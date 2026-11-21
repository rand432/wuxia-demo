extends Node2D
# ============================================================
# kushou/token_actor.gd —— 圆形人物牌（v0）
#
# 背景：现成人物素材都是静态图，硬做全身动作会僵。
#   这里把人物收进一枚"圆形牌"：纸底 + 金边 + 圆内头像/半身，
#   只做轻量的出手前倾、挨打闪红、倒地淡出。
#
# 坐标：position = 脚底中心（与 StickFighter / QActor 同口径）
# 接口：set_role / set_weapon / fit_height / face / play_move / play_hit
#       play_dodge / play_down / reset_pose（够战斗层直接换用）
# ============================================================

const CharArt := preload("res://shared/char_art.gd")
const UI_FONT := preload("res://fonts/ink.ttf")

var role := "player"
var art_tex: Texture2D = null
var radius := 62.0
var ring_col := Color(0.86, 0.68, 0.26)
var crop_top := false
var weapon_type := "sword"
var fit_height := 160.0
var is_q_art := true
var show_bar := false
var hp_ratio := 1.0
var unit_name := ""
var bar_w := 72.0
var name_col := Color(0.18, 0.15, 0.12, 0.85)

var _sprite: Sprite2D
var _base_scale := 1.0
var _pulse := 0.0
var _flash := 0.0
var _death_t := -1.0
var _sink := 0.0
var _dir := 1.0
var _spawn_t := 0.26
var _hit_t := 0.0
var _hit_dir := Vector2.RIGHT
var _hit_strength := 1.0
const DEATH_DURATION := 0.38


func setup(tex: Texture2D, r: float, ring: Color, crop: bool) -> void:
	art_tex = tex
	radius = maxf(20.0, r)
	ring_col = ring
	crop_top = crop


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
	_sprite.position = Vector2(0.0, -radius)
	_sprite.texture = art_tex
	if art_tex != null:
		var w := float(art_tex.get_width())
		var h := float(art_tex.get_height())
		if crop_top:
			_sprite.region_enabled = true
			_sprite.region_rect = Rect2(0.0, 0.0, w, h * 0.62)
			h = h * 0.62
		_base_scale = (radius * 1.86) / maxf(w, h)
		_sprite.scale = Vector2(_base_scale, _base_scale)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec2 uv = UV - vec2(0.5); if (dot(uv, uv) > 0.25) { discard; } COLOR = texture(TEXTURE, UV); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_sprite.material = mat
	add_child(_sprite)
	queue_redraw()


func _process(delta: float) -> void:
	if _death_t >= 0.0:
		_death_t += delta
		var p := clampf(_death_t / DEATH_DURATION, 0.0, 1.0)
		modulate = Color(0.68, 0.64, 0.57, pow(1.0 - p, 1.3))
		_apply_visual_pose(Vector2.ONE * (1.0 + 0.08 * sin(p * PI) - 0.24 * p), _hit_dir * 10.0 * p + Vector2(0, 8.0 * p), 0.12 * p * signf(_hit_dir.x))
		visible = p < 1.0
		queue_redraw()
		return
	_spawn_t = minf(0.26, _spawn_t + delta)
	_pulse = maxf(0.0, _pulse - delta * 4.5)
	_flash = maxf(0.0, _flash - delta * 7.0)
	_hit_t = maxf(0.0, _hit_t - delta / 0.16)
	var enter := clampf(_spawn_t / 0.26, 0.0, 1.0)
	var ease := 1.0 + 2.70158 * pow(enter - 1.0, 3.0) + 1.70158 * pow(enter - 1.0, 2.0)
	var pop := lerpf(0.68, 1.0, ease)
	var recoil := sin(_hit_t * PI) * _hit_strength
	var attack := sin(_pulse * PI) * 0.035
	_apply_visual_pose(Vector2(pop * (1.0 + recoil * 0.08 + attack), pop * (1.0 - recoil * 0.08 + attack)), Vector2(0, 18.0 * (1.0 - enter)) + _hit_dir * recoil * 7.0)
	modulate = Color(1, 1, 1, lerpf(0.35, 1.0, enter))
	if is_instance_valid(_sprite):
		_sprite.modulate = Color(1.0, 1.0 - 0.35 * _flash, 1.0 - 0.42 * _flash)
	if enter < 1.0 or _flash > 0.0 or _hit_t > 0.0 or _pulse > 0.0:
		queue_redraw()

