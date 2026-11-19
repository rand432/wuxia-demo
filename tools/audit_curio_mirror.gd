extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.foes.clear()
	core._spawn_foe()
	var foe: Dictionary = core.foes.back()
	foe["x"] = core.hero_pos.x + 20.0
	foe["y"] = core.hero_pos.y
	foe["hp_max"] = 1000.0
	foe["shield"] = false
	core.hero["atk"] = 100.0
	core.hero["crit"] = 0.0
	core.attr_set_base("crit", 0.0)
	core.hero["lucky"] = 0.0
	core.hero["hp_max"] = 1000.0
	battle._curio_id = "tongjing"
	for lv in range(1, 6):
		battle._curio_lv = lv
		battle._curio_cd = 0.0
		foe["hp"] = 1000.0
		foe["dying"] = 0.0
		core.hero["hp"] = 100.0
		battle._curio_tick_tongjing()
		assert(battle._minions.size() == 1 and battle._curio_cd == 20.0)
		var mirror: Dictionary = battle._minions[0]
		assert(mirror["life"] == (5.0 if lv == 1 else 7.0))
		assert(not foe.has("para"))
		battle._tick_minions(0.5)
		assert(foe["hp"] == 1000.0) # 没有普攻就不独立打人。
		core._heavy = 0
		core._hero_strike(foe)
		var echo := 56.0 if lv >= 4 else 40.0 # 本次物理普攻100-20护甲=80
		assert(is_equal_approx(foe["hp"], 1000.0 - 80.0 - echo))
		assert(is_equal_approx(core.hero["hp"], 100.0 + (echo * 0.1 if lv >= 3 else 0.0)))
		# 持续期间再次生成不增加镜像；吞海不改变它的有限寿命。
		battle._curio_cd = 0.0
		battle._curio_tick_tongjing()
		assert(battle._minions.size() == 1)
		var lifetime: float = mirror["life"]
		battle._enable_swallow_sea()
		assert(mirror["life"] == lifetime)
		battle._tick_minions(10.0)
		assert(battle._minions.is_empty() and not core._mirror_taunting())
		battle._swallow_sea = false
	# 复制伤害不会二次防御/暴击，吸血只基于实际剩余血。
	battle._curio_cd = 0.0
	foe["hp"] = 10.0
	foe["dying"] = 0.0
	battle._curio_tick_tongjing()
	core.hero["hp"] = 100.0
	core.kill.disconnect(battle._on_core_kill) # 单独测过量伤害吸血，排除击杀经验升级回血。
	core.kill_heal = 0.0 # 同时排除核心默认8%击杀回血。
	var kills: int = core.kills_total
	battle._curio_mirror_hit(foe, 100.0)
	assert(foe["hp"] == 0.0 and core.kills_total == kills + 1)
	assert(core.hero["hp"] == 101.0)
	battle._curio_mirror_hit(foe, 100.0)
	assert(core.kills_total == kills + 1 and core.hero["hp"] == 101.0)
	# 原生怪物普攻转向镜像，1.5秒后恢复打主角，完全不靠para。
	foe["hp"] = 1000.0
	foe["dying"] = 0.0
	foe.erase("_death_settled")
	foe["x"] = core.hero_pos.x + 20.0
	foe["y"] = core.hero_pos.y
	foe["stop"] = 1000.0
	foe["atk"] = 10.0
	for key in ["mage", "brute", "ranged"]: foe[key] = false
	core._last_quota_wave = core.wave
	core._wave_spawned = core._wave_quota
	core._spawn_left = 0
	core._spawn_t = 9999.0
	core.intro_wait = 9999.0
	core._hero_cd = 9999.0
	core._hitstop = 0.0
	core.hero["hp"] = 1000.0
	foe["t"] = 100.0
	core._process(0.1)
	assert(core.hero["hp"] == 1000.0 and core._mirror_decoy["hits"] == 1)
	assert(is_equal_approx(core._mirror_decoy["taunt_t"], 1.4))
	assert(not foe.has("para"))
	foe["t"] = 100.0
	core._process(1.4)
	assert(not core._mirror_taunting())
	assert(core.hero["hp"] == 990.0)
	# 新首领预警瞄准镜像；已经排好的区域仍按实际位置判定。
	core.foes.clear()
	core._spawn_foe("boss", 1.0, 1.0, true, 1, "test")
	var boss: Dictionary = core.foes.back()
	boss["ult_shape"] = "circle"
	boss["ult_t"] = 0.0
	var decoy: Dictionary = core.add_mirror_decoy(core.hero_pos + Vector2(-200.0, 0.0))
	core._delayed.clear()
	core._process(0.01)
	assert(core._delayed.size() == 1)
	assert(is_equal_approx(core._delayed[0]["x"], decoy["pos"].x))
	assert(is_equal_approx(core._delayed[0]["y"], decoy["pos"].y - 6.0))
	battle._run_over = true
	var hp: float = boss["hp"]
	battle._curio_mirror_hit(boss, 100.0)
	assert(boss["hp"] == hp)
	battle.queue_free()
	await process_frame
	await _check_boundaries()
	print("PASS: mirror five tiers/native attack copy/actual lifesteal/lifetime/real aggro and boss aim; stopped/dead entry and kill callback boundaries")
	Audio.quit_cleanly()

func _check_boundaries() -> void:
	for mode in ["normal", "result", "epoch", "dead", "stopped", "dead_entry", "stopped_entry"]:
		var b = Battle.instantiate()
		root.add_child(b)
		b.set_process(false)
		var c = b._core
		c.set_process(false)
		c.foes.clear()
		c.kill.disconnect(b._on_core_kill) # 排除升级回复，只测镜像吸血。
		c.kill_heal = 0.0
		c.hero["hp_max"] = 1000.0
		c.hero["hp"] = 100.0
		c._spawn_foe()
		var f: Dictionary = c.foes.back()
		f.merge({"hp": 10.0, "hp_max": 1000.0, "shield": false}, true)
		b._curio_id = "tongjing"
		b._curio_lv = 5
		b._curio_cd = 0.0
		b._curio_tick_tongjing()
		assert(b._minions.size() == 1)
		var kills: int = c.kills_total
		var callback_floats: Array = []
		c.kill.connect(func(_n):
			if mode == "result": b._end_run(false)
			elif mode == "epoch": c.clear_enemy_attacks()
			elif mode == "dead": c.hero["hp"] = 0.0
			elif mode == "stopped": c.running = false
			callback_floats.append(c._floats.size()))
		if mode == "dead_entry": c.hero["hp"] = 0.0
		elif mode == "stopped_entry": c.running = false
		b._curio_mirror_hit(f, 100.0)
		if mode.ends_with("_entry"):
			assert(f["hp"] == 10.0 and c.kills_total == kills and callback_floats.is_empty())
		else:
			assert(f["hp"] == 0.0 and c.kills_total == kills + 1 and callback_floats.size() == 1)
			if mode == "normal":
				assert(c.hero["hp"] == 101.0 and c._floats.size() > callback_floats[0])
			else:
				assert(c.hero["hp"] == (0.0 if mode == "dead" else 100.0))
				assert(c._floats.size() == callback_floats[0])
		b.queue_free()
		await process_frame
