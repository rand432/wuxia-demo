extends Control
# ============================================================
# forge_panel.gd —— 铁砧屏 V0.1
#
# 规则见 docs/锻造_设计稿.md：
#   · 五结果只在强化时掷；升阶不另掷
#   · +2%/级，+20 = +40%；升阶基础 ×1.5、强化归 0
#   · 入神：+10 触发，7 秒内最多 6 锤不碎
#   · 首锤收银两，后续按品质收锻造石；升阶 银两 + 星铁 1
#
# V0.1：先出成品入「锻造库」，四槽装备接入下一步。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const Ui := preload("res://menu/menu_theme.gd")
const ForgeData := preload("res://menu/data_forge.gd")
const ItemIcons := preload("res://shared/item_icons.gd")
const Audio := preload("res://shared/audio.gd")
const Cards := preload("res://shared/data_cards.gd")

signal closed

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const PANEL_W := 640.0
const PANEL_H := 940.0

var _panel: Panel
var _tut_overlay: Control = null
var _item_lb: Label
var _stat_lb: Label
var _res_lb: Label
var _log_lb: Label
var _bag_lb: Label
var _hammer_btn: Button
var _ascend_btn: Button
var _take_btn: Button
var _swing_fx: Control
var _spark_fx: Control
var _sparks: Array = []
var _confetti_fx: Control
var _confetti: Array = []
var _inspire_intro_t := 0.0
var _swing_t := 0.0
var _inspire_bar: ProgressBar
var _inspire_lb: Label
var _busy_block: ColorRect
var _queued_hammer := false
var _quench_panel: Panel
var _quench_name_lb: Label
var _quench_desc_lb: Label
var _quench_cost_lb: Label
var _quench_do_btn: Button
var _blank_btns: Array = []
var _grade_lbs: Array = []
var _fx_lb: Label
var _stat_fx_lb: Label
var _shake_t := 0.0
var _fx_base := Vector2.ZERO
var _stat_fx_base := Vector2.ZERO
var _hit_busy := false
var _blank_panel: Panel
var _blank_scroll: ScrollContainer
var _blank_grid: GridContainer
var _pick_mode := "weapon"
var _pick_tabs: Array = []
var _anvil: Control
var _log_lines: Array = []
var _comp_panel: Panel
var _comp_title: Label
var _comp_mode := "synthesis"
var _tab_btns: Array = []
var _comp_dim: ColorRect
var _comp_hint_lb: Label
var _comp_recipe_lb: Label
var _comp_try_btn: Button
var _comp_make_btn: Button
var _comp_page_btn: Button
var _comp_mode_btn: Button
var _comp_mat_btns := {}
var _comp_sel: Array = []
var _comp_idx := 0
var _bag_panel: Panel
var _bag_scroll: ScrollContainer
var _bag_grid: GridContainer
var _bag_cards := {}
var _bag_blink: Array = []
var _bag_from_picker := false
var _tool_panel: Panel
var _tool_grid: GridContainer
var _tool_cards := {}
var _bag_name_lb: Label
var _bag_stat_lb: Label
var _bag_price_lb: Label
var _bag_claim_btn: Button
var _bag_page_btn: Button
var _bag_sell_btn: Button
var _bag_scrap_btn: Button
var _bag_gift_btn: Button
var _bag_idx := 0
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
	var ins_it: Dictionary = GameState.forge_item
	if _inspire_intro_t > 0.0:
		_inspire_intro_t = maxf(0.0, _inspire_intro_t - d)
		if _inspire_bar != null:
			_inspire_bar.visible = false
		if _inspire_lb != null:
			_inspire_lb.visible = false
		if _inspire_intro_t <= 0.0:
			refresh()
	elif not ins_it.is_empty() and float(ins_it.get("inspired_left", 0.0)) > 0.0:
		ins_it["inspired_left"] = maxf(0.0, float(ins_it.get("inspired_left", 0.0)) - d)
		if float(ins_it.get("inspired_left", 0.0)) <= 0.0:
			_end_inspire(ins_it)
			GameState.save_game()
			refresh()
		elif _inspire_bar != null:
			_inspire_bar.visible = true
			_inspire_bar.value = float(ins_it.get("inspired_left", 0.0))
			if _inspire_lb != null:
				_inspire_lb.visible = true
				_inspire_lb.text = "入 神 · 限定时间内不会损坏"
	if _swing_t > 0.0:
		_swing_t = maxf(0.0, _swing_t - d)
		if _swing_fx != null:
			_swing_fx.visible = _swing_t > 0.0
			_swing_fx.queue_redraw()
	if not _sparks.is_empty():
		for sp_v in _sparks:
			var sp: Dictionary = sp_v
			sp["life"] = float(sp.get("life", 0.0)) - d
			sp["p"] = (sp.get("p", Vector2.ZERO) as Vector2) + (sp.get("v", Vector2.ZERO) as Vector2) * d
			sp["v"] = (sp.get("v", Vector2.ZERO) as Vector2) + Vector2(0, 460) * d
		_sparks = _sparks.filter(func(x: Dictionary) -> bool: return float(x.get("life", 0.0)) > 0.0)
		if _spark_fx != null:
			_spark_fx.queue_redraw()
	if not _confetti.is_empty():
		for cf_v in _confetti:
			var cf: Dictionary = cf_v
			cf["life"] = float(cf.get("life", 0.0)) - d
			cf["p"] = (cf.get("p", Vector2.ZERO) as Vector2) + (cf.get("v", Vector2.ZERO) as Vector2) * d
			cf["v"] = (cf.get("v", Vector2.ZERO) as Vector2) + Vector2(sin(_t * 4.0 + float(cf.get("seed", 0.0))) * 20.0, 26.0) * d
			cf["rot"] = float(cf.get("rot", 0.0)) + float(cf.get("spin", 0.0)) * d
		_confetti = _confetti.filter(func(x: Dictionary) -> bool: return float(x.get("life", 0.0)) > 0.0)
		if _confetti_fx != null:
			_confetti_fx.queue_redraw()
	if _shake_t > 0.0:
		_shake_t -= d
		var j := Vector2(randf_range(-7.0, 7.0), randf_range(-5.0, 5.0))
		if _fx_lb != null and _fx_lb.visible:
			_fx_lb.position = _fx_base + j
		if _stat_fx_lb != null and _stat_fx_lb.visible:
			_stat_fx_lb.position = _stat_fx_base + j * 0.6
		if _shake_t <= 0.0:
			if _fx_lb != null:
				_fx_lb.position = _fx_base
			if _stat_fx_lb != null:
				_stat_fx_lb.position = _stat_fx_base
	if _anvil != null:
		_anvil.queue_redraw()
	if _bag_panel != null and _bag_panel.visible:
		var a := 0.68 + 0.32 * absf(sin(_t * 4.2))
		for b_v in _bag_blink:
			var b = b_v
			if b != null and is_instance_valid(b):
				b.modulate = Color(1, 1, 1, a)

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
		psb.bg_color = Color(0.961, 0.941, 0.898, 1.0)
		psb.set_corner_radius_all(4)
		psb.border_color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.55)
		psb.set_border_width_all(2)
	else:
		psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.98)
		psb.set_corner_radius_all(14)
		psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
		psb.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", psb)
	# 本面板自己排标题/副题：不要再让主界面的换皮扫描补一条 78px 刊头把副题盖掉
	_panel.set_meta("skin_header", true)
	add_child(_panel)

	var title := _label("铁　砧", 34, INK)
	title.position = Vector2(28, 16)
	title.size = Vector2(220, 46)
	_panel.add_child(title)

	var sub := _label("选胚 · 一锤成器 · 成品库领奖", 16, Color(INK.r, INK.g, INK.b, 0.62))
	sub.position = Vector2(30, 58)
	sub.size = Vector2(380, 22)
	_panel.add_child(sub)

	_res_lb = _label("", 17, Color(INK.r, INK.g, INK.b, 0.68))
	_res_lb.position = Vector2(300, 58)
	_res_lb.size = Vector2(312, 22)
	_res_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_res_lb)

	_item_lb = _label("", 26, SEAL)
	_item_lb.position = Vector2(30, 92)
	_item_lb.size = Vector2(580, 34)
	_panel.add_child(_item_lb)

	_stat_lb = _label("", 18, Color(INK.r, INK.g, INK.b, 0.68))
	_stat_lb.position = Vector2(30, 126)
	_stat_lb.size = Vector2(580, 28)
	_panel.add_child(_stat_lb)
	_stat_fx_lb = _label("", 36, SEAL)
	_stat_fx_lb.position = Vector2(0, 192)
	_stat_fx_lb.size = Vector2(640, 52)
	_stat_fx_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_fx_lb.visible = false
	_stat_fx_lb.z_index = 12
	_panel.add_child(_stat_fx_lb)
	_fx_lb = _label("", 54, SEAL)
	_fx_lb.position = Vector2(0, 324)
	_fx_lb.size = Vector2(640, 80)
	_fx_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fx_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fx_lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.72))
	_fx_lb.add_theme_constant_override("outline_size", 5)
	_fx_lb.visible = false
	_fx_lb.z_index = 12
	_panel.add_child(_fx_lb)

	_anvil = Control.new()
	_anvil.position = Vector2(28, 160)
	_anvil.size = Vector2(584, 300)
	_anvil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anvil.draw.connect(_draw_anvil)
	_panel.add_child(_anvil)

	_hammer_btn = UiKit.make_button(_panel, Vector2(160, 470), Vector2(280, 64), "锤 一 下", 26)
	_hammer_btn.pressed.connect(_hammer)
	_take_btn = UiKit.make_button(_panel, Vector2(450, 470), Vector2(160, 64), "卸 下", 23)
	_take_btn.pressed.connect(_detach)
	_swing_fx = Control.new()
	_swing_fx.position = Vector2(290, 235)
	_swing_fx.size = Vector2(260, 220)
	_swing_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swing_fx.visible = false
	_swing_fx.draw.connect(_draw_swing)
	_panel.add_child(_swing_fx)
	_spark_fx = Control.new()
	_spark_fx.position = Vector2(280, 225)
	_spark_fx.size = Vector2(280, 220)
	_spark_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark_fx.draw.connect(_draw_sparks)
	_panel.add_child(_spark_fx)
	_confetti_fx = Control.new()
	_confetti_fx.position = Vector2.ZERO
	_confetti_fx.size = Vector2(PANEL_W, PANEL_H)
	_confetti_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confetti_fx.z_index = 14
	_confetti_fx.draw.connect(_draw_confetti)
	_panel.add_child(_confetti_fx)
	_inspire_lb = _label("", 16, Color(0.72, 0.48, 0.08))
	_inspire_lb.position = Vector2(160, 156)
	_inspire_lb.size = Vector2(300, 20)
	_inspire_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspire_lb.visible = false
	_inspire_lb.z_index = 18
	_panel.add_child(_inspire_lb)
	_inspire_bar = ProgressBar.new()
	_inspire_bar.position = Vector2(170, 178)
	_inspire_bar.size = Vector2(280, 10)
	_inspire_bar.show_percentage = false
	_inspire_bar.max_value = 7
	_inspire_bar.visible = false
	_inspire_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspire_bar.z_index = 18
	var ibg := StyleBoxFlat.new()
	ibg.bg_color = Color(0.20, 0.18, 0.16, 0.22)
	ibg.set_corner_radius_all(6)
	var ifg := StyleBoxFlat.new()
	ifg.bg_color = Color(0.86, 0.62, 0.18, 0.95)
	ifg.set_corner_radius_all(6)
	_inspire_bar.add_theme_stylebox_override("background", ibg)
	_inspire_bar.add_theme_stylebox_override("fill", ifg)
	_panel.add_child(_inspire_bar)

	# 五档成器概率条（替代原来那一大块文字日志）
	_grade_lbs = []
	for i in 5:
		var gl := Button.new()
		gl.position = Vector2(20 + i * 116, 540)
		gl.size = Vector2(108, 56)
		gl.focus_mode = Control.FOCUS_NONE
		gl.disabled = true
		gl.add_theme_font_size_override("font_size", 15)
		var gsb := StyleBoxFlat.new()
		gsb.set_corner_radius_all(6)
		gsb.bg_color = Color(0, 0, 0, 0)
		gsb.border_color = Color(0, 0, 0, 0)
		gsb.set_border_width_all(0)
		gl.add_theme_stylebox_override("normal", gsb)
		gl.add_theme_stylebox_override("disabled", gsb)
		gl.add_theme_color_override("font_color", ForgeData.outcome_col(i))
		gl.add_theme_color_override("font_disabled_color", ForgeData.outcome_col(i))
		_panel.add_child(gl)
		_grade_lbs.append(gl)

	_log_lb = _label("", 16, Color(INK.r, INK.g, INK.b, 0.74))
	_log_lb.position = Vector2(24, 604)
	_log_lb.size = Vector2(592, 56)
	_log_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_log_lb)

	_bag_lb = _label("", 15, Color(INK.r, INK.g, INK.b, 0.58))
	_bag_lb.position = Vector2(30, 832)
	_bag_lb.size = Vector2(580, 22)
	_panel.add_child(_bag_lb)

	var tab_names := ["武 器 / 装 备", "淬 火", "材料合成", "道 具", "关 闭"]
	_tab_btns = []
	for ti in tab_names.size():
		var tb := UiKit.make_button(_panel, Vector2(8 + ti * 124, 850), Vector2(118, 70), str(tab_names[ti]), 16)
		_tab_btns.append(tb)
	_tab_btns[0].pressed.connect(_open_blank_picker)
	_tab_btns[1].pressed.connect(_open_quench)
	_tab_btns[2].pressed.connect(func() -> void: _comp_open("synthesis"))
	_tab_btns[3].pressed.connect(_open_tools)
	_tab_btns[4].pressed.connect(close)
	_build_compendium()
	_build_bag()
	_build_blank_picker()
	_build_tools()
	_build_quench()
	_busy_block = ColorRect.new()
	_busy_block.position = Vector2.ZERO
	_busy_block.size = Vector2(PANEL_W, PANEL_H)
	_busy_block.color = Color(0, 0, 0, 0)
	_busy_block.mouse_filter = Control.MOUSE_FILTER_STOP
	_busy_block.z_index = 60
	_busy_block.visible = false
	_busy_block.gui_input.connect(_on_busy_input)
	_panel.add_child(_busy_block)

