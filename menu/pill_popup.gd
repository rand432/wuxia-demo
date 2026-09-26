extends Control
# ============================================================
# pill_popup.gd —— 服药弹窗 v1（从弟子面板［服药］打开）
#   为什么有它：丹药会越加越多，弟子面板放不下固定四格——
#   弹窗按 GameState.DAN_RECIPES 现算，加一条丹方就多一行（列表可滚动）。
#   每行：丹名 / 说明 / 存量 ×N / 本境已服 x/y /［服下］。
#   规则全在 GameState.eat_pill 里；这里只管显示与点按。
#   养灵丹（宠物粮）不给吃，只指路；没登记的丹摆"没方子"。
#   接口：open_for(rid) / close() / 信号 fed（外层刷新属性）· closed
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")

signal fed
signal closed

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)

const DLG_W := 560.0
const DLG_H := 600.0
const LIST_H := 380.0
const ROW_H := 76.0
const INNER_W := 498.0     # 对话框内宽（含滚动条余地）——行内元素照它定位

var _dialog: Panel
var _title_lb: Label
var _cap_lb: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _msg_lb: Label
var _btn_status: Button
var _btn_pills: Button
var _rid := ""
var _rows: Array = []
var _page := "list"      # v61：list（丹方）/ status（当前服用状态查明）/ pills（当前丹药查明）

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false

func _build() -> void:
	var vp := get_viewport_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.38)
	dim.size = vp
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_dialog = Panel.new()
	_dialog.position = Vector2((vp.x - DLG_W) * 0.5, (vp.y - DLG_H) * 0.5)
	_dialog.size = Vector2(DLG_W, DLG_H)
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.99)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	psb.set_border_width_all(2)
	_dialog.add_theme_stylebox_override("panel", psb)
	add_child(_dialog)

	_title_lb = _label("服药", 26, INK)
	_title_lb.position = Vector2(24, 16)
	_title_lb.size = Vector2(512, 36)
	_dialog.add_child(_title_lb)

	var sub := _label("丹药从「炼丹阁」收进包裹；点［服下］喂给这名弟子。养灵丹是宠物粮——去「宠物」面板喂。", 13, Color(INK.r, INK.g, INK.b, 0.55))   # v61（手游）：12 → 13 号
	sub.position = Vector2(24, 54)
	sub.size = Vector2(512, 20)
	_dialog.add_child(sub)

	_cap_lb = _label("", 13, Color(SEAL.r, SEAL.g, SEAL.b, 0.85))
	_cap_lb.position = Vector2(24, 76)
	_cap_lb.size = Vector2(512, 20)
	_dialog.add_child(_cap_lb)

	_scroll = ScrollContainer.new()
	UiKit.drag_scroll(_scroll)
	_scroll.position = Vector2(24, 102)
	_scroll.size = Vector2(512, LIST_H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialog.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(INNER_W, 0)
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)

	_msg_lb = _label("", 13, Color(SEAL.r, SEAL.g, SEAL.b, 0.92))
	_msg_lb.position = Vector2(24, 492)
	_msg_lb.size = Vector2(512, 38)
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog.add_child(_msg_lb)

	# v61（用户："点击服药后 增加两个选项【当前服用状态查明】【当前丹药查明】"）：
	#   底下摆两颗钮，各自把上面的滚动区切成"那一页"；再点一次回到丹方列表。
	#   两页的内容都写在滚动区里（行数/字数超了直接滑，不再挤成一团小字）。
	_btn_status = Button.new()
	_btn_status.position = Vector2(20, 534)
	_btn_status.size = Vector2(170, 52)
	_btn_status.add_theme_font_size_override("font_size", 15)
	_btn_status.focus_mode = Control.FOCUS_NONE
	_btn_status.pressed.connect(_show_page.bind("status"))
	_style_dark(_btn_status)
	_dialog.add_child(_btn_status)

	_btn_pills = Button.new()
	_btn_pills.position = Vector2(198, 534)
	_btn_pills.size = Vector2(150, 52)
	_btn_pills.add_theme_font_size_override("font_size", 15)
	_btn_pills.focus_mode = Control.FOCUS_NONE
	_btn_pills.pressed.connect(_show_page.bind("pills"))
	_style_dark(_btn_pills)
	_dialog.add_child(_btn_pills)

	var close_btn := Button.new()
	close_btn.text = "收起"
	close_btn.position = Vector2(DLG_W - 204.0, 534)
	close_btn.size = Vector2(184, 52)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	_style_dark(close_btn)
	_dialog.add_child(close_btn)

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

