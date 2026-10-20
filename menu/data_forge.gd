extends RefCounted
# ============================================================
# data_forge.gd —— 锻造 V0.1 的静态表（胚子 / 品质 / 数值 / 费用）
# 规则见 docs/锻造_设计稿.md：
#   · 五结果只在强化时掷；升阶不另掷
#   · +2%/级，+20 = +40%；升阶基础 ×1.5、强化归 0
#   · 入神：+10 触发，接下来 7 锤不碎
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
	{"id": "jianpei", "name": "入门剑胚", "weapon": "青锋剑", "kind": "sword",
		"quality": 0, "cap": 2, "atk": 18, "dmg": 2, "open": 0, "need": "jianpei",
		"probs": [15, 55, 20, 8, 2], "trait": "入门"},
	{"id": "qingfeng", "name": "青锋剑胚", "weapon": "青锋剑", "kind": "sword",
		"quality": 0, "cap": 2, "atk": 15, "dmg": 2, "open": 10,
		"probs": [8, 45, 25, 17, 5], "trait": "稳"},
	{"id": "zhujian", "name": "竹剑胚", "weapon": "竹剑", "kind": "sword",
		"quality": 0, "cap": 2, "atk": 12, "dmg": 1, "open": 10,
		"probs": [3, 35, 40, 17, 5], "trait": "便宜"},
	{"id": "xuantie", "name": "玄铁刀胚", "weapon": "玄铁刀", "kind": "dual",
		"quality": 1, "cap": 3, "atk": 24, "dmg": 3, "open": 20,
		"probs": [15, 30, 18, 22, 15], "trait": "赌"},
	{"id": "shangpin", "name": "上品青锋", "weapon": "上品青锋剑", "kind": "sword",
		"quality": 2, "cap": 4, "atk": 34, "dmg": 4, "open": 30,
		"probs": [10, 42, 24, 18, 6], "trait": "上品", "rule": "no_break"},
	{"id": "bicheng", "name": "天生·必成", "weapon": "必成剑", "kind": "sword",
		"quality": 0, "cap": 2, "atk": 16, "dmg": 2, "open": 20,
		"probs": [30, 70, 0, 0, 0], "trait": "必成", "rule": "always_success"},
]

static func blank(id: String) -> Dictionary:
	for b in BLANKS:
		if str((b as Dictionary)["id"]) == id:
			return (b as Dictionary).duplicate(true)
	return {}

static func quality_name(q: int) -> String:
	return QUALITY_CN[clampi(q, 0, QUALITY_CN.size() - 1)]

# 第一锤的成器档位：与「品质」分开，凡品也有破损/完美之分。
const CRAFT_GRADES := [
	{"id": "broken", "name": "破损的", "mul": 0.55, "col": Color(0.70, 0.24, 0.18)},
	{"id": "rough", "name": "粗劣的", "mul": 0.75, "col": Color(0.62, 0.42, 0.20)},
	{"id": "plain", "name": "寻常的", "mul": 1.00, "col": Color(0.45, 0.40, 0.33)},
	{"id": "fine", "name": "精良的", "mul": 1.15, "col": Color(0.28, 0.52, 0.34)},
	{"id": "perfect", "name": "完美的", "mul": 1.35, "col": Color(0.72, 0.56, 0.18)},
]

static func grade_name(g: int) -> String:
	return str((CRAFT_GRADES[clampi(g, 0, 4)] as Dictionary)["name"])

static func grade_col(g: int) -> Color:
	return (CRAFT_GRADES[clampi(g, 0, 4)] as Dictionary)["col"]

static func grade_mul(g: int) -> float:
	return float((CRAFT_GRADES[clampi(g, 0, 4)] as Dictionary)["mul"])

