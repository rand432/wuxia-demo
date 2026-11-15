extends RefCounted

const SaveFile := preload("res://shared/save_file.gd")
# ============================================================
# shared/forge_data.gd —— 装备 / 锻造数据
#   品质：定强化上限 + 每级增幅 + 边框色
#   品阶：每 20 级 +1，纯好看
#   特性：锻造时给特殊加成
# ============================================================
const QUALITY_NAME := ["凡品", "良品", "玄品", "地品", "天品"]
const QUALITY_CAP := [20, 40, 60, 80, 99]
const QUALITY_GAIN := [1.0, 1.2, 1.4, 1.65, 1.9]

const SLOT_KEYS := ["weapon", "armor", "jade", "cloak"]
const SLOT_LABEL := {"weapon": "兵 器", "armor": "护 甲", "jade": "玉 佩", "cloak": "披 风"}
const SLOT_BASE := {"weapon": 12.0, "armor": 6.0, "jade": 60.0, "cloak": 4.0}
const SLOT_ART := {
	"weapon": "res://assets/items/it_sword.png",
	"armor": "res://assets/items/it_armor.png",
	"jade": "res://assets/items/art_stone.png",
	"cloak": "res://assets/gen/char/qing_cogflash.png",
}

const TRAITS := {
	"不折": "破坏权重 ×0.6",
	"锋锐": "大成功权重 ×1.5",
	"稳手": "维持权重 ×1.4",
	"贪狼": "损伤后大成功再 ×1.3",
}

# ---- 玩家身上的装备（内存态，后面接存档）----
static var equipped := {
	"weapon": {"name": "短剑", "quality": 3, "plus": 11, "trait": "稳手"},
	"armor": {},
	"jade": {},
	"cloak": {},
}
static var bag: Array = []
static var _bag_ready := false

const _WPN := ["铁剑", "长刀", "短刀", "重剑", "柳叶刀", "飞匕", "青锋", "赤霄"]
const _ARM := ["皮甲", "铁甲", "锁子甲", "软甲", "战袍", "护心镜"]
const _JADE := ["玉佩", "玉环", "玉坠"]
const _CLOAK := ["披风", "斗篷", "披帛"]
const _MAT := ["朱果", "兽骨", "灵米", "紫芝", "雪参", "金髓", "赤铜", "玄铁", "寒晶", "火髓", "风灵", "雷精"]
const _TOOL := ["龙鳞", "淬火油", "星砂", "悔恨法条", "锻造石", "银两袋", "定神香", "炉心病"]

static func ensure_bag() -> void:
	if _bag_ready:
		return
	_bag_ready = true
	for i in 18:
		var nm := str(_WPN[i % _WPN.size()]) if i < 8 else (str(_ARM[i % _ARM.size()]) if i < 14 else str(_JADE[i % _JADE.size()]))
		var slot := "weapon" if i < 8 else ("armor" if i < 14 else "jade")
		var icon: String = str(SLOT_ART.get(slot, "res://assets/items/it_sword.png"))
		bag.append({"cat": "装备", "slot": slot, "name": nm, "quality": 1 + (i % 5),
			"plus": (i * 3) % 20, "icon": icon})
	for i in 16:
		bag.append({"cat": "材料", "slot": "", "name": str(_MAT[i % _MAT.size()]),
			"quality": 1 + (i % 5), "plus": 0, "icon": "res://assets/items/art_spring.png" if i % 3 == 0 else ("res://assets/items/art_stone.png" if i % 3 == 1 else "res://assets/items/it_ingot.png")})
	for i in 12:
		bag.append({"cat": "道具", "slot": "", "name": str(_TOOL[i % _TOOL.size()]),
			"quality": 1 + (i % 5), "plus": 0, "icon": "res://assets/items/chest_gold.png" if i % 2 == 0 else "res://assets/items/art_stone.png"})

static func bag_of(cat: String) -> Array:
	ensure_bag()
	if cat == "":
		return bag
	var out: Array = []
	for it in bag:
		if str(it.get("cat", "")) == cat:
			out.append(it)
	return out

static func qname(q: int) -> String:
	return QUALITY_NAME[clampi(q - 1, 0, 4)]

static func cap(q: int) -> int:
	return QUALITY_CAP[clampi(q - 1, 0, 4)]

