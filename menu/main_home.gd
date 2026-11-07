extends Control
# 主界面：整屏贴图 assets/art/ui/main_home_ref.png ＋ 一层透明热区；
#   顶栏两个数字由 GameState 覆盖到图上；难度/关卡箭头/开始/底栏都靠 _hot() 接。
const GameState := preload("res://shared/game_state.gd")
const Audio := preload("res://shared/audio.gd")
const INK := Color(0.14, 0.13, 0.15)
var _diff := 0
var _settings_ov: Control = null
var _wen_lb: Label = null
var _yuan_lb: Label = null
var _last_wen := -1
var _last_yuan := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_image_home()
	set_process(true)

func _on_diff(i: int) -> void:
	_diff = i

func _on_stage_arrow(i: int) -> void:
	print("[主界面] 切换关卡 dir=", i)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://kushou/battle_ui.tscn")

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
