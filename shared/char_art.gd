extends RefCounted
# ============================================================
# 角色美术取图口（立绘 / 头像 / Q版）
#   CharArt.face("player")  → 头像胸像（assets/char/player_face.png）
#   CharArt.full("player")  → 全身立绘（assets/char/player_full.png）
#   CharArt.q("player")     → 战斗 Q版（assets/char/player_q.png）
#   找不到图一律返回 null，调用方自己决定退化方案（绝不因为缺图崩界面）
# 资源由 tools/promote_char_art.mjs 从 assets/gen/char/ 的生成稿提升过来。
# ============================================================

const DIR := "res://assets/char/"
static var _cache := {}

# ⚠ 不要叫 _get：那是 Object 的虚函数（签名不符会直接 Parse Error）
static func _tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var p := DIR + name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(p):
		t = load(p) as Texture2D
	_cache[name] = t
	return t

static func has(role_id: String, slot: String) -> bool:
	if role_id == "":
		return false
	return ResourceLoader.exists(DIR + role_id + "_" + slot + ".png")

static func face(role_id: String) -> Texture2D:
	return _tex(role_id + "_face")

static func full(role_id: String) -> Texture2D:
	return _tex(role_id + "_full")

static func q(role_id: String) -> Texture2D:
	return _tex(role_id + "_q")
