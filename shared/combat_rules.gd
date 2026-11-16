extends RefCounted

# 当前接入战斗的基础节奏。属性层 aspd 的 1.8 是历史归一化单位。
const BASE_ATTACK_SECONDS := 0.60
const TYPE_RATE_CAP := 0.60
const DAMAGE_AMP_CAP := 2.0

static func effective_type_field(type: String, field: String, raw: float) -> float:
	if field in ["pen_f", "pen_p", "red_f", "red_p"]:
		return 0.0 if type == "真实" else clampf(raw, 0.0, TYPE_RATE_CAP)
	return maxf(0.0, raw) if field in ["amp_f", "amp_p"] else raw
