extends Control
# 江湖图：一张可拖动的连续大地图，不再是五个按钮。
# 区块按探索状态显形；未探索盖墨雾，已探索显示地形与地标。

signal entered(region: int)
signal closed

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")

const MAP_W := 1100.0
const MAP_H := 1500.0
const REGION_RECTS := [
	Rect2(80, 170, 410, 330),
	Rect2(650, 150, 400, 350),
	Rect2(330, 620, 450, 360),
	Rect2(70, 1080, 410, 320),
	Rect2(650, 1060, 410, 340),
]
const CENTERS := [Vector2(285, 335), Vector2(850, 325), Vector2(555, 800), Vector2(275, 1240), Vector2(855, 1230)]
const LANDMARK_NAMES := {"house": "竹屋", "sect": "山门", "merchant": "货郎", "temple": "破庙", "well": "古井", "tea": "茶棚", "snow_cave": "雪洞", "mine": "矿洞", "ferry": "渡口", "hunter": "猎户", "herb_garden": "药圃", "wuxia": "轮回台", "redwater": "赤水寨", "broker": "听雨楼", "north": "黑风寨", "outpost": "北境哨"}

class MapCanvas extends Control:
	var host = null
	func _draw() -> void:
		if host != null:
			host._draw_map(self)

var _sub_lb: Label
var _hint_lb: Label
var _buttons: Array = []
var _canvas
var _scroll: ScrollContainer
var _map_font: Font = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_map_font = UiKit.font()
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.66)
	var panel := UiKit.make_paper_panel(veil, Rect2(30, 105, 660, 1070))
	panel.add_theme_stylebox_override("panel", UiKit.paper_box(1.0))
	var title := UiKit.make_label(panel, Vector2(0, 20), Vector2(660, 46), 34, UiKit.INK)
	UiKit.set_text(title, "江 湖 图")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lb = UiKit.make_label(panel, Vector2(0, 70), Vector2(660, 26), 18, UiKit.DIM)
	_sub_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_scroll = ScrollContainer.new()
	UiKit.drag_scroll(_scroll)
	_scroll.position = Vector2(22, 108)
	_scroll.size = Vector2(616, 760)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.get_v_scroll_bar().visible = false
	_scroll.get_h_scroll_bar().visible = false
	_scroll.get_v_scroll_bar().modulate.a = 0.0
	_scroll.get_h_scroll_bar().modulate.a = 0.0
	panel.add_child(_scroll)
	_canvas = MapCanvas.new()
	_canvas.host = self
	_canvas.custom_minimum_size = Vector2(MAP_W, MAP_H)
	_canvas.size = Vector2(MAP_W, MAP_H)
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_canvas)

	_buttons = []
	for i in 5:
		var r: Rect2 = REGION_RECTS[i]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = r.position
		b.size = r.size
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		var empty := StyleBoxEmpty.new()
		b.add_theme_stylebox_override("normal", empty)
		b.add_theme_stylebox_override("hover", empty)
		b.add_theme_stylebox_override("pressed", empty)
		b.pressed.connect(_pick.bind(i))
		_canvas.add_child(b)
		_buttons.append(b)

	_hint_lb = UiKit.make_label(panel, Vector2(30, 884), Vector2(600, 72), 20, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.78))
	_hint_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := UiKit.make_button(panel, Vector2(220, 975), Vector2(220, 54), "返 回", 22)
	back.pressed.connect(close)
	visible = false

func open() -> void:
	visible = true
	_hint_lb.text = "拖动地图 · 点区块进入。石 / 雪需舆图开。"
	_refresh()
	_scroll_to_region(GS.current_region)

func close() -> void:
	visible = false
	closed.emit()

func _refresh() -> void:
	var atlas := GS.material_count("atlas")
	_sub_lb.text = "本世界 · 第 " + str(GS.world_tier) + " 档 · 舆图 " + str(atlas) + " 张 · 难度 " + _diff_name(GS.world_difficulty)
	_canvas.queue_redraw()

