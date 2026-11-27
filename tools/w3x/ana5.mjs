
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const abil = JSON.parse(fs.readFileSync(base + "parsed-abil.json", "utf8"));
const item = JSON.parse(fs.readFileSync(base + "parsed-item.json", "utf8"));
const upg = JSON.parse(fs.readFileSync(base + "parsed-upg.json", "utf8"));
const jass = fs.readFileSync(base + "war3map.decoded.j", "utf8");

// 1. item quality
const q = {};
for (const it of Object.values(item)) { const m = (it.Name || "").match(/^【([^】]{1,4})】/); const k = m ? m[1] : "(none)"; q[k] = (q[k] || 0) + 1; }
console.log("item quality prefixes:", JSON.stringify(Object.entries(q).sort((a,b)=>b[1]-a[1])));

// 2. stat keywords in item Description/Ubertip
const statWords = ["攻击","力量","敏捷","智力","生命","护甲","暴击","暴伤","吸血","攻速","移速","金币","木材","经验","技能伤害","普攻伤害","闪避","命中","全属性","伤害加成","伤害减免","掉落","积分","词条","装备"];
const tally = {};
for (const it of Object.values(item)) {
  const t2 = (it.Description || "") + " " + (it.Ubertip || "") + " " + (it.Tip || "");
  for (const w of statWords) if (t2.includes(w)) tally[w] = (tally[w] || 0) + 1;
}
console.log("item stat keyword counts:", JSON.stringify(Object.entries(tally).sort((a,b)=>b[1]-a[1])));

// 3. ability categories
const cat = {};
for (const a of Object.values(abil)) { const m = (a.Name || "").match(/^【([^】]{1,10})】/); const k = m ? m[1] : "(普通/原生)"; cat[k] = (cat[k] || 0) + 1; }
console.log("ability categories:", JSON.stringify(Object.entries(cat).sort((a,b)=>b[1]-a[1])));

// 4. jass system keywords
const kw = ["抽卡","宝库","词条","羁绊","吞噬","存档","积分","U币","声望","挖矿","宠物","神器","宝石","天赋","符文","神赋","成长","难度","波次","通关","试炼","钓鱼","彩蛋","科技","部位","品质","合成","强化","进化","变异","商店","祭坛","转生","重铸","存档装备"];
const kc = {};
for (const w of kw) kc[w] = (jass.split(w).length - 1);
console.log("jass keyword hits:", JSON.stringify(Object.entries(kc).filter(([k,v])=>v>0).sort((a,b)=>b[1]-a[1])));

// 5. sample strings per system
const strings = fs.readFileSync(base + "strings-cjk.txt", "utf8").split("\n");
for (const w of ["宝库","词条","神赋","天赋","符文","难度","通关","存档","宠物","神器","宝石","钓鱼","试炼"]) {
  const hits = strings.filter(s => s.includes(w)).slice(0, 5);
  console.log("[" + w + "]", JSON.stringify(hits));
}
