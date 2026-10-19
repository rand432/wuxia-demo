extends Control
# v245：荒野 POI 事件（破庙 / 古井 / 茶棚）——一个通用的三选一面板。
signal picked(id: String)
signal closed

const UiKit := preload("res://shared/ui_kit.gd")

var _title_lb: Label
var _sub_lb: Label
var _body_lb: Label
var _result_lb: Label
var _choice_btns: Array = []
var _close_btn: Button
var _choices: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.62)
	var panel := UiKit.make_paper_panel(veil, Rect2(50, 300, 620, 680))
	var psb: StyleBoxFlat = UiKit.paper_box(1.0)
	panel.add_theme_stylebox_override("panel", psb)
	_title_lb = UiKit.make_label(panel, Vector2(0, 22), Vector2(620, 46), 34, UiKit.INK)
	_title_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lb = UiKit.make_label(panel, Vector2(0, 72), Vector2(620, 24), 15, UiKit.DIM)
	_sub_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_lb = UiKit.make_label(panel, Vector2(50, 120), Vector2(520, 120), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.82))
	_body_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_lb = UiKit.make_label(panel, Vector2(50, 360), Vector2(520, 140), 17, UiKit.SEAL)
	_result_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in 3:
		var b := UiKit.make_button(panel, Vector2(170, 300 + i * 64), Vector2(280, 50), "", 18)
		b.pressed.connect(_on_choice.bind(i))
		_choice_btns.append(b)
	_close_btn = UiKit.make_button(panel, Vector2(210, 600), Vector2(200, 46), "离 开", 18)
	_close_btn.pressed.connect(close)
	visible = false

func open(data: Dictionary) -> void:
	_title_lb.text = str(data.get("title", "荒野"))
	_sub_lb.text = str(data.get("sub", ""))
	_body_lb.text = str(data.get("body", ""))
	_result_lb.text = ""
	_choices = data.get("choices", [])
	for i in _choice_btns.size():
		var b: Button = _choice_btns[i]
		if i < _choices.size():
			var c: Dictionary = _choices[i]
			b.text = str(c.get("label", "…"))
			b.visible = true
			b.disabled = false
		else:
			b.visible = false
	_close_btn.text = "离 开"
	visible = true

func set_result(text: String) -> void:
	_result_lb.text = text
	for b in _choice_btns:
		(b as Button).visible = false
	_close_btn.text = "走 了"

func close() -> void:
	visible = false
	closed.emit()

func _on_choice(i: int) -> void:
	if i < 0 or i >= _choices.size():
		return
	picked.emit(str((_choices[i] as Dictionary).get("id", "")))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
