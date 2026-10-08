extends RefCounted
# ============================================================
# data_chase.gd —— 「追剿」（精英爬塔）唯一真源 v1
#
# 用户 2026-10-08 原话（规划稿）："增加精英爬塔【500关解锁】…剧情是公主的部分追杀队
#   已经来到了这村落…也是在点出村之后 那个关卡列表里显示 这个可手动【手牌模式】可自动
#   难度略高 按照五关一boss形成 boss需要富有特色 特性什么的 让玩家可以针对的进行战术
#   【奖励暂时不给 做好再设置】"
# 用户 2026-10-09 追加（本轮）："当前先做500关 每五关一个boss"
#
# 口径（改难度只开这一个文件）：
#   · 解锁 ＝ 爬塔 500 关（UNLOCK_STAGE，看 stage_progress）；
#   · 关数 ＝ 500（STAGE_MAX），**每 5 关一个 boss**（BOSS_EVERY）→ 100 剿 ＝ 100 个 boss；
#   · boss ＝ **25 种性情 × 4 队**（轮次）：第 1~25 剿是第一队的二十五种、第 26~50 剿是第二队……
#     同一队的第二十五剿打完就是下一队；每换一队，招数倍率再抬 ART_BOOST 一档
#     （4 队 × 25 剿 × 5 关 ＝ 500 关 ✓）；
#   · 难度 ＝ 拿塔上**等价关**（第 i 关 ≈ 塔第 OFFSET+i 关）的底子 × HP_MUL/ATK_MUL
#     ——"难度略高"就压在这两个系数上；境界与境界压制跟塔同一把尺（GameState 那边乘）；
#   · 奖励**先留空**：清关只推进度，不给银两/经验/箱子（做好再设置）。
#
# ⚠ 本文件**不许 preload game_state**（game_state 反过来 preload 了它，绕回去就是死循环）。
#   要读玩家状态就由 GameState.chase_enemy_at() 在这一层外面补。
# ============================================================

const Tower := preload("res://shared/tower.gd")
const GameData := preload("res://shared/game_data.gd")
const Cards := preload("res://shared/data_cards.gd")     # v136：赏格要读品级表（QUALITY_ORDER）

const NAME := "追剿"
# v136（用户："设定最高400关"）：500 → **400**。
#   80 剿 ＝ 25 种 boss × 4 队（最后一队只有 5 剿）——队号那套不用改，循环取模就是。
const STAGE_MAX := 400
const BOSS_EVERY := 5            # 每 5 关一个 boss
const UNLOCK_STAGE := 500        # 爬塔到这一关（通关数）才开
const OFFSET := 499              # 追剿第 1 关 ＝ 塔第 500 关的底子（0 起是 499）
# ⚠ v140：下面这两个"相对塔同关"的旧系数**已被难度曲线取代**（见 DIFF_* 那一段）——
#   留着只为"一键回退"：把 enemy_at 里的 `dm` 换回 `HP_MUL` / `ATK_MUL` 就回到 v139 的手感。
const HP_MUL := 1.18             # 【已退休·回退用】杂兵气血（相对塔同关）
const ATK_MUL := 1.12            # 【已退休·回退用】杂兵攻击
#   ⚠ 追剿的 boss 是"五关一个"（塔是二十五关一个），所以这一档**不能照塔的首领加码来**：
#     试算过 1.45 会让 boss 那一组的总血池顶到塔第 500 关首领的 1.6 倍——太硬。
#     1.25 落在"跟塔的首领同档、但每五关就要打一次"的位置上（要松要紧只动这两行）。
const BOSS_HP := 1.25            # boss 再叠一档（相对本关杂兵）
const BOSS_ATK := 1.10
const REALM_DIV := 350           # 境界：与塔同尺（每 350 关一境）
const ELEM_FROM := 301           # v140：第 301 关起敌人带五行（＝旧口径"等价关过 800"那一档）
const SPD_ADD := 2               # 追杀队是轻骑——出手比塔里同关的怪快一点
const ART_BOOST := 0.05          # 每换一队：招数倍率 +5%
const ART_BOOST_CAP := 0.60      # 封顶 +60%（第十队）

# ============================================================
# 特性（traits）—— boss 的"性格"，玩家的"针对点"
#   id 要在 battle_lite 里有对应的兑现（引擎那侧认这几个 id）：
#     summon 召随从 · seal_ult 锁招 · guard_all 列阵 · venom 淬毒 · phase 换招
#   其余"靠词缀吃饭"的 boss 不写 traits，直接把 affixes 摊在敌情里。
# ============================================================
const TRAITS := {
	"summon": {"name": "号令", "desc": "每三手召一名随从补位（最多两名）",
		"counter": "带群伤/横扫——别让它把场子滚起来"},
	"seal_ult": {"name": "锁招", "desc": "每三手锁住我方怒气最高的那个人：两手放不出大招",
		"counter": "带不靠大招的队（普攻/武学流），或者抢先手把它打残"},
	"guard_all": {"name": "列阵", "desc": "每四手给全队上护体：此后两次挨打各减伤近半",
		"counter": "破防（「破防」会把护体撕开）——或者干脆堆无视防御的伤害"},
	"venom": {"name": "淬毒", "desc": "毒可叠到五层，而且毒伤翻倍",
		"counter": "速杀——跟它耗，血是被毒一点点磨没的"},
	"phase": {"name": "换招", "desc": "气血过半当场换一套更凶的招，并立刻放一次大招",
		"counter": "留爆发——半血那一下别把大招先交了"},
}

