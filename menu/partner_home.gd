extends Control
# ============================================================
# menu/partner_home.gd —— 局外「请神」页（v2 改版）
#
# 版式沿用原页面：底图（顶栏/底栏在图里）+ 禁用技能 + 方案 + 总伤害加成 + 七格
# 改动的只有三处：
#   ① 大立绘 → 祖宗「立绘卡轮播」（中间聚焦、两侧淡出、点两侧切换）
#   ② 七格内容 → 该祖宗的技能（名字 + Lv + 星级）
#   ③ 点立绘 → 「进阶路线」弹窗（六档：星级 / 档位 / 张数 / 组合 / 状态）
# ============================================================
const AD := preload("res://kushou/ancestor_data.gd")
const W := 720.0
const H := 1280.0
const INK := Color(0.14, 0.13, 0.15)
const SEAL := Color(0.55, 0.20, 0.12)
const GOLD := Color(0.78, 0.58, 0.22)
const DIM := Color(0.42, 0.38, 0.32)
const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]

# 立绘（真正的图后面做，先用现有三张脸/立绘顶着）
const PORTRAIT := {
	"zl": "res://assets/char/chen_shi_full_cut.png",
	"cuisanniang": "res://assets/char/qingluan_full_cut.png",
	"jicanghai": "res://assets/char/player_full_cut.png",
	"zhujue": "res://assets/char/player_full_cut.png",
}

var _ids: Array = []
var _sel := 0
var _stars := {}          # 占位：祖宗星级（正式版要从存档读）
var _cards: Array = []
var _pop: Control = null
var _plan := 0
var _plan_btns: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for aid_v in AD.ANCESTORS.keys():
		_ids.append(str(aid_v))
	# 占位星级：张道陵 3★、崔三娘 2★、季沧海 1★、主角 2★
	var demo := [3, 2, 1, 2]
	for i in _ids.size():
		_stars[_ids[i]] = mini(5, demo[i] if i < demo.size() else 0)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/ui/partner_bg.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_carousel()
	_build_rest()
	_build_hot()

# ---------------- 立绘卡轮播 ----------------
func _build_carousel() -> void:
	for i in 3:
		var c := GodArt.new()
		c.size = Vector2(280, 372) if i == 1 else Vector2(200, 266)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.pressed.connect(func() -> void: _on_card_click(i))
		add_child(c)
		_cards.append(c)
	_refresh_carousel()

func _refresh_carousel() -> void:
	var n := _ids.size()
	if n == 0:
		return
	var order := [(_sel - 1 + n) % n, _sel, (_sel + 1) % n]
	var geo := [Vector2(-40, 176), Vector2(220, 116), Vector2(560, 176)]
	for i in 3:
		var c: GodArt = _cards[i]
		var aid := str(_ids[order[i]])
		c.aid = aid
		c.god_name = str((AD.ANCESTORS[aid] as Dictionary)["name"])
		c.skill_name = str((AD.ANCESTORS[aid] as Dictionary)["skill"])
		c.quality = int((AD.ANCESTORS[aid] as Dictionary)["quality"])
		c.dtype = str((AD.ANCESTORS[aid] as Dictionary).get("dtype", ""))
		c.stars = int(_stars.get(aid, 0))
		c.art = load(str(PORTRAIT.get(aid, "res://assets/char/player_full_cut.png")))
		c.focus = i == 1
		c.position = geo[i]
		c.size = Vector2(280, 372) if i == 1 else Vector2(200, 266)
		c.modulate = Color(1, 1, 1, 1.0 if i == 1 else 0.32)
		c.queue_redraw()

func _on_card_click(i: int) -> void:
	if i == 1:
		_show_advance()
		return
	var n := _ids.size()
	_sel = (_sel + (1 if i == 2 else -1) + n) % n
	_refresh_carousel()

