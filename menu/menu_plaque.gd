extends Control
# ============================================================
# menu_plaque.gd —— 主界面·牌子层（v97 建 / v98 按用户反馈改）
#
#   用户（2026-10-08）在主界面上标了 11 处锚点（表见 docs/主界面布局_用户标注.md），
#   并对形式拍了板：**一律竖排木牌 / 悬挂木牌 / 六边形徽标**，
#   且"每个牌子接原有功能，一个不丢"。
#
#   v98 按用户第二轮反馈改的几处：
#     · **白色**：除"挂机/建设"（挂在横梁上的两块木牌）之外，其余功能竖牌一律改成**白纸牌**；
#     · **横梁**：名号底下那条横线＝梁——"挂机/建设"就从它上面吊下来（眼睛一看就懂）；
#     · **出村**：改成**向左的箭头**（原来是一块竖排"出村"木牌）；
#     · **藏宝阁**往右挪了一点；**商店**固定（不再随风轻摆、出现时机也不再随剧情忽隐忽现）；
#     · **跟着画卷走**：page="village" 的牌子随村景页左右滑动（查 on the cover they slide away）。
#
#   做法：**一层 + 一张表**。
#     · 画：全在 _draw() 里画；
#     · 点：每块牌子配一个**透明命中盒**（Control / MOUSE_FILTER_STOP），
#       牌子点得到，牌子之外的空白照旧落回主界面（拖卷、点景），互不打架；
#     · 摆：锚点写成**占屏比例**（0~1），跟用户那张标注表一行一行对得上。
#
#   ⚠ 两条老坑（都在这份里绕开了）：
#     ① 贴图取图口走 CharArt（静态缓存），**不在 _draw 里现 load**——现 load 会画成白块；
#     ② 牌子一律**不动**（用户："商店固定"）——所以没有 sway，也没有 draw_set_transform。
# ============================================================
const Conf := preload("res://menu/menu_conf.gd")
const Draw := preload("res://menu/menu_draw.gd")
const CharArt := preload("res://shared/char_art.gd")

const DW := 720.0
const DH := 1280.0
const ROPE := 26.0                                   # 吊绳长度（钉子在上面）
const WOOD0 := Color(0.72, 0.56, 0.34, 0.99)         # 旧木
const WOOD1 := Color(0.87, 0.71, 0.46, 0.99)         # 暖木（有货/可点）
const WOOD_EDGE := Color(0.40, 0.29, 0.17, 0.92)
const BEAM_C := Color(0.66, 0.50, 0.31, 0.98)        # 横梁
const PAPER_C := Color(0.965, 0.949, 0.902, 0.97)    # 白纸牌面
const PAPER_EDGE := Color(0.30, 0.25, 0.21, 0.62)
const ROPE_C := Color(0.35, 0.29, 0.22, 0.92)
const INK := Color(0.16, 0.155, 0.18)
const SEAL := Color(0.72, 0.20, 0.15)
const GOLD_C := Color(0.72, 0.58, 0.22)

var font: Font = null
var t := 0.0
var items: Array = []      # {id,kind,cx,cy,w,h,text,fn,sub,act,vis,warm,gold,style,page,hang_y}
var slide := 0.0           # 画卷偏移：page="village" 的牌子跟着村景页一起滑
var _hover := -1
var _down := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE     # 空白处放行给主界面
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(d: float) -> void:
	t += d
	queue_redraw()

