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
const Ui := preload("res://menu/menu_theme.gd")    # v205：影之刃皮肤
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
const CELL := 112.0
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

# v214：底部详情抽屉（点格子滑出；不再一上来就弹窗）
var _drawer: Control = null
var _drawer_icon: TextureRect
var _drawer_name: Label
var _drawer_kind_lb: Label
var _drawer_desc: Label
var _drawer_btn1: Button
var _drawer_btn2: Button
var _drawer_idx := -1
var _drawer_tween: Tween = null

# v217：长按 0.4s → 批量选择
var _multi := false
var _multi_sel := {}          # 页码 → true（列表一变就清）
var _multi_bar: Panel = null
var _multi_lb: Label = null
var _multi_btn_synth: Button = null
var _hold_k := -1
var _hold_from := 0
var _hold_x := 0.0
var _hold_y := 0.0
var _hold_moved := false
var _long_fired := false

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
	if Ui.SKIN == 1:
		psb.bg_color = Color(0.961, 0.941, 0.898, 0.985)
		psb.set_corner_radius_all(4)
		psb.border_color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.55)
		psb.set_border_width_all(2)
	else:
		psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.98)
		psb.set_corner_radius_all(14)
		psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
		psb.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", psb)
	add_child(_panel)
	# v77：垫一张货仓内景（用户：「是不是也要换图了」）——34% 透明度，纸底还透、字照样清楚
	if Ui.SKIN != 1:
		UiKit.add_room_bg(_panel, SceneArt.store_room(), 0.34)   # v205：新皮肤不要内景底图（跟影之刃的净板打架）
	else:
		var chrome := Control.new()
		chrome.size = Vector2(PANEL_W, PANEL_H)
		chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chrome.draw.connect(func() -> void: Ui.header(chrome, PANEL_W, 78.0))
		_panel.add_child(chrome)

	_title_lb = _label("仓　库", 30, INK)
	if Ui.SKIN == 1:
		_title_lb.add_theme_font_size_override("font_size", 34)
		_title_lb.add_theme_color_override("font_color", Ui.GOLD_HI)
		var bf := Ui.brush_font()
		if bf != null:
			_title_lb.add_theme_font_override("font", bf)
	_title_lb.position = Vector2(28, 18)
	_title_lb.size = Vector2(206, 36)
	_panel.add_child(_title_lb)

	# v132：副标题缩到标题底下那一小条（12 号、两行以内）——右边两颗钮（归类/整理）
	#   原来那颗长副标题（390 宽）尾巴会被钮压住，改成短句 + 自动换行，谁也不压谁。
	_sub_lb = _label("分类收在这儿 · 残卡凑齐可合成", 12, Color(INK.r, INK.g, INK.b, 0.55))
	_sub_lb.position = Vector2(30, 84) if Ui.SKIN == 1 else Vector2(30, 52)   # v205：刊头高 78，副标题得让开
	_sub_lb.visible = Ui.SKIN != 1      # 刊头抢地方，这行小字直接收掉
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
	_scroll.position = Vector2(24, 162)
	_scroll.size = Vector2(PANEL_W - 48.0, GRID_VIEW_H)
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

	# v214：旧页脚那句「还没接存档：关掉游戏会清零」是早期遗留的错话（现在每 20 秒都落盘），撤掉。

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(PANEL_W - 228.0, 674)
	close_btn.size = Vector2(200, 60)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	_style_dark_button(close_btn)
	_panel.add_child(close_btn)

	# ============================================================
	# v214：**底部详情抽屉**（设计规范第 4 节）——点格子从下滑出 320 高，
	#   左 96 图标 / 右 名称+品阶+描述 / 底部两颗按钮；不再"点一下弹一个窗"。
	# ============================================================
	_drawer = Control.new()
	_drawer.position = Vector2(0.0, PANEL_H)
	_drawer.size = Vector2(PANEL_W, 320.0)
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.visible = false
	_panel.add_child(_drawer)
	var dbg := Control.new()
	dbg.size = _drawer.size
	dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dbg.draw.connect(_draw_drawer_bg.bind(dbg))
	_drawer.add_child(dbg)

	_drawer_icon = TextureRect.new()
	_drawer_icon.position = Vector2(38, 38)
	_drawer_icon.size = Vector2(76, 76)
	_drawer_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drawer_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drawer_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer.add_child(_drawer_icon)

	_drawer_name = _label("", 24, Ui.GOLD_HI if Ui.SKIN == 1 else INK)
	_drawer_name.position = Vector2(144, 20)
	_drawer_name.size = Vector2(410, 34)
	_drawer.add_child(_drawer_name)

	_drawer_kind_lb = _label("", 13,
		Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.85) if Ui.SKIN == 1 else Color(INK.r, INK.g, INK.b, 0.60))
	_drawer_kind_lb.position = Vector2(144, 54)
	_drawer_kind_lb.size = Vector2(410, 20)
	_drawer.add_child(_drawer_kind_lb)

	_drawer_desc = _label("", 15,
		Color(0.90, 0.86, 0.78, 0.96) if Ui.SKIN == 1 else Color(INK.r, INK.g, INK.b, 0.85))
	_drawer_desc.position = Vector2(144, 80)
	_drawer_desc.size = Vector2(440, 106)
	_drawer_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_drawer.add_child(_drawer_desc)

	_drawer_btn1 = Button.new()
	_drawer_btn1.position = Vector2(144, 246)
	_drawer_btn1.size = Vector2(210, 54)
	_drawer_btn1.add_theme_font_size_override("font_size", 19)
	_drawer_btn1.focus_mode = Control.FOCUS_NONE
	_drawer_btn1.pressed.connect(_drawer_go)
	_drawer_btn1.add_theme_stylebox_override("normal", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.94)))
	_drawer_btn1.add_theme_stylebox_override("hover", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.80)))
	_drawer_btn1.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r * 0.75, SEAL.g * 0.75, SEAL.b * 0.75, 0.96)))
	_drawer_btn1.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86))
	_drawer.add_child(_drawer_btn1)

	_drawer_btn2 = Button.new()
	_drawer_btn2.position = Vector2(370, 246)
	_drawer_btn2.size = Vector2(202, 54)
	_drawer_btn2.add_theme_font_size_override("font_size", 19)
	_drawer_btn2.focus_mode = Control.FOCUS_NONE
	_drawer_btn2.pressed.connect(_drawer_detail)
	_style_dark_button(_drawer_btn2)
	UiKit.font_states(_drawer_btn2, Color(0.94, 0.91, 0.84))
	_drawer.add_child(_drawer_btn2)

	var dx := Button.new()
	dx.text = "×"
	dx.position = Vector2(566, 12)
	dx.size = Vector2(46, 46)
	dx.add_theme_font_size_override("font_size", 24)
	dx.focus_mode = Control.FOCUS_NONE
	dx.pressed.connect(_close_drawer)
	_style_dark_button(dx)
	_drawer.add_child(dx)

	# ---- v217：批量选择条（长按 0.4s 进）----
	_multi_bar = Panel.new()
	_multi_bar.position = Vector2(0, PANEL_H - 110.0)
	_multi_bar.size = Vector2(PANEL_W, 110.0)
	_multi_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_multi_bar.visible = false
	var mbs := StyleBoxFlat.new()
	mbs.bg_color = Color(0.075, 0.066, 0.060, 0.985)
	mbs.border_color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.62)
	mbs.set_border_width_all(2)
	mbs.set_corner_radius_all(4)
	_multi_bar.add_theme_stylebox_override("panel", mbs)
	_panel.add_child(_multi_bar)
	_multi_lb = _label("批量选择 · 已选 0 件", 18,
		Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.96) if Ui.SKIN == 1 else INK)
	_multi_lb.position = Vector2(24, 12)
	_multi_lb.size = Vector2(330, 28)
	_multi_bar.add_child(_multi_lb)
	var m_all := Button.new()
	m_all.text = "全选本页"
	m_all.position = Vector2(24, 54)
	m_all.size = Vector2(120, 42)
	m_all.add_theme_font_size_override("font_size", 16)
	m_all.focus_mode = Control.FOCUS_NONE
	m_all.pressed.connect(_multi_all)
	_style_dark_button(m_all)
	_multi_bar.add_child(m_all)
	var m_clr := Button.new()
	m_clr.text = "清空"
	m_clr.position = Vector2(154, 54)
	m_clr.size = Vector2(86, 42)
	m_clr.add_theme_font_size_override("font_size", 16)
	m_clr.focus_mode = Control.FOCUS_NONE
	m_clr.pressed.connect(_multi_clear)
	_style_dark_button(m_clr)
	_multi_bar.add_child(m_clr)
	_multi_btn_synth = Button.new()
	_multi_btn_synth.text = "合成所选"
	_multi_btn_synth.position = Vector2(250, 54)
	_multi_btn_synth.size = Vector2(190, 42)
	_multi_btn_synth.add_theme_font_size_override("font_size", 17)
	_multi_btn_synth.focus_mode = Control.FOCUS_NONE
	_multi_btn_synth.pressed.connect(_multi_synth)
	_multi_btn_synth.add_theme_stylebox_override("normal", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.94)))
	_multi_btn_synth.add_theme_stylebox_override("hover", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.80)))
	_multi_btn_synth.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r * 0.75, SEAL.g * 0.75, SEAL.b * 0.75, 0.96)))
	_multi_btn_synth.add_theme_stylebox_override("disabled", _flat(Color(0.35, 0.32, 0.30, 0.5)))
	_multi_btn_synth.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86))
	_multi_btn_synth.add_theme_color_override("font_disabled_color", Color(0.8, 0.76, 0.68, 0.5))
	_multi_bar.add_child(_multi_btn_synth)
	var m_quit := Button.new()
	m_quit.text = "退出"
	m_quit.position = Vector2(450, 54)
	m_quit.size = Vector2(86, 42)
	m_quit.add_theme_font_size_override("font_size", 16)
	m_quit.focus_mode = Control.FOCUS_NONE
	m_quit.pressed.connect(func() -> void: _exit_multi(false))
	_style_dark_button(m_quit)
	_multi_bar.add_child(m_quit)
	var m_tip := _label("长按卡片 = 批量选择 · 动作只支持残卡合成", 11,
		Color(Ui.TXT_DIM.r, Ui.TXT_DIM.g, Ui.TXT_DIM.b, 0.8))
	m_tip.position = Vector2(360, 16)
	m_tip.size = Vector2(256, 22)
	m_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_multi_bar.add_child(m_tip)

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
		cell.gui_input.connect(_hold_input.bind(cell, k))
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
		var nm := _label("", 11, Color(Ui.TXT_DIM.r, Ui.TXT_DIM.g, Ui.TXT_DIM.b, 0.90) if Ui.SKIN == 1 else Color(INK.r, INK.g, INK.b, 0.55))
		nm.position = Vector2(3, CELL - 22.0)
		nm.size = Vector2(CELL * 0.6, 16)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cell.add_child(nm)
		# v60：名字这行**可换行**（丹药名"突破丹（凡品）"7 个字，88 宽的老格子是要溢出的）
		var pt := _label("", 16, Ui.TXT if Ui.SKIN == 1 else INK)
		pt.position = Vector2(4, 58)
		pt.size = Vector2(CELL - 8.0, CELL - 80.0)
		pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pt.max_lines_visible = 2
		pt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.add_child(pt)
		var ct := _label("", 12, Ui.GOLD_HI if Ui.SKIN == 1 else Color(SEAL.r, SEAL.g, SEAL.b, 0.90))
		ct.position = Vector2(3, CELL - 22.0)
		ct.size = Vector2(CELL - 6.0, 18)
		ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cell.add_child(ct)
		# v214：底边 3px 品级色条（凡灰/良绿/上蓝/极紫/绝金）
		var bar := ColorRect.new()
		bar.position = Vector2(2.0, CELL - 4.0)
		bar.size = Vector2(CELL - 4.0, 3.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		cell.add_child(bar)
		# v217：批量选择的选中框（金边，盖在色条上）
		var sel := Panel.new()
		sel.position = Vector2.ZERO
		sel.size = Vector2(CELL, CELL)
		sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ssb := StyleBoxFlat.new()
		ssb.bg_color = Color(0, 0, 0, 0)
		ssb.border_color = Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.98) if Ui.SKIN == 1 else Color(SEAL.r, SEAL.g, SEAL.b, 0.90)
		ssb.set_border_width_all(3)
		ssb.set_corner_radius_all(3)
		sel.add_theme_stylebox_override("panel", ssb)
		sel.visible = false
		cell.add_child(sel)
		_cells.append({"panel": cell, "name": nm, "part": pt, "count": ct, "icon": ic, "bar": bar, "sel": sel})

