// ============================================================
// 智谱 CogVideoX-Flash 出片（免费模型）——LibTV 算力不足时的备用通道
//   用法：node tools/gen_video_zhipu.mjs <参考图> --prompt "..." [--out 名字] [--model cogvideox-flash]
//   流程：图 → base64 → POST /videos/generations → 轮询 /async-result/{id} → 下 mp4
//   key 与 modlens 共用（~/.modlens/config.json）
// ============================================================
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const FFMPEG = process.env.FFMPEG || 'C:\\Users\\zq300\\ffmpeg\\bin\\ffmpeg.exe';
const args = process.argv.slice(2);
const img = args.find((a) => !a.startsWith('--'));
const opt = (f, d) => { const i = args.indexOf('--' + f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
if (!img) { console.log('用法：node tools/gen_video_zhipu.mjs <参考图> --prompt "..." [--out 名字]'); process.exit(1); }
const prompt = opt('prompt', '');
const model = opt('model', 'cogvideox-flash');
const outName = opt('out', 'vid_' + Date.now());
const size = opt('size', '1080x1920');

const key = JSON.parse(fs.readFileSync(path.join(os.homedir(), '.modlens', 'config.json'), 'utf8'))?.providers?.openai?.apiKey ?? '';
if (!key) { console.log('✗ 没找到智谱 key'); process.exit(1); }

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// 压成 jpeg 再 base64（原 PNG 太大，接口会嫌）
const tmp = path.join(os.tmpdir(), 'vidin_' + Date.now() + '.jpg');
const sc = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', img, '-vf', 'scale=1024:-2', '-q:v', '4', tmp], { stdio: 'ignore' });
if (sc.status !== 0) { console.log('✗ 转 jpeg 失败'); process.exit(1); }
const b64 = fs.readFileSync(tmp).toString('base64');
console.log('参考图 ' + Math.round(fs.statSync(tmp).size / 1024) + 'KB → base64 ' + Math.round(b64.length / 1024) + 'KB');

const body = { model, prompt, image_url: 'data:image/jpeg;base64,' + b64 };
let r = await fetch('https://open.bigmodel.cn/api/paas/v4/videos/generations', {
  method: 'POST', headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' }, body: JSON.stringify(body),
});
let t = await r.text();
console.log('提交 [' + r.status + '] ' + t.slice(0, 400));
if (!r.ok) process.exit(1);
const job = JSON.parse(t);
const id = job.id || job.request_id;
for (let i = 0; i < 100; i++) {
  await sleep(6000);
  const rr = await fetch('https://open.bigmodel.cn/api/paas/v4/async-result/' + id, { headers: { Authorization: 'Bearer ' + key } });
  const tt = await rr.text();
  let j; try { j = JSON.parse(tt); } catch { console.log('  轮询返回非 JSON：' + tt.slice(0, 200)); continue; }
  const st = j.task_status || j.status;
  process.stdout.write('  ' + (i + 1) + ' ' + st + '\n');
  if (st === 'SUCCESS') {
    const url = (j.video_result || [])[0]?.url || j.video_url;
    if (!url) { console.log('✗ 成功但没拿到 url：' + tt.slice(0, 300)); process.exit(1); }
    const bin = Buffer.from(await (await fetch(url)).arrayBuffer());
    const outDir = path.resolve('assets/gen/aivideo');
    fs.mkdirSync(outDir, { recursive: true });
    const out = path.join(outDir, outName + '.mp4');
    fs.writeFileSync(out, bin);
    console.log('✓ ' + out + '  ' + (bin.length / 1024 / 1024).toFixed(2) + ' MB');
    process.exit(0);
  }
  if (st === 'FAIL' || st === 'FAILED') { console.log('✗ 生成失败：' + tt.slice(0, 400)); process.exit(1); }
}
console.log('✗ 超时未完成');
