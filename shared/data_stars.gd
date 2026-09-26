extends RefCounted
# ============================================================
# data_stars.gd —— 角色星（命座 / 星魂排布）· 唯一真源
#
# 排布（照原神命座 / 崩铁星魂的骨架，但把"大件"的位置对齐参考物）：
#   1 数值 · 2 机制 · 3 数值 · 4 专属被动加强 · 5 数值 · 6 大招加强
#   顺序解锁（不能跳级）——跟命座/星魂一样，"先给哪一级"本身是设计权。
#   为什么这么排：
#     · **机制放第 2 星**——碎片掉得慢（游历红件一次 1 片、1/3 概率轮到某人），
#       多数人长期停在 2~3 星；第 2 星就给一条新玩法，低星投资才有感觉。
#     · **大件在 4 与 6**——原神 C4/C6、崩铁 E4/E6 就是"核心机制/大招"那两格
#       （提纳里 C6 多一支绽放箭 · 崩铁 E6 大招段数 +2），所以被动与大招压在这一头。
#     · 数值散在 1/3/5，每一级手感都不一样（不像"连着两级纯数值"那么平）。
#
# ⚠ 三套 fx 词汇，**单位与落点都不一样，千万别混**（这是本项目最容易踩的坑）：
#   "stat" 组 → 走**五问天赋**那一套：整数＝百分点（12 就是 +12%）
#              键：dmg / hp_pct / crit / dodge / def / spd / dmg_cut / art_dmg …
#              落点：battle_lite._build_party、run_state.talent_fx_of、
#                    GameState.formation_dps_est —— 这三处本来就在应用 tfx
#   "mech" 组 → 走**运签卡**那一套：小数＝比例（0.30 就是 +30%）
#              键：ult_dmg / ult_dur / follow_hits / passive_up / art_cd_minus /
#                  open_rage / thorn_up / vengeance / art_any_weapon / rage_on_hit /
#                  crit_low_pct / crit_mul_up …
#              落点：battle_lite._build_party 的成员字段 + RunState.buff_fx 合并
#   "grow" 组 → **成长**那一套（v38 新增）：整数＝"每级多涨几点气血"
#              键：hp_grow
#              落点：**只被 GameState.level_gain 读**（升级时现算）——
#                    不进战斗、不进面板的八行属性。拿到这条星时还会**补课**：
#                    已过的级数按新成长一次性补上（见 GameState.hp_grow_sync）。
#   ⚠ 别在 stat 组里写小数、也别在 mech 组里写 "12"——单位错一位就是 100 倍。
#   ⚠ 两个**例外**，它们的单位写在名字里，别照 mech 组的小数习惯写：
#        crit_low_pct  → 百分点（30 就是 +30 个百分点；引擎里的 crit 本来就是 5~30 这种数）
#        rage_on_hit   → 点数（15 就是每次挨打 +15 怒气；怒气满值 100）
#        crit_mul_up   → 比例（0.5 就是暴击倍率 ×1.5）
#
# ㊿y2：「暴击伤害」现在是**真属性**了（以前两套引擎都写死 1.6 倍、crit_dmg 是死字段）：
#   暴击倍率 = 1.0 + 面板上的暴击伤害/100，再乘角色星的 crit_mul_up。
#   默认值 50 → 1.5 倍（原来是写死的 1.6 ✗ 现在按属性走 ✓）。
#   想让手感回到 1.6：把三个模板的 "crit_dmg" 与 STAT_DEFAULTS 一起改成 60。
#
# 规矩（定数值时遵守，免得把三条老线盖掉）：
#   · 不给速度（spd / spd_pct）——普攻额外出手按速度比跳档，星一加速度手感会突变，
#     离线估算也跟着跳（见 game_data.extra_attacks）
#   · 数值级只用**两套引擎都读得到**的键：dmg / hp_pct / crit / dmg_cut / def / dodge / crit_dmg
#     （v48 更正：以前这里写着"出村战斗不读闪避/防御/暴击伤害"——**早就读了**：
#      battle_lite 建队时把 tfx 的 def/dodge/crit_dmg 都并进成员身上了；
#      而弟子面板以前一个都不显示，v48 起 panel_stats 也折进来，面板与战斗一致）
#   · 大招级要看这个人**大招是什么形状**：瞬发群攻只能用 ult_dmg；
#     aura/song 那两种才有 ult_dur / follow_hits 可加
#   · 六级全开约等于"多一件好装备"，不是多一个人
#   · 材料只吃**角色碎片** + 银两；碎片产出慢，表要小
# ============================================================

