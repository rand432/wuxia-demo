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
const FoodMeter := preload("res://journey/explore/food_meter.gd")
const CharacterPanel := preload("res://menu/character_panel.gd")
const WarehousePanel := preload("res://menu/warehouse_panel.gd")
const RegionSelectPanel := preload("res://menu/region_select.gd")

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
const BossCodex := preload("res://journey/explore/boss_codex.gd")
const RelationshipPanel := preload("res://journey/explore/relationship_panel.gd")
const ROOM_W := 10
const ROOM_H := 10

# v255：精英词缀（世界档 ≥2）
const ELITE_AFFIXES := [
	{"id": "frenzy", "name": "狂暴", "hp": 0.9, "atk": 1.3, "scale": 1.18, "spd": 0},
	{"id": "iron", "name": "铁壁", "hp": 1.4, "atk": 0.9, "scale": 1.08, "spd": 0},
	{"id": "swift", "name": "疾风", "hp": 1.0, "atk": 1.05, "scale": 1.12, "spd": 20},
	{"id": "sharp", "name": "利刃", "hp": 1.0, "atk": 1.15, "scale": 1.16, "spd": 5},
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
var _back_btn: Button
var _action_lb: Label
var _food_meter: Control
var _time_lb: Label
var _region_lb: Label
var _side_panel: Control
var _ng_panel: Control
var _ng_echo_mode := false
var _ng_final_mode := false
var _wuxia_cell := Vector2i(-1, -1)
var _wuxia_pending := false
var _wuxia_panel: Control
var _wuxia_node: Node2D
var _flag_cell := Vector2i(-1, -1)
var _flag_pending := false
var _flag_panel: Control
var _flag_node: Node2D
var _counter_cell := Vector2i(-1, -1)
var _counter_faction := 0
var _counter_pending := false
var _counter_panel: Control
var _counter_node: Node2D
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
var _codex_panel: Control
var _codex_btn: Button
var _rel_panel: Control
var _rel_btn: Button
var _poi_pending := -1
var _node_cells: Array = []
var _node_types: Array = []
var _node_used: Dictionary = {}
var _node_pending := -1
var _npcs: Array = []
var _npc_pending := -1
var _npc_active := -1
var _npc_panel: Control
var _chest_quality: Dictionary = {}
var _poi_active := -1
var _poi_cells: Array = []
var _poi_types: Array = []
var _poi_used := {}
var _boss_cell := Vector2i(-1, -1)
var _boss_name := "山君"
var _boss_display := "山君"
var _boss_node: Node2D
var _boss_panel: Control
var _boss_pending := false
var _boss_fight_pending := false
var _arena_done := false
var _rival_cell := Vector2i(-1, -1)
var _rival_panel: Control
var _rival_pending := false
var _rival_fight_pending := false
var _rival_done := false
var _rival_contest := false
var _rival_final := false
var _rival_broker_help := false
var _broker_cell := Vector2i(-1, -1)
var _broker_panel: Control
var _broker_pending := false
var _broker_done := false
var _story_pending := false
var _story_panel: Control
var _north_cell := Vector2i(-1, -1)
var _north_panel: Control
var _north_pending := false
var _north_done := false
var _north_fight_pending := false
var _north_final := false
var _brawl_cell := Vector2i(-1, -1)
var _brawl_panel: Control
var _brawl_pending := false
var _brawl_done := false
var _chest_cells: Array = []
var _obstacles: Array = []
var _enemy_cells: Array = []
var _reveal_r := 3
var _land_id := 0
var _map_owner := 0
var _party_ids: Array = []
var _fates_keep: Array = []

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
		_set_msg("食物资源耗尽了——回村", 9.9)
		call_deferred("_return_village")

func setup(role_id := "player", diff := 1, party: Array = [], fates: Array = []) -> void:
	_role_id = role_id
	_diff = diff
	_state = RunState.new()
	_state.reset([])
	var use_party: Array = party.duplicate()
	if use_party.is_empty():
		use_party = [role_id]
	_party_ids = use_party.duplicate()
	_fates_keep = fates.duplicate()
	_state.begin_formal(use_party, _diff, fates)
	_gen_world()
	_build_astar()
	_spawn_player()
	_spawn_fx()
	_spawn_enemies()
	_spawn_boss()
	_apply_world_flags()
	_spawn_toast()
	_reveal_at(_player.position)
	queue_redraw()
	call_deferred("_maybe_ng_event")

func _gen_world() -> void:
	_land_id = clampi(GameState.current_region, 0, 4)
	_map_owner = GameState.map_owner_of(GameState.world_seed)
	_reveal_r = 2 if (_land_id == 1 or _land_id == 2 or _land_id == 4) else 3
	_obstacles.clear()
	_chest_cells.clear()
	_enemy_cells.clear()
	_poi_cells.clear()
	_poi_types.clear()
	_poi_used.clear()
	_node_cells.clear()
	_node_types.clear()
	_node_used.clear()
	_npcs.clear()
	_chest_quality.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001 + GameState.world_seed * 7919 + _land_id * 104729
	var obs_n: int = [14, 9, 11, 12, 13][_land_id]
	var guard := 0
	while _obstacles.size() < obs_n and guard < 500:
		guard += 1
		var c := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(c, 2) or _obstacles.has(c):
			continue
		_obstacles.append(c)
	var chest_n: int = [4, 5, 5, 7, 5][_land_id]
	guard = 0
	while _chest_cells.size() < chest_n and guard < 500:
		guard += 1
		var c2 := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(c2, 2) or _obstacles.has(c2) or _chest_cells.has(c2):
			continue
		_chest_cells.append(c2)
	var node_n: int = [3, 4, 4, 5, 3][_land_id]
	var node_pool: Array = []
	match _land_id:
		0: node_pool = ["ore", "bone"]
		1: node_pool = ["herb", "rice"]
		2: node_pool = ["herb", "rice"]
		3: node_pool = ["ore", "bone"]
		4: node_pool = ["snowherb", "bone"]
	var poi_order := ["temple", "well", "tea", "merchant"]
	var poi_n := 4
	if _land_id == 0:
		poi_order.append("herb_garden")
		poi_n = 5
	elif _land_id == 4:
		poi_order.append("snow_cave")
		poi_n = 5
	elif _land_id == 3:
		poi_order.append("mine")
		poi_n = 5
	elif _land_id == 1:
		poi_order.append("ferry")
		poi_n = 5
	elif _land_id == 2:
		poi_order.append("hunter")
		poi_n = 5
	var poff := (GameState.world_seed + _land_id * 7) % poi_order.size()
	guard = 0
	while _poi_cells.size() < poi_n and guard < 500:
		guard += 1
		var cp := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(cp, 1) or _obstacles.has(cp) or _chest_cells.has(cp) or _poi_cells.has(cp):
			continue
		_poi_cells.append(cp)
		_poi_types.append(poi_order[(_poi_cells.size() - 1 + poff) % poi_order.size()])
	var hunter_n := mini(2, GameState.wanted)
	var guard_n := 1 if GameState.wanted > 0 else 0
	var elite_n := 1 if GameState.world_tier >= 2 else 0
	var enemy_n := mini(9, 3 + int(GameState.world_tier / 3) + (1 if (_land_id == 2 or _land_id == 4) else 0) + (1 if _map_owner == 3 else 0) + hunter_n + guard_n + elite_n)
	guard = 0
	while _enemy_cells.size() < enemy_n and guard < 500:
		guard += 1
		var c3 := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(c3, 1) or _obstacles.has(c3) or _chest_cells.has(c3) or _poi_cells.has(c3) or _enemy_cells.has(c3):
			continue
		_enemy_cells.append(c3)
	# 赤水寨：敌对势力据点（拔寨 / 买路）
	_rival_cell = Vector2i(-1, -1)
	guard = 0
	while guard < 500:
		guard += 1
		var cr := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(cr, 2) or _obstacles.has(cr) or _chest_cells.has(cr) or _poi_cells.has(cr) or _enemy_cells.has(cr):
			continue
		if Vector2(cr).distance_to(Vector2(START_CELL)) < 7.0:
			continue
		_rival_cell = cr
		break
	var contest_chance := 0.0 if (GameState.red_water_garrison or GameState.red_water_peace) else (0.25 if GameState.red_water_wall else 0.55)
	if GameState.red_water == 2 and not GameState.red_water_peace and GameState.world_tier >= 3 and rng.randf() < contest_chance:
		_rival_contest = true
	# 听雨楼：江湖情报贩子（世界档 ≥2）
	_broker_cell = Vector2i(-1, -1)
	if GameState.world_tier >= 2:
		guard = 0
		while guard < 500:
			guard += 1
			var cb := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
			if _reserved(cb, 2) or _obstacles.has(cb) or _chest_cells.has(cb) or _poi_cells.has(cb) or _enemy_cells.has(cb) or cb == _rival_cell:
				continue
			if Vector2(cb).distance_to(Vector2(START_CELL)) < 6.0:
				continue
			_broker_cell = cb
			break
	# 北境黑风寨：第二处真实据点（未平定且世界档 ≥2）
	_north_cell = Vector2i(-1, -1)
	if GameState.world_tier >= 2:
		guard = 0
		while guard < 500:
			guard += 1
			var cn := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
			if _reserved(cn, 2) or _obstacles.has(cn) or _chest_cells.has(cn) or _poi_cells.has(cn) or _enemy_cells.has(cn) or cn == _rival_cell or cn == _broker_cell:
				continue
			if Vector2(cn).distance_to(Vector2(START_CELL)) < 7.0:
				continue
			if Vector2(cn).distance_to(Vector2(SECT_CELL)) < 8.0:
				continue
			_north_cell = cn
			break
	# 两寨火并：赤水已控 + 北境未平时，地图出现一处多方混战
	_brawl_cell = Vector2i(-1, -1)
	if GameState.red_water == 2 and not GameState.north_peace and GameState.world_tier >= 3:
		guard = 0
		while guard < 500:
			guard += 1
			var cw := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
			if _reserved(cw, 2) or _obstacles.has(cw) or _chest_cells.has(cw) or _poi_cells.has(cw) or _enemy_cells.has(cw) or cw == _rival_cell or cw == _broker_cell or cw == _north_cell:
				continue
			if Vector2(cw).distance_to(Vector2(START_CELL)) < 7.0:
				continue
			_brawl_cell = cw
			break
	# Boss 落在离起点远、避开所有已占格的位置；找不到就退到 (3,3)
	var bnames := ["山君", "夜叉", "老妖", "石傀", "雪魈"]
	_boss_name = str(bnames[_land_id])
	_boss_display = _boss_name + ("·轮回" if GameState.ng_plus > 0 else "")
	_boss_cell = Vector2i(3, 3)
	guard = 0
	while guard < 500:
		guard += 1
		var cb := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(cb, 2) or _obstacles.has(cb) or _chest_cells.has(cb) or _poi_cells.has(cb) or _enemy_cells.has(cb) or cb == _broker_cell or cb == _north_cell or cb == _brawl_cell:
			continue
		if Vector2(cb).distance_to(Vector2(START_CELL)) < 9.0:
			continue
		_boss_cell = cb
		break
	# 材料点：避开所有已占格，一图 3~5 处
	guard = 0
	while _node_cells.size() < node_n and guard < 500:
		guard += 1
		var cg := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(cg, 2) or _obstacles.has(cg) or _chest_cells.has(cg) or _poi_cells.has(cg) or _enemy_cells.has(cg) or _node_cells.has(cg):
			continue
		if cg == _boss_cell or cg == _rival_cell or cg == _broker_cell or cg == _north_cell or cg == _brawl_cell:
			continue
		_node_cells.append(cg)
		_node_types.append(str(node_pool[rng.randi_range(0, node_pool.size() - 1)]))
	# 宝箱品质：普通 70 / 精制 25 / 秘藏 5
	for cc_v in _chest_cells:
		var cc: Vector2i = cc_v
		var qr := rng.randf()
		_chest_quality[cc] = 2 if qr < 0.05 else (1 if qr < 0.30 else 0)
	# 随机 NPC：每世界 0~3 个；长线对按密信走向强制成对
	if GameState.npc_budget < 0:
		GameState.npc_budget = rng.randi_range(0, 3)
	var npc_n := 0
	if GameState.npc_budget > 0:
		npc_n = rng.randi_range(0, mini(2, GameState.npc_budget))
		GameState.npc_budget -= npc_n
	var npc_pool := ["merchant", "doctor", "storyteller", "swordsman", "thief"]
	for i in npc_n:
		var ct := str(npc_pool[rng.randi_range(0, npc_pool.size() - 1)])
		var cn := _npc_free_cell(rng)
		if cn.x >= 0:
			_npcs.append(_make_npc(cn, ct, _npc_default_name(ct)))
	var pair := _story_pair_kind()
	if pair == "qinglan":
		for nm in ["青岚执事·沈砚", "听雨楼线人·阿罗"]:
			var pc := _npc_free_cell(rng)
			if pc.x >= 0:
				_npcs.append(_make_npc(pc, "story", str(nm)))
	elif pair == "ashi":
		for nm in ["阿石", "货郎老赵"]:
			var pc2 := _npc_free_cell(rng)
			if pc2.x >= 0:
				_npcs.append(_make_npc(pc2, "story", str(nm)))
	GameState.save_game()
	# 新周目专属：轮回台（在所有占用格之后找空位）
	_wuxia_cell = Vector2i(-1, -1)
	if GameState.ng_plus > 0 and not GameState.ng_wuxia_done:
		var wg := 0
		while wg < 300:
			wg += 1
			var wc := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
			if _reserved(wc, 2) or _obstacles.has(wc) or _chest_cells.has(wc) or _poi_cells.has(wc) or _node_cells.has(wc) or _enemy_cells.has(wc):
				continue
			if wc == _boss_cell or wc == _rival_cell or wc == _broker_cell or wc == _north_cell or wc == _brawl_cell:
				continue
			var npc_taken := false
			for npc_v in _npcs:
				if Vector2i(npc_v["cell"]) == wc:
					npc_taken = true
					break
			if npc_taken:
				continue
			if Vector2(wc).distance_to(Vector2(START_CELL)) < 7.0:
				continue
			_wuxia_cell = wc
			break
	# 势力旗：非青岚归属 + 已入青岚时，每图一处夺旗点
	_flag_cell = Vector2i(-1, -1)
	if GameState.sect_joined and _map_owner != 1:
		var fg := 0
		while fg < 300:
			fg += 1
			var fc := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
			if _reserved(fc, 2) or _obstacles.has(fc) or _chest_cells.has(fc) or _poi_cells.has(fc) or _node_cells.has(fc) or _enemy_cells.has(fc):
				continue
			if fc == _boss_cell or fc == _rival_cell or fc == _broker_cell or fc == _north_cell or fc == _brawl_cell or fc == _wuxia_cell:
				continue
			var taken2 := false
			for npc_v2 in _npcs:
				if Vector2i(npc_v2["cell"]) == fc:
					taken2 = true
					break
			if taken2:
				continue
			if Vector2(fc).distance_to(Vector2(START_CELL)) < 6.0:
				continue
			_flag_cell = fc
			break
	# 反扑：青岚已控的图，若赤水残部 / 黑风仍在，可能来抢
	_counter_cell = Vector2i(-1, -1)
	if _map_owner == 1:
		var fac := 2 if GameState.red_water < 2 else (3 if not GameState.north_peace else 0)
		var cchance := 0.45
		if fac == 2:
			cchance = 0.25 + 0.003 * float(100 - clampi(GameState.war_score, 0, 100))
		else:
			cchance = 0.25 + 0.003 * float(clampi(GameState.north_score, 0, 100))
		if fac > 0 and rng.randf() < cchance:
			var cg2 := 0
			while cg2 < 300:
				cg2 += 1
				var cc2 := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
				if _reserved(cc2, 2) or _obstacles.has(cc2) or _chest_cells.has(cc2) or _poi_cells.has(cc2) or _node_cells.has(cc2) or _enemy_cells.has(cc2):
					continue
				if cc2 == _boss_cell or cc2 == _rival_cell or cc2 == _broker_cell or cc2 == _north_cell or cc2 == _brawl_cell or cc2 == _wuxia_cell or cc2 == _flag_cell:
					continue
				if Vector2(cc2).distance_to(Vector2(START_CELL)) < 7.0:
					continue
				_counter_cell = cc2
				_counter_faction = fac
				break
	_apply_story_followup()

func _apply_story_followup() -> void:
	if GameState.story_letter <= 0 or GameState.story_follow > 0:
		return
	_story_pending = true
	call_deferred("_open_story_followup")

func _open_story_followup() -> void:
	if not _story_pending or GameState.story_follow > 0:
		return
	if _story_panel == null:
		var sp = POIPanel.new()
		sp.connect("picked", _on_story_pick)
		sp.connect("closed", _on_story_closed)
		_toast_layer.add_child(sp)
		_story_panel = sp
	var data := {}
	match GameState.story_letter:
		1:
			data = {
				"title": "山 门 来 人",
				"sub": "青岚弟子在路口等你。",
				"body": "「长老说，信里的暗道图有用——山门昨夜拔了赤水一处暗哨。\n这点东西，是山门记你的。」",
				"choices": [{"id": "ok", "label": "收 下"}],
			}
		2:
			data = {
				"title": "赤 水 回 礼",
				"sub": "一个戴斗笠的人拦在路口。",
				"body": "「信有用。赤水伏了青岚一队人。\n寨主让我给你带句话——下次还有这种货，直接送来。」",
				"choices": [{"id": "ok", "label": "收 下"}],
			}
		_:
			data = {
				"title": "听 雨 楼 的 茶",
				"sub": "楼里的灯暗了一盏。",
				"body": "「楼主知道那封信被你烧了。\n茶凉了。名声，也凉一点。」",
				"choices": [{"id": "ok", "label": "知 道 了"}],
			}
	_story_panel.call("open", data)
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
	if _codex_btn != null:
		_codex_btn.visible = false
	if _rel_btn != null:
		_rel_btn.visible = false

func _on_story_pick(id: String) -> void:
	if id != "ok":
		_story_panel.call("close")
		return
	match GameState.story_letter:
		1:
			GameState.sect_favor = mini(100, GameState.sect_favor + 5)
			if GameState.sect_joined:
				GameState.sect_contrib += 30
			GameState.note_war("青岚按密信拔了赤水一处暗哨")
			GameState.note_push("青岚按密信拔了赤水一处暗哨：好感 +5" + (" · 贡献 +30" if GameState.sect_joined else ""))
		2:
			GameState.wanted = mini(5, GameState.wanted + 1)
			if not GameState.red_water_peace:
				GameState.war_score = maxi(0, GameState.war_score - 10)
			GameState.note_war("赤水按密信伏了青岚一队人")
			GameState.note_push("赤水按密信伏了青岚一队人：通缉 +1 · 战线 -10")
		_:
			GameState.broker_rep = maxi(0, GameState.broker_rep - 5)
			GameState.note_war("听雨楼查到你烧了信")
			GameState.note_push("听雨楼查到你烧了信：名声 -5")
	GameState.story_follow = 1
	GameState.save_game()
	_story_pending = false
	_story_panel.call("close")
	_set_msg("这件事有了回音。")
	queue_redraw()

func _on_story_closed() -> void:
	_story_pending = false
	_busy = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true
	if _codex_btn != null:
		_codex_btn.visible = true
	if _rel_btn != null:
		_rel_btn.visible = true

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
	_action_lb.position = Vector2(76, 60)
	_action_lb.add_theme_font_size_override("font_size", 16)
	_toast_layer.add_child(_action_lb)
	_food_meter = FoodMeter.new()
	_food_meter.position = Vector2(-58, -8)
	_food_meter.size = Vector2(44, 44)
	_action_lb.add_child(_food_meter)
	_time_lb = Label.new()
	_time_lb.position = Vector2(270, -2)
	_time_lb.add_theme_font_size_override("font_size", 15)
	_time_lb.add_theme_color_override("font_color", Color("#b9a878"))
	_action_lb.add_child(_time_lb)
	_region_lb = Label.new()
	_region_lb.position = Vector2(500, -12)
	_region_lb.size = Vector2(120, 20)
	_region_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_region_lb.add_theme_font_size_override("font_size", 12)
	_region_lb.add_theme_color_override("font_color", Color(0.62, 0.55, 0.4, 0.85))
	_action_lb.add_child(_region_lb)
	_update_action_label()
	_wanted_lb = Label.new()
	_wanted_lb.position = Vector2(584, 26)
	_wanted_lb.size = Vector2(112, 22)
	_wanted_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wanted_lb.add_theme_font_size_override("font_size", 14)
	_wanted_lb.add_theme_color_override("font_color", Color("#e06a5a"))
	_toast_layer.add_child(_wanted_lb)
	_update_wanted_label()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.05, 0.04, 0.84)
	normal.border_color = Color(0.72, 0.58, 0.22, 0.82)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.11, 0.08, 0.92)
	var bar := Button.new()
	bar.text = ""
	bar.position = Vector2(0, 1160)
	bar.size = Vector2(720, 62)
	bar.focus_mode = Control.FOCUS_NONE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.flat = true
	bar.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_toast_layer.add_child(bar)
	_back_btn = bar
	var labels := ["角色", "背包", "地图", "记录", "退出"]
	for i in labels.size():
		var b := Button.new()
		b.text = str(labels[i])
		b.position = Vector2(8 + i * 144, 10)
		b.size = Vector2(128, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", Color("#f0d68a"))
		b.add_theme_stylebox_override("normal", normal.duplicate() as StyleBoxFlat)
		b.add_theme_stylebox_override("hover", hover.duplicate() as StyleBoxFlat)
		b.add_theme_stylebox_override("pressed", hover.duplicate() as StyleBoxFlat)
		if i == 0:
			b.pressed.connect(_open_character_panel)
			_codex_btn = b
		elif i == 1:
			b.pressed.connect(_open_inventory_panel)
		elif i == 2:
			b.pressed.connect(_open_map_panel)
		elif i == 3:
			b.pressed.connect(_open_relations)
			_rel_btn = b
		else:
			b.pressed.connect(_quit_to_menu)
		bar.add_child(b)

func _maybe_ng_event() -> void:
	if GameState.ng_plus <= 0 or _busy:
		return
	if not GameState.ng_event_seen:
		GameState.ng_event_seen = true
		GameState.save_game()
		_ng_echo_mode = false
		_show_ng_panel({
			"title": "轮 回 旧 梦",
			"sub": "第 " + str(GameState.ng_plus + 1) + " 周 · 旧世界的残响",
			"body": "你在路上看见一个熟悉的背影。\n他回过头，像是上一世的你。",
			"choices": [{"id": "take", "label": "拾 起 旧 梦"}, {"id": "cut", "label": "斩 断 旧 梦"}],
		})
	elif not GameState.ng_echo_seen:
		GameState.ng_echo_seen = true
		GameState.save_game()
		_ng_echo_mode = true
		_show_ng_panel({
			"title": "旧 梦 余 响",
			"sub": "第 " + str(GameState.ng_plus + 1) + " 周 · 第二次回望",
			"body": "旧影没有散尽。它站在路边，等你再给一个答案。",
			"choices": [{"id": "take", "label": "受 它 一 礼"}, {"id": "cut", "label": "就 此 别 过"}],
		})
	elif not GameState.ng_final_seen:
		GameState.ng_final_seen = true
		GameState.save_game()
		_ng_final_mode = true
		_show_ng_panel({
			"title": "旧 梦 终 章",
			"sub": "第 " + str(GameState.ng_plus + 1) + " 周 · 最后一次回望",
			"body": "旧影已经淡了。它把一件东西放在路边，等你决定带不带走。",
			"choices": [{"id": "keep", "label": "留 下 旧 梦"}, {"id": "new", "label": "走 进 新 梦"}],
		})

func _show_ng_panel(data: Dictionary) -> void:
	if _ng_panel == null:
		var np = POIPanel.new()
		np.connect("picked", _on_ng_pick)
		np.connect("closed", _on_ng_closed)
		_toast_layer.add_child(np)
		_ng_panel = np
	_ng_panel.call("open", data)
	_busy = true
	_moving = false
	_has_click = false
	if _action_lb != null:
		_action_lb.visible = false
	if _back_btn != null:
		_back_btn.visible = false

func _on_ng_pick(id: String) -> void:
	var msg := "你站了一会儿，旧影散了。"
	if _ng_final_mode:
		if id == "keep":
			var w: Dictionary = GameState.grant_ng_weapon()
			GameState.ng_final_choice = 0
			GameState.add_prosperity(10, "旧梦终章")
			msg = "你带走了旧梦：「" + str(w.get("name", "旧梦")) + "」入库 · 繁荣 +10。"
		else:
			GameState.ng_final_choice = 1
			GameState.add_material("atlas", 2)
			GameState.add_material("jin", 2)
			GameState.action_add(30)
			GameState.add_prosperity(10, "旧梦终章")
			msg = "你把旧梦留在路边：舆图 +2 · 金髓 +2 · 食物 +30 · 繁荣 +10。"
	elif _ng_echo_mode:
		if id == "take":
			GameState.add_material("atlas", 1)
			GameState.add_region_rep(GameState.current_region, 5)
			GameState.add_prosperity(5, "旧梦余响")
			msg = "旧影行了一礼：舆图 +1 · 声望 +5 · 繁荣 +5。"
		else:
			GameState.add_material("jin", 2)
			GameState.action_add(10)
			GameState.add_prosperity(5, "旧梦余响")
			msg = "你与旧影别过：金髓 +2 · 食物 +10 · 繁荣 +5。"
	else:
		if id == "take":
			GameState.ng_event_choice = 0
			GameState.add_material("atlas", 1)
			GameState.action_add(20)
			GameState.add_prosperity(5, "轮回旧梦")
			msg = "你收下了旧梦：舆图 +1 · 食物 +20 · 繁荣 +5。"
		elif id == "cut":
			GameState.ng_event_choice = 1
			GameState.add_material("jin", 2)
			GameState.action_add(20)
			GameState.add_prosperity(5, "斩断旧梦")
			msg = "你斩断旧影：金髓 +2 · 食物 +20 · 繁荣 +5。"
	GameState.save_game()
	_update_action_label()
	_ng_panel.call("set_result", msg)

func _on_ng_closed() -> void:
	_busy = false
	_ng_echo_mode = false
	_ng_final_mode = false
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true

func _open_wuxia() -> void:
	if _wuxia_cell.x < 0:
		return
	if GameState.ng_wuxia_done:
		_set_msg("轮回台已经破了。")
		return
	if _wuxia_panel == null:
		var wp = POIPanel.new()
		wp.connect("picked", _on_wuxia_pick)
		wp.connect("closed", _on_wuxia_closed)
		_toast_layer.add_child(wp)
		_wuxia_panel = wp
	_wuxia_panel.call("open", {
		"title": "轮 回 台",
		"sub": "第 " + str(GameState.ng_plus + 1) + " 周 · 无相",
		"body": "台上没有香火，只有一面没有脸的影子。\n它等你很久了。",
		"choices": [{"id": "fight", "label": "登 台"}, {"id": "leave", "label": "退 下"}],
	})
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

func _on_wuxia_pick(id: String) -> void:
	_wuxia_panel.call("close")
	if id == "fight":
		_busy = false
		_start_wuxia_battle()

func _on_wuxia_closed() -> void:
	_busy = false
	_wuxia_pending = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true

func _start_wuxia_battle() -> void:
	if _wuxia_cell.x < 0 or GameState.ng_wuxia_done:
		return
	var tier := clampi(GameState.world_tier, 1, 5)
	var foe := {
		"hp": int(round(float(120 + tier * 15) * GameState.ng_mul())),
		"atk": maxi(1, int(round(float(2 + tier / 2.0) * GameState.ng_mul()))),
		"def": 0, "spd": 95, "scale": 1.0,
	}
	_wuxia_node = Node2D.new()
	_wuxia_node.position = _cell_pos(_wuxia_cell.x, _wuxia_cell.y)
	_wuxia_node.set_meta("boss", true)
	_wuxia_node.set_meta("special_boss", true)
	_wuxia_node.set_meta("foe_name", "无相")
	_wuxia_node.set_meta("display_name", "无相")
	_wuxia_node.set_meta("beaten", false)
	_wuxia_node.set_meta("foe", foe)
	add_child(_wuxia_node)
	_try_battle(_wuxia_node)

func _open_flag() -> void:
	if _flag_cell.x < 0 or _map_owner == 1:
		return
	if _flag_panel == null:
		var fp = POIPanel.new()
		fp.connect("picked", _on_flag_pick)
		fp.connect("closed", _on_flag_closed)
		_toast_layer.add_child(fp)
		_flag_panel = fp
	var owner_nm := "赤水" if _map_owner == 2 else ("黑风" if _map_owner == 3 else "无主")
	_flag_panel.call("open", {
		"title": "势 力 旗",
		"sub": "此图归属：" + owner_nm,
		"body": "旗还插着。守旗的人不多。\n夺下来，这张图就归青岚。",
		"choices": [{"id": "fight", "label": "夺 旗"}, {"id": "leave", "label": "退 下"}],
	})
	_busy = true
	_moving = false
	_has_click = false
	if _action_lb != null:
		_action_lb.visible = false
	if _back_btn != null:
		_back_btn.visible = false

func _on_flag_pick(id: String) -> void:
	_flag_panel.call("close")
	if id == "fight":
		_busy = false
		_start_flag_battle()

func _on_flag_closed() -> void:
	_busy = false
	_flag_pending = false
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true

func _start_flag_battle() -> void:
	if _flag_cell.x < 0 or _map_owner == 1:
		return
	var tier := clampi(GameState.world_tier, 1, 5)
	var guard := "赤水守旗" if _map_owner == 2 else ("黑风守旗" if _map_owner == 3 else "无主守卫")
	_flag_node = Node2D.new()
	_flag_node.position = _cell_pos(_flag_cell.x, _flag_cell.y)
	_flag_node.set_meta("faction_flag", true)
	_flag_node.set_meta("foe_name", guard)
	_flag_node.set_meta("display_name", guard)
	_flag_node.set_meta("beaten", false)
	_flag_node.set_meta("foe", {"hp": int(round(float(160 + tier * 30) * GameState.ng_mul())), "atk": maxi(1, int(round(float(5 + tier) * GameState.ng_mul()))), "scale": 1.0})
	add_child(_flag_node)
	_try_battle(_flag_node)

func _open_counter() -> void:
	if _counter_cell.x < 0:
		return
	if _counter_panel == null:
		var cp = POIPanel.new()
		cp.connect("picked", _on_counter_pick)
		cp.connect("closed", _on_counter_closed)
		_toast_layer.add_child(cp)
		_counter_panel = cp
	var nm := "赤水残部" if _counter_faction == 2 else "黑风悍匪"
	_counter_panel.call("open", {
		"title": "势 力 反 扑",
		"sub": nm + " 来抢旗了",
		"body": "旗还没插热，他们就摸上来了。\n迎战，还是让出这张图？",
		"choices": [{"id": "fight", "label": "迎 战"}, {"id": "cede", "label": "让 出"}],
	})
	_busy = true
	_moving = false
	_has_click = false
	if _action_lb != null:
		_action_lb.visible = false
	if _back_btn != null:
		_back_btn.visible = false

func _on_counter_pick(id: String) -> void:
	_counter_panel.call("close")
	if id == "cede":
		GameState.set_map_owner(GameState.world_seed, _counter_faction)
		if _counter_faction == 2:
			GameState.war_score = maxi(0, GameState.war_score - 5)
		else:
			GameState.north_score = mini(100, GameState.north_score + 5)
		GameState.note_war("让出了反扑的图")
		GameState.save_game()
		_map_owner = _counter_faction
		_counter_cell = Vector2i(-1, -1)
		queue_redraw()
		return
	_busy = false
	_start_counter_battle()

func _on_counter_closed() -> void:
	_busy = false
	_counter_pending = false
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true

func _start_counter_battle() -> void:
	if _counter_cell.x < 0:
		return
	var tier := clampi(GameState.world_tier, 1, 5)
	var nm := "赤水残部" if _counter_faction == 2 else "黑风悍匪"
	_counter_node = Node2D.new()
	_counter_node.position = _cell_pos(_counter_cell.x, _counter_cell.y)
	_counter_node.set_meta("faction_counter", true)
	_counter_node.set_meta("counter_faction", _counter_faction)
	_counter_node.set_meta("foe_name", nm)
	_counter_node.set_meta("display_name", nm)
	_counter_node.set_meta("beaten", false)
	_counter_node.set_meta("foe", {"hp": int(round(float(180 + tier * 30) * GameState.ng_mul())), "atk": maxi(1, int(round(float(5 + tier) * GameState.ng_mul()))), "scale": 1.0})
	add_child(_counter_node)
	_try_battle(_counter_node)

func _open_character_panel() -> void:
	if _busy:
		return
	var cp = CharacterPanel.new()
	cp.connect("closed", _on_side_closed)
	_toast_layer.add_child(cp)
	_side_panel = cp
	_hide_for_side()
	cp.call("open")

func _open_inventory_panel() -> void:
	if _busy:
		return
	var wp = WarehousePanel.new()
	wp.connect("closed", _on_side_closed)
	_toast_layer.add_child(wp)
	_side_panel = wp
	_hide_for_side()
	wp.call("open")

func _open_map_panel() -> void:
	if _busy:
		return
	var rp = RegionSelectPanel.new()
	rp.connect("entered", _on_map_region_entered)
	rp.connect("closed", _on_map_closed)
	_toast_layer.add_child(rp)
	_side_panel = rp
	_hide_for_side()
	rp.call("open")

func _on_map_region_entered(region: int) -> void:
	GameState.current_region = clampi(region, 0, 4)
	GameState.deploy_set(_party_ids, _diff, _fates_keep)
	GameState.save_game()
	get_tree().reload_current_scene()

func _on_map_closed() -> void:
	_return_village()

func _quit_to_menu() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://menu_sketch.tscn")

func _hide_for_side() -> void:
	_busy = true
	_moving = false
	_has_click = false
	if _action_lb != null:
		_action_lb.visible = false
	if _back_btn != null:
		_back_btn.visible = false
	if _rel_btn != null:
		_rel_btn.visible = false
	if _codex_btn != null:
		_codex_btn.visible = false

func _on_side_closed() -> void:
	_busy = false
	_side_panel = null
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true
	if _rel_btn != null:
		_rel_btn.visible = true
	if _codex_btn != null:
		_codex_btn.visible = true

func _node_idx_at(cell: Vector2i) -> int:
	return _node_cells.find(cell)

func _node_near(i: int) -> bool:
	if i < 0 or i >= _node_cells.size():
		return false
	return _player.position.distance_to(_cell_pos(_node_cells[i].x, _node_cells[i].y)) < 84.0

func _gather_node(i: int) -> void:
	if i < 0 or i >= _node_cells.size():
		return
	var cell: Vector2i = _node_cells[i]
	if bool(_node_used.get(cell, false)):
		return
	if not GameState.action_spend(1):
		_set_msg("食物不够——采不动了")
		return
	_node_used[cell] = true
	GameState.world_mark("node", _flag_key(cell))
	var typ := str(_node_types[i])
	var msg := ""
	match typ:
		"herb":
			if randf() < 0.5:
				GameState.add_material("zhi", 2)
				msg = "采到紫芝 ×2"
			else:
				GameState.add_material("shen", 1)
				msg = "采到雪参 ×1"
		"snowherb":
			GameState.add_material("shen", 2)
			msg = "采到雪参 ×2"
		"ore":
			var os := randi_range(2, 4)
			GameState.add_material("forge_stone", os)
			msg = "挖到锻造石 ×" + str(os)
		"bone":
			var bs := randi_range(2, 4)
			GameState.add_material("bone", bs)
			msg = "捡到兽骨碎 ×" + str(bs)
		"rice":
			var rs := randi_range(1, 3)
			GameState.add_material("rice", rs)
			msg = "采到灵米 ×" + str(rs)
	GameState.save_game()
	_update_action_label()
	queue_redraw()
	_set_msg(msg + "（食物 -1）")

func _npc_free_cell(rng: RandomNumberGenerator) -> Vector2i:
	for i in 220:
		var c := Vector2i(rng.randi_range(1, MAP_W - 2), rng.randi_range(1, MAP_H - 2))
		if _reserved(c, 2) or _obstacles.has(c) or _chest_cells.has(c) or _poi_cells.has(c) or _node_cells.has(c) or _enemy_cells.has(c) or c == _boss_cell or c == _rival_cell or c == _broker_cell or c == _north_cell or c == _brawl_cell:
			continue
		var taken := false
		for n_v in _npcs:
			if Vector2i(n_v["cell"]) == c:
				taken = true
				break
		if not taken:
			return c
	return Vector2i(-1, -1)

func _make_npc(cell: Vector2i, typ: String, nm: String) -> Dictionary:
	return {"cell": cell, "type": typ, "name": nm, "done": false, "stock_slot": -1, "stock": {}}

func _npc_key(cell: Vector2i) -> String:
	return str(GameState.world_seed) + ":" + str(GameState.current_region) + ":" + _flag_key(cell)

func _npc_price(base: int) -> int:
	var rep := int(GameState.region_rep[clampi(GameState.current_region, 0, 4)]) if GameState.region_rep.size() >= 5 else 0
	return maxi(1, int(round(float(base) * (1.0 - float(rep) * 0.002))))

func _npc_default_name(typ: String) -> String:
	return str({"merchant": "行商·赵四", "doctor": "游医·白芷", "storyteller": "说书人·柳先生", "swordsman": "落魄剑客·秦三", "thief": "偷儿·小六"}.get(typ, "江湖客"))

func _story_pair_kind() -> String:
	if GameState.story_letter == 1:
		return "qinglan"
	if GameState.story_letter >= 2:
		return "ashi"
	return ""

func _npc_idx_at(cell: Vector2i) -> int:
	for i in _npcs.size():
		if Vector2i(_npcs[i]["cell"]) == cell:
			return i
	return -1

func _npc_near(i: int) -> bool:
	if i < 0 or i >= _npcs.size():
		return false
	var c: Vector2i = _npcs[i]["cell"]
	return _player.position.distance_to(_cell_pos(c.x, c.y)) < 90.0

func _npc_type_name(typ: String) -> String:
	return str({"merchant": "行商", "doctor": "游医", "storyteller": "说书人", "swordsman": "落魄剑客", "thief": "偷儿", "story": "旧识"}.get(typ, "江湖客"))

func _draw_npcs() -> void:
	for i in _npcs.size():
		var n: Dictionary = _npcs[i]
		var c: Vector2i = n["cell"]
		if not _detail_visible(c):
			continue
		var p := _cell_pos(c.x, c.y)
		var typ := str(n["type"])
		var col := Color("#c9a64a") if typ == "merchant" else (Color("#8ab46a") if typ == "doctor" else (Color("#b9a878") if typ == "storyteller" else (Color("#8fa0b0") if typ == "swordsman" else (Color("#9a6a8a") if typ == "thief" else Color("#e0c070")))))
		if bool(n.get("done", false)):
			col = Color("#6b655c")
		draw_circle(p + Vector2(0, 18), 16.0, Color(0.04, 0.05, 0.04, 0.32))
		draw_circle(p + Vector2(0, -18), 9.0, Color("#d8c8a8"))
		draw_rect(Rect2(p + Vector2(-8, -10), Vector2(16, 26)), col)
		draw_line(p + Vector2(-8, 4), p + Vector2(-16, 12), Color("#d8c8a8"), 3.0)
		draw_line(p + Vector2(8, 4), p + Vector2(16, 12), Color("#d8c8a8"), 3.0)
		draw_string(ThemeDB.fallback_font, p + Vector2(-28, -40), str(n["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		if bool(n.get("done", false)):
			draw_string(ThemeDB.fallback_font, p + Vector2(-10, 34), "已了", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.5, 0.4, 0.8))

func _open_npc(i: int) -> void:
	if i < 0 or i >= _npcs.size():
		return
	var n: Dictionary = _npcs[i]
	if bool(n.get("done", false)):
		_set_msg(str(n["name"]) + "：话已经说完了。")
		return
	var typ := str(n["type"])
	var choices: Array = []
	match typ:
		"merchant":
			var sk := _npc_key(n["cell"])
			var slot_key := str(GameState.time_day) + ":" + str(GameState.time_slot)
			var rec: Dictionary = GameState.npc_stock.get(sk, {})
			if str(rec.get("slot", "")) != slot_key:
				rec = {"slot": slot_key, "stock": {"food": 3, "herb": 2}}
				GameState.npc_stock[sk] = rec
			n["stock"] = rec.get("stock", {"food": 3, "herb": 2})
			var st: Dictionary = n["stock"]
			choices = [{"id": "food", "label": "买干粮（" + str(_npc_price(10)) + "两 · 食物+10 · 余" + str(st.get("food", 0)) + "）"}, {"id": "herb", "label": "买药包（" + str(_npc_price(25)) + "两 · 雪参×1 · 余" + str(st.get("herb", 0)) + "）"}]
		"doctor":
			choices = [{"id": "heal", "label": "讨碗药汤（" + str(_npc_price(15)) + "两 · 食物+15）"}]
		"storyteller":
			choices = [{"id": "listen", "label": "听一段旧事（" + str(_npc_price(15)) + "两 · 开视野）"}]
		"swordsman":
			choices = [{"id": "tip", "label": "请他指点（" + str(_npc_price(50)) + "两 · 金髓×1）"}]
		"thief":
			choices = [{"id": "atlas", "label": "买一张舆图（" + str(_npc_price(120)) + "两）"}]
		_:
			choices = [{"id": "talk", "label": "说 几 句"}]
	if _npc_panel == null:
		var np = POIPanel.new()
		np.connect("picked", _on_npc_pick)
		np.connect("closed", _on_npc_closed)
		_toast_layer.add_child(np)
		_npc_panel = np
	_npc_active = i
	var body := "一个" + _npc_type_name(typ) + "在路边歇脚。"
	if typ == "story":
		body = "旧识在此，似乎有话要说。"
	_npc_panel.call("open", {"title": str(n["name"]), "sub": _npc_type_name(typ), "body": body, "choices": choices})
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
	if _codex_btn != null:
		_codex_btn.visible = false
	if _rel_btn != null:
		_rel_btn.visible = false

func _on_npc_pick(id: String) -> void:
	if _npc_active < 0 or _npc_active >= _npcs.size():
		return
	var n: Dictionary = _npcs[_npc_active]
	var msg := "你退开了。"
	match id:
		"food":
			var st: Dictionary = n.get("stock", {})
			var price := _npc_price(10)
			if int(st.get("food", 0)) <= 0:
				msg = "干粮卖完了，等下一个时段。"
			elif GameState.coin("silver") < price:
				msg = "银两不够。"
			else:
				GameState.add_coin("silver", -price)
				st["food"] = int(st.get("food", 0)) - 1
				n["stock"] = st
				GameState.npc_stock[_npc_key(n["cell"])] = {"slot": str(GameState.time_day) + ":" + str(GameState.time_slot), "stock": st}
				GameState.action_add(10)
				msg = "干粮下肚。食物 +10。"
		"herb":
			var st2: Dictionary = n.get("stock", {})
			var price2 := _npc_price(25)
			if int(st2.get("herb", 0)) <= 0:
				msg = "药包卖完了，等下一个时段。"
			elif GameState.coin("silver") < price2:
				msg = "银两不够。"
			else:
				GameState.add_coin("silver", -price2)
				st2["herb"] = int(st2.get("herb", 0)) - 1
				n["stock"] = st2
				GameState.npc_stock[_npc_key(n["cell"])] = {"slot": str(GameState.time_day) + ":" + str(GameState.time_slot), "stock": st2}
				GameState.add_material("shen", 1)
				msg = "药包入手：雪参 ×1。"
		"heal":
			var price3 := _npc_price(15)
			if GameState.coin("silver") < price3:
				msg = "银两不够。"
			else:
				GameState.add_coin("silver", -price3)
				GameState.action_add(15)
				msg = "药汤暖胃。食物 +15。"
		"listen":
			var price4 := _npc_price(15)
			if GameState.coin("silver") < price4:
				msg = "银两不够。"
			else:
				GameState.add_coin("silver", -price4)
				for k in 5:
					_reveal_at(_cell_pos(randi_range(1, MAP_W - 2), randi_range(1, MAP_H - 2)))
				n["done"] = true
				msg = "说书人讲了五处旧事。"
		"tip":
			var price5 := _npc_price(50)
			if GameState.coin("silver") < price5:
				msg = "银两不够。"
			else:
				GameState.add_coin("silver", -price5)
				GameState.add_material("jin", 1)
				n["done"] = true
				msg = "他指了指你的腕子。金髓 +1。"
		"atlas":
			var price6 := _npc_price(120)
			if GameState.coin("silver") < price6:
				msg = "银两不够。"
			else:
				GameState.add_coin("silver", -price6)
				GameState.add_material("atlas", 1)
				n["done"] = true
				msg = "偷儿塞给你一张舆图。"
		"talk":
			n["done"] = true
			GameState.add_region_rep(GameState.current_region, 5)
			GameState.world_mark("pair", str(n["name"]))
			msg = "你们交换了几句旧事。"
			var pair_id := ""
			var pair_a := ""
			var pair_b := ""
			if str(n["name"]).contains("青岚执事") or str(n["name"]).contains("听雨楼线人"):
				pair_id = "qinglan"
				pair_a = "青岚执事·沈砚"
				pair_b = "听雨楼线人·阿罗"
			elif str(n["name"]) == "阿石" or str(n["name"]) == "货郎老赵":
				pair_id = "ashi"
				pair_a = "阿石"
				pair_b = "货郎老赵"
			if pair_id != "" and GameState.world_has("pair", pair_a) and GameState.world_has("pair", pair_b) and not GameState.world_has("pair_done", pair_id):
				GameState.world_mark("pair_done", pair_id)
				GameState.add_prosperity(10, "长线旧识")
				GameState.add_region_rep(GameState.current_region, 10)
				GameState.add_material("atlas", 1)
				msg += " 两条线对上了：舆图 +1 · 声望 +10。"
	if bool(n.get("done", false)):
		GameState.world_mark("npc", _flag_key(n["cell"]))
	GameState.save_game()
	_update_action_label()
	queue_redraw()
	_npc_panel.call("set_result", msg)

func _on_npc_closed() -> void:
	_busy = false
	_npc_pending = -1
	_npc_active = -1
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true
	if _codex_btn != null:
		_codex_btn.visible = true
	if _rel_btn != null:
		_rel_btn.visible = true

func _mark_landmark(id: String) -> void:
	var arr: Array = GameState.landmarks(GameState.current_region)
	if not arr.has(id):
		GameState.mark_landmark(id)
		GameState.save_game()

func _detail_visible(cell: Vector2i) -> bool:
	if _player == null:
		return false
	var near := _player.position.distance_to(_cell_pos(cell.x, cell.y)) <= TILE * 4.0
	var key := _flag_key(cell)
	if near:
		if not GameState.world_has("seen", key):
			GameState.world_mark("seen", key)
			GameState.save_game()
		return true
	return GameState.world_has("seen", key)

func _flag_key(cell: Vector2i) -> String:
	return str(cell.x) + "," + str(cell.y)

func _apply_world_flags() -> void:
	for c_v in _chest_cells:
		var c: Vector2i = c_v
		if GameState.world_has("chest", _flag_key(c)):
			_chest_open[c] = true
	for p_v in _poi_cells:
		var p: Vector2i = p_v
		if GameState.world_has("poi", _flag_key(p)):
			_poi_used[p] = true
	for n_v in _node_cells:
		var n: Vector2i = n_v
		if GameState.world_has("node", _flag_key(n)):
			_node_used[n] = true
	for npc_v in _npcs:
		var npc: Dictionary = npc_v
		var nc: Vector2i = npc["cell"]
		if GameState.world_has("npc", _flag_key(nc)):
			npc["done"] = true
	if _boss_node != null and GameState.world_has("boss", _boss_name):
		_boss_node.set_meta("beaten", true)

func _spawn_boss() -> void:
	_boss_node = Node2D.new()
	_boss_node.position = _cell_pos(_boss_cell.x, _boss_cell.y)
	var tier := clampi(GameState.world_tier, 1, 5)
	var hp := int(round(float(280 + tier * 70) * GameState.ng_mul()))
	if GameState.boss_kills.has(_boss_name):
		hp = int(hp * 0.9)   # 图鉴弱点：首杀后识破，再战气血 -10%
	_boss_node.set_meta("boss", true)
	_boss_node.set_meta("foe_name", _boss_name)
	_boss_node.set_meta("beaten", false)
	var foe := {"hp": hp, "atk": maxi(1, int(round(float(14 + tier * 2) * GameState.ng_mul()))), "scale": 1.3}
	if _boss_name == "雪魈":
		foe["def"] = 8
		foe["spd"] = 105
		foe["frostburst"] = true
	_boss_node.set_meta("foe", foe)
	add_child(_boss_node)

func _spawn_enemies() -> void:
	var spots: Array = _enemy_cells
	if spots.is_empty():
		spots = [Vector2i(16, 16), Vector2i(7, 9), Vector2i(11, 17)]
	var hunters := mini(2, GameState.wanted)
	var guards := 1 if GameState.wanted > 0 else 0
	var elites := 1 if GameState.world_tier >= 2 else 0
	for i in spots.size():
		var is_hunter := hunters > 0 and i >= spots.size() - hunters
		var is_guard := guards > 0 and i == spots.size() - hunters - 1
		var is_elite := elites > 0 and i == spots.size() - hunters - guards - 1
		var e := _make_enemy(spots[i], i, is_hunter, is_guard, is_elite)
		if is_guard:
			_setup_guard(e, spots[i])
		_enemies.append(e)

func _setup_guard(e: Node2D, fallback: Vector2i) -> void:
	var gc := Vector2i(START_CELL.x + 3, START_CELL.y)
	if _astar.is_point_solid(gc):
		gc = fallback
	var a := _cell_pos(gc.x, gc.y)
	var gb := Vector2i(gc.x + 2, gc.y)
	if _astar.is_in_boundsv(gb) and not _astar.is_point_solid(gb):
		var b := _cell_pos(gb.x, gb.y)
		e.position = a
		e.set_meta("patrol_a", a)
		e.set_meta("patrol_b", b)
		e.set_meta("patrol_to_b", true)
	else:
		e.position = a
		e.set_meta("patrol_a", a)
		e.set_meta("patrol_b", a)
		e.set_meta("patrol_to_b", true)

# ---------- 程序化敌人模型 ----------

func _make_enemy(cell: Vector2i, i: int, hunter := false, guard := false, elite := false) -> Node2D:
	var e := Node2D.new()
	e.position = _cell_pos(cell.x, cell.y)
	var tier0 := clampi(GameState.world_tier, 1, 5)
	var kinds := ["竹妖", "野狼", "山贼"]
	if tier0 >= 2:
		kinds.append("山魈")
	if tier0 >= 3:
		kinds.append("铁甲尸")
	if tier0 >= 4:
		kinds.append("剑客")
	if tier0 >= 5:
		kinds.append("雾鬼")
	if _land_id == 4 and not kinds.has("雪狼"):
		kinds.append("雪狼")
	var base_kind: String = kinds[(i + GameState.world_seed + GameState.world_tier) % kinds.size()]
	var kind: String = base_kind
	if guard:
		base_kind = "山贼"
		kind = "捕快"
	elif hunter:
		base_kind = "山贼"
		kind = "赏金猎人"
	var aff: Dictionary = {}
	if elite:
		aff = ELITE_AFFIXES[(i + GameState.world_seed) % ELITE_AFFIXES.size()]
		kind = "精英·" + str(aff["name"]) + "·" + kind
	var tier := clampi(GameState.world_tier, 1, 5)
	e.set_meta("foe_name", kind)
	e.set_meta("hunter", hunter)
	e.set_meta("guard", guard)
	e.set_meta("elite", elite)
	var hp := 50 + i * 18 + (tier - 1) * 28
	var atk := 7 + i * 2 + (tier - 1) * 2
	var sc := 1.0
	var spd := 95
	var td := 0
	match base_kind:
		"山魈":
			hp += 40
			atk += 2
			sc = 1.12
		"铁甲尸":
			hp += 60
			atk -= 1
			td = 8
			sc = 1.05
		"剑客":
			hp += 10
			atk += 4
			spd = 108
		"雾鬼":
			hp -= 15
			atk += 2
			spd = 112
		"雪狼":
			hp += 10
			atk += 1
			spd = 110
			sc = 1.05
	if hunter:
		hp += 30
		atk += 3
	if guard:
		hp += 60
		atk += 5
	if elite:
		hp += 80 + tier * 20
		atk += 4
		sc = 1.18
		hp = int(round(float(hp) * float(aff["hp"])))
		atk = int(round(float(atk) * float(aff["atk"])))
		sc *= float(aff["scale"])
		e.set_meta("elite_affix", str(aff["id"]))
	var ng := GameState.ng_mul()
	hp = int(round(float(hp) * ng))
	atk = maxi(1, int(round(float(atk) * ng)))
	var foe := {"hp": hp, "atk": atk, "scale": sc, "spd": spd}
	if td > 0:
		foe["def"] = td
	if elite:
		foe["spd"] = spd + int(aff["spd"])
	e.set_meta("foe", foe)
	e.set_meta("beaten", false)
	e.draw.connect(func() -> void:
		match base_kind:
			"竹妖":
				_draw_zhuyiao(e)
			"野狼":
				_draw_wolf(e)
			"山魈":
				_draw_shanxiao(e)
			"铁甲尸":
				_draw_ironcorpse(e)
			"剑客":
				_draw_swordsman(e)
			"雾鬼":
				_draw_wraith(e)
			"雪狼":
				_draw_snowwolf(e)
			_:
				_draw_bandit(e)
		if elite:
			e.draw_circle(Vector2(0, -60), 4.0, Color("#ffd36a"))
		e.draw_string(ThemeDB.fallback_font, Vector2(-20, -46), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffd36a") if elite else Color("#f0d68a"))
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

func _draw_snowwolf(e: Node2D) -> void:
	e.draw_circle(Vector2(0, -8), 18.0, Color("#c9d3d6"))
	e.draw_circle(Vector2(0, -8), 12.0, Color("#e2eaec"))
	e.draw_circle(Vector2(16, -22), 9.0, Color("#c9d3d6"))
	e.draw_colored_polygon(PackedVector2Array([Vector2(11, -27), Vector2(14, -36), Vector2(18, -30)]), Color("#aebcc1"))
	e.draw_colored_polygon(PackedVector2Array([Vector2(19, -27), Vector2(23, -36), Vector2(25, -28)]), Color("#aebcc1"))
	e.draw_circle(Vector2(19, -24), 1.8, Color("#7cc8d8"))
	e.draw_line(Vector2(-12, 4), Vector2(-14, 20), Color("#aebcc1"), 4.0)
	e.draw_line(Vector2(-2, 5), Vector2(-2, 18), Color("#aebcc1"), 4.0)
	e.draw_line(Vector2(8, 5), Vector2(10, 20), Color("#aebcc1"), 4.0)
	e.draw_line(Vector2(-18, -8), Vector2(-30, -16), Color("#aebcc1"), 4.0)

func _draw_bandit(e: Node2D) -> void:
	e.draw_circle(Vector2(0, -8), 15.0, Color("#7a5a3a"))
	e.draw_rect(Rect2(-12, -2, 24, 20), Color("#6b4c30"))
	e.draw_circle(Vector2(0, -28), 9.0, Color("#c89a6a"))
	e.draw_rect(Rect2(-9, -35, 18, 6), Color("#8d2f2a"))
	e.draw_line(Vector2(-12, 2), Vector2(-20, 12), Color("#c89a6a"), 4.0)
	e.draw_line(Vector2(12, 2), Vector2(20, 8), Color("#c89a6a"), 4.0)
	e.draw_line(Vector2(20, 8), Vector2(30, -8), Color("#d8d2c2"), 3.0)

func _draw_shanxiao(e: Node2D) -> void:
	e.draw_circle(Vector2(0, -12), 24.0, Color("#5a4630"))
	e.draw_rect(Rect2(-20, -6, 40, 26), Color("#4a3828"))
	e.draw_circle(Vector2(0, -36), 13.0, Color("#6b5438"))
	e.draw_circle(Vector2(-6, -38), 2.0, Color("#1b1a18"))
	e.draw_circle(Vector2(6, -38), 2.0, Color("#1b1a18"))
	e.draw_line(Vector2(-22, -8), Vector2(-34, 12), Color("#5a4630"), 6.0)
	e.draw_line(Vector2(22, -8), Vector2(34, 12), Color("#5a4630"), 6.0)
	e.draw_line(Vector2(-10, 16), Vector2(-12, 30), Color("#4a3828"), 6.0)
	e.draw_line(Vector2(10, 16), Vector2(12, 30), Color("#4a3828"), 6.0)

func _draw_ironcorpse(e: Node2D) -> void:
	e.draw_rect(Rect2(-16, -10, 32, 30), Color("#5d625f"))
	e.draw_rect(Rect2(-12, -24, 24, 22), Color("#4a4f4c"))
	e.draw_rect(Rect2(-10, -38, 20, 12), Color("#7a7f78"))
	e.draw_line(Vector2(-18, -6), Vector2(-28, 12), Color("#3f4440"), 5.0)
	e.draw_line(Vector2(18, -6), Vector2(28, 12), Color("#3f4440"), 5.0)
	e.draw_line(Vector2(-8, 20), Vector2(-8, 32), Color("#3f4440"), 5.0)
	e.draw_line(Vector2(8, 20), Vector2(8, 32), Color("#3f4440"), 5.0)

func _draw_swordsman(e: Node2D) -> void:
	e.draw_circle(Vector2(0, -8), 15.0, Color("#3a3f52"))
	e.draw_rect(Rect2(-11, -2, 22, 22), Color("#2a2f40"))
	e.draw_circle(Vector2(0, -28), 9.0, Color("#d6b88a"))
	e.draw_rect(Rect2(-9, -34, 18, 5), Color("#2a2f40"))
	e.draw_line(Vector2(12, 0), Vector2(30, -18), Color("#e8e2d2"), 3.0)
	e.draw_line(Vector2(30, -18), Vector2(36, -22), Color("#8a6a3a"), 3.0)

func _draw_wraith(e: Node2D) -> void:
	e.draw_circle(Vector2(0, -10), 20.0, Color(0.55, 0.75, 0.82, 0.55))
	e.draw_circle(Vector2(0, -30), 11.0, Color(0.7, 0.85, 0.9, 0.62))
	e.draw_circle(Vector2(-4, -32), 2.0, Color("#d7f2f8"))
	e.draw_circle(Vector2(4, -32), 2.0, Color("#d7f2f8"))
	e.draw_line(Vector2(-18, 0), Vector2(-30, 16), Color(0.55, 0.75, 0.82, 0.45), 4.0)
	e.draw_line(Vector2(18, 0), Vector2(30, 16), Color(0.55, 0.75, 0.82, 0.45), 4.0)

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
	var grounds := ["#1b2a1c", "#1b2630", "#162a1c", "#2a2117", "#20262b"]
	draw_rect(full, Color(grounds[clampi(_land_id, 0, grounds.size() - 1)]))
	for gx in range(0, MAP_W, 2):
		for gy in range(0, MAP_H, 2):
			if _hash(gx, gy, 3) > 0.55:
				draw_rect(Rect2(Vector2(gx, gy) * TILE, Vector2(2, 2) * TILE), Color(0.11, 0.17, 0.12, 0.35))
	if _land_id == 4:
		for sx in range(MAP_W):
			for sy in range(MAP_H):
				if _hash(sx, sy, 9) > 0.9:
					draw_circle(Vector2(sx, sy) * TILE + Vector2(TILE * 0.5, TILE * 0.5), 2.0, Color(0.85, 0.9, 0.92, 0.5))
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
	_draw_rival()
	_draw_broker()
	_draw_north()
	_draw_brawl()
	_draw_boss()
	_draw_wuxia()
	_draw_faction_camp()
	_draw_counter()
	_draw_pois()
	_draw_chests()
	_draw_nodes()
	_draw_npcs()
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
	_draw_faction_flag()
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
	if not _detail_visible(HOUSE_CELL):
		return
	_mark_landmark("house")
	var p := _cell_pos(HOUSE_CELL.x, HOUSE_CELL.y)
	draw_circle(p + Vector2(0, 20), 34.0, Color(0.04, 0.06, 0.04, 0.4))
	draw_rect(Rect2(p + Vector2(-34, -26), Vector2(68, 46)), Color("#4a3a2a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-44, -22), p + Vector2(44, -22), p + Vector2(0, -60)]), Color("#6b4a30"))
	draw_rect(Rect2(p + Vector2(-10, 2), Vector2(20, 18)), Color("#2a1e14"))
	draw_circle(p + Vector2(6, 12), 2.0, Color("#c9a64a"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-18, -70), "竹屋", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f0d68a"))

func _draw_sect_gate() -> void:
	if not _detail_visible(SECT_CELL):
		return
	_mark_landmark("sect")
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

func _draw_rival() -> void:
	if _rival_cell.x < 0 or not _detail_visible(_rival_cell):
		return
	_mark_landmark("redwater")
	var p := _cell_pos(_rival_cell.x, _rival_cell.y)
	var st := GameState.red_water
	var contest := _rival_contest and not _rival_done
	var peace := GameState.red_water_peace
	var flag := Color("#5a1f1a")
	var edge := Color("#4a2a24")
	if st == 2 and not contest:
		flag = Color("#2a4a4a")
		edge = Color("#2a3a3a")
	elif st == 1:
		flag = Color("#3a3a36")
		edge = Color("#4a4a46")
	var done := (_rival_done or st > 0) and not contest
	var label := "赤水残部" if contest else ("青岚·赤水寨（已平）" if peace else ("青岚·赤水寨" if st == 2 else ("赤水寨·已破" if st == 1 else ("赤水寨·已了" if _rival_done else "赤水寨"))))
	draw_circle(p + Vector2(0, 22), 38.0, Color(0.03, 0.03, 0.03, 0.4))
	draw_rect(Rect2(p + Vector2(-34, 2), Vector2(68, 20)), Color("#3a2a22"))
	draw_rect(Rect2(p + Vector2(-40, -56), Vector2(12, 58)), edge)
	draw_rect(Rect2(p + Vector2(28, -56), Vector2(12, 58)), edge)
	draw_rect(Rect2(p + Vector2(-50, -64), Vector2(100, 12)), Color("#2a1814"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-58, -64), p + Vector2(58, -64), p + Vector2(0, -88)]), flag)
	draw_rect(Rect2(p + Vector2(-28, -112), Vector2(56, 22)), Color("#6b655c") if done else Color("#d8b06a"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-24, -96), "赤水寨", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#2a1814"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-34, -126), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9a927f") if done else Color("#e06a5a"))

func _draw_broker() -> void:
	if _broker_cell.x < 0 or not _detail_visible(_broker_cell):
		return
	_mark_landmark("broker")
	var p := _cell_pos(_broker_cell.x, _broker_cell.y)
	var col := Color("#6b655c") if _broker_done else Color("#3a4a5a")
	draw_circle(p + Vector2(0, 22), 32.0, Color(0.03, 0.03, 0.03, 0.38))
	draw_rect(Rect2(p + Vector2(-30, 0), Vector2(60, 20)), Color("#2a2e34"))
	draw_rect(Rect2(p + Vector2(-34, -38), Vector2(68, 40)), Color("#2a3038"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-44, -38), p + Vector2(44, -38), p + Vector2(0, -58)]), col)
	draw_rect(Rect2(p + Vector2(-6, -22), Vector2(12, 20)), Color("#1a1d20"))
	draw_circle(p + Vector2(20, -30), 4.0, Color("#d8b06a") if not _broker_done else Color("#6b655c"))
	draw_rect(Rect2(p + Vector2(-28, -82), Vector2(56, 20)), Color("#d8b06a") if not _broker_done else Color("#6b655c"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-24, -67), "听雨楼", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#2a1814"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-26, -96), "听雨楼", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9ab0c0") if not _broker_done else Color("#9a927f"))

func _draw_north() -> void:
	if _north_cell.x < 0 or not _detail_visible(_north_cell):
		return
	_mark_landmark("outpost" if GameState.north_peace else "north")
	var p := _cell_pos(_north_cell.x, _north_cell.y)
	var peace := GameState.north_peace
	var col := Color("#6b655c") if _north_done else (Color("#2a4a4a") if peace else Color("#262a2e"))
	draw_circle(p + Vector2(0, 22), 34.0, Color(0.03, 0.03, 0.03, 0.4))
	draw_rect(Rect2(p + Vector2(-34, 2), Vector2(68, 20)), Color("#2a2a28"))
	draw_rect(Rect2(p + Vector2(-38, -52), Vector2(10, 54)), Color("#1f2226"))
	draw_rect(Rect2(p + Vector2(28, -52), Vector2(10, 54)), Color("#1f2226"))
	draw_rect(Rect2(p + Vector2(-46, -60), Vector2(92, 10)), Color("#141618"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-54, -60), p + Vector2(54, -60), p + Vector2(0, -82)]), col)
	draw_rect(Rect2(p + Vector2(-26, -108), Vector2(52, 20)), Color("#6b655c") if _north_done else Color("#c9a64a"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-22, -93), "北境哨" if peace else "黑风寨", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#141618"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-30, -132), ("青岚·北境哨" if not _north_done else "北境哨·已取") if peace else ("黑风寨·已平" if _north_done else "黑风寨"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9a927f") if _north_done else Color("#c9a64a"))

func _draw_brawl() -> void:
	if _brawl_cell.x < 0 or not _detail_visible(_brawl_cell):
		return
	var p := _cell_pos(_brawl_cell.x, _brawl_cell.y)
	var done := _brawl_done
	draw_circle(p + Vector2(0, 18), 30.0, Color(0.03, 0.03, 0.03, 0.36))
	draw_rect(Rect2(p + Vector2(-28, 4), Vector2(56, 16)), Color("#332a22"))
	draw_line(p + Vector2(-24, 12), p + Vector2(-24, -26), Color("#3a2a1c"), 5.0)
	draw_line(p + Vector2(24, 12), p + Vector2(24, -26), Color("#3a2a1c"), 5.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-24, -26), p + Vector2(-4, -18), p + Vector2(-24, -8)]), Color("#6b655c") if done else Color("#8d2f2a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(24, -26), p + Vector2(4, -18), p + Vector2(24, -8)]), Color("#6b655c") if done else Color("#1f2226"))
	draw_line(p + Vector2(-10, 0), p + Vector2(10, -16), Color("#d8d2c2" if not done else "#6b655c"), 3.0)
	draw_string(ThemeDB.fallback_font, p + Vector2(-34, -42), "两寨火并" if not done else "火并·已散", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9a927f") if done else Color("#e06a5a"))

func _draw_faction_flag() -> void:
	if _map_owner <= 0:
		return
	var p := _cell_pos(START_CELL.x + 1, START_CELL.y - 1)
	var col := Color("#5a8a9a") if _map_owner == 1 else (Color("#8d2f2a") if _map_owner == 2 else Color("#c9a64a"))
	var nm := "青岚" if _map_owner == 1 else ("赤水" if _map_owner == 2 else "黑风")
	draw_line(p + Vector2(0, 18), p + Vector2(0, -28), Color("#3a2a1c"), 4.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -28), p + Vector2(28, -20), p + Vector2(0, -10)]), col)
	draw_string(ThemeDB.fallback_font, p + Vector2(-18, -38), "本图：" + nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)

func _draw_boss() -> void:
	if _boss_cell.x < 0 or not _detail_visible(_boss_cell):
		return
	var p := _cell_pos(_boss_cell.x, _boss_cell.y)
	var dead := _boss_node != null and bool(_boss_node.get_meta("beaten", false))
	var calm := _boss_node != null and bool(_boss_node.get_meta("appeased", false))
	draw_circle(p + Vector2(0, 22), 38.0, Color(0.03, 0.04, 0.03, 0.45))
	draw_rect(Rect2(p + Vector2(-30, 4), Vector2(60, 18)), Color("#3a3128"))
	var body_col := Color("#e6eef0") if _boss_name == "雪魈" else Color("#d8d0bc")
	draw_circle(p + Vector2(0, -8), 20.0, body_col if not dead else Color("#6b655c"))
	draw_circle(p + Vector2(-7, -10), 4.0, Color("#1b1a18"))
	draw_circle(p + Vector2(7, -10), 4.0, Color("#1b1a18"))
	draw_line(p + Vector2(-6, 2), p + Vector2(6, 2), Color("#1b1a18"), 2.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-22, -20), p + Vector2(-34, -44), p + Vector2(-12, -30)]), Color("#5a3f2a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(22, -20), p + Vector2(34, -44), p + Vector2(12, -30)]), Color("#5a3f2a"))
	var status := "·已伏" if dead else ("·已安抚" if calm else "")
	draw_string(ThemeDB.fallback_font, p + Vector2(-34, -56), _boss_display + status, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#9a927f") if (dead or calm) else Color("#e06a5a"))

func _draw_wuxia() -> void:
	if _wuxia_cell.x < 0 or not _detail_visible(_wuxia_cell):
		return
	var p := _cell_pos(_wuxia_cell.x, _wuxia_cell.y)
	var done := GameState.ng_wuxia_done
	_mark_landmark("wuxia")
	draw_circle(p + Vector2(0, 18), 34.0, Color(0.02, 0.02, 0.02, 0.45))
	draw_rect(Rect2(p + Vector2(-32, 4), Vector2(64, 20)), Color("#3a3128"))
	draw_rect(Rect2(p + Vector2(-24, -12), Vector2(48, 18)), Color("#4a4030"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-18, -12), p + Vector2(18, -12), p + Vector2(12, -26), p + Vector2(-12, -26)]), Color("#6b6252") if not done else Color("#4a4640"))
	draw_circle(p + Vector2(0, -20), 8.0, Color("#d8d0bc") if not done else Color("#6b655c"))
	draw_circle(p + Vector2(-3, -21), 2.0, Color("#1b1a18"))
	draw_circle(p + Vector2(3, -21), 2.0, Color("#1b1a18"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-30, -44), "轮回台" if not done else "轮回台·已破", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#e06a5a") if not done else Color("#6b655c"))

func _draw_faction_camp() -> void:
	if _flag_cell.x < 0 or not _detail_visible(_flag_cell):
		return
	var p := _cell_pos(_flag_cell.x, _flag_cell.y)
	var col := Color("#8d2f2a") if _map_owner == 2 else (Color("#1f2226") if _map_owner == 3 else Color("#6b655c"))
	var nm := "赤水旗" if _map_owner == 2 else ("黑风旗" if _map_owner == 3 else "无主旗")
	draw_circle(p + Vector2(0, 18), 26.0, Color(0.03, 0.04, 0.03, 0.38))
	draw_rect(Rect2(p + Vector2(-24, 2), Vector2(48, 16)), Color("#332a22"))
	draw_line(p + Vector2(0, 12), p + Vector2(0, -30), Color("#3a2a1c"), 4.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -30), p + Vector2(28, -22), p + Vector2(0, -10)]), col)
	draw_string(ThemeDB.fallback_font, p + Vector2(-24, -42), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)

