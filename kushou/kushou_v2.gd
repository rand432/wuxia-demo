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
func _card_gain(id: String) -> void:
	if _card_have.has(id):
		_card_have[id] = int(_card_have[id]) + 1
		_crystal += 5                                  # 重复卡回收
		_hint.text = "重复的「" + card_name(id) + "」回收成 5 灵晶"
		Audio.sfx("coin", -10.0)
		return
	_card_have[id] = 1
	if not _card_into_deck(id):
		_open_large("卡组")       # 十格满了：让玩家去换
	_set_check(str(id.split("_")[0]))

# 组合：这套的每张卡都到手了 → 给组合效果 ＋ 三张一起离开十格（腾位）
func _set_check(set_id: String) -> void:
	if bool(_sets_done.get(set_id, false)):
		return
	var s := card_set_of(set_id + "_0")
	if s.is_empty():
		return
	var n := int(s["size"])
	for i in n:
		if not _card_have.has(card_id(set_id, i)):
			return
	_sets_done[set_id] = true
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
		"thunder_para":
			_extra["thunder_para"] = 1.0
		"cut_all_6":
			_extra["cut_all_bonus"] = float(_extra.get("cut_all_bonus", 0.0)) + 0.06
		"skill_cd_12":
			_extra["skill_cd"] = float(_extra.get("skill_cd", 0.0)) + 0.12
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
var _chal_names := ["文钱挑战", "灵晶挑战", "装备挑战", "宝物挑战", "boss挑战"]
var _chal_descs := ["刷 4 只钱怪，掉 30~60 文钱", "刷 2 只晶怪，每只掉 6~10 灵晶", "刷 1 只甲士，必掉一件装备", "刷 1 只宝箱怪，掉宝物或大钱", "把下一个 boss 提前叫出来（赢额外名声）"]
var _auto_chal := false                            # 自动挑战开关（弹窗底部那颗）
var _chal_lbs: Array = []
var _chal_pop_lbs: Array = []
var _chal_badge: Label = null
var _chal_btn: Button = null
var _auto_btn: Button = null

# ⚠ 注意 visible 的时序：外面习惯是"add_child 完就 open()"，而 add_child 进来的这一帧
#   `_ready` 可能还没跑（SceneTree 建场那会儿是延迟的）——如果 _ready 里硬写 visible=false，
#   就会把外面刚 open 的那一下**覆盖掉**（探针上表现为"整屏全黑、什么都没有"）。
#   所以这里用 _want_open 记住意图，_ready 只按意图落地。
var _want_open := false

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
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
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ⚠ 不裁剪的话，怪从上面"走进来"那一段会画到 HUD 上（截图里 boss 的名字跟倒计时叠在一起）
	_field.clip_contents = true
	add_child(_field)
	_field.coin.connect(_on_coin)
	_field.coin_drop.connect(_on_coin_drop)
	_field.kill.connect(_on_kill)
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
	_circle_btn("事件", Vector2(22, 530), func(): _open_small("事件"))
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
	_card_gain(id)
	_draw_choices.clear()
	Audio.sfx("paper", -6.0)
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
		var x := 24.0 + float(i) * (cw + 12.0)
		_card_face(p, Vector2(x, ly), Vector2(cw, 168), cid)
		_pbtn(p, "选它 " + str(DRAW_COST), Vector2(x, ly + 176.0), Vector2(cw, 60), 21, int(_crystal) >= DRAW_COST, _draw_card.bind(cid))
		_pbtn(p, "重抽 " + str(REROLL_ONE), Vector2(x, ly + 242.0), Vector2(cw, 48), 19, int(_crystal) >= REROLL_ONE, _reroll_one.bind(i))
	ly += 306.0
	_pbtn(p, "全部刷新 " + str(REFRESH_ALL), Vector2(24, ly), Vector2(220, 64), 22, int(_crystal) >= REFRESH_ALL, _refresh_all)
	var done := Label.new()
	done.position = Vector2(260, ly + 14.0)
	done.size = Vector2(420, 40)
	done.add_theme_font_size_override("font_size", 19)
	done.add_theme_color_override("font_color", DIM)
	done.text = "已拿到 " + str(_card_have.size()) + " / " + str(card_pool_size()) + " 张"
	p.add_child(done)
	return ly + 84.0
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
	# ⚠ 卡面只有 118 宽：名字要缩到 17 并允许换行，不然【I】会被裁掉（截图抓到过）
	var nm := Label.new()
	nm.position = Vector2(5, 4)
	nm.size = Vector2(sz.x - 10, 42)
	nm.add_theme_font_size_override("font_size", 17)
	nm.add_theme_color_override("font_color", INK)
	nm.text = card_name(id)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(nm)
	var pr := Label.new()
	pr.position = Vector2(5, 48)
	pr.size = Vector2(sz.x - 10, 30)
	pr.add_theme_font_size_override("font_size", 19)
	pr.add_theme_color_override("font_color", SEAL)
	pr.text = card_prop(id)
	pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(pr)
	var st := Label.new()
	st.position = Vector2(5, 78)
	st.size = Vector2(sz.x - 16, 28)
	st.add_theme_font_size_override("font_size", 18)
	st.add_theme_color_override("font_color", GOLD)
	# v7f：撤掉星级——这一行改成"品级"（卡面信息更干净）
	st.text = str(card_set_of(id).get("quality", ""))
	st.add_theme_color_override("font_color", _quality_color(str(card_set_of(id).get("quality", "下品"))))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(st)
	# 组合栏（灰字）＋ 进度
	var cm := Label.new()
	cm.position = Vector2(5, sz.y - 58.0)
	cm.size = Vector2(sz.x - 10, 32)
	cm.add_theme_font_size_override("font_size", 14)
	cm.add_theme_color_override("font_color", DIM)
	cm.text = str(s.get("combo", "")).replace("每杀一名敌人 → ", "杀敌→").replace("全伤害减免", "全减").replace("幸运一击", "幸运")
	cm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cm.clip_text = true
	box.add_child(cm)
	var got := 0
	for i in int(s.get("size", 1)):
		if _card_have.has(card_id(str(s.get("set", "")), i)):
			got += 1
	var pg := Label.new()
	pg.position = Vector2(5, sz.y - 26.0)
	pg.size = Vector2(sz.x - 16, 22)
	pg.add_theme_font_size_override("font_size", 15)
	pg.add_theme_color_override("font_color", Color(0.42, 0.62, 0.40) if got >= int(s.get("size", 1)) else DIM)
	pg.text = str(got) + "/" + str(int(s.get("size", 1))) + ("　已成型" if got >= int(s.get("size", 1)) else "")
	pg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
