extends SceneTree
const LS := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")
class Probe extends "res://kushou/battle_ui.gd":
	var wins := true
	var gamble_rolls := 0
	var bonus_rolls := 0
	var bonus_grants := 0
	func _roll_quest_gamble() -> bool:
		gamble_rolls += 1
		return wins
	func _roll_bell_treasure() -> bool:
		bonus_rolls += 1
		return true
	func _grant_random_treasure() -> bool:
		bonus_grants += 1
		return true # 实际宝物发放及手牌隔离另由quest_bell专项验证。

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _offer(battle) -> void:
	for q in battle.QUEST_POOL:
		if q["id"] == "dj": battle._q_offer = battle._q_prepare(q)

func _labels(node: Node) -> String:
	var result: String = node.text if node is Label else ""
	for child in node.get_children(): result += _labels(child)
	return result

func _run() -> void:
	LS.ensure_loaded()
	LS.current_level = 6
	var battle := Probe.new()
	root.add_child(battle)
	battle.set_process(false)
	battle._core.set_process(false)
	battle._curio_id = ""
	battle._gold_pct = 0.0
	battle._wen = 99
	_offer(battle)
	battle._q_open_popup()
	var text := _labels(battle._q_pop)
	assert(text.contains("接受后立即结算") and text.contains("损失 100 文押金") and text.contains("文钱 400"))
	battle._q_accept()
	assert(battle._wen == 99 and not battle._q_offer.is_empty())
	assert(battle._q_pop != null and battle._q_done == 0 and battle._q_fail == 0 and battle.gamble_rolls == 0)
	assert(battle._toast_lb.text.contains("不足"))
	# 补足费用后只能结算一次，400是中奖收入，押金不返还。
	battle._wen = 100
	var offered: Dictionary = battle._q_offer
	battle._q_accept()
	assert(battle._wen == 400 and battle._q_done == 1 and battle._q_fail == 0)
	assert(battle._q_cur.is_empty() and battle._q_offer.is_empty() and battle.gamble_rolls == 1)
	assert((battle._toast_lb.text + str(battle._toast_queue)).contains("获得 400 文"))
	battle._q_accept()
	battle._q_instant(offered)
	assert(battle._wen == 400 and battle.gamble_rolls == 1)
	# 失败不发奖励；普通费用不受镇魂铃奖励加成影响。
	battle.wins = false
	battle._curio_id = "zhenhunling"
	battle._curio_lv = 5
	battle._wen = 100
	_offer(battle)
	battle._q_accept()
	assert(battle._wen == 0 and battle._q_fail == 1 and battle._q_done == 1)
	assert(battle.bonus_rolls == 0 and battle.bonus_grants == 0)
	assert((battle._toast_lb.text + str(battle._toast_queue)).contains("未中奖"))
	# 镇魂铃+30%与全局文钱收入共同生效，提示用真正中奖到账数。
	battle.wins = true
	battle._gold_pct = 50.0
	battle._wen = 1000
	_offer(battle)
	battle._q_open_popup()
	assert(_labels(battle._q_pop).contains("文钱 520"))
	battle._q_accept()
	assert(battle._wen == 1680 and battle._q_done == 2)
	assert((battle._toast_lb.text + str(battle._toast_queue)).contains("获得 780 文"))
	assert(battle.bonus_rolls == 1 and battle.bonus_grants == 1)
	assert(battle._q_t == 0.0 and battle._q_cur.is_empty())
	# 结果期间不接受、不扣费、不再掷胜负。
	_offer(battle)
	battle._run_over = true
	var roll_count := battle.gamble_rolls
	battle._q_accept()
	assert(battle._wen == 1680 and battle.gamble_rolls == roll_count)
	battle.queue_free()
	await process_frame
	print("PASS: gamble affordability/retry/fee/win/loss/claim once/bell and income bonus/result feedback")
	Audio.quit_cleanly()
