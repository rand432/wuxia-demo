extends RefCounted
const JOURNAL := "user://reward_pending.cfg"
static var _read_failures: Dictionary = {}
static var _batch := false
static var _pending: Dictionary = {}

static func _write_direct(cfg: ConfigFile, path: String) -> Error:
	var temporary := path + ".tmp"
	var err := cfg.save(temporary)
	if err != OK:
		return err
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))

static func write(cfg: ConfigFile, path: String) -> Error:
	if _read_failures.has(path):
		return int(_read_failures[path]) as Error
	if _batch:
		_pending[path] = cfg.encode_to_text()
		return OK
	var err := recover()
	if err != OK:
		return err
	return _write_direct(cfg, path)

static func begin() -> Error:
	if not _read_failures.is_empty():
		return ERR_FILE_CORRUPT
	if _batch:
		return ERR_BUSY
	var err := recover()
	if err != OK:
		return err
	_pending = {}
	_batch = true
	return OK

static func commit() -> Error:
	if not _batch:
		return ERR_UNCONFIGURED
	_batch = false
	return recover()

static func _flush_pending() -> Error:
	if _pending.is_empty():
		return OK
	var journal := ConfigFile.new()
	journal.set_value("transaction", "files", _pending)
	var err := _write_direct(journal, JOURNAL)
	if err != OK:
		return err
	_pending = {}
	return OK

# 重放保存后的完整快照，重复执行不会重复增加奖励。
static func recover() -> Error:
	if not _batch and not _pending.is_empty():
		var pending_error := _flush_pending()
		if pending_error != OK:
			return pending_error
	if not FileAccess.file_exists(JOURNAL):
		return OK
	var journal := ConfigFile.new()
	var err := journal.load(JOURNAL)
	if err != OK:
		return err
	var files = journal.get_value("transaction", "files", null)
	if not files is Dictionary or files.is_empty():
		return ERR_FILE_CORRUPT
	# 只接受当前奖励流程使用的固定目标，先校验全部内容再写入。
	var decoded: Dictionary = {}
	for path in files:
		if path not in ["user://level_state.cfg", "user://progress.cfg", "user://forge.cfg"]:
			return ERR_INVALID_DATA
		var cfg := ConfigFile.new()
		if not files[path] is String or cfg.parse(files[path]) != OK:
			return ERR_FILE_CORRUPT
		decoded[path] = cfg
	for path in decoded:
		err = _write_direct(decoded[path], path)
		if err != OK:
			return err
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(JOURNAL))

# 读档失败时禁止用默认值覆盖原文件；首次无存档不属于异常。
static func read(cfg: ConfigFile, path: String, schema: Dictionary = {}) -> Error:
	var err := cfg.load(path)
	if err == OK:
		for section in schema:
			for key in schema[section]:
				if cfg.has_section_key(section, key) and not _matches_schema(cfg.get_value(section, key), schema[section][key]):
					err = ERR_INVALID_DATA
	if err == OK or err == ERR_FILE_NOT_FOUND:
		_read_failures.erase(path)
	else:
		_read_failures[path] = err
	return err

# TYPE_FLOAT 在存档规格中表示有限数值，兼容整数与小数旧值。
static func _matches_schema(value: Variant, spec: Variant) -> bool:
	if spec is int:
		if spec == TYPE_FLOAT:
			return (value is int or value is float) and is_finite(float(value))
		return typeof(value) == spec
	if not spec is Dictionary or typeof(value) != int(spec.get("type", -1)):
		return false
	if value is Dictionary:
		if spec.has("values"):
			for entry in value.values():
				if not _matches_schema(entry, spec["values"]): return false
		for key in spec.get("fields", {}):
			if value.has(key) and not _matches_schema(value[key], spec["fields"][key]): return false
	elif value is Array and spec.has("items"):
		for entry in value:
			if not _matches_schema(entry, spec["items"]): return false
	return true
