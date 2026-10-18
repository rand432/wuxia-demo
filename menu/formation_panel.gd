extends Control
# ============================================================
# formation_panel.gd —— 出村整备 v4（用户：站位重做）
#   旧 v3：三格 + 名单，点名字上阵。
#   v4（用户）：三条横栏「前排抗伤 / 中排均衡 / 后排输出」——
#       **点一条栏 → 弹出人物按钮 → 点谁，谁就站那排**；
#       栏里有人 → 弹窗里也能「撤下」；三栏全空 = 不能出战。
#       名单不再常驻（搬进弹窗），主面板更空、字更大。
#   用法照旧：open_for_stage(i) 引导出战 / open_config() 配置阵容。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const DataPets := preload("res://shared/data_pets.gd")
const UiKit := preload("res://shared/ui_kit.gd")   # v221：统一收起

signal confirmed(stage_i: int)
signal saved
signal cancelled

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)

const PANEL_W := 640.0
const PANEL_H := 680.0
const SLOT_NAMES := ["前", "中", "后"]
const SLOT_ROLES := ["抗伤", "均衡", "输出"]

var _panel: Panel
var _title_lb: Label
var _sub_lb: Label
var _ok_btn: Button
var _stage_i := 0
var _battle_mode := true
var _slot_cells: Array = []     # {btn, role_lb, name_lb, hint_lb}
var _pet_lb: Label
var _pet_btn: Button
var _msg_lb: Label
# ---- 选人弹窗（点栏位后浮出来）----
var _pick_veil: Control = null
var _pick_slot := 0
var _pick_btns: Array = []
var _pick_ids: Array = []

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

	_title_lb = _label("整备 · 出战", 30, INK)
	_title_lb.position = Vector2(28, 18)
	_title_lb.size = Vector2(360, 44)
	_panel.add_child(_title_lb)
	_sub_lb = _label("", 15, Color(INK.r, INK.g, INK.b, 0.58))
	_sub_lb.position = Vector2(30, 60)
	_sub_lb.size = Vector2(580, 46)
	_sub_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_sub_lb)

	var sep := ColorRect.new()
	sep.color = Color(INK.r, INK.g, INK.b, 0.22)
	sep.position = Vector2(28, 110)
	sep.size = Vector2(PANEL_W - 56.0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sep)

	# ---- 三条横栏（前排抗伤 / 中排均衡 / 后排输出）----
	_slot_cells = []
	for i in 3:
		var y := 122.0 + float(i) * 112.0
		var b := Button.new()
		b.position = Vector2(28, y)
		b.size = Vector2(584, 104)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		_panel.add_child(b)
		var sb := _paper_sb()
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", _paper_sb(true))
		b.add_theme_stylebox_override("pressed", _flat(Color(0.90, 0.88, 0.82, 0.95)))
		b.add_theme_stylebox_override("focus", sb)
		b.pressed.connect(_on_slot.bind(i))
		var role := _label(str(SLOT_NAMES[i]) + "排 · " + str(SLOT_ROLES[i]), 24, Color(INK.r, INK.g, INK.b, 0.50))
		role.position = Vector2(20, 30)
		role.size = Vector2(200, 40)
		b.add_child(role)
		var nm := _label("（空）", 28, INK)
		nm.position = Vector2(230, 24)
		nm.size = Vector2(340, 46)
		b.add_child(nm)
		var hint := _label("", 14, Color(INK.r, INK.g, INK.b, 0.50))
		hint.position = Vector2(230, 70)
		hint.size = Vector2(340, 24)
		b.add_child(hint)
		_slot_cells.append({"btn": b, "role_lb": role, "name_lb": nm, "hint_lb": hint})

	# ---- 宠物栏 ----
	var pet := Panel.new()
	pet.position = Vector2(28, 462)
	pet.size = Vector2(584, 92)
	pet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pet.add_theme_stylebox_override("panel", _paper_sb())
	_panel.add_child(pet)
	var ph := _label("宠物", 22, Color(INK.r, INK.g, INK.b, 0.45))
	ph.position = Vector2(20, 28)
	ph.size = Vector2(80, 34)
	pet.add_child(ph)
	_pet_lb = _label("", 16, Color(INK.r, INK.g, INK.b, 0.85))
	_pet_lb.position = Vector2(112, 12)
	_pet_lb.size = Vector2(310, 68)
	_pet_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pet.add_child(_pet_lb)
	_pet_btn = Button.new()
	_pet_btn.position = Vector2(438, 20)
	_pet_btn.size = Vector2(128, 50)
	_pet_btn.add_theme_font_size_override("font_size", 17)
	_pet_btn.focus_mode = Control.FOCUS_NONE
	_pet_btn.pressed.connect(_on_pet_toggle)
	_style_dark(_pet_btn)
	pet.add_child(_pet_btn)

	# ---- 提示 & 按钮 ----
	_msg_lb = _label("", 14, Color(SEAL.r, SEAL.g, SEAL.b, 0.90))
	_msg_lb.position = Vector2(28, 566)
	_msg_lb.size = Vector2(584, 24)
	_panel.add_child(_msg_lb)

	_ok_btn = Button.new()
	_ok_btn.text = "确定出战"
	_ok_btn.position = Vector2(56, 598)
	_ok_btn.size = Vector2(260, 58)
	_ok_btn.add_theme_font_size_override("font_size", 22)
	_ok_btn.focus_mode = Control.FOCUS_NONE
	_ok_btn.pressed.connect(_on_ok)
	_style_seal(_ok_btn)
	_panel.add_child(_ok_btn)

	var back := Button.new()
	back.text = "返回"
	back.position = Vector2(348, 598)
	back.size = Vector2(200, 58)
	back.add_theme_font_size_override("font_size", 20)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_on_back)
	_style_dark(back)
	_panel.add_child(back)

	_build_picker()

