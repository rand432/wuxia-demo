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
const Ui := preload("res://menu/menu_theme.gd")     # v212：影之刃皮肤（墨底金线）

signal closed

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)

# v212：货行 → **卡片流**（2 列）。面板加高到 900，一屏能看 6 张大卡。
const PANEL_W := 640.0
const PANEL_H := 820.0
const LIST_W := 564.0
const LIST_H := 530.0
const CARD_W := 276.0
const CARD_H := 180.0
const CARD_GAP := 12.0
const ROW_H := 180.0       # 兼容旧名（有些地方按行高算消息位置）
const INNER_W := 564.0

# ---- 卡片图标（素材已有的直接 preload；丹药是 v212 生成的 shop_pill.png）----
const ICON_MAP := {
	"bone": preload("res://assets/items/mat_bone.png"),
	"rice": preload("res://assets/items/mat_rice.png"),
	"jin": preload("res://assets/items/mat_jin.png"),
	"weapon_card": preload("res://assets/items/it_sword.png"),
	"art_card": preload("res://assets/items/it_book.png"),
	"gear_card": preload("res://assets/items/it_armor.png"),
	"blood_gold": preload("res://assets/items/it_jar.png"),
	"tupo_fan": preload("res://assets/ui/shop_pill.png"),
	"tupo_liang": preload("res://assets/ui/shop_pill.png"),
}
const ICON_TOOL := preload("res://assets/items/it_token.png")

var _panel: Panel
var _silver_lb: Label
var _tab_btns: Array = []
var _tab := 0
var _scroll: ScrollContainer
var _list: GridContainer
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

	# v212：自己画刊头（96 高）；打标避免 _skin_pass 再补一条 78 的
	if Ui.SKIN == 1:
		_panel.set_meta("skin_header", true)
		var chrome := Control.new()
		chrome.size = Vector2(PANEL_W, PANEL_H)
		chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chrome.draw.connect(func() -> void: Ui.header(chrome, PANEL_W, 96.0))
		_panel.add_child(chrome)
		_panel.move_child(chrome, 0)

	var title := _label("货　栈", 30, INK)
	title.position = Vector2(28, 20)
	title.size = Vector2(240, 46)
	if Ui.SKIN == 1:
		title.add_theme_color_override("font_color", Ui.GOLD_HI)
		title.add_theme_font_size_override("font_size", 36)
		var bf := Ui.brush_font()
		if bf != null:
			title.add_theme_font_override("font", bf)
	_panel.add_child(title)

	var sub := _label("银两换材料与残卡——残卡与血脉囊按真实日期限购", 13,
		Color(Ui.TXT_DIM.r, Ui.TXT_DIM.g, Ui.TXT_DIM.b, 0.85) if Ui.SKIN == 1 else Color(INK.r, INK.g, INK.b, 0.55))
	sub.position = Vector2(30, 72)
	sub.size = Vector2(430, 20)
	_panel.add_child(sub)

	_silver_lb = _label("身上银两 0", 15,
		Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.95) if Ui.SKIN == 1 else Color(SEAL.r, SEAL.g, SEAL.b, 0.92))
	_silver_lb.position = Vector2(PANEL_W - 268.0, 32)
	_silver_lb.size = Vector2(240, 26)
	_silver_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if Ui.SKIN == 1:
		_silver_lb.add_theme_font_size_override("font_size", 17)
	_panel.add_child(_silver_lb)

	var sep := ColorRect.new()
	sep.color = Color(INK.r, INK.g, INK.b, 0.22)
	sep.position = Vector2(28, 96)
	sep.size = Vector2(PANEL_W - 56.0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.visible = Ui.SKIN != 1
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
	_scroll.position = Vector2(38, 166)
	_scroll.size = Vector2(LIST_W, LIST_H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# v15x（用户："所有滑动不要滑动进度条 用指尖滑动那种就可以了"）：
	#   强制藏掉滚动条（Godot 默认主题在内容超出时会冒出来）——拖拽滚动不受影响。
	_scroll.get_v_scroll_bar().visible = false
	_scroll.get_h_scroll_bar().visible = false
	_panel.add_child(_scroll)
	_list = GridContainer.new()
	_list.columns = 2
	_list.custom_minimum_size = Vector2(INNER_W, 0)
	_list.add_theme_constant_override("h_separation", int(CARD_GAP))
	_list.add_theme_constant_override("v_separation", int(CARD_GAP))
	_scroll.add_child(_list)

	_msg_lb = _label("", 13, Color(SEAL.r, SEAL.g, SEAL.b, 0.92))
	_msg_lb.position = Vector2(38, 706)
	_msg_lb.size = Vector2(564, 24)
	_panel.add_child(_msg_lb)

	var hint := _label("限购按真实日期，跨天自动重来", 13,
		Color(Ui.TXT_DIM.r, Ui.TXT_DIM.g, Ui.TXT_DIM.b, 0.7) if Ui.SKIN == 1 else Color(INK.r, INK.g, INK.b, 0.45))
	hint.position = Vector2(38, 754)
	hint.size = Vector2(360, 22)
	_panel.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(PANEL_W - 228.0, 748)
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
	if Ui.SKIN == 1:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.11, 0.095, 0.085, 0.96)
		sb.set_corner_radius_all(3)
		sb.border_color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.45)
		sb.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", sb)
		var hv := sb.duplicate() as StyleBoxFlat
		hv.bg_color = Color(0.17, 0.15, 0.13, 0.98)
		btn.add_theme_stylebox_override("hover", hv)
		var pr := sb.duplicate() as StyleBoxFlat
		pr.bg_color = Color(0.07, 0.06, 0.055, 0.98)
		btn.add_theme_stylebox_override("pressed", pr)
		btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
		btn.add_theme_color_override("font_color", Ui.GOLD_HI)
		return
	btn.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.19, 0.20, 0.96)))
	btn.add_theme_stylebox_override("hover", _flat(Color(0.31, 0.27, 0.27, 0.96)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.11, 0.12, 0.96)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))

