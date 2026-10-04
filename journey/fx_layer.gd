extends Control
# ============================================================
# 特效层 v4（水墨版 · 竖屏坐标）：墨笔刀光（墨身+招式色亮芯）、墨渍迸溅、
# 书法招式字 + 朱红印章"侠"、伤害数字、胜负大字、闪屏、震屏
# v4：两处绝对坐标搬到竖屏：招式字 (180,608)、胜负大字 (160,540)；
#   刀光/迸溅/数字/闪屏/震屏都是相对坐标或挂在视口上，未动。
#   （这两个数与竖屏战斗面板 (20,220) 680×780 配套。）
# 可选：把毛笔字体放到 res://fonts/ink.ttf 会自动启用
# ============================================================

const GameData := preload("res://shared/game_data.gd")
const UiKit := preload("res://shared/ui_kit.gd")   # v58：属性徽章 + 数字排一行（两套引擎共用）

var shake_target: Node2D = null

var _flash_rect: ColorRect
var _shake_tween: Tween
var _flash_tween: Tween
var _ink_font: Font = null

const INK := Color(0.12, 0.11, 0.13)
const SEAL := Color(0.72, 0.16, 0.12)

class BrushSlash extends Node2D:
	var col := Color(0.12, 0.11, 0.13, 0.78)
	var core_col := Color(1.0, 0.97, 0.90, 0.9)
	var length := 200.0
	var width := 12.0
	var bow := 18.0
	var rot_deg := 0.0

	func _draw() -> void:
		var r := deg_to_rad(rot_deg)
		var d := Vector2(cos(r), sin(r))
		var n := Vector2(-d.y, d.x)
		var npts := 12
		var prev := Vector2.ZERO
		for i in range(npts + 1):
			var t := float(i) / float(npts)
			var p := d * ((t - 0.5) * length) + n * sin(PI * t) * bow
			if i > 0:
				var t0 := float(i - 1) / float(npts)
				var w0 := width * (0.20 + 0.80 * sin(PI * t0))
				var w1 := width * (0.20 + 0.80 * sin(PI * t))
				_stroke(prev, p, w0 * 0.72, w1 * 0.72, Color(col.r, col.g, col.b, col.a * 0.22))
				_stroke(prev, p, w0 * 0.46, w1 * 0.46, col)
				_stroke(prev, p, w0 * 0.13, w1 * 0.13, core_col)
			prev = p

	func _stroke(a: Vector2, b: Vector2, ra: float, rb: float, col2: Color) -> void:
		var seg := b - a
		if seg.length() < 0.01:
			draw_circle(a, maxf(ra, rb), col2)
			return
		var th := seg.angle()
		var pts := PackedVector2Array()
		for i in 6:
			var ang := th - PI * 0.5 + PI * float(i) / 5.0
			pts.append(b + Vector2(cos(ang), sin(ang)) * rb)
		for i in 6:
			var ang2 := th + PI * 0.5 + PI * float(i) / 5.0
			pts.append(a + Vector2(cos(ang2), sin(ang2)) * ra)
		draw_colored_polygon(pts, col2)

class RayBurst extends Node2D:
	var col := Color(0.1, 0.1, 0.12, 0.7)
	var angles: Array = []
	var lens: Array = []

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 3.5, col)
		for i in angles.size():
			var a: float = angles[i]
			var L: float = lens[i]
			var d := Vector2(cos(a), sin(a))
			draw_line(d * 5.0, d * L, Color(col.r, col.g, col.b, col.a * 0.9), 2.6, true)
			draw_line(d * 5.0, d * (L * 0.8), Color(1, 1, 1, col.a * 0.45), 1.1, true)

class InkDots extends Node2D:
	var col := Color(0.10, 0.09, 0.11, 0.52)
	var pts: Array = []

	func _draw() -> void:
		for it in pts:
			draw_circle(it[0], it[1], col)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = get_viewport_rect().size
	var fpath := "res://fonts/ink.ttf"
	if ResourceLoader.exists(fpath):
		var f := ResourceLoader.load(fpath)
		if f is Font:
			_ink_font = f as Font
			print("已加载毛笔字体: ", fpath)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.position = Vector2(-20, -20)
	_flash_rect.size = get_viewport_rect().size + Vector2(40, 40)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)

