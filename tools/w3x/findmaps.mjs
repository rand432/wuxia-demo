
import fs from "node:fs";
import path from "node:path";
const roots = ["D:\\game","D:\\360安全浏览器下载","D:\\腾讯应用宝文件管理","D:\\Program","C:\\Users\\zq300\\Desktop","C:\\Users\\zq300\\Downloads","C:\\Users\\zq300\\Documents","D:\\视频","D:\\码"];
const found = [];
function walk(dir, depth) {
  if (depth > 8) return;
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of ents) {
    const full = path.join(dir, e.name);
    try {
      const st = fs.lstatSync(full);
      if (st.isSymbolicLink()) continue;
      if (e.isDirectory()) walk(full, depth + 1);
      else if (/\.(w3x|w3m|w3n)$/i.test(e.name)) found.push({ full, size: st.size, mtime: st.mtime.toISOString().slice(0,10) });
    } catch {}
  }
}
for (const r of roots) { try { if (fs.existsSync(r)) walk(r, 0); } catch {} }
console.log(JSON.stringify(found, null, 1));
console.log("total:", found.length);
