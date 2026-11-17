extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _battle():
	LS.ensure_loaded()
	LS.current_level = 6
	GS.skill_lv = {}
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	b._core.set_process(false)
	b._core.foes.clear()
	b._core.attr_set_base("crit", 0.0)
	b._core.attr_set_base("hp", 1000.0)
	b._core.hero.merge({"hp": 500.0, "hp_max": 1000.0, "lucky": 0.0}, true)
	b._core.hero_pos = Vector2(360, 600)
	b._core.kill_heal = 0.0
	return b

func _foe(c, y: float) -> Dictionary:
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": 1000.0, "hp_max": 1000.0, "shield": false, "x": 360.0, "y": y}, true)
	return f

func _case(steps: Array, chain: bool) -> Array:
	var b = _battle()
	var c = b._core
	b._ram_shiny = chain
	_foe(c, 500.0)
	if chain:
		_foe(c, 400.0)
		_foe(c, 375.0)
	b._charge_ram()
	var snapshot := []
	for f in c.foes: snapshot.append([f["x"], f["y"], f.get("_ky", 0.0), f["hp"]])
	b._tick_knock(0.0)
	for i in c.foes.size():
		var f: Dictionary = c.foes[i]
		assert(snapshot[i] == [f["x"], f["y"], f.get("_ky", 0.0), f["hp"]])
	for dt in steps: b._tick_knock(dt)
	snapshot.clear()
	for f in c.foes: snapshot.append([f["x"], f["y"], f.get("_kx", 0.0), f.get("_ky", 0.0), f["hp"]])
	snapshot.append([c.hero["hp_max"], c.hero["hp"]])
	if chain: assert(c.hero["hp_max"] == 1016.0)
	b.queue_free()
	return snapshot

func _run() -> void:
	for chain in [false, true]:
		var baseline := []
		for fps in [60, 30, 120]:
			var steps := []
			for i in range(fps): steps.append(1.0 / float(fps))
			var state := _case(steps, chain)
			if baseline.is_empty(): baseline = state
			else: assert(state == baseline)
			await process_frame
		# 长帧不丢失时间，抖动帧最后补齐到同一秒，也必须得到同一状态。
		assert(_case([1.0], chain) == baseline)
		await process_frame
		var jitter := []
		var elapsed := 0.0
		var pattern := [0.004, 0.037, 0.008, 0.019]
		while elapsed < 1.0:
			var dt := minf(float(pattern[jitter.size() % pattern.size()]), 1.0 - elapsed)
			jitter.append(dt)
			elapsed += dt
		assert(_case(jitter, chain) == baseline)
		await process_frame
	# 清场前尚未补足的半步不能挪到新批次，暂停则保留同一批次的半步。
	var phase_battle = _battle()
	var phase_core = phase_battle._core
	var phase_foe := _foe(phase_core, 500.0)
	phase_battle._charge_ram()
	phase_battle._tick_knock(1.0 / 120.0)
	phase_core.clear_enemy_attacks()
	phase_battle._charge_ram()
	phase_battle._tick_knock(1.0 / 120.0)
	assert(phase_foe["y"] == 500.0)
	phase_core.running = false
	phase_battle._tick_knock(1.0)
	phase_core.running = true
	phase_battle._tick_knock(1.0 / 120.0)
	assert(phase_foe["y"] == 470.0)
	phase_battle.queue_free()
	await process_frame
	# 真实初级/一星六卡合成：初撞72，连锁72×1.3=93.6；物理共享15%只在类型层应用一次。
	var b = _battle()
	var c = b._core
	GS.stars["gundilong"] = 1
	b._grant_ancestor("gundilong")
	for tier in range(2):
		for index in range(3): b._add_card("gundilong_t%d_%d" % [tier, index])
	b._add_ancestor_effects("xiaoqier", {"elem_pct": {"物理": 15.0}})
	var first := _foe(c, 500.0)
	var second := _foe(c, 400.0)
	b._charge_ram()
	var ctx: Dictionary = first["_ram_ctx"]
	assert(is_equal_approx(ctx["damage"], 72.0) and is_equal_approx(ctx["chain_damage"], 93.6))
	assert(is_equal_approx(first["hp"], 937.2))
	b._anc_mod["gundilong"]["chain_dmg"] = 200.0 # 后续加成不改变已经发出的这一组。
	b._tick_knock(0.05)
	assert(is_equal_approx(second["hp"], 912.36) and ctx["budget"] == 0)
	GS.stars["gundilong"] = 0
	b.queue_free()
	await process_frame
	print("PASS: ram 30/60/120/jitter/long-frame states identical; zero time stable; real family chain bonus owner-only and snapshotted; shared physical once")
	Audio.quit_cleanly()
