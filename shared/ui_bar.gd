extends RefCounted
# ============================================================
# ui_bar.gd —— 血条 / 怒气条（v93q）
#   用户："血条和怒气的 ui 也改一改"。
#   原来就是两根光板 ColorRect（一个深红、一个绿），像调试用的。
#   这里给一根**像样的条**：
#     · 竖向渐变填充 + 顶部一道高光（有体积感）
#     · **掉血拖尾**：被打掉的那截先留一截浅色，慢慢追上去（一眼看出这一下掉了多少）
#     · 刻度线（每 1/4 一格）
#     · 血量低于 30% 时红边脉动（危险提示）
#     · 满了可以走一道扫光（怒气满时用）
# ============================================================

class Bar extends Control:
	var ratio := 1.0            # 0~1：真实值
	var ghost := 1.0            # 0~1：拖尾（自动追 ratio）
	var col_a := Color(0.72, 0.20, 0.18)   # 上端
	var col_b := Color(0.46, 0.10, 0.10)   # 下端
	var ghost_col := Color(0.98, 0.86, 0.72, 0.55)
	var ticks := 4
	var radius := 4.0
	var low_warn := false       # 低于 30% 脉动（血条开、怒气条关）
	var shine := false          # 充满时走扫光（怒气满）
	var _t := 0.0

	func set_ratio(v: float) -> void:
		ratio = clampf(v, 0.0, 1.0)
		ghost = maxf(ghost, ratio)

	func _process(d: float) -> void:
		_t += d
		if ghost > ratio:
			ghost = maxf(ratio, ghost - d * 1.1)     # 追上去（约 1 秒追满一根）
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if r.size.x <= 1.0 or r.size.y <= 1.0:
			return
		# ① 槽底
		draw_rect(r, Color(0.09, 0.08, 0.09, 0.55), true)
		var fw := r.size.x * ratio
		var gw := r.size.x * ghost
		# ② 拖尾（被打掉的那一截）
		if gw > fw + 0.5:
			draw_rect(Rect2(r.position.x + fw, r.position.y, gw - fw, r.size.y), ghost_col, true)
		# ③ 填充：竖向渐变（分 6 段够顺，也不吃性能）
		if fw > 0.5:
			var seg := 6
			for i in seg:
				var y0 := r.position.y + r.size.y * float(i) / float(seg)
				var y1 := r.position.y + r.size.y * float(i + 1) / float(seg)
				var c := col_a.lerp(col_b, float(i) / float(seg - 1))
				draw_rect(Rect2(r.position.x, y0, fw, y1 - y0), c, true)
			# 顶部高光
			draw_rect(Rect2(r.position.x, r.position.y + 1.0, fw, maxf(1.0, r.size.y * 0.22)), Color(1, 1, 1, 0.22), true)
			# 满格扫光
			if shine and ratio >= 0.999:
				var ph := fmod(_t * 0.55, 1.0)
				var sx := r.position.x + (r.size.x + 40.0) * ph - 40.0
				draw_rect(Rect2(sx, r.position.y, 26.0, r.size.y), Color(1.0, 0.96, 0.78, 0.30), true)
		# ④ 刻度
		if ticks > 1:
			for i in range(1, ticks):
				var tx := r.position.x + r.size.x * float(i) / float(ticks)
				draw_line(Vector2(tx, r.position.y + 1.0), Vector2(tx, r.end.y - 1.0), Color(0.06, 0.05, 0.06, 0.35), 1.0)
		# ⑤ 边框（低血时朱红脉动）
		var bc := Color(0.16, 0.14, 0.14, 0.75)
		if low_warn and ratio < 0.30:
			var p := 0.5 + 0.5 * sin(_t * 6.0)
			bc = Color(0.86, 0.24, 0.20, 0.55 + 0.45 * p)
		draw_rect(r, bc, false, 1.6)
		# ⑥ 外描一圈极淡的墨，压在纸框上不突
		draw_rect(Rect2(r.position - Vector2(1, 1), r.size + Vector2(2, 2)), Color(0.10, 0.09, 0.10, 0.35), false, 1.0)
