extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const AD := preload("res://kushou/ancestor_data.gd")
const GS := preload("res://shared/game_state.gd")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

class FeirenProbe extends "res://kushou/battle_ui.gd":
	var captured := 0.0
	func _feiren_line(_origin: Vector2, _d: Vector2, base: float, _pierce: int, _volley: bool, _vmul: float) -> void:
		captured = base

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _basic(c, f: Dictionary, expected: float) -> void:
	f["hp"] = 10000.0
	c._heavy = 0
	c._hero_strike(f)
	assert(is_equal_approx(f["hp"], 10000.0 - expected))

func _cast(b, f: Dictionary, aid: String, expected: float) -> void:
	var sk: Dictionary = b.SKILL_DEFS[aid].duplicate(true)
	sk.merge({"aid": aid, "mp": 0.0, "cd_t": 0.0}, true)
	b._skills = [sk]
	f["hp"] = 10000.0
	b._cast_skill(0)
	assert(is_equal_approx(f["hp"], 10000.0 - expected))

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 7
	GS.skill_lv = {}
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	var c = b._core
	c.set_process(false)
	c.attr_set_base("atk", 100.0)
	c.attr_set_base("hp", 1000.0)
	c.attr_set_base("crit", 0.0)
	c.hero["lucky"] = 0.0
	b._sync_attrs_to_hero()
	c.foes.clear()
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": 10000.0, "hp_max": 1000.0, "res_wood": 0.0, "shield": false, "x": c.hero_pos.x, "y": c.hero_pos.y - 40.0}, true)
	_basic(c, f, 80.0)
	var own: Dictionary = AD.ANCESTORS["zhujue"]["tiers"][0]["effects"]
	b._add_ancestor_effects("zhujue", own)
	b._apply_hero_passive(own)
	assert(c.hero["atk"] == 100.0 and c.attr_final("atk") == 100.0)
	_basic(c, f, 100.0) # 本技能+20%，100×1.2−20。
	_cast(b, f, "xiaoqier", 70.0)
	_cast(b, f, "liuqingqing", 120.0)
	_cast(b, f, "chenshi", 140.0)
	var shared := {"elem_pct": {"物理": 15.0}}
	b._add_ancestor_effects("zhujue", shared)
	b._apply_hero_passive(shared)
	assert(c.hero["atk"] == 100.0 and is_equal_approx(c.type_amp("物理"), 0.15))
	_basic(c, f, 118.0)
	_cast(b, f, "xiaoqier", 83.5) # 90×1.15−20，只应用一次物理共享。
	_cast(b, f, "liuqingqing", 120.0)
	_cast(b, f, "chenshi", 140.0)
	b._add_ancestor_effects("qingluan", shared)
	assert(is_equal_approx(c.type_amp("物理"), 0.30))
	_cast(b, f, "xiaoqier", 97.0)
	_basic(c, f, 136.0)
	var probe := FeirenProbe.new()
	probe._core = c
	probe._anc_mod = b._anc_mod
	probe._elem_mod = b._elem_mod
	probe._cast_feiren(1.2)
	assert(probe.captured == 120.0) # 飞刃不在进入统一管线前再吃一次共享。
	probe.free()
	assert(is_equal_approx(b._ram_damage(), 60.0))
	GS.skill_lv["zhujue"] = 10
	b._sync_attrs_to_hero()
	assert(c.hero["atk"] == 100.0 and is_equal_approx(c.basic_attack_multiplier(), 1.4))
	_basic(c, f, 162.0)
	GS.skill_lv["zhujue"] = 0
	b._sync_attrs_to_hero()
	b._add_ancestor_effects("gundilong", {"elem_pct": {"物理": 300.0}})
	assert(c.type_amp("物理") == 2.0)
	_basic(c, f, 340.0)
	_cast(b, f, "liuqingqing", 120.0)
	_cast(b, f, "chenshi", 140.0)
	# 家传羁绊完成回调也要同帧同步专属倍率，不能等下一帧补回。
	c.type_attr["物理"]["amp_f"] = 0.3
	b._ancestor_combos = [{"name": AD.ANCESTORS["zhujue"]["tiers"][0]["combo_name"]}, {"name": AD.ANCESTORS["gundilong"]["tiers"][0]["combo_name"]}]
	b._bonds = [b.BOND_POOL.filter(func(o): return o["name"] == "剑棍同源")[0].duplicate(true)]
	b._bond_check()
	assert(is_equal_approx(c.hero["basic_family_bonus"], 0.6) and c.hero["atk"] == 100.0)
	_basic(c, f, 188.0)
	b.queue_free()
	await process_frame
	print("PASS: owner-only sword damage; physical sharing once across basic/generic/blade/ram; wood/true isolated; 200% cap")
	Audio.quit_cleanly()
