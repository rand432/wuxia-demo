extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _rewards(b) -> Array:
	return [b._wen, b._crystal, b._kills, b._exp, b._lv, b._draw_charge, b._trea_charge,
		b._trea_reroll, b._aug_reroll, b._curio_uses, b._curio_kills, b._curio_atk_t,
		b._core.attr.duplicate(true), b._bm.exp, b._bm.level, b._bm._boot_t,
		b._bm.periodic_t, b._bm.warehouse.duplicate(true), b._bm.slots.duplicate(true), b._bm.stock.duplicate(true), b._bm.refresh_n, b._bm.visible]
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")
func _case(win: bool) -> void:
	LS.ensure_loaded()
	LS.current_level = 5
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle._core._spawn_foe()
	var foe: Dictionary = battle._core.foes[0]
	# 正常信号仍结算；结果冻结从结算完成后的状态开始。
	var wen: int = battle._wen
	battle._core.coin.emit(7)
	battle._core.coin_drop.emit(9, Vector2.ZERO)
	assert(battle._wen == wen + 16)
	battle._curio_id = "zuiweng"
	battle._curio_lv = 5
	battle._curio_kills = 9
	battle._bm.slots = [{"name": "踏云靴"}, null] # 留空格，保证取装操作本来可以成功。
	battle._bm._on_kill(1)
	battle._bm.periodic_atk = 1.0
	battle._bm.periodic_t = 9.0
	battle._kills = 1000
	battle._bm.warehouse = [{"type": "道具", "effect": "wen", "value": 100}, {"name": "test", "type": "装备", "stats": {"atk": 5.0}}]
	battle._bm.stock = [{"base": 1, "item": {"kind": "equipment", "name": "test"}}]
	battle._bm.open_panel()
	battle._end_run(win)
	assert(not battle._bm.visible)
	var rewards := _rewards(battle)
	for i in range(3):
		battle._core.coin.emit(100)
		battle._core.coin_drop.emit(100, Vector2.ZERO)
		for kind in range(5): battle._core.chal_drop.emit(kind, Vector2.ZERO)
		battle._core.kill.emit(1)
		battle._bm._process(20.0)
		battle._bm.open_panel()
		battle._bm._buy(0)
		battle._bm._refresh_stock()
		battle._bm._take_out(1)
		battle._bm._store(0)
		battle._bm._use_prop(0)
		battle._bm.add_kill(100)
	assert(_rewards(battle) == rewards)
	var time: float = battle._run_time
	var mp: float = battle._mp
	var hp: float = foe["hp"]
	var cards: int = battle._cards.size()
	var crystal: int = battle._crystal
	battle._show_draw(true)
	battle._on_refresh()
	assert(battle._crystal == crystal)
	battle._tick_skills(2.0)
	battle._cast_skill(0)
	battle._add_card("atk_0_0")
	for i in range(30): battle._process(0.016)
	assert(battle._run_time == time and battle._mp == mp)
	assert(foe["hp"] == hp and battle._cards.size() == cards)
	assert(not battle._core.running)
	assert(_rewards(battle) == rewards)
	battle.queue_free()
	await process_frame

func _run() -> void:
	await _case(false)
	await _case(true)
	await _guardian_defeat()
	print("PASS: win/loss freezes rewards and actions; guardian finishes visual defeat before result reveal")
	Audio.quit_cleanly()

func _guardian_defeat() -> void:
	LS.current_level = 10
	var battle = Battle.instantiate()
	root.add_child(battle)
	await process_frame
	battle._tut.cancel()
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.foes.clear()
	core.set_wave(LS.waves())
	core.wave_reset_quota()
	core._wave_spawned = core._wave_quota
	core.start_boss(LS.boss_tier(), "困兽·终焉")
	battle._boss_spawned = true
	var foe: Dictionary = core._boss_foe(false)
	foe["x"] = 350.0
	foe["y"] = 380.0
	battle._process(0.0)
	var token = battle._foe_tokens[foe["_tid"]]
	assert(token._frame_atlas.resource_path.ends_with("kunshou_zhongyan_v1.png"))
	core._apply_dmg(foe, float(foe["hp"]) + 1.0, "真实")
	core._kill_foe(foe)
	battle._process(0.0)
	assert(battle._run_over and not core.running and LS.first_clear.get("10") == true)
	assert(battle._result_layer.mouse_filter == Control.MOUSE_FILTER_STOP and battle._result_layer.get_child_count() == 0)
	var rewards := _rewards(battle)
	core.coin.emit(100)
	battle._show_draw(true)
	await create_timer(0.22).timeout
	assert(token._frame_index == 15 and token.visible and battle._result_layer.get_child_count() == 0)
	await create_timer(0.27).timeout
	assert(not token.visible and battle._result_layer.get_child_count() > 0 and _rewards(battle) == rewards)
	battle.queue_free()
	await process_frame
