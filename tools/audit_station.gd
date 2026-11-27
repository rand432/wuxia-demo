extends SceneTree
const Iso := preload("res://tools/test_isolation.gd")
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

var b = null
var failures: Array[String] = []
var phase := 0
var t := 0.0
var focus_ref = null
var ranged_ref = null
var statue_refs: Array = []
var statue_hps: Array = []
var hp_before := 0.0

func _initialize() -> void:
	var e := Iso.verify()
	if e != "":
		print("[STATION] ISOLATION_REJECT " + e); quit(2); return
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
	if b._core != null:
		b._core.set_process(true)
	if phase == 0 and t > 0.5:
		b._core.intro_wait = 0.0
		_check_reachable_target()
		b._core.tap_at(Vector2(120, 300))
		phase = 1
	if phase == 1 and t > 1.3:
		_check("站点点空地不走位", b._core.hero_pos.distance_to(b._core._home) < 2.0)
		focus_ref = b._core._spawn_foe("normal", 1.0, 1.0)
		focus_ref["x"] = b._core._home.x
		focus_ref["y"] = b._core._home.y - 60.0
		focus_ref["stop"] = 60.0
		b._core.order_focus(focus_ref, false)
		hp_before = float(focus_ref["hp"])
		phase = 2
	if phase == 2 and t > 3.3:
		_check("集火目标被站桩攻击", _damaged(focus_ref, hp_before))
		ranged_ref = b._core._spawn_foe("normal", 1.0, 1.0)
		ranged_ref["x"] = b._core._home.x
		ranged_ref["y"] = b._core._home.y - 78.0
		ranged_ref["stop"] = 78.0
		ranged_ref["ranged"] = true
		ranged_ref["mage"] = false
		b._core.order_focus(ranged_ref, false)
		hp_before = float(ranged_ref["hp"])
		phase = 3
	if phase == 3 and t > 5.5:
		_check("远程怪可被站桩打到", _damaged(ranged_ref, hp_before))
		b._core.spawn_statues(3)
		statue_refs = []
		statue_hps = []
		for s in b._core.foes:
			if bool((s as Dictionary).get("still", false)):
				statue_refs.append(s)
				statue_hps.append(float(s["hp"]))
		if statue_refs.size() > 0:
			b._core.order_focus(statue_refs[0], false)
		phase = 4
	if phase == 4 and t > 8.5:
		var hit := 0
		for i in statue_refs.size():
			if _damaged(statue_refs[i], statue_hps[i]):
				hit += 1
		_check("破阵石像可被集火打碎", hit >= 1 and statue_refs.size() == 3)
		b._core.spawn_zone(150.0, 1.0)
		phase = 5
	if phase == 5 and t > 10.0:
		_check("占点法阵在驻点累积", b._core.zone_prog() > 0.0)
		b._core.clear_zone()
		b._start_hero_dash(Vector2(90, -40))
		phase = 6
	if phase == 6 and t > 10.8:
		_check("滚地龙冲刺偏移会归零", b._hero_visual_offset.length() < 0.5)
		_check("冲刺期间脚点不变", b._core.hero_pos.distance_to(b._core._home) < 2.0)
		b._start_hero_dash(Vector2(80, 0))
		phase = 7
	if phase == 7 and t > 11.1:
		b._end_run(false)
		phase = 8
	if phase == 8 and t > 11.4:
		_check("死亡/结算清除冲刺偏移", b._hero_visual_offset.length() < 0.5)
		print("PASS: station fixed, focus, ranged, statue, zone and dash return" if failures.is_empty() else ("FAIL: " + str(failures)))
		quit(0 if failures.is_empty() else 1)
	return false

func _damaged(ref, hp0: float) -> bool:
	if ref == null:
		return false
	if not b._core.foes.has(ref):
		return true
	return float(ref.get("hp", 0.0)) < hp0 - 0.1

func _check_reachable_target() -> void:
	var core = b._core
	core.foes.clear()
	var far: Dictionary = core._spawn_foe()
	far["x"] = core._home.x
	far["y"] = core._home.y - 200.0
	core._order_target() # 先形成自动锁定，再让一只近怪进场。
	var near: Dictionary = core._spawn_foe()
	near["x"] = core._home.x
	near["y"] = core._home.y - 54.0
	_check("自动索敌不等着远处旧目标", is_same(core._order_target(), near))
	core.order_focus(far, false)
	_check("集火目标未到时先打近怪", is_same(core._order_target(), near) and is_same(core._order_foe, far))
	far["y"] = core._home.y - 70.0
	_check("原集火进射程后恢复优先", is_same(core._order_target(), far))
	core.clear_order()
	core.foes.clear()

func _check(name: String, ok: bool) -> void:
	print(("[STATION] PASS " if ok else "[STATION] FAIL ") + name)
	if not ok: failures.append(name)
