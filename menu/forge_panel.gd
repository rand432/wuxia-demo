extends Control
# ============================================================
# forge_panel.gd —— 铁砧屏 V0.1
#
# 规则见 docs/锻造_设计稿.md：
#   · 五结果只在强化时掷；升阶不另掷
#   · +2%/级，+20 = +40%；升阶基础 ×1.5、强化归 0
#   · 入神：+10 触发，接下来 7 锤不碎
#   · 每锤 1 锻造石；开炉 10~30 两；升阶 银两 + 金髓 1
#
# V0.1：先出成品入「锻造库」，四槽装备接入下一步。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const Ui := preload("res://menu/menu_theme.gd")
const ForgeData := preload("res://menu/data_forge.gd")

signal closed

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const PANEL_W := 640.0
const PANEL_H := 940.0

var _panel: Panel
var _item_lb: Label
var _stat_lb: Label
var _res_lb: Label
var _log_lb: Label
var _bag_lb: Label
var _hammer_btn: Button
var _ascend_btn: Button
var _take_btn: Button
var _blank_btns: Array = []
var _anvil: Control
var _log_lines: Array = []
var _comp_panel: Panel
var _comp_dim: ColorRect
var _comp_hint_lb: Label
var _comp_recipe_lb: Label
var _comp_try_btn: Button
var _comp_make_btn: Button
var _comp_mat_btns := {}
var _comp_sel: Array = []
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
	if _anvil != null:
		_anvil.queue_redraw()

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

	var sub := _label("选胚 · 开炉 · 一锤一锤；+20 自动升阶", 14, Color(INK.r, INK.g, INK.b, 0.62))
	sub.position = Vector2(30, 58)
	sub.size = Vector2(380, 22)
	_panel.add_child(sub)

	_res_lb = _label("", 15, Color(INK.r, INK.g, INK.b, 0.68))
	_res_lb.position = Vector2(300, 58)
	_res_lb.size = Vector2(312, 22)
	_res_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_res_lb)

	_item_lb = _label("", 26, SEAL)
	_item_lb.position = Vector2(30, 92)
	_item_lb.size = Vector2(580, 34)
	_panel.add_child(_item_lb)

	_stat_lb = _label("", 15, Color(INK.r, INK.g, INK.b, 0.68))
	_stat_lb.position = Vector2(30, 128)
	_stat_lb.size = Vector2(580, 24)
	_panel.add_child(_stat_lb)

	_anvil = Control.new()
	_anvil.position = Vector2(28, 160)
	_anvil.size = Vector2(584, 300)
	_anvil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anvil.draw.connect(_draw_anvil)
	_panel.add_child(_anvil)

	_hammer_btn = UiKit.make_button(_panel, Vector2(210, 470), Vector2(220, 62), "锤 一 下", 22)
	_hammer_btn.pressed.connect(_hammer)

	_log_lb = _label("", 13, Color(INK.r, INK.g, INK.b, 0.74))
	_log_lb.position = Vector2(30, 544)
	_log_lb.size = Vector2(580, 60)
	_log_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_log_lb)

	var pick := _label("挑一口胚子开炉（不占手上兵器）", 14, Color(INK.r, INK.g, INK.b, 0.54))
	pick.position = Vector2(30, 624)
	pick.size = Vector2(580, 20)
	_panel.add_child(pick)

	_blank_btns = []
	for i in ForgeData.BLANKS.size():
		var b: Dictionary = ForgeData.BLANKS[i]
		var col := i % 2
		var row := i / 2
		var btn := UiKit.make_button(_panel, Vector2(30 + col * 300, 650 + row * 50), Vector2(280, 42), "", 14)
		btn.pressed.connect(_open_blank.bind(str(b["id"])))
		_blank_btns.append({"id": str(b["id"]), "btn": btn})

	_take_btn = UiKit.make_button(_panel, Vector2(30, 760), Vector2(180, 48), "收 下", 18)
	_take_btn.pressed.connect(_take)
	_ascend_btn = UiKit.make_button(_panel, Vector2(230, 760), Vector2(180, 48), "升 阶", 18)
	_ascend_btn.pressed.connect(_ascend)
	var close_btn := UiKit.make_button(_panel, Vector2(430, 760), Vector2(180, 48), "关 闭", 18)
	close_btn.pressed.connect(close)

	_bag_lb = _label("", 13, Color(INK.r, INK.g, INK.b, 0.58))
	_bag_lb.position = Vector2(30, 826)
	_bag_lb.size = Vector2(580, 22)
	_panel.add_child(_bag_lb)

	var comp_btn := UiKit.make_button(_panel, Vector2(516, 12), Vector2(94, 36), "图 鉴", 16)
	comp_btn.pressed.connect(_comp_open)
	_build_compendium()

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
	_comp_panel.position = Vector2(30, 70)
	_comp_panel.size = Vector2(580, 500)
	_comp_panel.z_index = 20
	_comp_panel.visible = false
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.958, 0.938, 0.892, 1.0)
	csb.set_corner_radius_all(6)
	csb.border_color = Color(0.42, 0.33, 0.20, 0.60)
	csb.set_border_width_all(2)
	_comp_panel.add_theme_stylebox_override("panel", csb)
	_panel.add_child(_comp_panel)

	var t := _label("锻 造 图 鉴", 24, INK)
	t.position = Vector2(22, 14)
	t.size = Vector2(300, 32)
	_comp_panel.add_child(t)

	_comp_hint_lb = _label("", 14, Color(INK.r, INK.g, INK.b, 0.74))
	_comp_hint_lb.position = Vector2(22, 52)
	_comp_hint_lb.size = Vector2(536, 24)
	_comp_panel.add_child(_comp_hint_lb)

	var pick := _label("放两味料试试（试错只亏石头，材料不动）", 13, Color(INK.r, INK.g, INK.b, 0.54))
	pick.position = Vector2(22, 84)
	pick.size = Vector2(536, 20)
	_comp_panel.add_child(pick)

	_comp_mat_btns = {}
	var mats := ["bone", "rice", "jin", "zhi"]
	for i in mats.size():
		var k := str(mats[i])
		var col := i % 2
		var row := i / 2
		var mb := UiKit.make_button(_comp_panel, Vector2(22 + col * 274, 110 + row * 48), Vector2(258, 40), "", 14)
		mb.toggle_mode = true
		mb.pressed.connect(_comp_toggle.bind(k))
		_comp_mat_btns[k] = mb

	_comp_try_btn = UiKit.make_button(_comp_panel, Vector2(22, 224), Vector2(258, 48), "试 合", 18)
	_comp_try_btn.pressed.connect(_comp_try)

	_comp_recipe_lb = _label("", 14, Color(INK.r, INK.g, INK.b, 0.78))
	_comp_recipe_lb.position = Vector2(22, 288)
	_comp_recipe_lb.size = Vector2(536, 70)
	_comp_recipe_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comp_panel.add_child(_comp_recipe_lb)

	_comp_make_btn = UiKit.make_button(_comp_panel, Vector2(22, 370), Vector2(258, 48), "照图鉴造胚", 17)
	_comp_make_btn.pressed.connect(_comp_make)

	var back := UiKit.make_button(_comp_panel, Vector2(300, 370), Vector2(258, 48), "返 回", 18)
	back.pressed.connect(_comp_close)

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
	var inspired := int(it.get("inspired_left", 0)) > 0
	var y := h - 112.0
	if inspired:
		blade = blade.lerp(Color("#ffb347"), 0.55)
	# 剑身：横在砧上
	var x0 := cx - 168.0
	var x1 := cx + 150.0
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
	# 入神：7 个亮点
	var left := int(it.get("inspired_left", 0))
	if left > 0:
		for i in left:
			_anvil.draw_circle(Vector2(bx + 168.0 + float(i) * 18.0, by - 24.0), 4.0, Color("#ffb347"))

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
	var cost := int(b.get("open", 10))
	if GameState.coin("silver") < cost:
		_push_log("开炉要 " + str(cost) + " 两——银两不够。")
		return
	GameState.add_coin("silver", -cost)
	GameState.forge_item = ForgeData.make_item(id)
	_push_log("开炉：" + str(b.get("name", "胚子")) + "（-" + str(cost) + " 两）")
	GameState.save_game()
	refresh()

