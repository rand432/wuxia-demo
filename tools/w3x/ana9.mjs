
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const slk = JSON.parse(fs.readFileSync(base + "slk.json", "utf8"));
const abilIni = JSON.parse(fs.readFileSync(base + "parsed-abil.json", "utf8"));
const itemIni = JSON.parse(fs.readFileSync(base + "parsed-item.json", "utf8"));
const clean = (s) => (s || "").replace(/\|c[0-9a-fA-F]{8}/g, "").replace(/\|r/g, "").replace(/\|c[0-9a-fA-F]{2}/g, "").trim();
const num = (v) => { const n = parseFloat(v); return Number.isFinite(n) ? n : null; };

// multi-level abilities sample
const multi = slk.ability.filter(r => num(r.levels) >= 3).slice(0, 12);
console.log("=== 多级技能样例 ===");
for (const r of multi) {
  const nm = clean((abilIni[r._id] || {}).Name);
  console.log(r._id, "|", nm, "| code", r.code, "| lv", r.levels, "| cool", [r.Cool1, r.Cool2, r.Cool3, r.Cool4].join("/"), "| cost", [r.Cost1, r.Cost2].join("/"), "| rng", [r.Rng1, r.Rng2].join("/"), "| area", [r.Area1, r.Area2].join("/"), "| DataA", [r.DataA1, r.DataA2, r.DataA3, r.DataA4].join("/"), "| DataB", [r.DataB1, r.DataB2].join("/"));
}
// cooldown buckets
const bucket = { "0-5s": 0, "5-15s": 0, "15-30s": 0, "30-60s": 0, "60s+": 0 };
for (const r of slk.ability) { const c = num(r.Cool1); if (c == null || c <= 0) continue; if (c <= 5) bucket["0-5s"]++; else if (c <= 15) bucket["5-15s"]++; else if (c <= 30) bucket["15-30s"]++; else if (c <= 60) bucket["30-60s"]++; else bucket["60s+"]++; }
console.log("cooldown buckets:", JSON.stringify(bucket));
const costBucket = { "0-50": 0, "50-100": 0, "100-200": 0, "200+": 0 };
for (const r of slk.ability) { const c = num(r.Cost1); if (c == null || c <= 0) continue; if (c <= 50) costBucket["0-50"]++; else if (c <= 100) costBucket["50-100"]++; else if (c <= 200) costBucket["100-200"]++; else costBucket["200+"]++; }
console.log("cost buckets:", JSON.stringify(costBucket));

// item price by quality
const byQ = {};
for (const r of slk.item) {
  const nm = clean((itemIni[r._id] || {}).Name);
  const qual = (nm.match(/^【([^】]{1,4})】/) || [])[1] || "(无)";
  const g = num(r.goldcost);
  (byQ[qual] = byQ[qual] || { n: 0, gold: [] }).n++;
  if (g) byQ[qual].gold.push(g);
}
const stats = Object.entries(byQ).map(([k, v]) => [k, v.n, v.gold.length ? Math.min(...v.gold) + "-" + Math.max(...v.gold) + " (avg " + (v.gold.reduce((a, b) => a + b, 0) / v.gold.length).toFixed(0) + ")" : "-"]);
console.log("item quality price:", JSON.stringify(stats));

// units: heroes & bosses
const byId = new Map();
for (const r of slk.unitBalance) byId.set(r._id, { ...r });
for (const r of slk.unitData) byId.set(r._id, { ...(byId.get(r._id) || {}), ...r });
for (const r of slk.unitWeapons) byId.set(r._id, { ...(byId.get(r._id) || {}), ...r });
for (const r of slk.unitUI) byId.set(r._id, { ...(byId.get(r._id) || {}), ...r });
const lvls = {};
for (const [id, u] of byId) { const l = num(u.level); if (l == null) continue; lvls[l] = (lvls[l] || 0) + 1; }
console.log("unit level dist:", JSON.stringify(Object.entries(lvls).sort((a, b) => Number(a[0]) - Number(b[0])).slice(0, 14)));
const big = [...byId.entries()].map(([id, u]) => ({ id, name: clean(u.name || ""), hp: num(u.HP) || 0, lvl: num(u.level) || 0, def: num(u.def) || 0, dmg: num(u.dice1) || 0 })).filter(x => x.hp > 0).sort((a, b) => b.hp - a.hp).slice(0, 12);
console.log("top HP units:", JSON.stringify(big));
