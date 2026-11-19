extends SceneTree
const UI := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")
const LS := preload("res://shared/level_state.gd")
const FD := preload("res://shared/forge_data.gd")
const Audio := preload("res://shared/audio.gd")
const Detail := preload("res://menu/equip_detail.gd")
class LoadingProbe extends "res://menu/loading.gd":
	var requests := 0
	var fail_request := false
	func _request_battle() -> Error:
		requests += 1
		return ERR_CANT_OPEN if fail_request else OK

var _settled_scene: Node

func _scene_settled() -> void:
	_settled_scene = current_scene

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	scene_changed.connect(_scene_settled)
	call_deferred("_run")

func _scene(path: String):
	for i in range(600):
		if current_scene != null and _settled_scene == current_scene and current_scene.scene_file_path == path: return current_scene
		await process_frame
	assert(false, "navigation timeout: " + path)
	return null

func _button(parent, text: String) -> Button:
	for b in parent.find_children("*", "Button", true, false):
		if b.text == text: return b
	assert(false, "missing button " + text)
	return null

func _snapshot() -> Array:
	return [FD.equipped.duplicate(true), FD.items.duplicate(true), FD.silver, FD.ores]

func _run() -> void:
	GS.ensure_loaded()
	LS.ensure_loaded()
	LS.max_unlocked = 10
	LS.current_level = 6
	var probe := LoadingProbe.new()
	root.add_child(probe)
	current_scene = probe
	probe.set_process(false)
	for i in range(4): probe._start_loading()
	probe._return_home()
	assert(probe.requests == 1 and probe._requesting and current_scene == probe)
	probe._loading_failed()
	probe.fail_request = true
	probe._start_loading()
	assert(probe.requests == 2 and probe._done and probe._recovery.visible)
	probe.fail_request = false
	probe._start_loading()
	probe._start_loading()
	assert(probe.requests == 3 and probe._requesting and not probe._recovery.visible and probe._pct.text == "0%")
	probe._loading_failed()
	probe._return_home()
	probe._return_home()
	probe._start_loading()
	probe._process(1.0)
	assert(probe.requests == 3 and not probe.is_inside_tree())
	var home = await _scene("res://menu/main_home.tscn")
	assert(UI.navigate(home, "res://missing_navigation_audit.tscn") == ERR_FILE_NOT_FOUND)
	assert(UI.navigate_packed(home, null) == ERR_INVALID_PARAMETER and UI.navigation_available(home))
	var stage: int = LS.current_level
	home._on_dock("role")
	home._on_dock("god")
	home._change_stage(1)
	home._start_level()
	assert(LS.current_level == stage and not home.is_inside_tree())
	var role = await _scene("res://menu/character_home.tscn")
	FD.equipped["weapon"] = {"name": "导航审查剑", "quality": 1, "plus": 0}
	role._on_slot("weapon")
	var detail = null
	for child in role.get_children():
		if child.get_script() == Detail: detail = child
	var forge = role._open_forge("weapon")
	var resources := _snapshot()
	UI.open_settings(role)
	var settings = role.get_node("SettingsOv")
	var before := Audio.bgm_volume()
	var symbol := "＋" if before < 0.9 else "－"
	var volume := _button(settings, symbol)
	volume.pressed.emit()
	assert(not is_equal_approx(Audio.bgm_volume(), before))
	_button(settings, "关 闭").pressed.emit()
	var changed := Audio.bgm_volume()
	volume.pressed.emit()
	assert(is_equal_approx(Audio.bgm_volume(), changed))
	await process_frame
	UI.open_settings(role)
	settings = role.get_node("SettingsOv")
	volume = _button(settings, symbol)
	role._on_dock("god")
	detail._sell()
	detail._forge()
	forge._hammer()
	forge._use_item("龙鳞")
	forge._close()
	role._on_slot("weapon")
	volume.pressed.emit()
	UI.open_settings(role)
	assert(_snapshot() == resources and is_equal_approx(Audio.bgm_volume(), changed))
	var partner = await _scene("res://menu/partner_home.tscn")
	partner._on_dock("curio")
	partner._on_dock("start")
	var curio = await _scene("res://menu/curio_home.tscn")
	var equipped: String = GS.curio_id
	curio._on_dock("start")
	curio._on_equip()
	assert(GS.curio_id == equipped)
	home = await _scene("res://menu/main_home.tscn")
	home._stage = 5
	home._start_level()
	home._stage = 0
	home._start_level()
	home._on_dock("role")
	assert(LS.current_level == 6)
	var battle = await _scene("res://kushou/battle_ui.tscn")
	assert(battle._core != null and LS.current_level == 6)
	paused = false
	battle.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	await create_timer(0.5).timeout # 等场景切换/音频的延迟清理完成后再退出引擎。
	print("PASS: loading retry single-flight/failure/back recovery; real four-page navigation and loading->battle; late stage/equipment/settings callbacks inert")
	Audio.quit_cleanly()