const MAX := 6

# 谁的星吃哪种碎片（与 GameState.FRAGMENT_CN 同一个键）
const FRAG := {
	"player": "frag_player",
	"chen_shi": "frag_chen",
	"qingluan": "frag_qing",
}

# ㊿z5：满星礼——各人的**专武功法**（id 见 shared/data_cards.gd 的 art_ex_*）
#   专武是 no_drop：游历/爬塔/首领赏都不出，唯一的来路就是"这个人升到满星"。
#   （改专武只改这一张对照表 + data_cards 里那一门。）
const EXCLUSIVE_ART := {
	"player": "art_ex_changfeng",
	"chen_shi": "art_ex_tiebi",
	"qingluan": "art_ex_duange",
}

static func exclusive_art(rid: String) -> String:
	return str(EXCLUSIVE_ART.get(rid, ""))

# v40（用户定的**测试版**来路）：引子下山通关后，仓库里多一只「新手关卡礼包」，
#   按关号分**三次**开：
#     第 50 关 → 少侠（长风诀）· 第 150 关 → 陈石（铁壁桩功）· 第 300 关 → 苏青鸾（短歌行）
#   ⚠ 这是**测试期的发法**（正式来路以后再定）；三门 `art_ex_*` 都是 no_drop，
#     除了这里就只有"满星礼"那条（目前还关着）。改发放点只改下面这张表。
const EXCLUSIVE_STAGE := [
	{"stage": 50, "role": "player"},
	{"stage": 150, "role": "chen_shi"},
	{"stage": 300, "role": "qingluan"},
]

static func exclusive_stage_line() -> String:
	var arr: Array = []
	for e in EXCLUSIVE_STAGE:
		var d: Dictionary = e
		arr.append(str(int(d.get("stage", 0))) + " 关→" + str(ROLE_CN.get(str(d.get("role", "")), "?")))
	return " / ".join(PackedStringArray(arr))

# 第 n 星要几片（下标 0 占位，"升到 1 星"要 60 片）。
# v36（用户定）：原来是 [0,1,1,2,3,5,8]（满星才 20 片），而红件一次只掉 1 片——
#   "几十次搜刮就满星"，星变成零钱而不是目标 → 改成翻倍表，碎片成了**主资源**。
# v45（用户："角色升星 为 60/120/180/240/300/360"）：翻倍表 → **每星 +60 的平表**，
#   满星共 **1260 片**（原 3780）。配套红件碎片从"一次一把 10 片"改成 **2~5 片**
#   （data_loot.FRAG_PER_DROP = [2, 5]）——两个数一起动，攒星节奏大致不变，
#   但**曲线平了**：不会出现"第 6 星要 1920 片"那种断崖。
#   满星 ≈ **360 次红件拾取**（按平均 3.5 片/次算）。
#   ⚠ 只动碎片；银两那条仍是逐星翻倍（STAR_SILVER，满星 18900 两/人）。
const STAR_FRAG := [0, 60, 120, 180, 240, 300, 360]

# 第 n 星的银两（吃"妙手"折扣：GameState.player_talent_cost_mul）
# v45（用户："要压平"）：逐星翻倍 [0,300,600,1200,2400,4800,9600]（满星 18900）→
#   **每星 +300 的平表**，满星共 **6300 两/人**（三人 18900）。碎片同轮砍到 1/3
#   （STAR_FRAG 满星 1260），银两不压平的话它会变成升星的主要门槛。
const STAR_SILVER := [0, 300, 600, 900, 1200, 1500, 1800]