func _flat(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if Ui.SKIN == 1:
		sb.set_corner_radius_all(2)
		if bg.a > 0.10:      # focus 那种全透明框别加边，否则按钮外面多一个金框
			sb.border_color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.40)
			sb.set_border_width_all(1)
	else:
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
	# v214：皮肤下改成"墨底金线 + 底边品级色条"（色条是格子里另画的一条 ColorRect）
	if Ui.SKIN == 1:
		sb.set_corner_radius_all(3)
		sb.set_border_width_all(1)
		if kind == "":
			sb.bg_color = Color(0.886, 0.859, 0.784, 0.30)
			sb.border_color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.16)
			return sb
		sb.bg_color = Color(0.095, 0.082, 0.072, 0.96)
		sb.border_color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.34)
		if ready:
			sb.border_color = Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.95)
			sb.set_border_width_all(2)
		return sb
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
		var q: Color = q_col
		sb.border_color = Color(q.r, q.g, q.b, 0.95)
		sb.set_border_width_all(3)
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
	# v214：列表一变（换页/整理/开礼包），抽屉先收——不然抽屉里那一件可能已经不在列表里了
	if _drawer != null and _drawer.visible:
		_close_drawer(true)
	# v217：批量选择也一起收（页码变了，旧下标没意义）
	if _multi:
		_exit_multi(false)
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
				ct.add_theme_color_override("font_color", Ui.GOLD_HI if Ui.SKIN == 1 else Color(0.62, 0.44, 0.08, 1.0))
			else:
				ct.text = "×" + str(n)
				ct.add_theme_color_override("font_color",
					Color(0.96, 0.92, 0.84, 0.92) if Ui.SKIN == 1 else Color(SEAL.r, SEAL.g, SEAL.b, 0.90))
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
			# v214：底边品级色条
			var bar: ColorRect = cd["bar"]
			if qc != null:
				bar.color = Color(qc.r, qc.g, qc.b, 0.95)
				bar.visible = true
			else:
				bar.visible = false
		else:
			nm.text = ""
			pt.text = ""
			ct.text = ""
			ct.visible = false
			ic2.texture = null
			cell.add_theme_stylebox_override("panel", _cell_box(""))
			var bar0: ColorRect = cd["bar"]
			bar0.visible = false
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

