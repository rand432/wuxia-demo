extends SceneTree

const Battle := preload("res://kushou/battle_ui.tscn")
const Levels := preload("res://shared/level_state.gd")
const Game := preload("res://shared/game_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	Levels.ensure_loaded()
	Levels.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	await process_frame
	battle._tut.cancel()
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.foes.clear()
	core.hero_pos = Vector2(350, 442)
	core.hero["atk"] = 100.0
	core.hero["lucky"] = 0.0
	Game.skill_lv["liuqingqing"] = 0
	battle._anc_mod["liuqingqing"] = {"aura": 1.0, "radius_add": 55.0}
	for y in range(-3, 4):
		for x in range(-3, 4):
			var foe: Dictionary = core._spawn_foe("normal" if core.foes.size() < core.MAX_FOES else "chal")
			var at: Vector2 = core.hero_pos + Vector2(x, y) * 33.0
			assert(not foe.is_empty())
			foe.merge({"x": at.x, "y": at.y, "hp": 1000.0,
				"hp_max": 1000.0, "res_wood": 0.0, "shield": false}, true)
	assert(core.foes.size() == 49)
	var layer = battle._spawn_pfx("impacts/hit-spark", Vector2(80, 190))
	layer._rng.seed = 701
	var child_count: int = battle._cam.get_child_count()
	battle._cast_heal(1.0)
	seed(92)
	var next_roll := randf()
	seed(92)
	battle._tick_poison(1.0)
	assert(randf() == next_roll)
	assert(core.foes.all(func(foe): return is_equal_approx(foe["hp"], 970.0)))
	var poison: Array = layer.sparks.filter(func(spark): return spark["poison"])
	assert(poison.size() == layer.POISON_LIMIT)
	for i in poison.size():
		for j in range(i):
			assert(poison[i]["pos"].distance_squared_to(poison[j]["pos"]) >= layer.POISON_SPACING_SQ)
	await process_frame
	for i in layer.LIMIT:
		assert(battle._spawn_pfx("impacts/crit-hit", Vector2(250 + i, 390), 0.8, "gold") == layer)
	assert(layer.sparks.size() == layer.LIMIT and layer.sparks.all(func(spark): return not spark["poison"]))
	assert(battle._cam.get_child_count() == child_count)
	await create_timer(0.3).timeout
	assert(layer.sparks.is_empty() and not layer.is_processing())
	battle.queue_free()
	await process_frame
	assert(not is_instance_valid(layer))
	print("PASS: all 49 poison targets take damage, eight spaced sparks share a node, heavy effects take priority and RNG is isolated")
	Audio.quit_cleanly()
