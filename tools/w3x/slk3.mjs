
import fs from "node:fs";
const dir = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\blocks\\";

export function parseSlk(text) {
  const grid = new Map(); // row -> Map(col -> value)
  let i = 0;
  const n = text.length;
  let curCol = 1, curRow = 1;
  // tokenise records: a record starts with a capital letter followed by ';'
  while (i < n) {
    // skip whitespace/newlines
    while (i < n && /\s/.test(text[i])) i++;
    if (i >= n) break;
    const start = i;
    // find end of record: newline or space followed by CAPITAL ';'
    let j = i + 1;
    while (j < n) {
      if (text[j] === '"') { j++; while (j < n && text[j] !== '"') { if (text[j] === '\\') j++; j++; } j++; continue; }
      if (text[j] === "\n" || text[j] === "\r") break;
      j++;
    }
    const rec = text.slice(start, j);
    i = j;
    const tokens = rec.split(";");
    const kind = tokens[0];
    if (kind !== "C") continue;
    let val = "";
    for (let k = 1; k < tokens.length; k++) {
      const tk = tokens[k];
      if (tk.startsWith("X")) curCol = parseInt(tk.slice(1), 10);
      else if (tk.startsWith("Y")) curRow = parseInt(tk.slice(1), 10);
      else if (tk.startsWith("K")) {
        let v = tk.slice(1);
        if (v.startsWith('"')) v = v.slice(1);
        if (v.endsWith('"')) v = v.slice(0, -1);
        val = v;
      }
    }
    if (!grid.has(curRow)) grid.set(curRow, new Map());
    grid.get(curRow).set(curCol, val);
  }
  return grid;
}

export function slkTable(text) {
  const grid = parseSlk(text);
  const headerRow = grid.get(1);
  if (!headerRow) return { header: [], rows: [] };
  const maxCol = Math.max(...[...grid.keys()].length ? [...grid.values()].map(m => Math.max(...m.keys())) : [1]);
  const header = [];
  for (let c = 1; c <= maxCol; c++) header.push(headerRow.get(c) || ("col" + c));
  const rows = [];
  for (const [r, cells] of [...grid.entries()].sort((a, b) => a[0] - b[0])) {
    if (r === 1) continue;
    const obj = { _id: cells.get(1) || "" };
    for (let c = 2; c <= maxCol; c++) obj[header[c - 1]] = cells.get(c) ?? "";
    if (obj._id) rows.push(obj);
  }
  return { header, rows };
}

const files = {
  ability: "blk_925.slk_txt.bin",
  unitBalance: "blk_1080.slk_txt.bin",
  unitData: "blk_2082.slk_txt.bin",
  unitWeapons: "blk_2372.slk_txt.bin",
  unitUI: "blk_122.slk_txt.bin",
  item: "blk_1204.slk_txt.bin",
  upgrade: "blk_3144.slk_txt.bin",
};
const out = {};
for (const [k, f] of Object.entries(files)) {
  const { header, rows } = slkTable(fs.readFileSync(dir + f, "utf8"));
  out[k] = rows;
  console.log(k, "rows", rows.length, "cols", header.length);
}
fs.writeFileSync("D:\\1\\wuxia-demo\\w3x-out\\shuashua\\slk.json", JSON.stringify(out), "utf8");
// sanity: ability A000
const a = out.ability.find(r => r._id === "A000");
console.log("A000:", JSON.stringify({ code: a.code, levels: a.levels, cool: [a.Cool1, a.Cool2, a.Cool3, a.Cool4], cost: [a.Cost1, a.Cost2], rng: [a.Rng1, a.Rng2], area: [a.Area1, a.Area2], dataA: [a.DataA1, a.DataA2], targ: a.targs1 }, null, 1));
const it = out.item.find(r => r._id === "I000");
console.log("I000:", JSON.stringify({ class: it.class, Level: it.Level, gold: it.goldcost, hp: it.HP, armor: it.armor, abil: it.abilList }).slice(0, 300));
