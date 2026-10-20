extends RefCounted

const Loot := preload("res://shared/data_loot.gd")   # 只为读 red_phase（相位系数要用）

# ============================================================
# data_appraise.gd —— 鉴宝行 · 唯一真源（v39）
#
# 用户的设计：
#   · **400 关剧情**：船上打捞上来一只货仓——锈迹斑斑但保存完好，看不出是什么。
#     这段剧情本身就是**新手引导**：教玩家"未知货仓可以先用道具研究，再决定买不买"。
#   · 解锁的**鉴宝行**里，用**银两**买不同的未知货仓。
#   · 买之前可以用**道具侦查**（三样，见 TOOLS）：
#       描影镜 → 显示**一件最高价值**道具的轮廓
#       透物灯 → **随机几件**的完整轮廓
#       识宝鉴 → 拿到**一件**物品的完整信息
#   · 买下之后的货仓内容＝**搜刮那一套东西，只是爆率更高**（见 data_loot.roll_salvage）。
#   · 类似"俱乐大玩家"那类：**信息本身就是要花的东西**——先侦查、再下手。
#
# ⚠ 后续会加**联机**：所以"一只货仓"是**一条独立数据**（档位＋内容＋已侦查的格子，
#   见 GameState.appraise_offers）——以后要做"几个人凑钱开同一只"或"把货仓晒给别人看"，
#   把这几个字段同步出去就行，不用重做数据形状。**别把内容散进各个面板里**。
# ============================================================

# 解锁关号（与 GameState.STORY_JIANBAO_STAGE 同一个数——那边是"剧情"，这边是"货仓档位"）
const UNLOCK_STAGE := 400

