extends RefCounted
# ============================================================
# data_status.gd —— **状态（负面/正面）唯一真源** v2（v53）
#
# 用户："参考三国志谋定天下这款 SLG，我要加一些负面状态，类似缴械啊、燃烧啊 等"
#   → 第一轮（v52）做了 7 条；第二轮（v53）用户又点名：
#     · 驱散（净化）要加
#     · 削弱怒气 / 禁止技能 / 禁止大招 / 禁止被动 / 技能冷却延长
#     · "受到伤害增加"的那一条（＝ v52 就有的「破防」，见下面注释）
#     · **燃烧要与中毒做区分**（原来两条数值一模一样）
#     · **禁疗不要 100%，60~80% 就行** → 取 70%（回血只剩三成）
#
#   规矩没变：**表里只有数据，怎么用由引擎调下面那几个函数**——引擎里不许写死状态名。
#
# 一条状态长这样（键都是"效果"，引擎读哪条就实现哪条）：
#   name        中文名（战报、浮字、面板都用它）
#   bad         true＝负面（给对面挂的）／false＝正面（给自己挂的）
#   turns       默认持续几"手"（该单位自己的出手次数；放的那一手不算）
#   max_stacks  最多叠几层
#   stack_mode  "add"＝再上一次加一层（封顶）／"refresh"＝只把时长刷满、不叠层
#   dot_pct     每手掉血＝气血上限 × 这个 × 层数（**不吃减伤**，与既有的毒/自爆同口径）
#   atk_pct     出手方攻击 ×(1 + 这个 × 层)（负＝虚弱）
#   taken_pct   挨打方受伤 ×(1 + 这个 × 层)（正＝破防——**这就是"受到伤害增加"那一条**）
#   spd_pct     出手顺序用的速度 ×(1 + 这个 × 层)（负＝迟缓）
#   rage_pct    怒气获取 ×(1 + 这个 × 层)（负＝挫锐）
#   rage_burn   上状态那一刻立刻打掉多少点怒气（现算，两套引擎的怒气都是 0~100）
#   heal_cut    回血 ×(1 − 这个 × 层)（0.7＝只回三成：封脉）
#   cd_add      技能冷却 +N 手（现在还压着的时候，上状态那一刻先把当前冷却一起推后）
#   block_plain 不能普攻（缴械）——武学/大招照放
#   block_arts  不能放武学（沉默）——普攻/大招照放
#   block_ult   不能放大招（封招）——怒气照攒、普攻与武学照放
#   block_passive 被动失效（闭窍）——**这一条是对着玩家来的**（用户："闭窍是针对玩家的"）：
#                 自带天赋 / 被动功法（专武）/ 五问天赋 / 角色星 这几条线全被压住，
#                 由首领的「点窍手」（出村第 50 关往后的模板、游历精英与寨主）给你挂上；
#                 玩家的解法是「清心诀」把它洗掉。实现见 battle_lite._passive_mask / duel_battle._passive_mask。
#   skip        这一手整个不出（震慑）
#   col         面板上那一条的颜色
#
# ⚠ 结算时机（两套引擎必须一致）：**在该单位自己出手之前**结算一次——
#   看 skips() → 掉血 → 时长 −1 → 到 0 就摘掉。跟既有的"毒发"是同一个位置、同一个口径。
#   **先看 skips 再看 tick**：反过来的话，结算会先把震慑的时长减掉，那一手就永远震慑不住。
#
# ⚠ 与既有的「中毒」怎么分工（用户："燃烧要做区分"）：
#   中毒（毒刃词缀，见 data_affixes 的 POISON_*）是**细水长流**：3%/层 · 最多 3 层 · 3 手；
#   燃烧是**急火**：5%/层 · 最多 2 层 · 只 2 手——烧得猛、退得快，一口就是一口。
#   两条走的是两套实现（一条在词缀表、一条在本表），但都是"按上限百分比直接扣、不吃减伤"。
# ============================================================

const RED := Color(0.72, 0.20, 0.16)
const ORANGE := Color(0.80, 0.45, 0.16)
const PURPLE := Color(0.52, 0.30, 0.62)
const BLUE := Color(0.30, 0.42, 0.62)
const GREY := Color(0.42, 0.40, 0.42)
const GREEN := Color(0.28, 0.50, 0.30)
const TEAL := Color(0.24, 0.46, 0.46)
const BROWN := Color(0.50, 0.34, 0.22)
const GOLD := Color(0.74, 0.60, 0.22)
const EARTH := Color(0.56, 0.42, 0.24)

