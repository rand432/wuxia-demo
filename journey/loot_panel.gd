extends Control
# ============================================================
## loot_panel.gd —— 搜刮面板 v8（放大批）
# v8（放大批）：玩家"仓库的字还是太小"——格外的说明字整体上调，格内小字按框宽给到顶：
#   · 格外（这是本次主要动的地方）：状态行 17→21 · 临时仓库签 17→21 · 底下说明 15→19 ·
#     搜刮格子里的种类签 14→18 · 件名 18→21 · 占格/价值行 13→14 ·
#     临时仓库"（空…）" 15→19 · "…还有 N 件" 14→19 ·
#     详情页：类别行 17→19 · 正文 15→19 · 三个钮 15/18→19 · 大标题 26 与"收好"22 本就在档内，不动。
#   · 格内小字（不许动格子尺寸，见 _chip_fs 的注释）：11→14（1 格框的非杂物）／12（2 格框）／
#     19（3 格以上框）；1 格框的杂物与"占格/价值"那行放不下，按规矩不动（10 / 13→14）。
#   · 纵向：面板 PANEL_RECT 仍 (10,316,700,604)。
#       状态行 184（h30→34）· 仓库签 220→222（h28→34）· 格子区 252→260 ·
#       说明 452→456（h46→58，19 号字排 2 行）· ［收好］508→522（56 高，底 578 ≤ 604）。
#       底下那排搜刮钮在舞台 y=958、底栏 y=1030，都没碰。
# v7：底部临时仓库改真格子区——12 列 × 3 行（格 50、缝 2），占几格就横跨几格，
#   框与字上品质色；排版走 data_loot.pack_cells（唯一真源）。超 3 行只画前 3 行 + 余量提示。
# v6（㉘）：杂物直显价值——搜刮格的角标、临时仓库签、详情行都带"值 N 银两"。
# v5：折现口径掰正——只有杂物能折现，折出＝其「值」多少银两（不再乘占格、不再给药材/丹药/
#   酒酿折现口）；杂物值＝银两；不折现的带出村，结算时自动贩卖（价一样）。
# v4：杂物也能折现（旧版杂物只能丢）。
# v3：①临时仓库改"点一件开详情"：查看 / 丢弃 / 折现——杂物类（药材/丹药/酒酿）
#   当场折现换银两（价表 CASH_BY_KIND 是初稿；红件另 ×3。改表即可）。
#   ②把上批的"窗口放大"一并含进本版：窗 700×604、格子 108、各标签字号上调。
# · 扫掠光带自左向右一轮：0.6s + 0.1s×容器格数（宠物 search_speed 提速）
# · 光带压到某件首格 → 该件翻牌（scale.x）——越稀有翻得越慢：
#     残页/残兵按品级 凡良 0.15 / 上 0.25 / 极 0.4 / 绝 0.6 秒；
#     其它红件 0.4 秒；普通小件 0.15 秒。
# · 全揭后 0.3 秒定格可拿；扫掠中点一下＝跳过全揭（警戒照记——防"跳过避警戒"）。
# · 拿取入 run_state.loot_bag（临时仓库，按格算；袋满拿不动、留在容器）。
# · 底部＝临时仓库查看口：点一件开详情（查看 / 丢弃 / 折现）。
# · 重开不重播：容器 anim_done 置位后直出。
# 本文件只做界面与调用；警戒/袋位/入账全在 run_state / game_state。
# ============================================================

signal closed

