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
const StickFighter := preload("res://journey/stick_fighter.gd")

const MAP_W := 24
const MAP_H := 30
const TILE := 72.0
const WALK_SPEED := 260.0
const ENEMY_REACH := 52.0
const HOUSE_CELL := Vector2i(6, 20)
const SECT_CELL := Vector2i(19, 6)
const START_CELL := Vector2i(12, 24)
const SectPanel := preload("res://journey/explore/sect_panel.gd")
const POIPanel := preload("res://journey/explore/poi_panel.gd")
const MerchantPanel := preload("res://journey/explore/merchant_panel.gd")
const JailPanel := preload("res://journey/explore/jail_panel.gd")
const ROOM_W := 10
const ROOM_H := 10

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
var _back_btn: Button
var _action_lb: Label
var _wanted_lb: Label
var _action_empty := false
var _exit_timer := 0.0
var _loot_silver := 0
var _loot_stones := 0
var _loot_atlas := 0
var _sect_panel: Control
var _sect_pending := false
var _poi_panel: Control
var _merchant_panel: Control
var _jail_panel: Control
var _poi_pending := -1
var _poi_active := -1
var _poi_cells: Array = []
var _poi_types: Array = []
var _poi_used := {}
var _boss_cell := Vector2i(-1, -1)
var _boss_name := "山君"
var _boss_node: Node2D
var _boss_panel: Control
var _boss_pending := false
var _boss_fight_pending := false
var _chest_cells: Array = []
var _obstacles: Array = []
var _enemy_cells: Array = []
var _reveal_r := 3
var _land_id := 0

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
	if GameState.action <= 0:
		_set_msg("行动资源耗尽了——回村", 9.9)
		call_deferred("_return_village")

func setup(role_id := "player", diff := 1, party: Array = [], fates: Array = []) -> void:
	_role_id = role_id
	_diff = diff
	_state = RunState.new()
	_state.reset([])
	var use_party: Array = party.duplicate()
	if use_party.is_empty():
		use_party = [role_id]
	_state.begin_formal(use_party, _diff, fates)
	_gen_world()
	_build_astar()
	_spawn_player()
	_spawn_fx()
	_spawn_enemies()
	_spawn_boss()
	_spawn_toast()
	_reveal_at(_player.position)
	queue_redraw()

func _gen_world() -> void:
	_land_id = GameState.world_seed % 4
	_reveal_r = 2 if (_land_id == 1 or _land_id == 2) else 3
	_obstacles.clear()
	_chest_cells.clear()
	_enemy_cells.clear()
	_poi_cells.clear()
	_poi_types.clear()
	_poi_used.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001 + GameState.world_seed * 7919
	var obs_n: int = [14, 9, 11, 12][_land_id]
	var guard := 0
	while _obstacles.size() < obs_n and guard < 500:
		guard += 1
		var c := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(c, 2) or _obstacles.has(c):
			continue
		_obstacles.append(c)
	var chest_n: int = [4, 5, 5, 7][_land_id]
	guard = 0
	while _chest_cells.size() < chest_n and guard < 500:
		guard += 1
		var c2 := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(c2, 2) or _obstacles.has(c2) or _chest_cells.has(c2):
			continue
		_chest_cells.append(c2)
	var poi_order := ["temple", "well", "tea", "merchant"]
	var poff := GameState.world_seed % poi_order.size()
	guard = 0
	while _poi_cells.size() < 4 and guard < 500:
		guard += 1
		var cp := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(cp, 1) or _obstacles.has(cp) or _chest_cells.has(cp) or _poi_cells.has(cp):
			continue
		_poi_cells.append(cp)
		_poi_types.append(poi_order[(_poi_cells.size() - 1 + poff) % poi_order.size()])
	var hunter_n := mini(2, GameState.wanted)
	var guard_n := 1 if GameState.wanted > 0 else 0
	var enemy_n := mini(8, 3 + int(GameState.world_tier / 3) + (1 if _land_id == 2 else 0) + hunter_n + guard_n)
	guard = 0
	while _enemy_cells.size() < enemy_n and guard < 500:
		guard += 1
		var c3 := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(c3, 1) or _obstacles.has(c3) or _chest_cells.has(c3) or _poi_cells.has(c3) or _enemy_cells.has(c3):
			continue
		_enemy_cells.append(c3)
	# Boss 落在离起点远、避开所有已占格的位置；找不到就退到 (3,3)
	var bnames := ["山君", "夜叉", "老妖"]
	_boss_name = str(bnames[GameState.world_seed % bnames.size()])
	_boss_cell = Vector2i(3, 3)
	guard = 0
	while guard < 500:
		guard += 1
		var cb := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(cb, 2) or _obstacles.has(cb) or _chest_cells.has(cb) or _poi_cells.has(cb) or _enemy_cells.has(cb):
			continue
		if Vector2(cb).distance_to(Vector2(START_CELL)) < 9.0:
			continue
		_boss_cell = cb
		break

