
import fs from "node:fs";
import zlib from "node:zlib";
import { MPQ, hashString, decryptBlock } from "./mpq.mjs";

const p = "D:\\1\\魔兽争霸3冰封王座\\Maps\\Download\\僵尸岛6(完整版).w3x";
const m = new MPQ(p);
const bi = m.find("war3map.w3i");
const be = m.blockTable[bi];
const raw = m.readAt(m.base + be.filePos, be.cSize);
const baseKey = hashString("war3map.w3i", 3);
const cands = {
  raw: null,
  key: baseKey,
  "(key+pos)^size": (((baseKey + be.filePos) >>> 0) ^ be.fSize) >>> 0,
  "key^size": (baseKey ^ be.fSize) >>> 0,
  "(key-1)": (baseKey - 1) >>> 0,
};
for (const [label, k] of Object.entries(cands)) {
  const buf = k == null ? Buffer.from(raw) : decryptBlock(Buffer.from(raw), k);
  let found = 0;
  for (let i = 0; i < buf.length - 2; i++) {
    if (buf[i] !== 0x78) continue;
    for (const fn of [zlib.inflateSync, zlib.inflateRawSync]) {
      try { const d = fn(buf.subarray(i)); if (d.length > 100) { if (found < 3) console.log(label, "zlib@", i, "->", d.length, "expected", be.fSize, JSON.stringify(d.subarray(0, 40).toString("utf8"))); found++; } } catch {}
    }
  }
  if (!found) console.log(label, "no zlib stream found");
}
m.close();
