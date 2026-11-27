
import fs from "node:fs";
const idx = JSON.parse(fs.readFileSync("D:\\1\\wuxia-demo\\tools\\w3x\\map-index.json", "utf8"));
console.log("total", idx.length);
const failed = idx.filter(r => r.w3i == null);
console.log("failed w3i:", failed.length);
console.log(failed.map(r => r.file.split("\\").pop() + " | " + r.size + " | " + (r.err || "-") + " | " + JSON.stringify(r.hdr)).join("\n"));
console.log("TRIGSTR unresolved:", idx.filter(r => r.name && /TRIGSTR/.test(r.name)).length);
console.log("sample of named maps:", idx.filter(r => r.name && !/TRIGSTR/.test(r.name)).length);
