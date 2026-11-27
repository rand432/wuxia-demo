extends SceneTree
const Audio := preload("res://shared/audio.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for i in range(100): Audio.sfx("melee")
	assert(Audio._sfx_active.size() == Audio.SFX_ACTIVE_MAX)
	Audio.sfx("enemy_warning", -12.0)
	Audio.sfx("boss_impact_ground", -8.0)
	Audio.sfx("ui_click", -13.0)
	assert(Audio.sfx_stats()["per_key"].get("enemy_warning", 0) == 1)
	assert(Audio.sfx_stats()["per_key"].get("boss_impact_ground", 0) == 1)
	assert(Audio.sfx_stats()["per_key"].get("ui_click", 0) == 1)
	assert(Audio._sfx_active.size() == Audio.SFX_ACTIVE_MAX)
	assert(Audio._sfx_active.filter(func(p): return p.sfx_key == "melee").size() == Audio.SFX_ACTIVE_MAX - 3)
	for player in Audio._sfx_active:
		assert(player.get_parent() == root)
	# 模拟结束回调，检查回收、重复回调和下一批播放。
	var players: Array = Audio._sfx_active.duplicate()
	for player in players:
		player.finished.emit()
	assert(Audio._sfx_active.is_empty() and Audio._sfx_pool.size() == Audio.SFX_POOL_MAX)
	Audio._release_sfx_player(players[0])
	assert(Audio._sfx_pool.size() == Audio.SFX_POOL_MAX)
	await process_frame
	for i in range(8): Audio.sfx("coin")
	assert(Audio._sfx_active.size() == 8)
	# 给真实短音效时间结束，验证原生finished信号而非只靠模拟回调。
	await create_timer(1.0).timeout
	assert(Audio._sfx_active.is_empty())
	assert(Audio._sfx_pool.size() <= Audio.SFX_POOL_MAX)
	for i in 16: Audio.sfx("bow", -13.0, 1.0, 95)
	assert(Audio._sfx_active.size() == 1)
	Audio.sfx("forge_hammer", -8.0)
	assert(Audio._sfx_active.size() == 2)
	await create_timer(0.85).timeout
	assert(Audio._sfx_active.is_empty())
	# 播放器可进入 playing 状态，即使总线实际没有收到声音。
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 0.75
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	Audio.sfx("enemy_warning", -12.0)
	await create_timer(0.40).timeout
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	AudioServer.remove_bus_effect(0, effect_index)
	assert(peak > 0.03 and peak < 0.95, "enemy warning mixer peak %f" % peak)
	print("PASS: enemy warning reaches the master mixer without clipping, peak=", peak)
	print("PASS: warnings, boss impacts and clicks play at capacity; bounded pool, natural completion and reuse; separate forge strike")
	quit()
