extends Control
# 主界面 v1（草稿落地）：顶栏货币 / 关卡 / 普通·精英 / 场景 / 提升等级 / 三档宝箱 / 开始游戏 / 底栏4图标
const GameState := preload("res://shared/game_state.gd")
const Ui := preload("res://menu/menu_theme.gd")
const CharacterPanel := preload("res://menu/character_panel.gd")
const Audio := preload("res://shared/audio.gd")
const USE_IMAGE_HOME := true
const OriginalTopBar := preload("res://menu/original_top_bar.gd")
const W := 720.0
const H := 1280.0
const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.96, 0.94, 0.90)
const SEAL := Color(0.55, 0.20, 0.12)
const GOLD := Color(0.78, 0.58, 0.22)
var _diff := 0
var _char_panel: Control = null
var _settings_ov: Control = null
var _wen_lb: Label = null
var _yuan_lb: Label = null
var _last_wen := -1
var _last_yuan := -1
var _diff_hl: Panel = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if USE_IMAGE_HOME:
		_build_image_home()
		set_process(true)
		return
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = PAPER
	add_child(bg)
	# 统一身份顶栏（按用户截图，不加元宝）
	var tb := OriginalTopBar.new()
	add_child(tb)
	tb.profile_pressed.connect(_open_char)
	tb.settings_pressed.connect(_open_settings)
	# 关卡
	var lv := _label("第 1 关 · 村口小道", 34, Color(0.10, 0.09, 0.08), Vector2(40, 116))
	lv.size = Vector2(640, 46)
	var brush: Font = null
	if ResourceLoader.exists(Ui.FONT_BRUSH):
		brush = load(Ui.FONT_BRUSH) as Font
	if brush != null:
		lv.add_theme_font_override("font", brush)
	# 难度
	_diff_btns = []
	for i in 2:
		var b := Button.new()
		b.text = "普 通" if i == 0 else "精 英"
		b.position = Vector2(80.0 + float(i) * 292.0, 210)
		b.size = Vector2(280, 52)
		b.add_theme_font_size_override("font_size", 22)
		if brush != null:
			b.add_theme_font_override("font", brush)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_diff.bind(i))
		add_child(b)
		_diff_btns.append(b)
	_style_diff()
	# 场景图
	# 原主界面的水墨动态画
	if ResourceLoader.exists("res://assets/video/village_loop.ogv"):
		var vid := VideoStreamPlayer.new()
		vid.position = Vector2(140, 300)
		vid.size = Vector2(440, 420)
		vid.expand = true
		vid.stream = load("res://assets/video/village_loop.ogv")
		add_child(vid)
		vid.play()
	# 左右关卡箭头
	for i in 2:
		var arrow := Button.new()
		arrow.text = "«" if i == 0 else "»"
		arrow.position = Vector2(34.0 if i == 0 else 638.0, 452)
		arrow.size = Vector2(48, 100)
		arrow.add_theme_font_size_override("font_size", 46)
		arrow.add_theme_color_override("font_color", Color(0.69, 0.52, 0.22))
		arrow.add_theme_color_override("font_hover_color", Color(0.86, 0.66, 0.26))
		arrow.flat = true
		arrow.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		arrow.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		arrow.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.pressed.connect(_on_stage_arrow.bind(i))
		add_child(arrow)
	# （三档宝箱已按用户要求去掉）
	# 开始游戏
	var go := Button.new()
	go.text = "开始游戏"
	go.position = Vector2(90, 1050)
	go.size = Vector2(540, 90)
	go.add_theme_font_size_override("font_size", 34)
	if brush != null:
		go.add_theme_font_override("font", brush)
	go.focus_mode = Control.FOCUS_NONE
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.95, 0.91, 0.82, 0.98)
	gsb.set_corner_radius_all(6)
	gsb.border_color = Color(0.65, 0.46, 0.20, 0.9)
	gsb.set_border_width_all(2)
	go.add_theme_stylebox_override("normal", gsb)
	go.add_theme_stylebox_override("hover", gsb)
	go.add_theme_stylebox_override("pressed", gsb)
	go.add_theme_color_override("font_color", Color(0.36, 0.20, 0.09))
	go.pressed.connect(_on_start)
	add_child(go)
	# 底栏 4 图标
	var bar := ColorRect.new()
	bar.position = Vector2(0, 1180)
	bar.size = Vector2(W, 100)
	bar.color = Color(0.15, 0.13, 0.12)
	add_child(bar)
	var icons := ["▶", "⚔", "👥", "⚙"]
	for i in 4:
		var b := Button.new()
		b.text = str(icons[i])
		b.position = Vector2(28.0 + float(i) * 174.0, 1192)
		b.size = Vector2(132, 76)
		b.add_theme_font_size_override("font_size", 30)
		b.focus_mode = Control.FOCUS_NONE
		var on := i == 0
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(0.55, 0.20, 0.12, 0.95) if on else Color(0.22, 0.20, 0.19, 0.95)
		sb2.set_corner_radius_all(4)
		sb2.border_color = Color(0.95, 0.82, 0.50, 0.9) if on else Color(0.55, 0.50, 0.44, 0.6)
		sb2.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb2)
		b.add_theme_color_override("font_color", Color(0.98, 0.92, 0.76) if on else Color(0.80, 0.76, 0.68))
		b.pressed.connect(_on_nav.bind(i))
		add_child(b)
	_label("设置", 1, Color(0, 0, 0, 0), Vector2.ZERO)

