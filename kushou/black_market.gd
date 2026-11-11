extends Control

# 黑市 / 仓库 / 装备（首版）
# - 六格随机货；Lv1-5 黑市经验；杀敌数刷新；30% 一件 7/5/3 折
# - 购买的装备/道具进仓库；装备格 6 格任意放；装备无使用，只取出/存入
# - 属性走 v6 新层：装备给临时攻击/气血/固定减免，神器再加专属效果
# - 不暂停：面板打开时战斗继续

const FONT := preload("res://fonts/ink.ttf")
const INK := Color(0.13, 0.12, 0.11)
const PAPER := Color(0.93, 0.90, 0.82)
const PAPER_HI := Color(0.97, 0.95, 0.89)
const GOLD := Color(0.85, 0.66, 0.23)
const SEAL := Color(0.66, 0.22, 0.15)
const DIM := Color(0.42, 0.38, 0.32)
const LIGHT := Color(0.91, 0.87, 0.78)
const QUAL := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
const TYPECOL := {"消耗": Color(0.31,0.48,0.29), "装备": Color(0.18,0.42,0.45), "道具": Color(0.42,0.29,0.48)}
const LEVEL_EXP := [20, 50, 90, 140]

var core = null
var ui = null
var level := 1
var exp := 0
var stock: Array = []
var warehouse: Array = []
var slots: Array = []
var view := "shop"
var refresh_n := 0
var discount_i := -1
var discount_m := 1.0
var selected_kind := ""
var selected_i := -1
var _inv_offset := 0
var periodic_atk := 0.0
var periodic_t := 0.0
var _sword_wave := -1
var _xuanwu_wave := -1
var _jade_used := false
var _boot_t := 0.0
var _buy_rects: Array = []
var _inv_rects: Array = []
var _slot_rects: Array = []
var _close_rect := Rect2()
var _refresh_rect := Rect2()
var _warehouse_rect := Rect2()
var _back_rect := Rect2()
var _take_rect := Rect2()
var _store_rect := Rect2()
var _use_rect := Rect2()

func setup(p_core, p_ui) -> void:
	core = p_core
	ui = p_ui
	slots.resize(6)
	warehouse.clear()
	stock.clear()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	if core != null:
		core.hero_foe_hit.connect(_on_hero_foe_hit)
		core.kill.connect(_on_kill)
		core.hero_down.connect(_on_hero_down)
	_roll_stock()

func _has_equipped(nm: String) -> bool:
	for it in slots:
		if it != null and str(it.get("name", "")) == nm:
			return true
	return false

func _on_hero_foe_hit(tgt: Dictionary, dmg: float, crit: bool, heavy: bool) -> void:
	if tgt.is_empty():
		return
	# 赤霄剑：每波首次普攻追加剑气
	if _has_equipped("赤霄剑"):
		var w := int(core.wave)
		if _sword_wave != w:
			_sword_wave = w
			core._apply_dmg(tgt, dmg * 0.5, core.DMG_PHYS)
	# 断岳刀：普攻溅射
	if _has_equipped("断岳刀"):
		for f in core.foes:
			if f != tgt and float(f.get("dying", 0.0)) <= 0.0:
				core._apply_dmg(f, dmg * 0.3, core.DMG_PHYS)
	# 朱雀羽：暴击灼烧
	if _has_equipped("朱雀羽") and crit and ui != null:
		ui._apply_burn(tgt, 1.0, 4.0)

func _on_kill(_n: int) -> void:
	# 踏云靴：击杀后短暂攻速
	if _has_equipped("踏云靴"):
		core.attr_add_amp("aspd", 0.2)
		_boot_t = 2.0

