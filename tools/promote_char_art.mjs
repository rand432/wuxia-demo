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
const ENEMY_SRC = ['_Q版_liblib_anime_v2_cut.png', '_Q版_liblib_anime_img2img_cut.png',
  '_Q版_liblib_anime_cut.png', '_Q版_liblib_anime_v2.png', '_Q版_liblib_anime_img2img.png'];
// 每个槽位按顺序找第一个存在的源文件（后面的是备选画风）
const SLOTS = {
  // v68：Q版 统一到水墨（ink1 优先）——原来那套彩色二次元 Q版 和敌人/场景不是一路
  q: ['_Q版_liblib_xieyi_ink1_cut.png', '_Q版_glm_anime_cut.png'],
  face: ['_头像_liblib_guofeng_cut.png', '_头像_glm_anime_cut.png'],
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
// ---- 场景（v67）：assets/gen/char/scene_*/… → assets/scenes/<名>.png ----
const SCENES = [
  ['scene_scroll', 'village'],
  ['scene_gate', 'gate'],
  ['scene_tower', 'tower'],
  ['scene_inn', 'inn'],
  ['scene_buildings', 'buildings'],
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
// 道具图标（items_sheet 那张图集切出来的 it_*_cut.png）→ assets/items/
const ITEM_DIR = path.resolve('assets/gen/char/items_sheet');
const ITEM_OUT = path.resolve('assets/items');
if (fs.existsSync(ITEM_DIR)) {
  fs.mkdirSync(ITEM_OUT, { recursive: true });
  for (const f of fs.readdirSync(ITEM_DIR)) {
    const m = f.match(/^(it_[a-z]+)_cut\.png$/);
    if (!m) continue;
    const dst = path.join(ITEM_OUT, m[1] + '.png');
    const r4 = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', path.join(ITEM_DIR, f), '-vf', 'scale=-1:200:flags=lanczos', dst], { stdio: 'ignore' });
    if (r4.status !== 0) fs.copyFileSync(path.join(ITEM_DIR, f), dst);
    patchImport(dst);
    console.log('  ✓ items/' + (m[1] + '.png').padEnd(14) + ' ← ' + f);
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
