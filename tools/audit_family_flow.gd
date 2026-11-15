extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const GS := preload("res://shared/game_state.gd")
const LS := preload("res://shared/level_state.gd")
func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")
func _run() -> void:
	GS.ensure_loaded()
	LS.ensure_loaded()
	LS.current_level = 5
	for star in [0, 1]:
		GS.stars["chenshi"] = star
		var battle = Battle.instantiate()
		root.add_child(battle)
		battle._grant_ancestor("chenshi")
		for tier in range(star + 1):
			for index in range(3):
				var id := "chenshi_t%d_%d" % [tier, index]
				assert(battle._pool.has(id), "next family card never entered pool")
				battle._add_card(id)
			assert(battle._ancestor_combos.size() == tier + 1)
			assert(battle._cards.is_empty())
		assert(not battle._pool.has("chenshi_t%d_0" % (star + 1)))
		assert(float(battle._anc_mod["chenshi"]["dmg_pct"]) > 0.0)
		battle.queue_free()
		await process_frame
	GS.stars = {}
	var tutorial = Battle.instantiate()
	root.add_child(tutorial)
	for aid in ["chenshi", "liuqingqing"]:
		tutorial._grant_ancestor(aid)
		for index in range(3):
			tutorial._add_card("%s_t0_%d" % [aid, index])
	assert(tutorial._family_shiny_ready)
	tutorial._roll_draw()
	assert(tutorial._family_shiny_done and not tutorial._family_shiny_ready)
	assert(str(tutorial._draw_cards[0].data.get("_id", "")).begins_with("shiny_"))
	# 引导炫卡不能再次给出已领取或已吞噬的祖宗炫卡。
	tutorial._acquired["shiny_zhujue"] = true
	tutorial._shiny_used["chenshi"] = true
	tutorial._family_shiny_ready = true
	tutorial._roll_draw()
	assert(str(tutorial._draw_cards[0].data.get("_id", "")) == "shiny_liuqingqing")
	tutorial.queue_free()
	await process_frame
	print("PASS: family entry/unlock/three-card merge/next-tier star gate at zero and one star")
	quit()
