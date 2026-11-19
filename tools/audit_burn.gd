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
	LS.current_level = 8
	var b = Battle.instantiate()
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
	return b

func _foe(c, hp := 10000.0) -> Dictionary:
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": hp, "hp_max": 1000.0, "shield": false, "res_fire": 0.0}, true)
	return f

func _run() -> void:
	for rate in [30, 60, 120, 0, -1, -2]:
		var b = _battle()
		var f := _foe(b._core)
		b._apply_burn(f, 2.0, 4.0)
		if rate > 0:
			for i in range(rate * 8): b._tick_burn(1.0 / rate)
		elif rate == 0: b._tick_burn(8.0)
		elif rate == -1: b._tick_burn(20.0)
		else:
			for dt in [0.17, 1.83, 0.1, 2.4, 3.5]: b._tick_burn(dt)
		assert(is_equal_approx(f["hp"], 9856.0)) # 前4秒2层96，后4秒1层48。
		assert(not f.has("burn") and not f.has("burn_acc"))
		b.queue_free()
		await process_frame
	var b = _battle()
	var c = b._core
	var f := _foe(c)
	b._apply_burn(f, 1.0, 0.4)
	b._tick_burn(10.0)
	assert(f["hp"] == 10000.0 and not f.has("burn"))
	b._apply_burn(f, 1.0, 4.0)
	b._tick_burn(0.6)
	assert(f["hp"] == 10000.0) # 上次余数不进入下一次点燃。
	b._tick_burn(0.4)
	assert(f["hp"] == 9988.0)
	f["hp"] = 10000.0
	f.erase("burn")
	c.type_add("火系", "amp_f", 0.25)
	f.merge({"vuln_t": 2.5, "vuln_pct": 50.0}, true)
	b._apply_burn(f, 1.0, 4.0)
	b._tick_burn(10.0)
	assert(is_equal_approx(f["hp"], 9925.0)) # 火共享一次，易伤仅前两跳。
	b.queue_free()
	await process_frame
	for mode in ["normal", "result", "epoch", "dead", "stopped", "removed"]:
		b = _battle()
		c = b._core
		var first := _foe(c, 1.0)
		var other := _foe(c)
		b._apply_burn(first, 1.0, 4.0)
		b._apply_burn(other, 1.0, 4.0)
		var kills: int = c.kills_total
		var replacement: Array = []
		c.kill.connect(func(_n):
			c._kill_foe(first) # 同次击杀不可重复发奖励。
			if mode == "result": b._end_run(false)
			elif mode == "epoch":
				c.clear_enemy_attacks()
				c.foes.clear()
				replacement.append(_foe(c))
			elif mode == "dead": c.hero["hp"] = 0.0
			elif mode == "stopped": c.running = false
			elif mode == "removed": c.foes.erase(other))
		b._tick_burn(10.0)
		assert(c.kills_total == kills + 1 and first.get("_death_settled", false))
		assert(other["hp"] == (9952.0 if mode == "normal" else 10000.0))
		if mode != "normal": assert(other["burn_t"] == 4.0 and other["burn_acc"] == 0.0)
		if mode == "epoch": assert(replacement[0]["hp"] == 10000.0)
		b.queue_free()
		await process_frame
	for mode in ["dead", "stopped", "removed"]:
		b = _battle()
		c = b._core
		f = _foe(c)
		b._apply_burn(f, 1.0, 4.0)
		if mode == "dead": c.hero["hp"] = 0.0
		elif mode == "stopped": c.running = false
		else: c.foes.erase(f)
		b._apply_burn(f, 1.0, 4.0)
		b._tick_burn(10.0)
		assert(f["hp"] == 10000.0 and f["burn"] == 1.0 and f["burn_t"] == 4.0 and f["burn_acc"] == 0.0)
		b.queue_free()
		await process_frame
	# 当前黑市朱雀羽实际点燃；只搭载现有神器，不开放封印角色。
	b = _battle()
	c = b._core
	f = _foe(c, 1.0)
	b._apply_burn(f, 1.0, 4.0)
	var next_foes: Array = []
	c.kill.connect(func(_n):
		c.clear_enemy_attacks()
		c.foes.clear()
		var next := _foe(c)
		next.merge({"poison": 1.0, "poison_t": 4.0, "poison_acc": 0.0, "vuln_t": 5.0}, true)
		next_foes.append(next))
	assert(not b._tick_battle_effects(1.0))
	assert(next_foes.size() == 1 and next_foes[0]["hp"] == 10000.0 and next_foes[0]["poison_t"] == 4.0 and next_foes[0]["vuln_t"] == 5.0)
	b.queue_free()
	await process_frame
	b = _battle()
	c = b._core
	f = _foe(c)
	b._bm.slots = [{"name": "朱雀羽"}]
	b._bm._on_hero_foe_hit(f, 100.0, true, false)
	assert(f["burn"] == 1.0 and f["burn_t"] == 4.0)
	b._tick_burn(20.0)
	assert(f["hp"] == 9952.0 and not f.has("burn"))
	# 保留封印炫卡的兼容规则：无限灼烧不衰减，但不额外开放入口。
	b._burn_unlimited = true
	b._apply_burn(f, 2.0, 4.0)
	b._tick_burn(8.0)
	assert(f["hp"] == 9760.0 and f["burn"] == 2.0)
	b.queue_free()
	await process_frame
	print("PASS: burn 30/60/120/jitter/long frame decay, duration cap and fresh accumulator; fire/vulnerability once; immediate kill and callback boundaries; current market ignite and sealed unlimited compatibility")
	Audio.quit_cleanly()
