extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")
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
	b._end_run(false)
	var replay := _button(b._result_layer, "再来一局")
	var home := _button(b._result_layer, "回主界面")
	# 损坏的待恢复日志必须阻止离开，并允许修复后重新点击。
	var journal := ConfigFile.new()
	journal.set_value("transaction", "files", {})
	assert(journal.save(SaveFile.JOURNAL) == OK)
	replay.pressed.emit()
	home.pressed.emit()
	b._quit() # 旧退出确认不能绕过结果页的保存恢复检查。
	assert(current_scene == b and b.is_inside_tree())
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveFile.JOURNAL)) == OK)
	replay.pressed.emit()
	home.pressed.emit()
	replay.pressed.emit()
	b = await _settle("res://kushou/battle_ui.tscn")
	_freeze_process(b)
	assert(LS.current_level == 6 and not b._run_over and b._core.running)
	b._end_run(false)
	home = _button(b._result_layer, "回主界面")
	replay = _button(b._result_layer, "再来一局")
	home.pressed.emit()
	replay.pressed.emit()
	home.pressed.emit()
	var page = await _settle("res://menu/main_home.tscn")
	page.queue_free()
	current_scene = null
	await process_frame
	print("PASS: real abandon/result buttons single-flight; abandoned late rewards/first clear frozen; pending save blocks all exits then retry/replay/home succeeds")
	Audio.quit_cleanly()