func _draw_counter() -> void:
	if _counter_cell.x < 0 or not _detail_visible(_counter_cell):
		return
	var p := _cell_pos(_counter_cell.x, _counter_cell.y)
	var col := Color("#8d2f2a") if _counter_faction == 2 else Color("#1f2226")
	var nm := "赤水反扑" if _counter_faction == 2 else "黑风反扑"
	draw_circle(p + Vector2(0, 18), 28.0, Color(0.03, 0.04, 0.03, 0.4))
	draw_rect(Rect2(p + Vector2(-24, 2), Vector2(48, 16)), Color("#332a22"))
	draw_line(p + Vector2(0, 10), p + Vector2(0, -28), Color("#3a2a1c"), 4.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -28), p + Vector2(26, -20), p + Vector2(0, -8)]), col)
	draw_circle(p + Vector2(-24, -14), 5.0, Color("#e06a5a"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-30, -42), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e06a5a"))

func _draw_pois() -> void:
	for i in _poi_cells.size():
		var cell: Vector2i = _poi_cells[i]
		if not _detail_visible(cell):
			continue
		var p := _cell_pos(cell.x, cell.y)
		var typ := str(_poi_types[i])
		_mark_landmark(typ)
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
			"herb_garden":
				draw_rect(Rect2(p + Vector2(-30, 2), Vector2(60, 20)), Color("#4a3524"))
				for k in 4:
					draw_line(p + Vector2(-24 + k * 16, 14), p + Vector2(-24 + k * 16, -14), Color("#5a8a4a"), 3.0)
					draw_circle(p + Vector2(-24 + k * 16, -16), 5.0, Color("#8ab46a"))
				draw_line(p + Vector2(-34, 22), p + Vector2(34, 22), Color("#6b4a2a"), 3.0)
			"ferry":
				draw_line(p + Vector2(-30, 4), p + Vector2(30, 4), Color("#5a4630"), 5.0)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-26, 4), p + Vector2(-12, 20), p + Vector2(20, 20), p + Vector2(30, 4)]), Color("#6b4a2a"))
				draw_line(p + Vector2(0, 4), p + Vector2(0, -28), Color("#3a2a1c"), 3.0)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -28), p + Vector2(20, -22), p + Vector2(0, -12)]), Color("#c9a64a"))
			"hunter":
				draw_rect(Rect2(p + Vector2(-24, -6), Vector2(48, 30)), Color("#4a3524"))
				draw_colored_polygon(PackedVector2Array([p + Vector2(-30, -6), p + Vector2(30, -6), p + Vector2(18, -26), p + Vector2(-18, -26)]), Color("#6b4a2a"))
				draw_line(p + Vector2(-20, 22), p + Vector2(-28, 30), Color("#3a2a1c"), 3.0)
				draw_line(p + Vector2(20, 22), p + Vector2(28, 30), Color("#3a2a1c"), 3.0)
			"mine":
				draw_circle(p + Vector2(0, 6), 28.0, Color("#2a241c"))
				draw_circle(p + Vector2(0, 10), 19.0, Color("#0e0d0a"))
				draw_line(p + Vector2(-24, -18), p + Vector2(-8, 2), Color("#6b4a2a"), 5.0)
				draw_line(p + Vector2(24, -18), p + Vector2(8, 2), Color("#6b4a2a"), 5.0)
				draw_line(p + Vector2(-18, -22), p + Vector2(18, -22), Color("#3a2a1c"), 4.0)
			"snow_cave":
				draw_circle(p + Vector2(0, 2), 24.0, Color("#c9d3d6"))
				draw_circle(p + Vector2(0, 4), 17.0, Color("#14181b"))
				draw_arc(p + Vector2(0, 2), 22.0, PI, TAU, 14, Color("#8fa0a6"), 3.0)
		var nm: String = str({"temple": "破庙", "well": "古井", "tea": "茶棚", "merchant": "货郎", "snow_cave": "雪洞", "mine": "矿洞", "ferry": "渡口", "hunter": "猎户", "herb_garden": "药圃"}.get(typ, "旧迹"))
		draw_string(ThemeDB.fallback_font, p + Vector2(-22, -50), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b9a878") if used else Color("#f0d68a"))
		if used:
			draw_string(ThemeDB.fallback_font, p + Vector2(-18, -34), "已探", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.66, 0.54, 0.8))

