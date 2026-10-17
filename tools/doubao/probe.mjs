// 自检：这条路通不通、模型 ID 对不对
//   node tools/doubao/probe.mjs              # 只看配置 + 拉模型列表
//   node tools/doubao/probe.mjs --live       # 真发一次 1 token 的对话，验证 Key 可用（几乎不花钱）
//   node tools/doubao/probe.mjs --match seed  # 过滤模型列表
import { ark, cli, config, say, die, WS } from './lib.mjs';

const a = cli();
const c = config();

say.step('配置来源');
say.ok(c.source ? c.source : '（没有 .ark.json，走环境变量/默认值）');
say.info('apiKey   ' + (c.apiKey ? c.apiKey.slice(0, 6) + '…' + c.apiKey.slice(-4) : '（空）'));
say.info('baseURL  ' + c.base);
say.info('语音凭证 ' + (c.tts.appid && c.tts.token ? '豆包语音 appid/token 已配置' : '（空）') + '   models.tts ' + (c.models.tts || '（空）'));
say.info('音频 Key ' + (c.audio.apiKey ? c.audio.apiKey.slice(0, 6) + '…' + c.audio.apiKey.slice(-4) : '（空）') + '   ' + c.audio.model);
say.info('联网 bot ' + (c.search.botId || '（空）'));

say.step('能力矩阵');
const rows = [
  ['图像 Seedream', c.models.image, !!c.apiKey],
  ['视频 Seedance', c.models.video, !!c.apiKey],
  ['视觉理解', c.models.vision, !!c.apiKey],
  ['音频生成 SeedAudio', c.audio.model, !!c.audio.apiKey],
  ['语音合成', c.tts.appid ? '豆包语音原生' : c.models.tts || '', !!(c.tts.appid && c.tts.token) || !!(c.models.tts && c.apiKey)],
  ['联网搜索', c.search.botId || '', !!c.search.botId],
];
for (const [cap, model, ready] of rows) {
  console.log('  ' + (ready ? '\u2713' : '\u2717') + ' ' + cap.padEnd(14) + ' ' + (model || '—'));
}

if (!c.apiKey) {
  say.warn('没有 Key，后面两步跳过。把 .ark.json 或 ARK_API_KEY 配上再跑。');
  process.exit(0);
}

say.step('模型列表  GET /models');
try {
  const res = await ark('/models?page_size=100', undefined, { method: 'GET', timeout: 30000 });
  const data = res.json?.data ?? res.json?.models ?? [];
  if (!data.length) say.warn('接口通了但没返回模型：' + res.text.slice(0, 200));
  else {
    const match = a.match && a.match !== true ? String(a.match) : '';
    const ids = data.map((m) => m.id || m.name || String(m)).filter((id) => !match || id.includes(match));
    say.ok(data.length + ' 个模型' + (match ? '，匹配「' + match + '」' + ids.length + ' 个' : ''));
    for (const id of ids.slice(0, 40)) console.log('    ' + id);
    if (ids.length > 40) say.info('…还有 ' + (ids.length - 40) + ' 个，用 --match 过滤');
  }
} catch (e) {
  say.warn('/models 不可用（' + String(e.message || e).slice(0, 120) + '）——不影响生成，模型 ID 以控制台开通管理为准');
}

if (a.live) {
  say.step('实弹：1 token 对话  ' + c.models.vision);
  try {
    const res = await ark('/chat/completions', {
      model: c.models.vision,
      messages: [{ role: 'user', content: '回复一个字：通' }],
      max_tokens: 4,
    }, { timeout: 60000 });
    const txt = res.json?.choices?.[0]?.message?.content;
    say.ok('模型可用，回：' + String(txt).slice(0, 40));
  } catch (e) {
    die('实弹失败：' + String(e.message || e).slice(0, 300));
  }
} else {
  say.info('加 --live 跑一次真调用验证 Key（约几分钱以内）');
}