const ROLE_CN := {"player": "少侠", "chen_shi": "陈石", "qingluan": "苏青鸾"}

# ---- 十八级内容 ----
# v62（用户："不少属性增幅都太大了 数值膨胀太快 装备都没作用了 先伤害增幅全部减半"）：
#   角色星这一条线原是最大的一头（少侠满星＝伤害 +48% ＋ 气血 +48%，比五件装备加起来还高），
#   所以按同一条尺子处理：**伤害/气血这类百分比增幅一律减半**、暴击率 ×0.7（暴击是"几率"不是"幅度"）。
#   机制类（无视兵器要求 / 被动强化 / 怒气 / 手数 / 被动加强）**一个没动**——那些是玩法，不是纯数值。
# 每一项：{"name": 星名, "desc": 面板/日志上的一句话, "stat": {...}, "mech": {...}}
#   位置规矩：1/3/5 ＝ 数值（stat）· 2 ＝ 机制 · 4 ＝ 被动加强 · 6 ＝ 大招加强
#   stat 可省（没有纯数值收益时）；mech 可省。两者都有＝"数值+机制"那种收尾级。
const STARS := {
	"player": [
		{"name": "锐气", "desc": "出手伤害 +4%", "stat": {"dmg": 4}},
		# 机制：武学宗师——换兵器也使出原本倍率（原本"不趁手"只出 off_mult 那点）
		{"name": "武学宗师", "desc": "无视武学的兵器要求——不趁手也使出原本倍率（不再只出三分火候）", "mech": {"art_any_weapon": 1}},
		{"name": "体魄", "desc": "气血上限 +6%", "stat": {"hp_pct": 6}},
		{"name": "引气", "desc": "被动「引气归元」效果 +50%（怒气 +30% → +45%）", "mech": {"passive_up": 0.5}},
		{"name": "眼力", "desc": "暴击 +3%", "stat": {"crit": 3}},
		# 大招级：他的「长风破浪」是瞬发群攻（没有持续手数），所以只能加伤害与起手怒气
		{"name": "破浪", "desc": "大招伤害 +15%，且开场怒气 +30", "mech": {"ult_dmg": 0.15, "open_rage": 30}},
	],
	"chen_shi": [
		{"name": "厚土", "desc": "气血上限 +6%", "stat": {"hp_pct": 6}},
		# 机制：铁桩——受击回怒（不到自己出手，怒气也往上走）。⚠ 单位是**比例**：0.15＝+15%
		{"name": "铁桩", "desc": "受击也涨怒气（每次挨打 +15%）——挨得越多，枪势来得越快", "mech": {"rage_on_hit": 0.15}},
		{"name": "铁骨", "desc": "受到伤害 -3%", "stat": {"dmg_cut": 3}},
		# v61（用户："移除被动增幅的气血成长"）：原来这一格还挂了一条 grow{hp_grow: 2}
		#   （"每级再多涨 2 点气血"）——已**删掉**，只留"被动强化 +50%"。
		#   想恢复：把 "grow": {"hp_grow": 2} 加回来即可（代码那套补课机制还都在）。
		{"name": "稳桩", "desc": "被动「扎马稳桩」效果 +50%（减伤 6% → 9%）", "mech": {"passive_up": 0.5}},
		{"name": "磐石", "desc": "气血上限再 +5%", "stat": {"hp_pct": 5}},
		# 大招级：枪势是 aura（有手数），所以能加持续
		{"name": "回马", "desc": "枪势再 +1 手，反刺再 +15%", "mech": {"ult_dur": 1, "thorn_up": 0.15}},
	],
	"qingluan": [
		{"name": "轻灵", "desc": "暴击 +3%", "stat": {"crit": 3}},
		# 机制：猎影——对手残血时暴击 +30
		{"name": "猎影", "desc": "对手气血不足一半时，暴击 +21%", "mech": {"crit_low_pct": 21}},
		{"name": "明眸", "desc": "出手伤害 +3%", "stat": {"dmg": 3}},
		{"name": "淬锋", "desc": "被动「剑走轻灵」效果 +50%（暴击 15% → 22%）", "mech": {"passive_up": 0.5}},
		# 数值级里的这一格：凝息 = 暴击伤害 +50%（乘在"1.0 + 暴伤/100"上）
		{"name": "凝息", "desc": "暴击伤害 +18%——暴伤 50 时：1.5 倍变 1.77 倍", "mech": {"crit_mul_up": 0.18}},
		# 大招级：剑歌是 song（有手数 + 追剑）
		{"name": "出岫", "desc": "剑歌 +1 手，且追剑再 +1 段", "mech": {"ult_dur": 1, "follow_hits": 1}},
	],
}

