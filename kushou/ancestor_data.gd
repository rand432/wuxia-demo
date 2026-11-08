extends RefCounted
# ============================================================
# kushou/ancestor_data.gd —— 祖宗家传卡（请神系统的卡池部分）
#
#   · 每位祖宗 6 档 × 每档 3 张 = 18 张；每档第一张是入口卡
#   · 同档 3 张集齐 → 组合生效 → 清空 → 下一档入口进池
#   · 卡组 10 格，最多同开 3 档
#   · 炫卡：抽到该祖宗家传卡时 4% 掷；中了进池，刷新高权重
#
# effects 键（组合加成，落地在 battle_ui._cast_skill）：
#   dmg_pct    本技能伤害 +X%
#   cd_pct     本技能冷却 −X%
#   mp_flat    本技能内力 −X
#   elem_pct   {元素: X}  该元素所有祖宗共享
#   para_s     命中麻痹 X 秒
#   para_amp   麻痹期间受伤 +X%
# ============================================================

const TIER_NAMES := ["初级", "二档", "三档", "四档", "五档", "六档"]
const TIER_STARS := [0, 1, 2, 3, 4, 5]

const ANCESTORS := {
	"zl": {
		"name": "张道陵", "skill": "天雷道术", "quality": 5, "dtype": "金系",
		"art": "res://assets/items/art_stone.png",
		"tiers": [
			{"combo_name": "引雷", "combo_text": "天雷伤害 +20%", "effects": {"dmg_pct": 20},
			 "cards": [["引雷", "天雷伤害 +8%"], ["聚电", "天雷伤害 +8%"], ["贯雷", "天雷暴击 +5%"]]},
			{"combo_name": "凝神", "combo_text": "冷却 −12% · 内力 −20", "effects": {"cd_pct": 12, "mp_flat": 20},
			 "cards": [["凝神", "冷却 −6%"], ["息念", "内力 −12"], ["守一", "冷却 −6%"]]},
			{"combo_name": "雷动", "combo_text": "半径 +25", "effects": {},
			 "cards": [["雷动", "半径 +15"], ["震荡", "半径 +15"], ["扩散", "落点溅射 +10%"]]},
			{"combo_name": "金罡", "combo_text": "金系伤害 +15%（众）", "effects": {"elem_pct": {"金系": 15}},
			 "cards": [["金罡", "金系伤害 +6%（众）"], ["庚金", "金系伤害 +6%（众）"], ["锋锐", "金系技能冷却 −6%"]]},
			{"combo_name": "雷缚", "combo_text": "必定麻痹 · 1.5 秒", "effects": {"para_s": 1.5},
			 "cards": [["雷缚", "麻痹几率 +20%"], ["定身", "麻痹时长 +0.4s"], ["僵直", "麻痹时长 +0.4s"]]},
			{"combo_name": "天罚", "combo_text": "麻痹期间受伤 +20%（众）", "effects": {"para_amp": 20},
			 "cards": [["天罚", "麻痹期间受伤 +8%"], ["雷劫", "麻痹期间受伤 +8%"], ["诛邪", "麻痹目标死亡爆雷"]]},
		],
		"shiny": {"name": "噬雷", "self_text": "天雷伤害 +10%",
			"devour_text": "进卡组即吞尽全部家传卡",
			"per_card": "灵晶 +20 · 文钱 +150 · 天雷伤害 +10%"},
	},
	"cuisanniang": {
		"name": "崔三娘", "skill": "雾海龙王", "quality": 5, "dtype": "召唤",
		"art": "res://assets/items/chest_jade.png",
		"tiers": [
			{"combo_name": "龙息", "combo_text": "蛟龙伤害 +20%", "effects": {"dmg_pct": 20},
			 "cards": [["龙息", "蛟龙伤害 +8%"], ["鳞甲", "蛟龙生命 +10%"], ["獠牙", "蛟龙普攻 +8%"]]},
			{"combo_name": "潮生", "combo_text": "冷却 −12% · 内力 −20", "effects": {"cd_pct": 12, "mp_flat": 20},
			 "cards": [["潮生", "冷却 −6%"], ["深流", "内力 −12"], ["静水", "冷却 −6%"]]},
			{"combo_name": "赴海", "combo_text": "存在时间 +8 秒", "effects": {"life_flat": 8},
			 "cards": [["赴海", "存在 +4 秒"], ["蛰伏", "存在 +4 秒"], ["不息", "召唤时回内 +10"]]},
			{"combo_name": "承脉", "combo_text": "召唤伤害 +15%（众）", "effects": {"elem_pct": {"召唤": 15}},
			 "cards": [["承脉", "召唤伤害 +6%（众）"], ["血裔", "召唤伤害 +6%（众）"], ["龙鳞", "蛟龙普攻 +8%"]]},
			{"combo_name": "呼龙", "combo_text": "蛟龙上限 +1", "effects": {"cap_add": 1},
			 "cards": [["呼龙", "蛟龙上限 +1"], ["分流", "蛟龙继承 +5%"], ["共潮", "双龙在场伤害 +10%"]]},
			{"combo_name": "怒涛", "combo_text": "「大浪拍击」进化：单体 → 范围 + 减速", "effects": {"wave_evo": 1},
			 "cards": [["怒涛", "大浪伤害 +20%"], ["溃堤", "大浪范围 +40"], ["凝滞", "大浪附加减速"]]},
		],
		"shiny": {"name": "吞海", "self_text": "蛟龙伤害 +10%",
			"devour_text": "进卡组即吞尽全部家传卡",
			"per_card": "灵晶 +20 · 文钱 +150 · 蛟龙伤害 +10%"},
	},
	"jicanghai": {
		"name": "季沧海", "skill": "怒火焚身", "quality": 4, "dtype": "火系",
		"art": "res://assets/items/chest_gold.png",
		"tiers": [
			{"combo_name": "燎原", "combo_text": "火焰伤害 +20%", "effects": {"dmg_pct": 20},
			 "cards": [["燎原", "火焰伤害 +8%"], ["沸血", "火焰伤害 +8%"], ["焦骨", "灼烧时长 +1s"]]},
			{"combo_name": "疾焰", "combo_text": "冷却 −12% · 内力 −20", "effects": {"cd_pct": 12, "mp_flat": 20},
			 "cards": [["疾焰", "冷却 −6%"], ["余烬", "内力 −12"], ["急燃", "冷却 −6%"]]},
			{"combo_name": "传火", "combo_text": "引燃目标 +1", "effects": {"ignite_add": 1},
			 "cards": [["传火", "引燃 +1 名"], ["蔓延", "引燃 +1 名"], ["风助", "引燃范围 +30"]]},
			{"combo_name": "火德", "combo_text": "火系伤害 +15%（众）", "effects": {"elem_pct": {"火系": 15}},
			 "cards": [["火德", "火系伤害 +6%（众）"], ["炎精", "火系伤害 +6%（众）"], ["赤羽", "火系技能冷却 −6%"]]},
			{"combo_name": "焚身", "combo_text": "每次命中灼烧 +1 层", "effects": {"burn_add": 1},
			 "cards": [["焚身", "灼烧 1s"], ["炙烤", "灼烧 1s"], ["熔骨", "灼烧伤害 +8%"]]},
			{"combo_name": "火葬", "combo_text": "灼烧目标死亡时爆火", "effects": {"burn_add": 1},
			 "cards": [["火葬", "死亡爆火 30%"], ["灰烬", "死亡爆火 +10%"], ["焦土", "爆火范围 +30"]]},
		],
		"shiny": {"name": "焚天", "self_text": "火焰伤害 +10%",
			"devour_text": "进卡组即吞尽全部家传卡",
			"per_card": "灵晶 +20 · 文钱 +150 · 火焰伤害 +10%"},
	},
	"zhujue": {
		"name": "主角", "skill": "基础剑法", "quality": 4, "dtype": "物理",
		"art": "res://assets/char/player_q.png",
		"tiers": [
			{"combo_name": "剑势", "combo_text": "物理伤害 +20%", "effects": {"dmg_pct": 20},
			 "cards": [["锋起", "物理伤害 +8%"], ["剑鸣", "物理伤害 +8%"], ["直刺", "普攻伤害 +8%"]]},
			{"combo_name": "疾风", "combo_text": "冷却 −12% · 内力 −20", "effects": {"cd_pct": 12, "mp_flat": 20},
			 "cards": [["疾风", "冷却 −6%"], ["收势", "内力 −12"], ["回风", "冷却 −6%"]]},
			{"combo_name": "连斩", "combo_text": "攻击目标 +1", "effects": {"tgt_add": 1},
			 "cards": [["连斩", "目标 +1"], ["缠斗", "攻速 +8%"], ["追击", "目标 +1"]]},
			{"combo_name": "剑意", "combo_text": "物理伤害 +15%（众）", "effects": {"elem_pct": {"物理": 15}},
			 "cards": [["剑意", "物理伤害 +6%（众）"], ["锋锐", "物理伤害 +6%（众）"], ["剑心", "物理技冷却 −6%"]]},
			{"combo_name": "破防", "combo_text": "伤害 +20%", "effects": {"dmg_pct": 20},
			 "cards": [["破防", "破防 10%"], ["重劈", "破防 10%"], ["断岳", "破防 +5%"]]},
			{"combo_name": "无我", "combo_text": "伤害 +25%", "effects": {"dmg_pct": 25},
			 "cards": [["无我", "击杀增伤 +10%"], ["剑魂", "击杀回内"], ["一心", "增伤持续 +1s"]]},
		],
		"shiny": {"name": "剑魄", "self_text": "物理伤害 +10%",
			"devour_text": "进卡组即吞尽全部家传卡",
			"per_card": "灵晶 +20 · 文钱 +150 · 物理伤害 +10%"},
	},
}


