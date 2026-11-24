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
	var picked = battle._god_root.get_child(0)
	picked.pressed.emit()
	var apparition = battle._invocation_portrait
	assert(apparition.spectral and apparition._demo_left > 0.0)
	assert(apparition.character_id == picked.aid and apparition.texture == picked.portrait)
	await create_timer(1.25).timeout
	assert(not is_instance_valid(apparition))
	battle.queue_free()
	await process_frame
	print("PASS: duplicate excluded; Liu portrait preserved; accepted pick shares portrait and plays a fading apparition")
	quit()
