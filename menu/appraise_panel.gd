extends Control
# ============================================================
# appraise_panel.gd —— 鉴宝行 v2（v50 重做版面）
#
# 用户这一版的设计（原话拆开）：
#   · 第一页就是**各种货仓**：一只一个**横框**（左头一只**会动的货仓**），
#     只写**名字与价格**——"也不写多少格"。点它 → 弹出窗口。
#   · 弹窗：**居中就是空白**（这只仓的格子区，没鉴定的地方就是空格），
#     下面三个键：［用道具］［买下 N 两］［退出］。用道具才"显现一些"。
#   · 买下之后"**就跟搜刮的动画一样，一格一格地显示出来**"。
#   · 道具（货栈「鉴宝」页卖，每日限购 · 效果越强越贵）：
#       描影镜 → 最值钱那一件的轮廓   透物灯 → 随机 2~3 件轮廓   识宝鉴 → 一件全知
#       **数格尺 → 这只仓一共几格**（较贵；店里不写格数，所以这是第一道信息）
#       **碧砂/紫霞/金纹/朱砂筛 → 把该成色的货全部标成轮廓**
#   · 格子区：一件货**占几格就横跨几格**（`Loot.pack_cells`），
#     没鉴定＝暗格；**轮廓＝那几格的边框用品质色**（看得出成色与大小，但不知道名字）。
#
# 规矩全在 shared/data_appraise.gd（HOLDS / TOOLS）＋ GameState.appraise_* 那一节；
#   这一页只管**画与演**，一个数值都不在这里定。
# ⚠ 后续联机：一只货仓＝一条独立数据（GameState.appraise_offers 里那一条），
#   要同步/分享就搬那一条；面板只负责把它画出来。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const Appraise := preload("res://shared/data_appraise.gd")
const Loot := preload("res://shared/data_loot.gd")
const Ladder := preload("res://shared/data_ladder.gd")   # v58：掉落阶梯（列数规则与抽货共用一个口）
const UiKit := preload("res://shared/ui_kit.gd")
const SceneArt := preload("res://shared/scene_art.gd")   # v77：内景垫图

signal closed

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const GOLD := Color(0.72, 0.52, 0.14)
const GREEN := Color(0.28, 0.50, 0.30)

const PANEL_W := 660.0
const PANEL_H := 980.0
const ROW_Y0 := 210.0
const ROW_STEP := 178.0
const ROW_H := 160.0

# 五档色（0 白 / 1 绿 / 2 紫 / 3 金 / 4 红）——与搜刮面板同一色系
const TIER_COL := [
	Color(0.30, 0.29, 0.30),
	Color(0.29, 0.47, 0.30),
	Color(0.46, 0.30, 0.58),
	Color(0.66, 0.50, 0.16),
	Color(0.72, 0.20, 0.16),
]
const TIER_CN := ["白", "绿", "紫", "金", "红"]

# 弹窗（货仓）版面
# ⚠ v59（用户："上下滑动不就好了"）：**只留上下滑，不许横滑**。
#   这样一来"格子"就只能按**面板宽度**定死：完整功法占 **10 格**，所以大仓必须 10 列，
#   10 列的盘宽 = 一格 × 10 + 9 道缝 —— 格子想再大就只能横着滑出去。按用户的话：
#   宁可不横滑（格子 61.6 像素），也不要"格子 79.2 但要左右拖"。
#   字号**不跟着格子缩**（那才是"看不清"的根）：固定在 15 像素上下，见 `_cell_chip`。
const POP_W := 712.0          # 660 → 700 → **712**：把两边那点空白也让给格子（屏幕宽 720）
const POP_H := 940.0
# v62：这个价以上的货仓，买之前先给一句提示（见 _open_big_ask）
const BIG_HOLD_PRICE := 8000
const POP_GRID_Y := 172.0
const GRID_COLS := 6          # 小仓（< 20 格）用 6 列；大仓 10 列（见 _use_grid）
const CELL := 92.0            # 6 列时的一格边长（大仓按面板宽度现算）
const CGAP := 2.0             # 缝 8 → 6 → **2**：省下的 36 像素全给格子（跟临时仓库一个观感）
const SBAR_W := 12.0          # **给纵向滚动条留的宽**——不留的话盘会比可见区宽，又冒出横滑条
const GRID_VIEW_PAD := 4.0

# v56（用户："货仓的价格也可以决定里面的格子数"）：**格子区随仓大小自适应**——
#   便宜仓 8 格（6 列 × 2 行就够）、龙纹舱 40 格（6 列要 7 行，放不下）。
#   规矩：格数 ≥ 26 的换成 **8 列**，一格边长按面板宽度现算（8 列时约 68 像素）；
#   下面这两个变量在每次 _open_hold() 里按这只仓的格数重算。
var _cols := GRID_COLS
var _cell := CELL
var _grid_rows := 1          # 这次画出来几行（开仓光带按行扫）
var _grid_w := 0.0           # 格子区总宽（光带扫到头用）

# v56（用户："货仓购买后加一个类似搜刮的那个等待动画 让人有点期待感，
#   同时显示完成点击是可以查看效果的"）——**开仓动画**：跟搜刮开箱一个路子。
#   · 开演前先静 REV_LEAD 秒（"等一等"的期待感）
#   · 一件一件来：光带**挪到某一件 → 停在那儿 → 那件才慢慢翻出来**
#   · 越贵重爬得越慢（用户 v58："白的就快一点 绿的比白的慢一点 红的就很慢很慢"）
#   · 爬条的途中点一下＝**跳过**；爬完后点一下＝**看结果**
#
# v58（用户："货仓的搜索时长太快了点 没有那种期待的感觉 就是那种慢慢的 跟搜刮一样
#   不同品质不同的等待时间 然后一件一件的呈现的感觉"）：
#   **从"匀速扫行"改成"按件停留"**——原来是"每行固定 0.28 秒扫过去"，一趟 8 格小仓
#   只要 1.36 秒，白货红货一样快。现在**每一件的停留时长按它的档位给**（见下表），
#   红件停 2.8 秒、翻牌自己占 1.8 秒——就是那种"慢慢揭开"的感觉。
const REV_LEAD := 0.35        # 开演前静一下（那口"期待"的气）
const REV_GAP := 0.10         # 两件之间的小停顿（前一条爬满了、下一条才开始爬）
const REV_BAND_W := 60.0      # （v56 金带的宽度；进度条版已不用，留着免得别处引用报错）
const REV_TAIL := 0.45        # 全翻完再定一下格才喊"开完了"
# 每一档"停多久"（含翻牌时间）——白 / 绿 / 紫 / 金 / 红
const REV_HOLD := [0.45, 0.75, 1.20, 1.80, 2.80]
# 每一档"翻牌用多久"（不超过该档的 hold）
const REV_FLIP := [0.30, 0.45, 0.70, 1.10, 1.80]
# 整场动画的上限：件多了（龙纹舱 30 件）不能真按"每件 0.2+2.8 秒"演——那要一分半。
#   超过就**整体等比压缩**（各档之间的快慢比例保留），见 _start_open_anim 里的 k。
#   ⚠ 这是**软上限**：每件还有个 REV_MIN_STEP 的下限（不然压缩后会闪成 0.02 秒一帧、
#     看着像抽搐），所以件特别多时总长会略微超出——超出量 ≤ 件数 × REV_MIN_STEP。
#     实测：13 件 → 8.3 秒（正好卡在上限）、30 件 → 8.6 秒（超 0.3 秒，可接受）。
const REV_TOTAL_CAP := 8.5
const REV_MIN_STEP := 0.18    # 压缩到极限也别低于这个（不然看着像卡了一帧）
# v58（用户："慢不要紧 给个一键加速的按钮"）：**加速键**——开了之后整条时间线乘这个系数。
#   本局记住（静态，跟战斗那边"手动/自动"一个做法），下一只仓不用再点。
const REV_FAST := 6.0
static var last_fast := false

var _panel: Panel
var _rows: Array = []
var _msg_lb: Label
var _stat_lb: Label
var _busy := false

# 弹窗态
var _pop: Panel = null
var _pop_uid := -1
var _pop_cells: Control = null
var _pop_scroll: ScrollContainer = null   # v59：格子区的滚动区（格子放大 1.5 倍后装不下就滑）
var _pop_slide_hint: Label = null         # v59：滑得动的时候才写一句"可以滑动"
var _grid_vp := Vector2.ZERO              # v59：滚动区的可见尺寸
var _pop_title: Label = null
var _pop_info: Label = null
var _pop_msg: Label = null
var _pop_buy: Button = null
# v56：道具窗（点［用道具］弹出来的那一页）——原来只是一条挤在底下的小按钮带
#   （8 个 146×28、13 号字），用户："鉴宝的道具按钮太小了 大一点 并且点击后显示效果
#   再给个返回和确定的显示窗口"。现在是**一整页窗**：列表 → 确认 → 结果，三步都在这页里。
var _tool_win: Panel = null
var _tool_page := ""            # list＝挑道具 / confirm＝确认 / result＝效果
var _tool_pick := ""            # 选中哪件道具
var _tool_lines: Array = []     # 结果页要写的几行
var _flash: Dictionary = {}     # 刚照出来的那几件（下标 → true）：格子上描一圈金边
var _flash_t := 0.0
var _pop_busy := false
# v50：弹窗里那只仓的**快照**（买下之后那只仓就从报价单里撤了，
#   可"一格一格显示出来"那场戏还得照着它演——所以开弹窗时先抄一份）
var _pop_data: Dictionary = {}

