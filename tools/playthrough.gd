extends Control
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")
const CurioData := preload("res://shared/curio_data.gd")
const LOG_PATH := "user://playthrough.log"

var b = null
var lv := 1
var t := 0.0
var cd := 0.0
var wait_draw := 0
var wait_trea := 0
var done := false
var failures := 0
var end_level := 10
var timeout_seconds := 420.0
var audit_curio := ""
var audit_curio_level := 1
var audit_basic_skill_level := 0
var audit_basic_family_stars := 0
var observed_wave := 1
var audit_backwash_final := false
var audit_backwash_used := false
var audit_seed := 20261116
var restrict_strength := false
var waves: Array = []
var wave_cur: Dictionary = {}
var tracked_wave := -1
var wall_start := 0
var boss_prev_hp := -1.0
var boss_hits := 0
var boss_dmg := 0.0
var boss_log_at := -1.0
var boss_max_seen := 0.0
var boss_hero_hp := 0.0

func _ready() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		push_error("请通过 tools/run_playthrough.ps1 运行隔离测试")
		get_tree().quit(2)
		return
	LS.ensure_loaded()
	lv = 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start-level="):
			lv = clampi(int(arg.get_slice("=", 1)), 1, 10)
		if arg.begins_with("--end-level="):
			end_level = clampi(int(arg.get_slice("=", 1)), lv, 10)
		if arg.begins_with("--timeout-seconds="):
			timeout_seconds = clampf(float(arg.get_slice("=", 1)), 60.0, 1800.0)
		if arg.begins_with("--curio-id="):
			audit_curio = arg.get_slice("=", 1)
		if arg.begins_with("--curio-level="):
			audit_curio_level = clampi(int(arg.get_slice("=", 1)), 1, 5)
		if arg.begins_with("--basic-skill-level="):
			audit_basic_skill_level = clampi(int(arg.get_slice("=", 1)), 0, 1000)
		if arg.begins_with("--basic-family-stars="):
			audit_basic_family_stars = clampi(int(arg.get_slice("=", 1)), 0, 5)
		if arg.begins_with("--backwash-at-final="):
			audit_backwash_final = arg.get_slice("=", 1).to_lower() == "true"
		if arg.begins_with("--seed="):
			audit_seed = int(arg.get_slice("=", 1))
		if arg.begins_with("--restrict-strength="):
			restrict_strength = arg.get_slice("=", 1).to_lower() == "true"
	seed(audit_seed)
	GS.ensure_loaded()
	GS.skill_lv["zhujue"] = audit_basic_skill_level # 仅隔离测试，可保存到本次隔离目录。
	GS.stars["zhujue"] = audit_basic_family_stars
	if not audit_curio.is_empty():
		if CurioData.get_curio(audit_curio).is_empty():
			push_error("未知测试奇物：" + audit_curio)
			get_tree().quit(2)
			return
		GS._curio_ensure()
		GS.curio_id = audit_curio
		GS.curio_lv[audit_curio] = audit_curio_level # 仅隔离测试进程内设置，不写正常玩家存档。
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
	observed_wave = int(b._core.wave)
	audit_backwash_used = false
	t = 0.0; cd = 0.0; wait_draw = 0; wait_trea = 0; done = false
	waves = []
	wave_cur = {}
	tracked_wave = int(b._core.wave)
	wall_start = Time.get_ticks_msec()
	boss_prev_hp = -1.0
	boss_hits = 0
	boss_dmg = 0.0
	boss_log_at = -1.0
	_log("[GO] L%d" % lv)
	_log("[SEED] %d" % audit_seed)
	_log("[SCENARIO] build=%s seed=%d decision_cadence=0.3s" % ["restrict_strength" if restrict_strength else "auto", audit_seed])
	_log("[CURIO] L%d id=%s level=%d" % [lv, str(b._curio_id), int(b._curio_lv)])
	_log("[BASIC_SKILL] L%d level=%d multiplier=%.2f" % [lv, audit_basic_skill_level, b._core.basic_skill_multiplier()])

