
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const lines = fs.readFileSync(base + "war3map.decoded.j", "utf8").split("\n");
for (const [a, b] of [[19155, 19200], [20140, 20200]]) {
  console.log("\n=== lines " + a + "-" + b + " ===");
  for (let i = a; i < b; i++) {
    const l = lines[i].trim();
    if (/udg_Time|if \(|TriggerExecute|SaveBoolean\(YDHT|call DisplayText|function /.test(l)) console.log("  " + i + ": " + l.slice(0, 160));
  }
}
// affix pools dump
const pools = JSON.parse(fs.readFileSync(base + "affix-pools.json", "utf8"));
const order = ["装备部位","绿色词条","绿色名称","蓝色词条","蓝色名称","紫色名称","黄色名称","红色名称","粉色名称"];
console.log("\n=== pools overview ===");
for (const k of Object.keys(pools)) console.log(k + " : " + pools[k].length + " -> " + pools[k].map(x => x.text).join(" / ").slice(0, 220));
