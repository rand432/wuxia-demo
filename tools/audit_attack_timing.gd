extends SceneTree
const Core := preload("res://kushou/kushou_battle.gd")
const Audio := preload("res://shared/audio.gd")
const AttackFx := preload("res://kushou/attack_fx.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _audit_trails() -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = Color(0.08, 0.07, 0.06)
	viewport.add_child(background)
	var fx := AttackFx.new()
	fx.front = true
	viewport.add_child(fx)
	fx.set_process(false)
	fx.spawn_skill_trail(Vector2(80, 40), Vector2(80, 40), Color.SKY_BLUE, 12.0)
	fx.spawn_skill_trail(Vector2(120, 40), Vector2(120.0001, 40), Color.SKY_BLUE, 12.0)
	fx.spawn_skill_trail(Vector2(60, 80), Vector2(260, 80), Color.SKY_BLUE, 6.5)
	fx.spawn_skill_trail(Vector2(60, 120), Vector2(260, 120), Color.SKY_BLUE, 0.0)
	fx.spawn_skill_trail(Vector2(60, 160), Vector2(260, 160), Color.SKY_BLUE, 6.5)
	fx.skill_trails.back()["age"] = 0.23999
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image.get_pixel(80, 40).b > 0.4 and image.get_pixel(120, 40).b > 0.4 and \
		image.get_pixel(180, 80).b > 0.4 and image.get_pixel(180, 120).b > 0.4 and \
		image.get_pixel(240, 160).b < 0.12

func _audit_number_edges() -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var fx := AttackFx.new()
	fx.front = true
	fx.size = Vector2(viewport.size)
	fx.clip_contents = true
	viewport.add_child(fx)
	fx.set_process(false)
	fx.spawn_hit(Vector2(1, 49), 36, 172560, false, true)
	fx.spawn_hit(Vector2(319, 65), 36, 9864321, true)
	assert(fx.nums.size() == 2)
	fx.hits.clear()
	for number in fx.nums:
		number["t"] = 0.27
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	var left_count := 0
	var right_count := 0
	for y in 75:
		for x in viewport.size.x:
			if image.get_pixel(x, y).r < 0.55:
				continue
			if y < 4 or x < 4 or x >= viewport.size.x - 4:
				return false
			if x < viewport.size.x / 2:
				left_count += 1
			else:
				right_count += 1
	return left_count > 70 and right_count > 70

func _run() -> void:
	for scenario in [{"aspd": 1.0}, {"aspd": 2.0}, {"aspd": 5.0}, {"aspd": 5.0, "boost": true}]:
		var multiplier: float = scenario["aspd"]
		var core := Core.new()
		root.add_child(core)
		core.size = Vector2(720, 760)
		core.set_process(false)
		core.setup({"atk": 100.0, "hp_max": 1000000.0, "mp_max": 100.0, "aspd": multiplier})
		core.attr_set_base("crit", 0.0)
		if scenario.get("boost", false):
			core.skill["aspd"] = 5
			core._p_aspd = 5.0
			core.hero["curio_aspd"] = 0.25
		core._spawn_foe()
		var foe: Dictionary = core.foes.back()
		foe["hp_max"] = 1000.0
		foe["hp"] = 1000000.0
		foe["shield"] = false
		core._last_quota_wave = core.wave
		core._spawn_t = 999.0
		core._spawn_left = 0
		core.intro_wait = 0.0
		core.running = true
		var counts := {"starts": 0, "hits": 0}
		core.hero_attack.connect(func(): counts["starts"] += 1)
		core.hero_foe_hit.connect(func(_f, _d, _c, _h): counts["hits"] += 1)
		for frame in range(120):
			foe["x"] = core.hero_pos.x
			foe["y"] = core.hero_pos.y - 40.0
			core._hitstop = 0.0 # 隔离顿帧；验证游戏时间内的起手/命中完整配对。
			core._process(1.0 / 60.0)
		assert(counts["starts"] >= 3)
		assert(counts["hits"] >= counts["starts"] - 1, "aspd=%s starts=%s hits=%s" % [multiplier, counts["starts"], counts["hits"]])
		assert(counts["hits"] <= counts["starts"])
		core.queue_free()
		await process_frame
	print("PASS: normal/2x/5x and temporary boosted attack starts resolve once; no overwrite of pending strike")
	if DisplayServer.get_name() != "headless":
		var trail_visible := await _audit_trails()
		assert(trail_visible)
		print("PASS: short skill glints, filled trails, thin edges and fade in the rendered viewport")
		assert(await _audit_number_edges())
		print("PASS: critical and hero damage numbers stay inside the rendered battlefield edges")
	Audio.quit_cleanly()
