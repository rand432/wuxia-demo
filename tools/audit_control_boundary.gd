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
	var c = b._core
	c.set_process(false)
	c.foes.clear()
	c.kill.disconnect(b._on_core_kill)
	c.kill_heal = 0.0
	c.hero["atk"] = 100.0
	c.hero["hp"] = 1000.0
	c.hero["hp_max"] = 1000.0
	c.hero["lucky"] = 0.0
	c.attr_set_base("crit", 0.0) # 本专项断言非暴击伤害，不能保留默认5%随机暴击。
	c._last_quota_wave = c.wave
	c._wave_spawned = c._wave_quota
	c._spawn_left = 0
	c._spawn_t = 9999.0
	c.intro_wait = 9999.0
	c._hero_cd = 9999.0
	c._hitstop = 0.0
	return b

func _foe(c, hp: float, offset: float) -> Dictionary:
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": hp, "hp_max": 1000.0, "shield": false, "x": c.hero_pos.x + offset,
		"y": c.hero_pos.y, "t": 0.0, "stop": 1000.0, "wood_t": 10.0}, true)
	return f

func _run() -> void:
	for kind in ["cold", "wood", "dot", "sweep"]:
		for mode in ["normal", "result", "epoch", "dead", "stopped", "removed"]:
			var b = _battle()
			var c = b._core
			b._curio_id = "hanyu" if kind == "cold" else "jingtangmu"
			b._curio_lv = 5
			var first := _foe(c, 1.0, 40.0)
			var other := _foe(c, 1000.0, 60.0)
			var source := _foe(c, 1000.0 if kind == "cold" else 1.0, 20.0)
			if kind == "cold":
				for i in range(3): b._curio_on_crit(source)
				source["cold_freeze_t"] = 0.005
			elif kind == "wood": source.merge({"wood_t": 0.005, "wood_boom": true}, true)
			elif kind == "dot": source["dot"] = [{"t": 1.0, "tick": 0.0, "mul": 1.0, "dtype": "木系"}]
			else: source["hp"] = 0.0
			var kills: int = c.kills_total
			var replacements: Array = []
			c.kill.connect(func(_n):
				if mode == "result": b._end_run(false)
				elif mode == "epoch":
					c.clear_enemy_attacks()
					c.foes.clear()
					replacements.append(_foe(c, 1000.0, 30.0))
				elif mode == "dead": c.hero["hp"] = 0.0
				elif mode == "stopped": c.running = false
				elif mode == "removed": c.foes.erase(other))
			c._process(0.01)
			assert(c.kills_total == kills + 1)
			assert((first if kind == "cold" else source).get("_death_settled", false))
			if mode == "normal":
				assert(other["hp"] == (960.0 if kind == "cold" else 1000.0))
				assert(is_equal_approx(other["wood_t"], 9.99))
			else:
				assert(other["hp"] == 1000.0 and other["wood_t"] == 10.0)
				if mode == "epoch": assert(replacements[0]["hp"] == 1000.0 and replacements[0]["wood_t"] == 10.0)
			b.queue_free()
			await process_frame
	# 无效战斗与撤场来源：到期标记只消费一次，不爆炸，不生成新寒层。
	for mode in ["dead", "stopped", "removed"]:
		var b = _battle()
		var c = b._core
		var other := _foe(c, 1000.0, 40.0)
		var source := _foe(c, 1000.0, 20.0)
		b._curio_lv = 5
		source.merge({"cold_boom": true, "wood_boom": true, "wood_vuln": 0.3}, true)
		if mode == "dead": c.hero["hp"] = 0.0
		elif mode == "stopped": c.running = false
		else: c.foes.erase(source)
		b._curio_id = "hanyu"
		b._curio_on_crit(source)
		b._curio_on_cold_expired(source)
		b._curio_on_cold_expired(source)
		b._curio_on_wood_expired(source)
		assert(other["hp"] == 1000.0 and source["hp"] == 1000.0 and not source.has("cold"))
		assert(not source.has("cold_boom") and not source.has("wood_boom") and not source.has("wood_vuln"))
		b.queue_free()
		await process_frame
	print("PASS: native cold/wood expiry, dot and zero-HP settlement stop at kill callback boundaries; removed targets/sources and stopped/dead entries")
	Audio.quit_cleanly()