const S := {
	# ---- 掉血类 ----
	# v58（用户第 5 条）：燃烧改成**五行印记·火**——叠到 3 层触发一次性「爆燃」，
	#   之后**不再爆**（"后续爆发不可叠加"）。层数上限跟着阈值走（2 → 3）。
	"burn": {"name": "燃烧", "glyph": "燃", "bad": true, "turns": 3, "max_stacks": 3, "stack_mode": "add",
		"dot_pct": 0.05, "col": ORANGE,
		"elem": "fire", "burst_at": 3, "burst": "爆燃", "burst_kind": "fire_blast", "burst_v": 0.12,
		"desc": "急火：每手掉气血上限的 5%/层（最多 3 层；掉血不吃减伤）。\n**叠到 3 层当场「爆燃」**——一次性火伤（上限 12%，吃火元素伤害加成），此后这一条不再爆"},
	# ---- v58：五行印记·水（给对手）----
	"soak": {"name": "水浸", "glyph": "浸", "bad": true, "turns": 3, "max_stacks": 3, "stack_mode": "add",
		"spd_pct": -0.25, "col": BLUE,
		"elem": "water", "burst_at": 3, "burst": "踏浪", "burst_kind": "steal_water", "burst_v": 0.15,
		"desc": "浑身湿重：出手顺序用的速度 -25%/层（最多 3 层）。\n**叠到 3 层触发「踏浪」**——夺走对手 15%/层 的水元素抗性（可夺成负数），\n夺来的那一份**变成自己的水元素伤害加成与速度**"},
	# ---- v58：五行印记·金（给自己）----
	"gild": {"name": "鎏金", "glyph": "鎏", "bad": false, "turns": 3, "max_stacks": 4, "stack_mode": "add",
		"atk_pct": 0.12, "col": GOLD,
		"elem": "metal", "burst_at": 4, "burst": "鎏金三叠", "burst_kind": "metal_multi", "burst_v": 0.60, "burst_n": 3,
		"desc": "金气镀身：出手攻击 +12%/层（最多 4 层）。\n**叠到 4 层触发「鎏金三叠」**——连打 3 段金伤害（每段 攻击 60%，走金元素通道）"},
	# ---- v58：五行印记·木（给自己）----
	"parasite": {"name": "寄生", "glyph": "寄", "bad": false, "turns": 3, "max_stacks": 4, "stack_mode": "add",
		"heal_up": 0.15, "col": GREEN,
		"elem": "wood", "burst_at": 4, "burst": "吸血藤", "burst_kind": "wood_from_heal", "burst_v": 1.20,
		"desc": "藤蔓附体：所有回血 +15%/层（最多 4 层）。\n**叠到 4 层触发「吸血藤」**——按这一条挂上期间**累计回的血** ×1.2 造成木伤害"},
	# ---- v58：五行印记·土（给自己）----
	"rockskin": {"name": "岩甲", "glyph": "岩", "bad": false, "turns": 3, "max_stacks": 4, "stack_mode": "add",
		"shield_pct": 0.06, "col": EARTH,
		"elem": "earth", "burst_at": 4, "burst": "崩山", "burst_kind": "earth_from_shield", "burst_v": 0.80,
		"desc": "土石附体：**每层给一层护盾**（＝气血上限 6%/层，相当于额外生命值）。\n护盾没打光之前**不掉气血**，但每回合自然衰减 10%。\n**叠到 4 层触发「崩山」**——按当前护盾值 ×0.8 造成**真实伤害**"},
	"disarm": {"name": "缴械", "glyph": "械", "bad": true, "turns": 2, "max_stacks": 1, "stack_mode": "refresh",
		"block_plain": true, "col": GREY,
		"desc": "兵器被磕飞：这 2 手**不能普攻**（武学与大招照放，也可以格挡）"},
	"silence": {"name": "沉默", "glyph": "默", "bad": true, "turns": 2, "max_stacks": 1, "stack_mode": "refresh",
		"block_arts": true, "col": PURPLE,
		"desc": "穴道被点：这 2 手**不能放武学**（普攻与大招照放）"},
	"ultseal": {"name": "封招", "glyph": "招", "bad": true, "turns": 2, "max_stacks": 1, "stack_mode": "refresh",
		"block_ult": true, "col": RED,
		"desc": "大招被封：这 2 手**放不出大招**——怒气照样攒着，满了也放不出来"},
	"stun": {"name": "震慑", "glyph": "震", "bad": true, "turns": 1, "max_stacks": 1, "stack_mode": "refresh",
		"skip": true, "col": PURPLE,
		"desc": "心神被夺：这一手整个不出（挨打照旧）"},
	# ---- 削弱类 ----
	"sunder": {"name": "破防", "glyph": "破", "bad": true, "turns": 3, "max_stacks": 2, "stack_mode": "add",
		"taken_pct": 0.30, "col": RED,
		"desc": "护体被打散：**挨打时受伤 +30%/层**（可叠 2 层）——要「打得更疼」就用它"},
	"weak": {"name": "虚弱", "glyph": "弱", "bad": true, "turns": 3, "max_stacks": 2, "stack_mode": "add",
		"atk_pct": -0.25, "col": BLUE,
		"desc": "气力不济：出手伤害 -25%/层（可叠 2 层）"},
	"slow": {"name": "迟缓", "glyph": "迟", "bad": true, "turns": 3, "max_stacks": 2, "stack_mode": "add",
		"spd_pct": -0.30, "col": GREEN,
		"desc": "手脚发沉：出手顺序用的速度 -30%/层（可叠 2 层）"},
	"ragecut": {"name": "挫锐", "glyph": "挫", "bad": true, "turns": 3, "max_stacks": 1, "stack_mode": "refresh",
		"rage_pct": -0.60, "rage_burn": 30, "col": TEAL,
		"desc": "锐气被夺：上手就先打掉 30 点怒气，此后 3 手**怒气获取只剩四成**"},
	"cdslow": {"name": "滞涩", "glyph": "滞", "bad": true, "turns": 3, "max_stacks": 1, "stack_mode": "refresh",
		"cd_add": 2, "col": BROWN,
		"desc": "经脉滞涩：**技能冷却 +2 手**（当下正在冷却的一起往后推；这 3 手里新放的也 +2）"},
	"nopassive": {"name": "闭窍", "glyph": "窍", "bad": true, "turns": 3, "max_stacks": 1, "stack_mode": "refresh",
		"block_passive": true, "col": PURPLE,
		"desc": "窍穴被封：**被动全失效**——自带天赋、被动功法（专武）、五问天赋、角色星这几条线全压住（已经算进气血上限的那一份退不回来，血条不缩）；首领的点窍手会给你上这一条"},
	"healseal": {"name": "封脉", "glyph": "脉", "bad": true, "turns": 2, "max_stacks": 1, "stack_mode": "refresh",
		"heal_cut": 0.70, "col": PURPLE,
		"desc": "经脉被封：这 2 手**回血只剩三成**（口子还开着，但灌不进去）"},
}

