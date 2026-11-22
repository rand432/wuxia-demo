extends SceneTree
const Scene := preload("res://kushou/battle_ui.tscn")
const Levels := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	call_deferred("_run")

func _click(point: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		click.pressed = down
		root.push_input(click, true)

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)

func _run() -> void:
	seed(20261123)
	Levels.ensure_loaded()
	Levels.current_level = 6
	var battle = Scene.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame
	battle._tut.cancel()
	battle.set_process(false)
	battle._core.set_process(false)
	await create_timer(0.6).timeout
	_click(Vector2(690, 981))
	assert(battle._page == 1)
	_click(Vector2(30, 981))
	assert(battle._page == 0)
	var options: Array = battle._pool.duplicate()
	assert(options.size() > 6)
	for i in range(5):
		battle._cards.append(options[i])
		battle._pool.erase(options[i])
	battle._refresh_deck()
	assert(battle._slots[0].art != null and not battle._slots[0].card_name.is_empty())
	battle._crystal = 200
	battle._update_crystal()
	_click(Vector2(640, 1180))
	assert(battle._draw_layer.visible and battle._draw_paid)
	await create_timer(0.55).timeout
	await _capture("res://deck_draw_tray.png")
	var frames := "res://deck_claim_frames"
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frames)) == OK)
	var first = battle._draw_cards[0]
	var chosen: String = first.data["_id"]
	for i in range(144):
		await process_frame
		if i == 42:
			_click(first.get_global_rect().get_center())
			assert(battle._draw_anim and battle._page == 1)
		await RenderingServer.frame_post_draw
		if i % 2 == 0:
			var capture := root.get_texture().get_image()
			capture.resize(450, 800, Image.INTERPOLATE_BILINEAR)
			assert(capture.save_png(frames + "/frame_%04d.png" % (i / 2)) == OK)
	assert(battle._cards.size() == 6 and battle._slots[0].idx == chosen and not battle._draw_anim)
	await _capture("res://deck_second_page.png")
	_click(battle._slots[0].get_global_rect().get_center())
	assert(battle._detail_layer.visible)
	battle.queue_free()
	await process_frame
	print("PASS: actual mouse page controls, sixth card lands on page two, occupied slot detail opens")
	Audio.quit_cleanly()
