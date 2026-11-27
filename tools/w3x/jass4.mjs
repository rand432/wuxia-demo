
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const jass = fs.readFileSync(base + "war3map.decoded.j", "utf8");
const lines = jass.split("\n");
// map line -> trigger name
const trigAt = new Array(lines.length).fill("");
let cur = "";
for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(/\/\/\s*Trigger:\s*(.+)/);
  if (m) cur = m[1].trim();
  trigAt[i] = cur;
}
// 1. time comparisons
const timeCmp = [];
lines.forEach((l, i) => {
  const re = /udg_Time\s*(<|<=|>|>=|==|!=)\s*(-?[\d.]+)/g;
  let m;
  while ((m = re.exec(l))) timeCmp.push({ t: parseFloat(m[2]), op: m[1], trig: trigAt[i] || "-", line: i });
});
const uniqT = [...new Set(timeCmp.map(x => x.t))].sort((a, b) => a - b);
console.log("time thresholds used:", JSON.stringify(uniqT));
console.log("count:", timeCmp.length);
// group by threshold -> triggers
const byT = {};
for (const c of timeCmp) (byT[c.t] = byT[c.t] || new Set()).add(c.trig);
for (const t2 of uniqT.slice(0, 20)) console.log(t2 + "s ->", [...(byT[t2] || [])].slice(0, 6).join(" / "));

// 2. TimerStart intervals
const timers = [];
lines.forEach((l, i) => {
  const m = l.match(/TimerStart\(\s*([^,]+),\s*([\d.]+),\s*(true|false)/);
  if (m) timers.push({ interval: parseFloat(m[2]), periodic: m[3] === "true", trig: trigAt[i] || "-", line: i });
});
console.log("\nTimerStart count:", timers.length);
const byInt = {};
for (const x of timers) byInt[x.interval] = (byInt[x.interval] || 0) + 1;
console.log("intervals:", JSON.stringify(Object.entries(byInt).sort((a, b) => Number(a[0]) - Number(b[0]))));
for (const x of timers.slice(0, 25)) console.log("  " + x.interval + "s periodic=" + x.periodic + " @ " + x.trig + " (line " + x.line + ")");
