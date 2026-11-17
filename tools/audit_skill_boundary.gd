extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")
const Audio := preload("res://shared/audio.gd")
class FreeProbe extends "res://kushou/battle_ui.gd":
	func _roll_skill_free_cast() -> bool: return true

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _battle(free := false):
	LS.ensure_loaded()
	LS.current_level = 6
	GS.skill_lv = {}
	var b = FreeProbe.new() if free else Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	var c = b._core
	c.set_process(false)
	c.foes.clear()
	c.attr_set_base("crit", 0.0)
	c.hero["atk"] = 100.0
	c.hero["lucky"] = 0.0
	c.kill_heal = 0.0
	b._curio_id = ""
	return b

func _foe(c, distance: float, hp: float) -> Dictionary:
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": hp, "hp_max": 1000.0, "res_wood": 0.0, "shield": false, "x": c.hero_pos.x, "y": c.hero_pos.y - distance}, true)
	return f

func _skill(b, aid: String) -> Dictionary:
	var sk: Dictionary = b.SKILL_DEFS[aid].duplicate(true)
	sk.merge({"aid": aid, "cd_t": 0.0}, true)
	return sk

func _run() -> void:
	for aid in ["chenshi", "xiaoqier"]:
		for mode in ["normal", "result", "epoch", "dead", "stopped", "removed"]:
			var b = _battle()
			var c = b._core
			var primary := _foe(c, 20.0, 1.0)
			var other := _foe(c, 40.0, 1000.0)
			var sk := _skill(b, aid)
			b._anc_mod[aid] = {"tgt_add": 1, "para_s": 1.0}
			b._skills = [sk]
			b._mp = 1000.0
			var kills: int = b._kills
			var money: int = b._wen
			var replacement: Array = []
			c.kill.connect(func(_n):
				c._kill_foe(primary) # 重入不能再发奖励。
				if mode == "result": b._end_run(false)
				elif mode == "dead": c.hero["hp"] = 0.0
				elif mode == "stopped": c.running = false
				elif mode == "removed": c.foes.erase(other)
				elif mode == "epoch":
					c.clear_enemy_attacks()
					c.foes.clear()
					replacement.append(_foe(c, 40.0, 1000.0)))
			b._cast_skill(0)
			assert(primary.get("_death_settled", false) and b._kills == kills + 1 and b._wen > money)
			assert(b._mp == 1000.0 - sk["mp"] and sk["cd_t"] > 0.0)
			if mode == "normal":
				var damage := 140.0 if aid == "chenshi" else 70.0
				assert(is_equal_approx(other["hp"], 1000.0 - damage) and other["para"] == 1.0)
			else:
				assert(other["hp"] == 1000.0 and float(other.get("para", 0.0)) == 0.0)
				if mode == "epoch": assert(replacement[0]["hp"] == 1000.0)
				elif mode in ["result", "dead", "stopped"]:
					sk["cd_t"] = 0.0
					var mana: float = b._mp
					b._cast_skill(0)
					b._tick_skills(1.0)
					assert(b._mp == mana and sk["cd_t"] == 0.0 and other["hp"] == 1000.0)
			c._kill_foe(primary)
			assert(b._kills == kills + 1)
			b.queue_free()
			await process_frame
	# 自动施法同一批：第一招致死回调清场，下一招不扣内力、不启动CD。
	for free in [false, true]:
		var b = _battle(free)
		var c = b._core
		var primary := _foe(c, 20.0, 1.0)
		var first := _skill(b, "chenshi")
		var second := _skill(b, "xiaoqier")
		second["mp"] = 0.0
		b._skills = [first, second]
		b._mp = 17.0 if free else 100.0
		if free:
			b._curio_id = "dingfengzhu"
			b._curio_lv = 5
		var replacement: Array = []
		c.kill.connect(func(_n):
			c.clear_enemy_attacks()
			c.foes.clear()
			replacement.append(_foe(c, 40.0, 1000.0)))
		b._tick_skills(0.0)
		assert(primary.get("_death_settled", false) and replacement[0]["hp"] == 1000.0)
		assert(first["cd_t"] > 0.0 and second["cd_t"] == 0.0 and b._mp == (17.0 if free else 10.0))
		assert(b._curio_mana_regen_left == 0.0) # 中止后不再启动后续回蓝特效，免费施法临时内力已还原。
		b.queue_free()
		await process_frame
	print("PASS: two current direct skills settle kills once; normal damage/cost preserved; result/death/stop/clear halt old targets and automatic cast batch")
	Audio.quit_cleanly()
