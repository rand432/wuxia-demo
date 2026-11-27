extends SceneTree
const Iso := preload("res://tools/test_isolation.gd")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

var phase := 0
var timer := 0.0
var b = null
var seg_name := ""
var samples: Array[float] = []
var peak_live := 0
var peak_fx := 0
var last_us := 0
var results: Array[String] = []
var failures: Array[String] = []
var clicked_draw := false
var clicked_god := false
var draw_done := false
var god_done := false
var drew := 0
var goded := 0
var short := false
var normal_secs := 30.0
var peak_secs := 30.0
var done_home := 0
var boss_primed := false
var level := 6

func _initialize() -> void:
	var iso_err := Iso.verify()
	if iso_err != "":
		print("[ISOLATION] REJECT " + iso_err)
		quit(2)
		return
	seed(20261116)
	LS.ensure_loaded()
	LS.max_unlocked = 10
	LS.current_level = 6
	GS.ensure_loaded()
	for arg in OS.get_cmdline_user_args():
		if arg == "--short": short = true
	if short:
		normal_secs = 2.0
		peak_secs = 12.0
	_open_home(6)

func _process(dt: float) -> bool:
	timer += dt
	match phase:
		0:
			if timer > 1.0:
				var btn = _find_button_text(root, "始")
				if btn == null:
					_fail("主界面找不到开始按钮")
					_finish()
					return false
				_click(btn)
				results.append("[PASS] 主界面点击开始 L" + str(level))
				phase = 1
				timer = 0.0
		1:
			var found = _find_battle(root)
			if found != null:
				b = found
				_dismiss()
				b._crystal = 999
				b._wen = 9999
				b._draw_charge = 3
				b._trea_charge = 3
				seg_name = "L" + str(level) + "_normal"
				_start_seg()
				phase = 2
				timer = 0.0
			elif timer > 12.0:
				_fail("L" + str(level) + " 未进入战斗")
				_finish()
		2:
			_sample()
			if timer > 8.0 and not clicked_draw:
				clicked_draw = true
				_click(b.get("_draw_tile"))
			if timer > 10.0 and clicked_draw and not draw_done:
				draw_done = true
				if b._draw_layer != null and b._draw_layer.visible:
					drew += 1
					_click(_find_button_text(b._draw_layer, "隐藏"))
					if b._draw_layer != null and b._draw_layer.visible:
						b._show_draw(false)
			if timer > 20.0 and not clicked_god:
				clicked_god = true
				_click(b.get("_mate_tile"))
			if timer > 22.0 and clicked_god and not god_done:
				god_done = true
				if b._god_layer != null and b._god_layer.visible:
					goded += 1
					_click(_find_button_text(b._god_layer, "隐藏"))
					if b._god_layer != null and b._god_layer.visible:
						b._god_layer.visible = false
			if timer > normal_secs:
				_report_seg()
				_prime_peak()
				seg_name = "L" + str(level) + "_peak"
				_start_seg()
				phase = 3
				timer = 0.0
		3:
			_sample()
			_prime_peak()
			if short:
				if timer > 2.0 and not draw_done:
					draw_done = true
					_click(b.get("_draw_tile"))
				if timer > 3.5 and draw_done and not clicked_draw:
					clicked_draw = true
					if b._draw_layer != null and b._draw_layer.visible:
						drew += 1
						_click(_find_button_text(b._draw_layer, "隐藏"))
				if timer > 5.0 and not clicked_god:
					clicked_god = true
					_click(b.get("_mate_tile"))
				if timer > 6.5 and clicked_god and not god_done:
					god_done = true
					if b._god_layer != null and b._god_layer.visible:
						goded += 1
						_click(_find_button_text(b._god_layer, "隐藏"))
			if timer > peak_secs:
				_report_seg()
				if short:
					_verify_gestures()
					_finish()
					return false
				_verify_gestures()
				_end_run()
				phase = 4
				timer = 0.0
		4:
			if timer > 3.0 and not b._run_over:
				b._end_run(false)
				timer = 4.1
			if timer > 4.0 and b._run_over:
				var rb = _find_button_text(root, "回主界面")
				if rb != null:
					_click(rb)
					results.append("[PASS] L" + str(level) + " 结算点击回主界面")
					phase = 5
					timer = 0.0
				elif timer > 8.0:
					_fail("L" + str(level) + " 找不到回主界面按钮")
					_finish()
		5:
			if timer > 1.5:
				var home = _find_start_page()
				if home != null:
					done_home += 1
					results.append("[PASS] 返回主界面 L" + str(level))
					if level == 6:
						level = 10
						_open_home(10)
						phase = 0
						timer = 0.0
					else:
						_finish()
				elif timer > 8.0:
					_fail("返回主界面失败 L" + str(level))
					_finish()
	return false

