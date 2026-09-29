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

# 敌方：暂时没有杂兵 Q版美术（出了自动切）
static func make_enemy(role_id: String = "") -> Node2D:
	if use_q_art and has_q_art(role_id):
		var a = QActor.new()
		a.set_role(role_id)
		return a
	return StickFighter.new()
