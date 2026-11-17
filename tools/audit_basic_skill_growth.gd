extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const GS := preload("res://shared/game_state.gd")
const LS := preload("res://shared/level_state.gd")
const Partner := preload("res://menu/partner_home.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	var c = b._core
	c.set_process(false)
	c.attr_set_base("atk", 100.0)
	c.attr["atk"]["temp"] = 0.0
	c.attr["atk"]["amp"] = 0.0
	c.attr_set_base("crit", 0.0)
	c.hero["lucky"] = 0.0
	c.foes.clear()
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": 10000.0, "hp_max": 1000.0, "shield": false, "x": c.hero_pos.x, "y": c.hero_pos.y - 40.0}, true)
	assert(Partner.SKILL_LV_STEP["zhujue"] == 2 and b.SKILL_LV_STEP["zhujue"] == 2)
	for lv in [0, 1, 10]:
		GS.skill_lv["zhujue"] = lv
		b._sync_attrs_to_hero()
		b._sync_attrs_to_hero() # 同步是赋值，不应逐帧重复叠加。
		assert(c.hero["atk"] == 100.0 and is_equal_approx(c.basic_skill_multiplier(), 1.0 + lv * 0.02))
		f["hp"] = 10000.0
		c._heavy = 0
		c._hero_strike(f)
		assert(is_equal_approx(f["hp"], 10000.0 - (80.0 + lv * 2.0)))
		assert(c._apply_dmg(f, 100.0, "物理", 0) == 80.0) # 其他技能不会重复吃主角普攻成长。
	# 重击/同刀溅射沿用同一基础剑法增幅，伤害进入原护甲管线。
	f["hp"] = 10000.0
	c._heavy = 2
	c._hero_strike(f)
	assert(is_equal_approx(f["hp"], 9828.0))
	c._spawn_foe()
	var extra: Dictionary = c.foes.back()
	extra.merge({"hp": 10000.0, "hp_max": 1000.0, "shield": false, "x": f["x"] + 20.0, "y": f["y"]}, true)
	f["hp"] = 10000.0
	c._heavy = 0
	c.skill["splash"] = 1
	c._hero_strike(f)
	assert(is_equal_approx(extra["hp"], 9936.0))
	# 当前家传多目标/追击/剑气也从相同的普攻成长读取，不给宠物抬攻击值。
	f["hp"] = 10000.0
	extra["hp"] = 10000.0
	b._hero_passive = {"tgt_add": 1, "chase": 100, "qijian": 100}
	b._hero_extra_hits()
	assert(is_equal_approx(f["hp"], 9836.0) and is_equal_approx(extra["hp"], 9812.0))
	GS.skill_lv["zhujue"] = 0
	b._sync_attrs_to_hero()
	assert(c.basic_skill_multiplier() == 1.0 and c.hero["atk"] == 100.0)
	b.queue_free()
	await process_frame
	print("PASS: basic sword levels 0/1/10; stable sync; heavy/splash/extra attacks; other skills and shared attack unchanged")
	Audio.quit_cleanly()
