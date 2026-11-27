
import { MPQ } from "./mpq.mjs";
import zlib from "node:zlib";
const p = "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(4)LostTemple.w3x";
const m = new MPQ(p);
for (const [name, bi] of [["war3map.wts", 14], ["(listfile)", 15], ["(attributes)", 16]]) {
  const be = m.blockTable[bi];
  const raw = m.readAt(m.base + be.filePos, be.cSize);
  console.log(name, "cSize", be.cSize, "fSize", be.fSize, "flags 0x" + (be.flags >>> 0).toString(16));
  console.log("  raw:", raw.subarray(0, 32).toString("hex"));
  const s0 = raw.readUInt32LE(0), s1 = raw.readUInt32LE(4);
  console.log("  first2:", s0, s1);
  if (s1 <= raw.length) {
    const chunk = raw.subarray(s0, s1);
    console.log("  chunk[0]:", chunk[0].toString(16), "len", chunk.length);
    for (const fn of ["inflateSync", "inflateRawSync"]) {
      try { const d = zlib[fn](chunk.subarray(1)); console.log("  " + fn, "->", d.length, JSON.stringify(d.subarray(0, 20).toString("utf8"))); } catch (e) { console.log("  " + fn, "err", e.message.slice(0, 40)); }
    }
    try { const d = zlib.inflateSync(chunk); console.log("  inflate whole ->", d.length); } catch {}
  }
}
m.close();