static func grade_weights(it: Dictionary) -> Array:
	var w := [10.0, 20.0, 35.0, 25.0, 10.0]
	if str(it.get("rule", "")) == "always_success":
		w = [0.0, 5.0, 25.0, 45.0, 25.0]
	elif str(it.get("rule", "")) == "no_break":
		w = [0.0, 5.0, 30.0, 40.0, 25.0]
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
		"quality": int(b["quality"]),
		"cap": int(b["cap"]),
		"enhance": 0,
		"cracks": 0,
		"base_atk": float(b["atk"]),
		"base_dmg": float(b["dmg"]),
		"inspired_left": 0,
		"round_inspired": false,
		"awaiting": false,
		"affixes": [],
		"craft_grade": -1,
		"rule": str(b.get("rule", "")),
	}

static func item_name(it: Dictionary) -> String:
	if it.is_empty():
		return "（无）"
	var g := int(it.get("craft_grade", -1))
	var pre := "" if g < 0 else (grade_name(g) + "·")
	return pre + quality_name(int(it.get("quality", 0))) + "·" + str(it.get("weapon", "兵器")) + " +" + str(int(it.get("enhance", 0)))

static func item_stats(it: Dictionary) -> Dictionary:
	if it.is_empty():
		return {"atk": 0, "dmg": 0}
	var mul := (1.0 + float(it.get("enhance", 0)) * 0.02) * grade_mul(int(it.get("craft_grade", 2)))
	var out := {
		"atk": int(round(float(it.get("base_atk", 0.0)) * mul)),
		"dmg": int(round(float(it.get("base_dmg", 0.0)) * mul)),
	}
	for aid in (it.get("affixes", []) as Array):
		var af := affix(str(aid))
		var st: Dictionary = af.get("stats", {})
		for k in st.keys():
			out[str(k)] = int(out.get(str(k), 0)) + int(st[k])
	return out

static func ascend_cost(q: int) -> Dictionary:
	return {"silver": 20 + 20 * clampi(q, 0, 4), "jin": 1}

static func card_set(it: Dictionary, sid: String) -> Dictionary:
	var nm := item_name(it)
	var st := item_stats(it)
	return {
		"id": sid, "name": nm, "item": nm,
		"pool": "weapon", "quality": quality_name(int(it.get("quality", 0))),
		"weapon": str(it.get("kind", "sword")),
		"no_drop": true, "forge": true, "parts": [],
		"item_stats": {"atk": int(st["atk"]), "dmg": int(st["dmg"])},
		"desc": "锻造出品（" + trait_of(it) + "）",
	}

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
const TRIAL_STONES := 3
const COMBOS := [
	{"id": "qingfeng", "blank": "qingfeng", "name": "青锋剑胚",
		"trial": ["bone", "rice"], "hint": "骨粉养锋，米浆淬火",
		"cost": {"bone": 3, "rice": 2}},
	{"id": "zhujian", "blank": "zhujian", "name": "竹剑胚",
		"trial": ["zhi", "rice"], "hint": "紫芝养竹，米浆润节",
		"cost": {"zhi": 2, "rice": 1}},
	{"id": "xuantie", "blank": "xuantie", "name": "玄铁刀胚",
		"trial": ["bone", "jin"], "hint": "骨炭沉锋，金髓定钢",
		"cost": {"bone": 4, "jin": 1}},
	{"id": "shangpin", "blank": "shangpin", "name": "上品青锋",
		"trial": ["zhi", "jin"], "hint": "紫芝养魂，金髓定锋（天生不折）",
		"cost": {"zhi": 3, "jin": 2}},
	{"id": "bicheng", "blank": "bicheng", "name": "天生·必成",
		"trial": ["rice", "jin"], "hint": "米浆定火，金髓锁锋（强化必成）",
		"cost": {"rice": 3, "jin": 1}},
]

const SELL_BASE := [8, 25, 75, 220, 600]

static func sell_price(it: Dictionary) -> int:
	var q := clampi(int(it.get("quality", 0)), 0, SELL_BASE.size() - 1)
	var mul := 1.0 + float(it.get("enhance", 0)) * 0.02
	return maxi(1, int(round(float(SELL_BASE[q]) * mul)))

static func scrap_return(it: Dictionary) -> Dictionary:
	var q := clampi(int(it.get("quality", 0)), 0, 4)
	var stones := 2 + q * 2 + int(it.get("enhance", 0)) / 5
	var mats := {"bone": 1} if q <= 1 else {"jin": 1}
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
