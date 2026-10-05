// ============================================================
// 角色美术「提升」：把 assets/gen/char/ 里的生成稿，复制成游戏内固定路径的正式资源
//   assets/gen/char/<角色>/…_Q版_glm_anime_cut.png   → assets/char/<id>_q.png     （战斗纸片人）
//   assets/gen/char/<角色>/…_头像_liblib_guofeng_cut.png → assets/char/<id>_face.png（头像/立绘胸像）
//   assets/gen/char/<角色>/…_立绘_liblib_guofeng_cut.png → assets/char/<id>_full.png（全身立绘）
// 用法：node tools/promote_char_art.mjs
// ============================================================
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const FFMPEG = process.env.FFMPEG || 'C:\\Users\\zq300\\ffmpeg\\bin\\ffmpeg.exe';
// 生成稿是 1000px 级别，游戏里 Q版只显示 ~148px、头像 ~200px——直接缩会糊成一团（无 mipmap 时更糟）。
// 这里就地缩到「显示的 2~3 倍」，既治锯齿又把体积砍掉一个数量级（APK 也吃这个）。
const TARGET_H = { q: 340, face: 460, full: 1000 };

// Godot 导入参数：把 mipmap 打开。
//   为什么必须开：PC 窗口是 450x800（设计分辨率 720x1280 的 0.625×），贴图要**缩小**渲染；
//   没 mipmap 时缩小 = 直接丢采样点 → 边缘锯齿、五官糊成一条（陈石的眉毛+眼睛就糊成黑带）。
//   ⚠ *.import 不进版本库（.gitignore 里有），所以这一步要跟着 promote 一起跑。
function patchImport(pngPath) {
  const imp = pngPath + '.import';
  if (!fs.existsSync(imp)) return 'no-import';
  let t = fs.readFileSync(imp, 'utf8');
  if (t.includes('mipmaps/generate=true')) return 'ok';
  t = t.replace('mipmaps/generate=false', 'mipmaps/generate=true');
  fs.writeFileSync(imp, t);
  return 'patched';
}

function shrink(src, dst, h) {
  const r = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', src, '-vf', 'scale=-1:' + h + ':flags=lanczos', dst], { stdio: 'ignore' });
  return r.status === 0;
}

const MAP = {
  player: { cn: '少侠', dir: 'shaoxia' },
  chen_shi: { cn: '陈石', dir: 'chenshi' },
  qingluan: { cn: '苏青鸾', dir: 'qingluan' },
};

// ---- 敌人 Q版（v66）：目录名就是美术键，一次一批 ----
//   生成方式特殊：不是直接文生图，而是**拿主角 Q版 当底图做 img2img（denoise≈0.62）**——
//   这样二头身比例能带过去（liblib 直接画 Q版 会跑成半写实，见对话记录里的试片）。
const ENEMY_KEYS = [
  ['mob_lou', '喽啰'], ['mob_blade', '刀客'], ['mob_spear', '枪手'], ['mob_bow', '弩手'],
  ['mob_hook', '钩手'], ['mob_flag', '旗手'], ['mob_chief', '头目'], ['mob_one_arm', '独臂刀客'],
  ['mob_dog', '恶犬'],
];
// ⚠ 必须用**抠好的**那张：img2img 原图是白底，直接提升会在战斗里显示成白方块
//   v2（多样性重制）优先：换底图 + 提高重绘幅度，让九个原型不再是同一张脸
// v71：**明亮二次元**优先（用户定调"人物走干净整洁的二次元"）；水墨/写意那几版退成备用
//   dogb = 恶犬专用（四足野兽版，只有 mob_dog 有这张，其他原型自动落到 anime2）
// v79：宠物（智谱出的 Q版 白狐/青隼）
const PETS = [
  ['pet_fox', 'pet_fox'],
  ['pet_falcon', 'pet_falcon'],
];
const ENEMY_SRC = ['_Q版_liblib_anime2_dogb_cut.png', '_Q版_liblib_anime2_anime2_cut.png', '_Q版_liblib_anime_v2_cut.png',
  '_Q版_liblib_anime_img2img_cut.png', '_Q版_liblib_anime_cut.png'];
