extends RefCounted
# ============================================================
# shared/ui_kit.gd —— 共享界面骨架
#   顶栏 0–90 · 页头 90–152 · 内容 152–1176 · 底栏 1176–1280
#   三页（主界面 / 装备 / 请神）共用；只画形状，文字一律用 Label。
# ============================================================
const P := preload("res://shared/ui_pal.gd")
const Motion := preload("res://shared/ui_motion.gd")

static func navigation_available(page: Control) -> bool:
	return is_instance_valid(page) and page.is_inside_tree() and not page.is_queued_for_deletion() and not bool(page.get_meta("scene_changing", false))

static func navigate(page: Control, path: String) -> Error:
	if not navigation_available(page): return ERR_BUSY
	if not ResourceLoader.exists(path): return ERR_FILE_NOT_FOUND
	page.set_meta("scene_changing", true)
	var err := page.get_tree().change_scene_to_file(path)
	if err != OK: page.set_meta("scene_changing", false)
	return err

static func navigate_packed(page: Control, scene: PackedScene) -> Error:
	if not navigation_available(page): return ERR_BUSY
	if scene == null: return ERR_INVALID_PARAMETER
	page.set_meta("scene_changing", true)
	var err := page.get_tree().change_scene_to_packed(scene)
	if err != OK: page.set_meta("scene_changing", false)
	return err
const TEX_PAPER := preload("res://assets/art/ui/tile_paper.png")

const W := 720.0
const H := 1280.0
const TOP_H := 90.0
const HEAD_H := 62.0
const DOCK_Y := 1176.0
const DOCK_H := 104.0

static func theme() -> Theme:
	var th := Theme.new()
	th.default_font = P.FONT
	th.default_font_size = 20
	return th

static func bg(root: Control) -> void:
	var tr := TextureRect.new()
	tr.texture = TEX_PAPER
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)

# ---------------- 装饰（程序绘制的匾额/分隔线，比生成图锐利） ----------------
class Deco extends Control:
	var kind := "banner"          # banner / divider
	var col := Color(0.42, 0.35, 0.25, 0.55)
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if kind == "banner":
			var p := 6.0
			draw_line(Vector2(p, 6), Vector2(size.x - p, 6), col, 1.4, true)
			draw_line(Vector2(p, size.y - 6), Vector2(size.x - p, size.y - 6), col, 1.4, true)
			draw_line(Vector2(p, 2), Vector2(p, size.y - 2), col, 1.8, true)
			draw_line(Vector2(size.x - p, 2), Vector2(size.x - p, size.y - 2), col, 1.8, true)
			# 端头小回钩
			draw_line(Vector2(p + 10, 2), Vector2(p + 10, 12), col, 1.2, true)
			draw_line(Vector2(size.x - p - 10, 2), Vector2(size.x - p - 10, 12), col, 1.2, true)
			draw_line(Vector2(p + 10, size.y - 2), Vector2(p + 10, size.y - 12), col, 1.2, true)
			draw_line(Vector2(size.x - p - 10, size.y - 2), Vector2(size.x - p - 10, size.y - 12), col, 1.2, true)
			var mid := size * 0.5
			draw_colored_polygon(PackedVector2Array([
				Vector2(mid.x, 1), Vector2(mid.x + 5, 6), Vector2(mid.x, 11), Vector2(mid.x - 5, 6)]), col)
		else:
			var mid := size * 0.5
			draw_line(Vector2(6, mid.y), Vector2(mid.x - 16, mid.y), col, 1.4, true)
			draw_line(Vector2(mid.x + 16, mid.y), Vector2(size.x - 6, mid.y), col, 1.4, true)
			draw_colored_polygon(PackedVector2Array([
				mid + Vector2(0, -6), mid + Vector2(8, 0), mid + Vector2(0, 6), mid + Vector2(-8, 0)]), col)
			draw_circle(mid, 1.8, col)

static func deco(root: Control, kind: String, rect: Rect2, alpha := 1.0) -> Control:
	var d := Deco.new()
	d.kind = kind
	d.col = Color(0.42, 0.35, 0.25, 0.55 * alpha)
	d.position = rect.position
	d.size = rect.size
	root.add_child(d)
	return d

static func label(root: Control, txt: String, pos: Vector2, sz: Vector2, fs: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else root).add_child(l)
	return l

static func panel(root: Control, rect: Rect2, bg_col: Color, radius := 8,
		border := Color(0, 0, 0, 0), bw := 0, parent: Control = null) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else root).add_child(p)
	return p

