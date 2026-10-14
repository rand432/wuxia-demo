extends Control
# ============================================================
# warehouse_panel.gd —— 仓库面板 v6（竖屏 720×1280）
# v6：页数自由配套（R0）——统计/循环不再写死"3"，按各套 parts.size() 说话；
#   残卡提示改成动态页数；宠物粮提示不再指名"白狐"。
# v5：丹药页接上真账——把 GameState.pills 里的丹逐种列出来（名 + 存量），
#   点一下给去处指引（属性丹/洗髓 → 弟子面板［服药］格；养灵丹 → 宠物面板）。
#   「包裹」就是这一页；收丹照旧在炼丹阁，服用照旧在弟子面板。
#   另：空页提示里的旧测试键 F10 改成 M（现在的塞货键）。
# v4：装备页收甲/头/披成品；格子顶行标类别；begin_pick 支持五类。
# 数据：GameState.vault_cards / vault_items / pills（内存版；关游戏清零）
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const ItemIcons := preload("res://shared/item_icons.gd")   # v93o：一件东西 → 一张图
const Cards := preload("res://shared/data_cards.gd")
const UiKit := preload("res://shared/ui_kit.gd")   # v61b：tap_in_scroll（格子可滑可点）
const SceneArt := preload("res://shared/scene_art.gd")   # v77：内景垫图
const GameData := preload("res://shared/game_data.gd")   # v142：招式说明走 move_desc（负面/控制那行）

signal closed
signal picked(sid: String)
# v58（用户："装备在仓库也可以装备吧 点击装备跳转到弟子页面就好了"）：
#   仓库里点［装备（去弟子页）］时发这一条——主界面收到后关仓库、开弟子页、把这件装上。
#   ⚠ 装配本身不在这里做：仍走 GameState.equip_*，与弟子面板那条路同一个口
signal equip_requested(sid: String)

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)

const PANEL_W := 640.0
# v58：装配窗尺寸
const EQ_W := 480.0
const EQ_H := 340.0
const PANEL_H := 760.0   # v40：底部腾出 62 给「新手关卡礼包」那一条
# v60（用户："仓库内容也做成可上下滑动，格子稍微再大一点；丹药一栏文字已经超出了"）：
#   格子 6×4/88 → **5 列 × 106**，外面套一个竖向 ScrollContainer（视高 350 约三行半）——
#   残卡/成品一多就往下滑，不用再挤成一团。格内那三行字也按新格子重排：
#   类别 11 号、名字**可换行**（丹药名"突破丹（凡品）"这种 7 个字在 88 宽里本来是要溢出的）。
const COLS := 5
const CELL := 106.0
const GAP := 8.0
const GRID_VIEW_H := 350.0     # 滚动窗口高度（够放三行多一点，一眼看得出能滑）
const GRID_W := CELL * float(COLS) + GAP * float(COLS - 1)

const EQUIP_POOLS := ["weapon", "armor", "helm", "cloak"]
# 槽位名表唯一源 = game_state.SLOT_CN（转发；含 "arts": "武学"）
const GEAR_CN := GameState.SLOT_CN

const TABS := [
	{"id": "equip", "name": "装备", "e1": "这一层还是空的", "e2": "历练带回的兵刃残卡与装备成品，会收在这儿（残卡凑齐可合成）"},
	{"id": "arts", "name": "武学", "e1": "这一层还是空的", "e2": "事件里拿到的武学残页，会收在这儿（凑齐可合成）"},
	{"id": "pill", "name": "丹药", "e1": "还没有丹药", "e2": "去「炼丹阁」炼一炉——丹成点［收丹］，自动收进这一格"},
	# v60（用户："宝箱开的材料在仓库不显示"）：新增**材料**一页——木料/灵草/兽骨碎/灵米/金髓
	#   以前一个都不显示（村账里明明有数），炼丹、起屋、升星要料时只能干瞪眼。
	{"id": "mat", "name": "材料", "e1": "还没有材料", "e2": "溪畔拾柴、爬塔宝箱、游历搜刮都会出材料——起屋 · 炼丹 · 升星都要它"},
	{"id": "use", "name": "消耗品", "e1": "还没有消耗品", "e2": "以后有消耗品了，就往这格放"},
	{"id": "misc", "name": "其他", "e1": "杂项都堆这儿", "e2": "眼下是空的"},
]

