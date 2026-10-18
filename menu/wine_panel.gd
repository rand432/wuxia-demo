extends Control
# ============================================================
# wine_panel.gd —— 品酒坊 v3（一桌五家 · 桌边斟酒版）
# v3（用户报的③）：**堵掉"酿→卖"无限刷银两**——面板这一层跟着两件事走：
#   ①估价行写清"生酒"（一口没品过＝只值四成半，卖不划算）；
#   ②酿一坛那颗钮带上**今日还剩几坛**，酿够了自己灰掉（数字与闸都在账本，见
#     game_state.WINE_BREW_LIMIT / wine_left_today）。
# v2 全窗重做：中间一张大桌，五位品酒师围坐（柳先生/闻婆/陈九爷/哑婆/铁头）。
#   选一坛酒 → 点某一位 → 桌上酒壶飞过去给他斟一杯（壶动/酒流/杯子见满）
#   → 他当场点评（话 + 星），星直接写回账本，卖价随星涨。
#   五家品定 → ［卖掉这坛］换银两；［酿一坛］花银两出新酒。
# 规则全在 shared/game_state.gd（TASTERS / wine_taste / wine_price / wine_brew / wine_sell），
#   本文件只负责"一间房、一张桌、五个人的戏"。
# 画法：全用 _draw 自绘（跟别的面板一个路子），只有文字/按钮是子节点。
# 注：几何数字是 var 不是 const（方便直接改，也躲开类型推断的坑）。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const SceneArt := preload("res://shared/scene_art.gd")   # v90：酒坛换成素材里的真图
const Ui := preload("res://menu/menu_theme.gd")          # v218：影之刃皮肤（与门厅/炼丹统一）

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const GOLD := Color(0.72, 0.58, 0.22)
const WINE_C := Color(0.66, 0.30, 0.16)

const PW := 672.0
const PH := 864.0
const POUR_DUR := 1.15
const SEAT_N := 5
const FOOT := "规矩：一家只品一口｜星越高，卖价越高｜五家品定再卖最划算（没品过的只算「生酒」，四成半价）｜每日限酿——银两不是从这儿无限刷的｜养灵丹是炼丹阁的事，别倒给客人"

const GUEST_COL := [
	Color(0.20, 0.19, 0.23, 0.90),   # 0 柳先生
	Color(0.28, 0.22, 0.21, 0.88),   # 1 闻婆
	Color(0.17, 0.22, 0.20, 0.90),   # 2 陈九爷
	Color(0.24, 0.21, 0.27, 0.88),   # 3 哑婆
	Color(0.19, 0.17, 0.15, 0.92),   # 4 铁头
]

signal closed

var _prect := Rect2()
var _tc := Vector2()        # 桌心（屏幕坐标）
var _rx := 168.0
var _ry := 92.0
var _seat_rx := 226.0
var _seat_ry := 146.0

var _t := 0.0
var _wi := 0
var _msg := ""
var _anim_seat := -1
var _anim_t := 0.0
var _anim_phase := 0        # 0=闲 1=斟酒中 2=已出评语
var _spark_t := 0.0
var _last_seat := -1
var _last_say := ""
var _last_stars := 0

var _silver_lb: Label
var _win_lb: Label
var _hint_lb: Label
var _note_lb: Label
var _price_lb: Label
var _msg_lb: Label
var _prev_btn: Button
var _next_btn: Button
var _brew_btn: Button
var _sell_btn: Button
var _name_lbs: Array = []
var _star_lbs: Array = []
var _seat_btns: Array = []
var _day_key := ""        # v39：上次画的时候是哪一天（按凌晨 4:00 换日）
var _day_t := 0.0         # 轮询计时

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_day_key = GameState.day_key()
	refresh()
	visible = get_parent() == get_tree().root

