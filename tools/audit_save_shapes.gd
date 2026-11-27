extends SceneTree
const SF := preload("res://shared/save_file.gd")
const FD := preload("res://shared/forge_data.gd")
const GS := preload("res://shared/game_state.gd")
const PATH := "user://audit_save_shapes.cfg"

func _reject(section: String, field: String, value: Variant, schema: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(section, field, value)
	assert(cfg.save(PATH) == OK)
	var original := FileAccess.get_file_as_bytes(PATH)
	assert(SF.read(ConfigFile.new(), PATH, schema) == ERR_INVALID_DATA)
	assert(SF.write(ConfigFile.new(), PATH) == ERR_INVALID_DATA)
	assert(FileAccess.get_file_as_bytes(PATH) == original)

func _initialize() -> void:
	for entry in [
		["bag", [123]],
		["equipped", {"armor": "not an item"}],
		["state", {"weapon": {"crack": {}}}],
		["items", {"龙鳞": "three"}],
		["equipped", {"weapon": {"quality": []}}],
		["state", {"weapon": {"undo": {"item": {"plus": []}, "state": {}}}}]
	]:
		_reject("res", entry[0], entry[1], FD.SAVE_SCHEMA)
	_reject("levels", "max", "three", SF.LEVEL_SCHEMA)
	_reject("levels", "first_clear", {"6": []}, SF.LEVEL_SCHEMA)
	_reject("levels", "preview", {"crystal": {}}, SF.LEVEL_SCHEMA)
	_reject("progress", "coins", {"wen": "broken"}, SF.PROGRESS_SCHEMA)
	_reject("progress", "curio_shards", [], SF.PROGRESS_SCHEMA)
	_reject("progress", "new_cards_unlocked", {"value": false}, SF.PROGRESS_SCHEMA)
	_reject("curio", "id", {"selected": "yuhu"}, GS.CURIO_SCHEMA)
	_reject("curio", "lv", {"yuhu": []}, GS.CURIO_SCHEMA)
	var cfg := ConfigFile.new()
	cfg.set_value("res", "equipped", {"weapon": {"quality": 1.0, "plus": 5}, "armor": {}})
	cfg.set_value("res", "bag", [{"name": "old item"}, {}])
	cfg.set_value("levels", "max", 6.0)
	cfg.set_value("levels", "first_clear", {"5": true})
	cfg.set_value("progress", "coins", {"wen": 60, "silver": 5.0})
	cfg.set_value("curio", "lv", {"yuhu": 2})
	assert(cfg.save(PATH) == OK)
	for schema in [FD.SAVE_SCHEMA, SF.LEVEL_SCHEMA, SF.PROGRESS_SCHEMA, GS.CURIO_SCHEMA]:
		assert(SF.read(ConfigFile.new(), PATH, schema) == OK)
	assert(not SF._matches_schema(NAN, TYPE_FLOAT))
	assert(not SF._matches_schema(INF, TYPE_FLOAT))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("PASS: malformed level, progress, curio and forge fields preserved; legacy optional fields and finite numeric types supported")
	quit()
