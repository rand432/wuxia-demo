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
const clips = EDL.map((e) => {
  const base = e.dur ?? dur(clipPath(e));
  const sp = e.speed ?? 1;
  return { p: clipPath(e), d: +(base / sp).toFixed(3), sp, note: e.note };
});
let norm = '';
clips.forEach((c, i) => {
  const pre = c.sp !== 1 ? 'setpts=PTS/' + c.sp + ',' : '';
  norm += '[' + i + ':v]' + pre + 'fps=25,scale=1280:720,setsar=1,format=yuv420p,settb=AVTB[n' + i + '];';
});
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

// ---------- ③ 字幕（横排 · 浓墨描边 + 淡墨外晕 · 无衬底）----------
const SB = rd('subs.json');
const ST = W + '/subs';
fs.mkdirSync(ST, { recursive: true });
const FSZ = 38, MAXC = 19;
// 按时间轴自动定位：文字属于哪一段，就跟着那一段的起止
const TJ = JSON.parse(fs.readFileSync(W + '/times.json', 'utf8'));
const MISS = [];
const seg = (kw) => {
  const hit = TJ.times.find((t) => t.note.includes(kw));
  if (!hit) { MISS.push(kw); return { start: 0, end: 5 }; }
  return hit;
};
// 每句给一个「锚点关键词」，落点 = 该段的 start + 偏移
const ANCHOR = {
  // 拆段点全部按 silencedetect 实测的句号停顿校准
  '旁_01': ['墨入水', 0.8, 4.2],
  '旁_02': ['荒原流民', 1.0, 6.6],
  '旁_03': ['纸醉金迷', 1.0, 6.6],
  '旁_04': ['刀在膝上', 1.2, 7.4],
  '旁_05': ['婚礼', 1.2, 4.2],      '旁_05b': ['婚礼', 5.6, 3.2],
  '旁_06': ['门外护卫', 1.2, 2.5],   '旁_06b': ['门外护卫', 5.25, 5.6],
  '旁_07': ['翻杯围拢', 1.5, 5.2],
  '旁_尾': ['行走墨线', 4.6, 2.9],   '旁_尾b': ['行走墨线', 7.8, 4.2],
  '声_敌人2': ['靠树喘息', 1.5, 2.5], '声_我1': ['五问', 8.0, 5.7],
  '声_敌人1': ['这酒', 0.5, 4.0],
  '黑幕我': ['我要死了吗', 0.3, 2.4],
  '不甘A': ['没死', 0.4, 2.0],       '不甘B': ['没死', 2.6, 3.4]
};
const wrap = (t) => { const c = [...t]; const out = []; for (let i = 0; i < c.length; i += MAXC) out.push(c.slice(i, i + MAXC).join('')); return out.join('\n'); };
// 三层套叠 = 淡墨外晕 + 浓墨描边 + 亮字
const DRAWTEXT = (fn, y, fs2, s, e, big) => {
  const base = "fontfile='C\\:/Windows/Fonts/simkai.ttf':textfile='" + fn.replace(/:/g, '\\:') + "'" +
               ':x=(w-text_w)/2:y=' + y + ':fontsize=' + fs2 + ":line_spacing=10:enable='between(t," + s + ',' + e + ')' + "'";
  let o = '';
  o += ',drawtext=' + base + ":fontcolor=0x000000@0:bordercolor=0x000000@0.20:borderw=" + (big ? 16 : 13);
  o += ',drawtext=' + base + ":fontcolor=0x000000@0:bordercolor=0x000000@0.42:borderw=" + (big ? 9 : 7);
  o += ',drawtext=' + base + ':fontcolor=0xf7f3e8@0.98:bordercolor=0x0b0b0e@0.90:borderw=3';
  return o;
};
let sf = '';
SB.bottom.forEach((n, i) => {
  const a = ANCHOR[n.k] || ['墨入水', 0.5, 4];
  const g = seg(a[0]); const s = +(g.start + a[1]).toFixed(2), e = +(g.start + a[1] + a[2]).toFixed(2);
  const fn = ST + '/T' + i + '.txt'; fs.writeFileSync(fn, wrap(n.t), 'utf8');
  sf += DRAWTEXT(fn, 'h-text_h-52', FSZ, s, e, false);
});
SB.black.forEach((n, i) => {
  const a = ANCHOR[n.k] || ['墨入水', 0.5, 2];
  const g = seg(a[0]); const s = +(g.start + a[1]).toFixed(2), e = +(g.start + a[1] + a[2]).toFixed(2);
  const fn = ST + '/K' + i + '.txt'; fs.writeFileSync(fn, wrap(n.t), 'utf8');
  sf += DRAWTEXT(fn, '(h-text_h)/2', 48, s, e, true);
});
if (MISS.length) {
  const uniq = [...new Set(MISS)];
  console.error('');
  console.error('!!! 锚点匹配失败 ' + uniq.length + ' 个（会被错放到片头 0s）: ' + uniq.join(' / '));
  console.error('!!! 请检查 subs.json 的 k 是否在生成器 ANCHOR 里、且关键词能在 edl.json 的 note 里找到');
  console.error('');
  process.exitCode = 3;
}
fs.writeFileSync(W + '/subs.txt', sf.replace(/^,/, ''), 'utf8');
console.log('[生成] subs.txt  ' + sf.length + ' 字符');
