
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const outDir = "D:\\1\\wuxia-demo\\docs\\重生魔兽刷刷刷";
fs.mkdirSync(outDir, { recursive: true });
const abil = JSON.parse(fs.readFileSync(base + "parsed-abil.json", "utf8"));
const item = JSON.parse(fs.readFileSync(base + "parsed-item.json", "utf8"));
const upg = JSON.parse(fs.readFileSync(base + "parsed-upg.json", "utf8"));
const buff = JSON.parse(fs.readFileSync(base + "parsed-buff.json", "utf8"));

const clean = (s) => (s || "")
  .replace(/\|c[0-9a-fA-F]{8}/g, "").replace(/\|r/g, "")
  .replace(/\|n/g, "\n").replace(/\\n/g, "\n")
  .replace(/\|c[0-9a-fA-F]{2}/g, "")
  .trim();

function catOf(name, map) { const m = (name || "").match(/^【([^】]{1,12})】/); return m ? m[1] : "(原生/无前缀)"; }

// 技能全表
{
  const groups = {};
  for (const [id, a] of Object.entries(abil)) {
    const c = catOf(a.Name, null);
    (groups[c] = groups[c] || []).push({ id, a });
  }
  const order = Object.keys(groups).sort((x, y) => groups[y].length - groups[x].length);
  const lines = ["===== 重生魔兽刷刷刷 · 技能/物品技能全表 =====", "来源：war3map SLK-INI（AbilityData），共 " + Object.keys(abil).length + " 条", ""];
  for (const c of order) {
    lines.push("===== [" + c + "] " + groups[c].length + " =====");
    for (const { id, a } of groups[c]) {
      lines.push("◆ " + (clean(a.Name) || "<无名称>") + "  (" + id + ")");
      const tip = clean(a.Tip), ub = clean(a.Ubertip), un = clean(a.Untip);
      if (tip && tip !== clean(a.Name)) lines.push("  提: " + tip.replace(/\n/g, " / "));
      if (un) lines.push("  末: " + un.replace(/\n/g, " / "));
      if (ub) lines.push("  效: " + ub.replace(/\n+/g, " / "));
      lines.push("");
    }
  }
  fs.writeFileSync(outDir + "\\_技能全表.txt", lines.join("\n"), "utf8");
  console.log("技能全表 lines:", lines.length);
}

// 物品全表
{
  const groups = {};
  for (const [id, it] of Object.entries(item)) {
    const c = catOf(it.Name, null);
    (groups[c] = groups[c] || []).push({ id, it });
  }
  const lines = ["===== 重生魔兽刷刷刷 · 物品全表 =====", "来源：ItemData，共 " + Object.keys(item).length + " 条", ""];
  for (const c of Object.keys(groups).sort()) {
    lines.push("===== [" + c + "] " + groups[c].length + " =====");
    for (const { id, it } of groups[c]) {
      lines.push("◆ " + (clean(it.Name) || "<无名称>") + "  (" + id + ")");
      const desc = clean(it.Description), ub = clean(it.Ubertip), tip = clean(it.Tip);
      if (desc) lines.push("  属: " + desc.replace(/\n/g, " / "));
      if (ub) lines.push("  效: " + ub.replace(/\n+/g, " / "));
      if (tip && tip !== clean(it.Name) && tip !== clean(it.Tip)) lines.push("  提: " + tip.replace(/\n/g, " / "));
      lines.push("");
    }
  }
  fs.writeFileSync(outDir + "\\_物品全表.txt", lines.join("\n"), "utf8");
  console.log("物品全表 lines:", lines.length);
}

// 升级 + buff
{
  const lines = ["===== 升级/科技（UpgradeData）" + Object.keys(upg).length + " ====="];
  for (const [id, u] of Object.entries(upg)) {
    lines.push("◆ " + (clean(u.Name) || "<无名称>") + "  (" + id + ")");
    if (u.Tip) lines.push("  提: " + clean(u.Tip).replace(/\n/g, " / "));
    if (u.Ubertip) lines.push("  效: " + clean(u.Ubertip).replace(/\n+/g, " / "));
  }
  lines.push("", "===== 光环/状态（BuffData）" + Object.keys(buff).length + " =====");
  for (const [id, b] of Object.entries(buff)) {
    const nm = b.Bufftip || b.Name || "";
    if (!nm) continue;
    lines.push("◆ " + clean(nm) + "  (" + id + ")" + (b.Buffubertip ? "  效: " + clean(b.Buffubertip).replace(/\n+/g, " / ") : ""));
  }
  fs.writeFileSync(outDir + "\\_升级与光环全表.txt", lines.join("\n"), "utf8");
  console.log("升级/光环 lines:", lines.length);
}

// 脚本字符串
{
  const strings = fs.readFileSync(base + "strings-cjk.txt", "utf8").split("\n").filter(Boolean);
  fs.writeFileSync(outDir + "\\_脚本中文串.txt", "===== war3map.j 内全部中文串（去重）" + strings.length + " 条 =====\n\n" + strings.join("\n"), "utf8");
  console.log("脚本串:", strings.length);
}
