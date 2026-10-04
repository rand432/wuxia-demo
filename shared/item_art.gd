extends RefCounted
# ============================================================
# 道具图取图口（v70）
#   来源：一张水墨道具图集（tools/gen_char_art.mjs 的 items_sheet 套）
#        → tools/cutout_art.mjs 抠底 → tools/promote_char_art.mjs 缩到 200px 高
#        → assets/items/it_*.png
#   九件：剑 sword · 刀 blade · 药草 herb · 酒坛 jar · 木料 wood ·
#        卷轴 scroll · 银锭 ingot · 令牌 token · 秘籍 book
#   找不到就返回 null——调用方要退化得掉（绝不因为缺图崩界面）
# ============================================================

const DIR := "res://assets/items/"
static var _cache := {}

static func icon(key: String) -> Texture2D:
	if key == "":
		return null
	if _cache.has(key):
		return _cache[key]
	var p := DIR + key + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(p):
		t = load(p) as Texture2D
	_cache[key] = t
	return t

# 材料键（GameState.material_count 那套）→ 道具图
static func mat_icon(mat: String) -> Texture2D:
	match mat:
		"wood":
			return icon("it_wood")
		"zhi", "shen", "guo", "rice", "bone":
			return icon("it_herb")
		"jin":
			return icon("it_ingot")
		"wine":
			return icon("it_jar")
		_:
			return null