func _process(delta: float) -> void:
	if not visible:
		return
	# v39：每日限酿也按**凌晨 4:00** 换日——面板开着不动时自己重画（与货栈一个口径）
	_day_t += delta
	if _day_t >= 0.5:
		_day_t = 0.0
		var r: Array = GameState.day_tick(_day_key)
		if bool(r[0]):
			_day_key = str(r[1])
			print("[品酒坊] 换日（凌晨 4:00）：今日限酿已重置")
			refresh()
	_t += delta
	if _anim_phase == 1:
		_anim_t += delta
		if _anim_t >= POUR_DUR:
			_finish_pour()
	elif _anim_phase == 2:
		_spark_t += delta
	queue_redraw()

# ---- 几何 ----

func seat_of(i: int) -> Vector2:
	var a := deg_to_rad(-90.0 + 72.0 * float(i))
	return _tc + Vector2(cos(a) * _seat_rx, sin(a) * _seat_ry)

func cup_of(i: int) -> Vector2:
	var a := deg_to_rad(-90.0 + 72.0 * float(i))
	return _tc + Vector2(cos(a) * 120.0, sin(a) * 76.0)

func _label(text: String, font_size: int, col: Color) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", col)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lb

func _flat(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(3 if Ui.SKIN == 1 else 8)
	if Ui.SKIN == 1 and bg.a > 0.2:
		sb.border_color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.42)
		sb.set_border_width_all(1)
	return sb

func _style_dark(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.19, 0.20, 0.96)))
	btn.add_theme_stylebox_override("hover", _flat(Color(0.31, 0.27, 0.27, 0.96)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.11, 0.12, 0.96)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.40)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Ui.GOLD_HI if Ui.SKIN == 1 else Color(0.94, 0.91, 0.84))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.55))

func _style_seal(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.92)))
	btn.add_theme_stylebox_override("hover", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.80)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r * 0.75, SEAL.g * 0.75, SEAL.b * 0.75, 0.95)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.35)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.50))

func _style_seat(b: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0, 0, 0, 0)
	n.set_corner_radius_all(48)
	b.add_theme_stylebox_override("normal", n)
	var h: StyleBoxFlat = n.duplicate()
	h.bg_color = Color(1.0, 0.98, 0.90, 0.16)
	b.add_theme_stylebox_override("hover", h)
	var p: StyleBoxFlat = n.duplicate()
	p.bg_color = Color(1.0, 0.98, 0.90, 0.26)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", n)

func _mk_btn(txt: String, r: Rect2, fs: int, seal := false) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = r.position
	b.size = r.size
	b.add_theme_font_size_override("font_size", fs)
	b.focus_mode = Control.FOCUS_NONE
	if seal:
		_style_seal(b)
	else:
		_style_dark(b)
	return b

