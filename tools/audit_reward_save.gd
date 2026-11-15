extends SceneTree
const DIR := "user://audit_reward_save/"
func _initialize() -> void:
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(DIR))
	var source := FileAccess.get_file_as_string("res://shared/save_file.gd").replace("user://", DIR)
	var script := GDScript.new()
	script.source_code = source
	assert(script.reload() == OK)
	var cfg := ConfigFile.new()
	cfg.set_value("reward", "wen", 300)
	assert(script.begin() == OK)
	assert(script.write(cfg, DIR + "progress.cfg") == OK)
	assert(script.write(cfg, DIR + "level_state.cfg") == OK)
	# 阻挡日志临时文件，模拟日志无法落盘。
	assert(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(DIR + "reward_pending.cfg.tmp")) == OK)
	assert(script.commit() != OK)
	assert(not script._pending.is_empty())
	assert(not FileAccess.file_exists(DIR + "progress.cfg"))
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "reward_pending.cfg.tmp")) == OK)
	assert(script.recover() == OK)
	assert(script._pending.is_empty())
	# 再次恢复不重复增加奖励。
	assert(script.recover() == OK)
	var loaded := ConfigFile.new()
	for name in ["progress.cfg", "level_state.cfg"]:
		assert(loaded.load(DIR + name) == OK)
		assert(loaded.get_value("reward", "wen") == 300)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	print("PASS: failed journal retains snapshot, retry saves once")
	quit()
