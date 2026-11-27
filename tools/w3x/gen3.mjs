
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const outDir = "D:\\1\\wuxia-demo\\docs\\重生魔兽刷刷刷\\";
const slk = JSON.parse(fs.readFileSync(base + "slk.json", "utf8"));
const itemIni = JSON.parse(fs.readFileSync(base + "parsed-item.json", "utf8"));
const abilIni = JSON.parse(fs.readFileSync(base + "parsed-abil.json", "utf8"));
const pools = JSON.parse(fs.readFileSync(base + "affix-pools.json", "utf8"));
const clean = (s) => (s || "").replace(/\|c[0-9a-fA-F]{8}/g, "").replace(/\|r/g, "").replace(/\|c[0-9a-fA-F]{2}/g, "").trim();
const q = (v) => { const s = String(v ?? ""); return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
const csv = (rows) => "\uFEFF" + rows.map(r => r.map(q).join(",")).join("\r\n");

// --- wave table csv
const byId = new Map();
for (const r of slk.unitBalance) byId.set(r._id, { ...r });
for (const r of slk.unitData) byId.set(r._id, { ...(byId.get(r._id) || {}), ...r });
for (const r of slk.unitWeapons) byId.set(r._id, { ...(byId.get(r._id) || {}), ...r });
for (const r of slk.unitUI) byId.set(r._id, { ...(byId.get(r._id) || {}), ...r });
const waveTypes = ["h006","h000","e001","n000","n001","n002","n003","n004","n005","n006","n007","n008","e002","n009","n00A","u002","n00D"];
const waveRows = [["波次","出现时间(秒)","兵种ID","基础生命","护甲","攻击加成","攻击间隔","射程","赏金(基础+骰)","金币"]];
for (let i = 0; i < waveTypes.length; i++) {
  const u = byId.get(waveTypes[i]) || {};
  waveRows.push([i + 1, (i + 1) * 120, waveTypes[i], u.HP || "", u.def || "", u.dmgplus1 || "", u.cool1 || "", u.rangeN1 || "", [u.bountyplus, u.bountydice, u.bountysides].filter(Boolean).join("+"), u.goldcost || ""]);
}
fs.writeFileSync(outDir + "节奏层_波次表.csv", csv(waveRows), "utf8");

// --- difficulty csv
const diff = [
  ["难1", 1.00, 1.00, 1.00], ["难2", 1.30, 1.50, 1.30], ["难3", 1.82, 2.40, 1.50], ["难4", 2.73, 4.08, 1.70],
  ["难5", 4.09, 7.30, 2.00], ["难6", 7.42, 14.68, 2.50], ["难7", 13.36, 32.31, 3.20], ["难8", 30, 90, 6.5],
  ["难9", 60, 260, 15], ["难10", 150, 600, 25], ["难11", 480, 1800, 50], ["难12", 1200, 5400, 100],
];
const diffRows = [["难度","攻击系数","生命系数","第三状态系数(0x20)","相对难1攻击","相对难1生命"]];
for (const d of diff) diffRows.push([d[0], d[1], d[2], d[3], (d[1] / 1).toFixed(2) + "x", (d[2] / 1).toFixed(0) + "x"]);
fs.writeFileSync(outDir + "节奏层_难度系数.csv", csv(diffRows), "utf8");

// --- affix csv
const affixRows = [["分组","序号","词条/名称"]];
for (const [k, arr] of Object.entries(pools)) for (const it of arr) affixRows.push([k, it.idx, it.text]);
fs.writeFileSync(outDir + "数值层_词条池.csv", csv(affixRows), "utf8");

// --- stats for md
const lvDist = {};
for (const r of slk.ability) { const k = r.levels || "?"; lvDist[k] = (lvDist[k] || 0) + 1; }
const codes = {};
for (const r of slk.ability) codes[r.code || "?"] = (codes[r.code || "?"] || 0) + 1;
const topCodes = Object.entries(codes).sort((a, b) => b[1] - a[1]).slice(0, 12);
const cds = slk.ability.map(r => parseFloat(r.Cool1)).filter(x => x > 0);
const costs = slk.ability.map(r => parseFloat(r.Cost1)).filter(x => x > 0);
const golds = slk.item.map(r => parseFloat(r.goldcost)).filter(x => x > 0);
const avg = (a) => a.length ? a.reduce((s, x) => s + x, 0) / a.length : 0;
console.log(JSON.stringify({ lvDist, topCodes, cdsN: cds.length, cdAvg: avg(cds).toFixed(1), costN: costs.length, costAvg: avg(costs).toFixed(1), goldN: golds.length, goldAvg: avg(golds).toFixed(0) }));
console.log("affix rows:", affixRows.length - 1, "| wave rows:", waveRows.length - 1);
