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

const SAVE_PATH := "user://level_state.cfg"

static var current_level := 1
static var max_unlocked := 1
static var first_clear: Dictionary = {}
static var tutorial_done: Dictionary = {}
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

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("levels", "current", current_level)
	cfg.set_value("levels", "max", max_unlocked)
	cfg.set_value("levels", "first_clear", first_clear)
	cfg.set_value("levels", "tutorial_done", tutorial_done)
	cfg.save(SAVE_PATH)

static func config(level: int = -1) -> Dictionary:
	ensure_loaded()
	var lv := current_level if level < 0 else level
	return LEVELS[clampi(lv - 1, 0, LEVELS.size() - 1)] as Dictionary

static func waves(level: int = -1) -> int:
	return int(config(level).get("waves", 5))

static func show_button(kind: String, level: int = -1) -> bool:
	var sh: Dictionary = config(level).get("show", {})
	return bool(sh.get(kind, false))

static func mark_first_clear(level: int = -1) -> bool:
	ensure_loaded()
	var lv := current_level if level < 0 else level
	var key := str(lv)
	if first_clear.has(key):
		return false
	first_clear[key] = true
	max_unlocked = maxi(max_unlocked, mini(lv + 1, LEVELS.size()))
	save()
	return true

static func mark_tutorial(key: String) -> void:
	ensure_loaded()
	if tutorial_done.has(key):
		return
	tutorial_done[key] = true
	save()

static func tutorial_was_done(key: String) -> bool:
	ensure_loaded()
	return tutorial_done.has(key)
