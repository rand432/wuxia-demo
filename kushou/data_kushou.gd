extends RefCounted
# ============================================================
# kushou/data_kushou.gd —— 「困兽」数据与效果引擎（v1 试玩）
#   卡 = {id, name, q(品级0..4), school, free(不占格), req(前置), fx(效果标签)}
#   效果标签（v1 先上这一组，机制型标签逐版加）：
#     atk N / hp N / life N / money_wave N / grid N / dmg N / aspd N /
#     crit N / dodge N / taken N / regen N（每秒回血%）
#     neg_life_wave N / neg_money_wave N / neg_aspd N / neg_dmg N（负面）
#     draw_growth N（偷师：每抽一张 攻/血 +N）
#     kill_scale N（每击杀 1 怪 攻 +N*0.1，取整）
# ============================================================

const Q_CN := ["凡品", "良品", "上品", "极品", "绝品"]

# 三派卡池（v1 试玩：少林 10 · 唐门 8 · 丐帮 6 · 散件 4）
const CARDS := {
	# ---- 少林（长线 · 主线 5 环 + 支线 + 散件）----
	"ks_luohan": {"name": "罗汉拳", "q": 0, "school": "shaolin", "fx": {"atk": 10}},
	"ks_weituo": {"name": "韦陀掌", "q": 1, "school": "shaolin", "req": "ks_luohan", "fx": {"atk": 18, "dmg": 6}},
	"ks_fumo": {"name": "伏魔棍", "q": 1, "school": "shaolin", "req": "ks_luohan", "fx": {"atk": 22, "aspd": 10}},
	"ks_jinzhong": {"name": "金钟罩", "q": 2, "school": "shaolin", "req": "ks_fumo", "fx": {"taken": 12, "neg_dmg": 5}},
	"ks_yijin": {"name": "易筋经", "q": 3, "school": "shaolin", "req": "ks_jinzhong", "fx": {"hp": 60, "grid": 1}},
	"ks_damo": {"name": "达摩心法", "q": 4, "school": "shaolin", "req": "ks_yijin", "fx": {"atk": 60, "dmg": 25}},
	"ks_tietou": {"name": "铁头功", "q": 0, "school": "shaolin", "free": true, "fx": {"hp": 20}},
	"ks_yiwei": {"name": "一苇渡江", "q": 1, "school": "shaolin", "fx": {"dodge": 20}},
	"ks_kuxing": {"name": "苦行戒", "q": 2, "school": "shaolin", "req": "ks_yijin", "fx": {"regen": 1, "neg_money_wave": 100}},
	"ks_shizi": {"name": "狮子吼", "q": 2, "school": "shaolin", "req": "ks_jinzhong", "fx": {"atk": 25, "crit": 8}},
	# ---- 唐门（中线 · 主线 5 环 + 毒支 + 弩）----
	"ks_duanren": {"name": "淬毒短刃", "q": 0, "school": "tangmen", "fx": {"atk": 12, "dmg": 5}},
	"ks_feixing": {"name": "飞星镖", "q": 1, "school": "tangmen", "req": "ks_duanren", "fx": {"atk": 20, "crit": 6}},
	"ks_lihua": {"name": "暴雨梨花", "q": 2, "school": "tangmen", "req": "ks_feixing", "fx": {"atk": 35, "aspd": 15}},
	"ks_kongque": {"name": "孔雀翎", "q": 3, "school": "tangmen", "req": "ks_lihua", "fx": {"atk": 55, "crit": 15}},
	"ks_qianji": {"name": "千机变", "q": 4, "school": "tangmen", "req": "ks_kongque", "fx": {"atk": 80, "dmg": 20}},
	"ks_wudu": {"name": "五毒功", "q": 1, "school": "tangmen", "req": "ks_duanren", "fx": {"dmg": 30, "neg_life_wave": 2}},
	"ks_nu": {"name": "机簧弩", "q": 1, "school": "tangmen", "fx": {"atk": 25, "aspd": 20, "neg_dmg": 10}},
	"ks_qingshen": {"name": "轻身术", "q": 0, "school": "tangmen", "free": true, "fx": {"dodge": 15}},
	# ---- 丐帮（短线）----
	"ks_dagou": {"name": "打狗棒法", "q": 0, "school": "gaibang", "fx": {"atk": 14, "money_wave": 80}},
	"ks_chanzi": {"name": "缠字诀", "q": 1, "school": "gaibang", "req": "ks_dagou", "fx": {"atk": 22, "taken": 8}},
	"ks_tiaozi": {"name": "挑字诀", "q": 1, "school": "gaibang", "req": "ks_dagou", "fx": {"atk": 20, "crit": 8}},
	"ks_tianxia": {"name": "天下无狗", "q": 2, "school": "gaibang", "req": "ks_chanzi", "fx": {"atk": 38, "dmg": 12}},
	"ks_kanglong": {"name": "亢龙有悔", "q": 3, "school": "gaibang", "req": "ks_tianxia", "fx": {"atk": 60, "dmg": 20, "neg_aspd": 15}},
	"ks_lianhua": {"name": "莲花落", "q": 0, "school": "gaibang", "free": true, "fx": {"money_wave": 150}},
	# ---- 散件（任何门派可抽）----
	"ks_toushi": {"name": "偷师", "q": 0, "school": "", "fx": {"draw_growth": 1}},
	"ks_taiji": {"name": "太极劲", "q": 2, "school": "", "fx": {"taken": 10}},
	"ks_tuna": {"name": "吐纳术", "q": 0, "school": "", "free": true, "fx": {"regen": 1}},
	"ks_tiesha": {"name": "铁砂掌", "q": 1, "school": "", "fx": {"atk": 18, "kill_scale": 1}},
}

