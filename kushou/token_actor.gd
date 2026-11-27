extends Node2D
# ============================================================
# kushou/token_actor.gd —— 战斗角色表现
#
# 带图集的角色按战斗事件切换独立动作帧，其余素材使用轻量姿态变化。
#
# 坐标：position = 脚底中心（与 StickFighter / QActor 同口径）
# 接口：set_role / set_weapon / fit_height / face / play_move / play_hit
#       play_dodge / play_down / reset_pose（够战斗层直接换用）
# ============================================================

const CharArt := preload("res://shared/char_art.gd")
const UI_FONT := preload("res://fonts/ink.ttf")
const HERO_OUTLINE := preload("res://kushou/hero_outline.gdshader")
const SKILL_POSE_TIME := 0.36
const MAX_PENDING_SKILL_POSES := 4

var role := "player"
var art_tex: Texture2D = null
var round_mask := true      # 旧式圆牌素材才需要裁切
var radius := 62.0
var ring_col := Color(0.86, 0.68, 0.26)
var crop_top := false
var weapon_type := "sword"
var fit_height := 160.0
var is_q_art := true
var show_bar := false
var compact_bar := false
var hp_ratio := 1.0
var unit_name := ""
var bar_w := 72.0
var name_col := Color(0.99, 0.94, 0.81)
var challenge_kind := -1
var guardian := false
var lamp_lit := false
var frost_layers := 0
var frost_chilled := false
var frost_frozen := false
var poisoned := false
var boss_warning: Dictionary = {}

var _sprite: Sprite2D
var _base_scale := 1.0
var _art_height := 0.0
var _attack_time := 0.0
var _boss_impact := false
var _boss_impact_pending := false
var _cast_time := 0.0
var skill_atlas: Texture2D
var _skill_row := -1
var _skill_facing := 1.0
var _pending_skill_poses: Array[Vector2i] = [] # 图集行号、水平朝向。
var _windup := 0.0
var _attack_direction := Vector2.RIGHT
var _attack_reach := 13.0
var _ready_time := 0.0
var _ready_duration := 0.0
var _recover_after_down := false
var _discard_after_down := false
var _flash := 0.0
var _death_t := -1.0
var _sink := 0.0
var _dir := 1.0
var _spawn_t := 0.26
var _hit_t := 0.0
var _guard_time := 0.0
var _lamp_pull_time := 0.0
var _lamp_pull_offset := Vector2.ZERO
var _hit_dir := Vector2.RIGHT
var _hit_strength := 1.0
var _anim_t := 0.0
var _last_feet := Vector2.ZERO
var _walk_blend := 0.0
var _frame_atlas: Texture2D
var _frame_index := -1
var _frame_clock := 0.0
var _frame_cell := 128.0
var _visual_pose_applied := false
const DEATH_DURATION := 0.38
const GUARD_DURATION := 0.14
const LAMP_PULL_DURATION := 0.18


func setup(tex: Texture2D, r: float, ring: Color, crop: bool, frames: Texture2D = null) -> void:
	art_tex = tex
	radius = maxf(20.0, r)
	ring_col = ring
	crop_top = crop
	_frame_atlas = frames
	if is_instance_valid(_sprite):
		_refresh_sprite()


func set_role(r: String) -> void:
	role = r


func set_weapon(w: String) -> void:
	weapon_type = w


func set_equipment(_a: String, _b: String, _c: String) -> void:
	pass


func face(dir: int) -> void:
	_dir = 1.0 if dir >= 0 else -1.0
	if is_instance_valid(_sprite):
		_sprite.flip_h = _dir < 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)
	_refresh_sprite()
	_last_feet = position
	queue_redraw()

