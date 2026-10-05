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

# Q版裁头（临时头像位）：立绘/头像那套先不用了，头像位先用 Q版头部顶着
static func q_head(role_id: String) -> Texture2D:
	return _tex(role_id + "_qhead")

# 立绘演出片（.ogv，Godot 原生格式）；没有就返回 null
const CLIP_DIR := "res://assets/clips/"
# v79：宠物图（智谱出的 Q版 白狐 / 青隼）——没有图返回 null，pet_actor 自己退回手画
# v92 修：走 _tex() 的静态缓存——**在 _draw() 里现 load() 的贴图会渲染成白块**
#   （宠物路上/面板里那个"白方块"就是这么来的，跟 draw_set_transform 无关）。
static func pet(kind: String) -> Texture2D:
	return _tex("pet_falcon" if kind == "hawk" else "pet_fox")

static func clip(role_id: String) -> VideoStream:
	var p := CLIP_DIR + role_id + "_clip.ogv"
	if not ResourceLoader.exists(p):
		return null
	return load(p) as VideoStream
