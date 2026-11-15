extends SceneTree
const PATH := "user://audit_role_advance.cfg"
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		push_error("此测试必须使用隔离项目")
		quit(2)
		return
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://shared/game_state.gd").replace("user://progress.cfg", PATH)
	assert(script.reload() == OK)
	script._progress_loaded = true
	script.coins = {"wen": 1500}
	script.shards = {"hero": 180}
	script.stars = {"hero": 5}
	assert(not script.advance_role("hero"))
	assert(script.coins["wen"] == 1500 and script.shards["hero"] == 180)
	script.stars["hero"] = 4
	assert(script.advance_role("hero"))
	assert(script.stars["hero"] == 5)
	assert(script.coins["wen"] == 1000 and script.shards["hero"] == 120)
	assert(not script.advance_role("hero"))
	script.skill_books = {"玄品": 2}
	script.skill_lv = {}
	assert(script.upgrade_skill("skill", "玄品"))
	assert(script.skill_lv["skill"] == 1 and script.skill_books["玄品"] == 1)
	assert(script.coins["wen"] == 800)
	# 模拟保存失败，所有扣费和星级应回退。
	script.stars["hero"] = 3
	assert(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp")) == OK)
	assert(not script.advance_role("hero"))
	assert(script.stars["hero"] == 3 and script.coins["wen"] == 800 and script.shards["hero"] == 120)
	assert(not script.upgrade_skill("skill", "玄品"))
	assert(script.skill_lv["skill"] == 1 and script.skill_books["玄品"] == 1 and script.coins["wen"] == 800)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("PASS: advancement and skill upgrade charge once, failed saves roll back")
	quit()
