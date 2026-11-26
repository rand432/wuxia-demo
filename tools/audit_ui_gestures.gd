extends SceneTree
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

var b = null
var char_page = null
var t := 0.0
var started := false
var failures: Array[String] = []
var step := 0
var step_t := 0.0
var results: Array[String] = []

func _initialize() -> void:
	seed(20261116)
	LS.ensure_loaded()
	LS.current_level = 6
	GS.ensure_loaded()
	b = BATTLE.instantiate()
	root.add_child(b)

func _process(dt: float) -> bool:
	t += dt
	if b == null and step < 10:
		return true
	if b != null and not started and t > 0.8:
		started = true
		_dismiss()
		b._crystal = 999
		b._wen = 9999
		b._draw_charge = 3
		b._trea_charge = 3
		step_t = t
	if not started:
		return false
	step_t += 0.0
	match step:
		0:
			if t > 1.4:
				_assert("draw closed", b._draw_layer == null or not b._draw_layer.visible)
				_click(b._draw_tile)
				step = 1
		1:
			if t > 1.7:
				_assert("draw open", b._draw_layer != null and b._draw_layer.visible)
				_assert("draw single view", _count_type("DrawView") <= 1)
				# 动画中关闭
				b._show_draw(false)
				step = 2
		2:
			if t > 1.9:
				_assert("draw closed mid-anim", b._draw_layer == null or not b._draw_layer.visible)
				# 按下拖出
				_press_drag_out(b._draw_tile)
				step = 3
		3:
			if t > 2.1:
				_assert("drag-out no draw", b._draw_layer == null or not b._draw_layer.visible)
				_click(b._mate_tile)
				step = 4
		4:
			if t > 2.4:
				_assert("god open", b._god_layer != null and b._god_layer.visible)
				var n: int = b._god_root.get_child_count()
				_click(b._mate_tile)
				step = 5
		5:
			if t > 2.7:
				_assert("god double click no dup", b._god_root.get_child_count() <= 3)
				b._god_layer.visible = false
				_click(b._trea_tile)
				step = 6
		6:
			if t > 3.0:
				_assert("treasure open", b._trea_layer != null and b._trea_layer.visible)
				b._trea_layer.visible = false
				_click(b._curio_sq)
				step = 7
		7:
			if t > 3.3:
				_assert("curio detail open", b._curio_detail != null and b._curio_detail.visible)
				if b._curio_detail != null:
					b._curio_detail.visible = false
				_click(b._draw_tile)
				step = 8
		8:
			if t > 3.5:
				# 连续切页：抽卡 → 请神，不应叠层
				_click(b._mate_tile)
				step = 9
		9:
			if t > 3.8:
				_assert("switch draw->god single layer", (b._god_layer != null and b._god_layer.visible) and (b._draw_layer == null or not b._draw_layer.visible))
				b.queue_free()
				b = null
				char_page = load("res://menu/character_home.tscn").instantiate()
				root.add_child(char_page)
				step = 10
		10:
			if t > 4.4:
				var slot = _find_named(char_page, "Slot_weapon")
				_assert("character slot exists", slot != null)
				if slot != null:
					_press_drag_out(slot)
				step = 11
		11:
			if t > 4.7:
				_assert("slot drag-out no dialog", _find_named(char_page, "EquipDetail") == null)
				var slot = _find_named(char_page, "Slot_weapon")
				if slot != null:
					_click(slot)
				step = 12
		12:
			if t > 5.1:
				var dlg = _find_named(char_page, "EquipDetail")
				_assert("slot click opens detail", dlg != null)
				var forge_btn = _find_button_text(dlg, "锻")
				_assert("detail has forge button", forge_btn != null)
				if forge_btn != null:
					_click(forge_btn)
				step = 13
		13:
			if t > 5.5:
				_assert("forge sheet opens", _find_named(char_page, "ForgeSheet") != null)
				_print()
				quit(0 if failures.is_empty() else 1)
	step_t = t
	return false

func _dismiss() -> void:
	var tut = b.get("_tut")
	if tut != null:
		tut.cancel()
		tut.queue_free()
		b.set("_tut", null)
	if b.has_method("_tutorial_pause"):
		b._tutorial_pause(false)
	b.set_process(true)
	if b._core != null:
		b._core.set_process(true)
		b._core.hero["hp_max"] = 1000000.0
		b._core.hero["hp"] = 1000000.0

func _click(ctrl) -> void:
	if ctrl == null:
		return
	var p: Vector2 = ctrl.get_global_transform() * (ctrl.size * 0.5)
	_push(p, true)
	_push(p, false)

func _press_drag_out(ctrl) -> void:
	if ctrl == null:
		return
	var p: Vector2 = ctrl.get_global_transform() * (ctrl.size * 0.5)
	_push(p, true)
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(8, 8)
	mv.global_position = Vector2(8, 8)
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mv, true)
	_push(Vector2(8, 8), false)

func _push(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(ev, true)

func _find_named(node: Node, name: String) -> Node:
	if node == null:
		return null
	if node.name == name:
		return node
	for c in node.get_children():
		var found := _find_named(c, name)
		if found != null:
			return found
	return null

func _find_button_text(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text.find(text) >= 0:
		return node
	for c in node.get_children():
		var found := _find_button_text(c, text)
		if found != null:
			return found
	return null

func _count_type(type: String) -> int:
	var n := 0
	for c in b.get_children():
		if c.get_class() == type:
			n += 1
	return n

func _assert(name: String, ok: bool) -> void:
	results.append(("[PASS] " if ok else "[FAIL] ") + name)
	if not ok:
		failures.append(name)

func _print() -> void:
	for s in results:
		print("[GESTURE] " + s)
	print("PASS: battle bottom bar real clicks + character slot/forge gestures" if failures.is_empty() else ("FAIL: " + str(failures)))
