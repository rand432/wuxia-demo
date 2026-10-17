extends RefCounted
# ============================================================
# run_state.gd —— 一局的全部数据与规则（不碰界面）v22
# v22（㊺）：①入口卡闸恢复"村里也算"口径——㊵ 误删，核过 game_state：
#   vault_count(sid, part) / vault_item_count(sid) 都是真函数（存档"仓库残卡/装备操作"段），
#   村里仓库有首片/成品也算"到手"；②请卡——三种都可重复请、叠着生效（专属只出本角色那三张）。
# v22b（㊿c2）：命数前缀修正——begin_formal 双认「fate_xxx」与「xxx」：出征屏交来的是全 id，
#   旧写法再加一层前缀＝「fate_fate_xxx」，六张命数集体失效；两种写法现在都落成规范 id。
# v21（优化批㉔）：运签（增益卡组）——buffs 一栏＋buff_fx 汇总＋请签接口；续行快照带上。
# v20（优化批⑰）：同款替换的账掰正——合成/拾到与身上同名的装备再点"替换"时，
#   落包的那件不盖"village"章：结算按包裹未盖章件入仓库，多出的一件不再被吞
#   （顺带焊上⑮留的"同名窄缝"）；这类操作的文案也从"已换上"改成"同款替换"。
# v19（优化批⑮）：村里出身的件被换下/卸下时，落包打"village"标记——
#   结算不再把它当战利品重复入库（配套 journey_settle v3 的两道闸）。
# v18（优化批⑭/#3/#5）：「卸下来算」＋随身三件套槽——
#   ①功法栏 4→3（ART_SLOTS=3；村里口径 3 功法＋大招＋被动，被动不占格）；
#   ②新增 run_gear（护甲/玉佩/披风）：出征时装村里那套；趟内可用包裹里的件换装
#     （村里仓库趟内不可取）；换下的旧件进包裹；
#   ③出征快照 carry_stats 先把随身兵器/装备/功法整份扣掉（卸下来算）——加成改由
#     槽位现算，修掉"武学加成被算两遍"的老坑；村里账本一个字不写（红线）；
#   ④兵器起点记在 base_weapon：没换装时按它算加成与招路；换装后被盖过；卸下复现。
#     run_base_gear：出发随身清单——给结算"过滤村里出身的旧件"留的（settle 下批接）。
# v17（⑫/#21）：随身兵器与功法加成走 GameState.starred_stats（升星生效）。
#   v35：星**记在件上**（不再按人记）——同一件换谁拿都是同一个乘率，所以这一口不再问主人。
# v16（⑧）：包裹容量接随行背包。  v15（④b）：续行存档。  v14：卡池换届同步。
# v13：run_base_arts。  v12：货价品级化。  v11：last_foe。  v10：警戒＋临时仓库。
# v9：池位闸。  v8：R1 出征底座。  v7：天赋 fx 归一。  v6：name_of 改名。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const Roles := preload("res://journey/data_roles.gd")
const Talents := preload("res://shared/data_talents.gd")
const GameState := preload("res://shared/game_state.gd")
const Ladder := preload("res://shared/data_ladder.gd")   # v112：货摊按品级取件（pick_of_q）
const Loot := preload("res://shared/data_loot.gd")
const Buffs := preload("res://shared/data_buffs.gd")
const Bonds := preload("res://shared/data_bonds.gd")   # ㊽：上阵羁绊（纯数据，无循环）
const Tuning := preload("res://shared/tuning.gd")   # ㉚：货价梯子读它

const BAG_MAX := 8
const ART_SLOTS := 3
const START_MONEY := 50

# 优化批⑭：随身三件套的槽位与汉名（内部键 helm = 玉佩）
const GEAR_SLOTS := ["armor", "helm", "cloak"]
const SLOT_CN := {"armor": "护甲", "helm": "玉佩", "cloak": "披风"}

# ---- R3 警戒规则（数值集中在这；宠物 alert_cap / alert_rate 在上面叠） ----
const ALERT_MAX := 100.0          # 触发线（满 = 遭遇战、敌先手）
const ALERT_OPEN := 10.0          # 开容器
const ALERT_REVEAL := 8.0         # 每揭晓 1 件
const ALERT_TAKE := 2.0           # 每拿取 1 件
const ALERT_NODE_DROP := 15.0     # 每通过 1 个节点（直减）

const MOVE_TABLE := {
	"sword": ["chop", "cut", "slice", "stab"],
	"dual": ["dual_chop", "dual_alt", "dual_rip", "dual_thrust"],
	"dagger": ["dagger_slash", "dagger_stab", "dagger_flurry"],
	"spear": ["spear_thrust", "spear_multi", "spear_turn"],
	"anqi": ["anqi_throw", "sweep"],
	"fist": ["fist_punch", "fist_palm", "fist_kick", "fist_combo"],
}

var bag: Array = []
var money := 0

# ---- R3：警戒 + 临时仓库（趟内状态；失败全丢） ----
var alert := 0.0
var loot_bag: Array = []
var last_foe: Dictionary = {}      # 最近一场敌阵容（{name, foe, money}；遭遇敌源第二级）

# ---- R1 出征底座 ----
var mode := "intro"          # "intro" 五问引子趟 / "formal" 出征屏正式趟
var diff := 0                # 正式趟的难度档（1~10；引子趟恒 0）
# ---- v107：事件卡与支线（**善恶只限这一趟**，用户 2026-10-08 定）----
#   karma     ：−100 ~ +100，开局 0；五档被动（恶贯满盈/恶名/中立/侠名/大侠）
#   ev_lines  ：线 id → 已走到第几步（走上一步就 +1）
#   ev_flags  ：这趟的标记（"letter"/"debt_book"/"nameplate"…）
#   ev_seen   ：见过的卡 id（同趟不重复出）
#   ev_pending：下一步指定要出的卡（连锁 / 线的下一步）
#   ev_done   ：走完的线 id（结局看它）
var karma := 0
var ev_lines: Dictionary = {}
var ev_flags: Array = []
var ev_seen: Array = []
var ev_pending: String = ""
var ev_done: Array = []
# ---- 优化批㉓：出征屏买的"临时扩仓"（只顶这一趟） ----
var run_expand := 0                  # 本趟额外格数（bag_cap 里叠；结算即失效）
# ---- 优化批㉔：卡组（增益；只在这趟生效，带不出去） ----
var buffs: Array = []                # 已请的卡 id（三种都可重复叠；专属只对卡上那个人）
# ---- v23（用户："进入游历第一节 根据当前难度 给予五个选项…五选一"）：开局行装 ----
#   kit_taken  ＝ 这一趟领过没有（摆出那一页就先记上，随续行档走——强杀重进不重复领）
#   kit_money_pct ＝ 选了"文钱"那一张才有（本趟文钱收益加成，0 ＝ 没拿）
var kit_taken := false
var kit_money_pct := 0.0

# ============================================================
# ㊿：三人成队——成员表
#
# 一趟最多带 PARTY_MAX 个人。**每人一份**：出发快照、随身三样、气血、
# 功法、天赋。队伍级的东西（包裹、盘缠、警戒、临时仓库、卡组、扩仓）
# 留在上面那几个 var 里，全队共用。
#
# ⚠ 关键设计：下面那十几个成员字段**名字一个没改**，只是从普通 var 变成了
#   "转发到当前成员"的属性（带 get/set）。这样 journey 那一百多处
#   `_state.role_id` / `_state.hp` / `_state.arts` … 一个字都不用动，
#   而"当前成员"由 active_i 决定（角色面板切换时改它）。
#   换存储不换接口——这是这次改造能不炸的原因。
# ============================================================

const PARTY_MAX := 3

var members: Array = []       # 每项见 _blank_member()
var active_i := 0             # 当前"对谁操作"（面板/换装/结算挨个来）

static func _blank_member() -> Dictionary:
	return {
		"role_id": "player",
		"carry_stats": {},          # 正式趟：村账快照（随身三样已"卸下扣净"）
		"hp": 100,
		"hp_max": 100,
		"arts": [],                 # 随身功法（最多 ART_SLOTS 个）
		"art_cd": {},               # 功法冷却（只在战斗里用）
		"talents": [],              # 五问天赋名（结算与战斗都读它）
		"base_weapon": "",          # 出发随身兵器——没换装时按它算
		"run_gear": {},             # 随身三件套：slot → sid
		"run_base_gear": {},        # 出发时的三件套清单（结算过滤用）
		"run_base_arts": [],        # 出发时随身功法（结算分辨"趟内新学"）
		"equipped_item": "",        # 趟内换上的兵器（空＝还用 base_weapon）
		"weapon_kind": "",          # 旧版遗留（现由 base_weapon 承担；空着即可）
	}

# 当前成员（空表就补一个——防"还没 reset 就被读到"）
func _m() -> Dictionary:
	if members.is_empty():
		members.append(_blank_member())
	active_i = clampi(active_i, 0, members.size() - 1)
	return members[active_i]

func member_count() -> int:
	return maxi(1, members.size())

func use_member(i: int) -> void:
	active_i = clampi(i, 0, maxi(0, members.size() - 1))

func active_role() -> String:
	return str(_m().get("role_id", "player"))

