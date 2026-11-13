extends Control
# 加载页直接当战斗的父节点：加载完就把 battle_ui 挂到自己下面，
# 不再 change_scene 二次实例化，首帧硬卡被加载界面盖住。
const BATTLE := "res://kushou/battle_ui.tscn"
const FONT := preload("res://fonts/ink.ttf")
var _ui: Control = null
var _fill: ColorRect = null
var _pct: Label = null
var _tip: Label = null
var _done := false
var _battle = null
var _frames := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.048, 0.040, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(bg)
	var title := Label.new()
	title.text = "江 湖 游 历"
	title.position = Vector2(0, 470)
	title.size = Vector2(720, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.88, 0.78, 0.55))
	_ui.add_child(title)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.14, 0.12, 0.10, 1.0)
	bar_bg.position = Vector2(100, 566)
	bar_bg.size = Vector2(520, 18)
	_ui.add_child(bar_bg)
	_fill = ColorRect.new()
	_fill.color = Color(0.72, 0.56, 0.24, 1.0)
	_fill.position = Vector2(100, 566)
	_fill.size = Vector2(0, 18)
	_ui.add_child(_fill)
	_pct = Label.new()
	_pct.text = "0%"
	_pct.position = Vector2(0, 600)
	_pct.size = Vector2(720, 30)
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct.add_theme_font_override("font", FONT)
	_pct.add_theme_font_size_override("font_size", 18)
	_pct.add_theme_color_override("font_color", Color(0.66, 0.60, 0.48))
	_ui.add_child(_pct)
	_tip = Label.new()
	_tip.text = "正在踏入江湖…"
	_tip.position = Vector2(0, 640)
	_tip.size = Vector2(720, 26)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.add_theme_font_override("font", FONT)
	_tip.add_theme_font_size_override("font_size", 15)
	_tip.add_theme_color_override("font_color", Color(0.45, 0.41, 0.34))
	_ui.add_child(_tip)
	ResourceLoader.load_threaded_request(BATTLE, "", true)
	set_process(true)

func _process(_delta: float) -> void:
	if _done:
		return
	var prog: Array = []
	var st := ResourceLoader.load_threaded_get_status(BATTLE, prog)
	var v := float(prog[0]) if prog.size() > 0 else 0.0
	_fill.size = Vector2(520.0 * clampf(v, 0.0, 1.0), 18)
	_pct.text = "%d%%" % int(clampf(v, 0.0, 1.0) * 100.0)
	if st == ResourceLoader.THREAD_LOAD_LOADED and _battle == null:
		var ps: PackedScene = ResourceLoader.load_threaded_get(BATTLE)
		_battle = ps.instantiate()
		_battle.z_index = -10
		add_child(_battle)
		_frames = 0
		_tip.text = "正在生火造饭…"
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_tip.text = "加载失败，请重试"
	if _frames >= 0:
		_frames += 1
		if _frames >= 4:
			_done = true
			var tw := create_tween()
			tw.tween_property(_ui, "modulate:a", 0.0, 0.35)
			tw.tween_callback(func() -> void: _ui.queue_free())