# ============================================================
# v141：**每个 boss 一个专属被动**（用户："增加 boss追缴有独立大招和被动"）
#
#   25 个 boss 各有一条**只属于它**的被动（大招本来就是各写各的，见 BOSSES[].ult）。
#   被动表是"数据 + 少量钩子"：引擎只认下面这几种键，配出来的花样都在表里：
#     stat    {hp/atk/def/spd: 倍数}   出场时改身板（build）
#     affix   {id, all}                给本体（all=true 连随从）挂一条现成词缀
#     shield  pct                      开局带一层"气血 × pct"的护盾
#     ward    pt                       对自己那一行的元素抗性 +pt
#     rage    倍数                     怒气获取（大招来得更勤）
#     tick    {every, kind, pct}       每 N 手来一次：heal / poison / sealvein / rally / guard
#     on_hit  {heal_pct, rage_cut}     每次命中：回自己血 / 打掉对手怒气
#     low_hp  {pct, atk, heal}         气血低于 pct：攻击 ×atk，并当场回一口（一次）
#     execute pt                       对手气血低于三成时，伤害 +pt
#     immune  [状态id…]                免疫这些负面（控制流对它无效）
#   ⚠ 判类口径：**特性（traits）**是"每几手来一次的大动作"，**被动**是"一直在身上的底子"——
#     两者不冲突，一个 boss 可以既带特性又带被动（现在 14 个带特性、25 个全带被动）。
# ============================================================
const PASSIVES := {
	"p_rage": {"name": "怒气奔腾", "desc": "怒气获取 +60%——大招来得比谁都勤", "counter": "速杀，或用「挫锐」压它的怒气", "rage": 1.6},
	"p_ironwill": {"name": "铁意", "desc": "免疫「震慑」「缴械」「沉默」「封招」——控制对它没用", "counter": "别带控制，带纯输出", "immune": ["stun", "disarm", "silence", "ultseal"]},
	"p_venomaura": {"name": "毒雾", "desc": "每三手给全队上 1 层毒", "counter": "速杀；「清心诀」可洗", "tick": {"every": 3, "kind": "poison"}},
	"p_bulwark": {"name": "铁壁", "desc": "全队带「坚壁」：挨打两成半几率只吃两成", "counter": "破防、多段攻击", "affix": {"id": "bulwark", "all": true}},
	"p_laststand": {"name": "背水", "desc": "气血不足三成：攻击 +50%，并当场回一口血（一次）", "counter": "留爆发，一口气打死", "low_hp": {"pct": 0.30, "atk": 1.5, "heal": 0.12}},
	"p_swift": {"name": "疾风步", "desc": "出手速度 +25%", "counter": "先手压制，或「迟缓」", "stat": {"spd": 1.25}},
	"p_execute": {"name": "处决", "desc": "对手气血不足三成时，伤害 +30%", "counter": "别残血站着——先撤或先治", "execute": 0.30},
	"p_drain": {"name": "摄魂", "desc": "每次命中回自己 4% 气血", "counter": "爆发秒杀，别跟它磨", "on_hit": {"heal_pct": 0.04}},
	"p_thorns": {"name": "荆棘", "desc": "全队带「反伤」：打它的人自己挨一下", "counter": "别硬砍；元素／远程", "affix": {"id": "thorns", "all": true}},
	"p_double": {"name": "双击", "desc": "每第三手追加一记六成力的快招", "counter": "血厚／高闪避", "affix": {"id": "swift"}},
	"p_drum": {"name": "战鼓", "desc": "每三手给全队 +8% 攻（可叠到 +40%）", "counter": "速杀，别让它叠起来", "tick": {"every": 3, "kind": "rally"}},
	"p_breath": {"name": "吐纳", "desc": "每三手回 8% 气血", "counter": "禁疗（封脉）＋高爆发", "tick": {"every": 3, "kind": "heal", "pct": 0.08}},
	"p_hide": {"name": "厚皮", "desc": "常驻：防御 +60%", "counter": "破防、无视防御的伤害", "stat": {"def": 1.6}},
	"p_shield": {"name": "护体罡气", "desc": "开局带一层气血 20% 的护盾", "counter": "先破盾，别急着交爆发", "shield": 0.20},
	"p_siphon": {"name": "吸取", "desc": "每次命中打掉对手 10 点怒气", "counter": "靠普攻与武学，别指望大招", "on_hit": {"rage_cut": 10}},
	"p_sealvein": {"name": "断脉", "desc": "每四手封住最前面那位的经脉（回血只剩三成，2 手）", "counter": "别指望回血，靠闪避／硬抗", "tick": {"every": 4, "kind": "sealvein"}},
	"p_ward": {"name": "五行护体", "desc": "对自己那一行的元素抗性 +40%", "counter": "换一种元素的兵器／功法", "ward": 40},
	"p_fury": {"name": "战意", "desc": "每挨一下，攻击 +8%（最多 +80%）", "counter": "控血／爆发，别给它攒", "affix": {"id": "fury"}},
	"p_poisonbite": {"name": "毒牙", "desc": "击中就上毒：此后每手掉 3% 气血上限（可叠 3 层）", "counter": "速杀；「清心诀」可洗", "affix": {"id": "poison"}},
	"p_ambush": {"name": "偷袭", "desc": "够得到中排往后，且对不是前排的目标伤害 +50%", "counter": "保后排；把肉盾往前推", "affix": {"id": "ambush"}},
	"p_regen": {"name": "生机", "desc": "出手即回气——每两手回 10% 气血上限", "counter": "禁疗（封脉）＋高爆发", "affix": {"id": "regen"}},
	"p_leech": {"name": "吸血", "desc": "每击中一次，自己回气血上限的 6%", "counter": "爆发秒杀，别跟它磨", "affix": {"id": "leech"}},
	"p_berserk": {"name": "狂血", "desc": "气血不到一半，出手重一倍六", "counter": "控血：要么别打残，要么一次打死", "affix": {"id": "berserk"}},
	"p_echo": {"name": "回响", "desc": "每第二手追一记四成力的快招", "counter": "减伤／闪避", "affix": {"id": "echo"}},
	"p_stonewall": {"name": "石壁", "desc": "每三手横练一次：此后两手挨打减伤 30%", "counter": "破防能撕开护体", "tick": {"every": 3, "kind": "guard", "pct": 0.70}},
	"p_order": {"name": "军令如山", "desc": "每四手一声军令：全队护体两手（挨打减伤 45%）", "counter": "破防／等它护体过了再交爆发", "tick": {"every": 4, "kind": "guard_all", "pct": 0.55}},
}

# 哪个 boss 带哪条被动（一格一个，绝不重复——25 个 boss 25 条）
const BOSS_PASSIVE := {
	"zhiling": "p_rage", "suolian": "p_ironwill", "dunu": "p_venomaura", "tiebi": "p_bulwark",
	"qinwei": "p_laststand", "xiuyi": "p_swift", "duanhun": "p_execute", "xuedizi": "p_drain",
	"yinfu": "p_thorns", "tieyao": "p_double", "tiji": "p_drum", "duyao": "p_breath",
	"tielong": "p_hide", "yingwei": "p_shield", "duanren": "p_siphon", "jinjia": "p_ward",
	"chiyan": "p_fury", "hanjiang": "p_poisonbite", "suohun": "p_ambush", "qianji": "p_regen",
	"xueshou": "p_leech", "guimu": "p_berserk", "zongguan": "p_echo", "dudu": "p_stonewall",
	"zhangshi": "p_order",
}

static func passive_of_arch(aid: String) -> String:
	return str(BOSS_PASSIVE.get(aid, ""))

static func passive_def(pid: String) -> Dictionary:
	return PASSIVES.get(pid, {})

# 某一关 boss 的被动 id（杂兵关返回空串）
static func passive_of(i: int) -> String:
	if not is_boss(i):
		return ""
	return passive_of_arch(str(arch_of(i).get("id", "")))

# 一行字（敌情/面板/战报用）
static func passive_line(i: int) -> String:
	var d: Dictionary = passive_def(passive_of(i))
	if d.is_empty():
		return ""
	return "被动「" + str(d.get("name", "")) + "」" + str(d.get("desc", "")) + "　　针对：" + str(d.get("counter", ""))