func _reserved(c: Vector2i, r: int) -> bool:
	for p_v in [START_CELL, HOUSE_CELL, SECT_CELL]:
		var p: Vector2i = p_v
		if Vector2(c).distance_to(Vector2(p)) <= float(r):
			return true
	return false

func _build_astar() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, MAP_W, MAP_H)
	_astar.cell_size = Vector2(TILE, TILE)
	_astar.offset = Vector2(TILE * 0.5, TILE * 0.5)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for cell_v in _obstacles:
		var cell: Vector2i = cell_v
		_astar.set_point_solid(cell, true)

func _spawn_player() -> void:
	_player = ActorFactory.make(_role_id)
	add_child(_player)
	_player.position = _cell_pos(START_CELL.x, START_CELL.y)
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
	_action_lb = Label.new()
	_action_lb.position = Vector2(24, 56)
	_action_lb.add_theme_font_size_override("font_size", 16)
	_toast_layer.add_child(_action_lb)
	_update_action_label()
	_wanted_lb = Label.new()
	_wanted_lb.position = Vector2(24, 86)
	_wanted_lb.add_theme_font_size_override("font_size", 14)
	_wanted_lb.add_theme_color_override("font_color", Color("#e06a5a"))
	_toast_layer.add_child(_wanted_lb)
	_update_wanted_label()
	var back := Button.new()
	back.text = "回 村"
	back.position = Vector2(584, 1172)
	back.size = Vector2(112, 44)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 20)
	back.add_theme_color_override("font_color", Color("#f0d68a"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.05, 0.04, 0.84)
	normal.border_color = Color(0.72, 0.58, 0.22, 0.82)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	back.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.11, 0.08, 0.92)
	back.add_theme_stylebox_override("hover", hover)
	back.add_theme_stylebox_override("pressed", hover)
	back.tooltip_text = "回村（战利品已入账）"
	back.pressed.connect(_return_village)
	_toast_layer.add_child(back)
	_back_btn = back

func _spawn_boss() -> void:
	_boss_node = Node2D.new()
	_boss_node.position = _cell_pos(_boss_cell.x, _boss_cell.y)
	var tier := clampi(GameState.world_tier, 1, 5)
	_boss_node.set_meta("boss", true)
	_boss_node.set_meta("foe_name", _boss_name)
	_boss_node.set_meta("beaten", false)
	_boss_node.set_meta("foe", {"hp": 280 + tier * 70, "atk": 14 + tier * 2, "scale": 1.3})
	add_child(_boss_node)

func _spawn_enemies() -> void:
	var spots: Array = _enemy_cells
	if spots.is_empty():
		spots = [Vector2i(16, 16), Vector2i(7, 9), Vector2i(11, 17)]
	var hunters := mini(2, GameState.wanted)
	var guards := 1 if GameState.wanted > 0 else 0
	for i in spots.size():
		var is_hunter := hunters > 0 and i >= spots.size() - hunters
		var is_guard := guards > 0 and i == spots.size() - hunters - 1
		_enemies.append(_make_enemy(spots[i], i, is_hunter, is_guard))

# ---------- 程序化敌人模型 ----------

