extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _stable(b) -> void:
	var c = b._core
	var state := [c.hero["atk"], c.hero["hp_max"], c.hero["hp"]]
	b._sync_attrs_to_hero()
	assert(state == [c.hero["atk"], c.hero["hp_max"], c.hero["hp"]])

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 8
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	var c = b._core
	c.set_process(false)
	var m = b._bm
	m.set_process(false)
	for key in ["atk", "hp"]:
		c.attr[key]["temp"] = 0.0
		c.attr[key]["amp"] = 0.5
	c.attr_set_base("atk", 100.0)
	c.attr_set_base("hp", 200.0)
	c.hero.merge({"atk": 150.0, "hp_max": 300.0, "hp": 150.0, "lucky": 0.0}, true)
	c.attr_set_base("crit", 0.0)
	b._kills = 1000
	m.discount_i = -1
	var goods: Array = m._catalog()["consumable"]
	var hp_attr: Dictionary = c.attr["hp"].duplicate(true)
	m.stock = [{"base": 20, "item": goods[0].duplicate(true)}]
	m._buy(0) # 真实商品生命丹，消耗20杀敌数。
	assert(b._kills == 980 and c.hero["hp"] == 180.0 and c.hero["hp_max"] == 300.0 and c.attr["hp"] == hp_attr)
	_stable(b)
	c.hero["hp"] = 290.0
	m._apply_consumable(goods[0])
	assert(c.hero["hp"] == 300.0 and c.attr["hp"] == hp_attr)
	m._apply_consumable(goods[0])
	assert(c.hero["hp"] == 300.0 and c.hero["hp_max"] == 300.0)
	c.hero["hp"] = 0.0
	m._apply_consumable(goods[0])
	assert(c.hero["hp"] == 0.0 and c.attr["hp"] == hp_attr)
	c.hero["hp"] = 150.0
	m.stock = [{"base": 20, "item": goods[1].duplicate(true)}]
	m._buy(0)
	assert(b._kills == 960 and c.hero["atk"] == 154.5 and c.attr_final("atk") == 154.5)
	_stable(b)
	m.slots = [null]
	m.warehouse = [{"name": "test", "kind": "equipment", "type": "装备", "stats": {"atk": 7.0}}]
	for i in range(5):
		m._take_out(0)
		assert(c.hero["atk"] == 165.0 and c.attr_final("atk") == 165.0)
		_stable(b)
		m._store(0)
		assert(c.hero["atk"] == 154.5 and c.attr_final("atk") == 154.5)
		_stable(b)
	c.foes.clear()
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"hp": 10000.0, "hp_max": 1000.0, "shield": false}, true)
	assert(c._apply_dmg(f, c.hero["atk"], "物理", 0) == 134.5)
	# 疾风散保留共享10秒计时；浮点边界不因30帧少一跳。
	for rate in [30, 60, 120, 0, -1]:
		c.attr["atk"]["temp"] = 0.0
		c.hero["atk"] = 150.0
		m.periodic_atk = 0.0
		m.periodic_t = 0.0
		m._apply_consumable(goods[2])
		if rate > 0:
			for i in range(rate * 10): m._process(1.0 / rate)
		else:
			for dt in ([10.0] if rate == 0 else [0.1, 2.4, 7.5]): m._process(dt)
		assert(c.hero["atk"] == 151.5 and c.attr_final("atk") == 151.5)
		assert(is_zero_approx(m.periodic_t))
		_stable(b)
		m._process(20.0)
		assert(c.hero["atk"] == 154.5 and c.attr_final("atk") == 154.5)
		_stable(b)
	b.queue_free()
	await process_frame
	print("PASS: real life-pill purchase heals 30 without max-HP growth or revival; amplified attack pill/equipment immediate and stable; periodic growth at 30/60/120/jitter/long frames")
	Audio.quit_cleanly()
