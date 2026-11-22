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
	var enemy_showcase := OS.get_cmdline_user_args().has("--enemy-showcase")
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
	c.attr_set_base("atk", 12.0 if enemy_showcase else 80.0)
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
	if enemy_showcase:
		c._last_quota_wave = c.wave
	var caption := Label.new()
	caption.text = "近身挥击 · 弓弦 · 法火" if enemy_showcase else "战斗动效预览 · 入场 / 命中 / 消散"
	caption.position = Vector2(24, 162)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(0.42, 0.33, 0.22))
	b.add_child(caption)
	var folder := "res://enemy_attack_frames" if enemy_showcase else "res://combat_motion_frames"
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK)
	var seen: Dictionary = {}
	var prepared: Dictionary = {}
	if enemy_showcase:
		c.foe_windup.connect(func(foe: Dictionary, _target: Vector2, _seconds: float): prepared[foe["name"]] = true)
	var frame_count := 360 if enemy_showcase else 600
	for frame in range(frame_count):
		await process_frame
		if enemy_showcase and frame == 20:
			for i in range(3):
				c._spawn_foe()
				var foe: Dictionary = c.foes.back()
				var offset: Vector2 = [Vector2(5, -54), Vector2(-145, -44), Vector2(145, -55)][i]
				var spawn: Vector2 = c.hero_pos + offset
				foe.merge({"x": spawn.x, "y": spawn.y, "hp": 900.0, "hp_max": 900.0,
					"atk": 9.0, "ranged": i == 1, "mage": i == 2, "brute": false, "shield": false,
					"stop": 59.0 if i == 0 else 162.0, "name": ["疯牛", "狱狼", "毒蝎"][i]}, true)
		elif not enemy_showcase and frame in [20, 140, 260, 380, 500]:
			for i in range(5):
				c._spawn_foe()
				var f: Dictionary = c.foes.back()
				var angle := -PI * 0.82 + float(i) * PI * 0.16
				f.merge({"x": c.hero_pos.x + cos(angle) * 110.0, "y": c.hero_pos.y + sin(angle) * 110.0,
					"hp": 140.0, "hp_max": 140.0, "atk": 3.0, "ranged": false, "mage": false, "brute": false, "shield": false, "stop": 58.0,
					"name": ["狱狼", "疯牛", "毒蝎", "牢鼠", "山匪"][i]}, true)
		await RenderingServer.frame_post_draw
		if enemy_showcase:
			for strike in b._fx_front.enemy_attacks:
				seen[strike["kind"]] = true
		if frame % 2 == 0:
			var capture := root.get_texture().get_image()
			capture.resize(450, 800, Image.INTERPOLATE_BILINEAR)
			assert(capture.save_png(folder + "/frame_%04d.png" % (frame / 2)) == OK)
	if enemy_showcase:
		assert(seen.has("melee") and seen.has("bow") and seen.has("mage") and prepared.size() == 3)
		assert(float(c.hero["hp"]) < 2000.0)
	else:
		assert(c.kills_total > 5)
	assert(b._foe_tokens.size() <= c.foes.size())
	print("PASS: rendered controlled combat; kills=", c.kills_total, "; enemy effects=", seen.keys(), "; windups=", prepared.size(), "; frames=", frame_count / 2)
	b.queue_free()
	current_scene = null
	await process_frame
	Audio.quit_cleanly()
