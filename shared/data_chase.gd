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
#   · boss ＝ 10 种性情 × 10 队（轮次）：第 1~10 剿是第一队的十种、第 11~20 剿是第二队……
#     同一队的第十剿打完就是下一队；每换一队，招数倍率再抬 ART_BOOST 一档；
#   · 难度 ＝ 拿塔上**等价关**（第 i 关 ≈ 塔第 OFFSET+i 关）的底子 × HP_MUL/ATK_MUL
#     ——"难度略高"就压在这两个系数上；境界与境界压制跟塔同一把尺（GameState 那边乘）；
#   · 奖励**先留空**：清关只推进度，不给银两/经验/箱子（做好再设置）。
#
# ⚠ 本文件**不许 preload game_state**（game_state 反过来 preload 了它，绕回去就是死循环）。
#   要读玩家状态就由 GameState.chase_enemy_at() 在这一层外面补。
# ============================================================

const Tower := preload("res://shared/tower.gd")
const GameData := preload("res://shared/game_data.gd")

const NAME := "追剿"
const STAGE_MAX := 500           # 追剿自己的关数（用户 2026-10-09 拍板）
const BOSS_EVERY := 5            # 每 5 关一个 boss
const UNLOCK_STAGE := 500        # 爬塔到这一关（通关数）才开
const OFFSET := 499              # 追剿第 1 关 ＝ 塔第 500 关的底子（0 起是 499）
const HP_MUL := 1.18             # 杂兵气血（相对塔同关）—— "难度略高"
const ATK_MUL := 1.12            # 杂兵攻击
#   ⚠ 追剿的 boss 是"五关一个"（塔是二十五关一个），所以这一档**不能照塔的首领加码来**：
#     试算过 1.45 会让 boss 那一组的总血池顶到塔第 500 关首领的 1.6 倍——太硬。
#     1.25 落在"跟塔的首领同档、但每五关就要打一次"的位置上（要松要紧只动这两行）。
const BOSS_HP := 1.25            # boss 再叠一档（相对本关杂兵）
const BOSS_ATK := 1.10
const REALM_DIV := 350           # 境界：与塔同尺（每 350 关一境）
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
# boss 性情表（十种，循环用）
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
# 关卡号 ↔ 剿号
# ============================================================
static func rounds() -> int:
	return STAGE_MAX / BOSS_EVERY

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
	var t: Dictionary = Tower.enemy_at(OFFSET + ti)
	var ba := _unmul(t)
	var hp := float(ba[0]) * HP_MUL
	var atk := float(ba[1]) * ATK_MUL
	var arch: Dictionary = arch_of(ti) if boss else {}
	if boss:
		hp *= BOSS_HP * float(arch.get("hp", 1.0))
		atk *= BOSS_ATK * float(arch.get("atk", 1.0))
	var out := {
		"name": enemy_name(ti),
		"hp": maxi(1, int(round(hp))),
		"atk": maxi(1, int(round(atk))),
		"spd": int(t.get("spd", 100)) + SPD_ADD,
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
	# 五行：等价关到了塔的元素线（第 800 关）就跟着有——与塔同尺
	if t.has("elem"):
		var fe := str(t["elem"])
		out["elem"] = fe
		out[fe + "_res"] = t.get(fe + "_res", 30)
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