func _on_hero_down() -> void:
	var w := int(core.wave)
	# 玄武甲：每波首次致命免死
	if _has_equipped("玄武甲") and _xuanwu_wave != w:
		_xuanwu_wave = w
		core.hero["hp"] = maxf(1.0, core.attr_final("hp") * 0.25)
		if ui != null:
			ui._toast("玄武甲：免死")
		return
	# 长生玉：一次免死
	if _has_equipped("长生玉") and not _jade_used:
		_jade_used = true
		core.hero["hp"] = maxf(1.0, core.attr_final("hp") * 0.3)
		if ui != null:
			ui._toast("长生玉：免死")

func open_panel() -> void:
	view = "shop"
	visible = true
	move_to_front()
	queue_redraw()

func close_panel() -> void:
	visible = false
	selected_kind = ""
	selected_i = -1
	queue_redraw()

func add_kill(n: int) -> void:
	exp += maxi(1, n)
	while level < 5:
		var need: int = LEVEL_EXP[level - 1]
		if exp < need:
			break
		exp -= need
		level += 1
		if ui != null:
			ui._toast("黑市升到 Lv %d" % level)
		_grant_seal_gifts()
	queue_redraw()

# ---------------- 数据 ----------------
func _catalog() -> Dictionary:
	return {
		"normal": [
			{"name":"铁剑","kind":"normal","type":"装备","q":2,"lvl":1,"price":40,"icon":"res://assets/items/it_sword.png","stats":{"atk":4.0},"text":"攻击 +4"},
			{"name":"青锋剑","kind":"normal","type":"装备","q":2,"lvl":1,"price":55,"icon":"res://assets/items/it_sword.png","stats":{"atk":7.0},"text":"攻击 +7"},
			{"name":"皮甲","kind":"normal","type":"装备","q":2,"lvl":1,"price":40,"icon":"res://assets/items/chest_gold.png","stats":{"hp":50.0,"red":2.0},"text":"气血 +50 · 固定减免 +2%"},
			{"name":"玄鳞甲","kind":"normal","type":"装备","q":3,"lvl":2,"price":70,"icon":"res://assets/items/chest_gold.png","stats":{"hp":40.0,"red":4.0},"text":"气血 +40 · 固定减免 +4%"},
			{"name":"白玉佩","kind":"normal","type":"装备","q":3,"lvl":2,"price":60,"icon":"res://assets/items/chest_jade.png","stats":{"red":5.0},"text":"固定减免 +5%"},
			{"name":"血玉佩","kind":"normal","type":"装备","q":3,"lvl":2,"price":65,"icon":"res://assets/items/chest_jade.png","stats":{"atk":3.0,"hp":30.0},"text":"攻击 +3 · 气血 +30"},
			{"name":"追风靴","kind":"normal","type":"装备","q":3,"lvl":2,"price":60,"icon":"res://assets/items/art_spring.png","stats":{"hp":30.0,"red":3.0},"text":"气血 +30 · 固定减免 +3%"},
			{"name":"云纹靴","kind":"normal","type":"装备","q":4,"lvl":3,"price":85,"icon":"res://assets/items/art_spring.png","stats":{"atk":2.0,"red":4.0},"text":"攻击 +2 · 固定减免 +4%"},
		],
		"artifact": [
			{"name":"赤霄剑","kind":"artifact","type":"装备","q":5,"lvl":4,"price":220,"icon":"res://assets/items/it_sword.png","stats":{"atk":7.0},"text":"攻击 +7 · 每波首击追加剑气","special":"first_sword"},
			{"name":"断岳刀","kind":"artifact","type":"装备","q":5,"lvl":4,"price":240,"icon":"res://assets/items/it_sword.png","stats":{"atk":8.0},"text":"攻击 +8 · 普攻溅射","special":"splash"},
			{"name":"朱雀羽","kind":"artifact","type":"装备","q":5,"lvl":4,"price":240,"icon":"res://assets/items/art_bell.png","stats":{"atk":6.0},"text":"攻击 +6 · 暴击灼烧","special":"burn"},
			{"name":"踏云靴","kind":"artifact","type":"装备","q":5,"lvl":4,"price":220,"icon":"res://assets/items/art_spring.png","stats":{"hp":30.0,"red":2.0},"text":"气血 +30 · 击杀后短暂攻速","special":"kill_speed"},
			{"name":"玄武甲","kind":"artifact","type":"装备","q":5,"lvl":4,"price":260,"icon":"res://assets/items/chest_gold.png","stats":{"hp":70.0,"red":6.0},"text":"气血 +70 · 固定减免 +6% · 每波首次致命减伤","special":"first_guard"},
			{"name":"长生玉","kind":"artifact","type":"装备","q":5,"lvl":4,"price":260,"icon":"res://assets/items/chest_jade.png","stats":{"hp":60.0,"red":4.0},"text":"气血 +60 · 固定减免 +4% · 首次致命免死","special":"revive"},
		],
		"consumable": [
			{"name":"生命丹","kind":"consumable","type":"消耗","q":2,"lvl":1,"price":20,"icon":"res://assets/ui/shop_pill.png","stats":{"hp":30.0},"text":"立即回 30 气血"},
			{"name":"攻击丹","kind":"consumable","type":"消耗","q":2,"lvl":1,"price":20,"icon":"res://assets/ui/shop_pill.png","stats":{"atk":3.0},"text":"永久攻击 +3"},
			{"name":"疾风散","kind":"consumable","type":"消耗","q":3,"lvl":2,"price":30,"icon":"res://assets/ui/shop_pill.png","stats":{"periodic":1.0},"text":"每 10 秒攻击 +1"},
		],
		"prop": [
			{"name":"进阶刷新令","kind":"prop","type":"道具","q":3,"lvl":2,"price":25,"icon":"res://assets/items/it_book.png","effect":"aug_reroll","text":"进阶刷新 +1"},
			{"name":"吞噬丹","kind":"prop","type":"道具","q":3,"lvl":2,"price":30,"icon":"res://assets/items/mat_bone.png","effect":"devour","text":"随机吞噬卡组一张，保留进度"},
			{"name":"灵晶丹","kind":"prop","type":"道具","q":2,"lvl":1,"price":25,"icon":"res://assets/items/loot_exp.png","effect":"crystal","value":20,"text":"灵晶 +20"},
			{"name":"文钱丹","kind":"prop","type":"道具","q":2,"lvl":1,"price":20,"icon":"res://assets/items/chest_gold.png","effect":"wen","value":100,"text":"文钱 +100"},
			{"name":"杀敌丹","kind":"prop","type":"道具","q":2,"lvl":1,"price":25,"icon":"res://assets/items/loot_silver.png","effect":"kills","value":10,"text":"杀敌数 +10"},
			{"name":"黑市经验丹","kind":"prop","type":"道具","q":3,"lvl":2,"price":30,"icon":"res://assets/items/it_scroll.png","effect":"bm_exp","value":10,"text":"黑市经验 +10"},
			{"name":"黑市药契","kind":"prop","type":"道具","q":5,"lvl":3,"price":150,"icon":"res://assets/items/art_bell.png","effect":"passive","text":"黑市每升1级随机丹药","unique":true},
			{"name":"黑市兵契","kind":"prop","type":"道具","q":5,"lvl":3,"price":180,"icon":"res://assets/items/it_scroll.png","effect":"passive","text":"黑市每升1级随机装备","unique":true},
		],
	}