func _apply_visual_pose(visual_scale: Vector2, offset: Vector2, angle := 0.0) -> void:
	var center := Vector2(0, -radius)
	var pose := Transform2D(angle, Vector2.ZERO).scaled(visual_scale)
	pose.origin = center + offset - pose * center
	# 显示层变换，脚底坐标、碰撞和目标距离仍由核心管理。
	RenderingServer.canvas_item_set_transform(get_canvas_item(), get_transform() * pose)

func play_spawn(delay := 0.0) -> void:
	_spawn_t = -clampf(delay, 0.0, 0.08)
	modulate.a = 0.35
	_apply_visual_pose(Vector2.ONE * 0.68, Vector2(0, 18))
	queue_redraw()

func death_finished() -> bool:
	return _death_t >= DEATH_DURATION


func play_move(_move_id: String = "", _speed := 1.0) -> void:
	_pulse = 1.0
	_flash = 0.0


func play_hit(direction := Vector2.RIGHT, strong := false) -> void:
	if _death_t >= 0.0: return
	_flash = 1.0
	_hit_t = 1.0
	_hit_dir = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	_hit_strength = 1.5 if strong else 1.0


func play_dodge() -> void:
	_pulse = 0.8


func play_down() -> void:
	if _death_t >= 0.0: return
	_death_t = 0.0
	_sink = 0.0
	_pulse = 0.0
	_flash = 0.0


func reset_pose() -> void:
	_death_t = -1.0
	_sink = 0.0
	_flash = 0.0
	_pulse = 0.0
	_spawn_t = 0.26
	_hit_t = 0.0
	_hit_dir = Vector2.RIGHT
	_hit_strength = 1.0
	visible = true
	modulate = Color(1, 1, 1, 1)
	if is_instance_valid(_sprite):
		_sprite.rotation = 0.0
		_sprite.position = Vector2(0.0, -radius)
		_sprite.modulate = Color(1, 1, 1, 1)
	_apply_visual_pose(Vector2.ONE, Vector2.ZERO)


func _draw() -> void:
	var off := Vector2(0.0, _sink)
	# 脚下影子
	draw_set_transform(off + Vector2(0.0, -4.0), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, radius * 0.62, Color(0.18, 0.14, 0.10, 0.16))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 圆牌底 + 金边
	var c := Vector2(0.0, -radius) + off
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
	if show_bar:
		var bw := bar_w
		var bh := 10.0
		var bx := -bw * 0.5
		var by := -radius * 2.0 - 18.0 + _sink
		draw_rect(Rect2(bx, by, bw, bh), Color(0.20, 0.18, 0.20))
		draw_rect(Rect2(bx, by, bw, bh), Color(0.06, 0.05, 0.06), false, 1.5)
		var rr := clampf(hp_ratio, 0.0, 1.0)
		draw_rect(Rect2(bx + 1.5, by + 1.5, (bw - 3.0) * rr, bh - 3.0), _hp_color(rr))
		if unit_name != "":
			var fs := 16
			var tw := UI_FONT.get_string_size(unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(UI_FONT, Vector2(-tw * 0.5, by - 6.0), unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, name_col)


func _hp_color(r: float) -> Color:
	var green := Color(0.32, 0.60, 0.26)
	var yellow := Color(0.82, 0.66, 0.18)
	var red := Color(0.68, 0.14, 0.10)
	if r > 0.5:
		return yellow.lerp(green, (r - 0.5) * 2.0)
	return red.lerp(yellow, r * 2.0)
