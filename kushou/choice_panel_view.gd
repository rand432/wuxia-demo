extends Control
# ============================================================
# kushou/choice_panel_view.gd —— 宝物 / 强化共用的选卡面板
#
#   合并自 treasure_view.gd 与 aug_view.gd 的相同部分：
#   遮罩渐变、双层纸框、标题区、三张卡挂载、隐藏/刷新/放弃按钮、
#   三张卡的弹出与关闭。差异由两个配置项承载：
#     · title（"宝物" / "进阶"）
#     · caption 初值（"选择一件" / 空，强化由战斗层写"强化 N 级"）
#   抽取池、品质、数值、选后结算、刷新费与按钮可用状态仍由战斗层负责。
#   卡牌控件（AugCard）由战斗层通过 card_factory 注入。
# ============================================================
signal hide_pressed
signal refresh_pressed
signal abandon_pressed
signal card_picked(card)

const UI := preload("res://shared/ui_kit.gd")

const W := 720.0
const LIGHT := Color(0.91, 0.87, 0.78)

var cards: Array = []
var refresh_btn: Button = null
var caption: Label = null
var card_factory: Callable = Callable()

var _title := "宝物"
var _caption_text := ""
var _built := false

func configure(title: String, caption_text: String) -> void:
	_title = title
	_caption_text = caption_text

func build() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink_wash := Gradient.new()
	var shade_color := Color(0.10, 0.08, 0.06)
	ink_wash.offsets = PackedFloat32Array([0.0, 0.11, 0.70, 1.0])
	ink_wash.colors = PackedColorArray([Color(shade_color, 0.0), Color(shade_color, 0.25), Color(shade_color, 0.21), Color(shade_color, 0.0)])
	var wash_texture := GradientTexture2D.new()
	wash_texture.gradient = ink_wash
	wash_texture.width = 2
	wash_texture.height = 256
	wash_texture.fill_to = Vector2.DOWN
	var shade := TextureRect.new()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.texture = wash_texture
	shade.position = Vector2(0, 136)
	shade.size = Vector2(W, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var ink := Color(0.13, 0.106, 0.081)
	var rim := Color(0.64, 0.48, 0.29)
	var brass := Color(0.87, 0.73, 0.49)
	_panel(Rect2(52, 166, 616, 498), Color(0.19, 0.15, 0.11, 0.98), 14, rim, 2, self)
	_panel(Rect2(65, 228, 590, 365), ink, 10, Color(0.39, 0.28, 0.18), 1, self)
	_lbl(_title, Vector2(75, 179), Vector2(152, 43), 32, LIGHT, self)
	caption = _lbl(_caption_text, Vector2(223, 182), Vector2(274, 40), 22, brass, self, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("隐藏", Rect2(562, 180, 84, 40), 19, ink, LIGHT, func() -> void: hide_pressed.emit(), self, rim, 1)
	refresh_btn = _btn("刷新 · 0 次", Rect2(106, 602, 240, 47), 20,
		Color(0.30, 0.22, 0.14), LIGHT, func() -> void: refresh_pressed.emit(), self, rim, 1)
	refresh_btn.add_theme_stylebox_override("disabled", refresh_btn.get_theme_stylebox("normal").duplicate())
	refresh_btn.add_theme_color_override("font_disabled_color", Color(0.63, 0.54, 0.43))
	_btn("放弃 · +1 刷新", Rect2(374, 602, 240, 47), 20,
		ink, LIGHT, func() -> void: abandon_pressed.emit(), self, rim, 1)
	for i in 3:
		if not card_factory.is_valid():
			break
		var card: Control = card_factory.call()
		card.size = Vector2(176, 335)
		if card.has_signal("picked"):
			card.picked.connect(func() -> void: card_picked.emit(card))
		add_child(card)
		cards.append(card)

func open() -> void:
	visible = true
	UI.Motion.fade_in(self)
	move_to_front()
	pop_cards()

func close() -> void:
	if not visible:
		return
	hide()
	UI.Motion.stop(self)
	for card in cards:
		UI.Motion.stop(card)

# 卡面数据由战斗层写入，这里只负责位置与出场
func pop_cards() -> void:
	var offered := 0
	for card in cards:
		if not card.o.is_empty():
			offered += 1
	var width := 250.0 if offered < 3 else 176.0
	var left := (W - (width * offered + 16.0 * maxi(0, offered - 1))) * 0.5
	var i := 0
	for card in cards:
		card.visible = not card.o.is_empty()
		if not card.visible:
			UI.Motion.stop(card)
			continue
		card.size.x = width
		var goal := Vector2(left + i * (width + 16.0), 242)
		UI.Motion.pop(card, true, i * 0.05, goal, (i - (offered - 1) * 0.5) * 0.018)
		i += 1

func _panel(rect: Rect2, bg: Color, radius := 8, border := Color(0, 0, 0, 0), bw := 0, parent: Node = null) -> Panel:
	var pnl := Panel.new()
	pnl.position = rect.position
	pnl.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	pnl.add_theme_stylebox_override("panel", sb)
	pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(pnl)
	return pnl

func _lbl(t: String, pos: Vector2, sz: Vector2, fs: int, col: Color, parent: Node = null, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(l)
	return l

func _btn(t: String, rect: Rect2, fs: int, bg: Color, fg: Color, cb: Callable, parent: Node = null,
		border := Color(0.85, 0.66, 0.23, 0.55), bw := 1) -> Button:
	var b := Button.new()
	b.text = t
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate()
	hb.bg_color = bg.lightened(0.08)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)
	if cb.is_valid():
		b.pressed.connect(cb)
	(parent if parent != null else self).add_child(b)
	UI.Motion.bind_button(b)
	return b