# ㊿：这趟带了谁（按队伍顺序）。重开一趟、结算、出征屏回显都读它。
func party_role_ids() -> Array:
	var out: Array = []
	for m_v in members:
		var m: Dictionary = m_v
		var r := str(m.get("role_id", ""))
		if r != "" and not out.has(r):
			out.append(r)
	if out.is_empty():
		out.append("player")
	return out

# 取某个成员的只读视图（战斗/结算要挨个算，又不想动 active_i 时用它）
func member_at(i: int) -> Dictionary:
	if i < 0 or i >= members.size():
		return _m()
	return members[i]

# ---- 成员字段的转发属性（名字与旧 var 完全一致）----

var role_id: String:
	get:
		return str(_m().get("role_id", "player"))
	set(v):
		_m()["role_id"] = str(v)

var hp: int:
	get:
		return int(_m().get("hp", 100))
	set(v):
		_m()["hp"] = int(v)

var hp_max: int:
	get:
		return int(_m().get("hp_max", 100))
	set(v):
		_m()["hp_max"] = int(v)

var carry_stats: Dictionary:
	get:
		return _m().get("carry_stats", {})
	set(v):
		_m()["carry_stats"] = v

var arts: Array:
	get:
		return _m().get("arts", [])
	set(v):
		_m()["arts"] = v

var art_cd: Dictionary:
	get:
		return _m().get("art_cd", {})
	set(v):
		_m()["art_cd"] = v

var talents: Array:
	get:
		return _m().get("talents", [])
	set(v):
		_m()["talents"] = v

var base_weapon: String:
	get:
		return str(_m().get("base_weapon", ""))
	set(v):
		_m()["base_weapon"] = str(v)

var run_gear: Dictionary:
	get:
		return _m().get("run_gear", {})
	set(v):
		_m()["run_gear"] = v

var run_base_gear: Dictionary:
	get:
		return _m().get("run_base_gear", {})
	set(v):
		_m()["run_base_gear"] = v

var run_base_arts: Array:
	get:
		return _m().get("run_base_arts", [])
	set(v):
		_m()["run_base_arts"] = v

var equipped_item: String:
	get:
		return str(_m().get("equipped_item", ""))
	set(v):
		_m()["equipped_item"] = str(v)

var weapon_kind: String:
	get:
		return str(_m().get("weapon_kind", ""))
	set(v):
		_m()["weapon_kind"] = str(v)


# v138（用户："最后一问还是固定给一个功法【不给武器】"）：起手的东西**不再由这里发**——
#   疾风剑法（成品）与那三片锈剑都由 journey_stage._intro_kit() 直接放进包裹
#   （那边要出提示、也要能被"再来一趟"重发），这里只管把一趟的状态清干净。
func reset(talent_list: Array) -> void:
	mode = "intro"
	diff = 0
	Loot.set_red_phase(GameState.ladder_phase())   # R4：搜刮红档随开趟同步
	# ㊿：队伍清空重建——引子趟就主角一个人
	members.clear()
	members.append(_blank_member())
	active_i = 0
	weapon_kind = ""
	base_weapon = ""
	run_gear.clear()
	run_base_gear.clear()
	run_expand = 0
	kit_taken = false
	kit_money_pct = 0.0
	buffs.clear()
	carry_stats.clear()
	bag.clear()
	arts.clear()
	art_cd.clear()
	run_base_arts.clear()
	equipped_item = ""
	alert = 0.0
	loot_bag.clear()
	last_foe.clear()
	money = START_MONEY
	talents = talent_list.duplicate()
	recalc()

# ---- 正式趟（R1）----
# 以村里弟子的账拍快照出发；优化批⑭起"卸下来算"：快照先扣掉随身兵器/装备/功法，
# 加成改由槽位现算（武学不再被算两遍）。整趟不回写账本（红线）。
#
# ㊿：rids 可以给 1~PARTY_MAX 个人（出征屏勾的那些）。第一个人是"领队"，
#   也是出征屏/结算默认对着操作的那个。老签名 begin_formal(rid, d, fate)
#   兼容——传字符串就等于单人队。
func begin_formal(rid, d: int, fate: Variant = "") -> void:
	mode = "formal"
	diff = maxi(1, d)
	var rids: Array = []
	if typeof(rid) == TYPE_ARRAY:
		for v in (rid as Array):
			var s := str(v)
			if s != "" and not rids.has(s):
				rids.append(s)
	else:
		var s1 := str(rid)
		if s1 != "":
			rids.append(s1)
	if rids.is_empty():
		rids.append("player")
	if rids.size() > PARTY_MAX:
		rids = rids.slice(0, PARTY_MAX)
	run_expand = GameState.take_run_expand()   # 优化批㉓：带上出征屏买的临时格
	kit_taken = false                          # v23：开局行装重新摆（每趟一张）
	kit_money_pct = 0.0
	# ㉛：出征屏选的命数——先挂上（舍装签要在装随身时就被看见；只顶这一趟）
	# v62r（用户："开局命数可多选"）：`fate` 现在可以是**字符串或数组**——
	#   出征屏多选后一次交过来，这里逐张挂上（各张的效果本来就互相独立）。
	buffs.clear()
	var fate_list: Array = []
	if typeof(fate) == TYPE_ARRAY:
		for v in (fate as Array):
			var s0 := str(v)
			if s0 != "" and not fate_list.has(s0):
				fate_list.append(s0)
	else:
		var s1b := str(fate)
		if s1b != "":
			fate_list.append(s1b)
	for f_v in fate_list:
		var fid := str(f_v)
		if not fid.begins_with("fate_"):
			fid = "fate_" + fid
		if not buffs.has(fid):
			buffs.append(fid)
	Loot.set_red_phase(GameState.ladder_phase())   # R4：搜刮红档随开趟同步
	# ㊿：按名单把每个成员都装好（每人一份快照/随身三样/功法/天赋）
	members.clear()
	for r in rids:
		members.append(_blank_member())
		active_i = members.size() - 1
		_fill_member_from_village(str(r))
	active_i = 0
	bag.clear()
	alert = 0.0
	loot_bag.clear()
	last_foe.clear()
	# ㉛：buffs 的清空＋命数挂载已搬到函数头（舍装签要先被看见）
	# v24：阅历线·财富「盘缠」段——开局盘缠 +N 文（与"文钱"那张命数各算各的）
	money = START_MONEY + int(GameState.insight_fx().get("start_money", 0.0))
	recalc()

# 把一个成员按村里的账装好（原来 begin_formal 的那一整段，逐个成员跑）
func _fill_member_from_village(rid: String) -> void:
	var acc: Dictionary = GameState.role_data(rid)
	role_id = rid
	# ㊿z9：这份底账里**已经含了宠物随行加成**（护主＝气血%、青隼＝速度%——见
	#   GameState.effective_stats 末尾那段）。出征前随身三样已卸回仓库，所以这里
	#   扣不到什么；下面 stats_of 只是把"路上捡到又穿上的"加回来。
	carry_stats = GameState.effective_stats(rid).duplicate()
	base_weapon = str(acc.get("weapon", ""))
	_deduct_snapshot(carry_stats, base_weapon, rid)   # v62g：扣的时候要用同一位角色的装备倍率
	run_gear.clear()
	var gear_acc: Dictionary = acc.get("gear", {})
	for slot_v in GEAR_SLOTS:
		var slot := str(slot_v)
		var gsid := str(gear_acc.get(slot, ""))
		if gsid != "":
			# ㉛：舍装签——护甲格封着：护甲不随身（照"卸下来算"从快照扣掉）
			if slot == "armor" and buffs.has("fate_noarmor"):
				_deduct_snapshot(carry_stats, gsid, rid)
				continue
			run_gear[slot] = gsid
			_deduct_snapshot(carry_stats, gsid, rid)
	run_base_gear = run_gear.duplicate()
	equipped_item = ""
	weapon_kind = ""
	arts.clear()
	art_cd.clear()
	for s in acc.get("skills", []):
		var sid := str(s)
		if sid != "" and not arts.has(sid) and arts.size() < ART_SLOTS:
			arts.append(sid)
			art_cd[sid] = 0
		_deduct_snapshot(carry_stats, sid, rid)
	run_base_arts = arts.duplicate()   # R4：记下出发时的功法
	talents.clear()
	for line in acc.get("talents", []):
		var nm := str(line).split("（")[0].strip_edges()
		if nm != "" and not talents.has(nm):
			talents.append(nm)
	# ㊿：只算这一名成员的气血（队伍级的清空/盘缠在 begin_formal 里做，
	#   别放进这个逐个成员跑的循环——那会把前一个人的东西擦掉）
	hp_max = maxi(1, int(round(float(stats()["hp"]))))
	hp = hp_max

# 把一件随身件（含升星）从快照里扣掉——"卸下来算"的核心；快照里没有的键不动
# v35：星改记在件上，所以这里不再问"谁拿着"——同一件在谁手里都是同一个乘率。
func _deduct_snapshot(snapshot: Dictionary, sid: String, role_id := "") -> void:
	if sid == "":
		return
	# v62h：装备随等级放大已回滚——扣的就是 starred_stats 那一份（与村里同口径）
	var contrib: Dictionary = GameState.starred_stats(sid)
	for k in contrib.keys():
		var nv := float(snapshot.get(k, 0.0)) - float(contrib.get(k, 0))
		snapshot[k] = maxf(0.0, nv)