const Cards := preload("res://shared/data_cards.gd")
const Loot := preload("res://shared/data_loot.gd")
const GameState := preload("res://shared/game_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const Icons3 := preload("res://shared/item_art.gd")   # v93r：一件东西 → 一张图
const RunState := preload("res://shared/run_state.gd")

const PANEL_RECT := Rect2(10, 316, 700, 604)
const CELL := 108.0
const CGAP := 10.0
const BAND_W := 54.0
const SWEEP_BASE := 0.6
const SWEEP_PER_GAP := 0.1
const FLIP_BY_Q := [0.15, 0.15, 0.25, 0.4, 0.6]
const FLIP_RED := 0.4
const FLIP_PLAIN := 0.15
const SETTLE_AFTER := 0.3

# v5：折现只认杂物——折出＝e["value"]（单位：银两）；其余件只能丢弃或带出
# v8（放大批）：正文 15→19 之后这份详情页装不下原框，向上/向下各让一点：
#   原 (140,420,440,380) → (140,396,440,428)：底边 824 仍在屏内（屏高 1280），
#   里面 y 也全往下挪了——类别行 68→64、正文 104→100（高 150→236）、
#   按钮 312→350（高 54，底 404 ≤ 428）。
const POPUP_RECT := Rect2(140, 396, 440, 428)

# v7：临时仓库＝真格子区——占几格就横跨几格（排版走 Loot.pack_cells 唯一真源）
# ⚠ v59（用户："单格或者2格的字体容易超出 格子可以再大一点 临时仓库的也是
#   如果显示框就加大 临时仓库也是 也可以做成可滑动"；"临时仓库那个格子也大一点啊"）：
#   ① 格子 50 → 58 → **74**、列 12 → 10 → **8**（8×74 + 7×3 = 613 ≤ 可见宽 618）
#      —— 搜刮那头的件最宽就是 **6 格**（残功法/密柜出的），8 列放得下
#   ② 格内小字跟着抬：1 格 非杂物 14 → **18** / 杂物 10 → **12**、2 格 12 → **16**、
#      3 格以上 19 → **21**（真正兜底的是 `_refresh_bag_strip` 那三行"缩字号"循环）
#   ③ 外面套 **ScrollContainer**：装不下就上下滑，不再"…还有 N 件（先清一清）"
#      （背包升级到 40 格以上时，原来第 4 行往后**根本画不出来**）
# v60（用户："临时仓库的格子框也是要再大一点"）：
#   格子 74 → **86**、列 8 → **7**、缝 3 → **4**；滚动区 632×214 → **646×274**。
#   高度是"挪出来"的：［收好］从最底下一行（占 56 高）搬到提示行右边，
#   腾出的那一条全给格子区——3 行 86 的格子现在**整整齐齐全看得见**（3×86+2×4 = 266 ≤ 274），
#   不用一进来就滑。7 列仍装得下最宽的件（搜刮出来的最宽 6 格）。
#   ⚠ 宽度按"出现滚动条时"算：7×86 + 6×4 = 626 ≤ 646−14−4 = 628，
#     所以件多到要滑的时候，最右那列也不会被滚动条切掉。
const BAG_COLS := 7
const BAG_CELL := 86.0
const BAG_CGAP := 4.0
const BAG_ROWS := 3           # 至少画几行；件多了按实际行数长高，靠滚动看后面
const BAG_VIEW_W := 646.0     # 滚动区可见宽
const BAG_VIEW_H := 274.0     # v60：214 → 274（［收好］搬到提示行右边，腾出这一条）
const BAG_SBAR := 14.0        # 纵向滚动条占的宽（出现时内容要少算这么多）

var _stage = null
var _state = null
var _c: Dictionary = {}
var _speed_pct := 0.0
var _instant := false

var _row_x0 := 0.0
var _row_w := 0.0
var _band_x0 := 0.0
var _band_x1 := 0.0
var _band: Panel = null
var _tiles: Array = []
var _sweep_t := 0.0
var _sweep_len := 1.0
var _anim_end := 0.0
var _animating := false
var _can_take := false

var _status: Label = null
var _bag_title: Label = null
var _chips: Control = null
var _bag_scroll: ScrollContainer = null   # v59：临时仓库的滚动区（格子变大后装不下就滑）
var _detail_veil: Control = null
var _detail_idx := -1


func setup(stage, state, c: Dictionary, speed_pct := 0.0) -> void:
	_stage = stage
	_state = state
	_c = c
	_speed_pct = speed_pct
	_instant = bool(c.get("anim_done", false))
	_build()
	_refresh_bag_strip()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

# ---------- 构建 ----------

func _build() -> void:
	if _stage != null and _stage is Control and (_stage as Control).size.x > 8.0:
		size = (_stage as Control).size
	if size.x < 8.0 or size.y < 8.0:
		size = Vector2(720, 1280)
	var veil := UiKit.make_veil(self, size, 0.55)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(_on_blank_input)

	var panel := UiKit.make_paper_panel(self, PANEL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_blank_input)

	var cid := str(_c.get("cid", ""))
	var gaps := maxi(1, Loot.container_gap(cid))
	var items: Array = _c.get("items", [])
	var title := UiKit.make_label(panel, Vector2(0, 14), Vector2(700, 44), 30, UiKit.INK)
	UiKit.set_text(title, "搜刮 · " + Loot.container_name(cid) + " · " + str(gaps) + " 格")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_row_w = float(gaps) * CELL + float(maxi(gaps - 1, 0)) * CGAP
	_row_x0 = (700.0 - _row_w) * 0.5
	var row_y := 64.0
	_band_x0 = _row_x0 - BAND_W
	_band_x1 = _row_x0 + _row_w
	_sweep_len = (SWEEP_BASE + SWEEP_PER_GAP * float(gaps)) / maxf(0.1, 1.0 + _speed_pct / 100.0)

	for i in gaps:
		var slot := Panel.new()
		slot.position = Vector2(_row_x0 + float(i) * (CELL + CGAP), row_y)
		slot.size = Vector2(CELL, CELL)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.26)
		sb.border_color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.16)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		slot.add_theme_stylebox_override("panel", sb)
		panel.add_child(slot)

	_tiles.clear()
	var tx := _row_x0
	for e_v in items:
		var e: Dictionary = e_v
		var g := maxi(1, int(e.get("gap", 1)))
		var w := float(g) * CELL + float(maxi(g - 1, 0)) * CGAP
		var tile := _make_tile(e, w)
		tile.position = Vector2(tx, row_y)
		tile.pivot_offset = Vector2(w * 0.5, CELL * 0.5)
		tile.scale.x = 1.0 if _instant else 0.02
		var ti := _tiles.size()
		tile.gui_input.connect(_on_tile_input.bind(ti))
		panel.add_child(tile)
		var k := clampf((tx - _band_x0) / maxf(1.0, _row_w + BAND_W), 0.0, 1.0)
		_tiles.append({
			"tile": tile, "entry": e,
			"st": 0.15 + _sweep_len * k,
			"fd": _flip_dur(e),
			"noted": false, "done": _instant, "taken": false,
		})
		tx += w + CGAP

	_anim_end = 0.0
	for td_v in _tiles:
		var td: Dictionary = td_v
		var endt := float(td.get("st", 0.0)) + maxf(0.05, float(td.get("fd", FLIP_PLAIN)))
		if endt > _anim_end:
			_anim_end = endt

	_band = Panel.new()
	_band.size = Vector2(BAND_W, CELL + 12.0)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(1.0, 0.97, 0.86, 0.5)
	bs.set_corner_radius_all(8)
	_band.add_theme_stylebox_override("panel", bs)
	_band.position = Vector2(_band_x0, row_y - 6.0)
	_band.visible = not _instant and not _tiles.is_empty()
	panel.add_child(_band)

	# v8：17→21（说明行），框高 30→34（y=184 不动，底 218 离下一行 222 还有 4 像素）
	_status = UiKit.make_label(panel, Vector2(24, 184), Vector2(652, 34), 21, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# v8：17→21（临时仓库的"行标题"），y 220→222、框高 28→34（底 256，格子区 260 起，不压）
	_bag_title = UiKit.make_label(panel, Vector2(24, 222), Vector2(652, 34), 21, UiKit.SEAL)

	# v59：格子区外面套一层滚动区（只纵滑）——件多了往下滑，不再"画不出来"
	_bag_scroll = ScrollContainer.new()
	UiKit.drag_scroll(_bag_scroll)
	_bag_scroll.position = Vector2(34, 260)     # v8：252→260（给上面两行让出 8 像素）
	_bag_scroll.size = Vector2(BAG_VIEW_W, BAG_VIEW_H)
	_bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# v15x（用户："所有滑动不要滑动进度条 用指尖滑动那种就可以了"）：
	#   强制藏掉滚动条（Godot 默认主题在内容超出时会冒出来）——拖拽滚动不受影响。
	_bag_scroll.get_v_scroll_bar().visible = false
	_bag_scroll.get_h_scroll_bar().visible = false
	_bag_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# v15x（用户："所有滑动不要滑动进度条 用指尖滑动那种就可以了"）：
	#   强制藏掉滚动条（Godot 默认主题在内容超出时会冒出来）——拖拽滚动不受影响。
	_bag_scroll.get_v_scroll_bar().visible = false
	_bag_scroll.get_h_scroll_bar().visible = false
	_bag_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(_bag_scroll)
	_chips = Control.new()
	_chips.position = Vector2.ZERO          # 内容坐标：从滚动区左上角起算
	_chips.size = Vector2(BAG_VIEW_W, BAG_VIEW_H)
	_chips.custom_minimum_size = Vector2(BAG_VIEW_W, BAG_VIEW_H)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_scroll.add_child(_chips)

	# v60：提示行 + ［收好］并排（原来收好在最下面单独占一行 56 高，
	#   那一行整条让给临时仓库的格子区了）。提示 19 号两行 ≈ 52，框给 58。
	var hint := UiKit.make_label(panel, Vector2(24, 538), Vector2(470, 58), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.55))
	UiKit.set_text(hint, "拿的先进临时仓库——活着走完这一趟才作数；点仓库里的件：查看／丢弃／折现。")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var cb := UiKit.make_button(panel, Vector2(506, 538), Vector2(170, 58), "收好", 24)
	cb.pressed.connect(_close)

	if _instant:
		_can_take = true
		_set_status("点亮的物品点击即可拿取（袋满时留在容器里）")
	else:
		_animating = true
		_sweep_t = 0.0
		_set_status("扫掠中……点一下跳过")

