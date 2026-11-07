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
const BattleCore := preload("res://kushou/kushou_battle.gd")
const TokenActor := preload("res://kushou/token_actor.gd")
const CardData := preload("res://kushou/card_data.gd")

const INK := Color(0.13, 0.12, 0.11)
const PAPER := Color(0.93, 0.90, 0.82)
const PAPER_HI := Color(0.97, 0.95, 0.89)
const GOLD := Color(0.85, 0.66, 0.23)
const SEAL := Color(0.66, 0.22, 0.15)
const DIM := Color(0.42, 0.38, 0.32)
const LIGHT := Color(0.91, 0.87, 0.78)
const QUALITY_COLORS := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]

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
var _detail_card: Panel
var _detail_art: TextureRect
var _detail_effect: Label
var _detail_combo: Label
var _detail_combo_text: Label
var _detail_pips: Array = []
var _deck_count_lb: Label
var _attr_layer: Control
var _exit_layer: Control
var _toast_lb: RichTextLabel
var _toast_seq := 0
var _cards: Array = []
var _card_db := {}
var _set_cards := {}
var _pool: Array = []
var _acquired := {}
var _combined: Array = []
var _stats := {"atk": 0.0, "def": 0.0, "hp": 0.0}
var _gold_pct := 0.0
var _crystal_pct := 0.0
var _last_wave := 1
var _attack_count := 0
var _hit_count := 0
var _combo_t := 0.0
var _combined_layer: Control
var _combined_icons: Control
var _combined_detail: Control
var _toast_queue: Array = []
var _toast_busy := false
var _page_lb: Label
var _slots: Array = []
var _draw_cards: Array = []
var _enemies: Array = []
var _core = null
var _coin_lb: Label
var _kill_lb: Label
var _wave_lb: Label
var _hp_lb: Label
var _wen := 0
var _kills := 0
var _crystal := 100
var _crystal_lb: Label
var _draw_paid := false
var _draw_anim := false
var _hero_token = null
var _foe_tokens := {}
var _foe_seq := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 17
	theme = th
	_init_cards()
	_build_bg()
	_build_hud()
	_build_field()
	_build_deck()
	_build_bottom()
	_build_draw()
	_build_attr()
	_build_exit()
	_build_toast()
	_build_combined()
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
	_toast_queue.append(t)
	if not _toast_busy:
		_toast_next()

func _toast_next() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	var t: String = str(_toast_queue.pop_front())
	if _toast_lb == null:
		_toast_queue.clear()
		_toast_busy = false
		return
	_toast_lb.text = "[center]" + t + "[/center]"
	_toast_lb.visible = true
	_toast_lb.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(_toast_lb, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func() -> void:
		if _toast_lb != null:
			_toast_lb.visible = false
		_toast_busy = false
		_toast_next())

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
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal pressed
	var empty := false
	var quality := 3
	var art: Texture2D = null
	var idx = 0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		if empty:
			var c := Color(0.42, 0.36, 0.28, 0.45)
			draw_dashed_line(Vector2(2,2), Vector2(size.x-2,2), c, 2.0, 6.0)
			draw_dashed_line(Vector2(size.x-2,2), Vector2(size.x-2,size.y-2), c, 2.0, 6.0)
			draw_dashed_line(Vector2(size.x-2,size.y-2), Vector2(2,size.y-2), c, 2.0, 6.0)
			draw_dashed_line(Vector2(2,size.y-2), Vector2(2,2), c, 2.0, 6.0)
			draw_string(F, size * 0.5 + Vector2(-10, 7), "空", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.42,0.36,0.28,0.55))
			return
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.93, 0.86, 0.98)
		sb.set_corner_radius_all(8)
		sb.border_color = QC[clampi(quality-1,0,4)]
		sb.set_border_width_all(5)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if art != null:
			draw_texture_rect(art, Rect2(8, 8, size.x - 16, size.y - 16), false)
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