# ============================================================
# v217：长按 0.4s → 批量选择（当前只给残卡做"批量合成"）
# ============================================================
func _process(_delta: float) -> void:
	if not visible:
		return
	if _hold_k >= 0 and not _long_fired and not _hold_moved and Time.get_ticks_msec() - _hold_from >= 400:
		var k := _hold_k
		_hold_k = -1
		_long_fired = true
		_enter_multi(k)

func _hold_input(ev: InputEvent, _cell: Control, k: int) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_hold_k = k
			_hold_from = Time.get_ticks_msec()
			_hold_x = mb.position.x
			_hold_y = mb.position.y
			_hold_moved = false
			_long_fired = false
		elif _hold_k == k:
			_hold_k = -1
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _hold_k == k and mm.button_mask != 0 and Vector2(mm.position.x - _hold_x, mm.position.y - _hold_y).length() > 14.0:
			_hold_moved = true
	elif ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		if t.pressed:
			_hold_k = k
			_hold_from = Time.get_ticks_msec()
			_hold_x = t.position.x
			_hold_y = t.position.y
			_hold_moved = false
			_long_fired = false
		elif _hold_k == k:
			_hold_k = -1
	elif ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		if _hold_k == k and Vector2(sd.position.x - _hold_x, sd.position.y - _hold_y).length() > 14.0:
			_hold_moved = true

