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
const SKETCH_DIR = path.resolve('assets/gen/sketches');   // 构图草图（本地免费生成）；存在则自动走垫图

const args = process.argv.slice(2);
const has = (f) => args.includes('--' + f);
const opt = (f, d) => { const i = args.indexOf('--' + f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };

// ---------- 统一风格前缀（全片锁死，改一处全片变）----------
const PREFIX =
  '中国古风水墨画,宣纸质感,笔触洒脱,浓淡墨五层,留白占七成,冷青灰为基调,极简构图,' +
  '人物为墨块身躯配柔灰面部,面部仅淡墨轮廓无清晰五官不辨容貌,黑白灰为主,慢镜头,电影感,16:9,无文字无数字无字幕无logo,';

// 全片共用负向词。注意：不要写「彩色」——会把各镜唯一的那点暖色也杀掉。
const NEGATIVE =
  'ng_deepnegative_v1_75t,(badhandv4:1.2),EasyNegative,(worst quality:2),' +
  'standing,正面,现代服饰,复杂背景,照片质感,3D渲染,高饱和度,五彩斑斓,' +
  '日式,和服,武士,太刀,金色刀镡,文字,数字,水印,签名,logo,' +
  '多余的手,三只手,畸形手指,六指,手指粘连,刀身弯曲,' +
  '两把刀,双刀,三把刀,交叉的刀,刀尖朝上,举刀,挥舞,刀尖朝外,' +
  '清晰五官,写实人脸,美型脸,浓妆,' +
  '地面血迹,血泊,大面积血迹,' +
  '现代建筑,高楼,摩天大楼,城市天际线,塔楼,玻璃幕墙,电线杆,倒影,水面,湖泊,河流,海,' +
  'nsfw';

const SHOTS = [
  ['01_墨入水',
   '一滴浓墨自画外坠入一泓清水,墨入水即散,缓缓晕成烟丝状慢慢铺满画面,纯黑画面,水中只有一丝冷光,极慢镜头大特写,画面中没有任何人物,极简,纯黑白'],
  ['02_荒原流民',
   '水墨荒原大远景,一场大饥荒之后的荒原上挤满了枯瘦如柴的流民,浩浩荡荡却杂乱无章,' +
   '人们佝偻着身子相互推挤,有的匍匐爬行,有的伏地不起,有的拄着木杖,有的抱着襁褓,' +
   '画面右侧一棵枯死的树,一群人正围着树根刨土哄抢,' +
   '地上散落着折断的木杖与森然的枯枝,' +
   '远处地平线上一座低矮的中式城郭,天边一轮血红的残阳是全图唯一暖色,' +
   '下半幅是密密麻麻的墨点人影,上半幅是大片空白的天空,冷青灰为底,风卷尘土,触目惊心'],
  // 02 镜的分层素材（背景无人 + 两条人群带），合成用，不直接进片
  ['_层_02背景',
   '水墨荒原大远景,空旷无人的荒原,地面干裂斑驳,远处地平线上一座低矮的中式城郭,' +
   '画面右侧一棵枯死的树,天边一轮血红的残阳是全图唯一暖色,上方是大片空白的天空,' +
   '冷青灰为底,风卷尘土,画面中绝对没有人'],
  ['_层_02人群A',
   '水墨画,密密麻麻的枯瘦流民挤成一片,浩浩荡荡却杂乱无章,彼此重叠遮挡,' +
   '人们佝偻着身子,有的匍匐爬行,有的伏地不起,有的弯腰拄杖,有的抱着襁褓,' +
   '衣衫褴褛,骨瘦如柴,面容枯槁,脚下只有干裂的土地,' +
   '画面中没有任何树木、枝干、木杆与杂物,纯白背景,只有人与土地'],
  ['_层_02人群B',
   '水墨画,远处成排成片的细小流民剪影,层层叠叠向远处延绵,密密麻麻如蚁群,' +
   '全部是墨点般的小人影,有站有伏有爬,衣衫褴褛,身形枯瘦,' +
   '画面中没有任何树木、枝干与杂物,纯白背景,只有细小的流民人影'],
  ['03_宫殿纸醉金迷',
   '水墨宫殿内景,剪影宴饮群像,贵人举杯舞女扭动,姿态夸张如傀儡,烟在人群间缭绕,长案上酒壶倾倒杯盏狼藉,一只举杯的手特写,杯中酒映一点暗红,整幅画静得诡异,墨色剪影,大面留白'],

  ['04_刀在膝上_B擦刀',
   '一位刀客跪坐于地,侧身半剪影,头戴斗笠压低遮去半张脸,双膝并拢跪地,上身挺直如松,头微低,' +
   '画面中只有一把刀,长刀横放于双膝之上,鞘朝左柄朝右,右手五指虚握刀柄,' +
   '左手的食中二指并拢贴住刀身,由刀镡向刀尖缓缓推抹,反复摩挲,心绪不宁,' +
   '指腹已磨得发红,刀锋上一线暗红,指节泛白,刀身映一点冷光,空无的室内仅地面一道光影,' +
   '人物偏画面右三分之一,左侧三分之二全空'],
  ['05_红烛婚礼',
   '一对红烛燃着,一只涂着蔻丹的手把一条红绸系到刀鞘上打结,动作缓慢仔细,像在系一只铃铛,只拍手与刀鞘,' +
   '红绸结成的瞬间烛火晃了一下,满目墨色中只有红——烛火蔻丹红绸是唯一暖色,没有喜乐,近景特写,大面留白'],
  ['06_门外护卫',
   '门内透出的光把门缝描成一条金线,门的这边一个护卫剪影背对而立一手按刀,门缝里人影晃过光影一跳一跳,' +
   '他的影子在地上拉得很长,暗部为墨,门缝一线是冷金,门外固定机位,压抑,大面留白'],
  // 07 暗算 → 扩写为五段（来源：参考片《剑意》3-39s「师门毁灭」重排）
  ['07a_翻杯围拢',
   '水墨酒宴,一只酒杯被失手打翻,酒在案上淌开呈暗红,四周墨色人影同时起身合拢围上来,' +
   '每一张脸都是墨色看不清,只有眼睛位置两点冷光,主角的手已握上刀刀将出未出,压迫感,墨色剪影'],
  ['07b_混战中刀',
   '水墨画,一个人被七八个墨色人影从四周围攻,他屈身撑地苦苦招架,身上已中了一刀,' +
   '胸口一道暗红,四周墨点猛烈炸开甩出墨线,画面激烈混乱,冷青灰为底,大面积留白在上方'],
  ['07c_师傅的话',
   '水墨画,黑暗中的闪回,一位须发皆白的老者剪影立在墨雾中央,看不清脸,' +
   '一个年轻人跪坐在他身前背对画面,墨雾缭绕,老者是画面里唯一稍亮的一层,庄重苍凉'],
  ['07d_宗门焚毁',
   '水墨画,夜色中一座中式山门牌楼被大火吞没,橙金色的烈焰从门内喷涌而出,黑烟冲天,' +
   '牌楼压在火前呈墨色剪影,匾额悬在门楣上(匾上不写字),火光把四周照得明暗剧变,惨烈'],
  ['07e_被逼崖边',
   '水墨画,夜色里一个人的背影站在悬崖边缘,身后几个墨色人影正一步步逼近,' +
   '天边地平线上有一线橙金色的火光(那是他宗门的方向),人物是墨色剪影,大面留白,绝境'],
  ['08_坠崖',
   '悬崖顶端站着一排黑袍人,一齐俯身探出崖沿向下张望,双手撑在崖边,' +
   '每个人都戴着惨白的满覆盖傩面面具,面具盖住整张脸看不到任何人脸,没有头发没有兜帽,' +
   '面具上是夸张的诡笑,嘴角咧到耳根,露出一排牙齿,眼窝是两个深洞,骨相森然,' +
   '他们手中攥着带血的匕首,刃上一道暗红,' +
   '崖下虚空中,一个人正向下坠落,他是背影,仰着头朝向崖顶,双臂向两侧张开,' +
   '后背衣衫破碎,身上有几道暗红的血痕,衣袂与袍角向上翻飞如断墨,' +
   '天惨白,崖墨黑呈岩石质感,大面积留白,孤绝森寒,压迫感'],
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

// 上传本地图片到 OSS（垫图 / 蒙版要用 URL）
async function uploadImage(filePath, cfg) {
  const base = path.basename(filePath);
  const ext = base.split('.').pop();
  const sig = await api('/api/generate/upload/signature', cfg.accessKey, cfg.secretKey,
    { name: base.replace(/\.[^.]+$/, ''), extension: ext });
  // ⚠ 接口返回的是 xOss…（大写 O），SDK 文档写的 xoss… 是错的，照文档写会发 undefined
  const mime = ext.toLowerCase() === 'jpg' || ext.toLowerCase() === 'jpeg' ? 'image/jpeg' : 'image/png';
  const form = new FormData();
  form.append('x-oss-signature', sig.xOssSignature);
  form.append('x-oss-date', sig.xOssDate);
  form.append('x-oss-signature-version', sig.xOssSignatureVersion);
  form.append('policy', sig.policy);
  form.append('key', sig.key);
  form.append('x-oss-credential', sig.xOssCredential);
  form.append('x-oss-expires', String(sig.xOssExpires));
  form.append('file', new Blob([fs.readFileSync(filePath)], { type: mime }), base);
  const r = await fetch(sig.postUrl, { method: 'POST', body: form });
  if (!r.ok) throw new Error('上传失败 [' + r.status + '] ' + (await r.text()).slice(0, 250));
  return new URL(sig.key, sig.postUrl).toString();
}

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

    // 有同名构图草图 → 走垫图，构图由草图锁死
    const sketchFile = path.join(SKETCH_DIR, name + '.png');
    let endpoint = '/api/generate/webui/text2img';
    if (!repro && fs.existsSync(sketchFile)) {
      const url = await uploadImage(sketchFile, cfg);
      Object.assign(payload.generateParams, {
        sourceImage: url, resizeMode: 0,
        resizedWidth: cfg.width, resizedHeight: cfg.height,
        mode: 0, denoisingStrength: parseFloat(opt('denoise', '0.72')),
      });
      payload.templateUuid = cfg.templateUuidImg2img || cfg.templateUuid;   // img2img 必须换模板
      endpoint = '/api/generate/webui/img2img';
      process.stdout.write('  [垫图 ' + path.basename(sketchFile) + ' @' + payload.generateParams.denoisingStrength + '] ');
    }

    try {
      const sub = await api(endpoint, cfg.accessKey, cfg.secretKey, payload);
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
