extends RefCounted
# ============================================================
# data_talents.gd —— 天赋表 v3（唯一真源：名字 / 说明 / fx / 五问池，全在这一份）
# v3（天赋合并成一个文件）：
#   ① 五问池 AFF_POOL 从 data_creation 搬来，配套 pick_for_affinity()；
#   ② 四位人物自带（勇决/身法/守拙/断枪）登记为 kind "innate"——fx 暂空，
#      不参与抽签、不结算；将来接线只补 fx 那一格；
#   ③ 从此加天赋/调数值/改五问池＝只开这一份；别处只留"转发壳"。
# v2（R0 天赋 fx 归一）：
#   ① 五问池的 7 条并进来（剑心通明/明察秋毫/料敌先机/百折不挠/
#      买卖精通/妙手/贵人相助）——弟子抽的、五问发的，从此读同一张表；
#   ② 天生神力、铁骨 对齐"实际生效值"（伤害 +15% / 气血 +15%），说明同步；
#   ③ 新增按"名字或 id"查的 by_key / fx_of / desc_of——各处只准从这儿拿数。
# fx 键口径（有键才生效；没接的键先空着，说明里带"（接入后生效）"）：
#   dmg 伤害% · hp_pct 气血% · spd 速度 · crit 暴击% · def 防御值 · dodge 闪避值 ·
#   exp_pct 经验% · sell_pct 卖价% ·
#   ㉗新接：dmg_cut 受到伤害减% · cost_pct 强化消耗% （负数＝更便宜）
#   ⚠ v35：def / dodge 是**数值**（不是百分比）——写 "+6" 就是防御/闪避 +6 点，
#     说明里别写 %（两数对拼的算法见 game_data.def_cut / dodge_rate）。
# 谁在吃这张表：GameState.roll_talents()（弟子）· run_state.talent_fx_sum()（游历）·
#   pick_for_affinity()（五问，池子 AFF_POOL 就在下面）。改数值只改这一份。
# ㉗：talents 里存"纯名字"（不带（说明）后缀）——talent_fx_sum / fx_of 是按名字查表的，
#   名字里混进说明就查不到、加成静默失效。说明一律现查（GameState.talent_desc）。
# ============================================================

