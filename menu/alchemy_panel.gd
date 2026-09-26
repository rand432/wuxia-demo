extends Control
# ============================================================
# alchemy_panel.gd —— 炼丹阁 v6（用户："点击炼丹不能直接输入练多少颗这样不会更好一点吗
#   我设想是这样的：点击炼丹阁 → 点击［炼制丹药］→ 弹出窗口：炼制什么丹（选丹药）
#   → 选择颗数 → 开始炼丹。然后第一排就出现 xxx丹正在炼制，第二排就是未解锁、
#   需要多少银两打开。"）
#
# v6 三处改动（规则一个字没动，账本那套照旧）：
#   ① 主面板顶部一颗**［炼制丹药］**：点开弹窗——**选丹 → 填/选颗数 → 开始炼丹**
#      （颗数既能按 −/＋，也能**直接敲数字**；旁边有 1/3/5/满 的快选）
#   ② 炉位从"一排小键"改成**一行一炉**：已开的写状态（谁在炼、炼什么、还剩多久／成了），
#      没开的写「**未解锁 · 需要 N 银两**」＋一颗［开炉位］
#   ③ 丹方总览（滚动区）留着当"看一眼存量/材料"的地方；点它的［炼制］＝带着这门方子开弹窗
#
# v7（用户："一号炉 2号炉 栏太小了 还是老问题…下面选择炼制丹药有啥用？重复了去掉可以
#   留下更多空间…2号3号4号都不显示 只显示一栏解锁第二个丹炉需要多少银两，然后购买了就
#   解锁2号炉 以此类推…只显示有材料且可以练的丹药即可"）——四条：
#   ① 炉位那一列**放大**：一条 84 高（原来 36）、炉号 17 号字、状态 15 号字两行、
#      炼制中还给一条**进度条**；按钮 120×40 / 17 号字（原来 100×30 / 13 号字）。
#   ② 炉位列**改成可上下滑**（ScrollContainer，视口 320 高）——不再挤成一堆小框。
#   ③ **未解锁的炉位只留"下一炉"那一行**（写清要多少银两、够不够），开了它这一行就变成
#      "2 号炉"，再顶上来一行问"开 3 号炉要多少"——不再把 2/3/4/5 号炉全摆出来。
#   ④ 底下那一片「丹方总览」**整块去掉**（它跟［炼制丹药］弹窗重复，白白吃掉 112 高）；
#      腾出来的地方全给炉位列。弹窗里的丹方小键**只列现在有料能炼的**（at least 一颗），
#      一门都炼不了时就写一句"药材不够"，不摆一排点不动的空方子。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")   # v61：tap_in_scroll（滚动区里可滑可点）

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const _GOLD := Color(0.72, 0.52, 0.14)   # 金色材料那一行的颜色

const PANEL_W := 640.0
# v8（用户："炼丹房的按钮和横栏框也可以再大一点"）：面板从 730 长到 **1000**
#   ——屏是 720×1280，730 只占了中间一块，白空着；长高之后每一段都能放大一圈：
#   ［炼制丹药］160×48 → **208×60**、炉位那一行 84 → **104**（按钮 120×40 → **140×56**、
#   炉号 17→20、状态 15→17、进度条 10→14）、看火四颗 120×44 → **120×58**、
#   ［关闭］200×48 → **240×64**，炼制弹窗里的键也跟着放大。
const PANEL_H := 1000.0
# v7：炉位那一列（放大 + 可上下滑）
const FR_H := 104.0          # 一条炉位有多高（v8：84 → 104）
const FR_SEP := 10.0
const FR_INNER_W := 564.0    # 滚动区里一行有多宽（右边给滚动条留位）
const FR_VIEW_Y := 124.0     # 滚动区
const FR_VIEW_H := 420.0

signal closed

