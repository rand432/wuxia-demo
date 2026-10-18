extends Node2D
# ============================================================
# explore_map.gd —— 游历 2.0 · 可走的大地图（v0.4 原型）
#
# v0.4：
#   1. 相机跟随玩家：人物始终居中，地图随走随滚
#   2. 地图放大到 24×30；没走过的格子压暗，走一步亮一圈
#   3. AStarGrid2D 寻路 + 程序化环境/敌人模型
#   4. 战斗复用 DuelBattle.run；战斗时关相机、藏地图、记/还原玩家位置
# ============================================================

const DuelBattle := preload("res://journey/duel_battle.gd")
const RunState := preload("res://shared/run_state.gd")
const GameState := preload("res://shared/game_state.gd")
const FxLayer := preload("res://journey/fx_layer.gd")
const ActorFactory := preload("res://journey/actor_factory.gd")

const MAP_W := 24
const MAP_H := 30
const TILE := 72.0
const WALK_SPEED := 260.0
const ENEMY_REACH := 52.0
const REVEAL_RADIUS := 3
const HOUSE_CELL := Vector2i(6, 20)
const CHEST_CELLS := [
	Vector2i(0, 0), Vector2i(23, 0), Vector2i(0, 29),
	Vector2i(23, 29), Vector2i(10, 13),
]
const ROOM_W := 10
const ROOM_H := 10

const OBSTACLES := [
	Vector2i(7, 21), Vector2i(7, 22), Vector2i(13, 24),
	Vector2i(4, 18), Vector2i(18, 19), Vector2i(3, 27),
	Vector2i(20, 12), Vector2i(9, 12), Vector2i(15, 8),
]

signal finished

var _state: RunState
var _player: Node2D
var _camera: Camera2D
var _fx: FxLayer
var _enemies: Array = []
var _astar: AStarGrid2D
var _path: Array = []
var _path_i := 0
var _moving := false
var _busy := false
var _battle_active := false
var _click_pos := Vector2.ZERO
var _has_click := false
var _target_enemy: Node2D = null
var _role_id := "player"
var _diff := 1
var _explored := {}
var _reveal_t := 0.0
var _map_pos_before_battle := Vector2.ZERO
var _in_house := false
var _house_pos := Vector2.ZERO
var _chest_open := {}
var _msg := ""
var _msg_t := 0.0
var _toast_layer: CanvasLayer
var _toast: Label

func _ready() -> void:
	var dep: Dictionary = GameState.deploy_take()
	var role_id := "player"
	var diff := 1
	var party: Array = []
	var fates: Array = []
	if not dep.is_empty():
		role_id = str(dep.get("role", "player"))
		diff = int(dep.get("diff", 1))
		party = (dep.get("party", []) as Array).duplicate()
		fates = (dep.get("fates", []) as Array).duplicate()
	setup(role_id, diff, party, fates)

func setup(role_id := "player", diff := 1, party: Array = [], fates: Array = []) -> void:
	_role_id = role_id
	_diff = diff
	_state = RunState.new()
	_state.reset([])
	var use_party: Array = party.duplicate()
	if use_party.is_empty():
		use_party = [role_id]
	_state.begin_formal(use_party, _diff, fates)
	_build_astar()
	_spawn_player()
	_spawn_fx()
	_spawn_enemies()
	_spawn_toast()
	_reveal_at(_player.position)
	queue_redraw()

func _build_astar() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, MAP_W, MAP_H)
	_astar.cell_size = Vector2(TILE, TILE)
	_astar.offset = Vector2(TILE * 0.5, TILE * 0.5)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for cell in OBSTACLES:
		_astar.set_point_solid(cell, true)

func _spawn_player() -> void:
	_player = ActorFactory.make(_role_id)
	add_child(_player)
	_player.position = _cell_pos(12, 24)
	if _player.has_method("set_equipment"):
		_player.set_equipment(_state.weapon_of_member(_state.member_at(0)), "douli", "short")
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	_camera.enabled = true
	_player.add_child(_camera)
	# setup 时相机还没完全进树，make_current 会抢半拍；推迟到下一帧。
	_camera.call_deferred("make_current")