func _roll_stock() -> void:
	stock.clear()
	var cat := _catalog()
	var pool: Array = []
	for it in cat["normal"]:
		if int(it["lvl"]) <= level + 1:
			pool.append(it)
	for it in cat["consumable"]:
		if int(it["lvl"]) <= level + 1:
			pool.append(it)
	for it in cat["prop"]:
		if int(it["lvl"]) <= level + 1:
			if bool(it.get("unique", false)) and _has_item(str(it["name"])):
				continue
			pool.append(it)
	if level >= 4:
		for it in cat["artifact"]:
			pool.append(it)
	for i in 6:
		var it: Dictionary = pool[randi() % pool.size()]
		var base := int(it["price"])
		if int(it["lvl"]) > level:
			base = int(round(base * 1.4))
		var offer := {"item": it.duplicate(true), "base": base, "sold": false}
		stock.append(offer)
	discount_i = -1
	discount_m = 1.0
	if randf() < 0.30:
		discount_i = randi() % 6
		var r := randf()
		discount_m = 0.7 if r < 0.5 else (0.5 if r < 0.8 else 0.3)
	queue_redraw()

func _offer_price(i: int) -> int:
	if i < 0 or i >= stock.size():
		return 0
	var base: int = int(stock[i]["base"])
	if i == discount_i:
		return maxi(1, int(round(base * discount_m)))
	return base