# ---------------- 其余（保持原版式） ----------------
func _build_rest() -> void:
	_lbl("禁用技能(0/3)", 18, Color(0.62,0.55,0.38), Vector2(240, 516))
	_lbl("ⓘ", 18, Color(0.62,0.55,0.38), Vector2(408, 514))
	_lbl("方案", 16, Color(0.46,0.42,0.36), Vector2(40, 566))
	for i in 3:
		var b := Button.new()
		b.text = str(i + 1)
		b.position = Vector2(100.0 + float(i) * 46.0, 558)
		b.size = Vector2(40, 34)
		b.add_theme_font_size_override("font_size", 17)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_plan.bind(i))
		add_child(b)
		_plan_btns.append(b)
	_style_plan()
	_lbl("总伤害加成 0%", 24, Color(0.55,0.38,0.12), Vector2(40, 620))
	_lbl("ⓘ", 20, Color(0.55,0.48,0.34), Vector2(300, 620))
	var edit := Button.new()
	edit.text = "禁用编辑"
	edit.position = Vector2(430, 610)
	edit.size = Vector2(250, 54)
	edit.add_theme_font_size_override("font_size", 22)
	edit.focus_mode = Control.FOCUS_NONE
	var esb := StyleBoxFlat.new()
	esb.bg_color = Color(0.94,0.89,0.79,0.98)
	esb.set_corner_radius_all(4)
	esb.border_color = Color(0.65,0.46,0.20,0.9)
	esb.set_border_width_all(2)
	edit.add_theme_stylebox_override("normal", esb)
	edit.add_theme_stylebox_override("hover", esb)
	edit.add_theme_stylebox_override("pressed", esb)
	edit.add_theme_color_override("font_color", Color(0.36,0.20,0.09))
	edit.pressed.connect(func() -> void: print("[请神页] 禁用编辑"))
	add_child(edit)
	_build_slots()

# 七格：该祖宗的技能
func _build_slots() -> void:
	var n := _ids.size()
	for i in 7:
		var row := 0 if i < 4 else 1
		var col := i % 4
		var p := Vector2(36.0 + float(col) * 166.0, 690.0 + float(row) * 168.0)
		if i >= n:
			var cell := Panel.new()
			cell.position = p
			cell.size = Vector2(150, 150)
			var csb := StyleBoxFlat.new()
			csb.bg_color = Color(0.99,0.97,0.93,0.75)
			csb.set_corner_radius_all(8)
			csb.border_color = Color(0.80,0.76,0.68)
			csb.set_border_width_all(2)
			cell.add_theme_stylebox_override("panel", csb)
			add_child(cell)
			continue
		var aid := str(_ids[i])
		var a: Dictionary = AD.ANCESTORS[aid]
		var cell2 := Panel.new()
		cell2.position = p
		cell2.size = Vector2(150, 150)
		var csb2 := StyleBoxFlat.new()
		csb2.bg_color = Color(0.99,0.97,0.93,0.98)
		csb2.set_corner_radius_all(8)
		csb2.border_color = QC[clampi(int(a["quality"]) - 1, 0, 4)]
		csb2.set_border_width_all(3)
		cell2.add_theme_stylebox_override("panel", csb2)
		cell2.mouse_filter = Control.MOUSE_FILTER_STOP
		cell2.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_sel = i
				_refresh_carousel())
		add_child(cell2)
		var tr := TextureRect.new()
		tr.position = Vector2(22, 16)
		tr.size = Vector2(106, 96)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = load(str(a["art"]))
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell2.add_child(tr)
		var nm := Label.new()
		nm.text = str(a["skill"])
		nm.position = Vector2(0, 116)
		nm.size = Vector2(150, 22)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 15)
		nm.add_theme_color_override("font_color", Color(0.30,0.26,0.20))
		cell2.add_child(nm)
		var lv := Label.new()
		lv.text = "Lv 1"
		lv.position = Vector2(96, 134)
		lv.size = Vector2(48, 18)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lv.add_theme_font_size_override("font_size", 13)
		lv.add_theme_color_override("font_color", GOLD)
		cell2.add_child(lv)