# 开仓动画态（见 REV_* 常量）
var _rev_on := false          # 正在演
var _rev_ready := false       # 演完了，等玩家点一下看结果
var _rev_t := 0.0
var _rev_end := 0.0
var _rev_band: Panel = null
var _rev_fast_btn: Button = null
var _rev_rows := 1
var _rev_loot: Array = []     # 这一次开出来的东西（结果页用）
var _rev_price := 0           # 这一次花的钱（结果页算净赚）
var _rev_msg := ""            # 买下时账房回的那句话（结果页第一行）
var _ask_veil: Control = null # v62：贵仓购买提示的那层罩子
var _chips_last: Array = []   # 这一盘摆出来的件（{chip, e, row}）——翻牌照它演
var _loot_lines: Array = []   # 结果页要写的几行（{t, f, c}）

var _t := 0.0

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	refresh()
	visible = get_parent() == get_tree().root

func _process(d: float) -> void:
	# 货仓图上那点"活着"的动效：轻轻起伏 + 一线反光扫过（纯画，不占资源）
	if not visible:
		return
	_t += d
	for r_v in _rows:
		var art = (r_v as Dictionary).get("art", null)
		if art != null and is_instance_valid(art):
			art.bob_t = _t
	# v56：道具刚照出来的那几件，金边亮一会儿就收（1.6 秒）
	if _flash_t > 0.0 and not _rev_on:
		_flash_t -= d
		if _flash_t <= 0.0:
			_flash.clear()
			_refresh_hold()
	# v56：开仓动画（光带扫行 + 一件件翻牌），见 _start_open_anim
	if _rev_on:
		_rev_step(d)
	queue_redraw()

# ══════════════════════════════════════════════════════════
# 自绘货仓（这一页的"美术"：没有贴图，全用 draw_* 画）
#   一只木箱：板条 + 铁箍 + 一把锁；bob_t 让它轻轻起伏，glint 扫一道反光
#   tier 换配色（打捞上来的那只偏暗），open_t 用来演"开箱"（盖往后翻）
# ══════════════════════════════════════════════════════════
class HoldArt extends Control:
	var tier := 0
	var bob_t := 0.0
	var open_t := 0.0     # 0 关 / 1 全开（购买后翻盖）
	var glint := 0.0      # 反光位置 0~1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func wood_col() -> Color:
		var cols: Array = [
			Color(0.52, 0.40, 0.28), Color(0.50, 0.38, 0.26),
			Color(0.58, 0.42, 0.24), Color(0.62, 0.46, 0.22), Color(0.60, 0.38, 0.26)]
		return cols[clampi(tier, 0, cols.size() - 1)]

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 2.0 or h <= 2.0:
			return
		var bob := sin(bob_t * 1.8) * 3.0
		var base := Color(0.34, 0.26, 0.20)
		var wc := wood_col()
		var bw := w * 0.74
		var bh := h * 0.56
		var x0 := (w - bw) * 0.5
		var y0 := h * 0.30 + bob
		# 影子
		draw_rect(Rect2(x0 + 6.0, y0 + bh + 6.0, bw - 12.0, 6.0), Color(0, 0, 0, 0.18), true)
		# 箱体
		draw_rect(Rect2(x0, y0, bw, bh), wc, true)
		draw_rect(Rect2(x0, y0, bw, bh), base, false, 2.0)
		# 板条
		for i in 3:
			var ly := y0 + bh * (0.28 + 0.24 * float(i))
			draw_line(Vector2(x0 + 3.0, ly), Vector2(x0 + bw - 3.0, ly), Color(base.r, base.g, base.b, 0.55), 1.0)
		# 铁箍（两条竖着的）
		for k in 2:
			var lx := x0 + bw * (0.24 + 0.52 * float(k))
			draw_line(Vector2(lx, y0), Vector2(lx, y0 + bh), Color(0.30, 0.30, 0.34), 3.0)
		# 盖：购买时往后翻（open_t 0→1）
		var lid_h := h * 0.20
		var lid_y := y0 - lid_h * (1.0 - open_t)
		var lid := Rect2(x0, lid_y, bw, lid_h)
		draw_rect(lid, wc.lightened(0.10), true)
		draw_rect(lid, base, false, 2.0)
		# 锁
		if open_t < 0.5:
			var lw := bw * 0.14
			draw_rect(Rect2(x0 + bw * 0.5 - lw * 0.5, y0 + bh * 0.30, lw, bh * 0.26), Color(0.72, 0.62, 0.30), true)
			draw_rect(Rect2(x0 + bw * 0.5 - lw * 0.5, y0 + bh * 0.30, lw, bh * 0.26), base, false, 1.0)
		# 反光扫过（一眼看出"这箱子是活的"）
		var gx := x0 + bw * fmod(glint, 1.0)
		draw_line(Vector2(gx, y0 + 2.0), Vector2(gx - 10.0, y0 + bh - 2.0), Color(1, 1, 1, 0.16), 4.0)

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
	# v77：垫一张货仓内景（鉴宝行就在仓里翻货）
	UiKit.add_room_bg(_panel, SceneArt.store_room(), 0.34)

	var title := _label("鉴 宝 行", 30, INK)
	title.position = Vector2(28, 14)
	title.size = Vector2(240, 44)
	_panel.add_child(title)

	var sub := _label("船上捞上来的货仓，一仓一个价。看中了就点开——先用道具照一照，再决定买不买。", 13, Color(INK.r, INK.g, INK.b, 0.62))
	sub.position = Vector2(30, 54)
	sub.size = Vector2(PANEL_W - 60.0, 22)
	_panel.add_child(sub)

	_stat_lb = _label("", 13, Color(INK.r, INK.g, INK.b, 0.62))
	_stat_lb.position = Vector2(30, 84)
	_stat_lb.size = Vector2(PANEL_W - 60.0, 22)
	_panel.add_child(_stat_lb)

	var tip := _label("（店里只写名字与价钱——**几格**得自己量；道具在货栈「鉴宝」页买，每日限购）".replace("**", ""), 13,
		Color(INK.r, INK.g, INK.b, 0.45))   # v61（手游）：12 → 13 号
	tip.position = Vector2(30, 108)
	tip.size = Vector2(PANEL_W - 60.0, 24)
	_panel.add_child(tip)

	var sep := ColorRect.new()
	sep.color = Color(INK.r, INK.g, INK.b, 0.22)
	sep.position = Vector2(28, 140)
	sep.size = Vector2(PANEL_W - 56.0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sep)

	# ── 三只货仓：一只一个横框（左头会动的货仓 ＋ 名字 ＋ 价钱）──
	_rows = []
	for i in Appraise.OFFER_N:
		var y := ROW_Y0 + float(i) * ROW_STEP
		var row := Panel.new()
		row.position = Vector2(28, y)
		row.size = Vector2(PANEL_W - 56.0, ROW_H)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(1, 1, 1, 0.40)
		rsb.set_corner_radius_all(12)
		rsb.border_color = Color(INK.r, INK.g, INK.b, 0.24)
		rsb.set_border_width_all(1)
		row.add_theme_stylebox_override("panel", rsb)
		_panel.add_child(row)
		var art := HoldArt.new()
		art.position = Vector2(14, 12)
		art.size = Vector2(120, 136)
		row.add_child(art)
		var rn := _label("", 22, INK)
		rn.position = Vector2(150, 26)
		rn.size = Vector2(300, 30)
		row.add_child(rn)
		var rd := _label("", 13, Color(INK.r, INK.g, INK.b, 0.55))   # v61（手游）：12 → 13 号
		rd.position = Vector2(150, 62)
		rd.size = Vector2(330, 40)
		rd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(rd)
		var price := _label("", 22, SEAL)
		price.position = Vector2(PANEL_W - 56.0 - 210.0, 30)
		price.size = Vector2(190, 30)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(price)
		var go := _label("点开看仓 ▸", 13, Color(INK.r, INK.g, INK.b, 0.45))
		go.position = Vector2(PANEL_W - 56.0 - 210.0, 66)
		go.size = Vector2(190, 20)
		go.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(go)
		# 整行可点（用户："然后点击货仓 弹出窗口"）
		row.gui_input.connect(_on_row_input.bind(i))
		_rows.append({"row": row, "name": rn, "desc": rd, "price": price, "art": art, "uid": -1})

	_msg_lb = _label("", 13, Color(SEAL.r, SEAL.g, SEAL.b, 0.94))
	_msg_lb.position = Vector2(28, 806)
	_msg_lb.size = Vector2(PANEL_W - 56.0, 56)
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_msg_lb)

	var close_btn := Button.new()
	close_btn.text = "关　闭"
	close_btn.position = Vector2(230, PANEL_H - 74.0)
	close_btn.size = Vector2(200, 50)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	_style_dark(close_btn)
	_panel.add_child(close_btn)