const LIST := [
	# ⚠ v61（用户："少侠的五问属性超模了 削弱"）：**战斗类签统一压到"专武/角色星"那一档**。
	#   对照预算（同一条线上的数值都在这附近，别再往上抬）：
	#     专武常驻：伤害 +5% / 暴击 +5%、暴伤 +13%     角色星：伤害 +6% / 暴击 +5% / 气血 +12%
	#   五问一局给**四条**（前四问各一条，且都是好签、还是玩家自己挑的系），
	#   所以单条的分量不能压过"一件专武"——原来那几条（+15% 伤害 / +20% 剑伤 / +10 速度）
	#   等于白送两三件专武，主角自然一路碾压。
	#   这次只动**战斗类** 8 条（伤害/剑伤/暴击/速度/气血/减伤/闪避）；
	#   非战斗那几条（买卖精通/妙手/悟性过人/福缘深厚/贵人相助）一个字没动——
	#   "超模"说的是打起来太强，不是经济。
	#   想再松/再紧：只改这张表的 fx，**desc 必须一起改**（面板读的是 desc）。
	#   v62（用户："不少属性增幅都太大了…先伤害增幅全部减半"）：五问池再按同一条尺子走一遍——
	#     伤害/剑伤/气血减半、暴击 ×0.7、闪避速度这类小点数不动（它们本来就是"小数据"）。
	{"id": "shenli", "name": "天生神力", "kind": "good", "desc": "出手更沉：伤害 +4%", "fx": {"dmg": 4}},
	{"id": "tiegu", "name": "铁骨", "kind": "good", "desc": "底子厚：气血 +4%", "fx": {"hp_pct": 4}},
	{"id": "qingyan", "name": "身轻如燕", "kind": "good", "desc": "闪得更开：闪避 +4", "fx": {"dodge": 4}},
	{"id": "mingmu", "name": "目光如炬", "kind": "good", "desc": "看得准：暴击 +3%", "fx": {"crit": 3}},
	{"id": "kuaibu", "name": "快人一步", "kind": "good", "desc": "先动半步：速度 +2", "fx": {"spd": 2}},
	{"id": "wuxing", "name": "悟性过人", "kind": "good", "desc": "学得快：经验 +15%", "fx": {"exp_pct": 15}},
	# v62（用户："主角的福源深厚降低降低至15%"）：40% → **15%**。
	#   它乘在"这一节有没有可搜的东西"的概率上（journey_stage._spawn_loot：
	#   chance = 20% × 翻财 × 舍装 × (1 + 本值)，合计封顶 75%）——40% 等于白送四成的搜刮点，
	#   在"搜刮＝残页/材料的主要来路"这条线上太重了。
	#   文案顺手把过期的"（接入后生效）"去掉——㉗ 之后它早就接上了。
	{"id": "fuyuan", "name": "福缘深厚", "kind": "good", "desc": "运气好：搜刮更容易出货（每节出产率 +15%）", "fx": {"loot_pct": 15}},
	{"id": "jianxin", "name": "剑心通明", "kind": "good", "desc": "剑上生慧：使剑或空手时，出手伤害 +5%", "fx": {"art_dmg": 5}},
	{"id": "mingcha", "name": "明察秋毫", "kind": "good", "desc": "看得准：暴击 +3%", "fx": {"crit": 3}},
	{"id": "liaodi", "name": "料敌先机", "kind": "good", "desc": "先动半步：速度 +4，更易抢先手", "fx": {"spd": 4}},
	{"id": "baizhe", "name": "百折不挠", "kind": "good", "desc": "站得住：气血不足三成时，受到的伤害 -6%", "fx": {"dmg_cut": 6}},
	{"id": "maimai", "name": "买卖精通", "kind": "good", "desc": "买卖不吃亏：卖出价 +20%", "fx": {"sell_pct": 20}},
	{"id": "miaoshou", "name": "妙手", "kind": "good", "desc": "巧手：升星消耗 -30%（接入后生效）", "fx": {"cost_pct": -30}},
	{"id": "guiren", "name": "贵人相助", "kind": "good", "desc": "游历事件可四选一（接入后生效）", "fx": {"evt_pick": 1}},
	# ㊴：为「缘法」补的第三条（缘法原本只有两条，五系凑不齐每系三条）
	{"id": "fengxiong", "name": "逢凶化吉", "kind": "good", "desc": "遇险总有转机：受到的伤害 -3%", "fx": {"dmg_cut": 3}},
	{"id": "lansan", "name": "懒散", "kind": "bad", "desc": "练得慢：经验 -15%", "fx": {"exp_pct": -15}},
	{"id": "tiruo", "name": "体弱", "kind": "bad", "desc": "气血薄：气血 -8%", "fx": {"hp_pct": -8}},
	{"id": "cuxin", "name": "粗心", "kind": "bad", "desc": "出手毛躁：暴击 -5%", "fx": {"crit": -5}},
	{"id": "manre", "name": "慢热", "kind": "bad", "desc": "开场软：首轮出手减半（以后接）", "fx": {}},
	{"id": "qiezhen", "name": "怯阵", "kind": "bad", "desc": "人众则慌：三人同场速度 -2（以后接）", "fx": {}},
	{"id": "tanbei", "name": "贪杯", "kind": "bad", "desc": "状态起伏：数值随酒（以后接）", "fx": {}},
	{"id": "shoujiu", "name": "守旧", "kind": "bad", "desc": "换新兵器要时间适应：换装当战攻击 -10%（以后接）", "fx": {}},
	# ---- 人物自带（kind "innate"：不参与抽签；"怎么算"在 journey/data_roles.INNATE）----
	# 说明以那边为准（本表这几条不写"占位"，免得面板上露出"接入后生效"）
	# ⚠ 面板上显示的 desc 就是这一行（Roles.innate_desc 优先取本表）——改数值必须两处一起改
	{"id": "yongjue", "name": "勇决", "kind": "innate", "desc": "气血不足一半时，出手伤害 +25%", "fx": {}},
	{"id": "shenfa", "name": "身法", "kind": "innate", "desc": "身法更轻（暂未接线）", "fx": {}},
	{"id": "shouzhuo", "name": "守拙", "kind": "innate", "desc": "气血上限 +15%", "fx": {}},   # v62x（用户："陈石的被动已经去掉了气血成长 但是说明还留着 去掉"）：+20%→+15%（与 data_roles 同步）、删掉"每级多涨 2 点气血"那句
	# ㊿：断枪现在没人挂（陈石的自带改成了守拙）；这条 desc 本来就是旧文案，别照它读数值
	{"id": "duanqiang", "name": "断枪", "kind": "innate", "desc": "手里是枪时，反刺/反伤效果 +10%", "fx": {}},

]

