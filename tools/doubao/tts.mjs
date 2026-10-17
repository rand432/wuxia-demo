// 火山 · 语音合成（两条后端，自动挑一条能用的）
//   A 豆包语音原生：openspeech.bytedance.com/api/v1/tts（要 appid + access token）
//   B 方舟 OpenAI 兼容：{base}/audio/speech（要 models.tts，验证到账号开了语音模型再用）
// 用法：
//   node tools/doubao/tts.mjs --text "少侠留步" [--voice zh_female_…] [--emotion happy] [--speed 1.1]
//   node tools/doubao/tts.mjs --file 台词.txt --name suqingluan-01
// 产物落到 .ark-out/tts/
import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { cli, flag, config, http, outPath, rel, say, die, WS, stamp } from './lib.mjs';

const a = cli();
let text = a.text || a._[0];
if (a.file && a.file !== true) {
  const f = path.isAbsolute(String(a.file)) ? String(a.file) : path.join(WS, String(a.file));
  if (!fs.existsSync(f)) die('找不到文件：' + f);
  text = fs.readFileSync(f, 'utf8');
}
if (!text || text === true) die('用法：node tools/doubao/tts.mjs --text "要念的句子" [--voice …] [--emotion happy] [--speed 1] [--format mp3] [--name 文件名]');
text = String(text).trim();
if (!text) die('文本是空的');

const c = config();
const format = String(a.format || 'mp3').toLowerCase();
const voice = String(a.voice || c.tts.voice);
const speed = Number(a.speed || 1);
const name = a.name && a.name !== true ? String(a.name) : 'tts-' + stamp();
const out = outPath(name, format, 'tts');

const native = c.tts.appid && c.tts.token;
const arkTts = c.models.tts && c.apiKey;

say.step('语音合成  ' + (native ? '豆包语音原生' : arkTts ? '方舟 /audio/speech' : '未配置'));
say.info(text.slice(0, 60) + (text.length > 60 ? '…' : '') + '   voice ' + voice + '   ' + text.length + ' 字');

if (native) {
  const body = {
    app: { appid: c.tts.appid, token: c.tts.token, cluster: c.tts.cluster || 'volcano_tts' },
    user: { uid: String(a.uid || 'wuxia-demo') },
    audio: {
      voice_type: voice,
      encoding: format,
      speed_ratio: speed,
      rate: Number(a.rate || 24000),
      bitrate: Number(a.bitrate || 160),
      loudness_ratio: Number(a.loudness || 1),
    },
    request: { reqid: randomUUID(), text, operation: 'query' },
  };
  if (a.emotion && a.emotion !== true) body.audio.emotion = String(a.emotion);
  if (a.emotion_scale) body.audio.emotion_scale = Number(a.emotion_scale);

  const nativeUrl = process.env.DOUBAO_TTS_URL || 'https://openspeech.bytedance.com/api/v1/tts';
  const res = await http(nativeUrl, {
    method: 'POST',
    body,
    headers: { Authorization: 'Bearer;' + c.tts.token },
    timeout: 120000,
  });
  const json = res.json;
  if (!json) die('返回不是 JSON [' + res.status + ']：' + res.text.slice(0, 300));
  if (json.code !== 3000 || !json.data) {
    const hints = {
      3001: '无效请求参数（voice_type / encoding 拼错？）',
      3003: '并发超限',
      3005: '后端服务超时',
      3006: '服务未授权（appid/token 跟当前语音应用对不上）',
      3007: '文本长度超限',
      3010: '文本长度超限',
      45000001: '请求参数错误',
      45000002: '空文本',
    };
    die('语音合成失败 code=' + json.code + ' ' + (json.message || '') + (hints[json.code] ? '\n  → ' + hints[json.code] : ''));
  }
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, Buffer.from(json.data, 'base64'));
  say.ok(rel(out) + '   ' + (fs.statSync(out).size / 1024).toFixed(0) + ' KB   ' + format);
  if (json.addition?.duration) say.info('时长 ' + json.addition.duration + ' ms');
} else if (arkTts) {
  const res = await http(c.base + '/audio/speech', {
    method: 'POST',
    body: { model: c.models.tts, input: text, voice, response_format: format, speed },
    headers: { Authorization: 'Bearer ' + c.apiKey },
    timeout: 120000,
  });
  if (!res.ok) die('方舟 /audio/speech 失败 [' + res.status + ']：' + res.text.slice(0, 300) + '\n  → 若 404，说明账号没开语音模型，改用豆包语音原生（.ark.json 的 tts.appid/token）');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, res.buf);
  say.ok(rel(out) + '   ' + (res.buf.length / 1024).toFixed(0) + ' KB');
} else {
  die('语音要用一套凭证，二选一：\n' +
    '  A) 豆包语音（推荐）：语音技术控制台建应用，拿 appid + access token，写进 .ark.json：\n' +
    '     "tts": { "appid": "…", "token": "…", "voice": "zh_female_shuangkuaisisi_moon_bigtts" }\n' +
    '  B) 方舟语音模型：确认控制台开通了语音模型后，把模型 ID 填进 models.tts');
}
