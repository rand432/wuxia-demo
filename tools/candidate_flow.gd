extends SceneTree
const Iso := preload("res://tools/test_isolation.gd")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

var b = null
var results: Array[String] = []
var failures: Array[String] = []
var short := false
var negative := false
var samples: Array[float] = []
var peak_live := 0
var peak_fx := 0
var last_us := 0
var level := 6
var boss_primed := false
var draw_before_crystal := -1
var draw_before_cards := -1
var god_before_charge := -1
var god_before_skills := -1
var draw_opened := false
var draw_selected := false
var draw_cancel_ok := false
var god_opened := false
var god_selected := false
var god_cancel_ok := false
var esc_ok := false
var draw_after_open_crystal := -1
var god_after_open_charge := -1
var draw_cost_ok := false

func _initialize() -> void:
	var iso_err := Iso.verify()
	if iso_err != "":
		print("[ISOLATION] REJECT " + iso_err)
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--short": short = true
		if arg == "--negative": negative = true
	seed(20261116)
	LS.ensure_loaded()
	LS.max_unlocked = 10
	LS.current_level = 6
	GS.ensure_loaded()
	_flow()

func _flow() -> void:
	await _enter_level(6)
	await _battle_checks(6)
	if short:
		if failures.is_empty():
			_pass("短模式：仅执行 L6 抽卡/请神/Esc，未跑 L10 与结算")
		_finish()
		return
	await _enter_level(10)
	await _battle_checks(10)
	if failures.is_empty():
		_pass("候选流程 L6/L10 主界面入口、抽卡/请神真实选择、结算返回")
	_finish()

func _enter_level(lv: int) -> void:
	b = null
	level = lv
	LS.current_level = lv
	change_scene_to_file("res://menu/main_home.tscn")
	await _wait(1.0)
	var btn = _find_button_text(root, "始")
	if btn == null:
		_fail("L" + str(lv) + " 主界面找不到开始按钮")
		return
	_click(btn)
	_pass("主界面点击开始 L" + str(lv))
	await _wait(0.5)
	var t := 0.0
	var last := Time.get_ticks_usec()
	while t < 12.0:
		await process_frame
		var now0 := Time.get_ticks_usec()
		t += float(now0 - last) / 1000000.0
		last = now0
		var found = _find_battle(root)
		if found != null:
			b = found
			_dismiss()
			b._crystal = 999
			b._wen = 9999
			b._draw_charge = 3
			b._trea_charge = 3
			_pass("进入战斗 L" + str(lv))
			return
	_fail("L" + str(lv) + " 未进入战斗")

func _battle_checks(lv: int) -> void:
	if b == null:
		return
	await _run_segment("L" + str(lv) + "_normal", 30.0 if not short else 20.0, false)
	_verify_gesture_detail()
	if not negative:
		await _run_segment("L" + str(lv) + "_peak", 30.0 if not short else 6.0, true)
	if short and lv == 6:
		return
	print("[CAND][TEST] 强制失败结算 _end_run(false)")
	b._end_run(false)
	await _wait(2.0)
	var rb = _find_button_text(root, "回主界面")
	if rb == null:
		_fail("L" + str(lv) + " 结算找不到回主界面")
		return
	_click(rb)
	_pass("L" + str(lv) + " 结算点击回主界面")
	await _wait(1.0)
	var home = _find_method(root, "_start_level")
	if home != null:
		_pass("返回主界面 L" + str(lv))
	else:
		_fail("L" + str(lv) + " 返回主界面失败")

