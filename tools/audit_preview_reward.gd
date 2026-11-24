extends SceneTree
const LS := preload("res://shared/level_state.gd")
const FD := preload("res://shared/forge_data.gd")
const SaveFile := preload("res://shared/save_file.gd")
const Battle := preload("res://kushou/battle_ui.tscn")
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	LS.ensure_loaded()
	FD.load_game()
	var before := FD.ores
	LS.preview = {"lv": 6, "forge": 20}
	assert(LS.take_preview(5).is_empty())
	assert(not LS.preview.is_empty())
	assert(LS.take_preview(6)["forge"] == 20)
	assert(FD.ores == before + 20 and LS.preview.is_empty())
	assert(LS.take_preview(6).is_empty())
	FD._loaded = false
	LS._loaded = false
	FD.load_game()
	LS.ensure_loaded()
	assert(FD.ores == before + 20 and LS.preview.is_empty())
	LS.current_level = 2
	var pending := {"lv": 2, "crystal": 60}
	LS.preview = pending
	LS.save()
	assert(SaveFile.begin() == OK)
	assert(LS.take_preview(2).is_empty() and LS.preview == pending)
	assert(SaveFile.commit() == OK)
	var blocker := ProjectSettings.globalize_path(LS.SAVE_PATH + ".tmp")
	assert(DirAccess.make_dir_absolute(blocker) == OK)
	var battle = Battle.instantiate()
	root.add_child(battle)
	assert(battle._crystal == 100 and LS.preview == pending)
	battle.queue_free()
	await process_frame
	var cfg := ConfigFile.new()
	assert(cfg.load(LS.SAVE_PATH) == OK and cfg.get_value("levels", "preview") == pending)
	assert(DirAccess.remove_absolute(blocker) == OK)
	battle = Battle.instantiate()
	root.add_child(battle)
	assert(battle._crystal == 160 and LS.preview.is_empty())
	battle.queue_free()
	await process_frame
	LS._loaded = false
	LS.ensure_loaded()
	assert(LS.preview.is_empty())
	battle = Battle.instantiate()
	root.add_child(battle)
	assert(battle._crystal == 100)
	battle.queue_free()
	await process_frame
	print("PASS: preview forge reward persists once; battle bonus waits for a durable save and does not repeat")
	quit()