static func button(root: Control, txt: String, rect: Rect2, fs: int, bg_col: Color, fg: Color,
		cb: Callable, border := Color(0, 0, 0, 0), bw := 0, radius := 8, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate() as StyleBoxFlat
	hb.bg_color = bg_col.lightened(0.07)
	b.add_theme_stylebox_override("hover", hb)
	var pb := sb.duplicate() as StyleBoxFlat
	pb.bg_color = bg_col.darkened(0.06)
	b.add_theme_stylebox_override("pressed", pb)
	if cb.is_valid():
		b.pressed.connect(cb)
	(parent if parent != null else root).add_child(b)
	Motion.bind_button(b)
	return b

# ---------------- 顶栏 ----------------
static func app_bar(root: Control, role_name: String, grade: String, on_settings: Callable) -> Dictionary:
	var ch := BarChrome.new()
	ch.size = Vector2(W, TOP_H)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ch)
	label(root, "侠", Vector2(26, 16), Vector2(52, 58), 26, P.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
	label(root, role_name, Vector2(92, 12), Vector2(150, 34), 22, P.PAPER_HI)
	panel(root, Rect2(92, 52, 62, 26), Color(0, 0, 0, 0), 4, Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.55), 1)
	label(root, grade, Vector2(92, 52), Vector2(62, 26), 15, P.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
	var coin_lb := label(root, "0", Vector2(282, 22), Vector2(112, 44), 24, P.PAPER_HI, HORIZONTAL_ALIGNMENT_RIGHT)
	var crystal_lb := label(root, "0", Vector2(432, 22), Vector2(112, 44), 24, P.PAPER_HI, HORIZONTAL_ALIGNMENT_RIGHT)
	ch.bind_currencies(coin_lb, crystal_lb)
	button(root, "设置", Rect2(578, 24, 86, 42), 18, Color(0, 0, 0, 0), P.PAPER_HI, on_settings,
		Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.45), 1, 6)
	return {"coin": coin_lb, "crystal": crystal_lb}

# ---------------- 页头 ----------------
static func page_head(root: Control, title: String, back_cb := Callable(), right_txt := "", right_cb := Callable()) -> void:
	var has_back := back_cb.is_valid()
	var x0 := 16.0
	if has_back:
		button(root, "‹", Rect2(16, 100, 48, 44), 26, P.PAPER_HI, P.INK, back_cb, P.LINE, 1, 22)
		x0 = 76.0
	deco(root, "banner", Rect2(x0 - 16, 92, 236, 58), 1.0)
	label(root, title, Vector2(x0, 98), Vector2(520, 48), 30, P.INK)
	if right_txt != "":
		button(root, right_txt, Rect2(566, 100, 138, 44), 20, P.PAPER_HI, P.SEAL, right_cb, P.GOLD, 1, 22)

# ---------------- 底栏 ----------------
static func dock(root: Control, active: String, on_pick: Callable) -> void:
	var ch := DockChrome.new()
	ch.size = Vector2(W, DOCK_H)
	ch.position = Vector2(0, DOCK_Y)
	ch.active = active
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ch)
	# 四格图标栏：开始 / 角色 / 请神 / 奇物（最后一格用奇物图标）
	var items := [["start", 86.0], ["role", 252.0], ["god", 418.0], ["curio", 584.0]]
	for it in items:
		var key := str(it[0])
		var cx := float(it[1])
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(cx - 60.0, 10)
		b.size = Vector2(120, 84)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		b.pressed.connect(func() -> void:
			if on_pick.is_valid():
				on_pick.call(key))
		ch.add_child(b)

class BarChrome extends Control:
	const P := preload("res://shared/ui_pal.gd")
	const GS := preload("res://shared/game_state.gd")
	var _coin_label: Label
	var _crystal_label: Label
	var _last_coin := -1
	var _last_crystal := -1
	func bind_currencies(coin_label: Label, crystal_label: Label) -> void:
		_coin_label = coin_label
		_crystal_label = crystal_label
		_refresh_currencies()
	func _process(_dt: float) -> void:
		_refresh_currencies()
	func _refresh_currencies() -> void:
		var wen := GS.coin("wen")
		var crystal := GS.coin("yuanbao")
		if is_instance_valid(_coin_label) and wen != _last_coin:
			_last_coin = wen
			_coin_label.text = str(wen)
		if is_instance_valid(_crystal_label) and crystal != _last_crystal:
			_last_crystal = crystal
			_crystal_label.text = str(crystal)
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 720, 90), P.DARK)
		draw_line(Vector2(0, 90), Vector2(720, 90), Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.5), 1.5, true)
		draw_circle(Vector2(52, 45), 26.0, P.DARK2)
		draw_arc(Vector2(52, 45), 26.0, 0, TAU, 48, P.GOLD_HI, 2.0, true)
		for cx in [264.0, 414.0]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = P.DARK2
			sb.set_corner_radius_all(8)
			sb.border_color = Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.35)
			sb.set_border_width_all(1)
			draw_style_box(sb, Rect2(cx, 20, 140, 50))
		# 文钱（圆）+ 灵晶（菱形）
		draw_circle(Vector2(288, 45), 13.0, Color(0.878, 0.690, 0.290))
		draw_circle(Vector2(288, 45), 4.5, P.DARK)
		draw_colored_polygon(PackedVector2Array([
			Vector2(438, 32), Vector2(451, 45), Vector2(438, 58), Vector2(425, 45)
		]), Color(0.490, 0.760, 0.850))
		draw_colored_polygon(PackedVector2Array([
			Vector2(438, 37), Vector2(446, 45), Vector2(438, 53), Vector2(430, 45)
		]), P.DARK)

