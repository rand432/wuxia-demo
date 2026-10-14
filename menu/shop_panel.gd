extends Control
# ============================================================
# shop_panel.gd —— 货栈 v4（分类页签 + 滚动货行 · 优化批⑨/#11）
# v4（用户报的"商店限购显示有问题"）：限购**只看账本那一口**（GameState.shop_left），
#   不再由面板自己判品类。病根：以前写的是 `if is_card（kind=="card"）` 才查限购，
#   而「金纹血脉囊」的 kind 是 "blood"——它那一行永远显示"不限购"、［购买］钮也不灰，
#   买过一次再点才回一句"今日已经卖完了"。现在血脉囊跟残卡同一套显示
#   （今日剩 N/M → 今日售罄 ＋ 钮灰）；中间那行也不再把它当材料数（"现有 0"）。
# v3（优化批⑨/#11）：残卡两件加"随机"提示——①买前行尾红字【随机】"开出的是现役池里
#   随机一件（残件部位也随机）——买下即知"；②买完弹居中"开货"小窗，把开出的是什么
#   亮出来（配［知道了］），不再只沉在底部小字里。
# v2（R4）：残卡价格走 GameState.shop_card_price（随现役卡池品级浮动；未通关＝原价）。
# v1（整份重写：分类页签 + 滚动货行）——布局照仓库面板的路子：滚动行、限购在银两下面。
# 接口：open() / close() / refresh()、信号 closed——与老版一致。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")   # v61：tap_in_scroll（滚动区里可滑可点）

signal closed

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)

const PANEL_W := 640.0
const PANEL_H := 720.0
const LIST_W := 584.0
const LIST_H := 458.0
const ROW_H := 96.0
const INNER_W := 562.0     # 行内可用宽（右边留出滚动条的余地）

var _panel: Panel
var _silver_lb: Label
var _tab_btns: Array = []
var _tab := 0
var _scroll: ScrollContainer
var _list: VBoxContainer
var _msg_lb: Label
var _result_veil: Control = null
var _day_key := ""        # v39：上次画的时候是哪一天（按凌晨 4:00 换日）
var _day_t := 0.0         # 轮询计时

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_day_key = GameState.day_key()
	refresh()
	visible = get_parent() == get_tree().root

# v39（用户报的"血脉今天没刷新"）：**面板开着不动时也要跨日重画**——
#   换了日（凌晨 4:00）就自己刷一遍，不然界面上还挂着"今日已售罄"。
#   半秒问一次就够（day_key 只是个字符串比较）。
func _process(delta: float) -> void:
	if not visible:
		return
	_day_t += delta
	if _day_t < 0.5:
		return
	_day_t = 0.0
	var r: Array = GameState.day_tick(_day_key)
	if bool(r[0]):
		_day_key = str(r[1])
		print("[货栈] 换日（凌晨 4:00）：限购已重置")
		refresh()

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

	var title := _label("货　栈", 30, INK)
	title.position = Vector2(28, 18)
	title.size = Vector2(220, 44)
	_panel.add_child(title)

	var sub := _label("银两换材料与残卡——残卡与血脉囊按真实日期限购", 13, Color(INK.r, INK.g, INK.b, 0.55))
	sub.position = Vector2(30, 60)
	sub.size = Vector2(430, 22)
	_panel.add_child(sub)

	_silver_lb = _label("身上银两 0", 15, Color(SEAL.r, SEAL.g, SEAL.b, 0.92))
	_silver_lb.position = Vector2(PANEL_W - 268.0, 28)
	_silver_lb.size = Vector2(240, 24)
	_silver_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_silver_lb)

	var sep := ColorRect.new()
	sep.color = Color(INK.r, INK.g, INK.b, 0.22)
	sep.position = Vector2(28, 92)
	sep.size = Vector2(PANEL_W - 56.0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sep)

	# ---- 分类页签（跟仓库一个路数） ----
	# v36：页签数不再写死 5 格宽度——加了"丹药"一页（突破丹）之后按页数均分，
	#   不然 5×132+4×12 = 708 > 640 会顶出面板。
	_tab_btns = []
	var tg := 12.0
	var n_cat := maxi(1, GameState.SHOP_CATS.size())
	var tw := (PANEL_W - 56.0 - tg * float(n_cat - 1)) / float(n_cat)
	var tx := (PANEL_W - (tw * float(n_cat) + tg * float(n_cat - 1))) * 0.5
	for i in GameState.SHOP_CATS.size():
		var btn := Button.new()
		btn.text = str(GameState.SHOP_CATS[i]["name"])
		btn.position = Vector2(tx + float(i) * (tw + tg), 106)
		btn.size = Vector2(tw, 46)
		btn.add_theme_font_size_override("font_size", 17)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_tab.bind(i))
		_panel.add_child(btn)
		_tab_btns.append(btn)

	# ---- 货行列表（滚动；行是叠着排的，不会再撞） ----
	_scroll = ScrollContainer.new()
	UiKit.drag_scroll(_scroll)
	_scroll.position = Vector2(28, 166)
	_scroll.size = Vector2(LIST_W, LIST_H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# v15x（用户："所有滑动不要滑动进度条 用指尖滑动那种就可以了"）：
	#   强制藏掉滚动条（Godot 默认主题在内容超出时会冒出来）——拖拽滚动不受影响。
	_scroll.get_v_scroll_bar().visible = false
	_scroll.get_h_scroll_bar().visible = false
	_panel.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(INNER_W, 0)
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)

	_msg_lb = _label("", 13, Color(SEAL.r, SEAL.g, SEAL.b, 0.92))
	_msg_lb.position = Vector2(28, 628)
	_msg_lb.size = Vector2(584, 24)
	_panel.add_child(_msg_lb)

	var hint := _label("限购按真实日期，跨天自动重来", 13, Color(INK.r, INK.g, INK.b, 0.45))   # v61（手游）：12 → 13 号
	hint.position = Vector2(28, 662)
	hint.size = Vector2(360, 22)
	_panel.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(PANEL_W - 228.0, 656)
	close_btn.size = Vector2(200, 52)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	_style_dark(close_btn)
	_panel.add_child(close_btn)

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
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))