func _style_seal(btn: Button) -> void:
	if Ui.SKIN == 1:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Ui.CINN.r, Ui.CINN.g, Ui.CINN.b, 0.94)
		sb.set_corner_radius_all(3)
		sb.border_color = Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.55)
		sb.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", sb)
		var hv := sb.duplicate() as StyleBoxFlat
		hv.bg_color = Color(Ui.CINN_HI.r, Ui.CINN_HI.g, Ui.CINN_HI.b, 0.96)
		btn.add_theme_stylebox_override("hover", hv)
		var pr := sb.duplicate() as StyleBoxFlat
		pr.bg_color = Color(Ui.CINN.r * 0.75, Ui.CINN.g * 0.75, Ui.CINN.b * 0.75, 0.96)
		btn.add_theme_stylebox_override("pressed", pr)
		btn.add_theme_stylebox_override("disabled", _flat(Color(0.26, 0.24, 0.22, 0.55)))
		btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86))
		btn.add_theme_color_override("font_disabled_color", Color(0.85, 0.82, 0.76, 0.45))
		return
	btn.add_theme_stylebox_override("normal", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.92)))
	btn.add_theme_stylebox_override("hover", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.80)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r * 0.75, SEAL.g * 0.75, SEAL.b * 0.75, 0.95)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.35)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87))
	btn.add_theme_color_override("font_disabled_color", Color(0.96, 0.93, 0.87, 0.45))

func _style_tab(btn: Button, selected: bool) -> void:
	if Ui.SKIN == 1:
		# v212：页签＝一排小墨牌；选中转朱砂 + 金边
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		sb.set_border_width_all(1)
		if selected:
			sb.bg_color = Color(0.44, 0.12, 0.09, 0.96)
			sb.border_color = Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.85)
		else:
			sb.bg_color = Color(0.105, 0.090, 0.080, 0.94)
			sb.border_color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.30)
		btn.add_theme_stylebox_override("normal", sb)
		var hv := sb.duplicate() as StyleBoxFlat
		hv.bg_color = sb.bg_color.lightened(0.08)
		hv.border_color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.62)
		btn.add_theme_stylebox_override("hover", hv)
		var pr := sb.duplicate() as StyleBoxFlat
		pr.bg_color = sb.bg_color.darkened(0.16)
		btn.add_theme_stylebox_override("pressed", pr)
		btn.add_theme_color_override("font_color", Ui.GOLD_HI if selected else Color(0.86, 0.82, 0.74, 0.92))
		btn.add_theme_color_override("font_hover_color", Ui.GOLD_HI)
		btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
		return
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
		_add_card(it)

