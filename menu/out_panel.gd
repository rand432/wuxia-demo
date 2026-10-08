extends Control
# ============================================================
# out_panel.gd —— 「出村」关卡面板 v6
# v5：只改提示文案——自动挑战现在战斗画面右上角也能开关；
#   战斗结束后自动接下一关，不用再点回村。其余同 v4。
# v6（v129）：底下多一张「追剿」卡——精英爬塔（公主府的追杀队）。
#   手动＝手牌模式（kushou）· 自动＝battle_lite；**每五关一个 boss**，共 500 关。
#   爬塔没到 500 关时这张卡灰着，并写清"还差多少关"。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const Chase := preload("res://shared/data_chase.gd")

signal challenge(i: int)
signal config_pressed
signal chest_pressed   # v6：宝箱（爬塔宝箱机制）
signal chase_manual    # v129：追剿·手牌模式（kushou）
signal chase_auto      # v129：追剿·自动战斗（battle_lite）
signal chase_bg_off    # v143：把"后台推进"关掉（人已经在村里，不用再进战斗）
signal chase_challenge(i: int)   # v144：在追剿关卡列表里点［挑战］（这一关真打一场）

# v144（用户："出战界面你把追剿那一行换成[开关] 点击切换为追剿的挑战关卡不就好了？"）：
#   那一行**整行可点**＝在［爬塔关卡］与［追剿关卡］之间切换；切过去以后，
#   上面那五行就变成追剿的五关（含 boss 行的特性/被动提示），一关一个［挑战］。
var _chase_view := false
var _chase_page := 0
signal closed

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const GREEN := Color(0.30, 0.52, 0.32)

const PANEL_W := 640.0
# v129：820 → 892——底下要给「追剿」那张卡腾出 72 高（底排按钮跟着下移）
const PANEL_H := 892.0
const PER_PAGE := 5
# ㊿n2：页数跟着塔高走（STAGE_MAX 50 ÷ 每章 5 关 ＝ 10 章）——不再写死 6
func _pages() -> int:
	return (GameState.STAGE_MAX + PER_PAGE - 1) / PER_PAGE

