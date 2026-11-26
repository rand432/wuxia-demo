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

func _audit_statue_focus(battle) -> void:
	var core = battle._core
	core.foes.clear()
	core.clear_order()
	core.hero_pos = Vector2(core.size.x * 0.5, core.size.y * core.HERO_MID)
	core.intro_wait = 0.0
	core._hero_cd = 0.0
	core._last_quota_wave = core.wave
	core._wave_spawned = core._wave_quota
	core._spawn_left = 0
	core.hero["atk"] = 500.0
	seed(327)
	core.spawn_statues()
	var statue: Dictionary = core.foes[1]
	var normal: Dictionary = core._spawn_foe()
	normal.merge({"x": core.hero_pos.x, "y": 111.0, "hp": 10.0, "hp_max": 10.0}, true)
	assert(is_same(core._order_target(), normal), "Auto-targeting latched onto a stationary quest statue")
	for frame in range(720):
		core._process(1.0 / 60.0)
		if normal.get("_death_settled", false):
			break
	assert(normal.get("_death_settled", false) and core.statues_left() == 3,
		"Auto clear: foe hp=%s, foe y=%s, hero=%s, statues=%s" % [normal["hp"], normal["y"], core.hero_pos, core.statues_left()])
	assert(core.wave_cleared())
	core.tap_at(Vector2(statue["x"], statue["y"]))
	assert(is_same(core._order_target(), statue))
	for frame in range(240):
		core._process(1.0 / 60.0)
		if statue.get("_death_settled", false):
			break
	assert(statue.get("_death_settled", false) and core.statues_left() == 2)

func _audit_automatic_orders(battle) -> void:
	var core = battle._core
	core.foes.clear()
	core.hero_pos = Vector2(100, 290)
	Audio._last_sfx_msec.erase("ui_click")
	battle._q_activate(_quest(battle, "zd"))
	battle._q_ai(0.30)
	assert(core._order_has_pos and core._order_fx.size() == 1)
	core._order_t = 0.24
	battle._q_ai(0.30)
	assert(core._order_t == 0.24 and core._order_fx.size() == 1)
	core.hero_pos = core._order_pos + Vector2(0, 42)
	core._order_has_pos = false
	battle._q_ai(0.30)
	assert(not core._order_has_pos and core._order_fx.size() == 1)
	battle._q_finish("fail")
	assert(core._order_fx.is_empty())
	battle._q_activate(_quest(battle, "sy"))
	var first: Dictionary = core.foes[0]
	var second: Dictionary = core.foes[1]
	battle._q_ai(0.30)
	assert(is_same(core._order_foe, first))
	core._banner_t = 0.2
	battle._q_ai(0.30)
	assert(core._banner_t == 0.2)
	first["hp"] = 0.0
	first["dying"] = 0.2
	battle._q_ai(0.30)
	assert(is_same(core._order_foe, second))
	battle._q_finish("fail")
	assert(core._order_foe.is_empty() and not Audio._last_sfx_msec.has("ui_click"))

	# 跑实际移动和占点帧，覆盖到达后重新受自动站位约束的情形。
	core.hero_pos = Vector2(100, 290)
	var completed: int = battle._q_done
	battle._q_activate(_quest(battle, "zd"))
	var walk_orders := 0
	for frame in range(1080):
		var was_walking: bool = core._order_has_pos
		battle._q_tick(1.0 / 60.0)
		if core._order_has_pos and not was_walking:
			walk_orders += 1
		core._process(1.0 / 60.0)
		if battle._q_cur.is_empty():
			break
	assert(walk_orders == 1 and battle._q_done == completed + 1)
	assert(core.zone.is_empty() and not core._order_has_pos and core._order_fx.is_empty())
	assert(not Audio._last_sfx_msec.has("ui_click"))

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
	var field := Probe.new()
	root.add_child(field)
	field._tut.cancel()
	field.set_process(false)
	field._core.set_process(false)
	_audit_statue_focus(field)
	_audit_automatic_orders(field)
	field.queue_free()
	battle.queue_free()
	await process_frame
	print("PASS: quest timers, rewards, stage clearing, statue focus, and stable quiet automatic orders")
	Audio.quit_cleanly()
