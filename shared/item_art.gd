extends RefCounted
# ============================================================
# 道具图取图口（v70）
#   来源：一张水墨道具图集（tools/gen_char_art.mjs 的 items_sheet 套）
#        → tools/cutout_art.mjs 抠底 → tools/promote_char_art.mjs 缩到 200px 高
#        → assets/items/it_*.png
#   八件：剑 sword · 刀 blade · 药草 herb · 酒坛 jar ·
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

# v73b：**按卡片 id 取图**（比按名字准得多）。
#   实测：85 个卡片名里，按名字只有 38 个能配上——剩下 27 个全是功法
#   （暴雨梨花/缠丝腿/铁布衫…）而在下名字里根本没有"书/卷/诀"这类字眼，猜不出来。
#   改成走 Cards 的公开接口：is_arts() 判功法、weapon_of() 判兵器类型、by_id().pool 判护具。
const Cards := preload("res://shared/data_cards.gd")

# v93r：**整套转发到 item_icons**（用户："功法书太雷同了""素材太少了"）。
#   这一个是全项目所有"一件东西 → 一张图"的公共口子（行囊/仓库/出征/鉴宝都在用），
#   所以在这里换，各处一起受益：
#     · 功法/武学 → **每一门有自己的图**（art_<id>.png），不再一律是那本蓝皮书；
#     · 兵器/护具 → 按套 id 稳定挑图，青锋剑和霜刃剑不会再撞脸；
#     · 材料 → 七味各有各的图。
const Icons := preload("res://shared/item_icons.gd")

static func icon_for_set(sid: String) -> Texture2D:
	if sid == "":
		return null
	var pool := str(Cards.by_id(sid).get("pool", ""))
	var w := Cards.weapon_of(sid)
	var t := Icons.for_pool(pool, w, sid)
	if t != null:
		return t
	return icon("it_scroll")

# v73：**按卡片名字取图**（行囊/仓库里的格子用）。
#   为什么按名字而不是按 pool：调用方手上只有 card_label(e) 出来的中文名，
#   而名字里必然带"剑/刀/枪/甲/披风/佩"这些字——关键字匹配最省事、也最稳，
#   不依赖 Cards 的内部结构（那套数据结构改过好几轮）。
static func icon_for_name(nm: String) -> Texture2D:
	if nm == "":
		return null
	# 兵器（先长后短：长枪/双刀 要先判，别被"枪/刀"抢先）
	if nm.contains("枪") or nm.contains("棍") or nm.contains("杖"):
		return icon("it_spear")
	if nm.contains("匕首"):
		return icon("it_blade")
	if nm.contains("剑"):
		return icon("it_sword")
	if nm.contains("刀"):
		return icon("it_blade")
	if nm.contains("镖") or nm.contains("暗器"):
		return icon("it_dart")
	# 护具
	if nm.contains("甲") or nm.contains("衣"):
		return icon("it_armor")
	if nm.contains("披风") or nm.contains("氅"):
		return icon("it_cloak")
	if nm.contains("佩") or nm.contains("冠") or nm.contains("玉") or nm.contains("牌"):
		return icon("it_token")
	# 功法 / 秘籍
	if nm.contains("卷") or nm.contains("篇") or nm.contains("诀") or nm.contains("经") or nm.contains("法") or nm.contains("功") or nm.contains("掌") or nm.contains("步"):
		return icon("it_book")
	if nm.contains("谱") or nm.contains("图"):
		return icon("it_scroll")
	# 材料
	if nm.contains("金") or nm.contains("银") or nm.contains("锭"):
		return icon("it_ingot")
	if nm.contains("酒"):
		return icon("it_jar")
	if nm.contains("芝") or nm.contains("参") or nm.contains("果") or nm.contains("草") or nm.contains("米") or nm.contains("骨"):
		return icon("it_herb")
	return null

# 材料键（GameState.material_count 那套）→ 道具图
static func mat_icon(mat: String) -> Texture2D:
	match mat:
		"zhi", "shen", "guo", "rice", "bone", "forge_stone":
			return icon("it_herb")
		"jin":
			return icon("it_ingot")
		"atlas":
			return icon("it_scroll")
		"wine":
			return icon("it_jar")
		_:
			return null
