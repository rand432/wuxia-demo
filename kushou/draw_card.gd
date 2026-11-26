extends Control
# ============================================================
# kushou/draw_card.gd —— 抽卡卡面控件（从 battle_ui.gd 迁出，批次 5）
#   普通卡：CardFrame 五档花边 + 组合进度；炫卡：七彩描边 + 吞噬说明。
#   只负责画与发 picked 信号；池子/支付/羁绊/吞噬结算仍在战斗层。
# ============================================================
const F := preload("res://fonts/ink.ttf")
var QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
const CF := preload("res://kushou/card_frame.gd")
signal picked
var data: Dictionary = {}
var progress := 0          # 该卡所属组合的当前进度（由外壳写入）
var _art_rect: TextureRect
var _shadow := StyleBoxFlat.new()
func set_art(texture: Texture2D) -> void:
	_art_rect.texture = texture
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shadow.bg_color = Color(0.19, 0.14, 0.09)
	_shadow.set_corner_radius_all(6)
	_shadow.shadow_color = Color(0.035, 0.022, 0.014, 0.72)
	_shadow.shadow_size = 12
	_shadow.shadow_offset = Vector2(0, 6)
	_art_rect = TextureRect.new()
	_art_rect.position = Vector2(22, 45)
	_art_rect.size = Vector2(156, 139)
	_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_rect)
func _draw() -> void:
	if data.is_empty():
		if _art_rect != null:
			_art_rect.visible = false
		return
	if _art_rect != null:
		_art_rect.visible = true
	var q := clampi(int(data.get("quality", 3)) - 1, 0, 4)
	var accent: Color = QC[q]
	draw_style_box(_shadow, Rect2(Vector2(1, 1), size - Vector2(2, 2)))
	var framed := CF.draw_on(self, int(data.get("quality", 3)), size)
	if framed:
		CF.content_panel(self, Rect2(18, 40, size.x - 36, size.y - 58))
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.93, 0.86, 0.99)
		sb.set_corner_radius_all(9)
		sb.border_color = QC[q]
		sb.set_border_width_all(6)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
	if bool(data.get("shiny", false)):
		# 炫卡：七彩描边由外向内
		var cols := [Color(0.85,0.28,0.30), Color(0.93,0.58,0.22), Color(0.90,0.80,0.28),
			Color(0.38,0.70,0.42), Color(0.32,0.62,0.85), Color(0.62,0.42,0.82)]
		for i in 6:
			var sp := StyleBoxFlat.new()
			sp.bg_color = Color(0, 0, 0, 0)
			sp.set_corner_radius_all(10)
			sp.border_color = cols[i]
			sp.set_border_width_all(2)
			draw_style_box(sp, Rect2(Vector2(-2.0 - float(i) * 2.0, -2.0 - float(i) * 2.0),
				size + Vector2(4.0 + float(i) * 4.0, 4.0 + float(i) * 4.0)))
	var artwork_center := Vector2(size.x * 0.5, 113)
	draw_circle(artwork_center, 55.0, Color(accent, 0.068), true, -1.0, true)
	draw_arc(artwork_center, 58.0, 0.0, TAU, 40, Color(accent, 0.26), 1.0, true)
	draw_rect(Rect2(12, 8, size.x - 24, 31), Color(accent.darkened(0.20), 0.96))
	draw_string(F, Vector2(0, 32), str(data.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, size.x, 23, Color(0.99, 0.95, 0.83))
	draw_rect(Rect2(14, 188, size.x - 28, 34), Color(accent, 0.13))
	draw_string(F, Vector2(20, 211), str(data.get("own_text", "")), HORIZONTAL_ALIGNMENT_CENTER, size.x - 40, 19, Color(0.14,0.11,0.08))
	draw_line(Vector2(18, 226), Vector2(size.x - 18, 226), Color(accent, 0.48), 1.0, true)
	if bool(data.get("shiny", false)):
		# 炫卡：不显示组合进度，改成吞噬说明
		draw_string(F, Vector2(20, 240), "进卡组即吞尽全部家传卡", HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 16, Color(0.42,0.30,0.12))
		draw_string(F, Vector2(20, 264), "每吞一张：灵晶+20 · 文钱+150", HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 14, Color(0.2,0.16,0.12))
		draw_string(F, Vector2(20, 284), "　　　　　技能伤害 +10%", HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 14, Color(0.2,0.16,0.12))
	else:
		draw_string(F, Vector2(20, 246), str(data.get("combo_name", "")) + " " + str(progress) + "/" + str(data.get("set_size", 0)), HORIZONTAL_ALIGNMENT_LEFT, 140, 18, Color(0.42,0.30,0.12))
		draw_string(F, Vector2(20, 280), str(data.get("trigger", "")) + "：" + str(data.get("combo_text", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 17, Color(0.2,0.16,0.12))
func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		picked.emit()
