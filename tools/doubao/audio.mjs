// 火山 · 豆包音频生成（SeedAudio 1.0）——一句提示词生成整段音频：
// 音效 / 环境声 / 音乐 / 带情绪的对白，全都写在同一句 text_prompt 里。
//   node tools/doubao/audio.mjs --prompt "深夜客栈，木门吱呀推开，远处虫鸣，掌柜用沙哑嗓音说：'客官，打尖还是住店？'"
//   node tools/doubao/audio.mjs --prompt "轻快的马林巴与琵琶，武侠赶路，节奏明快" --name bgm-01
// 产物落到 .ark-out/audio/
import fs from 'node:fs';
import path from 'node:path';
import { cli, config, http, outPath, rel, say, die, stamp, WS } from './lib.mjs';

const a = cli();
let prompt = a.prompt || a.scene || a._[0];
if (a.file && a.file !== true) {
  const f = path.isAbsolute(String(a.file)) ? String(a.file) : path.join(WS, String(a.file));
  if (!fs.existsSync(f)) die('找不到文件：' + f);
  prompt = fs.readFileSync(f, 'utf8');
}
if (!prompt || prompt === true) die('用法：node tools/doubao/audio.mjs --prompt "场景/对白描述" [--format mp3] [--sample-rate 24000] [--speed 0] [--pitch 0] [--name 文件名]');

const c = config();
const key = (a.key && a.key !== true ? String(a.key) : '') || c.audio.apiKey;
if (!key) {
  die('音频生成要一把 AI Hub 的 Key（不是方舟那把）：\n' +
    '  AI Hub 页面 → 豆包音频生成模型 → API 接入 → STEP 1，把 API Key 写进 .ark.json：\n' +
    '  "audio": { "apiKey": "…", "model": "seed-audio-1.0" }');
}

const model = (a.model && a.model !== true ? String(a.model) : '') || c.audio.model;
const format = String(a.format || 'mp3').toLowerCase();
const original = String(prompt).trim();
const body = {
  model,
  text_prompt: original,
  audio_config: {
    format,
    sample_rate: Number(a['sample-rate'] || 24000),
    pitch_rate: Number(a.pitch || 0),
    speech_rate: Number(a.speed || 0),
    loudness_rate: Number(a.loudness || 0),
  },
  watermark: {},
};

say.step('音频生成  ' + model + '  ' + format + '  ' + body.audio_config.sample_rate + 'Hz');
say.info(original.slice(0, 90) + (original.length > 90 ? '…' : ''));

const res = await http(c.audio.endpoint, {
  method: 'POST',
  body,
  headers: { 'X-Api-Key': key },
  timeout: 300000,
});

if (!res.ok) die('音频接口失败 [' + res.status + ']：' + res.text.slice(0, 300));
const b64 = res.json?.audio;
if (!b64) die('没有返回 audio 字段：' + res.text.slice(0, 300));

const buf = Buffer.from(b64, 'base64');
const name = a.name && a.name !== true ? String(a.name) : 'audio-' + stamp();
const file = outPath(name, format, 'audio');
fs.writeFileSync(file, buf);
say.ok(rel(file) + '   ' + (buf.length / 1024).toFixed(0) + ' KB');
if (a.json) console.log(JSON.stringify({ ...res.json, audio: '<' + b64.length + ' chars base64>' }, null, 2));
