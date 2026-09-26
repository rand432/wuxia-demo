extends Node
# ============================================================
# 通用数据表（纯数据，无逻辑）
# 用法：const GameData := preload("res://shared/game_data.gd")
#       GameData.MOVE_PROFILE / GameData.item_name(catalog, id)
# ============================================================

const Tuning := preload("res://shared/tuning.gd")   # ㊿：攻速规则的旋钮

const MAX_HP_DEFAULT := 80

# ㊼：多人上场时，副手按首领的比例折算（血量与攻击同用这两个数）。
#   出村战斗(battle_lite)、游历决斗(duel_battle)、离线爬塔估算(tower) 三处都读这一份——
#   以前三处各写一个 0.6/0.4，改了容易漏。本文件不 preload 任何东西，谁都能引。
const FOE_MID_RATIO := 0.6
const FOE_BACK_RATIO := 0.4

# 一关的"总血池倍数"：首领 3 人（本体＋中排＋后排）、精英 2 人、杂兵 1 人。
#   离线估算要按这个乘上去，不然首领关的血池少算一半。
static func foe_hp_scale(boss: bool, elite: bool) -> float:
	if boss:
		return 1.0 + FOE_MID_RATIO + FOE_BACK_RATIO
	if elite:
		return 1.0 + FOE_MID_RATIO
	return 1.0

# ============================================================
# v46：敌人也讲站位——**前排肉 / 中排均衡 / 后排高伤**
#   用户："爬塔和游历的怪…可以跟站位一样 前排肉后排伤害高，boss 也可以有特定怪物——
#         伤害高的 boss 后排，肉盾 boss 前排，花样可以多一点。这样苏的作用也明显下来。"
#
#   · 每一档的折算（相对那一关的基准属性）：
#       前排：血厚、攻击低（盾手——挡在前面，你先把血啃掉）
#       中排：中庸
#       后排：血薄、攻击高（杀手——打得疼，但不经打）
#   · ⚠ **整组的总血池与总攻击跟旧口径一模一样**（见 `foe_row_plan` 归一）：
#       旧表是"本体 1.0 ＋ 中排 0.6 ＋ 后排 0.4"（血攻同用），现在只是把这份总账
#       **重新分给三个位置**，所以难度不变、离线估算（foe_hp_scale）也不用动，
#       变的只有"谁站在前面、先打谁、谁最疼"。
#   · 站位型（`foe_archetype`）决定**首领/精英自己**站哪一排，副手补剩下的位置——
#       肉盾首领站前排、高伤首领躲后排（想先斩他得靠"打后排"的武学或苏青鸾这种绕前排的人）。
# ============================================================
const FOE_ROWS := [
	{"cn": "前排", "sub": "盾手", "hp": 1.00, "atk": 0.42, "def": 1.35},
	{"cn": "中排", "sub": "刀手", "hp": 0.62, "atk": 0.62, "def": 1.05},
	{"cn": "后排", "sub": "杀手", "hp": 0.38, "atk": 0.96, "def": 0.75},
]

# 这一组的"站位型"：0 肉盾（自己站前排）· 1 均衡（站中排）· 2 高伤（躲后排）
#   由关号/节点序号现算——**同一关重打看到的是同一套**（挂机估算与手动打才对得上）。
static func foe_archetype(seed_i: int) -> int:
	return posmod(int(seed_i) / 2, 3)

static func foe_row_cn(row: int) -> String:
	return str(FOE_ROWS[clampi(row, 0, FOE_ROWS.size() - 1)]["cn"])

static func foe_row_sub(row: int) -> String:
	return str(FOE_ROWS[clampi(row, 0, FOE_ROWS.size() - 1)]["sub"])

static func foe_archetype_cn(arch: int) -> String:
	match clampi(arch, 0, 2):
		0:
			return "肉盾（站前排）"
		1:
			return "均衡（站中排）"
	return "高伤（躲后排）"

