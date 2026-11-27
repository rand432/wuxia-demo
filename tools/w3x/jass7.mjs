
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const lines = fs.readFileSync(base + "war3map.decoded.j", "utf8").split("\n");
console.log("=== 难度选择2 region 17700-17880 (comments + key writes) ===");
for (let i = 17700; i < 17880; i++) {
  const l = lines[i];
  if (/^\s*\/\//.test(l) || /SaveReal\(YDHT, 1, 0x(2B73A0ED|A4C11C16|0461A507)/.test(l) || /if \(/.test(l) && /LoadReal|LoadInteger/.test(l)) console.log(i + ": " + l.trim().slice(0, 150));
}
// all 14 writes in order with key
const w = [];
lines.forEach((l, i) => { const m = l.match(/SaveReal\(YDHT, 1, 0x(2B73A0ED|A4C11C16|0461A507), ([\d.]+)\)/); if (m) w.push({ key: m[1], v: parseFloat(m[2]), line: i }); });
console.log("\nordered writes:", JSON.stringify(w));
// find execute sites of 刷怪04 trigger var
const v4 = lines.find(l => /gg_trg_[A-Za-z0-9_]+=CreateTrigger\(\)/.test(l) && false);
const idx4 = lines.findIndex(l => l.includes("// Trigger: 刷怪04"));
// the trigger var for 刷怪04 is defined in its InitTrig just before
let initStart = idx4; while (initStart > 0 && !/^function InitTrig/.test(lines[initStart])) initStart--;
const varName = (lines[initStart + 1] || "").match(/set (gg_trg_[A-Za-z0-9_]+)=/);
console.log("init func:", lines[initStart], "| var:", varName && varName[1]);
if (varName) {
  const sites = lines.map((l, i) => [i, l]).filter(([, l]) => l.includes("TriggerExecute(" + varName[1] + ")"));
  console.log("execute sites:", sites.length);
  for (const [i, l] of sites) {
    // find nearest preceding time condition
    let ctx = "";
    for (let k = i; k > i - 120 && k > 0; k--) { if (/udg_Time/.test(lines[k])) { ctx = lines[k].trim().slice(0, 120); break; } }
    console.log("  line " + i + " | near-time: " + ctx);
  }
}