# ---------------- 建牌子 ----------------
# 锚点＝**牌面中心**的占屏比例（跟用户标注表的框心对齐）
# cfg 可选：{"white": true（白纸牌）, "hang_y": 118.0（挂在横梁上：牌顶自动排到梁下）, "page": "village"}
func add_hang(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", act := "", cfg := {}) -> void:
	_push(id, "hang", rx, ry, 64.0, 0.0, text, fn, sub, act, cfg)   # 高度由 _hang_h 现算
	_relayout(items[items.size() - 1])

func add_hex(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", cfg := {}) -> void:
	_push(id, "hex", rx, ry, 78.0, 78.0, text, fn, sub, "", cfg)

func add_ribbon(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", cfg := {}) -> void:
	_push(id, "ribbon", rx, ry, 68.0, 34.0, text, fn, sub, "", cfg)

func add_slip(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", cfg := {}) -> void:
	var w := 40.0
	var h := 20.0 + float(maxi(1, text.length())) * 30.0
	_push(id, "slip", rx, ry, w, h, text, fn, sub, "", cfg)

func add_disc(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", cfg := {}) -> void:
	_push(id, "disc", rx, ry, 96.0, 96.0, text, fn, sub, "", cfg)

func add_txt(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", cfg := {}) -> void:
	var w := 22.0 * float(maxi(1, text.length())) + 24.0
	_push(id, "txt", rx, ry, w, 46.0, text, fn, sub, "", cfg)

# 横梁（挂机/建设从它上面吊下来）：x0~x1 是梁的两端（画布坐标），y 是梁心，nails 是钉子的 x
func add_beam(id: String, x0: float, x1: float, y: float, nails: Array) -> void:
	var cfg := {"no_hit": true}
	_push(id, "beam", 0.0, 0.0, x1 - x0, 10.0, "", Callable(), "", "", cfg)
	var it: Dictionary = items[items.size() - 1]
	it["cx"] = (x0 + x1) * 0.5
	it["cy"] = y
	it["nails"] = nails
	it["x0"] = x0
	it["x1"] = x1

# 箭头（出村）：dir = -1 向左 / 1 向右
func add_arrow(id: String, rx: float, ry: float, text: String, fn: Callable, dir := -1, cfg := {}) -> void:
	_push(id, "arrow", rx, ry, 84.0, 84.0, text, fn, "", "", cfg)
	(items[items.size() - 1] as Dictionary)["dir"] = dir

func _push(id: String, kind: String, rx: float, ry: float, w: float, h: float, text: String, fn: Callable, sub: String, act: String, cfg: Dictionary) -> void:
	var it := {
		"id": id, "kind": kind,
		"cx": rx * DW, "cy": ry * DH, "w": w, "h": h,
		"text": text, "fn": fn, "sub": sub, "act": act,
		"vis": true, "warm": 0.72, "gold": 0.0,
		"white": bool(cfg.get("white", false)),
		"page": str(cfg.get("page", "ui")),
		"hang_y": float(cfg.get("hang_y", -1.0)),
		"nails": [], "x0": 0.0, "x1": 0.0, "dir": -1,
	}
	items.append(it)
	if bool(cfg.get("no_hit", false)):
		return                      # 纯装饰件（横梁）不参与点击，免得挡住拖卷
	var hb := Control.new()
	hb.name = "hit_" + id
	hb.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(hb)
	var idx := items.size() - 1
	hb.mouse_entered.connect(func() -> void:
		_hover = idx
		queue_redraw())
	hb.mouse_exited.connect(func() -> void:
		if _hover == idx:
			_hover = -1
		queue_redraw())
	hb.gui_input.connect(_on_hit.bind(idx))
	_place_hit(it)

# 命中盒＝牌面外扩 8 像素（跟着 slide 一起走）
func _place_hit(it: Dictionary) -> void:
	var hb := get_node_or_null(NodePath("hit_" + str(it["id"])))
	if hb == null:
		return
	var pad := 8.0
	var s := slide if str(it["page"]) == "village" else 0.0
	(hb as Control).position = Vector2(float(it["cx"]) - float(it["w"]) * 0.5 - pad - s, float(it["cy"]) - float(it["h"]) * 0.5 - pad)
	(hb as Control).size = Vector2(float(it["w"]) + pad * 2.0, float(it["h"]) + pad * 2.0)

func _on_hit(ev: InputEvent, idx: int) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_down = idx
		queue_redraw()
	else:
		var was := _down
		_down = -1
		queue_redraw()
		if was == idx and idx >= 0 and idx < items.size():
			var it: Dictionary = items[idx]
			var f: Callable = it["fn"]
			if bool(it["vis"]) and f.is_valid():
				f.call()

# ---------------- 给主界面改状态 ----------------
func find_i(id: String) -> int:
	for i in items.size():
		if str((items[i] as Dictionary)["id"]) == id:
			return i
	return -1

func set_vis(id: String, v: bool) -> void:
	var i := find_i(id)
	if i < 0:
		return
	if bool((items[i] as Dictionary)["vis"]) != v:
		(items[i] as Dictionary)["vis"] = v
		var hb := get_node_or_null(NodePath("hit_" + id))
		if hb != null:
			(hb as Control).visible = v

func set_sub(id: String, s: String) -> void:
	var i := find_i(id)
	if i < 0:
		return
	var it: Dictionary = items[i]
	if str(it["sub"]) == s:
		return
	it["sub"] = s
	_relayout(it)

func set_act(id: String, s: String) -> void:
	var i := find_i(id)
	if i < 0:
		return
	var it: Dictionary = items[i]
	if str(it["act"]) == s:
		return
	it["act"] = s
	_relayout(it)

func set_warm(id: String, w: float, g: float) -> void:
	var i := find_i(id)
	if i >= 0:
		(items[i] as Dictionary)["warm"] = w
		(items[i] as Dictionary)["gold"] = g

# 画卷偏移：村景页的牌子跟着走（封面页上看不到村里的牌子）
func set_slide(s: float) -> void:
	if is_equal_approx(s, slide):
		return
	slide = s
	for it in items:
		if str((it as Dictionary)["page"]) == "village":
			_place_hit(it)

func item_rect(id: String) -> Rect2:
	var i := find_i(id)
	if i < 0:
		return Rect2()
	var it: Dictionary = items[i]
	return Rect2(float(it["cx"]) - float(it["w"]) * 0.5, float(it["cy"]) - float(it["h"]) * 0.5, float(it["w"]), float(it["h"]))

# 悬挂木牌的牌面高度：标题竖排 + 副标题若干行 + 底部一行动作字
func _hang_h(it: Dictionary) -> float:
	var fs := 22.0
	var n := maxi(1, str(it["text"]).length())
	var sub := str(it["sub"])
	var sub_lines: int = sub.split("\n").size() if sub != "" else 0
	var act := str(it["act"])
	return 16.0 + float(n) * (fs + 4.0) + 8.0 + float(sub_lines) * 19.0 + (30.0 if act != "" else 0.0) + 16.0

# 副标题/动作字是活的（挂机那块每 0.5 秒换一次字），牌面高度与命中盒要跟着重算
func _relayout(it: Dictionary) -> void:
	if str(it["kind"]) != "hang":
		return
	it["h"] = _hang_h(it)
	if float(it["hang_y"]) >= 0.0:
		# 挂在梁上：**牌顶**固定在梁下（梁不动，牌子长短往下长，两块牌顶齐平）
		it["cy"] = float(it["hang_y"]) + ROPE + float(it["h"]) * 0.5
	_place_hit(it)

# ---------------- 画 ----------------
func _draw() -> void:
	if font == null:
		return
	for i in items.size():
		var it: Dictionary = items[i]
		it["idx"] = i
		if not bool(it["vis"]):
			continue
		var s := slide if str(it["page"]) == "village" else 0.0
		if s > DW + 120.0 or s < -(DW + 120.0):
			continue                        # 整页滑出屏幕了，省点力气
		match str(it["kind"]):
			"beam":
				_draw_beam(it)
			"hang":
				_draw_hang(it, s)
			"hex":
				_draw_hex(it, s)
			"ribbon":
				_draw_ribbon(it, s)
			"slip":
				_draw_slip(it, s)
			"disc":
				_draw_disc(it, s)
			"txt":
				_draw_txt(it, s)
			"arrow":
				_draw_arrow(it, s)

func _wood(it: Dictionary) -> Color:
	var c: Color = WOOD0.lerp(WOOD1, clampf(float(it["warm"]), 0.0, 1.0))
	if _hover == int(it["idx"]):
		c = c.lightened(0.06)
	if _down == int(it["idx"]):
		c = c.darkened(0.08)
	return c

func _face(it: Dictionary) -> Color:
	if bool(it["white"]):
		var c := PAPER_C
		if _hover == int(it["idx"]):
			c = c.lerp(Color(1.0, 0.97, 0.90, 1.0), 0.6)
		if _down == int(it["idx"]):
			c = c.darkened(0.05)
		return c
	return _wood(it)

# 横梁：木条 + 两枚钉子（挂机/建设从这儿吊下来）
func _draw_beam(it: Dictionary) -> void:
	var x0 := float(it["x0"])
	var x1 := float(it["x1"])
	var y := float(it["cy"])
	draw_colored_polygon(Draw.round_poly(Rect2(x0 + 2.0, y + 3.0, x1 - x0, 10.0), 4.0), Color(0.06, 0.05, 0.05, 0.18))
	draw_colored_polygon(Draw.round_poly(Rect2(x0, y, x1 - x0, 10.0), 4.0), BEAM_C)
	draw_rect(Rect2(x0 + 3.0, y + 1.6, x1 - x0 - 6.0, 3.0), BEAM_C.lightened(0.12))   # ⚠ 别用 round_poly：4 像素高的条给 3 的圆角＝退化多边形（triangulation failed）
	var bp := Draw.round_poly(Rect2(x0, y, x1 - x0, 10.0), 4.0)
	bp.append(bp[0])
	draw_polyline(bp, WOOD_EDGE, 1.5, true)
	for nx in (it["nails"] as Array):
		draw_circle(Vector2(float(nx), y + 5.0), 2.4, Color(0.30, 0.22, 0.13, 0.75))
		draw_circle(Vector2(float(nx) - 0.6, y + 4.4), 0.9, Color(0.85, 0.80, 0.70, 0.5))

# 悬挂牌：钉＋绳＋牌面（下摆收尖）＋木纹（木牌）/素面（白纸牌）＋红穗
func _draw_hang(it: Dictionary, s: float) -> void:
	var w := float(it["w"])
	var h := float(it["h"])
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var x := cx - w * 0.5
	var y := cy - h * 0.5
	var peg := Vector2(cx, y - ROPE)
	var white := bool(it["white"])
	# 钉 + 两股绳
	draw_line(peg, Vector2(x + w * 0.30, y + 9.0), ROPE_C, 2.0, true)
	draw_line(peg, Vector2(x + w * 0.70, y + 9.0), ROPE_C, 2.0, true)
	draw_arc(peg, 3.4, 0.0, TAU, 12, ROPE_C, 1.6)
	if not white:
		draw_circle(peg, 2.0, Color(0.24, 0.18, 0.12, 0.95))
		draw_circle(peg + Vector2(-0.7, -0.7), 0.8, Color(0.72, 0.68, 0.60, 0.55))
	# 牌面
	if _down != int(it["idx"]):
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + 3.0, y + 4.0), Vector2(x + w - 3.0, y + 4.0),
			Vector2(x + w - 3.0, y + h - 25.0), Vector2(cx, y + h + 1.0), Vector2(x + 3.0, y + h - 25.0)]),
			Color(0.06, 0.05, 0.05, 0.20))
	var face := _face(it)
	var pts := PackedVector2Array([
		Vector2(x + 3.0, y), Vector2(x + w - 3.0, y),
		Vector2(x + w - 3.0, y + h - 26.0), Vector2(cx, y + h), Vector2(x + 3.0, y + h - 26.0)])
	draw_colored_polygon(pts, face)
	var line := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]])
	draw_polyline(line, WOOD_EDGE if not white else PAPER_EDGE, 1.8 if not white else 1.6, true)
	# 顶部横档 + 牌耳两孔
	draw_line(Vector2(x + 5.0, y + 14.0), Vector2(x + w - 5.0, y + 14.0), Color(0.52, 0.38, 0.21, 0.38) if not white else Color(0.30, 0.25, 0.21, 0.30), 1.2, true)
	draw_circle(Vector2(x + w * 0.30, y + 9.0), 2.2, Color(0.30, 0.22, 0.13, 0.70))
	draw_circle(Vector2(x + w * 0.70, y + 9.0), 2.2, Color(0.30, 0.22, 0.13, 0.70))
	# 木纹（只有木牌才有）
	if not white:
		for k in 3:
			var gx := x + 10.0 + float(k) * (w - 20.0) * 0.5
			draw_line(Vector2(gx, y + 18.0), Vector2(gx + sin(float(k) * 2.2) * 2.0, y + h - 38.0), Color(0.52, 0.38, 0.21, 0.24), 1.0, true)
	# 金漆内衬（有货/满了亮一档，只有挂机那种木牌有）
	var gold := float(it["gold"])
	if gold > 0.01 and not white:
		draw_polyline(PackedVector2Array([
			Vector2(x + 8.0, y + 22.0), Vector2(x + w - 8.0, y + 22.0),
			Vector2(x + w - 8.0, y + h - 32.0), Vector2(cx, y + h - 8.0), Vector2(x + 8.0, y + h - 32.0),
			Vector2(x + 8.0, y + 22.0)]), Color(GOLD_C.r, GOLD_C.g, GOLD_C.b, 0.30 + 0.55 * gold), 1.4 + 0.8 * gold)
	# 红穗
	draw_line(Vector2(cx, y + h), Vector2(cx, y + h + 9.0), Color(0.68, 0.15, 0.12, 0.72), 1.4, true)
	draw_circle(Vector2(cx, y + h + 10.0), 1.8, Color(0.68, 0.15, 0.12, 0.62))
	# 竖排大字（自下而上排：动作字压在收窄之前）
	var fs := 22
	var txt := str(it["text"])
	var inkc: Color = Color(INK.r, INK.g, INK.b, 0.92) if not white else Color(0.13, 0.12, 0.14, 0.90)
	var ty := y + 18.0 + float(fs)
	for i in txt.length():
		draw_string(font, Vector2(x, ty), txt.substr(i, 1), HORIZONTAL_ALIGNMENT_CENTER, w, fs, inkc)
		ty += float(fs) + 4.0
	var act := str(it["act"])
	var act_y := y + h - 30.0
	if act != "":
		draw_string(font, Vector2(x, act_y), act, HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(SEAL.r, SEAL.g, SEAL.b, 0.88))
	var sub := str(it["sub"])
	if sub != "":
		var lines: PackedStringArray = sub.split("\n")
		var sy := y + h - (30.0 if act != "" else 16.0) - 10.0 - float(lines.size() - 1) * 19.0
		for ln in lines:
			draw_string(font, Vector2(x, sy), str(ln), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(INK.r, INK.g, INK.b, 0.72))
			sy += 19.0

