extends RefCounted
# ============================================================
# ui_card.gd —— 「牌」与「签」两种卡面（v93j）
#
#   用户："还有卡组和签需要做成牌的样子和签的样子呀"
#   —— 原来卡组页里的每一张都只是一个**长方形按钮 + 文字**，不像牌；
#      命数那一页同样只是长条按钮，看不出是"签"。
#
#   这里给两件东西：
#     Card  —— 一张**牌**：落影、纸面、内框线、顶上一条彩色题名带、右下角一 Griff 印，
#              「已接/已拥有」时盖一枚朱红斜章。
#     Slip  —— 一支**签**：竹/木牌身 + 木纹 + 顶上红帽，签上**竖排**写名，
#              右边接一张纸条写说明（宽行排版也放得下）。
#
#   两者都只发 pressed 信号，接口跟 Button 一样好接。
# ============================================================

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.955, 0.938, 0.892)
const SEAL := Color(0.68, 0.15, 0.12)
const WOOD := Color(0.80, 0.68, 0.44)
const WOOD_D := Color(0.62, 0.49, 0.28)

# ---------------------------------------------------------------- 牌
class Card extends Control:
	signal pressed
	var title := ""
	var desc := ""
	var note := ""              # 小字（专属/限一次之类）
	var accent := Color(0.42, 0.40, 0.52)
	var tail := ""              # 右下角那枚小印里的字（价格/张数）
	var disabled := false
	var _hover := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not disabled else Control.CURSOR_ARROW

	func _gui_input(ev: InputEvent) -> void:
		if disabled:
			return
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				pressed.emit()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var face := PAPER if not disabled else Color(0.90, 0.885, 0.85)
		# ① 落影
		draw_colored_polygon(_round(Rect2(r.position + Vector2(0, 3), r.size), 10.0), Color(0.06, 0.05, 0.05, 0.20))
		# ② 牌面
		draw_colored_polygon(_round(r, 10.0), face)
		# ③ 内框线（差的这一点点，就是"牌"和"色块"的区别）
		var inner := Rect2(r.position + Vector2(5, 5), r.size - Vector2(10, 10))
		draw_polyline(_closed(_round(inner, 7.0)), Color(INK.r, INK.g, INK.b, 0.22), 1.2)
		draw_polyline(_closed(_round(r, 10.0)), Color(INK.r, INK.g, INK.b, 0.45), 1.6)
		# ④ 顶上题名带
		var band := Rect2(r.position + Vector2(5, 5), Vector2(r.size.x - 10.0, 34.0))
		var col := accent if not disabled else accent.lerp(Color(0.55, 0.55, 0.55), 0.6)
		draw_colored_polygon(_round(band, 7.0), Color(col.r, col.g, col.b, 0.90))
		var font := ThemeDB.fallback_font
		draw_string(font, band.position + Vector2(10.0, 24.0), title, HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 20.0, 20, Color(0.98, 0.96, 0.92))
		# ⑤ 说明
		var ty := band.position.y + 34.0 + 22.0
		draw_multiline_string(font, Vector2(r.position.x + 12.0, ty), desc, HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 24.0, 17, 3, Color(INK.r, INK.g, INK.b, 0.88))
		if note != "":
			draw_string(font, Vector2(r.position.x + 12.0, r.end.y - 10.0), note, HORIZONTAL_ALIGNMENT_LEFT,
				r.size.x - 76.0, 14, Color(INK.r, INK.g, INK.b, 0.55))
		# ⑥ 右下角小印
		if tail != "":
			var sq := Rect2(Vector2(r.end.x - 46.0, r.end.y - 30.0), Vector2(36.0, 20.0))
			draw_colored_polygon(_round(sq, 5.0), Color(SEAL.r, SEAL.g, SEAL.b, 0.86 if not disabled else 0.35))
			draw_string(font, sq.position + Vector2(0, 15.0), tail, HORIZONTAL_ALIGNMENT_CENTER, sq.size.x, 13, Color(0.99, 0.95, 0.90))
		# ⑦ 已接/已拥有 → 斜盖一枚章
		if disabled:
			draw_line(r.position + Vector2(18, r.size.y - 22), r.end - Vector2(18, 22), Color(SEAL.r, SEAL.g, SEAL.b, 0.30), 2.0)
			draw_line(r.position + Vector2(18, r.size.y - 34), r.end - Vector2(18, 34), Color(SEAL.r, SEAL.g, SEAL.b, 0.30), 2.0)

	static func _round(rc: Rect2, rad: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var seg := 6
		var corners := [
			[Vector2(rc.position.x + rad, rc.position.y + rad), PI, PI * 1.5],
			[Vector2(rc.end.x - rad, rc.position.y + rad), PI * 1.5, TAU],
			[Vector2(rc.end.x - rad, rc.end.y - rad), 0.0, PI * 0.5],
			[Vector2(rc.position.x + rad, rc.end.y - rad), PI * 0.5, PI],
		]
		for c in corners:
			var o: Vector2 = c[0]
			for i in seg + 1:
				var a: float = float(c[1]) + (float(c[2]) - float(c[1])) * float(i) / float(seg)
				pts.append(o + Vector2(cos(a), sin(a)) * rad)
		return pts

	static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
		var p := pts.duplicate()
		if p.size() > 0:
			p.append(p[0])
		return p

# ---------------------------------------------------------------- 签
class Slip extends Control:
	signal pressed
	var title := ""
	var desc := ""
	var disabled := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not disabled else Control.CURSOR_ARROW

	func _gui_input(ev: InputEvent) -> void:
		if disabled:
			return
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				pressed.emit()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var font := ThemeDB.fallback_font
		# ① 纸条（右）——说明写在这上面
		var paper := Rect2(r.position + Vector2(74, 4), Vector2(r.size.x - 78.0, r.size.y - 8.0))
		draw_colored_polygon(Card._round(Rect2(paper.position + Vector2(0, 2), paper.size), 8.0), Color(0.06, 0.05, 0.05, 0.16))
		draw_colored_polygon(Card._round(paper, 8.0), PAPER if not disabled else Color(0.90, 0.885, 0.85))
		draw_polyline(Card._closed(Card._round(paper, 8.0)), Color(INK.r, INK.g, INK.b, 0.35), 1.4)
		var ty := paper.position.y + 30.0
		draw_string(font, Vector2(paper.position.x + 14.0, ty), ("『" + title + "』" + ("　已接" if disabled else "　可接")),
			HORIZONTAL_ALIGNMENT_LEFT, paper.size.x - 28.0, 21, SEAL if not disabled else Color(0.45, 0.43, 0.45))
		draw_multiline_string(font, Vector2(paper.position.x + 14.0, ty + 24.0), desc, HORIZONTAL_ALIGNMENT_LEFT,
			paper.size.x - 28.0, 16, 3, Color(INK.r, INK.g, INK.b, 0.86))
		# ② 签身（左）——竹木牌，顶上红帽，名字**竖排**
		var sw := 62.0
		var sh := r.size.y - 6.0
		var slip := Rect2(r.position + Vector2(2, 3), Vector2(sw, sh))
		draw_colored_polygon(Card._round(Rect2(slip.position + Vector2(0, 2), slip.size), 8.0), Color(0.06, 0.05, 0.05, 0.20))
		var wood := WOOD if not disabled else WOOD.lerp(Color(0.72, 0.72, 0.72), 0.5)
		draw_colored_polygon(Card._round(slip, 8.0), wood)
		# 木纹
		for i in 3:
			var gy := slip.position.y + 26.0 + float(i) * (slip.size.y - 40.0) / 3.0
			draw_line(Vector2(slip.position.x + 6.0, gy), Vector2(slip.end.x - 6.0, gy), Color(WOOD_D.r, WOOD_D.g, WOOD_D.b, 0.35), 1.2)
		draw_polyline(Card._closed(Card._round(slip, 8.0)), Color(WOOD_D.r, WOOD_D.g, WOOD_D.b, 0.85), 1.6)
		# 红帽
		var cap := Rect2(slip.position + Vector2(2, 2), Vector2(sw - 4.0, 16.0))
		draw_colored_polygon(Card._round(cap, 6.0), Color(SEAL.r, SEAL.g, SEAL.b, 0.92 if not disabled else 0.4))
		# 竖排名字（一个字一行）
		var chars := title.replace("签", "")
		var n := chars.length()
		var fs := 19
		var total := float(n) * float(fs + 2)
		var sx := slip.position.x + sw * 0.5
		var sy := slip.position.y + 22.0 + maxf(0.0, (slip.size.y - 30.0 - total) * 0.5)
		for i in n:
			draw_string(font, Vector2(sx - float(fs) * 0.5, sy + float(fs)), chars.substr(i, 1),
				HORIZONTAL_ALIGNMENT_LEFT, float(fs + 4), fs, Color(0.24, 0.16, 0.10))
			sy += float(fs + 2)