func _hammer() -> void:
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
	if GameState.material_count("forge_stone") < 1:
		_push_log("锻造石不够——去游历、宝箱或塔里找。")
		return
	GameState.add_material("forge_stone", -1)

	var outcome := _roll(it)
	var text := ""
	match outcome:
		0:
			it["enhance"] = mini(20, int(it.get("enhance", 0)) + 2)
			text = "大成功！强化 +2"
		1:
			it["enhance"] = mini(20, int(it.get("enhance", 0)) + 1)
			text = "成功——强化 +1"
		2:
			text = "维持——剑身未动"
		3:
			it["enhance"] = maxi(0, int(it.get("enhance", 0)) - 1)
			it["cracks"] = int(it.get("cracks", 0)) + 1
			text = "损伤——强化 -1，裂纹 +1"
		_:
			text = "破坏——剑碎了"
	if outcome != 4:
		if int(it.get("inspired_left", 0)) > 0:
			it["inspired_left"] = int(it.get("inspired_left", 0)) - 1
		if int(it.get("enhance", 0)) >= 10 and not bool(it.get("round_inspired", false)):
			it["round_inspired"] = true
			it["inspired_left"] = 7
			text += "｜入神！接下来 7 锤不碎"
		GameState.forge_item = it
		_push_log(text)
		if int(it.get("enhance", 0)) >= 20:
			_try_ascend(it)
	else:
		GameState.add_material("forge_stone", 1)
		GameState.forge_item = {}
		_push_log(text + "（留 1 锻造石）")
	GameState.save_game()
	refresh()