# ============================================================
# boss 性情表（**二十五种**，循环用：25 种 × 4 队）
#   hp/atk ＝ 相对本关 boss 基准的偏科（**乘积尽量压在 1.0 附近**，难度不动、性格动）
#   arts/ult ＝ 这一门 boss 的成名招（形状与塔那边同一套：kind/ target/ mult/ cd/ apply）
#   phase_arts/phase_ult ＝ 只有「换招」那一门用（半血之后换这套）
# ============================================================
const BOSSES := [
	{
		"id": "zhiling", "name": "执令官", "weapon": "spear", "hp": 1.05, "atk": 0.95,
		"color": [0.44, 0.30, 0.24], "scale": 1.08, "traits": ["summon"], "affixes": ["rally"],
		"tag": "召随从滚雪球",
		"arts": [
			{"name": "点将", "kind": "heal", "heal_pct": 0.08, "cd": 4, "desc": "点一名副手补位——顺带回一口气"},
			{"name": "军令如山", "target": "mid", "kind": "damage", "mult": 1.10, "cd": 3,
				"apply": {"id": "weak", "turns": 2, "stacks": 1}, "desc": "一声令下压过来，中者「虚弱」两手"},
		],
		"ult": {"name": "合围令", "target": "sweep", "mult": 1.55, "desc": "号旗一展，四面合围"},
	},
	{
		"id": "suolian", "name": "锁链校尉", "weapon": "dual", "hp": 1.08, "atk": 0.94,
		"color": [0.36, 0.34, 0.40], "scale": 1.06, "traits": ["seal_ult"], "affixes": ["lockchain"],
		"tag": "封大招",
		"arts": [
			{"name": "锁链缠身", "target": "front", "kind": "damage", "mult": 1.05, "cd": 3,
				"apply": {"id": "disarm", "turns": 2, "stacks": 1}, "desc": "铁链一绕，中者「缴械」两手"},
			{"name": "封招链", "target": "mid", "kind": "damage", "mult": 1.02, "cd": 4,
				"apply": {"id": "ultseal", "turns": 2, "stacks": 1}, "desc": "链条锁住气门——「封招」两手，大招放不出来"},
		],
		"ult": {"name": "千链锁天", "target": "sweep", "mult": 1.45,
			"apply": {"id": "ultseal", "turns": 2, "stacks": 1}, "desc": "漫天铁链罩下来，全场「封招」"},
	},
	{
		"id": "dunu", "name": "毒弩手", "weapon": "anqi", "hp": 0.88, "atk": 1.12,
		"color": [0.34, 0.44, 0.30], "scale": 1.00, "traits": ["venom"], "affixes": ["poison", "swift"],
		"tag": "叠毒（怕速杀）",
		"arts": [
			{"name": "淬毒连弩", "target": "front", "kind": "dash", "mult": 0.95, "follow": 0.55, "cd": 3,
				"desc": "机簧连响——两段都是淬过毒的"},
			{"name": "毒烟弥散", "target": "sweep", "kind": "damage", "mult": 0.85, "cd": 4,
				"apply": {"id": "weak", "turns": 3, "stacks": 1}, "desc": "毒烟罩场，全场「虚弱」三手"},
		],
		"ult": {"name": "万弩穿心", "target": "sweep", "mult": 1.60, "desc": "一匣弩矢全泼出来"},
	},
	{
		"id": "tiebi", "name": "铁壁旗手", "weapon": "spear", "hp": 1.28, "atk": 0.80,
		"color": [0.40, 0.38, 0.34], "scale": 1.12, "traits": ["guard_all"], "affixes": ["bulwark"],
		"tag": "全员加防（要破防）",
		"arts": [
			{"name": "铁壁阵", "kind": "guard", "turns": 2, "cut": 0.68, "cd": 4, "desc": "大旗一插，全队横练"},
			{"name": "旗杆横扫", "target": "front", "kind": "damage", "mult": 1.15, "cd": 3, "desc": "旗杆当棍使——横扫当面的人"},
		],
		"ult": {"name": "旗开得胜", "target": "sweep", "mult": 1.50,
			"apply": {"id": "sunder", "turns": 3, "stacks": 1}, "desc": "旗风卷过，全场「破防」——它也怕这一手"},
	},
	{
		"id": "qinwei", "name": "公主亲卫", "weapon": "dual", "hp": 1.00, "atk": 1.05,
		"color": [0.56, 0.26, 0.30], "scale": 1.10, "traits": ["phase"], "affixes": ["fury"],
		"tag": "半血换招（留爆发）",
		"arts": [
			{"name": "卫主斩", "target": "front", "kind": "damage", "mult": 1.18, "cd": 3, "desc": "护主的一刀——又直又沉"},
			{"name": "回刃", "kind": "charge", "mult": 1.35, "cd": 4, "desc": "退半步蓄势——下一手更重"},
		],
		"ult": {"name": "亲卫一出", "target": "sweep", "mult": 1.65, "desc": "亲卫出手，不留余地"},
		"phase_arts": [
			{"name": "血刃连斩", "target": "mid", "kind": "dash", "mult": 1.10, "follow": 0.80, "cd": 2,
				"desc": "见了血就不收手——两段连斩"},
			{"name": "困兽反噬", "kind": "charge", "mult": 1.50, "cd": 3, "desc": "伤重反而更凶"},
		],
		"phase_ult": {"name": "玉碎", "target": "sweep", "mult": 1.95,
			"apply": {"id": "sunder", "turns": 3, "stacks": 1}, "desc": "宁可玉碎——全场重击并「破防」"},
	},
	{
		"id": "xiuyi", "name": "绣衣使", "weapon": "dagger", "hp": 0.92, "atk": 1.10,
		"color": [0.46, 0.28, 0.42], "scale": 1.00, "traits": [], "affixes": ["ambush", "acuity"],
		"tag": "绕前排 · 点窍",
		"arts": [
			{"name": "绣针入穴", "target": "back", "kind": "damage", "mult": 1.10, "cd": 3,
				"apply": {"id": "nopassive", "turns": 3, "stacks": 1}, "desc": "专挑后排下手——中者「闭窍」三手"},
			{"name": "影步", "kind": "charge", "mult": 1.30, "cd": 4, "desc": "人影一晃——下一手更重"},
		],
		"ult": {"name": "绣衣夜行", "target": "back", "mult": 1.70, "desc": "灯下无人——最靠后的那个最危险"},
	},
	{
		"id": "duanhun", "name": "断魂弩阵", "weapon": "anqi", "hp": 0.95, "atk": 1.08,
		"color": [0.30, 0.34, 0.44], "scale": 1.04, "traits": [], "affixes": ["pierce", "cutoff", "echo"],
		"tag": "破前截后 · 专打后排",
		"arts": [
			{"name": "穿云箭", "target": "back", "kind": "damage", "mult": 1.15, "cd": 3, "desc": "箭走直线——越过前排"},
			{"name": "乱箭齐发", "target": "sweep", "kind": "damage", "mult": 0.92, "cd": 4, "desc": "弩阵齐射，全场落箭"},
		],
		"ult": {"name": "断魂一矢", "target": "back", "mult": 1.85,
			"apply": {"id": "healseal", "turns": 2, "stacks": 1}, "desc": "一矢封脉——最靠后的人挨最重的一下"},
	},
	{
		"id": "xuedizi", "name": "血滴子", "weapon": "dual", "hp": 0.90, "atk": 1.14,
		"color": [0.52, 0.22, 0.24], "scale": 1.02, "traits": [], "affixes": ["leech", "berserk"],
		"tag": "吸血 · 残血狂暴",
		"arts": [
			{"name": "血滴取首", "target": "front", "kind": "damage", "mult": 1.20, "cd": 3, "desc": "一顶血滴子罩下来"},
			{"name": "饮血", "kind": "heal", "heal_pct": 0.12, "cd": 4, "desc": "吸一口血再打——回气一成有余"},
		],
		"ult": {"name": "血雨", "target": "sweep", "mult": 1.55, "desc": "血滴子满场飞——每一顶都要人命"},
	},
	{
		"id": "yinfu", "name": "阴符司", "weapon": "fist", "hp": 1.10, "atk": 0.92,
		"color": [0.34, 0.30, 0.36], "scale": 1.02, "traits": [], "affixes": ["thorns", "regen", "bomb"],
		"tag": "反伤 · 回气 · 死时自爆",
		"arts": [
			{"name": "阴符咒", "target": "front", "kind": "damage", "mult": 1.05, "cd": 3,
				"apply": {"id": "burn", "turns": 3, "stacks": 1}, "desc": "符纸自燃——中者「燃烧」三手"},
			{"name": "龟息", "kind": "heal", "heal_pct": 0.16, "cd": 4, "desc": "缩进符阵里缓一口气"},
		],
		"ult": {"name": "阴雷", "target": "sweep", "mult": 1.60, "desc": "符阵一炸——阴雷罩全场"},
	},
	{
		"id": "tieyao", "name": "铁鹞子", "weapon": "spear", "hp": 0.96, "atk": 1.06,
		"color": [0.38, 0.36, 0.30], "scale": 1.06, "traits": [], "affixes": ["fury", "swift", "bulwark"],
		"tag": "越打越凶 · 速攻",
		"arts": [
			{"name": "鹞子翻身", "target": "mid", "kind": "dash", "mult": 1.00, "follow": 0.70, "cd": 3, "desc": "翻身上扑——两段快招"},
			{"name": "铁翼横扫", "target": "sweep", "kind": "damage", "mult": 0.95, "cd": 4, "desc": "铁翼张开，横扫一片"},
		],
		"ult": {"name": "鹰击长空", "target": "sweep", "mult": 1.62, "desc": "从高处砸下来——躲无可躲"},
	},
	# ============================================================
	# v135：boss 从 10 种扩到 **25 种**（用户："boss种类最好设置25种"）
	#   500 关 ÷ 5 ＝ 100 剿 ＝ 25 种 × **4 队**（每队 25 剿 ＝ 125 关）：第 1~25 剿第一队、
	#   第 26~50 剿第二队……每换一队招数倍率 +5%（ART_BOOST，封顶 4 队＝+15%）。
	#   ⚠ 新加的这 15 种**不写新机制**——用的是已有的五条引擎特性（号令/锁招/列阵/淬毒/换招）
	#     ＋ 25 条词缀的现成组合，所以"性格各不同、引擎一个字没动"。
	#   每一条都留了针对点（tag 那一列就是"该怎么打"）。
	# ============================================================
	{
		"id": "tiji", "name": "缇骑都尉", "weapon": "spear", "hp": 1.02, "atk": 1.00,
		"color": [0.40, 0.30, 0.34], "scale": 1.06, "traits": ["summon"], "affixes": ["fury", "swift"],
		"tag": "越打越多 · 越打越快",
		"arts": [
			{"name": "缇骑冲阵", "target": "mid", "kind": "dash", "mult": 1.00, "follow": 0.60, "cd": 3, "desc": "马踏连营——两段冲撞"},
			{"name": "马踏连营", "target": "sweep", "kind": "damage", "mult": 0.95, "cd": 4, "desc": "铁蹄扫过，人人挨一下"},
		],
		"ult": {"name": "铁骑合围", "target": "sweep", "mult": 1.55, "desc": "四面包上来——跑不掉"},
	},
	{
		"id": "duyao", "name": "毒手药王", "weapon": "anqi", "hp": 1.10, "atk": 0.92,
		"color": [0.32, 0.42, 0.32], "scale": 1.02, "traits": ["venom"], "affixes": ["regen", "poison"],
		"tag": "毒＋自愈（要速杀＋禁疗）",
		"arts": [
			{"name": "五毒烟", "target": "sweep", "kind": "damage", "mult": 0.85, "cd": 4,
				"apply": {"id": "weak", "turns": 3, "stacks": 1}, "desc": "毒烟罩场——全场「虚弱」三手"},
			{"name": "药王续命", "kind": "heal", "heal_pct": 0.18, "cd": 5, "desc": "一把丹药咽下去，回血近两成"},
		],
		"ult": {"name": "万毒归元", "target": "sweep", "mult": 1.45,
			"apply": {"id": "weak", "turns": 2, "stacks": 2}, "desc": "毒气回卷——全场虚弱更重"},
	},
	{
		"id": "tielong", "name": "铁笼力士", "weapon": "dual", "hp": 1.30, "atk": 0.78,
		"color": [0.44, 0.40, 0.34], "scale": 1.16, "traits": ["guard_all"], "affixes": ["thorns", "bulwark"],
		"tag": "护体＋反伤（破防／别硬砍）",
		"arts": [
			{"name": "铁笼锁", "target": "front", "kind": "damage", "mult": 1.10, "cd": 3,
				"apply": {"id": "disarm", "turns": 2, "stacks": 1}, "desc": "铁链锁腕——中者「缴械」两手"},
			{"name": "横练", "kind": "guard", "turns": 2, "cut": 0.70, "cd": 4, "desc": "运气横练——两下重击也啃不动"},
		],
		"ult": {"name": "笼中困兽", "target": "sweep", "mult": 1.45, "desc": "困兽反扑——笼子都晃"},
	},
	{
		"id": "yingwei", "name": "影卫统领", "weapon": "dagger", "hp": 0.92, "atk": 1.12,
		"color": [0.34, 0.30, 0.42], "scale": 1.00, "traits": ["summon"], "affixes": ["ambush", "acuity"],
		"tag": "召影卫 · 绕前排点窍",
		"arts": [
			{"name": "缄口令", "target": "back", "kind": "damage", "mult": 1.05, "cd": 3,
				"apply": {"id": "silence", "turns": 2, "stacks": 1}, "desc": "专挑后排——中者「沉默」两手"},
			{"name": "影步", "kind": "charge", "mult": 1.30, "cd": 4, "desc": "人影一晃——下一手更重"},
		],
		"ult": {"name": "影卫夜袭", "target": "back", "mult": 1.80, "desc": "灯灭的一瞬——最靠后的那个最危险"},
	},
	{
		"id": "duanren", "name": "断刃死士", "weapon": "dagger", "hp": 0.86, "atk": 1.16,
		"color": [0.46, 0.32, 0.28], "scale": 0.98, "traits": [], "affixes": ["bomb", "berserk"],
		"tag": "自爆＋残血狂暴（控血）",
		"arts": [
			{"name": "同归", "target": "front", "kind": "damage", "mult": 1.25, "cd": 3, "desc": "不要命的一记直刺"},
			{"name": "断刃反扑", "kind": "charge", "mult": 1.40, "cd": 4, "desc": "半截刀也能杀人——下一手更重"},
		],
		"ult": {"name": "玉石俱焚", "target": "sweep", "mult": 1.70, "desc": "抱着你一起炸"},
	},
	{
		"id": "jinjia", "name": "金甲校尉", "weapon": "sword", "hp": 1.12, "atk": 0.90,
		"color": [0.52, 0.46, 0.30], "scale": 1.08, "traits": [], "affixes": ["bulwark", "metalcut"],
		"tag": "硬挡＋裂金（破防／换通道）",
		"arts": [
			{"name": "金甲撞", "target": "front", "kind": "damage", "mult": 1.15, "cd": 3, "desc": "整身甲撞过来——又沉又硬"},
			{"name": "裂金斩", "target": "mid", "kind": "damage", "mult": 1.05, "cd": 4,
				"apply": {"id": "sunder", "turns": 3, "stacks": 1}, "desc": "金气入体——中者「破防」三手"},
		],
		"ult": {"name": "金甲碎岳", "target": "sweep", "mult": 1.50, "desc": "连人带甲砸下来"},
	},
	{
		"id": "chiyan", "name": "赤焰刀客", "weapon": "dual", "hp": 0.94, "atk": 1.08,
		"color": [0.66, 0.30, 0.20], "scale": 1.02, "traits": [], "affixes": ["flame", "fury"],
		"tag": "燃烧＋越打越凶（水／速杀）",
		"arts": [
			{"name": "烈焰三连", "target": "front", "kind": "dash", "mult": 0.90, "follow": 0.50, "cd": 3,
				"apply": {"id": "burn", "turns": 2, "stacks": 1}, "desc": "刀刀带火——两段并上火种"},
			{"name": "炽风", "kind": "charge", "mult": 1.35, "cd": 4, "desc": "刀风一热——下一手更重"},
		],
		"ult": {"name": "燎原火", "target": "sweep", "mult": 1.60,
			"apply": {"id": "burn", "turns": 2, "stacks": 2}, "desc": "火势漫开——全场烧两层"},
	},
	{
		"id": "hanjiang", "name": "寒江剑侍", "weapon": "sword", "hp": 0.96, "atk": 1.06,
		"color": [0.30, 0.42, 0.56], "scale": 1.02, "traits": [], "affixes": ["coldwater", "echo"],
		"tag": "水浸＋回响（火／速杀）",
		"arts": [
			{"name": "寒江截浪", "target": "mid", "kind": "damage", "mult": 1.10, "cd": 3,
				"apply": {"id": "soak", "turns": 3, "stacks": 1}, "desc": "剑走寒江——中者「水浸」三手"},
			{"name": "凝霜", "kind": "guard", "turns": 2, "cut": 0.78, "cd": 4, "desc": "剑身凝霜——挡得住两下"},
		],
		"ult": {"name": "寒江倒卷", "target": "sweep", "mult": 1.55,
			"apply": {"id": "soak", "turns": 2, "stacks": 2}, "desc": "江水倒卷——全场湿透"},
	},
	{
		"id": "suohun", "name": "锁魂判官", "weapon": "spear", "hp": 1.04, "atk": 0.98,
		"color": [0.36, 0.32, 0.44], "scale": 1.04, "traits": ["seal_ult"], "affixes": ["choke", "stagnant"],
		"tag": "封招＋沉默＋滞涩（普攻流）",
		"arts": [
			{"name": "判官笔", "target": "front", "kind": "damage", "mult": 1.05, "cd": 3,
				"apply": {"id": "silence", "turns": 2, "stacks": 1}, "desc": "笔点哑穴——「沉默」两手"},
			{"name": "滞脉针", "target": "mid", "kind": "damage", "mult": 1.00, "cd": 4,
				"apply": {"id": "cdslow", "turns": 3, "stacks": 1}, "desc": "细针入脉——技能冷却 +2 手"},
		],
		"ult": {"name": "锁魂令", "target": "sweep", "mult": 1.50,
			"apply": {"id": "ultseal", "turns": 2, "stacks": 1}, "desc": "令牌一落——全场大招被封"},
	},
	{
		"id": "qianji", "name": "千机巧匠", "weapon": "anqi", "hp": 0.90, "atk": 1.10,
		"color": [0.42, 0.38, 0.46], "scale": 1.00, "traits": [], "affixes": ["pierce", "ambush", "swift"],
		"tag": "绕前排＋连发（保后排／先手）",
		"arts": [
			{"name": "千机弩", "target": "back", "kind": "damage", "mult": 1.05, "cd": 3, "desc": "机簧一响——越过前排取后排"},
			{"name": "连环匣", "target": "sweep", "kind": "damage", "mult": 0.90, "cd": 4, "desc": "一匣全泼出去"},
		],
		"ult": {"name": "万箭穿心", "target": "back", "mult": 1.80, "desc": "对准最靠后的那个——一箭到底"},
	},
	{
		"id": "xueshou", "name": "血手屠夫", "weapon": "dual", "hp": 0.88, "atk": 1.14,
		"color": [0.56, 0.24, 0.24], "scale": 1.04, "traits": [], "affixes": ["leech", "berserk", "fury"],
		"tag": "吸血＋狂暴＋战意（爆发秒杀）",
		"arts": [
			{"name": "开膛", "target": "front", "kind": "damage", "mult": 1.20, "cd": 3, "desc": "一记开膛手——又直又狠"},
			{"name": "啖血", "kind": "heal", "heal_pct": 0.12, "cd": 5, "desc": "舔一口血再上——回气一成"},
		],
		"ult": {"name": "血手漫天", "target": "sweep", "mult": 1.60, "desc": "满手血——每一巴掌都要命"},
	},
	{
		"id": "guimu", "name": "阴山鬼母", "weapon": "fist", "hp": 1.06, "atk": 0.96,
		"color": [0.38, 0.28, 0.40], "scale": 1.06, "traits": ["venom"], "affixes": ["bomb", "poison"],
		"tag": "淬毒＋死时自爆（速杀＋群伤）",
		"arts": [
			{"name": "鬼爪", "target": "front", "kind": "damage", "mult": 1.10, "cd": 3,
				"apply": {"id": "weak", "turns": 3, "stacks": 1}, "desc": "枯爪一带——中者「虚弱」三手"},
			{"name": "阴风", "target": "sweep", "kind": "damage", "mult": 0.90, "cd": 4, "desc": "阴风过处，人人发寒"},
		],
		"ult": {"name": "鬼母唤阴", "target": "sweep", "mult": 1.55,
			"apply": {"id": "weak", "turns": 2, "stacks": 2}, "desc": "阴气漫上来——全场虚弱两层"},
	},
	{
		"id": "zongguan", "name": "铁壁总管", "weapon": "spear", "hp": 1.22, "atk": 0.84,
		"color": [0.42, 0.40, 0.36], "scale": 1.12, "traits": ["guard_all"], "affixes": ["regen", "sealvein"],
		"tag": "护体＋回春＋封脉（破防＋禁疗）",
		"arts": [
			{"name": "铁壁令", "kind": "guard", "turns": 3, "cut": 0.72, "cd": 5, "desc": "令旗一立——三下重击也啃不动"},
			{"name": "镇堂棍", "target": "front", "kind": "damage", "mult": 1.10, "cd": 3,
				"apply": {"id": "healseal", "turns": 2, "stacks": 1}, "desc": "一棍点脉——中者回血只剩三成"},
		],
		"ult": {"name": "铁壁镇山", "target": "sweep", "mult": 1.45, "desc": "整座堂压下来"},
	},
	{
		"id": "dudu", "name": "绣衣都督", "weapon": "dagger", "hp": 0.95, "atk": 1.08,
		"color": [0.48, 0.28, 0.44], "scale": 1.02, "traits": [], "affixes": ["acuity", "choke", "stagnant"],
		"tag": "闭窍＋锁喉＋滞涩（别只靠被动）",
		"arts": [
			{"name": "绣衣点穴", "target": "front", "kind": "damage", "mult": 1.00, "cd": 4,
				"apply": {"id": "nopassive", "turns": 3, "stacks": 1}, "desc": "点在窍上——「闭窍」三手：自带/被动/星全失效"},
			{"name": "密令", "target": "mid", "kind": "damage", "mult": 1.05, "cd": 3,
				"apply": {"id": "silence", "turns": 2, "stacks": 1}, "desc": "一纸密令——中者「沉默」两手"},
		],
		"ult": {"name": "绣衣夜行", "target": "sweep", "mult": 1.50,
			"apply": {"id": "silence", "turns": 2, "stacks": 1}, "desc": "衣影过处——全场哑火"},
	},
	{
		"id": "zhangshi", "name": "公主座下·长史", "weapon": "sword", "hp": 1.00, "atk": 1.04,
		"color": [0.58, 0.30, 0.34], "scale": 1.08, "traits": ["phase", "summon"], "affixes": ["rally"],
		"tag": "换招＋号令（留爆发＋群伤）",
		"arts": [
			{"name": "长史令", "target": "mid", "kind": "damage", "mult": 1.08, "cd": 3,
				"apply": {"id": "ragecut", "turns": 3, "stacks": 1}, "desc": "令到气散——当场挫锐并压制怒气"},
			{"name": "点将", "kind": "heal", "heal_pct": 0.08, "cd": 4, "desc": "点一名副手补位——顺带回气"},
		],
		"ult": {"name": "公主府令", "target": "sweep", "mult": 1.60, "desc": "府令既出——追杀队倾巢而动"},
		"phase_arts": [
			{"name": "血书急令", "target": "front", "kind": "dash", "mult": 1.15, "follow": 0.70, "cd": 2, "desc": "写下血书——两段连斩"},
			{"name": "困兽犹斗", "kind": "charge", "mult": 1.50, "cd": 3, "desc": "退无可退——下一手更重"},
		],
		"phase_ult": {"name": "鱼死网破", "target": "sweep", "mult": 1.90,
			"apply": {"id": "sunder", "turns": 3, "stacks": 1}, "desc": "网破鱼死——全场重击并「破防」"},
	},
]