func _build() -> void:
	var vp := get_viewport_rect().size
	_prect = Rect2((vp.x - PW) * 0.5, (vp.y - PH) * 0.5, PW, PH)
	_tc = Vector2(_prect.position.x + PW * 0.5, _prect.position.y + 400.0)
	var px := _prect.position.x
	var py := _prect.position.y

	var title := _label("品酒坊", 30, INK)
	title.position = Vector2(px + 28.0, py + 14.0)
	title.size = Vector2(240, 44)
	if Ui.SKIN == 1:
		# 纸面上的"金字"＝墨字描金边（亮金直接写宣纸上会糊）
		title.add_theme_font_size_override("font_size", 34)
		var bf := Ui.brush_font()
		if bf != null:
			title.add_theme_font_override("font", bf)
		title.add_theme_color_override("font_color", INK)
		title.add_theme_color_override("font_outline_color", Ui.GOLD)
		title.add_theme_constant_override("outline_size", 2)
	add_child(title)

	_silver_lb = _label("", 16, SEAL if Ui.SKIN != 1 else Color(0.62, 0.44, 0.08))
	_silver_lb.position = Vector2(px + PW - 232.0, py + 26.0)
	_silver_lb.size = Vector2(204, 28)
	_silver_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_silver_lb)

	# 选酒条
	# v61（手游）：44 → 48 高（选酒条左右两颗）
	_prev_btn = _mk_btn("‹", Rect2(px + 28.0, py + 60.0, 56.0, 48.0), 24)
	_prev_btn.pressed.connect(_on_prev)
	add_child(_prev_btn)
	_next_btn = _mk_btn("›", Rect2(px + PW - 84.0, py + 60.0, 56.0, 48.0), 24)
	_next_btn.pressed.connect(_on_next)
	add_child(_next_btn)
	_win_lb = _label("", 18, INK)
	_win_lb.position = Vector2(px + 90.0, py + 68.0)
	_win_lb.size = Vector2(PW - 180.0, 32.0)
	_win_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_win_lb)

	_hint_lb = _label("", 13, Color(INK.r, INK.g, INK.b, 0.60))   # v61（手游）：12 → 13 号
	_hint_lb.position = Vector2(px + 28.0, py + 112.0)
	_hint_lb.size = Vector2(PW - 56.0, 26.0)
	_hint_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint_lb)

	# 五个座位：先放隐形按钮（接点击），再放名牌/星（不会被挡）
	_name_lbs = []
	_star_lbs = []
	_seat_btns = []
	for i in SEAT_N:
		var seat := seat_of(i)
		var b := Button.new()
		b.position = seat - Vector2(48.0, 48.0)
		b.size = Vector2(96.0, 96.0)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_seat(b)
		b.pressed.connect(_on_seat.bind(i))
		add_child(b)
		_seat_btns.append(b)
		var d := (seat - _tc).normalized()
		var lp := seat + d * 34.0
		var nl := _label("", 16, INK)
		nl.position = Vector2(lp.x - 60.0, lp.y - 12.0)
		nl.size = Vector2(120.0, 22.0)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(nl)
		_name_lbs.append(nl)
		var sl := _label("", 13, GOLD)
		sl.position = Vector2(lp.x - 60.0, lp.y + 8.0)
		sl.size = Vector2(120.0, 20.0)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(sl)
		_star_lbs.append(sl)

	_note_lb = _label("", 16, INK)
	_note_lb.position = Vector2(px + 46.0, py + 592.0)
	_note_lb.size = Vector2(PW - 92.0, 48.0)
	_note_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_note_lb)

	_price_lb = _label("", 14, Color(SEAL.r, SEAL.g, SEAL.b, 0.92))
	_price_lb.position = Vector2(px + 28.0, py + 646.0)
	_price_lb.size = Vector2(PW - 56.0, 24.0)
	_price_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_price_lb)

	_brew_btn = _mk_btn("酿一坛", Rect2(px + 40.0, py + 676.0, 180.0, 56.0), 18, true)
	_brew_btn.pressed.connect(_on_brew)
	add_child(_brew_btn)
	_sell_btn = _mk_btn("卖掉这坛", Rect2(px + 240.0, py + 676.0, 200.0, 56.0), 18, true)
	_sell_btn.pressed.connect(_on_sell)
	add_child(_sell_btn)
	var close_btn := _mk_btn("关闭", Rect2(px + 460.0, py + 676.0, 172.0, 56.0), 20)
	close_btn.pressed.connect(close)
	add_child(close_btn)

	# v218：规矩那行原来是一整句、中文又没空格，Label 的最小宽度把右半截顶出面板。
	#   直接在 "｜" 处显式断行（5 行，每行都短），比跟 Label 的最小尺寸较劲可靠。
	_msg_lb = _label(FOOT.replace("｜", "\n"), 13, Color(INK.r, INK.g, INK.b, 0.55))
	_msg_lb.position = Vector2(px + 28.0, py + 748.0)
	_msg_lb.size = Vector2(PW - 56.0, 96.0)
	_msg_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_msg_lb)

# ---- 状态 ----

func _star_text(n: int) -> String:
	var k := clampi(n, 0, 5)
	return "★".repeat(k) + "☆".repeat(5 - k)

func _stars_here(i: int) -> int:
	if GameState.wines.is_empty():
		return 0
	if i < 0 or i >= GameState.TASTERS.size():
		return 0
	var w: Dictionary = GameState.wines[_wi]
	var rated: Dictionary = w.get("rated", {})
	var t: Dictionary = GameState.TASTERS[i]
	return int(rated.get(str(t["key"]), 0))

func refresh() -> void:
	_refresh_texts()