// 每个槽位按顺序找第一个存在的源文件（后面的是备选画风）
const SLOTS = {
  // v71（用户定调）：**人物回滚彩色二次元 Q版**——"q版二次元更干净整洁、更符合大众审美"；
  //   UI/场景保持水墨。所以这里把 glm_anime 放回第一优先，ink1 退成备用。
  //   girlImg1 = 苏青鸾重画版（用户："苏看上去男的 重画"——把女性特征写死后 img2img 出来的），
  //   只有她有这张，其他角色自动落到下面那行
  // v92（用户："新的苏完全跟主角和陈石不一样"）：**智谱 glm 那版提到第一位**。
  //   病根：苏青鸾的 girlImg1 是 liblib/Qwen 出的**半写实厚涂**，跟主角/陈石的干净二次元
  //   不是一套；她其实早就有一张 glm 版（qingluan_Q版_glm_anime_cut.png），只是被排在后面。
  //   现在三个人统一走 glm 那张（没有 glm 版的角色自动落到后面的备选，行为不变）。
  q: ['_Q版_glm_anime_cut.png', '_Q版_liblib_anime2_girlImg1_cut.png', '_Q版_liblib_xieyi_ink1_cut.png'],
  // v92：苏青鸾的 glm 版胸像提到第一位（她要跟 Q版 身体一个画风；别人没有这张，行为不变）
  face: ['_头像_glm_anime2_cut.png', '_头像_liblib_guofeng_cut.png', '_头像_glm_anime_cut.png'],
  full: ['_立绘_liblib_guofeng_cut.png', '_立绘_glm_ink_cut.png', '_立绘_glm_anime_cut.png'],
};

// 演出片：assets/gen/aivideo/<名>.ogv → assets/clips/<id>_clip.ogv（Godot 只认 Ogg Theora）
const CLIPS = { player: 'clip_player', chen_shi: 'clip_chen_shi', qingluan: 'clip_qingluan' };
const CLIP_OUT = path.resolve('assets/clips');

// 出片通道给的是 1024x1536 的 mp4，底部 ~100px 是平台烧的「AI生成」水印。
// 固定配方：裁掉水印带 → 居中切成 9:16（裁掉左右各 108）→ 缩到 720x1280 → Ogg Theora
//   （Godot 4 只原生认 .ogv；mp4/H.264 要额外插件，APK 上更麻烦）
function ensureOgv(name) {
  const mp4 = path.resolve('assets/gen/aivideo', name + '.mp4');
  const ogv = path.resolve('assets/gen/aivideo', name + '.ogv');
  if (!fs.existsSync(mp4)) return fs.existsSync(ogv) ? ogv : '';
  if (fs.existsSync(ogv) && fs.statSync(ogv).mtimeMs >= fs.statSync(mp4).mtimeMs) return ogv;
  const r = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', mp4,
    '-vf', 'crop=808:1436:108:0,scale=720:1280:flags=lanczos',
    '-c:v', 'libtheora', '-q:v', '7', '-an', ogv], { stdio: 'ignore' });
  if (r.status !== 0) { console.log('  ⚠ ' + name + ' 转 ogv 失败'); return ''; }
  return ogv;
}

const OUT = path.resolve('assets/char');
fs.mkdirSync(OUT, { recursive: true });
const manifest = {};

