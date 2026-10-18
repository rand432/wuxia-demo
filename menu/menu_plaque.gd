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
const Audio := preload("res://shared/audio.gd")   # v98：点击反馈音（用户点名要）
const Ui := preload("res://menu/menu_theme.gd")     # v200：影之刃·玄墨鎏金皮肤（原名 Skin 撞了引擎内置类）

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

# ---- v211 主界面骨架（顶栏贯通 / 右栏等宽 / 历练大碑）----
const TOPBAR_H := 96.0
const RAIL_W := 110.0
const RAIL_H := 172.0
const RAIL_TOP := 160.0
const RAIL_GAP := 20.0
const RAIL_IDS := ["shop", "kushou_test", "cave", "treasure", "craft"]
var _rail_seq := 0

var font: Font = null
var t := 0.0
var items: Array = []      # {id,kind,cx,cy,w,h,text,fn,sub,act,vis,warm,gold,style,page,hang_y}
var slide := 0.0           # 画卷偏移：page="village" 的牌子跟着村景页一起滑
var _hover := -1
var _down := -1
var _ripples: Array = []       # v200：点击涟漪 {p: Vector2, t: float}
var _brush: Font = null        # v200：毛笔字（Ma Shan Zheng）

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE     # 空白处放行给主界面
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if Ui.SKIN == 1 and ResourceLoader.exists(Ui.FONT_BRUSH):
		var r: Resource = load(Ui.FONT_BRUSH)
		if r is Font:
			_brush = r as Font

func _process(d: float) -> void:
	t += d
	if Ui.SKIN == 1:
		_tick_anim(d)
	queue_redraw()

# v200（用户："主要要丝滑"）：所有悬停/按下都走缓动，不再瞬间跳变。
#   · hv：指数趋近（跟手、帧率无关）
#   · dn：阻尼弹簧（松手有回弹，不是硬切）
func _tick_anim(d: float) -> void:
	for i in items.size():
		var it: Dictionary = items[i]
		var hv := Ui.ease(float(it.get("hv", 0.0)), 1.0 if _hover == i else 0.0, 13.0, d)
		it["hv"] = hv
		var sp: Array = Ui.spring([float(it.get("dn", 0.0)), float(it.get("dvy", 0.0))],
			1.0 if _down == i else 0.0, 420.0, 27.0, d)
		it["dn"] = sp[0]
		it["dvy"] = sp[1]
		# v211：入场计时——只在"可见"时走；收起来就复位，下次出现再演一遍
		var el := float(it.get("el", -1.0))
		if bool(it["vis"]):
			el = minf((0.0 if el < 0.0 else el) + d, 4.0)
		else:
			el = -1.0
		it["el"] = el
		# v211：右栏自动补位——cy 缓动到 tcy（隐藏一格，下面的平滑往上顶）
		if str(it["kind"]) == "rail":
			var tcy := float(it.get("tcy", it["cy"]))
			if absf(float(it["cy"]) - tcy) > 0.04:
				it["cy"] = Ui.ease(float(it["cy"]), tcy, 14.0, d)
				_place_hit(it)
			else:
				it["cy"] = tcy
	# 涟漪：0.55 秒走完
	var keep: Array = []
	for rp in _ripples:
		rp["t"] = float(rp["t"]) + d
		if float(rp["t"]) < 0.55:
			keep.append(rp)
	_ripples = keep

# 点击涟漪（金环由内向外扩）
func _burst(pos: Vector2) -> void:
	if Ui.SKIN != 1:
		return
	_ripples.append({"p": pos, "t": 0.0})
	if _ripples.size() > 6:
		_ripples.pop_front()

