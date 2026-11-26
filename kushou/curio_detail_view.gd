extends Control
# ============================================================
# kushou/curio_detail_view.gd —— 奇物详情弹窗（批次 3 · 第一块）
#
#   只负责显示：遮罩、纸框、图标、名称、档位、四行数据、下一档提示。
#   奇物状态 / 冷却 / 等级 / 施放仍由战斗层维护；点遮罩或 × 只发 closed。
# ============================================================
signal closed

const UI := preload("res://shared/ui_kit.gd")
const CurioData := preload("res://shared/curio_data.gd")

const INK := Color(0.13, 0.12, 0.11)
const DIM := Color(0.42, 0.38, 0.32)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func present(info: Dictionary, curio_id: String, level: int, uses: int, frame: Texture2D, icon: Texture2D) -> void:
	var has := not info.is_empty()
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 32
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	add_child(dim)
	var holder := Control.new()
	holder.name = "CurioSheet"
	holder.position = Vector2(120, 340)
	holder.size = Vector2(480, 470)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(holder)
	var has_frame := has and frame != null
	if has_frame:
		var fr := TextureRect.new()
		fr.texture = frame
		fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fr.stretch_mode = TextureRect.STRETCH_SCALE
		fr.position = Vector2.ZERO
		fr.size = Vector2(480, 470)
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(fr)
	_panel(Rect2(0, 0, 480, 470), Color(0.97, 0.93, 0.85, 0.20) if has_frame else Color(0.97, 0.93, 0.85, 0.99), 10,
		Color(0.85, 0.66, 0.23, 0.0) if has_frame else Color(0.85, 0.66, 0.23), 0 if has_frame else 3, holder)
	_btn("×", Rect2(436, 12, 34, 30), 20, Color(0.97, 0.93, 0.85), DIM,
		func() -> void: closed.emit(), holder)
	if not has:
		_lbl("本局没有携带奇物", Vector2(0, 40), Vector2(480, 44), 28, INK, holder, HORIZONTAL_ALIGNMENT_CENTER)
		_lbl("在局外「奇物」页选择一件再出击", Vector2(0, 96), Vector2(480, 30), 18, DIM, holder, HORIZONTAL_ALIGNMENT_CENTER)
		UI.Motion.pop(holder, false, 0.0)
		return
	# 圆徽里放物件图标（1024 原图，缩到 110 仍清晰）
	if icon != null:
		var ic := TextureRect.new()
		ic.texture = icon
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_SCALE
		ic.position = Vector2(185, 52)
		ic.size = Vector2(110, 110)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(ic)
	_lbl(str(info.get("name", "")), Vector2(0, 176), Vector2(480, 40), 30, INK, holder, HORIZONTAL_ALIGNMENT_CENTER)
	_panel(Rect2(148, 220, 184, 26), Color(0.62, 0.44, 0.12, 0.92), 5, Color(0.62, 0.44, 0.12), 0, holder)
	_lbl("奇物 · Lv %d" % level, Vector2(148, 222), Vector2(184, 22), 14, Color(0.99, 0.95, 0.87), holder, HORIZONTAL_ALIGNMENT_CENTER)
	var cdv := float(info.get("cd", 0.0))
	var rows := [
		["当前", CurioData.level_text(curio_id, level)],
		["触发", str(info.get("trig", ""))],
		["冷却", ("%d 秒（自动使用，不用操作）" % int(cdv)) if cdv > 0.0 else "被动 · 常驻"],
		["本局", "已触发 %d 次" % uses],
	]
	var y := 262.0
	for r in rows:
		_lbl(str(r[0]), Vector2(26, y), Vector2(70, 22), 14, Color(0.47, 0.41, 0.33), holder)
		_lbl(str(r[1]), Vector2(92, y - 3), Vector2(360, 24), 17, INK, holder)
		y += 38.0
	if level < 5:
		_lbl("下一档：%s" % CurioData.level_text(curio_id, level + 1),
			Vector2(26, 406), Vector2(430, 22), 15, Color(0.47, 0.41, 0.33), holder)
	_lbl("全自动使用，玩家不需要点它；点这里只是看详情", Vector2(26, 436), Vector2(430, 22), 14, Color(0.47, 0.41, 0.33), holder)
	UI.Motion.pop(holder, false, 0.0)
	UI.Motion.breathe(holder)

func close() -> void:
	hide()
	var sheet := get_node_or_null("CurioSheet") as Control
	if sheet != null:
		UI.Motion.stop(sheet)
	queue_free()

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