for (const [id, info] of Object.entries(MAP)) {
  const srcDir = path.resolve('assets/gen/char', info.dir);
  manifest[id] = { cn: info.cn, source_dir: 'assets/gen/char/' + info.dir, slots: {} };
  for (const [slot, cands] of Object.entries(SLOTS)) {
    let hit = '';
    for (const c of cands) {
      const p = path.join(srcDir, info.dir + c);
      if (fs.existsSync(p)) { hit = p; break; }
    }
    if (!hit) { console.log('  ✗ ' + id + ' 缺 ' + slot); continue; }
    const dst = path.join(OUT, id + '_' + slot + '.png');
    const before = fs.statSync(hit).size;
    if (!shrink(hit, dst, TARGET_H[slot])) { fs.copyFileSync(hit, dst); console.log('  ⚠ ' + id + '_' + slot + ' 缩放失败，用原图'); }
    manifest[id].slots[slot] = { file: 'assets/char/' + id + '_' + slot + '.png',
      from: path.relative(process.cwd(), hit).replace(/\\/g, '/'),
      bytes: fs.statSync(dst).size };
    const impState = patchImport(dst);
    console.log('  ✓ ' + path.basename(dst).padEnd(18) + ' ← ' + path.basename(hit) +
      '  ' + Math.round(before / 1024) + 'KB → ' + Math.round(fs.statSync(dst).size / 1024) + 'KB' +
      (impState === 'no-import' ? '  （还没被 Godot 导入过，导入后再跑一次本脚本即可开 mipmap）' : '  mipmap:' + impState));
  }
}
// ---- 宠物（v79）→ assets/char/pet_*.png ----
for (const [dir, out] of PETS) {
  const d = path.resolve('assets/gen/char', dir);
  if (!fs.existsSync(d)) { console.log('  · 宠物 ' + out + ' 还没有生成稿'); continue; }
  const hit = fs.readdirSync(d).filter((f) => /_cut\.png$/.test(f))[0];
  if (!hit) { console.log('  · 宠物 ' + out + ' 没抠好的图'); continue; }
  const dst = path.join(OUT, out + '.png');
  const rp = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', path.join(d, hit), '-vf', 'scale=-1:340:flags=lanczos', dst], { stdio: 'ignore' });
  if (rp.status !== 0) fs.copyFileSync(path.join(d, hit), dst);
  patchImport(dst);
  console.log('  ✓ ' + (out + '.png').padEnd(18) + ' ← ' + hit + '  ' + Math.round(fs.statSync(dst).size / 1024) + 'KB');
}

// ---- 场景（v67）：assets/gen/char/scene_*/… → assets/scenes/<名>.png ----
const SCENES = [
  ['scene_scroll', 'village'],
  ['scene_gate', 'gate'],
  ['scene_tower', 'tower'],
  ['scene_inn', 'inn'],
  ['scene_buildings', 'buildings'],
  ['room_alchemy', 'room_alchemy'],     // v77：炼丹房内景
  ['room_store', 'room_store'],         // v77：货仓内景
  ['chest_open', 'chest_open'],         // v77：宝箱特写（v92 起被下面的宝箱块覆盖，见 CHESTS）
];
const SCENE_OUT = path.resolve('assets/scenes');

// ---- 敌人 Q版（v66）----
let enemy_n = 0;
for (const [key, cn] of ENEMY_KEYS) {
  const dir = path.resolve('assets/gen/char', key);
  let hit = '';
  for (const c of ENEMY_SRC) {
    const p = path.join(dir, key + c);
    if (fs.existsSync(p)) { hit = p; break; }
  }
  if (!hit) { console.log('  · ' + key + '（' + cn + '）还没有生成稿'); continue; }
  const dst = path.join(OUT, key + '_q.png');
  const before = fs.statSync(hit).size;
  if (!shrink(hit, dst, TARGET_H.q)) { fs.copyFileSync(hit, dst); }
  const st = patchImport(dst);
  manifest[key] = { cn: cn, kind: 'enemy', source_dir: 'assets/gen/char/' + key,
    slots: { q: { file: 'assets/char/' + key + '_q.png', from: path.relative(process.cwd(), hit).replace(/\\/g, '/'), bytes: fs.statSync(dst).size } } };
  console.log('  ✓ ' + (key + '_q.png').padEnd(20) + ' ← ' + path.basename(hit) +
    '  ' + Math.round(before / 1024) + 'KB → ' + Math.round(fs.statSync(dst).size / 1024) + 'KB' +
    (st === 'no-import' ? '  （导入后再跑一次开 mipmap）' : '  mipmap:' + st));
  enemy_n++;
}
if (enemy_n > 0) console.log('  敌人 Q版：' + enemy_n + ' 个原型入库');