func _roll(it: Dictionary) -> int:
	var b: Dictionary = ForgeData.blank(str(it.get("blank", "")))
	if b.is_empty():
		return 1
	var p: Array = []
	for v in (b.get("probs", [8, 45, 25, 17, 5]) as Array):
		p.append(float(v))
	var e := float(it.get("enhance", 0))
	var cr := float(it.get("cracks", 0))
	var extra_break := e * 0.15 + cr * 2.0
	var extra_dmg := e * 0.08 + cr * 1.0
	p[4] += extra_break
	p[3] += extra_dmg
	p[1] = maxf(0.0, float(p[1]) - extra_break - extra_dmg)
	if int(it.get("inspired_left", 0)) > 0:
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

func _try_ascend(it: Dictionary) -> void:
	if int(it.get("enhance", 0)) < 20:
		return
	if int(it.get("quality", 0)) >= int(it.get("cap", 4)):
		it["awaiting"] = false
		_push_log("潜力封顶——这把停在 +20。")
		return
	var cost: Dictionary = ForgeData.ascend_cost(int(it.get("quality", 0)))
	var need_s := int(cost["silver"])
	var need_j := int(cost["jin"])
	if GameState.coin("silver") < need_s or GameState.material_count("jin") < need_j:
		it["awaiting"] = true
		_push_log("够 +20 了——升阶要 " + str(need_s) + " 两 · 金髓 " + str(need_j) + "。")
		return
	GameState.add_coin("silver", -need_s)
	GameState.add_material("jin", -need_j)
	it["quality"] = int(it.get("quality", 0)) + 1
	it["base_atk"] = float(it.get("base_atk", 0.0)) * 1.5
	it["base_dmg"] = float(it.get("base_dmg", 0.0)) * 1.5
	it["enhance"] = 0
	it["cracks"] = 0
	it["inspired_left"] = 0
	it["round_inspired"] = false
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

func _comp_open() -> void:
	_comp_dim.visible = true
	_comp_panel.visible = true
	_comp_refresh()

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
		_push_log("合中！图鉴 +1：「" + str(c["name"]) + "」")
	GameState.save_game()
	refresh()

func _comp_make() -> void:
	var c: Dictionary = ForgeData.combo("qingfeng")
	if not GameState.forge_compendium.has("qingfeng"):
		_push_log("还没合中——图鉴上是空的。")
		return
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
	_push_log("照图鉴造胚：「" + str(c["name"]) + "」已上砧。")
	GameState.save_game()
	_comp_close()
	refresh()

