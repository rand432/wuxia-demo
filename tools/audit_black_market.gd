extends SceneTree
const Market := preload("res://kushou/black_market.gd")
const Core := preload("res://kushou/kushou_battle.gd")
class UIProbe extends "res://kushou/battle_ui.gd":
	var message := ""
	func _toast(t: String) -> void:
		message = t

func _initialize() -> void:
	var market := Market.new()
	var core := Core.new()
	market.core = core
	market.slots = [{"name": "踏云靴"}]
	var base := core.attr_final("aspd")
	for i in range(10): market._on_kill(1)
	assert(is_equal_approx(core.attr_final("aspd"), base * 1.2))
	market._process(2.1)
	assert(is_equal_approx(core.attr_final("aspd"), base))
	market._on_kill(1)
	market.slots = [null]
	market._remove_item({"name": "踏云靴"})
	assert(is_equal_approx(core.attr_final("aspd"), base) and market._boot_t == 0.0)
	market.level = 5
	assert(market._experience_text() == "已满级")
	for level in range(1, 5):
		market.level = level
		assert(market._experience_text().contains("/"))
	var ui := UIProbe.new()
	ui._core = core
	ui._crystal = 10
	market.ui = ui
	market.warehouse = [{"type": "道具", "effect": "crystal", "value": 30}]
	ui._crystal_lock = true
	market._use_prop(0)
	assert(ui._crystal == 10 and market.warehouse.size() == 1)
	ui._crystal_lock = false
	market._use_prop(0)
	assert(ui._crystal == 40 and market.warehouse.is_empty())
	assert(ui.message == "灵晶 +30")
	core.hero["hp"] = 100.0
	core.hero["hp_max"] = 200.0
	var original_atk := core.attr_final("atk")
	market.slots = [null]
	market.warehouse = [{"name": "test", "kind": "artifact", "stats": {"atk": 7.0, "hp": 50.0, "red": 2.0}}]
	for i in range(20):
		market._take_out(0)
		assert(is_equal_approx(core.hero["hp"], 125.0))
		assert(is_equal_approx(core.attr_final("atk"), original_atk + 7.0))
		market._store(0)
		assert(is_equal_approx(core.hero["hp"], 100.0))
		assert(is_equal_approx(core.attr_final("atk"), original_atk))
		assert(is_zero_approx(core.type_field("物理", "red_f")))
	assert(is_equal_approx(ui._equip_vuln, 0.015))
	ui.free()
	market.free()
	core.free()
	print("PASS: black market level, speed, crystal lock and twenty equipment swap cycles")
	quit()
