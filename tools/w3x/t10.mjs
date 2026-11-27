
import { MPQ, parseW3i, parseWts, resolveTrigStrings, decodeText } from "./mpq.mjs";
const p = "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(4)LostTemple.w3x";
const m = new MPQ(p);
const info = parseW3i(m.readFile("war3map.w3i"));
const wtsBuf = m.readFile("war3map.wts");
const wts = wtsBuf ? parseWts(wtsBuf) : new Map();
console.log("info:", JSON.stringify(info));
console.log("wts entries:", wts.size, "sample:", [...wts.entries()].slice(0,3));
console.log("resolved name:", resolveTrigStrings(info.name, wts));
m.close();
