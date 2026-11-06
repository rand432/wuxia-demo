extends Control
# 角色页新壳：整图顶栏/底栏 + 纸面装备/背包/属性

const CharArt := preload("res://shared/char_art.gd")
const W := 720.0
const H := 1280.0
const INK := Color(0.12, 0.11, 0.10)
const PAPER := Color(0.96, 0.93, 0.86)
const GOLD := Color(0.66, 0.48, 0.20)
const F := preload("res://fonts/ink.ttf")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/ui/partner_bg.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# 返回
	_button(Rect2(18, 108, 48, 44), "←", func() -> void: get_tree().change_scene_to_file("res://menu/main_home.tscn"))
	_label("角 色", Vector2(82, 108), 36, INK, 240)
	# 人物
	var art := TextureRect.new()
	art.position = Vector2(196, 152)
	art.size = Vector2(328, 520)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = CharArt.full("player")
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	# 四件装备
	_slot(Rect2(36, 196, 150, 76), "武 器")
	_slot(Rect2(534, 196, 150, 76), "护 甲")
	_slot(Rect2(36, 438, 150, 76), "玉 佩")
	_slot(Rect2(534, 438, 150, 76), "鞋 子")
	# 背包
	_label("背 包", Vector2(36, 646), 22, Color(0.38, 0.32, 0.24), 200)
	for i in 10:
		var r := 0 if i < 5 else 1
		var c := i % 5
		_slot(Rect2(36.0 + float(c) * 132.0, 684.0 + float(r) * 96.0, 120, 84), "")
	# 属性
	_label("属 性", Vector2(36, 894), 22, Color(0.38, 0.32, 0.24), 200)
	_label("攻击  25", Vector2(40, 936), 20, INK, 180)
	_label("气血  100", Vector2(300, 936), 20, INK, 180)
	_label("防御  5", Vector2(40, 978), 20, INK, 180)
	_label("速度  10", Vector2(300, 978), 20, INK, 180)
	# 升级 / 锻造
	_button(Rect2(40, 1036, 300, 64), "升 级", func() -> void: _msg("升级（待接入）"))
	_button(Rect2(380, 1036, 300, 64), "锻 造", func() -> void: _msg("锻造（待接入）"))
	# 底栏热区（底图自带）
	_hot(Rect2(10, 6, 240, 80), func() -> void: get_tree().change_scene_to_file("res://menu/main_home.tscn"))
	_hot(Rect2(630, 20, 82, 50), func() -> void: _msg("设置"))
	_hot(Rect2(0, 1180, 180, 100), func() -> void: get_tree().change_scene_to_file("res://menu/main_home.tscn"))
	_hot(Rect2(180, 1180, 180, 100), func() -> void: pass)
	_hot(Rect2(360, 1180, 180, 100), func() -> void: get_tree().change_scene_to_file("res://menu/partner_home.tscn"))
	_hot(Rect2(540, 1180, 180, 100), func() -> void: _msg("设置"))

func _label(t: String, pos: Vector2, fs: int, col: Color, w: float) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = Vector2(w, fs + 10)
	l.add_theme_font_override("font", F)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _slot(rect: Rect2, text: String) -> void:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.94, 0.87, 0.96)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.72, 0.58, 0.34, 0.75)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	if text != "":
		var l := Label.new()
		l.text = text
		l.position = Vector2(0, 20)
		l.size = Vector2(rect.size.x, 36)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", F)
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(0.46, 0.35, 0.20))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)

func _button(rect: Rect2, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", F)
	b.add_theme_font_size_override("font_size", 24 if rect.size.x > 100 else 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.88, 0.76, 0.98)
	sb.set_corner_radius_all(5)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.36, 0.20, 0.09))
	b.pressed.connect(cb)
	add_child(b)

func _hot(rect: Rect2, cb: Callable) -> void:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	add_child(b)

func _msg(t: String) -> void:
	print("[角色] ", t)
