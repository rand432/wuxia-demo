extends Control
# v254：江湖关系——把货郎 / 山门 / 凶物 / 此方世界收在一页。
signal closed

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")
const WarReportPanel := preload("res://journey/explore/war_report_panel.gd")
const EpiloguePanel := preload("res://journey/explore/epilogue_panel.gd")
const WarTablePanel := preload("res://journey/explore/war_table_panel.gd")

const LAND_NAMES := ["山多·路窄", "水多·雾重", "林密·怪多", "石多·宝多", "雪原·苦寒"]

var _sub_lb: Label
var _dealer_lb: Label
var _sect_lb: Label
var _boss_lb: Label
var _world_lb: Label
var _gift_btn: Button
var _wash_btn: Button
var _appease_btn: Button
var _msg_lb: Label
var _war_btn: Button
var _war_panel: Control
var _epi_btn: Button
var _epi_panel: Control
var _war_table_btn: Button
var _war_table_panel: Control
var _close_btn: Button
var _last_info := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.64)
	var panel := UiKit.make_paper_panel(veil, Rect2(40, 160, 640, 960))
	panel.add_theme_stylebox_override("panel", UiKit.paper_box(1.0))
	# v244：标题改左对齐——右上「战线/后记/战报」三颗钮原来正压在居中标题上
	var title := UiKit.make_label(panel, Vector2(30, 20), Vector2(220, 46), 34, UiKit.INK)
	UiKit.set_text(title, "江 湖 关 系")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_sub_lb = UiKit.make_label(panel, Vector2(0, 70), Vector2(640, 30), 22, UiKit.DIM)
	UiKit.set_text(_sub_lb, "货郎 · 山门 · 凶物 · 此方世界")
	_sub_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_dealer_lb = _section("货 郎 老 赵", 110)
	_sect_lb = _section("青 岚 山 门", 250)
	_boss_lb = _section("凶 物", 410)
	_world_lb = _section("此 方 世 界", 590)
	_gift_btn = UiKit.make_button(panel, Vector2(40, 758), Vector2(170, 48), "送礼 50两", 21)
	_gift_btn.pressed.connect(_gift)
	_wash_btn = UiKit.make_button(panel, Vector2(220, 758), Vector2(190, 48), "洗 白", 21)
	_wash_btn.pressed.connect(_wash)
	_appease_btn = UiKit.make_button(panel, Vector2(420, 758), Vector2(190, 48), "赔 礼", 21)
	_appease_btn.pressed.connect(_appease)
	_msg_lb = UiKit.make_label(panel, Vector2(40, 808), Vector2(560, 58), 20, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_war_btn = UiKit.make_button(panel, Vector2(500, 20), Vector2(110, 36), "战 报", 20)
	_war_btn.pressed.connect(_open_war)
	_epi_btn = UiKit.make_button(panel, Vector2(380, 20), Vector2(110, 36), "后 记", 20)
	_epi_btn.pressed.connect(_open_epi)
	_war_table_btn = UiKit.make_button(panel, Vector2(260, 20), Vector2(110, 36), "战 线", 20)
	_war_table_btn.pressed.connect(_open_war_table)
	_close_btn = UiKit.make_button(panel, Vector2(220, 878), Vector2(200, 48), "关 闭", 24)
	_close_btn.pressed.connect(close)
	visible = false

func _section(title: String, y: float) -> Label:
	var t := UiKit.make_label(_panel_parent(), Vector2(40, y), Vector2(560, 30), 26, UiKit.SEAL)
	UiKit.set_text(t, title)
	var lb := UiKit.make_label(_panel_parent(), Vector2(40, y + 34), Vector2(560, 100), 21, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.76))
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lb

func _panel_parent() -> Node:
	# 题目/正文都挂在同一张纸板上；_ready 里第一张 Panel 即父级。
	for c in get_children():
		if c is ColorRect:
			for p in c.get_children():
				if p is Panel:
					return p
	return self

