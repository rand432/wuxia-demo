extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	GS.ensure_loaded()
	LS.ensure_loaded()
	LS.current_level = 1
	LS.max_unlocked = 10
	assert(change_scene_to_packed(Battle) == OK)
	await scene_changed
	var b = current_scene
	await create_timer(5.5).timeout
	b.set_process(false)
	if b._core != null:
		b._core.set_process(false)
	await process_frame
	get_root().get_texture().get_image().save_png("D:/1/wuxia-demo/.shots/after_art_l1.png")
	print("[SHOT] foes=", b._core.foes.size(), " tokens=", b._foe_tokens.size())
	quit(0)