func _enter_multi(k: int) -> void:
	if k < 0 or k >= _stacks_now.size():
		return
	if not _multi:
		_multi = true
		_multi_sel.clear()
		_close_drawer(true)
		_multi_bar.visible = true
		_multi_bar.move_to_front()
	_toggle_sel(k)

func _toggle_sel(k: int) -> void:
	if k < 0 or k >= _cells.size() or k >= _stacks_now.size():
		return
	if _multi_sel.has(k):
		_multi_sel.erase(k)
	else:
		_multi_sel[k] = true
	var sel: Panel = _cells[k]["sel"]
	sel.visible = _multi_sel.has(k)
	_update_multi_bar()

func _update_multi_bar() -> void:
	if _multi_bar == null:
		return
	var n := _multi_sel.size()
	_multi_lb.text = "批量选择 · 已选 " + str(n) + " 件"
	var synth := 0
	for k_v in _multi_sel.keys():
		var k := int(k_v)
		if k < _stacks_now.size():
			var st: Dictionary = _stacks_now[k]
			if str(st.get("kind", "")) == "card" and GameState.can_synthesize(str(st.get("sid", ""))):
				synth += 1
	_multi_btn_synth.disabled = synth <= 0
	_multi_btn_synth.text = "合成所选" + (("（" + str(synth) + "）") if synth > 0 else "")

