// 行草书写动画：取 ink.ttf 字形 → 细化成骨架 → 串成书写路径 → 笔尖沿路径走
// ------------------------------------------------------------------
import fs from 'node:fs';
import zlib from 'node:zlib';
const WS = 'D:/1/wuxia-demo';
const W = WS + '/export/_work';
const FD = W + '/cframes';
const S = 1024;               // 字形坐标系
const OUT = 320;              // 每字输出边长
const GAP = 10;
const CW = OUT * 3 + GAP * 2;
const FPS = 25, DUR = 14;

let CRC = null;
function crc32(b) { if (!CRC) { CRC = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; CRC[n] = c >>> 0; } } let c = 0xffffffff; for (const x of b) c = CRC[(c ^ x) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function writePng(f, w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4); }
  const ch = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc32(td)); return Buffer.concat([l, td, c]); };
  const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 6;
  fs.writeFileSync(f, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), ch('IHDR', ih), ch('IDAT', zlib.deflateSync(raw, { level: 6 })), ch('IEND', Buffer.alloc(0))]));
}

// ---------- 读字形 → 二值 ----------
function mask(file) {
  const b = fs.readFileSync(file);
  const m = new Uint8Array(S * S);
  for (let i = 0; i < S * S; i++) m[i] = b[i * 4 + 3] > 110 ? 1 : 0;
  return m;
}
// 裁剪到内容框（留边），返回 {m, x0,y0,w,h}
function crop(m) {
  let x0 = S, y0 = S, x1 = -1, y1 = -1;
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) if (m[y * S + x]) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
  const pad = 12;
  x0 = Math.max(0, x0 - pad); y0 = Math.max(0, y0 - pad); x1 = Math.min(S - 1, x1 + pad); y1 = Math.min(S - 1, y1 + pad);
  const w = x1 - x0 + 1, h = y1 - y0 + 1;
  const o = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) o[y * w + x] = m[(y + y0) * S + (x + x0)];
  return { m: o, w, h };
}
// ---------- Zhang-Suen 细化 ----------
function thin(src, w, h) {
  const m = Uint8Array.from(src);
  const idx = (x, y) => y * w + x;
  const P = (x, y) => (x < 0 || y < 0 || x >= w || y >= h) ? 0 : m[idx(x, y)];
  let changed = true;
  while (changed) {
    changed = false;
    for (let step = 0; step < 2; step++) {
      const del = [];
      for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) {
        if (!m[idx(x, y)]) continue;
        const p2 = P(x, y - 1), p3 = P(x + 1, y - 1), p4 = P(x + 1, y), p5 = P(x + 1, y + 1);
        const p6 = P(x, y + 1), p7 = P(x - 1, y + 1), p8 = P(x - 1, y), p9 = P(x - 1, y - 1);
        const B = p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9;
        if (B < 2 || B > 6) continue;
        const seq = [p2, p3, p4, p5, p6, p7, p8, p9, p2];
        let A = 0; for (let i = 0; i < 8; i++) if (seq[i] === 0 && seq[i + 1] === 1) A++;
        if (A !== 1) continue;
        if (step === 0) { if (p2 * p4 * p6 !== 0) continue; if (p4 * p6 * p8 !== 0) continue; }
        else { if (p2 * p4 * p8 !== 0) continue; if (p2 * p6 * p8 !== 0) continue; }
        del.push(idx(x, y));
      }
      if (del.length) { changed = true; for (const i of del) m[i] = 0; }
    }
  }
  return m;
}
// ---------- 多源 BFS：每个笔画像素归到最近的骨架点 ----------
function nearest(skel, w, h) {
  const lab = new Int32Array(w * h).fill(-1);
  const q = [];
  for (let i = 0; i < w * h; i++) if (skel[i]) { lab[i] = i; q.push(i); }
  for (let head = 0; head < q.length; head++) {
    const i = q[head], x = i % w, y = (i / w) | 0;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy; if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      const j = ny * w + nx; if (lab[j] >= 0) continue;
      lab[j] = lab[i]; q.push(j);
    }
  }
  return lab;
}
// ---------- 骨架串成书写路径 ----------
function order(skel, w, h) {
  const pts = [];
  for (let i = 0; i < w * h; i++) if (skel[i]) pts.push([i % w, (i / w) | 0]);
  if (!pts.length) return [];
  // 端点优先（邻居只有 1 个的）
  const nb = (x, y) => { let c = 0; for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) { if (!dx && !dy) continue; const nx = x + dx, ny = y + dy; if (nx >= 0 && ny >= 0 && nx < w && ny < h && skel[ny * w + nx]) c++; } return c; };
  let start = pts.find(([x, y]) => nb(x, y) === 1) || pts[0];
  const used = new Set(), path = [];
  let cur = start;
  while (cur) {
    const key = cur[1] * w + cur[0];
    if (used.has(key)) break;
    used.add(key); path.push(cur);
    let best = null, bd = 1e9;
    for (const p of pts) {
      const k = p[1] * w + p[0]; if (used.has(k)) continue;
      const d = (p[0] - cur[0]) ** 2 + (p[1] - cur[1]) ** 2;
      if (d < bd) { bd = d; best = p; }
    }
    cur = best;
  }
  return path;
}

