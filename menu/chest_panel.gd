extends Control
# ============================================================
# chest_panel.gd —— 宝箱 v2（用户："专门加了个宝箱栏位，类似咸鱼之王的宝箱页面，宝箱开启有动画"）
#
# v2 相比 v1 的三处改动：
#   ① 一整页"开箱台"：中间一只**自绘的箱子**（按品质换颜色），下面五行箱子（点一行＝选中）
#   ② 开箱有动画：抖 → 掀盖 → 光柱炸开 → 奖励一件件飞出来（按件型上色） → 盖回去 → 账目刷新
#   ③ 一档选中就能连开：［开 1］［开 10］［全部开完］都作用在**选中的那一档**
#      （v1 是每行各挂两个按钮，五行十颗按钮，手机上容易点错）
#
# 规则仍在 shared/tower.gd 的 CHESTS 表 + GameState.chest_open——这一页只管**画与演**，
#   一个数值都不在这里定。箱子怎么来、开出来什么，看那两个文件。
# 入口两处：村内底排第 5 格［宝箱］（menu_hud 画）、出村屏右上角［宝箱］（out_panel）。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const Tower := preload("res://shared/tower.gd")
const UiKit := preload("res://shared/ui_kit.gd")   # v77：内景垫图要用
const Audio := preload("res://shared/audio.gd")   # v78：开箱音
const SceneArt := preload("res://shared/scene_art.gd")

signal closed

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)

const PANEL_W := 640.0
const PANEL_H := 900.0
const STAGE_Y := 96.0          # 开箱台
const STAGE_H := 236.0
const ROW_Y0 := 442.0          # 五行箱子
const ROW_STEP := 60.0
const ROW_H := 54.0
const POP_MAX := 8             # 一次最多"飞"几件（再多就只进下面的明细）

# 五档颜色（跟器物/箱子的品级一个色系：灰木 → 铁 → 金 → 玉 → 龙）
const TIER_COL := [
	Color(0.45, 0.38, 0.30),
	Color(0.42, 0.44, 0.50),
	Color(0.70, 0.55, 0.20),
	Color(0.40, 0.62, 0.46),
	Color(0.72, 0.30, 0.28),
]

var _panel: Panel
var _stage_box: Panel
var _art = null                # ChestArt
var _flash: ColorRect
var _stage_lb: Label
var _odds_lb: Label
var _msg_lb: Label
var _note_lb: Label
var _rows: Array = []
var _pop_root: Control
var _btn1: Button
var _btn10: Button
var _btnall: Button
var _close_btn: Button
var _sel := ""                 # 选中的档（cid）
var _sel_had_stock := false    # 上一轮这一档有没有货（决定"开完了自动挪档"要不要挪）
var _busy := false             # 动画播放中：挡住连点