func _make_enemy(cell: Vector2i, i: int, hunter := false, guard := false) -> Node2D:
	var e := Node2D.new()
	e.position = _cell_pos(cell.x, cell.y)
	var kinds := ["竹妖", "野狼", "山贼"]
	var kind: String = "捕快" if guard else ("赏金猎人" if hunter else kinds[(i + GameState.world_seed) % kinds.size()])
	var tier := clampi(GameState.world_tier, 1, 5)
	e.set_meta("foe_name", kind)
	e.set_meta("hunter", hunter)
	e.set_meta("guard", guard)
	var hp := 50 + i * 18 + (tier - 1) * 28
	var atk := 7 + i * 2 + (tier - 1) * 2
	if hunter:
		hp += 30
		atk += 3
	if guard:
		hp += 60
		atk += 5
	e.set_meta("foe", {"hp": hp, "atk": atk})
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
	# v244：同一张地图按 WorldSeed 变草色/水纹/花点——换世界不是只换名字
	return float(abs(hash(Vector3i(x, y, salt + GameState.world_seed * 137))) % 1000) / 1000.0

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
	# 地图外的底色：不然走到地图边缘，镜头会把工程的浅灰底露出来
	draw_rect(Rect2(Vector2(-TILE * 8.0, -TILE * 8.0), Vector2(MAP_W * TILE + TILE * 16.0, MAP_H * TILE + TILE * 16.0)), Color("#0b100c"))
	var full := Rect2(Vector2.ZERO, Vector2(MAP_W, MAP_H) * TILE)
	var grounds := ["#1b2a1c", "#1b2630", "#162a1c", "#2a2117"]
	draw_rect(full, Color(grounds[clampi(_land_id, 0, grounds.size() - 1)]))
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
	for i in _obstacles.size():
		var cell: Vector2i = _obstacles[i]
		if _land_id == 2 or i % 2 == 0:
			_draw_bamboo(_cell_pos(cell.x, cell.y))
		else:
			_draw_rock(_cell_pos(cell.x, cell.y))
	_draw_house()
	_draw_sect_gate()
	_draw_boss()
	_draw_pois()
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

