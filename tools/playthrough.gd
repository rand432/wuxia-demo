extends Control
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const LOG_PATH := "res://tools/playthrough.log"

var b = null
var lv := 1
var t := 0.0
var cd := 0.0
var wait_draw := 0
var wait_trea := 0
var done := false
var failures := 0
var end_level := 10

func _ready() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		push_error("请通过 tools/run_playthrough.ps1 运行隔离测试")
		get_tree().quit(2)
		return
	seed(20261116)
	LS.ensure_loaded()
	lv = 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start-level="):
			lv = clampi(int(arg.get_slice("=", 1)), 1, 10)
		if arg.begins_with("--end-level="):
			end_level = clampi(int(arg.get_slice("=", 1)), lv, 10)
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.store_line("# 十关连续通关")
		f.close()
	_start()

func _log(s: String) -> void:
	print(s)
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.seek_end(); f.store_line(s); f.close()

func _start() -> void:
	if lv > end_level:
		_log("[ALL] max_unlocked=%d first_clear=%s" % [LS.max_unlocked, str(LS.first_clear)])
		preload("res://shared/audio.gd").quit_cleanly(0 if failures == 0 else 1); return
	LS.current_level = lv
	b = BATTLE.instantiate(); add_child(b)
	t = 0.0; cd = 0.0; wait_draw = 0; wait_trea = 0; done = false
	_log("[GO] L%d" % lv)

func _process(dt: float) -> void:
	if b == null or b._core == null or done:
		return
	t += dt
	cd -= dt
	if b._tut != null and b._tut.visible:
		var tg = b._tut._target
		if tg == null or not is_instance_valid(tg) or not tg.is_visible_in_tree():
			_log("[WARN] L%d 教学目标无效" % lv)
		b._tut._on_pressed(); return
	if b._run_over:
		done = true
		var win: bool = b._run_cleared
		_log("[END] L%d %s t=%.0fs wave=%d/%d kills=%d hp=%d/%d unlock=%d" % [
			lv, "WIN" if win else "LOSE", t, int(b._core.wave), b._max_wave, int(b._kills),
			int(float(b._core.hero.get("hp", 0.0))), int(float(b._core.hero.get("hp_max", 1.0))), LS.max_unlocked])
		_log("[FAMILY] L%d combos=%d shiny=%s" % [lv, b._ancestor_combos.size(), str(b._family_shiny_done)])
		if not win:
			failures += 1
		_finish(); return
	if t > 420.0:
		done = true
		failures += 1
		_log("[STATE] cards=%s wen=%d crystal=%d pending=%s god=%s ancestors=%s running=%s processing=%s" % [str(b._cards), b._wen, b._crystal, str(b._str_pending), str(b._god_layer.visible), str(b._ancestors.keys()), str(b._core.running), str(b._core.is_processing())])
		_log("[CORE] hero=%s pos=%s spawned=%s quota=%s live=%s cd=%s" % [str(b._core.hero), str(b._core.hero_pos), str(b._core._wave_spawned), str(b._core._wave_quota), str(b._core.live_foes()), str(b._core._hero_cd)])
		for foe in b._core.foes:
			if float(foe.get("hp", 0)) > 0:
				_log("[FOE] %s" % str(foe))
		_log("[DRAW] paid=%s visible=%s anim=%s candidates=%s" % [str(b._draw_paid), str(b._draw_layer.visible), str(b._draw_anim), str(b._draw_cards.map(func(c): return c.data.get("_id", "EMPTY")))])
		_log("[END] L%d TIMEOUT t=%.0fs wave=%d/%d" % [lv, t, int(b._core.wave), b._max_wave])
		_finish(); return
	if wait_draw > 0:
		wait_draw -= 1
		if wait_draw == 0 and b._draw_layer != null and b._draw_layer.visible:
			var choice = _choose_draw_card()
			if choice != null:
				b._on_draw_pick(choice)
		return
	if wait_trea > 0:
		wait_trea -= 1
		if wait_trea == 0 and b._trea_layer != null and b._trea_layer.visible:
			if b._trea_cards.size() > 0:
				b._on_trea_card(b._trea_cards[0])
		return
	if cd > 0.0:
		return
	cd = 0.3
	# 请神按界面实际给出的选项操作，不直接注入角色。
	if b._god_layer != null and b._god_layer.visible and b._god_root != null:
		for card in b._god_root.get_children():
			b._pick_god(str(card.aid))
			return
	var has_unseen_god := false
	for aid in LS.god_ids():
		if not b._ancestors.has(str(aid)):
			has_unseen_god = true
	if has_unseen_god and b._mate_tile != null and b._mate_tile.visible and b._draw_charge > 0:
		b._on_mate_tile()
		return
	if b._q_cur.is_empty() and not b._q_offer.is_empty():
		b._q_open_popup(); b._q_accept(); return
	if b._str_pending and b._aug_cards.size() > 0:
		b._on_aug_card(b._aug_cards[0]); return
	if b._str_tile != null and b._str_tile.visible and b._wen >= b._str_cost():
		b._on_str_tile(); return
	if b._trea_tile != null and b._trea_tile.visible and b._trea_charge > 0:
		b._on_trea_tile()
		if b._trea_layer != null and b._trea_layer.visible:
			wait_trea = 8
		return
	if b._draw_tile != null and b._draw_tile.visible and b._crystal >= 20 and not b._pool.is_empty():
		b._show_draw(true)
		if b._draw_layer != null and b._draw_layer.visible:
			wait_draw = 8
		return

func _finish() -> void:
	if b != null:
		b.queue_free(); b = null
	lv += 1
	call_deferred("_start")

func _choose_draw_card():
	var best = null
	var best_score := -1
	for card in b._draw_cards:
		if card.data.is_empty():
			continue
		var data: Dictionary = card.data
		var score := 100 if data.has("ancestor") else 0
		if bool(data.get("shiny", false)):
			score += 10000
		var set_id := str(data.get("set_id", ""))
		var owned := 0
		for id in b._cards:
			if set_id != "" and str((b._card_db.get(str(id), {}) as Dictionary).get("set_id", "")) == set_id:
				owned += 1
		score += owned * 1000
		if owned + 1 >= int(data.get("set_size", 999)):
			score += 20000
		if score > best_score:
			best = card
			best_score = score
	return best
