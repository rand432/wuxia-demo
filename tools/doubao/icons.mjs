// 图标批量出图：node tools/doubao/icons.mjs [--only id,id] [--limit N] [--force] [--size 1024x1024] [--concurrency 2]
// 清单：tools/doubao/icon-plan.json（style 是公共前缀，items 逐条）；已存在的自动跳过，可反复跑
import fs from 'node:fs';
import path from 'node:path';
import { ark, cli, flag, config, download, rel, say, die, WS, ensureDir, renameToActualExt } from './lib.mjs';

const a = cli();
const planFile = path.resolve(WS, String(a.plan || 'tools/doubao/icon-plan.json'));
const plan = JSON.parse(fs.readFileSync(planFile, 'utf8'));
const items = Array.isArray(plan) ? plan : (plan.items || []);
const style = Array.isArray(plan) ? '' : (plan.style || '');
const outDir = ensureDir(path.resolve(WS, String(a.out || '.ark-out/icons')));
const size = String(a.size || '1024x1024');
const c = config();
const model = a.model && a.model !== true ? String(a.model) : c.models.image;
const price = Number(a.price || 0.12);
const only = a.only && a.only !== true ? String(a.only).split(',').map(s => s.trim()).filter(Boolean) : null;

let list = items.filter(it => !only || only.includes(it.id));
if (a.limit && a.limit !== true) list = list.slice(0, Number(a.limit));
if (!list.length) die('清单里没有匹配的条目：' + planFile);

const existing = new Set(fs.readdirSync(outDir).map(f => f.replace(/\.[a-z]+$/i, '')));
const pending = [];
let skipped = 0;
for (const it of list) {
  if (existing.has(it.id) && !flag(a, 'force')) { skipped++; continue; }
  pending.push(it);
}

say.step('图标批量  ' + model + '  ' + size);
say.info('选中 ' + list.length + ' · 待出 ' + pending.length + ' · 跳过 ' + skipped + ' · 预估 ' + (pending.length * price).toFixed(2) + ' 元');
if (!pending.length) { say.ok('都出过了，加 --force 可重出'); process.exit(0); }

const results = [];
let cursor = 0;
const conc = Math.max(1, Number(a.concurrency || 2));
async function worker() {
  while (cursor < pending.length) {
    const it = pending[cursor++];
    const prompt = (it.style || style) + '；' + it.prompt;
    const tmp = path.join(outDir, it.id + '.png');
    const t0 = Date.now();
    try {
      const res = await ark('/images/generations', { model, prompt, size, response_format: 'url', watermark: false }, { timeout: 300000 });
      const first = res.json?.data?.[0];
      if (!first || !first.url) throw new Error(res.text.slice(0, 180));
      await download(first.url, tmp);
      const file = renameToActualExt(tmp);
      results.push({ id: it.id, name: it.name, cat: it.cat, file: rel(file), ok: true, ms: Date.now() - t0 });
      say.ok(it.id.padEnd(15) + (it.name || '') + '  ' + rel(file));
    } catch (e) {
      const msg = String((e && e.message) || e).slice(0, 160);
      results.push({ id: it.id, name: it.name, cat: it.cat, ok: false, error: msg, ms: Date.now() - t0 });
      say.warn(it.id.padEnd(15) + '失败：' + msg);
    }
  }
}
await Promise.all(Array.from({ length: Math.min(conc, pending.length) }, worker));

const okCount = results.filter(r => r.ok).length;
const failCount = results.length - okCount;
fs.writeFileSync(path.join(outDir, 'summary.json'), JSON.stringify({ at: new Date().toISOString(), model, size, ok: okCount, fail: failCount, cost: +(okCount * price).toFixed(2), results }, null, 2));
say.step('完成  成功 ' + okCount + ' · 失败 ' + failCount + ' · 约 ' + (okCount * price).toFixed(2) + ' 元');
if (failCount) say.info('失败的重跑一次即可（已存在的会跳过）：node tools/doubao/icons.mjs');
process.exit(failCount ? 1 : 0);
