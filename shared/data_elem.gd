extends RefCounted
# ============================================================
# data_elem.gd —— **五行元素唯一真源**（v58）
#
# 用户原话（六条，逐条落在这里）：
#   1. "元素武器从上品开始 元素是随机给的"
#   2. （升星部分在 game_state / star_panel，不在本文件）
#   3. "元素伤害类型和物理类型不同 它造成伤害为 0.8【暂时 不合理再改】
#       同时伤害的增幅也要做出区分【火元素伤害增加%】【物理伤害增加%】【全伤害增加%】"
#   4. "防御只对物理有效 且元素伤害无法暴击 同时给出新防御 火元素抗性% 水元素抗性% 等"
#   5. （五条元素印记在 data_status.gd，本文件只给它们提供"吃哪个加成"的键名）
#   6. "上品功法部分改为不同元素 当元素不合时 倍率降低 效果降低"
#
# 三条硬口径（改数就改下面这几个常量，别在引擎里另写一份）：
#   · **元素伤害通道**：base × ELEM_BASE × (1 + (全伤害 + 该元素伤害)/100) × (1 − 抗性)
#       - 不吃防御（`GameData.def_cut` 只走物理）
#       - **不可暴击**（引擎里元素那一路直接跳过 crit 判定）
#   · **物理通道**：老样子（吃防御、可暴击），增幅改成 (1 + (全伤害 + 物理伤害)/100)
#   · 属性的三个口径分家（用户第 3 条）：
#       `dmg`        ＝ **全伤害增加%**（原来那一条，物理与元素都吃——所以老表一个字不用改）
#       `phys_dmg`   ＝ 物理伤害增加%（只加物理）
#       `<elem>_dmg` ＝ 火/水/金/木/土 元素伤害增加%（只加对应元素）
#   · 抗性五个键 `fire_res` … `earth_res`（百分点，可正可负）：
#       正＝减伤、负＝增伤（「水浸·踏浪」就是把对手的水抗夺成负的）
#       封顶 ±（见 RES_CAP / RES_FLOOR）
#
# ⚠ 与 Cards.ELEM_CN 的关系：那边是**给卡表用的显示名**（含 phys/true），这里是**真源**。
#   两张表内容一致，本文件是后来者、也是引擎唯一该读的那张。
# ============================================================

# 五行（相生顺序：金→水→木→火→土。顺序只影响"显示与遍历"，不影响数值）
const ORDER := ["metal", "water", "wood", "fire", "earth"]

const CN := {
	"metal": "金", "water": "水", "wood": "木", "fire": "火", "earth": "土",
	"phys": "物理", "true": "真实",
}

# 五行配色（面板/浮字/印记芯片都用它；跟着"五行习惯色"走，不跟品质色撞）
const COL := {
	"metal": Color(0.78, 0.72, 0.36),
	"water": Color(0.26, 0.48, 0.72),
	"wood": Color(0.28, 0.56, 0.30),
	"fire": Color(0.80, 0.32, 0.16),
	"earth": Color(0.56, 0.42, 0.24),
	"phys": Color(0.42, 0.40, 0.42),
	"true": Color(0.72, 0.28, 0.58),
}

# ---- 三条硬口径 ----
const ELEM_BASE := 0.8      # 用户第 3 条："造成伤害为 0.8【暂时 不合理再改】"
const RES_CAP := 0.75       # 抗性减伤上限（七成半）
const RES_FLOOR := -0.60    # 抗性下限（负抗性＝吃更多，最多多挨六成）
const MIN_TIER := 2         # 用户第 1 条："元素武器从上品开始"（凡 0 / 良 1 / 上 2 / 极 3 / 绝 4）
const NO_ELEM := ""         # 空串＝没有元素＝走物理

static func is_elem(e: String) -> bool:
	return ORDER.has(e)

static func cn(e: String) -> String:
	if e == "":
		return CN["phys"]
	return str(CN.get(e, e))

