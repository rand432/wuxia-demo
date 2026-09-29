// ============================================================
// 人物美术 · 去背景 / 透明底 PNG（零依赖，借 ffmpeg 编解码）
//
// 两种抠法：
//   flood（默认）—— 从四边泛洪，只删「与画面边缘相连的近白背景」
//                   白衣服、白纸、浅色皮肤只要不连到边就保得住；适合二次元彩图
//   luma         —— alpha = 255 - 亮度；水墨画专用，淡墨自动半透明，边缘最自然
//
// 附加处理：边缘白晕反解（去掉描边外那圈白边）、去孤点、填小洞、自动裁到内容框
//
// 用法：
//   node tools/cutout_art.mjs assets/gen/char/shaoxia/shaoxia_立绘_glm_anime.png
//   node tools/cutout_art.mjs <in.png> --mode luma --tol 30 --pad 24
//   node tools/cutout_art.mjs <dir>            # 目录下所有图批量（跳过已 _cut 的）
// ============================================================
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawnSync } from 'node:child_process';

const FFMPEG = process.env.FFMPEG || 'C:\\Users\\zq300\\ffmpeg\\bin\\ffmpeg.exe';
const args = process.argv.slice(2);
const input = args.find((a) => !a.startsWith('--'));
const opt = (f, d) => { const i = args.indexOf('--' + f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
const has = (f) => args.includes('--' + f);
if (!input) { console.log('用法：node tools/cutout_art.mjs <图片或目录> [--mode flood|luma] [--tol 26] [--pad 16]'); process.exit(1); }

const MODE = opt('mode', 'flood');
const TOL = parseInt(opt('tol', '26'), 10);        // 近白判定：三通道都 >= 255-TOL
const PAD = parseInt(opt('pad', '12'), 10);        // 裁切后四周留白
const MIN_BLOB = parseInt(opt('minblob', '40'), 10); // 小于此像素数的前景孤点删掉

const TMP = path.join(os.tmpdir(), 'cutout_' + process.pid);
fs.mkdirSync(TMP, { recursive: true });

// ---------- 从文件头读尺寸（不依赖 ffprobe，避免管道） ----------
function dimsOf(buf, file) {
  if (buf[0] === 0x89 && buf.toString('latin1', 1, 4) === 'PNG') {
    return { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
  }
  if (buf[0] === 0xff && buf[1] === 0xd8) {           // JPEG：扫 SOFn
    let i = 2;
    while (i < buf.length - 9) {
      if (buf[i] !== 0xff) { i++; continue; }
      const m = buf[i + 1];
      if (m >= 0xc0 && m <= 0xcf && m !== 0xc4 && m !== 0xc8 && m !== 0xcc) {
        return { h: buf.readUInt16BE(i + 5), w: buf.readUInt16BE(i + 7) };
      }
      i += 2 + buf.readUInt16BE(i + 2);
    }
    throw new Error('JPEG 尺寸解析失败: ' + file);
  }
  throw new Error('只支持 PNG/JPEG：' + file);
}

function ffmpeg(a) {
  const r = spawnSync(FFMPEG, a, { stdio: 'ignore' });
  if (r.status !== 0) throw new Error('ffmpeg 失败 [' + r.status + ']：' + a.join(' '));
}

// ---------- 抠图核心 ----------
function cutout(rgba, w, h) {
  const n = w * h;
  const isBg = new Uint8Array(n);            // 1 = 判定为背景
  // 自适应背景色：取四角 24x24 的中位数（AI 出图的"白底"常是 236~250 的暖白，写死 255 会漏）
  const samples = [[], [], []];
  const corners = [[0, 0], [w - 24, 0], [0, h - 24], [w - 24, h - 24]];
  for (const [cx, cy] of corners) {
    for (let y = Math.max(0, cy); y < Math.min(h, cy + 24); y++) {
      for (let x = Math.max(0, cx); x < Math.min(w, cx + 24); x++) {
        const p = (y * w + x) * 4;
        samples[0].push(rgba[p]); samples[1].push(rgba[p + 1]); samples[2].push(rgba[p + 2]);
      }
    }
  }
  const med = (a) => { a.sort((x, y) => x - y); return a[a.length >> 1]; };
  const bg = MODE === 'luma' ? [255, 255, 255] : [med(samples[0]), med(samples[1]), med(samples[2])];
  const near = (i) => {
    const p = i * 4;
    return Math.abs(rgba[p] - bg[0]) <= TOL && Math.abs(rgba[p + 1] - bg[1]) <= TOL && Math.abs(rgba[p + 2] - bg[2]) <= TOL;
  };
  if (MODE === 'luma') {
    for (let i = 0; i < n; i++) {
      const p = i * 4;
      const lum = 0.299 * rgba[p] + 0.587 * rgba[p + 1] + 0.114 * rgba[p + 2];
      rgba[p + 3] = Math.max(0, Math.min(255, Math.round((255 - lum) * 1.06 - 2)));
    }
  } else {
    const q = new Int32Array(n);
    let qh = 0, qt = 0;
    const push = (i) => { if (!isBg[i] && near(i)) { isBg[i] = 1; q[qt++] = i; } };
    for (let x = 0; x < w; x++) { push(x); push((h - 1) * w + x); }
    for (let y = 0; y < h; y++) { push(y * w); push(y * w + w - 1); }
    while (qh < qt) {
      const i = q[qh++], x = i % w, y = (i / w) | 0;
      if (x > 0) push(i - 1);
      if (x < w - 1) push(i + 1);
      if (y > 0) push(i - w);
      if (y < h - 1) push(i + w);
    }
    // 前景 alpha：内部 255；贴着背景的那圈按「有多白」递减，同时反解白晕
    for (let i = 0; i < n; i++) {
      if (isBg[i]) { rgba[i * 4 + 3] = 0; continue; }
      const x = i % w, y = (i / w) | 0;
      let edge = false;
      for (let dy = -1; dy <= 1 && !edge; dy++) for (let dx = -1; dx <= 1; dx++) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        if (isBg[ny * w + nx]) { edge = true; break; }
      }
      const p = i * 4;
      if (!edge) { rgba[p + 3] = 255; continue; }
      const d = Math.max(Math.abs(rgba[p] - bg[0]), Math.abs(rgba[p + 1] - bg[1]), Math.abs(rgba[p + 2] - bg[2]));
      const a = Math.max(0, Math.min(255, Math.round((d / TOL) * 255)));
      rgba[p + 3] = a;
      if (a > 8) { // 反解：观测 = a*前景 + (1-a)*背景 → 前景 = (观测 - (1-a)*背景)/a
        const k = a / 255;
        for (let c = 0; c < 3; c++) {
          const v = (rgba[p + c] - (1 - k) * bg[c]) / k;
          rgba[p + c] = Math.max(0, Math.min(255, Math.round(v)));
        }
      }
    }
    // 去孤点 + 填小洞（只做一轮，够用）
    const comp = new Int32Array(n).fill(-1);
    const stack = new Int32Array(n);
    const blobs = [];
    for (let i = 0; i < n; i++) {
      if (isBg[i] || comp[i] >= 0) continue;
      let sp = 0, size = 0; stack[sp++] = i; comp[i] = blobs.length;
      const members = [];
      while (sp > 0) {
        const j = stack[--sp]; members.push(j); size++;
        const x = j % w, y = (j / w) | 0;
        const nb = [x > 0 ? j - 1 : -1, x < w - 1 ? j + 1 : -1, y > 0 ? j - w : -1, y < h - 1 ? j + w : -1];
        for (const k of nb) if (k >= 0 && !isBg[k] && comp[k] < 0) { comp[k] = blobs.length; stack[sp++] = k; }
      }
      blobs.push({ size, members });
    }
    blobs.sort((a, b) => b.size - a.size);
    for (let bi = 1; bi < blobs.length; bi++) {
      if (blobs[bi].size < MIN_BLOB) for (const j of blobs[bi].members) rgba[j * 4 + 3] = 0;
      else for (const j of blobs[bi].members) rgba[j * 4 + 3] = 255;   // 连带小块也保住，只删碎屑
    }
  }
  // 内容框
  let x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (rgba[(y * w + x) * 4 + 3] > 8) {
      if (x < x0) x0 = x; if (x > x1) x1 = x;
      if (y < y0) y0 = y; if (y > y1) y1 = y;
    }
  }
  if (x1 < 0) return null;
  x0 = Math.max(0, x0 - PAD); y0 = Math.max(0, y0 - PAD);
  x1 = Math.min(w - 1, x1 + PAD); y1 = Math.min(h - 1, y1 + PAD);
  const cw = x1 - x0 + 1, ch = y1 - y0 + 1;
  const out = Buffer.alloc(cw * ch * 4);
  for (let y = 0; y < ch; y++) {
    rgba.copy(out, y * cw * 4, ((y + y0) * w + x0) * 4, ((y + y0) * w + x0 + cw) * 4);
  }
  return { buf: out, w: cw, h: ch };
}

function processOne(file, outFile) {
  const raw = fs.readFileSync(file);
  const { w, h } = dimsOf(raw, file);
  const dec = path.join(TMP, 'in.rgba');
  ffmpeg(['-y', '-i', file, '-vf', 'format=rgba', '-f', 'rawvideo', '-pix_fmt', 'rgba', dec]);
  const rgba = fs.readFileSync(dec);
  if (rgba.length < w * h * 4) throw new Error('解码尺寸不符：' + rgba.length + ' vs ' + w * h * 4);
  const buf = Buffer.from(rgba.subarray(0, w * h * 4));
  // GLM 出图右下角有「AI生成」水印：抹成白底（统计一下抹掉了多少非白像素，防止误伤人物）
  if (has('wm')) {
    const x0 = Math.floor(w * 0.70), y0 = Math.floor(h * 0.885);
    let dirty = 0, total = 0;
    const c0 = [buf[0], buf[1], buf[2]];   // 左上角当背景基准
    for (let y = y0; y < h; y++) for (let x = x0; x < w; x++) {
      const p = (y * w + x) * 4; total++;
      // 与背景色差 > 40 才算"压到东西"（水印灰 ≈ 222，背景 ≈ 238，差值 16，不算）
      const d = Math.max(Math.abs(buf[p] - c0[0]), Math.abs(buf[p + 1] - c0[1]), Math.abs(buf[p + 2] - c0[2]));
      if (d > 40) dirty++;
      // 填成「图本身的背景色」而不是纯白——否则暖白底（236,231,219）与纯白差 36，泛洪进不去
      buf[p] = c0[0]; buf[p + 1] = c0[1]; buf[p + 2] = c0[2]; buf[p + 3] = 255;
    }
    console.log('  · 抹水印区 ' + (w - x0) + 'x' + (h - y0) + '，压到人物像素 ' + dirty + '/' + total + (dirty / total > 0.02 ? '  ⚠ 可能压到人物，检查构图' : '  安全'));
  }
  const res = cutout(buf, w, h);
  if (!res) throw new Error('整张图都被判成背景了（tol 调小试试）');
  const enc = path.join(TMP, 'out.rgba');
  fs.writeFileSync(enc, res.buf);
  ffmpeg(['-y', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', res.w + 'x' + res.h, '-i', enc, outFile]);
  console.log('  ✓ ' + path.basename(outFile) + '  ' + res.w + 'x' + res.h + '  (' + path.basename(file) + ' → 去底裁切)');
}

const target = path.resolve(input);
// 目录模式：**递归两级**（assets/gen/char/<角色>/<图>），跳过已经抠好的 _cut
function collect(dir, depth) {
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (depth > 0) out.push(...collect(p, depth - 1)); continue; }
    if (/\.(png|jpe?g)$/i.test(e.name) && !/_cut\.png$/i.test(e.name)) out.push(p);
  }
  return out;
}
const files = fs.statSync(target).isDirectory() ? collect(target, 2) : [target];
for (const f of files) {
  const outFile = path.join(path.dirname(f), path.basename(f).replace(/\.(png|jpe?g)$/i, '') + '_cut.png');
  if (has('skip-existing') && fs.existsSync(outFile)) continue;
  try { processOne(f, outFile); } catch (e) { console.log('  ✗ ' + path.basename(f) + '：' + e.message); }
}
fs.rmSync(TMP, { recursive: true, force: true });
console.log('抠图完成（mode=' + MODE + ', tol=' + TOL + '）');
