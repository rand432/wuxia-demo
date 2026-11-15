extends SceneTree
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")
class Probe extends "res://kushou/battle_ui.gd":
	var crystal_roll := false
	func _roll_curio_crystal() -> bool:
		return crystal_roll

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle := Probe.new()
	root.add_child(battle)
	battle.set_process(false)
	battle._core.set_process(false)
	# 各级清波频率与数量；命可以超过初始100。
	for lv in range(1, 6):
		battle._curio_id = "xumingdeng"
		battle._curio_lv = lv
		battle._curio_waves = 0
		battle._life = 100
		for wave in range(1, 7): battle._curio_on_wave_clear(wave)
		var expected: int = [104, 106, 106, 109, 112][lv - 1]
		assert(battle._life == expected, "lamp clear reward mismatch at lv%d" % lv)
	# 首领奖励经过真实死亡流程，复活和重复死亡均不额外发放。
	battle._curio_lv = 3
	battle._life = 100
	battle._core._spawn_foe("boss", 1.0, 1.0, true, 1, "test")
	var boss: Dictionary = battle._core.foes.back()
	boss["boss_revive"] = 1
	boss["hp"] = 0.0
	battle._core._kill_foe(boss)
	assert(battle._life == 100 and float(boss["hp"]) > 0.0)
	boss["hp"] = 0.0
	battle._core._kill_foe(boss)
	assert(battle._life == 105)
	battle._core._kill_foe(boss)
	assert(battle._life == 105)
	battle._core.spawn_challenge(3, 1)
	var chest: Dictionary = battle._core.foes.back()
	chest["hp"] = 0.0
	battle._core._kill_foe(chest)
	assert(battle._life == 105, "large treasure challenge is not a boss")
	battle._core.spawn_challenge(4, 1)
	var challenge: Dictionary = battle._core.foes.back()
	challenge["hp"] = 0.0
	battle._core._kill_foe(challenge)
	assert(battle._life == 110)
	battle._curio_lv = 2
	battle._curio_on_boss_slain()
	assert(battle._life == 110)
	# 每三次成功清波结算，而非按波号：失败跳过的波不算。
	battle._curio_lv = 1
	battle._curio_waves = 0
	battle._rewarded_waves.clear()
	battle._life = 100
	battle._on_wave_clear(1)
	battle._on_wave_clear(3)
	assert(battle._life == 100)
	battle._on_wave_clear(4)
	assert(battle._life == 102)
	var wen: int = battle._wen
	battle._on_wave_clear(4)
	assert(battle._life == 102 and battle._wen == wen and battle._curio_waves == 3)
	# 聚宝盆：分级收入、千文边界、受既有收入加成与倾囊规则约束。
	battle._curio_id = "jubaopen"
	battle._gold_pct = 0.0
	for lv in range(1, 6):
		battle._curio_lv = lv
		battle._wen = 1000
		battle._crystal = 0
		battle.crystal_roll = true
		battle._curio_on_wave_clear(2)
		assert(battle._wen == [1006, 1008, 1008, 1010, 1030][lv - 1])
		assert(battle._crystal == (1 if lv >= 3 else 0))
	battle._wen = 999
	battle.crystal_roll = false
	battle._curio_on_wave_clear(2)
	assert(battle._wen == 1009 and battle._crystal == 1)
	battle._wen = 1000
	battle._gold_pct = 50.0
	battle._crystal_lock = true
	battle.crystal_roll = true
	battle._curio_on_wave_clear(2)
	assert(battle._wen == 1045 and battle._crystal == 1)
	# 最后一波也必须先发清波奖励，再进入胜利结算；结果期间不重复发。
	battle._curio_id = "xumingdeng"
	battle._curio_lv = 5
	battle._life = 100
	battle._rewarded_waves.clear()
	battle._core.foes.clear()
	battle._core.wave = battle._max_wave
	battle._core._wave_spawned = battle._core._wave_quota
	battle._core.boss_spawned_once = true
	battle._core.boss_alive = false
	battle._boss_spawned = true
	battle._process(0.0)
	assert(battle._run_over and battle._run_cleared and battle._life == 102)
	wen = battle._wen
	battle._process(0.0)
	battle._on_wave_clear(battle._max_wave)
	assert(battle._life == 102 and battle._wen == wen)
	battle.queue_free()
	await process_frame
	print("PASS: lamp levels/boss revival/challenge; basin thresholds/crystal lock; final wave settles once")
	Audio.quit_cleanly()