# ---- 开关 ----

func open_for(rid: String) -> void:
	_rid = rid
	_page = "list"        # v61：每次打开都从丹方列表起
	var d: Dictionary = GameState.role_data(rid)
	_title_lb.text = "服药 · " + str(d.get("name", rid))
	_msg_lb.text = ""
	_rebuild()
	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

# ---- 列表 ----

# v61：切页（list / status / pills）。再点同一颗钮＝回丹方列表。
func _show_page(p: String) -> void:
	_page = "list" if _page == p else p
	_msg_lb.text = ""
	_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows = []
	match _page:
		"status":
			_build_status_page()
		"pills":
			_build_pills_page()
		_:
			_build_recipe_list()
	_update_page_chrome()
	_update_state()

# 标题 / 底部两颗钮 的文案与配色，跟着当前页走
func _update_page_chrome() -> void:
	var nm := str(GameState.role_data(_rid).get("name", _rid))
	match _page:
		"status":
			_title_lb.text = "当前服用状态查明 · " + nm
			_btn_status.text = "← 回丹方"
			_btn_pills.text = "当前丹药查明"
			_style_seal(_btn_status)
			_style_dark(_btn_pills)
		"pills":
			_title_lb.text = "当前丹药查明"
			_btn_status.text = "当前服用状态查明"
			_btn_pills.text = "← 回丹方"
			_style_dark(_btn_status)
			_style_seal(_btn_pills)
		_:
			_title_lb.text = "服药 · " + nm
			_btn_status.text = "当前服用状态查明"
			_btn_pills.text = "当前丹药查明"
			_style_dark(_btn_status)
			_style_dark(_btn_pills)

# ---- 页一：丹方列表（原样，只是搬进这个函数） ----

func _build_recipe_list() -> void:
	var seen := {}
	for i in GameState.DAN_RECIPES.size():
		var r: Dictionary = GameState.DAN_RECIPES[i]
		var rid := str(r["id"])
		# ⚠ **先登记 seen，再决定跳不跳**（用户报的："服药框的突破丹没有中文名，变成了 tupo_fan"）：
		#   下面那条"没登记的丹"兜底是按 seen 判的；以前两个 continue 写在 seen[rid] = true
		#   **前面**，于是被跳过的丹（宠物丹 / 突破丹）反倒落进兜底里，用生 id 露一脸。
		seen[rid] = true
		# ㊿z9：宠物丹（养灵丹 pet / 洗灵丹 pet_apt）**不列在这里**——这是弟子的服药格，
		#   列出来只会让人把稀有丹喂错人（旧代码喂下去等于白扔，见 eat_pill 的兜底）
		if str(r.get("stat", "")).begins_with("pet"):
			continue
		# v36：突破丹（stat="break"）也不是吃的——它只在角色面板点［突破］用
		if str(r.get("stat", "")) == "break":
			continue
		_add_row(rid, str(r.get("name", rid)), str(r.get("desc", "")))
	for k in GameState.pills.keys():
		var kk := str(k)
		if seen.has(kk):
			continue
		if int(GameState.pills.get(kk, 0)) <= 0:
			continue
		_add_row(kk, kk, "（没登记的丹——先摆着，方子补上再吃）")
	if _rows.is_empty():
		var lb := _label("这里还没有丹方", 14, Color(INK.r, INK.g, INK.b, 0.55))
		lb.custom_minimum_size = Vector2(0, 40)
		_list.add_child(lb)

