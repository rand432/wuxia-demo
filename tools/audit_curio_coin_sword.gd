extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _foe(core, offset: Vector2) -> Dictionary:
	core._spawn_foe()
	var foe: Dictionary = core.foes.back()
	foe["x"] = core.hero_pos.x + offset.x
	foe["y"] = core.hero_pos.y + offset.y
	foe["hp"] = 10000.0
	foe["hp_max"] = 100.0 # 物理护甲折算2点。
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
	core.hero["crit"] = 0.0
	core.attr_set_base("crit", 0.0)
	core.hero["lucky"] = 0.0
	battle._curio_id = "tongqianjian"
	battle._wen = 777
	# 五级档位及贴身单目标，补镖是完整伤害并能重复命中同一目标。
	for lv in range(1, 6):
		core.foes.clear()
		var foe := _foe(core, Vector2(0.0, -20.0))
		battle._curio_lv = lv
		battle._dart_n = 0
		battle._curio_on_attack()
		var damage := 33.0 if lv == 1 else 43.0
		assert(foe["hp"] == 10000.0 - damage)
		foe["hp"] = 10000.0
		battle._dart_n = 2
		battle._curio_on_attack()
		assert(foe["hp"] == 10000.0 - damage * (2 if lv >= 3 else 1))
		assert(battle._wen == 777)
	# 射程边界按主角74+120/200，不存在60px内的盲区。
	for lv in [1, 4]:
		battle._curio_lv = lv
		var reach := 194.0 if lv == 1 else 274.0
		for distance in [reach, reach + 1.0]:
			core.foes.clear()
			var foe := _foe(core, Vector2(0.0, -distance))
			battle._dart_n = 0
			battle._curio_on_attack()
			assert(foe["hp"] == (10000.0 - (33.0 if lv == 1 else 43.0) if distance == reach else 10000.0))
	# 五级每一枚都只穿透一个同线目标，半伤只用于穿透，不用于第三击补镖。
	core.foes.clear()
	var first := _foe(core, Vector2(0.0, -50.0))
	var second := _foe(core, Vector2(0.0, -120.0))
	var third := _foe(core, Vector2(0.0, -180.0))
	var side := _foe(core, Vector2(25.0, -90.0))
	var behind := _foe(core, Vector2(0.0, 70.0))
	battle._curio_lv = 5
	battle._dart_n = 2
	battle._curio_on_attack()
	assert(first["hp"] == 9914.0 and second["hp"] == 9959.0)
	assert(third["hp"] == 10000.0 and side["hp"] == 10000.0 and behind["hp"] == 10000.0)
	# 第一枚击杀后，补镖重新选择活目标，仍是完整伤害。
	core.kill.disconnect(battle._on_core_kill)
	core.foes.clear()
	first = _foe(core, Vector2(0.0, -30.0))
	first["hp"] = 10.0
	second = _foe(core, Vector2(0.0, -90.0))
	battle._curio_lv = 3
	battle._dart_n = 2
	var kills: int = core.kills_total
	battle._curio_on_attack()
	assert(first["hp"] == 0.0 and core.kills_total == kills + 1)
	assert(second["hp"] == 9957.0)
	battle._run_over = true
	var hp: float = second["hp"]
	var count: int = battle._dart_n
	battle._curio_on_attack()
	assert(second["hp"] == hp and battle._dart_n == count)
	battle.queue_free()
	await process_frame
	print("PASS: coin sword five tiers/close and boundary range/full third shot/one line pierce/no cost/retarget/result")
	Audio.quit_cleanly()
