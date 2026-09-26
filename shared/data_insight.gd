extends RefCounted
# ============================================================
# data_insight.gd —— **阅历线**唯一真源 v1
#
# 用户原话（这一版的规格）：
#   "增加一个新线 阅历线 这个是专门场外给予游历内辅助的 挂机 给阅历值
#    消耗银两和阅历值 可以提升阅历线"
#   "1 游历也可以给一点 2 吃挂机档位 3.分四条线 财富【经济】 进攻线 防御 技巧【暴击 闪避】
#    4.走满要很久 5（入口用底排「关于」那格）6（要洗点）但是消耗银两"
#
# 三条硬口径：
#   ① **只作用在游历**——统计进 run_state.stats_of()（游历那一份）与游历自己的几处闸，
#      爬塔/村战一个字不吃（村里的 effective_stats/squad_stats 不读这张表）。
#   ② **四支各 5 段、顺序解锁**：财富（经济）· 进攻 · 防御 · 技巧（暴击/闪避）。
#   ③ 数值**刻意压小**（每段 2%~5%）——这是"场外养成"，不是第二条装备线；
#      红线（伤害增幅减半 / 银两要难攒）在这条线上照旧：**不给银两收入，只花银两**。
#
# fx 键分三类（改表只用这几个键，别的键引擎不认）：
#   · 并进属性的（run_state.stats_of → insight_apply_to）：
#       atk_pct / hp_pct（乘）· dmg_add / crit_add / crit_dmg_add / def_add / dodge_add / spd_add（加）
#   · 游历流程闸：start_money（开局盘缠 +N 文）· money_pct（本趟文钱收益 +%）·
#       loot_pct（搜刮出货率 +%）· shop_cut（货郎担要价 -%）· bag_slots（包裹 +N 格）·
#       heal_add（每节恢复 +%）
#   · 战斗小闸：cut_add（受到的伤害 -%，duel_battle._setup_ally 里并进 al.cut_add）
# ============================================================

const BRANCHES := [
	{
		"id": "wealth", "name": "财富", "sub": "经济",
		"desc": "这一趟的银钱与行囊——走得越远，越会过日子",
		"nodes": [
			{"name": "盘缠", "desc": "出征开局盘缠 +30 文", "fx": {"start_money": 30}},
			{"name": "财路", "desc": "本趟文钱收益 +10%", "fx": {"money_pct": 0.10}},
			{"name": "眼力", "desc": "搜刮出货率 +12%", "fx": {"loot_pct": 0.12}},
			{"name": "人脉", "desc": "途中货郎担要价 -10%", "fx": {"shop_cut": 0.10}},
			{"name": "行囊", "desc": "本趟包裹 +3 格", "fx": {"bag_slots": 3}},
		],
	},
	{
		"id": "attack", "name": "进攻", "sub": "刀口",
		"desc": "出手更沉——只在这一趟里算数",
		"nodes": [
			{"name": "手熟", "desc": "游历内攻击 +3%", "fx": {"atk_pct": 0.03}},
			{"name": "破绽", "desc": "游历内伤害加成 +2", "fx": {"dmg_add": 2.0}},
			{"name": "老手", "desc": "游历内攻击 +4%", "fx": {"atk_pct": 0.04}},
			{"name": "狠劲", "desc": "游历内伤害加成 +3", "fx": {"dmg_add": 3.0}},
			{"name": "杀气", "desc": "游历内攻击 +5%", "fx": {"atk_pct": 0.05}},
		],
	},
	{
		"id": "defense", "name": "防御", "sub": "护身",
		"desc": "扛得住才走得完——只在这一趟里算数",
		"nodes": [
			{"name": "皮实", "desc": "游历内气血上限 +4%", "fx": {"hp_pct": 0.04}},
			{"name": "硬骨", "desc": "游历内防御 +4", "fx": {"def_add": 4.0}},
			{"name": "卸力", "desc": "游历内受到的伤害 -2%", "fx": {"cut_add": 0.02}},
			{"name": "厚底", "desc": "游历内气血上限 +5%", "fx": {"hp_pct": 0.05}},
			{"name": "调息", "desc": "每过一节多回 4% 气血（10% → 14%）", "fx": {"heal_add": 0.04}},
		],
	},
	{
		"id": "skill", "name": "技巧", "sub": "暴击 · 闪避",
		"desc": "眼准身轻——只在这一趟里算数",
		"nodes": [
			{"name": "眼准", "desc": "游历内暴击 +2%", "fx": {"crit_add": 2.0}},
			{"name": "身法", "desc": "游历内闪避 +3", "fx": {"dodge_add": 3.0}},
			{"name": "重手", "desc": "游历内暴击伤害 +6%", "fx": {"crit_dmg_add": 6.0}},
			{"name": "轻功", "desc": "游历内速度 +3", "fx": {"spd_add": 3.0}},
			{"name": "炉火", "desc": "游历内暴击 +3% · 闪避 +4", "fx": {"crit_add": 3.0, "dodge_add": 4.0}},
		],
	},
]

