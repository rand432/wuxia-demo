extends RefCounted
# ============================================================
# data_buffs.gd —— 运签卡组 v3.6（用户："增益卡的属性增幅上调 50%"）
# v3.6（用户："增益卡的属性增幅上调 50%"）：**普通/特殊/专属三类增益卡的数值一律 ×1.5**
#   （v62 那一刀是"伤害增幅全部减半"，这次只回补一半——说明文字同步改成新数）。
#   ①只动**数值**：hp_pct / atk_pct / cut_add / hand_heal / vengeance / spd_pct / follow_dmg /
#     rage_pct / open_rage / ult_cut / rage_on_hit / thorn_up / ult_dmg / ult_window_regen /
#     passive_up。**机制类的整数一个没动**——冰心卡（冷却 -1）、坚壁/长歌（大招 +1 手）、
#     引吭（追剑 +1 段）、淬毒（命中上毒）不是"增幅"，乘 1.5 没有意义。
#   ②**命数签（kind="fate"）一个字没动**——那是"负面换好处"的另一条线，不在"增益卡"里。
#   ③两处封顶照旧吃原口径：回气卡 0.15×2 张 → 仍被 VENG_CAP(0.20) 封住（文案已写明）；
#     轻身卡是"按张相加"（USEFUL_COPIES 里没登记它），两张＝+30%，文案跟着改。
#   ④个别数取整：0.075×1.5＝0.1125 → **0.11**（铁骨/惊鸿），其余保留 .5 级小数。
#   调法：只改下面每条 fx 里的数；PRICE 与封顶值都没动。
# v3.5：①专属卡每角色各加一张（踏浪/磐石桩/惊鸿）——用的都是引擎里已经在读的键，
#     所以战斗引擎一行没动；②命数加两张（续命/锐意），走的是"负面换好处"那条线，
#     代价统一落在 hp_pct（气血上限）上——它只在本场战斗里折算，不会永久削人
#     （打完按比例折回，见 duel_battle 收尾那段）。
#     ⚠ 挑键的原则：好处要挑**相加**的键（buff_fx 同一键多条相加），
#     别挑 cut_add / rage_pct / dmg_cut 那种"取大不叠加"的——那类键一旦被
#     更便宜的同键卡压住，好处就白给了，而代价照样生效。
# v3.4：命数卡 3→6——加短绳/满囊/舍装（出征屏"选一卡"用；游历里也照旧能接前三种）。
#   命数卡（kind="fate"）不进抽卡池；name_of/desc_of/price_of 沿用 v3.3。
# v3.3：补 name_of 等口子（修 run_state 的 Parse Error）。
# v3.1：fx 键名与战斗对齐（passive_up / ult_dur / thorn_up / cut_add / rage_pct / hand_heal /
#   poison_hit / follow_hits / art_cd_minus / open_rage）。
# v3：改口"卡组"；普通卡 6 张；专属卡每角色 3 张；保底抽卡（普通1＋特殊1＋专属1）。
# ============================================================

const PRICE_NORMAL := 40
const PRICE_SPECIAL := 70
const PRICE_EXCL := 100

# ㊿：两张"再请也没用"的封顶值——引擎读这两个数（duel_battle.VENG_CAP 那条线），
#   卡片说明也由这一份生成，免得"文案写封顶、引擎没封"两边打架。
const VENG_CAP := 0.20        # 回气卡：伤害加成最高 +20%（请两张也只算 20%）
const ART_CD_CAP := 2         # 冰心卡：冷却减免最高 -2（＝duel_battle.ART_CD_MINUS_CAP）

# 键 → **最多几张有用**（0 / 没登记＝可以一直叠）。
#   ⚠ 这张表必须照引擎"真正怎么读这个键"来填，不能凭印象。查过一遍
#   duel_battle 里每个键的读法，结论是：**绝大多数键是按张数相加的**——
#   buff_fx() 会把多张的同键加起来，引擎那边出现的 maxf 全是"新旧键名二选一"
#   （rage_pct/rage_up、passive_up/passive_mul、thorn_up/thorn_mul、
#   ult_dur/aura_turns/song_turns、cut_add/taken_cut），**不是**"多张取最大"。
#   所以只有三种情况"再请一张没用"：
#     · 布尔开关：引擎只判 > 0   → poison_hit
#     · 引擎有封顶：clampi/minf → art_cd_minus（封顶 2）、vengeance（封顶 VENG_CAP）
#   其余（hp_pct / atk_pct / cut_add / hand_heal / spd_pct / rage_pct / passive_up /
#   thorn_up / ult_dur / open_rage / ult_dmg / follow_hits / ult_window_regen）
#   都是**请几张就叠几份**——别往这张表里加，加了就会误报"已达上限"。
const USEFUL_COPIES := {
	"poison_hit": 1,              # 命中即上毒，判定是 >0，第 2 张没有意义
	"vengeance": 1,               # duel_battle 里 minf(…, VENG_CAP)：第 2 张不再加
	"art_cd_minus": ART_CD_CAP,   # duel_battle 里 clampi(…, ART_CD_MINUS_CAP)
}

