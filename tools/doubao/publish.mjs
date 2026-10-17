// 把生成图落进游戏：抠底 → 缩放到目标规格 → 备份旧图 → 覆盖
// 用法：node tools/doubao/publish.mjs [--dry] [--plan tools/doubao/publish.json]
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { WS, cli, flag, say, ensureDir } from './lib.mjs';

const FFMPEG = process.env.FFMPEG || 'C:\\Users\\zq300\\ffmpeg\\bin\\ffmpeg.exe';
const a = cli();
const planPath = path.resolve(WS, String(a.plan || 'tools/doubao/publish.json'));
const groups = JSON.parse(fs.readFileSync(planPath, 'utf8'));
const dry = flag(a, 'dry');
const stamp = new Date().toISOString().slice(0, 10);
const backupDir = path.join(WS, 'assets', '_backup-' + stamp);

let done = 0;
let failed = 0;
for (const g of groups) {
  const srcDir = path.resolve(WS, g.src);
  const dstDir = path.resolve(WS, g.dst);
  if (!fs.existsSync(srcDir)) { say.warn('缺源目录 ' + g.src); continue; }
  ensureDir(dstDir);
  let files = fs.readdirSync(srcDir).filter(f => /\.(jpg|jpeg|png)$/i.test(f) && !/_cut\.png$/i.test(f) && !f.startsWith('_'));
  if (g.only) files = files.filter(f => g.only.includes(path.parse(f).name));
  say.step(g.dst + '  ' + files.length + ' 张  ' + (g.mode === 'height' ? g.height + 'px 高' : g.size + 'x' + g.size) + (dry ? '  [dry]' : ''));
  for (const f of files) {
    const base = path.parse(f).name;
    const src = path.join(srcDir, f);
    const cut = path.join(srcDir, base + '_cut.png');
    try {
      if (!fs.existsSync(cut)) {
        execFileSync(process.execPath, [path.join(WS, 'tools', 'cutout_art.mjs'), src, '--pad', '0'], { stdio: 'pipe' });
      }
      if (!fs.existsSync(cut)) throw new Error('抠图没有产出（白底没连到边？）');
      const outName = base + (g.suffix || '') + '.png';
      const outPath = path.join(dstDir, outName);
      const tmp = path.join(dstDir, '.tmp-' + outName);
      const vf = g.mode === 'height'
        ? 'scale=-1:' + g.height + ':flags=lanczos'
        : 'scale=' + g.size + ':' + g.size + ':force_original_aspect_ratio=decrease,pad=' + g.size + ':' + g.size + ':(ow-iw)/2:(oh-ih)/2:color=0x00000000';
      execFileSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', cut, '-vf', vf, '-pix_fmt', 'rgba', tmp], { stdio: 'pipe' });
      if (dry) { fs.rmSync(tmp, { force: true }); say.info('会写 ' + outName); done++; continue; }
      if (fs.existsSync(outPath)) {
        const rel = path.relative(path.join(WS, 'assets'), outPath);
        const bak = path.join(backupDir, rel);
        ensureDir(path.dirname(bak));
        fs.copyFileSync(outPath, bak);
      }
      fs.renameSync(tmp, outPath);
      done++;
      say.ok(outName);
    } catch (e) {
      failed++;
      say.warn(base + ' 失败：' + String((e && e.message) || e).slice(0, 140));
    }
  }
}
say.step('完成  写入 ' + done + ' · 失败 ' + failed + (dry ? '（dry run，未改动）' : ' · 旧图备份在 ' + path.relative(WS, backupDir)));
