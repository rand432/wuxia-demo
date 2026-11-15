extends SceneTree
const GS := preload("res://shared/game_state.gd")
const AD := preload("res://kushou/ancestor_data.gd")
const Battle := preload("res://kushou/battle_ui.gd")
func _initialize() -> void:
	GS._progress_loaded = true
	GS.stars = {}
	var battle := Battle.new()
	battle._card_db = AD.build()["cards"]
	battle._card_db.merge(AD.shiny_cards())
	for star in range(6):
		GS.stars["zhujue"] = star
		for tier in range(6):
			for index in range(3):
				assert(battle._family_card_allowed("zhujue_t%d_%d" % [tier, index]) == (tier <= star))
		assert(battle._family_card_allowed("shiny_zhujue"))
	# 一个角色的星级不应解锁另一个角色。
	GS.stars = {"zhujue": 5}
	assert(battle._family_card_allowed("qingluan_t0_0"))
	assert(not battle._family_card_allowed("qingluan_t1_0"))
	assert(not GS.family_tier_allowed("zhujue", -1))
	assert(not GS.family_tier_allowed("zhujue", 6))
	battle.free()
	print("PASS: all six stars gate family cards, roles isolated, shiny unchanged")
	quit()
