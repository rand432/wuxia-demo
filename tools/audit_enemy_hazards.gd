extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _pool(core) -> void:
	core.queue_delayed(core.hero_pos.x, core.hero_pos.y, 70.0, 20.0, "真实", 1.0, "pool test", "pool", Vector2.RIGHT, 0.0, 0.0, 0, 0.0, 3.0)

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.hero["hp_max"] = 1000.0
	core.hero["hp"] = 1000.0
	battle._curio_id = ""
	battle._bm.slots.clear()
	_pool(core)
	core._delayed_tick(0.5)
	assert(core.hero["hp"] == 1000.0)
	core._delayed_tick(0.5)
	assert(core.hero["hp"] == 980.0 and core._delayed.size() == 1)
	core._delayed_tick(0.99)
	assert(core.hero["hp"] == 980.0)
	core._delayed_tick(0.01)
	assert(core.hero["hp"] == 970.0)
	core._delayed_tick(2.1)
	assert(core.hero["hp"] == 950.0 and core._delayed.is_empty())
	# 单个长帧跨过预警与持续期也只能结算同样次数。
	core.hero["hp"] = 1000.0
	_pool(core)
	core._delayed_tick(4.5)
	assert(core.hero["hp"] == 950.0 and core._delayed.is_empty())
	# 离开地面范围不受伤，重新进入时仅吃剩余跳数。
	core.hero["hp"] = 1000.0
	_pool(core)
	core._delayed_tick(1.0)
	var position_before: Vector2 = core.hero_pos
	core.hero_pos += Vector2(300.0, 0.0)
	core._delayed_tick(1.0)
	assert(core.hero["hp"] == 980.0)
	core.hero_pos = position_before
	core._delayed_tick(2.0)
	assert(core.hero["hp"] == 960.0 and core._delayed.is_empty())
	# 五级纸人只拦截落下预警，不每秒替持续地面伤害耗一张。
	battle._curio_id = "zhiren"
	battle._curio_lv = 5
	battle._set_paper_count(2)
	core.hero["hp"] = 1000.0
	_pool(core)
	core._delayed.back()["boss_attack"] = true
	core._delayed_tick(1.0)
	assert(core.hero["hp"] == 1000.0 and battle._zhiren == 1)
	core._delayed_tick(1.0)
	assert(core.hero["hp"] == 990.0 and battle._zhiren == 1)
	core.clear_enemy_attacks()
	battle._curio_id = ""
	battle._set_paper_count(0)
	# 预警致命导致跳波：清空整个旧批次，不能继续用旧索引或再扣一命。
	core.foes.clear()
	core._spawn_foe()
	core.foes[0]["hp"] = 100.0
	core.set_wave(1)
	battle._life = 100
	core.hero["hp"] = 1.0
	var epoch: int = core._enemy_attack_epoch
	core.queue_delayed(core.hero_pos.x, core.hero_pos.y, 70.0, 2000.0, "真实", 1.0)
	_pool(core)
	core._delayed_tick(1.0)
	assert(core.wave == 2 and core._enemy_attack_epoch == epoch + 1)
	assert(core._delayed.is_empty() and core.hero["hp"] == 1000.0)
	assert(battle._life == 99 and battle._curio_waves == 0 and not battle._run_over)
	core._delayed_tick(10.0)
	assert(core.hero["hp"] == 1000.0 and battle._life == 99)
	# 已落地持续伤害触发跳波，也要立刻中止本次长帧的后续跳数。
	core.foes.clear()
	core._spawn_foe()
	core.foes[0]["hp"] = 100.0
	_pool(core)
	core._delayed_tick(1.0)
	core.hero["hp"] = 1.0
	epoch = core._enemy_attack_epoch
	core._delayed_tick(3.0)
	assert(core.wave == 3 and core._enemy_attack_epoch == epoch + 1)
	assert(core.hero["hp"] == 1000.0 and core._delayed.is_empty() and battle._life == 98)
	# 真正保命不跳波，其他地面威胁仍按原规则持续存在。
	battle._curio_id = "zhiren"
	battle._curio_lv = 1
	battle._set_paper_count(1)
	core.hero["hp"] = 1.0
	epoch = core._enemy_attack_epoch
	_pool(core)
	core._delayed_tick(1.0)
	assert(core.wave == 3 and core._enemy_attack_epoch == epoch)
	assert(core._delayed.size() == 1 and battle._zhiren == 0 and core.hero["hp"] == 1000.0)
	# 首领实例必须继承配置里的形态和循环冷却。
	core.clear_enemy_attacks()
	core.foes.clear()
	core._hitstop = 0.0
	core.start_boss(1, "石甲巨猿")
	var boss: Dictionary = core._boss_foe()
	assert(boss["ult_t"] == 15.0 and boss["ult_shape"] == "ring")
	boss["ult_t"] = 0.0
	core._process(0.01)
	assert(boss["ult_t"] == 15.0 and core._delayed.size() == 1)
	var cast: Dictionary = core._delayed[0]
	assert(cast["kind"] == "裂地拳" and cast["shape"] == "ring" and is_same(cast["caster"], boss))
	boss["x"] += 24.0
	core._delayed_tick(0.1)
	assert(cast["x"] == boss["x"] and cast["y"] == boss["y"])
	core.interrupt_cast(boss)
	assert(core._delayed.is_empty())
	# 号令使用首领的额外名额，只移动这轮实际新生的敌人。
	core.foes.clear()
	core.start_boss(4, "困兽·终焉")
	boss = core._boss_foe()
	core.intro_wait = 0.0
	for i in range(core.MAX_FOES - 1):
		assert(not core._spawn_foe().is_empty())
	var sentinel: Dictionary = core.foes.back()
	sentinel["y"] = 325.0
	core._hitstop = 0.0
	boss["boss_summon_t"] = 0.0
	core._process(0.01)
	assert(core.foes.size() == core.MAX_FOES + 2 and float(sentinel["y"]) > 320.0)
	assert(core.foes[-2]["y"] == -30.0 and core.foes[-1]["y"] == -70.0)
	assert(core._banner.contains("2 只") and boss["boss_summon_t"] == 12.0)
	while core.foes.size() < core.BOSS_SUMMON_FIELD_CAP - 1:
		assert(not core._spawn_foe("chal").is_empty())
	boss["boss_summon_t"] = 0.0
	core._process(0.01)
	assert(core.foes.size() == core.BOSS_SUMMON_FIELD_CAP and core._banner.contains("1 只"))
	core._banner = ""
	boss["boss_summon_t"] = 0.0
	core._process(0.01)
	assert(core.foes.size() == core.BOSS_SUMMON_FIELD_CAP and core._banner.is_empty())
	assert(core._spawn_foe().is_empty() and float(sentinel["y"]) > 320.0)
	battle.queue_free()
	await process_frame
	print("PASS: pool timing, failed-wave invalidation, paper survival and bounded boss summons")
	Audio.quit_cleanly()
