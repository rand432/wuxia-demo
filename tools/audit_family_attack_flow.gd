extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const GS := preload("res://shared/game_state.gd")
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
	GS.skill_lv["zhujue"] = 0
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	var c = b._core
	c.set_process(false)
	c.foes.clear()
	c.attr_set_base("atk", 100.0)
	c.attr_set_base("crit", 0.0)
	c.hero["atk"] = 100.0
	c.hero["lucky"] = 0.0
	c.hero["basic_skill_bonus"] = 0.0
	c.kill_heal = 0.0
	return b

func _foe(c, y_offset: float, hp := 1000.0) -> Dictionary:
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"x": c.hero_pos.x, "y": c.hero_pos.y + y_offset, "hp": hp, "hp_max": 100.0, "shield": false}, true)
	return f

func _run() -> void:
	var b = _battle()
	var c = b._core
	var primary := _foe(c, -60.0)
	var nearest := _foe(c, -20.0)
	c.order_focus(primary)
	b._hero_passive = {"tgt_add": 1, "chase": 100}
	b._on_hero_attack()
	assert(primary["hp"] == 1000.0 and nearest["hp"] == 1000.0) # 起手不提前追击。
	c._hero_strike(primary)
	assert(primary["hp"] == 854.0 and nearest["hp"] == 932.0) # 主刀98＋追击48；另一个多目标68。
	assert(b._attack_count == 1)
	b.queue_free()
	await process_frame
	# 真正核心帧：起手先等前摇，主刀落下后才执行家传追加。
	b = _battle(); c = b._core
	primary = _foe(c, -60.0)
	nearest = _foe(c, -20.0)
	primary["para"] = 10.0
	nearest["para"] = 10.0
	c.order_focus(primary)
	c._last_quota_wave = c.wave
	c._spawn_t = 999.0
	c._spawn_left = 0
	c.intro_wait = 0.0
	c._hero_cd = 0.0
	b._hero_passive = {"tgt_add": 1, "chase": 100}
	c._process(0.001)
	assert(primary["hp"] == 1000.0 and nearest["hp"] == 1000.0 and b._attack_count == 1)
	c._hitstop = 0.0
	c._process(0.20)
	assert(primary["hp"] == 854.0 and nearest["hp"] == 932.0 and b._attack_count == 1)
	b.queue_free()
	await process_frame
	# 追击当场击杀，奖励/计数立即到账，补扫与重入不重复。
	b = _battle(); c = b._core
	primary = _foe(c, -40.0, 110.0)
	b._hero_passive = {"chase": 100}
	var kills: int = b._kills
	var money: int = b._wen
	c.kill.connect(func(_n): c._kill_foe(primary))
	c._hero_strike(primary)
	assert(primary.get("_death_settled", false) and b._kills == kills + 1 and b._wen > money)
	c._kill_foe(primary)
	assert(b._kills == kills + 1)
	b.queue_free()
	await process_frame
	# 剑气圆心是本刀主目标，不是更近的其他怪。
	b = _battle(); c = b._core
	primary = _foe(c, -80.0)
	nearest = _foe(c, -10.0)
	var outside := _foe(c, 110.0)
	b._hero_passive = {"qijian": 100}
	c._hero_strike(primary)
	assert(primary["hp"] == 784.0 and nearest["hp"] == 882.0 and outside["hp"] == 1000.0)
	b.queue_free()
	await process_frame
	# 追加目标击杀回调结束/换波，后续追击和剑气不得继续。
	for result_end in [false, true]:
		b = _battle(); c = b._core
		primary = _foe(c, -60.0)
		var extra := _foe(c, -20.0, 1.0)
		var untouched := _foe(c, -10.0, 1.0)
		b._hero_passive = {"tgt_add": 1, "chase": 100, "qijian": 100}
		c.kill.connect(func(_n):
			if result_end: b._end_run(false)
			else: c.clear_enemy_attacks())
		# 最近者先被额外目标选中；原主目标始终被排除。
		c._hero_strike(primary)
		assert(primary["hp"] == 902.0 and untouched.get("_death_settled", false) and extra["hp"] == 1.0)
		b.queue_free()
		await process_frame
	# 真实六档合成：10级剑法20%＋家传40%，共享15%只经过一次物理层。
	b = _battle(); c = b._core
	GS.stars["zhujue"] = 5
	GS.skill_lv["zhujue"] = 10
	b._sync_attrs_to_hero()
	b._grant_ancestor("zhujue")
	for tier in range(6):
		for index in range(3): b._add_card("zhujue_t%d_%d" % [tier, index])
	assert(b._hero_passive["tgt_add"] == 1 and b._hero_passive["qijian"] == 20)
	assert(is_equal_approx(c.basic_attack_multiplier(), 1.6) and is_equal_approx(c.type_amp("物理"), 0.15))
	b._hero_passive["qijian"] = 100 # 仅固定触发概率，伤害和范围仍走实际家传实现。
	primary = _foe(c, -40.0)
	nearest = _foe(c, -20.0)
	c._heavy = 0
	c._hero_strike(primary)
	assert(is_equal_approx(primary["hp"], 599.2) and is_equal_approx(nearest["hp"], 654.4))
	# 剑魄250%与300px范围，不能残留原0.8基数变成200%。
	b._enable_jianpo()
	primary["hp"] = 1000.0
	nearest["hp"] = 1000.0
	outside = _foe(c, 200.0)
	c._heavy = 0
	c._hero_strike(primary)
	assert(is_equal_approx(primary["hp"], 360.0) and is_equal_approx(nearest["hp"], 415.2) and is_equal_approx(outside["hp"], 542.0))
	assert(c.hero["atk"] == 100.0)
	GS.stars["zhujue"] = 0
	GS.skill_lv["zhujue"] = 0
	b.queue_free()
	await process_frame
	print("PASS: family attacks resolve after primary; actual focused target; immediate once-only rewards; sword center and callback boundaries")
	Audio.quit_cleanly()
