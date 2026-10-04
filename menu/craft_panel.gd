extends Control
# ============================================================
# craft_panel.gd —— 「百工坊」v1（v50）
#
# 用户："品酒 炼丹 鉴宝统一集中到一个建筑物吧，也好点。名字你看着起——
#   就一个主界面，上面品酒 / 炼丹 / 鉴宝。"
#
# 所以：**一间屋子、三个作坊**。村里只留一个记号「百工坊」，
#   点进来就是这一页——上面三块牌子，点哪块进哪个作坊：
#     品酒坊（wine_panel）· 炼丹阁（alchemy_panel）· 鉴宝行（appraise_panel）
#   三块牌子各自写着**自己那间开没开**、以及现在能干什么（一行摘要）。
#
# ⚠ 三个作坊的**规矩一个字都没搬进来**：面板还是原来那三个（各自 open()），
#   账还是 GameState 里那三节（`winery_built` / `dange_built` / `jianbao_unlocked`）。
#   这一页只是"门厅"——以后加第四个作坊，在这里加一块牌子就行。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const ItemArt := preload("res://shared/item_art.gd")   # v70：水墨道具图
const SceneArt := preload("res://shared/scene_art.gd")   # v77：内景垫图

signal closed
# 门厅自己不管那三个面板——由主界面把"开门"的动作接过去
signal room_pressed(room: String)

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const GOLD := Color(0.72, 0.52, 0.14)
const GREEN := Color(0.28, 0.50, 0.30)

const PANEL_W := 640.0
const PANEL_H := 820.0
const CARD_Y0 := 208.0
const CARD_STEP := 172.0
const CARD_H := 154.0

var _panel: Panel
var _cards: Array = []
var _msg_lb: Label
var _t := 0.0

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	refresh()
	visible = get_parent() == get_tree().root

func _process(d: float) -> void:
	if not visible:
		return
	_t += d
	queue_redraw()

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
	# v77：门厅也垫一张内景（酒肆那间），进门就有"屋子"的感觉
	UiKit.add_room_bg(_panel, SceneArt.inn(), 0.30)

	var title := _label("百 工 坊", 32, INK)
	title.position = Vector2(28, 16)
	title.size = Vector2(300, 46)
	_panel.add_child(title)

	var sub := _label("一间屋子，三个作坊：酿酒、炼丹、鉴宝。", 14, Color(INK.r, INK.g, INK.b, 0.62))
	sub.position = Vector2(30, 62)
	sub.size = Vector2(PANEL_W - 60.0, 22)
	_panel.add_child(sub)

	var sep := ColorRect.new()
	sep.color = Color(INK.r, INK.g, INK.b, 0.22)
	sep.position = Vector2(28, 100)
	sep.size = Vector2(PANEL_W - 56.0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sep)

	# ── 三块作坊牌子（点哪块进哪间）──
	# v70：三块牌子左边挂**水墨道具图**（酒坛 / 药草 / 令牌）——原来是颗写字圆牌，
	#   现在字退成底衬、图压在中间，跟全作的水墨语言一致（这套图是从一张水墨道具图集里切出来的）。
	var rooms := [
		{"id": "wine", "name": "品 酒 坊", "icon": "酒", "art": "it_jar"},
		{"id": "alchemy", "name": "炼 丹 阁", "icon": "丹", "art": "it_herb"},
		{"id": "jianbao", "name": "鉴 宝 行", "icon": "宝", "art": "it_token"},
	]
	_cards = []
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var y := CARD_Y0 + float(i) * CARD_STEP
		var card := Panel.new()
		card.position = Vector2(28, y)
		card.size = Vector2(PANEL_W - 56.0, CARD_H)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(1, 1, 1, 0.42)
		csb.set_corner_radius_all(12)
		csb.border_color = Color(INK.r, INK.g, INK.b, 0.24)
		csb.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", csb)
		_panel.add_child(card)
		# 左边一个"字牌"（酒 / 丹 / 宝）——没有贴图，用一颗圆牌写字
		var chip := Label.new()
		chip.text = str(r["icon"])
		chip.position = Vector2(16, 22)
		chip.size = Vector2(88, 88)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_font_size_override("font_size", 40)
		chip.add_theme_color_override("font_color", Color(0.35, 0.30, 0.26, 0.30))   # 字退成浅底纹，图才是主角
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chsb := StyleBoxFlat.new()
		# v70：底衬改**纸色**——水墨图是深墨画的，压在原来的深褐圆牌上根本看不清（第一版就是）
		chsb.bg_color = Color(0.925, 0.898, 0.822, 0.96)
		chsb.set_corner_radius_all(44)
		chsb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.65)
		chsb.set_border_width_all(2)
		chip.add_theme_stylebox_override("normal", chsb)
		card.add_child(chip)
		# 压一张水墨道具图上去（找不到图就只留字牌，不会空一块）
		var chip_art := ItemArt.icon(str(r.get("art", "")))
		if chip_art != null:
			var ctr := TextureRect.new()
			ctr.texture = chip_art
			ctr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ctr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ctr.position = Vector2(24, 26)
			ctr.size = Vector2(72, 80)
			ctr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(ctr)
		var nm := _label(str(r["name"]), 24, INK)
		nm.position = Vector2(122, 24)
		nm.size = Vector2(280, 32)
		card.add_child(nm)
		var st := _label("", 13, Color(INK.r, INK.g, INK.b, 0.62))
		st.position = Vector2(122, 62)
		st.size = Vector2(PANEL_W - 56.0 - 260.0, 44)
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(st)
		var go := _label("进 ▸", 16, Color(INK.r, INK.g, INK.b, 0.40))
		go.position = Vector2(PANEL_W - 56.0 - 66.0, 104)
		go.size = Vector2(56, 24)
		go.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		card.add_child(go)
		card.gui_input.connect(_on_card.bind(str(r["id"])))
		_cards.append({"id": str(r["id"]), "card": card, "name": nm, "st": st, "chip": chip})

	_msg_lb = _label("", 13, Color(SEAL.r, SEAL.g, SEAL.b, 0.94))
	_msg_lb.position = Vector2(28, PANEL_H - 128.0)
	_msg_lb.size = Vector2(PANEL_W - 56.0, 56)
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_msg_lb)

	var close_btn := UiKit.make_button(_panel, Vector2(220, PANEL_H - 62.0), Vector2(200, 48), "出　门", 20)
	close_btn.pressed.connect(close)