# ══════════════════════════════════════════════════════════
func refresh() -> void:
	if _panel == null:
		return
	GameState.appraise_ensure_offers()
	_stat_lb.text = ("银两 " + str(GameState.coin("silver")) + "　｜　已开 " + str(GameState.appraise_opened)
		+ " 只　｜　单件最高估价 " + str(GameState.appraise_best) + " 两　｜　" + GameState.appraise_tool_line())
	var offers: Array = GameState.appraise_offers
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var rp: Panel = row["row"]
		if i >= offers.size():
			rp.visible = false
			continue
		rp.visible = true
		var o: Dictionary = offers[i]
		var uid := int(o.get("uid", -1))
		row["uid"] = uid
		var hid := str(o.get("hid", ""))
		var d: Dictionary = Appraise.hold_def(hid)
		var free := bool(o.get("free", false))
		var price := 0 if free else Appraise.hold_price_now(hid)
		(row["name"] as Label).text = Appraise.hold_name(hid) + ("　（打捞上来的那只）" if free else "")
		# ⚠ 这里**不写格数**（用户定的）——只留一句味道话
		(row["desc"] as Label).text = str(d.get("desc", ""))
		var pl: Label = row["price"]
		pl.text = "不收钱" if free else str(price) + " 两"
		pl.add_theme_color_override("font_color", GREEN if (free or GameState.coin("silver") >= price) else SEAL)
		# 那只货仓的配色随档位，反光相位错开（三只不会同步闪）
		var art = row["art"]
		art.tier = clampi(Appraise.HOLDS.find(d), 0, 4)
		art.glint = fmod(_t * 0.35 + float(i) * 0.31, 1.0)

# ---- 打开某只货仓的弹窗 ----
func _on_row_input(ev: InputEvent, i: int) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_open_hold(i)

func _open_hold(i: int) -> void:
	if i < 0 or i >= GameState.appraise_offers.size():
		return
	_close_hold()
	var src: Dictionary = GameState.appraise_offers[i]
	_pop_uid = int(src.get("uid", -1))
	# 开仓动画态归零（上一只仓的演完了没有，跟这一只没关系）
	_rev_on = false
	_rev_ready = false
	_rev_t = 0.0
	_rev_end = 0.0
	_rev_band = null
	_rev_loot = []
	_rev_price = 0
	_rev_msg = ""
	_loot_lines = []
	_chips_last = []
	# 快照（买下之后这只仓就从报价单撤了，那场"逐格揭示"还得照它演）
	_pop_data = {
		"hid": str(src.get("hid", "")),
		"cells": maxi(4, int(src.get("cells", 8))),
		"items": (src.get("items", []) as Array).duplicate(true),
		"free": bool(src.get("free", false)),
		"reveal_all": false,
	}
	var vp := get_viewport_rect().size
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.35)
	veil.size = vp
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(_on_pop_blank)
	add_child(veil)
	_pop = Panel.new()
	_pop.position = Vector2((vp.x - POP_W) * 0.5, (vp.y - POP_H) * 0.5)
	_pop.size = Vector2(POP_W, POP_H)
	_pop.mouse_filter = Control.MOUSE_FILTER_STOP
	_pop.gui_input.connect(_on_pop_blank)   # 扫完点面板空白处＝看结果；扫的途中＝跳过
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.99)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	psb.set_border_width_all(2)
	_pop.add_theme_stylebox_override("panel", psb)
	veil.add_child(_pop)

	_pop_title = _label("", 26, INK)
	_pop_title.position = Vector2(26, 16)
	_pop_title.size = Vector2(POP_W - 52.0, 34)
	_pop.add_child(_pop_title)
	_pop_info = _label("", 15, Color(INK.r, INK.g, INK.b, 0.62))
	_pop_info.position = Vector2(26, 54)
	_pop_info.size = Vector2(POP_W - 52.0, 20)
	_pop.add_child(_pop_info)

	# ── 居中：格子区（没鉴定的地方就是空格）──
	#   v56：按这只仓的格数决定列数与格边（大仓 10 列、格小）
	#   ⚠ v59：外面套一层 **ScrollContainer**（用户："上下滑动不就好了"）——
	#     **只开纵滑，横滑关掉**（`SCROLL_MODE_DISABLED`），一格按面板宽度铺满，
	#     于是"列多行多"就往下滚，永远不会左右拖。
	#     `mouse_filter = PASS` 是关键：滚轮归它（滑），空白处一点的点击**照样往上传**
	#     给 `_pop`（＝跳过动画 / 看结果），而格子里的"件"仍是 PASS + 左键自己收下（点开详情）。
	_use_grid(maxi(4, int(src.get("cells", 8))))
	_grid_vp = Vector2(POP_W - GRID_VIEW_PAD * 2.0, (POP_H - 196.0) - 10.0 - POP_GRID_Y)
	_pop_scroll = ScrollContainer.new()
	UiKit.drag_scroll(_pop_scroll)
	_pop_scroll.position = Vector2(GRID_VIEW_PAD, POP_GRID_Y)
	_pop_scroll.size = _grid_vp
	_pop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_pop_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_pop.add_child(_pop_scroll)
	_pop_cells = Control.new()
	_pop_cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop_scroll.add_child(_pop_cells)
	# 滑得动的时候才提示（滑不动就别占地方）——放在格子区**正上方**（信息行与盘之间那条空）
	_pop_slide_hint = _label("", 14, Color(INK.r, INK.g, INK.b, 0.55))
	_pop_slide_hint.position = Vector2(GRID_VIEW_PAD, POP_GRID_Y - 22.0)
	_pop_slide_hint.size = Vector2(POP_W - GRID_VIEW_PAD * 2.0, 20)
	_pop_slide_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pop.add_child(_pop_slide_hint)
	_pop_msg = _label("", 15, Color(SEAL.r, SEAL.g, SEAL.b, 0.94))
	_pop_msg.position = Vector2(26, POP_H - 196.0)
	_pop_msg.size = Vector2(POP_W - 52.0, 60)
	_pop_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pop.add_child(_pop_msg)

	# ── 三个键：用道具 / 买下 / 退出（用户："下面就是 道具使用 和购买 和退出"）──
	# ⚠ v59：面板从 660 放宽到 700，这一排跟着重新居中（62/250/488，右边留白 62 对称）
	var use_btn := UiKit.make_button(_pop, Vector2(62, POP_H - 60.0), Vector2(170, 48), "用道具", 18)
	use_btn.pressed.connect(_open_tool_win)
	_pop_buy = UiKit.make_button(_pop, Vector2(250, POP_H - 60.0), Vector2(220, 48), "买下", 19)
	_pop_buy.pressed.connect(_on_buy)
	# v58（用户：慢不要紧 给个一键加速的按钮）：**加速键**——开了之后整条时间线 ÷ 系数。
	#   演到一半点也立刻生效（剩下的按新速度走），本局记住。
	_rev_fast_btn = UiKit.make_button(_pop, Vector2(62, POP_H - 116.0), Vector2(230, 44),
		("加速 ×" + str(int(REV_FAST)) + "：开" if last_fast else "加速 ×" + str(int(REV_FAST)) + "：关"), 16)
	_rev_fast_btn.pressed.connect(_on_fast_toggle)
	var quit := UiKit.make_button(_pop, Vector2(488, POP_H - 60.0), Vector2(150, 48), "退出", 18)
	quit.pressed.connect(_close_hold)

	_refresh_hold()
	print("[鉴宝行] 打开货仓 uid=", _pop_uid)

# ══════════════════════════════════════════════════════════
# v56：**道具窗**（用户："鉴宝的道具按钮太小了 大一点 并且点击后显示效果
#   再给个返回和确定的显示窗口"）
#   三步都在这一页里：
#     ① 列表：八件道具一行一件，大字写"名字 ×数量"＋一句话效果（原来是 8 个 13 号小钮）
#     ② 确认：点一件 → 写清"这件是干什么的、现有几个"，［确定］［返回］
#     ③ 结果：用掉之后写出**照到了什么**（每件一行：类别 · 几档 · 占几格 · 在第几行第几格），
#        同时格子区把刚照出来的那几件**描一圈金边**亮 1.6 秒
# ══════════════════════════════════════════════════════════
func _open_tool_win() -> void:
	if _pop_busy or _pop == null:
		return
	if _rev_ready:
		return          # 这只仓已经买下开完了——没什么可鉴定的了（那个键此刻是［看结果］）
	_close_tool_win()
	_tool_page = "list"
	_tool_pick = ""
	_tool_lines = []
	_make_tool_win()
	_fill_tool_win()

# v56：开仓结果页（跟道具窗同一块面板，换一页内容）
func _open_loot_win() -> void:
	if _pop == null:
		return
	_close_tool_win()
	_tool_page = "loot"
	_tool_pick = ""
	_fill_loot_lines()
	_make_tool_win()
	_fill_tool_win()

func _make_tool_win() -> void:
	_tool_win = Panel.new()
	_tool_win.position = Vector2(30, 60)
	_tool_win.size = Vector2(POP_W - 60.0, POP_H - 200.0)
	_tool_win.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.995)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	sb.set_border_width_all(2)
	_tool_win.add_theme_stylebox_override("panel", sb)
	_pop.add_child(_tool_win)

func _close_tool_win() -> void:
	if _tool_win != null and is_instance_valid(_tool_win):
		_tool_win.queue_free()
	_tool_win = null
	_tool_page = ""
	_tool_pick = ""

