extends Control
# 入图前的区块选择：初始 3 区块直接进；石 / 雪消耗舆图解锁。

signal entered(region: int)
signal closed

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")

var _sub_lb: Label
var _hint_lb: Label
var _buttons: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.66)
	var panel := UiKit.make_paper_panel(veil, Rect2(40, 150, 640, 940))
	panel.add_theme_stylebox_override("panel", UiKit.paper_box(1.0))
	var title := UiKit.make_label(panel, Vector2(0, 22), Vector2(640, 46), 34, UiKit.INK)
	UiKit.set_text(title, "入　山")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lb = UiKit.make_label(panel, Vector2(0, 74), Vector2(640, 24), 15, UiKit.DIM)
	_sub_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 5:
		var b := UiKit.make_button(panel, Vector2(50, 120 + i * 88), Vector2(540, 76), "", 17)
		b.pressed.connect(_pick.bind(i))
		_buttons.append(b)
	_hint_lb = UiKit.make_label(panel, Vector2(40, 590), Vector2(560, 64), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	_hint_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := UiKit.make_button(panel, Vector2(220, 820), Vector2(200, 46), "回 村", 18)
	back.pressed.connect(close)
	visible = false

func open() -> void:
	visible = true
	_hint_lb.text = "选一个区块进去。石 / 雪要舆图开。"
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func _refresh() -> void:
	var atlas := GS.material_count("atlas")
	_sub_lb.text = "本世界 · 第 " + str(GS.world_tier) + " 档 · 舆图 " + str(atlas) + " 张"
	for i in 5:
		var b: Button = _buttons[i]
		var nm := str(GS.REGION_NAMES[i])
		var diff := int(GS.REGION_DIFFS[i])
		var boss := str(GS.REGION_BOSSES[i])
		if GS.region_unlocked_at(i):
			b.text = nm + " · D" + str(diff) + " · " + boss
		else:
			b.text = nm + " · D" + str(diff) + " · " + boss + " · 需舆图 ×" + str(GS.region_cost(i))

func _pick(i: int) -> void:
	if GS.region_unlocked_at(i):
		entered.emit(i)
		return
	var cost := GS.region_cost(i)
	if GS.material_count("atlas") < cost:
		_hint_lb.text = "舆图不够——开" + str(GS.REGION_NAMES[i]) + "要 " + str(cost) + " 张。"
		return
	GS.add_material("atlas", -cost)
	GS.region_unlocked[i] = true
	GS.save_game()
	_hint_lb.text = str(GS.REGION_NAMES[i]) + " 开了。再点一次进去。"
	_refresh()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
