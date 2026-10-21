extends RefCounted
# ============================================================
# data_forge.gd —— 锻造 V0.1 的静态表（胚子 / 品质 / 数值 / 费用）
# 规则见 docs/锻造_设计稿.md：
#   · 五结果只在强化时掷；升阶不另掷
#   · +2%/级，+20 = +40%；升阶基础 ×1.5、强化归 0
#   · 入神：+10 触发，7 秒内最多 6 锤不碎
#   · 每锤 1 锻造石；开炉 10~30 两；升阶 银两 + 金髓 1
# ============================================================

const QUALITY_CN := ["凡品", "良品", "上品", "极品", "绝品"]

# 品质基础（成品 = 基础 × (1 + 强化 × 2%)）
const Q_BASE := [
	{"atk": 15, "dmg": 2},
	{"atk": 24, "dmg": 3},
	{"atk": 34, "dmg": 4},
	{"atk": 48, "dmg": 6},
	{"atk": 68, "dmg": 8},
]

# 胚子：probs = [大成功, 成功, 维持, 损伤, 破坏]
const BLANKS := [
	{"id": "common", "name": "普通胚子", "weapon": "待定", "kind": "generic", "pool": "weapon",
		"quality": 0, "cap": 2, "atk": 0, "dmg": 0, "open": 0, "need": "common", "blank_class": "generic",
		"probs": [5, 32, 35, 22, 6], "trait": "普通"},
	{"id": "gen_fan", "name": "凡品胚子", "weapon": "待定", "kind": "generic", "pool": "weapon",
		"quality": 0, "cap": 2, "atk": 0, "dmg": 0, "open": 0, "blank_class": "generic",
		"probs": [8, 39, 28, 19, 6], "trait": "凡品"},
	{"id": "gen_zhong", "name": "中品胚子", "weapon": "待定", "kind": "generic", "pool": "weapon",
		"quality": 1, "cap": 3, "atk": 0, "dmg": 0, "open": 0, "blank_class": "generic",
		"probs": [10, 37, 26, 20, 7], "trait": "中品"},
	{"id": "gen_shang", "name": "上品胚子", "weapon": "待定", "kind": "generic", "pool": "weapon",
		"quality": 2, "cap": 4, "atk": 0, "dmg": 0, "open": 0, "blank_class": "generic",
		"probs": [10, 39, 24, 20, 7], "trait": "上品"},
	{"id": "gen_ji", "name": "极品胚子", "weapon": "待定", "kind": "generic", "pool": "weapon",
		"quality": 3, "cap": 4, "atk": 0, "dmg": 0, "open": 0, "blank_class": "generic",
		"probs": [12, 39, 22, 20, 7], "trait": "极品"},
	{"id": "gen_jue", "name": "绝品胚子", "weapon": "待定", "kind": "generic", "pool": "weapon",
		"quality": 4, "cap": 4, "atk": 0, "dmg": 0, "open": 0, "blank_class": "generic",
		"probs": [14, 39, 20, 20, 7], "trait": "绝品"},
]

static func blank(id: String) -> Dictionary:
	var use_id := "common" if id == "jianpei" else id
	for b in BLANKS:
		if str((b as Dictionary)["id"]) == use_id:
			return (b as Dictionary).duplicate(true)
	for b in BLANKS:
		if str((b as Dictionary)["id"]) == id:
			return (b as Dictionary).duplicate(true)
	return {}

const ELEM_CN := {"metal": "金", "wood": "木", "water": "水", "fire": "火", "earth": "土"}

static func element_cn(e: String) -> String:
	return str(ELEM_CN.get(e, ""))

static func quality_name(q: int) -> String:
	return QUALITY_CN[clampi(q, 0, QUALITY_CN.size() - 1)]

# 第一锤的成器档位：与「品质」分开，凡品也有破损/完美之分。
const CRAFT_GRADES := [
	{"id": "broken", "short": "破 损", "name": "破损的", "mul": 0.55, "col": Color(0.72, 0.20, 0.15), "bg": Color(0.96, 0.82, 0.78)},
	{"id": "rough", "short": "损 伤", "name": "损伤的", "mul": 0.75, "col": Color(0.66, 0.38, 0.10), "bg": Color(0.97, 0.89, 0.74)},
	{"id": "plain", "short": "维 持", "name": "寻常的", "mul": 1.00, "col": Color(0.36, 0.34, 0.30), "bg": Color(0.90, 0.88, 0.82)},
	{"id": "fine", "short": "成 功", "name": "精良的", "mul": 1.15, "col": Color(0.18, 0.50, 0.32), "bg": Color(0.82, 0.93, 0.82)},
	{"id": "perfect", "short": "大成功", "name": "完美的", "mul": 1.35, "col": Color(0.72, 0.48, 0.08), "bg": Color(0.99, 0.89, 0.55)},
]

