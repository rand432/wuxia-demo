extends RefCounted
# ============================================================
# data_pets.gd —— 宠物名录 v3
# v3：①阶名收成**通用**的"幼年期…化形期"（每宠不再各起一套名）；
#   ②青隼改成**主加速度**（spd_pct），原来的四条阶效果（转速/警戒/运气）**去掉**；
#   ③白狐仍是护主（pct＝全队气血%）——两只各管一头：一只加血、一只加速；
#   ④血脉表扩到**四档**：凡品(1)/紫品(2)/金品(3)/绝品(4)；
#   ⑤宠物可**升星**（同名两只合星，照功法升星那一套：每星 +20%，见 GameState.pet_star_*）。
# 效果键（宠物/血脉共用）：
#   pct 护主(全队气血%) · spd_pct 速度% · bag_slots 携行格 · alert_cap 警戒上限 ·
#   alert_rate 警戒增速% · search_speed 转速% · search_luck 运气%
# ============================================================

# 通用阶名（0..4）
const STAGE_CN := ["幼年期", "成长期", "成熟期", "通灵期", "化形期"]

const PETS := {
	"fox": {
		"name": "白狐",
		"from": "后山",
		"pct": 3,             # 护主：全队气血 +3%（每阶再 +2）· v62：5 → 3（伤害/气血增幅减半那一批）
		"kind": "guard",
		"elem": "灵",
	},
	"qing_sun": {
		"name": "青隼",
		"from": "后山（二遭）",
		"spd_pct": 4,         # 主加成：全队速度 +4%（每阶再 +2）
		"kind": "utility",
		"elem": "风",
	},
}

# 每阶再给多少（与上面的 base 相加）——两只都只有"主加成"这一条，
# 阶效果（转速/警戒/运气那一批）按需求撤掉了
const STAGE_STEP := 2