func _run_segment(seg: String, secs: float, peak: bool) -> void:
	samples = []
	peak_live = 0
	peak_fx = 0
	boss_primed = false
	last_us = Time.get_ticks_usec()
	var kills_at_start: int = b._kills
	if peak:
		print("[CAND][TEST] 受控补怪：30 普通怪 + 1 首领（固定种子 20261116）")
	else:
		draw_opened = false
		draw_selected = false
		draw_cost_ok = false
		draw_cancel_ok = false
		god_opened = false
		god_selected = false
		god_cancel_ok = false
		esc_ok = false
	var t := 0.0
	var fired := {}
	while t < secs:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last_us) / 1000000.0
		samples.append(float(now - last_us) / 1000.0)
		last_us = now
		t += dt
		if b != null and b._core != null:
			peak_live = maxi(peak_live, b._core.live_foes())
			peak_fx = maxi(peak_fx, b._frame_fx_live)
			if peak:
				_prime_peak()
			else:
				_gesture_tick(t, fired)
	_report(seg, int(b._kills) - kills_at_start)

func _gesture_tick(t: float, fired: Dictionary) -> void:
	if t > 6.0 and not fired.has("draw_open"):
		fired["draw_open"] = true
		print("[CAND][ACTION] L%d %.2fs draw_open" % [level, t])
		draw_before_crystal = b._crystal
		draw_before_cards = b._cards.size()
		_click(b.get("_draw_tile"))
		await process_frame
		if negative and b._draw_layer != null and b._draw_layer.visible:
			b._show_draw(false)
		draw_opened = (b._draw_layer != null and b._draw_layer.visible)
		draw_after_open_crystal = b._crystal
		draw_cost_ok = (draw_after_open_crystal == draw_before_crystal - 20)
	if t > 7.0 and fired.has("draw_open") and not fired.has("draw_hide"):
		fired["draw_hide"] = true
		_click(_find_button_text(b.get("_draw_layer"), "隐藏"))
		await process_frame
	if t > 8.0 and fired.has("draw_hide") and not fired.has("draw_reopen"):
		fired["draw_reopen"] = true
		_click(b.get("_draw_tile"))
		await process_frame
	if t > 8.6 and fired.has("draw_reopen") and not fired.has("draw_reopen_check"):
		fired["draw_reopen_check"] = true
		draw_cancel_ok = (b._crystal == draw_after_open_crystal)
	if t > 9.0 and fired.has("draw_reopen_check") and not fired.has("draw_pick"):
		fired["draw_pick"] = true
		print("[CAND][ACTION] L%d %.2fs draw_pick" % [level, t])
		_click(_first_card(b._draw_cards))
		await _wait(0.6)
		draw_selected = b._cards.size() > draw_before_cards and not b._draw_paid
	if t > 11.0 and not fired.has("god_open"):
		fired["god_open"] = true
		print("[CAND][ACTION] L%d %.2fs god_open" % [level, t])
		god_before_charge = b._draw_charge
		god_before_skills = b._skills.size()
		_click(b.get("_mate_tile"))
		await process_frame
		god_opened = (b._god_layer != null and b._god_layer.visible)
		god_after_open_charge = b._draw_charge
	if t > 12.0 and fired.has("god_open") and not fired.has("god_hide"):
		fired["god_hide"] = true
		_click(_find_button_text(b.get("_god_layer"), "隐藏"))
		await process_frame
	if t > 13.0 and fired.has("god_hide") and not fired.has("god_reopen"):
		fired["god_reopen"] = true
		_click(b.get("_mate_tile"))
		await process_frame
	if t > 13.6 and fired.has("god_reopen") and not fired.has("god_reopen_check"):
		fired["god_reopen_check"] = true
		god_cancel_ok = (b._draw_charge == god_after_open_charge)
	if t > 14.0 and fired.has("god_reopen_check") and not fired.has("god_pick"):
		fired["god_pick"] = true
		print("[CAND][ACTION] L%d %.2fs god_pick" % [level, t])
		_click(_first_card(b._god_root.get_children()))
		await process_frame
		god_selected = b._draw_charge == god_before_charge - 1 and b._skills.size() > god_before_skills
	if t > 15.5 and not fired.has("esc"):
		fired["esc"] = true
		print("[CAND][ACTION] L%d %.2fs back" % [level, t])
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_ESCAPE
		ev.keycode = KEY_ESCAPE
		ev.pressed = true
		root.push_input(ev, true)
		await process_frame
		esc_ok = (b._exit_layer != null and b._exit_layer.visible)
		if esc_ok:
			var back = _find_button_text(b._exit_layer, "继续")
			if back != null:
				_click(back)
			else:
				b._show_exit(false)

