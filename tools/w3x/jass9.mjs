
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const lines = fs.readFileSync(base + "war3map.decoded.j", "utf8").split("\n");
console.log("=== full enemy stat lines 18269-18281 ===");
for (let i = 18269; i <= 18281; i++) console.log(i + ": " + lines[i].replace(/\t/g, " ").trim());
console.log("\n=== context around 18041 (boss execute) ===");
for (let i = 18000; i <= 18060; i++) {
  const l = lines[i];
  if (/udg_Time|if \(|function |TriggerExecute|SaveInteger\(YDHT, 1, 0x|comment/.test(l) || i >= 18035 && i <= 18045) console.log(i + ": " + l.trim().slice(0, 190));
}
