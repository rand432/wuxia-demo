extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _keys(battle) -> Array:
	return battle._eligible_aug_pool().map(func(o): return o["key"])

func _hand(battle) -> Array:
	return battle._aug_cards.map(func(card): return [card.o.duplicate(true), card.oval])

func _state(battle) -> Array:
	return [battle._core.attr.duplicate(true), battle._core.type_attr.duplicate(true), battle._core.kill_heal, battle._gold_pct, battle._exp_pct, battle._mp_max, battle._mp, battle._wen]

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var core = battle._core
	core.set_process(false)
	core.attr_set_base("crit", 0.75)
	core.attr_set_base("cdmg", 4.0)
	core.attr["aspd"]["amp"] = 4.0
	core.kill_heal = 1.0
	core.type_add("物理", "red_f", 0.60)
	var keys := _keys(battle)
	for key in ["crit_add", "critdmg_add", "aspd_pct", "cut_add", "killheal"]: assert(not keys.has(key))
	assert(keys.has("cutall_add")) # 物理满了，其他类型仍有收益。
	for type in core.DMG_TYPES:
		if type != "真实": core.type_attr[type]["red_f"] = 0.60
	assert(not _keys(battle).has("cutall_add"))
	for i in range(20):
		battle._roll_aug()
		var seen := []
		for card in battle._aug_cards:
			assert(card.visible and battle._aug_has_effect(card.o["key"]))
			assert(not seen.has(card.o["key"]))
			seen.append(card.o["key"])
	# 接近上限仍可选，暂时减伤不应使永久减伤进阶失去候选资格。
	core.attr_set_base("crit", 0.74)
	core.attr_set_base("cdmg", 3.99)
	core.attr["aspd"]["amp"] = 0.0
	core.kill_heal = 0.08
	for type in core.DMG_TYPES: core.type_attr[type]["red_f"] = 0.0
	core.hero["curio_cut"] = 0.60
	keys = _keys(battle)
	assert(keys.has("crit_add") and keys.has("critdmg_add") and keys.has("cut_add"))
	core.hero["curio_cut"] = 0.0
	# 隐藏/重开保留同一手；只有候选失效才免费更新。
	battle._str_lv = 10
	battle._str_pending = true
	battle._aug_rolled_lv = -1
	battle._open_aug_pick()
	var hand := _hand(battle)
	battle._hide_aug_pick()
	battle._open_aug_pick()
	assert(_hand(battle) == hand)
	var crit_option: Dictionary = battle.AUG_POOL.filter(func(o): return o["key"] == "crit_add")[0]
	battle._aug_cards[0].o = crit_option.duplicate(true)
	battle._aug_cards[0].oval = 8
	core.attr_set_base("crit", 0.75)
	var rerolls: int = battle._aug_reroll
	battle._on_aug_card(battle._aug_cards[0])
	assert(battle._str_pending and battle._aug_reroll == rerolls)
	for card in battle._aug_cards: assert(card.o["key"] != "crit_add")
	# 一手只接受一次，隐藏回调和结果回调不授予数值。
	battle._on_aug_card(battle._aug_cards[0])
	assert(not battle._str_pending)
	var snapshot := _state(battle)
	battle._on_aug_card(battle._aug_cards[1])
	assert(_state(battle) == snapshot)
	battle._str_pending = true
	battle._str_layer.visible = false
	battle._on_aug_card(battle._aug_cards[1])
	assert(_state(battle) == snapshot)
	# 有既存增幅时即时值采用同一属性层，不先多乘一次。
	core.attr_set_base("atk", 100.0)
	core.attr["atk"]["temp"] = 0.0
	core.attr["atk"]["amp"] = 0.5
	core.hero["atk"] = 150.0
	battle._apply_aug("atk_pct", 15.0)
	assert(is_equal_approx(core.hero["atk"], 165.0) and core.hero["atk"] == core.attr_final("atk"))
	core.attr_set_base("hp", 200.0)
	core.attr["hp"]["temp"] = 0.0
	core.attr["hp"]["amp"] = 0.5
	core.hero["hp_max"] = 300.0
	core.hero["hp"] = 150.0
	battle._apply_aug("hp_pct", 20.0)
	assert(is_equal_approx(core.hero["hp_max"], 340.0) and is_equal_approx(core.hero["hp"], 170.0))
	core.attr["aspd"]["amp"] = 0.5
	core.hero["aspd"] = 1.5
	battle._apply_aug("aspd_pct", 12.0)
	assert(is_equal_approx(core.hero["aspd"], 1.62))
	core.attr_set_base("mp", 100.0)
	core.attr["mp"]["temp"] = 0.0
	core.attr["mp"]["amp"] = 0.0
	battle._mp = 40.0
	battle._apply_aug("mp_add", 60.0)
	assert(battle._mp_max == 160.0 and core.hero["mp_max"] == 160.0 and battle._mp == 40.0)
	battle._run_over = true
	battle._str_layer.visible = true
	snapshot = _state(battle)
	battle._on_aug_card(battle._aug_cards[0])
	assert(_state(battle) == snapshot)
	battle.queue_free()
	await process_frame
	print("PASS: capped aug filters/partial type room/cache invalidation/single claim and immediate additive attribute values")
	Audio.quit_cleanly()
