extends RefCounted
# ============================================================
# data_bonds.gd —— 上阵羁绊（㊽）
#
# 羁绊＝"谁和谁同时在阵里"给的加成。三人出战之后才有意义：
# 以前一队只上一个人，谈羁绊没有对象。
#
# 两种规模（都按"members 全在阵里"判，少一个就不生效）：
#   · 两人羁绊：flat 里各给各的——陈石加防、少侠加攻，各拿各的那一份
#   · 三人羁绊：pct_all 给全队按百分比加（"全属性 +10%"）
#
# ⚠ 只在"村内一队"这套口径里生效：出村战斗、弟子面板、离线爬塔估算。
#   **游历不带羁绊**——那是单人上路，没有同伴（快照从 effective_stats 取，
#   而 effective_stats 里没有羁绊，所以天然带不出去。别把它挪进去）。
#
# 纯数据，不 preload 任何东西（谁都能引，不会成环）。
# ============================================================

# 百分比加成作用在哪几项上（"全属性"的落地范围）。
#   没放 crit_dmg：它是"倍率"不是"属性"，+10% 从 50% 变 55% 说不清；
#   也没放 dmg（伤害加成本身就是百分比，再乘一层容易看糊涂）。
const PCT_KEYS := ["atk", "hp", "def", "spd", "crit", "dodge"]

const BONDS := [
	{
		"id": "shitu",
		"name": "师徒",
		"members": ["player", "chen_shi"],
		"who": "少侠 · 陈石",
		"desc": "少侠把陈石从山里带出来，一个肯教、一个肯学。",
		"flat": {
			"player": {"atk": 10},
			"chen_shi": {"def": 5},
		},
	},
	{
		"id": "tongmen",
		"name": "同门",
		"members": ["chen_shi", "qingluan"],
		"who": "陈石 · 苏青鸾",
		"desc": "两个弟子搭手搭惯了：一个顶在前面挡，一个绕到后面打。",
		"flat": {
			"chen_shi": {"def": 3, "hp": 10},
			"qingluan": {"crit": 3},
		},
	},
	{
		"id": "santong",
		"name": "三人同心",
		"members": ["player", "chen_shi", "qingluan"],
		"who": "少侠 · 陈石 · 苏青鸾",
		"desc": "三个人一条心，谁也不用回头看。",
		# v62（伤害增幅减半）：pct_all 是**百分比**（不是点数），按同一条尺子减半；暴击 7 → 5（×0.7）
		"pct_all": {"atk": 5, "hp": 5, "def": 5, "spd": 5, "crit": 5, "dodge": 5},
	},
]

static func all() -> Array:
	return BONDS

static func of(bid: String) -> Dictionary:
	for b in BONDS:
		if str(b.get("id", "")) == bid:
			return b
	return {}

# 这一条现在生效吗——members 得一个不少地在阵里
static func is_on(bond: Dictionary, formation: Array) -> bool:
	var ms: Array = bond.get("members", [])
	if ms.size() < 2:
		return false
	for m in ms:
		if not formation.has(str(m)):
			return false
	return true

# 当前阵里活着的羁绊（给界面用）
static func active(formation: Array) -> Array:
	var out: Array = []
	for b in BONDS:
		if is_on(b, formation):
			out.append(b)
	return out

# 还差谁（给"未生效"那一栏提示用）
static func missing(bond: Dictionary, formation: Array) -> Array:
	var out: Array = []
	for m in bond.get("members", []):
		if not formation.has(str(m)):
			out.append(str(m))
	return out

# 某个角色从羁绊里拿到多少：{"flat": {...}, "pct": {...}}
#   flat＝直接加到属性上；pct＝按百分比放大（100 表示 +100%）
static func fx_for(role_id: String, formation: Array) -> Dictionary:
	var flat: Dictionary = {}
	var pct: Dictionary = {}
	for b in BONDS:
		if not is_on(b, formation):
			continue
		var f: Dictionary = b.get("flat", {})
		if f.has(role_id):
			var mine: Dictionary = f[role_id]
			for k in mine.keys():
				flat[k] = int(flat.get(k, 0)) + int(mine[k])
		var pa: Dictionary = b.get("pct_all", {})
		for k2 in pa.keys():
			pct[k2] = float(pct.get(k2, 0.0)) + float(pa[k2])
	return {"flat": flat, "pct": pct}