const ORDER := ["burn", "disarm", "silence", "ultseal", "stun", "sunder", "weak", "slow",
	"ragecut", "cdslow", "nopassive", "healseal", "soak", "gild", "parasite", "rockskin"]

# v58：**五行印记**这一支（用户第 5 条）——它们自己是一组：按属性给、叠到 x 层爆一次
const MARKS := ["burn", "soak", "gild", "parasite", "rockskin"]

static func is_mark(id: String) -> bool:
	return MARKS.has(id)

# 属性 → 印记 id（**元素攻击按属性给印记**：火给对手燃烧、水给对手水浸，
#   金木土给自己鎏金/寄生/岩甲——用户追问后的口径："金木土叠自己，火水叠对手"）
const MARK_OF := {"fire": "burn", "water": "soak", "metal": "gild", "wood": "parasite", "earth": "rockskin"}

static func mark_of_elem(e: String) -> String:
	return str(MARK_OF.get(e, ""))

# 这一条印记叠到几层爆（0＝不爆）
static func burst_at(id: String) -> int:
	return int(def_of(id).get("burst_at", 0))

static func burst_name(id: String) -> String:
	return str(def_of(id).get("burst", ""))

# 这一条爆过了没有（**"后续爆发不可叠加"** 就靠它）——爆过就不再爆，直到这条散了/被洗掉
static func bursted(u: Dictionary, id: String) -> bool:
	var b: Dictionary = u.get(KEY, {})
	if not b.has(id):
		return false
	return bool((b[id] as Dictionary).get("fired", false))

static func _mark_fired(u: Dictionary, id: String) -> void:
	var b: Dictionary = u.get(KEY, {})
	if b.has(id):
		(b[id] as Dictionary)["fired"] = true

# ============================================================
# v54 全局规则（用户："全局规则——身上每挂一条负面，挨打就多受一点伤"）
#   每挂一条负面 → 挨打时受伤 **+4%**，最多算 **5 条**（封顶 +20%）。
#   · 按**条数**算，不按层数（燃烧 3 层也只算"一条"）
#   · 与「破防」叠加：破防是那一条自己额外给的 +30%/层
#   · ⚠ 掉血类（燃烧/中毒/自爆）**不走这一条**——它们是"按上限直接扣、不吃减伤"
#   · 两套引擎都从 taken_mul() 走（出村 _e_take/_member_take_cut、游历 _foe_take/_p_mitigate），
#     所以这一条全引擎自动生效，一处都不用改
#   嫌狠/嫌轻就改这两个数（＋4% × 5 条）。
# ============================================================
const PER_BAD_TAKEN := 0.04
const BAD_TAKEN_CAP := 0.20

# ============================================================
# v142（用户："功法中 负面和控制功法削弱【对于玩家削弱 怪拿到的是增强版】"）
#
#   **只有"负面"（bad=true）打折；正面（鎏金/寄生/岩甲…）两边一模一样，谁放都不折。**
#     · 玩家放的 → **削弱版**：时长 ×0.5（向上取整、至少 1 手）· 控制类层数锁 1 · 几率 ×0.85
#     · 怪放的   → **增强版**：时长 **+1 手**（不按倍率——长条负面翻倍会压死人）· 几率 ×1.2（封顶 100%）
#   例：一门"中者「缴械」两手"的功法——玩家手上 **1 手**，怪手上 **3 手**；
#       "「破防」三手" 那种——玩家 **2 手**，怪 **4 手**。
#   钩子只有一处：两套引擎的 `_st_hit()` 里 `spec = St.tune(spec, 是玩家放的)`，
#   于是"武学 / 大招 / 词缀 / 特性 / 被动"所有上负面的路都走同一把尺。
#   ⚠ 想让某一条特殊（比如"毒"不算控制、别折太多），在 PASS_IDS 里点名豁免。
# ============================================================
const CTRL_KEYS := ["skip", "block_plain", "block_arts", "block_ult"]
const NERF_TURNS := 0.5          # 玩家：时长倍率
const NERF_CHANCE := 0.85        # 玩家：几率倍率
const FOE_EXTRA_TURNS := 1       # 怪：时长 **+N 手**（不按倍率——3 手 ×1.5 会变 5 手，太狠）
const FOE_CHANCE := 1.2          # 怪：几率倍率
const PASS_IDS: Array = []       # 豁免名单（点名的那几条两边同数）

static func is_ctrl(id: String) -> bool:
	var d: Dictionary = def_of(id)
	for k in CTRL_KEYS:
		if bool(d.get(k, false)):
			return true
	return false

# 把一份 apply 规格折成"这一侧该给的值"
static func tune(spec: Dictionary, by_player: bool) -> Dictionary:
	if spec.is_empty():
		return spec
	var sid := str(spec.get("id", ""))
	if sid == "" or def_of(sid).is_empty():
		return spec
	if not is_bad(sid) or PASS_IDS.has(sid):
		return spec                      # 正面 / 豁免：原样
	var d: Dictionary = def_of(sid)
	var out := spec.duplicate()
	var raw := int(spec.get("turns", 0))
	var base_t := raw if raw > 0 else int(d.get("turns", 2))
	var t := base_t
	var ch := float(spec.get("chance", 1.0))
	if by_player:
		t = maxi(1, int(ceil(float(base_t) * NERF_TURNS)))
		if is_ctrl(sid):
			out["stacks"] = 1
		if ch < 1.0:
			out["chance"] = snappedf(ch * NERF_CHANCE, 0.01)
	else:
		t = base_t + FOE_EXTRA_TURNS
		if ch < 1.0:
			out["chance"] = minf(1.0, snappedf(ch * FOE_CHANCE, 0.01))
	out["turns"] = t
	return out

