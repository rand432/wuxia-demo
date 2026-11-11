extends Control
# ============================================================
# menu/curio_home.gd —— 局外「奇物」页
#   版式：复用主界面顶栏(UI.app_bar) + 底栏(UI.dock，新增 curio 页签)
#   内容：轮播三卡 + 名称/类型 + 五档强化路线 + 当前档效果 + 携带/卸下
#   交互：点两侧卡切换、点中间卡弹进阶路线、单槽携带
#   设计稿：docs/奇物_设计稿.md
# ============================================================
const UI := preload("res://shared/ui_kit.gd")
const P := preload("res://shared/ui_pal.gd")
const GameState := preload("res://shared/game_state.gd")
const CurioData := preload("res://shared/curio_data.gd")
const Audio := preload("res://shared/audio.gd")
const FONT := preload("res://fonts/ink.ttf")

var _ids: Array = []
var _sel := 0
var _cards: Array = []
var _name_lb: Label = null
var _type_lb: Label = null
var _fx_lb: Label = null
var _next_lb: Label = null
var _equip_btn: Button = null
var _pips = null
var _pop: Control = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	UI.bg(self)
	UI.app_bar(self, GameState.player_name, GameState.role_grade_cn(""), func() -> void: print("[奇物页] 设置"))
	_ids = CurioData.order()
	_build_head()
	_build_cards()
	_build_detail()
	UI.dock(self, "curio", _on_dock)
	_refresh()

