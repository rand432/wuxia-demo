extends SceneTree
const Iso := preload("res://tools/test_isolation.gd")
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

var b = null
var t := 0.0
var phase := 0
var done0 := 0
var fails: Array[String] = []
var focus_i := 0
var last_focus := 0.0

func _initialize() -> void:
	var e := Iso.verify()
	if e != "":
		print("[TASKS] REJECT " + e); quit(2); return
	seed(20261116)
	LS.ensure_loaded(); LS.current_level = 6; LS.max_unlocked = 10
	GS.ensure_loaded()
	b = BATTLE.instantiate(); root.add_child(b)

func _process(dt: float) -> bool:
	t += dt
	if b == null or b._core == null or not b.is_inside_tree():
		return true
	if b._tut != null:
		b._tut.cancel(); b._tut.queue_free(); b.set("_tut", null); b._tutorial_pause(false)
	b._core.intro_wait = 0.0
	b._core.set_process(true)
	if phase == 0 and t > 0.8:
		done0 = b._q_done
		_quest("pz", "破阵", "statue", 3, 20.0, 30.0)
		phase = 1
	if phase == 1 and t > 1.2 and t - last_focus > 0.8:
		last_focus = t
		for s in b._core.foes:
			if bool((s as Dictionary).get("still", false)) and float(s["hp"]) > 0.0 and not b._core.foes.has(b._core._order_foe):
				b._core.order_focus(s, false)
				break
	if phase == 1 and t > 12.0:
		_check("破阵任务完成", b._q_done > done0)
		_quest("zd", "占点", "zone", 3.0, 20.0, 20.0)
		phase = 2
	if phase == 2 and t > 21.0:
		_check("占点任务完成", b._q_done > done0 + 1)
		_quest("sh", "守护", "guard", 0, 30.0, 6.0)
		phase = 3
	if phase == 3 and t > 30.0:
		_check("守护任务完成（牢车未碎）", b._q_done > done0 + 2 and not (b._core.guard as Dictionary).is_empty())
		_quest("dt", "单挑", "champion", 0, 30.0, 20.0)
		phase = 4
	if phase == 4 and t > 45.0:
		_check("单挑任务完成或高手已被打", b._q_done > done0 + 3 or b._core.champion == 0)
		print("PASS: station tasks pz/zd/sh/dt" if fails.is_empty() else ("FAIL: " + str(fails)))
		quit(0 if fails.is_empty() else 1)
	return false

func _quest(id: String, n: String, kind: String, need: float, lim: float, _unused: float) -> void:
	var q := {"id": id, "n": n, "tier": 1, "kind": kind, "need": need, "lim": lim, "desc": "", "r": {}}
	b._q_activate(q)
	print("[TASKS] activate ", id, " cur=", b._q_cur.get("id", ""))

func _check(name: String, ok: bool) -> void:
	print(("[TASKS] PASS " if ok else "[TASKS] FAIL ") + name)
	if not ok: fails.append(name)