func _build_compendium() -> void:
	_comp_dim = ColorRect.new()
	_comp_dim.position = Vector2.ZERO
	_comp_dim.size = Vector2(PANEL_W, PANEL_H)
	_comp_dim.color = Color(0, 0, 0, 0.58)
	_comp_dim.z_index = 19
	_comp_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_comp_dim.visible = false
	_panel.add_child(_comp_dim)
	_comp_panel = Panel.new()
	_comp_panel.position = Vector2(10, 40)
	_comp_panel.size = Vector2(620, 760)
	_comp_panel.z_index = 20
	_comp_panel.visible = false
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.958, 0.938, 0.892, 1.0)
	csb.set_corner_radius_all(6)
	csb.border_color = Color(0.42, 0.33, 0.20, 0.60)
	csb.set_border_width_all(2)
	_comp_panel.add_theme_stylebox_override("panel", csb)
	_panel.add_child(_comp_panel)

	_comp_title = _label("材 料 合 成", 28, INK)
	_comp_title.position = Vector2(24, 14)
	_comp_title.size = Vector2(360, 36)
	_comp_panel.add_child(_comp_title)

	_comp_hint_lb = _label("", 15, Color(INK.r, INK.g, INK.b, 0.74))
	_comp_hint_lb.position = Vector2(24, 56)
	_comp_hint_lb.size = Vector2(570, 26)
	_comp_panel.add_child(_comp_hint_lb)

	_comp_page_btn = UiKit.make_button(_comp_panel, Vector2(444, 12), Vector2(160, 40), "下一条", 18)
	_comp_page_btn.pressed.connect(_comp_next)
	_comp_mode_btn = UiKit.make_button(_comp_panel, Vector2(444, 56), Vector2(160, 38), "图 鉴", 17)
	_comp_mode_btn.pressed.connect(_comp_mode_toggle)

	_comp_try_btn = UiKit.make_button(_comp_panel, Vector2(14, 292), Vector2(300, 60), "试 合", 23)
	_comp_try_btn.pressed.connect(_comp_try)

	_comp_recipe_lb = _label("", 17, Color(INK.r, INK.g, INK.b, 0.78))
	_comp_recipe_lb.position = Vector2(14, 94)
	_comp_recipe_lb.size = Vector2(592, 396)
	_comp_recipe_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comp_panel.add_child(_comp_recipe_lb)

	_comp_make_btn = UiKit.make_button(_comp_panel, Vector2(14, 510), Vector2(280, 60), "合 成 胚 子", 21)
	_comp_make_btn.pressed.connect(_comp_make)

	var back := UiKit.make_button(_comp_panel, Vector2(310, 510), Vector2(280, 60), "返 回", 23)
	back.pressed.connect(_comp_close)

func _build_bag() -> void:
	_bag_panel = Panel.new()
	_bag_panel.position = Vector2(30, 105)
	_bag_panel.size = Vector2(580, 720)
	_bag_panel.z_index = 20
	_bag_panel.visible = false
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.958, 0.938, 0.892, 1.0)
	bsb.set_corner_radius_all(6)
	bsb.border_color = Color(0.42, 0.33, 0.20, 0.60)
	bsb.set_border_width_all(2)
	_bag_panel.add_theme_stylebox_override("panel", bsb)
	_panel.add_child(_bag_panel)

	var t := _label("成 品 库", 26, INK)
	t.position = Vector2(22, 14)
	t.size = Vector2(240, 34)
	_bag_panel.add_child(t)
	var tip := _label("造过的兵器才会亮；点亮的卡可领一次奖励。", 16, Color(INK.r, INK.g, INK.b, 0.58))
	tip.position = Vector2(22, 50)
	tip.size = Vector2(530, 24)
	_bag_panel.add_child(tip)

	_bag_scroll = ScrollContainer.new()
	_bag_scroll.position = Vector2(12, 82)
	_bag_scroll.size = Vector2(556, 540)
	_bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bag_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_bag_scroll.get_v_scroll_bar().modulate.a = 0.30
	_bag_panel.add_child(_bag_scroll)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 3
	_bag_grid.add_theme_constant_override("h_separation", 10)
	_bag_grid.add_theme_constant_override("v_separation", 10)
	_bag_grid.custom_minimum_size = Vector2(536, 0)
	_bag_scroll.add_child(_bag_grid)

	var back := UiKit.make_button(_bag_panel, Vector2(210, 648), Vector2(160, 48), "返 回", 22)
	back.pressed.connect(_bag_close)

func _build_blank_picker() -> void:
	_blank_panel = Panel.new()
	_blank_panel.position = Vector2(35, 115)
	_blank_panel.size = Vector2(570, 690)
	_blank_panel.z_index = 20
	_blank_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.958, 0.938, 0.892, 1.0)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.42, 0.33, 0.20, 0.60)
	sb.set_border_width_all(2)
	_blank_panel.add_theme_stylebox_override("panel", sb)
	_panel.add_child(_blank_panel)
	var t := _label("武 器 / 装 备", 26, INK)
	t.position = Vector2(22, 14)
	t.size = Vector2(300, 34)
	_blank_panel.add_child(t)
	var tip := _label("选可强化的成品，或选一块胚子开炉", 16, Color(INK.r, INK.g, INK.b, 0.58))
	tip.position = Vector2(22, 92)
	tip.size = Vector2(520, 24)
	_blank_panel.add_child(tip)
	_pick_tabs = []
	var pick_names := ["武 器", "装 备", "胚 子", "成品库"]
	for pi in pick_names.size():
		var pb := UiKit.make_button(_blank_panel, Vector2(20 + pi * 136, 48), Vector2(128, 38), str(pick_names[pi]), 17)
		_pick_tabs.append(pb)
	_pick_tabs[0].pressed.connect(_show_pick.bind("weapon"))
	_pick_tabs[1].pressed.connect(_show_pick.bind("gear"))
	_pick_tabs[2].pressed.connect(_show_pick.bind("blank"))
	_pick_tabs[3].pressed.connect(_bag_pick_open)
	_blank_scroll = ScrollContainer.new()
	_blank_scroll.position = Vector2(12, 124)
	_blank_scroll.size = Vector2(546, 480)
	_blank_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_blank_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_blank_scroll.get_v_scroll_bar().modulate.a = 0.30
	_blank_panel.add_child(_blank_scroll)
	_blank_grid = GridContainer.new()
	_blank_grid.columns = 3
	_blank_grid.add_theme_constant_override("h_separation", 10)
	_blank_grid.add_theme_constant_override("v_separation", 10)
	_blank_grid.custom_minimum_size = Vector2(526, 0)
	_blank_scroll.add_child(_blank_grid)
	_blank_btns = []
	var back := UiKit.make_button(_blank_panel, Vector2(205, 624), Vector2(160, 48), "返 回", 22)
	back.pressed.connect(func() -> void: _blank_panel.visible = false)

func _open_blank_picker() -> void:
	if _comp_panel != null:
		_comp_panel.visible = false
	if _bag_panel != null:
		_bag_panel.visible = false
	_blank_panel.visible = true
	_show_pick("weapon")

func _pick_card(tex: Texture2D, text: String, enabled: bool, cb: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(164, 192)
	btn.focus_mode = Control.FOCUS_NONE
	btn.expand_icon = true
	btn.clip_text = true
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_constant_override("icon_max_width", 72)
	btn.icon = tex
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(8)
	st.bg_color = Color(0.94, 0.91, 0.84, 0.95)
	st.border_color = Color(0.42, 0.33, 0.20, 0.55)
	st.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_stylebox_override("disabled", st)
	btn.add_theme_color_override("font_color", INK)
	btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.32, 0.28, 0.55))
	btn.text = text
	btn.disabled = not enabled
	btn.pressed.connect(cb)
	_blank_grid.add_child(btn)
	return btn

func _all_equip_sets() -> Array:
	var out: Array = []
	var seen := {}
	for s_v in Cards.SETS:
		var sid := str((s_v as Dictionary).get("id", ""))
		seen[sid] = true
		out.append(s_v)
	for fid_v in Cards.FORGED_SETS.keys():
		var fsid := str(fid_v)
		if seen.has(fsid):
			continue
		out.append(Cards.FORGED_SETS[fid_v])
	return out

