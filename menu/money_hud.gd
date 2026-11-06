extends Node2D
# 原版 MoneyHud（从 menu_sketch 抽出，未改画法）
const Ui := preload("res://menu/menu_theme.gd")

var font: Font = null
var silver := 0
var yuanbao := 0
var _sb1: StyleBoxFlat = null
var _sb2: StyleBoxFlat = null
# v220：钱数滚动——目标变了先"数上去"，再停在目标值；同时金一下
var _disp_silver := 0.0
var _disp_yuanbao := 0.0
var _last_silver := -1
var _last_yuanbao := -1
var _bump_s := 0.0
var _bump_y := 0.0
var _seeded := false

func _process(delta: float) -> void:
	if not _seeded:
		_disp_silver = float(silver)
		_disp_yuanbao = float(yuanbao)
		_last_silver = silver
		_last_yuanbao = yuanbao
		_seeded = true
	if silver != _last_silver:
		_last_silver = silver
		_bump_s = 1.0
	if yuanbao != _last_yuanbao:
		_last_yuanbao = yuanbao
		_bump_y = 1.0
	var ns := Ui.ease(_disp_silver, float(silver), 9.0, delta)
	if absf(ns - float(silver)) < 0.5:
		ns = float(silver)
	_disp_silver = ns
	var ny := Ui.ease(_disp_yuanbao, float(yuanbao), 9.0, delta)
	if absf(ny - float(yuanbao)) < 0.5:
		ny = float(yuanbao)
	_disp_yuanbao = ny
	_bump_s = maxf(0.0, _bump_s - delta * 5.0)
	_bump_y = maxf(0.0, _bump_y - delta * 5.0)
	queue_redraw()

func _coin(c: Vector2) -> void:
	draw_circle(c, 12.0, Color(0.90, 0.90, 0.92))
	draw_circle(c, 12.0, Color(0.42, 0.42, 0.50, 0.85), false, 2.0)
	draw_rect(Rect2(c.x - 4.0, c.y - 4.0, 8.0, 8.0), Color(0.42, 0.42, 0.50, 0.85), false, 2.0)

func _ingot(c: Vector2) -> void:
	var g := Color(0.86, 0.68, 0.26)
	var gd := Color(0.55, 0.42, 0.15, 0.9)
	var pts := PackedVector2Array([
		c + Vector2(-13, 7), c + Vector2(-7, -2),
		c + Vector2(7, -2), c + Vector2(13, 7),
	])
	draw_colored_polygon(pts, g)
	draw_circle(c + Vector2(0, -4), 6.5, g)
	draw_circle(c + Vector2(0, -4), 6.5, gd, false, 1.5)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), gd, 1.5)

# v200：影之刃式资源条——墨底金线，钱眼/元宝都用金
func _n_draw() -> void:
	# v211：银两/元宝压进顶栏墨带（右段 340~628），不再浮在画面里
	var r1 := Rect2(340.0, 30.0, 140.0, 38.0)
	var r2 := Rect2(488.0, 30.0, 140.0, 38.0)
	var o := {"fill": Color(0.094, 0.080, 0.070, 0.90),
		"edge": Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.58),
		"cut": 7.0, "bracket": false, "shadow": 0.45, "ink_halo": false,
		"glow": maxf(_bump_s, _bump_y) * 0.55}
	Ui.panel(self, r1, o)
	Ui.panel(self, r2, o)
	# 铜钱：金钱一枚，中间方孔
	var c := Vector2(364.0, 49.0)
	draw_circle(c, 10.5, Color(0.86, 0.71, 0.38))
	draw_arc(c, 10.5, 0.0, TAU, 24, Color(0.38, 0.29, 0.12, 0.85), 1.4, true)
	draw_rect(Rect2(c + Vector2(-3.5, -3.5), Vector2(7.0, 7.0)), Color(0.38, 0.29, 0.12, 0.85), false, 1.4)
	draw_string(font, Vector2(384.0, 57.0), str(int(round(_disp_silver))), HORIZONTAL_ALIGNMENT_RIGHT, 82.0, 20.0,
		Color(0.960, 0.925, 0.820, 0.96).lerp(Ui.GOLD_HI, _bump_s * 0.85))
	# 元宝
	var g := Vector2(512.0, 49.0)
	var pts := PackedVector2Array([g + Vector2(-9.0, 5.0), g + Vector2(-5.0, -1.0),
		g + Vector2(5.0, -1.0), g + Vector2(9.0, 5.0)])
	draw_colored_polygon(pts, Color(0.86, 0.71, 0.38))
	draw_circle(g + Vector2(0.0, -3.0), 4.6, Color(0.90, 0.76, 0.42))
	draw_string(font, Vector2(532.0, 57.0), str(int(round(_disp_yuanbao))), HORIZONTAL_ALIGNMENT_RIGHT, 82.0, 20.0,
		Color(0.960, 0.925, 0.820, 0.96).lerp(Ui.GOLD_HI, _bump_y * 0.85))

func silver_anchor() -> Vector2:
	if Ui.SKIN == 1:
		return Vector2(364.0, 49.0)
	return Vector2(358.0, 25.0)

func _draw() -> void:
	if font == null:
		return
	if Ui.SKIN == 1:
		_n_draw()
		return
	if _sb1 == null:
		_sb1 = StyleBoxFlat.new()
		_sb1.bg_color = Color(0.955, 0.937, 0.886, 0.92)
		_sb1.set_corner_radius_all(10)
		_sb1.border_color = Color(0.28, 0.23, 0.19, 0.35)
		_sb1.set_border_width_all(1)
		_sb2 = StyleBoxFlat.new()
		_sb2.bg_color = Color(0.965, 0.945, 0.885, 0.92)
		_sb2.set_corner_radius_all(10)
		_sb2.border_color = Color(0.72, 0.58, 0.25, 0.55)
		_sb2.set_border_width_all(1)
	# v97：整排往左挪 96 像素——用户标注把「设置」钉在**右上角**（x 0.91~1.00），
	#   原来元宝那条正好压在那儿（576~706）。挪完两条落在 334~610，正好在头像与设置之间。
	var r1 := Rect2(334, 8, 136, 34)
	draw_style_box(_sb1, r1)
	_coin(Vector2(358, 25))
	draw_string(font, Vector2(378, 31), str(silver), HORIZONTAL_ALIGNMENT_LEFT, 86, 17, Color(0.14, 0.13, 0.15, 0.92))
	var r2 := Rect2(480, 8, 130, 34)
	draw_style_box(_sb2, r2)
	_ingot(Vector2(504, 26))
	draw_string(font, Vector2(526, 31), str(yuanbao), HORIZONTAL_ALIGNMENT_LEFT, 78, 17, Color(0.14, 0.13, 0.15, 0.92))