# 这张卡最多请几张还有用（0＝不封顶）
static func useful_copies(bid: String) -> int:
	var fx: Dictionary = of(bid).get("fx", {})
	var best := 0
	for k in fx.keys():
		var n := int(USEFUL_COPIES.get(str(k), 0))
		if n <= 0:
			continue
		# 同一个键只出现在一部分卡上；一张卡带多个受限键时取最紧的那个
		if best == 0 or n < best:
			best = n
	return best

# "手里已经有 owned 张了，再请一张还有没有用"——没用就给一句提示，有用给空串。
# 读它的地方：RunState.add_buff（买完的提示）、卡组面板（签面/卡面/详情）、
#   货郎担子、路边签摊、精英三抽的候选（后三处直接不再摆出来）。
static func cap_hint(bid: String, owned: int) -> String:
	var lim := useful_copies(bid)
	if lim <= 0 or owned < lim:
		return ""
	if lim == 1:
		return "这张的效果不叠加——手里已有 " + str(owned) + " 张，再请一张不会更强"
	return "这张最多叠 " + str(lim) + " 张——已经请满了，再请不会更强"

const CARDS := {
	# ---- 普通卡（养身） ----
	# v62（用户："先伤害增幅全部减半"）：下面是**百分比**（0.15＝15%），一律减半；说明文字同步。
	#   机制类（怒气/冷却/手数/回血/减伤）**没动**——那是玩法不是纯数值。
	"tiegu": {"name": "铁骨卡", "kind": "normal", "price": 40, "desc": "气血上限 +11%（本趟）", "fx": {"hp_pct": 0.11}},
	"ruifeng": {"name": "锐锋卡", "kind": "normal", "price": 40, "desc": "攻击 +9%（本趟）", "fx": {"atk_pct": 0.09}},
	"panshi": {"name": "磐石卡", "kind": "normal", "price": 40, "desc": "受到的伤害 -6%（本趟）", "fx": {"cut_add": 0.06}},
	"shensheng": {"name": "生生卡", "kind": "normal", "price": 40, "desc": "每出手 3 次回复 7.5% 气血（本趟）", "fx": {"hand_heal": 0.075}},
	"huiqi": {"name": "回气卡", "kind": "normal", "price": 40, "desc": "每次受伤后，接下来一次出手伤害 +15%（本趟·连挨几下也只算一次；请两张封顶 +20%）", "fx": {"vengeance": 0.15}},
	"qingshen": {"name": "轻身卡", "kind": "normal", "price": 40, "desc": "每次受击后速度 +15%——出手更快（本趟·挨打只算一次、不按挨打次数累积；请两张＝各算一份，共 +30%）", "fx": {"spd_pct": 0.15}},
	# ---- 特殊卡（改出手） ----
	# v62k（用户："现在可以加点不同命数 和不同增益"）：**三张新增益**——
	#   追风（追击）/ 护心（气血上限，与铁骨卡相加）/ 蓄气（开场怒气，与乘胜卡相加）。
	#   ⚠ 键都挑了"引擎真会读"的那几个（follow_dmg / hp_pct / open_rage），不是白写的。
	"zhuifeng": {"name": "追风卡", "kind": "normal", "price": 40, "desc": "追击伤害 +30%（本趟）", "fx": {"follow_dmg": 0.30}},
	"huxin": {"name": "护心卡", "kind": "normal", "price": 40, "desc": "气血上限 +9%（与铁骨卡相加·本趟）", "fx": {"hp_pct": 0.09}},
	"xuqi": {"name": "蓄气卡", "kind": "normal", "price": 40, "desc": "开场怒气 +30（与乘胜卡相加·本趟）", "fx": {"open_rage": 30}},
	"nutao": {"name": "怒涛卡", "kind": "special", "price": 70, "desc": "怒气获取 +75%（本趟）", "fx": {"rage_pct": 0.75}},
	"cuidu": {"name": "淬毒卡", "kind": "special", "price": 70, "desc": "出手命中即上毒（叠 3 层，每层 3% 上限/手）（本趟）", "fx": {"poison_hit": 1.0}},
	"bingxin": {"name": "冰心卡", "kind": "special", "price": 70, "desc": "功法冷却 -1（本趟·最多减到冷却 1；减冷却封顶 -2，请第三张不再有效）", "fx": {"art_cd_minus": 1.0}},
	# v62k（用户："现在可以加点不同命数 和不同增益"）：**三张新特殊**——
	#   卸势（自己放大招那几手减伤）/ 守真（受击回怒）/ 尖刺（反刺）。
	#   键同样是引擎已在读的：ult_cut / rage_on_hit / thorn_up。
	"xieshi": {"name": "卸势卡", "kind": "special", "price": 70, "desc": "自己放大招的那几手，受到的伤害 -22.5%（本趟）", "fx": {"ult_cut": 0.225}},
	"shouzhen": {"name": "守真卡", "kind": "special", "price": 70, "desc": "每次受击回怒 +12%（怒气上限 100，即 +12 点·本趟）", "fx": {"rage_on_hit": 0.12}},
	"jianci": {"name": "尖刺卡", "kind": "special", "price": 70, "desc": "反刺伤害 +30%（与铁蒺卡相加·本趟）", "fx": {"thorn_up": 0.30}},
	# ---- 专属卡 · 主角 ----
	"pojun": {"name": "破军卡", "kind": "exclusive", "role": "player", "price": 100, "desc": "大招伤害 +22.5%（本趟）", "fx": {"ult_dmg": 0.225}},
	"chengsheng": {"name": "乘胜卡", "kind": "exclusive", "role": "player", "price": 100, "desc": "开场怒气 +45（击杀返还待多敌战再归位）（本趟）", "fx": {"open_rage": 45}},
	"yanghui": {"name": "养晦卡", "kind": "exclusive", "role": "player", "price": 100, "desc": "大招收势后 3 手，每手回复 4.5% 气血（本趟）", "fx": {"ult_window_regen": 0.045}},
	# ㊿：主角第四张——前面的都在"大招"上做文章，这张管续航
	"talang": {"name": "踏浪卡", "kind": "exclusive", "role": "player", "price": 100, "desc": "每出手 3 次回复 9% 气血（与生生卡相加·本趟）", "fx": {"hand_heal": 0.09}},
	# ---- 专属卡 · 陈石 ----
	"jianbi": {"name": "坚壁卡", "kind": "exclusive", "role": "chen_shi", "price": 100, "desc": "大招枪势持续 +1 手（本趟）", "fx": {"ult_dur": 1}},
	"pangen": {"name": "盘根卡", "kind": "exclusive", "role": "chen_shi", "price": 100, "desc": "被动减伤效果 +75%——6%→10.5%（本趟）", "fx": {"passive_up": 0.75}},
	"tieji": {"name": "铁蒺卡", "kind": "exclusive", "role": "chen_shi", "price": 100, "desc": "反刺伤害 +37.5%（本趟）", "fx": {"thorn_up": 0.375}},
	# ㊿：陈石第四张——站桩的底子。挑 hp_pct 而不是 cut_add：减伤那条是"取大"，
	#   会跟盘石卡/他自己的被动撞车；气血上限是"相加"，跟铁骨卡是实打实叠。
	"panshizhuang": {"name": "磐石桩卡", "kind": "exclusive", "role": "chen_shi", "price": 100, "desc": "气血上限 +9%（与铁骨卡相加·本趟）", "fx": {"hp_pct": 0.09}},
	# ---- 专属卡 · 苏青鸾 ----
	"changge": {"name": "长歌卡", "kind": "exclusive", "role": "qingluan", "price": 100, "desc": "大招剑歌持续 +1 手（本趟）", "fx": {"ult_dur": 1}},
	"yinhang": {"name": "引吭卡", "kind": "exclusive", "role": "qingluan", "price": 100, "desc": "大招追剑 +1 段——暴击时多追一剑（本趟）", "fx": {"follow_hits": 1}},
	"cuifeng": {"name": "淬锋卡", "kind": "exclusive", "role": "qingluan", "price": 100, "desc": "被动效果 +75%——暴击 +15%→+26.25%、上限惩罚 -15%→-3.75%（本趟）", "fx": {"passive_up": 0.75}},
	# ㊿：青鸾第四张——她的三张都在被动/大招上，这张直接加刀口（与锐锋卡相加）
	"jinghong": {"name": "惊鸿卡", "kind": "exclusive", "role": "qingluan", "price": 100, "desc": "攻击 +11%（与锐锋卡相加·本趟）", "fx": {"atk_pct": 0.11}},
	# ---- 命数卡（㉙b/㉛：出征屏选一 或 游历中接；不进货郎、不进抽卡；price 0 只是占位） ----
	"fate_greed": {"name": "横财签", "kind": "fate", "price": 0, "desc": "命数·横财——每场文钱收入 **+100%**；攻击 -25%（本趟内一直挂着）", "fx": {"atk_pct": -0.25}},
	"fate_scavenge": {"name": "翻财签", "kind": "fate", "price": 0, "desc": "命数·翻财——**每走一节必定可搜刮**；**每显示一种物品**，当前气血 **-1.5%**（按上限算，**不动上限**·最低剩 1）", "fx": {}},
	"fate_bloodpath": {"name": "血路签", "kind": "fate", "price": 0, "desc": "命数·血路——前方多**六**节险路：三场精英，另有黑店、破窑、古渡各一处；**气血上限 -15% · 攻击 -15%**（打赢了钱厚）", "fx": {"hp_pct": -0.15, "atk_pct": -0.15}},
	"fate_shortrope": {"name": "短绳签", "kind": "fate", "price": 0, "desc": "命数·短绳——**红爆率 +150%**（红件出货率 ×2.5，其余色不动）；每打过一个 boss 关**保底一瓶金色品质的酒**（竹叶酒）；**每过一节攻击力 -2%**（可无限叠加，**没有下限**——走得越远越软）", "fx": {}},
	"fate_fullbag": {"name": "满囊签", "kind": "fate", "price": 0, "desc": "命数·满囊——**包裹 +6 格**；**速度 -50%**", "fx": {"spd_pct": -0.5}},
	"fate_noarmor": {"name": "舍装签", "kind": "fate", "price": 0, "desc": "命数·舍装——**攻击 +40% · 暴击 +50%**；本趟护甲格封着（护甲穿不上）、**气血上限 -30%**，搜刮概率 ×1.5", "fx": {"atk_pct": 0.40, "crit_pct": 0.50, "hp_pct": -0.30}},
	# ㊿：新加的两张——这两张不靠 journey 那边的 flag，纯靠 fx 生效（所以哪条路都通）。
	#   代价都是 hp_pct：气血上限 -N% 只在本场折算，打完按比例折回，不会永久削人。
	"fate_endure": {"name": "续命签", "kind": "fate", "price": 0, "desc": "命数·续命——**每 2 手回复 8% 气血**；**攻击 -25%**（本趟内一直挂着）", "fx": {"hand_heal": 0.08, "hand_heal_every": 2, "atk_pct": -0.25}},
	# v62k：**四张新命数**——都是"负面换好处"，与已有的八张拉开手感：
	#   血勇（攻高身薄）/ 铁衣（硬但手软）/ 孤注（大招猛、平时脆）/ 饮鸩（上毒、血薄）。
	"fate_iron": {"name": "铁衣签", "kind": "fate", "price": 0, "desc": "命数·铁衣——**受到的伤害 -50%**；**所有治疗效果（包括吸血）削弱 80%**（本趟内一直挂着）", "fx": {"cut_add": 0.50, "heal_cut": 0.80}},
	"fate_allin": {"name": "孤注签", "kind": "fate", "price": 0, "desc": "命数·孤注——**大招伤害 +100%**；**受到的伤害 +50%**（本趟内一直挂着）", "fx": {"ult_dmg": 1.0, "cut_add": -0.50}},
	"fate_venom": {"name": "饮鸩签", "kind": "fate", "price": 0, "desc": "命数·饮鸩——出手命中即上毒（同淬毒卡）；**气血上限 -18% · 速度 -18%**（本趟内一直挂着）", "fx": {"poison_hit": 1.0, "hp_pct": -0.18, "spd_pct": -0.18}},
	"fate_sharpen": {"name": "锐意签", "kind": "fate", "price": 0, "desc": "命数·锐意——**出手伤到人即回血 5%**（按实际打出的伤害算）；气血上限 -50%（本趟内一直挂着）", "fx": {"lifesteal": 0.05, "hp_pct": -0.50}},
}

