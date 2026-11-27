
import fs from "node:fs";
import path from "node:path";
import { MPQ, parseW3i, parseWts, resolveTrigStrings, decodeText } from "./mpq.mjs";

const roots = [
  "D:\\1\\魔兽争霸3冰封王座\\Maps",
];
const files = [];
function walk(dir) {
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of ents) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) walk(full);
    else if (/\.(w3x|w3m|w3n)$/i.test(e.name)) files.push(full);
  }
}
for (const r of roots) walk(r);
console.log("found", files.length, "maps");
const out = [];
for (const f of files) {
  const rec = { file: f, size: fs.statSync(f).size };
  let m;
  try {
    m = new MPQ(f);
    rec.hdr = { base: m.base, fmt: m.formatVersion, hash: m.hashTableSize, block: m.blockTableSize, hashEnc: m.hashTableEncrypted, blockEnc: m.blockTableEncrypted };
    const b = m.readFile("war3map.w3i");
    rec.w3i = b ? b.length : null;
    const info = parseW3i(b);
    let wts = new Map();
    if (info && /TRIGSTR/.test(info.name + info.author + info.description)) {
      try { const wb = m.readFile("war3map.wts"); if (wb) wts = parseWts(wb); } catch {}
    }
    if (info) {
      rec.name = resolveTrigStrings(info.name, wts);
      rec.author = resolveTrigStrings(info.author, wts);
      rec.desc = (resolveTrigStrings(info.description, wts) || "").slice(0, 80);
      rec.version = info.version;
      rec.wtsCount = wts.size;
    }
  } catch (e) {
    rec.err = e.message;
  } finally { try { m && m.close(); } catch {} }
  out.push(rec);
  console.log(JSON.stringify({ n: rec.name, s: rec.size, f: path.basename(rec.file), e: rec.err, w: rec.w3i }));
}
fs.writeFileSync(path.join(path.dirname(new URL(import.meta.url).pathname.slice(1)), "map-index.json"), JSON.stringify(out, null, 1), "utf8");