func recalc() -> void:
	hp_max = maxi(1, int(round(float(stats()["hp"]))))
	hp = hp_max

# 换装后同步气血上限（上限降了就压到上限——不白回血）
func _recalc_keephp() -> void:
	hp_max = maxi(1, int(round(float(stats()["hp"]))))
	hp = mini(hp, hp_max)

# ㊿：队伍级的气血操作——每节回复、歇脚全复、搜刮掉血这些"全队一起"的事走这三个口。
#   ⚠ 每个口都先记住当前对谁操作、跑完再放回去：不然角色面板看着看着就被切走了。
func party_heal(pct: float) -> int:
	# v62q（用户终表）：铁衣签"**所有治疗效果**削弱 80%"——战斗外的每节回复也算治疗，
	#   所以在这一口上先削（战斗内那几处走 duel_battle._heal_mul）。
	#   ⚠ 系数从卡表读（`heal_cut`），不在代码里写死 0.8——以后调表就够。
	pct *= heal_scale()
	var keep := active_i
	var total := 0
	for i in members.size():
		use_member(i)
		if hp < hp_max:
			var h := maxi(1, int(round(float(hp_max) * pct)))
			hp = mini(hp_max, hp + h)
			total += h
	use_member(keep)
	return total

# v62q（用户终表）：**治疗系数**——把全队所有"回血"按卡给的 heal_cut 削一刀。
#   铁衣签：受到伤害 -50%，代价就是"所有治疗效果（包括吸血）削弱 80%"。
#   战斗内那一份在 duel_battle._heal_mul()（它按人取 fx）；这里管战斗外
#   （每节回复 / 歇脚全复 / 搜刮蹭血那种"全队一起"的口）。
func heal_scale() -> float:
	var cut := 0.0
	for b_v in buffs:
		var b: Dictionary = Buffs.of(str(b_v))
		if str(b.get("kind", "")) != "fate":
			continue
		cut = maxf(cut, float((b.get("fx", {}) as Dictionary).get("heal_cut", 0.0)))
	return maxf(0.0, 1.0 - cut)

func party_lose(amount: int) -> void:
	var keep := active_i
	for i in members.size():
		use_member(i)
		hp = maxi(1, hp - amount)
	use_member(keep)

func party_full_heal() -> void:
	# v62q：歇脚"全复"也是治疗 → 一样吃 heal_scale（铁衣签下只能回两成，
	#   而不是直接回满——"所有治疗效果削弱 80%"不该被一个歇脚绕过去）
	var keep := active_i
	var sc := heal_scale()
	for i in members.size():
		use_member(i)
		if is_equal_approx(sc, 1.0):
			hp = hp_max
		else:
			hp = mini(hp_max, hp + maxi(1, int(round(float(hp_max) * sc))))
	use_member(keep)

# v139（用户定："半血真砍"）：把全队**当前**气血压到上限的 pct（0~1），上限不动。
#   引子起手就靠这一口把"一身武艺只剩不到三成"落到数值上。
#   ⚠ 只往下压、不回血（真要回血走 party_heal / party_full_heal，那两条才吃 heal_scale）。
func party_hp_pct(pct: float) -> int:
	var keep := active_i
	var total := 0
	var k := clampf(pct, 0.0, 1.0)
	for i in members.size():
		use_member(i)
		var want := maxi(1, int(round(float(hp_max) * k)))
		if want < hp:
			total += hp - want
			hp = want
	use_member(keep)
	return total

func has_talent(t: String) -> bool:
	return talents.has(t)

# ---- 角色 / 自带天赋 ----

func set_role(id: String) -> void:
	role_id = id

func role_name() -> String:
	return str(Roles.role_name(role_id))

func innate_data() -> Dictionary:
	return Roles.innate_of(role_id)

func innate_name() -> String:
	var d: Dictionary = innate_data()
	if d.is_empty():
		return ""
	# ㉖：名字/说明走 data_roles 的统一口（它再去 data_talents 那份真源取，
	# 免得这里读到 data_talents 里那句"占位：…（接入后生效）"）
	return Roles.innate_name(str(d.get("id", "")))

func innate_desc() -> String:
	var d: Dictionary = innate_data()
	if d.is_empty():
		return ""
	return Roles.innate_desc(str(d.get("id", "")))

func add_card(set_id: String, part: int) -> bool:
	if bag.size() >= bag_cap():
		return false
	bag.append({"kind": "card", "set": set_id, "part": part})
	return true

func add_item(set_id: String, village := false) -> bool:
	if bag.size() >= bag_cap():
		return false
	# v24：阅历线的"行囊"段也走 bag_cap()，这里不用另加
	var e := {"kind": "item", "set": set_id}
	if village:
		e["village"] = true   # 优化批⑮：村里出身的件——结算不再入库（防重复）
	bag.append(e)
	return true

# 包裹容量（唯一出口）：R3 接宠物驮运；优化批⑧ 起正式趟随"随行背包"档加大
# （引子趟固定 8；背包在出征屏换，存村账 journey.cfg）
func bag_cap() -> int:
	var base := BAG_MAX
	if mode == "formal":
		base = GameState.backpack_cap() + run_expand   # 优化批㉓：＋本趟临时扩仓
	if buffs.has("fate_fullbag"):
		base += 6   # v63（用户："包裹签改为6格"）：+8 → **+6**（代价仍是速度 -50%）
	# v24：阅历线·财富——「行囊」（包裹）与「仓廪」（临时仓库）两条都并进这里：
	#   引擎里"容量＝包裹＋仓格"本来就是**同一个池**（出征屏那行字也是这么写的）
	base += int(GameState.insight_fx().get("bag_slots", 0.0))
	base += int(GameState.insight_fx().get("stash_slots", 0.0))
	return base + int(GameState.pet_fx().get("bag_slots", 0))

func bag_full() -> bool:
	return bag.size() >= bag_cap()

# 招路：换装的兵器优先；没换装＝出发随身那把；都没有 = 空手
func weapon() -> String:
	var sid := equipped_item
	if sid == "":
		sid = base_weapon
	if sid != "":
		var w := str(Cards.weapon_of(sid))
		if w != "" and w != "any":
			return w
		return "fist"
	if weapon_kind != "":
		return weapon_kind
	return "fist"

# 面板/提示用：当前"看得见的那把"（没换装就是出发随身那把）
func weapon_id() -> String:
	if equipped_item != "":
		return equipped_item
	return base_weapon

# 优化批⑭：装备槽的工具——池名即槽名
func gear_slot_of(sid: String) -> String:
	var pool := str(Cards.by_id(sid).get("pool", ""))
	if pool == "armor" or pool == "helm" or pool == "cloak":
		return pool
	return ""

func gear_of(slot: String) -> String:
	return str(run_gear.get(slot, ""))

# 天赋 fx 合一（R0）："名字→数值"的真源在 shared/data_talents.gd。
# 未知名字（占位/旧档）查不到就当没有——不报错、不结算。
func talent_fx_sum() -> Dictionary:
	return talent_fx_of(_m())

# ㊿：按某一名成员算天赋加成（不动 active_i）
# ㊿y：角色星的 stat 组也并进这一份——游历这边所有读 tfx 的地方（stats_of、
#   残血减伤…）自动吃到星，不用逐个改。
func talent_fx_of(m: Dictionary) -> Dictionary:
	var out := {}
	for nm in (m.get("talents", []) as Array):
		var fx: Dictionary = Talents.fx_of(str(nm))
		for k in fx.keys():
			out[k] = float(out.get(k, 0)) + float(fx[k])
	var rid := str(m.get("role_id", ""))
	if rid != "":
		var sfx: Dictionary = GameState.role_star_stat_fx(rid)
		for k2 in sfx.keys():
			out[k2] = float(out.get(k2, 0.0)) + float(sfx[k2])
	# ㊿z5：专武功法（kind "passive"）的常驻数值也折进这一份——游历这边所有读 tfx 的
	#   地方自动吃到。单位跟天赋一致（整数＝百分点）。
	#   ⚠ 它那条"机制"（mech）不在这里：游历那边机制走 buff_fx / _fx_buff，
	#     所以在 duel_battle 的成员初始化里合并（见那边的 ㊿z5）。
	for s_v in (m.get("arts", []) as Array):
		var asid := str(s_v)
		if not Cards.art_is_passive(asid):
			continue
		# ㊿z6：两栏都并（分类只是给人看的排布）——随星放大
		var pstar := GameState.role_star_of(str(m.get("role_id", "")))
		var pfx: Dictionary = Cards.art_passive_fx_scaled(asid, pstar)
		var pmech: Dictionary = Cards.art_passive_mech_scaled(asid, pstar)
		for pk in pfx.keys():
			out[pk] = float(out.get(pk, 0.0)) + float(pfx[pk])
		for mk in pmech.keys():
			out[mk] = float(out.get(mk, 0.0)) + float(pmech[mk])
	return out

# ㊿：按成员取自带天赋（含"生效没"的判断所需的那把兵器）
func innate_of_member(m: Dictionary) -> Dictionary:
	return Roles.innate_of(str(m.get("role_id", "player")))