func _comp_refresh() -> void:
	if _comp_panel == null or not _comp_panel.visible:
		return
	var unlocked := GameState.forge_compendium.has("qingfeng")
	var stones := GameState.material_count("forge_stone")
	for k_v in _comp_mat_btns.keys():
		var k := str(k_v)
		var b: Button = _comp_mat_btns[k]
		b.text = GameState.mat_name(k) + " " + str(GameState.material_count(k))
	_comp_hint_lb.text = "已入图鉴：「青锋剑胚」" if unlocked else "老铁匠说：骨粉养锋，米浆淬火"
	_comp_try_btn.disabled = unlocked or stones < ForgeData.TRIAL_STONES
	_comp_try_btn.text = "试 合（锻造石 " + str(ForgeData.TRIAL_STONES) + "）"
	var c: Dictionary = ForgeData.combo("qingfeng")
	var cost: Dictionary = c.get("cost", {})
	var cost_txt := ""
	for k_v in cost.keys():
		var k := str(k_v)
		cost_txt += GameState.mat_name(k) + " " + str(int(cost[k])) + " · "
	cost_txt = cost_txt.trim_suffix(" · ")
	if unlocked:
		_comp_recipe_lb.text = "图鉴：「青锋剑胚」\n造胚耗：" + cost_txt + "\n造出来直接上砧，不再收开炉银两。"
	else:
		_comp_recipe_lb.text = "图鉴：未合中\n提示：骨粉养锋，米浆淬火。\n（放进炉子试；合不中只亏石头，材料原样退回）"
	_comp_make_btn.visible = unlocked
	var can_make := true
	for k_v in cost.keys():
		var k := str(k_v)
		if GameState.material_count(k) < int(cost[k]):
			can_make = false
	_comp_make_btn.disabled = not can_make or not (GameState.forge_item as Dictionary).is_empty()
	_comp_make_btn.text = "照图鉴造胚（" + cost_txt + "）"

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
	if GameState.forge_bag.size() > 40:
		GameState.forge_bag.pop_front()
	GameState.forge_item = {}
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
	_res_lb.text = "锻造石 " + str(GameState.material_count("forge_stone")) + " · 银两 " + str(GameState.coin("silver")) + " · 金髓 " + str(GameState.material_count("jin"))
	var it: Dictionary = GameState.forge_item
	for e_v in _blank_btns:
		var e: Dictionary = e_v
		var b: Dictionary = ForgeData.blank(str(e["id"]))
		var btn: Button = e["btn"]
		btn.text = str(b.get("name", "胚子")) + "  " + str(int(b.get("open", 10))) + "两 · " + str(b.get("trait", ""))
		btn.disabled = not it.is_empty()
	if _comp_panel != null:
		_comp_refresh()
	if it.is_empty():
		_item_lb.text = "砧上无物——挑一口胚子开炉"
		_stat_lb.text = "开炉后每锤耗 1 锻造石；+10 入神，+20 自动升阶"
		_hammer_btn.disabled = true
		_hammer_btn.text = "锤 一 下"
		_ascend_btn.visible = false
		_take_btn.visible = false
	else:
		_item_lb.text = ForgeData.item_name(it)
		var st: Dictionary = ForgeData.item_stats(it)
		var insp := ""
		if int(it.get("inspired_left", 0)) > 0:
			insp = " · 入神 " + str(int(it.get("inspired_left", 0))) + "/7"
		_stat_lb.text = "攻 " + str(int(st["atk"])) + " · 伤 " + str(int(st["dmg"])) + " · 强化 +" + str(int(it.get("enhance", 0))) + "/20 · 裂纹 " + str(int(it.get("cracks", 0))) + insp
		var waiting := bool(it.get("awaiting", false))
		_hammer_btn.disabled = waiting or int(it.get("enhance", 0)) >= 20 or GameState.material_count("forge_stone") < 1
		_hammer_btn.text = "先 升 阶" if waiting or int(it.get("enhance", 0)) >= 20 else "锤 一 下（锻造石 1）"
		_ascend_btn.visible = waiting or int(it.get("enhance", 0)) >= 20
		if int(it.get("quality", 0)) >= int(it.get("cap", 4)):
			_ascend_btn.text = "潜力封顶"
			_ascend_btn.disabled = true
		else:
			var cost: Dictionary = ForgeData.ascend_cost(int(it.get("quality", 0)))
			_ascend_btn.text = "升 阶 " + str(int(cost["silver"])) + "两·金髓1"
			_ascend_btn.disabled = GameState.coin("silver") < int(cost["silver"]) or GameState.material_count("jin") < int(cost["jin"])
		_take_btn.visible = true
	_bag_lb.text = "锻造库：" + str(GameState.forge_bag.size()) + " 件" + ("（最近：" + ForgeData.item_name(GameState.forge_bag[GameState.forge_bag.size() - 1]) + "）" if not GameState.forge_bag.is_empty() else "")
	if _anvil != null:
		_anvil.queue_redraw()

# ============================================================
# 开合
# ============================================================
func open() -> void:
	if _comp_panel != null:
		_comp_panel.visible = false
	if _comp_dim != null:
		_comp_dim.visible = false
	refresh()
	visible = true
	UiKit.pop_in(_panel)

func close() -> void:
	if not visible:
		return
	UiKit.hide_panel(self)
	closed.emit()

func _gui_input(event: InputEvent) -> void:
	if _comp_panel != null and _comp_panel.visible:
		_comp_close()
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
			else:
				close()
