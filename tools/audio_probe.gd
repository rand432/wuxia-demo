extends SceneTree
const Iso := preload("res://tools/test_isolation.gd")
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")
const Audio := preload("res://shared/audio.gd")

var b = null
var t := 0.0
var phase := 0
var timer := 0.0
var boss_done := false
var skill_t := 0.0
var prime_t := 0.0
var click_sent := false
var dismissed := false

func _initialize() -> void:
	var iso_err := Iso.verify()
	if iso_err != "":
		print("[ISOLATION] REJECT " + iso_err)
		quit(2)
		return
	seed(20261116)
	LS.ensure_loaded()
	LS.current_level = 6
	GS.ensure_loaded()
	Audio.reset_sfx_stats()
	_begin_probe.call_deferred()

func _begin_probe() -> void:
	b = BATTLE.instantiate()
	root.add_child(b)
	_dismiss()
	b._draw_charge = maxi(1, b._draw_charge)
	b._pick_god("liuqingqing")

func _dismiss() -> void:
	if b == null:
		return
	var tut = b.get("_tut")
	if tut != null:
		tut.cancel()
		tut.queue_free()
		b.set("_tut", null)
	if b.has_method("_tutorial_pause"):
		b._tutorial_pause(false)
	b.set_process(true)
	if b._core != null:
		b._core.set_process(true)
		b._core.hero["hp_max"] = 1000000.0
		b._core.hero["hp"] = 1000000.0

func _process(dt: float) -> bool:
	if b != null and b._core != null:
		if float(b._core.hero.get("hp", 0.0)) < 900000.0:
			b._core.hero["hp"] = float(b._core.hero["hp_max"])
	t += dt
	match phase:
		0:
			if not dismissed and t > 0.4:
				dismissed = true
				_dismiss()
			if b != null and b._core != null and not b._core.is_processing():
				b._core.set_process(true)
				b.set_process(true)
			_prime(dt)
			if not click_sent and t > 1.5:
				click_sent = true
				Audio.sfx("ui_click", -10.0)
			if t >= 20.0:
				print("[STATE] wave=" + str(b._core.wave) + " kills=" + str(b._kills) + " foes=" + str(b._core.foes.size()) + " core_proc=" + str(b._core.is_processing()) + " b_proc=" + str(b.is_processing()) + " over=" + str(b._run_over))
				print("[AUDIO] battle " + JSON.stringify(Audio.sfx_stats()))
				print("[AUDIO] pool_after_battle_active=" + str(Audio._sfx_active.size()) + " pool=" + str(Audio._sfx_pool.size()))
				if b != null:
					b.queue_free()
					b = null
				phase = 1
				timer = 0.0
		1:
			timer += dt
			if timer >= 2.0:
				print("[AUDIO] recovery active=" + str(Audio._sfx_active.size()) + " pool=" + str(Audio._sfx_pool.size()) + " last_gap_keys=" + str(Audio._last_sfx_msec.size()))
				Audio.reset_sfx_stats()
				Audio.play_menu_music()
				phase = 2
				timer = 0.0
		2:
			timer += dt
			if timer >= 1.2:
				print("[MUSIC] menu context=" + str(Audio._music_context) + " cur=" + str(Audio._cur_bgm) + " a_playing=" + str(Audio._bgm_a != null and Audio._bgm_a.playing) + " b_playing=" + str(Audio._bgm_b != null and Audio._bgm_b.playing))
				Audio.play_battle_music()
				phase = 3
				timer = 0.0
		3:
			timer += dt
			if timer >= 1.2:
				print("[MUSIC] battle context=" + str(Audio._music_context) + " cur=" + str(Audio._cur_bgm) + " a_playing=" + str(Audio._bgm_a != null and Audio._bgm_a.playing) + " b_playing=" + str(Audio._bgm_b != null and Audio._bgm_b.playing))
				Audio.play_battle_music()
				Audio.play_menu_music()
				phase = 4
				timer = 0.0
		4:
			timer += dt
			if timer >= 1.5:
				print("[MUSIC] back context=" + str(Audio._music_context) + " cur=" + str(Audio._cur_bgm))
				print("[AUDIO] final " + JSON.stringify(Audio.sfx_stats()))
				quit(0)
	return false

func _prime(dt: float) -> void:
	if b == null or b._core == null:
		return
	prime_t -= dt
	if prime_t <= 0.0:
		prime_t = 0.05
		if b._core.foes.size() < 30:
			b._core._spawn_foe("normal", 1.0, 1.0)
		elif not boss_done and t > 4.0:
			boss_done = true
			b._core.start_boss(LS.boss_tier(), "")
	skill_t -= dt
	if skill_t <= 0.0:
		skill_t = 2.0
		if b._skills.size() > 0:
			b._cast_skill(0)
