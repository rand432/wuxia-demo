extends Control
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
var b = null

func _ready() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	b = BATTLE.instantiate(); add_child(b)
	await get_tree().process_frame
	await get_tree().process_frame
	if b._tut != null:
		b._tut.free(); b._tut = null
	var bm = b._bm
	b._kills = 300
	b._open_bm()
	bm.add_kill(60)
	print("[M] 打开 visible=%s 库存=%d 黑市Lv=%d 杀敌=%d" % [str(bm.visible), bm.stock.size(), bm.level, b._kills])
	if bm.stock.size() > 0:
		var offer: Dictionary = bm.stock[0]
		var price: int = bm._offer_price(0)
		var k0: int = b._kills
		var w0: int = bm.warehouse.size()
		bm._buy(0)
		print("[M] 购买 price=%d 杀敌 %d->%d sold=%s 仓库 %d->%d 物品=%s" % [
			price, k0, b._kills, str(bool(offer.get("sold", false))), w0, bm.warehouse.size(),
			str((offer.get("item", {}) as Dictionary).get("name", "?"))])
	get_tree().quit()
