
import fs from "node:fs";
import path from "node:path";
import { MPQ, parseW3i, parseWts, resolveTrigStrings, decodeText } from "./mpq.mjs";

const STD_FILES = [
  "war3map.w3i", "war3map.wts", "war3map.wtg", "war3map.wct", "war3map.j", "war3map.lua",
  "scripts\\war3map.j", "scripts\\war3map.lua", "war3map.w3u", "war3map.w3t", "war3map.w3a",
  "war3map.w3h", "war3map.w3b", "war3map.w3d", "war3map.w3q", "war3map.w3r", "war3map.w3s",
  "war3map.w3c", "war3map.w3e", "war3map.imp", "war3map.wpm", "war3map.shd", "war3map.mmp",
  "war3map.doo", "war3mapUnits.doo", "war3mapMisc.txt", "war3mapSkin.txt", "war3mapExtra.txt",
  "war3map.ini", "(listfile)", "(attributes)", "war3mapMap.blp", "units\\UnitData.slk",
];

function main() {
  const args = process.argv.slice(2);
  if (!args.length) { console.error("usage: node w3x-extract.mjs <map.w3x> [outDir]"); process.exit(2); }
  const mapPath = args[0];
  const mapBase = path.basename(mapPath).replace(/\.(w3x|w3m|w3n)$/i, "");
  const outDir = args[1] || path.join(process.cwd(), "w3x-out", mapBase);
  fs.mkdirSync(path.join(outDir, "files"), { recursive: true });

  const m = new MPQ(mapPath);
  const report = {
    map: mapPath, size: m.size, base: m.base, formatVersion: m.formatVersion,
    sectorSize: m.sectorSize, hashTableSize: m.hashTableSize, blockTableSize: m.blockTableSize,
    hashTableEncrypted: m.hashTableEncrypted, blockTableEncrypted: m.blockTableEncrypted,
    info: null, names: [], extracted: [], missing: [],
  };

  // listfile
  let listNames = [];
  const lf = m.readFile("(listfile)");
  if (lf) listNames = decodeText(lf).split(/\r?\n/).map(s => s.trim()).filter(Boolean);

  const w3iBuf = m.readFile("war3map.w3i");
  const info = parseW3i(w3iBuf);
  let wts = new Map();
  const wtsBuf = m.readFile("war3map.wts");
  if (wtsBuf) wts = parseWts(wtsBuf);
  if (info) {
    report.info = {
      version: info.version, author: resolveTrigStrings(info.author, wts),
      name: resolveTrigStrings(info.name, wts), description: resolveTrigStrings(info.description, wts),
      players: resolveTrigStrings(info.players, wts),
    };
  }

  // extract
  const wanted = [...new Set([...STD_FILES, ...listNames])];
  const stdSet = new Set(STD_FILES.map(s => s.toUpperCase()));
  const MAX_BYTES = 40 * 1024 * 1024;
  for (const name of wanted) {
    let buf = null;
    const bi = m.find(name);
    if (bi >= 0) {
      const be = m.blockTable[bi];
      if (!stdSet.has(name.toUpperCase()) && be.fSize > MAX_BYTES) { report.skippedBig = (report.skippedBig || 0) + 1; continue; }
    }
    try { buf = m.readFile(name); } catch { buf = null; }
    if (!buf) { report.missing.push(name); continue; }
    const safe = name.replace(/[\\/]/g, "__");
    fs.writeFileSync(path.join(outDir, "files", safe), buf);
    report.extracted.push({ name, bytes: buf.length });
    if (name.startsWith("(")) report.names.push({ file: safe, text: decodeText(buf) });
  }

  if (wts.size) {
    const lines = [];
    const keys = [...wts.keys()].map(Number).sort((a, b) => a - b);
    for (const k of keys) lines.push("STRING " + k + "\n{\n" + wts.get(String(k)) + "\n}\n");
    fs.writeFileSync(path.join(outDir, "strings.txt"), lines.join("\n"), "utf8");
    report.wtsCount = wts.size;
  }
  fs.writeFileSync(path.join(outDir, "meta.json"), JSON.stringify(report, null, 1), "utf8");

  console.log(JSON.stringify({
    map: path.basename(mapPath),
    name: report.info && report.info.name,
    author: report.info && report.info.author,
    mapVersion: report.info && report.info.version,
    wtsStrings: wts.size,
    extractedFiles: report.extracted.length,
    listfileEntries: listNames.length,
    outDir,
  }, null, 1));
  const sizes = report.extracted.sort((a, b) => b.bytes - a.bytes).slice(0, 12);
  console.log("largest:", sizes.map(s => s.name + "=" + s.bytes).join(", "));
  m.close();
}
main();