func _fill_tool_win() -> void:
	if _tool_win == null or not is_instance_valid(_tool_win):
		return
	for c in _tool_win.get_children():
		_tool_win.remove_child(c)
		c.queue_free()
	var w := _tool_win.size.x
	var h := _tool_win.size.y
	var hid := str(_pop_data.get("hid", ""))
	if _tool_page == "list":
		var t1 := _label("用道具　·　" + Appraise.hold_name(hid), 26, INK)
		t1.position = Vector2(0, 18)
		t1.size = Vector2(w, 36)
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tool_win.add_child(t1)
		var t2 := _label("每用一次少一个——用完去货栈「鉴宝」页买（每日限购）", 17, Color(INK.r, INK.g, INK.b, 0.62))
		t2.position = Vector2(0, 58)
		t2.size = Vector2(w, 26)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tool_win.add_child(t2)
		var y := 100.0
		for k in Appraise.TOOL_ORDER.size():
			var tid := str(Appraise.TOOL_ORDER[k])
			var td: Dictionary = Appraise.tool_def(tid)
			var n := GameState.appraise_tool_count(tid)
			var txt := Appraise.tool_name(tid) + "　×" + str(n) + "\n" + str(td.get("desc", ""))
			var btn := UiKit.make_button(_tool_win, Vector2(30, y), Vector2(w - 60.0, 62), txt, 19)
			btn.disabled = n <= 0
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.pressed.connect(_tool_pick_one.bind(tid))
			if str(td.get("kind", "")) == "tier":
				btn.add_theme_color_override("font_color", TIER_COL[clampi(int(td.get("tier", 0)), 0, TIER_COL.size() - 1)])
			y += 68.0
		var back := UiKit.make_button(_tool_win, Vector2((w - 200.0) * 0.5, h - 76.0), Vector2(200, 56), "返回", 22)
		back.pressed.connect(_close_tool_win)
	elif _tool_page == "confirm":
		var td2: Dictionary = Appraise.tool_def(_tool_pick)
		var n2 := GameState.appraise_tool_count(_tool_pick)
		var t3 := _label(Appraise.tool_name(_tool_pick) + "　×" + str(n2), 28, INK)
		t3.position = Vector2(0, 30)
		t3.size = Vector2(w, 40)
		t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tool_win.add_child(t3)
		var body := _label(str(td2.get("desc", "")) + "\n\n现有 " + str(n2) + " 个　·　用掉一个。\n\n用在这只货仓上？", 21, Color(INK.r, INK.g, INK.b, 0.92))
		body.position = Vector2(40, 96)
		body.size = Vector2(w - 80.0, h - 260.0)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tool_win.add_child(body)
		var ok := UiKit.make_button(_tool_win, Vector2(w * 0.5 - 210.0, h - 96.0), Vector2(200, 60), "确定", 22)
		ok.disabled = n2 <= 0
		ok.pressed.connect(_tool_confirm)
		var back2 := UiKit.make_button(_tool_win, Vector2(w * 0.5 + 10.0, h - 96.0), Vector2(200, 60), "返回", 22)
		back2.pressed.connect(_tool_pick_back)
	elif _tool_page == "item":
		# v58：点格子看这件的详情（用户："货仓的物品点击可以查看到底是什么品质"）。
		#   与"开仓结果页"同一套滚动列表，只是内容换成一件事的明细。
		var t6 := _label("这　一　件", 28, INK)
		t6.position = Vector2(0, 22)
		t6.size = Vector2(w, 40)
		t6.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tool_win.add_child(t6)
		var sc6 = ScrollContainer.new()
		UiKit.drag_scroll(sc6)
		sc6.position = Vector2(26, 78)
		sc6.size = Vector2(w - 52.0, h - 192.0)
		sc6.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_tool_win.add_child(sc6)
		var box6 := VBoxContainer.new()
		box6.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box6.add_theme_constant_override("separation", 10)
		sc6.add_child(box6)
		for ld_v in _loot_lines:
			var ld: Dictionary = ld_v
			var lb3 := _label(str(ld.get("t", "")), int(ld.get("f", 19)), ld.get("c", INK))
			lb3.custom_minimum_size = Vector2(w - 84.0, 0)
			lb3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box6.add_child(lb3)
		var kb3 := UiKit.make_button(_tool_win, Vector2((w - 220.0) * 0.5, h - 96.0), Vector2(220, 60), "知道了", 22)
		kb3.pressed.connect(_close_tool_win)
	elif _tool_page == "loot":
		# v56：开仓结果页——把**这一次开出来的每一件**都列出来（类别/名字/档/几格/估价），
		#   底下再算一笔总账（合计估价 vs 本钱）。件多的时候用滚动条（龙纹舱能开 30 件）。
		var t5 := _label("开　仓　所　得", 28, INK)
		t5.position = Vector2(0, 22)
		t5.size = Vector2(w, 40)
		t5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tool_win.add_child(t5)
		var sc = ScrollContainer.new()
		UiKit.drag_scroll(sc)
		sc.position = Vector2(26, 76)
		sc.size = Vector2(w - 52.0, h - 190.0)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_tool_win.add_child(sc)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		sc.add_child(box)
		for ld_v in _loot_lines:
			var ld: Dictionary = ld_v
			var lb2 := _label(str(ld.get("t", "")), int(ld.get("f", 19)), ld.get("c", INK))
			lb2.custom_minimum_size = Vector2(w - 84.0, 0)
			lb2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(lb2)
		var kb2 := UiKit.make_button(_tool_win, Vector2((w - 220.0) * 0.5, h - 96.0), Vector2(220, 60), "知道了", 22)
		kb2.pressed.connect(_close_tool_win)
	else:
		var t4 := _label(Appraise.tool_name(_tool_pick), 28, INK)
		t4.position = Vector2(0, 26)
		t4.size = Vector2(w, 40)
		t4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tool_win.add_child(t4)
		var body2 := _label("\n".join(PackedStringArray(_tool_lines)), 20, Color(INK.r, INK.g, INK.b, 0.92))
		body2.position = Vector2(36, 86)
		body2.size = Vector2(w - 72.0, h - 240.0)
		body2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tool_win.add_child(body2)
		var kb := UiKit.make_button(_tool_win, Vector2((w - 220.0) * 0.5, h - 96.0), Vector2(220, 60), "知道了", 22)
		kb.pressed.connect(_close_tool_win)

func _tool_pick_one(tid: String) -> void:
	_tool_pick = tid
	_tool_page = "confirm"
	_fill_tool_win()

func _tool_pick_back() -> void:
	_tool_page = "list"
	_tool_pick = ""
	_fill_tool_win()

# 确定：真的用掉，然后把"照到了什么"写出来 + 把新照出来的那几件描金边
func _tool_confirm() -> void:
	if _pop_busy or _pop_uid < 0 or _tool_pick == "":
		return
	var before: Dictionary = (GameState.appraise_offer(_pop_uid).get("seen", {}) as Dictionary).duplicate()
	var r: Dictionary = GameState.appraise_use(_pop_uid, _tool_pick)
	var o: Dictionary = GameState.appraise_offer(_pop_uid)
	var after: Dictionary = o.get("seen", {})
	var items: Array = o.get("items", [])
	var plan: Array = Loot.pack_cells(items, _cols)
	_tool_lines = []
	var msg := str(r.get("msg", ""))
	if msg != "":
		_tool_lines.append(msg)
	var fresh: Array = []
	for k in after.keys():
		if before.has(str(k)):
			continue
		var idx := int(k)
		fresh.append(idx)
		var st := str(after[k])
		var e: Dictionary = items[idx] if idx >= 0 and idx < items.size() else {}
		var cell_txt := ""
		for p_v in plan:
			var p: Dictionary = p_v
			if int(p.get("idx", -1)) == idx:
				cell_txt = "（第 " + str(int(p.get("row", 0)) + 1) + " 行第 " + str(int(p.get("col", 0)) + 1) + " 格）"
				break
		if st == "full":
			_tool_lines.append("· 【" + Loot.entry_kind_cn(e) + "】" + str(e.get("name", "?"))
				+ "　" + TIER_CN[clampi(Loot.tier_of(e), 0, TIER_CN.size() - 1)] + "档 · "
				+ str(int(e.get("gap", 1))) + " 格　约 " + str(Loot.entry_value(e)) + " 两　" + cell_txt)
		else:
			_tool_lines.append("· 轮廓：" + Loot.entry_kind_cn(e) + "　"
				+ TIER_CN[clampi(Loot.tier_of(e), 0, TIER_CN.size() - 1)] + "档 · "
				+ str(int(e.get("gap", 1))) + " 格　" + cell_txt)
	if fresh.is_empty():
		_tool_lines.append("（这一件没照出新的东西——可能这一档在仓里本来就没有）")
	if bool(r.get("ok", false)):
		GameState.save_game()
	_flash.clear()
	for i in fresh:
		_flash[str(i)] = true
	_flash_t = 1.6
	_tool_page = "result"
	_fill_tool_win()
	_refresh_hold()

