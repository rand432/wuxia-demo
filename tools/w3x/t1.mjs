
import { MPQ, parseW3i } from "./mpq.mjs";
for (const p of ["D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(4)LostTemple.w3x", "D:\\1\\魔兽争霸3冰封王座\\Maps\\FrozenThrone\\(2)EchoIsles.w3x", "D:\\1\\魔兽争霸3冰封王座\\Maps\\Download\\DotA_IMBA_3.83.w3x"]) {
  try {
    const m = new MPQ(p);
    const b = m.readFile("war3map.w3i");
    const info = parseW3i(b);
    console.log(p.split("\\").pop(), "| hash", m.hashTableEncrypted, m.hashTableSize, "block", m.blockTableEncrypted, m.blockTableSize, "| w3i", b ? b.length : null, "|", JSON.stringify(info && { name: info.name, author: info.author, players: info.players }));
    m.close();
  } catch (e) { console.log(p, "ERR", e.message); }
}
