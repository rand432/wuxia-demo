extends RefCounted
# ============================================================
# data_affixes.gd —— 怪词缀表 v2（㉘ 数值外置）
# 词缀挂在敌字典的 "affixes": ["thorns", ...] 上；出村 battle_lite 与游历 duel_battle
# 各自兑现效果，本表只管数据与文案。
# ㉘ 变更：数值从 const 改成静态读取口（不传参调用）——
#   值可以放进 res://tuning.cfg 或 user://tuning.cfg 覆盖，改完不用重打包。
#   读不到就用下面写着的默认值（＝原来的数，行为一模一样）。
#   调用方从 Affixes.THORN_PCT 改成 Affixes.THORN_PCT()（多一对括号）。
# ============================================================

const Tuning := preload("res://shared/tuning.gd")

const LIST := {
	"thorns":  {"name": "反伤", "desc": "挨一下弹一下——出手的人受 12% 回的伤（一次最多打掉他上限的一成）"},
	"swift":   {"name": "速攻", "desc": "每第 3 手追一记快招（六成力）"},
	# v3（用户："回春词缀改为 10%恢复 两手恢复一次"）：6%/每手 → **10%／每两手**
	"regen":   {"name": "回春", "desc": "出手即回气——**每两手**回 **10%** 气血上限"},
	# v36：说明写清"哪一边的全队"——它只炸**对面**（我方），绝不会伤到它自己的同伴
	"bomb":    {"name": "自爆", "desc": "倒下时轰然炸开——**对面全队**各受**他自己**气血上限四成的伤（只炸对面，不伤它自己的同伴；满血挨炸不会一下炸死）"},
	"shock":   {"name": "电盾", "desc": "挨打 30% 几率电手——出手的人下一手落空"},
	"berserk": {"name": "狂暴", "desc": "气血不到一半，出手重一倍六"},
	"rally":   {"name": "鼓舞", "desc": "此怪每出一手，怪自己攻击 +6%（最多叠到 +60%）"},
	"fury":    {"name": "战意", "desc": "每挨一下，攻击 +8%（最多叠到 +80%）"},
	"poison":  {"name": "毒刃", "desc": "击中就上毒：对手此后每手掉 3% 气血上限（可叠 3 层）"},
	# ㉟：站位相关的词缀——前排挡刀是基本规矩，能破规矩的只有这条
	"pierce":  {"name": "破前", "desc": "长兵/暗器——普攻也能越过前排，够到中排"},
	# ㊿：两条"偷袭"词缀——都是站位反制：专打没被挡着的那些
	"ambush":  {"name": "偷袭", "desc": "够到中排往后，且对**不是前排**的目标伤害 +50%——藏后排也没用"},
	"cutoff":  {"name": "截后", "desc": "够到中排往后，而且**专挑站在最后面那个**打（不按'打最近的'）"},
	# ============================================================
	# v52（用户："参考三国志谋定天下这款 SLG，我要加一些负面状态，类似缴械啊、燃烧啊 等"）
	#   两个"击中就上状态"的词缀——状态表在 shared/data_status.gd，
	#   这里只写"哪条词缀、打中之后给对方挂什么"（两套引擎都读 ON_HIT 那一张）。
	# ============================================================
	"flame":   {"name": "火魔", "desc": "击中就上火：「燃烧」1 层——对手此后每手掉 5% 气血上限（可叠 2 层、只烧 2 手）"},
	"lockchain": {"name": "铁锁", "desc": "击中四成几率「缴械」——对手此后 2 手不能普攻（武学与大招照放）"},
	# ============================================================
	# v55（用户："新词缀 也可以加上了"）：词缀从 14 条涨到 25 条。
	#   前 8 条走"击中就上状态"（`ON_HIT` 表）——**引擎一个字都不用改**：
	#   两套引擎的 `_st_affix_hit()` 已经是"遍历身上的词缀 → 查 ON_HIT → 上状态"，
	#   所以这里加一行就等于接好了。后 3 条是机制类，两套引擎各接了一处。
	# ============================================================
	"choke":   {"name": "锁喉", "desc": "击中三五成几率「沉默」——对手此后 2 手放不出武学（普攻与大招照放）"},
	"soften":  {"name": "软筋", "desc": "击中就上「虚弱」——对手此后 3 手出手伤害 −25%（可叠 2 层）"},
	"entangle": {"name": "缠足", "desc": "击中就上「迟缓」——对手此后 3 手出手速度 −30%（可叠 2 层）"},
	"armorcrack": {"name": "裂甲", "desc": "击中就上「破防」——对手此后 3 手**挨打受伤 +30%**（可叠 2 层）"},
	"drainrage": {"name": "泄气", "desc": "击中五成几率「挫锐」——当场打掉对手 30 点怒气，此后 3 手怒气只剩四成"},
	"stagnant": {"name": "滞脉", "desc": "击中五成几率「滞涩」——对手此后 3 手**技能冷却 +2 手**"},
	"sealvein": {"name": "封穴", "desc": "击中三成几率「封脉」——对手此后 2 手**回血只剩三成**"},
	"acuity":  {"name": "点窍", "desc": "击中两成几率「闭窍」——对手此后 3 手**被动全失效**（自带/被动功法/五问天赋/角色星；只在高章出现）"},
	"leech":   {"name": "吸血", "desc": "每击中一次，自己回气血上限的 6%——打得越久它越精神"},
	"bulwark": {"name": "坚壁", "desc": "挨打两成半几率硬挡——那一下**只吃两成伤**"},
	"echo":    {"name": "回响", "desc": "每第 2 手追一记四成力的快招（与「速攻」错开：那条是每第 3 手六成力）"},
}