# ══════════════════════════════════════════════════════════
# 自绘宝箱（这一页唯一的"美术"：没有贴图，全部是 draw_* 画出来的）
#   lid  0→1 掀盖 · glow 0→1 嘴里/光柱的亮 · shake_t>0 时自己抖
#   tiny = true 画小图标（五行列表里那个）
# ══════════════════════════════════════════════════════════
class ChestArt extends Control:
	var tier := 0
	var lid := 0.0
	var glow := 0.0
	var shake_t := 0.0
	var tiny := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		if shake_t > 0.0:
			shake_t = maxf(0.0, shake_t - d)
		queue_redraw()

	# 抖一下（秒）——由面板在开箱时叫一声
	func shake_for(sec: float) -> void:
		shake_t = sec

	func tier_col() -> Color:
		var cols: Array = [
			Color(0.45, 0.38, 0.30), Color(0.42, 0.44, 0.50), Color(0.70, 0.55, 0.20),
			Color(0.40, 0.62, 0.46), Color(0.72, 0.30, 0.28)]
		return cols[clampi(tier, 0, cols.size() - 1)]

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 1.0 or h <= 1.0:
			return
		var base := tier_col()
		var wood_d := base.darkened(0.35)
		var wood_l := base.lightened(0.16)
		var band := Color(0.86, 0.78, 0.52) if tier >= 2 else Color(0.62, 0.58, 0.50)
		# 抖动/开盖的位移（只影响画，不影响 Control 的 rect）
		var k := shake_t
		var off := Vector2(sin(k * 52.0) * k * 7.0, -absf(sin(k * 26.0)) * k * 4.0)
		var px := w * 0.06
		var body_t := h * 0.44
		var body_b := h * 0.94
		var bx0 := px
		var bx1 := w - px
		# ── 光柱（盖子开了才有）──
		if glow > 0.02:
			var mouth_y := body_t - 2.0
			var tip_y := mouth_y - h * (0.55 + 0.35 * glow)
			var m0 := Vector2(bx0 + w * 0.10, mouth_y) + off
			var m1 := Vector2(bx1 - w * 0.10, mouth_y) + off
			var t0 := Vector2(bx0 + w * 0.26, tip_y) + off
			var t1 := Vector2(bx1 - w * 0.26, tip_y) + off
			draw_colored_polygon(PackedVector2Array([m0, m1, t1, t0]),
				Color(1.0, 0.96, 0.78, 0.20 * glow))
			draw_colored_polygon(PackedVector2Array([
				m0 + Vector2(w * 0.10, 0), m1 - Vector2(w * 0.10, 0),
				t1 - Vector2(w * 0.14, -h * 0.04), t0 + Vector2(w * 0.14, -h * 0.04)]),
				Color(1.0, 0.99, 0.90, 0.26 * glow))
			# 几点飞屑
			for i in 7:
				var fy := mouth_y - h * (0.18 + 0.62 * glow) * (0.35 + 0.13 * float(i))
				var fx := bx0 + w * (0.22 + 0.09 * float(i)) + sin(float(i) * 2.1 + glow * 6.0) * w * 0.05
				if fy > tip_y:
					draw_circle(Vector2(fx, fy) + off, 1.6 + 1.4 * glow, Color(1.0, 0.97, 0.80, 0.55 * glow))
		# ── 箱身（下沿略收，看着敦实）──
		var body := PackedVector2Array([
			Vector2(bx0, body_t), Vector2(bx1, body_t),
			Vector2(bx1 - w * 0.02, body_b), Vector2(bx0 + w * 0.02, body_b)])
		for i in body.size():
			body[i] = body[i] + off
		draw_colored_polygon(body, base)
		var bp := body.duplicate()
		bp.append(body[0])
		draw_polyline(bp, wood_d, 2.0, true)
		# 箱身上的竖箍与铆钉
		for i in 2:
			var gx := bx0 + (bx1 - bx0) * (0.30 + 0.40 * float(i))
			draw_line(Vector2(gx, body_t + 2.0) + off, Vector2(gx, body_b - 2.0) + off, Color(band.r, band.g, band.b, 0.55), 3.0, true)
		for i in 3:
			var sy2 := body_t + (body_b - body_t) * (0.22 + 0.30 * float(i))
			draw_circle(Vector2(bx0 + w * 0.045, sy2) + off, 1.8, Color(1, 1, 1, 0.35))
			draw_circle(Vector2(bx1 - w * 0.045, sy2) + off, 1.8, Color(1, 1, 1, 0.35))
		# ── 盖子（绕"箱口后沿"往后掀）──
		var lh := h * 0.30
		var hinge := Vector2(w * 0.5, body_t)
		draw_set_transform(hinge + off, -lid * 1.15, Vector2.ONE)
		var lid_pts := PackedVector2Array([
			Vector2(-(bx1 - bx0) * 0.5, 0.0), Vector2((bx1 - bx0) * 0.5, 0.0),
			Vector2((bx1 - bx0) * 0.5 - w * 0.03, -lh), Vector2(-(bx1 - bx0) * 0.5 + w * 0.03, -lh)])
		draw_colored_polygon(lid_pts, wood_l)
		var lp := lid_pts.duplicate()
		lp.append(lid_pts[0])
		draw_polyline(lp, wood_d, 2.0, true)
		# 盖子上的横箍
		draw_line(Vector2(-(bx1 - bx0) * 0.5 + w * 0.01, -lh * 0.45), Vector2((bx1 - bx0) * 0.5 - w * 0.01, -lh * 0.45),
			Color(band.r, band.g, band.b, 0.60), 3.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# ── 锁扣 / 箱口的亮线 ──
		if lid < 0.35:
			var lw := w * 0.16
			var lh2 := h * 0.14
			draw_rect(Rect2(Vector2(w * 0.5 - lw * 0.5, body_t - lh2 * 0.35) + off, Vector2(lw, lh2)), band)
			draw_circle(Vector2(w * 0.5, body_t + lh2 * 0.22) + off, w * 0.022, wood_d)
		if lid > 0.02:
			draw_line(Vector2(bx0 + w * 0.08, body_t + 1.0) + off, Vector2(bx1 - w * 0.08, body_t + 1.0) + off,
				Color(1.0, 0.97, 0.82, 0.75 * lid), 3.0, true)
		if tiny:
			return

# ══════════════════════════════════════════════════════════
func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	refresh()
	visible = get_parent() == get_tree().root

func _build() -> void:
	var vp := get_viewport_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = vp
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = Panel.new()
	_panel.position = Vector2((vp.x - PANEL_W) * 0.5, (vp.y - PANEL_H) * 0.5)
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.98)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	psb.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", psb)
	add_child(_panel)
	# v77：垫一张宝箱特写（用户：「是不是也要换图了」）——34% 透明度，纸底还透、字照样清楚
	UiKit.add_room_bg(_panel, SceneArt.chest_art(), 0.34)
	Audio.sfx("chest", -8.0)   # v78：开箱音

	var title := _label("宝　箱", 30, INK)
	title.position = Vector2(28, 16)
	title.size = Vector2(220, 44)
	_panel.add_child(title)
	var sub := _label("每清一关给一个：杂兵＝木箱 · 精英＝银箱 · 首领＝金箱 · 里程碑＝玉箱/龙箱。\n开箱有几率出角色碎片与突破丹，其余给银两与炼丹材料。", 14, Color(INK.r, INK.g, INK.b, 0.60))
	sub.position = Vector2(28, 56)
	sub.size = Vector2(584, 42)   # v61（手游）：12 → 14 号，框补宽补高（原来 500×40）
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(sub)

	# ── 开箱台 ──
	_stage_box = Panel.new()
	_stage_box.position = Vector2(28, STAGE_Y)
	_stage_box.size = Vector2(PANEL_W - 56.0, STAGE_H)
	_stage_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.16, 0.15, 0.17, 0.90)
	ssb.set_corner_radius_all(12)
	ssb.border_color = Color(0.42, 0.36, 0.26, 0.60)
	ssb.set_border_width_all(2)
	_stage_box.add_theme_stylebox_override("panel", ssb)
	_panel.add_child(_stage_box)

	_pop_root = Control.new()
	_pop_root.size = _stage_box.size
	_pop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_art = ChestArt.new()
	_art.position = Vector2((_stage_box.size.x - 220.0) * 0.5, 22.0)
	_art.size = Vector2(220.0, 176.0)
	_stage_box.add_child(_art)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.position = Vector2.ZERO
	_flash.size = _stage_box.size
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_box.add_child(_flash)

	# 飞出来的奖励字要压在最上面（后加的兄弟画在上面）
	_stage_box.add_child(_pop_root)

	_stage_lb = _label("", 16, Color(0.95, 0.92, 0.84, 0.92))
	_stage_lb.position = Vector2(0, STAGE_H - 34.0)
	_stage_lb.size = Vector2(_stage_box.size.x, 24)
	_stage_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_box.add_child(_stage_lb)

	# ── 选中的那一档：几率说明 ──
	_odds_lb = _label("", 13, Color(INK.r, INK.g, INK.b, 0.62))
	_odds_lb.position = Vector2(28, STAGE_Y + STAGE_H + 6.0)
	_odds_lb.size = Vector2(PANEL_W - 56.0, 24)   # v61（手游）：12 → 13 号
	_panel.add_child(_odds_lb)

	# ── 三个开箱键（都作用在选中的那一档）──
	_btn1 = _mk_btn("开 1", Vector2(28, 372), Vector2(150, 52), 20, true)
	_btn1.pressed.connect(_on_open.bind(1))
	_btn10 = _mk_btn("开 10", Vector2(190, 372), Vector2(150, 52), 20, true)
	_btn10.pressed.connect(_on_open.bind(10))
	_btnall = _mk_btn("全部开完", Vector2(352, 372), Vector2(260, 52), 20, false)
	_btnall.pressed.connect(_on_open_all)

	# ── 五行箱子：点一行＝选中 ──
	_rows = []
	for i in Tower.CHESTS.size():
		var c: Dictionary = Tower.CHESTS[i]
		var cid := str(c.get("id", ""))
		var y := ROW_Y0 + float(i) * ROW_STEP
		var b := Button.new()
		b.position = Vector2(28, y)
		b.size = Vector2(PANEL_W - 56.0, ROW_H)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_select.bind(cid))
		_row_style(b, int(c.get("grad", 0)))
		_panel.add_child(b)
		var mini := ChestArt.new()
		mini.tiny = true
		mini.tier = int(c.get("grad", 0))
		mini.position = Vector2(12, 9)
		mini.size = Vector2(46, 36)
		b.add_child(mini)
		var nm := _label(str(c.get("name", cid)), 19, INK)
		nm.position = Vector2(70, 6)
		nm.size = Vector2(180, 24)
		b.add_child(nm)
		# v61（手游）：11 → 13 号（爆率那行，原来小到看不清）
		var info := _label("", 13, Color(INK.r, INK.g, INK.b, 0.58))
		info.position = Vector2(70, 28)
		info.size = Vector2(340, 24)
		b.add_child(info)
		var cnt := _label("", 21, INK)
		cnt.position = Vector2(400, 12)
		cnt.size = Vector2(150, 30)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(cnt)
		_rows.append({"cid": cid, "btn": b, "info": info, "cnt": cnt, "grad": int(c.get("grad", 0))})

	_msg_lb = _label("", 14, SEAL)
	_msg_lb.position = Vector2(28, 736)
	_msg_lb.size = Vector2(PANEL_W - 56.0, 22)
	_panel.add_child(_msg_lb)

	_note_lb = _label("", 13, Color(INK.r, INK.g, INK.b, 0.62))
	_note_lb.position = Vector2(28, 756)
	_note_lb.size = Vector2(PANEL_W - 56.0, 60)   # v61（手游）：12 → 13 号
	_note_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_note_lb)

	_close_btn = _mk_btn("关　闭", Vector2(220, PANEL_H - 74.0), Vector2(200, 54), 22, false)
	_close_btn.pressed.connect(close)