var _panel: Panel
var _title_lb: Label
var _sub_lb: Label
var _tab_btns: Array = []
var _tab := 0
var _pick_cat := ""            # "" = 普通；"weapon"/"armor"/"helm"/"cloak"/"arts" = 联动取用
# v132：功法的**归类粗筛**（""=全部；"atk"/"buff"/"ctrl"/"pass"/"elem"/"ex"）——只筛「武学」页
var _cat_grp := ""
var _cat_btn: Button = null
var _cells: Array = []
var _stacks_now: Array = []
# v62（用户："仓库需要加一个整理功能 残卷和成品都是混在一起的"）：
#   原来 _stacks() 是**按套**走的——同一套的残页先列、成品紧跟其后，于是格子里成了
#   "残页 残页 成品 残页 成品"混成一团。整理＝**换排法**（不动数据、不动页签、不改库存）。
var _sort_mode := 0
var _sort_btn: Button
# 四种排法（按钮上循环切；顺序就是按下去依次出现的顺序）
const SORT_CN := ["成品在前", "残卷在前", "品质优先", "按名称"]
# v60：格子区改成"竖向可滑"——_scroll 是滚动窗口，_grid 是里头的内容节点（格子按需现建）
var _scroll: ScrollContainer = null
var _grid: Control = null
var _empty1: Label
var _empty2: Label
var _count_lb: Label
var _msg_lb: Label
# v58：装配窗（仓库里点成品件弹出来的那一页）
var _eq_veil: ColorRect = null
var _eq_win: Panel = null
var _synth_veil: Control = null   # ㊿：残页合成页（点残卡/残页开）
# v40：新手关卡礼包那条（引子下山通关后才有；没到手整条不显）
var _gift_box: Panel
var _gift_name: Label
var _gift_sub: Label
var _gift_btn: Button

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
	# v77：垫一张货仓内景（用户：「是不是也要换图了」）——34% 透明度，纸底还透、字照样清楚
	UiKit.add_room_bg(_panel, SceneArt.store_room(), 0.34)

	_title_lb = _label("仓　库", 30, INK)
	_title_lb.position = Vector2(28, 18)
	_title_lb.size = Vector2(206, 36)
	_panel.add_child(_title_lb)

	# v132：副标题缩到标题底下那一小条（12 号、两行以内）——右边两颗钮（归类/整理）
	#   原来那颗长副标题（390 宽）尾巴会被钮压住，改成短句 + 自动换行，谁也不压谁。
	_sub_lb = _label("分类收在这儿 · 残卡凑齐可合成", 12, Color(INK.r, INK.g, INK.b, 0.55))
	_sub_lb.position = Vector2(30, 52)
	_sub_lb.size = Vector2(206, 34)
	_sub_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_sub_lb)

	# v62：整理钮——放在标题行右侧那块空处（标题"仓　库"只占左边一小段，副标题也只占 390 宽）
	#   按一下换一种排法，钮上写着当前是哪种。48 高 ＝ 手游可点档。
	# v132：**归类**筛钮（用户："功法要做归类了"）——只在「武学」页生效：
	#   全部 → 攻击 → 增益 → 控制 → 被动 → 元素 → 专属 → 全部…（按大类粗筛，15 类在细则里）
	#   位置：把标题牌缩窄，与整理钮并排（两颗都 48 高 ＝ 手游可点档）
	_title_lb.size = Vector2(210, 44)
	_cat_btn = Button.new()
	_cat_btn.position = Vector2(248, 20)
	_cat_btn.size = Vector2(170, 48)
	_cat_btn.add_theme_font_size_override("font_size", 17)
	_cat_btn.focus_mode = Control.FOCUS_NONE
	_cat_btn.text = "归类：全部"
	_cat_btn.pressed.connect(_on_cat_filter)
	_style_dark_button(_cat_btn)
	UiKit.font_states(_cat_btn, Color(0.94, 0.91, 0.84))
	_panel.add_child(_cat_btn)

	_sort_btn = Button.new()
	_sort_btn.position = Vector2(430, 20)
	_sort_btn.size = Vector2(182, 48)
	_sort_btn.add_theme_font_size_override("font_size", 17)
	_sort_btn.focus_mode = Control.FOCUS_NONE
	_sort_btn.text = "整理：" + str(SORT_CN[_sort_mode])
	_sort_btn.pressed.connect(_on_sort)
	_style_dark_button(_sort_btn)
	UiKit.font_states(_sort_btn, Color(0.94, 0.91, 0.84))   # v61 那套：六个状态一起设，免得悬停回落到纯白
	_panel.add_child(_sort_btn)

	var sep := ColorRect.new()
	sep.color = Color(INK.r, INK.g, INK.b, 0.22)
	sep.position = Vector2(28, 88)
	sep.size = Vector2(PANEL_W - 56.0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sep)

	_tab_btns = []
	# v60：页签从 5 个加到 6 个（多了「材料」）——宽度按 TABS.size() 现算，缩到 88 也放得下
	var tw := 88.0
	var tg := 8.0
	var tx := (PANEL_W - (tw * float(TABS.size()) + tg * float(maxi(0, TABS.size() - 1)))) * 0.5
	for i in TABS.size():
		var btn := Button.new()
		btn.text = str(TABS[i]["name"])
		btn.position = Vector2(tx + float(i) * (tw + tg), 100)
		btn.size = Vector2(tw, 48)
		btn.add_theme_font_size_override("font_size", 17)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_tab.bind(i))
		_panel.add_child(btn)
		_tab_btns.append(btn)

	# ---- 格子区：竖向可滑（v60）----
	#   格子在 _grid（ScrollContainer 里的内容节点）里**按需现建**：件数一多就往下滑，
	#   所以不再写死"几行几列"；刷新时按件数补格子、并把内容高度调到刚好。
	_scroll = ScrollContainer.new()
	UiKit.drag_scroll(_scroll)
	_scroll.position = Vector2(28, 162)
	_scroll.size = Vector2(PANEL_W - 56.0, GRID_VIEW_H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# v15x（用户："所有滑动不要滑动进度条 用指尖滑动那种就可以了"）：
	#   强制藏掉滚动条（Godot 默认主题在内容超出时会冒出来）——拖拽滚动不受影响。
	_scroll.get_v_scroll_bar().visible = false
	_scroll.get_h_scroll_bar().visible = false
	_panel.add_child(_scroll)
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.custom_minimum_size = Vector2(GRID_W, CELL)
	_scroll.add_child(_grid)
	_cells = []

	_empty1 = _label("", 22, Color(INK.r, INK.g, INK.b, 0.72))
	_empty1.position = Vector2(0, 314)
	_empty1.size = Vector2(PANEL_W, 34)
	_empty1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_empty1)
	_empty2 = _label("", 15, Color(INK.r, INK.g, INK.b, 0.50))
	_empty2.position = Vector2(0, 352)
	_empty2.size = Vector2(PANEL_W, 26)
	_empty2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_empty2)

	# ---- v40：新手关卡礼包（引子下山通关后塞进仓库的那一只）----
	#   摆在格子与"共几件"之间那一条空带上；没到手就整条不显（老档/还没走引子）
	_gift_box = Panel.new()
	_gift_box.position = Vector2(28, 534)
	_gift_box.size = Vector2(PANEL_W - 56.0, 62)
	_gift_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.72, 0.52, 0.14, 0.16)
	gsb.set_corner_radius_all(8)
	gsb.border_color = Color(0.72, 0.52, 0.14, 0.75)
	gsb.set_border_width_all(2)
	_gift_box.add_theme_stylebox_override("panel", gsb)
	_panel.add_child(_gift_box)
	_gift_name = _label("", 17, INK)
	_gift_name.position = Vector2(14, 6)
	_gift_name.size = Vector2(360, 24)
	_gift_box.add_child(_gift_name)
	_gift_sub = _label("", 13, Color(INK.r, INK.g, INK.b, 0.62))   # v61（手游）：12 → 13 号
	_gift_sub.position = Vector2(14, 32)
	_gift_sub.size = Vector2(440, 22)
	_gift_box.add_child(_gift_sub)
	_gift_btn = Button.new()
	_gift_btn.text = "开"
	# v61（手游）：38 → 44 高（"开"那颗）
	_gift_btn.position = Vector2(PANEL_W - 56.0 - 112.0, 9)
	_gift_btn.size = Vector2(104, 44)
	_gift_btn.add_theme_font_size_override("font_size", 17)
	_gift_btn.focus_mode = Control.FOCUS_NONE
	_gift_btn.pressed.connect(_on_gift_open)
	_style_dark_button(_gift_btn)
	_gift_box.add_child(_gift_btn)

	_count_lb = _label("", 16, Color(INK.r, INK.g, INK.b, 0.80))
	_count_lb.position = Vector2(28, 606)
	_count_lb.size = Vector2(560, 28)
	_panel.add_child(_count_lb)

	_msg_lb = _label("", 13, Color(SEAL.r, SEAL.g, SEAL.b, 0.85))
	_msg_lb.position = Vector2(28, 632)
	_msg_lb.size = Vector2(560, 24)
	_panel.add_child(_msg_lb)

	var hint := _label("还没接存档：关掉游戏会清零", 13, Color(INK.r, INK.g, INK.b, 0.45))   # v61（手游）：12 → 13 号
	hint.position = Vector2(28, 656)
	hint.size = Vector2(380, 22)
	_panel.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(PANEL_W - 228.0, 674)
	close_btn.size = Vector2(200, 60)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	_style_dark_button(close_btn)
	_panel.add_child(close_btn)

