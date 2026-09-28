// 局部重绘（inpaint）· LiblibAI
// ------------------------------------------------------------------
// 用途：「只改一个局部，其余 100% 不动」——img2img 做不到这件事
//       （低 denoise 保不住构图，高 denoise 会把整张画重画）。
//
// 用法：
//   node tools/inpaint_liblib.mjs --base <原图> --rect "x,y,w,h" [--rect ...] \
//        --prompt "把这里换成…" [--denoise 0.8] [--out <输出>]
//   node tools/inpaint_liblib.mjs --base <原图> --mask <蒙版.png> --prompt "…"
//
// 蒙版规则：白色 = 要重绘的区域，黑色 = 保留。
//   给了 --rect 会自动生成蒙版（rect 可给多次，坐标是原图像素）。
// ------------------------------------------------------------------
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import zlib from 'node:zlib';

const BASE = 'https://openapi.liblibai.cloud';
const args = process.argv.slice(2);
const has = (f) => args.includes('--' + f);
const opt = (f, d) => { const i = args.indexOf('--' + f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
const all = (f) => args.reduce((a, v, i) => (v === '--' + f ? [...a, args[i + 1]] : a), []);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const CONF = [path.resolve('.liblib.json'), path.join(os.homedir(), '.liblib', 'liblib.json')]
  .find((p) => { try { return fs.existsSync(p); } catch { return false; } });
const cfg = JSON.parse(fs.readFileSync(CONF, 'utf8'));

// ---------- 签名 ----------
function signedPath(uri, ak, sk) {
  const ts = Date.now();
  const nonce = crypto.randomBytes(16).toString('hex').slice(0, 16);
  const sig = crypto.createHmac('sha1', sk).update(uri + '&' + ts + '&' + nonce).digest('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return uri + '?AccessKey=' + ak + '&Signature=' + sig + '&Timestamp=' + ts + '&SignatureNonce=' + nonce;
}
async function api(uri, body, tries = 6) {
  for (let a = 0; ; a++) {
    const r = await fetch(BASE + signedPath(uri, cfg.accessKey, cfg.secretKey), {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    const text = await r.text();
    let j; try { j = JSON.parse(text); } catch { throw new Error('非 JSON [' + r.status + '] ' + text.slice(0, 300)); }
    if (j.code === 429 || j.code === 100054) {
      if (a >= tries) throw new Error('限流 ' + j.msg);
      const w = 15000 * (a + 1); console.log('  …限流，等 ' + (w / 1000) + 's'); await sleep(w); continue;
    }
    if (j.code !== 0) throw new Error('API code=' + j.code + ' msg=' + j.msg + ' | ' + text.slice(0, 200));
    return j.data;
  }
}
async function uploadImage(filePath) {
  const base = path.basename(filePath);
  const ext = base.split('.').pop();
  const sig = await api('/api/generate/upload/signature', { name: base.replace(/\.[^.]+$/, ''), extension: ext });
  const mime = /jpe?g/i.test(ext) ? 'image/jpeg' : 'image/png';
  const form = new FormData();
  form.append('x-oss-signature', sig.xOssSignature);
  form.append('x-oss-date', sig.xOssDate);
  form.append('x-oss-signature-version', sig.xOssSignatureVersion);
  form.append('policy', sig.policy);
  form.append('key', sig.key);
  form.append('x-oss-credential', sig.xOssCredential);
  form.append('x-oss-expires', String(sig.xOssExpires));
  form.append('file', new Blob([fs.readFileSync(filePath)], { type: mime }), base);
  const r = await fetch(sig.postUrl, { method: 'POST', body: form });
  if (!r.ok) throw new Error('上传失败 [' + r.status + ']');
  return new URL(sig.key, sig.postUrl).toString();
}

// ---------- 极简 PNG：读尺寸 / 写蒙版 ----------
function pngSize(buf) {
  if (buf[0] !== 0x89 || buf[1] !== 0x50) throw new Error('不是 PNG');
  return { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
}
function writePng(file, w, h, rgb) {           // rgb: Buffer(w*h*3)
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 3 + 1)] = 0;                  // filter: none
    rgb.copy(raw, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3);
  }
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type), data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(zlib.crc32 ? zlib.crc32(td) >>> 0 : crc32(td));
    return Buffer.concat([len, td, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0)),
  ]));
}
let CRC_T = null;
function crc32(buf) {
  if (!CRC_T) { CRC_T = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; CRC_T[n] = c >>> 0; } }
  let c = 0xffffffff;
  for (const b of buf) c = CRC_T[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

async function main() {
  const basePath = opt('base', '');
  if (!basePath) { console.log('用法：--base <原图> --rect "x,y,w,h"（可多次）--prompt "…" [--denoise 0.8] [--out 输出]'); process.exit(1); }
  const baseBuf = fs.readFileSync(basePath);
  const { w, h } = pngSize(baseBuf);
  const prompt = opt('prompt', '');
  const negative = opt('neg', cfg.negativePrompt || 'ng_deepnegative_v1_75t,(worst quality:2),照片质感,3D渲染,现代器物,玻璃器皿,高脚杯');
  const denoise = parseFloat(opt('denoise', '0.8'));
  const out = opt('out', basePath.replace(/\.png$/i, '') + '_inpaint.png');

  // 蒙版
  let maskPath = opt('mask', '');
  if (!maskPath) {
    const rects = all('rect').map((s) => s.split(',').map(Number));
    if (!rects.length) { console.log('✗ 需要 --rect 或 --mask'); process.exit(1); }
    const rgb = Buffer.alloc(w * h * 3, 0);
    for (const [rx, ry, rw, rh] of rects) {
      for (let y = Math.max(0, ry); y < Math.min(h, ry + rh); y++)
        for (let x = Math.max(0, rx); x < Math.min(w, rx + rw); x++) {
          const i = (y * w + x) * 3; rgb[i] = 255; rgb[i + 1] = 255; rgb[i + 2] = 255;
        }
      console.log('  蒙版区域 x=' + rx + ' y=' + ry + ' w=' + rw + ' h=' + rh);
    }
    maskPath = path.join(path.dirname(out), '._mask.png');
    writePng(maskPath, w, h, rgb);
    console.log('  蒙版已生成 ' + maskPath);
  }

  console.log('原图 ' + w + '×' + h + '   denoise ' + denoise);
  console.log('提示词 ' + prompt.slice(0, 80));

  const [srcUrl, maskUrl] = [await uploadImage(basePath), await uploadImage(maskPath)];
  const payload = {
    templateUuid: cfg.templateUuidInpaint || cfg.templateUuidImg2img || cfg.templateUuid,
    generateParams: {
      checkPointId: cfg.checkPointId,
      prompt, negativePrompt: negative,
      sampler: cfg.sampler, steps: cfg.steps, cfgScale: cfg.cfgScale,
      width: w, height: h, imgCount: 1, randnSource: cfg.randnSource ?? 1,
      seed: parseInt(opt('seed', '-1'), 10), restoreFaces: 0,
      additionalNetwork: cfg.loras,
      sourceImage: srcUrl, maskImage: maskUrl,
      resizeMode: 0, resizedWidth: w, resizedHeight: h,
      mode: 0, denoisingStrength: denoise,
    },
  };
  const sub = await api('/api/generate/webui/inpaint', payload);
  process.stdout.write('提交 ' + sub.generateUuid + ' 等待中');
  let pred = null;
  for (let i = 0; i < 100; i++) {
    await sleep(3000);
    pred = await api('/api/generate/webui/status', { generateUuid: sub.generateUuid });
    process.stdout.write('.');
    if ([5, 6, 7].includes(pred.generateStatus)) break;
  }
  console.log('');
  if (!pred || pred.generateStatus !== 5) { console.log('✗ 失败 status=' + (pred && pred.generateStatus) + ' msg=' + (pred && pred.generateMsg)); process.exit(2); }
  const img = (pred.images || [])[0];
  const bin = Buffer.from(await (await fetch(img.imageUrl)).arrayBuffer());
  fs.writeFileSync(out, bin);
  const mp = path.join(path.dirname(out), '._mask.png');
  if (fs.existsSync(mp)) fs.rmSync(mp);
  console.log('✓ ' + out + '  消耗=' + pred.pointsCost + '  余额=' + pred.accountBalance);
}
main().catch((e) => { console.error('✗ ' + e.message); process.exit(1); });