func _spawn_fx() -> void:
	_fx = FxLayer.new()
	add_child(_fx)

func _spawn_toast() -> void:
	_toast_layer = CanvasLayer.new()
	add_child(_toast_layer)
	_toast = Label.new()
	_toast.position = Vector2(24, 24)
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_color_override("font_color", Color("#f0d68a"))
	_toast.visible = false
	_toast_layer.add_child(_toast)

func _spawn_enemies() -> void:
	var spots := [Vector2i(16, 16), Vector2i(7, 9), Vector2i(19, 5)]
	for i in spots.size():
		_enemies.append(_make_enemy(spots[i], i))

# ---------- 程序化敌人模型 ----------

func _make_enemy(cell: Vector2i, i: int) -> Node2D:
	var e := Node2D.new()
	e.position = _cell_pos(cell.x, cell.y)
	var kind: String = ["竹妖", "野狼", "山贼"][i % 3]
	e.set_meta("foe_name", kind)
	e.set_meta("foe", {"hp": 60 + i * 20, "atk": 8 + i * 2})
	e.set_meta("beaten", false)
	e.draw.connect(func() -> void:
		match kind:
			"竹妖":
				_draw_zhuyiao(e)
			"野狼":
				_draw_wolf(e)
			_:
				_draw_bandit(e)
		e.draw_string(ThemeDB.fallback_font, Vector2(-20, -46), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f0d68a"))
	)
	add_child(e)
	return e

func _draw_zhuyiao(e: Node2D) -> void:
	e.draw_circle(Vector2(0, -10), 16.0, Color("#5b8a4e"))
	e.draw_circle(Vector2(0, -26), 10.0, Color("#79a86a"))
	e.draw_circle(Vector2(-4, -27), 2.0, Color("#1b2417"))
	e.draw_circle(Vector2(4, -27), 2.0, Color("#1b2417"))
	e.draw_line(Vector2(-12, -6), Vector2(-22, 2), Color("#3f6b3a"), 3.0)
	e.draw_line(Vector2(12, -6), Vector2(22, 2), Color("#3f6b3a"), 3.0)
	e.draw_line(Vector2(-6, 4), Vector2(-8, 18), Color("#3f6b3a"), 4.0)
	e.draw_line(Vector2(6, 4), Vector2(8, 18), Color("#3f6b3a"), 4.0)
	e.draw_colored_polygon(PackedVector2Array([Vector2(-18, -34), Vector2(18, -34), Vector2(0, -46)]), Color("#9a7b3f"))

func _draw_wolf(e: Node2D) -> void:
	e.draw_circle(Vector2(0, -8), 18.0, Color("#5d5d57"))
	e.draw_circle(Vector2(0, -8), 12.0, Color("#6e6e66"))
	e.draw_circle(Vector2(16, -22), 9.0, Color("#5d5d57"))
	e.draw_colored_polygon(PackedVector2Array([Vector2(11, -27), Vector2(14, -36), Vector2(18, -30)]), Color("#4d4d47"))
	e.draw_colored_polygon(PackedVector2Array([Vector2(19, -27), Vector2(23, -36), Vector2(25, -28)]), Color("#4d4d47"))
	e.draw_circle(Vector2(19, -24), 1.8, Color("#d8c27a"))
	e.draw_line(Vector2(-12, 4), Vector2(-14, 20), Color("#4d4d47"), 4.0)
	e.draw_line(Vector2(-2, 5), Vector2(-2, 18), Color("#4d4d47"), 4.0)
	e.draw_line(Vector2(8, 5), Vector2(10, 20), Color("#4d4d47"), 4.0)
	e.draw_line(Vector2(-18, -8), Vector2(-30, -16), Color("#4d4d47"), 4.0)

func _draw_bandit(e: Node2D) -> void:
	e.draw_circle(Vector2(0, -8), 15.0, Color("#7a5a3a"))
	e.draw_rect(Rect2(-12, -2, 24, 20), Color("#6b4c30"))
	e.draw_circle(Vector2(0, -28), 9.0, Color("#c89a6a"))
	e.draw_rect(Rect2(-9, -35, 18, 6), Color("#8d2f2a"))
	e.draw_line(Vector2(-12, 2), Vector2(-20, 12), Color("#c89a6a"), 4.0)
	e.draw_line(Vector2(12, 2), Vector2(20, 8), Color("#c89a6a"), 4.0)
	e.draw_line(Vector2(20, 8), Vector2(30, -8), Color("#d8d2c2"), 3.0)

# ---------- 程序化环境 ----------

func _hash(x: int, y: int, salt: int) -> float:
	return float(abs(hash(Vector3i(x, y, salt))) % 1000) / 1000.0

func _cell_pos(x: int, y: int) -> Vector2:
	return Vector2(float(x) * TILE + TILE * 0.5, float(y) * TILE + TILE * 0.5)

func _player_cell() -> Vector2i:
	return Vector2i(int(_player.position.x / TILE), int(_player.position.y / TILE))

func _draw() -> void:
	if _battle_active:
		return
	if _in_house:
		_draw_interior()
		return
	var full := Rect2(Vector2.ZERO, Vector2(MAP_W, MAP_H) * TILE)
	draw_rect(full, Color("#1b2a1c"))
	for gx in range(0, MAP_W, 2):
		for gy in range(0, MAP_H, 2):
			if _hash(gx, gy, 3) > 0.55:
				draw_rect(Rect2(Vector2(gx, gy) * TILE, Vector2(2, 2) * TILE), Color(0.11, 0.17, 0.12, 0.35))
	var path := PackedVector2Array([
		Vector2(2.2, 28.0) * TILE, Vector2(4.2, 24.2) * TILE,
		Vector2(7.2, 20.6) * TILE, Vector2(10.2, 18.2) * TILE,
		Vector2(13.2, 16.6) * TILE, Vector2(16.4, 14.6) * TILE,
		Vector2(19.2, 10.6) * TILE, Vector2(20.4, 6.2) * TILE,
	])
	draw_polyline(path, Color("#3a3224"), 46.0)
	draw_polyline(path, Color("#4a4030"), 30.0)
	draw_circle(Vector2(20.6, 3.4) * TILE, 78.0, Color("#1e3a44"))
	draw_circle(Vector2(20.6, 3.4) * TILE, 64.0, Color("#274c58"))
	draw_circle(Vector2(20.2, 3.2) * TILE, 22.0, Color(0.65, 0.85, 0.9, 0.18))
	for gx in MAP_W:
		for gy in MAP_H:
			var h := _hash(gx, gy, 11)
			var base := _cell_pos(gx, gy)
			if h > 0.66:
				_draw_grass(base + Vector2((_hash(gx, gy, 21) - 0.5) * 44.0, (_hash(gx, gy, 22) - 0.5) * 44.0), 0.7 + h * 0.8)
			if h < 0.08:
				_draw_flower(base + Vector2((_hash(gx, gy, 31) - 0.5) * 40.0, (_hash(gx, gy, 32) - 0.5) * 40.0), Color("#c9a64a") if h > 0.04 else Color("#b85c4a"))
	for i in OBSTACLES.size():
		var cell: Vector2i = OBSTACLES[i]
		if i % 2 == 0:
			_draw_bamboo(_cell_pos(cell.x, cell.y))
		else:
			_draw_rock(_cell_pos(cell.x, cell.y))
	_draw_house()
	_draw_chests()
	# 迷雾：没走过的格子压暗
	for gx in MAP_W:
		for gy in MAP_H:
			var c := Vector2i(gx, gy)
			if not _explored.has(c):
				draw_rect(Rect2(Vector2(gx, gy) * TILE, Vector2(TILE, TILE)), Color(0.02, 0.03, 0.02, 0.78))
	# 路径提示
	if _moving and _path.size() > 1:
		var pts := PackedVector2Array()
		pts.append(_player.position)
		for i in range(_path_i, _path.size()):
			pts.append(_cell_pos(_path[i].x, _path[i].y))
		if pts.size() > 1:
			draw_polyline(pts, Color(0.88, 0.70, 0.35, 0.55), 2.0)
	if _has_click:
		draw_circle(_click_pos, 9.0, Color("#e0b45a"))
		draw_circle(_click_pos, 4.0, Color("#fff1c9"))
	if _msg != "":
		draw_string(ThemeDB.fallback_font, Vector2(24, 42), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f0d68a"))

func _draw_grass(pos: Vector2, s: float) -> void:
	var col := Color("#2f4a2a")
	for i in 3:
		var dx := (float(i) - 1.0) * 3.0 * s
		draw_line(pos + Vector2(dx, 2.0), pos + Vector2(dx + (float(i) - 1.0) * 2.0, -6.0 * s), col, 1.5)
	draw_line(pos + Vector2(-1.0, 2.0), pos + Vector2(-2.0, -9.0 * s), Color("#3a5a32"), 1.5)

func _draw_flower(pos: Vector2, col: Color) -> void:
	draw_circle(pos, 2.4, col)
	draw_circle(pos + Vector2(2.5, 0.6), 2.0, col.darkened(0.15))
	draw_circle(pos + Vector2(1.2, 1.8), 2.0, col.darkened(0.25))

func _draw_bamboo(pos: Vector2) -> void:
	draw_circle(pos + Vector2(0, 16), 20.0, Color(0.05, 0.08, 0.05, 0.35))
	for i in 5:
		var dx := (float(i) - 2.0) * 7.0
		draw_line(pos + Vector2(dx, 20), pos + Vector2(dx + 2.0, -30.0 - float(i % 2) * 8.0), Color("#3f5a33"), 4.0)
		draw_line(pos + Vector2(dx + 2.0, -12), pos + Vector2(dx + 14.0, -20.0), Color("#4f6a3d"), 2.0)
		draw_line(pos + Vector2(dx + 2.0, -24), pos + Vector2(dx - 10.0, -32.0), Color("#4f6a3d"), 2.0)

func _draw_house() -> void:
	var p := _cell_pos(HOUSE_CELL.x, HOUSE_CELL.y)
	draw_circle(p + Vector2(0, 20), 34.0, Color(0.04, 0.06, 0.04, 0.4))
	draw_rect(Rect2(p + Vector2(-34, -26), Vector2(68, 46)), Color("#4a3a2a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-44, -22), p + Vector2(44, -22), p + Vector2(0, -60)]), Color("#6b4a30"))
	draw_rect(Rect2(p + Vector2(-10, 2), Vector2(20, 18)), Color("#2a1e14"))
	draw_circle(p + Vector2(6, 12), 2.0, Color("#c9a64a"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-18, -70), "竹屋", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f0d68a"))

func _draw_chests() -> void:
	for cell_v in CHEST_CELLS:
		var cell: Vector2i = cell_v
		var p := _cell_pos(cell.x, cell.y)
		var opened := bool(_chest_open.get(cell, false))
		draw_circle(p + Vector2(0, 16), 16.0, Color(0.04, 0.05, 0.04, 0.35))
		draw_rect(Rect2(p + Vector2(-16, -10), Vector2(32, 22)), Color("#6b4a2a"))
		draw_rect(Rect2(p + Vector2(-13, -7), Vector2(26, 16)), Color("#8a6a3a"))
		if opened:
			draw_rect(Rect2(p + Vector2(-16, -20), Vector2(32, 10)), Color("#4a3a2a"))
		else:
			draw_rect(Rect2(p + Vector2(-16, -14), Vector2(32, 7)), Color("#5a3a20"))
			draw_rect(Rect2(p + Vector2(-4, -18), Vector2(8, 6)), Color("#c9a64a"))

func _open_chest(cell: Vector2i) -> void:
	if bool(_chest_open.get(cell, false)):
		return
	_chest_open[cell] = true
	_msg = "拾得：锻造石 ×3 · 旧铁 ×1"
	_msg_t = 2.6
	if _toast != null:
		_toast.text = _msg
		_toast.visible = true
	queue_redraw()

func _draw_interior() -> void:
	var w := ROOM_W * TILE
	var h := ROOM_H * TILE
	draw_rect(Rect2(0, 0, w, h), Color("#2a2018"))
	for x in ROOM_W:
		for y in ROOM_H:
			var c := Color("#4a3524") if (x + y) % 2 == 0 else Color("#3f2d1f")
			draw_rect(Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE)), c)
	# 墙
	draw_rect(Rect2(0, 0, w, 12), Color("#1a120c"))
	draw_rect(Rect2(0, 0, 12, h), Color("#1a120c"))
	draw_rect(Rect2(w - 12, 0, 12, h), Color("#1a120c"))
	# 地毯
	draw_rect(Rect2(2 * TILE, 3 * TILE, 4 * TILE, 2 * TILE), Color("#6b2f2a"))
	draw_rect(Rect2(2 * TILE + 8, 3 * TILE + 8, 4 * TILE - 16, 2 * TILE - 16), Color("#8a3f36"))
	# 桌子
	draw_rect(Rect2(7 * TILE, 2 * TILE, 2 * TILE, TILE), Color("#6b4a30"))
	draw_rect(Rect2(7 * TILE + 8, 2 * TILE + 8, 2 * TILE - 16, TILE - 16), Color("#8a6a3a"))
	# 床
	draw_rect(Rect2(0.6 * TILE, 1 * TILE, 2 * TILE, 2 * TILE), Color("#4a3a2a"))
	draw_rect(Rect2(0.6 * TILE + 6, 1 * TILE + 6, 2 * TILE - 12, 2 * TILE - 12), Color("#7a6a4a"))
	# 箱子
	draw_rect(Rect2(8 * TILE, 5 * TILE, TILE, TILE), Color("#6b4a2a"))
	draw_rect(Rect2(8 * TILE + 4, 5 * TILE + 4, TILE - 8, TILE - 8), Color("#8a6a3a"))
	# 门
	draw_rect(Rect2(5 * TILE, (ROOM_H - 1) * TILE, TILE, TILE * 0.6), Color("#2a1e14"))
	draw_rect(Rect2(5 * TILE + 6, (ROOM_H - 1) * TILE + 6, TILE - 12, TILE * 0.6 - 12), Color("#5a3a20"))
	draw_circle(Vector2(5 * TILE + TILE * 0.7, (ROOM_H - 1) * TILE + TILE * 0.3), 3.0, Color("#c9a64a"))
	# NPC
	var np := Vector2(7 * TILE + TILE * 0.5, 5 * TILE)
	draw_circle(np + Vector2(0, -18), 10.0, Color("#c89a6a"))
	draw_rect(Rect2(np + Vector2(-10, -8), Vector2(20, 24)), Color("#4a5a6a"))
	draw_string(ThemeDB.fallback_font, np + Vector2(-20, -38), "老掌柜", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f0d68a"))
	# 提示
	draw_string(ThemeDB.fallback_font, Vector2(24, 30), "竹屋内 · 点门或按 E 出去", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#d8cba0"))

func _draw_rock(pos: Vector2) -> void:
	draw_circle(pos + Vector2(0, 14), 22.0, Color(0.04, 0.06, 0.04, 0.4))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-24, 14), pos + Vector2(-16, -6), pos + Vector2(2, -16),
		pos + Vector2(20, -4), pos + Vector2(24, 14),
	]), Color("#45463f"))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-16, 12), pos + Vector2(-10, -2), pos + Vector2(2, -10),
		pos + Vector2(12, 0), pos + Vector2(14, 12),
	]), Color("#5a5b52"))

