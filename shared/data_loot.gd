extends RefCounted
# ============================================================
# data_loot.gd —— 搜索数据表 v13（杂物银两下修：上品碎玉 1440 → 200）
# v13（用户："杂物的银两是不是太多了 我看到一个紫色品质的碎玉价值一千多银两"）：
#   只动**杂物**这一条线（JUNKS 的 base ＋ 品质/格数两张系数表），货仓银两、店价、
#   残卡/折现价、塔收益一个字没动。新旧对照与"想再调改哪儿"写在 JUNKS 上面那段。
# 与《已粘贴的文本(109)》逐字一致，除：_make_red 里重复的 card_gear/card_buff
# 两组分支只留一组；RED_WEIGHT 删 "card_buff"（增益卡不上红件，来源＝卡组面板＋
# 精英三抽）；器具残片 card_gear 照旧。其余不动。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const DataPets := preload("res://shared/data_pets.gd")
# v59：掉落阶梯（6 行 × 4 色的唯一一张表）——搜刮与货仓共用。
#   ⚠ 方向是**单向**的：这里 preload 阶梯，阶梯里只在**运行时** load 本文件（`_filler`），
#     所以不成环（阶梯不能 preload 本文件）。
const Ladder := preload("res://shared/data_ladder.gd")

static var red_phase := 0

static func set_red_phase(p: int) -> void:
	red_phase = clampi(p, 0, Cards.QUALITY_ORDER.size() - 1)

const CONTAINERS := {
	# v59：`tier` ＝ 这只容器**最高抽到哪一档色**（口径与货仓的 tier 完全一样，见 data_ladder）：
	#   0 最高紫 · 1 最高金 · 2 最高小红 · 3 最高中红 · 4 最高大红。
	#   路上随手翻的（尸体/包袱/石缝/木箱/药篓）只到紫；柜子枯井到金；**密柜也是到金**——
	#   "见红"那一下交给下面 `red` 那一掷（中了才临时升到**小红**），
	#   不然密柜会变成"9% 概率直接给一颗绝品突破丹"的印钞口（探针实测过）。
	# `gap` ＝ 这只容器**一共几格**（v59 起它就是"格数预算"，摆不下的大件自然抽不到）；
	# `max_n` ＝ 最多摆几件；`red` ＝ **这一只能不能出红货**（中了临时升到 RED_PROMOTE 档）。
	# ⚠ `min_n` 已退役（格数预算决定件数），字段留着只为老存档/老注释对得上。
	"corpse":  {"name": "尸体",     "gap": 3, "min_n": 1, "max_n": 2, "red": 0.01, "tier": 0},
	"bundle":  {"name": "散落包袱", "gap": 3, "min_n": 1, "max_n": 2, "red": 0.01, "tier": 0},
	"box":     {"name": "木箱",     "gap": 4, "min_n": 1, "max_n": 3, "red": 0.02, "tier": 0},
	"basket":  {"name": "药篓",     "gap": 4, "min_n": 1, "max_n": 3, "red": 0.02, "tier": 0},
	"crevice": {"name": "石缝",     "gap": 3, "min_n": 1, "max_n": 2, "red": 0.01, "tier": 0},
	"cabinet": {"name": "储物柜",   "gap": 5, "min_n": 2, "max_n": 4, "red": 0.03, "tier": 1},
	"well":    {"name": "枯井",     "gap": 5, "min_n": 2, "max_n": 4, "red": 0.03, "tier": 1},
	"safe":    {"name": "密柜",     "gap": 6, "min_n": 2, "max_n": 5, "red": 0.04, "tier": 1},
}
# "这一只能出红货"那一掷中了之后升到哪一档：**小红**（1 格的那些：绝品突破丹 / 角色碎片）——
#   搜刮不该翻出"完整绝品功法"（那是货仓的大红行），但"居然翻到过一颗绝品丹"要有。
const RED_PROMOTE := 2

# 搜刮那一头"杂物行"的权重（见 data_ladder.roll_hold 的 junk_w）：
#   52 与旧 NORMAL_WEIGHT 里 junk 的权重同数，好让"翻出来大半是杂物"的手感不变。
const JUNK_ROW_W := 24.0

