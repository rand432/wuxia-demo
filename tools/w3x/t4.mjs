
import fs from "node:fs";
import { hashString } from "./mpq.mjs";

function analyze(p) {
  const fd = fs.openSync(p, "r");
  const size = fs.fstatSync(fd).size;
  const findMagic = () => {
    const b = Buffer.alloc(4); let r = -1;
    for (const off of [0, 512]) { fs.readSync(fd, b, 0, 4, off); if (b.readUInt32LE(0) === 0x1A51504D) { r = off; break; } }
    return r;
  };
  const base = findMagic();
  if (base < 0) { fs.closeSync(fd); return { p, err: "no magic", size }; }
  const h = Buffer.alloc(32); fs.readSync(fd, h, 0, 32, base);
  const info = { size, base, headerSize: h.readUInt32LE(4), archiveSize: h.readUInt32LE(8), fmt: h.readUInt16LE(12), shift: h.readUInt16LE(14), hashPos: h.readUInt32LE(16), blockPos: h.readUInt32LE(20), hashSize: h.readUInt32LE(24), blockSize: h.readUInt32LE(28) };
  // try both absolute and base-relative
  for (const rel of [0, base]) {
    const hp = info.hashPos + rel;
    if (hp + 64 > size) continue;
    const b = Buffer.alloc(Math.min(64, size - hp)); fs.readSync(fd, b, 0, b.length, hp);
    let plausible = 0;
    for (let i = 0; i + 16 <= b.length; i += 16) { const blk = b.readUInt32LE(i + 12); if (blk === 0xFFFFFFFF || blk < info.blockSize) plausible++; }
    info["plausible@" + rel] = plausible + "/" + Math.floor(b.length / 16);
  }
  fs.closeSync(fd);
  return info;
}

const files = [
  "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(4)LostTemple.w3x",
  "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(2)EchoIsles.w3x",
  "D:\\1\\魔兽争霸3冰封王座\\Maps\\Download\\New_生化围城v1.5.65.w3x",
  "D:\\1\\魔兽争霸3冰封王座\\Maps\\(4)LostTemple.w3m",
];
for (const f of files) { try { console.log(JSON.stringify(analyze(f))); } catch (e) { console.log(f, "ERR", e.message); } }
console.log("hash (hash table)", hashString("(hash table)", 3).toString(16), "hash (block table)", hashString("(block table)", 3).toString(16));
