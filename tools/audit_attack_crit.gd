extends SceneTree
const Audio := preload("res://shared/audio.gd")
class Probe extends "res://kushou/kushou_battle.gd":
	var force_crit := false
	var crit_rolls := 0
	func _roll_physical_crit() -> bool:
		crit_rolls += 1
		return force_crit

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	var core := Probe.new()
	root.add_child(core)
	core.set_process(false)
	core.setup({"atk": 100.0, "hp_max": 1000.0, "mp_max": 100.0})
	core.hero["crit"] = 1.0 # 故意保留过期桥字段，不应另外掷旧暴击。
	core.attr_set_base("crit", 0.2)
	core.attr_set_base("cdmg", 2.5)
	core.type_add("物理", "amp_f", 0.5)
	core._spawn_foe()
	var primary: Dictionary = core.foes.back()
	primary["hp_max"] = 1000.0
	primary["hp"] = 10000.0
	primary["shield"] = false
	primary["x"] = core.hero_pos.x
	primary["y"] = core.hero_pos.y - 40.0
	var hits := []
	core.hero_foe_hit.connect(func(_foe, amount, crit, heavy): hits.append({"dmg": amount, "crit": crit, "heavy": heavy}))
	# 普通一击：100×1.5-20防御=130，一次暴击：100×1.5×2.5-20=355。
	for critical in [false, true]:
		core.force_crit = critical
		core.crit_rolls = 0
		core._heavy = 0
		primary["hp"] = 10000.0
		hits.clear()
		core._floats.clear()
		core._hero_strike(primary)
		var expected := 355.0 if critical else 130.0
		assert(core.crit_rolls == 1 and is_equal_approx(primary["hp"], 10000.0 - expected))
		assert(hits.size() == 1 and hits[0]["crit"] == critical and hits[0]["dmg"] == expected)
		assert(core._floats.back()["txt"] == str(int(expected)))
	# 重击、溅射共享一次暴击结果，各目标只经过一次暴伤和防御。
	core._spawn_foe()
	var extra: Dictionary = core.foes.back()
	extra["hp_max"] = 1000.0
	extra["hp"] = 10000.0
	extra["shield"] = false
	extra["x"] = primary["x"] + 20.0
	extra["y"] = primary["y"]
	core.skill["splash"] = 1
	core.force_crit = true
	core.crit_rolls = 0
	core._heavy = 2
	primary["hp"] = 10000.0
	hits.clear()
	core._hero_strike(primary)
	assert(core.crit_rolls == 1 and hits.size() == 2)
	assert(hits[0]["crit"] and hits[1]["crit"] and hits[0]["heavy"] and hits[1]["heavy"])
	assert(is_equal_approx(hits[0]["dmg"], 580.0))
	assert(is_equal_approx(hits[1]["dmg"], 400.0)) # 100×1.6×0.7×1.5×2.5-20
	# 非普攻物理技能仍由统一层掷一次，元素/真实不暴击。
	core.crit_rolls = 0
	var physical := core.hero_out_dmg(100.0, core.DMG_PHYS)
	assert(physical["crit"] and physical["dmg"] == 375.0 and core.crit_rolls == 1)
	for type in [core.DMG_FIRE, core.DMG_TRUE]:
		var hit := core.hero_out_dmg(100.0, type, 1)
		assert(not hit["crit"] and hit["dmg"] == 100.0 and core.crit_rolls == 1)
	# 属性层与有效暴击率采用设计上限，临时暴击也不能越过75%。
	core.attr_set_base("crit", 2.0)
	core.attr_set_base("cdmg", 8.0)
	core.hero["curio_crit"] = 0.1
	assert(core.attr_final("crit") == 0.75 and core.attr_final("cdmg") == 4.0)
	assert(core.physical_crit_rate() == 0.75)
	core.attr_set_base("crit", 0.2)
	core.partners["yanwugui"]["active"] = 5.0
	core.partners["yanwugui"]["crit_lv"] = 0
	assert(is_equal_approx(core.physical_crit_rate(), 0.55))
	core.queue_free()
	await process_frame
	print("PASS: one basic crit roll, exact crit/heavy/splash damage and feedback; type isolation and stat caps")
	Audio.quit_cleanly()