# ---------- 迷雾 ----------

func _reveal_at(pos: Vector2) -> void:
	var c := Vector2i(int(pos.x / TILE), int(pos.y / TILE))
	var changed := false
	for dx in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
		for dy in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
			if dx * dx + dy * dy > REVEAL_RADIUS * REVEAL_RADIUS + 1:
				continue
			var cc := Vector2i(c.x + dx, c.y + dy)
			if not _explored.has(cc):
				_explored[cc] = true
				changed = true
	if changed:
		queue_redraw()

# ---------- 点击移动 / 接战 ----------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://menu/menu_sketch.tscn")
		return
	if event.is_action_pressed("ui_accept"):
		if _in_house:
			_exit_house()
		elif _near_house():
			_enter_house()
		return
	if _busy or _battle_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click(get_global_mouse_position())

func _enter_house() -> void:
	if _in_house:
		return
	_house_pos = _player.position
	_in_house = true
	_moving = false
	_has_click = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = false
	_player.position = Vector2(5 * TILE + TILE * 0.5, (ROOM_H - 1) * TILE + TILE * 0.2)
	_camera.enabled = false
	queue_redraw()

func _exit_house() -> void:
	if not _in_house:
		return
	_in_house = false
	_moving = false
	_player.position = _house_pos
	_camera.enabled = true
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	queue_redraw()