func _show_pick(mode: String) -> void:
	_pick_mode = mode
	for c in _blank_grid.get_children():
		c.queue_free()
	var busy := not (GameState.forge_item as Dictionary).is_empty()
	if mode == "weapon":
		var any := false
		for i in range(GameState.forge_bag.size() - 1, -1, -1):
			var rec: Dictionary = GameState.forge_bag[i]
			var sid := str(rec.get("sid", ""))
			if sid == "" or str(rec.get("pool", "weapon")) != "weapon":
				continue
			any = true
			var nm := str(rec.get("weapon", "兵器"))
			var tex := ItemIcons.for_pool("weapon", str(rec.get("kind", "sword")), sid)
			var rs := ForgeData.item_stats(rec)
			var txt := nm + " +" + str(int(rec.get("enhance", 0))) + "\n" + ("攻 " + str(int(rs["atk"])) if rs.has("atk") else ("防 " + str(int(rs.get("def", 0)))))
			var pb := _pick_card(tex, txt, not busy, _retrieve_weapon.bind(sid))
			pb.tooltip_text = ForgeData.item_name(rec)
		for s_v in _all_equip_sets():
			var s: Dictionary = s_v
			var sid3 := str(s.get("id", ""))
			if str(s.get("pool", "")) != "weapon" or sid3 == "" or GameState.vault_item_count(sid3) <= 0:
				continue
			var in_bag := false
			for rec_v2 in GameState.forge_bag:
				if str((rec_v2 as Dictionary).get("sid", "")) == sid3:
					in_bag = true
					break
			if in_bag:
				continue
			any = true
			var st3: Dictionary = s.get("item_stats", {})
			var txt4 := Cards.name_of(sid3) + "\n" + ("攻 " + str(int(st3.get("atk", 0))) if st3.has("atk") else ("防 " + str(int(st3.get("def", 0)))))
			var pb4 := _pick_card(ItemIcons.for_pool("weapon", str(s.get("weapon", "sword")), sid3), txt4, not busy, _retrieve_vault.bind(sid3))
			pb4.tooltip_text = Cards.item_name(sid3)
		if not any:
			_blank_grid.add_child(_label("还没有可强化的兵器。", 18, Color(INK.r, INK.g, INK.b, 0.55)))
		return
	if mode == "gear":
		var any2 := false
		for i in range(GameState.forge_bag.size() - 1, -1, -1):
			var rec2: Dictionary = GameState.forge_bag[i]
			var sid2 := str(rec2.get("sid", ""))
			if sid2 == "" or str(rec2.get("pool", "weapon")) == "weapon":
				continue
			any2 = true
			var rs2 := ForgeData.item_stats(rec2)
			var txt3 := str(rec2.get("weapon", "装备")) + " +" + str(int(rec2.get("enhance", 0))) + "\n防 " + str(int(rs2.get("def", 0))) + " · 血 " + str(int(rs2.get("hp", 0)))
			var pb3 := _pick_card(ItemIcons.for_pool(str(rec2.get("pool", "armor")), str(rec2.get("kind", "armor")), sid2), txt3, not busy, _retrieve_weapon.bind(sid2))
			pb3.tooltip_text = ForgeData.item_name(rec2)
		for s_v2 in _all_equip_sets():
			var s2: Dictionary = s_v2
			var sid4 := str(s2.get("id", ""))
			var pool4 := str(s2.get("pool", ""))
			if pool4 == "weapon" or pool4 == "arts" or sid4 == "" or GameState.vault_item_count(sid4) <= 0:
				continue
			var in_bag2 := false
			for rec_v3 in GameState.forge_bag:
				if str((rec_v3 as Dictionary).get("sid", "")) == sid4:
					in_bag2 = true
					break
			if in_bag2:
				continue
			any2 = true
			var st4: Dictionary = s2.get("item_stats", {})
			var txt5 := Cards.name_of(sid4) + "\n防 " + str(int(st4.get("def", 0))) + " · 血 " + str(int(st4.get("hp", 0)))
			var pb5 := _pick_card(ItemIcons.for_pool(pool4, str(s2.get("weapon", "armor")), sid4), txt5, not busy, _retrieve_vault.bind(sid4))
			pb5.tooltip_text = Cards.item_name(sid4)
		if not any2:
			_blank_grid.add_child(_label("还没有可强化的装备。", 18, Color(INK.r, INK.g, INK.b, 0.55)))
		return
	for i in range(GameState.forge_trait_blanks.size() - 1, -1, -1):
		var tb: Dictionary = GameState.forge_trait_blanks[i]
		var tb_blank := str(tb.get("blank", "gen_fan"))
		var tb_trait := str(tb.get("trait", ""))
		var tb_td := ForgeData.quench_trait(tb_trait)
		if tb_td.is_empty():
			continue
		var tbd := ForgeData.blank(tb_blank)
		var ttxt := str(tbd.get("name", "胚子")) + "\n" + str(tb_td.get("name", "特性"))
		var tpb := _pick_card(ItemIcons.for_pool("weapon", str(tbd.get("kind", "sword")), tb_blank), ttxt, not busy, _use_trait_blank.bind(i))
		tpb.tooltip_text = "带特性胚子：" + str(tb_td.get("desc", ""))
	for b_v in ForgeData.BLANKS:
		var b: Dictionary = b_v
		if str(b.get("pool", "weapon")) != "weapon":
			continue
		var bid := str(b.get("id", ""))
		var nm2 := str(b.get("name", bid))
		var qn := ForgeData.quality_name(int(b.get("quality", 0)))
		var own := GameState.material_count(bid) > 0
		var can := own and not busy
		var txt2 := nm2 + (" ×" + str(GameState.material_count(bid)) if own else "") + "\n" + qn
		var pb2 := _pick_card(ItemIcons.for_pool("weapon", str(b.get("kind", "sword")), bid), txt2, can, _pick_blank.bind(bid))
		pb2.tooltip_text = ("点击开炉" if own else "去材料合成")

func _retrieve_vault(sid: String) -> void:
	if not (GameState.forge_item as Dictionary).is_empty():
		_push_log("先收下砧上这把，再换。")
		return
	if GameState.forge_wearer(sid) != "":
		_push_log("这件正装备着——先卸下再强化。")
		return
	if GameState.vault_item_count(sid) <= 0:
		_push_log("仓库里没有这一件。")
		return
	var card: Dictionary = Cards.by_id(sid)
	if card.is_empty():
		return
	var st: Dictionary = card.get("item_stats", {})
	var q := Cards.q_idx(sid)
	var pool := str(card.get("pool", "weapon"))
	var kind := str(card.get("weapon", "sword"))
	var nm := Cards.name_of(sid)
	var extra_st := {}
	for stk in st.keys():
		if str(stk) in ["atk", "dmg", "def", "hp", "dodge"]:
			continue
		extra_st[str(stk)] = st[stk]
	GameState.forge_item = {
		"sid": sid, "weapon": nm, "kind": kind, "pool": pool,
		"quality": q, "craft_grade": 2, "enhance": 0, "finished": true,
		"base_atk": float(st.get("atk", 0)), "base_dmg": float(st.get("dmg", 0)),
		"base_def": float(st.get("def", 0)), "base_hp": float(st.get("hp", 0)),
		"base_dodge": float(st.get("dodge", 0)), "base_extra": extra_st,
		"base_card": card.duplicate(true),
	}
	_queued_hammer = false
	_set_hit_busy(false)
	_blank_panel.visible = false
	GameState.save_game()
	refresh()

func _use_trait_blank(idx: int) -> void:
	if idx < 0 or idx >= GameState.forge_trait_blanks.size():
		return
	if not (GameState.forge_item as Dictionary).is_empty():
		_push_log("先收下砧上这把，再换胚子。")
		return
	var tb: Dictionary = GameState.forge_trait_blanks[idx]
	var blank_id := str(tb.get("blank", "gen_fan"))
	var trait_id := str(tb.get("trait", ""))
	if trait_id == "":
		return
	GameState.forge_trait_blanks.remove_at(idx)
	GameState.forge_item = ForgeData.make_item(blank_id)
	GameState.forge_item["quench_trait"] = trait_id
	GameState.forge_item["quench_count"] = 0
	if trait_id == "mingdao":
		GameState.forge_item["mingdao_charges"] = 2
	elif trait_id == "xifeng":
		GameState.forge_item["xifeng_charges"] = 3
	elif trait_id == "xiren":
		GameState.forge_item["mingdao_charges"] = 1
	_blank_panel.visible = false
	GameState.save_game()
	refresh()

func _retrieve_weapon(sid: String) -> void:
	if not (GameState.forge_item as Dictionary).is_empty():
		_push_log("先收下砧上这把，再换。")
		return
	var idx := -1
	var rec: Dictionary = {}
	for i in range(GameState.forge_bag.size() - 1, -1, -1):
		if str((GameState.forge_bag[i] as Dictionary).get("sid", "")) == sid:
			idx = i
			rec = (GameState.forge_bag[i] as Dictionary).duplicate(true)
			break
	if idx < 0:
		return
	if GameState.forge_wearer(sid) != "":
		_push_log("这件正装备着——先卸下再强化。")
		return
	GameState.forge_bag.remove_at(idx)
	GameState.forge_item = rec
	GameState.forge_item["finished"] = true
	_queued_hammer = false
	_set_hit_busy(false)
	_blank_panel.visible = false
	GameState.save_game()
	refresh()

func _pick_blank(bid: String) -> void:
	_blank_panel.visible = false
	_open_blank(bid)

func _label(text: String, fs: int, col: Color) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", fs)
	lb.add_theme_color_override("font_color", col)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lb

# ============================================================
# 画铁砧 / 剑胚
# ============================================================
func _play_hammer_sfx() -> void:
	Audio.sfx("swing", -13.0, randf_range(0.88, 0.96))
	await get_tree().create_timer(0.55).timeout
	Audio.sfx("hit_heavy", -6.0, randf_range(0.76, 0.86))
	Audio.sfx("wood_down", -10.0, randf_range(0.68, 0.76))
	_spawn_sparks()

func _start_inspire_celebration() -> void:
	_inspire_intro_t = 1.0
	_confetti.clear()
	var cols := [Color("#d84a3a"), Color("#e8b23a"), Color("#4a9a62"), Color("#4a7ab8"), Color("#c46a9a"), Color("#f0e0b0")]
	for i in 58:
		var c: Color = cols[randi() % cols.size()]
		_confetti.append({
			"p": Vector2(randf_range(0.0, PANEL_W), randf_range(-80.0, 260.0)),
			"v": Vector2(randf_range(-55.0, 55.0), randf_range(90.0, 210.0)),
			"rot": randf_range(0.0, TAU),
			"spin": randf_range(-5.0, 5.0),
			"w": randf_range(7.0, 15.0),
			"h": randf_range(3.0, 7.0),
			"life": randf_range(1.1, 1.8),
			"seed": randf_range(0.0, 10.0),
			"col": c,
		})
	if _confetti_fx != null:
		_confetti_fx.queue_redraw()

func _draw_confetti() -> void:
	if _confetti_fx == null:
		return
	for cf_v in _confetti:
		var cf: Dictionary = cf_v
		var p: Vector2 = cf.get("p", Vector2.ZERO)
		var a := clampf(float(cf.get("life", 0.0)) / 1.8, 0.0, 1.0)
		var col: Color = cf.get("col", Color.WHITE)
		_confetti_fx.draw_set_transform(p, float(cf.get("rot", 0.0)), Vector2.ONE)
		_confetti_fx.draw_rect(Rect2(Vector2(-float(cf.get("w", 8.0)) * 0.5, -float(cf.get("h", 4.0)) * 0.5), Vector2(float(cf.get("w", 8.0)), float(cf.get("h", 4.0)))), Color(col.r, col.g, col.b, a))
		_confetti_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _spawn_sparks() -> void:
	_sparks.clear()
	var c := Vector2(140, 104)
	for i in 34:
		var ang := randf_range(-PI * 0.90, -PI * 0.10)
		var spd := randf_range(140.0, 340.0)
		_sparks.append({
			"p": c + Vector2(randf_range(-22.0, 22.0), randf_range(-8.0, 8.0)),
			"v": Vector2(cos(ang), sin(ang)) * spd,
			"life": randf_range(0.70, 1.35),
			"max": 1.35,
		})
	if _spark_fx != null:
		_spark_fx.queue_redraw()

func _draw_sparks() -> void:
	if _spark_fx == null:
		return
	for sp_v in _sparks:
		var sp: Dictionary = sp_v
		var p: Vector2 = sp.get("p", Vector2.ZERO)
		var v: Vector2 = sp.get("v", Vector2.ZERO)
		var a := clampf(float(sp.get("life", 0.0)) / float(sp.get("max", 0.62)), 0.0, 1.0)
		_spark_fx.draw_line(p, p - v * 0.045, Color(1.0, 0.68, 0.16, a * 0.85), 2.4)
		_spark_fx.draw_circle(p, 1.6 + a * 1.8, Color(1.0, 0.93, 0.55, a))