func _scroll_to_region(i: int) -> void:
	if _scroll == null or _canvas == null:
		return
	var c: Vector2 = CENTERS[clampi(i, 0, 4)]
	await get_tree().process_frame
	_scroll.scroll_horizontal = int(maxf(0.0, c.x - _scroll.size.x * 0.5))
	_scroll.scroll_vertical = int(maxf(0.0, c.y - _scroll.size.y * 0.5))

func _diff_name(d: int) -> String:
	return ["简单", "普通", "困难"][clampi(d - 1, 0, 2)]

func _pick(i: int) -> void:
	if GS.region_unlocked_at(i):
		entered.emit(i)
		return
	var cost := GS.region_cost(i)
	if GS.material_count("atlas") < cost:
		_hint_lb.text = "雾里是「" + str(GS.REGION_NAMES[i]) + "」——开图要舆图 ×" + str(cost) + "。"
		return
	GS.add_material("atlas", -cost)
	GS.region_unlocked[i] = true
	GS.save_game()
	_hint_lb.text = str(GS.REGION_NAMES[i]) + " 开了。再点一次进去。"
	_refresh()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

# ---------- 地图绘制 ----------

func _draw_map(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_W, MAP_H)), Color("#d9c9a6"))
	# 旧纸斑驳
	for i in 90:
		var p := Vector2((i * 137) % int(MAP_W), (i * 311) % int(MAP_H))
		c.draw_circle(p, 1.5, Color(0.35, 0.28, 0.18, 0.08))
	# 路
	var roads := [[0, 2], [1, 2], [2, 3], [2, 4], [0, 1]]
	for rd in roads:
		c.draw_dashed_line(CENTERS[int(rd[0])], CENTERS[int(rd[1])], Color(0.38, 0.28, 0.16, 0.5), 4.0, 12.0)
	for i in 5:
		_draw_region(c, i)
	# 罗盘
	c.draw_circle(Vector2(1010, 90), 40, Color(0.25, 0.20, 0.14, 0.12))
	c.draw_string(_map_font if _map_font != null else ThemeDB.fallback_font, Vector2(988, 70), "北", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#5a3a20"))
	c.draw_line(Vector2(1010, 84), Vector2(1010, 112), Color("#5a3a20"), 4.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(1010, 72), Vector2(1000, 88), Vector2(1020, 88)]), Color("#5a3a20"))

