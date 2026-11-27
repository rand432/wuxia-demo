
import fs from "node:fs";
import path from "node:path";
import { MPQ } from "./mpq.mjs";
const map = "D:\\1\\魔兽争霸3冰封王座\\Maps\\dz\\rpg\\ABF7FC0B0A80C407DD1DCC67F0E21139.w3x";
const outDir = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\blocks";
fs.mkdirSync(outDir, { recursive: true });
const m = new MPQ(map);
const bt = m.blockTable;
console.log("blocks:", bt.length);
const kinds = {};
const candidates = [];
for (let i = 0; i < bt.length; i++) {
  const be = bt[i];
  if ((be.flags & 0x80000000) === 0 || be.fSize < 400 || be.fSize > 4 * 1024 * 1024) continue;
  let buf;
  try { const r = m.readBlock(i, null); buf = r ? r[0] : null; } catch { buf = null; }
  if (!buf || buf.length < 400) continue;
  let kind = "bin";
  const head = buf.subarray(0, 64).toString("latin1");
  if (/^\uFEFF?ID;/.test(head) || /^\[/.test(head)) kind = "slk/txt";
  else if (/function\s|globals/.test(buf.subarray(0, 400).toString("latin1"))) kind = "jass";
  else if (buf.readUInt32LE(0) === 2 || buf.readUInt32LE(0) === 3) kind = "obj?";
  else if (/^[ -~\r\n\t]{40,}$/.test(head)) kind = "text";
  kinds[kind] = (kinds[kind] || 0) + 1;
  if (kind !== "bin") candidates.push({ i, size: buf.length, kind, head: head.replace(/[^\x20-\x7e]/g, ".").slice(0, 40) });
  if (buf.length < 2 * 1024 * 1024) fs.writeFileSync(path.join(outDir, "blk_" + i + "." + kind.replace(/\W/g, "_") + ".bin"), buf);
}
m.close();
console.log("kinds:", JSON.stringify(kinds));
console.log("candidates:", candidates.length);
for (const c of candidates.slice(0, 60)) console.log(c.i, "|", c.size, "|", c.kind, "|", c.head);