func _add_card(it: Dictionary) -> void:
	var key := str(it["key"])
	var kd := str(it.get("kind", "mat"))
	var is_card := kd == "card"
	var price_val: int = int(it["price"]) if not is_card else int(GameState.shop_card_price(key))
	var left := GameState.shop_left(key)
	var lim := int(it.get("limit", 0))
	var sold := left == 0
	var card := Control.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(card)
	card.draw.connect(_draw_card.bind(card, sold))

	var tex := _icon_for(it)
	if tex != null:
		var tr := TextureRect.new()
		# ⚠ 顺序有讲究：先设 expand/stretch，再设 size——反过来会被贴图的最小尺寸顶回 128
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = tex
		tr.position = Vector2(18, 18)
		tr.size = Vector2(48, 48)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tr)

	var gold_hi := Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.96) if Ui.SKIN == 1 else INK
	var dim := Color(Ui.TXT_DIM.r, Ui.TXT_DIM.g, Ui.TXT_DIM.b, 0.90) if Ui.SKIN == 1 else Color(INK.r, INK.g, INK.b, 0.55)
	var nm := _label(str(it.get("name", key)), 18, gold_hi)
	nm.position = Vector2(80, 10)
	nm.size = Vector2(182, 26)
	nm.clip_text = true
	card.add_child(nm)

	# 种类 + 现有数量合成一行（卡片只有 180 高，别再单开一行"现有 N"）
	var chip_txt := _kind_cn(it)
	if is_card:
		chip_txt += " · 补最缺"
	elif kd == "blood":
		chip_txt += " · 紫 90%"
	elif kd == "pill":
		chip_txt += " · 包裹 " + str(GameState.pill_count(str(it.get("pid", key)))) + " 颗"
	elif kd == "tool":
		chip_txt += " · 现有 " + str(GameState.appraise_tool_count(str(it.get("tid", "")))) + " 个"
	else:
		chip_txt += " · 现有 " + str(GameState.material_count(key))
	var chip := _label(chip_txt, 11,
		Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.90) if Ui.SKIN == 1 else Color(SEAL.r, SEAL.g, SEAL.b, 0.80))
	chip.position = Vector2(80, 36)
	chip.size = Vector2(182, 18)
	card.add_child(chip)

	# ⚠ 先设自动换行，再设 size——否则 Label 的最小宽度会按"整行不换行"算，撑到 224
	var desc := _label(str(it.get("desc", "")), 12, dim)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.position = Vector2(80, 62)
	desc.size = Vector2(182, 54)
	card.add_child(desc)

	var price_col := Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.95) if Ui.SKIN == 1 else Color(SEAL.r, SEAL.g, SEAL.b, 0.92)
	var price := _label("银两 " + str(price_val), 16, price_col)
	price.position = Vector2(14, 128)
	price.size = Vector2(160, 22)
	card.add_child(price)

	# 底行左二：限购（-1 不限购）
	var lim_txt := "不限购"
	var lim_col := dim
	if left == 0:
		lim_txt = "今日售罄"
		lim_col = Color(SEAL.r, SEAL.g, SEAL.b, 0.95)
	elif left > 0:
		lim_txt = "今日剩 " + str(left) + "/" + str(lim)
	var lim_lb := _label(lim_txt, 11, lim_col)
	lim_lb.position = Vector2(14, 152)
	lim_lb.size = Vector2(160, 18)
	card.add_child(lim_lb)

	# 购买钮：右下角
	var buy := Button.new()
	buy.text = "售罄" if sold else "购买"
	buy.position = Vector2(180, 124)
	buy.size = Vector2(82, 40)
	buy.add_theme_font_size_override("font_size", 15)
	buy.focus_mode = Control.FOCUS_NONE
	buy.disabled = sold
	# v61（手游）：购买钮在滚动区里——拖得动、点得准（原来一滑就误买）
	UiKit.tap_in_scroll(buy, _on_buy.bind(key))
	_style_seal(buy)
	card.add_child(buy)

# v212：卡片底（墨底 + 金角标 + 图标槽 + 底金线）；售罄盖一层暗
func _draw_card(c: Control, sold: bool) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	if Ui.SKIN == 1:
		Ui.panel(c, r, {"fill": Color(0.095, 0.082, 0.072, 0.97),
			"edge": Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.52 if not sold else 0.26),
			"cut": 9.0, "bracket": true, "shadow": 0.9 if not sold else 0.35, "ink_halo": false})
		var slot := Rect2(14.0, 14.0, 56.0, 56.0)
		var sp := Ui.cut_poly(slot, 6.0)
		c.draw_colored_polygon(sp, Color(0.025, 0.022, 0.020, 0.92))
		var sq := PackedVector2Array(sp)
		sq.append(sp[0])
		c.draw_polyline(sq, Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.30), 1.0, true)
		c.draw_line(Vector2(14.0, 124.0), Vector2(c.size.x - 14.0, 124.0),
			Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.16), 1.0, true)
		if sold:
			var ov := Ui.cut_poly(Rect2(Vector2(2.0, 2.0), c.size - Vector2(4.0, 4.0)), 9.0)
			c.draw_colored_polygon(ov, Color(0.02, 0.02, 0.02, 0.42))
	else:
		Ui.card(c, r, 8.0)
		c.draw_line(Vector2(14.0, 124.0), Vector2(c.size.x - 14.0, 124.0),
			Color(0.30, 0.25, 0.20, 0.18), 1.0, true)

func _kind_cn(it: Dictionary) -> String:
	match str(it.get("kind", "mat")):
		"card":
			return "残卡"
		"blood":
			return "血脉"
		"pill":
			return "突破丹"
		"tool":
			return "鉴宝道具"
		_:
			return "材料"

func _icon_for(it: Dictionary) -> Texture2D:
	var key := str(it.get("key", ""))
	if ICON_MAP.has(key):
		var t: Texture2D = ICON_MAP[key]
		return t
	if str(it.get("kind", "")) == "tool":
		return ICON_TOOL
	return null

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