static func gain(q: int) -> float:
	return QUALITY_GAIN[clampi(q - 1, 0, 4)]

static func grade_of(plus: int) -> int:
	return 1 + int(floor(float(plus) / 20.0))

static func stat_of(it: Dictionary, equipped_slot: String = "") -> float:
	if it.is_empty():
		return 0.0
	var slot := equipped_slot if equipped_slot != "" else str(it.get("slot", "weapon"))
	var base: float = SLOT_BASE.get(slot, 12.0)
	var v := base * gain(int(it.get("quality", 1))) * (1.0 + 0.02 * float(it.get("plus", 0)))
	return round(v)

static func totals() -> Dictionary:
	var t := {"atk": 0.0, "def": 0.0, "hp": 0.0, "spd": 0.0}
	for key in SLOT_KEYS:
		var it: Dictionary = equipped.get(key, {})
		if it.is_empty():
			continue
		var v := stat_of(it, key)
		match key:
			"weapon": t["atk"] = float(t["atk"]) + v
			"armor": t["def"] = float(t["def"]) + v
			"jade": t["hp"] = float(t["hp"]) + v
			"cloak": t["spd"] = float(t["spd"]) + v
	return t
# ============================================================
# 锻造机制（状态机）
#   破坏权重 = 裂纹 × 2.5（裂纹 0~5）；平时为 0
#   本锤结果改写下一锤：损→大×1.5+裂纹+1 · 维→成×1.35
#                      成→维×1.3 损×1.25 · 大→维×1.4 损×1.4 裂纹−1
#   入神：槽 10 格，一锤 +1（大成功 +2），满自动入神 = 接下来 6 锤不碎
# ============================================================
const BASE_W := {"破": 0.0, "损": 14.0, "维": 26.0, "成": 50.0, "大": 10.0}
const MODS := {
	"损": {"大": 1.5},
	"维": {"成": 1.35},
	"成": {"维": 1.3, "损": 1.25},
	"大": {"维": 1.4, "损": 1.4},
}
const BREAK_PER_CRACK := 2.5
const GAUGE_MAX := 10
const TRANCE_HAMMERS := 6
const CRACK_MAX := 5
const COST_ORE := 1
const COST_SILVER := 10
const OIL_SUCCESS_WEIGHT_MULT := 1.5

const ITEM_KEYS := ["龙鳞", "悔恨法条", "淬火油", "星砂"]
const ITEM_ICON := {
	"龙鳞": "res://assets/items/it_armor.png",
	"悔恨法条": "res://assets/items/art_spring.png",
	"淬火油": "res://assets/items/chest_gold.png",
	"星砂": "res://assets/items/art_stone.png",
}
const ITEM_DESC := {
	"龙鳞": "下一锤若「破坏」，则挡下。",
	"悔恨法条": "撤销上一锤，不返还材料；使用其他道具后失效。",
	"淬火油": "下一锤成功/大成功权重 ×1.5，不叠加。",
	"星砂": "入神 +3 格。",
}
const ITEM_USE := {"龙鳞": "protect", "悔恨法条": "undo", "淬火油": "oil", "星砂": "star"}

static var ores := 37
static var silver := 1240
static var items := {"龙鳞": 1, "悔恨法条": 0, "淬火油": 3, "星砂": 2}
static var state := {}      # slot -> {crack, gauge, trance, protect, last}

static func st_of(key: String) -> Dictionary:
	if not state.has(key):
		state[key] = {"crack": 0, "gauge": 0, "trance": 0, "protect": 0, "last": ""}
	return state[key]

static func weights(st: Dictionary, trait_name: String) -> Dictionary:
	var w := BASE_W.duplicate()
	var tr := int(st.get("trance", 0))
	w["破"] = 0.0 if tr > 0 else BREAK_PER_CRACK * float(st.get("crack", 0))
	var last := str(st.get("last", ""))
	if MODS.has(last):
		for kk in MODS[last]:
			w[kk] = float(w[kk]) * float(MODS[last][kk])
	match trait_name:
		"不折":
			w["破"] = float(w["破"]) * 0.6
		"锋锐":
			w["大"] = float(w["大"]) * 1.5
		"稳手":
			w["维"] = float(w["维"]) * 1.4
		"贪狼":
			if last == "损":
				w["大"] = float(w["大"]) * 1.3
	if int(st.get("oil", 0)) > 0:
		w["成"] = float(w["成"]) * OIL_SUCCESS_WEIGHT_MULT
		w["大"] = float(w["大"]) * OIL_SUCCESS_WEIGHT_MULT
	return w