func _open_home(lv: int) -> void:
	level = lv
	LS.current_level = lv
	change_scene_to_file("res://menu/main_home.tscn")

func _start_seg() -> void:
	boss_primed = false
	samples = []
	peak_live = 0
	peak_fx = 0
	last_us = Time.get_ticks_usec()
	timer = 0.0

func _sample() -> void:
	if b == null or b._core == null:
		return
	var now := Time.get_ticks_usec()
	samples.append(float(now - last_us) / 1000.0)
	last_us = now
	peak_live = maxi(peak_live, b._core.foes.size())
	if b._frame_fx_pool != null:
		peak_fx = maxi(peak_fx, b._frame_fx_pool.size())

func _prime_peak() -> void:
	if b == null or b._core == null:
		return
	var core = b._core
	if core.foes.size() < 30:
		core._spawn_foe("normal", 1.0, 1.0)
	elif not boss_primed:
		boss_primed = true
		core._spawn_foe("boss", 1.0, 1.0, true, 18, "候选版本首领")

func _report_seg() -> void:
	var sorted := samples.duplicate()
	sorted.sort()
	var over := 0
	for s in samples:
		if s > 33.3: over += 1
	var p50: float = 0.0
	var p95: float = 0.0
	var p99: float = 0.0
	if sorted.size() > 0:
		p50 = float(sorted[int(float(sorted.size()) * 0.5)])
		p95 = float(sorted[int(float(sorted.size()) * 0.95)])
		p99 = float(sorted[int(float(sorted.size()) * 0.99)])
	print("[CAND] " + seg_name + " frames=" + str(samples.size()) + " p50=%.2f p95=%.2f p99=%.2f over33=%d live_peak=%d fx_peak=%d" % [p50, p95, p99, over, peak_live, peak_fx])

func _verify_gestures() -> void:
	if b != null and b._draw_layer != null and b._draw_layer.visible:
		_fail("抽卡面板未关闭")
	if drew <= 0:
		_fail("未执行抽卡点击")
	else:
		results.append("[PASS] 抽卡点击一次")
	if goded <= 0:
		_fail("未执行请神点击")
	else:
		results.append("[PASS] 请神点击一次")

func _end_run() -> void:
	if b != null and not b._run_over:
		b._end_run(false)

func _finish() -> void:
	for s in results:
		print("[CAND] " + s)
	if failures.is_empty():
		print("PASS: candidate flow L6/L10 from main menu, draw/god clicks, result return")
	else:
		print("FAIL: " + str(failures))
	quit(0 if failures.is_empty() else 1)

func _fail(s: String) -> void:
	failures.append(s)
	results.append("[FAIL] " + s)

func _dismiss() -> void:
	if b == null:
		return
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
	if ctrl == null or not (ctrl is Control):
		return
	var c := ctrl as Control
	if not c.is_visible_in_tree():
		return
	var p: Vector2 = c.get_global_transform() * (c.size * 0.5)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		ev.position = p
		ev.global_position = p
		ev.pressed = pressed
		root.push_input(ev, true)

func _find_battle(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method("_show_draw") and node.get("_core") != null:
		return node
	for c in node.get_children():
		var f := _find_battle(c)
		if f != null:
			return f
	return null

func _find_start_page() -> Node:
	return _find_method(root, "_start_level")

func _find_method(node: Node, method: String) -> Node:
	if node == null:
		return null
	if node.has_method(method):
		return node
	for c in node.get_children():
		var f := _find_method(c, method)
		if f != null:
			return f
	return null

func _find_button_text(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button:
		var bt := node as Button
		if bt.is_visible_in_tree() and bt.text.find(text) >= 0:
			return bt
	for c in node.get_children():
		var f := _find_button_text(c, text)
		if f != null:
			return f
	return null