class FurnaceScene extends Node2D:
	var t := 0.0
	var state := 0          # 0 闲 / 1 炼制中 / 2 丹成
	var has_tender := false

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 584, 92), Color(0.93, 0.90, 0.83, 0.85))
		draw_colored_polygon(PackedVector2Array([Vector2(-10, 92), Vector2(120, 40), Vector2(300, 92)]), Color(0.16, 0.14, 0.13, 0.35))
		draw_colored_polygon(PackedVector2Array([Vector2(260, 92), Vector2(420, 28), Vector2(596, 92)]), Color(0.13, 0.11, 0.11, 0.45))
		draw_line(Vector2(0, 92), Vector2(584, 92), Color(0.30, 0.24, 0.18, 0.55), 2.0)
		var cx := 292.0
		if has_tender:
			var px := cx - 86.0
			var fw := sin(t * (5.0 if state == 1 else 3.0)) * 3.0
			var body := Color(0.20, 0.19, 0.23, 0.90)
			draw_circle(Vector2(px, 62.0), 8.0, Color(0.93, 0.89, 0.82, 0.95))
			draw_line(Vector2(px, 70.0), Vector2(px, 82.0), body, 4.0)
			draw_line(Vector2(px, 82.0), Vector2(px - 5.0, 90.0), body, 3.0)
			draw_line(Vector2(px, 82.0), Vector2(px + 5.0, 90.0), body, 3.0)
			draw_line(Vector2(px + 6.0, 74.0), Vector2(px + 15.0, 68.0 + fw), Color(0.44, 0.32, 0.20, 0.85), 2.0)
		draw_rect(Rect2(cx - 44, 44, 88, 42), Color(0.30, 0.27, 0.25, 0.98))
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 52, 46), Vector2(cx - 30, 26), Vector2(cx + 30, 26), Vector2(cx + 52, 46)]), Color(0.36, 0.32, 0.29, 0.98))
		draw_line(Vector2(cx - 14, 44), Vector2(cx - 14, 26), Color(0.22, 0.19, 0.17, 0.9), 2.0)
		draw_line(Vector2(cx + 14, 44), Vector2(cx + 14, 26), Color(0.22, 0.19, 0.17, 0.9), 2.0)
		var g := 0.5 + 0.5 * sin(t * (3.0 + 1.5 * float(state)))
		var fire_r := 10.0 + 2.0 * float(state)
		draw_circle(Vector2(cx, 66), fire_r + 3.0 * g, Color(0.90, 0.55, 0.20, 0.25 + 0.10 * float(state) + 0.30 * g))
		draw_circle(Vector2(cx, 66), 5.0 + 1.5 * float(state) + 2.0 * g, Color(0.98, 0.82, 0.42, 0.45 + 0.08 * float(state) + 0.35 * g))
		if state == 2:
			draw_arc(Vector2(cx, 58.0), 21.0 + 3.0 * g, 0.0, TAU, 22, Color(0.95, 0.78, 0.30, 0.35 + 0.25 * g), 2.0)
		var smoke_spd := 0.35 + 0.25 * float(state)
		for i in 3:
			var ph := fmod(t * smoke_spd + float(i) * 0.33, 1.0)
			draw_circle(Vector2(cx - 6.0 + sin(ph * 6.0 + float(i)) * 12.0, 30.0 - ph * 34.0), 5.0 * (1.0 - ph) + 2.0, Color(0.60, 0.58, 0.55, 0.35 * (1.0 - ph)))
		draw_rect(Rect2(cx - 62, 84, 124, 6), Color(0.24, 0.20, 0.17, 0.9))

var _panel: Panel
var _scene: FurnaceScene
var _mat_lb: Label
var _gold_lb: Label
var _brew_btn: Button            # v6：［炼制丹药］（开弹窗）
var _fr_rows: Array = []         # v6：一行一炉（v7：多出一行给"下一炉"）
var _fr_scroll: ScrollContainer  # v7：炉位列可上下滑
var _fr_list: VBoxContainer
var _slot := 0                   # 当前选中的炉位
var _msg_lb: Label
var _tender := ""
var _tend_lb: Label
var _tend_hint: Label
var _tend_btns: Array = []
var _note_lb: Label
var _tick := 0.0
# ---- v6：炼制弹窗 ----
var _dlg: Control = null
var _dlg_pick := ""              # 弹窗里选中的丹方
var _dlg_chips: Array = []       # 丹方小键
var _dlg_cnt_lb: Label
var _dlg_in: LineEdit
var _dlg_prev: Label
var _dlg_ok: Button

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	refresh()
	visible = get_parent() == get_tree().root

func _process(delta: float) -> void:
	if not visible:
		return
	_tick += delta
	if _tick >= 0.5:
		_tick = 0.0
		refresh()

