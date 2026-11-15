extends SceneTree
const PATH := "user://audit_forge_undo.cfg"
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	var data := GDScript.new()
	data.source_code = FileAccess.get_file_as_string("res://shared/forge_data.gd").replace("user://forge.cfg", PATH)
	assert(data.reload() == OK)
	data._loaded = true
	data._bag_ready = true
	for expected in ["大", "损", "维"]:
		data.equipped = {"weapon": {"name": "test", "quality": 1, "plus": 5}}
		data.state = {}
		data.ores = 10
		data.silver = 100
		data.items = {"悔恨法条": 2}
		var before_state: Dictionary = data.st_of("weapon").duplicate(true)
		var before_item: Dictionary = data.equipped["weapon"].duplicate(true)
		var found := false
		for value in range(10000):
			seed(value)
			if data.roll(data.equipped["weapon"], "weapon") == expected:
				seed(value)
				found = true
				break
		assert(found)
		assert(data.hammer("weapon")["result"] == expected)
		# 读档后仍可撤销，且恢复精确快照。
		data._loaded = false
		data.load_game()
		assert(data.use_forge_item("weapon", "悔恨法条")["ok"])
		assert(data.equipped["weapon"] == before_item and data.state["weapon"] == before_state)
		assert(data.ores == 9 and data.silver == 90)
		assert(data.items["悔恨法条"] == 1)
		assert(not data.use_forge_item("weapon", "悔恨法条")["ok"])
		assert(data.items["悔恨法条"] == 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("PASS: undo big success, damage, unchanged after reload; no material refund or double undo")
	quit()
