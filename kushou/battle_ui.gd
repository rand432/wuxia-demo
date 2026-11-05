extends Control
# ============================================================
# kushou/battle_ui.gd —— 新战斗界面（按 v31 草图）
#   独立场景：先跑通布局/交互，再接进关卡流程。
#   720×1280：顶部资源 64 / 战场 140..830 / 卡组 830..980 / 底栏 980..1220
#   抽卡页无外框、不暂停；三张卡框浮在战场上。
# ============================================================

const W := 720.0
const H := 1280.0
const FONT := preload("res://fonts/ink.ttf")
const PLAYER_TEX := preload("res://assets/char/player_q.png")

const INK := Color(0.13, 0.12, 0.11)
const PAPER := Color(0.93, 0.90, 0.82)
const PAPER_HI := Color(0.97, 0.95, 0.89)
const GOLD := Color(0.85, 0.66, 0.23)
const SEAL := Color(0.66, 0.22, 0.15)
const DIM := Color(0.42, 0.38, 0.32)
const LIGHT := Color(0.91, 0.87, 0.78)

var _page := 0
var _draw_open := false
var _attr_open := false
var _exit_open := false
var _draw_layer: Control
var _chal_layer: Control
var _detail_layer: Control
var _detail_name: Label
var _detail_sub: Label
var _detail_line: Label
var _attr_layer: Control
var _exit_layer: Control
var _toast_lb: Label
var _toast_seq := 0
var _cards := [0, 1, 2, 3, 4, 5, 6]
var _page_lb: Label
var _slots: Array = []
var _draw_cards: Array = []
var _enemies: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 17
	theme = th
	_build_bg()
	_build_hud()
	_build_field()
	_build_deck()
	_build_bottom()
	_build_draw()
	_build_attr()
	_build_exit()
	_build_toast()
	_refresh_deck()
	set_process(true)

# ---------------- 通用 ----------------
func _panel(rect: Rect2, bg: Color, radius := 8, border := Color(0, 0, 0, 0), bw := 0, parent: Node = null) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(p)
	return p

func _lbl(t: String, pos: Vector2, sz: Vector2, fs: int, col: Color, parent: Node = null, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(l)
	return l

func _btn(t: String, rect: Rect2, fs: int, bg: Color, fg: Color, cb: Callable, parent: Node = null, border := Color(0.85, 0.66, 0.23, 0.55), bw := 1) -> Button:
	var b := Button.new()
	b.text = t
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate()
	hb.bg_color = bg.lightened(0.08)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)
	if cb.is_valid():
		b.pressed.connect(cb)
	(parent if parent != null else self).add_child(b)
	return b

func _toast(t: String) -> void:
	if _toast_lb == null:
		return
	_toast_seq += 1
	var seq := _toast_seq
	_toast_lb.text = t
	_toast_lb.visible = true
	_toast_lb.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(_toast_lb, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		if seq == _toast_seq and _toast_lb != null:
			_toast_lb.visible = false)

# ---------------- 背景 ----------------
class BgArt extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.93, 0.90, 0.82))
		# 纸纹/山
		var pts := [
			Vector2(0, 830), Vector2(90, 690), Vector2(170, 790), Vector2(260, 660),
			Vector2(360, 800), Vector2(470, 670), Vector2(580, 790), Vector2(700, 700),
			Vector2(720, 830)
		]
		draw_polyline(PackedVector2Array(pts), Color(0.52, 0.46, 0.38, 0.30), 2.0, true)
		draw_line(Vector2(0, 830), Vector2(720, 830), Color(0.38, 0.32, 0.24, 0.55), 2.0)
		# 淡墨点
		for i in 6:
			draw_circle(Vector2(60 + i * 118, 200 + (i % 3) * 150), 46.0, Color(0.45, 0.38, 0.30, 0.025))

