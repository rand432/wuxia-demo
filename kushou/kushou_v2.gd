extends Control
# ============================================================
# kushou/kushou_v2.gd —— 困兽 v2 · 主界面【空壳】（第 1 步）
#
# 设计稿：docs/困兽_主界面设计稿.md（v2b：弹窗两层，大弹窗允许遮住战场）
# 这一步**只有布局 + 假数据**，不接战斗、不接真数值：
#   · 顶部 HUD：波数 · boss 倒计时 · 文钱 · 灵晶 · 杀敌 · 设置
#   · 战场：简笔小人（假打）＋ 左缘四个圆钮（抽卡/挑战/事件/卡组）＋ 右缘两个（存档/成就）
#   · 经验条 · 主角条（头像/生命/内力/技能＋/装备＋）
#   · 挑战六格（带冷却，两行三列）
#   · **两层弹窗**：小弹窗＝半屏（设置/头像/事件/抽卡）；大弹窗＝近全屏（卡组/技能/装备/挑战/存档/成就）
#     都不暂停；大弹窗顶部带状态带；血 <25% 自动收起；boss 入场强制收起
#
# 口径（用户）："按钮和字一定不要很小"——本文件按钮最小 66 高、正文 ≥ 20 号、主钮 26 号。
# 临时试玩键：E 开本壳 · H 扣 30% 血（看"血量告急自动收弹窗"）· B 叫 boss 入场
# ============================================================

const UiKit := preload("res://shared/ui_kit.gd")
const Audio := preload("res://shared/audio.gd")   # v2h：战斗音效＋BGM
const Battle := preload("res://kushou/kushou_battle.gd")   # v2j：真战斗引擎

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const PAPER_D := Color(0.84, 0.81, 0.74)
const SEAL := Color(0.68, 0.15, 0.12)
const GOLD := Color(0.86, 0.68, 0.26)
const CRYSTAL := Color(0.42, 0.62, 0.78)
const GREEN := Color(0.34, 0.55, 0.34)
const DIM := Color(0.36, 0.33, 0.31)

# ---------------- 假数据（第 2 步换成真账） ----------------
var _wave := 12
var _wave_max := 30
var _boss_sec := 37.0
var _boss_tier := 1
var _money := 1234
var _crystal := 46
var _kills := 287
var _lv := 7
var _exp := 0.62
var _hp := 860.0
var _hp_max := 1000.0
var _mp := 62.0
var _mp_max := 100.0
var _grow := 3                     # 成长值（招募继承用）
# v2d（用户："卡组有两种查询 第一种是10格的卡组 另一种是吞噬后的卡组"）：
#   卡改成带账的字典——**吃了同一张几张（ate）就升到几星**（1/2/4/8 那张表的简化：现在直接记星）
var _deck: Array = [
	{"school": "技能流", "name": "凝神", "star": 2, "ate": 3, "fx": "内力上限 +60"},
	{"school": "技能流", "name": "疾风诀", "star": 1, "ate": 1, "fx": "技能冷却 −15%"},
	{"school": "技能流", "name": "破罡", "star": 3, "ate": 7, "fx": "技能伤害 +40%"},
	{"school": "技能流", "name": "连锁", "star": 1, "ate": 0, "fx": "技能击杀 冷却 −1 秒"},
]
var _deck_tab := 0        # 0＝十格卡组 · 1＝吞噬记录（两种"查询"）
var _boss_seq := 0        # v2j：叫过几个 boss
var _revive := 1          # 浴血：免死次数（战场上真的会倒下）
# v3a 技能（基础剑法）——见 docs/困兽_技能设计稿.md
var _skill_pts := 0       # 技能点（每升 1 级 1 点）
# v5a 主属性（见 docs/困兽_属性设计稿.md）
#   臂力：气血+生命恢复；身法：攻速+护甲；悟性：内力+内力恢复
#   主属性（力量/敏捷/悟性）决定"哪一条额外转攻击 / 转元素攻击"
var _attr := {"arm": 0, "agi": 0, "wit": 0}
var _attr_pts := 0        # 属性点（每升 1 级 +2）
var _main_attr := "str"   # str＝力量 · agi＝敏捷 · wit＝悟性
# v6a 成长继承（用户："成长就是三属性了 根据角色不同特性 三属性成长也不同
#   【但是继承取最高值 保证稳步提升】"）
#   —— 三属性＝成长；每位伙伴三属性成长不同；招募时**逐项取最高**，所以只会升不会降。
var _grow_inherit := {"arm": 0, "agi": 0, "wit": 0}   # 继承到的成长（每项取所有已招募伙伴的最高）
var _recruit_opens := 0                               # 还有几次招募（每 5 级一次）
var _recruit_choices: Array = []                      # 本次招募的三个候选
var _draw_choices: Array = []                         # v8a：抽卡的三张候选
var _pending_card := ""                               # v8b：十格满了、等着"换哪张"的那张卡
var _detail_card := ""                                # v8c：正在看详情的那张卡
var _run_fame := 0                                    # v9h：本局名声（跨局那套还没做）
var _realm := 0                                       # v10a：境界 0 凡人 · 1 筑基 · 2 金丹 · 3 元婴 · 4 化神
var _meditate_acc := 0.0                              # v10a：打坐累积（每秒加，攒够 1 点进主属性）
var _card_kills := {}                                 # v10b：杀意这类"按杀敌进化"的卡：id → 已杀数

# v10b：杀敌 → 到阈值就把卡**换成下一形态**（占同一个格子，效果立刻改）
func _card_evo_tick() -> void:
	for id in _card_have.keys():
		var s := card_set_of(str(id))
		if not s.has("evo_next"):
			continue
		var need := int(s.get("evo_kills", 0))
		_card_kills[id] = int(_card_kills.get(id, 0)) + 1
		if int(_card_kills[id]) < need:
			continue
		var nid := str(s["evo_next"])
		_card_kills.erase(id)
		_card_have.erase(id)
		var at := _deck_cards.find(str(id))
		if at >= 0:
			_deck_cards[at] = nid                 # ⚠ 原地替换：还是那一格
		_card_have[nid] = 1
		_apply_solo_effect(str(card_set_of(nid)["set"]))
		_hint.text = "【" + card_name(str(id)) + "】进化 → 【" + card_name(nid) + "】"
		_field._push_float(_field.hero_pos.x, _field.hero_pos.y - 120.0,
			"进化：" + card_name(nid), Color(1.0, 0.86, 0.40), true)
		Audio.sfx("levelup", -3.0)

# 单卡（杀意/打坐）的常驻效果：进 _extra
func _apply_solo_effect(id: String) -> void:
	match str(id):
		"sayi0":
			_extra["atk_all"] = float(_extra.get("atk_all", 0.0)) + 0.06
		"sayi1":
			_extra["atk_all"] = float(_extra.get("atk_all", 0.0)) + 0.08
			_extra["crit_add"] = float(_extra.get("crit_add", 0.0)) + 0.03
		"sayi2":
			_extra["atk_all"] = float(_extra.get("atk_all", 0.0)) + 0.12
			_extra["crit_add"] = float(_extra.get("crit_add", 0.0)) + 0.05
		"sayi3":
			_extra["atk_all"] = float(_extra.get("atk_all", 0.0)) + 0.14
			_extra["crit_add"] = float(_extra.get("crit_add", 0.0)) + 0.07
			_extra["crit_dmg_bonus"] = float(_extra.get("crit_dmg_bonus", 0.0)) + 0.20
		_:
			pass
	_sync_battle_stats()
# v7a 卡牌状态
var _deck_cards: Array = []                           # 十格里的卡（id；空位用 ""）
var _card_star := {}                                  # id → 星级（1~5）
var _card_have := {}                                  # id → 已拥有张数（升星用）
var _sets_done := {}                                  # 已凑齐的套（set_id → true）
# v7b：三条成长线的"杀敌涨属性"（小数先存着，攒够 1 点进 _grow_card）
var _grow_kill := {"arm": 0.0, "agi": 0.0, "wit": 0.0}
var _grow_card := {"arm": 0, "agi": 0, "wit": 0}
const STAR_COST := [2, 3, 5, 5]                       # 默认：1★→2★ … 4★→5★ 各吃几张同名卡
# v7e（用户："还有那种六合一 八合一的也可以出"）：**升星成本按套可配**——
#   便宜线走 2/3/5/5；重卡（聚宝/同心/招怪这类）走 3/6/8/8，越重越难成型但收益也大。
const STAR_COST_HEAVY := [3, 6, 8, 8]

# 卡池总数（用户："暂定50张"）——用来在抽卡页与文档里对账
func card_pool_size() -> int:
	var n := 0
	for s_v in CARD_SETS:
		n += int((s_v as Dictionary)["size"])
	return n

func card_star_cost(id: String, star: int) -> int:
	var s := card_set_of(id)
	var arr: Array = s.get("star_cost", STAR_COST)
	var i := clampi(star - 1, 0, arr.size() - 1)
	return int(arr[i])

# 把一张卡塞进十格（有位置就进；满了返回 false，由界面去问"换哪张"）
func _card_into_deck(id: String) -> bool:
	if _deck_cards.has(id):
		return true
	for i in 10:
		if i >= _deck_cards.size():
			_deck_cards.append(id)
			return true
		if str(_deck_cards[i]) == "":
			_deck_cards[i] = id
			return true
	return false

# v7f（用户："不要升星"）：**撤掉吞噬升星**——卡只有两条成长线：
#   ①组合成套（凑齐给效果＋腾格）  ②进化/突破（下一形态直接替换原来那一张）
#   重复抽到的卡不再升星，直接**回收成灵晶**（免得白抽）。
# v10a：境界卡的"突破"——成功进境；失败**回池**（卡从手里消失，以后还能抽到）
func _realm_break(id: String, realm: int) -> bool:
	var rate: float = float([0.0, 0.75, 0.60, 0.45, 0.30][clampi(realm, 0, 4)])
	if randf() < rate:
		_realm = maxi(_realm, realm)
		Audio.sfx("levelup", -3.0)
		_hint.text = "突破成功！进入【" + card_name(id) + "】（打坐效率 ×" + str(_meditate_mult()) + "）"
		_sync_battle_stats()
		return true
	# 失败：回池
	_card_have.erase(id)
	_deck_cards.erase(id)
	Audio.sfx("fall_down", -6.0)
	_hint.text = "突破失败……【" + card_name(id) + "】已回到卡池（下次还能再抽）"
	return false

# 打坐倍率（境界越高越快）
func _meditate_mult() -> int:
	return [1, 2, 3, 5, 8][clampi(_realm, 0, 4)]

func _card_gain(id: String) -> void:
	# 境界卡：拿到就掷一次成败（失败回池）
	var cs0 := card_set_of(id)
	if cs0.has("realm"):
		var r := int(cs0["realm"])
		if r <= _realm:
			_hint.text = "已经在【" + card_name(id) + "】或更高境界了"
			return
		if not _realm_break(id, r):
			return
	if _card_have.has(id):
		_card_have[id] = int(_card_have[id]) + 1
		_crystal += 5                                  # 重复卡回收
		_hint.text = "重复的「" + card_name(id) + "」回收成 5 灵晶"
		Audio.sfx("coin", -10.0)
		return
	_card_have[id] = 1
	if cs0.has("evo_next"):
		# ⚠ 传**套名**（sayi0）不是卡 id（sayi0_0）：_apply_solo_effect 按套名匹配
		_apply_solo_effect(str(cs0["set"]))  # v10b：杀意到手先给初阶效果
	# ⚠ 这一行不能省：卡要**真的进十格**（v8b 曾把它摘掉，结果卡只记账不进格）
	if not _card_into_deck(id):
		_pending_card = id
	_set_check(str(id.split("_")[0]))

# 组合：这套的每张卡都到手了 → 给组合效果 ＋ 三张一起离开十格（腾位）
func _set_check(set_id: String) -> void:
	if bool(_sets_done.get(set_id, false)):
		return
	var s := card_set_of(set_id + "_0")
	if s.is_empty():
		return
	if bool(s.get("solo", false)):
		return                                    # v10a：单卡（打坐/境界）不成套、不腾格
	var n := int(s["size"])
	for i in n:
		if not _card_have.has(card_id(set_id, i)):
			return
	_sets_done[set_id] = true
	_sync_battle_stats()          # ⚠ 成套后立刻同步（不然新效果要等下一次受伤才生效）
	# v11e：装备卡成型 → **自动穿上六格**
	if str(s.get("cat", "")) == "装备":
		_equip_auto(str(s["name"]))
	# 成套后的常驻效果（成长线 / 经济线 / 数值线）
	match str(s.get("combo_id", "")):
		"cut_all_5":
			_extra["cut_all_bonus"] = float(_extra.get("cut_all_bonus", 0.0)) + 0.05
		"aspd_10":
			_extra["aspd_bonus"] = float(_extra.get("aspd_bonus", 0.0)) + 0.10
		"lucky_15":
			_extra["lucky"] = float(_extra.get("lucky", 0.0)) + 0.15
		"wave_crystal":
			_extra["wave_crystal"] = float(_extra.get("wave_crystal", 0.0)) + 2.0
		"chal_cd":
			_extra["chal_cd"] = float(_extra.get("chal_cd", 0.0)) + 0.15
		"chal_spawn":
			_extra["chal_spawn"] = float(_extra.get("chal_spawn", 0.0)) + 3.0
		"partner_grow":
			_extra["partner_grow"] = float(_extra.get("partner_grow", 0.0)) + 1.0
		"elem_all_15":
			for el in ["金系", "木系", "火系", "水系", "土系"]:
				_extra["dmg_elem"][el] = float(_extra["dmg_elem"].get(el, 0.0)) + 0.15
		"elem_fire_20":
			_extra["dmg_elem"]["火系"] = float(_extra["dmg_elem"].get("火系", 0.0)) + 0.20
		"elem_water_20":
			_extra["dmg_elem"]["水系"] = float(_extra["dmg_elem"].get("水系", 0.0)) + 0.20
		"elem_metal_20":
			_extra["dmg_elem"]["金系"] = float(_extra["dmg_elem"].get("金系", 0.0)) + 0.20
		"atk_all_12":
			_extra["atk_all"] = float(_extra.get("atk_all", 0.0)) + 0.12
		"critdmg_40":
			_extra["crit_dmg_bonus"] = float(_extra.get("crit_dmg_bonus", 0.0)) + 0.40
		"arrow_pierce":
			_extra["arrow_pierce"] = 1.0
			_extra["cg_feiyu"] = 1.0
			_extra["cg_feiyu_pierce"] = 1.0
		"thunder_para":
			_extra["thunder_para"] = 1.0
			_extra["cg_leiting"] = 1.0
			_extra["cg_leiting_para"] = 1.0
		"cut_all_6":
			_extra["cut_all_bonus"] = float(_extra.get("cut_all_bonus", 0.0)) + 0.06
		"skill_cd_12":
			_extra["skill_cd"] = float(_extra.get("skill_cd", 0.0)) + 0.12
		# v9e 装备卡：装备槽 / 宝物槽 / 开局装备
		"equip_slot":
			_extra["equip_slot"] = float(_extra.get("equip_slot", 0.0)) + 1.0
			_hint.text = "兵器·剑 成型：装备槽 +1"
		"treasure_slot":
			_extra["treasure_slot"] = float(_extra.get("treasure_slot", 0.0)) + 1.0
			_hint.text = "宝器 成型：宝物槽 +1"
		"start_equip_up":
			_extra["start_equip_up"] = float(_extra.get("start_equip_up", 0.0)) + 1.0
		"thorns_50":
			_extra["thorns"] = float(_extra.get("thorns", 0.0)) + 0.30
		_:
			pass
	for i in n:
		_deck_cards.erase(card_id(set_id, i))     # 腾出占位（效果保留）
	_field._push_float(_field.hero_pos.x, _field.hero_pos.y - 100.0, "组合完成：" + str(s["name"]), Color(1.0, 0.86, 0.40), true)
	Audio.sfx("chest", -3.0)
	_hint.text = "【" + str(s["name"]) + "】组合完成：" + str(s["combo"]) + "　卡已腾出占位，效果转常驻"
# v5f：装备/伙伴以后往这里塞这些（现在全是 0，接口先留着）
var _extra := {
	"lucky": 0.0,          # 幸运一击（0~3.0，上限 300%）
	"dmg_all": 0.0,        # 全伤害增加
	"res_elem": {},        # 各元素抗性 {金系: 0.1, …}
	"dmg_elem": {},        # 各元素加成
	"dmg_true": 0.0,       # 加真实伤害（唯一能影响真实伤害的一条）
	# 卡给的常驻（v7b/v7c）
	"cut_all_bonus": 0.0,  # 铁壁套：全伤害减免 +
	"aspd_bonus": 0.0,     # 疾风套：攻速 +
	"wave_crystal": 0.0,   # 商路套：每波额外灵晶
	"chal_cd": 0.0,        # 连战/招怪：挑战冷却 −
	"chal_spawn": 0.0,     # 招怪套：挑战多刷几只
	"partner_grow": 0.0,   # 同心套：招募时伙伴成长 +N
	"partner_dmg": 0.0,    # 同心：伙伴技能伤害 +
	"equip_slot": 0.0,     # v9e 兵器·剑：装备槽 +
	"treasure_slot": 0.0,  # v9e 宝器：宝物槽 +
	"start_equip_up": 0.0, # v9e 神兵：开局自带装备
	"thorns": 0.0,         # 荆棘/护心镜：反伤比例
}
var _skill_choices: Array = []
var _skill_badge: Label = null
var _partner_lbs: Array = []
var _mini_lv: Label = null        # 黑市下面那条小经验条（v4c）
var _mini_exp: ColorRect = null
# v4d（用户："每次击杀一名敌人 会让黑市经验条+1 同时180秒增加一次黑市刷新次数"）：
#   这条小经验条是**黑市自己的**——击杀 +1 经验；每 180 秒送 1 次"刷新次数"（用来换货架）。
var _bm_lv := 1                   # 黑市等级
var _bm_exp := 0                  # 黑市经验（每击杀 +1）
var _bm_need := 100               # 升下一级要多少（每级 +50）
var _bm_refresh := 1              # 刷新次数
var _bm_t := 0.0                  # 距离下一次 +1 刷新还差多久（满 180 送一次）
const BM_REFRESH_SEC := 180.0
# v13a 黑市重做（规格：docs/困兽_交接文档.md §6.1）：六格货架 · 买掉即空 · 只手动刷新 · 每件 30% 概率打折
var _bm_slots: Array = []         # 六格货架（{id,n,d,base,disc,cost,q,gear,bought}）
var _bm_atk := 0                  # 「消耗型装备·小」累积的攻（可重复买，叠加）
var _bm_hp := 0                   # 「消耗型装备·小」累积的血
var _bm_eaten: Array = []         # 被吞噬丹吞掉的卡（id；效果与成套计数照留）
var _card_refresh := 0            # 卡组刷新次数（黑市货品，抽卡页免费全刷用）
# ============================================================
# v13c P2：事件 / 任务（规格：docs/困兽_事件与任务_设计稿.md）
#   · 每 180 秒触发一次事件 → **自动挂进任务栏**（最多 2 个，挂满就顺延）
#   · 放弃 = +10 灵晶（抽卡 20 的一半）；限时到点 = 失败，**什么都不给**
# ============================================================
const Q_MAX := 2
const Q_EVENT_SEC := 180.0
const Q_GIVE_CRYSTAL := 10
var _q_slots: Array = []          # 进行中任务：{id,n,d,ck,goal,sec,left,base,alive,tier…}
var _q_t := 0.0                   # 距下一次事件还有多久
var _q_done := 0
var _q_give := 0
var _q_fail := 0
var _q_ctr := {}                  # 行为计数（任务进度的来源）
var _q_lb: Array = []             # HUD 上那两条任务条
var _q_panel: Panel = null
var _over := false        # 这一局结束没有
# v2f（用户这一轮的四条）：
#   · 吞噬记录/卡面**不标流派**（"这种是玩家自己发掘的"）
#   · **长按卡牌**看全部效果
#   · 装备**最多六格** · 宝物**不限**（滚动区自己长）· 多一个**仓库/公共仓库**窗口，
#     超出格子的可以**长按拖拽**放进仓库（点击看详情）
#   · 角色页要有**详细属性** ＋ 一颗**队员**钮（点队员看"成长 ＋ 携带技能"）
var _card_idx := 0                                  # 长按看详情的那张卡
var _equip_tab := 0                                 # 0＝装备 · 1＝宝物
var _equip: Array = ["青锋剑", "铁叶甲", "", "", "", ""]      # 装备：**最多六格**
var _equip_q: Array = ["良品", "良品", "", "", "", ""]
var _treasures: Array = ["护心镜", "玄铁令", "定神珠"]         # 宝物：**不限**（滚动区接着长）
var _treasure_q: Array = ["上品", "凡品", "良品"]
var _vault: Array = ["紫玉冠", "雁翎披风", "疗伤丹", "金丝软甲"] # 仓库（公共仓库＝联网共享，暂不开放）
var _vault_stat: Array = []                       # v11f：仓库里那些的属性
var _equip_stat: Array = [{}, {}, {}, {}, {}, {}]  # v11f：六格装备的属性（加成从这里汇总）
var _vault_q: Array = ["上品", "良品", "凡品", "极品"]
var _carry := ""                                    # 长按拿起来的那件：equip:2 / vault:1 / treasure:0
var _role_tab := 0                                  # 0＝属性 · 1＝队员
var _mates: Array = [
	{"name": "陈石", "grow": 3, "skills": ["守拙", "扎马稳桩"]},
	{"name": "苏青鸾", "grow": 5, "skills": ["惊鸿照影", "引气归元"]},
]
var _skills := ["追风剑 3★", "护体式 1★"]
var _equips := ["兵器·青锋剑（良品）", "护甲·铁叶甲（良品）", "玉佩·空", "披风·空", "宝物·空", "宝物·空"]
var _events := 0
var _popup_kind := ""
var _popup: Control = null
var _band: Label = null
var _cp: Control = null          # 弹窗内容区（在 ScrollContainer 里，装不下就手指拖着看）
var _field = null
var _hp_lb: Label = null
var _mp_lb: Label = null
var _hp_bar = null
var _mp_bar = null
var _boss_lb: Label = null
var _wave_lb: Label = null
var _money_lb: Label = null
var _crystal_lb: Label = null
var _kill_lb: Label = null
var _exp_lb: Label = null
var _exp_bar = null
var _hint: Label = null
# v2c：挑战**全部搬进［挑战］弹窗**（用户："最底部的挑战放在挑战按钮里吧 还能扩大点空间"
#   ＋"挑战的可自动按钮也要放在里面"）——主界面上只剩那颗圆钮 ＋ 右上角"几个能点"的小红点，
#   "自动挑战"从原来的第 6 格改成弹窗底部那颗**大开关**。
var _chal_cd := [12.0, 0.0, 40.0, 90.0, 0.0]      # 五个挑战的冷却（0＝就绪）
# v2c：第一格从"金币挑战"改名"**文钱挑战**"（用户："金币挑战换成文钱挑战 名字改一下即可"）——
#   本作里那门钱就叫"文钱"，别混着两种叫法。
var _chal_names := ["文钱挑战", "灵晶挑战", "经验挑战", "宝物挑战", "boss挑战"]
var _chal_descs := ["一群钱怪（6 只），掉 30~60 文钱", "一群晶怪（3 只），每只掉 6~10 灵晶", "一群书怪（4 只），掉一大笔经验", "一只大宝箱怪（大怪），掉宝物或大钱", "boss 亲自来（大怪），赢额外名声）"]
var _auto_chal := false                            # 自动挑战开关（弹窗底部那颗）
var _chal_lbs: Array = []
var _chal_pop_lbs: Array = []
var _chal_badge: Label = null
var _chal_btn: Button = null
var _auto_btn: Button = null

# ⚠ 注意 visible 的时序：外面习惯是"add_child 完就 open()"，而 add_child 进来的这一帧
#   `_ready` 可能还没跑（SceneTree 建场那会儿是延迟的）——如果 _ready 里硬写 visible=false，
#   里面 open() 设的 visible=true 会被覆盖；所以这里用 _want_open 标记，_ready 只看标记
var _want_open := false

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_bm_roll()          # v13a：开局先摆一轮黑市货（六格）
	visible = _want_open

func open() -> void:
	_want_open = true
	visible = true
	move_to_front()
	Audio.play_bgm("bgm_battle", 0.6)      # v2h：进场就是战斗曲（与爬塔同一首）

func close() -> void:
	_want_open = false
	visible = false
	_close_popup()
	Audio.play_bgm(Audio.menu_track(), 1.2)   # 回主界面：换回玩家选的那首

# ============================================================
# 搭建
# ============================================================
func _build() -> void:
	var vp := get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.14, 0.97)
	bg.size = vp
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_hud()
	_build_field()
	_build_hero_bar()
	# v2c（用户："最底部的挑战放在挑战按钮里吧 还能扩大点空间"）：
	#   底下那排六格**整块撤掉**，226 像素让给战场（616→704）与主角条（176→272）；

	# 底部提示（临时，第 2 步去掉）
	# 钱币飞行层：压在所有面板之上（不然钱会钻到面板底下），不接鼠标
	_coin_layer = CoinLayer.new()
	_coin_layer.host = self
	_coin_layer.size = vp
	_coin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_coin_layer)

	_hint = _lbl(Vector2(20, 1258), Vector2(680, 22), 18, Color(0.62, 0.60, 0.58))
	_hint.text = "空壳预览 · E 关 · H 扣血 · B 叫 boss"
	add_child(_hint)

# ---- 顶部 HUD：两行（第一行大字，第二行三个钱账） ----
func _build_hud() -> void:
	var r1 := _panel(Rect2(8, 8, 704, 80), Color(0.18, 0.17, 0.19, 0.96), 12)
	_wave_lb = _lbl(Vector2(24, 22), Vector2(190, 52), 28, PAPER)
	_wave_lb.text = "波 12/30"
	_boss_lb = _lbl(Vector2(226, 26), Vector2(300, 46), 22, GOLD)
	_boss_lb.text = "一阶 boss 00:37"      # 开局静态文本；_process 里会按 分:秒 覆写
	_mk_btn("设置", Vector2(560, 14), Vector2(140, 68), 24, false, func(): _open_small("设置"))

	# v2b：三个钱账**带图标**（用户："货币记得加图标"）——图标是画出来的，不新增素材
	var r2 := _panel(Rect2(8, 94, 704, 74), Color(0.18, 0.17, 0.19, 0.96), 12)
	var i1 := IconArt.new()
	i1.kind = "coin"
	i1.position = Vector2(20, 108)
	i1.size = Vector2(44, 44)
	i1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(i1)
	_money_lb = _lbl(Vector2(70, 110), Vector2(170, 44), 26, PAPER)
	var i2 := IconArt.new()
	i2.kind = "crystal"
	i2.position = Vector2(256, 108)
	i2.size = Vector2(44, 44)
	i2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(i2)
	_crystal_lb = _lbl(Vector2(306, 110), Vector2(150, 44), 26, PAPER)
	var i3 := IconArt.new()
	i3.kind = "kill"
	i3.position = Vector2(468, 108)
	i3.size = Vector2(44, 44)
	i3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(i3)
	_kill_lb = _lbl(Vector2(518, 110), Vector2(180, 44), 26, PAPER)

# ---- 战场：假打的小人 + 左右圆钮 ----
func _build_field() -> void:
	var bg := _panel(Rect2(8, 176, 704, 704), Color(0.16, 0.16, 0.18, 0.96), 12)
	# v2j：战场换成**真战斗引擎**（kushou/kushou_battle.gd）——刷怪/走位/出手/飘字/浴血都在那边
	_field = Battle.new()
	_field.size = Vector2(704, 704)
	_field.position = Vector2(8, 176)
	# v13b P1：战场**要接点击**（点空地＝走位指令 · 点怪＝集火）——原来 IGNORE 是穿过去的
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	# ⚠ 不裁剪的话，怪从上面"走进来"那一段会画到 HUD 上（截图里 boss 的名字跟倒计时叠在一起）
	_field.clip_contents = true
	add_child(_field)
	_field.coin.connect(_on_coin)
	_field.coin_drop.connect(_on_coin_drop)
	_field.kill.connect(_on_kill)
	_field.chal_drop.connect(_on_chal_drop)      # v9h：挑战怪掉落
	_field.hero_down.connect(_on_hero_down)
	_field.boss_arrived.connect(_on_boss)
	_field.special.connect(_on_special)
	_sync_battle_stats()
	_field.set_wave(_wave)
	_field.start_run()          # v3h：开场先站几秒（怪先走进画面），再"远快近慢"地压上去

	_circle_btn("抽卡", Vector2(22, 262), func(): _open_small("抽卡"))
	_chal_btn = _circle_btn("挑战", Vector2(22, 396), func(): _open_large("挑战"))
	# 就绪数量做成圆钮右上角的小红点（原来靠底下那排显示"哪个能点"，现在得在这儿说）
	_chal_badge = _lbl(Vector2(94, 384), Vector2(56, 36), 22, Color(1, 0.94, 0.88))
	_chal_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
_circle_btn("任务", Vector2(22, 530), func(): _open_large("任务"))
	_circle_btn("卡组", Vector2(22, 664), func(): _open_large("卡组"))
	_circle_btn("存档", Vector2(594, 340), func(): _open_large("存档"))
	_circle_btn("成就", Vector2(594, 480), func(): _open_large("成就"))
	# v4b（用户："成就下面增加按钮 黑市【用于杀敌数兑换东西的 内容暂定】"）
	_circle_btn("黑市", Vector2(594, 620), func(): _open_large("黑市"))
	# v4c（用户："黑市下面加一个小型经验条 和等级"）——黑市钮正下方一条小经验条
	_panel(Rect2(500, 736, 198, 66), Color(0.18, 0.17, 0.19, 0.96), 10)
	_mini_lv = _lbl(Vector2(508, 740), Vector2(182, 28), 19, PAPER)
	_mini_lv.text = "黑市 Lv 1"
	_mini_exp = _bar(Rect2(510, 776, 178, 14), Color(0.56, 0.44, 0.72))

# ---- 经验条 + 主角条 ----
func _build_hero_bar() -> void:
	_panel(Rect2(8, 888, 704, 72), Color(0.18, 0.17, 0.19, 0.96), 12)
	_exp_lb = _lbl(Vector2(24, 902), Vector2(110, 44), 26, PAPER)
	_exp_bar = _bar(Rect2(146, 908, 548, 32), Color(0.30, 0.42, 0.62))

	var hb := _panel(Rect2(8, 968, 704, 288), Color(0.18, 0.17, 0.19, 0.96), 12)
	# 头像
	var av := AvatarArt.new()
	av.size = Vector2(176, 176)
	av.position = Vector2(24, 984)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(av)
	var av_btn := _mk_btn("", Vector2(24, 984), Vector2(176, 176), 20, false, func(): _open_large("角色"))
	av_btn.flat = true
	av_btn.add_theme_stylebox_override("normal", _flat(Color(0, 0, 0, 0)))
	av_btn.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.06)))
	av_btn.add_theme_stylebox_override("pressed", _flat(Color(1, 1, 1, 0.10)))
	# 生命 / 内力
	_hp_lb = _lbl(Vector2(216, 986), Vector2(470, 40), 24, PAPER)
	_hp_bar = _bar(Rect2(216, 1030, 470, 38), Color(0.52, 0.22, 0.20))
	_mp_lb = _lbl(Vector2(216, 1082), Vector2(470, 40), 24, PAPER)
	_mp_bar = _bar(Rect2(216, 1126, 470, 38), Color(0.30, 0.42, 0.62))
	# 技能 / 装备：底部两颗**大**钮（用户："按钮和字一定不要很小"）
	_mk_btn("技能 ＋", Vector2(24, 1174), Vector2(336, 74), 26, false, func(): _open_large("技能"))
	# 有技能点没花的时候，钮右上角亮个红点（"＋"号）
	_skill_badge = _lbl(Vector2(318, 1162), Vector2(36, 32), 24, Color(1.0, 0.84, 0.34))
	_skill_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_badge.text = ""
	_mk_btn("装备·宝物 ＋", Vector2(372, 1174), Vector2(336, 74), 26, false, func(): _open_large("装备"))
	# v12a：玲珑玉壶（主动宝物）——战场右下角一颗大按钮 ＋ 一颗自动开关
	_yh_btn = _mk_btn("玉壶", Vector2(596, 792), Vector2(104, 104), 26, true, _yh_use)
	_yh_lb = Label.new()
	_yh_lb.position = Vector2(560, 900)
	_yh_lb.size = Vector2(176, 34)
	_yh_lb.add_theme_font_size_override("font_size", 20)
	_yh_lb.add_theme_color_override("font_color", DIM)
	_yh_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_yh_lb.text = "玉壶 就绪"
	add_child(_yh_lb)
	_yh_auto_btn = _mk_btn("自动：开", Vector2(560, 936), Vector2(176, 44), 20, false, _yh_toggle_auto)


