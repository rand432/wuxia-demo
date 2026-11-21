extends RefCounted
# 组合卡数据：10 系 × 4 阶；每阶 N 张不同卡，第一张为入口卡

const QUALITY_OF_TIER := [2, 3, 4, 5]  # 初=良 中=玄 高=地 特=天
const SELFS := [
	{"key": "atk", "label": "攻击", "names": [["砺锋","磨锋","藏锋"],["蓄势","养势","蓄锐","待发"],["嗜战","战意","血战","狂战","不退"],["无前","无惧","破阵","斩将","绝尘","独行"]], "own": [1,2,3,4], "own_suffix": "", "set": ["三锋","蓄势","战意","无前"], "trigger": ["每波","每 6 秒","每次击杀","每次攻击"], "combo": ["攻击 +1","攻击 +1","攻击 +1","攻击 +1"], "combo_key": ["atk","atk","atk","atk"], "combo_val": [1,1,1,1]},
	{"key": "def", "label": "防御", "names": [["铁壁","坚甲","护心"],["龟息","绵息","守拙","静水"],["血守","死守","护主","铁誓","不退"],["不摧","金刚","不动","山岳","磐石","不朽"]], "own": [1,1,2,2], "own_suffix": "", "set": ["铁壁","龟息","血守","不摧"], "trigger": ["每波","每 6 秒","每次击杀","每次受击"], "combo": ["防御 +1","防御 +1","防御 +1","防御 +1"], "combo_key": ["def","def","def","def"], "combo_val": [1,1,1,1]},
	{"key": "hp", "label": "气血", "names": [["生机","养元","生息"],["回春","春雨","润脉","复苏"],["不屈","硬骨","续命","血勇","残生"],["长生","驻颜","龟寿","不朽","长存","不灭"]], "own": [15,25,35,50], "own_suffix": "", "set": ["生机","回春","不屈","长生"], "trigger": ["每波","每 6 秒","每次击杀","每次攻击"], "combo": ["气血 +10","气血 +10","气血 +10","回复 2 气血"], "combo_key": ["hp","hp","hp","heal"], "combo_val": [10,10,10,2]},
	{"key": "gold", "label": "金币", "names": [["聚财","拾金","积少"],["生息","钱生","日进","斗金"],["掠夺","豪夺","搜刮","横财","抢掠"],["财源","金海","滚滚","无尽","富贵","通宝"]], "own": [5,8,12,16], "own_suffix": "%", "set": ["聚财","生息","掠夺","财源"], "trigger": ["每波","每 6 秒","每次击杀","每 5 次攻击"], "combo": ["金币 +5%","金币 +2%","金币 +1","金币 +1"], "combo_key": ["gold_pct","gold_pct","gold_flat","gold_flat"], "combo_val": [5,2,1,1]},
	{"key": "mp", "label": "内力", "names": [["凝息","养息","静息"],["聚气","纳气","回元","筑基"],["通脉","周天","督脉","气海","凝丹"],["化虚","返照","无息","大周天","抱元","归真"]], "own": [15,25,35,50], "own_suffix": "", "set": ["凝息","聚气","通脉","化虚"], "trigger": ["每波","每 6 秒","每次击杀","每 10 次攻击"], "combo": ["回复 5 内力","回复 2 内力","回复 3 内力","回复 8 内力"], "combo_key": ["mp_flat","mp_flat","mp_flat","mp_flat"], "combo_val": [5,2,3,8], "arts": ["res://assets/items/chest_jade.png", "res://assets/items/art_spring.png", "res://assets/ui/shop_pill.png", "res://assets/items/art_stone.png", "res://assets/items/chest_jade.png", "res://assets/items/art_spring.png"]},
	{"key": "crystal", "label": "灵晶", "names": [["灵涌","聚灵","引灵"],["凝晶","结晶","晶脉","灵泉"],["猎晶","夺晶","碎晶","搜灵","晶猎"],["晶河","晶海","灵潮","无尽晶","通灵","不竭"]], "own": [5,8,12,16], "own_suffix": "%", "set": ["灵涌","凝晶","猎晶","晶河"], "trigger": ["每波","每 6 秒","每次击杀","每 10 次攻击"], "combo": ["灵晶 +1","灵晶 +1","灵晶 +1","灵晶 +1"], "combo_key": ["crystal_flat","crystal_flat","crystal_flat","crystal_flat"], "combo_val": [1,1,1,1]},
	{"key": "swarm", "label": "群", "names": [["蜂拥","蚁聚","群起"],["潮涌","兽潮","云集","压境"],["蜂起","蚁附","漫野","遮天","蔽日"],["倾巢","天罗","地网","万军","不绝","如潮"]], "own": [1,1,1,1], "own_suffix": "", "set": ["蜂拥","潮涌","蜂起","倾巢"], "trigger": ["常驻","常驻","常驻","常驻"], "combo": ["每波 +2 只","每波 +4 只","每波 +6 只","每波 +10 只"], "combo_key": ["count_flat","count_flat","count_flat","count_flat"], "combo_val": [2,4,6,10], "own_keys": ["count","count","count","count"], "own_texts": ["每波怪物 +1","每波怪物 +1","每波怪物 +1","每波怪物 +1"], "combo_extra_key": ["diff_pct","diff_pct","diff_pct","diff_pct"], "combo_extra_val": [5,10,15,25], "arts": ["res://assets/items/mat_bone.png", "res://assets/items/mat_guo.png", "res://assets/items/mat_zhi.png", "res://assets/items/fate_bloodpath.png", "res://assets/items/fate_allin.png", "res://assets/items/art_shadow.png"]},
	{"key": "peril", "label": "险", "names": [["赏金","悬红","买路"],["晶簇","灵脉","髓光","聚灵"],["遗珍","宝光","秘藏","奇珍","异宝"],["王座","霸主","无归","独尊","天柱","压顶"]], "own": [1,1,10,10], "own_suffix": "", "set": ["赏金","晶簇","遗珍","王座"], "trigger": ["常驻","常驻","常驻","常驻"], "combo": ["文钱怪 +2/波","灵晶怪 +1/波","宝物奖励 +30%","首领奖励 +50%"], "combo_key": ["coin_count","crystal_count","treasure_pct","boss_pct"], "combo_val": [2,1,30,50], "own_keys": ["coin_count","crystal_count","treasure_pct","boss_pct"], "own_texts": ["文钱怪 +1/波","灵晶怪 +1/波","宝物奖励 +10%","首领奖励 +10%"], "combo_extra_key": ["diff_pct","diff_pct","diff_pct","diff_pct"], "combo_extra_val": [5,8,12,20], "arts": ["res://assets/items/loot_silver.png", "res://assets/items/loot_exp.png", "res://assets/items/chest_gold.png", "res://assets/items/fate_greed.png", "res://assets/items/fate_venom.png", "res://assets/items/chest_dragon.png"]},
	{"key": "bounty", "label": "财", "names": [["进账","聚沙","愈战"],["利市","点石","连战","坐地"],["日进","金窟","久战","囤积","居奇"],["万贯","通宝","长胜","不竭","通吃","富甲"]], "own": [0,0,0,0], "own_suffix": "", "set": ["进账","利市","日进","万贯"], "trigger": ["常驻","常驻","常驻","常驻"], "combo": ["随机吞噬 1 张","随机吞噬 2 张","随机吞噬 3 张","随机吞噬 5 张"], "combo_key": ["devour_n","devour_n","devour_n","devour_n"], "combo_val": [1,2,3,5], "own_matrix": [["wen_flat","crystal_flat","kill_pct"],["wen_flat","crystal_flat","kill_pct","wen_flat"],["wen_flat","crystal_flat","kill_pct","wen_flat","crystal_flat"],["wen_flat","crystal_flat","kill_pct","wen_flat","crystal_flat","wen_flat"]], "own_val_matrix": [[10,2,10],[20,4,15,10],[35,8,20,15,4],[60,15,30,20,8,30]], "own_text_matrix": [["文钱 +10","灵晶 +2","击杀收益 +10%"],["文钱 +20","灵晶 +4","击杀收益 +15%","文钱 +10"],["文钱 +35","灵晶 +8","击杀收益 +20%","文钱 +15","灵晶 +4"],["文钱 +60","灵晶 +15","击杀收益 +30%","文钱 +20","灵晶 +8","文钱 +30"]], "arts": ["res://assets/items/loot_silver.png", "res://assets/items/loot_exp.png", "res://assets/items/fate_greed.png", "res://assets/items/chest_gold.png", "res://assets/items/chest_jade.png", "res://assets/items/chest_dragon.png"]},
	{"key": "exp", "label": "经验", "names": [["奋起","历练","磨砺"],["精进","苦修","心得","通悟"],["顿悟","破境","明心","见性","大成"],["悟道","通天","无涯","见真","圆融","圆满"]], "own": [5,8,12,16], "own_suffix": "%", "set": ["奋起","精进","顿悟","悟道"], "trigger": ["常驻","常驻","常驻","常驻"], "combo": ["杀怪数 +5%","杀怪数 +8%","杀怪数 +12%","杀怪数 +16%"], "combo_key": ["killnum_pct","killnum_pct","killnum_pct","killnum_pct"], "combo_val": [5,8,12,16], "arts": ["res://assets/items/it_book.png", "res://assets/items/it_scroll.png", "res://assets/items/art_bell.png", "res://assets/items/loot_exp.png", "res://assets/items/art_spring.png", "res://assets/items/chest_jade.png"]},
]