func _style_seal(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.92)))
	btn.add_theme_stylebox_override("hover", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.80)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r * 0.75, SEAL.g * 0.75, SEAL.b * 0.75, 0.95)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.35)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87))
	btn.add_theme_color_override("font_disabled_color", Color(0.96, 0.93, 0.87, 0.45))

func _style_tab(btn: Button, selected: bool) -> void:
	if selected:
		btn.add_theme_stylebox_override("normal", _flat(Color(INK.r, INK.g, INK.b, 0.90)))
		btn.add_theme_stylebox_override("hover", _flat(Color(INK.r, INK.g, INK.b, 0.84)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.88)))
		btn.add_theme_color_override("font_color", PAPER)
		btn.add_theme_color_override("font_hover_color", PAPER)
	else:
		btn.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.30)))
		btn.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.55)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.60)))
		btn.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.75))
		btn.add_theme_color_override("font_hover_color", INK)
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))

# ---- 刷新 ----

func refresh() -> void:
	if _panel == null:
		return
	_tab = clampi(_tab, 0, GameState.SHOP_CATS.size() - 1)
	_silver_lb.text = "身上银两 " + str(GameState.coin("silver"))
	for i in _tab_btns.size():
		_style_tab(_tab_btns[i], i == _tab)
	_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var items: Array = GameState.shop_items_of(str(GameState.SHOP_CATS[_tab]["id"]))
	if items.is_empty():
		var lb := _label("这一页还空着——账本里没摆货", 14, Color(INK.r, INK.g, INK.b, 0.55))
		lb.custom_minimum_size = Vector2(0, 40)
		_list.add_child(lb)
		return
	for it in items:
		_add_row(it)

