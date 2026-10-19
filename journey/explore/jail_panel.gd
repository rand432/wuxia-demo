extends Control
# v248：牢房——败给捕快后的三选一：认罚 / 塞钱 / 越狱。
signal finished

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")

var _wanted := 0
var _sub_lb: Label
var _body_lb: Label
var _result_lb: Label
var _choice_btns: Array = []
var _close_btn: Button
var _resolved := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.66)
	var panel := UiKit.make_paper_panel(veil, Rect2(50, 300, 620, 680))
	var psb: StyleBoxFlat = UiKit.paper_box(1.0)
	panel.add_theme_stylebox_override("panel", psb)
	var title := UiKit.make_label(panel, Vector2(0, 22), Vector2(620, 46), 34, UiKit.INK)
	UiKit.set_text(title, "牢　房")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lb = UiKit.make_label(panel, Vector2(0, 72), Vector2(620, 24), 15, UiKit.DIM)
	_sub_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_lb = UiKit.make_label(panel, Vector2(50, 120), Vector2(520, 120), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.82))
	_body_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var labels := ["认 罚", "塞 钱", "越 狱"]
	for i in 3:
		var b := UiKit.make_button(panel, Vector2(170, 300 + i * 64), Vector2(280, 50), labels[i], 18)
		b.pressed.connect(_on_choice.bind(i))
		_choice_btns.append(b)
	_result_lb = UiKit.make_label(panel, Vector2(50, 470), Vector2(520, 90), 17, UiKit.SEAL)
	_result_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_close_btn = UiKit.make_button(panel, Vector2(210, 600), Vector2(200, 46), "出 狱", 18)
	_close_btn.pressed.connect(_finish)
	_close_btn.visible = false
	visible = false

func open() -> void:
	_wanted = maxi(1, GS.wanted)
	_resolved = false
	_result_lb.text = ""
	_close_btn.visible = false
	for b in _choice_btns:
		(b as Button).visible = true
		(b as Button).disabled = false
	_sub_lb.text = "县衙牢房 · 关押中 · 通缉 " + str(_wanted)
	_body_lb.text = "石墙冰冷，铁栏外有个打盹的老狱卒。\n案卷压在桌上，墨还没干。"
	_choice_btns[0].text = "认罚（" + str(40 * _wanted) + " 两）"
	_choice_btns[1].text = "塞钱（" + str(100 * _wanted) + " 两）"
	_choice_btns[1].disabled = GS.coin("silver") < 100 * _wanted
	_choice_btns[2].text = "越 狱（五五开）"
	visible = true

func _on_choice(i: int) -> void:
	if _resolved:
		return
	_resolved = true
	var msg := ""
	match i:
		0:
			var cost := 40 * _wanted
			var pay := mini(GS.coin("silver"), cost)
			GS.add_coin("silver", -pay)
			GS.wanted = 0
			msg = "你认了罚，交了 " + str(pay) + " 两。案子销了，人也放出来了。"
		1:
			var cost2 := 100 * _wanted
			if GS.coin("silver") < cost2:
				msg = "钱不够——狱卒把银子推了回来。"
				_resolved = false
				return
			GS.add_coin("silver", -cost2)
			GS.wanted = 0
			msg = "银子塞进狱卒袖口，案卷被抽走了。通缉清零。"
		2:
			if randf() < 0.5:
				GS.wanted = mini(5, GS.wanted + 1)
				msg = "你撬开窗棂翻了出去。通缉 +1，但人自由了。"
			else:
				var half := int(GS.coin("silver") / 2)
				GS.add_coin("silver", -half)
				GS.wanted = 0
				msg = "你刚翻上墙就被按了下来。挨了板子，银子去了一半，案子倒压下去了。"
	GS.jailed_days = 0
	GS.save_game()
	_result_lb.text = msg
	for b in _choice_btns:
		(b as Button).visible = false
	_close_btn.visible = true

func _finish() -> void:
	visible = false
	finished.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _resolved:
		get_viewport().set_input_as_handled()
		_finish()
