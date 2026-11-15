extends SceneTree
const GS := preload("res://shared/game_state.gd")
const LS := preload("res://shared/level_state.gd")
const SF := preload("res://shared/save_file.gd")
const Home := preload("res://menu/main_home.tscn")
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")
func _run() -> void:
	GS.ensure_loaded()
	LS.ensure_loaded()
	var home = Home.instantiate()
	root.add_child(home)
	assert(not home._start_btn.disabled)
	home.queue_free()
	await process_frame
	SF._read_failures["audit-placeholder"] = ERR_INVALID_DATA
	home = Home.instantiate()
	root.add_child(home)
	assert(home._start_btn.disabled)
	var found := false
	for child in home.get_children():
		if child is Label and child.text.contains("存档读取异常"):
			found = true
	assert(found)
	SF._read_failures.erase("audit-placeholder")
	home.queue_free()
	await process_frame
	print("PASS: valid save starts normally; read failure disables start and shows warning")
	quit()