func _refresh_texts() -> void:
	if _silver_lb == null:
		return
	_silver_lb.text = "银两 " + str(GameState.coin("silver"))
	for i in SEAT_N:
		if i >= GameState.TASTERS.size():
			continue
		var t: Dictionary = GameState.TASTERS[i]
		_name_lbs[i].text = str(t.get("name", "?"))
		var st := _stars_here(i)
		_star_lbs[i].text = _star_text(st) if st > 0 else ""
	var n := GameState.wines.size()
	var limit_txt := GameState.wine_limit_text()
	if n == 0:
		_win_lb.text = "酒窖空着——先酿一坛"
		_hint_lb.text = "酿一坛花 " + str(GameState.BREW_COST) + " 两（银两从清缴 / 挂机 / 卖酒来）　·　" + limit_txt
		_price_lb.text = ""
		_note_lb.text = ""
		_sell_btn.disabled = true
		_prev_btn.disabled = true
		_next_btn.disabled = true
		_brew_btn.text = "酿一坛（" + str(GameState.BREW_COST) + " 两）"
		_brew_btn.disabled = GameState.wine_left_today() == 0
		_msg_lb.text = _msg if _msg != "" else FOOT.replace("｜", "\n")
		return
	_wi = clampi(_wi, 0, n - 1)
	var w: Dictionary = GameState.wines[_wi]
	var nm := str(w.get("name", "酒"))
	var rated: Dictionary = w.get("rated", {})
	_win_lb.text = "「" + nm + "」　第 " + str(_wi + 1) + " / " + str(n) + " 坛"
	_hint_lb.text = str(w.get("hint", "")) + "　·　" + limit_txt
	var tail := "　—　五家品定，价到头了" if rated.size() >= SEAT_N else "（品得越多，价越高）"
	# v35：一口没品过＝生酒，价钱只有四成半——估价行说清楚，别让人以为"酿了就能赚"
	#   （这一行只有 616px、字号 14：生酒那句**替掉**"价到头了/品得越多"，不追加，免得顶出框）
	var price_txt := "估价 " + str(GameState.wine_price(w)) + " 两 · 已品 " + str(rated.size()) + "/" + str(SEAT_N)
	if rated.is_empty():
		price_txt += "　·　还没品过：现按「生酒」贱卖"
	else:
		price_txt += tail
	_price_lb.text = price_txt
	if _anim_phase == 1 and _anim_seat >= 0:
		_note_lb.text = "正给「" + str(GameState.TASTERS[_anim_seat].get("name", "?")) + "」斟酒……"
	elif _last_seat >= 0 and _last_say != "":
		_note_lb.text = "「" + str(GameState.TASTERS[_last_seat].get("name", "?")) + "」：" + _last_say + "　" + _star_text(_last_stars)
	else:
		_note_lb.text = "点桌上任意一位，给他斟上一杯"
	_prev_btn.disabled = false
	_next_btn.disabled = false
	_sell_btn.disabled = false
	_sell_btn.text = "卖掉这坛（" + str(GameState.wine_price(w)) + " 两）"
	_brew_btn.text = "酿一坛（" + str(GameState.BREW_COST) + " 两）"
	_brew_btn.disabled = GameState.wine_left_today() == 0
	_msg_lb.text = _msg if _msg != "" else FOOT.replace("｜", "\n")

func _reset_note() -> void:
	_anim_phase = 0
	_anim_seat = -1
	_anim_t = 0.0
	_last_seat = -1
	_last_say = ""
	_last_stars = 0
	_msg = ""

# ---- 动作 ----

func _on_seat(i: int) -> void:
	if _anim_phase == 1:
		return
	if i < 0 or i >= GameState.TASTERS.size():
		return
	if GameState.wines.is_empty():
		_msg = "酒窖是空的——先酿一坛"
		_refresh_texts()
		return
	if _stars_here(i) > 0:
		var t: Dictionary = GameState.TASTERS[i]
		_msg = str(t.get("name", "他")) + "已经品过这坛了"
		_refresh_texts()
		return
	_msg = ""
	_anim_seat = i
	_anim_t = 0.0
	_anim_phase = 1
	_spark_t = 0.0
	_refresh_texts()