func _draw_chests() -> void:
	for cell_v in _chest_cells:
		var cell: Vector2i = cell_v
		if not _detail_visible(cell):
			continue
		var p := _cell_pos(cell.x, cell.y)
		var opened := bool(_chest_open.get(cell, false))
		var q := int(_chest_quality.get(cell, 0))
		var body := Color("#6b4a2a") if q == 0 else (Color("#7a5a2a") if q == 1 else Color("#3a2a3a"))
		var band := Color("#8a6a3a") if q == 0 else (Color("#c9a64a") if q == 1 else Color("#e06a5a"))
		draw_circle(p + Vector2(0, 16), 16.0, Color(0.04, 0.05, 0.04, 0.35))
		draw_rect(Rect2(p + Vector2(-16, -10), Vector2(32, 22)), body)
		draw_rect(Rect2(p + Vector2(-13, -7), Vector2(26, 16)), band)
		if opened:
			draw_rect(Rect2(p + Vector2(-16, -20), Vector2(32, 10)), Color("#4a3a2a"))
		else:
			draw_rect(Rect2(p + Vector2(-16, -14), Vector2(32, 7)), Color("#5a3a20"))
			draw_rect(Rect2(p + Vector2(-4, -18), Vector2(8, 6)), Color("#f0d68a"))
		if q > 0 and not opened:
			draw_string(ThemeDB.fallback_font, p + Vector2(-18, -28), "精制" if q == 1 else "秘藏", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e8c46a") if q == 1 else Color("#e06a5a"))

func _draw_nodes() -> void:
	for i in _node_cells.size():
		var cell: Vector2i = _node_cells[i]
		if not _detail_visible(cell):
			continue
		var p := _cell_pos(cell.x, cell.y)
		var typ := str(_node_types[i])
		var used := bool(_node_used.get(cell, false))
		draw_circle(p + Vector2(0, 16), 18.0, Color(0.04, 0.05, 0.04, 0.32))
		match typ:
			"herb", "snowherb":
				draw_line(p + Vector2(0, 14), p + Vector2(0, -6), Color("#4a6a3a"), 3.0)
				draw_circle(p + Vector2(-8, -6), 7.0, Color("#5a8a4a"))
				draw_circle(p + Vector2(8, -3), 6.0, Color("#6a9a5a"))
				draw_circle(p + Vector2(0, -13), 5.0, Color("#c9d9a0") if typ == "snowherb" else Color("#8ab46a"))
			"ore":
				draw_colored_polygon(PackedVector2Array([p + Vector2(-14, 12), p + Vector2(-8, -10), p + Vector2(6, -14), p + Vector2(16, 4), p + Vector2(8, 14)]), Color("#6b6252"))
				draw_line(p + Vector2(-4, 0), p + Vector2(4, -8), Color("#c9a64a"), 2.0)
			"bone":
				draw_line(p + Vector2(-12, 10), p + Vector2(12, -8), Color("#d8d0bc"), 4.0)
				draw_circle(p + Vector2(-12, 10), 4.0, Color("#d8d0bc"))
				draw_circle(p + Vector2(12, -8), 4.0, Color("#d8d0bc"))
			"rice":
				draw_line(p + Vector2(0, 14), p + Vector2(0, -4), Color("#8a7a3a"), 2.0)
				for k in 5:
					draw_circle(p + Vector2(-8 + k * 4, -6 - (k % 2) * 5), 3.0, Color("#d9b56a"))
		var nm := "草药" if typ == "herb" else ("雪参" if typ == "snowherb" else ("矿脉" if typ == "ore" else ("兽骨" if typ == "bone" else "灵米")))
		draw_string(ThemeDB.fallback_font, p + Vector2(-20, -30), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.5, 0.4, 0.9) if used else Color("#b9d68a"))
		if used:
			draw_string(ThemeDB.fallback_font, p + Vector2(-14, 4), "采", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.5, 0.4, 0.75))