var _panel: Panel
var _page := 0
var _chap_lb: Label
var _team_lb: Label
var _coin_lb: Label
var _auto_btn: Button
var _chest_btn: Button
var _hint_lb: Label
var _row_name: Array = []
var _row_status: Array = []
var _row_btn: Array = []
# v129：追剿那张卡上的三件
var _chase_switch: Button   # v144：整行可点的切换钮（爬塔关卡 ↔ 追剿关卡）
var _chase_lb: Label
var _chase_sub: Label
var _chase_m_btn: Button
var _chase_a_btn: Button

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

	var title := _label("出　村", 30, INK)
	title.position = Vector2(28, 20)
	title.size = Vector2(240, 44)
	_panel.add_child(title)
	var sub := _label(str(GameState.STAGE_MAX) + " 关 · " + str(_pages()) + " 章——一章一章清", 15, Color(INK.r, INK.g, INK.b, 0.55))
	sub.position = Vector2(30, 60)
	sub.size = Vector2(400, 22)
	_panel.add_child(sub)

	_coin_lb = _label("", 13, Color(INK.r, INK.g, INK.b, 0.55))
	_coin_lb.position = Vector2(430, 64)   # v61：给宝箱钮让出 48 高
	_coin_lb.size = Vector2(182, 20)
	_coin_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_coin_lb)

	# v6（v36）：［宝箱］——右上角。每清一关攒一个箱子，点开去开箱（新的面板）。
	_chest_btn = Button.new()
	# v61（手游）：38 → 48 高、15 → 17 号（右上角那颗抓得住）
	_chest_btn.position = Vector2(430, 12)
	_chest_btn.size = Vector2(182, 48)
	_chest_btn.add_theme_font_size_override("font_size", 17)
	_chest_btn.focus_mode = Control.FOCUS_NONE
	_chest_btn.pressed.connect(_on_chest)
	_style_challenge(_chest_btn)
	_panel.add_child(_chest_btn)

	var sep := ColorRect.new()
	sep.color = Color(INK.r, INK.g, INK.b, 0.22)
	sep.position = Vector2(28, 88)
	sep.size = Vector2(PANEL_W - 56.0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sep)

	_team_lb = _label("", 15, Color(INK.r, INK.g, INK.b, 0.78))
	_team_lb.position = Vector2(28, 96)
	_team_lb.size = Vector2(584, 26)
	_panel.add_child(_team_lb)

	var prev := Button.new()
	prev.text = "‹ 上一章"
	prev.position = Vector2(28, 126)
	prev.size = Vector2(104, 44)
	prev.add_theme_font_size_override("font_size", 15)
	prev.focus_mode = Control.FOCUS_NONE
	prev.pressed.connect(_on_page.bind(-1))
	_style_dark(prev)
	_panel.add_child(prev)

	var nextb := Button.new()
	nextb.text = "下一章 ›"
	nextb.position = Vector2(508, 126)
	nextb.size = Vector2(104, 44)
	nextb.add_theme_font_size_override("font_size", 15)
	nextb.focus_mode = Control.FOCUS_NONE
	nextb.pressed.connect(_on_page.bind(1))
	_style_dark(nextb)
	_panel.add_child(nextb)

	_chap_lb = _label("", 17, INK)
	_chap_lb.position = Vector2(140, 130)
	_chap_lb.size = Vector2(360, 36)
	_chap_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chap_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(_chap_lb)

	_row_name = []
	_row_status = []
	_row_btn = []
	for i in PER_PAGE:
		var y := 184.0 + float(i) * 100.0
		var row := Panel.new()
		row.position = Vector2(28, y)
		row.size = Vector2(584, 92)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(1, 1, 1, 0.30)
		rsb.set_corner_radius_all(8)
		rsb.border_color = Color(INK.r, INK.g, INK.b, 0.20)
		rsb.set_border_width_all(1)
		row.add_theme_stylebox_override("panel", rsb)
		_panel.add_child(row)
		var nm := _label("", 19, INK)
		nm.position = Vector2(20, 12)
		nm.size = Vector2(390, 30)
		row.add_child(nm)
		var stt := _label("", 13, Color(INK.r, INK.g, INK.b, 0.60))
		stt.position = Vector2(20, 46)
		stt.size = Vector2(390, 24)
		row.add_child(stt)
		var btn := Button.new()
		btn.position = Vector2(424, 20)
		btn.size = Vector2(140, 52)
		btn.add_theme_font_size_override("font_size", 18)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_row.bind(i))
		_style_challenge(btn)
		row.add_child(btn)
		_row_name.append(nm)
		_row_status.append(stt)
		_row_btn.append(btn)

	# ============================================================
	# v129：［追剿］卡——精英爬塔（公主府的追杀队）
	#   位置在五关列表与底部按钮之间（682~754），跟固定件都不打架；
	#   卡上两行字＋两颗钮：［手牌］走 kushou（自己配牌）、［自动］走 battle_lite。
	# ============================================================
	var ccard := Panel.new()
	ccard.position = Vector2(28, 682)
	ccard.size = Vector2(584, 72)
	ccard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(SEAL.r, SEAL.g, SEAL.b, 0.10)
	csb.set_corner_radius_all(8)
	csb.border_color = Color(SEAL.r, SEAL.g, SEAL.b, 0.55)
	csb.set_border_width_all(1)
	ccard.add_theme_stylebox_override("panel", csb)
	_panel.add_child(ccard)

	# v144：整行可点——透明钮压在字上，点它就是"切到追剿关卡列表"
	_chase_switch = Button.new()
	_chase_switch.position = Vector2(6, 3)
	_chase_switch.size = Vector2(338, 66)
	_chase_switch.flat = true
	_chase_switch.focus_mode = Control.FOCUS_NONE
	_chase_switch.tooltip_text = "点这一行：在［爬塔关卡］与［追剿关卡］之间切换"
	_chase_switch.add_theme_stylebox_override("normal", _flat(Color(0, 0, 0, 0)))
	_chase_switch.add_theme_stylebox_override("hover", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.10)))
	_chase_switch.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.18)))
	_chase_switch.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	_chase_switch.pressed.connect(_on_chase_switch)
	ccard.add_child(_chase_switch)

	_chase_lb = _label("", 17, INK)
	_chase_lb.position = Vector2(18, 6)
	_chase_lb.size = Vector2(340, 24)
	_chase_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ccard.add_child(_chase_lb)

	_chase_sub = _label("", 12, Color(INK.r, INK.g, INK.b, 0.62))
	_chase_sub.position = Vector2(18, 32)
	_chase_sub.size = Vector2(340, 34)
	_chase_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chase_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ccard.add_child(_chase_sub)

	_chase_m_btn = Button.new()
	_chase_m_btn.text = "手牌"
	_chase_m_btn.position = Vector2(348, 19)
	_chase_m_btn.size = Vector2(84, 34)
	_chase_m_btn.add_theme_font_size_override("font_size", 15)
	_chase_m_btn.focus_mode = Control.FOCUS_NONE
	_chase_m_btn.tooltip_text = "手牌模式：进战斗自己点牌出手（游历那种出牌）——轮到你的人就摊一张手牌"
	_chase_m_btn.pressed.connect(_on_chase_manual)
	_style_dark(_chase_m_btn)
	ccard.add_child(_chase_m_btn)

	_chase_a_btn = Button.new()
	_chase_a_btn.text = "自动"
	_chase_a_btn.position = Vector2(440, 19)
	_chase_a_btn.size = Vector2(110, 34)
	_chase_a_btn.add_theme_font_size_override("font_size", 15)
	_chase_a_btn.focus_mode = Control.FOCUS_NONE
	_chase_a_btn.tooltip_text = "自动战斗：跟爬塔一样，看着它一场一场打（可开自动连打）"
	_chase_a_btn.pressed.connect(_on_chase_auto_click)
	_style_challenge(_chase_a_btn)
	ccard.add_child(_chase_a_btn)

	_hint_lb = _label("", 13, Color(INK.r, INK.g, INK.b, 0.45))   # v61（手游）：12 → 13 号
	_hint_lb.position = Vector2(28, 762)
	_hint_lb.size = Vector2(584, 44)
	_hint_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_hint_lb)

	var cfg_btn := Button.new()
	cfg_btn.text = "出战配置"
	cfg_btn.position = Vector2(28, 812)
	cfg_btn.size = Vector2(180, 56)
	cfg_btn.add_theme_font_size_override("font_size", 19)
	cfg_btn.focus_mode = Control.FOCUS_NONE
	cfg_btn.pressed.connect(_on_config)
	_style_dark(cfg_btn)
	_panel.add_child(cfg_btn)

	_auto_btn = Button.new()
	_auto_btn.text = "自动挑战：关"
	_auto_btn.position = Vector2(220, 812)
	_auto_btn.size = Vector2(200, 56)
	_auto_btn.add_theme_font_size_override("font_size", 17)
	_auto_btn.focus_mode = Control.FOCUS_NONE
	_auto_btn.pressed.connect(_on_auto)
	_panel.add_child(_auto_btn)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(432, 812)
	close_btn.size = Vector2(180, 56)
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
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.40)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.55))

