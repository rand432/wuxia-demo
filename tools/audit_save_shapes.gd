extends SceneTree
const SF := preload("res://shared/save_file.gd")
const FD := preload("res://shared/forge_data.gd")
const PATH := "user://audit_save_shapes.cfg"
func _initialize() -> void:
	var cfg := ConfigFile.new()
	for entry in [
		["bag", [123]],
		["equipped", {"armor": "not an item"}],
		["state", {"weapon": {"crack": {}}}],
		["items", {"龙鳞": "three"}],
		["equipped", {"weapon": {"quality": []}}],
		["state", {"weapon": {"undo": {"item": {"plus": []}, "state": {}}}}]
	]:
		cfg.clear()
		cfg.set_value("res", entry[0], entry[1])
		assert(cfg.save(PATH) == OK)
		var original := FileAccess.get_file_as_string(PATH)
		var loaded := ConfigFile.new()
		assert(SF.read(loaded, PATH, FD.SAVE_SCHEMA) == ERR_INVALID_DATA)
		assert(SF.write(ConfigFile.new(), PATH) != OK)
		assert(FileAccess.get_file_as_string(PATH) == original)
	cfg.clear()
	cfg.set_value("res", "equipped", {"weapon": {"quality": 1.0, "plus": 5}, "armor": {}})
	cfg.set_value("res", "bag", [{"name": "old item"}, {}])
	assert(cfg.save(PATH) == OK)
	assert(SF.read(ConfigFile.new(), PATH, FD.SAVE_SCHEMA) == OK)
	assert(not SF._matches_schema(NAN, TYPE_FLOAT))
	assert(not SF._matches_schema(INF, TYPE_FLOAT))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("PASS: malformed nested save fields blocked; legacy optional fields and finite numeric types supported")
	quit()
