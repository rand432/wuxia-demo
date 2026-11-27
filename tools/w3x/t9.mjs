
import { MPQ } from "./mpq.mjs";
const p = "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(4)LostTemple.w3x";
const m = new MPQ(p);
const b = m.readFile("war3map.w3i");
console.log("len", b.length, "version", b.readInt32LE(0), "saveCount", b.readInt32LE(4), "editor", b.readInt32LE(8));
console.log(b.subarray(0, 120).toString("hex").replace(/(.{64})/g, "$1\n"));
console.log("latin1:", b.subarray(0, 120).toString("latin1").replace(/[^\x20-\x7e]/g, "."));
// heuristic: find first plausible length-prefixed utf8 string
for (let p2 = 8; p2 < 48; p2 += 4) {
  const len = b.readInt32LE(p2);
  if (len > 0 && len < 200 && p2 + 4 + len <= b.length) {
    const s = b.subarray(p2 + 4, p2 + 4 + len);
    if (!s.includes(0)) console.log("candidate at", p2, "len", len, "->", JSON.stringify(s.toString("utf8")));
  }
}
m.close();