func _refresh_cost() -> int:
	return 10 + 10 * refresh_n

func _spend_kills(n: int) -> bool:
	if ui == null:
		return false
	if ui._kills < n:
		ui._toast("杀敌数不够")
		return false
	ui._kills -= n
	if ui._kill_lb != null:
		ui._kill_lb.text = str(ui._kills)
	return true

func _add_item_to_warehouse(it: Dictionary) -> void:
	warehouse.append(it)

func _has_item(nm: String) -> bool:
	for it in warehouse:
		if str(it.get("name", "")) == nm:
			return true
	for it in slots:
		if it != null and str(it.get("name", "")) == nm:
			return true
	return false

func _grant_seal_gifts() -> void:
	var cat := _catalog()
	if _has_item("黑市药契"):
		var arr: Array = cat["consumable"]
		var it: Dictionary = (arr[randi() % arr.size()] as Dictionary).duplicate(true)
		_apply_consumable(it)
		if ui != null:
			ui._toast("药契：获得 %s" % str(it.get("name", "")))
	if _has_item("黑市兵契"):
		var pool: Array = []
		for it2 in cat["normal"]:
			pool.append(it2)
		if level >= 4:
			for it3 in cat["artifact"]:
				pool.append(it3)
		var eq: Dictionary = (pool[randi() % pool.size()] as Dictionary).duplicate(true)
		_give_equipment(eq)

func _give_equipment(it: Dictionary) -> void:
	var empty := _empty_slot()
	if empty >= 0:
		slots[empty] = it
		_apply_item(it)
		if ui != null:
			ui._toast("兵契：%s 已装备" % str(it.get("name", "")))
	else:
		warehouse.append(it)
		if ui != null:
			ui._toast("兵契：%s 已进仓库" % str(it.get("name", "")))
	queue_redraw()

func _buy(i: int) -> void:
	if i < 0 or i >= stock.size():
		return
	var offer: Dictionary = stock[i]
	if bool(offer.get("sold", false)):
		return
	var price := _offer_price(i)
	if not _spend_kills(price):
		return
	var it: Dictionary = offer["item"]
	match str(it.get("kind", "")):
		"consumable":
			_apply_consumable(it)
		_:
			_add_item_to_warehouse(it)
	offer["sold"] = true
	selected_kind = ""
	queue_redraw()

func _refresh_stock() -> void:
	var cost := _refresh_cost()
	if not _spend_kills(cost):
		return
	refresh_n += 1
	_roll_stock()

func _apply_consumable(it: Dictionary) -> void:
	var st: Dictionary = it.get("stats", {})
	if st.has("hp"):
		core.attr_add("hp", float(st["hp"]))
		core.hero["hp_max"] = float(core.hero.get("hp_max", 1.0)) + float(st["hp"])
		core.hero["hp"] = minf(float(core.hero.get("hp_max", 1.0)), float(core.hero.get("hp", 0.0)) + float(st["hp"]))
	if st.has("atk"):
		core.attr_add("atk", float(st["atk"]))
		core.hero["atk"] = float(core.hero.get("atk", 0.0)) + float(st["atk"])
	if st.has("periodic"):
		periodic_atk += float(st["periodic"])
	if ui != null:
		ui._toast("用了 %s" % str(it.get("name", "")))