func _make_tile(e: Dictionary, w: float) -> Panel:
	var p := Panel.new()
	p.size = Vector2(w, CELL)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var tier := Loot.tier_of(e)
	var tcol := _tier_col(tier)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.955, 0.925, 0.865, 1.0)
	sb.set_corner_radius_all(7)
	sb.set_border_width_all(2)
	if tier >= 1:
		sb.border_color = Color(tcol.r, tcol.g, tcol.b, 0.95)
	else:
		sb.border_color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.42)
	p.add_theme_stylebox_override("panel", sb)
	# v8（放大批）：种类签 14→18、件名 18→21；占格/价值那行只到 14——它一格宽只有 108，
	#   实测 18 号"1 格 · 值480银两"＝133 > 108（会压到旁边那格），14 号＝103 ≤ 108 才装得下，
	#   所以这行按玩家的规矩"格子里的字放不下就不放"，只挪 13→14（框也从 w-8 放到整格 w）。
	#   格子还是 108（CELL 不动，它是舞台那排搜刮钮的对齐基准），三行的框重排了一下：
	#     种类签 y 8→5（高 22→25，底 30）· 件名 y 32→29（高 52，底 81）· 占格/价值 y 88→82
	#     （高 20→25，底 107 ≤ 108）。件名加 max_lines_visible=2：长名（如血脉
	#     "赤炎血脉（上品·纯3）"）21 号下要 3 行，会压到下面那行——现在收尾打省略号，
	#     全名在点开的详情页里（26 号字）看得见。
	# v93r（用户："铺上 ItemIcons"）：这一格**顶上压一张道具图**，种类签缩到右边——
	#   原来整格只有三行字，翻一屏全是一样的排版，认东西全靠读字。
	var licon := TextureRect.new()
	licon.position = Vector2(6, 2)
	licon.size = Vector2(26, 26)
	licon.texture = _entry_icon(e)
	licon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	licon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	licon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(licon)
	var tag := UiKit.make_label(p, Vector2(32, 5), Vector2(w - 36, 25), 17, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.62))
	UiKit.set_text(tag, _kind_cn(e))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := UiKit.make_label(p, Vector2(4, 29), Vector2(w - 8, 52), 21, tcol if tier >= 1 else UiKit.INK)
	UiKit.set_text(nm, str(e.get("name", "?")))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gp := UiKit.make_label(p, Vector2(0, 82), Vector2(w, 25), 14, UiKit.DIM)
	var gp_txt := str(int(e.get("gap", 1))) + " 格"
	if str(e.get("kind", "")) == "junk":
		gp_txt += " · 值" + str(int(e.get("value", 1))) + "银两"
	UiKit.set_text(gp, gp_txt)
	gp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