# 全新卡组接口：当前为空，L10 Boss 首通后由 GameState.new_cards_unlocked 打开。
# 以后把新卡组数据填进 new_group() 返回的 cards/entries 即可，不改抽卡主流程。
static func new_group() -> Dictionary:
	return {"cards": {}, "entries": []}

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
				var own_key := str(s["key"]) if str(s["key"]) in ["atk","def","hp","mp"] else str(s["key"]) + "_pct"
				if s.has("own_matrix"):
					own_key = str(s["own_matrix"][tier][idx])
					own_val = int(s["own_val_matrix"][tier][idx])
					own_text = str(s["own_text_matrix"][tier][idx])
				elif s.has("own_keys"):
					own_key = str(s["own_keys"][tier])
					own_text = str(s["own_texts"][tier])
				elif str(s["key"]) == "atk":
					own_text = "攻击 +" + str(own_val)
				elif str(s["key"]) == "def":
					own_text = "全系减免 +" + str(own_val * 3) + "%"     # v6：防御 → 固定减免（1 点 = 3%）
				elif str(s["key"]) == "hp":
					own_text = "气血 +" + str(own_val)
				elif str(s["key"]) == "mp":
					own_text = "内力 +" + str(own_val)
				elif str(s["key"]) == "exp":
					own_text = "杀怪数 +" + str(own_val) + "%"
				elif str(s["key"]) == "gold":
					own_text = "金币 +" + str(own_val) + "%"
				else:
					own_text = "灵晶 +" + str(own_val) + "%"
				var card := {
					"id": id, "series": str(s["key"]), "label": str(s["label"]),
					"tier": tier, "idx": idx, "name": str(nm_list[idx]),
					"quality": QUALITY_OF_TIER[tier], "art": _art_of(id, s, idx),
					"own_key": own_key,
					"own_val": own_val, "own_text": own_text,
					"set_id": "%s_%d" % [str(s["key"]), tier], "set_size": nm_list.size(),
					"combo_name": str(s["set"][tier]), "trigger": str(s["trigger"][tier]),
					"combo_text": str(s["combo"][tier]), "combo_key": str(s["combo_key"][tier]),
					"combo_val": int(s["combo_val"][tier]),
					"entry": idx == 0, "unlock_ids": [],
					"combo_extra_key": str(s["combo_extra_key"][tier]) if s.has("combo_extra_key") else "",
					"combo_extra_val": int(s["combo_extra_val"][tier]) if s.has("combo_extra_val") else 0,
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


# 卡图：优先生成图（assets/art/cards/gen/<series>.png 十系统一图标）；再退到单卡图 gen/<id>.png；最后退该系物品图
static func _art_of(id: String, s: Dictionary, idx: int) -> String:
	var series := "res://assets/art/cards/gen/" + str(s["key"]) + ".png"
	if ResourceLoader.exists(series):
		return series
	var gen := "res://assets/art/cards/gen/" + id + ".png"
	if ResourceLoader.exists(gen):
		return gen
	var arr: Array = s["arts"]
	if arr.is_empty():
		return "res://assets/items/it_sword.png"
	return str(arr[idx % arr.size()])
