
import { MPQ, hashString, decryptBlock } from "./mpq.mjs";
const p = "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(4)LostTemple.w3x";
const m = new MPQ(p);
console.log("hashOffset idx:", hashString("war3map.w3i", 0) % m.hashTableSize);
const bi = m.find("war3map.w3i");
console.log("block index:", bi);
if (bi >= 0) {
  const be = m.blockTable[bi];
  console.log("block:", JSON.stringify(be));
  const raw = m.readAt(m.base + be.filePos, be.cSize);
  console.log("raw head:", raw.subarray(0, 8).toString("hex"));
  const zlib = await import("node:zlib");
  try { const d = zlib.inflateSync(raw.subarray(1)); console.log("inflated:", d.length, d.subarray(0, 40).toString("hex")); } catch (e) { console.log("inflate err", e.message); }
  const b = m.readFile("war3map.w3i");
  console.log("readFile ->", b && b.length);
}
m.close();