// ---- 演出片 ----
fs.mkdirSync(CLIP_OUT, { recursive: true });
for (const [id, name] of Object.entries(CLIPS)) {
  const src = ensureOgv(name);
  if (!src) { console.log('  · ' + id + ' 还没有演出片（' + name + '.mp4 / .ogv）'); continue; }
  const dst = path.join(CLIP_OUT, id + '_clip.ogv');
  fs.copyFileSync(src, dst);
  manifest[id].clip = { file: 'assets/clips/' + id + '_clip.ogv', from: 'assets/gen/aivideo/' + name + '.ogv',
    bytes: fs.statSync(dst).size };
  console.log('  ✓ ' + path.basename(dst).padEnd(18) + ' ← ' + name + '.ogv  ' + Math.round(fs.statSync(dst).size / 1024) + 'KB');
}

// ---- 场景（v67）----
fs.mkdirSync(SCENE_OUT, { recursive: true });
const sceneManifest = {};
for (const [dir, name] of SCENES) {
  const srcDir = path.resolve('assets/gen/char', dir);
  if (!fs.existsSync(srcDir)) { console.log('  · 场景 ' + name + ' 还没有生成稿'); continue; }
  // ⚠ 跳过 bld_*（那是建筑切片，另有专门的循环处理）——否则 buildings.png 会被切片顶掉
  const hit = fs.readdirSync(srcDir).filter((f) => /\.(png|jpg)$/i.test(f) && !f.startsWith('bld_'))[0];
  if (!hit) { console.log('  · 场景 ' + name + ' 目录是空的'); continue; }
  const src = path.join(srcDir, hit);
  const dst = path.join(SCENE_OUT, name + '.png');
  const r2 = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', src, '-vf', 'scale=2000:-1:flags=lanczos', dst], { stdio: 'ignore' });
  if (r2.status !== 0) fs.copyFileSync(src, dst);
  patchImport(dst);
  sceneManifest[name] = { file: 'assets/scenes/' + name + '.png', from: path.relative(process.cwd(), src).replace(/\\/g, '/'), bytes: fs.statSync(dst).size };
  console.log('  ✓ ' + (name + '.png').padEnd(16) + ' ← ' + path.basename(src) + '  ' + Math.round(fs.statSync(dst).size / 1024) + 'KB');
}
// ---- 宝箱（v92）----
// 用户："宝箱没有扣干净"。原来的稿是**写实照片风**木箱，抠完四角还挂着白点与水印残渣；
// 现在换成智谱出的水墨木箱（纯白底、--wm 抹过平台水印），只取**抠好的 _cut.png**，
// 按固定宽度缩放进 assets/scenes/（不跟场景那支走 2000 宽，省体积）。
const CHESTS = [
  ['chest_ink', 'chest_closed', 640],
  ['chest_ink_open', 'chest_open', 640],
];
for (const [dir, name, w] of CHESTS) {
  const srcDir = path.resolve('assets/gen/char', dir);
  if (!fs.existsSync(srcDir)) { console.log('  · 宝箱 ' + name + ' 还没有生成稿'); continue; }
  const hit = fs.readdirSync(srcDir).filter((x) => /_cut.png$/i.test(x))[0];
  if (!hit) { console.log('  · 宝箱 ' + name + ' 目录里没有 _cut.png（先跑 cutout_art.mjs）'); continue; }
  const src = path.join(srcDir, hit);
  const dst = path.join(SCENE_OUT, name + '.png');
  const rc = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', src, '-vf', 'scale=' + w + ':-1:flags=lanczos', dst], { stdio: 'ignore' });
  if (rc.status !== 0) fs.copyFileSync(src, dst);
  patchImport(dst);
  console.log('  ✓ ' + (name + '.png').padEnd(16) + ' ← ' + path.basename(src) + '  ' + Math.round(fs.statSync(dst).size / 1024) + 'KB');
}

