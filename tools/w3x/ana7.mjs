
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const jass = fs.readFileSync(base + "war3map.decoded.j", "utf8");
const strings = fs.readFileSync(base + "strings-cjk.txt", "utf8").split("\n").filter(Boolean);

// 1. version-like markers inside the map
const head = jass.split("\n").slice(0, 3).join(" | ");
console.log("jass header:", head);
const verRe = /[Vv]\d+\.\d+(\.\d+)?/g;
const verHits = [...new Set((jass.match(verRe) || []))].slice(0, 30);
console.log("version-like strings in jass:", JSON.stringify(verHits));
const dateHits = [...new Set((jass.match(/20\d\d[-年\.]\d{1,2}[-月\.]\d{1,2}/g) || []))].slice(0, 20);
console.log("dates in jass:", JSON.stringify(dateHits));
const strVer = strings.filter(s => /版本|V\d\.\d|v\d\.\d/.test(s)).slice(0, 25);
console.log("version strings:", JSON.stringify(strVer, null, 1));

// 2. map version / build markers in w3i + slk headers
const w3i = fs.readFileSync(base + "files\\war3map.w3i");
console.log("w3i len", w3i.length, "version", w3i.readInt32LE(0), "saveCount", w3i.readInt32LE(4), "editorVersion", w3i.readInt32LE(8));
const fds = base + "files\\";
for (const f of ["war3mapMisc.txt"]) { try { const b = fs.readFileSync(fds + f); console.log(f, "head:", JSON.stringify(b.subarray(0, 120).toString("utf8"))); } catch {} }
