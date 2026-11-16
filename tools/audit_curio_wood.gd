extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _cast(core, caster: Dictionary) -> void:
	core.queue_delayed(0.0, 0.0, 70.0, 10.0, "火系", 1.0, "test", "circle", Vector2.RIGHT, 0.0, 0.0, 0, 0.0, 0.0, 0.0, caster)

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.hero["crit"] = 0.0
	core.attr_set_base("crit", 0.0)
	core.hero["lucky"] = 0.0
	core.hero["atk"] = 100.0
	core.foes.clear()
	for i in range(3):
		core._spawn_foe()
		var foe: Dictionary = core.foes.back()
		foe["x"] = core.hero_pos.x
		foe["y"] = core.hero_pos.y - 50.0 - i * 50.0
		foe["hp"] = 1000.0
		foe["hp_max"] = 1000.0
		foe["shield"] = false
	var nearest: Dictionary = core.foes[0]
	var middle: Dictionary = core.foes[1]
	var far: Dictionary = core.foes[2]
	battle._curio_id = "jingtangmu"
	battle._curio_lv = 1
	_cast(core, far)
	_cast(core, middle)
	# 不相关来源预警和已经落地的持续区不应被删。
	core.queue_delayed(0.0, 0.0, 70.0, 10.0, "火系")
	_cast(core, far)
	core._delayed.back()["landed"] = true
	battle._curio_tick_jingtangmu()
	assert(middle["para"] == 2.0 and not nearest.has("wood_t") and not far.has("wood_t"))
	assert(not core.has_pending_cast(middle) and core.has_pending_cast(far))
	assert(core._delayed.size() == 3)
	assert(battle._curio_cd == 35.0 and middle["hp"] == 1000.0)
	assert(is_equal_approx(core._apply_dmg(middle, 100.0, "真实"), 100.0))
	# 二级时长、三级易伤、四级双目标，五级不提前爆炸。
	for lv in range(2, 6):
		core._delayed.clear()
		for foe in core.foes:
			for key in ["para", "wood_t", "wood_vuln", "wood_boom"]: foe.erase(key)
			foe["hp"] = 1000.0
		battle._curio_cd = 0.0
		battle._curio_lv = lv
		battle._curio_tick_jingtangmu()
		assert(nearest["para"] == 2.5 and nearest["hp"] == 1000.0)
		assert(middle.has("wood_t") == (lv >= 4))
		assert(not far.has("wood_t"))
		var damage: float = core._apply_dmg(nearest, 100.0, "真实")
		assert(is_equal_approx(damage, 130.0 if lv >= 3 else 100.0))
		core._tick_wood_control(nearest, 2.49)
		assert(is_equal_approx(nearest["hp"], 1000.0 - damage))
		core._tick_wood_control(nearest, 0.02)
		var expected_boom := 60.0 if lv >= 5 else 0.0 # 80攻击，减目标护甲20
		assert(is_equal_approx(nearest["hp"], 1000.0 - damage - expected_boom))
		core._tick_wood_control(nearest, 10.0)
		assert(is_equal_approx(nearest["hp"], 1000.0 - damage - expected_boom))
		assert(is_equal_approx(core._apply_dmg(nearest, 100.0, "真实"), 100.0))
	# 真实核心帧的顿帧时间：定身与爆炸使用相同时间尺度。
	core._delayed.clear()
	core.foes = [nearest]
	nearest["para"] = 1.0
	nearest["wood_t"] = 1.0
	nearest["wood_boom"] = true
	nearest["wood_vuln"] = 0.3
	nearest["hp"] = 1000.0
	core._hitstop = 1.0
	core._wave_spawned = core._wave_quota
	core._last_quota_wave = core.wave
	core._spawn_t = 9999.0
	core._spawn_left = 0
	core.intro_wait = 9999.0
	core._hero_cd = 9999.0
	core._process(0.5)
	assert(is_equal_approx(nearest["wood_t"], 0.91) and is_equal_approx(nearest["para"], 0.91))
	assert(nearest["hp"] == 1000.0)
	# 少于两怪不启动，首领不被选择，已死目标不会在到期被再次结算。
	battle._curio_cd = 0.0
	battle._curio_tick_jingtangmu()
	assert(battle._curio_cd == 0.0)
	core._spawn_foe("boss", 1.0, 1.0, true, 1, "test")
	var boss: Dictionary = core.foes.back()
	battle._curio_tick_jingtangmu()
	assert(not boss.has("wood_t"))
	nearest["hp"] = 0.0
	var kills: int = core.kills_total
	core._tick_wood_control(nearest, 10.0)
	assert(core.kills_total == kills)
	battle.queue_free()
	await process_frame
	print("PASS: wood prioritizes/intercepts casts; five levels, timed vulnerability/explosion, hitstop and boss exclusion")
	Audio.quit_cleanly()
