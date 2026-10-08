extends RefCounted
# ============================================================
# data_ladder.gd —— **掉落阶梯**（货仓 / 搜刮共用一张）v58
#
# 用户原话（规格）：
#   "完整功法武器定义为和游历一样 定义为比越阶 1-2 如果游历难度处在凡品 那么就是良品和上品
#    如果处在良品 那就是 上品和极品"
#   "大红 完整功法定义为10格 装备武器完整为8 · 中红 残功法6 残武器装备4
#    小红 角色碎片1 绝品突破丹1 洗髓丹炼丹材料1 洗灵丹炼丹材料1
#    稀有小红 血脉2 洗髓丹1 洗灵丹1"
#   "金【关键】大金 完整…同阶 · 中金 残…同阶 · 小金 1炼丹材料 1极品突破丹炼丹材料
#    稀有小金 血脉2 极品突破丹1"
#   "紫【关键】大紫 …次1阶【如果没有就没有】杂物8【银两】· 中紫 …次1阶 杂物5
#    小紫 1炼丹材料 1上品突破丹炼丹材料 杂物1-3 · 稀有小紫 血脉2 上品突破丹1"
#   "蓝 大紫(=大蓝) …次2阶【如果没有就没有】杂物8【银两】依次类推"
#   "1.游历难度 到8 后面就是良品了 16之后就是上品"
#   "5.每档只能抽它自己那一行的色…便宜仓红格子权重极低但仍可能中 这个也加上"
#
# 三条硬口径：
#   ① **颜色 → 品阶**：蓝=良品(1) 紫=上品(2) 金=极品(3) 红=绝品(4)；凡品(0) 不单设一行
#   ② **成色偏移**：以"游历难度换算出的品阶"为基准——红 = +1~+2 阶、金 = 同阶、
#      紫 = −1 阶、蓝 = −2 阶。**没有那一阶就没有**（不往上借、不往下掉）。
#   ③ **格数**（占几格是**按规格重定的**，与占格常量 CARD_GAP/ITEM_GAP 那套无关）：
#        完整功法 10 · 完整武器装备 8 · 残功法 6 · 残武器装备 4 · 血脉 2 · 其余小件 1
#
# ⚠ 这个文件**只有表与查表**：怎么抽、抽多少件、权重如何随货仓档位变，都在调用方。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")

# 四色（从低到高）。凡品不单设一行（用户确认："凡品（白）就不单独设一档了 对的"）
const COLORS := ["blue", "purple", "gold", "red"]
const COLOR_Q := {"blue": 1, "purple": 2, "gold": 3, "red": 4}
const COLOR_CN := {"blue": "蓝", "purple": "紫", "gold": "金", "red": "红"}
const COLOR_QUALITY_CN := {"blue": "良品", "purple": "上品", "gold": "极品", "red": "绝品"}

# 成色偏移（相对"游历难度品阶"）：红＝+1~+2（两个值随机取）、金＝0、紫＝−1、蓝＝−2
const COLOR_OFFSET := {"red": [1, 2], "gold": [0, 0], "purple": [-1, -1], "blue": [-2, -2]}

# 四个尺寸
const SIZES := ["rare", "small", "mid", "big"]
const SIZE_CN := {"rare": "稀有", "small": "小", "mid": "中", "big": "大"}

# 格数（用户重定的）
const GAP_FULL_ART := 10      # 完整功法
const GAP_FULL_GEAR := 8      # 完整兵器 / 装备
const GAP_CARD_ART := 6       # 残功法
const GAP_CARD_GEAR := 4      # 残兵器 / 装备
const GAP_BLOOD := 2          # 血脉
const GAP_SMALL := 1          # 其余小件（碎片/丹/材料/银两）
# v62（用户："酒分品级 加入搜刮和货仓 最低紫 最高红 3格"）：
#   酒酿**自己一行**，固定占 **3 格**；颜色只出 紫(上品)/金(极品)/红(绝品) 三档——
#   所以这一行有"**下限**"（见 ROW_MIN_COLOR 与 _pick_color 里那一段），别的行没有。
const GAP_WINE := 3
# 紫/蓝档的"大件"要**附赠杂物（银两）**凑回本：大 8 格 · 中 5 格 · 小 1~3 格
const FILLER_BIG := 8
const FILLER_MID := 5
const FILLER_SMALL := [1, 3]

# ============================================================
# 游历难度 → 品阶（用户："游历难度 到8 后面就是良品了 16之后就是上品"）
#   难度 1~8 ＝ 凡品(0) · 9~16 ＝ 良品(1) · 17~24 ＝ 上品(2) · 25~32 ＝ 极品(3) · 33+ ＝ 绝品(4)
# ============================================================
const DIFF_STEP := 8

static func q_of_diff(diff: int) -> int:
	var d := maxi(1, diff)
	return clampi(int(ceil(float(d) / float(DIFF_STEP))) - 1, 0, 4)

# 村里/鉴宝行这边拿到的是**进度相位**（`GameState.ladder_phase()`，0~4，游历难度首通每 8 次升一段），
#   换算成"难度"再走 q_of_diff —— 于是相位 0/1/2/3/4 → 良品/良品/上品/极品/绝品
#   （相位 0 与 1 同档：0 是"一趟都没通"，而鉴宝行 400 关才开张，实际进场时相位早就 ≥1）。
#   而**绝品**在相位 3 以下只能靠红那一行 +1/+2 越上去（这正是"越阶"的意义）。
static func base_q_now(phase: int) -> int:
	return q_of_diff(maxi(1, phase) * DIFF_STEP + 1)

static func diff_of_q(q: int) -> int:
	# 反查：这一阶的最低难度（面板提示用）
	return clampi(q, 0, 4) * DIFF_STEP + 1

# 某一色的某一尺寸，**成色是第几阶**（拿不到那一阶就返回 -1 ＝"没有就没有"）
static func slot_q(color: String, base_q: int) -> int:
	var off: Array = COLOR_OFFSET.get(color, [0, 0])
	# 红是 +1~+2 两档取一：这里给"最低那一档"，上限由调用方按 randf 取（见 roll_slot_q）
	return clampi(base_q + int(off[0]), 0, 4) if base_q + int(off[0]) <= 4 else -1