const CARD_GAP := 2
const ITEM_GAP := 4
const GEAR_GAP := 3
const SMALL_GAP := 1
const GAP_WINE := 3     # v62：一坛酒占 3 格（与 data_ladder.GAP_WINE 同数，两处必须一致）

const NORMAL_GAP_W := {
	"junk":   [56, 32, 12],
	"mat":    [70, 24, 6],
	"pill":   [90, 10, 0],
	"wine":   [85, 15, 0],
}

# ============================================================
# v50（用户："优化搜刮和货仓 就是几格的物品 他的显示不占一格而是好几格，
#   比如四格 就是占四格；轮廓就是四格的边框上品质的颜色"）：
#   把一串"占格"物品摆进一个固定列数的格子区——**占几格就横跨几格**。
#   返回 [{"idx": 件号, "col": 起始列, "row": 行, "w": 占几列}, …]
#   规矩：从左往右填；这一行放不下（col + w > cols）就换行。
#   ⚠ 格子区的列数由调用方定（搜刮临时仓库 12 列、鉴宝行货仓 6 列…），
#     这个函数只管"谁在第几行第几列、横跨几格"——画多大由面板乘单元格尺寸。
# ============================================================
static func pack_cells(items: Array, cols: int) -> Array:
	var out: Array = []
	var cn := maxi(1, cols)
	var col := 0
	var row := 0
	for i in items.size():
		var e: Dictionary = items[i]
		var w := clampi(int(e.get("gap", 1)), 1, cn)
		if col + w > cn:
			col = 0
			row += 1
		out.append({"idx": i, "col": col, "row": row, "w": w})
		col += w
	return out

# ---- 红件内权重 ----
# ⚠ v59：`RED_WEIGHT`（12 键那张红池权重表）**整张删掉了**——红池并进 `data_ladder`
#   的「红那一行」：大红＝完整 10/8 格 · 中红＝残 6/4 格 · 小红＝碎片/丹/料 ·
#   稀小红＝血脉/丹。想要"完整件更少见"就调 `data_ladder._pick_row()` 里 `big` 的权重。
# ============================================================
# ⚠ v59：`NORMAL_WEIGHT`（搜刮那张正常池权重表）**也整张删掉了**。
#   原来"正常货"有两份各写一份的权重表——搜刮的 NORMAL_WEIGHT、货仓的 roll_salvage 内联表，
#   改一处忘一处（这是上一轮留下的最大隐患）。现在全局**只有一张表**：
#   `data_ladder.slots()` 的 6 行 × 4 色 ＋ 一个"杂物行"。搜刮与货仓都走它。

# 普通丹（v59：它现在**只在搜刮的"杂物格"里出**，占那一格的 5%——
#   用户："至于哪些其他丹你看着安排看稀有度分到什么位置"：
#   强身/淬体是最低档（能炼、随处可得），养灵丹稀有（稀有度仅次于洗髓/洗灵）。
#   ⚠ 洗髓丹/洗灵丹**不在这张表里**：它们是红那一行"稀有"格的货（见 data_ladder）。
const PILLS := [
	{"id": "qiangshen", "name": "强身丹", "w": 45},
	{"id": "cuiti", "name": "淬体丹", "w": 40},
	{"id": "yangling", "name": "养灵丹", "w": 10, "rare": true},
]

