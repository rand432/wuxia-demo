extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

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
	cap_core.spawn_challenge(3, 1)
	assert(not last.has("chal") and last == snapshot)
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
	print("PASS: real challenge chest no bonus money; bandit 220 once with wave/boss/gold multipliers; treasure/refresh preserved; revive/reentrant/repeated death never duplicates")
	Audio.quit_cleanly()
