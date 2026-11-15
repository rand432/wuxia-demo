extends SceneTree
const Audio := preload("res://shared/audio.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for i in range(40): Audio.sfx("tension")
	assert(Audio._sfx_active.size() == 32)
	await Audio.shutdown()
	assert(Audio._sfx_active.is_empty() and Audio._sfx_pool.is_empty() and Audio._cache.is_empty())
	Audio.sfx("coin")
	assert(Audio._sfx_active.is_empty())
	print("PASS: shutdown releases long voices and cached resources; deferred playback cannot restart")
	quit()
