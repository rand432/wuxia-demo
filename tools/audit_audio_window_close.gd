extends SceneTree
const Audio := preload("res://shared/audio.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	Audio.sfx("tension")
	assert(not auto_accept_quit)
	root.tree_exiting.connect(func():
		assert(Audio._shutting_down and Audio._sfx_active.is_empty())
		print("PASS: window close waits for audio shutdown before process exit"))
	root.close_requested.emit()
