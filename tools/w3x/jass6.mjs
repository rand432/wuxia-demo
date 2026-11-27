
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const lines = fs.readFileSync(base + "war3map.decoded.j", "utf8").split("\n");
const trigAt = new Array(lines.length).fill("");
let cur = "";
for (let i = 0; i < lines.length; i++) { const m = lines[i].match(/\/\/\s*Trigger:\s*(.+)/); if (m) cur = m[1].trim(); trigAt[i] = cur; }

// where difficulty keys are written
for (const key of ["0x2B73A0ED", "0xA4C11C16", "0x0461A507"]) {
  const idxs = lines.map((l, i) => [i, l]).filter(([, l]) => l.includes("SaveReal(YDHT, 1, " + key));
  console.log("\n== " + key + " written at " + idxs.length + " places ==");
  for (const [i, l] of idxs.slice(0, 6)) console.log("  line " + i + " [" + trigAt[i] + "] " + l.trim().slice(0, 180));
}
// difficulty selection strings
const dstr = lines.map((l, i) => [i, l]).filter(([, l]) => /难度/.test(l) && /Save(Str|Integer|Real)/.test(l)).slice(0, 12);
console.log("\n== difficulty save lines ==");
for (const [i, l] of dstr) console.log("  " + i + " [" + trigAt[i] + "] " + l.trim().slice(0, 170));

// 刷怪04 main actions head
const i4 = lines.findIndex(l => l.includes("// Trigger: 刷怪04"));
let s = i4; while (s < lines.length && !/^function Trig_______04Actions/.test(lines[s])) s++;
console.log("\n== 刷怪04 Actions head ==");
console.log(lines.slice(s, s + 60).map(l => l.trim().slice(0, 170)).join("\n"));
