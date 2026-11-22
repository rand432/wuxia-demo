extends Control
# ============================================================
# kushou/attack_fx.gd —— 攻击表现层（P0）
#   后层（front=false）：短剑 + 小弧（单目标）
#   前层（front=true）：白边 + 淡红 + 伤害数字
# 本层放在战场左上角 (8,150)；传入位置都已转成战场局部坐标。
# ============================================================

const FONT := preload("res://fonts/ink.ttf")
const SWORD_ART := preload("res://assets/char/jian_ink_v1.png")
const INK := Color(0.13, 0.12, 0.11)
const GOLD := Color(0.85, 0.66, 0.23)

var front := false
var swings: Array = []
var hits: Array = []
var nums: Array = []
var enemy_attacks: Array[Dictionary] = []
var _sword: AtlasTexture

func _ready() -> void:
	_sword = AtlasTexture.new()
	_sword.atlas = SWORD_ART
	_sword.region = Rect2(424, 16, 176, 1508)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func spawn_swing(attacker: Vector2, target: Vector2, radius: float, windup: float) -> void:
	var d := target - attacker
	var base := rad_to_deg(atan2(d.x, -d.y))
	swings.append({
		"a": attacker, "r": radius, "base": base,
		"t": 0.0, "dur": windup + 0.16, "windup": windup,
	})
	queue_redraw()

func spawn_hit(pos: Vector2, radius: float, dmg: int, hero_hit: bool, gold := false, big := false) -> void:
	hits.append({"p": pos - Vector2(0, radius), "r": radius * 0.7, "t": 0.0, "dur": 0.22 if gold or big else 0.16, "strong": gold or big})
	nums.append({
		"p": pos + Vector2(32.0, -radius - 8.0), "txt": "-" + str(maxi(1, dmg)),
		"t": 0.0, "dur": 0.62,
		"size": 36 if hero_hit else (34 if big else 28),
		"hero": hero_hit, "gold": gold,
	})
	queue_redraw()

func spawn_enemy_attack(origin: Vector2, target: Vector2, kind: String) -> void:
	if origin.distance_squared_to(target) < 9.0:
		return
	if enemy_attacks.size() >= 24:
		enemy_attacks.pop_front()
	enemy_attacks.append({"origin": origin, "target": target, "kind": kind, "age": 0.0})
	queue_redraw()

func _process(delta: float) -> void:
	var dirty := false
	for i in range(enemy_attacks.size() - 1, -1, -1):
		enemy_attacks[i]["age"] += delta
		if float(enemy_attacks[i]["age"]) >= 0.18:
			enemy_attacks.remove_at(i)
		dirty = true
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
		for strike in enemy_attacks:
			_draw_enemy_attack(strike)
		for h in hits:
			_draw_hit(h)
		for n in nums:
			_draw_num(n)
	else:
		for s in swings:
			_draw_swing(s)

func _draw_enemy_attack(strike: Dictionary) -> void:
	var origin: Vector2 = strike["origin"]
	var target: Vector2 = strike["target"]
	var progress := clampf(float(strike["age"]) / 0.18, 0.0, 1.0)
	var opacity := 1.0 - progress
	var direction := origin.direction_to(target)
	match str(strike["kind"]):
		"bow":
			# 伤害已经在出手帧结算，短残影指向落点，不再补一次假命中。
			var tail := origin.lerp(target, progress * 0.82)
			draw_line(tail, target, Color(0.98, 0.79, 0.40, opacity * 0.46), 5.0, true)
			draw_line(tail, target, Color(1.0, 0.95, 0.71, opacity), 1.8, true)
			var normal := direction.orthogonal()
			draw_colored_polygon(PackedVector2Array([target, target - direction * 11.0 + normal * 4.0, target - direction * 11.0 - normal * 4.0]), Color(1.0, 0.93, 0.71, opacity))
		"mage":
			draw_arc(origin, 9.0 + 13.0 * progress, 0.0, TAU, 22, Color(0.78, 0.62, 1.0, opacity), 2.2, true)
			var bend := origin.lerp(target, 0.55) + direction.orthogonal() * 12.0
			draw_polyline(PackedVector2Array([origin, bend, target]), Color(0.74, 0.49, 1.0, opacity * 0.72), 4.0, true)
			for i in range(3):
				var spark := origin.lerp(target, (float(i) + 1.0 + progress) / 5.0)
				draw_circle(spark, (4.0 - float(i) * 0.7) * opacity, Color(0.91, 0.83, 1.0, opacity))
		_:
			var center := origin.lerp(target, 0.60)
			var angle := direction.angle()
			var radius := 16.0 + progress * 13.0
			draw_arc(center, radius, angle - 0.95, angle + 0.95, 16, Color(1.0, 0.76, 0.51, opacity * 0.85), 3.0 * opacity + 0.6, true)