# ---- 页二：当前服用状态查明 ----
#   回答"这名弟子现在还能吃什么、已经吃了多少、额度怎么涨"——原来挤在弟子面板
#   右下角那一小块 12 号字里（v61 已从面板撤掉，挪到这儿）。
func _build_status_page() -> void:
	var d: Dictionary = GameState.role_data(_rid)
	var lv := int(d.get("lv", 1))
	var realm := GameState.role_realm(_rid)
	var used := int(d.get("pills_used", 0))
	var allow := GameState.stat_pill_allow(_rid)
	var cap := GameState.level_cap(_rid)
	var left := maxi(0, allow - used)
	var per := int(GameState.PILLS_PER_REALM)
	var lines: Array = []
	lines.append("【境界·等级】" + str(realm) + " 重「" + GameState.realm_name(realm) + "」")
	lines.append("　　等级 " + str(lv) + " / " + str(cap) + "（每突破一重 +" + str(GameState.BREAK_STEP) + " 级上限）")
	lines.append("")
	lines.append("【属性丹额度】本境已服 " + str(used) + " / " + str(allow) + "　→　还能吃 " + str(left) + " 颗")
	lines.append("　　额度 = (境界 + 1) × " + str(per) + "；每突破一重（境界 +1）额度 +" + str(per))
	lines.append("　　强身丹与淬体丹**共用**这一个额度——吃哪颗都算一颗")
	lines.append("")
	lines.append("【能喂的丹·现存】")
	var any := false
	for r_v in GameState.DAN_RECIPES:
		var r: Dictionary = r_v
		var st := str(r.get("stat", ""))
		if st.begins_with("pet") or st == "break":
			continue
		any = true
		var n := GameState.pill_count(str(r["id"]))
		lines.append("　· " + str(r.get("name", r["id"])) + " ×" + str(n) + "　" + str(r.get("desc", "")))
	if not any:
		lines.append("　（还没有能喂的丹——去「炼丹阁」炼一炉）")
	lines.append("")
	lines.append("【不在这里吃】")
	lines.append("　· 突破丹：回「弟子」面板点［突破］，不是拿来吃的")
	lines.append("　· 养灵丹 / 洗灵丹：宠物的丹药——去「宠物」面板喂")
	_add_text_block(lines, 15)

# ---- 页三：当前丹药查明 ----
#   把包裹里**所有**丹都摆出来（能喂的 / 突破用的 / 宠物用的分开列），
#   含颗数；没方子的野丹也不会漏（原来列表只列丹方上有登记的）。
func _build_pills_page() -> void:
	var eat_lines: Array = []
	var other_lines: Array = []
	var total := 0
	var eat_n := 0
	var seen := {}
	for r_v in GameState.DAN_RECIPES:
		var r: Dictionary = r_v
		var pid := str(r["id"])
		seen[pid] = true
		var n := GameState.pill_count(pid)
		total += n
		var st := str(r.get("stat", ""))
		var ln := "　· " + str(r.get("name", pid)) + " ×" + str(n) + "　" + str(r.get("desc", ""))
		if st.begins_with("pet"):
			other_lines.append(ln + "（宠物用）")
		elif st == "break":
			other_lines.append(ln + "（突破用）")
		else:
			eat_n += n
			eat_lines.append(ln)
	# 包裹里没方子的野丹（老档/测试留下的）——不列就等于"查不到"
	for k in GameState.pills.keys():
		var kk := str(k)
		if seen.has(kk):
			continue
		var n2 := int(GameState.pills.get(kk, 0))
		if n2 <= 0:
			continue
		total += n2
		other_lines.append("　· " + kk + " ×" + str(n2) + "（没登记的丹）")
	var lines: Array = []
	lines.append("【包裹合计】" + str(total) + " 颗（其中能喂给弟子的 " + str(eat_n) + " 颗）")
	lines.append("")
	lines.append("【能喂给弟子的】")
	if eat_lines.is_empty():
		lines.append("　（没有）")
	else:
		lines.append_array(eat_lines)
	lines.append("")
	lines.append("【别的用途】")
	if other_lines.is_empty():
		lines.append("　（没有）")
	else:
		lines.append_array(other_lines)
	lines.append("")
	lines.append("丹药从「炼丹阁」收进包裹；货栈每日也有限购的丹。")
	_add_text_block(lines, 15)

