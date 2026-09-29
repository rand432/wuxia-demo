// ============================================================
// 《江湖游历》· 人物美术生成器（立绘 / 头像 / Q版）
//
// 两条通道：
//   glm    = 智谱 GLM-Image（~0.1 元/张，快，适合大批量迭代）
//   liblib = LiblibAI Qwen-Image + 国风武侠水墨 LoRA（~23 积分/张，风格最稳，可垫图锁角色）
//
// 用法：
//   node tools/gen_char_art.mjs --jobs shaoxia:立绘:glm:anime,shaoxia:立绘:glm:ink
//   node tools/gen_char_art.mjs --pilot          # 跑默认打样套（少侠 4 张对比）
//   node tools/gen_char_art.mjs --all            # 三个主角 × 立绘/头像/Q版（先改 --style）
//   node tools/gen_char_art.mjs --dry            # 只打印将提交的参数，不花钱
//
// 输出：assets/gen/char/<角色>/<角色>_<套>.png
// ============================================================
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';

const BASE = 'https://openapi.liblibai.cloud';
const HERE = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const CONF = [process.env.LIBLIB_CONF, path.join(HERE, '..', '.liblib.json'), path.resolve('.liblib.json'),
  path.join(os.homedir(), '.liblib', 'liblib.json')].filter(Boolean)
  .find((p) => { try { return fs.existsSync(p); } catch { return false; } }) || '';
const OUT_ROOT = path.resolve('assets/gen/char');

