extends Control
# 引子过场：村长第一句 → 是否跳过剧情
#   · 画面沿用教学关那套：纸背+远山+圆盘立绘（TokenActor），不摆照片立绘
signal finished(skipped: bool)
const GS := preload("res://shared/game_state.gd")
const TokenActor := preload("res://kushou/token_actor.gd")
const CharArt := preload("res://shared/char_art.gd")
const UI_FONT := preload("res://fonts/ink.ttf")
const W := 720.0
const H := 1280.0
const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.93, 0.90, 0.83)
const SEAL := Color(0.68, 0.15, 0.12)
const GOLD := Color(0.86, 0.68, 0.26)
var _bg: Control
var _actors: Node2D
var _dlg: Panel
var _name_lb: Label
var _text_lb: Label
var _next_btn: Button
var _skip_panel: Control
var _portrait: Node2D
var _lines: Array = [
	{"who": "村长", "text": "孩子，你是屠龙一脉的传人。"},
	{"who": "村长", "text": "可这世上，已三百年没有龙了。你家的屠龙术，早成了废纸。"},
	{"who": "少侠", "text": "我知道。可我还是想出去看看。"},
	{"who": "村长", "text": "昨夜山里起了雾，雾里有东西在叫——像龙。"},
]
var _idx := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 背景与战斗关同一套：纸背 + 远山 + 地面
	_bg = Control.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.draw.connect(_draw_bg)
	add_child(_bg)
	_actors = Node2D.new()
	_actors.z_index = 2
	add_child(_actors)
	# 场上不再摆圆牌：只留水墨场景 + 对话框圆牌头像
	_dlg = Panel.new()
	_dlg.position = Vector2(30, 950)
	_dlg.size = Vector2(660, 280)
	_dlg.z_index = 5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.965, 0.947, 0.902, 0.98)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.72, 0.58, 0.25, 0.85)
	sb.set_border_width_all(2)
	_dlg.add_theme_stylebox_override("panel", sb)
	add_child(_dlg)
	_portrait = TokenActor.new()
	_portrait.set_role("player")
	_portrait.fit_height = 150.0
	_portrait.setup(CharArt.face("player"), 58.0, GOLD, true)
	_portrait.position = Vector2(92, 1006)
	_portrait.z_index = 6
	add_child(_portrait)
	_name_lb = _mk(24, SEAL)
	_name_lb.position = Vector2(160, 20)
	_name_lb.size = Vector2(200, 34)
	_dlg.add_child(_name_lb)
	_text_lb = _mk(19, Color(0.18, 0.16, 0.14))
	_text_lb.position = Vector2(160, 62)
	_text_lb.size = Vector2(478, 130)
	_text_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg.add_child(_text_lb)
	_next_btn = Button.new()
	_next_btn.text = "继 续"
	_next_btn.position = Vector2(480, 216)
	_next_btn.size = Vector2(160, 48)
	_next_btn.add_theme_font_size_override("font_size", 17)
	_next_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.pressed.connect(_on_next)
	_ink(_next_btn)
	_dlg.add_child(_next_btn)
	_show_line()

func _token(role: String, x: float, y: float, h: float, ring: Color, tex_path: String = "") -> Node2D:
	var t = TokenActor.new()
	t.set_role(role)
	t.weapon_type = "sword"
	t.fit_height = h
	var tex: Texture2D = CharArt.face(role) if tex_path == "" else load(tex_path)
	t.setup(tex, maxf(26.0, h * 0.38), ring, true)
	t.position = Vector2(x, y)
	_actors.add_child(t)
	return t

func _draw_bg() -> void:
	_bg.draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), PAPER)
	_bg.draw_colored_polygon(PackedVector2Array([
		Vector2(-40.0, 650.0), Vector2(160.0, 300.0), Vector2(340.0, 650.0),
	]), Color(0.75, 0.76, 0.69, 0.62))
	_bg.draw_colored_polygon(PackedVector2Array([
		Vector2(200.0, 650.0), Vector2(430.0, 220.0), Vector2(680.0, 650.0),
	]), Color(0.67, 0.68, 0.61, 0.52))
	_bg.draw_colored_polygon(PackedVector2Array([
		Vector2(480.0, 650.0), Vector2(660.0, 350.0), Vector2(800.0, 650.0),
	]), Color(0.71, 0.71, 0.64, 0.46))
	_bg.draw_rect(Rect2(0.0, 600.0, W, 48.0), Color(0.90, 0.86, 0.76, 0.34))
	_bg.draw_rect(Rect2(0.0, 640.0, W, 640.0), Color(0.86, 0.82, 0.72))
	_bg.draw_line(Vector2(0.0, 640.0), Vector2(W, 640.0), Color(0.45, 0.38, 0.28, 0.38), 2.0)

func _mk(fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _ink(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.21, 0.19, 0.20, 0.96)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))

func _show_line() -> void:
	if _idx >= _lines.size():
		_show_skip_prompt()
		return
	var d: Dictionary = _lines[_idx]
	_name_lb.text = str(d["who"])
	_text_lb.text = str(d["text"])
	if _portrait != null:
		var who := str(d["who"])
		if who == "村长":
			_portrait.set_role("mob_chief")
			_portrait.setup(load("res://assets/char/village_chief_q_cut.png"), 58.0, Color(0.36, 0.30, 0.24), true)
		else:
			_portrait.set_role("player")
			_portrait.setup(CharArt.face("player"), 58.0, GOLD, true)

func _on_next() -> void:
	_idx += 1
	_show_line()

func _show_skip_prompt() -> void:
	_skip_panel = Control.new()
	_skip_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skip_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_panel.z_index = 8
	add_child(_skip_panel)
	var dim2 := ColorRect.new()
	dim2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim2.color = Color(0.04, 0.03, 0.02, 0.55)
	_skip_panel.add_child(dim2)
	var box := Panel.new()
	box.position = Vector2(90, 455)
	box.size = Vector2(540, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.955, 0.937, 0.886, 0.99)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.72, 0.58, 0.25, 0.85)
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	_skip_panel.add_child(box)
	var t := _mk(26, SEAL)
	t.text = "是否跳过剧情？"
	t.position = Vector2(30, 36)
	t.size = Vector2(480, 40)
	box.add_child(t)
	var sub := _mk(15, Color(0.30, 0.27, 0.22, 0.75))
	sub.text = "跳过只跳这一段，直接接到下一段"
	sub.position = Vector2(30, 86)
	sub.size = Vector2(480, 26)
	box.add_child(sub)
	var b_skip := Button.new()
	b_skip.text = "跳 过"
	b_skip.position = Vector2(40, 196)
	b_skip.size = Vector2(200, 54)
	b_skip.add_theme_font_size_override("font_size", 18)
	b_skip.focus_mode = Control.FOCUS_NONE
	b_skip.pressed.connect(_do_skip)
	_ink(b_skip)
	box.add_child(b_skip)
	var b_go := Button.new()
	b_go.text = "继 续 看"
	b_go.position = Vector2(300, 196)
	b_go.size = Vector2(200, 54)
	b_go.add_theme_font_size_override("font_size", 18)
	b_go.focus_mode = Control.FOCUS_NONE
	b_go.pressed.connect(_do_continue)
	_ink(b_go)
	box.add_child(b_go)

func _do_skip() -> void:
	GS.first_journey_done = true
	GS.save_game()
	finished.emit(true)
	get_tree().change_scene_to_file("res://menu_sketch.tscn")

func _do_continue() -> void:
	get_tree().change_scene_to_file("res://kushou/tutorial_stage.tscn")