func _mv_style(mv: String) -> Dictionary:
	match mv:
		"chop", "dual_chop", "anqi_throw":
			return {"len": 160.0, "wid": 18.0, "rot": 90.0, "bow": 16.0, "off": Vector2(0, -6), "col": Color(1.0, 0.92, 0.72)}
		"cut", "dual_alt", "fist_combo":
			return {"len": 270.0, "wid": 14.0, "rot": 0.0, "bow": 26.0, "off": Vector2.ZERO, "col": Color(1.0, 0.97, 0.85)}
		"slice", "dual_rip", "spear_lift":
			return {"len": 240.0, "wid": 13.0, "rot": -40.0, "bow": 22.0, "off": Vector2(0, 10), "col": Color(0.85, 1.0, 0.88)}
		"stab", "dual_thrust", "fist_punch", "fist_palm":
			return {"len": 300.0, "wid": 8.0, "rot": 0.0, "bow": 6.0, "off": Vector2(0, 4), "col": Color(0.80, 0.95, 1.0)}
		"dagger_slash":
			return {"len": 180.0, "wid": 11.0, "rot": 14.0, "bow": 14.0, "off": Vector2(0, -12), "col": Color(1.0, 0.95, 0.80)}
		"dagger_stab":
			return {"len": 210.0, "wid": 7.0, "rot": 0.0, "bow": 5.0, "off": Vector2(0, 4), "col": Color(0.80, 0.95, 1.0)}
		"dagger_flurry":
			return {"len": 240.0, "wid": 9.0, "rot": -12.0, "bow": 16.0, "off": Vector2(0, 2), "col": Color(0.80, 0.95, 1.0)}
		"spear_thrust", "spear_multi", "spear_turn":
			return {"len": 330.0, "wid": 7.0, "rot": 0.0, "bow": 5.0, "off": Vector2(0, 4), "col": Color(0.80, 0.95, 1.0)}
		"sweep", "anqi_rain":
			return {"len": 290.0, "wid": 16.0, "rot": 6.0, "bow": 28.0, "off": Vector2(0, 46), "col": Color(1.0, 0.88, 0.72)}
		"anqi_kick", "fist_kick":
			return {"len": 130.0, "wid": 12.0, "rot": 0.0, "bow": 10.0, "off": Vector2(0, 40), "col": Color(1.0, 0.93, 0.70)}
		_:
			return {"len": 200.0, "wid": 12.0, "rot": -40.0, "bow": 18.0, "off": Vector2.ZERO, "col": Color(1, 1, 1)}

func _mid_between(a: Node2D, b: Node2D) -> Vector2:
	return a.global_position.lerp(b.global_position, 0.62) + Vector2(0, -95)

func _add_seal(parent: Control, pos: Vector2, s: float) -> void:
	var seal := ColorRect.new()
	seal.color = SEAL
	seal.size = Vector2(s, s)
	seal.position = pos
	seal.rotation = deg_to_rad(-5.0)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(seal)
	var ch := Label.new()
	ch.text = "侠"
	ch.add_theme_font_size_override("font_size", int(s * 0.64))
	ch.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	ch.position = Vector2(s * 0.10, s * 0.02)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _ink_font != null:
		ch.add_theme_font_override("font", _ink_font)
	seal.add_child(ch)

func slash_between(a: Node2D, b: Node2D, mv: String) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	var st := _mv_style(mv)
	var c: Color = st["col"]
	var node := BrushSlash.new()
	node.col = Color(INK.r, INK.g, INK.b, 0.80)
	node.core_col = Color(c.r, c.g, c.b, 0.92)
	node.length = float(st["len"]) * randf_range(0.9, 1.1)
	node.width = float(st["wid"]) * randf_range(0.9, 1.1)
	node.bow = float(st["bow"]) * randf_range(0.85, 1.15)
	node.rot_deg = float(st["rot"]) + randf_range(-6.0, 6.0)
	var off: Vector2 = st["off"]
	node.position = _mid_between(a, b) + off
	node.scale = Vector2(0.75, 0.75)
	add_child(node)
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector2(1.25, 1.25), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 0.0, 0.22).set_delay(0.03)
	tw.finished.connect(node.queue_free)
	# v74：**每一刀都自动补一道白刃刀光 + 火星**。
	#   为什么不逐个调用点去改：全工程有 14 处 slash_between/burst，
	#   在这里挂一次，所有攻击（普攻/武学/大招/敌人反击）一起升级。
	blade_light(a, b, mv)

