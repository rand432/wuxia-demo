extends RefCounted
# ============================================================
# data_icons.gd —— 武学 / 命数 的图标口（v93l）
#   图都是 tools/slice_atlas.mjs 从 素材/res_mirror 的两套图集里切出来的：
#     · 武学 ← icon_skill  （288 张，彩绘招式图）→ assets/items/art_<卡片id>.png
#     · 命数 ← icon_buff   （987 张，字牌）      → assets/items/fate_<命数id>.png
#   命名跟 id 一一对应，所以这里不需要写一大张表，取不到就返回 null（调用方照旧只有字）。
# ============================================================
const DIR := "res://assets/items/"

static var _cache := {}

static func _tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = t
	return t

# 武学：卡片 id（art_wind / art_breath …）→ 图标；"art_ult" 是大招那一格
static func art(id: String) -> Texture2D:
	if id == "":
		return null
	return _tex(DIR + id + ".png")

# 命数：命数 id（greed / bloodpath …）→ 字牌图标
static func fate(id: String) -> Texture2D:
	if id == "":
		return null
	return _tex(DIR + "fate_" + id + ".png")