func _style_auto(on: bool) -> void:
	if on:
		_auto_btn.add_theme_stylebox_override("normal", _flat(Color(GREEN.r, GREEN.g, GREEN.b, 0.90)))
		_auto_btn.add_theme_stylebox_override("hover", _flat(Color(GREEN.r, GREEN.g, GREEN.b, 0.78)))
		_auto_btn.add_theme_stylebox_override("pressed", _flat(Color(GREEN.r * 0.75, GREEN.g * 0.75, GREEN.b * 0.75, 0.95)))
	else:
		_auto_btn.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.19, 0.20, 0.96)))
		_auto_btn.add_theme_stylebox_override("hover", _flat(Color(0.31, 0.27, 0.27, 0.96)))
		_auto_btn.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.11, 0.12, 0.96)))
	_auto_btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	_auto_btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87))

func _style_challenge(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.92)))
	btn.add_theme_stylebox_override("hover", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.80)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r * 0.75, SEAL.g * 0.75, SEAL.b * 0.75, 0.95)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.35)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.50))

func refresh() -> void:
	if _panel == null:
		return
	_refresh_chase()
	_coin_lb.text = GameState.coin_line(false)
	# v6：宝箱钮上写"攒了几个"——一眼看得出该不该去开
	if _chest_btn != null:
		var cn := GameState.chest_total()
		_chest_btn.text = "宝箱 ×" + str(cn) + ("" if cn <= 0 else " · 可开")
	var tn: Array = GameState.formation_names()
	if tn.is_empty():
		_team_lb.text = "出战：还没安排——先去整备"
	else:
		_team_lb.text = "出战（前→后）：" + "、".join(PackedStringArray(tn)) + " ｜ 要改阵容：左下［出战配置］"
		# v144：切到追剿视图时，上面这五行改画追剿的五关（其余固定件照旧）
	if _chase_view and GameState.chase_unlocked():
		_refresh_chase_page()
		return
	_page = clampi(_page, 0, _pages() - 1)
	var a := _page * PER_PAGE
	_chap_lb.text = "第 " + str(_page + 1) + " 章 · " + GameState.chapter_of(a) + "（第 " + str(a + 1) + "–" + str(a + PER_PAGE) + " 关）"
	var p := GameState.stage_progress
	for k in PER_PAGE:
		var idx := a + k
		var e: Dictionary = GameState.enemy_at(idx)
		var nm: Label = _row_name[k]
		var stt: Label = _row_status[k]
		var btn: Button = _row_btn[k]
		nm.text = "第 " + str(idx + 1) + " 关 · " + str(e["name"])
		# ㊿r：剧情关（第 50/150/300 关）标在**名字行**——那行本来就短，够放；
		#   状态行（赏格那条）已经很长了，再塞进去就出框。
		if GameState.is_story_stage(idx):
			nm.text += "（剧情·真打）"
		if idx < p:
			stt.text = "已清缴"
			btn.text = "已清"
			btn.disabled = true
		elif idx == p:
			# ㊲：赏格改口径——银两＋经验入池；**只有首领关**掉装备/兵器/功法
			var s := "对手：气血 " + str(e["hp"]) + " · 攻 " + str(e["atk"]) + " · 赏：银两 +" + str(GameState.stage_silver(idx)) + " · 经验 +" + str(GameState.stage_exp_gain(idx))
			if GameState.is_boss(idx):
				s += "（首领再 +" + str(GameState.boss_silver_gain(idx)) + "）"
				s += "｜首领赏一件：" + str(GameState.GRADE_CN[GameState.tower_gift_tier_now()]) + "（凡品给整套，往后给残页）"
			elif GameState.is_elite(idx):
				s += "（精英关）"
			stt.text = s
			btn.text = "挑战"
			btn.disabled = false
		else:
			stt.text = "未解锁——先清前一关"
			btn.text = "锁定"
			btn.disabled = true
	_auto_btn.visible = p >= 1
	var auto_txt := "自动挑战：开" if GameState.auto_climb else "自动挑战：关"
	# ㊿q：开了自动、人又在村里（auto_bg）——标出"后台推塔中"，免得看不出它在动
	if GameState.auto_climb and GameState.auto_bg:
		auto_txt += "（后台）"
	_auto_btn.text = auto_txt
	_style_auto(GameState.auto_climb)
	if p >= GameState.STAGE_MAX:
		_hint_lb.text = str(GameState.STAGE_MAX) + " 关清净了——山外风声更近。（下一轮：真正的游历）"
	elif GameState.auto_climb:
		# ㊿：这一颗钮现在管两件事：屏幕上的连打 ＋ **挂机爬塔**（见 game_state._idle_climb）
		# ㊿q：再分一层——屏幕里连打 / 后台估算（战斗画面［回村·后台继续］切过去）
		if GameState.auto_bg:
			# ㊿r：后台推塔撞上剧情关就停住了——把"卡在哪、为什么"写清楚
			var g := GameState.climb_gate()
			if g < GameState.STAGE_MAX and p >= g:
				_hint_lb.text = "自动挑战：开·后台推定住了——推到第 " + str(g + 1) + " 关停：这关有剧情，估算不替你过。\n点上面的［挑战］真打一场，剧情过后后台自己接着往上推。"
			else:
				_hint_lb.text = "自动挑战：开·后台推塔中——塔每 20 秒按估算往上推一关（推完在村里报一声）。\n想看着它打就点［挑战］进战斗画面；不想推了就点这颗钮关掉。"
		else:
			_hint_lb.text = "自动挑战：开——清完一关自动接下一关；撤退/败退自停。\n战斗画面右下角还有［回村·后台继续］：人先回村，塔改后台估算接着推（这个钮不用关）。"
	else:
		_hint_lb.text = "清关得银两；经验进经验池（弟子面板分配）｜首领关另赏一件装备/兵器/功法：凡品给整套，良品起给残页（同一件凑齐才算到手）｜第一关打完可开［自动挑战］（开了才会连打、也才会挂机推塔）\n底下那一行是［追剿］——点它就把这个列表换成追剿的五关（再点一下切回来）。"

