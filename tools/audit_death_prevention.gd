extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
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
	battle._curio_id = "yuhu"
	battle._bm.slots = [{"name": "玄武甲"}, {"name": "长生玉"}]
	battle._core._spawn_foe()
	var enemy_count: int = battle._core.foes.size()
	var lives: int = battle._life
	for ratio in [0.25, 0.3]:
		battle._core.hero["hp"] = 0.0
		battle._core.running = false
		battle._core.hero_down.emit()
		assert(battle._life == lives and not battle._run_over)
		assert(battle._core.foes.size() == enemy_count)
		assert(battle._core.running)
		assert(is_equal_approx(battle._core.hero["hp"], battle._core.attr_final("hp") * ratio))
	assert(not battle._bm.try_prevent_death())
	battle._core.set_wave(2)
	assert(battle._bm.try_prevent_death())
	assert(not battle._bm.try_prevent_death())
	battle.queue_free()
	await process_frame
	print("PASS: armor/jade prevent death before life loss/clear; per-wave and once-only limits preserved")
	quit()