# 一组的站位安排：返回 [{"main": bool, "row": 0/1/2}, ...]，
#   **按前排→后排排好**（下标即排号——两套战斗的 _row_of 都是"下标即排号"）。
static func foe_layout(count: int, arch: int) -> Array:
	var a := clampi(arch, 0, 2)
	if count <= 1:
		return [{"main": true, "row": 1}]      # 单人：站中排（归一之后＝原样，属性一点不变）
	if count == 2:
		# 两人关：本体站哪一排就照哪种型（前排＝肉盾首领 / 中排＝均衡 / 后排＝高伤躲后面）
		if a == 0:
			return [{"main": true, "row": 0}, {"main": false, "row": 1}]
		if a == 1:
			return [{"main": false, "row": 0}, {"main": true, "row": 1}]
		return [{"main": false, "row": 0}, {"main": true, "row": 2}]
	if a == 0:
		return [{"main": true, "row": 0}, {"main": false, "row": 1}, {"main": false, "row": 2}]
	if a == 1:
		return [{"main": false, "row": 0}, {"main": true, "row": 1}, {"main": false, "row": 2}]
	return [{"main": false, "row": 0}, {"main": false, "row": 1}, {"main": true, "row": 2}]

# 一组敌人的站位折算（跟 foe_layout 的结果一一对应）：把 FOE_ROWS 的形状
#   **归一**到那一组的老口径总账（foe_hp_scale）——所以"整组强度"不变。
static func foe_row_plan(rows: Array) -> Array:
	var n := rows.size()
	var budget := foe_hp_scale(n >= 3, n == 2)
	var hp_sum := 0.0
	var atk_sum := 0.0
	for r in rows:
		var p: Dictionary = FOE_ROWS[clampi(int(r), 0, FOE_ROWS.size() - 1)]
		hp_sum += float(p["hp"])
		atk_sum += float(p["atk"])
	var hs := budget / maxf(0.001, hp_sum)
	var as_ := budget / maxf(0.001, atk_sum)
	var out: Array = []
	for r2 in rows:
		var p2: Dictionary = FOE_ROWS[clampi(int(r2), 0, FOE_ROWS.size() - 1)]
		out.append({
			"hp": float(p2["hp"]) * hs,
			"atk": float(p2["atk"]) * as_,
			"def": float(p2["def"]),
		})
	return out

# ============================================================
# v47：**单人关的"体型"**——一只怪也该有性格
#   用户："单人关是什么？…可以 你看着来"
#   背景：清关里 **88% 是单人关**（杂兵关：每 10 关 1 个精英、每 25 关 1 个首领），
#   而前排/后排那套站位只在 2 人以上的关里起作用——那 88% 的关一直是"一只怪顶在最前面"，
#   苏青鸾绕前排、带 target: back/mid 的武学在那儿等于白带。
#
#   所以给单人关也摇一个体型（**每关轮换**，同一关重打永远是同一个）：
#     肉盾：血厚、打得轻 —— 拖得住就赢，怕的是你输出不够
#     寻常：标准身板（原来那套，一点没动）
#     高伤：打得疼、不经打 —— 先手、先控、先回气值钱
#   ⚠ **血 × 攻 的乘积保持不变**（1.15×0.88 ≈ 1.012、0.86×1.16 ≈ 0.998）：
#     难度大致不动，变的只是"这一关该怎么打"。
#   ⚠ 离线挂机估算**知道这件事**：见下面的 foe_stage_scale——两处读同一口，
#     不然挂机算出来的关卡数会跟手动打的对不上（这一条是刻意的，别绕过它）。
# ============================================================
const FOE_SOLO := [
	{"cn": "肉盾", "hp": 1.15, "atk": 0.88, "def": 1.15, "desc": "血厚、打得轻"},
	{"cn": "寻常", "hp": 1.00, "atk": 1.00, "def": 1.00, "desc": "标准身板"},
	{"cn": "高伤", "hp": 0.86, "atk": 1.16, "def": 0.88, "desc": "打得疼、不经打"},
]

