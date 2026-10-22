extends Control
# 共用查看面板（仓库物品 / 装备栏 / 功法 / 绝学）：左立绘、右属性、下按钮，点窗外关闭
const UiKit := preload("res://shared/ui_kit.gd")
signal closed
const STAT_CN := {"atk": "攻击", "dmg": "伤害", "def": "防御", "hp": "气血", "crit": "暴击", "crit_dmg": "暴击伤害", "spd": "速度", "speed": "速度", "dodge": "闪避"}
const STAT_ICON := {"atk": "atk", "dmg": "dmg", "def": "def", "hp": "hp", "crit": "crit", "crit_dmg": "crit_dmg", "spd": "speed", "speed": "speed", "dodge": "speed"}
var _dim: ColorRect
var _box: Panel
var _art: TextureRect
var _name: Label
var _quality: Label
var _stats: VBoxContainer
var _desc: Label
var _sell: Button
var _equip: Button
var _confirm: Panel
var _confirm_lb: Label
var _price := 0
var _data: Dictionary = {}
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 65
	visible = false
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.04, 0.03, 0.02, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_outside)
	add_child(_dim)
	_box = Panel.new()
	_box.position = Vector2(50, 230)
	_box.size = Vector2(620, 820)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.955, 0.937, 0.886, 0.99)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.72, 0.58, 0.25, 0.85)
	sb.set_border_width_all(2)
	_box.add_theme_stylebox_override("panel", sb)
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.gui_input.connect(func(_e: InputEvent) -> void: pass)
	add_child(_box)
	_art = TextureRect.new()
	_art.position = Vector2(22, 22)
	_art.size = Vector2(250, 380)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_art)
	_name = _lb(24, Color(0.14, 0.13, 0.15))
	_name.position = Vector2(292, 20)
	_name.size = Vector2(300, 60)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_name)
	_quality = _lb(18, Color(0.55, 0.22, 0.18))
	_quality.position = Vector2(292, 82)
	_quality.size = Vector2(300, 30)
	_box.add_child(_quality)
	_stats = VBoxContainer.new()
	_stats.position = Vector2(292, 120)
	_stats.size = Vector2(300, 290)
	_stats.add_theme_constant_override("separation", 8)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_stats)
	_desc = _lb(15, Color(0.24, 0.21, 0.17, 0.86))
	_desc.position = Vector2(24, 420)
	_desc.size = Vector2(572, 250)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_desc)
	_sell = UiKit.make_button(_box, Vector2(60, 720), Vector2(220, 62), "卖 出", 22)
	_sell.pressed.connect(_ask_sell)
	_equip = UiKit.make_button(_box, Vector2(320, 720), Vector2(220, 62), "装 备", 22)
	_equip.pressed.connect(_do_equip)
	_equip.visible = false
	_confirm = Panel.new()
	_confirm.position = Vector2(80, 360)
	_confirm.size = Vector2(460, 240)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.97, 0.95, 0.90, 1.0)
	csb.set_corner_radius_all(4)
	csb.border_color = Color(0.68, 0.15, 0.12, 0.8)
	csb.set_border_width_all(2)
	_confirm.add_theme_stylebox_override("panel", csb)
	_confirm.visible = false
	_box.add_child(_confirm)
	_confirm_lb = _lb(22, Color(0.14, 0.13, 0.15))
	_confirm_lb.position = Vector2(20, 40)
	_confirm_lb.size = Vector2(420, 70)
	_confirm_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm.add_child(_confirm_lb)
	var b_ok := UiKit.make_button(_confirm, Vector2(40, 150), Vector2(170, 60), "卖 出", 20)
	b_ok.pressed.connect(_do_sell)
	var b_no := UiKit.make_button(_confirm, Vector2(250, 150), Vector2(170, 60), "取 消", 20)
	b_no.pressed.connect(func() -> void: _confirm.visible = false)
func _lb(fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
func _on_outside(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		close()
	elif ev is InputEventScreenTouch and ev.pressed:
		close()
func show_item(d: Dictionary) -> void:
	_data = d
	_price = int(d.get("price", 0))
	_name.text = str(d.get("title", ""))
	_quality.text = str(d.get("quality", ""))
	_art.texture = d.get("art")
	for c in _stats.get_children():
		c.queue_free()
	for row_v in (d.get("stats", []) as Array):
		var row: Dictionary = row_v
		var key := str(row.get("key", ""))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(34, 34)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = load("res://assets/ui/stats/" + str(STAT_ICON.get(key, "quality")) + ".png")
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var lb := _lb(18, Color(0.24, 0.21, 0.17))
		lb.custom_minimum_size = Vector2(140, 34)
		lb.text = str(row.get("label", STAT_CN.get(key, key)))
		h.add_child(lb)
		var vb := _lb(19, Color(0.55, 0.22, 0.18))
		vb.custom_minimum_size = Vector2(90, 34)
		vb.text = "+" + str(int(row.get("value", 0)))
		vb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(vb)
		_stats.add_child(h)
	_desc.text = str(d.get("desc", ""))
	_sell.visible = d.get("on_sell") != null and _price > 0
	_equip.visible = d.get("on_equip") != null
	_confirm.visible = false
	visible = true
func _ask_sell() -> void:
	_confirm_lb.text = "确定卖出？\n+" + str(_price) + " 两"
	_confirm.visible = true
func _do_sell() -> void:
	var cb = _data.get("on_sell")
	if cb != null and cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call()
	close()
func _do_equip() -> void:
	var cb = _data.get("on_equip")
	if cb != null and cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call()
	close()
func close() -> void:
	visible = false
	closed.emit()
