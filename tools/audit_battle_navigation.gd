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

func _new_battle():
	assert(change_scene_to_packed(Battle) == OK)
	var s = await _settle("res://kushou/battle_ui.tscn")
	_freeze_process(s)
	return s

# 按控件的实际全局矩形发鼠标按下/抬起，走 GUI 命中（不是 pressed.emit）
func _click_control(btn: Control) -> void:
	var point := btn.get_global_transform() * (btn.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)

func _run() -> void:
	LS.ensure_loaded()
	GS.ensure_loaded()
	# 用例假设「7 关还没通过」；整轮跑下来隔离存档可能已被前面的用例通关，先复位。
	LS.first_clear.erase("7")
	LS.save()
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
	var cleared7_before := LS.first_clear.has("7")
	var upgraded := {"name": "铁剑", "slot": "weapon", "quality": 2, "plus": 3}
	Forge.equipped["weapon"] = upgraded
	assert(Forge.save_game() == OK)
	assert(LS.first_clear.has("7") == cleared7_before)
	assert(journal.save(SaveFile.JOURNAL) == OK)
	b._end_run(true)
	assert(LS.first_clear.has("7") == cleared7_before and GS.coins["wen"] == wen and Forge.ores == previous_ores)
	await process_frame
	await process_frame
	assert(not b._tut.visible and not b._tutorial_paused)
	home = _button(b._result_layer, "回主界面")
	replay = _button(b._result_layer, "再来一局")
	home.pressed.emit()
	replay.pressed.emit()
	assert(current_scene == b and LS.first_clear.has("7") == cleared7_before)
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
	if DisplayServer.get_name() != "headless":
		await _audit_real_input()
	else:
		print("[HEADLESS] real-input branch skipped (run without --headless on a graphics device)")
	print("PASS: result retry saves deferred first clear and rewards once; abandon and both result buttons keep navigation single-flight")
	await _audit_window_close_with_pending_reward()

func _audit_window_close_with_pending_reward() -> void:
	const level := 8
	LS.first_clear.erase(str(level))
	LS.max_unlocked = level
	LS.current_level = level
	LS.save()
	var b = await _new_battle()
	var coins_before := int(GS.coins["wen"])
	var reward := LS.first_reward(level)
	var journal_tmp := ProjectSettings.globalize_path(SaveFile.JOURNAL + ".tmp")
	assert(DirAccess.make_dir_absolute(journal_tmp) == OK)
	b._end_run(true)
	assert(b._result_save_pending and b._result_layer._save_notice.visible)
	assert(LS.first_clear[str(level)] and not FileAccess.file_exists(SaveFile.JOURNAL))
	assert(int(GS.coins["wen"]) == coins_before + int(reward["wen"]))
	var disk := ConfigFile.new()
	assert(disk.load(LS.SAVE_PATH) == OK and not disk.get_value("levels", "first_clear").has(str(level)))
	root.close_requested.emit()
	await create_timer(0.18).timeout
	assert(current_scene == b and not paused and not Audio._shutting_down)
	assert(b._result_layer._save_notice.visible)
	assert(DirAccess.remove_absolute(journal_tmp) == OK)
	root.close_requested.emit()
	assert(Audio._shutting_down and not b._result_save_pending)
	assert(disk.load(LS.SAVE_PATH) == OK and disk.get_value("levels", "first_clear")[str(level)])
	assert(int(disk.get_value("levels", "max")) == level + 1)
	assert(disk.load(GS.PROGRESS_SAVE) == OK)
	assert(int(disk.get_value("progress", "coins")["wen"]) == coins_before + int(reward["wen"]))
	assert(not FileAccess.file_exists(SaveFile.JOURNAL))
	print("PASS: close request protects a pending first clear and saves unlock and reward exactly once")


# ---- 图形分支：真实鼠标点击与延迟揭幕释放（仅在非 headless 下执行） ----
func _audit_real_input() -> void:
	# 1) 胜：真实点击「再来一局」
	var b = await _new_battle()
	b._end_run(true)
	await create_timer(0.45).timeout
	var replay := _button(b._result_layer, "再来一局")
	_click_control(replay)
	await create_timer(0.4).timeout
	assert(current_scene != b and current_scene.scene_file_path.ends_with("battle_ui.tscn"))
	var b2 = current_scene
	_freeze_process(b2)
	# 2) 败：真实点击「回主界面」
	b2._end_run(false)
	await create_timer(0.45).timeout
	var home := _button(b2._result_layer, "回主界面")
	Audio.sfx("melee")
	Audio.sfx("ui_click", -13.0)
	assert(Audio._sfx_active.any(func(p): return p.sfx_key == "ui_click" and p.playing))
	_click_control(home)
	assert(Audio._sfx_active.any(func(p): return p.sfx_key == "ui_click" and p.playing))
	assert(not Audio._sfx_active.any(func(p): return p.sfx_key == "melee"))
	await create_timer(0.4).timeout
	assert(current_scene != b2 and current_scene.scene_file_path == "res://menu/main_home.tscn")
	# 3) 快速连点：只发起一次场景切换
	var b3 = await _new_battle()
	b3._end_run(true)
	await create_timer(0.45).timeout
	var replay3 := _button(b3._result_layer, "再来一局")
	_click_control(replay3)
	_click_control(replay3)
	await create_timer(0.45).timeout
	assert(current_scene != b3 and current_scene.scene_file_path.ends_with("battle_ui.tscn"))
	# 4) 保存失败：真实点击留在当前页；恢复后再次点击只切一次
	var b4 = await _new_battle()
	var journal := ConfigFile.new()
	journal.set_value("transaction", "files", {})
	assert(journal.save(SaveFile.JOURNAL) == OK)
	b4._end_run(true)
	await create_timer(0.45).timeout
	var home4 := _button(b4._result_layer, "回主界面")
	_click_control(home4)
	await create_timer(0.25).timeout
	assert(current_scene == b4 and b4.is_inside_tree())
	assert(b4._result_layer._save_notice.visible)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://battle_result_save_pending.png") == OK)
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveFile.JOURNAL)) == OK)
	_click_control(home4)
	await create_timer(0.4).timeout
	assert(current_scene != b4 and current_scene.scene_file_path == "res://menu/main_home.tscn")
	# 5) 延迟揭幕建立后立即释放：不得有残留、迟到特效或脚本错误
	var b5 = await _new_battle()
	b5._build_result(true, 0.5)
	await process_frame
	b5.queue_free()
	await create_timer(0.8).timeout
	assert(not is_instance_valid(b5))
	var b6 = await _new_battle()
	await process_frame
	assert(b6.is_inside_tree() and b6._core != null)
	print("[GRAPHICS] real click replay/home/save-fail/double-click/delayed-release and transition sound PASS")

