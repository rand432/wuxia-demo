extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _audit_defeat_audio() -> bool:
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.foes.clear()
	for i in 28:
		core._spawn_foe()
	for kind in range(4):
		assert(core.spawn_challenge(kind, 1) == 1)
	for player in Audio._sfx_active.duplicate():
		player.finished.emit()
	var foes: Array = core.foes.duplicate()
	for foe in foes:
		core._kill_foe(foe)
	assert(core.kills_total == foes.size())
	var cues := {}
	for player in Audio._sfx_active:
		if player.stream != null:
			var key: String = player.stream.resource_path.get_file().get_basename()
			cues[key] = int(cues.get(key, 0)) + 1
	for key in ["foe_down", "combo_mark", "coin", "challenge_coin_drop", "bell", "paper", "chest"]:
		assert(cues.get(key, 0) == 1, "%s: %s" % [key, str(cues)])
	assert(not cues.has("fall_down"))
	battle.queue_free()
	return true

func _audit_guardian_intro() -> void:
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	assert(core.spawn_challenge(4, 1) == 1)
	var challenger: Dictionary = core.foes.back()
	challenger["x"] = 40.0
	assert(not battle._boss_name_lb.visible)
	Audio.reset_sfx_stats()
	core.start_boss(4, "困兽·终焉")
	var guardian: Dictionary = core._boss_foe(false)
	assert(battle._boss_name_lb.text == guardian["name"], "The earlier challenger must not receive the stage boss title")
	var expected: float = clampf(core.position.x + float(guardian["x"]), 90.0, 630.0)
	assert(is_equal_approx(battle._boss_spot.position.x, expected))
	var intro_cues: Dictionary = Audio.sfx_stats()["per_key"]
	assert(intro_cues.get("drum", 0) == 1 and intro_cues.get("tension", 0) == 1,
		"A stage boss arrival must play one drum beat and one tension cue: %s" % intro_cues)
	battle.queue_free()

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

func _audit_large_challenge_attacks() -> void:
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	b._tut.cancel()
	var core = b._core
	core.set_process(false)
	core.running = true
	core.intro_wait = 0.0
	core._hero_cd = 999.0
	core._last_quota_wave = core.wave
	core._wave_spawned = core._wave_quota
	core._spawn_left = 0
	core.hero["hp_max"] = 10000.0
	core.hero["hp"] = 10000.0
	var fx = b._fx_front
	var interval: float = 1.0 / core.FOE_ASPD
	for kind in [3, 4]:
		core.foes.clear()
		assert(core.spawn_challenge(kind, 1) == 1)
		var foe: Dictionary = core.foes.back()
		var windup: float = 0.24 if kind == 3 else 0.32
		foe.merge({"x": core.hero_pos.x, "y": core.hero_pos.y - 65.0,
			"t": interval - windup - 0.01}, true)
		b._process(0.0)
		var token = b._foe_tokens[foe["_tid"]]
		var hp_before: float = core.hero["hp"]
		core._process(0.02)
		assert(is_equal_approx(token._ready_duration, windup - 0.01))
		assert(core.hero["hp"] == hp_before)
		token._process(0.03)
		assert(token._frame_index == 8)
		fx.enemy_attacks.clear()
		for i in fx.MAX_ENEMY_ATTACKS:
			fx.spawn_enemy_attack(Vector2.ZERO, Vector2(40, 0), "melee", i + 1)
		Audio.reset_sfx_stats()
		foe["t"] = interval - 0.01
		core._process(0.02)
		assert(core.hero["hp"] < hp_before and token._ready_time == 0.0)
		token._process(0.02)
		assert(token._frame_index == 10)
		var sound := "wood_down" if kind == 3 else "boss_impact_sweep"
		assert(Audio.sfx_stats()["per_key"].get(sound, 0) == 1)
		var attack: Dictionary = fx.enemy_attacks.back()
		assert(attack["kind"] == ("snap" if kind == 3 else "cleaver") and attack["important"])
		for i in fx.MAX_ENEMY_ATTACKS:
			fx.spawn_enemy_attack(Vector2.ZERO, Vector2(40, 0), "melee", i + 100)
		assert(fx.enemy_attacks.size() == fx.MAX_ENEMY_ATTACKS and fx.enemy_attacks.has(attack))
	b.queue_free()

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
	assert(_audit_defeat_audio())
	await process_frame
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
	_audit_guardian_intro()
	_audit_large_challenge_attacks()
	await process_frame
	assert(_audit_roster_density())
	await process_frame
	print("PASS: challenge rewards, bounded spawning, large windups and attack cues, crowd density and layered defeat audio")
	Audio.quit_cleanly()
