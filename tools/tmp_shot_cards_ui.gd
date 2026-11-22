extends SceneTree
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _snap(name: String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.shots/%s.png" % name)

func _run() -> void:
	root.size = Vector2i(720, 1280)
	root.content_scale_size = Vector2i(720, 1280)
	GS.ensure_loaded(); LS.ensure_loaded(); LS.current_level = 3
	var a = load("res://kushou/battle_ui.tscn").instantiate()
	root.add_child(a)
	await create_timer(2.4).timeout
	await _snap("cards_back")
	a._build_result(true)
	await _snap("result_win")
	a.queue_free()
	await process_frame
	LS.current_level = 4
	var b = load("res://kushou/battle_ui.tscn").instantiate()
	root.add_child(b)
	await create_timer(1.6).timeout
	b._build_result(false)
	await _snap("result_lose")
	print("PASS: cards_ui")
	quit()
