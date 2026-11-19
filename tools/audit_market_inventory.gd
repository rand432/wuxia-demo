extends SceneTree
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")
class BattleProbe extends "res://kushou/battle_ui.gd":
	var reenter := ""
	func _toast(t: String) -> void:
		if reenter == "buy": _bm._buy(0)
		elif reenter == "use": _bm._use_prop(0)
		super._toast(t)

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 8
	var b := BattleProbe.new()
	root.add_child(b)
	b.set_process(false)
	b._core.set_process(false)
	var m = b._bm
	m.set_process(false)
	m.slots.fill(null)
	var catalogue: Dictionary = m._catalog()
	var passive: Dictionary = catalogue["prop"].filter(func(it): return it.get("unique", false))[0].duplicate(true)
	var prop: Dictionary = catalogue["prop"].filter(func(it): return it.get("effect", "") == "wen")[0].duplicate(true)
	for it in [prop, passive, catalogue["consumable"][0], {"type": "道具", "effect": "unknown"}]:
		m.warehouse = [it.duplicate(true)]
		m._take_out(0)
		assert(m.warehouse.size() == 1 and m._filled_slots() == 0)
		if it != prop:
			m._use_prop(0)
			assert(m.warehouse.size() == 1)
	m.warehouse.clear()
	m.discount_i = -1
	m.stock = [{"base": 10, "item": passive.duplicate(true)}, {"base": 10, "item": passive.duplicate(true)}]
	b._kills = 100
	m._buy(0)
	m._buy(0)
	m._buy(1)
	assert(b._kills == 90 and m.warehouse.size() == 1 and m.stock[0]["sold"] and not m.stock[1].get("sold", false))
	# 商品效果回调重入同货位不再扣费/加属性。
	m.stock = [{"base": 20, "item": catalogue["consumable"][1].duplicate(true)}]
	var atk: float = b._core.attr_final("atk")
	b.reenter = "buy"
	m._buy(0)
	b.reenter = ""
	assert(b._kills == 70 and b._core.attr_final("atk") == atk + 3.0)
	m.warehouse = [prop.duplicate(true), {"type": "道具", "effect": "crystal", "value": 20}]
	var wen: int = b._wen
	var crystal: int = b._crystal
	b.reenter = "use"
	m._use_prop(0)
	b.reenter = ""
	assert(b._wen == wen + 100 and b._crystal == crystal and m.warehouse.size() == 1 and not m._using_prop)
	if DisplayServer.get_name() != "headless":
		await _ui_cases(b, catalogue, passive, prop)
	else:
		print("INFO: graphical hit rectangles and screenshots require the separate rendered run")
	b.queue_free()
	await process_frame
	print("PASS: inventory type safety, passive/unknown prop retention, unique purchase and reward callback reentry")
	Audio.quit_cleanly()

func _frame(m) -> void:
	m.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw

func _click(m, rect: Rect2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = rect.get_center()
	m._gui_input(e)

func _has_icon_detail(im: Image, rect: Rect2i) -> bool:
	var colors := {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			colors[im.get_pixel(x, y).to_rgba32()] = true
			if colors.size() > 8:
				return true
	return false

func _ui_cases(b, catalogue: Dictionary, passive: Dictionary, prop: Dictionary) -> void:
	var m = b._bm
	await create_timer(0.6).timeout # 等入场遮罩淡出后再验图，避免把转场中间帧当最终界面。
	m.warehouse = [passive.duplicate(true)]
	m.stock = [{"base": 11, "sold": true, "item": catalogue["normal"][0].duplicate(true)},
		{"base": 22, "item": passive.duplicate(true)}, {"base": 33, "item": catalogue["normal"][1].duplicate(true)}]
	b._kills = 200
	m.open_panel()
	await _frame(m)
	assert(m._buy_rects.size() == 3 and not m._buy_rects[0].has_area() and not m._buy_rects[1].has_area() and m._buy_rects[2].has_area())
	var shop_image := root.get_texture().get_image()
	assert(_has_icon_detail(shop_image, Rect2i(78, 292, 40, 40)))
	assert(shop_image.save_png("res://market_shop.png") == OK)
	var icons: int = m._item_icons.size()
	await _frame(m)
	assert(m._item_icons.size() == icons)
	_click(m, m._buy_rects[2])
	assert(b._kills == 167 and m.stock[2]["sold"] and m.warehouse.back()["name"] == catalogue["normal"][1]["name"])
	m.warehouse = [prop.duplicate(true), catalogue["normal"][0].duplicate(true)]
	m.view = "warehouse"
	m.selected_kind = "inv"
	m.selected_i = 0
	await _frame(m)
	assert(not m._take_rect.has_area() and not m._store_rect.has_area() and m._use_rect.has_area())
	var prop_image := root.get_texture().get_image()
	assert(_has_icon_detail(prop_image, Rect2i(105, 262, 36, 36)))
	assert(prop_image.save_png("res://market_prop.png") == OK)
	_click(m, Rect2(80, 900, 150, 50)) # 原来的取出位置已不可操作。
	assert(m.warehouse.size() == 2 and m._filled_slots() == 0)
	_click(m, m._use_rect)
	assert(m.warehouse.size() == 1)
	await _frame(m)
	assert(not m._take_rect.has_area() and not m._store_rect.has_area() and not m._use_rect.has_area())
	m.selected_kind = "inv"
	m.selected_i = 0
	await _frame(m)
	assert(m._take_rect.has_area() and not m._use_rect.has_area() and not m._store_rect.has_area())
	_click(m, m._take_rect)
	assert(m.warehouse.is_empty() and m._filled_slots() == 1)
	m.selected_kind = "slot"
	m.selected_i = 0
	await _frame(m)
	assert(not m._take_rect.has_area() and not m._use_rect.has_area() and m._store_rect.has_area())
	print("PASS: rendered shop keeps sold/owned stock indices; GUI buys correct later offer; warehouse buttons follow type/selection; icons retain texture detail and cache")
