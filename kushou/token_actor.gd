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
		# 死亡：闪两下 → 圆牌与头像一起暗淡、下沉、落幕
		_death_t += delta
		var t := _death_t
		var a := 1.0
		if t < 0.14:
			a = 0.12
		elif t < 0.30:
			a = 1.0
		elif t < 0.44:
			a = 0.12
		elif t < 0.60:
			a = 1.0
		else:
			var p := clampf((t - 0.60) / 0.45, 0.0, 1.0)
			a = 1.0 - p
			_sink = 12.0 * p
		modulate = Color(0.82, 0.78, 0.72, a)
		if is_instance_valid(_sprite):
			_sprite.position = Vector2(0.0, -radius + _sink)
		if t >= 1.05:
			visible = false
		queue_redraw()
		return
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 3.6)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
	if is_instance_valid(_sprite):
		var bump := 1.0 + 0.035 * sin(_pulse * PI)
		_sprite.scale = Vector2(_base_scale, _base_scale) * bump
		_sprite.position.x = 0.0
		var col := Color(1.0, 1.0, 1.0, 1.0)
		if _flash > 0.0:
			col = Color(1.0, 0.58, 0.52, 1.0)
		_sprite.modulate = col


func play_move(_move_id: String = "", _speed := 1.0) -> void:
	_pulse = 1.0
	_flash = 0.0


func play_hit() -> void:
	_flash = 1.0


func play_dodge() -> void:
	_pulse = 0.8


func play_down() -> void:
	_death_t = 0.0
	_sink = 0.0
	_pulse = 0.0
	_flash = 0.0


func reset_pose() -> void:
	_death_t = -1.0
	_sink = 0.0
	_flash = 0.0
	_pulse = 0.0
	visible = true
	modulate = Color(1, 1, 1, 1)
	if is_instance_valid(_sprite):
		_sprite.rotation = 0.0
		_sprite.position = Vector2(0.0, -radius)
		_sprite.modulate = Color(1, 1, 1, 1)


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