# ---- 货仓档位 ----
# price 是**基价**（相位 0 的价）；真实价格＝基价 × 这一档在这个相位的系数（见 PHASE_MUL_BY_TIER）。
# 定价尺子（**v59 重测**）：**回本率 87~90%**——每一档都是"花银两换东西"的**轻微亏本**买卖，
#   越贵的仓好东西越多、亏得一样多（口径是 v56 定下的，本轮沿用）。
#   永远不到 100%，所以它不是一个印钞机，而是"银两 → 稀缺货"的兑换口。
#   ⚠ 以后动 `data_ladder`（行权重 / 色偏移 / 格数 / 填充）或卡价、丹价，**必须重跑探针重量**：
#     量"每档每相位 3000 仓的平均估值"，再除以 0.88 回填下面的 price。
#   ⚠ 旧字段 `slots` / `full_mul` / `junk_floor` / `q_add` / `q_cap` / `red_max` **全部退休**
#     （它们是 v56 那套 roll_salvage 的参数，代码里已经没有一处读它们了）。
#     v56 那轮"每档 slots 各 +1 把回本率顶回设计带"的说法也随之作废。
const HOLDS := [
	# ============================================================
	# v59（本轮）：**价格与格数是探针实测标定的**（每档每相位 3000 仓）。
	#   标定口径仍是 v56 那条：**估值回本率 ≈ 88%**（"花银两换稀缺货"的轻微亏本买卖）。
	#   tier  ＝ 档位序（0~4）→ 对应 data_ladder.TIER_CAP：
	#           0 最高紫 · 1 最高金 · 2 最高小红 · 3 最高中红 · 4 最高大红
	#   cells ＝ 这只仓一共几格（**盘上摆几件＝账上真几件**，见 roll_hold 的真格子摆放）
	#   luck  ＝ 好货率：越大越往"上限那一行"偏
	#   phase ＝ 货色相位闸（游历难度首通每 8 次升一段）：没到就不摆上架
	#   实测（相位 0 基准良品，每档 2500 仓的**平均估值** · rare 权重减半之后重量的）：
	#     木箱 501 · 漆箱 1463 · 铜锁 8090 · 银扣 11304 · 金匮 15053
	#   ⚠ v59c（用户："木箱800-1000 漆箱 1800 → 2110"）：前两档的价**按用户给的价带定**，
	#     不再守 88%——木箱 **900**（800~1000 取中）、漆箱 **1950**（1800~2110 取中）。
	#     代价是回本率掉下来（实测）：木箱 **55%** · 漆箱 **76%**
	#     （铜锁以上没动，仍在 87~91%）。
	#     想让前两档也回到 88%，只有"把货加厚"这一条路（不改价）：木箱 24 → 38 格、
	#     漆箱 36 → 56 格（cells 一个数的事）；要"价在这条带上、货还不薄"就得那样配。
	# ============================================================
	{"id": "wood", "name": "木箱货仓", "price": 1300, "cells": 24, "luck": 1.0, "tier": 0, "phase": 0,
		"desc": "最普通的木箱，钉子都锈了——**最高只出到紫档**"},
	{"id": "lacq", "name": "漆箱货仓", "price": 2700, "cells": 36, "luck": 2.2, "tier": 1, "phase": 0,
		"desc": "漆皮还亮的箱子——**最高到金档**，件数与成色都比木箱好一截"},
	{"id": "bronze", "name": "铜锁货仓", "price": 12500, "cells": 52, "luck": 3.0, "tier": 2, "phase": 1,
		"desc": "铜锁扣得严实——**开始出红货，但只到「小红」**（占 1~2 格的那些）"},
	{"id": "silver", "name": "银扣货仓", "price": 18000, "cells": 68, "luck": 3.8, "tier": 3, "phase": 2,
		"desc": "银扣压边的大仓——**红货到「中红」**（残功法 6 格、残兵器装备 4 格那些）"},
	{"id": "gold", "name": "金匮货仓", "price": 23500, "cells": 84, "luck": 4.6, "tier": 4, "phase": 3,
		"desc": "金皮包角的匮子——**「大红」也出得来**：完整功法 10 格、完整兵器装备 8 格"},
]
# 相位闸：`phase` 用 `ladder_phase()` 比——只有货色到了那一档，贵仓才会露面。
# ============================================================
# v56（用户："我第一次买货仓 1000 多银两的，直接给了完整的功法吗？如果是残页倒是还好。
#   运气这么好，还是完整功法的爆率高？如果是后者，降低。设置：货仓的价格决定了该仓库的爆率，
#   当然也有可能出垃圾的"）
#
#   · **价格决定爆率**——这一条 v59 换了落点：现在由 `tier`（最高抽到哪一色）
#     ＋ `cells`（几格）＋ `luck`（往上限那一头偏多少）三个数决定，
#     全在 `data_ladder` 那张唯一的表里。v56 那两个参数（`full_mul` 完整件倍率 /
#     `junk_floor` 垃圾保底）连同它们赖以生效的 `roll_salvage` **一起退休了**。
#     "贵仓也照样能翻出废纸"这条仍然成立——它现在是"fillter 占几格"与"行权重"的结果。
# ============================================================
# v50：`cells` ＝ 这只货仓**一共几格**（画格子区用）。
#   ⚠ 它**不在店里写着**（用户："给好几个货仓就给名字和价格，也不写多少格"）——
#     想知道有几格得花道具（下面的「数格尺」）。所以这张表是"给系统看的"，
#     面板上**只准写名字与价格**。

# 相位系数：仓里的货按**当下品级**定价，推到后面这些货值钱得多，而价要是写死，
#   前期买的仓到后期就成了白送的。所以价格**按当下相位现算**——
#   口径与货栈残卡一口价同源（都用 `Cards.PRICE_MUL` 那一套品级系数）。
# v58（用户："货仓银两从1000起步吧"）：当时把这一列全改成 1.0＝不按相位加价。
# v59：**恢复相位加价**——这一版阶梯的货色**随相位涨得很厉害**（大红行从"红货摇不出来"
#   到"摇得出"、完整件从良品一路升到绝品），实测同一只仓的平均估值（每档每相位 3000 仓）：
#     相位 0 → 1 → 2 → 3 → 4 ＝ 1.00 → 1.00 → 1.15 → 1.45 → 1.76 倍（五档平均）
#   ⚠ **一个系数盖不住五个档位**：便宜的仓涨得快（木箱 2.24 倍）、贵的仓涨得慢（金匮 1.5 倍），
#     共用一条的话相位 4 时木箱要白送 35%。所以下面**每档一条**（实测值，逐个量出来的）——
#     这样"回本率 88%"在每个档、每个相位上都成立（探针验过）。
# v59b：**稀有权重减半（rare 2→1）之后重量了一遍**。实测（每档每相位 2500 仓）：
#   相位 0 → 1 → 2 → 3 → 4 ＝ 1.00 → 1.00 → **1.18** → **1.51** → **1.90** 倍（五档平均）
#   ⚠ 一个系数盖不住五个档位：便宜的仓涨得快（木箱 2.55 倍）、贵的仓涨得慢（金匮 1.5 倍），
#     共用一条的话相位 4 时木箱要白送 40%。所以下面**每档一条**（实测值，逐个量出来的）——
#     这样"回本率 88%"在每个档、每个相位上都成立（探针验过）。
const PHASE_PRICE_MUL := [1.0, 1.0, 1.18, 1.51, 1.90]      # 兜底（表里没写 id 的档用它）

