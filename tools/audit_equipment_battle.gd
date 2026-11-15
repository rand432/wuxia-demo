extends SceneTree
const Core := preload("res://kushou/kushou_battle.gd")
const Stats := preload("res://shared/equipment_stats.gd")
const Sheet := preload("res://shared/char_sheet.gd")
const FD := preload("res://shared/forge_data.gd")
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FD._loaded = true
	FD.equipped = {}
	for slot in FD.SLOT_KEYS:
		FD.equipped[slot] = {"quality": 1, "plus": 0}
	var core := Core.new()
	core.hero["hp"] = 100.0
	core.hero["hp_max"] = 200.0
	Stats.apply(core, FD.totals())
	var sheet := Sheet.new()
	assert(is_equal_approx(core.attr_final("atk"), 24.0))
	assert(is_equal_approx(core.attr_final("hp"), 260.0))
	assert(is_equal_approx(core.hero["hp"], 130.0))
	assert(is_equal_approx(core.hero["aspd"], 1.04))
	assert(is_equal_approx(sheet.hero["atk"], core.hero["atk"]))
	assert(is_equal_approx(sheet.hero["hp_max"], core.hero["hp_max"]))
	assert(is_equal_approx(sheet.hero["aspd"], core.hero["aspd"]))
	for type in core.DMG_TYPES:
		var red := 0.0 if type == "真实" else 0.18
		assert(is_equal_approx(core.type_field(type, "red_f"), red))
		assert(is_equal_approx(sheet.type_field(type, "red_f"), red))
	assert(is_equal_approx(core.take_after_red(100.0, "物理"), 82.0))
	assert(is_equal_approx(core.take_after_red(100.0, "真实"), 100.0))
	core.free()
	var levels = load("res://shared/level_state.gd")
	levels._loaded = true
	levels.preview = {}
	var game = load("res://shared/game_state.gd")
	game._progress_loaded = true
	for level in [7, 8]:
		levels.current_level = level
		var battle = load("res://kushou/battle_ui.tscn").instantiate()
		root.add_child(battle)
		assert(is_equal_approx(battle._core.attr_final("atk"), 24.0 if level == 8 else 12.0))
		battle.queue_free()
		await process_frame
	print("PASS: equipment attack/hp/armor/speed; character sheet matches; true damage unchanged")
	quit()