func _mk_btn(txt: String, pos: Vector2, sz: Vector2, fs: int, seal: bool) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", fs)
	b.focus_mode = Control.FOCUS_NONE
	if seal:
		_style_seal(b)
	else:
		_style_dark(b)
	_panel.add_child(b)
	return b

func _row_style(b: Button, grad: int) -> void:
	var c: Color = TIER_COL[clampi(grad, 0, TIER_COL.size() - 1)]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.34)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(INK.r, INK.g, INK.b, 0.20)
	sb.set_border_width_all(1)
	var hv: StyleBoxFlat = sb.duplicate()
	hv.bg_color = Color(1, 1, 1, 0.60)
	var pr: StyleBoxFlat = sb.duplicate()
	pr.bg_color = Color(0.90, 0.87, 0.80, 0.70)
	# 选中态：按品级描一道粗边（refresh 时整行换这一份）
	var sel: StyleBoxFlat = sb.duplicate()
	sel.bg_color = Color(c.r, c.g, c.b, 0.16)
	sel.border_color = Color(c.r, c.g, c.b, 0.85)
	sel.set_border_width_all(2)
	var sel_hv: StyleBoxFlat = sel.duplicate()
	sel_hv.bg_color = Color(c.r, c.g, c.b, 0.24)
	# ⚠ 四份都挂在 meta 上：refresh 只"换引用"，不每帧新建 StyleBox
	b.set_meta("box_plain", sb)
	b.set_meta("box_hover", hv)
	b.set_meta("box_sel", sel)
	b.set_meta("box_sel_hover", sel_hv)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("focus", sb)

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
	sb.set_corner_radius_all(8)
	return sb