func _label(t: String, fs: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.size = Vector2(640, fs + 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

var _diff_btns: Array = []

func _style_diff() -> void:
	for i in _diff_btns.size():
		var b: Button = _diff_btns[i]
		var on := i == _diff
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.89, 0.81, 0.66, 0.98) if on else Color(0.96, 0.93, 0.86, 0.98)
		sb.set_corner_radius_all(4)
		sb.border_color = Color(0.55, 0.38, 0.18, 0.9) if on else Color(0.74, 0.65, 0.50, 0.8)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(0.32, 0.18, 0.07) if on else Color(0.44, 0.34, 0.22))

func _on_diff(i: int) -> void:
	_diff = i
	_style_diff()
	if _diff_hl != null:
		_diff_hl.position = Vector2(80.0 if i == 0 else 368.0, 209.0)

func _on_stage_arrow(i: int) -> void:
	print("[主界面] 切换关卡 dir=", i)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://kushou/battle_ui.tscn")

func _tag_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.08, 0.0)
	sb.border_color = Color(0.85, 0.66, 0.23, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	return sb

func _bar_icon(pos: Vector2, kind: String) -> void:
	var ic := TopIcon.new()
	ic.kind = kind
	ic.position = pos
	ic.size = Vector2(24, 24)
	add_child(ic)

class TopIcon extends Control:
	var kind := "coin"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		if kind == "coin":
			draw_circle(c, 10, Color(0.88, 0.69, 0.29))
			draw_circle(c, 4, Color(0.12, 0.10, 0.08))
		elif kind == "yuan":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(10, 0), c + Vector2(0, 10), c + Vector2(-10, 0)]), Color(0.88, 0.69, 0.29))
			draw_circle(c, 3, Color(0.12, 0.10, 0.08))
		else:
			draw_arc(c + Vector2(0, 2), 7, PI, TAU, 16, Color(0.88, 0.69, 0.29), 2.0, true)
			draw_line(c + Vector2(-7, 2), c + Vector2(-7, 8), Color(0.88, 0.69, 0.29), 2.0, true)
			draw_line(c + Vector2(7, 2), c + Vector2(7, 8), Color(0.88, 0.69, 0.29), 2.0, true)
			draw_line(c + Vector2(-4, 9), c + Vector2(4, 9), Color(0.88, 0.69, 0.29), 2.0, true)

# ---------------- 页面入口 ----------------
func _open_char() -> void:
	get_tree().change_scene_to_file("res://menu/character_home.tscn")

func _on_nav(i: int) -> void:
	match i:
		0:
			pass
		1:
			_open_char()
		2:
			get_tree().change_scene_to_file("res://menu/partner_home.tscn")
		3:
			_open_settings()

