extends RefCounted
# ============================================================
# shared/char_sheet.gd —— 角色页的属性快照
#
#   作用：把「装备合计（FD.totals）＋ 基础常量」组装成一份
#   attr_panel（详细属性页）能直接读的东西，让角色页点一下属性
#   就能看到同一套面板，不用为了看一眼数值去开一局。
#
#   接口刻意和 kushou/kushou_battle.gd 的属性层保持一致：
#     hero / _attr_sync_from_hero() / type_field()
#   —— 战斗核心那边接上同一份数据之后，这个文件就可以退休。
# ============================================================

const FD := preload("res://shared/forge_data.gd")

const ATK_BASE := 12.0        # 与 kushou_battle.gd 的 ATTR_BASE 对齐
const HP_BASE := 200.0
const MP_BASE := 100.0
const ATK_SEC := 1.8          # 攻速基础：1.8 秒/刀

var hero := {
	"atk": ATK_BASE, "hp": HP_BASE, "hp_max": HP_BASE,
	"mp": MP_BASE, "mp_max": MP_BASE,
	"aspd": 1.0, "crit": 0.05, "crit_dmg": 2.0,
}

func _init() -> void:
	refresh()

# 从装备合计重新算一遍（穿脱装备后调一次即可）
func refresh() -> void:
	var t: Dictionary = FD.totals()
	hero["atk"] = ATK_BASE + float(t["atk"])
	hero["hp_max"] = HP_BASE + float(t["hp"])
	hero["hp"] = hero["hp_max"]
	hero["mp_max"] = MP_BASE
	hero["mp"] = MP_BASE
	hero["aspd"] = 1.0
	hero["crit"] = 0.05
	hero["crit_dmg"] = 2.0

func _attr_sync_from_hero() -> void:
	refresh()

# 七系面板数据暂时没有来源（穿透/减免/增幅 都是 0）
func type_field(_t: String, _f: String) -> float:
	return 0.0
