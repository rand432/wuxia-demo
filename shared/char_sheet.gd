extends RefCounted
# ============================================================
# shared/char_sheet.gd —— 角色页的属性快照
#
#   作用：把「装备合计（FD.totals）＋ 基础常量」组装成一份
#   attr_panel（详细属性页）能直接读的东西，让角色页点一下属性
#   就能看到同一套面板，不用为了看一眼数值去开一局。
#
#   接口刻意和 kushou/kushou_battle.gd 的属性层保持一致：
#     hero / attr / _attr_sync_from_hero() / type_field() / hero_attack_interval()
#   —— 战斗核心那边接上同一份数据之后，这个文件就可以退休。
# ============================================================

const EquipmentStats := preload("res://shared/equipment_stats.gd")

const FD := preload("res://shared/forge_data.gd")

const ATK_BASE := 12.0        # 与 kushou_battle.gd 的 ATTR_BASE 对齐
const HP_BASE := 200.0
const MP_BASE := 100.0
const ATK_SEC := preload("res://shared/combat_rules.gd").BASE_ATTACK_SECONDS

var _equipment: Dictionary = {}
var attr: Dictionary = {}

var hero := {
	"atk": ATK_BASE, "hp": HP_BASE, "hp_max": HP_BASE,
	"mp": MP_BASE, "mp_max": MP_BASE,
	"aspd": 1.0, "crit": 0.05, "crit_dmg": 2.0,
}

func _init() -> void:
	refresh()

# 从装备合计重新算一遍（穿脱装备后调一次即可）
func refresh() -> void:
	FD.load_game()
	var t: Dictionary = FD.totals()
	_equipment = EquipmentStats.bonuses(t)
	hero["atk"] = ATK_BASE + float(t["atk"])
	hero["hp_max"] = HP_BASE + float(t["hp"])
	hero["hp"] = hero["hp_max"]
	hero["mp_max"] = MP_BASE
	hero["mp"] = MP_BASE
	hero["aspd"] = 1.0 + float(_equipment["aspd_amp"])
	hero["crit"] = 0.05
	hero["crit_dmg"] = 2.0
	attr = {
		"atk": {"base": ATK_BASE, "temp": float(t["atk"]), "amp": 0.0},
		"hp": {"base": HP_BASE, "temp": float(t["hp"]), "amp": 0.0},
		"mp": {"base": MP_BASE, "temp": 0.0, "amp": 0.0},
		"aspd": {"base": 1.8, "temp": 0.0, "amp": float(_equipment["aspd_amp"])},
		"crit": {"base": 0.05, "temp": 0.0},
		"cdmg": {"base": 2.0, "temp": 0.0},
	}

func hero_attack_interval() -> float:
	return ATK_SEC / maxf(0.2, minf(5.0, float(hero["aspd"])))

func _attr_sync_from_hero() -> void:
	refresh()

# 局外目前只有装备固定减免，穿透/增幅尚无局外来源。
func type_field(t: String, f: String) -> float:
	if t != "真实" and f == "red_f":
		return float(_equipment.get("red", 0.0))
	return 0.0

func type_effective_field(t: String, f: String) -> float:
	return preload("res://shared/combat_rules.gd").effective_type_field(t, f, type_field(t, f))

func hero_fixed_reduction(t: String) -> float:
	return type_effective_field(t, "red_f")

func type_amp(_t: String) -> float:
	return 0.0
