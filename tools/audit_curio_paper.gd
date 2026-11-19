extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _hit(core, damage: float, boss_attack: bool) -> void:
	core.queue_delayed(core.hero_pos.x, core.hero_pos.y, 100.0, damage, "真实")
	var cast: Dictionary = core._delayed.back()
	cast["boss_attack"] = boss_attack
	core._delayed_hit(cast)
	core._delayed.clear()

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	battle._curio_id = "zhiren"
	for lv in range(1, 6):
		battle._curio_lv = lv
		battle._curio_apply_static()
		assert(battle._zhiren == 0 and core.hero["paper_guard"] == 0)
		battle._curio_on_wave_clear(1)
		assert(battle._zhiren == (2 if lv >= 4 else 1))
		battle._curio_on_wave_clear(2)
		battle._curio_on_wave_clear(3)
		assert(battle._zhiren == (2 if lv == 1 else 3))
		assert(core.hero["paper_guard"] == (3 if lv == 5 else 0))
	core.hero["hp_max"] = 1000.0
	core.hero["hp"] = 1000.0
	core.hero["atk"] = 100.0
	core.hero["crit"] = 0.0
	core.attr_set_base("crit", 0.0) # 实际暴击读取属性层，不能只改旧桥接字段。
	core.hero["lucky"] = 0.0
	battle._set_paper_count(2)
	_hit(core, 10.0, false)
	assert(core.hero["hp"] == 990.0 and battle._zhiren == 2)
	_hit(core, 10.0, true)
	assert(core.hero["hp"] == 990.0 and battle._zhiren == 1 and core.hero["paper_guard"] == 1)
	_hit(core, 10.0, true)
	assert(core.hero["hp"] == 990.0 and battle._zhiren == 0 and core.hero["paper_guard"] == 0)
	_hit(core, 10.0, true)
	assert(core.hero["hp"] == 980.0)
	# 同帧普通致命伤后，核心不能使用已消耗的旧纸人数。
	battle._set_paper_count(1)
	var life: int = battle._life
	_hit(core, 2000.0, false)
	assert(core.hero["hp"] == 1000.0 and core.running and battle._life == life)
	assert(battle._zhiren == 0 and core.hero["paper_guard"] == 0)
	_hit(core, 10.0, true)
	assert(core.hero["hp"] == 990.0)
	# 四级不能挡非致命首领技，但仍能挡致命伤。
	battle._curio_lv = 4
	battle._set_paper_count(1)
	_hit(core, 10.0, true)
	assert(core.hero["hp"] == 980.0 and battle._zhiren == 1)
	_hit(core, 2000.0, true)
	assert(core.hero["hp"] == 1000.0 and battle._zhiren == 0 and battle._life == life)
	# 两条碎裂路径都带三级范围伤害和普通怪击退。
	core.foes.clear()
	for i in range(2):
		core._spawn_foe()
		var foe: Dictionary = core.foes.back()
		foe["x"] = core.hero_pos.x + (50.0 if i == 0 else 200.0)
		foe["y"] = core.hero_pos.y
		foe["hp"] = 1000.0
		foe["hp_max"] = 1000.0
		foe["shield"] = false
	var near: Dictionary = core.foes[0]
	var far: Dictionary = core.foes[1]
	battle._curio_lv = 5
	battle._set_paper_count(2)
	_hit(core, 10.0, true)
	assert(near["hp"] == 920.0 and near["kb"] == 120.0 and far["hp"] == 1000.0)
	_hit(core, 2000.0, false)
	assert(near["hp"] == 840.0 and far["hp"] == 1000.0)
	# 原生首领连招必须给全部预警标记来源。
	core.foes.clear()
	core._spawn_foe("boss", 1.0, 1.0, true, 1, "test")
	var boss: Dictionary = core.foes.back()
	core._last_quota_wave = core.wave
	core._wave_spawned = core._wave_quota
	core._spawn_left = 0
	core._spawn_t = 9999.0
	core.intro_wait = 9999.0
	core._hero_cd = 9999.0
	for shape in ["combo_a", "combo_b", "combo_c"]:
		core._delayed.clear()
		boss["ult_t"] = 0.0
		boss["ult_shape"] = shape
		core._process(0.01)
		assert(core._delayed.size() == (6 if shape == "combo_b" else 3))
		for cast in core._delayed:
			assert(cast["boss_attack"] and is_same(cast["caster"], boss))
	# 延迟技命尽后立即停止本批后续伤害，不再次触发死亡。
	core._delayed.clear()
	battle._curio_id = ""
	battle._set_paper_count(0)
	battle._bm.slots.clear()
	battle._life = 1
	core.hero["hp"] = 1.0
	var deaths := [0]
	core.hero_down.connect(func(): deaths[0] += 1)
	for i in range(2): core.queue_delayed(core.hero_pos.x, core.hero_pos.y, 100.0, 2000.0, "真实", 0.35)
	core._delayed_tick(1.0)
	assert(battle._run_over and not core.running and deaths[0] == 1)
	battle.queue_free()
	await process_frame
	await _check_boundaries()
	print("PASS: paper gains/caps/count sync/boss guard/lethal protection/backlash/combo tags; both shatter paths stop at kill callback boundaries")
	Audio.quit_cleanly()

