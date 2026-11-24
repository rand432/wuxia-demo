extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")
const Forge := preload("res://shared/forge_data.gd")
const SaveFile := preload("res://shared/save_file.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _button(parent, caption: String) -> Button:
	for child in parent.find_children("*", "Button", true, false):
		if child.text == caption: return child
	assert(false, "missing button " + caption)
	return null

func _settle(path: String):
	await scene_changed
	assert(current_scene != null and current_scene.scene_file_path == path)
	return current_scene

func _freeze_process(b) -> void:
	b.set_process(false)
	b._core.set_process(false)

func _run() -> void:
	LS.ensure_loaded()
	GS.ensure_loaded()
	LS.max_unlocked = 10
	LS.current_level = 6
	assert(change_scene_to_packed(Battle) == OK)
	var b = await _settle("res://kushou/battle_ui.tscn")
	_freeze_process(b)
	b._show_exit(true)
	var leave := _button(b._exit_layer, "退出")
	var before := [b._wen, b._crystal, b._kills, b._exp, LS.first_clear.duplicate(true), GS.coins.duplicate(true)]
	leave.pressed.emit()
	assert(not b.is_inside_tree() and b._run_over and not b._core.running, "abandoned battle must freeze immediately")
	leave.pressed.emit()
	b._leave_result(true)
	b._core.coin.emit(100)
	b._core.coin_drop.emit(100, Vector2.ZERO)
	b._core.chal_drop.emit(4, Vector2.ZERO)
	b._core.kill.emit(1)
	b._end_run(true)
	assert([b._wen, b._crystal, b._kills, b._exp, LS.first_clear, GS.coins] == before)
	await _settle("res://menu/main_home.tscn")
	assert(change_scene_to_packed(Battle) == OK)
	b = await _settle("res://kushou/battle_ui.tscn")
	_freeze_process(b)
	b._leave_result(false) # 未出结算时，旧入口不能跳走。
	assert(b.is_inside_tree() and current_scene == b)
	var tutorial_actions := [0]
	b._tutorial("audit_exit", b._market_tile, "审查教学取消", func(): tutorial_actions[0] += 1)
	assert(b._tut.visible and b._tutorial_paused)
	b._end_run(false)
	assert(not b._tut.visible and not b._tutorial_paused)
	b._tut._hit.pressed.emit()
	assert(tutorial_actions[0] == 0)
	await process_frame
	await process_frame
	b._maybe_level_button_tutorial()
	assert(not b._tut.visible and not b._tutorial_paused, "late tutorial must not cover result buttons")
	var replay := _button(b._result_layer, "再来一局")
	var home := _button(b._result_layer, "回主界面")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://battle_result_navigation.png") == OK)
	# 损坏的待恢复日志必须阻止离开，并允许修复后重新点击。
	var journal := ConfigFile.new()
	journal.set_value("transaction", "files", {})
	assert(journal.save(SaveFile.JOURNAL) == OK)
	replay.pressed.emit()
	home.pressed.emit()
	b._quit() # 旧退出确认不能绕过结果页的保存恢复检查。
	assert(current_scene == b and b.is_inside_tree())
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveFile.JOURNAL)) == OK)
	LS.current_level = 7
	replay.pressed.emit()
	home.pressed.emit()
	replay.pressed.emit()
	b = await _settle("res://kushou/battle_ui.tscn")
	_freeze_process(b)
	assert(LS.current_level == 7 and not b._run_over and b._core.running)
	# 首次写入还未开始就被旧日志挡住，修好后仍要保存这一局的胜利。
	var reward := LS.first_reward(7)
	var wen: int = GS.coins["wen"]
	Forge.load_game()
	var previous_ores := Forge.ores
	var previous_silver := Forge.silver
	var previous_tokens := GS.equip_tokens
	var previous_materials := GS.forge_mat
	var previous_bag_size := Forge.bag.size()
	var upgraded := {"name": "铁剑", "slot": "weapon", "quality": 2, "plus": 3}
	Forge.equipped["weapon"] = upgraded
	assert(Forge.save_game() == OK)
	assert(not LS.first_clear.has("7"))
	assert(journal.save(SaveFile.JOURNAL) == OK)
	b._end_run(true)
	assert(not LS.first_clear.has("7") and GS.coins["wen"] == wen and Forge.ores == previous_ores)
	await process_frame
	await process_frame
	assert(not b._tut.visible and not b._tutorial_paused)
	home = _button(b._result_layer, "回主界面")
	replay = _button(b._result_layer, "再来一局")
	home.pressed.emit()
	replay.pressed.emit()
	assert(current_scene == b and not LS.first_clear.has("7"))
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveFile.JOURNAL)) == OK)
	home.pressed.emit()
	replay.pressed.emit()
	home.pressed.emit()
	assert(LS.first_clear["7"] and GS.coins["wen"] == wen + int(reward["wen"]))
	assert(GS.equip_tokens == previous_tokens + int(reward["equip"]))
	assert(GS.forge_mat == previous_materials + int(reward["forge_mat"]))
	assert(Forge.ores == previous_ores + int(reward["forge_mat"]))
	assert(Forge.silver == previous_silver + int(reward["forge_mat"]) * 10)
	assert(Forge.equipped["weapon"] == upgraded and Forge.bag.size() == previous_bag_size + 1)
	var levels := ConfigFile.new()
	var progress := ConfigFile.new()
	var forge := ConfigFile.new()
	assert(levels.load(LS.SAVE_PATH) == OK and levels.get_value("levels", "first_clear")["7"])
	assert(progress.load(GS.PROGRESS_SAVE) == OK)
	assert(progress.get_value("progress", "coins")["wen"] == GS.coins["wen"])
	assert(progress.get_value("progress", "forge_mat") == GS.forge_mat)
	assert(forge.load(Forge.SAVE_PATH) == OK and forge.get_value("res", "ores") == Forge.ores)
	assert(forge.get_value("res", "bag").size() == Forge.bag.size())
	var page = await _settle("res://menu/main_home.tscn")
	page.queue_free()
	current_scene = null
	await process_frame
	print("PASS: result retry saves deferred first clear and rewards once; abandon and both result buttons keep navigation single-flight")
	Audio.quit_cleanly()
