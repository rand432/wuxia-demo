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
	battle._skills.clear()
	battle._level_bonus(2)
	assert(is_equal_approx(battle._core.attr_final("mp"), 150.0))
	battle._mp = 0.0
	for i in range(120):
		battle._sync_attrs_to_hero()
		battle._tick_skills(0.1)
	assert(is_equal_approx(battle._mp, 150.0))
	assert(is_equal_approx(battle._core.hero["mp"], 150.0))
	battle._core.attr_add("mp", 150.0)
	battle._mp = 300.0
	battle._sync_attrs_to_hero()
	assert(is_equal_approx(battle._mp, 300.0))
	battle._core._spawn_foe()
	var skill: Dictionary = battle.SKILL_DEFS["zl"].duplicate(true)
	skill["aid"] = "zl"
	skill["cd_t"] = 0.0
	battle._skills = [skill]
	battle._tick_skills(0.0)
	assert(float(skill["cd_t"]) > 0.0)
	assert(is_equal_approx(battle._mp, 40.0) and is_equal_approx(battle._core.hero["mp"], 40.0))
	battle._sync_attrs_to_hero()
	assert(is_equal_approx(battle._mp, 40.0))
	battle.queue_free()
	await process_frame
	print("PASS: mana growth/regen survives synchronization; 260-cost skill casts and displayed mana matches")
	quit()
