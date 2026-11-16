extends SceneTree
const Core := preload("res://kushou/kushou_battle.gd")
const AttrPanel := preload("res://kushou/attr_panel.gd")
const Sheet := preload("res://shared/char_sheet.gd")
const FD := preload("res://shared/forge_data.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _capture(panel, popup_index: int, name: String) -> void:
	panel.popup_kind = "base"
	panel.popup = popup_index
	panel.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../" + name + ".png")) == OK)

func _run() -> void:
	root.size = Vector2i(720, 1280)
	root.content_scale_size = Vector2i(720, 1280)
	var core := Core.new()
	root.add_child(core)
	core.size = Vector2(720, 760)
	core.set_process(false)
	core.setup({"atk": 12.0, "hp_max": 200.0, "mp_max": 100.0})
	var panel := AttrPanel.new()
	root.add_child(panel)
	panel.setup(core)
	assert(panel._base_text(2) == "1.67 次/秒")
	# 所有实际攻速通道应同时进入面板和下一次出手冷却。
	core.hero["aspd"] = 1.5
	core.skill["aspd"] = 2
	core._p_aspd = 5.0
	core.hero["curio_aspd"] = 0.20
	core.hero["mech_comboaspd"] = 0.05
	core._combo = 20
	core._combo_t = 10.0
	var expected := 0.6 / (1.5 * 1.16 * 2.0 * 1.20 * 1.10)
	assert(is_equal_approx(core.hero_attack_interval(), expected))
	assert(is_equal_approx(panel._attack_rate(), 1.0 / expected))
	core._spawn_foe()
	var foe: Dictionary = core.foes.back()
	foe["x"] = core.hero_pos.x
	foe["y"] = core.hero_pos.y - 40.0
	core._hero_cd = 0.0
	core.intro_wait = 0.0
	core.running = true
	core._process(0.001)
	assert(is_equal_approx(core._hero_cd, expected), "cooldown=%s expected=%s interval=%s" % [core._hero_cd, expected, core.hero_attack_interval()])
	core.running = false
	# 已有增幅不能混进临时值：应显示 (100+20)×1.5=180。
	core.attr_set_base("atk", 100.0)
	core.attr_add("atk", 20.0)
	core.attr_add_amp("atk", 0.5)
	core.hero["atk"] = core.attr_final("atk")
	var details := panel._base_details(0)
	assert(details["base"] == "100" and details["temp"] == "+20" and details["amp"] == "+50%" and details["total"] == "180")
	core.attr_set_base("crit", 0.20)
	core.hero["crit"] = 0.20
	core.hero["curio_crit"] = 0.10
	assert(panel._base_text(4) == "30%")
	core.hero["curio_crit"] = 1.0
	assert(panel._base_text(4) == "75%" and panel._base_details(4)["amp"] == "—")
	# 局外装备快照复用同一基础节奏与真实拆解。
	FD._loaded = true
	FD.equipped = {}
	for slot in FD.SLOT_KEYS: FD.equipped[slot] = {"quality": 1, "plus": 0}
	var sheet := Sheet.new()
	panel.setup(sheet)
	panel.open()
	assert(is_equal_approx(panel._attack_rate(), 1.04 / 0.60))
	assert(panel._base_details(0)["temp"] == "+12" and panel._base_details(1)["temp"] == "+60")
	assert(panel._base_details(2)["amp"] == "+4%")
	if OS.get_cmdline_user_args().has("--visual"):
		panel.setup(core)
		panel.open()
		await _capture(panel, 0, "audit_attr_attack")
		await _capture(panel, 2, "audit_attr_speed")
		panel.setup(sheet)
		panel.open()
		await _capture(panel, -1, "audit_attr_sheet")
	panel.queue_free()
	core.queue_free()
	await process_frame
	print("PASS: displayed attack rate matches scheduled combat cooldown; real base/temp/amp split; crit buffs/cap; equipment snapshot")
	Audio.quit_cleanly()
