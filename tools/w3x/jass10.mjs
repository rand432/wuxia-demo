
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const lines = fs.readFileSync(base + "war3map.decoded.j", "utf8").split("\n");
function funcRange(name) {
  const i = lines.findIndex(l => l.includes("// Trigger: " + name));
  let s = i; while (s > 0 && !/^function\s/.test(lines[s])) s--;
  let e = s; while (e < lines.length && !/^endfunction/.test(lines[e])) e++;
  return [s, e];
}
for (const name of ["刷怪01", "刷怪02", "刷怪03", "刷怪05"]) {
  const [s, e] = funcRange(name);
  console.log("\n===== " + name + " lines " + s + "-" + e + " (" + (e - s) + ") =====");
  for (let i = s; i < e; i++) {
    const l = lines[i];
    if (/udg_Time|CreateUnit|TriggerExecute|SaveInteger\(YDHT|set ydul_k|exitwhen|loop|GetRandomInt|for |set udg_/.test(l)) {
      console.log("  " + i + ": " + l.replace(/\t/g, " ").trim().slice(0, 165));
    }
  }
}
