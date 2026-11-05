extends Control
# 关卡选择（照抄参考）：三张关卡卡 + 选择 + 返回
const W := 720.0
const H := 1280.0
const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.96, 0.94, 0.90)
const SEAL := Color(0.55, 0.20, 0.12)
const GOLD := Color(0.78, 0.58, 0.22)
var _sel := 0
var _cards: Array = []

const STAGES := [
	{"no": 1, "name": "城市大街", "state": "尚未解锁", "bg": "res://assets/art/bg/bg_village.jpg"},
	{"no": 2, "name": "废弃边界", "state": "尚未解锁", "bg": ""},
	{"no": 3, "name": "锈蚀工厂", "state": "尚未解锁", "bg": ""},
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.20, 0.17, 0.14)
	add_child(bg)
	# 顶部标题
	var ban := Panel.new()
	ban.position = Vector2(24, 20)
	ban.size = Vector2(200, 56)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.72, 0.36, 0.14, 0.95)
	bsb.set_corner_radius_all(6)
	ban.add_theme_stylebox_override("panel", bsb)
	add_child(ban)
	_label_in(ban, "关 卡 选 择", 24, Color(0.98, 0.94, 0.84), Vector2(28, 12))
	# 三张卡
	for i in 3:
		_cards.append(_make_card(i))
	_style_cards()
	# 底部：上下 + 输入 + 前往
	for i in 2:
		var b := Button.new()
		b.text = "▲" if i == 0 else "▼"
		b.position = Vector2(40.0 + float(i) * 56.0, 1030)
		b.size = Vector2(48, 48)
		b.add_theme_font_size_override("font_size", 18)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_nav.bind(i))
		add_child(b)
	_label_in(self, "请输入关卡数", 17, Color(0.86, 0.82, 0.74), Vector2(470, 1120))
	var go := Button.new()
	go.text = "前往"
	go.position = Vector2(586, 1112)
	go.size = Vector2(96, 40)
	go.add_theme_font_size_override("font_size", 17)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://kushou/battle_ui.tscn"))
	add_child(go)
	# 上一个未完美通关
	_label_in(self, "上一个未完美通关关卡：1.城市大街", 16, Color(0.86, 0.82, 0.74), Vector2(24, 1168))
	# 选择
	var sel := Button.new()
	sel.text = "选 择"
	sel.position = Vector2(160, 1200)
	sel.size = Vector2(400, 70)
	sel.add_theme_font_size_override("font_size", 30)
	sel.focus_mode = Control.FOCUS_NONE
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.86, 0.54, 0.10, 0.98)
	ssb.set_corner_radius_all(6)
	ssb.border_color = Color(0.98, 0.84, 0.48, 0.95)
	ssb.set_border_width_all(3)
	sel.add_theme_stylebox_override("normal", ssb)
	sel.add_theme_stylebox_override("hover", ssb)
	sel.add_theme_stylebox_override("pressed", ssb)
	sel.add_theme_color_override("font_color", Color(0.16, 0.10, 0.04))
	sel.pressed.connect(func() -> void: print("[关卡选择] 选择 ", _sel))
	add_child(sel)

func _make_card(i: int) -> Panel:
	var d: Dictionary = STAGES[i]
	var c := Panel.new()
	c.position = Vector2(24, 100.0 + float(i) * 230.0)
	c.size = Vector2(672, 210)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_sel = i
				_style_cards())
	add_child(c)
	# 缩略图
	# 没有素材：空框里写关卡名
	var th := Panel.new()
	th.position = Vector2(18, 22)
	th.size = Vector2(210, 166)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.88, 0.85, 0.79, 0.9)
	tsb.set_corner_radius_all(4)
	tsb.border_color = Color(0.70, 0.66, 0.60)
	tsb.set_border_width_all(2)
	th.add_theme_stylebox_override("panel", tsb)
	c.add_child(th)
	var nm := Label.new()
	nm.text = str(d["name"])
	nm.add_theme_font_size_override("font_size", 26)
	nm.add_theme_color_override("font_color", Color(0.38, 0.34, 0.28))
	nm.position = Vector2(0, 64)
	nm.size = Vector2(210, 36)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	th.add_child(nm)
	_label_in(c, str(d["no"]) + ". " + str(d["name"]), 26, Color(0.30, 0.27, 0.22), Vector2(250, 8))
	_label_in(c, "?", 18, Color(0.98, 0.88, 0.60), Vector2(268, 14))
	_label_in(c, "当前进度：", 17, Color(0.30, 0.27, 0.22), Vector2(250, 62))
	_label_in(c, str(d["state"]), 17, Color(0.55, 0.30, 0.12), Vector2(380, 62))
	# （三宝箱已按用户要求去掉）
	return c

func _style_cards() -> void:
	for i in _cards.size():
		var c: Panel = _cards[i]
		var on := i == _sel
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.98, 0.95, 0.88, 0.98)
		sb.set_corner_radius_all(4)
		sb.border_color = GOLD if on else Color(0.55, 0.50, 0.44)
		sb.set_border_width_all(4 if on else 2)
		c.add_theme_stylebox_override("panel", sb)

func _on_nav(i: int) -> void:
	_sel = clampi(_sel - 1, 0, 2) if i == 0 else clampi(_sel + 1, 0, 2)
	_style_cards()

func _label_in(parent: Control, t: String, fs: int, col: Color, pos: Vector2) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.size = Vector2(420, fs + 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