static func is_star_role(rid: String) -> bool:
	return STARS.has(rid)

static func levels(rid: String) -> Array:
	return STARS.get(rid, [])

static func level_entry(rid: String, lv: int) -> Dictionary:
	var arr: Array = levels(rid)
	if lv < 1 or lv > arr.size():
		return {}
	var d: Dictionary = arr[lv - 1]
	return d

static func star_name(rid: String, lv: int) -> String:
	return str(level_entry(rid, lv).get("name", ""))

static func star_desc(rid: String, lv: int) -> String:
	return str(level_entry(rid, lv).get("desc", ""))

static func frag_key(rid: String) -> String:
	return str(FRAG.get(rid, ""))

# 升到第 lv 星要几片（lv 从 1 数到 MAX；越界返回 0）
static func cost_frag(lv: int) -> int:
	if lv < 1 or lv >= STAR_FRAG.size():
		return 0
	return int(STAR_FRAG[lv])

static func cost_silver(lv: int) -> int:
	if lv < 1 or lv >= STAR_SILVER.size():
		return 0
	return int(STAR_SILVER[lv])

# ---- 前 lv 级的 fx 合并（面板、战斗、估算都读这两个口）----

static func stat_fx(rid: String, lv: int) -> Dictionary:
	var out: Dictionary = {}
	var arr: Array = levels(rid)
	for i in mini(maxi(lv, 0), arr.size()):
		var d: Dictionary = arr[i]
		var s: Dictionary = d.get("stat", {})
		for k in s.keys():
			out[k] = float(out.get(k, 0.0)) + float(s[k])
	return out

static func mech_fx(rid: String, lv: int) -> Dictionary:
	var out: Dictionary = {}
	var arr: Array = levels(rid)
	for i in mini(maxi(lv, 0), arr.size()):
		var d: Dictionary = arr[i]
		var s: Dictionary = d.get("mech", {})
		for k in s.keys():
			out[k] = float(out.get(k, 0.0)) + float(s[k])
	return out

# v38：grow 组（成长）——前 lv 级合并。整数：hp_grow = 每级多涨几点气血。
#   ⚠ 只给 level_gain 用；别把它并进 tfx（那是"战斗里的一次性加成"，两回事）
static func grow_fx(rid: String, lv: int) -> Dictionary:
	var out: Dictionary = {}
	var arr: Array = levels(rid)
	for i in mini(maxi(lv, 0), arr.size()):
		var d: Dictionary = arr[i]
		var s: Dictionary = d.get("grow", {})
		for k in s.keys():
			out[k] = float(out.get(k, 0.0)) + float(s[k])
	return out

# 面板上那一行"下一级给什么"
static func next_line(rid: String, cur: int) -> String:
	if cur >= MAX:
		return "已满星（" + str(MAX) + " 星）"
	var d := level_entry(rid, cur + 1)
	if d.is_empty():
		return ""
	return "下一星【" + str(d.get("name", "")) + "】：" + str(d.get("desc", ""))