# ---- 黑市（v4b）：用**杀敌数**换东西（内容暂定，先把入口与账摆上）----
#   用户：「成就下面增加按钮 黑市【用于杀敌数兑换东西的 内容暂定】」
const BLACK_GOODS := [
	{"id": "coin", "name": "文钱 ×200", "cost": 50, "desc": "换成一笔现钱（直接进右上文钱）"},
	{"id": "crystal", "name": "灵晶 ×10", "cost": 200, "desc": "抽卡用的那种晶"},
	{"id": "gear", "name": "装备一件", "cost": 300, "desc": "随机一件，进装备六格"},
	{"id": "treasure", "name": "宝物一件", "cost": 400, "desc": "宝物不限格"},
	{"id": "heal", "name": "回满气血", "cost": 120, "desc": "这一下能救急"},
]

func _fill_black(p: Control, y: float, sz: Vector2) -> float:
	var head := Label.new()
	head.position = Vector2(28, y)
	head.size = Vector2(640, 50)
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", INK)
	head.text = "杀敌数 " + str(_kills) + "　（这是黑市通用的一门钱）"
	p.add_child(head)
	var sub := Label.new()
	sub.position = Vector2(28, y + 50.0)
	sub.size = Vector2(640, 36)
	sub.add_theme_font_size_override("font_size", 21)
	sub.add_theme_color_override("font_color", SEAL)
	sub.text = "黑市 Lv " + str(_bm_lv) + "　经验 " + str(_bm_exp) + "/" + str(_bm_need) + "　刷新次数 " + str(_bm_refresh)
	p.add_child(sub)
	var tip := Label.new()
	tip.position = Vector2(28, y + 88.0)
	tip.size = Vector2(640, 60)
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "每击杀 1 名敌人，黑市经验 +1；每 180 秒自动 +1 次刷新（升级也送 1 次）。内容暂定。"
	p.add_child(tip)
	var ly := y + 152.0
	for g_v in BLACK_GOODS:
		var g: Dictionary = g_v
		var cost := int(g["cost"])
		var can := _kills >= cost
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.97, 0.92) if can else Color(0.90, 0.88, 0.84)
		sb.set_corner_radius_all(10)
		sb.border_color = Color(SEAL.r, SEAL.g, SEAL.b, 0.55) if can else Color(INK.r, INK.g, INK.b, 0.25)
		sb.set_border_width_all(2)
		var row := Panel.new()
		row.position = Vector2(28, ly)
		row.size = Vector2(640, 104)
		row.add_theme_stylebox_override("panel", sb)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(row)
		var nm := Label.new()
		nm.position = Vector2(18, 12)
		nm.size = Vector2(360, 42)
		nm.add_theme_font_size_override("font_size", 26)
		nm.add_theme_color_override("font_color", INK if can else DIM)
		nm.text = str(g["name"])
		row.add_child(nm)
		var ds := Label.new()
		ds.position = Vector2(18, 58)
		ds.size = Vector2(430, 36)
		ds.add_theme_font_size_override("font_size", 20)
		ds.add_theme_color_override("font_color", DIM)
		ds.text = str(g["desc"])
		row.add_child(ds)
		var pr := Label.new()
		pr.position = Vector2(452, 20)
		pr.size = Vector2(170, 44)
		pr.add_theme_font_size_override("font_size", 22)
		pr.add_theme_color_override("font_color", SEAL if can else DIM)
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pr.text = str(cost) + " 杀"
		row.add_child(pr)
		var b := _pbtn(row, "换", Vector2(540, 30), Vector2(84, 44), 22, can, _black_buy.bind(str(g["id"]), cost))
		b.disabled = not can
		ly += 116.0
	var foot := Label.new()
	foot.position = Vector2(28, ly)
	foot.size = Vector2(640, 44)
	foot.add_theme_font_size_override("font_size", 20)
	foot.add_theme_color_override("font_color", DIM)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.text = "换到的东西会像掉落一样飞进对应的计数位（文钱/灵晶→右上 · 装备/宝物→右下）。"
	p.add_child(foot)
	return ly + 56.0

