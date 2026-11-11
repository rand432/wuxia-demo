extends Node
# ============================================================
# tools/bench.gd —— 战斗帧率基准（一次跑 15 秒，结果追加到 .shots/bench_runs.txt）
#   用法：Godot --path <proj> res://tools/bench.tscn
#   场景：2 秒预热（不计）→ 第 4 秒放首领 → 共测 15 秒
# ============================================================
var _ui = null
var _dts: Array = []
var _on := false
var _boss_t := 0.0
var _boss_done := false
var _flags: Array = []
var _t := 0.0
var _spike_at: Array = []

func _process(delta: float) -> void:
	if not _on:
		return
	_t += delta
	if delta * 1000.0 > 34.0:
		_spike_at.append(snappedf(_t, 0.1))
	_dts.append(delta * 1000.0)
	_boss_t += delta
	if not _boss_done and _boss_t >= 4.0 and not _flags.has("noboss"):
		_boss_done = true
		_ui._core.start_boss(1, "石甲巨猿")

func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	await get_tree().create_timer(0.3).timeout
	_ui = (load("res://kushou/battle_ui.tscn") as PackedScene).instantiate()
	add_child(_ui)
	_flags = OS.get_cmdline_user_args()
	if _flags.has("nopfx"):
		_ui._pfx_root = null
	if _flags.has("noland"):
		for c in _ui._core.delayed_land.get_connections():
			_ui._core.delayed_land.disconnect(c["callable"])
	# 预热烘焙（_prewarm_pfx 会串行烘 30 个变体，前几秒本身就会卡）——等它跑完再计时
	await get_tree().create_timer(6.0).timeout
	_on = true
	await get_tree().create_timer(15.0).timeout
	_on = false
	_report()
	get_tree().quit()

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
	print("[BENCH] " + line + " at=" + str(_spike_at.slice(0, 40)))
	var f := FileAccess.open("res://.shots/bench_runs.txt", FileAccess.READ_WRITE if FileAccess.file_exists("res://.shots/bench_runs.txt") else FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(line)
		f.close()