func _build_head() -> void:
	UI.label(self, "奇 物", Vector2(0, 96), Vector2(720, 44), 34, P.INK, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(self, "单局只能带一件 · 局外强化固定路线", Vector2(0, 140), Vector2(720, 26), 17, P.DIM, HORIZONTAL_ALIGNMENT_CENTER)

# ---------------- 轮播 ----------------
func _build_cards() -> void:
	for i in 3:
		var c := CurioCard.new()
		if i == 1:
			c.position = Vector2(210, 186)
			c.size = Vector2(300, 380)
			c.big = true
		else:
			c.position = Vector2(18 if i == 0 else 530, 220)
			c.size = Vector2(172, 250)
			c.faded = true
		add_child(c)
		_cards.append(c)
		var side := i
		c.pressed.connect(func() -> void: _on_card(side))

func _on_card(i: int) -> void:
	Audio.sfx("ui_click", -8.0)
	if i == 1:
		_open_pop()
	else:
		var n := _ids.size()
		_sel = wrapi(_sel + (-1 if i == 0 else 1), 0, n)
		_refresh()

func _refresh() -> void:
	var n := _ids.size()
	if n <= 0:
		return
	var order := [wrapi(_sel - 1, 0, n), _sel, wrapi(_sel + 1, 0, n)]
	for i in 3:
		var cid := str(_ids[order[i]])
		var cd := CurioData.get_curio(cid)
		var c: CurioCard = _cards[i]
		c.curio_id = cid
		c.glyph = str(cd.get("glyph", "?"))
		c.equipped = GameState.curio_id == cid
		c.queue_redraw()
	var cur := str(_ids[_sel])
	var info := CurioData.get_curio(cur)
	_name_lb.text = str(info.get("name", ""))
	var is_active := str(info.get("type", "")) == "主动"
	var cd_s := float(info.get("cd", 0.0))
	_type_lb.text = ("主动 · 自动触发 · 冷却 %d 秒" % int(cd_s)) if is_active else "被动 · 常驻生效"
	var lv := GameState.curio_level(cur)
	if _pips != null:
		_pips.lv = lv
		var labs: Array = []
		for t in (info.get("lv", []) as Array):
			var s := str(t)
			labs.append(s.substr(0, 8))
		_pips.labels = labs
		_pips.queue_redraw()
	_fx_lb.text = "Lv %d · %s" % [lv, CurioData.level_text(cur, lv)]
	if lv < 5:
		_next_lb.text = "Lv%d 下一档：%s" % [lv + 1, CurioData.level_text(cur, lv + 1)]
	else:
		_next_lb.text = "已满级"
	var equipped := GameState.curio_id == cur
	_equip_btn.text = "卸 下 奇 物" if equipped else "携 带 此 奇 物"
	_apply_equip_style(equipped)

func _apply_equip_style(equipped: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	if equipped:
		sb.bg_color = P.PAPER_HI
		sb.border_color = Color(0.549, 0.470, 0.345)
		sb.set_border_width_all(3)
	else:
		sb.bg_color = P.DARK
		sb.border_color = P.GOLD_HI
		sb.set_border_width_all(2)
	for st in ["normal", "hover", "pressed"]:
		_equip_btn.add_theme_stylebox_override(st, sb)
	_equip_btn.add_theme_color_override("font_color", Color(0.353, 0.282, 0.173) if equipped else P.GOLD_HI)
	_equip_btn.add_theme_color_override("font_hover_color", Color(0.353, 0.282, 0.173) if equipped else P.GOLD_HI)

# ---------------- 详情 ----------------
func _build_detail() -> void:
	_name_lb = UI.label(self, "", Vector2(0, 592), Vector2(720, 56), 44, P.INK, HORIZONTAL_ALIGNMENT_CENTER)
	var pill := Panel.new()
	pill.position = Vector2(170, 646)
	pill.size = Vector2(380, 36)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.910, 0.886, 0.804)
	psb.set_corner_radius_all(16)
	psb.border_color = Color(0.722, 0.659, 0.533)
	psb.set_border_width_all(1)
	pill.add_theme_stylebox_override("panel", psb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pill)
	_type_lb = UI.label(self, "", Vector2(170, 646), Vector2(380, 36), 19, Color(0.306, 0.259, 0.196), HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(self, "强化路线", Vector2(52, 706), Vector2(200, 30), 21, P.DIM)
	_pips = CurioPips.new()
	_pips.position = Vector2(40, 736)
	_pips.size = Vector2(640, 96)
	add_child(_pips)
	# 效果区
	var box := Panel.new()
	box.position = Vector2(40, 842)
	box.size = Vector2(640, 148)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = P.PAPER_HI
	bsb.set_corner_radius_all(14)
	bsb.border_color = Color(0.753, 0.698, 0.588)
	bsb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", bsb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_fx_lb = UI.label(self, "", Vector2(62, 856), Vector2(600, 32), 21, P.INK)
	_fx_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_lb = UI.label(self, "", Vector2(62, 946), Vector2(600, 28), 18, P.DIM)
	_next_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 携带/卸下
	_equip_btn = UI.button(self, "", Rect2(150, 1004, 420, 84), 28, Color(0, 0, 0, 0), P.GOLD_HI, _on_equip)
	_equip_btn.text = "携 带 此 奇 物"
	UI.label(self, "点中间卡片 → 进阶路线 · 点两侧卡片 → 切换奇物", Vector2(0, 1112), Vector2(720, 26), 17, P.DIM, HORIZONTAL_ALIGNMENT_CENTER)

func _on_equip() -> void:
	var cur := str(_ids[_sel])
	Audio.sfx("ui_click", -8.0)
	if GameState.curio_id == cur:
		GameState.curio_unequip()
	else:
		GameState.curio_equip(cur)
	_refresh()

# ---------------- 进阶路线弹窗 ----------------
func _open_pop() -> void:
	_close_pop()
	_pop = Control.new()
	_pop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pop.mouse_filter = Control.MOUSE_FILTER_STOP
	_pop.z_index = 40
	add_child(_pop)
	var dim := ColorRect.new()
	dim.color = Color(0.235, 0.196, 0.157, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pop.add_child(dim)
	var cur := str(_ids[_sel])
	var info := CurioData.get_curio(cur)
	var holder := Control.new()
	holder.position = Vector2(60, 170)
	holder.size = Vector2(600, 950)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop.add_child(holder)
	var pn := Panel.new()
	pn.position = Vector2.ZERO
	pn.size = Vector2(600, 950)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.988, 0.969, 0.925)
	psb.set_corner_radius_all(18)
	psb.border_color = P.GOLD
	psb.set_border_width_all(3)
	pn.add_theme_stylebox_override("panel", psb)
	holder.add_child(pn)
	UI.label(holder, str(info.get("name", "")) + " · 进阶路线", Vector2(0, 24), Vector2(600, 48), 32, P.INK, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(holder, "固定路线 · 不可洗点", Vector2(0, 66), Vector2(600, 26), 17, P.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var lv := GameState.curio_level(cur)
	var arr: Array = info.get("lv", [])
	for i in arr.size():
		var on := (i + 1) <= lv
		var row := Panel.new()
		row.position = Vector2(30, 108 + i * 140)
		row.size = Vector2(540, 128)
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0.965, 0.933, 0.871) if on else Color(0.933, 0.902, 0.839)
		rsb.set_corner_radius_all(12)
		rsb.border_color = P.GOLD if on else Color(0.769, 0.714, 0.604)
		rsb.set_border_width_all(2 if on else 1)
		row.add_theme_stylebox_override("panel", rsb)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(row)
		var circle := LvDot.new()
		circle.position = Vector2(16, 36)
		circle.size = Vector2(56, 56)
		circle.lv = i + 1
		circle.on = on
		row.add_child(circle)
		var txt := str(arr[i])
		var tl := UI.label(row, txt, Vector2(88, 18), Vector2(436, 70), 21, P.INK)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not on:
			UI.label(row, "未解锁（强化上一层后开放）", Vector2(88, 90), Vector2(436, 24), 16, P.DIM)
	var up := UI.button(holder, "强 化", Rect2(40, 836, 520, 72), 28, P.DARK, P.GOLD_HI, Callable())
	up.pressed.connect(func() -> void:
		if GameState.curio_upgrade(cur):
			Audio.sfx("levelup", -8.0)
			_close_pop()
			_refresh())
	var close := UI.button(holder, "×", Rect2(548, 18, 40, 40), 26, Color(0, 0, 0, 0), P.DIM, _close_pop)
	close.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	close.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	close.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())

func _close_pop() -> void:
	if _pop != null and is_instance_valid(_pop):
		_pop.queue_free()
	_pop = null

func _on_dock(key: String) -> void:
	if key == "curio":
		return
	Audio.sfx("ui_click", -6.0)
	match key:
		"role":
			get_tree().change_scene_to_file("res://menu/character_home.tscn")
		"god":
			get_tree().change_scene_to_file("res://menu/partner_home.tscn")
		"start":
			get_tree().change_scene_to_file("res://kushou/battle_ui.tscn")

# ---------------- 子控件 ----------------
class CurioCard extends Control:
	signal pressed
	var glyph := "?"
	var curio_id := ""
	var equipped := false
	var big := false
	var faded := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()
	func _draw() -> void:
		var gold := Color(0.776, 0.612, 0.259)
		var line := Color(0.690, 0.635, 0.533)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.988, 0.973, 0.933) if big else Color(0.973, 0.957, 0.918)
		sb.set_corner_radius_all(16)
		sb.border_color = gold if big else line
		sb.set_border_width_all(4 if big else 2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var r := minf(size.x, size.y) * (0.33 if big else 0.30)
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		draw_circle(c, r, Color(0.941, 0.906, 0.827))
		draw_arc(c, r, 0.0, TAU, 40, Color(0.721, 0.659, 0.533), 2.0)
		var f := preload("res://fonts/ink.ttf")
		var fs := int(r * 0.95)
		var tw := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, c + Vector2(-tw.x * 0.5, tw.y * 0.32), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.227, 0.180, 0.125))
		if big and equipped:
			var tag := Rect2(size.x - 80, 10, 72, 34)
			draw_rect(tag, Color(0.549, 0.196, 0.149))
			draw_string(f, tag.position + Vector2(6, 24), "已携带", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.980, 0.957, 0.902))
		if faded:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.965, 0.933, 0.871, 0.58))

