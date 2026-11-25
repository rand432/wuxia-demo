extends RefCounted
# ============================================================
# kushou/balance_rules.gd —— 逐关平衡规则（从 battle_ui._process 抽出）
#
#   原来这段每帧写在 battle_ui._process 里（旧 :3144-3176），
#   每加一关都要动 UI 主文件。现在集中在这里，UI 只负责传上下文。
#
#   level_vuln() 返回 -1.0 表示「本关不覆盖」，交给内核默认值。
# ============================================================
const FD := preload("res://shared/forge_data.gd")
const GS := preload("res://shared/game_state.gd")

# 关卡 → 怪物隐藏易伤（foe_vuln）
static func level_vuln(level: int, equip_vuln: float, combined: Array, ancestor_combos: Array) -> float:
	if level >= 2 and level <= 4:
		# 不改怪面板，只偷偷加易伤：成长/家传组合给足，经济/危途给少一点
		var vuln := equip_vuln
		for rec in combined:
			var s := str((rec as Dictionary).get("series", ""))
			if s in ["gold", "crystal", "exp", "bounty"]:
				vuln += 0.06
			elif s in ["swarm", "peril"]:
				vuln += 0.10
			else:
				vuln += 0.15
		vuln += float(ancestor_combos.size()) * 0.15
		return minf(0.45, vuln)
	if level == 7:
		# 第七关：技能升级过，怪偷偷吃更多伤害；没升级也能过，只是吃力
		var skill_total := 0
		for v in GS.skill_lv.values():
			skill_total += int(v)
		return minf(0.30, float(skill_total) * 0.015 + equip_vuln)
	if level == 8:
		# 第八关：局外装备强化越高，怪偷偷越脆；四件 +20 共 80 级 → 20% 易伤
		var plus_total := 0
		for slot_v in FD.SLOT_KEYS:
			plus_total += int((FD.equipped.get(str(slot_v), {}) as Dictionary).get("plus", 0))
		return minf(0.35, float(plus_total) * 0.0025 + equip_vuln)
	if equip_vuln > 0.0:
		return minf(0.45, equip_vuln)
	return -1.0
