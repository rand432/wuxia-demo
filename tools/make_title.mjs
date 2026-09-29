// 毛笔逐笔写字动画 · 用 hanzi-writer 的笔顺数据渲染
// ------------------------------------------------------------------
// 数据：strokes[] = 每笔的**轮廓路径**（填充即得笔形）
//       medians[] = 每笔的**中心线**（给出书写方向，用来做"笔尖走到哪画到哪")
//
// 用法： node tools/make_title.mjs
// 产出： export/_work/frames/f0000.png ... 然后由 ffmpeg 合成视频
// ------------------------------------------------------------------
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const WS = 'D:/1/wuxia-demo';
const SD = WS + '/export/_work/strokes';
const FD = WS + '/export/_work/frames';
const SIZE = 1024;          // 数据坐标系
const OUT = 420;            // 每字输出边长
const SS = 3;
const GAP = 10;               // 超采样倍数
const FPS = 25;

// ---------- PNG 输出 ----------
let CRC = null;
function crc32(buf) {
  if (!CRC) { CRC = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; CRC[n] = c >>> 0; } }
  let c = 0xffffffff;
  for (const b of buf) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function writePng(file, w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4); }
  const ch = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc32(td)); return Buffer.concat([l, td, c]); };
  const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 6;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), ch('IHDR', ih), ch('IDAT', zlib.deflateSync(raw, { level: 6 })), ch('IEND', Buffer.alloc(0))]));
}

// ---------- SVG 路径 → 多边形 ----------
function parsePath(d) {
  const polys = []; let cur = [];
  const tk = d.match(/[MLQCZmlqcz]|-?\d*\.?\d+/g) || [];
  let i = 0, x = 0, y = 0;
  const push = (a, b) => { cur.push([a, b]); x = a; y = b; };
  while (i < tk.length) {
    const t = tk[i];
    if (t === 'M' || t === 'm') { if (cur.length > 1) polys.push(cur); cur = []; i++; const nx = +tk[i++], ny = +tk[i++]; push(t === 'm' ? x + nx : nx, t === 'm' ? y + ny : ny); }
    else if (t === 'L' || t === 'l') { i++; const nx = +tk[i++], ny = +tk[i++]; push(t === 'l' ? x + nx : nx, t === 'l' ? y + ny : ny); }
    else if (t === 'Q' || t === 'q') { i++; const cx = +tk[i++], cy = +tk[i++], nx = +tk[i++], ny = +tk[i++];
      const ax = t === 'q' ? x + cx : cx, ay = t === 'q' ? y + cy : cy, bx = t === 'q' ? x + nx : nx, by = t === 'q' ? y + ny : ny;
      for (let s = 1; s <= 8; s++) { const u = s / 8, m = 1 - u; cur.push([m * m * x + 2 * m * u * ax + u * u * bx, m * m * y + 2 * m * u * ay + u * u * by]); }
      x = bx; y = by; }
    else if (t === 'Z' || t === 'z') { if (cur.length > 1) polys.push(cur); cur = []; i++; }
    else i++;
  }
  if (cur.length > 1) polys.push(cur);
  return polys.map((p) => p.map(([a, b]) => [a, 900 - b]));   // hanzi-writer: y 翻转 + 偏移 900
}

