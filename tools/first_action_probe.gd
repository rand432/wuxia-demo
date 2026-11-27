extends SceneTree
const Iso := preload("res://tools/test_isolation.gd")
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

var b = null
var t := 0.0
var action := "load"
var last_us := 0
var longs: Array = []
var samples: Array[float] = []
var fired := {}
var mark_t := 0.0
var seg_log: Array = []
var boss_forced := false

func _initialize() -> void:
	var e := Iso.verify()
	if e != "":
		print("[FA] ISOLATION_REJECT " + e)
		quit(2); return
	seed(20261116)
	LS.ensure_loaded(); LS.current_level = 6; LS.max_unlocked = 10
	GS.ensure_loaded()
	b = BATTLE.instantiate()
	root.add_child(b)
	last_us = Time.get_ticks_usec()

func _process(dt: float) -> bool:
	if b == null or not b.is_inside_tree():
		return true
	t += dt
	var now := Time.get_ticks_usec()
	var ms := float(now - last_us) / 1000.0
	last_us = now
	samples.append(ms)
	if b._tut != null:
		b._tut.cancel(); b._tut.queue_free(); b.set("_tut", null); b._tutorial_pause(false)
	if b._core != null:
		b._core.set_process(true)
		if b._core.foes.size() < 16:
			b._core._spawn_foe("normal", 1.0, 1.0)
	if ms > 33.3:
		longs.append({"t": t, "ms": ms, "action": action, "live": b._core.foes.size() if b._core else -1,
			"fx": _fx_count(), "pool": b._frame_fx_pool.size() if b._frame_fx_pool != null else -1})
	_actions()
	if t >= 18.0:
		_report()
		quit(0)
	return false

func _actions() -> void:
	if t > 3.0 and not fired.has("challenge"):
		fired["challenge"] = true
		_set_action("challenge")
		if b._core.has_method("spawn_challenge"):
			b._core.spawn_challenge(4, 1)
	if t > 5.0 and not fired.has("draw"):
		fired["draw"] = true
		_set_action("draw_open")
		b._crystal = 999
		_click(b.get("_draw_tile"))
	if t > 6.0 and not fired.has("draw_close"):
		fired["draw_close"] = true
		_set_action("draw_close")
		_click(_find_button_text(b.get("_draw_layer"), "隐藏"))
	if t > 7.0 and not fired.has("god"):
		fired["god"] = true
		_set_action("god_open")
		b._draw_charge = 3
		_click(b.get("_mate_tile"))
	if t > 8.0 and not fired.has("god_close"):
		fired["god_close"] = true
		_set_action("god_close")
		_click(_find_button_text(b.get("_god_layer"), "隐藏"))
	if t > 9.0 and not fired.has("boss"):
		fired["boss"] = true
		_set_action("boss_entry")
		b._core._spawn_foe("boss", 1.0, 1.0, true, 18, "长帧首领")
	if t > 12.0 and not boss_forced:
		boss_forced = true
		_set_action("boss_skill")
		var fb = b._core._boss_foe()
		if not (fb as Dictionary).is_empty():
			fb["ult_t"] = 0.05
	if t > 15.0 and not fired.has("result"):
		fired["result"] = true
		_set_action("result")
		b._end_run(false)

func _set_action(name: String) -> void:
	action = name
	mark_t = t
	print("[FA] t=%.2f action=%s live=%d fx=%d pool=%d" % [t, name, b._core.foes.size() if b._core else -1,
		_fx_count(), b._frame_fx_pool.size() if b._frame_fx_pool != null else -1])

func _fx_count() -> int:
	var n := 0
	if b._fx_front != null: n += b._fx_front.get_child_count()
	if b._fx_back != null: n += b._fx_back.get_child_count()
	return n

func _report() -> void:
	var sorted := samples.duplicate(); sorted.sort()
	var over := 0
	for s in samples:
		if s > 33.3: over += 1
	var p95: float = 0.0
	var p99: float = 0.0
	if sorted.size() > 0:
		p95 = float(sorted[int(float(sorted.size()) * 0.95)])
		p99 = float(sorted[int(float(sorted.size()) * 0.99)])
	print("[FA] frames=%d over33=%d p95=%.2f p99=%.2f" % [samples.size(), over, p95, p99])
	for l in longs:
		print("[LONG] t=%.2f ms=%.1f action=%s live=%d fx=%d pool=%d" % [l["t"], l["ms"], l["action"], l["live"], l["fx"], l["pool"]])
	print("[FA] LONG_COUNT=" + str(longs.size()))

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

func _find_button_text(node, text: String) -> Button:
	if node == null: return null
	if node is Button:
		var bt := node as Button
		if bt.is_visible_in_tree() and bt.text.find(text) >= 0: return bt
	for c in node.get_children():
		var f := _find_button_text(c, text)
		if f != null: return f
	return null