static func odds(st: Dictionary, trait_name: String) -> Dictionary:
	var w := weights(st, trait_name)
	var tot := 0.0
	for k in w:
		tot += float(w[k])
	var out := {}
	for k in w:
		out[k] = (float(w[k]) / tot) * 100.0 if tot > 0.0 else 0.0
	return out

static func roll(it: Dictionary, equipped_slot: String = "") -> String:
	var key := equipped_slot if equipped_slot != "" else str(it.get("slot", "weapon"))
	var st := st_of(key)
	var w := weights(st, str(it.get("trait", "")))
	var tot := 0.0
	for k in w:
		tot += float(w[k])
	if tot <= 0.0:
		return "成"
	var r := randf() * tot
	var acc := 0.0
	for k in ["破", "损", "维", "成", "大"]:
		acc += float(w[k])
		if r <= acc:
			return k
	return "成"

# 返回 {"plus": 变化, "crack": 变化, "gauge": 变化, "trance": 是否进入, "broke": bool, "blocked": bool}
static func apply(it: Dictionary, res: String, equipped_slot: String = "") -> Dictionary:
	var key := equipped_slot if equipped_slot != "" else str(it.get("slot", "weapon"))
	var st := st_of(key)
	st.erase("oil")   # 不论本锤结果如何，只作用一次
	var out := {"plus": 0, "crack": 0, "gauge": 0, "trance": false, "broke": false, "blocked": false}
	match res:
		"大":
			out["plus"] = 2
			out["crack"] = -1
			out["gauge"] = 2
		"成":
			out["plus"] = 1
			out["gauge"] = 1
		"维":
			out["gauge"] = 1
		"损":
			out["plus"] = -1
			out["crack"] = 1
			out["gauge"] = 1
		"破":
			if int(st.get("protect", 0)) > 0:
				st["protect"] = int(st["protect"]) - 1
				out["blocked"] = true
				out["gauge"] = 1
			else:
				out["broke"] = true
	st["last"] = res
	if not bool(out["broke"]):
		var cap_plus := cap(int(it.get("quality", 1)))
		var np := clampi(int(it.get("plus", 0)) + int(out["plus"]), 0, cap_plus)
		it["plus"] = np
		st["crack"] = clampi(int(st.get("crack", 0)) + int(out["crack"]), 0, CRACK_MAX)
		if int(st.get("trance", 0)) > 0:
			st["trance"] = maxi(0, int(st["trance"]) - 1)
		var g := int(st.get("gauge", 0)) + int(out["gauge"])
		if g >= GAUGE_MAX:
			g = 0
			st["trance"] = TRANCE_HAMMERS
			out["trance"] = true
		st["gauge"] = clampi(g, 0, GAUGE_MAX)
	return out
# ============================================================
# 存档：equipped / bag / 资源 / 每件装备的运行时状态
# ============================================================
const SAVE_PATH := "user://forge.cfg"
static var _loaded := false

static func load_game() -> void:
	if _loaded:
		return
	if SaveFile.recover() != OK:
		push_error("未完成的首通奖励恢复失败，保留恢复记录")
		return
	_loaded = true
	ensure_bag()
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	ores = int(cf.get_value("res", "ores", ores))
	silver = int(cf.get_value("res", "silver", silver))
	var it_v = cf.get_value("res", "items", null)
	if it_v is Dictionary:
		items = it_v
	var eq_v = cf.get_value("res", "equipped", null)
	if eq_v is Dictionary:
		equipped = eq_v
	var bg_v = cf.get_value("res", "bag", null)
	if bg_v is Array:
		bag = bg_v
	var st_v = cf.get_value("res", "state", null)
	if st_v is Dictionary:
		state = st_v