func _apply_item(it: Dictionary) -> void:
	var st: Dictionary = it.get("stats", {})
	if st.has("atk"):
		core.attr_add("atk", float(st["atk"]))
		core.hero["atk"] = float(core.hero.get("atk", 0.0)) + float(st["atk"])
	if st.has("hp"):
		core.attr_add("hp", float(st["hp"]))
		core.hero["hp_max"] = float(core.hero.get("hp_max", 1.0)) + float(st["hp"])
		core.hero["hp"] = float(core.hero.get("hp", 0.0)) + float(st["hp"])
	if st.has("red"):
		for t in core.DMG_TYPES:
			if t != core.DMG_TRUE:
				core.type_add(t, "red_f", float(st["red"]) / 100.0)

func _remove_item(it: Dictionary) -> void:
	var st: Dictionary = it.get("stats", {})
	if st.has("atk"):
		core.attr_add("atk", -float(st["atk"]))
		core.hero["atk"] = maxf(1.0, float(core.hero.get("atk", 0.0)) - float(st["atk"]))
	if st.has("hp"):
		core.attr_add("hp", -float(st["hp"]))
		core.hero["hp_max"] = maxf(1.0, float(core.hero.get("hp_max", 1.0)) - float(st["hp"]))
		core.hero["hp"] = minf(float(core.hero.get("hp_max", 1.0)), float(core.hero.get("hp", 0.0)))
	if st.has("red"):
		for t in core.DMG_TYPES:
			if t != core.DMG_TRUE:
				core.type_add(t, "red_f", -float(st["red"]) / 100.0)

func _empty_slot() -> int:
	for i in slots.size():
		if slots[i] == null:
			return i
	return -1

func _take_out(idx: int) -> void:
	if idx < 0 or idx >= warehouse.size():
		return
	var empty := _empty_slot()
	if empty < 0:
		ui._toast("装备格已满，取不出来")
		return
	var it: Dictionary = warehouse[idx]
	slots[empty] = it
	warehouse.remove_at(idx)
	_apply_item(it)
	selected_kind = ""
	selected_i = -1
	queue_redraw()

func _store(i: int) -> void:
	if i < 0 or i >= slots.size() or slots[i] == null:
		return
	var it: Dictionary = slots[i]
	slots[i] = null
	warehouse.append(it)
	_remove_item(it)
	selected_kind = ""
	selected_i = -1
	queue_redraw()

func _use_prop(idx: int) -> void:
	if idx < 0 or idx >= warehouse.size():
		return
	var it: Dictionary = warehouse[idx]
	if str(it.get("type", "")) != "道具":
		return
	match str(it.get("effect", "")):
		"aug_reroll":
			ui._aug_reroll += 1
			ui._toast("进阶刷新 +1")
		"devour":
			ui._devour_random()
			ui._toast("吞噬丹：随机吞了一张卡")
		"crystal":
			ui._crystal += int(it.get("value", 0))
			ui._update_crystal()
			ui._toast("灵晶 +%d" % int(it.get("value", 0)))
		"wen":
			ui._add_wen(int(it.get("value", 0)))
			ui._toast("文钱 +%d" % int(it.get("value", 0)))
		"kills":
			ui._kills += int(it.get("value", 0))
			if ui._kill_lb != null:
				ui._kill_lb.text = str(ui._kills)
			ui._toast("杀敌数 +%d" % int(it.get("value", 0)))
		"bm_exp":
			add_kill(int(it.get("value", 0)))
			ui._toast("黑市经验 +%d" % int(it.get("value", 0)))
	warehouse.remove_at(idx)
	selected_kind = ""
	selected_i = -1
	queue_redraw()