func _draw_hit(h: Dictionary) -> void:
	var p := float(h["t"]) / maxf(0.001, float(h["dur"]))
	var a := clampf(1.0 - p, 0.0, 1.0)
	if a <= 0.0:
		return
	var c: Vector2 = h["p"]
	var r := float(h["r"])
	var strong := bool(h.get("strong", false))
	var accent := GOLD if strong else INK
	var spread := r * (0.45 + p * 1.3)
	draw_circle(c, 7.0 * a, Color(1.0, 0.96, 0.84, 0.8 * a))
	draw_arc(c, spread, -PI * 0.85, PI * 0.6, 28, Color(accent.r, accent.g, accent.b, a * 0.7), (3.0 if strong else 1.8) * a + 0.6, true)
	for i in range(4 if strong else 2):
		var direction := Vector2.from_angle(-0.65 + float(i) * 1.55)
		draw_line(c + direction * (3.0 + p * 9.0), c + direction * (12.0 + spread), Color(accent.r, accent.g, accent.b, a), 2.5 * a + 0.5, true)

func _draw_num(n: Dictionary) -> void:
	var p := float(n["t"]) / maxf(0.001, float(n["dur"]))
	var a := 1.0 - clampf((p - 0.62) / 0.38, 0.0, 1.0)
	if a <= 0.0:
		return
	var pos: Vector2 = n["p"] + Vector2(14.0 * p, -46.0 * (1.0 - pow(1.0 - p, 2.0)))
	var txt: String = str(n["txt"])
	var pop := lerpf(0.72, 1.12, minf(1.0, p / 0.16)) if p < 0.16 else lerpf(1.12, 1.0, minf(1.0, (p - 0.16) / 0.18))
	var fsz := int(round(float(n["size"]) * pop))
	var w := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	var base := Vector2(pos.x - w * 0.5, pos.y)
	var strong := bool(n["gold"])
	var color := Color(1.0, 0.79, 0.30, a) if strong else Color(1.0, 0.95, 0.82, a)
	if bool(n["hero"]):
		color = Color(1.0, 0.51, 0.45, a)
	draw_string_outline(FONT, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 5 if strong else 4, Color(0.16, 0.095, 0.055, a))
	draw_string(FONT, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, color)

func _draw_swing(s: Dictionary) -> void:
	var elapsed := float(s["t"])
	var windup := float(s["windup"])
	var t := (elapsed / maxf(windup, 0.001)) * 0.18 if elapsed < windup else 0.18 + elapsed - windup
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
	_draw_sword(hilt, ang, 58.0, alpha)
	# 弧只走牌外圈：起手 40°，接触时剑尖对目标，随势再带到 70°
	var ar := 72.0
	var a0 := deg_to_rad(base - 90.0 - 40.0)
	var a1 := deg_to_rad(arc_end)
	draw_arc(a, ar, a0, a1, 24, Color(GOLD.r, GOLD.g, GOLD.b, alpha * 0.80), 9.0, true)
	draw_arc(a, ar - 4.0, a0, a1, 24, Color(INK.r, INK.g, INK.b, alpha * 0.35), 3.0, true)

func _draw_sword(hilt: Vector2, angle: float, length: float, alpha: float) -> void:
	if _sword == null: return
	var height := (length + 9.0) / 0.745
	# 小尺寸战斗图加宽剑身与护手，保留Q版轮廓可读性。
	var width := height * 176.0 / 1508.0 * 2.4
	draw_set_transform(hilt, deg_to_rad(angle))
	draw_texture_rect(_sword, Rect2(-width * 0.5, -height * 0.745, width, height), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