func _draw_swing() -> void:
	if _swing_fx == null or _swing_t <= 0.0:
		return
	var phase := 1.0 - _swing_t / 1.0
	var ang := lerpf(-0.95, 0.62, clampf(phase / 0.55, 0.0, 1.0))
	if phase > 0.55:
		ang = lerpf(0.62, -0.45, clampf((phase - 0.55) / 0.45, 0.0, 1.0))
	_swing_fx.draw_set_transform(Vector2(120, 186), ang, Vector2.ONE)
	_swing_fx.draw_line(Vector2.ZERO, Vector2(0, -112), Color("#5a4024"), 15.0)
	_swing_fx.draw_line(Vector2(1, 0), Vector2(1, -108), Color("#8a6a3a"), 6.0)
	_swing_fx.draw_rect(Rect2(Vector2(-34, -142), Vector2(68, 38)), Color("#3b3b40"))
	_swing_fx.draw_rect(Rect2(Vector2(-38, -136), Vector2(76, 12)), Color("#8f9298"))
	_swing_fx.draw_rect(Rect2(Vector2(-32, -114), Vector2(64, 8)), Color("#232327"))
	_swing_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_anvil() -> void:
	if _anvil == null:
		return
	var w := _anvil.size.x
	var h := _anvil.size.y
	var cx := w * 0.5
	# 地面与退后的炉火
	_anvil.draw_circle(Vector2(80, 200), 38.0 + sin(_t * 2.1) * 3.0, Color(0.92, 0.44, 0.16, 0.07))
	_anvil.draw_circle(Vector2(80, 200), 18.0 + sin(_t * 3.3) * 2.0, Color(0.98, 0.62, 0.24, 0.10))
	# 铁砧：底座 + 砧面 + 角
	var base := PackedVector2Array([
		Vector2(cx - 92, h - 70), Vector2(cx + 92, h - 70),
		Vector2(cx + 66, h - 26), Vector2(cx - 66, h - 26),
	])
	_anvil.draw_colored_polygon(base, Color(0.145, 0.135, 0.120))
	_anvil.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 128, h - 100), Vector2(cx + 128, h - 100),
		Vector2(cx + 128, h - 72), Vector2(cx - 128, h - 72),
	]), Color(0.205, 0.192, 0.172))
	_anvil.draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 128, h - 100), Vector2(cx + 178, h - 88),
		Vector2(cx + 128, h - 72),
	]), Color(0.185, 0.172, 0.152))
	_anvil.draw_line(Vector2(cx - 128, h - 100), Vector2(cx + 128, h - 100), Color(0.48, 0.42, 0.32, 0.55), 2.0)

	var it: Dictionary = GameState.forge_item
	if it.is_empty():
		_anvil.draw_string(ThemeDB.fallback_font, Vector2(cx - 92, h - 130), "砧上无物", HORIZONTAL_ALIGNMENT_CENTER, 184.0, 18, Color(0.45, 0.38, 0.28, 0.7))
		return

	var q := clampi(int(it.get("quality", 0)), 0, 4)
	var cols := [Color("#b9b4a5"), Color("#8fb07a"), Color("#7fa3c9"), Color("#b98fc9"), Color("#d4a04a")]
	var blade: Color = cols[q]
	var inspired := float(it.get("inspired_left", 0.0)) > 0.0
	var y := h - 112.0
	if inspired:
		blade = blade.lerp(Color("#ffb347"), 0.55)
	# 剑身：横在砧上
	var x0 := cx - 168.0
	var x1 := cx + 150.0
	if inspired:
		var hue := fmod(_t * 0.22, 1.0)
		var glow := Color.from_hsv(hue, 0.62, 1.0, 0.30)
		_anvil.draw_line(Vector2(x0 - 8, y), Vector2(x1 + 8, y), glow, 22.0)
		_anvil.draw_line(Vector2(x0 - 2, y - 5), Vector2(x1 + 2, y - 5), Color.from_hsv(fmod(hue + 0.35, 1.0), 0.55, 1.0, 0.26), 10.0)
		for k in 3:
			var rr := 26.0 + float(k) * 18.0 + sin(_t * 3.0 + float(k)) * 3.0
			_anvil.draw_arc(Vector2(cx, y), rr * 1.7, 0.0, TAU, 40, Color.from_hsv(fmod(hue + float(k) * 0.18, 1.0), 0.55, 1.0, 0.18), 2.0)
	_anvil.draw_line(Vector2(x0, y), Vector2(x1, y), blade.darkened(0.35), 13.0)
	_anvil.draw_line(Vector2(x0 + 8, y - 2), Vector2(x1 - 6, y - 2), blade, 7.0)
	_anvil.draw_line(Vector2(x0 + 12, y - 4), Vector2(x1 - 18, y - 4), Color(1, 1, 1, 0.35), 2.0)
	# 护手 / 柄
	var gx := x1 - 18.0
	_anvil.draw_line(Vector2(gx, y - 22), Vector2(gx, y + 22), Color("#7a6336"), 8.0)
	_anvil.draw_line(Vector2(gx + 4, y), Vector2(gx + 64, y), Color("#3a2a1c"), 11.0)
	_anvil.draw_circle(Vector2(gx + 68, y), 7.0, Color("#9a7b3f"))
	# 强化刻度：20 小格
	var bx := cx - 160.0
	var by := h - 30.0
	for i in 20:
		var on := i < int(it.get("enhance", 0))
		var col2 := Color("#c9a64a") if on else Color(0.28, 0.24, 0.18, 0.45)
		_anvil.draw_rect(Rect2(bx + float(i) * 16.0, by, 11.0, 8.0), col2)


# ============================================================
# 操作
# ============================================================
func _open_blank(id: String) -> void:
	if not (GameState.forge_item as Dictionary).is_empty():
		_push_log("先收下砧上这把，再换新胚。")
		return
	var b: Dictionary = ForgeData.blank(id)
	if b.is_empty():
		return
	var need := str(b.get("need", ""))
	if need != "" and GameState.material_count(need) < 1:
		_push_log("没有这种胚子——先去材料合成造一块。")
		return
	if need != "":
		GameState.add_material(need, -1)
	GameState.forge_item = ForgeData.make_item(id)
	_push_log("上砧：" + str(b.get("name", "胚子")) + "（首锤另收银两）")
	GameState.save_game()
	refresh()

func _hammer() -> void:
	if _hit_busy:
		_queued_hammer = true
		return
	var it: Dictionary = GameState.forge_item
	if it.is_empty():
		_push_log("砧上无物——先挑一口胚子。")
		return
	if bool(it.get("awaiting", false)):
		_push_log("已经 +20 了——先升阶。")
		return
	if int(it.get("enhance", 0)) >= 20:
		_push_log("已经 +20 了——收下或升阶。")
		return
	var q0 := clampi(int(it.get("quality", 0)), 0, 4)
	var stone_cost := ForgeData.hammer_stones(q0)
	var first := int(it.get("craft_grade", -1)) < 0
	if first:
		var fee := ForgeData.finalize_silver(q0)
		if GameState.coin("silver") < fee:
			_push_log("首锤定型要 " + str(fee) + " 两——银两不够。")
			return
		GameState.add_coin("silver", -fee)
	var free_hit := bool(it.get("free_hammer", false))
	if free_hit:
		it.erase("free_hammer")
	else:
		if GameState.material_count("forge_stone") < stone_cost:
			_push_log("锻造石不够——这一锤要 " + str(stone_cost) + " 块。")
			return
		GameState.add_material("forge_stone", -stone_cost)
	if _swing_fx != null:
		_swing_t = 1.0
		_swing_fx.visible = true
		_swing_fx.queue_redraw()
	_play_hammer_sfx()
	_set_hit_busy(true)
	if str(it.get("blank_class", "")) == "generic" and not bool(it.get("generic_rolled", false)):
		ForgeData.randomize_generic(it)
		it["generic_rolled"] = true
		if str(it.get("quench_trait", "")).begins_with("type_"):
			it.erase("quench_trait")
	var forced_tongshen := false
	if not first and bool(it.get("tongshen_pending", false)):
		it.erase("tongshen_pending")
		it["round_inspired"] = true
		it["inspired_left"] = 10.0
		it["inspired_hits"] = 0
		it["inspire_need"] = int(it.get("enhance", 0)) + 10
		forced_tongshen = true
	var old_st := ForgeData.item_stats(it)
	if first:
		it["craft_grade"] = 2
	var outcome := _roll(it)
	it.erase("trait_next_success")
	it.erase("trait_next_guard")
	it.erase("trait_next_great")
	# 第一锤不碎：保证能定型。
	if first and outcome == 4:
		outcome = 2
	if outcome == 4 and bool(it.get("guard_break", false)):
		outcome = 2
		it.erase("guard_break")
	it.erase("boost_next")
	var mingdao_saved := false
	var mingdao_left := 0
	var guard_name := ""
	var qt_id := str(it.get("quench_trait", ""))
	if outcome == 4 and (qt_id == "mingdao" or qt_id == "xiren"):
		var max_c := 2 if qt_id == "mingdao" else 1
		var md := clampi(int(it.get("mingdao_charges", max_c)), 0, max_c)
		if md > 0:
			outcome = 2
			mingdao_left = md - 1
			it["mingdao_charges"] = mingdao_left
			it["cracks"] = 0
			it["damage_bias"] = 0
			mingdao_saved = true
			guard_name = str(ForgeData.quench_trait(qt_id).get("name", "名刀"))
			if mingdao_left <= 0:
				it.erase("quench_trait")
				it.erase("mingdao_charges")
	var huihuo_saved := false
	if outcome == 3 and bool(it.get("huihuo_ready", false)):
		outcome = 2
		it.erase("huihuo_ready")
		huihuo_saved = true
	it["enhance"] = mini(20, int(it.get("enhance", 0)) + 1)
	it["finished"] = true
	var text := ""
	if forced_tongshen:
		text += "｜通神：第二锤入神"
	if mingdao_saved:
		text += "｜" + guard_name + "护主（余 " + str(mingdao_left) + " 次）"
	if huihuo_saved:
		text += "｜回火：损伤转维持"
	if outcome == 4:
		_play_hit_fx(0, old_st, old_st)
		GameState.forge_discard(str(it.get("sid", "")))
		GameState.forge_item = {}
		_push_log("破坏——兵刃碎了")
		_queued_hammer = false
		GameState.save_game()
		await get_tree().create_timer(1.02).timeout
		_finish_hit_anim()
		return
	match outcome:
		0:
			it["craft_grade"] = mini(4, int(it.get("craft_grade", 2)) + 2)
			it["lucky_great"] = int(it.get("lucky_great", 0)) + 1
			it.erase("yangfeng_stack")
			text += "大成功！属性大增"
			if str(it.get("quench_trait", "")) == "bailian" and int(it.get("enhance", 0)) < 20:
				it["enhance"] = int(it.get("enhance", 0)) + 1
				text += "｜百炼：强化 +1"
			if str(it.get("quench_trait", "")) == "xifeng":
				var xc := clampi(int(it.get("xifeng_charges", 3)), 0, 3)
				if xc > 0:
					it["cracks"] = 0
					it["damage_bias"] = 0
					xc -= 1
					it["xifeng_charges"] = xc
					text += "｜洗锋：破坏累积清空（余 " + str(xc) + " 次）"
					if xc <= 0:
						it.erase("quench_trait")
						it.erase("xifeng_charges")
			elif str(it.get("quench_trait", "")) == "yuwei":
				it["trait_next_guard"] = true
				text += "｜余威：下一锤更稳"
			elif str(it.get("quench_trait", "")) == "jiehuo":
				it["free_hammer"] = true
				text += "｜借火：下一锤免石"
		1:
			it["craft_grade"] = mini(4, int(it.get("craft_grade", 2)) + 1)
			it["lucky_success"] = int(it.get("lucky_success", 0)) + 1
			it.erase("yangfeng_stack")
			text += "成功——属性提升"
			if str(it.get("quench_trait", "")) == "huihuo":
				it["huihuo_ready"] = true
				text += "｜回火已备"
			elif str(it.get("quench_trait", "")) == "xuhuo":
				GameState.add_material("forge_stone", 1)
				text += "｜续火：返 1 石"
		2:
			text += "维持——属性不变"
			if str(it.get("quench_trait", "")) == "yangfeng":
				it["yangfeng_stack"] = mini(2, int(it.get("yangfeng_stack", 0)) + 1)
				text += "｜养锋：成功 +8%（" + str(int(it.get("yangfeng_stack", 0))) + " 层）"
			if str(it.get("quench_trait", "")) == "jieshi":
				it["trait_next_success"] = true
				text += "｜借势：下一锤成功提高"
			elif str(it.get("quench_trait", "")) == "shouzhuo":
				GameState.add_material("forge_stone", 1)
				text += "｜守拙：返 1 石"
			elif str(it.get("quench_trait", "")) == "dieren":
				it["dieren_stack"] = mini(10, int(it.get("dieren_stack", 0)) + 1)
				text += "｜叠韧：破坏 -1%"
		3:
			it["craft_grade"] = maxi(0, int(it.get("craft_grade", 2)) - 1)
			it.erase("yangfeng_stack")
			if str(it.get("quench_trait", "")) == "chengshang":
				text += "（承伤：未增裂纹）"
			else:
				it["cracks"] = int(it.get("cracks", 0)) + 1
				it["damage_bias"] = int(it.get("damage_bias", 0)) + 1
			if str(it.get("quench_trait", "")) == "jianren":
				it["jianren_stack"] = int(it.get("jianren_stack", 0)) + 1
			elif str(it.get("quench_trait", "")) == "nifeng":
				it["trait_next_great"] = true
				text += "｜逆锋：下一锤大成功提高"
			text += "损伤——属性下降，破坏率上升"
	if float(it.get("inspired_left", 0.0)) > 0.0:
		it["inspired_hits"] = int(it.get("inspired_hits", 0)) + 1
		if int(it.get("inspired_hits", 0)) >= 6:
			_end_inspire(it)
			text += "｜入神散去"
	if int(it.get("enhance", 0)) >= int(it.get("inspire_need", 10)) and not bool(it.get("round_inspired", false)):
		it["round_inspired"] = true
		it["inspire_need"] = int(it.get("enhance", 0)) + 10
		it["inspired_left"] = 10.0 if str(it.get("quench_trait", "")) == "tongshen" else 7.0
		it["inspired_hits"] = 0
		if str(it.get("quench_trait", "")) == "dingshen":
			it["enhance"] = mini(20, int(it.get("enhance", 0)) + 1)
			text += "｜定神：强化 +1"
		_start_inspire_celebration()
		text += "｜入神——限定时间内不会损坏"
	if outcome == 0:
		var affs: Array = it.get("affixes", [])
		if affs.size() < 2 and randf() < 0.30:
			var af: Dictionary = ForgeData.random_affix(it)
			if not af.is_empty():
				affs.append(str(af["id"]))
				it["affixes"] = affs
				text += "｜出词缀：「" + str(af["name"]) + "」"
	var elem_now := _apply_element(it)
	if elem_now != "":
		text += "｜上品定型：「" + elem_now + "」属性"
	if first and qt_id == "tongshen":
		it["tongshen_pending"] = true
	GameState.forge_item = it
	if first:
		_register_anvil(it)
	else:
		_sync_anvil(it)
	var new_st := ForgeData.item_stats(it)
	_play_hit_fx(4 - outcome, old_st, new_st)
	_push_log(text)
	GameState.save_game()
	await get_tree().create_timer(1.02).timeout
	_finish_hit_anim()

