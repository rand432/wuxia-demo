extends Control
# 战斗加载页：线程加载 battle_ui，加载完直接切（稳定版，不再自己挂战斗）
const BATTLE := "res://kushou/battle_ui.tscn"
const FONT := preload("res://fonts/ink.ttf")
var _fill: ColorRect = null
var _pct: Label = null
var _tip: Label = null
var _done := false
var _recovery: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.048, 0.040, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "江 湖 游 历"
	title.position = Vector2(0, 470)
	title.size = Vector2(720, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.88, 0.78, 0.55))
	add_child(title)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.14, 0.12, 0.10, 1.0)
	bar_bg.position = Vector2(100, 566)
	bar_bg.size = Vector2(520, 18)
	add_child(bar_bg)
	_fill = ColorRect.new()
	_fill.color = Color(0.72, 0.56, 0.24, 1.0)
	_fill.position = Vector2(100, 566)
	_fill.size = Vector2(0, 18)
	add_child(_fill)
	_pct = Label.new()
	_pct.text = "0%"
	_pct.position = Vector2(0, 600)
	_pct.size = Vector2(720, 30)
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct.add_theme_font_override("font", FONT)
	_pct.add_theme_font_size_override("font_size", 18)
	_pct.add_theme_color_override("font_color", Color(0.66, 0.60, 0.48))
	add_child(_pct)
	_tip = Label.new()
	_tip.text = "正在踏入江湖…"
	_tip.position = Vector2(0, 640)
	_tip.size = Vector2(720, 26)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.add_theme_font_override("font", FONT)
	_tip.add_theme_font_size_override("font_size", 15)
	_tip.add_theme_color_override("font_color", Color(0.45, 0.41, 0.34))
	add_child(_tip)
	_recovery = HBoxContainer.new()
	_recovery.position = Vector2(160, 710)
	_recovery.add_theme_constant_override("separation", 24)
	add_child(_recovery)
	for caption in ["重试", "返回主页"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size = Vector2(188, 64)
		button.add_theme_font_override("font", FONT)
		_recovery.add_child(button)
		if caption == "重试":
			button.pressed.connect(_start_loading)
		else:
			button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://menu/main_home.tscn"))
	_start_loading()

func _start_loading() -> void:
	_done = false
	_recovery.hide()
	_tip.text = "正在踏入江湖…"
	if ResourceLoader.load_threaded_request(BATTLE, "", true) != OK:
		_loading_failed()

func _loading_failed() -> void:
	_done = true
	_tip.text = "加载失败，请重试或返回主页"
	_recovery.show()

func _process(_delta: float) -> void:
	if _done:
		return
	var prog: Array = []
	var st := ResourceLoader.load_threaded_get_status(BATTLE, prog)
	var v := float(prog[0]) if prog.size() > 0 else 0.0
	_fill.size = Vector2(520.0 * clampf(v, 0.0, 1.0), 18)
	_pct.text = "%d%%" % int(clampf(v, 0.0, 1.0) * 100.0)
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		_done = true
		var ps: PackedScene = ResourceLoader.load_threaded_get(BATTLE)
		if ps == null or get_tree().change_scene_to_packed(ps) != OK:
			_loading_failed()
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_loading_failed()
