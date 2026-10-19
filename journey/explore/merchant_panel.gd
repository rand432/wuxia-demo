extends Control
# v246：货郎老赵——世界内关系网的第一根线：买卖涨人情，人情压价。
signal closed

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")

const GOODS := [
	{"id": "forge_stone", "n": 3, "base": 30},
	{"id": "atlas", "n": 1, "base": 90},
	{"id": "rice", "n": 2, "base": 24},
	{"id": "bone", "n": 3, "base": 18},
]

var _favor_lb: Label
var _msg_lb: Label
var _goods_lbs: Array = []
var _price_lbs: Array = []
var _buy_btns: Array = []
var _sell_btn: Button
var _rob_btn: Button
var _wash_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.62)
	var panel := UiKit.make_paper_panel(veil, Rect2(50, 280, 620, 720))
	var psb: StyleBoxFlat = UiKit.paper_box(1.0)
	panel.add_theme_stylebox_override("panel", psb)
	var title := UiKit.make_label(panel, Vector2(0, 20), Vector2(620, 46), 34, UiKit.INK)
	UiKit.set_text(title, "货　郎")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_favor_lb = UiKit.make_label(panel, Vector2(0, 70), Vector2(620, 24), 15, UiKit.DIM)
	_favor_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for i in GOODS.size():
		var g: Dictionary = GOODS[i]
		var y := 122.0 + float(i) * 76.0
		var nm := UiKit.make_label(panel, Vector2(40, y), Vector2(210, 34), 19, UiKit.INK)
		UiKit.set_text(nm, GS.mat_name(str(g["id"])) + " ×" + str(g["n"]))
		_goods_lbs.append(nm)
		var pr := UiKit.make_label(panel, Vector2(240, y), Vector2(150, 34), 17, UiKit.DIM)
		_price_lbs.append(pr)
		var b := UiKit.make_button(panel, Vector2(400, y - 4), Vector2(180, 44), "买", 17)
		b.pressed.connect(_buy.bind(i))
		_buy_btns.append(b)

	_sell_btn = UiKit.make_button(panel, Vector2(170, 436), Vector2(280, 46), "卖锻造石 ×5（+15两）", 16)
	_sell_btn.pressed.connect(_sell)
	_rob_btn = UiKit.make_button(panel, Vector2(30, 498), Vector2(260, 46), "拔刀（通缉 +1）", 16)
	_rob_btn.pressed.connect(_rob)
	_wash_btn = UiKit.make_button(panel, Vector2(330, 498), Vector2(260, 46), "洗 白", 16)
	_wash_btn.pressed.connect(_wash)
	_msg_lb = UiKit.make_label(panel, Vector2(40, 556), Vector2(540, 56), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.75))
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := UiKit.make_button(panel, Vector2(210, 630), Vector2(200, 46), "走 了", 18)
	back.pressed.connect(close)
	visible = false

func open() -> void:
	visible = true
	if GS.wanted > 0:
		_msg_lb.text = "老赵把担子掀开一条缝：明面不做，黑市价。"
	else:
		_msg_lb.text = "老赵把担子放下：看看货？"
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _discount() -> float:
	var turf := 0.0
	if GS.red_water == 2:
		if GS.red_water_peace:
			turf = 0.10
		else:
			turf = 0.08 if GS.red_water_market else 0.05
	return minf(0.25, float(GS.merchant_favor) * 0.002 + turf)

func _price(base: int) -> int:
	if GS.wanted > 0:
		return maxi(1, int(round(float(base) * 1.5)))
	return maxi(1, int(round(float(base) * (1.0 - _discount()))))

func _refresh() -> void:
	var d := int(round(_discount() * 100.0))
	var w := GS.wanted
	var turf_txt := " · 青岚地盘" if GS.red_water == 2 else ""
	if w > 0:
		_favor_lb.text = "行商老赵 · 黑市价 +50% · 通缉 " + str(w)
	else:
		_favor_lb.text = "行商老赵 · 人情 " + str(GS.merchant_favor) + " · 价 -" + str(d) + "%" + turf_txt
	for i in GOODS.size():
		var g: Dictionary = GOODS[i]
		var p := _price(int(g["base"]))
		_price_lbs[i].text = str(p) + " 两"
		_buy_btns[i].disabled = GS.coin("silver") < p
	_sell_btn.disabled = GS.material_count("forge_stone") < 5
	_sell_btn.text = "销赃（5锻造石 +20两）" if w > 0 else "卖锻造石 ×5（+15两）"
	_rob_btn.visible = w <= 0
	_wash_btn.visible = w > 0
	if w > 0:
		var cost := 80 * w
		_wash_btn.text = "洗白（" + str(cost) + " 两）"
		_wash_btn.disabled = GS.coin("silver") < cost

func _buy(i: int) -> void:
	if i < 0 or i >= GOODS.size():
		return
	var g: Dictionary = GOODS[i]
	var p := _price(int(g["base"]))
	if GS.coin("silver") < p:
		_msg_lb.text = "银两不够——这价已经压到底了。"
		return
	GS.add_coin("silver", -p)
	GS.add_material(str(g["id"]), int(g["n"]))
	if GS.wanted <= 0:
		GS.merchant_favor = mini(100, GS.merchant_favor + 2)
	GS.save_game()
	if GS.wanted > 0:
		_msg_lb.text = "黑市价买下 " + GS.mat_name(str(g["id"])) + " ×" + str(g["n"]) + "。不记人情。"
	else:
		_msg_lb.text = "买下 " + GS.mat_name(str(g["id"])) + " ×" + str(g["n"]) + "。老赵记了你一份人情。"
	_refresh()

func _rob() -> void:
	if GS.wanted > 0:
		_msg_lb.text = "已经动了手，先洗白再说。"
		return
	var take := 100 + GS.world_tier * 20
	GS.add_coin("silver", take)
	GS.add_material("atlas", 1)
	GS.add_material("forge_stone", 5)
	GS.wanted = mini(5, GS.wanted + 1)
	GS.merchant_favor = 0
	GS.save_game()
	_msg_lb.text = "你拔了刀。老赵丢下担子跑了：银两 +" + str(take) + " · 舆图 +1 · 锻造石 +5 · 通缉 +1。"
	_refresh()

func _wash() -> void:
	if GS.wanted <= 0:
		_msg_lb.text = "你身上没有案子。"
		return
	var cost := 80 * GS.wanted
	if GS.coin("silver") < cost:
		_msg_lb.text = "洗白要 " + str(cost) + " 两——不够。"
		return
	GS.add_coin("silver", -cost)
	GS.wanted = 0
	GS.merchant_favor = maxi(GS.merchant_favor, 10)
	GS.save_game()
	_msg_lb.text = "老赵托人把案子抹平了。通缉清零，人情回到 10。"
	_refresh()

func _sell() -> void:
	if GS.material_count("forge_stone") < 5:
		_msg_lb.text = "锻造石不够五块。"
		return
	GS.add_material("forge_stone", -5)
	if GS.wanted > 0:
		GS.add_coin("silver", 20)
		GS.save_game()
		_msg_lb.text = "五块锻造石走了黑市，换 20 两。不记人情。"
	else:
		GS.add_coin("silver", 15)
		GS.merchant_favor = mini(100, GS.merchant_favor + 1)
		GS.save_game()
		_msg_lb.text = "卖了五块锻造石，换 15 两。"
	_refresh()
