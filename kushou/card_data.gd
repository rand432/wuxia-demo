extends RefCounted
# 组合卡数据：5 系 × 4 阶；每阶 N 张不同卡，第一张为入口卡

const QUALITY_OF_TIER := [2, 3, 4, 5]  # 初=良 中=玄 高=地 特=天
const SELFS := [
	{"key": "atk", "label": "攻击", "names": [["砺锋","磨锋","藏锋"],["蓄势","养势","蓄锐","待发"],["嗜战","战意","血战","狂战","不退"],["无前","无惧","破阵","斩将","绝尘","独行"]], "own": [1,2,3,4], "own_suffix": "", "set": ["三锋","蓄势","战意","无前"], "trigger": ["每波","每 6 秒","每次击杀","每次攻击"], "combo": ["攻击 +1","攻击 +1","攻击 +1","攻击 +1"], "combo_key": ["atk","atk","atk","atk"], "combo_val": [1,1,1,1], "arts": ["res://assets/items/it_sword.png", "res://assets/items/it_sword2.png", "res://assets/items/it_blade.png", "res://assets/items/wpn_sword3.png", "res://assets/items/wpn_sword4.png", "res://assets/items/wpn_sword5.png"]},
	{"key": "def", "label": "防御", "names": [["铁壁","坚甲","护心"],["龟息","绵息","守拙","静水"],["血守","死守","护主","铁誓","不退"],["不摧","金刚","不动","山岳","磐石","不朽"]], "own": [1,1,2,2], "own_suffix": "", "set": ["铁壁","龟息","血守","不摧"], "trigger": ["每波","每 6 秒","每次击杀","每次受击"], "combo": ["防御 +1","防御 +1","防御 +1","防御 +1"], "combo_key": ["def","def","def","def"], "combo_val": [1,1,1,1], "arts": ["res://assets/items/it_armor.png", "res://assets/items/armor2.png", "res://assets/items/armor3.png", "res://assets/gen/char/gear_sheet/it_cloak.png", "res://assets/items/it_armor.png", "res://assets/items/armor2.png"]},
	{"key": "hp", "label": "气血", "names": [["生机","养元","生息"],["回春","春雨","润脉","复苏"],["不屈","硬骨","续命","血勇","残生"],["长生","驻颜","龟寿","不朽","长存","不灭"]], "own": [15,25,35,50], "own_suffix": "", "set": ["生机","回春","不屈","长生"], "trigger": ["每波","每 6 秒","每次击杀","每次攻击"], "combo": ["气血 +10","气血 +10","气血 +10","回复 2 气血"], "combo_key": ["hp","hp","hp","heal"], "combo_val": [10,10,10,2], "arts": ["res://assets/items/it_herb.png", "res://assets/items/art_spring.png", "res://assets/ui/shop_pill.png", "res://assets/ui/stats/hp.png", "res://assets/items/it_herb.png", "res://assets/items/art_spring.png"]},
	{"key": "gold", "label": "金币", "names": [["聚财","拾金","积少"],["生息","钱生","日进","斗金"],["掠夺","豪夺","搜刮","横财","抢掠"],["财源","金海","滚滚","无尽","富贵","通宝"]], "own": [5,8,12,16], "own_suffix": "%", "set": ["聚财","生息","掠夺","财源"], "trigger": ["每波","每 6 秒","每次击杀","每 5 次攻击"], "combo": ["金币 +5%","金币 +2%","金币 +1","金币 +1"], "combo_key": ["gold_pct","gold_pct","gold_flat","gold_flat"], "combo_val": [5,2,1,1], "arts": ["res://assets/items/it_ingot.png", "res://assets/items/loot_silver.png", "res://assets/items/chest_gold.png", "res://assets/items/chest_silver.png", "res://assets/items/it_ingot.png", "res://assets/items/loot_silver.png"]},
	{"key": "crystal", "label": "灵晶", "names": [["灵涌","聚灵","引灵"],["凝晶","结晶","晶脉","灵泉"],["猎晶","夺晶","碎晶","搜灵","晶猎"],["晶河","晶海","灵潮","无尽晶","通灵","不竭"]], "own": [5,8,12,16], "own_suffix": "%", "set": ["灵涌","凝晶","猎晶","晶河"], "trigger": ["每波","每 6 秒","每次击杀","每 10 次攻击"], "combo": ["灵晶 +1","灵晶 +1","灵晶 +1","灵晶 +1"], "combo_key": ["crystal_flat","crystal_flat","crystal_flat","crystal_flat"], "combo_val": [1,1,1,1], "arts": ["res://assets/items/art_stone.png", "res://assets/items/chest_jade.png", "res://assets/gen/char/qing_cogflash.png", "res://assets/items/art_stone.png", "res://assets/items/chest_jade.png", "res://assets/gen/char/qing_cogflash.png"]},
]

static func build() -> Dictionary:
	var cards := {}
	var sets := {}
	var entries: Array = []
	for s in SELFS:
		for tier in 4:
			var ids: Array = []
			var nm_list: Array = s["names"][tier]
			for idx in nm_list.size():
				var id := "%s_%d_%d" % [str(s["key"]), tier, idx]
				var own_val := int(s["own"][tier])
				var own_text := ""
				if str(s["key"]) == "atk":
					own_text = "攻击 +" + str(own_val)
				elif str(s["key"]) == "def":
					own_text = "防御 +" + str(own_val)
				elif str(s["key"]) == "hp":
					own_text = "气血 +" + str(own_val)
				elif str(s["key"]) == "gold":
					own_text = "金币 +" + str(own_val) + "%"
				else:
					own_text = "灵晶 +" + str(own_val) + "%"
				var card := {
					"id": id, "series": str(s["key"]), "label": str(s["label"]),
					"tier": tier, "idx": idx, "name": str(nm_list[idx]),
					"quality": QUALITY_OF_TIER[tier], "art": str((s["arts"] as Array)[idx % (s["arts"] as Array).size()]),
					"own_key": str(s["key"]) if str(s["key"]) in ["atk","def","hp"] else str(s["key"]) + "_pct",
					"own_val": own_val, "own_text": own_text,
					"set_id": "%s_%d" % [str(s["key"]), tier], "set_size": nm_list.size(),
					"combo_name": str(s["set"][tier]), "trigger": str(s["trigger"][tier]),
					"combo_text": str(s["combo"][tier]), "combo_key": str(s["combo_key"][tier]),
					"combo_val": int(s["combo_val"][tier]),
					"entry": idx == 0, "unlock_ids": [],
				}
				cards[id] = card
				ids.append(id)
			for cid in ids:
				var rest: Array = []
				for other in ids:
					if other != cid:
						rest.append(other)
				(cards[cid] as Dictionary)["unlock_ids"] = rest
			sets["%s_%d" % [str(s["key"]), tier]] = ids
			if tier == 0:
				entries.append(ids[0])
	return {"cards": cards, "sets": sets, "entries": entries}

static func art_for(series: String) -> String:
	for s in SELFS:
		if str(s["key"]) == series:
			return str((s["arts"] as Array)[0])
	return "res://assets/items/it_sword.png"
