extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _snapshot(b) -> Array:
	return [b._ancestors.duplicate(true), b._skills.duplicate(true), b._cards.duplicate(), b._acquired.duplicate(true), b._core.attr.duplicate(true), b._draw_charge, b._aug_reroll, b._trea_reroll, b._str_pending, b._trea_pending]

func _click_card(card: Control) -> void:
	var point := card.get_global_transform() * (card.size * 0.5)
	_click_point(point)

func _click_point(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)

func _audit_toolbar(b) -> bool:
	b._crystal = 0
	b._wen = 0
	b._draw_charge = 0
	b._trea_charge = 0
	b._str_tile.show()
	var strength: int = b._str_lv
	for tile: Button in [b._draw_tile, b._mate_tile, b._trea_tile, b._str_tile]:
		_click_card(tile)
		var feedback = tile.get_node("PressFeedback")
		assert(feedback._pulse_color == feedback.REJECT_COLOR)
	assert(not b._draw_layer.visible and not b._god_layer.visible and not b._trea_layer.visible)
	assert(b._str_lv == strength and b._wen == 0)
	_click_card(b._curio_sq)
	var first: Control = b._curio_detail
	assert(first != null and first.visible)
	b._curio_sq.pressed.emit()
	assert(b._curio_detail == first)
	var holder := first.get_node("CurioSheet") as Control
	await create_timer(0.44).timeout
	var idle: Tween = holder.get_meta("motion_idle")
	var close := holder.find_children("*", "Button", false, false)[0] as Button
	_click_point(Vector2(40, 370))
	assert(not idle.is_valid() and not first.visible and b._curio_detail == null)
	_click_card(b._curio_sq)
	var second: Control = b._curio_detail
	close.pressed.emit()
	assert(second != null and second.visible and b._curio_detail == second)
	await create_timer(0.44).timeout
	_click_card(second.get_node("CurioSheet").find_children("*", "Button", false, false)[0] as Button)
	assert(b._curio_detail == null)
	return true

