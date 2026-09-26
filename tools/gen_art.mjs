// 古风水墨文生图小工具（智谱 GLM-Image · 0.1 元/次，新用户包 20 次免费）
// 用法：
//   node tools/gen_art.mjs "山间古刹，晨雾，松林" --out gate_shuimo
//   node tools/gen_art.mjs "热闹的古代集市" --out market --size 1728x960 --style none --n 3
// 选项：
//   --out <名字>      保存名（默认按时间戳）→ assets/gen/<名字>.png
//   --size WxH        默认 1056x1568（3:4 竖版）；16:9 用 1728x960；须 512-2048 且 32 的倍数
//   --style <风格>    默认 shuimo（自动追加水墨风格尾巴）；none = 不追加
//   --n <张数>        默认 1（每张算一次）
// 说明：key 从 ~/.modlens/config.json 读取（与 modlens 同一把智谱 key）；图生成后立即下载到本地（URL 会过期）。
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const args = process.argv.slice(2);
const promptArg = args.find((a) => !a.startsWith('--'));
const opt = (name, def) => {
  const i = args.indexOf('--' + name);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
};
if (!promptArg) {
  console.log('用法：node tools/gen_art.mjs "画面描述" --out 名字 [--size WxH] [--style shuimo|none] [--n 张数]');
  process.exit(1);
}
const out = opt('out', 'art_' + Date.now());
const size = opt('size', '1056x1568');
const style = opt('style', 'shuimo');
const n = Math.min(4, Math.max(1, parseInt(opt('n', '1'), 10) || 1));

// 风格尾巴（古风水墨）
const STYLES = {
  shuimo: '，中国古风水墨画风格：宣纸质感，淡墨浓淡层次，写意山水意境，大面留白，笔触洒脱；画面中不要出现任何文字、字幕、水印',
  none: '',
};
const prompt = (promptArg + (STYLES[style] ?? '')).slice(0, 1000);

// key：与 modlens 同一把（~/.modlens/config.json）
const cfgPath = path.join(os.homedir(), '.modlens', 'config.json');
let key = '';
try {
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  key = cfg?.providers?.openai?.apiKey ?? '';
} catch { /* ignore */ }
if (!key) {
  console.log('✗ 没找到智谱 key（~/.modlens/config.json）——先配好 modlens 或设置环境变量 ZP_KEY');
  process.exit(1);
}

const resp = await fetch('https://open.bigmodel.cn/api/paas/v4/images/generations', {
  method: 'POST',
  headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' },
  body: JSON.stringify({ model: 'glm-image', prompt, size, n }),
});
const txt = await resp.text();
if (!resp.ok) {
  console.log('✗ 生成失败 [' + resp.status + ']：' + txt.slice(0, 400));
  process.exit(1);
}
const data = JSON.parse(txt).data ?? [];
if (!data.length) {
  console.log('✗ 响应里没有图片：' + txt.slice(0, 300));
  process.exit(1);
}

const dir = path.resolve('assets/gen');
fs.mkdirSync(dir, { recursive: true });
for (let i = 0; i < data.length; i++) {
  const url = data[i].url;
  const file = path.join(dir, (data.length > 1 ? out + '_' + (i + 1) : out) + '.png');
  const img = await fetch(url);
  if (!img.ok) {
    console.log('✗ 第 ' + (i + 1) + ' 张下载失败 [' + img.status + ']');
    continue;
  }
  fs.writeFileSync(file, Buffer.from(await img.arrayBuffer()));
  console.log('✓ 第 ' + (i + 1) + '/' + data.length + ' 张 → ' + file);
}
console.log('提示词：' + prompt.slice(0, 120) + (prompt.length > 120 ? '…' : ''));