# v144：追剿视图下，上面那五行画的是**追剿的五关**（一页一剿）
#   · 抬头＝第几剿 / 共几剿 / 这几关的关号区间
#   · 每行＝关号 + 敌名（首领标出来）+ 赏格；首领行把小字换成"特性/被动"
#   · 按钮＝［挑战］（当前那一关）/ 已清 / 锁定
func _refresh_chase_page() -> void:
	_chase_page = clampi(_chase_page, 0, Chase.rounds() - 1)
	var base := Chase.stage_of_round(_chase_page + 1)
	var p := GameState.chase_progress
	var head := "追剿 · 第 " + str(_chase_page + 1) + "/" + str(Chase.rounds()) + " 剿（第 " + str(base + 1) + "–" + str(mini(base + Chase.BOSS_EVERY, Chase.STAGE_MAX)) + " 关）"
	_chap_lb.text = head
	for k in PER_PAGE:
		var idx := base + k
		var nm: Label = _row_name[k]
		var stt: Label = _row_status[k]
		var btn: Button = _row_btn[k]
		if idx >= Chase.STAGE_MAX:
			nm.text = "—"
			stt.text = "追剿清净了"
			btn.text = "—"
			btn.disabled = true
			btn.tooltip_text = ""
			continue
		var e: Dictionary = GameState.chase_enemy_at(idx)
		var boss := Chase.is_boss(idx)
		nm.text = "第 " + str(idx + 1) + " 关 · " + str(e["name"]) + ("（首领）" if boss else "")
		if boss:
			# 首领行：小字写"怎么打"（特性 + 专属被动 + 针对），比赏格重要
			var tip := Chase.trait_lines(Chase.boss_traits_of(idx))
			var pd: Dictionary = Chase.passive_def(Chase.passive_of(idx))
			var seg := ""
			for tp in tip:
				seg += ("" if seg == "" else "　") + str(tp)
			if not pd.is_empty():
				seg += "　被动「" + str(pd.get("name", "")) + "」" + str(pd.get("counter", ""))
			stt.text = seg
			btn.tooltip_text = "赏：" + Chase.reward_line(idx) + "\n" + Chase.passive_line(idx)
		else:
			stt.text = "赏：" + Chase.reward_line(idx)
			btn.tooltip_text = ""
		if idx < p:
			stt.text = "已清缴"
			btn.text = "已清"
			btn.disabled = true
		elif idx == p:
			btn.text = "挑战"
			btn.disabled = false
		else:
			# 还没解锁的关：**首领行照样把特性/被动摊出来**——"下一剿要打谁、怎么克"
			#   本来就是这一页最该看的东西（杂兵行就只写未解锁）
			if not boss:
				stt.text = "未解锁——先清前一关"
			btn.text = "锁定"
			btn.disabled = true
	# 底部那颗［自动挑战］是爬塔的口径——追剿视图里收起来（追剿的开关在那一行上）
	_auto_btn.visible = false
	_hint_lb.text = "追剿关卡：点［挑战］真打这一关（进战斗后右上那颗钮可在［手动出牌／自动］之间切）。\n这一趟是公主府的追杀队——首领关记得看它的特性与被动，挑克制的阵容上。点上面那一行可切回爬塔。"