# ---------------- 图标 ----------------
class Ico extends Control:
	var kind := "coin"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		if kind == "dot":
			draw_circle(c, minf(size.x, size.y) * 0.45, Color(0.85, 0.66, 0.23))
			return
		if kind == "coin":
			draw_circle(c, r, Color(0.88, 0.69, 0.29))
			draw_arc(c, r, 0, TAU, 40, Color(0.36, 0.27, 0.12, 0.7), 2.0)
			draw_circle(c, r * 0.30, Color(0.10, 0.09, 0.08))
			draw_rect(Rect2(c - Vector2(r * 0.20, r * 0.20), Vector2(r * 0.40, r * 0.40)), Color(0.10, 0.09, 0.08), false, 3.0)
		elif kind == "crystal":
			var pts := PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.72, -r * 0.2), c + Vector2(r * 0.44, r * 0.9),
				c + Vector2(-r * 0.44, r * 0.9), c + Vector2(-r * 0.72, -r * 0.2)
			])
			draw_colored_polygon(pts, Color(0.49, 0.76, 0.85))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.16, 0.31, 0.36, 0.7), 2.0, true)
		else:
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(r * 0.50, -r * 0.50), Color(0.78, 0.35, 0.23), 5.0, true)
			draw_line(c + Vector2(-r * 0.55, -r * 0.55), c + Vector2(r * 0.50, r * 0.50), Color(0.78, 0.35, 0.23), 5.0, true)
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(r * 0.50, -r * 0.50), Color(0.88, 0.69, 0.29), 4.0, true)

class Glyph extends Control:
	var kind := "sword"
	var col := Color(0.13, 0.12, 0.11)
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.40
		if kind == "sword":
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(r * 0.55, -r * 0.55), col, 6.0, true)
			draw_line(c + Vector2(-r * 0.15, r * 0.15), c + Vector2(r * 0.35, -r * 0.35), Color(0.79, 0.64, 0.24), 4.0, true)
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(-r * 0.30, r * 0.30), Color(0.55, 0.18, 0.14), 4.0, true)
		elif kind == "spear":
			draw_line(c + Vector2(-r * 0.6, r * 0.25), c + Vector2(r * 0.45, -r * 0.20), col, 4.0, true)
			var tip := c + Vector2(r * 0.52, -r * 0.25)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-r * 0.18, -r * 0.02), tip + Vector2(-r * 0.12, r * 0.17)]), Color(0.79, 0.64, 0.24))
		else:
			draw_line(c + Vector2(-r * 0.35, r * 0.40), c + Vector2(r * 0.45, -r * 0.40), col, 5.0, true)
			draw_line(c + Vector2(-r * 0.35, -r * 0.40), c + Vector2(r * 0.45, r * 0.40), col, 5.0, true)

class EnemyArt extends Control:
	var r := 30.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, r, Color(0.86, 0.81, 0.70))
		draw_arc(c, r, 0, TAU, 40, Color(0.16, 0.13, 0.10, 0.8), 2.0)
		draw_circle(c + Vector2(-r * 0.28, -r * 0.10), r * 0.07, Color(0.16, 0.13, 0.10, 0.8))
		draw_circle(c + Vector2(r * 0.28, -r * 0.10), r * 0.07, Color(0.16, 0.13, 0.10, 0.8))
		draw_line(c + Vector2(-r * 0.22, r * 0.25), c + Vector2(r * 0.22, r * 0.25), Color(0.16, 0.13, 0.10, 0.55), 1.5, true)

class AvatarArt extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var tex := preload("res://assets/char/player_q.png")
		if tex:
			var s := minf(size.x, size.y) * 0.92
			draw_texture_rect(tex, Rect2(c - Vector2(s * 0.5, s * 0.5), Vector2(s, s)), false)
		draw_arc(c, size.x * 0.50, 0, TAU, 48, Color(0.85, 0.66, 0.23, 0.9), 3.0)

class CardSlot extends Control:
	const F := preload("res://fonts/ink.ttf")
	const G := preload("res://shared/glyph_draw.gd")
	signal pressed
	var empty := false
	var idx := 0
	var label := ""
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.94, 0.90, 0.82) if not empty else Color(0.94, 0.90, 0.82, 0.25)
		sb.set_corner_radius_all(8)
		sb.border_color = Color(0.85, 0.66, 0.23, 0.8) if not empty else Color(0.42, 0.36, 0.28, 0.45)
		sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if empty:
			var c := size * 0.5
			draw_arc(c, minf(size.x, size.y) * 0.26, 0, TAU, 32, Color(0.42, 0.36, 0.28, 0.45), 2.0)
			draw_string(F, c + Vector2(-12, 7), "空", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.42, 0.36, 0.28, 0.6))
		else:
			var c := size * 0.5
			draw_circle(c, 36.0, Color(0.11, 0.10, 0.09, 0.92))
			draw_arc(c, 36.0, 0, TAU, 40, Color(0.85, 0.66, 0.23, 0.0), 1.0)
			G.draw(self, c, 30.0, ["sword", "spear", "dagger"][idx % 3], Color(0.91, 0.78, 0.42))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

