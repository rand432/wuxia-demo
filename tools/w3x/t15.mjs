
import fs from "node:fs";
import zlib from "node:zlib";
import { MPQ, hashString, decryptBlock } from "./mpq.mjs";

const p = "D:\\1\\魔兽争霸3冰封王座\\Maps\\Download\\僵尸岛6(完整版).w3x";
const m = new MPQ(p);
const bi = m.find("war3map.w3i");
const be = m.blockTable[bi];
const raw = m.readAt(m.base + be.filePos, be.cSize);
const baseKey = hashString("war3map.w3i", 3);
console.log("cSize", be.cSize, "fSize", be.fSize, "flags 0x" + (be.flags >>> 0).toString(16), "baseKey", baseKey.toString(16));
const cands = {
  "key": baseKey,
  "(key+pos)^size": (((baseKey + be.filePos) >>> 0) ^ be.fSize) >>> 0,
  "key^size": (baseKey ^ be.fSize) >>> 0,
  "(key+pos)": (baseKey + be.filePos) >>> 0,
  "key-1": (baseKey - 1) >>> 0,
};
const tryInflate = (buf) => {
  for (const [name, fn] of [["zlib", zlib.inflateSync], ["raw", zlib.inflateRawSync]]) {
    try { const d = fn(buf); if (d.length) return [name, d]; } catch {}
  }
  return null;
};
for (const [label, k] of Object.entries(cands)) {
  const dec = decryptBlock(Buffer.from(raw), k);
  // variant A: offset table at start
  const s0 = dec.readUInt32LE(0), s1 = dec.readUInt32LE(4);
  let res = null, note = "";
  if (s1 > s0 && s1 <= dec.length) {
    const chunk = dec.subarray(s0, s1);
    const r1 = tryInflate(chunk.subarray(1));
    if (r1) { res = r1[1]; note = "table[" + s0 + "," + s1 + "] type=" + chunk[0]; }
  }
  if (!res) {
    const r2 = tryInflate(dec.subarray(1));
    if (r2) { res = r2[1]; note = "whole type=" + dec[0]; }
  }
  if (!res) {
    // variant C: decrypt only data with sector key
    const sk = (((k + 0) >>> 0) ^ be.fSize) >>> 0;
    const dec2 = decryptBlock(Buffer.from(raw), sk);
    const s2 = dec2.readUInt32LE(0), s3 = dec2.readUInt32LE(4);
    if (s3 > s2 && s3 <= dec2.length) {
      const chunk = dec2.subarray(s2, s3);
      const r3 = tryInflate(chunk.subarray(1));
      if (r3) { res = r3[1]; note = "sectorKey table[" + s2 + "," + s3 + "] type=" + chunk[0]; }
    }
  }
  console.log(label, "->", res ? ("OK len=" + res.length + " (" + note + ") expected=" + be.fSize) : "fail");
  if (res && res.length === be.fSize) console.log("   head:", JSON.stringify(res.subarray(0, 80).toString("utf8")));
}
m.close();