func _multi_all() -> void:
	_multi_sel.clear()
	for k in _stacks_now.size():
		if k < _cells.size():
			_multi_sel[k] = true
			(_cells[k]["sel"] as Panel).visible = true
	_update_multi_bar()

func _multi_clear() -> void:
	_multi_sel.clear()
	for cd in _cells:
		(cd["sel"] as Panel).visible = false
	_update_multi_bar()

func _multi_synth() -> void:
	var sids: Array = []
	for k_v in _multi_sel.keys():
		var k := int(k_v)
		if k >= _stacks_now.size():
			continue
		var st: Dictionary = _stacks_now[k]
		var sid := str(st.get("sid", ""))
		if str(st.get("kind", "")) == "card" and GameState.can_synthesize(sid) and not sids.has(sid):
			sids.append(sid)
	var done := 0
	var msgs: Array = []
	for sid_v in sids:
		var r: Dictionary = GameState.synthesize(str(sid_v))
		if bool(r.get("ok", false)):
			done += 1
			msgs.append(str(r.get("msg", "")))
	_msg_lb.text = "批量合成：合了 " + str(done) + " 件" + ("（" + "；".join(PackedStringArray(msgs)) + "）" if done > 0 else "——选中的残卡还没凑齐")
	_exit_multi(true)

func _exit_multi(do_refresh: bool) -> void:
	_multi = false
	_multi_sel.clear()
	if _multi_bar != null:
		_multi_bar.visible = false
	for cd in _cells:
		(cd["sel"] as Panel).visible = false
	if do_refresh:
		refresh()

# v214：点格子 = 开底部抽屉（真正的动作在抽屉那两颗钮里）
# v217：批量选择模式下 = 勾选/取消
func _click_cell(k: int) -> void:
	if _long_fired:
		_long_fired = false
		return
	if _multi:
		_toggle_sel(k)
		return
	_open_drawer(k)


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
# v214：底部详情抽屉
# ============================================================
func _draw_drawer_bg(c: Control) -> void:
	Ui.panel(c, Rect2(0.0, 0.0, c.size.x, c.size.y), {
		"fill": Color(0.075, 0.066, 0.060, 0.985),
		"edge": Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.62),
		"cut": 10.0, "bracket": true, "shadow": 1.0, "ink_halo": false})
	c.draw_line(Vector2(14.0, 3.0), Vector2(c.size.x - 14.0, 3.0),
		Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.55), 2.0, true)
	var slot := Rect2(28.0, 26.0, 96.0, 96.0)
	var sp := Ui.cut_poly(slot, 8.0)
	c.draw_colored_polygon(sp, Color(0.030, 0.026, 0.022, 0.95))
	var q := PackedVector2Array(sp)
	q.append(sp[0])
	c.draw_polyline(q, Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.45), 1.4, true)
	c.draw_line(Vector2(28.0, 196.0), Vector2(c.size.x - 28.0, 196.0),
		Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.18), 1.0, true)