func _finish_pour() -> void:
	_anim_phase = 2
	_spark_t = 0.0
	_last_seat = _anim_seat
	var r: Dictionary = GameState.wine_taste(_wi, _anim_seat)
	_last_say = str(r.get("say", "……"))
	_last_stars = int(r.get("stars", 0))
	_anim_seat = -1
	print("[品酒坊] 斟给 #", _last_seat, "：", _last_say, " ", _last_stars, " 星")
	_refresh_texts()
	# v219：评语星星弹一下（从 1.35 回 1.0），不是"啪"地换一行字
	if _last_stars > 0 and _last_seat >= 0 and _last_seat < _star_lbs.size():
		var sl: Label = _star_lbs[_last_seat]
		sl.pivot_offset = sl.size * 0.5
		sl.scale = Vector2(1.35, 1.35)
		var tw := sl.create_tween()
		tw.tween_property(sl, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()

func _on_prev() -> void:
	if GameState.wines.is_empty():
		return
	_wi = (_wi - 1 + GameState.wines.size()) % GameState.wines.size()
	_reset_note()
	_refresh_texts()

func _on_next() -> void:
	if GameState.wines.is_empty():
		return
	_wi = (_wi + 1) % GameState.wines.size()
	_reset_note()
	_refresh_texts()

func _on_brew() -> void:
	var r: Dictionary = GameState.wine_brew()
	_msg = str(r.get("msg", ""))
	if bool(r.get("ok", false)):
		_wi = GameState.wines.size() - 1
		_reset_note()
		_msg = str(r.get("msg", ""))
	_refresh_texts()

func _on_sell() -> void:
	if GameState.wines.is_empty():
		return
	var w: Dictionary = GameState.wines[_wi]
	var nm := str(w.get("name", "酒"))
	var r: Dictionary = GameState.wine_sell(_wi)
	if bool(r.get("ok", false)):
		_reset_note()
		_msg = "卖出「" + nm + "」——银两 +" + str(int(r.get("price", 0)))
	_refresh_texts()

# ---- 自绘：一间房、一张桌、五个人 ----

func _dec(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)

func _draw_ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 28:
		var a := TAU * float(k) / 28.0
		pts.append(Vector2(c.x + cos(a) * rx, c.y + sin(a) * ry))
	draw_colored_polygon(pts, col)

func _ell_ring(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for k in 29:
		var a := TAU * float(k) / 28.0
		pts.append(Vector2(c.x + cos(a) * rx, c.y + sin(a) * ry))
	draw_polyline(pts, col, w)

func _round_poly(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cx := [r.position.x + rad, r.position.x + r.size.x - rad, r.position.x + r.size.x - rad, r.position.x + rad]
	var cy := [r.position.y + rad, r.position.y + rad, r.position.y + r.size.y - rad, r.position.y + r.size.y - rad]
	var a0s := [PI, PI * 1.5, 0.0, PI * 0.5]
	var a1s := [PI * 1.5, TAU, PI * 0.5, PI]
	for ci in 4:
		var ccx: float = cx[ci]
		var ccy: float = cy[ci]
		var aa0: float = a0s[ci]
		var aa1: float = a1s[ci]
		for k in 7:
			var a := aa0 + (aa1 - aa0) * float(k) / 6.0
			pts.append(Vector2(ccx + cos(a) * rad, ccy + sin(a) * rad))
	return pts

func _ease_out3(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)

func _draw_guest(i: int) -> void:
	var p := seat_of(i)
	var rated := _stars_here(i) > 0
	var bob := sin(_t * 1.7 + float(i) * 1.3) * 1.5
	# v219：被斟的那位往前探一点；喝完之后轻轻一顶（比原来只有呼吸自然）
	if _anim_phase == 1 and _anim_seat == i:
		bob += sin(_anim_t * 9.0) * 1.2
		p += (_tc - p).normalized() * 2.2
	elif _anim_phase == 2 and _last_seat == i and _spark_t < 0.42:
		bob -= sin(clampf(_spark_t / 0.42, 0.0, 1.0) * PI) * 4.0
	var c: Color = GUEST_COL[i] if i < GUEST_COL.size() else Color(0.2, 0.2, 0.2, 0.9)
	if rated:
		c = Color(c.r, c.g, c.b, c.a * 0.55)
	_draw_ell(p + Vector2(0.0, 16.0), 20.0, 6.0, Color(0.10, 0.09, 0.10, 0.10))
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-17.0, 14.0), p + Vector2(17.0, 14.0),
		p + Vector2(11.0, -14.0), p + Vector2(-11.0, -14.0)]), c)
	var hc := p + Vector2(0.0, -26.0 + bob)
	draw_circle(hc, 10.0, Color(0.93, 0.89, 0.82, 0.98))
	draw_arc(hc, 10.0, PI * 1.02, PI * 1.98, 12, Color(c.r * 0.7, c.g * 0.7, c.b * 0.7, 0.95), 6.0)