# ══════════════════════════════════════════════════════════
# 画格子区：一件货占几格就横跨几格。
#   · **没鉴定的一律不画**（用户："居中就是空白，然后使用道具就显现一些"）
#   · 轮廓＝那几格的**边框用品质色**；全知＝名字＋估价
#   · 买下之后（快照里的 reveal_all）全部亮出来，并按 reveal_upto 一件件演
# ══════════════════════════════════════════════════════════
# v56：按"这只仓有多少格"定格子区几何——
#   ≥ 20 格：10 列（完整功法占 10 格，列数不能少于它）
#   ⚠ v59：一格的边长 = **把面板宽度正好铺满**（再扣掉纵向滚动条那 14 像素）——
#     只纵滑、不横滑（用户："上下滑动不就好了"）；字号不跟着格子缩，见 `_cell_chip`
func _use_grid(cells: int) -> void:
	# ⚠ v59 修：列数**由掉落阶梯那一条规则说了算**（`Ladder.grid_cols`）——
	#   抽货时是"一边抽一边往真格子里摆"，画的时候必须用**同一把尺子**，
	#   否则 24 格的木箱会出现"账上有、盘上摆不下"的货（完整功法 10 格要 10 列）。
	#   原来这里是 `8 if cells >= 26 else 6`：24 格的木箱只给 6 列，
	#   抽货那边却按 10 列摆 → 那件货在盘上永远画不出来。
	_cols = Ladder.grid_cols(cells)
	# 一格 = **把面板宽度正好铺满**（再减去纵向滚动条要占的那 14 像素）——
	#   这样永远不会出现横向滚动条（用户："上下滑动不就好了"）。
	var avail := POP_W - GRID_VIEW_PAD * 2.0 - SBAR_W
	_cell = (avail - float(_cols - 1) * CGAP) / float(_cols)

func _refresh_hold(reveal_upto := -1) -> void:
	if _pop_cells == null:
		return
	var o: Dictionary = GameState.appraise_offer(_pop_uid)
	var snap := _pop_data
	if o.is_empty() and snap.is_empty():
		_close_hold()
		return
	var reveal_all := bool(snap.get("reveal_all", false))
	var items: Array = (snap.get("items", []) if reveal_all else o.get("items", []))
	var seen: Dictionary = o.get("seen", {})
	var cells := maxi(4, int(snap.get("cells", o.get("cells", 8))))
	_use_grid(cells)
	var known := bool(o.get("cells_known", false)) or reveal_all
	for c in _pop_cells.get_children():
		_pop_cells.remove_child(c)   # ⚠ 先摘下来再 free：queue_free 要等这一帧末尾，
		c.queue_free()               #   只调它会让新旧两批同屏一帧（看得见闪一下）
	# 底格：没量过格数就先只铺 4 格（"这只仓至少这么大"），量过/买下后铺满
	var draw_cells := cells if known else 4
	_use_grid(cells)
	# ⚠ v59 修：**排版要先算**——`Loot.pack_cells` 是"一行一行横着摆、摆不下就换行"，
	#   所以它用掉的行数**可能比 `ceil(格数/列数)` 多**（最后一行只剩 4 格、下一件要 6 格时，
	#   那 4 格就废了，整件挪到下一行）。原来格子区的尺寸按 ceil 算，于是那些件
	#   会落在滚动内容**外面**——ScrollContainer 会把它裁掉，玩家根本滑不到（探针抓到：
	#   银扣 7 件、金匮 6 件）。现在尺寸取"底格行数"与"实际摆出来的行数"的**大者**。
	var plan: Array = Loot.pack_cells(items, _cols)
	var rows_cells := int(ceil(float(draw_cells) / float(_cols)))
	var rows_plan := 0
	for pv0 in plan:
		rows_plan = maxi(rows_plan, int((pv0 as Dictionary).get("row", 0)) + 1)
	var rows := maxi(maxi(rows_cells, rows_plan), 1)
	_grid_rows = rows
	_grid_w = float(_cols) * _cell + float(_cols - 1) * CGAP
	var grid_h := float(rows) * _cell + float(rows - 1) * CGAP
	# 滚动内容：把整盘的真实尺寸交给 ScrollContainer（它按 custom_minimum_size 决定滑不滑）
	_pop_cells.custom_minimum_size = Vector2(_grid_w, grid_h)
	_pop_cells.size = Vector2(_grid_w, grid_h)
	# ⚠ v59：小仓（3 行）只占 254 像素，而那块地方留了 562 —— 不处理就是"上面一盘、下面一大片空"。
	#   所以**能装下就把滚动区收到跟盘一样高、并且居中**；装不下才用满整块（那时才纵滑）。
	#   （横滑已关，所以这里不用再给横滚动条留高度。）
	var snug := minf(_grid_vp.y, grid_h)
	_pop_scroll.position.y = POP_GRID_Y + (_grid_vp.y - snug) * 0.5
	_pop_scroll.size.y = snug
	if _pop_slide_hint != null:
		_pop_slide_hint.text = ("↑ ↓ 上下滑（滚轮 / 拖滚动条都行）" if grid_h > _grid_vp.y + 1.0
			else "")
	for r in rows:
		for c2 in _cols:
			if r * _cols + c2 >= draw_cells:
				continue
			var cell := Panel.new()
			cell.position = Vector2(float(c2) * (_cell + CGAP), float(r) * (_cell + CGAP))
			cell.size = Vector2(_cell, _cell)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 1, 1, 0.22)
			sb.border_color = Color(INK.r, INK.g, INK.b, 0.16)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(6)
			cell.add_theme_stylebox_override("panel", sb)
			_pop_cells.add_child(cell)
	# 一件件摆（占几格横跨几格；只摆"看得出的"）——`plan` 在上面已经算好了
	var shown := 0
	_chips_last = []      # v56：记下这一次画出来的件（开仓动画按这个顺序一件件翻）
	for p_v in plan:
		var p: Dictionary = p_v
		var i := int(p["idx"])
		if reveal_upto >= 0 and i > reveal_upto:
			break
		var st := "full" if reveal_all else str(seen.get(str(i), ""))
		if st == "":
			continue          # 未知：不画（留着空白）
		var e: Dictionary = items[i]
		var w := float(int(p["w"])) * _cell + float(int(p["w"]) - 1) * CGAP
		var chip := _cell_chip(e, st, w, _flash.has(str(i)))
		chip.position = Vector2(float(int(p["col"])) * (_cell + CGAP), float(int(p["row"])) * (_cell + CGAP))
		chip.size = Vector2(w, _cell)
		# v58（用户："货仓的物品点击可以查看到底是什么品质"）：格子**可以点**——
		#   点一下弹出这件的详情（类别/品质几档/占几格/在第几行第几格，
		#   全知的再给名字与估价）。原来这里是 IGNORE，点不动。
		# ⚠ v59：改成 **PASS + 左键 accept_event()**——左键仍归"件"（点开详情），
		#   而**滚轮/拖动能穿过去给外面的滚动区**（STOP 会把它们一起吃掉，格子盘就滑不动了）。
		# v61b：整块交给 tap_in_scroll（swallow=true 保持"左键自己收下"那条规矩），
		#   并且**拖动不再算点**——滑列表时不会再把货点开。
		UiKit.tap_in_scroll(chip, _chip_act.bind(i), true)
		_pop_cells.add_child(chip)
		_chips_last.append({"chip": chip, "e": e, "row": int(p.get("row", 0))})
		shown += 1
	# 抬头信息（⚠ 不报"一共几件"——那是没花钱的情报）
	var hid := str(snap.get("hid", o.get("hid", "")))
	var free := bool(snap.get("free", o.get("free", false)))
	var price := 0 if free else Appraise.hold_price_now(hid)
	_pop_title.text = Appraise.hold_name(hid) + ("　（打捞上来的那只）" if free else "")
	if reveal_all:
		_pop_info.text = "已买下：共 " + str(items.size()) + " 件　·　格数 " + str(cells)
	else:
		_pop_info.text = ("格数 " + (str(cells) if known else "未知（用数格尺量）")
			+ "　·　已看出 " + str(shown) + " 件")
	if _pop_buy != null:
		_pop_buy.text = ("买下（不收钱）" if free else "买下 " + str(price) + " 两")
		_pop_buy.disabled = reveal_all or ((not free) and GameState.coin("silver") < price)
	# 已经开完仓了：这个键的活儿变成"看结果"（别被这次重画改回"买下"）
	if _rev_ready and _pop_buy != null:
		_pop_buy.text = "看结果（" + str(_rev_loot.size()) + " 件）"
		_pop_buy.disabled = false

# ---- 格内小字：装不装得进框（与游历·临时仓库同一套口径）----
#   ⚠ v59：**改成用真字体量**（`ThemeDB.fallback_font`）——原来那套"全角＝1 字号、
#     半角≈0.55 字号"是估的，估窄了就会"以为装得下、实际折成两行"（探针抓到过）。
#     真字体量一次只要几微秒，一屏三十个件签完全无所谓。
func _text_w(t: String, fs: int) -> float:
	var f: Font = ThemeDB.fallback_font
	if f != null:
		return f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := 0.0
	for i in t.length():
		w += float(fs) * (0.55 if t.unicode_at(i) < 0x2E80 else 1.0)
	return w

# 这段字按框宽折行之后**要占多高**
func _est_h(t: String, iw: float, fs: int) -> float:
	var f: Font = ThemeDB.fallback_font
	if f != null:
		return f.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, iw, fs).y
	var lines := 0
	for part in t.split("\n"):
		lines += maxi(1, int(ceil(_text_w(str(part), fs) / maxf(1.0, iw))))
	return float(lines) * float(fs) * 1.3