# 单人关的体型：按关号每关轮换（0 肉盾 → 1 寻常 → 2 高伤 → 0 …）
static func foe_solo_type(i: int) -> int:
	return posmod(int(i), FOE_SOLO.size())

static func foe_solo_profile(i: int) -> Dictionary:
	return FOE_SOLO[foe_solo_type(i)]

static func foe_solo_cn(i: int) -> String:
	return str(FOE_SOLO[foe_solo_type(i)]["cn"])

# 这一关的**血量 / 攻击倍数**（整关总账）——真战斗与离线估算读同一口：
#   多人关＝站位表已保证总账＝foe_hp_scale；单人关＝再乘体型那一份。
static func foe_stage_scale(i: int, boss: bool, elite: bool) -> Dictionary:
	var base := foe_hp_scale(boss, elite)
	if boss or elite:
		return {"hp": base, "atk": base}
	var p: Dictionary = foe_solo_profile(i)
	return {"hp": base * float(p["hp"]), "atk": base * float(p["atk"])}

# ============================================================
# ㊿：速度 → 攻速（额外普攻）· 两套战斗共用这一份
#
# 「快过对手一倍」＝每手多打一下**普通攻击**；快过两倍＝多打两下，到此为止。
#   比值 2.0~2.99 → +1 下；3.0 及以上 → +2 下（上限 ATKSPD_MAX_EXTRA）。
#   武学与大招不吃这条——它们有自己的冷却/怒气在管。
#
# 为什么放在这里：出村战斗（battle_lite）与游历决斗（duel_battle）都要用，
#   放两份迟早走岔。本文件不 preload 任何东西、tuning 也是，所以谁都能引。
#
# ⚠ 两边必须用同一把尺子比：村里角色 9~12、出村怪 9~28 都是 10 量级；
#   游历敌人的表是 100 量级，所以 duel_battle._foe_spd() 里先折回 10 量级。
# ============================================================


static var ATKSPD_MIN_RATIO := Tuning.num("combat", "atkspd_min_ratio", 2.0)
static var ATKSPD_MAX_EXTRA := Tuning.intv("combat", "atkspd_max_extra", 2)

# 这手能多打几下普攻（0 = 不快，照常一手）
static func extra_attacks(my_spd: float, foe_spd: float) -> int:
	if foe_spd <= 0.0 or my_spd <= 0.0:
		return 0
	var ratio := my_spd / foe_spd
	if ratio < ATKSPD_MIN_RATIO:
		return 0
	return clampi(int(floor(ratio)) - 1, 0, ATKSPD_MAX_EXTRA)

# 一句话说明（战报/浮字用）；不快就是空串
static func atkspd_word(my_spd: float, foe_spd: float) -> String:
	var n := extra_attacks(my_spd, foe_spd)
	if n <= 0:
		return ""
	return "身法快出一截——再补 " + str(n) + " 下"


# ============================================================
# v35：防御 / 闪避接成活属性（口径：**数值对数值**，不做成"减伤百分比"字段）
#
# 为什么要"对拼"而不是固定减伤：往后要加**攻击类型**（物理／内功／穿刺…），
#   每种类型跟防御的算法会不一样；所以现在只把两个**数值**摆在一起比，
#   公式收在这一处，将来按类型分叉就在这儿加分支。
#
#   · 防御：挨打那一方挡掉的比例 = 防 / (攻 + 防)
#       攻 ＝ 出手那一下的攻击值（玩家＝面板攻击；敌人＝它自己的 atk）
#       防 ＝ 挨打那一方的防御值
#     例：敌攻 12 打 你防 5 → 挡 29%；你防 19（一套极品）→ 挡 61%；
#         你攻 114 打 敌防 10 → 只挡 8%（攻高就是压得住）。
#     ⚠ 这是"值"的比，不是"率"的比：攻防谁大谁说话，没有"减伤 20%"这种字段。
#   · 闪避：闪避率 = 我闪避 / (我闪避 + 对手命中)，对手命中 = 基准 + 对手速度×2
#       基准 100 只是两套数值之间的**尺子零点**（闪避 5~40、速度 9~110 同量级）。
#     例：闪避 5（光板）对速度 10 的怪 → 4%；披风拉满 + 升星（闪避 30）→ 20%。
#   两套战斗（battle_lite 出村 / duel_battle 游历）与离线估算(tower)都读这几个口，
#   所以"面板上写的"和"打起来算的"永远是同一把尺子。
# ============================================================
const DEF_CUT_CAP := 0.75        # 一次最多挡掉七成半（留个下限，不至于完全打不动）
const DODGE_HIT_BASE := 100.0    # 命中基准（尺子零点）
const DODGE_SPD_W := 2.0         # 对手速度换算成命中：越快越难闪
const DODGE_CAP := 0.45          # 闪避率上限（四成半）
const FOE_DEF_RATIO := 0.5       # 敌人没写 def 时：按攻击折一半