# v45：突破丹进搜刮（用户："突破丹材料加入搜刮 按品质来"）
#   · 突破丹**五品**（凡/良/上/极/绝）——出哪一品跟**货色**走：
#       普通货（打杂兵翻出来的）：凡品打底，越往后相位越可能翻到良/上
#       红件（好货）：**良品起**，绝品只是"居然翻到过"的稀罕物
#   · 权重表按相位（`red_phase` 0~3，＝推塔进度）排，所以改平衡只动下面两串数字
#   · 名字与货栈价跟 game_state 的「突破丹五品」对齐（价：150/420/980/2200/5200）
#     ⚠ 名字在这边写死一份是**照抄**（搜刮不该反过来 preload 账本，会成环）；
#       改品名时两边都要改：game_state.DAN_RECIPES + SHOP_ITEMS。
# ============================================================
const TUPO_CN := {
	"tupo_fan": "突破丹（凡品）", "tupo_liang": "突破丹（良品）", "tupo_shang": "突破丹（上品）",
	"tupo_ji": "突破丹（极品）", "tupo_jue": "突破丹（绝品）",
}
const TUPO_VALUE := {"tupo_fan": 150, "tupo_liang": 420, "tupo_shang": 980, "tupo_ji": 2200, "tupo_jue": 5200}
# 上色档（0白/1绿/2紫/3金/4红，见 tier_of）：普通货里翻到的丹药按"品级"上色——
#   凡/良 显紫、上/极 显金、绝品显红。红件那份本来就按 red 走 4（红），不吃这张表。
const TUPO_TIER := {"tupo_fan": 2, "tupo_liang": 2, "tupo_shang": 3, "tupo_ji": 3, "tupo_jue": 4}
# 普通货：相位 0 → 3
const TUPO_NORMAL := [
	{"tupo_fan": 84, "tupo_liang": 15, "tupo_shang": 1},
	{"tupo_fan": 72, "tupo_liang": 23, "tupo_shang": 5},
	{"tupo_fan": 58, "tupo_liang": 30, "tupo_shang": 11, "tupo_ji": 1},
	{"tupo_fan": 44, "tupo_liang": 34, "tupo_shang": 17, "tupo_ji": 4, "tupo_jue": 1},
]
# 红件（好货）：良品起
const TUPO_RED := [
	{"tupo_liang": 56, "tupo_shang": 34, "tupo_ji": 9, "tupo_jue": 1},
	{"tupo_liang": 46, "tupo_shang": 37, "tupo_ji": 15, "tupo_jue": 2},
	{"tupo_liang": 36, "tupo_shang": 40, "tupo_ji": 20, "tupo_jue": 4},
	{"tupo_liang": 26, "tupo_shang": 40, "tupo_ji": 27, "tupo_jue": 7},
]
const MATS := [
	# v45（用户："突破丹材料加入搜刮 按品质来"）：把**突破丹那几样料**补齐。
	#   权重按"这料在第几品才登场"排：越晚用上的越少见——
	#     朱果（凡/上/绝）> 紫芝（良/极/绝）> 雪参（良/上/极/绝）
	#     > 兽骨碎（只上品）> 灵米（极/绝）
	{"id": "guo", "name": "朱果", "w": 30},
	{"id": "zhi", "name": "紫芝", "w": 25},
	{"id": "shen", "name": "雪参", "w": 20},
	{"id": "bone", "name": "兽骨碎", "w": 10},
	{"id": "rice", "name": "灵米", "w": 6},
	# v41：金髓——稀有的**金色材料**（洗髓丹/洗灵丹的硬门槛）。权重 5 → 7：
	#   池子扩容后要把它的占比**稳定在 5% 上下**（5/96 ≈ 5.2%），不然等于顺手削了它。
	#   它同时也是货栈每日限购那件（900 两、日限 1）。
	{"id": "jin", "name": "金髓", "w": 5},
]
# v14（用户："垃圾银两收益可以增加，也有不同品质的垃圾，暂定最高到紫"）：
#   · 每样杂物自带**品质**（q：0凡品白 / 1良品绿 / 2上品紫）——名字里带出来（"枯骨（上品）"）
#   · 卖价 ＝ `base × 品质系数 × 格数系数`：**占的格子越多越值钱**（"不同格子卖价不同"）
#     凡品 1 格 6 两 → 紫（上品碎玉）3 格 200 两（v13 从 1440 压下来，见 JUNKS 上面那段）；
#     原来一律 1~4 两，占着格子等于白捡
#   · 品质**封顶到紫（上品，q=2）**：这是用户定的"暂定上限"。game 里那套五档颜色是
#     凡白/良绿/上紫/极金/绝红（见 data_cards.QUALITY_ORDER 与 loot_panel._tier_col），
#     所以"到紫"＝**只到上品**，金（极品）/红（绝品）留给装备、兵器、功法那条线，杂物不碰。
const JUNK_Q_MAX := 2
# v13（用户："杂物的银两是不是太多了 我看到一个紫色品质的碎玉价值一千多银两"）：
#   旧表最肥的一件＝**上品碎玉 3 格 1440 两**，而同期的村货栈一件成品才 91~147 两、
#   爬塔一关给 1 两上下、挂机 1 两/分——一件杂物顶十几件店货，明显脱钩。
#   这一版把**数值压下来、形状留住**（品质差好几倍 · 占格越多越值钱两条设计不动）：
#     · 底子：凡品 6 两（1 格）不变——地板不动，免得杂物的"找零"手感没了
#     · 品质系数 4/2/1 → **2.5/1.5/1**（紫仍是最肥，只是不再翻四倍）
#     · 格数系数 3.0/1.8/1 → **2.0/1.4/1**
#     · 两件肥货的底子：铜钱串 40 → **18**、碎玉 120 → **40**（锈铁片 14 → 10）
#   算下来：**上品碎玉 3 格 1440 → 200 两**（≈ 一件凡品突破丹 147），
#   单件均值 39 → **14 两**，一趟（十来件杂物）从 ~510 两降到 **~180 两**。
#   ⚠ 想再紧/再松：只动下面 base 那三个数与 JUNK_Q_MUL / JUNK_GAP_MUL 两张小表。
const JUNKS := [
	{"id": "bone", "name": "枯骨", "q": 0, "w": 30, "base": 6},
	{"id": "rag", "name": "破布", "q": 0, "w": 25, "base": 6},
	{"id": "shard", "name": "碎瓦", "q": 0, "w": 25, "base": 6},
	{"id": "rust", "name": "锈铁片", "q": 1, "w": 15, "base": 10},
	{"id": "copper", "name": "铜钱串", "q": 2, "w": 5, "base": 18},
	{"id": "gem", "name": "碎玉", "q": 2, "w": 2, "base": 40},   # 最肥的那一件（紫）
]
# 杂物的品质名与系数（0凡/1良/2上·紫）——面板名与上色都走这里
const JUNK_Q_CN := ["凡品", "良品", "上品"]
const JUNK_Q_MUL := [1.0, 1.5, 2.5]             # 品质系数（v13：4/2/1 → 2.5/1.5/1）
const JUNK_GAP_MUL := [0.0, 1.0, 1.4, 2.0]      # 格数系数（下标＝占几格；v13：3.0/1.8/1 → 2.0/1.4/1）

