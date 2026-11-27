
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const abil = JSON.parse(fs.readFileSync(base + "parsed-abil.json", "utf8"));
const cats = new Set();
for (const a of Object.values(abil)) { const m = (a.Name || "").match(/^【([^】]{1,12})】/); cats.add(m ? m[1] : "(原生/无前缀)"); }
console.log("distinct ability categories:", cats.size);
const doc = fs.readFileSync("D:\\1\\wuxia-demo\\docs\\重生魔兽刷刷刷\\_技能全表.txt", "utf8").split("\n");
console.log("--- 技能全表 head ---");
console.log(doc.slice(0, 22).join("\n"));
const items = fs.readFileSync("D:\\1\\wuxia-demo\\docs\\重生魔兽刷刷刷\\_物品全表.txt", "utf8").split("\n");
console.log("--- 物品全表 head ---");
console.log(items.slice(0, 18).join("\n"));
