// tools/edge_tts.mjs —— **免费**在线配音（微软 Edge 的朗读语音）
//   用户："这玩意是美元啊" → MiniMax 国际站按美元计费；这条路一分钱不花、也不用装 Python。
//   原理：edge-tts 那个 Python 包封的就是这个 WSS 接口，Node 24 自带 WebSocket，直连即可。
//
//   用法：node tools/edge_tts.mjs --voice narr --text "雨下了三天。" --out assets/voice/narr_01.mp3
//         node tools/edge_tts.mjs --batch tools/voice_lines.json
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import crypto from 'node:crypto';
import { createRequire } from 'node:module';

// ⚠ 微软要求握手带 Origin/User-Agent（edge-tts 就是这么带才通的），
//   而 Node 内置的 WebSocket **不让改请求头** → 连接被掐（close 1006）。
//   所以优先借 DSH 自带的 ws 包；借不到再退回内置的（大概率连不上，但不会崩）。
const WS_HEADERS = {
  Origin: 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0',
  'Accept-Encoding': 'gzip, deflate, br',
  'Accept-Language': 'en-US,en;q=0.9',
  Pragma: 'no-cache',
  'Cache-Control': 'no-cache',
};
let WSImpl = globalThis.WebSocket;      // 内置（改不了头，兜底用）
let WS_KIND = 'builtin';
for (const base of ['D:/1/DSH Desktop/resources/app/', 'C:/Users/' + (process.env.USERNAME || 'zq300') + '/.dsh/profiles/desktop/']) {
  try {
    const rq = createRequire(base);
    const W = rq('ws');
    if (W) { WSImpl = W; WS_KIND = 'ws(' + base + ')'; break; }
  } catch { /* 换下一个 */ }
}

const TOKEN = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
const CHROMIUM = '1-130.0.2849.68';   // 微软要求的客户端版本串（edge-tts 同款）

// 微软 2024 起加的校验：Sec-MS-GEC = SHA256(「5 分钟对齐的 Windows 文件时间」+ TOKEN)，大写十六进制。
//   少了它服务端直接掐连接（就是刚才那个"连接失败"）。
function secMsGec() {
  const WIN_EPOCH = 11644473600n;              // 1601→1970 的秒差
  let ticks = BigInt(Math.floor(Date.now() / 1000)) + WIN_EPOCH;
  ticks -= ticks % 300n;                        // 向下对齐到 5 分钟
  ticks *= 10000000n;                           // 换算成 100 纳秒
  return crypto.createHash('sha256').update(ticks.toString() + TOKEN).digest('hex').toUpperCase();
}
const WSS = 'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1' +
  '?TrustedClientToken=' + TOKEN +
  '&Sec-MS-GEC=' + secMsGec() +
  '&Sec-MS-GEC-Version=' + CHROMIUM;

// 角色 → 音色（中文，微软那套里最好听的几个）
export const VOICES = {
  narr:     { voice: 'zh-CN-YunyeNeural',    rate: '-8%', pitch: '-3Hz', cn: '云野·沉稳男声（旁白）' },
  player:   { voice: 'zh-CN-YunxiNeural',    rate: '-2%', pitch: '+0Hz', cn: '云希·青年男声（主角）' },
  chenshi:  { voice: 'zh-CN-YunjianNeural',  rate: '-5%', pitch: '-4Hz', cn: '云健·浑厚男声（陈石）' },
  qingluan: { voice: 'zh-CN-XiaoxiaoNeural', rate: '+0%', pitch: '+2Hz', cn: '晓晓·年轻女声（苏青鸾）' },
};

const stamp = () => new Date().toISOString().replace(/\.\d+Z$/, 'Z');
const uid = () => crypto.randomUUID().replace(/-/g, '');

function cfgMsg() {
  return 'X-Timestamp:' + stamp() + '\r\n' +
    'Content-Type:application/json; charset=utf-8\r\n' +
    'Path:speech.config\r\n\r\n' +
    JSON.stringify({ context: { synthesis: { audio: {
      metadataoptions: { sentenceBoundaryEnabled: 'false', wordBoundaryEnabled: 'false' },
      outputFormat: 'audio-24khz-48kbitrate-mono-mp3',
    } } } });
}

