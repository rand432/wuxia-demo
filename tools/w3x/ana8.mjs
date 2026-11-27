
import fs from "node:fs";
const p = "D:\\1\\wuxia-demo\\w3x-out\\shuashua\\files\\war3map.w3i";
const buf = fs.readFileSync(p);
let o = 0;
const i32 = () => { const v = buf.readInt32LE(o); o += 4; return v; };
const f32 = () => { const v = buf.readFloatLE(o); o += 4; return v; };
const cstr = () => { const s = o; while (buf[o] !== 0) o++; const v = buf.subarray(s, o).toString("utf8"); o++; return v; };
const ver = i32(), save = i32(), ed = i32();
const name = cstr(), author = cstr(), desc = cstr(), players = cstr();
for (let i = 0; i < 4; i++) f32();
for (let i = 0; i < 4; i++) i32();
const pw = i32(), ph = i32(), flags = i32();
o += 1; // tileset
i32();
const lsModel = cstr(), lsText = cstr(), lsTitle = cstr(), lsSubtitle = cstr();
i32();
const proPath = cstr(), proText = cstr(), proTitle = cstr(), proSub = cstr();
i32(); f32(); f32(); f32(); o += 4; i32(); i32();
const pc = i32();
console.log({ ver, save, ed, name, author, players, pw, ph, playerCount: pc, lsTitle });
const out = [];
for (let i = 0; i < pc && i < 12; i++) {
  const num = i32(), type = i32(), race = i32(), fixed = i32(), x = f32(), y = f32(), al = i32(), ah = i32();
  out.push({ num, type, race, fixed, al, ah });
}
console.log("players:", JSON.stringify(out));
const fc = i32();
const forces = [];
for (let i = 0; i < fc && i < 8; i++) { const fl = i32(), mask = i32(), fn = cstr(); forces.push({ fl, mask, fn }); }
console.log("forces:", JSON.stringify(forces));
