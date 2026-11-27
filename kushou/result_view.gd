extends Control
# ============================================================
# kushou/result_view.gd —— 结算视图（从 battle_ui.gd 拆出）
#
#   · 自带：结局 CG、遮罩、纸框、标题、六行数据、两个按钮、入场动画
#   · 不碰存档 / 首通 / 场景切换：按钮只发信号，去留由战斗层决定
#   · 布局与文案沿用拆分前的数值（540×480 框、行距 37、按钮 380 等）
# ============================================================
signal replay_pressed
signal home_pressed

const UI := preload("res://shared/ui_kit.gd")
const Aud := preload("res://shared/audio.gd")

const INK := Color(0.13, 0.12, 0.11)
const DIM := Color(0.42, 0.38, 0.32)

# 战斗层可选注入：present 完成后回放结局面特效（特效系统仍属于战斗舞台）
var on_presented: Callable = Callable()

class CoverRect extends Control:
	# 按比例裁切填满（全屏 CG 用）
	var tex: Texture2D = null
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if tex == null:
			return
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		if tw <= 0.0 or th <= 0.0:
			return
		var s := maxf(size.x / tw, size.y / th)
		var w := tw * s
		var h := th * s
		draw_texture_rect(tex, Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h), false)

func present(p: Dictionary) -> void:
	if get_child_count() > 0:
		return
	var win := bool(p.get("win", false))
	Aud.sfx("win" if win else "lose", -6.0)
	# 结局 CG 当全屏背景（有图才加，缺图保持原来的纯色压暗）
	var cg_path := "res://assets/art/cg/ending_win.png" if win else "res://assets/art/cg/ending_lose.png"
	var has_cg := ResourceLoader.exists(cg_path)
	if has_cg:
		var cg := CoverRect.new()
		cg.tex = load(cg_path) as Texture2D
		cg.position = Vector2.ZERO
		cg.size = size
		add_child(cg)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.42 if has_cg else 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var holder := Control.new()
	holder.position = Vector2(90, 320)
	holder.size = Vector2(540, 480)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	# 结算面板底图（有图就用图，没有回退原来的纯色面板）
	var panel_art := "res://assets/ui/panel_win.png" if win else "res://assets/ui/panel_lose.png"
	var has_art := ResourceLoader.exists(panel_art)
	if has_art:
		var tr := TextureRect.new()
		# 先设拉伸模式再挂贴图：反过来会让最小尺寸变成贴图原始尺寸（1024×768），
		# 面板底图会撑出 540×480 的 holder，整块框错位、文字压到花纹上。
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture = load(panel_art) as Texture2D
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.custom_minimum_size = Vector2.ZERO
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)
	else:
		_panel(Rect2(0, 0, 540, 480), Color(0.97, 0.93, 0.85, 0.99), 12,
			Color(0.85, 0.66, 0.23) if win else Color(0.64, 0.22, 0.15), 3, holder)
	if has_art:
		# 内容区压一层纸色，压住框内花边，保证文字清楚
		var content_bg := ColorRect.new()
		content_bg.position = Vector2(48, 112)
		content_bg.size = Vector2(444, 232)
		content_bg.color = Color(0.972, 0.948, 0.896, 0.90)
		content_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(content_bg)
		var title_bg := ColorRect.new()
		title_bg.position = Vector2(48, 56)
		title_bg.size = Vector2(444, 60)
		title_bg.color = Color(0.972, 0.948, 0.896, 0.88)
		title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(title_bg)
	if has_art:
		UI.deco(holder, "divider", Rect2(140, 112, 260, 8), 0.9)
	_lbl("通　关" if win else "命　尽", Vector2(0, 66), Vector2(540, 58), 42,
		Color(0.62, 0.44, 0.12) if win else Color(0.62, 0.20, 0.14), holder, HORIZONTAL_ALIGNMENT_CENTER)
	var secs_total := int(float(p.get("run_time", 0.0)))
	var mins := secs_total / 60
	var secs := secs_total % 60
	var total_bonds := int(p.get("bonds", 0)) + int(p.get("bonds_done", 0))
	var rows := [
		["到达波数", "%d / %d" % [mini(int(p.get("wave", 0)), int(p.get("max_wave", 5))), int(p.get("max_wave", 5))]],
		["击杀", str(int(p.get("kills", 0)))],
		["文钱", str(int(p.get("wen", 0)))],
		["灵晶", str(int(p.get("crystal", 0)))],
		["羁绊", "%d 条（已成 %d）" % [total_bonds, int(p.get("bonds_done", 0))]],
		["存活", "%d 分 %02d 秒" % [mins, secs]],
	]
	# 六行必须落在底图内容区 y 112–344 内：起点 120、步进 37，
	# 末行底边 335；原来的 126/40 会顶到 356，把"羁绊/存活"压到边框花纹上。
	var y := 120.0
	for r in rows:
		_lbl(str(r[0]), Vector2(56, y), Vector2(150, 30), 20, DIM, holder)
		_lbl(str(r[1]), Vector2(210, y), Vector2(276, 30), 22, INK, holder, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 37.0
	_btn("再来一局", Rect2(30, 380, 210, 64), 24, Color(0.86, 0.66, 0.24), Color(0.14, 0.11, 0.08),
		func() -> void: replay_pressed.emit(), holder)
	_btn("回主界面", Rect2(300, 380, 210, 64), 24, Color(0.93, 0.89, 0.80), INK,
		func() -> void: home_pressed.emit(), holder)
	UI.Motion.pop(holder, false, 0.0)
	UI.Motion.breathe(holder)
	if on_presented.is_valid():
		on_presented.call("holy/sunburst" if win else "shadow/dark-explosion", Vector2(360, 235))

func _panel(rect: Rect2, bg: Color, radius := 8, border := Color(0, 0, 0, 0), bw := 0, parent: Node = null) -> Panel:
	var pnl := Panel.new()
	pnl.position = rect.position
	pnl.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	pnl.add_theme_stylebox_override("panel", sb)
	pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(pnl)
	return pnl

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

func _btn(t: String, rect: Rect2, fs: int, bg: Color, fg: Color, cb: Callable, parent: Node = null,
		border := Color(0.85, 0.66, 0.23, 0.55), bw := 1) -> Button:
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
	UI.Motion.bind_button(b)
	return b
