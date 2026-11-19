extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	for boss_present in [false, true]:
		var b = Battle.instantiate()
		root.add_child(b)
		b.set_process(false)
		var c = b._core
		c.set_process(false)
		b._curio_id = ""
		b._skills.clear()
		c.set_wave(20)
		c.boss_required = true
		if boss_present:
			c.start_boss(LS.boss_tier(), "")
			b._boss_spawned = true
		c._spawn_foe()
		var old: Dictionary = c.foes.back()
		c._hero_pending = old
		c._hero_pending_t = 0.1
		c.queue_delayed(c.hero_pos.x, c.hero_pos.y, 100, 1000, "真实")
		old["rtype"] = "coin"
		b._q_activate(b.QUEST_POOL.filter(func(q): return q["kind"] == "statue")[0])
		var kills: int = b._kills
		var money: int = b._wen
		var epoch: int = c._enemy_attack_epoch
		b._backwash()
		assert(c.wave == 15 and c._enemy_attack_epoch == epoch + 1 and c.foes.is_empty() and c._delayed.is_empty())
		assert(not c.boss_required and not c.boss_alive and not c.boss_spawned_once and not b._boss_spawned)
		assert(c._hero_pending.is_empty() and c._hero_pending_t == -1.0)
		assert(b._q_cur.is_empty() and b._q_fail == 1 and b._kills == kills and b._wen == money and not old.get("_death_settled", false))
		c._wave_spawned = c._wave_quota
		assert(c.wave_cleared())
		b._process(0.0)
		assert(c.wave == 16 and not b._run_over)
		# 再次达到末波：必须重新出首领，打倒前不能提前通关。
		c.set_wave(20)
		c.wave_reset_quota()
		c.foes.clear()
		c._wave_spawned = c._wave_quota
		b._process(0.0)
		assert(c.boss_required and c.boss_alive and c.boss_spawned_once and b._boss_spawned and not b._run_over)
		var boss: Dictionary = c.foes.filter(func(f): return f.get("kind", "") == "boss")[0]
		boss["boss_revive"] = 0
		c._apply_dmg(boss, 100000000.0, "真实")
		c._kill_foe(boss)
		b._process(0.0)
		assert(b._run_over and b._run_cleared)
		b._backwash()
		assert(c.wave == 20) # 结果期间不能重开这一局。
		b.queue_free()
		await process_frame
	print("PASS: backwash resets pre/post boss gates, old foes/attacks/quest without rewards; normal waves advance and final boss respawns before victory")
	Audio.quit_cleanly()
