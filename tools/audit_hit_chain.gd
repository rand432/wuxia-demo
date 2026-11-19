extends SceneTree
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")
const Token := preload("res://kushou/token_actor.gd")
class BattleProbe extends "res://kushou/battle_ui.gd":
	var hit_effects := 0
	func _spawn_hit_fx(_p: Vector2, _r: float, _d: int, _h: bool, _c: bool, _heavy: bool) -> void:
		hit_effects += 1

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
	LS.ensure_loaded()
	LS.current_level = 8
	for source in ["mirror", "sword", "splash"]:
		for mode in ["normal", "result", "epoch", "dead", "stopped", "removed"]:
			var b := BattleProbe.new()
			root.add_child(b)
			b.set_process(false)
			var c = b._core
			c.set_process(false)
			c.foes.clear()
			c.kill.disconnect(b._on_core_kill)
			c.kill_heal = 0.0
			c.hero["atk"] = 100.0
			c.hero["hp"] = 100.0
			c.hero["hp_max"] = 1000.0
			c.attr_set_base("crit", 0.0)
			c.hero["lucky"] = 0.0
			c._heavy = 0
			var target := _foe(c, 1000.0 if source == "splash" else 90.0)
			var first := _foe(c, 1.0 if source == "splash" else 1000.0)
			var other := _foe(c, 1000.0)
			target["_tid"] = 42
			var token := Token.new()
			b.add_child(token)
			b._foe_tokens[42] = token
			b._bm.slots = [{"name": "断岳刀"}, {"name": "朱雀羽"}]
			if source == "sword": b._bm.slots.append({"name": "赤霄剑"})
			if source == "mirror":
				b._curio_id = "tongjing"
				b._curio_lv = 5
				b._curio_cd = 0.0
				b._curio_tick_tongjing()
			var kills: int = c.kills_total
			var resolved := [0]
			c.hero_strike_resolved.connect(func(_f): resolved[0] += 1)
			c.kill.connect(func(_n):
				if mode == "result": b._end_run(false)
				elif mode == "epoch": c.clear_enemy_attacks() # 故意保留目标，验证原信号批次。
				elif mode == "dead": c.hero["hp"] = 0.0
				elif mode == "stopped": c.running = false
				elif mode == "removed": c.foes.erase(other))
			# 末尾另测确定的暴击通知，保留真实主刀伤害与监听顺序，避免概率使灼烧断言空过。
			c.hero_foe_hit.connect(func(f, d, _crit, heavy):
				var equipment: Array = b._bm.slots
				b._bm.slots = [{"name": "朱雀羽"}]
				b._bm._on_hero_foe_hit(f, d, true, heavy)
				b._bm.slots = equipment)
			c._hero_strike(target)
			assert(c.kills_total == kills + 1 and c._hero_hit_epoch == -1)
			assert((first if source == "splash" else target).get("_death_settled", false))
			if mode in ["normal", "removed"]:
				assert(other["hp"] == (996.0 if mode == "normal" else 1000.0))
				assert(b.hit_effects == 1 and resolved[0] == 1)
				assert(target.get("burn", 0.0) == (1.0 if source == "splash" else 0.0))
			else:
				assert(other["hp"] == 1000.0 and b.hit_effects == (0 if source == "mirror" else 1) and resolved[0] == 0)
				assert(not target.has("burn"))
			b.queue_free()
			await process_frame
	print("PASS: native main hit -> mirror/sword/splash immediate kills; later signal listeners retain original epoch; no stale FX, burn or damage; removed splash targets skipped")
	Audio.quit_cleanly()
