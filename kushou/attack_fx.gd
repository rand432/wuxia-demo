extends Control
# ============================================================
# kushou/attack_fx.gd —— 攻击表现层（P0）
#   后层（front=false）：短剑 + 小弧（单目标）
#   前层（front=true）：白边 + 淡红 + 伤害数字
# 本层放在战场左上角 (8,150)；传入位置都已转成战场局部坐标。
# ============================================================

const FONT := preload("res://fonts/ink.ttf")
const INK := Color(0.13, 0.12, 0.11)
const PAPER := Color(0.93, 0.90, 0.82)
const GOLD := Color(0.85, 0.66, 0.23)
const SEAL := Color(0.66, 0.22, 0.15)

var front := false
var swings: Array = []
var hits: Array = []
var nums: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func spawn_swing(attacker: Vector2, target: Vector2, radius: float, hero: bool, heavy := false, contact := false) -> void:
	var d := target - attacker
	var base := rad_to_deg(atan2(d.x, -d.y))
	swings.append({
		"a": attacker, "b": target, "r": radius, "base": base,
		"t": 0.0, "dur": 0.34, "hero": hero, "heavy": heavy, "contact": contact,
	})
	queue_redraw()

func spawn_hit(pos: Vector2, radius: float, dmg: int, hero_hit: bool, gold := false, big := false) -> void:
	hits.append({"p": pos, "r": radius, "t": 0.0, "dur": 0.14})
	nums.append({
		"p": pos + Vector2(38.0, -24.0), "txt": "-" + str(maxi(1, dmg)),
		"t": 0.0, "dur": 0.55,
		"col": SEAL if hero_hit else (GOLD if gold else INK),
		"size": 36 if hero_hit else (34 if big else 28),
		"hero": hero_hit, "gold": gold,
	})
	queue_redraw()

func _process(delta: float) -> void:
	var dirty := false
	for i in range(swings.size() - 1, -1, -1):
		swings[i]["t"] = float(swings[i]["t"]) + delta
		if float(swings[i]["t"]) >= float(swings[i]["dur"]):
			swings.remove_at(i)
		dirty = true
	for i in range(hits.size() - 1, -1, -1):
		hits[i]["t"] = float(hits[i]["t"]) + delta
		if float(hits[i]["t"]) >= float(hits[i]["dur"]):
			hits.remove_at(i)
		dirty = true
	for i in range(nums.size() - 1, -1, -1):
		nums[i]["t"] = float(nums[i]["t"]) + delta
		if float(nums[i]["t"]) >= float(nums[i]["dur"]):
			nums.remove_at(i)
		dirty = true
	if dirty:
		queue_redraw()

func _draw() -> void:
	if front:
		for h in hits:
			_draw_hit(h)
		for n in nums:
			_draw_num(n)
	else:
		for s in swings:
			_draw_swing(s)

func _draw_hit(h: Dictionary) -> void:
	var p := float(h["t"]) / maxf(0.001, float(h["dur"]))
	var a := clampf(1.0 - p, 0.0, 1.0)
	if a <= 0.0:
		return
	var c: Vector2 = h["p"]
	var r := float(h["r"])
	draw_circle(c, r + 2.0, Color(0.77, 0.25, 0.20, 0.20 * a))
	draw_arc(c, r + 6.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.22 * a), 8.0, true)
	draw_arc(c, r + 1.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.95 * a), 4.0, true)

