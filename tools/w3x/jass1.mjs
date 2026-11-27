
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const jass = fs.readFileSync(base + "war3map.decoded.j", "utf8");
const lines = jass.split("\n");

// 1. global names containing CJK
const globals = lines.filter(l => /^(constant\s+)?(integer|real|string|boolean|unit|group|timer|trigger|location|region|dialog|button|quest|force|player|hashtable|item|destructable|effect)\b/i.test(l) && /[\u4e00-\u9fff]/.test(l));
console.log("globals with CJK:", globals.length);
console.log(globals.slice(0, 25).join("\n").slice(0, 1500));

// 2. grep wave / difficulty related lines
const pats = [/波/, /进攻/, /难度/, /怪物属性/, /刷怪/, /金币/, /经验/];
for (const p of pats) {
  const hits = lines.map((l, i) => [i, l]).filter(([, l]) => p.test(l)).slice(0, 8);
  console.log("\n== " + p + " (" + lines.filter(l => p.test(l)).length + " lines) ==");
  for (const [i, l] of hits) console.log(i + ": " + l.trim().slice(0, 160));
}