# ---- 杂兵名（一轮五关里的前四关；按"剿号"循环用）----
const MOB_ROWS := [
	["追杀队探马", "追杀队刀手", "追杀队弩手", "追杀队死士"],
	["绣衣探子", "绣衣刀客", "绣衣弩手", "绣衣死士"],
	["黑甲游骑", "黑甲刀卫", "黑甲弩卫", "黑甲铁奴"],
	["内廷缇骑", "内廷刀手", "内廷弩卫", "内廷力士"],
	["公主府鹰犬", "公主府刀卫", "公主府弩卫", "公主府死士"],
]
const MOB_WEAPON := ["dual", "dual", "anqi", "spear"]
const MOB_COLOR := [[0.40, 0.32, 0.30], [0.36, 0.34, 0.38], [0.32, 0.38, 0.34], [0.38, 0.30, 0.28]]

# ---- 队号（每十剿一队）----
const CYCLE_CN := ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

# ============================================================
# v136：**追剿的赏格**（用户："追剿给宝箱和大量银两【也不要太多】和大量经验【也不要太多】
#   boss关给一本完整功法或者武器装备 每80关提升一个档次 最高极品"）
#
#   口径：
#     · **每清一关**：银两 ＋ 经验 ＋ 一个宝箱（箱子档位跟赏格档走）；
#     · **每 80 关升一档**：1~80 凡品 · 81~160 良品 · 161~240 上品 · 241~400 极品
#       （**最高极品**——绝品不在追剿里发）；
#     · **boss 关（每 5 关）**：再加**一件完整的东西**（功法 / 兵器 / 装备，三选一，整件不是残页）；
#     · 量级（"大量但不要太多"）：银两 100/关起、每档 +50；经验 400/关起、每档 +200。
#       全程 400 关合计 ≈ **银两 7.6 万两、经验 30.4 万点、400 个箱子、80 件整品**
#       （约合一次满突破的五分之一）——
#       是"一趟大活"的量级，不至于把爬塔/游历那条线挤掉。要松要紧只动下面六个常数。
# ============================================================
const REWARD_STEP := 80          # 每多少关升一档
const REWARD_MAX_Q := 3          # 最高档（下标 3 ＝ 极品）
const RW_SILVER := 100           # 清关银两基础
const RW_SILVER_STEP := 50       # 每升一档多给
const RW_EXP := 400              # 清关经验基础
const RW_EXP_STEP := 200         # 每升一档多给
const RW_CHEST := ["wood", "iron", "gold", "jade"]              # 清关的箱子（对齐四档赏格）
const RW_BOSS_CHEST := ["iron", "gold", "jade", "dragon"]       # boss 关的箱子：升一档（封顶龙箱）
# v139（用户："追缴关大幅提升玉以及玉以下宝箱爆率"）：**每关给 2 个箱子**（原来 1 个）——
#   追剿成了"玉及以下箱子"的主力来路（塔那边玉箱刚被砍了六成）。
#   boss 关仍是"1 个升一档（银/金/玉/龙）＋ 1 个同档"，所以**龙箱每剿最多一个**、只在 boss 关出。
const RW_CHEST_N := 2

