
import fs from "node:fs";
const p = "D:\\1\\魔兽争霸3冰封王座\\Maps\\dz\\rpg\\maps.ini";
const buf = fs.readFileSync(p);
const dec = new TextDecoder("gbk");
console.log(dec.decode(buf));
