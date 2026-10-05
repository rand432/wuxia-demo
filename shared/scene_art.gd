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

# v90：素材里的**酒坛 / 酒桌**（品酒坊用；pic_jiutan / pic_table 抠底后入库）
static func wine_jar() -> Texture2D:
	return _tex("props/wine_jar_cut")

static func wine_table() -> Texture2D:
	return _tex("props/wine_table_cut")

# v79：素材 UI 图集里切出来的**书法字**（升级 / 狭路相逢 / 任务完成 / 强敌来袭 / VS）
const UI_TXT := {
	"levelup": "txt_levelup",
	"meet": "txt_meet",
	"done": "txt_done",
	"strongfoe": "txt_strongfoe",
	"vs": "txt_vs",
}

static var _txt_cache := {}

static func ui_txt(key: String) -> Texture2D:
	if not UI_TXT.has(key):
		return null
	if _txt_cache.has(key):
		return _txt_cache[key]
	var p := "res://assets/ui/mat/" + str(UI_TXT[key]) + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(p):
		t = load(p) as Texture2D
	_txt_cache[key] = t
	return t

# v92：**村景小物件**（松/桃/栅栏/石桌/草堆/山石）——智谱水墨稿，抠好落在 assets/scenes/props/
#   一次提升一批，见 tools/promote_char_art.mjs 的 PROPS。找不到返回 null，调用方退回程序画法。
static var _prop_cache := {}

static func prop(name: String) -> Texture2D:
	if _prop_cache.has(name):
		return _prop_cache[name]
	var p := "res://assets/scenes/props/" + name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(p):
		t = load(p) as Texture2D
	_prop_cache[name] = t
	return t

# v79：素材里的**刀光序列帧**（红/黑白两套，各 16 帧）
static var _slash2_cache := {}

static func slash_frames2(set_name := "red") -> Array:
	# v92：同 mat()——_draw 里现 load() 出来的贴图会变白块，这里也缓存一份
	if _slash2_cache.has(set_name):
		return _slash2_cache[set_name]
	var out: Array = []
	var pre := "slash_red_" if set_name == "red" else "slash_bw_"
	for i in 16:
		var p := "res://assets/ui/mat/" + pre + ("%02d" % i) + ".png"
		if ResourceLoader.exists(p):
			out.append(load(p))
	_slash2_cache[set_name] = out
	return out

# v79：村庄**废墟态**的房子图（智谱出的正侧视水墨断墙茅顶）
static func ruin() -> Texture2D:
	return _tex("house_ruin")

static func buildings() -> Texture2D:
	return _tex("buildings")

# v77：各作坊/货仓/宝箱的**内景图**（用户：「品酒坊/炼丹/货仓 是不是也要换图了」）
static func alchemy_room() -> Texture2D:
	return _tex("room_alchemy")

static func store_room() -> Texture2D:
	return _tex("room_store")

# v90：宝箱**开/关两张真图**（智谱出的水墨木箱 + 原来那张装满银锭的）
static func chest_closed() -> Texture2D:
	return _tex("chest_closed")

static func chest_open() -> Texture2D:
	return _tex("chest_open")

static func chest_art() -> Texture2D:
	return _tex("chest_open")

# v78：**素材里那两张水墨城郭**（影之刃 Atlas_MainMap 切出来的）——
#   用户指着图问"这个不适合做游历旅途的更换场景？"——适合，而且跟本作是一套语言。
#   月夜那幅给游历当远景，血月那幅给爬塔/战斗。
# v91（用户："画卷也要变一变啊 不是有素材吗"）：**素材背景通用口**——
#   assets/scenes/mat/ 下那 22 幅（切自影之刃的水墨图集）按名字取，换图只改调用处的名字。
# v92 修（**全工程级的白块病根**）：这里原来是每次调用都 load() 一遍。
#   在 _draw() 里现 load() 的贴图，Godot 这一版会画成**一块纯白**（同帧里别的、已经
#   缓存过的贴图却正常）——所以"素材取得到、代码也在跑，画面就是白的/看不见"
#   （远景平铺、宠物 Q版都栽在这上面）。改成跟 _tex() 一样走静态缓存就好了。
static var _mat_cache := {}

static func mat(name: String) -> Texture2D:
	if _mat_cache.has(name):
		return _mat_cache[name]
	var p := "res://assets/scenes/mat/" + name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(p):
		t = load(p) as Texture2D
	_mat_cache[name] = t
	return t

static func map_night() -> Texture2D:
	return _tex("map_night")

static func map_redmoon() -> Texture2D:
	return _tex("map_redmoon")

# v78：**素材里的刀光序列帧**（Atlas_hun_daoguang2 切成 25 帧）——技能特效直接用
static var _slash_cache: Array = []

static func slash_frames() -> Array:
	# v92：同 mat()——缓存（_draw 里现 load 会白块）
	if not _slash_cache.is_empty():
		return _slash_cache
	for i in 25:
		var p := "res://assets/scenes/slash/slash_" + ("%02d" % i) + ".png"   # GDScript 没有 zfill
		if ResourceLoader.exists(p):
			_slash_cache.append(load(p))
	return _slash_cache

# v75：村里的房子图（用户：「我是想让村里房子也换成图」）。
#   6 张：茅草土屋 / 竹屋 / 砖石瓦房 / 木构货栈 / 两层藏宝楼 / 牌坊山门。
#   Build.HOUSES 有 8 座，按序号取模轮着用；缺图返回 null，调用方退化回手画。
const HOUSE_N := 6
static func house(i: int) -> Texture2D:
	return _tex("house_" + str(posmod(i, HOUSE_N) + 1))

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
