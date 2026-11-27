
import fs from "node:fs";
import { hashString } from "./mpq.mjs";
const cryptTable = new Uint32Array(0x500);
{ let seed = 0x00100001; for (let i = 0; i < 0x100; i++) { let idx = i; for (let j = 0; j < 5; j++) { seed = (seed * 125 + 3) % 0x2AAAAB; const t1 = (seed & 0xFFFF) << 0x10; seed = (seed * 125 + 3) % 0x2AAAAB; const t2 = (seed & 0xFFFF); cryptTable[idx] = (t1 | t2) >>> 0; idx += 0x100; } } }
function decrypt(buf, key) { let seed = 0xEEEEEEEE; for (let i = 0; i < buf.length >> 2; i++) { seed = (seed + cryptTable[0x400 + (key & 0xFF)]) >>> 0; const off = i * 4; let val = buf.readUInt32LE(off); val = (val ^ ((key + seed) >>> 0)) >>> 0; buf.writeUInt32LE(val, off); key = ((((~key) << 21) + 0x11111111) | (key >>> 11)) >>> 0; seed = (val + seed + (seed << 5) + 3) >>> 0; } return buf; }

function test(p) {
  const fd = fs.openSync(p, "r");
  const size = fs.fstatSync(fd).size;
  const h = Buffer.alloc(32); fs.readSync(fd, h, 0, 32, 512);
  const hashPos = h.readUInt32LE(16), blockPos = h.readUInt32LE(20), hashSize = h.readUInt32LE(24), blockSize = h.readUInt32LE(28);
  const out = {};
  for (const rel of [0, 512]) {
    for (const dk of [null, hashString("(hash table)", 3)]) {
      const hp = hashPos + rel; if (hp + hashSize * 16 > size) continue;
      let b = Buffer.alloc(hashSize * 16); fs.readSync(fd, b, 0, b.length, hp);
      if (dk != null) b = decrypt(Buffer.from(b), dk);
      let free = 0, valid = 0;
      for (let i = 0; i < hashSize; i++) { const blk = b.readUInt32LE(i * 16 + 12); if (blk === 0xFFFFFFFF) free++; else if (blk < blockSize) valid++; }
      out["hash rel" + rel + " key" + (dk ? "T" : "N")] = "free=" + free + " valid=" + valid + "/" + hashSize;
    }
    for (const dk of [null, hashString("(block table)", 3)]) {
      const bp = blockPos + rel; if (bp + blockSize * 16 > size) continue;
      let b = Buffer.alloc(blockSize * 16); fs.readSync(fd, b, 0, b.length, bp);
      if (dk != null) b = decrypt(Buffer.from(b), dk);
      let ok = 0, maxEnd = 0;
      for (let i = 0; i < blockSize; i++) { const fp = b.readUInt32LE(i * 16), cs = b.readUInt32LE(i * 16 + 4), fs_ = b.readUInt32LE(i * 16 + 8), fl = b.readUInt32LE(i * 16 + 12); if ((fl >>> 31) === 1 && cs <= fs_ && fp + cs <= size && fl < 0x90000000) ok++; maxEnd = Math.max(maxEnd, fp + cs); }
      out["block rel" + rel + " key" + (dk ? "T" : "N")] = "ok=" + ok + "/" + blockSize + " maxEnd=" + maxEnd;
    }
  }
  fs.closeSync(fd);
  return { p: p.split("\\").pop(), size, out };
}
for (const f of ["D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(4)LostTemple.w3x", "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(2)EchoIsles.w3x"]) console.log(JSON.stringify(test(f), null, 1));