# 六边形徽标（商店）
func _draw_hex(it: Dictionary, s: float) -> void:
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var r := float(it["w"]) * 0.5
	var pts := PackedVector2Array()
	for i in 6:
		var a := -PI * 0.5 + float(i) * TAU / 6.0
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r * 0.92))
	if _down != int(it["idx"]):
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(2.0, 4.0))
		draw_colored_polygon(sh, Color(0.06, 0.05, 0.05, 0.20))
	draw_colored_polygon(pts, _wood(it))
	var outline := PackedVector2Array(pts)
	outline.append(outline[0])
	draw_polyline(outline, WOOD_EDGE, 1.8, true)
	var gold := float(it["gold"])
	if gold > 0.01:
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(Vector2(cx + (p.x - cx) * 0.82, cy + (p.y - cy) * 0.82))
		inner.append(inner[0])
		draw_polyline(inner, Color(GOLD_C.r, GOLD_C.g, GOLD_C.b, 0.30 + 0.5 * gold), 1.4)
	var txt := str(it["text"])
	var fs := 19
	if txt.length() >= 3:
		fs = 15
	draw_string(font, Vector2(cx - r, cy + 7.0), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(INK.r, INK.g, INK.b, 0.92))
	var sub := str(it["sub"])
	if sub != "":
		draw_string(font, Vector2(cx - r - 10.0, cy + r + 18.0), sub, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0 + 20.0, 12, Color(INK.r, INK.g, INK.b, 0.62))