func _check_boundaries() -> void:
	for lethal in [false, true]:
		for mode in ["normal", "result", "epoch", "dead", "stopped", "removed"]:
			var b = Battle.instantiate()
			root.add_child(b)
			b.set_process(false)
			var c = b._core
			c.set_process(false)
			c.foes.clear()
			c.kill.disconnect(b._on_core_kill)
			c.kill_heal = 0.0
			c.hero["atk"] = 100.0
			c.hero["hp_max"] = 1000.0
			c.hero["hp"] = 1000.0
			b._curio_id = "zhiren"
			b._curio_lv = 5
			b._set_paper_count(1)
			var targets: Array = []
			for i in range(2):
				c._spawn_foe()
				var f: Dictionary = c.foes.back()
				f.merge({"hp": 1.0 if i == 0 else 1000.0, "hp_max": 1000.0, "shield": false,
					"x": c.hero_pos.x + 30.0 + i * 20.0, "y": c.hero_pos.y, "kb": 0.0}, true)
				targets.append(f)
			var uses: int = b._curio_uses
			var kills: int = c.kills_total
			var callback_uses: Array = []
			var lands := [0]
			c.delayed_land.connect(func(_p, _e): lands[0] += 1)
			c.kill.connect(func(_n):
				callback_uses.append(b._curio_uses)
				if mode == "result": b._end_run(false)
				elif mode == "epoch":
					c.clear_enemy_attacks()
					c.foes.clear()
				elif mode == "dead": c.hero["hp"] = 0.0
				elif mode == "stopped": c.running = false
				elif mode == "removed": c.foes.erase(targets[1]))
			_hit(c, 2000.0 if lethal else 10.0, not lethal)
			assert(b._zhiren == 0 and c.hero["paper_guard"] == 0 and b._curio_uses == uses + 1)
			assert(c.kills_total == kills + 1 and callback_uses == [uses + 1])
			if mode == "normal":
				assert(targets[1]["hp"] == 920.0 and targets[1]["kb"] == 120.0)
			else:
				assert(targets[1]["hp"] == 1000.0 and targets[1]["kb"] == 0.0)
			assert(lands[0] == (1 if mode in ["normal", "removed"] else 0))
			assert(c.hero["hp"] == (0.0 if mode == "dead" else 1000.0))
			b.queue_free()
			await process_frame
	# 失效战斗入口不能直接触发碎裂或消耗挡招次数。
	for dead in [false, true]:
		var b = Battle.instantiate()
		root.add_child(b)
		b.set_process(false)
		var c = b._core
		c.set_process(false)
		c.foes.clear()
		c._spawn_foe()
		var f: Dictionary = c.foes.back()
		f.merge({"hp": 1000.0, "x": c.hero_pos.x, "y": c.hero_pos.y}, true)
		b._curio_id = "zhiren"
		b._curio_lv = 5
		b._set_paper_count(1)
		if dead: c.hero["hp"] = 0.0
		else: c.running = false
		var uses: int = b._curio_uses
		b._paper_shatter()
		b._on_paper_blocked(c.hero_pos)
		assert(f["hp"] == 1000.0 and b._zhiren == 1 and b._curio_uses == uses)
		b.queue_free()
		await process_frame