static func grade_name(g: int) -> String:
	return str((CRAFT_GRADES[clampi(g, 0, 4)] as Dictionary)["name"])

static func grade_short(g: int) -> String:
	return str((CRAFT_GRADES[clampi(g, 0, 4)] as Dictionary)["short"])

static func grade_bg(g: int) -> Color:
	return (CRAFT_GRADES[clampi(g, 0, 4)] as Dictionary)["bg"]

static func grade_col(g: int) -> Color:
	return (CRAFT_GRADES[clampi(g, 0, 4)] as Dictionary)["col"]

static func grade_mul(g: int) -> float:
	return float((CRAFT_GRADES[clampi(g, 0, 4)] as Dictionary)["mul"])

const OUTCOMES := [
	{"name": "破 坏", "col": Color(0.72, 0.16, 0.12)},
	{"name": "损 伤", "col": Color(0.66, 0.38, 0.10)},
	{"name": "维 持", "col": Color(0.36, 0.34, 0.30)},
	{"name": "成 功", "col": Color(0.18, 0.50, 0.32)},
	{"name": "大成功", "col": Color(0.72, 0.48, 0.08)},
]

static func outcome_name(i: int) -> String:
	return str((OUTCOMES[clampi(i, 0, 4)] as Dictionary)["name"])

static func outcome_col(i: int) -> Color:
	return (OUTCOMES[clampi(i, 0, 4)] as Dictionary)["col"]

# 显示顺序：破坏 / 损伤 / 维持 / 成功 / 大成功
static func roll_percents(it: Dictionary) -> Array:
	var b := blank(str(it.get("blank", "")))
	var p: Array = [8.0, 45.0, 25.0, 17.0, 5.0]
	if not b.is_empty():
		p = []
		for v in (b.get("probs", [8, 45, 25, 17, 5]) as Array):
			p.append(float(v))
	var lucky := int(it.get("lucky_success", 0)) + int(it.get("lucky_great", 0)) * 2
	if lucky > 0:
		p[1] = maxf(1.0, p[1] - float(lucky) * 5.0)
		p[0] = maxf(0.0, p[0] - float(lucky) * 3.0)
		p[2] += float(lucky) * 4.0
		p[3] += float(lucky) * 3.0
		p[4] += float(lucky) * 1.5
	var e := float(it.get("enhance", 0))
	var cr := float(it.get("cracks", 0))
	var extra_break := e * 0.15 + cr * 2.0 + float(it.get("damage_bias", 0)) * 5.0
	p[4] += extra_break
	p[3] += e * 0.08 + cr * 1.0
	p[1] = maxf(0.0, float(p[1]) - extra_break)
	if str(it.get("quench_trait", "")) == "wending":
		p[2] = float(p[2]) + 20.0
	elif str(it.get("quench_trait", "")) == "fengli":
		p[1] = float(p[1]) + 10.0
	elif str(it.get("quench_trait", "")) == "fuyuan":
		p[0] = float(p[0]) + 5.0
	elif str(it.get("quench_trait", "")) == "hufeng":
		p[4] = maxf(0.0, float(p[4]) - 3.0)
	if str(it.get("quench_trait", "")) == "jianren":
		p[4] = maxf(0.0, float(p[4]) - float(int(it.get("jianren_stack", 0))) * 2.0)
	if bool(it.get("trait_next_success", false)):
		p[1] = float(p[1]) + 15.0
	if bool(it.get("trait_next_guard", false)):
		p[4] = maxf(0.0, float(p[4]) - 10.0)
	if bool(it.get("trait_next_great", false)):
		p[0] = float(p[0]) + 10.0
	if str(it.get("quench_trait", "")) == "dieren":
		p[4] = maxf(0.0, float(p[4]) - float(int(it.get("dieren_stack", 0))))
	var total := 0.0
	for v in p:
		total += float(v)
	if total <= 0.0:
		return [0, 0, 0, 100, 0]
	return [p[4] / total * 100.0, p[3] / total * 100.0, p[2] / total * 100.0, p[1] / total * 100.0, p[0] / total * 100.0]