class DrawCard extends Control:
	const F := preload("res://fonts/ink.ttf")
	const G := preload("res://shared/glyph_draw.gd")
	signal picked
	var title := ""
	var kind := "sword"
	var quality := ""
	var stat1 := ""
	var stat2 := ""
	var is_new := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.95, 0.92, 0.85)
		sb.set_corner_radius_all(8)
		sb.border_color = Color(0.85, 0.66, 0.23, 0.85)
		sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(0, 0, size.x, 42), Color(0.48, 0.33, 0.12))
		draw_string(F, Vector2(0, 29), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(0.96, 0.90, 0.76))
		if is_new:
			draw_rect(Rect2(8, 8, 30, 26), Color(0.66, 0.22, 0.15))
			draw_string(F, Vector2(8, 27), "新", HORIZONTAL_ALIGNMENT_CENTER, 30, 17, Color(0.96, 0.90, 0.76))
		var c := Vector2(size.x * 0.5, 140)
		draw_circle(c, 46, Color(0.93, 0.90, 0.82))
		draw_arc(c, 46, 0, TAU, 40, Color(0.85, 0.66, 0.23, 0.8), 2.0)
		G.draw(self, c, 38.0, kind, Color(0.13, 0.12, 0.11))
		draw_string(F, Vector2(0, 225), stat1, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(0.13, 0.12, 0.11))
		draw_string(F, Vector2(0, 255), stat2, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color(0.32, 0.28, 0.23))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()

# ---------------- 顶部 ----------------
func _build_bg() -> void:
	var bg := BgArt.new()
	bg.size = Vector2(W, H)
	add_child(bg)

func _chip(x: float, kind: String, value: String, cap: String) -> void:
	_panel(Rect2(x, 8, 216, 64), Color(0.075, 0.068, 0.060, 0.98), 8, Color(0.85, 0.66, 0.23, 0.45), 1)
	var ic := Ico.new()
	ic.kind = kind
	ic.position = Vector2(x + 12, 21)
	ic.size = Vector2(38, 38)
	add_child(ic)
	_lbl(value, Vector2(x + 58, 4), Vector2(146, 36), 28, Color(0.95, 0.91, 0.83), self, HORIZONTAL_ALIGNMENT_RIGHT)
	_lbl(cap, Vector2(x + 58, 40), Vector2(146, 20), 17, Color(0.80, 0.75, 0.65), self, HORIZONTAL_ALIGNMENT_RIGHT)

func _build_hud() -> void:
	_chip(24, "coin", "1,234", "文钱")
	_chip(252, "crystal", "1,800", "灵晶")
	_chip(480, "kill", "287", "杀敌")
	_lbl("波 1/5", Vector2(22, 92), Vector2(100, 48), 26, INK)
	for i in 5:
		var d := Color(0.85, 0.66, 0.23) if i == 0 else Color(0.38, 0.33, 0.26, 0.55)
		var c := Control.new()
		c.position = Vector2(112 + i * 18 - 6, 117 - 6)
		c.size = Vector2(12, 12)
		var ci := Ico.new()
		ci.kind = "dot"
		ci.position = Vector2.ZERO
		ci.size = Vector2(12, 12)
		ci.modulate = Color(1, 1, 1, 1) if i == 0 else Color(0.52, 0.47, 0.40, 1)
		c.add_child(ci)
		add_child(c)
	_panel(Rect2(200, 92, 235, 20), Color(0.10, 0.09, 0.08, 0.35), 3)
	_panel(Rect2(200, 92, 235 * 0.70, 20), Color(0.61, 0.16, 0.13), 3)
	_lbl("224/320", Vector2(208, 88), Vector2(120, 28), 17, Color(0.98, 0.95, 0.88))
	_panel(Rect2(200, 118, 235, 9), Color(0.10, 0.09, 0.08, 0.22), 4)
	_panel(Rect2(200, 118, 235 * 0.35, 9), Color(0.85, 0.66, 0.23), 4)
	_lbl("首领 00:37", Vector2(450, 96), Vector2(120, 30), 17, SEAL)
	_btn("总计", Rect2(570, 88, 68, 42), 17, Color(0.10, 0.09, 0.08, 0.98), LIGHT, func(): _toast("总计：卡组 7/10 · 宝物 3/3"))
	_btn("退出", Rect2(646, 88, 60, 42), 17, Color(0.10, 0.09, 0.08, 0.98), LIGHT, func(): _show_exit(true))