func _draw_cup(i: int) -> void:
	var cp := cup_of(i)
	_draw_ell(cp + Vector2(0.0, 3.0), 15.0, 6.5, Color(0.80, 0.74, 0.62, 0.95))
	_ell_ring(cp + Vector2(0.0, 3.0), 15.0, 6.5, Color(INK.r, INK.g, INK.b, 0.35), 1.2)
	_draw_ell(cp, 10.0, 6.0, Color(0.93, 0.90, 0.84, 0.98))
	_ell_ring(cp, 10.0, 6.0, Color(INK.r, INK.g, INK.b, 0.45), 1.4)
	var fill := 0.0
	if _stars_here(i) > 0:
		fill = 1.0
	elif _anim_phase == 1 and _anim_seat == i:
		# 倒酒进度 → 缓出，杯面涨得"先快后慢"，不是匀速线性
		fill = _ease_out3((_anim_t / POUR_DUR - 0.18) / 0.58)
	if fill > 0.01:
		_draw_ell(cp, 7.6 * (0.5 + 0.5 * fill), 4.4 * (0.5 + 0.5 * fill), Color(WINE_C.r, WINE_C.g, WINE_C.b, 0.92))
		_draw_ell(cp + Vector2(0.0, -1.0), 4.2 * fill + 1.4, 2.0 * fill + 0.8, Color(0.92, 0.72, 0.50, 0.55 * fill))
		# v219：杯面涟漪——刚涨上来时一圈很淡的环，之后化开
		if _anim_phase == 1 and _anim_seat == i and fill < 0.98:
			var rip := 1.0 - fill
			_ell_ring(cp + Vector2(0.0, -1.0), (7.0 + 9.0 * (1.0 - rip)) * (0.6 + 0.4 * fill),
				(4.0 + 5.0 * (1.0 - rip)) * (0.6 + 0.4 * fill),
				Color(0.92, 0.72, 0.50, 0.35 * rip), 1.2)

# v90（用户："不要只换背景啊 里面的也要换"）：**酒坛换成真图**——
#   原来是六边形+两个方块拼的酒坛（一眼程序画），现在用素材里的 pic_jiutan（带葫芦那只）。
#   没图就退回原来那套画法，不会变空白。
func _draw_jar() -> void:
	var jp := _tc + Vector2(0.0, -4.0)
	var tex := SceneArt.wine_jar()
	if tex != null:
		var h := 76.0
		var w: float = h * float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		draw_texture_rect(tex, Rect2(jp.x - w * 0.5, jp.y + 10.0 - h, w, h), false, Color(1, 1, 1, 0.98))
		return
	draw_colored_polygon(PackedVector2Array([
		jp + Vector2(-17.0, 6.0), jp + Vector2(-13.0, -12.0),
		jp + Vector2(-6.0, -20.0), jp + Vector2(6.0, -20.0),
		jp + Vector2(13.0, -12.0), jp + Vector2(17.0, 6.0)]), Color(0.30, 0.26, 0.22, 0.95))
	_draw_ell(jp + Vector2(0.0, -18.0), 7.0, 3.0, Color(0.62, 0.56, 0.42, 0.95))
	draw_rect(Rect2(jp.x - 10.0, jp.y - 8.0, 20.0, 14.0), Color(0.88, 0.83, 0.66, 0.92))
	draw_rect(Rect2(jp.x - 10.0, jp.y - 8.0, 20.0, 14.0), Color(0.55, 0.46, 0.30, 0.50), false, 1.0)
	draw_line(Vector2(jp.x - 6.0, jp.y - 4.0), Vector2(jp.x + 6.0, jp.y - 4.0), Color(0.60, 0.26, 0.20, 0.60), 1.2, true)

