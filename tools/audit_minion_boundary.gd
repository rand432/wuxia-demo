extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

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
	b._core.hero["lucky"] = 0.0
	b._core.kill_heal = 0.0
	b._curio_id = "zhaohunfan"
	b._curio_lv = 5
	b._curio_cd = 0.0
	_foe(b._core, 1000.0)
	b._curio_tick_zhaohunfan()
	assert(b._minions.size() == 2)
	b._core.foes.clear()
	return b

func _foe(c, hp: float, offset := 0.0) -> Dictionary:
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": hp, "hp_max": 1000.0, "shield": false, "x": c.hero_pos.x, "y": c.hero_pos.y - offset}, true)
	return f

func _run() -> void:
	for expiry in [true, false]:
		for mode in ["normal", "result", "epoch", "dead", "stopped"]:
			var b = _battle()
			var c = b._core
			for m in b._minions:
				m["pos"] = c.hero_pos
				m["life"] = 0.05 if expiry else 100.0
				m["max_life"] = m["life"]
				m["atk_cd"] = 100.0 if expiry else 0.0
			var last: Dictionary = b._minions[1]
			var first := _foe(c, 1.0)
			var other := _foe(c, 1000.0, 30.0)
			var kills: int = b._kills
			var replacement: Array = []
			c.kill.connect(func(_n):
				b._tick_minions(0.1) # 同一击杀回调重入不能多扣寿命或重复自爆。
				c._kill_foe(first)
				if mode == "result": b._end_run(false)
				elif mode == "dead": c.hero["hp"] = 0.0
				elif mode == "stopped": c.running = false
				elif mode == "epoch":
					c.clear_enemy_attacks()
					c.foes.clear()
					replacement.append(_foe(c, 1000.0)))
			b._tick_minions(0.1)
			assert(not b._minions_ticking and first.get("_death_settled", false) and b._kills == kills + 1)
			if mode == "normal":
				assert(other["hp"] == (840.0 if expiry else 965.0))
				if expiry: assert(b._minions.is_empty())
				else: assert(is_equal_approx(last["life"], 99.9))
			else:
				assert(other["hp"] == 1000.0 and last["life"] == (0.05 if expiry else 100.0))
				assert(b._minions.size() == (1 if expiry else 2))
				if mode == "epoch": assert(replacement[0]["hp"] == 1000.0)
			b.queue_free()
			await process_frame
	# 死亡或停止时既不攻击，也不让寿命悄悄流逝。
	for dead in [false, true]:
		var b = _battle()
		var c = b._core
		var m: Dictionary = b._minions[0]
		var life: float = m["life"]
		var pos: Vector2 = m["pos"]
		var target := _foe(c, 1000.0)
		if dead: c.hero["hp"] = 0.0
		else: c.running = false
		b._tick_minions(100.0)
		assert(b._minions.size() == 2 and m["life"] == life and m["pos"] == pos and target["hp"] == 1000.0 and not b._minions_ticking)
		b._curio_cd = 0.0
		var uses: int = b._curio_uses
		b._curio_tick_zhaohunfan()
		b._curio_tick_tongjing()
		b._curio_summon("tongjing", "镜影", Color.WHITE, 5.0, 0.5, 0.0)
		assert(b._minions.size() == 2 and b._curio_cd == 0.0 and b._curio_uses == uses)
		b.queue_free()
		await process_frame
	print("PASS: two ghost expiry blasts once under reentry; attacks and later minions stop after callbacks; death/stop freeze lifetime and motion")
	Audio.quit_cleanly()
