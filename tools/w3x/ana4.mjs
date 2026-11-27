
import fs from "node:fs";
import path from "node:path";
const dir = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\blocks";
function parseIni(text) {
  const out = {};
  let cur = null;
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*\[([^\]]+)\]\s*$/);
    if (m) { cur = m[1]; out[cur] = out[cur] || {}; continue; }
    if (!cur) continue;
    const eq = line.indexOf("=");
    if (eq < 0) continue;
    const k = line.slice(0, eq).trim();
    const v = line.slice(eq + 1);
    out[cur][k] = v;
  }
  return out;
}
const abil = parseIni(fs.readFileSync(path.join(dir, "blk_1626.slk_txt.bin"), "utf8"));
const item = parseIni(fs.readFileSync(path.join(dir, "blk_2454.slk_txt.bin"), "utf8"));
const upg = parseIni(fs.readFileSync(path.join(dir, "blk_1358.slk_txt.bin"), "utf8"));
const buff = parseIni(fs.readFileSync(path.join(dir, "blk_2810.slk_txt.bin"), "utf8"));
console.log("abilities", Object.keys(abil).length, "| items", Object.keys(item).length, "| upgrades", Object.keys(upg).length, "| buffs", Object.keys(buff).length);
const uniq = (arr) => [...new Set(arr)];
const abilNames = Object.values(abil).map(a => a.Name).filter(Boolean);
console.log("abilities with Name:", abilNames.length, "| unique:", uniq(abilNames).length);
const itemNames = Object.values(item).map(a => a.Name).filter(Boolean);
console.log("items with Name:", itemNames.length, "| unique:", uniq(itemNames).length);
// quality prefixes in item names
const prefixes = {};
for (const n of itemNames) { const m = n.match(/^【([^】]+)】/); const k = m ? m[1] : "(none)"; prefixes[k] = (prefixes[k] || 0) + 1; }
console.log("item prefixes:", JSON.stringify(Object.entries(prefixes).sort((a,b)=>b[1]-a[1]).slice(0,20)));
const abilPrefixes = {};
for (const n of abilNames) { const m = n.match(/^【([^】]+)】/); const k = m ? m[1] : "(none)"; abilPrefixes[k] = (abilPrefixes[k] || 0) + 1; }
console.log("ability prefixes:", JSON.stringify(Object.entries(abilPrefixes).sort((a,b)=>b[1]-a[1]).slice(0,25)));
console.log("sample abilities:");
for (const [id, a] of Object.entries(abil).slice(0, 6)) console.log(id, "|", a.Name, "|", (a.Tip || "").slice(0, 40), "|", (a.Ubertip || "").replace(/\|n/g, " / ").slice(0, 80));
console.log("sample items:");
for (const [id, a] of Object.entries(item).slice(0, 8)) console.log(id, "|", a.Name, "|", (a.Tip || "").slice(0, 30), "|", (a.Ubertip || "").replace(/\|n/g, " / ").slice(0, 80));
fs.writeFileSync("D:\\1\\wuxia-demo\\w3x-out\\shuashua\\parsed-abil.json", JSON.stringify(abil, null, 1), "utf8");
fs.writeFileSync("D:\\1\\wuxia-demo\\w3x-out\\shuashua\\parsed-item.json", JSON.stringify(item, null, 1), "utf8");
fs.writeFileSync("D:\\1\\wuxia-demo\\w3x-out\\shuashua\\parsed-upg.json", JSON.stringify(upg, null, 1), "utf8");
fs.writeFileSync("D:\\1\\wuxia-demo\\w3x-out\\shuashua\\parsed-buff.json", JSON.stringify(buff, null, 1), "utf8");
