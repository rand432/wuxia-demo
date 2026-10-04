// ============================================================
// 《江湖游历》· 人物美术生成器（立绘 / 头像 / Q版）
//
// 两条通道：
//   glm    = 智谱 GLM-Image（~0.1 元/张，快，适合大批量迭代）
//   liblib = LiblibAI Qwen-Image + 国风武侠水墨 LoRA（~23 积分/张，风格最稳，可垫图锁角色）
//
// 用法：
//   node tools/gen_char_art.mjs --jobs shaoxia:立绘:glm:anime,shaoxia:立绘:glm:ink
//   node tools/gen_char_art.mjs --pilot          # 跑默认打样套（少侠 4 张对比）
//   node tools/gen_char_art.mjs --all            # 三个主角 × 立绘/头像/Q版（先改 --style）
//   node tools/gen_char_art.mjs --dry            # 只打印将提交的参数，不花钱
//
// 输出：assets/gen/char/<角色>/<角色>_<套>.png
// ============================================================
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';

const BASE = 'https://openapi.liblibai.cloud';
const HERE = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const CONF = [process.env.LIBLIB_CONF, path.join(HERE, '..', '.liblib.json'), path.resolve('.liblib.json'),
  path.join(os.homedir(), '.liblib', 'liblib.json')].filter(Boolean)
  .find((p) => { try { return fs.existsSync(p); } catch { return false; } }) || '';
const OUT_ROOT = path.resolve('assets/gen/char');

