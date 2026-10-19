extends Control
# 入图前的区块选择：初始 3 区块直接进；石 / 雪消耗舆图解锁。

signal entered(region: int)
signal closed

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")

var _sub_lb: Label
var _hint_lb: Label
var _buttons: Array = []
var _markers: Array = []
var _fog_rects: Array = []
const LANDMARK_NAMES := {"house": "竹屋", "sect": "山门", "merchant": "货郎", "temple": "破庙", "well": "古井", "tea": "茶棚", "snow_cave": "雪洞", "mine": "矿洞", "ferry": "渡口", "hunter": "猎户", "herb_garden": "药圃", "redwater": "赤水寨", "broker": "听雨楼", "north": "黑风寨", "outpost": "北境哨"}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.66)
	var panel := UiKit.make_paper_panel(veil, Rect2(40, 150, 640, 940))
	panel.add_theme_stylebox_override("panel", UiKit.paper_box(1.0))
	var title := UiKit.make_label(panel, Vector2(0, 22), Vector2(640, 46), 34, UiKit.INK)
	UiKit.set_text(title, "江 湖 图")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lb = UiKit.make_label(panel, Vector2(0, 74), Vector2(640, 24), 15, UiKit.DIM)
	_sub_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var map_bg := ColorRect.new()
	map_bg.color = Color("#15130f")
	map_bg.position = Vector2(30, 112)
	map_bg.size = Vector2(580, 500)
	map_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(map_bg)
	var pos := [Vector2(60, 150), Vector2(350, 170), Vector2(205, 315), Vector2(60, 460), Vector2(350, 480)]
	var links := [[0, 1], [0, 2], [1, 2], [2, 3], [2, 4], [3, 4]]
	for lk in links:
		var line := Line2D.new()
		line.points = PackedVector2Array([pos[int(lk[0])] + Vector2(115, 35), pos[int(lk[1])] + Vector2(115, 35)])
		line.width = 3.0
		line.default_color = Color(0.55, 0.45, 0.2, 0.45)
		line.z_index = 0
		panel.add_child(line)
	var north := UiKit.make_label(panel, Vector2(520, 122), Vector2(60, 22), 12, Color(0.62, 0.55, 0.4, 0.8))
	UiKit.set_text(north, "北 ↑")
	for i in 5:
		var fog := ColorRect.new()
		fog.color = Color(0.02, 0.02, 0.02, 0.72)
		fog.position = pos[i] + Vector2(-12, -12)
		fog.size = Vector2(254, 120)
		fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(fog)
		_fog_rects.append(fog)
	for i in 5:
		var b := UiKit.make_button(panel, pos[i], Vector2(230, 70), "", 16)
		b.pressed.connect(_pick.bind(i))
		_buttons.append(b)
		var mk := UiKit.make_label(panel, pos[i] + Vector2(0, 76), Vector2(230, 18), 12, Color("#c9a64a"))
		mk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_markers.append(mk)
	_hint_lb = UiKit.make_label(panel, Vector2(40, 640), Vector2(560, 64), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	_hint_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := UiKit.make_button(panel, Vector2(220, 820), Vector2(200, 46), "回 村", 18)
	back.pressed.connect(close)
	visible = false

func open() -> void:
	visible = true
	_hint_lb.text = "选一个区块进去。石 / 雪要舆图开。"
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func _refresh() -> void:
	var atlas := GS.material_count("atlas")
	_sub_lb.text = "本世界 · 第 " + str(GS.world_tier) + " 档 · 舆图 " + str(atlas) + " 张"
	for i in 5:
		var b: Button = _buttons[i]
		var nm := str(GS.REGION_NAMES[i])
		var diff := int(GS.REGION_DIFFS[i])
		var boss := str(GS.REGION_BOSSES[i])
		var seen: bool = bool(GS.region_seen[i]) if GS.region_seen.size() > i else false
		if i < _fog_rects.size():
			_fog_rects[i].visible = not seen
		if i < _markers.size():
			var names: Array = []
			if seen:
				for id_v in GS.landmarks(i):
					var idn := str(id_v)
					if LANDMARK_NAMES.has(idn):
						names.append(str(LANDMARK_NAMES[idn]))
					if names.size() >= 3:
						break
			_markers[i].text = " · ".join(PackedStringArray(names)) if not names.is_empty() else ("尚未记下地标" if seen else "")
		if not seen:
			b.text = nm + " · 未探索" + (" · 需舆图 ×" + str(GS.region_cost(i)) if not GS.region_unlocked_at(i) else "")
		elif GS.region_unlocked_at(i):
			b.text = nm + " · D" + str(diff) + " · " + boss
		else:
			b.text = nm + " · D" + str(diff) + " · " + boss + " · 需舆图 ×" + str(GS.region_cost(i))

func _pick(i: int) -> void:
	if GS.region_unlocked_at(i):
		entered.emit(i)
		return
	var cost := GS.region_cost(i)
	if GS.material_count("atlas") < cost:
		_hint_lb.text = "舆图不够——开" + str(GS.REGION_NAMES[i]) + "要 " + str(cost) + " 张。"
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
