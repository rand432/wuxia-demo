extends SceneTree
const PATH := "user://audit_curio_save.cfg"
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	var data := GDScript.new()
	data.source_code = FileAccess.get_file_as_string("res://shared/game_state.gd").replace("user://curio.cfg", PATH)
	assert(data.reload() == OK)
	data._curio_loaded = true
	data.curio_id = "yuhu"
	data.curio_lv = {}
	assert(data._curio_save() == OK)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	assert(not data.curio_equip("hanyu") and data.curio_id == "yuhu")
	assert(not data.curio_unequip() and data.curio_id == "yuhu")
	assert(not data.curio_upgrade("yuhu") and data.curio_lv.is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	assert(data.curio_equip("hanyu"))
	assert(data.curio_unequip())
	assert(data.curio_equip("yuhu"))
	assert(data.curio_upgrade("yuhu"))
	data.curio_lv = {}
	data.curio_id = ""
	data._curio_loaded = false
	assert(data.curio_level("yuhu") == 2 and data.curio_id == "yuhu")
	data.curio_lv["yuhu"] = 5
	assert(not data.curio_upgrade("yuhu") and data.curio_lv["yuhu"] == 5)
	assert(not data.curio_upgrade("unknown") and not data.curio_equip("unknown"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("PASS: curio equip/unequip/upgrade rollback, persistence, max level and invalid IDs")
	quit()
