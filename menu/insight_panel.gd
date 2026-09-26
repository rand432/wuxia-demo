extends Control
# ============================================================
# insight_panel.gd —— **阅历线**面板 v1
#
# 用户："增加一个新线 阅历线 …分四条线 财富【经济】进攻 防御 技巧【暴击 闪避】·
#   走满要很久 ·（入口用底排那一格）· 要洗点但是消耗银两"
#
# 这一页只做三件事：
#   · 顶上报数：现有阅历 / 挂机速率（吃档位）/ 已通几段
#   · 四支各 5 段：顺序解锁，点［升级］花 **阅历 ＋ 银两**（价目在 data_insight）
#   · 底排［洗点］：退**全部阅历**、收手续费（每级 200 两），银两不退
#
# 表与价目**只读 shared/data_insight.gd**——这一页里不许出现任何数字。
# 入口：主界面底排第 6 格「阅历」（menu_sketch._tag_fire 的 case 5）。
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
var _ph := 1040.0

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

	_ph = clampf(vp.y - 120.0, 420.0, 1040.0)
	_panel = Panel.new()
	_panel.position = Vector2((vp.x - 680.0) * 0.5, (vp.y - _ph) * 0.5)
	_panel.size = Vector2(680.0, _ph)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.98)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	psb.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", psb)
	add_child(_panel)

	var title := _label("阅　历", 30, INK)
	title.position = Vector2(28, 16)
	title.size = Vector2(300, 40)
	_panel.add_child(title)

	_top_lb = _label("", 17, Color(INK.r, INK.g, INK.b, 0.78))
	_top_lb.position = Vector2(30, 58)
	_top_lb.size = Vector2(620, 26)
	_panel.add_child(_top_lb)

	var sub := _label("场外养成，只在**游历**里算数——挂机攒阅历，银两＋阅历一起花。", 15,
		Color(INK.r, INK.g, INK.b, 0.55))
	sub.position = Vector2(30, 82)
	sub.size = Vector2(620, 22)
	_panel.add_child(sub)

	_msg_lb = _label("", 16, Color(SEAL.r, SEAL.g, SEAL.b, 0.95))
	_msg_lb.position = Vector2(30, _ph - 76.0)
	_msg_lb.size = Vector2(620, 24)
	_panel.add_child(_msg_lb)

	var by := _ph - 60.0
	_respec_btn = Button.new()
	_respec_btn.position = Vector2(30, by)
	_respec_btn.size = Vector2(300, 48)
	_respec_btn.add_theme_font_size_override("font_size", 18)
	_respec_btn.focus_mode = Control.FOCUS_NONE
	_respec_btn.pressed.connect(_on_respec)
	_style_light(_respec_btn)
	_panel.add_child(_respec_btn)

	var cl := Button.new()
	cl.text = "关闭"
	cl.position = Vector2(450, by)
	cl.size = Vector2(200, 48)
	cl.add_theme_font_size_override("font_size", 18)
	cl.focus_mode = Control.FOCUS_NONE
	cl.pressed.connect(close)
	_style_dark(cl)
	_panel.add_child(cl)

	refresh()

func refresh() -> void:
	if _panel == null:
		return
	var total := Insight.total_lv(GameState.insight_lv)
	var maxi_all := 0
	for b_v in Insight.BRANCHES:
		maxi_all += Insight.max_lv(str((b_v as Dictionary).get("id", "")))
	UiKit.set_text(_top_lb, "现有阅历 " + str(GameState.insight) + " 点　·　挂机 +"
		+ str(snappedf(GameState.insight_rate(), 0.1)) + "/分（第 " + str(GameState.idle_tier() + 1)
		+ " 档）　·　已通 " + str(total) + "/" + str(maxi_all) + " 段")
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
	_body.size = Vector2(648, 10)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_body)

	var scroll := ScrollContainer.new()
	UiKit.drag_scroll(scroll)
	scroll.position = Vector2(20, 110)
	scroll.size = Vector2(640, _ph - 110.0 - 92.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(616, 0)
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	for b_v in Insight.BRANCHES:
		var b: Dictionary = b_v
		var bid := str(b.get("id", ""))
		var lv := GameState.insight_lv_of(bid)
		var head := Panel.new()
		head.custom_minimum_size = Vector2(616, 44)
		var hsb := StyleBoxFlat.new()
		hsb.bg_color = Color(INK.r, INK.g, INK.b, 0.10)
		hsb.set_corner_radius_all(8)
		hsb.set_content_margin_all(6)
		head.add_theme_stylebox_override("panel", hsb)
		box.add_child(head)
		var hl := _label(str(b.get("name", "")) + "　·　" + str(b.get("sub", "")) + "　　" + str(lv) + "/"
			+ str(Insight.max_lv(bid)) + "　　" + str(b.get("desc", "")), 18, INK)
		hl.position = Vector2(12, 10)
		hl.size = Vector2(590, 26)
		head.add_child(hl)

		var nodes: Array = b.get("nodes", [])
		for i in nodes.size():
			var nd: Dictionary = nodes[i]
			var row := Panel.new()
			row.custom_minimum_size = Vector2(616, 62)
			var rsb := StyleBoxFlat.new()
			var done := i < lv
			var cur := i == lv
			rsb.bg_color = (Color(0.90, 0.87, 0.80, 1.0) if done
				else (Color(0.96, 0.93, 0.86, 1.0) if cur else Color(0.93, 0.91, 0.86, 1.0)))
			rsb.set_corner_radius_all(8)
			rsb.border_color = (GOLD if cur else Color(INK.r, INK.g, INK.b, 0.30))
			rsb.set_border_width_all(3 if cur else 1)
			rsb.set_content_margin_all(6)
			row.add_theme_stylebox_override("panel", rsb)
			box.add_child(row)
			var nm := _label(str(i + 1) + ". " + str(nd.get("name", "")), 19,
				(INK if not done else Color(INK.r, INK.g, INK.b, 0.45)))
			nm.position = Vector2(12, 6)
			nm.size = Vector2(300, 26)
			row.add_child(nm)
			var ds := _label(str(nd.get("desc", "")), 15, Color(INK.r, INK.g, INK.b, 0.72))
			ds.position = Vector2(12, 34)
			ds.size = Vector2(420, 22)
			row.add_child(ds)
			var cost := Insight.cost_next(bid, i)
			if done:
				var tag := _label("已通", 17, Color(INK.r, INK.g, INK.b, 0.45))
				tag.position = Vector2(510, 18)
				tag.size = Vector2(90, 26)
				row.add_child(tag)
			elif i > lv:
				var lk := _label("先通上一段", 15, Color(INK.r, INK.g, INK.b, 0.45))
				lk.position = Vector2(450, 20)
				lk.size = Vector2(150, 24)
				row.add_child(lk)
			else:
				var ct := _label("阅历 " + str(cost.get("insight", 0)) + " · 银两 " + str(cost.get("silver", 0)),
					15, Color(SEAL.r, SEAL.g, SEAL.b, 0.95))
				ct.position = Vector2(430, 6)
				ct.size = Vector2(180, 22)
				ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				row.add_child(ct)
				var up := Button.new()
				up.text = "升级"
				up.position = Vector2(506, 28)
				up.size = Vector2(100, 30)
				up.add_theme_font_size_override("font_size", 16)
				up.focus_mode = Control.FOCUS_NONE
				up.pressed.connect(_on_upgrade.bind(bid))
				_style_dark(up)
				row.add_child(up)

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

# ---- 开合 ----

func open() -> void:
	_msg_lb.text = ""
	refresh()
	visible = true

func close() -> void:
	if not visible:
		return
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
			close()