// ---------- 光栅化：按 progress 沿方向裁剪 ----------
function raster(polys, dir, prog, ci, bmpInfo) {
  if (bmpInfo) {
    const N0 = OUT * SS, CW0 = OUT * 3 + GAP * 2;
    const img0 = Buffer.alloc(CW0 * OUT * 4);
    const kk = OUT / 1024;
    const yEnd = bmpInfo.y0 + (bmpInfo.y1 - bmpInfo.y0) * Math.min(1, prog * 1.15);
    for (let y = 0; y < OUT; y++) for (let x = 0; x < OUT; x++) {
      let a = 0;
      for (let dy = 0; dy < SS; dy++) for (let dx = 0; dx < SS; dx++) {
        const sx = Math.round((x + dx / SS) / kk), sy = Math.round((y + dy / SS) / kk);
        if (sy >= bmpInfo.y0 && sy <= yEnd && sx >= 0 && sx < 1024 && sy >= 0 && sy < 1024 && G3[(sy * 1024 + sx) * 4 + 3] > 40) a++;
      }
      const al = a / (SS * SS);
      if (al <= 0) continue;
      const ox = ci * (OUT + GAP) + x, o = (y * CW0 + ox) * 4;
      img0[o] = 0x14; img0[o + 1] = 0x11; img0[o + 2] = 0x0e; img0[o + 3] = Math.round(al * 255);
    }
    return img0;
  }
  const CW = OUT * 3 + GAP * 2;          // 画布总宽
  const CH_ = OUT;                       // 画布高
  const N = OUT * SS;
  const acc = new Float32Array(N * N);
  const k = N / SIZE;
  // 多边形扫描线填充（nonzero）
  for (const poly of polys) {
    const pts = poly.map(([a, b]) => [a * k, b * k]);
    let minY = Infinity, maxY = -Infinity;
    for (const p of pts) { if (p[1] < minY) minY = p[1]; if (p[1] > maxY) maxY = p[1]; }
    const y0 = Math.max(0, Math.floor(minY)), y1 = Math.min(N - 1, Math.ceil(maxY));
    for (let yy = y0; yy <= y1; yy++) {
      const yc = yy + 0.5, xs = [];
      for (let a = 0; a < pts.length; a++) {
        const p = pts[a], q = pts[(a + 1) % pts.length];
        if ((p[1] <= yc && q[1] > yc) || (q[1] <= yc && p[1] > yc)) xs.push(p[0] + (yc - p[1]) / (q[1] - p[1]) * (q[0] - p[0]));
      }
      if (!xs.length) continue;
      xs.sort((m, n) => m - n);
      for (let s = 0; s + 1 < xs.length; s += 2) {
        const xa = Math.max(0, Math.ceil(xs[s] - 0.5)), xb = Math.min(N - 1, Math.floor(xs[s + 1] - 0.5));
        for (let xx = xa; xx <= xb; xx++) {
          if (prog < 1) { const t = (xx - dir.x0) * dir.dx + (yy - dir.y0) * dir.dy; if (t > prog * dir.len) continue; }
          acc[yy * N + xx] = 1;
        }
      }
    }
  }
  // 降采样 → RGBA（浓墨色）
  const img = Buffer.alloc(CW * CH_ * 4);
  for (let y = 0; y < CH_; y++) for (let x = 0; x < OUT; x++) {
    let s = 0;
    for (let dy = 0; dy < SS; dy++) for (let dx = 0; dx < SS; dx++) s += acc[(y * SS + dy) * N + x * SS + dx];
    const a = s / (SS * SS);
    const ox = (ci * (OUT + GAP) + x);
    const o = (y * CW + ox) * 4;
    img[o] = 0x14; img[o + 1] = 0x11; img[o + 2] = 0x0e; img[o + 3] = Math.round(a * 255);
  }
  return img;
}

// ---------- 主流程 ----------
const chars = [];
for (const [ch, file] of [['侠', '侠.json'], ['缘', '缘.json']]) {
  const j = JSON.parse(fs.readFileSync(path.join(SD, file), 'utf8'));
  chars.push({ ch, strokes: j.strokes.map((d, i) => ({ d, med: j.medians[i] })) });
}
// 「3」不在汉字库里 —— 手工给两笔（中心线 + 宽度），转成轮廓
// 「3」用 ink.ttf 渲染的字形位图（raw RGBA 1024×1024），沿中线劈成两笔
const G3 = fs.readFileSync(WS + '/export/_work/three.raw');
function bmp3(part) {
  let lo = 1e9, hi = -1;
  for (let y = 0; y < 1024; y++) for (let x = 0; x < 1024; x++) if (G3[(y * 1024 + x) * 4 + 3] > 40) { if (y < lo) lo = y; if (y > hi) hi = y; }
  const mid = (lo + hi) / 2;
  const y0 = part === 0 ? lo : mid, y1 = part === 0 ? mid : hi;
  return { bmp: true, y0, y1, med: [[512, y0], [512, y1]], plain: true };
}
const three = [bmp3(0), bmp3(1)];
chars.push({ ch: '3', strokes: three });

