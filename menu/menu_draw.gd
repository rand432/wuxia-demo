extends RefCounted
# ============================================================
# menu_draw.gd —— 公用笔法与换算（拆分 2/6，全静态）
# 规矩：所有 draw_* 必须传"正在 _draw 里的那个节点"（h）。
#       在别的节点的 _draw 里画另一个节点 = Godot 会报错，别试。
# ============================================================

const Conf := preload("res://menu/menu_conf.gd")

# ---- 坐标 / 裁剪 ----

static func sy() -> float:
	return (Conf.CONTENT_BOT - Conf.CONTENT_TOP) / (Conf.SCENE_BOT - Conf.SCENE_TOP)

static func sy_at(y_old: float) -> float:
	return Conf.CONTENT_TOP + (y_old - Conf.SCENE_TOP) * sy()

static func vis(cam: float, a: float, b: float) -> bool:
	return b > cam - 80.0 and a < cam + Conf.DW + 80.0

static func ramp(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / maxf(b - a, 0.001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

# ---- 河：蜿蜒 ----

static func river_off(x: float) -> float:
	return sin(x * 0.00215 + 0.70) * 0.62 + sin(x * 0.00081 - 1.15) * 0.38

static func river_open(x: float) -> float:
	var a := ramp(840.0, 1060.0, x)
	var b := 1.0 - ramp(1640.0, 1860.0, x)
	return 1.0 - 0.55 * a * b

static func river_far(x: float) -> float:
	return Conf.RIVER_FAR_Y + river_off(x) * Conf.RIVER_FAR_AMP * river_open(x)

static func river_near(x: float) -> float:
	return Conf.RIVER_NEAR_Y + river_off(x) * Conf.RIVER_NEAR_AMP * river_open(x)

# ---- 风：以 base 为支点的弯曲矩阵（用完记得 draw_set_transform_matrix(Transform2D.IDENTITY) 复位） ----

static func bend_xf(base: Vector2, amount: float) -> Transform2D:
	return Transform2D(Vector2(1.0, 0.0), Vector2(-amount, 1.0), Vector2(base.y * amount, 0.0))

# ---- 字库 ----

static func pick_font(theme_font: Font) -> Font:
	var f: Font = theme_font
	if ResourceLoader.exists(Conf.FONT_PATH):
		var r: Resource = load(Conf.FONT_PATH)
		if r is Font:
			f = r as Font
	if f == null:
		f = ThemeDB.fallback_font
	return f

# ---- 笔法（h = 正在画的节点） ----

static func stroke(h: CanvasItem, pts: Array, w0: float, w1: float, col: Color) -> void:
	var n := pts.size()
	if n < 2:
		return
	var poly := PackedVector2Array()
	for i in n:
		var p: Vector2 = pts[i]
		var dir: Vector2
		if i == 0:
			dir = (pts[1] as Vector2) - p
		elif i == n - 1:
			dir = p - (pts[n - 2] as Vector2)
		else:
			dir = (pts[i + 1] as Vector2) - (pts[i - 1] as Vector2)
		if dir.length_squared() < 0.0001:
			dir = Vector2.RIGHT
		dir = dir.normalized()
		var nr := Vector2(-dir.y, dir.x)
		var w := lerpf(w0, w1, float(i) / float(n - 1)) * 0.5
		poly.append(p + nr * w)
	for i in range(n - 1, -1, -1):
		var p2: Vector2 = pts[i]
		var dir2: Vector2
		if i == 0:
			dir2 = (pts[1] as Vector2) - p2
		elif i == n - 1:
			dir2 = p2 - (pts[n - 2] as Vector2)
		else:
			dir2 = (pts[i + 1] as Vector2) - (pts[i - 1] as Vector2)
		if dir2.length_squared() < 0.0001:
			dir2 = Vector2.RIGHT
		dir2 = dir2.normalized()
		var nr2 := Vector2(-dir2.y, dir2.x)
		var w2 := lerpf(w0, w1, float(i) / float(n - 1)) * 0.5
		poly.append(p2 - nr2 * w2)
	h.draw_colored_polygon(poly, col)

static func ellipse(h: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 26:
		var a := TAU * float(i) / 26.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	h.draw_colored_polygon(pts, col)

static func round_poly(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs := [
		Vector2(r.position.x + rad, r.position.y + rad),
		Vector2(r.end.x - rad, r.position.y + rad),
		Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad),
	]
	var angs := [PI, PI * 1.5, 0.0, PI * 0.5]
	for i in 4:
		var c: Vector2 = cs[i]
		var a0: float = angs[i]
		for k in 6:
			var a := a0 + (PI * 0.5) * float(k) / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts

static func mini_person(h: CanvasItem, x: float, y: float, facing: float, step: float, bob: float, hat: bool) -> void:
	var col := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.68)
	var col2 := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.50)
	var hip := Vector2(x, y - 10.0 + bob)
	var neck := Vector2(x - facing * 1.2, y - 28.0 + bob)
	stroke(h, [hip, Vector2(x - step, y)], 2.6, 1.2, col2)
	stroke(h, [hip, Vector2(x + step, y)], 2.6, 1.2, col2)
	stroke(h, [hip, neck], 5.0, 3.6, col)
	stroke(h, [Vector2(x - facing * 1.0, y - 22.0 + bob), Vector2(x - facing * 1.0 - step * 0.6, y - 14.0 + bob)], 2.0, 1.0, col2)
	var head := Vector2(x + facing * 0.6, y - 30.0 + bob)
	ellipse(h, head, 3.6, 3.6 / sy(), col)
	if hat:
		stroke(h, [Vector2(head.x - 6.0, head.y - 2.0), Vector2(head.x + 6.0, head.y - 2.0)], 1.8, 1.8, col2)
