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
	battle.queue_free()
	await process_frame
	print("PASS: pool impact/ticks/expiry/escape/long frames; failed-wave invalidation and paper survival")
	Audio.quit_cleanly()