func _style_dark(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.19, 0.20, 0.96)))
	btn.add_theme_stylebox_override("hover", _flat(Color(0.31, 0.27, 0.27, 0.96)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.11, 0.12, 0.96)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.40)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.55))

func _style_seal(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.92)))
	btn.add_theme_stylebox_override("hover", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.80)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r * 0.75, SEAL.g * 0.75, SEAL.b * 0.75, 0.95)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.30)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.45))

# ══════════════════════════════════════════════════════════
# 刷新（账目 → 界面）
# ══════════════════════════════════════════════════════════
func refresh() -> void:
	if _panel == null:
		return
	# 选哪一档：第一脚进来＝**最高那档有货的**（都没货就落到最低那档）；
	#   刚把手上这一档开完 → 自动挪到下一个有货的档（省得手点）。
	#   ⚠ 但"玩家自己点了一档空的"要留住，别当场把他弹回别的档——所以看的是
	#     **上一轮这一档有没有货**（_sel_had_stock），不是"现在有没有货"。
	var sel_n := GameState.chest_count(_sel)
	if _sel == "" or (sel_n <= 0 and _sel_had_stock):
		_sel = _pick_default()
		sel_n = GameState.chest_count(_sel)
	_sel_had_stock = sel_n > 0
	for row in _rows:
		var cid := str(row["cid"])
		var d: Dictionary = Tower.chest_def(cid)
		var n := GameState.chest_count(cid)
		var info: Label = row["info"]
		var frag_pct := int(round(float(d.get("frag_chance", 0.0)) * 100.0))
		var pill_pct := int(round(float(d.get("pill_chance", 0.0)) * 100.0))
		var fr: Array = d.get("frag", [0, 0])
		info.text = ("碎片 " + str(frag_pct) + "%（" + str(int(fr[0])) + "~" + str(int(fr[1]))
			+ " 片）· 突破丹 " + str(pill_pct) + "% · 其余银两/材料")
		var cnt: Label = row["cnt"]
		cnt.text = "×" + str(n)
		var c: Color = TIER_COL[clampi(int(row["grad"]), 0, TIER_COL.size() - 1)]
		cnt.add_theme_color_override("font_color", c if n > 0 else Color(INK.r, INK.g, INK.b, 0.32))
		var b: Button = row["btn"]
		var is_sel: bool = cid == _sel
		b.add_theme_stylebox_override("normal", b.get_meta("box_sel") if is_sel else b.get_meta("box_plain"))
		b.add_theme_stylebox_override("hover", b.get_meta("box_sel_hover") if is_sel else b.get_meta("box_hover"))
	_art.tier = _sel_grad()
	if sel_n > 0:
		_stage_lb.text = Tower.chest_name(_sel) + " ×" + str(sel_n) + "　——　点下面的［开 1］"
	else:
		_stage_lb.text = Tower.chest_name(_sel) + " ×0　——　这档还空着，去清关攒"
	var odds_parts: Array = []
	odds_parts.append("攒着 " + str(GameState.chest_total()) + " 个箱子")
	odds_parts.append("已清 " + str(GameState.stage_progress) + " 关")
	if sel_n > 0:
		odds_parts.append("这档每开一个：银两约 " + str(Tower.chest_silver_total(GameState.stage_progress, _sel)) + " 两")
	_odds_lb.text = "　｜　".join(PackedStringArray(odds_parts))
	_btn1.disabled = sel_n <= 0 or _busy
	_btn10.disabled = sel_n <= 0 or _busy
	_btnall.disabled = GameState.chest_total() <= 0 or _busy
	_close_btn.disabled = _busy
	var notes: Array = GameState.chest_notes
	if notes.is_empty():
		_note_lb.text = "开出来的东西会列在这儿。银两与材料直接进村账，碎片进碎片账（弟子面板升星用），突破丹进丹药包裹（突破用）。"
	else:
		_note_lb.text = "刚开出来：" + "、".join(PackedStringArray(notes))