# ---- 招募页（v6a）：三个候选，选一个把"成长"并进来（逐项取最高）----
func _fill_recruit(p: Control, y: float, sz: Vector2) -> float:
	var head := Label.new()
	head.position = Vector2(28, y)
	head.size = Vector2(640, 46)
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", INK)
	head.text = "招募机会 " + str(_recruit_opens) + " 次　（成长继承：逐项取最高）"
	p.add_child(head)
	var cur := Label.new()
	cur.position = Vector2(28, y + 50.0)
	cur.size = Vector2(640, 36)
	cur.add_theme_font_size_override("font_size", 21)
	cur.add_theme_color_override("font_color", DIM)
	cur.text = "当前继承：臂力 " + str(int(_grow_inherit["arm"])) + "　身法 " + str(int(_grow_inherit["agi"]))
	cur.text += "　悟性 " + str(int(_grow_inherit["wit"]))
	p.add_child(cur)
	if _recruit_opens <= 0:
		var t0 := Label.new()
		t0.position = Vector2(28, y + 96.0)
		t0.size = Vector2(640, 60)
		t0.add_theme_font_size_override("font_size", 22)
		t0.add_theme_color_override("font_color", DIM)
		t0.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t0.text = "现在没有招募机会——每升 5 级给一次。"
		p.add_child(t0)
		return y + 170.0
	if _recruit_choices.is_empty():
		_recruit_choices = _roll_recruits()
	var ly := y + 100.0
	for i in _recruit_choices.size():
		var pid := str(_recruit_choices[i])
		var info: Dictionary = _field.PARTNER_INFO[pid]
		var g: Dictionary = info.get("grow", {})
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.97, 0.92)
		sb.set_corner_radius_all(12)
		sb.border_color = Color(SEAL.r, SEAL.g, SEAL.b, 0.5)
		sb.set_border_width_all(2)
		var box := Panel.new()
		box.position = Vector2(28, ly)
		box.size = Vector2(640, 150)
		box.add_theme_stylebox_override("panel", sb)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(box)
		var nm := Label.new()
		nm.position = Vector2(18, 12)
		nm.size = Vector2(430, 44)
		nm.add_theme_font_size_override("font_size", 26)
		nm.add_theme_color_override("font_color", INK)
		nm.text = str(info["name"]) + "　【" + str(info["quality"]) + "】　" + str(info["skill"])
		box.add_child(nm)
		var gl := Label.new()
		gl.position = Vector2(18, 60)
		gl.size = Vector2(600, 36)
		gl.add_theme_font_size_override("font_size", 22)
		gl.add_theme_color_override("font_color", SEAL)
		gl.text = "成长：臂力 +" + str(int(g.get("arm", 0))) + "　身法 +" + str(int(g.get("agi", 0)))
		gl.text += "　悟性 +" + str(int(g.get("wit", 0)))
		box.add_child(gl)
		var dl := Label.new()
		dl.position = Vector2(18, 100)
		dl.size = Vector2(600, 34)
		dl.add_theme_font_size_override("font_size", 19)
		dl.add_theme_color_override("font_color", DIM)
		dl.text = str(info["desc"]).replace("**", "")
		box.add_child(dl)
		_pbtn(box, "招募", Vector2(496, 96), Vector2(126, 44), 22, true, _recruit.bind(pid))
		ly += 162.0
	return ly

# 抽三个候选：品质越高越少见（权重：下 30 · 中 25 · 上 20 · 极 15 · 绝 10），不重复
func _roll_recruits() -> Array:
	var pool: Array = []
	for pid in _field.PARTNER_INFO.keys():
		# v6b：**每种只能选一次**——已经入队的不再出现
		if bool((_field.partners[pid] as Dictionary)["owned"]):
			continue
		var q := str((_field.PARTNER_INFO[pid] as Dictionary)["quality"])
		var w: int = int({"下品": 30, "中品": 25, "上品": 20, "极品": 15, "绝品": 10}.get(q, 20))
		for i in w:
			pool.append(str(pid))
	var out: Array = []
	while out.size() < 3 and pool.size() > 0:
		var pick := str(pool[randi() % pool.size()])
		if not out.has(pick):
			out.append(pick)
	return out
# ============================================================
# v7a 卡牌（用户口径）：一张卡＝**单卡属性 ＋ 组合**；
#   组合按【编号】分（I/II/III…），卡片有**品级与颜色**（跟伙伴同一套配色）；
#   凑齐一套 → **给组合效果**、三张**一起离开十格（腾位）**、效果**转常驻**、
#   并且这些卡**从池子里永久移除**（不回池）；同名卡走**吞噬升星 2/3/5/5**。
#   长线（5 张）与短线（2~3 张）都有。
# ============================================================
const CARD_SETS := [
	{"set": "liliang", "name": "力量祝福", "quality": "下品", "size": 3,
		"combo": "每杀一名敌人 → 臂力 +0.2（本局永久叠加）", "combo_id": "kill_arm", "grow": "arm"},
	{"set": "tayun", "name": "踏云步", "quality": "下品", "size": 3,
		"combo": "每杀一名敌人 → 身法 +0.2（本局永久叠加）", "combo_id": "kill_agi", "grow": "agi"},
	{"set": "jingxin", "name": "静心诀", "quality": "中品", "size": 3,
		"combo": "每杀一名敌人 → 悟性 +0.2（本局永久叠加）", "combo_id": "kill_wit", "grow": "wit"},
	{"set": "tiebi", "name": "铁壁", "quality": "中品", "size": 2,
		"combo": "全伤害减免 +5%", "combo_id": "cut_all_5"},
	{"set": "jifeng", "name": "疾风", "quality": "中品", "size": 2,
		"combo": "攻速 +10%", "combo_id": "aspd_10"},
	{"set": "jubao", "name": "聚宝", "quality": "上品", "size": 3, "star_cost": [3, 6, 8, 8],
		"combo": "幸运一击 +15%", "combo_id": "lucky_15"},
	{"set": "shanglu", "name": "商路", "quality": "上品", "size": 2,
		"combo": "每波额外 +2 灵晶", "combo_id": "wave_crystal"},
	{"set": "lianzhan", "name": "连战", "quality": "极品", "size": 2,
		"combo": "挑战冷却 −15%", "combo_id": "chal_cd"},
	# v7c（用户："还有增加挑战怪的卡也要 招募队员会增强的卡也要"）
	{"set": "zhaoguai", "name": "招怪", "quality": "上品", "size": 3, "star_cost": [3, 6, 8, 8],
		"combo": "挑战一次多刷 3 只怪（挑战怪也吃这条）", "combo_id": "chal_spawn"},
	{"set": "tongxin", "name": "同心", "quality": "极品", "size": 3, "star_cost": [3, 6, 8, 8],
		"combo": "招募时伙伴成长 +1（三属性各 +1 后再并入继承）", "combo_id": "partner_grow"},
	# ---- v7g（用户："多加一些卡 3合的 2合的啊 毕竟还有元素的 攻击的 额外特效的"）----
	# 元素线
	{"set": "wuxing", "name": "五行", "quality": "上品", "size": 3,
		"combo": "全元素伤害 +15%", "combo_id": "elem_all_15"},
	{"set": "lieyan", "name": "烈焰", "quality": "中品", "size": 2,
		"combo": "火系伤害 +20%", "combo_id": "elem_fire_20"},
	{"set": "hanshui", "name": "寒水", "quality": "中品", "size": 2,
		"combo": "水系伤害 +20%", "combo_id": "elem_water_20"},
	{"set": "jinglei", "name": "惊雷", "quality": "上品", "size": 2,
		"combo": "金系伤害 +20%", "combo_id": "elem_metal_20"},
	# 攻击线
	{"set": "cuifeng", "name": "淬锋", "quality": "下品", "size": 3,
		"combo": "攻击 +12%", "combo_id": "atk_all_12"},
	{"set": "liebo", "name": "裂帛", "quality": "中品", "size": 2,
		"combo": "暴击伤害 +40%", "combo_id": "critdmg_40"},
	# 额外特效线（触发型，等战场接）
	{"set": "feiyu", "name": "飞羽", "quality": "上品", "size": 2,
		"combo": "飞羽改为**穿透**（一支箭穿两个）", "combo_id": "arrow_pierce"},
	{"set": "leiting", "name": "雷霆", "quality": "极品", "size": 2,
		"combo": "暴击落雷必定麻痹 1 秒", "combo_id": "thunder_para"},
	# v7h（用户："暂定50张吧"）——补两套 3 合的，凑满 **50 张**
	{"set": "panshi", "name": "磐石", "quality": "中品", "size": 3,
		"combo": "全伤害减免 +6%", "combo_id": "cut_all_6"},
	{"set": "lingxi", "name": "灵犀", "quality": "上品", "size": 3,
		"combo": "技能冷却 −12%", "combo_id": "skill_cd_12"},
	# ---- v7i（用户："100张吧"）：再补 50 张 → 合计 40 套 / 100 张 ----
	{"set": "muling", "name": "木灵", "quality": "中品", "size": 3, "combo": "木系伤害 +20%", "combo_id": "elem_wood_20"},
	{"set": "houtu", "name": "厚土", "quality": "中品", "size": 3, "combo": "土系伤害 +20%", "combo_id": "elem_earth_20"},
	{"set": "bingxin", "name": "冰心", "quality": "上品", "size": 3, "combo": "技能冷却 −12%", "combo_id": "skill_cd_12b"},
	{"set": "xuezhan", "name": "血战", "quality": "中品", "size": 3, "combo": "攻击 +12%", "combo_id": "atk_all_12"},
	{"set": "xunying", "name": "迅影", "quality": "上品", "size": 3, "combo": "攻速 +15%", "combo_id": "aspd_15"},
	{"set": "jingang", "name": "金刚", "quality": "上品", "size": 3, "combo": "全伤害减免 +8%", "combo_id": "cut_all_6"},
	{"set": "liesha", "name": "猎杀", "quality": "极品", "size": 3, "combo": "幸运一击 +20%", "combo_id": "lucky_20"},
	{"set": "wudao", "name": "悟道", "quality": "极品", "size": 3, "combo": "属性点 +3", "combo_id": "attr_pts_3"},
	{"set": "shouhun", "name": "兽魂", "quality": "上品", "size": 3, "combo": "伙伴技能伤害 +20%", "combo_id": "partner_dmg_20"},
	{"set": "leifa", "name": "雷罚", "quality": "绝品", "size": 3, "combo": "暴击落雷必定麻痹 1 秒", "combo_id": "thunder_para"},
	{"set": "tieqi", "name": "铁骑", "quality": "中品", "size": 2, "combo": "攻击 +10%", "combo_id": "atk_all_12"},
	{"set": "pojun", "name": "破军", "quality": "上品", "size": 2, "combo": "暴击伤害 +50%", "combo_id": "critdmg_40"},
	{"set": "lingmao", "name": "灵猫", "quality": "中品", "size": 2, "combo": "闪避 +8%", "combo_id": "dodge_8"},
	{"set": "jinzhong", "name": "金钟", "quality": "上品", "size": 2, "combo": "全伤害减免 +6%", "combo_id": "cut_all_6"},
	{"set": "caishen", "name": "财神", "quality": "上品", "size": 2, "combo": "每波额外 +3 灵晶", "combo_id": "wave_crystal"},
	{"set": "zhangu", "name": "战鼓", "quality": "极品", "size": 2, "combo": "挑战多刷 2 只", "combo_id": "chal_spawn"},
	{"set": "shuangxiu", "name": "双修", "quality": "极品", "size": 2, "combo": "招募时伙伴成长 +1", "combo_id": "partner_grow"},
	{"set": "liuxing", "name": "流星", "quality": "极品", "size": 2, "combo": "落星改为范围", "combo_id": "star_aoe"},
	{"set": "jingji", "name": "荆棘", "quality": "上品", "size": 2, "combo": "反伤 +50%", "combo_id": "thorns_50"},
	{"set": "tianming", "name": "天命", "quality": "绝品", "size": 2, "combo": "幸运一击 +30%", "combo_id": "lucky_20"},
	# ---- v9e（用户："然后加入装备卡"）：**装备卡**这一类 ----
	#   单卡给装备向的数值；组合给"装备槽/开局装备"这类**元效果**
	{"set": "bingqi", "name": "兵器·剑", "quality": "中品", "size": 3, "cat": "装备",
		"combo": "开局自带一件兵器（装备槽 +1）", "combo_id": "equip_slot"},
	{"set": "dao", "name": "兵器·刀", "quality": "中品", "size": 2, "cat": "装备",
		"combo": "攻击 +10%", "combo_id": "atk_all_12"},
	{"set": "ruanjia", "name": "软甲", "quality": "中品", "size": 2, "cat": "装备",
		"combo": "全伤害减免 +5%", "combo_id": "cut_all_6"},
	{"set": "baoqi", "name": "宝器", "quality": "上品", "size": 3, "cat": "装备",
		"combo": "宝物槽 +1（宝物不限格，这条再送一格）", "combo_id": "treasure_slot"},
	{"set": "shenbing", "name": "神兵", "quality": "极品", "size": 2, "cat": "装备",
		"combo": "开局自带一件上品装备", "combo_id": "start_equip_up"},
	{"set": "huxinjing", "name": "护心镜", "quality": "上品", "size": 2, "cat": "装备",
		"combo": "反伤 +30%", "combo_id": "thorns_50"},
	# ---- v10a（用户："打坐 是每秒主属性增加 然后 卡池会出 筑基境 金丹等等境界 一个个出现
	#       当拿筑基会有多少几率突破失败 拿金丹也是；失败了会重新进入卡池"）----
	#   打坐：每秒涨主属性（本局永久叠加）；境界卡一个个解锁，拿了当场掷成败，失败即回池。
	{"set": "dazuo", "name": "打坐", "quality": "下品", "size": 1, "solo": true,
		"combo": "每秒 主属性 +0.02（本局永久叠加）", "combo_id": "meditate"},
	{"set": "zhuji", "name": "筑基境", "quality": "中品", "size": 1, "solo": true, "realm": 1,
		"combo": "突破 75%（失败回池）→ 打坐效率 ×2", "combo_id": "realm_1"},
	{"set": "jindan", "name": "金丹境", "quality": "上品", "size": 1, "solo": true, "realm": 2,
		"combo": "突破 60%（失败退筑基）→ 打坐 ×3 · 气血 +15%", "combo_id": "realm_2"},
	{"set": "yuanying", "name": "元婴境", "quality": "极品", "size": 1, "solo": true, "realm": 3,
		"combo": "突破 45%（失败退金丹）→ 打坐 ×5 · 全属性 +25%", "combo_id": "realm_3"},
	{"set": "huashen", "name": "化神境", "quality": "绝品", "size": 1, "solo": true, "realm": 4,
		"combo": "突破 30%（失败退元婴）→ 打坐 ×8 · 全属性 +50% · 元素 +30%", "combo_id": "realm_4"},
	# ---- v10b（用户："杀敌进化的卡也要"）：**杀意**——杀敌到阈值就**换成下一形态**（同一个格子）----
	{"set": "sayi0", "name": "杀意·初", "quality": "下品", "size": 1, "solo": true,
		"evo_next": "sayi1", "evo_kills": 60, "combo": "杀敌 60 → 杀意·成", "combo_id": "sayi1"},
	{"set": "sayi1", "name": "杀意·成", "quality": "中品", "size": 1, "solo": true, "evo_from": true,
		"evo_next": "sayi2", "evo_kills": 200, "combo": "杀敌 200 → 杀意·极", "combo_id": "sayi2"},
	{"set": "sayi2", "name": "杀意·极", "quality": "上品", "size": 1, "solo": true, "evo_from": true,
		"evo_next": "sayi3", "evo_kills": 500, "combo": "杀敌 500 → 杀意·绝", "combo_id": "sayi3"},
	{"set": "sayi3", "name": "杀意·绝", "quality": "极品", "size": 1, "solo": true, "evo_from": true,
		"combo": "已是极致：攻击 +40% · 暴击 +15% · 暴伤 +20%", "combo_id": "sayi4"},
	# ---- v11d（用户：装备卡三类 × 五用途）①杀怪提升 ②固定特效 ③时间进化 ----
	# ① 杀怪提升（单卡，复用 evo_kills：到点原地进化）
	{"set": "yinxue", "name": "饮血刀", "quality": "中品", "size": 1, "solo": true, "cat": "装备",
		"evo_next": "yinxue2", "evo_kills": 80, "combo": "杀敌 80 → 进化（吸血）", "combo_id": "yinxue1"},
	{"set": "yinxue2", "name": "饮血·嗜", "quality": "上品", "size": 1, "solo": true, "cat": "装备", "evo_from": true,
		"evo_next": "yinxue3", "evo_kills": 300, "combo": "杀敌 300 → 进化（大吸血）", "combo_id": "yinxue2"},
	{"set": "yinxue3", "name": "饮血·狂", "quality": "极品", "size": 1, "solo": true, "cat": "装备", "evo_from": true,
		"combo": "攻击 +18% · 吸血 8%", "combo_id": "yinxue3"},
	{"set": "pojunq", "name": "破军枪", "quality": "上品", "size": 1, "solo": true, "cat": "装备",
		"evo_next": "pojunq2", "evo_kills": 120, "combo": "杀敌 120 → 进化（溅射）", "combo_id": "pojun1"},
	{"set": "pojunq2", "name": "破军·裂", "quality": "极品", "size": 1, "solo": true, "cat": "装备", "evo_from": true,
		"combo": "攻击 +14% · 攻击溅射", "combo_id": "pojun2"},
	# ② 固定特效（成套，凑齐才生效）
	{"set": "chixiao", "name": "赤霄剑", "quality": "上品", "size": 2, "cat": "装备",
		"combo": "成型：攻击溅射（打周围）", "combo_id": "splash_equip"},
	{"set": "suozijia", "name": "锁子甲", "quality": "中品", "size": 2, "cat": "装备",
		"combo": "成型：每 5 秒一层护盾", "combo_id": "shield_equip"},
	{"set": "jucaizhu", "name": "聚财珠", "quality": "上品", "size": 2, "cat": "装备",
		"combo": "成型：文钱 +25% · 灵晶 +15%", "combo_id": "money_equip"},
	{"set": "yubanzhi", "name": "玉扳指", "quality": "极品", "size": 3, "cat": "装备",
		"combo": "成型：全属性 +8%", "combo_id": "allattr_equip"},
	# ③ 时间进化（单卡，每秒 tick，到点进化）
	{"set": "cuihuo", "name": "淬火剑", "quality": "中品", "size": 1, "solo": true, "cat": "装备",
		"evo_time": 120, "evo_next": "cuihuo2", "combo": "每 60 秒 +1 攻击；120 秒 → 进化", "combo_id": "cuihuo"},
	{"set": "cuihuo2", "name": "淬火·利", "quality": "上品", "size": 1, "solo": true, "cat": "装备", "evo_from": true,
		"evo_time": 300, "evo_next": "cuihuo3", "combo": "每 60 秒 +1 攻击；300 秒 → 进化", "combo_id": "cuihuo2"},
	{"set": "cuihuo3", "name": "淬火·绝", "quality": "极品", "size": 1, "solo": true, "cat": "装备", "evo_from": true,
		"combo": "攻击 +10% · 每 60 秒 +2 攻击（封顶）", "combo_id": "cuihuo3"},
]
# 每一张卡的"单卡属性"（按编号从小到大）
const CARD_PARTS := {
	"liliang": ["气血 +100", "攻击 +12", "生命恢复 +5"],
	"tayun": ["攻速 +6%", "闪避 +4%", "护甲 +6"],
	"jingxin": ["内力 +60", "内力恢复 +2/秒", "元素攻击 +5%"],
	"tiebi": ["减伤 +6%", "护甲 +8"],
	"jifeng": ["攻速 +8%", "暴击 +5%"],
	"jubao": ["文钱 +20%", "灵晶 +10%", "幸运一击 +5%"],
	"shanglu": ["文钱 +25%", "灵晶 +15%"],
	"lianzhan": ["杀敌数 +15%", "挑战刷怪 +1 只"],
	"zhaoguai": ["挑战刷怪 +1 只", "挑战冷却 −10%", "挑战怪掉落 +20%"],
	"tongxin": ["伙伴技能伤害 +10%", "伙伴冷却 −10%", "伙伴内力消耗 −15%"],
	"wuxing": ["全元素伤害 +8%", "元素抗性 +6%", "元素攻击 +10%"],
	"lieyan": ["火系伤害 +12%", "火系抗性 +10%"],
	"hanshui": ["水系伤害 +12%", "水系抗性 +10%"],
	"jinglei": ["金系伤害 +12%", "金系抗性 +10%"],
	"cuifeng": ["攻击 +6%", "暴击 +4%", "暴击伤害 +15%"],
	"liebo": ["暴击 +6%", "暴击伤害 +20%"],
	"feiyu": ["每 3 秒射一支箭（60% 伤害）", "箭 +1（每层）"],
	"leiting": ["暴击时落一道雷（范围 80）", "雷伤 +30%"],
	"panshi": ["护甲 +6", "气血 +120", "全伤害减免 +3%"],
	"lingxi": ["内力 +80", "技能冷却 −8%", "伙伴技能伤害 +8%"],
	"muling": ["木系伤害 +12%", "木系抗性 +10%", "生命恢复 +4"],
	"houtu": ["土系伤害 +12%", "土系抗性 +10%", "护甲 +8"],
	"bingxin": ["内力 +90", "技能冷却 −8%", "元素攻击 +6%"],
	"xuezhan": ["攻击 +7%", "暴击伤害 +18%", "生命恢复 +5"],
	"xunying": ["攻速 +7%", "闪避 +4%", "暴击 +4%"],
	"jingang": ["护甲 +10", "全伤害减免 +3%", "气血 +140"],
	"liesha": ["杀敌数 +20%", "文钱 +25%", "幸运一击 +6%"],
	"wudao": ["属性点 +1", "内力恢复 +2/秒", "元素攻击 +6%"],
	"shouhun": ["伙伴技能伤害 +8%", "伙伴冷却 −8%", "伙伴内力消耗 −12%"],
	"leifa": ["暴击 +8%", "暴击伤害 +25%", "金系伤害 +15%"],
	"tieqi": ["攻击 +8%", "护甲 +6"],
	"pojun": ["暴击 +7%", "暴击伤害 +25%"],
	"lingmao": ["闪避 +5%", "攻速 +6%"],
	"jinzhong": ["全伤害减免 +4%", "护甲 +10"],
	"caishen": ["文钱 +30%", "灵晶 +12%"],
	"zhangu": ["挑战刷怪 +1 只", "挑战冷却 −8%"],
	"shuangxiu": ["伙伴技能伤害 +10%", "招募成长 +1（组合才给）"],
	"liuxing": ["每 4 秒落星（70% 伤害）", "星伤 +30%"],
	"jingji": ["反伤 +30%", "反伤敌人 +1"],
	"tianming": ["幸运一击 +8%", "全属性 +3%"],
	"bingqi": ["攻击 +6%", "暴击 +4%", "暴击伤害 +15%"],
	"dao": ["攻击 +7%", "破甲（无视 8% 防御）"],
	"ruanjia": ["护甲 +8", "气血 +110"],
	"baoqi": ["幸运一击 +4%", "灵晶 +12%", "文钱 +20%"],
	"shenbing": ["攻击 +9%", "暴击伤害 +22%"],
	"huxinjing": ["全伤害减免 +3%", "反伤 +20%"],
	"dazuo": ["每秒 主属性 +0.02"],
	"zhuji": ["突破成功：打坐效率 ×2"],
	"jindan": ["突破成功：打坐 ×3 · 气血 +15%"],
	"yuanying": ["突破成功：打坐 ×5 · 全属性 +25%"],
	"huashen": ["突破成功：打坐 ×8 · 全属性 +50% · 元素 +30%"],
	"sayi0": ["攻击 +6%"],
	"sayi1": ["攻击 +14% · 暴击 +3%"],
	"sayi2": ["攻击 +26% · 暴击 +8%"],
	"sayi3": ["攻击 +40% · 暴击 +15% · 暴伤 +20%"],
	"yinxue": ["攻击 +8"],
	"yinxue2": ["攻击 +12 · 吸血 4%"],
	"yinxue3": ["攻击 +18 · 吸血 8%"],
	"pojunq": ["攻击 +9%"],
	"pojunq2": ["攻击 +14% · 溅射"],
	"chixiao": ["攻击 +7%", "溅射范围 +20"],
	"suozijia": ["护甲 +9", "气血 +120"],
	"jucaizhu": ["文钱 +12%", "灵晶 +8%"],
	"yubanzhi": ["臂力 +1", "身法 +1", "悟性 +1"],
	"cuihuo": ["每 60 秒 攻击 +1"],
	"cuihuo2": ["每 60 秒 攻击 +1"],
	"cuihuo3": ["攻击 +10% · 每 60 秒 +2"],
}
# 长线的"名字递进"（用户参考别人的 力量-野蛮人-战神）：I/II/III 各有名号
const CARD_TIER_NAME := {
	"liliang": ["力量祝福", "力士", "刑天"],
	"tayun": ["踏云步", "追风", "缩地"],
	"jingxin": ["静心诀", "明镜", "菩提"],
}
const CARD_ROMAN := ["I", "II", "III", "IV", "V"]

func card_id(set_id: String, part: int) -> String:
	return set_id + "_" + str(part)

func card_name(id: String) -> String:
	var sp := id.split("_")
	if sp.size() < 2:
		return id
	var set_id := str(sp[0])
	var part := int(sp[1])
	# v10a：单卡（打坐/境界）不带编号——就叫"筑基境"，不写【I】
	for s_v in CARD_SETS:
		var ss: Dictionary = s_v
		if str(ss["set"]) == set_id and bool(ss.get("solo", false)):
			return str(ss["name"])
	# 长线走"名字递进"（力量祝福→力士→刑天），短线仍是 套名【I/II/III】
	if CARD_TIER_NAME.has(set_id):
		var arr: Array = CARD_TIER_NAME[set_id]
		if part < arr.size():
			return str(arr[part])
	for s_v in CARD_SETS:
		var s: Dictionary = s_v
		if str(s["set"]) == set_id:
			return str(s["name"]) + "【" + str(CARD_ROMAN[part]) + "】"
	return id

func card_set_of(id: String) -> Dictionary:
	var set_id := str(id.split("_")[0])
	for s_v in CARD_SETS:
		var s: Dictionary = s_v
		if str(s["set"]) == set_id:
			return s
	return {}

func card_prop(id: String) -> String:
	var sp := id.split("_")
	var set_id := str(sp[0])
	var part := int(sp[1]) if sp.size() > 1 else 0
	var arr: Array = CARD_PARTS.get(set_id, [])
	return str(arr[part]) if part < arr.size() else "—"
# ============================================================
# v8d 抽卡页的**大卡面**（用户参考别人的卡：锦旗卡名 / 插画 / 风味 / 徽章）
#   插画没有美术素材——**用代码画简笔图标**（剑/盾/拳/符/箭/钱 六种，按套名猜）
#   风味小字按"线"给（40 套逐句太占，先按类给一句）
# ============================================================
const FLAVOR := {
	"剑": "手上没家伙，就靠这口气。",
	"盾": "站住了，就是赢。",
	"拳": "一寸短，一寸险。",
	"符": "五行相生，气随意走。",
	"箭": "先到的是箭，后到的是人。",
	"钱": "有钱能使鬼推磨。",
	"宝": "捡着的，都是命。",
}

func _card_icon_of(set_id: String) -> String:
	var nm := ""
	for s_v in CARD_SETS:
		var s: Dictionary = s_v
		if str(s["set"]) == set_id:
			nm = str(s["name"])
	if nm.contains("铁") or nm.contains("磐") or nm.contains("金钟") or nm.contains("金刚"):
		return "盾"
	if nm.contains("钱") or nm.contains("宝") or nm.contains("商") or nm.contains("财"):
		return "钱"
	if nm.contains("羽") or nm.contains("箭"):
		return "箭"
	if nm.contains("五行") or nm.contains("心") or nm.contains("灵") or nm.contains("道"):
		return "符"
	if nm.contains("力") or nm.contains("淬") or nm.contains("血") or nm.contains("战") or nm.contains("骑"):
		return "拳"
	return "剑"

# 画一个 40×40 的简笔图标（中心 c）
func _draw_card_icon(cv: Control, c: Vector2, kind: String) -> void:
	var ink := Color(0.22, 0.20, 0.18, 0.9)
	match kind:
		"拳":
			cv.draw_circle(c, 13.0, ink)
			cv.draw_line(c + Vector2(-16, -14), c + Vector2(16, 14), ink, 4.0)
			cv.draw_line(c + Vector2(-16, 14), c + Vector2(16, -14), ink, 4.0)
		"盾":
			var sh := PackedVector2Array([c + Vector2(0, -17), c + Vector2(15, -9),
				c + Vector2(11, 12), c + Vector2(0, 18), c + Vector2(-11, 12), c + Vector2(-15, -9)])
			cv.draw_colored_polygon(sh, Color(0.62, 0.60, 0.56))
			cv.draw_polyline(PackedVector2Array([sh[0], sh[1], sh[2], sh[3], sh[4], sh[5], sh[0]]), ink, 3.0)
		"箭":
			cv.draw_line(c + Vector2(-16, 0), c + Vector2(10, 0), ink, 4.0)
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(18, 0), c + Vector2(4, -9), c + Vector2(4, 9)]), ink)
			cv.draw_line(c + Vector2(-16, 0), c + Vector2(-8, -8), ink, 3.0)
			cv.draw_line(c + Vector2(-16, 0), c + Vector2(-8, 8), ink, 3.0)
		"符":
			cv.draw_rect(Rect2(c.x - 11, c.y - 17, 22, 34), Color(0.94, 0.90, 0.78))
			cv.draw_rect(Rect2(c.x - 11, c.y - 17, 22, 34), ink, false, 3.0)
			cv.draw_line(c + Vector2(0, -12), c + Vector2(0, 12), Color(0.72, 0.24, 0.20), 3.0)
			cv.draw_line(c + Vector2(-6, -4), c + Vector2(6, -4), Color(0.72, 0.24, 0.20), 3.0)
		"钱":
			cv.draw_circle(c, 15.0, Color(0.88, 0.72, 0.30))
			cv.draw_circle(c, 15.0, Color(0.52, 0.40, 0.14), false, 3.0)
			cv.draw_rect(Rect2(c.x - 5, c.y - 5, 10, 10), Color(0.52, 0.40, 0.14), false, 3.0)
		_:
			cv.draw_line(c + Vector2(-4, 18), c + Vector2(4, 18), ink, 4.0)
			cv.draw_line(c + Vector2(0, 16), c + Vector2(0, -14), Color(0.70, 0.72, 0.76), 5.0)
			cv.draw_line(c + Vector2(-12, -6), c + Vector2(12, -6), ink, 4.0)
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(6, -8), c + Vector2(-6, -8)]), Color(0.82, 0.84, 0.88))

class CardIcon extends Control:
	var host = null
	var kind := "剑"
	func _draw() -> void:
		if host != null:
			host._draw_card_icon(self, size * 0.5, kind)

# 大卡面（抽卡页用）：锦旗卡名 → 图标 → 单卡属性 → 组合 → 进度 → 风味
func _card_big(p: Control, pos: Vector2, sz: Vector2, id: String) -> void:
	var s := card_set_of(id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.86)
	sb.set_corner_radius_all(12)
	sb.border_color = _quality_color(str(s.get("quality", "下品")))
	sb.set_border_width_all(2)
	var box := Panel.new()
	box.position = pos
	box.size = sz
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_child(box)
	# ① 锦旗：一个下缘带尖角的横幅（卡面拉长后旗子也放大）
	var bw := sz.x - 24.0
	var banner := Control.new()
	banner.position = Vector2(12, 10)
	banner.size = Vector2(bw, 56)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(banner)
	var bn := Label.new()
	bn.position = Vector2(0, 6)
	bn.size = Vector2(bw, 46)
	bn.add_theme_font_size_override("font_size", 25)
	bn.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	bn.text = card_name(id)
	bn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_child(bn)
	var band := ColorRect.new()
	band.position = Vector2(0, 0)
	band.size = Vector2(bw, 50)
	band.color = _quality_color(str(s.get("quality", "下品")))
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(band)
	banner.move_child(band, 0)
	# ② 简笔图标
	var ic := CardIcon.new()
	ic.host = self
	ic.kind = _card_icon_of(str(s.get("set", "")))
	ic.position = Vector2(sz.x * 0.5 - 52.0, 84.0)
	ic.size = Vector2(104, 104)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ic)
	# ③ 单卡属性（大字）
	var pr := Label.new()
	pr.position = Vector2(6, 206.0)
	pr.size = Vector2(sz.x - 12, 76)
	pr.add_theme_font_size_override("font_size", 26)
	pr.add_theme_color_override("font_color", SEAL)
	pr.text = card_prop(id)
	pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(pr)
	# ④ 组合 ＋ 进度（大字）
	var got := 0
	for i in int(s.get("size", 1)):
		if _card_have.has(card_id(str(s.get("set", "")), i)):
			got += 1
	var cm := Label.new()
	cm.position = Vector2(8, 292.0)
	cm.size = Vector2(sz.x - 16, 120)
	cm.add_theme_font_size_override("font_size", 19)
	cm.add_theme_color_override("font_color", DIM)
	cm.text = "组合：" + str(s.get("combo", ""))
	cm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(cm)
	# 风味小字（按图标类给一句）
	var fl := Label.new()
	fl.position = Vector2(8, 420.0)
	fl.size = Vector2(sz.x - 16, 90)
	fl.add_theme_font_size_override("font_size", 17)
	fl.add_theme_color_override("font_color", Color(0.48, 0.44, 0.40))
	fl.text = str(FLAVOR.get(_card_icon_of(str(s.get("set", ""))), ""))
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(fl)
	# 进度：大字（卡面拉长后放到底部）
	var pg := Label.new()
	pg.position = Vector2(6, sz.y - 74.0)
	pg.size = Vector2(sz.x - 12, 52)
	pg.add_theme_font_size_override("font_size", 30)
	pg.add_theme_color_override("font_color", SEAL)
	pg.text = str(got) + "/" + str(int(s.get("size", 1)))
	pg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(pg)
# ---- v8a 抽卡本体（用户：20 灵晶三选一 ＋ 重抽 5 灵晶）----
const DRAW_COST := 20
const REROLL_ONE := 5
const REFRESH_ALL := 5
const QUALITY_WEIGHT := {"下品": 30, "中品": 25, "上品": 20, "极品": 15, "绝品": 10}

# 候选池：还没拿到、且这套没成型的卡（每张卡只能"拿一次"；成型后整套出池）
func _card_pool_available() -> Array:
	var out: Array = []
	for s_v in CARD_SETS:
		var s: Dictionary = s_v
		var set_id := str(s["set"])
		if bool(_sets_done.get(set_id, false)):
			continue
		# v10a：境界卡**一个个出现**——筑基只在没进境时出现，金丹要先进筑基…
		if s.has("realm") and int(s["realm"]) != _realm + 1:
			continue
		# v10b：杀意的进阶形态只靠"进化"拿到，不进池
		if bool(s.get("evo_from", false)):
			continue
		var w: int = int(QUALITY_WEIGHT.get(str(s["quality"]), 20))
		for i in int(s["size"]):
			var cid := card_id(set_id, i)
			if _card_have.has(cid):
				continue
			for k in w:
				out.append(cid)
	return out

func _roll_cards() -> Array:
	var pool := _card_pool_available()
	var out: Array = []
	var guard := 0
	while out.size() < 3 and pool.size() > 0 and guard < 400:
		guard += 1
		var pick := str(pool[randi() % pool.size()])
		if not out.has(pick):
			out.append(pick)
	return out

