extends RefCounted
# 统一的小图标笔刷：剑/枪/匕（战斗界面用）

static func draw_ui(icon: CanvasItem, center: Vector2, extent: float, key: String, color: Color) -> void:
	icon.draw_set_transform(center, 0.0, Vector2.ONE * extent / 40.0)
	match key:
		"start":
			_outline(icon, [Vector2(-17, 8), Vector2(-7, -9), Vector2(0, 2), Vector2(8, -15), Vector2(18, 5)], color)
			_outline(icon, [Vector2(-17, 14), Vector2(-7, 10), Vector2(1, 14), Vector2(15, 10)], color)
		"role":
			icon.draw_arc(Vector2(0, -8), 6, 0, TAU, 24, color, 2.5, true)
			_outline(icon, [Vector2(-16, 14), Vector2(-14, 5), Vector2(-6, 1), Vector2(0, 6),
				Vector2(6, 1), Vector2(14, 5), Vector2(16, 14), Vector2(-16, 14)], color)
		"god", "mate":
			_outline(icon, [Vector2(-9, -16), Vector2(8, -16), Vector2(8, 10), Vector2(0, 15),
				Vector2(-9, 10), Vector2(-9, -16)], color)
			_outline(icon, [Vector2(-4, -8), Vector2(3, -8), Vector2(0, -1), Vector2(3, 5), Vector2(-4, 5)], color)
			_spark(icon, Vector2(15, -6), color)
			_spark(icon, Vector2(-15, 7), color)
		"treasure":
			icon.draw_rect(Rect2(-16, -5, 32, 19), color, false, 2.5)
			_outline(icon, [Vector2(-16, -5), Vector2(-12, -12), Vector2(12, -12), Vector2(16, -5)], color)
			icon.draw_rect(Rect2(-3, -3, 6, 7), color, false, 2.0)
		"curio":
			_outline(icon, [Vector2(-5, -13), Vector2(5, -13), Vector2(4, -6), Vector2(11, -2),
				Vector2(13, 7), Vector2(8, 14), Vector2(-8, 14), Vector2(-13, 7), Vector2(-11, -2),
				Vector2(-4, -6), Vector2(-5, -13)], color)
			icon.draw_line(Vector2(-7, -15), Vector2(7, -15), color, 2.5, true)
			icon.draw_line(Vector2(-9, 7), Vector2(9, 7), color, 2.0, true)
		"market":
			icon.draw_arc(Vector2.ZERO, 15, 0, TAU, 36, color, 2.5, true)
			icon.draw_rect(Rect2(-4, -4, 8, 8), color, false, 2.4)
			icon.draw_line(Vector2(-13, 10), Vector2(-5, 17), color, 2.0, true)
		"skill":
			_outline(icon, [Vector2(-12, 6), Vector2(0, -7), Vector2(12, 6)], color, 3)
			_outline(icon, [Vector2(-12, -3), Vector2(0, -16), Vector2(12, -3)], color, 3)
			icon.draw_line(Vector2(-9, 13), Vector2(9, 13), color, 2.5, true)
		"draw":
			_outline(icon, [Vector2(-12, 10), Vector2(-17, -11), Vector2(-4, -16), Vector2(0, -13)], color)
			icon.draw_rect(Rect2(-7, -11, 21, 27), color, false, 2.5)
			_spark(icon, Vector2(3, 2), color)
	icon.draw_set_transform(Vector2.ZERO)

static func _outline(icon: CanvasItem, points: Array[Vector2], color: Color, width := 2.5) -> void:
	icon.draw_polyline(PackedVector2Array(points), color, width, true)

static func _spark(icon: CanvasItem, center: Vector2, color: Color) -> void:
	icon.draw_line(center - Vector2(0, 4), center + Vector2(0, 4), color, 1.7, true)
	icon.draw_line(center - Vector2(4, 0), center + Vector2(4, 0), color, 1.7, true)

static func draw(ci: CanvasItem, c: Vector2, r: float, kind: String, col: Color) -> void:
	if kind == "sword":
		ci.draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(r * 0.55, -r * 0.55), col, maxf(2.0, r * 0.16), true)
		ci.draw_line(c + Vector2(-r * 0.15, r * 0.15), c + Vector2(r * 0.35, -r * 0.35), Color(0.85, 0.66, 0.23), maxf(2.0, r * 0.10), true)
		ci.draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(-r * 0.30, r * 0.30), Color(0.55, 0.18, 0.14), maxf(2.0, r * 0.10), true)
	elif kind == "spear":
		ci.draw_line(c + Vector2(-r * 0.60, r * 0.25), c + Vector2(r * 0.45, -r * 0.20), col, maxf(2.0, r * 0.12), true)
		var tip := c + Vector2(r * 0.56, -r * 0.26)
		ci.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-r * 0.20, -r * 0.02), tip + Vector2(-r * 0.12, r * 0.18)]), Color(0.85, 0.66, 0.23))
	else:
		ci.draw_line(c + Vector2(-r * 0.35, r * 0.40), c + Vector2(r * 0.45, -r * 0.40), col, maxf(2.0, r * 0.14), true)
		ci.draw_line(c + Vector2(-r * 0.35, -r * 0.40), c + Vector2(r * 0.45, r * 0.40), col, maxf(2.0, r * 0.14), true)