func _lbl(t: String, fs: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.size = Vector2(420, fs + 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _style_plan() -> void:
	for i in _plan_btns.size():
		var b: Button = _plan_btns[i]
		var on := i == _plan
		var sb := StyleBoxFlat.new()
		sb.bg_color = SEAL if on else Color(0.91,0.88,0.82)
		sb.set_corner_radius_all(4)
		sb.border_color = GOLD if on else Color(0.78,0.73,0.64)
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(0.96,0.92,0.80) if on else Color(0.30,0.27,0.22))

func _on_plan(i: int) -> void:
	_plan = i
	_style_plan()

# ---------------- 进阶路线弹窗 ----------------
func _show_advance() -> void:
	if _pop != null and is_instance_valid(_pop):
		_pop.queue_free()
		_pop = null
	var aid := str(_ids[_sel])
	var a: Dictionary = AD.ANCESTORS[aid]
	var star := int(_stars.get(aid, 0))
	_pop = Control.new()
	_pop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pop.mouse_filter = Control.MOUSE_FILTER_STOP
	_pop.z_index = 80
	add_child(_pop)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.03, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_pop())
	_pop.add_child(dim)
	var b := Rect2(Vector2(40, 150), Vector2(640, 930))
	var box := Panel.new()
	box.position = b.position
	box.size = b.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.975, 0.955, 0.915, 1.0)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.72, 0.53, 0.16)
	sb.set_border_width_all(3)
	box.add_theme_stylebox_override("panel", sb)
	_pop.add_child(box)
	# 头像
	var ph := Panel.new()
	ph.position = Vector2(26, 24)
	ph.size = Vector2(190, 246)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.90, 0.86, 0.77)
	psb.set_corner_radius_all(6)
	psb.border_color = QC[clampi(int(a["quality"]) - 1, 0, 4)]
	psb.set_border_width_all(3)
	ph.add_theme_stylebox_override("panel", psb)
	box.add_child(ph)
	var pt := TextureRect.new()
	pt.position = Vector2(6, 6)
	pt.size = Vector2(178, 234)
	pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pt.texture = load(str(PORTRAIT.get(aid, "")))
	ph.add_child(pt)
	_push_label(box, str(a["name"]), 32, INK, Vector2(238, 40))
	_push_label(box, "%s · %s" % [grade_cn(int(a["quality"])), str(a.get("dtype", ""))], 15, DIM, Vector2(238, 82))
	_push_label(box, "%d ★" % star, 20, Color(0.55, 0.40, 0.16), Vector2(238, 112))
	_push_label(box, "来 历", 14, Color(0.55, 0.40, 0.16), Vector2(238, 150))
	_push_label(box, "请神上身，代代相传。", 15, Color(0.28, 0.24, 0.19), Vector2(238, 176), 360)
	# 路线
	_push_label(box, "进 阶 路 线", 20, Color(0.55, 0.30, 0.12), Vector2(26, 292))
	_push_label(box, "每档独立：集齐 3 张 → 组合 → 清空", 14, DIM, Vector2(174, 292), 440)
	var tiers: Array = a["tiers"]
	var y := 312.0
	for t in tiers.size():
		var tier: Dictionary = tiers[t]
		var done := t < star
		var cur := t == star
		var rp := Panel.new()
		rp.position = Vector2(26, y)
		rp.size = Vector2(588, 78)
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0.99, 0.965, 0.88) if cur else (Color(0.90, 0.86, 0.77) if done else Color(0.95, 0.92, 0.865))
		rsb.set_corner_radius_all(6)
		if cur:
			rsb.border_color = Color(0.82, 0.50, 0.12, 0.85)
			rsb.set_border_width_all(2)
		rp.add_theme_stylebox_override("panel", rsb)
		box.add_child(rp)
		var lc := Color(0.55, 0.40, 0.16) if (done or cur) else Color(0.62, 0.57, 0.48)
		_push_label(rp, "%d★" % t, 21, lc, Vector2(14, 24))
		_push_label(rp, "%s · 3 张" % str(AD.TIER_NAMES[t]), 18, INK if (done or cur) else Color(0.45, 0.41, 0.35), Vector2(72, 6))
		_push_label(rp, str(tier["combo_text"]), 14, Color(0.45, 0.41, 0.35), Vector2(72, 36), 380)
		var st := "已完成" if done else ("进行中" if cur else "未解锁")
		var sc := Color(0.20, 0.50, 0.28) if done else (Color(0.66, 0.18, 0.12) if cur else Color(0.58, 0.53, 0.45))
		var sl := Label.new()
		sl.text = st
		sl.position = Vector2(430, 28)
		sl.size = Vector2(140, 26)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sl.add_theme_font_size_override("font_size", 16)
		sl.add_theme_color_override("font_color", sc)
		rp.add_child(sl)
		y += 86.0
	_push_label(box, "0★ 时可抽全套 18 张，每张 4% 掷「炫卡」", 14, Color(0.66, 0.18, 0.12), Vector2(26, y + 6), 580)
	var close := Button.new()
	close.text = "关 闭"
	close.position = Vector2(214, 856)
	close.size = Vector2(200, 54)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_close_pop)
	box.add_child(close)

