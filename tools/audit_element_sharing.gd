extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const AttrPanel := preload("res://kushou/attr_panel.gd")
const AD := preload("res://kushou/ancestor_data.gd")
const GS := preload("res://shared/game_state.gd")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _cast(b, f: Dictionary, aid: String, expected: float) -> void:
	var sk: Dictionary = b.SKILL_DEFS[aid].duplicate(true)
	sk.merge({"aid": aid, "mp": 0.0, "cd_t": 0.0}, true)
	b._skills = [sk]
	f["hp"] = 10000.0
	b._cast_skill(0)
	assert(is_equal_approx(f["hp"], 10000.0 - expected))

func _heal(b, f: Dictionary, expected: float) -> void:
	var sk: Dictionary = b.SKILL_DEFS["liuqingqing"].duplicate(true)
	sk.merge({"aid": "liuqingqing", "mp": 0.0, "cd_t": 0.0}, true)
	b._skills = [sk]
	b._core.hero["hp"] = 100.0
	f["hp"] = 10000.0
	b._cast_skill(0)
	assert(f["hp"] == 10000.0 and is_equal_approx(b._core.hero["hp"], 100.0 + expected))

func _run() -> void:
	seed(20261124)   # 用例依赖随机刷怪类型；固定随机序列避免偶发误报
	LS.ensure_loaded()
	LS.current_level = 9
	GS.skill_lv = {}
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	var c = b._core
	c.set_process(false)
	c.attr_set_base("hp", 1000.0)
	c.attr_set_base("atk", 100.0)
	c.attr["atk"]["temp"] = 0.0
	c.attr["atk"]["amp"] = 0.0
	c.attr_set_base("crit", 0.0)
	c.hero["lucky"] = 0.0
	b._sync_attrs_to_hero()
	c.foes.clear()
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": 10000.0, "hp_max": 1000.0, "res_metal": 0.0, "res_wood": 0.0, "res_water": 0.0, "res_earth": 0.0, "vuln_pct": 0.0, "wood_vuln": 0.0, "res_fire": 0.0, "shield": false, "x": c.hero_pos.x, "y": c.hero_pos.y - 40.0}, true)
	for aid in ["liuqingqing", "chenshi"]:
		b._add_ancestor_effects(aid, AD.ANCESTORS[aid]["tiers"][0]["effects"])
		b._add_ancestor_effects(aid, AD.ANCESTORS[aid]["tiers"][4 if aid == "liuqingqing" else 3]["effects"])
	assert(c.hero["atk"] == 100.0)
	assert(is_equal_approx(c.type_amp("木系"), 0.15) and is_equal_approx(c.type_amp("真实"), 0.15))
	_heal(b, f, 270.0) # 医疗版：100×2×(1+治疗20%+木共享15%)，不直接扣血。
	_cast(b, f, "chenshi", 193.2) # 100×1.4×本技能1.2×真实共享1.15。
	_cast(b, f, "xiaoqier", 70.0)
	var panel := AttrPanel.new()
	root.add_child(panel)
	panel.setup(c)
	panel.tab = panel.TYPES.find("木系")
	assert(is_equal_approx(panel._type_f("amp"), 0.15))
	panel.tab = panel.TYPES.find("真实")
	assert(is_equal_approx(panel._type_f_raw("真实", "amp_f"), 0.15))
	# 明烛的另一份木系共享和真实聚灯命中只吃一次类型层。
	b._add_ancestor_effects("mingzhu", {"elem_pct": {"木系": 15.0}, "pull": 1})
	b._mingzhu = true
	b._aura_pull_acc = 0.0
	f["hp"] = 10000.0
	var chosen_seed := -1
	for candidate in range(1, 101):
		seed(candidate)
		if randf() < 0.20:
			chosen_seed = candidate
			break
	assert(chosen_seed > 0)
	seed(chosen_seed)
	b._tick_aura(1.0)
	assert(is_equal_approx(f["hp"], 9980.5)) # 100×15%×木共享1.3。
	# 标量毒的兼容入口同样不再预乘共享；正常医疗版的独立层由medical_roster验证。
	f["hp"] = 10000.0
	f["poison"] = 1.0
	f["poison_acc"] = 0.0
	f["poison_t"] = 4.0
	b._tick_poison(1.0)
	assert(is_equal_approx(f["hp"], 9961.0))
	# 封印火系的保留直伤/灼烧函数同样兼容统一层，不解封角色。
	b._add_ancestor_effects("jicanghai", {"elem_pct": {"火系": 15.0}})
	f["hp"] = 10000.0
	b._cast_fire()
	assert(is_equal_approx(f["hp"], 9931.0))
	f["burn_acc"] = 0.0
	b._tick_burn(1.0)
	assert(is_equal_approx(f["hp"], 9917.2))
	# 所有七种面板类型都登记；召唤仍保留独立旧路径。
	for type in c.DMG_TYPES:
		b._add_ancestor_effects("__audit", {"elem_pct": {type: 300.0}})
		assert(c.type_amp(type) == 2.0 and c.hero_out_dmg(100.0, type, 0)["dmg"] == 300.0)
	b._add_ancestor_effects("cuisanniang", {"elem_pct": {"召唤": 15.0}})
	assert(b._elem_mod["召唤"] == 15.0 and c.type_amp("召唤") == 0.0)
	assert(not LS.god_ids().has("jicanghai") and not LS.god_ids().has("cuisanniang") and not LS.god_ids().has("liuqingqing2"))
	assert(not b._ancestors.has("jicanghai") and not b._ancestors.has("liuqingqing2"))
	_heal(b, f, 640.0)
	_cast(b, f, "chenshi", 504.0)
	f["hp"] = 10000.0
	c.reflect_damage(f, 10.0)
	assert(f["hp"] == 9990.0) # 已约定的精确反射不再吃一遍真实增幅。
	assert(c.apply_echo_damage(f, 10.0) == 10.0 and f["hp"] == 9980.0)
	panel.queue_free()
	b.queue_free()
	await process_frame
	print("PASS: wood/true sharing and panel agree; aura/poison/fire apply once; seven-type cap; summon path and sealed roster preserved")
	Audio.quit_cleanly()