func _draw_pour() -> void:
	if _anim_phase != 1 or _anim_seat < 0:
		return
	var i := _anim_seat
	var cup := cup_of(i)
	var gp := seat_of(i)
	var gc: Color = GUEST_COL[i] if i < GUEST_COL.size() else Color(0.2, 0.2, 0.2, 0.9)
	draw_line(gp + Vector2(0.0, -6.0), cup + (gp - cup).normalized() * 18.0, gc, 4.0, true)
	var p := clampf(_anim_t / POUR_DUR, 0.0, 1.0)
	var side := -1.0 if cup.x > _tc.x else 1.0
	# 酒壶：前 0.18 端进来（缓出），后 0.14 撤走——不是"啪"一下出现/消失
	var pin := _ease_out3(p / 0.18)
	var pout := clampf((p - 0.86) / 0.14, 0.0, 1.0)
	var pa := clampf(pin, 0.0, 1.0) * (1.0 - pout)
	var base := cup + Vector2(30.0 * side, -54.0)
	var pot := base + Vector2(-16.0 * side * (1.0 - pin) + 12.0 * side * pout,
		-10.0 * (1.0 - pin) + 8.0 * pout)
	if pa > 0.01:
		var pot_c := Color(0.34, 0.30, 0.28, 0.95 * pa)
		_draw_ell(pot, 13.0, 10.0, pot_c)
		draw_line(Vector2(pot.x + 10.0 * -side, pot.y - 2.0), Vector2(pot.x + 22.0 * -side, pot.y - 8.0), pot_c, 4.0)
		draw_arc(Vector2(pot.x + 12.0 * side, pot.y + 2.0), 7.0, -0.8 * side, 2.2 * side, 10, pot_c, 2.4)
		draw_rect(Rect2(pot.x - 4.0, pot.y - 13.0, 8.0, 4.0), Color(0.72, 0.66, 0.50, 0.9 * pa))
	# 酒流：两端收细、渐显渐隐；再加一道高光与杯口溅点/涟漪
	if p > 0.16 and p < 0.92:
		var sp := clampf((p - 0.16) / 0.74, 0.0, 1.0)
		var sa := clampf(sp * 7.0, 0.0, 1.0) * clampf((1.0 - sp) * 9.0, 0.0, 1.0)
		var from := pot + Vector2(22.0 * -side, -8.0)
		var to := cup + Vector2(0.0, -4.0)
		var pts := PackedVector2Array()
		for k in 10:
			var u := float(k) / 9.0
			var q := from.lerp(to, u)
			q.y += sin(u * PI) * 7.0
			pts.append(q)
		var wdt := 3.4 * (0.6 + 0.4 * sin(sp * PI))
		draw_polyline(pts, Color(WINE_C.r, WINE_C.g, WINE_C.b, 0.88 * sa), wdt)
		var hl := PackedVector2Array()
		for qi in pts.size():
			hl.append(pts[qi] + Vector2(0.9, -0.9))
		draw_polyline(hl, Color(0.98, 0.84, 0.62, 0.45 * sa), 1.2)
		var tt := fmod(_anim_t * 13.0, 1.0)
		for k in 3:
			var aa := fmod(tt + float(k) * 0.33, 1.0)
			draw_circle(cup + Vector2(cos(aa * TAU) * (7.0 + aa * 9.0), -3.0 - sin(aa * PI) * 4.0),
				1.4 * (1.0 - aa), Color(WINE_C.r, WINE_C.g, WINE_C.b, 0.55 * (1.0 - aa) * sa))
		_ell_ring(cup + Vector2(0.0, -3.0), 9.0 + tt * 7.0, 4.6 + tt * 3.5,
			Color(0.95, 0.78, 0.52, 0.30 * (1.0 - tt) * sa), 1.2)