# v52/v55：词缀 → 击中时给对方挂的状态。格式与武学/大招的 "apply" 完全一样：
#   id 状态表里的键（data_status）；turns 持续几手（0＝用表里的默认）；stacks 层数；chance 触发几率
const ON_HIT := {
	"flame": {"id": "burn", "turns": 2, "stacks": 1, "chance": 1.0},
	"lockchain": {"id": "disarm", "turns": 2, "stacks": 1, "chance": 0.4},
	"choke": {"id": "silence", "turns": 2, "stacks": 1, "chance": 0.35},
	"soften": {"id": "weak", "turns": 3, "stacks": 1, "chance": 1.0},
	"entangle": {"id": "slow", "turns": 3, "stacks": 1, "chance": 1.0},
	"armorcrack": {"id": "sunder", "turns": 3, "stacks": 1, "chance": 1.0},
	"drainrage": {"id": "ragecut", "turns": 3, "stacks": 1, "chance": 0.5},
	"stagnant": {"id": "cdslow", "turns": 3, "stacks": 1, "chance": 0.5},
	"sealvein": {"id": "healseal", "turns": 2, "stacks": 1, "chance": 0.3},
	"acuity": {"id": "nopassive", "turns": 3, "stacks": 1, "chance": 0.2},
}

static func on_hit(id: String) -> Dictionary:
	return ON_HIT.get(id, {})

