extends RefCounted
# ============================================================
# 场景美术取图口（v67）
#   SceneArt.village()  → 主场景·村景长卷（assets/scenes/village.png）
#   SceneArt.tower()    → 爬塔·山巅古塔
#   SceneArt.inn()      → 酒肆内景
#   SceneArt.buildings()-> 建筑图集（切片前，一般不用）
#   找不到就返回 null——调用方自己决定退化（绝不因为缺图崩界面）
# 资源由 tools/promote_char_art.mjs 从 assets/gen/char/scene_*/ 的生成稿提升过来。
# ============================================================

const DIR := "res://assets/scenes/"
static var _cache := {}

static func _tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var p := DIR + name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(p):
		t = load(p) as Texture2D
	_cache[name] = t
	return t

static func village() -> Texture2D:
	return _tex("village")

static func gate() -> Texture2D:
	return _tex("gate")

static func tower() -> Texture2D:
	return _tex("tower")

static func inn() -> Texture2D:
	return _tex("inn")

static func buildings() -> Texture2D:
	return _tex("buildings")

# 村口记号（kind）→ 建筑图。没有对应图的返回 null，记号照旧只有牌子。
const MARK_ART := {
	"wa": "bld_house",      # 瓦房 → 茅草土屋
	"zhu": "bld_bamboo",    # 竹屋
	"stone": "bld_table",   # 石桌
	"gate": "bld_gate",     # 山门牌坊
	"site": "bld_site",     # 工地
	"brook": "bld_bridge",  # 溪畔小桥
}

static func building(kind: String) -> Texture2D:
	if not MARK_ART.has(kind):
		return null
	return _tex(str(MARK_ART[kind]))

# "点进去"的那张图：点建筑时闪一张内景/场景（约 1 秒）再从面板接上
#   —— 现在有内景图的只有「酒肆/作坊」和「山门」，其余记号仍旧只有 toast。
const ENTER_ART := {
	"craft": "inn", "winery": "inn", "dange": "inn", "jianbao": "inn",
	"shop": "inn", "zhu": "inn", "treasure": "inn", "gate": "gate",
}

static func enter_scene(kind: String) -> Texture2D:
	if not ENTER_ART.has(kind):
		return null
	return _tex(str(ENTER_ART[kind]))