# 一条杂物的卖价（占格×品质）——生成与显示都走这一口，免得两处各算一遍
static func junk_value(base: int, q: int, gap: int) -> int:
	var qm: float = float(JUNK_Q_MUL[clampi(q, 0, JUNK_Q_MUL.size() - 1)])
	var gm: float = float(JUNK_GAP_MUL[clampi(gap, 0, JUNK_GAP_MUL.size() - 1)])
	return maxi(1, int(round(float(base) * qm * maxf(gm, 1.0))))

static func junk_q_cn(q: int) -> String:
	return str(JUNK_Q_CN[clampi(q, 0, JUNK_Q_CN.size() - 1)])
# v59：`SILVER_RANGE` 退休（用它的是已退休的正常池）；搜刮的银两数额见 data_ladder._filler。

const FRAGMENTS := [
	{"id": "frag_player", "name": "少侠碎片"},
	{"id": "frag_chen", "name": "陈石碎片"},
	{"id": "frag_qing", "name": "苏青鸾碎片"},
]
# 碎片一次掉几片（v45：用户"搜刮碎片给 2-5"）。
# v13 的由来：星表当年是翻倍（满星 3780 片），一次 1 片要搜刮上万次，所以改成"一次一把"。
#   现在 v45 星表改成每星 +60（满星 1260 片），掉一把 10 片又嫌太肥 → 改成 **2~5 片**，
#   满星仍约 360 次拾取。嫌快嫌慢就动这一个数（[最少, 最多]）。
const FRAG_PER_DROP := [2, 5]

const SPAWN_BATTLE_NONE := 0.45
const SPAWN_BATTLE_EXTRA := 0.15
const SPAWN_EVENT_NONE := 0.35
const SPAWN_SAFE_AT_EVENT := 0.10
const EMPTY_CHANCE := 0.35
const BATTLE_POOL := ["corpse", "corpse", "bundle", "basket"]
const EVENT_POOL := ["box", "cabinet", "basket", "crevice", "well"]

static func container_name(cid: String) -> String:
	return str(CONTAINERS.get(cid, {}).get("name", cid))

static func container_gap(cid: String) -> int:
	return int(CONTAINERS.get(cid, {}).get("gap", 0))

static func card_gap(_sid: String) -> int:
	return CARD_GAP

