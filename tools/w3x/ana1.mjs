
import fs from "node:fs";
const p = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\files\\war3map.j";
const buf = fs.readFileSync(p);
const utf8 = buf.toString("utf8");
const bad = (utf8.match(/\uFFFD/g) || []).length;
let text = utf8;
let enc = "utf8";
if (bad > 50) { text = new TextDecoder("gbk").decode(buf); enc = "gbk"; }
console.log("bytes", buf.length, "enc", enc, "bad", bad, "lines", text.split("\n").length);
fs.writeFileSync("D:\\1\\wuxia-demo\\w3x-out\\shuashua\\war3map.decoded.j", text, "utf8");
// function inventory
const fns = [...text.matchAll(/^function\s+([A-Za-z_][\w]*)\s+takes/gm)].map(m => m[1]);
console.log("functions:", fns.length);
const pre = {};
for (const f of fns) { const k = f.replace(/[0-9]+$/g, "").slice(0, 12); pre[k] = (pre[k] || 0) + 1; }
console.log("top prefixes:", JSON.stringify(Object.entries(pre).sort((a,b)=>b[1]-a[1]).slice(0, 25)));
// chinese strings
const strs = [...text.matchAll(/"((?:[^"\\]|\\.)*)"/g)].map(m => m[1]);
const cjk = strs.filter(s => /[\u4e00-\u9fff]/.test(s));
const uniq = [...new Set(cjk)];
console.log("string literals:", strs.length, "| with CJK:", cjk.length, "| unique CJK:", uniq.length);
fs.writeFileSync("D:\\1\\wuxia-demo\\w3x-out\\shuashua\\strings-cjk.txt", uniq.join("\n"), "utf8");
console.log("sample CJK strings:", JSON.stringify(uniq.slice(0, 25), null, 1));
console.log("--- first 60 lines ---");
console.log(text.split("\n").slice(0, 60).join("\n").slice(0, 2000));
