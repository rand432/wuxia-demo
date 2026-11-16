extends SceneTree
const Core := preload("res://kushou/kushou_battle.gd")
const Audio := preload("res://shared/audio.gd")
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _target(extra: Dictionary = {}) -> Dictionary:
	var f := {"hp": 10000.0, "hp_max": 1000.0, "x": 352.0, "y": 568.0, "res_fire": 0.30}
	f.merge(extra, true)
	return f

func _hit(core, type: String, expected: float, extra: Dictionary = {}) -> void:
	var f := _target(extra)
	var damage: float = core._apply_dmg(f, 100.0, type, 0)
	assert(is_equal_approx(damage, expected), "%s %s: got=%s expected=%s" % [type, extra, damage, expected])
	assert(is_equal_approx(f["hp"], 10000.0 - expected))
	assert(f["last_dtype"] == type)

func _run() -> void:
	var core := Core.new()
	root.add_child(core)
	core.set_process(false)
	core.setup({"atk": 100.0, "hp_max": 1000.0, "mp_max": 100.0})
	core.attr_set_base("crit", 0.0)
	_hit(core, "物理", 80.0)
	_hit(core, "物理", 84.0, {"armor_break_t": 5.0})
	_hit(core, "物理", 100.0, {"armor_break_t": 5.0, "hp_max": 0.0})
	_hit(core, "火系", 70.0, {"armor_break_t": 5.0})
	# 保留重甲原本替代普通护甲的常规伤害规则，不在此轮重新设计首领强度。
	_hit(core, "物理", 60.0, {"boss_cut": 0.40})
	_hit(core, "火系", 60.0, {"boss_cut": 0.40})
	_hit(core, "物理", 44.0, {"shield": true})
	core.hero_pos.y = 500.0
	_hit(core, "物理", 80.0, {"shield": true})
	core.hero_pos.y = 608.0
	var f := _target({"armor_break_t": 5.0})
	core.foes.append(f)
	core._buffs_tick(5.0)
	assert(is_equal_approx(core._apply_dmg(f, 100.0, "物理", 0), 80.0))
	core.foes.clear()
	core.type_add("物理", "pen_f", 0.05)
	_hit(core, "物理", 89.0, {"armor_break_t": 5.0})
	core.type_attr["物理"]["pen_f"] = 0.0
	# 真实只吃自己的增幅，逐个及组合修饰都不能把它变成可格挡/可减伤的伤害。
	core.type_add("真实", "amp_f", 0.50)
	for extra in [{"armor_break_t": 5.0}, {"shield": true}, {"boss_cut": 0.4}, {"buff": 2.0}, {"cold_dmg": 0.25, "cold_freeze_t": 1.0}, {"wood_t": 1.0, "wood_vuln": 0.5}]:
		_hit(core, "真实", 150.0, extra)
	core.hero["drunk_t"] = 5.0
	core.hero["drunk_atk"] = 0.25
	core.foe_vuln = 0.20
	var combined := {"armor_break_t": 5.0, "shield": true, "boss_cut": 0.4, "buff": 2.0, "cold_dmg": 0.25, "cold_freeze_t": 1.0, "wood_t": 1.0, "wood_vuln": 0.5}
	_hit(core, "真实", 150.0, combined)
	assert(not core._last_crit and not core._last_lucky)
	# 常规伤害仍应用酒气/易伤/格挡/石像/寒玉/惊堂木，各一次。
	combined.erase("armor_break_t")
	combined.erase("boss_cut")
	_hit(core, "物理", 103.95, combined)
	core.queue_free()
	await process_frame
	# 当前接入技能与家传碎裂的UI入口，也不能提前乘入通用易伤。
	LS.ensure_loaded()
	LS.current_level = 6
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	b._core.set_process(false)
	b._core.foes.clear()
	b._core._spawn_foe()
	var victim: Dictionary = b._core.foes.back()
	victim.merge(_target({"shield": true, "boss_cut": 0.4, "buff": 2.0, "cold_dmg": 0.25, "cold_freeze_t": 1.0, "wood_t": 1.0, "wood_vuln": 0.5, "vuln_t": 5.0, "vuln_pct": 100.0}), true)
	b._core.hero["atk"] = 100.0
	b._core.hero["def"] = 100.0
	b._core.hero["drunk_t"] = 5.0
	b._core.hero["drunk_atk"] = 0.25
	b._core.foe_vuln = 0.20
	b._core.type_add("真实", "amp_f", 0.5)
	GS.skill_lv["chenshi"] = 0
	b._anc_mod = {}
	b._elem_mod = {}
	var skill: Dictionary = b.SKILL_DEFS["chenshi"].duplicate(true)
	skill["aid"] = "chenshi"
	skill["cd_t"] = 0.0
	b._skills = [skill]
	b._mp = 200.0
	b._cast_skill(0)
	assert(is_equal_approx(victim["hp"], 9790.0) and b._mp == 110.0) # 100×1.4×1.5。
	victim["hp"] = 10000.0
	b._stone_shatter()
	assert(is_equal_approx(victim["hp"], 9775.0)) # 防御100×1.5×真实增幅1.5，不乘通用易伤。
	b.queue_free()
	await process_frame
	print("PASS: armor break reduces physical armor before penetration; normal blocks/heavy armor retained; true modifier isolation")
	Audio.quit_cleanly()
