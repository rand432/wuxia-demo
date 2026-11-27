
import { MPQ, decodeText } from "./mpq.mjs";
const p = "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(4)LostTemple.w3x";
const m = new MPQ(p);
const bi = m.find("war3map.wts");
console.log("wts block idx:", bi);
if (bi >= 0) {
  const b = m.readFile("war3map.wts");
  console.log("len", b && b.length);
  if (b) console.log(JSON.stringify(decodeText(b).slice(0, 400)));
}
console.log("listfile idx:", m.find("(listfile)"), "attributes idx:", m.find("(attributes)"));
m.close();
