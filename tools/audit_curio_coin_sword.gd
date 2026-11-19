extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")
class BattleProbe extends "res://kushou/battle_ui.gd":
	var traces: Array = []
	func _curio_dart_trace(_origin: Vector2, target: Vector2) -> void:
		traces.append(target)

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
	await _check_boundaries()
	print("PASS: coin sword five tiers/range/full third shot/pierce/retarget; native attack callback boundaries stop later darts, traces and combos")
	Audio.quit_cleanly()

func _check_boundaries() -> void:
	for lv in [3, 5]:
		for mode in ["normal", "result", "epoch", "dead", "stopped", "removed"]:
			var b := BattleProbe.new()
			root.add_child(b)
			b.set_process(false)
			var c = b._core
			c.set_process(false)
			c.foes.clear()
			c.kill.disconnect(b._on_core_kill)
			c.kill_heal = 0.0
			c.hero["atk"] = 100.0
			c.attr_set_base("crit", 0.0)
			c.hero["lucky"] = 0.0
			c._last_quota_wave = c.wave
			c._wave_spawned = c._wave_quota
			c._spawn_left = 0
			c._spawn_t = 9999.0
			c.intro_wait = 0.0
			c._hero_cd = 0.0
			c._hitstop = 0.0
			var first := _foe(c, Vector2(0.0, -30.0))
			var second := _foe(c, Vector2(0.0, -90.0))
			var third := _foe(c, Vector2(0.0, -150.0))
			first["hp"] = 1.0
			second["hp"] = 1000.0
			third["hp"] = 1000.0
			b._curio_id = "tongqianjian"
			b._curio_lv = lv
			b._dart_n = 2
			b._attack_count = 9
			b._combined.clear()
			for trigger in ["每次攻击", "每 5 次攻击", "每 10 次攻击"]:
				b._combined.append({"name": trigger, "trigger": trigger, "combo_key": "gold_flat", "combo_val": 1, "stacks": 0})
			var replacements: Array = []
			var uses: int = b._curio_uses
			var kills: int = c.kills_total
			var first_at := Vector2(first["x"], first["y"])
			var third_at := Vector2(third["x"], third["y"])
			c.kill.connect(func(_n):
				if mode == "result": b._end_run(false)
				elif mode == "epoch":
					c.clear_enemy_attacks()
					c.foes.clear()
					replacements.append(_foe(c, Vector2(0.0, -20.0)))
				elif mode == "dead": c.hero["hp"] = 0.0
				elif mode == "stopped": c.running = false
				elif mode == "removed": c.foes.erase(second))
			c._process(0.01) # 真实起手信号，而非只调用奇物子函数。
			assert(c.kills_total == kills + 1 and first.get("_death_settled", false))
			assert(b._dart_n == 3 and b._attack_count == 10 and b._curio_uses == uses + 1)
			if mode in ["normal", "removed"]:
				assert(second["hp"] == (1000.0 if mode == "removed" else (936.5 if lv == 5 else 957.0)))
				assert(third["hp"] == (957.0 if mode == "removed" else (979.5 if lv == 5 else 1000.0)))
				assert(b.traces.size() == 2)
				if mode == "removed": assert(b.traces[0] == first_at and b.traces[1] == third_at)
				for combo in b._combined: assert(combo["stacks"] == 1)
			else:
				assert(second["hp"] == 1000.0 and third["hp"] == 1000.0 and b.traces.is_empty())
				for combo in b._combined: assert(combo["stacks"] == 0)
				if mode == "epoch": assert(replacements[0]["hp"] == 10000.0)
			b.queue_free()
			await process_frame
	for dead in [false, true]:
		var b := BattleProbe.new()
		root.add_child(b)
		b.set_process(false)
		var c = b._core
		c.set_process(false)
		c.foes.clear()
		var f := _foe(c, Vector2(0.0, -30.0))
		b._curio_id = "tongqianjian"
		b._curio_lv = 5
		if dead: c.hero["hp"] = 0.0
		else: c.running = false
		var uses: int = b._curio_uses
		b._curio_on_attack()
		b._on_hero_attack()
		assert(f["hp"] == 10000.0 and b._dart_n == 0 and b._attack_count == 0 and b._curio_uses == uses and b.traces.is_empty())
		b.queue_free()
		await process_frame
