extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _reset(b) -> void:
	var c = b._core
	for key in ["atk", "hp", "aspd"]:
		c.attr[key]["temp"] = 0.0
		c.attr[key]["amp"] = 0.5
	c.attr_set_base("atk", 100.0)
	c.attr_set_base("hp", 200.0)
	c.hero["atk"] = 150.0
	c.hero["hp_max"] = 300.0
	c.hero["hp"] = 150.0
	c.hero["aspd"] = 1.5
	b._hero_jianpo = false
	b._hero_passive = {}
	b._anc_mod["zhujue"] = {}
	c.hero["basic_family_bonus"] = 0.0

func _stable(b) -> void:
	var c = b._core
	var snapshot := [c.hero["atk"], c.hero["hp_max"], c.hero["hp"], c.hero["aspd"]]
	b._sync_attrs_to_hero()
	assert(snapshot == [c.hero["atk"], c.hero["hp_max"], c.hero["hp"], c.hero["aspd"]])

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	var c = b._core
	c.set_process(false)
	_reset(b)
	b._add_ancestor_effects("zhujue", {"dmg_pct": 20, "aspd_pct": 20})
	b._apply_hero_passive({"dmg_pct": 20, "aspd_pct": 20})
	assert(is_equal_approx(c.hero["atk"], 150.0) and is_equal_approx(c.hero["aspd"], 1.7) and c.hero["basic_family_bonus"] == 0.2)
	_stable(b)
	_reset(b)
	b._level_bonus(2)
	assert(c.hero["atk"] == 153.0 and c.hero["hp_max"] == 318.0 and c.hero["hp"] == 159.0)
	_stable(b)
	_reset(b)
	b._apply_str_levels(2)
	assert(c.hero["atk"] == 153.0 and c.hero["hp_max"] == 330.0 and c.hero["hp"] == 165.0)
	_stable(b)
	# 平加卡按新增的最终上限补气血，保留原来的“加上限同时加血”规则。
	_reset(b)
	b._apply_own({"atk": 10.0, "hp": 20.0, "def": 0.0, "gold_pct": 0.0, "crystal_pct": 0.0})
	assert(c.hero["atk"] == 165.0 and c.hero["hp_max"] == 330.0 and c.hero["hp"] == 180.0)
	_stable(b)
	_reset(b)
	b._apply_combo({"combo_key": "atk", "combo_val": 10.0})
	b._apply_combo({"combo_key": "hp", "combo_val": 20.0})
	assert(c.hero["atk"] == 165.0 and c.hero["hp_max"] == 330.0 and c.hero["hp"] == 180.0)
	_stable(b)
	_reset(b)
	b._gunshan_grow()
	assert(c.hero["hp_max"] == 312.0 and c.hero["hp"] == 162.0)
	_stable(b)
	c.hero["hp"] = 0.0
	b._apply_flat_growth(10.0, 20.0)
	assert(c.hero["hp"] == 0.0)
	# 剑魄临时攻速与永久增幅同源；切换目标只移除剑魄自身叠层。
	_reset(b)
	c.foes.clear()
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	b._hero_jianpo = true
	b._jpo_stacks = 0
	b._jpo_tid = int(f.get("_tid", -1))
	b._hero_extra_hits(f)
	assert(is_equal_approx(c.hero["aspd"], 1.56))
	b._apply_hero_passive({"aspd_pct": 20})
	assert(is_equal_approx(c.hero["aspd"], 1.76))
	b._jpo_tid = -999
	b._hero_extra_hits(f)
	assert(b._jpo_stacks == 0 and is_equal_approx(c.hero["aspd"], 1.7))
	_stable(b)
	c.attr["aspd"]["amp"] = 10.0
	b._sync_attrs_to_hero()
	assert(c.hero["aspd"] == b.MAX_ASPD)
	b.queue_free()
	await process_frame
	print("PASS: immediate growth matches attribute source; level HP ratio/flat HP grant; jianpo reset preserves permanent speed; no next-frame jump")
	Audio.quit_cleanly()