static func of(id: String) -> Dictionary:
	return CARDS.get(id, {})

static func all_ids() -> Array:
	return CARDS.keys()

static func name_of(id: String) -> String:
	return str(of(id).get("name", id))

static func desc_of(id: String) -> String:
	return str(of(id).get("desc", ""))

static func price_of(id: String) -> int:
	return int(of(id).get("price", 0))

# 抽卡池：只放 normal / special / **这趟在阵里那几个人的** exclusive——命数卡（fate）永不进池
# ㊿：当初把"只认本角色"的过滤撤了——拦的地方挪到"只对卡上那个角色生效"
#   （见 RunState.buff_fx(role_id)）。参数留着，就是为了以后按"上阵的这几个人"收窄池子。
# ㊿u：现在收窄了。**主人不在阵里，他的专属卡就不进池**：那张卡请回来也不出力
#   （buff_fx 只认卡上那个人），摆在货架/签面上就是坑人（引子趟只有少侠一个人，
#   却摆着"坚壁卡（专属卡 · 陈石专用）"——请了白花 100 两）。
#   普通卡与特殊卡不受影响（它们对全队生效）。
#   party 空 = **不筛**（老口径兜底）：正常调用一律传 RunState.party_role_ids()。
static func pool_for_role(_rid: String, party: Array = []) -> Array:
	var out: Array = []
	for id in CARDS.keys():
		var c: Dictionary = CARDS[id]
		var k := str(c.get("kind", "normal"))
		if k == "normal" or k == "special":
			out.append(str(id))
		elif k == "exclusive" and owner_deployed(str(id), party):
			out.append(str(id))
	return out

