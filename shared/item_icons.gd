extends RefCounted
# ============================================================
# item_icons.gd —— 道具图标口（v93o）
#   用户："仓库怎么还是字啊" —— 仓库格子原来只有文字。这里给"一件东西 → 一张图"的口径：
#     · 装备按 **pool**（weapon/armor/helm/cloak/arts）挑图；
#     · 材料按材料键（wood/zhi/shen/…）挑图；
#     · 丹药统一用丹盒图。
#   图都在 assets/items/（其中道具那批是 素材/res_mirror 的图集切出来的）。
#   取不到就返回 null，调用方退回"只有字"，不会开天窗。
# ============================================================
const Cards := preload("res://shared/data_cards.gd")
const DIR := "res://assets/items/"
static var _cache := {}

static func _t(nm: String) -> Texture2D:
	if _cache.has(nm):
		return _cache[nm]
	var p := DIR + nm + ".png"
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_cache[nm] = t
	return t

# 装备：按 pool 挑；同一套（sid）永远挑到同一张——用 sid 的哈希定档，
#   这样"青锋剑"和"霜刃剑"不会长得一模一样（用户："素材太少了"）。
static func for_pool(pool: String, weapon := "", sid := "") -> Texture2D:
	var cand: Array = []
	match pool:
		"weapon":
			match weapon:
				"dual":
					cand = ["it_blade", "wpn_blade2", "wpn_blade3"]
				"dagger", "anqi":
					cand = ["it_dart", "wpn_blade2"]
				"spear":
					cand = ["it_spear", "wpn_spear2", "wpn_spear3"]
				_:
					cand = ["it_sword", "it_sword2", "wpn_sword3", "wpn_sword4", "wpn_sword5"]
		"armor":
			cand = ["it_armor", "armor2", "armor3"]
		"helm":
			cand = ["it_token", "helm2", "helm3"]     # 冠 / 佩
		"cloak":
			cand = ["it_cloak", "cloak2", "cloak3"]
		"arts":
			# 武学：**每一门有自己的图**（art_<id>.png，素材图集里挑的彩绘招式图）
			if sid != "":
				var at := _t(sid)
				if at != null:
					return at
			cand = ["it_book", "it_scroll"]
	return _pick(cand, sid)

# 按 sid 稳定地取候选里的一张
static func _pick(cand: Array, sid: String) -> Texture2D:
	if cand.is_empty():
		return null
	var h := 0
	for i in sid.length():
		h = (h * 31 + sid.unicode_at(i)) % 100000
	var t := _t(str(cand[h % cand.size()]))
	if t == null:
		t = _t(str(cand[0]))
	return t

# ---- 品级色（凡白 / 良绿 / 上紫 / 极金 / 绝红，跟全项目一个口径）----
const QUALITY_COL := [
	Color(0.86, 0.85, 0.82),   # 凡品
	Color(0.36, 0.70, 0.42),   # 良品
	Color(0.55, 0.42, 0.78),   # 上品
	Color(0.85, 0.66, 0.22),   # 极品
	Color(0.80, 0.28, 0.24),   # 绝品
]

static func quality_col(q_idx: int) -> Color:
	return QUALITY_COL[clampi(q_idx, 0, QUALITY_COL.size() - 1)]

# 一件东西的品级色（拿不到就返回"凡品"那档）
static func quality_col_of(sid: String) -> Color:
	if sid == "":
		return QUALITY_COL[0]
	return quality_col(Cards.q_idx(sid))

# 材料：**各有各的图**（原来除了金髓，其余全挤在药草那一张上）
static func for_mat(k: String) -> Texture2D:
	match k:
		"zhi":
			return _t("mat_zhi")
		"shen":
			return _t("mat_shen")
		"guo":
			return _t("mat_guo")
		"bone", "forge_stone":
			return _t("mat_bone")
		"rice":
			return _t("mat_rice")
		"jin", "daoguo", "xinghui":
			return _t("mat_jin")
		"pojing":
			return _t("mat_zhi")
		"xuantie", "hundun", "soul":
			return _t("mat_bone")
		"lingguo":
			return _t("mat_rice")
		"common", "jianpei", "iron_sand":
			return _t("it_ingot")
		"bone_coal":
			return _t("mat_bone")
		"forge_oil":
			return _t("it_jar")
		"fine_iron", "meteor_iron", "cold_iron":
			return _t("mat_jin")
		"star_iron":
			return _t("it_token")
		"atlas":
			return _t("it_scroll")
	return _t("it_herb")

# 锻炉道具：TOOLS 里直接写素材图标名
static func for_tool(icon_name: String) -> Texture2D:
	return _t(icon_name)

# 丹药 / 消耗
static func for_pill() -> Texture2D:
	return _t("it_jar")

# 兜底（残页/残卡/信物一类）
static func fallback() -> Texture2D:
	return _t("it_scroll")
