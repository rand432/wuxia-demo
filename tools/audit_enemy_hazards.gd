extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const Core := preload("res://kushou/kushou_battle.gd")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _pool(core) -> void:
	core.queue_delayed(core.hero_pos.x, core.hero_pos.y, 70.0, 20.0, "真实", 1.0, "pool test", "pool", Vector2.RIGHT, 0.0, 0.0, 0, 0.0, 3.0)

func _active_sound_count(key: String) -> int:
	var count := 0
	for player in Audio._sfx_active:
		if is_instance_valid(player) and player.stream != null and player.stream.resource_path.ends_with("/" + key + ".ogg"):
			count += 1
	return count

func _audit_chain_audio(core) -> bool:
	core.queue_chain(60.0, 70.0, 60.0, 0.0, "真实", "连爆测试", Vector2.RIGHT, 5, 110.0, 0.22)
	assert(_active_sound_count("enemy_warning") == 1 and core._delayed.size() == 5)
	for cast in core._delayed:
		cast["boss_attack"] = true
	core._delayed_tick(3.0)
	assert(core._delayed.is_empty())
	assert(_active_sound_count("boss_impact_chain") == 1 and _active_sound_count("boss_chain_pop") == 1)
	core._hitstop = 0.0
	return true

func _audit_unseen_foes() -> bool:
	LS.current_level = 10
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.foes.clear()
	core.start_boss(4, "困兽·终焉")
	var boss: Dictionary = core._boss_foe()
	core._summon_boss_foes(boss)
	assert(core.foes.size() == 3)
	var entering: Dictionary = core.foes[1]
	var removed: Dictionary = core.foes[2]
	battle._process(0.0)
	var entry_id: int = entering["_tid"]
	var removed_id: int = removed["_tid"]
	assert(core.live_foes() == 3 and battle._foe_tokens.size() == 1)
	assert(not battle._foe_tokens.has(entry_id) and not battle._foe_tokens.has(removed_id))
	entering["hp"] = float(entering["hp_max"]) * 0.5
	removed["hp"] = 0.0
	core._kill_foe(removed)
	removed["y"] = 110.0
	entering["y"] = battle.MIN_VISIBLE_FOE_Y
	battle._process(0.0)
	var token = battle._foe_tokens[entry_id]
	assert(token.visible and entering["_tid"] == entry_id)
	assert(token.hp_ratio == 0.5 and token._hit_t == 0.0 and token._spawn_t <= 0.0)
	assert(not battle._foe_tokens.has(removed_id) and battle._recycle_q.is_empty())
	core.foes.erase(entering)
	battle._process(0.0)
	assert(not battle._foe_tokens.has(entry_id) and battle._recycle_q.size() == 1)
	battle._process(0.5)
	assert(battle._foe_pool.has(token) and not token.visible and not token.is_processing())
	battle.queue_free()
	return true

func _audit_spacing() -> bool:
	var core := Core.new()
	core.size = Vector2(680, 720)
	core.foes = [
		{"x": 100, "y": 180}, {"x": 140, "y": 180},
		{"x": 170, "y": 180, "dying": 0.15}, {"x": 190, "y": 180, "boss": true},
		{"x": 600, "y": 300}, {"x": 656, "y": 300},
	]
	core._separate_foes()
	assert(core.foes.map(func(foe: Dictionary): return int(foe["x"])) == [92, 136, 170, 202, 600, 656])
	assert(typeof(core.foes[2]["x"]) == TYPE_INT and typeof(core.foes[5]["x"]) == TYPE_INT)
	# 第一对推开后，原本不相交的第三只进入间距范围。
	core.foes = [{"x": 100, "y": 180}, {"x": 130, "y": 180}, {"x": 35, "y": 180}]
	core._separate_foes()
	assert(core.foes.map(func(foe: Dictionary): return int(foe["x"])) == [89, 143, 33])
	seed(2211)
	var dx := randf_range(-1.0, 1.0)
	var dy := randf_range(-1.0, 1.0)
	var next := randi()
	var distance := maxf(0.001, sqrt(dx * dx + dy * dy))
	var push := (56.0 - distance) * 0.5
	seed(2211)
	core.foes = [{"x": 30.0, "y": 20.0}, {"x": 30.0, "y": 20.0}]
	core._separate_foes()
	assert(is_equal_approx(core.foes[0]["x"], maxf(30.0, 30.0 - dx / distance * push)))
	assert(is_equal_approx(core.foes[1]["y"], maxf(20.0, 20.0 + dy / distance * push)))
	assert(randi() == next)
	core.free()
	return true