# v58：这一名成员"此刻手里那把"的**件名**（不是类型）——五行元素挂在件名上
#   （见 GameState.item_elems），所以要看元素就得拿件名。换装过就是换上的那把。
func weapon_id_of_member(i: int) -> String:
	if i < 0 or i >= members.size():
		return ""
	var mm: Dictionary = members[i]
	var eq := str(mm.get("equipped_item", ""))
	return eq if eq != "" else str(mm.get("base_weapon", ""))

func weapon_of_member(m: Dictionary) -> String:
	var sid := str(m.get("equipped_item", ""))
	if sid == "":
		sid = str(m.get("base_weapon", ""))
	if sid != "":
		var w := str(Cards.weapon_of(sid))
		if w != "" and w != "any":
			return w
		return "fist"
	var wk := str(m.get("weapon_kind", ""))
	if wk != "":
		return wk
	return "fist"

# ㊿：按成员算"百折不挠"（残血减伤）与"剑心通明"（剑/空手增伤）——
#   原来只有不带参数的版本（读当前成员），战斗里要挨个成员算。
func talent_dmg_cut_for(m: Dictionary) -> float:
	var v := maxf(float(talent_fx_of(m).get("dmg_cut", 0)), float(buff_fx(str(m.get("role_id", ""))).get("dmg_cut", 0)))
	return clampf(v / 100.0, 0.0, 0.9)

func talent_weapon_mul_for(m: Dictionary) -> float:
	var add := float(talent_fx_of(m).get("art_dmg", 0))
	if add == 0.0:
		return 1.0
	var w := weapon_of_member(m)
	if w == "sword" or w == "fist":
		return 1.0 + add / 100.0
	return 1.0

func stats() -> Dictionary:
	return stats_of(_m())

# v60（用户："游历同理——目前游历没有元素属性显示"）：**五行那一组键也要算**。
#   以前 stats_of 只认 8 个老键（atk/hp/spd/crit/dmg/def/dodge/crit_dmg），
#   于是游历里"物理/元素增伤"与"五行抗性"**永远是 0**：面板没得显示，
#   战斗里那条元素通道（duel_battle 按 Elem.dmg_key() 取 st[…]）也吃不到加成。
#   来源与那 8 条一模一样：出发快照 / 包里残卡 / 随身兵器（含"上品起的类型增伤"）/
#   功法 / 三件套。补齐之后，游历与村里（effective_stats）就是同一个口径了。
const ELEM_KEYS := ["all_dmg", "phys_dmg",
	"metal_dmg", "water_dmg", "wood_dmg", "fire_dmg", "earth_dmg",
	"metal_res", "water_res", "wood_res", "fire_res", "earth_res"]

func _acc_elem(dst: Dictionary, b: Dictionary) -> void:
	for k in ELEM_KEYS:
		if b.has(k):
			dst[k] = float(dst.get(k, 0.0)) + float(b[k])

# ㊿：按"某一名成员"算属性（不动 active_i）——三人成队后战斗/结算要挨个算。
#   原来的 stats() 就是这一份，只是把"读当前成员"换成"读传进来的那一份"。
func stats_of(m: Dictionary) -> Dictionary:
	if m.is_empty():
		m = _m()
	var m_role := str(m.get("role_id", "player"))
	var m_carry: Dictionary = m.get("carry_stats", {})
	var m_equipped := str(m.get("equipped_item", ""))
	var m_base_wpn := str(m.get("base_weapon", ""))
	var m_arts: Array = m.get("arts", [])
	var m_gear: Dictionary = m.get("run_gear", {})
	var elem: Dictionary = {}
	for k0 in ELEM_KEYS:
		elem[k0] = 0.0
	var atk := 13.0
	var dmg := 0.0
	var hpx := 100.0
	var spd := 100.0
	var crit := 5.0
	var def := 5.0
	var dodge := 5.0
	var crit_dmg := 50.0
	if mode == "formal":
		atk = float(m_carry.get("atk", atk))
		dmg = float(m_carry.get("dmg", 0.0))
		hpx = float(m_carry.get("hp", hpx))
		spd = float(m_carry.get("spd", spd))
		crit = float(m_carry.get("crit", crit))
		def = float(m_carry.get("def", def))
		dodge = float(m_carry.get("dodge", dodge))
		crit_dmg = float(m_carry.get("crit_dmg", crit_dmg))
		_acc_elem(elem, m_carry)   # v60：快照里的五行那几条（村里 effective_stats 给的）
	# 卡组增益**不在这里加**：卡的 fx 键是 atk_pct / hp_pct / cut_add 那一类，
	#   由 duel_battle 自己按 _fx_buff 消费（它已经按角色过滤过了）。
	#   这里若再吃一遍 atk/dmg，等于凭空多给一份。
	# v35：包里残卡的那份"份额"**按件型吃全**——以前只吃 atk/dmg，于是护甲残片
	#   （卡片加成＝气血/防御）在游历里白带着；现在与随身装备那一份同口径地并进来。
	for e in bag:
		var ed: Dictionary = e
		if str(ed.get("kind", "")) != "card":
			continue
		var cb: Dictionary = Cards.card_bonus(str(ed.get("set", "")))
		atk += float(cb.get("atk", 0))
		dmg += float(cb.get("dmg", 0))
		hpx += float(cb.get("hp", 0))
		spd += float(cb.get("spd", 0))
		crit += float(cb.get("crit", 0))
		def += float(cb.get("def", 0))
		dodge += float(cb.get("dodge", 0))
		crit_dmg += float(cb.get("crit_dmg", 0))
		_acc_elem(elem, cb)   # v60：残片份额里的五行那几条（护甲的 earth_res 之类）
	# 随身兵器（⑭：没换装＝出发那把；换装＝新那把）——与村里同口径含升星
	# v35：星记在件上（不再按人），所以这几处只问件名
	# v62h：装备随等级放大那条已回滚（用户："装备不按照佩戴者等级放大"）——
	#   现在靠装备**自身的数值**（兵器 ×1.7、防具气血 ×5.4）在面板里占份额，
	#   所以这里与村里一样，直接吃 starred_stats 就行。
	if m_equipped != "":
		var ib: Dictionary = GameState.starred_stats(m_equipped)
		atk += float(ib.get("atk", 0))
		dmg += float(ib.get("dmg", 0))
		_acc_elem(elem, ib)
		_acc_elem(elem, GameState.elem_weapon_dmg(m_equipped))   # 上品起的"类型增伤"
	elif m_base_wpn != "":
		var bb: Dictionary = GameState.starred_stats(m_base_wpn)
		atk += float(bb.get("atk", 0))
		dmg += float(bb.get("dmg", 0))
		_acc_elem(elem, bb)
		_acc_elem(elem, GameState.elem_weapon_dmg(m_base_wpn))
	for sid in m_arts:
		var ab: Dictionary = GameState.starred_stats(str(sid))
		atk += float(ab.get("atk", 0))
		dmg += float(ab.get("dmg", 0))
		_acc_elem(elem, ab)
	# 优化批⑭：随身三件套（护甲/玉佩/披风）——池里有什么吃什么
	for slot_k in m_gear.keys():
		var gsid := str(m_gear[slot_k])
		if gsid == "":
			continue
		var gb: Dictionary = GameState.starred_stats(gsid)
		atk += float(gb.get("atk", 0))
		dmg += float(gb.get("dmg", 0))
		hpx += float(gb.get("hp", 0))
		spd += float(gb.get("spd", 0))
		crit += float(gb.get("crit", 0))
		def += float(gb.get("def", 0))
		dodge += float(gb.get("dodge", 0))
		crit_dmg += float(gb.get("crit_dmg", 0))
		_acc_elem(elem, gb)   # v60：三件套上的五行抗性（铁叶甲 earth_res 之类）
	var tfx := talent_fx_of(m)
	dmg += float(tfx.get("dmg", 0))
	hpx *= 1.0 + float(tfx.get("hp_pct", 0)) / 100.0
	spd += float(tfx.get("spd", 0))
	crit += float(tfx.get("crit", 0))
	def += float(tfx.get("def", 0))
	dodge += float(tfx.get("dodge", 0))
	crit_dmg += float(tfx.get("crit_dmg", 0))
	# ㊽：上阵羁绊——游历里也生效了。判定用的是"这趟带了谁"（party_role_ids），
	#   不是村里的阵容。与村里侧同一份实现：先乘百分比、再加平面值。
	var out := {"atk": atk, "dmg": dmg, "hp": hpx, "spd": spd, "crit": crit, "def": def, "dodge": dodge, "crit_dmg": crit_dmg}
	# v60：五行那一组并进结果——面板（游历［详细属性］/弟子面板）与战斗读的是同一份
	for k1 in ELEM_KEYS:
		out[k1] = float(elem.get(k1, 0.0))
	Bonds.apply_to(out, m_role, party_role_ids())
	# v24（阅历线）：**场外养成 → 游历内辅助**——最后一层并进这一份属性。
	#   ⚠ 只在这一口（游历那一条链）里并：村里的 effective_stats/squad_stats 不读阅历线，
	#     所以爬塔/村战一个字不吃（用户："专门场外给予游历内辅助"）。
	GameState.insight_apply_to(out)
	# ㊿z9：宠物随行加成不在这一层再加一遍——它在快照（carry_stats）里就算过了。
	#   这里若顺手再乘一次，就是"面板 +13%、实际 +26%"那种双算，见 effective_stats 的注。
	return out