func _process(delta: float) -> void:
	if _boot_t > 0.0:
		_boot_t -= delta
		if _boot_t <= 0.0:
			core.attr_add_amp("aspd", -0.2)
	if periodic_atk <= 0.0:
		return
	periodic_t += delta
	while periodic_t >= 10.0:
		periodic_t -= 10.0
		if core != null:
			core.attr_add("atk", periodic_atk)
			core.hero["atk"] = float(core.hero.get("atk", 0.0)) + periodic_atk

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if view == "warehouse":
			_inv_offset += -2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2
			queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if view == "shop":
			if _close_rect.has_point(p):
				close_panel()
				return
			if _warehouse_rect.has_point(p):
				view = "warehouse"
				selected_kind = ""
				selected_i = -1
				queue_redraw()
				return
			if _refresh_rect.has_point(p):
				_refresh_stock()
				return
			for i in _buy_rects.size():
				if (_buy_rects[i] as Rect2).has_point(p):
					_buy(i)
					return
		else:
			if _close_rect.has_point(p) or _back_rect.has_point(p):
				view = "shop"
				selected_kind = ""
				selected_i = -1
				queue_redraw()
				return
			for i in _slot_rects.size():
				if (_slot_rects[i] as Rect2).has_point(p):
					selected_kind = "slot"
					selected_i = i
					queue_redraw()
					return
			for j in _inv_rects.size():
				if (_inv_rects[j] as Rect2).has_point(p):
					selected_kind = "inv"
					selected_i = mini(_inv_offset, maxi(0, warehouse.size() - 1)) + j
					queue_redraw()
					return
			if _take_rect.has_point(p):
				if selected_kind == "inv":
					_take_out(selected_i)
				return
			if _store_rect.has_point(p):
				if selected_kind == "slot":
					_store(selected_i)
				return
			if _use_rect.has_point(p):
				if selected_kind == "inv":
					_use_prop(selected_i)
				return

func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(0, 0, 720, 1280), Color(0, 0, 0, 0.55), true)
	draw_rect(Rect2(36, 120, 648, 1088), Color(0.10, 0.09, 0.08, 0.98), true)
	draw_rect(Rect2(36, 120, 648, 2), Color(0.85, 0.66, 0.23, 0.8), true)
	if view == "shop":
		_draw_shop()
	else:
		_draw_warehouse()

func _txt(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string(FONT, pos, s, align, w, size, col)

func _btn(rect: Rect2, label: String, size: int, bg: Color, fg: Color) -> void:
	draw_rect(rect, bg, true)
	draw_rect(rect, Color(0.85, 0.66, 0.23, 0.45), false, 1.0)
	_txt(Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + size * 0.35), label, size, fg, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)