func burst(pos: Vector2, mv: String) -> void:
	var st := _mv_style(mv)
	var c: Color = st["col"]
	var ray := RayBurst.new()
	ray.col = Color(c.r * 0.35 + 0.04, c.g * 0.35 + 0.04, c.b * 0.35 + 0.03, 0.72)
	for i in 7:
		ray.angles.append(TAU * float(i) / 7.0 + randf_range(-0.25, 0.25))
		ray.lens.append(randf_range(16.0, 30.0))
	ray.position = pos
	ray.scale = Vector2(0.6, 0.6)
	add_child(ray)
	var tw := ray.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ray, "scale", Vector2(1.35, 1.35), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ray, "modulate:a", 0.0, 0.18).set_delay(0.02)
	tw.finished.connect(ray.queue_free)

	var dots := InkDots.new()
	dots.col = Color(INK.r, INK.g, INK.b, 0.52)
	for i in 6:
		var ang := randf() * TAU
		var dist := randf_range(16.0, 46.0)
		dots.pts.append([Vector2(cos(ang), sin(ang)) * dist, randf_range(1.8, 4.2)])
	dots.position = pos
	dots.scale = Vector2(0.5, 0.5)
	add_child(dots)
	var tw2 := dots.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(dots, "scale", Vector2(1.3, 1.3), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(dots, "modulate:a", 0.0, 0.26).set_delay(0.04)
	tw2.finished.connect(dots.queue_free)
	# v74：命中再补一圈**白色冲击环**——「打到了」得有一记亮的东西（原来只有墨点，太静）
	var ring := ShockRing.new()
	ring.col = Color(minf(1.0, c.r * 0.4 + 0.86), minf(1.0, c.g * 0.4 + 0.86), minf(1.0, c.b * 0.4 + 0.88), 0.9)
	ring.position = pos
	ring.r1 = 42.0 + float(st.get("len", 120.0)) * 0.10
	add_child(ring)


# ============================================================
# v74：**打击特效加强**（用户：「加一些打击命中特效 什么剑气啊 刀光啊…大招也要加 更华丽一点」）
#   素材包里那批特效是 Spine 图集/plist 帧动画（2.5D 彩色），跟本作水墨二次元是两套语言，
#   硬塞进来又是一轮违和——所以这里**照同一套水墨语言手写**：
#     · 刀光 blade_light()——一道白刃芯 + 墨边 + 火星，压在 brush slash 之上
#     · 剑气 sword_qi()——月牙形剑气**飞出去**（会走、会淡、会留残影）
#     · 命中墨爆 impact()——白色冲击环 + 墨点飞溅（比原来的 burst 更响）
#     · 大招墨漩 ult_storm()——墨色漩涡 + 多重剑气 + 冲击波
#   所有东西都是 _draw 画的，不依赖任何外部素材。
# ============================================================

# 白刃刀光：两头尖、中间亮的一道，外加两串火星
class BladeCore extends Node2D:
	var col := Color(1, 1, 1, 0.95)
	var edge := Color(0.10, 0.10, 0.12, 0.85)
	var length := 130.0
	var width := 9.0
	var bow := 10.0
	var rot_deg := -30.0
	var sparks: Array = []      # [[pos, r], …]

	func _draw() -> void:
		var n := 16
		var pts := PackedVector2Array()
		for i in n + 1:
			var t := float(i) / float(n)
			var x := (t - 0.5) * length
			var taper := sin(t * PI)                       # 两头收尖
			var y := -sin(t * PI) * bow * 0.4
			pts.append(Vector2(x, y))
			if i == 0:
				continue
		# 先描墨边（粗），再压白刃（细）——一刀两笔，像毛笔写出来的
		draw_polyline(pts, edge, width * 1.9, true)
		draw_polyline(pts, Color(col.r, col.g, col.b, col.a * 0.55), width * 1.1, true)
		draw_polyline(pts, col, width * 0.45, true)
		for s in sparks:
			draw_circle(Vector2(s[0]), float(s[1]), Color(1, 1, 1, 0.75))

# 飞出去的剑气：月牙形，会走、会转、会淡
class SwordQi extends Node2D:
	var col := Color(0.92, 0.94, 1.0, 0.95)
	var edge := Color(0.10, 0.10, 0.13, 0.90)
	var radius := 46.0
	var span := 1.7
	var vel := Vector2(600, 0)
	var life := 0.42
	var spin := 0.0
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		position += vel * d
		rotation += spin * d
		queue_redraw()
		if _t >= life:
			queue_free()

	func _draw() -> void:
		var k := clampf(1.0 - _t / life, 0.0, 1.0)
		var half := span * 0.5
		for i in 3:
			var w := 1.0 - 0.22 * float(i)
			draw_arc(Vector2.ZERO, radius * w, -half, half, 22, Color(col.r, col.g, col.b, 0.85 * k), 7.0 - 2.0 * float(i), true)
		draw_arc(Vector2.ZERO, radius * 1.16, -half * 0.9, half * 0.9, 22, Color(edge.r, edge.g, edge.b, 0.75 * k), 2.6, true)

# 命中墨爆：一圈白色冲击环 + 外扩墨环
class ShockRing extends Node2D:
	var col := Color(1, 1, 1, 0.85)
	var ink := Color(0.11, 0.11, 0.13, 0.75)
	var r0 := 6.0
	var r1 := 54.0
	var width := 5.0
	var life := 0.24
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()
		if t >= life:
			queue_free()

	func _draw() -> void:
		var k := clampf(t / life, 0.0, 1.0)
		var rr := lerpf(r0, r1, 1.0 - pow(1.0 - k, 2.0))
		var a := 1.0 - k
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(col.r, col.g, col.b, col.a * a), width * (1.0 - 0.5 * k), true)
		draw_arc(Vector2.ZERO, rr * 1.18, 0.0, TAU, 40, Color(ink.r, ink.g, ink.b, ink.a * a * 0.8), width * 0.6, true)

