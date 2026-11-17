extends SceneTree
const GS := preload("res://shared/game_state.gd")
class CoreProbe extends RefCounted:
	var hero := {"atk": 100.0, "hp": 100.0}
	var running := true
	var _enemy_attack_epoch := 0
	var hero_pos := Vector2.ZERO
	var foes := [{"hp": 1000.0, "x": 0.0, "y": -100.0}]
class BattleProbe extends "res://kushou/battle_ui.gd":
	var captured := 0.0
	func _feiren_line(_origin: Vector2, _d: Vector2, base: float, _pierce: int, _volley: bool, _vmul: float) -> void:
		captured = base
func _initialize() -> void:
	var battle := BattleProbe.new()
	battle._core = CoreProbe.new()
	GS.skill_lv = {}
	battle._cast_skill(-1)
	battle._cast_skill(0)
	battle._cast_feiren(1.2)
	assert(is_equal_approx(battle.captured, 120.0))
	GS.skill_lv = {"qingluan": 10}
	battle._cast_feiren(1.2)
	assert(is_equal_approx(battle.captured, 156.0))
	battle.free()
	print("PASS: invalid skill indices safe; flying blade level 10 damage 120 -> 156")
	quit()