# ---------------- 建牌子 ----------------
# 锚点＝**牌面中心**的占屏比例（跟用户标注表的框心对齐）
# cfg 可选：{"white": true（白纸牌）, "hang_y": 118.0（挂在横梁上：牌顶自动排到梁下）, "page": "village"}
func add_hang(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", act := "", cfg := {}) -> void:
	_push(id, "hang", rx, ry, 64.0, 0.0, text, fn, sub, act, cfg)   # 高度由 _hang_h 现算
	_relayout(items[items.size() - 1])

# v115（用户："商店按钮换成商店的ui"）：六边形徽标 → **一间铺子**（雨棚＋铺面＋门窗＋招牌字）
func add_shop(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", cfg := {}) -> void:
	_push(id, "shop", rx, ry, 116.0, 128.0, text, fn, sub, "", cfg)

func add_ribbon(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", cfg := {}) -> void:
	_push(id, "ribbon", rx, ry, 68.0, 34.0, text, fn, sub, "", cfg)

func add_slip(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", cfg := {}) -> void:
	var w := 40.0
	var h := 20.0 + float(maxi(1, text.length())) * 30.0
	_push(id, "slip", rx, ry, w, h, text, fn, sub, "", cfg)

func add_disc(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", cfg := {}) -> void:
	var dd := float(cfg.get("w", 96.0))
	_push(id, "disc", rx, ry, dd, dd, text, fn, sub, "", cfg)

func add_txt(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", cfg := {}) -> void:
	var w := float(cfg.get("w", 22.0 * float(maxi(1, text.length())) + 24.0))
	_push(id, "txt", rx, ry, w, float(cfg.get("h", 46.0)), text, fn, sub, "", cfg)

# v211：顶栏小牌（进阶 / 设置）——横置墨牌 + 金线
func add_chip(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", cfg := {}) -> void:
	_push(id, "chip", rx, ry, float(cfg.get("w", 80.0)), float(cfg.get("h", 34.0)), text, fn, sub, "", cfg)

# v211：右侧功能栏的一格——icon 水印 + 大号毛笔单字 + 小字名
func add_rail(id: String, rx: float, ry: float, big: String, label: String, tex: Texture2D,
		fn: Callable, sub := "", cfg := {}) -> void:
	var c: Dictionary = cfg.duplicate()
	c["big"] = big
	c["label"] = label
	c["tex"] = tex
	_push(id, "rail", rx, ry, RAIL_W, RAIL_H, label, fn, sub, "", c)
	var it: Dictionary = items[items.size() - 1]
	it["seq"] = _rail_seq
	_rail_seq += 1

# v211：中央朱砂大碑（历练）
func add_stele(id: String, rx: float, ry: float, text: String, fn: Callable, sub := "", cfg := {}) -> void:
	_push(id, "stele", rx, ry, float(cfg.get("w", 452.0)), float(cfg.get("h", 138.0)), text, fn, sub, "", cfg)

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
	_push(id, "arrow", rx, ry, 124.0, 68.0, text, fn, "", "", cfg)   # v102：箭头放大，命中盒跟着
	(items[items.size() - 1] as Dictionary)["dir"] = dir

func _push(id: String, kind: String, rx: float, ry: float, w: float, h: float, text: String, fn: Callable, sub: String, act: String, cfg: Dictionary) -> void:
	var it := {
		"id": id, "kind": kind,
		"cx": rx * DW, "cy": ry * DH, "w": float(cfg.get("w", w)), "h": float(cfg.get("h", h)),
		"text": text, "fn": fn, "sub": sub, "act": act,
		"vis": true, "warm": 0.72, "gold": 0.0,
		"white": bool(cfg.get("white", false)),
		"page": str(cfg.get("page", "ui")),
		"hang_y": float(cfg.get("hang_y", -1.0)),
		"nails": [], "x0": 0.0, "x1": 0.0, "dir": -1,
		"tex": cfg.get("tex", null),
		"big": str(cfg.get("big", "")), "label": str(cfg.get("label", "")),
		"el": -1.0, "tcy": float(cfg.get("tcy", ry * DH)),
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
	if str(it["sub"]) != "":
		hb.tooltip_text = str(it["sub"])
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
		_click_sfx(idx)
		var it: Dictionary = items[idx]
		var ss := slide if str(it["page"]) == "village" else 0.0
		_burst(Vector2(float(it["cx"]) - ss, float(it["cy"])))
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

# v98（用户："点击需要有一点反馈的音效"）：**按下**就响，不等抬手——
#   木牌/徽标给沉一点的音（pitch 0.92），纸牌/箭头/窄签给脆一点的（1.04），跟画面对得上。
func _click_sfx(idx: int) -> void:
	if idx < 0 or idx >= items.size():
		return
	var it: Dictionary = items[idx]
	if not bool(it["vis"]):
		return
	var wooden := (not bool(it["white"])) and (str(it["kind"]) != "arrow")
	Audio.sfx("ui_click", -11.0, randf_range(0.90, 0.95) if wooden else randf_range(1.02, 1.08))

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
	var hb := get_node_or_null(NodePath("hit_" + id))
	if hb != null:
		(hb as Control).tooltip_text = s
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

# v211：功能栏自动补位——隐藏的格子不再留洞，下面的整体往上顶
#   右栏走 tcy 缓动（见 _tick_anim），不会"啪"一下跳位。
func set_ry(id: String, ry: float) -> void:
	var i := find_i(id)
	if i < 0:
		return
	var it: Dictionary = items[i]
	it["tcy"] = ry * DH
	if str(it["kind"]) == "rail":
		if float(it.get("el", -1.0)) < 0.0:
			it["cy"] = ry * DH          # 还没入场：直接到位，别让新格子从旧位置飞过来
		return
	it["cy"] = ry * DH
	_relayout(it)
	_place_hit(it)

# v211：按"当前可见的格子"重排右栏——等宽、等距、从上往下
func layout_rail(ids: Array, top: float, h: float, gap: float) -> void:
	var vis_ids: Array = []
	for id in ids:
		var i := find_i(str(id))
		if i >= 0 and bool((items[i] as Dictionary)["vis"]):
			vis_ids.append(str(id))
	var n := vis_ids.size()
	if n == 0:
		return
	for k in n:
		set_ry(vis_ids[k], (top + h * 0.5 + float(k) * (h + gap)) / DH)

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
	# v211：顶栏贯通（0~96 一条墨带）+ 右栏底板（长度按可见格子算）
	if Ui.SKIN == 1:
		_n_topbar()
		_n_railback()
	for i in items.size():
		var it: Dictionary = items[i]
		it["idx"] = i
		if not bool(it["vis"]):
			continue
		var s := slide if str(it["page"]) == "village" else 0.0
		if s > DW + 120.0 or s < -(DW + 120.0):
			continue                        # 整页滑出屏幕了，省点力气
		if Ui.SKIN == 1:
			match str(it["kind"]):
				"beam":
					_n_beam(it)
				"hang":
					_n_hang(it, s)
				"shop", "icon":
					_n_icon(it, s)
				"ribbon":
					_n_ribbon(it, s)
				"slip":
					_n_slip(it, s)
				"disc":
					_n_disc(it, s)
				"txt":
					_n_txt(it, s)
				"arrow":
					_n_arrow(it, s)
				"rail":
					_n_rail(it, s)
				"stele":
					_n_stele(it, s)
				"chip":
					_n_chip(it, s)
		else:
			match str(it["kind"]):
				"beam":
					_draw_beam(it)
				"hang":
					_draw_hang(it, s)
				"shop", "icon":
					_draw_icon(it, s)
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
	# v200：涟漪画在最上层
	for rp in _ripples:
		var k := clampf(float(rp["t"]) / 0.55, 0.0, 1.0)
		var rad := 10.0 + 64.0 * (1.0 - pow(1.0 - k, 2.2))
		var a := (1.0 - k) * (1.0 - k)
		draw_arc(rp["p"], rad, 0.0, TAU, 44,
			Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, a * 0.55), 1.4 + 2.0 * a, true)

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

# v116（用户："可"——采纳"别的牌子也换成素材"）：**图标牌**——纸卡＋一张素材图＋两行字。
#   商店/藏宝阁/百工坊共用这一个（贴图走 cfg 传进来，see add_icon）。
func add_icon(id: String, rx: float, ry: float, text: String, tex: Texture2D, fn: Callable, sub := "", cfg := {}) -> void:
	var c := cfg.duplicate()
	c["tex"] = tex
	_push(id, "icon", rx, ry, 116.0, 128.0, text, fn, sub, "", c)

# v115b（用户："商店不是有素材ui吗？换成素材"）：**用素材**——从集市图集里抠出的茶摊（assets/ui/shop_stall.png）。
#   素材自带白底，所以垫一张**纸卡**（把白底一起吃掉）＋墨边，字写在卡片下沿。
#   笔法与出村箭头同一套：白面 ＋ 墨边 ＋ 落影；悬停/按下时边线转朱红。
func _draw_icon(it: Dictionary, s: float) -> void:
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var down: bool = _down == int(it["idx"])
	var paper := Color(0.985, 0.975, 0.95, 0.97)
	var edge := Color(0.20, 0.18, 0.21, 0.88)
	if _hover == int(it["idx"]):
		edge = Color(SEAL.r, SEAL.g, SEAL.b, 0.95)
	if down:
		paper = Color(0.95, 0.93, 0.89, 1.0)
		edge = Color(SEAL.r, SEAL.g, SEAL.b, 1.0)
	var W := 108.0
	var H := 128.0
	var y0 := cy - H * 0.5 + (2.0 if down else 0.0)
	# ① 纸卡（素材的白底就吃在这张卡里）
	var card := Rect2(cx - W * 0.5, y0, W, H)
	if not down:
		draw_colored_polygon(Draw.round_poly(Rect2(card.position + Vector2(2.5, 4.0), card.size), 10.0), Color(0.06, 0.05, 0.05, 0.18))
	draw_colored_polygon(Draw.round_poly(card, 10.0), paper)
	var bp := Draw.round_poly(card, 10.0)
	bp.append(bp[0])
	draw_polyline(bp, edge, 2.2, true)
	# ② 素材：按比例缩进卡片里（下面留一行写字）
	var tex: Texture2D = SHOP_TEX
	if it.get("tex", null) != null:
		tex = it["tex"]
	# ③ 文字块：副题**可能是多行**（后山/百工坊的副题带 \n）——先分行量好，再往上给素材留地方。
	#    v119：原来是把整个 sub 丢给一次 draw_string（不认换行 → 全挤一行），而且**画了两遍**
	#    （卡片里一遍、卡片外 cy+58 又一遍，老商店代码的残留）→ 就是用户说的"字数重合"。
	var sub := str(it["sub"])
	var lines: Array = []
	if sub != "":
		for ln in sub.split("\n"):
			lines.append(str(ln))
	var n := lines.size()
	var lh := 14.0
	var title_y := y0 + H - 10.0 - float(n) * lh
	var th := maxf(24.0, (title_y - 22.0) - (y0 + 5.0))
	var tw := th * float(tex.get_width()) / maxf(1.0, float(tex.get_height()))
	if tw > W - 12.0:
		tw = W - 12.0
		th = tw * float(tex.get_height()) / maxf(1.0, float(tex.get_width()))
	draw_texture_rect(tex, Rect2(cx - tw * 0.5, y0 + 5.0, tw, th), false)
	draw_string(font, Vector2(cx - W * 0.5, title_y), str(it["text"]), HORIZONTAL_ALIGNMENT_CENTER, W, 17, Color(INK.r, INK.g, INK.b, 0.92))
	for i in n:
		draw_string(font, Vector2(cx - W * 0.5, title_y + 18.0 + float(i) * lh), str(lines[i]),
			HORIZONTAL_ALIGNMENT_CENTER, W, 12, Color(INK.r, INK.g, INK.b, 0.62))

# 六边形徽标（v115 起商店不用它了；留着——以后要别的徽标还能用）
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
	# v123（用户："称号…炫酷一点 整体头像框+名字+称号可以再放大一些 头像框可以不用放大了"）：
	#   名号 27 → **34**；称号从"一行灰小字"改成**描金墨牌**（斜切角 + 金线 + 金字）。头像框没动。
	draw_string(font, Vector2(cx - w * 0.5, cy + 12.0), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 34, Color(0.12, 0.11, 0.13, 0.94))
	var sub := str(it["sub"])
	if sub != "":
		var tw := maxf(104.0, float(sub.length()) * 20.0 + 36.0)
		var th := 32.0
		var tx := cx - tw * 0.5
		var ty := cy + 22.0
		var cut := 10.0
		var plate := PackedVector2Array([Vector2(tx + cut, ty), Vector2(tx + tw - cut, ty),
			Vector2(tx + tw, ty + th * 0.5), Vector2(tx + tw - cut, ty + th),
			Vector2(tx + cut, ty + th), Vector2(tx, ty + th * 0.5)])
		draw_colored_polygon(plate, Color(0.16, 0.14, 0.17, 0.92))
		var po := PackedVector2Array(plate)
		po.append(plate[0])
		draw_polyline(po, Color(0.84, 0.70, 0.34, 0.95), 1.8, true)
		draw_string(font, Vector2(tx, ty + th * 0.5 + 8.0), sub, HORIZONTAL_ALIGNMENT_CENTER, tw, 19, Color(0.98, 0.90, 0.66, 0.98))

# v115b：商店那张素材（集市图集里抠出的茶摊；见 assets/ui/shop_stall.png）
const SHOP_TEX := preload("res://assets/ui/shop_stall.png")
const TREASURE_TEX := preload("res://assets/ui/treasure_shelf.png")   # v116：藏宝阁（酒坛架）
const CRAFT_TEX := preload("res://assets/ui/craft_bench.png")         # v116：百工坊（晾布架＋案几＋火盆）
const HILL_TEX := preload("res://assets/ui/hill_rock.png")            # v118：后山（崖石）
const CAVE_TEX := preload("res://assets/ui/cave_mouth.png")           # v118：山洞（冰窟首帧）
# v211：右栏五格的金色刻线图标（从原素材转的"金线版"，见 .shots/_icons_tmp.py）
const RAIL_SHOP_TEX := preload("res://assets/ui/rail_shop.png")
const RAIL_BEAST_TEX := preload("res://assets/ui/rail_beast.png")
const RAIL_CAVE_TEX := preload("res://assets/ui/rail_cave.png")
const RAIL_TREASURE_TEX := preload("res://assets/ui/rail_treasure.png")
const RAIL_CRAFT_TEX := preload("res://assets/ui/rail_craft.png")
const JIAN_TEX := preload("res://assets/ui/char_jian.png")             # 历练大碑上的金色"剑"字水印

# 箭头（出村）——v102（用户："改成白色再大一点 字体也一点 放在箭头里面更显目一些"）：
#   **白底墨边的实心箭头**，字写在箭杆里（比原来"墨线箭头＋底下一行小字"醒目得多）。
func _draw_arrow(it: Dictionary, s: float) -> void:
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var d := float(it["dir"])          # -1 向左 / 1 向右
	var L := 120.0                     # 总长
	var HH := 31.0                     # 箭头半高
	var SH := 16.0                     # 箭杆半高
	var HEAD := 48.0                   # 箭头那一段的长度
	var tip := cx + d * L * 0.5
	var tail := cx - d * L * 0.5
	var neck := tip - d * HEAD
	var pts := PackedVector2Array([
		Vector2(tip, cy),
		Vector2(neck, cy - HH),
		Vector2(neck, cy - SH),
		Vector2(tail, cy - SH),
		Vector2(tail, cy + SH),
		Vector2(neck, cy + SH),
		Vector2(neck, cy + HH),
	])
	var fill := Color(0.99, 0.982, 0.955, 0.97)
	var edge := Color(0.20, 0.18, 0.21, 0.88)
	if _hover == int(it["idx"]):
		fill = Color(1.0, 0.995, 0.97, 1.0)
		edge = Color(SEAL.r, SEAL.g, SEAL.b, 0.95)
	if _down == int(it["idx"]):
		fill = Color(0.95, 0.93, 0.89, 1.0)
		edge = Color(SEAL.r, SEAL.g, SEAL.b, 1.0)
	# 落影 → 白面 → 墨边
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(2.5, 4.0))
	draw_colored_polygon(sh, Color(0.06, 0.05, 0.05, 0.20))
	draw_colored_polygon(pts, fill)
	var outline := PackedVector2Array(pts)
	outline.append(outline[0])
	draw_polyline(outline, edge, 2.4, true)
	# 字写在箭杆里
	var txt := str(it["text"])
	if txt != "":
		var sx := minf(neck, tail)
		var sw := absf(tail - neck)
		draw_string(font, Vector2(sx, cy + 9.0), txt, HORIZONTAL_ALIGNMENT_CENTER, sw, 22, Color(INK.r, INK.g, INK.b, 0.92))

# ============================================================
# v200 · 影之刃皮肤（玄墨鎏金）
#   一张板＝切角 + 金线 + 四角 L 标；字＝毛笔金；强调只剩朱砂。
#   所有 _n_* 都读 it["hv"] / it["dn"]（缓动值，见 _tick_anim）。
# ============================================================

func _n_font() -> Font:
	return _brush if _brush != null else font

# 板面：底 → 悬停提亮 → 按下加深
func _n_fill(it: Dictionary) -> Color:
	var hv := clampf(float(it.get("hv", 0.0)), 0.0, 1.0)
	var dn := clampf(float(it.get("dn", 0.0)), 0.0, 1.0)
	var c := Ui.lerp_c(Ui.INK0, Ui.INK2, hv * 0.85)
	return Ui.lerp_c(c, Ui.INK3, dn * 0.7)

func _n_edge(it: Dictionary) -> Color:
	var hv := clampf(float(it.get("hv", 0.0)), 0.0, 1.0)
	var dn := clampf(float(it.get("dn", 0.0)), 0.0, 1.0)
	var c := Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.50 + 0.34 * hv)
	return Ui.lerp_c(c, Color(Ui.CINN_HI.r, Ui.CINN_HI.g, Ui.CINN_HI.b, 0.95), dn * 0.75)

# 横梁：一根铁梁，上下各一线金，钉子改成金菱
func _n_beam(it: Dictionary) -> void:
	var x0 := float(it["x0"])
	var x1 := float(it["x1"])
	var y := float(it["cy"])
	var w := x1 - x0
	draw_rect(Rect2(x0, y, w, 7.0), Color(0.055, 0.050, 0.065, 0.62))
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.72), 1.4, true)
	draw_line(Vector2(x0, y + 7.0), Vector2(x1, y + 7.0), Color(Ui.GOLD_DK.r, Ui.GOLD_DK.g, Ui.GOLD_DK.b, 0.62), 1.0, true)
	for nx in (it["nails"] as Array):
		Ui.diamond(self, Vector2(float(nx), y + 3.0), 3.4, Ui.GOLD_HI, 1.2)

# 悬挂牌：吊绳 + 墨牌 + 竖排毛笔金
func _n_hang(it: Dictionary, s: float) -> void:
	var hv := clampf(float(it.get("hv", 0.0)), 0.0, 1.0)
	var dn := clampf(float(it.get("dn", 0.0)), -0.4, 1.6)
	var w := float(it["w"])
	var h := float(it["h"])
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"]) - 1.8 * hv + 2.4 * dn
	var x := cx - w * 0.5
	var y := cy - h * 0.5
	var peg := Vector2(cx, y - ROPE)
	var rope_c := Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.40 + 0.30 * hv)
	draw_line(peg, Vector2(x + w * 0.30, y + 9.0), rope_c, 1.2, true)
	draw_line(peg, Vector2(x + w * 0.70, y + 9.0), rope_c, 1.2, true)
	Ui.diamond(self, peg, 3.4, Ui.GOLD_HI, 1.2)
	Ui.panel(self, Rect2(x, y, w, h), {"fill": _n_fill(it), "edge": _n_edge(it), "glow": hv, "cut": 8.0})
	draw_line(Vector2(x + 10.0, y + 15.0), Vector2(x + w - 10.0, y + 15.0),
		Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.20 + 0.12 * hv), 1.0, true)
	var f := _n_font()
	var fs := 22
	var txt := str(it["text"])
	var ty := y + 20.0 + float(fs)
	for i in txt.length():
		Ui.gold_text(self, f, Vector2(x, ty), txt.substr(i, 1), fs, HORIZONTAL_ALIGNMENT_CENTER, w, Ui.GOLD_HI, 2)
		ty += float(fs) + 3.0
	# 底部：动作字压在最下（朱砂），副题往上一行行排——v200 修掉原来 act/sub 叠字
	var act := str(it["act"])
	var sub := str(it["sub"])
	var lines: PackedStringArray = sub.split("\n") if sub != "" else PackedStringArray()
	var base_y := y + h - 14.0
	if act != "":
		Ui.gold_text(self, f, Vector2(x, base_y), act, 15, HORIZONTAL_ALIGNMENT_CENTER, w, Ui.CINN_HI, 2)
		base_y -= 20.0
	for i in lines.size():
		var sy2 := base_y - float(lines.size() - 1 - i) * 15.0
		draw_string(font, Vector2(x, sy2), str(lines[i]), HORIZONTAL_ALIGNMENT_CENTER, w, 12,
			Color(Ui.TXT_DIM.r, Ui.TXT_DIM.g, Ui.TXT_DIM.b, 0.92))

# 窄签（进阶）
func _n_slip(it: Dictionary, s: float) -> void:
	var w := float(it["w"])
	var h := float(it["h"])
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var r := Rect2(cx - w * 0.5, cy - h * 0.5, w, h)
	Ui.panel(self, r, {"fill": _n_fill(it), "edge": _n_edge(it),
		"glow": clampf(float(it.get("hv", 0.0)), 0.0, 1.0), "cut": 6.0})
	var f := _n_font()
	var txt := str(it["text"])
	var fs := 19
	var ty := r.position.y + 15.0 + float(fs)
	for i in txt.length():
		Ui.gold_text(self, f, Vector2(r.position.x, ty), txt.substr(i, 1), fs, HORIZONTAL_ALIGNMENT_CENTER, w, Ui.GOLD_HI, 2)
		ty += float(fs) + 8.0

# 右上角斜挂小牌（设置）
func _n_ribbon(it: Dictionary, s: float) -> void:
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var w := float(it["w"])
	var h := float(it["h"])
	var hv := clampf(float(it.get("hv", 0.0)), 0.0, 1.0)
	var rc := Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.38)
	draw_line(Vector2(cx + 16.0, cy - h * 0.5 - 20.0), Vector2(cx - w * 0.26, cy - h * 0.5 + 4.0), rc, 1.0, true)
	draw_line(Vector2(cx + 16.0, cy - h * 0.5 - 20.0), Vector2(cx + w * 0.26, cy - h * 0.5 + 4.0), rc, 1.0, true)
	draw_set_transform(Vector2(cx, cy), -0.30, Vector2.ONE)
	var r := Rect2(-w * 0.5, -h * 0.5, w, h)
	Ui.panel(self, r, {"fill": _n_fill(it), "edge": _n_edge(it), "glow": hv, "cut": 6.0, "bracket": false})
	Ui.gold_text(self, _n_font(), Vector2(r.position.x, r.position.y + h * 0.5 + 6.0), str(it["text"]), 17,
		HORIZONTAL_ALIGNMENT_CENTER, w, Ui.GOLD_HI, 2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# 圆形头像：墨底 + 双金环 + 四枚刻点
func _n_disc(it: Dictionary, s: float) -> void:
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var r := float(it["w"]) * 0.5
	var hv := clampf(float(it.get("hv", 0.0)), 0.0, 1.0)
	draw_circle(Vector2(cx + 1.5, cy + 3.5), r, Color(0.02, 0.02, 0.03, 0.45))
	draw_circle(Vector2(cx, cy), r, Ui.INK0)
	var tex: Texture2D = CharArt.q_head("player")
	if tex != null:
		var tw := tex.get_width()
		var th := tex.get_height()
		var k: float = (r * 1.62) / maxf(1.0, float(maxi(tw, th)))
		var dw := float(tw) * k
		var dh := float(th) * k
		draw_texture_rect(tex, Rect2(cx - dw * 0.5, cy - dh * 0.5 + r * 0.08, dw, dh), false)
	else:
		Ui.gold_text(self, _n_font(), Vector2(cx - r, cy + 11.0), "侠", 32,
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, Ui.GOLD_HI, 3)
	Ui.ring(self, Vector2(cx, cy), r, Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.60 + 0.32 * hv), 2.0)
	Ui.ring(self, Vector2(cx, cy), r - 5.0, Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.16 + 0.38 * hv), 1.0)
	for i in 4:
		var a := -PI * 0.5 + float(i) * PI * 0.5
		Ui.diamond(self, Vector2(cx + cos(a) * r, cy + sin(a) * r), 3.2, Ui.GOLD_HI, 1.0)

