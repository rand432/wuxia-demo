
import fs from "node:fs";
const idx = JSON.parse(fs.readFileSync("D:\\1\\wuxia-demo\\tools\\w3x\\map-index.json", "utf8"));
const unresolved = idx.filter(r => r.name && /TRIGSTR/.test(r.name));
const named = idx.filter(r => r.name && !/TRIGSTR/.test(r.name));
const none = idx.filter(r => !r.name);
console.log("total", idx.length, "| named", named.length, "| TRIGSTR left", unresolved.length, "| no-name", none.length);
const hits = idx.filter(r => r.name && /刷/.test(r.name));
console.log("name contains 刷:", hits.length, hits.map(h => h.name + " <- " + h.file.split("\\").pop()).join(" | "));
console.log("TRIGSTR left files:", unresolved.map(r => r.file.split("\\").pop() + ":" + r.name).join(", ").slice(0, 800));
