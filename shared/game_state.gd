extends Node

const SaveFile := preload("res://shared/save_file.gd")
# 新流程最小状态：只保留货币/名号，不再加载旧卡池/装备/伙伴数据

static var player_name := "少侠"
static var coins := {"wen": 0, "silver": 0, "yuanbao": 0}
# 十关首通掉落占位（实际系统后续接）
static var skill_mat := 0
static var forge_mat := 0
static var equip_tokens := 0
static var advance_tokens := 0
static var new_cards_unlocked := false
static var new_curio_unlocked := false
# 技能升级（局外·请神界面消耗）：aid -> 等级
static var skill_lv := {}
# 技能书按品级：凡/良/玄/地/天；升级消耗对应品级技能书 + 文钱
static var skill_books := {"凡品": 0, "良品": 0, "玄品": 0, "地品": 0, "天品": 0}
# 角色碎片（局外进阶）：初始主角 60；aid -> 碎片数
static var shards := {"zhujue": 60}
# 奇物合成碎片：第十关首通给；局外奇物页消耗碎片 + 文钱合成
static var curio_shards := 0
static var stars := {}

static func coin(k: String) -> int:
	ensure_loaded()
	return int(coins.get(k, 0))

static func add_coin(k: String, n: int) -> void:
	ensure_loaded()
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
	if SaveFile.read(cfg, CURIO_SAVE, {"curio": {"lv": TYPE_DICTIONARY}}) != OK:
		return
	curio_id = str(cfg.get_value("curio", "id", curio_id))
	var d = cfg.get_value("curio", "lv", {})
	if d is Dictionary:
		curio_lv = (d as Dictionary).duplicate()

static func _curio_save() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("curio", "id", curio_id)
	cfg.set_value("curio", "lv", curio_lv)
	return SaveFile.write(cfg, CURIO_SAVE)

static func curio_level(id: String) -> int:
	_curio_ensure()
	return clampi(int(curio_lv.get(id, 1)), 1, 5)

static func curio_equip(id: String) -> bool:
	_curio_ensure()
	var CurioData := preload("res://shared/curio_data.gd")
	if CurioData.get_curio(id).is_empty():
		return false
	var previous := curio_id
	curio_id = id
	if _curio_save() == OK:
		return true
	curio_id = previous
	return false

static func curio_unequip() -> bool:
	_curio_ensure()
	var previous := curio_id
	curio_id = ""
	if _curio_save() == OK:
		return true
	curio_id = previous
	return false

static func curio_upgrade(id: String) -> bool:
	var CurioData := preload("res://shared/curio_data.gd")
	if CurioData.get_curio(id).is_empty():
		return false
	var lv := curio_level(id)
	if lv >= 5:
		return false
	var had_level := curio_lv.has(id)
	curio_lv[id] = lv + 1
	if _curio_save() == OK:
		return true
	if had_level:
		curio_lv[id] = lv
	else:
		curio_lv.erase(id)
	return false

# 当前接入的局外成长数据；与旧玩法存档分开保存。
const PROGRESS_SAVE := "user://progress.cfg"
const PROGRESS_KEYS := ["player_name", "coins", "skill_mat", "forge_mat", "equip_tokens", "advance_tokens", "new_cards_unlocked", "new_curio_unlocked", "skill_lv", "skill_books", "shards", "curio_shards", "stars"]
static var _progress_loaded := false