# 图标牌（商店）：墨卡 + 浅绢画心（把素材白底吃成留白）+ 金字
func _n_icon(it: Dictionary, s: float) -> void:
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var W := 112.0
	var H := 132.0
	var hv := clampf(float(it.get("hv", 0.0)), 0.0, 1.0)
	var dn := clampf(float(it.get("dn", 0.0)), -0.4, 1.6)
	var y0 := cy - H * 0.5 + 2.2 * dn - 1.6 * hv
	var card := Rect2(cx - W * 0.5, y0, W, H)
	Ui.panel(self, card, {"fill": _n_fill(it), "edge": _n_edge(it), "glow": hv, "cut": 9.0})
	var inner := Rect2(card.position.x + 9.0, card.position.y + 9.0, W - 18.0, H - 46.0)
	draw_colored_polygon(Ui.cut_poly(inner, 4.0), Color(0.925, 0.906, 0.855, 0.94))
	var tex: Texture2D = SHOP_TEX
	if it.get("tex", null) != null:
		tex = it["tex"]
	if tex != null:
		var th := inner.size.y - 6.0
		var tw := th * float(tex.get_width()) / maxf(1.0, float(tex.get_height()))
		if tw > inner.size.x - 6.0:
			tw = inner.size.x - 6.0
			th = tw * float(tex.get_height()) / maxf(1.0, float(tex.get_width()))
		draw_texture_rect(tex, Rect2(inner.get_center().x - tw * 0.5, inner.get_center().y - th * 0.5, tw, th), false)
	var sub := str(it["sub"])
	var lines: Array = []
	if sub != "":
		for ln in sub.split("\n"):
			lines.append(str(ln))
	Ui.gold_text(self, _n_font(), Vector2(card.position.x, card.position.y + H - 30.0), str(it["text"]), 20,
		HORIZONTAL_ALIGNMENT_CENTER, W, Ui.GOLD_HI, 2)
	var li := 0
	for ln in lines:
		draw_string(font, Vector2(card.position.x, card.position.y + H - 12.0 + float(li) * 13.0), str(ln),
			HORIZONTAL_ALIGNMENT_CENTER, W, 11, Color(Ui.TXT_DIM.r, Ui.TXT_DIM.g, Ui.TXT_DIM.b, 0.92))
		li += 1

