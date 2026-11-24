extends SceneTree
const DIR := "user://audit_reward_save/"

func _snapshot(schema: Dictionary) -> ConfigFile:
	var cfg := ConfigFile.new()
	for section in schema:
		for key in schema[section]:
			var spec = schema[section][key]
			var kind: int = spec["type"] if spec is Dictionary else spec
			match kind:
				TYPE_DICTIONARY: cfg.set_value(section, key, {})
				TYPE_ARRAY: cfg.set_value(section, key, [])
				TYPE_BOOL: cfg.set_value(section, key, false)
				TYPE_STRING: cfg.set_value(section, key, "审查")
				TYPE_FLOAT: cfg.set_value(section, key, 0)
	return cfg

func _initialize() -> void:
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(DIR))
	var source := FileAccess.get_file_as_string("res://shared/save_file.gd").replace("user://", DIR)
	var script := GDScript.new()
	script.source_code = source
	assert(script.reload() == OK)
	var progress := _snapshot(script.REWARD_SCHEMAS[DIR + "progress.cfg"])
	var levels := _snapshot(script.REWARD_SCHEMAS[DIR + "level_state.cfg"])
	progress.set_value("progress", "coins", {"wen": 300})
	levels.set_value("levels", "first_clear", {"6": true})
	assert(script.begin() == OK)
	assert(script.write(progress, DIR + "progress.cfg") == OK)
	assert(script.write(levels, DIR + "level_state.cfg") == OK)
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
	var progress_path := DIR + "progress.cfg"
	var levels_path := DIR + "level_state.cfg"
	var before_progress := FileAccess.get_file_as_string(progress_path)
	var before_levels := FileAccess.get_file_as_string(levels_path)
	assert(before_progress == progress.encode_to_text() and before_levels == levels.encode_to_text())

	# 可解析的空白、半份存档和内部类型错误都会阻止整个日志重放。
	progress.set_value("progress", "coins", {"wen": 900})
	levels.set_value("levels", "preview", {"lv": "损坏"})
	var journal := ConfigFile.new()
	for invalid in ["", "[levels]\ncurrent=7", levels.encode_to_text()]:
		journal.set_value("transaction", "files", {progress_path: progress.encode_to_text(), levels_path: invalid})
		assert(journal.save(script.JOURNAL) == OK)
		var before_journal := FileAccess.get_file_as_string(script.JOURNAL)
		assert(script.recover() == ERR_FILE_CORRUPT)
		assert(FileAccess.get_file_as_string(progress_path) == before_progress)
		assert(FileAccess.get_file_as_string(levels_path) == before_levels)
		assert(FileAccess.get_file_as_string(script.JOURNAL) == before_journal)
	levels.set_value("levels", "preview", {"lv": 7, "forge": 20})
	journal.set_value("transaction", "files", {progress_path: progress.encode_to_text(), levels_path: levels.encode_to_text()})
	assert(journal.save(script.JOURNAL) == OK)
	assert(script.recover() == OK and script.recover() == OK)
	assert(FileAccess.get_file_as_string(progress_path) == progress.encode_to_text())
	assert(FileAccess.get_file_as_string(levels_path) == levels.encode_to_text())

	# 旧格式至少要有关卡和一份奖励快照。
	journal.set_value("transaction", "files", {levels_path: levels.encode_to_text()})
	assert(journal.save(script.JOURNAL) == OK)
	assert(script.recover() == ERR_FILE_CORRUPT)
	assert(FileAccess.get_file_as_string(levels_path) == levels.encode_to_text())
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(script.JOURNAL)) == OK)

	# 让正常事务写出带校验值的日志，再模拟丢失一整份快照。
	var forge_path := DIR + "forge.cfg"
	var forge := _snapshot(script.REWARD_SCHEMAS[forge_path])
	forge.set_value("res", "ores", 100)
	assert(script.begin() == OK)
	progress.set_value("progress", "coins", {"wen": 1900})
	levels.set_value("levels", "first_clear", {"6": true, "7": true})
	assert(script.write(progress, progress_path) == OK)
	assert(script.write(levels, levels_path) == OK)
	assert(script.write(forge, forge_path) == OK)
	var target_blocker := ProjectSettings.globalize_path(progress_path + ".tmp")
	assert(DirAccess.make_dir_absolute(target_blocker) == OK)
	assert(script.commit() != OK)
	assert(DirAccess.remove_absolute(target_blocker) == OK)
	var original_journal := FileAccess.get_file_as_string(script.JOURNAL)
	journal.clear()
	assert(journal.parse(original_journal) == OK)
	var snapshot: Dictionary = journal.get_value("transaction", "snapshot")
	assert(snapshot.size() == 3 and journal.has_section_key("transaction", "sha256"))
	var before_retry := {
		progress_path: FileAccess.get_file_as_string(progress_path),
		levels_path: FileAccess.get_file_as_string(levels_path),
		forge_path: FileAccess.get_file_as_string(forge_path),
	}
	for missing in [true, false]:
		var damaged := snapshot.duplicate()
		if missing:
			damaged.erase(forge_path)
		else:
			damaged[progress_path] = before_retry[progress_path] # 数据本身合法，但属于旧的事务。
		journal.set_value("transaction", "snapshot", damaged)
		assert(journal.save(script.JOURNAL) == OK)
		assert(script.recover() == ERR_FILE_CORRUPT)
		for path in before_retry:
			assert(FileAccess.get_file_as_string(path) == before_retry[path])
	journal.set_value("transaction", "snapshot", snapshot)
	journal.erase_section_key("transaction", "sha256")
	assert(journal.save(script.JOURNAL) == OK and script.recover() == ERR_FILE_CORRUPT)
	journal.clear()
	assert(journal.parse(original_journal) == OK and journal.save(script.JOURNAL) == OK)
	assert(script.recover() == OK and script.recover() == OK)
	for path in [progress_path, levels_path, forge_path]:
		assert(FileAccess.get_file_as_string(path) == snapshot[path])
		assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	print("PASS: legacy and checksummed journal recovery; missing and changed snapshots preserve existing saves")
	quit()