# 红档：成色在 +1 与 +2 之间摇一个；其余色固定
static func roll_slot_q(color: String, base_q: int, rng: RandomNumberGenerator = null) -> int:
	var off: Array = COLOR_OFFSET.get(color, [0, 0])
	var lo := int(off[0])
	var hi := int(off[1])
	var k := lo
	if hi > lo:
		k = (rng.randi_range(lo, hi) if rng != null else randi_range(lo, hi))
	var q := base_q + k
	# v58 修正（跑探针才看出来的）：**掉到底＝没有就没有；顶到绝品＝就给绝品**。
	#   原来两头都返回 -1，于是"绝品难度"下**红那一行什么都抽不出来**（+1/+2 越界），
	#   最好的色反而空转 → 越往后越差，整条阶梯是反的。
	#   用户写的"如果没有就没有"是配在**紫/蓝（往下减）**那两句上的，所以只有往下才作废。
	if q < 0:
		return -1
	return mini(q, 4)

# ============================================================
# 16 个格位的内容（一张表，货仓与搜刮共用）
#   每个格位：{"k": 大类, "gap": 占几格, "q": 成色规则, "filler": 附赠杂物格数}
#     k = "full_art" 完整功法 · "full_gear" 完整兵器/装备 · "card_art" 残功法
#         "card_gear" 残兵器/装备 · "frag" 角色碎片 · "pill" 丹药 · "mat" 炼丹材料
#         "blood" 血脉
#     q = "slot" 用 slot_q() 算（红会摇 +1/+2）· 固定数字 ＝ 写死（材料/丹/血脉不看难度）
# ============================================================
static func slots() -> Dictionary:
	var out := {}
	# ---- 大：完整件；紫/蓝要附赠杂物 ----
	out["big"] = {
		"blue": {"k": "full_art", "gap": GAP_FULL_ART, "q": "slot", "filler": FILLER_BIG},
		"purple": {"k": "full_art", "gap": GAP_FULL_ART, "q": "slot", "filler": FILLER_BIG},
		"gold": {"k": "full_art", "gap": GAP_FULL_ART, "q": "slot", "filler": 0},
		"red": {"k": "full_art", "gap": GAP_FULL_ART, "q": "slot", "filler": 0},
	}
	# 完整"兵器/装备"是同一格的另一半（抽到 full 时按 50% 决定是功法还是兵器/装备）
	out["big_gear"] = {
		"blue": {"k": "full_gear", "gap": GAP_FULL_GEAR, "q": "slot", "filler": FILLER_BIG},
		"purple": {"k": "full_gear", "gap": GAP_FULL_GEAR, "q": "slot", "filler": FILLER_BIG},
		"gold": {"k": "full_gear", "gap": GAP_FULL_GEAR, "q": "slot", "filler": 0},
		"red": {"k": "full_gear", "gap": GAP_FULL_GEAR, "q": "slot", "filler": 0},
	}
	# ---- 中：残件；紫/蓝附赠杂物（5 格）----
	out["mid"] = {
		"blue": {"k": "card_art", "gap": GAP_CARD_ART, "q": "slot", "filler": FILLER_MID},
		"purple": {"k": "card_art", "gap": GAP_CARD_ART, "q": "slot", "filler": FILLER_MID},
		"gold": {"k": "card_art", "gap": GAP_CARD_ART, "q": "slot", "filler": 0},
		"red": {"k": "card_art", "gap": GAP_CARD_ART, "q": "slot", "filler": 0},
	}
	out["mid_gear"] = {
		"blue": {"k": "card_gear", "gap": GAP_CARD_GEAR, "q": "slot", "filler": FILLER_MID},
		"purple": {"k": "card_gear", "gap": GAP_CARD_GEAR, "q": "slot", "filler": FILLER_MID},
		"gold": {"k": "card_gear", "gap": GAP_CARD_GEAR, "q": "slot", "filler": 0},
		"red": {"k": "card_gear", "gap": GAP_CARD_GEAR, "q": "slot", "filler": 0},
	}
	# ---- 小：材料 + 该色对应的突破丹材料；紫/蓝附赠杂物 1~3 ----
	#   突破丹按色归位（用户："突破丹也可以练 至于哪些其他丹你看着安排看稀有度分到什么位置"）：
	#     红→绝品 · 金→极品 · 紫→上品 · 蓝→良品（凡品不单设一行，所以凡品突破丹走杂项池）
	out["small"] = {
		"blue": {"k": "mat", "gap": GAP_SMALL, "q": -1, "with": "tupo_liang", "filler": -1},
		"purple": {"k": "mat", "gap": GAP_SMALL, "q": -1, "with": "tupo_shang", "filler": -1},
		"gold": {"k": "mat", "gap": GAP_SMALL, "q": -1, "with": "tupo_ji", "filler": 0},
		"red": {"k": "mat", "gap": GAP_SMALL, "q": -1, "with": "tupo_jue", "filler": 0,
			"extra": "frag"},
	}
	# ---- 稀有：血脉 + 该色对应的丹；洗灵只在红那一行（v61：洗髓丹已下线）----
	# v62（用户："洗灵丹和完整功法武器 权重再大幅度降低"→随后"洗灵丹是极度稀有 再降"）：
	#   红那一行的 `also`（洗灵丹）原来**必给**，先砍到 25%，现在再压到 **4%（1/25）**——
	#   定位就是"极度稀有"：**正经来路是炼丹阁自己炼**（金髓×2 ＋ 灵草那几味，见 DAN_RECIPES），
	#   掉落这一头只当彩票。想再调只动这个数（1.0＝必给）。
	out["rare"] = {
		"blue": {"k": "blood", "gap": GAP_BLOOD, "q": -1, "with": "tupo_liang"},
		"purple": {"k": "blood", "gap": GAP_BLOOD, "q": -1, "with": "tupo_shang"},
		"gold": {"k": "blood", "gap": GAP_BLOOD, "q": -1, "with": "tupo_ji"},
		"red": {"k": "blood", "gap": GAP_BLOOD, "q": -1, "with": "tupo_jue",
			"also": ["xiling"], "also_chance": 0.04},
	}
	# ---- 酒酿（v62 新增）：3 格一行 · 只有 紫/金/红 三色（下限见 ROW_MIN_COLOR）----
	out["wine"] = {
		"blue": {"k": "wine", "gap": GAP_WINE, "q": -1},      # ⚠ 走不到（下限会把它抬到紫）
		"purple": {"k": "wine", "gap": GAP_WINE, "q": -1},
		"gold": {"k": "wine", "gap": GAP_WINE, "q": -1},
		"red": {"k": "wine", "gap": GAP_WINE, "q": -1},
	}
	return out