# v211：顶栏·名号（左对齐）+ 境界牌——整条 0~96 的墨带上排，不再居中飘在画面里
func _n_txt(it: Dictionary, s: float) -> void:
	var hv := clampf(float(it.get("hv", 0.0)), 0.0, 1.0)
	var f := _n_font()
	var txt := str(it["text"])
	var x0 := 112.0
	var fs := 30
	if txt.length() == 4:
		fs = 26
	elif txt.length() >= 5:
		fs = 21
	# 悬停：字后透一层暖光（顶栏没有板，用光代替）
	if hv > 0.01:
		var gw := clampf(float(txt.length()) * float(fs) * 1.05, 70.0, 148.0)
		draw_rect(Rect2(x0 - 4.0, 16.0, gw, 40.0), Color(1.0, 0.86, 0.48, hv * 0.07))
	Ui.gold_text(self, f, Vector2(x0, 52.0), txt, fs, HORIZONTAL_ALIGNMENT_LEFT, 146.0, Ui.GOLD_HI, 3)
	if hv > 0.01:
		Ui.gold_text(self, f, Vector2(x0, 52.0), txt, fs, HORIZONTAL_ALIGNMENT_LEFT, 146.0,
			Color(1.0, 0.95, 0.74, hv * 0.35), 0)
	var sub := str(it["sub"])
	if sub != "":
		var tw := maxf(80.0, float(sub.length()) * 17.0 + 30.0)
		var r := Rect2(x0, 59.0, tw, 27.0)
		Ui.panel(self, r, {"fill": Color(0.10, 0.088, 0.098, 0.95),
			"edge": Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.62 + 0.25 * hv),
			"cut": 5.0, "bracket": false, "shadow": 0.45, "ink_halo": false, "glow": hv * 0.5})
		Ui.gold_text(self, f, Vector2(r.position.x, r.position.y + 19.0), sub, 16,
			HORIZONTAL_ALIGNMENT_CENTER, tw, Ui.GOLD_HI, 2)