# 把羁绊加成打在属性字典上（原地改 out；与 _merge_stats 同口径）
#   顺序：先乘百分比、再加平面值——"全属性 +10%"按"自己原本的底子"算，
#   不吃后面刚加上的那 10 点（否则两条羁绊叠起来会互相放大）。
#   ⚠ v48：`pct_all` 的键**只认 PCT_KEYS 那几个**（atk/hp/def/spd/crit/dodge）——
#     往 pct_all 里写 `dmg` / `crit_dmg` 会被**静默忽略**（那两条本身就是百分比属性，
#     再乘一层容易看糊涂；要给就给 flat）。另外 `crit` 在这一层是**乘**不是加点：
#     写 10 就是"暴击点数 ×1.1"（10 点 → 11 点），文案见 pct_text，别写成"暴击 +10%"。
static func apply_to(out: Dictionary, role_id: String, formation: Array) -> void:
	var fx := fx_for(role_id, formation)
	var pct: Dictionary = fx["pct"]
	for k in PCT_KEYS:
		var p := float(pct.get(k, 0.0))
		if p != 0.0 and out.has(k):
			out[k] = int(round(float(out[k]) * (1.0 + p / 100.0)))
	var flat: Dictionary = fx["flat"]
	for k2 in flat.keys():
		out[k2] = int(out.get(k2, 0)) + int(flat[k2])

# 一句话摘要（面板那一行）
static func line_for(formation: Array) -> String:
	var on := active(formation)
	if on.is_empty():
		return "无（需两人以上同时在阵里）"
	var names: Array = []
	for b in on:
		names.append(str(b.get("name", "")))
	return "、".join(PackedStringArray(names))

# 效果明细：把 fx_for 的结果写成"攻击 +10、防御 +5、暴击 +5%"这种
#   暴击/暴击伤害/伤害加成本身就是百分比属性——写出来必须带 %，
#   不然"暴击 +5"会让人以为是 +5 点（面板上 5 和 5% 差着 100 倍）。
#   ⚠ v35：**闪避移出这一张**——闪避改成"数值"了（与防御一样，两个数对拼，
#     见 game_data.dodge_rate 与角色面板的说明），不再带 %。
const PCT_STATS := ["crit", "crit_dmg", "dmg"]

# ㊿：出征屏那一行用——把"现在生效的羁绊"连效果写成一段（**一条羁绊一行**）：
#   "师徒（少侠 攻击 +10 · 陈石 防御 +5）\n三人同心（全队 攻击·气血·防御·速度·暴击·闪避 各 +10%）"
#   两人羁绊是"各拿各的那一份"（flat 是按人写的），三人羁绊是"全队按百分比"（pct_all）。
# ㊿s：原来三条挤成一句（"、"连起来），三条全生效时 123 个字 → 出征屏那一格
#   （584×56，13 号字）要 3 行 54px，字体一换/字号一改就压到下面"二 · 选路"上。
#   现在一条一行：每行最多 33 字，框给到 62px，稳稳三行。
static func summary_line(formation: Array) -> String:
	var on := active(formation)
	if on.is_empty():
		return ""
	var parts: Array = []
	for b_v in on:
		var b: Dictionary = b_v
		var seg: Array = []
		var flat: Dictionary = b.get("flat", {})
		for rid in flat.keys():
			var mine: Dictionary = flat[rid]
			var one: Array = []
			for k in mine.keys():
				var kk := str(k)
				var tail := "%" if PCT_STATS.has(kk) else ""
				one.append(stat_cn(kk) + " +" + str(int(mine[k])) + tail)
			seg.append(role_cn(str(rid)) + " " + "、".join(PackedStringArray(one)))
		var pa: Dictionary = b.get("pct_all", {})
		if not pa.is_empty():
			seg.append("全队 " + pct_text(pa))
		parts.append(str(b.get("name", "")) + "（" + " · ".join(PackedStringArray(seg)) + "）")
	return "\n".join(PackedStringArray(parts))