# 数（两场战斗共用）。括号里的就是默认值，也是 tuning.cfg 里那个键的 fallback。
#
# ㊿：反伤与自爆的**基数**改过一次，这是关键——不是单纯调数值：
#   · 自爆原＝**怪的**气血上限 ×15%。怪的血量本来就厚（游历还 ×3），
#     于是"炸一下等于好几个玩家满血"——挨上就秒。现在按**挨炸那个人的**上限算：
#     谁挨都只按他自己的池子扣，人越厚扣得越多但**永远不会一下炸死**
#     （40% < 100%，满血挨炸必留一口气）。40% 是"很疼但可算"的那一档：
#     挨两下（或炸一下再吃一记普攻）才会倒，所以走位/先手有意义。
#   · ㊿ 后来自爆又改成**全队**（每人都按自己的上限扣 40%）——一只怪倒下，
#     三个人一起掉四成血。⚠ 这支数很凶：两只自爆怪连着死＝全队八成。
#     嫌狠就把下面的 T_BOMB_PCT 调小（tuning 里 affix/bomb_pct 一行）。
#   · v36（用户："自爆全体不要炸到自己人，也要有提示"）：
#     ① **只炸对面**——两条路的实现都只遍历"对面那一侧"的名单
#        （battle_lite._enemy_bomb 走 _party、duel_battle._foe_bomb_if_dead 走 _allies），
#        所以它永远不会伤到自爆者自己的同伴。这一条是**规矩**，以后加"我方自爆"类的
#        东西也照这条来：自爆只打对面。
#     ② **提示写足**：横幅"轰——自爆 N"（N＝这一炸最重的那一下）、每个挨炸的人头上飘 −N、
#        战报再记一行"名字 自爆 → 谁 −N、谁 −N"。
#   · 反伤原＝出手伤害 ×25%。玩家一叠攻击，这一下反回来的就跟着涨，
#     攻击越高越容易被自己打死。现在 12%，**并且加一道硬上限**：
#     一次反伤最多打掉出手人上限的 10%（THORN_CAP）——只有单次挨打超过
#     自己上限的 83% 时才会碰到这道上限，所以它只拦"一击被反死"那种极端情形。
const T_THORN_PCT := 0.12
const T_THORN_CAP := 0.10       # 一次反伤 ≤ 出手人气血上限的这么多
const T_SWIFT_EVERY := 3
const T_SWIFT_PCT := 0.6
const T_REGEN_PCT := 0.10        # v3：0.06 → 0.10（用户："回春…10%恢复"）
const T_REGEN_EVERY := 2         # v3：每几手回一次（用户："两手恢复一次"）
const T_BOMB_PCT := 0.40        # ⚠ 基数是"挨炸那个人的上限"，不是怪的上限
const T_SHOCK_CHANCE := 0.30
const T_BERSERK_MUL := 1.6
const T_RALLY_STEP := 0.06
const T_RALLY_CAP := 0.6
const T_FURY_STEP := 0.08
const T_FURY_CAP := 0.8
const T_POISON_PCT := 0.03
const T_POISON_MAX := 3
# v55（用户："新词缀 也可以加上"）：三条机制类词缀的数
const T_LEECH_PCT := 0.06        # 吸血：每击中一次回自己上限的这么多
const T_BULWARK_CHANCE := 0.25   # 坚壁：挨打时这么多几率硬挡
const T_BULWARK_TAKE := 0.2      # 硬挡那一下只吃两成（不做"完全免伤"——0 伤害会在战报里飘个 −0）
const T_ECHO_EVERY := 2          # 回响：每第 N 手
const T_ECHO_PCT := 0.4          # 那一记的力道（四成）

static func THORN_PCT() -> float:
	return Tuning.num("affix", "thorn_pct", T_THORN_PCT)

static func THORN_CAP() -> float:
	return Tuning.num("affix", "thorn_cap", T_THORN_CAP)

static func SWIFT_EVERY() -> int:
	return Tuning.intv("affix", "swift_every", T_SWIFT_EVERY)

static func SWIFT_PCT() -> float:
	return Tuning.num("affix", "swift_pct", T_SWIFT_PCT)

static func REGEN_PCT() -> float:
	return Tuning.num("affix", "regen_pct", T_REGEN_PCT)

# v3：回春每几手回一次（1＝每手，2＝每两手）——两套引擎都读这一口，别各写各的
static func REGEN_EVERY() -> int:
	return maxi(1, Tuning.intv("affix", "regen_every", T_REGEN_EVERY))

static func BOMB_PCT() -> float:
	return Tuning.num("affix", "bomb_pct", T_BOMB_PCT)

static func SHOCK_CHANCE() -> float:
	return Tuning.num("affix", "shock_chance", T_SHOCK_CHANCE)

static func BERSERK_MUL() -> float:
	return Tuning.num("affix", "berserk_mul", T_BERSERK_MUL)

static func RALLY_STEP() -> float:
	return Tuning.num("affix", "rally_step", T_RALLY_STEP)

static func RALLY_CAP() -> float:
	return Tuning.num("affix", "rally_cap", T_RALLY_CAP)

