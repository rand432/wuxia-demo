extends SceneTree
const Core := preload("res://kushou/kushou_battle.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _foe(c, hp: float) -> Dictionary:
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": hp, "hp_max": 1000.0, "shield": false, "x": c.hero_pos.x, "y": c.hero_pos.y - 40.0}, true)
	return f

func _run() -> void:
	for event in ["hit", "kill"]:
		for mode in ["stopped", "epoch", "dead"]:
			var c := Core.new()
			root.add_child(c)
			c.set_process(false)
			c.setup({"atk": 100.0, "hp_max": 1000.0})
			c.start_run()
			c.attr_set_base("crit", 0.0)
			c.hero["lucky"] = 0.0
			c.hero["hp"] = 100.0
			c.hero["mech_lifesteal"] = 0.1
			c.kill_heal = 0.0
			c.skill["splash"] = 1
			var primary := _foe(c, 10.0 if event == "kill" else 1000.0)
			var other := _foe(c, 1000.0)
			var replacement: Array = []
			var hits := [0]
			var resolved := [0]
			var invalidate := func():
				if mode == "stopped": c.running = false
				elif mode == "dead": c.hero["hp"] = 0.0
				else:
					c.clear_enemy_attacks()
					c.foes.clear()
					replacement.append(_foe(c, 1000.0))
			c.hero_foe_hit.connect(func(_f, _d, _crit, _heavy):
				hits[0] += 1
				if event == "hit": invalidate.call())
			c.kill.connect(func(_n):
				if event == "kill": invalidate.call())
			c.hero_strike_resolved.connect(func(_f): resolved[0] += 1)
			c._hero_strike(primary)
			assert(other["hp"] == 1000.0 and hits[0] == 1 and resolved[0] == 0)
			assert(c.hero["hp"] == (0.0 if mode == "dead" else 100.0))
			assert(c._hero_step == 0.0 and c._slashes.is_empty())
			if event == "kill": assert(primary.get("_death_settled", false) and c.kills_total == 1)
			else: assert(primary["hp"] == 920.0)
			if mode == "epoch": assert(replacement.size() == 1 and replacement[0]["hp"] == 1000.0)
			else:
				var heavy_before: int = c._heavy
				c._hero_strike(other)
				assert(other["hp"] == 1000.0 and c._heavy == heavy_before and hits[0] == 1)
			c.queue_free()
			await process_frame
	print("PASS: main-hit/kill callbacks stop splash, lifesteal, animation and resolved signal after stop/death/clear; new-wave foes untouched")
	Audio.quit_cleanly()