# 右上角斜挂小牌（设置）
func _draw_ribbon(it: Dictionary, s: float) -> void:
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var w := float(it["w"])
	var h := float(it["h"])
	draw_line(Vector2(cx + 14.0, cy - h * 0.5 - 22.0), Vector2(cx - w * 0.28, cy - h * 0.5 + 3.0), ROPE_C, 2.0, true)
	draw_line(Vector2(cx + 14.0, cy - h * 0.5 - 22.0), Vector2(cx + w * 0.28, cy - h * 0.5 + 3.0), ROPE_C, 2.0, true)
	draw_set_transform(Vector2(cx, cy), -0.30, Vector2.ONE)
	var r := Rect2(-w * 0.5, -h * 0.5, w, h)
	if _down != int(it["idx"]):
		draw_colored_polygon(Draw.round_poly(Rect2(r.position + Vector2(2.0, 4.0), r.size), 7.0), Color(0.06, 0.05, 0.05, 0.20))
	draw_colored_polygon(Draw.round_poly(r, 7.0), _wood(it))
	var bp := Draw.round_poly(r, 7.0)
	bp.append(bp[0])
	draw_polyline(bp, WOOD_EDGE, 1.7, true)
	draw_string(font, Vector2(r.position.x, r.position.y + h * 0.5 + 6.0), str(it["text"]), HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color(INK.r, INK.g, INK.b, 0.92))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# 竖排窄签（底部正中的玩家 ID）