# 出村箭头：墨底金边 + 金字
func _n_arrow(it: Dictionary, s: float) -> void:
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var d := float(it["dir"])
	var L := 122.0
	var HH := 31.0
	var SH := 16.0
	var HEAD := 48.0
	var tip := cx + d * L * 0.5
	var tail := cx - d * L * 0.5
	var neck := tip - d * HEAD
	var pts := PackedVector2Array([
		Vector2(tip, cy), Vector2(neck, cy - HH), Vector2(neck, cy - SH),
		Vector2(tail, cy - SH), Vector2(tail, cy + SH), Vector2(neck, cy + SH),
		Vector2(neck, cy + HH)])
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(2.0, 4.0))
	draw_colored_polygon(sh, Color(0.02, 0.02, 0.03, 0.35))
	draw_colored_polygon(pts, _n_fill(it))
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, _n_edge(it), 1.8, true)
	var txt := str(it["text"])
	if txt != "":
		var sx := minf(neck, tail)
		var sw := absf(tail - neck)
		Ui.gold_text(self, _n_font(), Vector2(sx, cy + 9.0), txt, 21, HORIZONTAL_ALIGNMENT_CENTER, sw, Ui.GOLD_HI, 2)

# ============================================================
# v211 · 主界面骨架：顶栏 / 右栏 / 历练大碑
# ============================================================

