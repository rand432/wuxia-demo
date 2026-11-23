extends SceneTree
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")
func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 5
	var battle = BATTLE.instantiate()
	root.add_child(battle)
	battle._draw_charge = 2
	battle._god_hand_charge = 2
	battle._pick_god("chenshi")
	assert(battle._ancestors.has("chenshi"))
	assert(battle._draw_charge == 1 and battle._god_hand_charge == -1)
	battle._pick_god("chenshi")
	assert(battle._draw_charge == 1)
	battle._draw_charge = 2
	battle._show_god_pick()
	for card in battle._god_root.get_children():
		assert(card.aid != "chenshi")
		assert(card.portrait.resource_path.ends_with("portrait_liuqingqing_ink_v1.png"))
		assert(card.skill_art.resource_path.ends_with("skill_liuqingqing.png"))
	battle.queue_free()
	await process_frame
	print("PASS: new god hand excludes owned; duplicate pick free; current Liu portrait and separate skill seal")
	quit()