# 每一行的**颜色下限**（没写的行＝没有下限，蓝起步）。酒酿是唯一有下限的一行：
#   用户："最低紫 最高红" —— 最高那一头由货仓档位（TIER_CAP）管，不用在这儿写。
const ROW_MIN_COLOR := {"wine": "purple"}
# v62（用户："红色酒变为稀有红的权重比"）：
#   酒酿那一行抽到**红**之后，再掷一次"留不留"——只留 **10%**，其余落回该档允许的次高色。
#   于是绝品酒（陈酿）与"稀有红那一行"（血脉/洗灵丹）同一个稀罕度，
#   金（竹叶酒）成为酒里的常见上限。别的行不写＝照旧（抽到就留）。
const ROW_RED_KEEP := {"wine": 0.10}

# ---- 每档货仓"最高能抽到哪一行"（用户：第一个最高紫 第二个最高金 第三个最高小红…）----
#   cap ＝ 色；red_size_cap ＝ 抽到红那一行时**最高允许的尺寸**（rare/small/mid/big）
const TIER_CAP := [
	{"color": "purple", "red_size": "none"},
	{"color": "gold", "red_size": "none"},
	{"color": "red", "red_size": "small"},
	{"color": "red", "red_size": "mid"},
	{"color": "red", "red_size": "big"},
]
# 便宜仓中**超出上限的红件**的概率（用户："便宜仓红格子权重极低但仍可能中 这个也加上"）。
#   ⚠ 这是**每次抽一格的命中率**（不是权重）：一仓会抽 4~10 格，所以"一仓里有越阶红"的
#     概率 ≈ OVER_CAP_P × 抽了几格。0.005 时，24 格的木箱大约**每 50 仓**出一件越阶红。
# ⚠ v59 改口径：原来是一个 0.6 的**权重**，而同一行的正常色权重只有 1~2.5 ——
#   于是"极低"其实是 **19%**（探针实测：最高紫的木箱几乎每仓都有红/金），
#   与"最高紫""极低"两条都相反。改成概率之后，"极低"才是真的极低。
#   **只放红**：金不会因为"超过最高紫"就漏进木箱（那违背"最高紫"这条档位规矩）。
const OVER_CAP_P := 0.005
# 行内四色的权重衰减：离本档上限越远越少（上限那一色权重 1.0，次一色 0.5…）
const COLOR_DECAY := 0.5

static func color_rank(c: String) -> int:
	return COLORS.find(c)

# 这一档能不能抽到 (color, size)
static func allowed(tier_i: int, color: String, size: String) -> bool:
	var t: Dictionary = TIER_CAP[clampi(tier_i, 0, TIER_CAP.size() - 1)]
	var cap := str(t.get("color", "red"))
	if color_rank(color) > color_rank(cap):
		return false
	if color != "red":
		return true
	# 红那一行：看尺寸上限
	var rmax := str(t.get("red_size", "none"))
	if rmax == "none":
		return false     # 前两档＝"最高紫/最高金"，红那一行一点都不许（"一件红货都不出"）
	match rmax:
		"small":
			return size == "small" or size == "rare"
		"mid":
			return size != "big"
		_:
			return true

# ============================================================
# 抽一整仓（**按"格数预算"抽**，不是按件数）
#   为什么改成按格：规格里完整功法占 **10 格**、完整兵器 8 格——再按"几件"抽，
#   一仓 28 件能把 48 格的盘撑爆（画不下、结果页却有），两边对不上。
#   现在：一边抽一边扣格子预算，扣不动就停 → **盘上摆出来的件数＝账上真实的件数**。
#
#   tier_i  ＝ 这只仓的档位（0~4，见 TIER_CAP）
#   base_q  ＝ 游历难度换算出的品阶（0~4，见 q_of_diff）
#   luck    ＝ 好货率（越大越往"上限那一行"偏）
#   返回：与 data_loot 同格式的条目（kind/id/part/name/gap/red），下游一个字都不用改
# ============================================================
# 格子区列数（**与 appraise_panel._use_grid 同一条规则**——两处必须一致，不然"盘上摆的"
#   与"账上有的"又会对不上）
static func grid_cols(cells: int) -> int:
	# ⚠ v58 修（探针抓到的）：**列数必须 ≥ 最宽的那一件**，否则那件永远放不进去。
	#   完整功法占 **10 格**，而 `pack_cells` 是"一行内横着摆"——
	#   第一版 24 格的木箱给 6 列、36/52 格给 8 列，于是这些档位**一件完整功法都抽不出来**
	#   （静默失效：不报错，只是永远没有）。现在统一 **10 列**（≥20 格都用 10 列）。
	if cells >= 20:
		return 10
	return 6

# 一行放得下 w 格吗（first-fit：从上往下、每行从左往右找第一段连续空位）
#   ⚠ 与 `Loot.pack_cells` 的摆法**必须是同一条规则**，否则排不下
static func _place(free: Array, cols: int, w: int) -> bool:
	for r in free.size():
		var row: Array = free[r]
		var run := 0
		for c in cols:
			if bool(row[c]):
				run += 1
				if run >= w:
					var s := c - w + 1
					for k in w:
						row[s + k] = false
					return true
			else:
				run = 0
	return false

# 只问"放得下吗"，**不动**格子（挑行之前先问一句用）
static func _fits(free: Array, cols: int, w: int) -> bool:
	for r_v in free:
		var row: Array = r_v
		var run := 0
		for c in cols:
			if bool(row[c]):
				run += 1
				if run >= w:
					return true
			else:
				run = 0
	return false

# 放一格填充货（银两 / 杂物 / 酒酿）
#   ⚠ v59 修（探针抓到的）：原来这里写死 `_place(free, cols, 1)`——**银两是 1 格没错，
#     可杂物不是**（`_junk_entry` 的 gap 是 1~3）。于是搜刮那头的 2/3 格杂物
#     只占掉 1 格账，一盘子摆出去比容器本身大：实测 尸体(3 格) **24% 的开箱超格**、
#     木箱(4 格) 10%。现在按**这件货真实的 gap** 占格，占不下就当场收手。
static func _put_filler(free: Array, cols: int, out: Array, rng: RandomNumberGenerator,
		kind: String) -> bool:
	var e := _filler(rng, kind)
	var g := maxi(1, int(e.get("gap", 1)))
	if not _place(free, cols, g):
		return false
	out.append(e)
	return true

# 每一行**最宽的那一件**占几格（用它先筛"这一行还摆得下吗"）
const ROW_W := {"big": GAP_FULL_ART, "big_gear": GAP_FULL_GEAR, "mid": GAP_CARD_ART,
	"mid_gear": GAP_CARD_GEAR, "small": GAP_SMALL, "rare": GAP_BLOOD,
	"wine": GAP_WINE}

