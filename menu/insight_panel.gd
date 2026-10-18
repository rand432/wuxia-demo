extends Control
# ============================================================
# insight_panel.gd —— **阅历线**面板 v2（四支 × 32 段 · 每第 4 段是大节点）
#
# 用户："四种 32 个节点 每第四个一个大节点 可以同时四条线都走 ·（入口用底排那一格）·
#   要洗点但是消耗银两"
#
# 这一页：顶上报数 → **四个页签**（各 32 行，可滚）→ 底排［洗点］［关闭］。
#   大节点描金边、标「大」；已通写"已通"，没轮到的写"先通上一段"。
# 表与价目**只读 shared/data_insight.gd**——这一页里不许出现任何数字。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const Insight := preload("res://shared/data_insight.gd")
const UiKit := preload("res://shared/ui_kit.gd")

signal closed

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const GOLD := Color(0.72, 0.55, 0.18)

var _panel: Panel
var _top_lb: Label
var _msg_lb: Label
var _respec_btn: Button = null
var _body: Control = null
var _tab_btns: Array = []
var _tab := "wealth"
var _ph := 1040.0
var _pw := 680.0

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = get_parent() == get_tree().root

func _build() -> void:
	var vp := get_viewport_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = vp
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# v3（用户："阅历横框可以大一点【至少一倍】"）：面板铺到近满屏（宽 700 / 高 屏高-40），
	#   行高与字号整体**翻倍**——手机上看得清、点得着。
	_ph = clampf(vp.y - 40.0, 520.0, 1240.0)
	_pw = minf(vp.x - 20.0, 700.0)
	_panel = Panel.new()
	_panel.position = Vector2((vp.x - _pw) * 0.5, (vp.y - _ph) * 0.5)
	_panel.size = Vector2(_pw, _ph)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.98)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	psb.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", psb)
	add_child(_panel)

	var title := _label("阅　历", 36, INK)
	title.position = Vector2(30, 16)
	title.size = Vector2(360, 48)
	_panel.add_child(title)

	_top_lb = _label("", 20, Color(INK.r, INK.g, INK.b, 0.78))
	_top_lb.position = Vector2(32, 68)
	_top_lb.size = Vector2(_pw - 64.0, 30)
	_panel.add_child(_top_lb)

	# ---- 四个页签（每个 ~160 宽、52 高）----
	_tab_btns = []
	var tw := (_pw - 40.0 - 18.0) / 4.0
	for i in Insight.BRANCHES.size():
		var b: Dictionary = Insight.BRANCHES[i]
		var bid := str(b.get("id", ""))
		var tb := Button.new()
		tb.position = Vector2(20.0 + float(i) * (tw + 6.0), 104)
		tb.size = Vector2(tw, 52)
		tb.add_theme_font_size_override("font_size", 19)
		tb.focus_mode = Control.FOCUS_NONE
		tb.pressed.connect(_on_tab.bind(bid))
		_style_light(tb)
		_panel.add_child(tb)
		_tab_btns.append(tb)

	_msg_lb = _label("", 19, Color(SEAL.r, SEAL.g, SEAL.b, 0.95))
	_msg_lb.position = Vector2(32, _ph - 88.0)
	_msg_lb.size = Vector2(_pw - 64.0, 28)
	_panel.add_child(_msg_lb)

	var by := _ph - 72.0
	_respec_btn = Button.new()
	_respec_btn.position = Vector2(20, by)
	_respec_btn.size = Vector2(_pw - 40.0 - 150.0, 58)
	_respec_btn.add_theme_font_size_override("font_size", 19)
	_respec_btn.focus_mode = Control.FOCUS_NONE
	_respec_btn.pressed.connect(_on_respec)
	_style_light(_respec_btn)
	_panel.add_child(_respec_btn)

	var cl := Button.new()
	cl.text = "关闭"
	cl.position = Vector2(_pw - 20.0 - 140.0, by)
	cl.size = Vector2(140, 58)
	cl.add_theme_font_size_override("font_size", 21)
	cl.focus_mode = Control.FOCUS_NONE
	cl.pressed.connect(close)
	_style_dark(cl)
	_panel.add_child(cl)

	refresh()

