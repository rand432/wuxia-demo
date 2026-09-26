// ============================================================
// 人海合成器：把「人群带」按亮度转透明，分层叠到无人背景上
// 依赖：Node 内置 zlib（自带极简 PNG 解码/编码，无第三方包）
// 用法：node tools/composite_crowd.mjs <背景.png> <输出.png> <层:dx,dy,scale,opacity> ...
// ============================================================
import fs from 'node:fs';
import zlib from 'node:zlib';
import path from 'node:path';

function decodePNG(buf) {
  if (buf.readUInt32BE(0) !== 0x89504e47) throw new Error('不是 PNG');
  let off = 8, w = 0, h = 0, bitDepth = 0, colorType = 0;
  const idat = [];
  while (off + 8 <= buf.length) {
    const len = buf.readUInt32BE(off);
    const type = buf.toString('ascii', off + 4, off + 8);
    const data = buf.subarray(off + 8, off + 8 + len);
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); bitDepth = data[8]; colorType = data[9]; }
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
    off += 12 + len;
  }
  const ch = colorType === 6 ? 4 : colorType === 2 ? 3 : colorType === 0 ? 1 : colorType === 4 ? 2 : 0;
  if (!ch || bitDepth !== 8) throw new Error('不支持的 PNG: colorType=' + colorType + ' bitDepth=' + bitDepth);
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = w * ch;
  const out = Buffer.alloc(w * h * 4);
  let prev = Buffer.alloc(stride), pos = 0;
  for (let y = 0; y < h; y++) {
    const ft = raw[pos++];
    const line = Buffer.from(raw.subarray(pos, pos + stride)); pos += stride;
    for (let i = 0; i < stride; i++) {
      const a = i >= ch ? line[i - ch] : 0, b = prev[i], c = i >= ch ? prev[i - ch] : 0;
      let v = line[i];
      if (ft === 1) v = (v + a) & 255;
      else if (ft === 2) v = (v + b) & 255;
      else if (ft === 3) v = (v + ((a + b) >> 1)) & 255;
      else if (ft === 4) {
        const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        v = (v + ((pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c))) & 255;
      }
      line[i] = v;
    }
    for (let x = 0; x < w; x++) {
      const s = x * ch, d = (y * w + x) * 4;
      if (ch === 4) { out[d] = line[s]; out[d+1] = line[s+1]; out[d+2] = line[s+2]; out[d+3] = line[s+3]; }
      else if (ch === 3) { out[d] = line[s]; out[d+1] = line[s+1]; out[d+2] = line[s+2]; out[d+3] = 255; }
      else if (ch === 1) { out[d] = out[d+1] = out[d+2] = line[s]; out[d+3] = 255; }
      else { out[d] = out[d+1] = out[d+2] = line[s]; out[d+3] = line[s+1]; }
    }
    prev = line;
  }
  return { w, h, data: out };
}

const CRCT = (() => { const t = new Int32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1); t[n] = c; } return t; })();
function crc32(b) { let c = -1; for (let i = 0; i < b.length; i++) c = CRCT[(c ^ b[i]) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const t = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([t, data])));
  return Buffer.concat([len, t, data, crc]);
}
function encodePNG(w, h, rgba) {
  const stride = w * 4;
  const raw = Buffer.alloc((stride + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (stride + 1)] = 0; rgba.copy(raw, y * (stride + 1) + 1, y * stride, y * stride + stride); }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0)),
  ]);
}

function cropPNG(img, x, y, w, h) {
  const out = Buffer.alloc(w * h * 4);
  for (let yy = 0; yy < h; yy++) {
    for (let xx = 0; xx < w; xx++) {
      const sx = Math.min(img.w - 1, Math.max(0, x + xx));
      const sy = Math.min(img.h - 1, Math.max(0, y + yy));
      const si = (sy * img.w + sx) * 4, di = (yy * w + xx) * 4;
      out[di] = img.data[si]; out[di+1] = img.data[si+1]; out[di+2] = img.data[si+2]; out[di+3] = img.data[si+3];
    }
  }
  return { w, h, data: out };
}

function toInk(layer, gain = 1.18, inkGamma = 0.86) {
  const { w, h, data } = layer;
  const out = Buffer.alloc(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    const r = data[i*4], g = data[i*4+1], b = data[i*4+2];
    const lum = 0.30*r + 0.59*g + 0.11*b;
    let a = Math.round((255 - lum) * gain);
    if (a < 0) a = 0; if (a > 255) a = 255;
    const v = Math.round(255 * Math.pow(lum / 255, inkGamma) * 0.9);
    out[i*4] = v; out[i*4+1] = v; out[i*4+2] = v; out[i*4+3] = a;
  }
  return { w, h, data: out };
}

function stamp(dst, src, dx, dy, scale, opacity) {
  const sw = Math.round(src.w * scale), sh = Math.round(src.h * scale);
  for (let y = 0; y < sh; y++) {
    const ty = dy + y; if (ty < 0 || ty >= dst.h) continue;
    const sy = Math.min(src.h - 1, Math.floor(y / scale));
    for (let x = 0; x < sw; x++) {
      const tx = dx + x; if (tx < 0 || tx >= dst.w) continue;
      const sx = Math.min(src.w - 1, Math.floor(x / scale));
      const si = (sy * src.w + sx) * 4;
      const a = src.data[si+3] * opacity;
      if (a < 1) continue;
      const af = a / 255;
      const di = (ty * dst.w + tx) * 4;
      dst.data[di]   = Math.round(dst.data[di]   * (1 - af) + src.data[si]   * af);
      dst.data[di+1] = Math.round(dst.data[di+1] * (1 - af) + src.data[si+1] * af);
      dst.data[di+2] = Math.round(dst.data[di+2] * (1 - af) + src.data[si+2] * af);
      dst.data[di+3] = 255;
    }
  }
}