# 一页纯文字（整块塞进滚动区：超了就滑）——status / pills 两页共用
func _add_text_block(lines: Array, fs: int) -> void:
	var lb := _label("\n".join(PackedStringArray(lines)), fs, Color(INK.r, INK.g, INK.b, 0.88))
	lb.custom_minimum_size = Vector2(INNER_W - 8.0, 0)
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(lb)

func _add_row(rid: String, nm: String, desc: String) -> void:
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
	var nm_lb := _label(nm, 18, INK)
	nm_lb.position = Vector2(14, 8)
	nm_lb.size = Vector2(240, 26)
	row.add_child(nm_lb)
	var cnt_lb := _label("×0", 16, Color(SEAL.r, SEAL.g, SEAL.b, 0.92))
	cnt_lb.position = Vector2(INNER_W - 210.0, 10)
	cnt_lb.size = Vector2(80, 24)
	cnt_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cnt_lb)
	var desc_lb := _label(desc, 12, Color(INK.r, INK.g, INK.b, 0.55))
	desc_lb.position = Vector2(14, 38)
	desc_lb.size = Vector2(INNER_W - 140.0, 18)
	row.add_child(desc_lb)
	var use_lb := _label("", 12, Color(INK.r, INK.g, INK.b, 0.50))
	use_lb.position = Vector2(14, 56)
	use_lb.size = Vector2(INNER_W - 140.0, 16)
	row.add_child(use_lb)
	var btn := Button.new()
	btn.text = "服下"
	btn.position = Vector2(INNER_W - 112.0, 18)
	btn.size = Vector2(98, 40)
	btn.add_theme_font_size_override("font_size", 16)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_eat.bind(rid))
	_style_seal(btn)
	row.add_child(btn)
	_rows.append({"rid": rid, "cnt_lb": cnt_lb, "use_lb": use_lb, "btn": btn})

func _update_state() -> void:
	var d: Dictionary = GameState.role_data(_rid)
	var used_s := int(d.get("pills_used", 0))
	var allow_s := GameState.stat_pill_allow(_rid)
	# v61：洗髓丹已下线 → 这行只报属性丹（根骨不再有丹药途径，gengu_used 留作老档字段）
	_cap_lb.text = "本境：属性丹 " + str(used_s) + "/" + str(allow_s) + "（每突破一重 +3）"
	for e in _rows:
		var rid := str(e["rid"])
		var r := GameState.recipe_of(rid)
		var cnt := GameState.pill_count(rid)
		var cnt_lb: Label = e["cnt_lb"]
		var use_lb: Label = e["use_lb"]
		var btn: Button = e["btn"]
		cnt_lb.text = "×" + str(cnt)
		if r.is_empty():
			use_lb.text = "——"
			btn.text = "没方子"
			btn.disabled = true
			continue
		var stat := str(r.get("stat", ""))
		if stat == "pet":
			use_lb.text = "宠物粮——去「宠物」面板喂"
			btn.text = "宠物用"
			btn.disabled = true
			continue
		# v61：洗髓丹（stat "gengu"）已下线 → 这里只剩"属性丹"那一档；
		#   以后若再添"根骨类"的丹，把 is_g / used_g / allow_g 那三行加回来即可。
		var used := used_s
		var allow := allow_s
		use_lb.text = "本境已服 " + str(used) + "/" + str(allow)
		if cnt <= 0:
			btn.text = "没有货"
			btn.disabled = true
		elif used >= allow:
			btn.text = "已满"
			btn.disabled = false     # 点了会告诉你"已满 x/x"——比灰着不响好
		else:
			btn.text = "服下"
			btn.disabled = false

func _on_eat(rid: String) -> void:
	_msg_lb.text = GameState.eat_pill(_rid, rid)
	_update_state()
	fed.emit()

# ---- 点外面收弹窗 ----

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if not _dialog.get_global_rect().has_point(mb.global_position):
				close()
			accept_event()
