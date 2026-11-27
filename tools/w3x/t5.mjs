
import fs from "node:fs";
import { hashString } from "./mpq.mjs";
const p = "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(4)LostTemple.w3x";
const fd = fs.openSync(p, "r");
const size = fs.fstatSync(fd).size;
const dump = (off, len) => { const b = Buffer.alloc(Math.min(len, size - off)); fs.readSync(fd, b, 0, b.length, off); return off + ": " + b.toString("hex").replace(/(.{64})/g, "$1\n") ; };
console.log(dump(544, 64));
console.log(dump(size - 300, 300));
// try decrypting hash table with known keys
const cryptTable = new Uint32Array(0x500);
{ let seed = 0x00100001; for (let i = 0; i < 0x100; i++) { let idx = i; for (let j = 0; j < 5; j++) { seed = (seed * 125 + 3) % 0x2AAAAB; const t1 = (seed & 0xFFFF) << 0x10; seed = (seed * 125 + 3) % 0x2AAAAB; const t2 = (seed & 0xFFFF); cryptTable[idx] = (t1 | t2) >>> 0; idx += 0x100; } } }
function decrypt(buf, key) { let seed = 0xEEEEEEEE; for (let i = 0; i < buf.length >> 2; i++) { seed = (seed + cryptTable[0x400 + (key & 0xFF)]) >>> 0; const off = i * 4; let val = buf.readUInt32LE(off); val = (val ^ ((key + seed) >>> 0)) >>> 0; buf.writeUInt32LE(val, off); key = ((((~key) << 21) + 0x11111111) | (key >>> 11)) >>> 0; seed = (val + seed + (seed << 5) + 3) >>> 0; } return buf; }
for (const [label, key] of [["(hash table)", hashString("(hash table)", 3)], ["(block table)", hashString("(block table)", 3)]]) {
  for (const base of [0, 512]) {
    const hp = 244277 + base;
    const b = Buffer.alloc(64); fs.readSync(fd, b, 0, 64, hp);
    const d = decrypt(Buffer.from(b), key);
    console.log(label, "base", base, "->", d.toString("hex").replace(/(.{32})/g, "$1 "));
  }
}
fs.closeSync(fd);