class DrawCard extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal picked
	var data: Dictionary = {}
	var _art_rect: TextureRect
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_art_rect = TextureRect.new()
		_art_rect.position = Vector2(40, 52)
		_art_rect.size = Vector2(120, 120)
		_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_art_rect)
	func _draw() -> void:
		if data.is_empty():
			return
		var q := clampi(int(data.get("quality", 3)) - 1, 0, 4)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.93, 0.86, 0.99)
		sb.set_corner_radius_all(9)
		sb.border_color = QC[q]
		sb.set_border_width_all(6)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		draw_string(F, Vector2(0, 34), str(data.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.14,0.11,0.08))
		var tex := load(str(data.get("art", "")))
		if _art_rect != null:
			_art_rect.texture = tex
		draw_string(F, Vector2(20, 204), str(data.get("own_text", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 21, Color(0.14,0.11,0.08))
		draw_line(Vector2(20, 220), Vector2(size.x - 20, 220), Color(0.5,0.4,0.25,0.35), 1.5)
		draw_string(F, Vector2(20, 246), str(data.get("combo_name", "")) + " 0/" + str(data.get("set_size", 0)), HORIZONTAL_ALIGNMENT_LEFT, 140, 18, Color(0.42,0.30,0.12))
		draw_string(F, Vector2(20, 280), str(data.get("trigger", "")) + "：" + str(data.get("combo_text", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 17, Color(0.2,0.16,0.12))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()


func _build_bg() -> void:
	var bg := BgArt.new()
	bg.size = Vector2(W, H)
	add_child(bg)

func _chip(x: float, kind: String, value: String, cap: String) -> Label:
	_panel(Rect2(x, 8, 216, 64), Color(0.075, 0.068, 0.060, 0.98), 8, Color(0.85, 0.66, 0.23, 0.45), 1)
	var ic := Ico.new()
	ic.kind = kind
	ic.position = Vector2(x + 12, 21)
	ic.size = Vector2(38, 38)
	add_child(ic)
	var vl := _lbl(value, Vector2(x + 58, 4), Vector2(146, 36), 28, Color(0.95, 0.91, 0.83), self, HORIZONTAL_ALIGNMENT_RIGHT)
	_lbl(cap, Vector2(x + 58, 40), Vector2(146, 20), 17, Color(0.80, 0.75, 0.65), self, HORIZONTAL_ALIGNMENT_RIGHT)
	return vl

func _build_hud() -> void:
	_coin_lb = _chip(24, "coin", "0", "文钱")
	_crystal_lb = _chip(252, "crystal", "100", "灵晶")
	_kill_lb = _chip(480, "kill", "0", "杀敌")
	_wave_lb = _lbl("波 1/5", Vector2(22, 92), Vector2(100, 48), 26, INK)
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
	_hp_lb = _lbl("200/200", Vector2(208, 88), Vector2(120, 28), 17, Color(0.98, 0.95, 0.88))
	_panel(Rect2(200, 118, 235, 9), Color(0.10, 0.09, 0.08, 0.22), 4)
	_panel(Rect2(200, 118, 235 * 0.35, 9), Color(0.85, 0.66, 0.23), 4)
	_lbl("首领 00:37", Vector2(450, 96), Vector2(120, 30), 17, SEAL)
	_btn("总计", Rect2(570, 88, 68, 42), 17, Color(0.10, 0.09, 0.08, 0.98), LIGHT, func(): _toast("总计：卡组 7/10 · 宝物 3/3"))
	_btn("退出", Rect2(646, 88, 60, 42), 17, Color(0.10, 0.09, 0.08, 0.98), LIGHT, func(): _show_exit(true))

# ---------------- 战场 ----------------
func _build_field() -> void:
	_core = BattleCore.new()
	_core.position = Vector2(8, 150)
	_core.size = Vector2(704, 650)
	_core.mouse_filter = Control.MOUSE_FILTER_STOP
	_core.modulate = Color(1, 1, 1, 0.25)
	add_child(_core)
	_core.setup({"atk": 12.0, "hp_max": 200.0, "mp_max": 100.0})
	_core.set_wave(1)
	_core.coin.connect(_on_core_coin)
	_core.kill.connect(_on_core_kill)
	_core.hero_attack.connect(_on_hero_attack)
	_core.hero_hit.connect(_on_hero_hit)
	_core.hero_down.connect(func() -> void: _toast("倒下了"))
	_core.boss_arrived.connect(func(_t: int) -> void: _toast("首领来了"))
	_core.start_run()
	_hero_token = TokenActor.new()
	_hero_token.setup(PLAYER_TEX, 44.0, Color(0.85, 0.66, 0.23), true)
	_hero_token.set_role("player")
	_hero_token.set_weapon("sword")
	_hero_token.show_bar = true
	_hero_token.bar_w = 84.0
	_hero_token.unit_name = "少侠"
	_hero_token.position = Vector2(360, 758)
	_hero_token.z_index = 6
	add_child(_hero_token)
	var hit := Button.new()
	hit.position = Vector2(312, 710)
	hit.size = Vector2(96, 96)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hit.pressed.connect(func(): _show_attr(true))
	add_child(hit)
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
	_detail_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_layer.visible = false
	_detail_layer.z_index = 30
	add_child(_detail_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_detail_layer.visible = false)
	_detail_layer.add_child(dim)
	_detail_card = Panel.new()
	_detail_card.position = Vector2(210, 420)
	_detail_card.size = Vector2(300, 420)
	_detail_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_layer.add_child(_detail_card)
	_detail_name = _lbl("青锋", Vector2(230, 438), Vector2(260, 40), 30, INK, _detail_layer, HORIZONTAL_ALIGNMENT_CENTER)
	_detail_art = TextureRect.new()
	_detail_art.position = Vector2(230, 486)
	_detail_art.size = Vector2(260, 150)
	_detail_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_detail_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_layer.add_child(_detail_art)
	_lbl("效 果", Vector2(230, 650), Vector2(120, 26), 18, DIM, _detail_layer)
	_detail_effect = _lbl("攻击 +6", Vector2(230, 678), Vector2(260, 36), 26, INK, _detail_layer)
	_lbl("组 合", Vector2(230, 728), Vector2(120, 26), 18, DIM, _detail_layer)
	_detail_combo = _lbl("成长 1/3", Vector2(300, 728), Vector2(120, 28), 22, Color(0.54, 0.35, 0.12), _detail_layer)
	for i in 6:
		var pip := ColorRect.new()
		pip.position = Vector2(424 + i * 14, 734)
		pip.size = Vector2(11, 11)
		pip.color = Color(0.42, 0.36, 0.28, 0.3)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_detail_layer.add_child(pip)
		_detail_pips.append(pip)
	_detail_combo_text = _lbl("成长：杀敌提升 1 点攻击", Vector2(230, 768), Vector2(260, 44), 17, INK, _detail_layer)
	_btn("×", Rect2(574, 430, 40, 34), 22, Color(0.95, 0.91, 0.83), DIM, func(): _detail_layer.visible = false, _detail_layer)

# ---------------- 卡组 ----------------
func _build_deck() -> void:
	_deck_count_lb = _lbl("卡组 0/10", Vector2(22, 840), Vector2(160, 30), 20, INK)
	_page_lb = _lbl("1/2", Vector2(330, 840), Vector2(60, 30), 17, DIM, self, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("<", Rect2(8, 890, 56, 60), 28, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _flip(-1))
	_btn(">", Rect2(656, 890, 56, 60), 28, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _flip(1))
	for i in 5:
		var s := CardSlot.new()
		s.position = Vector2(46 + i * 132, 870)
		s.size = Vector2(100, 100)
		s.idx = ""
		s.pressed.connect(func(): _pick_card(str(s.idx)))
		add_child(s)
		_slots.append(s)

func _flip(d: int) -> void:
	_page = (_page + d + 2) % 2
	_refresh_deck()

func _refresh_deck() -> void:
	if _page_lb:
		_page_lb.text = str(_page + 1) + "/2"
	if _deck_count_lb:
		_deck_count_lb.text = "卡组 " + str(_cards.size()) + "/10"
	for i in _slots.size():
		var s: CardSlot = _slots[i]
		var at := _page * 5 + i
		if at < _cards.size():
			var id := str(_cards[at])
			var c: Dictionary = _card_db[id]
			s.empty = false
			s.idx = id
			s.quality = int(c["quality"])
			s.art = load(str(c["art"]))
			s.queue_redraw()
		else:
			s.empty = true
			s.idx = ""
			s.queue_redraw()

func _pick_card(id: String) -> void:
	if id == "" or not _card_db.has(id): return
	var c: Dictionary = _card_db[id]
	_detail_name.text = str(c["name"])
	_detail_art.texture = load(str(c["art"]))
	_detail_effect.text = str(c["own_text"])
	var prog := _set_progress(str(c["set_id"]))
	_detail_combo.text = str(c["combo_name"]) + " " + str(prog) + "/" + str(c["set_size"])
	_detail_combo_text.text = str(c["trigger"]) + "：" + str(c["combo_text"])
	var q := clampi(int(c["quality"]) - 1, 0, 4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.86, 0.99)
	sb.set_corner_radius_all(9)
	sb.border_color = QUALITY_COLORS[q]
	sb.set_border_width_all(7)
	_detail_card.add_theme_stylebox_override("panel", sb)
	var set_n := int(c["set_size"])
	for i in _detail_pips.size():
		var pip := _detail_pips[i] as ColorRect
		pip.visible = i < set_n
		pip.color = Color(0.78, 0.58, 0.22) if i < prog else Color(0.42, 0.36, 0.28, 0.3)
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
	for i in 3:
		var d := DrawCard.new()
		d.position = Vector2(30 + i * 220, 220)
		d.set_meta("base", d.position)
		d.pivot_offset = Vector2(100, 150)
		d.size = Vector2(200, 300)
		d.picked.connect(func() -> void: _on_draw_pick(d))
		_draw_layer.add_child(d)
		_draw_cards.append(d)
	_btn("刷新 · 5 灵晶", Rect2(250, 540, 220, 56), 20, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _on_refresh(), _draw_layer)

func _roll_draw() -> void:
	var cands := _pool.duplicate()
	cands.shuffle()
	for i in _draw_cards.size():
		var dc: DrawCard = _draw_cards[i]
		if i < cands.size():
			var c: Dictionary = (_card_db[str(cands[i])] as Dictionary).duplicate()
			c["_id"] = str(cands[i])
			dc.data = c
		else:
			dc.data = {}
		dc.queue_redraw()

func _update_crystal() -> void:
	if _crystal_lb != null:
		_crystal_lb.text = str(_crystal)

func _show_draw(v: bool) -> void:
	if v:
		if not _draw_paid:
			if _pool.is_empty():
				_toast("本局卡池已空")
				return
			if _crystal < 20:
				_toast("灵晶不够：抽卡要 20")
				return
			_crystal -= 20
			_update_crystal()
			_roll_draw()
			_draw_paid = true
		_draw_layer.visible = true
		_draw_layer.move_to_front()
		_pop_draw_cards()
	else:
		_draw_layer.visible = false
		_draw_open = false

func _on_draw_pick(card: DrawCard) -> void:
	if _draw_anim or card == null or card.data.is_empty(): return
	var id := str(card.data.get("_id", ""))
	if id == "": return
	if _cards.size() >= 10:
		_toast("卡组已满（10 格）")
		return
	_draw_anim = true
	var target := Vector2(46 + float(_cards.size() % 5) * 132.0, 870)
	for other in _draw_cards:
		if other != card:
			other.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tw0 := create_tween()
			tw0.tween_property(other, "modulate:a", 0.28, 0.18)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 3
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "position", target, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "scale", Vector2(0.36, 0.36), 0.34)
	tw.tween_property(card, "modulate:a", 0.42, 0.34)
	tw.chain().tween_callback(func() -> void:
		_draw_anim = false
		_add_card(id))

func _on_refresh() -> void:
	if _draw_anim: return
	if _pool.is_empty():
		_toast("卡池已空，没法刷新")
		return
	if _crystal < 5:
		_toast("灵晶不够：刷新要 5")
		return
	_crystal -= 5
	_update_crystal()
	_draw_anim = true
	for card in _draw_cards:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "scale", Vector2(0.72, 0.72), 0.16)
		tw.tween_property(card, "modulate:a", 0.0, 0.16)
	await get_tree().create_timer(0.2).timeout
	_roll_draw()
	_draw_anim = false
	_pop_draw_cards()
	_toast("刷新：5 灵晶")

func _pop_draw_cards() -> void:
	for i in _draw_cards.size():
		var card: DrawCard = _draw_cards[i]
		var base: Vector2 = card.get_meta("base", Vector2(30 + i * 220, 220))
		card.visible = true
		card.position = base + Vector2(0, 70)
		card.scale = Vector2(0.82, 0.82)
		card.modulate.a = 0.0
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "position", base, 0.24).set_delay(i * 0.055).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.24).set_delay(i * 0.055)
		tw.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(i * 0.055)

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
	_toast_lb = RichTextLabel.new()
	_toast_lb.bbcode_enabled = true
	_toast_lb.fit_content = false
	_toast_lb.scroll_active = false
	_toast_lb.position = Vector2(0, 620)
	_toast_lb.size = Vector2(720, 48)
	_toast_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_lb.add_theme_font_override("normal_font", FONT)
	_toast_lb.add_theme_font_size_override("normal_font_size", 26)
	_toast_lb.add_theme_color_override("default_color", INK)
	_toast_lb.visible = false
	_toast_lb.z_index = 40
	add_child(_toast_lb)

func _toast_card(name: String, quality: int, tail: String) -> void:
	var col: String = QUALITY_COLORS[clampi(quality - 1, 0, 4)].to_html(false)
	_toast("[color=#" + col + "]" + name + "[/color]　" + tail)

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _enemies.size():
		var e: Control = _enemies[i]
		e.position.y = float(e.get_meta("base_y", e.position.y)) + sin(t * 1.6 + i) * 2.0
	if _core != null:
		if int(_core.wave) != _last_wave:
			_last_wave = int(_core.wave)
			_trigger_combos("每波")
		_combo_t += _delta
		if _combo_t >= 6.0:
			_combo_t -= 6.0
			_trigger_combos("每 6 秒")
		if _wave_lb != null:
			_wave_lb.text = "波 %d/5" % int(_core.wave)
		if _hp_lb != null:
			_hp_lb.text = "%d/%d" % [int(float(_core.hero.get("hp", 0))), int(float(_core.hero.get("hp_max", 1)))]
		if _hero_token != null:
			_hero_token.position = _core.position + _core.hero_pos
			_hero_token.hp_ratio = float(_core.hero.get("hp", 0.0)) / maxf(1.0, float(_core.hero.get("hp_max", 1.0)))
			_hero_token.queue_redraw()
		var active := {}
		for f in _core.foes:
			if not f.has("_tid"):
				_foe_seq += 1
				f["_tid"] = _foe_seq
				_foe_tokens[_foe_seq] = _make_foe_token(f)
			var tid: int = int(f["_tid"])
			active[tid] = true
			var tk = _foe_tokens.get(tid)
			if tk != null:
				tk.position = _core.position + Vector2(float(f["x"]), float(f["y"]))
				tk.hp_ratio = float(f["hp"]) / maxf(1.0, float(f["hp_max"]))
				tk.unit_name = str(f.get("name", ""))
				tk.visible = float(f.get("y", 0.0)) >= 90.0
				tk.queue_redraw()
		for tid in _foe_tokens.keys():
			if not active.has(tid):
				var tk = _foe_tokens[tid]
				if tk != null:
					tk.play_down()
				_foe_tokens.erase(tid)

func _on_core_kill(n: int) -> void:
	_kills += n
	if _kill_lb != null:
		_kill_lb.text = str(_kills)
	_trigger_combos("每次击杀")

func _make_foe_token(f: Dictionary):
	var kind := str(f.get("kind", "normal"))
	var boss := bool(f.get("boss", false))
	var rad := 36.0 if boss else 26.0
	var ring := Color(0.42, 0.36, 0.28)
	if kind == "coin":
		ring = Color(0.85, 0.66, 0.23)
	elif kind == "crystal":
		ring = Color(0.35, 0.55, 0.75)
	elif boss:
		ring = Color(0.68, 0.18, 0.14)
	var tk = TokenActor.new()
	tk.setup(null, rad, ring, false)
	tk.show_bar = true
	tk.bar_w = 84.0 if boss else 54.0
	tk.unit_name = str(f.get("name", ""))
	tk.z_index = 5
	tk.position = _core.position + Vector2(float(f["x"]), float(f["y"]))
	add_child(tk)
	var mark := Label.new()
	mark.text = "王" if boss else ("钱" if kind == "coin" else ("晶" if kind == "crystal" else "怪"))
	mark.position = Vector2(-rad, -rad * 2.0 + 6.0)
	mark.size = Vector2(rad * 2.0, rad * 1.5)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_override("font", FONT)
	mark.add_theme_font_size_override("font_size", 22 if not boss else 28)
	mark.add_theme_color_override("font_color", Color(0.30, 0.24, 0.16))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tk.add_child(mark)
	return tk

# ---------------- 卡池 / 组合 ----------------
func _init_cards() -> void:
	var d: Dictionary = CardData.build()
	_card_db = d["cards"]
	_set_cards = d["sets"]
	_pool = (d["entries"] as Array).duplicate()
	_cards.clear()
	_acquired.clear()
	_combined.clear()

func _set_progress(set_id: String) -> int:
	if not _set_cards.has(set_id):
		return 0
	var n := 0
	for id in _set_cards[set_id]:
		if _cards.has(id):
			n += 1
	return n

func _on_core_coin(n: int) -> void:
	var gain := int(round(float(n) * (1.0 + _gold_pct / 100.0)))
	_wen += gain
	if _coin_lb != null:
		_coin_lb.text = str(_wen)

func _trigger_combos(trigger: String) -> void:
	for rec in _combined:
		if str(rec.get("trigger", "")) == trigger:
			_apply_combo(rec)
	if _combined_layer != null and _combined_layer.visible:
		_refresh_combined()

func _apply_combo(rec: Dictionary) -> void:
	rec["stacks"] = int(rec.get("stacks", 0)) + 1
	var key := str(rec.get("combo_key", ""))
	var val := float(rec.get("combo_val", 0))
	match key:
		"atk":
			_stats["atk"] = float(_stats["atk"]) + val
			if _core != null: _core.hero["atk"] = float(_core.hero.get("atk", 0.0)) + val
		"def":
			_stats["def"] = float(_stats["def"]) + val
			if _core != null: _core.hero["def"] = float(_core.hero.get("def", 0.0)) + val
		"hp":
			_stats["hp"] = float(_stats["hp"]) + val
			if _core != null:
				_core.hero["hp_max"] = float(_core.hero.get("hp_max", 1.0)) + val
				_core.hero["hp"] = float(_core.hero.get("hp", 0.0)) + val
		"heal":
			if _core != null: _core.hero["hp"] = minf(float(_core.hero.get("hp_max", 1.0)), float(_core.hero.get("hp", 0.0)) + val)
		"gold_pct":
			_gold_pct += val
		"gold_flat":
			_wen += int(val)
			if _coin_lb != null: _coin_lb.text = str(_wen)
		"crystal_flat":
			_crystal += int(val)
			_update_crystal()

func _check_sets() -> void:
	var changed := true
	while changed:
		changed = false
		for sid_v in _set_cards.keys():
			var sid := str(sid_v)
			var ids: Array = _set_cards[sid]
			var all_in := true
			for cid in ids:
				if not _cards.has(str(cid)):
					all_in = false
					break
			if all_in:
				_activate_set(sid)
				changed = true
				break

func _activate_set(sid: String) -> void:
	var ids: Array = _set_cards[sid]
	if ids.is_empty(): return
	var first: Dictionary = _card_db[str(ids[0])]
	var own_sum := {"atk": 0.0, "def": 0.0, "hp": 0.0, "gold_pct": 0.0, "crystal_pct": 0.0}
	var srcs: Array = []
	for cid_v in ids:
		var cid := str(cid_v)
		var c: Dictionary = _card_db[cid]
		srcs.append(str(c["name"]))
		var k := str(c["own_key"])
		if own_sum.has(k):
			own_sum[k] = float(own_sum[k]) + float(c["own_val"])
		_cards.erase(cid)
	var rec := {"set_id": sid, "series": str(first["series"]), "tier": int(first["tier"]),
		"name": str(first["combo_name"]), "size": int(first["set_size"]),
		"quality": int(first["quality"]), "art": str(first["art"]),
		"own_text": _own_text(own_sum), "combo_text": str(first["combo_text"]),
		"trigger": str(first["trigger"]), "combo_key": str(first["combo_key"]),
		"combo_val": int(first["combo_val"]), "stacks": 0, "sources": srcs}
	_combined.append(rec)
	_apply_own(own_sum)
	_toast_card(str(rec["name"]), int(rec["quality"]), "组合激活，" + str(rec["size"]) + " 张已清空")
	var parts := sid.split("_")
	if parts.size() == 2:
		var tier := int(parts[1])
		if tier < 3:
			var nid := str(parts[0]) + "_" + str(tier + 1)
			if _set_cards.has(nid):
				var entry := str((_set_cards[nid] as Array)[0])
				if not _acquired.has(entry) and not _pool.has(entry):
					_pool.append(entry)
					var ec: Dictionary = _card_db[entry]
					_toast_card(str(ec["name"]), int(ec["quality"]), "已加入卡池")
	_refresh_deck()
	if _combined_layer != null and _combined_layer.visible:
		_refresh_combined()

func _own_text(s: Dictionary) -> String:
	var arr: Array = []
	if float(s["atk"]) > 0: arr.append("攻击 +" + str(int(s["atk"])))
	if float(s["def"]) > 0: arr.append("防御 +" + str(int(s["def"])))
	if float(s["hp"]) > 0: arr.append("气血 +" + str(int(s["hp"])))
	if float(s["gold_pct"]) > 0: arr.append("金币 +" + str(int(s["gold_pct"])) + "%")
	if float(s["crystal_pct"]) > 0: arr.append("灵晶 +" + str(int(s["crystal_pct"])) + "%")
	return " · ".join(PackedStringArray(arr))

func _apply_own(s: Dictionary) -> void:
	_stats["atk"] = float(_stats["atk"]) + float(s["atk"])
	_stats["def"] = float(_stats["def"]) + float(s["def"])
	_stats["hp"] = float(_stats["hp"]) + float(s["hp"])
	_gold_pct += float(s["gold_pct"])
	_crystal_pct += float(s["crystal_pct"])
	if _core != null:
		_core.hero["atk"] = float(_core.hero.get("atk", 0.0)) + float(s["atk"])
		_core.hero["def"] = float(_core.hero.get("def", 0.0)) + float(s["def"])
		var hp_add := float(s["hp"])
		_core.hero["hp_max"] = float(_core.hero.get("hp_max", 1.0)) + hp_add
		_core.hero["hp"] = float(_core.hero.get("hp", 0.0)) + hp_add

func _add_card(id: String) -> void:
	if not _card_db.has(id): return
	if _cards.size() >= 10:
		_toast("卡组已满（10 格）")
		return
	var c: Dictionary = _card_db[id]
	_pool.erase(id)
	_cards.append(id)
	_acquired[id] = true
	if bool(c.get("entry", false)):
		for uid in c.get("unlock_ids", []):
			var us := str(uid)
			if not _acquired.has(us) and not _pool.has(us):
				_pool.append(us)
				var uc: Dictionary = _card_db[us]
				_toast_card(str(uc["name"]), int(uc["quality"]), "已加入卡池")
	_check_sets()
	_page = 0
	_refresh_deck()
	_toast_card(str(c["name"]), int(c["quality"]), "已入卡组")
	_draw_paid = false
	_show_draw(false)

func _build_combined() -> void:
	_combined_layer = Control.new()
	_combined_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_combined_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_combined_layer.visible = false
	_combined_layer.z_index = 32
	add_child(_combined_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_show_combined(false))
	_combined_layer.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(32, 150)
	panel.size = Vector2(656, 900)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.91, 0.83, 0.99)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.70, 0.52, 0.22, 0.7)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_combined_layer.add_child(panel)
	_lbl("总 计", Vector2(60, 168), Vector2(260, 46), 34, INK, _combined_layer)
	_lbl("已激活组合 · 本局有效", Vector2(60, 216), Vector2(360, 28), 18, DIM, _combined_layer)
	_btn("×", Rect2(624, 170, 44, 36), 22, Color(0.95, 0.91, 0.83), DIM, func(): _show_combined(false), _combined_layer)
	_combined_icons = Control.new()
	_combined_icons.position = Vector2(50, 260)
	_combined_icons.size = Vector2(620, 640)
	_combined_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combined_layer.add_child(_combined_icons)
	_combined_detail = Control.new()
	_combined_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_combined_detail.visible = false
	_combined_layer.add_child(_combined_detail)