static func roll_hold(cell_budget: int, tier_i: int, base_q: int, luck := 1.0,
		rng: RandomNumberGenerator = null, max_items := 60, filler := "silver",
		junk_w := 0.0, pity := true, rate_mul := 1.0) -> Array:
	var Loot = load("res://shared/data_loot.gd")
	var sl := slots()
	var out: Array = []
	var cells := maxi(1, cell_budget)
	# ⚠ v59 修（探针抓到的第三处）：这里原来是 `maxi(4, cell_budget)`——
	#   货仓最小 24 格看不出问题，但**搜刮的 3 格容器会被偷偷撑成 4 格**：
	#   实测 尸体/包袱/石缝（3 格）有 **39% 的开箱"占格 4 > 3"**，还多塞了一件 4 格残器。
	#   现在按调用方给的格数**一格不多给**（谁超格谁自己看着办）。
	var cols := grid_cols(cells)
	var nrows := int(ceil(float(cells) / float(cols)))
	var ti := clampi(tier_i, 0, TIER_CAP.size() - 1)
	# ── **真格子**（rows × cols 的布尔阵）──
	#   ⚠ v58 修：原来是"扣总格数"，但**格子盘是按行从左往右摆的**——一件 6 格的残功法
	#     正好卡在两行之间时，那一行剩下的 5 格就废了。实测 13.9 件只排得下 8 件。
	#     现在一边抽一边**真往格子里放**（first-fit，规则与 Loot.pack_cells 一致），
	#     放不下就停 → **盘上摆几件＝账上真几件**，一件不多一件不少。
	var free: Array = []
	for r in nrows:
		var row: Array = []
		for c in cols:
			# ⚠ v59 修（探针抓到的第二处）：原来是 `r <= (cells-1)/cols or …` ——
			#   第一个条件把**最后一行整行**都算成空的（24 格的仓 → 3×10＝30 格可用），
			#   账上货物比盘上格子多出最多 cols-1 格，"这只仓一共几格"就成了假话。
			#   与 `appraise_panel` 画底格的规矩（`r*cols+c >= draw_cells 就跳过`）对齐：
			#   **只有 (行×列数＋列) < 总格数 的格子才是真格子**。
			row.append((r * cols + c) < cells)
		free.append(row)
	var rows := ["big", "big_gear", "mid", "mid_gear", "small", "rare", "wine"]   # v62：酒酿成一行
	if junk_w > 0.0:
		# 搜刮那一头多一行"杂物"（**不是第二张表**：只是同一张阶梯表里多一个行名）——
		#   路上翻尸体/药篓本来就该以杂物为主（v14"垃圾银两收益"那条设计），
		#   杂物本身也带品质色、卖了就是银两，所以它和"【银两】"是同一件事的两种写法。
		rows.append("junk")
	var guard := 0
	var miss := 0
	while out.size() < max_items and guard < 500:
		guard += 1
		# 还有没有地方放"最小的一件"？没有就收工
		# ⚠ v59 修：这一句原来是 `_place(free, cols, 1)`——**它会把那一格吃掉**，
		#   于是每一轮循环都白白烧掉 1 格（24 格的仓实测浪费 2~3 格 ≈ 10%）。
		#   改问"放得下吗"（`_fits`，只读不动）。
		if not _fits(free, cols, 1):
			break
		# ⚠ 小仓（搜刮的 3~6 格）里，"大件/中件"很多是**放不下**或**那一阶没有**的——
		#   连空 40 次就认定这盘没货可摆了，别把 500 次 guard 白烧掉。
		if miss >= 40:
			break
		var row_k := _pick_row(rows, rng, free, cols, junk_w)
		if row_k == "":
			break
		if row_k == "junk":
			var jn := (rng.randi_range(FILLER_SMALL[0], FILLER_SMALL[1]) if rng != null
				else randi_range(FILLER_SMALL[0], FILLER_SMALL[1]))
			for j in jn:
				if not _put_filler(free, cols, out, rng, filler):
					break
			continue
		var color := _pick_color(row_k, ti, luck, rng, rate_mul)
		# v62：酒酿有**下限**（最低紫）——"最高红"那一头仍由货仓档位管。
		var cmin := str(ROW_MIN_COLOR.get(row_k, ""))
		if cmin != "" and color_rank(color) < color_rank(cmin):
			color = cmin
		# v62：红件的"留与不留"——酒酿那一行按 ROW_RED_KEEP（10%）掷，
		#   不留就落到**这一档允许的次高色**（金匮→金；便宜仓→它自己的上限色）。
		var keep := float(ROW_RED_KEEP.get(row_k, 1.0))
		if color == "red" and keep < 1.0 and (rng.randf() if rng != null else randf()) >= keep:
			color = ""
			for c_alt in ["gold", "purple", "blue"]:
				if allowed(ti, str(c_alt), _size_of(row_k)):
					color = str(c_alt)
					break
		if color == "":
			miss += 1
			continue
		var spec: Dictionary = (sl[row_k] as Dictionary).get(color, {})
		if spec.is_empty():
			miss += 1
			continue
		var q := -1
		if str(spec.get("q", -1)) == "slot":
			q = roll_slot_q(color, base_q, rng)
			if q < 0:
				miss += 1
				continue                 # "如果没有就没有"
		var made: Array = _make(Loot, row_k, color, q, rng, spec)
		if made.is_empty():
			miss += 1
			continue
		var got := false
		for e_v in made:
			var e: Dictionary = e_v
			if e.is_empty():
				continue
			var g := maxi(1, int(e.get("gap", 1)))
			if _place(free, cols, g):
				e["_row"] = row_k      # v62d：红色保底要用（返回前会擦干净）
				e["_col"] = color
				out.append(e)
				got = true
		miss = 0 if got else (miss + 1)
		# 紫/蓝的大件、中件**附赠杂物**——用户："杂物8【银两】" / "杂物5"
		#   ⚠ 货仓走 `filler = "silver"`（那一格就是银两）；搜刮走 `"junk"`（那一格是杂物，
		#     杂物卖了就是银两——「杂物【银两】」两种读法都成立，但**一张表**说了算）。
		var fl := int(spec.get("filler", 0))
		var fn := 0
		if fl == -1:
			fn = (rng.randi_range(FILLER_SMALL[0], FILLER_SMALL[1]) if rng != null
				else randi_range(FILLER_SMALL[0], FILLER_SMALL[1]))
		else:
			fn = fl
		for k2 in fn:
			if not _put_filler(free, cols, out, rng, filler):
				break
	# ── v62d：高档货仓的红色保底（3档1红 · 4档2红 · 5档3红）──
	#   ⚠ v62e（用户："搜刮也同理啊 不过搜刮没保底"）：**保底只给货仓**。
	#     搜刮那条走的是 `pity = false`（data_loot.roll_salvage 传的）——原因很实在：
	#     搜刮的容器有个"中了红闸就临时升到 2 档"（RED_PROMOTE）的机制，而 2 档正好
	#     是保底的起点，不关掉的话"翻个尸体也保底一件红"就荒谬了。
	#     颜色爆率两边**完全一样**（都走 _pick_color 的绝对爆率），差的只是这条保底。
	if pity:
		_apply_red_guarantee(out, ti, sl, Loot, rng, base_q)
	# 临时键擦干净——下游拿到的东西与以前一模一样
	for e2_v in out:
		var e2: Dictionary = e2_v
		e2.erase("_row")
		e2.erase("_col")
	return out