func _audit_guardian(level: int, name: String, atlas_id: String, attack: String, shape: String) -> bool:
	LS.current_level = level
	var battle = Battle.instantiate()
	var path := "res://assets/gen/enemies/frames/%s.png" % atlas_id
	assert(path in battle.prepare_entry_art())
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.start_boss(LS.boss_tier(), name)
	var foe: Dictionary = core._boss_foe()
	foe.merge({"x": 290.0, "y": 290.0}, true)
	battle._process(0.0)
	var boss_bar: Control = battle._boss_bar
	assert(boss_bar.visible and boss_bar.bname == name and boss_bar.ratio == 1.0)
	assert(boss_bar.get_global_rect().end.y <= battle.FIELD_POS.y)
	var token = battle._foe_tokens[foe["_tid"]]
	token.set_process(false)
	assert(token.guardian and token._frame_atlas.resource_path == path)
	assert(battle._boss_spot.get_parent() == battle._cam and battle._boss_veil.get_parent() == battle._cam)
	assert(battle._boss_veil.z_index < battle._boss_spot.z_index
		and battle._boss_spot.z_index < battle._hazard_view.z_index
		and battle._hazard_view.z_index < token.z_index and token.z_index < battle._hero_token.z_index)
	token._process(0.1)
	assert(token._frame_index in range(4))
	foe["x"] += 5.0
	battle._process(0.0)
	token._process(0.1)
	assert(token._frame_index in range(4, 8))
	core.intro_wait = 0.0
	core._hitstop = 0.0
	foe["ult_t"] = 0.0
	core._process(0.016)
	var chained := shape == "chain"
	assert(core._delayed.size() == (5 if chained else 1))
	assert(core._delayed[0]["kind"] == attack and core._delayed[0]["shape"] == ("circle" if chained else shape))
	var landed_steps: Array[int] = []
	if chained:
		core.boss_impact.connect(func(hazard: Dictionary): landed_steps.append(int(hazard["chain_step"])))
		for i in core._delayed.size():
			assert(int(core._delayed[i]["chain_step"]) == i)
	var warn: float = core._delayed[0]["warn"]
	battle._process(0.0)
	token._process(0.016)
	assert(token._frame_index == 8)
	core._delayed_tick(warn * 0.86)
	battle._process(0.0)
	token._process(0.016)
	assert(token._frame_index == 9)
	core._delayed_tick(warn * 0.15)
	token._process(0.09)
	assert(token._frame_index == 10)
	if name == "毒牙蟒":
		assert(not battle._fx_front.skill_trails.is_empty())
	token._process(0.085)
	assert(token._frame_index == 11)
	if chained:
		for i in range(1, 5):
			core._delayed_tick(0.22)
			battle._process(0.0)
			token._process(0.22)
			assert(token.boss_warning.is_empty() and not token._boss_impact and token._frame_index < 8)
		assert(landed_steps == [0, 1, 2, 3, 4] and core._delayed.is_empty())
	core._apply_dmg(foe, float(foe["hp"]) * 0.08, "真实")
	battle._process(0.0)
	assert(boss_bar.ratio < 1.0 and boss_bar.ghost > boss_bar.ratio)
	token._process(0.065)
	assert(token._frame_index == 12)
	token._process(0.03)
	assert(token._frame_index == 13)
	if int(foe.get("boss_summon", 0)) > 0:
		var before: int = core.foes.size()
		core._hitstop = 0.0
		foe["boss_summon_t"] = 0.0
		core._process(0.016)
		assert(core.foes.size() == before + 2 and foe["boss_summon_t"] == 12.0)
	if int(foe.get("boss_revive", 0)) > 0:
		foe["hp"] = 0.0
		core._kill_foe(foe)
		assert(foe["hp"] == float(foe["hp_max"]) * 0.5 and foe["boss_revive"] == 0)
		assert(is_same(core._boss_foe(), foe) and token._death_t < 0.0)
	foe["hp"] = 0.0
	core._kill_foe(foe)
	token._process(0.08)
	assert(token._frame_index == 14)
	token._process(0.18)
	assert(token._frame_index == 15 and token.visible)
	token._process(0.2)
	assert(token.death_finished() and not token.visible)
	battle.queue_free()
	return true

