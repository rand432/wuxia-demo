extends SceneTree
const Core := preload("res://kushou/kushou_battle.gd")
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _dead_foe(c, statue := false) -> Dictionary:
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f["hp"] = 0.0
	if statue: f["still"] = true
	return f

func _run() -> void:
	var c := Core.new()
	root.add_child(c)
	c.set_process(false)
	c.setup({"hp_max": 1000.0})
	c.hero["hp"] = 990.0
	assert(c.heal_hero(100.0) == 10.0 and c.hero["hp"] == 1000.0)
	assert(c.heal_hero(-10.0) == 0.0 and c.hero["hp"] == 1000.0)
	c.hero["hp"] = 100.0
	c._kill_foe(_dead_foe(c, true))
	assert(c.hero["hp"] == 100.0) # 石像是物件，不提供击杀回血。
	var f := _dead_foe(c)
	c._kill_foe(f)
	assert(c.hero["hp"] == 180.0)
	c._kill_foe(f)
	assert(c.hero["hp"] == 180.0)
	c.hero["hp"] = 0.0
	c._kill_foe(_dead_foe(c))
	assert(c.hero["hp"] == 0.0)
	c.hero["hp_regen"] = 100.0
	c._update_partners(0.1)
	assert(c.hero["hp"] == 0.0 and c.heal_hero(100.0) == 0.0)
	c.foes.clear()
	c.hero["shield"] = 10.0
	c.hero["shield_max"] = 10.0
	c.hero["mech_shieldheal"] = 0.2
	c._absorb_by_shield(20.0)
	assert(c.hero["hp"] == 0.0)
	c.revive()
	assert(c.hero["hp"] == 500.0 and c.running)
	c.queue_free()
	await process_frame
	LS.ensure_loaded()
	LS.current_level = 6
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	b._core.set_process(false)
	b._core.foes.clear()
	b._core._spawn_foe()
	f = b._core.foes.back()
	f["x"] = b._core.hero_pos.x
	f["y"] = b._core.hero_pos.y - 40.0
	b._core.hero["atk"] = 100.0
	b._core.hero["hp_max"] = 1000.0
	b._core.hero["hp"] = 990.0
	b._anc_mod["liuqingqing"] = {"aura": 1.0}
	b._baicao = true # 百草解锁叠毒；满血施法仍可刷新/叠加医毒。
	b._core._floats.clear()
	b._cast_heal(1.0)
	assert(b._core.hero["hp"] == 1000.0 and b._core._floats.back()["txt"] == "+10")
	var poison: float = f["poison"]
	b._core._floats.clear()
	b._cast_heal(1.0)
	assert(b._core._floats.is_empty() and f["poison"] == poison + 1.0) # 满血依然可施放附带环毒。
	b._core.hero["hp"] = 0.0
	poison = f["poison"]
	b._cast_heal(1.0)
	assert(b._core.hero["hp"] == 0.0 and f["poison"] == poison)
	b._mingzhu = true
	b._anc_mod["mingzhu"] = {"heal_aura": 1.0}
	b._tick_aura(0.1)
	b._curio_use()
	b._curio_cd = 0.0
	b._curio_tick_xuehulu()
	b._gunshan_grow()
	assert(b._core.hero["hp"] == 0.0)
	var skill: Dictionary = b.SKILL_DEFS["liuqingqing2"].duplicate(true)
	skill["aid"] = "liuqingqing2"
	skill["cd_t"] = 0.0
	b._skills = [skill]
	b._mp = 200.0
	b._cast_skill(0)
	assert(b._mp == 200.0 and b._skills[0]["cd_t"] == 0.0)
	b._run_over = true
	b._core.hero["hp"] = 500.0
	b._cast_heal(1.0)
	assert(b._core.hero["hp"] == 500.0)
	b.queue_free()
	await process_frame
	print("PASS: normal healing cannot revive; statue kill grants no heal; actual heal feedback/full-HP poison retained; explicit revive preserved")
	Audio.quit_cleanly()
