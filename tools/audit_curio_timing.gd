extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle._core.set_process(false)
	battle._curio_id = "yuhu"
	battle._curio_lv = 5
	battle._core.hero["hp_max"] = 1000.0
	battle._core.hero["hp"] = 150.0
	battle._curio_cd = 23.0
	battle._curio_tick_yuhu(0.0)
	assert(battle._curio_uses == 0 and not battle._curio_extra_used)
	battle._core.hero["hp"] = 140.0
	battle._mp_max = 100.0
	battle._mp = 0.0
	battle._curio_tick_yuhu(0.0)
	assert(is_equal_approx(battle._core.hero["hp"], 440.0))
	assert(is_equal_approx(battle._mp, 30.0))
	assert(battle._curio_cd == 23.0 and battle._curio_extra_used)
	assert(battle._curio_uses == 1 and battle._yuhu_shield == 4.0)
	battle._core.hero["hp"] = 100.0
	battle._curio_tick_yuhu(0.0)
	assert(battle._curio_uses == 1 and battle._core.hero["hp"] == 100.0)
	battle._curio_cd = 0.0
	battle._curio_tick_yuhu(0.0)
	assert(battle._curio_uses == 2 and battle._curio_cd == 45.0)
	# 额外次数在普通冷却空闲时也不启动冷却；四级不能越过冷却。
	battle._curio_extra_used = false
	battle._core.hero["hp"] = 100.0
	battle._curio_cd = 0.0
	battle._curio_tick_yuhu(0.0)
	assert(battle._curio_cd == 0.0 and battle._curio_uses == 3)
	battle._curio_lv = 4
	battle._core.hero["hp"] = 100.0
	battle._curio_cd = 10.0
	battle._curio_tick_yuhu(0.0)
	assert(battle._curio_uses == 3)
	# 血葫芦：总延时四秒，计时流逝不补回延时额度。
	battle._curio_id = "xuehulu"
	battle._curio_lv = 3
	battle._curio_cd = 0.0
	battle._core.hero["hp"] = 600.0
	battle._core._spawn_foe()
	battle._core.foes[0]["x"] = battle._core.hero_pos.x + 100.0
	battle._core.foes[0]["y"] = battle._core.hero_pos.y
	battle._curio_tick_xuehulu()
	assert(battle._curio_atk_t == 11.0)
	battle._curio_on_kill(1)
	assert(is_equal_approx(battle._curio_atk_t, 11.6))
	battle._tick_curio(3.0)
	battle._curio_on_kill(100)
	assert(is_equal_approx(battle._curio_atk_t, 12.0))
	assert(is_equal_approx(battle._curio_extend_used, 4.0))
	battle._tick_curio(1.0)
	battle._curio_on_kill(100)
	assert(is_equal_approx(battle._curio_atk_t, 11.0))
	battle._curio_atk_t = 0.0
	battle._curio_on_kill(1)
	assert(battle._curio_atk_t == 0.0)
	battle._curio_cd = 0.0
	battle._curio_tick_xuehulu()
	assert(battle._curio_extend_used == 0.0)
	battle._curio_lv = 2
	battle._curio_on_kill(1)
	assert(battle._curio_extend_used == 0.0)
	# 醉翁壶：边流逝边暴击也只加五秒；下次十杀重新计额度。
	battle._curio_id = "zuiweng"
	battle._curio_lv = 5
	battle._curio_on_kill(10)
	assert(battle._curio_atk_t == 10.0 and battle._curio_extend_used == 0.0)
	for i in range(10):
		battle._tick_curio(0.5)
		battle._curio_on_crit({})
	assert(is_equal_approx(battle._curio_atk_t, 10.0))
	assert(battle._curio_extend_used == 5.0)
	battle._curio_on_kill(10)
	assert(battle._curio_extend_used == 0.0)
	battle._tick_curio(10.0)
	assert(battle._core.hero["curio_atk"] == 0.0)
	assert(battle._core.hero["curio_aspd"] == 0.0 and battle._core.hero["curio_crit"] == 0.0)
	battle._curio_on_crit({})
	assert(battle._curio_atk_t == 0.0)
	battle.queue_free()
	await process_frame
	print("PASS: jade flask emergency bypass preserves cooldown; blood/drunk extension budgets cap and reset")
	Audio.quit_cleanly()
