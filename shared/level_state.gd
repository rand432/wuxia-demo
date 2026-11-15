class_name LevelState
extends RefCounted

# 十关教学关配置。波数、按钮显隐、后续卡池/掉落/教学都从这里取。
const LEVELS := [
	{"waves": 5,  "name": "第一关 · 教学",
		"show": {"strengthen": true, "curio": true}},
	{"waves": 10, "name": "第二关",
		"show": {"strengthen": true, "curio": true, "draw": true, "crystal": true}},
	{"waves": 15, "name": "第三关",
		"show": {"strengthen": true, "curio": true, "draw": true, "crystal": true, "treasure": true}},
	{"waves": 20, "name": "第四关",
		"show": {"strengthen": true, "curio": true, "draw": true, "crystal": true, "treasure": true, "challenge": true}},
	{"waves": 25, "name": "第五关",
		"show": {"strengthen": true, "curio": true, "draw": true, "crystal": true, "treasure": true, "challenge": true, "mate": true}},
	{"waves": 30, "name": "第六关",
		"show": {"strengthen": true, "curio": true, "draw": true, "crystal": true, "treasure": true, "challenge": true, "mate": true, "market": true}},
	{"waves": 35, "name": "第七关",
		"show": {"strengthen": true, "curio": true, "draw": true, "crystal": true, "treasure": true, "challenge": true, "mate": true, "market": true}},
	{"waves": 35, "name": "第八关",
		"show": {"strengthen": true, "curio": true, "draw": true, "crystal": true, "treasure": true, "challenge": true, "mate": true, "market": true}},
	{"waves": 35, "name": "第九关",
		"show": {"strengthen": true, "curio": true, "draw": true, "crystal": true, "treasure": true, "challenge": true, "mate": true, "market": true}},
	{"waves": 35, "name": "第十关",
		"show": {"strengthen": true, "curio": true, "draw": true, "crystal": true, "treasure": true, "challenge": true, "mate": true, "market": true}},
]

# ============================================================
# 十关新功能解锁表 —— **唯一事实来源**
#   与 docs/困兽_十关教学关_设计原则.md 的「痛点 → 操作」表逐条对应。
#   任何系统要判断"这个功能现在开没开"，都必须走 has_feature()，
#   不要再在别处写 current_level >= N 的零散判断。
# ============================================================
const FEATURE_LEVEL := {
	# 第 1 关：强化 / 进阶 / 玉壶
	"strengthen": 1, "advance": 1, "curio": 1,
	# 第 2 关：抽卡 / 成长线
	"draw": 2, "growth": 2, "crystal": 2,
	# 第 3 关：宝物 / 经济线
	"treasure": 3, "economy": 3,
	# 第 4 关：奇遇 / 挑战 / 危途
	"encounter": 4, "challenge": 4, "peril": 4,
	# 第 5 关：请神 / 家传卡
	"god": 5, "ancestor": 5, "mate": 5,
	# 第 6 关：黑市 / 高级卡
	"market": 6, "advanced": 6,
	# 第 7 关：特级 / 装备材料
	"special": 7,
	# 第 8 关：装备 / 锻造
	"equip": 8, "forge": 8,
	# 第 9 关：角色进阶
	"role_advance": 9,
	# 第 10 关：新奇物 / 新卡组
	"new_curio": 10, "new_cards": 10,
}

static func has_feature(kind: String, level: int = -1) -> bool:
	var lv2 := current_level if level < 0 else level
	return lv2 >= int(FEATURE_LEVEL.get(kind, 1))

# 10 系分线：成长 4 / 经济 4 / 危途 2（挑战 peril 已从经济线移过来）
const LINE_GROWTH := ["atk", "def", "hp", "mp"]
const LINE_ECON := ["gold", "crystal", "exp", "bounty"]
const LINE_DANGER := ["swarm", "peril"]

# 首通掉落（7/8/9/10 关）；实际系统未做的先留字段，文案照设计
const FIRST_REWARDS := {
	1: {"preview": {"crystal": 60}, "text": "下一关抽卡：灵晶 +60"},
	2: {"preview": {"wen": 200}, "text": "下一关经济：文钱 +200"},
	3: {"preview": {"chal": 1}, "text": "下一关挑战：次数 +1"},
	4: {"preview": {"exp_pct": 20}, "text": "下一关经验：经验获取 +20%"},
	5: {"preview": {"forge": 20}, "text": "下一关黑市：锻造石 +20"},
	6: {"wen": 300, "skill_book": "玄品", "skill_book_n": 2, "text": "文钱 +300 · 玄品技能书 ×2"},
	7: {"wen": 1000, "equip": 4, "forge_mat": 100, "text": "四件凡品装备 + 文钱 +1000 · 锻造石 ×100"},
	8: {"wen": 1500, "shards": {"zhujue": 30}, "text": "主角角色碎片 +30 · 文钱 +1500"},
	9: {"wen": 1000, "curio_shards": 30, "text": "奇物碎片 +30 · 文钱 +1000"},
	10: {"wen": 300, "new_cards": 1, "text": "新卡组解锁"},
}

# 请神六位：L5 开 2 位，之后每关 +1，L9 满 6；顺序按设计固定
# 六格请神：只放未封印的六位；最强的张道陵/崔三娘/季沧海封印中，不在这条顺序里
const GOD_ORDER := ["chenshi", "liuqingqing", "qingluan", "xiaoqier", "gundilong", "mingzhu"]