static func reward_q(i: int) -> int:
	return mini(int(clampi(i, 0, STAGE_MAX - 1) / REWARD_STEP), REWARD_MAX_Q)

static func reward_q_cn(i: int) -> String:
	return str(Cards.QUALITY_ORDER[clampi(reward_q(i), 0, Cards.QUALITY_ORDER.size() - 1)])

static func reward_silver(i: int) -> int:
	return RW_SILVER + reward_q(i) * RW_SILVER_STEP

static func reward_exp(i: int) -> int:
	return RW_EXP + reward_q(i) * RW_EXP_STEP

# 这一关的"主箱"（boss 关＝升一档那个）；要看**全部**箱子用 reward_chests()
static func reward_chest(i: int) -> String:
	var q := reward_q(i)
	if is_boss(i):
		return str(RW_BOSS_CHEST[clampi(q, 0, RW_BOSS_CHEST.size() - 1)])
	return str(RW_CHEST[clampi(q, 0, RW_CHEST.size() - 1)])

# 这一关**一共给哪几个箱子**（v139：每关 2 个；boss 关＝升一档 ＋ 同档各一个）
static func reward_chests(i: int) -> Array:
	var out: Array = []
	var q := reward_q(i)
	var base := str(RW_CHEST[clampi(q, 0, RW_CHEST.size() - 1)])
	if is_boss(i):
		out.append(str(RW_BOSS_CHEST[clampi(q, 0, RW_BOSS_CHEST.size() - 1)]))
		out.append(base)
	else:
		for k in RW_CHEST_N:
			out.append(base)
	return out

