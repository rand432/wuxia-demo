extends Control

# 一次性强制教学层：暂停全场、压暗、只留目标高亮；点目标才继续。
signal done
const Motion := preload("res://shared/ui_motion.gd")

var _on_done: Callable
var _on_pause: Callable
var _on_resume: Callable
var _target: Node = null
var _dim: ColorRect
var _ring: Panel
var _lbl: Label
var _hit: Button

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 80

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.03, 0.62)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_ring = Panel.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)

	_lbl = Label.new()
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_size_override("font_size", 26)
	_lbl.add_theme_color_override("font_color", Color(0.99, 0.93, 0.78))
	_lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04, 0.95))
	_lbl.add_theme_constant_override("outline_size", 8)
	_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl)

	_hit = Button.new()
	_hit.flat = true
	_hit.focus_mode = Control.FOCUS_NONE
	_hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_hit.pressed.connect(_on_pressed)
	add_child(_hit)
	Motion.bind_button(_hit)

	# 跳过：万一玩家没找准高亮目标，也能一次性退出教学，避免"游戏卡住"
	var skip := Button.new()
	skip.text = "跳过"
	skip.position = Vector2(596, 16)
	skip.size = Vector2(104, 44)
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 20)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.12, 0.10, 0.08, 0.92)
	ssb.set_corner_radius_all(8)
	ssb.border_color = Color(0.85, 0.66, 0.23, 0.9)
	ssb.set_border_width_all(2)
	skip.add_theme_stylebox_override("normal", ssb)
	skip.add_theme_stylebox_override("hover", ssb)
	skip.add_theme_stylebox_override("pressed", ssb)
	skip.add_theme_color_override("font_color", Color(0.97, 0.90, 0.74))
	skip.pressed.connect(_on_pressed)
	add_child(skip)
	Motion.bind_button(skip)

func open(target: Node, text: String, on_done: Callable, on_pause := Callable(), on_resume := Callable()) -> void:
	_target = target
	_on_done = on_done
	_on_pause = on_pause
	_on_resume = on_resume
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(1.0, 0.82, 0.30, 0.95)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	_ring.add_theme_stylebox_override("panel", sb)
	_lbl.text = text
	reposition()
	visible = true
	if _on_pause.is_valid():
		_on_pause.call()

func reposition() -> void:
	var gr := get_global_transform().affine_inverse() * _target_rect(_target)
	_ring.position = gr.position - Vector2(8, 8)
	_ring.size = gr.size + Vector2(16, 16)
	_hit.position = gr.position - Vector2(8, 8)
	_hit.size = gr.size + Vector2(16, 16)
	var ly := gr.position.y - 76.0
	if ly < 20.0:
		ly = gr.position.y + gr.size.y + 26.0
	_lbl.position = Vector2(24, ly)
	_lbl.size = Vector2(672, 52)

func _target_rect(t: Node) -> Rect2:
	if t is Control:
		return (t as Control).get_global_rect()
	if t is Node2D:
		var n2 := t as Node2D
		var sz := Vector2(96, 96)
		return Rect2(n2.global_position - sz * 0.5, sz)
	return Rect2()

func _on_pressed() -> void:
	if not visible:
		return
	# 先取出并清空本步回调，信号里打开下一步时不会串用。
	var resume := _on_resume
	var complete := _on_done
	_clear_step()
	if resume.is_valid():
		resume.call()
	done.emit()
	if complete.is_valid():
		complete.call()

# 结算/离场只撤掉教学并恢复处理状态，不执行目标动作或开启下一步。
func cancel() -> void:
	var resume := _on_resume
	_clear_step()
	if resume.is_valid():
		resume.call()

func _clear_step() -> void:
	visible = false
	_target = null
	_on_done = Callable()
	_on_pause = Callable()
	_on_resume = Callable()
