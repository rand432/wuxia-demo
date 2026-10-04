extends RefCounted
# ============================================================
# 演员工厂 v1：战斗里用「火柴人」还是「Q版纸片人」，只在这一处决定
#
#   ActorFactory.make(角色id)   → 我方（有 Q版美术就用 Q版，没有自动退回火柴人）
#   ActorFactory.make_enemy()   → 敌方（杂兵 Q版美术还没出，先火柴人；出了自动切）
#
# 为什么不是"改 StickFighter"：火柴人那套是九关节骨骼画法 + 一百多处调过的弹簧历史，
#   动它风险太大；Q版是另一条表现路子（纸片人），只在**建节点那一行**换类，
#   战斗逻辑（出手/挨打/位移/结算）一行都不用改——两边公开接口完全一致。
#
# 关掉 Q版（回到纯火柴人）：ActorFactory.use_q_art = false
# ============================================================

const StickFighter := preload("res://journey/stick_fighter.gd")
const QActor := preload("res://journey/q_actor.gd")

const Q_ART_DIR := "res://assets/char/"   # 正式资源（tools/promote_char_art.mjs 提升过来的）
const Q_ART_SUFFIX := "_q.png"

static var use_q_art := true

static func has_q_art(role_id: String) -> bool:
	if role_id == "":
		return false
	return ResourceLoader.exists(Q_ART_DIR + role_id + Q_ART_SUFFIX)

# 我方：有图用 Q版
static func make(role_id: String = "") -> Node2D:
	if use_q_art and has_q_art(role_id):
		var a = QActor.new()
		a.set_role(role_id)
		return a
	return StickFighter.new()

# ---------------- 敌人名字 → Q版美术键（临时占位用） ----------------
# 杂兵名会随章节换（落草/流寇/黑风/翻江/袖箭/残党/断魂/铁旗/血鹰/天王 共 50 个），
# 但"是不是头目、拿什么兵器"这两条规律不变——所以按**关键字**归原型，比写 50 行表耐改。
# 目前只有 mob_lou / mob_dog 两张试片（且 liblib 出的不是 Q版，见 assets/gen/char/mob_*），
# 所以现在仍然会自动退回火柴人；等 Q版 敌人图进了 assets/char/，这里一行都不用改就会切过去。
const ENEMY_RULES := [
	{"kw": ["独臂", "独眼"], "key": "mob_one_arm"},
	{"kw": ["舵主", "寨主", "堡主", "门主", "谷主", "崖主", "龙王", "魁首", "首领", "头目", "堂主", "副寨主", "死士", "悍将", "护法", "桩主", "精锐"], "key": "mob_chief"},
	{"kw": ["犬", "狗", "狼", "兽"], "key": "mob_dog"},
	{"kw": ["弩", "箭", "针", "镖"], "key": "mob_bow"},
	{"kw": ["枪", "矛", "戟"], "key": "mob_spear"},
	{"kw": ["钩"], "key": "mob_hook"},
	{"kw": ["旗"], "key": "mob_flag"},
	{"kw": ["刀", "刃"], "key": "mob_blade"},
	{"kw": ["喽啰", "毛贼", "斥候", "门徒", "卒", "快手", "水鬼", "游骑", "暗手", "暗哨", "鬼影"], "key": "mob_lou"},
]

static func enemy_key(nm: String) -> String:
	for row in ENEMY_RULES:
		for k in (row["kw"] as Array):
			if nm.find(str(k)) >= 0:
				return str(row["key"])
	return "mob_lou"

# 敌方：暂时没有杂兵 Q版美术（出了自动切）
static func make_enemy(role_id: String = "") -> Node2D:
	if use_q_art and has_q_art(role_id):
		var a = QActor.new()
		a.set_role(role_id)
		return a
	return StickFighter.new()