# 回弹缓动（牌子落下时略微过冲）
func _back(k: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var x := clampf(k, 0.0, 1.0) - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x

# 顶栏：0~96 一条贯通墨带（头像/名号/境界/进阶/银两/元宝/设置都排在上面）
func _n_topbar() -> void:
	var w := DW
	var h := TOPBAR_H
	# 底：玄墨横带（上沿略提亮，像被光扫过）
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.035, 0.031, 0.034, 0.95))
	draw_rect(Rect2(0.0, 0.0, w, 34.0), Color(0.055, 0.048, 0.046, 0.55))
	# 底金线（2.5px）+ 上沿细亮线
	draw_rect(Rect2(0.0, h - 2.5, w, 2.5), Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.92))
	draw_line(Vector2(0.0, h - 7.5), Vector2(w, h - 7.5),
		Color(Ui.GOLD_DK.r, Ui.GOLD_DK.g, Ui.GOLD_DK.b, 0.55), 1.0)
	draw_line(Vector2(0.0, 1.0), Vector2(w, 1.0),
		Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.16), 1.0)
	# 左端朱砂"起笔"
	draw_rect(Rect2(8.0, 26.0, 3.0, 44.0), Color(Ui.CINN.r, Ui.CINN.g, Ui.CINN.b, 0.90))
	# 四角 L 标（影之刃的那口气）
	Ui.brackets(self, Rect2(5.0, 4.0, w - 10.0, h - 9.0), 9.0,
		Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.55), 12.0, 1.5)
	# 墨带暗纹：三条极淡的横向金线，避免纯色块
	for k in 3:
		var yy := 24.0 + float(k) * 22.0
		draw_line(Vector2(104.0, yy), Vector2(w - 120.0, yy),
			Color(1.0, 0.92, 0.72, 0.022), 1.0)
	# 名号 ↔ 银两 之间：一道朱砂菱形分界
	draw_line(Vector2(333.0, 22.0), Vector2(333.0, 74.0),
		Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.28), 1.0)
	Ui.diamond(self, Vector2(333.0, 48.0), 3.4,
		Color(Ui.CINN_HI.r, Ui.CINN_HI.g, Ui.CINN_HI.b, 0.85), 1.2)