func _end_inspire(it: Dictionary) -> void:
	it["inspired_left"] = 0.0
	it["inspired_hits"] = 0
	it["round_inspired"] = false
	it["inspire_need"] = int(it.get("enhance", 0)) + 10

func _roll(it: Dictionary) -> int:
	var b: Dictionary = ForgeData.blank(str(it.get("blank", "")))
	if b.is_empty():
		return 1
	if str(it.get("rule", "")) == "always_success":
		return 0 if randf() < 0.3 else 1
	var p: Array = []
	for v in (b.get("probs", [8, 45, 25, 17, 5]) as Array):
		p.append(float(v))
	if bool(it.get("boost_next", false)):
		p[0] = float(p[0]) + 15.0
		p[1] = float(p[1]) + 15.0
		p[2] = maxf(0.0, float(p[2]) - 8.0)
		p[3] = maxf(0.0, float(p[3]) - 8.0)
		p[4] = maxf(0.0, float(p[4]) - 4.0)
	var lucky := int(it.get("lucky_success", 0)) + int(it.get("lucky_great", 0)) * 2
	if lucky > 0:
		p[1] = maxf(1.0, float(p[1]) - float(lucky) * 5.0)
		p[0] = maxf(0.0, float(p[0]) - float(lucky) * 3.0)
		p[2] = float(p[2]) + float(lucky) * 4.0
		p[3] = float(p[3]) + float(lucky) * 3.0
		p[4] = float(p[4]) + float(lucky) * 1.5
	var e := float(it.get("enhance", 0))
	var cr := float(it.get("cracks", 0))
	var extra_break := e * 0.15 + cr * 2.0 + float(it.get("damage_bias", 0)) * 5.0
	var extra_dmg := e * 0.08 + cr * 1.0
	p[4] += extra_break
	p[3] += extra_dmg
	p[1] = maxf(0.0, float(p[1]) - extra_break - extra_dmg)
	if str(it.get("quench_trait", "")) == "wending":
		p[2] = float(p[2]) + 20.0
	elif str(it.get("quench_trait", "")) == "fengli":
		p[1] = float(p[1]) + 10.0
	elif str(it.get("quench_trait", "")) == "fuyuan":
		p[0] = float(p[0]) + 5.0
	elif str(it.get("quench_trait", "")) == "hufeng":
		p[4] = maxf(0.0, float(p[4]) - 3.0)
	elif str(it.get("quench_trait", "")) == "yangfeng":
		p[1] = float(p[1]) + 8.0 * float(int(it.get("yangfeng_stack", 0)))
	if str(it.get("quench_trait", "")) == "jianren":
		p[4] = maxf(0.0, float(p[4]) - float(int(it.get("jianren_stack", 0))) * 2.0)
	if bool(it.get("trait_next_success", false)):
		p[1] = float(p[1]) + 15.0
	if bool(it.get("trait_next_guard", false)):
		p[4] = maxf(0.0, float(p[4]) - 10.0)
	if bool(it.get("trait_next_great", false)):
		p[0] = float(p[0]) + 10.0
	if str(it.get("quench_trait", "")) == "dieren":
		p[4] = maxf(0.0, float(p[4]) - float(int(it.get("dieren_stack", 0))))
	if float(it.get("inspired_left", 0.0)) > 0.0:
		p[4] = 0.0
		p[0] += 8.0
		p[1] += 8.0
		p[3] = maxf(0.0, float(p[3]) - 6.0)
		p[2] = maxf(0.0, float(p[2]) - 4.0)
	var total := 0.0
	for v in p:
		total += float(v)
	if total <= 0.0:
		return 1
	var r := randf() * total
	var acc := 0.0
	for i in 5:
		acc += float(p[i])
		if r <= acc:
			return i
	return 4

func _apply_element(it: Dictionary) -> String:
	if int(it.get("quality", 0)) < 2:
		return ""
	if str(it.get("elem", "")) != "":
		return ""
	var td: Dictionary = ForgeData.quench_trait(str(it.get("quench_trait", "")))
	var e := str(td.get("elem", ""))
	if e == "":
		return ""
	it["elem"] = e
	return ForgeData.element_cn(e)

func _try_ascend(it: Dictionary) -> void:
	if int(it.get("enhance", 0)) < 20:
		return
	if int(it.get("quality", 0)) >= int(it.get("cap", 4)):
		it["awaiting"] = false
		_push_log("潜力封顶——这把停在 +20。")
		return
	var cost: Dictionary = ForgeData.ascend_cost(int(it.get("quality", 0)))
	var need_s := int(cost["silver"])
	var need_j := int(cost.get("star_iron", 1))
	if GameState.coin("silver") < need_s or GameState.material_count("star_iron") < need_j:
		it["awaiting"] = true
		_push_log("够 +20 了——升阶要 " + str(need_s) + " 两 · 星铁 " + str(need_j) + "。")
		return
	GameState.add_coin("silver", -need_s)
	GameState.add_material("star_iron", -need_j)
	it["quality"] = int(it.get("quality", 0)) + 1
	var ascended_elem := _apply_element(it)
	if ascended_elem != "":
		_push_log("上品定型：必为「" + ascended_elem + "」属性。")
	it["base_atk"] = float(it.get("base_atk", 0.0)) * 1.5
	it["base_dmg"] = float(it.get("base_dmg", 0.0)) * 1.5
	it["base_def"] = float(it.get("base_def", 0.0)) * 1.5
	it["base_hp"] = float(it.get("base_hp", 0.0)) * 1.5
	it["base_dodge"] = float(it.get("base_dodge", 0.0)) * 1.5
	var bex: Dictionary = it.get("base_extra", {})
	for bek in bex.keys():
		if typeof(bex[bek]) == TYPE_INT or typeof(bex[bek]) == TYPE_FLOAT:
			bex[bek] = float(bex[bek]) * 1.5
	it["base_extra"] = bex
	it["enhance"] = 0
	it["inspired_left"] = 0.0
	it["inspired_hits"] = 0
	it["round_inspired"] = false
	it["inspire_need"] = 10
	it.erase("tongshen_pending")
	it.erase("yangfeng_stack")
	it["awaiting"] = false
	GameState.forge_item = it
	_push_log("升阶！→ " + ForgeData.item_name(it) + "（强化归 0）")

func _ascend() -> void:
	var it: Dictionary = GameState.forge_item
	if it.is_empty():
		return
	if int(it.get("enhance", 0)) < 20:
		_push_log("还没到 +20，升不了阶。")
		return
	_try_ascend(it)
	GameState.forge_item = it
	GameState.save_game()
	refresh()

func _comp_next() -> void:
	if ForgeData.COMBOS.is_empty():
		return
	_comp_idx = (_comp_idx + 1) % ForgeData.COMBOS.size()
	_comp_refresh()

func _bag_list() -> Array:
	var out: Array = []
	for rec_v in GameState.forge_bag:
		var rec: Dictionary = rec_v
		if str(rec.get("sid", "")) != "":
			out.append(rec)
	return out

func _bag_current() -> Dictionary:
	var list := _bag_list()
	if list.is_empty():
		return {}
	_bag_idx = clampi(_bag_idx, 0, list.size() - 1)
	return list[_bag_idx]

func _bag_pick_open() -> void:
	if _comp_panel != null:
		_comp_panel.visible = false
	if _tool_panel != null:
		_tool_panel.visible = false
	if _blank_panel != null:
		_blank_panel.visible = false
	_bag_from_picker = true
	_bag_open()

func _bag_open() -> void:
	if _comp_panel != null:
		_comp_panel.visible = false
	var list := _bag_list()
	_bag_idx = maxi(0, list.size() - 1)
	_comp_dim.visible = true
	_bag_panel.visible = true
	_bag_refresh()

func _bag_close() -> void:
	if _bag_panel != null:
		_bag_panel.visible = false
	if _bag_from_picker:
		_bag_from_picker = false
		_comp_dim.visible = false
		if _blank_panel != null:
			_blank_panel.visible = true
			_show_pick("weapon")
		return
	if _comp_panel == null or not _comp_panel.visible:
		_comp_dim.visible = false

func _bag_next() -> void:
	var list := _bag_list()
	if list.is_empty():
		return
	_bag_idx = (_bag_idx + 1) % list.size()
	_bag_refresh()

func _build_quench() -> void:
	_quench_panel = Panel.new()
	_quench_panel.position = Vector2(50, 250)
	_quench_panel.size = Vector2(540, 430)
	_quench_panel.z_index = 22
	_quench_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.958, 0.938, 0.892, 1.0)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.42, 0.33, 0.20, 0.60)
	sb.set_border_width_all(2)
	_quench_panel.add_theme_stylebox_override("panel", sb)
	_panel.add_child(_quench_panel)
	var t := _label("淬 火", 28, INK)
	t.position = Vector2(24, 18)
	t.size = Vector2(260, 36)
	_quench_panel.add_child(t)
	var tip := _label("成器前可反复淬火，刷新特性；越淬越贵", 15, Color(INK.r, INK.g, INK.b, 0.58))
	tip.position = Vector2(24, 56)
	tip.size = Vector2(490, 24)
	_quench_panel.add_child(tip)
	_quench_name_lb = _label("", 26, SEAL)
	_quench_name_lb.position = Vector2(24, 104)
	_quench_name_lb.size = Vector2(490, 36)
	_quench_panel.add_child(_quench_name_lb)
	_quench_desc_lb = _label("", 18, Color(INK.r, INK.g, INK.b, 0.78))
	_quench_desc_lb.position = Vector2(24, 148)
	_quench_desc_lb.size = Vector2(490, 58)
	_quench_desc_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quench_panel.add_child(_quench_desc_lb)
	_quench_cost_lb = _label("", 18, Color(0.62, 0.47, 0.16))
	_quench_cost_lb.position = Vector2(24, 220)
	_quench_cost_lb.size = Vector2(490, 30)
	_quench_panel.add_child(_quench_cost_lb)
	_quench_do_btn = UiKit.make_button(_quench_panel, Vector2(24, 276), Vector2(240, 54), "淬 火", 22)
	_quench_do_btn.pressed.connect(_do_quench)
	var back := UiKit.make_button(_quench_panel, Vector2(292, 276), Vector2(220, 54), "返 回", 22)
	back.pressed.connect(func() -> void: _quench_panel.visible = false)