# 抽一张（花 20 灵晶）；十格满了会先弹卡组页让你腾位置
func _draw_card(id: String) -> void:
	if int(_crystal) < DRAW_COST:
		_hint.text = "灵晶不够（要 " + str(DRAW_COST) + "，现有 " + str(int(_crystal)) + "）"
		return
	_crystal -= DRAW_COST
_qc("draw")                       # v13c：任务进度（抽卡）
	_draw_choices.clear()
	Audio.sfx("paper", -6.0)
	# v8b：十格满了 → 进"换卡"模式（抽到的先拿在手上，去卡组页点掉一张）
	if not _card_have.has(id) and not _card_into_deck(id):
		_pending_card = id
		_hint.text = "十格满了——点一张换掉（换掉的那张回池）"
		_open_large("卡组")
		return
	_card_gain(id)
	_hint.text = "抽到「" + card_name(id) + "」： " + card_prop(id)
	if _popup_kind == "抽卡":
		_open_large("抽卡")

func _reroll_one(idx: int) -> void:
	if int(_crystal) < REROLL_ONE:
		_hint.text = "重抽要 " + str(REROLL_ONE) + " 灵晶"
		return
	_crystal -= REROLL_ONE
	var fresh := _roll_cards()
	for cid in fresh:
		if not _draw_choices.has(cid):
			_draw_choices[idx] = cid
			break
	Audio.sfx("ui_click", -8.0)
	_open_large("抽卡")

func _refresh_all() -> void:
	if int(_crystal) < REFRESH_ALL:
		_hint.text = "刷新要 " + str(REFRESH_ALL) + " 灵晶"
		return
	_crystal -= REFRESH_ALL
	_draw_choices = _roll_cards()
	Audio.sfx("ui_click", -8.0)
	_open_large("抽卡")

# v13a：卡组刷新次数（黑市 60 杀敌数一件）——免费把三选一全刷一次
func _refresh_all_free() -> void:
	if _card_refresh <= 0:
		_hint.text = "没有卡组刷新次数了（黑市 60 杀敌数一件）"
		return
	_card_refresh -= 1
	_draw_choices = _roll_cards()
	Audio.sfx("ui_click", -8.0)
	_hint.text = "用掉 1 次卡组刷新（剩 " + str(_card_refresh) + " 次）"
	_open_large("抽卡")

# 三选一页：三张大卡面（大的先做"信息区"，插画下一轮补）
func _fill_draw(p: Control, y: float, sz: Vector2) -> float:
	var head := Label.new()
	head.position = Vector2(24, y)
	head.size = Vector2(660, 44)
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", INK)
	head.text = "抽卡　" + str(DRAW_COST) + " 灵晶　现有 " + str(int(_crystal)) + " 灵晶"
	p.add_child(head)
	var tip := Label.new()
	tip.position = Vector2(24, y + 46.0)
	tip.size = Vector2(660, 36)
	tip.add_theme_font_size_override("font_size", 19)
	tip.add_theme_color_override("font_color", DIM)
	tip.text = "三选一 · 单张重抽 " + str(REROLL_ONE) + " · 全刷新 " + str(REFRESH_ALL) + " · 每张卡一局只能拿一次"
	p.add_child(tip)
	if _draw_choices.is_empty():
		_draw_choices = _roll_cards()
	var cw := 204.0
	var ly := y + 92.0
	for i in _draw_choices.size():
		var cid := str(_draw_choices[i])
		var x := 24.0 + float(i) * (cw + 12.0)      # 三张大卡并排（v8d）
		_card_big(p, Vector2(x, ly), Vector2(cw, 560), cid)
		_pbtn(p, "选它 " + str(DRAW_COST), Vector2(x, ly + 568.0), Vector2(cw, 66), 23, int(_crystal) >= DRAW_COST, _draw_card.bind(cid))
		_pbtn(p, "重抽 " + str(REROLL_ONE), Vector2(x, ly + 640.0), Vector2(cw, 52), 20, int(_crystal) >= REROLL_ONE, _reroll_one.bind(i))
	ly += 706.0
	_pbtn(p, "全部刷新 " + str(REFRESH_ALL) + " 灵晶", Vector2(24, ly), Vector2(250, 68), 22, int(_crystal) >= REFRESH_ALL, _refresh_all)
	# v13a：黑市买的「卡组刷新」在这里免费花（一次用 1 个）
	var fb := _pbtn(p, "用卡组刷新 ×" + str(_card_refresh), Vector2(286, ly), Vector2(280, 68), 22, _card_refresh > 0, _refresh_all_free)
	if _card_refresh <= 0:
		fb.add_theme_stylebox_override("normal", _flat(Color(0.55, 0.53, 0.51, 0.95)))
		fb.add_theme_stylebox_override("hover", _flat(Color(0.60, 0.58, 0.56, 0.95)))
		fb.add_theme_stylebox_override("pressed", _flat(Color(0.48, 0.46, 0.44, 0.95)))
	var done := Label.new()
	done.position = Vector2(24, ly + 78.0)
	done.size = Vector2(620, 40)
	done.add_theme_font_size_override("font_size", 20)
	done.add_theme_color_override("font_color", DIM)
	done.text = "已拿到 " + str(_card_have.size()) + " / " + str(card_pool_size()) + " 张　·　黑市卖「卡组刷新」60 杀敌数一件"
	p.add_child(done)
	return ly + 128.0
# ============================================================
# v11a 成长武器：自带一件 · 无限强化（文钱）· 每 10 级进阶（品质升档 ＋ 三选一）
#   强化等级保留 · 一键强化用大按钮（手机不做键盘热键）· 三选一可刷新（按次数计价）
# ============================================================
const WPN_NAME := "成长·初锋"
const WPN_Q_CN := ["凡品", "下品", "中品", "上品", "极品", "绝品"]
const WPN_Q_MUL := [1.0, 1.5, 2.0, 3.0, 4.0, 6.0]
var _wpn_lv := 0
var _wpn_q := 0
var _wpn_lines: Array = []
var _wpn_choices: Array = []
var _wpn_refresh_n := 0
var _wpn_await := false

func _wpn_q_mul() -> float:
	return float(WPN_Q_MUL[clampi(_wpn_q, 0, 5)])

func _wpn_tier() -> int:
	return int(_wpn_lv / 10)

func _wpn_cost() -> int:
	return int(60.0 * pow(1.22, float(_wpn_lv)) * pow(1.6, float(_wpn_tier())))

func _wpn_refresh_cost() -> int:
	return 100 + 150 * _wpn_refresh_n

func _wpn_flat_atk() -> int:
	return int(float(2 * (1 + _wpn_tier())) * _wpn_q_mul())

func _wpn_flat_hp() -> int:
	return int(float(10 * (1 + _wpn_tier())) * _wpn_q_mul())

# ============================================================
# v11g：仓库能存能取（六格 ↔ 仓库）＋ 满格醒目提醒（用户：装备满值会放入仓库，记得提醒）
func _gear_to_vault(idx: int) -> void:
	if idx >= _equip.size() or str(_equip[idx]) == "":
		return
	var label := str(_equip[idx])
	var stat: Dictionary = _equip_stat[idx] if idx < _equip_stat.size() else {}
	_equip[idx] = ""
	if idx < _equip_stat.size():
		_equip_stat[idx] = {}
	_vault.append(label)
	_vault_stat.append(stat)
	_hint.text = "「" + label + "」收进仓库"
	Audio.sfx("ui_click", -8.0)
	_gear_sync()
	if _popup_kind == "装备":
		_open_large("装备")

func _gear_from_vault(idx: int) -> void:
	if idx >= _vault.size():
		return
	var label := str(_vault[idx])
	var stat: Dictionary = _vault_stat[idx] if idx < _vault_stat.size() else {}
	for i in _equip.size():
		if str(_equip[i]) == "":
			_equip[i] = label
			_equip_stat[i] = stat
			_vault.remove_at(idx)
			if idx < _vault_stat.size():
				_vault_stat.remove_at(idx)
			_hint.text = "「" + label + "」穿上第 " + str(i + 1) + " 格"
			Audio.sfx("equip", -4.0)
			_gear_sync()
			if _popup_kind == "装备":
				_open_large("装备")
			return
	_hint.text = "六格满了，先卖或存一件"

func _gear_full_notice(label: String) -> void:
	_hint.text = "六格已满！「" + label + "」已自动放进仓库（去［仓库］取用或卖掉）"
	if _field != null:
		_field._push_float(_field.hero_pos.x, _field.hero_pos.y - 110.0, "六格已满 → 进仓库", Color(1.0, 0.78, 0.34), true)
	Audio.sfx("bell", -6.0)
# v11f 装备掉落（第 3 轮）：按品级随机生成 · 挑战真的爆 · 可以卖文钱
#   装备/宝物都带品级与颜色（跟卡牌同一套），卖价＝品质 × 强化等级折算
# ============================================================
const GEAR_EQ_NAMES := ["青锋剑", "铁叶甲", "长刀", "锁子甲", "赤霄剑", "玉扳指", "玄铁令", "披风"]
const GEAR_TR_NAMES := ["护心镜", "定神珠", "聚财珠", "引雷幡", "商队旗", "天蚕衣"]

# 按品质权重掷一件装备/宝物（大怪掉得更好）
func _gen_gear(is_treasure: bool, big: bool) -> Dictionary:
	var w: Array = [50, 28, 14, 6, 2, 0] if not big else [18, 26, 26, 18, 9, 3]
	var roll := randi() % 100
	var acc := 0
	var q := 0
	for i in 6:
		acc += int(w[i])
		if roll < acc:
			q = i
			break
	var mul := float(WPN_Q_MUL[q])
	var pool: Array = GEAR_TR_NAMES if is_treasure else GEAR_EQ_NAMES
	var nm := str(pool[randi() % pool.size()])
	var atk := int(ceil(3.0 * mul))
	var hp := int(ceil(14.0 * mul))
	return {"name": nm, "q": q, "atk": atk, "hp": hp,
		"price": int(60.0 * mul * mul)}

# 装备进六格（带加成）
func _equip_add(g: Dictionary) -> void:
	var label := str(g["name"]) + "（" + str(WPN_Q_CN[int(g["q"])]) + "）"
	for i in _equip.size():
		if str(_equip[i]) == "":
			_equip[i] = label
			_equip_stat[i] = g
			_hint.text = "得到 " + label + "（攻 +" + str(g["atk"]) + " 血 +" + str(g["hp"]) + "），已穿上第 " + str(i + 1) + " 格"
			_gear_sync()
			Audio.sfx("equip", -4.0)
			return
	_vault.append(label)
	_vault_stat.append(g)
	_gear_full_notice(label)
	_gear_sync()

# 六格 ＋ 仓库里的装备加成（每次重算，不会叠错）
func _gear_sync() -> void:
	var a := 0
	var h := 0
	for i in _equip.size():
		if i < _equip_stat.size() and _equip_stat[i] is Dictionary:
			a += int((_equip_stat[i] as Dictionary).get("atk", 0))
			h += int((_equip_stat[i] as Dictionary).get("hp", 0))
	# v13a：再加上黑市买的「消耗型装备·小」（可重复买，叠加）
	_extra["gear_atk"] = float(a + _bm_atk)
	_extra["gear_hp"] = float(h + _bm_hp)
	_sync_battle_stats()

# 卖一件（六格或仓库），按品质 × 强化等级折算成文钱
func _gear_sell(is_vault: bool, idx: int) -> void:
	var stat: Dictionary = {}
	var label := ""
	if is_vault:
		if idx >= _vault.size():
			return
		label = str(_vault[idx])
		stat = _vault_stat[idx] if idx < _vault_stat.size() else {}
		_vault.remove_at(idx)
		if idx < _vault_stat.size():
			_vault_stat.remove_at(idx)
	else:
		if idx >= _equip.size() or str(_equip[idx]) == "":
			return
		label = str(_equip[idx])
		stat = _equip_stat[idx] if idx < _equip_stat.size() else {}
		_equip[idx] = ""
		if idx < _equip_stat.size():
			_equip_stat[idx] = {}
	var price := int(stat.get("price", 60))
	_money += price
	_hint.text = "卖了 " + label + "，得 " + str(price) + " 文钱"
	Audio.sfx("coin", -4.0)
	_gear_sync()
	if _popup_kind == "装备":
		_open_large("装备")
# v11e：时间进化（淬火剑这类）——每秒 tick，每 60 秒 +1 攻击，到点原地进化
var _card_time := {}          # id → 已过秒数
var _evo_atk := 0             # 时间进化累积的固定攻击

func _card_time_tick(delta: float) -> void:
	for id in _card_have.keys():
		var s := card_set_of(str(id))
		if not s.has("evo_time"):
			continue
		var before := float(_card_time.get(id, 0.0))
		var now := before + delta
		_card_time[id] = now
		# 每满 60 秒：攻击 +1（淬火·绝 是 +2）
		if int(now / 60.0) > int(before / 60.0):
			_evo_atk += (2 if str(id).begins_with("cuihuo3") else 1)
			_extra["evo_atk"] = float(_evo_atk)
			_sync_battle_stats()
		# 到点：进化（原地换卡）
		if now >= float(s["evo_time"]) and s.has("evo_next"):
			var nid := str(s["evo_next"])
			_card_time.erase(id)
			_card_have.erase(id)
			var at := _deck_cards.find(str(id))
			if at >= 0:
				_deck_cards[at] = nid
			_card_have[nid] = 1
			_hint.text = "【" + card_name(str(id)) + "】随时间进化 → 【" + card_name(nid) + "】"
			Audio.sfx("levelup", -5.0)
			_sync_battle_stats()

# v11e：凑齐成套的装备卡 → **自动穿到六格第一空格**（散卡永不进六格）
func _equip_auto(name_cn: String) -> void:
	for i in _equip.size():
		if str(_equip[i]) == "":
			_equip[i] = name_cn
			_hint.text = "装备成型，自动穿上：" + name_cn + "（第 " + str(i + 1) + " 格）"
			Audio.sfx("equip", -4.0)
			return
	_hint.text = "六格满了，" + name_cn + " 放进仓库"
	_vault.append(name_cn)
# v11b：把成长武器的加成写进 _extra（每次同步重算，不会重复叠加）
func _wpn_line_total(t: String) -> float:
	var sum := 0.0
	for it_v in _wpn_lines:
		var it: Dictionary = it_v
		if str(it["t"]) == t:
			sum += float(it["v"])
	return sum

func _wpn_sync() -> void:
	_extra["atk_flat"] = float(_wpn_flat_atk()) + _wpn_line_total("atk_flat")
	_extra["hp_flat"] = float(_wpn_flat_hp()) + _wpn_line_total("hp_flat")
	_extra["wpn_aspd"] = _wpn_line_total("aspd") / 100.0
	_extra["wpn_crit"] = _wpn_line_total("crit") / 100.0
	_extra["wpn_critdmg"] = _wpn_line_total("critdmg") / 100.0
	_extra["wpn_arm"] = _wpn_line_total("arm")
	_extra["wpn_agi"] = _wpn_line_total("agi")
	_extra["wpn_wit"] = _wpn_line_total("wit")
	_extra["wpn_cut"] = _wpn_line_total("cut") / 100.0
	_extra["wpn_elem"] = _wpn_line_total("elem") / 100.0
# 三条强化线的属性池（每条带品质档，数值按档位放大）
const WPN_POOL := [
	{"n": "攻击 +%d", "t": "atk_flat", "v": 4},
	{"n": "气血 +%d", "t": "hp_flat", "v": 30},
	{"n": "攻速 +%d%%", "t": "aspd", "v": 2},
	{"n": "暴击 +%d%%", "t": "crit", "v": 1},
	{"n": "暴击伤害 +%d%%", "t": "critdmg", "v": 4},
	{"n": "臂力 +%d", "t": "arm", "v": 1},
	{"n": "身法 +%d", "t": "agi", "v": 1},
	{"n": "悟性 +%d", "t": "wit", "v": 1},
	{"n": "减伤 +%d%%", "t": "cut", "v": 2},
	{"n": "元素攻击 +%d%%", "t": "elem", "v": 3},
]

# 掷三选一：品质权重跟着武器品质走（越高越容易出高档）
func _wpn_roll_choices() -> void:
	var w: Array = [[60, 30, 10, 0, 0, 0], [45, 32, 18, 5, 0, 0], [25, 32, 26, 13, 4, 0],
		[12, 24, 30, 22, 9, 3], [5, 15, 28, 28, 17, 7], [2, 8, 20, 30, 25, 15]][clampi(_wpn_q, 0, 5)]
	var out: Array = []
	var guard := 0
	while out.size() < 3 and guard < 200:
		guard += 1
		var base: Dictionary = WPN_POOL[randi() % WPN_POOL.size()]
		var roll := randi() % 100
		var acc := 0
		var q := 0
		for i in 6:
			acc += int(w[i])
			if roll < acc:
				q = i
				break
		var mul := float(WPN_Q_MUL[q])
		var v := int(ceil(float(base["v"]) * mul))
		var item := {"n": str(base["n"]) % v, "t": str(base["t"]), "v": v, "q": q}
		var dup := false
		for o_v in out:
			if str((o_v as Dictionary)["t"]) == str(item["t"]):
				dup = true
		if not dup:
			out.append(item)
	_wpn_choices = out

func _wpn_refresh() -> void:
	var c := _wpn_refresh_cost()
	if int(_money) < c:
		_hint.text = "刷新要 " + str(c) + " 文钱（现有 " + str(int(_money)) + "）"
		return
	_money -= c
	_wpn_refresh_n += 1
	_wpn_roll_choices()
	Audio.sfx("ui_click", -8.0)
	if _popup_kind == "成长武器":
		_open_large("成长武器")
# 贴上一条强化线（永久）
func _wpn_take(i: int) -> void:
	if i < 0 or i >= _wpn_choices.size():
		return
	var it: Dictionary = _wpn_choices[i]
	_wpn_lines.append(it)
	_wpn_choices.clear()
	_wpn_await = false
	_wpn_refresh_n = 0
	_hint.text = "武器贴上：" + str(it["n"])
	Audio.sfx("equip", -4.0)
	_sync_battle_stats()
	if _popup_kind == "成长武器":
		_open_large("成长武器")

# 强化一次：钱够就升；到 10 的倍数进阶＋弹三选一
func _wpn_up() -> bool:
	var c := _wpn_cost()
	if int(_money) < c:
		_hint.text = "强化要 " + str(c) + " 文钱（现有 " + str(int(_money)) + "）"
		return false
	_money -= c
	_wpn_lv += 1
	Audio.sfx("hit_heavy", -10.0, 1.3)
	if _wpn_lv % 10 == 0:
		_wpn_q = mini(5, _wpn_q + 1)
		_wpn_await = true
		_wpn_refresh_n = 0
		_wpn_roll_choices()
		_hint.text = "进阶！武器升为【" + str(WPN_Q_CN[_wpn_q]) + "】，来选一条强化线"
		Audio.sfx("levelup", -3.0)
	_sync_battle_stats()
	if _popup_kind == "成长武器":
		_open_large("成长武器")
	return true

# 一键强化：一直花文钱，碰到进阶（等三选一）或钱不够就停
func _wpn_auto() -> void:
	var n := 0
	var spent := 0
	while n < 200 and not _wpn_await:
		var c := _wpn_cost()
		if int(_money) < c:
			break
		if not _wpn_up():
			break
		n += 1
		spent += c
	if n <= 0:
		_hint.text = "一键强化：文钱不够（下次要 " + str(_wpn_cost()) + "）"
	else:
		_hint.text = "一键强化 " + str(n) + " 次：花了 " + str(spent) + " 文钱，现在 +" + str(_wpn_lv) + "（" + str(WPN_Q_CN[_wpn_q]) + "）"
	Audio.sfx("coin", -6.0)
	if _popup_kind == "成长武器":
		_open_large("成长武器")
# ---- v12k 图鉴：宝物全部 ＋ 羁绊 16 件（用户："可以查看有什么宝物"）----
func _fill_codex(p: Control, y: float, sz: Vector2) -> float:
	var head := Label.new()
	head.position = Vector2(24, y)
	head.size = Vector2(640, 40)
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", INK)
	var own := _trea_own.size()
	var locked := 0
	for b_v in BONDS:
		if bool(_bonds_locked.get(str((b_v as Dictionary)["id"]), false)):
			locked += 1
	head.text = "图鉴　宝物 " + str(own) + "/" + str(TREA_POOL.size()) + "　羁绊 " + str(locked) + "/" + str(BONDS.size())
	p.add_child(head)
	var ly := y + 46.0
	var t1 := Label.new()
	t1.position = Vector2(24, ly)
	t1.size = Vector2(640, 32)
	t1.add_theme_font_size_override("font_size", 21)
	t1.add_theme_color_override("font_color", SEAL)
	t1.text = "宝物（灰的还没拿到）"
	p.add_child(t1)
	ly += 36.0
	for i in TREA_POOL.size():
		var it: Dictionary = TREA_POOL[i]
		var nm := str(it["n"])
		var got := _trea_own.has(nm)
		var col := i % 2
		var row := i / 2
		var bx := 24.0 + float(col) * 326.0
		var by := ly + float(row) * 46.0
		var qc := _quality_color(str(it["q"]))
		var rowbox := Panel.new()
		rowbox.position = Vector2(bx, by)
		rowbox.size = Vector2(318, 42)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.97, 0.95, 0.88) if got else Color(0.90, 0.89, 0.86)
		sb.set_corner_radius_all(8)
		sb.border_color = qc if got else Color(0.6, 0.6, 0.6, 0.5)
		sb.set_border_width_all(2)
		rowbox.add_theme_stylebox_override("panel", sb)
		rowbox.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(rowbox)
		var l1 := Label.new()
		l1.position = Vector2(10, 2)
		l1.size = Vector2(180, 22)
		l1.add_theme_font_size_override("font_size", 19)
		l1.add_theme_color_override("font_color", qc if got else Color(0.55, 0.55, 0.55))
		l1.text = nm + ("　×" + str(int((_trea_own[nm] as Dictionary).get("n", 1))) if got else "　未获得")
		rowbox.add_child(l1)
		var l2 := Label.new()
		l2.position = Vector2(10, 22)
		l2.size = Vector2(296, 20)
		l2.add_theme_font_size_override("font_size", 15)
		l2.add_theme_color_override("font_color", DIM)
		l2.text = str(it["fx"])
		l2.clip_text = true
		rowbox.add_child(l2)
	ly += float(int(ceil(float(TREA_POOL.size()) / 2.0))) * 46.0 + 12.0
	var t2 := Label.new()
	t2.position = Vector2(24, ly)
	t2.size = Vector2(640, 32)
	t2.add_theme_font_size_override("font_size", 21)
	t2.add_theme_color_override("font_color", SEAL)
	t2.text = "羁绊宝物（点一行看条件）"
	p.add_child(t2)
	ly += 36.0
	for i in BONDS.size():
		var b: Dictionary = BONDS[i]
		var col2 := i % 2
		var row2 := i / 2
		var bx3 := 24.0 + float(col2) * 326.0
		var by4 := ly + float(row2) * 54.0
		var pr := _bond_progress(b)
		var done := bool(_bonds_locked.get(str(b["id"]), false))
		var qc2 := _quality_color(str(b["q"]))
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(0.93, 0.96, 0.90) if done else Color(0.97, 0.95, 0.88)
		sb2.set_corner_radius_all(8)
		sb2.border_color = Color(0.42, 0.62, 0.40) if done else qc2
		sb2.set_border_width_all(3 if done else 2)
		var rb := Panel.new()
		rb.position = Vector2(bx3, by4)
		rb.size = Vector2(318, 48)
		rb.add_theme_stylebox_override("panel", sb2)
		rb.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(rb)
		var nl := Label.new()
		nl.position = Vector2(10, 2)
		nl.size = Vector2(190, 24)
		nl.add_theme_font_size_override("font_size", 19)
		nl.add_theme_color_override("font_color", Color(0.30, 0.55, 0.32) if done else qc2)
		nl.text = str(b["n"])
		rb.add_child(nl)
		var pl := Label.new()
		pl.position = Vector2(200, 4)
		pl.size = Vector2(110, 22)
		pl.add_theme_font_size_override("font_size", 20)
		pl.add_theme_color_override("font_color", SEAL)
		pl.text = "已成" if done else str(int(pr[0])) + "/" + str(int(pr[1]))
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rb.add_child(pl)
		var fl := Label.new()
		fl.position = Vector2(10, 24)
		fl.size = Vector2(300, 22)
		fl.add_theme_font_size_override("font_size", 15)
		fl.add_theme_color_override("font_color", DIM)
		fl.text = str(b["fx"])
		fl.clip_text = true
		rb.add_child(fl)
		var bh := _pbtn(rb, "", Vector2(0, 0), Vector2(318, 48), 14, false, _bond_detail.bind(i))
		bh.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.001)))
	var brow := int(ceil(float(BONDS.size()) / 2.0))
	return ly + float(brow) * 54.0 + 10.0
# ---- v12e 宝物页（照卡组那套）：紧凑格子 · 品质描边 · ×叠加数 · 点击详情 · 可滑动 ----
func _fill_trea_list(p: Control, y: float, sz: Vector2) -> float:
	var head := Label.new()
	head.position = Vector2(28, y)
	head.size = Vector2(640, 40)
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", INK)
	head.text = "宝物 " + str(_trea_own.size()) + " 种　道具 " + str(_items.size()) + " 种　刷新次数 " + str(_trea_refresh)
	p.add_child(head)
	var tip := Label.new()
	tip.position = Vector2(28, y + 42.0)
	tip.size = Vector2(640, 32)
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", DIM)
	tip.text = "点格子看详情（宝物不限格 · 同名叠加）"
	p.add_child(tip)
	var keys := _trea_own.keys()
	if keys.is_empty():
		var empty := Label.new()
		empty.position = Vector2(28, y + 90.0)
		empty.size = Vector2(640, 40)
		empty.add_theme_font_size_override("font_size", 21)
		empty.add_theme_color_override("font_color", DIM)
		empty.text = "还没有宝物——去［宝物三选一］拿，或打宝物挑战/boss"
		p.add_child(empty)
		return y + 150.0
	var ly := y + 84.0
	for i in keys.size():
		var nm := str(keys[i])
		var info: Dictionary = _trea_own[nm]
		var col := i % 5
		var row := i / 5
		var bx := 24.0 + float(col) * 134.0
		var by := ly + float(row) * 108.0
		var qc := _quality_color(str(info.get("q", "凡品")))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.97, 0.92)
		sb.set_corner_radius_all(10)
		sb.border_color = qc
		sb.set_border_width_all(3)
		var box := Panel.new()
		box.position = Vector2(bx, by)
		box.size = Vector2(126, 98)
		box.add_theme_stylebox_override("panel", sb)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(box)
		var l1 := Label.new()
		l1.position = Vector2(4, 10)
		l1.size = Vector2(118, 44)
		l1.add_theme_font_size_override("font_size", 21)
		l1.add_theme_color_override("font_color", INK)
		l1.text = nm
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l1)
		var l2 := Label.new()
		l2.position = Vector2(4, 56)
		l2.size = Vector2(118, 28)
		l2.add_theme_font_size_override("font_size", 24)
		l2.add_theme_color_override("font_color", SEAL)
		l2.text = "×" + str(int(info.get("n", 1)))
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l2)
		var hit := _pbtn(box, "", Vector2(0, 0), Vector2(126, 94), 16, false, _trea_detail.bind(nm))
		hit.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.001)))
		hit.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.10)))
	var rows := int(ceil(float(keys.size()) / 5.0))
	ly += float(rows) * 108.0 + 8.0
	# v12k（用户："宝物不用全部显示 选后才会显示 … 可以加一个图鉴"）：
	#   宝物页只列**已到手**的；想看"全部有什么"就去［图鉴］
	_pbtn(p, "图鉴（宝物 ＋ 羁绊）", Vector2(24, ly), Vector2(400, 72), 24, false,
		func(): _open_large("图鉴"))
	ly += 84.0
	return ly
	# ↓ 下面这段（羁绊列表）已挪进图鉴；留着当参照，不再执行
	# v12h（用户："不要留太多空白"）：空出来的地方放**羁绊宝物进度**（16 件，2 列紧凑排）
	var bt := Label.new()
	bt.position = Vector2(24, ly)
	bt.size = Vector2(640, 36)
	bt.add_theme_font_size_override("font_size", 23)
	bt.add_theme_color_override("font_color", INK)
	var locked := 0
	for b_v in BONDS:
		if bool(_bonds_locked.get(str((b_v as Dictionary)["id"]), false)):
			locked += 1
	bt.text = "羁绊宝物 " + str(locked) + "/" + str(BONDS.size()) + " 已激活"
	p.add_child(bt)
	ly += 40.0
	for i in BONDS.size():
		var b: Dictionary = BONDS[i]
		var col2 := i % 2
		var row2 := i / 2
		var bx3 := 24.0 + float(col2) * 326.0
		var by4 := ly + float(row2) * 54.0
		var pr := _bond_progress(b)
		var done := bool(_bonds_locked.get(str(b["id"]), false))
		var qc := _quality_color(str(b["q"]))
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(0.97, 0.95, 0.88) if not done else Color(0.93, 0.96, 0.90)
		sb2.set_corner_radius_all(8)
		sb2.border_color = Color(0.42, 0.62, 0.40) if done else qc
		sb2.set_border_width_all(2 if not done else 3)
		var rowbox := Panel.new()
		rowbox.position = Vector2(bx3, by4)
		rowbox.size = Vector2(318, 48)
		rowbox.add_theme_stylebox_override("panel", sb2)
		rowbox.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(rowbox)
		var nl := Label.new()
		nl.position = Vector2(10, 2)
		nl.size = Vector2(190, 24)
		nl.add_theme_font_size_override("font_size", 19)
		nl.add_theme_color_override("font_color", Color(0.30, 0.55, 0.32) if done else qc)
		nl.text = str(b["n"])
		rowbox.add_child(nl)
		var pl := Label.new()
		pl.position = Vector2(200, 4)
		pl.size = Vector2(110, 22)
		pl.add_theme_font_size_override("font_size", 20)
		pl.add_theme_color_override("font_color", SEAL)
		pl.text = ("已成" if done else str(int(pr[0])) + "/" + str(int(pr[1])))
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rowbox.add_child(pl)
		var fl := Label.new()
		fl.position = Vector2(10, 24)
		fl.size = Vector2(300, 22)
		fl.add_theme_font_size_override("font_size", 15)
		fl.add_theme_color_override("font_color", DIM)
		fl.text = str(b["fx"])
		fl.clip_text = true
		rowbox.add_child(fl)
		var bhit := _pbtn(rowbox, "", Vector2(0, 0), Vector2(318, 48), 14, false, _bond_detail.bind(i))
		bhit.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.001)))
	var brow := int(ceil(float(BONDS.size()) / 2.0))
	return ly + float(brow) * 54.0 + 10.0

func _bond_detail(i: int) -> void:
	_detail_bond = i
	_open_small("羁绊详情")

func _gear_detail(i: int) -> void:
	_detail_gear = i
	_open_small("装备详情")

func _trea_detail(nm: String) -> void:
	_detail_trea = nm
	_open_small("宝物详情")
# ---- v12c 宝物三选一页（三张候选带品质色 ＋ 刷新按钮）----
func _fill_trea_pick(p: Control, y: float, sz: Vector2) -> float:
	var head := Label.new()
	head.position = Vector2(28, y)
	head.size = Vector2(640, 46)
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", INK)
	head.text = "宝物三选一　刷新次数：" + str(_trea_refresh)
	p.add_child(head)
	var tip := Label.new()
	tip.position = Vector2(28, y + 48.0)
	tip.size = Vector2(640, 34)
	tip.add_theme_font_size_override("font_size", 19)
	tip.add_theme_color_override("font_color", DIM)
	tip.text = "刷新只花「宝物刷新次数」（每 5 波 +1 · boss 首杀 +2 · 宝物挑战 +1）"
	p.add_child(tip)
	if _trea_choices.is_empty():
		_trea_roll()
	var ly := y + 92.0
	for i in _trea_choices.size():
		var it: Dictionary = _trea_choices[i]
		var qc := _quality_color(str(it["q"]))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.97, 0.92)
		sb.set_corner_radius_all(12)
		sb.border_color = qc
		sb.set_border_width_all(3)
		var box := Panel.new()
		box.position = Vector2(28, ly)
		box.size = Vector2(640, 96)
		box.add_theme_stylebox_override("panel", sb)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(box)
		var t1 := Label.new()
		t1.position = Vector2(18, 10)
		t1.size = Vector2(420, 44)
		t1.add_theme_font_size_override("font_size", 26)
		t1.add_theme_color_override("font_color", qc)
		t1.text = str(it["n"]) + "　【" + str(it["q"]) + "】"
		box.add_child(t1)
		var t2 := Label.new()
		t2.position = Vector2(18, 54)
		t2.size = Vector2(470, 34)
		t2.add_theme_font_size_override("font_size", 20)
		t2.add_theme_color_override("font_color", INK)
		t2.text = str(it["fx"]) + ("　（消耗型）" if str(it["t"]) == "item" else "")
		box.add_child(t2)
		var btn_txt := "拿它"
		if str(it["t"]) == "item":
			btn_txt = "收下 ×" + str(int(_items.get(str(it["n"]), 0)) + 1)
		_pbtn(box, btn_txt, Vector2(506, 22), Vector2(118, 52), 22, true, _trea_take.bind(i))
		ly += 104.0
	_pbtn(p, "刷新（剩 " + str(_trea_refresh) + " 次）", Vector2(28, ly), Vector2(360, 76), 24, _trea_refresh > 0, _trea_refresh_now)
	ly += 96.0
	var items := Label.new()
	items.position = Vector2(28, ly)
	items.size = Vector2(640, 44)
	items.add_theme_font_size_override("font_size", 20)
	items.add_theme_color_override("font_color", DIM)
	items.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# v12d：道具栏每件一颗［用］按钮
	var ix := 28.0
	for k in _items.keys():
		var cnt := int(_items[k])
		if cnt <= 0:
			continue
		_pbtn(p, str(k) + " ×" + str(cnt) + " 用", Vector2(ix, ly + 48.0), Vector2(200, 54), 20, true, _item_use.bind(str(k)))
		ix += 208.0
		if ix > 500.0:
			break
	var itxt := "道具栏："
	if _items.is_empty():
		itxt += "（空——消耗型宝物会收在这里）"
	else:
		var parts := []
		for k in _items.keys():
			parts.append(str(k) + " ×" + str(int(_items[k])))
		itxt += "、".join(PackedStringArray(parts))
	items.text = itxt
	p.add_child(items)
	return ly + 60.0
