extends SceneTree
const Core := preload("res://kushou/kushou_battle.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _setup() -> Array:
	var c := Core.new()
	root.add_child(c)
	c.size = Vector2(720, 760)
	c.set_process(false)
	c.setup({"atk": 100.0, "hp_max": 1000.0, "mp_max": 100.0})
	c.kill_heal = 0.0
	c._spawn_foe()
	var f: Dictionary = c.foes.back()
	f.merge({"x": c.hero_pos.x + 40.0, "y": c.hero_pos.y, "hp": 500.0, "hp_max": 1000.0, "atk": 100.0, "t": 100.0, "stop": 1000.0, "mage": false, "brute": false, "ranged": false, "shield": false}, true)
	c._last_quota_wave = c.wave
	c._spawn_t = 999.0
	c._spawn_left = 0
	c.intro_wait = 999.0
	c._hero_cd = 999.0
	c.running = true
	var events := []
	c.hero_damaged.connect(func(amount, attacker): events.append([amount, attacker]))
	return [c, f, events]

func _shield(c, value: float) -> void:
	c.hero["shield"] = value
	c.hero["shield_max"] = value
	c.hero["shield_t"] = 5.0

func _run() -> void:
	var s := _setup()
	var c = s[0]
	var f: Dictionary = s[1]
	var events: Array = s[2]
	c.hero["hp"] = 10.0
	f["boss_lifesteal"] = 0.5
	c._process(0.01)
	assert(c.hero["hp"] == 0.0 and f["hp"] == 505.0 and not c.running)
	assert(events.size() == 1 and events[0][0] == 10.0 and events[0][1] == f)
	c.queue_free()
	await process_frame
	# 完全吸收不叠受伤层、不让嗜血回血，也不产生最低1点荆棘反伤。
	s = _setup(); c = s[0]; f = s[1]; events = s[2]
	_shield(c, 200.0)
	c.hero["thorns"] = 1.0
	f["boss_lifesteal"] = 0.5
	c._process(0.01)
	assert(c.hero["hp"] == 1000.0 and c.hero["shield"] == 100.0 and f["hp"] == 500.0 and events.is_empty())
	assert(c._hero_hit_flash == 0.0 and c._shield_block_flash > 0.0)
	assert(c._floats.any(func(item): return item["txt"] == "格挡"))
	assert(not c._floats.any(func(item): return item["txt"] == "-0"))
	c.running = false
	c._process(0.25)
	assert(c._shield_block_flash == 0.0)
	c.queue_free()
	await process_frame
	# 延迟技也先扣盾；盾破震荡仍真实生效一次。
	s = _setup(); c = s[0]; f = s[1]; events = s[2]
	_shield(c, 30.0)
	c.queue_delayed(c.hero_pos.x, c.hero_pos.y, 100.0, 100.0, "物理", 1.0, "test", "circle", Vector2.RIGHT, 0.0, 0.0, 0, 0.0, 0.0, 0.0, f)
	c._delayed_hit(c._delayed.back())
	assert(c.hero["hp"] == 930.0 and c.hero["shield"] == 0.0 and f["hp"] == 470.0)
	assert(events.size() == 1 and events[0][0] == 70.0)
	assert(c._hero_hit_flash > 0.0 and c._shield_block_flash == 0.0)
	assert(c._quake_fx.any(func(effect): return effect["big"]))
	c.queue_free()
	await process_frame
	for poison_hit in [false, true]:
		s = _setup(); c = s[0]; f = s[1]; events = s[2]
		c.hero["hp"] = 1.0
		if poison_hit:
			c.hero["poison"] = 4.0
			c.hero["poison_tick"] = 0.0
			c._update_partners(0.01)
		else:
			c.queue_delayed(c.hero_pos.x, c.hero_pos.y, 100.0, 100.0, "物理", 1.0, "test")
			c._delayed_hit(c._delayed.back())
		assert(c.hero["hp"] == 0.0 and not c.running and events.size() == 1 and events[0][0] == 1.0)
		c.queue_free()
		await process_frame
	s = _setup(); c = s[0]; events = s[2]
	_shield(c, 200.0)
	c.hero["poison"] = 4.0
	c.hero["poison_tick"] = 0.0
	c._update_partners(0.01)
	assert(c.hero["hp"] == 1000.0 and c.hero["shield"] == 188.0 and events.is_empty())
	c.queue_free()
	await process_frame
	# 普攻后的受击效果补盾，追加狐火仍须扣这层盾。
	s = _setup(); c = s[0]; f = s[1]; events = s[2]
	f["boss_foxfire"] = 1
	c.hero_hit.connect(func(): _shield(c, 100.0))
	c._process(0.01)
	assert(c.hero["hp"] == 900.0 and c.hero["shield"] == 50.0 and events.size() == 1)
	c.queue_free()
	await process_frame
	# 已被受击回调反死的攻击者不再追加狐火或毒。
	s = _setup(); c = s[0]; f = s[1]; events = s[2]
	f["boss_foxfire"] = 1
	f["boss_poison"] = true
	c.hero_hit.connect(func(): c.reflect_damage(f, 10000.0))
	c._process(0.01)
	assert(c.hero["hp"] == 900.0 and events.size() == 1 and float(c.hero.get("poison", 0.0)) == 0.0)
	c.queue_free()
	await process_frame
	# 通知或盾破回调切换战斗状态，剩余命中链必须停止。
	for shield_end in [false, true]:
		s = _setup(); c = s[0]; f = s[1]; events = s[2]
		f["boss_foxfire"] = 1
		f["boss_lifesteal"] = 0.5
		if shield_end:
			_shield(c, 10.0)
			f["hp"] = 5.0
			c.kill.connect(func(_n): c.running = false; c.clear_enemy_attacks())
		else:
			c.hero_damaged.connect(func(_n, _f): c.running = false; c.clear_enemy_attacks())
		c._process(0.01)
		assert(not c.running and c.hero["hp"] == (1000.0 if shield_end else 900.0))
		assert(events.size() == (0 if shield_end else 1))
		if not shield_end: assert(f["hp"] == 500.0)
		c.queue_free()
		await process_frame
	print("PASS: incoming actual HP loss; shield block and break feedback; boss lifesteal; delayed/poison/fox; callback phase boundaries")
	Audio.quit_cleanly()