# 挡掉的比例（0 ~ DEF_CUT_CAP）
static func def_cut(attack: float, defense: float) -> float:
	if attack <= 0.0 or defense <= 0.0:
		return 0.0
	return clampf(defense / (attack + defense), 0.0, DEF_CUT_CAP)

# 这一手打过来，被防御削掉之后还剩多少（至少 1）
static func after_def(raw: float, attack: float, defense: float) -> int:
	return maxi(1, int(round(raw * (1.0 - def_cut(attack, defense)))))

# 闪避率（0 ~ DODGE_CAP）：对手越快越难闪
static func dodge_rate(dodge: float, foe_spd: float) -> float:
	if dodge <= 0.0:
		return 0.0
	var hit := DODGE_HIT_BASE + maxf(0.0, foe_spd) * DODGE_SPD_W
	return clampf(dodge / (dodge + hit), 0.0, DODGE_CAP)

# 敌人的防御值：表里写了就用（given），没写按攻击折一半
static func foe_def(atk: float, given := 0.0) -> int:
	if given > 0.0:
		return int(round(given))
	return maxi(0, int(round(atk * FOE_DEF_RATIO)))

const DIR_NAMES := {
	"north": "北",
	"south": "南",
	"east": "东",
	"west": "西",
}

# 每招的冲步档案：
#   delay 起手等待(秒) / dist 冲步距离(像素) / time 冲步耗时 / y 下沉(正)或上浮(负)
#   push 击退倍率 / back 收步耗时(不写=0.35)
const MOVE_PROFILE := {
	"chop":         {"delay": 0.42, "dist": 105.0, "time": 0.50, "y": 6.0,  "push": 1.3},
	"cut":          {"delay": 0.40, "dist": 85.0,  "time": 0.42, "y": 0.0,  "push": 1.0},
	"slice":        {"delay": 0.40, "dist": 65.0,  "time": 0.30, "y": -4.0, "push": 0.9},
	"stab":         {"delay": 0.42, "dist": 210.0, "time": 0.16, "y": 10.0, "push": 1.9},
	"sweep":        {"delay": 0.45, "dist": 95.0,  "time": 0.45, "y": 8.0,  "push": 1.2},
	"dual_chop":    {"delay": 0.30, "dist": 110.0, "time": 0.22, "y": 6.0,  "push": 1.4},
	"dual_alt":     {"delay": 0.22, "dist": 130.0, "time": 0.28, "y": 2.0,  "push": 1.0,  "back": 0.50},
	"dual_thrust":  {"delay": 0.25, "dist": 195.0, "time": 0.14, "y": 8.0,  "push": 1.8},
	# v57 补：普攻表里有、档案里缺的两条（原来是走"兜底 0.35/120/0.25/1.0"，
	#   手感跟别的招不一路）；数值按同系相邻招推的：双撩上撩（dist 短、y 负）· 推掌（比直拳远一点、慢一点）
	"dual_rip":     {"delay": 0.24, "dist": 145.0, "time": 0.20, "y": -6.0, "push": 1.2},
	"fist_palm":    {"delay": 0.22, "dist": 150.0, "time": 0.18, "y": 4.0,  "push": 1.4},
	"dagger_slash": {"delay": 0.16, "dist": 130.0, "time": 0.14, "y": 2.0,  "push": 0.9},
	"dagger_stab":  {"delay": 0.14, "dist": 245.0, "time": 0.12, "y": 4.0,  "push": 1.5,  "back": 0.45},
	"dagger_flurry":{"delay": 0.10, "dist": 255.0, "time": 0.10, "y": 5.0,  "push": 1.2,  "back": 0.60},
	"spear_thrust": {"delay": 0.30, "dist": 220.0, "time": 0.15, "y": 10.0, "push": 1.9},
	"spear_multi":  {"delay": 0.22, "dist": 205.0, "time": 0.14, "y": 8.0,  "push": 1.7,  "back": 0.45},
	"spear_turn":   {"delay": 0.55, "dist": 240.0, "time": 0.16, "y": 10.0, "push": 2.2},
	"fist_punch":   {"delay": 0.24, "dist": 170.0, "time": 0.14, "y": 6.0,  "push": 1.2},
	"fist_combo":   {"delay": 0.18, "dist": 190.0, "time": 0.16, "y": 4.0,  "push": 1.0,  "back": 0.50},
	"fist_kick":    {"delay": 0.22, "dist": 90.0,  "time": 0.30, "y": 0.0,  "push": 1.3},
	# v57：暗器三招（原"棍"三招：棒喝/扫棍/踢 → 飞掷/连掷/踢）
	"anqi_throw":   {"delay": 0.34, "dist": 150.0, "time": 0.20, "y": 6.0,  "push": 1.5},
	"anqi_rain":    {"delay": 0.40, "dist": 120.0, "time": 0.34, "y": 8.0,  "push": 1.3},
	"anqi_kick":    {"delay": 0.26, "dist": 35.0,  "time": 0.35, "y": 0.0,  "push": 1.2},
}

