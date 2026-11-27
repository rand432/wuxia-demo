
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const slk = JSON.parse(fs.readFileSync(base + "slk.json", "utf8"));
const byId = new Map();
for (const r of slk.unitBalance) byId.set(r._id, { ...r });
for (const r of slk.unitData) byId.set(r._id, { ...(byId.get(r._id) || {}), ...r });
for (const r of slk.unitWeapons) byId.set(r._id, { ...(byId.get(r._id) || {}), ...r });
for (const r of slk.unitUI) byId.set(r._id, { ...(byId.get(r._id) || {}), ...r });

const waveTypes = ["h006","h000","e001","n000","n001","n002","n003","n004","n005","n006","n007","n008","e002","n009","n00A","u002","n00D"];
const rows = [];
for (let i = 0; i < waveTypes.length; i++) {
  const id = waveTypes[i];
  const u = byId.get(id) || {};
  rows.push({ wave: i + 1, t: (i + 1) * 120, id, hp: u.HP, lvl: u.level, def: u.def, bounty: [u.bountyplus, u.bountydice, u.bountysides].filter(Boolean).join("+"), gold: u.goldcost, dmgDice: [u.dice1, u.sides1, u.dmgplus1].join("/"), cool: u.cool1, range: u.rangeN1, atkType: u.atkType1 });
}
console.log(JSON.stringify(rows, null, 1));
// boss units
for (const b of ["h008","h00I","h00K","h00V","h00U","u004","n00W"]) {
  const u = byId.get(b) || {};
  console.log("BOSS", b, "| hp", u.HP, "| def", u.def, "| level", u.level, "| bounty", [u.bountyplus, u.bountydice, u.bountysides].join("+"), "| gold", u.goldcost);
}
