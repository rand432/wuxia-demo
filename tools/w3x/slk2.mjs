
import fs from "node:fs";
const dir = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\blocks\\";
function headers(f) {
  const text = fs.readFileSync(dir + f, "utf8");
  const firstRow = text.slice(0, text.indexOf("Y2;") > 0 ? text.indexOf("Y2;") : 4000);
  return [...firstRow.matchAll(/K"([^"]*)"/g)].map(m => m[1]);
}
for (const [label, f] of [["AbilityData", "blk_925.slk_txt.bin"], ["UnitBalance", "blk_1080.slk_txt.bin"], ["ItemData", "blk_1204.slk_txt.bin"], ["UnitWeapons", "blk_2372.slk_txt.bin"], ["UnitData", "blk_2082.slk_txt.bin"], ["UpgradeData", "blk_3144.slk_txt.bin"]]) {
  const h = headers(f);
  console.log("== " + label + " (" + h.length + " cols) ==");
  console.log(JSON.stringify(h));
}
