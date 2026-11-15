extends SceneTree
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")
func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 5
	var warm_nodes := -1
	var warm_orphans := -1
	for cycle in range(5):
		var battle = BATTLE.instantiate()
		root.add_child(battle)
		battle._draw_charge = 2
		battle._pick_god("chenshi")
		battle.queue_free()
		await process_frame
		# 让混音线程完成短音效，回收到池后再取样。
		await create_timer(2.0).timeout
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		print("[LIFECYCLE] cycle=%d nodes=%d orphans=%d pool=%d" % [cycle, nodes, orphans, Audio._sfx_pool.size()])
		if cycle == 1:
			warm_nodes = nodes
			warm_orphans = orphans
		elif cycle > 1:
			assert(nodes <= warm_nodes, "node count grows across scene exits")
			assert(orphans <= warm_orphans, "orphan nodes grow across scene exits")
	print("PASS: five battle exits have stable node and orphan counts after warmup")
	quit()