static func save_game() -> Error:
	var cf := ConfigFile.new()
	cf.set_value("res", "ores", ores)
	cf.set_value("res", "silver", silver)
	cf.set_value("res", "items", items)
	cf.set_value("res", "equipped", equipped)
	cf.set_value("res", "bag", bag)
	cf.set_value("res", "state", state)
	var err := SaveFile.write(cf, SAVE_PATH)
	if err != OK:
		push_error("存档保存失败：%s (%s)" % [SAVE_PATH, error_string(err)])
	return err

static func sell_equipped(slot: String) -> bool:
	load_game()
	var item: Dictionary = equipped.get(slot, {})
	if item.is_empty():
		return false
	var previous_silver := silver
	var had_state := state.has(slot)
	var previous_state = state.get(slot)
	equipped[slot] = {}
	state.erase(slot)
	silver += 40 + int(item.get("plus", 0)) * 6
	if save_game() == OK:
		return true
	equipped[slot] = item
	silver = previous_silver
	if had_state:
		state[slot] = previous_state
	return false

# 一锤的材料、装备和状态只在同一次保存成功后结算。
static func hammer(slot: String) -> Dictionary:
	load_game()
	var item: Dictionary = equipped.get(slot, {})
	if item.is_empty():
		return {"ok": false, "reason": "该部位没有装备"}
	if int(item.get("plus", 0)) >= cap(int(item.get("quality", 1))):
		return {"ok": false, "reason": "已达到强化上限"}
	if ores < COST_ORE or silver < COST_SILVER:
		return {"ok": false, "reason": "材料不够"}
	var previous_equipped := equipped.duplicate(true)
	var previous_state := state.duplicate(true)
	var previous_ores := ores
	var previous_silver := silver
	ores -= COST_ORE
	silver -= COST_SILVER
	var before_item := item.duplicate(true)
	var before_slot := st_of(slot).duplicate(true)
	before_slot.erase("undo")
	var result := roll(item, slot)
	var outcome := apply(item, result, slot)
	if not bool(outcome["broke"]):
		st_of(slot)["undo"] = {"item": before_item, "state": before_slot}
	if bool(outcome["broke"]):
		equipped[slot] = {}
		state.erase(slot)
	if save_game() != OK:
		equipped = previous_equipped
		state = previous_state
		ores = previous_ores
		silver = previous_silver
		return {"ok": false, "reason": "保存失败，材料与装备已恢复，请重试"}
	return {"ok": true, "result": result, "outcome": outcome}

static func use_forge_item(slot: String, name: String) -> Dictionary:
	load_game()
	if not ITEM_USE.has(name) or int(items.get(name, 0)) <= 0:
		return {"ok": false, "reason": "道具不足"}
	var item: Dictionary = equipped.get(slot, {})
	if item.is_empty():
		return {"ok": false, "reason": "该部位没有装备"}
	if str(ITEM_USE[name]) == "oil" and int((state.get(slot, {}) as Dictionary).get("oil", 0)) > 0:
		return {"ok": false, "reason": "已使用淬火油，请先锻造一锤"}
	var undo = (state.get(slot, {}) as Dictionary).get("undo", null)
	if str(ITEM_USE[name]) == "undo":
		if not undo is Dictionary or not undo.get("item") is Dictionary or not undo.get("state") is Dictionary:
			return {"ok": false, "reason": "没有可撤销的上一锤"}
	var previous_equipped := equipped.duplicate(true)
	var previous_state := state.duplicate(true)
	var previous_items := items.duplicate(true)
	items[name] = int(items[name]) - 1
	var st := st_of(slot)
	var entered_trance := false
	match str(ITEM_USE[name]):
		"protect": st["protect"] = int(st.get("protect", 0)) + 1
		"star":
			var gauge := int(st.get("gauge", 0)) + 3
			if gauge >= GAUGE_MAX:
				st["gauge"] = 0
				st["trance"] = TRANCE_HAMMERS
				entered_trance = true
			else:
				st["gauge"] = gauge
		"oil": st["oil"] = 1
		"undo":
			equipped[slot] = (undo["item"] as Dictionary).duplicate(true)
			state[slot] = (undo["state"] as Dictionary).duplicate(true)
	if str(ITEM_USE[name]) != "undo":
		st.erase("undo")
	if save_game() != OK:
		equipped = previous_equipped
		state = previous_state
		items = previous_items
		return {"ok": false, "reason": "保存失败，道具与装备已恢复，请重试"}
	return {"ok": true, "trance": entered_trance}