# ---- 血脉表（四档：1 凡品 / 2 紫品 / 3 金品 / 4 绝品）----
# fx 键见文件头；实际值 = 基础 ×（0.5+资质/100）×（0.5+纯度/100）×（契合 ×1.5）
const BLOODS := [
	# v62（用户："先伤害增幅全部减半"）：血脉里"护主 pct"与"元素伤害增加 *_dmg"一律减半；
	#   功能性那几条（携行格/警戒/转速/运气/抗性）**没动**——它们不是伤害数值。
	#
	# v62c（用户："增加不同金色和紫色血脉 放入搜刮和货仓池 金色血脉在同品级也是极度稀有"）：
	#   ① 紫/金两档各添了几味，五味俱全（灵/风/水/炎/岩）都照顾到了；
	#   ② 每条血脉带 **`w`（同品级内部的权重，不写＝10）**——见 roll_blood 的加权挑；
	#   ③ **「玄黄血」金品里只有它 w=1**（其余金品都是 10）→ 同品级里也是极度稀有：
	#      摇到金品之后，约 **1/61** 才是它（金品本身已占 17.5%，合起来约千分之三）。
	#   新的这些**自动进搜刮与货仓**：两边都走 roll_blood(0) → 按档位权重抽，无需另接。
	# 凡品（1）——容易捡到的杂血
	{"id": "bl_shougu",  "name": "兽骨血",   "elem": "岩", "q": 1, "fx": {"bag_slots": 1, "earth_res": 3},  "desc": "山里野兽的底子，驮得多一点；皮糙，抗土"},
	{"id": "bl_shanye",  "name": "山野气",   "elem": "风", "q": 1, "fx": {"search_speed": 5, "metal_dmg": 2},  "desc": "跑惯山路的轻快，手里也带三分锐"},
	{"id": "bl_caoye",   "name": "草叶露",   "elem": "水", "q": 1, "fx": {"alert_rate": -5, "water_res": 3},  "desc": "气息淡，不惹眼；沾了水汽，耐水"},
	# 紫品（2）
	{"id": "bl_yusui",    "name": "玉髓血脉", "elem": "灵", "q": 2, "fx": {"pct": 2, "wood_dmg": 2},  "desc": "护主之力见于气血；木气生发，出手带木"},
	{"id": "bl_jifeng",   "name": "疾风翎",   "elem": "风", "q": 2, "fx": {"search_speed": 10, "metal_dmg": 3},  "desc": "身轻步快，翻找利索；翎如刀，金属性重"},
	{"id": "bl_xunbao",   "name": "寻宝纹",   "elem": "灵", "q": 2, "fx": {"search_luck": 8, "wood_res": 4},  "desc": "鼻子尖，闻得见好东西；木气护身"},
	{"id": "bl_fushan",   "name": "负山骨",   "elem": "岩", "q": 2, "fx": {"bag_slots": 1, "earth_res": 5},  "desc": "驮得多；背山的人，土性抗打"},
	{"id": "bl_qingxin",  "name": "清心露",   "elem": "水", "q": 2, "fx": {"alert_rate": -10, "water_res": 5},  "desc": "气息宁，少惹眼；水性耐寒"},
	# —— 紫品·新增四味（v62c）——
	{"id": "bl_tiegu",    "name": "铁骨血",   "elem": "岩", "q": 2, "fx": {"earth_res": 6, "bag_slots": 1},  "desc": "骨里带铁；扛得住，也驮得动"},
	{"id": "bl_liuyin",   "name": "流银血",   "elem": "金", "q": 2, "fx": {"metal_dmg": 3, "metal_res": 5},  "desc": "血里像淌着水银——出手带锐，也耐锐器"},
	{"id": "bl_huoyan",   "name": "火岩血",   "elem": "炎", "q": 2, "fx": {"fire_dmg": 3, "fire_res": 5},  "desc": "山口滚出来的热气；烫手，也不怕烫"},
	{"id": "bl_qingmu",   "name": "青木髓",   "elem": "灵", "q": 2, "fx": {"pct": 2, "wood_res": 5},  "desc": "春树上取的髓——护主，且木气护身"},
	# 金品（3）
	{"id": "bl_longxian", "name": "龙涎血",   "elem": "灵", "q": 3, "fx": {"pct": 3, "wood_dmg": 3},  "desc": "血脉里的护主之力（厚）；木气入招"},
	{"id": "bl_tianfeng", "name": "天风翼",   "elem": "风", "q": 3, "fx": {"search_speed": 18, "metal_dmg": 4},  "desc": "风一样的手脚；翼锋如刃，金属性更重"},
	{"id": "bl_zhuoyang", "name": "灼阳血",   "elem": "炎", "q": 3, "fx": {"pct": 3, "search_luck": 5, "fire_dmg": 4},  "desc": "烈性血脉——出手带火"},
	{"id": "bl_panshi",   "name": "磐石心",   "elem": "岩", "q": 3, "fx": {"bag_slots": 2, "earth_res": 8},  "desc": "四平八稳；土性厚，抗土极佳"},
	# —— 金品·新增三味（v62c）——
	{"id": "bl_liuli",    "name": "琉璃血",   "elem": "水", "q": 3, "fx": {"pct": 3, "water_dmg": 3, "water_res": 6},  "desc": "澄澈见底的一线水色；护主，且水火不侵"},
	{"id": "bl_jinyan",   "name": "金焰血",   "elem": "炎", "q": 3, "fx": {"fire_dmg": 5, "metal_dmg": 2},  "desc": "烧红的刀口——火里带金，两样一起上"},
	# ⚠ 金品里的"极度稀有"：同品级其余都是 w=10，只有它 w=1
	{"id": "bl_xuanhuang", "name": "玄黄血",  "elem": "岩", "q": 3, "w": 1, "fx": {"pct": 5, "earth_dmg": 5, "earth_res": 8},  "desc": "天地玄黄那一线厚土——护主之力与土性皆极，金品里也难碰上"},
	# 绝品（4）——极稀有：给"速度"和"警戒"两条留了顶级
	{"id": "bl_yufeng",   "name": "御风髓",   "elem": "风", "q": 4, "fx": {"spd_pct": 2, "metal_dmg": 5},  "desc": "风髓入体——出手快人一步，且金锐透骨"},
	{"id": "bl_longmai",  "name": "龙脉血",   "elem": "灵", "q": 4, "fx": {"pct": 5, "wood_dmg": 5, "wood_res": 6},  "desc": "护主之力（极厚）；木气同时护身与伤人"},
	{"id": "bl_wuxing",   "name": "无相血",   "elem": "水", "q": 4, "fx": {"alert_rate": -18, "water_res": 12, "water_dmg": 3},  "desc": "气息全无，走到跟前也不惊动；水性圆融，既耐水也伤水"},
]
# 同品级内部的权重：不写就是 10（只有"金品里那枚玄黄血"是 1）
const BLOOD_W_DEFAULT := 10

