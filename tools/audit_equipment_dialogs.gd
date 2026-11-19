extends SceneTree
const Home := preload("res://menu/character_home.tscn")
const Detail := preload("res://menu/equip_detail.gd")
const Forge := preload("res://menu/forge_sheet.gd")
const FD := preload("res://shared/forge_data.gd")
const GS := preload("res://shared/game_state.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _find(parent, script):
	for child in parent.get_children():
		if child.get_script() == script and not child.is_queued_for_deletion(): return child
	return null

func _button(parent, label: String) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		if node.text == label: return node
	assert(false, "missing button: " + label)
	return null

func _resources() -> Array:
	return [FD.equipped.duplicate(true), FD.state.duplicate(true), FD.items.duplicate(true), FD.ores, FD.silver]

func _run() -> void:
	GS.ensure_loaded()
	FD.load_game()
	FD._bag_ready = true
	FD.bag = []
	FD.equipped = {"weapon": {"name": "审查短剑", "quality": 1, "plus": 0, "trait": ""}, "armor": {}, "jade": {}, "cloak": {}}
	FD.state = {}
	FD.items = {"龙鳞": 3, "淬火油": 2, "星砂": 2, "悔恨法条": 2}
	FD.ores = 100
	FD.silver = 1000
	assert(FD.save_game() == OK)
	var home = Home.instantiate()
	root.add_child(home)
	home._on_slot("weapon")
	var detail = _find(home, Detail)
	assert(detail != null)
	var detail_closed := [0]
	detail.closed.connect(func(): detail_closed[0] += 1)
	_button(detail, "锻 造").pressed.emit()
	detail._forge()
	detail._sell()
	detail._close()
	assert(detail_closed[0] == 1 and FD.silver == 1000 and not FD.equipped["weapon"].is_empty())
	var forge = _find(home, Forge)
	assert(forge != null)
	await process_frame
	await process_frame # 原角色页重建在此会删除刚打开的锻造窗口。
	assert(is_instance_valid(forge) and not forge.is_queued_for_deletion() and forge.is_inside_tree())
	assert(_find(home, Forge) == forge)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://forge_modal.png") == OK)
	var ov := Control.new()
	forge.add_child(ov)
	forge._confirm_use("龙鳞", 3, ov)
	var confirm := _button(ov, "确 定")
	var cancel := _button(ov, "取 消")
	confirm.pressed.emit()
	confirm.pressed.emit()
	cancel.pressed.emit()
	assert(FD.items["龙鳞"] == 2 and FD.st_of("weapon")["protect"] == 1)
	var cfg := ConfigFile.new()
	assert(cfg.load("user://forge.cfg") == OK and cfg.get_value("res", "items")["龙鳞"] == 2)
	var ov_cancel := Control.new()
	forge.add_child(ov_cancel)
	forge._confirm_use("龙鳞", 2, ov_cancel)
	_button(ov_cancel, "取 消").pressed.emit()
	_button(ov_cancel, "确 定").pressed.emit()
	assert(FD.items["龙鳞"] == 2 and FD.st_of("weapon")["protect"] == 1)
	seed(20261120)
	_button(forge, "锤 一 下").pressed.emit()
	assert(FD.ores == 100 - FD.COST_ORE and FD.silver == 1000 - FD.COST_SILVER)
	assert(not FD.equipped["weapon"].is_empty()) # 龙鳞保护，任何合法随机结果均不销毁。
	var resources := _resources()
	var forge_closed := [0]
	forge.closed.connect(func(): forge_closed[0] += 1)
	_button(forge, "收 下").pressed.emit()
	forge._close()
	forge._hammer()
	forge._use_item("龙鳞")
	forge._open_item("龙鳞")
	assert(forge_closed[0] == 1 and _resources() == resources)
	await process_frame
	await process_frame
	assert(_find(home, Forge) == null)
	home._on_slot("weapon")
	detail = _find(home, Detail)
	var price: int = 40 + int(FD.equipped["weapon"]["plus"]) * 6
	var silver: int = FD.silver
	_button(detail, "卖 出").pressed.emit()
	assert(FD.equipped["weapon"].is_empty() and FD.silver == silver + price)
	FD.equipped["weapon"] = {"name": "新装备", "quality": 1, "plus": 1}
	assert(FD.save_game() == OK)
	detail._sell() # 关闭详情的旧按钮不能卖掉同槽的新装备。
	assert(FD.equipped["weapon"]["name"] == "新装备" and FD.silver == silver + price)
	assert(cfg.load("user://forge.cfg") == OK and cfg.get_value("res", "equipped")["weapon"]["name"] == "新装备")
	home.queue_free()
	await process_frame
	await process_frame
	print("PASS: role -> detail -> forge survives frames; single close/sale; confirm double press and cancel cannot consume twice; closed forge cannot hammer/use; isolated saves verified")
	Audio.quit_cleanly()
