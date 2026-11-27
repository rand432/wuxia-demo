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
	battle._cam_pulse(1.14, 0.42)
	battle._screen_flash(Color.ORANGE, 0.7, 0.9)
	battle._end_run(win)
	assert(not battle._bm.visible)
	assert(battle._cam.scale == Vector2.ONE)
	var result_flash: Color = battle._flash_rect.color
	battle._on_boss_died(Vector2(320, 380))
	assert(battle._flash_rect.color == result_flash, "A late boss cue replaced the result flash")
	await create_timer(0.18).timeout
	assert(battle._cam.scale == Vector2.ONE, "Old camera animation moved the result scene")
	battle._cam_zoom_to(1.16, 0.07)
	await create_timer(0.18).timeout
	assert(battle._cam.scale == Vector2.ONE)
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
	await create_timer(0.27).timeout
	assert(battle._flash_rect.color.a == 0.0, "An older flash returned after the result flash faded")
	battle.queue_free()
	await process_frame

func _run() -> void:
	await _case(false)
	await _case(true)
	await _camera_transitions()
	await _flash_transitions()
	await _guardian_defeat()
	print("PASS: result freezes rewards and camera; scene flashes cannot return or override results; guardian defeat precedes result")
	Audio.quit_cleanly()

func _camera_transitions() -> void:
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle._tut.cancel()
	battle.set_process(false)
	battle._core.set_process(false)
	battle._cam_zoom_to(1.05, 0.08)
	await create_timer(0.2).timeout
	assert(battle._cam.scale.is_equal_approx(Vector2.ONE * 1.05))
	battle._cam_pulse(1.12, 0.16)
	await create_timer(0.68).timeout
	assert(battle._cam.scale.is_equal_approx(Vector2.ONE * 1.05))
	battle._cam_pulse(1.18, 0.42)
	await create_timer(0.12).timeout
	battle._cam_zoom_to(1.07, 0.12)
	await create_timer(0.92).timeout
	assert(battle._cam.scale.is_equal_approx(Vector2.ONE * 1.07))
	battle.queue_free()
	await process_frame

func _flash_transitions() -> void:
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle._tut.cancel()
	battle.set_process(false)
	battle._core.set_process(false)
	battle._screen_flash(Color.ORANGE, 0.65, 0.8)
	await create_timer(0.09).timeout
	battle._screen_flash(Color.CYAN, 0.25, 0.07)
	await create_timer(0.22).timeout
	assert(battle._flash_rect.color.a == 0.0, "An older flash returned after a shorter cue faded")
	battle.queue_free()
	await process_frame

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
	foe["x"] = 440.0
	foe["y"] = 380.0
	battle._process(0.0)
	var token = battle._foe_tokens[foe["_tid"]]
	assert(token._frame_atlas.resource_path.ends_with("kunshou_zhongyan_v1.png"))
	core.hero_pos = Vector2(230, 538)
	core._hero_cd = 30.0
	core._hitstop = 0.0
	foe["ult_t"] = 0.0
	core._process(0.01)
	battle._process(0.0)
	var sweep: Dictionary = core._delayed[0]
	assert(sweep["shape"] == "sector" and sweep["dir"].x < 0.0)
	token.play_attack(Vector2.RIGHT)
	token._process(0.01)
	assert(token._frame_index == 8 and token._sprite.flip_h)
	core._delayed_tick(1.40)
	token._process(0.01)
	assert(token._frame_index == 10 and token._sprite.flip_h and core._delayed.is_empty())
	assert(battle._hazard_view._sector_flashes.size() == 1)
	var flash: Dictionary = battle._hazard_view._sector_flashes[0]
	assert(is_equal_approx(flash["angle"], Vector2(sweep["dir"]).angle()) and flash["radius"] == sweep["r"])
	# 两段同帧结算时，第二个预警不能替另一个落点提供形状或方向。
	core.queue_delayed(310.0, 355.0, 68.0, 0.0, "真实", 0.40, "震荡", "ring")
	core.queue_delayed(380.0, 385.0, 215.0, 0.0, "真实", 0.50, "横扫", "sector", Vector2.LEFT, 0.0, 1.40)
	for hazard: Dictionary in core._delayed:
		hazard["caster"] = foe
		hazard["boss_attack"] = true
	battle._process(0.0)
	assert(token.boss_warning["shape"] == "ring")
	core._delayed_tick(0.51)
	assert(core._delayed.is_empty())
	assert(battle._hazard_view._ring_flashes.back()["radius"] == 94.0)
	assert(battle._hazard_view._sector_flashes.size() == 2)
	assert(battle._hazard_view._sector_flashes.back()["radius"] == 215.0)
	# 下一段预警在当前横扫之后接续，普通起手不能抢掉横扫姿态。
	core.queue_delayed(380.0, 385.0, 215.0, 0.0, "真实", 0.40, "横扫", "sector", Vector2.LEFT, 0.0, 1.40)
	core.queue_delayed(380.0, 385.0, 45.0, 0.0, "真实", 0.65, "剑气", "beam", Vector2.RIGHT, 220.0)
	for hazard: Dictionary in core._delayed:
		hazard["caster"] = foe
		hazard["boss_attack"] = true
	battle._process(0.0)
	core._delayed_tick(0.41)
	battle._process(0.0)
	assert(token.boss_warning["shape"] == "beam")
	token.prepare_attack(Vector2.RIGHT * 40.0, 0.10)
	token._process(0.01)
	assert(token._frame_index == 10 and token._sprite.flip_h)
	token._process(0.15)
	assert(token._frame_index == 8 and not token._sprite.flip_h)
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