const args = process.argv.slice(2);
const has = (f) => args.includes('--' + f);
const opt = (f, d) => { const i = args.indexOf('--' + f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------- 角色设定（外形锁死，改这里全角色同步变） ----------------
const CHARS = {
  shaoxia: {
    cn: '少侠', title: '无名少年 · 主角',
    body: '一名年轻男子，身形清瘦挺拔，墨黑色长发束成高马尾、鬓边散落几缕碎发，面容清俊冷峻，眉眼细长，眼神沉静而带倦意，肤色偏白',
    cloth: '身着一袭深青灰交领窄袖长袍，衣料带淡淡墨色晕染与暗纹，腰间以深色布带束紧，小臂缠深色皮护腕，下着深色长裤与软靴，腰侧斜挂一柄直刃长刀，刀鞘深色无饰',
    pose: '双手抱臂而立，微微侧身，衣摆与发尾轻轻飘动',
    qpose: '双脚分开站定，一手按在腰侧刀柄上，另一手握拳垂在身侧',
    weapon: '长刀',
  },
  chenshi: {
    cn: '陈石', title: '弟子 · 阿石',
    body: '一名十七八岁少年，身材敦实粗壮，方圆脸，浓眉大眼，神情憨厚木讷，肤色偏黑，黑色短发以一条褐色布巾束起',
    cloth: '身穿粗布褐色短打劲装，外罩一件洗得发白的对襟褂子，肩宽手大，小臂缠粗布绑腿护腕，腰间系麻绳与布囊，下着深色扎脚长裤与布鞋，背后斜背一杆断了枪头的长枪，枪杆缠布',
    pose: '双脚稳稳分开站桩，一手拄着断枪，另一手垂在身侧握拳，肩背厚实微沉',
    qpose: '双手横持断枪挡在身前，双腿扎马步',
    weapon: '断枪',
  },
  qingluan: {
    cn: '苏青鸾', title: '弟子 · 游侠女',
    // ⚠ v71g（用户："苏看上去男的 重画"）：原来只写"少女"，模型照样给了一张男性脸
    //   （宽肩、粗眉、方下颌、平胸）。这里把**女性特征逐条写死**，并显式排除男性化。
    body: '一名十六七岁的**少女（明确的女性角色，绝不是男性、不是中性、不是少年）**，瓜子脸、下颌线条柔和，柳叶细眉、睫毛分明，杏眼明亮有神，鼻梁秀挺小巧，唇形小而饱满、唇色微红，脖颈纤细，肩窄腰细、身形轻盈窈窕，胸前轮廓清晰可见女性曲线，神情冷淡矜傲，肤白如雪，墨黑长发束成高马尾并垂一条细发辫，鬓边碎发随风轻扬',
    cloth: '身着月白与青碧色的交领窄袖劲装，衣料层次繁复、缀金属扣件与皮革束带，外披一件短氅，腰束革带、垂流苏飘带，腰后横别一对匕首，下着深色束脚长裤与轻靴，一手斜垂一柄长剑',
    pose: '侧身而立，一手轻按腰间匕首，另一手垂在身侧，衣摆与发尾随风扬起',
    qpose: '反手抽出匕首横在身前，重心前倾作起手式',
    weapon: '匕首',
  },

  // ============ 敌人 / 怪物（临时 Q版；原型覆盖一批杂兵名） ============
  // 游历：恶犬 / 剪径毛贼 / 独眼镖头 / 山道悍匪 / 黑风舵主 / 独臂刀客 …
  // 爬塔：10 章 × 5 名杂兵，按"拿什么兵器、什么打扮"归成下面这些原型
  mob_lou: {
    cn: '喽啰', title: '杂兵 · 山贼',
    body: '一名瘦削的中年汉子，尖嘴猴腮，三角眼游移不定，肤色黝黑，乱发用一条脏布带束起',
    cloth: '身穿洗得发灰的粗布短打，外罩半旧的褐色坎肩，腰间系草绳，下着绑腿布鞋，手里横着一把缺口柴刀',
    pose: '双腿分开半蹲，双手横握柴刀挡在胸前，肩背微驼',
    qpose: '双手横握柴刀挡在身前，双腿分开半蹲',
    weapon: '柴刀',
  },
  mob_blade: {
    cn: '刀客', title: '杂兵 · 刀手',
    body: '一名精悍的刀客，方脸浓眉，眼神狠戾，黑发以头巾束起',
    cloth: '身着深色劲装，外罩一件对襟短褂，小臂缠布护腕，腰间束带，手里握着一柄厚背长刀',
    pose: '侧身半马，长刀斜横在身前，重心压低',
    qpose: '侧身半马，双手握长刀横在身前',
    weapon: '长刀',
  },
  mob_spear: {
    cn: '枪手', title: '杂兵 · 长兵',
    body: '一名高瘦的枪手，脸型削长，颧骨高，眼神阴沉，乱发披散',
    cloth: '身穿灰褐色布甲，胸前一片皮护心镜，腰束革带，下着束脚长裤，双手持一杆比人还高的长枪',
    pose: '立姿持枪，枪尖斜指前方',
    qpose: '双手持长枪，枪尖斜指前方',
    weapon: '长枪',
  },
  mob_bow: {
    cn: '弩手', title: '杂兵 · 远程',
    body: '一名精瘦的弩手，细眉薄唇，眼神专注，短发以布条束起',
    cloth: '身穿紧身短打，背后一个箭囊，腰间挂着弩弦与皮囊，双手端着一具木制弩机',
    pose: '侧身端起弩机作瞄准状，一腿后撤',
    qpose: '侧身端起弩机瞄准',
    weapon: '弩机',
  },
  mob_hook: {
    cn: '钩手', title: '杂兵 · 水匪',
    body: '一名膀大腰圆的水匪，脸膛黝黑，络腮短须，眼神浑浊，头发湿漉漉地贴在额上',
    cloth: '上身赤膊只系一件粗布坎肩，肩上搭着缆绳，腰间围着防水布裙，手里拎着一把生锈的铁钩',
    pose: '半蹲作势，铁钩举在肩侧',
    qpose: '半蹲举铁钩在肩侧',
    weapon: '铁钩',
  },
  mob_flag: {
    cn: '旗手', title: '杂兵 · 掌旗',
    body: '一名壮实的旗手，方脸阔额，神情傲慢，短发以皮箍束起',
    cloth: '身穿深色号衣，胸前一个白色的字，腰间束宽带，双手扛着一面卷着的大旗，旗杆很长',
    pose: '立姿扛旗，一肩微沉',
    qpose: '双手扛大旗立姿',
    weapon: '大旗',
  },
  mob_chief: {
    cn: '头目', title: '精英 · 蒙面',
    body: '一名高大的蒙面人，只露出一双冷眼，眉骨突出，气度阴沉',
    cloth: '身披黑色长斗篷，内穿深色劲装，胸前有金属兽纹扣，腰束宽革带，双手各握一柄短刀，衣摆被风掀起',
    pose: '立姿微侧，双刀一前一后',
    qpose: '立姿双刀交叉在身前',
    weapon: '双刀',
  },
  mob_one_arm: {
    cn: '独臂刀客', title: '精英 · 守关',
    body: '一名独臂的中年刀客，另一半袖管空荡荡地垂着，面容枯瘦，眼神死寂，鬓角斑白',
    cloth: '身穿洗旧的灰袍，外罩一件破斗笠的蓑衣，腰间束麻绳，仅剩的一手握着一柄极长的直刀',
    pose: '立姿不动，长刀拄地',
    qpose: '单手握长刀拄地而立',
    weapon: '长刀',
  },
  mob_dog: {
    cn: '恶犬', title: '野兽',
    // ⚠ v71d：**必须把"四足野兽"写死**。原来只写"一条黑色恶犬"，模型一律给人形——
    //   第一版拿苏青鸾当底图，出了个女人形（用户："苏青不是女的吗"）；
    //   第二版文生图又出来个"狗头人身、穿着黑袍"的怪物。这里逐条否掉人形特征。
    body: '一条四足行走的黑色恶犬（**是一条狗，不是人，不是兽人，不是狗头人**），瘦骨嶙峋、肋骨根根可见，杂毛竖立，眼睛泛着红光，呲着尖牙，四条腿着地，尾巴平伸，身上不穿任何衣服、没有人类的手和脚',
    cloth: '颈上套着一圈磨旧的皮项圈，项圈下垂着半截断绳',
    pose: '前肢低伏、后腿蹬地作扑咬状，尾巴平伸',
    qpose: '四条腿着地的恶犬，前肢低伏后腿蹬地，呲牙作扑咬状',
    weapon: '獠牙',
  },

  // ============ 场景（无人，水墨；用 --set 场景 出） ============
  scene_gate: {
    cn: '村口', title: '主场景',
    body: '中国水墨山水画：一座依山的荒村，几间茅草土屋错落，村口立着一棵枯了半边的老槐树，一条土路从画面下缘蜿蜒进村，远处山影淡淡、晨雾未散，天上几笔飞白，大面积留白，冷灰与赭石为基调，笔触写意，画面中没有任何人物',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  scene_tower: {
    cn: '塔', title: '爬塔场景',
    body: '中国水墨画：一座高耸入云的九层古塔立于山巅，塔身以焦墨勾出、层层收分，塔下石阶盘旋而上，两侧古松斜出，云雾从山腰漫过吞掉塔基，冷青灰为基调，笔触写意，大面积留白，画面中没有任何人物',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  scene_scroll: {
    cn: '村景长卷', title: '主场景',
    body: '中国水墨长卷：一座山坳里的小村，从左到右依次是木牌坊山门、几间茅草土屋、一座竹屋、一道溪流与小木桥、一处货栈院子、一处作坊工棚，远处山影层叠云雾缭绕，近处几株老树与竹丛，纸白底、淡墨为主、留白多，横幅长卷构图，画面中没有任何人物、没有任何文字',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  scene_buildings: {
    cn: '建筑图集', title: '建筑素材',
    body: '中国水墨画：六个古代村舍建筑**横向等距排成一行**，从左到右依次是——①茅草土屋 ②竹屋 ③石桌石凳 ④木牌坊山门 ⑤搭着脚手架的工地 ⑥溪边小木桥；每个建筑单独完整、互不重叠、大小相近，淡墨勾线、赭石与花青略作点缀，纯白背景，画面中没有任何人物、没有任何文字',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  room_alchemy: {
    cn: '炼丹房', title: '室内场景',
    body: '中国水墨画：一间古代炼丹房的室内（**正对视角、平视，不要俯视不要等距**），正中间一座青铜丹炉冒着淡淡青烟，两侧木架上摆满药瓶药罐与药材，墙上挂着一串干草药，窗外透进天光，纸白底、淡墨为主、赭石与花青略作点缀，留白多，画面中没有任何人物、没有任何文字',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  room_store: {
    cn: '货仓', title: '室内场景',
    body: '中国水墨画：一间古代货仓的室内（**正对视角、平视，不要俯视不要等距**），堆放着木箱、麻袋、成捆的木料与酒坛，一架木梯靠在梁上，高窗透光、浮尘可见，纸白底、淡墨为主、赭石略作点缀，留白多，画面中没有任何人物、没有任何文字',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  chest_open: {
    cn: '宝箱', title: '道具特写',
    body: '中国水墨画：一只**打开的木宝箱特写**，箱盖掀开、里面堆着银锭与卷轴、箱口透出一层淡淡金光，箱身包着铜角与锁扣，纸白底、淡墨勾线、赭石与金色略作点缀，画面居中、留白多，画面中没有任何人物、没有任何文字',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  house_side: {
    cn: '侧视村舍', title: '村庄建筑（正侧视）',
    // ⚠ 视角必须写死：素材里那批是等距 2.5D，跟本作的正侧视平面打架；
    //   这一版专门强调"正侧视、底面同一条水平线、檐口一律朝右"。
    body: '中国水墨画：六座中国古代村舍建筑，**全部正侧视（绝对不要等距斜视、不要俯视、不要立体方块感）**，从左到右依次是——①一间茅草顶土屋 ②一座竹屋（竹墙竹顶）③一间带院墙的货栈大屋 ④一座作坊工棚（有木架与棚顶）⑤一座两层的藏宝小楼 ⑥一座木牌坊山门；六座建筑的**屋baseline 底边全部落在同一条水平线上**、大小相近、互不重叠，屋檐朝向一致（都朝右），淡墨勾线、赭石与花青略作点缀，纯白背景，画面中没有任何人物、没有任何文字',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  icon_q: {
    cn: 'Q版道具图', title: '道具图标（二次元）',
    body: '**二次元手游道具图标（画法：粗黑描边 + 明亮平涂 + 高饱和配色，看上去像贴纸；绝对不要水墨、不要写意、不要灰调、不要写实厚涂、不要毛笔质感）**：九件道具**排成整齐的三行三列**，横竖间距均匀、大小相近，从左到右从上到下依次是——第一行：①一柄长剑 ②一把厚背刀 ③一杆长枪；第二行：④三枚飞镖暗器 ⑤一件皮甲 ⑥一块系穗玉佩；第三行：⑦一本线装武功秘籍 ⑧一株药草 ⑨一只酒坛；每件都是**厚描边的二次元平涂**、色彩鲜明（月白/青蓝/赭石/朱红），圆润可爱，纯白背景，画面中没有任何人物、没有任何文字',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  house_ruin_side: {
    cn: '侧视废墟', title: '村庄建筑（废墟态）',
    body: '中国水墨画：一座**颓败的废弃村舍**（**正侧视、平视，不要等距不要俯视**），只剩半截土墙与塌落的茅草屋顶，焦黑的梁木斜插着，墙角长着杂草，底边与地面齐平，淡墨为主、赭石略作点缀，纯白背景，画面中没有任何人物、没有任何文字',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  icon_q2: {
    cn: 'Q版道具图乙', title: '道具图标（二次元·补）',
    body: '**二次元手游道具图标（粗黑描边 + 明亮平涂 + 高饱和，像贴纸；不要水墨不要写实）**：六件道具横排成**两行三列**，间距均匀：第一行 ①一杆红缨长枪 ②一本蓝色线装秘籍 ③一只青瓷酒坛；第二行 ④一捆木料 ⑤一枚银锭 ⑥一块木质令牌；纯白背景、画面中没有人物、没有文字、没有枪械',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  pet_fox: {
    cn: '灵狐', title: '宠物 · 白狐',
    body: '一只**Q版二头身**的雪白灵狐（大头小身、圆脑袋、大眼睛、短腿，二次元手游萌宠造型），毛色雪白、耳尖与尾尖带淡青，眼睛大而明亮呈琥珀色，尾巴蓬松翘起，圆润可爱',
    cloth: '颈上系一条朱红细绳坠着小铃铛',
    pose: '四足站立、微微歪头看着前方',
    qpose: '四足站立、歪头看前方',
    weapon: '爪',
  },
  pet_falcon: {
    cn: '青隼', title: '宠物 · 青隼',
    body: '一只**Q版二头身**的青灰色小隼（大头小身、圆脑袋、大眼睛、短翅短尾，二次元手游萌宠造型），羽毛青灰带月白、翅尖墨黑，眼睛大而机灵呈金色，圆润可爱',
    cloth: '脚上系一条细皮绳',
    pose: '站立、翅膀半张作欲飞状',
    qpose: '站立、翅膀半张',
    weapon: '喙',
  },
  pet_q: {
    cn: '宠物Q版', title: '宠物（二次元）',
    body: '明亮干净的国风二次元 Q版 游戏宠物：**两只并排**，左边是一只雪白的灵狐（九尾狐，大眼萌，毛茸茸），右边是一只青灰色的隼（小青鹰，翅膀半张，眼神机灵），都是**厚描边的二次元平涂**、色彩鲜明，圆润可爱，纯白背景，画面中没有任何人物、没有任何文字',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  gear_sheet: {
    cn: '兵械图集', title: '兵器护具素材',
    body: '中国水墨画：八件武侠器物**排成整齐的四列两行**，横竖间距均匀、互不重叠、大小相近，从左到右从上到下依次是——第一行：①一对双刀（两把并排）②一柄短匕首 ③一杆长枪 ④三枚飞镖暗器；第二行：⑤一件皮甲护身 ⑥一块系着穗子的玉佩 ⑦一件披风（挂着的）⑧一根铁棍；每件都单独完整、淡墨勾线、赭石与花青略作点缀，纯白背景，画面中没有任何人物、没有任何文字',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  items_sheet: {
    cn: '道具图集', title: '道具素材',
    body: '中国水墨画：九件武侠道具**排成整齐的三行三列**，横竖间距均匀、互不重叠、大小相近，从左到右从上到下依次是——第一行：①一柄长剑 ②一只丹瓶 ③一株药草；第二行：④一只酒坛 ⑤一捆木料 ⑥一卷布匹；第三行：⑦一枚银锭 ⑧一块令牌 ⑨一本线装秘籍；每件都单独完整、淡墨勾线、赭石与花青略作点缀，纯白背景，画面中没有任何人物、没有任何文字',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
  scene_inn: {
    cn: '酒肆', title: '室内场景',
    body: '中国水墨画：一间荒野酒肆的内景，几张旧木桌与长凳，柜台上一排陶制酒坛，墙上挂着蓑衣与斗笠，门窗大开、外面是淡墨的远山，光线从门口斜射进来，冷灰为基调，笔触写意，大面积留白，画面中没有任何人物',
    cloth: '', pose: '', qpose: '', weapon: '',
  },
};

// ---------------- 风格尾巴 ----------------
const ANIME = '，国风二次元游戏角色立绘，赛璐璐上色，线条干净利落，冷青灰色调为主，衣料带淡淡水墨晕染质感，光影柔和，画面精致，全身完整不裁切，画面中只有这一个人物，纯白背景，背景没有任何景物，画面中没有文字没有水印没有logo没有签名';
// v71（用户定调："Q版二次元更干净整洁，更符合大众审美"）：
//   ANIME 那条尾巴写着"冷青灰色调为主、带水墨晕染"，敌人出图就发灰——这条专门给
//   **明亮干净的二次元**用：配色清爽、线条利落、五官精神（人物统一走这条路）。
const ANIME2 = '，明亮干净的国风二次元 Q版 游戏角色，赛璐璐平涂上色，线条干净利落、轮廓清晰，配色明亮清爽（月白、青蓝、赭石、墨黑为主，点缀朱红），五官清晰有神、眼睛明亮，光影通透干净，画面整洁，全身完整不裁切，画面中只有这一个人物，纯白背景，背景没有任何景物，画面中没有文字没有水印没有logo没有签名';
const INK = '，中国古风水墨人物画，宣纸质感，墨色浓淡五层，笔触写意洒脱，面部用淡墨勾线、五官清秀可辨，衣纹以焦墨飞白表现，冷青灰为基调，大面积留白，全身完整不裁切，画面中只有这一个人物，纯白背景，背景没有任何景物，画面中没有文字没有水印没有logo没有签名';

// 水墨大写意：AI 的短板（线稿不精确、细节糊成一团）在这个赛道里恰好变成"风格"
const XIEYI = '，中国水墨大写意人物画，宣纸质感，焦墨与飞白，笔触淋漓酣畅、线条有粗细顿挫，衣纹以枯笔扫出，发丝以细笔勾扬，面部仅淡墨数笔勾出、神情清冷，墨色浓淡五到七层，画面只用水墨＋一点朱红点缀，纸面有渗墨与水痕，大面积留白，写意不写实，全身完整不裁切，画面中只有这一个人物，画面中没有文字没有印章没有水印没有logo';

// 鸣潮/库洛那种二次元游戏立绘：精细线稿 + 赛璐璐与厚涂结合、服装细节繁复、风动感
const MENGCHAO = '，高品质二次元游戏角色立绘（国产二次元手游卡面那种质感），精细线稿与通透的赛璐璐上色结合局部厚涂，服装结构繁复（交领、束带、金属扣件、皮革绑带、流苏飘带），衣摆与发丝带风动感，光影通透有层次，冷调高对比，电影感构图，全身完整不裁切，画面中只有这一个人物，纯白背景，背景没有任何景物，画面中没有文字没有水印没有logo没有签名';
const GUOFENG = '，中国古风武侠人物插画，精致细腻的半写实国风画风，柔和厚涂与赛璐璐结合的质感，冷青灰色调，衣料纹样细致，光影柔和通透，画面干净利落，全身完整不裁切，画面中只有这一个人物，纯白背景，背景没有任何景物，画面中没有文字没有水印没有logo没有签名';
const NEG_COMMON = '文字,汉字,书法,印章,水印,签名,logo,字幕,多个角色,两个人,重复人物,背景景物,树木,山水,建筑,房间,现代服饰,西式服装,西装,3D渲染,照片,写实照片,油画厚涂,高饱和度,艳丽俗气,日式和服,日本武士,太刀,多余的手,三只手,六指,畸形手指,断手,脸崩,崩坏,低质量,模糊,裁切,半身';
const NEG_Q = NEG_COMMON + ',写实比例,成人比例,九头身,长腿,细长身材,狰狞';
// 按性别分：女角色不许出男人；男角色不许出女人
const NEG_MALE = NEG_COMMON + ',男性,男人,男子,胡子,络腮胡,粗犷,魁梧,壮汉,肌肉块';
const NEG_FEMALE = NEG_COMMON + ',男性,男人,男子,少年,胡须,粗犷,魁梧,壮汉,肌肉块,中性';
const NEG_BUST = NEG_COMMON.replace(',半身', '');

// ---------------- 出图套（尺寸按通道给） ----------------
const SETS = {
  '立绘': { suffix: '全身立绘站姿，完整人物全身像（含鞋靴与头顶发髻，任何部位都不得被画面边缘裁掉），人物高度约占画面的七成五，头顶留白约一成、脚下留白约一成，全身立绘站姿', glm: [1056, 1568], liblib: [928, 1664], neg: NEG_COMMON },
  '头像': { suffix: '胸像特写，半身构图，人物面部居中清晰、五官精致，眼睛看向观者，肩部完整', glm: [1024, 1024], liblib: [1024, 1024], neg: NEG_BUST },
  // 横版角色卡面（照参考图那种：人物在右、左边留白放名字与星级）
  '卡面': { suffix: '横版角色卡面构图：人物置于画面右侧约三分之二处，取膝上半身、四分之三侧身，微微回眸看向画外，左侧留出大片空白用于排名字与星级，画面下方留出不多的空间', glm: [1728, 960], liblib: [1664, 928], neg: NEG_BUST },
  // 场景：横版概念图，无人
  '场景': { suffix: '横版场景概念图，中远景，构图讲究、留白充足，画面中没有任何人物、没有任何文字', glm: [1728, 960], liblib: [1664, 928], neg: NEG_COMMON + ',人物,人,人影,文字,印章,水印,现代建筑' },
  'Q版': { suffix: 'Q版二头身萌系造型，大头小身，圆圆的脸，眼睛大而明亮，身形小巧，清晰描边，游戏战斗立绘用', glm: [1024, 1024], liblib: [1024, 1024], neg: NEG_Q },
};

// ---------------- Liblib 签名 / 请求 ----------------
function signedPath(uri, accessKey, secretKey) {
  const timestamp = Date.now();
  const nonce = crypto.randomBytes(16).toString('hex').slice(0, 16);
  const content = uri + '&' + timestamp + '&' + nonce;
  const sig = crypto.createHmac('sha1', secretKey).update(content).digest('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return uri + '?AccessKey=' + accessKey + '&Signature=' + sig + '&Timestamp=' + timestamp + '&SignatureNonce=' + nonce;
}
async function liblibApi(uri, cfg, body, tries = 6) {
  for (let attempt = 0; ; attempt++) {
    const r = await fetch(BASE + signedPath(uri, cfg.accessKey, cfg.secretKey), {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    const text = await r.text();
    let j; try { j = JSON.parse(text); } catch { throw new Error('非 JSON 响应 [' + r.status + '] ' + text.slice(0, 300)); }
    if (j.code === 429 || j.code === 100054) {
      if (attempt >= tries) throw new Error('限流/并发超限：' + j.msg);
      const wait = 15000 * (attempt + 1);
      console.log('  … 限流(' + j.code + ')，等 ' + (wait / 1000) + 's 重试');
      await sleep(wait); continue;
    }
    if (j.code !== 0) throw new Error('API code=' + j.code + ' msg=' + j.msg + ' | ' + text.slice(0, 250));
    return j.data;
  }
}

// ---------------- 两通道出图 ----------------
async function genGlm(prompt, [w, h], outBase) {
  const cfgPath = path.join(os.homedir(), '.modlens', 'config.json');
  const key = JSON.parse(fs.readFileSync(cfgPath, 'utf8'))?.providers?.openai?.apiKey ?? '';
  if (!key) throw new Error('没找到智谱 key（~/.modlens/config.json）');
  const resp = await fetch('https://open.bigmodel.cn/api/paas/v4/images/generations', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: 'glm-image', prompt: prompt.slice(0, 1000), size: w + 'x' + h, n: 1 }),
  });
  const txt = await resp.text();
  if (!resp.ok) throw new Error('[' + resp.status + '] ' + txt.slice(0, 300));
  const url = JSON.parse(txt).data?.[0]?.url;
  if (!url) throw new Error('响应无图片：' + txt.slice(0, 200));
  const bin = Buffer.from(await (await fetch(url)).arrayBuffer());
  const ext = bin[0] === 0x89 && bin[1] === 0x50 ? '.png' : '.jpg';
  fs.writeFileSync(outBase + ext, bin);
  return { file: outBase + ext, cost: '约 0.1 元' };
}

// 上传本地图到 OSS（img2img 垫图要 URL）
async function uploadImage(filePath, cfg) {
  const base = path.basename(filePath);
  const ext = base.split('.').pop();
  const sig = await liblibApi('/api/generate/upload/signature', cfg, { name: base.replace(/\.[^.]+$/, ''), extension: ext });
  const mime = /jpe?g$/i.test(ext) ? 'image/jpeg' : 'image/png';
  const form = new FormData();
  form.append('x-oss-signature', sig.xOssSignature);
  form.append('x-oss-date', sig.xOssDate);
  form.append('x-oss-signature-version', sig.xOssSignatureVersion);
  form.append('policy', sig.policy);
  form.append('key', sig.key);
  form.append('x-oss-credential', sig.xOssCredential);
  form.append('x-oss-expires', String(sig.xOssExpires));
  form.append('file', new Blob([fs.readFileSync(filePath)], { type: mime }), base);
  const r = await fetch(sig.postUrl, { method: 'POST', body: form });
  if (!r.ok) throw new Error('上传失败 [' + r.status + '] ' + (await r.text()).slice(0, 200));
  return new URL(sig.key, sig.postUrl).toString();
}

// img2img：拿一张现成的图当底，低重绘幅度"细化/放大"（denoise 0.3~0.55 是加细节，0.6+ 会改画风）
async function genLiblibImg(prompt, negative, [w, h], outBase, loraOverride, srcFile, denoise) {
  if (!CONF) throw new Error('找不到 .liblib.json');
  const cfg = JSON.parse(fs.readFileSync(CONF, 'utf8'));
  const url = await uploadImage(srcFile, cfg);
  const payload = {
    templateUuid: cfg.templateUuidImg2img || cfg.templateUuid,
    generateParams: {
      ...(cfg.checkPointId ? { checkPointId: cfg.checkPointId } : {}),
      prompt: prompt.slice(0, 2000),
      negativePrompt: negative,
      sampler: cfg.sampler, steps: cfg.steps, cfgScale: cfg.cfgScale,
      width: w, height: h, imgCount: 1, randnSource: cfg.randnSource ?? 1, seed: -1,
      restoreFaces: 0,
      ...(has('nolora') ? {} : { additionalNetwork: loraOverride ? [{ modelId: loraOverride, weight: 0.8 }] : cfg.loras }),
      sourceImage: url, resizeMode: 0, resizedWidth: w, resizedHeight: h, mode: 0,
      denoisingStrength: denoise,
    },
  };
  const sub = await liblibApi('/api/generate/webui/img2img', cfg, payload);
  process.stdout.write('  提交 ' + sub.generateUuid + ' 等待中');
  let pred = null;
  for (let i = 0; i < 100; i++) {
    await sleep(3000);
    pred = await liblibApi('/api/generate/webui/status', cfg, { generateUuid: sub.generateUuid });
    process.stdout.write('.');
    if (pred.generateStatus === 5 || [6, 7].includes(pred.generateStatus)) break;
  }
  process.stdout.write('\n');
  if (!pred || pred.generateStatus !== 5) throw new Error('status=' + (pred && pred.generateStatus) + ' msg=' + (pred && pred.generateMsg));
  const img = (pred.images || [])[0];
  const bin = Buffer.from(await (await fetch(img.imageUrl)).arrayBuffer());
  const ext = bin[0] === 0x89 && bin[1] === 0x50 ? '.png' : '.jpg';
  fs.writeFileSync(outBase + ext, bin);
  return { file: outBase + ext, cost: pred.pointsCost + ' 积分（余额 ' + pred.accountBalance + '）', seed: img.seed };
}

async function genLiblib(prompt, negative, [w, h], outBase, loraOverride) {
  if (!CONF) throw new Error('找不到 .liblib.json');
  const cfg = JSON.parse(fs.readFileSync(CONF, 'utf8'));
  const payload = {
    templateUuid: cfg.templateUuid,
    generateParams: {
      ...(cfg.checkPointId ? { checkPointId: cfg.checkPointId } : {}),
      prompt: prompt.slice(0, 2000),
      negativePrompt: negative,
      sampler: cfg.sampler, steps: cfg.steps, cfgScale: cfg.cfgScale,
      width: w, height: h, imgCount: 1, randnSource: cfg.randnSource ?? 1, seed: -1,
      restoreFaces: 0,
      ...(has('nolora') ? {} : { additionalNetwork: loraOverride ? [{ modelId: loraOverride, weight: 0.8 }] : cfg.loras }),
    },
  };
  const sub = await liblibApi('/api/generate/webui/text2img', cfg, payload);
  process.stdout.write('  提交 ' + sub.generateUuid + ' 等待中');
  let pred = null;
  for (let i = 0; i < 100; i++) {
    await sleep(3000);
    pred = await liblibApi('/api/generate/webui/status', cfg, { generateUuid: sub.generateUuid });
    process.stdout.write('.');
    if (pred.generateStatus === 5 || [6, 7].includes(pred.generateStatus)) break;
  }
  process.stdout.write('\n');
  if (!pred || pred.generateStatus !== 5) throw new Error('status=' + (pred && pred.generateStatus) + ' msg=' + (pred && pred.generateMsg));
  const img = (pred.images || [])[0];
  if (!img) throw new Error('没有图片返回');
  const bin = Buffer.from(await (await fetch(img.imageUrl)).arrayBuffer());
  const ext = bin[0] === 0x89 && bin[1] === 0x50 ? '.png' : '.jpg';
  fs.writeFileSync(outBase + ext, bin);
  return { file: outBase + ext, cost: pred.pointsCost + ' 积分（余额 ' + pred.accountBalance + '）', seed: img.seed };
}

// ---------------- 主流程 ----------------
function buildPrompt(charKey, setKey, styleKey) {
  const c = CHARS[charKey], s = SETS[setKey];
  if (!c || !s) throw new Error('未知角色或套：' + charKey + '/' + setKey);
  const tail = styleKey === 'xieyi' ? XIEYI : styleKey === 'ink' ? INK : styleKey === 'guofeng' ? GUOFENG
  : styleKey === 'mengchao' ? MENGCHAO : styleKey === 'anime2' ? ANIME2 : ANIME;
  // 场景：只要 body（不含人物装扮/姿势），尾巴单独给
  if (setKey === '场景') {
    const sceneTail = '，中国水墨画，宣纸质感，墨分五色，笔触写意洒脱，冷青灰为基调，大面积留白，画面中没有文字没有印章没有水印没有logo';
    return (c.body + '。' + s.suffix + sceneTail).replace(/\s+/g, '');
  }
  const poseText = setKey === 'Q版' ? c.qpose : (setKey === '头像' ? '微微侧首，神情平静' : c.pose);
  const head = setKey === 'Q版'
    ? '国风武侠角色' + (styleKey === 'ink' ? '水墨' : '') + 'Q版造型，' + c.body + '，' + c.cloth + '，' + poseText
    : c.body + '，' + c.cloth + '，' + poseText;
  return (head + '。' + s.suffix + tail).replace(/\s+/g, '');
}

async function main() {
  let jobs = [];
  if (has('pilot')) {
    jobs = [
      'shaoxia:立绘:glm:anime',
      'shaoxia:立绘:glm:ink',
      'shaoxia:立绘:liblib:ink',
      'shaoxia:Q版:glm:anime',
    ];
  } else if (has('all')) {
    const style = opt('style', 'anime');
    const channel = opt('channel', 'glm');
    for (const c of Object.keys(CHARS)) for (const s of Object.keys(SETS)) jobs.push([c, s, channel, style].join(':'));
  } else {
    jobs = String(opt('jobs', '')).split(',').map((x) => x.trim()).filter(Boolean);
  }
  if (!jobs.length) { console.log('用法见文件头注释（--pilot / --all / --jobs 角色:套:通道:风格）'); return; }

  const dry = has('dry');
  const force = has('force');
  let spent = 0;
  for (const job of jobs) {
    const [charKey, setKey, channel, styleKey] = job.split(':');
    const label = CHARS[charKey]?.cn + ' · ' + setKey + ' · ' + channel + ' · ' + styleKey;
    const prompt = buildPrompt(charKey, setKey, styleKey);
    var negative = SETS[setKey]?.neg ?? NEG_COMMON;
    if (styleKey === 'xieyi') negative = NEG_COMMON + ',二次元,动漫,赛璐璐,彩绘,鲜艳色彩,写实照片,3D渲染,精细描线,眼睛过大,萌系,可爱,水墨之外的颜色';
    else if (charKey === 'qingluan') negative = NEG_FEMALE;
    else if (CHARS[charKey]) negative = NEG_MALE;
    const size = SETS[setKey]?.[channel];
    const dir = path.join(OUT_ROOT, charKey);
    const tag = opt('tag', '');
    const outBase = path.join(dir, charKey + '_' + setKey + '_' + channel + '_' + styleKey + (tag ? '_' + tag : ''));
    console.log('──── ' + label + '  ' + size?.join('x') + ' → ' + path.relative(process.cwd(), outBase));
    if (dry) { console.log('  prompt: ' + prompt + '\n'); continue; }
    fs.mkdirSync(dir, { recursive: true });
    if (fs.existsSync(outBase + '.png') || fs.existsSync(outBase + '.jpg')) {
      if (!force) { console.log('  跳过（已存在，--force 重出）'); continue; }
    }
    try {
      const srcImg = opt('img', '');
      const r = (channel === 'liblib' && srcImg)
        ? await genLiblibImg(prompt, negative, size, outBase, opt('lora', ''), srcImg, parseFloat(opt('denoise', '0.45')))
        : channel === 'liblib'
          ? await genLiblib(prompt, negative, size, outBase, opt('lora', ''))
          : await genGlm(prompt, size, outBase);
      console.log('  ✓ ' + path.basename(r.file) + '  ' + r.cost + (r.seed ? '  seed=' + r.seed : ''));
    } catch (e) { console.log('  ✗ 失败：' + e.message); }
  }
  console.log('\n完成。');
}
main().catch((e) => { console.error(e); process.exit(1); });