func _label(text: String, font_size: int, col: Color) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", col)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lb

# ---- v60：格子按需现建（竖向可滑） ----

# 第 k 个格子还没建就建一个（建好就摆好位；内容由 refresh 每次重填）
func _ensure_cells(n: int) -> void:
	while _cells.size() < n:
		var k := _cells.size()
		var c := k % COLS
		var r := int(k / COLS)
		var cell := Panel.new()
		cell.position = Vector2(float(c) * (CELL + GAP), float(r) * (CELL + GAP))
		cell.size = Vector2(CELL, CELL)
		# v61b（用户："仓库的上下滑动需要优化 极易误触仓库物品"）：
		#   病根：格子原来是 **STOP + 在"按下"那一下就 _click_cell**——
		#     ① 手指一碰就弹详情（想滑列表却把物品点开了）；
		#     ② 而且 STOP 把拖动**吃掉**，滚动区收不到，列表还滑不动。
		#   现在走 tap_in_scroll：PASS（拖动继续传给滚动区）+ 只有"位移 ≤14 像素且 ≤0.7 秒"
		#   才算点中物品。手滑一下只滚列表，不会误开详情。
		UiKit.tap_in_scroll(cell, _click_cell.bind(k))
		_grid.add_child(cell)
		# v93o（用户："仓库怎么还是字啊"）：格子里**加一张图标**——
		#   图在上、名在中、类型与数量在底下一行；取不到图就只留字，不会开天窗。
		var ic := TextureRect.new()
		ic.position = Vector2(CELL * 0.5 - 25.0, 6.0)
		ic.size = Vector2(50, 50)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(ic)
		var nm := _label("", 11, Color(INK.r, INK.g, INK.b, 0.55))
		nm.position = Vector2(3, CELL - 22.0)
		nm.size = Vector2(CELL * 0.6, 16)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cell.add_child(nm)
		# v60：名字这行**可换行**（丹药名"突破丹（凡品）"7 个字，88 宽的老格子是要溢出的）
		var pt := _label("", 16, INK)
		pt.position = Vector2(4, 58)
		pt.size = Vector2(CELL - 8.0, CELL - 80.0)
		pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pt.max_lines_visible = 2
		pt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.add_child(pt)
		var ct := _label("", 12, Color(SEAL.r, SEAL.g, SEAL.b, 0.90))
		ct.position = Vector2(3, CELL - 22.0)
		ct.size = Vector2(CELL - 6.0, 18)
		ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cell.add_child(ct)
		_cells.append({"panel": cell, "name": nm, "part": pt, "count": ct, "icon": ic})

func _flat(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	return sb

func _style_dark_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.19, 0.20, 0.96)))
	btn.add_theme_stylebox_override("hover", _flat(Color(0.31, 0.27, 0.27, 0.96)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.11, 0.12, 0.96)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))

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

# ㊿：ready＝"这一套凑齐了、现在就能合成"——给个金边提示，
#   不然玩家得自己数六个格子里哪几个是同一套的哪几页。
func _cell_box(kind: String, ready := false, q_col = null) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	if kind == "":
		sb.bg_color = Color(1, 1, 1, 0.16)
		sb.border_color = Color(INK.r, INK.g, INK.b, 0.14)
		return sb
	sb.bg_color = Color(0.96, 0.93, 0.86, 1.0)
	if ready:
		# 能合成的：金边优先（这是"现在就能点一下"的提示，盖过品级色）
		sb.border_color = Color(0.78, 0.60, 0.16, 1.0)
		sb.set_border_width_all(3)
	elif q_col != null:
		# v93p（用户："同时加颜色品质"）：**边框按品级上色**——凡白/良绿/上紫/极金/绝红
		var q: Color = q_col
		sb.border_color = Color(q.r, q.g, q.b, 0.95)
		sb.set_border_width_all(3)
		# 再垫一层极淡的同色底，格子里一眼能分出高低
		sb.bg_color = Color(0.96, 0.93, 0.86, 1.0).lerp(Color(q.r, q.g, q.b, 1.0), 0.10)
	elif kind == "item" or kind == "pill":
		sb.border_color = Color(0.72, 0.58, 0.25, 0.70)
	else:
		sb.border_color = Color(INK.r, INK.g, INK.b, 0.40)
	return sb