func _draw_sect_gate() -> void:
	var p := _cell_pos(SECT_CELL.x, SECT_CELL.y)
	draw_circle(p + Vector2(0, 24), 46.0, Color(0.04, 0.05, 0.04, 0.38))
	draw_rect(Rect2(p + Vector2(-46, 8), Vector2(92, 10)), Color("#3f3a30"))
	draw_rect(Rect2(p + Vector2(-40, -54), Vector2(12, 64)), Color("#4a4032"))
	draw_rect(Rect2(p + Vector2(28, -54), Vector2(12, 64)), Color("#4a4032"))
	draw_rect(Rect2(p + Vector2(-50, -62), Vector2(100, 12)), Color("#2e2820"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-58, -62), p + Vector2(58, -62), p + Vector2(0, -88)]), Color("#5a3f2a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-44, -62), p + Vector2(44, -62), p + Vector2(0, -82)]), Color("#7a5432"))
	draw_rect(Rect2(p + Vector2(-26, -118), Vector2(52, 22)), Color("#e6d7b4"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-22, -102), "山门", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#6b2f22"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-32, -132), "青岚山门", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f0d68a"))

func _draw_boss() -> void:
	if _boss_cell.x < 0:
		return
	var p := _cell_pos(_boss_cell.x, _boss_cell.y)
	var dead := _boss_node != null and bool(_boss_node.get_meta("beaten", false))
	draw_circle(p + Vector2(0, 22), 38.0, Color(0.03, 0.04, 0.03, 0.45))
	draw_rect(Rect2(p + Vector2(-30, 4), Vector2(60, 18)), Color("#3a3128"))
	draw_circle(p + Vector2(0, -8), 20.0, Color("#d8d0bc") if not dead else Color("#6b655c"))
	draw_circle(p + Vector2(-7, -10), 4.0, Color("#1b1a18"))
	draw_circle(p + Vector2(7, -10), 4.0, Color("#1b1a18"))
	draw_line(p + Vector2(-6, 2), p + Vector2(6, 2), Color("#1b1a18"), 2.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-22, -20), p + Vector2(-34, -44), p + Vector2(-12, -30)]), Color("#5a3f2a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(22, -20), p + Vector2(34, -44), p + Vector2(12, -30)]), Color("#5a3f2a"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-30, -56), _boss_name + ("·已伏" if dead else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#9a927f") if dead else Color("#e06a5a"))

func _draw_pois() -> void:
	for i in _poi_cells.size():
		var cell: Vector2i = _poi_cells[i]
		var p := _cell_pos(cell.x, cell.y)
		var typ := str(_poi_types[i])
		var used := bool(_poi_used.get(cell, false))
		draw_circle(p + Vector2(0, 18), 26.0, Color(0.04, 0.05, 0.04, 0.36))
		match typ:
			"temple":
				draw_rect(Rect2(p + Vector2(-26, -10), Vector2(52, 30)), Color("#4a3a2a"))
				draw_colored_polygon(PackedVector2Array([p + Vector2(-34, -10), p + Vector2(34, -10), p + Vector2(0, -34)]), Color("#6b4a30"))
				draw_rect(Rect2(p + Vector2(-8, 2), Vector2(16, 18)), Color("#241a12"))
				draw_line(p + Vector2(0, 2), p + Vector2(0, -14), Color("#c9a64a"), 2.0)
				draw_circle(p + Vector2(0, -16), 2.0, Color("#d96a3a"))
			"well":
				draw_circle(p + Vector2(0, 4), 22.0, Color("#3f3a30"))
				draw_circle(p + Vector2(0, 2), 16.0, Color("#1d2c34"))
				draw_arc(p + Vector2(0, 2), 16.0, 0.0, TAU, 18, Color("#6b6252"), 3.0)
				draw_line(p + Vector2(-22, -18), p + Vector2(-22, 8), Color("#5a4630"), 4.0)
				draw_line(p + Vector2(22, -18), p + Vector2(22, 8), Color("#5a4630"), 4.0)
				draw_line(p + Vector2(-24, -20), p + Vector2(24, -20), Color("#3a2a1c"), 5.0)
			"merchant":
				draw_rect(Rect2(p + Vector2(-30, -2), Vector2(52, 24)), Color("#6b4a2a"))
				draw_circle(p + Vector2(-18, 24), 9.0, Color("#3a2a1c"))
				draw_circle(p + Vector2(16, 24), 9.0, Color("#3a2a1c"))
				draw_colored_polygon(PackedVector2Array([p + Vector2(-34, -2), p + Vector2(34, -2), p + Vector2(0, -30)]), Color("#8a6a3a"))
				draw_line(p + Vector2(0, -2), p + Vector2(0, 20), Color("#3a2a1c"), 3.0)
			"tea":
				draw_rect(Rect2(p + Vector2(-30, 2), Vector2(60, 18)), Color("#5a3f2a"))
				draw_colored_polygon(PackedVector2Array([p + Vector2(-36, 2), p + Vector2(36, 2), p + Vector2(0, -28)]), Color("#7a5432"))
				draw_line(p + Vector2(-24, -2), p + Vector2(-24, 16), Color("#3a2a1c"), 3.0)
				draw_line(p + Vector2(24, -2), p + Vector2(24, 16), Color("#3a2a1c"), 3.0)
				draw_line(p + Vector2(0, 8), p + Vector2(0, -6), Color(0.9, 0.85, 0.72, 0.45), 2.0)
		var nm: String = str({"temple": "破庙", "well": "古井", "tea": "茶棚", "merchant": "货郎"}.get(typ, "旧迹"))
		draw_string(ThemeDB.fallback_font, p + Vector2(-22, -50), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b9a878") if used else Color("#f0d68a"))
		if used:
			draw_string(ThemeDB.fallback_font, p + Vector2(-18, -34), "已探", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.66, 0.54, 0.8))

func _draw_chests() -> void:
	for cell_v in _chest_cells:
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
	var tier := clampi(GameState.world_tier, 1, 5)
	var stones := 3 + tier
	var silver := 20 + tier * 6
	GameState.add_material("forge_stone", stones)
	GameState.add_coin("silver", silver)
	_loot_stones += stones
	_loot_silver += silver
	var extra := ""
	if randf() < 0.22:
		GameState.add_material("atlas", 1)
		_loot_atlas += 1
		extra = " · 舆图 ×1"
	GameState.save_game()
	_set_msg("拾得：锻造石 ×" + str(stones) + " · 银两 +" + str(silver) + extra)

func _set_msg(text: String, sec := 2.6) -> void:
	_msg = text
	_msg_t = sec
	if _toast != null:
		_toast.text = text
		_toast.visible = true
	queue_redraw()

func _update_action_label() -> void:
	if _action_lb == null:
		return
	_action_lb.text = "行动 " + str(GameState.action) + " / " + str(GameState.ACTION_MAX)
	_action_lb.add_theme_color_override("font_color", Color("#e06a5a") if GameState.action <= 5 else Color("#d8cba0"))

func _update_wanted_label() -> void:
	if _wanted_lb == null:
		return
	_wanted_lb.visible = GameState.wanted > 0
	_wanted_lb.text = "通缉 " + str(GameState.wanted) + " / 5" if GameState.wanted > 0 else ""

func _return_village() -> void:
	if _battle_active:
		return
	var parts: Array = []
	if _loot_silver > 0:
		parts.append("银两 +" + str(_loot_silver))
	if _loot_stones > 0:
		parts.append("锻造石 +" + str(_loot_stones))
	if _loot_atlas > 0:
		parts.append("舆图 +" + str(_loot_atlas))
	if not parts.is_empty():
		GameState.note_push("游历归来：" + " · ".join(PackedStringArray(parts)))
	elif _action_empty:
		GameState.note_push("行动资源耗尽——安全回村，战利品已入账")
	GameState.save_game()
	print("[游历] 回村：锻造石=", GameState.material_count("forge_stone"), " 银两=", GameState.coin("silver"), " 行动=", GameState.action)
	get_tree().change_scene_to_file("res://menu/menu_sketch.tscn")

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
	for dx in range(-_reveal_r, _reveal_r + 1):
		for dy in range(-_reveal_r, _reveal_r + 1):
			if dx * dx + dy * dy > _reveal_r * _reveal_r + 1:
				continue
			var cc := Vector2i(c.x + dx, c.y + dy)
			if not _explored.has(cc):
				_explored[cc] = true
				changed = true
	if changed:
		queue_redraw()

# ---------- 点击移动 / 接战 ----------

func _unhandled_input(event: InputEvent) -> void:
	if _sect_panel != null and _sect_panel.visible:
		return
	if _poi_panel != null and _poi_panel.visible:
		return
	if _merchant_panel != null and _merchant_panel.visible:
		return
	if _jail_panel != null and _jail_panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_return_village()
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

func _near_sect() -> bool:
	return _player.position.distance_to(_cell_pos(SECT_CELL.x, SECT_CELL.y)) < 112.0

func _poi_at(cell: Vector2i) -> int:
	for i in _poi_cells.size():
		if Vector2i(_poi_cells[i]) == cell:
			return i
	return -1

func _poi_near(i: int) -> bool:
	if i < 0 or i >= _poi_cells.size():
		return false
	var c: Vector2i = _poi_cells[i]
	return _player.position.distance_to(_cell_pos(c.x, c.y)) < 102.0

func _poi_data(typ: String) -> Dictionary:
	match typ:
		"temple":
			return {"title": "破　庙", "sub": "半塌的山神庙，泥像没了头。",
				"body": "供桌积着灰，香炉冷透。梁上似乎还藏着东西。\n\n（只能探一次）",
				"choices": [{"id": "loot", "label": "搜供桌"}, {"id": "incense", "label": "上一炷香"}]}
		"well":
			return {"title": "古　井", "sub": "井沿磨得发亮，井水黑得看不见底。",
				"body": "水桶还在，绳子没烂。\n\n（只能探一次）",
				"choices": [{"id": "water", "label": "打一桶水"}, {"id": "probe", "label": "探井底"}]}
		_:
			return {"title": "茶　棚", "sub": "山道边的茶棚，炉子还温着。",
				"body": "一个瞎眼说书人坐在角落，茶香混着松烟。\n\n（只能探一次）",
				"choices": [{"id": "drink", "label": "喝一碗（10两）"}, {"id": "listen", "label": "听一段书"}]}

func _open_poi(i: int) -> void:
	if i < 0 or i >= _poi_cells.size():
		return
	_poi_active = i
	if str(_poi_types[i]) == "merchant":
		_open_merchant()
		return
	if _poi_panel == null:
		var pp = POIPanel.new()
		pp.connect("picked", _on_poi_pick)
		pp.connect("closed", _on_poi_closed)
		_toast_layer.add_child(pp)
		_poi_panel = pp
	_poi_panel.call("open", _poi_data(str(_poi_types[i])))
	_busy = true
	_moving = false
	_has_click = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = false
	if _action_lb != null:
		_action_lb.visible = false
	if _back_btn != null:
		_back_btn.visible = false

func _on_poi_pick(id: String) -> void:
	if _poi_active < 0 or _poi_active >= _poi_cells.size():
		return
	var cell: Vector2i = _poi_cells[_poi_active]
	var typ := str(_poi_types[_poi_active])
	var used := false
	var msg := "你退了出来。"
	match typ:
		"temple":
			if id == "loot":
				GameState.add_coin("silver", 25)
				GameState.add_material("forge_stone", 2)
				used = true
				msg = "供桌下摸出 25 两碎银，又捡了两块锻造石。"
			elif id == "incense":
				GameState.action_add(2)
				_reveal_at(_cell_pos(cell.x, cell.y))
				used = true
				msg = "你上了一炷香，心里静了静。行动 +2，附近亮了一角。"
		"well":
			if id == "water":
				GameState.action_add(2)
				used = true
				msg = "井水冰凉，喝下去精神一振。行动 +2。"
			elif id == "probe":
				if randf() < 0.4:
					GameState.add_material("atlas", 1)
					used = true
					msg = "井底卡着一只旧木匣——里面是一张舆图。"
				else:
					GameState.add_material("forge_stone", 3)
					used = true
					msg = "井底只摸到三块沉石，倒是能当锻造石用。"
		"tea":
			if id == "drink":
				if GameState.coin("silver") < 10:
					msg = "茶钱不够——老板没收你的铜板，也没给你茶。"
				else:
					GameState.add_coin("silver", -10)
					GameState.action_add(3)
					used = true
					msg = "一碗热茶下肚。行动 +3，银两 -10。"
			elif id == "listen":
				for k in 4:
					_reveal_at(_cell_pos(randi_range(1, MAP_W - 2), randi_range(1, MAP_H - 2)))
				used = true
				msg = "说书人讲了几处旧事，地图亮了一角。"
	if used:
		_poi_used[cell] = true
		GameState.save_game()
	_update_action_label()
	queue_redraw()
	_poi_panel.call("set_result", msg)

func _on_poi_closed() -> void:
	_busy = false
	_poi_pending = -1
	_poi_active = -1
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true

func _open_merchant() -> void:
	if _merchant_panel == null:
		var mp = MerchantPanel.new()
		mp.connect("closed", _on_merchant_closed)
		_toast_layer.add_child(mp)
		_merchant_panel = mp
	_merchant_panel.call("open")
	_busy = true
	_moving = false
	_has_click = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = false
	if _action_lb != null:
		_action_lb.visible = false
	if _back_btn != null:
		_back_btn.visible = false

func _on_merchant_closed() -> void:
	_busy = false
	_poi_pending = -1
	_poi_active = -1
	_update_wanted_label()
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true

func _open_jail() -> void:
	if _jail_panel == null:
		var jp = JailPanel.new()
		jp.connect("finished", _on_jail_finished)
		_toast_layer.add_child(jp)
		_jail_panel = jp
	_jail_panel.call("open")
	_busy = true
	_moving = false
	_has_click = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = false
	if _action_lb != null:
		_action_lb.visible = false
	if _wanted_lb != null:
		_wanted_lb.visible = false
	if _back_btn != null:
		_back_btn.visible = false

func _on_jail_finished() -> void:
	GameState.save_game()
	_return_village()

func _boss_near() -> bool:
	if _boss_cell.x < 0:
		return false
	return _player.position.distance_to(_cell_pos(_boss_cell.x, _boss_cell.y)) < 118.0

func _open_boss() -> void:
	if _boss_node == null or bool(_boss_node.get_meta("beaten", false)):
		return
	if _boss_panel == null:
		var bp = POIPanel.new()
		bp.connect("picked", _on_boss_pick)
		bp.connect("closed", _on_boss_closed)
		_toast_layer.add_child(bp)
		_boss_panel = bp
	var data := {
		"title": _boss_name,
		"sub": "盘踞在此的一方凶物。",
		"body": "山风忽然停了。\n\n（失败会被抬回村，战利品全留）",
		"choices": [{"id": "fight", "label": "拔 剑"}, {"id": "leave", "label": "绕 开"}],
	}
	_boss_panel.call("open", data)
	_busy = true
	_moving = false
	_has_click = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = false
	if _action_lb != null:
		_action_lb.visible = false
	if _back_btn != null:
		_back_btn.visible = false

func _on_boss_pick(id: String) -> void:
	if id == "fight":
		_boss_fight_pending = true
	_boss_panel.call("close")

func _on_boss_closed() -> void:
	_busy = false
	_boss_pending = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true
	if _boss_fight_pending:
		_boss_fight_pending = false
		call_deferred("_try_battle", _boss_node)

func _open_sect() -> void:
	if _sect_panel == null:
		var sp = SectPanel.new()
		sp.connect("closed", _on_sect_closed)
		_toast_layer.add_child(sp)
		_sect_panel = sp
	_sect_panel.open()
	_busy = true
	_moving = false
	_has_click = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = false
	if _action_lb != null:
		_action_lb.visible = false
	if _back_btn != null:
		_back_btn.visible = false

func _on_sect_closed() -> void:
	_busy = false
	_sect_pending = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true

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
	if cell == SECT_CELL:
		if _near_sect():
			_open_sect()
			return
		_sect_pending = true
	var pi := _poi_at(cell)
	if pi >= 0:
		var pc: Vector2i = _poi_cells[pi]
		if bool(_poi_used.get(pc, false)):
			_set_msg("这处旧迹已经探过了")
			return
		if _poi_near(pi):
			_open_poi(pi)
			return
		_poi_pending = pi
	if _chest_cells.has(cell):
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
	if not GameState.action_spend(1):
		_set_msg("行动资源耗尽——这一趟该回去了")
		_action_empty = true
		return
	_update_action_label()
	if GameState.action <= 0:
		_action_empty = true
		_set_msg("行动资源耗尽——这一趟该回去了")
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
	if _action_empty and not _moving and not _busy and not _battle_active and not _in_house:
		_exit_timer += delta
		if _exit_timer > 1.4:
			_return_village()
			return
	if _busy or _battle_active or _player == null:
		return
	if _sect_pending and not _in_house and _near_sect():
		_sect_pending = false
		_moving = false
		_path.clear()
		_has_click = false
		_open_sect()
		return
	if _poi_pending >= 0 and not _in_house and _poi_near(_poi_pending):
		var pi2 := _poi_pending
		_poi_pending = -1
		_moving = false
		_path.clear()
		_has_click = false
		_open_poi(pi2)
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
	if _back_btn != null:
		_back_btn.visible = false
	_map_pos_before_battle = _player.position
	_camera.enabled = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = false
	queue_redraw()
	var is_guard := bool(enemy.get_meta("guard", false))
	var node := {
		"t": "battle",
		"name": str(enemy.get_meta("foe_name", "敌人")),
		"foe": (enemy.get_meta("foe", {}) as Dictionary).duplicate(true),
		"money": [12 + GameState.world_tier * 4, 25 + GameState.world_tier * 6],
		"stick_enemies": true,   # v242：探险战斗的敌人也用火柴人
		"guard": is_guard,
	}
	# 战斗里主角用火柴人（地图上仍用 Q 版立绘）：另起一个火柴人替身，
	# 打完收掉，地图上的立绘原样还回来。
	var battle_player := StickFighter.new()
	battle_player.position = Vector2(210.0, 950.0)
	add_child(battle_player)
	_player.visible = false
	var battle := DuelBattle.new()
	add_child(battle)
	var res: Dictionary = await battle.run(_state, battle_player, _fx, node, false, [])
	if is_instance_valid(battle):
		battle.queue_free()
	if is_instance_valid(battle_player):
		battle_player.queue_free()
	_player.visible = true
	_player.position = _map_pos_before_battle
	_camera.enabled = true
	var won := bool(res.get("win", false))
	if won:
		enemy.set_meta("beaten", true)
	_battle_active = false
	if _back_btn != null:
		_back_btn.visible = true
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	_busy = false
	if won:
		if is_guard:
			GameState.wanted = mini(5, GameState.wanted + 1)
			_update_wanted_label()
		_grant_battle_loot(enemy)
	elif is_guard:
		_open_jail()
		return
	queue_redraw()

func _grant_battle_loot(enemy: Node2D) -> void:
	var tier := clampi(GameState.world_tier, 1, 5)
	var silver := randi_range(12 + tier * 4, 25 + tier * 6)
	var stones := randi_range(1 + int(tier / 2), 3 + tier)
	if bool(enemy.get_meta("hunter", false)):
		silver += 30
	if bool(enemy.get_meta("guard", false)):
		silver += 50
	GameState.add_coin("silver", silver)
	GameState.add_material("forge_stone", stones)
	_loot_silver += silver
	_loot_stones += stones
	GameState.save_game()
	var tail := " · 通缉 +1" if bool(enemy.get_meta("guard", false)) else ""
	_set_msg("击败「" + str(enemy.get_meta("foe_name", "敌人")) + "」：银两 +" + str(silver) + " · 锻造石 +" + str(stones) + tail, 3.0)

