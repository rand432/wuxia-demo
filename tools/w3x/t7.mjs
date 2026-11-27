
import { MPQ, hashString } from "./mpq.mjs";
const p = "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(4)LostTemple.w3x";
const m = new MPQ(p);
const ht = m.hashTable;
const want = { a: hashString("war3map.w3i", 1), b: hashString("war3map.w3i", 2) };
console.log("want", want.a.toString(16), want.b.toString(16));
let shown = 0;
for (const [i, e] of ht.entries()) {
  if (e.block !== 0xFFFFFFFF) {
    if (shown < 20) console.log(i, "hashA", e.hashA.toString(16), "hashB", e.hashB.toString(16), "block", e.block, "locale", e.locale);
    shown++;
  }
}
console.log("valid entries:", shown);
console.log("match by A only:", ht.filter(e => e.hashA === want.a).length);
// try reverse: which block indexes exist
const bt = m.blockTable;
console.log("blocks:", bt.map(b => ({ p: b.filePos, c: b.cSize, f: b.fSize, fl: (b.flags>>>0).toString(16) })));
m.close();
