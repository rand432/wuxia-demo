extends SceneTree
const PATH := "user://audit_equipment.cfg"
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	var data := GDScript.new()
	data.source_code = FileAccess.get_file_as_string("res://shared/forge_data.gd").replace("user://forge.cfg", PATH)
	assert(data.reload() == OK)
	data._loaded = true
	data._bag_ready = true
	data.equipped = {}
	for slot in data.SLOT_KEYS:
		data.equipped[slot] = {"name": slot, "quality": 1, "plus": 0}
	var totals: Dictionary = data.totals()
	assert(totals == {"atk": 12.0, "def": 6.0, "hp": 60.0, "spd": 4.0})
	# 不带slot字段的护甲必须只修改护甲的裂纹/保护状态。
	data.state = {}
	data.st_of("weapon")["protect"] = 1
	var weapon_state: Dictionary = data.st_of("weapon").duplicate(true)
	var armor: Dictionary = data.equipped["armor"]
	data.apply(armor, "损", "armor")
	assert(data.st_of("armor")["crack"] == 1)
	assert(data.st_of("weapon") == weapon_state)
	var result: Dictionary = data.apply(armor, "破", "armor")
	assert(result["broke"] and not result["blocked"])
	assert(data.st_of("weapon")["protect"] == 1)
	data.silver = 100
	data.state = {"armor": {"crack": 3}}
	assert(data.sell_equipped("armor"))
	assert(data.silver == 140 and data.equipped["armor"].is_empty() and not data.state.has("armor"))
	assert(not data.sell_equipped("armor") and data.silver == 140)
	var cfg := ConfigFile.new()
	assert(cfg.load(PATH) == OK)
	assert(cfg.get_value("res", "silver") == 140)
	assert(cfg.get_value("res", "equipped")["armor"].is_empty())
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	assert(not data.sell_equipped("jade"))
	assert(not data.equipped["jade"].is_empty() and data.silver == 140)
	data.ores = 10
	var before_equipped: Dictionary = data.equipped.duplicate(true)
	var before_state: Dictionary = data.state.duplicate(true)
	var failed: Dictionary = data.hammer("weapon")
	assert(not failed["ok"])
	assert(data.ores == 10 and data.silver == 140)
	assert(data.equipped == before_equipped and data.state == before_state)
	var before_items: Dictionary = data.items.duplicate(true)
	assert(not data.use_forge_item("weapon", "龙鳞")["ok"])
	assert(data.items == before_items and data.equipped == before_equipped and data.state == before_state)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	var success: Dictionary = data.hammer("weapon")
	assert(success["ok"])
	assert(data.ores == 9 and data.silver == 130)
	assert(cfg.load(PATH) == OK)
	assert(cfg.get_value("res", "ores") == 9 and cfg.get_value("res", "silver") == 130)
	var protection := int(data.st_of("weapon").get("protect", 0))
	assert(data.use_forge_item("weapon", "龙鳞")["ok"])
	assert(data.items["龙鳞"] == int(before_items["龙鳞"]) - 1)
	assert(data.st_of("weapon")["protect"] == protection + 1)
	assert(not data.use_forge_item("armor", "星砂")["ok"])
	data.st_of("weapon")["gauge"] = 8
	assert(data.use_forge_item("weapon", "星砂")["trance"])
	assert(data.st_of("weapon")["trance"] == data.TRANCE_HAMMERS)
	assert(cfg.load(PATH) == OK)
	assert(cfg.get_value("res", "items")["龙鳞"] == data.items["龙鳞"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("PASS: equipment, hammer and forge items persistence and rollback")
	quit()
