extends SceneTree
const Iso := preload("res://tools/test_isolation.gd")
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

var b = null
var fails: Array[String] = []

func _initialize() -> void:
	var e := Iso.verify()
	if e != "":
		print("[CONT] REJECT " + e); quit(2); return
	seed(20261116)
	LS.ensure_loaded(); LS.current_level = 6; LS.max_unlocked = 10
	GS.ensure_loaded()
	b = BATTLE.instantiate(); root.add_child(b)

func _process(_dt: float) -> bool:
	if b == null or b._core == null or not b.is_inside_tree():
		return true
	if not b.is_inside_tree():
		return true
	b._tut.cancel(); b._tut.queue_free(); b.set("_tut", null); b.set("_tutorial_pause", Callable())
	var core = b._core
	core.intro_wait = 0.0
	core.running = true
	b._run_over = false
	# A. 未排定完不换波
	core.foes.clear(); core.set_wave(3); core.wave_reset_quota()
	core._wave_spawned = core._wave_quota - 1
	b._wave_clock = 99.0
	b._schedule_tick(0.0)
	_check("定额未排定完不换波", int(core.wave) == 3)
	core._wave_spawned = core._wave_quota
	b._wave_clock = 99.0
	b._schedule_tick(0.0)
	_check("排定完到点换波", int(core.wave) == 4 and bool(b._wave_issued.get(3, false)))
	# B. 清波奖励一次
	core.foes.clear()
	core._wave_spawned = core._wave_quota
	b._rewarded_waves.erase(4)
	var wen0: int = b._wen
	b._wave_issued.erase(4)
	b._schedule_tick(0.0)
	_check("清波记一次", bool(b._rewarded_waves.get(4, false)))
	var wen1: int = b._wen
	_check("清波给钱", wen1 > wen0)
	b._schedule_tick(0.0)
	_check("清波不重复给钱", b._wen == wen1)
	# C. 回潮撤怪不发清波奖
	core.set_wave(5); core.wave_reset_quota()
	var f = core._spawn_foe("normal", 1.0, 1.0)
	core._wave_spawned = core._wave_quota
	b._wave_issued.erase(5); b._rewarded_waves.erase(5)
	b._schedule_tick(0.0)
	var kills0: int = int(b._kills)
	b._backwash()
	_check("撤怪不计击杀", int(b._kills) == kills0)
	_check("回潮标记撤怪波次", bool(b._withdrawn_waves.get(5, false)))
	_check("撤怪不发清波奖", not bool(b._rewarded_waves.get(5, false)))
	# C2. 死亡清场不补发清波奖
	core.set_wave(6); core.wave_reset_quota()
	core._spawn_foe("normal", 1.0, 1.0)
	core._wave_spawned = core._wave_quota
	b._wave_issued.erase(6); b._rewarded_waves.erase(6)
	b._schedule_tick(0.0)
	b._end_run(false)
	b._schedule_tick(0.0)
	_check("死亡清场不补发清波奖", not bool(b._rewarded_waves.get(6, false)))
	b._run_over = false
	# D. 末波首领 ≤6
	var wmax := int(b._max_wave)
	core.foes.clear(); core.set_wave(wmax); core.wave_reset_quota()
	core._wave_spawned = core._wave_quota
	core.boss_required = true
	core.boss_alive = false; core.boss_spawned_once = false
	b._boss_spawned = false
	for i in 7:
		var f2 = core._spawn_foe("normal", 1.0, 1.0)
		f2["wave_tag"] = wmax
	b._schedule_tick(0.0)
	_check("末波 7 杂兵不出首领", not bool(b._boss_spawned))
	var killed := 0
	for f3 in core.foes:
		if killed < 1 and int((f3 as Dictionary).get("wave_tag", -1)) == wmax and not bool((f3 as Dictionary).get("boss", false)):
			(f3 as Dictionary)["hp"] = 0.0
			killed += 1
	b._schedule_tick(0.0)
	_check("末波 ≤6 杂兵出首领", bool(b._boss_spawned) and bool(core.boss_alive))
	for s in fails: print("[CONT] FAIL " + s)
	print("PASS: continuous advance, settle-once, withdrawal and boss threshold" if fails.is_empty() else ("FAIL: " + str(fails)))
	quit(0 if fails.is_empty() else 1)
	return false

func _check(name: String, ok: bool) -> void:
	print(("[CONT] PASS " if ok else "[CONT] FAIL ") + name)
	if not ok: fails.append(name)