# 随缘掉落的档位权重（越往下越稀有）——紫品为主，绝品**极度稀有**
#   v62b（用户："红血脉也是极度稀有"）：原 `[34, 48, 16, 2]`（总 100，红＝2%）
#     → **`[68, 96, 35, 1]`（总 200，红＝0.5%）**：红血脉再稀四倍，
#     前三档的**相对比例基本照旧**（34%/48%/16% → 34%/48%/17.5%），只是红那一格掉了。
#     实测：一只金匮约出 0.5 枚血脉 → 红血脉约**每 200 只金匮**才一枚。
#   ⚠ 货栈那件「金纹血脉囊」走的是 `roll_blood(3)`（**指定金品**），不吃这张表——照旧。
const BLOOD_ROLL := [{ "q": 1, "w": 68 }, { "q": 2, "w": 96 }, { "q": 3, "w": 35 }, { "q": 4, "w": 1 }]

const FX_CN := {"bag_slots": "携行格", "alert_cap": "警戒上限", "alert_rate": "警戒增速", "search_speed": "转速", "search_luck": "运气", "pct": "护主", "spd_pct": "速度",
	# v58：五行那两条（用户："装备和血脉可以给一些了"）——键名与装备/角色面板同源
	"phys_dmg": "物理伤害增加", "all_dmg": "全伤害增加",
	"metal_dmg": "金元素伤害增加", "water_dmg": "水元素伤害增加", "wood_dmg": "木元素伤害增加",
	"fire_dmg": "火元素伤害增加", "earth_dmg": "土元素伤害增加",
	"metal_res": "金元素抗性", "water_res": "水元素抗性", "wood_res": "木元素抗性",
	"fire_res": "火元素抗性", "earth_res": "土元素抗性"}
const FX_ORDER := ["pct", "spd_pct", "bag_slots", "alert_cap", "alert_rate", "search_speed", "search_luck",
	# v58：五行排在最后（面板上先看老的那几条，再看新的）
	"all_dmg", "phys_dmg",
	"metal_dmg", "water_dmg", "wood_dmg", "fire_dmg", "earth_dmg",
	"metal_res", "water_res", "wood_res", "fire_res", "earth_res"]

static func of(pid: String) -> Dictionary:
	return PETS.get(pid, {})

static func name_of(pid: String) -> String:
	return str(of(pid).get("name", pid))

static func elem_of(pid: String) -> String:
	return str(of(pid).get("elem", ""))

static func elem_cn(e: String) -> String:
	if e == "":
		return "——"
	return e

# 通用阶名（各宠同一套）
static func stage_name_of(_pid: String, stage: int) -> String:
	return str(STAGE_CN[clampi(stage, 0, STAGE_CN.size() - 1)])

# 宠物的主加成（白狐＝护主 pct；青隼＝速度 spd_pct），带阶数增量
static func stage_fx_of(pid: String, stage: int) -> Dictionary:
	var d := of(pid)
	var out := {}
	var st := clampi(stage, 0, STAGE_CN.size() - 1)
	for k in ["pct", "spd_pct"]:
		if d.has(k):
			out[k] = int(d[k]) + st * STAGE_STEP
	return out

# ---- 血脉接口 ----

static func blood_of(bid: String) -> Dictionary:
	for b in BLOODS:
		if str(b.get("id", "")) == bid:
			return b
	return {}

static func blood_name(bid: String) -> String:
	return str(blood_of(bid).get("name", bid))

static func quality_cn(q: int) -> String:
	if q >= 4:
		return "绝品"
	if q >= 3:
		return "金品"
	if q >= 2:
		return "紫品"
	return "凡品"