# 三怪轮替（小怪 1~9 波循环；血攻按波数放大）
const MONSTERS := [
	{"name": "狱狼", "atk": 6, "hp": 60},
	{"name": "疯牛", "atk": 9, "hp": 45},
	{"name": "毒蝎", "atk": 4, "hp": 80},
]
# Boss 表（10/15/20/25/30/35 波）
const BOSSES := [
	{"name": "看门恶犬", "atk": 14, "hp": 520},
	{"name": "双头狮", "atk": 20, "hp": 1100},
	{"name": "铁甲犀", "atk": 28, "hp": 2300},
	{"name": "狱头·刀疤", "atk": 38, "hp": 4800},
	{"name": "场主心腹·黑鳞", "atk": 52, "hp": 9800},
	{"name": "场主亲养·狴犴", "atk": 70, "hp": 20000},
]

# 开局签（自虐换收益 · 可不挑）
const STARTER_SIGNS := {
	"cursed": {"name": "受咒的赏钱", "desc": "每波结算 +1000 文；开局生命 -2，每累计 5000 文结算再 -2"},
	"arrogant": {"name": "傲骨", "desc": "击杀概率掉 200 文/刷新/抽卡（随机）；进攻怪难度 +50%"},
	"greedy": {"name": "贪功", "desc": "Boss 关武学格 +1；永久删 1 个随机门派"},
}

# ---- 角色初始面板（Lv1 状态 · 单人选一）----
const HEROES := {
	"player": {"name": "少侠", "atk": 12, "hp": 110, "crit": 5, "dodge": 3},
	"chen_shi": {"name": "陈石", "atk": 10, "hp": 130, "crit": 3, "dodge": 2},
	"qingluan": {"name": "苏青鸾", "atk": 9, "hp": 95, "crit": 10, "dodge": 8},
}

# 该卡能不能抽（前置已拿/无前置；已被拿过不重复入池）
static func can_offer(cid: String, have: Array) -> bool:
	var c: Dictionary = CARDS.get(cid, {})
	if c.is_empty():
		return false
	if have.has(cid):
		return false
	var req := str(c.get("req", ""))
	if req != "" and not have.has(req):
		return false
	return true

# 卡组总值（效果标签叠加）
static func deck_stats(have: Array) -> Dictionary:
	var out := {"atk": 0, "hp": 0, "life": 0, "money_wave": 0, "grid": 0, "dmg": 0,
		"aspd": 0, "crit": 0, "dodge": 0, "taken": 0, "regen": 0,
		"neg_life_wave": 0, "neg_money_wave": 0, "neg_aspd": 0, "neg_dmg": 0, "draw_growth": 0}
	for cid in have:
		var c: Dictionary = CARDS.get(cid, {})
		var fx: Dictionary = c.get("fx", {})
		for k in fx.keys():
			out[k] = int(out.get(k, 0)) + int(fx[k])
	return out

# 卡面短说明（牌桌上那行字）
static func card_line(cid: String) -> String:
	var c: Dictionary = CARDS.get(cid, {})
	if c.is_empty():
		return "?"
	var parts: Array = []
	var fx: Dictionary = c.get("fx", {})
	if int(fx.get("atk", 0)) != 0:
		parts.append("攻+" + str(fx["atk"]))
	if int(fx.get("hp", 0)) != 0:
		parts.append("血+" + str(fx["hp"]))
	if int(fx.get("life", 0)) != 0:
		parts.append("命+" + str(fx["life"]))
	if int(fx.get("dmg", 0)) != 0:
		parts.append("伤+" + str(fx["dmg"]) + "%")
	if int(fx.get("aspd", 0)) != 0:
		parts.append("速+" + str(fx["aspd"]) + "%")
	if int(fx.get("crit", 0)) != 0:
		parts.append("暴+" + str(fx["crit"]) + "%")
	if int(fx.get("dodge", 0)) != 0:
		parts.append("闪+" + str(fx["dodge"]) + "%")
	if int(fx.get("taken", 0)) != 0:
		parts.append("受击-" + str(fx["taken"]) + "%")
	if int(fx.get("regen", 0)) != 0:
		parts.append("每秒回血" + str(fx["regen"]) + "%")
	if int(fx.get("money_wave", 0)) != 0:
		parts.append("每波+" + str(fx["money_wave"]) + "文")
	if int(fx.get("grid", 0)) != 0:
		parts.append("格+" + str(fx["grid"]))
	if int(fx.get("draw_growth", 0)) != 0:
		parts.append("抽卡成长")
	if int(fx.get("neg_life_wave", 0)) != 0:
		parts.append("每波命-" + str(fx["neg_life_wave"]))
	if int(fx.get("neg_money_wave", 0)) != 0:
		parts.append("每波-" + str(fx["neg_money_wave"]) + "文")
	if int(fx.get("neg_aspd", 0)) != 0:
		parts.append("速-" + str(fx["neg_aspd"]) + "%")
	if int(fx.get("neg_dmg", 0)) != 0:
		parts.append("伤-" + str(fx["neg_dmg"]) + "%")
	return " · ".join(PackedStringArray(parts))