static func col(e: String) -> Color:
	if e == "":
		return COL["phys"]
	return COL.get(e, COL["phys"])

# "金木水火土"一行（面板标题用）
static func all_cn(sep := "") -> String:
	var out: Array = []
	for e in ORDER:
		out.append(CN[e])
	return sep.join(PackedStringArray(out))

# ---- 属性键 ----
# 增伤键：元素 → `<elem>_dmg`；物理 → `phys_dmg`；真实 → "（不吃增伤）"
static func dmg_key(e: String) -> String:
	if e == "" or e == "phys":
		return "phys_dmg"
	if e == "true":
		return ""
	return e + "_dmg"

static func res_key(e: String) -> String:
	if not is_elem(e):
		return ""
	return e + "_res"

# 本系统新加的全部属性键（面板要一行行列出来，effective_stats 也要照它兜底）
static func stat_keys() -> Array:
	var out: Array = ["phys_dmg", "all_dmg"]
	for e in ORDER:
		out.append(e + "_dmg")
	for e in ORDER:
		out.append(e + "_res")
	return out

# 面板上那两组的显示名（键 → 中文）
static func stat_cn(k: String) -> String:
	if k == "all_dmg":
		return "全伤害增加"
	if k == "phys_dmg":
		return "物理伤害增加"
	if k.ends_with("_dmg"):
		return cn(k.substr(0, k.length() - 4)) + "元素伤害增加"
	if k.ends_with("_res"):
		return cn(k.substr(0, k.length() - 4)) + "元素抗性"
	return k

# ============================================================
# 摇元素（用户第 1 条："元素是随机给的"）
#   ⚠ v58 补（用户："武器随机元素 也会随到空的 也就是物理 因为物理也是类型伤害 不要忘了"）：
#     **"物理"也是一档**——摇的时候会摇到它。摇到物理的那一把：
#       · 打出去走物理通道（吃防御、可暴击）
#       · 它给的那条加成从 `<元素>_dmg` 换成 **`phys_dmg`（物理伤害增加%）**
#         ——所以"上品兵器必有一条类型增伤"这件事**不会因为摇到物理就落空**
#     摇法：六等分（金木水火土 + 物理），见 ROLL_POOL；想调比例就改 POOL_WEIGHT。
# ============================================================
const ROLL_POOL := ["metal", "water", "wood", "fire", "earth", "phys"]
# 每个结果一份权重（现在六等分＝物理 1/6 ≈ 16.7%）。想"物理更少见"就把 phys 调小
const POOL_WEIGHT := {"metal": 1.0, "water": 1.0, "wood": 1.0, "fire": 1.0, "earth": 1.0, "phys": 1.0}

# 给一个"品级序"（q_idx：凡0 良1 上2 极3 绝4）——**上品（2）起才有元素**
static func tier_has_elem(q: int) -> bool:
	return q >= MIN_TIER

# 摇一个：可以摇到 "phys"（＝这一把不带五行，走物理）。weights 空＝按 POOL_WEIGHT
static func roll(rng: RandomNumberGenerator = null, weights: Dictionary = {}) -> String:
	var pool := ROLL_POOL
	var total := 0.0
	for e in pool:
		total += maxf(0.0, float(weights.get(e, POOL_WEIGHT.get(e, 1.0))))
	if total <= 0.0:
		total = float(pool.size())
	var hit := (rng.randf() if rng != null else randf()) * total
	var acc := 0.0
	for e in pool:
		acc += maxf(0.0, float(weights.get(e, POOL_WEIGHT.get(e, 1.0))))
		if hit <= acc:
			return str(e)
	return str(pool[pool.size() - 1])

# 这一档能不能挂徽章/算不算"有类型"（物理与真实也算类型——用户："物理也是类型伤害"）
const BADGE := {"metal": "金", "water": "水", "wood": "木", "fire": "火", "earth": "土",
	"phys": "物", "true": "真"}