func _black_buy(id: String, cost: int) -> void:
	if _kills < cost:
		_hint.text = "杀敌数不够（要 " + str(cost) + "，你现在 " + str(_kills) + "）"
		return
	_kills -= cost
	match id:
		"coin":
			_spawn_drop("coin", 200, Vector2(560.0, 560.0), 12)
		"crystal":
			_spawn_drop("crystal", 10, Vector2(560.0, 560.0), 6)
		"gear":
			_spawn_drop("gear", 1, Vector2(560.0, 560.0), 1)
		"treasure":
			_spawn_drop("treasure", 1, Vector2(560.0, 560.0), 1)
		"heal":
			if _field != null:
				_field.hero["hp"] = float(_field.hero["hp_max"])
			_hint.text = "气血回满"
	Audio.sfx("ui_click", -6.0)
	_hint.text = "黑市成交：" + id + "（花 " + str(cost) + " 杀敌数，剩 " + str(_kills) + "）"
	if _popup_kind == "黑市":
		_open_large("黑市")
# ---- 失败结算（v3m）----
#   用户："任务失败卡住了"——免死用尽之后得有去处：把这一局的账摊开，给［再来一局］与［退出］。
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

func _chal_press(i: int) -> void:
	_hint.text = "点了「" + str(_chal_names[i]) + "」——空壳里只回一句（第 2 步真的刷怪）"

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
	_boss_sec -= delta
	if _boss_sec <= 0.0:
		_boss_sec = 60.0
		_wave = mini(_wave_max, _wave + 1)
		_boss_tier = clampi(1 + _wave / 10, 1, 3)
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
	_field.hero["elem_amp"] = _elem_amp()
	# v5f：暴击/暴击伤害（无上限）· 幸运一击（上限 300%）· 全伤害增加与减免 · 各元素抗性/加成
	_field.hero["crit"] = _crit_total()
	_field.hero["crit_dmg"] = _crit_dmg_total()
	_field.hero["lucky"] = _lucky()
	_field.hero["dmg_all"] = _dmg_all()
	_field.hero["cut_all"] = 0.10 + float(_extra.get("cut_all_bonus", 0.0))   # 横练 10% ＋ 铁壁套
	_field.hero["res_elem"] = _res_elem()
	_field.hero["dmg_elem"] = _dmg_elem()
	_field.hero["dmg_true"] = float(_extra.get("dmg_true", 0.0))   # 只有它能加真实伤害
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

