extends RefCounted
const JOURNAL := "user://reward_pending.cfg"
const COUNTERS := {"type": TYPE_DICTIONARY, "values": TYPE_FLOAT}
const ITEM_SCHEMA := {"type": TYPE_DICTIONARY, "fields": {"name": TYPE_STRING, "slot": TYPE_STRING, "quality": TYPE_FLOAT, "plus": TYPE_FLOAT, "trait": TYPE_STRING}}
const FORGE_STATE_FIELDS := {"crack": TYPE_FLOAT, "gauge": TYPE_FLOAT, "trance": TYPE_FLOAT, "protect": TYPE_FLOAT, "oil": TYPE_FLOAT, "last": TYPE_STRING}
const FORGE_STATE_SCHEMA := {"type": TYPE_DICTIONARY, "fields": {
	"crack": TYPE_FLOAT, "gauge": TYPE_FLOAT, "trance": TYPE_FLOAT, "protect": TYPE_FLOAT,
	"oil": TYPE_FLOAT, "last": TYPE_STRING, "undo": {"type": TYPE_DICTIONARY, "fields": {
		"item": ITEM_SCHEMA, "state": {"type": TYPE_DICTIONARY, "fields": FORGE_STATE_FIELDS}}}}}
const FORGE_SCHEMA := {"res": {
	"ores": TYPE_FLOAT, "silver": TYPE_FLOAT, "items": COUNTERS,
	"equipped": {"type": TYPE_DICTIONARY, "values": ITEM_SCHEMA},
	"bag": {"type": TYPE_ARRAY, "items": ITEM_SCHEMA},
	"state": {"type": TYPE_DICTIONARY, "values": FORGE_STATE_SCHEMA}}}
const REWARD_SCHEMAS := {
	"user://level_state.cfg": {"levels": {
		"version": TYPE_FLOAT, "current": TYPE_FLOAT, "max": TYPE_FLOAT,
		"first_clear": {"type": TYPE_DICTIONARY, "values": TYPE_BOOL},
		"tutorial_done": {"type": TYPE_DICTIONARY, "values": TYPE_BOOL},
		"preview": COUNTERS}},
	"user://progress.cfg": {"progress": {
		"player_name": TYPE_STRING, "coins": COUNTERS, "skill_mat": TYPE_FLOAT,
		"forge_mat": TYPE_FLOAT, "equip_tokens": TYPE_FLOAT, "advance_tokens": TYPE_FLOAT,
		"new_cards_unlocked": TYPE_BOOL, "new_curio_unlocked": TYPE_BOOL,
		"skill_lv": COUNTERS, "skill_books": COUNTERS, "shards": COUNTERS,
		"curio_shards": TYPE_FLOAT, "stars": COUNTERS}},
	"user://forge.cfg": FORGE_SCHEMA,
}
static var _read_failures: Dictionary = {}
static var _batch := false
static var _pending: Dictionary = {}

static func _write_direct(cfg: ConfigFile, path: String) -> Error:
	var temporary := path + ".tmp"
	var err := cfg.save(temporary)
	if err != OK:
		return err
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))

static func write(cfg: ConfigFile, path: String, require_immediate := false) -> Error:
	if _read_failures.has(path):
		return int(_read_failures[path]) as Error
	if _batch:
		if require_immediate:
			return ERR_BUSY
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
	journal.set_value("transaction", "snapshot", _pending)
	journal.set_value("transaction", "sha256", _snapshot_digest(_pending))
	var err := _write_direct(journal, JOURNAL)
	if err != OK:
		return err
	_pending = {}
	return OK

static func _snapshot_digest(files: Dictionary) -> String:
	return JSON.stringify(files, "", true).sha256_text()

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
	var checksummed := journal.has_section_key("transaction", "snapshot") or journal.has_section_key("transaction", "sha256")
	var key := "snapshot" if checksummed else "files"
	if not journal.has_section_key("transaction", key):
		return ERR_FILE_CORRUPT
	var files = journal.get_value("transaction", key)
	# 首通和锻造预习都至少同时写关卡记录与一份奖励存档。
	if not files is Dictionary or files.size() < 2 or not files.has("user://level_state.cfg"):
		return ERR_FILE_CORRUPT
	if checksummed:
		if not journal.has_section_key("transaction", "sha256"):
			return ERR_FILE_CORRUPT
		var expected = journal.get_value("transaction", "sha256")
		if not expected is String or expected != _snapshot_digest(files):
			return ERR_FILE_CORRUPT
	# 只接受当前奖励流程使用的固定目标，先校验全部内容再写入。
	var decoded: Dictionary = {}
	for path in files:
		if not REWARD_SCHEMAS.has(path):
			return ERR_INVALID_DATA
		var cfg := ConfigFile.new()
		if not files[path] is String or cfg.parse(files[path]) != OK \
				or not _valid_sections(cfg, REWARD_SCHEMAS[path], true):
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
	if err == OK and not _valid_sections(cfg, schema, false):
		err = ERR_INVALID_DATA
	if err == OK or err == ERR_FILE_NOT_FOUND:
		_read_failures.erase(path)
	else:
		_read_failures[path] = err
	return err

static func _valid_sections(cfg: ConfigFile, schema: Dictionary, required: bool) -> bool:
	for section in schema:
		for key in schema[section]:
			if not cfg.has_section_key(section, key):
				if required:
					return false
			elif not _matches_schema(cfg.get_value(section, key), schema[section][key]):
				return false
	return true

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
