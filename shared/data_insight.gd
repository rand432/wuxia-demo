extends RefCounted
# ============================================================
# data_insight.gd —— **阅历线**唯一真源 v2（32 段 × 4 支 · 每第 4 段一个大节点）
#
# 用户规格（v2 定案）：
#   "每一种 32 个节点 · 每第四个一个大节点 · 可以同时四条线都走 ·
#    攻击纯数值（大节点 攻击+百分比）· 防御也是纯数值 · 技巧再加一个伤害增幅 ·
#    长线价目 · 整体上调 · 暴击放宽 · 闪避稀有给少点 · 伤害增幅多些 · 爆伤多些 ·
#    财富再大一点 · **去掉"开局行装"** · 财富按四组节奏：初始文钱→大节点文钱% ·
#    **搜刮给文钱**→大节点搜刮% · 货架折扣→大节点包裹+ · 卖价→大节点临时仓库+3"
#
# 结构：每支 = **8 组 × 4 段**（3 个小节点 ＋ 第 4 段的大节点）＝ 32 段。
#   小节点：平面值；大节点：平面 ＋（进攻/防御）百分比，或（技巧/财富）另一条加成。
# 只作用在**游历**：并进 run_state.stats_of() 与游历自己的几处闸；爬塔/村里一个字不吃。
# 不给银两收入（只花银两）——"银两要难攒"那条红线照旧。
# ============================================================

const BIG_EVERY := 4          # 每第几段是大节点
const GROUPS := 8             # 每支几组
const LV_MAX := BIG_EVERY * GROUPS   # 32

# ---- 价目 ---------------------------------------------------------------------
# v2g（用户："不 8节后是 9-12 提升20% 13-16提升40% 17-20提升80%"）：
#   **总系数按"第几节"走**，跟小/大节点无关（大小只决定"基础价"是多少）：
#     第 1~8 节   ＝ × **0.6**（下调 40%）
#     第 9~12 节  ＝ × **1.2**（＋20%）   第 13~16 节 ＝ × **1.4**（＋40%）
#     第 17~20 节 ＝ × **1.8**（＋80%）   第 21~24 节 ＝ × **2.6**（＋160%）
#     第 25~28 节 ＝ × **4.2**（＋320%）  第 29~32 节 ＝ × **7.4**（＋640%）
#   ——**每往后四节，"加的那一份"翻一倍**（20% → 40% → 80% → …），不是复利。
#   基础价：小节点 阅历 100 / 银两 120 · 大节点 阅历 600 / 银两 750。
#   ⚠ 想整体快慢/陡缓：只改下面三行（0.6 / 0.2 / 8）。
const SMALL_INS := 100
const SMALL_SIL := 120
const BIG_INS := 600
const BIG_SIL := 750
const COST_MUL0 := 0.6          # 前 8 节的总系数（用户："初始 8 节下调 40%"）
const COST_STEP_BASE := 0.2     # 第 9 节起：＋20%、＋40%、＋80%…（每四节翻一倍）
const COST_FIRST_CHEAP := 8     # 前几节算"初始档"（每 4 节一组的整倍数）
const RESPEC_SILVER_PER_LV := 200   # 洗点手续费：每已通一段 200 两（阅历全退，银两不退）

