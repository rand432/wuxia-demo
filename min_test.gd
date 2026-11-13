extends Control
# 最小对照场景：只有背景 + 主角 + 4 个怪，无 UI/音频/特效
const FONT := preload("res://fonts/ink.ttf")
var lb: Label = null
var worst := 0.0
var win := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.93, 0.90, 0.82, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var hero := TextureRect.new()
	hero.texture = load("res://assets/char/player_q.png")
	hero.position = Vector2(300, 700)
	hero.size = Vector2(120, 120)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(hero)
	for i in 4:
		var f := Panel.new()
		f.position = Vector2(200 + i * 80, 330)
		f.size = Vector2(64, 64)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.88, 0.83, 0.72)
		sb.set_corner_radius_all(10)
		sb.border_color = Color(0.45, 0.38, 0.28)
		sb.set_border_width_all(2)
		f.add_theme_stylebox_override("panel", sb)
		add_child(f)
	lb = Label.new()
	lb.position = Vector2(20, 30)
	lb.size = Vector2(420, 120)
	lb.add_theme_font_override("font", FONT)
	lb.add_theme_font_size_override("font_size", 20)
	lb.add_theme_color_override("font_color", Color(0.10, 0.55, 0.22))
	add_child(lb)
	set_process(true)

func _process(delta: float) -> void:
	worst = maxf(worst, delta)
	win += delta
	if win >= 2.0:
		lb.text = "FPS %d\nworst %.0fms" % [Engine.get_frames_per_second(), worst * 1000.0]
		win = 0.0
		worst = 0.0
