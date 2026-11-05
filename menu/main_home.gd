extends Control
# 主界面 v1（草稿落地）：顶栏货币 / 关卡 / 普通·精英 / 场景 / 提升等级 / 三档宝箱 / 开始游戏 / 底栏4图标
const GameState := preload("res://shared/game_state.gd")
const Ui := preload("res://menu/menu_theme.gd")
const W := 720.0
const H := 1280.0
const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.96, 0.94, 0.90)
const SEAL := Color(0.55, 0.20, 0.12)
const GOLD := Color(0.78, 0.58, 0.22)
var _diff := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = PAPER
	add_child(bg)
	# 顶栏
	var top := ColorRect.new()
	top.position = Vector2.ZERO
	top.size = Vector2(W, 84)
	top.color = Color(0.16, 0.14, 0.12)
	add_child(top)
	_label("银两 " + str(GameState.coin("silver")), 20, Color(0.93, 0.89, 0.80), Vector2(24, 28))
	_label("元宝 " + str(GameState.coin("yuanbao")), 20, Color(0.93, 0.89, 0.80), Vector2(200, 28))
	_label("设置", 16, Color(0.78, 0.74, 0.66), Vector2(606, 30))
	# 关卡
	var lv := _label("第 1 关 · 村口小道", 34, INK, Vector2(40, 116))
	lv.size = Vector2(640, 46)
	var sub := _label("主角 · 江湖新客", 16, Color(0.48, 0.44, 0.38), Vector2(42, 166))
	# 难度
	_diff_btns = []
	for i in 2:
		var b := Button.new()
		b.text = "普 通" if i == 0 else "精 英"
		b.position = Vector2(80.0 + float(i) * 292.0, 210)
		b.size = Vector2(280, 52)
		b.add_theme_font_size_override("font_size", 22)
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
		arrow.text = "‹" if i == 0 else "›"
		arrow.position = Vector2(64.0 if i == 0 else 608.0, 466)
		arrow.size = Vector2(48, 90)
		arrow.add_theme_font_size_override("font_size", 40)
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.pressed.connect(_on_stage_arrow.bind(i))
		add_child(arrow)
	# 提升等级
	_label("提升等级(0/3)", 18, Color(0.58, 0.50, 0.36), Vector2(440, 866))
	# 三档宝箱
	for i in 3:
		var x := 70.0 + float(i) * 200.0
		var box := Panel.new()
		box.position = Vector2(x, 906)
		box.size = Vector2(140, 76)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.47, 0.36, 0.21, 0.95)
		sb.set_corner_radius_all(4)
		sb.border_color = GOLD
		sb.set_border_width_all(2)
		box.add_theme_stylebox_override("panel", sb)
		add_child(box)
		_label(["成功通关", "50%血量通关", "完美通关"][i], 16, Color(0.42, 0.38, 0.32), Vector2(x + 10.0, 992))
	# 开始游戏
	var go := Button.new()
	go.text = "开始游戏"
	go.position = Vector2(90, 1050)
	go.size = Vector2(540, 90)
	go.add_theme_font_size_override("font_size", 34)
	go.focus_mode = Control.FOCUS_NONE
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.82, 0.50, 0.12, 0.97)
	gsb.set_corner_radius_all(6)
	gsb.border_color = Color(0.98, 0.84, 0.48, 0.95)
	gsb.set_border_width_all(3)
	go.add_theme_stylebox_override("normal", gsb)
	go.add_theme_stylebox_override("hover", gsb)
	go.add_theme_stylebox_override("pressed", gsb)
	go.add_theme_color_override("font_color", Color(0.16, 0.10, 0.04))
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
		sb.bg_color = SEAL if on else Color(0.91, 0.88, 0.82)
		sb.set_corner_radius_all(4)
		sb.border_color = GOLD if on else Color(0.78, 0.73, 0.64)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(0.96, 0.92, 0.80) if on else Color(0.30, 0.27, 0.22))

func _on_diff(i: int) -> void:
	_diff = i
	_style_diff()

func _on_stage_arrow(i: int) -> void:
	print("[主界面] 切换关卡 dir=", i)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://kushou/tutorial_stage.tscn")