func _audit_crowd_melee(flag: String, title: String, atlas_id: String) -> bool:
	LS.current_level = 6
	var battle = Battle.instantiate()
	var path := "res://assets/gen/enemies/frames/%s.png" % atlas_id
	assert(path in battle.prepare_entry_art())
	root.add_child(battle)
	battle._tut.cancel()
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	seed(186)
	var foe: Dictionary = {}
	for attempt in range(64):
		core.foes.clear()
		foe = core._spawn_foe()
		if bool(foe.get(flag, false)):
			break
	assert(bool(foe.get(flag, false)))
	var origin: Vector2 = core.hero_pos
	foe.merge({"x": origin.x + 24.0, "y": origin.y - 36.0}, true)
	battle._process(0.0)
	var token = battle._foe_tokens[foe["_tid"]]
	token.set_process(false)
	assert(token.unit_name == title and token._frame_atlas.resource_path == path)
	assert(token.challenge_kind == -1 and not token.guardian and not token.round_mask)
	assert(token.z_index < battle._hero_token.z_index - 1)
	token._process(0.1)
	assert(token._frame_index in range(4))
	foe["x"] += 3.0
	battle._process(0.0)
	token._process(0.1)
	assert(token._frame_index in range(4, 8))
	core.running = true
	core.intro_wait = 0.0
	core._hero_cd = 10.0
	core._hitstop = 0.0
	var interval := 1.0 / float(core.FOE_ASPD)
	foe["t"] = interval - 0.17
	core._process(0.02)
	token._process(0.02)
	assert(token._frame_index == 8)
	core._process(0.16)
	token._process(0.016)
	assert(token._frame_index == 10)
	token._process(0.06)
	assert(token._frame_index == 11)
	token._process(0.09)
	core._apply_dmg(foe, float(foe["hp"]) * 0.08, "真实")
	battle._process(0.0)
	token._process(0.016)
	assert(token._frame_index == 12 and token.hp_ratio < 1.0)
	if flag == "shield":
		var feet := Vector2(float(foe["x"]), float(foe["y"]))
		var hp_before: float = foe["hp"]
		core.hero_pos = feet + Vector2(40, 30)
		var blocked: float = core._apply_dmg(foe, 20.0, "物理", 0)
		battle._process(0.0)
		token._process(0.016)
		assert(token._frame_index == 9 and token._sprite.modulate.b > 1.0)
		var guard_fx: Dictionary = battle._fx_front.hits.back()
		assert(guard_fx["guard_side"] == 1.0)
		var effect_count: int = battle._fx_front.hits.size()
		token._process(0.17)
		assert(token._guard_time == 0.0 and token._frame_index != 9)
		foe["hp"] = hp_before
		core.hero_pos = feet + Vector2(40, -30)
		var rear: float = core._apply_dmg(foe, 20.0, "物理", 0)
		assert(is_equal_approx(blocked, rear * 0.55))
		assert(token._guard_time == 0.0 and battle._fx_front.hits.size() == effect_count)
		core.hero_pos = feet + Vector2(40, 30)
		core._apply_dmg(foe, 5.0, "真实", 0)
		assert(token._guard_time == 0.0 and battle._fx_front.hits.size() == effect_count)
	core._apply_dmg(foe, float(foe["hp"]) * 2.0, "真实")
	core._process(0.016)
	assert(bool(foe.get("_death_settled", false)))
	battle._process(0.0)
	token._process(0.08)
	assert(token._frame_index == 14)
	token._process(0.18)
	assert(token._frame_index == 15)
	token._process(0.2)
	assert(token.death_finished() and not token.visible)
	battle.queue_free()
	return true

