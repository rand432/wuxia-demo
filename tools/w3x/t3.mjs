
import fs from "node:fs";
const p = "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(4)LostTemple.w3x";
const fd = fs.openSync(p, "r");
const dump = (off, len) => { const b = Buffer.alloc(len); fs.readSync(fd, b, 0, len, off); return b.toString("hex").replace(/(.{32})/g, "$1\n") + "\n  ascii: " + b.toString("latin1").replace(/[^\x20-\x7e]/g, "."); };
console.log("== offset 0 ==");
console.log(dump(0, 64));
console.log("== offset 512 ==");
console.log(dump(512, 64));
console.log("== 512+244277 ==", 512+244277);
console.log(dump(512+244277, 48));
console.log("== 244277 ==");
console.log(dump(244277, 48));
// scan whole file for 'MPQ' magic
const size = fs.fstatSync(fd).size;
const all = Buffer.alloc(size); fs.readSync(fd, all, 0, size, 0);
for (let i = 0; i < size - 4; i++) { if (all.readUInt32LE(i) === 0x1A51504D) console.log("MPQ magic at", i); }
fs.closeSync(fd);