# "玉箱 ×2" / "龙箱 ×1、玉箱 ×1"——播报用的一小行
static func chest_summary(chests: Array) -> String:
	var cnt: Dictionary = {}
	for c_v in chests:
		var c := str(c_v)
		cnt[c] = int(cnt.get(c, 0)) + 1
	var seg: Array = []
	for c2 in cnt.keys():
		seg.append(Tower.chest_name(str(c2)) + " ×" + str(int(cnt[c2])))
	return "、".join(PackedStringArray(seg))

# boss 关那一件**整件**：功法 / 兵器 / 装备三选一（品质＝当前档；专武不进池）
#   非 boss 关返回空串。
static func reward_item(i: int) -> String:
	if not is_boss(i):
		return ""
	var q := reward_q(i)
	var kinds := ["arts", "weapon", "gear"]
	var kind := str(kinds[randi() % kinds.size()])
	var pool: Array = Tower.chest_card_pool(kind, q)
	if pool.is_empty():
		return ""
	return str(pool[randi() % pool.size()])

# 一行预览（出村面板 / 战斗抬头用）
static func reward_line(i: int) -> String:
	var s := "银两+" + str(reward_silver(i)) + " · 经验+" + str(reward_exp(i)) + " · " + chest_summary(reward_chests(i))
	if is_boss(i):
		s += " · 整件" + reward_q_cn(i) + "（功法/兵器/装备）"
	return s