# 每支 5 段的价（下标＝第几段-1）——"走满要很久"是用户点名的：
#   单支 5 段 ＝ 阅历 5620 / 银两 6750；四支走满 ＝ **阅历 22480 / 银两 27000**。
#   按 0 档挂机（阅历 1/分、银两 0.16/分）算：阅历 ≈ 375 小时、银两 ≈ 2800 小时——
#   所以卡脖子的一定是银两（正合"银两要难攒"）；挂机档位上去了两条都会快起来。
#   ⚠ 想整体快/慢：只改这两行（或下面的两个常量），别的什么都不用动。
const COST_INSIGHT := [120, 300, 700, 1500, 3000]
const COST_SILVER := [150, 360, 840, 1800, 3600]
const MAX_LV := 5
# 洗点手续费：每"已升一级"收这么多银两（阅历全额退，银两不退）
const RESPEC_SILVER_PER_LV := 200

static func branch_of(bid: String) -> Dictionary:
	for b_v in BRANCHES:
		var b: Dictionary = b_v
		if str(b.get("id", "")) == bid:
			return b
	return {}

static func branch_ids() -> Array:
	var out: Array = []
	for b_v in BRANCHES:
		out.append(str((b_v as Dictionary).get("id", "")))
	return out

# 第 lv+1 段（要升的那一段；lv 已经走满 ＝ 空表）
static func node_next(bid: String, lv: int) -> Dictionary:
	var b := branch_of(bid)
	if b.is_empty():
		return {}
	var nodes: Array = b.get("nodes", [])
	var i := clampi(lv, 0, nodes.size())
	if i >= nodes.size():
		return {}
	return nodes[i]

static func max_lv(bid: String) -> int:
	var b := branch_of(bid)
	return (b.get("nodes", []) as Array).size()

# 第 lv+1 段要多少（lv 已满 ＝ 0/0）
static func cost_next(bid: String, lv: int) -> Dictionary:
	var i := clampi(lv, 0, COST_INSIGHT.size() - 1)
	if lv >= max_lv(bid):
		return {"insight": 0, "silver": 0}
	return {"insight": int(COST_INSIGHT[i]), "silver": int(COST_SILVER[i])}

# 已升的这些段合起来给什么（levels: {bid: 级数}）——同键相加
static func fx_of_levels(levels: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for b_v in BRANCHES:
		var b: Dictionary = b_v
		var bid := str(b.get("id", ""))
		var lv := clampi(int(levels.get(bid, 0)), 0, max_lv(bid))
		var nodes: Array = b.get("nodes", [])
		for i in lv:
			var fx: Dictionary = (nodes[i] as Dictionary).get("fx", {})
			for k in fx.keys():
				out[k] = float(out.get(k, 0.0)) + float(fx[k])
	return out

# 四支总级数（洗点费按它算）与"已投入的阅历合计"（洗点退这一笔）
static func total_lv(levels: Dictionary) -> int:
	var n := 0
	for b_v in BRANCHES:
		n += clampi(int(levels.get(str((b_v as Dictionary).get("id", "")), 0)), 0, MAX_LV)
	return n

static func spent_insight(levels: Dictionary) -> int:
	var n := 0
	for b_v in BRANCHES:
		var bid := str((b_v as Dictionary).get("id", ""))
		var lv := clampi(int(levels.get(bid, 0)), 0, MAX_LV)
		for i in lv:
			n += int(COST_INSIGHT[clampi(i, 0, COST_INSIGHT.size() - 1)])
	return n