class CurioPips extends Control:
	var lv := 1
	var labels: Array = []
	func _draw() -> void:
		var f := preload("res://fonts/ink.ttf")
		var xs := [56.0, 188.0, 320.0, 452.0, 584.0]
		for i in xs.size():
			var x: float = xs[i]
			var on := (i + 1) <= lv
			if i < xs.size() - 1:
				var nx: float = xs[i + 1]
				draw_line(Vector2(x + 22, 26), Vector2(nx - 22, 26),
					Color(0.776, 0.612, 0.259) if (i + 1) < lv else Color(0.800, 0.761, 0.682), 4.0)
			draw_circle(Vector2(x, 26), 22.0, Color(0.776, 0.612, 0.259) if on else Color(0.988, 0.973, 0.933))
			draw_arc(Vector2(x, 26), 22.0, 0.0, TAU, 32, Color(0.596, 0.533, 0.416), 3.0)
			var s := str(i + 1)
			var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
			draw_string(f, Vector2(x - tw.x * 0.5, 34), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
				Color(0.988, 0.965, 0.910) if on else Color(0.486, 0.439, 0.361))
			if i < labels.size():
				var lab := str(labels[i])
				var tw2 := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
				draw_string(f, Vector2(x - tw2.x * 0.5, 74), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					Color(0.290, 0.243, 0.180) if on else Color(0.431, 0.388, 0.325))

class LvDot extends Control:
	var lv := 1
	var on := false
	func _draw() -> void:
		var c := Vector2(28, 28)
		draw_circle(c, 26.0, Color(0.776, 0.612, 0.259) if on else Color(0.816, 0.769, 0.675))
		draw_arc(c, 26.0, 0.0, TAU, 32, Color(0.596, 0.533, 0.416), 2.0)
		var f := preload("res://fonts/ink.ttf")
		var s := str(lv)
		var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		draw_string(f, Vector2(28 - tw.x * 0.5, 38), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
			Color(0.988, 0.965, 0.910) if on else Color(0.514, 0.463, 0.384))