# ══════════════════════════════════════════════════════════
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

	var title := _label("炼丹阁", 34, INK)
	title.position = Vector2(32, 20)
	title.size = Vector2(240, 48)
	_panel.add_child(title)

	# v6：主路径就这一颗——点它开弹窗（选丹 → 选颗数 → 开始炼丹）
	_brew_btn = Button.new()
	_brew_btn.text = "炼制丹药"
	_brew_btn.focus_mode = Control.FOCUS_NONE
	_brew_btn.position = Vector2(400, 14)
	_brew_btn.size = Vector2(208, 60)
	_brew_btn.add_theme_font_size_override("font_size", 24)
	_brew_btn.pressed.connect(_open_dlg)
	_style_seal(_brew_btn)
	_panel.add_child(_brew_btn)

	# ---- 材料行（金色材料单独一行金字）----
	_mat_lb = _label("", 15, Color(INK.r, INK.g, INK.b, 0.70))
	_mat_lb.position = Vector2(32, 84)
	_mat_lb.size = Vector2(400, 26)
	_panel.add_child(_mat_lb)
	_gold_lb = _label("", 15, _GOLD)
	_gold_lb.position = Vector2(436, 84)
	_gold_lb.size = Vector2(172, 26)
	_gold_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_gold_lb)

	# ---- 炉位：一行一炉，**可上下滑**（v7）----
	#   只摆两类行：① 已经开的炉（写状态／进度／按钮）② "下一炉"那一行（写开它要多少银两）。
	#   再往后的炉位不摆出来——开了这一行，下一行自己顶上来。
	_fr_scroll = ScrollContainer.new()
	UiKit.drag_scroll(_fr_scroll)
	_fr_scroll.position = Vector2(32, FR_VIEW_Y)
	_fr_scroll.size = Vector2(PANEL_W - 64.0, FR_VIEW_H)
	_fr_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_fr_scroll)
	_fr_list = VBoxContainer.new()
	_fr_list.custom_minimum_size = Vector2(FR_INNER_W, 0)
	_fr_list.add_theme_constant_override("separation", int(FR_SEP))
	_fr_scroll.add_child(_fr_list)
	_fr_rows = []
	for i in GameState.FURNACE_MAX + 1:      # 最后一格留给"下一炉"那一行
		var row := Panel.new()
		row.custom_minimum_size = Vector2(0, FR_H)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(1, 1, 1, 0.42)
		rsb.set_corner_radius_all(10)
		rsb.border_color = Color(INK.r, INK.g, INK.b, 0.20)
		rsb.set_border_width_all(1)
		row.add_theme_stylebox_override("panel", rsb)
		_fr_list.add_child(row)
		var no := _label("", 20, INK)
		no.position = Vector2(14, 14)
		no.size = Vector2(84, 30)
		row.add_child(no)
		var st := _label("", 17, Color(INK.r, INK.g, INK.b, 0.80))
		st.position = Vector2(104, 10)
		st.size = Vector2(296, 60)
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(st)
		var pb := ProgressBar.new()
		# ⚠ 探针量出来的：ProgressBar 自己有"最小高度"（这版主题算出来 27），
		#   写 14 也会被撑回 27——所以按 26 摆位（y 72..98，仍在 104 的行里）。
		pb.position = Vector2(104, 72)
		pb.size = Vector2(288, 26)
		pb.min_value = 0.0
		pb.max_value = 100.0
		pb.value = 0.0
		pb.show_percentage = false
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pbg := _flat(Color(INK.r, INK.g, INK.b, 0.14))
		pbg.set_corner_radius_all(7)
		var pbf := _flat(Color(0.90, 0.55, 0.20, 0.92))
		pbf.set_corner_radius_all(7)
		pb.add_theme_stylebox_override("background", pbg)
		pb.add_theme_stylebox_override("fill", pbf)
		row.add_child(pb)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(FR_INNER_W - 152.0, 24)
		b.size = Vector2(140, 56)
		b.add_theme_font_size_override("font_size", 20)
		# v61（手游）：炉位在滚动区里——走"拖得动、点得准"那一口（原来手指一按就滑不动、松手还误触）
		UiKit.tap_in_scroll(b, _on_furnace_btn.bind(i))
		_style_dark(b)
		row.add_child(b)
		_fr_rows.append({"row": row, "no": no, "st": st, "bar": pb, "btn": b})

	# 炉火小景（三态 + 看火人）
	_scene = FurnaceScene.new()
	_scene.position = Vector2(32, 560)
	_scene.scale = Vector2(0.9, 0.9)
	_panel.add_child(_scene)

	# ---- 看火：派谁去看炉子（必须下战） ----
	_tend_lb = _label("看火：", 18, Color(INK.r, INK.g, INK.b, 0.62))
	_tend_lb.position = Vector2(32, 666)
	_tend_lb.size = Vector2(66, 36)
	_panel.add_child(_tend_lb)
	_tend_btns = []
	var tend_list := [
		{"id": "", "name": "没人"},
		{"id": "player", "name": "少侠"},
		{"id": "chen_shi", "name": "陈石"},
		{"id": "qingluan", "name": "苏青鸾"},
	]
	for k in tend_list.size():
		var it: Dictionary = tend_list[k]
		var tb := Button.new()
		tb.text = str(it["name"])
		tb.position = Vector2(104.0 + float(k) * 128.0, 658)
		tb.size = Vector2(120, 58)
		tb.add_theme_font_size_override("font_size", 18)
		tb.focus_mode = Control.FOCUS_NONE
		tb.pressed.connect(_on_tend.bind(str(it["id"])))
		_panel.add_child(tb)
		_tend_btns.append({"id": str(it["id"]), "btn": tb})
	_tend_hint = _label("看火要下战（先出阵容；在阵里点了会被拦）。效率：陈石 ×0.7 · 青鸾 ×0.8 · 少侠 ×0.85 · 没人 ×1.0；每收一炉，看火的人 +20 经验/颗。", 13, Color(INK.r, INK.g, INK.b, 0.55))
	_tend_hint.position = Vector2(32, 728)
	_tend_hint.size = Vector2(PANEL_W - 64.0, 36)
	_tend_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_tend_hint)

	_note_lb = _label("服用：「弟子」面板选中人 → 点右下「服药」格。每人每境限量：属性丹 3 颗——每突破一重（境界 +1，25 级）扩容。", 13, Color(INK.r, INK.g, INK.b, 0.62))
	_note_lb.position = Vector2(32, 772)
	_note_lb.size = Vector2(PANEL_W - 64.0, 40)
	_note_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_note_lb)

	_msg_lb = _label("", 14, Color(SEAL.r, SEAL.g, SEAL.b, 0.92))
	_msg_lb.position = Vector2(32, 820)
	_msg_lb.size = Vector2(PANEL_W - 64.0, 44)
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_msg_lb)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(368, 892)
	close_btn.size = Vector2(240, 64)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	_style_dark(close_btn)
	_panel.add_child(close_btn)

