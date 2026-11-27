
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const lines = fs.readFileSync(base + "war3map.decoded.j", "utf8").split("\n");
// 1. boss trigger var occurrences
const occ = lines.map((l, i) => [i, l]).filter(([, l]) => /_______04\b/.test(l) || /gg_trg_______04/.test(l));
console.log("occurrences of __04:", occ.length);
for (const [i, l] of occ.slice(0, 20)) console.log("  " + i + ": " + l.trim().slice(0, 140));
// 2. 设置进攻怪属性 arithmetic
console.log("\n=== 设置进攻怪属性01 body (18260-18340) ===");
console.log(lines.slice(18260, 18340).map((l, k) => (18260 + k) + ": " + l.trim().slice(0, 170)).join("\n"));
