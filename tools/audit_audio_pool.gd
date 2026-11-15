extends SceneTree
const Audio := preload("res://shared/audio.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for i in range(100): Audio.sfx("melee")
	assert(Audio._sfx_active.size() == Audio.SFX_ACTIVE_MAX)
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
	print("PASS: 100 long sounds bounded to 32 active; pool <=16; natural completion and reuse work")
	quit()
