// 开场动画构建 · 滤镜生成器
// 读 tools/{edl,subs,audio_mix}.json → 生成 export/_work/ 下的滤镜文件
import fs from 'node:fs';
import path from 'node:path';

const WS  = 'D:/1/wuxia-demo';
const T   = WS + '/assets/_edit';
const EX  = WS + '/export';
const W   = EX + '/_work';
fs.mkdirSync(W, { recursive: true });
const rd = (p) => JSON.parse(fs.readFileSync(WS + '/tools/' + p, 'utf8'));

// ---------- ① 拼片 ----------
const EDL = rd('edl.json');
const clipPath = (e) => {
  if (e.type === 'ai')    return WS + '/assets/gen/aivideo/' + e.file;
  if (e.type === 'ref')   return T + '/ref/' + e.file;
  if (e.type === 'black') return T + '/black/' + e.file;
  throw new Error('未知类型 ' + e.type);
};
const dur = (p) => {
  // 用 ffprobe 太慢，这里用已知时长表；缺的按 5s 兜底
  const M = JSON.parse(fs.readFileSync(WS + '/tools/durations.json', 'utf8'));
  const k = p.split(/[\\/]/).pop();
  return M[k] ?? 5;
};
const clips = EDL.map((e) => ({ p: clipPath(e), d: e.dur ?? dur(clipPath(e)), note: e.note }));
let norm = '';
clips.forEach((c, i) => { norm += '[' + i + ':v]fps=25,scale=1280:720,setsar=1,format=yuv420p,settb=AVTB[n' + i + '];'; });
let vf = norm, prev = '[n0]', total = clips[0].d;
const times = [{ start: 0, end: clips[0].d, note: clips[0].note }];
for (let i = 1; i < clips.length; i++) {
  const isBlack = clips[i].p.includes('BLACK_') || clips[i-1].p.includes('BLACK_');
  const tr = isBlack ? { t: 'fadeblack', d: 0.5 } : { t: 'fade', d: 0.6 };
  const out = i === clips.length - 1 ? '[vout]' : '[v' + i + ']';
  vf += prev + '[n' + i + ']xfade=transition=' + tr.t + ':duration=' + tr.d +
        ':offset=' + (total - tr.d).toFixed(3) + out + ';';
  const st = total - tr.d;
  times.push({ start: st, end: st + clips[i].d, note: clips[i].note });
  prev = out; total = st + clips[i].d;
}
// 剥掉末尾多余的分号
vf = vf.replace(/;$/, '');
fs.writeFileSync(W + '/vf.txt', vf, 'utf8');
fs.writeFileSync(W + '/inputs.json', JSON.stringify(clips.map((c) => c.p)), 'utf8');
fs.writeFileSync(W + '/times.json', JSON.stringify({ times, total }, null, 2), 'utf8');
console.log('[生成] vf.txt  ' + vf.length + ' 字符   总长 ' + total.toFixed(2) + 's');

// ---------- ② 声轨 ----------
const AM = rd('audio_mix.json');
const A  = WS + '/assets/gen/audio';
const af = [];
const afIn = [];
const idx = {};
const need = (f) => { if (!(f in idx)) { idx[f] = afIn.length; afIn.push(A + '/' + f + '.wav'); } return idx[f]; };
const ms = (s) => Math.round(s * 1000);
let k = 0;
for (const b of AM.beds) {
  const i = need(b.f);
  let ch = '[' + i + ':a]volume=' + b.vol;
  if (b.fin)    ch += ',afade=t=in:st=0:d=' + b.fin;
  if (b.foutAt) ch += ',afade=t=out:st=' + b.foutAt + ':d=' + (b.fout ?? 2);
  ch += ',adelay=' + ms(b.at) + '|' + ms(b.at) + '[x' + (k++) + ']';
  af.push(ch);
}
for (const s of AM.sfx) {
  const i = need(s.f);
  let ch = '[' + i + ':a]volume=' + s.vol;
  if (s.fin)    ch += ',afade=t=in:st=0:d=' + s.fin;
  if (s.foutAt) ch += ',afade=t=out:st=' + s.foutAt + ':d=' + (s.fout ?? 2);
  ch += ',adelay=' + ms(s.at) + '|' + ms(s.at) + '[x' + (k++) + ']';
  af.push(ch);
}
if (AM.bells) {
  const i = need(AM.bells.f);
  const labels = [];
  for (let n = 0; n < AM.bells.n; n++) labels.push('[bb' + n + ']');
  af.push('[' + i + ':a]asplit=' + AM.bells.n + labels.join(''));
  for (let n = 0; n < AM.bells.n; n++) {
    af.push('[bb' + n + ']volume=' + AM.bells.vol + ',afade=t=out:st=3.2:d=2,adelay=' +
            ms(AM.bells.at + n * AM.bells.step) + '|' + ms(AM.bells.at + n * AM.bells.step) + '[x' + (k++) + ']');
  }
}
for (const v of AM.voice) {
  const i = need(v.f);
  af.push('[' + i + ':a]volume=' + v.vol + ',adelay=' + ms(v.at) + '|' + ms(v.at) + '[x' + (k++) + ']');
}
const mixLabels = Array.from({ length: k }, (_, n) => '[x' + n + ']').join('');
af.push(mixLabels + 'amix=inputs=' + k + ':duration=longest:dropout_transition=0:normalize=0,alimiter=limit=0.78:level=false,apad=whole_dur=' + (total + 0.2).toFixed(1) + '[aout]');
fs.writeFileSync(W + '/af.txt', af.join(';'), 'utf8');
fs.writeFileSync(W + '/ainputs.json', JSON.stringify(afIn), 'utf8');
console.log('[生成] af.txt  ' + k + ' 路混音');

