extends Control
# v258：势力战报——war_notes 的完整列表（最多 12 条）。
signal closed

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")

var _list_lb: Label
var _sub_lb: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.66)
	var panel := UiKit.make_paper_panel(veil, Rect2(50, 180, 620, 900))
	var psb: StyleBoxFlat = UiKit.paper_box(1.0)
	panel.add_theme_stylebox_override("panel", psb)
	var title := UiKit.make_label(panel, Vector2(0, 20), Vector2(620, 46), 32, UiKit.INK)
	UiKit.set_text(title, "势 力 战 报")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lb = UiKit.make_label(panel, Vector2(0, 70), Vector2(620, 24), 14, UiKit.DIM)
	_sub_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list_lb = UiKit.make_label(panel, Vector2(40, 112), Vector2(540, 560), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.82))
	_list_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := UiKit.make_button(panel, Vector2(210, 800), Vector2(200, 46), "关 闭", 18)
	back.pressed.connect(close)
	visible = false

func open() -> void:
	_sub_lb.text = "共 " + str(GS.war_notes.size()) + " 条 · 战线 " + str(GS.war_score) + "/100" + (" · 已平" if GS.red_water_peace else "")
	if GS.war_notes.is_empty():
		_list_lb.text = "还没有战报。"
	else:
		var lines: Array = []
		for i in range(GS.war_notes.size() - 1, -1, -1):
			lines.append("· " + str(GS.war_notes[i]))
		_list_lb.text = "\n\n".join(PackedStringArray(lines))
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