func refresh() -> void:
	if _panel == null:
		return
	var total := Insight.total_lv(GameState.insight_lv)
	var all_max := 0
	for b_v in Insight.BRANCHES:
		all_max += Insight.max_lv(str((b_v as Dictionary).get("id", "")))
	UiKit.set_text(_top_lb, "现有阅历 " + str(GameState.insight) + " 点　·　挂机 +"
		+ str(snappedf(GameState.insight_rate(), 0.1)) + "/分（第 " + str(GameState.idle_tier() + 1)
		+ " 档）　·　总计 " + str(total) + "/" + str(all_max))
	for i in _tab_btns.size():
		var b: Dictionary = Insight.BRANCHES[i]
		var bid := str(b.get("id", ""))
		UiKit.set_btn_text(_tab_btns[i],
			str(b.get("name", "")) + " " + str(GameState.insight_lv_of(bid)) + "/" + str(Insight.max_lv(bid)))
		_style_pick(_tab_btns[i], bid == _tab)
	var fee := GameState.insight_respec_cost()
	if total <= 0:
		_respec_btn.disabled = true
		UiKit.set_btn_text(_respec_btn, "洗点：还没点过")
	else:
		_respec_btn.disabled = false
		UiKit.set_btn_text(_respec_btn, "洗点（退全部阅历 · 手续费 " + str(fee) + " 两）")
	_rebuild()

