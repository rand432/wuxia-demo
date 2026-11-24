extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _fresh():
	assert(change_scene_to_packed(Battle) == OK)
	await scene_changed
	var b = current_scene
	b.set_process(false)
	b._core.set_process(false)
	return b

func _run() -> void:
	GS.ensure_loaded()
	LS.ensure_loaded()
	LS.current_level = 3
	LS.max_unlocked = 10

	# A. 重复调用结算：带回只算一次
	var b = await _fresh()
	var before: int = GS.coin("wen")
	b._wen = 1000
	b._end_run(true)
	var once: int = GS.coin("wen")
	b._end_run(true)
	var twice: int = GS.coin("wen")
	print("[A] delta1=", once - before, " delta2=", twice - once, " carry=", b._carry_wen)
	assert(once - before == 200, "carry should be 200")
	assert(twice == once, "double end_run must not pay twice")

	# B. 失败：不带回
	b = await _fresh()
	b._wen = 500
	var pre: int = GS.coin("wen")
	b._end_run(false)
	print("[B] lose delta=", GS.coin("wen") - pre, " carry=", b._carry_wen)
	assert(GS.coin("wen") == pre and b._carry_wen == 0, "lose must not carry")

	# C. 中途退出：不带回、不结算首通
	var clears_before := LS.first_clear.size()
	b = await _fresh()
	b._wen = 700
	pre = GS.coin("wen")
	b._show_exit(true)
	var pressed := false
	for btn in b._exit_layer.find_children("*", "Button", true, false):
		if str(btn.text) == "退出":
			btn.pressed.emit()
			pressed = true
			break
	print("[C] pressed=", pressed, " delta=", GS.coin("wen") - pre, " in_tree=", b.is_inside_tree(), " first_clear=", LS.first_clear.size())
	assert(GS.coin("wen") == pre, "abandon must not carry")
	assert(LS.first_clear.size() == clears_before, "abandon must not clear level")
	print("[EDGES] all pass")
	quit(0)