# ══════════════════════════════════════════════════════════
# v6：炼制弹窗——选丹 → 选颗数 → 开始炼丹
# v7：**只列现在有料能炼的丹**（至少炼得出一颗）；一门都炼不了就写一句"药材不够"。
#     弹窗高度按实际列几行算（列得少就矮一点，不摆一大片空框）。
# ══════════════════════════════════════════════════════════
func _open_dlg(rid := "") -> void:
	_close_dlg()
	var avail := _craftable()
	_dlg_pick = rid if avail.has(rid) else ("" if avail.is_empty() else str(avail[0]))

	# 先算要几行丹方，才能定弹窗多高（v8：每行 62 高；一门都没有就留一块提示）
	var rows_n := int(ceil(float(avail.size()) / 2.0))
	var chips_h := 62.0 * float(rows_n) if rows_n > 0 else 104.0
	var pw := 660.0
	var ph := clampf(340.0 + chips_h, 440.0, 660.0)

	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.45)
	veil.size = size
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(_on_dlg_blank)
	add_child(veil)
	_dlg = veil
	var box := Panel.new()
	box.position = Vector2((size.x - pw) * 0.5, (size.y - ph) * 0.5)
	box.size = Vector2(pw, ph)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_theme_stylebox_override("panel", _soft_sb())
	veil.add_child(box)

	var t1 := _label("炼制丹药", 30, INK)
	t1.position = Vector2(0, 14)
	t1.size = Vector2(pw, 38)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t1)
	var t2 := _label("① 选丹药　② 选颗数　③ 开始炼丹（看火的人在上面那排选）", 15, Color(INK.r, INK.g, INK.b, 0.60))
	t2.position = Vector2(0, 52)
	t2.size = Vector2(pw, 26)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t2)

	# ① 丹方小键（两列；带存量）——v7：只摆"有料能炼"的
	_dlg_chips = []
	var y0 := 88.0
	if avail.is_empty():
		var none_lb := _label("现在没有能炼的丹——药材不够。\n去仓库数数：紫芝 / 雪参 / 朱果 / 兽骨碎 / 灵米 / 木料（金髓只有宝箱与搜刮里出）", 17, Color(INK.r, INK.g, INK.b, 0.72))
		none_lb.position = Vector2(24, y0 + 6)
		none_lb.size = Vector2(pw - 48.0, 92)
		none_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(none_lb)
	else:
		for k in avail.size():
			var rid_k := str(avail[k])
			var r2: Dictionary = GameState.recipe_of(rid_k)
			var col := k % 2
			var rowi := k / 2
			var cb := Button.new()
			cb.focus_mode = Control.FOCUS_NONE
			cb.position = Vector2(24.0 + float(col) * 312.0, y0 + float(rowi) * 62.0)
			cb.size = Vector2(300, 56)
			cb.add_theme_font_size_override("font_size", 18)
			cb.pressed.connect(_on_dlg_pick.bind(rid_k))
			box.add_child(cb)
			_dlg_chips.append({"id": rid_k, "btn": cb})
	var y_cnt := y0 + chips_h + 8.0

	# ② 颗数：−／直接输入／＋ ＋ 快选
	_dlg_cnt_lb = _label("颗数", 18, Color(INK.r, INK.g, INK.b, 0.72))
	_dlg_cnt_lb.position = Vector2(24, y_cnt + 8)
	_dlg_cnt_lb.size = Vector2(60, 34)
	box.add_child(_dlg_cnt_lb)
	var minus := Button.new()
	minus.text = "−"
	minus.focus_mode = Control.FOCUS_NONE
	minus.position = Vector2(92, y_cnt)
	minus.size = Vector2(56, 46)
	minus.add_theme_font_size_override("font_size", 24)
	minus.pressed.connect(_on_dlg_count.bind(-1))
	_style_dark(minus)
	box.add_child(minus)
	_dlg_in = LineEdit.new()
	_dlg_in.position = Vector2(154, y_cnt)
	_dlg_in.size = Vector2(84, 46)
	_dlg_in.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dlg_in.max_length = 2
	_dlg_in.virtual_keyboard_enabled = true
	_dlg_in.add_theme_font_size_override("font_size", 22)
	_dlg_in.text_changed.connect(_on_dlg_input)
	box.add_child(_dlg_in)
	var plus := Button.new()
	plus.text = "＋"
	plus.focus_mode = Control.FOCUS_NONE
	plus.position = Vector2(244, y_cnt)
	plus.size = Vector2(56, 46)
	plus.add_theme_font_size_override("font_size", 24)
	plus.pressed.connect(_on_dlg_count.bind(1))
	_style_dark(plus)
	box.add_child(plus)
	var quick := [1, 3, 5]
	for q in quick.size():
		var qb := Button.new()
		qb.text = "×" + str(quick[q])
		qb.focus_mode = Control.FOCUS_NONE
		qb.position = Vector2(316.0 + float(q) * 74.0, y_cnt)
		qb.size = Vector2(68, 46)
		qb.add_theme_font_size_override("font_size", 17)
		qb.pressed.connect(_on_dlg_set.bind(int(quick[q])))
		_style_dark(qb)
		box.add_child(qb)
	var maxb := Button.new()
	maxb.text = "满"
	maxb.focus_mode = Control.FOCUS_NONE
	maxb.position = Vector2(316.0 + 3.0 * 74.0, y_cnt)
	maxb.size = Vector2(68, 46)
	maxb.add_theme_font_size_override("font_size", 17)
	maxb.pressed.connect(_on_dlg_set.bind(GameState.ALCHEMY_BATCH_MAX))
	_style_dark(maxb)
	box.add_child(maxb)

	# ③ 预览 + 开始
	_dlg_prev = _label("", 15, Color(INK.r, INK.g, INK.b, 0.78))
	_dlg_prev.position = Vector2(24, y_cnt + 58.0)
	_dlg_prev.size = Vector2(pw - 48.0, 84)
	_dlg_prev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_dlg_prev)
	_dlg_ok = Button.new()
	_dlg_ok.text = "开始炼丹"
	_dlg_ok.focus_mode = Control.FOCUS_NONE
	_dlg_ok.position = Vector2(36, ph - 76.0)
	_dlg_ok.size = Vector2(280, 60)
	_dlg_ok.add_theme_font_size_override("font_size", 22)
	_dlg_ok.pressed.connect(_on_dlg_go)
	_style_seal(_dlg_ok)
	box.add_child(_dlg_ok)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.position = Vector2(pw - 316.0, ph - 76.0)
	cancel.size = Vector2(280, 60)
	cancel.add_theme_font_size_override("font_size", 22)
	cancel.pressed.connect(_close_dlg)
	_style_dark(cancel)
	box.add_child(cancel)

	_dlg_in.text = str(_dlg_count())
	_refresh_dlg()

