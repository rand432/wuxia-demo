// 算力恢复后自动接手：把新出的 03 / 02 换进剪辑表并重出成片
// 用法： node tools/promote.mjs [03|02|all]
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const WS = 'D:/1/wuxia-demo';
const AI = WS + '/assets/gen/aivideo/';
const ED = WS + '/tools/edl.json';
const DU = WS + '/tools/durations.json';
const want = (process.argv[2] || 'all');
let changed = 0;

function probe(file) {
  try {
    return parseFloat(execFileSync('C:/Users/zq300/ffmpeg/bin/ffprobe.exe',
      ['-v','error','-show_entries','format=duration','-of','default=noprint_wrappers=1:nokey=1', file]).toString().trim());
  } catch { return 0; }
}

const edl = JSON.parse(fs.readFileSync(ED, 'utf8'));
const dur = JSON.parse(fs.readFileSync(DU, 'utf8'));

// 03：从 2.5D 缓推版换回真视频
if ((want === 'all' || want === '03') && fs.existsSync(AI + '03_纸醉金迷.mp4')) {
  const e = edl.find((x) => x.note && x.note.includes('纸醉金迷'));
  if (e && e.type === 'fx') {
    const d = probe(AI + '03_纸醉金迷.mp4');
    if (d > 0) {
      e.type = 'ai'; e.file = '03_纸醉金迷.mp4'; e.note = '纸醉金迷（陶盏·真动画）';
      dur['03_纸醉金迷.mp4'] = d;
      console.log('✓ 03 换回真视频  ' + d.toFixed(2) + 's'); changed++;
    }
  } else console.log('· 03 已经是视频版，跳过');
}

// 02：换成运动量足够的新版
if ((want === 'all' || want === '02') && fs.existsSync(AI + '02_荒原流民.mp4')) {
  const st = fs.statSync(AI + '02_荒原流民.mp4');
  // 只在新版比登记时长更新时替换（避免把老素材又换回去）
  if (st.mtimeMs > Date.parse('2026-09-29T00:00:00')) {
    const e = edl.find((x) => x.note && x.note.includes('荒原流民'));
    const d = probe(AI + '02_荒原流民.mp4');
    if (e && d > 0) { e.type = 'ai'; e.file = '02_荒原流民.mp4'; dur['02_荒原流民.mp4'] = d;
      console.log('✓ 02 换成新版  ' + d.toFixed(2) + 's'); changed++; }
  } else console.log('· 02 素材不是新的，跳过');
}

if (!changed) { console.log('没有需要换的，退出'); process.exit(0); }
fs.writeFileSync(ED, JSON.stringify(edl, null, 2), 'utf8');
fs.writeFileSync(DU, JSON.stringify(dur, null, 2), 'utf8');
console.log('✓ 剪辑表已更新，开始重出成片...');