// 逐笔渲染
fs.rmSync(FD, { recursive: true, force: true }); fs.mkdirSync(FD, { recursive: true });
const plan = [];
let t = 0;
const PER = 0.30;                    // 每笔 0.30 秒
for (const c of chars) {
  for (let i = 0; i < c.strokes.length; i++) {
    const st = c.strokes[i];
    const polys = st.plain ? st.polys : parsePath(st.d);
    const med = st.med;
    // 书写方向：中心线首→尾
    const k = OUT / SIZE;
    const [sx, sy] = med[0], [ex, ey] = med[med.length - 1];
    let dx = (ex - sx) * k, dy = (ey - sy) * k;
    const len = Math.hypot(dx, dy) || 1;
    const dir = { x0: sx * k, y0: sy * k, dx: dx / len, dy: dy / len, len: len * 1.25 };
    plan.push({ ch: c.ch, i, ci: chars.indexOf(c), polys, dir, bmp: st.bmp, y0: st.y0, y1: st.y1, t0: +t.toFixed(3), t1: +(t + PER).toFixed(3) });
    t += PER;
  }
  t += 0.35;                        // 字与字之间喘一口气
}
console.log('共 ' + plan.length + ' 笔，写完需 ' + t.toFixed(2) + ' 秒');
fs.writeFileSync(WS + '/export/_work/strokeplan.json', JSON.stringify({ plan: plan.map((p) => ({ ch: p.ch, i: p.i, t0: p.t0, t1: p.t1 })), total: t, fps: FPS, out: OUT }, null, 2), 'utf8');

// 缓存每笔的"完成态"和"进行态"
const DUR = 12.0;                   // 卡片总长
const NF = Math.round(DUR * FPS);
const cache = new Map();
const key = (pi, p) => pi + ':' + p.toFixed(2);
process.stdout.write('渲染 ' + NF + ' 帧');
for (let f = 0; f < NF; f++) {
  const tt = f / FPS;
  const CW = OUT * 3 + GAP * 2;
  const img = Buffer.alloc(CW * OUT * 4);
  for (let pi = 0; pi < plan.length; pi++) {
    const p = plan[pi];
    if (tt < p.t0) continue;
    const prog = tt >= p.t1 ? 1 : (tt - p.t0) / (p.t1 - p.t0);
    const kk = key(pi, prog >= 1 ? 1 : Math.round(prog * 8) / 8);
    let sp = cache.get(kk);
    if (!sp) { sp = raster(p.polys, p.dir, prog >= 1 ? 1 : Math.round(prog * 8) / 8, p.ci, p.bmp ? { y0: p.y0, y1: p.y1 } : null); cache.set(kk, sp); }
    for (let o = 0; o < img.length; o += 4) {
      const a = sp[o + 3]; if (!a) continue;
      const d = img[o + 3];
      const na = a + d * (1 - a / 255);
      if (na > 0) { img[o] = ((img[o] * d + sp[o] * a * (1 - d / 255)) / na) | 0; img[o + 1] = ((img[o + 1] * d + sp[o + 1] * a * (1 - d / 255)) / na) | 0; img[o + 2] = ((img[o + 2] * d + sp[o + 2] * a * (1 - d / 255)) / na) | 0; img[o + 3] = na | 0; }
    }
  }
  writePng(FD + '/f' + String(f).padStart(4, '0') + '.png', CW, OUT, img);
  if (f % 25 === 0) process.stdout.write('.');
}
console.log(' ✓ 帧已写入 ' + FD);
