extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")
class Probe extends "res://kushou/kushou_battle.gd":
	var critical := false
	var rolls := 0
	func _roll_physical_crit() -> bool:
		rolls += 1
		return critical

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var original = battle._core
	original.set_process(false)
	var core := Probe.new()
	battle.add_child(core)
	core.setup({"atk": 100.0, "hp_max": 1000.0, "mp_max": 100.0})
	core.set_process(false)
	battle._core = core
	original.queue_free()
	core.attr_set_base("cdmg", 2.5)
	core.type_add("物理", "amp_f", 0.5)
	core.hero["crit"] = 1.0 # 过期旧字段不能再制造第二次暴击。
	core.hero["lucky"] = 0.0
	for i in range(3):
		core._spawn_foe()
		var foe: Dictionary = core.foes.back()
		foe["x"] = 0.0
		foe["y"] = -100.0 * (i + 1)
		foe["hp_max"] = 1000.0
		foe["hp"] = 10000.0
		foe["shield"] = false
	# 保留的旧分支：手动投入一枚飞匕，不解锁旧伙伴或恢复旧玩法。
	assert(not core.partners["suqingluan"]["owned"])
	for critical in [false, true]:
		core.critical = critical
		core.rolls = 0
		for foe in core.foes: foe["hp"] = 10000.0
		core._dg_list = [{"pos": Vector2(0.0, -100.0), "tgt": core.foes[0], "dir": Vector2.UP, "dmg": 100.0, "pierce": 1, "bounce": 1, "hits": [], "t": 0.0, "multi": false}]
		for i in range(3):
			var dagger: Dictionary = core._dg_list[0]
			dagger["pos"] = Vector2(dagger["tgt"]["x"], dagger["tgt"]["y"])
			core._floats.clear()
			core._update_dagger_motion(0.0)
			var expected := (205.0 if i == 2 else 355.0) if critical else (70.0 if i == 2 else 130.0)
			assert(is_equal_approx(core.foes[i]["hp"], 10000.0 - expected))
			var feedback: Array = core._floats.filter(func(f): return str(f["txt"]).begins_with("飞匕 "))
			assert(feedback.size() == 1 and feedback[0]["txt"] == "飞匕 " + str(int(expected)))
			assert(feedback[0]["big"] == critical)
		assert(core.rolls == 3 and core._dg_list.is_empty())
	assert(not core.partners["suqingluan"]["owned"])
	# 当前玩法的飞刃去程/回程：每次命中独立判一次，不叠旧1.8倍。
	for critical in [false, true]:
		core.critical = critical
		core.rolls = 0
		for foe in core.foes: foe["hp"] = 10000.0
		battle._feiren_line(Vector2.ZERO, Vector2.UP, 100.0, 2, true, 0.5)
		var expected := 522.5 if critical else 185.0
		assert(is_equal_approx(core.foes[0]["hp"], 10000.0 - expected))
		assert(is_equal_approx(core.foes[1]["hp"], 10000.0 - expected))
		assert(core.foes[2]["hp"] == 10000.0 and core.rolls == 4)
	# 强化回调结束时，旧hero桥与属性层就应一致，无需等下一帧修正。
	core.attr_set_base("crit", 0.7)
	core.attr_set_base("cdmg", 3.9)
	battle._apply_aug("crit_add", 25.0)
	battle._apply_aug("critdmg_add", 50.0)
	assert(core.hero["crit"] == 0.75 and core.hero["crit_dmg"] == 4.0)
	assert(core.hero["crit"] == core.attr_final("crit") and core.hero["crit_dmg"] == core.attr_final("cdmg"))
	battle.queue_free()
	await process_frame
	print("PASS: legacy dagger pierce/bounce single crit without reactivation; live flying blade/return; immediate cap display")
	Audio.quit_cleanly()