func _audit_ranged_miss(flag: String, kind: String) -> bool:
	LS.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle._tut.cancel()
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.hero["hp"] = 10000.0
	core.hero["hp_max"] = 10000.0
	core.intro_wait = 0.0
	core._hero_cd = 999.0
	core._last_quota_wave = core.wave
	core._wave_spawned = core._wave_quota
	core._spawn_left = 0
	var foe: Dictionary = core._spawn_foe()
	var hero: Vector2 = core._home
	core.hero_pos = hero
	foe.merge({"x": hero.x - 40.0, "y": hero.y - 40.0, "stop": 78.0,
		"ranged": flag == "ranged", "mage": flag == "mage", "brute": false, "shield": false}, true)
	battle._process(0.0)
	var impact := hero - Vector2(0, 26)
	var effects: Array = battle._fx_front.enemy_attacks
	var missed := false
	for given_seed in range(1, 32):
		effects.clear()
		seed(given_seed)
		foe["blind_t"] = 1.0
		foe["t"] = 1.0 / float(core.FOE_ASPD)
		core._hitstop = 0.0
		var before: float = core.hero["hp"]
		core._process(0.016)
		if core.hero["hp"] == before:
			var trail: Dictionary = effects.back()
			assert(trail["kind"] == kind and trail["missed"] and trail["foe_id"] == foe["_tid"])
			assert(Vector2(trail["target"]).distance_to(impact) > 4.0)
			missed = true
			break
	assert(missed)
	foe.erase("blind_t")
	foe["t"] = 1.0 / float(core.FOE_ASPD)
	var before: float = core.hero["hp"]
	core._process(0.016)
	var hit: Dictionary = effects.back()
	assert(core.hero["hp"] < before and hit["kind"] == kind and not hit.has("missed"))
	assert(Vector2(hit["target"]).distance_to(impact) < 60.0)
	battle.queue_free()
	return true