# v93r：一件战利品 → 一张图（走全项目统一的口子；认不出就返回 null，只留字）
func _entry_icon(e: Dictionary) -> Texture2D:
	var sid := str(e.get("set", ""))
	if sid != "":
		var t := Icons3.icon_for_set(sid)
		if t != null:
			return t
	match str(e.get("kind", "")):
		"junk":
			return Icons3.icon("it_ingot")
		"mat":
			return Icons3.icon("it_herb")
		"pill":
			return Icons3.icon("it_jar")
	return Icons3.icon("it_scroll")

func _kind_cn(e: Dictionary) -> String:
	var k := str(e.get("kind", ""))
	var sid := str(e.get("id", ""))
	match k:
		"card":
			if Cards.is_arts(sid):
				return "功法残页"
			if Cards.is_buff(sid):
				return "增益残卡"
			if Cards.is_gear(sid):
				return "器具残片"
			return "兵器残兵"
		"item":
			return "完整功法" if Cards.is_arts(sid) else "完整武器"
		"pill":
			return "丹药"
		"mat":
			return "药材"
		"junk":
			return "杂物"
		"blood":
			return "血脉"
		"wine":
			return "酒酿"
		"silver":
			return "银两"
		"fragment":
			return "角色碎片"
		"yuanbao":
			return "元宝"
	return ""

# ㉟：五档色（0白/1绿/2紫/3金/4红）——档位口径见 data_loot.tier_of
func _tier_col(t: int) -> Color:
	match t:
		1:
			return Color(0.29, 0.47, 0.30)
		2:
			return Color(0.46, 0.30, 0.58)
		3:
			return Color(0.66, 0.50, 0.16)
		4:
			return Color(0.68, 0.15, 0.12)
	return Color(0.14, 0.13, 0.15)

func _flip_dur(e: Dictionary) -> float:
	if str(e.get("kind", "")) == "card":
		var q: int = Cards.q_idx(str(e.get("id", "")))
		return float(FLIP_BY_Q[clampi(q, 0, FLIP_BY_Q.size() - 1)])
	if bool(e.get("red", false)) or Loot.tier_of(e) >= 3:
		return FLIP_RED   # 金档也慢翻——养灵丹这类一眼看出贵重
	return FLIP_PLAIN

func _set_status(t: String) -> void:
	if _status != null:
		UiKit.set_text(_status, t)

# ---------- 动画与拿取 ----------

func _process(delta: float) -> void:
	if not _animating:
		return
	if _band != null and is_instance_valid(_band):
		var k := clampf((_sweep_t - 0.15) / maxf(0.01, _sweep_len), 0.0, 1.0)
		_band.position.x = lerpf(_band_x0, _band_x1, k)
	_sweep_t += delta
	for td_v in _tiles:
		var td: Dictionary = td_v
		if bool(td.get("done", false)):
			continue
		if _sweep_t < float(td.get("st", 0.0)):
			continue
		if not bool(td.get("noted", false)):
			td["noted"] = true
			_state.alert_gain(RunState.ALERT_REVEAL)
			_stage._refresh_alert()
			# v62s（用户："每显示一种物品，当前气血 -3%"）：**翻出来那一刻**就扣
			#   ——不是我上一版接的"取走那一刻" ✗。这一处是动画扫到的那一件。
			_fate_reveal_cost()
		var fdur := maxf(0.05, float(td.get("fd", FLIP_PLAIN)))
		var x := clampf((_sweep_t - float(td.get("st", 0.0))) / fdur, 0.0, 1.0)
		var tile: Panel = td.get("tile")
		if tile != null and is_instance_valid(tile):
			tile.scale.x = maxf(0.02, 1.0 - pow(1.0 - x, 3.0))
		if x >= 1.0:
			td["done"] = true
	if _sweep_t >= _anim_end + SETTLE_AFTER:
		_finish_anim()

