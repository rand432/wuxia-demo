
import fs from "node:fs";
import path from "node:path";
const drives = [];
for (const l of "CDEFGHIJ") { if (fs.existsSync(l + ":\\")) drives.push(l + ":\\"); }
console.log("drives:", drives.join(" "));
const skipDirs = new Set(["windows","program files","program files (x86)","$recycle.bin","system volume information","appdata","node_modules","$windows.~bt","recovery","perflogs","msocache","config.msi","wuxia-demo"]);
const skipPrefix = ["C:\\Users\\zq300\\AppData","C:\\Windows","C:\\Program Files","C:\\ProgramData","C:\\Users\\zq300\\.dsh","C:\\Users\\zq300\\.cache","C:\\Users\\zq300\\.cargo","C:\\Users\\zq300\\.gradle","C:\\Users\\zq300\\.nuget","C:\\Users\\zq300\\.ollama","C:\\Users\\zq300\\.conda","C:\\Users\\zq300\\.vscode","C:\\Users\\zq300\\node_modules"];
const found = [];
let scanned = 0;
function walk(dir, depth) {
  if (depth > 7 || found.length > 400) return;
  for (const p of skipPrefix) if (dir.toLowerCase().startsWith(p.toLowerCase())) return;
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of ents) {
    const full = dir.endsWith("\\") ? dir + e.name : dir + "\\" + e.name;
    if (e.isDirectory()) { if (!skipDirs.has(e.name.toLowerCase())) walk(full, depth + 1); }
    else if (/\.(w3x|w3m)$/i.test(e.name)) { try { const st = fs.statSync(full); found.push({ full, size: st.size, mtime: st.mtime.toISOString().slice(0,10) }); } catch {} }
  }
  scanned++;
}
for (const d of drives) walk(d, 0);
console.log("dirs scanned:", scanned);
console.log(JSON.stringify(found.filter(f => !f.full.includes("魔兽争霸3冰封王座")), null, 1));
console.log("non-war3 maps:", found.filter(f => !f.full.includes("魔兽争霸3冰封王座")).length, "of", found.length);
