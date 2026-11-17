extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _battle():
	LS.ensure_loaded()
	LS.current_level = 6
	GS.skill_lv = {}
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	var c = b._core
	c.set_process(false)
	c.foes.clear()
	c.attr_set_base("crit", 0.0)
	c.attr_set_base("hp", 1000.0)
	c.hero["hp_max"] = 1000.0
	c.hero["hp"] = 500.0
	c.hero["lucky"] = 0.0
	c.hero_pos = Vector2(360, 600)
	c.kill_heal = 0.0
	return b

func _foe(c, x: float, y: float, hp := 1000.0) -> Dictionary:
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": hp, "hp_max": 1000.0, "shield": false, "x": x, "y": y}, true)
	return f

func _run() -> void:
	# 同一敌人下一次施法仍可连锁，非炫卡每次仅一次；伤害60扣20护甲=40。
	var b = _battle()
	var c = b._core
	var first := _foe(c, 360, 500)
	var second := _foe(c, 360, 400)
	b._charge_ram()
	assert(first["hp"] == 960.0)
	var old_ctx: Dictionary = first["_ram_ctx"]
	b._tick_knock(0.08)
	assert(second["hp"] == 960.0 and old_ctx["budget"] == 0)
	b._charge_ram() # 现在second更近，反过来撞到first，不应被上一轮的标记排除。
	b._tick_knock(1.0 / 60.0)
	assert(first["hp"] == 920.0 and second["hp"] == 920.0)
	assert(not is_same(old_ctx, second["_ram_ctx"]))
	b.queue_free()
	await process_frame
	# 两个仍在飞行的施法各自持有伤害/预算，第二次施法不覆盖第一组。
	b = _battle(); c = b._core
	c.hero_pos = Vector2(300, 600)
	first = _foe(c, 300, 500)
	second = _foe(c, 300, 400)
	b._charge_ram()
	old_ctx = first["_ram_ctx"]
	c.hero["hp_max"] = 2000.0
	c.hero_pos = Vector2(420, 650)
	var third := _foe(c, 420, 550)
	var fourth := _foe(c, 420, 450)
	b._charge_ram()
	var new_ctx: Dictionary = third["_ram_ctx"]
	b._tick_knock(0.06)
	assert(old_ctx["damage"] == 60.0 and new_ctx["damage"] == 120.0)
	assert(second["hp"] == 960.0 and fourth["hp"] == 900.0 and old_ctx["budget"] == 0 and new_ctx["budget"] == 0)
	b.queue_free()
	await process_frame
	# 滚山接力的第一帧保留扫掠起点；每个接力目标只命中一次，加8上限只登记一次。
	b = _battle(); c = b._core
	b._ram_shiny = true
	first = _foe(c, 360, 500)
	second = _foe(c, 360, 400)
	third = _foe(c, 360, 375)
	b._charge_ram()
	b._tick_knock(0.05)
	assert(first["hp"] == 960.0 and second["hp"] == 960.0 and third["hp"] == 960.0)
	assert(c.hero["hp_max"] == 1016.0 and c.hero["hp"] == 516.0)
	assert(is_same(first["_ram_ctx"], second["_ram_ctx"]) and is_same(second["_ram_ctx"], third["_ram_ctx"]))
	b._tick_knock(0.0)
	assert(c.hero["hp_max"] == 1016.0 and third["hp"] == 960.0)
	b.queue_free()
	await process_frame
	# 每个被撞者仅能接力一次，旧来源继续飞行不能在下一帧再次撞一个新敌。
	b = _battle(); c = b._core
	b._ram_shiny = true
	first = _foe(c, 360, 500)
	second = _foe(c, 360, 400)
	b._charge_ram()
	b._tick_knock(0.05)
	b._ram_stop(second)
	third = _foe(c, 360, 375)
	b._tick_knock(0.05)
	assert(third["hp"] == 1000.0 and c.hero["hp_max"] == 1008.0)
	b.queue_free()
	await process_frame
	# 初撞致死当场奖励，不把尸体重新发射。
	b = _battle(); c = b._core
	first = _foe(c, 360, 500, 1.0)
	var kills: int = b._kills
	c.kill.connect(func(_n): c._kill_foe(first))
	b._charge_ram()
	assert(first.get("_death_settled", false) and b._kills == kills + 1 and float(first.get("_kx", 0.0)) == 0.0 and not first.has("_ram_ctx"))
	b.queue_free()
	await process_frame
	# 反弹击杀回调结束、清场、死亡或停止后，不再发射/增长/碰撞下一目标。
	for mode in ["result", "epoch", "dead", "stopped"]:
		b = _battle(); c = b._core
		b._ram_shiny = true
		first = _foe(c, 360, 500)
		second = _foe(c, 360, 400, 1.0)
		third = _foe(c, 360, 375)
		var replacement: Array = []
		kills = b._kills
		c.kill.connect(func(_n):
			c._kill_foe(second)
			if mode == "result": b._end_run(false)
			elif mode == "dead": c.hero["hp"] = 0.0
			elif mode == "stopped": c.running = false
			else:
				c.clear_enemy_attacks()
				c.foes.clear()
				replacement.append(_foe(c, 360, 400)))
		b._charge_ram()
		b._tick_knock(0.05)
		assert(second.get("_death_settled", false) and b._kills == kills + 1 and third["hp"] == 1000.0)
		assert(c.hero["hp_max"] == 1000.0 and not second.has("_ram_ctx"))
		if mode == "epoch": assert(replacement[0]["hp"] == 1000.0)
		b.queue_free()
		await process_frame
	# 清场批次变化即使保留原敌人，也会使旧动量失效；暂停时不移动。
	b = _battle(); c = b._core
	first = _foe(c, 360, 500)
	second = _foe(c, 360, 400)
	b._charge_ram()
	c.running = false
	b._tick_knock(0.06)
	assert(first["y"] == 500.0 and second["hp"] == 1000.0)
	c.running = true
	c.clear_enemy_attacks()
	b._tick_knock(0.06)
	assert(first["y"] == 500.0 and first["_ky"] == 0.0 and not first.has("_ram_ctx") and second["hp"] == 1000.0)
	b.queue_free()
	await process_frame
	print("PASS: ram once-only deaths; per-cast hit/budget/damage isolation; repeat casts; shiny sweep/growth; callback, pause and stale-epoch boundaries")
	Audio.quit_cleanly()
