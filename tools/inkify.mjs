// ============================================================
// 素材"水墨化"（v69）：把外部素材（2.5D 手绘描边风等）过一遍 Liblib img2img，
//   统一成本作的纸白水墨语言——低重绘保结构、改画风。
//
// 用法：
//   node tools/inkify.mjs --in "素材/res_mirror/pic/fangzi.png" --out fangzi --prompt "一间茅草顶的村舍"
//   node tools/inkify.mjs --batch tools/ink_list.json      # 批量
// 输出：assets/gen/ink/<out>.png
// ============================================================
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';

const BASE = 'https://openapi.liblibai.cloud';
const HERE = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const CONF = [process.env.LIBLIB_CONF, path.join(HERE, '..', '.liblib.json'), path.resolve('.liblib.json')]
  .find((p) => { try { return fs.existsSync(p); } catch { return false; } }) || '';
const OUT_DIR = path.resolve('assets/gen/ink');

const args = process.argv.slice(2);
const opt = (f, d) => { const i = args.indexOf('--' + f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
const has = (f) => args.includes('--' + f);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// 统一的水墨尾巴：结构交给垫图，画风交给这几句
const INK_TAIL = '，中国水墨画，宣纸质感，墨分五色、以淡墨为主，笔触写意洒脱、有飞白与枯笔，赭石与花青仅作极淡点缀，大面积留白，纯白背景，画面干净，画面中没有文字没有印章没有水印没有logo';
const NEG = '照片,3D渲染,厚涂油画,高饱和度,鲜艳色彩,描边过重,深色背景,复杂背景,文字,水印,logo,人物,人';

function signedPath(uri, ak, sk) {
  const ts = Date.now();
  const nonce = crypto.randomBytes(16).toString('hex').slice(0, 16);
  const sig = crypto.createHmac('sha1', sk).update(uri + '&' + ts + '&' + nonce).digest('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return uri + '?AccessKey=' + ak + '&Signature=' + sig + '&Timestamp=' + ts + '&SignatureNonce=' + nonce;
}
async function api(uri, cfg, body, tries = 6) {
  for (let i = 0; ; i++) {
    const r = await fetch(BASE + signedPath(uri, cfg.accessKey, cfg.secretKey), {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    const t = await r.text();
    let j; try { j = JSON.parse(t); } catch { throw new Error('非 JSON [' + r.status + '] ' + t.slice(0, 200)); }
    if (j.code === 429 || j.code === 100054) {
      if (i >= tries) throw new Error('限流：' + j.msg);
      await sleep(15000 * (i + 1)); continue;
    }
    if (j.code !== 0) throw new Error('code=' + j.code + ' ' + j.msg);
    return j.data;
  }
}
async function upload(file, cfg) {
  const base = path.basename(file);
  const ext = base.split('.').pop();
  const sig = await api('/api/generate/upload/signature', cfg, { name: base.replace(/\.[^.]+$/, ''), extension: ext });
  const mime = /jpe?g$/i.test(ext) ? 'image/jpeg' : 'image/png';
  const form = new FormData();
  form.append('x-oss-signature', sig.xOssSignature);
  form.append('x-oss-date', sig.xOssDate);
  form.append('x-oss-signature-version', sig.xOssSignatureVersion);
  form.append('policy', sig.policy);
  form.append('key', sig.key);
  form.append('x-oss-credential', sig.xOssCredential);
  form.append('x-oss-expires', String(sig.xOssExpires));
  form.append('file', new Blob([fs.readFileSync(file)], { type: mime }), base);
  const r = await fetch(sig.postUrl, { method: 'POST', body: form });
  if (!r.ok) throw new Error('上传失败 [' + r.status + ']');
  return new URL(sig.key, sig.postUrl).toString();
}

async function one(cfg, src, outName, prompt, denoise, size) {
  const [w, h] = size;
  const url = await upload(src, cfg);
  const payload = {
    templateUuid: cfg.templateUuidImg2img || cfg.templateUuid,
    generateParams: {
      checkPointId: cfg.checkPointId,
      prompt: (prompt + INK_TAIL).slice(0, 2000),
      negativePrompt: NEG,
      sampler: cfg.sampler, steps: cfg.steps, cfgScale: cfg.cfgScale,
      width: w, height: h, imgCount: 1, randnSource: cfg.randnSource ?? 1, seed: -1, restoreFaces: 0,
      sourceImage: url, resizeMode: 0, resizedWidth: w, resizedHeight: h, mode: 0,
      denoisingStrength: denoise,
    },
  };
  const sub = await api('/api/generate/webui/img2img', cfg, payload);
  process.stdout.write('  ' + outName + ' 提交 ' + sub.generateUuid.slice(0, 8) + ' ');
  let pred = null;
  for (let i = 0; i < 100; i++) {
    await sleep(3000);
    pred = await api('/api/generate/webui/status', cfg, { generateUuid: sub.generateUuid });
    process.stdout.write('.');
    if (pred.generateStatus === 5 || [6, 7].includes(pred.generateStatus)) break;
  }
  process.stdout.write('\n');
  if (!pred || pred.generateStatus !== 5) throw new Error('status=' + (pred && pred.generateStatus) + ' ' + (pred && pred.generateMsg));
  const img = (pred.images || [])[0];
  const bin = Buffer.from(await (await fetch(img.imageUrl)).arrayBuffer());
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const dst = path.join(OUT_DIR, outName + '.png');
  fs.writeFileSync(dst, bin);
  console.log('  ✓ ' + outName + '  ' + pred.pointsCost + ' 积分（余额 ' + pred.accountBalance + '）');
}

async function main() {
  const cfg = JSON.parse(fs.readFileSync(CONF, 'utf8'));
  const size = [1024, 1024];
  if (has('batch')) {
    const list = JSON.parse(fs.readFileSync(opt('batch', ''), 'utf8'));
    for (const it of list) {
      try { await one(cfg, it.in, it.out, it.prompt, it.denoise ?? 0.52, it.size ?? size); }
      catch (e) { console.log('  ✗ ' + it.out + '：' + e.message); }
    }
    return;
  }
  const src = opt('in', '');
  if (!src) { console.log('用法：node tools/inkify.mjs --in <图> --out <名> --prompt "..." [--denoise 0.52]'); return; }
  await one(cfg, src, opt('out', 'ink_' + Date.now()), opt('prompt', '一件中国古代器物'), parseFloat(opt('denoise', '0.52')), size);
}
main().catch((e) => { console.error(e); process.exit(1); });