# 当前这一档的说明（面板上那行小字）
static func tier_line(i: int) -> String:
	return reward_q_cn(i) + "档（第 " + str(reward_q(i) * REWARD_STEP + 1) + "~" + str(mini((reward_q(i) + 1) * REWARD_STEP, STAGE_MAX)) + " 关）"

# ============================================================
# 关卡号 ↔ 剿号
# ============================================================
static func rounds() -> int:
	return STAGE_MAX / BOSS_EVERY

# ============================================================
# v140：**难度曲线**（用户："追缴整体难度按照500关开始 每25关上浮整体25%
#   同时每一档提升50% 前80关难度降低50%"）
#
#   口径（三段相乘，全部复利）：
#     基准  ＝ **塔第 500 关**的杂兵身板（固定不动——不再像 v139 那样"跟着等价关往后爬"）
#     ① 每 **25 关 ×1.25**：t＝第几段（关号÷25 取整）→ 1.25^t
#     ② 每 **80 关（一档）×1.5**：档＝关号÷80 取整（0~4 共五档）→ 1.5^档
#     ③ **前 80 关 ×0.5**（第一档整体减半）
#   于是（相对"塔第 500 关的杂兵"）：
#     第 1 关 **0.50×** · 第 50 关 0.78× · 第 80 关 0.98× ｜ 第 81 关 **2.93×**（跨档那一下）
#     第 160 关 8.6× · 第 240 关 25× · 第 320 关 74× · 第 400 关 **144×**
#   （对照：塔自己从 500 爬到 900 关只涨约 16× —— 追剿这条线陡得多，是"精英梯"。）
#   ⚠ 改曲线只动下面四个常数；`diff_line(i)` 是面板/探针用的那一行字。
# ============================================================
const DIFF_BASE_STAGE := 499     # 基准＝塔第 500 关（0 起 499）
const DIFF_STEP := 25            # 每多少关抬一次
const DIFF_STEP_MUL := 1.25      # 每次抬多少（整体）
const DIFF_BAND := 80            # 每多少关算"一档"
const DIFF_BAND_MUL := 1.5       # 每档再乘多少
const DIFF_EARLY := 80           # 前多少关享受减负
const DIFF_EARLY_MUL := 0.5      # 减负系数（0.5 ＝ 难度减半）

static func diff_mul(i: int) -> float:
	var ti := clampi(i, 0, STAGE_MAX - 1)
	var m := pow(DIFF_STEP_MUL, float(ti / DIFF_STEP))
	m *= pow(DIFF_BAND_MUL, float(ti / DIFF_BAND))
	if ti < DIFF_EARLY:
		m *= DIFF_EARLY_MUL
	return m

static func diff_band(i: int) -> int:
	return clampi(i, 0, STAGE_MAX - 1) / DIFF_BAND

static func diff_line(i: int) -> String:
	return "难度 ×" + str(snappedf(diff_mul(i), 0.01)) + "（基准＝塔第 500 关 · 第 " + str(diff_band(i) + 1) + " 档）"

static func is_boss(i: int) -> bool:
	return ((clampi(i, 0, STAGE_MAX - 1) + 1) % BOSS_EVERY) == 0

static func round_of(i: int) -> int:
	return clampi(i, 0, STAGE_MAX - 1) / BOSS_EVERY + 1

static func stage_of_round(r: int) -> int:
	return (clampi(r, 1, rounds()) - 1) * BOSS_EVERY

static func wave_in_round(i: int) -> int:
	return clampi(i, 0, STAGE_MAX - 1) % BOSS_EVERY + 1     # 1..5（5 ＝ boss 关）

static func cycle_of(i: int) -> int:
	return (round_of(i) - 1) / BOSSES.size() + 1

static func arch_of(i: int) -> Dictionary:
	return BOSSES[(round_of(i) - 1) % BOSSES.size()]

static func cycle_cn(i: int) -> String:
	return str(CYCLE_CN[clampi(cycle_of(i) - 1, 0, CYCLE_CN.size() - 1)])

static func boss_name(i: int) -> String:
	return "第" + cycle_cn(i) + "队·" + str(arch_of(i).get("name", "?"))

static func mob_name(i: int) -> String:
	var pos := clampi(i, 0, STAGE_MAX - 1) % BOSS_EVERY
	var names: Array = MOB_ROWS[(round_of(i) - 1) % MOB_ROWS.size()]
	return str(names[clampi(pos, 0, names.size() - 1)])

static func chapter_of(i: int) -> String:
	return "公主府追杀队·第" + str(round_of(i)) + "剿"

static func enemy_name(i: int) -> String:
	return boss_name(i) if is_boss(i) else mob_name(i)

# ============================================================
# 敌人（真数值）
#   底子从 Tower.enemy_at 的**等价关**取——塔那边调难度，追剿跟着一起动；
#   塔的首领/精英加码先除掉（追剿自己定 boss，不叠两次）。
# ============================================================
static func _unmul(t: Dictionary) -> Array:
	var hp := float(t.get("hp", 1.0))
	var atk := float(t.get("atk", 1.0))
	if bool(t.get("boss", false)):
		hp /= Tower.HP_BOSS
		atk /= Tower.ATK_BOSS
	if bool(t.get("elite", false)):
		hp /= Tower.HP_ELITE
		atk /= Tower.ATK_ELITE
	return [hp, atk]

static func _scaled_arts(arts: Array, boost: float) -> Array:
	var out: Array = []
	for a_v in arts:
		var a: Dictionary = (a_v as Dictionary).duplicate(true)
		if a.has("mult"):
			a["mult"] = snappedf(float(a["mult"]) * boost, 0.01)
		if a.has("follow"):
			a["follow"] = snappedf(float(a["follow"]) * boost, 0.01)
		out.append(a)
	return out