func open(info: Dictionary) -> void:
	_last_info = info
	var subtxt := "货郎 · 山门 · 凶物 · 此方世界"
	if GS.story_title != "":
		subtxt += " · " + GS.story_title
	_sub_lb.text = subtxt
	var d := int(round(minf(0.2, float(GS.merchant_favor) * 0.002) * 100.0))
	_dealer_lb.text = "人情 " + str(GS.merchant_favor) + "/100 · 价 -" + str(d) + "%\n通缉 " + str(GS.wanted) + "/5 · " + ("暂不做你生意" if GS.wanted > 0 else "照常做生意")
	var sect := ""
	if GS.sect_betrayed:
		sect = "已叛门 · 山门已封（可赔礼 500 两）"
	elif GS.sect_joined:
		var rank := "外门弟子"
		if GS.sect_contrib >= 250:
			rank = "真传弟子"
		elif GS.sect_contrib >= 100:
			rank = "内门弟子"
		sect = rank + " · 贡献 " + str(GS.sect_contrib)
	else:
		sect = "尚未入门"
	sect += "\n好感 " + str(GS.sect_favor) + "/60 · 声望 " + str(GS.sect_rep) + "/60 · 考验 " + ("过" if GS.sect_test else "未过")
	if GS.wanted > 0:
		sect += "\n通缉在身：山门不纳"
	else:
		sect += "\n山门可入"
	_sect_lb.text = sect
	var bl := ""
	for n in ["山君", "夜叉", "老妖", "雪魈"]:
		bl += n + "：" + ("已首杀 · 弱点已识破" if GS.boss_kills.has(n) else "未首杀") + "\n"
	_boss_lb.text = bl.strip_edges()
	var rw: String = str(["未动", "已破", "青岚控制"][clampi(GS.red_water, 0, 2)])
	if GS.red_water == 2:
		var disc := 8 if GS.red_water_market else 5
		rw += "（货郎价 -" + str(disc) + "%" + (" · 寨墙" if GS.red_water_wall else "") + (" · 驻军" if GS.red_water_garrison else "") + (" · 税所" if GS.red_water_taxpost else "") + "）"
		rw += " · 战线 " + str(GS.war_score) + (" · 已平" if GS.red_water_peace else "")
	var last_war := ""
	if not GS.war_notes.is_empty():
		last_war = "\n战报：" + str(GS.war_notes[GS.war_notes.size() - 1])
	_war_btn.visible = not GS.war_notes.is_empty()
	_war_btn.text = "战报 " + str(GS.war_notes.size())
	var next_p := GS.prosperity_need(mini(5, GS.world_tier + 1)) if GS.world_tier < 5 else GS.world_prosperity
	_world_lb.text = "世界档 " + str(GS.world_tier) + " · 繁荣 " + str(GS.world_prosperity) + "/" + str(next_p) + " · 区块 " + str(GS.REGION_NAMES[GS.current_region]) + " · 声望 " + str(GS.region_rep[clampi(GS.current_region, 0, 4)]) + "\n赤水寨：" + str(rw) + "\n听雨楼：名声 " + str(GS.broker_rep) + "/100 · " + GS.broker_rank_name() + "\n本图 Boss：" + str(info.get("boss", "凶物")) + "（" + str(info.get("boss_state", "未动")) + "）" + last_war
	_gift_btn.disabled = GS.merchant_favor >= 100 or GS.coin("silver") < 50
	var wash_cost := 80 * GS.wanted
	_wash_btn.visible = GS.wanted > 0
	_wash_btn.text = "洗白（" + str(wash_cost) + " 两）"
	_wash_btn.disabled = GS.coin("silver") < wash_cost
	_appease_btn.visible = GS.sect_betrayed
	_appease_btn.text = "赔礼（500 两）"
	_appease_btn.disabled = GS.coin("silver") < 500
	visible = true

func _open_war() -> void:
	if _war_panel == null:
		var wp = WarReportPanel.new()
		wp.connect("closed", _on_war_closed)
		add_child(wp)
		_war_panel = wp
	_war_panel.call("open")
	if _close_btn != null:
		_close_btn.visible = false

func _on_war_closed() -> void:
	if _close_btn != null:
		_close_btn.visible = true

func _open_war_table() -> void:
	if _war_table_panel == null:
		var wt = WarTablePanel.new()
		wt.connect("closed", _on_war_table_closed)
		add_child(wt)
		_war_table_panel = wt
	_war_table_panel.call("open")
	if _close_btn != null:
		_close_btn.visible = false

func _on_war_table_closed() -> void:
	if _close_btn != null:
		_close_btn.visible = true

func _open_epi() -> void:
	if _epi_panel == null:
		var ep = EpiloguePanel.new()
		ep.connect("closed", _on_epi_closed)
		add_child(ep)
		_epi_panel = ep
	_epi_panel.call("open")
	if _close_btn != null:
		_close_btn.visible = false

func _on_epi_closed() -> void:
	if _close_btn != null:
		_close_btn.visible = true

func _gift() -> void:
	if GS.merchant_favor >= 100 or GS.coin("silver") < 50:
		_msg_lb.text = "礼送不出去。"
		return
	GS.add_coin("silver", -50)
	GS.merchant_favor = mini(100, GS.merchant_favor + 10)
	GS.save_game()
	_msg_lb.text = "老赵收了礼，人情 +10。"
	open(_last_info)

func _wash() -> void:
	var cost := 80 * GS.wanted
	if GS.wanted <= 0 or GS.coin("silver") < cost:
		_msg_lb.text = "洗白要 " + str(cost) + " 两——不够。"
		return
	GS.add_coin("silver", -cost)
	GS.wanted = 0
	GS.save_game()
	_msg_lb.text = "案子抹平了。通缉清零。"
	open(_last_info)

func _appease() -> void:
	if not GS.sect_betrayed or GS.coin("silver") < 500:
		_msg_lb.text = "赔礼要 500 两——不够。"
		return
	GS.add_coin("silver", -500)
	GS.sect_betrayed = false
	GS.sect_joined = false
	GS.sect_contrib = 0
	GS.sect_favor = 0
	GS.sect_rep = 0
	GS.sect_test = false
	GS.note_war("向青岚赔礼，封条揭了")
	GS.save_game()
	_msg_lb.text = "赔了礼，山门封条揭了。重走四门可再入。"
	open(_last_info)

func close() -> void:
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if _war_panel != null and _war_panel.visible:
		return
	if _epi_panel != null and _epi_panel.visible:
		return
	if _war_table_panel != null and _war_table_panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