func _rebuild() -> void:
	if _body != null and is_instance_valid(_body):
		_body.queue_free()
	_body = Control.new()
	_body.size = Vector2(_pw - 20.0, 10)
	# ⚠ 这一层**不能吃掉手指/鼠标事件**——不然"按住列表上下拖"传不到 ScrollContainer
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_body)

	var b := Insight.branch_of(_tab)
	var head := _label(str(b.get("name", "")) + "　·　" + str(b.get("sub", "")), 18,
		Color(INK.r, INK.g, INK.b, 0.62), true)
	head.position = Vector2(32, 160)
	head.size = Vector2(300, 26)          # ⚠ 要放得下"技巧　·　暴击 · 闪避 · 伤害增幅"（实测 250px）
	_body.add_child(head)
	var head2 := _label(str(b.get("desc", "")), 17, Color(INK.r, INK.g, INK.b, 0.55), true)
	head2.position = Vector2(340, 161)
	head2.size = Vector2(_pw - 372.0, 24)
	_body.add_child(head2)

	var scroll := ScrollContainer.new()
	UiKit.drag_scroll(scroll)          # v3：按住内容上下拖＝滚动（指尖滑动页面）
	scroll.position = Vector2(20, 192)
	scroll.size = Vector2(_pw - 40.0, _ph - 192.0 - 108.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# v15x（用户："所有滑动不要滑动进度条 用指尖滑动那种就可以了"）：
	#   强制藏掉滚动条（Godot 默认主题在内容超出时会冒出来）——拖拽滚动不受影响。
	scroll.get_v_scroll_bar().visible = false
	scroll.get_h_scroll_bar().visible = false
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(_pw - 60.0, 0)
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_PASS   # ⚠ PASS：事件继续往上传给 ScrollContainer
	scroll.add_child(box)

	var lv := GameState.insight_lv_of(_tab)
	# ⚠ 行的**实际**宽度＝面板宽 − 60（VBox 在滚动区里另有 20+20 边距）——
	#   靠右的东西一律按它定位，别再拿 _pw 当行宽（"字超出"就是这么来的）。
	# v3b 排版：第一行＝名字 ·（价格/状态）·［升级］；第二行＝说明（**自动换行**，两行封顶）。
	var rw := _pw - 60.0
	for i in Insight.max_lv(_tab):
		var nd := Insight.node_next(_tab, i)
		var big := Insight.is_big(i)
		var row := Panel.new()
		row.custom_minimum_size = Vector2(rw, 136.0 if big else 124.0)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var done := i < lv
		var cur := i == lv
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = (Color(0.90, 0.87, 0.80, 1.0) if done
			else (Color(0.96, 0.93, 0.86, 1.0) if cur else Color(0.93, 0.91, 0.86, 1.0)))
		rsb.set_corner_radius_all(10)
		rsb.border_color = (GOLD if (cur or big) else Color(INK.r, INK.g, INK.b, 0.28))
		rsb.set_border_width_all(4 if cur else (3 if big else 1))
		rsb.set_content_margin_all(8)
		row.add_theme_stylebox_override("panel", rsb)
		box.add_child(row)

		var nm := _label(("◆ " if big else "") + str(i + 1) + ". " + str(nd.get("name", "")), 26,
			(INK if not done else Color(INK.r, INK.g, INK.b, 0.45)), true)
		nm.position = Vector2(18, 8)
		nm.size = Vector2(rw - 400.0, 36)
		row.add_child(nm)

		# ⚠ v3c（用户："消耗显示不见了"）：价格必须**独占第一行右侧**——
		#   上一版把［升级］也放在第一行，按钮在标签之后入树＝画在上面，
		#   右对齐的价格正好被整块盖住（看着就是"消耗没了"）。
		#   现在：第一行＝名字 ＋ 价格（右侧）；第二行＝说明（左）＋［升级］（右）。
		var cost := Insight.cost_next(_tab, i)
		var ct := _label("阅历 " + str(cost.get("insight", 0)) + " · 银两 " + str(cost.get("silver", 0)),
			18, (Color(INK.r, INK.g, INK.b, 0.42) if done else Color(SEAL.r, SEAL.g, SEAL.b, 0.95)), true)
		ct.position = Vector2(rw - 380.0, 12)
		ct.size = Vector2(360, 28)
		ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(ct)
		if done:
			var tag := _label("已通", 22, Color(INK.r, INK.g, INK.b, 0.45), true)
			tag.position = Vector2(rw - 200.0, 62)
			tag.size = Vector2(180, 32)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(tag)
		elif i > lv:
			var lk := _label("先通上一段", 19, Color(INK.r, INK.g, INK.b, 0.45), true)
			lk.position = Vector2(rw - 210.0, 64)
			lk.size = Vector2(190, 30)
			lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(lk)
		else:
			var up := Button.new()
			up.text = "升级"
			up.position = Vector2(rw - 170.0, 60)
			up.size = Vector2(150, 50)
			up.add_theme_font_size_override("font_size", 22)
			up.focus_mode = Control.FOCUS_NONE
			up.pressed.connect(_on_upgrade.bind(_tab))
			_style_dark(up)
			row.add_child(up)

		# 说明：占满整行、**自动换行**（最多两行）——再长也不会顶出框外
		var ds := _label(str(nd.get("desc", "")), 18, Color(INK.r, INK.g, INK.b, 0.72))
		ds.position = Vector2(18, 58)
		ds.size = Vector2(rw - 220.0, 62)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.clip_text = true
		row.add_child(ds)

func _on_tab(bid: String) -> void:
	_tab = bid
	refresh()

func _on_upgrade(bid: String) -> void:
	var r := GameState.insight_upgrade(bid)
	_msg_lb.text = str(r.get("msg", ""))
	if bool(r.get("ok", false)):
		UiKit.float_text(self, "阅历线：" + str(r.get("msg", "")), GOLD)
	refresh()

func _on_respec() -> void:
	var r := GameState.insight_respec()
	_msg_lb.text = str(r.get("msg", ""))
	if bool(r.get("ok", false)):
		UiKit.float_text(self, str(r.get("msg", "")), SEAL)
	refresh()

# ---- 小件 ----

func _label(text: String, font_size: int, col: Color, clip := false) -> Label:
	# v3b（用户："字超出了"）：凡是"靠右贴边"的那几行一律 clip_text——
	#   宁可裁掉尾巴，也不许它溢出框外（字号/宽度都算好了，正常情况裁不到）。
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", col)
	lb.clip_text = clip
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
	UiKit.font_states(btn, Color(0.94, 0.91, 0.84))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.55))

func _style_light(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.30)))
	btn.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.55)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.60)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(1, 1, 1, 0.18)))
	UiKit.font_states(btn, Color(INK.r, INK.g, INK.b, 0.82))
	btn.add_theme_color_override("font_disabled_color", Color(INK.r, INK.g, INK.b, 0.35))

func _style_pick(btn: Button, on: bool) -> void:
	if on:
		btn.add_theme_stylebox_override("normal", _flat(Color(INK.r, INK.g, INK.b, 0.90)))
		btn.add_theme_stylebox_override("hover", _flat(Color(INK.r, INK.g, INK.b, 0.84)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.88)))
		UiKit.font_states(btn, PAPER)
	else:
		btn.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.30)))
		btn.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.55)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.60)))
		UiKit.font_states(btn, Color(INK.r, INK.g, INK.b, 0.75))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))

# ---- 开合 ----

func open() -> void:
	_msg_lb.text = ""
	refresh()
	visible = true

func close() -> void:
	if not visible:
		return
	UiKit.hide_panel(self)
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
			close()