func _can_pay(rid: String, count: int) -> bool:
	var r: Dictionary = GameState.recipe_of(rid)
	if r.is_empty():
		return false
	for k in (r.get("cost", {}) as Dictionary).keys():
		if GameState.material_count(str(k)) < int(r["cost"][k]) * maxi(1, count):
			return false
	return true

# v7：现在"有料、开得动炉"的丹（至少炼得出一颗）——弹窗只列这些，
#   省得摆一堆点了才说"缺材料"的空方子。材料够几颗由颗数那一栏现算。
func _craftable() -> Array:
	var out: Array = []
	for r_v in GameState.DAN_RECIPES:
		var r: Dictionary = r_v
		if bool(r.get("loot_only", false)):
			continue
		var rid := str(r.get("id", ""))
		if _can_pay(rid, 1):
			out.append(rid)
	return out

# 弹窗里现在的颗数（输入框优先，空/非法就回落 1）
func _dlg_count() -> int:
	if _dlg_in == null:
		return 1
	return clampi(int(_dlg_in.text.to_int()), 1, GameState.ALCHEMY_BATCH_MAX)

func _refresh_dlg() -> void:
	if _dlg == null:
		return
	var n := _dlg_count()
	for c_v in _dlg_chips:
		var c: Dictionary = c_v
		var rid := str(c["id"])
		var r: Dictionary = GameState.recipe_of(rid)
		var btn: Button = c["btn"]
		var need: Dictionary = {}
		for k in (r.get("cost", {}) as Dictionary).keys():
			need[str(k)] = int(r["cost"][k]) * n
		var ok := _can_pay(rid, n)
		btn.text = str(r.get("name", rid)) + "　存" + str(GameState.pill_count(rid)) + ("" if ok else "（料不够）")
		btn.disabled = false   # 料不够也点得动——点一下会告诉玩家缺什么
		_style_tab(btn, rid == _dlg_pick)
	_dlg_cnt_lb.text = "颗数"
	var rid2 := _dlg_pick
	if rid2 == "" or GameState.recipe_of(rid2).is_empty():
		_dlg_prev.text = ("一门都炼不了——先把药材凑够（紫芝 / 雪参 / 朱果 / 兽骨碎 / 灵米 / 木料，洗灵丹还要金髓）"
			if _dlg_chips.is_empty() else "先选一门丹药")
		_dlg_ok.disabled = true
		return
	var r2: Dictionary = GameState.recipe_of(rid2)
	var need2: Dictionary = {}
	for k2 in (r2.get("cost", {}) as Dictionary).keys():
		need2[str(k2)] = int(r2["cost"][k2]) * n
	var mins := GameState.batch_minutes(rid2, n, _tender)
	var slot := _slot if not GameState.furnace_is_busy(_slot) else GameState.furnace_free()
	var where := "第 " + str(slot + 1) + " 号炉" if slot >= 0 else "**炉位占满**（先收一炉，或开个新炉位）"
	_dlg_prev.text = ("选的是「" + str(r2.get("name", rid2)) + "」×" + str(n)
		+ "　·　材料：" + GameState.cost_text(need2) + "（现有：" + GameState.cost_text(_mine(need2)) + "）"
		+ "\n炉时约 " + str(snappedf(mins, 0.1)) + " 分（" + ("没人看火 ×1.0" if _tender == "" else GameState.tend_name(_tender) + "看火 ×" + str(snappedf(GameState.tend_mul(_tender), 0.05))) + "）"
		+ "　·　下到 " + where)
	var can := _can_pay(rid2, n) and slot >= 0
	_dlg_ok.disabled = not can

