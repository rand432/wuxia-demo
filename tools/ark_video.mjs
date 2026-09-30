// 火山方舟 · 视频生成（Doubao-Seedance 2.5）
// ------------------------------------------------------------------
// 用法：
//   node tools/ark_video.mjs --prompt "提示词" --dur 5 [--img 首帧.png] [--out 输出.mp4]
//   node tools/ark_video.mjs --batch            # 读 tools/ark_plan.json 批量出
//
// Key 读取顺序：环境变量 ARK_API_KEY → .ark.json 里的 apiKey
// ------------------------------------------------------------------
import fs from 'node:fs';
import path from 'node:path';

const BASE = 'https://ark.cn-beijing.volces.com/api/v3';
const MODEL = 'doubao-seedance-2-5-260628';
const WS = 'D:/1/wuxia-demo';
const args = process.argv.slice(2);
const has = (f) => args.includes('--' + f);
const opt = (f, d) => { const i = args.indexOf('--' + f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function getKey() {
  if (process.env.ARK_API_KEY) return process.env.ARK_API_KEY.trim();
  for (const p of [WS + '/.ark.json', path.join(process.env.USERPROFILE || '', '.ark.json')]) {
    try { const j = JSON.parse(fs.readFileSync(p, 'utf8')); if (j.apiKey) return j.apiKey.trim(); } catch {}
  }
  console.error('✗ 找不到 API Key：设环境变量 ARK_API_KEY，或建 ' + WS + '/.ark.json 写 {"apiKey":"..."}');
  process.exit(1);
}
const KEY = getKey();
const H = { 'Content-Type': 'application/json', Authorization: 'Bearer ' + KEY };

// 提交一个生成任务
async function submit(prompt, dur, imgPath, ratio = '16:9', res = '720p') {
  const content = [];
  if (imgPath) {
    const b64 = fs.readFileSync(imgPath).toString('base64');
    const ext = path.extname(imgPath).slice(1).toLowerCase();
    content.push({ type: 'image_url', image_url: { url: 'data:image/' + (ext === 'jpg' ? 'jpeg' : ext) + ';base64,' + b64 } });
  }
  // 参数写在文本末尾（方舟的约定）
  content.push({ type: 'text', text: prompt + ' --resolution ' + res + ' --duration ' + dur + ' --ratio ' + ratio });
  const body = { model: MODEL, content };
  const r = await fetch(BASE + '/contents/generations/tasks', { method: 'POST', headers: H, body: JSON.stringify(body) });
  const t = await r.text();
  let j; try { j = JSON.parse(t); } catch { throw new Error('非 JSON [' + r.status + '] ' + t.slice(0, 300)); }
  if (j.error) throw new Error('提交失败：' + JSON.stringify(j.error).slice(0, 300));
  return j.id;
}
// 轮询直到完成
async function wait(id, label) {
  for (let i = 0; i < 240; i++) {
    await sleep(10000);
    const r = await fetch(BASE + '/contents/generations/tasks/' + id, { headers: H });
    const j = await r.json();
    const st = j.status;
    process.stdout.write('\r  ' + (label || id) + '  ' + st + '  ' + ((i + 1) * 10) + 's   ');
    if (st === 'succeeded') { process.stdout.write('\n'); return j; }
    if (st === 'failed' || st === 'cancelled') { process.stdout.write('\n'); throw new Error('任务 ' + st + '：' + JSON.stringify(j.error || {}).slice(0, 250)); }
  }
  throw new Error('超时');
}
async function download(url, out) {
  const r = await fetch(url);
  if (!r.ok) throw new Error('下载失败 ' + r.status);
  fs.writeFileSync(out, Buffer.from(await r.arrayBuffer()));
  return fs.statSync(out).size;
}

async function main() {
  if (has('batch')) {
    const plan = JSON.parse(fs.readFileSync(WS + '/tools/ark_plan.json', 'utf8'));
    const OUT = WS + '/assets/gen/ark';
    fs.mkdirSync(OUT, { recursive: true });
    let spent = 0;
    for (const it of plan) {
      const out = OUT + '/' + it.id + '.mp4';
      if (fs.existsSync(out) && !has('force')) { console.log('跳过 ' + it.id + '（已存在）'); continue; }
      console.log('── ' + it.id + '  ' + it.dur + 's' + (it.img ? '  垫图 ' + path.basename(it.img) : ''));
      try {
        const id = await submit(it.prompt, it.dur, it.img ? WS + '/' + it.img : null, it.ratio, it.res);
        const j = await wait(id, it.id);
        const url = (j.content && j.content.video_url) || j.video_url;
        if (!url) { console.log('  ✗ 没拿到视频 URL：' + JSON.stringify(j).slice(0, 300)); continue; }
        const sz = await download(url, out);
        spent += (j.usage && j.usage.total_tokens ? j.usage.total_tokens : 0);
        console.log('  ✓ ' + path.basename(out) + '  ' + (sz / 1048576).toFixed(2) + ' MB  tokens=' + (j.usage ? j.usage.total_tokens : '?'));
      } catch (e) { console.log('  ✗ ' + it.id + '：' + e.message); }
    }
    console.log('\n合计 tokens ' + spent + '（按 70 元/百万 ≈ ' + (spent / 1e6 * 70).toFixed(1) + ' 元）');
    return;
  }
  const prompt = opt('prompt', '');
  if (!prompt) { console.log('用法：--prompt "..." --dur 5 [--img 首帧.png] [--out 输出.mp4]'); process.exit(1); }
  const dur = parseInt(opt('dur', '5'), 10);
  const img = opt('img', '');
  const out = opt('out', WS + '/assets/gen/ark/out_' + Date.now() + '.mp4');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  console.log('提交 ' + MODEL + '  ' + dur + 's  ' + (img ? '垫图 ' + path.basename(img) : '纯文本'));
  const id = await submit(prompt, dur, img || null, opt('ratio', '16:9'), opt('res', '720p'));
  console.log('  任务 ' + id);
  const j = await wait(id);
  const url = (j.content && j.content.video_url) || j.video_url;
  if (!url) { console.log('✗ 没拿到视频 URL：' + JSON.stringify(j).slice(0, 400)); process.exit(2); }
  const sz = await download(url, out);
  console.log('✓ ' + out + '  ' + (sz / 1048576).toFixed(2) + ' MB  tokens=' + (j.usage ? j.usage.total_tokens : '?'));
}
main().catch((e) => { console.error('\n✗ ' + e.message); process.exit(1); });
