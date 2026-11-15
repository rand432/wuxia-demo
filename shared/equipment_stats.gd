extends RefCounted
const DEF_TO_RED := 0.03
const SPEED_TO_AMP := 0.01
static func bonuses(totals: Dictionary) -> Dictionary:
	return {"atk": float(totals.get("atk", 0.0)), "hp": float(totals.get("hp", 0.0)),
		"red": float(totals.get("def", 0.0)) * DEF_TO_RED,
		"aspd_amp": float(totals.get("spd", 0.0)) * SPEED_TO_AMP}

# 每局建场时应用一次；局内成长继续使用原属性层。
static func apply(core, totals: Dictionary) -> void:
	var b := bonuses(totals)
	var ratio := clampf(float(core.hero.get("hp", 0.0)) / maxf(1.0, float(core.hero.get("hp_max", 1.0))), 0.0, 1.0)
	core.attr_add("atk", b["atk"])
	core.attr_add("hp", b["hp"])
	core.attr_add_amp("aspd", b["aspd_amp"])
	for type in core.DMG_TYPES:
		if type != core.DMG_TRUE:
			core.type_add(type, "red_f", b["red"])
	core.hero["atk"] = core.attr_final("atk")
	core.hero["hp_max"] = core.attr_final("hp")
	core.hero["hp"] = core.hero["hp_max"] * ratio
	core.hero["aspd"] = core.attr_final("aspd") / float(core.ATTR_BASE["aspd"])