static func FURY_STEP() -> float:
	return Tuning.num("affix", "fury_step", T_FURY_STEP)

static func FURY_CAP() -> float:
	return Tuning.num("affix", "fury_cap", T_FURY_CAP)

static func POISON_PCT() -> float:
	return Tuning.num("affix", "poison_pct", T_POISON_PCT)

static func POISON_MAX() -> int:
	return Tuning.intv("affix", "poison_max", T_POISON_MAX)

static func LEECH_PCT() -> float:
	return Tuning.num("affix", "leech_pct", T_LEECH_PCT)

static func BULWARK_CHANCE() -> float:
	return Tuning.num("affix", "bulwark_chance", T_BULWARK_CHANCE)

static func BULWARK_TAKE() -> float:
	return Tuning.num("affix", "bulwark_take", T_BULWARK_TAKE)

static func ECHO_EVERY() -> int:
	return Tuning.intv("affix", "echo_every", T_ECHO_EVERY)

static func ECHO_PCT() -> float:
	return Tuning.num("affix", "echo_pct", T_ECHO_PCT)

static func of(id: String) -> Dictionary:
	return LIST.get(id, {})

static func name_of(id: String) -> String:
	return str(of(id).get("name", id))

static func has(ids: Array, id: String) -> bool:
	return ids.has(id)

static func names_text(ids: Array) -> String:
	var arr: Array = []
	for i in ids:
		arr.append(name_of(str(i)))
	return "、".join(PackedStringArray(arr))

# ============================================================
# 词缀池（v55 重排）：14 条 → **25 条**，按"打的第几章/第几档"分四池。
#   分池的理由：池子越大、每条越难撞见——把 25 条搅在一起的话，
#   前期就有一成几率撞上「点窍/吸血」这种硬货，中期又看不到「自爆」。
#     · 早池（3）  ：回春 速攻 反伤——**教学段**（出村第 1 章 / 游历 3~4 档）
#     · 中池（+3） ：鼓舞 毒刃 电盾
#     · 晚池（+5） ：火魔 铁锁 **锁喉 软筋 缠足**——开始"上负面"，但都是温和的
#     · 硬池（+14）：自爆 狂暴 战意 破前 偷袭 截后 **裂甲 泄气 滞脉 封穴 点窍 吸血 坚壁 回响**
#   ⚠ 硬池从**第 6 章**（出村第 31 关）/ **9 档**起——「点窍/吸血」这类不该早期出现。
#   出村只到 10 章（`Tower.chapter_idx`），所以调用方把档口收到 6 就够（game_state 那边已改）。
# ============================================================
const POOL_EARLY := ["regen", "swift", "thorns"]
const POOL_MID := ["rally", "poison", "shock"]
const POOL_LATE := ["flame", "lockchain", "choke", "soften", "entangle"]
const POOL_HARD := ["bomb", "berserk", "fury", "pierce", "ambush", "cutoff",
	"armorcrack", "drainrage", "stagnant", "sealvein", "acuity", "leech", "bulwark", "echo"]

# 出村：按章节点菜
static func pool_for(tier: int) -> Array:
	if tier <= 1:
		return POOL_EARLY.duplicate()
	if tier <= 3:
		return POOL_EARLY + POOL_MID
	if tier <= 5:
		return POOL_EARLY + POOL_MID + POOL_LATE
	return POOL_EARLY + POOL_MID + POOL_LATE + POOL_HARD

# 游历正式趟：按难度档点菜（3 档起加）
static func pool_for_diff(d: int) -> Array:
	if d <= 2:
		return []
	if d <= 4:
		return POOL_EARLY.duplicate()
	if d <= 6:
		return POOL_EARLY + POOL_MID
	if d <= 8:
		return POOL_EARLY + POOL_MID + POOL_LATE
	return POOL_EARLY + POOL_MID + POOL_LATE + POOL_HARD

static func roll_from(pool: Array, n: int) -> Array:
	var p := pool.duplicate()
	p.shuffle()
	return p.slice(0, mini(n, p.size()))
