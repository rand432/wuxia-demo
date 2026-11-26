extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _audit_frost_presentation() -> void:
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle._tut.cancel()
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	battle._curio_id = "hanyu"
	battle._curio_lv = 5
	var foe: Dictionary = core._spawn_foe()
	foe.merge({"x": 300.0, "y": 300.0, "hp_max": 1000.0, "hp": 1000.0}, true)
	battle._process(0.0)
	var tk = battle._foe_tokens[foe["_tid"]]
	tk.set_process(false)
	for stacks in [1, 2, 3]:
		battle._curio_on_crit(foe)
		battle._process(0.0)
		assert(tk.frost_chilled and tk.frost_layers == (0 if stacks == 3 else stacks))
		assert(tk.frost_frozen == (stacks == 3))
	var held_frame: int = tk._frame_index
	tk._process(0.4)
	assert(tk._frame_index == held_frame and tk._sprite.modulate.b > 1.0)
	core._tick_cold_control(foe, 0.81)
	battle._process(0.0)
	assert(not tk.frost_frozen and tk.frost_chilled)
	var burst: Dictionary = battle._fx_front.hits.back()
	assert(burst["ice_burst"] and burst["r"] == 70.0 and burst["p"] == Vector2(300, 300))
	tk._process(0.03)
	assert(tk._sprite.modulate.b <= 1.0)
	core._tick_cold_control(foe, 3.0)
	battle._process(0.0)
	assert(not tk.frost_chilled and tk.frost_layers == 0)
	for i in range(3):
		battle._curio_on_crit(foe)
	battle._process(0.0)
	assert(tk.frost_frozen)
	core._kill_foe(foe)
	battle._process(0.0)
	assert(not tk.frost_frozen and not tk.frost_chilled and tk.frost_layers == 0)
	battle.queue_free()

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.foes.clear()
	for i in range(3):
		core._spawn_foe()
		var foe: Dictionary = core.foes.back()
		foe["x"] = 200.0 + i * 50.0
		foe["y"] = 100.0
		foe["hp"] = 1000.0
		foe["hp_max"] = 1000.0
		foe["shield"] = false
	core.hero["crit"] = 0.0
	core.attr_set_base("crit", 0.0)
	core.hero["lucky"] = 0.0
	core.hero["atk"] = 100.0
	battle._curio_id = "hanyu"
	var target: Dictionary = core.foes[0]
	var near: Dictionary = core.foes[1]
	var far: Dictionary = core.foes[2]
	var base_speed: float = core.foe_move_speed(target)
	for lv in range(1, 6):
		battle._curio_lv = lv
		for key in ["cold", "cold_t", "cold_slow", "cold_freeze_t", "cold_dmg", "cold_boom", "para"]:
			target.erase(key)
		for foe in core.foes:
			foe["hp"] = 1000.0
			foe["res_fire"] = 0.0
		battle._curio_on_crit(target)
		var per := 0.15 if lv >= 4 else 0.10
		assert(is_equal_approx(core.foe_move_speed(target), base_speed * (1.0 - per)))
		battle._curio_on_crit(target)
		assert(is_equal_approx(core.foe_move_speed(target), base_speed * (1.0 - 2.0 * per)))
		battle._curio_on_crit(target)
		assert(is_equal_approx(core.foe_move_speed(target), base_speed * (1.0 - 3.0 * per)))
		assert(not target.has("cold_freeze_t") if lv == 1 else target["cold_freeze_t"] == 0.8)
		assert(near["hp"] == 1000.0)
		if lv == 1:
			for i in range(10): battle._curio_on_crit(target)
			assert(target["cold"] == 3 and not target.has("cold_freeze_t"))
		else:
			assert(target["cold"] == 0)
			assert(is_equal_approx(core._apply_dmg(target, 100.0, "真实"), 100.0))
			target["hp"] = 1000.0
			assert(is_equal_approx(core._apply_dmg(target, 100.0, "火系"), 125.0 if lv >= 3 else 100.0))
			core._tick_cold_control(target, 0.79)
			assert(near["hp"] == 1000.0)
			core._tick_cold_control(target, 0.02)
			assert(is_equal_approx(near["hp"], 960.0 if lv == 5 else 1000.0))
			assert(far["hp"] == 1000.0)
			# 其他麻痹不能延长寒玉易伤，也不会重复冰爆。
			target["para"] = 5.0
			assert(is_equal_approx(core._apply_dmg(target, 100.0, "火系"), 100.0))
		core._tick_cold_control(target, 3.0)
		assert(target["cold"] == 0 and is_equal_approx(core.foe_move_speed(target), base_speed))
	# 既有45%减速取更强效果，寒层到期不清掉别的减速。
	target["slow_t"] = 5.0
	battle._curio_on_crit(target)
	assert(is_equal_approx(core.foe_move_speed(target), base_speed * 0.55))
	core._tick_cold_control(target, 3.0)
	assert(target["slow_t"] == 5.0 and is_equal_approx(core.foe_move_speed(target), base_speed * 0.55))
	target.erase("slow_t")
	target.erase("para")
	# 真实帧下冻结期间不移动，顿帧同时减慢寒层和冻结。
	for i in range(3): battle._curio_on_crit(target)
	core._last_quota_wave = core.wave
	core._wave_spawned = core._wave_quota
	core._spawn_left = 0
	core._spawn_t = 9999.0
	core.intro_wait = 9999.0
	core._hero_cd = 9999.0
	core._hitstop = 1.0
	core.foes = [target]
	var position_before := Vector2(target["x"], target["y"])
	core._process(0.5)
	assert(is_equal_approx(target["cold_freeze_t"], 0.71))
	assert(is_equal_approx(target["cold_t"], 2.91))
	assert(Vector2(target["x"], target["y"]) == position_before)
	# 首领仅受软减速，不能被冻结后获得易伤或爆炸。
	core._spawn_foe("boss", 1.0, 1.0, true, 1, "test")
	var boss: Dictionary = core.foes.back()
	for i in range(3): battle._curio_on_crit(boss)
	assert(not boss.has("cold_freeze_t") and not boss.has("cold_dmg"))
	battle._run_over = true
	core.foes = [target, near, far, boss]
	near["hp"] = 1000.0
	core._tick_cold_control(target, 10.0)
	assert(near["hp"] == 1000.0)
	battle.queue_free()
	await process_frame
	_audit_frost_presentation()
	await process_frame
	print("PASS: cold mechanics, stacks, frozen pose, visible ice burst, and death/result cleanup")
	Audio.quit_cleanly()