# 右栏底板：长度按"当前可见的格子"算（自动补位后不留空洞）
func _n_railback() -> void:
	var y_top := 1.0e9
	var y_bot := -1.0e9
	var cx := 0.0
	var n := 0
	for id in RAIL_IDS:
		var i := find_i(str(id))
		if i < 0:
			continue
		var it: Dictionary = items[i]
		if not bool(it["vis"]):
			continue
		y_top = minf(y_top, float(it["cy"]) - float(it["h"]) * 0.5)
		y_bot = maxf(y_bot, float(it["cy"]) + float(it["h"]) * 0.5)
		cx = float(it["cx"])
		n += 1
	if n == 0:
		return
	var rr := Rect2(cx - RAIL_W * 0.5 - 10.0, y_top - 18.0, RAIL_W + 20.0, (y_bot - y_top) + 36.0)
	var rp := Ui.cut_poly(rr, 14.0)
	draw_colored_polygon(rp, Color(0.030, 0.026, 0.022, 0.46))
	var rq := PackedVector2Array(rp)
	rq.append(rp[0])
	draw_polyline(rq, Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.20), 1.0, true)
	draw_line(Vector2(rr.position.x + 16.0, rr.position.y + 4.0),
		Vector2(rr.end.x - 16.0, rr.position.y + 4.0),
		Color(Ui.CINN.r, Ui.CINN.g, Ui.CINN.b, 0.75), 2.0, true)

# 顶栏小牌（进阶 / 设置）
func _n_chip(it: Dictionary, s: float) -> void:
	var hv := clampf(float(it.get("hv", 0.0)), 0.0, 1.0)
	var dn := clampf(float(it.get("dn", 0.0)), -0.4, 1.6)
	var w := float(it["w"])
	var h := float(it["h"])
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"]) - 1.6 * hv + 2.4 * dn
	var r := Rect2(cx - w * 0.5, cy - h * 0.5, w, h)
	Ui.panel(self, r, {"fill": _n_fill(it), "edge": _n_edge(it), "glow": hv,
		"cut": 6.0, "bracket": false, "shadow": 0.7, "ink_halo": false})
	Ui.diamond(self, Vector2(r.position.x + 12.0, r.position.y + h * 0.5), 3.0,
		Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.55 + 0.35 * hv), 1.0)
	Ui.gold_text(self, _n_font(), Vector2(r.position.x, r.position.y + h * 0.5 + 6.0),
		str(it["text"]), 16, HORIZONTAL_ALIGNMENT_CENTER, w, Ui.GOLD_HI, 2)