func _add_row(it: Dictionary) -> void:
	var key := str(it["key"])
	var kd := str(it.get("kind", "mat"))       # mat（不限购）/ card（残卡）/ blood（血脉囊）
	var is_card := kd == "card"
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.42)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(INK.r, INK.g, INK.b, 0.20)
	sb.set_border_width_all(1)
	row.add_theme_stylebox_override("panel", sb)
	_list.add_child(row)

	var nm := _label(str(it.get("name", key)), 18, INK)
	nm.position = Vector2(14, 8)
	nm.size = Vector2(INNER_W - 280.0, 26)
	row.add_child(nm)

	var desc := _label(str(it.get("desc", "")), 13, Color(INK.r, INK.g, INK.b, 0.55))   # v61（手游）：12 → 13 号
	desc.position = Vector2(14, 34)
	desc.size = Vector2(INNER_W - 280.0, 22)
	row.add_child(desc)

	# v3（#11）：残卡行第三行改成"随机"明示——买下前谁都预览不了
	# v4：这一行按**三种货**分开写——以前只判 is_card，于是「金纹血脉囊」既走了
	#   "现有 0"（它不是材料，material_count 查不到）又漏了限购文案。
	var have := ""
	var have_col := Color(INK.r, INK.g, INK.b, 0.50)
	if is_card:
		have = "【随机】开出的是现役池里随机一件（残件部位也随机）——买下即知"
		have_col = Color(SEAL.r, SEAL.g, SEAL.b, 0.78)
	elif kd == "blood":
		# v63（用户："这里显示有点问题"）：原来这句写死"开出金色血脉" ✗ 与卡面概率（紫九成）打架 ✗，
		#   而且太长顶进右边按钮。改成：纯度和用途 + 买下即知（概率已在卡面第一行）。
		have = "纯度 30~100 随机 · 宠物融合用——买下即知"
		have_col = Color(SEAL.r, SEAL.g, SEAL.b, 0.78)
	elif kd == "pill":
		# v36：突破丹——显示包裹里已有几颗（它是丹药，不是材料）
		have = "包裹 " + str(GameState.pill_count(str(it.get("pid", key)))) + " 颗 · 角色面板点［突破］用"
		have_col = Color(SEAL.r, SEAL.g, SEAL.b, 0.70)
	elif kd == "tool":
		# v39：鉴宝行的侦查道具——显示背包里已有几个（在鉴宝行那一页用）
		have = "现有 " + str(GameState.appraise_tool_count(str(it.get("tid", "")))) + " 个 · 鉴宝行里用来照货仓"
		have_col = Color(SEAL.r, SEAL.g, SEAL.b, 0.70)
	else:
		have = "现有 " + str(GameState.material_count(key))
	var have_lb := _label(have, 13, have_col)   # v61（手游）：12 → 13 号
	have_lb.position = Vector2(14, 58)
	have_lb.size = Vector2(INNER_W - 280.0, 20)
	row.add_child(have_lb)

	var price_val: int = int(it["price"]) if not is_card else int(GameState.shop_card_price(key))
	var price := _label("银两 " + str(price_val), 16, Color(SEAL.r, SEAL.g, SEAL.b, 0.92))
	price.position = Vector2(INNER_W - 250.0, 10)
	price.size = Vector2(130, 24)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)

	# ---- 限购（v4：**一个口径**——都看 GameState.shop_left，-1 ＝ 不限购）----
	#   病根：以前这里写的是 `if is_card:`，而血脉囊的 kind 是 "blood"——
	#   于是它那一行永远显示"不限购"、［购买］钮也不灰，买过一次再点才回一句
	#   "今日已经卖完了"。限购得按**账本**说（shop_left 认 card 与 blood 两种），
	#   面板不再自己判品类。
	var left := GameState.shop_left(key)
	var lim := int(it.get("limit", 0))
	var lim_txt := "不限购"
	var lim_col := Color(INK.r, INK.g, INK.b, 0.45)
	var sold := false
	if left == 0:
		lim_txt = "今日售罄"
		lim_col = Color(SEAL.r, SEAL.g, SEAL.b, 0.92)
		sold = true
	elif left > 0:
		lim_txt = "今日剩 " + str(left) + "/" + str(lim)
	var lim_lb := _label(lim_txt, 13, lim_col)   # v61（手游）：12 → 13 号
	lim_lb.position = Vector2(INNER_W - 250.0, 36)
	lim_lb.size = Vector2(140, 20)
	lim_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(lim_lb)

	var buy := Button.new()
	buy.text = "售罄" if sold else "购买"
	buy.position = Vector2(INNER_W - 108.0, 26)
	buy.size = Vector2(94, 44)
	buy.add_theme_font_size_override("font_size", 16)
	buy.focus_mode = Control.FOCUS_NONE
	buy.disabled = sold
	# v61（手游）：购买钮在滚动区里——拖得动、点得准（原来一滑就误买）
	UiKit.tap_in_scroll(buy, _on_buy.bind(key))
	_style_seal(buy)
	row.add_child(buy)

# ---- 点击 ----

func _on_tab(i: int) -> void:
	_tab = i
	refresh()

func _on_buy(key: String) -> void:
	var r := GameState.buy_material(key, 1)
	_msg_lb.text = str(r.get("msg", ""))
	if bool(r.get("ok", false)) and r.has("got"):
		_show_result(r.get("got", []))
	refresh()

# ---- 开货结果（v3/#11）：残卡买完，居中把"开出了什么"亮出来，［知道了］收起 ----

func _show_result(got: Array) -> void:
	_close_result()
	var ov := Control.new()
	ov.position = Vector2.ZERO
	ov.size = size
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.38)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.add_child(dim)
	var panel := Panel.new()
	panel.size = Vector2(460, 300)
	panel.position = Vector2((size.x - 460.0) * 0.5, (size.y - 300.0) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.99)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	ov.add_child(panel)
	var t1 := _label("开　货", 26, INK)
	t1.position = Vector2(0, 20)
	t1.size = Vector2(460, 36)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(t1)
	for i in got.size():
		var lb := _label(str(got[i]), 22, Color(SEAL.r, SEAL.g, SEAL.b, 0.95))
		lb.position = Vector2(16, 78 + float(i) * 34.0)
		lb.size = Vector2(428, 30)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(lb)
	var note := _label("（已收进仓库 · 残卡凑齐一套可合成）", 13, Color(INK.r, INK.g, INK.b, 0.55))
	note.position = Vector2(16, 182)
	note.size = Vector2(428, 20)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(note)
	var ok := Button.new()
	ok.text = "知道了"
	ok.position = Vector2(160, 216)
	ok.size = Vector2(140, 52)
	ok.add_theme_font_size_override("font_size", 20)
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(_close_result)
	_style_dark(ok)
	panel.add_child(ok)
	_result_veil = ov

func _close_result() -> void:
	if _result_veil != null and is_instance_valid(_result_veil):
		_result_veil.queue_free()
	_result_veil = null

# ---- 开合 ----

func open() -> void:
	_tab = 0
	_msg_lb.text = ""
	_close_result()
	refresh()
	visible = true

func close() -> void:
	if not visible:
		return
	_close_result()
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
			if _result_veil != null:
				_close_result()
				return
			close()
