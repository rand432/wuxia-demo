extends SceneTree
const Core := preload("res://kushou/kushou_battle.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _core():
	var c := Core.new()
	root.add_child(c)
	c.set_process(false)
	c.setup({"atk": 1000.0, "hp_max": 1000.0, "mp_max": 100.0})
	c.start_run()
	c.hero["hp"] = 100.0
	c.attr_set_base("crit", 0.0)
	c.kill_heal = 0.0
	return c

func _foe(c, hp: float):
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f["hp"] = hp
	f["hp_max"] = 1000.0
	f["shield"] = false
	f["x"] = c.hero_pos.x
	f["y"] = c.hero_pos.y - 40.0
	return f

func _run() -> void:
	var c = _core()
	var f: Dictionary = _foe(c, 10.0)
	c.hero["lifesteal_t"] = 5.0
	c.hero["lifesteal"] = 0.1
	assert(c._apply_dmg(f, 1000.0, "真实") == 1000.0) # 保留整刀结算/飘字语义。
	assert(c.hero["hp"] == 101.0 and c.dmg_done == 10.0)
	assert(c._apply_dmg(f, 1000.0, "真实") == 0.0) # 尚未扫死亡，但HP已归零。
	assert(c.hero["hp"] == 101.0 and c.dmg_done == 10.0)
	c.hero["hp"] = 0.0
	c._apply_dmg(_foe(c, 10.0), 1000.0, "真实")
	assert(c.hero["hp"] == 0.0 and c.dmg_done == 20.0)
	c.queue_free()
	await process_frame
	# 普攻溅射逐目标以各自剩余气血计算，不能用过量伤害回血。
	c = _core()
	c.hero["mech_lifesteal"] = 0.1
	c.skill["splash"] = 1
	f = _foe(c, 10.0)
	_foe(c, 20.0)
	c._hero_strike(f)
	assert(is_equal_approx(c.hero["hp"], 103.0) and c.dmg_done == 30.0)
	c.queue_free()
	await process_frame
	c = _core()
	c.hero["hp"] = 999.5
	c.hero["mech_lifesteal"] = 0.1
	f = _foe(c, 10.0)
	c._hero_strike(f)
	assert(c.hero["hp"] == 1000.0 and c._floats.back()["txt"] == "+0.5")
	c._floats.clear()
	c._hero_strike(_foe(c, 10.0))
	assert(not c._floats.any(func(item): return item["txt"] == "+0"))
	c.queue_free()
	await process_frame
	# 第一目标的命中回调杀掉后续溅射目标：该目标不能再触发普攻命中或吸血。
	c = _core()
	c.hero["mech_lifesteal"] = 0.1
	c.skill["splash"] = 1
	f = _foe(c, 2000.0)
	var other: Dictionary = _foe(c, 20.0)
	var hits := []
	c.hero_foe_hit.connect(func(target, _d, _crit, _heavy):
		hits.append(target)
		c.reflect_damage(other, 1000.0))
	c._hero_strike(f)
	assert(hits.size() == 1 and is_equal_approx(c.hero["hp"], 198.0))
	assert(is_equal_approx(c.dmg_done, 1000.0)) # 普攻980＋反射实际20。
	c.reflect_damage(other, 1000.0)
	assert(c.dmg_done == 1000.0)
	c.queue_free()
	await process_frame
	# 击杀回调导致主角倒下时，普攻末尾的吸血不能把他重新抬起来。
	c = _core()
	c.hero["mech_lifesteal"] = 0.1
	f = _foe(c, 10.0)
	c.kill.connect(func(_n): c.hero["hp"] = 0.0)
	c._hero_strike(f)
	assert(c.hero["hp"] == 0.0)
	c.queue_free()
	await process_frame
	print("PASS: lifesteal/damage credit use effective HP loss; dead targets and reentrant splash do not double-credit or revive hero")
	Audio.quit_cleanly()
