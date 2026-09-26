// 开场分镜 · 关键帧批量出图（智谱 GLM-Image · 16:9 · 0.1 元/张，从免费包扣）
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const cfg = JSON.parse(fs.readFileSync(path.join(os.homedir(), '.modlens', 'config.json'), 'utf8'));
const key = cfg.providers.openai.apiKey;

const PREFIX = '中国古风水墨动画，宣纸质感，笔触洒脱，浓淡墨层次，大面留白，冷青色调为底、血红为唯一暖色点缀，人物为剪影、无五官细节，慢镜头，电影感，16:9，无文字无字幕无logo，';

const SHOTS = [
  ['01_墨入水', '一滴浓墨坠入清水，墨在水中缓慢晕散成烟丝状，铺满画面，纯黑白，极简，慢镜头特写'],
  ['02_荒原流民', '水墨荒原大远景，流民剪影如蝼蚁蠕动，远处王城轮廓，天边一轮血红残阳，冷青色调，风卷尘土'],
  ['03_宫殿纸醉金迷', '水墨宫殿内景，剪影宴饮群像，姿态夸张如傀儡，烟缭绕，长案酒盏狼藉，一只举杯的手特写，杯中酒映血红一点，诡异寂静'],
  ['04_刀在膝上', '一把刀横放膝上，刀身映冷光，指节发白的手握鞘，跪坐剪影肩线不动如山，大面留白，寂静'],
  ['05_红烛婚礼', '一对红烛，涂蔻丹的手将红绸系在刀鞘上打结，动作缓慢，烛火晃动，墨色画面中红绸与烛火为唯一暖色，近景特写'],
  ['06_门外护卫', '水墨门内透光为一线冷金，门外护卫剪影背对按刀而立，门内人影晃动光影跳动，影子拖长，压抑'],
  ['07_暗算', '水墨酒宴，酒杯打翻酒水淌开，四周墨色人影同时起身围拢，剪影脸上仅两点冷光，主角握刀将出未出，压迫感'],
  ['08_坠崖', '水墨悬崖大远景，剪影人物坠落，衣袂散开如断墨，崖顶人影转身离去，天惨白崖墨黑，孤绝'],
  ['09_没死', '谷底黑暗，一只染血的手猛攀住石缝，指甲裂开，指节绷起将自己拉上半寸，特写，几乎静止，伤口暗红一点'],
  ['10_五问', '水墨烟雾中浮现老者剪影，须发皆白看不清脸，跪坐人影旁，墨雾缭绕，庄重苍凉'],
  ['11_江湖新客', '水墨晨雾江边，背插长刀的剪影起身走向雾深处，越走越远，镜头不追，整幅冷青，人物一点浓墨，雾渐合拢'],
];

const outDir = path.resolve('assets/gen/keyframes');
fs.mkdirSync(outDir, { recursive: true });

let ok = 0;
for (const [name, shot] of SHOTS) {
  const prompt = (PREFIX + shot).slice(0, 1000);
  try {
    const r = await fetch('https://open.bigmodel.cn/api/paas/v4/images/generations', {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'glm-image', prompt, size: '1728x960', n: 1 }),
    });
    const t = await r.text();
    if (!r.ok) {
      console.log('✗ ' + name + ' [' + r.status + '] ' + t.slice(0, 200).replace(/\s+/g, ' '));
      continue;
    }
    const j = JSON.parse(t);
    const url = j.data?.[0]?.url;
    if (!url) {
      console.log('✗ ' + name + ' 无图片 URL：' + t.slice(0, 160));
      continue;
    }
    const img = await fetch(url);
    const file = path.join(outDir, name + '.png');
    fs.writeFileSync(file, Buffer.from(await img.arrayBuffer()));
    ok += 1;
    console.log('✓ ' + name + ' → ' + file);
  } catch (e) {
    console.log('✗ ' + name + ' 异常：' + e.message);
  }
}
console.log('\n完成 ' + ok + '/' + SHOTS.length + ' 张 → ' + outDir);