func _open_quench() -> void:
	if _blank_panel != null:
		_blank_panel.visible = false
	if _comp_panel != null:
		_comp_panel.visible = false
	if _bag_panel != null:
		_bag_panel.visible = false
	if _tool_panel != null:
		_tool_panel.visible = false
	_quench_panel.visible = true
	_quench_refresh()

func _quench_refresh() -> void:
	if _quench_panel == null or not _quench_panel.visible:
		return
	var it: Dictionary = GameState.forge_item
	if it.is_empty():
		_quench_name_lb.text = "砧上无胚"
		_quench_desc_lb.text = "先选一块胚子上砧，再淬火。"
		_quench_cost_lb.text = ""
		_quench_do_btn.disabled = true
		return
	if int(it.get("craft_grade", -1)) >= 0:
		_quench_name_lb.text = ForgeData.item_name(it)
		_quench_desc_lb.text = "已经成器定型，不能再淬火。"
		_quench_cost_lb.text = "当前特性：" + str(ForgeData.quench_trait(str(it.get("quench_trait", ""))).get("name", "无"))
		_quench_do_btn.disabled = true
		return
	var tid := str(it.get("quench_trait", ""))
	var st := ForgeData.quench_trait(tid)
	_quench_name_lb.text = "当前特性：" + (str(st.get("name", "无")) if not st.is_empty() else "无")
	_quench_desc_lb.text = str(st.get("desc", "还没有淬出特性。"))
	var n := int(it.get("quench_count", 0))
	var cost := ForgeData.quench_cost(n)
	_quench_cost_lb.text = "下一次淬火：" + str(cost) + " 两（已淬 " + str(n) + " 次）"
	_quench_do_btn.text = "淬 火（" + str(cost) + " 两）"
	_quench_do_btn.disabled = GameState.coin("silver") < cost

func _do_quench() -> void:
	var it: Dictionary = GameState.forge_item
	if it.is_empty() or int(it.get("craft_grade", -1)) >= 0:
		return
	var n := int(it.get("quench_count", 0))
	var cost := ForgeData.quench_cost(n)
	if GameState.coin("silver") < cost:
		_push_log("淬火要 " + str(cost) + " 两——银两不够。")
		return
	GameState.add_coin("silver", -cost)
	it["quench_count"] = n + 1
	it["quench_trait"] = ForgeData.roll_quench_trait()
	it["jianren_stack"] = 0
	it.erase("huihuo_ready")
	it.erase("trait_next_success")
	it.erase("trait_next_guard")
	it.erase("trait_next_great")
	it.erase("free_hammer")
	it.erase("dieren_stack")
	it.erase("yangfeng_stack")
	it.erase("tongshen_pending")
	it.erase("inspire_need")
	if str(it.get("quench_trait", "")) == "mingdao":
		it["mingdao_charges"] = 2
	elif str(it.get("quench_trait", "")) == "xiren":
		it["mingdao_charges"] = 1
	else:
		it.erase("mingdao_charges")
	if str(it.get("quench_trait", "")) == "xifeng":
		it["xifeng_charges"] = 3
	else:
		it.erase("xifeng_charges")
	GameState.forge_item = it
	GameState.save_game()
	var st := ForgeData.quench_trait(str(it["quench_trait"]))
	_push_log("淬火：" + str(st.get("name", "?")) + "（花 " + str(cost) + " 两）")
	Audio.sfx("wood_down", -11.0, 1.4)
	_quench_refresh()
	refresh()

func _build_tools() -> void:
	_tool_panel = Panel.new()
	_tool_panel.position = Vector2(30, 105)
	_tool_panel.size = Vector2(580, 720)
	_tool_panel.z_index = 20
	_tool_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.958, 0.938, 0.892, 1.0)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.42, 0.33, 0.20, 0.60)
	sb.set_border_width_all(2)
	_tool_panel.add_theme_stylebox_override("panel", sb)
	_panel.add_child(_tool_panel)
	var t := _label("锻 炉 道 具", 26, INK)
	t.position = Vector2(22, 14)
	t.size = Vector2(360, 34)
	_tool_panel.add_child(t)
	var tip := _label("点道具直接使用；只对砧上这把生效", 16, Color(INK.r, INK.g, INK.b, 0.58))
	tip.position = Vector2(22, 50)
	tip.size = Vector2(530, 24)
	_tool_panel.add_child(tip)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 82)
	scroll.size = Vector2(556, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.get_v_scroll_bar().modulate.a = 0.30
	_tool_panel.add_child(scroll)
	_tool_grid = GridContainer.new()
	_tool_grid.columns = 3
	_tool_grid.add_theme_constant_override("h_separation", 10)
	_tool_grid.add_theme_constant_override("v_separation", 10)
	_tool_grid.custom_minimum_size = Vector2(536, 0)
	scroll.add_child(_tool_grid)
	var back := UiKit.make_button(_tool_panel, Vector2(210, 648), Vector2(160, 48), "返 回", 22)
	back.pressed.connect(func() -> void: _tool_panel.visible = false)

func _open_tools() -> void:
	if _comp_panel != null:
		_comp_panel.visible = false
	if _bag_panel != null:
		_bag_panel.visible = false
	if _blank_panel != null:
		_blank_panel.visible = false
	_tool_panel.visible = true
	_tool_refresh()

func _tool_refresh() -> void:
	if _tool_panel == null or not _tool_panel.visible:
		return
	for c in _tool_grid.get_children():
		c.queue_free()
	_tool_cards.clear()
	for t_v in ForgeData.TOOLS:
		var t: Dictionary = t_v
		var tid := str(t.get("id", ""))
		var n := GameState.forge_tool_count(tid)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(164, 190)
		btn.focus_mode = Control.FOCUS_NONE
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 62)
		btn.icon = ItemIcons.for_tool(str(t.get("icon", "")))
		btn.text = str(t.get("name", tid)) + "\n×" + str(n)
		btn.add_theme_font_size_override("font_size", 18)
		btn.tooltip_text = str(t.get("desc", ""))
		var sb2 := StyleBoxFlat.new()
		sb2.set_corner_radius_all(8)
		sb2.bg_color = Color(0.94, 0.91, 0.84, 0.95)
		sb2.border_color = Color(0.42, 0.33, 0.20, 0.55)
		sb2.set_border_width_all(2)
		btn.add_theme_stylebox_override("normal", sb2)
		btn.add_theme_stylebox_override("hover", sb2)
		btn.add_theme_stylebox_override("pressed", sb2)
		btn.add_theme_stylebox_override("disabled", sb2)
		btn.add_theme_color_override("font_color", INK)
		btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.32, 0.28, 0.55))
		btn.disabled = n <= 0
		btn.pressed.connect(_use_tool.bind(tid))
		_tool_grid.add_child(btn)
		_tool_cards[tid] = btn

func _use_tool(tid: String) -> void:
	var it: Dictionary = GameState.forge_item
	if it.is_empty():
		_push_log("砧上无物——先上胚子。")
		return
	if GameState.forge_tool_count(tid) <= 0:
		_push_log("这个道具用完了。")
		return
	match tid:
		"dragon_scale":
			it["guard_break"] = true
		"regret_ink":
			it["lucky_success"] = 0
			it["lucky_great"] = 0
		"quench_oil":
			it["boost_next"] = true
		"star_sand":
			if (it.get("affixes", []) as Array).is_empty():
				_push_log("这把还没有词缀——星砂用不上。")
				return
			var affs2: Array = it.get("affixes", [])
			affs2.clear()
			var af2 := ForgeData.random_affix(it)
			if not af2.is_empty():
				affs2.append(str(af2["id"]))
			it["affixes"] = affs2
		_:
			return
	GameState.forge_tool_take(tid)
	GameState.forge_item = it
	_sync_anvil(it)
	_push_log("使用道具：" + str(ForgeData.tool_def(tid).get("name", tid)))
	GameState.save_game()
	_tool_refresh()
	refresh()

func _bag_reward_for(q0: int) -> Dictionary:
	var q := clampi(q0, 0, 4)
	return {
		"stones": [3, 5, 8, 12, 18][q],
		"silver": [20, 40, 80, 160, 320][q],
		"exp": [60, 120, 260, 520, 1000][q],
		"pill": ["tupo_fan", "tupo_fan", "tupo_liang", "tupo_shang", "tupo_jue"][q],
		"wine": q >= 2,
	}

func _bag_made_info(bid: String) -> Dictionary:
	if GameState.forge_made.has(bid):
		var v = GameState.forge_made[bid]
		if v is Dictionary:
			return {"q": int((v as Dictionary).get("q", 0)), "grade": int((v as Dictionary).get("grade", 2)), "name": str((v as Dictionary).get("name", "")), "pool": str((v as Dictionary).get("pool", "weapon")), "kind": str((v as Dictionary).get("kind", "sword"))}
		return {"q": int(v), "grade": 2}
	for rec_v in GameState.forge_bag:
		var rec: Dictionary = rec_v
		if str(rec.get("blank", "")) == bid:
			return {"q": int(rec.get("quality", 0)), "grade": int(rec.get("craft_grade", 2))}
	return {}

func _bag_claim(bid: String) -> void:
	var info := _bag_made_info(bid)
	if info.is_empty() or GameState.forge_claimed.has(bid):
		return
	var q := int(info.get("q", 0))
	var rw := _bag_reward_for(q)
	GameState.add_material("forge_stone", int(rw["stones"]))
	GameState.add_coin("silver", int(rw["silver"]))
	GameState.exp_pool += int(rw["exp"])
	var pid := str(rw["pill"])
	GameState.pills[pid] = int(GameState.pills.get(pid, 0)) + 1
	if bool(rw["wine"]):
		var wv := 20 + q * 16
		GameState.add_wine("锻礼·" + ForgeData.quality_name(q), {"color": wv, "aroma": wv + 4, "taste": wv + 2, "after": wv + 6, "body": wv}, 20 + q * 18, "成品库领的锻礼酒，不算自酿。")
	GameState.forge_claimed[bid] = true
	GameState.save_game()
	_push_log("领取成品奖励：" + ForgeData.quality_name(q) + "（锻造石 +" + str(int(rw["stones"])) + " · 银两 +" + str(int(rw["silver"])) + "）")
	_bag_reward_burst(rw)
	_bag_refresh()
	refresh()

