extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _foe(core, pos: Vector2) -> Dictionary:
	core._spawn_foe()
	var foe: Dictionary = core.foes.back()
	foe["x"] = pos.x
	foe["y"] = pos.y
	foe["hp"] = 10000.0
	foe["hp_max"] = 1000.0
	foe["shield"] = false
	return foe

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.hero["atk"] = 100.0
	core.hero["lucky"] = 0.0
	battle._curio_id = "zhaohunfan"
	core.foes.clear()
	battle._curio_cd = 0.0
	battle._curio_tick_zhaohunfan()
	assert(battle._minions.is_empty() and battle._curio_cd == 0.0)
	var target := _foe(core, core.hero_pos)
	for lv in range(1, 6):
		battle._curio_lv = lv
		battle._curio_cd = 0.0
		battle._curio_tick_zhaohunfan()
		var count := 2 if lv >= 3 else 1
		assert(battle._curio_count_minions("zhaohunfan") == count and battle._curio_cd == 25.0)
		if count == 2:
			assert(battle._minions[0]["pos"] != battle._minions[1]["pos"])
			battle._minions[1]["atk_cd"] = 999.0
		var uses: int = battle._curio_uses
		battle._curio_cd = 0.0
		battle._curio_tick_zhaohunfan()
		assert(battle._curio_count_minions("zhaohunfan") == count and battle._curio_uses == uses and battle._curio_cd == 0.0)
		var ghost: Dictionary = battle._minions[0]
		assert(ghost["max_life"] == (8.0 if lv == 1 else 10.0))
		target["x"] = ghost["pos"].x
		target["y"] = ghost["pos"].y
		target["hp"] = 10000.0
		ghost["atk_cd"] = 0.0
		battle._tick_minions(0.1)
		assert(target["hp"] == (9965.0 if lv >= 4 else 9975.0))
		var before: float = target["hp"]
		for unit in battle._minions:
			unit["life"] = 0.05
			unit["pos"] = ghost["pos"]
		battle._tick_minions(0.1)
		assert(target["hp"] == before - (80.0 * count if lv == 5 else 0.0))
		battle._tick_minions(0.1)
		assert(target["hp"] == before - (80.0 * count if lv == 5 else 0.0) and battle._minions.is_empty())
	# 鬼影回到主角身边，不追出220px支援范围，移动不越过目标。
	battle._curio_lv = 1
	battle._curio_cd = 0.0
	battle._curio_tick_zhaohunfan()
	var ghost: Dictionary = battle._minions[0]
	ghost["life"] = 100.0
	ghost["max_life"] = 100.0
	core.foes.clear()
	core.hero_pos += Vector2(100.0, 0.0)
	var anchor: Vector2 = core.hero_pos + ghost["follow_offset"]
	battle._tick_minions(1.0)
	assert(ghost["pos"] == anchor)
	var far := _foe(core, core.hero_pos + Vector2(0.0, -400.0))
	battle._tick_minions(1.0)
	assert(ghost["pos"] == anchor and far["hp"] == 10000.0)
	var near := _foe(core, core.hero_pos + Vector2(0.0, -200.0))
	battle._tick_minions(1.0)
	battle._tick_minions(10.0)
	assert(is_equal_approx(Vector2(ghost["pos"]).distance_to(Vector2(near["x"], near["y"])), 48.0))
	# 普攻击杀即时结算一次，不等核心补扫；其他鬼影不能重复结算尸体。
	core.kill.disconnect(battle._on_core_kill)
	near["hp"] = 10.0
	ghost["pos"] = Vector2(near["x"], near["y"])
	ghost["atk_cd"] = 0.0
	var kills: int = core.kills_total
	battle._tick_minions(0.1)
	assert(core.kills_total == kills + 1 and near["hp"] == 0.0)
	battle._tick_minions(0.1)
	assert(core.kills_total == kills + 1)
	battle._tick_minions(200.0)
	# 鬼影和蛟龙各按本类计数，吞海只永久化蛟龙。
	core.foes.clear()
	_foe(core, core.hero_pos)
	battle._curio_lv = 3
	battle._curio_cd = 0.0
	battle._curio_tick_zhaohunfan()
	ghost = battle._minions[0]
	battle._summon_dragon(0.0)
	assert(battle._minions.size() == 3 and battle._curio_count_minions("") == 1)
	battle._summon_dragon(0.0)
	assert(battle._minions.size() == 3)
	var life: float = ghost["life"]
	battle._enable_swallow_sea()
	assert(ghost["life"] == life and battle._minions[2]["life"] == 999999.0)
	for unit in battle._minions:
		if str(unit.get("curio", "")) == "zhaohunfan": unit["life"] = 0.0
	assert(battle._curio_count_minions("zhaohunfan") == 0)
	battle._tick_minions(0.0)
	assert(battle._minions.size() == 1)
	battle._run_over = true
	battle._curio_cd = 0.0
	battle._curio_tick_zhaohunfan()
	battle._tick_minions(10.0)
	assert(battle._minions.size() == 1)
	battle.queue_free()
	await process_frame
	print("PASS: ghost duration/damage/one expiry blast/follow/leash/immediate kill; independent dragon cap and swallow/result")
	Audio.quit_cleanly()