# v129：追剿那条卡——进度 / 下一战 / 特性名；没解锁就写清"还差多少关"
func _refresh_chase() -> void:
	if _chase_lb == null:
		return
	var p := GameState.chase_progress
	var on := GameState.chase_unlocked()
	if not on:
		_chase_lb.text = "追剿 · 未解锁"
		_chase_sub.text = "爬塔到第 " + str(Chase.UNLOCK_STAGE) + " 关才开 · 还差 " + str(GameState.chase_gap()) + " 关（现在第 " + str(GameState.stage_progress) + " 关）"
	elif p >= Chase.STAGE_MAX:
		_chase_lb.text = "追剿 · " + str(Chase.STAGE_MAX) + "/" + str(Chase.STAGE_MAX) + "（已清）"
		_chase_sub.text = "公主府的追杀队一个不剩——村口安静了。"
	else:
		# v144：这一行现在是"关卡列表切换开关"——标题上带个箭头，让人知道能点
		if _chase_view:
			_chase_lb.text = "◂ 回爬塔（追剿 · 第 " + str(p + 1) + "/" + str(Chase.STAGE_MAX) + " 关）"
		else:
			_chase_lb.text = "▸ 追剿 · 第 " + str(p + 1) + "/" + str(Chase.STAGE_MAX) + " 关（第 " + str(Chase.round_of(p)) + " 剿）"
		var tail := ""
		if Chase.is_boss(p):
			tail = "　" + Chase.trait_names(Chase.boss_traits_of(p))
		# v136：把"这一档给什么品级"写在小字里（每 80 关升一档，封顶极品）
		# v141：boss 关把**专属被动**的名字也带上（"这一关该针对什么"一眼看到）
		if Chase.is_boss(p):
			var pd2: Dictionary = Chase.passive_def(Chase.passive_of(p))
			if not pd2.is_empty():
				tail += "　被动「" + str(pd2.get("name", "")) + "」"
		var sub_txt := "第 " + str(Chase.wave_in_round(p)) + "/" + str(Chase.BOSS_EVERY) + " 关 ｜ " + Chase.panel_line(p) + tail
		# v143：连打开着 + 人在村里 ＝ 后台估算正在推——标出来（与爬塔那条一样的写法）
		if GameState.chase_auto and GameState.chase_bg:
			sub_txt += "　·　后台推进中"
		_chase_sub.text = sub_txt + "（" + Chase.reward_q_cn(p) + "档）"
	var can := on and p < Chase.STAGE_MAX
	_chase_m_btn.disabled = not can
	_chase_a_btn.disabled = not can
	_chase_m_btn.text = "手牌" if can else "未开"
	if GameState.chase_auto and GameState.chase_bg:
		_chase_a_btn.text = "停推" if can else "未开"
	else:
		_chase_a_btn.text = "自动" if can else "未开"

