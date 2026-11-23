extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _battle():
	LS.ensure_loaded()
	LS.current_level = 6
	var b = Battle.instantiate()
	root.add_child(b)
	b.set_process(false)
	var c = b._core
	c.set_process(false)
	c.foes.clear()
	c.kill.disconnect(b._on_core_kill)
	c.coin_drop.disconnect(b._on_coin_drop) # 排除通用随机1~3文钱，只断言类型奖励。
	c.kill_heal = 0.0
	b._curio_id = ""
	b._treasure_pct = 50.0
	b._boss_pct = 50.0
	b._gold_pct = 20.0
	b._wen = 0
	b._crystal = 0
	return b

func _foe(b, rt: String) -> Dictionary:
	b._core._spawn_foe()
	var f: Dictionary = b._core.foes.back()
	f["rtype"] = rt
	f["_tid"] = 0 # 不依赖界面分配，且多个目标允许相同视觉编号。
	return f

func _kill(b, f: Dictionary) -> void:
	f["hp"] = 0.0
	b._core._kill_foe(f)

func _run() -> void:
	var b = _battle()
	var c = b._core
	c.foe_defeated.connect(func(f):
		b._on_foe_defeated(f)
		c._kill_foe(f))
	var coin := _foe(b, "coin")
	var crystal := _foe(b, "crystal")
	_kill(b, coin)
	_kill(b, crystal)
	assert(b._wen == 36 and b._crystal == 3)
	_kill(b, coin)
	b._on_foe_defeated(coin)
	c.foes.clear()
	assert(b._tick_battle_effects(0.0) and b._wen == 36 and b._crystal == 3)
	# 普通怪不发类型奖；宝物倍率与全局文钱倍率各进一次。
	_kill(b, _foe(b, ""))
	_kill(b, _foe(b, "coin"))
	assert(b._wen == 72 and b._crystal == 3)
	var boss := _foe(b, "boss")
	boss["boss"] = true
	boss["boss_revive"] = 1
	_kill(b, boss)
	assert(float(boss["hp"]) > 0.0 and not boss.get("_rtype_rewarded", false) and b._wen == 72)
	_kill(b, boss)
	assert(b._wen == 432 and b._crystal == 33)
	_kill(b, boss)
	assert(b._wen == 432 and b._crystal == 33)
	b.queue_free()
	await process_frame
	for clear_kind in ["withdraw", "death", "backwash"]:
		b = _battle()
		c = b._core
		coin = _foe(b, "coin")
		crystal = _foe(b, "crystal")
		# 活着时处理过一帧，也不等于之后消失就是击杀。
		assert(b._tick_battle_effects(0.0))
		if clear_kind == "withdraw":
			c.foes.clear()
			c.clear_enemy_attacks()
		elif clear_kind == "death":
			c.hero["hp"] = 0.0
			b._on_hero_down()
		else:
			c.set_wave(10)
			b._backwash()
		b._process(0.0)
		assert(b._wen == 0 and b._crystal == 0 and not coin.get("_death_settled", false) and not crystal.get("_death_settled", false))
		b._on_foe_defeated(coin) # 撤场对象不能靠补发事件骗奖励。
		assert(b._wen == 0)
		b.queue_free()
		await process_frame
	# 终局和锁灵晶边界：先确认的击杀奖励在结算前已有；被锁收入不延后补发。
	b = _battle()
	c = b._core
	b._crystal_lock = true
	crystal = _foe(b, "crystal")
	_kill(b, crystal)
	assert(b._crystal == 0)
	b._crystal_lock = false
	b._on_foe_defeated(crystal)
	assert(b._crystal == 0)
	coin = _foe(b, "coin")
	c.kill.connect(func(_n): b._end_run(false))
	_kill(b, coin)
	assert(b._run_over and b._wen == 36)
	_kill(b, _foe(b, "coin"))
	assert(b._wen == 36)
	b.queue_free()
	await process_frame
	b = _battle()
	c = b._core
	c.set_wave(16)
	c.wave_reset_quota()
	c._wave_spawned = 9
	var previous_quota: int = c._wave_quota
	var swarm: Array = b._set_cards["swarm_0"]
	b._cards.append_array(swarm)
	b._activate_set("swarm_0")
	assert(c._wave_spawned == 9 and c._wave_quota == previous_quota + 5 and c.wave_stage_adjustment == -4)
	for i in c.MAX_FOES:
		assert(not c._spawn_foe().is_empty())
	b._coin_count_extra = 4
	b._crystal_count_extra = 3
	b._spawn_typed_foes()
	c._tick_wave_spawn(2.0)
	assert(c.foes.size() == c.MAX_FOES and c._wave_spawned == 9)
	assert(c._queued_coin_foes == 4 and c._queued_crystal_foes == 3 and not c.foes.back().has("rtype"))
	var typed := {"coin": 0, "crystal": 0}
	for i in 100:
		if c.wave_spawn_complete():
			break
		if c.foes.size() >= c.MAX_FOES:
			c.foes.pop_front()
		var previous_size: int = c.foes.size()
		c._tick_wave_spawn(0.22)
		assert(c.foes.size() <= previous_size + 1)
		if c.foes.size() > previous_size and c.foes.back().has("rtype"):
			typed[c.foes.back()["rtype"]] += 1
	assert(c.wave_spawn_complete() and c._wave_spawned == c._wave_quota and typed == {"coin": 4, "crystal": 3})
	c.foes.clear()
	c.queue_wave_reward_foes(1, 0)
	assert(not c.wave_cleared())
	c.set_wave(17)
	c.wave_reset_quota()
	assert(c._queued_coin_foes == 0 and c._queued_crystal_foes == 0)
	print("PASS: dense queue preserves active wave quota, no loss at cap, one spawn per tick and no premature clear")
	b.queue_free()
	await process_frame
	print("PASS: confirmed typed kills pay once before result; same/no visual ID, fast kills, revive, multipliers and crystal lock; withdrawal/death/backwash never pay")
	Audio.quit_cleanly()
