extends SceneTree
# 表现用受控构筑：真实核心自动出手，不代替正常关卡平衡验证。
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression") or DisplayServer.get_name() == "headless":
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	seed(20261122)
	LS.ensure_loaded()
	LS.current_level = 6
	var b = Battle.instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	await process_frame
	b._tut.cancel()
	b._curio_id = ""
	var c = b._core
	c.foes.clear()
	c.attr_set_base("atk", 80.0)
	c.attr_set_base("crit", 0.35)
	c.attr_set_base("aspd", 2.0)
	c.attr_set_base("hp", 2000.0)
	c.hero["hp"] = 2000.0
	c.hero_pos = Vector2(352, 470)
	c.skill["splash"] = 1
	c.intro_wait = 0.0
	c._spawn_left = 0
	c._spawn_t = 999.0
	c._wave_spawned = 0
	c._wave_quota = 999
	var caption := Label.new()
	caption.text = "战斗动效预览 · 入场 / 命中 / 消散"
	caption.position = Vector2(24, 162)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(0.42, 0.33, 0.22))
	b.add_child(caption)
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://combat_motion_frames")) == OK)
	for frame in range(600):
		await process_frame
		if frame in [20, 140, 260, 380, 500]:
			for i in range(5):
				c._spawn_foe()
				var f: Dictionary = c.foes.back()
				var angle := -PI * 0.82 + float(i) * PI * 0.16
				f.merge({"x": c.hero_pos.x + cos(angle) * 110.0, "y": c.hero_pos.y + sin(angle) * 110.0,
					"hp": 140.0, "hp_max": 140.0, "atk": 3.0, "ranged": false, "mage": false, "brute": false, "shield": false, "stop": 58.0,
					"name": ["狱狼", "疯牛", "毒蝎", "牢鼠", "山匪"][i]}, true)
		await RenderingServer.frame_post_draw
		if frame % 2 == 0:
			var capture := root.get_texture().get_image()
			capture.resize(450, 800, Image.INTERPOLATE_BILINEAR)
			assert(capture.save_png("res://combat_motion_frames/frame_%04d.png" % (frame / 2)) == OK)
	assert(c.kills_total > 5)
	assert(b._foe_tokens.size() <= c.foes.size())
	print("PASS: rendered controlled combat, real automatic hits and kills=", c.kills_total, "; 300 frames recorded")
	b.queue_free()
	current_scene = null
	await process_frame
	Audio.quit_cleanly()
