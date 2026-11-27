
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const jass = fs.readFileSync(base + "war3map.decoded.j", "utf8");
const lines = jass.split("\n");

// 1. trigger names
const trig = [...jass.matchAll(/\/\/\s*Trigger:\s*(.+)/g)].map(m => m[1].trim());
console.log("trigger declarations:", trig.length, "| unique:", new Set(trig).size);
const pref = {};
for (const t of trig) { const k = t.replace(/[0-9]+$/g, "").slice(0, 14); pref[k] = (pref[k] || 0) + 1; }
console.log("top trigger families:", JSON.stringify(Object.entries(pref).sort((a, b) => b[1] - a[1]).slice(0, 30), null, 0));
console.log("sample trigger names:", JSON.stringify(trig.slice(0, 40)));

// 2. affix pools via YDWESaveStringByString
const saves = [...jass.matchAll(/YDWESaveStringByString\(\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"\s*\)/g)];
console.log("\nYDWESaveStringByString calls:", saves.length);
const pools = {};
for (const m of saves) { const key = m[1]; (pools[key] = pools[key] || []).push({ idx: m[2], text: m[3] }); }
const keys = Object.keys(pools);
console.log("pool keys:", keys.length);
console.log(keys.slice(0, 40).join(" | "));
for (const k of keys.slice(0, 4)) console.log("\n[" + k + "] " + pools[k].length + " 条:", JSON.stringify(pools[k].slice(0, 4)));
fs.writeFileSync(base + "affix-pools.json", JSON.stringify(pools, null, 1), "utf8");
fs.writeFileSync(base + "triggers.txt", [...new Set(trig)].sort().join("\n"), "utf8");