# ---- 整理（v62）----
#   成品 ＝ kind "item"（兵器/护甲/玉佩/披风/功法成品、金纹血脉囊那种）
#   残卷 ＝ kind "card"（残页/残卡，一件一套的"页"）
#   其余（丹药/材料/消耗品）排在两类之后——它们各有自己的页签，在这儿只当尾巴。
func _kind_rank(kind: String, m: int) -> int:
	var item_first := (m != 1)          # 模式 1＝残卷在前，其余模式都是成品在前
	if kind == "item":
		return 0 if item_first else 1
	if kind == "card":
		return 1 if item_first else 0
	return 2

# 名字键：同一套的东西（残页各页 + 成品）在"按名称"里也挨着；
#   同一套内部按**原本页序**（锋→柄→鞘），成品（-1）排在自家残页前面。
func _sort_name(st: Dictionary) -> String:
	var pi := int(st.get("part_idx", -1))
	return str(st.get("set_name", "")) + "\u0001" + ("%03d" % pi) + "\u0002" + str(st.get("part_name", ""))

func _sort_stacks(arr: Array) -> Array:
	if arr.size() <= 1:
		return arr
	var m := _sort_mode
	arr.sort_custom(func(a_v, b_v) -> bool:
		var a: Dictionary = a_v
		var b: Dictionary = b_v
		var ra := _kind_rank(str(a.get("kind", "")), m)
		var rb := _kind_rank(str(b.get("kind", "")), m)
		var qa := Cards.q_idx(str(a.get("sid", "")))
		var qb := Cards.q_idx(str(b.get("sid", "")))
		var na := _sort_name(a)
		var nb := _sort_name(b)
		if m == 2:                      # 品质优先：好东西先露面，同品质再按 成品/残卷
			if qa != qb:
				return qa > qb
			if ra != rb:
				return ra < rb
			return na < nb
		if m == 3:                      # 按名称：一套一套挨着排
			return na < nb
		if ra != rb:                    # 0/1：先分成品与残卷，再按品质降序
			return ra < rb
		if qa != qb:
			return qa > qb
		return na < nb
	)
	return arr

func _on_sort() -> void:
	_sort_mode = (_sort_mode + 1) % SORT_CN.size()
	if _sort_btn != null:
		_sort_btn.text = "整理：" + str(SORT_CN[_sort_mode])
	refresh()

# ---- v132：归类筛（武学页）----
#   粗筛按六个大类走（攻击/增益/控制/被动/元素/专属）——15 个细类在详情页里写着，
#   一格一格点 15 下太碎；要细看某一门的归类，点开它看"归类："那一行。
func _cat_cycle() -> Array:
	var out: Array = [""]
	out.append_array(Cards.CAT_GROUPS)
	return out

func _on_cat_filter() -> void:
	var cyc := _cat_cycle()
	var i := cyc.find(_cat_grp)
	_cat_grp = str(cyc[(i + 1) % cyc.size()])
	if _cat_btn != null:
		_cat_btn.text = "归类：" + (str(Cards.CAT_GROUP_CN.get(_cat_grp, "全部")) if _cat_grp != "" else "全部")
	print("[仓库] 归类筛 = ", _cat_grp)
	refresh()

# 这一件过不过当前的归类筛（只筛武学；别的页一律放行）
func _cat_pass(s: Dictionary) -> bool:
	if _cat_grp == "":
		return true
	var sid := str(s.get("id", ""))
	if str(s.get("pool", "")) != "arts":
		return true
	return Cards.in_group(sid, _cat_grp)

# ---- 分类 ----

func _in_cat(s: Dictionary, tab_id: String) -> bool:
	var pool := str(s.get("pool", ""))
	if tab_id == "equip":
		return EQUIP_POOLS.has(pool)
	if tab_id == "arts":
		return pool == "arts"
	return false

func _stacks() -> Array:
	var out: Array = []
	if _pick_cat == "" and str(TABS[_tab]["id"]) == "pill":
		return _pill_stacks()
	if _pick_cat == "" and str(TABS[_tab]["id"]) == "mat":
		return _mat_stacks()
	for s in Cards.SETS:
		var sid := str(s.get("id", ""))
		var pool := str(s.get("pool", ""))
		if _pick_cat != "":
			if pool != _pick_cat:
				continue
			var ni := GameState.vault_item_count(sid)
			if ni > 0:
				out.append({"kind": "item", "sid": sid, "pool": pool, "weapon": str(s.get("weapon", "")), "set_name": str(GEAR_CN.get(pool, s.get("name", sid))), "title": Cards.item_name(sid), "part_name": Cards.item_name(sid), "count": ni})
			continue
		if not _in_cat(s, str(TABS[_tab]["id"])):
			continue
		# v132：归类筛（只对武学页有实感；别的页没有 art 归类，一律放行）
		if not _cat_pass(s):
			continue
		var parts: Array = s.get("parts", [])
		for p in parts.size():
			var n := GameState.vault_count(sid, p)
			if n > 0:
				var pn := str(parts[p]) if p < parts.size() else "?"
				out.append({"kind": "card", "sid": sid, "pool": pool, "weapon": str(s.get("weapon", "")), "set_name": str(s.get("name", sid)), "title": str(s.get("name", sid)) + "·" + pn, "part_name": pn, "part_idx": p, "count": n})
		var ni2 := GameState.vault_item_count(sid)
		if ni2 > 0:
			out.append({"kind": "item", "sid": sid, "pool": pool, "weapon": str(s.get("weapon", "")), "set_name": str(GEAR_CN.get(pool, s.get("name", sid))), "title": Cards.item_name(sid), "part_name": Cards.item_name(sid), "count": ni2})
	return out