# 连击补刀：命中后再补几下剑光与踉跄（不产生新的伤害数字）
const EXTRA_HITS := {
	"dual_chop": 1, "dual_alt": 4, "dual_thrust": 1,
	"dagger_slash": 1, "dagger_stab": 3, "dagger_flurry": 5,
	"spear_thrust": 1, "spear_multi": 3, "spear_turn": 0,
	"fist_punch": 0, "fist_combo": 5,
}

# 战斗中按 1~5 依次预览当前武器的招式
const WEAPON_MOVES := {
	"sword":  ["chop", "cut", "slice", "stab", "sweep"],
	"dual":   ["dual_chop", "dual_alt", "dual_thrust"],
	"dagger": ["dagger_slash", "dagger_stab", "dagger_flurry"],
	"spear":  ["spear_thrust", "spear_multi", "spear_turn"],
	"anqi":   ["anqi_throw", "anqi_rain", "anqi_kick"],
	"fist":   ["fist_punch", "fist_combo", "fist_kick"],
}

# 招式弹字
const MOVE_NAMES := {
	"chop": "劈", "cut": "砍", "slice": "削", "stab": "刺", "sweep": "扫",
	"dual_chop": "双劈", "dual_alt": "乱斩", "dual_rip": "双撩", "dual_thrust": "双刺",
	"dagger_slash": "横抹", "dagger_stab": "贴身刺", "dagger_flurry": "乱刃",
	"spear_thrust": "直刺", "spear_multi": "连刺", "spear_turn": "回身刺", "spear_lift": "挑",
	"anqi_throw": "飞掷", "anqi_rain": "连掷", "anqi_kick": "踢",
	"fist_punch": "直拳", "fist_combo": "连环快拳", "fist_kick": "侧踹", "fist_palm": "推掌",
}

# 武器名兜底（正式名以服务器下发的 catalog 为准）
const WEAPON_NAMES := {
	"sword": "长剑", "dual": "双刀", "dagger": "匕首",
	"spear": "长枪", "anqi": "暗器", "fist": "空手",
}