# 精英三抽用——残卡（片）。
static func make_draw_entry(cat: String, sid: String, part: int) -> Dictionary:
	if cat == "buff":
		return {"kind": "item", "id": sid, "part": 0, "name": Cards.item_name(sid), "gap": ITEM_GAP, "red": true}
	return {"kind": "card", "id": sid, "part": maxi(0, part), "name": Cards.card_name(sid, part), "gap": card_gap(sid), "red": true}

static func tier_of(e: Dictionary) -> int:
	if bool(e.get("red", false)):
		return 4
	var k := str(e.get("kind", ""))
	if k == "card" or k == "item":
		return 4
	if k == "yuanbao":
		return 4
	if k == "fragment" or k == "wine":
		return 3
	# v14：杂物按它自己的品质上色（凡白/良绿/上紫）——一眼看得出哪件值钱
	if k == "junk":
		return clampi(int(e.get("q", 0)), 0, JUNK_Q_MAX)
	if k == "pill":
		var t := int(e.get("tier", 0))
		if t > 0:
			return t
		return 3 if bool(e.get("rare", false)) else 2
	if k == "mat" or k == "silver":
		return 1
	return 0

static func roll_spawn(kind: String) -> Array:
	var out: Array = []
	if kind == "battle":
		if randf() < SPAWN_BATTLE_NONE:
			return out
		out.append(_pick_from(BATTLE_POOL))
		if randf() < SPAWN_BATTLE_EXTRA:
			out.append(_pick_from(BATTLE_POOL))
		return out
	if kind == "elite":
		out.append("corpse")
		out.append("safe")
		return out
	if kind == "event":
		if randf() < SPAWN_EVENT_NONE:
			return out
		if randf() < SPAWN_SAFE_AT_EVENT:
			out.append("safe")
		else:
			out.append(_pick_from(EVENT_POOL))
		return out
	return out

static func roll_container(cid: String, luck_pct := 0.0, rate_mul := 1.0) -> Array:
	var cfg: Dictionary = CONTAINERS.get(cid, {})
	if cfg.is_empty():
		return []
	if cid != "safe" and randf() < EMPTY_CHANCE:
		return []
	# ============================================================
	# v59：搜刮改成走**货仓那张掉落阶梯表**（用户："搜刮也雷同 权重记得要做好"）——
	#   容器自己的格数＝"格数预算"，档位 `tier` 写在 CONTAINERS 里，
	#   那一掷老口径的 `red`（1%~4%）留着当"**这只容器能出红货**"的闸：中了就临时升到最高档。
	#   ⚠ 于是原来那**两张各写一份的正常池权重表**（NORMAL_WEIGHT 与 roll_salvage 里那张
	#     内联表）一起退休了——**全局只剩一张表**（data_ladder.slots 的 6 行 × 4 色）。
	#   ⚠ 底档仍然是杂物（`junk_w`），"垃圾银两收益"那条设计没被砍掉。
	# ============================================================
	var tier := int(cfg.get("tier", 0))
	if randf() < float(cfg["red"]) * (1.0 + luck_pct / 100.0):
		tier = RED_PROMOTE
	var lk := 1.0 + luck_pct / 100.0
	var q: int = Ladder.base_q_now(red_phase)
	# v62e（用户："搜刮也同理啊 不过搜刮没保底"）：
	#   颜色爆率与货仓**同源**（同一张 _pick_color 绝对爆率：红 1.5% / 金 10% / 紫 30%），
	#   但**最后那个 `false` 把红色保底关掉**——搜刮不保底，翻到什么是运气。
	return Ladder.roll_hold(int(cfg["gap"]), tier, q, lk, null, int(cfg["max_n"]), "junk", JUNK_ROW_W, false, rate_mul)

static func _pick_from(arr: Array) -> String:
	return str(arr[randi() % arr.size()])