class DockChrome extends Control:
	const P := preload("res://shared/ui_pal.gd")
	var active := ""
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 720, 104), P.DARK)
		draw_line(Vector2(0, 0), Vector2(720, 0), Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.35), 1.5, true)
		var items := [["start", 86.0], ["role", 252.0], ["god", 418.0], ["curio", 584.0]]
		for it in items:
			var key := str(it[0])
			var cx := float(it[1])
			var on := key == active
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.157, 0.137, 0.110) if on else P.DARK2
			sb.set_corner_radius_all(10)
			sb.border_color = P.GOLD_HI if on else Color(0.471, 0.408, 0.322)
			sb.set_border_width_all(2 if on else 1)
			draw_style_box(sb, Rect2(cx - 52.0, 20, 104, 64))
			_draw_icon(cx, 52.0, key, on)
	func _draw_icon(cx: float, cy: float, key: String, on: bool) -> void:
		var col := P.GOLD_HI if on else Color(0.78, 0.70, 0.55)
		match key:
			"start":
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx - 9, cy - 14), Vector2(cx + 14, cy), Vector2(cx - 9, cy + 14)
				]), col)
			"role":
				draw_line(Vector2(cx - 13, cy + 12), Vector2(cx + 13, cy - 12), col, 3.0, true)
				draw_line(Vector2(cx - 13, cy - 12), Vector2(cx + 13, cy + 12), col, 3.0, true)
				draw_line(Vector2(cx - 15, cy + 8), Vector2(cx - 8, cy + 15), col, 3.0, true)
				draw_line(Vector2(cx + 8, cy + 15), Vector2(cx + 15, cy + 8), col, 3.0, true)
			"god":
				draw_circle(Vector2(cx - 7, cy - 6), 5.5, col)
				draw_circle(Vector2(cx + 7, cy - 6), 5.5, col)
				draw_arc(Vector2(cx, cy + 8), 12.0, PI, TAU, 16, col, 2.4, true)
			"curio":
				# 奇物：小匣子 + 提环
				draw_rect(Rect2(cx - 12, cy - 2, 24, 14), col, false, 2.2)
				draw_line(Vector2(cx - 12, cy + 3), Vector2(cx + 12, cy + 3), col, 1.8, true)
				draw_arc(Vector2(cx, cy - 5), 6.0, PI, TAU, 12, col, 2.0, true)

# ---------------- 大号切关箭头（照原图的鎏金双人字纹） ----------------
static func chevron(dir: int, rect: Rect2, cb: Callable) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var ch := Chevron.new()
	ch.dir = dir
	ch.size = rect.size
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ch)
	if cb.is_valid():
		b.pressed.connect(cb)
	Motion.bind_button(b)
	return b

class Chevron extends Control:
	var dir := -1
	var _t := 0.0
	func _ready() -> void:
		set_process(true)
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cy := h * 0.5
		var tip_x := w * 0.17 if dir < 0 else w * 0.83
		var back_x := w * 0.88 if dir < 0 else w * 0.12
		var pulse := 0.5 + 0.5 * sin(_t * 2.1)
		for kk in [1.0, 0.58]:
			var k: float = kk
			var hh: float = h * 0.36 * k
			var pts := PackedVector2Array([
				Vector2(back_x, cy - hh),
				Vector2(tip_x, cy),
				Vector2(back_x, cy + hh),
			])
			for i in 3:
				var a: float = (0.13 + 0.12 * float(i)) * (0.60 + 0.75 * pulse)
				draw_polyline(pts, Color(1.0, 0.84, 0.46, a), 30.0 - 6.5 * float(i), true)
			draw_polyline(pts, Color(0.66, 0.49, 0.24), 13.0 * k, true)
			draw_polyline(pts, Color(1.0, 0.95, 0.80), 5.0 * k, true)
		var u := fmod(_t * 0.55, 1.0)
		var p0 := Vector2(back_x, cy - h * 0.36)
		var p1 := Vector2(tip_x, cy)
		var p2 := Vector2(back_x, cy + h * 0.36)
		var pos: Vector2 = p0.lerp(p1, u / 0.5) if u < 0.5 else p1.lerp(p2, (u - 0.5) / 0.5)
		for i in 3:
			draw_circle(pos, 11.0 - 3.0 * float(i), Color(1.0, 0.95, 0.80, 0.16 + 0.09 * float(i)))
		draw_circle(pos, 3.2, Color(1.0, 0.99, 0.94))
		var dc := Vector2(tip_x + (11.0 if dir < 0 else -11.0), cy)
		draw_colored_polygon(PackedVector2Array([
			dc + Vector2(0, -7), dc + Vector2(7, 0), dc + Vector2(0, 7), dc + Vector2(-7, 0)
		]), Color(1.0, 0.88, 0.56, 0.75 + 0.25 * pulse))