# 右栏一格：icon 水印 + 大号毛笔字 + 小字名 + 动态副题
func _n_rail(it: Dictionary, s: float) -> void:
	var hv := clampf(float(it.get("hv", 0.0)), 0.0, 1.0)
	var dn := clampf(float(it.get("dn", 0.0)), -0.4, 1.6)
	var w := float(it["w"])
	var h := float(it["h"])
	var cx := float(it["cx"]) - s
	var el := float(it.get("el", -1.0))
	var k := 1.0
	if el >= 0.0:
		var delay := float(it.get("seq", 0)) * 0.075
		k = _back(clampf((el - 0.10 - delay) / 0.42, 0.0, 1.0))
	var cy := float(it["cy"]) - (1.0 - k) * 76.0 - 1.8 * hv + 2.4 * dn
	var r := Rect2(cx - w * 0.5, cy - h * 0.5, w, h)
	# 悬停：板外一圈暖光
	if hv > 0.02:
		for g in 2:
			var d := 3.0 + float(g) * 4.0
			draw_colored_polygon(Ui.cut_poly(r.grow(d), 12.0 + d),
				Color(1.0, 0.82, 0.42, (0.055 - 0.02 * float(g)) * hv))
	Ui.panel(self, r, {"fill": _n_fill(it), "edge": _n_edge(it), "glow": hv,
		"cut": 10.0, "bracket": true, "shadow": 1.0})
	var inner := Rect2(r.position + Vector2(5.0, 5.0), r.size - Vector2(10.0, 10.0))
	var ip := Ui.cut_poly(inner, 6.0)
	ip.append(ip[0])
	draw_polyline(ip, Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.18 + 0.30 * hv), 1.0, true)
	Ui.diamond(self, Vector2(cx, r.position.y + 2.0), 4.0,
		Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.75 + 0.25 * hv), 1.2)
	# 图标水印（金色刻线）
	var tex: Texture2D = it.get("tex", null)
	if tex != null:
		var sz := 44.0
		draw_texture_rect(tex, Rect2(cx - sz * 0.5, r.position.y + 10.0, sz, sz), false,
			Color(1.0, 1.0, 1.0, 0.34 + 0.22 * hv))
	var f := _n_font()
	var big := str(it["big"])
	if big == "":
		big = str(it["text"]).substr(0, 1)
	Ui.gold_text(self, f, Vector2(r.position.x, r.position.y + 108.0), big, 46,
		HORIZONTAL_ALIGNMENT_CENTER, w, Ui.GOLD_HI, 3)
	var label := str(it["label"])
	if label == "":
		label = str(it["text"])
	draw_string(font, Vector2(r.position.x, r.position.y + 128.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(Ui.TXT.r, Ui.TXT.g, Ui.TXT.b, 0.80))
	var sub := str(it["sub"])
	if sub != "":
		var lines: PackedStringArray = sub.split("\n")
		var li := 0
		for ln in lines:
			if li >= 2:
				break
			draw_string(font, Vector2(r.position.x + 4.0, r.position.y + 146.0 + float(li) * 12.0),
				str(ln), HORIZONTAL_ALIGNMENT_CENTER, w - 8.0, 10,
				Color(Ui.TXT_DIM.r, Ui.TXT_DIM.g, Ui.TXT_DIM.b, 0.78))
			li += 1

# 中央朱砂大碑（历练）：呼吸微光 + 金框角标 + 金色书法水印 + 斜扫光
func _n_stele(it: Dictionary, s: float) -> void:
	var cx := float(it["cx"]) - s
	var cy := float(it["cy"])
	var w := float(it["w"])
	var h := float(it["h"])
	var hv := clampf(float(it.get("hv", 0.0)), 0.0, 1.0)
	var dn := clampf(float(it.get("dn", 0.0)), -0.4, 1.6)
	var el := float(it.get("el", -1.0))
	var k := 0.0
	if el >= 0.0:
		k = _back(clampf(el / 0.45, 0.0, 1.0))
	var sc := 0.965 + 0.035 * k
	draw_set_transform(Vector2(cx, cy + 2.4 * dn - 1.4 * hv), 0.0, Vector2(sc, sc))
	var r := Rect2(-w * 0.5, -h * 0.5, w, h)
	var breath := 0.5 + 0.5 * sin(t * 2.4)
	# 外扩朱砂光（2.4 秒一轮）
	for g in 3:
		var d := 2.0 + float(g) * 4.0
		draw_colored_polygon(Ui.cut_poly(r.grow(d), 14.0 + d * 0.8),
			Color(0.78, 0.14, 0.09, (0.085 - 0.022 * float(g)) * (0.55 + 0.45 * breath)))
	var shp := Ui.cut_poly(Rect2(r.position + Vector2(0.0, 6.0), r.size), 12.0)
	draw_colored_polygon(shp, Color(0.02, 0.01, 0.01, 0.42))
	# 板面三明治：底朱 → 上半提亮 → 下半压暗（切角都保住）
	draw_colored_polygon(Ui.cut_poly(r, 12.0), Color(0.58, 0.115, 0.088, 0.985))
	var c := 12.0
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	var top_pts := PackedVector2Array([
		Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c),
		Vector2(x1, y0 + h * 0.46), Vector2(x0, y0 + h * 0.46), Vector2(x0, y0 + c)])
	draw_colored_polygon(top_pts, Color(0.80, 0.22, 0.15, 0.55))
	var bot_pts := PackedVector2Array([
		Vector2(x0, y0 + h * 0.52), Vector2(x1, y0 + h * 0.52),
		Vector2(x1, y1 - c), Vector2(x1 - c, y1), Vector2(x0 + c, y1), Vector2(x0, y1 - c)])
	draw_colored_polygon(bot_pts, Color(0.26, 0.035, 0.028, 0.55))
	draw_line(Vector2(x0 + c + 6.0, y0 + 3.0), Vector2(x1 - c - 6.0, y0 + 3.0),
		Color(1.0, 0.84, 0.52, 0.20 + 0.12 * breath), 1.4, true)
	var op := Ui.cut_poly(r, c)
	op.append(op[0])
	draw_polyline(op, Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.85 + 0.15 * breath),
		2.4 + 0.4 * hv, true)
	var ir := Rect2(r.position + Vector2(6.0, 6.0), r.size - Vector2(12.0, 12.0))
	var ip := Ui.cut_poly(ir, 8.0)
	ip.append(ip[0])
	draw_polyline(ip, Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.30 + 0.18 * breath), 1.0, true)
	Ui.brackets(self, r, c, Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.92), 20.0, 2.0)
	if JIAN_TEX != null:
		draw_texture_rect(JIAN_TEX, Rect2(x1 - 150.0, y0 + 4.0, 132.0, 132.0), false,
			Color(1.0, 1.0, 1.0, 0.14 + 0.05 * breath + 0.10 * hv))
	# 斜扫光：像金字上过一道光
	var sx := fposmod(t * 90.0, w + 260.0) - 130.0 + x0
	var sheen := PackedVector2Array([
		Vector2(sx, y0 + 10.0), Vector2(sx + 44.0, y0 + 10.0),
		Vector2(sx + 10.0, y1 - 10.0), Vector2(sx - 34.0, y1 - 10.0)])
	draw_colored_polygon(sheen, Color(1.0, 0.88, 0.58, 0.05))
	var f := _n_font()
	Ui.gold_text(self, f, Vector2(x0 + 38.0, 22.0), str(it["text"]), 62,
		HORIZONTAL_ALIGNMENT_LEFT, w - 120.0, Ui.GOLD_HI, 4)
	draw_line(Vector2(x0 + 40.0, 36.0), Vector2(x0 + 232.0, 36.0),
		Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.30 + 0.15 * breath), 1.2, true)
	var sub := str(it["sub"])
	if sub != "":
		draw_string(font, Vector2(x0 + 40.0, 60.0), sub, HORIZONTAL_ALIGNMENT_LEFT, w - 150.0, 14,
			Color(0.99, 0.90, 0.72, 0.88))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

