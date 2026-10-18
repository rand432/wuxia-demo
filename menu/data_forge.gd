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
	{"id": "qingfeng", "name": "青锋剑胚", "weapon": "青锋剑", "kind": "sword",
		"quality": 0, "cap": 2, "atk": 15, "dmg": 2, "open": 10,
		"probs": [8, 45, 25, 17, 5], "trait": "稳"},
	{"id": "zhujian", "name": "竹剑胚", "weapon": "竹剑", "kind": "sword",
		"quality": 0, "cap": 2, "atk": 12, "dmg": 1, "open": 10,
		"probs": [3, 35, 40, 17, 5], "trait": "便宜"},
	{"id": "xuantie", "name": "玄铁刀胚", "weapon": "玄铁刀", "kind": "saber",
		"quality": 1, "cap": 3, "atk": 24, "dmg": 3, "open": 20,
		"probs": [15, 30, 18, 22, 15], "trait": "赌"},
	{"id": "shangpin", "name": "上品青锋", "weapon": "上品青锋剑", "kind": "sword",
		"quality": 2, "cap": 4, "atk": 34, "dmg": 4, "open": 30,
		"probs": [10, 42, 24, 18, 6], "trait": "上品"},
]

static func blank(id: String) -> Dictionary:
	for b in BLANKS:
		if str((b as Dictionary)["id"]) == id:
			return (b as Dictionary).duplicate(true)
	return {}

static func quality_name(q: int) -> String:
	return QUALITY_CN[clampi(q, 0, QUALITY_CN.size() - 1)]

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
	}

static func item_name(it: Dictionary) -> String:
	if it.is_empty():
		return "（无）"
	return quality_name(int(it.get("quality", 0))) + "·" + str(it.get("weapon", "兵器")) + " +" + str(int(it.get("enhance", 0)))

static func item_stats(it: Dictionary) -> Dictionary:
	if it.is_empty():
		return {"atk": 0, "dmg": 0}
	var mul := 1.0 + float(it.get("enhance", 0)) * 0.02
	return {
		"atk": int(round(float(it.get("base_atk", 0.0)) * mul)),
		"dmg": int(round(float(it.get("base_dmg", 0.0)) * mul)),
	}

static func ascend_cost(q: int) -> Dictionary:
	return {"silver": 20 + 20 * clampi(q, 0, 4), "jin": 1}

static func trait_of(it: Dictionary) -> String:
	var b := blank(str(it.get("blank", "")))
	return str(b.get("trait", ""))
