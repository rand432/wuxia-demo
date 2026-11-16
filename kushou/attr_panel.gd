extends Control
# ============================================================
# kushou/attr_panel.gd —— 详细属性页 + 属性弹窗（设计稿 v6）
#
#   基础 6 行（攻击 / 气血 / 攻速 / 内力 / 暴击 / 爆伤）—— 只写结果
#   伤害类型 7 页签（物理 / 金木水火土 / 真实）—— 穿透 / 减免 / 增幅 两段
#   点任意一行 → 弹窗（拆解 → 算式 → 总结）
#
#   数据全部读 core.attr_final / core.type_field，本文件只管画与点。
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
	{"key": "mp", "icon": "drop", "name": "内力"},
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
var popup_kind := ""     # base / type / real
var _rows: Array = []
var _refresh_t := 0.0

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

func _process(delta: float) -> void:
	if not visible: return
	_refresh_t += delta
	if _refresh_t >= 0.1:
		_refresh_t = 0.0
		queue_redraw()

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
		2: return "%.2f 次/秒" % _attack_rate()
		3: return _fmt_num(_h("mp_max", 100.0))
		4: return _fmt_num(_crit_rate() * 100.0) + "%"
		5: return _fmt_num(_h("crit_dmg", 2.0) * 100.0) + "%"
	return "—"

func _attack_rate() -> float:
	if core != null and core.has_method("hero_attack_interval"):
		return 1.0 / float(core.hero_attack_interval())
	return 0.0

func _crit_rate() -> float:
	if core != null and core.has_method("physical_crit_rate"):
		return float(core.physical_crit_rate())
	return clampf(_h("crit", 0.05), 0.0, 0.75)

# 使用真实属性层拆解，不把已经乘过的增幅伪装成临时属性。
func _base_details(i: int) -> Dictionary:
	var key: String = BASE_ROWS[i]["key"]
	var a: Dictionary = core.attr.get(key, {}) if core != null else {}
	var base := float(a.get("base", 0.0))
	var temp := float(a.get("temp", 0.0))
	var amp := float(a.get("amp", 0.0))
	var speed := key == "aspd"
	var percentage := key in ["crit", "cdmg"]
	if speed:
		base /= 1.8
		temp /= 1.8
	elif percentage:
		base *= 100.0
		temp *= 100.0
	var base_text := _fmt_val(base, speed)
	var temp_text := _fmt_delta(temp, speed)
	var equation := "%s ＋ %s" % [base_text, temp_text]
	var note := ""
	if not percentage:
		equation = "(%s %s) × %.2f" % [base_text, temp_text, 1.0 + amp]
	if speed:
		note = "基础间隔%.2f秒 · 最终含当前攻速效果" % preload("res://shared/combat_rules.gd").BASE_ATTACK_SECONDS
	elif key == "crit":
		note = "含当前暴击效果 · 最高75%"
	elif key == "cdmg":
		note = "最高400%"
	return {"base": base_text, "temp": temp_text, "amp": "—" if percentage else "%+.0f%%" % (amp * 100.0), "equation": equation, "note": note, "total": _base_text(i)}

func _type_f(field: String) -> float:
	if core == null:
		return 0.0
	var t: String = str(TYPES[clampi(tab, 0, TYPES.size() - 1)])
	match field:
		"pen": return float(core.type_effective_field(t, "pen_f"))
		"pen_p": return float(core.type_effective_field(t, "pen_p"))
		"red": return float(core.hero_fixed_reduction(t))
		"red_p": return float(core.type_effective_field(t, "red_p"))
		"amp": return float(core.type_field(t, "amp_f"))
	return float(core.type_field(t, "amp_p"))

func _type_f_raw(t: String, f: String) -> float:
	if core == null:
		return 0.0
	return float(core.type_field(t, f))