# 一行放不下就截到放得下（末尾加"…"）
func _fit_text(t: String, fs: int, w: float) -> String:
	var f: Font = ThemeDB.fallback_font
	if _text_w(t, fs) <= w:
		return t
	var ell := _text_w("…", fs)
	var out := ""
	for i in t.length():
		var ch := t.substr(i, 1)
		var cand := out + ch
		var cw := (f.get_string_size(cand + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if f != null else _text_w(cand, fs) + ell)
		if cw > w:
			break
		out = cand
	return out + "…"

func _seen_count(seen: Dictionary) -> int:
	var n := 0
	for k in seen.keys():
		if str(seen[k]) == "outline" or str(seen[k]) == "full":
			n += 1
	return n

# 一格（可能横跨几格）：未知 / 轮廓 / 全知
# v56（用户："搜刮和鉴宝的网格 多格的时候 不能合并吗 修复一下"）：
#   原来底色是**半透明**的（0.22 / 0.10），底下那一格格的边框会从它下面透出来——
#   一件占 3 格的货看着像"三个小格上盖了一层色"，不像一整块。
#   现在**占 2 格以上**改成**不透明**的纸色打底（再把品质色按比例调进去），
#   一格块就把底下的格线整个盖住 → 一眼看得出它占了几格。
func _cell_chip(e: Dictionary, st: String, w: float, flash := false) -> Panel:
	var chip := Panel.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	var tier := Loot.tier_of(e)
	var tc: Color = TIER_COL[clampi(tier, 0, TIER_COL.size() - 1)]
	var multi := w > _cell + 1.0       # 占 2 格以上：要画成一整块
	var base := Color(PAPER.r, PAPER.g, PAPER.b, 1.0)
	var txt := ""
	var fcol := INK
	# ⚠ v59（用户："单格或者2格的字体容易超出"）：**一格的小框不硬塞长句**——
	#   全知只写名字（类别看边框色、要细节点开）、轮廓只写成色几格。
	var narrow := w < _cell * 1.6
	if st == "full":
		sb.bg_color = base.lerp(tc, 0.22) if multi else Color(tc.r, tc.g, tc.b, 0.22)
		sb.border_color = Color(tc.r, tc.g, tc.b, 0.85)
		var val := str(Loot.entry_value(e))
		txt = (str(e.get("name", "?")) if narrow else
			("【" + Loot.entry_kind_cn(e) + "】" + str(e.get("name", "?")) + "\n约 " + val + " 两"))
	elif st == "outline":
		# v50（用户："轮廓就是那几格的边框上品质的颜色"）——**边框用品质色**，
		#   字只写"类别 · 几格"，不给名字：看得出成色与大小，看不出是什么
		sb.bg_color = base.lerp(tc, 0.14) if multi else Color(tc.r, tc.g, tc.b, 0.10)
		sb.border_color = Color(tc.r, tc.g, tc.b, 0.80)
		var tcn: String = str(TIER_CN[clampi(tier, 0, TIER_CN.size() - 1)])
		var gp := str(int(e.get("gap", 1)))
		txt = ((tcn + "档" + gp + "格") if narrow else
			(Loot.entry_kind_cn(e) + "　" + tcn + "档 · " + gp + " 格"))
	else:
		sb.bg_color = base.lerp(INK, 0.10) if multi else Color(INK.r, INK.g, INK.b, 0.12)
		sb.border_color = Color(INK.r, INK.g, INK.b, 0.22)
		txt = "？"
		fcol = Color(INK.r, INK.g, INK.b, 0.45)
	# ⚠ v59：**字必须真装进框里**。原来字号是一个固定公式（`_cell×0.26`）+ 在 Label 上
	#   设了 `clip_text`——可 Label 的**最小宽**会把框顶大，品质底色却只画在框里，
	#   于是"字块撑出色块"就是玩家看到的"超出"。现在：
	#   ① **一格的小框**统一 15 号（大小一致才不跳），放不下就截字加"…"；
	#   ② 宽框：字号从 18 往下试，取第一个"折行后 ≤ 框高"的；再不行才截字。
	var iw := w - 12.0
	var ih := _cell - 12.0
	var fsz := 15
	if not narrow:
		fsz = 18
		while fsz > 11 and _est_h(txt, iw, fsz) > ih:
			fsz -= 1
	var parts: Array = txt.split("\n")
	var cut: Array = []
	for pv in parts:
		cut.append(_fit_text(str(pv), fsz, iw))
	txt = "\n".join(PackedStringArray(cut))
	# v56：刚用道具照出来的那几件——加粗描一圈金边，看得见"刚才那一下照到了哪儿"
	if flash:
		sb.set_border_width_all(3)
		sb.border_color = Color(0.86, 0.68, 0.24, 0.98)
	chip.add_theme_stylebox_override("panel", sb)
	var lb := _label(txt, fsz, fcol)
	lb.position = Vector2(6, 6)
	lb.size = Vector2(w - 12.0, _cell - 12.0)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.clip_text = true
	chip.add_child(lb)
	return chip

# ---- 用药 ----
# v56：原来这里是"点一下就用掉"（没有确认、也看不到照出了什么）——
#   现在统一走道具窗的三步（列表 → 确认 → 结果），见 _open_tool_win / _tool_confirm。
#   这个口留着：想不弹窗直接用的地方（以后的联机/脚本）还能调。

# ---- 买下：开仓动画（光带扫行 + 一件件翻出来），演完点一下看结果 ----
# v56（用户："货仓购买后加一个类似搜刮的那个等待动画 让人有点期待感，
#   同时显示完成点击是可以查看效果的"）
#   原来是 `for i in items.size(): _refresh_hold(i); await 0.16` —— 每 0.16 秒把
#   整盘格子拆了重摆一次（闪、也没"翻"的感觉）。现在：
#     ① 一次把整盘摆好（每件先**藏起来**，等它的进度条爬满才显形）
#     ② 金带按行从左扫到右，扫到哪件哪件才翻（越贵重翻得越慢）
#     ③ 途中点一下＝跳过；扫完 → ［看结果］亮起来，点面板空白/点这个键都开结果页
# v62：贵仓的"买之前先问一句"——一个只读的小弹窗，确认了才走原来的购买流程。
#   文案就用户给的那一句，不加别的。
func _big_ask_text() -> String:
	return "你的游历越高，越容易出更高品质的武学与武器装备。\n\n确定要现在购买吗？"

func _open_big_ask(price: int) -> void:
	_close_big_ask()
	var vp := get_viewport_rect().size
	var veil := UiKit.make_veil(self, vp, 0.45)
	_ask_veil = veil
	var w := 560.0
	var h := 300.0
	var box := UiKit.make_paper_panel(veil, Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h))
	var head := _label("这只仓 " + str(price) + " 两", 24, INK)
	head.position = Vector2(24, 20)
	head.size = Vector2(w - 48.0, 34)
	box.add_child(head)
	var body := _label(_big_ask_text(), 17, Color(INK.r, INK.g, INK.b, 0.82))
	body.position = Vector2(24, 64)
	body.size = Vector2(w - 48.0, 96)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	var ok := UiKit.make_button(box, Vector2(24, h - 78.0), Vector2(240, 56), "买下", 20)
	ok.pressed.connect(func() -> void: _close_big_ask(); _on_buy())
	var no := UiKit.make_button(box, Vector2(w - 264.0, h - 78.0), Vector2(240, 56), "再想想", 20)
	no.pressed.connect(_close_big_ask)

func _close_big_ask() -> void:
	if _ask_veil != null and is_instance_valid(_ask_veil):
		_ask_veil.queue_free()
	_ask_veil = null

func _on_buy() -> void:
	if _pop_busy and not _rev_ready:
		return
	if _rev_ready:
		_open_loot_win()      # 已经开完了：这个键现在是［看结果］
		return
	var o: Dictionary = GameState.appraise_offer(_pop_uid)
	if o.is_empty():
		return
	var free := bool(o.get("free", false))
	var hid := str(o.get("hid", ""))
	var price := 0 if free else Appraise.hold_price_now(hid)
	if (not free) and GameState.coin("silver") < price:
		_pop_msg.text = "银两不够：要 " + str(price) + " 两（现有 " + str(GameState.coin("silver")) + "）"
		return
	# v62（用户："货仓8000以上的货仓 购买给个提示 你的游历越高更容易出更高品质的武学和武器装备
	#   确定要现在购买吗？（不加别的 就给个提示）"）：
	#   8000 两以上的仓（铜锁 12500 / 银扣 18000 / 金匮 23500）先问一句——
	#   因为**仓里的货色是跟着"游历难度"走的**（Ladder.roll_hold 的 base_q ← q_of_diff），
	#   现在把大钱砸下去，等游历推高了再开同一只仓，出好东西的概率更高。
	#   只加这一句提示，不改价、不改爆率、不加别的门槛。
	if (not free) and price >= BIG_HOLD_PRICE and _ask_veil == null:
		_open_big_ask(price)
		return
	var r: Dictionary = GameState.appraise_buy(_pop_uid)
	if not bool(r.get("ok", false)):
		_pop_msg.text = str(r.get("msg", ""))
		return
	# 账已经落好了（appraise_buy 里就落了）——这里只负责**演**。
	#   ⚠ 那只仓买下后就从报价单撤了，所以照**开弹窗时抄的那份快照**演。
	var items: Array = (r.get("items", []) as Array).duplicate(true)
	_pop_data["items"] = items
	_pop_data["reveal_all"] = true
	_close_tool_win()
	_rev_loot = items
	_rev_price = price
	_rev_msg = str(r.get("msg", ""))
	_start_open_anim()
	refresh()                 # 钱已经扣了，报价单跟着变

