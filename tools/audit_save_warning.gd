extends SceneTree
const GS := preload("res://shared/game_state.gd")
const LS := preload("res://shared/level_state.gd")
const SF := preload("res://shared/save_file.gd")
const FD := preload("res://shared/forge_data.gd")
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
	assert(not FileAccess.file_exists(SF.JOURNAL))
	var journal := ConfigFile.new()
	journal.set_value("transaction", "files", {})
	assert(journal.save(SF.JOURNAL) == OK)
	var journal_bytes := FileAccess.get_file_as_bytes(SF.JOURNAL)
	home._start_level()
	assert(home.is_inside_tree() and home._start_btn.disabled and home._save_warning.visible)
	assert(home._save_warning.text.contains("首通奖励待恢复"))
	assert(FileAccess.get_file_as_bytes(SF.JOURNAL) == journal_bytes)
	home.queue_free()
	await process_frame
	home = Home.instantiate()
	root.add_child(home)
	assert(home._start_btn.disabled and home._save_warning.visible)
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(SF.JOURNAL)) == OK)
	assert(home._check_save_before_start() and not home._save_warning.visible)
	home.queue_free()
	await process_frame
	var had_forge := FileAccess.file_exists(FD.SAVE_PATH)
	var forge_backup := FileAccess.get_file_as_bytes(FD.SAVE_PATH) if had_forge else PackedByteArray()
	var forge := ConfigFile.new()
	forge.set_value("res", "ores", [])
	assert(forge.save(FD.SAVE_PATH) == OK)
	var malformed_forge := FileAccess.get_file_as_bytes(FD.SAVE_PATH)
	FD._loaded = false
	home = Home.instantiate()
	root.add_child(home)
	assert(home._start_btn.disabled and home._save_warning.text.contains("存档读取异常"))
	home._start_level()
	assert(home.is_inside_tree() and FileAccess.get_file_as_bytes(FD.SAVE_PATH) == malformed_forge)
	if had_forge:
		var file := FileAccess.open(FD.SAVE_PATH, FileAccess.WRITE)
		assert(file != null)
		file.store_buffer(forge_backup)
		file.close()
	else:
		assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(FD.SAVE_PATH)) == OK)
	home.queue_free()
	await process_frame
	print("PASS: valid save starts normally; corrupted journal or forge blocks battle and preserves original bytes")
	quit()