func _show_combined(v: bool) -> void:
	_combined_layer.visible = v
	if v:
		_refresh_combined()
		_combined_layer.move_to_front()

func _refresh_combined() -> void:
	for ch in _combined_icons.get_children(): ch.queue_free()
	_combined_detail.visible = false
	if _combined.is_empty():
		_lbl("还没有已激活组合", Vector2(20, 20), Vector2(580, 40), 22, DIM, _combined_icons)
		return
	for i in _combined.size():
		var rec: Dictionary = _combined[i]
		var ic := CombinedIcon.new()
		ic.position = Vector2(float(i % 5) * 120.0, float(i / 5) * 130.0)
		ic.size = Vector2(100, 100)
		ic.quality = int(rec["quality"])
		ic.art = load(str(rec["art"]))
		ic.size_n = int(rec["size"])
		ic.pressed.connect(func() -> void: _show_combined_detail(rec))
		_combined_icons.add_child(ic)

func _show_combined_detail(rec: Dictionary) -> void:
	for ch in _combined_detail.get_children(): ch.queue_free()
	_combined_detail.visible = true
	var p := Panel.new()
	p.position = Vector2(140, 300)
	p.size = Vector2(440, 420)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.85, 0.99)
	sb.set_corner_radius_all(9)
	sb.border_color = QUALITY_COLORS[clampi(int(rec["quality"]) - 1, 0, 4)]
	sb.set_border_width_all(7)
	p.add_theme_stylebox_override("panel", sb)
	_combined_detail.add_child(p)
	_lbl(str(rec["name"]), Vector2(170, 326), Vector2(360, 40), 30, INK, _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	var sz_cn: Array = ["", "三", "四", "五", "六"]
	_lbl(str(sz_cn[clampi(int(rec["size"]), 1, 6)]) + "合一", Vector2(420, 330), Vector2(100, 28), 18, Color(0.64,0.22,0.15), _combined_detail)
	_lbl("卡面合计：" + str(rec["own_text"]), Vector2(170, 390), Vector2(380, 32), 20, INK, _combined_detail)
	_lbl("组合：" + str(rec["combo_text"]), Vector2(170, 430), Vector2(380, 32), 20, INK, _combined_detail)
	_lbl("触发：" + str(rec["trigger"]) + "　已叠 " + str(int(rec["stacks"])), Vector2(170, 470), Vector2(380, 30), 18, DIM, _combined_detail)
	_lbl("源：" + " · ".join(PackedStringArray(rec["sources"])), Vector2(170, 510), Vector2(380, 60), 17, Color(0.38,0.30,0.20), _combined_detail)
	_btn("×", Rect2(592, 302, 34, 30), 20, Color(0.97,0.93,0.85), DIM, func(): _combined_detail.visible = false, _combined_detail)

class CombinedIcon extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal pressed
	var quality := 3
	var art: Texture2D = null
	var size_n := 3
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96,0.93,0.86,0.98)
		sb.set_corner_radius_all(8)
		sb.border_color = QC[clampi(quality-1,0,4)]
		sb.set_border_width_all(5)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if art != null:
			draw_texture_rect(art, Rect2(8,8,size.x-16,size.y-16), false)
		draw_rect(Rect2(size.x-32,6,26,22), Color(0.64,0.22,0.15))
		draw_string(F, Vector2(size.x-30,23), "合", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.98,0.92,0.78))
		draw_string(F, Vector2(size.x-34,size.y-8), str(size_n), HORIZONTAL_ALIGNMENT_RIGHT, 26, 16, Color(0.38,0.30,0.20))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

func _on_hero_attack() -> void:
	_attack_count += 1
	_trigger_combos("每次攻击")
	if _attack_count % 5 == 0:
		_trigger_combos("每 5 次攻击")
	if _attack_count % 10 == 0:
		_trigger_combos("每 10 次攻击")

func _on_hero_hit() -> void:
	_hit_count += 1
	_trigger_combos("每次受击")