# ---------------- 战场 ----------------
func _build_field() -> void:
	var av := AvatarArt.new()
	av.position = Vector2(312, 722)
	av.size = Vector2(96, 96)
	add_child(av)
	var hit := Button.new()
	hit.position = Vector2(312, 722)
	hit.size = Vector2(96, 96)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hit.pressed.connect(func(): _show_attr(true))
	add_child(hit)
	for p in [Vector2(250, 480), Vector2(420, 450), Vector2(560, 550), Vector2(320, 620)]:
		var e := EnemyArt.new()
		e.position = p - Vector2(30, 30)
		e.size = Vector2(60, 60)
		e.r = 30
		add_child(e)
		e.set_meta("base_y", e.position.y)
		_enemies.append(e)
	# 挑战方形
	_btn("挑战", Rect2(0, 680, 96, 96), 20, Color(0.075, 0.068, 0.060, 0.98), Color(0.91, 0.78, 0.42), func(): _toggle_challenge())
	_build_challenge()
	_build_card_detail()
	# 功法面板
	_panel(Rect2(480, 240, 230, 190), Color(0.95, 0.91, 0.83, 0.92), 6, Color(0.85, 0.66, 0.23, 0.45), 2)
	_lbl("功法 12（可滑）", Vector2(492, 250), Vector2(200, 24), 17, DIM)
	var k := 0
	for row in 3:
		for col in 4:
			var s := SkillIcon.new()
			s.position = Vector2(506 + col * 50, 280 + row * 48)
			s.size = Vector2(40, 40)
			s.cd = 0 if k % 3 != 1 else (k % 5 + 4)
			s.kind = ["sword", "spear", "dagger"][k % 3]
			s.pressed.connect(func(): _toast("功法"))
			add_child(s)
			k += 1

class SkillIcon extends Control:
	const F := preload("res://fonts/ink.ttf")
	const G := preload("res://shared/glyph_draw.gd")
	signal pressed
	var kind := "sword"
	var cd := 0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 19, Color(0.93, 0.90, 0.82))
		draw_arc(c, 19, 0, TAU, 32, Color(0.85, 0.66, 0.23, 0.85) if cd == 0 else Color(0.45, 0.39, 0.31, 0.8), 2.0)
		G.draw(self, c, 17.0, kind, Color(0.13, 0.12, 0.11))
		if cd > 0:
			draw_circle(c, 19, Color(0.06, 0.05, 0.05, 0.45))
			draw_string(F, c + Vector2(-8, 7), str(cd), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.96, 0.90, 0.74))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

func _toggle_challenge() -> void:
	_chal_layer.visible = not _chal_layer.visible
	if _chal_layer.visible:
		_chal_layer.move_to_front()

func _build_challenge() -> void:
	_chal_layer = Control.new()
	_chal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chal_layer.visible = false
	_chal_layer.z_index = 15
	add_child(_chal_layer)
	_panel(Rect2(8, 360, 320, 320), Color(0.94, 0.90, 0.82, 0.98), 8, Color(0.85, 0.66, 0.23, 0.6), 2, _chal_layer)
	var names := ["钱怪", "晶怪", "书怪", "宝箱", "匪首"]
	for i in names.size():
		var x := 28.0 + float(i % 2) * 140.0
		var y := 380.0 + float(i / 2) * 96.0
		_btn(names[i], Rect2(x, y, 76, 76), 18, Color(0.09, 0.08, 0.07, 0.98), Color(0.91, 0.78, 0.42), func(): _toast("挑战：" + names[i]); _chal_layer.visible = false, _chal_layer)

