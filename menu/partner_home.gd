extends Control
# 伙伴页 v3：核心布局 + 只显示武学 + 底栏4图标
const CharArt := preload("res://shared/char_art.gd")
const W := 720.0
const H := 1280.0
const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.96, 0.94, 0.90)
const SEAL := Color(0.55, 0.20, 0.12)
const GOLD := Color(0.78, 0.58, 0.22)
var _plan := 0
var _plan_btns: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/ui/partner_bg.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# 页面标题：请神
	var ban := Panel.new()
	ban.position = Vector2(24, 112)
	ban.size = Vector2(160, 52)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.92, 0.85, 0.72, 0.98)
	bsb.set_corner_radius_all(5)
	bsb.border_color = Color(0.65, 0.46, 0.20, 0.9)
	bsb.set_border_width_all(2)
	ban.add_theme_stylebox_override("panel", bsb)
	add_child(ban)
	var banlb := Label.new()
	banlb.text = "请 神"
	banlb.add_theme_font_size_override("font_size", 24)
	banlb.add_theme_color_override("font_color", Color(0.36, 0.20, 0.09))
	banlb.position = Vector2(34, 10)
	ban.add_child(banlb)
	# 人物卡牌（胸像）
	var art := TextureRect.new()
	art.position = Vector2(150, 104)
	art.size = Vector2(420, 400)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex = CharArt.face("player")
	if tex != null:
		art.texture = tex
	add_child(art)
	# 禁用技能
	_label("禁用技能(0/3)", 18, Color(0.62, 0.55, 0.38), Vector2(240, 516))
	_label("ⓘ", 18, Color(0.62, 0.55, 0.38), Vector2(408, 514))
	# 方案
	_label("方案", 16, Color(0.46, 0.42, 0.36), Vector2(40, 566))
	for i in 3:
		var b := Button.new()
		b.text = str(i + 1)
		b.position = Vector2(100.0 + float(i) * 46.0, 558)
		b.size = Vector2(40, 34)
		b.add_theme_font_size_override("font_size", 17)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_plan.bind(i))
		add_child(b)
		_plan_btns.append(b)
	_style_plan()
	# 总伤害加成 + 禁用编辑
	_label("总伤害加成 0%", 24, Color(0.55, 0.38, 0.12), Vector2(40, 620))
	_label("ⓘ", 20, Color(0.55, 0.48, 0.34), Vector2(300, 620))
	var edit := Button.new()
	edit.text = "禁用编辑"
	edit.position = Vector2(430, 610)
	edit.size = Vector2(250, 54)
	edit.add_theme_font_size_override("font_size", 22)
	edit.focus_mode = Control.FOCUS_NONE
	var esb := StyleBoxFlat.new()
	esb.bg_color = Color(0.94, 0.89, 0.79, 0.98)
	esb.set_corner_radius_all(4)
	esb.border_color = Color(0.65, 0.46, 0.20, 0.9)
	esb.set_border_width_all(2)
	edit.add_theme_stylebox_override("normal", esb)
	edit.add_theme_stylebox_override("hover", esb)
	edit.add_theme_stylebox_override("pressed", esb)
	edit.add_theme_color_override("font_color", Color(0.36, 0.20, 0.09))
	edit.pressed.connect(func() -> void: _set_msg("编辑模式（占位）"))
	add_child(edit)
	# 武学 7 格：4 + 3
	var names := ["落日剑法", "落日剑诀", "", "", "", "", ""]
	for i in 7:
		var r := 0 if i < 4 else 1
		var c := i % 4
		var x := 36.0 + float(c) * 166.0
		var y := 690.0 + float(r) * 168.0
		var cell := Panel.new()
		cell.position = Vector2(x, y)
		cell.size = Vector2(150, 150)
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.99, 0.97, 0.93, 0.95)
		csb.set_corner_radius_all(8)
		csb.border_color = Color(0.70, 0.66, 0.60) if i < 2 else Color(0.80, 0.76, 0.68)
		csb.set_border_width_all(3 if i < 2 else 2)
		cell.add_theme_stylebox_override("panel", csb)
		add_child(cell)
		if i < 2:
			var icon := ColorRect.new()
			icon.position = Vector2(22, 18)
			icon.size = Vector2(106, 100)
			icon.color = Color(0.40, 0.28, 0.16) if i == 0 else Color(0.18, 0.32, 0.50)
			cell.add_child(icon)
			var lv := Label.new()
			lv.text = "1级"
			lv.add_theme_font_size_override("font_size", 15)
			lv.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
			lv.position = Vector2(96, 118)
			lv.size = Vector2(48, 22)
			cell.add_child(lv)
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			cell.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton:
					var mb := ev as InputEventMouseButton
					if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
						_show_skill_popup(i))
	# 整图底栏的透明热区
	_hot(Rect2(10, 6, 240, 76), func() -> void: get_tree().change_scene_to_file("res://menu/main_home.tscn"))
	_hot(Rect2(630, 20, 82, 50), func() -> void: print("[伙伴] 设置"))
	for i in 4:
		_hot(Rect2(float(i) * 180.0, 1180, 180, 100), _on_nav.bind(i))



