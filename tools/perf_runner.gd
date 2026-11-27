extends Control
const Iso := preload("res://tools/test_isolation.gd")
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

var b = null
var scenario := "normal"
var duration := 30.0
var warm := 4.0
var run_seed := 20261116
var t := 0.0
var samples: Array[float] = []
var first_samples: Array[float] = []
var peak_live := 0
var peak_nodes := 0
var peak_fx := 0
var load_ms := 0.0
var done := false
var prime_cd := 0.0
var skill_cd := 0.0
var boss_primed := false
var last_us := 0

func _exit_tree() -> void:
	print("[PERF] exit_tree")

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		print("[PERF] predelete")

func _ready() -> void:
	seed(run_seed)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="): scenario = arg.get_slice("=", 1)
		if arg.begins_with("--duration="): duration = clampf(float(arg.get_slice("=", 1)), 5.0, 120.0)
		if arg.begins_with("--warm="): warm = clampf(float(arg.get_slice("=", 1)), 0.0, 20.0)
		if arg.begins_with("--seed="): run_seed = int(arg.get_slice("=", 1))
	process_mode = PROCESS_MODE_ALWAYS
	seed(run_seed)
	LS.ensure_loaded()
	LS.current_level = 6
	GS.ensure_loaded()
	var t0 := Time.get_ticks_usec()
	b = BATTLE.instantiate()
	add_child(b)
	load_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	if b._tut != null:
		b._tut.cancel()
		b._tut.queue_free()
		b._tut = null
	b._tutorial_pause(false)
	b.set_process(true)
	if b._core != null:
		b._core.set_process(true)
	last_us = Time.get_ticks_usec()
	if b._core != null:
		b._core.hero["hp_max"] = 1000000.0
		b._core.hero["hp"] = 1000000.0
	print("[PERF] start scenario=" + scenario + " project=" + OS.get_user_data_dir())

func _process(dt: float) -> void:
	if b == null or done:
		return
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - last_us) / 1000.0
	last_us = now
	t += dt
	if b._core.hero != null and float(b._core.hero.get("hp", 0.0)) < 900000.0:
		b._core.hero["hp"] = float(b._core.hero["hp_max"])
	if int(b._core.foes.size()) > peak_live: peak_live = int(b._core.foes.size())
	var nodes := _count_nodes(b)
	if nodes > peak_nodes: peak_nodes = nodes
	var fx_n: int = 0
	if b._frame_fx_pool != null:
		fx_n = b._frame_fx_pool.size()
	if fx_n > peak_fx: peak_fx = fx_n
	if get_tree().paused:
		get_tree().paused = false
	if Engine.get_process_frames() % 60 == 0:
		print("[PERF] tick t=%.1f over=%s paused=%s hp=%.0f foes=%d" % [t, str(b._run_over), str(get_tree().paused), float(b._core.hero.get("hp", -1.0)), b._core.foes.size()])
	if t < warm:
		if t > 0.5:
			_prime()
		return
	if first_samples.size() < 60:
		first_samples.append(frame_ms)
	samples.append(frame_ms)
	if not scenario.is_empty() and scenario != "normal":
		prime_cd -= dt
		if prime_cd <= 0.0:
			prime_cd = 0.02
			_prime()
	if scenario == "boss":
		skill_cd -= dt
		if skill_cd <= 0.0:
			skill_cd = 2.0
			if b._core != null and b.has_method("_cast_skill") and b._skills.size() > 0:
				b._cast_skill(0)
	if t >= warm + duration:
		done = true
		_report()
		get_tree().quit(0)

func _prime() -> void:
	if b == null or b._core == null:
		return
	var core = b._core
	match scenario:
		"swarm":
			if core.foes.size() < 34:
				core._spawn_foe("normal", 1.0, 1.0)
			elif core.foes.size() < 40:
				core._spawn_foe("champion", 1.0, 1.0, false, 6, "挑战怪")
		"boss":
			if not boss_primed and t > 1.0:
				boss_primed = true
				core._spawn_foe("boss", 1.0, 1.0, true, 18, "压力首领")
			elif core.foes.size() < 30:
				core._spawn_foe("normal", 1.0, 1.0)
		_:
			pass

func _count_nodes(node: Node) -> int:
	var n := 1
	for c in node.get_children():
		n += _count_nodes(c)
	return n

func _pct(arr: Array[float], p: float) -> float:
	if arr.is_empty(): return 0.0
	var a := arr.duplicate()
	a.sort()
	var idx := clampi(int(round(float(a.size() - 1) * p)), 0, a.size() - 1)
	return float(a[idx])

func _report() -> void:
	var over := 0
	var over50 := 0
	var max_i := 0
	for i in range(samples.size()):
		if samples[i] > 33.3: over += 1
		if samples[i] > 50.0: over50 += 1
		if samples[i] > samples[max_i]: max_i = i
	var adapter := RenderingServer.get_video_adapter_name()
	var viewport := get_viewport().get_visible_rect().size
	print("[PERF] scenario=%s seed=%d duration=%.0fs warm=%.0fs viewport=%dx%d renderer=%s adapter=%s" % [
		scenario, run_seed, duration, warm, int(viewport.x), int(viewport.y), str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), adapter])
	print("[PERF] frames=%d p50=%.2f p95=%.2f p99=%.2f max=%.2f max_at=%.1fs over33=%d over50=%d first60_max=%.2f load_ms=%.1f" % [
		samples.size(), _pct(samples, 0.50), _pct(samples, 0.95), _pct(samples, 0.99),
		_pct(samples, 1.0), warm + float(max_i) / 60.0, over, over50, _pct(first_samples, 1.0), load_ms])
	print("[PERF] peak_live=%d peak_nodes=%d peak_fx_pool=%d core_wave=%d kills=%d" % [
		peak_live, peak_nodes, peak_fx, int(b._core.wave), int(b._kills)])