func _bag_refresh() -> void:
	if _bag_panel == null or not _bag_panel.visible or _bag_grid == null:
		return
	for c in _bag_grid.get_children():
		c.queue_free()
	_bag_cards.clear()
	_bag_blink.clear()
	for b_v in ForgeData.BLANKS:
		var b: Dictionary = b_v
		var bid := str(b.get("id", ""))
		var info := _bag_made_info(bid)
		var made := not info.is_empty()
		var q := int(info.get("q", int(b.get("quality", 0))))
		var g := int(info.get("grade", 2))
		var claimed := GameState.forge_claimed.has(bid)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(168, 178)
		btn.focus_mode = Control.FOCUS_NONE
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 54)
		btn.icon = ItemIcons.for_pool(str(info.get("pool", b.get("pool", "weapon"))), str(info.get("kind", b.get("kind", "sword"))), bid)
		btn.add_theme_font_size_override("font_size", 17)
		var state := "locked"
		if made and not claimed:
			state = "ready"
		elif made and claimed:
			state = "claimed"
		var shown := str(info.get("name", b.get("name", "胚子")))
		var grade_txt := "" if state == "locked" else (ForgeData.grade_name(g) + " · ")
		btn.text = "◆ " + shown + "\n" + grade_txt + ForgeData.quality_name(q) + "\n" + ("未打造" if state == "locked" else ("可领取" if state == "ready" else "已领取"))
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(8)
		st.set_border_width_all(2)
		if state == "locked":
			st.bg_color = Color(0.20, 0.18, 0.16, 0.30)
			st.border_color = Color(0.35, 0.31, 0.26, 0.25)
			btn.add_theme_color_override("font_color", Color(0.35, 0.32, 0.28, 0.55))
			btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.32, 0.28, 0.55))
			btn.disabled = true
		elif state == "ready":
			st.bg_color = Color(0.22, 0.14, 0.10, 0.96)
			st.border_color = Color(0.86, 0.68, 0.24, 0.95)
			btn.add_theme_color_override("font_color", Color(0.98, 0.88, 0.54))
			btn.add_theme_color_override("font_disabled_color", Color(0.98, 0.88, 0.54))
			btn.tooltip_text = "点击领取奖励"
			btn.pressed.connect(_bag_claim.bind(bid))
			_bag_blink.append(btn)
		else:
			st.bg_color = Color(0.91, 0.86, 0.74, 0.95)
			st.border_color = Color(0.62, 0.49, 0.20, 0.75)
			btn.add_theme_color_override("font_color", Color(0.30, 0.25, 0.18))
			btn.add_theme_color_override("font_disabled_color", Color(0.30, 0.25, 0.18))
			btn.disabled = true
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", st)
		btn.add_theme_stylebox_override("pressed", st)
		btn.add_theme_stylebox_override("disabled", st)
		_bag_grid.add_child(btn)
		_bag_cards[bid] = btn