# ---- v11c 成长武器页：大字 · 大按钮（手机）· 三选一带品质色 ----
func _fill_weapon(p: Control, y: float, sz: Vector2) -> float:
	var nm := Label.new()
	nm.position = Vector2(28, y)
	nm.size = Vector2(420, 52)
	nm.add_theme_font_size_override("font_size", 30)
	nm.add_theme_color_override("font_color", _quality_color(str(WPN_Q_CN[_wpn_q])))
	nm.text = str(WPN_NAME) + "　【" + str(WPN_Q_CN[_wpn_q]) + "】"
	p.add_child(nm)
	var lv := Label.new()
	lv.position = Vector2(460, y)
	lv.size = Vector2(200, 52)
	lv.add_theme_font_size_override("font_size", 34)
	lv.add_theme_color_override("font_color", SEAL)
	lv.text = "+" + str(_wpn_lv)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(lv)
	var ly := y + 60.0
	# 当前属性（固定加成 ＋ 已选强化线）
	var stat := Label.new()
	stat.position = Vector2(28, ly)
	stat.size = Vector2(640, 96)
	stat.add_theme_font_size_override("font_size", 22)
	stat.add_theme_color_override("font_color", INK)
	stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var txt := "每级：攻击 +" + str(_wpn_flat_atk()) + "　气血 +" + str(_wpn_flat_hp())
	txt += "\n已选强化线 " + str(_wpn_lines.size()) + " 条："
	if _wpn_lines.is_empty():
		txt += "（还没有——每 10 级进阶时选一条）"
	else:
		var parts := []
		for it_v in _wpn_lines:
			var it: Dictionary = it_v
			parts.append(str(it["n"]) + "（" + str(WPN_Q_CN[int(it["q"])]) + "）")
		txt += "、".join(PackedStringArray(parts))
	stat.text = txt
	p.add_child(stat)
	ly += 104.0
	if _wpn_await and _wpn_choices.size() > 0:
		var ht := Label.new()
		ht.position = Vector2(28, ly)
		ht.size = Vector2(640, 40)
		ht.add_theme_font_size_override("font_size", 24)
		ht.add_theme_color_override("font_color", GOLD)
		ht.text = "进阶！三选一（可刷新）"
		p.add_child(ht)
		ly += 46.0
		for i in _wpn_choices.size():
			var it: Dictionary = _wpn_choices[i]
			var q := int(it["q"])
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.99, 0.97, 0.92)
			sb.set_corner_radius_all(12)
			sb.border_color = _quality_color(str(WPN_Q_CN[q]))
			sb.set_border_width_all(3)
			var box := Panel.new()
			box.position = Vector2(28, ly)
			box.size = Vector2(640, 84)
			box.add_theme_stylebox_override("panel", sb)
			box.mouse_filter = Control.MOUSE_FILTER_STOP
			p.add_child(box)
			var t1 := Label.new()
			t1.position = Vector2(18, 10)
			t1.size = Vector2(360, 60)
			t1.add_theme_font_size_override("font_size", 26)
			t1.add_theme_color_override("font_color", _quality_color(str(WPN_Q_CN[q])))
			t1.text = str(it["n"]) + "　【" + str(WPN_Q_CN[q]) + "】"
			box.add_child(t1)
			_pbtn(box, "选它", Vector2(500, 16), Vector2(124, 52), 24, true, _wpn_take.bind(i))
			ly += 92.0
		_pbtn(p, "刷新 " + str(_wpn_refresh_cost()) + " 文钱", Vector2(28, ly), Vector2(320, 68), 24, int(_money) >= _wpn_refresh_cost(), _wpn_refresh)
		ly += 80.0
	_pbtn(p, "强化（" + str(_wpn_cost()) + " 文钱）", Vector2(28, ly), Vector2(312, 88), 28, int(_money) >= _wpn_cost(), _wpn_up)
	_pbtn(p, "一键强化", Vector2(356, ly), Vector2(312, 88), 28, true, _wpn_auto)
	ly += 100.0
	var tip := Label.new()
	tip.position = Vector2(28, ly)
	tip.size = Vector2(640, 70)
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "文钱强化 · 等级无上限 · 每 10 级进阶一次（品质升一档 ＋ 三选一）；进阶不重置等级。"
	p.add_child(tip)
	return ly + 84.0
# ============================================================
# ============================================================
# ============================================================
# ============================================================
# v12d 消耗型宝物的实际效果（道具栏里点着用）
#   疾风符 15s 攻速 +200% · 金刚符 10s 全减 +50% · 狂血丹 15s 攻击 +150%（受伤 +30%）
#   定身符 全场定身 5s · 天雷符 立刻全场 300% 攻击的雷伤
# ============================================================
var _tmp_aspd := 0.0      # 剩余秒数
var _tmp_cut := 0.0
var _tmp_atk := 0.0

func _item_use(nm: String) -> void:
	if int(_items.get(nm, 0)) <= 0:
		return
	_items[nm] = int(_items[nm]) - 1
	if int(_items[nm]) <= 0:
		_items.erase(nm)
	match nm:
		"疾风符":
			_tmp_aspd = 15.0
		"金刚符":
			_tmp_cut = 10.0
		"狂血丹":
			_tmp_atk = 15.0
		"定身符":
			if _field != null:
				for f_v in _field.foes:
					(f_v as Dictionary)["para"] = 5.0
				_field._push_float(_field.hero_pos.x, _field.hero_pos.y - 120.0, "定身符：全场定身", Color(0.80, 0.86, 1.0), true)
		"天雷符":
			if _field != null:
				for f_v in _field.foes.duplicate():
					_field._apply_dmg(f_v as Dictionary, float(_field.hero["atk"]) * 3.0, "金系")
				_field._push_float(_field.hero_pos.x, _field.hero_pos.y - 120.0, "天雷符：全场落雷", Color(0.72, 0.88, 1.0), true)
		_:
			pass
	_hint.text = "用了「" + nm + "」（剩 " + str(int(_items.get(nm, 0))) + " 个）"
	Audio.sfx("slash_light", -5.0)
	_sync_battle_stats()
	if _popup_kind == "宝物三选一":
		_open_large("宝物三选一")

func _item_tick(delta: float) -> void:
	var dirty := false
	if _tmp_aspd > 0.0:
		_tmp_aspd = maxf(0.0, _tmp_aspd - delta)
		dirty = true
	if _tmp_cut > 0.0:
		_tmp_cut = maxf(0.0, _tmp_cut - delta)
		dirty = true
	if _tmp_atk > 0.0:
		_tmp_atk = maxf(0.0, _tmp_atk - delta)
		dirty = true
	if dirty:
		_sync_battle_stats()
# v12c 宝物三选一（用户：宝物可以刷新 需要宝物刷新次数 依旧三选一）
#   三张候选带品质色；刷新**消耗宝物刷新次数**（不是文钱/灵晶）
#   次数来源：每过 5 波 +1 · boss 首杀 +2 · 宝物挑战 +1
# ============================================================
var _trea_refresh := 0            # 宝物刷新次数
var _trea_choices: Array = []     # 当前三选一
var _trea_taken := {}             # 已拿过的（被动宝物可重复拿，这里只记次数）

# 宝物池（被动 / 羁绊 / 消耗 三类先放一起，闲散宝物走"即拾即用"不进池）
const TREA_POOL := [
	{"n": "虎符", "q": "中品", "t": "passive", "fx": "攻击 +6%", "key": "atk_all", "v": 0.06},
	{"n": "破军印", "q": "中品", "t": "passive", "fx": "暴击 +3%", "key": "crit_add", "v": 0.03},
	{"n": "血玉", "q": "上品", "t": "passive", "fx": "暴击伤害 +25%", "key": "crit_dmg_bonus", "v": 0.25},
	{"n": "疾风铃", "q": "中品", "t": "passive", "fx": "攻速 +5%", "key": "aspd_bonus", "v": 0.05},
	{"n": "玄龟甲", "q": "中品", "t": "passive", "fx": "全伤害减免 +3%", "key": "cut_all_bonus", "v": 0.03},
	{"n": "金钟罩", "q": "下品", "t": "passive", "fx": "护甲 +6", "key": "armor_add", "v": 6.0},
	{"n": "聚宝盆", "q": "上品", "t": "passive", "fx": "文钱 +25%", "key": "money_bonus", "v": 0.25},
	{"n": "灵石", "q": "上品", "t": "passive", "fx": "灵晶 +15%", "key": "crystal_bonus", "v": 0.15},
	{"n": "龙纹佩", "q": "极品", "t": "passive", "fx": "三属性各 +1", "key": "attr_all", "v": 1.0},
	{"n": "天命石", "q": "极品", "t": "passive", "fx": "幸运一击 +5%", "key": "lucky", "v": 0.05},
	{"n": "疾风符", "q": "中品", "t": "item", "fx": "15 秒内攻速 +200%", "key": "item_haste", "v": 15.0},
	{"n": "金刚符", "q": "上品", "t": "item", "fx": "10 秒内全减 +50%", "key": "item_shield", "v": 10.0},
	{"n": "狂血丹", "q": "极品", "t": "item", "fx": "15 秒内攻击 +150%（受伤 +30%）", "key": "item_rage", "v": 15.0},
	{"n": "定身符", "q": "极品", "t": "item", "fx": "全场敌人定身 5 秒", "key": "item_root", "v": 5.0},
	{"n": "天雷符", "q": "绝品", "t": "item", "fx": "立刻对全场造成 300% 攻击的雷伤", "key": "item_thunder", "v": 3.0},
	# v12i（用户：闲散宝物）——**即拾即用**：拿到当场结算，不占格、不入库
	{"n": "灵晶袋", "q": "中品", "t": "instant", "fx": "灵晶 +100", "key": "crystal", "v": 100},
	{"n": "钱袋", "q": "下品", "t": "instant", "fx": "文钱 +800", "key": "money", "v": 800},
	{"n": "悟道果", "q": "上品", "t": "instant", "fx": "经验 +40%", "key": "exp", "v": 0.40},
	{"n": "属性丹", "q": "上品", "t": "instant", "fx": "属性点 +3", "key": "attr_pt", "v": 3},
	{"n": "洗髓丹", "q": "极品", "t": "instant", "fx": "三属性各 +2（永久）", "key": "attr_all", "v": 2},
	{"n": "淬火石", "q": "极品", "t": "instant", "fx": "成长武器立刻 +3 级（不花钱）", "key": "wpn_lv", "v": 3},
]

func _trea_roll() -> void:
	var out: Array = []
	var guard := 0
	while out.size() < 3 and guard < 200:
		guard += 1
		var pick: Dictionary = TREA_POOL[randi() % TREA_POOL.size()]
		var dup := false
		for o_v in out:
			if str((o_v as Dictionary)["n"]) == str(pick["n"]):
				dup = true
		if not dup:
			out.append(pick)
	_trea_choices = out

# 刷新：只花"宝物刷新次数"
func _trea_refresh_now() -> void:
	if _trea_refresh <= 0:
		_hint.text = "没有宝物刷新次数了（每 5 波 +1 · boss 首杀 +2 · 宝物挑战 +1）"
		return
	_trea_refresh -= 1
	_trea_roll()
	Audio.sfx("ui_click", -8.0)
	if _popup_kind == "宝物三选一":
		_open_large("宝物三选一")

# 拿一件
func _trea_take(i: int) -> void:
	if i < 0 or i >= _trea_choices.size():
		return
	var it: Dictionary = _trea_choices[i]
	var nm := str(it["n"])
	var key := str(it["key"])
	var v := float(it["v"])
	var t := str(it["t"])
_qc("trea")                       # v13c：任务进度（拿到宝物）
	if t == "instant":
		# v12i：闲散宝物——当场结算，不占格不入库
		match key:
			"crystal":
				_crystal += int(v)
			"money":
				_money += int(v)
				_money_earned += int(v)
			"exp":
				_gain_exp(v)
			"attr_pt":
				_attr_pts += int(v)
			"attr_all":
				_attr["arm"] = int(_attr["arm"]) + int(v)
				_attr["agi"] = int(_attr["agi"]) + int(v)
				_attr["wit"] = int(_attr["wit"]) + int(v)
			"wpn_lv":
				_wpn_lv += int(v)
				_sync_battle_stats()
			_:
				pass
		_hint.text = "闲散宝物：" + nm + "　" + str(it["fx"])
		Audio.sfx("coin", -4.0)
		_trea_choices.clear()
		if _popup_kind == "宝物三选一":
			_open_large("宝物三选一")
		return
	if t == "item":
		_items[nm] = int(_items.get(nm, 0)) + 1        # 消耗型进道具栏
		_hint.text = "拿到道具：" + nm + " ×" + str(int(_items[nm])) + "（" + str(it["fx"]) + "）"
	else:
		if key == "attr_all":
			_extra["wpn_arm"] = float(_extra.get("wpn_arm", 0.0)) + v
			_extra["wpn_agi"] = float(_extra.get("wpn_agi", 0.0)) + v
			_extra["wpn_wit"] = float(_extra.get("wpn_wit", 0.0)) + v
		else:
			_extra[key] = float(_extra.get(key, 0.0)) + v
		var own: Dictionary = _trea_own.get(nm, {"q": str(it["q"]), "fx": str(it["fx"]), "n": 0})
		own["n"] = int(own["n"]) + 1
		_trea_own[nm] = own
		_trea_taken[nm] = int(_trea_taken.get(nm, 0)) + 1
		_hint.text = "宝物到手：" + nm + "　" + str(it["fx"])
	Audio.sfx("equip", -4.0)
	_trea_choices.clear()
	_sync_battle_stats()
	if _popup_kind == "宝物三选一":
		_open_large("宝物三选一")
# v12b 羁绊宝物（16 件）：条件是"看你这一局的进度"，满足即**常驻锁定**（不会掉）
#   cond 类型：sets 成套 / partners 入队数 / equip 六格 / wpn 武器等级 / realm 境界
#              / kill 杀敌 / money 累计文钱 / time 存活秒数
# ============================================================
const BONDS := [
	{"id": "zhufu", "n": "祝福之宝", "q": "上品", "cond": "sets", "arg": ["liliang", "tayun", "jingxin"],
		"fx": "三条祝福的杀敌成长 ×1.3", "key": "bond_grow", "v": 0.30},
	{"id": "wuxing", "n": "五行盘", "q": "上品", "cond": "sets", "arg": ["wuxing", "lieyan", "hanshui", "jinglei"],
		"fx": "全元素伤害 +25%", "key": "dmg_elem_all", "v": 0.25},
	{"id": "jubao", "n": "聚宝匣", "q": "上品", "cond": "sets", "arg": ["shanglu", "caishen", "jubao"],
		"fx": "每波灵晶 +3 · 文钱 +25%", "key": "wave_crystal", "v": 3.0},
	{"id": "zhengfa", "n": "征伐令", "q": "极品", "cond": "sets", "arg": ["zhaoguai", "zhangu", "lianzhan"],
		"fx": "挑战多刷 3 只 · 冷却 −20%", "key": "chal_spawn", "v": 3.0},
	{"id": "tongxin", "n": "同心结", "q": "极品", "cond": "sets", "arg": ["tongxin", "shuangxiu", "shouhun"],
		"fx": "伙伴技能伤害 +30%", "key": "partner_dmg", "v": 0.30},
	{"id": "bingzhu", "n": "兵主印", "q": "极品", "cond": "sets", "arg": ["bingqi", "shenbing", "huxinjing"],
		"fx": "装备攻击 +20% · 反伤 +20%", "key": "thorns", "v": 0.20},
	{"id": "tongxing", "n": "同行令", "q": "上品", "cond": "partners", "arg": 5,
		"fx": "伙伴技能伤害 +25%", "key": "partner_dmg", "v": 0.25},
	{"id": "mantang", "n": "满堂红", "q": "绝品", "cond": "partners", "arg": 10,
		"fx": "全属性 +12%", "key": "atk_all", "v": 0.12},
	{"id": "liuhe", "n": "六合匣", "q": "上品", "cond": "equip", "arg": 6,
		"fx": "全伤害减免 +8%", "key": "cut_all_bonus", "v": 0.08},
	{"id": "bailian", "n": "百炼锤", "q": "极品", "cond": "wpn", "arg": 30,
		"fx": "攻击 +15%", "key": "atk_all", "v": 0.15},
	{"id": "qianchui", "n": "千锤印", "q": "绝品", "cond": "wpn", "arg": 60,
		"fx": "攻击 +20% · 暴伤 +30%", "key": "crit_dmg_bonus", "v": 0.30},
	{"id": "wendao", "n": "问道石", "q": "上品", "cond": "realm", "arg": 1,
		"fx": "打坐效率 +50%", "key": "meditate", "v": 0.50},
	{"id": "jindan", "n": "金丹录", "q": "极品", "cond": "realm", "arg": 2,
		"fx": "内力上限 +20% · 打坐再 +50%", "key": "mp_all", "v": 0.20},
	{"id": "shafa", "n": "杀伐印", "q": "绝品", "cond": "kill", "arg": 500,
		"fx": "攻击 +15% · 暴伤 +25%", "key": "crit_dmg_bonus", "v": 0.25},
	{"id": "wanguan", "n": "万贯囊", "q": "上品", "cond": "money", "arg": 20000,
		"fx": "文钱 +30%", "key": "lucky", "v": 0.03},
	{"id": "changye", "n": "长夜灯", "q": "极品", "cond": "time", "arg": 900,
		"fx": "攻速 +15% · 每秒回血 +1% 上限", "key": "aspd_bonus", "v": 0.15},
]
var _items := {}                  # v12c：道具栏（消耗型宝物，可堆叠）
var _trea_own := {}               # v12e：已到手的宝物（名字 → {q: 品质, fx: 效果, n: 件数}）
var _detail_trea := ""            # v12e：正在看详情的宝物
var _detail_gear := 0             # v12g：正在看详情的装备格（点格子进详情）
var _detail_bond := 0             # v12h：正在看详情的羁绊宝物
var _bond_t := 0.0
var _bonds_locked := {}          # 已锁定的羁绊
var _run_time := 0.0             # 本局存活秒数
var _money_earned := 0           # 本局累计赚到的文钱

# 进度：当前/需要（界面显示 2/3 用）
func _bond_progress(b: Dictionary) -> Array:
	var c := str(b["cond"])
	match c:
		"sets":
			var arr: Array = b["arg"]
			var got := 0
			for s in arr:
				if bool(_sets_done.get(str(s), false)):
					got += 1
			return [got, arr.size()]
		"partners":
			var n := 0
			for pid in _field.partners.keys() if _field != null else []:
				if bool((_field.partners[pid] as Dictionary)["owned"]):
					n += 1
			return [n, int(b["arg"])]
		"equip":
			var e := 0
			for s_v in _equip:
				if str(s_v) != "":
					e += 1
			return [e, int(b["arg"])]
		"wpn":
			return [mini(_wpn_lv, int(b["arg"])), int(b["arg"])]
		"realm":
			return [mini(_realm, int(b["arg"])), int(b["arg"])]
		"kill":
			return [mini(_kills, int(b["arg"])), int(b["arg"])]
		"money":
			return [mini(_money_earned, int(b["arg"])), int(b["arg"])]
		"time":
			return [mini(int(_run_time), int(b["arg"])), int(b["arg"])]
	return [0, 1]

# 每秒检查一次：满足即**锁定**＋给效果＋提醒
# 条件的白话说法（详情页用）
func _bond_cond_cn(b: Dictionary) -> String:
	match str(b["cond"]):
		"sets":
			var arr: Array = b["arg"]
			var names := []
			for s in arr:
				for s_v in CARD_SETS:
					if str((s_v as Dictionary)["set"]) == str(s):
						names.append(str((s_v as Dictionary)["name"]))
			return "完成卡组：" + "、".join(PackedStringArray(names))
		"partners":
			return "招募满 " + str(int(b["arg"])) + " 位伙伴"
		"equip":
			return "六格装备全满"
		"wpn":
			return "成长武器 +" + str(int(b["arg"]))
		"realm":
			return "境界到 " + str(["", "筑基", "金丹", "元婴", "化神"][clampi(int(b["arg"]), 0, 4)])
		"kill":
			return "本局杀敌 " + str(int(b["arg"]))
		"money":
			return "本局累计文钱 " + str(int(b["arg"]))
		"time":
			return "存活 " + str(int(int(b["arg"]) / 60)) + " 分钟"
	return "—"

func _bond_check() -> void:
	for b_v in BONDS:
		var b: Dictionary = b_v
		var id := str(b["id"])
		if bool(_bonds_locked.get(id, false)):
			continue
		var pr := _bond_progress(b)
		if int(pr[0]) < int(pr[1]):
			continue
		_bonds_locked[id] = true
		var key := str(b["key"])
		var v := float(b["v"])
		if key == "dmg_elem_all":
			for el in ["金系", "木系", "火系", "水系", "土系"]:
				_extra["dmg_elem"][el] = float(_extra["dmg_elem"].get(el, 0.0)) + v
		elif key == "meditate":
			_extra["meditate_bonus"] = float(_extra.get("meditate_bonus", 0.0)) + v
		elif key == "mp_all":
			_extra["mp_all"] = float(_extra.get("mp_all", 0.0)) + v
		else:
			_extra[key] = float(_extra.get(key, 0.0)) + v
		_hint.text = "羁绊激活：" + str(b["n"]) + "　" + str(b["fx"])
		Audio.sfx("levelup", -2.0)
		if _field != null:
			_field._push_float(_field.hero_pos.x, _field.hero_pos.y - 140.0, "羁绊：" + str(b["n"]), Color(1.0, 0.88, 0.42), true)
		_sync_battle_stats()
# v12a 主动宝物地基 ＋ 玲珑玉壶（用户口径）
#   效果：恢复自身 气血 25% ＋ 内力 25%　冷却 60 秒　气血低于 50% 时**自动**用（手动也行）
#   品质影响恢复与冷却（凡 25%/60s → 绝 40%/35s，高档附加减伤）
#   这一套是"主动宝物"的地基：以后护身符、遁地符都是填数据。
# ============================================================
const YUHU_NAME := "玲珑玉壶"
const YUHU_HEAL := [0.25, 0.28, 0.30, 0.32, 0.35, 0.40]
const YUHU_CD := [60.0, 55.0, 50.0, 45.0, 40.0, 35.0]
var _yh_cd := 0.0
var _yh_auto := true
var _yh_q := 0
var _yh_btn: Button = null
var _yh_lb: Label = null
var _yh_auto_btn: Button = null

func _yh_ready() -> bool:
	return _yh_cd <= 0.0

func _yh_use() -> void:
	if not _yh_ready() or _field == null:
		return
	var heals := float(YUHU_HEAL[clampi(_yh_q, 0, 5)])
	var hp_add := float(_field.hero["hp_max"]) * heals
	var mp_add := float(_field.hero["mp_max"]) * heals
	_field.hero["hp"] = minf(float(_field.hero["hp_max"]), float(_field.hero["hp"]) + hp_add)
	_field.hero["mp"] = minf(float(_field.hero["mp_max"]), float(_field.hero["mp"]) + mp_add)
	_yh_cd = float(YUHU_CD[clampi(_yh_q, 0, 5)])
	_field._push_float(_field.hero_pos.x, _field.hero_pos.y - 96.0, "玉壶：气血/内力 +" + str(int(heals * 100.0)) + "%", Color(0.62, 0.92, 0.86), true)
	if _field.has_method("_burst_at"):
		_field._burst_at(_field.hero_pos, Color(0.62, 0.92, 0.86), 2.0)
	Audio.sfx("chest", -6.0)
	_hint.text = "玲珑玉壶：气血 +" + str(int(hp_add)) + " · 内力 +" + str(int(mp_add))

func _yh_toggle_auto() -> void:
	_yh_auto = not _yh_auto
	if _yh_auto_btn != null and is_instance_valid(_yh_auto_btn):
		_yh_auto_btn.text = "自动：" + ("开" if _yh_auto else "关")

# 每帧：冷却倒计时 ＋ 自动使用（气血低于 50% 就喝）
func _yh_tick(delta: float) -> void:
	if _yh_cd > 0.0:
		_yh_cd = maxf(0.0, _yh_cd - delta)
	if _yh_auto and _yh_ready() and _field != null:
		var hp := float(_field.hero["hp"])
		var mx := maxf(1.0, float(_field.hero["hp_max"]))
		if hp / mx < 0.5:
			_yh_use()
	if _yh_lb != null and is_instance_valid(_yh_lb):
		_yh_lb.text = "玉壶 " + str(int(ceil(_yh_cd))) + "s" if not _yh_ready() else "玉壶 就绪"
		_yh_lb.add_theme_color_override("font_color", Color(0.62, 0.92, 0.86) if _yh_ready() else DIM)
	if _yh_btn != null and is_instance_valid(_yh_btn):
		_yh_btn.disabled = not _yh_ready()
# ---- v7a 卡面（单卡属性 ＋ 组合栏 ＋ 进度条）----
func _card_face(p: Control, pos: Vector2, sz: Vector2, id: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.97, 0.92) if id != "" else Color(0.85, 0.83, 0.79)
	sb.set_corner_radius_all(10)
	var qcol := Color(INK.r, INK.g, INK.b, 0.35)
	var set_done := false
	if id != "":
		# v7b：**成套后描金**（用户参考的"三国凑 9 张变色"）
		set_done = bool(_sets_done.get(str(id.split("_")[0]), false))
		qcol = Color(0.92, 0.74, 0.28, 1.0) if set_done else _quality_color(str(card_set_of(id).get("quality", "下品")))
	sb.border_color = qcol
	sb.set_border_width_all(3 if set_done else 2)
	var box := Panel.new()
	box.position = pos
	box.size = sz
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_child(box)
	if id == "":
		var e0 := Label.new()
		e0.position = Vector2(6, sz.y * 0.5 - 16.0)
		e0.size = Vector2(sz.x - 12, 32)
		e0.add_theme_font_size_override("font_size", 22)
		e0.add_theme_color_override("font_color", DIM)
		e0.text = "空"
		e0.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(e0)
		return
	var s := card_set_of(id)
	# v8e（用户："卡组的十格也大一些 这个界面也空了很多空间"）——十格做成**竖长卡**：
	#   名字 / 品级 / 简笔图标 / 单卡属性 / 大字进度，整格可点看详情
	var nm := Label.new()
	nm.position = Vector2(4, 10)
	nm.size = Vector2(sz.x - 8, 72)
	nm.add_theme_font_size_override("font_size", 25)
	nm.add_theme_color_override("font_color", INK)
	nm.text = card_name(id)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(nm)
	# 品级（按档配色）
	var st := Label.new()
	st.position = Vector2(4, 84)
	st.size = Vector2(sz.x - 8, 32)
	st.add_theme_font_size_override("font_size", 22)
	st.text = str(card_set_of(id).get("quality", ""))
	st.add_theme_color_override("font_color", _quality_color(str(card_set_of(id).get("quality", "下品"))))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(st)
	# v8e：简笔图标 ＋ 单卡属性（竖长卡才放得下）
	# v8g（用户："当十格子满的时候 你得在格子里腾出一个换的按钮吧"）：
	#   换卡模式下**卡面自己让出底部一条**（图标上移、进度上移），把位置留给［换］
	var swap_mode := _pending_card != ""
	var ic := CardIcon.new()
	ic.host = self
	ic.kind = _card_icon_of(str(s.get("set", "")))
	ic.position = Vector2(sz.x * 0.5 - (26.0 if swap_mode else 32.0), 104.0 if swap_mode else 122.0)
	ic.size = Vector2(52, 52) if swap_mode else Vector2(64, 64)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ic)
	# v8f（用户："十格不用显示属性"）——十格里不写单卡属性，点开看详情
	# v8d（用户："格子底下显示的进度条 换成1/3 这种 显目一点"）——细条改成大字
	var got := 0
	for i in int(s.get("size", 1)):
		if _card_have.has(card_id(str(s.get("set", "")), i)):
			got += 1
	var done_set := got >= int(s.get("size", 1))
	var pg := Label.new()
	pg.position = Vector2(4, sz.y - (118.0 if swap_mode else 74.0))
	pg.size = Vector2(sz.x - 8, 56 if swap_mode else 66)
	pg.add_theme_font_size_override("font_size", 32 if swap_mode else 38)
	pg.add_theme_color_override("font_color", Color(0.30, 0.62, 0.34) if done_set else SEAL)
	# v10b：杀意这类"按杀敌进化"的卡，进度显示的是**杀敌数**
	if s.has("evo_kills"):
		pg.add_theme_font_size_override("font_size", 22)
		pg.text = "杀敌 " + str(int(_card_kills.get(id, 0))) + "/" + str(int(s["evo_kills"]))
	else:
		pg.text = (str(got) + "/" + str(int(s.get("size", 1)))) if not done_set else "已成"
	pg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(pg)

func _quality_color(q: String) -> Color:
	match q:
		"绝品":
			return Color(0.86, 0.44, 0.24, 0.9)
		"极品":
			return Color(0.86, 0.68, 0.26, 0.9)
		"上品":
			return Color(0.52, 0.34, 0.72, 0.85)
		"中品":
			return Color(0.30, 0.58, 0.72, 0.8)
	return Color(INK.r, INK.g, INK.b, 0.35)
# ============================================================
# v13a 黑市重做（规格：docs/困兽_交接文档.md §6.1）
#   · 六格货架，**每格只能买一次**，买掉即空（不补货）
#   · **只手动刷新**：花 1 次「黑市刷新次数」→ 六格全部重掷（折扣一起重掷）；
#     每 180 秒自动 +1 次刷新是 v4d 的旧规矩，保留
#   · **每件 30% 概率打折**：7/5/3/2 折（权重 40/30/20/10），黑市等级越高越偏大折扣
#   · 等级越高东西越好：Lv2 强化石/装备 · Lv3 消耗型装备小 · Lv5 吞噬丹 · Lv7 起可能出上品/极品装备
# ============================================================
const BM_SLOTS := 6
const BM_DISC := [0.7, 0.5, 0.3, 0.2]
const BM_DISC_CN := ["7折", "5折", "3折", "2折"]
const BM_DISC_RATE := 0.30                                   # 每件 30% 概率打折
const BM_GEAR_PRICE := [300, 400, 550, 750, 1000, 1400]      # 装备货品：按品级，300 起
const BM_GOODS := [
	{"id": "bm_refresh", "n": "黑市刷新", "cost": 40, "lv": 1, "w": 16, "d": "黑市刷新次数 +1（再来一轮货）"},
	{"id": "money_bag", "n": "文钱袋", "cost": 50, "lv": 1, "w": 16, "d": "文钱 +600（进右上钱账）"},
	{"id": "crystal_bag", "n": "灵晶袋", "cost": 70, "lv": 1, "w": 14, "d": "灵晶 +40（抽卡用的晶）"},
	{"id": "trea_refresh", "n": "宝物刷新", "cost": 60, "lv": 1, "w": 12, "d": "宝物刷新次数 +1"},
	{"id": "card_refresh", "n": "卡组刷新", "cost": 60, "lv": 1, "w": 12, "d": "卡组刷新次数 +1（抽卡页免费用）"},
	{"id": "wpn_stone", "n": "强化石", "cost": 120, "lv": 2, "w": 13, "d": "成长武器直接 +2 级"},
	{"id": "gear", "n": "装备", "cost": 300, "lv": 2, "w": 12, "d": "按品级随机一件（六格满则进仓库）"},
	{"id": "gear_s", "n": "消耗型装备·小", "cost": 80, "lv": 3, "w": 15, "d": "点击即用：攻 +3 · 血 +15（可重复买，叠加）"},
	{"id": "eat_pill", "n": "吞噬丹", "cost": 200, "lv": 5, "w": 14, "d": "随机吞掉十格一张卡：腾位，效果与成套计数保留"},
]

# 折扣权重：Lv1 就是规格里的 40/30/20/10；等级越高越偏大折扣（总和恒为 100）
func _bm_disc_w() -> Array:
	var t := clampi(_bm_lv - 1, 0, 12)
	return [maxi(6, 40 - t * 3), 30, 20 + t, 10 + t * 2]

# 货架上装备的品级：Lv1-3 最多中品 · Lv4-6 可能上品 · Lv7 起可能极品
func _bm_gear_q() -> int:
	var cap := 2
	if _bm_lv >= 7:
		cap = 4
	elif _bm_lv >= 4:
		cap = 3
	var w: Array = [50, 28, 14, 6, 2, 0]
	var roll := randi() % 100
	var acc := 0
	var q := 0
	for i in 6:
		acc += int(w[i])
		if roll < acc:
			q = i
			break
	return mini(q, cap)

# 摆一格货（含 30% 打折；装备货品当场定品级，价按品级走）
func _bm_make_slot(g: Dictionary) -> Dictionary:
	var base := int(g["cost"])
	var gear: Dictionary = {}
	if str(g["id"]) == "gear":
		var q := _bm_gear_q()
		var mul := float(WPN_Q_MUL[q])
		var pool: Array = GEAR_EQ_NAMES
		gear = {"name": str(pool[randi() % pool.size()]), "q": q,
			"atk": int(ceil(3.0 * mul)), "hp": int(ceil(14.0 * mul)),
			"price": int(60.0 * mul * mul)}
		base = int(BM_GEAR_PRICE[q])
	var disc := -1
	if randf() < BM_DISC_RATE:
		var w := _bm_disc_w()
		var roll := randi() % 100
		var acc := 0
		for i in 4:
			acc += int(w[i])
			if roll < acc:
				disc = i
				break
	var cost: int = base
	if disc >= 0:
		cost = maxi(1, int(floor(float(base) * float(BM_DISC[disc]))))
	return {"id": str(g["id"]), "n": str(g["n"]), "d": str(g["d"]), "base": base,
		"disc": disc, "cost": cost, "q": int(gear.get("q", 0)), "gear": gear, "bought": false}

