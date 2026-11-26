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
const MAX_HITS := 24
const MAX_NUMBERS := 12
const MAX_CLUSTER_NUMBERS := 6
const NUMBER_CLUSTER_RADIUS_SQ := 156.0 * 156.0
const MAX_DEFEATS := 14
const NUMBER_OFFSETS := [Vector2.ZERO, Vector2(33, -23), Vector2(-36, -23), Vector2(0, -45)]

var front := false
var swings: Array = []
var hits: Array = []
var nums: Array = []
var defeats: Array[Dictionary] = []
var cast_seals: Array[Dictionary] = []
var skill_trails: Array[Dictionary] = []
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

func spawn_hit(pos: Vector2, radius: float, dmg: int, hero_hit: bool, crit := false, heavy := false) -> void:
	var intensity := 2 if crit else (1 if heavy or hero_hit else 0)
	var accent := Color(0.96, 0.40, 0.32) if hero_hit else (GOLD if crit else (Color(1.0, 0.52, 0.25) if heavy else Color(0.90, 0.83, 0.67)))
	if hits.size() >= MAX_HITS:
		hits.pop_front()
	hits.append({"p": pos - Vector2(0, radius), "r": radius * 0.7, "t": 0.0, "dur": 0.22 if intensity > 0 else 0.14,
		"intensity": intensity, "accent": accent})
	queue_redraw()
	_place_number(pos + Vector2(24, -radius - 11), dmg, hero_hit, crit, heavy)

func _place_number(anchor: Vector2, dmg: int, hero_hit: bool, crit: bool, heavy: bool) -> void:
	var important := hero_hit or crit or heavy
	var crowded := 0
	var replace := -1
	for i in nums.size():
		var current: Dictionary = nums[i]
		if anchor.distance_squared_to(current["p"]) > NUMBER_CLUSTER_RADIUS_SQ:
			continue
		crowded += 1
		if replace < 0 and not current["important"]:
			replace = i
	var displace := crowded >= MAX_CLUSTER_NUMBERS and not hero_hit
	if displace:
		if not important or replace < 0:
			return
	var location := Vector2.INF
	for offset: Vector2 in NUMBER_OFFSETS:
		var spot := Vector2(clampf(anchor.x + offset.x, 44.0, size.x - 56.0), maxf(53.0, anchor.y + offset.y))
		var occupied := false
		for i in nums.size():
			if displace and i == replace:
				continue
			var gap := (spot - _number_position(nums[i])).abs()
			if gap.x < 46.0 and gap.y < 25.0:
				occupied = true
				break
		if not occupied:
			location = spot
			break
	if location == Vector2.INF:
		if not hero_hit:
			return
		location = Vector2(clampf(anchor.x, 44.0, size.x - 56.0), maxf(44.0, anchor.y - 56.0))
	if displace:
		nums.remove_at(replace)
	elif nums.size() >= MAX_NUMBERS:
		var ordinary := nums.find_custom(func(entry: Dictionary) -> bool: return not bool(entry["important"]))
		if ordinary < 0 and not important:
			return
		nums.remove_at(maxi(0, ordinary))
	nums.append({
		"p": location, "txt": "-" + str(maxi(1, dmg)),
		"t": 0.0, "dur": 0.58 if important else 0.40,
		"size": 36 if hero_hit else (35 if crit else (31 if heavy else 24)),
		"hero": hero_hit, "gold": crit, "heavy": heavy, "important": important,
	})

func spawn_defeat(feet: Vector2, radius: float, accent: Color, important: bool) -> void:
	if defeats.size() >= MAX_DEFEATS:
		var ordinary := defeats.find_custom(func(entry: Dictionary) -> bool: return not bool(entry["important"]))
		if ordinary < 0 and not important:
			return
		defeats.remove_at(maxi(0, ordinary))
	defeats.append({"p": feet, "r": radius, "accent": accent,
		"important": important, "t": 0.0, "dur": 0.39 if important else 0.30})
	queue_redraw()

func spawn_enemy_attack(origin: Vector2, target: Vector2, kind: String) -> void:
	if origin.distance_squared_to(target) < 9.0:
		return
	if enemy_attacks.size() >= 24:
		enemy_attacks.pop_front()
	enemy_attacks.append({"origin": origin, "target": target, "kind": kind, "age": 0.0})
	queue_redraw()

func spawn_cast_seal(feet: Vector2, tint: Color, radius := 54.0, flatten := 0.36) -> void:
	if cast_seals.size() >= 3:
		cast_seals.pop_front()
	cast_seals.append({"p": feet, "tint": tint, "age": 0.0, "radius": radius, "flatten": flatten})
	queue_redraw()

