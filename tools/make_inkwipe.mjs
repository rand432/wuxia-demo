// 水墨转场遮罩：从水滴落点长出一团墨，把下一个画面化开
// ------------------------------------------------------------------
// 只生成"遮罩"（黑=保留上一镜，白=显示下一镜），由 ffmpeg 拿去做混合。
import fs from 'node:fs';
import zlib from 'node:zlib';
const WS = 'D:/1/wuxia-demo';
const MD = WS + '/export/_work/mask';
const WW = 1280, HH = 720, LEAD = 90, NF = 48, FPS = 25;   // LEAD=3.6 秒黑场（等旁白说完）

let CRC = null;
function crc32(b) { if (!CRC) { CRC = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; CRC[n] = c >>> 0; } } let c = 0xffffffff; for (const x of b) c = CRC[(c ^ x) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function writePng(f, w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4); }
  const ch = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc32(td)); return Buffer.concat([l, td, c]); };
  const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 6;
  fs.writeFileSync(f, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), ch('IHDR', ih), ch('IDAT', zlib.deflateSync(raw, { level: 6 })), ch('IEND', Buffer.alloc(0))]));
}
function hash(x, y) { let n = (x * 374761393 + y * 668265263) | 0; n = (n ^ (n >> 13)) * 1274126177 | 0; return ((n ^ (n >> 16)) >>> 0) / 4294967295; }
function vn(x, y) { const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash(xi, yi), b = hash(xi + 1, yi), c = hash(xi, yi + 1), d = hash(xi + 1, yi + 1);
  return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v; }
function fbm(x, y) { let s = 0, amp = 1, sc = 1, tot = 0;
  for (let o = 0; o < 4; o++) { s += vn(x * sc, y * sc) * amp; tot += amp; amp *= 0.5; sc *= 2.05; } return s / tot; }

// 水滴落点（01 镜头的正中）与几处墨点飞溅
const CX = WW * 0.5, CY = HH * 0.52;
const RMAX = Math.hypot(WW, HH) * 0.62;
const dots = [];
for (let i = 0; i < 34; i++) dots.push([hash(i * 7 + 1, 3) * WW, hash(i * 13 + 5, 9) * HH, 0.10 + hash(i * 3 + 2, 17) * 0.34, 8 + hash(i * 11 + 4, 23) * 34]);
fs.rmSync(MD, { recursive: true, force: true }); fs.mkdirSync(MD, { recursive: true });
process.stdout.write('渲染 ' + (LEAD + NF) + ' 帧遮罩（前 ' + LEAD + ' 帧全黑）');
for (let f = 0; f < LEAD; f++) {
  const img = Buffer.alloc(WW * HH * 4);
  for (let i = 0; i < WW * HH; i++) { img[i * 4 + 3] = 255; }
  writePng(MD + '/m' + String(f).padStart(4, '0') + '.png', WW, HH, img);
}
for (let f = 0; f < NF; f++) {
  const t = f / (NF - 1);                     // 0→1
  const front = Math.pow(t, 0.78) * 1.30;     // 墨的前沿（先快后慢）
  const img = Buffer.alloc(WW * HH * 4);
  for (let y = 0; y < HH; y++) for (let x = 0; x < WW; x++) {
    const dx = x - CX, dy = y - CY;
    let r = Math.hypot(dx, dy) / RMAX;
    // 用噪声扭曲半径 → 墨的边缘有丝缕、不规则
    const nz = (fbm(x / 190 + t * 1.6, y / 190 - t * 1.2) - 0.5) * 2;
    const nz2 = (fbm(x / 62 - t * 2.2, y / 62 + t * 1.8) - 0.5) * 2;
    r += nz * 0.22 + nz2 * 0.075 * (0.4 + t);
    let a = 0;
    if (r < front) a = Math.min(1, (front - r) * 5.5);            // 里面：已化开
    for (const [px, py, pt, pr] of dots) {                        // 墨点飞溅
      if (t < pt) continue;
      const d2 = Math.hypot(x - px, y - py);
      const grow = pr * (0.35 + (t - pt) * 2.4);
      if (d2 < grow) a = Math.max(a, Math.min(1, (grow - d2) * 0.5));
    }
    const o = (y * WW + x) * 4;
    const v = Math.round(Math.max(0, Math.min(1, a)) * 255);
    img[o] = v; img[o + 1] = v; img[o + 2] = v; img[o + 3] = 255;
  }
  writePng(MD + '/m' + String(LEAD + f).padStart(4, '0') + '.png', WW, HH, img);
  if (f % 8 === 0) process.stdout.write('.');
}
console.log(' ✓ ' + MD);
