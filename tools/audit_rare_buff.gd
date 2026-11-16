extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const GS := preload("res://shared/game_state.gd")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _reset(b, temp := 0.0) -> void:
	b._run_over = false
	b._rare_buffs.clear()
	b._rare_taken.clear()
	b._core.attr_set_base("atk", 100.0)
	b._core.attr["atk"]["temp"] = temp
	b._core.attr["atk"]["amp"] = 0.5
	b._core.hero["atk"] = b._core.attr_final("atk")
	b._core.hero["hp"] = b._core.hero["hp_max"]

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	var c = b._core
	c.set_process(false)
	_reset(b, 20.0)
	var rare := {"name": "狂血", "rare": true, "kind": "buff", "v": 60, "dur": 30.0}
	b._pick_trea(rare, 60)
	assert(c.hero["atk"] == 288.0 and c.attr["atk"]["temp"] == 92.0)
	b._pick_trea(rare, 60)
	assert(b._rare_buffs.size() == 1 and c.hero["atk"] == 288.0)
	b._sync_attrs_to_hero()
	assert(c.hero["atk"] == 288.0)
	b._apply_flat_growth(10.0, 0.0)
	b._apply_aug("atk_pct", 20.0) # 永久攻击增幅；家传dmg_pct属于本技能，不是全局攻击。
	assert(is_equal_approx(c.hero["atk"], 343.4))
	b._tick_rare_buffs(29.9)
	assert(is_equal_approx(c.hero["atk"], 343.4))
	b._tick_rare_buffs(0.11)
	assert(is_equal_approx(c.hero["atk"], 221.0) and c.attr["atk"]["temp"] == 30.0 and b._rare_buffs.is_empty())
	b._tick_rare_buffs(10.0)
	b._sync_attrs_to_hero()
	assert(is_equal_approx(c.hero["atk"], 221.0))
	# 两份不同快照/寿命独立到期；移除任一份不重算或吞掉其他来源。
	_reset(b)
	b._apply_rare_buff({"v": 60, "dur": 3.0})
	b._apply_rare_buff({"v": 10, "dur": 1.0})
	assert(c.hero["atk"] == 264.0)
	b._tick_rare_buffs(1.0)
	assert(c.hero["atk"] == 240.0 and b._rare_buffs.size() == 1)
	b._apply_flat_growth(10.0, 0.0)
	b._tick_rare_buffs(2.0)
	assert(c.hero["atk"] == 165.0 and b._rare_buffs.is_empty())
	# 真正外壳帧：增益到期应先于本帧自动技能。
	_reset(b, 20.0)
	GS.skill_lv["xiaoqier"] = 0
	c.attr_set_base("crit", 0.0)
	c.hero["lucky"] = 0.0
	c.foes.clear()
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": 10000.0, "hp_max": 1000.0, "shield": false, "x": c.hero_pos.x, "y": c.hero_pos.y - 40.0}, true)
	b._apply_rare_buff({"v": 60, "dur": 0.01})
	var sk: Dictionary = b.SKILL_DEFS["xiaoqier"].duplicate(true)
	sk.merge({"aid": "xiaoqier", "mp": 0.0, "cd_t": 0.0}, true)
	b._skills = [sk]
	b._process(0.02)
	assert(is_equal_approx(f["hp"], 9858.0) and b._rare_buffs.is_empty()) # 180×0.9−20=142。
	_reset(b)
	c.hero["hp"] = 0.0
	b._apply_rare_buff(rare)
	assert(c.hero["hp"] == 0.0 and c.hero["atk"] == 240.0) # 尚未结算的奖励可登记，但不能恢复气血。
	_reset(b)
	b._apply_rare_buff(rare)
	b._run_over = true
	var timer: float = b._rare_buffs[0]["t"]
	b._tick_rare_buffs(100.0)
	b._apply_rare_buff(rare)
	assert(b._rare_buffs.size() == 1 and b._rare_buffs[0]["t"] == timer and c.hero["atk"] == 240.0)
	b.queue_free()
	await process_frame
	print("PASS: rare attack snapshot units/unique grant/independent expiry; later growth retained; expiry precedes real skill tick; result/death boundaries")
	Audio.quit_cleanly()