const SAVE_VERSION := 2
const SAVE_PATH := "user://level_state.cfg"

static var current_level := 1
static var max_unlocked := 1
static var first_clear: Dictionary = {}
static var tutorial_done: Dictionary = {}
# 首通后给下一关的“预习”开局加成：{lv, crystal/wen/chal/god/forge}
static var preview: Dictionary = {}
static var _loaded := false

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	current_level = clampi(int(cfg.get_value("levels", "current", 1)), 1, LEVELS.size())
	max_unlocked = clampi(int(cfg.get_value("levels", "max", 1)), 1, LEVELS.size())
	first_clear = cfg.get_value("levels", "first_clear", {}) as Dictionary
	tutorial_done = cfg.get_value("levels", "tutorial_done", {}) as Dictionary
	preview = cfg.get_value("levels", "preview", {}) as Dictionary
	# v2：旧存档里的教学 done 是调参/探针写进去的，清掉，保证玩家能看到强制教学
	if int(cfg.get_value("levels", "version", 1)) < SAVE_VERSION:
		tutorial_done = {}

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("levels", "version", SAVE_VERSION)
	cfg.set_value("levels", "current", current_level)
	cfg.set_value("levels", "max", max_unlocked)
	cfg.set_value("levels", "first_clear", first_clear)
	cfg.set_value("levels", "tutorial_done", tutorial_done)
	cfg.set_value("levels", "preview", preview)
	cfg.save(SAVE_PATH)

static func config(level: int = -1) -> Dictionary:
	ensure_loaded()
	var lv := current_level if level < 0 else level
	return LEVELS[clampi(lv - 1, 0, LEVELS.size() - 1)] as Dictionary

static func waves(level: int = -1) -> int:
	return int(config(level).get("waves", 5))

# 十关循环用现有 16 只 Boss 的 4 阶：1-3 关一阶，4-6 二阶，7-9 三阶，10 四阶
static func tutorial_l1_done() -> bool:
	return tutorial_was_done("l1_wen") and tutorial_was_done("l1_attr") and tutorial_was_done("l1_aug") and tutorial_was_done("l1_yuhu")

static func god_count(level: int = -1) -> int:
	var lv := current_level if level < 0 else level
	if lv < 5:
		return 0
	return mini(6, 2 + (lv - 5))

static func god_ids(level: int = -1) -> Array:
	return GOD_ORDER.slice(0, god_count(level))

static func boss_tier(level: int = -1) -> int:
	var lv := current_level if level < 0 else level
	# 按设计稿：1-3 关一阶，4-6 二阶，7-9 三阶，10 四阶
	if lv <= 3:
		return 1
	if lv <= 6:
		return 2
	if lv <= 9:
		return 3
	return 4

static func show_button(kind: String, level: int = -1) -> bool:
	# 已知功能一律走解锁表（避免 LEVELS.show 与各处零散判断打架）
	if FEATURE_LEVEL.has(kind):
		return has_feature(kind, level)
	var sh: Dictionary = config(level).get("show", {})
	return bool(sh.get(kind, false))

# 卡池门控：id = key_tier_idx
# L1 无卡；L2 成长初/中；L3 +经济初/中；L4 +危途；L5 家传不走抽卡；
# L6 全系高级；L7 全系特级
static func card_allowed(id: String, level: int = -1) -> bool:
	var lv := current_level if level < 0 else level
	if lv <= 1:
		return false
	var parts := id.split("_")
	if parts.size() < 2:
		return false
	var key := str(parts[0])
	var tier := int(parts[1])
	if key in LINE_GROWTH:
		pass
	elif key in LINE_ECON:
		if lv < 3:
			return false
		# 第三关经济线只先给灵晶/文钱；杀敌数/直接奖励留到第四关
		if lv == 3 and key in ["exp", "bounty"]:
			return false
	elif key in LINE_DANGER:
		if lv < 4:
			return false
	else:
		return false
	if lv <= 5:
		return tier <= 1
	if lv == 6:
		return tier <= 2
	return tier <= 3

static func first_reward(level: int = -1) -> Dictionary:
	var lv := current_level if level < 0 else level
	return FIRST_REWARDS.get(lv, {}) as Dictionary

static func mark_first_clear(level: int = -1) -> bool:
	ensure_loaded()
	var lv := current_level if level < 0 else level
	var key := str(lv)
	if first_clear.has(key):
		return false
	first_clear[key] = true
	max_unlocked = maxi(max_unlocked, mini(lv + 1, LEVELS.size()))
	var r := first_reward(lv)
	if r.has("preview"):
		preview = (r["preview"] as Dictionary).duplicate()
		preview["lv"] = mini(lv + 1, LEVELS.size())
	save()
	return true

# 进入某关时取走属于它的“预习”加成，只生效一次
static func take_preview(level: int) -> Dictionary:
	if preview.is_empty() or int(preview.get("lv", 0)) != level:
		return {}
	var p: Dictionary = preview.duplicate()
	preview = {}
	save()
	return p

static func mark_tutorial(key: String) -> void:
	ensure_loaded()
	if tutorial_done.has(key):
		return
	tutorial_done[key] = true
	save()

static func tutorial_was_done(key: String) -> bool:
	ensure_loaded()
	return tutorial_done.has(key)