# 点格子 → 填内容 + 从下滑出（0.18s，TRANS_BACK）
func _open_drawer(k: int) -> void:
	if k < 0 or k >= _stacks_now.size():
		return
	_drawer_idx = k
	var st: Dictionary = _stacks_now[k]
	var kd := str(st.get("kind", ""))
	var sid := str(st.get("sid", ""))
	var count := int(st.get("count", 1))
	var title := str(st.get("title", st.get("set_name", "")))
	if kd == "mat":
		_drawer_icon.texture = ItemIcons.for_mat(sid)
	elif kd == "pill":
		_drawer_icon.texture = ItemIcons.for_pill()
	elif kd == "item" or kd == "card":
		_drawer_icon.texture = ItemIcons.for_pool(str(st.get("pool", "")), str(st.get("weapon", "")), sid)
	else:
		_drawer_icon.texture = ItemIcons.fallback()
	var kind_txt := ""
	var desc := ""
	var primary := "知道了"
	var secondary := "关　闭"
	var show2 := false
	if _pick_cat != "":
		kind_txt = str(GEAR_CN.get(_pick_cat, "")) + " · 选一件装上"
		desc = "点［取用］把这一件装到刚选的格子上；换下来的那件会放回仓库。"
		primary = "取　用"
	elif kd == "item":
		var pool := str(st.get("pool", ""))
		kind_txt = GameState.grade_of(sid) + " · " + str(GEAR_CN.get(pool, "成品")) + " · 现有 ×" + str(count)
		var lines: Array = []
		lines.append("加成：" + Cards.bonus_text(GameState.starred_stats(sid)) + GameState.star_marks(sid))
		if pool == "arts":
			var cl := Cards.cat_line(sid)
			if cl != "":
				lines.append(cl)
		lines.append("现在：" + _holders_text(sid, pool) + " 拿着")
		desc = "\n".join(PackedStringArray(lines))
		primary = "装　备"
		secondary = "看详情"
		show2 = true
	elif kd == "card":
		kind_txt = "残卡 · 现有 ×" + str(count)
		if GameState.can_synthesize(sid):
			desc = "这一套已经凑齐——点［合　成］直接合。"
		else:
			desc = "集齐这一套的残页可合成。点［合　成］看还差哪几张。"
		primary = "合　成"
		secondary = "关　闭"
		show2 = true
	elif kd == "pill":
		var r2: Dictionary = GameState.recipe_of(sid)
		kind_txt = "丹药 · 存 " + str(count) + " 颗"
		desc = str(r2.get("desc", "")) + "\n去「弟子」面板点右下［服药］吃；宠物粮去「宠物」面板喂。"
	elif kd == "mat":
		kind_txt = "材料 · 现有 ×" + str(count)
		desc = _mat_use(sid)
	_drawer_name.text = title
	_drawer_kind_lb.text = kind_txt
	_drawer_desc.text = desc
	_drawer_btn1.text = primary
	_drawer_btn2.text = secondary
	_drawer_btn2.visible = show2
	if _drawer.visible:
		return
	_drawer.visible = true
	_drawer.position.y = PANEL_H
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	_drawer_tween = create_tween()
	_drawer_tween.tween_property(_drawer, "position:y", PANEL_H - 320.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_drawer(instant := false) -> void:
	if _drawer == null or not _drawer.visible:
		return
	_drawer_idx = -1
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	if instant:
		_drawer.visible = false
		_drawer.position.y = PANEL_H
		return
	_drawer_tween = create_tween()
	_drawer_tween.tween_property(_drawer, "position:y", PANEL_H, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drawer_tween.tween_callback(func() -> void: _drawer.visible = false)

func _drawer_go() -> void:
	if _drawer_idx < 0 or _drawer_idx >= _stacks_now.size():
		_close_drawer()
		return
	var st: Dictionary = _stacks_now[_drawer_idx]
	var kd := str(st.get("kind", ""))
	var sid := str(st.get("sid", ""))
	if _pick_cat != "":
		picked.emit(sid)
		close()
		return
	match kd:
		"item":
			_equip_go(sid)
		"card":
			_ask_synth(sid)
		_:
			_close_drawer()

func _drawer_detail() -> void:
	if _drawer_idx < 0 or _drawer_idx >= _stacks_now.size():
		_close_drawer()
		return
	var st: Dictionary = _stacks_now[_drawer_idx]
	var kd := str(st.get("kind", ""))
	var sid := str(st.get("sid", ""))
	match kd:
		"item":
			_open_equip_win(sid)
		"card":
			_ask_synth(sid)
		_:
			_close_drawer()

func _holders_text(sid: String, pool: String) -> String:
	var holders: Array = []
	for rid_v in GameState.disciple_ids():
		var rid := str(rid_v)
		var d: Dictionary = GameState.role_data(rid)
		var nm := str(d.get("name", rid))
		if pool == "arts":
			if (d.get("skills", []) as Array).has(sid):
				holders.append(nm)
		elif str(d.get("weapon", "")) == sid:
			holders.append(nm)
		else:
			var gr: Dictionary = d.get("gear", {})
			for sl in gr.keys():
				if str(gr[sl]) == sid:
					holders.append(nm)
					break
	if holders.is_empty():
		return "没人"
	return "、".join(PackedStringArray(holders))

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
	UiKit.hide_panel(self)
	_pick_cat = ""
	_close_drawer(true)
	_exit_multi(false)
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