func _process(dt: float) -> void:
	if b == null or b._core == null or done:
		return
	if int(b._core.wave) < observed_wave:
		_log("[REWIND] L%d wave=%d->%d boss_required=%s" % [lv, observed_wave, int(b._core.wave), str(b._core.boss_required)])
	observed_wave = int(b._core.wave)
	if audit_backwash_final and not audit_backwash_used and not b._run_over and int(b._core.wave) >= int(b._max_wave):
		audit_backwash_used = true
		b._core.boss_required = true # 重现原卡关：已进入末波首领门槛，尚未出首领。
		_log("[SCENARIO] L%d force backwash from final wave=%d" % [lv, int(b._core.wave)])
		b._backwash()
	t += dt
	cd -= dt
	_track_wave(t)
	if b._tut != null and b._tut.visible:
		var tg = b._tut._target
		if tg == null or not is_instance_valid(tg) or not tg.is_visible_in_tree():
			_log("[WARN] L%d 教学目标无效" % lv)
		b._tut._on_pressed(); return
	if b._run_over:
		done = true
		var win: bool = b._run_cleared
		_finalize_wave(t, win, false)
		_log_boss_end()
		_log_pace(t, win)
		_log("[WALL] L%d %dms" % [lv, Time.get_ticks_msec() - wall_start])
		_log("[END] L%d %s t=%.0fs wave=%d/%d kills=%d hp=%d/%d unlock=%d" % [
			lv, "WIN" if win else "LOSE", t, int(b._core.wave), b._max_wave, int(b._kills),
			int(float(b._core.hero.get("hp", 0.0))), int(float(b._core.hero.get("hp_max", 1.0))), LS.max_unlocked])
		_log("[DECISION] L%d str=%d draws=%d gods=%d trea=%d enc_done=%d wen_in=%d wen_out=%d cards=%d" % [lv, int(b._str_lv), int(b._dbg_draws), int(b._dbg_gods), int(b._trea_charge), int(b._q_done), int(b._dbg_wen_in), int(b._dbg_wen_out), b._cards.size()])
		_log("[FAMILY] L%d combos=%d shiny=%s" % [lv, b._ancestor_combos.size(), str(b._family_shiny_done)])
		_log("[BASIC_FAMILY] L%d stars=%d tiers=%s" % [lv, audit_basic_family_stars, str(b._ancestor_combos.filter(func(ar): return str(ar.get("ancestor", "")) == "zhujue").map(func(ar): return int(ar["tier"])))])
		_log("[QUEST_RESULT] L%d done=%d fail=%d giveup=%d" % [lv, b._q_done, b._q_fail, b._q_giveup])
		_log("[CURIO_RESULT] L%d uses=%d" % [lv, b._curio_uses])
		_log("[RARE_RESULT] L%d taken=%s" % [lv, str(b._rare_taken.keys())])
		_log("[SKILL_RESULT] L%d roles=%s backwash=%s" % [lv, str(b._skills.map(func(sk): return str(sk["aid"]))), str(b._acquired.has("shiny_backwash"))])
		if not win:
			failures += 1
		_finish(); return
	if t > timeout_seconds:
		done = true
		failures += 1
		_finalize_wave(t, false, true)
		_log_boss_end()
		_log_pace(t, false)
		_log("[WALL] L%d %dms" % [lv, Time.get_ticks_msec() - wall_start])
		_log("[STATE] cards=%s wen=%d crystal=%d pending=%s god=%s ancestors=%s running=%s processing=%s" % [str(b._cards), b._wen, b._crystal, str(b._str_pending), str(b._god_layer.visible), str(b._ancestors.keys()), str(b._core.running), str(b._core.is_processing())])
		_log("[CORE] hero=%s pos=%s spawned=%s quota=%s live=%s cd=%s" % [str(b._core.hero), str(b._core.hero_pos), str(b._core._wave_spawned), str(b._core._wave_quota), str(b._core.live_foes()), str(b._core._hero_cd)])
		_log("[WAVE_STATE] clear=%s required=%s boss_alive=%s boss_once=%s ui_boss=%s run_cleared=%s ui_processing=%s tutorial=%s" % [str(b._core.wave_cleared()), str(b._core.boss_required), str(b._core.boss_alive), str(b._core.boss_spawned_once), str(b._boss_spawned), str(b._run_cleared), str(b.is_processing()), str(b._tut != null and b._tut.visible)])
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
			b._on_god_card(card)
			return
	var has_unseen_god := false
	for aid in LS.god_ids():
		if not b._ancestors.has(str(aid)):
			has_unseen_god = true
	if has_unseen_god and b._mate_tile != null and b._mate_tile.visible and b._draw_charge > 0:
		b._on_mate_tile()
		return
	if b._q_cur.is_empty() and not b._q_offer.is_empty():
		_log("[QUEST] L%d accept=%s" % [lv, str(b._q_offer.get("id", ""))])
		b._q_open_popup(); b._q_accept(); return
	if b._str_pending and b._aug_cards.size() > 0:
		if not b._str_layer.visible:
			b._open_aug_pick()
			return
		b._on_aug_card(b._aug_cards[0]); return
	if not restrict_strength and b._str_tile != null and b._str_tile.visible and b._wen >= b._str_cost():
		if b._str_lv >= 1 and b._wen >= b._str_batch_cost():
			b._str_batch_upgrade()
		else:
			b._on_str_tile()
		return
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