func _open_chest(cell: Vector2i) -> void:
	if bool(_chest_open.get(cell, false)):
		return
	_chest_open[cell] = true
	GameState.world_mark("chest", _flag_key(cell))
	var tier := clampi(GameState.world_tier, 1, 5)
	var q := int(_chest_quality.get(cell, 0))
	var stones := 3 + tier
	var silver := 20 + tier * 6
	if q == 1:
		stones *= 2
		silver = int(round(float(silver) * 1.5))
	elif q == 2:
		stones *= 3
		silver *= 2
	GameState.add_material("forge_stone", stones)
	GameState.add_coin("silver", silver)
	_loot_stones += stones
	_loot_silver += silver
	var extra := ""
	if q == 1:
		GameState.add_material("rice", 3)
		extra = " · 灵米 ×3"
	elif q == 2:
		GameState.add_material("atlas", 1)
		GameState.add_material("jin", 1)
		_loot_atlas += 1
		extra = " · 舆图 ×1 · 金髓 ×1"
	elif randf() < 0.22:
		GameState.add_material("atlas", 1)
		_loot_atlas += 1
		extra = " · 舆图 ×1"
	GameState.save_game()
	var qn := "" if q == 0 else ("〔精制〕" if q == 1 else "〔秘藏〕")
	_set_msg(qn + "拾得：锻造石 ×" + str(stones) + " · 银两 +" + str(silver) + extra)

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
	if _food_meter != null:
		_food_meter.call("set_value", GameState.action)
	if _time_lb != null:
		_time_lb.text = GameState.time_text()
	if _region_lb != null:
		_region_lb.text = str(GameState.REGION_NAMES[GameState.current_region]) + " D" + str(GameState.REGION_DIFFS[GameState.current_region]) + " · 档 " + str(GameState.world_tier)
	if GameState.action > 100:
		_action_lb.text = "食物 " + str(GameState.action) + " · 存粮 +" + str(GameState.action - 100)
	else:
		_action_lb.text = "食物 " + str(GameState.action) + " / 100"
	if GameState.action > 100:
		_action_lb.add_theme_color_override("font_color", Color("#e8c46a"))
	elif GameState.action <= 10:
		_action_lb.add_theme_color_override("font_color", Color("#e06a5a"))
	else:
		_action_lb.add_theme_color_override("font_color", Color("#d8cba0"))

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
		GameState.note_push("食物资源耗尽——安全回村，战利品已入账")
	GameState.save_game()
	print("[游历] 回村：锻造石=", GameState.material_count("forge_stone"), " 银两=", GameState.coin("silver"), " 食物=", GameState.action)
	get_tree().change_scene_to_file("res://menu_sketch.tscn")

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
	if _codex_panel != null and _codex_panel.visible:
		return
	if _rel_panel != null and _rel_panel.visible:
		return
	if _rival_panel != null and _rival_panel.visible:
		return
	if _broker_panel != null and _broker_panel.visible:
		return
	if _north_panel != null and _north_panel.visible:
		return
	if _brawl_panel != null and _brawl_panel.visible:
		return
	if _boss_panel != null and _boss_panel.visible:
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
		"herb_garden":
			return {"title": "药　圃", "sub": "山坳里一圈矮篱，药苗长得正好。",
				"body": "一个老樵夫蹲在圃边理药。\n\n（只能探一次）",
				"choices": [{"id": "pick", "label": "采 药（1食物）"}, {"id": "help", "label": "帮他劈柴（2食物）"}]}
		"ferry":
			return {"title": "渡　口", "sub": "水边一条旧渡船，绳子系在木桩上。",
				"body": "船底积着水，对岸雾蒙蒙的。\n\n（只能探一次）",
				"choices": [{"id": "fish", "label": "钓 鱼（1食物）"}, {"id": "cross", "label": "渡 河（1食物）"}]}
		"hunter":
			return {"title": "猎　户", "sub": "林中一间树屋，檐下挂着兽皮。",
				"body": "猎户正在磨刀，灶上炖着肉。\n\n（只能探一次）",
				"choices": [{"id": "meat", "label": "买肉（15两 · 食物+15）"}, {"id": "hunt", "label": "跟他进山（2食物）"}]}
		"mine":
			return {"title": "矿　洞", "sub": "石壁上全是旧镐痕，深处有风。",
				"body": "洞口堆着碎矿，里面黑得看不见底。\n\n（只能探一次）",
				"choices": [{"id": "dig", "label": "采 矿（1食物）"}, {"id": "deep", "label": "深 挖（3食物）"}]}
		"snow_cave":
			var cc: Array = [{"id": "warm", "label": "避 风（食物+10）"}, {"id": "probe", "label": "探 洞"}]
			if not GameState.snow_charm:
				cc.append({"id": "charm", "label": "买护符（80两）"})
			elif not GameState.snow_charm2:
				cc.append({"id": "charm", "label": "升护符（150两）"})
			return {"title": "雪　洞", "sub": "雪坡上裂开一口黑黢黢的洞。",
				"body": "洞里没有风，反倒有些暖。\n\n（只能探一次）",
				"choices": cc}
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
				_reveal_at(_cell_pos(cell.x, cell.y))
				used = true
				msg = "你上了一炷香，心里静了静。附近亮了一角。"
		"well":
			if id == "water":
				GameState.action_add(6)
				used = true
				msg = "井水冰凉，喝下去精神一振。食物 +6。"
			elif id == "probe":
				if randf() < 0.4:
					GameState.add_material("atlas", 1)
					used = true
					msg = "井底卡着一只旧木匣——里面是一张舆图。"
				else:
					GameState.add_material("forge_stone", 3)
					used = true
					msg = "井底只摸到三块沉石，倒是能当锻造石用。"
		"herb_garden":
			if id == "pick":
				if GameState.action_spend(1):
					if randf() < 0.5:
						GameState.add_material("zhi", 2)
						msg = "采到紫芝 ×2。"
					else:
						GameState.add_material("shen", 1)
						msg = "采到雪参 ×1。"
					used = true
				else:
					msg = "食物不够，蹲不下去。"
			elif id == "help":
				if GameState.action_spend(2):
					if randf() < 0.4:
						GameState.add_material("jin", 1)
						GameState.add_material("bone", 2)
						msg = "老樵夫塞给你一块金髓：金髓 +1 · 兽骨碎 +2。"
					else:
						GameState.action_add(10)
						GameState.add_material("bone", 2)
						msg = "劈完柴，老樵夫留你吃了顿饭：食物 +10 · 兽骨碎 +2。"
					used = true
				else:
					msg = "食物不够，抡不动斧。"
		"ferry":
			if id == "fish":
				if GameState.action_spend(1):
					if randf() < 0.5:
						GameState.add_material("rice", 2)
						msg = "钓上两尾银鳞。灵米 +2。"
					else:
						GameState.add_material("rice", 1)
						GameState.add_coin("silver", 12)
						msg = "鱼没钓着，倒摸到 12 两旧钱。灵米 +1。"
					used = true
				else:
					msg = "食物不够，提不动竿。"
			elif id == "cross":
				if GameState.action_spend(1):
					if randf() < 0.35:
						GameState.add_material("atlas", 1)
						msg = "船到河心，艄公递来一张旧舆图。"
					else:
						GameState.add_coin("silver", 25)
						msg = "对岸有个小集市，你换了 25 两。"
					used = true
				else:
					msg = "食物不够，划不动船。"
		"hunter":
			if id == "meat":
				if GameState.coin("silver") < 15:
					msg = "银两不够。"
				else:
					GameState.add_coin("silver", -15)
					GameState.action_add(15)
					used = true
					msg = "一碗炖肉下肚。食物 +15。"
			elif id == "hunt":
				if GameState.action_spend(2):
					if randf() < 0.35:
						GameState.add_material("jin", 1)
						GameState.add_material("bone", 2)
						msg = "猎户一箭放倒头鹿：金髓 +1 · 兽骨碎 +2。"
					else:
						var bs := randi_range(3, 5)
						GameState.add_material("bone", bs)
						msg = "只套着两只兔子：兽骨碎 +" + str(bs) + "。"
					used = true
				else:
					msg = "食物不够，走不动山路。"
		"mine":
			if id == "dig":
				if GameState.action_spend(1):
					var ms := randi_range(5, 8)
					GameState.add_material("forge_stone", ms)
					used = true
					msg = "凿下几块好矿：锻造石 +" + str(ms) + "。"
				else:
					msg = "食物不够，抡不动镐。"
			elif id == "deep":
				if GameState.action_spend(3):
					if randf() < 0.5:
						GameState.add_material("atlas", 1)
						GameState.add_material("jin", 1)
						used = true
						msg = "深洞里摸到一只铁匣：舆图 ×1 · 金髓 ×1。"
					else:
						var ms2 := randi_range(4, 7)
						GameState.add_material("forge_stone", ms2)
						used = true
						msg = "洞底塌了一角，只扒出锻造石 +" + str(ms2) + "。"
				else:
					msg = "食物不够，深挖要 3 食物。"
		"snow_cave":
			if id == "warm":
				GameState.action_add(10)
				used = true
				msg = "洞里暖得出奇，你歇了一会儿。食物 +10。"
			elif id == "probe":
				if randf() < 0.4:
					GameState.add_material("atlas", 1)
					used = true
					msg = "洞底压着半只旧箱，里面有一张舆图。"
				else:
					GameState.add_material("forge_stone", 3)
					GameState.add_coin("silver", 15)
					used = true
					msg = "洞里只有几块冻石和 15 两碎银。"
			elif id == "charm":
				if GameState.snow_charm2:
					msg = "护符已经暖透了。"
				elif not GameState.snow_charm:
					if GameState.coin("silver") < 80:
						msg = "护符要 80 两——不够。"
					else:
						GameState.add_coin("silver", -80)
						GameState.snow_charm = true
						GameState.save_game()
						msg = "你从洞壁暗格里摸出一枚暖玉护符。雪魈的寒霜会轻些；洞还能再进，护符也能再养。"
				else:
					if GameState.coin("silver") < 150:
						msg = "养护符要 150 两——不够。"
					else:
						GameState.add_coin("silver", -150)
						GameState.snow_charm2 = true
						used = true
						msg = "护符吃足了洞里的暖意。雪魈的寒霜再也压不住你了。"
		"tea":
			if id == "drink":
				if GameState.coin("silver") < 10:
					msg = "茶钱不够——老板没收你的铜板，也没给你茶。"
				else:
					GameState.add_coin("silver", -10)
					GameState.action_add(10)
					used = true
					msg = "一碗热茶下肚。食物 +10，银两 -10。"
			elif id == "listen":
				for k in 4:
					_reveal_at(_cell_pos(randi_range(1, MAP_W - 2), randi_range(1, MAP_H - 2)))
				used = true
				msg = "说书人讲了几处旧事，地图亮了一角。"
	if used:
		var first_poi := not GameState.world_has("poi", _flag_key(cell))
		_poi_used[cell] = true
		GameState.world_mark("poi", _flag_key(cell))
		if first_poi:
			GameState.add_prosperity(2, "探旧迹")
			GameState.add_region_rep(GameState.current_region, 3)
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

