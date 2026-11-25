extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _audit_challenge_poses() -> bool:
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	var core = b._core
	core.set_process(false)
	core.foes.clear()
	core.set_wave(5)
	for kind in range(3):
		var count: int = core.foes.size()
		b._toggle_challenge()
		b._chal_btns[kind].pressed.emit()
		assert(core.foes.size() == count + b.CHAL_GROUP[kind])
		var foe: Dictionary = core.foes.back()
		foe["y"] = 300.0
		b._process(0.0)
		var token = b._foe_tokens[foe["_tid"]]
		token.set_process(false)
		assert(token._frame_atlas == b._chal_btns[kind].art and not token.round_mask)
		assert(token.challenge_kind == kind and token.ring_col == b.CHALLENGE_RIMS[kind])
		token._process(0.12)
		assert(token._frame_index in range(4))
		foe["x"] += 5.0
		b._process(0.0)
		token._process(0.12)
		assert(token._frame_index in range(4, 8))
		core.foe_windup.emit(foe, core.hero_pos, 0.16)
		token._process(0.03)
		assert(token._frame_index == 8)
		core.foe_attack.emit(foe, core.hero_pos)
		token._process(0.02)
		assert(token._frame_index == 10)
		core._apply_dmg(foe, float(foe["hp"]) * 0.12, "真实")
		b._process(0.0)
		token._process(0.13)
		assert(token._frame_index in [12, 13])
		foe["hp"] = 0.0
		core._kill_foe(foe)
		b._process(0.0)
		token._process(0.25)
		assert(token._frame_index == 15)
	b.queue_free()
	return true

func _audit_roster_density() -> bool:
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	var core = b._core
	core.set_process(false)
	core.foes.clear()
	for i in range(18):
		core._spawn_foe()
	core.spawn_challenge(0, 2)
	core.spawn_challenge(3, 1)
	core.start_boss(2, "双头狮")
	assert(core.foes.size() == 22)
	for foe in core.foes:
		foe["y"] = 300.0
	core.foes[0]["y"] = 80.0
	core.foes[6]["rtype"] = "coin"
	b._process(0.0)
	assert(not b._dense_roster)
	core.foes[0]["y"] = 300.0
	core.foes[0]["dying"] = 0.15
	b._process(0.0)
	assert(not b._dense_roster)
	core.foes[0]["dying"] = 0.0
	b._process(0.0)
	assert(b._dense_roster)
	for i in [1, 6, 18, 20, 21]:
		var token = b._foe_tokens[core.foes[i]["_tid"]]
		assert(token.compact_bar == (i in [1, 18]))
	for i in range(4):
		core.foes[i]["y"] = 80.0
	b._process(0.0)
	assert(b._dense_roster)
	core.foes[4]["y"] = 80.0
	b._process(0.0)
	assert(not b._dense_roster and not b._foe_tokens[core.foes[18]["_tid"]].compact_bar)
	b.queue_free()
	return true

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var cap_test = Battle.instantiate()
	root.add_child(cap_test)
	cap_test.set_process(false)
	var cap_core = cap_test._core
	cap_core.set_process(false)
	cap_core.foes.clear()
	for i in cap_core.MAX_FOES + 16:
		cap_core._spawn_foe("coin")
	var last: Dictionary = cap_core.foes.back()
	var snapshot := last.duplicate(true)
	cap_core.set_wave(5)
	cap_test._refresh_chal_panel()
	assert(cap_test._chal_btns[3].status == "应战")
	cap_test._chal_press(3)
	assert(not last.has("chal") and last == snapshot)
	assert(cap_test._chal_cd[3] == 0.0 and cap_test._chal_count == 0)
	assert(cap_test._chal_btns[3].status == "应战")
	cap_core.foes.pop_back()
	cap_test._chal_press(3)
	assert(cap_core.foes.back().get("chal") == 3)
	assert(cap_test._chal_cd[3] > 0.0 and cap_test._chal_count == 1 and cap_test._chal_btns[3].disabled)
	cap_test.queue_free()
	await process_frame
	for wave in [1, 5, 10]:
		for kind in [3, 4]:
			for boosted in [false, true]:
				var b = Battle.instantiate()
				root.add_child(b)
				b.set_process(false)
				var c = b._core
				c.set_process(false)
				c.foes.clear()
				c.kill.disconnect(b._on_core_kill) # 只测额外挑战奖励，保留真实coin_drop通道。
				b._curio_id = ""
				b._boss_pct = 50.0 if boosted else 0.0
				b._gold_pct = 20.0 if boosted else 0.0
				b._treasure_pct = 0.0
				c.set_wave(wave)
				c.spawn_challenge(kind, 1)
				var f: Dictionary = c.foes.back()
				f["boss_revive"] = 1
				var state := [b._wen, b._crystal, b._trea_charge, b._trea_reroll, b._aug_reroll]
				var core_money := [0]
				c.coin_drop.connect(func(n, _p): core_money[0] += n)
				c.kill.connect(func(_n): c._kill_foe(f))
				f["hp"] = 0.0
				c._kill_foe(f)
				assert([b._wen, b._crystal, b._trea_charge, b._trea_reroll, b._aug_reroll] == state)
				f["hp"] = 0.0
				c._kill_foe(f)
				var boss_mul := 1.5 if boosted else 1.0
				var gold_mul := 1.2 if boosted else 1.0
				var money := int(round(float(int(220.0 * (1.0 + 0.05 * (wave - 1)) * boss_mul)) * gold_mul)) if kind == 4 else 0
				var crystal := int(round(30.0 * (1.0 + 0.03 * (wave - 1)) * boss_mul)) if kind == 4 else 0
				assert(core_money[0] == 0 and b._wen == state[0] + money and b._crystal == state[1] + crystal)
				assert(b._trea_charge == state[2] + 1 and b._trea_reroll == state[3] + 1)
				assert(b._aug_reroll == state[4] + (1 if kind == 4 else 0))
				var paid := [b._wen, b._crystal, b._trea_charge, b._trea_reroll, b._aug_reroll]
				c._kill_foe(f)
				assert([b._wen, b._crystal, b._trea_charge, b._trea_reroll, b._aug_reroll] == paid)
				b.queue_free()
				await process_frame
	assert(_audit_challenge_poses())
	await process_frame
	assert(_audit_roster_density())
	await process_frame
	print("PASS: challenge rewards, bounded spawning, shared atlases and visible crowd density thresholds")
	Audio.quit_cleanly()