func _track_wave(now: float) -> void:
	if b == null or b._core == null:
		return
	var w := int(b._core.wave)
	if wave_cur.is_empty() or int(wave_cur.get("wave", 0)) != w:
		if not wave_cur.is_empty():
			wave_cur["cleared"] = now
			_log_wave(wave_cur)
			waves.append(wave_cur)
		wave_cur = {"wave": w, "start": now, "first_engage": -1.0, "last_spawn": -1.0,
			"cleared": -1.0, "boss_in": -1.0, "boss_out": -1.0,
			"normal_peak": 0, "reward_done": -1.0, "kinds": {}, "statues": 0}
		tracked_wave = w
	# 第一只怪进入交战区（与主角距离 <= 120）
	if float(wave_cur["first_engage"]) < 0.0:
		var hp: Vector2 = b._core.hero_pos
		for f in b._core.foes:
			if float(f.get("hp", 0.0)) <= 0.0 or bool(f.get("still", false)):
				continue
			var fp := Vector2(float(f.get("x", 0.0)), float(f.get("y", 0.0)))
			if fp.distance_to(hp) <= 120.0:
				wave_cur["first_engage"] = now
				break
	# 普通怪峰值 / 剩余种类 / 奖励怪也刷完
	var kinds := {}
	var normals := 0
	for f in b._core.foes:
		if float(f.get("hp", 0.0)) <= 0.0:
			continue
		var k := str(f.get("kind", "normal"))
		kinds[k] = int(kinds.get(k, 0)) + 1
		if k == "normal":
			normals += 1
	if normals > int(wave_cur["normal_peak"]):
		wave_cur["normal_peak"] = normals
	if not kinds.is_empty():
		wave_cur["kinds"] = kinds
	if int(wave_cur["statues"]) == 0 and b._core.has_method("statues_left") and b._core.statues_left() > 0:
		wave_cur["statues"] = b._core.statues_left()
		_log("[BREAK] L%d wave=%d statues=%d" % [lv, w, int(wave_cur["statues"])])
	# 本波刷怪完成
	if float(wave_cur["last_spawn"]) < 0.0 and b._core.wave_spawn_complete():
		wave_cur["last_spawn"] = now
	if float(wave_cur["last_spawn"]) >= 0.0 and float(wave_cur["reward_done"]) < 0.0:
		if int(b._core._queued_coin_foes) == 0 and int(b._core._queued_crystal_foes) == 0:
			wave_cur["reward_done"] = now
	# 首领入场 / 死亡
	if bool(b._core.boss_alive) and float(wave_cur["boss_in"]) < 0.0:
		wave_cur["boss_in"] = now
	if float(wave_cur["boss_in"]) >= 0.0 and not bool(b._core.boss_alive) and float(wave_cur["boss_out"]) < 0.0:
		wave_cur["boss_out"] = now
	if float(wave_cur["cleared"]) < 0.0 and b._core.wave_cleared():
		wave_cur["cleared"] = now
	_track_boss(now)

func _track_boss(now: float) -> void:
	if b == null or b._core == null or not bool(b._core.boss_alive):
		return
	var bf: Dictionary = b._core._boss_foe(false)
	if bf.is_empty():
		return
	var hp := float(bf.get("hp", 0.0))
	boss_max_seen = float(bf.get("hp_max", boss_max_seen))
	boss_hero_hp = float(b._core.hero.get("hp", 0.0))
	if boss_prev_hp >= 0.0 and hp < boss_prev_hp:
		boss_hits += 1
		boss_dmg += boss_prev_hp - hp
	boss_prev_hp = hp
	if boss_log_at < 0.0 or now - boss_log_at >= 1.0:
		boss_log_at = now
		_log("[BOSS] L%d t=%.1f hp=%.0f/%.0f hero=%.0f/%.0f hits=%d dmg=%.0f str_lv=%d cards=%d" % [
			lv, now, hp, float(bf.get("hp_max", 0.0)),
			float(b._core.hero.get("hp", 0.0)), float(b._core.hero.get("hp_max", 1.0)),
			boss_hits, boss_dmg, int(b._str_lv), b._cards.size()])

