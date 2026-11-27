
import { MPQ, parseW3i, parseWts, resolveTrigStrings } from "./mpq.mjs";
const files = [
  "D:\\1\\魔兽争霸3冰封王座\\Maps\\dz\\rpg\\ABF7FC0B0A80C407DD1DCC67F0E21139.w3x",
  "D:\\1\\魔兽争霸3冰封王座\\Maps\\dz\\rpg\\D862BFB35C5CED1620EEF6EC17028EE7.w3x",
];
for (const p of files) {
  try {
    const m = new MPQ(p);
    const info = parseW3i(m.readFile("war3map.w3i"));
    const wtsBuf = m.readFile("war3map.wts");
    const wts = wtsBuf ? parseWts(wtsBuf) : new Map();
    console.log(p.split("\\").pop(), "| size", m.size, "| block", m.blockTableSize, "| name:", info && resolveTrigStrings(info.name, wts), "| author:", info && resolveTrigStrings(info.author, wts), "| wts", wts.size);
    if (info) console.log("   desc:", JSON.stringify(resolveTrigStrings(info.description, wts).slice(0, 200)));
    m.close();
  } catch (e) { console.log(p, "ERR", e.message); }
}
