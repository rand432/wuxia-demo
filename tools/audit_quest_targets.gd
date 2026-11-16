extends SceneTree
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")
class Probe extends "res://kushou/battle_ui.gd":
	var reward_calls := 0
	func _q_reward(q: Dictionary) -> void:
		reward_calls += 1
		super._q_reward(q)
		_q_finish("done") # 奖励回调重入不能重复结算同一奇遇。

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _quest(battle, id: String) -> Dictionary:
	for q in battle.QUEST_POOL:
		if q["id"] == id: return q.duplicate(true)
	assert(false, "missing quest")
	return {}

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle := Probe.new()
	root.add_child(battle)
	battle.set_process(false)
	battle._core.set_process(false)
	battle._curio_id = "zhenhunling"
	for lv in range(1, 6):
		battle._curio_lv = lv
		var count := battle._q_prepare(_quest(battle, "tu"))
		assert(count["need"] == (32 if lv >= 3 else 40))
		assert(count["desc"] == ("杀 32 只" if lv >= 3 else "杀 40 只"))
		assert(battle._q_prepare(count)["need"] == count["need"])
		var survive := battle._q_prepare(_quest(battle, "yx"))
		assert(survive["need"] == 0 and survive["lim"] == (48.0 if lv >= 3 else 60.0))
		var guard := battle._q_prepare(_quest(battle, "sh"))
		assert(guard["need"] == 0 and guard["lim"] == (48.0 if lv >= 3 else 60.0))
		var champion := battle._q_prepare(_quest(battle, "dt"))
		assert(champion["need"] == 0 and champion["lim"] == 90.0)
		var expected_interval: float = battle.Q_TICK / (1.4 if lv >= 4 else 1.25)
		assert(is_equal_approx(battle._q_interval(), expected_interval))
	assert(_quest(battle, "tu")["need"] == 40)
	assert(_quest(battle, "yx")["lim"] == 60.0)
	battle._curio_lv = 3
	battle._crystal = 0
	battle._q_activate(_quest(battle, "tu"))
	battle._qc("kill", 31)
	assert(not battle._q_cur.is_empty() and battle._crystal == 0)
	battle._qc("kill", 1)
	assert(battle._q_cur.is_empty() and battle.reward_calls == 1 and battle._q_done == 1)
	assert(battle._crystal == 33)
	# 有任务进行时不能被新接受任务替换。
	battle._q_activate(_quest(battle, "yx"))
	battle._q_activate(_quest(battle, "tu"))
	assert(battle._q_cur["id"] == "yx")
	battle._q_tick(47.99)
	assert(battle._q_done == 1)
	battle._q_tick(0.02)
	assert(battle._q_cur.is_empty() and battle._q_done == 2)
	# 清道夫通过真实清波入口完成，重复回调不再奖励。
	battle._q_activate(_quest(battle, "qdf"))
	var before: int = battle._crystal
	battle._on_wave_clear(1)
	assert(battle._q_cur.is_empty() and battle._q_done == 3)
	assert(battle._crystal == before + 65)
	battle._on_wave_clear(1)
	assert(battle._crystal == before + 65)
	# 精英尸体仍播放死亡动画时，也应该视为击杀完成。
	battle._q_activate(_quest(battle, "sy"))
	assert(battle._q_cur["need"] == 2)
	for foe in battle._core.foes:
		if foe.get("kind", "") == "elite":
			foe["hp"] = 0.0
			foe["dying"] = 0.36
	battle._q_tick(0.0)
	assert(battle._q_done == 4 and battle._q_cur.is_empty())
	battle._q_activate(_quest(battle, "tu"))
	battle._run_over = true
	before = battle._crystal
	battle._q_finish("done")
	assert(battle._crystal == before and battle._q_done == 4)
	battle.queue_free()
	await process_frame
	print("PASS: bell tier targets/timers/template isolation; quest reentry, clearwave, elite corpses and result guard")
	Audio.quit_cleanly()
