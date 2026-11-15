extends SceneTree
const PATH := "user://audit_forge_oil.cfg"
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	var data := GDScript.new()
	data.source_code = FileAccess.get_file_as_string("res://shared/forge_data.gd").replace("user://forge.cfg", PATH)
	assert(data.reload() == OK)
	data._loaded = true
	data._bag_ready = true
	data.equipped = {"weapon": {"quality": 1, "plus": 5}}
	data.state = {}
	data.items = {"淬火油": 2}
	data.ores = 10
	data.silver = 100
	var before: Dictionary = data.weights(data.st_of("weapon"), "")
	assert(data.use_forge_item("weapon", "淬火油")["ok"])
	assert(data.items["淬火油"] == 1)
	assert(not data.use_forge_item("weapon", "淬火油")["ok"])
	assert(data.items["淬火油"] == 1)
	var after: Dictionary = data.weights(data.st_of("weapon"), "")
	assert(after["成"] == before["成"] * 1.5 and after["大"] == before["大"] * 1.5)
	assert(after["破"] == before["破"] and after["损"] == before["损"] and after["维"] == before["维"])
	var odds: Dictionary = data.odds(data.st_of("weapon"), "")
	var total := 0.0
	for value in odds.values(): total += float(value)
	assert(is_equal_approx(total, 100.0))
	data._loaded = false
	data.load_game()
	assert(data.st_of("weapon")["oil"] == 1)
	assert(data.hammer("weapon")["ok"])
	assert(not data.st_of("weapon").has("oil"))
	var cfg := ConfigFile.new()
	assert(cfg.load(PATH) == OK)
	assert(not cfg.get_value("res", "state")["weapon"].has("oil"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("PASS: oil weights, normalized odds, no stacking, persisted single-hammer effect")
	quit()
