extends SceneTree
const Role := preload("res://menu/character_home.tscn")
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const FD := preload("res://shared/forge_data.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	call_deferred("_run")

func _mouse(point: Vector2, down: bool) -> void:
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	root.push_input(event, true)

func _run() -> void:
	seed(20261122)
	LS.ensure_loaded()
	LS.current_level = 7
	LS.max_unlocked = 10
	FD.load_game()
	FD.equipped["weapon"] = {"name": "青锋剑", "quality": 2, "plus": 5}
	assert(FD.save_game() == OK)
	var role = Role.instantiate()
	root.add_child(role)
	current_scene = role
	var b = null
	var peak := 0.0
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://spring_art_frames")) == OK)
	for frame in range(780):
		await process_frame
		if frame == 60: _mouse(Vector2(98, 246), true)
		if frame == 68: _mouse(Vector2(98, 246), false)
		if frame == 120: _mouse(Vector2(564, 877), true)
		if frame == 128: _mouse(Vector2(564, 877), false)
		if frame == 180:
			role.queue_free()
			b = Battle.instantiate()
			root.add_child(b)
			current_scene = b
			b.set_process(false)
			b._core.set_process(false)
			b._crystal = 1000
			b._update_crystal()
		if frame == 182: b._tut.cancel()
		if frame == 210: b._show_draw(true)
		if frame >= 210 and frame < 245: peak = maxf(peak, b._draw_cards[0].scale.x)
		if frame == 250:
			assert(peak > 1.035 and b._draw_cards[0].scale.is_equal_approx(Vector2.ONE))
		if frame == 340: b._show_draw(false)
		if frame == 375: b._show_draw(true)
		if frame == 430:
			b._show_draw(false)
			b._str_pending = true
			b._str_lv = 5
			b._open_aug_pick()
		if frame == 540:
			b._hide_aug_pick()
			b._trea_pending = true
			b._roll_trea()
			b._open_trea()
		if frame == 650:
			b._hide_trea()
			b._draw_charge = 2
			b._show_god_pick()
		await RenderingServer.frame_post_draw
		if frame % 2 == 0:
			assert(root.get_texture().get_image().save_png("res://spring_art_frames/frame_%04d.png" % (frame / 2)) == OK)
	assert(b._god_root.get_child_count() == 2)
	assert(b._hero_token.art_tex.resource_path == "res://assets/char/player_q.png")
	print("PASS: new role art with original Q battle token; equipment popup input; draw/reopen/upgrade/treasure/god spring entries; peak card scale=", peak, "; 390 frames")
	b.queue_free()
	current_scene = null
	await process_frame
	Audio.quit_cleanly()