func _audit_entry_pointer() -> bool:
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	b._core.set_process(false)
	await create_timer(0.55).timeout
	b._tut.cancel()
	var toolbar := await _audit_toolbar(b)
	assert(toolbar)
	b._crystal = 100
	b._show_draw(true)
	var draw_card: Control = b._draw_cards[2]
	var draw_motion: Tween = draw_card.get_meta("motion_entry")
	_click_card(draw_card)
	assert(not b._draw_anim and b._draw_paid)
	b._draw_charge = 1
	b._show_god_pick()
	assert(not draw_motion.is_valid() and not b._draw_layer.visible)
	var god = b._god_root.get_child(0)
	_click_card(god)
	assert(b._draw_charge == 1)
	await create_timer(0.24).timeout
	_click_card(god)
	assert(b._draw_charge == 0 and b._ancestors.has(god.aid))
	b._str_pending = true
	b._str_lv = 10
	b._open_aug_pick()
	var augment: Control = b._aug_cards[0]
	_click_card(augment)
	assert(b._str_pending)
	await create_timer(0.24).timeout
	_click_card(augment)
	assert(not b._str_pending)
	b._trea_pending = true
	b._roll_trea()
	b._open_trea()
	var treasure: Control = b._trea_cards[0]
	_click_card(treasure)
	assert(b._trea_pending)
	await create_timer(0.24).timeout
	_click_card(treasure)
	assert(not b._trea_pending)
	var paid_crystal: int = b._crystal
	b._show_draw(true)
	assert(b._crystal == paid_crystal)
	await create_timer(0.24).timeout
	_click_card(draw_card)
	assert(b._draw_anim)
	b.queue_free()
	await process_frame
	return true

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 7
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	b._core.set_process(false)
	b._draw_charge = 3
	b._show_god_pick()
	var card = b._god_root.get_child(0)
	var state := _snapshot(b)
	b._hide_god_pick()
	card.picked.emit()
	assert(_snapshot(b) == state)
	b._show_god_pick()
	# 已被刷新摘除、尚未帧末释放的旧卡不能领取。
	b._roll_god()
	card.picked.emit()
	assert(_snapshot(b) == state)
	card = b._god_root.get_child(0)
	var aid: String = card.aid
	card.picked.emit()
	assert(b._ancestors.has(aid) and b._draw_charge == 2)
	assert(not b._god_layer.visible and b._skill_slots[0].visible and b._skill_slots[0].arriving)
	assert(b._skill_slots[0].skill_icon == b._god_skill_icon(aid))
	assert(b.get_node_or_null("GodSkillSeal") != null)
	state = _snapshot(b)
	card.picked.emit()
	assert(_snapshot(b) == state)
	# 放弃只接受当前可见手牌，且每手只奖励一次。
	b._str_pending = true
	b._trea_pending = true
	b._str_layer.visible = false
	b._trea_layer.visible = false
	state = _snapshot(b)
	b._on_aug_abandon()
	b._on_trea_abandon()
	assert(_snapshot(b) == state)
	var aug: int = b._aug_reroll
	var trea: int = b._trea_reroll
	b._str_layer.visible = true
	b._trea_layer.visible = true
	b._on_aug_abandon()
	b._on_trea_abandon()
	b._on_aug_abandon()
	b._on_trea_abandon()
	assert(b._aug_reroll == aug + 1 and b._trea_reroll == trea + 1)
	assert(not b._str_pending and not b._trea_pending)
	# 刷新后只剩一张宝物时，旧卡数据和领取入口都要清掉。
	b._roll_trea()
	for bond in b.BOND_POOL:
		b._bond_taken[bond["name"]] = true
	for rare in b.RARE_POOL:
		if rare["name"] != "中晶囊":
			b._rare_taken[rare["name"]] = true
	b._roll_trea()
	b._trea_pending = true
	b._open_trea()
	assert(b._trea_cards[0].visible and b._trea_cards[0].o["name"] == "中晶囊")
	b._crystal = 0
	b._show_draw(true)
	assert(b._trea_pending and b._trea_layer.visible and not b._draw_paid)
	for i in [1, 2]:
		assert(not b._trea_cards[i].visible and b._trea_cards[i].o.is_empty())
		b._on_trea_card(b._trea_cards[i])
		assert(b._trea_pending)
	# 正常复制仍授予属性；抽卡飞行动画中结束本局则不领取、不复制。
	var atk: float = b._core.attr_final("atk")
	b._grant_copy("atk_0_0")
	assert(b._core.attr_final("atk") > atk)
	b._crystal = 100
	b._show_draw(true)
	var crystal_after_draw: int = b._crystal
	b._show_god_pick()
	assert(b._god_layer.visible and not b._draw_layer.visible and b._draw_paid)
	b._show_draw(true)
	assert(not b._god_layer.visible and b._draw_layer.visible and b._crystal == crystal_after_draw)
	b._zhongli_count = 12
	b._on_draw_pick(b._draw_cards[0])
	assert(b._draw_anim)
	b._end_run(false)
	assert(not b._draw_layer.visible and not b._str_layer.visible and not b._trea_layer.visible and not b._god_layer.visible)
	b._str_pending = true
	b._trea_pending = true
	b._str_layer.visible = true
	b._trea_layer.visible = true
	b._god_layer.visible = true
	state = _snapshot(b)
	b._show_god_pick()
	b._pick_god("chenshi")
	b._on_god_card(b._god_root.get_child(0))
	b._on_aug_abandon()
	b._on_trea_abandon()
	b._grant_copy("atk_0_0")
	seed(441)
	var next_random := randi()
	seed(441)
	b._zhongli_try("atk_0_0")
	assert(randi() == next_random)
	await create_timer(0.5).timeout
	assert(not b._draw_anim and _snapshot(b) == state)
	assert(not b._skill_slots[0].arriving and b.get_node_or_null("GodSkillSeal") == null)
	b.queue_free()
	await process_frame
	print("PASS: current god hand only, skill arrival, paid draw resumes across choices, abandonment once, result blocks claims")
	if DisplayServer.get_name() != "headless":
		var entry_pointer := await _audit_entry_pointer()
		assert(entry_pointer)
		print("PASS: real viewport clicks, red denial feedback, curio modal cleanup, and card entry input")
	Audio.quit_cleanly()
