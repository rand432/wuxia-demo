
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const outDir = "D:\\1\\wuxia-demo\\docs\\重生魔兽刷刷刷\\";
const slk = JSON.parse(fs.readFileSync(base + "slk.json", "utf8"));
const abilIni = JSON.parse(fs.readFileSync(base + "parsed-abil.json", "utf8"));
const itemIni = JSON.parse(fs.readFileSync(base + "parsed-item.json", "utf8"));
const upgIni = JSON.parse(fs.readFileSync(base + "parsed-upg.json", "utf8"));

const clean = (s) => (s || "").replace(/\|c[0-9a-fA-F]{8}/g, "").replace(/\|r/g, "").replace(/\|c[0-9a-fA-F]{2}/g, "").trim();
const q = (v) => { const s = String(v ?? ""); return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
const csv = (rows) => "\uFEFF" + rows.map(r => r.map(q).join(",")).join("\r\n");
const num = (v) => { const n = parseFloat(v); return Number.isFinite(n) ? n : null; };

// ---- abilities ----
const abilRows = [["ID","名称","分类","基础技能代码","等级数","冷却1-4","耗蓝1-4","射程1-4","范围1-4","持续1-4","DataA","DataB","DataC","DataD","DataE","DataF","DataG","DataH","目标类型","需求等级","跳级","召唤单位","效果ID"]];
for (const r of slk.ability) {
  const ini = abilIni[r._id] || {};
  const name = clean(ini.Name);
  const cat = (name.match(/^【([^】]{1,12})】/) || [])[1] || "原生/无前缀";
  abilRows.push([
    r._id, clean(name) || "", cat, r.code || "", r.levels || "",
    [r.Cool1, r.Cool2, r.Cool3, r.Cool4].filter(x => x !== "").join("/"),
    [r.Cost1, r.Cost2, r.Cost3, r.Cost4].filter(x => x !== "").join("/"),
    [r.Rng1, r.Rng2, r.Rng3, r.Rng4].filter(x => x !== "").join("/"),
    [r.Area1, r.Area2, r.Area3, r.Area4].filter(x => x !== "").join("/"),
    [r.Dur1, r.Dur2, r.Dur3, r.Dur4].filter(x => x !== "").join("/"),
    [r.DataA1, r.DataA2, r.DataA3, r.DataA4].filter(x => x !== "").join("/"),
    [r.DataB1, r.DataB2, r.DataB3, r.DataB4].filter(x => x !== "").join("/"),
    [r.DataC1, r.DataC2, r.DataC3, r.DataC4].filter(x => x !== "").join("/"),
    [r.DataD1, r.DataD2, r.DataD3, r.DataD4].filter(x => x !== "").join("/"),
    [r.DataE1, r.DataE2, r.DataE3, r.DataE4].filter(x => x !== "").join("/"),
    [r.DataF1, r.DataF2, r.DataF3, r.DataF4].filter(x => x !== "").join("/"),
    [r.DataG1, r.DataG2, r.DataG3, r.DataG4].filter(x => x !== "").join("/"),
    [r.DataH1, r.DataH2, r.DataH3, r.DataH4].filter(x => x !== "").join("/"),
    r.targs1 || "", r.reqLevel || "", r.levelSkip || "", r.UnitID1 || "", r.EfctID1 || "",
  ]);
}
fs.writeFileSync(outDir + "数值层_技能表.csv", csv(abilRows), "utf8");

// ---- items ----
const itemRows = [["ID","名称","品质","类别class","等级Level","金币","木材","生命HP","护甲armor","技能abilList","使用次数uses","库存上限","冷却ID"]];
for (const r of slk.item) {
  const ini = itemIni[r._id] || {};
  const name = clean(ini.Name);
  const qual = (name.match(/^【([^】]{1,4})】/) || [])[1] || "";
  itemRows.push([r._id, name, qual, r.class || "", r.Level || "", r.goldcost || "", r.lumbercost || "", r.HP || "", r.armor || "", r.abilList || "", r.uses || "", r.stockMax || "", r.cooldownID || ""]);
}
fs.writeFileSync(outDir + "数值层_物品表.csv", csv(itemRows), "utf8");

// ---- units ----
const byId = new Map();
for (const r of slk.unitBalance) byId.set(r._id, { ...r });
for (const r of slk.unitData) byId.set(r._id, { ...(byId.get(r._id) || {}), ...r });
for (const r of slk.unitWeapons) byId.set(r._id, { ...(byId.get(r._id) || {}), ...r });
for (const r of slk.unitUI) byId.set(r._id, { ...(byId.get(r._id) || {}), ...r });
const unitRows = [["ID","名称","等级","生命HP","魔法mana0","护甲def","护甲类型","移动spd","力量STR","敏捷AGI","智力INT","成长(STR/AGI/INT)","回血regenHP","回蓝regenMana","攻击力(基础+骰)","骰子(数x面)","攻击加成dmgplus","攻击间隔cool","攻击距离rangeN","攻击类型","护甲类型defType","目标类型targType","金币goldcost","木材lumbercost","是否建筑"]];
for (const [id, u] of byId) {
  if (!u.name && !u.code) continue;
  unitRows.push([id, clean(u.name || ""), u.level || "", u.HP || "", u.mana0 || "", u.def || "", u.armor || "", u.spd || "", u.STR || "", u.AGI || "", u.INT || "", [u.STRplus, u.AGIplus, u.INTplus].join("/"), u.regenHP || "", u.regenMana || "", u.dmgplus1 || "", [u.dice1, u.sides1].join("x"), u.dmgplus1 || "", u.cool1 || "", u.rangeN1 || "", u.atkType1 || "", u.defType || "", u.targType || "", u.goldcost || "", u.lumbercost || "", u.isbldg || ""]);
}
fs.writeFileSync(outDir + "数值层_单位表.csv", csv(unitRows), "utf8");

// ---- upgrades ----
const upgRows = [["ID","名称","类别","最高等级","基准效果base1-4","每级增量mod1-4","生效目标effect1-4","金币基数","金币增量","木材基数","木材增量","时间基数","时间增量"]];
for (const r of slk.upgrade) {
  const ini = upgIni[r._id] || {};
  upgRows.push([r._id, clean(ini.Name || ""), r.class || "", r.maxlevel || "", [r.base1, r.base2, r.base3, r.base4].join("/"), [r.mod1, r.mod2, r.mod3, r.mod4].join("/"), [r.effect1, r.effect2, r.effect3, r.effect4].join("/"), r.goldbase || "", r.goldmod || "", r.lumberbase || "", r.lumbermod || "", r.timebase || "", r.timemod || ""]);
}
fs.writeFileSync(outDir + "数值层_科技表.csv", csv(upgRows), "utf8");

console.log("abilities", abilRows.length - 1, "items", itemRows.length - 1, "units", unitRows.length - 1, "upgrades", upgRows.length - 1);

// ---- stats for the report ----
const lv = {};
for (const r of slk.ability) { const k = r.levels || "?"; lv[k] = (lv[k] || 0) + 1; }
console.log("levels dist:", JSON.stringify(Object.entries(lv).sort((a, b) => Number(b[0]) - Number(a[0])).slice(0, 12)));
const codes = {};
for (const r of slk.ability) { codes[r.code || "?"] = (codes[r.code || "?"] || 0) + 1; }
console.log("top base codes:", JSON.stringify(Object.entries(codes).sort((a, b) => b[1] - a[1]).slice(0, 20)));
const costs = slk.ability.map(r => num(r.Cost1)).filter(x => x != null && x > 0);
const cools = slk.ability.map(r => num(r.Cool1)).filter(x => x != null && x > 0);
const avg = (a) => a.length ? (a.reduce((s, x) => s + x, 0) / a.length) : 0;
console.log("cost1 n", costs.length, "avg", avg(costs).toFixed(1), "max", Math.max(...costs));
console.log("cool1 n", cools.length, "avg", avg(cools).toFixed(2), "max", Math.max(...cools));
const gold = slk.item.map(r => num(r.goldcost)).filter(x => x != null && x > 0);
console.log("item gold n", gold.length, "avg", avg(gold).toFixed(0), "max", Math.max(...gold));