func _mine(need: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in need.keys():
		out[str(k)] = GameState.material_count(str(k))
	return out

func _on_dlg_pick(rid: String) -> void:
	_dlg_pick = rid
	_refresh_dlg()

func _on_dlg_count(d: int) -> void:
	_on_dlg_set(_dlg_count() + d)

func _on_dlg_set(n: int) -> void:
	if _dlg_in == null:
		return
	_dlg_in.text = str(clampi(n, 1, GameState.ALCHEMY_BATCH_MAX))
	_refresh_dlg()

func _on_dlg_input(_s: String) -> void:
	_refresh_dlg()

func _on_dlg_go() -> void:
	var n := _dlg_count()
	var slot := _slot if not GameState.furnace_is_busy(_slot) else GameState.furnace_free()
	var msg := GameState.alchemy_start(_dlg_pick, _tender, n, slot)
	_msg_lb.text = msg
	_close_dlg()
	refresh()

func _on_dlg_blank(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close_dlg()

func _close_dlg() -> void:
	if _dlg != null and is_instance_valid(_dlg):
		_dlg.queue_free()
	_dlg = null

# ══════════════════════════════════════════════════════════
# 丹方总览：一行一方（存量/材料/时长）＋［炼制］＝带方子开弹窗
# ══════════════════════════════════════════════════════════
# v7：**丹方总览那一块整块去掉了**（用户："下面选择炼制丹药有啥用？重复了"）——
#   选丹 / 看存量 / 看材料需求都在［炼制丹药］的弹窗里，这里不再摆第二份。
# ══════════════════════════════════════════════════════════
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

func _soft_sb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.99)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.32, 0.27, 0.22, 0.60)
	sb.set_border_width_all(2)
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
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.35)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.50))