static func ensure_loaded() -> void:
	if _progress_loaded:
		return
	if SaveFile.recover() != OK:
		push_error("未完成的首通奖励恢复失败，保留恢复记录")
		return
	_progress_loaded = true
	_curio_ensure()
	var cfg := ConfigFile.new()
	if SaveFile.read(cfg, PROGRESS_SAVE, {"progress": {"coins": TYPE_DICTIONARY, "skill_lv": TYPE_DICTIONARY, "skill_books": TYPE_DICTIONARY, "shards": TYPE_DICTIONARY, "stars": TYPE_DICTIONARY}}) != OK:
		return
	player_name = str(cfg.get_value("progress", "player_name", player_name))
	for key in ["coins", "skill_lv", "skill_books", "shards", "stars"]:
		var value = cfg.get_value("progress", key, null)
		if value is Dictionary:
			match key:
				"coins": coins.merge(value, true)
				"skill_lv": skill_lv = value.duplicate(true)
				"skill_books": skill_books.merge(value, true)
				"shards": shards = value.duplicate(true)
				"stars": stars = value.duplicate(true)
	skill_mat = int(cfg.get_value("progress", "skill_mat", skill_mat))
	forge_mat = int(cfg.get_value("progress", "forge_mat", forge_mat))
	equip_tokens = int(cfg.get_value("progress", "equip_tokens", equip_tokens))
	advance_tokens = int(cfg.get_value("progress", "advance_tokens", advance_tokens))
	curio_shards = int(cfg.get_value("progress", "curio_shards", curio_shards))
	new_cards_unlocked = bool(cfg.get_value("progress", "new_cards_unlocked", new_cards_unlocked))
	new_curio_unlocked = bool(cfg.get_value("progress", "new_curio_unlocked", new_curio_unlocked))

static func save_progress() -> Error:
	ensure_loaded()
	var cfg := ConfigFile.new()
	var values := [player_name, coins, skill_mat, forge_mat, equip_tokens, advance_tokens, new_cards_unlocked, new_curio_unlocked, skill_lv, skill_books, shards, curio_shards, stars]
	for i in PROGRESS_KEYS.size():
		cfg.set_value("progress", PROGRESS_KEYS[i], values[i])
	var err := SaveFile.write(cfg, PROGRESS_SAVE)
	if err != OK:
		push_error("局外进度保存失败：%s" % error_string(err))
	return err

const ROLE_STAR_MAX := 5
const ROLE_ADVANCE_SHARDS := 60
const ROLE_ADVANCE_WEN := 500

static func can_advance_role(aid: String, initial_star: int = 0) -> bool:
	ensure_loaded()
	return int(stars.get(aid, initial_star)) < ROLE_STAR_MAX and int(shards.get(aid, 0)) >= ROLE_ADVANCE_SHARDS and coin("wen") >= ROLE_ADVANCE_WEN

static func advance_role(aid: String, initial_star: int = 0) -> bool:
	if not can_advance_role(aid, initial_star):
		return false
	var had_star := stars.has(aid)
	var previous_star := int(stars.get(aid, initial_star))
	var previous_shards := int(shards.get(aid, 0))
	var previous_wen := coin("wen")
	shards[aid] = previous_shards - ROLE_ADVANCE_SHARDS
	coins["wen"] = previous_wen - ROLE_ADVANCE_WEN
	stars[aid] = previous_star + 1
	if save_progress() == OK:
		return true
	# 保存失败时恢复全部扣费，允许玩家重试。
	shards[aid] = previous_shards
	coins["wen"] = previous_wen
	if had_star:
		stars[aid] = previous_star
	else:
		stars.erase(aid)
	return false

static func upgrade_skill(aid: String, quality: String, cost_wen: int = 200) -> bool:
	ensure_loaded()
	var books := int(skill_books.get(quality, 0))
	var wen := coin("wen")
	if cost_wen < 0 or books < 1 or wen < cost_wen:
		return false
	var had_level := skill_lv.has(aid)
	var previous_level := int(skill_lv.get(aid, 0))
	skill_books[quality] = books - 1
	coins["wen"] = wen - cost_wen
	skill_lv[aid] = previous_level + 1
	if save_progress() == OK:
		return true
	skill_books[quality] = books
	coins["wen"] = wen
	if had_level:
		skill_lv[aid] = previous_level
	else:
		skill_lv.erase(aid)
	return false

# 六档家传：0 星可收集初档，每升一星解锁下一档。
static func family_tier_allowed(aid: String, tier: int) -> bool:
	ensure_loaded()
	return tier >= 0 and tier <= clampi(int(stars.get(aid, 0)), 0, ROLE_STAR_MAX)