func _audit_draw_does_not_change_spawn() -> void:
	var core := Core.new()
	core.size = Vector2(680, 720)
	root.add_child(core)
	core.set_process(false)
	core.hide_units = false
	core._shake = 4.0
	var shocked := core._spawn_foe()
	shocked.merge({"x": 300.0, "y": 280.0, "para": 1.0, "flash": 0.2}, true)
	var draw_count := [0]
	core.draw.connect(func(): draw_count[0] += 1)
	await RenderingServer.frame_post_draw
	seed(477)
	var expected := core._spawn_foe()
	core.foes.erase(expected)
	seed(477)
	var draws_before: int = draw_count[0]
	for i in range(3):
		core.queue_redraw()
		await RenderingServer.frame_post_draw
	assert(draw_count[0] == draws_before + 3)
	var actual := core._spawn_foe()
	assert(actual == expected, "Rendering shake, sparks or hit flash changed the next generated enemy")
	core.queue_free()
	await process_frame
	print("[GRAPHICS] repeated redraw preserves generated enemy identity and position")

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.hero["hp_max"] = 1000.0
	core.hero["hp"] = 1000.0
	battle._curio_id = ""
	battle._bm.slots.clear()
	assert(_audit_chain_audio(core))
	_pool(core)
	core._delayed_tick(0.5)
	assert(core.hero["hp"] == 1000.0)
	core._delayed_tick(0.5)
	assert(core.hero["hp"] == 980.0 and core._delayed.size() == 1)
	core._delayed_tick(0.99)
	assert(core.hero["hp"] == 980.0)
	core._delayed_tick(0.01)
	assert(core.hero["hp"] == 970.0)
	core._delayed_tick(2.1)
	assert(core.hero["hp"] == 950.0 and core._delayed.is_empty())
	# 单个长帧跨过预警与持续期也只能结算同样次数。
	core.hero["hp"] = 1000.0
	_pool(core)
	core._delayed_tick(4.5)
	assert(core.hero["hp"] == 950.0 and core._delayed.is_empty())
	# 离开地面范围不受伤，重新进入时仅吃剩余跳数。
	core.hero["hp"] = 1000.0
	_pool(core)
	core._delayed_tick(1.0)
	var position_before: Vector2 = core.hero_pos
	core.hero_pos += Vector2(300.0, 0.0)
	core._delayed_tick(1.0)
	assert(core.hero["hp"] == 980.0)
	core.hero_pos = position_before
	core._delayed_tick(2.0)
	assert(core.hero["hp"] == 960.0 and core._delayed.is_empty())
	# 五级纸人只拦截落下预警，不每秒替持续地面伤害耗一张。
	battle._curio_id = "zhiren"
	battle._curio_lv = 5
	battle._set_paper_count(2)
	core.hero["hp"] = 1000.0
	_pool(core)
	core._delayed.back()["boss_attack"] = true
	core._delayed_tick(1.0)
	assert(core.hero["hp"] == 1000.0 and battle._zhiren == 1)
	core._delayed_tick(1.0)
	assert(core.hero["hp"] == 990.0 and battle._zhiren == 1)
	# 同帧到期时，纸人先拦真正先落地的一段。
	core.clear_enemy_attacks()
	battle._set_paper_count(1)
	var hero: Vector2 = core.hero_pos
	core.queue_delayed(hero.x, hero.y, 70.0, 10.0, "真实", 0.40)
	core.queue_delayed(hero.x, hero.y, 70.0, 30.0, "真实", 0.60)
	for attack: Dictionary in core._delayed:
		attack["boss_attack"] = true
	core.hero["hp"] = 1000.0
	core._delayed_tick(0.65)
	assert(core.hero["hp"] == 970.0 and battle._zhiren == 0)
	core.clear_enemy_attacks()
	battle._curio_id = ""
	battle._set_paper_count(0)
	# 预警致命导致跳波：清空整个旧批次，不能继续用旧索引或再扣一命。
	core.foes.clear()
	core._spawn_foe()
	core.foes[0]["hp"] = 100.0
	core.set_wave(1)
	battle._life = 100
	core.hero["hp"] = 1.0
	var epoch: int = core._enemy_attack_epoch
	core.queue_delayed(core.hero_pos.x, core.hero_pos.y, 70.0, 2000.0, "真实", 1.0)
	_pool(core)
	core._delayed_tick(1.0)
	assert(core.wave == 2 and core._enemy_attack_epoch == epoch + 1)
	assert(core._delayed.is_empty() and core.hero["hp"] == 1000.0)
	assert(battle._life == 99 and battle._curio_waves == 0 and not battle._run_over)
	core._delayed_tick(10.0)
	assert(core.hero["hp"] == 1000.0 and battle._life == 99)
	# 已落地持续伤害触发跳波，也要立刻中止本次长帧的后续跳数。
	core.foes.clear()
	core._spawn_foe()
	core.foes[0]["hp"] = 100.0
	_pool(core)
	core._delayed_tick(1.0)
	core.hero["hp"] = 1.0
	epoch = core._enemy_attack_epoch
	var late_impacts := []
	var remember_impact := func(attack: Dictionary): late_impacts.append(attack["kind"])
	core.boss_impact.connect(remember_impact)
	core.queue_delayed(core.hero_pos.x, core.hero_pos.y, 70.0, 0.0, "真实", 1.50, "后续落点")
	core._delayed.back()["boss_attack"] = true
	core._delayed_tick(3.0)
	assert(core.wave == 3 and core._enemy_attack_epoch == epoch + 1)
	assert(core.hero["hp"] == 1000.0 and core._delayed.is_empty() and battle._life == 98)
	assert(late_impacts.is_empty())
	core.boss_impact.disconnect(remember_impact)
	# 真正保命不跳波，其他地面威胁仍按原规则持续存在。
	battle._curio_id = "zhiren"
	battle._curio_lv = 1
	battle._set_paper_count(1)
	core.hero["hp"] = 1.0
	epoch = core._enemy_attack_epoch
	_pool(core)
	core._delayed_tick(1.0)
	assert(core.wave == 3 and core._enemy_attack_epoch == epoch)
	assert(core._delayed.size() == 1 and battle._zhiren == 0 and core.hero["hp"] == 1000.0)
	# 首领实例必须继承配置里的形态和循环冷却。
	core.clear_enemy_attacks()
	core.foes.clear()
	core._hitstop = 0.0
	core.start_boss(1, "石甲巨猿")
	var boss: Dictionary = core._boss_foe()
	assert(boss["ult_t"] == 15.0 and boss["ult_shape"] == "ring")
	boss["ult_t"] = 0.0
	core._process(0.01)
	assert(boss["ult_t"] == 15.0 and core._delayed.size() == 1)
	var cast: Dictionary = core._delayed[0]
	assert(cast["kind"] == "裂地拳" and cast["shape"] == "ring" and is_same(cast["caster"], boss))
	boss["x"] += 24.0
	core._delayed_tick(0.1)
	assert(cast["x"] == boss["x"] and cast["y"] == boss["y"])
	core.interrupt_cast(boss)
	assert(core._delayed.is_empty())
	# 落地回调打断首领时，已经排入本帧的后续攻击也不能继续结算。
	core.queue_delayed(350.0, 310.0, 50.0, 0.0, "真实", 0.40, "首段")
	core.queue_delayed(350.0, 310.0, 50.0, 0.0, "真实", 0.60, "次段")
	for attack: Dictionary in core._delayed:
		attack["boss_attack"] = true
		attack["caster"] = boss
	var impacts := []
	var interrupt := func(attack: Dictionary):
		impacts.append(attack["kind"])
		core.interrupt_cast(boss)
	core.boss_impact.connect(interrupt)
	core._delayed_tick(0.70)
	assert(core._delayed.is_empty() and impacts == ["首段"])
	core.boss_impact.disconnect(interrupt)
	# 号令使用首领的额外名额，只移动这轮实际新生的敌人。
	core.foes.clear()
	core.start_boss(4, "困兽·终焉")
	boss = core._boss_foe()
	boss["x"] = 60.0
	core.intro_wait = 0.0
	for i in range(core.MAX_FOES - 1):
		assert(not core._spawn_foe().is_empty())
	var sentinel: Dictionary = core.foes.back()
	sentinel["y"] = 325.0
	core._hitstop = 0.0
	boss["boss_summon_t"] = 0.0
	core._process(0.01)
	assert(core.foes.size() == core.MAX_FOES + 2 and float(sentinel["y"]) > 320.0)
	assert(core.foes[-2]["y"] == -30.0 and core.foes[-1]["y"] == -70.0,
		"Summons should remain at their entry positions during their spawn tick: %s" % str(core.foes.slice(-2)))
	assert(core._banner.contains("2 只") and boss["boss_summon_t"] == 12.0)
	var first_summon: Dictionary = core.foes[-2]
	core._process(0.016)
	assert(float(first_summon["y"]) > -30.0 and float(first_summon["y"]) < -20.0)
	while core.foes.size() < core.BOSS_SUMMON_FIELD_CAP - 1:
		assert(not core._spawn_foe("chal").is_empty())
	boss["boss_summon_t"] = 0.0
	core._process(0.01)
	assert(core.foes.size() == core.BOSS_SUMMON_FIELD_CAP and core._banner.contains("1 只"))
	core._banner = ""
	boss["boss_summon_t"] = 0.0
	core._process(0.01)
	assert(core.foes.size() == core.BOSS_SUMMON_FIELD_CAP and core._banner.is_empty())
	assert(core._spawn_foe().is_empty() and float(sentinel["y"]) > 320.0)
	battle.queue_free()
	await process_frame
	for guardian in [
		[1, "看门恶犬", "kanmen_quan_v1", "狂吠震地", "circle"],
		[1, "铁背苍狼", "tiebei_lang_v1", "冲撞", "beam"],
		[1, "毒牙蟒", "duya_mang_v1", "毒雾喷吐", "follow"],
		[1, "石甲巨猿", "shijia_yuan", "裂地拳", "ring"],
		[4, "双头狮", "shuangtou_shi_v1", "狮吼", "sector"],
		[4, "独眼狱卒", "duyan_yuzu_v1", "铁链横扫", "beam"],
		[4, "火尾狐妖", "huowei_hu_v1", "焚身爆", "chain"],
		[4, "赤焰蛟", "chiyan_jiao_v1", "烽火连天", "chain"],
		[7, "场主亲养·狴犴", "bian_v1", "断罪一击", "sector"],
		[7, "血手判官", "xueshou_panguan_v1", "血海", "chain"],
		[7, "困兽之主", "kunshou_zhu_v1", "万兽奔踏", "beam"],
		[7, "幽冥判官", "youming_panguan_v1", "幽冥斩", "sector"],
		[10, "九幽魔君", "jiuyou_mojun_v1", "九幽落雷", "chain"],
		[10, "血海罗刹", "xuehai_luocha_v1", "血浪滔天", "ring"],
		[10, "万蛊虫母", "wanqu_chongmu_v1", "万蛊噬心", "follow"],
		[10, "困兽·终焉", "kunshou_zhongyan_v1", "万兽终章", "sector"],
	]:
		assert(_audit_guardian(guardian[0], guardian[1], guardian[2], guardian[3], guardian[4]))
		await process_frame
	assert(_audit_spacing())
	await process_frame
	assert(_audit_unseen_foes())
	await process_frame
	assert(_audit_crowd_melee("brute", "山匪壮汉", "crowd_brute_v1"))
	await process_frame
	assert(_audit_crowd_melee("shield", "山匪盾兵", "crowd_shield_v1"))
	await process_frame
	assert(_audit_ranged_miss("ranged", "bow"))
	await process_frame
	assert(_audit_ranged_miss("mage", "mage"))
	await process_frame
	print("[RANGED] blinded bow and spell attacks miss visually without damage; unblinded attacks hit the hero")
	if DisplayServer.get_name() != "headless":
		await _audit_draw_does_not_change_spawn()
	print("PASS: hazard chronology, bounded summons, guardian and crowd melee poses, shield guard, separation and token allocation")
	Audio.quit_cleanly()