# ---- 选人弹窗（点栏位后浮出）----

func _build_picker() -> void:
	_pick_veil = Control.new()
	_pick_veil.position = Vector2.ZERO
	_pick_veil.size = _panel.size
	_pick_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_pick_veil.visible = false
	var bg := ColorRect.new()
	bg.color = Color(PAPER.r, PAPER.g, PAPER.b, 0.99)
	bg.size = _pick_veil.size
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_pick_veil.add_child(bg)
	_panel.add_child(_pick_veil)
	_pick_veil.move_to_front()

	var tt := _label("", 26, INK)
	tt.name = "PickTitle"
	tt.position = Vector2(28, 22)
	tt.size = Vector2(584, 40)
	_pick_veil.add_child(tt)
	var sub2 := _label("点谁，谁就站这排；已在阵里的会挪过来。", 15, Color(INK.r, INK.g, INK.b, 0.55))
	sub2.position = Vector2(28, 66)
	sub2.size = Vector2(584, 26)
	_pick_veil.add_child(sub2)

	_pick_btns = []
	for i in 3:
		var rb := Button.new()
		rb.position = Vector2(28, 104.0 + float(i) * 92.0)
		rb.size = Vector2(584, 84)
		rb.add_theme_font_size_override("font_size", 20)
		rb.focus_mode = Control.FOCUS_NONE
		rb.pressed.connect(_on_pick_person.bind(i))
		_style_dark(rb)
		_pick_veil.add_child(rb)
		_pick_btns.append(rb)

	var rm := Button.new()
	rm.text = "撤下这一排的人"
	rm.name = "PickRemove"
	rm.position = Vector2(28, 396)
	rm.size = Vector2(584, 58)
	rm.add_theme_font_size_override("font_size", 18)
	rm.focus_mode = Control.FOCUS_NONE
	rm.pressed.connect(_on_pick_remove)
	_pick_veil.add_child(rm)

	var cl := Button.new()
	cl.text = "返回"
	cl.position = Vector2(56, 560)
	cl.size = Vector2(240, 56)
	cl.add_theme_font_size_override("font_size", 20)
	cl.focus_mode = Control.FOCUS_NONE
	cl.pressed.connect(_close_picker)
	_style_dark(cl)
	_pick_veil.add_child(cl)

func _open_picker(slot_i: int) -> void:
	_pick_slot = slot_i
	_pick_ids = GameState.disciple_ids()
	var tt: Label = _pick_veil.find_child("PickTitle", true, false)
	tt.text = "第「" + str(SLOT_NAMES[slot_i]) + "」排（" + str(SLOT_ROLES[slot_i]) + "）——安排谁？"
	var occupant := "" if slot_i >= GameState.formation.size() else str(GameState.formation[slot_i])
	for i in _pick_btns.size():
		var b: Button = _pick_btns[i]
		if i >= _pick_ids.size():
			b.visible = false
			continue
		b.visible = true
		var id2 := str(_pick_ids[i])
		var d: Dictionary = GameState.role_data(id2)
		var lv := int(d.get("lv", 1))
		var in_form := GameState.formation.find(id2)
		b.text = str(d.get("name", id2)) + " · Lv" + str(lv) + " " + GameState.realm_of(lv)
		if in_form >= 0:
			b.text += "　（已在「" + str(SLOT_NAMES[in_form]) + "」排——点我挪过来）"
		b.disabled = false
	var rm: Button = _pick_veil.find_child("PickRemove", true, false)
	rm.visible = occupant != ""
	rm.text = "撤下这一排的人" + ("" if occupant == "" else "（" + str(GameState.role_data(occupant).get("name", occupant)) + "）")
	_pick_veil.visible = true
	_pick_veil.move_to_front()