# 重掷六格：先尽量不重样（Lv1 只有 5 种货，凑不满 6 格时才允许重样）
func _bm_roll() -> void:
	var pool: Array = []
	for g_v in BM_GOODS:
		var g: Dictionary = g_v
		if _bm_lv >= int(g["lv"]):
			for i in int(g["w"]):
				pool.append(g)
	_bm_slots.clear()
	if pool.is_empty():
		return
	var used := {}
	var tries := 0
	while _bm_slots.size() < BM_SLOTS and tries < 900:
		tries += 1
		var g: Dictionary = pool[randi() % pool.size()]
		var id := str(g["id"])
		var limit: int = 1 if tries < 400 else 2
		if int(used.get(id, 0)) >= limit:
			continue
		used[id] = int(used.get(id, 0)) + 1
		_bm_slots.append(_bm_make_slot(g))

# 花 1 次刷新：六格全部重掷（含折扣重掷）
func _bm_refresh_now() -> void:
	if _bm_refresh <= 0:
		_hint.text = "没有黑市刷新次数了（每 180 秒自动 +1；货架上也有卖）"
		return
	_bm_refresh -= 1
	_bm_roll()
	Audio.sfx("ui_click", -8.0)
	_hint.text = "黑市重掷六格（折扣一起重掷），刷新剩 " + str(_bm_refresh) + " 次"
	if _popup_kind == "黑市":
		_open_large("黑市")

# 十格里还能被吞的卡有几张
func _bm_edible() -> int:
	var n := 0
	for i in _deck_cards.size():
		if str(_deck_cards[i]) != "":
			n += 1
	return n

# 货名（装备带上具体那件）
func _bm_slot_title(s: Dictionary) -> String:
	if str(s["id"]) == "gear":
		var g: Dictionary = s.get("gear", {})
		return "装备·" + str(g.get("name", ""))
	return str(s["n"])

# 货品说明（装备把品级与加成写出来）
func _bm_slot_desc(s: Dictionary) -> String:
	if str(s["id"]) == "gear":
		var g: Dictionary = s.get("gear", {})
		return "【" + str(WPN_Q_CN[int(g.get("q", 0))]) + "】攻 +" + str(int(g.get("atk", 0))) \
			+ " · 血 +" + str(int(g.get("hp", 0))) + "（六格满则进仓库）"
	return str(s["d"])

# 强化石：成长武器 +n 级（进阶照旧：每 10 级品质升档 ＋ 掷三选一）
func _bm_wpn_add(n: int) -> String:
	_qc("wpn", n)                      # v13c：任务进度（强化武器）
	var adv := ""
	for i in n:
		_wpn_lv += 1
		if _wpn_lv % 10 == 0:
			_wpn_q = mini(5, _wpn_q + 1)
			_wpn_await = true
			_wpn_refresh_n = 0
			_wpn_roll_choices()
			adv = str(WPN_Q_CN[_wpn_q])
	_sync_battle_stats()
	Audio.sfx("hit_heavy", -10.0, 1.3)
	return adv

# 吞噬丹：随机吞掉十格里的一张卡 → 卡离开格子（腾位），但 _card_have 不动
#   → 单卡效果（杀意/打坐）与成套计数（_set_check 只看 _card_have）全部保留
func _bm_eat_pill() -> String:
	var cand: Array = []
	for i in _deck_cards.size():
		if str(_deck_cards[i]) != "":
			cand.append(i)
	if cand.is_empty():
		return "十格是空的——这丹药没东西可吞"
	var idx := int(cand[randi() % cand.size()])
	var cid := str(_deck_cards[idx])
	_deck_cards[idx] = ""
	_bm_eaten.append(cid)
	_set_check(str(cid.split("_")[0]))     # 吞完立刻再验一次：成套照样给（例：3 合套吞一张，另两张仍能凑齐）
	Audio.sfx("hit_heavy", -8.0, 0.7)
	if _field != null:
		_field._push_float(_field.hero_pos.x, _field.hero_pos.y - 120.0, "吞噬：" + card_name(cid), SEAL, true)
	return "吞噬丹吞掉「" + card_name(cid) + "」（第 " + str(idx + 1) + " 格腾空 · 效果与成套计数保留）"

# 一格货（320 × 200）：名字 / 说明 / 价签（原价划掉 → 折后朱红大字）/ ［买］
func _bm_tile(p: Control, pos: Vector2, sz: Vector2, i: int) -> void:
	var s: Dictionary = _bm_slots[i]
	var bought := bool(s.get("bought", false))
	var cost := int(s["cost"])
	var can: bool = (not bought) and _kills >= cost
	var is_gear: bool = str(s["id"]) == "gear"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.90, 0.88, 0.84) if bought else Color(0.99, 0.97, 0.92)
	sb.set_corner_radius_all(12)
	if bought:
		sb.border_color = Color(INK.r, INK.g, INK.b, 0.22)
	elif is_gear:
		sb.border_color = _quality_color(str(WPN_Q_CN[int(s["q"])]))
	else:
		sb.border_color = Color(SEAL.r, SEAL.g, SEAL.b, 0.55)
	sb.set_border_width_all(2)
	var box := Panel.new()
	box.position = pos
	box.size = sz
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_child(box)
	var nm := Label.new()
	nm.position = Vector2(14, 6)
	nm.size = Vector2(sz.x - 28.0, 34)
	nm.add_theme_font_size_override("font_size", 25)
	nm.add_theme_color_override("font_color", DIM if bought else INK)
	nm.text = _bm_slot_title(s)
	box.add_child(nm)
	var ds := Label.new()
	ds.position = Vector2(14, 42)
	ds.size = Vector2(sz.x - 28.0, 52)
	ds.add_theme_font_size_override("font_size", 18)
	ds.add_theme_color_override("font_color", DIM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.text = _bm_slot_desc(s)
	box.add_child(ds)
	if bought:
		var sold := Label.new()
		sold.position = Vector2(14, 112)
		sold.size = Vector2(sz.x - 28.0, 40)
		sold.add_theme_font_size_override("font_size", 26)
		sold.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.45))
		sold.text = "已售罄（等刷新）"
		box.add_child(sold)
		return
	# 价签：原价划掉 → 折后朱红大字（RichTextLabel 的 [s] 就是删除线）
	var pr := RichTextLabel.new()
	pr.bbcode_enabled = true
	pr.scroll_active = false
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pr.position = Vector2(14, 96)
	pr.size = Vector2(sz.x - 28.0, 44)
	pr.add_theme_font_size_override("normal_font_size", 20)
	if int(s["disc"]) >= 0:
		pr.text = "[color=#6b625c][s]原价 " + str(int(s["base"])) + "[/s][/color] → [color=#ad2620][font_size=26]" \
			+ str(BM_DISC_CN[int(s["disc"])]) + " " + str(cost) + "[/font_size][/color]"
	else:
		pr.text = "[color=#ad2620][font_size=26]" + str(cost) + "[/font_size][/color][color=#6b625c] 杀敌数[/color]"
	box.add_child(pr)
	var bb := _pbtn(box, "买", Vector2(14, 144), Vector2(sz.x - 28.0, 50), 26, can, _bm_buy.bind(i))
	if not can:
		bb.add_theme_stylebox_override("normal", _flat(Color(0.55, 0.53, 0.51, 0.95)))
		bb.add_theme_stylebox_override("hover", _flat(Color(0.60, 0.58, 0.56, 0.95)))
		bb.add_theme_stylebox_override("pressed", _flat(Color(0.48, 0.46, 0.44, 0.95)))

# 黑市页：顶部「黑市 Lv ＋ 刷新 ×N」＋［刷新］大按钮 ＋ 六格货架
func _fill_black(p: Control, y: float, sz: Vector2) -> float:
	if _bm_slots.is_empty():
		_bm_roll()                                  # 本局还没摆过货：进门先摆一排
	var head := Label.new()
	head.position = Vector2(16, y + 10.0)
	head.size = Vector2(370, 46)
	head.add_theme_font_size_override("font_size", 28)
	head.add_theme_color_override("font_color", INK)
	head.text = "黑市 Lv " + str(_bm_lv) + "　刷新 ×" + str(_bm_refresh)
	p.add_child(head)
	var rb := _pbtn(p, "刷新（花 1 次）", Vector2(392, y), Vector2(264, 76), 24, _bm_refresh > 0, _bm_refresh_now)
	if _bm_refresh <= 0:
		rb.disabled = true
		rb.add_theme_stylebox_override("disabled", _flat(Color(0.46, 0.44, 0.42, 0.95)))
		rb.add_theme_color_override("font_disabled_color", Color(0.88, 0.86, 0.83))
	var sub := Label.new()
	sub.position = Vector2(16, y + 92.0)
	sub.size = Vector2(640, 34)
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", DIM)
	sub.text = "杀敌数 " + str(_kills) + " 就是黑市的钱　·　每 180 秒自动 +1 次刷新"
	p.add_child(sub)
	var ly := y + 136.0
	for i in _bm_slots.size():
		var col := i % 2
		var row := i / 2
		_bm_tile(p, Vector2(2.0 + float(col) * 328.0, ly + float(row) * 214.0), Vector2(320, 200), i)
	var rows_n := int((_bm_slots.size() + 1) / 2)
	var by := ly + float(rows_n) * 214.0 + 4.0
	var tip := Label.new()
	tip.position = Vector2(16, by)
	tip.size = Vector2(640, 74)
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "每件 30% 概率打折（7/5/3/2 折，等级越高越容易出大折扣）· 装备按品级定价 300 起 · 六格每格只能买一次，买掉即空（只手动刷新补货）"
	p.add_child(tip)
	by += 78.0
	if not _bm_eaten.is_empty():
		var names: Array = []
		for id_v in _bm_eaten:
			names.append(card_name(str(id_v)))
		var eat := Label.new()
		eat.position = Vector2(16, by)
		eat.size = Vector2(640, 44)
		eat.add_theme_font_size_override("font_size", 20)
		eat.add_theme_color_override("font_color", SEAL)
		eat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eat.text = "吞噬丹已吞 " + str(_bm_eaten.size()) + " 张（效果与成套计数仍在）：" + "、".join(PackedStringArray(names))
		p.add_child(eat)
		by += 50.0
	return by + 10.0

# 买一格：扣杀敌数 → 当场结账 → 这格标已售罄（不补货）
func _bm_buy(i: int) -> void:
	if i < 0 or i >= _bm_slots.size():
		return
	var s: Dictionary = _bm_slots[i]
	if bool(s.get("bought", false)):
		_hint.text = "这一格已经买过了（买掉即空，等下次刷新）"
		return
	var cost := int(s["cost"])
	if _kills < cost:
		_hint.text = "杀敌数不够（要 " + str(cost) + "，你现在 " + str(_kills) + "）"
		return
	var id := str(s["id"])
	if id == "eat_pill" and _bm_edible() <= 0:
		_hint.text = "十格是空的，吞噬丹没东西可吞（先抽卡再来）"
		return
	_kills -= cost
	var msg := ""
	match id:
		"bm_refresh":
			_bm_refresh += 1
			msg = "黑市刷新 +1（现有 " + str(_bm_refresh) + " 次）"
		"money_bag":
			_money += 600
			_money_earned += 600
			_coin_pop = 0.32
			msg = "文钱 +600（现有 " + str(int(_money)) + "）"
		"crystal_bag":
			_crystal += 40
			_crystal_pop = 0.32
			msg = "灵晶 +40（现有 " + str(int(_crystal)) + "）"
		"trea_refresh":
			_trea_refresh += 1
			msg = "宝物刷新 +1（现有 " + str(_trea_refresh) + " 次）"
		"card_refresh":
			_card_refresh += 1
			msg = "卡组刷新 +1（现有 " + str(_card_refresh) + " 次，去抽卡页用）"
		"wpn_stone":
			var adv := _bm_wpn_add(2)
			msg = "成长武器 +2 级 → +" + str(_wpn_lv) + "（" + str(WPN_Q_CN[_wpn_q]) + "）"
			if adv != "":
				msg += "　进阶了！去［成长武器］选一条线"
		"gear_s":
			_bm_atk += 3
			_bm_hp += 15
			_gear_sync()
			msg = "吃下消耗型装备：攻 +3 · 血 +15（累计 攻 +" + str(_bm_atk) + " · 血 +" + str(_bm_hp) + "）"
		"gear":
			var g: Dictionary = s.get("gear", {})
			_equip_add(g)
			msg = "装备到手：" + str(g.get("name", "")) + "（" + str(WPN_Q_CN[int(g.get("q", 0))]) + "）"
		"eat_pill":
			msg = _bm_eat_pill()
		_:
			pass
	s["bought"] = true
_qc("bm")                         # v13c：任务进度（黑市成交）
	_bm_slots[i] = s
	Audio.sfx("coin", -6.0)
	if _field != null:
		_field._push_float(_field.hero_pos.x, _field.hero_pos.y - 110.0, "黑市 · " + str(s["n"]), GOLD, true)
	_hint.text = "黑市成交 · " + msg + "　（花 " + str(cost) + " 杀敌数，剩 " + str(_kills) + "）"
	if _popup_kind == "黑市":
		_open_large("黑市")
# ============================================================
# v13c P2：事件 / 任务 核心
#   分档按波次（简单越来越少）——P2 只有简单池，普通/困难/特殊以后往池子里填
# ============================================================
const QUEST_SIMPLE := [
	{"id": "tuchang", "n": "屠场", "d": "60 秒内杀 40 只", "ck": "kill", "goal": 40, "sec": 60.0, "cr": 30},
	{"id": "liancai", "n": "敛财", "d": "本局累计攒够 800 文钱", "ck": "money", "goal": 800, "sec": -1.0, "cr": 25},
	{"id": "canwu", "n": "参悟", "d": "抽 3 张卡", "ck": "draw", "goal": 3, "sec": -1.0, "cr": 30, "card": 1},
	{"id": "xiaozang", "n": "销赃", "d": "在黑市成交 3 次", "ck": "bm", "goal": 3, "sec": -1.0, "cr": 25, "bms": 3},
	{"id": "xunbao", "n": "寻宝", "d": "拿到 1 件宝物", "ck": "trea", "goal": 1, "sec": -1.0, "cr": 25, "trs": 2},
	{"id": "shilian", "n": "试炼", "d": "完成任意 2 次挑战", "ck": "chal", "goal": 2, "sec": -1.0, "cr": 30},
	{"id": "cuihuo", "n": "淬火", "d": "强化武器 5 次", "ck": "wpn", "goal": 5, "sec": -1.0, "cr": 20, "wpnlv": 5},
	{"id": "yexun", "n": "夜巡", "d": "撑过一波不倒下", "ck": "alive", "goal": 60, "sec": 60.0, "cr": 30},
	{"id": "zougou", "n": "走狗", "d": "杀掉 1 只挑战怪（大怪）", "ck": "chalkill", "goal": 1, "sec": 90.0, "cr": 35},
]
# 波次 → 档位权重（简单/普通/困难/特殊）：简单越来越少
const Q_TIER_W := [
	{"w": 9, "t": [45, 55, 0, 0]},
	{"w": 19, "t": [20, 50, 30, 0]},
	{"w": 999, "t": [10, 35, 40, 15]},
]
const Q_TIER_CN := ["简单", "普通", "困难", "特殊"]

# 行为计数（任务进度从这里取）
func _qc(key: String, n := 1) -> void:
	_q_ctr[key] = int(_q_ctr.get(key, 0)) + n

func _q_now(key: String) -> int:
	if key == "kill":
		return _kills
	if key == "money":
		return _money_earned
	return int(_q_ctr.get(key, 0))

func _q_prog(q: Dictionary) -> int:
	if str(q["ck"]) == "alive":
		return int(float(q.get("alive", 0.0)))
	return _q_now(str(q["ck"])) - int(q["base"])

# 奖励文案
func _q_reward_cn(d: Dictionary) -> String:
	var parts: Array = []
	if int(d.get("cr", 0)) > 0:
		parts.append("灵晶 " + str(int(d["cr"])))
	if int(d.get("money", 0)) > 0:
		parts.append("文钱 " + str(int(d["money"])))
	if int(d.get("bms", 0)) > 0:
		parts.append("黑市刷新 " + str(int(d["bms"])))
	if int(d.get("trs", 0)) > 0:
		parts.append("宝物刷新 " + str(int(d["trs"])))
	if int(d.get("card", 0)) > 0:
		parts.append("卡组刷新 " + str(int(d["card"])))
	if int(d.get("wpnlv", 0)) > 0:
		parts.append("武器 +" + str(int(d["wpnlv"])) + " 级")
	if parts.is_empty():
		return "—"
	return "、".join(PackedStringArray(parts))

# 发奖
func _q_grant(d: Dictionary) -> String:
	if int(d.get("cr", 0)) > 0:
		_crystal += int(d["cr"])
		_crystal_pop = 0.32
	if int(d.get("money", 0)) > 0:
		_money += int(d["money"])
		_money_earned += int(d["money"])
		_coin_pop = 0.32
	if int(d.get("bms", 0)) > 0:
		_bm_refresh += int(d["bms"])
	if int(d.get("trs", 0)) > 0:
		_trea_refresh += int(d["trs"])
	if int(d.get("card", 0)) > 0:
		_card_refresh += int(d["card"])
	if int(d.get("wpnlv", 0)) > 0:
		_bm_wpn_add(int(d["wpnlv"]))
	return _q_reward_cn(d)

# 掷一个任务（先按波次决定档位；池子空就往下降级）
func _q_roll() -> Dictionary:
	var row: Array = Q_TIER_W[0]["t"]
	for r_v in Q_TIER_W:
		if _wave <= int(r_v["w"]):
			row = r_v["t"]
			break
	var roll := randi() % 100
	var acc := 0
	var tier := 0
	for i in 4:
		acc += int(row[i])
		if roll < acc:
			tier = i
			break
	while tier > 0:
		# P2 只填了简单池：高档次暂时降级（池子以后补）
		break
	tier = 0
	var used: Array = []
	for s_v in _q_slots:
		used.append(str((s_v as Dictionary)["id"]))
	var pick: Array = []
	for d_v in QUEST_SIMPLE:
		var d: Dictionary = d_v
		if not used.has(str(d["id"])):
			pick.append(d)
	if pick.is_empty():
		return {}
	var out: Dictionary = (pick[randi() % pick.size()] as Dictionary).duplicate()
	out["tier"] = tier
	return out

# 触发一次事件：挂进任务栏（挂满就顺延），只出横幅不弹窗
func _q_event() -> void:
	if _q_slots.size() >= Q_MAX:
		return
	var d := _q_roll()
	if d.is_empty():
		return
	var q := d
	q["left"] = float(d.get("sec", -1.0))
	q["base"] = _q_now(str(d["ck"]))
	q["alive"] = 0.0
	_q_slots.append(q)
	var tail := ""
	if float(q["left"]) >= 0.0:
		tail = "　限时 " + str(int(q["left"])) + " 秒"
	_note("【事件·" + str(Q_TIER_CN[int(q["tier"])]) + "】" + str(q["n"]) + "　" + str(q["d"]) + tail
		+ "　·　奖 " + _q_reward_cn(q) + "\n（已经在任务栏里挂着；不想做就点［放弃］，给 10 灵晶）", 5.0)
	_hint.text = "新任务：「" + str(q["n"]) + "」" + str(q["d"])
	Audio.sfx("bell", -6.0)

# 放弃：+10 灵晶
func _q_give_up(i: int) -> void:
	if i < 0 or i >= _q_slots.size():
		return
	var q: Dictionary = _q_slots[i]
	_q_slots.remove_at(i)
	_q_give += 1
	_crystal += Q_GIVE_CRYSTAL
	_crystal_pop = 0.32
	_hint.text = "放弃「" + str(q["n"]) + "」：灵晶 +" + str(Q_GIVE_CRYSTAL) + "（现在 " + str(int(_crystal)) + "）"
	Audio.sfx("ui_click", -8.0)
	if _popup_kind == "任务":
		_open_large("任务")

# 每帧：事件计时 ＋ 进度检查（完成发奖 / 限时到点失败）
func _q_tick(delta: float) -> void:
	_q_t += delta
	if _q_t >= Q_EVENT_SEC:
		_q_t -= Q_EVENT_SEC
		_q_event()
	for i in range(_q_slots.size() - 1, -1, -1):
		var q: Dictionary = _q_slots[i]
		if str(q["ck"]) == "alive":
			q["alive"] = float(q.get("alive", 0.0)) + delta
		if _q_prog(q) >= int(q["goal"]):
			var got := _q_grant(q)
			_q_slots.remove_at(i)
			_q_done += 1
			_note("【任务完成】" + str(q["n"]) + "　到手：" + got, 4.0)
			Audio.sfx("levelup", -4.0)
			continue
		if float(q["left"]) >= 0.0:
			q["left"] = float(q["left"]) - delta
			if float(q["left"]) <= 0.0:
				_q_slots.remove_at(i)
				_q_fail += 1
				_note("【任务失败】" + str(q["n"]) + "　时间到——失败不给东西", 3.5)
				Audio.sfx("fall_down", -6.0)
	_q_chips_update()

# 战场左下角那两条任务条（点着不挡操作：Label 不吃鼠标）
func _q_chips_update() -> void:
	if _q_panel == null:
		_q_panel = _panel(Rect2(6, 794, 492, 88), Color(0.12, 0.12, 0.14, 0.70), 10)
		for i in Q_MAX:
			var l := _lbl(Vector2(14, 798 + float(i) * 40.0), Vector2(476, 36), 20, Color(0.97, 0.93, 0.80))
			_q_lb.append(l)
	var any := not _q_slots.is_empty()
	_q_panel.visible = any
	for i in Q_MAX:
		var l2: Label = _q_lb[i]
		if i < _q_slots.size():
			var q: Dictionary = _q_slots[i]
			var tail := ""
			if float(q["left"]) >= 0.0:
				var sec := int(ceil(maxf(0.0, float(q["left"]))))
				tail = "　%02d:%02d" % [sec / 60, sec % 60]
			l2.text = "【任务】" + str(q["n"]) + "　" + str(_q_prog(q)) + "/" + str(int(q["goal"])) + tail
			l2.visible = true
		else:
			l2.visible = false

# ---- 任务页（事件钮进来）：进行中 2 格 ＋ 本局账 ----
func _fill_quest(p: Control, y: float, sz: Vector2) -> float:
	var head := Label.new()
	head.position = Vector2(20, y)
	head.size = Vector2(620, 40)
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", INK)
	var nxt := int(ceil(maxf(0.0, Q_EVENT_SEC - _q_t)))
	head.text = "进行中 " + str(_q_slots.size()) + " / " + str(Q_MAX) + "　·　下一次事件 " + ("%02d:%02d" % [nxt / 60, nxt % 60])
	p.add_child(head)
	var ly := y + 50.0
	if _q_slots.is_empty():
		var em := Label.new()
		em.position = Vector2(20, ly)
		em.size = Vector2(620, 44)
		em.add_theme_font_size_override("font_size", 21)
		em.add_theme_color_override("font_color", DIM)
		em.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		em.text = "现在没有任务——牢里每 3 分钟出一次事，出了会自动挂到这里。"
		p.add_child(em)
		ly += 56.0
	for i in _q_slots.size():
		var q: Dictionary = _q_slots[i]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.97, 0.92)
		sb.set_corner_radius_all(12)
		sb.border_color = Color(SEAL.r, SEAL.g, SEAL.b, 0.5)
		sb.set_border_width_all(2)
		var box := Panel.new()
		box.position = Vector2(16, ly)
		box.size = Vector2(624, 140)
		box.add_theme_stylebox_override("panel", sb)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(box)
		var nm := Label.new()
		nm.position = Vector2(16, 8)
		nm.size = Vector2(320, 38)
		nm.add_theme_font_size_override("font_size", 27)
		nm.add_theme_color_override("font_color", INK)
		nm.text = "【" + str(q["n"]) + "】"
		box.add_child(nm)
		var ds := Label.new()
		ds.position = Vector2(16, 48)
		ds.size = Vector2(390, 34)
		ds.add_theme_font_size_override("font_size", 20)
		ds.add_theme_color_override("font_color", DIM)
		ds.text = str(q["d"])
		box.add_child(ds)
		var prog := _q_prog(q)
		var bgb := ColorRect.new()
		bgb.position = Vector2(16, 92)
		bgb.size = Vector2(390, 18)
		bgb.color = Color(0.85, 0.83, 0.79)
		bgb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bgb)
		var fg := ColorRect.new()
		fg.position = Vector2(16, 92)
		fg.size = Vector2(390.0 * clampf(float(prog) / maxf(1.0, float(q["goal"])), 0.0, 1.0), 18)
		fg.color = SEAL
		fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(fg)
		var pt := Label.new()
		pt.position = Vector2(16, 112)
		pt.size = Vector2(390, 26)
		pt.add_theme_font_size_override("font_size", 19)
		pt.add_theme_color_override("font_color", INK)
		pt.text = "进度 " + str(prog) + " / " + str(int(q["goal"]))
		box.add_child(pt)
		var tl := Label.new()
		tl.position = Vector2(416, 76)
		tl.size = Vector2(192, 30)
		tl.add_theme_font_size_override("font_size", 21)
		tl.add_theme_color_override("font_color", SEAL if float(q["left"]) >= 0.0 else DIM)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if float(q["left"]) >= 0.0:
			var sec2 := int(ceil(maxf(0.0, float(q["left"]))))
			tl.text = "剩余 %02d:%02d" % [sec2 / 60, sec2 % 60]
		else:
			tl.text = "不限时"
		box.add_child(tl)
		var rw := Label.new()
		rw.position = Vector2(416, 110)
		rw.size = Vector2(192, 26)
		rw.add_theme_font_size_override("font_size", 18)
		rw.add_theme_color_override("font_color", GOLD)
		rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rw.text = "奖 " + _q_reward_cn(q)
		box.add_child(rw)
		_pbtn(box, "放弃 +" + str(Q_GIVE_CRYSTAL), Vector2(432, 10), Vector2(176, 60), 22, false, _q_give_up.bind(i))
		ly += 152.0
	var acc := Label.new()
	acc.position = Vector2(20, ly + 4.0)
	acc.size = Vector2(620, 36)
	acc.add_theme_font_size_override("font_size", 22)
	acc.add_theme_color_override("font_color", INK)
	acc.text = "本局账：完成 " + str(_q_done) + "　放弃 " + str(_q_give) + "　失败 " + str(_q_fail)
	p.add_child(acc)
	var tip := Label.new()
	tip.position = Vector2(20, ly + 46.0)
	tip.size = Vector2(620, 110)
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "规则：每 180 秒牢里出一次事 → 自动挂上任务（最多 2 个，挂满就顺延到下一次）。做完才有奖励；限时到点算失败，什么都不给；不想做就放弃，放弃给 " + str(Q_GIVE_CRYSTAL) + " 灵晶（抽卡 20 的一半）。"
	p.add_child(tip)
	return ly + 170.0

# ---- 失败结算（v3m）----
func _fill_over(p: Control, y: float, sz: Vector2) -> float:
	var head := Label.new()
	head.position = Vector2(28, y)
	head.size = Vector2(640, 60)
	head.add_theme_font_size_override("font_size", 32)
	head.add_theme_color_override("font_color", SEAL)
	head.text = "这一局到这儿"
	p.add_child(head)
	var rows := [
		["打到", "第 " + str(_wave) + " 波 / 共 30 波" + ("（boss 波）" if _wave % 5 == 0 else "")],
		["杀敌", str(_kills) + " 只"],
		["文钱", str(_money) + "（这一局结束会清空，名声才留）"],
		["灵晶", str(_crystal)],
		["等级 / 技能点", "Lv " + str(_lv) + "　技能点 " + str(_skill_pts)],
		["宠物", "白狐（跟着打到最后一口气）"],
	]
	var ly := y + 74.0
	for r_v in rows:
		var r: Array = r_v
		var l1 := Label.new()
		l1.position = Vector2(28, ly)
		l1.size = Vector2(190, 46)
		l1.add_theme_font_size_override("font_size", 23)
		l1.add_theme_color_override("font_color", DIM)
		l1.text = str(r[0])
		p.add_child(l1)
		var l2 := Label.new()
		l2.position = Vector2(226, ly)
		l2.size = Vector2(440, 46)
		l2.add_theme_font_size_override("font_size", 24)
		l2.add_theme_color_override("font_color", INK)
		l2.text = str(r[1])
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(l2)
		ly += 56.0
	var tip := Label.new()
	tip.position = Vector2(28, ly + 10.0)
	tip.size = Vector2(640, 70)
	tip.add_theme_font_size_override("font_size", 21)
	tip.add_theme_color_override("font_color", DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "再来一局：波数、文钱、灵晶、技能全部重来（名声才累积，第 6 步接）。"
	p.add_child(tip)
	ly += 96.0
	_pbtn(p, "再来一局", Vector2(28, ly), Vector2(320, 96), 28, true, _restart_run)
	_pbtn(p, "退出（回村外）", Vector2(366, ly), Vector2(302, 96), 24, false, func(): close())
	return ly + 116.0

func _restart_run() -> void:
	_wave = 1
	_money = 0
	_crystal = 0
	_kills = 0
	_exp = 0.0
	_lv = 1
	_grow = 3
	_skill_pts = 0
	_skill_choices.clear()
	_revive = 1
	_boss_sec = 60.0
	_boss_seq = 0
	_over = false
	_field.reset_run()
	_field.reset_partners()          # v6b：伙伴退回未入队（招募是这一局的事）
	_grow_inherit = {"arm": 0, "agi": 0, "wit": 0}
	_recruit_opens = 0
	_recruit_choices.clear()
	_bm_roll()                       # v13a：新的一局，黑市货架重摆
	_sync_battle_stats()
	_close_popup()
	_hint.text = "新的一局——预备几秒，怪就压上来了"

# ---- 技能页：三选一（有技能点时）／当前招式（没点时）----
#   数据与效果都在战场（kushou_battle.gd）里：roll_choices() 抽、apply_pick() 落。
func _fill_skill(p: Control, y: float, sz: Vector2) -> float:
	var head := Label.new()
	head.position = Vector2(28, y)
	head.size = Vector2(640, 46)
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", INK)
	head.text = "技能点：" + str(_skill_pts) + "　（每升 1 级给 1 点）"
	p.add_child(head)
	var ly := y + 54.0
	if _skill_pts > 0:
		if _skill_choices.is_empty():
			_skill_choices = _field.roll_choices()
		var sub := Label.new()
		sub.position = Vector2(28, ly)
		sub.size = Vector2(640, 40)
		sub.add_theme_font_size_override("font_size", 22)
		sub.add_theme_color_override("font_color", DIM)
		sub.text = "三选一——选完**立刻生效**，动作也跟着变".replace("**立刻生效**", "立刻生效")
		p.add_child(sub)
		ly += 46.0
		var w := 200.0
		for i in _skill_choices.size():
			var e: Dictionary = _skill_choices[i]
			var x := 28.0 + float(i) * (w + 20.0)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.99, 0.97, 0.92)
			sb.set_corner_radius_all(12)
			var mech := str(e["kind"]) == "mech"
			sb.border_color = Color(SEAL.r, SEAL.g, SEAL.b, 0.75) if mech else Color(INK.r, INK.g, INK.b, 0.35)
			sb.set_border_width_all(3 if mech else 2)
			var box := Panel.new()
			box.position = Vector2(x, ly)
			box.size = Vector2(w, 330)
			box.add_theme_stylebox_override("panel", sb)
			box.mouse_filter = Control.MOUSE_FILTER_STOP
			p.add_child(box)
			var nm := Label.new()
			nm.position = Vector2(12, 14)
			nm.size = Vector2(w - 24, 62)
			nm.add_theme_font_size_override("font_size", 26)
			nm.add_theme_color_override("font_color", INK)
			nm.text = str(e["name"])
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(nm)
			var tag := Label.new()
			tag.position = Vector2(12, 76)
			tag.size = Vector2(w - 24, 30)
			tag.add_theme_font_size_override("font_size", 19)
			tag.add_theme_color_override("font_color", SEAL if mech else DIM)
			tag.text = ("机制" if mech else "数值") + "　" + str(_field.skill_lv(str(e["id"]))) + "/" + str(e["max"])
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(tag)
			var ds := Label.new()
			ds.position = Vector2(12, 112)
			ds.size = Vector2(w - 24, 120)
			ds.add_theme_font_size_override("font_size", 20)
			ds.add_theme_color_override("font_color", INK)
			# <R> 是范围技的实时半径（学了才显示数字）
			# <R>/<C>/<D>/<W>/<P>/<S> 都是"实时数值"，让玩家点之前就看见当前档位
			var txt := str(e["desc"])
			txt = txt.replace("<R>", str(int(_field.splash_radius())) + " 像素")
			txt = txt.replace("<C>", str(int(_field.jg_chance() * 100.0)) + "%")
			txt = txt.replace("<D>", str(snappedf(_field.jg_dmg_mul(), 0.01)))
			txt = txt.replace("<W>", str(snappedf(_field.jg_width(), 0.01)))
			txt = txt.replace("<P>", str(_field.jg_pierce()))
			txt = txt.replace("<S>", str(int(_field.jg_speed())))
			# 飞匕那一套的实时数值
			txt = txt.replace("<DP>", str(_field.dg_pierce()))
			txt = txt.replace("<DD>", str(snappedf(_field.dg_dmg_mul(), 0.01)))
			txt = txt.replace("<DB>", str(_field.dg_bounce()))
			txt = txt.replace("<DM>", str(_field.dg_multi()))
			txt = txt.replace("<DBM>", str(snappedf(_field.dg_bounce_mul(), 0.01)))
			txt = txt.replace("<MD>", str(snappedf(_field.dg_multi_mul(), 0.01)))
			# 天雷那一套
			txt = txt.replace("<TD>", str(snappedf(_field.tl_dmg_mul(), 0.01)))
			txt = txt.replace("<TR>", str(int(_field.tl_radius())))
			txt = txt.replace("<TP>", str(int(_field.tl_para_chance() * 100.0)) + "%")
			txt = txt.replace("<TPD>", str(snappedf(_field.tl_para_dur(), 0.1)))
			txt = txt.replace("<TM>", str(int(_field.tl_multi_chance() * 100.0)) + "%")
			txt = txt.replace("<TMD>", str(snappedf(_field.tl_multi_mul(), 0.01)))
			txt = txt.replace("<TMP>", str(int(_field.tl_mp())))
			txt = txt.replace("<TCD>", str(snappedf(_field.tl_cd(), 0.1)))
			# 回春 / 怒火
			txt = txt.replace("<LH>", str(int(_field.lq_heal() * 100.0)))
			txt = txt.replace("<LP>", str(snappedf(_field.lq_poison_mul(), 0.01)))
			txt = txt.replace("<LPD>", str(snappedf(_field.lq_poison_dur(), 0.1)))
			txt = txt.replace("<LS>", str(_field.lq_spread()))
			txt = txt.replace("<LCD>", str(snappedf(_field.lq_cd(), 0.1)))
			txt = txt.replace("<LMP>", str(int(_field.lq_mp())))
			txt = txt.replace("<JD>", str(snappedf(_field.jc_dmg_mul(), 0.01)))
			txt = txt.replace("<JS>", str(_field.jc_spread()))
			txt = txt.replace("<JB>", str(snappedf(_field.jc_burn_mul(), 0.01)))
			txt = txt.replace("<JCD>", str(snappedf(_field.jc_interval(), 0.1)))
			# 崔三娘·龙王
			txt = txt.replace("<CI>", str(int(_field.cn_inherit() * 100.0)))
			txt = txt.replace("<CS>", str(snappedf(_field.cn_skill_mul(), 0.01)))
			txt = txt.replace("<CR>", str(int(_field.cn_skill_radius())))
			txt = txt.replace("<CM>", str(int(_field.cn_mp())))
			txt = txt.replace("<CC>", str(snappedf(_field.cn_cd(), 0.1)))
			txt = txt.replace("<CL>", str(int(_field.cn_life())))
			# 杀气 / 纳气
			txt = txt.replace("<SBC>", str(snappedf(_field.sb_cd(), 0.1)))
			txt = txt.replace("<SBD>", str(snappedf(_field.sb_dur(), 0.1)))
			txt = txt.replace("<SBA>", str(snappedf(_field.sb_atk_add(), 0.1)))
			txt = txt.replace("<SBM>", str(int(_field.p_mp("duyanbiao"))))
			txt = txt.replace("<KRC>", str(snappedf(_field.kr_cd(), 0.1)))
			txt = txt.replace("<KRD>", str(snappedf(_field.kr_dur(), 0.1)))
			txt = txt.replace("<KRA>", str(int(_field.kr_mp_add())))
			txt = txt.replace("<KRP>", str(int(_field.kr_mp_pct() * 100.0)) + "%")
			# 法度·怒目金刚
			txt = txt.replace("<FDS>", str(int((0.40 + 0.15 * _field.skill_lv("fadu_shield")) * 100.0)))
			txt = txt.replace("<FDB>", str(snappedf(_field.fd_break_mul(), 0.01)))
			txt = txt.replace("<FDP>", str(int(_field.fd_step_pct() * 100.0)))
			txt = txt.replace("<FDR>", str(int(_field.fd_range())))
			txt = txt.replace("<FDD>", str(snappedf(_field.fd_dur(), 0.1)))
			txt = txt.replace("<FDC>", str(snappedf(_field.fd_cd(), 0.1)))
			txt = txt.replace("<FDM>", str(int(_field.p_mp("fadu"))))
			txt = txt.replace("<KRM>", str(int(_field.p_mp("kurong"))))
			txt = txt.replace("<DS>", str(int(_field.dg_interval())))
			txt = txt.replace("**", "")
			ds.text = txt
			ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(ds)
			var an := Label.new()
			an.position = Vector2(12, 236)
			an.size = Vector2(w - 24, 56)
			an.add_theme_font_size_override("font_size", 18)
			an.add_theme_color_override("font_color", DIM)
			an.text = "动作：" + str(e["anim"])
			an.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(an)
			_pbtn(box, "选它", Vector2(26, 288), Vector2(w - 52, 34), 20, mech, _pick_skill.bind(str(e["id"])))
		ly += 344.0
	# 当前招式一览（没技能点时这就是主内容）
	var title := Label.new()
	title.position = Vector2(28, ly)
	title.size = Vector2(640, 44)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", INK)
	title.text = "基础剑法（普攻本体）"
	p.add_child(title)
	ly += 50.0
	var rows := [
		["伤害", "×" + str(snappedf(_field.atk_mul(), 0.01)) + "（伤害提升 " + str(_field.skill_lv("dmg")) + "/5）"],
		["攻速", "×" + str(snappedf(_field.aspd_mul(), 0.01)) + "（攻速提升 " + str(_field.skill_lv("aspd")) + "/5）"],
		["横扫范围", ("无" if _field.splash_radius() <= 0.0 else str(int(_field.splash_radius())) + " 像素") +
			"（溅射 " + str(_field.skill_lv("splash")) + "/5）　被溅到 ×" +
			str(snappedf(_field.splash_mul(), 0.01)) + "（溅射伤害提升 " + str(_field.skill_lv("splash_dmg")) + "/3）"],
		["剑光", ("无（未解锁）" if _field.skill_lv("jg") <= 0 else
			"几率 " + str(int(_field.jg_chance() * 100.0)) + "%　伤害 ×" + str(snappedf(_field.jg_dmg_mul(), 0.01))
			+ "　宽度 ×" + str(snappedf(_field.jg_width(), 0.01))
			+ "　穿透 " + str(_field.jg_pierce()) + "　速度 " + str(int(_field.jg_speed())))],
	]
	for r_v in rows:
		var r: Array = r_v
		var l1 := Label.new()
		l1.position = Vector2(28, ly)
		l1.size = Vector2(150, 44)
		l1.add_theme_font_size_override("font_size", 22)
		l1.add_theme_color_override("font_color", DIM)
		l1.text = str(r[0])
		p.add_child(l1)
		var l2 := Label.new()
		l2.position = Vector2(186, ly)
		l2.size = Vector2(480, 44)
		l2.add_theme_font_size_override("font_size", 22)
		l2.add_theme_color_override("font_color", INK)
		l2.text = str(r[1])
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(l2)
		ly += 52.0
	return ly + 10.0

