extends Control
# ============================================================
# kushou/draw_view.gd —— 抽卡视图外壳（批次 2 · 第一步）
#
#   负责：抽卡层、抽卡横幅、隐藏/刷新按钮、三张卡的创建与
#         出场 / 收起 / 选中飞入动画。
#   不负责：抽什么卡、灵晶扣费、卡组满判定、吞噬结算（都在战斗层）。
#   卡牌控件由战斗层通过 card_factory 注入（DrawCard 类暂留 battle_ui）。
# ============================================================
signal card_picked(card)
signal refresh_pressed
signal hide_pressed

const UI := preload("res://shared/ui_kit.gd")

const GOLD := Color(0.85, 0.66, 0.23)

var cards: Array = []
var refresh_btn: Button = null
var card_factory: Callable = Callable()
var _banner: Panel = null

func build(charge_text := "抽卡 · 20 灵晶") -> void:
	if _banner != null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner = Panel.new()
	_banner.position = Vector2(230, 162)
	_banner.size = Vector2(260, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.54, 0.23, 0.10)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.95, 0.76, 0.36, 0.9)
	sb.set_border_width_all(2)
	_banner.add_theme_stylebox_override("panel", sb)
	add_child(_banner)
	UI.Motion.breathe(_banner)
	_lbl(charge_text, Vector2(0, 0), Vector2(260, 42), 20, Color(0.97, 0.90, 0.74), _banner, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("隐藏", Rect2(620, 162, 72, 32), 17, Color(0.09, 0.08, 0.07, 0.98), GOLD,
		func() -> void: hide_pressed.emit(), self)
	for i in 3:
		if not card_factory.is_valid():
			break
		var d: Control = card_factory.call()
		d.position = Vector2(30 + i * 220, 220)
		d.set_meta("base", d.position)
		d.pivot_offset = Vector2(100, 150)
		d.size = Vector2(200, 300)
		if d.has_signal("picked"):
			d.picked.connect(func() -> void: card_picked.emit(d))
		add_child(d)
		cards.append(d)
	refresh_btn = _btn("刷新 · 5 灵晶", Rect2(250, 540, 220, 56), 20, Color(0.09, 0.08, 0.07, 0.98), GOLD,
		func() -> void: refresh_pressed.emit(), self)

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

func pop_cards() -> void:
	for i in cards.size():
		var card: Control = cards[i]
		var base: Vector2 = card.get_meta("base", Vector2(30 + i * 220, 220))
		card.visible = true
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		UI.Motion.pop(card, true, i * 0.055, base, (i - 1) * 0.025)

# 选卡后：其余卡变暗，选中卡飞向目标格；结束后回调战斗层
func fly_card(card: Control, target_local: Vector2, done: Callable) -> void:
	if card == null:
		done.call()
		return
	for other in cards:
		UI.Motion.stop(other)
		if other != card:
			other.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tw0 := create_tween()
			tw0.tween_property(other, "modulate:a", 0.28, 0.18)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 3
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "position", target_local, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "scale", Vector2(0.32, 0.32), 0.34)
	tw.tween_property(card, "rotation", 0.0, 0.34)
	tw.tween_property(card, "modulate:a", 0.42, 0.34)
	tw.chain().tween_callback(done)

func fade_cards_out() -> void:
	for card in cards:
		UI.Motion.stop(card)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "scale", Vector2(0.72, 0.72), 0.16)
		tw.tween_property(card, "modulate:a", 0.0, 0.16)

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
