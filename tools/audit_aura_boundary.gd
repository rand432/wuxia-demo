extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")
var pull_seed := 0

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _battle():
	LS.ensure_loaded()
	LS.current_level = 6
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	b._core.set_process(false)
	b._core.foes.clear()
	b._core.hero["atk"] = 100.0
	b._mingzhu = true
	b._anc_mod["mingzhu"] = {"pull": 1, "heal_aura": 1, "vuln": 10.0}
	return b

func _foe(c, distance: float, hp := 1000.0) -> Dictionary:
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"x": c.hero_pos.x, "y": c.hero_pos.y - distance, "hp": hp, "hp_max": 1000.0, "res_wood": 0.0, "shield": false, "slow_t": 0.0, "vuln_t": 0.0}, true)
	return f

func _pull(b) -> void:
	b._aura_pull_acc = 0.0
	seed(pull_seed)
	b._tick_aura(1.0)

func _run() -> void:
	for candidate in range(1, 101):
		seed(candidate)
		if randf() < 0.20:
			pull_seed = candidate
			break
	assert(pull_seed > 0)
	for distance in [0.0, 40.0, 150.0, 181.0]:
		var b = _battle()
		var c = b._core
		var f := _foe(c, distance)
		_pull(b)
		var expected: float = maxf(0.0, distance - 120.0) if distance <= 180.0 else distance
		assert(is_equal_approx(Vector2(f["x"], f["y"]).distance_to(c.hero_pos), expected))
		assert(is_equal_approx(f["hp"], 983.5 if distance <= 180.0 else 1000.0))
		b.queue_free()
		await process_frame
	# 结束、死亡、核心暂停时，光环不回血回蓝、不加状态、不拉拽。
	for mode in ["result", "dead", "stopped"]:
		var b = _battle()
		var c = b._core
		var f := _foe(c, 40.0)
		b._mp = 0.0
		if mode == "result": b._run_over = true
		elif mode == "dead": c.hero["hp"] = 0.0
		else: c.running = false
		var hp: float = c.hero["hp"]
		_pull(b)
		assert(c.hero["hp"] == hp and b._mp == 0.0 and f["hp"] == 1000.0 and f["slow_t"] == 0.0)
		b.queue_free()
		await process_frame
	# 致死聚灯当场结算一次；回调换波/结算后不再给旧目标加状态。
	for result_end in [false, true]:
		var b = _battle()
		var c = b._core
		var f := _foe(c, 40.0, 1.0)
		var untouched := _foe(c, 60.0)
		var kills: int = b._kills
		c.kill.connect(func(_n):
			c._kill_foe(f)
			if result_end: b._end_run(false)
			else: c.clear_enemy_attacks())
		_pull(b)
		assert(f.get("_death_settled", false) and b._kills == kills + 1)
		assert(untouched["hp"] == 1000.0 and untouched["slow_t"] == 0.0)
		c._kill_foe(f)
		assert(b._kills == kills + 1)
		b.queue_free()
		await process_frame
	print("PASS: aura pull clamps at center; range/damage preserved; dead/result/stopped guards; immediate once-only kill and callback boundaries")
	Audio.quit_cleanly()