# 丹药页：把包裹里（GameState.pills）现有的丹逐种列出来
func _pill_stacks() -> Array:
	var out: Array = []
	for i in GameState.DAN_RECIPES.size():
		var r: Dictionary = GameState.DAN_RECIPES[i]
		var rid := str(r["id"])
		var n := GameState.pill_count(rid)
		if n > 0:
			out.append({
				"kind": "pill",
				"sid": rid,
				"set_name": "丹药",
				"title": str(r.get("name", rid)),
				"part_name": str(r.get("name", rid)),
				"count": n,
			})
	return out

# v60（用户："宝箱开的材料在仓库不显示"）：材料页——把村账里现有的材料逐种列出来。
#   名单以 GameState.MAT_CN 为准（木料/紫芝/雪参/朱果/兽骨碎/灵米/金髓），
#   数量取 material_count ✓（宝箱、溪畔拾柴、搜刮、货栈买的全进这一个账）。
func _mat_stacks() -> Array:
	var out: Array = []
	for k_v in GameState.MAT_CN.keys():
		var k := str(k_v)
		var n := GameState.material_count(k)
		if n > 0:
			out.append({
				"kind": "mat",
				"sid": k,
				"set_name": "材料",
				"title": GameState.mat_name(k),
				"part_name": GameState.mat_name(k),
				"count": n,
			})
	return out

func _cat_total(tab_id: String) -> int:
	if tab_id == "pill":
		var np := 0
		for i in GameState.DAN_RECIPES.size():
			np += GameState.pill_count(str(GameState.DAN_RECIPES[i]["id"]))
		return np
	if tab_id == "mat":
		var nm := 0
		for k_v in GameState.MAT_CN.keys():
			nm += GameState.material_count(str(k_v))
		return nm
	var n := 0
	for s in Cards.SETS:
		if not _in_cat(s, tab_id):
			continue
		var sid := str(s.get("id", ""))
		var parts_n := Cards.parts_of(sid).size()
		for p in parts_n:
			n += GameState.vault_count(sid, p)
		n += GameState.vault_item_count(sid)
	return n

# ---- 刷新 ----

func refresh() -> void:
	if _panel == null:
		return
	var picking := _pick_cat != ""
	if picking:
		_title_lb.text = "仓库 · 选一件" + str(GEAR_CN.get(_pick_cat, _pick_cat))
		_sub_lb.text = "点一件装上（换下的那件会放回仓库）"
	else:
		_title_lb.text = "仓　库"
		if str(TABS[_tab]["id"]) == "pill":
			_sub_lb.text = "丹药收这一格 · 吃用去弟子页"
		else:
			_sub_lb.text = "分类收在这儿 · 残卡凑齐可合成（金边＝能合）"
	# v62：整理钮的牌子跟着当前排法走（选人模式下藏起来——那会儿只用点一件）
	if _sort_btn != null:
		_sort_btn.visible = not picking
		_sort_btn.text = "整理：" + str(SORT_CN[_sort_mode])
	for i in _tab_btns.size():
		var btn: Button = _tab_btns[i]
		btn.visible = not picking
		if not picking:
			var tid := str(TABS[i]["id"])
			btn.text = str(TABS[i]["name"]) + " " + str(_cat_total(tid))
			_style_tab(btn, i == _tab)
	var stacks := _stacks()
	stacks = _sort_stacks(stacks)          # v62：整理（残卷 / 成品 不再混着放）
	_stacks_now = stacks
	# v60：格子按件数现建现摆，多出来的往下滑（内容高度＝实际行数，窗口高固定）
	var rows_needed := int(ceil(float(maxi(1, stacks.size())) / float(COLS)))
	_ensure_cells(rows_needed * COLS)
	if _grid != null:
		_grid.custom_minimum_size = Vector2(GRID_W, maxf(float(GRID_VIEW_H), float(rows_needed) * (CELL + GAP) - GAP))
	for k in _cells.size():
		var cd: Dictionary = _cells[k]
		var cell: Panel = cd["panel"]
		var nm: Label = cd["name"]
		var pt: Label = cd["part"]
		var ct: Label = cd["count"]
		var ic2: TextureRect = cd["icon"]
		if k < stacks.size():
			var st: Dictionary = stacks[k]
			nm.text = str(st.get("set_name", ""))
			# ㊿z4：量身定做的功法——格子上标出来（不锁人，只是提醒"这门是照谁定的"）
			var st_sid := str(st.get("sid", ""))
			var st_note := Cards.art_owner_note(st_sid)
			if st_note != "":
				nm.text += "（" + Cards.art_owner_cn(st_sid) + "量身）"
			pt.text = str(st.get("part_name", ""))
			if str(st["kind"]) == "card":
				pt.add_theme_font_size_override("font_size", 20)
			elif str(st["kind"]) == "pill":
				pt.add_theme_font_size_override("font_size", 15)
			elif str(st["kind"]) == "mat":
				pt.add_theme_font_size_override("font_size", 20)   # v60：材料名也是两三个字，跟卡名一个号
			else:
				pt.add_theme_font_size_override("font_size", 13)
			var n := int(st.get("count", 1))
			# ㊿：凑齐的那一套直接标出来（×N ✓）——点开就能合成
			var can := false
			if str(st.get("kind", "")) == "card":
				can = GameState.can_synthesize(str(st.get("sid", "")))
			if can:
				ct.text = "×" + str(n) + " ✓可合成"
				ct.add_theme_color_override("font_color", Color(0.62, 0.44, 0.08, 1.0))
			else:
				ct.text = "×" + str(n)
				ct.add_theme_color_override("font_color", Color(SEAL.r, SEAL.g, SEAL.b, 0.90))
			ct.visible = (n > 1) or can
			# v93o：这一件的图标（材料按材料键、丹药用丹盒、装备按 pool 挑图）
			var kd := str(st.get("kind", ""))
			var sid2 := str(st.get("sid", ""))
			if kd == "mat":
				ic2.texture = ItemIcons.for_mat(sid2)
			elif kd == "pill":
				ic2.texture = ItemIcons.for_pill()
			elif kd == "item" or kd == "card":
				ic2.texture = ItemIcons.for_pool(str(st.get("pool", "")), str(st.get("weapon", "")), sid2)
			else:
				ic2.texture = ItemIcons.fallback()
			# 品级色：装备/功法按套的品级；丹药按丹的品级；材料不标
			var qc = null
			if kd == "item" or kd == "card" or kd == "pill":
				qc = ItemIcons.quality_col_of(sid2)
			cell.add_theme_stylebox_override("panel", _cell_box(str(st["kind"]), can, qc))
		else:
			nm.text = ""
			pt.text = ""
			ct.text = ""
			ct.visible = false
			ic2.texture = null
			cell.add_theme_stylebox_override("panel", _cell_box(""))
	var empty := stacks.is_empty()
	if picking and empty:
		_empty1.text = "没有可用的成品"
		_empty2.text = "先把残卡凑齐合成；测试可用 M 塞货（主界面按 M）"
	else:
		_empty1.text = str(TABS[_tab]["e1"])
		_empty2.text = str(TABS[_tab]["e2"])
	_empty1.visible = empty
	_empty2.visible = empty
	if str(TABS[_tab]["id"]) == "pill" and not picking:
		_count_lb.text = "丹药共 " + str(_cat_total("pill")) + " 颗 · 本页 " + str(stacks.size()) + " 种"
	elif str(TABS[_tab]["id"]) == "mat" and not picking:
		_count_lb.text = "材料共 " + str(_cat_total("mat")) + " 件 · 本页 " + str(stacks.size()) + " 种（起屋 · 炼丹 · 升星都吃它）"
	else:
		_count_lb.text = "残卡 " + str(GameState.vault_total()) + " · 成品 " + str(GameState.vault_item_total()) + " · 本页 " + str(_cat_total(str(TABS[_tab]["id"])))
	_refresh_gift()