func _pick_skill(id: String) -> void:
	if _skill_pts <= 0:
		return
	_field.apply_pick(id)
	_skill_pts -= 1
	_skill_choices.clear()
	var nm := id
	for e_v in _field.SKILL_POOL:
		if str((e_v as Dictionary)["id"]) == id:
			nm = str((e_v as Dictionary)["name"])
	Audio.sfx("skill", -5.0)
	_hint.text = "学了「" + nm + "」——招式已经变了，接着打就能看出来"
	_open_large("技能")

# ---- 挑战弹窗：五格（2×3）＋ 底部那颗大开关 ----
func _fill_chal(p: Control, y: float, sz: Vector2) -> float:
	_chal_pop_lbs.clear()
	var w := 318.0
	var h := 152.0
	for i in 5:
		var col := i % 2
		var row := i / 2
		var x := 28.0 + float(col) * (w + 20.0)
		var yy := y + float(row) * (h + 16.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.97, 0.92)
		sb.set_corner_radius_all(12)
		sb.border_color = Color(INK.r, INK.g, INK.b, 0.35)
		sb.set_border_width_all(2)
		var box := Panel.new()
		box.position = Vector2(x, yy)
		box.size = Vector2(w, h)
		box.add_theme_stylebox_override("panel", sb)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(box)
		var nm := Label.new()
		nm.position = Vector2(16, 12)
		nm.size = Vector2(w - 32, 42)
		nm.add_theme_font_size_override("font_size", 26)
		nm.add_theme_color_override("font_color", INK)
		nm.text = str(_chal_names[i])
		box.add_child(nm)
		var ds := Label.new()
		ds.position = Vector2(16, 56)
		ds.size = Vector2(w - 32, 56)
		ds.add_theme_font_size_override("font_size", 20)
		ds.add_theme_color_override("font_color", DIM)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.text = str(_chal_descs[i])
		box.add_child(ds)
		var cd := Label.new()
		cd.position = Vector2(16, 112)
		cd.size = Vector2(w - 32, 34)
		cd.add_theme_font_size_override("font_size", 22)
		cd.text = "就绪"
		cd.add_theme_color_override("font_color", GREEN)
		box.add_child(cd)
		_chal_pop_lbs.append(cd)
		_pbtn(box, "打", Vector2(w - 88.0, 104.0), Vector2(72, 40), 20, true, _chal_press.bind(i))
	var ay := y + 3.0 * (h + 16.0) + 4.0
	_auto_btn = _pbtn(p, "自动挑战：" + ("开（按冷却轮刷）" if _auto_chal else "关"), Vector2(28, ay), Vector2(660, 96), 26, _auto_chal, _toggle_auto_chal)
	var tip := Label.new()
	tip.position = Vector2(28, ay + 104.0)
	tip.size = Vector2(660, 40)
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", DIM)
	# ⚠ 面板里的字**不认 markdown**——写成 **并存** 会原样画出来两个星号（老教训了）
	tip.text = "挑战与当前这一波的怪并存（不是替换）；开了自动就按各自冷却轮着刷。"
	p.add_child(tip)
	return ay + 150.0

# v9a：挑战——连战/招怪套在这里生效：冷却 ×(1−缩减) 、刷怪数 ＋chal_spawn
func _chal_base_cd(i: int) -> float:
	var base: float = float([70.0, 90.0, 90.0, 90.0, 180.0][clampi(i, 0, 4)])
	return base * (1.0 - clampf(float(_extra.get("chal_cd", 0.0)), 0.0, 0.6))

# v9c（用户："挑战怪 文钱/经验/灵晶 boss和宝物是打怪都是群怪"）：
#   五个挑战**都是群刷**——每种一群，招怪/战鼓套再加量
# v9d（用户："文钱/经验/灵晶都是群怪 boss和宝物是大怪"）：
#   0 文钱 / 1 灵晶 / 2 经验 → **群怪**（一群小怪）；3 宝物 / 4 boss → **大怪**（单只打大）
const CHAL_GROUP := [6, 3, 4, 1, 1]        # 群怪：文钱 6 · 灵晶 3 · 经验 4；大怪：宝物 1 · boss 1

func _chal_is_big(i: int) -> bool:
	return i >= 3                          # 宝物 / boss ＝ 大怪

func _chal_spawn_count(i: int) -> int:
	var base: int = int(CHAL_GROUP[clampi(i, 0, 4)])
	var extra := int(_extra.get("chal_spawn", 0.0))
	if _chal_is_big(i):
		return base + (1 if extra > 0 else 0)     # 大怪最多再多一只，不会变刷屏
	return base + extra

# 一群/一只——统一口径给界面用
func _chal_group_total(i: int) -> int:
	return _chal_spawn_count(i)

# 中文口径：大怪说"一只大怪"、群怪说"一群 N 只"
func _chal_amount_cn(i: int) -> String:
	var n := _chal_group_total(i)
	if _chal_is_big(i):
		return "一只大怪" if n <= 1 else (str(n) + " 只大怪")
	return "一群 " + str(n) + " 只"

func _chal_press(i: int) -> void:
	if i >= _chal_cd.size():
		return
	var cd := float(_chal_cd[i])
	if cd > 0.0:
		_hint.text = "「" + str(_chal_names[i]) + "」冷却中（还要 " + str(int(ceil(cd))) + " 秒）"
		return
	_chal_cd[i] = _chal_base_cd(i)
_qc("chal")                       # v13c：任务进度（挑战）
	# 挑战怪的数量（招怪/战鼓套会给更多）
	var n := _chal_spawn_count(i)
	# v9g：把"一群 N 只"交给战场（群怪一群／大怪一只只刷，由战场决定体型与血厚）
	# v9b（用户："去掉装备挑战 换成经验挑战"）：第 3 个挑战＝**经验**——当场给一笔经验
	#   （升级那套逻辑跟击杀走的是同一段，这里只是把经验加进去）
	if i == 2:
		_gain_exp(0.30 * float(n) / 4.0)          # 群刷：按实际只数给经验（基准 4 只）
	if _field != null and _field.has_method("spawn_challenge"):
		_field.spawn_challenge(i, n)
		_hint.text = "「" + str(_chal_names[i]) + "」开了：" + _chal_amount_cn(i) + "（冷却 " + str(int(ceil(float(_chal_cd[i])))) + " 秒）"
	else:
		_hint.text = "「" + str(_chal_names[i]) + "」：" + _chal_amount_cn(i) + "（战场接口下一步接）"
	Audio.sfx("bell", -6.0)
	if _popup_kind == "挑战":
		_open_large("挑战")

func _toggle_auto_chal() -> void:
	_auto_chal = not _auto_chal
	if _auto_btn != null and is_instance_valid(_auto_btn):
		_auto_btn.text = "自动挑战：" + ("开（按冷却轮刷）" if _auto_chal else "关")

# ============================================================
# 通用小件
# ============================================================
func _panel(r: Rect2, col: Color, radius: int) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1, 1, 1, 0.06)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p

func _lbl(pos: Vector2, sz: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _flat(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(12)
	return sb

func _mk_btn(txt: String, pos: Vector2, sz: Vector2, fs: int, seal: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", fs)
	b.focus_mode = Control.FOCUS_NONE
	var c: Color = SEAL if seal else Color(0.26, 0.25, 0.28, 0.98)
	b.add_theme_stylebox_override("normal", _flat(c))
	b.add_theme_stylebox_override("hover", _flat(c.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", _flat(c.darkened(0.15)))
	b.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	b.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	b.pressed.connect(cb)
	add_child(b)
	return b

func _circle_btn(txt: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = pos
	b.size = Vector2(104, 104)
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.26, 0.25, 0.28, 0.98)
	sb.set_corner_radius_all(52)
	sb.border_color = Color(1, 1, 1, 0.10)
	sb.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate() as StyleBoxFlat
	hb.bg_color = Color(0.34, 0.32, 0.36, 0.98)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)
	b.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	b.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	b.pressed.connect(cb)
	add_child(b)
	return b

func _bar(r: Rect2, col: Color) -> ColorRect:
	_panel(Rect2(r.position - Vector2(2, 2), r.size + Vector2(4, 4)), Color(0.10, 0.10, 0.11, 0.9), 8)
	var c := ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = col
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

# ============================================================
# 假数据每帧走一点（看得出"活着"）
# ============================================================
func _process(delta: float) -> void:
	# v10a 打坐：每秒 主属性 +0.02（境界越高倍率越大），攒够 1 点进属性
	if _card_have.has("dazuo_0"):
		_meditate_acc += 0.02 * float(_meditate_mult()) * delta
		if _meditate_acc >= 1.0:
			var add := int(floor(_meditate_acc))
			_meditate_acc -= float(add)
			_grow_card[_main_line()] = int(_grow_card.get(_main_line(), 0)) + add
			_sync_battle_stats()
	_item_tick(delta)           # v12d：消耗型宝物的计时
	_run_time += delta
	_bond_t += delta
	if _bond_t >= 1.0:
		_bond_t = 0.0
		_bond_check()            # v12b：羁绊宝物每秒查一次
	_yh_tick(delta)             # v12a：玲珑玉壶（冷却 ＋ 气血低于 50% 自动用）
	_card_time_tick(delta)      # v11e：时间进化（淬火剑这类）
	_boss_sec -= delta
	if _boss_sec <= 0.0:
		_boss_sec = 60.0
		_wave = mini(_wave_max, _wave + 1)
		# v12c：每过 5 波送 1 次宝物刷新
		if _wave % 5 == 0:
			_trea_refresh += 1
			_hint.text = "宝物刷新 +1（现有 " + str(_trea_refresh) + " 次）"
		_boss_tier = clampi(1 + _wave / 10, 1, 3)
		# v9a：商路/财神套——**每过一波额外给灵晶**（用户："都可"里的经济线）
		var wc := int(_extra.get("wave_crystal", 0.0))
		if wc > 0:
			_crystal += wc
			_hint.text = "商路进账：每波 +" + str(wc) + " 灵晶（现有 " + str(int(_crystal)) + "）"
		_boss_arrive()
	var ready := 0
	for i in _chal_cd.size():
		if float(_chal_cd[i]) > 0.0:
			_chal_cd[i] = maxf(0.0, float(_chal_cd[i]) - delta)
		if float(_chal_cd[i]) <= 0.0:
			ready += 1
	# 圆钮右上角那个小红点：几个能点（原来靠底下那排看，现在挪进弹窗了）
	if _chal_badge != null:
		_chal_badge.text = ("" if ready <= 0 else str(ready))
		_chal_badge.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30) if ready > 0 else Color(0, 0, 0, 0))
	# 弹窗开着的时候，里面那五格的冷却也要跟着跳
	# ⚠ 这里**别写类型标注**（var lb: Label = …）：弹窗一关，那批 Label 就成"已释放实例"，
	#   拿它给带类型的变量赋值会当场报 "assign invalid previously freed instance"（探针刷了一屏）。
	#   现在改成无类型取、逐个 is_instance_valid 判；关窗时还会把数组清空。
	for i in _chal_pop_lbs.size():
		var lb = _chal_pop_lbs[i]
		if lb != null and is_instance_valid(lb):
			var cd := float(_chal_cd[i])
			lb.text = ("就绪" if cd <= 0.0 else "冷却 " + str(int(ceil(cd))) + "s")
			lb.add_theme_color_override("font_color", GREEN if cd <= 0.0 else DIM)
	_wave_lb.text = "波 " + str(_wave) + "/" + str(_wave_max)
	var tier_cn: String = str(["", "一阶", "二阶", "三阶"][clampi(_boss_tier, 1, 3)])
	# v4e：倒计时按"分:秒"走——浴血把 boss 推到 180 秒后，原来那套 "00:180" 就露馅了
	var bs := int(ceil(maxf(0.0, _boss_sec)))
	_boss_lb.text = tier_cn + " boss " + ("%02d:%02d" % [bs / 60, bs % 60])
	_money_lb.text = str(_money)
	_crystal_lb.text = str(_crystal)
	_kill_lb.text = str(_kills)
	_exp_lb.text = "Lv " + str(_lv)
	_exp_bar.size.x = 548.0 * _exp
	# 黑市下面那条小的，跟大条一个数
	if _mini_exp != null:
		_mini_exp.size.x = 178.0 * clampf(float(_bm_exp) / maxf(1.0, float(_bm_need)), 0.0, 1.0)
	if _mini_lv != null:
		_mini_lv.text = "黑市 Lv " + str(_bm_lv) + "　刷新 " + str(_bm_refresh)
	# 每 180 秒送一次黑市刷新
	_bm_t += delta
	if _bm_t >= BM_REFRESH_SEC:
		_bm_t -= BM_REFRESH_SEC
		_bm_refresh += 1
		_hint.text = "黑市刷新 +1（现有 " + str(_bm_refresh) + " 次）"
	# 生命/杀敌都跟战场上那本真账走（v2j）
	if _field != null:
		_hp = float(_field.hero["hp"])
		_hp_max = float(_field.hero["hp_max"])
		_mp = float(_field.hero["mp"])
		_mp_max = float(_field.hero["mp_max"])
	_hp_lb.text = "生命 " + str(int(_hp)) + " / " + str(int(_hp_max))
	_hp_bar.size.x = 470.0 * clampf(_hp / maxf(1.0, _hp_max), 0.0, 1.0)
	_mp_lb.text = "内力 " + str(int(_mp)) + " / " + str(int(_mp_max))
	_mp_bar.size.x = 470.0 * clampf(_mp / maxf(1.0, _mp_max), 0.0, 1.0)
	if _field != null:
		_field.queue_redraw()
	_update_coins(delta)
	# 收钱那一下数字跳一下（用户："然后文钱的数字开始增加"）
	_coin_pop = maxf(0.0, _coin_pop - delta * 1.6)
	_crystal_pop = maxf(0.0, _crystal_pop - delta * 1.6)
	if _money_lb != null:
		_money_lb.pivot_offset = _money_lb.size * 0.5
		var sc2 := 1.0 + _coin_pop * 0.45
		_money_lb.scale = Vector2(sc2, sc2)
	if _crystal_lb != null:
		_crystal_lb.pivot_offset = _crystal_lb.size * 0.5
		var sc3 := 1.0 + _crystal_pop * 0.45
		_crystal_lb.scale = Vector2(sc3, sc3)
	if _skill_badge != null:
		_skill_badge.text = ("＋" if _skill_pts > 0 else "")
	_refresh_band()      # 大弹窗顶部那条状态带每帧跟着走
	_refresh_partner_live()
	# v4e：提醒横幅的倒计时
	if _note_t > 0.0:
		_note_t = maxf(0.0, _note_t - delta)
		if _note_t <= 0.0 and _note_lb != null:
			_note_lb.visible = false
	# 大弹窗的保险②：血 <25% 自动收起
	# ⚠ 但**结算页（局终）不能被这条收掉**——人一死血就是 0（<25%），
	#   上一版这里会把刚弹出来的"局终"立刻关掉，玩的人看到的就是"死了以后卡住没反应"（用户报的 bug）
	if _popup_kind != "" and _popup_kind != "局终" and _is_large(_popup_kind):
		if _hp / maxf(1.0, _hp_max) < 0.25:
			_close_popup()
			_hint.text = "血量告急——大弹窗自动收起了"

func _boss_arrive() -> void:
	if _popup_kind != "" and _is_large(_popup_kind):
		_close_popup()
	# 真叫一只 boss 下来（阶随波数涨）
	_boss_seq += 1
	_field.start_boss(clampi(1 + _boss_seq / 3, 1, 3))
	_hint.text = "boss 入场——顶上那条是它的血条"

# ---- 战场信号 ----
# v4e：给玩家的一条**醒目提醒**（横幅 ＋ 底部提示；横幅 5 秒后自己消失）
var _note_lb: Label = null
var _note_t := 0.0

func _note(txt: String, secs: float) -> void:
	if _note_lb == null:
		_note_lb = _lbl(Vector2(24, 196), Vector2(672, 88), 20, Color(1.0, 0.92, 0.72))
		_note_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_note_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_note_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note_lb.text = txt
	_note_lb.visible = true
	_note_t = secs
	Audio.sfx("tension", -8.0)

func _sync_battle_stats() -> void:
	_wpn_sync()          # v11b：先把成长武器的加成算进 _extra
	if _field == null:
		return
	_field.setup({
		"atk": _atk(),
		"hp_max": _hp_max_total(),
		"mp_max": _mp_max_total(),                             # v4j：够放 300 内力那一发天雷
		"aspd": _aspd_total(),                                 # v5a：身法给攻速
		"crit": 0.05,
		"dodge": 0.05,
		"cut": minf(0.70, 0.10 + _armor_cut()),                # v5a：护甲转减伤（上限 70%）
		"dmg_pct": 0.0,
	})
	# v5a：回血 / 回蓝 / 元素攻击 这三样直接塞进 hero 字典（战场每帧要用）
	_field.hero["hp_regen"] = _hp_regen()
	_field.hero["mp_regen"] = _mp_regen()
	_field.hero["elem_amp"] = _elem_amp() + float(_extra.get("wpn_elem", 0.0))
	# v5f：暴击/暴击伤害（无上限）· 幸运一击（上限 300%）· 全伤害增加与减免 · 各元素抗性/加成
	_field.hero["crit"] = _crit_total()
	_field.hero["crit_dmg"] = _crit_dmg_total()
	_field.hero["lucky"] = _lucky()
	_field.hero["dmg_all"] = _dmg_all()
	_field.hero["cut_all"] = 0.10 + float(_extra.get("cut_all_bonus", 0.0)) + float(_extra.get("wpn_cut", 0.0)) + (0.50 if _tmp_cut > 0.0 else 0.0)
	_field.hero["res_elem"] = _res_elem()
	_field.hero["dmg_elem"] = _dmg_elem()
	_field.hero["dmg_true"] = float(_extra.get("dmg_true", 0.0))   # 只有它能加真实伤害
	_field.hero["thorns"] = float(_extra.get("thorns", 0.0))       # v9f 荆棘/护心镜：挨打反伤
	# v9i 触发型卡（飞羽 / 流星 / 雷霆）——战场每帧读这几个开关
	for k in ["cg_feiyu", "cg_feiyu_pierce", "cg_liuxing", "cg_liuxing_aoe", "cg_leiting", "cg_leiting_para"]:
		_field.hero[k] = float(_extra.get(k, 0.0))
	# 物理那一路的减伤仍旧走 cut（护甲），元素走 res_elem、真实两边都不吃
	_field.hero["cut"] = _armor_cut()

func _on_coin(n: int) -> void:
	_money += n

# ---- 钱币掉落 → 掉地 → 飞右上 → 数字跳（用户点名要的那套）----
#   每枚钱：phase 0＝往下掉（重力＋落地小弹），phase 1＝飞向 HUD 上的钱图标，phase 2＝到了（加钱＋跳字）
var _coinfx: Array = []
var _coin_layer: Control = null
var _coin_pop := 0.0
var _crystal_pop := 0.0

func _on_coin_drop(amount: int, pos: Vector2) -> void:
	_spawn_drop("coin", amount, pos, 14)

# 通用掉落：kind ∈ coin/crystal/gear/treasure；max_n ＝ 最多拆成几枚（视觉热闹度）
func _spawn_drop(kind: String, amount: int, pos: Vector2, max_n: int) -> void:
	var n := clampi(amount, 1, max_n)
	var each := int(maxf(1.0, round(float(amount) / float(n))))
	var base := Vector2(8.0, 176.0) + pos                 # 战场坐标 → 面板坐标
	var tgt := _drop_target(kind)
	for i in n:
		# ⚠ 拆成 n 枚时**余数给最后一枚**——不然 30 文拆 14 枚（每枚 2）只到账 28（探针抓到的）
		var amt: int = each if i < n - 1 else amount - each * (n - 1)
		_coinfx.append({
			"kind": kind,
			"pos": base + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0)),
			"vel": Vector2(randf_range(-90.0, 90.0), randf_range(-190.0, -110.0)),
			"phase": 0, "t": 0.0, "wait": 0.25 + randf() * 0.35,
			"amount": amt, "from": Vector2.ZERO, "target": tgt,
		})
	Audio.sfx("coin" if kind == "coin" else ("bell" if kind == "crystal" else "chest"), -12.0)

# 到手那一下：加账 ＋ 数字跳 ＋ 音效（各类各的）
func _credit_drop(kind: String, n: int) -> void:
	match kind:
		"coin":
			_money += n
			_coin_pop = 0.32
			Audio.sfx("coin", -9.0)
		"crystal":
			_crystal += n
			_crystal_pop = 0.32
			Audio.sfx("bell", -10.0)
		"gear":
			for i in 6:
				if str(_equip[i]) == "":
					_equip[i] = "甲士掉落"
					_equip_q[i] = "良品"
					break
			Audio.sfx("equip", -8.0)
			_hint.text = "装备进包了（去［装备·宝物］看）"
		"treasure":
			_treasures.append("宝箱怪掉落")
			_treasure_q.append("上品")
			Audio.sfx("chest", -8.0)
			_hint.text = "宝物进包了（宝物不限格）"

# 各类掉落的"归宿"：文钱→右上钱图标 · 灵晶→右上晶图标 · 装备/宝物→右下［装备·宝物］钮
func _drop_target(kind: String) -> Vector2:
	if kind == "coin":
		return Vector2(42.0, 130.0)
	if kind == "crystal":
		return Vector2(278.0, 130.0)
	return Vector2(540.0, 1211.0)

func _update_coins(delta: float) -> void:
	if _coinfx.is_empty():
		if _coin_layer != null:
			_coin_layer.queue_redraw()
		return
	var ground := 176.0 + 704.0 - 84.0
	for i in range(_coinfx.size() - 1, -1, -1):
		var c: Dictionary = _coinfx[i]
		c["t"] = float(c["t"]) + delta
		if int(c["phase"]) == 0:
			var p: Vector2 = c["pos"]
			var v: Vector2 = c["vel"]
			v.y += 900.0 * delta
			p += v * delta
			if p.y >= ground:
				p.y = ground
				v.y = -v.y * 0.32                # 落地小弹一下
				v.x *= 0.5
				c["wait"] = float(c["wait"]) - delta
			c["pos"] = p
			c["vel"] = v
			if float(c["t"]) > float(c["wait"]):
				c["phase"] = 1
				c["from"] = p
				c["t"] = 0.0
		elif int(c["phase"]) == 1:
			var k := clampf(float(c["t"]) / 0.5, 0.0, 1.0)
			var f: Vector2 = c["from"]
			var tgt: Vector2 = c["target"]
			# 一条往上兜的弧线（别直愣愣地拉过去）
			var mid := (f + tgt) * 0.5 + Vector2(0.0, -90.0)
			var a := f.lerp(mid, k)
			var b := mid.lerp(tgt, k)
			c["pos"] = a.lerp(b, k)
			if k >= 1.0:
				_credit_drop(str(c["kind"]), int(c["amount"]))
				_coinfx.remove_at(i)
	if _coin_layer != null:
		_coin_layer.queue_redraw()

# v9h（挑战掉落表）：打死挑战怪按类型发奖
#   0 文钱 · 1 灵晶 · 2 经验 · 3 宝物 · 4 boss
func _on_chal_drop(kind_i: int, at: Vector2) -> void:
	match kind_i:
		0:
			var g0 := 40 + randi() % 41
			_money += g0
			# v11f：钱怪另有小概率掉装备
			if randi() % 100 < 12:
				_equip_add(_gen_gear(false, false))
			else:
				_hint.text = "钱怪掉了 " + str(g0) + " 文钱"
		1:
			var g1 := 6 + randi() % 5
			_crystal += g1
			_hint.text = "晶怪掉了 " + str(g1) + " 灵晶"
		2:
			_gain_exp(0.06)
			_hint.text = "书怪：经验 +6%"
		3:
			# v12d：宝物挑战 → 送 1 次宝物刷新 ＋ 开三选一
			_trea_refresh += 1
			_trea_choices.clear()
			_open_large("宝物三选一")
			# v11f：宝物挑战真的爆一件宝物（大怪掉得更好）
			var g3 := _gen_gear(true, true)
			_treasures.append(str(g3["name"]) + "（" + str(WPN_Q_CN[int(g3["q"])]) + "）")
			_hint.text = "宝箱大怪爆出：" + str(g3["name"]) + "【" + str(WPN_Q_CN[int(g3["q"])]) + "】"
			Audio.sfx("chest", -3.0)
		4:
			_trea_refresh += 2            # v12d：boss 首杀送 2 次宝物刷新
			# 名声是"局外"的（跨局保留），这里先记一笔本局战绩
			_run_fame += 20
			_hint.text = "挑战 boss 拿下：本局名声 +20（现在 " + str(_run_fame) + "）"
			Audio.sfx("levelup", -4.0)
	Audio.sfx("coin", -8.0)

func _on_kill(_n: int) -> void:
	_card_evo_tick()          # v10b：杀意按杀敌进化
	# v4b：杀敌数**是可花的钱**（黑市用它换东西），所以这里自己累加、不再每帧从战场回读
	_kills += 1
	# v7b：三条成长线——成套后**每杀一名敌人**给 臂力/身法/悟性 +0.2（本局永久叠加）
	for pair in [["liliang", "arm"], ["tayun", "agi"], ["jingxin", "wit"]]:
		if bool(_sets_done.get(str(pair[0]), false)):
			var key := str(pair[1])
			_grow_kill[key] = float(_grow_kill.get(key, 0.0)) + 0.2
			if _grow_kill[key] >= 1.0:
				var add := int(floor(float(_grow_kill[key])))
				_grow_kill[key] = float(_grow_kill[key]) - float(add)
				_grow_card[key] = int(_grow_card.get(key, 0)) + add
	# v4d：黑市经验 每击杀 +1；攒够就升一级（升级送 1 次刷新）
	_bm_exp += 1
	while _bm_exp >= _bm_need:
		_bm_exp -= _bm_need
		_bm_lv += 1
		_bm_need += 50
		_bm_refresh += 1
		_hint.text = "黑市升到 Lv " + str(_bm_lv) + "，刷新 +1（现有 " + str(_bm_refresh) + " 次）"
		Audio.sfx("levelup", -8.0)
	_gain_exp(0.04)

# v9b：经验入口（击杀 +0.04 ／ 经验挑战 +0.30）——升级、技能点、属性点、招募都在这里
func _gain_exp(amount: float) -> void:
	_exp += amount
	if _exp >= 1.0:
		_exp -= 1.0
		_lv += 1
		_skill_pts += 1                      # v3a：每升 1 级给 1 点技能点
		_attr_pts += 2                       # v5a：再给 2 点属性点（角色页自己分配）
		if _lv % 5 == 0:                     # v6a：每 5 级给一次招募（成长继承）
			_recruit_opens += 1
			_hint.text = "升级！Lv " + str(_lv) + "　招募 +1（第 " + str(_recruit_opens) + " 次，去角色页点［招募］）"
		Audio.sfx("levelup", -6.0)
		_hint.text = "升级！Lv " + str(_lv) + "　技能点 +1（点［技能 ＋］三选一）"
		_sync_battle_stats()

func _on_special(kind: String, n: int, pos: Vector2) -> void:
	# 灵晶 / 装备 / 宝物：跟文钱一个套路——掉地 → 飞向各自的"计数位" → 数字或清单变化
	match kind:
		"crystal":
			_spawn_drop("crystal", 6 + randi() % 5, pos, 6)
			_hint.text = "晶怪掉灵晶——看它飞进右上的灵晶"
		"gear":
			_spawn_drop("gear", 1, pos, 1)
			_hint.text = "甲士掉装备——飞进［装备·宝物］"
		"treasure":
			_spawn_drop("treasure", 1, pos, 1)
			_hint.text = "宝箱怪掉宝物——飞进［装备·宝物］"

func _on_boss(tier: int) -> void:
	_hint.text = ["", "一阶", "二阶", "三阶"][clampi(tier, 1, 3)] + " boss 下场了——打赢有额外名声"