const PHASE_MUL_BY_TIER := {
	"wood":   [1.0, 1.0, 1.26, 1.75, 2.55],
	"lacq":   [1.0, 1.0, 1.29, 1.86, 2.58],
	"bronze": [1.0, 1.0, 1.02, 1.19, 1.40],
	"silver": [1.0, 1.0, 1.13, 1.34, 1.47],
	"gold":   [1.0, 1.0, 1.20, 1.40, 1.49],
}

static func phase_price_mul(phase: int) -> float:
	var i := clampi(phase, 0, PHASE_PRICE_MUL.size() - 1)
	return float(PHASE_PRICE_MUL[i])

# 这一档在**这个相位**的加价（先查每档那条，没写就退回共用那条）
static func hold_phase_mul(hid: String, phase: int) -> float:
	var row: Array = PHASE_MUL_BY_TIER.get(hid, [])
	if row.is_empty():
		return phase_price_mul(phase)
	return float(row[clampi(phase, 0, row.size() - 1)])

# ---- 货色相位（谁来决定"贵仓露不露面"）----
#   由 `GameState` 每次铺货前同步一手（＝`GameState.ladder_phase()`：游历难度首通每 8 次
#   升一段，0~4）。**为什么不直接读 `Loot.red_phase`**：那个静态量只在开趟/搜刮时才被写，
#   刚进游戏就点鉴宝行会读到 0（于是贵仓全都不出来、价格也按相位 0 算）。
static var phase_now := -1

static func sync_phase(p: int) -> void:
	phase_now = clampi(p, 0, 4)

static func cur_phase() -> int:
	return Loot.red_phase if phase_now < 0 else phase_now

# 这一档**现在**卖多少（面板与扣款都走这一口，免得两处各算一遍）
static func hold_price_now(hid: String, phase := -1) -> int:
	var d := hold_def(hid)
	if d.is_empty():
		return 0
	var p := phase
	if p < 0:
		p = cur_phase()
	return maxi(1, int(round(float(d.get("price", 0)) * hold_phase_mul(hid, p))))

# ---- 侦查道具 ----
# kind 三样各管一段信息（由浅到深）：
#   "best"  只标出**最值钱那一件**的轮廓（告诉你"这一仓里有硬货"）
#   "many"  随机几件给**完整轮廓**（看出是什么类的东西、几格、什么成色——仍不给名字）
#   "one"   给**一件**的完整信息（名字、加成、估值——但不知是第几格？不，认得出的那一格）
# count 一次用掉几个（都 1）· price 货栈卖价 · limit 货栈每日限购
#
# v50（用户："解锁鉴宝后 商店卖限购的鉴定道具（效果较强的价格也贵）；同时增加一个可以
#   显示当前仓库多少格子（较贵）和显示所有紫色轮廓 和显示所有金色轮廓 和显示所有绿色轮廓等
#   （不同类型的道具）"）——**新增两个族**：
#     · kind "slots" ← **数格尺**：量出这只货仓一共几格（较贵）。
#       平时店里**不写格数**，所以这是"要不要下手"的第一道信息。
#     · kind "tier"  ← 四把"筛子"：把该成色的货**全部**标成轮廓（绿/紫/金/红各一把）。
#       tier 字段＝要筛的档（1 绿 / 2 紫 / 3 金 / 4 红，口径见 data_loot.tier_of）。
#   价钱按"效果强弱"排：绿色筛最便宜（绿货最多、信息最不值钱），朱砂筛最贵。
const TOOLS := [
	{"id": "sight", "name": "描影镜", "kind": "best", "price": 170, "limit": 3,
		"desc": "照出货仓里最值钱的一件"},
	{"id": "lamp", "name": "透物灯", "kind": "many", "price": 280, "limit": 2,
		"desc": "照出两三件货的轮廓"},
	{"id": "seal", "name": "识宝鉴", "kind": "one", "price": 450, "limit": 2,
		"desc": "看清一件货的详情"},
	{"id": "count", "name": "数格尺", "kind": "slots", "price": 590, "limit": 2,
		"desc": "量出货仓的格数"},
	{"id": "sift_g", "name": "碧砂筛", "kind": "tier", "tier": 1, "price": 220, "limit": 3,
		"desc": "标出全部绿档货"},
	{"id": "sift_p", "name": "紫霞筛", "kind": "tier", "tier": 2, "price": 420, "limit": 2,
		"desc": "标出全部紫档货"},
	{"id": "sift_j", "name": "金纹筛", "kind": "tier", "tier": 3, "price": 870, "limit": 2,
		"desc": "标出全部金档货"},
	{"id": "sift_r", "name": "朱砂筛", "kind": "tier", "tier": 4, "price": 1500, "limit": 1,
		"desc": "标出全部红档货"},
]
const TOOL_ORDER := ["sight", "lamp", "seal", "count", "sift_g", "sift_p", "sift_j", "sift_r"]

