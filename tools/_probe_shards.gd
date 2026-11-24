extends SceneTree
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var r8: Dictionary = LS.first_reward(8)
	var r9: Dictionary = LS.first_reward(9)
	var r10: Dictionary = LS.first_reward(10)
	print("[8] shards=", r8.get("shards", {}))
	print("[9] shards=", r9.get("shards", {}))
	print("[10] shards=", r10.get("shards", {}))
	# 模拟领奖：直接调 _grant_first_clear 需要战斗实例；这里只校验数据面
	GS.ensure_loaded()
	var before: int = int(GS.shards.get("liuqingqing", 0))
	for kv in (r8.get("shards", {}) as Dictionary).keys():
		GS.shards[str(kv)] = int(GS.shards.get(str(kv), 0)) + int(r8["shards"][kv])
	print("[apply] liuqingqing ", before, " -> ", int(GS.shards.get("liuqingqing", 0)))
	quit(0)