func _close_picker() -> void:
	if _pick_veil != null:
		_pick_veil.visible = false
	refresh()

func _on_pick_person(i: int) -> void:
	if i < 0 or i >= _pick_ids.size():
		return
	_msg_lb.text = GameState.formation_put(str(_pick_ids[i]), _pick_slot)
	_close_picker()

func _on_pick_remove() -> void:
	if _pick_slot < GameState.formation.size():
		_msg_lb.text = GameState.formation_remove(str(GameState.formation[_pick_slot]))
	_close_picker()

# ---- 样式 ----

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

func _paper_sb(hover := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if hover:
		sb.bg_color = Color(1.0, 0.97, 0.90, 0.98)
		sb.border_color = Color(0.72, 0.58, 0.25, 0.85)
	else:
		sb.bg_color = Color(1, 1, 1, 0.35)
		sb.border_color = Color(INK.r, INK.g, INK.b, 0.22)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	return sb

func _style_dark(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.19, 0.20, 0.96)))
	btn.add_theme_stylebox_override("hover", _flat(Color(0.31, 0.27, 0.27, 0.96)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.11, 0.12, 0.96)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.40)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.55))

func _style_seal(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.92)))
	btn.add_theme_stylebox_override("hover", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.80)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r * 0.75, SEAL.g * 0.75, SEAL.b * 0.75, 0.95)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87))

# ---- 刷新 ----

func refresh() -> void:
	if _panel == null:
		return
	_title_lb.text = "整备 · 出战" if _battle_mode else "整备 · 阵容"
	if _battle_mode:
		_sub_lb.text = "第一次出战，先过一遍：点一条栏 → 点人，谁就站那排（前→后＝出手先后，对方先打最前面）\n选好点［确定出战］——以后点［挑战］直接开打"
	else:
		_sub_lb.text = "点一条栏 → 点人，谁就站那排（前→后＝出手先后，对方先打最前面）\n改完点［保存阵容］——以后的挑战照这套来"
	_ok_btn.text = "确定出战" if _battle_mode else "保存阵容"
	# 三条栏
	for i in _slot_cells.size():
		var cell: Dictionary = _slot_cells[i]
		var nm: Label = cell["name_lb"]
		var hint: Label = cell["hint_lb"]
		if i < GameState.formation.size():
			var id := str(GameState.formation[i])
			nm.text = str(GameState.role_data(id).get("name", id))
			nm.add_theme_color_override("font_color", INK)
			hint.text = "点我换人 / 撤下"
		else:
			nm.text = "（空）"
			nm.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.40))
			hint.text = "点我安排这一排"
	# 宠物（㊿z9 修）
	var fpid := str(GameState.pet_follow)
	if fpid == "":
		fpid = GameState.pet_cur()
	var pd: Dictionary = DataPets.of(fpid)
	if pd.is_empty():
		_pet_lb.text = "（还没有）——把村子修出一段，去后山看看"
		_pet_btn.visible = false
	else:
		var pfx := DataPets.fx_text(GameState.pet_fx_of(fpid))
		var following := str(GameState.pet_follow) == fpid
		_pet_lb.text = DataPets.name_of(fpid) + " · " + (pfx if pfx != "" else "——") + "（只给加成，不参战）｜" + ("随行中" if following else "留在村里")
		_pet_btn.visible = true
		_pet_btn.text = "留在村里" if following else "叫它跟上"

# ---- 点击 ----

func _on_slot(i: int) -> void:
	_open_picker(i)

func _on_pet_toggle() -> void:
	var pid := str(GameState.pet_follow)
	if pid == "":
		pid = GameState.pet_cur()
	if pid == "":
		_msg_lb.text = "还没有宠物——把村子修出一段，去后山看看"
		return
	_msg_lb.text = GameState.pet_follow_toggle(pid)
	refresh()

func _on_ok() -> void:
	if GameState.formation.is_empty():
		_msg_lb.text = "至少要有一个人出战"
		return
	GameState.formation_intro_done = true
	close()
	if _battle_mode:
		confirmed.emit(_stage_i)
	else:
		saved.emit()

func _on_back() -> void:
	_close_picker()
	close()
	cancelled.emit()

# ---- 开合 ----

func open_for_stage(i: int) -> void:
	_stage_i = i
	_battle_mode = true
	_msg_lb.text = ""
	refresh()
	visible = true

func open_config() -> void:
	_battle_mode = false
	_msg_lb.text = ""
	refresh()
	visible = true

func close() -> void:
	if not visible:
		return
	UiKit.hide_panel(self)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_back()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_on_back()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back()
