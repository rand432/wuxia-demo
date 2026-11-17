extends SceneTree
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")
const AD := preload("res://kushou/ancestor_data.gd")
const Menu := preload("res://menu/partner_home.gd")
const Audio := preload("res://shared/audio.gd")
class Probe extends "res://kushou/battle_ui.gd":
	var repeats := 5
	func _baicao_times() -> int: return repeats

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _foe(c, distance := 40.0, hp := 10000.0) -> Dictionary:
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": hp, "hp_max": 1000.0, "res_wood": 0.0, "shield": false, "x": c.hero_pos.x, "y": c.hero_pos.y - distance}, true)
	return f

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	GS.ensure_loaded()
	GS.skill_lv["liuqingqing"] = 7
	GS.stars["liuqingqing"] = 5
	GS.shards["liuqingqing"] = 123
	var b := Probe.new()
	root.add_child(b)
	b.set_process(false)
	var c = b._core
	c.set_process(false)
	c.foes.clear()
	c.attr_set_base("atk", 100.0)
	c.attr_set_base("hp", 1000.0)
	b._sync_attrs_to_hero()
	# 从正常可见请神卡接入，身份仍是原编号，既有养成数据保留。
	b._draw_charge = 3
	b._show_god_pick()
	b._god_root.get_child(0).picked.emit() # 陈石。
	b._show_god_pick()
	assert(b._god_root.get_child(0).aid == "liuqingqing")
	b._god_root.get_child(0).picked.emit()
	assert(LS.god_ids().has("liuqingqing") and not LS.god_ids().has("liuqingqing2"))
	assert(GS.skill_lv["liuqingqing"] == 7 and GS.stars["liuqingqing"] == 5 and GS.shards["liuqingqing"] == 123)
	assert(AD.ANCESTORS["liuqingqing"]["tiers"][0]["effects"]["heal_pct"] == 20)
	assert(AD.ANCESTORS["liuqingqing"]["tiers"][1]["effects"]["aura"] == 1)
	assert(Menu.SKILL_DEFS["liuqingqing"]["heal_mul"] == 2.0 and Menu.SKILL_DEFS["liuqingqing"]["mp"] == 80.0)
	var index := -1
	for i in b._skills.size():
		if b._skills[i]["aid"] == "liuqingqing": index = i
	assert(index >= 0 and b._skills[index]["mp"] == 80.0 and b._skills[index]["mul"] == 1.0)
	GS.skill_lv["liuqingqing"] = 0
	var target := _foe(c)
	c.hero["hp"] = 100.0
	b._mp = 500.0
	b._cast_skill(index)
	assert(c.hero["hp"] == 300.0 and b._mp == 420.0 and target["hp"] == 10000.0 and not target.has("poison"))
	# 真实六档家传，毒圈解锁、范围/费用/共享/持续时间均读取同一角色。
	for tier in range(6):
		for part in range(3): b._add_card("liuqingqing_t%d_%d" % [tier, part])
	GS.skill_lv["liuqingqing"] = 10
	var edge := _foe(c, 140.0)
	var outside := _foe(c, 160.0)
	c.hero["hp"] = 100.0
	b._mp = 500.0
	b._cast_skill(index)
	assert(is_equal_approx(c.hero["hp"], 430.0) and b._mp == 440.0 and is_equal_approx(b._skills[index]["cd_t"], 10.56))
	assert(target["poison"] == 1.0 and edge["poison"] == 1.0 and not outside.has("poison"))
	assert(target["poison_t"] == 6.0 and target["vuln_pct"] == 10.0)
	b._cast_skill(index)
	assert(target["poison"] == 1.0) # 未得百草仅刷新，不叠层。
	b._tick_poison(1.0)
	assert(is_equal_approx(target["hp"], 9950.665)) # 30×1.3等级×1.15共享×1.1易伤。
	assert(is_equal_approx(c._apply_dmg(target, 100.0, "物理", 0), 80.0 * 1.1))
	assert(is_equal_approx(c._apply_dmg(target, 100.0, "木系"), 126.5))
	assert(c._apply_dmg(target, 100.0, "真实") == 100.0)
	# 百草走实际领取入口，治疗+10%，五连放只收一次内力与CD。
	b._add_card("shiny_liuqingqing")
	assert(b._baicao and b._anc_mod["liuqingqing"]["heal_pct"] == 30.0)
	target["poison"] = 0.0
	c.hero["hp"] = 100.0
	b._mp = 500.0
	b._cast_skill(index)
	assert(c.hero["hp"] == 1000.0 and b._mp == 440.0 and target["poison"] == 5.0)
	# 满血仍可环毒；结果和死亡不能治疗/施毒或消耗内力。
	b.repeats = 1
	b._cast_skill(index)
	assert(target["poison"] == 6.0)
	c.hero["hp"] = 0.0
	var mana: float = b._mp
	b._cast_skill(index)
	assert(c.hero["hp"] == 0.0 and b._mp == mana and target["poison"] == 6.0)
	b.queue_free()
	await process_frame
	# 长帧只结算实际持续时间，层数逐层衰减，毒击杀当场且清场后不追击旧目标。
	b = Probe.new(); root.add_child(b); b.set_process(false)
	c = b._core; c.set_process(false); c.foes.clear(); c.hero["atk"] = 100.0
	target = _foe(c)
	target.merge({"poison": 1.0, "poison_t": 4.0, "poison_acc": 0.0}, true)
	b._tick_poison(10.0)
	assert(target["hp"] == 9880.0 and not target.has("poison"))
	target["hp"] = 10000.0
	target.merge({"poison": 2.0, "poison_t": 4.0, "poison_acc": 0.0}, true)
	b._tick_poison(10.0)
	assert(target["hp"] == 9640.0 and not target.has("poison"))
	# 正常施放产生的百草毒层各自到期，新的一层不能延长旧的一层。
	GS.skill_lv["liuqingqing"] = 0
	b._anc_mod["liuqingqing"] = {"aura": 1.0}
	b._baicao = true
	target["hp"] = 10000.0
	b._cast_heal(1.0)
	b._tick_poison(2.0)
	b._cast_heal(1.0)
	assert(target["poison_layers"][0]["t"] == 2.0 and target["poison_layers"][1]["t"] == 4.0)
	b._tick_poison(2.0)
	assert(target["poison"] == 1.0)
	b._tick_poison(2.0)
	assert(target["hp"] == 9760.0 and not target.has("poison"))
	target["hp"] = 1.0
	target.merge({"poison": 1.0, "poison_t": 4.0, "poison_acc": 0.0}, true)
	var other := _foe(c)
	other.merge({"poison": 1.0, "poison_t": 4.0, "poison_acc": 0.0}, true)
	var kills: int = b._kills
	c.kill.connect(func(_n): c.clear_enemy_attacks())
	b._tick_poison(10.0)
	assert(target.get("_death_settled", false) and b._kills == kills + 1 and other["hp"] == 10000.0)
	b.queue_free()
	await process_frame
	print("PASS: normal medical god/save identity; six-tier healing/poison/range/cost; level/shared growth; real Baicao; bounded poison timing and callback kills")
	Audio.quit_cleanly()