func _build_card_detail() -> void:
	_detail_layer = Control.new()
	_detail_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_layer.visible = false
	_detail_layer.z_index = 18
	add_child(_detail_layer)
	_panel(Rect2(120, 430, 480, 260), Color(0.95, 0.91, 0.83, 0.99), 8, Color(0.85, 0.66, 0.23, 0.7), 2, _detail_layer)
	_detail_name = _lbl("青锋", Vector2(150, 455), Vector2(300, 36), 26, INK, _detail_layer)
	_detail_sub = _lbl("上品 · 剑心", Vector2(150, 495), Vector2(300, 28), 17, DIM, _detail_layer)
	_detail_line = _lbl("攻 +6 · 连击 15%", Vector2(150, 540), Vector2(380, 60), 18, INK, _detail_layer)
	_btn("×", Rect2(540, 438, 44, 36), 22, Color(0.95, 0.91, 0.83), DIM, func(): _detail_layer.visible = false, _detail_layer)

# ---------------- 卡组 ----------------
func _build_deck() -> void:
	_lbl("卡组 7/10", Vector2(22, 840), Vector2(160, 30), 20, INK)
	_page_lb = _lbl("1/2", Vector2(330, 840), Vector2(60, 30), 17, DIM, self, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("‹", Rect2(8, 890, 56, 60), 26, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _flip(-1))
	_btn("›", Rect2(656, 890, 56, 60), 26, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _flip(1))
	for i in 5:
		var s := CardSlot.new()
		s.position = Vector2(84 + i * 110, 870)
		s.size = Vector2(100, 100)
		s.idx = i
		s.pressed.connect(func(): _pick_card(s.idx))
		add_child(s)
		_slots.append(s)

func _flip(d: int) -> void:
	_page = (_page + d + 2) % 2
	_refresh_deck()

func _refresh_deck() -> void:
	if _page_lb:
		_page_lb.text = str(_page + 1) + "/2"
	for i in _slots.size():
		var s: CardSlot = _slots[i]
		var idx := _page * 5 + i
		if idx < _cards.size():
			s.empty = false
			s.idx = idx
			s.queue_redraw()
		else:
			s.empty = true
			s.idx = idx
			s.queue_redraw()

func _pick_card(idx: int) -> void:
	if idx >= _cards.size():
		return
	var names := ["青锋", "疾风", "破罡", "凝神", "铁布衫", "影步", "回风"]
	_detail_name.text = names[idx]
	_detail_sub.text = ["上品 · 剑心", "上品 · 剑心", "上品 · 剑心", "中品 · 剑心", "中品 · 剑心", "上品 · 剑心", "中品 · 剑心"][idx]
	_detail_line.text = ["攻 +6 · 连击 15%", "攻 +5 · 速度 +1", "伤 +2 · 破甲 12%", "攻 +4 · 暴击 +5%", "防御 +3 · 气血 +80", "速度 +3 · 闪避 +3%", "攻 +4 · 回气 8%"][idx]
	_detail_layer.visible = true
	_detail_layer.move_to_front()

# ---------------- 底栏 ----------------
func _build_bottom() -> void:
	_panel(Rect2(8, 980, 704, 240), Color(0.075, 0.068, 0.060, 0.98), 10, Color(0.85, 0.66, 0.23, 0.45), 2)
	_lbl("Lv 7", Vector2(22, 992), Vector2(60, 28), 18, GOLD)
	_panel(Rect2(86, 992, 540, 12), Color(0.93, 0.90, 0.82, 0.16), 6)
	_panel(Rect2(86, 992, 540 * 0.62, 12), Color(0.85, 0.66, 0.23), 6)
	_lbl("620/1000", Vector2(626, 986), Vector2(80, 24), 17, Color(0.80, 0.75, 0.65), self, HORIZONTAL_ALIGNMENT_RIGHT)
	_tile(24, 1020, 124, "market", "黑市", false)
	_tile(158, 1020, 124, "treasure", "宝物", false)
	_tile(292, 1020, 124, "mate", "伙伴", false)
	_tile(426, 1020, 124, "skill", "强化", true)
	_tile(560, 1008, 136, "draw", "抽卡", true)

func _tile(x: float, y: float, s: float, kind: String, label: String, hot: bool) -> void:
	var t := Tile.new()
	t.position = Vector2(x, y)
	t.size = Vector2(s, s)
	t.kind = kind
	t.label = label
	t.hot = hot
	var hit := func() -> void:
		match kind:
			"draw": _show_draw(true)
			"market": _toast("黑市")
			"treasure": _toast("宝物")
			"mate": _toast("伙伴")
			"skill": _toast("强化")
			_: _toast(label)
	t.pressed.connect(hit)
	add_child(t)

class Tile extends Control:
	const F := preload("res://fonts/ink.ttf")
	signal pressed
	var kind := "market"
	var label := ""
	var hot := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.48, 0.14, 0.10) if hot else Color(0.09, 0.08, 0.07, 0.98)
		sb.set_corner_radius_all(8)
		sb.border_color = Color(0.95, 0.76, 0.36, 0.95) if hot else Color(0.85, 0.66, 0.23, 0.5)
		sb.set_border_width_all(3 if hot else 1)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c := Vector2(size.x * 0.5, size.y * 0.34)
		var ink := Color(0.93, 0.88, 0.76) if hot else Color(0.88, 0.83, 0.73)
		if kind == "market":
			draw_circle(c, 20, Color(0.88, 0.69, 0.29))
			draw_circle(c, 8, Color(0.09, 0.08, 0.07))
		elif kind == "treasure":
			draw_rect(Rect2(c + Vector2(-24, -10), Vector2(48, 24)), Color(0.88, 0.83, 0.73))
			draw_rect(Rect2(c + Vector2(-24, -16), Vector2(48, 8)), Color(0.88, 0.69, 0.29))
			draw_rect(Rect2(c + Vector2(-4, -4), Vector2(8, 13)), Color(0.09, 0.08, 0.07))
		elif kind == "mate":
			draw_circle(c + Vector2(-11, -7), 9, Color(0.88, 0.83, 0.73))
			draw_circle(c + Vector2(11, -7), 9, Color(0.88, 0.83, 0.73))
			draw_circle(c + Vector2(-11, 13), 12, Color(0.88, 0.83, 0.73))
			draw_circle(c + Vector2(11, 13), 12, Color(0.88, 0.83, 0.73))
		elif kind == "skill":
			draw_rect(Rect2(c + Vector2(-17, -22), Vector2(34, 44)), Color(0.88, 0.83, 0.73))
			draw_rect(Rect2(c + Vector2(-2, -13), Vector2(4, 26)), Color(0.88, 0.69, 0.29))
			draw_rect(Rect2(c + Vector2(-13, -2), Vector2(26, 4)), Color(0.88, 0.69, 0.29))
		else:
			draw_set_transform(c + Vector2(-7, 2), -0.25, Vector2.ONE)
			draw_rect(Rect2(-16, -20, 22, 32), Color(0.93, 0.88, 0.76))
			draw_rect(Rect2(-2, -16, 22, 32), Color(0.88, 0.69, 0.29))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_string(F, Vector2(0, size.y - 14), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20 if size.x < 130 else 22, ink)
		if hot:
			draw_circle(Vector2(size.x - 14, 14), 10, Color(0.88, 0.69, 0.29))
			draw_string(F, Vector2(size.x - 20, 20), "1", HORIZONTAL_ALIGNMENT_LEFT, 20, 17, Color(0.18, 0.10, 0.05))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

