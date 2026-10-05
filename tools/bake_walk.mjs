// ============================================================
// 走路视频 → 游戏用帧序列图（v93）
//   用法：node tools/bake_walk.mjs <id> [帧数] [高度]
//   输入：assets/gen/aivideo/walk_<id>.mp4（智谱 CogVideoX 图生视频出的）
//   输出：assets/char/<id>_walk.png（横向帧序列图，各帧等宽，已抠底）
//   过程：抽帧 → 裁掉平台水印带 → 抠白底（复用 cutout_art.mjs 的 flood）→ 横向拼图
// ============================================================
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawnSync } from 'node:child_process';

const FFMPEG = process.env.FFMPEG || 'C:\\Users\\zq300\\ffmpeg\\bin\\ffmpeg.exe';
const args = process.argv.slice(2);
const id = args[0];
const N = parseInt(args[1] || '10', 10);
const H = parseInt(args[2] || '190', 10);
if (!id) { console.log('用法：node tools/bake_walk.mjs <id> [帧数] [高度]'); process.exit(1); }

const mp4 = path.resolve('assets/gen/aivideo', 'walk_' + id + '.mp4');
if (!fs.existsSync(mp4)) { console.log('✗ 没有视频：' + mp4); process.exit(1); }
const tmp = path.join(os.tmpdir(), 'walkbake_' + id + '_' + Date.now());
fs.mkdirSync(tmp, { recursive: true });

// ① 抽帧：等间隔 N 帧；**裁掉底部 9%**（智谱烧的「AI生成」水印就在那一带）
const r1 = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', mp4,
  '-vf', 'crop=iw:ih*0.91:0:0,fps=' + N + '/4,scale=-1:' + H,
  path.join(tmp, 'f_%03d.png')], { stdio: 'inherit' });
if (r1.status !== 0) { console.log('✗ 抽帧失败'); process.exit(1); }
let frames = fs.readdirSync(tmp).filter((f) => f.startsWith('f_')).sort().slice(0, N);
console.log('抽到 ' + frames.length + ' 帧');

// ② 抠白底：直接调现成的抠图工具（flood 模式）
const cut = spawnSync('node', [path.resolve('tools/cutout_art.mjs'), tmp, '--mode', 'flood', '--tol', '30', '--pad', '2'],
  { stdio: 'inherit' });
if (cut.status !== 0) { console.log('  ⚠ 抠图工具返回非 0，继续试'); }

// cutout 会把 f_001.png 变成 f_001_cut.png，优先用 cut 版
const cuts = frames.map((f) => path.join(tmp, f.replace(/\.png$/, '_cut.png'))).filter((p) => fs.existsSync(p));
const use = cuts.length === frames.length ? cuts : frames.map((f) => path.join(tmp, f));
console.log('用 ' + (cuts.length === frames.length ? '抠好的' : '原') + ' 帧拼图');

// ③ 横向拼图（等宽：都缩到同一高度，按最宽的留边）
const sheet = path.resolve('assets/char', id + '_walk.png');
const inputs = use.flatMap((p) => ['-i', p]);
const n = use.length;
const parts = use.map((_, i) => '[' + i + ':v]scale=-1:' + H + ',pad=iw:ih:0:0:color=0x00000000[s' + i + ']').join(';');
const stack = use.map((_, i) => '[s' + i + ']').join('') + 'hstack=inputs=' + n;
const r3 = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', ...inputs, '-filter_complex', parts + ';' + stack, '-frames:v', '1', sheet], { stdio: 'inherit' });
if (r3.status !== 0) { console.log('✗ 拼图失败'); process.exit(1); }
console.log('✓ ' + sheet + '  ' + Math.round(fs.statSync(sheet).size / 1024) + 'KB  (' + n + ' 帧)');

// ④ 写清单：帧数 + 单帧宽高比（游戏那边按这个切图，不用猜）
const man = path.resolve('assets/char/walk_frames.json');
let m = {};
try { m = JSON.parse(fs.readFileSync(man, 'utf8')); } catch {}
const fw = (() => {
	const r = spawnSync('C:\\Users\\zq300\\ffmpeg\\bin\\ffprobe.exe', ['-v', 'error', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', sheet], { encoding: 'utf8' });
	const [w, h] = String(r.stdout).trim().split(',').map(Number);
	return w && h ? (w / n) / h : 0.63;
})();
m[id] = { n, aw: Math.round(fw * 1000) / 1000 };
fs.writeFileSync(man, JSON.stringify(m, null, 1));
console.log('✓ 清单 ' + man + ' → ' + JSON.stringify(m[id]));
fs.rmSync(tmp, { recursive: true, force: true });