func _finish_anim() -> void:
	_animating = false
	_can_take = true
	_c["anim_done"] = true
	if _band != null and is_instance_valid(_band):
		_band.visible = false
	_set_status("点亮的物品点击即可拿取（袋满时留在容器里）")

func _skip_anim() -> void:
	for td_v in _tiles:
		var td: Dictionary = td_v
		if not bool(td.get("noted", false)):
			td["noted"] = true
			_state.alert_gain(RunState.ALERT_REVEAL)
			_stage._refresh_alert()
			# v62s：跳过动画＝剩下的**一次性全显示**——那就一件一件都扣（同一口函数）
			_fate_reveal_cost()
		td["done"] = true
		var tile: Panel = td.get("tile")
		if tile != null and is_instance_valid(tile):
			tile.scale.x = 1.0
	_finish_anim()

func _on_blank_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _animating:
		_skip_anim()

func _on_tile_input(ev: InputEvent, ti: int) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	if _animating:
		_skip_anim()
		return
	if not _can_take:
		return
	_take(ti)

func _take(ti: int) -> void:
	if ti < 0 or ti >= _tiles.size():
		return
	var td: Dictionary = _tiles[ti]
	if bool(td.get("taken", false)):
		return
	var e: Dictionary = td.get("entry", {})
	if not _state.loot_take(e):
		UiKit.float_text(_stage, "临时仓库放不下了（余 " + str(_state.loot_gap_left()) + " 格）", UiKit.SEAL)
		return
	td["taken"] = true
	var arr: Array = _c.get("items", [])
	var ii := arr.find(e)
	if ii >= 0:
		arr.remove_at(ii)
	_state.alert_gain(RunState.ALERT_TAKE)
	_stage._refresh_alert()
	# v62s（用户："每显示一种物品，当前气血 -3%"）：取走**不再扣血**——
	#   代价搬到"翻出来那一刻"（_fate_reveal_cost，在 _process/_skip_anim 里调）。
	var tile: Panel = td.get("tile")
	if tile != null and is_instance_valid(tile):
		tile.modulate.a = 0.35
		if tile.get_child_count() > 1 and tile.get_child(1) is Label:
			UiKit.set_text(tile.get_child(1), "已拿")
	_refresh_bag_strip()
	UiKit.float_text(_stage, "已入临时仓库：" + str(e.get("name", "?")), UiKit.INK)
	# v24（阅历线·财富）：**搜刮时额外掉文钱**——取走一件就给几文（用户："搜刮给文钱"）
	var lm := int(GameState.insight_fx().get("loot_money", 0.0))
	if lm > 0:
		_state.money += lm
		UiKit.float_text(_stage, "顺手捡到 " + str(lm) + " 文", UiKit.GOLD, 168.0)
		var host = _stage
		if host != null and host.has_method("_money"):
			host._money()

# ============================================================
# v62s / v62t（用户："每显示一种物品，当前气血 -3%" → "-1.5%"）：翻财签的代价——
#   **每翻出来一件**扣一次（当前气血 -**1.5%** 上限算，不动上限·最低剩 1）。
#   触发点：物品"显示"的那一刻（动画扫到 / 跳过动画一次性全显示），不是取走时。
#   ⚠ 本面板没有 _has_fate，直接问 _state.buffs（别去调舞台的方法）
# ============================================================
func _fate_reveal_cost() -> void:
	if _state == null or not _state.buffs.has("fate_scavenge"):
		return
	var cut3: int = maxi(1, int(round(float(_state.hp_max) * 0.015)))
	_state.party_lose(cut3)
	UiKit.float_text(_stage, "翻找见血——全队当前气血 -" + str(cut3), UiKit.SEAL)

# ---------- 临时仓库（底部查看口） ----------