static func grade_weights(it: Dictionary) -> Array:
	var w := [10.0, 20.0, 35.0, 25.0, 10.0]
	return w

static func roll_craft_grade(it: Dictionary) -> int:
	var w := grade_weights(it)
	var total := 0.0
	for v in w:
		total += float(v)
	var r := randf() * total
	var acc := 0.0
	for i in w.size():
		acc += float(w[i])
		if r <= acc:
			return i
	return 2

static func make_item(blank_id: String) -> Dictionary:
	var b := blank(blank_id)
	if b.is_empty():
		return {}
	return {
		"blank": blank_id,
		"weapon": str(b["weapon"]),
		"kind": str(b["kind"]),
		"pool": str(b.get("pool", "weapon")),
		"quality": int(b["quality"]),
		"cap": int(b["cap"]),
		"enhance": 0,
		"cracks": 0,
		"base_atk": float(b.get("atk", 0)),
		"base_dmg": float(b.get("dmg", 0)),
		"base_def": float(b.get("def", 0)),
		"base_hp": float(b.get("hp", 0)),
		"base_dodge": float(b.get("dodge", 0)),
		"inspired_left": 0,
		"round_inspired": false,
		"awaiting": false,
		"affixes": [],
		"craft_grade": -1,
		"blank_class": str(b.get("blank_class", "specific")),
		"rule": str(b.get("rule", "")),
	}

static func randomize_generic(it: Dictionary) -> void:
	var q := clampi(int(it.get("quality", 0)), 0, 4)
	var roll := randi() % 6
	if str(it.get("quench_trait", "")).begins_with("elem_"):
		roll = randi() % 3
	match str(it.get("quench_trait", "")):
		"type_sword":
			roll = 0
		"type_dual":
			roll = 1
		"type_staff":
			roll = 2
		"type_armor":
			roll = 3
		"type_helm":
			roll = 4
		"type_cloak":
			roll = 5
	var names := ["长剑", "双刀", "长棍", "战甲", "头冠", "披风"]
	var kinds := ["sword", "dual", "staff", "armor", "helm", "cloak"]
	var pools := ["weapon", "weapon", "weapon", "armor", "helm", "cloak"]
	it["kind"] = kinds[roll]
	it["pool"] = pools[roll]
	it["weapon"] = str(names[roll])
	it["base_atk"] = 0.0
	it["base_dmg"] = 0.0
	it["base_def"] = 0.0
	it["base_hp"] = 0.0
	it["base_dodge"] = 0.0
	match roll:
		0:
			it["base_atk"] = 16.0 + q * 10.0
			it["base_dmg"] = 2.0 + q
		1:
			it["base_atk"] = 14.0 + q * 9.0
			it["base_dmg"] = 3.0 + q
		2:
			it["base_atk"] = 18.0 + q * 10.0
			it["base_dmg"] = 2.0 + q
		3:
			it["base_def"] = 4.0 + q * 3.0
			it["base_hp"] = 30.0 + q * 25.0
		4:
			it["base_def"] = 2.0 + q * 2.0
			it["base_hp"] = 14.0 + q * 12.0
		5:
			it["base_def"] = 1.0 + q * 2.0
			it["base_hp"] = 8.0 + q * 8.0
			it["base_dodge"] = 3.0 + q
	it["blank_class"] = "specific"

static func item_name(it: Dictionary) -> String:
	if it.is_empty():
		return "（无）"
	var g := int(it.get("craft_grade", -1))
	var pre := "" if g < 0 else (grade_name(g) + "·")
	var qn := quality_name(int(it.get("quality", 0)))
	var wn := str(it.get("weapon", "兵器"))
	if wn.begins_with(qn):
		wn = wn.substr(qn.length())
	return pre + qn + "·" + wn + " +" + str(int(it.get("enhance", 0)))

