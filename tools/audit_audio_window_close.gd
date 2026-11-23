extends SceneTree
const Audio := preload("res://shared/audio.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	Audio.play_menu_music(0.03)
	await create_timer(0.20).timeout
	assert(not auto_accept_quit and is_instance_valid(Audio._bgm_a) and Audio._bgm_a.playing)
	Audio.sfx("tension")
	assert(not auto_accept_quit)
	root.tree_exiting.connect(func():
		assert(Audio._shutting_down and Audio._sfx_active.is_empty())
		print("PASS: window close waits for audio shutdown before process exit"))
	root.close_requested.emit()