# qual：0 = 随缘（按 BLOOD_ROLL 的权重抽档，越往下越稀有）；其它值 = 指定档位
static func roll_blood(qual := 0) -> String:
	var q := qual
	if q <= 0:
		var total := 0
		for e_v in BLOOD_ROLL:
			total += int((e_v as Dictionary).get("w", 0))
		var r := randi() % maxi(1, total)
		var acc := 0
		q = 2
		for e_v2 in BLOOD_ROLL:
			var e: Dictionary = e_v2
			acc += int(e.get("w", 0))
			if r < acc:
				q = int(e.get("q", 2))
				break
	var arr: Array = []
	var wt: Array = []
	for b in BLOODS:
		if int(b.get("q", 2)) == q:
			arr.append(str(b.get("id", "")))
			# v62c：同品级内部**加权**（不写 w 就是 10）——「玄黄血」w=1，所以金品里也极难碰上
			wt.append(maxi(1, int((b as Dictionary).get("w", BLOOD_W_DEFAULT))))
	if arr.is_empty():
		# 这一档没货就退回最近的档（别掉出个空）
		for b2 in BLOODS:
			arr.append(str(b2.get("id", "")))
			wt.append(BLOOD_W_DEFAULT)
	var total2 := 0
	for v in wt:
		total2 += int(v)
	var r2 := randi() % maxi(1, total2)
	var acc2 := 0
	for i in arr.size():
		acc2 += int(wt[i])
		if r2 < acc2:
			return str(arr[i])
	return str(arr[arr.size() - 1])

# ============================================================
# v62c（用户："商店卖的那个血脉变为随机 90%紫色 8.9%金色 0.1%红色"）
#   货栈那件「血脉囊」原来是 `roll_blood(3)`＝**指定金品**；现在改成按千分位摇档。
#   ⚠ 用户给的三个数**加起来是 99%**（90 + 8.9 + 0.1）——那 1% 的零头我并进**金**：
#     于是 紫 恰好 90.0% · 红 恰好 0.1%（两个头条数字精确），金 9.9%（含零头）。
#     想让零头归紫：把下面 `r < 990` 挪到 `r < 900` 那一段之前即可（紫就会变 91%）。
# ============================================================
static func roll_blood_pouch() -> String:
	var r := randi() % 1000
	if r < 900:
		return roll_blood(2)     # 900/1000 = 90.0% 紫
	if r < 999:
		return roll_blood(3)     # 99/1000 = 9.9% 金（8.9% ＋ 1% 零头）
	return roll_blood(4)         # 1/1000 = 0.1% 绝

static func fit_of(pid: String, bid: String) -> bool:
	var b := blood_of(bid)
	if b.is_empty():
		return false
	return str(b.get("elem", "")) == elem_of(pid)

# 实际效果：基础 ×（0.5+资质/100）×（0.5+纯度/100）×（契合 ×1.5）
static func blood_value(bid: String, pur: int, apt: int, fit: bool) -> Dictionary:
	var b := blood_of(bid)
	if b.is_empty():
		return {}
	var k := 1.0
	k *= 0.5 + float(clampi(apt, 0, 100)) / 100.0
	k *= 0.5 + float(clampi(pur, 0, 100)) / 100.0
	if fit:
		k *= 1.5
	var out := {}
	var base: Dictionary = b.get("fx", {})
	for key in base.keys():
		out[key] = int(round(float(base[key]) * k))
	return out

static func fx_text(fx: Dictionary) -> String:
	var arr: Array = []
	for k in FX_ORDER:
		if not fx.has(k):
			continue
		var v := int(fx[k])
		var s := str(FX_CN.get(k, k)) + " "
		s += ("+" + str(v)) if v >= 0 else str(v)
		if k != "bag_slots" and k != "alert_cap":
			s += "%"
		arr.append(s)
	return " · ".join(PackedStringArray(arr))

# 血脉预览/结算用：连"护主(pct)"一起显示
static func blood_fx_text(fx: Dictionary) -> String:
	var arr: Array = []
	for k in ["pct", "spd_pct", "bag_slots", "alert_cap", "alert_rate", "search_speed", "search_luck"]:
		if not fx.has(k):
			continue
		var v := int(fx[k])
		var s := str(FX_CN.get(k, k)) + " "
		s += ("+" + str(v)) if v >= 0 else str(v)
		if k != "bag_slots" and k != "alert_cap":
			s += "%"
		arr.append(s)
	return " · ".join(PackedStringArray(arr))
