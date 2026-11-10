extends Control
# ============================================================
# kushou/attr_panel.gd —— 详细属性页 + 属性弹窗（设计稿 v6）
#
#   结构：基础 5 行（只写结果）＋ 伤害类型 7 页签（穿透/减免/增幅 两段）
#   交互：点任意一行 → 弹窗（拆解 → 算式 → 总结）
#
#   数据来源：core.attr_final(key) / core.type_field(系, field)
#   本文件**只管画与点**，不参与结算。
# ============================================================

const F := preload("res://fonts/ink.ttf")

const INK := Color(0.13, 0.12, 0.11)
const DIM := Color(0.42, 0.38, 0.32)
const GOLD := Color(0.68, 0.51, 0.17)
const SEAL := Color(0.55, 0.20, 0.12)
const FAINT := Color(0.72, 0.68, 0.60)
const PAPER := Color(0.95, 0.92, 0.85)
const GRN := Color(0.24, 0.46, 0.27)

const TYPES := ["物理", "金系", "木系", "水系", "火系", "土系", "真实"]
const TAB_LABEL := ["物理", "金", "木", "水", "火", "土", "真实"]

const BASE_ROWS := [
	{"key": "atk", "icon": "sword", "name": "攻击"},
	{"key": "hp", "icon": "heart", "name": "气血"},
	{"key": "aspd", "icon": "aspd", "name": "攻速"},
	{"key": "crit", "icon": "star", "name": "暴击"},
	{"key": "cdmg", "icon": "burst", "name": "爆伤"},
]
const TYPE_ROWS := [
	{"field": "pen", "icon": "arrow", "name": "穿透"},
	{"field": "red", "icon": "shield", "name": "减免"},
	{"field": "amp", "icon": "up", "name": "增幅"},
]

var core = null
var tab := 0
var popup := -1          # 弹窗对应的行（-1＝没开）
var _rows: Array = []    # 命中测试：{rect, kind, idx}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func setup(c) -> void:
	core = c

func open() -> void:
	if core != null and core.has_method("_attr_sync_from_hero"):
		core._attr_sync_from_hero()
	visible = true
	queue_redraw()

func close() -> void:
	popup = -1
	visible = false

# ---------------- 取值 ----------------
func _h(key: String, dflt: float) -> float:
	if core == null:
		return dflt
	return float(core.hero.get(key, dflt))

func _fmt_num(v: float) -> String:
	return str(int(round(v)))

func _base_text(i: int) -> String:
	match i:
		0: return _fmt_num(_h("atk", 12.0))
		1: return _fmt_num(_h("hp_max", 200.0))
		2: return "%.2f 次/秒" % (_h("aspd", 1.0) / 1.8)
		3: return _fmt_num(_h("crit", 0.05) * 100.0) + "%"
		4: return _fmt_num(_h("crit_dmg", 2.0) * 100.0) + "%"
	return "—"

func _type_f(field: String) -> float:
	if core == null:
		return 0.0
	var t: String = str(TYPES[clampi(tab, 0, TYPES.size() - 1)])
	if field == "pen":
		return float(core.type_field(t, "pen_f"))
	if field == "pen_p":
		return float(core.type_field(t, "pen_p"))
	if field == "red":
		return float(core.type_field(t, "red_f"))
	if field == "red_p":
		return float(core.type_field(t, "red_p"))
	if field == "amp":
		return float(core.type_field(t, "amp_f"))
	return float(core.type_field(t, "amp_p"))