func _draw_shop() -> void:
	_txt(Vector2(64, 160), "黑市", 40, Color(0.95, 0.92, 0.85))
	_txt(Vector2(64, 196), "Lv%d" % level, 20, GOLD)
	_txt(Vector2(120, 196), "经验 %d/%d" % [exp, LEVEL_EXP[min(level - 1, 4)]], 15, Color(0.78, 0.72, 0.62))
	_txt(Vector2(64, 224), "杀敌 %d" % (ui._kills if ui != null else 0), 18, Color(0.85, 0.80, 0.70))
	_btn(Rect2(600, 130, 56, 36), "×", 24, Color(0.10, 0.09, 0.08), Color(0.90, 0.86, 0.78))
	_close_rect = Rect2(600, 130, 56, 36)
	_buy_rects.clear()
	var cat := _catalog()
	for i in stock.size():
		var col := i % 2
		var row := i / 2
		var r := Rect2(60 + col * 310, 250 + row * 250, 290, 236)
		var offer: Dictionary = stock[i]
		var it: Dictionary = offer["item"]
		var q: Color = QUAL[clampi(int(it.get("q", 2)), 0, 4)]
		draw_rect(r, Color(0.97, 0.95, 0.89, 0.98), true)
		draw_rect(r, q, false, 3.0)
		var tcol: Color = TYPECOL.get(str(it.get("type", "消耗")), DIM)
		draw_rect(Rect2(r.position.x + 10, r.position.y + 8, 52, 22), tcol, true)
		_txt(Vector2(r.position.x + 36, r.position.y + 23), str(it.get("type", "消耗")), 12, Color(0.97, 0.95, 0.89), HORIZONTAL_ALIGNMENT_CENTER, 52)
		var icon: Texture2D = load(str(it.get("icon", "")))
		if icon != null:
			draw_texture_rect(icon, Rect2(r.position.x + 18, r.position.y + 42, 40, 40), false)
		_txt(Vector2(r.position.x + 68, r.position.y + 66), str(it.get("name", "")), 21, INK)
		var parts: Array = str(it.get("text", "")).split(" · ")
		for j in parts.size():
			_txt(Vector2(r.position.x + 12, r.position.y + 112 + j * 19), str(parts[j]), 13, Color(0.24, 0.21, 0.18), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24)
		var price := _offer_price(i)
		if i == discount_i:
			_txt(Vector2(r.position.x + 12, r.position.y + 196), str(int(offer["base"])), 15, Color(0.52, 0.46, 0.38))
			draw_line(Vector2(r.position.x + 10, r.position.y + 190), Vector2(r.position.x + 48, r.position.y + 190), Color(0.52, 0.46, 0.38), 1.0)
			_txt(Vector2(r.position.x + 56, r.position.y + 196), "%d折 %d" % [int(discount_m * 10), price], 16, SEAL)
		else:
			_txt(Vector2(r.position.x + 12, r.position.y + 196), "%d 杀敌" % price, 16, Color(0.24, 0.21, 0.18))
		var br := Rect2(r.position.x + r.size.x - 84, r.position.y + r.size.y - 40, 72, 30)
		if bool(offer.get("sold", false)):
			_btn(br, "已售罄", 14, Color(0.55, 0.50, 0.42), Color(0.95, 0.92, 0.85))
		else:
			_btn(br, "买", 17, SEAL, Color(0.97, 0.95, 0.89))
			_buy_rects.append(br)
	# 底栏
	_btn(Rect2(60, 1010, 250, 54), "刷新 · %d 杀敌" % _refresh_cost(), 18, SEAL, Color(0.97, 0.95, 0.89))
	_refresh_rect = Rect2(60, 1010, 250, 54)
	_btn(Rect2(330, 1010, 160, 54), "仓库/装备", 18, Color(0.18, 0.16, 0.14), Color(0.90, 0.86, 0.78))
	_warehouse_rect = Rect2(330, 1010, 160, 54)
	_btn(Rect2(510, 1010, 120, 54), "关闭", 18, Color(0.18, 0.16, 0.14), Color(0.90, 0.86, 0.78))
	_txt(Vector2(60, 1092), "30% 概率一件 7/5/3 折；买掉即空，刷新补货。", 12, Color(0.62, 0.57, 0.48))

