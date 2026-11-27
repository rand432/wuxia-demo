
import fs from "node:fs";
import path from "node:path";
const dir = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\blocks";
const files = fs.readdirSync(dir).filter(f => /slk_txt|text/.test(f));
for (const f of files.sort()) {
  const full = path.join(dir, f);
  const buf = fs.readFileSync(full);
  const text = new TextDecoder("utf-8").decode(buf);
  const sections = [...text.matchAll(/^\s*\[([^\]]+)\]/gm)].map(m => m[1]);
  const keys = [...text.matchAll(/^\s*([A-Za-z]\w*)\s*=/gm)].map(m => m[1]);
  const keyCount = {};
  for (const k of keys) keyCount[k] = (keyCount[k] || 0) + 1;
  const topKeys = Object.entries(keyCount).sort((a, b) => b[1] - a[1]).slice(0, 8).map(x => x[0] + ":" + x[1]);
  const cjk = (text.match(/[\u4e00-\u9fff]/g) || []).length;
  console.log(f.replace(/\.\w+$/, ""), "| " + buf.length + "B | sections " + sections.length + " [" + sections.slice(0, 3).join(",") + "] | cjk " + cjk + " | keys " + topKeys.join(" "));
  console.log("   head:", JSON.stringify(text.slice(0, 160).replace(/\s+/g, " ")));
}
