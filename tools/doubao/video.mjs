// 火山方舟 · 视频生成（Seedance）
//   node tools/doubao/video.mjs --prompt "雨夜山道，剑客回首" --dur 5
//   node tools/doubao/video.mjs --prompt "…" --dur 10 --img 首帧.png --ratio 9:16 --res 1080p
//   node tools/doubao/video.mjs --batch tools/ark_plan.json      # 批量；已存在同名产物默认跳过
// 产物落到 .ark-out/video/
import fs from 'node:fs';
import path from 'node:path';
import { ark, cli, flag, fileToDataUri, config, outPath, download, rel, say, die, sleep, WS } from './lib.mjs';

const a = cli();
const c = config();
const model = a.model || c.models.video;
const interval = Math.max(3, Number(a.interval || 10)) * 1000;
function buildBody(prompt, dur, imgPath, ratio, res) {
  const content = [];
  if (imgPath) content.push({ type: 'image_url', image_url: { url: fileToDataUri(imgPath) } });
  content.push({ type: 'text', text: prompt + ' --resolution ' + res + ' --duration ' + dur + ' --ratio ' + ratio });
  return { model, content };
}

async function submit(prompt, dur, imgPath, ratio, res) {
  const body = buildBody(prompt, dur, imgPath, ratio, res);
  const r = await ark('/contents/generations/tasks', body, { timeout: 120000 });
  if (!r.json?.id) die('提交失败，没拿到任务 id：' + r.text.slice(0, 300));
  return r.json.id;
}

async function wait(id, label) {
  const deadline = Date.now() + Math.max(60, Number(a.timeout || 900)) * 1000;
  while (Date.now() < deadline) {
    await sleep(interval);
    const r = await ark('/contents/generations/tasks/' + id, undefined, { method: 'GET', timeout: 60000 });
    const st = r.json?.status;
    process.stdout.write('\r  ' + (label || id) + '  ' + st + '   ');
    if (st === 'succeeded') return r.json;
    if (st === 'failed' || st === 'cancelled') {
      process.stdout.write('\n');
      die('任务 ' + st + '：' + JSON.stringify(r.json?.error || {}).slice(0, 400));
    }
  }
  die('超时（' + Number(a.timeout || 900) + 's）—— 已提交的任务仍在方舟后台跑，可稍后到控制台取');
}

async function run(prompt, dur, imgPath, ratio, res, name) {
  say.step('Seedance 出片  ' + model + '  ' + dur + 's  ' + res + '  ' + ratio + (imgPath ? '  垫图 ' + path.basename(imgPath) : ''));
  const id = await submit(prompt, dur, imgPath, ratio, res);
  say.info('task ' + id);
  const done = await wait(id, name);
  const url = done?.content?.video_url || done?.video_url;
  if (!url) die('任务完成但没拿到视频 URL：' + JSON.stringify(done).slice(0, 400));
  const file = outPath(name, 'mp4', 'video');
  const bytes = await download(url, file);
  process.stdout.write('\n');
  say.ok(rel(file) + '   ' + (bytes / 1024 / 1024).toFixed(1) + ' MB');
  return file;
}

if (a.batch) {
  const planFile = path.resolve(WS, a.batch === true ? 'tools/ark_plan.json' : String(a.batch));
  const plan = JSON.parse(fs.readFileSync(planFile, 'utf8'));
  say.step('批量 ' + plan.length + ' 条：' + rel(planFile));
  for (const item of plan) {
    const name = item.id || ('clip-' + Date.now());
    const existing = outPath(name, 'mp4', 'video');
    if (fs.existsSync(existing) && !flag(a, 'force')) { say.info('跳过 ' + name + '（已存在）'); continue; }
    await run(item.prompt, item.dur || 5, item.img ? path.resolve(WS, item.img) : null, item.ratio || '16:9', item.res || '720p', name);
  }
} else {
  const prompt = a.prompt || a._[0];
  if (!prompt || prompt === true) die('用法：node tools/doubao/video.mjs --prompt "提示词" --dur 5 [--img 首帧] [--ratio 16:9] [--res 720p] [--name 文件名]；或 --batch tools/ark_plan.json');
  await run(String(prompt), Number(a.dur || 5), a.img && a.img !== true ? String(a.img) : null, a.ratio || '16:9', a.res || '720p', a.name && a.name !== true ? String(a.name) : null);
}