# ---- 四支 ---------------------------------------------------------------------
#   groups：8 组，每组 {small: {name,desc,fx}, big: {name,desc,fx}}
const BRANCHES := [
	{
		"id": "wealth", "name": "行旅", "sub": "交易 · 粮草 · 掉落",
		"desc": "这一趟买得便宜、卖得贵、走路省粮、偶尔多爆一件",
		"groups": [
			{"small": {"name": "讲价", "desc": "货郎卖价 -3%", "fx": {"shop_cut": 0.03}},
			 "big": {"name": "眼力", "desc": "搜刮出货率 +8%", "fx": {"loot_pct": 0.08}}},
			{"small": {"name": "轻身", "desc": "行走免耗粮 +6%", "fx": {"food_save": 0.06}},
			 "big": {"name": "寻宝", "desc": "搜刮出货率 +12%", "fx": {"loot_pct": 0.12}}},
			{"small": {"name": "议价", "desc": "卖价 +5%", "fx": {"sell_pct": 0.05}},
			 "big": {"name": "生意", "desc": "货郎卖价 -4%", "fx": {"shop_cut": 0.04}}},
			{"small": {"name": "拾遗", "desc": "额外掉落概率 +4%", "fx": {"extra_loot": 0.04}},
			 "big": {"name": "丰获", "desc": "额外掉落概率 +6%", "fx": {"extra_loot": 0.06}}},
			{"small": {"name": "讲价", "desc": "货郎卖价 -4%", "fx": {"shop_cut": 0.04}},
			 "big": {"name": "洞察", "desc": "搜刮出货率 +10%", "fx": {"loot_pct": 0.10}}},
			{"small": {"name": "轻身", "desc": "行走免耗粮 +8%", "fx": {"food_save": 0.08}},
			 "big": {"name": "寻宝", "desc": "搜刮出货率 +15%", "fx": {"loot_pct": 0.15}}},
			{"small": {"name": "议价", "desc": "卖价 +6%", "fx": {"sell_pct": 0.06}},
			 "big": {"name": "生意", "desc": "货郎卖价 -5%", "fx": {"shop_cut": 0.05}}},
			{"small": {"name": "拾遗", "desc": "额外掉落概率 +6%", "fx": {"extra_loot": 0.06}},
			 "big": {"name": "丰获", "desc": "额外掉落概率 +10%", "fx": {"extra_loot": 0.10}}},
		],
	},
	{
		"id": "attack", "name": "进攻", "sub": "刀口",
		"desc": "小节点平面攻击，大节点平面＋百分比",
		# v2i（用户："百分比的增益可以给多一点【指暴击伤害 伤害增幅 攻击加成 和气血防御加成】"）：
		#   进攻支的**攻击加成 +12% → +24%**（大节点 2%/2%/2%/2%/4%/4%/4%/4%），平面仍 +110。
		#   → 满级满配 (140+110)×1.24 ＝ **310（×2.21）**
		"groups": [
			{"small": {"name": "手熟", "desc": "攻击 +1", "fx": {"atk_flat": 1}},
			 "big": {"name": "起手", "desc": "攻击 +4 · 攻击 +2%", "fx": {"atk_flat": 4, "atk_pct": 0.02}}},
			{"small": {"name": "沉腕", "desc": "攻击 +1", "fx": {"atk_flat": 1}},
			 "big": {"name": "断筋", "desc": "攻击 +5 · 攻击 +2%", "fx": {"atk_flat": 5, "atk_pct": 0.02}}},
			{"small": {"name": "老手", "desc": "攻击 +2", "fx": {"atk_flat": 2}},
			 "big": {"name": "贯甲", "desc": "攻击 +5 · 攻击 +2%", "fx": {"atk_flat": 5, "atk_pct": 0.02}}},
			{"small": {"name": "快刀", "desc": "攻击 +2", "fx": {"atk_flat": 2}},
			 "big": {"name": "势成", "desc": "攻击 +6 · 攻击 +2%", "fx": {"atk_flat": 6, "atk_pct": 0.02}}},
			{"small": {"name": "快刀", "desc": "攻击 +3", "fx": {"atk_flat": 3}},
			 "big": {"name": "破军", "desc": "攻击 +6 · 攻击 +4%", "fx": {"atk_flat": 6, "atk_pct": 0.04}}},
			{"small": {"name": "狠劲", "desc": "攻击 +3", "fx": {"atk_flat": 3}},
			 "big": {"name": "无回", "desc": "攻击 +7 · 攻击 +4%", "fx": {"atk_flat": 7, "atk_pct": 0.04}}},
			{"small": {"name": "狠劲", "desc": "攻击 +4", "fx": {"atk_flat": 4}},
			 "big": {"name": "刀意", "desc": "攻击 +8 · 攻击 +4%", "fx": {"atk_flat": 8, "atk_pct": 0.04}}},
			{"small": {"name": "刀意", "desc": "攻击 +4", "fx": {"atk_flat": 4}},
			 "big": {"name": "无锋", "desc": "攻击 +9 · 攻击 +4%", "fx": {"atk_flat": 9, "atk_pct": 0.04}}},
		],
	},
	{
		"id": "defense", "name": "防御", "sub": "护身",
		"desc": "小节点给气血，大节点给气血与防御%",
		# v2i：**气血 +15% → +30%**、并新增**防御 +%（合计 +20%）**，平面仍是气血 +1,950 / 防御 +24。
		#   → 满级满配 (2,633+1,950)×1.30 ＝ **5,958（×2.26）**；防御 (110+24)×1.20 ＝ **161（+46%）**
		"groups": [
			{"small": {"name": "皮实", "desc": "气血 +15", "fx": {"hp_flat": 15}},
			 "big": {"name": "硬骨", "desc": "气血 +60 · 气血 +2% · 防御 +2 · 防御 +2%", "fx": {"hp_flat": 60, "hp_pct": 0.02, "def_flat": 2, "def_pct": 0.02}}},
			{"small": {"name": "皮实", "desc": "气血 +15", "fx": {"hp_flat": 15}},
			 "big": {"name": "卸力", "desc": "气血 +90 · 气血 +2% · 防御 +2 · 防御 +2%", "fx": {"hp_flat": 90, "hp_pct": 0.02, "def_flat": 2, "def_pct": 0.02}}},
			{"small": {"name": "厚底", "desc": "气血 +25", "fx": {"hp_flat": 25}},
			 "big": {"name": "铁桩", "desc": "气血 +120 · 气血 +4% · 防御 +3 · 防御 +2%", "fx": {"hp_flat": 120, "hp_pct": 0.04, "def_flat": 3, "def_pct": 0.02}}},
			{"small": {"name": "厚底", "desc": "气血 +25", "fx": {"hp_flat": 25}},
			 "big": {"name": "龟息", "desc": "气血 +140 · 气血 +4% · 防御 +3 · 防御 +2%", "fx": {"hp_flat": 140, "hp_pct": 0.04, "def_flat": 3, "def_pct": 0.02}}},
			{"small": {"name": "铁布", "desc": "气血 +35", "fx": {"hp_flat": 35}},
			 "big": {"name": "山立", "desc": "气血 +160 · 气血 +4% · 防御 +3 · 防御 +3%", "fx": {"hp_flat": 160, "hp_pct": 0.04, "def_flat": 3, "def_pct": 0.03}}},
			{"small": {"name": "铁布", "desc": "气血 +35", "fx": {"hp_flat": 35}},
			 "big": {"name": "不摧", "desc": "气血 +180 · 气血 +4% · 防御 +3 · 防御 +3%", "fx": {"hp_flat": 180, "hp_pct": 0.04, "def_flat": 3, "def_pct": 0.03}}},
			{"small": {"name": "磐石", "desc": "气血 +45", "fx": {"hp_flat": 45}},
			 "big": {"name": "不动", "desc": "气血 +220 · 气血 +4% · 防御 +4 · 防御 +3%", "fx": {"hp_flat": 220, "hp_pct": 0.04, "def_flat": 4, "def_pct": 0.03}}},
			{"small": {"name": "磐石", "desc": "气血 +45", "fx": {"hp_flat": 45}},
			 "big": {"name": "金刚", "desc": "气血 +260 · 气血 +6% · 防御 +4 · 防御 +3%", "fx": {"hp_flat": 260, "hp_pct": 0.06, "def_flat": 4, "def_pct": 0.03}}},
		],
	},
	{
		"id": "skill", "name": "技巧", "sub": "暴击 · 闪避 · 伤害增幅",
		"desc": "暴击放宽、闪避稀有、增伤与爆伤给厚",
		# v2i：**伤害增幅 +29% → +56%**、**暴击伤害 +29% → +53%**（大节点各抬一档）。
		#   全支：暴击 +16 · 闪避 +21 · 伤害增幅 +56% · 暴击伤害 +53%
		"groups": [
			{"small": {"name": "眼准", "desc": "闪避 +1", "fx": {"dodge_flat": 1}},
			 "big": {"name": "身法", "desc": "暴击 +2 · 闪避 +2", "fx": {"crit_add": 2, "dodge_flat": 2}}},
			{"small": {"name": "眼准", "desc": "闪避 +1", "fx": {"dodge_flat": 1}},
			 "big": {"name": "重手", "desc": "暴击 +2 · 伤害增幅 +10%", "fx": {"crit_add": 2, "dmg_pct": 0.10}}},
			{"small": {"name": "听风", "desc": "闪避 +2", "fx": {"dodge_flat": 2}},
			 "big": {"name": "轻功", "desc": "暴击 +2 · 暴击伤害 +16%", "fx": {"crit_add": 2, "crit_dmg_add": 16}}},
			{"small": {"name": "沉劲", "desc": "伤害增幅 +1%", "fx": {"dmg_pct": 0.01}},
			 "big": {"name": "炉火", "desc": "暴击 +2 · 闪避 +3", "fx": {"crit_add": 2, "dodge_flat": 3}}},
			{"small": {"name": "沉劲", "desc": "伤害增幅 +1%", "fx": {"dmg_pct": 0.01}},
			 "big": {"name": "踏雪", "desc": "暴击 +2 · 伤害增幅 +14%", "fx": {"crit_add": 2, "dmg_pct": 0.14}}},
			{"small": {"name": "沉劲", "desc": "伤害增幅 +2%", "fx": {"dmg_pct": 0.02}},
			 "big": {"name": "惊鸿", "desc": "暴击 +2 · 暴击伤害 +22%", "fx": {"crit_add": 2, "crit_dmg_add": 22}}},
			{"small": {"name": "淬锋", "desc": "暴击伤害 +2%", "fx": {"crit_dmg_add": 2}},
			 "big": {"name": "无痕", "desc": "暴击 +2 · 闪避 +4", "fx": {"crit_add": 2, "dodge_flat": 4}}},
			{"small": {"name": "淬锋", "desc": "暴击伤害 +3%", "fx": {"crit_dmg_add": 3}},
			 "big": {"name": "通神", "desc": "暴击 +2 · 伤害增幅 +20%", "fx": {"crit_add": 2, "dmg_pct": 0.20}}},
		],
	},
]