// --cols <file>：报告墨色像素的列分布，用于找出图里每个人物所在的 x 区间
if (process.argv[2] === '--cols') {
  for (const f of process.argv.slice(3)) {
    const img = decodePNG(fs.readFileSync(f));
    const cols = new Array(img.w).fill(0);
    for (let x = 0; x < img.w; x++) {
      let c = 0;
      for (let y = 0; y < img.h; y++) {
        const i = (y * img.w + x) * 4;
        const lum = 0.30*img.data[i] + 0.59*img.data[i+1] + 0.11*img.data[i+2];
        if (lum < 170) c++;
      }
      cols[x] = c;
    }
    const seg = [];
    let st = -1;
    for (let x = 0; x < img.w; x++) {
      const on = cols[x] > img.h * 0.012;
      if (on && st < 0) st = x;
      if (!on && st >= 0) { if (x - st > 40) seg.push([st, x]); st = -1; }
    }
    if (st >= 0) seg.push([st, img.w]);
    console.log(path.basename(f) + '  ' + img.w + 'x' + img.h + '  人物段: ' + JSON.stringify(seg));
    for (const [a, b] of seg) {
      let top = img.h, bot = 0;
      for (let y = 0; y < img.h; y++) {
        for (let x = a; x < b; x++) {
          const i = (y * img.w + x) * 4;
          const lum = 0.30*img.data[i] + 0.59*img.data[i+1] + 0.11*img.data[i+2];
          if (lum < 170) { if (y < top) top = y; if (y > bot) bot = y; break; }
        }
      }
      console.log('   x[' + a + ',' + b + ']  y[' + top + ',' + bot + ']  尺寸 ' + (b-a) + 'x' + (bot-top));
    }
  }
  process.exit(0);
}

// --info <file>：报告墨色像素的行分布，用于确定人群带实际所在的 y 区间
if (process.argv[2] === '--info') {
  for (const f of process.argv.slice(3)) {
    const img = decodePNG(fs.readFileSync(f));
    const rows = new Array(img.h).fill(0);
    let total = 0;
    for (let y = 0; y < img.h; y++) {
      let c = 0;
      for (let x = 0; x < img.w; x++) {
        const i = (y * img.w + x) * 4;
        const lum = 0.30*img.data[i] + 0.59*img.data[i+1] + 0.11*img.data[i+2];
        if (lum < 175) c++;
      }
      rows[y] = c; total += c;
    }
    let top = -1, bot = -1;
    for (let y = 0; y < img.h; y++) { if (rows[y] > img.w * 0.004) { if (top < 0) top = y; bot = y; } }
    console.log(path.basename(f) + '  ' + img.w + 'x' + img.h + '  墨色像素=' + total +
      '  人物带 y 区间=[' + top + ',' + bot + ']  (占全高 ' + (100*top/img.h).toFixed(0) + '%~' + (100*bot/img.h).toFixed(0) + '%)');
    const step = Math.floor(img.h / 12);
    let bar = '';
    for (let y = 0; y < img.h; y += step) {
      let c = 0; for (let k = y; k < Math.min(img.h, y + step); k++) c += rows[k];
      bar += ' [' + y + ':' + Math.round(c / (step * img.w) * 100) + '%]';
    }
    console.log('   分行密度:' + bar);
  }
  process.exit(0);
}

const [bgPath, outPath, ...stamps] = process.argv.slice(2);
const bg = decodePNG(fs.readFileSync(bgPath));
console.log('背景 ' + bg.w + 'x' + bg.h);
const cache = new Map();
for (const spec of stamps) {
  const m = spec.match(/^(.+?)(?:#(-?\d+),(-?\d+),(\d+),(\d+))?:(-?\d+),(-?\d+),([\d.]+),([\d.]+)$/);
  if (!m) { console.log('跳过: ' + spec); continue; }
  const [, file, cxs, cys, cws, chs, dxs, dys, scales, ops] = m;
  const key = file + (cxs !== undefined ? '#' + cxs + ',' + cys + ',' + cws + ',' + chs : '');
  if (!cache.has(key)) {
    let img = decodePNG(fs.readFileSync(file));
    if (cxs !== undefined) img = cropPNG(img, +cxs, +cys, +cws, +chs);
    cache.set(key, toInk(img));
  }
  stamp(bg, cache.get(key), parseInt(dxs, 10), parseInt(dys, 10), parseFloat(scales), parseFloat(ops));
  console.log('  叠加 ' + path.basename(file) + ' @(' + dxs + ',' + dys + ') x' + scales + ' a=' + ops);
}
// 原子写入：先写临时文件再改名，避开被 git/编辑器/引擎占用导致的写入失败
const png = encodePNG(bg.w, bg.h, bg.data);
const tmp = outPath + '.tmp' + Date.now();
fs.writeFileSync(tmp, png);
let done = false;
for (let i = 0; i < 12; i++) {
  try { fs.renameSync(tmp, outPath); done = true; break; }
  catch (e) { await new Promise((r) => setTimeout(r, 500)); }
}
if (!done) { fs.copyFileSync(tmp, outPath); fs.rmSync(tmp, { force: true }); }
console.log('输出 ' + outPath + '  ' + (fs.statSync(outPath).size/1024/1024).toFixed(2) + 'MB');