# 面板上那一行（写**玩家手上**的值，括注敌人手上那一版）
static func apply_note(spec: Dictionary) -> String:
	if spec.is_empty():
		return ""
	var sid := str(spec.get("id", ""))
	if sid == "" or not is_bad(sid) or def_of(sid).is_empty():
		return ""
	var mine: Dictionary = tune(spec, true)
	var foe: Dictionary = tune(spec, false)
	var seg := name_of(sid) + " " + str(int(mine.get("turns", 0))) + " 手"
	if int(mine.get("stacks", 1)) > 1:
		seg += " ×" + str(int(mine.get("stacks", 1))) + " 层"
	if float(mine.get("chance", 1.0)) < 1.0:
		seg += "（" + str(int(round(float(mine.get("chance", 1.0)) * 100.0))) + "% 中）"
	var tail := "敌手上 " + str(int(foe.get("turns", 0))) + " 手"
	if int(foe.get("stacks", 1)) != int(mine.get("stacks", 1)):
		tail += " ×" + str(int(foe.get("stacks", 1))) + " 层"
	return "▸ 中者「" + seg + "」（" + tail + "）"

static func def_of(id: String) -> Dictionary:
	return S.get(id, {})

static func name_of(id: String) -> String:
	var d: Dictionary = def_of(id)
	return str(d.get("name", id)) if not d.is_empty() else id

static func col_of(id: String) -> Color:
	var d: Dictionary = def_of(id)
	return d.get("col", GREY) if not d.is_empty() else GREY

static func is_bad(id: String) -> bool:
	return bool(def_of(id).get("bad", true))

static func desc_of(id: String) -> String:
	return str(def_of(id).get("desc", ""))

# v54：小图标里那个字（一个汉字，一眼认得出是哪条）
static func glyph_of(id: String) -> String:
	var d: Dictionary = def_of(id)
	if d.is_empty():
		return "?"
	return str(d.get("glyph", name_of(id).substr(0, 1)))

# 给面板/说明用的一行总表
static func all_lines() -> Array:
	var out: Array = []
	for id in ORDER:
		out.append("「" + name_of(id) + "」" + desc_of(id))
	return out

# ---- 挂在单位身上 ----
# 单位字典里那一格：{"burn": {"n": 层, "t": 剩几手}, …}——**两套引擎存在同一个键名上**
const KEY := "status"

static func _bag(u: Dictionary) -> Dictionary:
	if not u.has(KEY):
		u[KEY] = {}
	return u[KEY]

static func has(u: Dictionary, id: String) -> bool:
	var b: Dictionary = u.get(KEY, {})
	return b.has(id) and int((b[id] as Dictionary).get("t", 0)) > 0

static func stacks(u: Dictionary, id: String) -> int:
	var b: Dictionary = u.get(KEY, {})
	if not b.has(id):
		return 0
	var e: Dictionary = b[id]
	return int(e.get("n", 0)) if int(e.get("t", 0)) > 0 else 0

# 上状态。turns 传 0 ＝ 用表里的默认时长。返回一句播报（空串＝没上上去）
# ⚠ v56：这个参数原来叫 `stacks`——跟本文件里的 `stacks()` 函数同名，Godot 会记一条
#   SHADOWED_GLOBAL_IDENTIFIER 告警（"parameter 'stacks' is shadowing an already-declared
#   function at line 160"）。改名 `layers`；调用方全是按位置传参，所以外面一个字都不用动。
static func apply(u: Dictionary, id: String, turns := 0, layers := 1, eb := 1.0) -> String:
	var d: Dictionary = def_of(id)
	if d.is_empty():
		# 数据里写错 id（或表里删了某条）时别静默——编辑器输出里留一行，好查
		if id != "" and not S.has(id):
			push_warning("[状态] 表里没有这个 id：" + id)
		return ""
	if u.is_empty():
		return ""
	var b := _bag(u)
	var t := turns if turns > 0 else int(d.get("turns", 2))
	var cap := maxi(1, int(d.get("max_stacks", 1)))
	var mode := str(d.get("stack_mode", "add"))
	var had := 0
	if b.has(id):
		had = int((b[id] as Dictionary).get("n", 0))
	var n := had
	if mode == "add":
		n = clampi(had + maxi(1, layers), 0, cap)
	else:
		# ⚠ "只刷新时长"那一档（缴械/沉默/封招…）**第一次上时字典里还没有这一格**——
		#   这里必须先判 has，不然头一次上状态就报 Invalid access（探针当场抓到的）
		n = maxi(1, had)
		if b.has(id):
			t = maxi(t, int((b[id] as Dictionary).get("t", 0)))
	# v58：印记**第一次叠到阈值**时把"爆过没有"清掉（层数回落再叠上来算新的一条命）；
	#   爆过之后 fired 留着，后续叠层不会二次爆——这就是"后续爆发不可叠加"。
	#   `eb`＝**上这一条的那一手的元素加成倍率**（用户："燃烧【吃火属性加成】"）——
	#   记在条目上，掉血与爆发都按它放大（记在条目而不是现算，是因为"谁上的"引擎那边不留）。
	var fired := false
	var kept_eb := eb
	var granted := 0
	if b.has(id):
		fired = bool((b[id] as Dictionary).get("fired", false))
		kept_eb = maxf(float((b[id] as Dictionary).get("eb", eb)), eb)
		granted = int((b[id] as Dictionary).get("sh", 0))
	b[id] = {"n": n, "t": t, "fired": fired, "eb": kept_eb, "sh": granted}
	var nm := name_of(id)
	if had > 0 and mode == "refresh":
		return "「" + nm + "」被续上（再 " + str(t) + " 手）"
	if had > 0 and n == had:
		return "「" + nm + "」已满层（" + str(n) + " 层 · 再 " + str(t) + " 手）"
	return "「" + nm + "」" + str(n) + " 层 · 再 " + str(t) + " 手"

