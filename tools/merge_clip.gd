extends SceneTree
const Iso := preload("res://tools/test_isolation.gd")
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
var b = null
var t := 0.0
var want := 3
var done := false

func _initialize() -> void:
	var e := Iso.verify()
	if e != "":
		print("[MERGE_CLIP] REJECT " + e); quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="): want = int(arg.get_slice("=", 1))
	seed(20261116)
	LS.ensure_loaded(); LS.current_level = 6
	b = Battle.instantiate(); root.add_child(b)

func _process(dt: float) -> bool:
	t += dt
	if b == null or b._core == null or not b.is_inside_tree():
		return true
	if b._tut != null:
		b._tut.cancel(); b._tut.queue_free(); b.set("_tut", null)
	b._core.set_process(false)
	if t > 0.35 and not done:
		done = true
		var ids: Array = []
		for sid in b._set_cards.keys():
			var cand: Array = b._set_cards[sid]
			if cand.size() == want and int((b._card_db.get(str(cand[0]), {}) as Dictionary).get("set_size", 0)) == want:
				ids = cand.duplicate(); break
		for cid in ids: b._cards.append(str(cid))
		b._check_sets()
		print("[MERGE_CLIP] size=", want, " combined=", b._combined.size())
	if t >= 3.2:
		quit(0)
	return false