# ---- ㉗：五问天赋的现算口（别处一律走这几个，别自己翻 talent_fx_sum） ----

# 百折不挠：气血不足三成时，受到的伤害 -N%（返回 0~1 的小数；buff 里同类键取大不叠加）
func talent_dmg_cut() -> float:
	# ㊿：这里必须按角色过滤——减伤是"挨打的那个人"的属性，
	#   替队友请的专属卡不该把减伤加到当前这个人身上。
	return talent_dmg_cut_for(_m())

# 妙手（升星消耗 -30%）在账本侧，因为升星是村内操作、不在趟里：
# 见 GameState.player_talent_cost_mul()（star_silver_next 已经吃它）。

# 剑心通明：使剑或空手时出手伤害 ×(1 + art_dmg/100)；别的兵器不吃这个加成。
# 不带参数——直接问 weapon()（它已经管了"换装的 / 出发随身那把 / 空手"三种情况），
# 别在这儿重写一遍判断，那种重复迟早会跟 weapon() 走岔。
func talent_weapon_mul() -> float:
	return talent_weapon_mul_for(_m())

# 福缘深厚：搜刮出产率加成（返回 0.15 这样的小数；加在 journey_stage._spawn_loot 的概率上）
#   v62：表里 40 → 15，所以这里现在是 +15%（不是 +40%）；换算逻辑不用动。
func talent_loot_bonus() -> float:
	return maxf(0.0, float(talent_fx_sum().get("loot_pct", 0)) / 100.0)

func card_label(e: Dictionary) -> String:
	var sid := str(e.get("set", ""))
	if str(e.get("kind", "")) == "item":
		var nm := str(Cards.item_name(sid))
		if nm == "":
			nm = sid
		return nm
	var cn := str(Cards.card_name(sid, int(e.get("part", 0))))
	if cn == "":
		cn = sid
	return cn

# ============================================================
# ㉚ 货价梯子（原版这三个数互相打架，这里一次理顺）
#
# 修之前：买 30~60 ｜ 卖店 10 ｜ 满包折现 20
#   → 折现比卖店还贵一倍，于是"故意把包裹攒满再折现"比老实卖店更赚。
#     这不是"哪个价高了低了"，是三个价之间的**顺序**错了。
#
# 现在的规矩（从高到低，一眼看懂）：
#   买进    30 × 品级系数（起）      ← 花出去
#   ────────────────────────────
#   卖店    SELL_CARD × 品级系数      ← 正常变现，最划算
#   折现    CASHOUT × 品级系数        ← 满包时的下策，必须比卖店低
#
# 为什么折现要比卖店低：折现是"包裹满了、不想翻包，点一下就完事"的便利，
#   便利不该比正经操作更赚。低一档玩家才有动机去管理包裹。
# 为什么卖店是 12 而不是 10：进货 30 起，10 文只有三分之一，卖什么都肉疼；
#   12 是四成，接近这类游戏常见的回收比例。
# 想要买进不亏本（倒卖套利），只要保证"买进基价 > 卖店基价"就不会有套利，
#   30 > 12，安全。
# 三个数都在 tuning.cfg 的 [price] 段里，随时可调（见 tuning_write_example）。
# ============================================================
const T_SELL_CARD := 12
const T_SELL_ITEM := 25
const T_CASHOUT := 6
const T_FIX_BASE := 80

func _sell_base() -> int:
	return Tuning.intv("price", "sell_card", T_SELL_CARD)

func _sell_item_base() -> int:
	return Tuning.intv("price", "sell_item", T_SELL_ITEM)

func _cashout_base() -> int:
	return Tuning.intv("price", "cashout", T_CASHOUT)

# R3 货价批：基价 × 品级系数（data_cards.PRICE_MUL）。sid 可省——省 = 凡品系数
# （旧的空参调用者不受影响）；卖价天赋 sell_pct 照旧按百分比乘在外层。
# v24：卖价那两口都再乘一道"阅历线·财富"的 sell_pct（用户："卖价提升"）
func _sell_mul() -> float:
	return 1.0 + float(GameState.insight_fx().get("sell_pct", 0.0))

func sell_price(sid := "") -> int:
	var mul := 1.0
	if sid != "":
		mul = Cards.price_mul(str(sid))
	return int(round(float(_sell_base()) * mul * (1.0 + float(talent_fx_sum().get("sell_pct", 0)) / 100.0) * _sell_mul()))

func item_sell_price(sid := "") -> int:
	var mul := 1.0
	if sid != "":
		mul = Cards.price_mul(str(sid))
	return int(round(float(_sell_item_base()) * mul * (1.0 + float(talent_fx_sum().get("sell_pct", 0)) / 100.0) * _sell_mul()))

func price_of(e: Dictionary) -> int:
	var sid := str(e.get("set", ""))
	var p := 0
	if str(e.get("kind", "")) == "item":
		p = item_sell_price(sid)
	else:
		p = sell_price(sid)
	# v107：侠名/大侠——货郎给的价更好（−10% / −20%）
	return maxi(1, int(round(float(p) * karma_shop_mul())))

# 卖价区间文案（货郎提示行）：随天赋卖价、随品级系数表自动跟。
func sell_range_text() -> String:
	var b := 1.0 + float(talent_fx_sum().get("sell_pct", 0)) / 100.0
	var top: float = float(Cards.PRICE_MUL[Cards.PRICE_MUL.size() - 1])
	var lo := float(_sell_base())
	var ilo := float(_sell_item_base())
	return "残卡 " + str(int(round(lo * b))) + "～" + str(int(round(lo * top * b))) + " 文／成品 " + str(int(round(ilo * b))) + "～" + str(int(round(ilo * top * b))) + " 文"

# 补齐价（买指定缺页）/ 折现价（满包把新卡换钱）：同样 基价 × 品级系数。
# 补齐＝买，所以基价（80）比货摊的进货基价（30~60）高——这是"点菜"的代价。
func fix_price(sid: String) -> int:
	return int(round(float(Tuning.intv("price", "fix_base", T_FIX_BASE)) * Cards.price_mul(sid)))

# 折现：满包时的下策，必须低于卖店（理由见上面那把"货价梯子"）
func cashout_price(sid: String) -> int:
	return int(round(float(_cashout_base()) * Cards.price_mul(sid) * _sell_mul()))

# ---- 卡组统计 ----

func count_cards() -> Dictionary:
	var m := {}
	for e in bag:
		var ed: Dictionary = e
		if str(ed.get("kind", "")) != "card":
			continue
		var s := str(ed.get("set", ""))
		var p := int(ed.get("part", 0))
		if not m.has(s):
			m[s] = {}
		m[s][p] = int(m[s].get(p, 0)) + 1
	return m

func ready_sets() -> Array:
	var out: Array = []
	var m := count_cards()
	for s in m.keys():
		var parts: Array = Cards.parts_of(str(s))
		var ok := true
		for i in parts.size():
			if int(m[s].get(i, 0)) <= 0:
				ok = false
		if ok:
			out.append(str(s))
	return out

func take_one_card(set_id: String, part: int) -> bool:
	for i in bag.size():
		var ed: Dictionary = bag[i]
		if str(ed.get("kind", "")) == "card" and str(ed.get("set", "")) == set_id and int(ed.get("part", 0)) == part:
			bag.remove_at(i)
			return true
	return false

func missing_card() -> Dictionary:
	var m := count_cards()
	var best := {}
	var best_have := -1
	for s in m.keys():
		var sid := str(s)
		var pool := str(Cards.by_id(sid).get("pool", ""))
		if not GameState.pool_active(pool).has(sid):
			continue   # R4：补齐只在现役卡池里挑（旧组退场后不能再补齐）
		var parts: Array = Cards.parts_of(sid)
		var have := 0
		var miss: Array = []
		for i in parts.size():
			if int(m[s].get(i, 0)) > 0:
				have += 1
			else:
				miss.append(i)
		if miss.is_empty():
			continue
		if have > best_have:
			best_have = have
			best = {"set": str(s), "part": int(miss[0])}
	return best

func part_status(sid: String) -> Dictionary:
	var have: Array = []
	var miss: Array = []
	var parts: Array = Cards.parts_of(sid)
	var m := count_cards()
	var mine: Dictionary = {}
	if m.has(sid):
		mine = m[sid]
	for i in parts.size():
		if int(mine.get(i, 0)) > 0:
			have.append(str(parts[i]))
		else:
			miss.append(str(parts[i]))
	return {"have": have, "miss": miss}

# ---- 装备 ----

func can_place_item(sid: String) -> Dictionary:
	if Cards.is_arts(sid):
		var can_eq: bool = (not arts.has(sid)) and arts.size() < ART_SLOTS
		return {"equip": can_eq, "bag": bag.size() < bag_cap()}
	return {"equip": true, "bag": bag.size() < bag_cap()}

