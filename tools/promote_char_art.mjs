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
// 每个槽位按顺序找第一个存在的源文件（后面的是备选画风）
const SLOTS = {
  q: ['_Q版_glm_anime_cut.png'],
  face: ['_头像_liblib_guofeng_cut.png', '_头像_glm_anime_cut.png'],
  full: ['_立绘_liblib_guofeng_cut.png', '_立绘_glm_ink_cut.png', '_立绘_glm_anime_cut.png'],
};

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
fs.writeFileSync(path.join(OUT, 'art_manifest.json'), JSON.stringify(manifest, null, 2));
console.log('\n清单：assets/char/art_manifest.json');
