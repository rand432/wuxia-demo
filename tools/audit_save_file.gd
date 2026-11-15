extends SceneTree
const SaveFile := preload("res://shared/save_file.gd")
const PATH := "user://audit_save_file.cfg"
func _initialize() -> void:
	# 独立测试文件，不读取或修改玩家进度。
	var cfg := ConfigFile.new()
	cfg.set_value("test", "n", 1)
	assert(SaveFile.write(cfg, PATH) == OK)
	cfg.set_value("test", "n", 2)
	assert(SaveFile.write(cfg, PATH) == OK)
	var loaded := ConfigFile.new()
	assert(loaded.load(PATH) == OK)
	assert(loaded.get_value("test", "n") == 2)
	# 让临时路径成为目录，模拟写入失败，确认正式文件未变。
	assert(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp")) == OK)
	cfg.set_value("test", "n", 3)
	assert(SaveFile.write(cfg, PATH) != OK)
	assert(loaded.load(PATH) == OK)
	assert(loaded.get_value("test", "n") == 2)
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp")) == OK)
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH)) == OK)
	print("PASS: save replacement and failure preserve previous file")
	quit()