func _on_kill(_n: int) -> void:
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
	_exp += 0.04
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
	return ["卡组", "技能", "装备", "挑战", "存档", "成就", "角色", "队员", "仓库", "卡牌详情", "局终", "黑市", "招募"].has(k)

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
	if kind == "招募":
		return _fill_recruit(p, y, sz)
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
	elif kind == "卡牌详情":
		var c: Dictionary = _deck[clampi(_card_idx, 0, _deck.size() - 1)]
		lines = ["『" + str(c["name"]) + "』　" + str(c["star"]) + "★（已吞 " + str(c["ate"]) + " 张）",
			"现在效果：" + str(c["fx"]),
			"每升一星：效果按 +50% 走（1★→5★ 一共 ×3）",
			"再吃 " + str(maxi(1, 2 - int(c["ate"]))) + " 张同名卡升下一星",
			"长按卡牌就看这一页（流派不写，自己发掘）"]
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
		for i in 6:
			var cd := float(_chal_cd[i])
			lines.append("　" + str(_chal_names[i]) + "：" + ("就绪" if cd <= 0.0 else "冷却 " + str(int(ceil(cd))) + "s"))
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
	if _deck_tab == 0:
		_fill_deck_slots(p, y + 182.0)
	else:
		_fill_deck_ate(p, y + 182.0)
	# 底部这三个跟着内容走（在滑动区里），别钉在窗外
	var by := maxf(640.0, y + (460.0 if _deck_tab == 0 else 420.0))
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
	# v7a：十格改成**新卡面**（单卡属性 ＋ 组合栏 ＋ 进度）
	while _deck_cards.size() < 10:
		_deck_cards.append("")
	for i in 10:
		var col := i % 5
		var row := i / 5
		_card_face(p, Vector2(24.0 + float(col) * 134.0, y + float(row) * 134.0), Vector2(126, 122), str(_deck_cards[i]))
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
	_band.text = "波 " + str(_wave) + "/" + str(_wave_max) + "　❤ " + str(int(_hp)) + "/" + str(int(_hp_max)) + "　内力 " + str(int(_mp)) + "/" + str(int(_mp_max)) + "　内力 " + str(int(_mp)) + "/" + str(int(_mp_max))


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
	return int(_attr["arm"]) + int(_grow_inherit["arm"]) + int(_grow_card["arm"])

func _attr_agi() -> int:
	return int(_attr["agi"]) + int(_grow_inherit["agi"]) + int(_grow_card["agi"])

func _attr_wit() -> int:
	return int(_attr["wit"]) + int(_grow_inherit["wit"]) + int(_grow_card["wit"])

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
		+ 12.0 * float(_attr_arm()) * _boost_for("arm")

func _hp_regen() -> float:
	return 0.4 * float(_attr_arm()) * _boost_for("arm")

# 身法：攻速 + 护甲；主属性＝敏捷时再给攻击
func _aspd_total() -> float:
	return 1.0 * (1.0 + 0.02 * float(_attr_agi()) * _boost_for("agi") + float(_extra.get("aspd_bonus", 0.0)))

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
	return 0.05 + 0.005 * float(_attr_agi())

func _crit_dmg_total() -> float:
	return 2.0 + 0.02 * float(_attr_arm()) + float(_extra.get("crit_dmg_bonus", 0.0))

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
		for i in 6:
			var col := i % 3
			var row := i / 3
			_gear_box(p, Vector2(28.0 + float(col) * 216.0, ly + float(row) * 132.0), Vector2(200, 120), "equip", i)
		ly += 276.0
	else:
		for i in _treasures.size():
			var col2 := i % 3
			var row2 := i / 3
			_gear_box(p, Vector2(28.0 + float(col2) * 216.0, ly + float(row2) * 132.0), Vector2(200, 120), "treasure", i)
		ly += 132.0 * float(1 + _treasures.size() / 3)
	ly += 12.0
	_pbtn(p, "仓库", Vector2(28, ly), Vector2(200, 76), 24, false, func(): _open_large("仓库"))
	_pbtn(p, "公共仓库（暂不开放）", Vector2(240, ly), Vector2(300, 76), 21, false, func(): _open_large("公共仓库"))
	var tip := Label.new()
	tip.position = Vector2(28, ly + 86.0)
	tip.size = Vector2(640, 44)
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "六格自由摆（不分部位，随便放）。点击看详情；长按拿起来，再点目标格或［仓库］放下。"
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