# ⚠ v59：`_pick_red` / `_make_red`（老红池）、`_pick_normal` / `_roll_one_normal`（老正常池）
#   **整块退休**——红件与正常货现在都由 `data_ladder` 那张唯一的表出：
#     红那一行按尺寸出品（大红＝完整 10/8 格 · 中红＝残 6/4 格 · 小红＝碎片/丹/料 ·
#     稀小红＝血脉/丹），正常货按「6 行 × 4 色」，杂物作为"杂物行"混在里面。
#   `RED_WEIGHT` 那张 12 键权重表跟着一起退休。
static func _junk_entry() -> Dictionary:
	var j := _weighted_list(JUNKS)
	var jq := int(j.get("q", 0))
	var jg := _pick_gap("junk")
	# v14：占的格子越多越值钱（junk_value＝base×品质系数×格数系数）；
	#   名字里带品质，玩家一眼看得出哪件是紫的（卖价差好几倍）
	# 越阶越肥（v14）：推到后面的阶段，杂物有几率往上抬一档（红池相位＝推塔进度）
	#   ⚠ 抬到**紫就封顶**（JUNK_Q_MAX）——再往上就得动"杂物只能到紫"这条规矩了
	if red_phase > 0 and randf() < 0.10 * float(mini(red_phase, 4)):
		jq = mini(jq + 1, JUNK_Q_MAX)
	return {"kind": "junk", "id": str(j.get("id", "")), "part": 0, "amount": 1, "q": jq,
		"value": junk_value(int(j.get("base", 1)), jq, jg),
		"name": str(j.get("name", "杂物")) + "（" + junk_q_cn(jq) + "）", "gap": jg, "red": false}

static func _pill_entry() -> Dictionary:
	var p := _weighted_list(PILLS)
	return {"kind": "pill", "id": str(p.get("id", "")), "part": 0, "name": str(p.get("name", "丹药")), "gap": _pick_gap("pill"), "red": false, "rare": bool(p.get("rare", false)), "tier": int(p.get("tier", 0))}

# 掷一颗突破丹（red＝这一件是红件/好货）——普通与红件各一张表，按相位挑（表见文件上半）
static func tupo_entry(red: bool) -> Dictionary:
	var idx := clampi(red_phase, 0, TUPO_NORMAL.size() - 1)
	var table: Dictionary = (TUPO_RED[idx] if red else TUPO_NORMAL[idx])
	var pid := _weighted(table)
	return {"kind": "pill", "id": pid, "part": 0, "amount": 1,
		"name": str(TUPO_CN.get(pid, pid)), "gap": SMALL_GAP, "red": red, "rare": false, "tupo": true,
		"tier": int(TUPO_TIER.get(pid, 2))}

# v58：**按 id 造**一颗突破丹——掉落阶梯要指定"这一色配哪一档突破丹"
#   （原来是 `tupo_entry(red)` 按相位随机挑；阶梯表要的是"红→绝品 · 金→极品 · 紫→上品 · 蓝→良品"）
static func tupo_by_id(tid: String) -> Dictionary:
	if not TUPO_CN.has(tid):
		return {}
	return {"kind": "pill", "id": tid, "part": 0, "amount": 1,
		"name": str(TUPO_CN.get(tid, tid)), "gap": SMALL_GAP, "red": true, "rare": false,
		"tupo": true, "tier": int(TUPO_TIER.get(tid, 2))}

# v58：**按 id 造**稀有丹（红那一行的"稀有"格用）
# v61（用户："移除洗髓丹"）：`xisui` 那一支**整条删掉**——洗髓丹从配方、掉落、搜刮里全部下线。
#   ⚠ 连带后果：**根骨（gengu）从此没有成长途径**，只由人物模板决定
#     （少侠 62 / 陈石 35 / 苏青鸾 48）——评价与"每级成长档"随之固定。
#   想恢复：把下面那一支加回来 + game_state.DAN_RECIPES 里那条也加回来。
static func pill_by_id(pid: String) -> Dictionary:
	match pid:
		"xiling":
			return {"kind": "pill", "id": "xiling", "part": 0, "amount": 1, "name": "洗灵丹",
				"gap": SMALL_GAP, "red": true, "rare": true, "tier": 4}
	return {}