func _draw_slip(it: Dictionary, s: float) -> void:
	var w := float(it["w"])
	var h := float(it["h"])
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var r := Rect2(cx - w * 0.5, cy - h * 0.5, w, h)
	draw_colored_polygon(Draw.round_poly(Rect2(r.position + Vector2(2.0, 3.0), r.size), 6.0), Color(0.06, 0.05, 0.05, 0.14))
	draw_colored_polygon(Draw.round_poly(r, 6.0), Color(0.955, 0.937, 0.886, 0.66))
	var bp := Draw.round_poly(r, 6.0)
	bp.append(bp[0])
	draw_polyline(bp, Color(0.28, 0.23, 0.19, 0.55), 1.4, true)
	var txt := str(it["text"])
	var fs := 20
	var ty := r.position.y + 14.0 + float(fs)
	for i in txt.length():
		draw_string(font, Vector2(r.position.x, ty), txt.substr(i, 1), HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(INK.r, INK.g, INK.b, 0.86))
		ty += float(fs) + 10.0

# 圆形头像（玩家）：宣纸底 + 墨圈 + Q版头像
func _draw_disc(it: Dictionary, s: float) -> void:
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var r := float(it["w"]) * 0.5
	draw_circle(Vector2(cx + 2.0, cy + 4.0), r, Color(0.06, 0.05, 0.05, 0.16))
	draw_circle(Vector2(cx, cy), r, Color(0.955, 0.937, 0.886, 0.94))
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 48, Color(0.30, 0.25, 0.21, 0.72), 2.2, true)
	draw_arc(Vector2(cx, cy), r - 5.0, 0.0, TAU, 48, Color(SEAL.r, SEAL.g, SEAL.b, 0.32), 1.2, true)
	var tex: Texture2D = CharArt.q_head("player")
	if tex != null:
		var tw := tex.get_width()
		var th := tex.get_height()
		var k: float = (r * 1.72) / maxf(1.0, float(maxi(tw, th)))
		var dw := float(tw) * k
		var dh := float(th) * k
		draw_texture_rect(tex, Rect2(cx - dw * 0.5, cy - dh * 0.5 + r * 0.10, dw, dh), false)
	else:
		draw_string(font, Vector2(cx - r, cy + 10.0), "侠", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 34, Color(INK.r, INK.g, INK.b, 0.85))