# ---- 表查询 -------------------------------------------------------------------

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

static func max_lv(_bid: String) -> int:
	return LV_MAX

# 第 lv+1 段是"小"还是"大"
static func is_big(lv: int) -> bool:
	return (lv + 1) % BIG_EVERY == 0

# 第 lv+1 段的内容（lv 从 0 起；走满＝空表）
static func node_next(bid: String, lv: int) -> Dictionary:
	var b := branch_of(bid)
	if b.is_empty() or lv < 0 or lv >= LV_MAX:
		return {}
	var groups: Array = b.get("groups", [])
	var g := lv / BIG_EVERY
	if g < 0 or g >= groups.size():
		return {}
	var grp: Dictionary = groups[g]
	return grp.get("big", {}) if is_big(lv) else grp.get("small", {})

# 第 lv+1 节的价——**总系数只看"第几节"**（见上面那段）：
#   前 8 节 ×0.6；之后每 4 节再 ×1.2（复利）。基础价按小/大节点分两档。
static func cost_mul_at(lv: int) -> float:
	var idx := lv + 1
	if idx <= COST_FIRST_CHEAP:
		return COST_MUL0
	# 第 9 节起：第一组 +20%，之后每四节"加的那一份"翻一倍（+20/+40/+80/+160…）
	var g := (idx - COST_FIRST_CHEAP - 1) / BIG_EVERY + 1
	return 1.0 + COST_STEP_BASE * pow(2.0, float(g - 1))

