extends Node
# 新流程最小状态：只保留货币/名号，不再加载旧卡池/装备/伙伴数据

static var player_name := "少侠"
static var coins := {"wen": 0, "silver": 0, "yuanbao": 0}

static func coin(k: String) -> int:
	return int(coins.get(k, 0))

static func add_coin(k: String, n: int) -> void:
	coins[k] = int(coins.get(k, 0)) + n

static func role_data(_rid: String) -> Dictionary:
	return {"name": player_name if player_name != "" else "少侠", "grade": "玄品"}

static func role_grade_cn(_rid: String) -> String:
	return "玄品"

# ---------------- 奇物（局外） ----------------
# 单槽：curio_id 为空 = 不带；curio_lv 是每件的强化等级（默认 1）
static var curio_id := ""
static var curio_lv := {}

static func curio_level(id: String) -> int:
	return clampi(int(curio_lv.get(id, 1)), 1, 5)

static func curio_equip(id: String) -> void:
	curio_id = id

static func curio_unequip() -> void:
	curio_id = ""

static func curio_upgrade(id: String) -> bool:
	var lv := curio_level(id)
	if lv >= 5:
		return false
	curio_lv[id] = lv + 1
	return true
