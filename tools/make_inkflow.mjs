// 水墨流动片尾：笔尖边走边"放墨"，墨被 curl noise 速度场吹着翻涌
// ------------------------------------------------------------------
// 参考 KeiKanamori《毛笔水墨CG片头》—— 那是 Houdini Pyro 烟雾模拟。
// 这里用等效近似：curl noise（无散度速度场）做半拉格朗日平流，
// 不用解 Navier-Stokes，也能得到翻涌、卷曲、拖尾的墨。
// ------------------------------------------------------------------
import fs from 'node:fs';
import zlib from 'node:zlib';
const WS = 'D:/1/wuxia-demo';
const W = WS + '/export/_work';
const FD = W + '/iframes';
const S = 1024, OUT = 320, GAP = 10, CW = OUT * 3 + GAP * 2;
const FPS = 25, DUR = 14;
// 模拟分辨率（半分辨率，快）
const SW = CW >> 1, SH = OUT >> 1;

let CRC = null;
function crc32(b) { if (!CRC) { CRC = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; CRC[n] = c >>> 0; } } let c = 0xffffffff; for (const x of b) c = CRC[(c ^ x) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function writePng(f, w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4); }
  const ch = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc32(td)); return Buffer.concat([l, td, c]); };
  const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 6;
  fs.writeFileSync(f, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), ch('IHDR', ih), ch('IDAT', zlib.deflateSync(raw, { level: 6 })), ch('IEND', Buffer.alloc(0))]));
}
// ---------- 噪声 ----------
function hash(x, y) { let n = (x * 374761393 + y * 668265263) | 0; n = (n ^ (n >> 13)) * 1274126177 | 0; return ((n ^ (n >> 16)) >>> 0) / 4294967295; }
function vnoise(x, y, sc) {
  const xi = Math.floor(x * sc), yi = Math.floor(y * sc), xf = x * sc - xi, yf = y * sc - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash(xi, yi), b = hash(xi + 1, yi), c = hash(xi, yi + 1), d = hash(xi + 1, yi + 1);
  return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v;
}
function fbm(x, y, t) {          // 时间演化的分形噪声（第三维用 t 切片）
  let s = 0, amp = 1, sc = 0.012, tot = 0;
  for (let o = 0; o < 3; o++) { s += vnoise(x + t * 12, y * 1.0 + t * 7, sc) * amp; tot += amp; amp *= 0.5; sc *= 2.1; }
  return s / tot;
}
// ---------- 字形 ----------
function mask(file) { const b = fs.readFileSync(file); const m = new Uint8Array(S * S); for (let i = 0; i < S * S; i++) m[i] = b[i * 4 + 3] > 110 ? 1 : 0; return m; }
function crop(m) {
  let x0 = S, y0 = S, x1 = -1, y1 = -1;
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) if (m[y * S + x]) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
  const p = 14; x0 = Math.max(0, x0 - p); y0 = Math.max(0, y0 - p); x1 = Math.min(S - 1, x1 + p); y1 = Math.min(S - 1, y1 + p);
  const w = x1 - x0 + 1, h = y1 - y0 + 1; const o = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) o[y * w + x] = m[(y + y0) * S + (x + x0)];
  return { m: o, w, h };
}
function thin(src, w, h) {
  const m = Uint8Array.from(src), idx = (x, y) => y * w + x;
  const P = (x, y) => (x < 0 || y < 0 || x >= w || y >= h) ? 0 : m[idx(x, y)];
  let ch = true;
  while (ch) { ch = false;
    for (let step = 0; step < 2; step++) { const del = [];
      for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) {
        if (!m[idx(x, y)]) continue;
        const p2 = P(x, y - 1), p3 = P(x + 1, y - 1), p4 = P(x + 1, y), p5 = P(x + 1, y + 1), p6 = P(x, y + 1), p7 = P(x - 1, y + 1), p8 = P(x - 1, y), p9 = P(x - 1, y - 1);
        const B = p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9; if (B < 2 || B > 6) continue;
        const seq = [p2, p3, p4, p5, p6, p7, p8, p9, p2]; let A = 0; for (let i = 0; i < 8; i++) if (seq[i] === 0 && seq[i + 1] === 1) A++;
        if (A !== 1) continue;
        if (step === 0) { if (p2 * p4 * p6 !== 0 || p4 * p6 * p8 !== 0) continue; } else { if (p2 * p4 * p8 !== 0 || p2 * p6 * p8 !== 0) continue; }
        del.push(idx(x, y));
      }
      if (del.length) { ch = true; for (const i of del) m[i] = 0; }
    } }
  return m;
}
function nearest(skel, w, h) {
  const lab = new Int32Array(w * h).fill(-1), q = [];
  for (let i = 0; i < w * h; i++) if (skel[i]) { lab[i] = i; q.push(i); }
  for (let hd = 0; hd < q.length; hd++) { const i = q[hd], x = i % w, y = (i / w) | 0;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const nx = x + dx, ny = y + dy; if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue; const j = ny * w + nx; if (lab[j] >= 0) continue; lab[j] = lab[i]; q.push(j); } }
  return lab;
}
function order(skel, w, h) {
  const pts = []; for (let i = 0; i < w * h; i++) if (skel[i]) pts.push([i % w, (i / w) | 0]);
  if (!pts.length) return [];
  const nb = (x, y) => { let c = 0; for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) { if (!dx && !dy) continue; const nx = x + dx, ny = y + dy; if (nx >= 0 && ny >= 0 && nx < w && ny < h && skel[ny * w + nx]) c++; } return c; };
  let cur = pts.find(([x, y]) => nb(x, y) === 1) || pts[0];
  const used = new Set(), path = [];
  while (cur) { const key = cur[1] * w + cur[0]; if (used.has(key)) break; used.add(key); path.push(cur);
    let best = null, bd = 1e9;
    for (const p of pts) { const k = p[1] * w + p[0]; if (used.has(k)) continue; const d = (p[0] - cur[0]) ** 2 + (p[1] - cur[1]) ** 2; if (d < bd) { bd = d; best = p; } }
    cur = best; }
  return path;
}