func _refresh_sprite() -> void:
	_sprite.position = Vector2(0.0, -radius)
	_art_height = 0.0
	_sprite.texture = art_tex
	_sprite.region_enabled = crop_top and art_tex != null
	if _frame_atlas != null:
		_frame_index = -1
		_sprite.texture = _frame_atlas
		_sprite.region_enabled = true
		_sprite.region_filter_clip_enabled = true
		_frame_cell = float(_frame_atlas.get_width()) / 4.0
		_base_scale = radius * (2.24 if role == "player" else 3.15) / (_frame_cell * 101.0 / 128.0)
		_art_height = (_frame_cell * 108.0 / 128.0) * _base_scale
		_sprite.scale = Vector2.ONE * _base_scale
		_sprite.position.y = _frame_center_y()
		_show_frame(0)
	elif art_tex != null:
		var w := float(art_tex.get_width())
		var h := float(art_tex.get_height())
		if crop_top:
			_sprite.region_rect = Rect2(0.0, 0.0, w, h * 0.62)
			h = h * 0.62
		_base_scale = (radius * (1.86 if round_mask else 3.15)) / maxf(w, h)
		_sprite.scale = Vector2(_base_scale, _base_scale)
		if not round_mask:
			_art_height = h * _base_scale
			_sprite.position.y = -_art_height * 0.5
	if role == "player" and _frame_atlas != null and not round_mask:
		var outline := ShaderMaterial.new()
		outline.shader = HERO_OUTLINE
		_sprite.material = outline
	elif round_mask and art_tex != null and _frame_atlas == null:
		if _sprite.material == null:
			var shader := Shader.new()
			shader.code = "shader_type canvas_item;\nvoid fragment(){ if (distance(UV, vec2(0.5)) > 0.5) discard; }"
			var material := ShaderMaterial.new()
			material.shader = shader
			_sprite.material = material
	else:
		_sprite.material = null

func _frame_center_y() -> float:
	return -_frame_cell * (116.0 / 128.0 - 0.5) * _base_scale

func _show_frame(index: int) -> void:
	if _frame_atlas == null or index == _frame_index:
		return
	_frame_index = index
	_sprite.region_rect = Rect2((index % 4) * _frame_cell, floori(index / 4.0) * _frame_cell, _frame_cell, _frame_cell)

func _use_frame_atlas(atlas: Texture2D) -> void:
	if _sprite.texture != atlas:
		_sprite.texture = atlas
		_frame_index = -1


func _process(delta: float) -> void:
	if _death_t >= 0.0:
		_death_t += delta
		var p := clampf(_death_t / DEATH_DURATION, 0.0, 1.0)
		if p >= 1.0 and _discard_after_down:
			queue_free()
			return
		if p >= 1.0 and _recover_after_down:
			reset_pose()
			play_spawn()
			return
		if _frame_atlas != null:
			_use_frame_atlas(_frame_atlas)
			_show_frame(14 if role != "player" and p < 0.38 else 15)
			modulate = Color(0.88, 0.83, 0.77, 1.0 - smoothstep(0.44, 1.0, p))
			_apply_visual_pose(Vector2.ONE, _hit_dir * p * 9.0)
			visible = p < 1.0
			queue_redraw()
			return
		modulate = Color(0.68, 0.64, 0.57, pow(1.0 - p, 1.3))
		# 击败：先狠狠压扁，再散开（q 弹）
		var fall := smoothstep(0.08, 0.8, p)
		var sq := Vector2(1.0 + 0.25 * sin(p * PI), 1.0 - 0.81 * fall)
		_apply_visual_pose(sq, _hit_dir * 22.0 * fall + Vector2(0, 6.0 * fall), 0.42 * fall * signf(_hit_dir.x))
		visible = p < 1.0
		queue_redraw()
		return
	# 贴图闪白和身体偏移由 Sprite 与画布变换负责。只有脚边入场弧与圆牌闪光需要重绘。
	if _spawn_t < 0.26 or (_flash > 0.0 and (round_mask or (_frame_atlas == null and art_tex == null))) \
			or (challenge_kind >= 3 and _ready_time > 0.0):
		queue_redraw()
	_spawn_t = minf(0.26, _spawn_t + delta)
	if _boss_impact_pending:
		# 结算后的第一帧先画出招姿势，避免前一帧耗时过长直接跳到收势。
		_boss_impact_pending = false
	else:
		_attack_time = maxf(0.0, _attack_time - delta)
	if _boss_impact and _attack_time == 0.0:
		_boss_impact = false
	_advance_cast_pose(delta)
	_ready_time = maxf(0.0, _ready_time - delta)
	_flash = maxf(0.0, _flash - delta * 7.0)
	_hit_t = maxf(0.0, _hit_t - delta / 0.16)
	_guard_time = maxf(0.0, _guard_time - delta)
	if _lamp_pull_time > 0.0:
		_lamp_pull_time = maxf(0.0, _lamp_pull_time - delta)
	var enter := clampf(_spawn_t / 0.26, 0.0, 1.0)
	var ease := 1.0 + 2.70158 * pow(enter - 1.0, 3.0) + 1.70158 * pow(enter - 1.0, 2.0)
	var pop := lerpf(0.68, 1.0, ease)
	var recoil := sin(_hit_t * PI) * _hit_strength
	var travel := position - _last_feet
	_last_feet = position
	var moving := travel.length_squared() > 0.04 and travel.length_squared() < 400.0
	if _frame_atlas != null:
		_tick_frame_pose(delta, travel, moving, pop, enter, recoil)
		return
	_walk_blend = move_toward(_walk_blend, 1.0 if moving else 0.0, delta * 8.0)
	_anim_t += delta * lerpf(3.1, 16.0, _walk_blend)
	var breathe := 1.0 + lerpf(0.03, 0.085, _walk_blend) * sin(_anim_t)
	var atk := 0.0
	if _attack_time > 0.14:
		atk = -0.55 * smoothstep(0.0, 1.0, 1.0 - (_attack_time - 0.14) / maxf(_windup, 0.001))
	elif _attack_time > 0.0:
		atk = sin(PI * pow(1.0 - _attack_time / 0.14, 0.48))
	elif _ready_time > 0.0:
		atk = -0.8 * sin(PI * (1.0 - _ready_time / _ready_duration))
	var beat := lerpf(sin(_anim_t + 0.6) * 1.4, -absf(sin(_anim_t)) * 6.0, _walk_blend)
	var sx := pop * breathe * (1.0 + recoil * 0.08) * (1.0 + 0.16 * atk)
	var sy := pop / breathe * (1.0 - recoil * 0.08) * (1.0 - 0.14 * atk)
	_apply_visual_pose(Vector2(sx, sy), Vector2(0, 18.0 * (1.0 - enter) + beat) + _hit_dir * recoil * 7.0 + _attack_direction * atk * _attack_reach, 0.12 * atk * _attack_direction.x)
	modulate = Color(1, 1, 1, lerpf(0.35, 1.0, enter))
	if is_instance_valid(_sprite):
		_sprite.modulate = Color(0.75, 0.94, 1.18) if frost_frozen else Color(1.0 + 0.40 * _flash, 1.0 - 0.38 * _flash, 1.0 - 0.47 * _flash)

