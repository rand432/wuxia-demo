extends SceneTree
const LS := preload("res://shared/level_state.gd")
const FD := preload("res://shared/forge_data.gd")
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
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
	print("PASS: preview forge reward persists once; wrong level cannot consume")
	quit()