static func item_stats(it: Dictionary) -> Dictionary:
	if it.is_empty():
		return {"atk": 0, "dmg": 0}
	var g0 := int(it.get("craft_grade", -1))
	var gm := 1.0 if g0 < 0 else grade_mul(g0)
	var mul := (1.0 + float(it.get("enhance", 0)) * 0.02) * gm
	var out := {}
	if float(it.get("base_atk", 0.0)) > 0.0:
		out["atk"] = int(round(float(it.get("base_atk", 0.0)) * mul))
	if float(it.get("base_dmg", 0.0)) > 0.0:
		out["dmg"] = int(round(float(it.get("base_dmg", 0.0)) * mul))
	if float(it.get("base_def", 0.0)) > 0.0:
		out["def"] = int(round(float(it.get("base_def", 0.0)) * mul))
	if float(it.get("base_hp", 0.0)) > 0.0:
		out["hp"] = int(round(float(it.get("base_hp", 0.0)) * mul))
	if float(it.get("base_dodge", 0.0)) > 0.0:
		out["dodge"] = int(round(float(it.get("base_dodge", 0.0)) * mul))
	var extra: Dictionary = it.get("base_extra", {})
	for ek in extra.keys():
		if typeof(extra[ek]) == TYPE_INT or typeof(extra[ek]) == TYPE_FLOAT:
			out[str(ek)] = int(round(float(extra[ek]) * mul))
	for aid in (it.get("affixes", []) as Array):
		var af := affix(str(aid))
		var st: Dictionary = af.get("stats", {})
		for k in st.keys():
			out[str(k)] = int(out.get(str(k), 0)) + int(st[k])
	return out

static func finalize_silver(q: int) -> int:
	return [20, 40, 80, 160, 320][clampi(q, 0, 4)]

static func hammer_stones(q: int) -> int:
	return [1, 2, 3, 4, 5][clampi(q, 0, 4)]

const ASCEND_SILVER := [100, 300, 800, 2000]
const ASCEND_STAR_IRON := [0, 1, 2, 3]

static func ascend_cost(q: int) -> Dictionary:
	var qi := clampi(q, 0, ASCEND_SILVER.size() - 1)
	return {"silver": int(ASCEND_SILVER[qi]), "star_iron": int(ASCEND_STAR_IRON[qi])}

static func card_set(it: Dictionary, sid: String) -> Dictionary:
	var nm := item_name(it)
	var st := item_stats(it)
	var set := {
		"id": sid, "name": nm, "item": nm,
		"pool": str(it.get("pool", "weapon")), "quality": quality_name(int(it.get("quality", 0))),
		"weapon": str(it.get("kind", "sword")),
		"no_drop": true, "forge": true, "parts": [],
		"item_stats": st.duplicate(),
		"elem": str(it.get("elem", "")),
		"desc": "锻造出品（" + trait_of(it) + "）",
	}
	var base: Dictionary = it.get("base_card", {})
	if not base.is_empty():
		for bk in base.keys():
			if str(bk) in ["id", "name", "item", "item_stats", "parts", "forge"]:
				continue
			set[bk] = base[bk]
	return set

const AFFIXES := [
	{"id": "fengrui", "name": "锋锐", "stats": {"crit": 5}, "desc": "暴击 +5"},
	{"id": "buzhe", "name": "不折", "stats": {"def": 3}, "desc": "防御 +3"},
	{"id": "yinrui", "name": "饮血", "stats": {"atk": 4}, "desc": "攻 +4"},
	{"id": "pojun", "name": "破军", "stats": {"dmg": 4}, "desc": "伤害 +4%"},
	{"id": "qingshen", "name": "轻身", "stats": {"spd": 3}, "desc": "速度 +3"},
	{"id": "tiegu", "name": "铁骨", "stats": {"hp": 80}, "desc": "气血 +80"},
]

static func affix(id: String) -> Dictionary:
	for a in AFFIXES:
		if str((a as Dictionary)["id"]) == id:
			return (a as Dictionary).duplicate(true)
	return {}

static func random_affix(it: Dictionary) -> Dictionary:
	var have: Array = it.get("affixes", [])
	var pool: Array = []
	for a in AFFIXES:
		if not have.has(str((a as Dictionary)["id"])):
			pool.append(a)
	if pool.is_empty():
		return {}
	return (pool[randi() % pool.size()] as Dictionary).duplicate(true)

static func trait_of(it: Dictionary) -> String:
	var b := blank(str(it.get("blank", "")))
	return str(b.get("trait", ""))