# ---------------- 设置弹窗（三页共用） ----------------
static func open_settings(root: Control) -> void:
	if not navigation_available(root): return
	var old := root.get_node_or_null("SettingsOv")
	if old != null:
		return
	var AudioRef := load("res://shared/audio.gd")
	var ov := Control.new()
	ov.name = "SettingsOv"
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.z_index = 70
	root.add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.02, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var p := Panel.new()
	p.position = Vector2(90, 400)
	p.size = Vector2(540, 360)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.957, 0.922, 0.851)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.851, 0.659, 0.231, 0.8)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	ov.add_child(p)
	label(p, "设 置", Vector2(30, 22), Vector2(480, 40), 28, P.INK)
	label(p, "背景音乐", Vector2(40, 100), Vector2(180, 36), 20, P.INK, HORIZONTAL_ALIGNMENT_LEFT, p)
	label(p, "音  效", Vector2(40, 170), Vector2(180, 36), 20, P.INK, HORIZONTAL_ALIGNMENT_LEFT, p)
	var bv := label(p, str(int(AudioRef.bgm_volume() * 100)) + "%", Vector2(250, 100), Vector2(90, 36), 20, P.INK, HORIZONTAL_ALIGNMENT_CENTER, p)
	var sv := label(p, str(int(AudioRef.sfx_volume() * 100)) + "%", Vector2(250, 170), Vector2(90, 36), 20, P.INK, HORIZONTAL_ALIGNMENT_CENTER, p)
	button(p, "－", Rect2(356, 96, 56, 44), 22, P.PAPER_HI, P.INK, func() -> void:
		if not _settings_current(root, ov): return
		AudioRef.set_bgm_volume(clampf(AudioRef.bgm_volume() - 0.1, 0.0, 1.0))
		bv.text = str(int(AudioRef.bgm_volume() * 100)) + "%", P.LINE, 1, 18, p)
	button(p, "＋", Rect2(422, 96, 56, 44), 22, P.PAPER_HI, P.INK, func() -> void:
		if not _settings_current(root, ov): return
		AudioRef.set_bgm_volume(clampf(AudioRef.bgm_volume() + 0.1, 0.0, 1.0))
		bv.text = str(int(AudioRef.bgm_volume() * 100)) + "%", P.LINE, 1, 18, p)
	button(p, "－", Rect2(356, 166, 56, 44), 22, P.PAPER_HI, P.INK, func() -> void:
		if not _settings_current(root, ov): return
		AudioRef.set_sfx_volume(clampf(AudioRef.sfx_volume() - 0.1, 0.0, 1.0))
		sv.text = str(int(AudioRef.sfx_volume() * 100)) + "%", P.LINE, 1, 18, p)
	button(p, "＋", Rect2(422, 166, 56, 44), 22, P.PAPER_HI, P.INK, func() -> void:
		if not _settings_current(root, ov): return
		AudioRef.set_sfx_volume(clampf(AudioRef.sfx_volume() + 0.1, 0.0, 1.0))
		sv.text = str(int(AudioRef.sfx_volume() * 100)) + "%", P.LINE, 1, 18, p)
	button(p, "关 闭", Rect2(180, 282, 180, 52), 20, P.PAPER_HI, P.INK,
		func() -> void:
			if not _settings_current(root, ov): return
			ov.hide()
			ov.queue_free(), P.LINE, 1, 20, p)
	Motion.present(ov, p)

static func _settings_current(page: Control, overlay: Control) -> bool:
	return navigation_available(page) and is_instance_valid(overlay) and not overlay.is_queued_for_deletion() and page.get_node_or_null("SettingsOv") == overlay
