extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	LS.ensure_loaded()
	GS.ensure_loaded()
	LS.current_level = 1
	LS.max_unlocked = 10
	assert(change_scene_to_packed(Battle) == OK)
	await scene_changed
	var b = current_scene
	b.set_process(false)
	b._core.set_process(false)
	b._end_run(true)
	for i in 12:
		await process_frame
	await create_timer(0.55).timeout
	# 打印底图 rect 供核对
	for c in b._result_layer.find_children("*", "TextureRect", true, false):
		print("[BG] pos=", c.position, " size=", c.size)
	var img: Image = get_root().get_texture().get_image()
	print("[SHOT] ", img.save_png("D:/1/wuxia-demo/.shots/result_after.png"), " size=", img.get_size())
	quit(0)