func _sel_grad() -> int:
	for c_v in Tower.CHESTS:
		var c: Dictionary = c_v
		if str(c.get("id", "")) == _sel:
			return int(c.get("grad", 0))
	return 0

# 该选谁：从最高档往下找第一个有货的；一个都没有＝最低那档（空着也能看几率）
func _pick_default() -> String:
	var n := Tower.CHESTS.size()
	for i in range(n - 1, -1, -1):
		var cid := str((Tower.CHESTS[i] as Dictionary).get("id", ""))
		if GameState.chest_count(cid) > 0:
			return cid
	return str((Tower.CHESTS[0] as Dictionary).get("id", "")) if n > 0 else ""

func _select(cid: String) -> void:
	if _busy:
		return
	_sel = cid
	# ⚠ 玩家手点的这一下要"锁住"：把上一档的存货记忆清掉，refresh 才不会
	#   因为"上一档刚开完"把他弹回别的档（否则点一个空档＝当场跳走）。
	_sel_had_stock = false
	_msg_lb.text = ""
	refresh()

# ══════════════════════════════════════════════════════════
# 开箱：先落账（chest_open 里就写账了），再把结果**演**出来
#   ⚠ 账在动画之前——哪怕动画放一半被打断，东西也已经到手，不会丢
# ══════════════════════════════════════════════════════════
func _on_open(n: int) -> void:
	if _busy:
		return
	if GameState.chest_count(_sel) <= 0:
		_msg_lb.text = "没有「" + Tower.chest_name(_sel) + "」可开——清关攒箱子"
		return
	var r: Dictionary = GameState.chest_open(_sel, n)
	if not bool(r.get("ok", false)):
		_msg_lb.text = str(r.get("msg", ""))
		refresh()
		return
	GameState.save_game()   # 箱子是"攒出来的东西"，开了就落盘
	_msg_lb.text = "开了 " + str(int(r.get("n", 0))) + " 个「" + Tower.chest_name(_sel) + "」"
	_play(r)

