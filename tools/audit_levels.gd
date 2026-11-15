extends Control
# 单关验证：Boss 是否出现/被击杀、是否真正通关（_run_cleared）
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
var b = null
var t := 0.0
var cd := 0.0
var wait_draw := 0
var wait_trea := 0
var lv := 10
var boss_seen := false
var boss_name := "-"
var boss_spawned_wave := -1

func _ready() -> void:
	LS.ensure_loaded()
	var s := OS.get_environment("LV")
	if s != "":
		lv = int(s)
	LS.current_level = lv
	b = BATTLE.instantiate(); add_child(b)

func _process(dt: float) -> void:
	if b == null or b._core == null:
		return
	t += dt
	cd -= dt
	if b._tut != null and b._tut.visible:
		b._tut._on_pressed(); return
	if not boss_seen and b._core.boss_spawned_once:
		boss_seen = true
		boss_spawned_wave = int(b._core.wave)
		for f_v in b._core.foes:
			var f: Dictionary = f_v
			if bool(f.get("boss", false)):
				boss_name = str(f.get("bname", f.get("name", "?")))
				break
		if boss_name == "-":
			boss_name = "(已击杀)"
	if b._run_over:
		print("[V] L%d 结束 t=%.0fs win=%s wave=%d/%d kills=%d hp=%d/%d boss出现=%s@波%d 名字=%s boss_alive=%s" % [
			lv, t, str(b._run_cleared), int(b._core.wave), b._max_wave, int(b._kills),
			int(float(b._core.hero.get("hp", 0.0))), int(float(b._core.hero.get("hp_max", 1.0))),
			str(boss_seen), boss_spawned_wave, boss_name, str(b._core.boss_alive)])
		get_tree().quit(); return
	if wait_draw > 0:
		wait_draw -= 1
		if wait_draw == 0 and b._draw_layer != null and b._draw_layer.visible:
			if b._draw_cards.size() > 0 and not b._draw_cards[0].data.is_empty():
				b._on_draw_pick(b._draw_cards[0])
		return
	if wait_trea > 0:
		wait_trea -= 1
		if wait_trea == 0 and b._trea_layer != null and b._trea_layer.visible:
			if b._trea_cards.size() > 0:
				b._on_trea_card(b._trea_cards[0])
		return
	if cd <= 0.0:
		cd = 0.3
		if b._str_pending and b._aug_cards.size() > 0:
			b._on_aug_card(b._aug_cards[0])
		elif b._str_tile != null and b._str_tile.visible and b._wen >= b._str_cost():
			b._on_str_tile()
		elif b._trea_tile != null and b._trea_tile.visible and b._trea_charge > 0:
			b._on_trea_tile()
			if b._trea_layer != null and b._trea_layer.visible:
				wait_trea = 8
		elif b._draw_tile != null and b._draw_tile.visible and b._crystal >= 20 and not b._pool.is_empty():
			b._show_draw(true)
			if b._draw_layer != null and b._draw_layer.visible:
				wait_draw = 8
	if t > 420.0:
		print("[V] L%d 超时 t=%.0fs wave=%d/%d boss出现=%s" % [lv, t, int(b._core.wave), b._max_wave, str(boss_seen)])
		get_tree().quit()