static func cost_next(bid: String, lv: int) -> Dictionary:
	if branch_of(bid).is_empty() or lv < 0 or lv >= LV_MAX:
		return {"insight": 0, "silver": 0}
	var big := (lv + 1) % BIG_EVERY == 0
	var m := cost_mul_at(lv)
	return {
		"insight": maxi(1, int(round(float(BIG_INS if big else SMALL_INS) * m))),
		"silver": maxi(1, int(round(float(BIG_SIL if big else SMALL_SIL) * m))),
	}

# 已升的这些段合起来给什么（levels: {bid: 级数}）——同键相加
static func fx_of_levels(levels: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for b_v in BRANCHES:
		var bid := str((b_v as Dictionary).get("id", ""))
		var lv := clampi(int(levels.get(bid, 0)), 0, LV_MAX)
		for i in lv:
			var nd := node_next(bid, i)
			var fx: Dictionary = nd.get("fx", {})
			for k in fx.keys():
				out[k] = float(out.get(k, 0.0)) + float(fx[k])
	return out

static func total_lv(levels: Dictionary) -> int:
	var n := 0
	for b_v in BRANCHES:
		n += clampi(int(levels.get(str((b_v as Dictionary).get("id", "")), 0)), 0, LV_MAX)
	return n

static func spent_insight(levels: Dictionary) -> int:
	var n := 0
	for b_v in BRANCHES:
		var bid := str((b_v as Dictionary).get("id", ""))
		var lv := clampi(int(levels.get(bid, 0)), 0, LV_MAX)
		for i in lv:
			n += int(cost_next(bid, i).get("insight", 0))
	return n

# 走满一支要多少（给面板"总计"用）
static func branch_total_cost(bid: String) -> Dictionary:
	var ins := 0
	var sil := 0
	for i in LV_MAX:
		var c := cost_next(bid, i)
		ins += int(c.get("insight", 0))
		sil += int(c.get("silver", 0))
	return {"insight": ins, "silver": sil}