func _open_relations() -> void:
	if _busy:
		return
	if _rel_panel == null:
		var rp = RelationshipPanel.new()
		rp.connect("closed", _on_relations_closed)
		_toast_layer.add_child(rp)
		_rel_panel = rp
	var bs := "未动"
	if _boss_node != null:
		if bool(_boss_node.get_meta("beaten", false)):
			bs = "已伏"
		elif bool(_boss_node.get_meta("appeased", false)):
			bs = "已安抚"
	_rel_panel.call("open", {"boss": _boss_name, "boss_state": bs})
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
	if _codex_btn != null:
		_codex_btn.visible = false
	if _rel_btn != null:
		_rel_btn.visible = false

func _on_relations_closed() -> void:
	_busy = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true
	if _codex_btn != null:
		_codex_btn.visible = true
	if _rel_btn != null:
		_rel_btn.visible = true

func _open_codex() -> void:
	if _codex_panel == null:
		var cp = BossCodex.new()
		cp.connect("closed", _on_codex_closed)
		_toast_layer.add_child(cp)
		_codex_panel = cp
	_codex_panel.call("open")
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
	if _codex_btn != null:
		_codex_btn.visible = false

func _on_codex_closed() -> void:
	_busy = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true
	if _codex_btn != null:
		_codex_btn.visible = true

