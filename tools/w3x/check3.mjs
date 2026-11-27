
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const item = JSON.parse(fs.readFileSync(base + "parsed-item.json", "utf8"));
const abil = JSON.parse(fs.readFileSync(base + "parsed-abil.json", "utf8"));
const clean = (s) => (s || "").replace(/\|c[0-9a-fA-F]{8}/g, "").replace(/\|r/g, "").replace(/\|c[0-9a-fA-F]{2}/g, "").trim();
const q = {};
for (const it of Object.values(item)) { const m = clean(it.Name).match(/^【([^】]{1,4})】/); const k = m ? m[1] : "(无)"; q[k] = (q[k] || 0) + 1; }
console.log("item quality (cleaned):", JSON.stringify(Object.entries(q).sort((a,b)=>b[1]-a[1])));
const ac = {};
for (const a of Object.values(abil)) { const m = clean(a.Name).match(/^【([^】]{1,10})】/); (ac[m ? m[1] : "(原生)"] = (ac[m ? m[1] : "(原生)"] || 0) + 1); }
console.log("ability categories count:", Object.keys(ac).length);
console.log("ability top:", JSON.stringify(Object.entries(ac).sort((a,b)=>b[1]-a[1]).slice(0, 12)));
