extends Node2D
# ============================================================
# menu_mist.gd —— v231/232：画心雾气 + 随季粒子
#   16 团雾（颜色随季）＋ 20~28 粒粒子：
#     春/夏：金尘上浮；秋：落叶下坠；冬：雪点下坠。
#   只铺在画心那一条（父级 Control 已 clip），不吃鼠标。
# ============================================================

const Conf := preload("res://menu/menu_conf.gd")

const FOG_COL := [
	Color(0.88, 0.86, 0.80),   # 春
	Color(0.92, 0.88, 0.78),   # 夏
	Color(0.86, 0.80, 0.68),   # 秋
	Color(0.80, 0.85, 0.92),   # 冬
]

var t := 0.0
var season := 0
var _wisps: Array = []
var _parts: Array = []
var _rain: Array = []           # v233：夏雨的斜线

func _ready() -> void:
	for i in 16:
		_wisps.append({
			"x": randf_range(-120.0, Conf.DW + 120.0),
			"y": randf_range(40.0, Conf.BAND_H - 40.0),
			"rx": randf_range(90.0, 220.0),
			"ry": randf_range(12.0, 26.0),
			"spd": randf_range(4.0, 12.0),
			"a": randf_range(0.100, 0.160),
			"ph": randf_range(0.0, TAU),
		})
	_rebuild_parts()

func set_season(s: int) -> void:
	s = clampi(s, 0, 3)
	if s == season and not _parts.is_empty():
		return
	season = s
	_rebuild_parts()

func _rebuild_parts() -> void:
	_parts.clear()
	_rain.clear()
	if season == 1:
		for i in 26:
			_rain.append({
				"x": randf_range(-40.0, Conf.DW + 40.0),
				"y": randf_range(0.0, Conf.BAND_H),
				"spd": randf_range(380.0, 680.0),
				"len": randf_range(14.0, 30.0),
				"a": randf_range(0.08, 0.16),
			})
	var n := 20
	if season == 2:
		n = 22
	elif season == 3:
		n = 28
	for i in n:
		_parts.append({
			"x": randf_range(16.0, Conf.DW - 16.0),
			"y": randf_range(10.0, Conf.BAND_H - 10.0),
			"spd": randf_range(9.0, 26.0) if season >= 2 else randf_range(5.0, 14.0),
			"ph": randf_range(0.0, TAU),
			"r": randf_range(1.2, 3.0) if season != 2 else randf_range(2.0, 4.0),
			"vx": randf_range(-6.0, 6.0),
		})

func _process(d: float) -> void:
	t += d
	for w in _wisps:
		w["x"] = float(w["x"]) + float(w["spd"]) * d
		if float(w["x"]) - float(w["rx"]) > Conf.DW:
			w["x"] = -float(w["rx"]) - 40.0
	for r in _rain:
		r["y"] = float(r["y"]) + float(r["spd"]) * d
		r["x"] = float(r["x"]) + float(r["spd"]) * 0.22 * d
		if float(r["y"]) > Conf.BAND_H + 24.0 or float(r["x"]) > Conf.DW + 40.0:
			r["y"] = -24.0
			r["x"] = randf_range(-80.0, Conf.DW)
	for m in _parts:
		m["x"] = float(m["x"]) + float(m["vx"]) * d + sin(t * 0.4 + float(m["ph"])) * 0.10
		if season >= 2:
			m["y"] = float(m["y"]) + float(m["spd"]) * d
			if float(m["y"]) > Conf.BAND_H + 8.0:
				m["y"] = -8.0
				m["x"] = randf_range(16.0, Conf.DW - 16.0)
		else:
			m["y"] = float(m["y"]) - float(m["spd"]) * d
			if float(m["y"]) < 8.0:
				m["y"] = Conf.BAND_H - 10.0
				m["x"] = randf_range(16.0, Conf.DW - 16.0)
	queue_redraw()

func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 26:
		var a := TAU * float(k) / 26.0
		pts.append(Vector2(c.x + cos(a) * rx, c.y + sin(a) * ry))
	draw_colored_polygon(pts, col)

func _draw() -> void:
	var fog: Color = FOG_COL[season]
	for w in _wisps:
		var cx := float(w["x"]) + sin(t * 0.25 + float(w["ph"])) * 14.0
		var cy := float(w["y"]) + sin(t * 0.18 + float(w["ph"])) * 6.0
		var rx := float(w["rx"])
		var ry := float(w["ry"])
		var a := float(w["a"])
		for k in 3:
			_ell(Vector2(cx, cy), rx * (1.0 - float(k) * 0.18), ry * (1.0 - float(k) * 0.18),
				Color(fog.r, fog.g, fog.b, a * (0.70 - 0.20 * float(k))))
	# 夏雨斜线：压在雾与金尘之上
	for r in _rain:
		var rx2 := float(r["x"])
		var ry2 := float(r["y"])
		var ln := float(r["len"])
		draw_line(Vector2(rx2, ry2), Vector2(rx2 - ln * 0.28, ry2 - ln),
			Color(0.84, 0.89, 0.96, float(r["a"])), 1.2, true)
	for m in _parts:
		var px := float(m["x"])
		var py := float(m["y"])
		var r := float(m["r"])
		if season == 2:
			# 秋：一片斜着的小叶
			var ang := sin(t * 0.8 + float(m["ph"])) * 0.9
			var c := Vector2(px, py)
			var d := Vector2(cos(ang), sin(ang)) * r * 1.6
			var n := Vector2(-sin(ang), cos(ang)) * r * 0.7
			draw_colored_polygon(PackedVector2Array([c - d, c + n, c + d, c - n]),
				Color(0.84, 0.50, 0.20, 0.55))
		elif season == 3:
			# 冬：雪点
			draw_circle(Vector2(px, py), r * 0.7, Color(0.96, 0.98, 1.0, 0.60))
		else:
			var glow := 0.55 + 0.45 * sin(t * 1.6 + float(m["ph"]))
			draw_circle(Vector2(px, py), r, Color(0.92, 0.74, 0.38, 0.32 * glow))
