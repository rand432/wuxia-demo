extends SceneTree
const UI := preload("res://shared/ui_kit.gd")
const FD := preload("res://shared/forge_data.gd")
const GS := preload("res://shared/game_state.gd")
const Detail := preload("res://menu/equip_detail.gd")
const Audio := preload("res://shared/audio.gd")
class RoleProbe extends "res://menu/character_home.gd":
	var builds: Array = []
	func _build_all() -> void:
		builds.append(is_inside_tree())
		super._build_all()

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _detail_of(page):
	for child in page.get_children():
		if child.get_script() == Detail and not child.is_queued_for_deletion(): return child
	return null

func _run() -> void:
	GS.ensure_loaded()
	FD.load_game()
	FD.equipped["weapon"] = {"name": "刷新审查剑", "quality": 1, "plus": 0}
	assert(FD.save_game() == OK)
	var page := RoleProbe.new()
	root.add_child(page)
	current_scene = page
	page._open_detail()
	var old_panel = page._detail
	assert(old_panel.visible)
	var attack: float = old_panel._h("atk", 0.0)
	page._on_slot("weapon")
	var detail = _detail_of(page)
	assert(detail != null)
	FD.equipped["weapon"]["plus"] = 5
	assert(FD.save_game() == OK)
	detail._close()
	page._rebuild()
	page._rebuild()
	await process_frame
	await process_frame
	assert(not is_instance_valid(old_panel))
	page._open_detail()
	assert(is_instance_valid(page._detail) and page._detail.visible, "attribute panel must reopen after equipment refresh")
	assert(page._detail._h("atk", 0.0) > attack)
	assert(page.builds == [true, true], "same-frame refreshes must coalesce")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://equipment_refresh_attributes.png") == OK)
	page._detail.close()
	page._rebuild()
	page._on_slot("weapon")
	page._open_detail()
	assert(_detail_of(page) == null and not page._detail.visible)
	await process_frame
	await process_frame
	page._on_slot("weapon")
	detail = _detail_of(page)
	assert(detail != null)
	detail._close()
	var observations: Array = page.builds
	var before := observations.size()
	assert(UI.navigate(page, "res://menu/main_home.tscn") == OK)
	page._rebuild()
	page._open_detail()
	await scene_changed
	assert(observations.size() == before and not observations.has(false), "detached page must not rebuild")
	current_scene.queue_free()
	current_scene = null
	await process_frame
	print("PASS: attribute details reopen with updated equipment after refresh; duplicate refreshes coalesce; pending dialog actions and detached rebuilds inert")
	Audio.quit_cleanly()
