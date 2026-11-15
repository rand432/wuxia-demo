extends RefCounted
const JOURNAL := "user://reward_pending.cfg"
static var _batch := false
static var _pending: Dictionary = {}

static func _write_direct(cfg: ConfigFile, path: String) -> Error:
	var temporary := path + ".tmp"
	var err := cfg.save(temporary)
	if err != OK:
		return err
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))

static func write(cfg: ConfigFile, path: String) -> Error:
	if _batch:
		_pending[path] = cfg.encode_to_text()
		return OK
	var err := recover()
	if err != OK:
		return err
	return _write_direct(cfg, path)

static func begin() -> Error:
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