func _on_hero_down() -> void:
	if _revive > 0:
		_revive -= 1
		_grow += 1
		# v4e：浴血＝**清场**（普通怪奖励照给 · 挑战怪算失败 · boss 撤走并 180 秒后再来）
		var res: Dictionary = _field.blood_bath_clear()
		_field.revive()
		_sync_battle_stats()
		var msg := "浴血：免死一次（剩 " + str(_revive) + " 次）· 成长 +1 → " + str(_grow)
		msg += "　｜　场上清空：普通怪 " + str(int(res["normal"])) + " 只奖励照给，挑战怪 " + str(int(res["challenge"])) + " 只算失败"
		if bool(res["boss"]):
			_boss_sec = 180.0                     # 主线 boss：出现时间重置，180 秒后再来
			msg += "　｜　boss 180 秒后再来"
		if int(res["challenge"]) > 0 and _auto_chal:
			_auto_chal = false                    # 解除自动挑战（挑战怪算失败，别让它继续刷）
			if _auto_btn != null and is_instance_valid(_auto_btn):
				_auto_btn.text = "自动挑战：关（浴血后已解除）"
			msg += "　｜　自动挑战已解除"
		_hint.text = msg
		# 提醒玩家：战场中央横幅 ＋ 一声紧张的弦（大弹窗会被这条规则自动收掉）
		_note(msg, 5.0)
	else:
		# v3m（用户："任务失败卡住了"）：免死用尽＝这一局结束——
		#   战场停住 ＋ 弹**失败结算页**（原来只改了一句提示，玩的人就卡在 0 血没去处）
		_over = true
		_field.running = false
		_open_large("局终")

# 临时试玩键
func _input(e: InputEvent) -> void:
	if not visible:
		return
	var ke := e as InputEventKey
	if ke == null or not ke.pressed:
		return
	if ke.keycode == KEY_H:
		_hp = maxf(0.0, _hp - 300.0)
	elif ke.keycode == KEY_B:
		_boss_sec = 0.0
	elif ke.keycode == KEY_ESCAPE:
		if _popup_kind != "":
			_close_popup()
		else:
			close()
	accept_event()

# ============================================================
# 弹窗（两层）
# ============================================================
func _is_large(k: String) -> bool:
	return ["卡组", "技能", "装备", "挑战", "存档", "成就", "角色", "队员", "仓库", "卡牌详情", "局终", "黑市", "招募", "成长武器", "宝物三选一", "图鉴", "任务"].has(k)

func _close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null
	_popup_kind = ""
	_band = null
	_chal_pop_lbs.clear()   # 关窗＝这批 Label 作废，别留在数组里被 _process 摸到
	_auto_btn = null

func _open_small(kind: String) -> void:
	_open_popup(kind, false)

func _open_large(kind: String) -> void:
	_open_popup(kind, true)

func _open_popup(kind: String, large: bool) -> void:
	_close_popup()
	_popup_kind = kind
	var vp := get_viewport_rect().size
	var layer := Control.new()
	layer.size = vp
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	_popup = layer
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, (0.42 if large else 0.18))
	dim.size = vp
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var closer := Button.new()
	closer.position = Vector2.ZERO
	closer.size = vp
	closer.flat = true
	closer.focus_mode = Control.FOCUS_NONE
	closer.add_theme_stylebox_override("normal", _flat(Color(0, 0, 0, 0)))
	closer.add_theme_stylebox_override("hover", _flat(Color(0, 0, 0, 0)))
	closer.add_theme_stylebox_override("pressed", _flat(Color(0, 0, 0, 0)))
	closer.pressed.connect(_close_popup)
	layer.add_child(closer)

	var r: Rect2 = Rect2(16, 300, 688, 640) if not large else Rect2(12, 84, 696, 1104)
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.99)
	sb.set_corner_radius_all(16)
	sb.border_color = Color(SEAL.r, SEAL.g, SEAL.b, 0.55)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	layer.add_child(p)

	var title := Label.new()
	title.position = Vector2(24, 16)
	title.size = Vector2(400, 46)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", INK)
	title.text = kind
	p.add_child(title)
	var xb := Button.new()
	xb.text = "关闭"
	xb.position = Vector2(r.size.x - 156, 12)
	xb.size = Vector2(140, 56)
	xb.add_theme_font_size_override("font_size", 24)
	xb.focus_mode = Control.FOCUS_NONE
	xb.add_theme_stylebox_override("normal", _flat(Color(0.26, 0.25, 0.28, 0.98)))
	xb.add_theme_stylebox_override("hover", _flat(Color(0.34, 0.32, 0.36, 0.98)))
	xb.add_theme_stylebox_override("pressed", _flat(Color(0.20, 0.19, 0.22, 0.98)))
	xb.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	xb.pressed.connect(_close_popup)
	p.add_child(xb)

	var body_y := 76.0
	if large:
		# 保险①：大弹窗顶部固定一条状态带
		var band := Panel.new()
		band.position = Vector2(16, 74)
		band.size = Vector2(r.size.x - 32, 56)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0.16, 0.15, 0.17, 0.96)
		bsb.set_corner_radius_all(10)
		band.add_theme_stylebox_override("panel", bsb)
		p.add_child(band)
		_band = Label.new()
		_band.position = Vector2(16, 12)
		_band.size = Vector2(r.size.x - 64, 34)
		_band.add_theme_font_size_override("font_size", 22)
		_band.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
		band.add_child(_band)
		body_y = 146.0
	# v2e（用户："尽量做到清理明了 内容不够可以做成指尖触碰滑动"）：
	#   正文放进 **ScrollContainer**——头（标题/状态带）与底（关闭）固定，中间一段可以**手指拖着看**。
	#   Godot 的 ScrollContainer 自带触摸拖动（scroll_deadzone 就是这个用的），不用自己写手势。
	#   内容比可视区矮时不会滚（那格被撑满）；比它高就滑。
	var body_h := r.size.y - body_y - 16.0
	var body := ScrollContainer.new()
	body.position = Vector2(6, body_y)
	body.size = Vector2(r.size.x - 12, body_h)
	body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.scroll_deadzone = 8
	p.add_child(body)
	_cp = Control.new()
	_cp.custom_minimum_size = Vector2(r.size.x - 40, body_h)
	_cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_cp)
	var need := _fill_popup(_cp, kind, 0.0, Vector2(r.size.x - 40, 0))
	_cp.custom_minimum_size = Vector2(r.size.x - 40, maxf(need + 12.0, body_h))

# 返回：内容用到的高度（外层拿它撑 ScrollContainer 的滚动区）
func _fill_popup(p: Control, kind: String, y: float, sz: Vector2) -> float:
	# 卡组 / 抽卡这两页**不用文字列表**，直接用格子摆（探针抓到过：长句换行会压到下一行上）
	if kind == "卡组":
		return _fill_cards(p, y, sz)
	if kind == "抽卡":
		return _fill_draw(p, y, sz)
	if kind == "挑战":
		return _fill_chal(p, y, sz)
	if kind == "技能":
		return _fill_skill(p, y, sz)
	if kind == "局终":
		return _fill_over(p, y, sz)
	if kind == "黑市":
		return _fill_black(p, y, sz)
if kind == "任务":
	return _fill_quest(p, y, sz)
	if kind == "招募":
		return _fill_recruit(p, y, sz)
	if kind == "成长武器":
		return _fill_weapon(p, y, sz)
	if kind == "宝物三选一":
		return _fill_trea_pick(p, y, sz)
	if kind == "图鉴":
		return _fill_codex(p, y, sz)
	if kind == "角色":
		# 页签点了要**真的换内容**（探针抓到过：只高亮了页签、内容没换）
		return _fill_mates(p, y, sz) if _role_tab == 1 else _fill_role(p, y, sz)
	if kind == "装备":
		return _fill_equip(p, y, sz)
	if kind == "仓库" or kind == "公共仓库":
		return _fill_vault(p, y, sz, kind)
	var lines: Array = []
	if kind == "设置":
		lines = ["音乐：开", "音效：开", "（这一版只有开关，曲子后补）"]
	elif kind == "羁绊详情":
		var b: Dictionary = BONDS[clampi(_detail_bond, 0, BONDS.size() - 1)]
		var pr := _bond_progress(b)
		var done := bool(_bonds_locked.get(str(b["id"]), false))
		lines = ["『" + str(b["n"]) + "』　【" + str(b["q"]) + "】",
			"条件：" + _bond_cond_cn(b),
			"进度：" + ("已激活（常驻，不会掉）" if done else str(int(pr[0])) + " / " + str(int(pr[1]))),
			"效果：" + str(b["fx"]),
			"激活一次即永久生效，换掉卡也不会失效"]
	elif kind == "装备详情":
		var gi := clampi(_detail_gear, 0, 5)
		var st: Dictionary = _equip_stat[gi] if gi < _equip_stat.size() else {}
		if str(_equip[gi]) == "":
			lines = ["这一格是空的", "来源：宝物三选一 / 挑战 / 装备卡"]
		else:
			var has_stat := not st.is_empty()
			lines = ["『" + str(_equip[gi]) + "』"]
			if has_stat:
				lines.append("加成：攻击 +" + str(int(st.get("atk", 0))) + "　气血 +" + str(int(st.get("hp", 0))))
				lines.append("卖价：" + str(int(st.get("price", 60))) + " 文钱")
			else:
				lines.append("初始装备（无加成）")
				lines.append("卖价：60 文钱")
			lines.append("格子下面有［存］［卖］")
	elif kind == "宝物详情":
		var info: Dictionary = _trea_own.get(_detail_trea, {})
		lines = ["『" + str(_detail_trea) + "』　【" + str(info.get("q", "凡品")) + "】",
			"效果：" + str(info.get("fx", "—")),
			"已有：×" + str(int(info.get("n", 1))) + "（同名宝物效果叠加）",
			"宝物不占装备格；消耗型宝物会进道具栏，点着用"]
	elif kind == "卡牌详情":
		var cid := _detail_card
		var cs := card_set_of(cid)
		var got := 0
		for i in int(cs.get("size", 1)):
			if _card_have.has(card_id(str(cs.get("set", "")), i)):
				got += 1
		lines = ["『" + card_name(cid) + "』　【" + str(cs.get("quality", "")) + "】",
			"单卡属性：" + card_prop(cid),
			"组合（" + str(cs.get("name", "")) + "）：" + str(cs.get("combo", "")),
			"这套进度：" + str(got) + " / " + str(int(cs.get("size", 1)))
				+ ("　（已成型）" if bool(_sets_done.get(str(cs.get("set", "")), false)) else ""),
			"本局规则：凑齐一套 → 给组合效果并把这几张腾出占位（效果常驻）；重复抽到回收 5 灵晶"]
	elif kind == "事件":
		lines = ["牢中事件（三选一 · 4 秒不点自动随机）", "① 捡到钱袋：文钱 +150", "② 灵晶矿：灵晶 +8", "③ 武学残页：随机一张卡 +1 星"]
	elif kind == "抽卡":
		lines = ["抽卡 · 20 灵晶（现有 " + str(_crystal) + "）", "① 技能流 · 凝神（1★）", "② 技能流 · 疾风诀（1★）", "③ 技能流 · 破罡（1★）", "十格满时会先进「替换」模式"]
	elif kind == "卡组合计":
		lines = ["当前流派：技能流（本流派出现率 ×3）", "十格用了 " + str(_deck.size()) + " / 10", "　内力上限 +60　技能冷却 −15%", "　技能伤害 +40%　技能击杀 冷却 −1 秒", "（正式版这里按卡的标签逐条汇总；空壳先写死）"]
	elif kind == "技能":
		lines = ["技能点：3", "　" + "、".join(PackedStringArray(_skills)), "升级消耗：1★→2★ 1 点 · 2★→3★ 2 点 · 3★→4★ 3 点"]
	elif kind == "装备":
		lines = ["装备与宝物（一个入口 · 六格）"]
		lines.append_array(_equips)
	elif kind == "挑战":
		lines = ["六种挑战（与本波怪并存）"]
		for i in 5:
			var cd := float(_chal_cd[i])
			lines.append("　" + str(_chal_names[i]) + "：" + _chal_amount_cn(i) + " · "
				+ ("就绪" if cd <= 0.0 else "冷却 " + str(int(ceil(cd))) + "s"))
	elif kind == "存档":
		lines = ["名声：128（局外 · 跨局保留）", "［开局 +20 灵晶］ 30 名声", "［开局带一张指定流派卡］ 60 名声", "［基础攻 +2］ 80 名声", "［基础血 +40］ 80 名声", "［抽卡 -2 灵晶］ 100 名声", "［事件池多 2 条好事］ 120 名声"]
	elif kind == "成就":
		lines = ["每条 = 条件 + 下一局生效的小效果", "［一局杀 500］ → 下局开局攻 +3", "［不用抽卡通关］ → 名声 +20%", "［30 分钟不浴血］ → 下局血 +10%", "（第一版先 8 条，这里是假数据）"]
	# ⚠ 行高 56、框高 48：留出换行的余地，长句换行也不会压到下一行（用户："字不要小"→不能靠缩字号躲）
	var ly := y
	for s_v in lines:
		var t := str(s_v)
		var fs: int = 22 if t.begins_with("　") else 25
		var l := Label.new()
		l.position = Vector2(28, ly)
		l.size = Vector2(sz.x - 56, 62)
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", INK if fs >= 24 else DIM)
		l.text = t
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.clip_text = true
		p.add_child(l)
		ly += 70.0
	return ly

# ---- 卡组页：流派页签 ＋ **两种查询**（十格 / 吞噬记录）＋ 操作钮 ----
func _fill_cards(p: Control, y: float, sz: Vector2) -> float:
	# 清爽一点（用户："尽量做到清理明了"）：页签只写流派名，当前流派改用一行小字说清
	var tabs := ["技能流", "攻击流", "盾牌流"]
	for i in 3:
		_pbtn(p, tabs[i], Vector2(28.0 + float(i) * 218.0, y), Vector2(206, 62), 24, i == 0, func(): pass)
	var cur := Label.new()
	cur.position = Vector2(28, y + 68.0)
	cur.size = Vector2(640, 30)
	cur.add_theme_font_size_override("font_size", 20)
	cur.add_theme_color_override("font_color", DIM)
	cur.text = "本局流派：技能流（该流派卡出现率 ×3）"
	p.add_child(cur)
	# 两种查询（用户："第一种是10格的卡组 另一种是吞噬后的卡组"）
	var qs := ["十格卡组", "吞噬记录"]
	for i in 2:
		_pbtn(p, qs[i], Vector2(28.0 + float(i) * 162.0, y + 106.0), Vector2(150, 60), 24, _deck_tab == i, _set_deck_tab.bind(i))
	# ⚠ 按钮必须**跟着内容走**：十格放大后写死偏移会压到卡上（截图抓到过）
	var grid_bottom := 0.0
	if _deck_tab == 0:
		grid_bottom = _fill_deck_slots(p, y + 182.0)
	else:
		grid_bottom = _fill_deck_ate(p, y + 182.0)
	var by := maxf(640.0, grid_bottom + 96.0)
	_pbtn(p, "查合计", Vector2(28, by), Vector2(180, 72), 24, false, func(): _open_large("卡组合计"))
	_pbtn(p, "放弃（换 1 次刷新）", Vector2(220, by), Vector2(284, 72), 22, false, func(): pass)
	_pbtn(p, "刷新 5 灵晶", Vector2(516, by), Vector2(152, 72), 22, true, func(): pass)
	return by + 88.0

func _set_deck_tab(i: int) -> void:
	_deck_tab = i
	if _popup_kind == "卡组":
		_open_large("卡组")     # 重开一次＝重画（空壳阶段够用）

# 视图①：十格（5×2）
func _fill_deck_slots(p: Control, y: float) -> float:
	# v7a：十格改成**新卡面**；v8e 放大成竖长卡；v8f 去掉单卡属性（点开看详情）
	while _deck_cards.size() < 10:
		_deck_cards.append("")
	# v8b：手上还捏着一张（十格满）时，每张卡下面挂一颗［换］
	if _pending_card != "":
		var pend := Label.new()
		# ⚠ 原来放在 y-34，正好压着"十格卡组/吞噬记录"那排页签——挪到内容区第一行
		pend.position = Vector2(24, y + 2.0)
		pend.size = Vector2(560, 30)
		pend.add_theme_font_size_override("font_size", 21)
		pend.add_theme_color_override("font_color", SEAL)
		pend.text = "手上： " + card_name(_pending_card) + "　→ 点下面任意一张的［换］把它顶掉（原卡回池）"
		p.add_child(pend)
		_pbtn(p, "放弃这张", Vector2(590, y - 4.0), Vector2(96, 36), 18, false, _drop_pending)
	for i in 10:
		var col := i % 5
		var row := i / 5
		var cx := 24.0 + float(col) * 134.0
		var cy := y + float(row) * 280.0
		_card_face(p, Vector2(cx, cy), Vector2(126, 268), str(_deck_cards[i]))
		# v8c：整格可点 → 看详情
		var hit := _pbtn(p, "", Vector2(cx, cy), Vector2(126, 218 if _pending_card != "" else 260), 16, false, _card_detail.bind(i))
		hit.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.001)))
		hit.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.10)))
		hit.add_theme_stylebox_override("pressed", _flat(Color(1, 1, 1, 0.18)))
		if _pending_card != "" and str(_deck_cards[i]) != "":
			# 按钮占卡片自己让出来的那一条（宽 126−8，高 38，离底 6）
			_pbtn(p, "换这张", Vector2(cx + 4.0, cy + 224.0), Vector2(118, 38), 20, true, _swap_in.bind(i))
			_pbtn(p, "换这张", Vector2(cx + 4.0, cy + 224.0), Vector2(118, 38), 20, true, _swap_in.bind(i))
	# v13a：被吞噬丹吞掉的卡（已腾出格子 · 效果与成套计数都还在）
	if not _bm_eaten.is_empty():
		var names: Array = []
		for id_v in _bm_eaten:
			names.append(card_name(str(id_v)))
		var eat := Label.new()
		eat.position = Vector2(24, y + 566.0)
		eat.size = Vector2(608, 70)
		eat.add_theme_font_size_override("font_size", 20)
		eat.add_theme_color_override("font_color", SEAL)
		eat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eat.text = "吞噬丹吞掉的 " + str(_bm_eaten.size()) + " 张（已腾出格子 · 效果与成套计数仍在）：" + "、".join(PackedStringArray(names))
		p.add_child(eat)
		return y + 646.0
	return y + 560.0
	var tip := Label.new()
	tip.position = Vector2(28, y + 248.0)
	tip.size = Vector2(640, 44)
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", DIM)
	tip.text = "同名卡自动吞噬升星（2/3/5/5）；凑齐一套 → 给组合效果并把这几张**腾出占位**（效果转常驻，卡永久出池）。换掉的卡会回池。".replace("**腾出占位**", "腾出占位")
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(tip)
	return y + 300.0

# 视图②：吞噬记录（每张卡吃了几张 → 现在几星 → 现在什么效果）
func _fill_deck_ate(p: Control, y: float) -> float:
	var ate_sum := 0
	for c_v in _deck:
		ate_sum += int((c_v as Dictionary).get("ate", 0))
	var head := Label.new()
	head.position = Vector2(28, y)
	head.size = Vector2(640, 46)
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", INK)
	head.text = "共吞了 " + str(ate_sum) + " 张（同名卡吃够 2/4/8 张各升一星）"
	p.add_child(head)
	var ly := y + 58.0
	for i in _deck.size():
		var c: Dictionary = _deck[i]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.97, 0.92)
		sb.set_corner_radius_all(10)
		sb.border_color = Color(INK.r, INK.g, INK.b, 0.30)
		sb.set_border_width_all(2)
		var row := Panel.new()
		row.position = Vector2(28, ly)
		row.size = Vector2(640, 84)
		row.add_theme_stylebox_override("panel", sb)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(row)
		var nm := Label.new()
		nm.position = Vector2(18, 8)
		nm.size = Vector2(300, 40)
		nm.add_theme_font_size_override("font_size", 25)
		nm.add_theme_color_override("font_color", INK)
		nm.text = str(c["name"]) + "　" + str(c["star"]) + "★"
		row.add_child(nm)
		var mid := Label.new()
		mid.position = Vector2(18, 48)
		mid.size = Vector2(300, 30)
		mid.add_theme_font_size_override("font_size", 20)
		mid.add_theme_color_override("font_color", DIM)
		mid.text = "已吞 " + str(c["ate"]) + " 张"
		row.add_child(mid)
		var fx := Label.new()
		fx.position = Vector2(330, 22)
		fx.size = Vector2(292, 42)
		fx.add_theme_font_size_override("font_size", 22)
		fx.add_theme_color_override("font_color", SEAL)
		fx.text = str(c["fx"])
		fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(fx)
		ly += 94.0
	return ly

# v8b：把手上那张换进第 i 格——原来那张**回池**（用户："去掉的那张卡肯定回池啊"）
func _swap_in(i: int) -> void:
	if _pending_card == "":
		return
	var old := str(_deck_cards[i]) if i < _deck_cards.size() else ""
	if old != "":
		_card_have.erase(old)                     # 回池：从"已拥有"里划掉，以后还能抽到
		_hint.text = "「" + card_name(old) + "」回池了；「" + card_name(_pending_card) + "」进第 " + str(i + 1) + " 格"
	_deck_cards[i] = _pending_card
	_card_have[_pending_card] = 1
	var new_id := _pending_card
	_pending_card = ""
	Audio.sfx("equip", -6.0)
	_set_check(str(new_id.split("_")[0]))
	_open_large("卡组")

func _drop_pending() -> void:
	if _pending_card == "":
		return
	_hint.text = "「" + card_name(_pending_card) + "」丢回池子了（灵晶不退）"
	_pending_card = ""
	_open_large("卡组")

# v8c：点十格里的卡 → 看详情（单卡属性 / 组合 / 进度）
func _card_detail(idx: int) -> void:
	if idx >= _deck_cards.size() or str(_deck_cards[idx]) == "":
		_hint.text = "这一格是空的"
		return
	_detail_card = str(_deck_cards[idx])
	_open_small("卡牌详情")

func _card_press(idx: int) -> void:
	if idx >= _deck.size():
		_hint.text = "这一格是空的——抽卡抽到新卡才填"
		return
	_hint.text = "选中了「" + str((_deck[idx] as Dictionary)["name"]) + "」（长按看全部效果）"

func _card_long(idx: int) -> void:
	if idx >= _deck.size():
		return
	_card_idx = idx
	_open_large("卡牌详情")

func _slot_box(p: Control, pos: Vector2, sz: Vector2, idx: int) -> void:
	var card := str((_deck[idx] as Dictionary)["name"]) if idx < _deck.size() else ""
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.97, 0.92) if card != "" else Color(0.85, 0.83, 0.79)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(INK.r, INK.g, INK.b, 0.40)
	sb.set_border_width_all(2)
	var pp := Panel.new()
	pp.position = pos
	pp.size = sz
	pp.add_theme_stylebox_override("panel", sb)
	pp.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_child(pp)
	var nm := "空"
	var school := ""
	var star := ""
	if card != "":
		var c: Dictionary = _deck[idx]
		school = str(c["school"])
		nm = str(c["name"])
		star = str(c["star"]) + "★"
	# v2f：卡面**不写流派**（用户："这种是玩家自己发掘的"）——只留名字与星
	var l2 := Label.new()
	l2.position = Vector2(6, 20)
	l2.size = Vector2(sz.x - 12, 46)
	l2.add_theme_font_size_override("font_size", 23)
	l2.add_theme_color_override("font_color", INK if card != "" else DIM)
	l2.text = nm
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pp.add_child(l2)
	var l3 := Label.new()
	l3.position = Vector2(6, 68)
	l3.size = Vector2(sz.x - 12, 30)
	l3.add_theme_font_size_override("font_size", 20)
	l3.add_theme_color_override("font_color", GOLD)
	l3.text = star
	l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pp.add_child(l3)
	# 点击＝选中；**长按＝看这张卡的全部效果**（用户："长按可显示卡牌的全部效果"）
	_press_btn(pp, Vector2(0, 0), sz, _card_press.bind(idx), _card_long.bind(idx))