func _draw_num(n: Dictionary) -> void:
	var p := float(n["t"]) / maxf(0.001, float(n["dur"]))
	var a := 1.0 - clampf((p - 0.62) / 0.38, 0.0, 1.0)
	if a <= 0.0:
		return
	var pos: Vector2 = n["p"] + Vector2(0.0, -38.0 * p)
	var txt: String = str(n["txt"])
	var fsz := int(n["size"])
	var w := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	var base := Vector2(pos.x - w * 0.5, pos.y)
	var col: Color = n["col"]
	if bool(n.get("gold", false)):
		draw_string(FONT, base + Vector2(2.0, 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz,
			Color(INK.r, INK.g, INK.b, 0.75 * a))
		draw_string(FONT, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz,
			Color(col.r, col.g, col.b, a))
	else:
		for ox in [-2.0, 0.0, 2.0]:
			for oy in [-2.0, 0.0, 2.0]:
				if ox == 0.0 and oy == 0.0:
					continue
				draw_string(FONT, base + Vector2(ox, oy), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz,
					Color(PAPER.r, PAPER.g, PAPER.b, 0.92 * a))
		draw_string(FONT, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz,
			Color(col.r, col.g, col.b, a))

func _draw_swing(s: Dictionary) -> void:
	var t := float(s["t"]) + (0.18 if bool(s.get("contact", false)) else 0.0)
	var appear := clampf(t / 0.06, 0.0, 1.0)
	var fade := 1.0 - clampf((t - 0.20) / 0.14, 0.0, 1.0)
	var alpha := appear * fade
	if alpha <= 0.0:
		return
	var base := float(s["base"])
	var ang: float
	var arc_end := base - 90.0
	if t < 0.18:
		# 起手 → 接触：到 0.18 时剑尖正对目标
		var p := clampf((t - 0.04) / 0.14, 0.0, 1.0)
		var e := p * p * (3.0 - 2.0 * p)
		ang = base - 40.0 + 40.0 * e
	else:
		# 接触后的随势：剑再往前带 30°，弧也收一下
		var q := clampf((t - 0.18) / 0.10, 0.0, 1.0)
		var e2 := q * q * (3.0 - 2.0 * q)
		ang = base + 30.0 * e2
		arc_end = base - 90.0 + 30.0 * e2
	var a: Vector2 = s["a"]
	var r := float(s["r"])
	var hilt := a + Vector2(sin(deg_to_rad(ang)), -cos(deg_to_rad(ang))) * (r + 14.0)
	_draw_sword(hilt, ang, 58.0, alpha, bool(s["hero"]))
	# 弧只走牌外圈：起手 40°，接触时剑尖对目标，随势再带到 70°
	var ar := 72.0
	var a0 := deg_to_rad(base - 90.0 - 40.0)
	var a1 := deg_to_rad(arc_end)
	draw_arc(a, ar, a0, a1, 24, Color(GOLD.r, GOLD.g, GOLD.b, alpha * 0.80), 9.0, true)
	draw_arc(a, ar - 4.0, a0, a1, 24, Color(INK.r, INK.g, INK.b, alpha * 0.35), 3.0, true)

func _draw_sword(hilt: Vector2, angle: float, length: float, alpha: float, _hero: bool) -> void:
	var dir := Vector2(sin(deg_to_rad(angle)), -cos(deg_to_rad(angle)))
	var perp := Vector2(-dir.y, dir.x)
	var g := hilt + dir * 9.0
	var tip := hilt + dir * (length + 9.0)
	var dark := Color(0.13, 0.12, 0.11, alpha)
	var steel := Color(0.41, 0.41, 0.45, alpha)
	var edge := Color(0.90, 0.90, 0.92, alpha)
	draw_colored_polygon(PackedVector2Array([
		g + perp * 8.6, tip + perp * 2.2, tip - perp * 2.2, g - perp * 8.6
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		g + perp * 7.0, tip + perp * 1.2, tip - perp * 1.2, g - perp * 7.0
	]), steel)
	draw_line(g + perp * 1.6, tip + perp * 0.4, edge, 2.0, true)
	draw_line(hilt + perp * 12.0, hilt - perp * 12.0, dark, 9.0, true)
	draw_line(hilt + perp * 11.0, hilt - perp * 11.0, Color(GOLD.r, GOLD.g, GOLD.b, alpha), 6.0, true)
	draw_line(hilt - dir * 2.0, hilt - dir * 18.0, dark, 9.0, true)
	draw_line(hilt - dir * 4.0, hilt - dir * 16.0, Color(0.23, 0.19, 0.16, alpha), 5.0, true)
	draw_circle(hilt - dir * 20.0, 5.0, Color(GOLD.r, GOLD.g, GOLD.b, alpha))
	draw_line(hilt - dir * 18.0, hilt - dir * 26.0 + perp * 9.0,
		Color(SEAL.r, SEAL.g, SEAL.b, alpha), 3.0, true)