static func hold_def(hid: String) -> Dictionary:
	for h in HOLDS:
		if str(h.get("id", "")) == hid:
			return h
	return {}

static func hold_name(hid: String) -> String:
	var d := hold_def(hid)
	return str(d.get("name", hid)) if not d.is_empty() else hid

static func hold_price(hid: String) -> int:
	# ⚠ 这是**基价**（相位 0 的价）。要"现在卖多少"用 hold_price_now。
	return int(hold_def(hid).get("price", 0))

static func tool_def(tid: String) -> Dictionary:
	for t in TOOLS:
		if str(t.get("id", "")) == tid:
			return t
	return {}

static func tool_name(tid: String) -> String:
	var d := tool_def(tid)
	return str(d.get("name", tid)) if not d.is_empty() else tid

# 一次买仓能挑到哪几档：**越贵的仓越少露面**（按抽签权重）
#   ⚠ v59：**换成新的五档 id**。原来那张表还挂着 9 个**已经退休的旧档 id**
#   （rust/sealed/lacquer/iron/sandal/jade/dragon）——`hold_def()` 找不到 → 返回 {} →
#   兜底又写死 "rust" → 铺货直接铺出空档，"一只仓都没有"。这是换档时最容易漏的一处。
const HOLD_WEIGHT := {"wood": 40, "lacq": 26, "bronze": 12, "silver": 6, "gold": 2}
const FALLBACK_HOLD := "wood"

# 贵仓要不要露面，看**货色相位**（＝`ladder_phase()`：游历难度首通每 8 次升一段）。
#   表里每档写了 `phase`：货色没到那一档就不进池（前期不会看见七千两的仓）。
static func holds_at(phase: int) -> Array:
	var out: Array = []
	for h in HOLDS:
		if int(h.get("phase", 0)) <= phase:
			out.append(h)
	return out

static func roll_hold_id(phase := -1) -> String:
	var p := phase
	if p < 0:
		p = cur_phase()
	var pool: Array = holds_at(p)
	if pool.is_empty():
		var fb := hold_def(FALLBACK_HOLD)
		pool = [fb] if not fb.is_empty() else []
	var total := 0
	for h_v in pool:
		var h: Dictionary = h_v
		total += int(HOLD_WEIGHT.get(str(h.get("id", "")), 1))
	if total <= 0:
		return FALLBACK_HOLD
	var r := randi() % total
	for h_v2 in pool:
		var h2: Dictionary = h_v2
		r -= int(HOLD_WEIGHT.get(str(h2.get("id", "")), 1))
		if r < 0:
			return str(h2.get("id", FALLBACK_HOLD))
	return FALLBACK_HOLD

# 一次摆几只仓给人挑
const OFFER_N := 3
# 买走一只之后隔多久补一只（秒）——先是"立刻补"，留着这个数是为了以后想加冷却
const REFILL_SEC := 0.0

# 侦查给几件（透物灯）：2~3 件
static func lamp_count() -> int:
	return randi_range(2, 3)