const args = process.argv.slice(2);
const has = (f) => args.includes('--' + f);
const opt = (f, d) => { const i = args.indexOf('--' + f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------- 角色设定（外形锁死，改这里全角色同步变） ----------------
const CHARS = {
  shaoxia: {
    cn: '少侠', title: '无名少年 · 主角',
    body: '一名年轻男子，身形清瘦挺拔，墨黑色长发束成高马尾、鬓边散落几缕碎发，面容清俊冷峻，眉眼细长，眼神沉静而带倦意，肤色偏白',
    cloth: '身着一袭深青灰交领窄袖长袍，衣料带淡淡墨色晕染与暗纹，腰间以深色布带束紧，小臂缠深色皮护腕，下着深色长裤与软靴，腰侧斜挂一柄直刃长刀，刀鞘深色无饰',
    pose: '双手抱臂而立，微微侧身，衣摆与发尾轻轻飘动',
    qpose: '双脚分开站定，一手按在腰侧刀柄上，另一手握拳垂在身侧',
    weapon: '长刀',
  },
  chenshi: {
    cn: '陈石', title: '弟子 · 阿石',
    body: '一名十七八岁少年，身材敦实粗壮，方圆脸，浓眉大眼，神情憨厚木讷，肤色偏黑，黑色短发以一条褐色布巾束起',
    cloth: '身穿粗布褐色短打劲装，外罩一件洗得发白的对襟褂子，肩宽手大，小臂缠粗布绑腿护腕，腰间系麻绳与布囊，下着深色扎脚长裤与布鞋，背后斜背一杆断了枪头的长枪，枪杆缠布',
    pose: '双脚稳稳分开站桩，一手拄着断枪，另一手垂在身侧握拳，肩背厚实微沉',
    qpose: '双手横持断枪挡在身前，双腿扎马步',
    weapon: '断枪',
  },
  qingluan: {
    cn: '苏青鸾', title: '弟子 · 游侠女',
    body: '一名十六七岁的少女，身姿轻盈挺拔、腰肢纤细，鹅蛋脸，柳叶细眉，杏眼锐利有神，鼻梁秀挺，唇色微红，神情冷淡矜傲，肤白如雪，墨黑长发束成高马尾并垂一条细发辫，鬓边碎发随风轻扬',
    cloth: '身着月白与青碧色的交领窄袖劲装，衣料层次繁复、缀金属扣件与皮革束带，外披一件短氅，腰束革带、垂流苏飘带，腰后横别一对匕首，下着深色束脚长裤与轻靴，一手斜垂一柄长剑',
    pose: '侧身而立，一手轻按腰间匕首，另一手垂在身侧，衣摆与发尾随风扬起',
    qpose: '反手抽出匕首横在身前，重心前倾作起手式',
    weapon: '匕首',
  },
};

// ---------------- 风格尾巴 ----------------
const ANIME = '，国风二次元游戏角色立绘，赛璐璐上色，线条干净利落，冷青灰色调为主，衣料带淡淡水墨晕染质感，光影柔和，画面精致，全身完整不裁切，画面中只有这一个人物，纯白背景，背景没有任何景物，画面中没有文字没有水印没有logo没有签名';
const INK = '，中国古风水墨人物画，宣纸质感，墨色浓淡五层，笔触写意洒脱，面部用淡墨勾线、五官清秀可辨，衣纹以焦墨飞白表现，冷青灰为基调，大面积留白，全身完整不裁切，画面中只有这一个人物，纯白背景，背景没有任何景物，画面中没有文字没有水印没有logo没有签名';

// 鸣潮/库洛那种二次元游戏立绘：精细线稿 + 赛璐璐与厚涂结合、服装细节繁复、风动感
const MENGCHAO = '，高品质二次元游戏角色立绘（国产二次元手游卡面那种质感），精细线稿与通透的赛璐璐上色结合局部厚涂，服装结构繁复（交领、束带、金属扣件、皮革绑带、流苏飘带），衣摆与发丝带风动感，光影通透有层次，冷调高对比，电影感构图，全身完整不裁切，画面中只有这一个人物，纯白背景，背景没有任何景物，画面中没有文字没有水印没有logo没有签名';
const GUOFENG = '，中国古风武侠人物插画，精致细腻的半写实国风画风，柔和厚涂与赛璐璐结合的质感，冷青灰色调，衣料纹样细致，光影柔和通透，画面干净利落，全身完整不裁切，画面中只有这一个人物，纯白背景，背景没有任何景物，画面中没有文字没有水印没有logo没有签名';
const NEG_COMMON = '文字,汉字,书法,印章,水印,签名,logo,字幕,多个角色,两个人,重复人物,背景景物,树木,山水,建筑,房间,现代服饰,西式服装,西装,3D渲染,照片,写实照片,油画厚涂,高饱和度,艳丽俗气,日式和服,日本武士,太刀,多余的手,三只手,六指,畸形手指,断手,脸崩,崩坏,低质量,模糊,裁切,半身';
const NEG_Q = NEG_COMMON + ',写实比例,成人比例,九头身,长腿,细长身材,狰狞';
// 按性别分：女角色不许出男人；男角色不许出女人
const NEG_MALE = NEG_COMMON + ',男性,男人,男子,胡子,络腮胡,粗犷,魁梧,壮汉,肌肉块';
const NEG_FEMALE = NEG_COMMON + ',男性,男人,男子,少年,胡须,粗犷,魁梧,壮汉,肌肉块,中性';
const NEG_BUST = NEG_COMMON.replace(',半身', '');

// ---------------- 出图套（尺寸按通道给） ----------------
const SETS = {
  '立绘': { suffix: '全身立绘站姿，完整人物全身像（含鞋靴与头顶发髻，任何部位都不得被画面边缘裁掉），人物高度约占画面的七成五，头顶留白约一成、脚下留白约一成，全身立绘站姿', glm: [1056, 1568], liblib: [928, 1664], neg: NEG_COMMON },
  '头像': { suffix: '胸像特写，半身构图，人物面部居中清晰、五官精致，眼睛看向观者，肩部完整', glm: [1024, 1024], liblib: [1024, 1024], neg: NEG_BUST },
  // 横版角色卡面（照参考图那种：人物在右、左边留白放名字与星级）
  '卡面': { suffix: '横版角色卡面构图：人物置于画面右侧约三分之二处，取膝上半身、四分之三侧身，微微回眸看向画外，左侧留出大片空白用于排名字与星级，画面下方留出不多的空间', glm: [1728, 960], liblib: [1664, 928], neg: NEG_BUST },
  'Q版': { suffix: 'Q版二头身萌系造型，大头小身，圆圆的脸，眼睛大而明亮，身形小巧，清晰描边，游戏战斗立绘用', glm: [1024, 1024], liblib: [1024, 1024], neg: NEG_Q },
};

// ---------------- Liblib 签名 / 请求 ----------------
function signedPath(uri, accessKey, secretKey) {
  const timestamp = Date.now();
  const nonce = crypto.randomBytes(16).toString('hex').slice(0, 16);
  const content = uri + '&' + timestamp + '&' + nonce;
  const sig = crypto.createHmac('sha1', secretKey).update(content).digest('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return uri + '?AccessKey=' + accessKey + '&Signature=' + sig + '&Timestamp=' + timestamp + '&SignatureNonce=' + nonce;
}
async function liblibApi(uri, cfg, body, tries = 6) {
  for (let attempt = 0; ; attempt++) {
    const r = await fetch(BASE + signedPath(uri, cfg.accessKey, cfg.secretKey), {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    const text = await r.text();
    let j; try { j = JSON.parse(text); } catch { throw new Error('非 JSON 响应 [' + r.status + '] ' + text.slice(0, 300)); }
    if (j.code === 429 || j.code === 100054) {
      if (attempt >= tries) throw new Error('限流/并发超限：' + j.msg);
      const wait = 15000 * (attempt + 1);
      console.log('  … 限流(' + j.code + ')，等 ' + (wait / 1000) + 's 重试');
      await sleep(wait); continue;
    }
    if (j.code !== 0) throw new Error('API code=' + j.code + ' msg=' + j.msg + ' | ' + text.slice(0, 250));
    return j.data;
  }
}

// ---------------- 两通道出图 ----------------
async function genGlm(prompt, [w, h], outBase) {
  const cfgPath = path.join(os.homedir(), '.modlens', 'config.json');
  const key = JSON.parse(fs.readFileSync(cfgPath, 'utf8'))?.providers?.openai?.apiKey ?? '';
  if (!key) throw new Error('没找到智谱 key（~/.modlens/config.json）');
  const resp = await fetch('https://open.bigmodel.cn/api/paas/v4/images/generations', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: 'glm-image', prompt: prompt.slice(0, 1000), size: w + 'x' + h, n: 1 }),
  });
  const txt = await resp.text();
  if (!resp.ok) throw new Error('[' + resp.status + '] ' + txt.slice(0, 300));
  const url = JSON.parse(txt).data?.[0]?.url;
  if (!url) throw new Error('响应无图片：' + txt.slice(0, 200));
  const bin = Buffer.from(await (await fetch(url)).arrayBuffer());
  const ext = bin[0] === 0x89 && bin[1] === 0x50 ? '.png' : '.jpg';
  fs.writeFileSync(outBase + ext, bin);
  return { file: outBase + ext, cost: '约 0.1 元' };
}

// 上传本地图到 OSS（img2img 垫图要 URL）
async function uploadImage(filePath, cfg) {
  const base = path.basename(filePath);
  const ext = base.split('.').pop();
  const sig = await liblibApi('/api/generate/upload/signature', cfg, { name: base.replace(/\.[^.]+$/, ''), extension: ext });
  const mime = /jpe?g$/i.test(ext) ? 'image/jpeg' : 'image/png';
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
  if (!r.ok) throw new Error('上传失败 [' + r.status + '] ' + (await r.text()).slice(0, 200));
  return new URL(sig.key, sig.postUrl).toString();
}

// img2img：拿一张现成的图当底，低重绘幅度"细化/放大"（denoise 0.3~0.55 是加细节，0.6+ 会改画风）
async function genLiblibImg(prompt, negative, [w, h], outBase, loraOverride, srcFile, denoise) {
  if (!CONF) throw new Error('找不到 .liblib.json');
  const cfg = JSON.parse(fs.readFileSync(CONF, 'utf8'));
  const url = await uploadImage(srcFile, cfg);
  const payload = {
    templateUuid: cfg.templateUuidImg2img || cfg.templateUuid,
    generateParams: {
      ...(cfg.checkPointId ? { checkPointId: cfg.checkPointId } : {}),
      prompt: prompt.slice(0, 2000),
      negativePrompt: negative,
      sampler: cfg.sampler, steps: cfg.steps, cfgScale: cfg.cfgScale,
      width: w, height: h, imgCount: 1, randnSource: cfg.randnSource ?? 1, seed: -1,
      restoreFaces: 0,
      ...(has('nolora') ? {} : { additionalNetwork: loraOverride ? [{ modelId: loraOverride, weight: 0.8 }] : cfg.loras }),
      sourceImage: url, resizeMode: 0, resizedWidth: w, resizedHeight: h, mode: 0,
      denoisingStrength: denoise,
    },
  };
  const sub = await liblibApi('/api/generate/webui/img2img', cfg, payload);
  process.stdout.write('  提交 ' + sub.generateUuid + ' 等待中');
  let pred = null;
  for (let i = 0; i < 100; i++) {
    await sleep(3000);
    pred = await liblibApi('/api/generate/webui/status', cfg, { generateUuid: sub.generateUuid });
    process.stdout.write('.');
    if (pred.generateStatus === 5 || [6, 7].includes(pred.generateStatus)) break;
  }
  process.stdout.write('\n');
  if (!pred || pred.generateStatus !== 5) throw new Error('status=' + (pred && pred.generateStatus) + ' msg=' + (pred && pred.generateMsg));
  const img = (pred.images || [])[0];
  const bin = Buffer.from(await (await fetch(img.imageUrl)).arrayBuffer());
  const ext = bin[0] === 0x89 && bin[1] === 0x50 ? '.png' : '.jpg';
  fs.writeFileSync(outBase + ext, bin);
  return { file: outBase + ext, cost: pred.pointsCost + ' 积分（余额 ' + pred.accountBalance + '）', seed: img.seed };
}

async function genLiblib(prompt, negative, [w, h], outBase, loraOverride) {
  if (!CONF) throw new Error('找不到 .liblib.json');
  const cfg = JSON.parse(fs.readFileSync(CONF, 'utf8'));
  const payload = {
    templateUuid: cfg.templateUuid,
    generateParams: {
      ...(cfg.checkPointId ? { checkPointId: cfg.checkPointId } : {}),
      prompt: prompt.slice(0, 2000),
      negativePrompt: negative,
      sampler: cfg.sampler, steps: cfg.steps, cfgScale: cfg.cfgScale,
      width: w, height: h, imgCount: 1, randnSource: cfg.randnSource ?? 1, seed: -1,
      restoreFaces: 0,
      ...(has('nolora') ? {} : { additionalNetwork: loraOverride ? [{ modelId: loraOverride, weight: 0.8 }] : cfg.loras }),
    },
  };
  const sub = await liblibApi('/api/generate/webui/text2img', cfg, payload);
  process.stdout.write('  提交 ' + sub.generateUuid + ' 等待中');
  let pred = null;
  for (let i = 0; i < 100; i++) {
    await sleep(3000);
    pred = await liblibApi('/api/generate/webui/status', cfg, { generateUuid: sub.generateUuid });
    process.stdout.write('.');
    if (pred.generateStatus === 5 || [6, 7].includes(pred.generateStatus)) break;
  }
  process.stdout.write('\n');
  if (!pred || pred.generateStatus !== 5) throw new Error('status=' + (pred && pred.generateStatus) + ' msg=' + (pred && pred.generateMsg));
  const img = (pred.images || [])[0];
  if (!img) throw new Error('没有图片返回');
  const bin = Buffer.from(await (await fetch(img.imageUrl)).arrayBuffer());
  const ext = bin[0] === 0x89 && bin[1] === 0x50 ? '.png' : '.jpg';
  fs.writeFileSync(outBase + ext, bin);
  return { file: outBase + ext, cost: pred.pointsCost + ' 积分（余额 ' + pred.accountBalance + '）', seed: img.seed };
}

// ---------------- 主流程 ----------------
function buildPrompt(charKey, setKey, styleKey) {
  const c = CHARS[charKey], s = SETS[setKey];
  if (!c || !s) throw new Error('未知角色或套：' + charKey + '/' + setKey);
  const tail = styleKey === 'ink' ? INK : styleKey === 'guofeng' ? GUOFENG : styleKey === 'mengchao' ? MENGCHAO : ANIME;
  const poseText = setKey === 'Q版' ? c.qpose : (setKey === '头像' ? '微微侧首，神情平静' : c.pose);
  const head = setKey === 'Q版'
    ? '国风武侠角色' + (styleKey === 'ink' ? '水墨' : '') + 'Q版造型，' + c.body + '，' + c.cloth + '，' + poseText
    : c.body + '，' + c.cloth + '，' + poseText;
  return (head + '。' + s.suffix + tail).replace(/\s+/g, '');
}

async function main() {
  let jobs = [];
  if (has('pilot')) {
    jobs = [
      'shaoxia:立绘:glm:anime',
      'shaoxia:立绘:glm:ink',
      'shaoxia:立绘:liblib:ink',
      'shaoxia:Q版:glm:anime',
    ];
  } else if (has('all')) {
    const style = opt('style', 'anime');
    const channel = opt('channel', 'glm');
    for (const c of Object.keys(CHARS)) for (const s of Object.keys(SETS)) jobs.push([c, s, channel, style].join(':'));
  } else {
    jobs = String(opt('jobs', '')).split(',').map((x) => x.trim()).filter(Boolean);
  }
  if (!jobs.length) { console.log('用法见文件头注释（--pilot / --all / --jobs 角色:套:通道:风格）'); return; }

  const dry = has('dry');
  const force = has('force');
  let spent = 0;
  for (const job of jobs) {
    const [charKey, setKey, channel, styleKey] = job.split(':');
    const label = CHARS[charKey]?.cn + ' · ' + setKey + ' · ' + channel + ' · ' + styleKey;
    const prompt = buildPrompt(charKey, setKey, styleKey);
    var negative = SETS[setKey]?.neg ?? NEG_COMMON;
    if (charKey === 'qingluan') negative = NEG_FEMALE;
    else if (CHARS[charKey]) negative = NEG_MALE;
    const size = SETS[setKey]?.[channel];
    const dir = path.join(OUT_ROOT, charKey);
    const tag = opt('tag', '');
    const outBase = path.join(dir, charKey + '_' + setKey + '_' + channel + '_' + styleKey + (tag ? '_' + tag : ''));
    console.log('──── ' + label + '  ' + size?.join('x') + ' → ' + path.relative(process.cwd(), outBase));
    if (dry) { console.log('  prompt: ' + prompt + '\n'); continue; }
    fs.mkdirSync(dir, { recursive: true });
    if (fs.existsSync(outBase + '.png') || fs.existsSync(outBase + '.jpg')) {
      if (!force) { console.log('  跳过（已存在，--force 重出）'); continue; }
    }
    try {
      const srcImg = opt('img', '');
      const r = (channel === 'liblib' && srcImg)
        ? await genLiblibImg(prompt, negative, size, outBase, opt('lora', ''), srcImg, parseFloat(opt('denoise', '0.45')))
        : channel === 'liblib'
          ? await genLiblib(prompt, negative, size, outBase, opt('lora', ''))
          : await genGlm(prompt, size, outBase);
      console.log('  ✓ ' + path.basename(r.file) + '  ' + r.cost + (r.seed ? '  seed=' + r.seed : ''));
    } catch (e) { console.log('  ✗ 失败：' + e.message); }
  }
  console.log('\n完成。');
}
main().catch((e) => { console.error(e); process.exit(1); });