# ㊿u：这张专属卡的主人，这趟在不在阵里（非专属卡永远算"在"）。
#   party 空 = 不筛——给没接队伍的调用点兜底，免得一漏传就把所有专属卡全禁了。
static func owner_deployed(bid: String, party: Array) -> bool:
	var b := of(bid)
	if str(b.get("kind", "")) != "exclusive":
		return true
	if party.is_empty():
		return true
	return party.has(str(b.get("role", "")))

static func kind_cn(id: String) -> String:
	var k := str(of(id).get("kind", "normal"))
	if k == "special":
		return "特殊卡"
	if k == "exclusive":
		return "专属卡"
	if k == "fate":
		return "命数卡"
	return "普通卡"

# ㊿：专属卡上"给谁用"的汉名（卡面与详情都读这一份）
const ROLE_CN := {"player": "少侠", "chen_shi": "陈石", "qingluan": "苏青鸾"}

static func role_cn(rid: String) -> String:
	return str(ROLE_CN.get(rid, rid))

# ㊿：这张卡的专属主人（短名，如"少侠"）；不是专属卡＝空串。
#   专属卡"请得到、但只对卡上那个人出力"，所以**凡是列出它的地方都得写出是谁的**
#   ——不然三张专属卡长得一模一样，玩家只能靠猜。
static func owner_cn(bid: String) -> String:
	var b := of(bid)
	if str(b.get("kind", "")) != "exclusive":
		return ""
	return role_cn(str(b.get("role", "")))

