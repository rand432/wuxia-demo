
import fs from "node:fs";
const base = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\";
const lines = fs.readFileSync(base + "war3map.decoded.j", "utf8").split("\n");
// function containing 18041
let s = 18041; while (s > 0 && !/^function\s/.test(lines[s])) s--;
let e = s; while (e < lines.length && !/^endfunction/.test(lines[e])) e++;
console.log("enclosing function:", lines[s], "| lines", s, "-", e);
for (let i = s; i < Math.min(e, s + 40); i++) console.log("  " + i + ": " + lines[i].trim().slice(0, 170));
// who sets 0xF5FB05F4 / 0x32C07523 (boss-started flags)
console.log("\nflag writes:", JSON.stringify(lines.map((l, i) => [i, l]).filter(([, l]) => /SaveBoolean\(YDHT, 1, 0x(F5FB05F4|32C07523)/.test(l)).map(([i, l]) => i)));
// boss countdown numbers (0x25DAB820 saved with 360 etc.)
console.log("boss countdown inits:", JSON.stringify(lines.map((l, i) => [i, l]).filter(([, l]) => /0x25DAB820, (\d+)\)/.test(l)).map(([i, l]) => i + ":" + (l.match(/0x25DAB820, (\d+)\)/) || [])[1]).slice(0, 30)));
// waves array init
const gw = lines.map((l, i) => [i, l]).filter(([, l]) => /set udg_GW_03\[/.test(l));
console.log("\nGW_03 array sets:", gw.length);
for (const [i, l] of gw.slice(0, 24)) console.log("  " + i + ": " + l.trim().slice(0, 120));
