
import fs from "node:fs";
const idx = JSON.parse(fs.readFileSync("D:\\1\\wuxia-demo\\tools\\w3x\\map-index.json", "utf8"));
const trig = idx.filter(r => r.name && /TRIGSTR/.test(r.name));
const byDir = {};
for (const r of trig) {
  const dir = r.file.replace(/\\[^\\]+$/, "").replace("D:\\1\\魔兽争霸3冰封王座\\Maps", "Maps");
  byDir[dir] = (byDir[dir] || 0) + 1;
}
console.log("TRIGSTR maps by dir:", JSON.stringify(byDir, null, 1));
console.log("\nsample rows:");
console.log(trig.slice(0, 10).map(r => r.file.split("\\").pop() + " | " + r.name + " | wts=" + r.wtsCount).join("\n"));
const dzTrigs = trig.filter(r => r.file.includes("\\dz\\"));
console.log("\ndz TRIGSTR:", dzTrigs.length);
console.log(dzTrigs.slice(0, 30).map(r => r.file.split("\\").pop() + " | " + r.name).join("\n"));
