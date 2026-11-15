extends SceneTree
const SaveFile := preload("res://shared/save_file.gd")
const PATH := "user://audit_corrupted_save.cfg"
func _initialize() -> void:
	var original := "[progress]\ncoins = !!! invalid !!!\n".replace("\n", "
")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	var cfg := ConfigFile.new()
	# 仅抑制这一次故意构造的解析错误输出，返回值仍断言。
	var old_print := Engine.print_error_messages
	Engine.print_error_messages = false
	var error := SaveFile.read(cfg, PATH)
	Engine.print_error_messages = old_print
	assert(error != OK and error != ERR_FILE_NOT_FOUND)
	var defaults := ConfigFile.new()
	defaults.set_value("progress", "coins", 0)
	assert(SaveFile.write(defaults, PATH) != OK)
	assert(SaveFile.begin() != OK)
	assert(FileAccess.get_file_as_string(PATH) == original)
	# 外部修复/恢复文件后，必须成功读回，才可再次保存。
	assert(defaults.save(PATH) == OK)
	assert(SaveFile.read(cfg, PATH) == OK)
	assert(SaveFile.write(defaults, PATH) == OK)
	assert(SaveFile.begin() == OK)
	assert(SaveFile.commit() == OK)
	# 配置可解析但容器字段类型错误，也不能覆盖。
	defaults.set_value("progress", "coins", "wrong type")
	assert(defaults.save(PATH) == OK)
	var schema := {"progress": {"coins": TYPE_DICTIONARY}}
	assert(SaveFile.read(cfg, PATH, schema) == ERR_INVALID_DATA)
	assert(SaveFile.write(ConfigFile.new(), PATH) != OK)
	defaults.set_value("progress", "coins", {})
	assert(defaults.save(PATH) == OK)
	assert(SaveFile.read(cfg, PATH, schema) == OK)
	assert(SaveFile.write(defaults, PATH) == OK)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	assert(SaveFile.read(cfg, PATH) == ERR_FILE_NOT_FOUND)
	assert(SaveFile.write(defaults, PATH) == OK)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("PASS: corrupt save preserved; write and transaction blocked; repaired read and new save work")
	quit()