# ---- 对外接口 ----

# 刀光：压在 slash_between 之上再补一道白刃 + 火星（有它才「亮」）
func blade_light(a: Node2D, b: Node2D, mv: String) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	var st := _mv_style(mv)
	var node := BladeCore.new()
	var c: Color = st["col"]
	node.col = Color(minf(1.0, c.r * 0.35 + 0.88), minf(1.0, c.g * 0.35 + 0.88), minf(1.0, c.b * 0.35 + 0.90), 0.96)
	node.length = float(st["len"]) * randf_range(0.95, 1.12)
	node.width = maxf(7.0, float(st["wid"]) * 0.9)
	node.bow = float(st["bow"])
	node.rot_deg = float(st["rot"]) + randf_range(-4.0, 4.0)
	for i in 5:
		node.sparks.append([Vector2(randf_range(-0.6, 0.6), randf_range(-1.0, 1.0)) * float(st["len"]) * 0.5, randf_range(1.2, 2.6)])
	node.position = _mid_between(a, b) + (st["off"] as Vector2)
	node.rotation = deg_to_rad(node.rot_deg)
	node.scale = Vector2(0.7, 0.7)
	add_child(node)
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector2(1.3, 1.3), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 0.0, 0.20).set_delay(0.05)
	tw.finished.connect(node.queue_free)
	# 顺手甩一串火星
	var dots := InkDots.new()
	dots.col = Color(1.0, 0.96, 0.86, 0.85)
	for i in 7:
		var ang := randf() * TAU
		dots.pts.append([Vector2(cos(ang), sin(ang)) * randf_range(20.0, 58.0), randf_range(1.0, 2.4)])
	dots.position = node.position
	add_child(dots)
	var tw2 := dots.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(dots, "scale", Vector2(1.4, 1.4), 0.24).set_trans(Tween.TRANS_QUAD)
	tw2.tween_property(dots, "modulate:a", 0.0, 0.26).set_delay(0.03)
	tw2.finished.connect(dots.queue_free)