func _on_open_all() -> void:
	if _busy:
		return
	if GameState.chest_total() <= 0:
		_msg_lb.text = "没有箱子可开——去清关（手动打或挂机推都算）"
		refresh()
		return
	var total := 0
	var merged: Array = []
	var names: Array = []
	for c_v in Tower.CHESTS:
		var cid := str((c_v as Dictionary).get("id", ""))
		var n := GameState.chest_count(cid)
		if n <= 0:
			continue
		var r: Dictionary = GameState.chest_open(cid, n)
		if not bool(r.get("ok", false)):
			continue
		total += int(r.get("n", 0))
		names.append(Tower.chest_name(cid) + "×" + str(int(r.get("n", 0))))
		for it_v in (r.get("items", []) as Array):
			merged.append((it_v as Dictionary).duplicate())
	if total <= 0:
		_msg_lb.text = "没有箱子可开——去清关"
		refresh()
		return
	GameState.save_game()
	_msg_lb.text = "全开完：" + "、".join(PackedStringArray(names)) + "　共 " + str(total) + " 个"
	_play({"items": _merge_items(merged), "n": total})

# 多档合并：同名同型并成一条（"银两"两条并一条）
func _merge_items(list: Array) -> Array:
	var out: Array = []
	for it_v in list:
		var it: Dictionary = it_v
		var hit := -1
		for i in out.size():
			var o: Dictionary = out[i]
			if str(o.get("kind", "")) == str(it.get("kind", "")) and str(o.get("name", "")) == str(it.get("name", "")):
				hit = i
				break
		if hit >= 0:
			out[hit]["n"] = int(out[hit]["n"]) + int(it.get("n", 0))
		else:
			out.append({"kind": str(it.get("kind", "")), "name": str(it.get("name", "")), "n": int(it.get("n", 0))})
	# 由稀到常排一遍（碎片 → 突破丹 → 银两 → 材料）：飞出来的头几件就是好东西。
	#   ⚠ 这里手写四桶、不用 sort_custom：同一个字典键排序，分桶比 lambda 好读也好查。
	var order := ["frag", "pill", "silver", "mat"]
	var sorted_out: Array = []
	for kind in order:
		for o2_v in out:
			var o2: Dictionary = o2_v
			if str(o2.get("kind", "")) == str(kind):
				sorted_out.append(o2)
	for o3_v in out:   # 兜底：没在表里的件型照原样接在最后
		var o3: Dictionary = o3_v
		if not order.has(str(o3.get("kind", ""))):
			sorted_out.append(o3)
	return sorted_out

