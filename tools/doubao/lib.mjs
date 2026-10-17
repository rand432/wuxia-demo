// 火山方舟（豆包）公共客户端 —— tools/doubao/*
// ------------------------------------------------------------------
// Key 读取顺序：环境变量 → 工程根 .ark.json → 用户目录 .ark.json
// 配置文件形如：
//   {
//     "apiKey": "…",
//     "baseURL": "https://ark.cn-beijing.volces.com/api/v3",
//     "models": { "vision": "…", "image": "…", "video": "…", "tts": "…" },
//     "tts": { "appid": "…", "token": "…", "voice": "…", "cluster": "volcano_tts" },
//     "search": { "botId": "bot-…" }
//   }
// ------------------------------------------------------------------
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const WS = path.resolve(HERE, '..', '..');
export const OUT = path.join(WS, '.ark-out');
export const DEFAULT_BASE = 'https://ark.cn-beijing.volces.com/api/v3';

/** 默认模型 ID —— 一律以方舟控制台「开通管理」里显示的为准，可用 .ark.json 或 --model 覆盖 */
const DEFAULTS = {
  vision: 'doubao-seed-1-6-250615',
  image: 'doubao-seedream-4-0-250828',
  video: 'doubao-seedance-2-5-260628',
  tts: '',
};

function readJson(file) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')) || {}; } catch { return null; }
}

export function config() {
  const home = process.env.USERPROFILE || process.env.HOME || '';
  const found = [path.join(WS, '.ark.json'), path.join(home, '.ark.json')]
    .map((f) => ({ file: f, data: readJson(f) }))
    .find((x) => x.data);
  const file = found ? found.data : {};
  const env = process.env;
  const tts = {
    appid: (env.DOUBAO_TTS_APPID || file.tts?.appid || '').trim(),
    token: (env.DOUBAO_TTS_TOKEN || file.tts?.token || '').trim(),
    voice: (env.DOUBAO_TTS_VOICE || file.tts?.voice || 'zh_female_shuangkuaisisi_moon_bigtts').trim(),
    cluster: (env.DOUBAO_TTS_CLUSTER || file.tts?.cluster || 'volcano_tts').trim(),
  };
  return {
    source: found ? found.file : '',
    apiKey: (env.ARK_API_KEY || file.apiKey || '').trim(),
    base: ((env.ARK_BASE_URL || file.baseURL || DEFAULT_BASE) + '').replace(/\/+$/, ''),
    models: {
      vision: env.DOUBAO_MODEL_VISION || file.models?.vision || DEFAULTS.vision,
      image: env.DOUBAO_MODEL_IMAGE || file.models?.image || DEFAULTS.image,
      video: env.DOUBAO_MODEL_VIDEO || file.models?.video || DEFAULTS.video,
      tts: env.DOUBAO_MODEL_TTS || file.models?.tts || DEFAULTS.tts,
    },
    tts,
    audio: {
      apiKey: (env.DOUBAO_AUDIO_KEY || file.audio?.apiKey || '').trim(),
      model: (env.DOUBAO_AUDIO_MODEL || file.audio?.model || 'seed-audio-1.0').trim(),
      endpoint: (env.DOUBAO_AUDIO_URL || file.audio?.endpoint || 'https://openspeech.bytedance.com/api/v3/tts/create').trim(),
    },
    search: { botId: (env.DOUBAO_BOT_ID || file.search?.botId || '').trim() },
  };
}

export function requireKey(c = config()) {
  if (!c.apiKey) {
    die('找不到方舟 API Key。\n' +
      '  · 在 ' + WS + '\\.ark.json 里写 {"apiKey":"…"}（该文件已在 .gitignore，不会推到远端）\n' +
      '  · 或设环境变量 ARK_API_KEY');
  }
  return c;
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** 通用 HTTP：自带超时、5xx/429 退避重试，返回原始 body 供二进制接口使用 */
export async function http(url, opts = {}) {
  const { method = 'POST', body, headers = {}, timeout = 120000, retries = 2 } = opts;
  const payload = body === undefined ? undefined : (typeof body === 'string' || Buffer.isBuffer(body) ? body : JSON.stringify(body));
  const init = { method, headers: { 'Content-Type': 'application/json', ...headers }, body: payload, signal: AbortSignal.timeout(timeout) };
  let last;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await fetch(url, { ...init, signal: AbortSignal.timeout(timeout) });
      const buf = Buffer.from(await res.arrayBuffer());
      const text = buf.toString('utf8');
      let json;
      try { json = JSON.parse(text); } catch { /* 二进制或纯文本 */ }
      if (res.status === 429 || res.status >= 500) {
        last = new Error('HTTP ' + res.status + ' ' + text.slice(0, 200));
        if (attempt < retries) { await sleep(800 * (attempt + 1)); continue; }
      }
      return { status: res.status, ok: res.ok, text, json, buf };
    } catch (e) {
      last = e;
      if (attempt < retries) await sleep(800 * (attempt + 1));
    }
  }
  throw last;
}