static func build() -> Dictionary:
	var cards := {}
	var sets := {}
	var entries: Array = []
	for aid_v in ANCESTORS.keys():
		var aid := str(aid_v)
		var a: Dictionary = ANCESTORS[aid]
		var tiers: Array = a["tiers"]
		for t in tiers.size():
			var ids: Array = []
			var tier: Dictionary = tiers[t]
			var names: Array = tier["cards"]
			var sid := "%s_%d" % [aid, t]
			for i in names.size():
				var pair: Array = names[i]
				var id := "%s_t%d_%d" % [aid, t, i]
				var card := {
					"id": id, "ancestor": aid, "ancestor_name": str(a["name"]),
					"series": aid, "label": str(a["name"]),
					"tier": t, "idx": i, "name": str(pair[0]),
					"quality": int(a["quality"]), "art": str(a["art"]),
					"own_key": "", "own_val": 0, "own_text": str(pair[1]),
					"set_id": sid, "set_size": names.size(),
					"combo_name": str(tier["combo_name"]),
					"combo_text": str(tier["combo_text"]),
					"effects": tier.get("effects", {}),
					"trigger": "", "combo_key": "", "combo_val": 0,
					"entry": i == 0, "unlock_ids": [],
					"tier_label": TIER_NAMES[t], "stars": TIER_STARS[t],
				}
				cards[id] = card
				ids.append(id)
			for cid in ids:
				var rest: Array = []
				for other in ids:
					if other != cid:
						rest.append(other)
				(cards[cid] as Dictionary)["unlock_ids"] = rest
			sets[sid] = ids
			entries.append(ids[0])
	return {"cards": cards, "sets": sets, "entries": entries}