func _style_tab(btn: Button, selected: bool) -> void:
	if selected:
		btn.add_theme_stylebox_override("normal", _flat(Color(INK.r, INK.g, INK.b, 0.92)))
		btn.add_theme_stylebox_override("hover", _flat(Color(INK.r, INK.g, INK.b, 0.85)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.90)))
		btn.add_theme_color_override("font_color", PAPER)
		btn.add_theme_color_override("font_hover_color", PAPER)
	else:
		btn.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.35)))
		btn.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.55)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.60)))
		btn.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.78))
		btn.add_theme_color_override("font_hover_color", INK)
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))

func _fmt_sec(s: int) -> String:
	if s >= 60:
		return str(s / 60) + " 分 " + str(s % 60) + " 秒"
	return str(s) + " 秒"

func _auto_tender() -> String:
	if GameState.disciple_joined and not GameState.is_deployed("chen_shi"):
		return "chen_shi"
	if GameState.qingluan_joined and not GameState.is_deployed("qingluan"):
		return "qingluan"
	return ""

# ══════════════════════════════════════════════════════════
func refresh() -> void:
	if _panel == null:
		return
	if _tender == "chen_shi" and not GameState.disciple_joined:
		_tender = ""
	if _tender == "qingluan" and not GameState.qingluan_joined:
		_tender = ""
	_mat_lb.text = "药材：紫芝 " + str(GameState.material_count("zhi")) + " · 雪参 " + str(GameState.material_count("shen")) + " · 朱果 " + str(GameState.material_count("guo")) + " ｜ 兽骨碎 " + str(GameState.material_count("bone")) + " · 灵米 " + str(GameState.material_count("rice")) + " ｜ 木料 " + str(GameState.material_count("wood"))
	# v62b（用户："洗灵丹丹方 材料全部去掉"）：洗灵丹不再吃料，所以这句不再写"洗灵丹要它"——
	#   金髓眼下没有丹方在用（材料/宝箱权重/货栈那件都留着），如实标注即可。
	_gold_lb.text = "◆金髓 " + str(GameState.material_count("jin")) + "（稀有料·暂无丹方要用）"
	# 选中的炉位：越界/没了就落回 0；有"丹成了"就先看那一炉
	_slot = clampi(_slot, 0, GameState.furnace_count() - 1)
	var ready_slots := GameState.alchemy_ready_slots()
	if not ready_slots.is_empty() and not ready_slots.has(_slot):
		_slot = int(ready_slots[0])
	# ---- 炉位那一列（v7：只摆已开的炉 + "下一炉"那一行）----
	var fcnt := GameState.furnace_count()
	var silver := GameState.coin("silver")
	for i in _fr_rows.size():
		var e: Dictionary = _fr_rows[i]
		var row: Panel = e["row"]
		var no: Label = e["no"]
		var st: Label = e["st"]
		var bar: ProgressBar = e["bar"]
		var btn: Button = e["btn"]
		# 已开的炉都摆；再多摆一行"下一炉"（问价）；更后面的炉位不出现
		if i > fcnt or (i == fcnt and fcnt >= GameState.FURNACE_MAX):
			row.visible = false
			continue
		row.visible = true
		bar.visible = false
		if i == fcnt:
			# v7：**未解锁只留这一行**——开了它，这一行就变成"2 号炉"，下一行自己顶上来
			var price := GameState.furnace_cost_next()
			no.text = str(i + 1) + "号炉"
			st.text = "未解锁 · 需要 " + str(price) + " 银两（现有 " + str(silver) + "）\n开了它就能同时炼两炉"
			st.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.50))
			btn.text = "开炉位"
			btn.disabled = silver < price
			_style_tab(btn, false)
			continue
		var f: Dictionary = GameState.furnace_at(i)
		no.text = str(i + 1) + "号炉"
		if f.is_empty():
			st.text = "空闲" + ("　现在选的是这一炉" if i == _slot else "　点［选中］把新丹下到这一炉")
			st.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.55))
			btn.text = "已选中" if i == _slot else "选中"
			btn.disabled = (i == _slot)
		else:
			var rid := str(f.get("recipe", ""))
			var rr := GameState.recipe_of(rid)
			var n := maxi(1, int(f.get("count", 1)))
			var rem := GameState.alchemy_remain_sec(i)
			var tn := str(f.get("tender", ""))
			var tw := "" if tn == "" else "　" + GameState.tend_name(tn) + "看火"
			if rem > 0:
				# 进度条：总炉时 = 这一炉的单子（含看火折扣与多颗折扣）
				var total := maxf(1.0, GameState.batch_minutes(rid, n, tn) * 60.0)
				bar.value = clampf(1.0 - float(rem) / total, 0.0, 1.0) * 100.0
				bar.visible = true
				st.text = "「" + str(rr.get("name", rid)) + "」×" + str(n) + " 正在炼制 · 剩 " + _fmt_sec(rem) + tw
				st.add_theme_color_override("font_color", INK)
				btn.text = "看这炉"
				btn.disabled = false
			else:
				st.text = "「" + str(rr.get("name", rid)) + "」×" + str(n) + " 丹成了——点［收丹］收进仓库" + tw
				st.add_theme_color_override("font_color", SEAL)
				btn.text = "收丹"
				btn.disabled = false
		_style_tab(btn, i == _slot)
	# 炉火小景：按选中的那一炉画三态 + 看火人
	var busy := GameState.furnace_is_busy(_slot)
	var rem2 := GameState.alchemy_remain_sec(_slot) if busy else 0
	var shown := str(GameState.furnace_at(_slot).get("tender", "")) if busy else _tender
	_scene.state = 0
	if busy:
		_scene.state = 2 if rem2 <= 0 else 1
	_scene.has_tender = shown != ""
	# 看火按钮
	for t in _tend_btns:
		var tid := str(t["id"])
		var tb: Button = t["btn"]
		if tid == "chen_shi":
			tb.visible = GameState.disciple_joined
		elif tid == "qingluan":
			tb.visible = GameState.qingluan_joined
		else:
			tb.visible = true
		if tid != "":
			if GameState.is_deployed(tid):
				tb.text = GameState.tend_name(tid) + "·战中"
			else:
				tb.text = GameState.tend_name(tid)
		_style_tab(tb, tid == _tender)

