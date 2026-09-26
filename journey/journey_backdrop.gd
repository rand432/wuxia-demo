extends RefCounted
# ============================================================
# journey_backdrop.gd —— 游历背景绘制件 v1（拆件批）
# 拆分自 journey_stage v20 的 _draw 与四个绘制助手（_ridge/_props/_road_marks/
# _ink_capsule），逐字搬运、只改静态：绘制目标由调用方传入。
# 舞台那边 _draw() 里只剩一行：Backdrop.draw_all(self, size, 三个滚动量)。
# ============================================================

const UiKit := preload("res://shared/ui_kit.gd")


static func draw_all(ctrl: Control, sz: Vector2, scroll_far: float, scroll_mid: float, scroll_road: float) -> void:
	var w: float = sz.x
	var h: float = sz.y
	ctrl.draw_rect(Rect2(0, 0, w, h), UiKit.PAPER)
	_ridge(ctrl, sz, scroll_far, 766.0, 118.0, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.055), 940.0)
	_ridge(ctrl, sz, scroll_mid, 828.0, 88.0, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.095), 720.0)
	_props(ctrl, sz, scroll_mid * 1.35)
	ctrl.draw_rect(Rect2(0, 950.0, w, h - 950.0), Color(0.885, 0.850, 0.775))
	ctrl.draw_line(Vector2(0, 950.0), Vector2(w, 950.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.30), 2.0)
	_road_marks(ctrl, sz, scroll_road)

static func _ridge(ctrl: Control, sz: Vector2, offset: float, base_y: float, hgt: float, col: Color, wave: float) -> void:
	var pts := PackedVector2Array()
	var x := -60.0
	while x <= sz.x + 60.0:
		var y: float = base_y - hgt * (0.5 + 0.5 * sin((x + offset) * TAU / wave))
		pts.append(Vector2(x, y))
		x += 36.0
	pts.append(Vector2(sz.x + 60.0, 950.0))
	pts.append(Vector2(-60.0, 950.0))
	ctrl.draw_colored_polygon(pts, col)

static func _props(ctrl: Control, sz: Vector2, offset: float) -> void:
	var span := sz.x + 600.0
	var period := 260.0
	var n := int(span / period) + 2
	for i in n:
		var x := fposmod(float(i) * period - offset, span) - 120.0
		if x < -140.0 or x > sz.x + 140.0:
			continue
		var hgt := 120.0 + fposmod(float(i) * 53.0, 90.0)
		var c1 := Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.10)
		var c2 := Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.07)
		_ink_capsule(ctrl, Vector2(x, 952.0), Vector2(x + 7.0, 952.0 - hgt), 5.0, 3.2, c1)
		_ink_capsule(ctrl, Vector2(x + 42.0, 952.0), Vector2(x + 47.0, 952.0 - hgt * 0.72), 4.2, 2.8, c2)
		var ty := 952.0 - hgt
		ctrl.draw_line(Vector2(x + 6.0, ty + 16.0), Vector2(x + 30.0, ty - 4.0), c1, 3.0, true)
		ctrl.draw_line(Vector2(x + 6.0, ty + 34.0), Vector2(x - 18.0, ty + 14.0), c2, 3.0, true)

static func _road_marks(ctrl: Control, sz: Vector2, scroll_road: float) -> void:
	var span := sz.x + 240.0
	var count := int(span / 170.0) + 1
	for i in count:
		var x := fposmod(float(i) * 170.0 - scroll_road, span)
		ctrl.draw_line(Vector2(x, 986.0), Vector2(x + 48.0, 986.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.10), 3.0, true)
	var count2 := int(span / 240.0) + 1
	for i in count2:
		var x2 := fposmod(float(i) * 240.0 - scroll_road * 1.25, span)
		var yy := 1016.0 + float(i % 3) * 14.0
		ctrl.draw_circle(Vector2(x2, yy), 2.6, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.09))

static func _ink_capsule(ctrl: Control, a: Vector2, b: Vector2, ra: float, rb: float, col: Color) -> void:
	var seg := b - a
	if seg.length() < 0.01:
		ctrl.draw_circle(a, maxf(ra, rb), col)
		return
	var th := seg.angle()
	var pts := PackedVector2Array()
	for i in 6:
		var ang := th - PI * 0.5 + PI * float(i) / 5.0
		pts.append(b + Vector2(cos(ang), sin(ang)) * rb)
	for i in 6:
		var ang2 := th + PI * 0.5 + PI * float(i) / 5.0
		pts.append(a + Vector2(cos(ang2), sin(ang2)) * ra)
	ctrl.draw_colored_polygon(pts, col)
