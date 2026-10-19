extends Control
# v263：势力战线——赤水前线 + 北境黑风寨（抽象战线 / 出兵 / 决战）。
signal closed

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")

var _red_lb: Label
var _north_lb: Label
var _msg_lb: Label
var _dispatch_btn: Button
var _final_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.64)
	var panel := UiKit.make_paper_panel(veil, Rect2(50, 160, 620, 900))
	panel.add_theme_stylebox_override("panel", UiKit.paper_box(1.0))
	var title := UiKit.make_label(panel, Vector2(0, 20), Vector2(620, 46), 32, UiKit.INK)
	UiKit.set_text(title, "势 力 战 线")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UiKit.make_label(panel, Vector2(0, 70), Vector2(620, 24), 14, UiKit.DIM)
	UiKit.set_text(sub, "两处战线，各自记账")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_red_lb = UiKit.make_label(panel, Vector2(40, 116), Vector2(540, 90), 15, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.78))
	_red_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_north_lb = UiKit.make_label(panel, Vector2(40, 224), Vector2(540, 90), 15, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.78))
	_north_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dispatch_btn = UiKit.make_button(panel, Vector2(130, 340), Vector2(360, 46), "北境出兵（2行动+50两）", 15)
	_dispatch_btn.pressed.connect(_dispatch)
	_final_btn = UiKit.make_button(panel, Vector2(130, 400), Vector2(360, 46), "北境决战（5行动+200两）", 15)
	_final_btn.pressed.connect(_final)
	_msg_lb = UiKit.make_label(panel, Vector2(40, 468), Vector2(540, 80), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.75))
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := UiKit.make_button(panel, Vector2(210, 620), Vector2(200, 46), "关 闭", 18)
	back.pressed.connect(close)
	visible = false

func open() -> void:
	visible = true
	_msg_lb.text = "北境出兵是抽签，胜了涨战线，输了退。"
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func _refresh() -> void:
	var rw: String = str(["未动", "已破", "青岚控制"][clampi(GS.red_water, 0, 2)])
	_red_lb.text = "赤水前线\n" + str(rw) + (" · 已平" if GS.red_water_peace else "") + " · 战线 " + str(GS.war_score) + "/100\n" + ("赤水寨已归青岚。" if GS.red_water_peace else "寨门未平，可去地图拔寨 / 守寨。")
	var north := "北境黑风寨\n战线 " + str(GS.north_score) + "/100 · 小胜 " + str(GS.north_wins) + " 次\n"
	north += "已平" if GS.north_peace else ("可出兵；满 100 开决战。" if GS.north_score < 100 else "可决战。")
	_north_lb.text = north
	_dispatch_btn.disabled = GS.north_peace or GS.action < 2 or GS.coin("silver") < 50
	_final_btn.visible = not GS.north_peace
	_final_btn.disabled = GS.north_score < 100 or GS.action < 5 or GS.coin("silver") < 200

func _dispatch() -> void:
	if GS.north_peace:
		return
	if not GS.action_spend(2) or GS.coin("silver") < 50:
		_msg_lb.text = "行动或银两不够。"
		return
	GS.add_coin("silver", -50)
	if randf() < 0.6:
		GS.north_score = mini(100, GS.north_score + 15)
		GS.north_wins += 1
		GS.add_coin("silver", 80)
		GS.note_war("北境小胜")
		_msg_lb.text = "北境小胜：战线 +15，缴获 80 两。"
	else:
		GS.north_score = maxi(0, GS.north_score - 10)
		GS.note_war("北境失利")
		_msg_lb.text = "北境失利：战线 -10，人退回来了。"
	GS.save_game()
	_refresh()

func _final() -> void:
	if GS.north_peace or GS.north_score < 100:
		return
	if not GS.action_spend(5) or GS.coin("silver") < 200:
		_msg_lb.text = "决战要 5 行动 + 200 两。"
		return
	GS.add_coin("silver", -200)
	if randf() < 0.55:
		GS.north_peace = true
		GS.add_coin("silver", 300)
		GS.add_material("atlas", 2)
		GS.note_war("北境黑风寨平定")
		_msg_lb.text = "北境平定：银两 +300 · 舆图 +2。"
	else:
		GS.north_score = 80
		GS.note_war("北境决战失利")
		_msg_lb.text = "决战失利，北境战线退回 80。"
	GS.save_game()
	_refresh()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
