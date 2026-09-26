// ============================================================
// 开场分镜 · 关键帧批量出图（LiblibAI 开放平台 API）
//
// 风格锁定（来自你满意的那张 04 的 PNG 元数据）：
//   底模  Qwen-Image_1.0.safetensors
//   LoRA  「Qwen Image-国风武侠水墨画」权重 0.8
//   Euler / 30 步 / CFG 7.0 / 1664x928
// ⚠️ 上面是「文件」标识；API 要的是平台的 modelVersionUUID，见配置文件说明。
//
// 用法：
//   node tools/gen_keyframes_liblib.mjs --dry          # 只打印将提交的参数，不花钱、不提交
//   node tools/gen_keyframes_liblib.mjs --only 04      # 只出 04 镜
//   node tools/gen_keyframes_liblib.mjs                # 出所有缺的镜（已存在则跳过）
//   node tools/gen_keyframes_liblib.mjs --force        # 已存在的也重出
//
// 凭据与模型 UUID（放在工作区之外，绝不进 git）：
//   C:\Users\zq300\.liblib\liblib.json
//   {
//     "accessKey": "...",  "secretKey": "...",
//     "templateUuid": "e10adc3949ba59abbe56e057f20f883e",
//     "checkPointId": "<Qwen-Image 底模的 modelVersionUUID>",
//     "loras": [{ "modelId": "<水墨 LoRA 的 modelVersionUUID>", "weight": 0.8 }],
//     "sampler": 0, "steps": 30, "cfgScale": 7,
//     "width": 1664, "height": 928, "randnSource": 1
//   }
// ============================================================

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';

const BASE = 'https://openapi.liblibai.cloud';
// 配置查找顺序：环境变量 > 工作区根目录 .liblib.json（已 gitignore）> 用户目录
const HERE = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const CONF_CANDIDATES = [
  process.env.LIBLIB_CONF,
  path.join(HERE, '..', '.liblib.json'),
  path.resolve('.liblib.json'),
  path.join(os.homedir(), '.liblib', 'liblib.json'),
].filter(Boolean);
const CONF = CONF_CANDIDATES.find((p) => { try { return fs.existsSync(p); } catch { return false; } }) || CONF_CANDIDATES[1];
const OUT_DIR = path.resolve('assets/gen/keyframes');

