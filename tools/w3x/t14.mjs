
import fs from "node:fs";
import { MPQ, parseW3i } from "./mpq.mjs";
const idx = JSON.parse(fs.readFileSync("D:\\1\\wuxia-demo\\tools\\w3x\\map-index.json", "utf8"));
const failed = idx.filter(r => r.w3i == null);
for (const rec of failed) {
  let m;
  try {
    m = new MPQ(rec.file);
    const bi = m.find("war3map.w3i");
    const listBi = m.find("(listfile)");
    let detail = "w3iIdx=" + bi;
    if (bi >= 0) {
      const be = m.blockTable[bi];
      const raw = m.readAt(m.base + be.filePos, Math.min(be.cSize, 40));
      detail += " c=" + be.cSize + " f=" + be.fSize + " fl=0x" + (be.flags >>> 0).toString(16) + " head=" + raw.subarray(0, 12).toString("hex");
    }
    // count compression type bytes across small blocks
    const types = {};
    for (let i = 0; i < m.blockTableSize && i < 400; i++) {
      const be = m.blockTable[i];
      if (!(be.flags & 0x80000000) || be.cSize < 4 || be.cSize > 200000) continue;
      try {
        const r2 = m.readAt(m.base + be.filePos, 1);
        types[r2[0]] = (types[r2[0]] || 0) + 1;
      } catch {}
    }
    detail += " listfile=" + listBi + " firstBytes=" + JSON.stringify(types);
    console.log(rec.file.split("\\").pop(), "|", detail);
  } catch (e) { console.log(rec.file.split("\\").pop(), "ERR", e.message); }
  finally { try { m && m.close(); } catch {} }
}