# v40：新手关卡礼包那一条——到手才显；按钮写清"现在能不能开、下一格是第几关给谁"
func _refresh_gift() -> void:
	if _gift_box == null:
		return
	if not GameState.stage_gift_got:
		_gift_box.visible = false
		return
	_gift_box.visible = true
	_gift_name.text = "新手关卡礼包　已开 " + str(GameState.stage_gift_opened) + "/" + str(GameState.stage_gift_total())
	var can: Dictionary = GameState.stage_gift_can()
	var ok := bool(can.get("ok", false))
	# 不能开时只写"为什么"（那句本身就是可行动的下一步），能开时写下一格给什么
	_gift_sub.text = GameState.stage_gift_next_line() if ok else str(can.get("msg", ""))
	_gift_btn.disabled = not ok
	_gift_btn.text = "开" if ok else "未到"

func _on_gift_open() -> void:
	var r: Dictionary = GameState.stage_gift_open()
	_msg_lb.text = str(r.get("msg", ""))
	refresh()   # 开出来的成品直接进仓库——刷一遍让它出现在格子里

# ---- 点格子 ----
# v61b：原来的 `_on_cell_gui`（按**下**就触发）已撤——格子改走 UiKit.tap_in_scroll，
#   逻辑只留"真的点中了"之后的这一段（见 _ensure_cells 里的注释）。

func _click_cell(k: int) -> void:
	if k < 0 or k >= _stacks_now.size():
		return
	var st: Dictionary = _stacks_now[k]
	if _pick_cat != "":
		picked.emit(str(st.get("sid", "")))
		close()
		return
	if str(st["kind"]) == "pill":
		var r2: Dictionary = GameState.recipe_of(str(st.get("sid", "")))
		var cnt := str(st["count"])
		var pstat := str(r2.get("stat", ""))
		if pstat == "pet":
						_msg_lb.text = "「" + str(st["title"]) + "」×" + cnt + "：宠物粮——去「宠物」面板喂它（升阶用）"
		elif pstat == "pet_apt":
						_msg_lb.text = "「" + str(st["title"]) + "」×" + cnt + "：宠物资质丹——去「宠物」面板［服洗灵丹］（资质 +2，每阶限 1 颗）"
		else:
			_msg_lb.text = "「" + str(st["title"]) + "」×" + cnt + "：" + str(r2.get("desc", "")) + "——去「弟子」面板，选中人点右下［服药］格吃"
		return
	if str(st["kind"]) == "mat":
		# v60：材料点一下给句"这料干什么用的"——去处从丹方表反查（见 _mat_use）
		_msg_lb.text = "「" + str(st["title"]) + "」×" + str(st["count"]) + "：" + _mat_use(str(st.get("sid", "")))
		return
	if str(st["kind"]) == "item":
		# v58（用户："装备在仓库也可以装备吧 点击装备跳转到弟子页面就好了"）：
		#   原来这里只写一句"去弟子面板点装备格"——等于没有动作。现在点一下开一页**装配窗**：
		#   写清这件是什么、加什么、现在谁拿着，底下［装备（去弟子页）］一键跳过去装上。
		_open_equip_win(str(st.get("sid", "")))
	else:
		# ㊿：残页/残卡——点开就是**合成页**（以前这里只写"合成台随后接"，等于没有）
		_ask_synth(str(st.get("sid", "")))