const glyphs = [{ n: '侠', f: W + '/xia.raw' }, { n: '缘', f: W + '/yuan.raw' }, { n: '3', f: W + '/three.raw' }];
const G = [];
for (let gi = 0; gi < glyphs.length; gi++) {
  const c = crop(mask(glyphs[gi].f));
  const sk = thin(c.m, c.w, c.h);
  const lab = nearest(sk, c.w, c.h);
  const path = order(sk, c.w, c.h);
  const pos = new Map(); path.forEach(([x, y], i) => pos.set(y * c.w + x, i / Math.max(1, path.length - 1)));
  G.push({ gi, c, lab, path, pos });
  console.log('  ' + glyphs[gi].n + ' 骨架 ' + path.length + ' 点');
}
const T = 9.2, per = T / glyphs.length;

// ---------- 墨流场模拟 ----------
const dye = new Float32Array(SW * SH);
const dye2 = new Float32Array(SW * SH);
const K = OUT / S, kk = (OUT / S) / 2;      // 字形→输出→模拟 的缩放
const NF = Math.round(DUR * FPS);
fs.rmSync(FD, { recursive: true, force: true }); fs.mkdirSync(FD, { recursive: true });
process.stdout.write('模拟+渲染 ' + NF + ' 帧');
for (let f = 0; f < NF; f++) {
  const tt = f / FPS;
  // ① 笔尖放墨
  for (const J of G) {
    const t0 = J.gi * per, pr = Math.max(0, Math.min(1, (tt - t0) / per));
    if (pr <= 0) continue;
    const idx = Math.min(J.path.length - 1, Math.floor(pr * (J.path.length - 1)));
    const [px, py] = J.path[idx], c = J.c;
    const ox = J.gi * (OUT + GAP);
    const sxp = (ox + (px - (c.w - 0) / 2 + OUT / 2) * K) / 2, syp = ((py - c.h / 2 + OUT / 2) * K) / 2;
    for (let dy = -4; dy <= 4; dy++) for (let dx = -4; dx <= 4; dx++) {
      const x = Math.round(sxp + dx), y = Math.round(syp + dy);
      if (x < 0 || y < 0 || x >= SW || y >= SH) continue;
      const w = Math.exp(-(dx * dx + dy * dy) / 9);
      dye[y * SW + x] = Math.min(2.4, dye[y * SW + x] + w * 0.95);
    }
  }
  // ② curl noise 平流 + 扩散 + 衰减
  const adv = 3.4, dec = 0.9955;
  for (let y = 0; y < SH; y++) for (let x = 0; x < SW; x++) {
    const e = 3.0;
    const n1 = fbm(x, y, tt), n2 = fbm(x + 100, y + 100, tt);
    const n1x = fbm(x + e, y, tt) - fbm(x - e, y, tt);
    const n1y = fbm(x, y + e, tt) - fbm(x, y - e, tt);
    const n2x = fbm(x + 100 + e, y + 100, tt) - fbm(x + 100 - e, y + 100, tt);
    const n2y = fbm(x + 100, y + 100 + e, tt) - fbm(x + 100, y + 100 - e, tt);
    const vx = (n2y - n1y) * adv, vy = -(n2x - n1x) * adv;      // curl
    const sx = Math.max(0, Math.min(SW - 1, x - vx)), sy = Math.max(0, Math.min(SH - 1, y - vy));
    const x0 = sx | 0, y0 = sy | 0, x1 = Math.min(SW - 1, x0 + 1), y1 = Math.min(SH - 1, y0 + 1);
    const fx = sx - x0, fy = sy - y0;
    const a = dye[y0 * SW + x0] * (1 - fx) + dye[y0 * SW + x1] * fx;
    const b = dye[y1 * SW + x0] * (1 - fx) + dye[y1 * SW + x1] * fx;
    dye2[y * SW + x] = (a * (1 - fy) + b * fy) * dec;
  }
  for (let i = 0; i < SW * SH; i++) dye[i] = dye2[i];
  // 轻微扩散（3x3）
  for (let y = 1; y < SH - 1; y++) for (let x = 1; x < SW - 1; x++) {
    const i = y * SW + x;
    dye2[i] = (dye[i] * 4 + dye[i - 1] + dye[i + 1] + dye[i - SW] + dye[i + SW]) / 8;
  }
  for (let i = 0; i < SW * SH; i++) dye[i] = dye2[i];

  // ③ 合成：干墨（字形）+ 湿墨（翻涌的墨）
  const img = Buffer.alloc(CW * OUT * 4);
  for (let y = 0; y < OUT; y++) for (let x = 0; x < CW; x++) {
    let a = 0;
    // 干墨
    const gi = Math.min(2, Math.floor(x / (OUT + GAP)));
    const J = G[gi], c = J.c;
    const t0 = gi * per, pr = Math.max(0, Math.min(1, (tt - t0) / per));
    if (pr > 0) {
      const lx = x - gi * (OUT + GAP);
      const sx = Math.round((lx - (OUT - c.w * K) / 2) / K), sy = Math.round((y - (OUT - c.h * K) / 2) / K);
      if (sx >= 0 && sy >= 0 && sx < c.w && sy < c.h && c.m[sy * c.w + sx]) {
        const lp = J.pos.get(J.lab[sy * c.w + sx]);
        if (lp !== undefined && lp <= pr) a = Math.min(1, (pr - lp) * 26);
      }
    }
    // 湿墨
    const dx2 = x >> 1, dy2 = y >> 1;
    const dv = dye[dy2 * SW + dx2];
    if (dv > 0.03) a = Math.max(a, Math.min(1, dv * 0.86));
    if (a <= 0.004) continue;
    const o = (y * CW + x) * 4;
    img[o] = 0x14; img[o + 1] = 0x11; img[o + 2] = 0x0e;
    img[o + 3] = Math.round(255 * a);
  }
  writePng(FD + '/i' + String(f).padStart(4, '0') + '.png', CW, OUT, img);
  if (f % 25 === 0) process.stdout.write('.');
}
console.log(' ✓ ' + FD);
