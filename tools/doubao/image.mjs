// 火山方舟 · 图像生成（Seedream，OpenAI 图像格式）
//   node tools/doubao/image.mjs --prompt "水墨山门，晨雾" [--size 2K] [--name shanmen]
//   node tools/doubao/image.mjs --prompt "改成水墨风" --ref 参考.png --ref 另一张.png
// 产物落到 .ark-out/img/（不进版本库）；要进库自己挑进 assets/
import { ark, cli, flag, list, fileToDataUri, config, outPath, download, rel, say, die, slug, renameToActualExt } from './lib.mjs';
import fs from 'node:fs';

const a = cli();
const prompt = a.prompt || a._[0];
if (!prompt || prompt === true) die('用法：node tools/doubao/image.mjs --prompt "画面描述" [--size 2K] [--n 1] [--ref 参考图] [--model ID] [--name 文件名]');

const c = config();
const model = a.model || c.models.image;
const size = a.size || '2K';
const n = Math.max(1, Number(a.n || 1));
const refs = list(a.ref || a.image);

const body = { model, prompt, size, response_format: 'url', watermark: flag(a, 'watermark') };
if (a.seed !== undefined && a.seed !== true) body.seed = Number(a.seed);
if (refs.length) body.image = refs.map(fileToDataUri);

say.step('Seedream 出图  ' + model + '  ' + size + (refs.length ? '  垫图 ' + refs.length + ' 张' : ''));
say.info(String(prompt).slice(0, 90) + (String(prompt).length > 90 ? '…' : ''));

const saved = [];
for (let i = 0; i < n; i++) {
  const res = await ark('/images/generations', body, { timeout: 300000 });
  const data = res.json?.data ?? [];
  if (!data.length) die('没拿到图像：' + res.text.slice(0, 300));
  for (const [k, item] of data.entries()) {
    const tail = (n > 1 ? '-' + (i + 1) : '') + (data.length > 1 ? '-' + (k + 1) : '');
    const name = (a.name && a.name !== true ? String(a.name) : slug(prompt)) + tail;
    const file = outPath(name, 'png');
    if (item.url) {
      const bytes = await download(item.url, file);
      const fixed = renameToActualExt(file);
      say.ok(rel(fixed) + '   ' + (bytes / 1024).toFixed(0) + ' KB');
      saved.push(fixed);
    } else if (item.b64_json) {
      fs.writeFileSync(file, Buffer.from(item.b64_json, 'base64'));
      const fixed = renameToActualExt(file);
      say.ok(rel(fixed));
      saved.push(fixed);
    }
  }
  if (res.json?.usage) say.info('usage ' + JSON.stringify(res.json.usage));
}
if (saved.length) say.info('验收：node tools/doubao/vision.mjs --img ' + rel(saved[0]) + ' --prompt "画面是否达标？中国元素/构图/可切片"');