func _label(text: String, font_size: int, col: Color) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", col)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lb

# ══════════════════════════════════════════════════════════
func refresh() -> void:
	if _panel == null:
		return
	for e_v in _cards:
		var e: Dictionary = e_v
		var rid := str(e["id"])
		var st: Label = e["st"]
		var chip: Label = e["chip"]
		var on := false
		var line := ""
		match rid:
			"wine":
				on = GameState.winery_built
				if on:
					line = "请人品酒 · 卖酒（现有 " + str(GameState.wines.size()) + " 坛）"
				else:
					line = "还没起这间——先过山洞那段（" + str(GameState.material_count("wood")) + "/8 木料）"
			"alchemy":
				on = GameState.dange_built
				if on:
					if GameState.alchemy_busy():
						# v56：整数除法告警——这里算的是"还剩几分钟"，向上取整更贴切
						#   （剩 1 秒也显示 1 分），顺便避开 INTEGER_DIVISION。
						var mins := int(ceil(float(GameState.alchemy_remain_sec()) / 60.0))
						line = GameState.furnace_line() + GameState.furnace_tender_text() + " · 剩 " + str(mins) + " 分"
					else:
						line = "炉子空着——开炉炼丹（可派弟子看火）"
				else:
					line = "灵草剧情还没到（第 " + str(GameState.STORY_HERB_STAGE) + " 关）" if not GameState.dange_unlocked() else "有灵草了——起炉要 " + str(GameState.material_count("wood")) + "/10 木料"
			"jianbao":
				on = GameState.jianbao_ok()
				if on:
					line = "看仓 " + str(GameState.appraise_offers.size()) + " 只 · " + GameState.appraise_tool_line()
				else:
					line = "还没开张——过第 " + str(GameState.STORY_JIANBAO_STAGE) + " 关（打捞上来的货仓）"
		st.text = line
		# 未开的作坊：牌子压暗（进不去）
		chip.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88) if on else Color(0.72, 0.70, 0.68))
		(e["name"] as Label).add_theme_color_override("font_color", INK if on else Color(INK.r, INK.g, INK.b, 0.45))

func _on_card(ev: InputEvent, room: String) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	# 未开的作坊：给一句话，不开门（跟村口牌子上的说法一致）
	match room:
		"wine":
			if not GameState.winery_built:
				_msg_lb.text = "品酒坊还没起——先把山洞那段过了（山洞就在村里，起屋要 8 木料）"
				return
		"alchemy":
			# ⚠ 这里以前是 `if not dange_built:` → 两种情况都 return，**解锁了也进不去**，
			#   于是"过了 300 关、木料也够了"却永远起不了炉（用户报的那条）。
			#   现在只有"还没解锁"才拦；解锁了就把这一下交给主界面去起炉（那里才有木料账）。
			if not GameState.dange_built and not GameState.dange_unlocked():
				_msg_lb.text = "炼丹阁要到第 " + str(GameState.STORY_HERB_STAGE) + " 关（灵草剧情）才起得了炉"
				return
		"jianbao":
			if not GameState.jianbao_ok():
				_msg_lb.text = "鉴宝行还没开张——过第 " + str(GameState.STORY_JIANBAO_STAGE) + " 关（打捞上来的货仓）"
				return
	_msg_lb.text = ""
	room_pressed.emit(room)

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