# ============================================================
# v62（用户："酒分品级 加入搜刮和货仓 最低紫 最高红 3格"）
#
#   酒酿正式成为掉落表里的一行（`Ladder.slots()` 的 "wine"）：
#     · **占 3 格**（GAP_WINE）——一坛酒就是三格，货仓/临时仓库都按 3 格摆
#     · **品级只出 上品(紫) / 极品(金) / 绝品(红)**：下限写在 data_ladder.ROW_MIN_COLOR，
#       上限由货仓档位（TIER_CAP）管，跟别的行同一套规矩
#     · 品级决定 **名字 + 身价**：紫＝村酿 · 金＝竹叶酒 · 红＝陈酿（都是村里品酒坊那几个名号）
#     · 带回村后进酒坊（`journey_deposit` 按品级兑成对应档次的那坛酒，见 game_state.add_wine_of_grade）
# ============================================================
const WINE_GRADE := {
	2: {"name": "村酿", "base": 270, "value": 270},      # v63（用户："价格增幅拉高一点"）：180→270（+50%）
	3: {"name": "竹叶酒", "base": 540, "value": 540},    #   360→540
	4: {"name": "陈酿", "base": 1080, "value": 1080},    #   720→1080
}

static func wine_grade_of(color: String) -> int:
	match color:
		"red": return 4
		"gold": return 3
		_: return 2          # 紫（酒的下限；蓝走不到）

static func _wine_entry(color: String, q: int, rng: RandomNumberGenerator) -> Dictionary:
	# v63（用户："酒价格上浮100% 但是好酒几率下降50%"）：
	#   · 价格在 WINE_GRADE 里 ×2（180/360/720）
	#   · **好酒（金/红）掉率减半**：摇中金/红时，一半概率降一档（红→金、金→紫）。
	#     ⚠ 只动这里——短绳签的 boss 保底金酒不走 _wine_entry（直接记 grade 3），不吃这刀。
	# ⚠ v13 修（顺手抓到的老 bug）：这里原来直接 `rng.randf()`，而**搜刮那头传的就是 null**
	#   （roll_container → Ladder.roll_hold(rng=null) → _make → 这里）——于是每摇到"酒酿那一行"
	#   就报 "Cannot call method 'randf' on a null value"，函数半路返回 null、**塞进容器里**；
	#   表现就是"路上怎么翻都翻不出酒"（货仓那头有真 rng，所以一直没露馅）。
	#   照本文件别处的口径补 null 分支：有 rng 用它，没有就用全局 randf()。
	var downgrade := (rng.randf() if rng != null else randf())
	if (color == "gold" or color == "red") and downgrade < 0.5:
		color = "purple" if color == "gold" else "gold"
	var g := wine_grade_of(color)
	var spec: Dictionary = WINE_GRADE.get(g, WINE_GRADE[2])
	return {"kind": "wine", "id": "", "part": 0, "amount": 1,
		"name": str(spec["name"]) + "（" + str(COLOR_CN.get(color, color)) + "）",
		"gap": GAP_WINE, "red": color == "red", "wgrade": g,
		"base": int(spec["base"]), "value": int(spec["value"]),
		"q": clampi(q, 0, 4)}

# 品级的中文（只酒酿这一支用；别的行走各自的 name 规则）
const COLOR_CN := {"blue": "良品", "purple": "上品", "gold": "极品", "red": "绝品"}

# ============================================================
# v59：`SALVAGE_GOOD` / `roll_salvage`（货仓专用的那张旧表）**整块退休**——
#   货仓与搜刮现在都走 `Ladder.roll_hold`（`data_ladder.gd`，全局唯一一张掉落表）。
#   v39/v56 那套"好货走红池、杂项走共用小口、luck 抬三样"的说明已被阶梯表取代：
#     ① "价格决定爆率" → `data_appraise.HOLDS` 的 `tier`（最高抽到哪一色）＋ `cells`（几格）
#     ② "成色加成"     → `luck`（同一行里往上限那一头偏多少）
#     ③ "红件尺寸"     → `data_ladder.TIER_CAP` 的 `red_size`
#   留着旧函数只会又多出一份会走偏的权重（原来那张内联表就是这么来的）。
# ============================================================
# 一件货的**估值**（银两口径）——鉴宝行要拿它排"最值钱的那一件"、也要给玩家看个数。
#   ⚠ 这是**估价**不是卖价：成品/残卡按"品级×基价"折算，碎片按片数，元宝按元宝价。
#     想让鉴定报告更准/更飘，只改这一张表。
static func entry_value(e: Dictionary) -> int:
	var k := str(e.get("kind", ""))
	var sid := str(e.get("id", ""))
	var q := Cards.q_idx(sid) if sid != "" else 0
	var pm := float(Cards.PRICE_MUL[clampi(q, 0, Cards.PRICE_MUL.size() - 1)])
	match k:
		"junk":
			return int(e.get("value", 1))
		"silver":
			return int(e.get("amount", 1))
		"mat":
			return 18                      # 药材：与货栈价一个量级（兽骨碎 15 / 灵米 10）
		"fragment":
			return 40 * maxi(1, int(e.get("amount", 1)))
		"card":
			return int(round(90.0 * pm))
		"item":
			return int(round(200.0 * pm))
		"pill":
			# v45：突破丹按品级定价（与货栈那五档对齐）——鉴宝行的估价/回本率跟着它走
			if TUPO_VALUE.has(sid):
				return int(TUPO_VALUE[sid])
			if bool(e.get("rare", false)):
				return 600
			return 80 + 40 * q
		"wine":
			# v62：按品级给身价（紫 90 · 金 180 · 红 360）——鉴宝行的估价/回本率跟着它走
			var wg := int(e.get("wgrade", 2))
			var wspec: Dictionary = WINE_GRADE.get(wg, WINE_GRADE[2])
			return int(wspec["value"])
		"blood":
			return 280
		"yuanbao":
			return 900
	return 1

