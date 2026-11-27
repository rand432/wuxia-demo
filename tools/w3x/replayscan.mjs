
import fs from "node:fs";
import path from "node:path";
const root = "D:\\1\\魔兽争霸3冰封王座\\Replay";
const files = [];
function walk(d, depth) {
  if (depth > 6) return;
  let ents = [];
  try { ents = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
  for (const e of ents) {
    const f = path.join(d, e.name);
    try { const st = fs.statSync(f); if (e.isDirectory()) walk(f, depth + 1); else if (/\.(nwg|w3g)$/i.test(e.name) && st.size > 1000) files.push(f); } catch {}
  }
}
walk(root, 0);
console.log("replays:", files.length);
const decoders = [new TextDecoder("utf-8"), new TextDecoder("gbk")];
let hitCount = 0;
for (const f of files) {
  let buf;
  try { buf = fs.readFileSync(f); } catch { continue; }
  for (const dec of decoders) {
    const txt = dec.decode(buf);
    for (const needle of ["重生魔兽", "刷刷刷", "魔兽刷刷"]) {
      const i = txt.indexOf(needle);
      if (i >= 0) {
        hitCount++;
        console.log("HIT", path.relative(root, f), "|", needle, "|", txt.slice(Math.max(0, i - 100), i + 150).replace(/[\x00-\x1f]/g, "."));
        break;
      }
    }
  }
}
console.log("hits:", hitCount);
// also dump ascii strings that look like map paths
for (const f of files.slice(0, 3)) {
  const buf = fs.readFileSync(f);
  const s = buf.toString("latin1");
  const m = s.match(/[ -~]{6,}/g) || [];
  console.log(f.split("\\").pop(), "strings:", m.filter(x => /w3x|Maps|war3map|kk/i.test(x)).slice(0, 8).join(" | "));
}