func _start_open_anim() -> void:
	_flash.clear()
	_flash_t = 0.0
	_pop_busy = true
	_rev_ready = false
	_rev_on = true
	_rev_t = 0.0
	_rev_band = null
	_refresh_hold()                       # 整盘一次摆好（件都在 _chips_last 里）
	_rev_rows = maxi(1, _grid_rows)
	# ============================================================
	# v58（用户："就是那种进度条的感觉 进度条满了 就显示 没满就加载"）：
	#   **每件一条进度条**——没满就一直"加载中"（空格子上只有一条在爬的条 + 百分比），
	#   条爬满了那件才**显形**（一个小弹跳）。
	#   · 一件接一件地爬（从左到右、从上到下）——"一件一件的呈现"
	#   · 每件爬多久**按品质给**（REV_HOLD：白 0.45 → 红 2.80 秒）——
	#     "白的就快一点 绿的比白的慢一点 红的就很慢很慢"
	#   ⚠ 上一版做的是"金带扫过 + 卡片翻面"，用户说"不对"——已换成进度条。
	# ============================================================
	var order: Array = []
	for v in _chips_last:
		var td0: Dictionary = v
		var ch: Panel = td0.get("chip")
		if ch == null or not is_instance_valid(ch):
			continue
		order.append({"td": td0, "row": int(td0.get("row", 0)), "x": ch.position.x})
	order.sort_custom(func(a, b):
		if int(a["row"]) != int(b["row"]):
			return int(a["row"]) < int(b["row"])
		return float(a["x"]) < float(b["x"]))
	var raw := 0.0
	for o_v in order:
		var td1: Dictionary = (o_v as Dictionary)["td"]
		var ti1 := clampi(Loot.tier_of(td1.get("e", {})), 0, REV_HOLD.size() - 1)
		raw += REV_GAP + float(REV_HOLD[ti1])
	var k := 1.0
	if raw > REV_TOTAL_CAP and raw > 0.0:
		k = REV_TOTAL_CAP / raw
	var t := REV_LEAD
	for o2_v in order:
		var o2: Dictionary = o2_v
		var td: Dictionary = o2["td"]
		var chip: Panel = td.get("chip")
		var ti := clampi(Loot.tier_of(td.get("e", {})), 0, REV_HOLD.size() - 1)
		var hold := maxf(REV_MIN_STEP, float(REV_HOLD[ti]) * k)
		var w := maxf(24.0, chip.size.x)
		# ── 进度条：轨道 + 填充 + 百分比 ──
		var track := Panel.new()
		track.position = Vector2(chip.position.x + 6.0, chip.position.y + _cell - 30.0)
		track.size = Vector2(w - 12.0, 16.0)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(INK.r, INK.g, INK.b, 0.16)
		tsb.border_color = Color(INK.r, INK.g, INK.b, 0.30)
		tsb.set_border_width_all(1)
		tsb.set_corner_radius_all(8)
		track.add_theme_stylebox_override("panel", tsb)
		_pop_cells.add_child(track)
		var fill := Panel.new()
		fill.position = Vector2(1, 1)
		fill.size = Vector2(0.0, 14.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = Color(0.86, 0.68, 0.24, 0.92)
		fsb.set_corner_radius_all(7)
		fill.add_theme_stylebox_override("panel", fsb)
		track.add_child(fill)
		var pct := _label("0%", clampi(int(_cell * 0.15), 9, 13), Color(INK.r, INK.g, INK.b, 0.55))
		pct.position = Vector2(0, -18.0)
		pct.size = Vector2(w - 12.0, 18.0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		track.add_child(pct)
		td["track"] = track
		td["fill"] = fill
		td["pct"] = pct
		td["fill_w"] = w - 14.0
		# 这一件：**没满先藏起来**（"没满就加载"）
		chip.visible = false
		chip.pivot_offset = chip.size * 0.5
		chip.scale = Vector2(0.62, 0.62)
		td["st"] = t
		td["end"] = t + hold
		td["done"] = false
		t = float(td["end"]) + REV_GAP * k
	_rev_end = t + REV_TAIL
	if _pop_buy != null:
		_pop_buy.text = "开仓中…"
		_pop_buy.disabled = true
	_pop_msg.text = "开仓——" + str(_rev_loot.size()) + " 件货，一件一件摆出来……（点一下直接看）"
	_pop_info.text = "已买下：共 " + str(_rev_loot.size()) + " 件　·　格数 " + str(int(_pop_data.get("cells", 0)))

# v58（用户："慢不要紧 给个一键加速的按钮"）：一键加速/恢复正常。
#   演到一半点它：**立刻按新速度走**（把已经过去的那段按新系数折算，进度不跳回 0）
func _on_fast_toggle() -> void:
	# 演到一半点它：**按"已演到几成"接上**——记下进度比例，重排时间线后把 _rev_t 放回同一比例
	var frac := 0.0
	var mid := _rev_on and not _rev_ready
	if mid:
		frac = clampf(_rev_t / maxf(0.01, _rev_end), 0.0, 1.0)
	last_fast = not last_fast
	if _rev_fast_btn != null and is_instance_valid(_rev_fast_btn):
		_rev_fast_btn.text = ("加速 ×" + str(int(REV_FAST)) + "：开" if last_fast
			else "加速 ×" + str(int(REV_FAST)) + "：关")
	if mid:
		_start_open_anim()            # 按新速度重排（_rev_t 被清零）
		_rev_t = frac * _rev_end      # 接回同一个进度，不跳回开头
		_pop_msg.text = ("加速已开——这一仓快放" if last_fast else "加速已关——慢慢看") + "（点一下直接看结果）"

func _flip_dur(e: Dictionary) -> float:
	return float(REV_FLIP[clampi(Loot.tier_of(e), 0, REV_FLIP.size() - 1)])

# v58：进度条往上爬——**一件接一件**：轮到谁，谁的条就爬；爬到 100% 那件就显形（带个小弹跳）。
#   没轮到的条停在 0%（＝"还在加载"），爬完的条隐藏、换成那件货。
func _rev_step(d: float) -> void:
	_rev_t += d
	for v in _chips_last:
		var td: Dictionary = v
		if not td.has("st"):
			continue
		var st := float(td["st"])
		var en := float(td["end"])
		var fill: Panel = td.get("fill")
		var track: Panel = td.get("track")
		var pct: Label = td.get("pct")
		var chip: Panel = td.get("chip")
		if chip == null or not is_instance_valid(chip):
			continue
		# ① 还在这一段里：把条往上爬
		if _rev_t < en:
			var p := clampf((_rev_t - st) / maxf(0.01, en - st), 0.0, 1.0)
			if fill != null and is_instance_valid(fill):
				fill.size = Vector2(float(td.get("fill_w", 40.0)) * p, 14.0)
			if pct != null and is_instance_valid(pct):
				pct.text = str(int(round(p * 100.0))) + "%"
			continue
		# ② 满了：条收起来，货显形（带一个小弹跳）
		if not bool(td.get("done", false)):
			td["done"] = true
			td["pop"] = _rev_t
			if fill != null and is_instance_valid(fill):
				fill.size = Vector2(float(td.get("fill_w", 40.0)), 14.0)
			if pct != null and is_instance_valid(pct):
				pct.text = "100%"
			if track != null and is_instance_valid(track):
				track.visible = false
			chip.visible = true
			_rev_follow(td)      # v59：轮到这一件就把它滚进视野（大仓一屏装不下）
		# ③ 显形之后的一个小弹跳（0.62 → 1.0，0.18 秒）
		var pt := float(td.get("pop", 0.0))
		var x := clampf((_rev_t - pt) / 0.18, 0.0, 1.0)
		var s := 0.62 + 0.38 * (1.0 - pow(1.0 - x, 3.0))
		chip.scale = Vector2(s, s)
	if _rev_t >= _rev_end:
		_rev_finish()

# v59：格子变大 / 布局改成"一屏装不下就往下滑"之后，大仓（金匮 84 格 = 864×777）一屏装不下。
#   开仓动画是一件一件爬的——演到**屏幕外的那几件**时，玩家只看见"什么也没动"。
#   所以轮到谁就把谁**滚进视野**（只纵滑，横滑已关）。
#   ⚠ 摆法：**只挪到"刚好露出来"**（不居中、不做匀速追）——动画是顺着行一件件走的，
#     镜头跟着一点点推最稳；居中会导致每件都跳一大段，看着晕。
func _rev_follow(td: Dictionary) -> void:
	if _pop_scroll == null or not is_instance_valid(_pop_scroll):
		return
	var chip: Panel = td.get("chip")
	if chip == null or not is_instance_valid(chip):
		return
	var vp: Vector2 = _pop_scroll.size
	var content: Vector2 = _pop_cells.custom_minimum_size
	var max_y: float = maxf(0.0, content.y - vp.y + 8.0)
	var y0: float = chip.position.y
	var chh: float = chip.size.y
	var cur_y: float = clampf(float(_pop_scroll.scroll_vertical), 0.0, max_y)
	var want_y: float = cur_y
	if y0 < cur_y - 1.0:
		want_y = y0 - 8.0
	elif y0 + chh > cur_y + vp.y + 1.0:
		want_y = y0 + chh - vp.y + 8.0
	_pop_scroll.scroll_vertical = int(round(clampf(want_y, 0.0, max_y)))

func _rev_finish() -> void:
	_rev_on = false
	_rev_ready = true
	_pop_busy = false
	for v in _chips_last:
		var td: Dictionary = v
		var chip: Panel = td.get("chip")
		if chip != null and is_instance_valid(chip):
			chip.visible = true
			chip.scale = Vector2.ONE
		var track: Panel = td.get("track")
		if track != null and is_instance_valid(track):
			track.visible = false
	_pop_msg.text = "开完了！共 " + str(_rev_loot.size()) + " 件　·　点一下看结果"
	if _pop_buy != null:
		_pop_buy.text = "看结果（" + str(_rev_loot.size()) + " 件）"
		_pop_buy.disabled = false

# 爬条的途中点一下＝跳过（所有条直接拉满、所有货立刻显形）
func _rev_skip() -> void:
	for v in _chips_last:
		var td: Dictionary = v
		var chip: Panel = td.get("chip")
		if chip != null and is_instance_valid(chip):
			chip.visible = true
			chip.scale = Vector2.ONE
		var fill: Panel = td.get("fill")
		if fill != null and is_instance_valid(fill):
			fill.size = Vector2(float(td.get("fill_w", 40.0)), 14.0)
		var pct: Label = td.get("pct")
		if pct != null and is_instance_valid(pct):
			pct.text = "100%"
		var track: Panel = td.get("track")
		if track != null and is_instance_valid(track):
			track.visible = false
		td["done"] = true
	_rev_t = _rev_end
	_rev_finish()

# 结果页要写的那几行：一件一行（类别·名字·档·几格·估价）＋一笔总账
func _fill_loot_lines() -> void:
	_loot_lines = []
	var items: Array = _pop_data.get("items", [])
	var free := bool(_pop_data.get("free", false))
	var hid := str(_pop_data.get("hid", ""))
	var by_tier := [0, 0, 0, 0, 0]
	var total := 0
	for i in items.size():
		var e: Dictionary = items[i]
		var v := Loot.entry_value(e)
		total += v
		var ti := clampi(Loot.tier_of(e), 0, 4)
		by_tier[ti] += 1
		_loot_lines.append({
			"t": str(i + 1) + ". 【" + Loot.entry_kind_cn(e) + "】" + str(e.get("name", "?"))
				+ "　" + TIER_CN[ti] + "档 · " + str(int(e.get("gap", 1))) + " 格　约 " + str(v) + " 两",
			"f": 20, "c": TIER_COL[ti]})
	var head := Appraise.hold_name(hid) + "　共 " + str(items.size()) + " 件　·　格数 " + str(int(_pop_data.get("cells", 0)))
	if _rev_msg != "":
		_loot_lines.append({"t": _rev_msg, "f": 18, "c": Color(INK.r, INK.g, INK.b, 0.62)})
	_loot_lines.append({"t": head, "f": 19, "c": Color(INK.r, INK.g, INK.b, 0.72)})
	var cnt := ""
	for k in 5:
		if by_tier[k] > 0:
			cnt += ("　" if cnt != "" else "") + TIER_CN[k] + "档 ×" + str(by_tier[k])
	_loot_lines.append({"t": "成色：" + (cnt if cnt != "" else "空"), "f": 19, "c": Color(INK.r, INK.g, INK.b, 0.72)})
	_loot_lines.append({"t": "合计估价：" + str(total) + " 两", "f": 22, "c": GOLD})
	if free:
		_loot_lines.append({"t": "这只仓是打捞上来的，不花本钱。", "f": 19, "c": GREEN})
	else:
		var net := total - _rev_price
		_loot_lines.append({
			"t": "本钱 " + str(_rev_price) + " 两　→　" + ("净赚 " if net >= 0 else "净亏 ") + str(abs(net)) + " 两",
			"f": 22, "c": (GREEN if net >= 0 else SEAL)})
		if _rev_price > 0:
			_loot_lines.append({
				"t": "（估价／本钱 ＝ " + str(snappedf(float(total) * 100.0 / float(_rev_price), 1)) + "%　·　估价只是账面价，实际能卖多少看商路）",
				"f": 17, "c": Color(INK.r, INK.g, INK.b, 0.55)})

# ============================================================
# v58（用户："货仓的物品点击可以查看到底是什么品质"）：
#   **点格子看这件到底是什么**——弹一页详情。原来格子是点不动的（mouse_filter IGNORE），
#   品质只能从边框颜色猜。
#   分两种情况（数据本来就分两档，见 data_loot 的 `seen`）：
#     · 轮廓（outline）：只知道**类别 + 品质几档 + 占几格**（名字与估价还锁着）
#     · 全知（full）    ：名字、估价一起给
#   开仓动画演到一半时点格子＝跟点空白一样**跳过**（不然那会儿还没翻出来，点了也没得看）。
# ============================================================
# v61b（用户："仓库的上下滑动需要优化 极易误触仓库物品"）：货仓格子原来是**按下即开详情**，
#   手指想滑列表却把货点开了。现在整块交给 UiKit.tap_in_scroll（第三参 swallow=true ——
#   左键照样在按下时吞掉，免得冒泡到 `_pop` 变成"顺手跳过动画 / 又开一次结果页"），
#   松手时只有"位移 ≤14 像素且 ≤0.7 秒"才算点中；拖动过就什么都不做，让列表滑。
func _chip_act(idx: int) -> void:
	if _rev_on:
		_rev_skip()
		return
	_open_item_win(idx)

func _open_item_win(idx: int) -> void:
	var items: Array = _pop_data.get("items", [])
	if idx < 0 or idx >= items.size():
		return
	var e: Dictionary = items[idx]
	var reveal_all := bool(_pop_data.get("reveal_all", false))
	var o: Dictionary = GameState.appraise_offer(_pop_uid)
	var seen: Dictionary = o.get("seen", {})
	var st := "full" if reveal_all else str(seen.get(str(idx), ""))
	if st == "":
		return
	var ti := clampi(Loot.tier_of(e), 0, 4)
	# 在第几行第几格（拿同一份排版算，跟画面上一定一致）
	var cell_txt := ""
	var plan: Array = Loot.pack_cells(items, _cols)
	for p_v in plan:
		var p: Dictionary = p_v
		if int(p.get("idx", -1)) == idx:
			cell_txt = "第 " + str(int(p.get("row", 0)) + 1) + " 行第 " + str(int(p.get("col", 0)) + 1) + " 格"
			break
	var lines: Array = []
	lines.append({"t": "品质：**" + TIER_CN[ti] + "档**（第 " + str(ti + 1) + " / 5 档）", "f": 24, "c": TIER_COL[ti]})
	lines.append({"t": "类别：" + Loot.entry_kind_cn(e), "f": 19, "c": Color(INK.r, INK.g, INK.b, 0.86)})
	lines.append({"t": "占格：" + str(int(e.get("gap", 1))) + " 格　·　" + cell_txt, "f": 19, "c": Color(INK.r, INK.g, INK.b, 0.86)})
	if st == "full":
		lines.append({"t": "名称：" + str(e.get("name", "?")), "f": 21, "c": INK})
		lines.append({"t": "估价：约 " + str(Loot.entry_value(e)) + " 两", "f": 21, "c": GOLD})
		lines.append({"t": "（这一件已经看全了）", "f": 17, "c": Color(INK.r, INK.g, INK.b, 0.5)})
	else:
		lines.append({"t": "名称：？　估价：？", "f": 21, "c": Color(INK.r, INK.g, INK.b, 0.55)})
		lines.append({"t": "（只看得出轮廓——用［用道具］照一照，"
			+ "识宝鉴能给一件全知，筛子能照出整档）", "f": 17, "c": Color(SEAL.r, SEAL.g, SEAL.b, 0.85)})
	# 用道具窗那块面板（同一套样式，换一页内容）
	_close_tool_win()
	_tool_page = "item"
	_tool_pick = ""
	_loot_lines = lines
	_make_tool_win()
	_fill_tool_win()

func _on_pop_blank(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	if _tool_win != null and is_instance_valid(_tool_win):
		return                    # 结果页/道具页开着时，点面板空白不当"跳过/看结果"
	if _rev_on:
		_rev_skip()               # 开仓中：点一下跳过
	elif _rev_ready:
		_open_loot_win()          # 开完了：点一下看结果
	elif _pop_busy == false:
		_close_hold()

func _close_hold() -> void:
	if _pop != null and is_instance_valid(_pop):
		var veil := _pop.get_parent()
		if veil != null and is_instance_valid(veil):
			veil.queue_free()
	_pop = null
	_pop_cells = null
	_pop_scroll = null
	_pop_slide_hint = null
	_pop_title = null
	_pop_info = null
	_pop_msg = null
	_pop_buy = null
	_close_tool_win()
	_flash.clear()
	_flash_t = 0.0
	_pop_uid = -1
	_pop_busy = false
	# 开仓动画态（_pop_cells 那一坨跟着 veil 一起 free 了，这里把这些引用清干净）
	_rev_on = false
	_rev_ready = false
	_rev_t = 0.0
	_rev_end = 0.0
	_rev_band = null
	_rev_rows = 1
	_rev_loot = []
	_rev_price = 0
	_rev_msg = ""
	_chips_last = []
	_loot_lines = []
	refresh()

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

func _style_dark(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.19, 0.20, 0.96)))
	btn.add_theme_stylebox_override("hover", _flat(Color(0.31, 0.27, 0.27, 0.96)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.11, 0.12, 0.96)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.40)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.55))

# ---- 开合 ----
func open() -> void:
	_busy = false
	_msg_lb.text = ""
	refresh()
	visible = true

func close() -> void:
	if not visible:
		return
	_close_hold()
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
			if _pop != null:
				_close_hold()
				return
			close()