# 这件是什么"型"（鉴定报告上的小标签；未知时只给大类）
static func entry_kind_cn(e: Dictionary) -> String:
	var k := str(e.get("kind", ""))
	var sid := str(e.get("id", ""))
	match k:
		"card":
			if Cards.is_arts(sid):
				return "功法残页"
			if Cards.is_buff(sid):
				return "增益残卡"
			if Cards.is_gear(sid):
				return "器具残片"
			return "兵器残卡"
		"item":
			return "完整功法" if Cards.is_arts(sid) else "成品器物"
		"fragment":
			return "角色碎片"
		"junk":
			return "杂物"
		"mat":
			return "药材"
		"pill":
			return "丹药"
		"wine":
			return "酒酿"
		"blood":
			return "血脉"
		"silver":
			return "银两"
		"yuanbao":
			return "元宝"
	return "未知"


static func _pick_gap(kind: String) -> int:
	var w: Array = NORMAL_GAP_W.get(kind, [100, 0, 0])
	var total := 0
	for v in w:
		total += int(v)
	if total <= 0:
		return SMALL_GAP
	var r := randi() % total
	for i in w.size():
		r -= int(w[i])
		if r < 0:
			return i + 1
	return SMALL_GAP

# ⚠ v59：`_pick_high`（老红池"按相位挑品级"）**退休**——阶梯表直接按"这一行的色"指定品级。
static func _card_entry(sid: String, red: bool) -> Dictionary:
	var part := randi() % maxi(1, Cards.part_count(sid))
	return {"kind": "card", "id": sid, "part": part, "name": Cards.card_name(sid, part), "gap": card_gap(sid), "red": red}

static func _item_entry(sid: String) -> Dictionary:
	return {"kind": "item", "id": sid, "part": 0, "name": Cards.item_name(sid), "gap": ITEM_GAP, "red": true}

# v59：`_gear_entry` 也退休了——阶梯表用 `_item_entry()` + 覆盖 gap 造完整兵器/器具。

static func _weighted(w: Dictionary) -> String:
	# v56：改成按**浮点**累加。完整件那几个权重本来就是小数（0.4 / 1.0，再乘货仓的 full_mul），
	#   而这里原来是 `int(w[k])` 累加——小数会被**截成 0**，等于"整本功法/整件兵器永远抽不到"
	#   （探针实测 30000 仓 0 次，就是被这一行吃掉的）。
	#   调用方传整数权重时，浮点口径的分布与原来看不出差别。
	var total := 0.0
	for k in w.keys():
		total += float(w[k])
	if total <= 0.0:
		return ""
	var r := randf() * total
	for k2 in w.keys():
		r -= float(w[k2])
		if r < 0.0:
			return str(k2)
	return ""

static func _weighted_list(items: Array) -> Dictionary:
	var total := 0
	for it in items:
		total += int(it.get("w", 1))
	if total <= 0:
		return {}
	var r := randi() % total
	for it2 in items:
		r -= int(it2.get("w", 1))
		if r < 0:
			return it2
	return {}
