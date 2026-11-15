extends SceneTree
const PATH := "user://audit_starter_equipment.cfg"
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	var data := GDScript.new()
	data.source_code = FileAccess.get_file_as_string("res://shared/forge_data.gd").replace("user://forge.cfg", PATH)
	assert(data.reload() == OK)
	data._loaded = true
	data._bag_ready = true
	var old := {"name": "old weapon", "quality": 3, "plus": 25, "trait": "稳手"}
	data.equipped = {"weapon": old.duplicate(true), "armor": {}, "jade": {}, "cloak": {}}
	data.state = {"weapon": {"crack": 2}, "armor": {"crack": 5}}
	data.bag = []
	assert(data.grant_starter_equipment() == 1)
	assert(data.equipped["weapon"] == old and data.state["weapon"]["crack"] == 2)
	assert(not data.state.has("armor"))
	assert(data.bag.size() == 1 and data.bag[0]["slot"] == "weapon")
	for slot in ["armor", "jade", "cloak"]:
		assert(data.equipped[slot]["slot"] == slot and data.equipped[slot]["plus"] == 0)
	assert(data.save_game() == OK)
	data._loaded = false
	data.equipped = {}
	data.bag = []
	data.state = {}
	data.load_game()
	assert(data.equipped["weapon"] == old and data.bag.size() == 1)
	data.equipped = {}
	data.bag = []
	data.state = {}
	assert(data.grant_starter_equipment() == 0 and data.bag.is_empty())
	assert(data.grant_starter_equipment() == 4 and data.bag.size() == 4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("PASS: starter set preserves upgraded gear/state; fills empty slots; occupied rewards go to bag; reload safe")
	quit()