# ============================================================
# 图鉴合（V0.1 一条）：石头试组合；合中才进图鉴，之后扣材料一键造胚。
#   试错只亏石头，材料不动；正式造胚才吃材料。
# ============================================================
# 锻炉消耗道具：探险 NPC / 怪物掉落 / 宝箱奖励 / 货栈限购。
const TOOLS := [
	{"id": "dragon_scale", "name": "龙鳞", "desc": "下一锤不会破坏", "icon": "it_armor"},
	{"id": "regret_ink", "name": "悔恨法条", "desc": "清空这把兵器的成功衰减", "icon": "it_scroll"},
	{"id": "quench_oil", "name": "淬火油", "desc": "下一锤成功/大成功概率提高", "icon": "it_jar"},
	{"id": "star_sand", "name": "星砂", "desc": "重掷一次词缀", "icon": "it_ingot"},
]
static func tool_def(id: String) -> Dictionary:
	for t in TOOLS:
		if str((t as Dictionary)["id"]) == id:
			return (t as Dictionary).duplicate(true)
	return {}
const TRIAL_STONES := 3
const COMBOS := [
	{"id": "common", "blank": "common", "name": "普通胚子",
		"trial": ["iron_sand", "bone_coal"], "hint": "铁砂定形，骨炭收口", "cost": {"iron_sand": 1, "bone_coal": 1}},
	{"id": "gen_fan", "blank": "gen_fan", "name": "凡品胚子",
		"trial": ["iron_sand", "bone_coal"], "hint": "铁砂定形，骨炭收口", "cost": {"iron_sand": 2, "bone_coal": 2}},
	{"id": "gen_zhong", "blank": "gen_zhong", "name": "中品胚子",
		"trial": ["iron_sand", "bone_coal"], "hint": "铁砂定形，骨炭收口", "cost": {"iron_sand": 3, "bone_coal": 3}},
	{"id": "gen_shang", "blank": "gen_shang", "name": "上品胚子",
		"trial": ["iron_sand", "fine_iron"], "hint": "铁砂沉锋，精铁定钢", "cost": {"iron_sand": 4, "fine_iron": 1}},
	{"id": "gen_ji", "blank": "gen_ji", "name": "极品胚子",
		"trial": ["iron_sand", "fine_iron"], "hint": "铁砂沉锋，精铁定钢", "cost": {"iron_sand": 5, "fine_iron": 2}},
	{"id": "gen_jue", "blank": "gen_jue", "name": "绝品胚子",
		"trial": ["iron_sand", "star_iron"], "hint": "铁砂聚魂，星铁定锋", "cost": {"iron_sand": 6, "star_iron": 1}},
]