# ---------------- 画 ----------------
func _draw() -> void:
	var f_t := _font(42)
	var f_n := _font(28)
	var f_v := _font(42)
	var f_lab := _font(18)
	var f_tab := _font(22)
	var f_small := _font(16)
	var f_gold := _font(38)

	draw_rect(Rect2(0, 0, 720, 1280), Color(0.10, 0.09, 0.08, 0.55))
	_panel(Rect2(28, 56, 664, 1168), PAPER, Color(0.78, 0.70, 0.55), 14)
	draw_string(f_t, Vector2(64, 118), "详细属性", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, INK)
	draw_string(f_t, Vector2(636, 120), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, DIM)
	draw_line(Vector2(64, 152), Vector2(656, 152), Color(0.80, 0.76, 0.66), 2.0)
	draw_string(f_lab, Vector2(64, 186), "基 础", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GOLD)

	_rows.clear()
	for i in BASE_ROWS.size():
		var y := 200.0 + float(i) * 92.0
		_icon(Vector2(88, y + 32), str(BASE_ROWS[i]["icon"]), INK)
		draw_string(f_n, Vector2(122, y + 42), str(BASE_ROWS[i]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, DIM)
		var txt := _base_text(i)
		var sz := 42 if txt.length() <= 4 else 34
		_right(_font(sz), 470, y + 44, txt, INK, sz)
		_rows.append({"rect": Rect2(64, y, 592, 86), "kind": "base", "idx": i})

	draw_line(Vector2(64, 770), Vector2(656, 770), Color(0.80, 0.76, 0.66), 2.0)
	draw_string(f_lab, Vector2(64, 804), "伤害类型", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GOLD)

	for i in TYPES.size():
		var x := 64.0 + float(i) * 85.0
		var on := i == tab
		var r := Rect2(x, 820, 82, 48)
		draw_rect(r, SEAL if on else Color(0.98, 0.96, 0.92), true)
		if not on:
			draw_rect(r, FAINT, false, 1.0)
		var col := Color(0.98, 0.95, 0.88) if on else INK
		draw_string(f_tab, Vector2(x, 852), str(TAB_LABEL[i]), HORIZONTAL_ALIGNMENT_CENTER, 82, 22, col)
		_rows.append({"rect": r, "kind": "tab", "idx": i})

	if tab == 6:
		_real_rows(f_n, f_v, f_gold, f_small)
	else:
		for i in TYPE_ROWS.size():
			var y2 := 892.0 + float(i) * 96.0
			_icon(Vector2(88, y2 + 32), str(TYPE_ROWS[i]["icon"]), INK)
			draw_string(f_n, Vector2(122, y2 + 42), str(TYPE_ROWS[i]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, DIM)
			_type_pair(y2, str(TYPE_ROWS[i]["field"]), f_v, f_gold)
			_rows.append({"rect": Rect2(64, y2, 592, 90), "kind": "type", "idx": i})
	var amp_summary := "最终增幅 +%.0f%% · 上限200%%" % (float(core.type_amp(str(TYPES[tab]))) * 100.0) if core != null else ""
	if tab != 6:
		draw_string(f_small, Vector2(64, 1174), amp_summary, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
	draw_string(f_small, Vector2(64, 1200), "点任意一行看说明", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, FAINT)

	if popup >= 0:
		_draw_popup()

func _real_rows(f_n: Font, f_v: Font, f_gold: Font, f_small: Font) -> void:
	var defs := [
		{"icon": "diamond", "name": "真实攻击", "val": _fmt_num(_type_f_raw("真实", "atk")), "grey": false},
		{"icon": "up", "name": "真实伤害增幅", "val": _fmt_num(_type_f_raw("真实", "amp_f") * 100.0),
			"val2": _fmt_num(_type_f_raw("真实", "amp_p") * 100.0) + "%", "grey": false},
		{"icon": "arrow", "name": "穿透", "val": "—", "grey": true},
		{"icon": "shield", "name": "减免", "val": "—", "grey": true},
	]
	for i in defs.size():
		var y2 := 892.0 + float(i) * 78.0
		var grey := bool(defs[i]["grey"])
		_icon(Vector2(88, y2 + 28), str(defs[i]["icon"]), FAINT if grey else INK)
		draw_string(f_n, Vector2(122, y2 + 38), str(defs[i]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, FAINT if grey else DIM)
		if grey:
			_right(f_gold, 470, y2 + 36, "—", FAINT, 38)
			draw_string(f_small, Vector2(486, y2 + 32), "不吃", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, FAINT)
		elif defs[i].has("val2"):
			_right(_font(42), 352, y2 + 40, str(defs[i]["val"]), INK, 42)
			draw_string(_font(32), Vector2(368, y2 + 36), "/", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, FAINT)
			_right(_font(38), 470, y2 + 36, str(defs[i]["val2"]), GOLD, 38)
		else:
			_right(_font(42), 470, y2 + 40, str(defs[i]["val"]), INK, 42)
		_rows.append({"rect": Rect2(64, y2, 592, 74), "kind": "real", "idx": i})
	if core != null:
		draw_string(f_small, Vector2(64, 1040), "最终增幅 +%.0f%% · 上限200%%" % (float(core.type_amp("真实")) * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)

func _type_pair(y2: float, field: String, f_v: Font, f_gold: Font) -> void:
	_right(_font(42), 352, y2 + 44, _fmt_num(_type_f(field) * 100.0), INK, 42)
	draw_string(_font(32), Vector2(368, y2 + 40), "/", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, FAINT)
	_right(_font(38), 470, y2 + 40, _fmt_num(_type_f(field + "_p") * 100.0) + "%", GOLD, 38)

func _draw_popup() -> void:
	var f_title := _font(56)
	var f_lab := _font(36)
	var f_val := _font(50)
	var f_mid := _font(34)
	var f_res := _font(46)

	draw_rect(Rect2(0, 0, 720, 1280), Color(0.10, 0.09, 0.08, 0.45))
	_panel(Rect2(56, 196, 608, 780), Color(0.99, 0.97, 0.93), Color(0.78, 0.70, 0.55), 18)

	var is_base := popup_kind == "base"
	var is_real := popup_kind == "real"
	var name := ""
	if is_base:
		name = str(BASE_ROWS[popup]["name"])
	elif is_real:
		name = ["真实攻击", "真实伤害增幅", "穿透", "减免"][popup]
	else:
		name = str(TYPE_ROWS[popup]["name"])
	draw_string(f_title, Vector2(96, 268), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, INK)
	draw_string(f_mid, Vector2(596, 268), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, DIM)
	draw_line(Vector2(96, 300), Vector2(624, 300), FAINT, 2.0)

	if is_base:
		var data := _base_details(popup)
		for row in range(3):
			var label: String = ["基础倍率" if popup == 2 else "基础", "临时倍率" if popup == 2 else "临时", "增幅"][row]
			var value: String = data[["base", "temp", "amp"][row]]
			var y := 372.0 + float(row) * 80.0
			draw_string(f_lab, Vector2(96, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, DIM)
			_right(f_val, 624, y - 6, value, INK if row == 0 else (GRN if row == 1 else GOLD), 50)
		draw_line(Vector2(96, 580), Vector2(624, 580), FAINT, 2.0)
		var equation: String = data["equation"]
		var eq_size := 32 if equation.length() > 22 else 38
		draw_string(_font(eq_size), Vector2(96, 642), equation, HORIZONTAL_ALIGNMENT_LEFT, -1, eq_size, DIM)
		_right(f_res, 624, 724, data["total"], SEAL, 46)
		draw_string(_font(22), Vector2(96, 786), data["note"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DIM)
		if popup == 2:
			draw_string(_font(22), Vector2(96, 830), "近身出手频率 · 寻敌、走位与停顿另计", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DIM)
	elif is_real:
		if popup == 0:
			draw_string(f_lab, Vector2(96, 372), "真实攻击", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, DIM)
			_right(f_val, 624, 366, _fmt_num(_type_f_raw("真实", "atk")), INK, 50)
			draw_line(Vector2(96, 424), Vector2(624, 424), FAINT, 2.0)
			draw_string(f_mid, Vector2(96, 470), "由请神技能换算", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
			draw_string(f_mid, Vector2(96, 514), "不吃总攻击", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
			draw_string(_font(28), Vector2(96, 570), "例：刺骨 ＝ 气血上限 × 2.5%", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, DIM)
		elif popup == 1:
			var af := _type_f_raw("真实", "amp_f") * 100.0
			var ap := _type_f_raw("真实", "amp_p") * 100.0
			draw_string(f_lab, Vector2(96, 372), "固定", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, DIM)
			_right(f_val, 624, 366, _fmt_num(af), INK, 50)
			draw_string(f_lab, Vector2(96, 452), "百分比", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, DIM)
			_right(f_val, 624, 446, _fmt_num(ap) + "%", GOLD, 50)
			draw_line(Vector2(96, 508), Vector2(624, 508), FAINT, 2.0)
			draw_string(f_mid, Vector2(96, 552), "唯一对真实伤害生效的加成", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
			draw_string(_font(28), Vector2(96, 626), "最终增幅 +%.0f%% · 最高200%%" % (float(core.type_amp("真实")) * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, SEAL)
		else:
			draw_string(f_mid, Vector2(96, 410), "真实伤害不吃它", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
			draw_string(f_mid, Vector2(96, 460), "没有抗性可穿、也不可减免", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, DIM)
	else:
		var j := popup
		var flat := _type_f(str(TYPE_ROWS[j]["field"])) * 100.0
		var pct := _type_f(str(TYPE_ROWS[j]["field"]) + "_p") * 100.0
		draw_string(f_lab, Vector2(96, 372), "固定", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, DIM)
		_right(f_val, 624, 366, _fmt_num(flat), INK, 50)
		draw_string(f_lab, Vector2(96, 452), "百分比", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, DIM)
		_right(f_val, 624, 446, _fmt_num(pct) + "%", GOLD, 50)
		draw_line(Vector2(96, 508), Vector2(624, 508), FAINT, 2.0)
		var formula: String = ["先扣固定，再削剩余", "两段依次作用", "固定增幅 × (1＋百分比)"][j]
		draw_string(f_mid, Vector2(96, 552), formula, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
		if j == 2:
			draw_string(_font(28), Vector2(96, 626), "最终增幅 +%.0f%% · 最高200%%" % (float(core.type_amp(str(TYPES[tab]))) * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, SEAL)
		elif j == 1:
			var reduction := 1.0 - (1.0 - flat / 100.0) * (1.0 - pct / 100.0)
			draw_string(_font(28), Vector2(96, 626), "最终减伤 %.0f%% · 两段相乘" % (reduction * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, SEAL)
			draw_string(_font(24), Vector2(96, 680), "固定含当前效果 · 两段各最高60%", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, DIM)
		else:
			draw_string(_font(28), Vector2(96, 626), "固定、百分比各最高60%", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, DIM)

# ---------------- 小工具 ----------------
func _font(sz: int) -> Font:
	return F

func _fmt_val(v: float, pct: bool) -> String:
	return "%.2f" % v if pct else _fmt_num(v)

func _fmt_delta(v: float, pct: bool) -> String:
	if pct:
		return "%+.2f" % v
	return "%+d" % int(round(v))

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
		"drop":
			draw_circle(c + Vector2(0, 3), 7.0, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6.5, 0), c + Vector2(6.5, 0), c + Vector2(0, -11)]), col)
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
		"diamond":
			var dm := PackedVector2Array([c + Vector2(0, -11), c + Vector2(8, 0), c + Vector2(0, 11), c + Vector2(-8, 0)])
			dm.append(dm[0])
			draw_polyline(dm, col, w, true)

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
				popup_kind = str(r["kind"])
				popup = int(r["idx"])
			queue_redraw()
			accept_event()
			return
	close()
	accept_event()
