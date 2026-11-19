extends SceneTree
const GS := preload("res://shared/game_state.gd")
const LS := preload("res://shared/level_state.gd")
const UI := preload("res://shared/ui_kit.gd")
const Audio := preload("res://shared/audio.gd")
const PAGES := [preload("res://menu/main_home.tscn"), preload("res://menu/character_home.tscn"), preload("res://menu/partner_home.tscn"), preload("res://menu/curio_home.tscn")]

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _button(parent, prefix: String) -> Button:
	for b in parent.find_children("*", "Button", true, false):
		if b.text.begins_with(prefix): return b
	assert(false, "missing button " + prefix)
	return null

func _click_settings() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(650, 45) # 原无效热区覆盖的设置按钮右侧。
	root.push_input(motion, true)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = motion.position
		e.button_index = MOUSE_BUTTON_LEFT
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		e.pressed = down
		root.push_input(e, true)
	await process_frame

func _frames() -> void:
	await process_frame
	await process_frame

func _run() -> void:
	GS.ensure_loaded()
	LS.ensure_loaded()
	LS.current_level = 6
	for i in PAGES.size():
		GS.coins = {"wen": 12345, "yuanbao": 67, "silver": 89}
		var page = PAGES[i].instantiate()
		root.add_child(page)
		var bar = null
		for child in page.get_children():
			if child is UI.BarChrome: bar = child
		assert(bar != null and bar._coin_label.text == "12345" and bar._crystal_label.text == "67")
		GS.add_coin("wen", -200)
		GS.add_coin("yuanbao", 2)
		await _frames()
		assert(bar._coin_label.text == "12145" and bar._crystal_label.text == "69")
		if i == 2:
			GS.skill_books = {"凡品": 5, "良品": 5, "玄品": 5, "地品": 5, "天品": 5}
			GS.skill_lv = {}
			page._show_skill_detail(0)
			_button(page._pop, "升级").pressed.emit()
			await _frames()
			assert(GS.coin("wen") == 11945 and bar._coin_label.text == "11945")
			page._close_pop()
			await _frames()
			if DisplayServer.get_name() == "headless":
				_button(page, "设置").pressed.emit()
			else:
				await _click_settings()
			assert(page.get_node_or_null("SettingsOv") != null)
			page.get_node("SettingsOv").queue_free()
			await _frames()
		if DisplayServer.get_name() != "headless":
			await create_timer(0.6).timeout
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://menu_wallet_%d.png" % i) == OK)
		GS.coins["wen"] = 0
		GS.coins["yuanbao"] = 0
		await _frames()
		assert(bar._coin_label.text == "0" and bar._crystal_label.text == "0")
		page.queue_free()
		await _frames()
	print("PASS: four pages show wallet before first frame, update on changes and zero; real skill spend updates header; partner settings opens (right-side input in rendered run)")
	Audio.quit_cleanly()