# ============================================================
# v62d：红色保底（用户："顶多货仓里面 高档的保底有一两件红 从3档开始…"）
#   做法：这一仓抽完之后数一数有几件红；不够就把**已有的普通件升级成同一行的红件**
#   （不是凭空塞一件——格子盘是排好的，塞会挤爆；升级只换内容、格子照旧）。
#   尺寸尽量按用户的"多半"来：3档要小红 · 4档小+中 · 5档小+中+大；
#   该尺寸这一仓没抽到就退而求其次（保底优先，尺寸其次）。
#   ⚠ 填充料（杂物/银两）不带 `_row`，不参与升级——它们是找零，不该变红。
# ============================================================
static func _apply_red_guarantee(out: Array, ti: int, sl: Dictionary, Loot,
		rng: RandomNumberGenerator, base_q: int) -> void:
	var spec: Dictionary = RED_GUARANTEE[clampi(ti, 0, RED_GUARANTEE.size() - 1)]
	var need := int(spec.get("n", 0))
	if need <= 0:
		return
	var have := 0
	for e_v in out:
		if str((e_v as Dictionary).get("_col", "")) == "red":
			have += 1
	var lack := need - have
	if lack <= 0:
		return
	var want: Array = (spec.get("sizes", []) as Array).duplicate()
	# 第一轮：按"想要的尺寸"升级
	lack = _red_upgrade_pass(out, sl, Loot, rng, base_q, want, lack)
	# 第二轮：想要的尺寸没货了——剩下的缺口用任何普通件补（保底优先）
	if lack > 0:
		lack = _red_upgrade_pass(out, sl, Loot, rng, base_q, [], lack)

static func _red_upgrade_pass(out: Array, sl: Dictionary, Loot,
		rng: RandomNumberGenerator, base_q: int, want: Array, lack: int) -> int:
	var used_sizes: Array = want.duplicate()
	for i in out.size():
		if lack <= 0:
			break
		var e: Dictionary = out[i]
		if not e.has("_row"):
			continue                                   # 填充料不参与
		if str(e.get("_col", "")) == "red":
			continue                                   # 已经是红
		var row := str(e.get("_row", ""))
		var size := _size_of(row)
		if not used_sizes.is_empty() and not used_sizes.has(size):
			continue
		var rspec: Dictionary = (sl[row] as Dictionary).get("red", {})
		if rspec.is_empty():
			continue
		var rq := -1
		if str(rspec.get("q", -1)) == "slot":
			rq = roll_slot_q("red", base_q, rng)
			if rq < 0:
				continue
		var made: Array = _make(Loot, row, "red", rq, rng, rspec)
		if made.is_empty():
			continue
		var ne: Dictionary = made[0]
		if int(ne.get("gap", 1)) > int(e.get("gap", 1)):
			continue                                   # 红的格子更宽就跳过，别挤坏已排好的盘
		ne["_row"] = row
		ne["_col"] = "red"
		out[i] = ne
		lack -= 1
		if not used_sizes.is_empty():
			used_sizes.erase(size)
	return lack

static func _pick_row(rows: Array, rng: RandomNumberGenerator = null,
		free: Array = [], cols := 0, junk_w := 0.0) -> String:
	# ⚠ 权重是**实测调出来的**（第一版小件 32 权重 → 回本率 300~1000%，因为
	#   "小件"里装着绝品突破丹 5200 两/格、血脉 280 两/2格——按"量"给权重就印钞）
	# ⚠ v59b（用户："稀有权重降低"）：`rare` **2 → 1**（砍一半）。
	#   缘由：木箱（680 两）实测 20000 仓——平均 599（回本 88%），但**中位只有 369**，
	#   90% 分位 1544、最高 8190：均值全靠稀有行那两件（血脉 280 / 上品丹 980，
	#   **固定估价、不随档位缩**）撑起的尾巴。玩家看到"680 的箱子出 1541"就是这条尾巴。
	#   稀有行权重减半 → 血脉/该色丹的出现率也减半（木箱从"每 4 仓一条血脉"变"每 8 仓"）。
	#   ⚠ 这一改**估值会掉**，五档的价必须跟着重跑重填（口径仍是回本率 ≈ 88%）。
	# v62（用户："洗灵丹和完整功法武器 权重再大幅度降低"）：
	#   完整功法/完整兵器 5.0 → **1.5**（砍七成）；洗灵丹见 rare 行的 also_chance（100% → 25%）。
	#   酒酿 6.0 是新入场的那一行——搜刮与货仓都抽得到（搜刮那头另有 junk_w 24 撑着杂物手感）。
	var w := {"big": 1.5, "big_gear": 1.5, "mid": 18.0, "mid_gear": 18.0, "small": 4.0, "rare": 1.0,
		"wine": 6.0, "junk": maxf(0.0, junk_w)}
	# 小盘（搜刮的 3~6 格）里"大件/中件"摆不下——**先把摆不下的行筛掉**再按权重抽，
	#   不然小容器会一直抽到摆不下的行、空转到 miss 保护才收工（几乎什么都给不出来）。
	var cand: Array = []
	for r in rows:
		if free.is_empty() or _fits(free, cols, int(ROW_W.get(str(r), 1))):
			cand.append(r)
	if cand.is_empty():
		return ""
	var total := 0.0
	for r3 in cand:
		total += float(w.get(str(r3), 1.0))
	if total <= 0.0:
		return str(cand[cand.size() - 1])
	var hit := (rng.randf() if rng != null else randf()) * total
	var acc := 0.0
	for r2 in cand:
		acc += float(w.get(str(r2), 1.0))
		if hit <= acc:
			return str(r2)
	return str(cand[cand.size() - 1])