func _draw_sparkle() -> void:
	if _anim_phase != 2 or _last_seat < 0 or _spark_t > 0.7:
		return
	var cp := cup_of(_last_seat)
	var a := 1.0 - _spark_t / 0.7
	for k in 6:
		var ang := TAU * float(k) / 6.0 + _spark_t * 4.0
		var r0 := 16.0 + _spark_t * 22.0
		var v0 := cp + Vector2(cos(ang), sin(ang) * 0.6) * r0
		var v1 := cp + Vector2(cos(ang), sin(ang) * 0.6) * (r0 + 9.0)
		draw_line(v0, v1, Color(GOLD.r, GOLD.g, GOLD.b, 0.8 * a), 2.4)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	if Ui.SKIN == 1:
		# v218：切角纸面 + 金框角标 + 左端朱砂起笔（跟弟子/仓库同一套板）
		var pts := Ui.cut_poly(_prect, 12.0)
		draw_colored_polygon(pts, Color(0.961, 0.941, 0.898, 0.985))
		var q := PackedVector2Array(pts)
		q.append(pts[0])
		draw_polyline(q, Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.55), 2.0, true)
		Ui.brackets(self, _prect, 12.0, Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.72), 16.0, 2.0)
		var ir := Rect2(_prect.position + Vector2(9.0, 9.0), _prect.size - Vector2(18.0, 18.0))
		var ip := Ui.cut_poly(ir, 6.0)
		ip.append(ip[0])
		draw_polyline(ip, Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.18), 1.0, true)
		draw_rect(Rect2(_prect.position.x + 18.0, _prect.position.y + 18.0, 4.0, 28.0), Ui.CINN)
	else:
		draw_colored_polygon(_round_poly(_prect, 14.0), Color(PAPER.r, PAPER.g, PAPER.b, 0.985))
		var bp := _round_poly(_prect, 14.0)
		bp.append(bp[0])
		draw_polyline(bp, Color(0.32, 0.27, 0.22, 0.55), 2.0)
		var ir := Rect2(_prect.position + Vector2(9.0, 9.0), _prect.size - Vector2(18.0, 18.0))
		var ip := _round_poly(ir, 10.0)
		ip.append(ip[0])
		draw_polyline(ip, Color(INK.r, INK.g, INK.b, 0.12), 1.4)
	# 地板
	_draw_ell(_tc + Vector2(0.0, 112.0), 290.0, 52.0, Color(0.10, 0.09, 0.10, 0.05))
	# 后排（0/1/4）：先人、后桌，桌子压住他们下半身
	for i in [0, 1, 4]:
		_draw_guest(i)
	# 桌子
	_draw_ell(_tc + Vector2(0.0, 9.0), _rx + 13.0, _ry + 13.0, Color(0.40, 0.31, 0.22, 0.50))
	_draw_ell(_tc, _rx, _ry, Color(0.50, 0.40, 0.27, 0.97))
	_draw_ell(_tc, _rx - 6.0, _ry - 6.0, Color(0.60, 0.49, 0.34, 0.98))
	_ell_ring(_tc, _rx * 0.55, _ry * 0.55, Color(0.42, 0.33, 0.22, 0.35), 1.2)
	_ell_ring(_tc, _rx * 0.80, _ry * 0.80, Color(0.42, 0.33, 0.22, 0.25), 1.0)
	_draw_jar()
	for i in SEAT_N:
		_draw_cup(i)
	# 前排（2/3）：人压住桌沿
	for i in [2, 3]:
		_draw_guest(i)
	_draw_pour()
	_draw_sparkle()

# ---- 开合 ----

func open() -> void:
	_msg = ""
	_reset_note()
	_refresh_texts()
	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _prect.has_point(mb.position):
			close()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and not _prect.has_point(st.position):
			close()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
