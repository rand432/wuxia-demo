extends SceneTree
const Iso := preload("res://tools/test_isolation.gd")
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

var b = null
var t := 0.0
var fired := {}

func _initialize() -> void:
	var e := Iso.verify()
	if e != "":
		print("[STATION_CLIP] REJECT " + e); quit(2); return
	seed(20261116)
	LS.ensure_loaded(); LS.current_level = 6; LS.max_unlocked = 10
	GS.ensure_loaded()
	b = BATTLE.instantiate(); root.add_child(b)

func _process(dt: float) -> bool:
	if b == null or b._core == null or not b.is_inside_tree():
		return true
	t += dt
	if b._tut != null:
		b._tut.cancel(); b._tut.queue_free(); b.set("_tut", null); b._tutorial_pause(false)
	b._core.intro_wait = 0.0
	b._core.set_process(true)
	if t > 1.0 and not fired.has("crowd"):
		fired["crowd"] = true
		for i in 8:
			b._core._spawn_foe("normal", 1.0, 1.0)
	if t > 3.0 and not fired.has("focus"):
		fired["focus"] = true
		var f = b._core._spawn_foe("normal", 1.0, 1.0)
		f["x"] = b._core._home.x
		f["y"] = b._core._home.y - 70.0
		f["stop"] = 70.0
		b._core.order_focus(f, false)
	if t > 5.0 and not fired.has("statue"):
		fired["statue"] = true
		b._core.spawn_statues(3)
		for s in b._core.foes:
			if bool((s as Dictionary).get("still", false)):
				b._core.order_focus(s, false)
				break
	if t > 7.0 and not fired.has("zone"):
		fired["zone"] = true
		b._core.spawn_zone(150.0, 3.0)
	if t > 8.0 and not fired.has("dash"):
		fired["dash"] = true
		print("[STATION_CLIP][TEST] 直接触发表现层冲刺")
		b._start_hero_dash(Vector2(90, -50))
	if t >= 12.0:
		print("[STATION_CLIP] done")
		quit(0)
	return false