func _open_boss() -> void:
	if _boss_node == null or bool(_boss_node.get_meta("beaten", false)) or bool(_boss_node.get_meta("appeased", false)):
		return
	if _boss_panel == null:
		var bp = POIPanel.new()
		bp.connect("picked", _on_boss_pick)
		bp.connect("closed", _on_boss_closed)
		_toast_layer.add_child(bp)
		_boss_panel = bp
	var data := {
		"title": _boss_display,
		"sub": "盘踞在此的一方凶物。",
		"body": "山风忽然停了。\n供品要价 " + str(100 + GameState.world_tier * 20) + " 两。\n（失败会被抬回村，战利品全留）",
		"choices": [{"id": "fight", "label": "拔 剑"}, {"id": "offer", "label": "送 供 品"}],
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
		return
	if id == "offer":
		var cost := 100 + GameState.world_tier * 20
		if GameState.coin("silver") < cost:
			_boss_panel.call("set_result", "供品要 " + str(cost) + " 两——不够。")
			return
		GameState.add_coin("silver", -cost)
		GameState.add_material("atlas", 1)
		GameState.add_material("jin", 1)
		GameState.save_game()
		_boss_node.set_meta("appeased", true)
		_set_msg("你把供品摆在骸骨前。山风缓了，凶物没现身。")
		_boss_panel.call("close")
		return
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

func _rival_near() -> bool:
	if _rival_cell.x < 0:
		return false
	return _player.position.distance_to(_cell_pos(_rival_cell.x, _rival_cell.y)) < 112.0

func _open_rival() -> void:
	var contest := _rival_contest and not _rival_done
	if GameState.red_water_peace:
		_set_msg("赤水寨已平，寨门挂着青岚旗。")
		return
	_rival_final = false
	_rival_broker_help = false
	if GameState.red_water == 2 and not contest and GameState.war_score < 100:
		if GameState.red_water_wall and GameState.red_water_market and GameState.red_water_garrison and GameState.red_water_taxpost:
			_set_msg("寨墙、货栈、驻军、税所都齐了。赤水寨安稳。")
			return
	elif GameState.red_water == 1:
		_set_msg("赤水寨已经破了")
		return
	elif not contest and _rival_done:
		_set_msg("赤水寨已经了结了")
		return
	if _rival_panel == null:
		var rp = POIPanel.new()
		rp.connect("picked", _on_rival_pick)
		rp.connect("closed", _on_rival_closed)
		_toast_layer.add_child(rp)
		_rival_panel = rp
	var data := {}
	if contest:
		data = {
			"title": "赤水寨·反扑",
			"sub": "青岚控制的地盘，赤水残部摸了回来。",
			"body": "寨门外火把乱晃。\n迎战要 3 食物；让出则地盘归赤水。",
			"choices": [{"id": "defend", "label": "迎 战（3食物）"}, {"id": "cede", "label": "让 出"}],
		}
	elif GameState.red_water == 2 and GameState.war_score >= 100:
		_rival_broker_help = GameState.broker_rep >= 60
		var help_txt := "\n听雨楼递来布防图：寨主少一成半气血。" if _rival_broker_help else ""
		data = {
			"title": "赤水寨·决战",
			"sub": "青岚与赤水的账，今天一次算清。",
			"body": "寨主披甲站在门外，背后是全部残部。\n决战要 5 食物。胜了，赤水寨永平。" + help_txt,
			"choices": [{"id": "final", "label": "决 战（5食物）"}],
		}
	elif GameState.red_water == 2:
		var opts: Array = []
		var defense_done := GameState.red_water_wall and GameState.red_water_market and GameState.red_water_garrison
		if defense_done:
			if not GameState.red_water_taxpost:
				opts.append({"id": "taxpost", "label": "设税所（250两）"})
		else:
			if not GameState.red_water_wall:
				opts.append({"id": "wall", "label": "修寨墙（200两）"})
			if not GameState.red_water_market:
				opts.append({"id": "market", "label": "设货栈（150两）"})
			if not GameState.red_water_garrison:
				opts.append({"id": "garrison", "label": "驻军（300两）"})
		data = {
			"title": "赤水寨·寨务",
			"sub": "青岚控制的地盘。",
			"body": "寨墙压反扑，货栈压货价，驻军绝后患，税所添日税。\n寨墙 200 · 货栈 150 · 驻军 300 · 税所 250。",
			"choices": opts,
		}
	else:
		data = {
			"title": "赤 水 寨",
			"sub": "山道上的敌对寨子，红幡压着路口。",
			"body": "寨门半开，里面有人磨刀。\n拔寨要 3 食物；买路要 50 两。\n（失败不会被抓，只退回来）",
			"choices": [{"id": "fight", "label": "拔 寨（3食物）"}, {"id": "pay", "label": "买 路（50两）"}],
		}
	_rival_panel.call("open", data)
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
	if _codex_btn != null:
		_codex_btn.visible = false
	if _rel_btn != null:
		_rel_btn.visible = false

func _on_rival_pick(id: String) -> void:
	if _rival_contest:
		if id == "defend":
			_rival_fight_pending = true
			_rival_panel.call("close")
			return
		if id == "cede":
			GameState.red_water = 1
			GameState.war_score = maxi(0, GameState.war_score - 20)
			GameState.note_war("让出了赤水寨")
			GameState.save_game()
			_rival_done = true
			_rival_panel.call("close")
			_set_msg("你让出了赤水寨。地盘归赤水残部。")
			queue_redraw()
			return
		_rival_panel.call("close")
		return
	if id == "final":
		_rival_final = true
		_rival_fight_pending = true
		_rival_panel.call("close")
		return
	if id == "wall":
		if GameState.coin("silver") < 200:
			_rival_panel.call("set_result", "修寨墙要 200 两——不够。")
			return
		GameState.add_coin("silver", -200)
		GameState.red_water_wall = true
		GameState.add_prosperity(5, "寨墙")
		GameState.war_score = mini(100, GameState.war_score + 5)
		GameState.note_war("赤水寨修了寨墙")
		GameState.save_game()
		_rival_panel.call("close")
		_set_msg("寨墙修好了。赤水残部再来会少些。")
		queue_redraw()
		return
	if id == "market":
		if GameState.coin("silver") < 150:
			_rival_panel.call("set_result", "设货栈要 150 两——不够。")
			return
		GameState.add_coin("silver", -150)
		GameState.red_water_market = true
		GameState.add_prosperity(5, "货栈")
		GameState.war_score = mini(100, GameState.war_score + 5)
		GameState.note_war("赤水寨开了货栈")
		GameState.save_game()
		_rival_panel.call("close")
		_set_msg("货栈开了。货郎那边的价还会再低些。")
		queue_redraw()
		return
	if id == "taxpost":
		if GameState.coin("silver") < 250:
			_rival_panel.call("set_result", "设税所要 250 两——不够。")
			return
		GameState.add_coin("silver", -250)
		GameState.red_water_taxpost = true
		GameState.add_prosperity(5, "税所")
		GameState.war_score = mini(100, GameState.war_score + 5)
		GameState.note_war("赤水寨设了税所")
		GameState.save_game()
		_rival_panel.call("close")
		_set_msg("税所开了。每日地盘税会多一些。")
		queue_redraw()
		return
	if id == "garrison":
		if GameState.coin("silver") < 300:
			_rival_panel.call("set_result", "驻军要 300 两——不够。")
			return
		GameState.add_coin("silver", -300)
		GameState.red_water_garrison = true
		GameState.add_prosperity(5, "驻军")
		GameState.war_score = mini(100, GameState.war_score + 5)
		GameState.note_war("赤水寨驻了军")
		GameState.save_game()
		_rival_panel.call("close")
		_set_msg("驻军进了寨。赤水残部不敢再来了。")
		queue_redraw()
		return
	if id == "fight":
		_rival_fight_pending = true
		_rival_panel.call("close")
		return
	if id == "pay":
		if GameState.coin("silver") < 50:
			_rival_panel.call("set_result", "买路要 50 两——不够。")
			return
		GameState.add_coin("silver", -50)
		GameState.war_score = maxi(0, GameState.war_score - 5)
		GameState.note_war("向赤水寨买了路")
		GameState.save_game()
		_rival_done = true
		_rival_panel.call("close")
		_set_msg("你交了买路钱。赤水寨放你过去。")
		queue_redraw()
		return
	_rival_panel.call("close")

func _on_rival_closed() -> void:
	_busy = false
	_rival_pending = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true
	if _codex_btn != null:
		_codex_btn.visible = true
	if _rel_btn != null:
		_rel_btn.visible = true
	if _rival_fight_pending:
		_rival_fight_pending = false
		call_deferred("_rival_battle")

func _rival_battle() -> void:
	if _rival_done or _busy or _battle_active:
		return
	var cost := 5 if _rival_final else 3
	if not GameState.action_spend(cost):
		_set_msg("食物不够——要 " + str(cost) + " 点食物")
		return
	_busy = true
	_battle_active = true
	_has_click = false
	_moving = false
	queue_redraw()
	_update_action_label()
	if _action_lb != null:
		_action_lb.visible = false
	if _wanted_lb != null:
		_wanted_lb.visible = false
	if _codex_btn != null:
		_codex_btn.visible = false
	if _rel_btn != null:
		_rel_btn.visible = false
	if _back_btn != null:
		_back_btn.visible = false
	_map_pos_before_battle = _player.position
	_camera.enabled = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = false
	_player.visible = false
	var tier := clampi(GameState.world_tier, 1, 5)
	var rival_ng := GameState.ng_mul()
	var foe_hp := int(round(float((300 + tier * 55) if _rival_final else (180 + tier * 40)) * rival_ng))
	if _rival_final and _rival_broker_help:
		foe_hp = int(round(float(foe_hp) * 0.85))
	var foe_atk := maxi(1, int(round(float((10 + tier * 2) if _rival_final else (6 + tier)) * rival_ng)))
	var foe_scale := 1.1 if _rival_final else 1.0
	var node := {
		"t": "battle", "name": "赤水寨主" if not _rival_final else "赤水寨主·决战",
		"foe": {"hp": foe_hp, "atk": foe_atk, "scale": foe_scale},
		"money": [0, 0], "stick_enemies": true,
	}
	var bp := StickFighter.new()
	bp.position = Vector2(210.0, 950.0)
	add_child(bp)
	var battle := DuelBattle.new()
	add_child(battle)
	var res: Dictionary = await battle.run(_state, bp, _fx, node, false, [])
	if is_instance_valid(battle):
		battle.queue_free()
	if is_instance_valid(bp):
		bp.queue_free()
	_player.visible = true
	_player.position = _map_pos_before_battle
	_camera.enabled = true
	var won := bool(res.get("won", res.get("win", false)))
	_battle_active = false
	_busy = false
	if _back_btn != null:
		_back_btn.visible = true
	if _action_lb != null:
		_action_lb.visible = true
	if _wanted_lb != null:
		_wanted_lb.visible = GameState.wanted > 0
	if _codex_btn != null:
		_codex_btn.visible = true
	if _rel_btn != null:
		_rel_btn.visible = true
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	_update_action_label()
	if won:
		_rival_done = true
		if _rival_final:
			GameState.red_water = 2
			GameState.red_water_peace = true
			GameState.add_prosperity(20, "赤水平定")
			GameState.war_score = 100
			GameState.add_coin("silver", 300)
			GameState.add_material("atlas", 2)
			GameState.note_war("青岚平定赤水寨" + ("（听雨楼助战）" if _rival_broker_help else ""))
			GameState.save_game()
			_set_msg("寨主倒了。赤水寨永平。银两 +300 · 舆图 +2。", 3.5)
		elif _rival_contest:
			GameState.red_water = 2
			GameState.add_coin("silver", 80)
			if GameState.sect_joined:
				GameState.sect_contrib += 30
			GameState.war_score = mini(100, GameState.war_score + 15)
			GameState.note_war("青岚守住赤水寨")
			GameState.save_game()
			_set_msg("赤水残部退了。青岚仍控赤水寨：银两 +80。", 3.0)
		else:
			GameState.add_coin("silver", 150)
			GameState.add_material("atlas", 1)
			if GameState.sect_joined:
				GameState.sect_contrib += 80
				GameState.red_water = 2
				GameState.set_map_owner(GameState.world_seed, 1)
				GameState.add_prosperity(3, "拿下赤水")
				GameState.war_score = mini(100, GameState.war_score + 25)
				GameState.note_war("青岚拿下赤水寨")
			else:
				GameState.red_water = 1
				GameState.note_war("赤水寨被破")
			GameState.save_game()
			GameState.note_push("拔了赤水寨：银两 +150 · 舆图 +1" + (" · 宗门贡献 +80" if GameState.sect_joined else ""))
			_set_msg("赤水寨的旗倒了。银两 +150 · 舆图 +1。", 3.0)
	else:
		if _rival_final:
			GameState.war_score = 80
			GameState.note_war("决战失利，赤水寨还在")
			GameState.save_game()
			_set_msg("寨主太硬。决战失利，战线退到 80。", 3.0)
		elif _rival_contest:
			_rival_done = true
			GameState.red_water = 1
			GameState.war_score = maxi(0, GameState.war_score - 20)
			GameState.note_war("赤水寨夺回地盘")
			GameState.save_game()
			_set_msg("赤水残部夺回了寨子。青岚丢了赤水寨。", 3.0)
		else:
			_set_msg("寨主把你逼退了。歇一歇再来。", 3.0)
	queue_redraw()

func _broker_near() -> bool:
	if _broker_cell.x < 0:
		return false
	return _player.position.distance_to(_cell_pos(_broker_cell.x, _broker_cell.y)) < 106.0

func _broker_buy_price() -> int:
	var p := maxi(40, 80 - GameState.broker_rep / 4)
	if GameState.story_title == "听雨客":
		p = maxi(30, p - 10)
	return p

func _broker_sell_price() -> int:
	var p := 60 + GameState.broker_rep / 5
	if GameState.story_title == "听雨客":
		p += 10
	return p

func _open_broker() -> void:
	if _broker_done:
		_set_msg("听雨楼的灯灭了")
		return
	if _broker_panel == null:
		var bp = POIPanel.new()
		bp.connect("picked", _on_broker_pick)
		bp.connect("closed", _on_broker_closed)
		_toast_layer.add_child(bp)
		_broker_panel = bp
	if GameState.broker_rep >= 60 and GameState.story_letter == 0:
		var letter := {
			"title": "一封没署名的信",
			"sub": "听雨楼把它压在茶盏底下。",
			"body": "信里是青岚后山的一条暗道图，落款被烧掉了。\n交给青岚，还是卖给赤水？",
			"choices": [{"id": "letter_qinglan", "label": "交给青岚"}, {"id": "letter_chi", "label": "卖给赤水（+150两）"}, {"id": "letter_burn", "label": "烧掉"}],
		}
		_broker_panel.call("open", letter)
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
		if _codex_btn != null:
			_codex_btn.visible = false
		if _rel_btn != null:
			_rel_btn.visible = false
		return
	if GameState.broker_rep >= 90 and GameState.story_letter > 0 and GameState.story_title == "":
		var epi_choices: Array = []
		if GameState.sect_joined:
			epi_choices.append({"id": "epi_qinglan", "label": "留在青岚"})
		epi_choices.append({"id": "epi_tingyu", "label": "做听雨楼的客人"})
		epi_choices.append({"id": "epi_wander", "label": "继续走江湖"})
		var epi := {
			"title": "楼 主 的 茶",
			"sub": "听雨楼最高一层，只有一盏灯。",
			"body": "「你替青岚、替赤水、替听雨都跑过腿。\n往后的路，想挂哪一家的名？」",
			"choices": epi_choices,
		}
		_broker_panel.call("open", epi)
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
		if _codex_btn != null:
			_codex_btn.visible = false
		if _rel_btn != null:
			_rel_btn.visible = false
		return
	var choices: Array = []
	if GameState.broker_rep >= 100 and GameState.broker_quest >= 3 and not GameState.broker_weapon:
		choices.append({"id": "weapon", "label": "听雨刃（300两）"})
	if GameState.broker_rep >= 90 and GameState.wanted > 0 and not GameState.broker_pardon:
		choices.append({"id": "pardon", "label": "听雨令·抹案"})
	choices.append({"id": "buy", "label": "买消息（" + str(_broker_buy_price()) + "两）"})
	choices.append({"id": "sell", "label": "卖消息（+" + str(_broker_sell_price()) + "两）"})
	var qlabel := ""
	if GameState.broker_quest == 0 and GameState.broker_rep >= 30:
		qlabel = "接委托（2食物）"
	elif GameState.broker_quest == 1 and GameState.broker_rep >= 60:
		qlabel = "查布防（2食物）"
	elif GameState.broker_quest == 2 and GameState.broker_rep >= 90:
		qlabel = "楼主托付（3食物）"
	if qlabel != "":
		choices.append({"id": "quest", "label": qlabel})
	if choices.size() > 3:
		choices = choices.slice(0, 3)
	var data := {
		"title": "听 雨 楼",
		"sub": "檐下两盏雨灯，不问来路。名声 " + str(GameState.broker_rep) + "/100 · " + GameState.broker_rank_name() + "。",
		"body": "楼里卖两样东西：别人的布防，和你的行踪。\n买消息 " + str(_broker_buy_price()) + " 两；卖消息 +" + str(_broker_sell_price()) + " 两。",
		"choices": choices,
	}
	_broker_panel.call("open", data)
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
	if _codex_btn != null:
		_codex_btn.visible = false
	if _rel_btn != null:
		_rel_btn.visible = false

func _on_broker_pick(id: String) -> void:
	if id.begins_with("letter_"):
		if id == "letter_qinglan":
			GameState.sect_favor = mini(100, GameState.sect_favor + 10)
			GameState.broker_rep = mini(100, GameState.broker_rep + 5)
			GameState.story_letter = 1
			GameState.note_war("把听雨楼的密信交给了青岚")
			GameState.save_game()
			_broker_panel.call("close")
			_set_msg("信送进了青岚山门。山门好感 +10，听雨楼名声 +5。")
		elif id == "letter_chi":
			GameState.add_coin("silver", 150)
			GameState.wanted = mini(5, GameState.wanted + 1)
			GameState.story_letter = 2
			GameState.note_war("把青岚的密信卖给了赤水寨")
			GameState.save_game()
			_broker_panel.call("close")
			_set_msg("赤水寨收了信，给你 150 两。通缉 +1。")
		else:
			GameState.story_letter = 3
			GameState.note_war("烧了听雨楼的密信")
			GameState.save_game()
			_broker_panel.call("close")
			_set_msg("信在灯火上卷成灰。没人知道里面写了什么。")
		queue_redraw()
		return
	if id.begins_with("epi_"):
		if id == "epi_qinglan":
			GameState.story_title = "青岚客卿"
			GameState.note_story_title("青岚客卿")
			GameState.sect_favor = mini(100, GameState.sect_favor + 10)
			GameState.note_war("挂了青岚客卿的名")
		elif id == "epi_tingyu":
			GameState.story_title = "听雨客"
			GameState.note_story_title("听雨客")
			GameState.broker_rep = mini(100, GameState.broker_rep + 5)
			GameState.note_war("成了听雨楼的客人")
		else:
			GameState.story_title = "江湖散人"
			GameState.note_story_title("江湖散人")
			GameState.add_coin("silver", 100)
			GameState.note_war("不挂任何一家的名，继续走江湖")
		GameState.save_game()
		_broker_panel.call("close")
		_set_msg("从此江湖上多了一个「" + GameState.story_title + "」。")
		queue_redraw()
		return
	if id == "buy":
		var cost := _broker_buy_price()
		if GameState.coin("silver") < cost:
			_broker_panel.call("set_result", "买消息要 " + str(cost) + " 两——不够。")
			return
		GameState.add_coin("silver", -cost)
		for k in 5:
			_reveal_at(_cell_pos(randi_range(1, MAP_W - 2), randi_range(1, MAP_H - 2)))
		var got_score := GameState.red_water == 2 and not GameState.red_water_peace
		var score_gain := 10 + GameState.broker_rep / 10
		if got_score:
			GameState.war_score = mini(100, GameState.war_score + score_gain)
		GameState.broker_rep = mini(100, GameState.broker_rep + 5)
		GameState.note_war("听雨楼卖了赤水布防")
		GameState.save_game()
		_broker_done = true
		_broker_panel.call("close")
		_set_msg("布防图到手，地图亮了一角。" + (" 战线 +" + str(score_gain) + "。" if got_score else ""))
		queue_redraw()
		return
	if id == "weapon":
		if GameState.coin("silver") < 300:
			_broker_panel.call("set_result", "听雨刃要 300 两——不够。")
			return
		GameState.add_coin("silver", -300)
		var got: Dictionary = GameState.grant_broker_weapon()
		GameState.broker_weapon = true
		GameState.note_war("从听雨楼取了听雨刃")
		GameState.save_game()
		_broker_panel.call("close")
		_set_msg("楼主把「" + str(got.get("name", "听雨刃")) + "」推了过来。已入锻造库。")
		queue_redraw()
		return
	if id == "pardon":
		GameState.wanted = 0
		GameState.broker_pardon = true
		GameState.note_war("听雨楼抹了你的案子")
		GameState.save_game()
		_broker_panel.call("close")
		_set_msg("听雨令动了。通缉清零，只此一次。")
		queue_redraw()
		return
	if id == "quest":
		var stage := GameState.broker_quest
		var cost := 3 if stage == 2 else 2
		if stage > 2:
			_broker_panel.call("set_result", "听雨楼的委托已经跑完了。")
			return
		if not GameState.action_spend(cost):
			_broker_panel.call("set_result", "食物不够——这单要 " + str(cost) + " 点。")
			return
		GameState.broker_quest = stage + 1
		if stage == 0:
			GameState.broker_rep = mini(100, GameState.broker_rep + 10)
			GameState.add_coin("silver", 120)
			GameState.note_war("替听雨楼跑了一趟委托")
			_set_msg("信送到了。听雨楼给 120 两，名声 +10。")
		elif stage == 1:
			GameState.broker_rep = mini(100, GameState.broker_rep + 15)
			GameState.add_coin("silver", 120)
			if GameState.red_water == 2 and not GameState.red_water_peace:
				GameState.war_score = mini(100, GameState.war_score + 20)
			GameState.note_war("替听雨楼查了赤水布防")
			_set_msg("布防查清了。听雨楼给 120 两，名声 +15。")
		else:
			GameState.broker_rep = mini(100, GameState.broker_rep + 20)
			GameState.add_coin("silver", 200)
			GameState.add_material("atlas", 1)
			GameState.add_material("jin", 2)
			GameState.note_war("办完了听雨楼楼主的托付")
			_set_msg("楼主托付办完。银两 +200 · 舆图 +1 · 金髓 +2，名声 +20。")
		GameState.save_game()
		_broker_panel.call("close")
		queue_redraw()
		return
	if id == "sell":
		GameState.add_coin("silver", _broker_sell_price())
		GameState.broker_rep = maxi(0, GameState.broker_rep - 5)
		if not GameState.red_water_peace:
			GameState.war_score = maxi(0, GameState.war_score - 10)
		if GameState.sect_joined:
			GameState.sect_favor = maxi(0, GameState.sect_favor - 5)
		GameState.note_war("把青岚行踪卖给了听雨楼")
		GameState.save_game()
		_broker_done = true
		_broker_panel.call("close")
		_set_msg(str(_broker_sell_price()) + " 两落袋。山门那边会有人记着。")
		queue_redraw()
		return
	_broker_panel.call("close")

func _on_broker_closed() -> void:
	_busy = false
	_broker_pending = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true
	if _codex_btn != null:
		_codex_btn.visible = true
	if _rel_btn != null:
		_rel_btn.visible = true

func _north_battle() -> void:
	if _north_done or GameState.north_peace or _battle_active:
		return
	var cost := 5 if _north_final else 2
	if not GameState.action_spend(cost):
		_set_msg("食物不够——要 " + str(cost) + " 点。")
		return
	_busy = true
	_battle_active = true
	_has_click = false
	_moving = false
	queue_redraw()
	_update_action_label()
	if _action_lb != null:
		_action_lb.visible = false
	if _wanted_lb != null:
		_wanted_lb.visible = false
	if _codex_btn != null:
		_codex_btn.visible = false
	if _rel_btn != null:
		_rel_btn.visible = false
	if _back_btn != null:
		_back_btn.visible = false
	_map_pos_before_battle = _player.position
	_camera.enabled = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = false
	_player.visible = false
	var tier := clampi(GameState.world_tier, 1, 5)
	var north_ng := GameState.ng_mul()
	var foe_hp := int(round(float((320 + tier * 60) if _north_final else (160 + tier * 30)) * north_ng))
	var foe_atk := maxi(1, int(round(float((11 + tier * 2) if _north_final else (5 + tier)) * north_ng)))
	var foe_scale := 1.1 if _north_final else 1.0
	var node := {
		"t": "battle", "name": "黑风寨主" if not _north_final else "黑风寨主·决战",
		"foe": {"hp": foe_hp, "atk": foe_atk, "scale": foe_scale},
		"money": [0, 0], "stick_enemies": true,
	}
	node["affixes"] = ["leech", "berserk"] if _north_final else []
	if _north_final:
		node["arts"] = [{"name": "黑风乱斩", "kind": "dash", "mult": 1.1, "follow": 0.6, "cd": 3, "apply": {"id": "weak", "turns": 2, "stacks": 1}}]
	else:
		node["arts"] = [{"name": "黑风刀法", "kind": "damage", "mult": 1.4, "cd": 3, "apply": {"id": "sunder", "turns": 2, "stacks": 1}}]
	var bp := StickFighter.new()
	bp.position = Vector2(210.0, 950.0)
	add_child(bp)
	var battle := DuelBattle.new()
	add_child(battle)
	var res: Dictionary = await battle.run(_state, bp, _fx, node, false, [])
	if is_instance_valid(battle):
		battle.queue_free()
	if is_instance_valid(bp):
		bp.queue_free()
	_player.visible = true
	_player.position = _map_pos_before_battle
	_camera.enabled = true
	var won := bool(res.get("won", res.get("win", false)))
	_battle_active = false
	_busy = false
	if _back_btn != null:
		_back_btn.visible = true
	if _action_lb != null:
		_action_lb.visible = true
	if _wanted_lb != null:
		_wanted_lb.visible = GameState.wanted > 0
	if _codex_btn != null:
		_codex_btn.visible = true
	if _rel_btn != null:
		_rel_btn.visible = true
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	_update_action_label()
	_north_done = true
	if won:
		if _north_final:
			GameState.north_peace = true
			GameState.set_map_owner(GameState.world_seed, 1)
			GameState.add_prosperity(20, "北境平定")
			GameState.add_coin("silver", 300)
			GameState.add_material("atlas", 2)
			if not GameState.north_weapon:
				var nw: Dictionary = GameState.grant_north_weapon()
				GameState.north_weapon = true
				GameState.note_war("北境平定，取黑风刀")
				_set_msg("黑风寨的旗倒了：银两 +300 · 舆图 +2 · 黑风刀入库。", 3.0)
			else:
				GameState.note_war("北境黑风寨平定")
				_set_msg("黑风寨的旗倒了：银两 +300 · 舆图 +2。", 3.0)
		else:
			GameState.north_score = mini(100, GameState.north_score + 15)
			GameState.north_wins += 1
			GameState.add_coin("silver", 80)
			GameState.note_war("北境小胜")
			_set_msg("攻寨得手：战线 +15 · 银两 +80。", 3.0)
	else:
		if _north_final:
			GameState.north_score = 80
			GameState.note_war("北境决战失利")
			_set_msg("决战失利，北境战线退回 80。", 3.0)
		else:
			GameState.north_score = maxi(0, GameState.north_score - 10)
			GameState.note_war("北境失利")
			_set_msg("攻寨失利：战线 -10。", 3.0)
	GameState.save_game()
	queue_redraw()

func _north_near() -> bool:
	if _north_cell.x < 0:
		return false
	return _player.position.distance_to(_cell_pos(_north_cell.x, _north_cell.y)) < 110.0

func _open_north() -> void:
	if _north_done:
		_set_msg("这趟已经处理过北境了")
		return
	if _north_panel == null:
		var np = POIPanel.new()
		np.connect("picked", _on_north_pick)
		np.connect("closed", _on_north_closed)
		_toast_layer.add_child(np)
		_north_panel = np
	var data := {}
	if GameState.north_peace:
		var pchoices: Array = [{"id": "supply", "label": "取补给"}]
		if not GameState.north_garrison:
			pchoices.append({"id": "garrison", "label": "驻军（150两）"})
		data = {
			"title": "青岚·北境哨",
			"sub": "黑风寨旧址上立起了青岚的哨旗。",
			"body": "哨里的弟子认得你，搬出一只补给箱。\n（一图一次）",
			"choices": pchoices,
		}
	else:
		var choices: Array = []
		if GameState.north_score >= 100:
			choices.append({"id": "final", "label": "决 战（5食物）"})
		else:
			choices.append({"id": "raid", "label": "攻 寨（2食物）"})
			choices.append({"id": "pay", "label": "买 路（60两）"})
		data = {
			"title": "黑 风 寨",
			"sub": "北境马贼的寨子，黑幡压着风口。",
			"body": "寨墙上有人张弓。\n" + ("战线已满，可决战。" if GameState.north_score >= 100 else "攻寨 2 食物；买路 60 两。"),
			"choices": choices,
		}
	_north_panel.call("open", data)
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
	if _codex_btn != null:
		_codex_btn.visible = false
	if _rel_btn != null:
		_rel_btn.visible = false

func _on_north_pick(id: String) -> void:
	if GameState.north_peace:
		if id == "supply":
			var ss := 50 if GameState.north_garrison else 30
			var sst := 2 if GameState.north_garrison else 1
			GameState.add_coin("silver", ss)
			GameState.add_material("forge_stone", sst)
			_north_done = true
			GameState.save_game()
			_north_panel.call("close")
			_set_msg("北境哨补给：银两 +" + str(ss) + " · 锻造石 +" + str(sst) + "。")
			queue_redraw()
			return
		if id == "garrison":
			if GameState.coin("silver") < 150:
				_north_panel.call("set_result", "驻军要 150 两——不够。")
				return
			GameState.add_coin("silver", -150)
			GameState.north_garrison = true
			GameState.note_war("北境哨驻了军")
			GameState.save_game()
			_north_panel.call("close")
			_set_msg("青岚的兵进了哨。北境哨税会多些。")
			queue_redraw()
			return
		_north_panel.call("close")
		return
	if id == "pay":
		if GameState.coin("silver") < 60:
			_north_panel.call("set_result", "买路要 60 两——不够。")
			return
		GameState.add_coin("silver", -60)
		_north_done = true
		GameState.save_game()
		_north_panel.call("close")
		_set_msg("你交了买路钱。黑风寨放你过去。")
		queue_redraw()
		return
	if id == "raid":
		_north_final = false
		_north_fight_pending = true
		_north_panel.call("close")
		return
	if id == "final":
		if GameState.north_score < 100:
			return
		_north_final = true
		_north_fight_pending = true
		_north_panel.call("close")
		return
	_north_panel.call("close")

func _on_north_closed() -> void:
	_busy = false
	_north_pending = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true
	if _codex_btn != null:
		_codex_btn.visible = true
	if _rel_btn != null:
		_rel_btn.visible = true
	if _north_fight_pending:
		_north_fight_pending = false
		call_deferred("_north_battle")

func _brawl_near() -> bool:
	if _brawl_cell.x < 0:
		return false
	return _player.position.distance_to(_cell_pos(_brawl_cell.x, _brawl_cell.y)) < 108.0

func _open_brawl() -> void:
	if _brawl_done:
		_set_msg("火并已经散了")
		return
	if _brawl_panel == null:
		var bp = POIPanel.new()
		bp.connect("picked", _on_brawl_pick)
		bp.connect("closed", _on_brawl_closed)
		_toast_layer.add_child(bp)
		_brawl_panel = bp
	var data := {
		"title": "两 寨 火 并",
		"sub": "赤水与黑风的人在谷口撞上了。",
		"body": "两拨人杀得难分，地上已经躺了几个。\n帮一边，还是等他们散？",
		"choices": [{"id": "red", "label": "帮赤水"}, {"id": "black", "label": "帮黑风"}, {"id": "watch", "label": "观 战"}],
	}
	_brawl_panel.call("open", data)
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
	if _codex_btn != null:
		_codex_btn.visible = false
	if _rel_btn != null:
		_rel_btn.visible = false

func _on_brawl_pick(id: String) -> void:
	_brawl_done = true
	if id == "red":
		GameState.war_score = mini(100, GameState.war_score + 10)
		GameState.north_score = maxi(0, GameState.north_score - 10)
		GameState.add_coin("silver", 80)
		GameState.set_map_owner(GameState.world_seed, 2)
		GameState.add_prosperity(3, "赤水得图")
		GameState.add_region_rep(GameState.current_region, 10)
		GameState.note_war("两寨火并，你帮了赤水")
		_set_msg("赤水的人赢了这一阵。战线 +10 · 北境 -10 · 银两 +80。")
	elif id == "black":
		GameState.north_score = mini(100, GameState.north_score + 10)
		GameState.war_score = maxi(0, GameState.war_score - 10)
		GameState.add_coin("silver", 80)
		GameState.set_map_owner(GameState.world_seed, 3)
		GameState.add_prosperity(3, "黑风得图")
		GameState.add_region_rep(GameState.current_region, 10)
		GameState.note_war("两寨火并，你帮了黑风")
		_set_msg("黑风的人赢了这一阵。北境 +10 · 赤水 -10 · 银两 +80。")
	else:
		GameState.add_coin("silver", 30)
		GameState.note_war("你在两寨火并后捡了尸")
		_set_msg("等他们散尽，你从地上捡了 30 两。")
	GameState.save_game()
	_brawl_panel.call("close")
	queue_redraw()

func _on_brawl_closed() -> void:
	_busy = false
	_brawl_pending = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	if _action_lb != null:
		_action_lb.visible = true
	if _back_btn != null:
		_back_btn.visible = true
	if _codex_btn != null:
		_codex_btn.visible = true
	if _rel_btn != null:
		_rel_btn.visible = true

func _open_sect() -> void:
	if _sect_panel == null:
		var sp = SectPanel.new()
		sp.connect("closed", _on_sect_closed)
		sp.connect("arena_requested", _on_sect_arena)
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

func _on_sect_arena() -> void:
	call_deferred("_arena_battle")

func _arena_battle() -> void:
	if _arena_done:
		_set_msg("这一趟已经挑战过师兄了")
		return
	if _busy or _battle_active:
		return
	if not GameState.action_spend(2):
		_set_msg("食物不够——挑战师兄要 2 点食物")
		return
	_arena_done = true
	_busy = true
	_battle_active = true
	_has_click = false
	_moving = false
	queue_redraw()
	_update_action_label()
	if _action_lb != null:
		_action_lb.visible = false
	if _wanted_lb != null:
		_wanted_lb.visible = false
	if _codex_btn != null:
		_codex_btn.visible = false
	if _back_btn != null:
		_back_btn.visible = false
	_map_pos_before_battle = _player.position
	_camera.enabled = false
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = false
	_player.visible = false
	var tier := clampi(GameState.world_tier, 1, 5)
	var node := {
		"t": "battle", "name": "青岚师兄",
		"foe": {"hp": 110 + tier * 35, "atk": 9 + tier * 2, "scale": 1.05},
		"money": [0, 0], "stick_enemies": true,
	}
	var bp := StickFighter.new()
	bp.position = Vector2(210.0, 950.0)
	add_child(bp)
	var battle := DuelBattle.new()
	add_child(battle)
	var res: Dictionary = await battle.run(_state, bp, _fx, node, false, [])
	if is_instance_valid(battle):
		battle.queue_free()
	if is_instance_valid(bp):
		bp.queue_free()
	_player.visible = true
	_player.position = _map_pos_before_battle
	_camera.enabled = true
	var won := bool(res.get("won", res.get("win", false)))
	_battle_active = false
	_busy = false
	if _back_btn != null:
		_back_btn.visible = true
	if _action_lb != null:
		_action_lb.visible = true
	if _wanted_lb != null:
		_wanted_lb.visible = GameState.wanted > 0
	if _codex_btn != null:
		_codex_btn.visible = true
	for e_v in _enemies:
		var e: Node2D = e_v
		if is_instance_valid(e):
			e.visible = not bool(e.get_meta("beaten", false))
	_update_action_label()
	if won:
		GameState.sect_contrib += 30
		GameState.save_game()
		GameState.note_push("演武场胜了青岚师兄：宗门贡献 +30。")
		_set_msg("胜了师兄。宗门贡献 +30。", 3.0)
	else:
		_set_msg("师兄留了手。歇一歇再来。", 3.0)
	queue_redraw()

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
	var npc_i := _npc_idx_at(cell)
	if npc_i >= 0:
		if _npc_near(npc_i):
			_open_npc(npc_i)
			return
		_npc_pending = npc_i
	var node_i := _node_idx_at(cell)
	if node_i >= 0:
		if bool(_node_used.get(cell, false)):
			_set_msg("这里已经采过了")
			return
		if _node_near(node_i):
			_gather_node(node_i)
			return
		_node_pending = node_i
	if cell == _counter_cell:
		if _player.position.distance_to(_cell_pos(cell.x, cell.y)) < 104.0:
			_open_counter()
			return
		_counter_pending = true
	if cell == _flag_cell:
		if _map_owner == 1:
			_set_msg("这里已经归青岚了")
			return
		if _player.position.distance_to(_cell_pos(cell.x, cell.y)) < 104.0:
			_open_flag()
			return
		_flag_pending = true
	if cell == _wuxia_cell:
		if GameState.ng_wuxia_done:
			_set_msg("轮回台已经破了")
			return
		if _player.position.distance_to(_cell_pos(cell.x, cell.y)) < 104.0:
			_open_wuxia()
			return
		_wuxia_pending = true
	if cell == _boss_cell:
		if _boss_node != null and (bool(_boss_node.get_meta("beaten", false)) or bool(_boss_node.get_meta("appeased", false))):
			_set_msg("这里已经了结了")
			return
		if _boss_near():
			_open_boss()
			return
		_boss_pending = true
	if cell == _rival_cell:
		if not (_rival_contest and not _rival_done) and GameState.red_water > 0:
			_set_msg("赤水寨已归青岚" if GameState.red_water == 2 else "赤水寨已经破了")
			return
		if _rival_done:
			_set_msg("赤水寨已经了结了")
			return
		if _rival_near():
			_open_rival()
			return
		_rival_pending = true
	if cell == _broker_cell:
		if _broker_done:
			_set_msg("听雨楼的灯灭了")
			return
		if _broker_near():
			_open_broker()
			return
		_broker_pending = true
	if cell == _north_cell:
		if _north_done:
			_set_msg("北境已经处理过了")
			return
		if _north_near():
			_open_north()
			return
		_north_pending = true
	if cell == _brawl_cell:
		if _brawl_done:
			_set_msg("火并已经散了")
			return
		if _brawl_near():
			_open_brawl()
			return
		_brawl_pending = true
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
	var steps := path.size() - 1
	var food_cost := 0
	if steps > 0:
		food_cost = maxi(1, int(ceil(float(steps) / 5.0)))
	if food_cost > 0 and not GameState.action_spend(food_cost):
		_set_msg("食物不够走这一程——先回村吃点东西")
		return
	_update_action_label()
	var ri := clampi(GameState.current_region, 0, 4)
	while GameState.region_walk.size() < 5:
		GameState.region_walk.append(0)
	GameState.region_walk[ri] = int(GameState.region_walk[ri]) + steps
	if not GameState.region_seen[ri] and int(GameState.region_walk[ri]) >= 8:
		GameState.region_seen[ri] = true
		GameState.save_game()
	if food_cost > 0:
		_set_msg("走了 " + str(steps) + " 格，食物 -" + str(food_cost), 1.2)
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
	for ev in _enemies:
		var en: Node2D = ev
		if not is_instance_valid(en):
			continue
		var ec := Vector2i(int(en.position.x / TILE), int(en.position.y / TILE))
		en.visible = (not _in_house) and (not bool(en.get_meta("beaten", false))) and _detail_visible(ec)
	if not _in_house:
		for e_v in _enemies:
			var eg: Node2D = e_v
			if not is_instance_valid(eg) or bool(eg.get_meta("beaten", false)) or not bool(eg.get_meta("guard", false)):
				continue
			var pa: Vector2 = eg.get_meta("patrol_a", eg.position)
			var pb: Vector2 = eg.get_meta("patrol_b", eg.position)
			var to_b := bool(eg.get_meta("patrol_to_b", true))
			var target := pb if to_b else pa
			var gd := target - eg.position
			if gd.length() < 3.0:
				eg.set_meta("patrol_to_b", not to_b)
			else:
				eg.position += gd.normalized() * minf(58.0 * delta, gd.length())
			if eg.position.distance_to(_player.position) <= ENEMY_REACH:
				_try_battle(eg)
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
	if _node_pending >= 0 and not _in_house and _node_near(_node_pending):
		var ni2 := _node_pending
		_node_pending = -1
		_moving = false
		_path.clear()
		_has_click = false
		_gather_node(ni2)
		return
	if _npc_pending >= 0 and not _in_house and _npc_near(_npc_pending):
		var ni3 := _npc_pending
		_npc_pending = -1
		_moving = false
		_path.clear()
		_has_click = false
		_open_npc(ni3)
		return
	if _counter_pending and not _in_house and _player.position.distance_to(_cell_pos(_counter_cell.x, _counter_cell.y)) < 104.0:
		_counter_pending = false
		_moving = false
		_path.clear()
		_has_click = false
		_open_counter()
		return
	if _flag_pending and not _in_house and _player.position.distance_to(_cell_pos(_flag_cell.x, _flag_cell.y)) < 104.0:
		_flag_pending = false
		_moving = false
		_path.clear()
		_has_click = false
		_open_flag()
		return
	if _wuxia_pending and not _in_house and _player.position.distance_to(_cell_pos(_wuxia_cell.x, _wuxia_cell.y)) < 104.0:
		_wuxia_pending = false
		_moving = false
		_path.clear()
		_has_click = false
		_open_wuxia()
		return
	if _boss_pending and not _in_house and _boss_near():
		_boss_pending = false
		_moving = false
		_path.clear()
		_has_click = false
		_open_boss()
		return
	if _rival_pending and not _in_house and _rival_near():
		_rival_pending = false
		_moving = false
		_path.clear()
		_has_click = false
		_open_rival()
		return
	if _broker_pending and not _in_house and _broker_near():
		_broker_pending = false
		_moving = false
		_path.clear()
		_has_click = false
		_open_broker()
		return
	if _north_pending and not _in_house and _north_near():
		_north_pending = false
		_moving = false
		_path.clear()
		_has_click = false
		_open_north()
		return
	if _brawl_pending and not _in_house and _brawl_near():
		_brawl_pending = false
		_moving = false
		_path.clear()
		_has_click = false
		_open_brawl()
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
	var is_boss := bool(enemy.get_meta("boss", false))
	var is_special := bool(enemy.get_meta("special_boss", false))
	var is_flag := bool(enemy.get_meta("faction_flag", false))
	var is_counter := bool(enemy.get_meta("faction_counter", false))
	var is_snow_boss := is_boss and str(enemy.get_meta("foe_name", "")) == "雪魈"
	var display_name := str(enemy.get_meta("display_name", _boss_display if is_boss else str(enemy.get_meta("foe_name", "敌人"))))
	var node := {
		"t": "battle",
		"name": display_name,
		"foe": (enemy.get_meta("foe", {}) as Dictionary).duplicate(true),
		"money": [12 + GameState.world_tier * 4, 25 + GameState.world_tier * 6],
		"stick_enemies": true,   # v242：探险战斗的敌人也用火柴人
		"guard": is_guard,
		"boss": is_boss,
		"chill": is_snow_boss,
		"chill_guard": 2 if GameState.snow_charm2 else (1 if GameState.snow_charm else 0),
	}
	if is_snow_boss:
		node["affixes"] = ["berserk"]
	if is_special:
		node["affixes"] = ["berserk"]
		node["arts"] = [{"name": "无相斩", "kind": "damage", "mult": 1.45, "cd": 2, "apply": {"id": "weak", "turns": 2, "stacks": 1}}]
	elif is_boss and GameState.ng_plus > 0:
		node["arts"] = [{"name": "轮回斩", "kind": "damage", "mult": 1.35, "cd": 3, "apply": {"id": "weak", "turns": 2, "stacks": 1}}]
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
	var won := bool(res.get("won", res.get("win", false)))
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
		if is_flag:
			GameState.set_map_owner(GameState.world_seed, 1)
			GameState.war_score = mini(100, GameState.war_score + 3)
			GameState.add_prosperity(5, "夺旗")
			GameState.add_region_rep(GameState.current_region, 5)
			GameState.note_war("夺下势力旗")
			GameState.save_game()
			_map_owner = 1
			_flag_cell = Vector2i(-1, -1)
			if is_instance_valid(_flag_node):
				_flag_node.queue_free()
			_set_msg("旗倒了。这张图归青岚。", 3.0)
		if is_counter:
			GameState.war_score = mini(100, GameState.war_score + 2)
			GameState.add_prosperity(5, "守住反扑")
			GameState.add_region_rep(GameState.current_region, 5)
			GameState.note_war("守住势力反扑")
			GameState.save_game()
			_counter_cell = Vector2i(-1, -1)
			if is_instance_valid(_counter_node):
				_counter_node.queue_free()
			_set_msg("反扑退了。这张图还在青岚手里。", 3.0)
		if is_special:
			GameState.ng_wuxia_done = true
			GameState.save_game()
			GameState.note_push("踏破轮回台——无相已破。")
		if is_boss:
			GameState.note_push("击败「" + str(enemy.get_meta("foe_name", "凶物")) + "」——此方凶物已伏。")
	elif is_guard:
		GameState.jailed_days = 3
		GameState.save_game()
		GameState.note_push("被捕快拿住——押回县衙，先服刑、打点或越狱。")
		_return_village()
		return
	elif is_counter:
		var cf := int(enemy.get_meta("counter_faction", 2))
		GameState.set_map_owner(GameState.world_seed, cf)
		if cf == 2:
			GameState.war_score = maxi(0, GameState.war_score - 5)
		else:
			GameState.north_score = mini(100, GameState.north_score + 5)
		GameState.note_war("没能守住反扑的图")
		GameState.save_game()
		_map_owner = cf
		_counter_cell = Vector2i(-1, -1)
		_set_msg("旗被拔了。这张图归" + ("赤水" if cf == 2 else "黑风") + "。", 3.0)
	elif is_boss:
		GameState.note_push("被「" + str(enemy.get_meta("foe_name", "凶物")) + "」打下山，抬回村。战利品全留。")
		_return_village()
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
	if bool(enemy.get_meta("elite", false)):
		silver += 60
		stones += 3
	var fname := str(enemy.get_meta("foe_name", ""))
	var extra_mat := ""
	if fname.contains("山魈"):
		GameState.add_material("bone", 4)
		extra_mat += " · 兽骨碎 +4"
	if fname.contains("铁甲尸"):
		stones += 4
		extra_mat += " · 锻造石 +4"
	if fname.contains("剑客") and randf() < 0.25:
		GameState.add_material("jin", 1)
		extra_mat += " · 金髓 +1"
	if fname.contains("雾鬼") and randf() < 0.2:
		GameState.add_material("atlas", 1)
		_loot_atlas += 1
		extra_mat += " · 舆图 +1"
	if bool(enemy.get_meta("elite", false)):
		if fname.contains("山魈"):
			GameState.add_material("bone", 2)
			extra_mat += " · 兽骨碎 +2"
	var is_boss := bool(enemy.get_meta("boss", false))
	var first_boss := false
	var boss_drop := ""
	if is_boss:
		silver += 180
		stones += 8
		GameState.add_material("atlas", 1)
		GameState.add_material("jin", 1)
		_loot_atlas += 1
		var bname := str(enemy.get_meta("foe_name", "凶物"))
		GameState.world_mark("boss", bname)
		if not GameState.boss_kills.has(bname):
			GameState.boss_kills.append(bname)
			GameState.add_prosperity(10, "Boss首杀")
			GameState.add_region_rep(GameState.current_region, 15)
			first_boss = true
			stones += 10
			GameState.add_material("jin", 2)
			GameState.add_material("atlas", 1)
			_loot_atlas += 1
			var drop := GameState.grant_boss_weapon(bname)
			boss_drop = str(drop.get("name", ""))
	if GameState.story_title == "江湖散人":
		silver = int(round(float(silver) * 1.1))
	if _map_owner == 1:
		silver = int(round(float(silver) * 1.1))
	elif _map_owner == 3:
		silver = int(round(float(silver) * 1.2))
	GameState.add_coin("silver", silver)
	GameState.add_material("forge_stone", stones)
	_loot_silver += silver
	_loot_stones += stones
	GameState.save_game()
	var tail := " · 通缉 +1" if bool(enemy.get_meta("guard", false)) else ""
	if bool(enemy.get_meta("elite", false)):
		tail += " · 精英 +60 两 +3 石"
	if is_boss:
		tail += " · 舆图 +1 · 金髓 +1"
		if first_boss:
			tail += " · 首杀：金髓 +2 · 舆图 +1 · 锻造石 +10"
			if boss_drop != "":
				tail += " · 专属「" + boss_drop + "」"
	_set_msg("击败「" + fname + "」：银两 +" + str(silver) + " · 锻造石 +" + str(stones) + tail + extra_mat, 3.0)

