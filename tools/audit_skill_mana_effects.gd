extends SceneTree
const LS := preload("res://shared/level_state.gd")
class Probe extends "res://kushou/battle_ui.gd":
	var force_free := false
	func _roll_skill_free_cast() -> bool:
		return force_free
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")
func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle := Probe.new()
	root.add_child(battle)
	battle._curio_id = "dingfengzhu"
	battle._curio_lv = 5
	battle.force_free = true
	var thunder: Dictionary = battle.SKILL_DEFS["zl"].duplicate(true)
	thunder["aid"] = "zl"
	thunder["cd_t"] = 0.0
	battle._skills = [thunder]
	battle._core.foes.clear()
	battle._mp = 17.0
	battle._tick_skills(0.0)
	assert(battle._mp == 17.0 and thunder["cd_t"] == 0.0)
	battle._core._spawn_foe()
	battle._core.foes[0]["hp"] = 100000.0
	battle._tick_skills(0.0)
	assert(battle._mp == 17.0 and float(thunder["cd_t"]) > 0.0)
	battle._skills.clear()
	battle._mp = 0.0
	battle._tick_skills(1.0)
	assert(is_equal_approx(battle._mp, 30.0))
	battle._tick_skills(2.0)
	assert(is_equal_approx(battle._mp, 80.0))
	battle.force_free = false
	battle._curio_lv = 3
	var skill: Dictionary = battle.SKILL_DEFS["chenshi"].duplicate(true)
	skill["aid"] = "chenshi"
	skill["cd_t"] = 0.0
	battle._skills = [skill]
	battle._anc_mod["chenshi"] = {"mp_flat": 80.0}
	battle._mp = 17.0
	battle._tick_skills(0.0)
	assert(is_equal_approx(battle._mp, 7.0) and float(skill["cd_t"]) > 0.0)
	battle.queue_free()
	await process_frame
	print("PASS: failed free cast keeps mana; high-cost free cast works; timed regen and reduced-cost casting")
	quit()