func spawn_skill_trail(origin: Vector2, target: Vector2, tint: Color, width: float) -> void:
	if skill_trails.size() >= 10:
		skill_trails.pop_front()
	skill_trails.append({"origin": origin, "target": target, "tint": tint, "width": width, "age": 0.0})
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
	for i in range(defeats.size() - 1, -1, -1):
		defeats[i]["t"] += delta
		if float(defeats[i]["t"]) >= float(defeats[i]["dur"]):
			defeats.remove_at(i)
		dirty = true
	for events in [cast_seals, skill_trails]:
		for i in range(events.size() - 1, -1, -1):
			events[i]["age"] += delta
			if float(events[i]["age"]) >= 0.24:
				events.remove_at(i)
			dirty = true
	if dirty:
		queue_redraw()

func _draw() -> void:
	if front:
		for seal in cast_seals:
			_draw_cast_seal(seal)
		for trail in skill_trails:
			_draw_skill_trail(trail)
		for strike in enemy_attacks:
			_draw_enemy_attack(strike)
		for defeat in defeats:
			_draw_defeat(defeat)
		for h in hits:
			_draw_hit(h)
		for n in nums:
			_draw_num(n)
	else:
		for s in swings:
			_draw_swing(s)

func _draw_cast_seal(seal: Dictionary) -> void:
	var progress := clampf(float(seal["age"]) / 0.24, 0.0, 1.0)
	var tone: Color = seal["tint"]
	var center: Vector2 = seal["p"]
	var radius := float(seal["radius"]) * lerpf(0.44, 1.0, ease(progress, 0.44))
	draw_set_transform(center, 0.0, Vector2(1.0, float(seal["flatten"])))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(tone, 0.85 * (1.0 - progress)), 2.8, true)
	draw_arc(Vector2.ZERO, radius * 0.74, 0.0, TAU, 26, Color(tone, 0.36 * (1.0 - progress)), 1.2, true)
	draw_set_transform(Vector2.ZERO)

func _draw_skill_trail(trail: Dictionary) -> void:
	var progress := clampf(float(trail["age"]) / 0.24, 0.0, 1.0)
	var alpha := 1.0 - progress
	if alpha <= 0.001:
		return
	var origin: Vector2 = trail["origin"]
	var target: Vector2 = trail["target"]
	var tint: Color = trail["tint"]
	var width := float(trail["width"])
	var travel := target - origin
	if travel.length_squared() < 1.0:
		draw_circle(target, maxf(1.0, width * 0.18) * alpha, Color(tint.lightened(0.42), alpha), true, -1.0, true)
		return
	var tail := origin.lerp(target, progress * 0.72)
	var half_width := width * alpha
	# 贴身命中和淡出末段不提交接近零面积的面。
	if half_width >= 0.25:
		var side := travel.normalized().orthogonal() * half_width
		var shoulder := origin.lerp(target, 0.42 + progress * 0.48)
		draw_colored_polygon(PackedVector2Array([tail, shoulder + side, target, shoulder - side]), Color(tint, alpha * 0.58))
	draw_line(tail, target, Color(tint.lightened(0.55), alpha), 2.5 * alpha + 0.7, true)

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
			draw_line(tail, target, Color(0.21, 0.13, 0.07, opacity * 0.66), 4.5, true)
			draw_line(tail, target, Color(1.0, 0.95, 0.71, opacity), 1.8, true)
			var normal := direction.orthogonal()
			draw_colored_polygon(PackedVector2Array([target, target - direction * 11.0 + normal * 4.0, target - direction * 11.0 - normal * 4.0]), Color(1.0, 0.93, 0.71, opacity))
			if progress < 0.5:
				draw_line(tail - normal * 4.0 - direction * 8.0, tail, Color(1.0, 0.66, 0.28, opacity), 2.2, true)
				draw_line(tail + normal * 4.0 - direction * 8.0, tail, Color(1.0, 0.66, 0.28, opacity), 2.2, true)
		"mage":
			var flare := Color(0.78, 0.62, 1.0, opacity)
			var spread := 5.0 + 12.0 * progress
			draw_polyline(PackedVector2Array([origin + Vector2(0, -spread), origin + Vector2(spread, 0),
				origin + Vector2(0, spread), origin + Vector2(-spread, 0), origin + Vector2(0, -spread)]), flare, 2.2, true)
			var bend := origin.lerp(target, 0.55) + direction.orthogonal() * 12.0
			draw_polyline(PackedVector2Array([origin, bend, target]), Color(0.74, 0.49, 1.0, opacity * 0.72), 4.0, true)
			for i in range(3):
				var spark := origin.lerp(target, (float(i) + 1.0 + progress) / 5.0)
				draw_circle(spark, (4.0 - float(i) * 0.7) * opacity, Color(0.91, 0.83, 1.0, opacity))
		"snap":
			var center := origin.lerp(target, 0.68)
			var angle := direction.angle()
			var gap := lerpf(0.74, 0.30, progress)
			var reach := 21.0 + progress * 10.0
			for side in [-1.0, 1.0]:
				var tip := center + Vector2.from_angle(angle + gap * side) * reach
				var corner := center + Vector2.from_angle(angle + (gap + 0.20) * side) * reach * 0.76
				draw_colored_polygon(PackedVector2Array([center - direction * 7.0, corner, tip]),
					Color(1.0, 0.73, 0.35, opacity))
		"cleaver":
			var center := origin.lerp(target, 0.55)
			var angle := direction.angle() + 0.34 * progress
			var reach := 30.0 + progress * 18.0
			draw_arc(center, reach, angle - 1.17, angle + 0.92, 22, Color(0.39, 0.23, 0.51, opacity), 8.0 * opacity + 1.0, true)
			draw_arc(center, reach + 2.0, angle - 1.06, angle + 0.82, 22, Color(0.94, 0.85, 1.0, opacity), 2.8 * opacity + 0.5, true)
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
	var intensity := int(h["intensity"])
	var accent: Color = h["accent"]
	var spread := r * (0.45 + p * 1.3)
	draw_circle(c, (4.5 + intensity * 1.8) * a, Color(1.0, 0.96, 0.84, 0.82 * a))
	draw_arc(c, spread, -PI * 0.85, PI * 0.6, 20, Color(accent, a * 0.81), (1.6 + intensity * 1.3) * a + 0.6, true)
	for i in range(2 + intensity * 2):
		var direction := Vector2.from_angle(-0.65 + float(i) * 1.55)
		draw_line(c + direction * (3.0 + p * 9.0), c + direction * (9.0 + spread), Color(accent, a), (2.0 + intensity * 0.5) * a + 0.5, true)

