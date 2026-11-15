extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")
func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 5
	var battle = Battle.instantiate()
	root.add_child(battle)
	battle._crystal = 100
	battle._show_draw(true)
	var first_id := str(battle._draw_cards[0].data.get("_id", ""))
	assert(battle._crystal == 80 and battle._draw_layer.visible)
	battle._show_draw(false)
	battle._show_draw(true)
	assert(battle._draw_layer.visible and battle._crystal == 80)
	assert(str(battle._draw_cards[0].data.get("_id", "")) == first_id)
	battle._cards.resize(10)
	battle._add_card("shiny_zhujue")
	assert(not battle._hero_jianpo)
	assert(not battle._acquired.has("shiny_zhujue"))
	battle._cards.clear()
	battle._draw_paid = true
	battle._draw_layer.visible = true
	battle._add_card("shiny_zl")
	assert(battle._acquired.has("shiny_zl"))
	assert(not battle._draw_paid and not battle._draw_layer.visible)
	var count: int = battle._devoured.size()
	battle._add_card("shiny_zl")
	assert(battle._devoured.size() == count and count == 1)
	await create_timer(0.3).timeout
	battle.queue_free()
	await process_frame
	print("PASS: full deck cannot grant shiny effects; devour claim closes hand and cannot repeat")
	quit()