func _prime_peak() -> void:
	if b == null or b._core == null:
		return
	if b._core.foes.size() < 30:
		b._core._spawn_foe("normal", 1.0, 1.0)
	elif not boss_primed:
		boss_primed = true
		var boss_name := "困兽·终焉" if level == 10 else "赤焰蛟"
		b._core.start_boss(LS.boss_tier(level), boss_name)

func _verify_gesture_detail() -> void:
	var before_fail := failures.size()
	if not draw_opened: _fail("抽卡面板未打开")
	if not draw_selected: _fail("抽卡没有实际选中")
	if not draw_cost_ok: _fail("抽卡未扣 20 灵晶")
	if not draw_cancel_ok: _fail("抽卡关闭/重开后重复扣费")
	if not god_opened: _fail("请神面板未打开")
	if not god_selected: _fail("请神没有实际选中")
	if not god_cancel_ok: _fail("请神关闭/重开后次数变化")
	if not esc_ok: _fail("桌面 Esc 未打开退出面板")
	if failures.size() == before_fail:
		_pass("L%d 抽卡/请神选中、隐藏重开与 Esc 均已核对" % level)

func _report(seg: String, kills: int) -> void:
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
	print("[CAND] %s frames=%d p50=%.2f p95=%.2f p99=%.2f max=%.2f over33=%d live_peak=%d fx_peak=%d kills=%d" % [
		seg, samples.size(), p50, p95, p99, float(sorted.back()) if not sorted.is_empty() else 0.0, over, peak_live, peak_fx, kills])

func _dismiss() -> void:
	if b == null: return
	var tut = b.get("_tut")
	if tut != null:
		tut.cancel(); tut.queue_free(); b.set("_tut", null)
	if b.has_method("_tutorial_pause"): b._tutorial_pause(false)
	b.set_process(true)
	if b._core != null:
		b._core.set_process(true)
		b._core.hero["hp_max"] = 1000000.0
		b._core.hero["hp"] = 1000000.0

func _click(ctrl) -> void:
	if ctrl == null or not (ctrl is Control): return
	var c := ctrl as Control
	if not c.is_visible_in_tree(): return
	var p: Vector2 = c.get_global_transform() * (c.size * 0.5)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		ev.position = p; ev.global_position = p; ev.pressed = pressed
		root.push_input(ev, true)

func _first_card(arr) -> Control:
	if arr == null: return null
	for c in arr:
		if c is Control and (c as Control).is_visible_in_tree():
			return c as Control
	return null

func _find_battle(node: Node) -> Node:
	if node == null: return null
	if node.has_method("_show_draw") and node.get("_core") != null: return node
	for c in node.get_children():
		var f := _find_battle(c)
		if f != null: return f
	return null

func _find_method(node: Node, m: String) -> Node:
	if node == null: return null
	if node.has_method(m): return node
	for c in node.get_children():
		var f := _find_method(c, m)
		if f != null: return f
	return null

func _find_button_text(node, text: String) -> Button:
	if node == null: return null
	if node is Button:
		var bt := node as Button
		if bt.is_visible_in_tree() and bt.text.find(text) >= 0: return bt
	for c in node.get_children():
		var f := _find_button_text(c, text)
		if f != null: return f
	return null

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _pass(s: String) -> void:
	results.append("[PASS] " + s)

func _fail(s: String) -> void:
	failures.append(s)
	results.append("[FAIL] " + s)

func _finish() -> void:
	for s in results: print("[CAND] " + s)
	print("PASS: candidate flow gestures" if failures.is_empty() else "FAIL: " + str(failures))
	quit(0 if failures.is_empty() else 1)