func _near_house() -> bool:
	return _player.position.distance_to(_cell_pos(HOUSE_CELL.x, HOUSE_CELL.y)) < 92.0

func _on_click(pos: Vector2) -> void:
	if _in_house:
		var c := Vector2i(int(pos.x / TILE), int(pos.y / TILE))
		if c == Vector2i(5, ROOM_H - 1):
			_exit_house()
			return
		if c == Vector2i(8, 5):
			_open_chest(Vector2i(8, 5))
			return
		_click_pos = _cell_pos(c.x, c.y)
		_moving = true
		queue_redraw()
		return
	var cell := Vector2i(int(pos.x / TILE), int(pos.y / TILE))
	if CHEST_CELLS.has(cell):
		_open_chest(cell)
		return
	if not _astar.is_in_boundsv(cell):
		return
	if _astar.is_point_solid(cell):
		return
	_target_enemy = null
	for e_v in _enemies:
		var e: Node2D = e_v
		if not is_instance_valid(e) or bool(e.get_meta("beaten", false)):
			continue
		if Vector2i(int(e.position.x / TILE), int(e.position.y / TILE)) == cell:
			_target_enemy = e
			break
	var path: Array = _astar.get_id_path(_player_cell(), cell)
	if path.is_empty():
		return
	_path = path
	_path_i = 1
	_moving = true
	_click_pos = _cell_pos(cell.x, cell.y)
	_has_click = true
	queue_redraw()

