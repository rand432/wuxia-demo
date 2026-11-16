extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _battle():
	LS.ensure_loaded()
	LS.current_level = 6
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	b._core.set_process(false)
	return b

func _quest(b, id: String) -> Dictionary:
	for q in b.QUEST_POOL:
		if q["id"] == id: return b._q_prepare(q)
	return {}

func _button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found := _button(child, label)
		if found != null: return found
	return null

func _run() -> void:
	# 存活时正常献祭不致死；完成后清除正在查看的旧详情。
	var b = _battle()
	var c = b._core
	c.hero["hp"] = 100.0
	b._q_offer = _quest(b, "xj")
	b._q_open_popup()
	_button(b._q_pop, "接 受").pressed.emit()
	assert(c.hero["hp"] == 80.0 and b._q_cur["id"] == "xj" and b._q_pop == null)
	b._q_open_popup()
	var crystal: int = b._crystal
	b._q_tick(60.0)
	assert(b._q_done == 1 and b._crystal == crystal + 130 and b._q_pop == null)
	b._q_finish("done")
	assert(b._crystal == crystal + 130)
	c.hero["hp"] = 0.5
	b._q_activate(_quest(b, "xj"))
	assert(c.hero["hp"] == 0.5) # 扣血不会使存活角色死亡，也不反向治疗。
	b.queue_free()
	await process_frame
	# 旧按钮在弹窗关闭/替换后不能接取或放弃新奇遇。
	b = _battle()
	b._q_offer = _quest(b, "xj")
	b._q_open_popup()
	var old_accept := _button(b._q_pop, "接 受")
	var old_decline := _button(b._q_pop, "放 弃")
	b._q_close_popup()
	b._q_offer = _quest(b, "dj")
	b._q_open_popup()
	var current: Control = b._q_pop
	old_accept.pressed.emit()
	old_decline.pressed.emit()
	assert(b._q_offer["id"] == "dj" and b._q_cur.is_empty() and b._q_pop == current and b._q_giveup == 0)
	_button(current, "放 弃").pressed.emit()
	assert(b._q_offer.is_empty() and b._q_giveup == 1 and b._q_pop == null)
	b.queue_free()
	await process_frame
	# 死亡/核心停止/结算后，各入口不复活、不扣款、不发奖、不继续倒计时。
	for mode in ["dead", "stopped", "result"]:
		b = _battle()
		c = b._core
		b._wen = 1000
		b._q_offer = _quest(b, "xj")
		b._q_open_popup()
		if mode == "dead": c.hero["hp"] = 0.0
		elif mode == "stopped": c.running = false
		else: b._end_run(false)
		var hp: float = c.hero["hp"]
		b._q_accept()
		b._q_decline()
		b._q_activate(_quest(b, "xj"))
		assert(c.hero["hp"] == hp and b._q_cur.is_empty() and b._q_offer["id"] == "xj" and b._q_giveup == 0)
		b._q_offer = {}
		b._q_roll()
		b._q_open_popup()
		assert(b._q_offer.is_empty())
		b._q_cur = _quest(b, "xj")
		b._q_cur["t"] = 1.0
		crystal = b._crystal
		b._q_tick(2.0)
		b._q_finish("done")
		assert(b._q_cur["t"] == 1.0 and b._q_done == 0 and b._crystal == crystal)
		b._q_cur = _quest(b, "dj")
		b._q_instant(b._q_cur)
		assert(b._wen == 1000 and b._q_done == 0 and b._q_fail == 0)
		if mode == "result": assert(b._q_pop == null)
		b.queue_free()
		await process_frame
	print("PASS: live sacrifice/reward preserved; stale popup callbacks isolated; dead/stopped/result entry and timer/reward boundaries")
	Audio.quit_cleanly()
