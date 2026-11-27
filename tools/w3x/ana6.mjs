
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const strings = fs.readFileSync(base + "strings-cjk.txt", "utf8").split("\n").filter(Boolean);
const jass = fs.readFileSync(base + "war3map.decoded.j", "utf8");
const show = (label, re, n = 6) => {
  const hits = strings.filter(s => re.test(s)).slice(0, n);
  console.log("[" + label + "] " + JSON.stringify(hits));
};
show("波次", /波次|第.{1,3}波/, 8);
show("难度", /难度/, 8);
show("吞噬", /吞噬/, 8);
show("部位", /部位/, 6);
show("词条级", /词条/, 10);
show("宝库", /宝库|十连/, 6);
show("品质", /品质|[ABCDS]{2,}级/, 8);
show("积分", /积分/, 8);
show("上限", /上限/, 6);
// structural: how many functions reference 神赋/词条
const fnBodies = jass.split(/\nendfunction/);
const cnt = (w) => fnBodies.filter(b => b.includes(w)).length;
for (const w of ["神赋", "词条", "吞噬", "宝库", "试炼", "钓鱼", "存档", "难度", "符文", "宠物", "黑市", "投资", "彩蛋", "天赋"]) console.log("functions mentioning", w, cnt(w));
// waves: look for 进攻怪 / 怪物 wave
const m = jass.match(/[\u4e00-\u9fff]{0,8}(进攻|波|难度)[\u4e00-\u9fff]{0,8}/g) || [];
console.log("inkoGrep:", JSON.stringify([...new Set(m)].slice(0, 20)));
