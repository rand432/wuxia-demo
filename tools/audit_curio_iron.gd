extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _hit(core, attacker: Dictionary, damage: float, push := 0.0) -> void:
	core.queue_delayed(core.hero_pos.x, core.hero_pos.y, 100.0, damage, "物理", 1.0, "test", "circle", Vector2.RIGHT, 0.0, 0.0, 0, 0.0, 0.0, push, attacker)
	core._delayed_hit(core._delayed.back())
	core._delayed.clear()

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.foes.clear()
	for i in range(2):
		core._spawn_foe()
		var foe: Dictionary = core.foes.back()
		foe["hp"] = 10000.0
		foe["hp_max"] = 10000.0
		foe["x"] = core.hero_pos.x + 50.0 + i * 50.0
		foe["y"] = core.hero_pos.y
	var near: Dictionary = core.foes[0]
	var attacker: Dictionary = core.foes[1]
	battle._curio_id = "tiebushan"
	for lv in range(1, 6):
		battle._curio_lv = lv
		battle._tie_stacks = 0
		core.hero["curio_cut"] = 0.0
		core.hero["curio_control_immune"] = false
		for i in range(20): core._notify_hero_damage(10.0, {})
		var cap := 5 if lv == 1 else 8
		var reduction := cap * (0.03 if lv >= 4 else 0.02)
		assert(battle._tie_stacks == cap)
		assert(is_equal_approx(core.hero_in_dmg(100.0, "物理"), 100.0 * (1.0 - reduction)))
		assert(is_equal_approx(core.hero_in_dmg(100.0, "火系"), 100.0 * (1.0 - reduction)))
		assert(core.hero_in_dmg(100.0, "真实") == 100.0)
		assert(core.hero["curio_control_immune"] == (lv == 5))
		battle._curio_tick_tiebushan(4.9)
		assert(battle._tie_stacks == cap)
		core._notify_hero_damage(0.0, attacker)
		battle._curio_tick_tiebushan(0.11)
		assert(battle._tie_stacks == 0 and core.hero["curio_cut"] == 0.0)
		assert(not core.hero["curio_control_immune"])
	# 满层按实际所受伤害反射给远一点的真正攻击者，不吃主角攻击与暴击加成。
	battle._curio_lv = 3
	for i in range(8): core._notify_hero_damage(10.0, {})
	core.hero["atk"] = 99999.0
	core.hero["crit"] = 1.0
	core.hero["hp_max"] = 10000.0
	core.hero["hp"] = 10000.0
	_hit(core, attacker, 100.0)
	assert(is_equal_approx(core.hero["hp"], 9916.0))
	assert(is_equal_approx(attacker["hp"], 9974.8) and near["hp"] == 10000.0)
	# 满层第五级阻止冲撞，超时失去免控后恢复击退。
	battle._curio_lv = 5
	core._notify_hero_damage(1.0, {})
	var position_before: Vector2 = core.hero_pos
	_hit(core, attacker, 100.0, 110.0)
	assert(core.hero_pos == position_before)
	battle._curio_tick_tiebushan(5.0)
	_hit(core, attacker, 100.0, 110.0)
	assert(core.hero_pos != position_before and battle._tie_stacks == 1)
	# 真正普通攻击与延迟技都只结算一次30%防御。
	battle._curio_id = ""
	core.hero["curio_cut"] = 0.0
	core.hero["curio_control_immune"] = false
	core.type_add("物理", "red_f", 0.30)
	core.hero["cut"] = 0.30
	core.hero["hp"] = 10000.0
	core.foes = [near]
	near["x"] = core.hero_pos.x + 50.0
	near["y"] = core.hero_pos.y
	near["atk"] = 100.0
	near["t"] = 100.0
	near["stop"] = 1000.0
	for key in ["mage", "brute", "ranged", "shield"]: near[key] = false
	core._last_quota_wave = core.wave
	core._wave_spawned = core._wave_quota
	core._spawn_left = 0
	core._spawn_t = 9999.0
	core.intro_wait = 9999.0
	core._hero_cd = 9999.0
	core._hitstop = 0.0
	core._process(0.01)
	assert(is_equal_approx(core.hero["hp"], 9930.0))
	_hit(core, near, 100.0)
	assert(is_equal_approx(core.hero["hp"], 9860.0))
	# 中毒无指定攻击者，叠层但不错误反伤最近怪；毒伤致命当场走保命。
	battle._curio_id = "tiebushan"
	battle._curio_lv = 1
	battle._tie_stacks = 0
	core.hero["poison"] = 4.0
	core.hero["poison_tick"] = 0.0
	var foe_hp: float = near["hp"]
	core._update_partners(0.01)
	assert(battle._tie_stacks == 1 and near["hp"] == foe_hp)
	battle._curio_id = "zhiren"
	battle._curio_lv = 1
	battle._set_paper_count(1)
	core.hero["poison_tick"] = 0.0
	core.hero["hp"] = 1.0
	core._update_partners(0.01)
	assert(battle._zhiren == 0 and core.running and core.hero["hp"] == 10000.0)
	battle.queue_free()
	await process_frame
	print("PASS: iron levels/expiry/all damage sources/exact attacker reflection/push immunity; armor once; poison death")
	Audio.quit_cleanly()