# 淬火特性：只在成器前可刷，费用逐次暴涨。
# rank：0 凡品 / 1 良品 / 2 上品 / 3 极品。越好越少见。
const QUENCH_TRAITS := [
	{"id": "wending", "name": "稳定", "desc": "维持概率 +20%", "rank": 1, "weight": 10},
	{"id": "fengli", "name": "锋利", "desc": "成功概率 +10%", "rank": 1, "weight": 10},
	{"id": "hufeng", "name": "护锋", "desc": "破坏概率 -3%", "rank": 1, "weight": 10},
	{"id": "chengshang", "name": "承伤", "desc": "损伤时，不增加裂纹与破坏累积", "rank": 1, "weight": 10},
	{"id": "jianren", "name": "坚韧", "desc": "每次损伤，破坏率额外 -2%（可叠加）", "rank": 1, "weight": 8},
	{"id": "jieshi", "name": "借势", "desc": "维持后，下一锤成功 +15%", "rank": 1, "weight": 8},
	{"id": "fuyuan", "name": "福缘", "desc": "大成功概率 +5%", "rank": 1, "weight": 6},
	{"id": "type_sword", "name": "剑胚", "desc": "首锤必成剑类", "rank": 0, "weight": 7},
	{"id": "type_dual", "name": "刀胚", "desc": "首锤必成刀类", "rank": 0, "weight": 7},
	{"id": "type_staff", "name": "棍胚", "desc": "首锤必成棍类", "rank": 0, "weight": 6},
	{"id": "type_armor", "name": "甲胚", "desc": "首锤必成护甲", "rank": 0, "weight": 6},
	{"id": "type_helm", "name": "冠胚", "desc": "首锤必成头冠", "rank": 0, "weight": 5},
	{"id": "type_cloak", "name": "披风胚", "desc": "首锤必成披风", "rank": 0, "weight": 5},
	{"id": "elem_metal", "name": "金", "desc": "升到上品时，必为金属性", "rank": 0, "weight": 7, "elem": "metal"},
	{"id": "elem_wood", "name": "木", "desc": "升到上品时，必为木属性", "rank": 0, "weight": 7, "elem": "wood"},
	{"id": "elem_water", "name": "水", "desc": "升到上品时，必为水属性", "rank": 0, "weight": 7, "elem": "water"},
	{"id": "elem_fire", "name": "火", "desc": "升到上品时，必为火属性", "rank": 0, "weight": 7, "elem": "fire"},
	{"id": "elem_earth", "name": "土", "desc": "升到上品时，必为土属性", "rank": 0, "weight": 7, "elem": "earth"},
	{"id": "dingshen", "name": "定神", "desc": "入神触发时，强化额外 +1", "rank": 2, "weight": 4},
	{"id": "huihuo", "name": "回火", "desc": "成功后，下一次损伤转为维持", "rank": 2, "weight": 4},
	{"id": "yuwei", "name": "余威", "desc": "大成功后，下一锤破坏 -10%", "rank": 2, "weight": 4},
	{"id": "xiren", "name": "惜刃", "desc": "免疫 1 次破坏，触发后消失", "rank": 2, "weight": 5},
	{"id": "xifeng", "name": "洗锋", "desc": "大成功时，清空裂纹与破坏累积", "rank": 3, "weight": 2},
	{"id": "mingdao", "name": "名刀", "desc": "免疫 3 次破坏；每次挡下清空裂纹与破坏累积", "rank": 3, "weight": 1},
	{"id": "xuhuo", "name": "续火", "desc": "成功时，返还 1 锻造石", "rank": 2, "weight": 4},
	{"id": "jiehuo", "name": "借火", "desc": "大成功后，下一锤不耗锻造石", "rank": 2, "weight": 4},
	{"id": "shouzhuo", "name": "守拙", "desc": "维持时，返还 1 锻造石", "rank": 1, "weight": 8},
	{"id": "nifeng", "name": "逆锋", "desc": "损伤后，下一锤大成功 +10%", "rank": 1, "weight": 8},
	{"id": "dieren", "name": "叠韧", "desc": "每次维持，破坏率 -1%（可叠加）", "rank": 1, "weight": 8},
]
const QUENCH_COSTS := [50, 200, 800, 3000, 12000, 50000]

static func quench_cost(n: int) -> int:
	var i := clampi(n, 0, QUENCH_COSTS.size() - 1)
	return int(QUENCH_COSTS[i])

static func quench_trait(id: String) -> Dictionary:
	for t in QUENCH_TRAITS:
		if str((t as Dictionary)["id"]) == id:
			return (t as Dictionary).duplicate(true)
	return {}

static func roll_quench_trait() -> String:
	var total := 0
	for t in QUENCH_TRAITS:
		total += int((t as Dictionary)["weight"])
	var r := randi() % maxi(1, total)
	for t in QUENCH_TRAITS:
		r -= int((t as Dictionary)["weight"])
		if r < 0:
			return str((t as Dictionary)["id"])
	return "wending"

const SELL_BASE := [8, 25, 75, 220, 600]

static func sell_price(it: Dictionary) -> int:
	var q := clampi(int(it.get("quality", 0)), 0, SELL_BASE.size() - 1)
	var mul := 1.0 + float(it.get("enhance", 0)) * 0.02
	return maxi(1, int(round(float(SELL_BASE[q]) * mul)))

static func scrap_return(it: Dictionary) -> Dictionary:
	var q := clampi(int(it.get("quality", 0)), 0, 4)
	var stones := 2 + q * 2 + int(it.get("enhance", 0)) / 5
	var mats := {"iron_sand": 1} if q <= 1 else {"fine_iron": 1}
	return {"stones": stones, "mats": mats}

static func combo(id: String) -> Dictionary:
	for c in COMBOS:
		if str((c as Dictionary)["id"]) == id:
			return (c as Dictionary).duplicate(true)
	return {}

static func combo_index(id: String) -> int:
	for i in COMBOS.size():
		if str((COMBOS[i] as Dictionary)["id"]) == id:
			return i
	return 0

static func combo_by_trial(sel: Array) -> Dictionary:
	var a: Array = []
	for k in sel:
		a.append(str(k))
	a.sort()
	for c in COMBOS:
		var t: Array = []
		for k in (c as Dictionary)["trial"]:
			t.append(str(k))
		t.sort()
		if a == t:
			return (c as Dictionary).duplicate(true)
	return {}
