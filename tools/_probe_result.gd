extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func dump(n: Node, depth: int) -> void:
	var pad := ""
	for i in depth: pad += "  "
	var extra := ""
	if n is Label: extra = " TEXT=" + str(n.text)
	elif n is Button: extra = " BTN=" + str(n.text)
	elif n is TextureRect: extra = " TEX"
	var pos := Vector2.ZERO
	var sz := Vector2.ZERO
	if n is Control:
		pos = n.position
		sz = n.size
	print(pad, n.get_class(), " p=", pos, " s=", sz, extra)
	for c in n.get_children():
		dump(c, depth + 1)

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
	for i in 5:
		await process_frame
	print("[PROBE] layer children=", b._result_layer.get_child_count())
	dump(b._result_layer, 0)
	quit(0)
