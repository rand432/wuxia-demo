
import { MPQ, hashString } from "./mpq.mjs";
const p = "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(4)LostTemple.w3x";
const m = new MPQ(p);
console.log({headerOffset:m.headerOffset, hashPos:m.hashTablePos, blockPos:m.blockTablePos, hashSize:m.hashTableSize, blockSize:m.blockTableSize, size:m.size});
console.log("hash entries:");
const ht = m.hashTable;
for (let i = 0; i < Math.min(ht.length, 20); i++) console.log(i, JSON.stringify(ht[i]));
console.log("block entries:");
for (const [i, be] of m.blockTable.entries()) console.log(i, JSON.stringify(be), "0x"+(be.flags>>>0).toString(16));
console.log("hashA w3i", hashString("war3map.w3i",1).toString(16), "hashB", hashString("war3map.w3i",2).toString(16));
m.close();
