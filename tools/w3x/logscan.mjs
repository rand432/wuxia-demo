
import fs from "node:fs";
import path from "node:path";
const roots = ["D:\\1\\魔兽争霸3冰封王座\\Logs", "D:\\1\\魔兽争霸3冰封王座\\日志", "D:\\1\\魔兽争霸3冰封王座\\万华镜", "D:\\1\\魔兽争霸3冰封王座\\动漫明星乱斗", "D:\\1\\魔兽争霸3冰封王座\\梦迹沙河0", "D:\\1\\魔兽争霸3冰封王座\\Errors"];
const files = [];
function walk(d, depth) {
  if (depth > 4) return;
  let ents = [];
  try { ents = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
  for (const e of ents) {
    const f = path.join(d, e.name);
    try { const st = fs.statSync(f); if (e.isDirectory()) walk(f, depth + 1); else if (st.size < 20 * 1024 * 1024) files.push(f); } catch {}
  }
}
for (const r of roots) walk(r, 0);
console.log("log files:", files.length);
const needles = ["刷刷", "重生", "魔兽刷"];
let hits = 0;
for (const f of files) {
  let buf;
  try { buf = fs.readFileSync(f); } catch { continue; }
  const txt = new TextDecoder("gbk").decode(buf);
  for (const n of needles) {
    const i = txt.indexOf(n);
    if (i >= 0) {
      hits++;
      console.log("HIT", f, "|", txt.slice(Math.max(0, i - 80), i + 120).replace(/\s+/g, " "));
      break;
    }
  }
}
console.log("total hits:", hits);