func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg = ""
			if _toast != null:
				_toast.visible = false
			queue_redraw()
	if _busy or _battle_active or _player == null:
		return
	if _in_house:
		if not _moving:
			return
		var to_h := _click_pos - _player.position
		if to_h.length() <= 3.0:
			_moving = false
			return
		_player.position += to_h.normalized() * minf(WALK_SPEED * delta, to_h.length())
		_player.position.x = clampf(_player.position.x, TILE * 0.5, (ROOM_W - 0.5) * TILE)
		_player.position.y = clampf(_player.position.y, TILE * 0.5, (ROOM_H - 0.5) * TILE)
		return
	_reveal_t += delta
	if _reveal_t > 0.18:
		_reveal_t = 0.0
		_reveal_at(_player.position)
	if not _moving:
		return
	if _path_i >= _path.size():
		_moving = false
		return
	var wp := _cell_pos(_path[_path_i].x, _path[_path_i].y)
	var to := wp - _player.position
	if to.length() <= 3.0:
		_path_i += 1
		if _path_i >= _path.size():
			_moving = false
			if _target_enemy != null and is_instance_valid(_target_enemy):
				_try_battle(_target_enemy)
		return
	_player.position += to.normalized() * minf(WALK_SPEED * delta, to.length())
	for e_v in _enemies:
		var e: Node2D = e_v
		if not is_instance_valid(e) or bool(e.get_meta("beaten", false)):
			continue
		if _player.position.distance_to(e.position) <= ENEMY_REACH:
			_try_battle(e)
			return

func _try_battle(enemy: Node2D) -> void:
	if _busy:
		return
	_busy = true
	_moving = false
	_battle_active = true
	_has_click = false
	_map_pos_before_battle = _player.position
	_camera.enabled = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = false
	queue_redraw()
	var node := {
		"t": "battle",
		"name": str(enemy.get_meta("foe_name", "敌人")),
		"foe": (enemy.get_meta("foe", {}) as Dictionary).duplicate(true),
		"money": [12, 25],
	}
	var battle := DuelBattle.new()
	add_child(battle)
	var res: Dictionary = await battle.run(_state, _player, _fx, node, false, [])
	if is_instance_valid(battle):
		battle.queue_free()
	_player.position = _map_pos_before_battle
	_camera.enabled = true
	if bool(res.get("win", false)):
		enemy.set_meta("beaten", true)
	_battle_active = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	_busy = false
	queue_redraw()