# ---------------- 抽卡层 ----------------
func _build_draw() -> void:
	_draw_layer = Control.new()
	_draw_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.visible = false
	_draw_layer.z_index = 20
	add_child(_draw_layer)
	var banner := Panel.new()
	banner.position = Vector2(230, 162)
	banner.size = Vector2(260, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.54, 0.23, 0.10)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.95, 0.76, 0.36, 0.9)
	sb.set_border_width_all(2)
	banner.add_theme_stylebox_override("panel", sb)
	_draw_layer.add_child(banner)
	_lbl("抽卡 · 20 灵晶", Vector2(0, 0), Vector2(260, 42), 20, Color(0.97, 0.90, 0.74), banner, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("隐藏", Rect2(620, 162, 72, 32), 17, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _show_draw(false), _draw_layer)
	var names := ["青锋", "破罡", "回风"]
	for i in 3:
		var d := DrawCard.new()
		d.position = Vector2(30 + i * 220, 220)
		d.size = Vector2(200, 300)
		d.title = names[i]
		d.kind = ["sword", "spear", "dagger"][i]
		d.quality = "上品 · 剑心"
		d.stat1 = ["攻 +6", "伤 +2", "暴击 +8%"][i]
		d.stat2 = ["连击 15%", "破甲 12%", "回气 8%"][i]
		d.is_new = i == 0
		d.picked.connect(func(): _on_draw_pick(names[i]))
		_draw_layer.add_child(d)
		_draw_cards.append(d)
	_btn("刷新 · 5 灵晶", Rect2(250, 540, 220, 56), 20, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _on_refresh(), _draw_layer)

func _show_draw(v: bool) -> void:
	_draw_open = v
	_draw_layer.visible = v
	if v:
		_draw_layer.move_to_front()

func _on_draw_pick(n: String) -> void:
	if _cards.size() >= 10:
		_toast("卡组已满（10 格）")
		_show_draw(false)
		return
	_cards.append(_cards.size())
	_page = 1
	_refresh_deck()
	_toast("拿到：" + n + "，已进卡组")
	_show_draw(false)

func _on_refresh() -> void:
	_toast("刷新：5 灵晶")

# ---------------- 属性 ----------------
func _build_attr() -> void:
	_attr_layer = Control.new()
	_attr_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_attr_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attr_layer.visible = false
	_attr_layer.z_index = 25
	add_child(_attr_layer)
	var p := Panel.new()
	p.position = Vector2(50, 300)
	p.size = Vector2(620, 240)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.92, 0.85)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.85, 0.66, 0.23, 0.7)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	_attr_layer.add_child(p)
	var rows := [
		["气血", "320", "速度", "12"],
		["攻击", "21", "暴伤", "150%"],
		["防御", "8", "闪避", "5%"],
		["暴击", "15%", "伤害", "+2"],
	]
	for r in 4:
		var y := 30.0 + float(r) * 44.0
		_lbl(rows[r][0], Vector2(30, y), Vector2(100, 30), 20, DIM, p)
		_lbl(rows[r][1], Vector2(120, y), Vector2(90, 30), 22, INK, p, HORIZONTAL_ALIGNMENT_RIGHT)
		_lbl(rows[r][2], Vector2(330, y), Vector2(100, 30), 20, DIM, p)
		_lbl(rows[r][3], Vector2(420, y), Vector2(100, 30), 22, INK, p, HORIZONTAL_ALIGNMENT_RIGHT)
	_btn("×", Rect2(566, 8, 44, 36), 22, Color(0.95, 0.92, 0.85), DIM, func(): _show_attr(false), p)