# v144：那一行整行可点——在［爬塔关卡］与［追剿关卡］之间切换
func _on_chase_switch() -> void:
	if not GameState.chase_unlocked():
		return
	_chase_view = not _chase_view
	if _chase_view:
		# 切过去时默认停在"当前这一剿"，省得从头翻
		_chase_page = clampi(Chase.round_of(GameState.chase_progress) - 1, 0, Chase.rounds() - 1)
	refresh()

func _on_chase_manual() -> void:
	if _chase_m_btn.disabled:
		return
	chase_manual.emit()

func _on_chase_auto() -> void:
	if _chase_a_btn.disabled:
		return
	chase_auto.emit()

func _on_row(i: int) -> void:
	# v144：追剿视图里，这一行的［挑战］打的是追剿那一关
	if _chase_view:
		chase_challenge.emit(Chase.stage_of_round(_chase_page + 1) + i)
		return
	challenge.emit(_page * PER_PAGE + i)

func _on_config() -> void:
	config_pressed.emit()

func _on_chest() -> void:
	chest_pressed.emit()

# v143：追剿的［自动］开关——关掉时把"后台推进"那面旗一起收（与爬塔的 auto_bg 同规矩）
func _on_chase_auto_click() -> void:
	if _chase_a_btn.disabled:
		return
	# v143：后台正在推的时候，这颗钮是"停推"——不想让它自己走了就点它
	#   （否则玩家一旦按了［回村·后台继续］，村里就没有关掉它的地方了）
	if GameState.chase_auto and GameState.chase_bg:
		GameState.chase_auto = false
		GameState.chase_bg = false
		chase_bg_off.emit()
		refresh()
		return
	chase_auto.emit()

func _on_auto() -> void:
	GameState.auto_climb = not GameState.auto_climb
	if not GameState.auto_climb:
		GameState.auto_bg = false   # ㊿q：关了就两种形态一起收
	print("[出村] 自动挑战 = ", GameState.auto_climb)
	refresh()

func _on_page(d: int) -> void:
	# v144：追剿视图里，这两颗钮翻的是"剿"（一剿＝五关），不是塔的章
	if _chase_view:
		_chase_page = clampi(_chase_page + d, 0, Chase.rounds() - 1)
		refresh()
		return
	_page = clampi(_page + d, 0, _pages() - 1)
	refresh()

func open() -> void:
	_page = clampi(GameState.stage_progress / PER_PAGE, 0, _pages() - 1)
	# v144：开着追剿视图再打开面板时，追剿那一页也跟着进度走
	if _chase_view:
		_chase_page = clampi(Chase.round_of(GameState.chase_progress) - 1, 0, Chase.rounds() - 1)
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