func _tick_frame_pose(delta: float, travel: Vector2, moving: bool, pop: float, enter: float, recoil: float) -> void:
	_frame_clock += delta
	var frame := 0
	var skill_pose := _cast_time > 0.0 and _skill_row >= 0 and skill_atlas != null
	_use_frame_atlas(skill_atlas if skill_pose else _frame_atlas)
	if frost_frozen:
		frame = clampi(_frame_index, 0, 13)
	elif skill_pose:
		frame = _skill_row * 4 + clampi(int((SKILL_POSE_TIME - _cast_time) * 4.0 / SKILL_POSE_TIME), 0, 3)
	elif _cast_time > 0.0:
		frame = 12 if _cast_time > 0.24 else 13
	elif _boss_impact:
		frame = 10 if _attack_time > 0.075 else 11
	elif not boss_warning.is_empty():
		frame = 8 if float(boss_warning["t"]) < float(boss_warning["warn"]) * 0.82 else 9
		if str(boss_warning.get("shape", "")) in ["sector", "beam"] or boss_warning.has("chain_step"):
			var aim := Vector2(boss_warning["dir"])
			if aim.x * _dir < -0.05:
				face(-1 if aim.x < 0.0 else 1)
	elif _attack_time > 0.0 and _attack_time <= 0.14:
		frame = 10 if _attack_time > 0.075 else 11
	elif _guard_time > 0.0:
		frame = 9
	elif _lamp_pull_time > 0.0:
		frame = 12 if _lamp_pull_time > LAMP_PULL_DURATION * 0.44 else 13
	elif _hit_t > 0.0:
		frame = 14 if role == "player" else (12 if _hit_t > 0.48 else 13)
	elif _attack_time > 0.0:
		frame = 8
	elif _ready_time > 0.0:
		frame = 8 if _ready_time > _ready_duration * 0.28 else 9
	elif moving:
		frame = 4 + posmod(int(_frame_clock * (8.0 if guardian else 12.0)), 4)
		if absf(travel.x) > 0.12:
			face(1 if travel.x >= 0.0 else -1)
	else:
		frame = posmod(int(_frame_clock * 4.0), 4)
	_show_frame(frame)
	_sprite.flip_h = (_skill_facing if skill_pose else _dir) < 0.0
	_apply_visual_pose(Vector2.ONE * pop, Vector2(0, 18.0 * (1.0 - enter)) + _hit_dir * recoil * 4.0)
	modulate = Color(1, 1, 1, lerpf(0.35, 1.0, enter))
	if frost_frozen:
		_sprite.modulate = Color(0.72, 0.94, 1.24)
	elif _guard_time > 0.0:
		var light := _guard_time / GUARD_DURATION
		_sprite.modulate = Color(1.0 + 0.07 * light, 1.0 + 0.24 * light, 1.0 + 0.43 * light)
	else:
		_sprite.modulate = Color(1.0 + 0.25 * _flash, 1.0 - 0.28 * _flash, 1.0 - 0.32 * _flash)