func place_item(sid: String, where: String) -> String:
	if where == "equip":
		_pull_from_bag(sid)   # 这件若还在包裹里，先取出来（腾位、防同件两份）
		if Cards.is_arts(sid):
			# v60：这两个原因**分开报**。原来合成/去向页里"身上已有同名"与"功法栏满"
			#   合并成一句"功法栏满，改放包裹"，玩家明明只带了 1 门也被告知"栏满"，
			#   看着就是"合成了功法却怎么也装不上，只能塞在包里"。
			if arts.has(sid):
				if add_item(sid):
					return "这门功法身上已经有了（多的这本放包裹，结算带进村仓库）"
				return "身上已有这门、包裹也满——已丢弃"
			if arts.size() >= ART_SLOTS:
				if add_item(sid):
					return "功法栏已满 " + str(ART_SLOTS) + " 门，先卸下一门（这件先放包裹）"
				return "功法栏满、包裹也满——已丢弃"
			arts.append(sid)
			art_cd[sid] = 0
			_recalc_keephp()
			return "功法已装上"
		var slot := gear_slot_of(sid)
		if slot != "":
			# ㉛：舍装签——护甲格封着（这件已从包裹取出，先放回去）
			if slot == "armor" and buffs.has("fate_noarmor"):
				if add_item(sid):
					return "舍装签在身：这趟护甲格封着——改放包裹"
				return "舍装签在身：护甲穿不上；包裹也满——先腾一格"
			var old_g := str(run_gear.get(slot, ""))
			if old_g == sid:
				# v20：同款替换——身上这件不动；落包的多余那件不盖"村里"章（结算按未盖章件带出）
				if bag.size() >= bag_cap():
					return "包裹满：多出的一件没处放——先腾一格，或改选［放入］"
				run_gear[slot] = sid
				if add_item(old_g):
					return "同款替换：多出的一件进包裹（结算带进村仓库）"
				return "同款替换：多出的一件没能放下——包裹满"
			if old_g != "" and bag.size() >= bag_cap():
				return "包裹满：旧" + str(SLOT_CN.get(slot, slot)) + "没处放——先腾一格，或改选［放入］"
			run_gear[slot] = sid
			_recalc_keephp()
			var cn := str(SLOT_CN.get(slot, slot))
			if old_g == "":
				return "已装上" + cn + "：" + str(Cards.item_name(sid))
			if add_item(old_g, str(run_base_gear.get(slot, "")) == old_g):
				return "已换上" + cn + "：" + str(Cards.item_name(sid)) + "，旧的进包裹"
			return "已换上（旧件没放回——检查包裹）"
		var old := equipped_item
		if old != "" and old != sid and bag.size() >= bag_cap():
			return "包裹满：旧兵器没处放——先腾一格，或改选［放入］"
		if old == sid and bag.size() >= bag_cap():
			return "包裹满：多的一把没处放——先腾一格，或改选［放入］"
		equipped_item = sid
		_recalc_keephp()
		if old == "":
			if base_weapon != "" and sid == base_weapon:
				return "同款替换：多的这把先带着（结算带进村仓库）"
			return "兵器已装上"
		if old == sid:
			if add_item(old):
				return "同款替换：多的一把进包裹（结算带进村仓库）"
			return "同款替换：多的一把没能放下——包裹满"
		if add_item(old):
			return "已换装，旧兵器进包裹"
		return "已换装（旧兵器没放回——检查包裹）"
	if where == "drop":
		return "已丢弃 " + str(Cards.item_name(sid))
	if add_item(sid):
		return "已放入包裹"
	return "包裹已满，已丢弃"

# 把包裹里的一份成品取走——换装流程先腾位（防"换了新的、旧的没处放"）
func _pull_from_bag(sid: String) -> void:
	for i in bag.size():
		var ed: Dictionary = bag[i]
		if str(ed.get("kind", "")) == "item" and str(ed.get("set", "")) == sid:
			bag.remove_at(i)
			return

# ㊿w：指定成员那一版的"穿/放"——多人趟里"这件给谁"走这几个口。
#   以前只有"当前看着的那个人"（左上角［角色］切人＝隐式选人），多人上场时等于没得选，
#   点［装备］永远穿在当前那位身上。
#   实现就是"切过去→照老口做→切回来"，别在调用方自己拼。
func can_place_item_for(mi: int, sid: String) -> Dictionary:
	var keep := active_i
	use_member(mi)
	var c := can_place_item(sid)
	use_member(keep)
	return c

func place_item_for(mi: int, sid: String, where: String) -> String:
	var keep := active_i
	use_member(mi)
	var msg := place_item(sid, where)
	use_member(keep)
	return msg

func equip_from_bag_for(mi: int, i: int) -> String:
	var keep := active_i
	use_member(mi)
	var msg := equip_from_bag(i)
	use_member(keep)
	return msg

func equip_from_bag(i: int) -> String:
	if i < 0 or i >= bag.size():
		return ""
	var e: Dictionary = bag[i]
	var sid := str(e.get("set", ""))
	# v60：编号丢了的件（老档／坏数据）**不能落进下面"同款"那两支**——
	#   那两支在"身上空着"时会回一句"身上已有同款——留在包裹"，
	#   等于**谎报装备成功**：玩家看到的就是"提示装上了、人还是空手"。
	#   这里先拦下来，实话实说（探针跑过：{"kind":"item"} 这种坏件正是这个表现）。
	if sid == "":
		return "这件认不出是什么（编号丢了）——先在包裹里［丢弃］它"
	if Cards.is_arts(sid):
		if arts.has(sid):
			# v60（用户报的："点击装备提示已装备，但还是空手"）：这句以前只有"这本已经装备了"，
			#   玩家看着包裹里那本还在，就以为"点了没反应"。写清"多的那本去哪了"，
			#   与兵器/装备那几条"同款"的口气拉齐。
			return "这门功法已经在身上了（多的这本留在包裹，结算带进村仓库）"
		if arts.size() >= ART_SLOTS:
			return "功法栏已满 " + str(ART_SLOTS) + " 门，先卸下一门"
		bag.remove_at(i)
		arts.append(sid)
		art_cd[sid] = 0
		_recalc_keephp()
		# v60：功法**不占兵器格**——不点这一句，玩家会以为"装上了武学，怎么还空手"。
		return "已装上功法 " + str(Cards.name_of(sid)) + "（功法不占兵器格——手里那把要另装）"
	var slot := gear_slot_of(sid)
	if slot != "":
		# ㉛：舍装签——护甲格封着
		if slot == "armor" and buffs.has("fate_noarmor"):
			return "舍装签在身：这趟护甲格封着——护甲穿不上"
		var old_g := str(run_gear.get(slot, ""))
		if old_g == sid:
			return "身上已有同款——这件留在包裹（结算带进村仓库）"
		bag.remove_at(i)
		run_gear[slot] = sid
		_recalc_keephp()
		var cn := str(SLOT_CN.get(slot, slot))
		if old_g != "":
			if add_item(old_g, str(run_base_gear.get(slot, "")) == old_g):
				return "已换上" + cn + "：" + str(Cards.item_name(sid)) + "（旧的进包裹）"
			return "已换上" + cn + "：" + str(Cards.item_name(sid)) + "（旧件没放回——包裹满）"
		return "已戴上" + cn + "：" + str(Cards.item_name(sid))
	var old := equipped_item
	if old == sid:
		return "身上已有同款——这把留在包裹（结算带进村仓库）"
	bag.remove_at(i)
	equipped_item = sid
	_recalc_keephp()
	if old != "":
		if add_item(old):
			return "已装上 " + str(Cards.item_name(sid)) + "，旧兵器进包裹"
		return "已装上 " + str(Cards.item_name(sid)) + "（旧兵器没放回——包裹满）"
	return "已装上 " + str(Cards.item_name(sid))

func unequip_weapon() -> String:
	if equipped_item == "":
		return ""
	var sid := equipped_item
	if not add_item(sid):
		return "包裹满，先腾一格"
	equipped_item = ""
	_recalc_keephp()
	if base_weapon != "":
		return "已卸下 " + str(Cards.item_name(sid)) + "（换回随身那把）"
	return "已卸下 " + str(Cards.item_name(sid))

# 优化批⑭：卸下三件套（进包裹）
func unequip_gear(slot: String) -> String:
	var sid := str(run_gear.get(slot, ""))
	if sid == "":
		return ""
	if not add_item(sid, str(run_base_gear.get(slot, "")) == sid):
		return "包裹满，先腾一格"
	run_gear.erase(slot)
	_recalc_keephp()
	return "已卸下" + str(SLOT_CN.get(slot, slot)) + "：" + str(Cards.item_name(sid)) + "（进包裹）"

func unequip_art(i: int) -> String:
	if i < 0 or i >= arts.size():
		return ""
	var sid := str(arts[i])
	if not add_item(sid, run_base_arts.has(sid)):
		return "包裹满，先腾一格"
	arts.remove_at(i)
	art_cd.erase(sid)
	_recalc_keephp()
	return "已卸下 " + str(Cards.name_of(sid))

# ---- 功法冷却 ----

func reset_art_cd() -> void:
	for sid in arts:
		art_cd[str(sid)] = 0

func tick_arts() -> void:
	for sid in arts:
		var s := str(sid)
		var cd := int(art_cd.get(s, 0))
		if cd > 0:
			art_cd[s] = cd - 1

func set_art_cd(sid: String, cd: int) -> void:
	art_cd[sid] = cd