func _refresh_bag_strip() -> void:
	if _bag_title == null or _chips == null:
		return
	var tail := ""
	if not _state.loot_bag.is_empty():
		tail = "　·　点一件：查看 / 丢弃 / 折现"
	UiKit.set_text(_bag_title, "临时仓库 " + str(_state.loot_gap_used()) + "/" + str(_state.bag_cap()) + " 格" + tail)
	for ch in _chips.get_children():
		ch.queue_free()
	var bag: Array = _state.loot_bag
	# v59b 兜底：**列数至少要装得下最宽的那一件**。搜刮的容器只有 3~6 格，所以出来的件
	#   最宽 6 格 —— 8 列本来是够的；但万一以后哪条路塞进来一件 10 格的（完整功法），
	#   `Loot.pack_cells` 会**悄悄把它夹成 8 格**（它内部 `clampi(gap, 1, cols)`），
	#   画出来就是"少了两格还看不出来"。所以这里按实际最宽的件把列数顶上去，
	#   格子跟着缩一点（探针实测：真搜刮永远走不到这一支）。
	var cols := BAG_COLS
	for e_v in bag:
		cols = maxi(cols, int((e_v as Dictionary).get("gap", 1)))
	var content_w0 := BAG_VIEW_W - BAG_SBAR
	var cell := BAG_CELL
	if cols > BAG_COLS:
		cell = maxf(30.0, (content_w0 - float(cols - 1) * BAG_CGAP) / float(cols))
	# 8×74 + 7×3 = 613 ≤ 可见宽（有滚动条时按 618 算，居中对齐）
	var grid_w := float(cols) * cell + float(cols - 1) * BAG_CGAP
	var stride := cell + BAG_CGAP
	# 排版先算：**实际要几行**——内容高度按它长，装不下就滚（不再丢弃后面的件）
	var packed: Array = Loot.pack_cells(bag, cols)
	var rows := BAG_ROWS
	for pv0 in packed:
		rows = maxi(rows, int((pv0 as Dictionary).get("row", 0)) + 1)
	var content_h := maxf(BAG_VIEW_H, float(rows) * stride - BAG_CGAP + 2.0)
	_chips.custom_minimum_size = Vector2(BAG_VIEW_W, content_h)
	_chips.size = Vector2(BAG_VIEW_W, content_h)
	var content_w := BAG_VIEW_W - (BAG_SBAR if rows > BAG_ROWS else 0.0)
	var x0 := (content_w - grid_w) * 0.5
	# ① 先铺淡格底（cols 列 × 实际行数）——一眼看得出格子区有多大
	for r in rows:
		for c in cols:
			var slot := Panel.new()
			slot.position = Vector2(x0 + float(c) * stride, float(r) * stride)
			slot.size = Vector2(cell, cell)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ssb := StyleBoxFlat.new()
			ssb.bg_color = Color(1, 1, 1, 0.22)
			ssb.border_color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.16)
			ssb.set_border_width_all(1)
			ssb.set_corner_radius_all(4)
			slot.add_theme_stylebox_override("panel", ssb)
			_chips.add_child(slot)
	if bag.is_empty():
		# v8：15→19（这是格子区里的说明字，不是格内小字，跟着格外那档走）
		var e0 := UiKit.make_label(_chips, Vector2(0, 64), Vector2(content_w, 30), 19, UiKit.DIM)
		UiKit.set_text(e0, "（空——搜到的先放这，走完这一趟才作数）")
		e0.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	# ② 再摆件：占几格就横跨几格（排版只认 Loot.pack_cells，别在这儿另写一套）
	for pv in packed:
		var p: Dictionary = pv
		var prow := int(p.get("row", 0))
		var i := int(p.get("idx", 0))
		var ed: Dictionary = bag[i]
		var cw := maxi(1, int(p.get("w", 1)))
		var w := float(cw) * cell + float(maxi(cw - 1, 0)) * BAG_CGAP
		var pos := Vector2(x0 + float(int(p.get("col", 0))) * stride, float(prow) * stride)
		var junk := str(ed.get("kind", "")) == "junk"
		var fsz := _chip_fs(w, junk)
		var txt := _chip_text(ed, w, fsz)
		# v59：字必须装进框——估计高度超了就缩一号，最多缩 3 次（再不行 `_chip_text` 已经截过字）
		var box := Vector2(w - 4.0, cell - 4.0)
		for _try in 3:
			if _est_h(txt, box.x, fsz) <= box.y:
				break
			fsz = maxi(9, fsz - 1)
		var btn := UiKit.make_button(_chips, pos, Vector2(w, cell), txt, fsz)
		_style_chip(btn, Loot.tier_of(ed), cw >= 2)   # v56：占 2 格以上＝画成一整块（不透明底）
		btn.tooltip_text = _chip_tip(ed)
		UiKit.tap_in_scroll(btn, _on_chip_pressed.bind(i))   # v61：滚动区里的格子：拖得动、点得准
	# （v59：不再有"…还有 N 件"——件多了内容会长高，滚动区滑下去就能看见）

# 格内小字的字号规矩（v60 随格子放大重定）：按"这一格的框里装得下什么"定，**不是**按格子大小等比例缩。
#   口径：框内正文宽 = 框宽 − 4；量字用真字体（`_text_w`），够不够高用 `_est_h`。
#   · 1 格（86 宽，正文 82）：**杂物 14**（名字＋"值N银两"两行）、**非杂物 20**
#     （4 字名 80 ≤ 82 整名可见——v59 时 74 宽只能放 3 字）
#   · 2 格（176 宽，正文 172）：**20**（最长"燕子三抄水·卷首" 8 字 ≈160 ≤ 172）
#   · 3 格及以上（266 宽起）：**23**
#   还有一道兜底：`_refresh_bag_strip` 里"估高超过框就再缩一号"（最多三号），
#   所以这里宁可给大一点——**字大而截字**比**字小而截更多**好读。
func _chip_fs(w: float, is_junk: bool) -> int:
	if w >= 250.0:
		return 23
	if w >= 165.0:
		return 20
	return 14 if is_junk else 20