func _apply_visual_pose(visual_scale: Vector2, offset: Vector2, angle := 0.0) -> void:
	if _lamp_pull_time > 0.0:
		offset += _lamp_pull_offset * smoothstep(0.0, LAMP_PULL_DURATION, _lamp_pull_time)
	var changed := visual_scale != Vector2.ONE or offset != Vector2.ZERO or angle != 0.0
	if not changed and not _visual_pose_applied:
		return
	_visual_pose_applied = changed
	var center := Vector2(0, 0 if _art_height > 0.0 else -radius)
	var pose := Transform2D(angle, Vector2.ZERO).scaled(visual_scale)
	pose.origin = center + offset - pose * center
	# 显示层变换，脚底坐标、碰撞和目标距离仍由核心管理。
	RenderingServer.canvas_item_set_transform(get_canvas_item(), get_transform() * pose)

func play_spawn(delay := 0.0) -> void:
	_spawn_t = -clampf(delay, 0.0, 0.08)
	_anim_t = delay * 48.0
	_frame_clock = delay * 5.0
	_last_feet = position
	_walk_blend = 0.0
	modulate.a = 0.35
	_apply_visual_pose(Vector2.ONE * 0.68, Vector2(0, 18))
	queue_redraw()

func death_finished() -> bool:
	return _death_t >= DEATH_DURATION

func death_time_left() -> float:
	return maxf(0.0, DEATH_DURATION - _death_t) if _death_t >= 0.0 else 0.0


func play_move(_move_id: String = "", _speed := 1.0) -> void:
	play_attack(Vector2.RIGHT)

func play_attack(direction: Vector2, windup := 0.0, visual_reach := 13.0) -> void:
	if _death_t >= 0.0 or _boss_impact: return
	if challenge_kind >= 3 and _ready_time > 0.0:
		queue_redraw()
	_ready_time = 0.0
	_attack_direction = direction.normalized()
	if _frame_atlas != null and absf(direction.x) > 1.0:
		face(1 if direction.x > 0.0 else -1)
	_attack_reach = visual_reach
	_windup = clampf(windup, 0.0, 0.22)
	_attack_time = _windup + 0.14

func play_boss_impact(direction: Vector2) -> void:
	_boss_impact = false
	play_attack(direction)
	_boss_impact = _attack_time > 0.0
	_boss_impact_pending = _boss_impact and _frame_atlas != null

func prepare_attack(direction: Vector2, duration: float) -> void:
	if _death_t >= 0.0 or _boss_impact or duration <= 0.0: return
	_attack_direction = direction.normalized()
	if _frame_atlas != null and absf(direction.x) > 1.0:
		face(1 if direction.x > 0.0 else -1)
	_attack_reach = 10.0
	_ready_duration = duration
	_ready_time = duration
	if challenge_kind >= 3:
		queue_redraw()


func play_hit(direction := Vector2.RIGHT, strong := false) -> void:
	if _death_t >= 0.0: return
	_flash = 1.0
	_hit_t = 1.0
	_hit_dir = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	_hit_strength = 1.5 if strong else 1.0

func play_guard(direction: Vector2) -> void:
	if _death_t >= 0.0 or _frame_atlas == null:
		return
	_guard_time = GUARD_DURATION
	if absf(direction.x) > 1.0 and _attack_time <= 0.0:
		face(1 if direction.x > 0.0 else -1)