# ============================================================
# ㊱ 招式的作用范围（"打谁"）——写在招式上的特殊效果
#
# 站位的基本规矩是"普攻只打最前排"。**招式能越过它是特殊效果**，
# 所以要一招一招写明，而不是"所有技能都够到中排"（那一版太随意，已撤）。
#
# 招数字典里写 "target": "mid" / "sweep"；不写＝"front"（照基本规矩，只打最前排）。
#   写在 desc 里给玩家看的说法，也用下面这张表统一。
# ============================================================
const TARGETS := {
	"front": {"cn": "对前排敌人造成伤害", "reach": 0},
	"mid":   {"cn": "对中排敌人造成伤害", "reach": 1},
	"back":  {"cn": "对后排敌人造成伤害", "reach": 2},
	"sweep": {"cn": "对群体造成伤害", "reach": 2},   # 群伤：每一排都够得着
	# ㊿：加持类（不伤人，给**自己人**上状态）——单开一套键，免得跟上面那套混用。
	#   我方站位＝名册顺序：0 前、1 中、末位 后（两场战斗同一条规矩：_row_of = 下标）。
	"ally_front": {"cn": "加持前排（最前面那位）", "reach": 0},
	"ally_mid":   {"cn": "加持中排（中间那位）", "reach": 1},
	"ally_back":  {"cn": "加持后排（最后面那位）", "reach": 2},
	"ally_all":   {"cn": "加持全队", "reach": 2},
}

# 招式的够到排号（0/1/2）；sweep 视作够到最后一排
static func target_reach(t: String) -> int:
	var d: Dictionary = TARGETS.get(t, TARGETS["front"])
	return clampi(int(d.get("reach", 0)), 0, 2)

static func target_cn(t: String) -> String:
	var d: Dictionary = TARGETS.get(t, TARGETS["front"])
	return str(d.get("cn", ""))

# 把"打谁"补进招式说明里——非默认（front）才加，免得说明行全被塞满
static func move_desc(a: Dictionary) -> String:
	var base := str(a.get("desc", ""))
	# v48：多段武学把"几段"写在说明里（不然"一击 ×0.42"看着像弱得没道理）
	var hs := clampi(int(a.get("hits", 1)), 1, 3)
	if hs >= 2:
		base += "｜" + str(hs) + " 段，每段 ×" + str(a.get("mult", 1.0))
	var t := str(a.get("target", "front"))
	if t == "front" or t == "":
		return base
	var cn := target_cn(t)
	if cn == "":
		return base
	return base + "｜" + cn

static func item_name(catalog: Dictionary, id: String) -> String:
	if id == "" or id == "none":
		return "无"
	if catalog.has(id):
		var info: Dictionary = catalog[id]
		return str(info.get("name", id))
	return str(WEAPON_NAMES.get(id, id))

static func move_color(move_id: String) -> Color:
	match move_id:
		"chop", "dual_chop", "anqi_throw":
			return Color(1.0, 0.85, 0.45)
		"cut", "dual_alt", "fist_combo", "dagger_slash", "fist_punch":
			return Color(1.0, 0.95, 0.75)
		"slice", "dual_rip", "spear_lift", "fist_palm":
			return Color(0.75, 1.0, 0.8)
		"stab", "dual_thrust", "dagger_stab", "dagger_flurry", "spear_thrust", "spear_multi", "spear_turn":
			return Color(0.7, 0.95, 1.0)
		"sweep", "anqi_rain":
			return Color(1.0, 0.75, 0.6)
		"anqi_kick", "fist_kick":
			return Color(1.0, 0.95, 0.85)
		_:
			return Color(1.0, 0.85, 0.45)

# 倒地方式：tumble 旋转角度（负=向前扑） / time 倒下耗时
static func fall_style(weapon: String) -> Dictionary:
	match weapon:
		"dual":
			return {"tumble": 86.0, "time": 0.65}
		"dagger":
			return {"tumble": 66.0, "time": 0.60}
		"fist":
			return {"tumble": -72.0, "time": 0.62}
		"spear":
			return {"tumble": 20.0, "time": 0.50}
		_:
			return {"tumble": 24.0, "time": 0.50}
