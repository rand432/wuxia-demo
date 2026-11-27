
import fs from "node:fs";
import path from "node:path";

const roots = ["D:\\kkduizhan", "C:\\Users\\zq300\\AppData\\Roaming", "C:\\Users\\zq300\\AppData\\Local", "C:\\Users\\zq300\\AppData\\LocalLow", "C:\\ProgramData", "D:\\1", "C:\\Users\\zq300\\Documents"];
const skipParts = /node_modules|\\\.git\\|\\\.shots\\|\\wuxia-demo\\|\\Windows\\|\\\$Recycle|\\package|\\\.cache\\|\\npm-cache\\|\\JianyingPro\\/i;
const hits = [];
let checked = 0;
function probe(full) {
  let fd;
  try {
    fd = fs.openSync(full, "r");
    const b = Buffer.alloc(8);
    fs.readSync(fd, b, 0, 8, 0);
    const magic = b.readUInt32BE(0);
    const head4 = b.toString("latin1", 0, 4);
    const m1 = b.toString("latin1", 0, 4) === "HM3W";
    const m2 = b.readUInt32LE(0) === 0x1A51504D;
    if (m1 || m2) {
      const st = fs.statSync(full);
      hits.push({ full, size: st.size, mtime: st.mtime.toISOString().slice(0, 10), head: head4 });
    }
    checked++;
  } catch {} finally { if (fd !== undefined) try { fs.closeSync(fd); } catch {} }
  void magic;
}
function walk(d, depth) {
  if (depth > 8) return;
  let ents;
  try { ents = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
  for (const e of ents) {
    const f = path.join(d, e.name);
    if (skipParts.test(f)) continue;
    try {
      const st = fs.lstatSync(f);
      if (st.isSymbolicLink()) continue;
      if (e.isDirectory()) walk(f, depth + 1);
      else if (st.size > 100 * 1024) probe(f);
    } catch {}
  }
}
for (const r of roots) { try { if (fs.existsSync(r)) walk(r, 0); } catch {} }
hits.sort((a, b) => b.size - a.size);
console.log("files probed:", checked, "| MPQ/HM3W hits:", hits.length);
console.log(JSON.stringify(hits.filter(h => !/魔兽争霸3冰封王座\\Maps/i.test(h.full)).slice(0, 40), null, 1));
