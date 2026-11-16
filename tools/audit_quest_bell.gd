extends SceneTree
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")
class Probe extends "res://kushou/battle_ui.gd":
	var bonus := false
	func _roll_bell_treasure() -> bool: return bonus

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _quest(battle, id: String) -> Dictionary:
	for q in battle.QUEST_POOL:
		if q["id"] == id: return q.duplicate(true)
	return {}

func _taken(battle) -> int:
	return battle._bond_taken.size() + battle._rare_taken.size()

func _label_text(node: Node) -> String:
	var result: String = node.text if node is Label else ""
	for child in node.get_children(): result += _label_text(child)
	return result

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle := Probe.new()
	root.add_child(battle)
	battle.set_process(false)
	battle._core.set_process(false)
	battle._curio_id = "zhenhunling"
	# 待接时不替换，不储存后续；结束后从零计时。
	battle._curio_lv = 1
	battle._q_tick(battle._q_interval())
	assert(not battle._q_offer.is_empty())
	var offered: String = battle._q_offer["id"]
	for i in range(5):
		battle._q_roll()
		battle._q_tick(battle._q_interval())
		assert(battle._q_offer["id"] == offered and battle._q_t == 0.0)
	battle._q_decline()
	assert(battle._q_offer.is_empty())
	battle._q_tick(battle._q_interval() - 0.01)
	assert(battle._q_offer.is_empty())
	battle._q_tick(0.02)
	assert(not battle._q_offer.is_empty())
	battle._q_decline()
	battle._q_activate(_quest(battle, "tu"))
	for i in range(5): battle._q_roll()
	assert(battle._q_offer.is_empty())
	battle._q_finish("fail")
	assert(battle._q_offer.is_empty() and battle._q_cur.is_empty() and battle._q_t == 0.0)
	# 所有奖励统一取整，预览与实际发放相同，原模板不变。
	var reward := {"id": "test", "n": "奖励", "kind": "count", "key": "kill", "need": 1, "lim": 0.0, "desc": "测试", "r": {"crystal": 25, "wen": 100, "trea_rr": 2, "aug_rr": 1, "trea": 2}}
	battle._curio_lv = 2
	assert(battle._q_rewards(reward) == {"crystal": 33, "wen": 130, "trea_rr": 3, "aug_rr": 1, "trea": 3})
	battle._q_offer = battle._q_prepare(reward)
	battle._q_open_popup()
	var preview := _label_text(battle._q_pop)
	assert(preview.contains("灵晶 33") and preview.contains("文钱 130") and preview.contains("宝物刷新 3"))
	battle._q_offer = {}
	battle._q_close_popup()
	var rr: int = battle._trea_reroll
	var charges: int = battle._trea_charge
	battle._crystal = 0
	battle._wen = 0
	battle._q_activate(reward)
	battle._qc("kill", 1)
	assert(battle._crystal == 33 and battle._wen == 130)
	assert(battle._trea_reroll == rr + 3 and battle._trea_charge == charges + 3)
	assert(reward["r"]["crystal"] == 25)
	# 五级直接奖励宝物，保留正在选择的一手与机会数量。
	battle._curio_lv = 5
	battle.bonus = true
	battle._trea_pending = true
	battle._roll_trea()
	battle._trea_layer.visible = true
	var shown := []
	for card in battle._trea_cards: shown.append(card.o.duplicate(true))
	var owned := _taken(battle)
	charges = battle._trea_charge
	battle._q_activate(_quest(battle, "tu"))
	battle._qc("kill", 32)
	assert(_taken(battle) == owned + 1 and battle._trea_charge == charges)
	assert(battle._trea_pending and battle._trea_layer.visible)
	for i in range(shown.size()): assert(battle._trea_cards[i].o == shown[i])
	# 原手仍能只领取一张；普通羁绊也计入寻宝进度。
	battle.bonus = false
	battle._q_activate(_quest(battle, "xb"))
	owned = _taken(battle)
	var completed: int = battle._q_done
	battle._on_trea_card(battle._trea_cards[0])
	assert(_taken(battle) == owned + 1 and battle._q_done == completed + 1)
	battle._on_trea_card(battle._trea_cards[1])
	assert(_taken(battle) == owned + 1)
	# 代价卡不得自动强选；池耗尽时不谎报已发宝物。
	for item in battle.BOND_POOL: battle._bond_taken[item["name"]] = true
	for item in battle.RARE_POOL:
		if item.get("kind", "") not in ["convert", "crystal_burst"]: battle._rare_taken[item["name"]] = true
	battle._wen = 777
	assert(not battle._grant_random_treasure())
	assert(battle._wen == 777 and not battle._crystal_lock)
	battle.queue_free()
	await process_frame
	print("PASS: single quest/no backlog; boosted reward preview; actual safe bonus treasure preserves hand and claims once")
	Audio.quit_cleanly()
