extends Node
# ============================================================
# tools/bench.gd —— 战斗帧率基准（一次跑 15 秒，结果追加到 .shots/bench_runs.txt）
#   用法：Godot --path <proj> res://tools/bench.tscn
#   场景：6 秒预热（不计）→ 采样第 4 秒放首领 → 共测 15 秒
# ============================================================
class BenchmarkBattle extends "res://kushou/battle_ui.gd":
	var disable_pfx := false
	var successful_casts := 0
	func _cast_skill(i: int) -> void:
		if i < 0 or i >= _skills.size(): return
		var before := float(_skills[i].get("cd_t", 0.0))
		super._cast_skill(i)
		if float(_skills[i].get("cd_t", 0.0)) > before:
			successful_casts += 1
	func _spawn_pfx(effect: String, pos: Vector2, scale_value := 1.0, pal := "", lig := 1.0, spd := 1.0, flip := false):
		if disable_pfx: return null
		return super._spawn_pfx(effect, pos, scale_value, pal, lig, spd, flip)

var _ui = null
var _dts: Array = []
var _on := false
var _boss_t := 0.0
var _boss_done := false
var _flags: Array = []
var _t := 0.0
var _spike_at: Array = []
var _cpu_ms: Array = []
var _last_frame_usec := 0
var _peak_foes := 0
var _peak_nodes := 0
var _peak_minions := 0
var _initial_casts := 0

func _process(delta: float) -> void:
	if _ui != null and _ui._tut != null and _ui._tut.visible:
		_ui._tut._on_pressed()
	if _ui != null and _flags.has("stress"):
		for attempt in range(24):
			if _ui._core.live_foes() >= 24 or _ui._core.foes.size() >= _ui._core.MAX_FOES:
				break
			_ui._core._spawn_foe("normal", 1000.0, 1.0)
	if not _on:
		return
	_t += delta
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - _last_frame_usec) / 1000.0
	_last_frame_usec = now
	if frame_ms > 34.0:
		_spike_at.append(snappedf(_t, 0.1))
	_dts.append(frame_ms)
	_cpu_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	_peak_foes = maxi(_peak_foes, _ui._core.live_foes())
	_peak_nodes = maxi(_peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_peak_minions = maxi(_peak_minions, _ui._core._minions.size() + _ui._minions.size())
	_boss_t += delta
	if not _boss_done and _boss_t >= 4.0 and not _flags.has("noboss"):
		_boss_done = true
		_ui._core.start_boss(1, "石甲巨猿")

func _ready() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		push_error("性能测试必须使用隔离项目")
		get_tree().quit(2)
		return
	seed(20261116)
	var levels := preload("res://shared/level_state.gd")
	levels.ensure_loaded()
	levels.current_level = 6
	get_window().size = Vector2i(720, 1280)
	await get_tree().create_timer(0.3).timeout
	_flags = OS.get_cmdline_user_args()
	_ui = BenchmarkBattle.new()
	_ui.disable_pfx = _flags.has("nopfx")
	add_child(_ui)
	if not _flags.has("noskill"):
		_ui._draw_charge = 1
		_ui._pick_god("jicanghai")
		_ui._hide_god_pick()
	if _flags.has("stress"):
		_ui._core.attr_set_base("hp", 1000000.0)
		_ui._core.hero["hp_max"] = 1000000.0
		_ui._core.hero["hp"] = 1000000.0
		_ui._core.attr_set_base("mp", 100300.0)
		_ui._mp = 100000.0
		_ui._draw_charge = 5
		for aid in ["zl", "qingluan", "chenshi", "gundilong", "cuisanniang"]:
			_ui._pick_god(aid)
	if _flags.has("noland"):
		for c in _ui._core.delayed_land.get_connections():
			_ui._core.delayed_land.disconnect(c["callable"])
	# 等待资源加载与初始化稳定后再采样；教程自动按实际确认操作恢复。
	await get_tree().create_timer(6.0).timeout
	_initial_casts = _ui.successful_casts
	_last_frame_usec = Time.get_ticks_usec()
	_on = true
	await get_tree().create_timer(15.0).timeout
	_on = false
	_report()
	preload("res://shared/audio.gd").quit_cleanly()

func _report() -> void:
	if _dts.is_empty():
		return
	var sorted := _dts.duplicate()
	sorted.sort()
	var n := sorted.size()
	var sum := 0.0
	for d in sorted:
		sum += float(d)
	var avg := sum / float(n)
	var p95: float = sorted[clampi(int(float(n) * 0.95), 0, n - 1)]
	var mx: float = sorted[n - 1]
	var spikes := 0
	for d in sorted:
		if float(d) > 34.0:
			spikes += 1
	var line := "flags=%s frames=%d avg_ms=%.2f p95_ms=%.2f max_ms=%.2f spikes=%d kills=%d" % [
		str(_flags),
		n, avg, p95, mx, spikes, int(_ui._kills)]
	_cpu_ms.sort()
	line += " process_p95_ms=%.2f peak_foes=%d" % [float(_cpu_ms[clampi(int(_cpu_ms.size() * 0.95), 0, _cpu_ms.size() - 1)]), _peak_foes]
	line += " peak_nodes=%d peak_minions=%d skills=%d" % [_peak_nodes, _peak_minions, _ui._skills.size()]
	line += " casts=%d" % (_ui.successful_casts - _initial_casts)
	print("[BENCH] " + line + " at=" + str(_spike_at.slice(0, 40)))
	var f := FileAccess.open("res://.shots/bench_runs.txt", FileAccess.READ_WRITE if FileAccess.file_exists("res://.shots/bench_runs.txt") else FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(line)
		f.close()