func pick_art() -> Dictionary:
	for sid in arts:
		var s := str(sid)
		if int(art_cd.get(s, 0)) > 0:
			continue
		# ㊿z4：被动功法不进出手轮转（它装备即生效，没有"放一手"这回事）
		if Cards.art_is_passive(s):
			continue
		var art: Dictionary = Cards.art_of(s).duplicate()
		if art.is_empty():
			continue
		art["_name"] = str(Cards.name_of(s))
		art["_sid"] = s
		return art
	return {}

# ---- R3 警戒 ----

func alert_max() -> float:
	return ALERT_MAX + float(GameState.pet_fx().get("alert_cap", 0))

func alert_mul() -> float:
	# v107：恶名/恶贯满盈——警戒涨得快（遭遇变多）
	return maxf(0.1, 1.0 + float(GameState.pet_fx().get("alert_rate", 0)) / 100.0) * karma_alert_mul()

# 积攒走宠物乘率（开容器 / 揭晓 / 拿取由舞台调用）
func alert_gain(base: float) -> void:
	alert = minf(alert_max(), alert + base * alert_mul())

# 衰减直减（每通过 1 个节点）
func alert_drop(v: float) -> void:
	alert = maxf(0.0, alert - v)

func alert_reset() -> void:
	alert = 0.0

func alert_full() -> bool:
	return alert >= alert_max()

# ============================================================
# v107：善恶五档——**只限这一趟**（出村清零，不进村账）
#   恶贯满盈 文钱+30% 攻+10% 警戒+50% ｜ 恶名 文钱+15% 警戒+20%
#   中立 无 ｜ 侠名 商店−10% 每 3 节回 3% 血 ｜ 大侠 商店−20% 每 3 节回 6% 血（＋"仗义"选项）
# ============================================================
func karma_band() -> int:
	var k := int(karma)
	if k <= -60:
		return 0
	if k <= -20:
		return 1
	if k >= 60:
		return 4
	if k >= 20:
		return 3
	return 2

func karma_band_name() -> String:
	return ["恶贯满盈", "恶名", "中立", "侠名", "大侠"][karma_band()]

func karma_money_mul() -> float:
	return [1.30, 1.15, 1.0, 1.0, 1.0][karma_band()]

func karma_alert_mul() -> float:
	return [1.50, 1.20, 1.0, 1.0, 1.0][karma_band()]

func karma_shop_mul() -> float:
	return [1.0, 1.0, 1.0, 0.90, 0.80][karma_band()]

func karma_heal_pct() -> float:
	return [0.0, 0.0, 0.0, 3.0, 6.0][karma_band()]

func karma_atk_mul() -> float:
	return [1.10, 1.0, 1.0, 1.0, 1.0][karma_band()]

func alert_ratio() -> float:
	return clampf(alert / maxf(1.0, alert_max()), 0.0, 1.0)

# ---- R3 临时仓库（单位＝格；容量＝bag_cap()） ----

func loot_gap_used() -> int:
	var n := 0
	for e in loot_bag:
		var ed: Dictionary = e
		n += int(ed.get("gap", 1))
	return n

func loot_gap_left() -> int:
	return maxi(0, bag_cap() - loot_gap_used())

func loot_can_take(e: Dictionary) -> bool:
	return int(e.get("gap", 1)) <= loot_gap_left()

func loot_take(e: Dictionary) -> bool:
	if not loot_can_take(e):
		return false
	loot_bag.append(e)
	return true

func loot_drop(i: int) -> void:
	if i >= 0 and i < loot_bag.size():
		loot_bag.remove_at(i)

# ============================================================
# v62o（用户重做命数）：
#   · **短绳签**：每过一节攻击力 -2%（可叠）——计数放这儿，战斗建人时按它折 atk。
#     （存运行态而不是战斗态：一节打完还留着，整趟一直累积）
#   · **短绳签**：每打过一个 boss 关**保底一瓶金色品质的酒**（竹叶酒＝3 级）——
#     放进 bonus_wines，结算时由 journey_settle 并进战利（不占临时仓库格子，
#     免得"保底被背包塞满吞掉"）。
# ============================================================
var fate_node_passed := 0          # 短绳签：已经过了多少节（每节攻击 -2%）
var bonus_wines: Array = []        # 保底酒（grade 3＝金（竹叶酒））

func fate_atk_mul() -> float:
	# v62u（用户："每过一节攻击 -2% 可叠 **没有上限和下限一说**"）：
	#   去掉原来那个 30% 下限 ✗ —— 一路叠下去，过了 50 节系数就归 0（再往下是负数，
	#   由调用处 `maxf(1.0, atk × 系数)` 兜住，攻击最低降到 1，不会崩也不会反向加血）。
	#   ⚠ 也就是说：短绳签**走得越远越软**，长趟必须靠别的手段补攻击。
	var base := 1.0
	if buffs.has("fate_shortrope"):
		base = 1.0 - 0.02 * float(fate_node_passed)
	return base * karma_atk_mul()   # v107：恶贯满盈出手更狠（×1.10）

# ---- 商店 ----

# ㊲/㊺：入口卡——首片到手后，其余片才出货；村里仓库（残卡/成品）＋本趟包裹/临时仓库都算"到手"
func _entry_open(sid: String) -> bool:
	if GameState.vault_count(sid, 0) > 0:
		return true
	if GameState.vault_item_count(sid) > 0:
		return true
	if _arr_has_part(bag, sid, 0):
		return true
	if _arr_has_part(loot_bag, sid, 0):
		return true
	return false

func _arr_has_part(arr: Array, sid: String, part: int) -> bool:
	for e_v in arr:
		var e: Dictionary = e_v
		if str(e.get("kind", "")) != "card":
			continue
		var es := str(e.get("set", e.get("id", "")))
		if es == sid and int(e.get("part", -1)) == part:
			return true
	return false

func make_shop_offers(node_idx: int) -> Array:
	# R4：货摊只摆现役卡池（随难度换届的 8 槽窗）——旧组退场、新组进窗
	# v112（用户："商店的档位也同时更改 如果是凡品档就出凡品 极品档就出极品"）：
	#   货郎担的货**按这一趟选的品级**出（老路子看"全局进度到哪一档"，与出征屏选的对不上）。
	#   仍是 2 兵器 + 1 武学 + 1 装备，只是件件换成这一档的；这一档取不到就退回现役池。
	var q := GameState.deploy_phase()
	var picks: Array = []
	for pool_v in ["weapon", "weapon", "arts"]:
		var sid := Ladder.pick_of_q(str(pool_v), q)
		if sid != "" and not picks.has(sid):
			picks.append(sid)
	var ws: Array = GameState.pool_active("weapon")
	ws.shuffle()
	var ar: Array = GameState.pool_active("arts")
	ar.shuffle()
	# 兜底也要**同档**（不然极品档的摊上会冒出凡品货——探针抓到过一件 33 文的匕首）
	for i in mini(2, ws.size()):
		if picks.size() >= 3:
			break
		if not picks.has(str(ws[i])) and Cards.q_idx(str(ws[i])) == q:
			picks.append(str(ws[i]))
	for i in mini(1, ar.size()):
		if picks.size() >= 3:
			break
		if not picks.has(str(ar[i])) and Cards.q_idx(str(ar[i])) == q:
			picks.append(str(ar[i]))
	# ㊳/㊽：第 4 格＝装备残卡——三池合一、随阶段开品级（阶段 0 仍是凡品那三件；
	# 首通越多开越高，封顶极品。首片闸在下面统一过）
	# v112：第 4 格（装备）也按这一趟的品级取；取不到再退回现役池
	var gsid := Ladder.pick_of_q("armor", q)
	var gr: Array = GameState.pool_gear()
	if gr.is_empty():
		gr = ["armor_pi", "helm_bu", "cloak_bu"]
	gr.shuffle()
	if gsid != "" and not picks.has(gsid):
		picks.append(gsid)
	else:
		for s_v in gr:
			if not picks.has(str(s_v)) and Cards.q_idx(str(s_v)) == q:
				picks.append(str(s_v))
				break
		if picks.size() < 4:
			picks.append(str(gr[0]))   # 真没有同档的（装备无绝品那种）——宁可借一件也不空着
	var offers: Array = []
	for sid in picks:
		var parts: Array = Cards.parts_of(str(sid))
		var p := randi() % maxi(1, parts.size())
		if p > 0 and not _entry_open(str(sid)):
			p = 0   # ㊲：入口卡——没拿过首片的套，货摊只摆首片
		# v24：阅历线·财富「人脉」段——货郎担要价 -N%
		var cut := float(GameState.insight_fx().get("shop_cut", 0.0))
		var pr := float(clampi(30 + node_idx, 30, 60)) * Cards.price_mul(str(sid)) * (1.0 - clampf(cut, 0.0, 0.8))
		offers.append({
			"set_id": str(sid),
			"part": p,
			"price": maxi(1, int(round(pr))),
		})
	return offers

# ---- 优化批㉔：卡组（增益）——面板/货郎请卡；只在这趟里生效 ----

func buff_count() -> int:
	return buffs.size()