# 名号（头像右边那一行）——底下不再画线：那条线现在是**横梁**（见 add_beam）
func _draw_txt(it: Dictionary, s: float) -> void:
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var w := float(it["w"])
	var txt := str(it["text"])
	if _hover == int(it["idx"]):
		draw_colored_polygon(Draw.round_poly(Rect2(cx - w * 0.5, cy - 22.0, w, 44.0), 8.0), Color(1.0, 0.97, 0.90, 0.45))
	draw_string(font, Vector2(cx - w * 0.5, cy + 9.0), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 27, Color(0.12, 0.11, 0.13, 0.92))
	var sub := str(it["sub"])
	if sub != "":
		draw_string(font, Vector2(cx - w * 0.5, cy + 34.0), sub, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(INK.r, INK.g, INK.b, 0.60))

# 箭头（出村）：一笔墨箭头 + 底下一行小字
func _draw_arrow(it: Dictionary, s: float) -> void:
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var d := float(it["dir"])
	var col := Color(0.16, 0.15, 0.17, 0.80)
	if _hover == int(it["idx"]):
		col = Color(0.72, 0.20, 0.15, 0.92)
	if _down == int(it["idx"]):
		col = Color(0.55, 0.16, 0.12, 0.95)
	var len := 30.0
	var hh := 17.0
	# 杆
	draw_line(Vector2(cx - d * len * 0.15, cy), Vector2(cx + d * len, cy), col, 5.0, true)
	# 头
	draw_line(Vector2(cx + d * len, cy), Vector2(cx + d * (len - hh), cy - hh * 0.72), col, 5.0, true)
	draw_line(Vector2(cx + d * len, cy), Vector2(cx + d * (len - hh), cy + hh * 0.72), col, 5.0, true)
	var txt := str(it["text"])
	if txt != "":
		draw_string(font, Vector2(cx - 34.0, cy + 44.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 68.0, 15, Color(INK.r, INK.g, INK.b, 0.62))