func set_lamp_lit(active: bool) -> void:
	if lamp_lit != active:
		lamp_lit = active
		queue_redraw()

func play_lamp_pull(displacement: Vector2) -> void:
	if _death_t >= 0.0:
		return
	_lamp_pull_offset = -displacement
	_lamp_pull_time = LAMP_PULL_DURATION
	_last_feet += displacement

func clear_lamp_pull() -> void:
	_lamp_pull_time = 0.0

func set_frost(layers: int, chilled: bool, frozen: bool) -> void:
	if frost_layers == layers and frost_chilled == chilled and frost_frozen == frozen:
		return
	frost_layers = layers
	frost_chilled = chilled
	frost_frozen = frozen
	queue_redraw()

func set_poisoned(active: bool) -> void:
	if poisoned != active:
		poisoned = active
		queue_redraw()

func play_cast(direction := Vector2.ZERO) -> void:
	if role not in ["player", "dragon"] or _frame_atlas == null or _death_t >= 0.0:
		return
	if absf(direction.x) > 0.05:
		face(1 if direction.x > 0.0 else -1)
	_skill_row = -1
	_cast_time = 0.32

func play_skill_cast(row: int, direction: Vector2) -> void:
	if role != "player" or _frame_atlas == null or _death_t >= 0.0:
		return
	var in_skill_pose := _cast_time > 0.0 and _skill_row >= 0
	if row < 0 or skill_atlas == null:
		if not in_skill_pose:
			play_cast(direction)
		return
	var facing := int(_dir) if absf(direction.x) <= 0.05 else (1 if direction.x > 0.0 else -1)
	var pose := Vector2i(row, facing)
	if not in_skill_pose:
		_begin_skill_pose(pose)
	elif _pending_skill_poses.size() < MAX_PENDING_SKILL_POSES:
		_pending_skill_poses.append(pose)


func _begin_skill_pose(pose: Vector2i) -> void:
	_skill_row = pose.x
	_skill_facing = float(pose.y)
	_cast_time = SKILL_POSE_TIME


func _advance_cast_pose(delta: float) -> void:
	while _cast_time > 0.0:
		# 连续施法时缩短重叠展示，动画计时与伤害、冷却独立。
		var speed := 1.75 if not _pending_skill_poses.is_empty() else 1.0
		var seconds_left := _cast_time / speed
		if delta < seconds_left:
			_cast_time -= delta * speed
			return
		delta -= seconds_left
		if _pending_skill_poses.is_empty():
			cancel_cast_poses()
			return
		_begin_skill_pose(_pending_skill_poses.pop_front())


func cancel_cast_poses() -> void:
	_cast_time = 0.0
	_skill_row = -1
	_pending_skill_poses.clear()


func play_dodge() -> void:
	play_attack(Vector2.UP)


func play_down(recover := false) -> void:
	if _death_t >= 0.0:
		if not recover: _recover_after_down = false
		return
	_death_t = 0.0
	_sink = 0.0
	set_lamp_lit(false)
	clear_lamp_pull()
	set_frost(0, false, false)
	set_poisoned(false)
	_guard_time = 0.0
	_attack_time = 0.0
	_boss_impact = false
	_boss_impact_pending = false
	cancel_cast_poses()
	_recover_after_down = recover
	_flash = 0.0


func retire() -> void:
	play_down()
	_discard_after_down = true


func reset_pose() -> void:
	boss_warning = {}
	set_lamp_lit(false)
	clear_lamp_pull()
	set_frost(0, false, false)
	set_poisoned(false)
	_death_t = -1.0
	_sink = 0.0
	_flash = 0.0
	_attack_time = 0.0
	_boss_impact = false
	_boss_impact_pending = false
	cancel_cast_poses()
	_ready_time = 0.0
	_recover_after_down = false
	_discard_after_down = false
	_anim_t = 0.0
	_frame_clock = 0.0
	_walk_blend = 0.0
	_dir = 1.0
	_last_feet = position
	_spawn_t = 0.26
	_hit_t = 0.0
	_guard_time = 0.0
	_hit_dir = Vector2.RIGHT
	_hit_strength = 1.0
	visible = true
	modulate = Color(1, 1, 1, 1)
	if is_instance_valid(_sprite):
		if _frame_atlas != null:
			_use_frame_atlas(_frame_atlas)
			_show_frame(0)
		_sprite.rotation = 0.0
		_sprite.flip_h = false
		_sprite.position = Vector2(0.0, _frame_center_y() if _frame_atlas != null else (-_art_height * 0.5 if _art_height > 0.0 else -radius))
		_sprite.modulate = Color(1, 1, 1, 1)
	_apply_visual_pose(Vector2.ONE, Vector2.ZERO)