// ---------- ③ 字幕 ----------
const SB = rd('subs.json');
const ST = W + '/subs';
fs.mkdirSync(ST, { recursive: true });
const FSZ = 34, LS = 9, COLW = FSZ + 22, X0 = 42;
let sf = '';
const box = (x, y, w, h, s, e) => {   // 柔边墨色衬底：4 层套叠，越靠外越淡
  const layers = [[26, '0.09'], [18, '0.14'], [10, '0.24'], [0, '0.36']];
  let o = '';
  for (const [pad, a] of layers) {
    o += ',drawbox=x=' + (x - pad) + ':y=' + (y - pad) + ':w=' + (w + pad * 2) + ':h=' + (h + pad * 2) +
         ':color=0x17140f@' + a + ':t=fill:enable=\'between(t,' + s + ',' + e + ')\'';
  }
  return o;
};
SB.left.forEach((n, i) => {
  const chars = [...n.t]; const cols = [];
  for (let q = 0; q < chars.length; q += 15) cols.push(chars.slice(q, q + 15));
  const rows = Math.max(...cols.map((c) => c.length));
  const bw = (cols.length - 1) * COLW + FSZ;
  const bh = rows * (FSZ + LS) + 26;          // 多留余量，别让末字露在框外
  const bx = X0 - 14, by = Math.round((720 - bh) / 2);
  sf += box(bx, by, bw + 28, bh, n.s, n.e);
  cols.forEach((col, ci) => {
    const fn = ST + '/L' + i + '_' + ci + '.txt';
    fs.writeFileSync(fn, col.join('\n'), 'utf8');
    const xo = X0 + (cols.length - 1 - ci) * COLW;
    sf += ',drawtext=fontfile=\'C\\:/Windows/Fonts/simkai.ttf\':textfile=\'' + fn.replace(/:/g, '\\:') +
          '\':x=' + xo + ':y=(h-text_h)/2:fontsize=' + FSZ + ':fontcolor=0xf3efe5@0.96:line_spacing=' + LS +
          ':enable=\'between(t,' + n.s + ',' + n.e + ')\'';
  });
});
SB.center.forEach((n, i) => {
  const fn = ST + '/C' + i + '.txt'; fs.writeFileSync(fn, n.t, 'utf8');
  sf += ',drawtext=fontfile=\'C\\:/Windows/Fonts/simkai.ttf\':textfile=\'' + fn.replace(/:/g, '\\:') +
        '\':x=(w-text_w)/2:y=h-text_h-58:fontsize=40:fontcolor=0xf6f2e8@0.97:borderw=3:bordercolor=0x000000@0.72' +
        ':enable=\'between(t,' + n.s + ',' + n.e + ')\'';
});
SB.black.forEach((n, i) => {
  const fn = ST + '/B' + i + '.txt'; fs.writeFileSync(fn, [...n.t].join('\n'), 'utf8');
  sf += ',drawtext=fontfile=\'C\\:/Windows/Fonts/simkai.ttf\':textfile=\'' + fn.replace(/:/g, '\\:') +
        '\':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=46:fontcolor=0xf6f2e8@0.97:line_spacing=11' +
        ':enable=\'between(t,' + n.s + ',' + n.e + ')\'';
});
SB.flash.forEach((n, i) => {
  const fn = ST + '/F' + i + '.txt'; fs.writeFileSync(fn, n.t, 'utf8');
  sf += ',drawtext=fontfile=\'C\\:/Windows/Fonts/simkai.ttf\':textfile=\'' + fn.replace(/:/g, '\\:') +
        '\':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=42:fontcolor=0xf6f2e8@0.95:borderw=3:bordercolor=0x000000@0.75' +
        ':enable=\'between(t,' + n.s + ',' + n.e + ')\'';
});
fs.writeFileSync(W + '/subs.txt', sf.replace(/^,/, ''), 'utf8');
console.log('[生成] subs.txt  ' + sf.length + ' 字符');