# ============================================================
# v62d（用户："再说爆率 红爆率定的就是1%-2% 金10% 紫30% 【你看着分配】 然后再从里面选权重
#   目前可能还是太高了"）
#
#   原来的颜色是"**离上限越近越容易中**"（pow(COLOR_DECAY, 距离)）——贵仓的上限就是红，
#   于是金匮开出来**一半以上是红件**，"红"就不红了。现在改成**绝对爆率**（千分位直读）：
#
#     红 **1.5%**（用户给 1%~2%，取中值）· 金 **10%** · 紫 **30%** · 蓝 **58.5%**（余下）
#
#   · 这是**每一件**的爆率；`luck`（贵仓的好货率）只做**轻微**上偏，不再翻江倒海
#     （每高一阶 ×(1+0.15×luck)，金匮 luck 4.6 时红约 ×1.28，仍是个位数千分位）
#   · 货仓档位的"最高色"（TIER_CAP）照旧封顶：木箱/漆箱最高紫 → 抽到金/红会被压回紫，
#     只有 OVER_CAP_P 那条"越阶红"后门留一点（便宜仓也可能翻出红，但极低）
#   · 颜色定完**再按行权重挑**哪一行（big/mid/small/rare/wine…）——用户说的"再从里面选权重"
# ============================================================
const COLOR_RATE := [
	{"c": "red", "w": 15},        # 1.5%
	{"c": "gold", "w": 100},      # 10%
	{"c": "purple", "w": 300},    # 30%
	{"c": "blue", "w": 585},      # 58.5%（余下全给它）
]

# 高档货仓的**红色保底**（用户："从3档开始 保底一红【多半小红】4档保底2个红【多半小 中】
#   5档保底 3个红【小 中 大】"）
#   下标＝货仓档位（0=木箱 1=漆箱 2=铜锁 3=银扣 4=金匮）；sizes＝这几件红**尽量**落在哪些尺寸，
#   该尺寸没货时退而求其次（保底优先于尺寸——用户自己写的也是"多半"）。
const RED_GUARANTEE := [
	{"n": 0, "sizes": []},
	{"n": 0, "sizes": []},
	{"n": 1, "sizes": ["small"]},                  # 3 档（铜锁 12500）：保底 1 红 · 多半小红
	{"n": 2, "sizes": ["small", "mid"]},           # 4 档（银扣 18000）：保底 2 红 · 小·中
	{"n": 3, "sizes": ["small", "mid", "big"]},    # 5 档（金匮 23500）：保底 3 红 · 小·中·大
]

# v99（出征屏三档）：**这一趟的爆率倍率**——简单 0.5 / 普通 1.0 / 困难 2.0。
#   放在这里当静态变量（而不是去 preload GameState）是为了**不制造循环依赖**：
#   game_state 已经 preload 了本文件，本文件反过来读 game_state 会绕回去。
#   游历开局时由 journey_stage 从 GameState.deploy_drop_mul 抄进来，收尾时复位 1.0。
static var run_rate_mul := 1.0

static func _pick_color(row: String, tier_i: int, luck: float,
		rng: RandomNumberGenerator = null, rate_mul := 1.0) -> String:
	var ti := clampi(tier_i, 0, TIER_CAP.size() - 1)
	var cap_rank := color_rank(str((TIER_CAP[ti] as Dictionary).get("color", "red")))
	var size := _size_of(row)
	# ① 越阶红：**极低概率的后门**（尺寸越界、或"最高紫/最高金"那种整行不许红）
	#    ——"便宜仓红格子权重极低但仍可能中"。
	if not allowed(ti, "red", size):
		var p := (rng.randf() if rng != null else randf())
		if p < OVER_CAP_P:
			return "red"
	# ② v62d：颜色按**绝对爆率**摇（红 1.5% · 金 10% · 紫 30% · 蓝 58.5%），
	#    只在上限及以下的色里摇；`luck` 只做轻微上偏（每高一阶 ×(1+0.15×luck)）。
	var cand: Array = []
	var wt: Array = []
	var lk := maxf(0.0, luck)
	for e_v in COLOR_RATE:
		var e: Dictionary = e_v
		var cc := str(e.get("c", "blue"))
		if not allowed(ti, cc, size):
			continue
		cand.append(cc)
		# ⚠ v62d 实测修正：一开始给 0.15 的偏置，金匮（luck 4.6）一乘变成红 5.08% ✗
		#   （用户要的是 1~2%）。改成 **0.03**：金匮时红 ≈ 2.0%、紫 ≈ 31.6%，
		#   搜刮那种 luck 1.0 的 ≈ 红 1.6% —— 都在用户给的区间里。
		var w := float(e.get("w", 0)) * pow(1.0 + 0.03 * lk, float(color_rank(cc) - 1))
		# ============================================================
		# v62p（用户："这个短绳签的爆率指的是假如原红有1%的话 提升就是红1.5%
		#   所以并不高 算了 直接短绳加150% 爆率"）：
		#   **只放大「红」那一条**的权重 ×rate_mul，其余色不动、蓝照旧吃剩下的。
		#   为什么不是三色一起乘：这是**加权抽取**，三条一起乘、蓝不动的话
		#   各自反被摊薄（实测三色各只 +48% ✗，不是 +150%）。
		#   只乘红时：红权重 15 → 37.5，总权重 1000 → 1022.5，红 = **3.67%**
		#   （原 1.50%），正好是用户要的"×2.5"；金/紫/蓝几乎不动（各让出一点点）。
		#   ⚠ 于是"爆率 +150%"＝**红件出货率 ×2.5**，这才是那张签的实际口径。
		# ============================================================
		# v99：红与金两条一起受"这一趟的爆率"影响（困难 ×2 → 红 3%、金 20%）；
		#   紫/蓝照旧吃剩下的（加权抽取，不能三条一起乘，见上面那段）。
		var mult := maxf(0.0, rate_mul) * maxf(0.0, run_rate_mul)
		if (cc == "red" or cc == "gold") and not is_equal_approx(mult, 1.0):
			w *= mult
		wt.append(w)
	if cand.is_empty():
		return ""
	var total := 0.0
	for v in wt:
		total += float(v)
	if total <= 0.0:
		return str(cand[cand.size() - 1])
	var hit := (rng.randf() if rng != null else randf()) * total
	var acc := 0.0
	for i in cand.size():
		acc += float(wt[i])
		if hit <= acc:
			return str(cand[i])
	return str(cand[cand.size() - 1])