static func _scaled_ult(u: Dictionary, boost: float) -> Dictionary:
	var out: Dictionary = u.duplicate(true)
	if out.has("mult"):
		out["mult"] = snappedf(float(out["mult"]) * boost, 0.01)
	return out

static func enemy_at(i: int) -> Dictionary:
	var ti := clampi(i, 0, STAGE_MAX - 1)
	var boss := is_boss(ti)
	# v140：基准固定＝塔第 500 关（不再跟着等价关往后爬），成长交给 diff_mul 那条曲线
	var base_t: Dictionary = Tower.enemy_at(DIFF_BASE_STAGE)
	# 五行那一格要按"追剿自己的进度"取（基准关是 500，取不到 elem）——见下面那段
	var ba := _unmul(base_t)
	var dm := diff_mul(ti)
	var hp := float(ba[0]) * dm
	var atk := float(ba[1]) * dm
	var arch: Dictionary = arch_of(ti) if boss else {}
	if boss:
		hp *= BOSS_HP * float(arch.get("hp", 1.0))
		atk *= BOSS_ATK * float(arch.get("atk", 1.0))
	var out := {
		"name": enemy_name(ti),
		"hp": maxi(1, int(round(hp))),
		"atk": maxi(1, int(round(atk))),
		"spd": int(base_t.get("spd", 100)) + SPD_ADD,
		"def": GameData.foe_def(atk),
		"boss": boss,
		"elite": false,
		"chase": true,
		"chapter": chapter_of(ti),
	}
	if boss:
		var boost := 1.0 + minf(ART_BOOST * float(cycle_of(ti) - 1), ART_BOOST_CAP)
		out["arts"] = _scaled_arts(arch.get("arts", []), boost)
		out["ult"] = _scaled_ult(arch.get("ult", {}), boost)
		# v141：这一门 boss 的**专属被动**（battle_lite 那边认 passive_id 去实现）
		var ppid := passive_of_arch(str(arch.get("id", "")))
		out["passive_id"] = ppid
		out["passive"] = passive_def(ppid)
		out["affixes"] = (arch.get("affixes", []) as Array).duplicate()
		out["traits"] = (arch.get("traits", []) as Array).duplicate()
		out["arch"] = str(arch.get("id", ""))
		out["color"] = arch.get("color", [0.5, 0.3, 0.28])
		out["scale"] = float(arch.get("scale", 1.0))
		out["weapon"] = str(arch.get("weapon", ""))
		if bool(arch.has("phase_arts")):
			out["phase_arts"] = _scaled_arts(arch.get("phase_arts", []), boost)
		if bool(arch.has("phase_ult")):
			out["phase_ult"] = _scaled_ult(arch.get("phase_ult", {}), boost)
	else:
		var pos := ti % BOSS_EVERY
		if ti >= 9:
			out["affix_n"] = 1                     # 杂兵：第 10 关起带一条词缀（GameState 那边掷）
		out["weapon"] = str(MOB_WEAPON[clampi(pos, 0, MOB_WEAPON.size() - 1)])
		out["color"] = MOB_COLOR[clampi(pos, 0, MOB_COLOR.size() - 1)]
		out["scale"] = 0.96
	# 五行（v140 改口径）：基准关是固定 500，取不到塔那边的 elem 了，
	#   于是按**追剿自己的进度**给——第 301 关起（＝旧口径里"等价关过 800"那一档），
	#   每 25 关换一种五行（与塔"一章一属"的节奏同一把尺）。
	# ⚠ v141：带「五行护体」（金甲校尉）的那一门**提前给五行**——
	#   它的被动就是"自己那一行抗性 +40"，若等到第 301 关才有五行，前两轮的它等于没被动。
	var ward_boss := boss and passive_of_arch(str(arch.get("id", ""))) == "p_ward"
	if ti + 1 >= ELEM_FROM or ward_boss:
		var fe := str(Tower.CHAPTER_ELEM[(ti / DIFF_STEP) % Tower.CHAPTER_ELEM.size()])
		out["elem"] = fe
		out[fe + "_res"] = 30
	return out

# ============================================================
# 手牌模式（kushou）口径：同一批 boss / 同一套特性，数值换算到牌桌那一档
#   牌桌是"一局一剿"的 roguelike，跟真实战斗不可能同数——但**同一个 boss、
#   同一套特性、同一条进度**，玩家在两边看到的敌情是一回事。
# ============================================================
const KS_MOB_HP := 60.0
const KS_MOB_ATK := 6.0
const KS_BOSS_HP := 520.0
const KS_BOSS_ATK := 14.0
const KS_STEP := 0.06            # 每往后一剿，数值 +6%
const KS_WAVES := 5              # 一剿 ＝ 5 波（4 杂兵 + 1 boss）

static func ks_scale(i: int) -> float:
	return 1.0 + KS_STEP * float(round_of(i) - 1)

static func ks_enemy_at(i: int) -> Dictionary:
	var ti := clampi(i, 0, STAGE_MAX - 1)
	var s := ks_scale(ti)
	if is_boss(ti):
		var a: Dictionary = arch_of(ti)
		var boost := 1.0 + minf(ART_BOOST * float(cycle_of(ti) - 1), ART_BOOST_CAP)
		return {
			"name": boss_name(ti), "boss": true,
			"hp": int(round(KS_BOSS_HP * s * BOSS_HP * float(a.get("hp", 1.0)))),
			"atk": int(round(KS_BOSS_ATK * s * BOSS_ATK * float(a.get("atk", 1.0)))),
			"traits": (a.get("traits", []) as Array).duplicate(),
			"affixes": (a.get("affixes", []) as Array).duplicate(),
			"tag": str(a.get("tag", "")), "boost": boost,
		}
	return {
		"name": mob_name(ti), "boss": false,
		"hp": int(round(KS_MOB_HP * s)), "atk": int(round(KS_MOB_ATK * s)),
		"traits": [], "affixes": [], "tag": "", "boost": 1.0,
	}

# ============================================================
# 文案
# ============================================================
static func trait_of(id: String) -> Dictionary:
	return TRAITS.get(id, {})

static func trait_names(ids: Array) -> String:
	var out: Array = []
	for t in ids:
		var d := trait_of(str(t))
		if not d.is_empty():
			out.append("「" + str(d["name"]) + "」")
	return "".join(PackedStringArray(out))

static func trait_lines(ids: Array) -> Array:
	var out: Array = []
	for t in ids:
		var d := trait_of(str(t))
		if d.is_empty():
			continue
		out.append("「" + str(d["name"]) + "」" + str(d["desc"]) + "　　针对：" + str(d["counter"]))
	return out

static func boss_traits_of(i: int) -> Array:
	if not is_boss(i):
		return []
	return (arch_of(i).get("traits", []) as Array).duplicate()

# 出村面板那一行（未解锁也用它，把"还差多少"写清楚）
static func panel_line(progress: int) -> String:
	var p := clampi(progress, 0, STAGE_MAX)
	if p >= STAGE_MAX:
		return "五百关清净了——追杀队一个不剩。"
	var i := p
	if is_boss(i):
		return "下一战：" + boss_name(i)
	return "下一战：" + mob_name(i)