func _draw() -> void:
	var off := Vector2(0.0, _sink)
	# 脚下影子
	draw_set_transform(off + Vector2(0.0, -4.0), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, radius * 0.76, Color(0.10, 0.09, 0.08, 0.30))
	draw_circle(Vector2.ZERO, radius * 0.44, Color(0.07, 0.06, 0.05, 0.22))
	if lamp_lit:
		for side: float in [0.0, PI]:
			draw_arc(Vector2.ZERO, radius * 0.86, side - 0.83, side + 0.83, 10, Color(1.0, 0.79, 0.47, 0.82), 2.2, true)
	if frost_chilled:
		draw_arc(Vector2.ZERO, radius * 0.92, 0.10, PI - 0.10, 16, Color(0.61, 0.87, 1.0, 0.72), 2.2, true)
	if (challenge_kind >= 0 or guardian or role == "dragon") and _death_t < 0.0:
		var color := ring_col
		var ring_radius := radius * 0.98
		draw_circle(Vector2.ZERO, ring_radius, Color(color, 0.11), true, -1.0, true)
		draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 36, Color(color, 0.87), 2.6, true)
		if guardian or challenge_kind >= 3:
			draw_arc(Vector2.ZERO, radius * 1.12, 0, TAU, 36, Color(color, 0.45), 1.7, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if challenge_kind >= 3 and _ready_time > 0.0 and _death_t < 0.0:
		_draw_challenge_windup()
	if frost_chilled or frost_frozen:
		_draw_frost()
	if poisoned:
		var marker := Vector2(radius * 1.12, -radius * 0.65)
		var leaf := PackedVector2Array([marker + Vector2(2, -7), marker + Vector2(5, 1),
			marker + Vector2(0, 6), marker + Vector2(-5, 1)])
		draw_colored_polygon(leaf, Color(0.21, 0.43, 0.24, 0.95))
		leaf.append(leaf[0])
		draw_polyline(leaf, Color(0.65, 0.91, 0.53), 1.4, true)
	# 圆牌底 + 金边（怪物：有立绘时省掉圆牌，直接站人）
	var c := Vector2(0.0, -radius) + off
	var show_plate := (art_tex == null and _frame_atlas == null) or round_mask
	if show_plate:
		draw_circle(c, radius, Color(0.93, 0.90, 0.83, 1.0))
		draw_arc(c, radius, 0.0, TAU, 64, Color(0.42, 0.35, 0.25, 0.55), 2.0, true)
		draw_arc(c, radius - 4.0, 0.0, TAU, 64, Color(ring_col.r, ring_col.g, ring_col.b, 0.85), 2.0, true)
		if _flash > 0.0:
			draw_arc(c, radius + 1.5, 0.0, TAU, 40, Color(1.0, 0.94, 0.72, _flash), 4.0, true)
	if _spawn_t < 0.26 and _death_t < 0.0:
		var enter := clampf(_spawn_t / 0.26, 0.0, 1.0)
		draw_arc(c, radius + 12.0 * (1.0 - enter), -PI * 0.9, PI * 0.8, 32, Color(0.24, 0.22, 0.19, 0.3 * (1.0 - enter)), 2.0, true)
	if _death_t >= 0.0:
		var p := clampf(_death_t / DEATH_DURATION, 0.0, 1.0)
		for i in range(7):
			var direction := Vector2.from_angle(TAU * float(i) / 7.0 + 0.2)
			var start := c + direction * radius * (0.7 + p * 0.7)
			draw_line(start, start + direction * (4.0 + 14.0 * p), Color(0.16, 0.15, 0.13, 0.8 * (1.0 - p)), 2.5 * (1.0 - p) + 0.5, true)
	# 头顶血条（照困兽那只怪：厚一点、带深色描边、绿→黄→红）
	if show_bar and _death_t < 0.0:
		var tagged := challenge_kind >= 0 or guardian
		var show_health := not compact_bar or hp_ratio < 0.995
		if not show_health and not tagged:
			return
		var bw := minf(bar_w, 36.0) if compact_bar else bar_w
		var bh := 6.0 if compact_bar else 10.0
		var bx := -bw * 0.5 + (10.0 if compact_bar and tagged else 0.0)
		var by := -maxf(_art_height, radius * 2.0) - 14.0 + _sink
		if show_health:
			draw_rect(Rect2(bx, by, bw, bh), Color(0.20, 0.18, 0.20))
			draw_rect(Rect2(bx, by, bw, bh), Color(0.06, 0.05, 0.06), false, 1.5)
			var rr := clampf(hp_ratio, 0.0, 1.0)
			var fill := ring_col.lerp(Color(0.89, 0.70, 0.40), 1.0 - rr) if role == "dragon" else _hp_color(rr)
			draw_rect(Rect2(bx + 1.5, by + 1.5, (bw - 3.0) * rr, bh - 3.0), fill)
		if not compact_bar and unit_name != "":
			var fs := 16
			var tw := UI_FONT.get_string_size(unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var label_position := Vector2(-tw * 0.5, by - 6.0)
			draw_string_outline(UI_FONT, label_position, unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.10, 0.08, 0.06, 0.9))
			draw_string(UI_FONT, label_position, unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, name_col)
		if tagged:
			var tag: String = ["钱", "晶", "书", "宝", "战"][challenge_kind] if challenge_kind >= 0 else "首"
			var plaque := Rect2(bx - 24, by - 6, 20, 22)
			if compact_bar:
				plaque = Rect2(bx - 20 if show_health else -8.5, by - 5, 17, 17)
			draw_rect(plaque, Color(0.11, 0.08, 0.05, 0.95))
			draw_rect(plaque, ring_col, false, 1.3)
			var baseline := 13.0 if compact_bar else 17.0
			draw_string(UI_FONT, plaque.position + Vector2(0, baseline), tag, HORIZONTAL_ALIGNMENT_CENTER,
				plaque.size.x, 12 if compact_bar else 15, ring_col)


func _draw_challenge_windup() -> void:
	var progress := 1.0 - _ready_time / _ready_duration
	var angle := _attack_direction.angle()
	var center := Vector2(0.0, -radius * 0.86)
	var edge := radius * (1.65 - 0.30 * progress)
	var glow := Color(ring_col.lightened(0.48), 0.55 + 0.45 * progress)
	if challenge_kind == 3:
		for side: float in [-1.0, 1.0]:
			var arc_angle := angle + side * lerpf(1.14, 0.63, progress)
			draw_arc(center, edge, arc_angle - 0.32, arc_angle + 0.32, 12, glow, 4.5, true)
	else:
		draw_arc(center, edge, angle - 1.16, angle - 1.16 + 2.32 * maxf(0.15, progress), 20, glow, 4.5, true)

func _draw_frost() -> void:
	if frost_frozen:
		for side: float in [-1.0, 1.0]:
			var foot := Vector2(side * radius * 0.67, -2.0)
			var tip := foot + Vector2(side * radius * 0.34, -radius * 1.16)
			var inner := foot + Vector2(-side * radius * 0.34, -radius * 0.28)
			var edge := foot + Vector2(side * radius * 0.45, -radius * 0.20)
			draw_colored_polygon(PackedVector2Array([tip, inner, foot, edge]), Color(0.38, 0.72, 0.94, 0.52))
			draw_polyline(PackedVector2Array([inner, tip, edge]), Color(0.80, 0.96, 1.0, 0.9), 1.5, true)
	for i in range(frost_layers):
		var marker := Vector2((float(i) - float(frost_layers - 1) * 0.5) * 9.0, 13.0)
		draw_circle(marker, 4.0, Color(0.10, 0.22, 0.34, 0.92), true, -1.0, true)
		draw_circle(marker, 2.7, Color(0.65, 0.91, 1.0), true, -1.0, true)

func _hp_color(r: float) -> Color:
	var green := Color(0.32, 0.60, 0.26)
	var yellow := Color(0.82, 0.66, 0.18)
	var red := Color(0.68, 0.14, 0.10)
	if r > 0.5:
		return yellow.lerp(green, (r - 0.5) * 2.0)
	return red.lerp(yellow, r * 2.0)
