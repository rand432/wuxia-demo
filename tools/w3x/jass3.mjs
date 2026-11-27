
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const jass = fs.readFileSync(base + "war3map.decoded.j", "utf8");
const lines = jass.split("\n");
function fnAt(idx) {
  let s = idx, e = idx;
  while (s > 0 && !/^function\s/.test(lines[s])) s--;
  while (e < lines.length && !/^endfunction/.test(lines[e])) e++;
  return { s, e };
}
function dump(name, maxLines = 70) {
  const idx = lines.findIndex(l => l.includes("Trigger: " + name));
  if (idx < 0) { console.log("NOT FOUND", name); return; }
  const { s, e } = fnAt(idx);
  console.log("\n===== " + name + "  (function lines " + s + "-" + e + ", " + (e - s) + " 行) =====");
  console.log(lines.slice(s, Math.min(e, s + maxLines)).map(l => l.replace(/\s+$/, "")).join("\n").slice(0, 3000));
}
dump("刷怪01");
dump("设置进攻怪属性01");
dump("初始化03{CSH难度钓鱼}");