var _pop: Control = null

func _show_skill_popup(idx: int) -> void:
	if _pop != null:
		_pop.queue_free()
		_pop = null
	var data := [
		{"name": "落日剑法", "lv": 1, "desc": "单剑斜斩，对单个目标造成 150% 伤害。",
		 "attrs": [["伤害", "×1.5", "+0.1"], ["冷却", "20 秒", ""], ["目标", "单体", ""], ["品阶", "固定", ""]],
		 "ups": [[2, "解锁「追击」：暴击后追加一击"], [4, "伤害倍率 ×1.7"], [6, "解锁「破甲」：无视 20% 防御"]]},
		{"name": "落日剑诀", "lv": 1, "desc": "怒气满时释放：四柄长剑自天而降，对最多 4 名敌人各造成 200% 伤害。",
		 "attrs": [["伤害", "200%×4", "+10%"], ["冷却", "60 秒", ""], ["目标", "全体", ""], ["品阶", "绝品", ""]],
		 "ups": [[2, "解锁「剑雨」：额外两柄长剑"], [4, "伤害 200% → 240%"], [6, "解锁「日蚀」：命中降低敌方怒气"]]},
	]
	var d: Dictionary = data[clampi(idx, 0, 1)]
	_pop = Control.new()
	_pop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pop.mouse_filter = Control.MOUSE_FILTER_STOP
	_pop.z_index = 80
	add_child(_pop)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.03, 0.6)
	_pop.add_child(dim)
	var box := Panel.new()
	box.position = Vector2(90, 150)
	box.size = Vector2(540, 780)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.87, 0.99)
	sb.set_corner_radius_all(4)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	_pop.add_child(box)
	# 头部
	var head := Panel.new()
	head.position = Vector2.ZERO
	head.size = Vector2(540, 132)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.74, 0.36, 0.16, 0.95)
	hsb.set_corner_radius_all(4)
	head.add_theme_stylebox_override("panel", hsb)
	box.add_child(head)
	var icon := ColorRect.new()
	icon.position = Vector2(24, 26)
	icon.size = Vector2(80, 80)
	icon.color = Color(0.30, 0.20, 0.12) if idx == 0 else Color(0.16, 0.28, 0.46)
	head.add_child(icon)
	_label_in(head, str(d["name"]), 30, Color(0.98, 0.94, 0.86), Vector2(122, 20))
	_label_in(head, str(d["lv"]) + " 级", 18, Color(0.98, 0.88, 0.66), Vector2(122, 58))
	_label_in(head, str(d["desc"]), 15, Color(0.96, 0.90, 0.80), Vector2(122, 86), 380)
	# 技能属性
	_label_in(box, "技 能 属 性", 18, Color(0.55, 0.36, 0.14), Vector2(24, 150))
	var y := 188.0
	for row_v in d["attrs"]:
		var row: Array = row_v
		_label_in(box, str(row[0]), 17, Color(0.34, 0.31, 0.26), Vector2(40, y))
		_label_in(box, str(row[1]), 18, Color(0.16, 0.14, 0.12), Vector2(300, y))
		if str(row[2]) != "":
			_label_in(box, str(row[2]), 15, Color(0.20, 0.56, 0.30), Vector2(430, y))
		y += 38.0
	# 升级效果
	_label_in(box, "升 级 效 果", 18, Color(0.55, 0.36, 0.14), Vector2(24, y + 10))
	y += 52.0
	for up_v in d["ups"]:
		var up: Array = up_v
		var rowp := Panel.new()
		rowp.position = Vector2(34, y)
		rowp.size = Vector2(472, 54)
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0.88, 0.85, 0.79, 0.9)
		rsb.set_corner_radius_all(3)
		rowp.add_theme_stylebox_override("panel", rsb)
		box.add_child(rowp)
		_label_in(rowp, str(up[0]) + " 级", 17, Color(0.55, 0.30, 0.12), Vector2(16, 14))
		_label_in(rowp, str(up[1]), 15, Color(0.30, 0.27, 0.22), Vector2(96, 15), 360)
		y += 66.0
	# 消耗 + 升级
	_label_in(box, "银两 3000/500", 15, Color(0.34, 0.31, 0.26), Vector2(40, 636))
	_label_in(box, "材料 0/75", 15, Color(0.34, 0.31, 0.26), Vector2(300, 636))
	var up_btn := Button.new()
	up_btn.text = "升 级"
	up_btn.position = Vector2(150, 682)
	up_btn.size = Vector2(240, 64)
	up_btn.add_theme_font_size_override("font_size", 26)
	up_btn.focus_mode = Control.FOCUS_NONE
	var usb := StyleBoxFlat.new()
	usb.bg_color = Color(0.82, 0.50, 0.12, 0.97)
	usb.set_corner_radius_all(4)
	usb.border_color = Color(0.98, 0.84, 0.48, 0.95)
	usb.set_border_width_all(2)
	up_btn.add_theme_stylebox_override("normal", usb)
	up_btn.add_theme_stylebox_override("hover", usb)
	up_btn.add_theme_stylebox_override("pressed", usb)
	up_btn.add_theme_color_override("font_color", Color(0.16, 0.10, 0.04))
	up_btn.pressed.connect(func() -> void: print("[伙伴页] 升武学 ", d["name"]))
	box.add_child(up_btn)
	var close := Button.new()
	close.text = "×"
	close.position = Vector2(486, 8)
	close.size = Vector2(44, 44)
	close.add_theme_font_size_override("font_size", 24)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void:
		if _pop != null:
			_pop.queue_free()
			_pop = null)
	box.add_child(close)