func _draw_region(c: Control, i: int) -> void:
	var center: Vector2 = CENTERS[i]
	var seen: bool = bool(GS.region_seen[i]) if i < GS.region_seen.size() else false
	var unlocked := GS.region_unlocked_at(i)
	var nm := str(GS.REGION_NAMES[i])
	var col := _biome_col(i)
	# 地形底
	c.draw_circle(center, 180.0, Color(col.r, col.g, col.b, 0.75))
	c.draw_circle(center + Vector2(-40, 20), 130.0, Color(col.r * 1.08, col.g * 1.08, col.b * 1.08, 0.55))
	# 地形细节
	match i:
		0:
			for k in 3:
				var p := center + Vector2(-110 + k * 80, 25)
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(-55, 20), p + Vector2(0, -70), p + Vector2(55, 20)]), Color("#6f6a58"))
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(-30, 20), p + Vector2(0, -40), p + Vector2(30, 20)]), Color("#d8d0bc"))
		1:
			for k in 3:
				c.draw_arc(center + Vector2(-100 + k * 45, 20), 60, 0.1, PI - 0.1, 20, Color("#5f7f8a"), 4.0)
		2:
			for k in 7:
				var p := center + Vector2(-140 + (k % 4) * 75, -60 + int(k / 4) * 90)
				c.draw_line(p, p + Vector2(0, 40), Color("#4a3a24"), 5.0)
				c.draw_circle(p + Vector2(0, -8), 24, Color("#4e6a3a"))
		3:
			for k in 5:
				var p := center + Vector2(-120 + k * 55, 30 + (k % 2) * 40)
				c.draw_circle(p, 28, Color("#5a5148"))
		4:
			for k in 12:
				var p := center + Vector2(-130 + (k % 4) * 80, -60 + int(k / 4) * 70)
				c.draw_circle(p, 3, Color("#eef4f5"))
	# 未探索：只留雾，不写字
	if not seen:
		_draw_fog(c, center)
		return
	# 名称 / 状态
	var mf: Font = _map_font if _map_font != null else ThemeDB.fallback_font
	c.draw_string(mf, center + Vector2(-120, -70), nm, HORIZONTAL_ALIGNMENT_LEFT, 240, 32, Color("#2a241c"))
	c.draw_string(mf, center + Vector2(-120, -36), "D" + str(GS.REGION_DIFFS[i]) + " · " + str(GS.REGION_BOSSES[i]), HORIZONTAL_ALIGNMENT_LEFT, 240, 18, Color("#5a4a34"))
	if not unlocked:
		c.draw_string(mf, center + Vector2(-100, 118), "需舆图 ×" + str(GS.region_cost(i)), HORIZONTAL_ALIGNMENT_LEFT, 200, 22, Color("#8d2f2a"))
	# 地标
	var lms: Array = GS.landmarks(i)
	var y := 62.0
	for id_v in lms:
		var id := str(id_v)
		if not LANDMARK_NAMES.has(id):
			continue
		var p2 := center + Vector2(-130, y)
		c.draw_circle(p2 + Vector2(8, -6), 5, Color("#8d2f2a"))
		c.draw_string(_map_font if _map_font != null else ThemeDB.fallback_font, p2 + Vector2(20, 0), str(LANDMARK_NAMES[id]), HORIZONTAL_ALIGNMENT_LEFT, 190, 18, Color("#3a3024"))
		y += 28.0
		if y > 130:
			break
	# 当前区块
	if i == GS.current_region:
		c.draw_arc(center, 186.0, 0, TAU, 64, Color("#8d2f2a"), 5.0)
		c.draw_string(_map_font if _map_font != null else ThemeDB.fallback_font, center + Vector2(-40, -110), "所 在", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#8d2f2a"))

func _draw_fog(c: Control, center: Vector2) -> void:
	# 一片厚云：多个同色圆叠起来，地形完全看不见，边缘是软的。
	var soft := Color(0.075, 0.085, 0.065, 0.28)
	for k in 8:
		var ang0 := float(k) * TAU / 8.0
		c.draw_circle(center + Vector2(cos(ang0), sin(ang0)) * 88.0, 138.0, soft)
	var fog := Color(0.10, 0.115, 0.09, 1.0)
	for k in 8:
		var ang := float(k) * TAU / 8.0
		c.draw_circle(center + Vector2(cos(ang), sin(ang)) * 72.0, 118.0, fog)
	c.draw_circle(center, 150.0, fog)
	# 云顶一点层次，不露地形
	for k in 5:
		var ang2 := float(k) * TAU / 5.0 + 0.6
		c.draw_circle(center + Vector2(cos(ang2), sin(ang2)) * 78.0, 42.0, Color(0.17, 0.18, 0.14, 0.12))
	# v245：雾区也要看得出"这里有一块地方"，并写清未探索
	c.draw_arc(center, 152.0, 0.0, TAU, 56, Color(0.72, 0.58, 0.22, 0.32), 2.0)
	c.draw_string(_map_font if _map_font != null else ThemeDB.fallback_font, center + Vector2(-80, 4),
		"未 探 索", HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color(0.78, 0.72, 0.56, 0.88))

func _biome_col(i: int) -> Color:
	return [Color("#9a9a78"), Color("#7898a0"), Color("#6a8a58"), Color("#8a7a68"), Color("#c9d3d6")][clampi(i, 0, 4)]
