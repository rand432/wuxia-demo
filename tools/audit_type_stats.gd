extends SceneTree
const Core := preload("res://kushou/kushou_battle.gd")
const AttrPanel := preload("res://kushou/attr_panel.gd")
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	var core := Core.new()
	root.add_child(core)
	core.set_process(false)
	core.setup({"atk": 100.0, "hp_max": 1000.0, "mp_max": 100.0})
	core.attr_set_base("crit", 0.0)
	var panel := AttrPanel.new()
	root.add_child(panel)
	panel.setup(core)
	for type in core.DMG_TYPES:
		core.type_attr[type]["pen_f"] = 1.2
		core.type_attr[type]["pen_p"] = 1.1
		core.type_attr[type]["red_f"] = 1.3
		core.type_attr[type]["red_p"] = 1.4
		var expected := 0.0 if type == "真实" else 0.6
		for field in ["pen_f", "pen_p", "red_f", "red_p"]:
			assert(is_equal_approx(core.type_effective_field(type, field), expected))
		assert(core.type_field(type, "pen_f") == 1.2) # 保留原始成长，不破坏后续增减。
		assert(is_equal_approx(core.hero_in_dmg(100.0, type), 100.0 if type == "真实" else 16.0))
		assert(is_equal_approx(core.take_after_red(100.0, type), 100.0 if type == "真实" else 16.0))
		assert(is_equal_approx(core.red_after_pen(0.8, type), 0.0 if type == "真实" else 0.08))
		# 合成后的增幅封顶，不是先截断固定段再额外突破。
		core.type_attr[type]["amp_f"] = 1.5
		core.type_attr[type]["amp_p"] = 0.5
		assert(core.type_amp(type) == 2.0)
		assert(core.hero_out_dmg(100.0, type, 0)["dmg"] == 300.0)
		core.type_attr[type]["amp_f"] = 0.4
		core.type_attr[type]["amp_p"] = 0.5
		assert(is_equal_approx(core.type_amp(type), 0.6))
		assert(is_equal_approx(core.hero_out_dmg(100.0, type, 0)["dmg"], 160.0))
		panel.tab = panel.TYPES.find(type)
		assert(is_equal_approx(panel._type_f("pen"), expected))
		assert(is_equal_approx(panel._type_f("pen_p"), expected))
		assert(is_equal_approx(panel._type_f("red"), expected))
		assert(is_equal_approx(panel._type_f("red_p"), expected))
	# 稿中18/50%穿30%应剩6%；不擅自修改敌方旧护甲换算。
	core.type_attr["火系"]["pen_f"] = 0.18
	core.type_attr["火系"]["pen_p"] = 0.5
	assert(is_equal_approx(core.foe_take(100.0, {"res_fire": 0.3}, "火系"), 94.0))
	var target := {"hp": 1000.0, "res_fire": 0.3}
	assert(is_equal_approx(core._apply_dmg(target, 100.0, "火系", 0), 150.4))
	assert(is_equal_approx(target["hp"], 849.6))
	core.type_attr["物理"]["red_f"] = 0.4
	core.type_attr["物理"]["red_p"] = 0.25
	assert(is_equal_approx(core.hero_in_dmg(100.0, "物理"), 45.0))
	core.hero["curio_cut"] = 0.3
	assert(is_equal_approx(core.hero_in_dmg(100.0, "物理"), 30.0))
	panel.tab = 0
	assert(panel._type_f("red") == 0.6 and panel._type_f("red_p") == 0.25)
	core.hero["curio_cut"] = 0.0
	assert(panel._type_f("red") == 0.4)
	assert(core.hero_in_dmg(100.0, "真实") == 100.0)
	if OS.get_cmdline_user_args().has("--visual"):
		for type in core.DMG_TYPES:
			core.type_attr[type]["amp_f"] = 1.5
			core.type_attr[type]["amp_p"] = 0.5
		root.size = Vector2i(720, 1280)
		root.content_scale_size = Vector2i(720, 1280)
		panel.open()
		for capture in [{"tab": 0, "kind": "type", "popup": 1, "name": "reduction"}, {"tab": 0, "kind": "type", "popup": 2, "name": "amplification"}, {"tab": 6, "kind": "real", "popup": -1, "name": "true"}]:
			panel.tab = capture["tab"]
			panel.popup_kind = capture["kind"]
			panel.popup = capture["popup"]
			panel.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../audit_type_" + capture["name"] + ".png")) == OK)
	panel.queue_free()
	core.queue_free()
	await process_frame
	# 六系全部到达上限才移出进阶池；任一系仍有收益就保留。
	LS.ensure_loaded()
	LS.current_level = 6
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	b._core.set_process(false)
	for type in b._core.DMG_TYPES:
		if type == "真实": continue
		b._core.type_attr[type]["pen_f"] = 0.6
		b._core.type_attr[type]["amp_f"] = 2.0
	assert(not b._aug_has_effect("pen_flat") and not b._aug_has_effect("dmgall_add"))
	b._core.type_attr["木系"]["pen_f"] = 0.59
	b._core.type_attr["木系"]["amp_f"] = 1.99
	assert(b._aug_has_effect("pen_flat") and b._aug_has_effect("dmgall_add"))
	b._core.type_attr["木系"]["amp_p"] = 0.1
	assert(not b._aug_has_effect("dmgall_add"))
	b._apply_aug("dmgall_add", 50.0)
	b._apply_aug("cutall_add", 120.0)
	assert(b._core.hero["dmg_all"] == 2.0 and b._core.hero["cut"] == 0.6 and b._core.hero["cut_all"] == 0.0)
	b.queue_free()
	await process_frame
	print("PASS: seven-type penetration/reduction/amp caps; two-stage incoming damage; true bypass; panel and capped aug eligibility")
	Audio.quit_cleanly()
