extends SceneTree
# 隔离运行并录制真实界面输入；720x1280、30fps帧序列交给ffmpeg编码。
const Home := preload("res://menu/main_home.tscn")
const Audio := preload("res://shared/audio.gd")
class Pointer extends Control:
	var held := false
	func _draw() -> void:
		if held:
			draw_arc(Vector2(8, 12), 23.0, 0.0, TAU, 36, Color(1.0, 0.78, 0.34, 0.85), 2.0, true)
		var shape := PackedVector2Array([Vector2.ZERO, Vector2(0, 28), Vector2(7, 22), Vector2(13, 36), Vector2(20, 33), Vector2(14, 20), Vector2(26, 20)])
		draw_colored_polygon(shape, Color(1.0, 0.97, 0.88))
		var outline := shape.duplicate()
		outline.append(shape[0])
		draw_polyline(outline, Color(0.12, 0.10, 0.07), 2.0, true)

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	call_deferred("_run")

func _position_at(frame: int) -> Vector2:
	var keys := [[0, Vector2(500, 200)], [50, Vector2(650, 45)], [80, Vector2(650, 45)],
		[105, Vector2(474, 518)], [130, Vector2(474, 518)], [155, Vector2(540, 588)],
		[180, Vector2(540, 588)], [205, Vector2(360, 708)], [235, Vector2(360, 708)],
		[265, Vector2(650, 45)], [360, Vector2(650, 45)]]
	for i in range(keys.size() - 1):
		if frame <= keys[i + 1][0]:
			var t := float(frame - keys[i][0]) / float(keys[i + 1][0] - keys[i][0])
			return (keys[i][1] as Vector2).lerp(keys[i + 1][1], smoothstep(0.0, 1.0, t))
	return keys.back()[1]

func _run() -> void:
	Audio.set_bgm_volume(0.7)
	Audio.set_sfx_volume(0.5)
	var page = Home.instantiate()
	root.add_child(page)
	current_scene = page
	var pointer := Pointer.new()
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.z_index = 200
	root.add_child(pointer)
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://motion_frames")) == OK)
	for frame in range(360):
		await process_frame
		pointer.position = _position_at(frame)
		var move := InputEventMouseMotion.new()
		move.position = pointer.position
		move.global_position = pointer.position
		root.push_input(move, true)
		if frame in [60, 68, 110, 118, 160, 168, 210, 218, 270, 278]:
			pointer.held = frame in [60, 110, 160, 210, 270]
			var click := InputEventMouseButton.new()
			click.position = pointer.position
			click.global_position = pointer.position
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pointer.held
			click.button_mask = MOUSE_BUTTON_MASK_LEFT if pointer.held else 0
			root.push_input(click, true)
		pointer.queue_redraw()
		if frame == 90: assert(page.get_node_or_null("SettingsOv") != null)
		if frame == 135: assert(is_equal_approx(Audio.bgm_volume(), 0.6))
		if frame == 185: assert(is_equal_approx(Audio.sfx_volume(), 0.6))
		if frame == 240: assert(page.get_node_or_null("SettingsOv") == null)
		if frame == 300: assert(page.get_node_or_null("SettingsOv") != null)
		await RenderingServer.frame_post_draw
		if frame % 2 == 0:
			assert(root.get_texture().get_image().save_png("res://motion_frames/frame_%04d.png" % (frame / 2)) == OK)
	# 按钮绘制缩小时，原点击区域边缘也必须继续可用。
	var minus: Button
	for child in page.get_node("SettingsOv").find_children("*", "Button", true, false):
		if child.text == "－":
			minus = child
			break
	var bounds := minus.get_global_rect()
	var point := bounds.position + Vector2(0.2, bounds.size.y * 0.5)
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	var press := InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	root.push_input(press, true)
	await create_timer(0.12).timeout
	assert(minus.get_global_rect() == bounds)
	press = press.duplicate()
	press.pressed = false
	press.button_mask = 0
	root.push_input(press, true)
	await process_frame
	assert(is_equal_approx(Audio.bgm_volume(), 0.5))
	page.queue_free()
	pointer.queue_free()
	current_scene = null
	await process_frame
	print("PASS: rendered real settings open/volume/close/reopen inputs; held edge click keeps hit area and triggers; 180 frames recorded")
	Audio.quit_cleanly()