# v60：这一味料"用在哪儿"——从丹方表（DAN_RECIPES 的 cost）反查，
#   丹方一改这里自动跟；木料另加一句"起屋/起炉"（那两笔账在菜单侧，不在丹方里）。
func _mat_use(k: String) -> String:
	var uses: Array = []
	for r_v in GameState.DAN_RECIPES:
		var r: Dictionary = r_v
		var cost: Dictionary = r.get("cost", {})
		if cost.has(k):
			uses.append("「" + str(r.get("name", r.get("id", ""))) + "」×" + str(int(cost[k])))
	if k == "wood":
		uses.append("起屋/起炉（百工坊、炼丹阁都吃木料）")
	if uses.is_empty():
		return "眼下还没有配方吃它——先攒着"
	return "用在：" + "、".join(PackedStringArray(uses))

# ============================================================
# v58：仓库里的**装配窗**（用户："装备在仓库也可以装备吧 点击装备跳转到弟子页面就好了"）
#   · 写清这件是什么（类别/品质/星/属性/五行）、仓库几件、现在谁拿着
#   · ［装备（去弟子页）］→ 发 equip_requested(sid)；主界面收到后**关仓库、开弟子页、装上**
#   （装配本身仍走 GameState.equip_*，与弟子面板那条路同一个口——不另写一套）
# ============================================================
func _open_equip_win(sid: String) -> void:
	if sid == "":
		return
	_close_equip_win()
	_close_synth()   # v63c：两个弹窗永远不叠着开
	var vp := get_viewport_rect().size
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.35)
	veil.size = vp
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	# v63c：点窗外空白就关掉（跟合成页一个手感）——不然窗口只能走［再看看］/Esc
	veil.gui_input.connect(_on_eq_blank)
	add_child(veil)
	_eq_veil = veil
	var w := Panel.new()
	w.position = Vector2((vp.x - EQ_W) * 0.5, (vp.y - EQ_H) * 0.5)
	w.size = Vector2(EQ_W, EQ_H)
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.99)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	sb.set_border_width_all(2)
	w.add_theme_stylebox_override("panel", sb)
	veil.add_child(w)
	_eq_win = w
	var pool := str(Cards.by_id(sid).get("pool", ""))
	var is_arts := pool == "arts"
	var t1 := _label(Cards.item_name(sid) + GameState.star_marks(sid), 26, INK)
	t1.position = Vector2(26, 20)
	t1.size = Vector2(EQ_W - 52.0, 36)
	w.add_child(t1)
	var kind_cn := "功法·武学" if is_arts else str(GEAR_CN.get(pool, Cards.name_of(sid)))
	var kind_full := kind_cn
	if is_arts:
		var cid := Cards.cat_of(sid)
		if cid != "":
			kind_full = "功法·" + Cards.cat_name(cid)
	var t2 := _label(GameState.grade_of(sid) + "　【" + kind_full + "】", 17, Color(INK.r, INK.g, INK.b, 0.66))
	t2.position = Vector2(26, 58)
	t2.size = Vector2(EQ_W - 52.0, 26)
	w.add_child(t2)
	var lines: Array = []
	lines.append("仓库现有 ×" + str(GameState.vault_item_count(sid)))
	var el := GameState.elem_line(sid)
	if el != "":
		lines.append("五行：" + el)
	lines.append("加成：" + Cards.bonus_text(GameState.starred_stats(sid)))
	# v63（用户："我得穿上了才能看到技能"）：武学的**招式说明**直接写进弹窗——
	#   不用先装到弟子身上再去面板里看。
	if is_arts:
		# v132：先报**归类**（用户："功法要做归类了"），再报招式
		var cl := Cards.cat_line(sid)
		if cl != "":
			lines.append(cl)
		var ad: Dictionary = Cards.by_id(sid).get("art", {})
		# v142：走 GameData.move_desc —— 会补上"几段/打哪几排"，以及负面/控制那一行
		#   （写玩家手上的实际值，并括注"怪手上是几手"）
		var adesc := str(GameData.move_desc(ad))
		if adesc != "":
			lines.append("招式：" + adesc)
	lines.append("升星 ×" + str(snappedf(GameState.star_mul(sid), 0.1)) + "（去［升 星］合星——星记在这件上）")
	var holders: Array = []
	for rid_v in GameState.disciple_ids():
		var rid := str(rid_v)
		var d: Dictionary = GameState.role_data(rid)
		var nm2 := str(d.get("name", rid))
		if is_arts:
			if (d.get("skills", []) as Array).has(sid):
				holders.append(nm2)
		elif str(d.get("weapon", "")) == sid:
			holders.append(nm2)
		else:
			var gr: Dictionary = d.get("gear", {})
			for sl in gr.keys():
				if str(gr[sl]) == sid:
					holders.append(nm2)
					break
	lines.append("现在：" + ("、".join(PackedStringArray(holders)) + " 拿着" if not holders.is_empty() else "没人拿"))
	var body := _label("\n".join(PackedStringArray(lines)), 18, Color(INK.r, INK.g, INK.b, 0.92))
	body.position = Vector2(26, 100)
	body.size = Vector2(EQ_W - 52.0, 150)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w.add_child(body)
	var ok := Button.new()
	ok.text = "装备（去弟子页）"
	ok.position = Vector2(26, EQ_H - 78.0)
	ok.size = Vector2(240, 56)
	ok.add_theme_font_size_override("font_size", 20)
	ok.focus_mode = Control.FOCUS_NONE
	_style_dark_button(ok)
	ok.pressed.connect(_equip_go.bind(sid))
	w.add_child(ok)
	var back := Button.new()
	back.text = "再看看"
	back.position = Vector2(282, EQ_H - 78.0)
	back.size = Vector2(160, 56)
	back.add_theme_font_size_override("font_size", 20)
	back.focus_mode = Control.FOCUS_NONE
	_style_dark_button(back)
	back.pressed.connect(_close_equip_win)
	w.add_child(back)