static func markable(e: String) -> bool:
	return BADGE.has(e) and e != ""

static func badge_cn(e: String) -> String:
	return str(BADGE.get(e, "?"))


# ============================================================
# 伤害通道（两套引擎都只调下面这几个）
# ============================================================
# 增伤倍率：全伤害(dmg) + all_dmg + 该元素/物理专属。返回**倍率**（1.0＝不加不减）
#   ⚠ 这里刻意把 `dmg` 与 `all_dmg` **都**算进去：`dmg` 是老表里的"增伤"（用户第 3 条
#     把它定义成【全伤害增加%】），`all_dmg` 是本次新加的同一个意思的键——
#     老表写 `dmg`、新表写 `all_dmg`，两条并存不会互相吃掉。
static func atk_bonus(stats: Dictionary, e: String) -> float:
	var b := float(stats.get("dmg", 0)) + float(stats.get("all_dmg", 0))
	var k := dmg_key(e)
	if k != "":
		b += float(stats.get(k, 0))
	return maxf(0.05, 1.0 + b / 100.0)

# 走的是元素通道吗（空串＝物理；真实伤害两套都不走）
static func is_elem_attack(e: String) -> bool:
	return is_elem(e)

# 抗性减伤：resist_pct 是百分点。返回**受伤害倍率**
#   正抗性：×(1−r)；负抗性：×(1+|r|)。上下都封顶（见 RES_CAP / RES_FLOOR）
static func res_mul(resist_pct: float) -> float:
	var r := clampf(resist_pct / 100.0, RES_FLOOR, RES_CAP)
	return maxf(0.05, 1.0 - r)

# 一条攻击的基础倍率：元素 ×ELEM_BASE；物理 ×1
static func channel_mul(e: String) -> float:
	return ELEM_BASE if is_elem(e) else 1.0

# 元素伤害不吃暴击（引擎里用这一句当开关，别再各写一遍）
static func can_crit(e: String) -> bool:
	return not is_elem(e)

# 元素伤害不吃防御（同上）
static func use_defense(e: String) -> bool:
	return not is_elem(e)

static func line(e: String) -> String:
	if e == "" or e == "phys":
		return "物理"
	return cn(e) + "属性"

# ============================================================
# v58（用户第 6 条）：**上品功法部分带元素；元素不合时倍率降低、效果降低**
#   口径：武学表里写了 `elem` 的（上品及以上的一部分），
#     出手时拿**手里那把兵器的元素**去比：
#       · 兵器元素 == 武学元素        → 全效（×1.0）
#       · 兵器是别的元素 / 没元素      → **倍率 ×0.70、附带效果也 ×0.70**
#       · 武学没写元素                → 与元素无关（×1.0）
#   注意：武学带元素时，**这一手就是元素伤害**（走元素通道：不吃防御、不可暴击），
#     这一条优先级高于兵器（见 duel_battle._atk_elem）。
#   ⚠ 与"兵器要求"（`off_mult`）是两回事：那个管"是不是趁手的兵器类型"，
#     这个管"五行合不合"——两条可以同时打折（不趁手 + 元素不合）。
# ============================================================
const ART_MISMATCH := 0.70     # 元素不合：倍率与效果都打七折

# 返回这一手的"合不合"倍率（1.0＝全效）
static func art_fit(weapon_elem: String, art_elem: String) -> float:
	if art_elem == "":
		return 1.0
	if weapon_elem == art_elem:
		return 1.0
	return ART_MISMATCH

static func art_mismatch_note(weapon_elem: String, art_elem: String) -> String:
	if art_elem == "" or weapon_elem == art_elem:
		return ""
	return "元素不合（手里是" + line(weapon_elem) + "，这门是" + cn(art_elem) + "）——倍率与效果 ×" + str(snappedf(ART_MISMATCH, 0.01))