func _draw_defeat(entry: Dictionary) -> void:
	var progress := float(entry["t"]) / float(entry["dur"])
	var alpha := 1.0 - progress
	var p: Vector2 = entry["p"]
	var radius := float(entry["r"])
	var accent: Color = entry["accent"]
	draw_set_transform(p, 0.0, Vector2(1.0, 0.32))
	draw_arc(Vector2.ZERO, radius * (0.50 + progress * 0.82), 0, TAU, 24, Color(accent, alpha * 0.8), 2.0 * alpha + 0.6, true)
	draw_set_transform(Vector2.ZERO)
	for i in range(6 if entry["important"] else 4):
		var side := -1.0 if i % 2 == 0 else 1.0
		var gap := (7.0 + i * 3.0) * (0.5 + progress * 1.2)
		var at := p + Vector2(gap * side, -sin(progress * PI * 0.85) * (17.0 + i * 4.0))
		draw_line(at, at + Vector2(side * 4.0, -6.0) * alpha, Color(accent, alpha), 3.0 * alpha + 0.5, true)

func _number_position(n: Dictionary) -> Vector2:
	var p := clampf(float(n["t"]) / float(n["dur"]), 0.0, 1.0)
	return n["p"] + Vector2(9.0 * p, -38.0 * (1.0 - pow(1.0 - p, 2.0)))

func _draw_num(n: Dictionary) -> void:
	var p := float(n["t"]) / maxf(0.001, float(n["dur"]))
	var a := 1.0 - clampf((p - 0.62) / 0.38, 0.0, 1.0)
	if a <= 0.0:
		return
	var pos := _number_position(n)
	var txt: String = str(n["txt"])
	var pop := lerpf(0.72, 1.12, minf(1.0, p / 0.16)) if p < 0.16 else lerpf(1.12, 1.0, minf(1.0, (p - 0.16) / 0.18))
	var fsz := int(round(float(n["size"]) * pop))
	var w := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	var strong := bool(n["gold"])
	var outline := 5 if strong else 4
	var inset := float(outline) + 2.0
	# 依据回弹后的实际字宽和基线限制描边，避免长数字被战场裁切。
	var base := Vector2(
		clampf(pos.x - w * 0.5, inset, maxf(inset, size.x - w - inset)),
		clampf(pos.y, FONT.get_ascent(fsz) + inset, size.y - FONT.get_descent(fsz) - inset))
	var color := Color(1.0, 0.79, 0.30, a) if strong else Color(1.0, 0.95, 0.82, a)
	if bool(n["heavy"]) and not strong:
		color = Color(1.0, 0.64, 0.37, a)
	if bool(n["hero"]):
		color = Color(1.0, 0.51, 0.45, a)
	draw_string_outline(FONT, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, outline, Color(0.16, 0.095, 0.055, a))
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
