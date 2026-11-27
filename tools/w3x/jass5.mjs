
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const jass = fs.readFileSync(base + "war3map.decoded.j", "utf8");
const lines = jass.split("\n");
const trigAt = new Array(lines.length).fill("");
let cur = "";
for (let i = 0; i < lines.length; i++) { const m = lines[i].match(/\/\/\s*Trigger:\s*(.+)/); if (m) cur = m[1].trim(); trigAt[i] = cur; }
function funcOf(idx) { let s = idx, e = idx; while (s > 0 && !/^function\s/.test(lines[s])) s--; while (e < lines.length && !/^endfunction/.test(lines[e])) e++; return [s, e]; }
for (const kw of ["第一波BOSS来临", "第二波BOSS来临", "最终波BOSS来临"]) {
  const idx = lines.findIndex(l => l.includes(kw));
  if (idx < 0) { console.log("miss", kw); continue; }
  const [s, e] = funcOf(idx);
  console.log("\n=== " + kw + " @ " + trigAt[idx] + " (lines " + s + "-" + e + ") ===");
  // print lines around the set-text call, ±18
  console.log(lines.slice(Math.max(s, idx - 18), Math.min(e, idx + 22)).map(l => l.trim().slice(0, 150)).join("\n"));
}
// wave trigger 刷怪03: print its beginning with time conditions
const i3 = lines.findIndex(l => l.includes("Trigger: 刷怪03"));
{
  const [s, e] = funcOf(i3 + 6);
  console.log("\n=== 刷怪03 head (lines " + s + "-" + e + ", " + (e - s) + " lines) ===");
  console.log(lines.slice(s, s + 55).map(l => l.trim().slice(0, 150)).join("\n"));
}