const args = process.argv.slice(2);
const has = (f) => args.includes('--' + f);
const opt = (f, d) => { const i = args.indexOf('--' + f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };

// ---------- 统一风格前缀（全片锁死，改一处全片变）----------
const PREFIX =
  '中国古风水墨画,宣纸质感,笔触洒脱,浓淡墨五层,大面留白,冷青灰为基调,极简构图,' +
  '人物为墨块身躯配柔灰面部(半剪影),以黑白灰为主,慢镜头,电影感,16:9,无文字无数字无字幕无logo,';

// 全片共用负向词。注意：不要写「彩色」——会把各镜唯一的那点暖色也杀掉。
const NEGATIVE =
  'ng_deepnegative_v1_75t,(badhandv4:1.2),EasyNegative,(worst quality:2),' +
  'standing,正面,现代服饰,复杂背景,bedroom,照片质感,3D渲染,高饱和度,五彩斑斓,' +
  '日式,和服,武士,太刀,金色刀镡,文字,数字,水印,签名,logo,' +
  '多余的手,三只手,畸形手指,六指,手指粘连,刀身弯曲,nsfw';

const SHOTS = [
  ['01_墨入水',
   '一滴浓墨自画外坠入一泓清水,墨入水即散,缓缓晕成烟丝状慢慢铺满画面,纯黑画面,水中只有一丝冷光,极慢镜头大特写,画面中没有任何人物,极简,纯黑白'],
  ['02_荒原流民',
   '水墨荒原大远景,一支流民队伍如蝼蚁般在荒原上缓慢挪动,全部为墨点剪影,远处王城轮廓压在地平线上,天边一轮残阳是血红色(全图唯一暖色),冷青灰为底,风卷尘土,地平线压得很低,上方大面积空白天'],
  ['03_宫殿纸醉金迷',
   '水墨宫殿内景,剪影宴饮群像,贵人举杯舞女扭动,姿态夸张如傀儡,烟在人群间缭绕,长案上酒壶倾倒杯盏狼藉,一只举杯的手特写,杯中酒映一点暗红,整幅画静得诡异,墨色剪影,大面留白'],
  ['04_刀在膝上',
   '一位刀客跪坐于地,侧身半剪影,头戴斗笠压低遮去半张脸,双膝并拢跪地,脚跟垫于臀下,上身挺直如松,头微低,' +
   '长刀横放于双膝之上,刀鞘朝左刀柄朝右,右手五指虚握刀柄,左手食中二指贴住刀身缓缓擦拭,往复摩挲,' +
   '心绪不稳,他自己的手指磨破了,刀身上擦出一道淡淡血痕(全图唯一暖色),指节泛白,刀身映一点冷光,' +
   '空无的室内仅地面一线光影,人物置于画面右三分之一,左侧与上方大面积留白,平视中景'],
  ['05_红烛婚礼',
   '一对红烛燃着,一只涂着蔻丹的手把一条红绸系到刀鞘上打结,动作缓慢仔细,像在系一只铃铛,只拍手与刀鞘,' +
   '红绸结成的瞬间烛火晃了一下,满目墨色中只有红——烛火蔻丹红绸是唯一暖色,没有喜乐,近景特写,大面留白'],
  ['06_门外护卫',
   '门内透出的光把门缝描成一条金线,门的这边一个护卫剪影背对而立一手按刀,门缝里人影晃过光影一跳一跳,' +
   '他的影子在地上拉得很长,暗部为墨,门缝一线是冷金,门外固定机位,压抑,大面留白'],
  ['07_暗算',
   '水墨酒宴,一只酒杯被失手打翻,酒在案上淌开呈暗红,四周墨色人影同时起身围拢,每一张脸都是墨色看不清,' +
   '只有眼睛位置两点冷光,主角的手已握上刀刀将出未出,节奏突快,压迫感,墨色剪影'],
  ['08_坠崖',
   '水墨悬崖大远景,悬崖之上一名剪影被推下,衣袂散开如一笔断墨直直坠落,崖上的人影朝下看了一眼转身走了,' +
   '天是惨白崖是墨黑,人物是画面唯一活动点,镜头自崖顶向下跟坠,孤绝,大面留白'],
  ['09_没死',
   '黑暗谷底,一只手猛地攀住石缝,手指上全是血指甲裂了,那只手一点点用力指节绷起把自己从黑里拉上来半寸,' +
   '紧贴手部大特写几乎静止,全黑只有伤口一点暗红,粗重呼吸感,极简'],
  ['10_五问',
   '水墨烟雾中浮现一位老者剪影,须发皆白看不清脸,旁边一个跪坐的人影,墨雾缭绕,' +
   '老者剪影是画面里唯一稍亮的一层,镜头缓缓环绕半圈,庄重苍凉,大面留白'],
  ['11_江湖新客',
   '水墨晨雾江边,一个无名者的剪影起身,背上斜斜插着一把刀,朝雾深处走去越走越远只剩一个点,' +
   '雾渐渐合拢把他吞掉,固定机位镜头不推不追,整幅冷青,人物一点浓墨,大面留白'],
];

// 原图（你满意的那张 04）的完整提示词 —— 只用于 --repro 精确复现测试
const REPRO_SHOT =
  '一位刀客跪坐于地,侧身剪影,双膝并拢跪地,脚跟垫于臀下,上身挺直如松,头微低,双手置于膝上,' +
  '一手虚按膝前横放的长刀刀鞘,指节泛白,刀身映一点冷光,空无的室内仅地面一线光影,' +
  '人物置于画面右三分之一,左侧与上方大面积留白,平视中景,中国古风水墨画,纯黑剪影人物,无五官无细节,' +
  '黑白灰三色,浓淡墨五层,宣纸质感,留白占七成,冷青色基调,血红为唯一暖色点缀,极简构图,16:9';
const REPRO_NEG =
  'ng_deepnegative_v1_75t,(badhandv4:1.2),EasyNegative,(worst quality:2),standing,正面,现代服饰,' +
  '复杂背景,bedroom,照片质感,3D渲染,,nsfw';

// ---------- 签名（HMAC-SHA1 → base64 URL-safe 去 padding）----------
function signedPath(uri, accessKey, secretKey) {
  const timestamp = Date.now();
  const nonce = crypto.randomBytes(16).toString('hex').slice(0, 16);
  const content = uri + '&' + timestamp + '&' + nonce;
  const sig = crypto.createHmac('sha1', secretKey).update(content).digest('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return uri + '?AccessKey=' + accessKey + '&Signature=' + sig + '&Timestamp=' + timestamp + '&SignatureNonce=' + nonce;
}

async function api(uri, accessKey, secretKey, body, tries = 6) {
  for (let attempt = 0; ; attempt++) {
  const url = BASE + signedPath(uri, accessKey, secretKey);
  const r = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const text = await r.text();
  let j; try { j = JSON.parse(text); } catch { throw new Error('非 JSON 响应 [' + r.status + '] ' + text.slice(0, 400)); }
  if (j.code === 429 || j.code === 100054) {
    if (attempt >= tries) throw new Error('限流/并发超限，重试 ' + tries + ' 次仍失败：' + j.msg);
    const wait = 15000 * (attempt + 1);
    console.log('  … 限流(' + j.code + ')，等 ' + (wait/1000) + 's 重试');
    await sleep(wait);
    continue;
  }
  if (j.code !== 0) throw new Error('API 错误 code=' + j.code + ' msg=' + j.msg + ' | 原始: ' + text.slice(0, 300));
  return j.data;
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  if (!fs.existsSync(CONF)) {
    console.log('✗ 找不到配置文件：' + CONF);
    console.log('  请按文件头注释里的格式建好（accessKey/secretKey/templateUuid/checkPointId/loras）。');
    process.exit(1);
  }
  const cfg = JSON.parse(fs.readFileSync(CONF, 'utf8'));
  const dry = has('dry');
  const force = has('force');
  const only = opt('only', '');
  const seedOpt = parseInt(opt('seed', '-1'), 10);
  const repro = has('repro');

  let todo = SHOTS.filter(([name]) => (!only || name.startsWith(only)));
  if (repro) todo = [['_repro_原图复现', REPRO_SHOT]];
  fs.mkdirSync(OUT_DIR, { recursive: true });

  console.log('底模 checkPointId = ' + cfg.checkPointId);
  console.log('LoRA = ' + JSON.stringify(cfg.loras));
  console.log('参数 = ' + JSON.stringify({ sampler: cfg.sampler, steps: cfg.steps, cfgScale: cfg.cfgScale, size: cfg.width + 'x' + cfg.height }));
  console.log('待出 ' + todo.length + ' 镜' + (dry ? '（--dry：不会真的提交）' : '') + '\n');

  let spent = 0;
  for (const [name, shot] of todo) {
    const file = path.join(OUT_DIR, name + '.png');
    if (fs.existsSync(file) && !force) { console.log('跳过 ' + name + '（已存在，--force 可重出）'); continue; }

    const prompt = (repro ? REPRO_SHOT : PREFIX + shot).slice(0, 2000);
    const negative = repro ? REPRO_NEG : NEGATIVE;
    const payload = {
      templateUuid: cfg.templateUuid,
      generateParams: {
        ...(cfg.checkPointId && !String(cfg.checkPointId).startsWith('待填') ? { checkPointId: cfg.checkPointId } : {}),
        prompt,
        negativePrompt: negative,
        sampler: cfg.sampler,
        steps: cfg.steps,
        cfgScale: cfg.cfgScale,
        width: cfg.width,
        height: cfg.height,
        imgCount: 1,
        randnSource: cfg.randnSource ?? 1,
        seed: (repro && seedOpt < 0) ? 1619041440 : seedOpt,
        restoreFaces: 0,
        additionalNetwork: cfg.loras,
      },
    };

    if (dry) { console.log('— ' + name + '\n  prompt: ' + prompt + '\n'); continue; }

    try {
      const sub = await api('/api/generate/webui/text2img', cfg.accessKey, cfg.secretKey, payload);
      const uuid = sub.generateUuid;
      process.stdout.write('· ' + name + ' 提交 ' + uuid + ' 等待中');

      let pred = null;
      for (let i = 0; i < 100; i++) {
        await sleep(3000);
        pred = await api('/api/generate/webui/status', cfg.accessKey, cfg.secretKey, { generateUuid: uuid });
        process.stdout.write('.');
        if (pred.generateStatus === 5) break;
        if ([6, 7].includes(pred.generateStatus)) break;
      }
      process.stdout.write('\n');

      if (!pred || pred.generateStatus !== 5) {
        console.log('  ✗ 失败 status=' + (pred && pred.generateStatus) + ' msg=' + (pred && pred.generateMsg));
        continue;
      }
      const img = (pred.images || [])[0];
      if (!img) { console.log('  ✗ 没有图片返回'); continue; }

      const bin = Buffer.from(await (await fetch(img.imageUrl)).arrayBuffer());
      // 按真实字节决定扩展名，别再出现「.png 里装 JPEG」
      const isPng = bin[0] === 0x89 && bin[1] === 0x50;
      const target = path.join(OUT_DIR, name + (isPng ? '.png' : '.jpg'));
      fs.writeFileSync(target, bin);
      spent += pred.pointsCost || 0;
      console.log('  ✓ ' + path.basename(target) + '  seed=' + img.seed +
        '  本次消耗=' + pred.pointsCost + '  余额=' + pred.accountBalance +
        (img.auditStatus !== 3 ? '  ⚠审核状态=' + img.auditStatus : ''));
    } catch (e) {
      console.log('  ✗ ' + name + ' 异常：' + e.message);
    }
  }
  if (!dry) console.log('\n本次合计消耗积分：' + spent);
}

main().catch((e) => { console.error(e); process.exit(1); });