func _draw_warehouse() -> void:
	_txt(Vector2(64, 160), "仓库/装备", 38, Color(0.95, 0.92, 0.85))
	_txt(Vector2(64, 196), "装备格 %d/6　不能卖 · 可替换" % _filled_slots(), 15, Color(0.78, 0.72, 0.62))
	_btn(Rect2(600, 130, 56, 36), "×", 24, Color(0.10, 0.09, 0.08), Color(0.90, 0.86, 0.78))
	_close_rect = Rect2(600, 130, 56, 36)
	_back_rect = Rect2(60, 1000, 150, 50)
	_btn(_back_rect, "返回黑市", 17, Color(0.18, 0.16, 0.14), Color(0.90, 0.86, 0.78))
	# 仓库物品 2x4
	_txt(Vector2(60, 230), "仓库物品", 18, Color(0.90, 0.86, 0.78))
	_inv_rects.clear()
	_inv_offset = clampi(_inv_offset, 0, maxi(0, warehouse.size() - 1))
	var start := mini(_inv_offset, maxi(0, warehouse.size() - 1))
	for j in mini(8, maxi(0, warehouse.size() - start)):
		var i := start + j
		var col := j % 2
		var row := j / 2
		var r := Rect2(60 + col * 145, 250 + row * 120, 130, 108)
		_inv_rects.append(r)
		var it: Dictionary = warehouse[i]
		_draw_item_cell(r, it, selected_kind == "inv" and selected_i == i)
	# 装备格 2x3
	_txt(Vector2(420, 230), "装备格", 18, Color(0.90, 0.86, 0.78))
	_slot_rects.clear()
	for i in 6:
		var col := i % 2
		var row := i / 2
		var r := Rect2(420 + col * 130, 250 + row * 120, 120, 108)
		_slot_rects.append(r)
		if slots[i] != null:
			_draw_item_cell(r, slots[i], selected_kind == "slot" and selected_i == i)
		else:
			draw_rect(r, Color(0.16, 0.14, 0.12), true)
			draw_rect(r, Color(0.38, 0.34, 0.28), false, 1.0)
			_txt(Vector2(r.position.x, r.position.y + 56), "空", 18, Color(0.45, 0.41, 0.35), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# 选中详情
	var sel: Dictionary = {}
	if selected_kind == "inv" and selected_i >= 0 and selected_i < warehouse.size():
		sel = warehouse[selected_i]
	elif selected_kind == "slot" and selected_i >= 0 and selected_i < 6 and slots[selected_i] != null:
		sel = slots[selected_i]
	draw_rect(Rect2(60, 770, 600, 210), Color(0.14, 0.12, 0.10), true)
	draw_rect(Rect2(60, 770, 600, 1), Color(0.85, 0.66, 0.23, 0.5), true)
	if sel.is_empty():
		_txt(Vector2(80, 800), "点一件仓库物品或装备格看详情", 15, Color(0.62, 0.57, 0.48))
	else:
		_txt(Vector2(80, 800), str(sel.get("name", "")) + "　·　" + str(sel.get("type", "")), 23, Color(0.95, 0.92, 0.85))
		var parts: Array = str(sel.get("text", "")).split(" · ")
		for j in parts.size():
			_txt(Vector2(80, 832 + j * 21), str(parts[j]), 15, Color(0.78, 0.72, 0.62))
		_txt(Vector2(80, 860), "不可出售", 13, SEAL)
		_take_rect = Rect2(80, 900, 150, 50)
		_store_rect = Rect2(250, 900, 150, 50)
		_use_rect = Rect2(420, 900, 150, 50)
		if str(sel.get("type", "")) == "道具":
			_btn(_take_rect, "取出", 18, Color(0.18, 0.16, 0.14), Color(0.90, 0.86, 0.78))
			_btn(_use_rect, "使用", 18, SEAL, Color(0.97, 0.95, 0.89))
		else:
			_btn(_take_rect, "取出", 18, Color(0.18, 0.16, 0.14), Color(0.90, 0.86, 0.78))
			_btn(_store_rect, "存入", 18, Color(0.18, 0.16, 0.14), Color(0.90, 0.86, 0.78))

func _filled_slots() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += 1
	return n

func _draw_item_cell(r: Rect2, it: Dictionary, selected: bool) -> void:
	var q: Color = QUAL[clampi(int(it.get("q", 2)), 0, 4)]
	draw_rect(r, Color(0.97, 0.95, 0.89, 0.98) if selected else Color(0.24, 0.21, 0.18), true)
	draw_rect(r, GOLD if selected else q, false, 3.0 if selected else 2.0)
	var icon: Texture2D = load(str(it.get("icon", "")))
	if icon != null:
		draw_texture_rect(icon, Rect2(r.position.x + 45, r.position.y + 12, 36, 36), false)
	_txt(Vector2(r.position.x, r.position.y + 78), str(it.get("name", "")), 17, INK if selected else Color(0.93, 0.90, 0.82), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