func _log_boss_end() -> void:
	if b == null or b._core == null:
		return
	var bf: Dictionary = b._core._boss_foe(false)
	var hp := float(bf.get("hp", 0.0)) if not bf.is_empty() else boss_prev_hp
	var hpm := float(bf.get("hp_max", 0.0)) if not bf.is_empty() else boss_max_seen
	_log("[BOSS_END] L%d t=%.1f boss_hp=%.0f/%.0f hits=%d dmg=%.0f hero_hp=%.0f/%.0f str_lv=%d cards=%d wave=%d" % [
		lv, t, hp, hpm, boss_hits, boss_dmg,
		boss_hero_hp if bf.is_empty() else float(b._core.hero.get("hp", 0.0)), float(b._core.hero.get("hp_max", 1.0)),
		int(b._str_lv), b._cards.size(), int(b._core.wave)])

func _finalize_wave(now: float, win: bool, timed_out: bool) -> void:
	if wave_cur.is_empty():
		return
	if timed_out or wave_cur["cleared"] is float and float(wave_cur["cleared"]) < 0.0:
		wave_cur["cleared"] = now
	waves.append(wave_cur)
	_log_wave(wave_cur)
	wave_cur = {}

func _log_wave(d: Dictionary) -> void:
	_log("[WAVE] L%d n=%d start=%.1f first_engage=%.1f last_spawn=%.1f reward_done=%.1f cleared=%.1f boss_in=%.1f boss_out=%.1f normal_peak=%d statues=%d kinds=%s" % [
		lv, int(d.get("wave", 0)), float(d.get("start", 0.0)), float(d.get("first_engage", -1.0)),
		float(d.get("last_spawn", -1.0)), float(d.get("reward_done", -1.0)), float(d.get("cleared", -1.0)),
		float(d.get("boss_in", -1.0)), float(d.get("boss_out", -1.0)),
		int(d.get("normal_peak", 0)), int(d.get("statues", 0)), str(d.get("kinds", {}))])

func _log_pace(total: float, win: bool) -> void:
	var spawn_wait := 0.0
	var engage := 0.0
	var clear_tail := 0.0
	var boss_fight := 0.0
	var after_boss := 0.0
	var span := 0.0
	var complete := win
	for d in waves:
		var start_t := float(d.get("start", 0.0))
		var fe := float(d.get("first_engage", -1.0))
		var ls := float(d.get("last_spawn", -1.0))
		var cl := float(d.get("cleared", -1.0))
		var bi := float(d.get("boss_in", -1.0))
		var bo := float(d.get("boss_out", -1.0))
		if fe < 0.0 or ls < 0.0 or cl < 0.0:
			complete = false
		var end_t := maxf(start_t, cl)
		var engaged_at := clampf(fe, start_t, end_t) if fe >= 0.0 else end_t
		var tail_start := clampf(ls, engaged_at, end_t) if ls >= 0.0 else end_t
		var boss_start := clampf(bi, tail_start, end_t) if bi >= 0.0 else end_t
		var boss_end := clampf(bo, boss_start, end_t) if bo >= 0.0 else end_t
		spawn_wait += engaged_at - start_t
		engage += tail_start - engaged_at
		clear_tail += boss_start - tail_start
		boss_fight += boss_end - boss_start
		after_boss += end_t - boss_end
		span += end_t - start_t
	if b != null and b._max_wave != null and waves.size() != int(b._max_wave):
		complete = false
	var seg_sum := spawn_wait + engage + clear_tail + boss_fight + after_boss
	_log("[PACE] L%d spawn_wait=%.1f engage=%.1f clear_tail=%.1f boss_fight=%.1f after_boss=%.1f span=%.1f seg_sum=%.1f drift=%.2f total=%.1f waves=%d/%d complete=%s" % [
		lv, spawn_wait, engage, clear_tail, boss_fight, after_boss, span, seg_sum, seg_sum - span, total, waves.size(),
		int(b._max_wave) if b != null else -1, str(complete)])

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
