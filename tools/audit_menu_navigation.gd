extends SceneTree
const UI := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")
const LS := preload("res://shared/level_state.gd")
const FD := preload("res://shared/forge_data.gd")
const Audio := preload("res://shared/audio.gd")
const Detail := preload("res://menu/equip_detail.gd")
const GodPortraits := preload("res://shared/god_portraits.gd")
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
	var hero_portrait := role.find_child("HeroPortrait", true, false) as TextureRect
	var hero_portrait_path := hero_portrait.texture.resource_path
	assert(hero_portrait_path == GodPortraits.path_for("zhujue"))
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
	var portrait = partner._cards[1].motion
	assert(portrait.character_id == "zhujue" and portrait._demo_left == 0.0)
	assert(portrait.texture.resource_path == hero_portrait_path)
	partner._on_card_click(2)
	assert(portrait.character_id == "chenshi" and portrait._demo_left > 0.0)
	partner._on_card_click(0)
	assert(portrait.character_id == "zhujue" and portrait._demo_left > 0.0)
	partner._on_dock("curio")
	partner._on_dock("start")
	var curio = await _scene("res://menu/curio_home.tscn")
	var equipped: String = GS.curio_id
	curio._on_dock("start")
	curio._on_equip()
	assert(GS.curio_id == equipped)
	home = await _scene("res://menu/main_home.tscn")
	home._stage = 9
	home._start_level()
	home._stage = 0
	home._start_level()
	home._on_dock("role")
	assert(LS.current_level == 10)
	var loading = await _scene("res://menu/loading.tscn")
	for i in range(600):
		if loading._battle != null: break
		await process_frame
	assert(loading._art_total > 0 and not loading._battle.is_inside_tree())
	var battle = await _scene("res://kushou/battle_ui.tscn")
	assert(battle._core != null and LS.current_level == 10)
	assert(battle._entry_cards_ready and battle._entry_art.is_empty())
	assert(battle._hero_token._frame_atlas != null and battle._skill_frame_art != null)
	if battle._curio_id == "yuhu":
		assert(battle._curio_detail_frame.resource_path == battle.CURIO_DETAIL_FRAME_PATH)
		assert(battle._curio_detail_icon.resource_path == battle.CURIO_DETAIL_ICON_PATH % "yuhu")
	assert(battle._draw_art_cache.values().any(func(art): return art != null))
	for key in ["jiuyou_mojun", "xuehai_luocha", "wanqu_chongmu"]:
		assert(battle._foe_tex_cache[key].resource_path.ends_with("foe_%s.png" % key))
	assert(battle._foe_animation_cache[battle.FINAL_BEAST_FRAME_ID] != null)
	assert(not battle._foe_tex_cache.has("shuangtou_shi"))
	var challenge_atlases := ["challenge_coin_v1", "challenge_crystal_v1", "challenge_scroll_v1"]
	for i in challenge_atlases.size():
		var atlas = battle._foe_animation_cache[challenge_atlases[i]]
		assert(atlas != null and battle._chal_btns[i].art == atlas)
		assert(battle._chal_btns[i].art_region == Rect2(0, 0, 128, 128))
	assert(battle._chal_btns[3].art == battle._foe_animation_cache["challenge_mimic"])
	var eligible := LS.god_ids()
	assert(battle._god_portraits.size() == eligible.size())
	for aid in eligible:
		assert(battle._god_portraits[aid].resource_path == GodPortraits.path_for(aid))
	assert(battle._draw_layer == null and battle._str_layer == null and battle._trea_layer == null and battle._god_layer == null)
	battle._tut.cancel()
	battle._crystal = 40
	battle._draw_tile.pressed.emit()
	var draw_panel: Control = battle._draw_layer
	assert(draw_panel.visible and battle._draw_cards.size() == 3 and battle._crystal == 20)
	battle._draw_charge = 1
	battle._mate_tile.pressed.emit()
	var god_panel: Control = battle._god_layer
	assert(god_panel.visible and not draw_panel.visible and battle._god_root.get_child_count() > 0)
	var god = battle._god_root.get_child(0)
	assert(god.portrait.resource_path.ends_with("portrait_chenshi_ink_v2.webp") and god.skill_art != god.portrait)
	assert(god.portrait == battle._god_portraits[god.aid])
	battle._trea_charge = 1
	battle._trea_tile.pressed.emit()
	var treasure_panel: Control = battle._trea_layer
	assert(treasure_panel.visible and not god_panel.visible and battle._trea_cards.size() == 3 and battle._trea_charge == 0)
	battle._str_pending = true
	battle._str_lv = 10
	battle._open_aug_pick()
	var augment_panel: Control = battle._str_layer
	assert(augment_panel.visible and not treasure_panel.visible and battle._aug_cards.size() == 3)
	for i in range(8): await process_frame
	assert(battle._draw_layer == draw_panel and battle._god_layer == god_panel)
	assert(battle._trea_layer == treasure_panel and battle._str_layer == augment_panel)
	assert(augment_panel.visible and battle._exit_layer != null and battle._combined_layer != null)
	# 剩余两位首次发牌以及刷新，都复用进入战斗时就已持有的纹理。
	for aid in eligible.slice(0, 4):
		battle._ancestors[aid] = 0
	battle._god_hand_charge = -1
	battle._god_reroll = 1
	battle._mate_tile.pressed.emit()
	assert(battle._god_root.get_child_count() == 2)
	var later = battle._god_root.get_child(0)
	assert(later.aid == "gundilong" and later.portrait == battle._god_portraits[later.aid])
	var earlier_texture: Texture2D = later.portrait
	battle._god_refresh_btn.pressed.emit()
	assert(battle._god_reroll == 0 and battle._god_root.get_child(0).portrait == earlier_texture)
	paused = false
	battle.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	await create_timer(0.5).timeout # 等场景切换/音频的延迟清理完成后再退出引擎。
	print("PASS: loading recovery, staged panels, ready challenge and boss textures, and all six god portraits reused")
	Audio.quit_cleanly()