static func by_id(tid: String) -> Dictionary:
	for t in LIST:
		if str(t.get("id", "")) == tid:
			return t
	return {}

# 按"名字或 id"查（各处一律走这三个口，别再自己拼对照）
static func by_key(s: String) -> Dictionary:
	for t in LIST:
		if str(t.get("id", "")) == s or str(t.get("name", "")) == s:
			return t
	return {}

static func fx_of(s: String) -> Dictionary:
	var t := by_key(s)
	if t.is_empty():
		return {}
	var fx: Dictionary = t.get("fx", {})
	return fx

static func desc_of(s: String) -> String:
	return str(by_key(s).get("desc", ""))

static func name_of_id(tid: String) -> String:
	return str(by_id(tid).get("name", ""))

# ---- 五问池（v4 ㊴ 重排：每系三条）----
# 为什么每系要三条：五问里**前四问**各发一条天赋（第五问只送行囊礼物）＝ 抽 4 次，
#   每系在题目里正好出现 3 次，所以**同一条天赋绝不会重复发**，
#   也不会掉进"本系发完了去别系捡漏"的兜底。
# 为什么这样分系：让每一系都对应一种"玩法倾向"，而不是按名字硬凑——
#   武势＝打得更狠 · 智谋＝更准更快 · 韧劲＝更能扛 · 财路＝更会经营 · 缘法＝运气与遭遇
# ⚠ 别把同一系的池子加到 4 条以上而不动别系：一系能被选中的次数一超过池子大小，
#   就会退到全表捡漏，玩家的选择就不再对应他答的那一系了。
const AFF_POOL := {
	"武势": ["天生神力", "剑心通明", "目光如炬"],
	"智谋": ["明察秋毫", "料敌先机", "快人一步"],
	"韧劲": ["铁骨", "百折不挠", "身轻如燕"],
	"财路": ["买卖精通", "妙手", "悟性过人"],
	"缘法": ["福缘深厚", "贵人相助", "逢凶化吉"],
}

# 五问取签：先在本系里挑没发过的；都发过就全表捡漏；返回 {name, desc}
# ㊿t：**定签**——同一串选择永远给同一套天赋。
#   原来这里写的是 avail[randi() % avail.size()]：全局随机数每次启动都不一样，
#   于是"同样五个选项、两次开局，拿到的天赋不同"，玩家眼里就是"答了也白答"。
#   现在按**表序**取第一条没发过的：答什么就对应什么系，系里的签按顺序拿。
#     · 只选一次武势 → 天生神力；再选一次 → 剑心通明；第三次 → 目光如炬
#     · 每系在五问里正好出现 3 次（见 journey/data_creation 的分布表），
#       所以三条签都拿得到，也不会掉进下面的兜底。
static func pick_for_affinity(aff: String, used: Array) -> Dictionary:
	var avail: Array = []
	for nm in AFF_POOL.get(aff, []):
		if not used.has(str(nm)):
			avail.append(str(nm))
	if avail.is_empty():
		# 兜底：本系三条都发过了（正常不会发生——五问只抽四次、每系正好出现三次）
		for k in AFF_POOL.keys():
			for nm2 in AFF_POOL[k]:
				if not used.has(str(nm2)):
					avail.append(str(nm2))
	if avail.is_empty():
		return {}
	var pick := str(avail[0])
	return {"name": pick, "desc": desc_of(pick)}
