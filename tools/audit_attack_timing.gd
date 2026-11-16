extends SceneTree
const Core := preload("res://kushou/kushou_battle.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

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
	Audio.quit_cleanly()
