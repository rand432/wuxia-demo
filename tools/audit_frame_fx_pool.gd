extends SceneTree

const Battle := preload("res://kushou/battle_ui.tscn")
const Levels := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	Levels.ensure_loaded()
	Levels.current_level = 6
	var battle = Battle.instantiate()
	root.add_child(battle)
	await process_frame
	battle._tut.cancel()
	battle.set_process(false)
	battle._core.set_process(false)
	var effects: Array[Sprite2D] = []
	for i in battle.FRAME_FX_AMBIENT_LIMIT:
		effects.append(battle._spawn_frame_burst(0, Vector2(i, 300), 1.0, 0.2))
	assert(effects.all(func(effect): return effect != null))
	assert(battle._spawn_frame_burst(0, Vector2.ZERO, 1.0, 0.2) == null)
	for i in battle.FRAME_FX_LIMIT - battle.FRAME_FX_AMBIENT_LIMIT:
		battle._skill_fx("金系", Vector2(i, 300))
	assert(battle._frame_fx_live == battle.FRAME_FX_LIMIT)
	assert(battle._spawn_frame_burst(0, Vector2.ZERO, 1.0, 0.2, 0.0, battle._dragon_wave_art, true) == null)
	effects[0].flip_h = true
	await create_timer(0.50).timeout
	assert(battle._frame_fx_live == 0 and battle._frame_fx_pool.size() == battle.FRAME_FX_LIMIT)
	assert(effects.all(func(effect): return not effect.visible and not effect.is_processing() and effect.texture == null))
	var child_count: int = battle._cam.get_child_count()
	var reused: Array[Sprite2D] = []
	for i in battle.FRAME_FX_LIMIT:
		var burst: Sprite2D = battle._spawn_frame_burst(2, Vector2(120, 300), 0.8, 0.2, 0.4, battle._skill_frame_art, true)
		assert(burst != null and burst.visible and burst.is_processing() and not burst.flip_h)
		assert(burst._shown == 0 and burst.modulate.a == 1.0 and burst.region_rect.position.y == burst.region_rect.size.y * 2.0)
		assert(burst.get_index() == child_count - 1 and not reused.has(burst))
		reused.append(burst)
	assert(battle._cam.get_child_count() == child_count and reused.has(effects[0]))
	battle.queue_free()
	await process_frame
	assert(reused.all(func(effect): return not is_instance_valid(effect)))
	print("PASS: skill frames retain four slots under saturation; 16 sprites reuse safely and release on scene exit")
	Audio.quit_cleanly()
