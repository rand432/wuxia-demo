extends Control
# v244：舆图 / 世界档——花一张舆图换一张新世界（地图重排、敌人变强、掉落变好）。
signal closed
signal changed

const UiKit := preload("res://shared/ui_kit.gd")
const Ui := preload("res://menu/menu_theme.gd")   # v245：禁用态暗金
const GS := preload("res://shared/game_state.gd")

const WORLD_NAMES := ["青岚界", "赤水界", "玄霜界", "黄泉界", "无相界"]
const LAND_NAMES := ["山多·路窄", "水多·雾重", "林密·怪多", "石多·宝多", "雪原·苦寒"]
const LAND_DESC := ["宝箱少 · 石多", "视野短 · 雾重", "怪多一只 · 草木密", "宝箱多 · 石多", "怪快 · 视野短 · 雪狼"]

var _cur_lb: Label
var _next_lb: Label
var _hint_lb: Label
var _msg_lb: Label
var _go_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.62)
	var panel := UiKit.make_paper_panel(veil, Rect2(50, 300, 620, 640))
	var psb: StyleBoxFlat = UiKit.paper_box(1.0)
	panel.add_theme_stylebox_override("panel", psb)

	var title := UiKit.make_label(panel, Vector2(0, 20), Vector2(620, 46), 34, UiKit.INK)
	UiKit.set_text(title, "舆　图")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UiKit.make_label(panel, Vector2(0, 70), Vector2(620, 24), 15, UiKit.DIM)
	UiKit.set_text(sub, "展开一张新世界；旧世界不回来")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_cur_lb = UiKit.make_label(panel, Vector2(40, 116), Vector2(540, 64), 18, UiKit.INK)
	_cur_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_lb = UiKit.make_label(panel, Vector2(40, 192), Vector2(540, 64), 18, UiKit.SEAL)
	_next_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_lb = UiKit.make_label(panel, Vector2(40, 270), Vector2(540, 54), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.65))
	_hint_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_go_btn = UiKit.make_button(panel, Vector2(170, 360), Vector2(280, 56), "展开舆图", 22)
	if Ui.SKIN == 1:
		# 禁用态别用主题灰块，改成"墨底暗金"——跟纸面金框一套
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color(0.075, 0.066, 0.060, 0.88)
		dsb.set_corner_radius_all(4)
		dsb.border_color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.22)
		dsb.set_border_width_all(1)
		_go_btn.add_theme_stylebox_override("disabled", dsb)
		_go_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.66, 0.52, 0.75))
	_go_btn.pressed.connect(_confirm)
	_msg_lb = UiKit.make_label(panel, Vector2(40, 440), Vector2(540, 54), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := UiKit.make_button(panel, Vector2(210, 520), Vector2(200, 46), "先 不 换", 18)
	back.pressed.connect(close)
	visible = false

func open() -> void:
	visible = true
	_msg_lb.text = "村里的东西不丢；换的是下一趟要进的那张图。"
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _world_name(tier: int) -> String:
	return str(WORLD_NAMES[clampi(tier - 1, 0, WORLD_NAMES.size() - 1)])

func _next_tier() -> int:
	return clampi(1 + int((GS.world_seed + 1) / 2), 1, 5)

func _refresh() -> void:
	var atlas := GS.material_count("atlas")
	var need := GS.prosperity_need(mini(5, GS.world_tier + 1)) if GS.world_tier < 5 else GS.world_prosperity
	_cur_lb.text = "当前：" + _world_name(GS.world_tier) + " · 第 " + str(GS.world_tier) + " 档 · 繁荣 " + str(GS.world_prosperity) + "/" + str(need) + "\n区块：" + str(GS.REGION_NAMES[GS.current_region]) + " · 舆图 " + str(atlas) + " 张"
	_next_lb.text = "下一世界：第 1 档 · 种 " + str(GS.world_seed + 1) + "\n繁荣 / 区块 / 一次性标记全部重置"
	_go_btn.disabled = atlas < 1
	_go_btn.text = "展开舆图（耗 1 张）" if atlas >= 1 else "没有舆图"

func _confirm() -> void:
	if GS.material_count("atlas") < 1:
		_msg_lb.text = "没有舆图了——爬塔宝箱 / 游历宝箱里会出。"
		return
	GS.add_material("atlas", -1)
	GS.world_flags.clear()
	GS.current_region = 0
	GS.region_unlocked = [true, true, true, false, false]
	GS.world_seed += 1
	GS.world_prosperity = 0
	GS.world_tier = 1
	GS.time_slot = 0
	GS.time_day = 1
	GS.slot_progress = 0
	GS.region_rep = [0, 0, 0, 0, 0]
	GS.region_seen = [false, false, false, false, false]
	GS.region_walk = [0, 0, 0, 0, 0]
	GS.merchant_stock_slot = ""
	GS.merchant_stock.clear()
	GS.npc_stock.clear()
	GS.region_landmarks.clear()
	GS.npc_budget = -1
	GS.ng_event_seen = false
	GS.ng_event_choice = -1
	GS.ng_echo_seen = false
	GS.ng_final_seen = false
	GS.ng_final_choice = -1
	GS.ng_wuxia_done = false
	GS.save_game()
	_msg_lb.text = "新世界展开：" + _world_name(GS.world_tier) + " · 第 " + str(GS.world_tier) + " 档。下一趟进图生效。"
	changed.emit()
	_refresh()
