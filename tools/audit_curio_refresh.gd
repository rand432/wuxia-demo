extends SceneTree
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")
class Probe extends "res://kushou/battle_ui.gd":
	var keep := false
	var keep_rolls := 0
	var next_kind := 0
	func _roll_refresh_keep() -> bool:
		keep_rolls += 1
		return keep
	func _roll_wanying_refresh() -> int: return next_kind

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _counts(battle) -> Array:
	return [battle._trea_reroll, battle._aug_reroll, battle._god_reroll, battle._draw_free]

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle := Probe.new()
	root.add_child(battle)
	battle.set_process(false)
	battle._core.set_process(false)
	battle._curio_id = "wanyingfu"
	for lv in range(1, 6):
		battle._curio_lv = lv
		battle._trea_reroll = 3
		battle._aug_reroll = 3
		battle._god_reroll = 0
		battle._draw_free = 0
		battle._curio_apply_static()
		var added: int = [1, 2, 2, 3, 0][lv - 1]
		assert(_counts(battle) == [3 + added, 3 + added, added, added])
		assert(battle._wanying_add == added)
	# 清波新增覆盖四类，五级不再同时获得次数赠送。
	battle._curio_lv = 3
	for kind in range(4):
		var before := _counts(battle)
		battle.next_kind = kind
		battle._curio_on_wave_clear(kind + 1)
		before[kind] += 1
		assert(_counts(battle) == before)
	battle._curio_lv = 5
	var counts := _counts(battle)
	battle._curio_on_wave_clear(5)
	assert(_counts(battle) == counts)
	battle.keep = true
	# 实际三个次数型入口：低级花次数，五级可免耗，0次不能凭空刷新。
	battle._str_layer.visible = true
	battle._str_pending = true
	battle._trea_layer.visible = true
	battle._trea_pending = true
	battle._god_layer.visible = true
	battle._draw_charge = 1
	for lv in [4, 5]:
		battle._curio_lv = lv
		battle._aug_reroll = 2
		battle._trea_reroll = 2
		battle._god_reroll = 2
		battle._on_aug_refresh()
		battle._on_trea_refresh()
		battle._on_god_refresh()
		assert(_counts(battle).slice(0, 3) == ([1, 1, 1] if lv == 4 else [2, 2, 2]))
	battle.keep = false
	battle._on_aug_refresh()
	battle._on_trea_refresh()
	battle._on_god_refresh()
	assert(_counts(battle).slice(0, 3) == [1, 1, 1])
	battle._aug_reroll = 0
	battle._trea_reroll = 0
	battle._god_reroll = 0
	battle.keep = true
	var rolls := battle.keep_rolls
	battle._on_aug_refresh()
	battle._on_trea_refresh()
	battle._on_god_refresh()
	assert(battle.keep_rolls == rolls)
	# 抽卡：免费次数可以在零灵晶时用，但五级免耗须先有支付能力。
	battle._draw_layer.visible = true
	battle._draw_paid = true
	battle._draw_free = 1
	battle._crystal = 0
	battle._refresh_draw_btn()
	assert(battle._draw_refresh_btn.text.contains("免费 1 次"))
	battle._on_refresh()
	await create_timer(0.3).timeout
	assert(battle._draw_free == 0 and battle._crystal == 0 and not battle._draw_anim)
	rolls = battle.keep_rolls
	battle._on_refresh()
	assert(battle.keep_rolls == rolls and not battle._draw_anim)
	battle._crystal = 5
	battle._on_refresh()
	await create_timer(0.3).timeout
	assert(battle._crystal == 5)
	battle.keep = false
	battle._on_refresh()
	await create_timer(0.3).timeout
	assert(battle._crystal == 0)
	# 隐藏界面/结果不刷新，放弃同一请神手牌不重复赠送。
	battle._god_reroll = 2
	battle._god_layer.visible = true
	battle._on_god_abandon()
	battle._on_god_abandon()
	assert(battle._god_reroll == 3)
	battle._on_god_refresh()
	assert(battle._god_reroll == 3)
	battle._run_over = true
	counts = _counts(battle)
	battle._on_refresh()
	battle._on_aug_refresh()
	battle._on_trea_refresh()
	battle._on_god_refresh()
	assert(_counts(battle) == counts)
	battle.queue_free()
	await process_frame
	print("PASS: four refresh grants/selection, exclusive keep mode, real refresh costs, affordability and stale guards")
	Audio.quit_cleanly()