# ㊿s：百分比那一串——几项数值一样就合成一句（"攻击·气血·防御·速度·暴击·闪避 各 +10%"），
#   不一样才逐项列。三人同心是六项全 +10%，逐项列要 48 个字，出征屏那一格放不下。
#   ⚠ v48：这些数都是**乘在属性上的比例**（见 apply_to）——对 atk/hp/def/spd/dodge 说
#     "+10%"就是"那一项 ×1.1"，没问题；但 **crit 本身就是"百分点"属性**，
#     写"暴击 +10%"会被读成"加 10 个点"。所以 crit 单独写成"×1.1"那种写法。
static func pct_text(pa: Dictionary) -> String:
	var keys: Array = []
	for k in pa.keys():
		keys.append(str(k))
	if keys.is_empty():
		return ""
	var same := true
	var first := int(pa[keys[0]])
	for k in keys:
		if int(pa[k]) != first:
			same = false
			break
	if same and keys.size() > 1:
		var names: Array = []
		for k in keys:
			names.append(stat_cn(k))
		var allpct := true
		for k in keys:
			if str(k) == "crit":     # 暴击那一项是"点数的倍数"，得单独说
				allpct = false
		if allpct:
			return "·".join(PackedStringArray(names)) + " 各 +" + str(first) + "%"
	var one: Array = []
	for k in keys:
		var kk := str(k)
		if kk == "crit":
			one.append("暴击 ×" + str(snappedf(1.0 + float(pa[k]) / 100.0, 0.01)))
		else:
			one.append(stat_cn(kk) + " +" + str(int(pa[k])) + "%")
	return "、".join(PackedStringArray(one))

# ㊿：一条都还没成的时候，给一句"还差谁"——出征屏最容易犯的错就是少带一个人
static func hint_line(formation: Array) -> String:
	if active(formation).size() > 0:
		return ""
	var best: Dictionary = {}
	var best_n := 99
	for b_v in BONDS:
		var b: Dictionary = b_v
		var miss := missing(b, formation)
		if miss.size() < best_n:
			best_n = miss.size()
			best = b
	if best.is_empty() or best_n <= 0:
		return ""
	var names: Array = []
	for m in missing(best, formation):
		names.append(role_cn(str(m)))
	return "带上 " + "、".join(PackedStringArray(names)) + " 就能成「" + str(best.get("name", "")) + "」"


static func fx_text(fx: Dictionary) -> String:
	var parts: Array = []
	var flat: Dictionary = fx.get("flat", {})
	for k in flat.keys():
		var kk := str(k)
		var tail := "%" if PCT_STATS.has(kk) else ""
		parts.append(stat_cn(kk) + " +" + str(int(flat[k])) + tail)
	var pct: Dictionary = fx.get("pct", {})
	for k2 in pct.keys():
		parts.append(stat_cn(str(k2)) + " +" + str(int(pct[k2])) + "%")
	if parts.is_empty():
		return "（这个人不吃这条羁绊）"
	return "、".join(PackedStringArray(parts))

const STAT_CN := {
	"atk": "攻击", "hp": "气血", "spd": "速度", "crit": "暴击",
	"dmg": "伤害加成", "def": "防御", "dodge": "闪避", "crit_dmg": "暴击伤害",
}

static func stat_cn(k: String) -> String:
	return str(STAT_CN.get(k, k))

const ROLE_CN := {"player": "少侠", "chen_shi": "陈石", "qingluan": "苏青鸾"}

static func role_cn(rid: String) -> String:
	return str(ROLE_CN.get(rid, rid))