function ssmlMsg(text, v) {
  const esc = text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'>" +
    "<voice name='" + v.voice + "'><prosody rate='" + v.rate + "' pitch='" + v.pitch + "'>" + esc + '</prosody></voice></speak>';
  return 'X-RequestId:' + uid() + '\r\n' +
    'Content-Type:application/ssml+xml\r\n' +
    'X-Timestamp:' + stamp() + '\r\n' +
    'Path:ssml\r\n\r\n' + ssml;
}

// 返回 mp3 的 Buffer；失败抛错（把服务端说的话带出来）
export function synth(text, v, timeoutMs = 25000) {
  return new Promise((resolve, reject) => {
    const useWs = WS_KIND !== 'builtin';
    const opts = useWs ? { headers: WS_HEADERS } : undefined;
    const ws = useWs ? new WSImpl(WSS, opts) : new WSImpl(WSS);
    const chunks = [];
    let done = false;
    const finish = (err, buf) => {
      if (done) return;
      done = true; clearTimeout(kill);
      try { ws.close(); } catch {}
      if (err) reject(err); else resolve(buf);
    };
    const kill = setTimeout(() => finish(new Error('超时')), timeoutMs);
    const onText = (s) => {
      if (s.includes('Path:turn.end')) {
        const buf = Buffer.concat(chunks);
        if (buf.length < 200) finish(new Error('没收到音频（服务端可能拒了）'));
        else finish(null, buf);
      }
    };
    const onBin = (b0) => {
      const b = Buffer.from(b0);
      if (b.length < 3) return;
      // 二进制帧：前 2 字节（大端）＝头部长度，跳过它 + 头部，剩下才是音频
      const hlen = b.readUInt16BE(0);
      if (2 + hlen <= b.length) chunks.push(b.subarray(2 + hlen));
    };
    if (useWs) {
      ws.on('open', () => { ws.send(cfgMsg()); ws.send(ssmlMsg(text, v)); });
      ws.on('message', (data, isBinary) => { if (isBinary) onBin(data); else onText(data.toString()); });
      ws.on('error', (e) => finish(new Error('连接失败 ' + (e && e.message ? e.message : ''))));
      ws.on('close', (code) => finish(new Error('提前关闭 code=' + code)));
    } else {
      ws.binaryType = 'arraybuffer';
      ws.onopen = () => { ws.send(cfgMsg()); ws.send(ssmlMsg(text, v)); };
      ws.onmessage = (ev) => { if (typeof ev.data === 'string') onText(ev.data); else onBin(ev.data); };
      ws.onerror = () => finish(new Error('连接失败（内置 WebSocket，改不了请求头）'));
      ws.onclose = (e) => finish(new Error('提前关闭 code=' + e.code));
    }
  });
}

// ---- CLI ----
const args = process.argv.slice(2);
const opt = (k, d = '') => { const i = args.indexOf('--' + k); return i >= 0 && args[i + 1] ? args[i + 1] : d; };

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const batch = opt('batch');
  const jobs = [];
  if (batch) {
    const spec = JSON.parse(fs.readFileSync(batch, 'utf8'));
    for (const it of spec) jobs.push({ voice: it.voice || 'narr', text: it.text, out: it.out });
  } else {
    jobs.push({ voice: opt('voice', 'narr'), text: opt('text'), out: opt('out') });
  }
  for (const j of jobs) {
    const v = VOICES[j.voice] || VOICES.narr;
    if (!j.text || !j.out) { console.log('  ✗ 缺 --text / --out'); continue; }
    try {
      const buf = await synth(j.text, v);
      fs.mkdirSync(path.dirname(j.out), { recursive: true });
      fs.writeFileSync(j.out, buf);
      console.log('  ✓ ' + path.basename(j.out).padEnd(20) + String(Math.round(buf.length / 1024)).padStart(4) + 'KB  ' + v.cn);
    } catch (e) {
      console.log('  ✗ ' + path.basename(j.out) + ' — ' + e.message);
    }
  }
}
