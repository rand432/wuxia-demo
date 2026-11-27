
import fs from "node:fs";
import path from "node:path";
const roots = ["D:\\kkduizhan", "D:\\1\\魔兽争霸3冰封王座"];
const out = [];
function walk(d, depth) {
  if (depth > 8) return;
  let ents = [];
  try { ents = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
  for (const e of ents) {
    const f = path.join(d, e.name);
    try {
      const st = fs.statSync(f);
      if (e.isDirectory()) walk(f, depth + 1);
      else if (st.size > 2 * 1024 * 1024 && st.mtime >= new Date("2026-10-01")) out.push({ f, size: st.size, mtime: st.mtime.toISOString().slice(0, 16) });
    } catch {}
  }
}
for (const r of roots) walk(r, 0);
out.sort((a, b) => b.mtime.localeCompare(a.mtime));
console.log("files >2MB modified since Oct 2026:", out.length);
for (const o of out.slice(0, 40)) console.log(o.mtime, "|", (o.size / 1048576).toFixed(1) + "MB", "|", o.f.replace("D:\\1\\魔兽争霸3冰封王座", "WAR3"));
// .dz_res listing
const dz = "D:\\1\\魔兽争霸3冰封王座\\.dz_res";
function walk2(d, depth) {
  if (depth > 5) return;
  let ents = [];
  try { ents = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
  for (const e of ents) {
    const f = path.join(d, e.name);
    try { const st = fs.statSync(f); if (e.isDirectory()) walk2(f, depth + 1); else console.log("  dz_res:", f, st.size, st.mtime.toISOString().slice(0, 10)); } catch {}
  }
}
console.log("== .dz_res ==");
walk2(dz, 0);