const HINTS = [
  [/AuthenticationError|401|403/i, 'Key 无效或无权限：检查 .ark.json 的 apiKey / 账号实名与权限'],
  [/ModelNotOpen|model_not_found|not activated|404/i, '模型未开通：到方舟控制台「开通管理」开通该模型，或换 models 里的 ID'],
  [/QuotaExceeded|InsufficientBalance|402/i, '额度/余额不足：控制台充值或换套餐'],
  [/RateLimit|429/i, '限流：降低并发或稍后重试'],
  [/InvalidParameter|400/i, '参数不合法：看报错里的 param 字段'],
];

function hintOf(text) {
  for (const [re, h] of HINTS) if (re.test(text)) return h;
  return '';
}

/** 调方舟 REST：自动拼 base、带 Bearer Key，失败时抛出带建议的异常 */
export async function ark(pathOrUrl, body, opts = {}) {
  const c = requireKey();
  const url = /^https?:/i.test(pathOrUrl) ? pathOrUrl : c.base + pathOrUrl;
  const res = await http(url, { ...opts, body, headers: { Authorization: 'Bearer ' + c.apiKey, ...(opts.headers || {}) } });
  if (!res.ok || (res.json && res.json.error)) {
    const detail = res.json?.error ? (res.json.error.code + ': ' + res.json.error.message) : res.text.slice(0, 300);
    const hint = hintOf(detail);
    die('方舟接口失败 [' + res.status + '] ' + url.replace(c.base, '') + '\n  ' + detail + (hint ? '\n  → ' + hint : ''));
  }
  return res;
}

/** 把返回体里的 error 也当失败（部分接口 HTTP 200 但带 error） */
export function ensureOk(res, where) {
  if (res.json?.error) die(where + ' 失败：' + JSON.stringify(res.json.error).slice(0, 300));
  return res.json;
}

export async function download(url, file) {
  const res = await fetch(url, { signal: AbortSignal.timeout(180000) });
  if (!res.ok) throw new Error('下载失败 HTTP ' + res.status + ' ' + url.slice(0, 120));
  const buf = Buffer.from(await res.arrayBuffer());
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, buf);
  return buf.length;
}

export function ensureDir(dir) { fs.mkdirSync(dir, { recursive: true }); return dir; }

export function stamp(d = new Date()) {
  const p = (n) => String(n).padStart(2, '0');
  return d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + '-' + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds());
}

export function slug(text, max = 28) {
  const s = (text || '').replace(/[^\p{Script=Han}A-Za-z0-9]+/gu, '').slice(0, max);
  return s || 'untitled';
}

export function outPath(name, ext, sub = 'img') {
  const dir = ensureDir(path.join(OUT, sub));
  const base = name && !name.includes('/') && !name.includes('\\') ? name : (name || stamp());
  return path.join(dir, base.endsWith('.' + ext) ? base : base + '.' + ext);
}

/** 极简 CLI 解析：--key value / --flag / 同名重复自动变数组 */
export function cli(argv = process.argv.slice(2)) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) { out._.push(a); continue; }
    const key = a.slice(2);
    const next = argv[i + 1];
    const value = next === undefined || next.startsWith('--') ? true : (i++, next);
    if (out[key] === undefined) out[key] = value;
    else out[key] = [].concat(out[key], value);
  }
  return out;
}

export const list = (v) => (v === undefined ? [] : [].concat(v).filter((x) => x !== true));
export const flag = (a, k) => a[k] === true || a[k] === 'true';

export function die(msg) {
  console.error('\u2717 ' + msg);
  process.exit(1);
}

export function money(note) {
  if (note) console.log('  \u26a0 ' + note);
}

export const say = {
  step: (m) => console.log('── ' + m),
  ok: (m) => console.log('  \u2713 ' + m),
  info: (m) => console.log('    ' + m),
  warn: (m) => console.log('  \u26a0 ' + m),
};

/** 本地图片 → data URI（视觉理解/垫图都用得上） */
export function fileToDataUri(file) {
  if (/^https?:/i.test(file)) return file;
  const abs = path.isAbsolute(file) ? file : path.join(WS, file);
  if (!fs.existsSync(abs)) die('找不到文件：' + abs);
  const ext = path.extname(abs).slice(1).toLowerCase();
  const mime = ext === 'jpg' ? 'jpeg' : ext;
  return 'data:image/' + mime + ';base64,' + fs.readFileSync(abs).toString('base64');
}

export function sniffImageExt(buf) {
  if (buf[0] === 0x89 && buf[1] === 0x50) return 'png';
  if (buf[0] === 0xff && buf[1] === 0xd8) return 'jpg';
  if (buf.length > 12 && buf.subarray(0, 4).toString() === 'RIFF' && buf.subarray(8, 12).toString() === 'WEBP') return 'webp';
  return '';
}

/** 方舟出图可能是 JPEG 却按 .png 命名；按真实字节改名，免得导入器/读图报格式不符 */
export function renameToActualExt(file) {
  let buf;
  try { buf = fs.readFileSync(file); } catch { return file; }
  const ext = sniffImageExt(buf);
  if (!ext) return file;
  const want = path.join(path.dirname(file), path.basename(file) + '.' + ext);
  if (want === file || fs.existsSync(want)) return file;
  fs.renameSync(file, want);
  return want;
}

export function rel(file) { return path.relative(WS, file).replace(/\\/g, '/'); }