func _bag_reward_burst(rw: Dictionary) -> void:
	if _bag_panel == null:
		return
	var names := ["锻造石 +" + str(int(rw["stones"])), "银两 +" + str(int(rw["silver"])), "经验 +" + str(int(rw["exp"])), "突破丹 ×1"]
	if bool(rw["wine"]):
		names.append("锻礼酒 ×1")
	for i in names.size():
		var lb := Label.new()
		lb.text = str(names[i])
		lb.add_theme_font_size_override("font_size", 19)
		lb.add_theme_color_override("font_color", Color(0.72, 0.20, 0.15))
		lb.z_index = 30
		var p := Vector2(290, 220 + float(i) * 4)
		lb.position = p
		_bag_panel.add_child(lb)
		var tw := create_tween()
		tw.tween_property(lb, "position", p + Vector2(randf_range(-90, 90), -70 - float(i) * 12), 0.22)
		tw.tween_interval(0.16)
		tw.tween_property(lb, "position", Vector2(300, 610), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(lb, "modulate:a", 0.0, 0.42)
		tw.tween_callback(lb.queue_free)

func _bag_drop_record(sid: String) -> void:
	for i in range(GameState.forge_bag.size() - 1, -1, -1):
		var rec: Dictionary = GameState.forge_bag[i]
		if str(rec.get("sid", "")) == sid:
			GameState.forge_bag.remove_at(i)

func _bag_sell() -> void:
	var rec := _bag_current()
	if rec.is_empty():
		return
	var sid := str(rec.get("sid", ""))
	if GameState.vault_item_count(sid) <= 0:
		_push_log("这件已经装在人身上——先卸下再卖。")
		return
	var price := ForgeData.sell_price(rec)
	GameState.vault_items[sid] = GameState.vault_item_count(sid) - 1
	GameState.add_coin("silver", price)
	GameState.forge_remove(sid)
	_bag_drop_record(sid)
	_push_log("卖掉：" + ForgeData.item_name(rec) + "（+" + str(price) + " 两）")
	GameState.save_game()
	_bag_refresh()
	refresh()

func _bag_scrap() -> void:
	var rec := _bag_current()
	if rec.is_empty():
		return
	var sid := str(rec.get("sid", ""))
	if GameState.vault_item_count(sid) <= 0:
		_push_log("这件已经装在人身上——先卸下再拆。")
		return
	var ret := ForgeData.scrap_return(rec)
	GameState.vault_items[sid] = GameState.vault_item_count(sid) - 1
	GameState.add_material("forge_stone", int(ret["stones"]))
	for k_v in (ret.get("mats", {}) as Dictionary).keys():
		var k := str(k_v)
		GameState.add_material(k, int(ret["mats"][k]))
	GameState.forge_remove(sid)
	_bag_drop_record(sid)
	_push_log("拆掉：" + ForgeData.item_name(rec) + "（锻造石 +" + str(int(ret["stones"])) + "）")
	GameState.save_game()
	_bag_refresh()
	refresh()

func _bag_gift() -> void:
	var rec := _bag_current()
	if rec.is_empty():
		return
	var sid := str(rec.get("sid", ""))
	if GameState.vault_item_count(sid) <= 0:
		_push_log("这件已经装在人身上了。")
		return
	var target := "player"
	var tname := "自己"
	if GameState.disciple_joined:
		target = "chen_shi"
		tname = "陈石"
	elif GameState.qingluan_joined:
		target = "qingluan"
		tname = "苏青鸾"
	var msg := GameState.equip_weapon(target, sid)
	_push_log("送" + tname + "：" + msg)
	GameState.save_game()
	_bag_refresh()
	refresh()

func _comp_open(mode := "synthesis") -> void:
	_comp_mode = mode
	if _blank_panel != null:
		_blank_panel.visible = false
	if _tool_panel != null:
		_tool_panel.visible = false
	if _comp_mode_btn != null:
		_comp_mode_btn.text = "图 鉴" if mode == "synthesis" else "合 成"
	if _bag_panel != null:
		_bag_panel.visible = false
	_comp_dim.visible = true
	_comp_panel.visible = true
	var synth := mode == "synthesis"
	_comp_title.text = "材 料 合 成" if synth else "锻 造 图 鉴"
	for k_v in _comp_mat_btns.keys():
		(_comp_mat_btns[k_v] as Button).visible = synth
	if _comp_mode_btn != null:
		_comp_mode_btn.visible = true
	_comp_try_btn.visible = false
	if not synth:
		_comp_make_btn.visible = false
	_comp_refresh()

func _tab_main() -> void:
	_comp_close()
	if _bag_panel != null:
		_bag_panel.visible = false
	refresh()

func _comp_mode_toggle() -> void:
	_comp_open("codex" if _comp_mode == "synthesis" else "synthesis")

func _comp_close() -> void:
	if _comp_panel != null:
		_comp_panel.visible = false
	if _comp_dim != null:
		_comp_dim.visible = false

func _comp_toggle(k: String) -> void:
	var b: Button = _comp_mat_btns.get(k)
	if b == null:
		return
	if b.button_pressed:
		if not _comp_sel.has(k):
			_comp_sel.append(k)
			if _comp_sel.size() > 2:
				var drop := str(_comp_sel.pop_front())
				var db: Button = _comp_mat_btns.get(drop)
				if db != null:
					db.button_pressed = false
	else:
		_comp_sel.erase(k)
	_comp_refresh()

func _comp_try() -> void:
	if GameState.material_count("forge_stone") < ForgeData.TRIAL_STONES:
		_push_log("试合要 " + str(ForgeData.TRIAL_STONES) + " 锻造石——不够。")
		return
	GameState.add_material("forge_stone", -ForgeData.TRIAL_STONES)
	var c: Dictionary = ForgeData.combo_by_trial(_comp_sel)
	if c.is_empty():
		_push_log("没合中——只亏 " + str(ForgeData.TRIAL_STONES) + " 锻造石，材料没动。")
	else:
		GameState.forge_compendium[str(c["id"])] = true
		_comp_idx = ForgeData.combo_index(str(c["id"]))
		_push_log("合中！图鉴 +1：「" + str(c["name"]) + "」")
	GameState.save_game()
	refresh()

func _comp_make() -> void:
	var c: Dictionary = ForgeData.COMBOS[_comp_idx]
	if not (GameState.forge_item as Dictionary).is_empty():
		_push_log("先收下砧上这把，再照图鉴造胚。")
		return
	var cost: Dictionary = c.get("cost", {})
	for k_v in cost.keys():
		var k := str(k_v)
		if GameState.material_count(k) < int(cost[k]):
			_push_log("材料不够：" + GameState.mat_name(k) + " " + str(GameState.material_count(k)) + "/" + str(int(cost[k])))
			return
	for k_v in cost.keys():
		var k := str(k_v)
		GameState.add_material(k, -int(cost[k]))
	GameState.forge_item = ForgeData.make_item(str(c["blank"]))
	_push_log("造胚：「" + str(c["name"]) + "」已上砧。")
	GameState.save_game()
	_comp_close()
	refresh()

func _comp_refresh() -> void:
	if _comp_panel == null or not _comp_panel.visible:
		return
	if ForgeData.COMBOS.is_empty():
		return
	_comp_idx = clampi(_comp_idx, 0, ForgeData.COMBOS.size() - 1)
	var c: Dictionary = ForgeData.COMBOS[_comp_idx]
	for k_v in _comp_mat_btns.keys():
		var k := str(k_v)
		var b: Button = _comp_mat_btns[k]
		b.text = GameState.mat_name(k) + " " + str(GameState.material_count(k))
		b.visible = _comp_mode == "synthesis"
		b.disabled = true
	_comp_page_btn.text = "下一条 " + str(_comp_idx + 1) + "/" + str(ForgeData.COMBOS.size())
	_comp_hint_lb.text = "配方：" + str(c["name"]) + " · " + str(c["hint"])
	var cost: Dictionary = c.get("cost", {})
	var req_lines: Array = []
	var can_make := true
	for k_v in cost.keys():
		var k := str(k_v)
		var need := int(cost[k])
		var have := GameState.material_count(k)
		if have < need:
			can_make = false
		req_lines.append(("✓" if have >= need else "×") + " " + GameState.mat_name(k) + "　" + str(have) + " / " + str(need))
	_comp_recipe_lb.text = "「" + str(c["name"]) + "」\n\n合成需求：\n" + "\n".join(PackedStringArray(req_lines)) + "\n\n材料够就直接上砧。"
	_comp_make_btn.visible = _comp_mode == "synthesis"
	_comp_try_btn.visible = false
	_comp_make_btn.disabled = not can_make or not (GameState.forge_item as Dictionary).is_empty()
	_comp_make_btn.text = "合 成 胚 子"

func _set_hit_busy(v: bool) -> void:
	_hit_busy = v
	if _busy_block != null:
		_busy_block.visible = v
	if _take_btn != null:
		_take_btn.disabled = v
	if _hammer_btn != null and v:
		_hammer_btn.disabled = true

func _on_busy_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if not pressed:
		return
	var gp := get_global_mouse_position()
	if _hammer_btn != null and _hammer_btn.get_global_rect().has_point(gp):
		_queued_hammer = true
		accept_event()

func _finish_hit_anim() -> void:
	_set_hit_busy(false)
	refresh()
	if _queued_hammer:
		_queued_hammer = false
		call_deferred("_hammer")

func _play_hit_fx(outcome: int, old_st: Dictionary, new_st: Dictionary) -> void:
	_set_hit_busy(true)
	var gc := ForgeData.outcome_col(outcome)
	_fx_lb.text = ForgeData.outcome_name(outcome) + "！"
	_fx_lb.add_theme_color_override("font_color", gc)
	_fx_base = Vector2(0, 324)
	_fx_lb.position = _fx_base
	_fx_lb.visible = true
	_fx_lb.scale = Vector2(1.75, 1.75)
	_fx_lb.pivot_offset = Vector2(320, 40)
	_stat_fx_base = Vector2(0, 192)
	if new_st.has("atk"):
		_stat_fx_lb.text = "攻击 " + str(int(old_st.get("atk", 0))) + "  →  " + str(int(new_st.get("atk", 0)))
	else:
		_stat_fx_lb.text = "防御 " + str(int(old_st.get("def", 0))) + "  →  " + str(int(new_st.get("def", 0)))
	_stat_fx_lb.position = _stat_fx_base
	_stat_fx_lb.visible = true
	_stat_fx_lb.scale = Vector2(1.45, 1.45)
	_stat_fx_lb.pivot_offset = Vector2(320, 26)
	_shake_t = 0.38
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_fx_lb, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stat_fx_lb, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(0.38)
	tw.tween_property(_fx_lb, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(_stat_fx_lb, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func() -> void:
		_fx_lb.visible = false
		_stat_fx_lb.visible = false
		_fx_lb.modulate.a = 1.0
		_stat_fx_lb.modulate.a = 1.0
	)

func _register_anvil(it: Dictionary) -> void:
	var old_sid := str(it.get("sid", ""))
	if old_sid != "":
		if bool(it.get("vault_out", false)) or GameState.vault_item_count(old_sid) <= 0:
			GameState.vault_add_item(old_sid, 1)
			it.erase("vault_out")
		var in_bag := false
		for rec_v in GameState.forge_bag:
			if str((rec_v as Dictionary).get("sid", "")) == old_sid:
				in_bag = true
				break
		if not in_bag:
			GameState.forge_bag.append(it.duplicate(true))
		GameState.save_game()
		return
	var sid := GameState.forge_next_sid()
	var set := ForgeData.card_set(it, sid)
	GameState.forge_add(sid, set)
	it["sid"] = sid
	GameState.forge_bag.append(it.duplicate(true))
	if GameState.forge_bag.size() > 40:
		GameState.forge_bag.pop_front()
	var bid := str(it.get("blank", ""))
	if bid != "":
		GameState.forge_made[bid] = {"q": int(it.get("quality", 0)), "grade": int(it.get("craft_grade", 2)), "name": ForgeData.item_name(it), "pool": str(it.get("pool", "weapon")), "kind": str(it.get("kind", "sword"))}
	GameState.save_game()

func _sync_anvil(it: Dictionary) -> void:
	var sid := str(it.get("sid", ""))
	if sid == "":
		return
	var set := ForgeData.card_set(it, sid)
	GameState.forge_update(sid, it, set)
	var bid := str(it.get("blank", ""))
	if bid != "":
		GameState.forge_made[bid] = {"q": int(it.get("quality", 0)), "grade": int(it.get("craft_grade", 2)), "name": ForgeData.item_name(it), "pool": str(it.get("pool", "weapon")), "kind": str(it.get("kind", "sword"))}
	GameState.save_game()

func _detach() -> void:
	var it: Dictionary = GameState.forge_item
	if it.is_empty():
		return
	var nm := ForgeData.item_name(it)
	_register_anvil(it)
	GameState.forge_item = {}
	_queued_hammer = false
	_set_hit_busy(false)
	_push_log("卸下：" + nm + "（在仓库里，可装备）")
	GameState.save_game()
	refresh()

func _auto_collect(it: Dictionary) -> void:
	if it.is_empty():
		return
	var nm := ForgeData.item_name(it)
	var sid := GameState.forge_next_sid()
	var set := ForgeData.card_set(it, sid)
	GameState.forge_add(sid, set)
	it["sid"] = sid
	GameState.forge_bag.append(it.duplicate(true))
	var bid := str(it.get("blank", ""))
	if bid != "":
		GameState.forge_made[bid] = {"q": int(it.get("quality", 0)), "grade": int(it.get("craft_grade", 2))}
	if GameState.forge_bag.size() > 40:
		GameState.forge_bag.pop_front()
	GameState.forge_item = {}
	_set_hit_busy(false)
	_push_log("成器入成品库：" + nm)
	GameState.save_game()
	refresh()

func _take() -> void:
	var it: Dictionary = GameState.forge_item
	if it.is_empty():
		return
	var nm := ForgeData.item_name(it)
	var sid := GameState.forge_next_sid()
	var set := ForgeData.card_set(it, sid)
	GameState.forge_add(sid, set)
	it["sid"] = sid
	GameState.forge_bag.append(it.duplicate(true))
	var bid := str(it.get("blank", ""))
	if bid != "":
		GameState.forge_made[bid] = {"q": int(it.get("quality", 0)), "grade": int(it.get("craft_grade", 2))}
	if GameState.forge_bag.size() > 40:
		GameState.forge_bag.pop_front()
	GameState.forge_item = {}
	_set_hit_busy(false)
	_push_log("收下：" + nm + "（已入仓库，角色面板可装备）")
	GameState.save_game()
	refresh()

func _push_log(s: String) -> void:
	_log_lines.append(s)
	while _log_lines.size() > 2:
		_log_lines.pop_front()
	_log_lb.text = "\n".join(PackedStringArray(_log_lines))

# ============================================================
# 刷新
# ============================================================
func refresh() -> void:
	if _panel == null:
		return
	_res_lb.text = "锻造石 " + str(GameState.material_count("forge_stone")) + " · 银两 " + str(GameState.coin("silver")) + " · 胚子 " + str(GameState.material_count("common"))
	var it: Dictionary = GameState.forge_item
	var gw := ForgeData.roll_percents(it)
	for i in _grade_lbs.size():
		var gl: Button = _grade_lbs[i]
		gl.text = ForgeData.outcome_name(i) + "\n" + str(int(round(float(gw[i])))) + "%"
	if _comp_panel != null:
		_comp_refresh()
	if _bag_panel != null:
		_bag_refresh()
	if _tool_panel != null and _tool_panel.visible:
		_tool_refresh()
	if it.is_empty():
		_item_lb.text = "砧上无物——点下方［武器/装备］选一块"
		_stat_lb.text = "选定胚子后锤第一下成器；成器直接进成品库"
		_hammer_btn.disabled = true
		_hammer_btn.text = "先 选 胚 子"
		if _take_btn != null:
			_take_btn.visible = false
		if _inspire_bar != null:
			_inspire_bar.visible = false
		if _inspire_lb != null:
			_inspire_lb.visible = false
	else:
		if int(it.get("craft_grade", -1)) < 0:
			var bb: Dictionary = ForgeData.blank(str(it.get("blank", "")))
			_item_lb.text = str(bb.get("name", "胚子"))
		else:
			_item_lb.text = ForgeData.item_name(it)
		var st: Dictionary = ForgeData.item_stats(it)
		var extra_txt := ""
		var qt := ForgeData.quench_trait(str(it.get("quench_trait", "")))
		if not qt.is_empty():
			if str(qt.get("id", "")) == "mingdao" or str(qt.get("id", "")) == "xiren":
				var ch := int(it.get("mingdao_charges", 2 if str(qt.get("id", "")) == "mingdao" else 1))
				extra_txt += " · " + str(qt.get("name", "")) + "(" + str(ch) + ")"
			elif str(qt.get("id", "")) == "xifeng":
				extra_txt += " · 洗锋(余" + str(int(it.get("xifeng_charges", 3))) + ")"
			elif str(qt.get("id", "")) == "dieren":
				extra_txt += " · 叠韧(" + str(int(it.get("dieren_stack", 0))) + ")"
			elif str(qt.get("id", "")) == "yangfeng":
				extra_txt += " · 养锋(" + str(int(it.get("yangfeng_stack", 0))) + ")"
			else:
				extra_txt += " · " + str(qt.get("name", ""))
		var ecn := ForgeData.element_cn(str(it.get("elem", "")))
		if ecn != "":
			extra_txt += " · " + ecn + "属"
		if st.has("atk"):
			_stat_lb.text = "攻 " + str(int(st.get("atk", 0))) + " · 伤 " + str(int(st.get("dmg", 0))) + " · 品质 " + ForgeData.quality_name(int(it.get("quality", 0))) + extra_txt
		else:
			_stat_lb.text = "防 " + str(int(st.get("def", 0))) + " · 血 " + str(int(st.get("hp", 0))) + " · 闪 " + str(int(st.get("dodge", 0))) + " · 品质 " + ForgeData.quality_name(int(it.get("quality", 0))) + extra_txt
		var qq := clampi(int(it.get("quality", 0)), 0, 4)
		var sc := ForgeData.hammer_stones(qq)
		var first_hammer := int(it.get("craft_grade", -1)) < 0
		var silver_need := ForgeData.finalize_silver(qq) if first_hammer else 0
		_hammer_btn.disabled = _hit_busy or GameState.material_count("forge_stone") < sc or (first_hammer and GameState.coin("silver") < silver_need)
		if _hit_busy:
			_hammer_btn.text = "锤 击 中…"
		elif first_hammer:
			_hammer_btn.text = "首 锤（" + str(silver_need) + "两 · 石" + str(sc) + "）"
		elif bool(it.get("free_hammer", false)):
			_hammer_btn.text = "锤 一 下（免 石）"
		else:
			_hammer_btn.text = "锤 一 下（石 " + str(sc) + "）"
		if _take_btn != null:
			_take_btn.visible = true
			_take_btn.disabled = _hit_busy
		var ins := float(it.get("inspired_left", 0.0))
		var intro := _inspire_intro_t > 0.0
		if _inspire_bar != null:
			_inspire_bar.visible = ins > 0.0 and not intro
			_inspire_bar.max_value = 7
			_inspire_bar.value = ins
		if _inspire_lb != null:
			_inspire_lb.visible = ins > 0.0 and not intro
			_inspire_lb.text = "入 神 · 限定时间内不会损坏"
	_bag_lb.text = "成品库：" + str(GameState.forge_bag.size()) + " 件"
	if _anvil != null:
		_anvil.queue_redraw()

# ============================================================
# 开合
# ============================================================
func open() -> void:
	if _comp_panel != null:
		_comp_panel.visible = false
	if _bag_panel != null:
		_bag_panel.visible = false
	if _comp_dim != null:
		_comp_dim.visible = false
	refresh()
	visible = true
	UiKit.pop_in(_panel)
	if GameState.first_journey_done and GameState.disciple_joined and not GameState.forge_tut_done:
		_show_forge_tutorial.call_deferred()

func _show_forge_tutorial() -> void:
	if _tut_overlay != null and is_instance_valid(_tut_overlay):
		return
	var dim := ColorRect.new()
	dim.position = Vector2.ZERO
	dim.size = Vector2(PANEL_W, PANEL_H)
	dim.color = Color(0.05, 0.04, 0.03, 0.74)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 80
	_panel.add_child(dim)
	_tut_overlay = dim
	var box := Panel.new()
	box.position = Vector2(50, 250)
	box.size = Vector2(540, 430)
	box.z_index = 81
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.958, 0.938, 0.892, 1.0)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.42, 0.33, 0.20, 0.70)
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	dim.add_child(box)
	var title := _label("第一次锻造", 30, INK)
	title.position = Vector2(0, 24)
	title.size = Vector2(540, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var body := _label("陈石：师父，先拿一块普通胚子上砧。

① 点「武器 / 装备」
② 选「胚子」
③ 点「锤一下」

先打一把趁手的。", 21, Color(INK.r, INK.g, INK.b, 0.88))
	body.position = Vector2(52, 86)
	body.size = Vector2(436, 250)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	var ok := UiKit.make_button(box, Vector2(170, 350), Vector2(200, 52), "知道了", 22)
	ok.pressed.connect(func() -> void:
		GameState.forge_tut_done = true
		GameState.save_game()
		if is_instance_valid(dim):
			dim.queue_free()
		_tut_overlay = null
	)

func close() -> void:
	if not visible:
		return
	_queued_hammer = false
	if _tool_panel != null:
		_tool_panel.visible = false
	UiKit.hide_panel(self)
	closed.emit()

func _gui_input(event: InputEvent) -> void:
	if _comp_panel != null and _comp_panel.visible:
		_comp_close()
		return
	if _bag_panel != null and _bag_panel.visible:
		_bag_close()
		return
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
			if _comp_panel != null and _comp_panel.visible:
				_comp_close()
			elif _bag_panel != null and _bag_panel.visible:
				_bag_close()
			else:
				close()
