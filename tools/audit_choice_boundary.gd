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
	# 正常复制仍授予属性；抽卡飞行动画中结束本局则不领取、不复制。
	var atk: float = b._core.attr_final("atk")
	b._grant_copy("atk_0_0")
	assert(b._core.attr_final("atk") > atk)
	b._crystal = 100
	b._show_draw(true)
	b._zhongli_count = 12
	b._on_draw_pick(b._draw_cards[0])
	assert(b._draw_anim)
	b._end_run(false)
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
	b.queue_free()
	await process_frame
	print("PASS: visible current god hand only; abandonment once; result blocks god/copy and in-flight draw claims")
	Audio.quit_cleanly()