func _show_attr(v: bool) -> void:
	_attr_open = v
	_attr_layer.visible = v
	if v:
		_attr_layer.move_to_front()

# ---------------- 退出 ----------------
func _build_exit() -> void:
	_exit_layer = Control.new()
	_exit_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_layer.visible = false
	_exit_layer.z_index = 30
	add_child(_exit_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_layer.add_child(dim)
	var p := Panel.new()
	p.position = Vector2(150, 500)
	p.size = Vector2(420, 220)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.86)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(0.85, 0.66, 0.23, 0.8)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	_exit_layer.add_child(p)
	_lbl("是否退出？", Vector2(0, 34), Vector2(420, 40), 26, INK, p, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl("退出后本局作废，奖励不保留", Vector2(0, 78), Vector2(420, 30), 17, SEAL, p, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("继续战斗", Rect2(60, 130, 150, 48), 18, Color(0.09, 0.08, 0.07, 0.98), LIGHT, func(): _show_exit(false), p)
	_btn("退出", Rect2(220, 130, 140, 48), 18, Color(0.48, 0.14, 0.10), Color(0.97, 0.90, 0.74), func(): _quit(), p)

func _show_exit(v: bool) -> void:
	_exit_open = v
	_exit_layer.visible = v
	if v:
		_exit_layer.move_to_front()

func _quit() -> void:
	get_tree().change_scene_to_file("res://menu/main_home.tscn")

# ---------------- 提示/动画 ----------------
func _build_toast() -> void:
	_toast_lb = Label.new()
	_toast_lb.position = Vector2(120, 1100)
	_toast_lb.size = Vector2(480, 36)
	_toast_lb.add_theme_font_size_override("font_size", 18)
	_toast_lb.add_theme_color_override("font_color", Color(0.96, 0.91, 0.80))
	_toast_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lb.add_theme_stylebox_override("normal", StyleBoxFlat.new())
	_toast_lb.visible = false
	_toast_lb.z_index = 40
	add_child(_toast_lb)

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _enemies.size():
		var e: Control = _enemies[i]
		e.position.y = float(e.get_meta("base_y", e.position.y)) + sin(t * 1.6 + i) * 2.0
