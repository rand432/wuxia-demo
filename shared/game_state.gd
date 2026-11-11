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
static var curio_id := "yuhu"   # 默认带玉壶（原来每局必有的那件）
static var curio_lv := {}
static var _curio_loaded := false
const CURIO_SAVE := "user://curio.cfg"

static func _curio_ensure() -> void:
	if _curio_loaded:
		return
	_curio_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(CURIO_SAVE) != OK:
		return
	curio_id = str(cfg.get_value("curio", "id", curio_id))
	var d = cfg.get_value("curio", "lv", {})
	if d is Dictionary:
		curio_lv = (d as Dictionary).duplicate()

static func _curio_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("curio", "id", curio_id)
	cfg.set_value("curio", "lv", curio_lv)
	cfg.save(CURIO_SAVE)

static func curio_level(id: String) -> int:
	_curio_ensure()
	return clampi(int(curio_lv.get(id, 1)), 1, 5)

static func curio_equip(id: String) -> void:
	_curio_ensure()
	curio_id = id
	_curio_save()

static func curio_unequip() -> void:
	_curio_ensure()
	curio_id = ""
	_curio_save()

static func curio_upgrade(id: String) -> bool:
	var lv := curio_level(id)
	if lv >= 5:
		return false
	curio_lv[id] = lv + 1
	_curio_save()
	return true
