extends SceneTree
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")
const Audio := preload("res://shared/audio.gd")
class Probe extends "res://kushou/battle_ui.gd":
	var lines := 0
	func _feiren_line(origin: Vector2, d: Vector2, base: float, pierce: int, volley: bool, vmul: float) -> void:
		lines += 1
		super._feiren_line(origin, d, base, pierce, volley, vmul)

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _battle():
	LS.ensure_loaded()
	LS.current_level = 6
	GS.skill_lv = {}
	var b := Probe.new()
	root.add_child(b)
	b.set_process(false)
	b._core.set_process(false)
	b._core.foes.clear()
	b._core.attr_set_base("crit", 0.0)
	b._core.hero["lucky"] = 0.0
	b._core.hero["atk"] = 100.0
	b._core.kill_heal = 0.0
	return b

func _foe(c, distance: float, hp: float) -> Dictionary:
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": hp, "hp_max": 1000.0, "shield": false, "x": c.hero_pos.x, "y": c.hero_pos.y - distance}, true)
	return f

func _run() -> void:
	for phase in ["out", "return"]:
		for mode in ["normal", "result", "epoch", "dead", "stopped", "removed"]:
			var b = _battle()
			var c = b._core
			var primary := _foe(c, 20.0, 1.0 if phase == "out" else 1000.0)
			var other := _foe(c, 40.0, 1000.0 if phase == "out" else 100.0)
			var killed: Dictionary = primary if phase == "out" else other
			var remaining: Dictionary = other if phase == "out" else primary
			var replacement: Array = []
			var kills: int = b._kills
			var money: int = b._wen
			b._wanren = true
			c.kill.connect(func(_n):
				c._kill_foe(killed)
				if mode == "result": b._end_run(false)
				elif mode == "dead": c.hero["hp"] = 0.0
				elif mode == "stopped": c.running = false
				elif mode == "removed": c.foes.erase(remaining)
				elif mode == "epoch":
					c.clear_enemy_attacks()
					c.foes.clear()
					replacement.append(_foe(c, 40.0, 1000.0)))
			b._feiren_line(c.hero_pos, Vector2.UP, 100.0, 2, true, 1.0)
			assert(killed.get("_death_settled", false) and b._kills == kills + 1 and b._wen > money)
			var expected := 840.0 if mode == "normal" else (1000.0 if phase == "out" else 920.0)
			assert(is_equal_approx(remaining["hp"], expected))
			if mode == "epoch": assert(replacement[0]["hp"] == 1000.0)
			if mode in ["result", "epoch", "dead", "stopped"] and phase == "out":
				assert(b._wanren_volleys == 0 and b._wanren_pierce == 0)
			c._kill_foe(killed)
			assert(b._kills == kills + 1)
			b.queue_free()
			await process_frame
	# 多刀外层也保留最初批次，不能在下一刀对新一波重新取目标。
	var b = _battle()
	var c = b._core
	var primary := _foe(c, 20.0, 1.0)
	b._anc_mod["qingluan"] = {"knife": 2, "pierce": 1, "volley": 1}
	var sk: Dictionary = b.SKILL_DEFS["qingluan"].duplicate(true)
	sk.merge({"aid": "qingluan", "cd_t": 0.0}, true)
	b._skills = [sk]
	b._mp = 100.0
	var replacement: Array = []
	c.kill.connect(func(_n):
		c.clear_enemy_attacks()
		c.foes.clear()
		replacement.append(_foe(c, 40.0, 1000.0)))
	b._cast_skill(0)
	assert(primary.get("_death_settled", false) and b.lines == 1 and replacement[0]["hp"] == 1000.0)
	assert(b._mp == 10.0 and sk["cd_t"] > 0.0)
	b.queue_free()
	await process_frame
	# 不死首领在去程复活，回程仍可打到复活后的同一目标，不提前发击杀。
	b = _battle(); c = b._core
	primary = _foe(c, 20.0, 1.0)
	primary["boss_revive"] = 1
	var kills: int = b._kills
	b._feiren_line(c.hero_pos, Vector2.UP, 100.0, 1, true, 1.0)
	assert(primary["boss_revive"] == 0 and primary["hp"] == 420.0 and not primary.get("_death_settled", false) and b._kills == kills)
	c.running = false
	var lines: int = b.lines
	b._cast_feiren(1.2)
	b._feiren_line(c.hero_pos, Vector2.UP, 100.0, 1, true, 1.0)
	assert(primary["hp"] == 420.0 and b.lines == lines + 1)
	b.queue_free()
	await process_frame
	print("PASS: blade outbound/return settle once; callback boundaries and removed targets; multi-knife epoch/cost; boss revive preserved")
	Audio.quit_cleanly()