# ── 动画本体：抖 → 掀盖 → 光柱 → 奖励飞出 → 盖回 ──
func _play(r: Dictionary) -> void:
	_busy = true
	_btn1.disabled = true
	_btn10.disabled = true
	_btnall.disabled = true
	_close_btn.disabled = true
	_art.lid = 0.0
	_art.glow = 0.0
	_art.shake_for(0.50)
	var items: Array = r.get("items", [])
	var tw := create_tween()
	tw.tween_callback(_stage_lb_shake_note)
	tw.tween_interval(0.52)
	tw.tween_callback(_burst)
	tw.tween_interval(0.06)
	tw.tween_callback(_pop_rewards.bind(items))
	var hold := 0.20 + 0.10 * float(mini(items.size(), POP_MAX))
	tw.tween_interval(hold)
	tw.tween_callback(_close_lid)
	tw.tween_interval(0.30)
	tw.tween_callback(_finish_play)

func _stage_lb_shake_note() -> void:
	_stage_lb.text = "……"

func _burst() -> void:
	# 掀盖 + 光柱 + 白闪，并把"帐"刷新到界面（箱子数当场少下去）
	var tw := create_tween()
	tw.tween_property(_art, "lid", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_art, "glow", 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var ft := create_tween()
	ft.tween_property(_flash, "color:a", 0.55, 0.06)
	ft.tween_property(_flash, "color:a", 0.0, 0.42)
	refresh()

# 奖励一件件从箱口飞出来（每件一个自己的小 Tween，错开 0.10s）
func _pop_rewards(items: Array) -> void:
	var n := mini(items.size(), POP_MAX)
	for i in n:
		var it: Dictionary = items[i]
		var kind := str(it.get("kind", ""))
		var fs := 20 if kind == "silver" else 18
		var lb := _label(_item_text(it), fs, _item_col(kind))
		lb.size = Vector2(240, 26)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cx := _stage_box.size.x * 0.5
		lb.position = Vector2(cx - 120.0, 74.0)
		lb.modulate.a = 0.0
		lb.scale = Vector2(0.6, 0.6)
		lb.pivot_offset = Vector2(120, 13)
		_pop_root.add_child(lb)
		# 落点：中间偏上，左右交错，越后面的越高一点（不叠在一起）
		var lane := float(i % 4) - 1.5
		var tx := cx - 120.0 + lane * 74.0
		var ty := 40.0 - 16.0 * float(i / 4) + sin(float(i) * 1.7) * 4.0
		var tw := lb.create_tween()
		tw.tween_interval(0.10 * float(i))
		tw.parallel().tween_property(lb, "modulate:a", 1.0, 0.14)
		tw.parallel().tween_property(lb, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(lb, "position", Vector2(tx, ty), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.55)
		tw.tween_property(lb, "modulate:a", 0.0, 0.30)
		tw.tween_callback(lb.queue_free)

func _item_text(it: Dictionary) -> String:
	var kind := str(it.get("kind", ""))
	var n := int(it.get("n", 0))
	if kind == "silver":
		return "银两 +" + str(n)
	return str(it.get("name", "?")) + " ×" + str(n)

func _item_col(kind: String) -> Color:
	match kind:
		"frag":
			return Color(0.86, 0.24, 0.20)     # 碎片：红
		"pill":
			return Color(0.52, 0.32, 0.66)     # 突破丹：紫
		"silver":
			return Color(0.84, 0.64, 0.16)     # 银两：金
		_:
			return Color(0.30, 0.56, 0.34)     # 材料：绿

func _close_lid() -> void:
	var tw := create_tween()
	tw.tween_property(_art, "lid", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_art, "glow", 0.0, 0.26)

func _finish_play() -> void:
	_busy = false
	refresh()

# ---- 开合 ----

func open() -> void:
	_busy = false
	_msg_lb.text = ""
	_art.lid = 0.0
	_art.glow = 0.0
	refresh()
	visible = true

func close() -> void:
	if not visible or _busy:
		return
	visible = false
	closed.emit()

func _gui_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			close()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