// 道具图标（items_sheet 那张图集切出来的 it_*_cut.png）→ assets/items/
// v79：后两个目录是智谱出的**二次元**图标（用户："装备功法图……也换成q版吧"），
//   切好后覆盖 assets/items/ 里的同名文件——bag 那边一行代码都不用改。
const ITEM_DIRS = [path.resolve('assets/gen/char/items_sheet'), path.resolve('assets/gen/char/gear_sheet'),
  path.resolve('assets/items2')];
const ITEM_DIR = ITEM_DIRS[0];
const ITEM_OUT = path.resolve('assets/items');
fs.mkdirSync(ITEM_OUT, { recursive: true });
for (const dir of ITEM_DIRS) {
  if (!fs.existsSync(dir)) continue;
  for (const f of fs.readdirSync(dir)) {
    const m = f.match(/^(it_[a-z0-9]+)_cut\.png$/);   // 含数字（it_sword2 之类）
    if (!m) continue;
    const dst = path.join(ITEM_OUT, m[1] + '.png');
    const r4 = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', path.join(dir, f), '-vf', 'scale=-1:200:flags=lanczos', dst], { stdio: 'ignore' });
    if (r4.status !== 0) fs.copyFileSync(path.join(dir, f), dst);
    patchImport(dst);
    console.log('  ✓ items/' + (m[1] + '.png').padEnd(14) + ' ← ' + f);
  }
}

// v75：村里房子的**图**（house_side 那张侧视图集切出来的 house_N_cut.png）→ assets/scenes/
const HOUSE_DIR = path.resolve('assets/gen/char/house_side');
if (fs.existsSync(HOUSE_DIR)) {
  for (const f of fs.readdirSync(HOUSE_DIR)) {
    const m = f.match(/^(house_[1-9])_cut\.png$/);
    if (!m) continue;
    const dst = path.join(SCENE_OUT, m[1] + '.png');
    const r5 = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', path.join(HOUSE_DIR, f), '-vf', 'scale=-1:360:flags=lanczos', dst], { stdio: 'ignore' });
    if (r5.status !== 0) fs.copyFileSync(path.join(HOUSE_DIR, f), dst);
    patchImport(dst);
    sceneManifest[m[1]] = { file: 'assets/scenes/' + m[1] + '.png', from: 'assets/gen/char/house_side/' + f, bytes: fs.statSync(dst).size };
    console.log('  ✓ ' + (m[1] + '.png').padEnd(16) + ' ← ' + f + '  ' + Math.round(fs.statSync(dst).size / 1024) + 'KB');
  }
}

// 建筑切片（从 scene_buildings 那张图集里切出来的 bld_*_cut.png）
const BLD_DIR = path.resolve('assets/gen/char/scene_buildings');
if (fs.existsSync(BLD_DIR)) {
  for (const f of fs.readdirSync(BLD_DIR)) {
    const m = f.match(/^(bld_[a-z]+)_cut\.png$/);
    if (!m) continue;
    const dst = path.join(SCENE_OUT, m[1] + '.png');
    const r3 = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', path.join(BLD_DIR, f), '-vf', 'scale=-1:520:flags=lanczos', dst], { stdio: 'ignore' });
    if (r3.status !== 0) fs.copyFileSync(path.join(BLD_DIR, f), dst);
    patchImport(dst);
    sceneManifest[m[1]] = { file: 'assets/scenes/' + m[1] + '.png', from: 'assets/gen/char/scene_buildings/' + f, bytes: fs.statSync(dst).size };
    console.log('  ✓ ' + (m[1] + '.png').padEnd(16) + ' ← ' + f + '  ' + Math.round(fs.statSync(dst).size / 1024) + 'KB');
  }
}

fs.writeFileSync(path.join(SCENE_OUT, 'manifest.json'), JSON.stringify(sceneManifest, null, 2));

fs.writeFileSync(path.join(OUT, 'art_manifest.json'), JSON.stringify(manifest, null, 2));
console.log('\n清单：assets/char/art_manifest.json');