# 炫卡定义（每位祖宗一张，独立卡，不进套）
static func shiny_cards() -> Dictionary:
	var out := {}
	for aid_v in ANCESTORS.keys():
		var aid := str(aid_v)
		var a: Dictionary = ANCESTORS[aid]
		var sh: Dictionary = a["shiny"]
		var id := "shiny_" + aid
		out[id] = {
			"id": id, "shiny": true, "ancestor": aid, "ancestor_name": str(a["name"]),
			"series": aid, "label": str(a["name"]), "tier": -1, "idx": 0,
			"name": str(sh["name"]), "quality": int(a["quality"]), "art": str(a["art"]),
			"own_key": "", "own_val": 0, "own_text": str(sh["self_text"]),
			"set_id": "", "set_size": 0, "combo_name": "", "combo_text": "",
			"trigger": "", "combo_key": "", "combo_val": 0,
			"entry": false, "unlock_ids": [],
			"shiny_self": str(sh["self_text"]), "shiny_devour": str(sh["devour_text"]),
			"shiny_per": str(sh["per_card"]),
		}
	return out

static func ancestor_of(aid: String) -> Dictionary:
	return ANCESTORS.get(aid, {})

static func shiny_of(aid: String) -> Dictionary:
	var a: Dictionary = ANCESTORS.get(aid, {})
	return a.get("shiny", {})