# ---------------- 画 ----------------
func _draw() -> void:
	var f_t := _font(42)
	var f_n := _font(30)
	var f_v := _font(46)
	var f_lab := _font(18)
	var f_tab := _font(22)
	var f_small := _font(16)
	var f_gold := _font(40)

	draw_rect(Rect2(0, 0, 720, 1280), Color(0.10, 0.09, 0.08, 0.55))
	_panel(Rect2(28, 56, 664, 1168), PAPER, Color(0.78, 0.70, 0.55), 14)
	draw_string(f_t, Vector2(64, 118), "详细属性", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, INK)
	draw_string(f_t, Vector2(636, 120), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, DIM)
	draw_line(Vector2(64, 158), Vector2(656, 158), Color(0.80, 0.76, 0.66), 2.0)
	draw_string(f_lab, Vector2(64, 196), "基 础", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GOLD)

	_rows.clear()
	for i in BASE_ROWS.size():
		var y := 208.0 + float(i) * 100.0
		_icon(Vector2(88, y + 34), str(BASE_ROWS[i]["icon"]), INK)
		draw_string(f_n, Vector2(122, y + 44), str(BASE_ROWS[i]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, DIM)
		_right(f_v, 470, y + 48, _base_text(i), INK, 46)
		_rows.append({"rect": Rect2(64, y, 592, 92), "kind": "base", "idx": i})

	draw_line(Vector2(64, 714), Vector2(656, 714), Color(0.80, 0.76, 0.66), 2.0)
	draw_string(f_lab, Vector2(64, 752), "伤害类型", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GOLD)

	for i in TYPES.size():
		var x := 64.0 + float(i) * 85.0
		var on := i == tab
		var r := Rect2(x, 766, 82, 50)
		draw_rect(r, SEAL if on else Color(0.98, 0.96, 0.92), true)
		if not on:
			draw_rect(r, FAINT, false, 1.0)
		var col := Color(0.98, 0.95, 0.88) if on else INK
		draw_string(f_tab, Vector2(x, 800), str(TAB_LABEL[i]), HORIZONTAL_ALIGNMENT_CENTER, 82, 22, col)
		_rows.append({"rect": r, "kind": "tab", "idx": i})

	var real := tab == 6
	for i in TYPE_ROWS.size():
		var y2 := 846.0 + float(i) * 100.0
		_icon(Vector2(88, y2 + 34), str(TYPE_ROWS[i]["icon"]), INK)
		draw_string(f_n, Vector2(122, y2 + 44), str(TYPE_ROWS[i]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, DIM)
		if real and i < 2:
			_right(f_gold, 470, y2 + 44, "—", FAINT, 40)
			draw_string(f_small, Vector2(486, y2 + 40), "不吃", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, FAINT)
		else:
			_right(f_v, 352, y2 + 48, _fmt_num(_type_f(str(TYPE_ROWS[i]["field"])) * 100.0), INK, 46)
			draw_string(_font(34), Vector2(368, y2 + 44), "/", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, FAINT)
			_right(_font(40), 470, y2 + 44, _fmt_num(_type_f(str(TYPE_ROWS[i]["field"]) + "_p") * 100.0) + "%", GOLD, 40)
		_rows.append({"rect": Rect2(64, y2, 592, 92), "kind": "type", "idx": i})

	draw_string(f_small, Vector2(64, 1180), "点任意一行看说明", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, FAINT)

	if popup >= 0:
		_draw_popup()

func _draw_popup() -> void:
	var f_title := _font(56)
	var f_lab := _font(38)
	var f_val := _font(50)
	var f_mid := _font(34)
	var f_eq := _font(40)
	var f_res := _font(46)

	draw_rect(Rect2(0, 0, 720, 1280), Color(0.10, 0.09, 0.08, 0.45))
	_panel(Rect2(56, 196, 608, 820), Color(0.99, 0.97, 0.93), Color(0.78, 0.70, 0.55), 18)

	var is_base := popup < 5
	var name := str(BASE_ROWS[popup]["name"]) if is_base else str(TYPE_ROWS[popup - 5]["name"])
	draw_string(f_title, Vector2(96, 268), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, INK)
	draw_string(f_mid, Vector2(596, 268), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, DIM)
	draw_line(Vector2(96, 300), Vector2(624, 300), FAINT, 2.0)

	if is_base:
		var i := popup
		var total := 0.0
		var base := 0.0
		match i:
			0: total = _h("atk", 12.0); base = 12.0
			1: total = _h("hp_max", 200.0); base = 200.0
			2: total = _h("aspd", 1.0); base = 1.0
			3: total = _h("crit", 0.05) * 100.0; base = 5.0
			4: total = _h("crit_dmg", 2.0) * 100.0; base = 200.0
		var temp := total - base
		draw_string(f_lab, Vector2(96, 372), "基础", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, DIM)
		_right(f_val, 624, 366, _fmt_num(base), INK, 50)
		draw_string(f_lab, Vector2(96, 452), "临时", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, DIM)
		_right(f_val, 624, 446, ("%+d" % int(round(temp))), GRN, 50)
		draw_line(Vector2(96, 508), Vector2(624, 508), FAINT, 2.0)
		draw_string(f_mid, Vector2(96, 546), "（基础 ＋ 临时）× 增幅", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
		draw_string(f_eq, Vector2(120, 616), _fmt_num(base) + " ＋ " + _fmt_num(temp), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, DIM)
		_right(f_eq, 624, 610, _fmt_num(total), INK, 40)
		_right(f_res, 624, 700, _fmt_num(total), SEAL, 46)
	else:
		var j := popup - 5
		var flat := _type_f(str(TYPE_ROWS[j]["field"])) * 100.0
		var pct := _type_f(str(TYPE_ROWS[j]["field"]) + "_p") * 100.0
		draw_string(f_lab, Vector2(96, 372), "固定", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, DIM)
		_right(f_val, 624, 366, _fmt_num(flat), INK, 50)
		draw_string(f_lab, Vector2(96, 452), "百分比", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, DIM)
		_right(f_val, 624, 446, _fmt_num(pct) + "%", GOLD, 50)
		draw_line(Vector2(96, 508), Vector2(624, 508), FAINT, 2.0)
		draw_string(f_mid, Vector2(96, 548), "两段依次作用，不对对手做假设", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)

# ---------------- 小工具 ----------------
func _font(sz: int) -> Font:
	return F

func _panel(r: Rect2, bg: Color, border: Color, rad: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(rad)
	sb.border_color = border
	sb.set_border_width_all(2)
	draw_style_box(sb, r)

func _right(font: Font, x: float, y: float, txt: String, col: Color, sz: int) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string(font, Vector2(x - w, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _icon(c: Vector2, kind: String, col: Color) -> void:
	var s := 11.0
	var w := 3.0
	match kind:
		"sword":
			draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, w + 1.0)
			draw_line(c + Vector2(-5, 1), c + Vector2(1, -5), col, w)
			draw_line(c + Vector2(-5, 1), c + Vector2(-1, 5), col, w)
		"heart":
			draw_circle(c + Vector2(-5, -3), 6.0, col)
			draw_circle(c + Vector2(5, -3), 6.0, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -2), c + Vector2(10, -2), c + Vector2(0, 11)]), col)
		"aspd":
			draw_line(c + Vector2(-11, -7), c + Vector2(2, -7), col, w)
			draw_line(c + Vector2(-11, 0), c + Vector2(7, 0), col, w)
			draw_line(c + Vector2(-11, 7), c + Vector2(12, 7), col, w)
		"star":
			var pts := [Vector2(0, -12), Vector2(-3, -3), Vector2(-12, 0), Vector2(-3, 3), Vector2(0, 12), Vector2(3, 3), Vector2(12, 0), Vector2(3, -3)]
			var arr := PackedVector2Array()
			for p in pts:
				arr.append(c + p)
			draw_colored_polygon(arr, col)
		"burst":
			for k in 8:
				var a := TAU * float(k) / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 4.0, c + Vector2(cos(a), sin(a)) * 12.0, col, w)
			draw_circle(c, 2.5, col)
		"arrow":
			draw_line(c + Vector2(-12, 6), c + Vector2(7, -6), col, w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(12, -9), c + Vector2(4, -8), c + Vector2(9, -3)]), col)
			draw_line(c + Vector2(-4, -9), c + Vector2(-4, 9), col, w - 1.0)
		"shield":
			var sh := PackedVector2Array([c + Vector2(-10, -9), c + Vector2(10, -9), c + Vector2(10, 2), c + Vector2(0, 12), c + Vector2(-10, 2)])
			sh.append(sh[0])
			draw_polyline(sh, col, w, true)
		"up":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(9, -2), c + Vector2(3.5, -2), c + Vector2(3.5, 11), c + Vector2(-3.5, 11), c + Vector2(-3.5, -2), c + Vector2(-9, -2)]), col)

# ---------------- 点 ----------------
func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = ev.position
	if popup >= 0:
		popup = -1
		queue_redraw()
		accept_event()
		return
	if p.x > 636 and p.y < 160:
		close()
		accept_event()
		return
	for r in _rows:
		if (r["rect"] as Rect2).has_point(p):
			if str(r["kind"]) == "tab":
				tab = int(r["idx"])
			else:
				popup = int(r["idx"]) if str(r["kind"]) == "base" else 5 + int(r["idx"])
			queue_redraw()
			accept_event()
			return
	close()
	accept_event()
