extends SceneTree
# 宝物流程回归：0 次数不开、有次数才开、选一张后入池并关闭。
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _fail(msg: String) -> void:
	push_error("AUDIT FAIL: " + msg)
	quit(1)

func _run() -> void:
	GS.ensure_loaded()
	LS.ensure_loaded()
	LS.current_level = 3
	LS.max_unlocked = 10
	assert(change_scene_to_packed(Battle) == OK)
	await scene_changed
	var b = current_scene
	b.set_process(false)
	b._core.set_process(false)

	# A. 0 次数：只提示，不开面板
	b._trea_charge = 0
	b._on_trea_tile()
	await process_frame
	if b._trea_layer.visible:
		_fail("treasure panel opened with 0 charges")
		return
	if str(b._toast_lb.text).find("宝物机会") < 0:
		_fail("missing no-charge toast: " + str(b._toast_lb.text))
		return

	# B. 有次数：扣次数、开面板、至少一张可选
	b._trea_charge = 1
	b._on_trea_tile()
	await process_frame
	if not b._trea_layer.visible:
		_fail("treasure panel not opened")
		return
	if b._trea_charge != 0:
		_fail("charge not consumed")
		return
	var visible_cards := 0
	var first_card = null
	for c in b._trea_cards:
		if c.visible and not c.o.is_empty():
			visible_cards += 1
			if first_card == null:
				first_card = c
	if visible_cards < 1:
		_fail("no selectable treasure card")
		return

	# C. 选一张：羁绊入池或稀有生效，面板关闭
	var before_bonds: int = b._bonds.size()
	var before_rare: int = b._rare_taken.size()
	first_card.picked.emit()
	await process_frame
	var gained: bool = b._bonds.size() > before_bonds or b._rare_taken.size() > before_rare
	if not gained:
		_fail("picking treasure produced no bond/rare")
		return
	if b._trea_layer.visible:
		_fail("treasure panel not closed after pick")
		return
	print("PASS: treasure flow (guard / open / pick) bonds=", b._bonds.size(), " rare=", b._rare_taken.size())
	quit(0)
