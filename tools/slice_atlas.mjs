// ============================================================
// slice_atlas.mjs —— 把 TexturePacker 的 .plist 图集切成单张图标
//   用法：node slice_atlas.mjs <xxx.plist> <输出目录>
//   素材库（素材/res_mirror）里的 icon / icon_equipment / icon_skill / icon_buff / head
//   都是"一张大图 + 一个 plist"，切出来就能当我们的道具图标用。
// ============================================================
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const FFMPEG = process.env.FFMPEG || 'C:\\Users\\zq300\\ffmpeg\\bin\\ffmpeg.exe';
const [plist, outDir] = process.argv.slice(2);
if (!plist || !outDir) { console.log('用法：node slice_atlas.mjs <plist> <输出目录>'); process.exit(1); }
const xml = fs.readFileSync(plist, 'utf8');
const atlas = path.join(path.dirname(plist), (xml.match(/<key>textureFileName<\/key>\s*<string>([^<]+)<\/string>/) ?? [])[1] ?? path.basename(plist).replace(/\.plist$/i, '.png'));
fs.mkdirSync(outDir, { recursive: true });

// 逐个 frame：<key>名字</key> 后面跟 <dict> … <key>frame</key><string>{{x,y},{w,h}}</string>
const re = /<key>([^<]+)<\/key>\s*<dict>([\s\S]*?)<\/dict>/g;
let m, n = 0;
const manifest = {};
while ((m = re.exec(xml)) !== null) {
	const name = m[1];
	if (name === 'frames' || name === 'metadata') continue;
	const body = m[2];
	const fr = (body.match(/<key>frame<\/key>\s*<string>\{\{(-?\d+),(-?\d+)\},\{(-?\d+),(-?\d+)\}\}<\/string>/) ?? []);
	if (fr.length < 5) continue;
	const [x, y, w, h] = [Number(fr[1]), Number(fr[2]), Number(fr[3]), Number(fr[4])];
	const safe = name.replace(/\.png$/i, '').replace(/[\\/:*?"<>|]/g, '_');
	const dst = path.join(outDir, safe + '.png');
	const rc = spawnSync(FFMPEG, ['-y', '-loglevel', 'error', '-i', atlas, '-vf', 'crop=' + w + ':' + h + ':' + x + ':' + y, dst], { stdio: 'ignore' });
	if (rc.status === 0) { manifest[safe] = { w, h }; n++; }
}
fs.writeFileSync(path.join(outDir, '_manifest.json'), JSON.stringify(manifest, null, 1));
console.log('✓ ' + path.basename(plist) + ' → ' + outDir + '  共 ' + n + ' 张（图集 ' + path.basename(atlas) + '）');