const glyphs = [
  { n: '侠', f: W + '/xia.raw' },
  { n: '缘', f: W + '/yuan.raw' },
  { n: '3', f: W + '/three.raw' },
];
const jobs = [];
let totalPts = 0;
for (let gi = 0; gi < glyphs.length; gi++) {
  const g = glyphs[gi];
  const c = crop(mask(g.f));
  const sk = thin(c.m, c.w, c.h);
  const lab = nearest(sk, c.w, c.h);
  const path = order(sk, c.w, c.h);
  const pos = new Map();
  path.forEach(([x, y], i) => pos.set(y * c.w + x, i / Math.max(1, path.length - 1)));
  jobs.push({ gi, c, lab, path, pos });
  totalPts += c.w * c.h;
  console.log('  ' + g.n + '  内容 ' + c.w + '×' + c.h + '  骨架点 ' + path.length);
}
const T = 9.2;                                     // 三字总书写时长
const per = T / glyphs.length;
fs.rmSync(FD, { recursive: true, force: true }); fs.mkdirSync(FD, { recursive: true });
const NF = Math.round(DUR * FPS);
const k = OUT / S;
process.stdout.write('渲染 ' + NF + ' 帧');
for (let f = 0; f < NF; f++) {
  const tt = f / FPS;
  const img = Buffer.alloc(CW * OUT * 4);
  for (const J of jobs) {
    const t0 = J.gi * per, pr = Math.max(0, Math.min(1, (tt - t0) / per));
    if (pr <= 0) continue;
    const c = J.c, ox = J.gi * (OUT + GAP);
    for (let y = 0; y < OUT; y++) for (let x = 0; x < OUT; x++) {
      const sx = Math.round((x - (OUT - c.w * k) / 2) / k), sy = Math.round((y - (OUT - c.h * k) / 2) / k);
      if (sx < 0 || sy < 0 || sx >= c.w || sy >= c.h) continue;
      const i = sy * c.w + sx;
      if (!c.m[i]) continue;
      const lp = J.pos.get(J.lab[i]);
      if (lp === undefined || lp > pr) continue;
      const o = (y * CW + (ox + x)) * 4;
      const edge = Math.min(1, Math.max(0, (pr - lp) * 26));
      // 写完 0.15 秒后墨就干了，全部浓黑（否则最后写到的笔画永远偏淡）
      const done = tt >= t0 + per + 0.15;
      img[o] = 0x14; img[o + 1] = 0x11; img[o + 2] = 0x0e;
      img[o + 3] = done ? 255 : Math.round(255 * (0.62 + 0.38 * edge));
    }
  }
  writePng(FD + '/c' + String(f).padStart(4, '0') + '.png', CW, OUT, img);
  if (f % 25 === 0) process.stdout.write('.');
}
console.log(' ✓ ' + FD);
