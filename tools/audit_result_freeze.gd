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
	LS.current_level = 5
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle._core._spawn_foe()
	var foe: Dictionary = battle._core.foes[0]
	battle._end_run(false)
	var time: float = battle._run_time
	var mp: float = battle._mp
	var hp: float = foe["hp"]
	var cards: int = battle._cards.size()
	var crystal: int = battle._crystal
	battle._show_draw(true)
	battle._on_refresh()
	assert(battle._crystal == crystal)
	battle._tick_skills(2.0)
	battle._cast_skill(0)
	battle._add_card("atk_0_0")
	for i in range(30): battle._process(0.016)
	assert(battle._run_time == time and battle._mp == mp)
	assert(foe["hp"] == hp and battle._cards.size() == cards)
	assert(not battle._core.running)
	battle.queue_free()
	await process_frame
	print("PASS: result stops run timer, skills, resource changes and delayed card claims")
	quit()