static func _size_of(row: String) -> String:
	if row == "big" or row == "big_gear":
		return "big"
	if row == "mid" or row == "mid_gear":
		return "mid"
	return row

static func _make(Loot, row: String, color: String, q: int, rng: RandomNumberGenerator,
		spec: Dictionary = {}) -> Array:
	var out: Array = []
	var qq := clampi(q, 0, 4)
	var size := _size_of(row)
	if size == "big" or size == "mid":
		var is_arts := row == "big" or row == "mid"
		var pool := "arts" if is_arts else ("weapon" if randf() < 0.5 else "gear")
		var sid := _pick_of_q(pool, qq, rng)
		if sid == "":
			return out               # 那一阶没有这种东西 → "没有就没有"
		if size == "big":
			# ⚠ v58 修（探针抓到的）：`Loot._item_entry()` 里 gap 写死 `ITEM_GAP = 4`，
			#   所以"完整功法占 10 格"这条规格**根本没生效**。这里按规格覆盖成 10 / 8。
			var e0: Dictionary = Loot._item_entry(sid)
			e0["gap"] = GAP_FULL_ART if row == "big" else GAP_FULL_GEAR
			out.append(e0)
		else:
			var parts: Array = Cards.by_id(sid).get("parts", [])
			# ⚠ v59 修（探针抓到 4847 次 `randi_range` on null）：这一句原来只判了
			#   `parts.size() > 0`，**漏了 rng != null**——而搜刮那头传的就是 null，
			#   于是"路上捡到的残卡"part 全是 null（探针刷了几千条错误）。
			var pi := 0
			if parts.size() > 0:
				pi = (rng.randi_range(0, parts.size() - 1) if rng != null
					else randi_range(0, parts.size() - 1))
			var e: Dictionary = Loot._card_entry(sid, true)
			e["part"] = pi
			e["name"] = Cards.card_name(sid, pi)
			e["gap"] = GAP_CARD_ART if row == "mid" else GAP_CARD_GEAR
			out.append(e)
		return out
	# ---- 酒酿（v62）：一件 3 格的酒，品级＝这一行的颜色 ----
	if row == "wine":
		out.append(Loot._wine_entry(color, qq, rng))
		return out
	# ---- 小 / 稀有那两行：**只有红那一行给成品丹**，金/紫/蓝给的是那一炉的**料** ----
	var with_pid := str(spec.get("with", ""))
	if row == "small":
		# 小红：1 炼丹材料 · **绝品突破丹1** · 角色碎片1
		# 蓝/紫/金小：1 炼丹材料 · 1（该色突破丹的）炼丹材料
		# ⚠ v62b（用户："洗灵丹现在不给材料了"）：原来小红还多塞一味**洗灵丹料**
		#   （`_mat_of_recipe(Loot, "xiling")` ＝ 金髓/朱果/灵米里随机一味）——**撤掉**。
		#   缘由：洗灵丹自己已经压到 1/25 的"极度稀有"，材料再顺手给，等于绕开那道闸
		#   （玩家攒够料就能在炼丹阁炼出来）→ 材料也不给了，整条线只留炼丹阁一条正经路。
		#   注：金髓本身另有来路（金箱材料池 · 货栈每日限购 1），不必从这儿出。
		out.append(_mat_entry(Loot, rng))
		if color == "red":
			out.append(Loot.tupo_by_id(with_pid))
		else:
			out.append(_mat_of_recipe(Loot, with_pid, rng))
		if str(spec.get("extra", "")) == "frag":
			out.append(_frag_entry(Loot, rng))
		return out
	# 稀有小金/紫/蓝：血脉2 · 该色突破丹1　｜　稀小红：血脉2 · 洗灵丹1（v61：洗髓丹已下线）
	out.append(_blood_entry(rng))
	if color == "red":
		var ac := float(spec.get("also_chance", 1.0))
		if ac >= 1.0 or rng.randf() < ac:   # v62：洗灵丹不再必给
			for pid in (spec.get("also", ["xiling"]) as Array):
				out.append(Loot.pill_by_id(str(pid)))
	else:
		out.append(Loot.tupo_by_id(with_pid))
	return out

static func _pick_of_q(pool: String, q: int, rng: RandomNumberGenerator) -> String:
	var cand: Array = []
	for d_v in Cards.SETS:
		var d: Dictionary = d_v
		var p := str(d.get("pool", ""))
		if pool == "arts":
			if p != "arts":
				continue
		elif pool == "weapon":
			if p != "weapon":
				continue
		else:
			if p != "armor" and p != "helm" and p != "cloak":
				continue
		if str(d.get("role", "")) != "":
			continue                 # 专武不落货仓
		if bool(d.get("no_drop", false)):
			continue
		if Cards.q_idx(str(d.get("id", ""))) == q:
			cand.append(str(d.get("id", "")))
	if cand.is_empty():
		return ""
	var i := (rng.randi_range(0, cand.size() - 1) if rng != null else randi_range(0, cand.size() - 1))
	return str(cand[i])

# v59（用户："开局五选一 · 给的完整"）：按"**单池** ＋ 品阶"抽一件**成品** id。
#   与 _pick_of_q 的区别：那个把护甲/玉佩/披风合成一个"装备"池（货仓抽货用），
#   开局那五张牌要分得清是哪一格，所以这里按单池抽。
#   本阶没货就**往下借**（装备没有绝品 → 绝品难度下装备仍给极品）；一阶都没有＝空串。
static func pick_of_q(pool: String, q: int, rng: RandomNumberGenerator = null) -> String:
	var top := clampi(q, 0, Cards.QUALITY_ORDER.size() - 1)
	for qq in range(top, -1, -1):
		var got := _pick_in_pool(pool, qq, rng)
		if got != "":
			return got
	return ""

# v59b：某一池里**所有**该品阶的可掉落套（专武/不掉落的除外）——货栈"补缺"挑范围也用它，
#   免得"哪些能掉"这件事在两处各写一遍（写岔了就会出现"补的是一张根本掉不出来的卡"）。
static func sets_of_q(pool: String, q: int) -> Array:
	var out: Array = []
	for d_v in Cards.SETS:
		var d: Dictionary = d_v
		if str(d.get("pool", "")) != pool:
			continue
		if str(d.get("role", "")) != "":
			continue                 # 专武不落货仓
		if bool(d.get("no_drop", false)):
			continue
		if Cards.q_idx(str(d.get("id", ""))) == clampi(q, 0, Cards.QUALITY_ORDER.size() - 1):
			out.append(str(d.get("id", "")))
	return out

