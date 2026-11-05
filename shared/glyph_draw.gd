extends RefCounted
# 统一的小图标笔刷：剑/枪/匕（战斗界面用）

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