# 剑气：从 from 朝 to 方向飞出 count 道（武学/大招用）
func sword_qi(from: Node2D, to: Node2D, count := 3, spread := 0.30) -> void:
	if not is_instance_valid(from) or not is_instance_valid(to):
		return
	var p0 := from.global_position + Vector2(0, -70)
	var dir := (to.global_position + Vector2(0, -70) - p0).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(1, 0)
	for i in count:
		var q := SwordQi.new()
		var a := dir.rotated(randf_range(-spread, spread))
		q.vel = a * randf_range(560.0, 760.0)
		q.rotation = a.angle() + PI * 0.5
		q.spin = randf_range(-1.2, 1.2)
		q.radius = randf_range(30.0, 52.0)
		q.life = randf_range(0.34, 0.5)
		q.position = p0 + a * randf_range(0.0, 22.0)
		add_child(q)

# 命中墨爆：冲击环 + 墨点（替代原来那个偏静的 burst 手感）
# （冲击环已并进 burst，这里只是语义别名——内部**别再调 burst**，会递归）
func impact(pos: Vector2, mv := "chop") -> void:
	burst(pos, mv)

func _impact_old(pos: Vector2, mv := "") -> void:
	var ring := ShockRing.new()
	var st := _mv_style(mv) if mv != "" else {"col": Color(1, 1, 1)}
	var c: Color = st["col"]
	ring.col = Color(minf(1.0, c.r * 0.4 + 0.85), minf(1.0, c.g * 0.4 + 0.85), minf(1.0, c.b * 0.4 + 0.88), 0.9)
	ring.position = pos
	add_child(ring)
	burst(pos, mv if mv != "" else "chop")

# 大招：墨色漩涡 + 多重剑气 + 两圈冲击波
func ult_storm(center: Vector2, dir_x := 1.0) -> void:
	for i in 3:
		var r := ShockRing.new()
		r.position = center
		r.r1 = 90.0 + 46.0 * float(i)
		r.life = 0.30 + 0.10 * float(i)
		r.width = 7.0 - 1.6 * float(i)
		add_child(r)
	for i in 9:
		var q := SwordQi.new()
		var a := Vector2(dir_x, 0).rotated(randf_range(-0.85, 0.85))
		q.vel = a * randf_range(700.0, 1050.0)
		q.rotation = a.angle() + PI * 0.5
		q.radius = randf_range(26.0, 62.0)
		q.life = randf_range(0.36, 0.62)
		q.position = center + a * randf_range(0.0, 40.0)
		q.col = Color(1.0, 0.97, 0.90, 0.95)
		add_child(q)
	var dots := InkDots.new()
	dots.col = Color(0.10, 0.10, 0.12, 0.70)
	for i in 14:
		var ang := randf() * TAU
		dots.pts.append([Vector2(cos(ang), sin(ang)) * randf_range(30.0, 110.0), randf_range(2.0, 5.5)])
	dots.position = center
	add_child(dots)
	var tw := dots.create_tween()
	tw.set_parallel(true)
	tw.tween_property(dots, "scale", Vector2(1.6, 1.6), 0.34).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(dots, "modulate:a", 0.0, 0.38).set_delay(0.05)
	tw.finished.connect(dots.queue_free)

func shake(strength: float, duration: float) -> void:
	var t: Node2D = shake_target
	if t == null:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	t.position = Vector2.ZERO
	_shake_tween = t.create_tween()
	var steps := 6
	for i in steps:
		var off := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		_shake_tween.tween_property(t, "position", off, duration / float(steps))
	_shake_tween.tween_property(t, "position", Vector2.ZERO, duration / float(steps))

func flash(color: Color) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_rect.color = color
	_flash_tween = _flash_rect.create_tween()
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, 0.35)