func _label_in(parent: Control, t: String, fs: int, col: Color, pos: Vector2, w := 240.0) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.size = Vector2(w, fs + 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)

func _label(t: String, fs: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.size = Vector2(400, fs + 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _label_inside(parent: Control, t: String, fs: int, pos: Vector2) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(0.30, 0.27, 0.22))
	l.position = pos
	l.size = Vector2(84, 20)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)

func _style_plan() -> void:
	for i in _plan_btns.size():
		var b: Button = _plan_btns[i]
		var on := i == _plan
		var sb := StyleBoxFlat.new()
		sb.bg_color = SEAL if on else Color(0.91, 0.88, 0.82)
		sb.set_corner_radius_all(4)
		sb.border_color = GOLD if on else Color(0.78, 0.73, 0.64)
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", Color(0.96, 0.92, 0.80) if on else Color(0.30, 0.27, 0.22))

func _on_plan(i: int) -> void:
	_plan = i
	_style_plan()

func _set_msg(t: String) -> void:
	print("[伙伴页] ", t)

func _on_nav(i: int) -> void:
	match i:
		0, 3:
			get_tree().change_scene_to_file("res://menu/main_home.tscn")
		1:
			get_tree().change_scene_to_file("res://kushou/battle_ui.tscn")
		_:
			pass

	match i:
		0:
			get_tree().change_scene_to_file("res://menu/main_home.tscn")
		1:
			get_tree().change_scene_to_file("res://menu/character_home.tscn")
		_:
			pass

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