static func clear(u: Dictionary) -> void:
	u[KEY] = {}

# ---- v53：驱散（净化）----
# **随机**洗掉身上至多 n 条**负面**（正面状态留着）。返回一句播报（空串＝本来就没有）。
#   ⚠ v54（用户："洗掉所有负面 改为随机一个"）：原来是从表头往后挑 n 条（等于"先洗固定那几种"），
#     现在改成**先随机挑、再洗**——n 默认 1（清心诀就是"洗掉身上随机一条负面"）。
#     所以它不保证洗得掉你最想洗的那条：身上挂着三条时，洗到「闭窍」的几率是三分之一。
#   ⚠ 两套引擎的"清心诀"都走这一口：谁身上的负面、洗掉几条，全由这里说了算。
static func cleanse(u: Dictionary, n := 1) -> String:
	var b: Dictionary = u.get(KEY, {})
	if b.is_empty():
		return ""
	var pool: Array = []
	for id in ORDER:
		if b.has(id) and is_bad(id) and int((b[id] as Dictionary).get("t", 0)) > 0:
			pool.append(id)
	if pool.is_empty():
		return ""
	pool.shuffle()
	var gone: Array = []
	for i in mini(maxi(1, n), pool.size()):
		var gid := str(pool[i])
		gone.append(name_of(gid))
		b.erase(gid)
	if gone.is_empty():
		return ""
	return "洗去「" + "」「".join(PackedStringArray(gone)) + "」"

# ============================================================
# v58 五行印记的**引擎面**（用户第 5 条）——两套引擎都只调下面这几个
#   分工：**数值全在这里算**（两套引擎算出来的数必须一模一样），引擎只负责"打给谁 + 飘字"。
# ============================================================

# ---- 护盾（岩甲）----
#   口径：护盾＝**额外生命值**，没打光之前不掉气血；每回合自然衰减 10%。
#   存在单位字典的 `shield` 键上（"满"值另记 `shield_max`，衰减按满值算更好懂）。
const SHIELD_KEY := "shield"
const SHIELD_MAX_KEY := "shield_max"
const SHIELD_DECAY := 0.10

static func shield_of(u: Dictionary) -> int:
	return maxi(0, int(u.get(SHIELD_KEY, 0)))

# 加一层护盾（按气血上限的比例）。返回实际加了多少
static func shield_add(u: Dictionary, hp_max: int, pct: float) -> int:
	var add := maxi(1, int(round(float(maxi(1, hp_max)) * pct)))
	u[SHIELD_KEY] = shield_of(u) + add
	u[SHIELD_MAX_KEY] = maxi(int(u.get(SHIELD_MAX_KEY, 0)), int(u[SHIELD_KEY]))
	return add

static func shield_set(u: Dictionary, v: int) -> void:
	u[SHIELD_KEY] = maxi(0, v)

# 每回合（每手）衰减 10%——按**当前值**衰减
static func shield_decay(u: Dictionary) -> int:
	var cur := shield_of(u)
	if cur <= 0:
		return 0
	var cut := maxi(1, int(round(float(cur) * SHIELD_DECAY)))
	u[SHIELD_KEY] = maxi(0, cur - cut)
	return cut

# 挨打：先扣护盾，剩下的才扣气血。返回 {"absorbed": 吸掉多少, "hp": 还要扣多少血}
static func shield_absorb(u: Dictionary, dmg: int) -> Dictionary:
	var cur := shield_of(u)
	if cur <= 0:
		return {"absorbed": 0, "hp": dmg}
	var ab := mini(cur, dmg)
	u[SHIELD_KEY] = cur - ab
	return {"absorbed": ab, "hp": dmg - ab}

# ---- 回血加成（寄生）----
#   与既有的 `heal_mul()`（封脉那条**削减**）**相乘**：先受削减、再吃加成
static func heal_up_mul(u: Dictionary) -> float:
	var m := 1.0
	for id in ORDER:
		var n := stacks(u, id)
		if n > 0:
			m += float(def_of(id).get("heal_up", 0.0)) * float(n)
	return maxf(0.1, m)

# 这一条印记挂上期间累计回了多少血（"吸血藤"按它算伤害）
const HEAL_ACC_KEY := "heal_acc"

