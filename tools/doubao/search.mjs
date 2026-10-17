// 火山方舟 · 联网搜索（智能体 / bot 形态）
//   node tools/doubao/search.mjs --query "2026 武侠手游买量素材趋势"
// 说明：方舟的联网搜索挂在「智能体应用」上，先到控制台建一个开了联网插件的应用，
//      把 bot-xxxx 写进 .ark.json 的 search.botId（或 --bot 传），本脚本走 /bots/chat/completions。
import { ark, cli, flag, config, say, die } from './lib.mjs';

const a = cli();
const q = a.query || a._[0];
if (!q || q === true) die('用法：node tools/doubao/search.mjs --query "要查什么" [--bot bot-xxx] [--model 模型ID] [--json]');

const c = config();
const bot = (a.bot && a.bot !== true ? String(a.bot) : '') || c.search.botId;

if (!bot) {
  die('联网搜索还缺一个「智能体」ID：\n' +
    '  1) 方舟控制台 → 智能体 / 应用 → 新建，插件里勾「联网搜索」\n' +
    '  2) 发布后拿 bot-xxxxxxxx，写进 .ark.json：{ "search": { "botId": "bot-…" } }\n' +
    '  （不想配也行：DSH 自带的 web_search 已经能联网，豆包这条主要是拿它的检索+摘要质量）');
}

say.step('联网搜索  ' + bot);
say.info(String(q).slice(0, 80));

const res = await ark('/bots/chat/completions', {
  model: bot,
  messages: [{ role: 'user', content: String(q) }],
  stream: false,
}, { timeout: 180000 });

if (flag(a, 'json')) { console.log(JSON.stringify(res.json, null, 2)); }
else {
  const msg = res.json?.choices?.[0]?.message ?? {};
  const parts = Array.isArray(msg.content) ? msg.content.map((p) => (typeof p === 'string' ? p : p?.text ?? '')).join('') : msg.content;
  if (parts) console.log(parts);
  else { say.warn('没有文本内容，原样输出：'); console.log(JSON.stringify(res.json, null, 2).slice(0, 2000)); }
}
const refs = res.json?.references ?? res.json?.choices?.[0]?.message?.references;
if (Array.isArray(refs) && refs.length) {
  say.info('引用的来源：');
  for (const r of refs.slice(0, 10)) say.info('· ' + (r.title || r.site_name || '') + ' ' + (r.url || ''));
}
