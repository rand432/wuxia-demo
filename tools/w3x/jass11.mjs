
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const lines = fs.readFileSync(base + "war3map.decoded.j", "utf8").split("\n");
function bodyAfter(name) {
  const i = lines.findIndex(l => l.includes("// Trigger: " + name));
  if (i < 0) return null;
  let s = i; while (s < lines.length && !/^function\s/.test(lines[s])) s++;
  let e = s; while (e < lines.length && !/^endfunction/.test(lines[e])) e++;
  return [s, e];
}
for (const name of ["刷怪01", "刷怪02", "刷怪03"]) {
  const r = bodyAfter(name);
  if (!r) { console.log("miss", name); continue; }
  const [s, e] = r;
  console.log("\n===== " + name + " lines " + s + "-" + e + " (" + (e - s) + ") =====");
  let shown = 0;
  for (let i = s; i < e && shown < 45; i++) {
    const l = lines[i];
    if (/udg_Time|CreateUnit|TriggerExecute|SaveInteger\(YDHT, 1|set udg_|GetRandomInt|for |loop|exitwhen/.test(l)) {
      console.log("  " + i + ": " + l.replace(/\t/g, " ").trim().slice(0, 160));
      shown++;
    }
  }
}