func _equip_go(sid: String) -> void:
	_close_equip_win()
	equip_requested.emit(sid)

func _close_equip_win() -> void:
	if _eq_veil != null and is_instance_valid(_eq_veil):
		_eq_veil.queue_free()
	_eq_veil = null
	_eq_win = null

func _on_eq_blank(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_close_equip_win()

# ============================================================
# ㊿ 仓库合成：武学残页 / 兵器装备残卡，凑齐了就**在这儿合**
#   规则真源在 game_state：can_synthesize（齐没齐）／synth_missing（还缺哪几页）
#   ／synthesize（各吃一页、成品进仓库、记收集）。这里只负责摆给人看。
# ============================================================
func _ask_synth(sid: String) -> void:
	if sid == "" or Cards.by_id(sid).is_empty():
		return
	_close_synth()
	_close_equip_win()   # v63c：两个弹窗永远不叠着开
	var parts: Array = Cards.parts_of(sid)
	var item_nm := str(Cards.item_name(sid))
	var vp := get_viewport_rect().size
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.42)
	veil.size = vp
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	_synth_veil = veil
	var pw := 560.0
	var miss := GameState.synth_missing(sid)
	var ph := 150.0 + float(parts.size()) * 34.0 + 80.0
	var panel := Panel.new()
	panel.position = Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.99)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	psb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", psb)
	veil.add_child(panel)

	var tt := _label("『" + item_nm + "』残页", 24, INK)
	tt.position = Vector2(0, 16)
	tt.size = Vector2(pw, 34)
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(tt)

	var kind_cn := "武学" if Cards.is_arts(sid) else "兵器"
	var sub := _label(kind_cn + " · " + Cards.quality_of(sid) + "　·　共 " + str(parts.size()) + " 页，各吃一张，合成「" + item_nm + "」", 14, Color(INK.r, INK.g, INK.b, 0.62))
	sub.position = Vector2(0, 54)
	sub.size = Vector2(pw, 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sub)

	var y := 90.0
	for i in parts.size():
		var have := GameState.vault_count(sid, i)
		var lb := _label(str(parts[i]) + "　×" + str(have) + ("" if have > 0 else "　（缺）"), 17, INK if have > 0 else SEAL)
		lb.position = Vector2(48, y)
		lb.size = Vector2(pw - 96.0, 28)
		panel.add_child(lb)
		y += 34.0

	var ready := miss.is_empty()
	var status := "齐了——可以合一件" if ready else "还缺 " + str(miss.size()) + " 页，先去历练/游历里攒"
	var st_lb := _label(status, 16, Color(0.62, 0.44, 0.08, 1.0) if ready else SEAL)
	st_lb.position = Vector2(48, y + 4.0)
	st_lb.size = Vector2(pw - 96.0, 26)
	panel.add_child(st_lb)

	var mk := Button.new()
	mk.text = "合成一件"
	mk.position = Vector2(60, y + 44.0)
	mk.size = Vector2(200, 54)
	mk.add_theme_font_size_override("font_size", 19)
	mk.focus_mode = Control.FOCUS_NONE
	mk.disabled = not ready
	mk.pressed.connect(_do_synth.bind(sid))
	_style_dark_button(mk)
	panel.add_child(mk)

	var back := Button.new()
	back.text = "知道了"
	back.position = Vector2(300, y + 44.0)
	back.size = Vector2(200, 54)
	back.add_theme_font_size_override("font_size", 19)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_close_synth)
	_style_dark_button(back)
	panel.add_child(back)
	veil.gui_input.connect(_on_synth_blank)

func _do_synth(sid: String) -> void:
	var r: Dictionary = GameState.synthesize(sid)
	var ok := bool(r.get("ok", false))
	_msg_lb.text = str(r.get("msg", ""))
	_msg_lb.add_theme_color_override("font_color", Color(0.62, 0.44, 0.08, 0.95) if ok else Color(SEAL.r, SEAL.g, SEAL.b, 0.85))
	print("[仓库] 合成 ", sid, "：", r)
	# 合完重新摆一次这一页：手里还有余页就能接着合，没了按钮自己变灰
	refresh()
	_ask_synth(sid)

func _on_synth_blank(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_close_synth()

func _close_synth() -> void:
	if _synth_veil != null and is_instance_valid(_synth_veil):
		_synth_veil.queue_free()
	_synth_veil = null

func _on_tab(i: int) -> void:
	_tab = i
	refresh()
	# v60：换页把格子区滑回顶部（上一个页签滑下去过，不重置会一脸空白）
	if _scroll != null:
		_scroll.set_deferred("scroll_vertical", 0)

# ---- 开合 ----

func open() -> void:
	_pick_cat = ""
	_tab = 0
	_msg_lb.text = ""
	# v63c：开面板先把两个弹窗都清掉——不管上一回是怎么离开的，这次都是白纸一张
	_close_equip_win()
	_close_synth()
	refresh()
	visible = true

func begin_pick(cat: String) -> void:
	_pick_cat = cat
	_tab = 1 if cat == "arts" else 0
	_msg_lb.text = ""
	# v63c：选件模式同理——弟子页跳过来时不能带着上一回留下的旧弹窗
	_close_equip_win()
	_close_synth()
	refresh()
	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	_pick_cat = ""
	# v63（用户："不管穿戴装备还是武学，总会弹上一个穿戴物品的描述"）：
	#   病根：装配窗（_eq_veil）是面板的**子节点**——关面板只是"隐藏"，弹窗跟着藏起来；
	#   下次开面板（比如弟子页点武学格 → 选一件）它**一起显形** ✗ 于是永远弹旧兵器的信息 ✗。
	#   这里把弹窗一并清掉：面板再开时就是干净的一张纸。
	_close_equip_win()
	_close_synth()   # v63c：残页合成页同病——也是面板的子节点，不跟着清就会在下次开面板时诈尸
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