static func heal_note(u: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	if stacks(u, "parasite") <= 0:
		return
	u[HEAL_ACC_KEY] = int(u.get(HEAL_ACC_KEY, 0)) + amount

static func heal_acc(u: Dictionary) -> int:
	return maxi(0, int(u.get(HEAL_ACC_KEY, 0)))

# ---- 夺取抗性（踏浪）----
#   夺取＝把**对手**的某元素抗性压下去（可压成负数），把夺来的那一份
#   **转成自己的该元素伤害加成 + 速度**。存在两边的 `res_shift` / `elem_gain` 上。
const RES_SHIFT_KEY := "res_shift"      # {元素: 百分点}（负＝抗性被打掉）
const ELEM_GAIN_KEY := "elem_gain"      # {元素: 百分点}（转成自己的元素伤害加成）
const SPD_GAIN_KEY := "spd_gain"        # 百分点（转成自己的速度）

static func res_shift(u: Dictionary, e: String) -> float:
	return float((u.get(RES_SHIFT_KEY, {}) as Dictionary).get(e, 0.0))

static func _res_shift_add(u: Dictionary, e: String, v: float) -> void:
	var d: Dictionary = u.get(RES_SHIFT_KEY, {})
	d[e] = float(d.get(e, 0.0)) + v
	u[RES_SHIFT_KEY] = d

# 踏浪：夺对手 burst_v×层 的水抗，转成自己的水增伤与速度
static func steal_res(stolen_from: Dictionary, gain_to: Dictionary, e: String, pct: float) -> Dictionary:
	_res_shift_add(stolen_from, e, -pct)
	var d: Dictionary = gain_to.get(ELEM_GAIN_KEY, {})
	d[e] = float(d.get(e, 0.0)) + pct * 100.0
	gain_to[ELEM_GAIN_KEY] = d
	gain_to[SPD_GAIN_KEY] = float(gain_to.get(SPD_GAIN_KEY, 0.0)) + pct * 100.0 * 0.5
	return {"res": -pct, "dmg_pt": pct * 100.0, "spd_pt": pct * 100.0 * 0.5}

static func elem_gain(u: Dictionary, e: String) -> float:
	return float((u.get(ELEM_GAIN_KEY, {}) as Dictionary).get(e, 0.0))

static func spd_gain(u: Dictionary) -> float:
	return float(u.get(SPD_GAIN_KEY, 0.0))

# ---- 爆发的伤害结算 ----
#   ctx（引擎传进来）：{"atk": 出手攻击, "hp_max": 上限}
#   返回 {"dmg": 总伤, "hits": [每一段的数], "lines": [给战报的句子], "elem": 属性,
#          "list": [{id,dmg,elem,lines,to}…]}
#   ⚠ `to` ＝ **这一发打谁**（引擎必须照它分派，别一律打对手）：
#       "self" ＝ 打在**身上挂着这一条的人**（燃烧/水浸这类负面：谁烧谁挨）
#       "foe"  ＝ 打在**他的对手**身上（鎏金/寄生/岩甲：自己攒的势，爆发打出去）
#     第一版没分这个，探针里"敌人身上的爆燃"直接把主角炸了 1613（探针当场抓到的）。
#   ⚠ 只在**这一条还没爆过**且层数 ≥ burst_at 时才算；算完立刻置 fired（不可叠加）
static func resolve_bursts(u: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var out := {"dmg": 0, "hits": [], "lines": [], "elem": "", "self_bursts": [], "list": []}
	var b: Dictionary = u.get(KEY, {})
	if b.is_empty():
		return out
	var hp_max := maxi(1, int(ctx.get("hp_max", 1)))
	var atk := maxf(0.0, float(ctx.get("atk", 0.0)))
	for id in MARKS:
		if not b.has(id):
			continue
		var need := burst_at(id)
		if need <= 0:
			continue
		var e: Dictionary = b[id]
		if bool(e.get("fired", false)):
			continue          # ← "后续爆发不可叠加"
		var n := int(e.get("n", 0))
		if n < need or int(e.get("t", 0)) <= 0:
			continue
		var d: Dictionary = def_of(id)
		var kind := str(d.get("burst_kind", ""))
		var v := float(d.get("burst_v", 0.0))
		# v58：爆发也吃"上这一条时那一手的元素加成"（用户："燃烧【吃火属性加成】"）
		var ebm := maxf(0.05, float(e.get("eb", 1.0)))
		var nm := str(d.get("burst", "爆发"))
		var el := str(d.get("elem", ""))
		# 打谁：负面＝打背着它的那个人；正面印记＝打他的对手
		var to := "self" if bool(d.get("bad", true)) else "foe"
		var amount := 0
		match kind:
			"fire_blast":
				amount = maxi(1, int(round(float(hp_max) * v * ebm)))
				(out["hits"] as Array).append(amount)
				out["dmg"] = int(out["dmg"]) + amount
				out["elem"] = el
				(out["lines"] as Array).append("「" + nm + "」" + str(n) + " 层火起——爆燃 " + str(amount))
			"metal_multi":
				var seg := maxi(1, int(d.get("burst_n", 3)))
				var one := maxi(1, int(round(atk * v * ebm)))
				for i in seg:
					(out["hits"] as Array).append(one)
				out["dmg"] = int(out["dmg"]) + one * seg
				out["elem"] = el
				amount = one * seg
				(out["lines"] as Array).append("「" + nm + "」金气化刃——" + str(seg) + " 段 ×" + str(one))
			"wood_from_heal":
				var acc := heal_acc(u)
				if acc <= 0:
					# 这一条挂上期间一口血都没回 —— 不爆（留着，等回血了再爆）
					continue
				amount = maxi(1, int(round(float(acc) * v * ebm)))
				(out["hits"] as Array).append(amount)
				out["dmg"] = int(out["dmg"]) + amount
				out["elem"] = el
				(out["lines"] as Array).append("「" + nm + "」藤蔓抽枝——按回血 " + str(acc) + " 打木伤 " + str(amount))
				u[HEAL_ACC_KEY] = 0
			"earth_from_shield":
				var sh := shield_of(u)
				if sh <= 0:
					continue
				amount = maxi(1, int(round(float(sh) * v * ebm)))
				(out["hits"] as Array).append(amount)
				out["dmg"] = int(out["dmg"]) + amount
				out["elem"] = "true"      # 用户："造成真实伤害"
				(out["lines"] as Array).append("「" + nm + "」岩层崩落——按护盾 " + str(sh) + " 打真实伤害 " + str(amount))
			"steal_water":
				# 不造成伤害：这一条由引擎把"夺来的东西"落到两边身上（见 steal_res）
				(out["self_bursts"] as Array).append(id)
				(out["lines"] as Array).append("「" + nm + "」水势翻卷——夺走对手水抗 " + str(int(v * 100.0 * n)) + "%")
				(out["list"] as Array).append({"id": id, "dmg": 0, "elem": el, "to": "self",
					"lines": (out["lines"] as Array).back()})
				_mark_fired(u, id)
				continue
			_:
				continue
		(out["list"] as Array).append({"id": id, "dmg": amount, "elem": el, "to": to,
			"lines": (out["lines"] as Array).back()})
		_mark_fired(u, id)
	return out

# ============================================================
# v58：**元素攻击按属性给印记**（用户第 5 条 + 追问口径）
#   火 → 对手挂「燃烧」 · 水 → 对手挂「水浸」
#   金 → 自己叠「鎏金」 · 木 → 自己叠「寄生」 · 土 → 自己叠「岩甲」
#   `eb` ＝ 这一手的元素加成倍率（掉血与爆发都按它放大）
#   返回 {"msg","side","id","name"}；空字典＝没上去（属性不对/表里没有）
# ============================================================
static func apply_elem_mark(attacker: Dictionary, target: Dictionary, elem: String, eb := 1.0) -> Dictionary:
	var id := mark_of_elem(elem)
	if id == "":
		return {}
	if attacker.is_empty() and target.is_empty():
		return {}
	var d: Dictionary = def_of(id)
	var on_foe := bool(d.get("bad", true))     # 负面＝打对手；正面印记＝叠自己
	var u: Dictionary = target if on_foe else attacker
	if u.is_empty():
		return {}
	var msg := apply(u, id, 0, 1, eb)
	if msg == "":
		return {}
	# 岩甲：上印记那一刻就按"层数 × 每层比例"给护盾（只补差额，刷新时不重复给）
	var sp := float(d.get("shield_pct", 0.0))
	if sp > 0.0:
		var hp_max := int(u.get("hp_max", u.get("max", 1)))
		var want := maxi(1, int(round(float(maxi(1, hp_max)) * sp))) * stacks(u, id)
		var b: Dictionary = u.get(KEY, {})
		var had := int((b[id] as Dictionary).get("sh", 0)) if b.has(id) else 0
		if want > had:
			shield_add(u, hp_max, float(want - had) / float(maxi(1, hp_max)))
			(b[id] as Dictionary)["sh"] = want
	return {"msg": msg, "side": ("foe" if on_foe else "self"), "id": id, "name": name_of(id)}

# 身上挂着几条负面（清心诀用得上，也能做"负面越多越疼"之类的后续设计）
#   ⚠ v58：正面印记（鎏金/寄生/岩甲）**不算**负面——它们不上"负面越多越疼"那条账
static func bad_count(u: Dictionary) -> int:
	var b: Dictionary = u.get(KEY, {})
	var n := 0
	for id in ORDER:
		if b.has(id) and is_bad(id) and int((b[id] as Dictionary).get("t", 0)) > 0:
			n += 1
	return n

# 每手开头结算：掉血 + 时长递减 + **护盾衰减** + **印记爆发**。
# 返回 {"dmg":掉了多少, "msgs":[…], "gone":[…], "shield_lost":护盾掉多少,
#        "burst": {dmg,hits,lines,elem,self_bursts}}（burst 的伤害由引擎单独飘字结算）
static func tick(u: Dictionary, hp_max: int, ctx: Dictionary = {}) -> Dictionary:
	var out := {"dmg": 0, "msgs": [], "gone": [], "shield_lost": 0, "burst": {}}
	# ⚠ hp_max 由本函数**自己塞进 ctx**——引擎调 tick(u, hp_max) 就不可能忘（探针第一版
	#   就是漏了 ctx，爆燃被按 hp_max=1 算成了 1 点）
	var c2 := ctx.duplicate(true)
	c2["hp_max"] = maxi(1, hp_max)
	ctx = c2
	var b: Dictionary = u.get(KEY, {})
	# v58：护盾每回合自然衰减 10%（**先衰减再算别的**，与说明文字一致）
	var sl := shield_decay(u)
	out["shield_lost"] = sl
	if sl > 0:
		(out["msgs"] as Array).append("护盾自然消减 -" + str(sl))
	if b.is_empty():
		# 没有状态也要把爆发算一遍（护盾那条已经回来了）
		out["burst"] = resolve_bursts(u, ctx)
		return out
	var dmg := 0
	var gone: Array = []
	for id in ORDER:
		if not b.has(id):
			continue
		var e: Dictionary = b[id]
		if int(e.get("t", 0)) <= 0:
			gone.append(id)
			continue
		var d: Dictionary = def_of(id)
		# v58：印记的掉血吃"上这一条时那一手的元素加成"（用户："燃烧【吃火属性加成】"）
		var dot := float(d.get("dot_pct", 0.0)) * float(int(e.get("n", 1))) * float(e.get("eb", 1.0))
		if dot > 0.0:
			var one := maxi(1, int(round(float(maxi(1, hp_max)) * dot)))
			dmg += one
			(out["msgs"] as Array).append(name_of(id) + " -" + str(one))
		e["t"] = int(e["t"]) - 1
		if int(e["t"]) <= 0:
			gone.append(id)
	for id2 in gone:
		b.erase(id2)
		(out["gone"] as Array).append(name_of(str(id2)))
	out["dmg"] = dmg
	# v58：印记爆发（叠到阈值且这一条还没爆过）——伤害**单独一段**交给引擎，
	#   免得跟"掉血"混在一起（掉血不吃减伤，爆发要走元素通道/飘字）
	out["burst"] = resolve_bursts(u, ctx)
	return out

# ---- 效果查询（引擎只调这几个）----
static func atk_mul(u: Dictionary) -> float:
	var m := 1.0
	for id in ORDER:
		var n := stacks(u, id)
		if n > 0:
			m += float(def_of(id).get("atk_pct", 0.0)) * float(n)
	return maxf(0.1, m)

static func taken_mul(u: Dictionary) -> float:
	var m := 1.0
	for id in ORDER:
		var n := stacks(u, id)
		if n > 0:
			m += float(def_of(id).get("taken_pct", 0.0)) * float(n)
	# v54：**全局规则**（用户："身上每挂一条负面，挨打就多受一点伤"）——
	#   按**条数**算（不是层数）：身上每多一条负面，挨打就多受一分伤（见下面的两个常量）。
	#   与「破防」那条叠加：破防是"某一条负面额外给 +30%/层"，这里是"条数本身"的底账。
	m += vuln_add(u)
	return maxf(0.1, m)

# 全局规则：身上挂着几条负面 → 挨打多受多少（比例）。0 条＝0
static func vuln_add(u: Dictionary) -> float:
	return minf(float(bad_count(u)) * PER_BAD_TAKEN, BAD_TAKEN_CAP)

# 面板/战报上那句附注（"受伤 +8%"）；没有负面＝空串
static func vuln_note(u: Dictionary) -> String:
	var v := vuln_add(u)
	if v <= 0.0:
		return ""
	return "受伤 +" + str(int(round(v * 100.0))) + "%"

static func spd_mul(u: Dictionary) -> float:
	var m := 1.0
	for id in ORDER:
		var n := stacks(u, id)
		if n > 0:
			m += float(def_of(id).get("spd_pct", 0.0)) * float(n)
	# v58：「踏浪」夺来的那一份转成自己的速度（百分点）
	m += spd_gain(u) / 100.0
	return maxf(0.1, m)

# v53：怒气获取（挫锐）
static func rage_mul(u: Dictionary) -> float:
	var m := 1.0
	for id in ORDER:
		var n := stacks(u, id)
		if n > 0:
			m += float(def_of(id).get("rage_pct", 0.0)) * float(n)
	return maxf(0.0, m)

# v53：回血倍率（封脉：0.7 ＝ 只回三成）。没状态＝1.0
#   v58：**「寄生」的加成并进这一口**——`heal_mul =（1 − 削减）×（1 + 加成）`。
#     这么改是为了"一处落地"：两套引擎一共有 7 个回血口，全都已经在调 `heal_mul()`，
#     并进来它们自动都吃到加成，不必去七个地方挨个乘一遍（漏一个就是"面板有、战斗没有"）。
#     纯加成那份仍可用 `heal_up_mul()` 单独读（面板/探针用）。
static func heal_mul(u: Dictionary) -> float:
	var m := 1.0
	for id in ORDER:
		var n := stacks(u, id)
		if n > 0:
			m -= float(def_of(id).get("heal_cut", 0.0)) * float(n)
	return clampf(m, 0.0, 1.0) * heal_up_mul(u)

# v53：技能冷却要加几手（滞涩）
static func cd_add(u: Dictionary) -> int:
	var n := 0
	for id in ORDER:
		var k := stacks(u, id)
		if k > 0:
			n += int(def_of(id).get("cd_add", 0)) * k
	return n

static func blocks_plain(u: Dictionary) -> bool:
	return _any(u, "block_plain")

static func blocks_arts(u: Dictionary) -> bool:
	return _any(u, "block_arts")

static func blocks_ult(u: Dictionary) -> bool:
	return _any(u, "block_ult")

# 闭窍：被动失效（敌方那侧＝词缀全灭）
static func blocks_passive(u: Dictionary) -> bool:
	return _any(u, "block_passive")

static func skips(u: Dictionary) -> bool:
	return _any(u, "skip")

static func _any(u: Dictionary, key: String) -> bool:
	for id in ORDER:
		if bool(def_of(id).get(key, false)) and stacks(u, id) > 0:
			return true
	return false

# v53：上状态那一刻的"立刻效果"——由引擎调（挫锐打怒气 / 滞涩推后当前冷却）
static func burst_rage_burn(u: Dictionary) -> int:
	var n := 0
	for id in ORDER:
		if stacks(u, id) > 0:
			n += int(def_of(id).get("rage_burn", 0)) * stacks(u, id)
	return n

# 身上状态那一行（战报/面板用）："燃烧2 · 缴械"；没有就空串
static func line(u: Dictionary) -> String:
	var seg: Array = []
	for id in ORDER:
		var n := stacks(u, id)
		if n <= 0:
			continue
		seg.append(name_of(id) + (str(n) if n > 1 else ""))
	return " · ".join(PackedStringArray(seg))

# 面板上那一行的小芯片（每一条一个 {name, col, stacks}）——画法交给面板
static func chips(u: Dictionary) -> Array:
	var out: Array = []
	for id in ORDER:
		var n := stacks(u, id)
		if n <= 0:
			continue
		out.append({"id": id, "name": name_of(id), "col": col_of(id), "n": n})
	return out
