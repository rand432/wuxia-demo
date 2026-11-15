extends SceneTree
const LS := preload("res://shared/level_state.gd")
var page: Control
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")
func _capture(name: String) -> void:
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_png("res://.shots/" + name + ".png")
	assert(err == OK)
func _run() -> void:
	root.size = Vector2i(720, 1280)
	root.content_scale_size = Vector2i(720, 1280)
	LS.ensure_loaded()
	LS.current_level = 5
	page = load("res://menu/partner_home.tscn").instantiate()
	root.add_child(page)
	await _capture("audit_partner")
	page._show_advance()
	await _capture("audit_advance")
	page.queue_free()
	await process_frame
	page = load("res://menu/main_home.tscn").instantiate()
	root.add_child(page)
	await _capture("audit_main")
	page.queue_free()
	await process_frame
	print("PASS: visual captures saved")
	quit()
