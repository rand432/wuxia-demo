
import fs from "node:fs";
import path from "node:path";
const dir = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\blocks";
const files = fs.readdirSync(dir).filter(f => /slk_txt/.test(f));
for (const f of files.sort()) {
  const buf = fs.readFileSync(path.join(dir, f));
  const text = buf.toString("utf8");
  // find first K"..." cells to identify columns
  const keys = [...text.matchAll(/K"([^"]*)"/g)].map(m => m[1]).slice(0, 14);
  // count rows: max Y
  const ys = [...text.matchAll(/Y(\d+)/g)].map(m => parseInt(m[1], 10));
  const maxY = ys.length ? Math.max(...ys) : 0;
  console.log(f.replace(/\.\w+$/, "").padEnd(18), "| " + String(buf.length).padStart(7) + "B | rows " + String(maxY).padStart(5) + " | cols: " + keys.join(", "));
}