# 估一行字要多高（v59：改用真字体量，见 `_text_w`）
func _est_h(t: String, iw: float, fs: int) -> float:
	var f: Font = ThemeDB.fallback_font
	if f != null:
		return f.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, iw, fs).y
	var lines := 0
	for part in t.split("\n"):
		lines += maxi(1, int(ceil(_text_w(str(part), fs) / maxf(1.0, iw))))
	return float(lines) * float(fs) * 1.3

# 一件签的字：一行放得下＝名字 + 占格数；放不下就先保名字（占几格看框宽 + 悬停提示）
func _chip_text(e: Dictionary, w: float, fs: int) -> String:
	var nm := str(e.get("name", "?"))
	var g := maxi(1, int(e.get("gap", 1)))
	var budget := w - 6.0
	var head := nm + ("（" + str(g) + "格）" if g > 1 else "")
	if _text_w(head, fs) > budget:
		head = _fit_text(nm, fs, budget)
	if str(e.get("kind", "")) == "junk":
		return head + "\n" + _fit_text("值" + str(int(e.get("value", 1))) + "银两", fs, budget)
	return head

func _chip_tip(e: Dictionary) -> String:
	var t := str(e.get("name", "?")) + "　·　" + _kind_cn(e) + "　·　占 " + str(maxi(1, int(e.get("gap", 1)))) + " 格"
	if str(e.get("kind", "")) == "junk":
		t += "　·　值 " + str(int(e.get("value", 1))) + " 银两"
	return t

# 框与字都上品质色（tier 0＝淡墨，跟容器格子一个口径）
# v56（用户："搜刮和鉴宝的网格 多格的时候 不能合并吗 修复一下"）：
#   原来占 2 格以上的件也是**半透明**底（0.14），底下那几格的格线透出来，
#   看着像"几个小格上盖了一层色"而不是一整块。现在**占 2 格以上**改用**不透明**的纸色打底
#   （品质色按比例调进去），一块就把底下的格线整个盖住 → 一眼看得出它占了几格。
const CHIP_PAPER := Color(0.955, 0.925, 0.865, 1.0)

func _style_chip(btn: Button, tier: int, multi := false) -> void:
	var c := _tier_col(tier)
	var fill: Color
	var hov: Color
	var prs: Color
	if multi:
		fill = CHIP_PAPER.lerp(c, 0.18) if tier >= 1 else CHIP_PAPER
		hov = CHIP_PAPER.lerp(c, 0.32)
		prs = CHIP_PAPER.lerp(c, 0.46)
	else:
		fill = Color(c.r, c.g, c.b, 0.14) if tier >= 1 else Color(0.955, 0.925, 0.865, 0.92)
		hov = Color(c.r, c.g, c.b, 0.28)
		prs = Color(c.r, c.g, c.b, 0.40)
	var border := Color(c.r, c.g, c.b, 0.85) if tier >= 1 else Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.42)
	btn.add_theme_stylebox_override("normal", _chip_box(fill, border))
	btn.add_theme_stylebox_override("hover", _chip_box(hov, border))
	btn.add_theme_stylebox_override("pressed", _chip_box(prs, border))
	btn.add_theme_color_override("font_color", c)
	btn.add_theme_color_override("font_hover_color", c)
	btn.add_theme_color_override("font_pressed_color", c)

func _chip_box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 2.0
	sb.content_margin_right = 2.0
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	return sb

# 字宽：**用真字体量**（v59：原来是"全角＝字号、半角≈0.55"的估算，估窄了就会
#   "以为装得下、实际折成两行"——探针抓到过；真字体量一次几微秒，一屏几十个签无所谓）
func _text_w(t: String, fs: int) -> float:
	var f: Font = ThemeDB.fallback_font
	if f != null:
		return f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := 0.0
	for i in t.length():
		w += float(fs) * (0.55 if t.unicode_at(i) < 0x2E80 else 1.0)
	return w

