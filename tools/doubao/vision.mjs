// 火山方舟 · 视觉理解（看图说话 / 批量审图 / 读参考图）
//   node tools/doubao/vision.mjs --img 图.png --prompt "描述这张图"
//   node tools/doubao/vision.mjs --img a.png --img b.png --prompt "对比两者风格差异" --save 结论.md
// 一次可传多张；本地路径/URL 都行，本地图自动转 data URI
import fs from 'node:fs';
import path from 'node:path';
import { ark, cli, flag, list, fileToDataUri, config, say, die, WS } from './lib.mjs';

const a = cli();
const prompt = a.prompt || a._[0];
if (!prompt || prompt === true) die('用法：node tools/doubao/vision.mjs --img 图.png [--img 图2.png] --prompt "你想问什么" [--model ID] [--json] [--save 文件]');

const imgs = list(a.img || a.image);
if (!imgs.length) die('至少给一张图：--img 路径或 URL');

const c = config();
const model = a.model || c.models.vision;
const content = imgs.map((f) => ({ type: 'image_url', image_url: { url: fileToDataUri(f) } }));
content.push({ type: 'text', text: String(prompt) });

const body = { model, messages: [{ role: 'user', content }], max_tokens: Number(a['max-tokens'] || 1500) };
say.step('视觉理解  ' + model + '  ' + imgs.length + ' 张图');

const res = await ark('/chat/completions', body, { timeout: 180000 });
const msg = res.json?.choices?.[0]?.message ?? {};
const parts = Array.isArray(msg.content) ? msg.content.map((p) => (typeof p === 'string' ? p : p?.text ?? '')).join('') : msg.content;
const text = typeof parts === 'string' ? parts : '';

if (flag(a, 'json')) console.log(JSON.stringify(res.json, null, 2));
else if (text) console.log(text);
else { say.warn('没有纯文本返回，原样输出：'); console.log(JSON.stringify(msg, null, 2).slice(0, 2000)); }

if (a.save && a.save !== true) {
  const file = path.isAbsolute(String(a.save)) ? String(a.save) : path.join(WS, String(a.save));
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text + '\n');
  say.ok('已存 ' + String(a.save));
}
if (res.json?.usage) say.info('usage ' + JSON.stringify(res.json.usage));