# ㊿：卡面上的"谁的专属"备注；非专属＝空串
static func owner_note(bid: String) -> String:
	var o := owner_cn(bid)
	return "" if o == "" else o + "专用"

# ㊿：统一的卡面标题——"破军卡（专属卡 · 少侠专用）"／"铁骨卡（普通卡）"。
#   抽签面、签摊、货郎、当前卡组、精英三选一全用它，免得各写一套、有的写有的不写。
static func title_of(bid: String) -> String:
	var nm := name_of(bid)
	var k := kind_cn(bid)
	var o := owner_note(bid)
	if o == "":
		return nm + "（" + k + "）"
	return nm + "（" + k + " · " + o + "）"

# 保底见三样——普通 1 + 特殊 1 + 专属 1（专属只从"在阵那几个人"的里挑）；不够再拿没上过的补到 n
static func roll_offers(rid: String, n := 3, party: Array = []) -> Array:
	var out: Array = []
	for kind in ["normal", "special", "exclusive"]:
		var bucket: Array = []
		for k in pool_for_role(rid, party):
			if str(of(str(k)).get("kind", "normal")) == kind:
				bucket.append(str(k))
		bucket.shuffle()
		if not bucket.is_empty():
			out.append(str(bucket[0]))
	var rest: Array = pool_for_role(rid, party)
	rest.shuffle()
	for k2 in rest:
		if out.size() >= n:
			break
		if not out.has(str(k2)):
			out.append(str(k2))
	return out

# fx 汇总：同一 id 只算一次；多条同键相加（数值）
static func merge_fx(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for id_v in ids:
		var fx: Dictionary = of(str(id_v)).get("fx", {})
		for k in fx.keys():
			var v = fx[k]
			if typeof(v) == TYPE_BOOL:
				out[k] = true
			elif out.has(k):
				out[k] = out[k] + v
			else:
				out[k] = v
	return out