func _fit_text(t: String, fs: int, w: float) -> String:
	# 原来先按估宽算 `avail`，估窄了会留下"再截一个字正好"的边角——现在逐字试真宽
	if _text_w(t, fs) <= w:
		return t
	var f: Font = ThemeDB.fallback_font
	var out := ""
	for i in t.length():
		var cand := out + t.substr(i, 1)
		var cw := (f.get_string_size(cand + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if f != null else _text_w(cand, fs) + _text_w("…", fs))
		if cw > w:
			break
		out = cand
	return out + "…"

func _on_chip_pressed(i: int) -> void:
	if i < 0 or i >= _state.loot_bag.size():
		return
	_open_chip_detail(i)


# ---- 临时仓库 · 详情（查看 / 丢弃 / 折现） ----

func _open_chip_detail(i: int) -> void:
	_close_chip_detail()
	if i < 0 or i >= _state.loot_bag.size():
		return
	_detail_idx = i
	var ed: Dictionary = _state.loot_bag[i]
	var veil := UiKit.make_veil(self, size, 0.25)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(_on_detail_blank)
	_detail_veil = veil
	var panel := UiKit.make_paper_panel(veil, POPUP_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var red := bool(ed.get("red", false))
	var dtier := Loot.tier_of(ed)
	var nm := UiKit.make_label(panel, Vector2(0, 18), Vector2(440, 40), 26, _tier_col(dtier) if dtier >= 1 else UiKit.INK)
	UiKit.set_text(nm, str(ed.get("name", "?")))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var cat := _kind_cn(ed)
	var sid := str(ed.get("id", ""))
	var kind := str(ed.get("kind", ""))
	if sid != "" and (kind == "card" or kind == "item"):
		var qn := str(Cards.quality_of(sid))
		if qn != "凡品":
			cat += "（" + qn + "）"
	if red:
		cat += " · 红件"
	elif dtier == 3:
		cat += " · 金档"
	elif dtier == 2:
		cat += " · 紫档"
	elif dtier == 1:
		cat += " · 绿档"
	# v8：大标题 26 不动（本就在档内）；下面三块全上调：
	#   类别行 17→19（y 68→64，框高 26→30）· 正文 15→19（y 104→100，框高 150→236）·
	#   按钮 312→350（15/18→19）。正文框 100~336 装得下最长的一份（血脉：9 行 ≈ 216）。
	var l1 := UiKit.make_label(panel, Vector2(30, 64), Vector2(380, 30), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	var l1_txt := "类别：" + cat + "　·　占 " + str(int(ed.get("gap", 1))) + " 格"
	if str(ed.get("kind", "")) == "junk":
		l1_txt += "　·　值 " + str(int(ed.get("value", 1))) + " 银两"
	UiKit.set_text(l1, l1_txt)

	var l2 := UiKit.make_label(panel, Vector2(30, 100), Vector2(380, 236), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
	var body := "先放临时仓库——活着走完这一趟才作数。\n杂物可［折现］：值多少就是多少银两，立刻入村账。\n不折现就带出村——结算时自动贩卖，价一样。"
	if str(ed.get("kind", "")) == "blood":
		body = "血脉：去［宠物］面板融合给宠物（每升 1 阶开 1 格）。\n契合血脉额外 ×1.5。\n\n" + body
	elif red:
		body = "红件——带出村才作数。\n丢掉就没了，别手滑。\n\n" + body
	UiKit.set_text(l2, body)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var cash := _cash_price(ed)
	var by := 350.0
	if cash > 0:
		# v8：三个钮的尺寸没动（130×54），只把字号 15/18→19。19 号下
		#   "折现 +1440 银两"在 130 宽的钮里放不下（探针实测 141 > 内框 110），
		#   按"字号优先"去掉尾巴"银两"（上面类别行就写着"值 1440 银两"）：
		#   "折现 +1440"＝98 ≤ 110，行情里的价都放得下。
		var db := UiKit.make_button(panel, Vector2(13, by), Vector2(130, 54), "丢弃", 19)
		db.pressed.connect(_chip_drop)
		var cb := UiKit.make_button(panel, Vector2(155, by), Vector2(130, 54), "折现 +" + str(cash), 19)
		cb.pressed.connect(_chip_cash)
		var xb := UiKit.make_button(panel, Vector2(297, by), Vector2(130, 54), "关闭", 19)
		xb.pressed.connect(_close_chip_detail)
	else:
		var db2 := UiKit.make_button(panel, Vector2(64, by), Vector2(150, 54), "丢弃", 19)
		db2.pressed.connect(_chip_drop)
		var xb2 := UiKit.make_button(panel, Vector2(226, by), Vector2(150, 54), "关闭", 19)
		xb2.pressed.connect(_close_chip_detail)

func _cash_price(e: Dictionary) -> int:
	# v5：只认杂物——值多少就是多少银两
	if str(e.get("kind", "")) == "junk":
		return maxi(1, int(e.get("value", 1)))
	return 0

func _chip_drop() -> void:
	var i := _detail_idx
	if i < 0 or i >= _state.loot_bag.size():
		_close_chip_detail()
		return
	var ed: Dictionary = _state.loot_bag[i]
	_state.loot_drop(i)
	_close_chip_detail()
	_refresh_bag_strip()
	UiKit.float_text(_stage, "丢掉了：" + str(ed.get("name", "?")), UiKit.SEAL)

func _chip_cash() -> void:
	var i := _detail_idx
	if i < 0 or i >= _state.loot_bag.size():
		_close_chip_detail()
		return
	var ed: Dictionary = _state.loot_bag[i]
	var n := _cash_price(ed)
	if n <= 0:
		return
	GameState.add_coin("silver", n)
	_state.loot_drop(i)
	_close_chip_detail()
	_refresh_bag_strip()
	UiKit.float_text(_stage, "折现 +" + str(n) + " 银两：" + str(ed.get("name", "?")), UiKit.GOLD)

func _on_detail_blank(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_close_chip_detail()

func _close_chip_detail() -> void:
	if _detail_veil != null and is_instance_valid(_detail_veil):
		_detail_veil.queue_free()
	_detail_veil = null
	_detail_idx = -1

# ---------- 关 ----------

func _close() -> void:
	if _animating:
		_skip_anim()
	_close_chip_detail()
	closed.emit()
	queue_free()