func _on_furnace_btn(i: int) -> void:
	if i >= GameState.furnace_count():
		# 未解锁那一行：开炉位
		var r: Dictionary = GameState.furnace_unlock()
		_msg_lb.text = str(r.get("msg", ""))
		if bool(r.get("ok", false)):
			_slot = GameState.furnace_count() - 1
		refresh()
		_sync_scroll()
		return
	var f: Dictionary = GameState.furnace_at(i)
	if not f.is_empty() and GameState.alchemy_remain_sec(i) <= 0:
		var c: Dictionary = GameState.alchemy_collect(i)   # 丹成了 → 直接收
		_msg_lb.text = str(c.get("msg", ""))
		refresh()
		return
	_slot = i
	_msg_lb.text = "看第 " + str(i + 1) + " 号炉"
	refresh()

func _on_tend(id: String) -> void:
	var why := GameState.can_tend(id)
	if why != "":
		_msg_lb.text = why
		return
	_tender = id
	var txt := "看火：" + GameState.tend_name(id)
	if id != "":
		txt += "（×" + str(snappedf(GameState.tend_mul(id), 0.05)) + "）——开炉时他就站炉边了"
	else:
		txt += "（没人看火，慢些）"
	_msg_lb.text = txt
	refresh()

# v7：把选中的那一炉滚进可视区（刚开完炉位／丹成自动跳过去时用）
func _sync_scroll() -> void:
	if _fr_scroll == null or _fr_rows.is_empty():
		return
	var i := clampi(_slot, 0, _fr_rows.size() - 1)
	var row: Panel = _fr_rows[i]["row"]
	if row != null and row.visible:
		_fr_scroll.ensure_control_visible(row)

func open() -> void:
	_msg_lb.text = ""
	if _tender == "":
		_tender = _auto_tender()
	refresh()
	visible = true
	_sync_scroll()

func close() -> void:
	if not visible:
		return
	_close_dlg()
	visible = false
	closed.emit()

func _gui_input(event: InputEvent) -> void:
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
			if _dlg != null:
				_close_dlg()
				return
			close()