func _open_settings() -> void:
	if _settings_ov != null and is_instance_valid(_settings_ov):
		return
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.z_index = 70
	add_child(ov)
	_settings_ov = ov
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.02, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var p := Panel.new()
	p.position = Vector2(90, 400)
	p.size = Vector2(540, 360)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.92, 0.85)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(0.85, 0.66, 0.23, 0.75)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	ov.add_child(p)
	var tl := Label.new()
	tl.text = "设 置"
	tl.position = Vector2(30, 22)
	tl.size = Vector2(480, 40)
	tl.add_theme_font_size_override("font_size", 28)
	tl.add_theme_color_override("font_color", INK)
	p.add_child(tl)
	var bgm := Label.new()
	bgm.position = Vector2(40, 100)
	bgm.size = Vector2(180, 36)
	bgm.add_theme_font_size_override("font_size", 20)
	bgm.add_theme_color_override("font_color", INK)
	bgm.text = "背景音乐"
	p.add_child(bgm)
	var bv := Label.new()
	bv.position = Vector2(260, 100)
	bv.size = Vector2(80, 36)
	bv.add_theme_font_size_override("font_size", 20)
	bv.add_theme_color_override("font_color", INK)
	bv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.text = str(int(Audio.bgm_volume() * 100)) + "%"
	p.add_child(bv)
	var sfx := Label.new()
	sfx.position = Vector2(40, 170)
	sfx.size = Vector2(180, 36)
	sfx.add_theme_font_size_override("font_size", 20)
	sfx.add_theme_color_override("font_color", INK)
	sfx.text = "音效"
	p.add_child(sfx)
	var sv := Label.new()
	sv.position = Vector2(260, 170)
	sv.size = Vector2(80, 36)
	sv.add_theme_font_size_override("font_size", 20)
	sv.add_theme_color_override("font_color", INK)
	sv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.text = str(int(Audio.sfx_volume() * 100)) + "%"
	p.add_child(sv)
	var bm := Button.new(); bm.text = "－"; bm.position = Vector2(360, 96); bm.size = Vector2(56, 44); bm.focus_mode = Control.FOCUS_NONE
	bm.add_theme_font_size_override("font_size", 22)
	bm.pressed.connect(func() -> void:
		Audio.set_bgm_volume(clampf(Audio.bgm_volume() - 0.1, 0.0, 1.0))
		bv.text = str(int(Audio.bgm_volume() * 100)) + "%")
	p.add_child(bm)
	var bp := Button.new(); bp.text = "＋"; bp.position = Vector2(426, 96); bp.size = Vector2(56, 44); bp.focus_mode = Control.FOCUS_NONE
	bp.add_theme_font_size_override("font_size", 22)
	bp.pressed.connect(func() -> void:
		Audio.set_bgm_volume(clampf(Audio.bgm_volume() + 0.1, 0.0, 1.0))
		bv.text = str(int(Audio.bgm_volume() * 100)) + "%")
	p.add_child(bp)
	var sm := Button.new(); sm.text = "－"; sm.position = Vector2(360, 166); sm.size = Vector2(56, 44); sm.focus_mode = Control.FOCUS_NONE
	sm.add_theme_font_size_override("font_size", 22)
	sm.pressed.connect(func() -> void:
		Audio.set_sfx_volume(clampf(Audio.sfx_volume() - 0.1, 0.0, 1.0))
		sv.text = str(int(Audio.sfx_volume() * 100)) + "%")
	p.add_child(sm)
	var sp := Button.new(); sp.text = "＋"; sp.position = Vector2(426, 166); sp.size = Vector2(56, 44); sp.focus_mode = Control.FOCUS_NONE
	sp.add_theme_font_size_override("font_size", 22)
	sp.pressed.connect(func() -> void:
		Audio.set_sfx_volume(clampf(Audio.sfx_volume() + 0.1, 0.0, 1.0))
		sv.text = str(int(Audio.sfx_volume() * 100)) + "%")
	p.add_child(sp)
	var cb := Button.new(); cb.text = "关 闭"; cb.position = Vector2(180, 280); cb.size = Vector2(180, 52); cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_size_override("font_size", 20)
	cb.pressed.connect(_close_settings)
	p.add_child(cb)

func _close_settings() -> void:
	if _settings_ov != null and is_instance_valid(_settings_ov):
		_settings_ov.queue_free()
		_settings_ov = null

func _process(_delta: float) -> void:
	if not USE_IMAGE_HOME:
		return
	var w := GameState.coin("wen")
	var y := GameState.coin("yuanbao")
	if w != _last_wen and _wen_lb != null:
		_last_wen = w
		_wen_lb.text = str(w)
	if y != _last_yuan and _yuan_lb != null:
		_last_yuan = y
		_yuan_lb.text = str(y)

func _build_image_home() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/ui/main_home_ref.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# 顶栏动态数字：盖住图上的 0，写 GameState 的值
	_wen_lb = _money_label(Vector2(396, 30), Vector2(64, 36), 22)
	_yuan_lb = _money_label(Vector2(548, 30), Vector2(64, 36), 22)
	_wen_lb.text = str(GameState.coin("wen"))
	_yuan_lb.text = str(GameState.coin("yuanbao"))
	# 热区
	_hot(Rect2(10, 6, 235, 78), _open_char)
	_hot(Rect2(630, 20, 82, 50), _open_settings)
	_hot(Rect2(80, 209, 278, 54), func() -> void: _on_diff(0))
	_hot(Rect2(368, 209, 278, 54), func() -> void: _on_diff(1))
	_hot(Rect2(26, 430, 80, 190), func() -> void: _on_stage_arrow(0))
	_hot(Rect2(614, 430, 80, 190), func() -> void: _on_stage_arrow(1))
	_hot(Rect2(88, 1050, 544, 96), _on_start)
	_hot(Rect2(16, 1180, 172, 90), func() -> void: pass)
	_hot(Rect2(188, 1180, 172, 90), _open_char)
	_hot(Rect2(360, 1180, 172, 90), func() -> void: get_tree().change_scene_to_file("res://menu/partner_home.tscn"))
	_hot(Rect2(532, 1180, 180, 90), _open_settings)
func _cover_digit(x: float, y: float, w: float, h: float) -> void:
	var r := ColorRect.new()
	r.position = Vector2(x, y)
	r.size = Vector2(w, h)
	r.color = Color(0.165, 0.145, 0.13, 1.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func _money_label(pos: Vector2, sz: Vector2, fs: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load("res://fonts/ink.ttf"))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

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