func _close_pop() -> void:
	if _pop != null and is_instance_valid(_pop):
		_pop.queue_free()
		_pop = null

func _push_label(parent: Control, t: String, fs: int, col: Color, pos: Vector2, w := 260.0) -> void:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = Vector2(w, fs + 12)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)

func grade_cn(q: int) -> String:
	return ["凡品", "良品", "玄品", "地品", "绝品"][clampi(q - 1, 0, 4)]

# ---------------- 热区（顶栏 / 底栏） ----------------
func _build_hot() -> void:
	_hot(Rect2(10, 6, 240, 76), func() -> void: get_tree().change_scene_to_file("res://menu/main_home.tscn"))
	_hot(Rect2(630, 20, 82, 50), func() -> void: print("[请神页] 设置"))
	_hot(Rect2(16, 1180, 172, 90), func() -> void: get_tree().change_scene_to_file("res://menu/main_home.tscn"))
	_hot(Rect2(188, 1180, 172, 90), func() -> void: get_tree().change_scene_to_file("res://menu/character_home.tscn"))
	_hot(Rect2(360, 1180, 172, 90), func() -> void: pass)
	_hot(Rect2(532, 1180, 180, 90), func() -> void: print("[请神页] 设置"))

func _hot(rect: Rect2, cb: Callable) -> void:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	add_child(b)

# ============================================================
# 立绘卡
# ============================================================
class GodArt extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal pressed
	var aid := ""
	var god_name := ""
	var skill_name := ""
	var dtype := ""
	var quality := 5
	var stars := 0
	var focus := false
	var art: Texture2D = null
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var qc: Color = QC[clampi(quality - 1, 0, 4)]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.972, 0.958, 0.930, 1.0)
		sb.set_corner_radius_all(12 if focus else 9)
		sb.border_color = qc
		sb.set_border_width_all(4 if focus else 2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if art != null:
			var pad := 10.0 if focus else 8.0
			var ar := Rect2(Vector2(pad, pad), size - Vector2(pad * 2.0, pad * 2.0 - 26.0))
			var ts := art.get_size()
			var sc: float = minf(ar.size.x / ts.x, ar.size.y / ts.y)
			draw_texture_rect(art, Rect2(ar.position + Vector2((ar.size.x - ts.x * sc) * 0.5, 0), Vector2(ts.x * sc, ts.y * sc)), false)
		# 竖排名牌
		var pw := 28.0 if focus else 22.0
		var phh := 26.0 * float(maxi(1, god_name.length())) + 10.0
		var pp := Rect2(Vector2(14, 14), Vector2(pw, phh))
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color(0.98, 0.96, 0.92, 0.92)
		psb.set_corner_radius_all(4)
		psb.border_color = Color(0.70, 0.60, 0.42, 0.8)
		psb.set_border_width_all(1)
		draw_style_box(psb, pp)
		for i in god_name.length():
			draw_string(F, pp.position + Vector2(4, 24.0 + float(i) * 26.0), god_name.substr(i, 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18 if focus else 15, Color(0.14, 0.13, 0.15))
		# 品质章
		var qs := 34.0 if focus else 26.0
		var qp := Rect2(Vector2(size.x - qs - 12, size.y - qs - 40), Vector2(qs, qs))
		var qsb := StyleBoxFlat.new()
		qsb.bg_color = qc
		qsb.set_corner_radius_all(4)
		draw_style_box(qsb, qp)
		draw_string(F, qp.position + Vector2(0, qs * 0.72), ["凡","良","玄","地","天"][clampi(quality - 1, 0, 4)],
			HORIZONTAL_ALIGNMENT_CENTER, qs, 17 if focus else 13, Color(0.99, 0.96, 0.88))
		# 星级（画在图上）
		if focus:
			var cy := size.y - 22.0
			for i in 5:
				_star(Vector2(size.x * 0.5 - 40.0 + float(i) * 20.0, cy), 7.0, i < stars)
	func _star(c: Vector2, r: float, filled: bool) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var ang := -PI * 0.5 + float(i) * PI / 5.0
			var rr := r if i % 2 == 0 else r * 0.42
			pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
		if filled:
			draw_colored_polygon(pts, GOLD)
		else:
			pts.append(pts[0])
			draw_polyline(pts, Color(0.55, 0.48, 0.38, 0.6), 1.2, true)
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