func move_word(move_id: String) -> void:
	var nm := str(GameData.MOVE_NAMES.get(move_id, "招"))
	var base: Color = GameData.move_color(move_id)
	var col: Color = base.lerp(INK, 0.35).darkened(0.12)
	# v4 竖屏：x=180 让 360 宽的字条在 720 里居中；y=608 = 两人头顶上方约 60px
	var pos := Vector2(180, 608)

	var swash := BrushSlash.new()
	swash.col = Color(INK.r, INK.g, INK.b, 0.30)
	swash.core_col = Color(col.r, col.g, col.b, 0.0)
	swash.length = 300.0
	swash.width = 30.0
	swash.bow = 10.0
	swash.rot_deg = -6.0
	swash.position = pos + Vector2(180.0, 44.0)
	swash.scale = Vector2(0.6, 0.6)
	add_child(swash)
	var stw := swash.create_tween()
	stw.set_parallel(true)
	stw.tween_property(swash, "scale", Vector2(1.1, 1.1), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	stw.tween_property(swash, "modulate:a", 0.0, 0.30).set_delay(0.10)
	stw.finished.connect(swash.queue_free)

	var lb := Label.new()
	lb.text = nm + "！"
	lb.add_theme_font_size_override("font_size", 58)
	lb.add_theme_color_override("font_color", col)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	lb.add_theme_constant_override("outline_size", 6)
	if _ink_font != null:
		lb.add_theme_font_override("font", _ink_font)
	lb.size = Vector2(360, 84)
	lb.position = pos
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.pivot_offset = lb.size * 0.5
	lb.scale = Vector2(1.7, 1.7)
	lb.rotation = deg_to_rad(randf_range(-3.5, -0.5))
	lb.modulate.a = 0.0
	add_child(lb)
	_add_seal(lb, Vector2(272.0, 46.0), 30.0)
	var tw1 := lb.create_tween()
	tw1.set_parallel(true)
	tw1.tween_property(lb, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw1.tween_property(lb, "modulate:a", 1.0, 0.10)
	var tw2 := lb.create_tween()
	tw2.tween_interval(0.65)
	tw2.tween_property(lb, "modulate:a", 0.0, 0.30)
	tw2.finished.connect(lb.queue_free)

# v58（用户："伤害弹出记得标注是什么类型伤害"）：数字前面挂一枚**属性徽章**。
#   elem 为空＝物理/真实，维持老样子（只有数字）；有元素时才加牌子——免得满屏牌子。
func number(text: String, anchor: Node2D, color: Color, elem := "") -> void:
	if not is_instance_valid(anchor):
		return
	var lb: Control = UiKit.elem_number_row(text, color, elem, 46)
	lb.pivot_offset = lb.custom_minimum_size * 0.5
	lb.position = anchor.global_position + Vector2(-85, -205)
	lb.rotation = deg_to_rad(randf_range(-6.0, 6.0))
	lb.scale = Vector2(0.4, 0.4)
	lb.modulate.a = 0.0
	add_child(lb)
	var tw1 := lb.create_tween()
	tw1.set_parallel(true)
	tw1.tween_property(lb, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw1.tween_property(lb, "modulate:a", 1.0, 0.06)
	var tw2 := lb.create_tween()
	tw2.tween_interval(0.12)
	tw2.tween_property(lb, "scale", Vector2.ONE, 0.10)
	tw2.tween_interval(0.42)
	tw2.tween_property(lb, "modulate:a", 0.0, 0.30)
	tw2.finished.connect(lb.queue_free)
	var tw3 := lb.create_tween()
	tw3.tween_property(lb, "position:y", lb.position.y - 70.0, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func big_word(text: String, color: Color) -> void:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", 100)
	lb.add_theme_color_override("font_color", color)
	lb.add_theme_color_override("font_outline_color", Color(0.98, 0.96, 0.91, 0.5))
	lb.add_theme_constant_override("outline_size", 10)
	if _ink_font != null:
		lb.add_theme_font_override("font", _ink_font)
	lb.size = Vector2(400, 140)
	# v4 竖屏：x=160 让 400 宽的大字在 720 里居中；y=540 = 战斗面板中央
	lb.position = Vector2(160, 540)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.pivot_offset = lb.size / 2
	lb.scale = Vector2(0.4, 0.4)
	lb.rotation = deg_to_rad(-2.0)
	add_child(lb)
	_add_seal(lb, Vector2(300.0, 92.0), 44.0)
	var tw := lb.create_tween()
	tw.tween_property(lb, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(lb, "modulate:a", 0.0, 0.35)
	tw.finished.connect(lb.queue_free)