static func _pick_in_pool(pool: String, q: int, rng: RandomNumberGenerator) -> String:
	var cand: Array = sets_of_q(pool, q)
	if cand.is_empty():
		return ""
	var i := (rng.randi_range(0, cand.size() - 1) if rng != null else randi_range(0, cand.size() - 1))
	return str(cand[i])

static func _mat_entry(Loot, rng: RandomNumberGenerator) -> Dictionary:
	var i := (rng.randi_range(0, Loot.MATS.size() - 1) if rng != null else randi_range(0, Loot.MATS.size() - 1))
	var m: Dictionary = Loot.MATS[i]
	return {"kind": "mat", "id": str(m.get("id", "")), "part": 0,
		"name": str(m.get("name", "炼丹材料")), "gap": GAP_SMALL, "red": false}

static func _mat_by_id(Loot, mid: String, rng: RandomNumberGenerator) -> Dictionary:
	for m_v in Loot.MATS:
		var m: Dictionary = m_v
		if str(m.get("id", "")) == mid:
			return {"kind": "mat", "id": mid, "part": 0,
				"name": str(m.get("name", "炼丹材料")), "gap": GAP_SMALL, "red": false}
	return _mat_entry(Loot, rng)

# ---- "某一炉丹的料"（规格里的"上品突破丹炼丹材料1""洗髓丹炼丹材料1"就是这一格）----
#   丹方在 `game_state.DAN_RECIPES`（那边才是唯一真源），这里**运行时**取一手：
#   不能 preload（game_state 会 preload 本文件，成环），所以用 load() 拿**同一份**缓存脚本。
static var _GS: GDScript = null

static func _recipes() -> Array:
	if _GS == null:
		_GS = load("res://shared/game_state.gd") as GDScript
	if _GS == null:
		return []
	return _GS.DAN_RECIPES

static func _mat_of_recipe(Loot, pid: String, rng: RandomNumberGenerator) -> Dictionary:
	for r_v in _recipes():
		var d: Dictionary = r_v
		if str(d.get("id", "")) != pid:
			continue
		var keys: Array = (d.get("cost", {}) as Dictionary).keys()
		if keys.is_empty():
			break
		var k := str(keys[(rng.randi_range(0, keys.size() - 1) if rng != null
			else randi_range(0, keys.size() - 1))])
		return _mat_by_id(Loot, k, rng)
	return _mat_entry(Loot, rng)

static func _frag_entry(Loot, rng: RandomNumberGenerator) -> Dictionary:
	var i := (rng.randi_range(0, Loot.FRAGMENTS.size() - 1) if rng != null else randi_range(0, Loot.FRAGMENTS.size() - 1))
	var f: Dictionary = Loot.FRAGMENTS[i]
	var n := (rng.randi_range(Loot.FRAG_PER_DROP[0], Loot.FRAG_PER_DROP[1]) if rng != null
		else randi_range(Loot.FRAG_PER_DROP[0], Loot.FRAG_PER_DROP[1]))
	return {"kind": "fragment", "id": str(f.get("id", "")), "part": 0, "amount": n,
		"name": str(f.get("name", "碎片")) + "×" + str(n), "gap": GAP_SMALL, "red": true}

static func _blood_entry(rng: RandomNumberGenerator) -> Dictionary:
	var DataPets = load("res://shared/data_pets.gd")
	var bid := str(DataPets.roll_blood(0))
	if bid == "":
		return {}
	var pur := (rng.randi_range(30, 100) if rng != null else randi_range(30, 100))
	var bq := int((DataPets.blood_of(bid) as Dictionary).get("q", 2))
	return {"kind": "blood", "id": bid, "pur": pur, "part": 0,
		"name": DataPets.blood_name(bid) + "（" + DataPets.quality_cn(bq) + "·纯" + str(pur) + "）",
		"gap": GAP_BLOOD, "red": true}

# 附赠杂物（用户写的是"杂物8【银两】"）——两张读法都落在这一格：
#   "silver"（货仓）＝**这一格就是银两**（用户字面）；"junk"（搜刮）＝**这一格是杂物**
#   （杂物卖了就是银两，且带品质色——v14 那套"垃圾银两收益"没被砍掉）。
#   ⚠ 数值是**杂物那个量级**（5~12 两/格）：原来一仓的"估值"有六七成是这一格撑起来的
#     （20~60 两/格 × 六七成格子），等于"花 1650 买回 1450 两银两"的空转。
#     现在银两是**找零**，值钱的是上面那几行。
#   ⚠ v59 补（换表时差点弄丢的三样）：搜刮的**普通丹**（强身/淬体/养灵）与**酒酿**
#     原来都在旧正常池里（pill 10 · wine 3 · silver 10）。酒酿接回来了，**丹也接回来**
#     （放在杂物那一格里，占 5%）——不然"养灵丹"就只剩炼丹阁一条路，
#     而它本来是路上最常见的那颗丹（宠物灵息那条线要靠它）。
static func _filler(rng: RandomNumberGenerator, kind := "silver") -> Dictionary:
	var lo := 5
	var hi := 12
	var amt := (rng.randi_range(lo, hi) if rng != null else randi_range(lo, hi))
	if kind == "junk":
		# 搜刮那一头的手感：杂物 87% / 银两 8% / **普通丹 5%**
		#   （旧池子是 junk 52 · mat 25 · pill 10 · silver 10 · wine 3 —— 材料与丹
		#     现在走阶梯表那几行，这里只补回"杂物格里的零碎"）
		#   ⚠ v62（用户："酒分品级 加入搜刮和货仓 最低紫 最高红 3格"）：
		#     原来这里有 **10% 的"1 格酒酿"**（无品级、白板）——现在酒有自己的行、
		#     有品级、占 3 格，再混一个"没品级的 1 格酒"就是两套口径打架，所以**撤掉**：
		#     那一份并给杂物（77% → 87%）。酒现在只能从"酒酿那一行"整坛地翻出来。
		var r := (rng.randf() if rng != null else randf())
		if r < 0.08:
			return {"kind": "silver", "id": "", "part": 0, "amount": amt, "name": "银两",
				"gap": GAP_SMALL, "red": false}
		if r < 0.13:
			var Loot2 = load("res://shared/data_loot.gd")
			return Loot2._pill_entry()
		var Loot = load("res://shared/data_loot.gd")
		return Loot._junk_entry()
	return {"kind": "silver", "id": "", "part": 0, "amount": amt, "name": "银两",
		"gap": GAP_SMALL, "red": false}