# ---- 通用小按钮 / 状态带刷新（⚠ 上一版误删过这两个，别再删）----
func _pbtn(parent: Node, txt: String, pos: Vector2, sz: Vector2, fs: int, seal: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", fs)
	b.focus_mode = Control.FOCUS_NONE
	var c: Color = SEAL if seal else Color(0.26, 0.25, 0.28, 0.98)
	b.add_theme_stylebox_override("normal", _flat(c))
	b.add_theme_stylebox_override("hover", _flat(c.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", _flat(c.darkened(0.15)))
	b.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	b.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _refresh_band() -> void:
	if _band == null:
		return
	# ⚠ 上一版这里把"内力"拼了两遍（截图里看到两段一样的）——现在只写一遍
	_band.text = "波 " + str(_wave) + "/" + str(_wave_max) + "　❤ " + str(int(_hp)) + "/" + str(int(_hp_max)) + "　内力 " + str(int(_mp)) + "/" + str(int(_mp_max))

# ---- 角色页：详细属性 ＋ 一颗［队员］钮 ----
func _fill_role(p: Control, y: float, sz: Vector2) -> float:
	var tabs := ["属性", "队员"]
	for i in 2:
		_pbtn(p, tabs[i], Vector2(28.0 + float(i) * 130.0, y), Vector2(120, 58), 24, _role_tab == i, _set_role_tab.bind(i))
	var rows := [
		["攻击", str(int(_atk())) + "（成长 " + str(_grow) + " → 每级 +" + str(_grow) + "）"],
		["气血", str(int(_hp_max_total())) + "（每级 +" + str(_grow * 10) + "）　回复 "
			+ str(snappedf(_hp_regen(), 0.1)) + "/秒"],
		["内力", str(int(_mp_max_total())) + "（回 " + str(snappedf(_mp_regen(), 0.1)) + "/秒）"],
		["暴击", "12%　暴伤 ×2.0"],
		["闪避", "8%"],
		["减伤", str(int((0.10 + _armor_cut()) * 100.0)) + "%（横练 10% ＋ 护甲 " + str(int(_armor_value()))
			+ " → " + str(snappedf(_armor_cut() * 100.0, 0.1)) + "%）"],
		["攻速", str(snappedf(_aspd_total(), 0.01)) + " 次/秒（身法加成）"],
		["等级", "Lv " + str(_lv) + "（经验 " + str(int(_exp * 100.0)) + "%）"],
		["宠物", "白狐（幼年期）· 全属性 +3%"],
		["已继承技能", "、".join(PackedStringArray(_skills))],
	]
	# ---- v5a 主属性区：三条属性 ＋ 主属性切换 ----
	var mtip := Label.new()
	mtip.position = Vector2(28, y + 68.0)
	mtip.size = Vector2(640, 32)
	mtip.add_theme_font_size_override("font_size", 21)
	mtip.add_theme_color_override("font_color", SEAL)
	mtip.text = "属性点 " + str(_attr_pts) + "　主属性：" + _main_attr_cn() \
		+ "　继承成长：臂力 " + str(int(_grow_inherit["arm"])) + " / 身法 " + str(int(_grow_inherit["agi"])) \
		+ " / 悟性 " + str(int(_grow_inherit["wit"]))
	p.add_child(mtip)
	var names := ["力量", "敏捷", "悟性"]
	var ids := ["str", "agi", "wit"]
	for i in 3:
		_pbtn(p, names[i], Vector2(28.0 + float(i) * 138.0, y + 104.0), Vector2(126, 56), 22,
			_main_attr == str(ids[i]), _set_main_attr.bind(str(ids[i])))
	var arows := [
		["arm", "臂力", _attr_arm(), "气血 +" + str(int(12.0 * float(_attr_arm()) * _boost_for("arm")))
			+ "　生命恢复 " + str(snappedf(_hp_regen(), 0.1)) + "/秒"
			+ ("　（主属性 ×1.5）" if _is_main_line("arm") else "")],
		["agi", "身法", _attr_agi(), "攻速 +" + str(int(2.0 * float(_attr_agi()) * _boost_for("agi"))) + "%　护甲 "
			+ str(int(_armor_value())) + "（全局减伤 " + str(snappedf(_armor_cut() * 100.0, 0.1)) + "%）"
			+ ("　（主属性 ×1.5）" if _is_main_line("agi") else "")],
		["wit", "悟性", _attr_wit(), "内力 +" + str(int(20.0 * float(_attr_wit()) * _boost_for("wit")))
			+ "　回蓝 " + str(snappedf(_mp_regen(), 0.1)) + "/秒　元素 +"
			+ str(snappedf(_elem_amp() * 100.0, 0.1)) + "%"
			+ ("（主属性 ×1.5）" if _is_main_line("wit") else "")],
	]
	var aly := y + 172.0
	for r_v in arows:
		var r: Array = r_v
		var l1 := Label.new()
		l1.position = Vector2(28, aly)
		l1.size = Vector2(150, 44)
		l1.add_theme_font_size_override("font_size", 24)
		l1.add_theme_color_override("font_color", INK)
		l1.text = str(r[1]) + " " + str(r[2])
		p.add_child(l1)
		var l2 := Label.new()
		l2.position = Vector2(184, aly + 3.0)
		l2.size = Vector2(370, 40)
		l2.add_theme_font_size_override("font_size", 20)
		l2.add_theme_color_override("font_color", DIM)
		l2.text = str(r[3])
		p.add_child(l2)
		_pbtn(p, "＋", Vector2(500, aly - 4.0), Vector2(76, 52), 26, _attr_pts > 0, _add_attr.bind(str(r[0])))
		if aly == y + 172.0:
			_pbtn(p, "招募 " + str(_recruit_opens), Vector2(586, aly - 4.0), Vector2(82, 52), 20,
				_recruit_opens > 0, func(): _open_large("招募"))
		aly += 60.0
	y = aly + 6.0
	var ly2 := y
	for r2_v in rows:
		var r2: Array = r2_v
		var l3 := Label.new()
		l3.position = Vector2(28, ly2)
		l3.size = Vector2(210, 44)
		l3.add_theme_font_size_override("font_size", 22)
		l3.add_theme_color_override("font_color", DIM)
		l3.text = str(r2[0])
		p.add_child(l3)
		var l4 := Label.new()
		l4.position = Vector2(246, ly2)
		l4.size = Vector2(422, 44)
		l4.add_theme_font_size_override("font_size", 23)
		l4.add_theme_color_override("font_color", INK)
		l4.text = str(r2[1])
		l4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(l4)
		ly2 += 54.0
	var tip := Label.new()
	# ⚠ 这行字比框长会被裁（截图抓到过）——给足高度并允许换行
	tip.position = Vector2(28, ly2 + 8.0)
	tip.size = Vector2(640, 64)
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "主属性＝你主哪条，那条就当攻击（力量/敏捷→攻击 · 悟性→元素），并把它那条的副属性放大 1.5 倍。"
	p.add_child(tip)
	return ly2 + 60.0
	# （旧版属性列表循环已删除——上面那段就是新的）
func _fill_role_old_tail(rows: Array, y: float, p: Control) -> float:
	var ly := y + 74.0
	for r_v in rows:
		var r: Array = r_v
		var l := Label.new()
		l.position = Vector2(28, ly)
		l.size = Vector2(210, 44)
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", DIM)
		l.text = str(r[0])
		p.add_child(l)
		var v := Label.new()
		v.position = Vector2(246, ly)
		v.size = Vector2(422, 44)
		v.add_theme_font_size_override("font_size", 23)
		v.add_theme_color_override("font_color", INK)
		v.text = str(r[1])
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(v)
		ly += 54.0
	var tip := Label.new()
	tip.position = Vector2(28, ly + 8.0)
	tip.size = Vector2(640, 40)
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", DIM)
	tip.text = "队伍上限 3 人；队员不显示在动画里，但成长与技能都并到主角身上。"
	p.add_child(tip)
	return ly + 60.0

func _set_role_tab(i: int) -> void:
	_role_tab = i
	if _popup_kind == "角色":
		_open_large("角色")

# ---- v5a 三条属性的换算（都在这里，改数只改这一处）----
# v6a：实际三属性 ＝ 自己加的点 ＋ **继承来的成长**（招募取最高值）
func _attr_arm() -> int:
	return int(_attr["arm"]) + int(_grow_inherit["arm"]) + int(_grow_card["arm"]) + int(_extra.get("wpn_arm", 0))

func _attr_agi() -> int:
	return int(_attr["agi"]) + int(_grow_inherit["agi"]) + int(_grow_card["agi"]) + int(_extra.get("wpn_agi", 0))

func _attr_wit() -> int:
	return int(_attr["wit"]) + int(_grow_inherit["wit"]) + int(_grow_card["wit"]) + int(_extra.get("wpn_wit", 0))

# 招募：把这位伙伴的三属性成长**逐项取最高**并进来（保证只升不降）
func _recruit(id: String) -> void:
	var info: Dictionary = _field.PARTNER_INFO[id]
	var g: Dictionary = info.get("grow", {})
	var up: Array = []
	var bonus := int(_extra.get("partner_grow", 0.0))     # v7c：同心套给的"招募成长 +1"
	for k in ["arm", "agi", "wit"]:
		var v := int(g.get(k, 0)) + bonus
		if v > int(_grow_inherit[k]):
			_grow_inherit[k] = v
			up.append({"arm": "臂力", "agi": "身法", "wit": "悟性"}[k] + "→" + str(v))
	_field.partners[id]["owned"] = true
	_recruit_opens = maxi(0, _recruit_opens - 1)
	_recruit_choices.clear()
	_sync_battle_stats()
	Audio.sfx("levelup", -4.0)
	_hint.text = "招募了「" + str(info["name"]) + "」" + ("　成长提升：" + "、".join(PackedStringArray(up)) if up.size() > 0 else "　（成长已被更高的顶住，没变）")
	_open_large("招募")

# 臂力：气血 + 生命恢复；主属性＝力量时再给攻击
func _hp_max_total() -> float:
	return 200.0 + float(_grow) * 10.0 * float(maxi(0, _lv - 1)) \
		+ 12.0 * float(_attr_arm()) * _boost_for("arm") + float(_extra.get("hp_flat", 0.0)) + float(_extra.get("gear_hp", 0.0))

func _hp_regen() -> float:
	return 0.4 * float(_attr_arm()) * _boost_for("arm")

# 身法：攻速 + 护甲；主属性＝敏捷时再给攻击
func _aspd_total() -> float:
	var mul := 1.0 + 0.02 * float(_attr_agi()) * _boost_for("agi") + float(_extra.get("aspd_bonus", 0.0)) + float(_extra.get("wpn_aspd", 0.0))
	if _tmp_aspd > 0.0:
		mul += 2.0                     # v12d 疾风符：+200%
	return 1.0 * mul

# v5e（用户："护甲是整体百分比减伤 要少给"）：
#   身法每点 **+1 护甲**（原来 +2），换算也调钝：护甲/(护甲+**120**)（原来 60）
#   ——6 点身法（敏捷主属性）＝9 护甲 ≈ **7%** 全局减伤（原来 23%，太肥了）
func _armor_value() -> float:
	return 1.0 * float(_attr_agi()) * _boost_for("agi")

func _armor_cut() -> float:
	var ar := _armor_value()
	return ar / (ar + 120.0)

# 悟性：内力 + 内力恢复；主属性＝悟性时给元素攻击
func _mp_max_total() -> float:
	return 300.0 + 25.0 * float(maxi(0, _lv - 1)) + 20.0 * float(_attr_wit()) * _boost_for("wit")

func _mp_regen() -> float:
	return 10.0 + 1.2 * float(_attr_wit()) * _boost_for("wit")

# v5c（用户："主属性的意思是 玩家主哪个属性就按照哪个主属性作为攻击 主角三属性都有的"）：
#   主角**三条属性都有**（副属性照常生效）；**主属性**决定"哪条属性当攻击"——
#   力量→臂力当攻击 · 敏捷→身法当攻击 · 悟性→**元素攻击**当攻击；
#   三条**折算系数一致**（每点 1.5）。另外悟性**始终**给 +1%/点 元素（v5b）。
const ATTR_TO_ATK := 1.5
# v5d（用户："主属性会对副属性有一定增幅"）：
#   主属性**把它自己那条的副属性也放大**——力量→臂力的气血/回血 ×1.5、
#   敏捷→身法的攻速/护甲 ×1.5、悟性→悟性的内力/回蓝 ×1.5（另两条不受影响）
const MAIN_BOOST := 1.5

func _main_line() -> String:
	return str({"str": "arm", "agi": "agi", "wit": "wit"}.get(_main_attr, "arm"))

func _boost_for(kind: String) -> float:
	return MAIN_BOOST if kind == _main_line() else 1.0

func _is_main_line(kind: String) -> bool:
	return kind == _main_line()

func _elem_amp() -> float:
	var v := 0.01 * float(_attr_wit())          # 悟性本身：每点 +1% 元素
	if _main_attr == "wit":
		v += 0.015 * float(_attr_wit())          # 主属性＝悟性：再用"攻击"那一份折算成元素
	return v

func _atk() -> float:
	var base := 12.0 + float(_grow) * float(maxi(0, _lv - 1))
	base *= 1.0 + float(_extra.get("atk_all", 0.0))          # v7g：淬锋套给的攻击 %
	base += float(_extra.get("atk_flat", 0.0))              # v11b：成长武器给的固定攻击
	base += float(_extra.get("evo_atk", 0.0))               # v11e：时间进化累积的攻击
	base += float(_extra.get("gear_atk", 0.0))              # v11f：六格装备给的攻击
	if _tmp_atk > 0.0:
		base *= 2.5                    # v12d 狂血丹：+150%
	# 主属性是哪条，就用哪条当攻击（系数统一 1.5）；主属性＝悟性时它的"攻击"是元素（见 _elem_amp）
	match _main_attr:
		"str":
			base += ATTR_TO_ATK * float(_attr_arm())
		"agi":
			base += ATTR_TO_ATK * float(_attr_agi())
	return base

# ---- v5f 暴击 / 幸运 / 元素 / 全伤 ----
#   臂力：每点 +2% 暴击伤害　身法：每点 +0.5% 暴击　悟性：每点 +0.5% 全元素加成
#   幸运一击、各元素抗性、全伤害增减目前由装备/伙伴给（先给 0，接口留着）
func _crit_total() -> float:
	return 0.05 + 0.005 * float(_attr_agi()) + float(_extra.get("crit_add", 0.0)) + float(_extra.get("wpn_crit", 0.0))

func _crit_dmg_total() -> float:
	return 2.0 + 0.02 * float(_attr_arm()) + float(_extra.get("crit_dmg_bonus", 0.0)) + float(_extra.get("wpn_critdmg", 0.0))

func _lucky() -> float:
	return minf(3.0, float(_extra.get("lucky", 0.0)))

func _dmg_all() -> float:
	return float(_extra.get("dmg_all", 0.0))

func _res_elem() -> Dictionary:
	return _extra.get("res_elem", {})

func _dmg_elem() -> Dictionary:
	var d: Dictionary = _extra.get("dmg_elem", {}).duplicate()
	var bonus := 0.005 * float(_attr_wit())
	for k in d.keys():
		d[k] = float(d[k]) + bonus
	return d

func _main_attr_cn() -> String:
	return {"str": "力量", "agi": "敏捷", "wit": "悟性"}.get(_main_attr, "力量")

func _add_attr(id: String) -> void:
	if _attr_pts <= 0:
		return
	_attr_pts -= 1
	_attr[id] = int(_attr[id]) + 1
	_sync_battle_stats()
	Audio.sfx("ui_click", -8.0)
	if _popup_kind == "角色":
		_open_large("角色")

func _set_main_attr(id: String) -> void:
	_main_attr = id
	_sync_battle_stats()
	if _popup_kind == "角色":
		_open_large("角色")

# ---- 伙伴页（v4a）：两位伙伴 ＋ 他们的技能与档位 ----
#   用户在战斗里**自动放**（内力够、不在冷却就放），这一页是看账的地方。
func _fill_mates(p: Control, y: float, sz: Vector2) -> float:
	var tabs := ["属性", "伙伴"]
	for i in 2:
		_pbtn(p, tabs[i], Vector2(28.0 + float(i) * 130.0, y), Vector2(120, 58), 24, _role_tab == i, _set_role_tab.bind(i))
	var owned_n := 0
	for pid in _field.partners.keys():
		if bool((_field.partners[pid] as Dictionary)["owned"]):
			owned_n += 1
	var head := Label.new()
	head.position = Vector2(28, y + 74.0)
	head.size = Vector2(640, 44)
	head.add_theme_font_size_override("font_size", 23)
	head.add_theme_color_override("font_color", INK)
	head.text = "伙伴 " + str(owned_n) + "/" + str(_field.PARTNER_INFO.size()) + " 名入队（每 5 级招募一次 · 每种只能选一次）"
	p.add_child(head)
	_partner_lbs.clear()
	var ly := y + 128.0
	# 伙伴列表**通用遍历**（加人不用改这里）：档位那行也按池子里 req_p 自动拼
	for id in _field.PARTNER_INFO.keys():
		var info: Dictionary = _field.PARTNER_INFO[id]
		var pid := str(id)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.97, 0.92)
		sb.set_corner_radius_all(12)
		# v4t：品质一眼分档——绝品（赤金）> 极品（金）> 上品（紫）> 中品（青）> 下品（灰）
		var qcol := Color(INK.r, INK.g, INK.b, 0.35)
		var qw := 2
		match str(info["quality"]):
			"绝品":
				qcol = Color(0.86, 0.44, 0.24, 0.9)
				qw = 3
			"极品":
				qcol = Color(0.86, 0.68, 0.26, 0.9)
				qw = 3
			"上品":
				qcol = Color(0.52, 0.34, 0.72, 0.85)
				qw = 3
			"中品":
				qcol = Color(0.30, 0.58, 0.72, 0.8)
				qw = 2
		sb.border_color = qcol
		sb.set_border_width_all(qw)
		var box := Panel.new()
		box.position = Vector2(28, ly)
		box.size = Vector2(640, 210)
		box.add_theme_stylebox_override("panel", sb)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(box)
		var nm := Label.new()
		nm.position = Vector2(18, 12)
		nm.size = Vector2(420, 42)
		nm.add_theme_font_size_override("font_size", 26)
		nm.add_theme_color_override("font_color", INK)
		nm.text = str(info["name"]) + "　【" + str(info["quality"]) + "】　技能「" + str(info["skill"]) + "」"
		box.add_child(nm)
		var live := Label.new()
		live.position = Vector2(430, 14)
		live.size = Vector2(196, 40)
		live.add_theme_font_size_override("font_size", 20)
		live.add_theme_color_override("font_color", SEAL)
		live.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		live.text = ("" if bool((_field.partners[pid] as Dictionary)["owned"]) else "未入队")
		if not bool((_field.partners[pid] as Dictionary)["owned"]):
			live.add_theme_color_override("font_color", DIM)
		box.add_child(live)
		_partner_lbs.append([pid, live])
		var st := Label.new()
		st.position = Vector2(18, 58)
		st.size = Vector2(600, 34)
		st.add_theme_font_size_override("font_size", 21)
		st.add_theme_color_override("font_color", DIM)
		var dt := str(info.get("dtype", ""))
		st.text = ("伤害：" + dt + "　" if dt != "" else "")
		if pid == "jicanghai":
			st.text += "每隔 " + str(snappedf(_field.jc_interval(), 0.1)) + " 秒自动烧一次"
		elif pid == "suqingluan":
			st.text += "每隔 " + str(snappedf(_field.dg_interval(), 0.1)) + " 秒出一枚"
		elif float(info["mp0"]) <= 0.0:
			st.text += "自动"
		elif str(pid) == "liuqingqing":
			st.text += "内力 " + str(int(_field.lq_mp())) + "　冷却 " + str(snappedf(_field.lq_cd(), 0.1)) + " 秒"
		elif str(pid) == "zhangdaoling":
			st.text += "内力 " + str(int(_field.tl_mp())) + "　冷却 " + str(snappedf(_field.tl_cd(), 0.1)) + " 秒"
		elif str(pid) == "cuisanniang":
			st.text += "内力 " + str(int(_field.cn_mp())) + "　冷却 " + str(snappedf(_field.cn_cd(), 0.1))
			st.text += " 秒　场上 " + str(_field._minions.size()) + " 条"
			st.text += "　（蛟龙活 " + str(int(_field.cn_life())) + " 秒、会被打掉）"
		else:
			st.text += "内力 " + str(int(_field.p_mp(pid))) + "　持续 " + str(int(_field.p_dur(pid))) + " 秒　冷却 " + str(int(_field.p_cd(pid))) + " 秒"
		box.add_child(st)
		var ds := Label.new()
		ds.position = Vector2(18, 96)
		ds.size = Vector2(600, 62)
		ds.add_theme_font_size_override("font_size", 20)
		ds.add_theme_color_override("font_color", INK)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# ⚠ 面板里的字不认 markdown：描述里写 **传火** 会原样画出星号——统一清一遍
		ds.text = str(info["desc"]).replace("**", "")
		box.add_child(ds)
		# ⚠ 档位那行会很长（飞匕有七项）——给足高度并允许换行，不然会被裁掉半个字（截图抓到过）
		var lv := Label.new()
		lv.position = Vector2(18, 156)
		lv.size = Vector2(604, 52)
		lv.add_theme_font_size_override("font_size", 19)
		lv.add_theme_color_override("font_color", DIM)
		lv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var parts: Array = []
		for pk_v in _field.SKILL_POOL:
			var pk: Dictionary = pk_v
			if str(pk.get("req_p", "")) != pid:
				continue
			var nmv: String = str(pk["name"])
			var nm2: String = nmv.split("·")[1] if nmv.contains("·") else nmv
			parts.append(nm2 + " " + str(_field.skill_lv(str(pk["id"]))))
		lv.text = ("档位：" + "／".join(PackedStringArray(parts))) if parts.size() > 0 else "档位：还没强化过"
		box.add_child(lv)
		ly += 222.0
	var tip := Label.new()
	tip.position = Vector2(28, ly)
	tip.size = Vector2(640, 44)
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "战斗里内力每秒回 2；伙伴的强化项在升级三选一里出现（都自带内力消耗提升的代价）。"
	p.add_child(tip)
	return ly + 56.0

func _refresh_partner_live() -> void:
	if _popup_kind != "伙伴" and _popup_kind != "角色":
		return
	if _field == null:
		return
	for e_v in _partner_lbs:
		var e: Array = e_v
		var lb = e[1]
		if lb == null or not is_instance_valid(lb):
			continue
		var pid := str(e[0])
		var p: Dictionary = _field.partners[pid]
		if _field.p_active(pid):
			lb.text = "释放中"
			lb.add_theme_color_override("font_color", Color(0.42, 0.66, 0.36))
		elif float(p["cd"]) > 0.0:
			lb.text = "冷却 " + str(int(ceil(float(p["cd"])))) + "s"
			lb.add_theme_color_override("font_color", DIM)
		else:
			lb.text = "待机"
			lb.add_theme_color_override("font_color", SEAL)
# ---- 旧版队友页（假数据；v4a 起被"伙伴页"取代，**留着当参照**，别再往外调）----
func _fill_mates_old(p: Control, y: float, sz: Vector2) -> float:
	var tabs := ["属性", "队员"]
	for i in 2:
		_pbtn(p, tabs[i], Vector2(28.0 + float(i) * 130.0, y), Vector2(120, 58), 24, _role_tab == i, _set_role_tab.bind(i))
	var head := Label.new()
	head.position = Vector2(28, y + 74.0)
	head.size = Vector2(640, 46)
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", INK)
	head.text = "已继承 " + str(_mates.size()) + " 名队友（等级每 +5 给一次招募机会）"
	p.add_child(head)
	var ly := y + 132.0
	for i in _mates.size():
		var m: Dictionary = _mates[i]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.97, 0.92)
		sb.set_corner_radius_all(10)
		sb.border_color = Color(INK.r, INK.g, INK.b, 0.30)
		sb.set_border_width_all(2)
		var row := Panel.new()
		row.position = Vector2(28, ly)
		row.size = Vector2(640, 104)
		row.add_theme_stylebox_override("panel", sb)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(row)
		var nm := Label.new()
		nm.position = Vector2(18, 10)
		nm.size = Vector2(360, 42)
		nm.add_theme_font_size_override("font_size", 26)
		nm.add_theme_color_override("font_color", INK)
		nm.text = str(m["name"])
		row.add_child(nm)
		var sk: Array = m["skills"]
		var sub := Label.new()
		sub.position = Vector2(18, 56)
		sub.size = Vector2(420, 36)
		sub.add_theme_font_size_override("font_size", 21)
		sub.add_theme_color_override("font_color", DIM)
		sub.text = "携带技能：" + "、".join(PackedStringArray(sk))
		row.add_child(sub)
		# ⚠ 「成长 N」原来落在 430..620、跟右上那颗［看］(556..626) 叠着——往左收
		var gr := Label.new()
		gr.position = Vector2(380, 22)
		gr.size = Vector2(166, 46)
		gr.add_theme_font_size_override("font_size", 24)
		gr.add_theme_color_override("font_color", SEAL)
		gr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		gr.text = "成长 " + str(m["grow"])
		row.add_child(gr)
		# 点这一行：看这一位的成长与技能（照旧点开看详情）
		_pbtn(row, "看", Vector2(556, 32), Vector2(70, 40), 20, false, func(): pass)
		ly += 116.0
	return ly + 12.0

# ---- 装备 / 宝物页 ----
#   装备**最多六格**（3×2）· 宝物**不限**（滚动区接着长）· 两颗入口钮：仓库 / 公共仓库
#   规则（用户）：点击看详情；**长按拿起来**，再点目标格/仓库放下（触屏上的"拖拽"就这么做）
func _fill_equip(p: Control, y: float, sz: Vector2) -> float:
	# v2l（用户拍板）：装备＝**自由六格**（不分部位）
	var tabs := ["装备（自由 6 格）", "宝物（不限）"]
	for i in 2:
		_pbtn(p, tabs[i], Vector2(28.0 + float(i) * 190.0, y), Vector2(178, 60), 23, _equip_tab == i, _set_equip_tab.bind(i))
	var ly := y + 74.0
	if _equip_tab == 0:
		# v12f（用户："装备那边也是"）：跟卡组/宝物一套——紧凑格子（126×98，5 个一行）
		#   ⚠ 上一版把［存］［卖］画在了 if 外面，结果压到宝物页上（截图抓到过）——现在收回这一支里
		for i in 6:
			var col := i % 5
			var row := i / 5
			var bx2 := 24.0 + float(col) * 134.0
			var by3 := ly + float(row) * 152.0
			_gear_box(p, Vector2(bx2, by3), Vector2(126, 98), "equip", i)
			# v12g：整格可点 → 装备详情（说明都在详情页，格子上只留名字与品质）
			var ghit := _pbtn(p, "", Vector2(bx2, by3), Vector2(126, 96), 16, false, _gear_detail.bind(i))
			ghit.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.001)))
			ghit.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.10)))
			if str(_equip[i]) != "":
				_pbtn(p, "存", Vector2(bx2, by3 + 100.0), Vector2(58, 34), 17, false, _gear_to_vault.bind(i))
				_pbtn(p, "卖", Vector2(bx2 + 66.0, by3 + 100.0), Vector2(58, 34), 17, true, _gear_sell.bind(false, i))
		ly += 284.0
	else:
		# v12e：宝物页照卡组那套——紧凑格子（名字＋品质色＋×数量）· 点击详情 · 可滑动
		ly = _fill_trea_list(p, ly, sz)
	ly += 12.0
	# v11c：成长武器入口（自带那一件，无限强化）
	_pbtn(p, "成长武器 ＋" + str(_wpn_lv) + "（" + str(WPN_Q_CN[_wpn_q]) + "）", Vector2(28, ly), Vector2(640, 80), 26, true,
		func(): _open_large("成长武器"))
	ly += 92.0
	# v12f：旧的"每格两颗小钮"循环**已删**——它画在 if 外面，会跑到宝物页上压住格子（截图抓到过）。
	#   现在的［存］［卖］在装备那一支里、跟着每个格子画。
	# v12c：宝物三选一入口
	_pbtn(p, "宝物三选一（刷新 " + str(_trea_refresh) + " 次）", Vector2(240, ly), Vector2(428, 76), 23, true,
		func(): _open_large("宝物三选一"))
	_pbtn(p, "仓库", Vector2(28, ly), Vector2(200, 76), 24, false, func(): _open_large("仓库"))
	_pbtn(p, "公共仓库（暂不开放）", Vector2(240, ly), Vector2(300, 76), 21, false, func(): _open_large("公共仓库"))
	var tip := Label.new()
	tip.position = Vector2(28, ly + 86.0)
	tip.size = Vector2(640, 44)
	tip.add_theme_font_size_override("font_size", 21)
	tip.add_theme_color_override("font_color", DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "点格子看详情；每格下面［存］［卖］"
	# v12j（用户："不要留太多空白"）：把装备页下半屏用起来——成长武器摘要 ＋ 六格加成合计
	var sy := ly + 88.0
	var wsum := Label.new()
	wsum.position = Vector2(24, sy)
	wsum.size = Vector2(640, 40)
	wsum.add_theme_font_size_override("font_size", 24)
	wsum.add_theme_color_override("font_color", _quality_color(str(WPN_Q_CN[_wpn_q])))
	wsum.text = "成长武器 ＋" + str(_wpn_lv) + "　【" + str(WPN_Q_CN[_wpn_q]) + "】"
	p.add_child(wsum)
	var wsub := Label.new()
	wsub.position = Vector2(24, sy + 42.0)
	wsub.size = Vector2(640, 34)
	wsub.add_theme_font_size_override("font_size", 21)
	wsub.add_theme_color_override("font_color", INK)
	wsub.text = "每级：攻击 +" + str(_wpn_flat_atk()) + "　气血 +" + str(_wpn_flat_hp())
	p.add_child(wsub)
	var wline := Label.new()
	wline.position = Vector2(24, sy + 78.0)
	wline.size = Vector2(640, 66)
	wline.add_theme_font_size_override("font_size", 20)
	wline.add_theme_color_override("font_color", SEAL)
	wline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _wpn_lines.is_empty():
		wline.text = "已选强化线：还没有（每 10 级进阶时选一条）"
	else:
		var wparts := []
		for it_v in _wpn_lines:
			var it: Dictionary = it_v
			wparts.append(str(it["n"]) + "（" + str(WPN_Q_CN[int(it["q"])]) + "）")
		wline.text = "已选 " + str(_wpn_lines.size()) + " 条：" + "、".join(PackedStringArray(wparts))
	p.add_child(wline)
	var gsum := Label.new()
	gsum.position = Vector2(24, sy + 150.0)
	gsum.size = Vector2(640, 34)
	gsum.add_theme_font_size_override("font_size", 21)
	gsum.add_theme_color_override("font_color", INK)
	gsum.text = "六格加成合计：攻击 +" + str(int(_extra.get("gear_atk", 0))) + "　气血 +" + str(int(_extra.get("gear_hp", 0)))
	p.add_child(gsum)
	return sy + 210.0

	p.add_child(tip)
	return ly + 146.0

func _set_equip_tab(i: int) -> void:
	_equip_tab = i
	if _popup_kind == "装备":
		_open_large("装备")

# 一格装备/宝物/仓库件（点击看详情 · 长按拿起来/放下）
func _gear_box(p: Control, pos: Vector2, sz: Vector2, src: String, idx: int) -> void:
	var nm := ""
	var q := ""
	if src == "equip":
		nm = str(_equip[idx])
		q = str(_equip_q[idx])
	elif src == "treasure":
		nm = str(_treasures[idx]) if idx < _treasures.size() else ""
		q = str(_treasure_q[idx]) if idx < _treasure_q.size() else ""
	else:
		nm = str(_vault[idx]) if idx < _vault.size() else ""
		q = str(_vault_q[idx]) if idx < _vault_q.size() else ""
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.97, 0.92) if nm != "" else Color(0.85, 0.83, 0.79)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(SEAL.r, SEAL.g, SEAL.b, 0.8) if _carry == (src + ":" + str(idx)) else Color(INK.r, INK.g, INK.b, 0.35)
	sb.set_border_width_all(3 if _carry == (src + ":" + str(idx)) else 2)
	var box := Panel.new()
	box.position = pos
	box.size = sz
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_child(box)
	var l1 := Label.new()
	l1.position = Vector2(10, 26)
	l1.size = Vector2(sz.x - 20, 44)
	l1.add_theme_font_size_override("font_size", 23)
	l1.add_theme_color_override("font_color", INK if nm != "" else DIM)
	l1.text = nm if nm != "" else "空"
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l1)
	var l2 := Label.new()
	l2.position = Vector2(10, 74)
	l2.size = Vector2(sz.x - 20, 32)
	l2.add_theme_font_size_override("font_size", 19)
	l2.add_theme_color_override("font_color", GOLD)
	l2.text = q
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l2)
	var b := _press_btn(box, Vector2(0, 0), sz, _gear_press.bind(src, idx), _gear_long.bind(src, idx))

func _gear_press(src: String, idx: int) -> void:
	# 手上有东西 → 这一下是"放下"；手上空 → 这一下是"看详情"
	if _carry != "":
		var from := _carry
		_carry = ""
		_hint.text = "把「" + from + "」放到了 " + src + " 第 " + str(idx + 1) + " 格（空壳只演示动作，真存取第 2 步接）"
		if _popup_kind == "装备":
			_open_large("装备")
		elif _popup_kind == "仓库":
			_open_large("仓库")
		return
	_hint.text = "查看了 " + src + " 第 " + str(idx + 1) + " 格的详情（空壳只回一句）"

func _gear_long(src: String, idx: int) -> void:
	var nm := ""
	if src == "equip":
		nm = str(_equip[idx])
	elif src == "treasure":
		nm = str(_treasures[idx]) if idx < _treasures.size() else ""
	else:
		nm = str(_vault[idx]) if idx < _vault.size() else ""
	if nm == "":
		_hint.text = "这一格是空的——长按要对着有东西的那格"
		return
	_carry = src + ":" + str(idx)
	_hint.text = "拿起了「" + nm + "」——再点一个格子或［仓库］放下"
	if _popup_kind == "装备":
		_open_large("装备")
	elif _popup_kind == "仓库":
		_open_large("仓库")

# ---- 仓库 / 公共仓库 ----
func _fill_vault(p: Control, y: float, sz: Vector2, kind: String) -> float:
	var head := Label.new()
	head.position = Vector2(28, y)
	head.size = Vector2(640, 46)
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", INK)
	head.text = ("仓库存货 " + str(_vault.size()) + " 件（点击看详情 · 长按拿起来）" if kind == "仓库" else "玩家共享联网——暂不开放")
	p.add_child(head)
	var ly := y + 56.0
	if kind == "仓库":
		for i in _vault.size():
			var col := i % 3
			var row := i / 3
			_gear_box(p, Vector2(28.0 + float(col) * 216.0, ly + float(row) * 132.0), Vector2(200, 120), "vault", i)
		ly += 132.0 * float(1 + _vault.size() / 3)
		_pbtn(p, "回装备页", Vector2(28, ly + 8.0), Vector2(220, 76), 24, false, func(): _open_large("装备"))
		ly += 96.0
	else:
		var tip := Label.new()
		tip.position = Vector2(28, ly + 10.0)
		tip.size = Vector2(640, 120)
		tip.add_theme_font_size_override("font_size", 22)
		tip.add_theme_color_override("font_color", DIM)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.text = "公共仓库要联网（几台机器共享同一份存货）——这一版先占位，等联机那一批一起开。"
		p.add_child(tip)
		ly += 140.0
		_pbtn(p, "回装备页", Vector2(28, ly), Vector2(220, 76), 24, false, func(): _open_large("装备"))
		ly += 96.0
	return ly

# ---- 长按（0.45 秒）＋ 单击：触屏上"长按拿起"就靠这一对回调 ----
var _lp_timer: Timer = null
var _lp_cb: Callable = Callable()
var _lp_fired := false

func _press_btn(parent: Node, pos: Vector2, sz: Vector2, on_press: Callable, on_long: Callable) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.03)))
	b.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.10)))
	b.add_theme_stylebox_override("pressed", _flat(Color(1, 1, 1, 0.16)))
	b.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	b.button_down.connect(_lp_start.bind(on_long))
	b.button_up.connect(_lp_up.bind(on_press))
	b.mouse_exited.connect(_lp_stop)
	parent.add_child(b)
	return b

func _lp_start(cb: Callable) -> void:
	if _lp_timer == null:
		_lp_timer = Timer.new()
		_lp_timer.one_shot = true
		_lp_timer.wait_time = 0.45
		_lp_timer.timeout.connect(_lp_fire)
		add_child(_lp_timer)
	_lp_cb = cb
	_lp_fired = false
	_lp_timer.start()

func _lp_fire() -> void:
	_lp_fired = true
	if _lp_cb.is_valid():
		_lp_cb.call()

func _lp_up(on_press: Callable) -> void:
	_lp_stop()
	if not _lp_fired and on_press.is_valid():
		on_press.call()

func _lp_stop() -> void:
	if _lp_timer != null:
		_lp_timer.stop()

# ============================================================
# 战场画面（简笔小人 · 假打）
# ============================================================
# v2c（用户："人物动画 主角应该在下面 怪物从上面过来 形成对立"）：
#   战场改成**上下对立**——主角压在下面（武器朝上）、怪从上面涌下来（武器朝下），
#   中间留出对峙的空档；血条挂在每只怪的头顶。
class FieldArt extends Control:
	var t := 0.0
	func _process(d: float) -> void:
		t += d
	func _draw() -> void:
		var w := size.x
		var h := size.y
		# 上：怪的来路（淡色带）｜下：主角站的地（淡色带）
		draw_rect(Rect2(0, 0, w, 46), Color(1, 1, 1, 0.030))
		draw_rect(Rect2(0, h - 84.0, w, 84), Color(1, 1, 1, 0.045))
		draw_line(Vector2(24, h - 84.0), Vector2(w - 24, h - 84.0), Color(1, 1, 1, 0.06), 2.0)
		# 主角：**在下面**，朝上（x 往右挪一点，给宠物留位置——左缘 22..126 是圆钮列）
		var hx := 268.0
		var hy := h - 96.0
		_stick(Vector2(hx, hy + sin(t * 4.0) * 3.0), 1.35, Color(0.94, 0.92, 0.86), true)
		# 宠物：画成一只**小兽**（身体＋头＋耳＋尾＋腿）——原来只点一个小圆，根本看不出来
		#   （用户："宠物没有显示"）
		var px := hx - 96.0
		var py := hy + 26.0
		var pc := Color(0.87, 0.85, 0.79)
		draw_circle(Vector2(px, py), 16.0, pc)
		draw_circle(Vector2(px - 18.0, py - 14.0), 11.0, pc)
		draw_colored_polygon(PackedVector2Array([
			Vector2(px - 26.0, py - 22.0), Vector2(px - 19.0, py - 32.0), Vector2(px - 13.0, py - 21.0)]), pc)
		draw_line(Vector2(px + 14.0, py - 4.0), Vector2(px + 32.0, py - 18.0), pc, 4.0)
		draw_line(Vector2(px - 7.0, py + 13.0), Vector2(px - 7.0, py + 24.0), pc, 4.0)
		draw_line(Vector2(px + 9.0, py + 13.0), Vector2(px + 9.0, py + 24.0), pc, 4.0)
		draw_circle(Vector2(px - 22.0, py - 16.0), 2.2, Color(0.20, 0.19, 0.20))
		# 怪：从上往下压（三排，微微上下"逼近"＋左右摆）——武器朝下，与主角对着
		for i in 12:
			var col := i % 4
			var row := i / 4
			var ex := 172.0 + float(col) * 106.0 + sin(t * 1.6 + float(i)) * 7.0
			var ey := 108.0 + float(row) * 112.0 + sin(t * 2.2 + float(i) * 0.7) * 5.0
			_stick(Vector2(ex, ey), 0.86, Color(0.66, 0.62, 0.60), false)
			draw_rect(Rect2(ex - 22.0, ey - 56.0, 44.0, 5.0), Color(0.30, 0.28, 0.30))
			draw_rect(Rect2(ex - 22.0, ey - 56.0, 44.0 * (0.35 + 0.2 * float(i % 3)), 5.0), Color(0.62, 0.30, 0.28))
	# up=true：武器朝上（主角）／false：朝下（怪）——"谁对着谁"一眼看出来
	func _stick(c: Vector2, s: float, col: Color, up: bool) -> void:
		var w := 3.0 * s
		var d := -1.0 if up else 1.0
		draw_circle(c + Vector2(0, -34.0 * s), 9.0 * s, col)
		draw_line(c + Vector2(0, -25.0 * s), c + Vector2(0, 6.0 * s), col, w)
		draw_line(c + Vector2(0, -18.0 * s), c + Vector2(-13.0 * s, -2.0 * s), col, w)
		draw_line(c + Vector2(0, -18.0 * s), c + Vector2(14.0 * s, -26.0 * s * (1.0 if up else 1.0)), col, w)
		draw_line(c + Vector2(0, 6.0 * s), c + Vector2(-9.0 * s, 26.0 * s), col, w)
		draw_line(c + Vector2(0, 6.0 * s), c + Vector2(9.0 * s, 26.0 * s), col, w)
		# 手上那把：朝上或朝下
		draw_line(c + Vector2(14.0 * s, -10.0 * s), c + Vector2(20.0 * s, -10.0 * s + d * 42.0 * s), Color(0.85, 0.84, 0.80), w)

# 钱币飞行层（v2m）：把"掉在地上的钱 → 飞向右上文钱"画在所有面板之上
class CoinLayer extends Control:
	var host = null
	func _draw() -> void:
		if host == null:
			return
		for c_v in host._coinfx:
			var c: Dictionary = c_v
			var p: Vector2 = c["pos"]
			var sc := 1.0 if int(c["phase"]) == 0 else 0.85
			match str(c["kind"]):
				"crystal":
					var r := 11.0 * sc
					var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.66, 0),
						p + Vector2(0, r), p + Vector2(-r * 0.66, 0)])
					draw_colored_polygon(pts, Color(0.42, 0.62, 0.78))
					draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.20, 0.38, 0.56), 2.5)
				"gear", "treasure":
					# 装备/宝物：一只小箱子（宝物描金边）
					var w2 := 15.0 * sc
					draw_rect(Rect2(p.x - w2, p.y - w2 * 0.8, w2 * 2.0, w2 * 1.6), Color(0.55, 0.38, 0.22))
					draw_rect(Rect2(p.x - w2, p.y - w2 * 0.8, w2 * 2.0, w2 * 1.6),
						Color(0.88, 0.72, 0.30) if str(c["kind"]) == "treasure" else Color(0.34, 0.32, 0.30), false, 2.5)
				_:
					# 同一套铜钱画法（外圆内方）
					draw_circle(p, 10.0 * sc, Color(0.90, 0.74, 0.30))
					draw_circle(p, 10.0 * sc, Color(0.55, 0.42, 0.15), false, 2.0)
					draw_rect(Rect2(p.x - 3.2 * sc, p.y - 3.2 * sc, 6.4 * sc, 6.4 * sc), Color(0.55, 0.42, 0.15), false, 2.0)

# 货币/杀敌图标（画出来的：铜钱 · 六棱晶 · 交叉小刀）
class IconArt extends Control:
	var kind := "coin"
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		if kind == "coin":
			draw_circle(c, 15.0, Color(0.90, 0.90, 0.92))
			draw_circle(c, 15.0, Color(0.42, 0.42, 0.50, 0.9), false, 2.5)
			draw_rect(Rect2(c.x - 5.0, c.y - 5.0, 10.0, 10.0), Color(0.42, 0.42, 0.50, 0.9), false, 2.5)
		elif kind == "crystal":
			var pts := PackedVector2Array([c + Vector2(0, -17), c + Vector2(12, 0), c + Vector2(0, 17), c + Vector2(-12, 0)])
			draw_colored_polygon(pts, Color(0.42, 0.62, 0.78))
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.22, 0.40, 0.56), 2.0)
			draw_line(c + Vector2(-6, -3), c + Vector2(0, -12), Color(0.82, 0.92, 0.98, 0.9), 2.0)
		else:
			draw_line(c + Vector2(-13, -13), c + Vector2(13, 13), Color(0.86, 0.84, 0.80), 4.0)
			draw_line(c + Vector2(-13, 13), c + Vector2(13, -13), Color(0.86, 0.84, 0.80), 4.0)

# 主角头像（简笔）
class AvatarArt extends Control:
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		draw_circle(c, 64.0, Color(0.86, 0.83, 0.76))
		draw_circle(c + Vector2(0, -18.0), 20.0, Color(0.30, 0.28, 0.28))
		draw_line(c + Vector2(0, 2.0), c + Vector2(0, 40.0), Color(0.30, 0.28, 0.28), 6.0)
		draw_line(c + Vector2(0, 10.0), c + Vector2(-24.0, 28.0), Color(0.30, 0.28, 0.28), 6.0)
		draw_line(c + Vector2(0, 10.0), c + Vector2(24.0, 28.0), Color(0.30, 0.28, 0.28), 6.0)