# ㊿：卡组增益汇总。
#   role_id 给了就按"专属只对本人生效"过滤——这才是"只认本角色"的正确落点：
#     · 专属卡：只有 card.role == role_id 才计入（替别人请的那张对你这趟不出力）
#     · 普通 / 特殊卡：谁问都给（它们是对全队生效的）
#   不给 role_id（""）＝不过滤，全部计入（只有"跟具体人无关"的汇总才该这么用）。
func buff_fx(role_id := "") -> Dictionary:
	var out: Dictionary = {}
	for bid_v in buffs:
		var b: Dictionary = Buffs.of(str(bid_v))
		if role_id != "" and str(b.get("kind", "")) == "exclusive" and str(b.get("role", "")) != role_id:
			continue
		var fx: Dictionary = b.get("fx", {})
		for k in fx.keys():
			out[k] = float(out.get(k, 0.0)) + float(fx[k])
	# ㊿y：角色星的 mech 组也并进这一份——游历这边引擎读 buff_fx 的地方
	#   （大招持续/追剑/被动/武学冷却/回气…）**一行都不用改**就吃到了星。
	#   ⚠ stat 组不在这里：那条走 stats_of 的 tfx（见下面 talent_fx_of 那一口）。
	if role_id != "":
		# ⚠ 这里**只并角色星**——专武**不在这里并**：
		#   duel_battle._setup_ally（约 1368~1379 行）会按「这个人随身那几门被动功法」
		#   把专武的 **mech 与 fx 两栏都**加进 al["fx_buff"]（随星放大）。
		#   若在这一层也并一次专武，游历里就是**两倍**。
		#   （2026-09 我误判过一次「专武在游历失效」，就是只看这一层得出的——别再改它。）
		var sfx: Dictionary = GameState.role_star_mech_fx(role_id)
		for k2 in sfx.keys():
			out[k2] = float(out.get(k2, 0.0)) + float(sfx[k2])
	# v84：**集齐流派的额外效果**（3/6/9 档）——游历这边的汇合口就在这，
	#   并进这一份之后，战斗引擎（_fx_buff）与角色面板都自动吃到。
	var pb: Dictionary = Buffs.path_bonus_fx(buffs)
	for k3 in pb.keys():
		out[k3] = float(out.get(k3, 0.0)) + float(pb[k3])
	return out

func buff_lines() -> String:
	if buffs.is_empty():
		return "（还没请卡）"
	var m: Dictionary = {}
	for bid_v in buffs:
		var k := str(bid_v)
		m[k] = int(m.get(k, 0)) + 1
	var arr: Array = []
	for k2 in m.keys():
		var n2 := int(m[k2])
		# ㊿：专属卡在"已请"这一行里也标出主人——只写卡名的话，破军/坚壁/长歌
		#   看上去就是三张普通卡，玩家不知道它们只对谁出力。
		var oc := Buffs.owner_cn(str(k2))
		var nm2 := Buffs.name_of(str(k2)) + ("（" + oc + "）" if oc != "" else "")
		arr.append(nm2 + ("×" + str(n2) if n2 > 1 else ""))
	return "、".join(PackedStringArray(arr))

func add_buff(bid: String) -> Dictionary:
	var b: Dictionary = Buffs.of(bid)
	if b.is_empty():
		return {"ok": false, "msg": "没有这张卡"}
	# ㊿：「只认本角色」这道闸**撤了**——它以前是"别家的专属你请不上"。
	#   现在改成"请得到，但只对那个人生效"（见 buff_fx(role_id)）：三人在队时
	#   你完全可能替队友请一张专属。所以这里不再拦。
	# ㊾：而"同一张专属每趟只能请一次"这条**留着**——它跟角色无关，是数量限制。
	if str(b.get("kind", "")) == "exclusive" and buffs.has(bid):
		return {"ok": false, "msg": "同一张专属卡每趟只能请一次——这张已经请过了"}
	# ㊿：先数手里有几张——有些卡的第 2 张是白请的（引擎那边取大/有封顶，
	#   见 data_buffs.USEFUL_COPIES）。不拦着买（"普通/特殊可重复请"这条没改），
	#   但买完得当场告诉他这张不再更强——提示只有这一处能覆盖全部入口：
	#   卡组面板的签摊、货郎担子、精英三抽、路边签摊，全都走 add_buff。
	var owned_before := 0
	for id_v in buffs:
		if str(id_v) == bid:
			owned_before += 1
	var price := int(b.get("price", 40))
	if money < price:
		return {"ok": false, "msg": "文钱不够：要 " + str(price) + " 文（现有 " + str(money) + "）"}
	money -= price
	buffs.append(bid)
	var tail := ""
	var capmsg := Buffs.cap_hint(bid, owned_before)
	if capmsg != "":
		tail = "\n⚠ " + capmsg + "（这张已入卡组，但不再额外生效）"
	return {"ok": true, "msg": "已收入卡组：「" + str(b.get("name", bid)) + "」——" + str(b.get("desc", "")) + "（本趟生效，带不出去）" + tail}

# ---- R4 ④b：续行存档（整局快照；舞台侧另存节点表/容器残局） ----

func to_save() -> Dictionary:
	return {
		"mode": str(mode), "diff": int(diff), "role_id": str(role_id),
		"weapon_kind": str(weapon_kind), "carry_stats": carry_stats.duplicate(true),
		"bag": bag.duplicate(true), "money": int(money),
		"equipped_item": str(equipped_item), "arts": arts.duplicate(),
		"talents": talents.duplicate(), "run_base_arts": run_base_arts.duplicate(),
		"alert": float(alert), "loot_bag": loot_bag.duplicate(true),
		"last_foe": last_foe.duplicate(true),
		"base_weapon": str(base_weapon),
		"run_gear": run_gear.duplicate(true),
		"run_base_gear": run_base_gear.duplicate(true),
		"run_expand": run_expand,
		"buffs": buffs.duplicate(),
		# v23：开局行装那两格也要进档——不然中途退出重进会又摆一次五选一（白拿一件）
		"kit_taken": bool(kit_taken), "kit_money_pct": float(kit_money_pct),
		# ㊾：当前气血**必须**存——以前这里没有它，而 resume_from 结尾 recalc() 把 hp
		#   直接顶成满血。于是"残血上路"这条设计只活在这一趟的内存里：
		#   一旦强退/杀进程再进，人就满血复活了（duel_battle._end 明明把残血写回了 _state.hp，
		#   但那一笔从来没进过存档）。
		"hp": int(hp),
		# ㊿：三个人各存一份。上面那些"单人"键**照旧写**（写的是当前成员那份）——
		#   万一还有别处按老格式读，也不至于读到空；真正恢复以 members 为准。
		"members": members.duplicate(true),
		"active_i": active_i,
	}

func resume_from(d: Dictionary) -> void:
	mode = str(d.get("mode", "intro"))
	diff = int(d.get("diff", 0))
	alert = float(d.get("alert", 0.0))
	bag = (d.get("bag", []) as Array).duplicate(true)
	money = int(d.get("money", START_MONEY))
	loot_bag = (d.get("loot_bag", []) as Array).duplicate(true)
	last_foe = (d.get("last_foe", {}) as Dictionary).duplicate(true)
	run_expand = int(d.get("run_expand", 0))
	kit_taken = bool(d.get("kit_taken", false))
	kit_money_pct = float(d.get("kit_money_pct", 0.0))
	buffs = (d.get("buffs", []) as Array).duplicate()
	# ㊿：先恢复队伍。有 "members" 就按它建（三人档）；没有就是旧档
	#   （单人形状）——把老键拼成一个成员，进度一点不丢。
	members.clear()
	var raw: Array = d.get("members", [])
	if not raw.is_empty():
		for mv in raw:
			var src: Dictionary = mv
			var m := _blank_member()
			for k in m.keys():
				if src.has(k):
					m[k] = src[k]
			members.append(m)
	else:
		var m1 := _blank_member()
		m1["role_id"] = str(d.get("role_id", "player"))
		m1["weapon_kind"] = str(d.get("weapon_kind", ""))
		m1["carry_stats"] = (d.get("carry_stats", {}) as Dictionary).duplicate(true)
		m1["equipped_item"] = str(d.get("equipped_item", ""))
		m1["arts"] = (d.get("arts", []) as Array).duplicate()
		m1["talents"] = (d.get("talents", []) as Array).duplicate()
		m1["run_base_arts"] = (d.get("run_base_arts", []) as Array).duplicate()
		m1["base_weapon"] = str(d.get("base_weapon", ""))
		m1["run_gear"] = (d.get("run_gear", {}) as Dictionary).duplicate(true)
		m1["run_base_gear"] = (d.get("run_base_gear", {}) as Dictionary).duplicate(true)
		m1["hp"] = int(d.get("hp", -1))
		members.append(m1)
	if members.is_empty():
		members.append(_blank_member())
	active_i = clampi(int(d.get("active_i", 0)), 0, members.size() - 1)
	# 每个成员的 hp 上限按当下装备/武学/卡组重算，再把存下来的残血压回上限。
	#   上限是 -1（旧档没这一栏）＝满血，跟以前行为一致，不会平白扣血。
	for i in members.size():
		use_member(i)
		art_cd = {}
		for sid in arts:
			art_cd[str(sid)] = 0
		var keep := int(_m().get("hp", -1))
		recalc()
		if keep >= 0:
			hp = clampi(keep, 1, hp_max)
	use_member(0)
	Loot.set_red_phase(GameState.ladder_phase())   # 红档按当下进度重算（与开趟同源）
