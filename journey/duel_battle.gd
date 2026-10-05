extends Control
# ============================================================
# duel_battle.gd —— 1v1 交手演出（v9 · 自带 row_priority 接线：苏青鸾持匕首绕前排）
# v9（用户："苏 被动带匕首不打后排"）：**自带天赋的 row_priority 在游历这边补接线**——
#   村里战斗一直认它（battle_lite._enemy_attack_index：row_prio "back" ＝ 普攻挑最靠后的活人），
#   游历这边却一律打最前排 → 苏青鸾拿匕首绕前排直取后排那只「杀手」的设定等于没写。
#   改法三处：_blank_ally 加字段、_setup_ally 按兵器闸记下（innate_active 判过）、
#   _pick_player_target 在**普攻**分支落点（带 target 的招式本来自己点名，不动）；
#   闭窍（nopassive）压着时一并压住。一只敌时与 _front_foe 同值，老场面一字不变。
# v8（㉙）：①陈石枪势反刺——不再按"敌伤 35%"，改按陈石气血上限的比例带 8%~12%
#   （挨的打越重比例越高：THORN_HP_LO/HI 两个常数；铁蒺卡整带加乘）；
#   ②反伤/反刺浮字改"橙字数字、打在挨打的人身上"（回复仍旧绿字）；敌"反伤词缀"同理；
#   ③运签 fx 键名双向兼容（ult_dur/aura_turns、passive_up/passive_mul、thorn_up/thorn_mul、
#   cut_add/taken_cut、rage_pct/rage_up）——与 data_buffs v3.1 对齐（取大不叠加）；
#   ④回气卡（受伤后下一击 +10%）与养晦卡（大招空窗 3 手回气）接线；
#   ⑤反刺可在敌方出手段打死敌——补自爆判定（不白死）。
# v7：①怪词缀（同出村口径）；②角色被动真生效；③我方怒气/大招接入——主角一段·陈石枪势·
#   青鸾剑歌；④货郎「运签」在这里兑现（攻防/怒气/冷却/毒/大招改造）。数值初稿。
# v6（优化批㉑：精英带招 · 文钱减半）
# v6：①精英敌（节点带 "arts"/"ult" 键，见 data_journey v5）会放招、怒气满放大招；
#   【新手游历不加】＝引子趟（mode == "intro"）不接招，纯蛮力。
#   右上［敌情］看招数（看着时回合停住）。护体招数按 _foe_take 统一减伤玩家输出。
#   ②MONEY_MULT 2.0→1.0：一场架文钱收入减半（还嫌多就改 0.6——就这一个数）。
# v5e（R4）：战败横幅"负伤"→"不敌"——Q1=b 后败北＝殒命，"负伤退走"字样不再准确；
#   败北语义与结算由 journey_stage 承担，本文件只报结果。
# v5d（R3 子批②）：①入口加 foe_first（警戒遭遇：敌先手，附横幅"来敌先手！"）；
#   ②每场把敌阵容记进 run_state.last_foe（遭遇三级敌源第二级）。
# v5c：百折不挠 / 剑心通明 的活逻辑撤除——"全撤，等 R6 与村战一起接"；
#   天赋表说明早已写"（接入后生效）"，从此两边口径一致。
# v5b：护体浮字不再写死"减伤 60%"——改按 art.cut 现算（铁布衫 v9 实为 45%）。
# v5 变动：坐标从横屏 1152×648 搬到竖屏 720×1280（只动位置与字号，逻辑零变化）：
#   ① 两人落脚 (210,950) / (510,950)：踩在游历地面线 y=950 上，屏幕中轴 360 左右各 150
#   ② 血条根 (20,80) 680×104：左"我"320 宽、"敌"320 宽，功法行 680 宽
#   ③ 招式横幅 (60,520) 600×52（居中）
#   ④ 5 处浮字从默认 y=150 挪到 y=192（血条区正下方，不再压功法行）
#   （敌人入场与败退仍从屏外 x=1500 出入，勿动）
# v4 变动：
#  ① 新增 MONEY_MULT（文钱收入总系数）
#  ② 自带天赋生效：kind == "low_hp_dmg" 时，
#     我方气血不足一半 → 伤害 ×mult，每场浮字提示一次
#  ③ 胜/负结算收入统一乘 MONEY_MULT
# 其余：FOE_HP_MULT、招式横幅、血条、冷却行不变
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const RunState := preload("res://shared/run_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const GameState := preload("res://shared/game_state.gd")
const Affixes := preload("res://shared/data_affixes.gd")
const St := preload("res://shared/data_status.gd")   # v52：负面状态（表＋API，与出村共用同一份）
const Elem := preload("res://shared/data_elem.gd")   # v58：五行（通道口径/抗性/增伤聚合）
const StatusChips := preload("res://shared/status_chips.gd")   # v54：负面状态的小图标
const Tuning := preload("res://shared/tuning.gd")   # ㉘：可调参数读取口
const Roles := preload("res://journey/data_roles.gd")   # ㊳：自带天赋的兵器条件判定
const GameData := preload("res://shared/game_data.gd")  # ㊷：招式作用范围（target_reach）
const Buffs := preload("res://shared/data_buffs.gd")   # ㊿：运签卡的封顶值（回气卡/冰心卡）
const StickFighter := preload("res://journey/stick_fighter.gd")
const ActorFactory := preload("res://journey/actor_factory.gd")   # Q版纸片人 / 火柴人 二选一
const CharArt := preload("res://shared/char_art.gd")
const ArtClip := preload("res://shared/art_clip.gd")
const Audio := preload("res://shared/audio.gd")
const InkTouch := preload("res://shared/ink_touch.gd")
const FadeIn := preload("res://shared/fade_in.gd")   # v68：进场淡入 + 震动

# ㉘ 数值外置：下面这批旋钮可以从 res://tuning.cfg 或 user://tuning.cfg 覆盖
#   （读不到＝用这里写着的默认值，行为与改之前一模一样）。
#   用 static var 是因为 const 不能调 Tuning.num()；好处是用它的地方不用改。
#   ⚠ 别在运行中往这些变量赋值——它们是"开机读一次的配置"，不是状态。
#
# 敌人生命总系数：越大打得越久。1.0 = 原样；2.0 轻快；3.0 = 建议（约现在 3 倍回合）
static var FOE_HP_MULT := Tuning.num("journey", "foe_hp_mult", 3.0)
# ㊿：新手游历（引子趟）的"手下留情"系数——血量与攻击**都**按它打折。
#   引子是第一场仗，原来跟正式趟一个强度、还上副手，太劝退。
#   想恢复原样就把 tuning 的 journey/intro_ease 填 1.0。
static var INTRO_EASE := Tuning.num("journey", "intro_ease", 0.7)
# ㊿：冰心卡的冷却减免上限——就算叠了好几张，一次最多减这么多；
#   而且冷却本身保底 1（见 set_art_cd 那一处），永远到不了 0。
#   数值只在 data_buffs 里写一份（那边还要拿它算"最多几张有用"的提示）。
const ART_CD_MINUS_CAP := Buffs.ART_CD_CAP
# v49：追剑连环的上限（与 battle_lite.SONG_CHAIN_MAX 同一个数、同一个含义）：
#   一次触发里"追剑自己暴击 → 再追一层"最多追到第几层。
#   1 ＝ 只追一层（不再连环）；3 ＝ 最多"追了又追"两轮。见 _song_follow 的注。
# v11d（用户："【追击可暴击 但是不会继续追击】"）：**苏青鸾的追剑改为不连锁 → 1**。
const SONG_CHAIN_MAX := 1
# v11：剑歌窗口内的暴击加成（百分点）——苏青鸾的大招加强，见 QINGLUAN_DEFAULT.ult。
#   ⚠ 与 menu/battle_lite.SONG_CRIT_UP 同一个数，改一处必须改两处。
const SONG_CRIT_UP := 15.0
# 文钱收入总系数：2.0 → v6 减半 → 本次再降（花不完）；还想更低就 0.4，一个数
static var MONEY_MULT := Tuning.num("journey", "money_mult", 0.6)
# 精英怒气增速：敌人每出一手 +34；满 100 放大招（与队员同口径）
static var DUEL_RAGE_GAIN := Tuning.intv("journey", "duel_rage_gain", 34)
# ㊹：全体怒气恢复 -30%（与 battle_lite.RAGE_MUL 同一个键，两套战斗同步）
static var DUEL_RAGE_MUL := Tuning.num("combat", "rage_mul", 0.7)
# ㊿：游历敌人速度的折算（data_journey 用 100 量级；村里/塔用 10 量级）。
#   攻速那条规矩（GameData.extra_attacks）也读这里折好的数——两边必须同一把尺子。
static var JOURNEY_FOE_SPD_DIV := Tuning.num("journey", "foe_spd_div", 10.0)
# ㉙：枪势反刺——按陈石气血上限的比例带（挨得越重比例越高）
static var THORN_HP_LO := Tuning.num("journey", "thorn_hp_lo", 0.08)
static var THORN_HP_HI := Tuning.num("journey", "thorn_hp_hi", 0.12)
# ㉙：反伤/反刺浮字——橙；回复用 UiKit.GREEN（绿）——一眼分开
const C_COUNTER := Color(0.95, 0.52, 0.10)
const C_DODGE := Color(0.42, 0.62, 0.86)   # v35：闪避浮字（蓝——与反伤橙、回复绿分得开）

var _state: RunState = null   # ㊿：标注类型，否则 var x := _state.foo() 推不出类型（编译报错过）
var _player: Node2D = null      # 当前聚焦的那名我方（由 _p_focus_on 换）——与 _foe 同一套路
var _fx: Control = null
var _foe: Node2D = null
# ㊷：敌人状态已搬进 _foes 数组（见下面的敌阵容段）；_foe_* 改成了访问器函数
var _p_base := Vector2(210, 950)   # 当前聚焦那名我方的站位（由 _p_focus_on 换）
var _e_base := Vector2(510, 950)
var _skip_enemy := false

# ============================================================
# ㊿：三人成队——我方成员表
#
# 原来那一批"我方单人状态"（_hp / _rage / _ult_* / _guard_* / _fx_buff / _my_hp_max …）
# 现在**每人一份**，存在 _allies 里。变量名一个没改，只是从普通 var 变成了
# "转发到当前成员"的属性——所以出手/挨打那一百多处读法一个字都不用动。
# 谁挨打/谁出手之前先 _p_focus_on(i)，之后所有 _xxx 读写都落在那一人身上。
#
# 这与敌人侧的 _foes + _foe_*（㊷ 那一批）是同一套路，不是新发明。
# _player / _p_base 跟 _foe 一样留作"当前那一个"的普通 var（由聚焦函数换）。
# ============================================================

var _allies: Array = []         # 每项见 _blank_ally()
var _ally_nodes: Array = []     # 与 _allies 同序的节点
var _own_nodes: Array = []      # 战斗自己开的节点（收尾只收这些；舞台的还要走路上）
# ㊿：手动／自动 · 出牌（"杀戮尖塔"那套）
#   这一版选过一次就记着（本局有效，写在这个静态变量里）——
#   不然每打一场都要重新点一次切换钮。
static var last_manual := false
var _manual := false            # true＝玩家划线出牌；false＝自动（照旧）
var _card_row: Control = null   # 底部那一排牌（扇形手牌）
var _card_panels: Array = []
var _card_meta: Array = []      # 与 _card_panels 同序的牌数据
var _card_base: Array = []      # 每张的原始姿态 {pos, rot}——弹出后要能回位
var _card_lbl: Array = []       # 每张底下那行小字（弹出后改文案）
var _card_choice := -1          # 玩家选中的下标；-1＝还没选
var _card_pick := -1            # 当前"弹出"的那张（-1＝没弹）
var _drag_from := Vector2.ZERO  # 按住起点（判"往上划"）
var _press_was_pick := false    # 按下去之前它是不是已经弹出的那张（＝"再点一下发动"）
var _touch_active := false      # 触摸进行中——挡掉 Godot 仿真出来的鼠标事件
var _card_tip: Label = null     # 牌上方那行提示（等牌时显示倒计时）
var _card_wait_left := -1       # 倒计时剩几秒（-1＝不显示）
var _card_interactive := false  # 这排牌能不能点（自动模式那排只是亮一下）
var _card_auto := false         # 这一手交给自动（行内按钮／中途改自动）
var _card_zoom: Control = null  # ㊿：按住卡牌弹的"放大镜"窗口
var _card_hold_i := -1          # 正按着哪张（-1＝没按）
var _card_hold_seq := 0         # 按住序号——松开/换牌就作废，防止延迟弹窗
var _card_logged := false       # 摊牌几何每场只打印一次（排查"牌在哪"用）
# ㊿：这一轮**已经出过哪些牌**（按"人|种类|id"记）。
#   出手位不再按"每人一个"算，而是按"还能出几张牌"算：
#   技能冷却好了就能出，所以一轮里同一个人可能连出好几手。
#   ⚠ 普攻没有冷却，所以它**每人每轮仍只算一次**——不然可以无限点（见 _available_cards）。
var _used: Array = []
# ㊿：刚打出去的那一手（出手循环用它记台账——**只记真出的那一张**，
#   两条路（玩家点的 / 自动挑的）都汇到这一个落点，免得各记一套迟早走岔）
var _last_ai := -1
var _last_k := ""
var _last_sid := ""
# ㊿：出手方式那颗钮在**舞台**上（左侧［卡组］下面）——这里不留钮，只跟静态值同步。
# ㊿：手牌——**全队一副**。每个活着的人一排（最多三排），一排最多 5 张
#   （普攻＋3 门武学＋大招）。尺寸按 720 宽算：左边 96 的"谁 · 哪一排"标签列
#   ＋ 5×104 的牌 ＋ 4×10 的缝 ＝ 656，正好放得下。
const CARD_W := 104.0
const CARD_H := 112.0
const CARD_GAP := 10.0
const CARD_LABEL_W := 96.0
const CARD_ROW_GAP := 12.0
const CARD_TIP_PICK := "点选·长按看详情"
const CARD_TIP_FIRE := "↑ 往上划发动"
const CARD_FACE_SUB := 26          # 牌面上效果文字最多留几个字（全文在长按的大窗里）
# ㊿：按住多久弹"放大镜"（看清效果用）。太长会像没反应，太短又会被"点一下"误触。
const CARD_HOLD_SEC := 0.35
# ㊿：手牌按**人**配色——三人出战时一眼分得出这张是谁的（少侠/陈石/苏青鸾）
const ROLE_CARD_COL := {
	"player": Color(0.22, 0.34, 0.58),
	"chen_shi": Color(0.52, 0.33, 0.18),
	"qingluan": Color(0.60, 0.22, 0.34),
}
# 等牌上限：超时就按普攻打出去。**别写太大**——玩家眼里"没反应"就是卡死，
#   所以配了可见倒计时＋行内［自动挑］钮，30 秒够想一手了。
const CARD_WAIT_SEC := 30.0

# ============================================================
# v57（用户："可以 你继续"）：**普攻接上招式表**
#   `MOVE_ANIM = false` → 整条退回旧样子（只滑 92 像素 / 0.15 秒，招式表不播）。
#   `MOVE_SPEED` → 招式整体倍速。招式表是按"单看一招"排的，放进连续出手要快一档：
#     起手 0.10~0.55 秒 ÷ 倍速；冲步时间也除同一个数，所以姿势与等待不会各走各的。
#   实测（17 招平均）：旧的一下 0.15 秒 → 现在"起手＋冲"平均 0.50÷倍速。
const MOVE_ANIM := true
const MOVE_SPEED := 1.8

# ============================================================
# v10（用户："游历战斗界面加一个 2倍加速【4倍不加】"）：**这一场的节奏倍速**
#   口径照出村战斗（battle_lite v38 起）：只压"等一会儿"与"招式播放"，**不碰任何数值**。
#   ⚠ 用户点名"4 倍不加"——SPEED_STEPS 里只有 1× 与 2×，别再往里塞。
#   ⚠ 招式那边走 _move_spd()（MOVE_SPEED × 本倍速）。**move_time() 返回的 windup 已经除过
#     这个倍速**了，所以等它的那一句要调原来的 create_timer、**别再走 _wait**（除两遍＝四倍）。
#   静态存一份：这一场按了 2×，下一场进来还是 2×（与"出手方式" last_manual 同一处手感）。
# ============================================================
static var SPEED := 1.0
const SPEED_STEPS := [1.0, 2.0]

static func next_speed(cur: float) -> float:
	var i := SPEED_STEPS.find(cur)
	i = 0 if i < 0 else (i + 1) % SPEED_STEPS.size()
	return float(SPEED_STEPS[i])

# 这一场"等一会儿"的唯一出口——倍速只在这一行生效
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec / maxf(1.0, SPEED)).timeout

# 招式播放的实际倍速＝表定 1.8 × 这一场的快进
func _move_spd() -> float:
	return MOVE_SPEED * maxf(1.0, SPEED)

var _p_focus := 0

const ALLY_ROW_DX := -58.0      # 我方站位：越靠后越往左、越往上（镜像敌人的排布）
const ALLY_ROW_DY := -26.0

static func _blank_ally() -> Dictionary:
	return {
		"role_id": "player", "name": "少侠", "node": null,
		"base": Vector2(210, 950), "row": 0,
		"hp": 100, "hp_max": 100,
		"spd": 100, "atk": 10, "dmg": 0.0, "crit": 5.0,
		# ㊿：加持（武学 kind "bless"）——按"自己的手"计数，同一人只挂一条
		"bless_turns": 0, "bless_cut": 0.0, "bless_atk": 0.0, "bless_crit": 0.0,
		"bless_regen": 0.0, "bless_spd": 0.0, "bless_rage": 0.0, "bless_skip": false,
		"weapon": "sword", "arts": [], "art_i": 0, "art_cd": 0,
		"guard_left": 0, "guard_cut": 0.8,
		"next_mult": 1.0, "innate_noted": false,
		"talent_cut": 0.0, "talent_wpn": 1.0, "inn_thorn": 1.0, "talent_cut_noted": false,
		# v9（用户："苏 被动带匕首不打后排"）：自带里的 row_priority——"back"＝普攻绕前排直取后排。
		#   与出村战斗 battle_lite._enemy_attack_index 同一条规矩；谁生效由 _setup_ally 判兵器闸。
		"row_prio": "",
		"rage": 0, "rage_mul": 1.0,
		"ult": {}, "ult_turns": 0, "ult_new": false, "ult_follow": 0.0,
		"ult_thorn": 0.0, "ult_thorn_on": false, "ult_regen_pct": 0.0,
		"fx_buff": {}, "crit_add": 0.0, "cut_add": 0.0,
		"hand_n": 0, "window_left": 0, "p_poison": 0,
		# ㊿：轻身卡——"受击过"标记。置上就是 +20% 速度（spd_pct），**不叠加**：
		#   它是开关不是层数，所以挨多少下都只 +20%。
		"hit_taken": false,
		"acts": 0, "downed": false,
	}

func _a() -> Dictionary:
	if _allies.is_empty():
		_allies.append(_blank_ally())
	_p_focus = clampi(_p_focus, 0, _allies.size() - 1)
	return _allies[_p_focus]

func ally_count() -> int:
	return _allies.size()

func ally_at(i: int) -> Dictionary:
	if i < 0 or i >= _allies.size():
		return {}
	return _allies[i]

# 聚焦到某名我方（顺手把 _player / _p_base 换成他的）——与 _focus_on 对称
# ㊿：同时把 run_state 的"当前成员"也切过去。武学冷却/怒气那一套（reset_art_cd /
#   tick_arts / pick_art / set_art_cd）都住在 run_state 里、按"当前成员"算——
#   这里同步一次，战斗里那些 _state.xxx 就自动落在出手的那一人身上，不会错位。
func _p_focus_on(i: int) -> void:
	_p_focus = clampi(i, 0, maxi(0, _allies.size() - 1))
	if _p_focus < _ally_nodes.size():
		_player = _ally_nodes[_p_focus]
	var al := ally_at(_p_focus)
	if not al.is_empty():
		_p_base = al.get("base", _p_base)
	if _state != null:
		_state.use_member(_p_focus)

func _ally_alive(i: int) -> bool:
	var al := ally_at(i)
	if al.is_empty():
		return false
	return int(al.get("hp", 0)) > 0

func _allies_alive() -> int:
	var n := 0
	for i in _allies.size():
		if _ally_alive(i):
			n += 1
	return n

# 前排优先：普攻只打最靠前还站着的那个（站位规则）
func _front_ally() -> int:
	for i in _allies.size():
		if _ally_alive(i):
			return i
	return -1

# ㊿：敌人这手打谁——按"够到第几排"挑，与出村战斗（battle_lite._pick_target）同一套规矩：
#   · 普攻／没写 target 的招式：reaches = 0，只够到前排
#   · 写了 target: mid/back 的招式：够得到中排/后排——**但要前面没人挡**才算数
#     （游历的精英招就是 target:"mid"：黑风掠阵、单臂快刀、以及两个大招）
#   · 够不着任何"露出来的人" → 兜底打最前面那个活人（宁可够得着，也别空过一手）
#   ⚠ 那道"前面没人挡"的闸是**前排替后排挡刀**这条设计的落点：mid 招式在前排还站着时
#     仍旧打前排，前排一倒就能点到中排。出村战斗就是这么判的，两边保持一致。
#   ㊿：**bypass＝跳过那道闸**。两条路会传它：
#     · 怪的词缀「破前 / 偷袭 / 截后」——这三个的存在意义就是破规矩（见 data_affixes）
#     · 点名招式（写了 target: mid/back/sweep 的大招/招数）
#   ⚠ 这一段以前**没有 bypass**，于是"破前"其实是个空词缀：那道闸把 reaches 全挡平了，
#     有没有它挑出来的人一模一样。现在词缀真能破闸了。
func _pick_ally_target(reaches: int, bypass := false) -> int:
	var pool: Array = []
	for i in _allies.size():
		if not _ally_alive(i):
			continue
		if int((_allies[i] as Dictionary).get("row", i)) > reaches:
			continue
		if not bypass and not _ally_row_exposed(i):
			continue
		pool.append(i)
	if pool.is_empty():
		return _front_ally()
	# ㊿：截后（cutoff）——不按"打最近的"，专挑够得着的人里**站得最靠后**的那个
	if bypass and _foe_affixes().has("cutoff"):
		var best := -1
		var best_row := -1
		for i2 in pool:
			var r2 := int((_allies[i2] as Dictionary).get("row", i2))
			if r2 > best_row:
				best_row = r2
				best = int(i2)
		if best >= 0:
			return best
	return int(pool[randi() % pool.size()])

# 露出来了没：他前面还有人活着就不算露（与 battle_lite._row_exposed 同义）。
#   本作里 row 就是下标（0 前 1 中 2 后），所以"前面"＝下标比他小的那些。
func _ally_row_exposed(idx: int) -> bool:
	for i in idx:
		if _ally_alive(i):
			return false
	return true

# ㊿：这只怪的**普攻**够到第几排——默认 0（只打前排）。
#   破前（pierce）＝够到中排；偷袭（ambush）/ 截后（cutoff）＝够到最后一排。
#   这三个词缀都算"破规矩的"，所以还要 bypass 那道挡刀闸（见 _pick_ally_target）。
func _foe_reach() -> int:
	if _foe_affixes().has("ambush") or _foe_affixes().has("cutoff"):
		return 2
	if _foe_affixes().has("pierce"):
		return 1
	return 0

# ㊿：这只怪的普攻能不能破"前排挡刀"那道闸
func _foe_pierce_shield() -> bool:
	var af := _foe_affixes()
	return af.has("pierce") or af.has("ambush") or af.has("cutoff")

# ㊿：偷袭（ambush）——打**不在前排**的目标伤害 +50%。
#   判据是"此刻聚焦的那名我方"的排号（挨打前 _pick_ally_target 已经切好人）。
func _ambush_mul() -> float:
	if not _foe_affixes().has("ambush"):
		return 1.0
	if int(_a().get("row", 0)) <= 0:
		return 1.0
	return 1.5

# ㊿：速度 → 攻速那条规矩的真源在 GameData.extra_attacks / atkspd_word（见那儿的长注释）。
#   出村战斗与这里共用同一份——所以这里不再自己写一遍。

# ---- 我方成员字段的转发属性（名字与旧 var 完全一致）----

var _hp: int:
	get:
		return int(_a().get("hp", 0))
	set(v):
		var before := int(_a().get("hp", 0))
		var after := maxi(0, int(v))
		_a()["hp"] = after
		# ㊿z：角色星·陈石「铁桩」——受击也涨怒气（所有扣血口都从这里过，所以只写这一处）
		if after < before:
			var rh := float(_fx_buff.get("rage_on_hit", 0.0))
			if rh > 0.0:
				_a()["rage"] = mini(100, int(_a().get("rage", 0)) + int(round(rh)))

var _guard_left: int:
	get:
		return int(_a().get("guard_left", 0))
	set(v):
		_a()["guard_left"] = int(v)

var _guard_cut: float:
	get:
		return float(_a().get("guard_cut", 0.8))
	set(v):
		_a()["guard_cut"] = float(v)

var _next_mult: float:
	get:
		return float(_a().get("next_mult", 1.0))
	set(v):
		_a()["next_mult"] = float(v)

var _innate_noted: bool:
	get:
		return bool(_a().get("innate_noted", false))
	set(v):
		_a()["innate_noted"] = bool(v)

var _talent_cut: float:
	get:
		return float(_a().get("talent_cut", 0.0))
	set(v):
		_a()["talent_cut"] = float(v)

var _talent_wpn: float:
	get:
		return float(_a().get("talent_wpn", 1.0))
	set(v):
		_a()["talent_wpn"] = float(v)

var _inn_thorn: float:
	get:
		return float(_a().get("inn_thorn", 1.0))
	set(v):
		_a()["inn_thorn"] = float(v)

var _talent_cut_noted: bool:
	get:
		return bool(_a().get("talent_cut_noted", false))
	set(v):
		_a()["talent_cut_noted"] = bool(v)

var _rage: int:
	get:
		return int(_a().get("rage", 0))
	set(v):
		_a()["rage"] = int(v)

var _rage_mul: float:
	get:
		return float(_a().get("rage_mul", 1.0))
	set(v):
		_a()["rage_mul"] = float(v)

var _ult: Dictionary:
	get:
		return _a().get("ult", {})
	set(v):
		_a()["ult"] = v

var _ult_turns: int:
	get:
		return int(_a().get("ult_turns", 0))
	set(v):
		_a()["ult_turns"] = int(v)

var _ult_new: bool:
	get:
		return bool(_a().get("ult_new", false))
	set(v):
		_a()["ult_new"] = bool(v)

var _ult_follow: float:
	get:
		return float(_a().get("ult_follow", 0.0))
	set(v):
		_a()["ult_follow"] = float(v)

var _ult_thorn: float:
	get:
		return float(_a().get("ult_thorn", 0.0))
	set(v):
		_a()["ult_thorn"] = float(v)

var _ult_thorn_on: bool:
	get:
		return bool(_a().get("ult_thorn_on", false))
	set(v):
		_a()["ult_thorn_on"] = bool(v)

var _ult_regen_pct: float:
	get:
		return float(_a().get("ult_regen_pct", 0.0))
	set(v):
		_a()["ult_regen_pct"] = float(v)

var _fx_buff: Dictionary:
	get:
		return _a().get("fx_buff", {})
	set(v):
		_a()["fx_buff"] = v

var _my_hp_max: int:
	get:
		return int(_a().get("hp_max", 100))
	set(v):
		_a()["hp_max"] = int(v)

var _crit_add: float:
	get:
		return float(_a().get("crit_add", 0.0))
	set(v):
		_a()["crit_add"] = float(v)

var _cut_add: float:
	get:
		return float(_a().get("cut_add", 0.0))
	set(v):
		_a()["cut_add"] = float(v)

var _hand_n: int:
	get:
		return int(_a().get("hand_n", 0))
	set(v):
		_a()["hand_n"] = int(v)

var _window_left: int:
	get:
		return int(_a().get("window_left", 0))
	set(v):
		_a()["window_left"] = int(v)
# ㊷：敌方的"临时状态"也搬进了 _foes 项里（arts/ult/affixes/art_i/art_cd/rage/guard/
#   stack/poison/next_mult/acts），下面这批访问器同样指向 _focus 那一只。
#   注意：_foe_affixes 以前是"节点级"的字段，现在也从当前敌身上取——
#   所以每个敌人可以各带各的词缀。

func _foe_arts() -> Array:
	return _cur().get("arts", [])

func _foe_ult() -> Dictionary:
	return _cur().get("ult", {})

func _foe_affixes() -> Array:
	return _cur().get("affixes", [])

func _foe_art_i() -> int:
	return int(_cur().get("art_i", 0))

func _set_foe_art_i(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["art_i"] = v

func _foe_art_cd() -> int:
	return int(_cur().get("art_cd", 0))

func _set_foe_art_cd(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["art_cd"] = v

func _foe_rage() -> int:
	return int(_cur().get("rage", 0))

func _set_foe_rage(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["rage"] = v

func _foe_guard() -> int:
	return int(_cur().get("guard", 0))

func _set_foe_guard(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["guard"] = v

func _foe_guard_cut() -> float:
	return float(_cur().get("guard_cut", 0.0))

func _set_foe_guard_cut(v: float) -> void:
	var c := _cur()
	if not c.is_empty():
		c["guard_cut"] = v

func _foe_next_mult() -> float:
	return float(_cur().get("next_mult", 1.0))

func _set_foe_next_mult(v: float) -> void:
	var c := _cur()
	if not c.is_empty():
		c["next_mult"] = v

func _foe_stack() -> float:
	return float(_cur().get("stack", 0.0))

func _set_foe_stack(v: float) -> void:
	var c := _cur()
	if not c.is_empty():
		c["stack"] = v

func _foe_poison_n() -> int:
	return int(_cur().get("poison", 0))

func _set_foe_poison_n(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["poison"] = mini(Affixes.POISON_MAX(), v)

func _foe_acts() -> int:
	return int(_cur().get("acts", 0))

func _set_foe_acts(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["acts"] = v

var _p_poison: int:
	get:
		return int(_a().get("p_poison", 0))
	set(v):
		_a()["p_poison"] = int(v)

var _skip_next := false

# v6：精英带招——㊷：这些已搬进 _foes 项（见上面的访问器），这里不再留变量
var _info_open := false
var _info_veil: Control = null
var _info_btn: Button = null
# v63h（用户："战斗就爬塔那样"）：出手方式搬回右上，爬塔同款两排大钮（17 号字 / 50 高）。
#   v63h2（用户："暂时不用加速"）：快进钮与倍速逻辑撤掉——只留布局，出手节奏照旧。
var _mode_btn: Button = null
# v10（用户："游历战斗界面加一个 2倍加速【4倍不加】"）：［快进 ×1/×2］——摆在第二排中间
var _speed_btn: Button = null

var _root: Control = null
var _bar_p: ProgressBar = null
var _bar_e: ProgressBar = null
var _chip_p = null           # v54：我方负面状态的小图标
var _chip_e = null           # v54：敌方负面状态的小图标
var _txt_p: Label = null
var _txt_e: Label = null
var _mrows: Array = []        # v63j（爬塔同款）：每人一条 {nm, bar, rage, hp}——名字+条+怒气小金条+数值
var _erow: Dictionary = {}    # v63c：敌方一行 {nm, bar, hp}——名字+条+数值并排
var _art_line: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bars()

func _build_bars() -> void:
	_root = Control.new()
	# v63j（用户："血条太短了，就按爬塔那个战斗界面来"）：整体照爬塔重排——
	#   敌方＝名字居中（24 号）＋420 宽大条（数值画在条里）＋条下居中小字；
	#   我方每人一行＝名字（16 号）＋200 宽绿条＋怒气小金条＋数值。
	#   单人/多人统一"每人一行"；老的单人总条（_bar_p/_txt_p）退役隐藏。
	_root.position = Vector2(20, 120)
	_root.size = Vector2(680, 340)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	# v63j：单人/多人统一"每人一行"——老的单人总条与文案行退役（恒藏，留作兜底不删）
	_txt_p = UiKit.make_label(_root, Vector2(0, 314), Vector2(200, 18), 13, UiKit.INK)
	UiKit.set_text(_txt_p, "")
	_txt_p.visible = false
	# v63j：敌方照爬塔——名字居中 + 420 宽大条 + 数值画在条里；多人段"全队：…"走条下居中
	_txt_e = UiKit.make_label(_root, Vector2(130, 60), Vector2(420, 18), 13, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.62))
	_txt_e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.set_text(_txt_e, "")
	_erow = {
		"nm": UiKit.make_label(_root, Vector2(0, 0), Vector2(680, 34), 24, UiKit.INK),
		"bar": _make_bar(Vector2(130, 40), Vector2(420, 16), Color(0.68, 0.28, 0.22)),
		"hp": UiKit.make_label(_root, Vector2(130, 40), Vector2(420, 16), 12, Color(0.96, 0.94, 0.90)),
	}
	(_erow["nm"] as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(_erow["hp"] as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(_erow["hp"] as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	(_erow["nm"] as Label).text = "敌"

	# v63j（爬塔同款）：每人一行——名字 + 200 宽条 + 怒气小金条 + 数值
	_mrows = []
	for i in 3:
		var ry := 112.0 + float(i) * 56.0
		var nm := UiKit.make_label(_root, Vector2(0, ry), Vector2(150, 24), 16, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.8))
		var bar := _make_bar(Vector2(154, ry + 4.0), Vector2(200, 14), Color(0.34, 0.56, 0.34))
		var rage := _make_bar(Vector2(154, ry + 23.0), Vector2(200, 5), Color(0.85, 0.72, 0.25))
		var hp := UiKit.make_label(_root, Vector2(360, ry), Vector2(150, 24), 13, UiKit.INK)
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_mrows.append({"nm": nm, "bar": bar, "rage": rage, "hp": hp})

	# v63j：退役的总条——留一个藏在角落的桩子，_update_bars 只拿它当"建好了"的哨兵
	_bar_p = _make_bar(Vector2(0, 300), Vector2(200, 10), Color(0.34, 0.56, 0.34))
	_bar_p.visible = false

	# v54：两边血条底下各一排负面状态的小图标（一个字一块）
	_chip_p = StatusChips.new()
	_chip_p.position = Vector2(0, 284)
	_chip_p.size = Vector2(420, 20)
	_chip_p.cell = 17.0
	_chip_p.max_n = 13
	_root.add_child(_chip_p)
	_chip_e = StatusChips.new()
	_chip_e.position = Vector2(130, 84)
	_chip_e.size = Vector2(420, 20)
	_chip_e.cell = 17.0
	_chip_e.max_n = 13
	_root.add_child(_chip_e)

	_art_line = UiKit.make_label(_root, Vector2(0, 310), Vector2(680, 28), 16, UiKit.SEAL)
	UiKit.set_text(_art_line, "")

	# v63h（"战斗就爬塔那样"）：右上改两排大钮，照爬塔的位子与字号（17 号 / 50 高）：
	#   第一排［出手方式］（自动/手动），第二排［战报］＋［敌情］。
	#   x 从 288 铺到 708，舞台顶上的盘缠/节点标签（x≤438、y≤52）不被压到。
	var vpw := size.x if size.x > 8.0 else get_viewport_rect().size.x
	var dk := StyleBoxFlat.new()
	dk.bg_color = Color(0.21, 0.19, 0.20, 0.92)
	dk.set_corner_radius_all(8)

	_mode_btn = Button.new()
	_mode_btn.focus_mode = Control.FOCUS_NONE
	_mode_btn.position = Vector2(vpw - 280.0, 10.0)
	_mode_btn.size = Vector2(268, 50)
	_mode_btn.pressed.connect(_on_mode_toggle)
	_paint_mode_btn()
	_mode_btn.visible = false
	add_child(_mode_btn)

	_log_btn = Button.new()
	_log_btn.text = "战报"
	_log_btn.focus_mode = Control.FOCUS_NONE
	_log_btn.position = Vector2(vpw - 432.0, 64.0)
	_log_btn.size = Vector2(96, 50)
	_log_btn.add_theme_font_size_override("font_size", 17)
	_log_btn.pressed.connect(_toggle_log)
	_log_btn.visible = false
	add_child(_log_btn)

	_info_btn = Button.new()
	_info_btn.focus_mode = Control.FOCUS_NONE
	_info_btn.position = Vector2(vpw - 148.0, 64.0)
	_info_btn.size = Vector2(136, 50)
	_info_btn.add_theme_font_size_override("font_size", 17)
	_info_btn.text = "敌情（招数）"
	_info_btn.pressed.connect(_show_info)
	_info_btn.visible = false
	add_child(_info_btn)

	# v10：［快进 ×1/×2］——第二排正中那道缝（战报 96 ＋ 快进 176 ＋ 敌情 136 ＝ 正好排满）
	_speed_btn = Button.new()
	_speed_btn.focus_mode = Control.FOCUS_NONE
	_speed_btn.position = Vector2(vpw - 330.0, 64.0)
	_speed_btn.size = Vector2(176, 50)
	_speed_btn.add_theme_font_size_override("font_size", 17)
	_speed_btn.pressed.connect(_on_speed_toggle)
	_speed_btn.visible = false
	_paint_speed_btn()
	add_child(_speed_btn)

	for b in [_log_btn, _info_btn, _speed_btn]:
		(b as Button).add_theme_stylebox_override("normal", dk)
		(b as Button).add_theme_stylebox_override("hover", dk)
		(b as Button).add_theme_stylebox_override("pressed", dk)
		(b as Button).add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		(b as Button).add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))

	# ㊿：出手方式（手动／自动）那颗钮**已搬回右上**（v63h，爬塔同款）——挂在第一排。
	#   状态存在静态 last_manual 里，这里每手/每帧跟它同步（见 _choose_action / _await_card）。

# v63h：出手方式——与舞台旧钮同一份状态（静态 last_manual），只是把钮摆到了右上
func _on_mode_toggle() -> void:
	last_manual = not last_manual
	_paint_mode_btn()
	if last_manual:
		UiKit.float_text(self, "出手方式：手动——轮到你时点牌、往上划发动", UiKit.GOLD, 172.0)
	else:
		UiKit.float_text(self, "出手方式：自动出手（照旧）", UiKit.GOLD, 172.0)

func _paint_mode_btn() -> void:
	if _mode_btn == null:
		return
	UiKit.set_btn_text(_mode_btn, ("出手：手动出牌（点我切）" if last_manual else "出手：自动（点我切）"))
	var manual := last_manual
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.62, 0.20, 0.16, 0.95) if manual else Color(0.21, 0.19, 0.20, 0.92)
	sb.set_corner_radius_all(8)
	_mode_btn.add_theme_stylebox_override("normal", sb)
	_mode_btn.add_theme_stylebox_override("hover", sb)
	_mode_btn.add_theme_stylebox_override("pressed", sb)
	_mode_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_mode_btn.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88) if manual else Color(0.94, 0.91, 0.84))
	_mode_btn.add_theme_font_size_override("font_size", 17)

# ============================================================
# v10：［快进］——1× ⇄ 2×（用户："加一个 2倍加速【4倍不加】"）
#   v63h2 那次"暂时不用加速"撤掉的是这一块；现在按用户点的口径只做 **2 倍**一档。
#   只压"等一会儿"（_wait）与"招式播放"（_move_spd）——数值/概率/回合数一个字没动。
# ============================================================
func _on_speed_toggle() -> void:
	SPEED = next_speed(SPEED)
	_paint_speed_btn()
	print("[游历战斗] 快进 ×", SPEED)
	UiKit.float_text(self, ("快进 ×2——这一场打得快些" if SPEED > 1.0 else "快进关了（×1）"), UiKit.GOLD, 172.0)

func _paint_speed_btn() -> void:
	if _speed_btn == null:
		return
	var on := SPEED > 1.0
	UiKit.set_btn_text(_speed_btn, ("快进 ×2（点我切）" if on else "快进 ×1（点我切）"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.46, 0.30, 0.95) if on else Color(0.21, 0.19, 0.20, 0.92)
	sb.set_corner_radius_all(8)
	_speed_btn.add_theme_stylebox_override("normal", sb)
	_speed_btn.add_theme_stylebox_override("hover", sb)
	_speed_btn.add_theme_stylebox_override("pressed", sb)
	_speed_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_speed_btn.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88) if on else Color(0.94, 0.91, 0.84))
	_speed_btn.add_theme_font_size_override("font_size", 17)

func _make_bar(pos: Vector2, sz: Vector2, col: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	# v63j：ProgressBar 有主题最小高（实测默认 27，压不掉）——真身留 27 高、
	#   整体按 scale.y 压到想要的条高。视觉上与爬塔的 ColorRect 细条一模一样。
	bar.size = Vector2(sz.x, 27.0)
	bar.scale = Vector2(1.0, sz.y / 27.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(int(minf(6.0, sz.y * 0.3)))
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.16, 0.14, 0.14, 0.85)
	back.set_corner_radius_all(int(minf(6.0, sz.y * 0.3)))
	bar.add_theme_stylebox_override("background", back)
	_root.add_child(bar)
	return bar

# ============================================================
# v36（用户："游历增加战斗记录"）：**战报**——这一场从头到尾都记一笔
#
# 出村战斗（battle_lite）一直有一块常显的 4 行战报；游历这边以前只有转瞬即逝的
#   招式横幅与飘字，打完就什么都不剩，想回头看"刚才那一手挨了多少"没法查。
# 现在：
#   · 每次出手/挨打/闪避/自爆/毒发/倒下/胜负都往 _log_lines 里记一行（封顶 200 行）
#   · 右上角［战报］一按，弹一块可滚动、**自动跟到底**的面板（RichTextLabel）
#   · 面板开着也不挡回合（不像［敌情］那样停表）——记录是"回头看"的东西
# 记法（一行一件事，方便扫）：
#   「谁」招式 → 挨打的人 −伤害［暴击/闪避/护体］
# 想加新事件：调 _blog(文本, 颜色号) 就行，颜色号见 _log_col。
# ============================================================
var _log_lines: Array = []       # 每项 {"t": 文本, "c": 颜色号}
var _log_open := false
var _log_panel: Control = null
var _log_rt: RichTextLabel = null
var _log_btn: Button = null
var _cur_move := ""              # 当前这一手的招式名（_foe_take / _foe_show_hit 记账用）
var _cur_crit := false           # 这一手是不是暴击（同上）
# v58：当前这一手的**伤害属性**（空串＝物理）。跟 _cur_move/_cur_crit 一样是"先把这一手
#   的属性摆好，再让 _foe_take / _roll_p_damage 去读"——省得把 elem 一路往下传。
#   玩家那一手由 _strike 写。
var _cur_elem := ""
#   ⚠ **敌人的出手另用一格**：`_cur_elem` 在玩家出手时被写成玩家的元素，而反伤/反刺
#     那几路会在玩家出手**途中**把伤害打回玩家身上（走 `_p_mitigate`）——
#     共用一格的话那些反伤会被误判成"元素伤害、不吃防御"。所以两支分开。
var _foe_cur_elem := ""
const LOG_MAX := 200

# 颜色号 → 颜色（面板里给行上色；不给就用默认墨色）
func _log_col(c: String) -> Color:
	match c:
		"hit":
			return Color(0.72, 0.16, 0.12)     # 我方挨打 / 伤害
		"deal":
			return Color(0.20, 0.42, 0.24)     # 我打出去
		"dodge":
			return Color(0.42, 0.62, 0.86)     # 闪避
		"heal":
			return Color(0.30, 0.52, 0.32)     # 回复
		"crit":
			return Color(0.72, 0.52, 0.12)     # 暴击 / 大招
		"bomb":
			return Color(0.85, 0.45, 0.16)     # 自爆
		"sys":
			return Color(0.40, 0.38, 0.42)     # 开场/收尾/倒下
	return UiKit.INK

# 记一行（c＝颜色号；面板开着就当场追加）
func _blog(t: String, c := "") -> void:
	if t == "":
		return
	_log_lines.append({"t": t, "c": c})
	while _log_lines.size() > LOG_MAX:
		_log_lines.remove_at(0)
	if _log_rt != null and is_instance_valid(_log_rt):
		_log_rt.append_text("\n" + _log_bb(t, c))
	# 也打进控制台——问"刚才那手打了多少"时能直接翻日志
	print("[游历战斗] ", t)

func _log_bb(t: String, c: String) -> String:
	var col := _log_col(c)
	return "[color=#%02x%02x%02x]%s[/color]" % [int(col.r * 255.0), int(col.g * 255.0), int(col.b * 255.0), t]

# 一行"谁 招式 → 谁 −N"
func _log_hit(who: String, move: String, target: String, dmg: int, c := "hit", extra := "") -> void:
	var mv := "" if move == "" else " " + move
	var tail := "" if extra == "" else "（" + extra + "）"
	_blog(who + mv + " → " + target + " −" + str(dmg) + tail, c)

# ［战报］面板：开关（不挡回合）
func _toggle_log() -> void:
	_log_open = not _log_open
	if _log_open:
		_open_log()
	else:
		_close_log()

func _open_log() -> void:
	_close_log()
	var vp := size if size.x > 8.0 else get_viewport_rect().size
	var veil := ColorRect.new()
	veil.color = Color(0.06, 0.05, 0.07, 0.28)
	veil.position = Vector2.ZERO
	veil.size = vp
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 不挡回合：只盖住画面，不接输入
	veil.z_index = 120   # v71f：压在演员之上（双保险）
	add_child(veil)
	var panel := Panel.new()
	panel.position = Vector2(36.0, 150.0)
	panel.size = Vector2(vp.x - 72.0, vp.y - 330.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.86, 0.97)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.45)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	veil.add_child(panel)
	var ttl := UiKit.make_label(panel, Vector2(0, 10), Vector2(panel.size.x, 30), 20, UiKit.INK)
	UiKit.set_text(ttl, "战  报（这一场）")
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.scroll_following = true
	rt.position = Vector2(14.0, 46.0)
	rt.size = Vector2(panel.size.x - 28.0, panel.size.y - 60.0)
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.add_theme_font_size_override("bold_font_size", 14)
	panel.add_child(rt)
	var txt: Array = []
	for it_v in _log_lines:
		var it: Dictionary = it_v
		txt.append(_log_bb(str(it.get("t", "")), str(it.get("c", ""))))
	rt.text = "\n".join(PackedStringArray(txt))
	_log_rt = rt
	_log_panel = veil
	if _log_btn != null:
		_log_btn.text = "收起战报"

func _close_log() -> void:
	if _log_panel != null and is_instance_valid(_log_panel):
		_log_panel.queue_free()
	_log_panel = null
	_log_rt = null
	if _log_btn != null:
		_log_btn.text = "战报"

# ---- 自绘招式横幅（不依赖 fx_layer） ----
func _banner(txt: String, col: Color) -> void:
	if txt == "":
		return
	var lb := UiKit.make_label(self, Vector2(60, 520), Vector2(600, 52), 30, col)
	UiKit.set_text(lb, txt)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(lb, "modulate:a", 1.0, 0.10)
	tw.tween_interval(0.80)
	tw.tween_property(lb, "modulate:a", 0.0, 0.30)
	tw.finished.connect(lb.queue_free)

# ============================================================
# ㊷ 敌阵容：上多人
#
# 一个敌＝只有前排，行为跟以前一模一样（老表不用改）。
# 多个敌＝按数组下标排：_foes[0] 最前排、_foes[1] 中排、_foes[2] 后排。
#   · 我方普攻只打"对面最靠前的活人"——前排替后排挡刀
#   · 带 target 的招式（mid/back/sweep）按 GameData.target_reach 越过前排
#   · sweep 打全部活着的
#   · 敌人一个一个出手（按各自 spd 排在玩家之后）
#
# 状态放在 _foes 每一项里（hp/atk/spd/arts/ult/affixes/rage/guard…），
# 下面那批 _foe_*() 访问器都指向"当前聚焦的那一个"（_focus），
# 所以老代码里那些 _foe_hp 之类的地方只要加一对括号就能继续用。
# ============================================================

var _foes: Array = []
var _foe_nodes: Array = []
var _focus := 0

# ---- 兼容访问器：一律指向 _focus 那一只 ----
func _cur() -> Dictionary:
	if _foes.is_empty():
		return {}
	return _foes[clampi(_focus, 0, _foes.size() - 1)]

func _foe_hp() -> int:
	return int(_cur().get("hp", 0))

func _foe_hp_max() -> int:
	return int(_cur().get("hp_max", 1))

func _foe_atk() -> int:
	return int(_cur().get("atk", 8))

func _foe_spd() -> int:
	# ㊿：**游历敌人的速度是另一个量级**——data_journey 里写的是 88~110（"100＝常人"），
	#   而村里角色是 9/10/12、出村战斗的怪是 9~28（"10＝常人"）。
	#   不改的话：正式趟里玩家速度 10 对上敌人 95，永远后手，
	#   而且"快一倍多打一下"那条新规矩会把额外普攻全判给敌人。
	#   这里统一折到全村/全塔用的那个量级（÷10 → 8.8~11），
	#   于是"速度＝谁先出手"这句面板说明才真的成立。
	#   要整体调游历敌人的快慢，改 tuning 的 journey/foe_spd_div 即可。
	return maxi(1, int(round(float(int(_cur().get("spd", 95))) / JOURNEY_FOE_SPD_DIV)))

func _foe_name() -> String:
	return str(_cur().get("name", "敌人"))

func _foe_weapon() -> String:
	return str(_cur().get("weapon", "dagger"))

func _set_foe_hp(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["hp"] = maxi(0, v)

# ---- 建阵容 ----
# 多少人、都是谁：
#   · node["foe_count"] 明说了就按它（1~3）
#   · 没说明：精英 2 人、首领 3 人、其余 1 人（遭遇战那种临时敌走 _state.last_foe，也是 1 人）
# 多出来的人叫"副手"，从主敌身上派生。
# v46（用户："可以跟站位一样 前排肉后排伤害高，boss 也可以有特定怪物 肉盾 boss 前排 /
#   伤害高的 boss 后排，花样可以多一点"）：**改成"按站位分账"**——
#   · 前排＝盾手（血厚、打不疼）· 中排＝刀手（中庸）· 后排＝杀手（血薄、打得疼）
#   · 站位型（GameData.foe_archetype）决定**主敌自己**站哪一排，副手补剩下的位置；
#     肉盾主敌站前排、高伤主敌躲后排——想先斩他，要么有"打后排"的武学，要么带苏青鸾（绕前排）
#   · ⚠ **整组的总血池与总攻击跟旧口径一样**（旧表 本体 1.0 ＋ 中排 0.6 ＋ 后排 0.4；
#     新的走 GameData.foe_row_plan 归一），所以难度不变，变的是"先打谁、谁最疼"
#   · 列表**按排号排**（下标即排号——duel_battle 的 _row_of / 挑目标全靠这条）
const FOE_MID_RATIO := GameData.FOE_MID_RATIO    # ㊼：真源在 game_data（v46 起只用于"整组总账"）
const FOE_BACK_RATIO := GameData.FOE_BACK_RATIO  # ㊼：同上
const FOE_WEAPON_BY_ROW := ["spear", "dual", "dagger"]

# 这场仗的"站位型"取哪个：拿敌人自己的数据现算——**同一场重打看到的是同一套**
#   （不用随机数：不然撤退重进就换阵，玩家没法预先准备）
func _foe_seed(node: Dictionary, foe: Dictionary) -> int:
	var s := str(node.get("name", ""))
	return int(foe.get("hp", 60)) + int(foe.get("atk", 8)) * 7 + s.length() * 3

func _compose_foes(node: Dictionary, foe: Dictionary) -> Array:
	var n := 1
	if node.has("foe_count"):
		n = clampi(int(node["foe_count"]), 1, 3)
	elif not foe.is_empty():
		# ㊿：**新手游历（引子趟）只上单怪**——不加副手。
		#   引子是全游戏第一场仗，两三个人围着打会直接劝退；
		#   等正式趟（出征屏那条路）再按精英/首领上 2~3 人。
		if _state != null and str(_state.mode) == "intro":
			n = 1
		elif bool(node.get("boss", false)):
			n = 3
		elif bool(node.get("elite", false)):
			n = 2
	var base_name := str(node.get("name", "敌人"))
	var base_hp := float(foe.get("hp", 60))
	var base_atk := float(foe.get("atk", 8))
	# v46：站位安排 → 折算（前排肉 · 后排高伤；整组总账不变）
	var arch: int = GameData.foe_archetype(_foe_seed(node, foe))
	var layout: Array = GameData.foe_layout(n, arch)
	var rows2: Array = []
	for e_v in layout:
		rows2.append(int((e_v as Dictionary).get("row", 0)))
	var plan: Array = GameData.foe_row_plan(rows2)
	var sub_color := [[0.34, 0.30, 0.36], [0.40, 0.34, 0.28], [0.30, 0.26, 0.34]]
	# v47：单人关也摇一个**体型**（肉盾/寻常/高伤）——血×攻 的总账不变（见 GameData.FOE_SOLO）。
	#   ⚠ 引子趟（新手第一场仗）**强制寻常**：那是教学关，不该一上来就撞肉盾/高伤。
	var solo: Dictionary = {}
	if layout.size() <= 1 and not _is_intro():
		solo = GameData.foe_solo_profile(_foe_seed(node, foe))
	var out: Array = []
	for i in layout.size():
		var le: Dictionary = layout[i]
		var is_main := bool(le.get("main", true))
		var row := int(le.get("row", 0))
		var pl: Dictionary = plan[i]
		var d: Dictionary = foe.duplicate(true)
		d["hp"] = maxi(1, int(round(base_hp * float(pl.get("hp", 1.0)) * float(solo.get("hp", 1.0)))))
		d["atk"] = maxi(1, int(round(base_atk * float(pl.get("atk", 1.0)) * float(solo.get("atk", 1.0)))))
		# 防御按站位给（前排厚、后排薄）：这里只给**倍数**，绝对值留给 _build_foes 现算
		#   （引子趟的 INTRO_EASE 是在那边折攻击的，这里若写死绝对值会把那份折扣吃掉）
		d["def_mul"] = float(pl.get("def", 1.0)) * float(solo.get("def", 1.0))
		d["row"] = row
		d["solo_cn"] = str(solo.get("cn", ""))   # v47：单人关的体型名（多人关是空串）
		if is_main:
			d["name"] = base_name
		else:
			# 副手换个颜色、换个兵器、名字带上它的位置（"盾手/刀手/杀手"），场上一眼分得开
			d["weapon"] = str(FOE_WEAPON_BY_ROW[clampi(row, 0, FOE_WEAPON_BY_ROW.size() - 1)])
			d["name"] = base_name + "·" + GameData.foe_row_sub(row)
			d["color"] = sub_color[clampi(row, 0, sub_color.size() - 1)]
			d["scale"] = maxf(0.7, float(foe.get("scale", 1.0)) * 0.92)
			# 副手不带招数/大招：招数是主敌的成名技
			d["arts"] = []
			d["ult"] = {}
		out.append(d)
	return out

# ㊿：本场的敌人强度系数。引子趟（mode=="intro"）按 INTRO_EASE 打折——
#   血量走 FOE_HP_MULT × INTRO_EASE，攻击走 INTRO_EASE（攻击本来就没有别的系数）。
func _is_intro() -> bool:
	return _state != null and str(_state.mode) == "intro"

func _hp_mult() -> float:
	return FOE_HP_MULT * (INTRO_EASE if _is_intro() else 1.0)

func _atk_ease() -> float:
	return INTRO_EASE if _is_intro() else 1.0

func _build_foes(node: Dictionary, foe: Dictionary) -> void:
	_foes.clear()
	var raw: Array = []
	if node.has("foes") and node["foes"] is Array and not (node["foes"] as Array).is_empty():
		raw = node["foes"] as Array
	elif not foe.is_empty():
		raw = _compose_foes(node, foe)
	else:
		raw = [{}]
	var nm := str(node.get("name", "敌人"))
	for i in raw.size():
		if _foes.size() >= 3:
			break   # 最多三人（前排/中排/后排）
		var f: Dictionary = raw[i] if raw[i] is Dictionary else {}
		# 名字：数据里写了就用，没写就用节点名（多人时加序号，免得两个同名看混）
		var fn := str(f.get("name", ""))
		if fn == "":
			fn = nm if i == 0 else (nm + " " + str(i + 1))
		var hp := maxi(1, int(float(f.get("hp", 60)) * _hp_mult()))
		var f_atk := maxi(1, int(round(float(f.get("atk", 8)) * _atk_ease())))
		# v46：防御＝（按攻击折算的基准防御）× 站位倍数（前排厚、后排薄）
		var f_def := maxi(0, int(round(float(GameData.foe_def(f_atk, float(f.get("def", 0)))) * float(f.get("def_mul", 1.0)))))
		_foes.append({
			"name": fn,
			"weapon": str(f.get("weapon", "dagger")),
			"hp": hp, "hp_max": hp,
			"atk": f_atk,
			# v35：防御值——表里带了就用，没带按攻击折一半（GameData.foe_def）
			"def": f_def,
			"spd": int(f.get("spd", 95)),
			"hat": str(f.get("hat", "toujin")),
			"cape": str(f.get("cape", "none")),
			"color": f.get("color", [0.5, 0.3, 0.28]),
			"scale": float(f.get("scale", 1.0)),
			# v46：排号＝站位（前排肉 · 后排高伤）；副手是"补位"的，排号由 _compose_foes 定
			"row": int(f.get("row", i)),
			"solo_cn": str(f.get("solo_cn", "")),   # v47：单人关的体型名（肉盾/寻常/高伤）
			# ============================================================
			# v58：**五行**也要搬过来**（塔那边第 400 关起由 tower.gd 给 `elem`；
			#   游历的怪以后也可以在自己那一行里写）。
			#   ⚠ 这个字典是**白名单**式的：源里有的键，这里不写就**丢了**——
			#     第一版就漏了 `elem`，探针里打出来的 "敌人 elem=" 是空的才抓到
			#     （少了它，敌人打你就永远走物理路、你的五行抗性一辈子用不上）。
			# ============================================================
			"elem": str(f.get("elem", "")),
			"metal_res": float(f.get("metal_res", 0)),
			"water_res": float(f.get("water_res", 0)),
			"wood_res": float(f.get("wood_res", 0)),
			"fire_res": float(f.get("fire_res", 0)),
			"earth_res": float(f.get("earth_res", 0)),
			"metal_dmg": float(f.get("metal_dmg", 0)),
			"water_dmg": float(f.get("water_dmg", 0)),
			"wood_dmg": float(f.get("wood_dmg", 0)),
			"fire_dmg": float(f.get("fire_dmg", 0)),
			"earth_dmg": float(f.get("earth_dmg", 0)),
			# 招数/词缀：数据写在敌人项里就用它，否则沿用节点级的
			"arts": (f.get("arts", node.get("arts", [])) as Array).duplicate(true),
			"ult": (f.get("ult", node.get("ult", {})) as Dictionary).duplicate(true),
			"affixes": (f.get("affixes", node.get("affixes", [])) as Array).duplicate(),
			# 场上的临时状态
			"art_i": 0, "art_cd": 0, "rage": 0,
			"guard": 0, "guard_cut": 0.0, "next_mult": 1.0,
			"stack": 0.0, "poison": 0,
		})

# 建头像节点：排号越后站得越远（跟站位那套一致，越后排越靠近画面中央）
func _make_foe_node(i: int) -> void:
	var f: Dictionary = _foes[i]
	# v65：按敌人名字取"Q版原型键"（有图就用 Q版，没图工厂自动退回火柴人）
	var n := ActorFactory.make_enemy(ActorFactory.enemy_key(str(f.get("name", ""))))
	# v71c：染色只给火柴人用（那时候是没脸的线条人，靠颜色区分敌我）。
	#   Q版 是画好的图，再乘一层色会发灰发白、跟主角不是一个画风——用户一眼就看出来了。
	var wcol: Array = f.get("color", [0.5, 0.3, 0.28])
	if wcol.size() >= 3 and not bool(n.get("is_q_art")):
		n.body_color = Color(float(wcol[0]), float(wcol[1]), float(wcol[2]))
	n.set_equipment(str(f.get("weapon", "dagger")), str(f.get("hat", "toujin")), str(f.get("cape", "none")))
	var scl := maxf(0.5, float(f.get("scale", 1.0)))
	n.scale = Vector2(-scl, scl)
	var tgt := _foe_slot_pos(i)
	n.position = Vector2(1500.0, tgt.y)
	add_child(n)
	_foe_nodes.append(n)

# 第 i 个敌人站哪儿：0 号在最前（最靠我方），往后依次往右上退一点。
# v63l（取证数据：两个敌人开场就叠在 (510,950)）：基准用**写死的阵位原点**，
#   不能拿 _e_base 现算——聚焦换人时 _e_base 会跟着换，拿它当基准会把全队
#   站位挤成一团（后位怪第一次出招就被拽回 0 号位，再也分不开）。
func _foe_slot_pos(i: int) -> Vector2:
	return Vector2(510.0 + float(i) * 60.0, 950.0 - float(i) * 26.0)

func _enter_foes() -> void:
	var tw := create_tween()
	var added := 0
	for i in _foe_nodes.size():
		var n = _foe_nodes[i]
		if n == null or not is_instance_valid(n):
			continue
		# v71c：tween_property 可能返回 null（节点已释放／tween 已结束），
		#   链式 .set_trans() 会当场炸掉整个入场流程——「战斗卡死」的来源之一
		var pt = tw.parallel().tween_property(n, "position", _foe_slot_pos(i), 0.55)
		if pt != null:
			pt.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			added += 1
	if added == 0:
		return   # 一条都没加上，await 会永远等下去
	await tw.finished

# 聚焦到某个敌人（所有 _foe_* 访问器都跟着它走）。
# _foe 这个"当前敌人节点"也跟着换——老代码里那些 _foe.play_hit() 之类就不用动。
func _focus_on(i: int) -> void:
	_focus = clampi(i, 0, maxi(0, _foes.size() - 1))
	if _focus < _foe_nodes.size():
		_foe = _foe_nodes[_focus]
		_e_base = _foe_slot_pos(_focus)   # v63l：聚焦换人，站位基准跟着换——不然每只怪的进退都挂在 0 号位上

func _foe_alive(i: int) -> bool:
	if i < 0 or i >= _foes.size():
		return false
	return int((_foes[i] as Dictionary).get("hp", 0)) > 0

func _foes_alive() -> int:
	var n := 0
	for f in _foes:
		if int((f as Dictionary).get("hp", 0)) > 0:
			n += 1
	return n

# ㊿：敌人这一手"点名"到哪名我方——按招式自己写的 target 算排号。
#   普攻不走这里（那是 reaches 0，见 _strike 开头的 _pick_ally_target(0)）。
#   ㊿：**点名＝破闸**——写了 target: mid/back/sweep 的招数/大招就是要越过前排，
#     所以 reaches ≥ 1 时传 bypass（这也正是 1888 行那句注释的意思）。
#   单人时无论怎么挑都只会挑到 0 号，与老行为一致。
func _focus_foe_target_on_ally(mv: Dictionary) -> void:
	var reaches := 0
	if not mv.is_empty():
		reaches = GameData.target_reach(str(mv.get("target", "front")))
	var ta := _pick_ally_target(reaches, reaches >= 1)
	if ta >= 0:
		_p_focus_on(ta)

func _front_foe() -> int:
	for i in _foes.size():
		if _foe_alive(i):
			return i
	return -1

# v9（用户："苏 被动带匕首不打后排"）：最靠后还站着的敌人——自带 row_priority="back" 的普攻落点。
#   与 _front_foe 对称；一只敌（下标 0）时两者同值，老场面一字不变。
func _back_foe() -> int:
	for i in range(_foes.size() - 1, -1, -1):
		if _foe_alive(i):
			return i
	return -1

# 我方出手该打谁：默认打最前排；带 target 的招式按够到距离越排。
# reaches = 0/1/2（GameData.target_reach 给）
#   v48（用户："全修"）：**mid/back 要真的"绕过去"**——以前这里是"从前往后找第一个
#   落在 reach 之内的"，而最前排天然满足 `i <= reaches`，于是**破阵刀法/穿云箭法
#   永远打在当面那个身上**：字段写了"绕过前排直取后排"，实现却等于没写（描述与行为不符）。
#   现在与苏青鸾「洞察」的 row_prio="back" 同一条规矩：**在够得着的排里挑站得最靠后的那只**。
#     · front（reach 0）→ 最前排（不变）
#     · mid  （reach 1）→ 中排那只（中排没了就退回前排）
#     · back （reach 2）→ 最后面那只（绕过当面挡刀的）
func _target_foe(reaches: int, sweep: bool) -> int:
	if sweep:
		return _front_foe()   # 群伤由调用方遍历所有活人，这里只用于"打谁当主目标"
	var best := -1
	for i in _foes.size():
		if not _foe_alive(i):
			continue
		if i <= reaches:
			best = i          # 越往后越"靠后"，循环到最后一个就是最靠后的那只
	return best if best >= 0 else _front_foe()

# ㊿：把我方按这一趟带的人装出来。
#   第 0 名用舞台递进来的那个 walker；第 1、2 名**优先用舞台上已经站着的同伴**
#   （party_nodes）——不然"路上三个 + 打起来又开两个"会同时出现五个小人。
#   舞台上没有（比如单人趟、或别处直接 new 出来的战斗）才现开节点。
#   单人时结果与老代码完全一致：一个 ally、一个节点、站位还是 (210,950)。
func _compose_allies(player: Node2D, party_nodes: Array = []) -> void:
	_allies.clear()
	_ally_nodes.clear()
	_own_nodes.clear()
	# ⚠ 按**成员下标**装人，不要用 party_role_ids()：那个口会去重，
	#   万一档里有两个同 role_id 的成员，它会比 members 短，下标就错位了
	#   （舞台上的人数也按 member_count() 算，两边必须同一把尺子）。
	var n: int = mini(_state.member_count(), 3)
	for i in n:
		var m0: Dictionary = _state.member_at(i)
		var rid := str(m0.get("role_id", "player"))
		var nd: Node2D = null
		if i == 0:
			nd = player
		elif i - 1 < party_nodes.size():
			# 舞台的同伴：位置/装扮它自己管好了，战斗只借来打架
			var pv = party_nodes[i - 1]
			if pv != null and is_instance_valid(pv):
				nd = pv
		if nd == null and i > 0:
			# 现开一个（并记下来：收尾时由战斗自己负责收掉）
			nd = ActorFactory.make(str(_state.member_at(i).get("role_id", "player")))
			add_child(nd)
			nd.position = Vector2(210.0 + ALLY_ROW_DX * float(i), 950.0 + ALLY_ROW_DY * float(i))
			if nd.has_method("set_equipment"):
				nd.set_equipment(_state.weapon_of_member(_state.member_at(i)), "douli", "short")
			nd.scale = Vector2(0.94, 0.94)   # 后排略小一点，看得出层次
			_own_nodes.append(nd)
		_ally_nodes.append(nd)
		_allies.append(_setup_ally(rid, nd, i))
	_p_focus_on(0)

# 把一名成员装成"能打的样子"（原来 run() 里那一段，改成按成员逐份跑）
# v64：大招 cut-in——放这个人的「人物演出」片（assets/clips/<角色id>_clip.ogv）。
#   · **非阻塞**：战斗照走，片只压在上层 2.6 秒就收（片源 5 秒，别把整场战斗糊住）
#   · 想整段关掉：DuelBattle.ult_cutin = false（或只想改时长：ult_cutin_len）
static var ult_cutin := false   # v65：片源是"立绘演出"，立绘撤了就一起先关（true 可随时开回来）
static var ult_cutin_len := 2.6

func _ult_cutin(m: Dictionary) -> void:
	if not ult_cutin or _fx == null:
		return
	var stream: VideoStream = CharArt.clip(str(m.get("role_id", "")))
	if stream == null:
		return
	var cv = ArtClip.new()
	_fx.add_child(cv)
	cv.play(stream, _fx.size, ult_cutin_len, false)


func _setup_ally(rid: String, nd: Node2D, idx: int) -> Dictionary:
	var al := _blank_ally()
	al["role_id"] = rid
	al["row"] = idx
	al["node"] = nd
	al["base"] = Vector2(210.0 + ALLY_ROW_DX * float(idx), 950.0 + ALLY_ROW_DY * float(idx))
	var acc: Dictionary = GameState.role_data(rid)
	al["name"] = str(acc.get("name", rid))
	# 属性：走 run_state 的"按成员算"那一口（含随身三样 + 天赋 + 羁绊）
	var st: Dictionary = _state.stats_of(_state.member_at(idx))
	al["atk"] = float(st.get("atk", 10))
	# v62o：短绳签——**每过一节攻击力 -2%**（可叠，`fate_atk_mul()` 里算好；不拿这张签恒 1.0）
	var fam := _state.fate_atk_mul()
	if not is_equal_approx(fam, 1.0):
		al["atk"] = maxf(1.0, float(al["atk"]) * fam)
	al["dmg"] = float(st.get("dmg", 0))
	al["spd"] = int(round(float(st.get("spd", 100))))
	al["crit"] = float(st.get("crit", 5))
	# v48（用户："全修"）：**防御 / 闪避以前在这边根本没接线**——
	#   建队只抄了 atk/dmg/spd/crit，而 _p_mitigate 那边按"有 def/dodge"来处理：
	#   dodge 恒 0 → 永不闪避；def 恒 0 → 直接 return maxi(1, raw)，攻防对拼整段跳过。
	#   于是游历里堆防御/闪避（护甲、披风、羁绊、天赋「身轻如燕」…）全是白搭，
	#   而村内是生效的、游历面板还在解释这两条属性。这里补上就对齐了。
	al["def"] = float(st.get("def", 5))
	al["dodge"] = float(st.get("dodge", 5))
	# 招路
	var m: Dictionary = _state.member_at(idx)
	al["weapon"] = _state.weapon_of_member(m)
	al["arts"] = (m.get("arts", []) as Array).duplicate()
	# ㉖／㊳：自带天赋跟着角色走（真源 journey/data_roles.gd）
	#   有的自带认兵器（断枪＝用枪、洞察＝用匕首）：先看手里是什么，再判生效没
	var inn: Dictionary = Roles.innate_of(rid)
	var inn_on := Roles.innate_active(inn, str(al["weapon"]))
	var inn_hp := 0.0
	al["inn_thorn"] = 1.0
	# v9（用户："苏 被动带匕首不打后排"）：自带的 row_priority 以前**游历这边根本没接线**——
	#   「洞察」写着 row_priority "back"（持匕首时普攻绕前排直取后排），村里战斗
	#   （battle_lite._enemy_attack_index 3209 那段）照着做了，游历这边却一律 _front_foe()：
	#   于是苏青鸾拿匕首在游历里永远是"跟着打前排"，描述与行为不符。
	#   这里只把"生效中"的那一条记下来（兵器闸由 innate_active 判过），落点在 _pick_player_target。
	al["row_prio"] = ""
	if inn_on and str(inn.get("row_priority", "")) == "back":
		al["row_prio"] = "back"
	if inn_on:
		var inn_kind := str(inn.get("kind", ""))
		if inn_kind == "innate_hp_pct":
			inn_hp = float(inn.get("hp_pct", 0.0))
		elif inn_kind == "thorn_up":
			al["inn_thorn"] = 1.0 + float(inn.get("v", 0.0))
	# v7：运签与被动——气血上限先算（苏青鸾的"换命"在这里扣）
	# ㊿：按角色过滤——专属卡只对卡上写的那个角色生效；普通/特殊谁都有份
	var fb: Dictionary = _state.buff_fx(rid)
	# ㊿z5：专武功法那条"机制"并进本人这份 fx——游历这边所有读 _fx_buff 的地方
	#   （大招增伤 / 反刺 / 残血暴击 / 开场怒气…）自然就带上了，不用逐处改。
	for s_v in (al.get("arts", []) as Array):
		var asid := str(s_v)
		if not Cards.art_is_passive(asid):
			continue
		var pstar := GameState.role_star_of(rid)
		# ㊿z6：两栏都并（分类只是排布，引擎各读各认得的键）——随星放大
		var pmech: Dictionary = Cards.art_passive_mech_scaled(asid, pstar)
		var pfx: Dictionary = Cards.art_passive_fx_scaled(asid, pstar)
		for mk in pmech.keys():
			fb[mk] = float(fb.get(mk, 0.0)) + float(pmech[mk])
		for pk in pfx.keys():
			fb[pk] = float(fb.get(pk, 0.0)) + float(pfx[pk])
	al["fx_buff"] = fb
	var pas: Dictionary = acc.get("passive", {})
	var pkind := str(pas.get("kind", ""))
	var pv := float(pas.get("v", 0.0))
	# ㉙：键名双向兼容——passive_up（旧）/ passive_mul（v3），取大不叠加
	var pup := 1.0 + maxf(float(fb.get("passive_up", 0.0)), float(fb.get("passive_mul", 0.0)))
	al["crit_add"] = 0.0
	var hp_cut := 0.0
	if pkind == "glass_crit":
		al["crit_add"] = pv * pup
		hp_cut = float(pas.get("hp_cut", 0.0)) * maxf(0.0, 1.0 - float(fb.get("passive_up", 0.0)))
	al["cut_add"] = (pv * pup if pkind == "taken_cut" else 0.0) + maxf(float(fb.get("cut_add", 0.0)), float(fb.get("taken_cut", 0.0)))
	# v10（阅历线）：防御支「卸力」段的"受到的伤害 -N%"——与卡组那份**相加**
	#   （卡组那几条是"取大不叠加"，阅历这条是常驻养成，直接加上去更直观）
	al["cut_add"] = float(al["cut_add"]) + float(GameState.insight_fx().get("cut_add", 0.0))
	al["rage_mul"] = 1.0 + maxf(float(fb.get("rage_pct", 0.0)), float(fb.get("rage_up", 0.0)))
	if pkind == "rage_up":
		al["rage_mul"] = float(al["rage_mul"]) + pv * pup
	# ㉗：五问天赋——百折不挠（残血减伤）与剑心通明（剑/空手增伤）。
	#   两者都是"按条件现算"的，所以存下来、在出手/挨打那一刻才判，不是常驻数值。
	al["talent_cut"] = _state.talent_dmg_cut_for(m)
	al["talent_wpn"] = _state.talent_weapon_mul_for(m)
	var hpm := maxi(1, int(round(float(st.get("hp", 100)) * (1.0 + float(fb.get("hp_pct", 0.0))) * (1.0 + inn_hp) * (1.0 - hp_cut))))
	al["hp_max"] = hpm
	# ㊼：开打接当前残血——按比例折进本场（不再每场白满血）
	var cur := int(m.get("hp", hpm))
	var mmax := maxi(1, int(m.get("hp_max", hpm)))
	if cur < mmax:
		al["hp"] = maxi(1, int(round(float(hpm) * float(cur) / float(mmax))))
	else:
		al["hp"] = hpm
	al["rage"] = int(fb.get("open_rage", 0))
	al["ult"] = (acc.get("ult", {}) as Dictionary).duplicate(true)
	return al
# 一轮的出手顺序：每个活着的我方 + 每个活着的敌人，按 spd 从高到低。
# ㊿：单人时结果与以前一字不差（"p0" 顶替了原来的 "p"），三人时每个人各占一手。
# ㊿：这一手排顺序时用的速度＝基础速度 ×（轻身卡加成）。
#   轻身卡是"受击后 +20%"，且**不叠加**——所以 `hit_taken` 是个开关，不是层数。
func _ally_spd(i: int) -> float:
	var al := ally_at(i)
	if al.is_empty():
		return 100.0
	var s := float(al.get("spd", 100))
	if bool(al.get("hit_taken", false)):
		var pct := float((al.get("fx_buff", {}) as Dictionary).get("spd_pct", 0.0))
		s *= 1.0 + pct
	# ㊿：加持加速（疾风令）——按人算，所以只影响他那几手，不影响别人
	var bs := float(al.get("bless_spd", 0.0))
	if bs > 0.0:
		s *= 1.0 + bs
	# v52：「迟缓」——只影响出手顺序，不改 al.spd 本身（不然会跟加持/还原打架）
	s *= St.spd_mul(al)
	return s

# ㊿：轻身卡——"受过击"标记。判据＝这名我方掉过血（挨打／挨炸／中毒都算）。
#   比在每个扣血点各插一行可靠：扣血的路子有七八处，漏一处那张卡就有时不灵。
#   只置不清——中途被治疗回满也不该把"已经挨过打"这件事抹掉。
#   ⚠ **按人逐个判**（原来只看"当前聚焦那个"）：群攻大招和改群之后的**自爆**
#     会一次打好几个人，只置聚焦那个的话，另外两位的轻身卡就白带了。
func _mark_hit_if_hurt() -> void:
	for i in _allies.size():
		var al: Dictionary = _allies[i]
		if int(al.get("hp", 0)) <= 0:
			continue
		if float((al.get("fx_buff", {}) as Dictionary).get("spd_pct", 0.0)) <= 0.0:
			continue
		if int(al.get("hp", 0)) < int(al.get("hp_max", 1)):
			al["hit_taken"] = true

# ㊿：一轮的出手顺序。我方**不再是一人一个位子**——而是"一张能出的牌占一个位子"
#   （见 _party_slots）。每个位子的先手值取那张牌主人的速度，所以：
#     · 又快又攒了一堆技能的人，他的牌在回合里排得更靠前、还可能连出好几手
#     · 慢的人牌多也排在后面
#   单人时结果与老行为一致（一个位子，一次出手）。
func _round_order(p_first: bool, slots: Array) -> Array:
	var actor: Array = []
	for s_v in slots:
		var s: Dictionary = s_v
		actor.append({"k": str(s.get("k", "p")), "s": float(s.get("s", 100.0))})
	for i in _foes.size():
		if _foe_alive(i):
			# v52：「迟缓」也压怪的出手顺序（同样的口径：只影响排序，不改 spd 本身）
			actor.append({"k": str(i),
				"s": float(int((_foes[i] as Dictionary).get("spd", 95))) * St.spd_mul(_foes[i])})
	actor.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["s"]), float(b["s"])):
			return float(a["s"]) > float(b["s"])
		return str(a["k"]) < str(b["k"]))
	var out: Array = []
	for a in actor:
		out.append(str((a as Dictionary)["k"]))
	if not p_first:
		# 场面设定"敌先手"：我方**全体**挪到最后。
		# ⚠ 别写成"把第一个 p 开头的挪到末尾"——多个我方位子时那会把它们拆散，
		#   结果有人连出两手、有人一辈子轮不到。
		#   单人时结果与老逻辑一致：那一个挪到最后。
		var foes_first: Array = []
		var mine: Array = []
		for k in out.size():
			var sk := str(out[k])
			if sk.begins_with("p"):
				mine.append(sk)
			else:
				foes_first.append(sk)
		out = foes_first + mine
	return out

# ============================================================
# ㊿：手动／自动 · 出牌（"杀戮尖塔"那套）
#
# 手动＝轮到我方某人出手时，把他**现在能用的东西**摊成几张牌：
#   普攻（永远有）／武学（冷却好了的各一张）／大招（怒气满才有）。
#   按住一张往上划＝用这张。牌是**每手现算**的——冷却没好、怒气不满的东西
#   根本不会出现在牌面上，所以"哪个好了用哪个"是天然的。
# 自动＝照旧（大招＞武学＞普攻），但会把要用的那张牌亮一下再收，
#   让你看得见"这一手出的是什么"。
# ============================================================

# 某人这一手能用的牌：[{"k","sid","name","sub","col","who","row_cn","own_col"}]
#   k = "normal"（普攻）/ "art"（武学）/ "ult"（大招）
#   ㊿：who / row_cn / own_col —— **这张牌是谁的**。三个人轮流出手，每人各有一副手牌，
#     牌面必须写清"谁的、站哪一排"，否则三副牌长得一模一样，玩家分不出这是谁在动。
func _cards_for(ai: int) -> Array:
	var out: Array = []
	var al := ally_at(ai)
	if al.is_empty() or _state == null:
		return out
	var w := str(al.get("weapon", ""))
	var who := str(al.get("name", "我"))
	var row_cn := _row_tag(ai, _allies.size())
	var own_col: Color = ROLE_CARD_COL.get(str(al.get("role_id", "")), UiKit.INK)
	# ⚠ 怒气/大招**从这个人的字典里读**，不能走 _rage / _ult 那两个转发属性——
	#   它们读的是"当前聚焦的那个人"（_a()）。全队手牌要挨个人现算，用转发属性
	#   会把别人的怒气和别人的大招当成他的。武学冷却同理：调用方得先
	#   _state.use_member(ai)（见 _team_rows）。
	var rg := int(al.get("rage", 0))
	var ult: Dictionary = al.get("ult", {})
	out.append({
		"k": "normal", "sid": "", "name": "普攻",
		"sub": ("空手" if w == "" else str(Cards.by_id(w).get("name", w))),
		"col": UiKit.INK,
		"ai": ai, "who": who, "row_cn": row_cn, "own_col": own_col, "kind_cn": "普攻",
	})
	# 武学：冷却好了的才有
	# v53：「沉默」——武学牌这一会儿直接不摊出来（手动/自动两条路都从这份牌里挑，一处就够）
	if not St.blocks_arts(al):
		for sid_v in _state.arts:
			var sid := str(sid_v)
			if int(_state.art_cd.get(sid, 0)) > 0:
				continue
			var art: Dictionary = Cards.art_of(sid)
			if art.is_empty():
				continue
			var is_bless := str(art.get("kind", "")) == "bless"
			out.append({
				"k": "art", "sid": sid,
				"name": str(Cards.name_of(sid)),
				"sub": str(GameData.move_desc(art)),
				"col": UiKit.SEAL,
				"ai": ai, "who": who, "row_cn": row_cn, "own_col": own_col,
				"kind_cn": ("加持" if is_bless else "武学"),
			})
	# 大招：怒气满了才有
	# v53：「封招」——大招牌不摊出来（怒气留着，卡面也不给）
	if rg >= 100 and not ult.is_empty() and not St.blocks_ult(al):
		out.append({
			"k": "ult", "sid": "",
			"name": str(ult.get("name", "大招")),
			"sub": str(GameData.move_desc(ult)),
			"col": Color(0.85, 0.66, 0.20),
			"ai": ai, "who": who, "row_cn": row_cn, "own_col": own_col, "kind_cn": "大招",
		})
	return out

# 由 sid 取出那一张武学（手动划线时用；带上 _sid/_name，上层照旧读）
func _art_by_sid(sid: String) -> Dictionary:
	if sid == "" or _state == null or not _state.arts.has(sid):
		return {}
	var a: Dictionary = (Cards.art_of(sid) as Dictionary).duplicate(true)
	if a.is_empty():
		return {}
	a["_sid"] = sid
	a["_name"] = str(Cards.name_of(sid))
	return a

# ㊿：**自动那一手**的挑法与亮牌。
#   ⚠ 这里不再等玩家——等牌只发生在出手循环摊"全队手牌"那一步（_team_slot_turn）。
#     以前手动那条路也在这个函数里等，改成全队共用手牌之后，若还留着，
#     "行内［自动挑一张］"会让它**再等一次**（等于白等第二遍）。所以删掉了。
#   自动模式连大招也会亮牌（以前大招在摊牌之前就放掉了，牌面上永远看不到它）。
func _choose_action() -> Dictionary:
	var cards := _cards_for(_p_focus)
	if cards.is_empty():
		return {"k": "normal", "sid": ""}
	var want := _auto_choice(cards)
	_build_card_row(cards, false)
	_flash_card(str(want.get("k", "normal")), str(want.get("sid", "")))
	await _wait(0.32)
	_close_card_row()
	return want

# 自动这一手挑什么（手动改自动时也走这里，保证两条路挑法一致）
#   "哪张武学算就绪"只问 RunState.pick_art() 一处——不自己再扫一遍牌面
#   （扫两遍迟早会跟它走岔，亮出来的牌和真出的就不是一张）。
func _auto_choice(cards: Array) -> Dictionary:
	for c_v in cards:
		if str((c_v as Dictionary).get("k", "normal")) == "ult":
			return {"k": "ult", "sid": ""}
	var auto_art: Dictionary = _state.pick_art()
	if not auto_art.is_empty():
		return {"k": "art", "sid": str(auto_art.get("_sid", ""))}
	return {"k": "normal", "sid": ""}

# ㊿：摊牌——**全队一副手牌**，一个人一排（左边写清"谁 · 哪一排"）。
#   出牌两条路都行：**点一下**（选中弹出）或按住往上划 ≥40 像素（发动）；
#   按住不放 0.35 秒弹放大窗口看效果。
func _build_card_rows(rows: Array, interactive: bool) -> void:
	_close_card_row()
	if rows.is_empty():
		return
	# ⚠ ⚠ 尺寸**必须问视口**，不能读本控件的 size。
	#   本场战斗是 `DuelBattle.new()` 出来直接 add_child 到舞台的，而舞台不是
	#   Container（它只给自己 `size = get_viewport_rect().size`，不会传给子节点），
	#   所以**这个 Control 的 size 一直是 (0,0)**。
	#   原来这几行直接读 size.x / size.y，后果是：
	#     · y0 = 0 - 214 = -214 → 整排牌画在屏幕上边**外面**，手动模式什么也看不见；
	#     · 牌宽被夹成下限 96、起点钉在最左边（本该居中）；
	#     · 而 _await_card 只看"_card_panels 是不是空"——面板是建了的，只是画在屏幕外，
	#       于是那道"牌没建起来就退回普攻"的保险根本不触发，每一手都要**干等满超时**
	#       （当时写的是 90 秒）才按普攻打出去，看着就是"卡住了"。
	#   _build_bars 早就踩过同一个坑（上面那两个按钮就是 `size.x if size.x > 8.0 else 视口`），
	#   这里改成同一套兜底。
	var vp := get_viewport_rect().size
	var vw := size.x if size.x > 8.0 else vp.x
	var vh := size.y if size.y > 8.0 else vp.y
	var cw := CARD_W
	var ch := CARD_H
	var row_h := ch + CARD_ROW_GAP
	var total_h := float(rows.size()) * row_h
	var y0 := vh - 40.0 - total_h          # 整块贴底对齐
	# 提示行再往上留一截：牌被"弹出"时会抬 26，别让顶排压在提示行上
	var tip_y := y0 - 62.0
	# ㊿：兜底——算出来的位置要是画不到屏幕上，就**干脆不摊牌**：
	#   不建面板 → _await_card 那边"面板是空的"保险立刻生效 → 这一手直接按普攻走，
	#   绝不出现"牌在屏幕外、人干等 30 秒"。
	if tip_y < 60.0 or y0 + total_h > vh:
		print("[决斗] 牌面位置算不出屏幕内，这一手不摊牌：vw=", vw, " vh=", vh, " 行数=", rows.size(), " y0=", y0)
		return
	if not _card_logged:
		_card_logged = true
		print("[决斗] 摊牌几何：行数=", rows.size(), " 视口=", vw, "x", vh, " 牌=", cw, "x", ch, " 起点y=", y0, " 提示y=", tip_y)
	var row := Control.new()
	row.position = Vector2.ZERO
	row.size = Vector2(vw, vh)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_card_row = row
	var tip := UiKit.make_label(row, Vector2(0, tip_y), Vector2(vw - 210.0, 30), 16, UiKit.DIM)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_tip = tip
	# ㊿：行内明摆一个"这一手交出去"的钮——等牌时点它立刻改为自动挑，免得"没反应＝卡死"。
	if interactive:
		var ab := UiKit.make_button(row, Vector2(vw - 200.0, tip_y - 4.0), Vector2(190, 34), "自动挑一张", 15)
		ab.pressed.connect(_card_give_up)
	_card_meta.clear()
	_card_base.clear()
	_card_lbl.clear()
	_card_pick = -1
	_card_interactive = interactive
	for r in rows.size():
		var rd: Dictionary = rows[r]
		var ry := y0 + float(r) * row_h
		var acted := bool(rd.get("acted", false))
		var own_col: Color = rd.get("col", UiKit.INK)
		# 左边那一列：谁 · 哪一排（这轮已经出过手就打灰＋写明）
		# v89b：**一手牌不画这一列**——牌都混在一起了，"谁·哪一排"没有意义，
		#   主人信息改标在每张牌的角上（见下面 own_nm 那几行）。
		if not bool(rd.get("hand", false)):
			var lb := UiKit.make_label(row, Vector2(6, ry + 26.0), Vector2(CARD_LABEL_W - 10.0, 60), 17, own_col)
			var ltxt := str(rd.get("who", "")) + "\n" + str(rd.get("row_cn", "")) + "排"
			if acted:
				ltxt += "\n已出手"
			UiKit.set_text(lb, ltxt)
			lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if acted:
				lb.modulate = Color(1, 1, 1, 0.45)
		var cards: Array = rd.get("cards", [])
		var n := cards.size()
		# v89b：一手牌（hand=true）时**居中 + 重叠**排；一人一排的老路子照旧。
		var is_hand := bool(rd.get("hand", false))
		var step := cw + CARD_GAP
		var x0 := CARD_LABEL_W
		if is_hand:
			var avail := vw - 48.0
			if float(n) * step > avail:
				# 重叠：牌多就挤紧一点，最少留 40 像素露头（够看清名字的第一个字 + 主人色）
				step = maxf(40.0, (avail - cw) / maxf(1.0, float(n - 1)))
			x0 = (vw - (cw + float(n - 1) * step)) * 0.5
		for i in n:
			var c: Dictionary = cards[i]
			# ㊿：**按张判**能不能出——技能冷却好了就能出（一整排可能出好几张）
			var spent := _card_used(c)
			var usable := interactive and not spent
			var card := Panel.new()
			card.position = Vector2(x0 + float(i) * step, ry)
			card.size = Vector2(cw, ch)
			card.pivot_offset = Vector2(cw * 0.5, ch)
			# v89（用户草图里三张是散开的）：扇形角度 2.0 → **3.4 度/张**，
			#   并且中间那张略微抬高一点——像一把摊开的手牌，不再是整齐一排。
			var fk := float(i) - float(n - 1) * 0.5
			card.rotation = deg_to_rad(fk * 3.4)
			card.position.y += absf(fk) * 4.0
			card.mouse_filter = Control.MOUSE_FILTER_STOP if usable else Control.MOUSE_FILTER_IGNORE
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.93, 0.91, 0.85, 0.97) if usable else Color(0.80, 0.78, 0.74, 0.85)
			sb.set_corner_radius_all(9)
			sb.border_color = own_col          # 边框按**人**配色
			sb.set_border_width_all(3 if usable else 2)
			card.add_theme_stylebox_override("panel", sb)
			row.add_child(card)
			var flat := _card_meta.size()
			_card_meta.append(c)
			_card_panels.append(card)
			_card_base.append({"pos": card.position, "rot": card.rotation, "lift": 26.0})
			# v89（用户给的草图：「点击或者长按可以完全显示，不长按只显示名字」）：
			#   **牌面只留名字**——原来那张 26 字的缩略效果整块撤掉（牌一下子清爽了），
			#   效果全文挪到点击/长按弹的放大窗里（见 _show_card_zoom）。
			#   名字跟着放大、牌面竖直居中，远看就是一叠牌。
			# v89b：混排的一手牌里，**牌角标主人名字**（跟边框同色）——一眼看出这张是谁的
			var own_nm := str(c.get("own_nm", ""))
			if own_nm != "":
				var to := UiKit.make_label(card, Vector2(5, 3), Vector2(cw - 10.0, 18), 12,
					Color(own_col.r, own_col.g, own_col.b, 0.80))
				UiKit.set_text(to, own_nm)
				to.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var t1 := UiKit.make_label(card, Vector2(6, 20.0 if own_nm != "" else 0.0), Vector2(cw - 12.0, ch - 50.0 if own_nm != "" else ch - 30.0), 23, c.get("col", UiKit.INK))
			UiKit.set_text(t1, str(c.get("name", "?")))
			t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			t1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			t1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var t3 := UiKit.make_label(card, Vector2(5, 87), Vector2(cw - 10.0, 24), 12, UiKit.DIM)
			if spent:
				UiKit.set_text(t3, "已出")
			else:
				UiKit.set_text(t3, (CARD_TIP_PICK if usable else str(c.get("kind_cn", "普攻"))))
			t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_card_lbl.append(t3)
			if usable:
				card.gui_input.connect(_on_card_input.bind(flat, card))
	_paint_card_tip()   # 整块手牌建完再刷一次提示行（不必每张牌刷一遍）

# ㊿：一行的版本——自动模式"亮一下要出的那张"用（只摊出手那个人的手牌，不可点）
func _build_card_row(cards: Array, interactive: bool) -> void:
	if cards.is_empty():
		return
	_build_card_rows([_row_of_cards(_p_focus, cards, false)], interactive)

# ㊿：牌面上的效果文字截短——104 宽的牌放不下整段，全文留给长按的大窗
func _card_face_sub(s: String) -> String:
	if s.length() <= CARD_FACE_SUB:
		return s
	return s.substr(0, CARD_FACE_SUB) + "…"

# ㊿：一个"行"（某人这一手能用的牌）
func _row_of_cards(ai: int, cards: Array, acted: bool) -> Dictionary:
	var al := ally_at(ai)
	return {
		"ai": ai,
		"who": str(al.get("name", "我")),
		"row_cn": _row_tag(ai, _allies.size()),
		"col": ROLE_CARD_COL.get(str(al.get("role_id", "")), UiKit.INK),
		"acted": acted,
		"cards": cards,
	}

# ㊿：全队手牌——每个活着的人一排（含这轮已经出过的那几张，打灰但看得见）
#   row["acted"] 只在**这一排的牌全出完了**时才为真（左边那列好写"已出手"）
func _team_rows() -> Array:
	# v89b（用户：「所有牌都在上面哦 不是三个人分开哦…之所以扇形就保证有充足空间占手牌」）：
	#   **合成一手牌** —— 三个人的牌混在**同一排**扇形摊开。
	#   原来是一人一排（三排叠着），牌多的时候又挤又占屏幕；
	#   改成一手之后靠**扇形重叠**省地方：十几张也放得下，而且一眼看全"这一轮能出什么"。
	#   每张牌自己带主人（own_col 描边 + 牌面小名字 + meta 里的 ai），所以混排不会认错人。
	var rows: Array = []
	if _state == null:
		return rows
	var keep := _p_focus
	var hand: Array = []
	for i in _allies.size():
		if not _ally_alive(i):
			continue
		_state.use_member(i)                 # 武学冷却/功法是按成员存的，得先切过去
		var al := ally_at(i)
		var rcol: Color = ROLE_CARD_COL.get(str(al.get("role_id", "")), UiKit.INK)
		var own := str(al.get("name", "我"))
		for c_v in _cards_for(i):
			var c: Dictionary = c_v
			c["ai"] = i                      # 这张牌是谁的（出牌/放大窗都要用）
			c["own_col"] = rcol              # 主人配色（牌框 + 名字）
			c["own_nm"] = own                # 主人名字（牌面角上一行小字）
			hand.append(c)
	_state.use_member(keep)                  # 还原聚焦，别让别人读到他的功法
	if hand.is_empty():
		return rows
	rows.append({
		"ai": _p_focus, "who": "手牌", "row_cn": "", "col": UiKit.INK,
		"acted": false, "hand": true, "cards": hand,
	})
	return rows

# ㊿：提示行文案——选没选中不一样；倒计时由 _paint_card_tip 统一拼上去
func _paint_card_tip() -> void:
	if _card_tip == null or not is_instance_valid(_card_tip):
		return
	var base := ""
	if not _card_interactive:
		base = "「" + str(_a().get("name", "我")) + "」出手（自动）"
	elif _card_pick >= 0 and _card_pick < _card_meta.size():
		var dc: Dictionary = _card_meta[_card_pick]
		base = "「" + str(dc.get("name", "这张")) + "」（" + str(dc.get("who", "")) + "）挑好了——往上划发动"
	else:
		base = "还能出 " + str(_cards_left()) + " 手（技能冷却好了就能出）——点一张牌发动"
	if _card_wait_left >= 0:
		base += "　（" + str(maxi(0, _card_wait_left)) + " 秒后按普攻）"
	UiKit.set_text(_card_tip, base)

# ㊿：这一轮还能出几手——见 _cards_left()（提示行直接用那个）

# ㊿：点到哪张，哪张弹出——抬起、摆正、放大，并压到最上层；其余各回各位。
func _pop_card(i: int) -> void:
	if i < 0 or i >= _card_panels.size():
		return
	_card_pick = i
	for k in _card_panels.size():
		var p: Panel = _card_panels[k]
		if p == null or not is_instance_valid(p):
			continue
		var b: Dictionary = _card_base[k]
		var t := p.create_tween()
		t.set_parallel(true)
		if k == i:
			# ㊿：抬 26 就够（一排只有 112 高，抬太多会压到上面那排）
			var lift := float(b.get("lift", 26.0))
			t.tween_property(p, "position", (b["pos"] as Vector2) + Vector2(0.0, -lift), 0.13)
			t.tween_property(p, "rotation", 0.0, 0.13)
			t.tween_property(p, "scale", Vector2(1.07, 1.07), 0.13)
			if _card_row != null and is_instance_valid(_card_row):
				_card_row.move_child(p, _card_row.get_child_count() - 1)
		else:
			t.tween_property(p, "position", b["pos"], 0.13)
			t.tween_property(p, "rotation", float(b["rot"]), 0.13)
			t.tween_property(p, "scale", Vector2.ONE, 0.13)
	for k2 in _card_lbl.size():
		var lb: Label = _card_lbl[k2]
		if lb == null or not is_instance_valid(lb):
			continue
		if k2 == i:
			UiKit.set_text(lb, CARD_TIP_FIRE)
			lb.add_theme_color_override("font_color", UiKit.SEAL)
		else:
			UiKit.set_text(lb, CARD_TIP_PICK)
			lb.add_theme_color_override("font_color", UiKit.DIM)
	_paint_card_tip()

# ㊿：按住卡牌 → 等 CARD_HOLD_SEC 弹"放大镜"：把这张牌的名字/归属/效果放大摆中间。
#   作废条件三条：松手、换按别的牌、这张已经出手了（_card_choice >= 0）。
func _hold_start(i: int) -> void:
	_card_hold_i = i
	_card_hold_seq += 1
	var seq := _card_hold_seq
	await get_tree().create_timer(CARD_HOLD_SEC).timeout
	if _card_choice >= 0 or _card_hold_i != i or seq != _card_hold_seq:
		return
	_show_card_zoom(i)

func _hold_end() -> void:
	_card_hold_i = -1
	_card_hold_seq += 1
	_close_card_zoom()

# ㊿：放大镜——一块不拦输入的纱＋中央大纸片（拦输入的话会把"松手发动"那条路挡掉）
func _show_card_zoom(i: int) -> void:
	_close_card_zoom()
	if i < 0 or i >= _card_meta.size():
		return
	var c: Dictionary = _card_meta[i]
	# ⚠ 遮罩尺寸也得问视口——本控件 size 是 (0,0)（见 _build_card_row 那段说明），
	#   直接传 size 会得到一块 0x0 的纱：面板还在，就是背景不压暗。
	var vp := get_viewport_rect().size
	var vw := size.x if size.x > 8.0 else vp.x
	var vh := size.y if size.y > 8.0 else vp.y
	var veil := UiKit.make_veil(self, Vector2(vw, vh), 0.42)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_zoom = veil
	var panel := UiKit.make_paper_panel(veil, Rect2(60, 300, 600, 460))
	var own_col: Color = c.get("own_col", UiKit.INK)
	var head := UiKit.make_label(panel, Vector2(0, 18), Vector2(600, 30), 17, own_col)
	UiKit.set_text(head, str(c.get("who", "")) + " · " + str(c.get("row_cn", "")) + "排　·　" + str(c.get("kind_cn", "")))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# v89（用户草图：放大后是「大招；长风破浪」+「效果；xxxxxx」）：
	#   名字那行改成 **「种类 · 名字」**（原来种类挤在顶栏小字里，一眼扫不到）。
	var nm := UiKit.make_label(panel, Vector2(0, 54), Vector2(600, 48), 32, c.get("col", UiKit.INK))
	var kcn := str(c.get("kind_cn", ""))
	UiKit.set_text(nm, (kcn + " ·　" if kcn != "" else "") + str(c.get("name", "?")))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 「效果」小标题——草图上就是这个格式
	var eh := UiKit.make_label(panel, Vector2(40, 112), Vector2(520, 26), 15, Color(UiKit.SEAL.r, UiKit.SEAL.g, UiKit.SEAL.b, 0.85))
	UiKit.set_text(eh, "效　果")
	var bd := UiKit.make_label(panel, Vector2(40, 142), Vector2(520, 226), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))
	UiKit.set_text(bd, _card_zoom_text(c))
	bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tip := UiKit.make_label(panel, Vector2(0, 386), Vector2(600, 30), 16, UiKit.SEAL)
	UiKit.set_text(tip, "松手回到手牌——往上划（或再点一下）就发动")
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# 放大镜里的正文：把"打谁/冷却/效果"都摊开写
func _card_zoom_text(c: Dictionary) -> String:
	var kk := str(c.get("k", "normal"))
	var lines: Array = []
	if kk == "normal":
		lines.append("用手里那把兵器照常打一下——只够得到对面最前排。")
		lines.append("兵器：" + str(c.get("sub", "")))
	elif kk == "ult":
		lines.append("怒气满了才能放（这一手放完怒气清零）。")
		lines.append(str(c.get("sub", "")))
	else:
		# ⚠ 这张牌可能是**别人**的——武学冷却存在成员身上，得先切到牌主人才问得到
		#   （不然别人的武学在放大窗里会显示不出冷却，甚至查不到）。
		var oi := int(c.get("ai", _p_focus))
		var keep := _p_focus
		if _state != null and oi >= 0 and oi < _state.member_count():
			_state.use_member(oi)
		var art: Dictionary = _art_by_sid(str(c.get("sid", "")))
		if _state != null:
			_state.use_member(keep)
		lines.append("武学：冷却好了才会出现在牌面上。")
		lines.append(str(c.get("sub", "")))
		if not art.is_empty():
			lines.append("冷却：" + str(int(art.get("cd", 3))) + " 次行动")
			if str(art.get("kind", "")) == "bless":
				lines.append("⚠ 加持类：放这一手的人自己不出击，效果按目标**自己的手数**算。")
	lines.append("")
	lines.append("发动：往上划 ≥40 像素，或在这张牌上再点一下。")
	return "\n".join(PackedStringArray(lines))

func _close_card_zoom() -> void:
	if _card_zoom != null and is_instance_valid(_card_zoom):
		_card_zoom.queue_free()
	_card_zoom = null

func _on_card_input(ev: InputEvent, i: int, card: Panel) -> void:
	if _card_choice >= 0:
		return
	# ㊿：三种动作，别乱：
	#   · 点一下某张 → 那张弹出（抬起摆正；再点一下它＝发动）
	#   · 按住往上划 ≥40 像素 → 发动这张（一次到位，不用先点）
	#   · 往下/横着拖一大截 → 当误触，什么都不做
	# ⚠ 手机上 Godot 默认把触摸**再仿真一份鼠标事件**。不挡掉的话，一次轻点会被
	#   当成"按下→松开"两轮，弹出那一步白做、还会直接发动。所以触摸期间忽略鼠标事件。
	if ev is InputEventMouseButton:
		if _touch_active:
			return
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_drag_from = mb.position
			_press_was_pick = (_card_pick == i)
			_pop_card(i)
			_hold_start(i)      # ㊿：按住不放 → 弹放大镜
			return
		var d := Vector2.ZERO
		if _drag_from != Vector2.ZERO:
			d = _drag_from - mb.position
		_drag_from = Vector2.ZERO
		_hold_end()
		_card_release(i, card, d, false)
		return
	if ev is InputEventScreenTouch:
		var st2 := ev as InputEventScreenTouch
		if st2.pressed:
			_touch_active = true
			_drag_from = st2.position
			_press_was_pick = (_card_pick == i)
			_pop_card(i)
			_hold_start(i)      # ㊿：按住不放 → 弹放大镜
			return
		_touch_active = false
		var d2 := Vector2.ZERO
		if _drag_from != Vector2.ZERO:
			d2 = _drag_from - st2.position
		_drag_from = Vector2.ZERO
		_hold_end()
		_card_release(i, card, d2, true)

# 松手判定：往上划够 40 ＝发动；原地轻点且"按下去之前它就已经是弹出的那张"＝再点一下也发动
func _card_release(i: int, card: Panel, d: Vector2, _from_touch: bool) -> void:
	var swiped := d.y >= 40.0
	var tapped := absf(d.x) < 24.0 and absf(d.y) < 24.0
	if swiped or (tapped and _press_was_pick):
		_pick_card_at(i, card)

# ㊿：行内［自动挑一张］——这一手交出去（上层按自动那条路挑，不浪费成普攻）
func _card_give_up() -> void:
	_card_auto = true

func _pick_card_at(i: int, card: Panel) -> void:
	_card_choice = i
	if card != null and is_instance_valid(card):
		var t := card.create_tween()
		t.set_parallel(true)
		t.tween_property(card, "position", card.position + Vector2(0.0, -64.0), 0.12)
		t.tween_property(card, "modulate", Color(1.5, 1.42, 1.10, 1), 0.12)
	UiKit.set_text(_card_tip, "出「" + str((_card_meta[i] as Dictionary).get("name", "这张")) + "」")

func _await_card() -> int:
	# ㊿：等玩家选牌。**必须留退路**——这里是"等输入"的循环，
	#   万一牌面没建起来（或玩家一直不点），不能把整场卡死：
	#   · 牌面一个面板都没有 → 直接认输，退回普攻（这一手照样打出去）
	#   · 中途把［出手方式］切成自动、或点了行内［自动挑一张］→ 立刻退出，改走自动
	#   · 等太久（CARD_WAIT_SEC）→ 也退回普攻，别让人以为游戏死了
	#   等的过程里提示行会显示倒计时——"还剩几秒"看得见，就不会像卡死。
	var waited := 0.0
	var shown := -1
	while _card_choice < 0:
		# ㊿：出手方式那颗钮现在在舞台左侧（［卡组］下面），等牌时切它也要立刻生效
		_manual = last_manual
		if _allies_alive() <= 0 or _foes_alive() <= 0:
			return -1
		if not _manual or _card_auto:
			return -1        # ㊿：玩家自己交了——不用再等
		if _card_panels.is_empty():
			return -1
		waited += get_process_delta_time()
		var left := int(ceil(CARD_WAIT_SEC - waited))
		if left != shown:
			shown = left
			_card_wait_left = left          # 提示行由 _paint_card_tip 统一拼（含"挑好了"那句）
			_paint_card_tip()
		if waited > CARD_WAIT_SEC:
			UiKit.float_text(self, "等太久了——这一手按普攻算", UiKit.SEAL, 172.0)
			return -1
		await get_tree().process_frame
	return _card_choice

func _close_card_row() -> void:
	_hold_end()          # ㊿：连带把放大镜收掉（不然会留在结算页上）
	if _card_row != null and is_instance_valid(_card_row):
		_card_row.queue_free()
	_card_row = null
	_card_panels.clear()
	_card_meta.clear()
	_card_base.clear()
	_card_lbl.clear()
	_card_choice = -1
	_card_pick = -1
	_drag_from = Vector2.ZERO
	_card_tip = null
	_card_auto = false
	_card_wait_left = -1
	_touch_active = false
	_press_was_pick = false

# ㊿：站位标签按"这一队几个人"走——两个人就是"前/后"（没有中排）。
#   出征屏里挑的是"前排/中排/后排"（两人趟只给前/后），打起来要是写"中排"就对不上了。
#   ⚠ 这里只管**叫法**，机制上站位仍是名册下标（0 前 1 中 2 后，reach/挡刀都按它算）。
func _row_tag(i: int, n: int) -> String:
	if n <= 1:
		return "前"
	if n == 2:
		return "前" if i <= 0 else "后"
	return "前" if i == 0 else ("中" if i == 1 else "后")

# ㊿：出手台账——"这一轮已经出过哪些牌"。
#   一张牌的唯一标识：人 + 种类 + id（普攻/大招的 sid 是空，靠"人+种类"区分）。
func _card_key(c: Dictionary) -> String:
	return str(int(c.get("ai", -1))) + "|" + str(c.get("k", "normal")) + "|" + str(c.get("sid", ""))

func _card_used(c: Dictionary) -> bool:
	return _used.has(_card_key(c))

func _reset_used() -> void:
	_used.clear()

# ㊿：全队**这一轮还能出的牌**（摊牌、算出手位、自动挑牌都用这一份）
func _available_cards() -> Array:
	var out: Array = []
	for rd_v in _team_rows():
		var rd: Dictionary = rd_v
		for c_v in rd.get("cards", []):
			var c: Dictionary = c_v
			if not _card_used(c):
				out.append(c)
	return out

# ㊿：我方这一轮的"出手位"——**一张能出的牌占一个位子**（不再是一人一个）。
#   速度仍然说话：每个位子的先手值取"这张牌主人的速度"，
#   所以又快又有一堆技能的人，他的牌在回合里排得更靠前。
func _party_slots() -> Array:
	var out: Array = []
	for c_v in _available_cards():
		var c: Dictionary = c_v
		out.append({"k": "p", "s": _ally_spd(int(c.get("ai", 0)))})
	return out

# ㊿：提示行用——这一轮还能出几手
func _cards_left() -> int:
	return _available_cards().size()

# 每轮开头给每个活人走一次武学冷却（以前只在本人出手时走一手；
#   现在手牌是"全队一起摊"的，冷却必须在摊牌**之前**统一走完，
#   否则牌面上写着"好了"的那张，等轮到那个人时其实还没好）。
func _tick_arts_all() -> void:
	if _state == null:
		return
	for i in _allies.size():
		if not _ally_alive(i):
			continue
		_state.use_member(i)
		_state.tick_arts()
	_state.use_member(_p_focus)

# ㊿：自动挑牌（**全队手牌版**）——大招＞武学＞普攻；同类里挑"牌主速度更快"的那个。
#   注意跟 _auto_choice 的分工：那个只在"某一个人的牌"里挑（自动那一手要亮牌用），
#   这个在全队摊开的牌里挑（决定这一手该由谁出）。
func _auto_choice_team(cards: Array) -> Dictionary:
	# ============================================================
	# v64（用户："上了少侠，就只有少侠出手…不上少侠的话 陈和苏会出手"）：
	#   **原来只看（优先级, 速度）**——速度那一项一压，同优先级下**最快的人每格都赢**：
	#   少侠 116 对陈石 12 / 苏 18，一回合 7 个位子他能吃掉大半，
	#   战报上看着就是"只有少侠在打"（复现：少侠 81 行 vs 陈石 14 行）。
	#   现在加一层**公平**：这一轮还没出过手的人优先（权重 200——
	#   高过任何速度差，又低过"大招＞武学"那 1000 的档），于是
	#   **只要某人这轮一张牌都还没出，他就排在所有"已出过手"的人前面** ✓
	#   大招/武学仍然优先于普攻，只是不再被同一个人包场。
	# ============================================================
	# v64c（用户："挑人那层改成硬性一轮一人一次"）：
	#   **本轮已出过手的人，直接从候选里剔掉**——一轮里每人至多一个位子。
	#   只有当"剩下这些牌的主人都已经出过手"（＝全队都轮过了）时才放开重复，
	#   否则位子会白白空过。
	var pool: Array = []
	for c_v in cards:
		if not _acted_this_round(int((c_v as Dictionary).get("ai", 0))):
			pool.append(c_v)
	if pool.is_empty():
		pool = cards
	var best: Dictionary = {}
	var best_score := -1.0
	for c_v in pool:
		var c: Dictionary = c_v
		var k := str(c.get("k", "normal"))
		var pri := 2.0 if k == "ult" else (1.0 if k == "art" else 0.0)
		var score := pri * 1000.0 + _ally_spd(int(c.get("ai", 0)))
		if score > best_score:
			best_score = score
			best = c
	return best

# v64：这一轮这个人出过手没有（台账 _used 每轮开头清，见 _reset_used）
func _acted_this_round(ai: int) -> bool:
	var pre := str(ai) + "|"
	for u_v in _used:
		if str(u_v).begins_with(pre):
			return true
	return false

# ㊿：一个"我方出手位"。一个位子＝出一张牌；**还能出几张就有几个位子**，
#   所以一个人一轮里可能连出好几手（技能冷却好了就能出）。
#   具体出哪张由玩家点的牌决定；自动模式只在这里**定人**，出哪张交给 _strike
#   那条自动路（它会亮一下要出的那张牌）。
#   返回 {"ai": 下标, "pick": 出哪一张}；返回空字典＝我方这轮没牌可出了，位子空过。
#   pick 为空＝让 _strike 自己按自动挑（并亮牌）。
func _team_slot_turn() -> Dictionary:
	# ⚠ 先看还有没有牌能出——没牌了就直接空过这个位子。
	#   不先判的话，手动模式会摊出一手"全是灰的牌"然后**干等 30 秒**：
	#   面板是建了的（_card_panels 不空），那道"没牌就退回普攻"的保险不触发。
	var avail := _available_cards()
	if avail.is_empty():
		return {}
	if not _manual:
		var c0 := _auto_choice_team(avail)
		if c0.is_empty():
			return {}
		return {"ai": int(c0.get("ai", 0)), "pick": {}}
	_build_card_rows(_team_rows(), true)
	var pick_i: int = await _await_card()
	# ⚠ 这两个标记要在 _close_card_row() 之前读出来——那边会把 _card_auto 清掉
	var want_auto := _card_auto
	var quit_manual := not _manual
	var cd: Dictionary = {}
	if pick_i >= 0 and pick_i < _card_meta.size():
		cd = _card_meta[pick_i]
	_close_card_row()
	if not cd.is_empty() and not _card_used(cd):
		# 台账不在这里记——由出手循环在 _strike 跑完之后按"真出的那一张"记
		#（自动那条路也是同一个落点，免得两边各记一套、迟早走岔）
		return {"ai": int(cd.get("ai", 0)), "pick": {"k": str(cd.get("k", "normal")), "sid": str(cd.get("sid", ""))}}
	# 认输（行内［自动挑］/中途改自动）或超时 → 这一手交给自动挑，别浪费
	var avail2 := _available_cards()
	if avail2.is_empty():
		return {}
	var c2 := _auto_choice_team(avail2)
	if want_auto or quit_manual or cd.is_empty():
		UiKit.float_text(self, "交给我挑——这一手替你出", UiKit.GOLD, 172.0)
	return {"ai": int(c2.get("ai", 0)), "pick": {}}

func _flash_card(kind: String, sid: String) -> void:
	for i in _card_meta.size():
		var cd: Dictionary = _card_meta[i]
		if str(cd.get("k", "")) != kind:
			continue
		if kind == "art" and str(cd.get("sid", "")) != sid:
			continue
		if i >= _card_panels.size():
			return
		var p: Panel = _card_panels[i]
		if p == null or not is_instance_valid(p):
			return
		p.modulate = Color(1.7, 1.55, 1.05, 1)
		var tw := create_tween()
		tw.tween_property(p, "modulate", Color.WHITE, 0.3)
		return


#   普攻／没写 target 的招式 → 对面最前排（前排替后排挡刀）
#   target=mid/back        → 按 GameData.target_reach 越过前排
#   target=sweep           → 主目标仍是前排，但伤害由调用方铺满所有活人
func _pick_player_target(art: Dictionary) -> int:
	if art.is_empty():
		# v9（用户："苏 被动带匕首不打后排"）：自带 row_priority="back" 的人（苏青鸾·洞察 持匕首）
		#   普攻**绕开当面挡刀的，直取最后面那只**——与出村战斗同一条规矩。
		#   ⚠ 闭窍（nopassive）压着时这条也一并压住（与 _roll_p_damage 里那两段现算增伤同源）。
		var al0 := _a()
		if str(al0.get("row_prio", "")) == "back" and not St.blocks_passive(al0):
			return _back_foe()
		return _front_foe()
	var t := str(art.get("target", "front"))
	if t == "sweep":
		return _front_foe()
	return _target_foe(GameData.target_reach(t), false)

func run(state, player: Node2D, fx: Control, node: Dictionary, foe_first := false, party_nodes: Array = []) -> Dictionary:
	_state = state
	_fx = fx
	Audio.play_bgm("bgm_battle", 0.6)   # v65：遭遇战 BGM
	InkTouch.attach()
	FadeIn.attach()   # v68：进场淡入

	var foe: Dictionary = node.get("foe", {})
	_skip_enemy = false
	_skip_next = false
	# ㊿：沿用上次选的出手方式（本局记忆；默认自动＝老手感）。
	#   那颗钮在舞台上（［卡组］下面），这里只跟它同步一个值。
	_manual = last_manual
	# ㊿：先把每个人的武学冷却清一遍（reset_art_cd 是按"当前成员"算的）
	if _state != null:
		var mc: int = _state.member_count()
		for mi in mc:
			_state.use_member(mi)
			_state.reset_art_cd()
		_state.use_member(0)
	# ㊿：我方成队——把这一趟带的人按名册装出来（单人时与老行为一字不差）
	_compose_allies(player, party_nodes)

	# ㊷：敌阵容——上多人。招数/词缀的装载在 _build_foes 里做
	#   （引子趟不接招数与词缀——新手宽容，这条规矩照旧）。
	#   ⚠ _build_foes 必须在任何 _foe_*() 访问器之前调用，否则 _cur() 是空字典。
	_build_foes(node, foe)
	# ㊷：敌阵容装好了，再替本场留档（警戒遭遇的第二级敌源，只记前排那只）。
	#   ⚠ 这一段**必须排在 _build_foes 之后**：它要读 _foes[0]——前排那只的名字。
	#     原先它写在 _build_foes 之前，_foes 还是空数组，于是每场游历战斗的开头
	#     都报一次 "Out of bounds get index '0' (on base: 'Array')"，
	#     战斗就卡在起手那里进不去。
	if not foe.is_empty() and not _foes.is_empty():
		var lf := {"name": str((_foes[0] as Dictionary).get("name", "敌人")), "foe": foe.duplicate(true), "money": node.get("money", [10, 20])}
		if str(_state.mode) != "intro" and node.has("affixes"):
			lf["affixes"] = (node["affixes"] as Array).duplicate()
		_state.last_foe = lf
	_focus = 0
	for i in _foes.size():
		_make_foe_node(i)
	_focus_on(0)          # 让 _foe 指向 0 号（老代码靠它做动画）
	await _enter_foes()
	# ㊿：我方入场——三个人各走各的位（单人时就是原来那一个，一模一样）
	var pt := create_tween()
	var added := 0
	for i in _allies.size():
		var an = _ally_nodes[i] if i < _ally_nodes.size() else null
		if an == null or not is_instance_valid(an):
			continue
		var ab: Vector2 = (_allies[i] as Dictionary).get("base", _p_base)
		# v71c：同上——判空后再链式设置，并记数，防止 await 空等
		var ptp = pt.parallel().tween_property(an, "position", ab, 0.45)
		if ptp != null:
			ptp.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			added += 1
	if added > 0:
		await pt.finished

	_root.visible = true
	if _info_btn != null:
		_info_btn.visible = true
	if _log_btn != null:
		_log_btn.visible = true
	if _mode_btn != null:   # v63h：右上两排大钮跟血条同进同出
		_mode_btn.visible = true
	if _speed_btn != null:  # v10：快进钮同一批
		_speed_btn.visible = true
	_update_bars()
	await _wait(0.25)
	# v36：战报开场——这一场打谁、带什么词缀、我方是谁
	_log_lines.clear()
	_blog("── 遭遇「" + str(node.get("name", "敌")) + "」", "sys")
	var who: Array = []
	for al_v in _allies:
		who.append(str((al_v as Dictionary).get("name", "")))
	_blog("我方：" + "、".join(PackedStringArray(who)) + "　敌：" + str(_foes.size()) + " 人", "sys")
	# v46：多人场把"谁站前面、谁打得疼"写进战报——不然"打谁先"全靠猜
	if _foes.size() > 1:
		var seg3: Array = []
		for i5 in _foes.size():
			var f5: Dictionary = _foes[i5]
			seg3.append(GameData.foe_row_cn(i5) + " " + str(f5.get("name", "敌"))
				+ "（气 " + str(f5.get("hp", 0)) + " · 攻 " + str(f5.get("atk", 0)) + "）")
		_blog("敌站位——" + "　".join(PackedStringArray(seg3)), "sys")
		_blog("前排挡刀、后排打得疼；普通攻击只打最前排（" + str(_foes.size()) + " 人场）", "sys")
	elif not str((_foes[0] as Dictionary).get("solo_cn", "")).is_empty():
		# v47：单人关——把体型说清楚（不然只觉得这一关莫名其妙更肉/更疼）；寻常那档不解释
		var f1: Dictionary = _foes[0]
		var solo_cn := str(f1.get("solo_cn", ""))
		var tail3 := "" if solo_cn == "寻常" else "（血×攻的总账与寻常怪一样，只是偏了一头）"
		_blog("这只的体型：「" + solo_cn + "」——气 " + str(f1.get("hp", 0))
			+ " · 攻 " + str(f1.get("atk", 0)) + tail3, "sys")
	if not _foe_affixes().is_empty():
		_blog("敌带词缀：" + Affixes.names_text(_foe_affixes()), "bomb")
		_banner("敌带词缀：" + Affixes.names_text(_foe_affixes()), Color(0.62, 0.30, 0.26))
		await _wait(0.9)
	if foe_first:
		_blog("来敌先手！", "hit")
		_banner("来敌先手！", UiKit.SEAL)

	var p_first: bool = (not foe_first) and _player_spd() >= _foe_spd()
	var guard := 0
	# ㊷：多人时按 spd 排一轮——我方可能插在敌人中间；单人时行为与以前一致
	# ㊿：⚠ **我方一个位子＝一张能出的牌**（不是一人一个位子）：
	#   技能冷却好了就能出，所以一轮里同一个人可能连出好几手。
	#   每个位子的先手值＝那张牌主人的速度（见 _party_slots / _round_order）。
	# ㊿：⚠ 出手顺序**每轮重算**（原来只在开打时算一次）。
	#   因为轻身卡会中途改速度（受击后 +20%），顺序要是钉死在第一轮，
	#   那张卡就永远看不出效果。重算的代价可以忽略。
	var order: Array = _round_order(p_first, _party_slots())
	while _foes_alive() > 0 and _allies_alive() > 0 and guard < 60:
		guard += 1
		# ㊿：一轮开始——清"这轮出过哪些牌"、走一遍全队武学冷却（手牌是"全队一起摊"的，
		#   冷却必须先统一走完，牌面才跟真出的那一手对得上），再按"还能出几张牌"排位子
		_reset_used()
		_tick_arts_all()
		order = _round_order(p_first, _party_slots())
		for slot_v in order:
			if _allies_alive() <= 0 or _foes_alive() <= 0:
				break
			var slot := str(slot_v)
			if slot.begins_with("p"):
				# ㊿：我方一个"出手位"——出一张牌（谁出手由那张牌的主人决定）
				var t := await _team_slot_turn()
				if t.is_empty():
					continue          # 我方这轮没牌可出了，这个位子空过
				var act_i := int(t.get("ai", -1))
				if act_i < 0 or not _ally_alive(act_i):
					continue
				var pk: Dictionary = t.get("pick", {})
				_p_focus_on(act_i)
				# v64：这一手开始前先清掉"上一次是谁出的"——
				#   否则 _strike 中途被打断（电麻/震慑/毒发倒下）时，
				#   下面那句会把**上一个人**的牌记进台账，位子白白少一个。
				_last_ai = -1
				await _strike(true, pk)
				# ㊿：记台账——照"真出的那一张"记（手动点的／自动挑的都汇到这儿）
				if _last_ai >= 0:
					_used.append(str(_last_ai) + "|" + _last_k + "|" + _last_sid)
				_tick_bless(act_i)   # ㊿：加持按"自己的手"计数（用明确下标，别靠 _a()）
			else:
				var fi := int(slot)
				if not _foe_alive(fi):
					continue
				_focus_on(fi)
				await _strike(false)
		# v64：一轮收尾——**手上有牌却一张没出**的人，写一行到战报里。
		#   修完公平那一层之后正常不该出现；留着当兜底（也是"自动会不会漏人"的现场取证）。
		if _allies_alive() > 0 and _foes_alive() > 0:
			for i2 in _allies.size():
				if not _ally_alive(i2) or _acted_this_round(i2):
					continue
				var mine := 0
				for c_v in _available_cards():
					if int((c_v as Dictionary).get("ai", -1)) == i2:
						mine += 1
				if mine > 0:
					# v64b：把"这一轮谁被挑过"一起写出来——下一次截图就能看出是
					# 「位子不够」还是「被挑了但没打出去」（票根见 _used）
					var seat2: Array = []
					for u2 in _used:
						seat2.append(str(u2).split("|")[0])
					_blog("（这一轮 " + str(ally_at(i2).get("name", "队友")) + " 没轮上——手上还剩 "
						+ str(mine) + " 张牌；本轮的位子：" + str(order.size()) + " 个，出过手的下标 ["
						+ ",".join(PackedStringArray(seat2)) + "]）", "sys")
		# 这一轮里倒下的敌人补一次自爆判定
		for i in _foes.size():
			if not _foe_alive(i):
				_focus_on(i)
				if bool((_foes[i] as Dictionary).get("bombed", false)):
					continue
				(_foes[i] as Dictionary)["bombed"] = true
				await _foe_bomb_if_dead()
				_mark_hit_if_hurt()   # ㊿：轻身卡——挨炸也算受击
		_foe_fall_if_dead()

	var won: bool = _foes_alive() <= 0 and _allies_alive() > 0
	var mrange: Array = node.get("money", [10, 20])
	var lo := int(mrange[0])
	var hi := int(mrange[1])
	if hi < lo:
		hi = lo
	var gain := 0

	# ㊿：倒下的我方各补一个倒地姿势（以前只有一个人，没人管这个）
	for i in _allies.size():
		if _ally_alive(i):
			continue
		var dn = _ally_nodes[i] if i < _ally_nodes.size() else null
		if dn != null and is_instance_valid(dn) and dn.has_method("play_down"):
			dn.play_down()

	if won:
		if _foe != null and is_instance_valid(_foe):
			_foe.play_down()
		_blog("── 胜！（" + str(_foes.size()) + " 名敌人全倒）", "crit")
		_banner("胜！", Color(0.15, 0.14, 0.16))
		if _fx != null:
			_fx.flash(Color(1, 1, 1, 0.25))
		var ft := create_tween()
		ft.tween_interval(0.55)
		if _foe != null and is_instance_valid(_foe):
			ft.tween_property(_foe, "modulate:a", 0.0, 0.5)
		await ft.finished
		gain = randi_range(lo, hi)
		# ㊿：领队倒过但队伍赢了——把领队扶起来：打完还要靠这个 walker 走回路上
		if _ally_nodes.size() > 0:
			var lead = _ally_nodes[0]
			if lead != null and is_instance_valid(lead) and lead.has_method("reset_pose"):
				lead.reset_pose()
	else:
		_blog("── 不敌（我方全倒）", "hit")
		_banner("不敌", UiKit.SEAL)
		gain = maxi(1, int(randi_range(lo, hi) / 2))
		if _foe != null and is_instance_valid(_foe):
			var lv := create_tween()
			lv.tween_property(_foe, "position", Vector2(1500, _e_base.y), 0.55)

	gain = maxi(1, int(round(float(gain) * MONEY_MULT)))

	# ㊷：收尾把所有敌人都清掉（以前只有一个）
	for n in _foe_nodes:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_foe_nodes.clear()
	_foe = null
	_root.visible = false
	Audio.play_bgm("bgm_journey", 1.2)   # v65：打完回游历 BGM
	Audio.sfx("win", -7.0)   # v78：遭遇战胜负音
	if _info_btn != null:
		_info_btn.visible = false
	if _log_btn != null:   # v63h：右上两排大钮跟血条同进同出
		_log_btn.visible = false
	if _mode_btn != null:
		_mode_btn.visible = false
	if _speed_btn != null:  # v10：快进钮跟另外两颗一起收
		_speed_btn.visible = false
	_close_card_row()   # ㊿：收摊时把牌面也收掉（免得留一排牌在结算页上）
	_close_info()
	# ㊼：打完写回——按比例折回游历气血（胜：残血上路；败＝殒命，不回写）
	# ㊿：三个人各写各的——每个人都按自己这一场的剩血折回自己那份
	if won and _state != null:
		for i in _allies.size():
			var al: Dictionary = _allies[i]
			var jm := maxi(1, int(_state.member_at(i).get("hp_max", int(al.get("hp_max", 1)))))
			var ratio := float(int(al.get("hp", 0))) / float(maxi(1, int(al.get("hp_max", 1))))
			_state.use_member(i)
			_state.hp = clampi(int(round(float(jm) * ratio)), 1, jm)
		_state.use_member(0)
	# ㊿：只收战斗自己开的节点——舞台的 walker 与同伴还给舞台（它们还要走路上，
	#   而且同伴的站位/装扮由舞台管，战斗不该动它们的生死）
	for n2 in _own_nodes:
		if n2 != null and is_instance_valid(n2):
			n2.queue_free()
	_own_nodes.clear()
	_ally_nodes.clear()
	# ㊿：不管胜败都把"当前对谁操作"归零——战斗里 _p_focus_on 会一路改它，
	#   不收回去的话，出战斗后面板/结算默认对着的是最后出手的那个人。
	if _state != null:
		_state.use_member(0)
	return {"won": won, "gain": gain}

func _player_spd() -> int:
	return int(round(float(_a().get("spd", 100))))

func _roll_p_damage(mult: float) -> Dictionary:
	var st: Dictionary = _state.stats_of(_state.member_at(_p_focus))
	# v58（用户第 3、4 条）：这一手走**物理**还是**五行**通道，由 `_cur_elem` 说了算。
	#   · 增伤：物理＝全伤害＋物理伤害；元素＝全伤害＋该元素伤害（`Elem.atk_bonus`）
	#   · 元素再加一道 ×ELEM_BASE(0.8) 的通道底倍率
	#   · **元素不可暴击**：下面 crit 那一整段直接跳过（不是把暴击率调 0——是压根不掷）
	var base := float(st["atk"]) * Elem.atk_bonus(st, _cur_elem) * Elem.channel_mul(_cur_elem) * mult * _next_mult
	base *= 1.0 + float(_fx_buff.get("atk_pct", 0.0))
	base *= 1.0 + float(_a().get("bless_atk", 0.0))   # ㊿：加持（锐锋旗令等）
	base *= _talent_wpn   # ㉗：剑心通明（使剑/空手才算，开打时已判过）
	_next_mult = 1.0
	# ㊳：自带天赋两种"增伤"——
	#   low_hp_dmg     自己残血时更重（主角·赤子之心）
	#   foe_low_hp_dmg 对手残血时更重（苏青鸾·洞察）
	#   都带兵器条件的话由 innate_active 判过（这里拿到的已是"生效中"的那条）
	var inn: Dictionary = _state.innate_of_member(_state.member_at(_p_focus))
	var inn_kind := str(inn.get("kind", ""))
	# v54：闭窍压着的时候，自带天赋那两段现算的增伤一并跳过
	if not inn.is_empty() and not St.blocks_passive(_a()):
		if inn_kind == "low_hp_dmg" and _hp * 2 <= _my_hp_max:
			base *= float(inn.get("mult", 1.25))
			if not _innate_noted:
				_innate_noted = true
				UiKit.float_text(self, str(inn.get("name", "自带天赋")) + " · 出手更重", UiKit.GOLD, 192.0)
		elif inn_kind == "foe_low_hp_dmg" and _foe_hp() * 2 <= _foe_hp_max():
			base *= float(inn.get("mult", 1.25))
			if not _innate_noted:
				_innate_noted = true
				UiKit.float_text(self, str(inn.get("name", "自带天赋")) + " · 看准了破绽", UiKit.GOLD, 192.0)
	# ㊿z：角色星——「猎影」（对手残血时暴击 +30 个百分点）
	#   ⚠ 这一格用**百分点**（跟 stat 组一个口径），不是比例——crit 在引擎里就是 5~30 这种数
	var crit_pt := float(st["crit"]) + _crit_add + float(_a().get("bless_crit", 0.0))   # ㊿：加持暴击
	# v11（苏的大招加强）：**剑歌窗口内她自己暴击 +SONG_CRIT_UP**——
	#   那支大招本来就是"暴击才追剑"，暴击率不够整支就空转（见 QINGLUAN_DEFAULT.ult 的账）。
	#   判据用 _ult_follow > 0（只有"剑歌"那支会设它；陈石的枪势只设 _ult_turns）✓
	if _ult_turns > 0 and _ult_follow > 0.0:
		crit_pt += SONG_CRIT_UP
	# ============================================================
	# v62v（用户："舍装签 攻击 +40% 暴击 +50%"）：**暴击率按比例加**——
	#   `crit_pct` 是比例（0.50＝×1.5），与上面那格"百分点"（crit_pt，5~30 这种数）
	#   是两个口径，别混。60 点暴击 ×1.5 ＝ 90 点，封顶照旧由下面掷骰子那一行管。
	# ============================================================
	var crit_pct := float(_fx_buff.get("crit_pct", 0.0))
	if crit_pct > 0.0:
		crit_pt *= 1.0 + crit_pct
	var star_low := float(_fx_buff.get("crit_low_pct", 0.0))
	if star_low > 0.0 and _foe_hp() * 2 <= _foe_hp_max():
		crit_pt += star_low
	# v58：**元素伤害不能暴击**（用户第 4 条）——不是"暴击率算成 0"，是这一次压根不掷骰子，
	#   所以面板上的暴击率再高也没用（装配五行兵器时那一栏只对物理有意义）。
	var crit := false
	if Elem.can_crit(_cur_elem):
		crit = randf() * 100.0 < crit_pt
	if crit:
		# ㊿y2：暴击伤害是**真属性**了——倍率 = 1.0 + 暴伤/100（以前写死 1.6 倍），
		#   再乘角色星·青鸾「凝息」的 crit_mul_up
		base *= (1.0 + float(st.get("crit_dmg", 50.0)) / 100.0) * (1.0 + float(_fx_buff.get("crit_mul_up", 0.0)))
	return {"dmg": maxi(1, int(round(base * randf_range(0.92, 1.08)))), "crit": crit}

# ㊿z6：专武·铁壁桩功——自己**每击中一名敌人**，反刺累计 +10%（封顶 +100%）。
#   （游历这边反刺走 _foe_show_hit 里的那一块儿，累计值存在当前成员身上）
func _ex_thorn_gain() -> void:
	var per := float(_fx_buff.get("thorn_per_hit", 0.0))
	if per <= 0.0:
		return
	_a()["thorn_ramp"] = minf(1.0, float(_a().get("thorn_ramp", 0.0)) + per)

# ㊿z6：专武·铁壁桩功——大招窗口（枪势）里的额外减伤
func _ex_ult_cut() -> float:
	if _ult_turns <= 0:
		return 0.0
	return float(_fx_buff.get("ult_cut", 0.0))

# v35：我方挨打的两道新闸——**闪避 → 防御**，两套战斗共用 GameData 那把尺子。
#   ① 闪避率 ＝ 我闪避 / (我闪避 + 对手命中)；对手命中 ＝ 基准 + 对手速度×2
#      （游历敌人的速度是 100 量级，先按 JOURNEY_FOE_SPD_DIV 折回 10 量级）
#   ② 挡掉比例 ＝ 我防御 / (对手攻击 + 我防御)——**数值对数值**，不做成"减伤%"
#   返回最终伤害；**闪掉时返回 0**（这一手整个作废，调用方按 0 跳过挨打演出）。
#   普攻（_roll_e_damage）与招数（_foe_art_dmg）两条路都调它，就这一处口径。
# v58：这一手算什么属性（用户第 3、6 条）——
#   ① 武学自己写了元素（`Cards.elem_of(武学 id)`，上品起部分武学有）就用它的
#   ② 否则看手里那把兵器的元素（**逐件随机**，见 GameState.item_elems）
#   ③ 都没有＝物理（空串）
#   ⚠ 敌人这一侧返回空：塔/游历的敌人 `weapon` 字段记的是**类型**（sword/dual/…），
#     不是件名，没有元素可查。要给怪上五行（比如袖箭门给水、铁旗堡给金）得再定一版数据。
# v88（用户规则：「元素类上品/极品/绝品功法才会触发元素特有效果；良品/凡品没有元素功法；
#   如果没有元素功法，元素武器只有元素伤害」）：
#   这一手的元素**来自哪里**决定了要不要给印记——来自**上品及以上的功法**才给（见 _apply_elem_mark_on_hit）。
#   武器带的元素只算"伤害通道"（不吃防御、不可暴击），不给燃烧/湿身那一类特有效果。
var _elem_from_high_art := false

func _atk_elem(art: Dictionary, is_player: bool) -> String:
	var sid := str(art.get("_sid", ""))
	if sid != "":
		var fe := GameState.elem_of_card(sid)
		if fe != "":
			# v88：只有上品及以上才算"元素功法"（良品/凡品本来也摇不到元素，双保险）
			var q := Cards.quality_of(sid)
			_elem_from_high_art = (q == "上品" or q == "极品" or q == "绝品")
			return fe
	_elem_from_high_art = false
	if is_player and _state != null:
		return GameState.elem_of_card(_state.weapon_id_of_member(_p_focus))
	# v58：敌人的属性写在它自己的字典上（塔那边第 400 关起由 tower.gd 给；
	#   游历的怪以后也可以在自己的行里写 `elem`）
	return str(_cur().get("elem", ""))

	# v58（用户第 5 条）：**元素攻击按属性给印记**——火水打对手、金木土叠自己。
	#   放在伤害落地之后（跟招式自带状态一个位置）。吃的那一份加成＝
	#   `Elem.atk_bonus(出手方属性, 元素)` ×（1 + 踏浪夺来的该元素增伤）——
	#   记进印记条目里，之后它的掉血与爆发都按这个数放大（用户："燃烧【吃火属性加成】"）。
	#   ⚠ `_foe_take` 每一段伤害都会调一次（连击/群攻各算一次）——这正是"叠层"的来源。
func _apply_elem_mark_on_hit() -> void:
	if not Elem.is_elem_attack(_cur_elem):
		return
	# v88（用户规则）：**没有元素功法，元素武器就只有元素伤害**——印记是"特有效果"，
	#   只由上品及以上的元素功法给。武器摇出来的元素不触发。
	var fmark := str(_cur().get("elem", ""))
	if not _elem_from_high_art:
		# 例外：敌人自带的元素（塔 800 关起 / 游历难度 25 起）仍然照给——那是敌人的本事
		if fmark == "" or fmark != _cur_elem:
			return
	if _state == null or _foe_hp() <= 0:
		return
	var eb := _elem_eb_for(_a(), _cur_elem)
	var mr: Dictionary = St.apply_elem_mark(_a(), _cur(), _cur_elem, eb)
	if mr.is_empty():
		return
	var mside := str(mr.get("side", ""))
	var mmsg := str(mr.get("msg", ""))
	UiKit.float_text(self, ("印记 " if mside == "self" else "") + mmsg,
		St.col_of(str(mr.get("id", ""))), 176.0)
	_blog(str(_a().get("name", "我")) + " " + Elem.cn(_cur_elem) + "属性 → " + mmsg, "sys")
	_update_bars()

# v58：出手方针对某元素的增伤倍率（印记的掉血/爆发按它放大）
#   ＝ 全伤害+该元素增伤（Elem.atk_bonus）再乘"踏浪夺来的那一份"
func _elem_eb_for(u: Dictionary, e: String) -> float:
	var st: Dictionary = {}
	if _state != null:
		st = _state.stats_of(_state.member_at(_p_focus))
	var base := Elem.atk_bonus(st, e)
	var gain := St.elem_gain(u, e)
	return base * (1.0 + gain / 100.0)

# v58（用户第 6 条）：这一门武学跟手里那把兵器**合不合**（1.0＝全效，0.70＝不合）
#   武学没写元素 → 不涉及（1.0）。兵器没元素（物理）对上有元素的武学 → 算不合。
func _art_fit(art: Dictionary) -> float:
	var ae := str(art.get("elem", ""))
	if ae == "":
		return 1.0
	var we := ""
	if _state != null:
		we = GameState.elem_of_card(_state.weapon_id_of_member(_p_focus))
	return Elem.art_fit(we, ae)

# ============================================================
# v58（用户："伤害弹出记得标注是什么类型伤害 比如火元素就火焰图标标志"）：
#   飘伤害数字统一走这两个口——它们会把**这一手的属性**一起交给 fx_layer，
#   由 `UiKit.elem_number_row()` 在数字左边挂一枚属性徽章（火/水/金/木/土 的色块小字牌）。
#   物理与真实**不给徽章**（老样子只有数字），免得满屏都是牌子。
#   ⚠ 属性读的是**这一手**的元素：打我方的读 `_foe_cur_elem`（敌人那一手），
#     打敌方的读 `_cur_elem`（我方那一手）——两边分得开，不然反伤会被标成元素。
#   ⚠ v58 补（用户："武器随机元素 也会随到空的 也就是物理 因为物理也是类型伤害 不要忘了"）：
#     `_cur_elem` 为**空串**＝没元素，但打出去那一下**就是物理伤害**——所以飘字时换成
#     `"phys"`，徽章就显示「物」。空串与 "phys" 在引擎里走的是**同一条路**
#     （`is_elem_attack` 都假、`dmg_key` 都取 `phys_dmg`），这里只是给飘字一个画得出来的名字。
# ============================================================
func _mark_elem(e: String) -> String:
	return "phys" if e == "" else e

func _num_foe(v: int, col = null) -> void:
	if _fx == null or not is_instance_valid(_foe):
		return
	_fx.number(str(v), _foe, (UiKit.SEAL if col == null else col), _mark_elem(_cur_elem))

func _num_me(v: int, who: Node2D, col = null) -> void:
	if _fx == null or not is_instance_valid(who):
		return
	_fx.number(str(v), who, (Color(0.72, 0.16, 0.12) if col == null else col), _mark_elem(_foe_cur_elem))

func _p_mitigate(raw: int) -> int:
	var target: Dictionary = _a()
	if target.is_empty():
		return maxi(1, raw)
	# v52：负面状态的两条乘数（怪身上的「虚弱」→ 这一下更轻、我身上的「破防」→ 更重）。
	#   放在最前头：下面的"闪掉返 0"与"防御为 0 直接返回"两条早退都吃得到，
	#   与出村 `_member_take_cut` 的位置一致。
	var raw2 := raw
	var st_am := St.atk_mul(_cur())
	if not is_equal_approx(st_am, 1.0):
		raw2 = maxi(1, int(round(float(raw2) * st_am)))
	var st_tm := St.taken_mul(target)
	if not is_equal_approx(st_tm, 1.0):
		raw2 = maxi(1, int(round(float(raw2) * st_tm)))
	var foe_spd := float(_cur().get("spd", 95)) / JOURNEY_FOE_SPD_DIV
	var dr := GameData.dodge_rate(float(target.get("dodge", 0.0)), foe_spd)
	if dr > 0.0 and randf() < dr:
		# v36：战报——闪开了（这一手整个作废）
		_blog(str(target.get("name", "我")) + " 闪开了" + ("" if _cur_move == "" else " " + _cur_move) + "（" + str(_cur().get("name", "敌")) + " 这一手落空）", "dodge")
		if _fx != null and is_instance_valid(_player):
			_fx.number("闪避！", _player, C_DODGE)
		else:
			UiKit.float_text(self, "闪避！", C_DODGE, 192.0)
		return 0
	var my_def := float(target.get("def", 0.0))
	# v58：元素伤害不走防御，改走我方的对应抗性（与 _foe_take 那一侧同一个口径）。
	#   ⚠ 读的是 `_foe_cur_elem`（**敌人这一手**的属性），不是 `_cur_elem`。
	if Elem.is_elem_attack(_foe_cur_elem):
		var myres := float(target.get(Elem.res_key(_foe_cur_elem), 0.0)) + St.res_shift(target, _foe_cur_elem)
		var rcut := Elem.res_mul(myres)
		return _shield_then(raw2, rcut, target)
	if my_def <= 0.0:
		return _shield_then(raw2, 1.0, target)
	return _shield_then(GameData.after_def(float(raw2), float(_foe_atk_eff()), my_def), 1.0, target)

# v58：先乘抗性、再让护盾吸一口，剩下的才是真扣血。
#   护盾吸掉的那一份在函数里就扣掉了（外面拿到的返回值＝还要扣的血）。
func _shield_then(raw: int, mul: float, target: Dictionary) -> int:
	var v := maxi(1, int(round(float(raw) * mul)))
	if St.shield_of(target) > 0:
		var ab: Dictionary = St.shield_absorb(target, v)
		if int(ab["absorbed"]) > 0:
			UiKit.float_text(self, "护盾 -" + str(int(ab["absorbed"])), Color(0.56, 0.42, 0.24), 176.0)
			_blog("　护盾挡下 " + str(int(ab["absorbed"])) + "（剩 " + str(St.shield_of(target)) + "）", "guard")
		v = int(ab["hp"])
	return v
func _roll_e_damage() -> Dictionary:
	var base := _foe_atk_eff() * _foe_next_mult() * randf_range(0.9, 1.1)
	base *= Elem.channel_mul(_foe_cur_elem)   # v58：元素那一手再乘 0.8（物理＝×1）
	base *= _ambush_mul()   # ㊿：偷袭——打不在前排的目标 +50%
	_set_foe_next_mult(1.0)
	var raw := maxi(1, int(round(base)))   # ㉕：原始数——陈石的反刺按它算（不吃减伤）
	base *= 1.0 - _cut_add
	# ㉗：百折不挠——气血不足三成时再减一层
	if _talent_cut > 0.0 and _hp * 10 <= _my_hp_max * 3:
		base *= 1.0 - _talent_cut
		if not _talent_cut_noted:
			_talent_cut_noted = true
			UiKit.float_text(self, "百折不挠 · 站得住", UiKit.GOLD, 192.0)
	# 百折不挠：全撤（R1 决定）——两场战斗都不接；R6 与弟子 fx 一起接线
	var guarded := false
	if _guard_left > 0:
		base *= _guard_cut
		_guard_left -= 1
		guarded = true
	# v35：闪避 → 防御（可能回 0＝闪掉）
	var fin := _p_mitigate(maxi(1, int(round(base))))
	return {"dmg": fin, "guard": guarded, "raw": raw}

func _pick_move(is_player: bool) -> String:
	var table := _foe_weapon()
	if is_player:
		table = _state.weapon()
	var arr: Array = RunState.MOVE_TABLE.get(table, ["fist_punch"])
	return str(arr[randi() % arr.size()])

func _update_bars() -> void:
	if _bar_p == null:
		return
	# v63j（用户："血条太短了，就按爬塔那个战斗界面来"）：单人/多人**统一每人一行**——
	#   名字（16 号）＋ 200 宽绿条 ＋ 怒气小金条 ＋ 数值（加持/负面缀在数值后面）。
	#   老的单人总条与文案行退役（_bar_p / _txt_p 恒藏）。
	_txt_p.visible = false
	_bar_p.visible = false
	_txt_e.visible = _foes.size() > 1
	for i in _allies.size():
		if i >= _mrows.size():
			break
		var a2: Dictionary = _allies[i]
		var tag := _row_tag(i, _allies.size())   # ㊿：两人趟写"前/后"，不写"中"
		var ahp := int(a2.get("hp", 0))
		var bm := _bless_mark(a2)
		var sm := _st_mark(a2)
		var tailm := ("" if bm == "" else " " + bm) + ("" if sm == "" else " " + sm)
		var mr: Dictionary = _mrows[i]
		(mr["nm"] as Label).text = tag + "·" + str(a2.get("name", ""))
		(mr["nm"] as Label).visible = true
		var barm: ProgressBar = mr["bar"]
		barm.max_value = maxi(1, int(a2.get("hp_max", 1)))
		barm.value = maxi(0, ahp)
		barm.visible = true
		var ragem: ProgressBar = mr["rage"]
		ragem.max_value = 100.0
		ragem.value = clampf(float(int(a2.get("rage", 0))), 0.0, 100.0)
		ragem.visible = true
		(mr["hp"] as Label).text = ("倒" if ahp <= 0 else (str(ahp) + "/" + str(int(a2.get("hp_max", 1))))) + tailm
		(mr["hp"] as Label).visible = true
	for i2 in range(_allies.size(), _mrows.size()):
		var mr2: Dictionary = _mrows[i2]
		(mr2["nm"] as Label).visible = false
		(mr2["bar"] as ProgressBar).visible = false
		(mr2["rage"] as ProgressBar).visible = false
		(mr2["hp"] as Label).visible = false
	# v63j（爬塔同款）：敌方名字居中 + 大条（数值画在条里）；多人段"全队：前…中…后…"走条下居中小字。
	var fsm := _st_mark(_cur())
	(_erow["nm"] as Label).text = _foe_name() + ((" " + fsm) if fsm != "" else "")
	(_erow["bar"] as ProgressBar).max_value = maxi(1, _foe_hp_max())
	(_erow["bar"] as ProgressBar).value = maxi(0, _foe_hp())
	(_erow["hp"] as Label).text = str(_foe_hp()) + " / " + str(_foe_hp_max())
	if _foes.size() > 1:
		var seg: Array = []
		for i in _foes.size():
			var f: Dictionary = _foes[i]
			var hp := int(f.get("hp", 0))
			var tag := "前" if i == 0 else ("中" if i == 1 else "后")
			if hp <= 0:
				seg.append(tag + " 倒")
			else:
				seg.append(tag + " " + str(hp))
		UiKit.set_text(_txt_e, "全队：" + " · ".join(PackedStringArray(seg)))
		_txt_e.visible = true
	else:
		_txt_e.visible = false
	# v54：两边的小图标（跟文字同一份数据；谁都可能被上负面）
	if _chip_p != null:
		_chip_p.set_unit(_a())
		_chip_p.visible = _chip_p.count() > 0
	if _chip_e != null:
		_chip_e.set_unit(_cur())
		_chip_e.visible = _chip_e.count() > 0
	if _art_line == null:
		return
	# 功法栏显示的是"当前聚焦那个人"的功法（出手前 _p_focus_on 会切到他）
	if _state.arts.is_empty():
		UiKit.set_text(_art_line, "功法：无（合成武学后会装上）")
		return
	var out: Array = []
	for sid in _state.arts:
		var s := str(sid)
		# ㊿z4：被动功法（专武那类）不进出手轮转——标"常驻"就行
		if Cards.art_is_passive(s):
			out.append(str(Cards.name_of(s)) + "·常驻")
			continue
		var cd := int(_state.art_cd.get(s, 0))
		if cd <= 0:
			out.append(str(Cards.name_of(s)) + "·就绪")
		else:
			out.append(str(Cards.name_of(s)) + "·冷却" + str(cd))
	UiKit.set_text(_art_line, "功法：" + "　".join(PackedStringArray(out)))

# ---- v7：我方大招（三分支）----

func _player_ult() -> void:
	if _player == null or not is_instance_valid(_player) or _foe == null or not is_instance_valid(_foe):
		return
	var un := str(_ult.get("name", "大招"))
	var uk := str(_ult.get("kind", "hit"))
	_cur_move = "大招『" + un + "』"   # v36：战报
	_banner("『" + un + "』", UiKit.SEAL)
	# v66：大招的"分量"——顿帧 ＋ 屏震 ＋ 全屏墨红闪 ＋ 招式名大字。
	#   以前大招只有一条 banner，打出来跟普攻一个手感（就一条字），所以这里补三样。
	FadeIn.buzz(140)   # v68：手机上一记长振（大招的分量）
	if _fx != null:
		_fx.shake(10.0, 0.42)
		_fx.flash(Color(UiKit.SEAL.r, UiKit.SEAL.g, UiKit.SEAL.b, 0.30))
		# v74：大招的"华丽"——墨色漩涡 + 九道剑气四散 + 三重冲击波（用户：「大招也要加 更华丽一点」）
		var uc := _player.global_position + Vector2(0.0, -80.0)
		var udir := 1.0
		if _foe != null and is_instance_valid(_foe):
			udir = signf(_foe.global_position.x - _player.global_position.x)
			if udir == 0.0:
				udir = 1.0
			uc = (_player.global_position + _foe.global_position) * 0.5 + Vector2(0.0, -80.0)
		_fx.ult_storm(uc, udir)
		# v92：素材红刀光挪到**大招这一下**（普攻不再叠，见 fx_layer.slash_between 的注）
		if _foe != null and is_instance_valid(_foe):
			_fx.slash_between(_player, _foe, "cut", true)
		_fx.big_word(un, UiKit.SEAL)
	await get_tree().create_timer(0.12).timeout   # 顿帧：压下来的那一下要有重量
	if uk == "hit":
		var mult := float(_ult.get("mult", 2.5)) * (1.0 + float(_fx_buff.get("ult_dmg", 0.0)))
		var is_sweep_ult := str(_ult.get("target", "front")) == "sweep"
		var alive_now := _foes_alive()
		# ㊺：群攻大招只在"对手不止一个"时才横扫；只剩一个就转单体重击，
		#   倍率改用 mult_single（主角是 2.8）——不然人少时等于自己打自己六折。
		var solo := float(_ult.get("mult_single", 0.0))
		var solo_hit := is_sweep_ult and alive_now <= 1 and solo > 0.0
		if solo_hit:
			# v48：**转单体也得吃大招增伤**——以前这里直接用数据里的 mult_single，
			#   把上面刚乘上的 (1+ult_dmg)（破军卡 +30% / 星「破浪」+30%）整个丢了，
			#   于是"游历打单个敌人时大招增伤不生效"，而村内是生效的。
			mult = solo * (1.0 + float(_fx_buff.get("ult_dmg", 0.0)))
		# ㊿z7：专武·长风诀——"放完大招后两回合内再放大招，那一下再 +30%"
		var chain_up := 0.0
		if int(_a().get("ult_chain_left", 0)) > 0 and float(_fx_buff.get("ult_chain_up", 0.0)) > 0.0:
			chain_up = float(_fx_buff.get("ult_chain_up", 0.0))
			mult = mult * (1.0 + chain_up)
			UiKit.float_text(self, "长风不断 +" + str(int(round(chain_up * 100.0))) + "%", UiKit.GOLD, 192.0)
		var tw0: Tween = _player.push_move_to(_p_base + Vector2(112.0, 0.0), 0.18)   # ㊿x：位移排队（显式 Tween：_player 无类型，:= 推不出来）
		await tw0.finished
		if not is_instance_valid(_player) or not is_instance_valid(_foe):
			return
		if _fx != null:
			_fx.flash(Color(1, 1, 1, 0.25))
			_fx.burst(_foe.global_position + Vector2(0.0, -95.0), "cut")
		var r := _roll_p_damage(mult)
		# ㊷：群伤大招（"target": "sweep"）铺满所有活着的敌人
		var dmg := 0
		if is_sweep_ult and alive_now > 1:
			# ㊿z8：**每一名**中招的对手都算一层（第一个也吃，第二个再叠一层）
			var per := float(_fx_buff.get("ult_per_hit", 0.0))
			var base_one := int(r["dmg"])
			var k2 := 0
			for i in _foes.size():
				if not _foe_alive(i):
					continue
				_focus_on(i)
				k2 += 1
				var one := base_one
				if per > 0.0:
					one = maxi(1, int(round(float(base_one) * (1.0 + per * float(k2)))))
				dmg += _foe_take(one)
			# ㊹：扫完把焦点挪回还活着的那个——否则聚焦停在一具尸体上，
			#   后面的血条/选目标都会跟着错。
			var bk := _front_foe()
			if bk >= 0:
				_focus_on(bk)
		else:
			dmg = _foe_take(int(r["dmg"]))
		if _fx != null and _foe != null and is_instance_valid(_foe):
			_num_foe(dmg)
			_foe.play_hit()
		_update_bars()
		# ㊺：横扫落到单体时把话说清楚——数字变重了，得让人知道为什么
		if solo_hit:
			UiKit.float_text(self, "只剩一人 · 长风破浪转单体重击", UiKit.SEAL, 168.0)
		print("[游历战斗] 我放大招『", un, "』：", dmg)
		# v46（用户："苏的被动暴击追击是只要暴击就追击，释放技能和大招也是哈"）：
		#   大招这一发暴击也追剑。⚠ 必须排在"退回原位"之前——追剑是从我身上打出去的，
		#   人还在对面的时候才看得见；也必须在 _foe_hp() 判定里（追剑自己会检查还活着没）。
		if bool(r["crit"]):
			_cur_crit = true
			await _song_follow()
		# ㊿z8：**撤了**"对单人时大招后回怒 20%"（设计改掉了）——数据里已删掉 ult_back_rage 这条。
		# ㊿z7：专武·长风诀——放完大招开"连发窗口"（turns+1：含当前这一手不完整的回合，
		#   此后每行动一次减 1，见 _strike 里那一句）
		if int(float(_fx_buff.get("ult_chain_turns", 0.0))) > 0:
			_a()["ult_chain_left"] = int(float(_fx_buff.get("ult_chain_turns", 0.0))) + 1
		var tw1: Tween = _player.push_move_to(_p_base, 0.2, Tween.TRANS_QUAD, Tween.EASE_IN)   # ㊿x：退回来同样排队
		await tw1.finished
		if float(_fx_buff.get("ult_window_regen", 0.0)) > 0.0:
			_window_left = 3   # ㉙：养晦卡——大招收势开后窗
		return
	if uk == "aura":
		# ㉙：时长读双键（旧 ult_dur / 新 aura_turns 都认）；反刺改"上限比例带"，不再读 0.35
		_ult_turns = int(_ult.get("turns", 3)) + int(maxf(float(_fx_buff.get("ult_dur", 0.0)), float(_fx_buff.get("aura_turns", 0.0))))
		_ult_regen_pct = float(_ult.get("regen_pct", 0.0))
		_ult_thorn = maxf(float(_fx_buff.get("thorn_up", 0.0)), float(_fx_buff.get("thorn_mul", 0.0)))
		_ult_thorn_on = true
		if _fx != null:
			_fx.flash(Color(1, 1, 1, 0.12))
		UiKit.float_text(self, "枪势起——" + str(_ult_turns) + " 手回气 · 挨打反刺（上限 8~12%）", UiKit.BLUE, 192.0)
		await _wait(0.5)
		return
	if uk == "song":
		# ============================================================
		# v11e（用户："先挂追击状态再打大招伤害也行 · 我说的是追击暴击不会继续追击
		#   但是武学啊 大招的多段啊 普攻产生的暴击依旧会追击"）
		#   ① **先挂追击状态**（turns 手 · 每次暴击追一剑 ×follow · 取后排）
		#   ② **再打出手那几段**（每段 mult）——**每一段各自掷暴击，暴击就追一剑**
		#   ③ 「不连锁」只约束**追剑自己**：追剑暴击只吃暴伤，不再生出新的追剑
		#      （SONG_CHAIN_MAX = 1）；普攻 / 武学 / 大招各段的暴击照追
		# ============================================================
		_ult_turns = int(_ult.get("turns", 3)) + int(maxf(float(_fx_buff.get("ult_dur", 0.0)), float(_fx_buff.get("song_turns", 0.0))))
		_ult_follow = float(_ult.get("follow", 0.6)) + maxf(0.0, float(_fx_buff.get("song_follow", 0.0)))
		_ult_new = true
		if _fx != null:
			_fx.flash(Color(1, 1, 1, 0.12))
		UiKit.float_text(self, "剑歌起——" + str(_ult_turns) + " 手，暴击追剑（取后排）", UiKit.BLUE, 192.0)
		var segn := maxi(1, int(_ult.get("hits", 1)))
		var segm := float(_ult.get("mult", 0.0)) * (1.0 + float(_fx_buff.get("ult_dmg", 0.0)))
		var keep_s := _focus
		var back_s := _back_foe()
		if back_s >= 0 and back_s != keep_s:
			_focus_on(back_s)
		var tws: Tween = _player.push_move_to(_p_base + Vector2(112.0, 0.0), 0.18)
		await tws.finished
		if not is_instance_valid(_player) or not is_instance_valid(_foe):
			return
		var seg_tot := 0
		for si in segn:
			if _foe_hp() <= 0:
				break
			if _fx != null and is_instance_valid(_foe):
				_fx.burst(_foe.global_position + Vector2(0.0, -95.0), "cut")
			var rs := _roll_p_damage(segm)
			var ds := _foe_take(int(rs["dmg"]))
			seg_tot += ds
			_num_foe(ds)
			_foe.play_hit()
			_update_bars()
			await _wait(0.16)
			# v11e：**这一段暴击 → 追一剑**（每一段各追一次；追剑自己不连锁）
			if bool(rs["crit"]) and _foe_hp() > 0:
				_cur_crit = true
				await _song_follow()
		print("[游历战斗] 我放大招『", un, "』：出手 ", segn, " 段，合计 ", seg_tot)
		# 焦点还回去（别让大招把"当前目标"永久抢到后排）
		if back_s >= 0 and back_s != keep_s:
			var back_to_s := keep_s if _foe_alive(keep_s) else _front_foe()
			if back_to_s >= 0:
				_focus_on(back_to_s)
		var tws2: Tween = _player.push_move_to(_p_base, 0.2, Tween.TRANS_QUAD, Tween.EASE_IN)
		await tws2.finished
		await _wait(0.5)
		return
	var r2 := _roll_p_damage(2.5)
	var dmg2 := _foe_take(int(r2["dmg"]))
	_update_bars()
	print("[游历战斗] 我放大招『", un, "』：", dmg2)

# ---- v6：精英招数与敌情面板 ----

# ============================================================
# v46：剑歌追剑——**只要这一手暴击就追**（普攻 / 武学 / 大招都算）
#   用户："苏的被动暴击追击是只要暴击就追击，释放技能和大招也是哈。"
#   原来这块只长在 _strike 里（普攻与武学都走那条，但**大招**走的是 _player_ult，
#   于是"放大招暴击"不追）。现在抽成这一口：_strike 与 _player_ult 两处都调它。
#   窗口（_ult_turns / _ult_follow）仍由大招「青鸾出岫」那支设；
#   专武·短歌行：追击伤害 +50%、追击自己暴击再 +20%、引吭卡再加 1 段。
# ============================================================
func _song_follow(depth := 1) -> void:
	# v49（用户："追击的暴击不触发追击"）：**追剑自己暴击 → 再追一层**。
	#   以前追剑只把暴击换成伤害（专武·短歌行那条 +20%），不会再生出新的追击，
	#   于是"只要暴击就追击"这句话在追击自己身上不成立。
	#   ⚠ 上限 SONG_CHAIN_MAX（与出村战斗同一个数）：期待值 p + p² + p³，不会无限连环。
	if depth > SONG_CHAIN_MAX:
		return
	if _ult_turns <= 0 or _ult_follow <= 0.0:
		return
	if _foe_hp() <= 0 or not is_instance_valid(_foe):
		return
	# v11b（用户："大招追击 且打后排"）：**追剑跟她普攻同一条路数——有后排就点后排**。
	#   她的自带「洞察」本来就是"持匕首绕开当面挡刀的"，追剑若还打在挡刀的身上，
	#   等于那条自带白写一半。打完把焦点还回去（原来那只还活着就还回去，死了退最前排）。
	#   ⚠ 连环那一层是递归进来的：两层都会切一次、也都还一次，幂等，不会越切越偏。
	var keep_focus := _focus
	var back_i := _back_foe()
	if back_i >= 0 and back_i != keep_focus:
		_focus_on(back_i)
	var f_up := 1.0 + float(_fx_buff.get("follow_dmg", 0.0))
	var fc_up := 1.0 + float(_fx_buff.get("follow_crit_up", 0.0))
	for hi2 in 1 + int(_fx_buff.get("follow_hits", 0.0)):
		if _foe_hp() <= 0:
			break
		var fr2 := _roll_p_damage(_ult_follow * f_up)
		var fdmg2 := int(fr2["dmg"])
		var fcrit2 := bool(fr2["crit"])
		if fcrit2:
			fdmg2 = maxi(1, int(round(float(fdmg2) * fc_up)))
		fdmg2 = _foe_take(fdmg2)
		if _fx != null and is_instance_valid(_foe):
			_fx.burst(_foe.global_position + Vector2(0.0, -95.0), "cut")
			_num_foe(fdmg2)
			if fcrit2:
				_fx.number("追击暴击" + ("·连环 " + str(depth) if depth > 1 else ""), _foe, UiKit.GOLD)
		_foe.play_hit()
		_update_bars()
		await _wait(0.12)
		# 追剑自己暴击 → 再追一层（有上限）
		if fcrit2 and depth < SONG_CHAIN_MAX and _foe_hp() > 0:
			await _song_follow(depth + 1)
	if back_i >= 0 and back_i != keep_focus:
		# 焦点还回去（别让追剑把"当前目标"永久抢到后排去）
		var back_to := keep_focus if _foe_alive(keep_focus) else _front_foe()
		if back_to >= 0:
			_focus_on(back_to)

# ============================================================
# v52：负面状态（缴械 / 燃烧 / 震慑 / 破防 / 虚弱 / 迟缓 / 封脉）
#   用户："参考三国志谋定天下这款 SLG，我要加一些负面状态，类似缴械啊、燃烧啊 等"
#   表与 API 都在 shared/data_status.gd（出村那边共用同一份，规矩只写一遍）。
#   这里只做三件事：
#     ① 每手开头结算（掉血 + 时长递减）——在 _strike() 里、本人出手之前，
#        与既有的"毒发"是同一个位置、同一个口径
#     ② 效果兑现——不能普攻 / 不能放武学 / 放不出大招 / 整手不出 /
#        出手方攻击 / 挨打方受伤 / 出手顺序 / 怒气获取 / 回血倍率 / 技能冷却 / 被动失效
#     ③ 播报（战报＋浮字）与血条下面那一行
#   ⚠ 掉血**不吃减伤**（与毒/自爆同口径）：按气血上限的比例直接扣。
#   ⚠ 顺序必须与出村一致：**先看 skips() 再 tick()**——反了的话，
#     结算会把震慑的时长先减掉，那一手就永远震慑不住（出村那边踩过这个坑）。
# ============================================================

# ============================================================
# v54：**闭窍**（被动失效）——用户："闭窍是针对玩家的"
#   压住玩家这一侧的四条被动线：
#     · 自带天赋——inn_thorn，以及 _roll_p_damage 里那两段现算的自带增伤（闭着时直接跳过）
#     · 被动功法（专武）——fx_buff 里那批机制键（下面 PASSIVE_FX_KEYS）
#     · 五问天赋——talent_cut / talent_wpn
#     · 角色星——crit_add、以及并进 fx_buff 的那几条（猎影/凝息/破浪…）
#   做法＝备份—压零—还原；压着期间不重复备份（"续上"不会把压成 0 的值当原值）。
#   ⚠ 还不了的那一份：已经算进**气血上限**的（自家 hp_pct / 星的气血）——血条不会缩。
#   ⚠ fx_buff 里 `ult_dmg`、`art_cd_minus` 这类键**卡与被动共用**（破军卡/冰心卡），
#     压掉被动时那一份卡收益也一起停了——分不开，这条写清。
# ============================================================
const PASSIVE_FX_KEYS := [
	"passive_up", "passive_mul", "crit_low_pct", "crit_mul_up",
	"ult_dmg", "ult_per_hit", "ult_chain_up", "ult_chain_turns", "ult_cut",
	"thorn_per_hit", "thorn_all", "thorn_heal", "thorn_up",
	"follow_dmg", "follow_crit_up", "follow_hits", "art_any_weapon",
	"rage_on_hit", "rage_pct", "open_rage",
	"art_cd_minus", "ult_window_regen", "weapon_mul",
]
const PASSIVE_ZERO := {
	"talent_cut": 0.0, "talent_wpn": 1.0, "crit_add": 0.0, "cut_add": 0.0,
	"rage_mul": 1.0, "inn_thorn": 1.0,
}

func _passive_mask(al: Dictionary) -> void:
	if al.is_empty() or al.has("pas_bak"):
		return
	var bak: Dictionary = {}
	for k in PASSIVE_ZERO.keys():
		if al.has(k):
			bak[k] = al[k]
			al[k] = PASSIVE_ZERO[k]
	# fx_buff：只把"被动那一批键"摘掉（卡的那些键留着），整份备份
	if al.has("fx_buff"):
		var fb: Dictionary = (al["fx_buff"] as Dictionary).duplicate()
		bak["__fx"] = fb
		var keep: Dictionary = {}
		for k2 in fb.keys():
			if PASSIVE_FX_KEYS.has(str(k2)):
				continue
			keep[k2] = fb[k2]
		al["fx_buff"] = keep
	al["pas_bak"] = bak
	UiKit.float_text(self, str(al.get("name", "我")) + " 被动全被压住", St.col_of("nopassive"), 192.0)

func _passive_unmask(al: Dictionary) -> void:
	if al.is_empty() or not al.has("pas_bak"):
		return
	var bak: Dictionary = al["pas_bak"]
	for k in bak.keys():
		if str(k) == "__fx":
			al["fx_buff"] = bak[k]
		else:
			al[k] = bak[k]
	al.erase("pas_bak")

# 给某人挂状态（spec ＝ 武学/怪招/词缀里的 "apply"）。返回 true ＝ 挂上了
# ⚠ is_foe：立刻效果（挫锐打怒气 / 滞涩推后当前冷却）要落在"挨打那一侧"的字段上，
#   而两边的存法不同（我方在 _allies[i]，敌方在 _cur()，冷却还在 _state.art_cd 里），所以传进来。
func _st_hit(u: Dictionary, spec: Dictionary, who: String, is_foe := false) -> bool:
	if u.is_empty() or spec.is_empty():
		return false
	var sid := str(spec.get("id", ""))
	if sid == "" or St.def_of(sid).is_empty():
		return false
	var ch := float(spec.get("chance", 1.0))
	if ch < 1.0 and randf() >= ch:
		return false
	var msg := St.apply(u, sid, int(spec.get("turns", 0)), int(spec.get("stacks", 1)))
	if msg == "":
		return false
	UiKit.float_text(self, who + " " + St.name_of(sid) + "！", St.col_of(sid), 192.0)
	_blog(who + " 中招：" + msg, "bomb")
	# v54：「闭窍」——被动线全压住（玩家这一侧）
	if bool(St.def_of(sid).get("block_passive", false)):
		_passive_mask(u)
	# ---- v53：上状态那一刻的"立刻效果"（挫锐当场打怒气 / 滞涩把当前冷却推后）----
	var dd: Dictionary = St.def_of(sid)
	var rb := int(dd.get("rage_burn", 0))
	if rb > 0:
		if is_foe:
			_set_foe_rage(maxi(0, _foe_rage() - rb))
		else:
			u["rage"] = maxi(0, int(u.get("rage", 0)) - rb)
		_blog("　锐气被打散：怒气 −" + str(rb), "hit")
	var ca := int(dd.get("cd_add", 0))
	if ca > 0:
		if is_foe:
			if _foe_art_cd() > 0:
				_set_foe_art_cd(_foe_art_cd() + ca)
		elif _state != null:
			# 我方的冷却按"这一手当前是谁"存在 run_state 里（逐人一份）
			_state.use_member(int(u.get("row", _state.active_i)))
			for sid2 in _state.arts:
				var s2 := str(sid2)
				if int(_state.art_cd.get(s2, 0)) > 0:
					_state.set_art_cd(s2, int(_state.art_cd.get(s2, 0)) + ca)
			_state.use_member(_p_focus)
		_blog("　经脉滞涩：技能冷却 +" + str(ca) + " 手", "hit")
	_update_bars()
	return true

# 每手开头结算（护盾衰减 + 掉血 + 印记爆发 + 时长递减）。返回 true ＝ 这人已经倒下了
func _st_tick(u: Dictionary, hp_max: int, who: String, is_ally: bool) -> bool:
	# v58：把出手方那一份攻击传进 ctx —— 「鎏金三叠」按攻击算段伤（两套引擎同一份数）
	var r: Dictionary = St.tick(u, hp_max, {"atk": float(u.get("atk", 0.0))})
	var dm := int(r.get("dmg", 0))
	if dm > 0:
		if is_ally:
			_hp = maxi(0, _hp - dm)          # 走转发属性：受击回怒那一套照旧生效
		else:
			_set_foe_hp(maxi(0, _foe_hp() - dm))
		var tail := "、".join(PackedStringArray(r.get("msgs", [])))
		UiKit.float_text(self, "状态 -" + str(dm) + "（" + tail + "）", Color(0.62, 0.34, 0.24), 192.0)
		_blog(who + " 状态发作 −" + str(dm) + "（" + tail + "）", "hit")
		_update_bars()
	# v58：护盾自然衰减（每回合 10%）——岩甲的护盾按"当前值"缩
	var sl := int(r.get("shield_lost", 0))
	if sl > 0:
		UiKit.float_text(self, "护盾消减 -" + str(sl), Color(0.56, 0.42, 0.24), 176.0)
	# v58：**印记爆发**（叠到阈值且这一条还没爆过）——数值已经在 data_status 里算好
	#   （掉血/爆发都吃"上这一条时那一手的元素加成"），这里只负责"打给谁 + 飘字"。
	#   ⚠ **打谁由 list[].to 说了算**：负面印记（燃烧/水浸）打**背着它的那个人**；
	#     正面印记（鎏金/寄生/岩甲）打**他的对手**。第一版一律打对手，
	#     结果敌人身上的爆燃把主角炸了 1613（探针当场抓到的）。
	var bd: Dictionary = r.get("burst", {})
	for one_v in (bd.get("list", []) as Array):
		var one: Dictionary = one_v
		var bdmg := int(one.get("dmg", 0))
		if bdmg <= 0:
			continue
		var bel := str(one.get("elem", ""))
		var btxt := ", ".join(PackedStringArray(one.get("lines", [])))
		var to_carrier := str(one.get("to", "foe")) == "self"
		# 换算成"这一发打的是谁"：carrier 是 u 自己
		var hits_foe: bool = (not is_ally) if to_carrier else is_ally
		if hits_foe:
			_set_foe_hp(maxi(0, _foe_hp() - bdmg))
			_blog(who + " 印记爆发 → " + str(_cur().get("name", "敌")) + " −" + str(bdmg) + "（" + btxt + "）", "bomb")
			if _fx != null and is_instance_valid(_foe):
				_fx.number(str(bdmg), _foe, Elem.col(bel), bel)
		else:
			_hp = maxi(0, _hp - bdmg)
			_blog(who + " 印记爆发 → " + str(_a().get("name", "我")) + " −" + str(bdmg) + "（" + btxt + "）", "bomb")
			UiKit.float_text(self, btxt, Elem.col(bel), 176.0)
		_update_bars()
	# v58：「踏浪」——不造成伤害，把对手的水抗夺过来（转成自己的水增伤与速度）
	for sb in (bd.get("self_bursts", []) as Array):
		var sid2 := str(sb)
		if sid2 != "soak":
			continue
		var lv := St.stacks(u, "soak")
		var v := float(St.def_of("soak").get("burst_v", 0.15)) * float(maxi(1, lv))
		var steal_from: Dictionary = _cur() if is_ally else u
		var steal_to: Dictionary = u if is_ally else _a()
		var rr: Dictionary = St.steal_res(steal_from, steal_to, "water", v)
		var txt := "「踏浪」夺水抗 " + str(int(rr["res"] * 100.0)) + "% → 自己水伤 +" + str(int(rr["dmg_pt"])) + "% · 速度 +" + str(int(rr["spd_pt"])) + "%"
		UiKit.float_text(self, txt, Elem.col("water"), 176.0)
		_blog(who + " " + txt, "sys")
		_update_bars()
	for g in (r.get("gone", []) as Array):
		_blog("　「" + str(g) + "」散了", "sys")
		# v54：闭窍到期——被动线原样还回来
		if str(g) == St.name_of("nopassive"):
			_passive_unmask(u)
	return int(u.get("hp", 0)) <= 0

# 血条下面那一行（"负：燃烧2 · 缴械"；没有状态＝空串）
#   v54：后面缀上全局规则那条底账（"受伤 +8%"）
func _st_mark(u: Dictionary) -> String:
	var ln := St.line(u)
	if ln == "":
		return ""
	var vn := St.vuln_note(u)
	return "负：" + ln + ("" if vn == "" else "（" + vn + "）")

# v52：招式自带的状态挂到**当前聚焦的那只怪**身上（打完才挂——调用点都在伤害结算之后）
func _st_art_foe(art: Dictionary) -> void:
	if art.is_empty() or _foe_hp() <= 0:
		return
	_st_hit(_cur(), art.get("apply", {}), str(_cur().get("name", "敌")), true)

# v52：词缀"击中就上状态"（火魔/铁锁）——与既有的毒刃同一个位置，两个挨打口都调它
# v53：**闭窍**在身时词缀整个失效（_foe_affixes 会被压成空表），所以这里天然挂不上
func _st_affix_hit(target: Dictionary, who: String) -> void:
	if int(target.get("hp", 0)) <= 0:
		return
	for af in _foe_affixes():
		var spec: Dictionary = Affixes.on_hit(str(af))
		if not spec.is_empty():
			_st_hit(target, spec, who, false)

# v53：驱散（清心诀）——全队洗掉负面 + 磕掉当前对手的护体与蓄势
func _cleanse_apply(art: Dictionary) -> void:
	var ids := _bless_targets(str(art.get("target", "ally_all")))
	var who: Array = []
	for i_v in ids:
		var i := int(i_v)
		if i < 0 or i >= _allies.size():
			continue
		var al: Dictionary = _allies[i]
		if int(al.get("hp", 0)) <= 0:
			continue
		var msg := St.cleanse(al, int(art.get("cleanse", 1)))
		# v54：洗掉「闭窍」＝被动线还原
		if msg.contains(St.name_of("nopassive")):
			_passive_unmask(al)
		var an = _ally_nodes[i] if i < _ally_nodes.size() else null
		if _fx != null and an != null and is_instance_valid(an):
			_fx.burst(an.global_position + Vector2(0.0, -95.0), "heal")
		if msg != "":
			who.append(str(al.get("name", "")) + " " + msg)
	if bool(art.get("dispel_foe", false)) and _foe_alive(_focus):
		var had: Array = []
		if _foe_guard() > 0:
			_set_foe_guard(0)
			_set_foe_guard_cut(0.0)
			had.append("护体")
		if _foe_next_mult() > 1.0:
			_set_foe_next_mult(1.0)
			had.append("蓄势")
		if not had.is_empty():
			who.append(str(_cur().get("name", "敌")) + " 被磕掉" + "、".join(PackedStringArray(had)))
	if who.is_empty():
		_blog(str(_a().get("name", "我")) + " 施『" + str(art.get("move", "清心诀")) + "』：身上本就干净，白走一手。", "sys")
		return
	_blog(str(_a().get("name", "我")) + " 施『" + str(art.get("move", "清心诀")) + "』：" + "；".join(PackedStringArray(who)), "heal")
	UiKit.float_text(self, "清心涤虑", UiKit.BLUE, 192.0)

# ============================================================
# v62q（用户终表）：铁衣签——**受到伤害 -50%，但所有治疗效果（包括吸血）削弱 80%**。
#   这里是"治疗系数"唯一的口：所有回血点都乘它（生生卡/续命签那种每 N 手回、
#   护主回春、大招窗口回气、养晦、反刺回血、吸血…）。
#   ⚠ 只削"治疗"，不碰护盾/减伤——那两条是铁衣签自己的好处。
# ============================================================
func _heal_mul() -> float:
	return maxf(0.0, 1.0 - float(_fx_buff.get("heal_cut", 0.0)))

func _foe_take(raw: int) -> int:
	var dmg := maxi(1, raw)
	# v55：词缀·坚壁——挨打两成半几率硬挡，那一下只吃两成
	#   （不做"完全免伤"：0 伤害会在战报里飘个 −0、"是否命中"也串味）
	if _foe_affixes().has("bulwark") and randf() < Affixes.BULWARK_CHANCE():
		dmg = maxi(1, int(round(float(dmg) * Affixes.BULWARK_TAKE())))
		UiKit.float_text(self, str(_cur().get("name", "敌")) + " 坚壁！", Color(0.44, 0.44, 0.50), 192.0)
	# ============================================================
	# v52：负面状态的两条乘数——**出手方的「虚弱」→ 这一下更轻**、
	#   **挨打方的「破防」→ 这一下更重**。放在最前头（攻防对拼之前）：
	#   它们跟"用哪一招"无关，与出村那边 `_e_take` 的位置一字不差。
	#   出手的恒是我（_a() 是当前聚焦那一名队员），挨打的恒是 _cur()。
	# ============================================================
	var st_am := St.atk_mul(_a())
	if not is_equal_approx(st_am, 1.0):
		dmg = maxi(1, int(round(float(dmg) * st_am)))
	var st_tm := St.taken_mul(_cur())
	if not is_equal_approx(st_tm, 1.0):
		dmg = maxi(1, int(round(float(dmg) * st_tm)))
	# ============================================================
	# v58（用户第 4 条："防御只对物理有效"）：**元素伤害不走攻防对拼**，
	#   改走挨打方的**对应五行抗性**（`Elem.res_mul`，正抗性减伤、负抗性多挨）。
	#   出手的恒是我（_a()），挨打的恒是 _cur()——与下面那段的站位口径一致。
	#   ⚠ 抗性要**加上「踏浪」夺走的那一份**（`St.res_shift`，负＝被夺）
	# ============================================================
	if Elem.is_elem_attack(_cur_elem):
		var res_pct := float(_cur().get(Elem.res_key(_cur_elem), 0.0)) + St.res_shift(_cur(), _cur_elem)
		var cut := Elem.res_mul(res_pct)
		if not is_equal_approx(cut, 1.0):
			dmg = maxi(1, int(round(float(dmg) * cut)))
	else:
		# v35：攻防对拼——出手的恒是我（_a() 是当前聚焦那一名队员），
		#   我的攻击值 vs 敌人的防御值（表里没写就按它的攻击折一半，见 GameData.foe_def）。
		var my_atk := float(_a().get("atk", 0.0))
		var foe_def := float(_cur().get("def", 0))
		if my_atk > 0.0 and foe_def > 0.0:
			dmg = GameData.after_def(float(dmg), my_atk, foe_def)
	# v36：战报——我打出去这一下（招式名由 _strike/_player_ult 先写进 _cur_move）
	if dmg > 0:
		_log_hit(str(_a().get("name", "我")), _cur_move, str(_cur().get("name", "敌")), dmg,
			"crit" if _cur_crit else "deal", "暴击" if _cur_crit else "")
	if _foe_guard() > 0:
		_set_foe_guard(_foe_guard() - (1))
		dmg = maxi(1, int(round(float(dmg) * _foe_guard_cut())))
		UiKit.float_text(self, "横练卸力", Color(0.46, 0.44, 0.42), 192.0)
		if _foe_guard() <= 0:
			_set_foe_guard_cut(0.0)
	_apply_elem_mark_on_hit()
	# v58（用户第 5 条）：**护盾**先挨——没打光之前不掉气血。
	#   护盾来源是「岩甲」印记（也有可能来自别处，所以判的是单位字典那一格）
	if St.shield_of(_cur()) > 0:
		var ab: Dictionary = St.shield_absorb(_cur(), dmg)
		if int(ab["absorbed"]) > 0:
			UiKit.float_text(self, "护盾 -" + str(int(ab["absorbed"])), Color(0.56, 0.42, 0.24), 176.0)
			_blog("　护盾挡下 " + str(int(ab["absorbed"])) + "（剩 " + str(St.shield_of(_cur())) + "）", "guard")
		dmg = int(ab["hp"])
		if dmg <= 0:
			_update_bars()
			return 0
	_set_foe_hp(maxi(0, _foe_hp() - dmg))
	# v7：词缀——战意/电盾（出手的恒是我）
	if dmg > 0:
		if _foe_affixes().has("fury"):
			_set_foe_stack(minf(Affixes.FURY_CAP(), _foe_stack() + Affixes.FURY_STEP()))
		if _foe_affixes().has("thorns"):
			# ㉕：按原始数。㊿：再加硬上限——一次最多打掉挨反那人上限的 THORN_CAP()，
			#   攻击叠多高都不会"一击被反死"。
			var rf := maxi(1, int(round(float(raw) * Affixes.THORN_PCT())))
			rf = mini(rf, maxi(1, int(round(float(_my_hp_max) * Affixes.THORN_CAP()))))
			_hp = maxi(0, _hp - rf)
			# ㉙：橙字打在我身上——"反伤"（橙）与回复（绿）一眼分开
			if _fx != null and _player != null and is_instance_valid(_player):
				_fx.number("反伤 -" + str(rf), _player, C_COUNTER)
			else:
				UiKit.float_text(self, "反伤 -" + str(rf), C_COUNTER, 192.0)
		if _foe_affixes().has("shock") and randf() < Affixes.SHOCK_CHANCE():
			_skip_next = true
			UiKit.float_text(self, "电盾反弹——手上一麻！", UiKit.BLUE, 192.0)
	# ============================================================
	# v62m（用户："锐意 为5%吸血"）：**吸血**——命数/卡给的 lifesteal 比例，
	#   按这一下的**最终伤害**回血（回给出手那位 `_a()`，不超过他自己上限）。
	#   ⚠ 挂在 `_foe_take` 的尾巴上：所有乘数（虚弱/破防/抗性/护盾）都算完了，
	#     吸到的是真正打进敌人身上的那个数——不是面板伤害。
	#   ⚠ 只有游历这边认这个键（命数只存在于游历），村里那套不掺和。
	# ============================================================
	if dmg > 0:
		var ls := float(_fx_buff.get("lifesteal", 0.0))
		if ls > 0.0:
			var al3: Dictionary = _a()
			var hmax := maxi(1, int(al3.get("hp_max", 1)))
			var cur_hp := int(al3.get("hp", 0))
			if cur_hp > 0 and cur_hp < hmax:
				var heal_ls := maxi(1, int(round(float(dmg) * ls * _heal_mul())))
				heal_ls = mini(heal_ls, hmax - cur_hp)
				if heal_ls > 0:
					al3["hp"] = cur_hp + heal_ls
					# 浮字颜色走本文件既有那一支（714 行那个"回复绿"）——绿色＝回复
					if _fx != null and _player != null and is_instance_valid(_player):
						_fx.number("吸血 +" + str(heal_ls), _player, Color(0.30, 0.52, 0.32))
					else:
						UiKit.float_text(self, "吸血 +" + str(heal_ls), UiKit.GREEN, 176.0)
					_update_bars()
	return dmg

# ㉙：枪势反刺现算——按陈石气血上限的比例带 8%~12%：挨的打越重比例越高；
# 铁蒺卡（thorn_up/thorn_mul）整带加乘。
# ㊳：自带若带 thorn_up（原来的「断枪」＝用枪时 ×1.1），这里再乘一道 _inn_thorn。
#   ㊿：陈石的自带已改成「守拙」（气血上限 +20%），这条乘数现在恒为 1——
#   引擎的 thorn_up 自带留着，谁挂上谁吃这一乘。
func _thorn_calc(raw_hit: int) -> int:
	var ratio := clampf(float(raw_hit) / float(maxi(1, _my_hp_max)), 0.0, 1.0)
	var pct := lerpf(THORN_HP_LO, THORN_HP_HI, ratio)
	pct *= 1.0 + _ult_thorn
	pct *= _inn_thorn
	# ㊿z6：专武·铁壁桩功——自己每击中一名敌人攒的"反刺增幅"（封顶 +100%）
	pct *= 1.0 + clampf(float(_a().get("thorn_ramp", 0.0)), 0.0, 1.0)
	return maxi(1, int(round(float(_my_hp_max) * pct)))

# v7：敌攻击现算（狂暴 ×1.6；鼓舞/战意叠加）
func _foe_atk_eff() -> float:
	var v := float(_foe_atk())
	if _foe_affixes().has("berserk") and _foe_hp() * 2 <= _foe_hp_max():
		v *= Affixes.BERSERK_MUL()
	return v * (1.0 + _foe_stack())

# ㊿z：角色星·陈石「铁桩」——受击回怒。
#   走 `_hp` 的那些口（普通攻击的挨打）由 _hp 的 setter 统一管；
#   直接改 `_allies[i]["hp"]` 的口（自爆这种群体伤害）在这里补一下。
func _rage_on_hit(al: Dictionary) -> void:
	var rid := str(al.get("role_id", ""))
	if rid == "":
		return
	var rh := float(_state.buff_fx(rid).get("rage_on_hit", 0.0))
	if rh <= 0.0:
		return
	# ㊿z7：单位是**比例**（0.15＝满怒的 15%，怒气上限 100）
	# v53：受击回怒同样吃「挫锐」
	al["rage"] = mini(100, int(al.get("rage", 0)) + int(round(100.0 * rh * St.rage_mul(al))))

# v7：自爆——倒下时炸一下；炸死了我，这局就算不敌
# ㊿：**改成群体**——一只怪炸开，全队每个人都按**自己的**上限挨四成。
#   基数仍是"挨炸那个人的上限"（不是怪的上限），所以满血的人不会被一下炸死；
#   但一炸全队都掉四成，两只自爆怪连着死＝全队八成——很凶，嫌狠改 affix/bomb_pct。
# v36（用户："自爆全体不要炸到自己人 · 也要有提示，比如 自爆 180"）：
#   · **只炸对面**——这里从头到尾只遍历 `_allies`（我方），绝不会炸到它自己的同伴；
#     出村战斗（battle_lite._enemy_bomb）也只遍历 `_party`。这条现在写进注释与词缀说明里。
#   · **提示做足**：横幅写"自爆 N"（N＝这一炸最重的那一下）、每个挨炸的人头上飘 −N、
#     战报再记一行"名字 自爆 → 谁 −N、谁 −N"。
func _foe_bomb_if_dead() -> void:
	if not _foe_affixes().has("bomb") or _hp <= 0:
		return
	_fx.flash(Color(1, 0.85, 0.6, 0.35))
	var seg: Array = []
	var worst := 0
	# 先把数字算齐（横幅要写"自爆 N"，所以先跑一遍再摆提示）
	for i in _allies.size():
		var al: Dictionary = _allies[i]
		if int(al.get("hp", 0)) <= 0:
			continue
		var amax := maxi(1, int(al.get("hp_max", 1)))
		var bd := maxi(1, int(round(float(amax) * Affixes.BOMB_PCT())))
		worst = maxi(worst, bd)
		al["hp"] = maxi(0, int(al.get("hp", 0)) - bd)
		_rage_on_hit(al)   # ㊿z：铁桩——挨炸也算挨打
		seg.append(str(al.get("name", "")) + " −" + str(bd))
		var an = _ally_nodes[i] if i < _ally_nodes.size() else null
		if _fx != null and an != null and is_instance_valid(an):
			_fx.burst(an.global_position + Vector2(0.0, -95.0), "hit")
			_fx.number("−" + str(bd), an, Color(0.85, 0.45, 0.16), _foe_cur_elem)   # v36：每个人头上飘自己挨的数
	_blog(str(_cur().get("name", "敌")) + " 自爆 " + str(worst) + " → " + "、".join(PackedStringArray(seg)), "bomb")
	_banner("轰——自爆 " + str(worst) + "！", UiKit.SEAL)
	UiKit.float_text(self, "自爆 " + str(worst) + "　" + "、".join(PackedStringArray(seg)), UiKit.SEAL, 214.0)
	_mark_hit_if_hurt()      # ㊿：轻身卡——挨炸也算受击（谁掉了血就置谁）
	_update_bars()
	await _wait(0.5)

# ㊹：逐只补倒地动画。多人上场后"只倒一两只"是常态（群攻大招尤其明显），
#   不能等全灭才倒。用每只自己的 "downed" 标记保证只演一次。
func _foe_fall_if_dead() -> void:
	for i in _foes.size():
		var f: Dictionary = _foes[i]
		if int(f.get("hp", 0)) > 0 or bool(f.get("downed", false)):
			continue
		f["downed"] = true
		_blog(str(f.get("name", "敌")) + " 倒下了", "sys")   # v36：战报
		if i >= _foe_nodes.size():
			continue
		var n = _foe_nodes[i]
		if n != null and is_instance_valid(n):
			n.play_down()

func _foe_art_dmg(mult: float) -> Dictionary:
	var base := _foe_atk_eff() * mult * _foe_next_mult() * randf_range(0.9, 1.1)
	base *= _ambush_mul()   # ㊿：偷袭——招数同样吃这条（点名越排时才可能吃到）
	_set_foe_next_mult(1.0)
	var raw := maxi(1, int(round(base)))   # ㉕：原始数
	base *= 1.0 - _cut_add
	# ㉗：百折不挠——气血不足三成时再减一层
	if _talent_cut > 0.0 and _hp * 10 <= _my_hp_max * 3:
		base *= 1.0 - _talent_cut
		if not _talent_cut_noted:
			_talent_cut_noted = true
			UiKit.float_text(self, "百折不挠 · 站得住", UiKit.GOLD, 192.0)
	var guarded := false
	if _guard_left > 0:
		base *= _guard_cut
		_guard_left -= 1
		guarded = true
	# v35：闪避 → 防御（可能回 0＝闪掉）
	return {"dmg": _p_mitigate(maxi(1, int(round(base)))), "guard": guarded, "raw": raw}

func _foe_show_hit(dmg: int, guarded: bool, raw_dmg := -1) -> void:
	# ㊿：加持减伤（坚壁旗令/同心结阵）——**就卡在这一处**：所有落到我方的伤害
	#   （普攻、精英招数、大招、群攻逐个聚焦）最后都走这个函数，
	#   所以只要在这里减一次，就不怕漏掉某条路径。
	#   ⚠ raw_dmg 是"原始数"，陈石的反刺按它算、不吃减伤——所以只动 dmg。
	# v35：闪避与防御**不在这里**——它们在算伤害那一步（_roll_e_damage / _foe_art_dmg
	#   里的 _p_mitigate），因为"闪掉"要让这一手整个作废（不是扣 0 点血那么简单）。
	var bcut := float(_a().get("bless_cut", 0.0))
	# ㊿z6：专武·铁壁桩功——大招窗口（枪势）里额外减伤 +15%（与加持减伤取大，不叠乘）
	bcut = maxf(bcut, _ex_ult_cut())
	if bcut > 0.0:
		dmg = maxi(1, int(round(float(dmg) * (1.0 - bcut))))
	# v36：战报——敌人这一手打到我方身上（招数/大招都走这里；普攻在 _strike 里记）
	_log_hit(str(_cur().get("name", "敌")), _cur_move, str(_a().get("name", "我")), dmg,
		"crit" if guarded else "hit", "护体卸力" if guarded else "")
	_hp = maxi(0, _hp - dmg)
	var veng := minf(float(_fx_buff.get("vengeance", 0.0)), Buffs.VENG_CAP)   # ㉙：回气卡——受伤后下一击 +20%（㊿：10%→20%，且**封顶**：请两张也只算 20%）
	if veng > 0.0:
		_next_mult = maxf(_next_mult, 1.0 + veng)
	if guarded:
		UiKit.float_text(self, "铁布衫挡下一击（剩 " + str(_guard_left) + " 次）", UiKit.BLUE, 192.0)
	if _fx != null and is_instance_valid(_player):
		_fx.burst(_player.global_position + Vector2(0.0, -95.0), "cut")
		_num_me(dmg, _player)
	if _player != null and is_instance_valid(_player):
		_player.play_hit()
		_player.modulate = Color(1.8, 1.8, 1.8, 1)
		var mt := create_tween()
		mt.tween_property(_player, "modulate", Color.WHITE, 0.2)
		# ㊿x：同上——挨打抖动走位移队列
		_player.push_move_to(_p_base + Vector2(-12.0, 2.0), 0.07)
		_player.push_move_to(_p_base, 0.12)
	if _foe_affixes().has("poison") and _hp > 0:
		_p_poison = mini(Affixes.POISON_MAX(), _p_poison + 1)
		UiKit.float_text(self, "毒刃入体 +1（" + str(_p_poison) + " 层）", Color(0.42, 0.62, 0.30), 192.0)
	# v52/v55：词缀·火魔/铁锁/锁喉/软筋/缠足/裂甲/泄气/滞脉/封穴/点窍
	#   ——击中就上状态（"哪个词缀上什么状态"写在 data_affixes.ON_HIT，以后加词缀不用动引擎）
	if _hp > 0:
		_st_affix_hit(_a(), str(_a().get("name", "我")))
	# v55：词缀·吸血——击中回自己上限的 6%（打得越久它越精神）
	if _foe_affixes().has("leech") and _foe_hp() > 0 and _foe_hp() < _foe_hp_max():
		var lh := maxi(1, int(round(float(_foe_hp_max()) * Affixes.LEECH_PCT())))
		_set_foe_hp(mini(_foe_hp_max(), _foe_hp() + lh))
		UiKit.float_text(self, str(_cur().get("name", "敌")) + " 吸血 +" + str(lh), Color(0.62, 0.24, 0.32), 192.0)
		_blog(str(_cur().get("name", "敌")) + " 咬住不放，吸回一口气 +" + str(lh), "heal")
	# ㉙：枪势反刺——按陈石上限 8%~12% 现算；橙字打在敌人身上
	# ㊿z6：专武·铁壁桩功把它扩成"反刺全体 + 每次回血 + 累计增幅"；
	#   没这门专武的人走原路（只反当前那一只）——数值一模一样。
	if _ult_turns > 0 and _ult_thorn_on and _foe_alive(_focus):
		var tb := dmg
		if raw_dmg > 0:
			tb = raw_dmg   # ㉕：反刺按"敌原始数"定比例带（不吃我方减伤）
		var all_flag := float(_fx_buff.get("thorn_all", 0.0)) > 0.0
		var heal_r := float(_fx_buff.get("thorn_heal", 0.0))
		if all_flag or heal_r > 0.0 or float(_fx_buff.get("thorn_per_hit", 0.0)) > 0.0:
			var amt := _thorn_calc(tb)
			var n_hit := 0
			for i in _foes.size():
				if not _foe_alive(i):
					continue
				if not all_flag and i != _focus:
					continue
				_focus_on(i)
				var one := amt if not all_flag else maxi(1, int(round(float(amt) * 0.6)))
				_set_foe_hp(maxi(0, _foe_hp() - one))
				if _fx != null and _foe != null and is_instance_valid(_foe):
					_fx.number("反伤 -" + str(one), _foe, C_COUNTER)
				n_hit += 1
			if n_hit > 0 and heal_r > 0.0:
				# v53：专武回血也吃「封脉」（只剩三成）
				var hh := maxi(1, int(round(float(_my_hp_max) * heal_r * St.heal_mul(_a()) * _heal_mul())))
				_hp = mini(_my_hp_max, _hp + hh)
				UiKit.float_text(self, "桩劲回气 +" + str(hh), UiKit.GREEN, 192.0)
		else:
			var rbt := _thorn_calc(tb)
			_set_foe_hp(maxi(0, _foe_hp() - rbt))
			if _fx != null and _foe != null and is_instance_valid(_foe):
				_fx.number("反伤 -" + str(rbt), _foe, C_COUNTER)
			else:
				UiKit.float_text(self, "反伤 -" + str(rbt), C_COUNTER, 192.0)
	_update_bars()

func _foe_art_strike(a: Dictionary) -> void:
	if _foe == null or not is_instance_valid(_foe):
		return
	var anm := str(a.get("name", "杀招"))
	var kind := str(a.get("kind", "damage"))
	_cur_move = "『" + anm + "』"   # v36：战报
	_set_foe_art_cd(int(a.get("cd", 3)) + St.cd_add(_cur()))   # v53：滞涩——首领的冷却也 +2
	_banner("『" + anm + "』", UiKit.SEAL)
	var tw: Tween = _foe.push_move_to(_e_base + Vector2(-92.0, 0.0), 0.15)   # ㊿x：位移排队
	await tw.finished
	if not is_instance_valid(_foe):
		return
	if kind == "guard":
		_set_foe_guard(int(a.get("turns", 2)))
		_set_foe_guard_cut(float(a.get("cut", 0.78)))
		if _fx != null:
			_fx.flash(Color(1, 1, 1, 0.12))
		UiKit.float_text(self, "横练周身 · 下 " + str(_foe_guard()) + " 次受击减伤 " + str(int(round((1.0 - _foe_guard_cut()) * 100.0))) + "%", Color(0.46, 0.44, 0.42), 192.0)
	elif kind == "heal":
		# v53：「封脉」在身——这一口只剩三成
		var fhm := St.heal_mul(_cur())
		if fhm < 1.0:
			UiKit.float_text(self, str(_cur().get("name", "敌")) + " 经脉被封", St.col_of("healseal"), 192.0)
			_blog(str(_cur().get("name", "敌")) + " 施『" + anm + "』：经脉被封——这一口只剩三成。", "sys")
		var heal := maxi(1, int(float(_foe_hp_max()) * float(a.get("heal_pct", 0.2)) * fhm))
		_set_foe_hp(mini(_foe_hp_max(), _foe_hp() + heal))
		_set_foe_next_mult(float(a.get("next_mult", 1.0)))
		UiKit.float_text(self, "吐纳回气 · 气血 +" + str(heal), UiKit.GREEN, 192.0)
	elif kind == "charge":
		_set_foe_next_mult(float(a.get("mult", 1.5)))
		UiKit.float_text(self, "蓄势 · 下一手更重", UiKit.SEAL, 192.0)
	else:
		var hits := 2 if kind == "dash" else 1
		var total := 0
		for hi in hits:
			var mult_i := float(a.get("mult", 1.5)) if hi == 0 else float(a.get("follow", 0.7))
			var rr := _foe_art_dmg(mult_i)
			total += int(rr["dmg"])
			# v35：闪掉（dmg 0）＝这一手整个落空，不再摆挨打演出
			if int(rr["dmg"]) > 0:
				_foe_show_hit(int(rr["dmg"]), bool(rr["guard"]), int(rr.get("raw", 0)))
			if _hp <= 0:
				break
			if hi + 1 < hits:
				await _wait(0.16)
		# v52：怪招自带的状态（第 50 关往后首领的焚身掌/锁脉手/封穴指那一路）
		if _hp > 0:
			_st_hit(_a(), a.get("apply", {}), str(_a().get("name", "我")))
		print("[游历战斗] ", _foe_name(), " 施『", anm, "』：", total)
	var rt: Tween = _foe.push_move_to(_e_base, 0.18, Tween.TRANS_QUAD, Tween.EASE_IN)   # ㊿x：退回来同样排队
	await rt.finished
	await _wait(0.08)
	_update_bars()

func _foe_ult_strike() -> void:
	if _foe == null or not is_instance_valid(_foe):
		return
	var un := str(_foe_ult().get("name", "大招"))
	_cur_move = "大招『" + un + "』"   # v36：战报
	_banner("『" + un + "』", UiKit.SEAL)
	if _fx != null:
		_fx.flash(Color(1, 1, 1, 0.25))
	var tw: Tween = _foe.push_move_to(_e_base + Vector2(-112.0, 0.0), 0.18)   # ㊿x：位移排队
	await tw.finished
	if not is_instance_valid(_foe):
		return
	var rr := _foe_art_dmg(float(_foe_ult().get("mult", 2.2)))
	if int(rr["dmg"]) > 0:
		_foe_show_hit(int(rr["dmg"]), bool(rr["guard"]), int(rr.get("raw", 0)))
	# v52：大招自带的状态（横扫型的就挂给被打的那个；单体大招同理）
	if _hp > 0:
		_st_hit(_a(), _foe_ult().get("apply", {}), str(_a().get("name", "我")))
	_update_bars()
	print("[游历战斗] ", _foe_name(), " 放大招『", un, "』：", rr["dmg"])
	var rt: Tween = _foe.push_move_to(_e_base, 0.2, Tween.TRANS_QUAD, Tween.EASE_IN)
	await rt.finished
	await _wait(0.10)

# ㊿：加持目标 → 我方下标数组。站位＝名册顺序：0 前、1 中、末位 后（两场战斗同一条规矩）。
#   单人时"前排/后排"都是他本人——一人一趟也照样能用这几门。
# ㊿z3："self" = 施放者本人——出手前代码已经 use_member(他) 切过去了，
#   所以这里读 active_i 就是他（专属功法走这条）。
func _bless_targets(t: String) -> Array:
	var out: Array = []
	var last := _allies.size() - 1
	if last < 0:
		return out
	match t:
		"self":
			out.append(clampi(int(_state.active_i), 0, last))
		"ally_front":
			out.append(0)
		"ally_back":
			out.append(last)
		"ally_mid":
			out.append(1 if last >= 2 else 0)
		_:
			for i in _allies.size():
				out.append(i)
	return out

# ㊿：施加持——写进每个人的状态格；同一人身上只挂一条（新的顶掉旧的）。
func _cast_bless(art: Dictionary) -> void:
	var ids := _bless_targets(str(art.get("target", "ally_all")))
	if ids.is_empty():
		return
	var turns := int(art.get("turns", 3))
	var cut := float(art.get("cut", 0.0))
	var atk := float(art.get("atk_pct", 0.0))
	var cr := float(art.get("crit_add", 0.0))
	var rg := float(art.get("regen_pct", 0.0))
	var sp := float(art.get("spd_pct", 0.0))
	var ra := float(art.get("rage_pct", 0.0))
	var who: Array = []
	for i_v in ids:
		var i := int(i_v)
		if i < 0 or i >= _allies.size():
			continue
		var al: Dictionary = _allies[i]
		if int(al.get("hp", 0)) <= 0:
			continue
		al["bless_turns"] = turns
		# ============================================================
		# v52 修正：**加持减伤以前算反了**。表里那个 `cut` 是"伤害系数"
		#   （0.85＝受击时只挨 85%，也就是减伤 15%，与 kind:"guard" 同一个口径），
		#   可这里原样存进 bless_cut，而消费者是 `dmg × (1 − bless_cut)`——
		#   于是 0.85 变成"减 85%"。实测：坚壁旗令 1000→150（应 850）·
		#   铁壁合围 1000→200（应 800）· 同心结阵 1000→90（应 910）。
		#   修法选在**源头转换**（存进去的就存"减伤比例" `1 − cut`）：
		#   消费者一个字不用动，与专武·铁壁桩功的 ex_ult_cut 取 max 也从此同口径，
		#   `_bless_mark` 印出来的自然就对。出村 `_bless_apply` 同步改过。
		# ============================================================
		al["bless_cut"] = clampf(1.0 - cut, 0.0, 0.95) if cut > 0.0 else 0.0
		al["bless_atk"] = atk
		al["bless_crit"] = cr
		al["bless_regen"] = rg
		al["bless_spd"] = sp
		al["bless_rage"] = ra
		al["bless_skip"] = true      # 放这一手不算在"目标自己的手"里
		who.append(str(al.get("name", "")))
		var an = _ally_nodes[i] if i < _ally_nodes.size() else null
		if _fx != null and an != null and is_instance_valid(an):
			_fx.burst(an.global_position + Vector2(0.0, -95.0), "heal")
	if who.is_empty():
		return
	var what: Array = []
	if atk > 0.0:
		what.append("伤害 +" + str(int(round(atk * 100.0))) + "%")
	if cut > 0.0:
		# v52：文案跟着改成"减伤比例"（以前印的是 cut 本身＝85%，跟描述打架）
		what.append("减伤 " + str(int(round((1.0 - cut) * 100.0))) + "%")
	if cr > 0.0:
		what.append("暴击 +" + str(int(round(cr))))
	if rg > 0.0:
		what.append("每手回 " + str(int(round(rg * 100.0))) + "%")
	if sp > 0.0:
		what.append("速度 +" + str(int(round(sp * 100.0))) + "%")
	if ra > 0.0:
		what.append("怒气 +" + str(int(round(ra * 100.0))) + "%")
	UiKit.float_text(self, "『" + str(art.get("move", "加持")) + "』" + "、".join(PackedStringArray(who)) + "：" + "、".join(PackedStringArray(what)) + "（" + str(turns) + " 手）", UiKit.BLUE, 192.0)
	_update_bars()

# ㊿：加持按"目标自己的手"计数——他出完一手就减 1，减到 0 就散。
#   由出手循环在 await _strike() 之后按**明确的下标**调用（不能靠 _a()：
#   群攻/挨打都会把聚焦挪到别人身上）。
func _tick_bless(i: int) -> void:
	if i < 0 or i >= _allies.size():
		return
	var al: Dictionary = _allies[i]
	if int(al.get("bless_turns", 0)) <= 0:
		return
	if bool(al.get("bless_skip", false)):
		al["bless_skip"] = false      # 施放那一手不计
		return
	al["bless_turns"] = int(al["bless_turns"]) - 1
	if int(al["bless_turns"]) <= 0:
		al["bless_cut"] = 0.0
		al["bless_atk"] = 0.0
		al["bless_crit"] = 0.0
		al["bless_regen"] = 0.0
		al["bless_spd"] = 0.0
		al["bless_rage"] = 0.0
		UiKit.float_text(self, "「" + str(al.get("name", "")) + "」的加持散了", UiKit.DIM, 192.0)
	_update_bars()

# ㊿：名册里那几个人此刻的加持标记（气血条那行字用）
func _bless_mark(m: Dictionary) -> String:
	if int(m.get("bless_turns", 0)) <= 0:
		return ""
	var seg: Array = []
	if float(m.get("bless_atk", 0.0)) > 0.0:
		seg.append("锐")
	if float(m.get("bless_cut", 0.0)) > 0.0:
		seg.append("坚")
	if float(m.get("bless_crit", 0.0)) > 0.0:
		seg.append("准")
	if float(m.get("bless_regen", 0.0)) > 0.0:
		seg.append("春")
	if float(m.get("bless_spd", 0.0)) > 0.0:
		seg.append("风")
	if float(m.get("bless_rage", 0.0)) > 0.0:
		seg.append("气")
	if seg.is_empty():
		return ""
	return "〔" + "".join(PackedStringArray(seg)) + str(int(m["bless_turns"])) + "〕"

func _show_info() -> void:
	if _info_open:
		return
	_info_open = true
	var vp := get_viewport_rect().size
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.42)
	veil.size = vp
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(_on_info_blank)
	veil.z_index = 120   # v71f：压在演员之上（双保险）
	add_child(veil)
	_info_veil = veil
	var panel := UiKit.make_paper_panel(veil, Rect2((vp.x - 560.0) * 0.5, 290.0, 560, 680))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var tt := UiKit.make_label(panel, Vector2(0, 18), Vector2(560, 40), 26, UiKit.INK)
	UiKit.set_text(tt, "敌情 · " + _foe_name())
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l0 := UiKit.make_label(panel, Vector2(34, 70), Vector2(492, 30), 16, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.75))
	# v47：单人关没有"前后排"可写——改写它的体型（肉盾/寻常/高伤）
	var pos_txt2 := str(_cur().get("solo_cn", ""))
	if pos_txt2 == "":
		pos_txt2 = GameData.foe_row_cn(int(_cur().get("row", _focus)))
	UiKit.set_text(l0, "气血 " + str(_foe_hp()) + " / " + str(_foe_hp_max()) + "　·　攻 " + str(_foe_atk())
		+ "　·　" + pos_txt2 + "　·　速度 " + str(_foe_spd()))
	var y := 104.0
	# v46：整组站位一览——谁在前排挡刀、谁在后排打得疼（▶ ＝ 现在盯着的这只）
	if _foes.size() > 1:
		var seg2: Array = []
		for i4 in _foes.size():
			var f4: Dictionary = _foes[i4]
			seg2.append(("▶ " if i4 == _focus else "　 ") + GameData.foe_row_cn(i4) + " " + str(f4.get("name", "敌"))
				+ "　气 " + str(f4.get("hp", 0)) + "/" + str(f4.get("hp_max", 0)) + " · 攻 " + str(f4.get("atk", 0)))
		var lr := UiKit.make_label(panel, Vector2(34, y - 6.0), Vector2(492, 88), 14, Color(0.24, 0.34, 0.52))
		UiKit.set_text(lr, "站位（前排挡刀 · 后排打得疼，普攻只打最前排）：\n" + "\n".join(PackedStringArray(seg2)))
		lr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		y += 92.0
	if not _foe_affixes().is_empty():
		var seg: Array = []
		for af in _foe_affixes():
			seg.append("「" + Affixes.name_of(str(af)) + "」" + str(Affixes.of(str(af)).get("desc", "")))
		var la := UiKit.make_label(panel, Vector2(34, y), Vector2(492, 96), 15, Color(0.62, 0.30, 0.26))
		UiKit.set_text(la, "词缀：" + "\n".join(PackedStringArray(seg)))
		la.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		y += 104.0
	if _foe_arts().is_empty() and _foe_ult().is_empty():
		var ln := UiKit.make_label(panel, Vector2(34, y), Vector2(492, 60), 17, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
		UiKit.set_text(ln, "没有成名招数——出手全凭蛮力。\n（正式游历的精英会带招）")
		ln.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for a_v in _foe_arts():
		var a: Dictionary = a_v
		var l1 := UiKit.make_label(panel, Vector2(34, y), Vector2(492, 84), 16, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))
		UiKit.set_text(l1, "「" + str(a.get("name", "?")) + "」　每 " + str(int(a.get("cd", 3))) + " 手一转\n　" + str(a.get("desc", "")))
		l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		y += 92.0
	if not _foe_ult().is_empty():
		var lu := UiKit.make_label(panel, Vector2(34, y), Vector2(492, 84), 17, UiKit.SEAL)
		UiKit.set_text(lu, "大招「" + str(_foe_ult().get("name", "?")) + "」　怒气满自动放\n　" + str(_foe_ult().get("desc", "")))
		lu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cb := UiKit.make_button(panel, Vector2(210, 606), Vector2(140, 52), "知道了", 20)
	cb.pressed.connect(_close_info)

func _foe_row_of(i: int) -> int:
	if i < 0 or i >= _foes.size():
		return i
	return int((_foes[i] as Dictionary).get("row", i))

func _on_info_blank(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_close_info()

func _close_info() -> void:
	if _info_veil != null and is_instance_valid(_info_veil):
		_info_veil.queue_free()
	_info_veil = null
	_info_open = false

func _strike(is_player: bool, pre_pick: Dictionary = {}) -> void:
	while _info_open:
		await get_tree().process_frame   # v6：看敌情时不走回合
	if _foe_nodes.is_empty():
		return
	# ㊷：我方出手时先按招式作用范围挑目标（前排挡刀 / mid / back）
	#   单人时这一定挑到 0 号，跟以前一样。
	if is_player:
		_focus_on(_front_foe() if _front_foe() >= 0 else 0)
	else:
		# ㊿：敌人普攻打谁——只够到最前排还站着的那个（站位规则）。
		#   带 target:mid/back 的**招式**在下面各自的分支里重新点名（见 _foe_art_strike /
		#   _foe_ult_strike 两处 _pick_ally_target）；单人时无论如何都只会挑到 0 号。
		#   ⚠ "破前/偷袭/截后"三条词缀在这里生效：带它们的怪**普攻也能越过前排**——
		#     与出村战斗的 _foe_reach() 同一口径，并且要 bypass 那道挡刀闸。
		#     不加这条的话，破前在游历里是张空词缀（deep 池 d>=7 会抽到它）。
		var ta := _pick_ally_target(_foe_reach(), _foe_pierce_shield())
		if ta < 0:
			return
		_p_focus_on(ta)
	var atk: Node2D = _player if is_player else _foe
	var dfd: Node2D = _foe if is_player else _player
	if atk == null or dfd == null or not is_instance_valid(atk) or not is_instance_valid(dfd):
		return
	var dir := 1.0 if is_player else -1.0
	var home: Vector2 = _p_base if is_player else _e_base
	var dfd_home: Vector2 = _e_base if is_player else _p_base

	if not is_player and _skip_enemy:
		_skip_enemy = false
		if _fx != null:
			_fx.number("落空", _foe, Color(0.45, 0.45, 0.52))
		await _wait(0.30)
		return

	# ============================================================
	# v52：负面状态——怪这一手开头。**先看"震慑"再结算**（顺序不能反）
	# ============================================================
	if not is_player:
		var f_skip := St.skips(_cur())
		var f_who := str(_cur().get("name", "敌"))
		if _st_tick(_cur(), _foe_hp_max(), f_who, false):
			await _foe_bomb_if_dead()
			return
		if f_skip:
			UiKit.float_text(self, f_who + " 被震慑", St.col_of("stun"), 192.0)
			_blog(f_who + " 被震慑——这一手整个没使出来。", "sys")
			await _wait(0.30)
			return

	# v7：词缀——回春 / 淬毒（敌中毒）/ 鼓舞
	if not is_player:
		_set_foe_acts(_foe_acts() + (1))
		# v10（用户："回春词缀改为 10%恢复 两手恢复一次"）：与出村战斗同一口径——
		#   每两手回一次（上面刚把 _foe_acts 加过 1，所以落在第 2、4、6…手）
		if _foe_affixes().has("regen") and _foe_hp() > 0 and _foe_hp() < _foe_hp_max() 				and _foe_acts() % Affixes.REGEN_EVERY() == 0:
			# v53：回春也吃「封脉」（只剩三成）
			var rh := maxi(1, int(round(float(_foe_hp_max()) * Affixes.REGEN_PCT() * St.heal_mul(_cur()))))
			_set_foe_hp(mini(_foe_hp_max(), _foe_hp() + rh))
			UiKit.float_text(self, "回春 +" + str(rh), UiKit.GREEN, 192.0)
			_blog(str(_cur().get("name", "敌")) + " 回春 +" + str(rh), "heal")   # v36：战报
		if _foe_poison_n() > 0:
			var fd0 := maxi(1, int(round(float(_foe_hp_max()) * Affixes.POISON_PCT() * float(_foe_poison_n()))))
			_set_foe_hp(maxi(0, _foe_hp() - fd0))
			UiKit.float_text(self, "毒发 -" + str(fd0) + "（" + str(_foe_poison_n()) + " 层）", Color(0.42, 0.62, 0.30), 192.0)
			_blog(str(_cur().get("name", "敌")) + " 毒发 −" + str(fd0) + "（" + str(_foe_poison_n()) + " 层）", "deal")   # v36：战报
			_update_bars()
			if _foe_hp() <= 0:
				await _foe_bomb_if_dead()
				return
		if _foe_affixes().has("rally"):
			_set_foe_stack(minf(Affixes.RALLY_CAP(), _foe_stack() + Affixes.RALLY_STEP()))
	# v6：精英带招——怒气满放大招；技能按冷却轮转；都没有＝寻常出手
	if not is_player and (not _foe_arts().is_empty() or not _foe_ult().is_empty()):
		_set_foe_rage(_foe_rage() + (int(round(DUEL_RAGE_GAIN * DUEL_RAGE_MUL))))
		if _foe_rage() >= 100 and not _foe_ult().is_empty():
			_set_foe_rage(0)
			# ㊿：大招点名——写了 target:mid/back 的能越过前排（游历精英的大招就是 mid）
			_focus_foe_target_on_ally(_foe_ult())
			await _foe_ult_strike()
			_mark_hit_if_hurt()   # ㊿：轻身卡
			return
		if not _foe_arts().is_empty():
			if _foe_art_cd() > 0:
				_set_foe_art_cd(_foe_art_cd() - (1))
			if _foe_art_cd() <= 0:
				var ai := _foe_art_i() % _foe_arts().size()
				_set_foe_art_i(_foe_art_i() + (1))
				var mv1: Dictionary = _foe_arts()[ai]
				# ㊿：招式点名——同上
				_focus_foe_target_on_ally(mv1)
				await _foe_art_strike(mv1)
				_mark_hit_if_hurt()   # ㊿：轻身卡
				return

	# v7：我方每手——电麻/毒发/怒气/生生卡/枪势回气/养晦窗/大招
	if is_player and _skip_next:
		_skip_next = false
		if _fx != null:
			_fx.number("手麻", _player, Color(0.45, 0.55, 0.85))
		UiKit.float_text(self, "电盾余麻——这一手落空", UiKit.BLUE, 192.0)
		await _wait(0.30)
		return
	# v52：负面状态——我方这一手开头（同上：先看震慑，再结算）
	if is_player:
		var p_skip := St.skips(_a())
		var p_who := str(_a().get("name", "我"))
		if _st_tick(_a(), _my_hp_max, p_who, true):
			return
		if p_skip:
			UiKit.float_text(self, p_who + " 被震慑", St.col_of("stun"), 192.0)
			_blog(p_who + " 被震慑——这一手整个没使出来。", "sys")
			await _wait(0.30)
			return
	if is_player and _p_poison > 0:
		var pd := maxi(1, int(round(float(_my_hp_max) * Affixes.POISON_PCT() * float(_p_poison))))
		_hp = maxi(0, _hp - pd)
		UiKit.float_text(self, "毒发 -" + str(pd) + "（" + str(_p_poison) + " 层）", Color(0.42, 0.62, 0.30), 192.0)
		_blog(str(_a().get("name", "我")) + " 毒发 −" + str(pd) + "（" + str(_p_poison) + " 层）", "hit")   # v36：战报
		_update_bars()
		if _hp <= 0:
			return
	if is_player:
		# ㊹：以前这里写死 34.0（跟 DUEL_RAGE_GAIN 的默认值重复），现在统一走系数
		_rage += int(round(float(DUEL_RAGE_GAIN) * DUEL_RAGE_MUL * _rage_mul * (1.0 + float(_a().get("bless_rage", 0.0)))
			* St.rage_mul(_a())))   # v53：挫锐——怒气只剩四成
		_hand_n += 1
		# ============================================================
		# v53：「封脉」——回血只剩三成（v52 时是"100% 回不上来"，用户改成 60~80%，取 70%）。
		#   下面四口（加持回春 / 手数回气 / 枪势回气 / 养晦窗）乘同一个倍率。
		# ============================================================
		var st_hm := St.heal_mul(_a())
		if st_hm < 1.0:
			UiKit.float_text(self, "经脉被封 · 回气只剩三成", St.col_of("healseal"), 192.0)
			_blog(str(_a().get("name", "我")) + " 经脉被封——这一手的回气只剩三成。", "sys")
		# ㊿：加持回春（回春令）——每手开头先回一口，能救命的那种顺序
		var brg := float(_a().get("bless_regen", 0.0))
		if brg > 0.0 and _hp > 0:
			var bh := maxi(1, int(round(float(_my_hp_max) * brg * st_hm * _heal_mul())))
			_hp = mini(_my_hp_max, _hp + bh)
			UiKit.float_text(self, "回春 +" + str(bh), UiKit.GREEN, 192.0)
			_update_bars()
		var hh2 := float(_fx_buff.get("hand_heal", 0.0))
		# v62o：间隔可配（`hand_heal_every`）——续命签改成"每 2 手回 8%"，
		#   生生卡/踏浪卡那种"每 3 手"照旧（不写这个键就是 3）。
		var hh_every := maxi(1, int(_fx_buff.get("hand_heal_every", 3)))
		if hh2 > 0.0 and _hand_n % hh_every == 0:
			var hh3 := maxi(1, int(round(float(_my_hp_max) * hh2 * st_hm * _heal_mul())))
			_hp = mini(_my_hp_max, _hp + hh3)
			# ㊿：这句原写"生生卡回气"——现在 hand_heal 这条键不止生生卡在用
			#   （踏浪卡 6%、续命签 4%），所以只报数、不报卡名。
			UiKit.float_text(self, "回气 +" + str(hh3), UiKit.GREEN, 192.0)
			_update_bars()
		if _ult_turns > 0 and _ult_regen_pct > 0.0:
			var uh := maxi(1, int(round(float(_my_hp_max) * _ult_regen_pct * st_hm * _heal_mul())))
			_hp = mini(_my_hp_max, _hp + uh)
			UiKit.float_text(self, "枪势回气 +" + str(uh), UiKit.GREEN, 192.0)
			_update_bars()
		var wr2 := float(_fx_buff.get("ult_window_regen", 0.0))   # ㉙：养晦卡
		if _window_left > 0 and wr2 > 0.0:
			_window_left -= 1
			var wr3 := maxi(1, int(round(float(_my_hp_max) * wr2 * st_hm * _heal_mul())))
			_hp = mini(_my_hp_max, _hp + wr3)
			UiKit.float_text(self, "养晦回气 +" + str(wr3), UiKit.GREEN, 192.0)
			_update_bars()
		if _ult_new:
			_ult_new = false
		elif _ult_turns > 0:
			_ult_turns -= 1
			if _ult_turns <= 0 and wr2 > 0.0:
				_window_left = 3
		# ㊿：大招**不再在这里抢着放**——它现在是牌面上的一张（自动模式由
		#   _choose_action 按"大招＞武学＞普攻"挑，手动模式等玩家划）。
		#   这样自动模式也能看到大招那张亮一下。
	# ㊿：这一手用什么——
	#   · 手动：玩家在手牌上点的那张，由出手循环挑好人+动作后传进来（pre_pick）
	#   · 自动：在这里按"大招＞武学＞普攻"挑，并亮一下那张牌
	#   ⚠ 武学冷却是**每轮开头统一走**的（见出手循环的 _tick_arts_all），
	#     这里不能再 tick——否则手动那条路会走两遍，牌面和真出的那一手又对不上了。
	var pick := {"k": "normal", "sid": ""}   # 敌方不用它
	if is_player:
		if pre_pick.is_empty():
			pick = await _choose_action()      # 自动那条路（会摊牌亮一下）
		else:
			pick = pre_pick                    # 玩家点的（手牌已经收掉了）
		# ㊿：记下"这一手真出的是什么"——出手循环随后按它记台账
		_last_ai = _p_focus
		_last_k = str(pick.get("k", "normal"))
		_last_sid = str(pick.get("sid", ""))
		# ㊿z7：专武·长风诀的"大招连发窗口"按**本人这一手**递减（每次行动算一回合）
		var cl7 := int(_a().get("ult_chain_left", 0))
		if cl7 > 0:
			_a()["ult_chain_left"] = cl7 - 1
		if str(pick.get("k", "normal")) == "ult" and St.blocks_ult(_a()):
			# v53：封招压着——手牌那边已经不摊大招牌了，这里再兜一道
			#   （手动模式摊牌那一刻到点下去之间可能刚被人上了状态）
			_blog(str(_a().get("name", "我")) + " 大招被封——这一手放不出来，怒气留着。", "sys")
			UiKit.float_text(self, "封招 · 这一手放不出大招", St.col_of("ultseal"), 192.0)
			pick = {"k": "normal", "sid": ""}
		if str(pick.get("k", "normal")) == "art" and St.blocks_arts(_a()):
			_blog(str(_a().get("name", "我")) + " 穴道被点——这一手放不出武学。", "sys")
			UiKit.float_text(self, "沉默 · 这一手放不出武学", St.col_of("silence"), 192.0)
			pick = {"k": "normal", "sid": ""}
		if str(pick.get("k", "normal")) == "ult":
			_rage = 0
			_ult_cutin(_a())      # v64：大招演出片（非阻塞；没片子/关了开关就什么都不做）
			await _player_ult()
			return
	var mv := _pick_move(is_player)
	var art: Dictionary = {}
	var banner_txt := ""
	if is_player:
		# 用哪张武学**只由 pick 决定**（不再是"自动再挑一次"）：
		#   手动＝玩家划的那张；自动＝_choose_action 挑的那张。
		#   pk 是 "normal"、或那张武学已经不在了 → art 留空，这一手就是普攻。
		if str(pick.get("k", "normal")) == "art":
			art = _art_by_sid(str(pick.get("sid", "")))
		if not art.is_empty():
			var an := str(art.get("_name", "武学"))
			var am := str(art.get("move", ""))
			banner_txt = "『" + an + "』" + am
			# ㊿：冰心卡的冷却减免**封顶**（ART_CD_MINUS_CAP），且冷却保底 1 ——
			#   两张冰心卡叠起来也不会把冷却压到 0（0 冷却＝无限放，直接穿帮）。
			var cd_cut := clampi(int(_fx_buff.get("art_cd_minus", 0.0)), 0, ART_CD_MINUS_CAP)
			# v53：「滞涩」——这一手放完的冷却 +2 手（状态压着谁，谁的技能就慢）
			_state.set_art_cd(str(art.get("_sid", "")), maxi(1, int(art.get("cd", 3)) - cd_cut) + St.cd_add(_a()))
			_update_bars()
	var kind := str(art.get("kind", ""))
	# v36：战报用的"这一手叫什么"——_foe_take / _foe_show_hit 记账时读它
	_cur_move = banner_txt if banner_txt != "" else ("普攻" if is_player else "反手")
	_cur_crit = false
	# v58：这一手算什么属性（见 _atk_elem）——摆好之后 _roll_p_damage / _foe_take 都读它。
	#   敌人的出手写另一格（_foe_cur_elem），免得反伤被当成元素伤害。
	var ae := _atk_elem(art, is_player)
	if is_player:
		_cur_elem = ae
	else:
		_foe_cur_elem = ae

	# v52：「缴械」——这一手若是**普攻**（手上没带武学/大招），就递不出去，只能格挡。
	#   武学、大招、护体、回气都不受影响（设计原话："不能普攻，武学与大招照放"）。
	if is_player and art.is_empty() and St.blocks_plain(_a()):
		if _fx != null:
			_fx.number("缴械", _player, St.col_of("disarm"))
		UiKit.float_text(self, str(_a().get("name", "我")) + " 兵器被打落——这一手只能格挡", St.col_of("disarm"), 192.0)
		_blog(str(_a().get("name", "我")) + " 兵器被打落——这一手只能格挡。", "sys")
		await _wait(0.40)
		return

	# 护体 / 疗伤 / 加持 / 驱散：原地起手，不出击
	# v53：`kind: "cleanse"`（清心诀）也归这一支——它同样不伤人
	if kind == "guard" or kind == "heal" or kind == "bless" or kind == "cleanse":
		_banner(banner_txt, UiKit.SEAL)
		if _fx != null:
			_fx.flash(Color(1, 1, 1, 0.12))
		if kind == "cleanse":
			_cleanse_apply(art)
			await _wait(0.55)
			return
		if kind == "guard":
			_guard_left = int(art.get("turns", 3))
			_guard_cut = float(art.get("cut", 0.8))
			var cut_pct := int(round((1.0 - _guard_cut) * 100.0))
			UiKit.float_text(self, "气凝周身 · 下 " + str(_guard_left) + " 次受击减伤 " + str(cut_pct) + "%", UiKit.BLUE, 192.0)
			_blog(str(_a().get("name", "我")) + " " + banner_txt + "：下 " + str(_guard_left) + " 次受击减伤 " + str(cut_pct) + "%", "dodge")   # v36：战报
		elif kind == "heal":
			# v53：「封脉」在身——武学照放，药气只剩三成
			var hm := St.heal_mul(_a())
			if hm <= 0.0:
				UiKit.float_text(self, "经脉被封——这一口回不上来", St.col_of("healseal"), 192.0)
				_blog(str(_a().get("name", "我")) + " " + banner_txt + "：经脉被封，这一口回不上来。", "sys")
				await _wait(0.45)
				return
			# ⚠ 「寄生」的回血加成已经并进 St.heal_mul()（一处落地），这里别再乘一遍
			var heal := maxi(1, int(float(_my_hp_max) * float(art.get("heal_pct", 0.25)) * hm * _art_fit(art) * _heal_mul()))
			var before_hp := _hp
			_hp = mini(_my_hp_max, _hp + heal)
			# v58：「寄生」——把**实际回进去的血**记一笔，"吸血藤"按它算木伤
			St.heal_note(_a(), _hp - before_hp)
			_next_mult = float(art.get("next_mult", 1.0))
			_update_bars()
			UiKit.float_text(self, "吐纳归元 · 气血 +" + str(heal), UiKit.GREEN, 192.0)
			_blog(str(_a().get("name", "我")) + " " + banner_txt + "：气血 +" + str(heal), "heal")   # v36：战报
		else:
			# ㊿：加持——按 target 挑自己人，给每个人挂"持续 N 手"的状态
			_cast_bless(art)
		await _wait(0.55)
		return

	# ㊿x：冲上去/退回来都走 StickFighter 的位移队列——同一个人的 position
	#   只排一条补间。否则"挨打抖动"跟"冲上去"会同时往 position 上写，
	#   每帧互相覆盖，画面上就是抽搐（多人对打时最容易撞上）。
	#
	# v57（用户："可以 你继续"）：**普攻接上招式表**——原来这一下只有"滑 92 像素 / 0.15 秒"，
	#   六种兵器、二十来招长得一模一样，而招式表（`move_db`）与冲步档案（`MOVE_PROFILE`）
	#   一直没人调（`play_move()` 全项目零调用）。现在：
	#     ① 播招式姿势：起手 → 出招（各自的弹簧软硬）→ 收招（`_finish_move` 自动接）
	#     ② 起手时长**取自招式表第 1 步**（不是另写一个数）——表和等待严格同源，改表就跟着改
	#     ③ 冲步距离/下沉/击退取 `MOVE_PROFILE`：枪刺 245 像素、拳 170、暗器 150、匕 255，
	#        不像原来六种兵器一律 92
	#   `MOVE_SPEED` 是整体倍速：招式表是按"单看一招"排的（起手 0.10~0.55、全程 0.7~1.4 秒），
	#   放进连续出手里要快一档。调大＝更快（更接近旧观感），设 `MOVE_ANIM = false` 就整条退回旧样子。
	var pr: Dictionary = GameData.MOVE_PROFILE.get(mv, {}) if MOVE_ANIM else {}
	var lunge_dist := 92.0
	var lunge_y := 0.0
	var lunge_time := 0.15
	var push_k := 1.0
	if MOVE_ANIM:
		lunge_dist = float(pr.get("dist", 92.0))
		lunge_y = float(pr.get("y", 0.0))
		lunge_time = float(pr.get("time", 0.15)) / _move_spd()
		push_k = float(pr.get("push", 1.0))
		var mt: Dictionary = atk.move_time(mv, _move_spd())
		atk.play_move(mv, _move_spd())
		# 起手：招式表第 1 步的定格——姿势与等待同源，所以永远不会"姿势还没抬手，伤害已经出了"
		await get_tree().create_timer(float(mt.get("windup", 0.15))).timeout
		if not (is_instance_valid(atk) and is_instance_valid(dfd)):
			return
	var tw: Tween = atk.push_move_to(home + Vector2(lunge_dist * dir, lunge_y), lunge_time)
	await tw.finished
	if not (is_instance_valid(atk) and is_instance_valid(dfd)):
		return

	var slashed_node: Node = dfd
	if _fx != null:
		_fx.slash_between(atk, dfd, mv)
		if art.is_empty():
			_fx.move_word(mv)
	if banner_txt != "":
		_banner(banner_txt, UiKit.SEAL)
		# v66：武学出手加一档轻震 + 白闪（跟大招的墨红重震区分开）
		if _fx != null:
			_fx.shake(5.0, 0.22)
			_fx.flash(Color(1, 1, 1, 0.18))

	var dmg := 0
	var crit := false
	if is_player:
		# ㊷：先按招式的作用范围挑目标（普攻＝最前排；mid/back 越前排；sweep 打全部）
		var tgt := _pick_player_target(art)
		if tgt < 0:
			return
		_focus_on(tgt)
		dfd = _foe
		if not (dfd != null and is_instance_valid(dfd)):
			return
		# v92：目标没换就**不再补第二道**——原来这里不看目标是否相同，
		#   普攻最常见的情况就是"同一对人放两遍刀光"，叠在一起看着就是乱。
		if _fx != null and dfd != slashed_node:
			_fx.slash_between(atk, dfd, mv)
		var is_sweep := (not art.is_empty()) and str(art.get("target", "front")) == "sweep"
		var mult := 1.0
		if not art.is_empty():
			# v62f：倍率吃星级（与村里战斗同一口 GameState.art_mult）
			var asid := str(art.get("_sid", ""))
			mult = GameState.art_mult(asid, float(art.get("mult", 1.0)))
			# v58（用户第 6 条）：**元素不合时倍率降低**——武学表里写了元素的，
			#   拿手里那把兵器的元素去比；不合（或手里没元素）就 ×0.70。
			#   与下面那条"不趁手"（off_mult）是两回事，两条可以同时打折。
			var fit_e := _art_fit(art)
			if fit_e < 1.0:
				mult *= fit_e
				UiKit.float_text(self, "元素不合 · 这门武学使不出全劲", Elem.col(str(art.get("elem", ""))), 176.0)
			var wreq := str(Cards.weapon_of(str(art.get("_sid", ""))))
			var fit: bool = wreq == "any" or wreq == _state.weapon()
			# ㊿z：角色星·少侠「武学宗师」——无视武学的兵器要求，不趁手也按原本倍率打
			if not fit and float(_fx_buff.get("art_any_weapon", 0.0)) > 0.0:
				fit = true
				UiKit.float_text(self, "武学宗师 · 兵刃虽不趁手，招式照旧", UiKit.GOLD, 192.0)
			if not fit:
				mult = GameState.art_mult(asid, float(art.get("off_mult", mult)))
				UiKit.float_text(self, "兵器不趁手，只使出三分火候", UiKit.SEAL, 192.0)
		# v48：**多段武学**（art["hits"] ＝ 2~3 段，每段倍率写得很低）——
		#   每一段**各自掷暴击、各自过一次结算**（防御/护体/反伤各算一次），
		#   每一段暴击都追剑（与"只要暴击就追"同一条规矩）。段数上限 3。
		#   ⚠ 这一段必须**排在第一掷之前**：不然那一次掷点白掷，还会先把"蓄势"吃掉。
		var seg_n := clampi(int(art.get("hits", 1)), 1, 3)
		if (not is_sweep) and seg_n >= 2:
			var seg_total := 0
			var crit_n := 0
			for k2 in seg_n:
				if _foe_hp() <= 0:
					break
				var rk := _roll_p_damage(mult)
				_cur_crit = bool(rk["crit"])
				if bool(rk["crit"]):
					crit_n += 1
				seg_total += _foe_take(int(rk["dmg"]))
				# v52：多段武学也认 apply（表里现在没有这种，留着口径一致）
				_st_art_foe(art)
				_ex_thorn_gain()
				if _fx != null and is_instance_valid(_foe):
					_fx.burst(_foe.global_position + Vector2(0.0, -95.0), "cut")
					_num_foe(int(rk["dmg"]))
				_foe.play_hit()
				_update_bars()
				_blog(str(_a().get("name", "我")) + " " + _cur_move + "：" + str(int(rk["dmg"]))
					+ "（第 " + str(k2 + 1) + "/" + str(seg_n) + " 段" + ("·暴击）" if bool(rk["crit"]) else "）"), "deal")
				if bool(rk["crit"]):
					await _song_follow()
				await _wait(0.12)
			dmg = seg_total
			if crit_n > 0:
				crit = true
			# 段数报清楚（说明文字里也写了段数）
			UiKit.float_text(self, str(seg_n) + " 段共 " + str(seg_total)
				+ ("（" + str(crit_n) + " 段暴击）" if crit_n > 0 else ""), UiKit.SEAL, 176.0)
			if kind == "stone":
				_skip_enemy = true
				UiKit.float_text(self, "石到人到，敌人下一手落空", UiKit.BLUE, 192.0)
			_mark_hit_if_hurt()   # ㊿：轻身卡——这一手之后若掉了血（反伤），置"受过击"
			await _extras_after_plain(is_player, art)
			var rt0: Tween = atk.push_move_to(home, 0.18, Tween.TRANS_QUAD, Tween.EASE_IN)
			await rt0.finished
			await _wait(0.08)
			return
		var r := _roll_p_damage(mult)
		crit = bool(r["crit"])
		_cur_crit = crit   # v36：战报里标"暴击"
		if is_sweep:
			# 群伤：每个活着的敌人都挨这一下（打谁先算谁，数字各自结算）
			# ㊿z6：专武·长风诀——对多人时大招**每击中一名对手，那一击再 +10%**（逐个叠）
			var swung := 0
			var k_hit := 0
			var per := float(_fx_buff.get("ult_per_hit", 0.0))
			var base_dmg := int(r["dmg"])
			for i in _foes.size():
				if not _foe_alive(i):
					continue
				_focus_on(i)
				var one := base_dmg
				if per > 0.0 and k_hit > 0:
					one = maxi(1, int(round(float(base_dmg) * (1.0 + per * float(k_hit)))))
				k_hit += 1
				swung += _foe_take(one)
				_ex_thorn_gain()
				# v52：横扫的招式若带 apply——**每一只中招的都挂上**（聚焦已经在它身上了）
				_st_art_foe(art)
			dmg = swung
			if _fx != null:
				_fx.flash(Color(1, 1, 1, 0.18))
		else:
			dmg = _foe_take(int(r["dmg"]))
			_ex_thorn_gain()
			# v52：招式自带的状态（烈焰刀/卸甲手/软筋散…）——伤害已经落地，这里挂状态
			_st_art_foe(art)
			# ㊿z6：专武·长风诀——**对单人**时，放出大招后怒气回 20%
			if _foes_alive() <= 1 and float(_fx_buff.get("ult_back_rage", 0.0)) > 0.0:
				var back := int(round(float(_fx_buff.get("ult_back_rage", 0.0))))
				_rage = mini(100, _rage + back)
				UiKit.float_text(self, "长风回气 +" + str(back), UiKit.GOLD, 192.0)
		if kind == "stone":
			_skip_enemy = true
			UiKit.float_text(self, "石到人到，敌人下一手落空", UiKit.BLUE, 192.0)
	else:
		# v52：「缴械」——怪这一手若是普攻（上面的大招/技能两支都没走），也递不出去
		if St.blocks_plain(_cur()):
			UiKit.float_text(self, str(_cur().get("name", "敌")) + " 兵器被打落", St.col_of("disarm"), 192.0)
			_blog(str(_cur().get("name", "敌")) + " 兵器被打落——这一手没能递上来。", "sys")
			await _wait(0.30)
			return
		var er := _roll_e_damage()
		dmg = int(er["dmg"])
		# v36：战报——敌方这一手（普攻）。闪掉的那种 dmg＝0，_p_mitigate 里已记过"闪避"
		if dmg > 0:
			_log_hit(str(_cur().get("name", "敌")), _cur_move, str(_a().get("name", "我")), dmg, "hit")
		_hp = maxi(0, _hp - dmg)   # v35：dmg 0 ＝ 闪掉了（_p_mitigate 里已浮过"闪避！"）
		var veng2 := minf(float(_fx_buff.get("vengeance", 0.0)), Buffs.VENG_CAP)   # ㉙：回气卡（㊿：封顶 20%）
		if dmg > 0 and veng2 > 0.0:
			_next_mult = maxf(_next_mult, 1.0 + veng2)
		if bool(er["guard"]):
			UiKit.float_text(self, "铁布衫挡下一击（剩 " + str(_guard_left) + " 次）", UiKit.BLUE, 192.0)
		if _foe_affixes().has("poison") and dmg > 0 and _hp > 0:
			_p_poison = mini(Affixes.POISON_MAX(), _p_poison + 1)
			UiKit.float_text(self, "毒刃入体 +1（" + str(_p_poison) + " 层）", Color(0.42, 0.62, 0.30), 192.0)
		# v52/v55：词缀·火魔/铁锁/锁喉/软筋/缠足/裂甲/泄气/滞脉/封穴/点窍（普攻这条路）
		if dmg > 0 and _hp > 0:
			_st_affix_hit(_a(), str(_a().get("name", "我")))
		# ㉙：枪势反刺——按陈石上限 8%~12%；橙字打在敌人身上
		if _ult_turns > 0 and _ult_thorn_on and _foe_hp() > 0:
			var rbb := _thorn_calc(int(er.get("raw", dmg)))
			_set_foe_hp(maxi(0, _foe_hp() - rbb))
			if _fx != null and _foe != null and is_instance_valid(_foe):
				_fx.number("反伤 -" + str(rbb), _foe, C_COUNTER)
			else:
				UiKit.float_text(self, "反伤 -" + str(rbb), C_COUNTER, 192.0)
		if _foe_affixes().has("swift") and dmg > 0 and _foe_acts() % Affixes.SWIFT_EVERY() == 0 and _hp > 0:
			var sd := maxi(1, int(round(float(dmg) * Affixes.SWIFT_PCT())))
			_hp = maxi(0, _hp - sd)
			UiKit.float_text(self, "速攻快招 -" + str(sd), Color(0.62, 0.30, 0.26), 192.0)
		# v55：词缀·回响——每第 2 手追一记四成力（与速攻错开：那条是每第 3 手六成力）
		if _foe_affixes().has("echo") and dmg > 0 and _foe_acts() % Affixes.ECHO_EVERY() == 0 and _hp > 0:
			var ee := _foe_atk_eff() * Affixes.ECHO_PCT() * randf_range(0.9, 1.1)
			var ed := _p_mitigate(maxi(1, int(round(ee))))
			_hp = maxi(0, _hp - ed)
			UiKit.float_text(self, "回响 -" + str(ed), Color(0.62, 0.34, 0.44), 192.0)
			_blog(str(_cur().get("name", "敌")) + " 余势回响：" + str(_a().get("name", "我")) + " 再挨 " + str(ed), "hit")

	# v35：闪掉的那一手（dmg 0）不摆挨打演出——不然屏幕上会飘一个"0"
	if dmg > 0 and _fx != null and is_instance_valid(dfd):
		var hit_pos: Vector2 = atk.global_position.lerp(dfd.global_position, 0.6) + Vector2(0.0, -95.0)
		_fx.burst(hit_pos, mv)
		if is_player:
			_fx.number(str(dmg), dfd, UiKit.SEAL, _cur_elem)
		else:
			_fx.number(str(dmg), dfd, Color(0.72, 0.16, 0.12), _foe_cur_elem)
		if crit:
			_fx.flash(Color(1, 1, 1, 0.12))

	_mark_hit_if_hurt()   # ㊿：轻身卡——这一手之后若掉了血，置"受过击"
	dfd.play_hit()
	dfd.modulate = Color(1.8, 1.8, 1.8, 1)
	var mt := create_tween()
	mt.tween_property(dfd, "modulate", Color.WHITE, 0.2)
	# ㊿x：挨打这一抖也排队——它跟"冲上去/退回来"是同一个 position，两条并行就抽搐
	#   v57：抖多远跟着招式的"击退倍率"走（枪 1.9 / 暗器 1.5 / 匕 0.9）——重兵器把人打得更趔趄
	var kb: float = 12.0 * push_k if MOVE_ANIM else 12.0
	dfd.push_move_to(dfd_home + Vector2(kb * dir, 2.0), 0.07)
	dfd.push_move_to(dfd_home, 0.12)
	_update_bars()

	# v7：淬毒卡——出手命中上毒；剑歌窗口——暴击追剑（引吭卡加段）
	if is_player and float(_fx_buff.get("poison_hit", 0.0)) > 0.0 and _foe_hp() > 0:
		_set_foe_poison_n(mini(Affixes.POISON_MAX(), _foe_poison_n() + 1))
		UiKit.float_text(self, "淬毒 +1（" + str(_foe_poison_n()) + " 层）", Color(0.42, 0.62, 0.30), 192.0)
	if is_player and crit and _ult_turns > 0 and _ult_follow > 0.0 and _foe_hp() > 0:
		await _song_follow()
	if is_player and kind == "dash" and _foe_hp() > 0 and _foe != null and is_instance_valid(_foe):
		await _wait(0.20)
		var fr := _roll_p_damage(float(art.get("follow", 0.7)))
		var fdmg := _foe_take(int(fr["dmg"]))
		_st_art_foe(art)   # v52：连追那一支也认 apply
		if _fx != null and is_instance_valid(_foe):
			_fx.burst(_foe.global_position + Vector2(0.0, -95.0), "cut")
			_num_foe(fdmg)
		_foe.play_hit()
		_update_bars()

	# ㊿：速度 → 攻速。**只有普通攻击**吃这条（武学/大招有自己的冷却与怒气管着）：
	#   快过对手一倍多打一下普攻，最多多打两下。
	await _extras_after_plain(is_player, art)

	var rt: Tween = atk.push_move_to(home, 0.18, Tween.TRANS_QUAD, Tween.EASE_IN)   # ㊿x：退回来同样排队
	await rt.finished
	await _wait(0.08)

# ㊿：普通攻击之后的"额外普攻"（速度压制）。
#   只有真·普攻才算：art 非空（武学那一手）不走这里；大招那一手在别处 return 了。
#   多打的那几下也守着站位规矩——打的是"当前还站着的那一个"。
func _extras_after_plain(is_player: bool, art: Dictionary) -> void:
	if not art.is_empty():
		return
	var my_spd := float(_a().get("spd", 100))
	var op_spd := float(_foe_spd())
	var n := 0
	if is_player:
		if _foe_hp() <= 0:
			return
		n = GameData.extra_attacks(my_spd, op_spd)
	else:
		if _hp <= 0:
			return
		n = GameData.extra_attacks(op_spd, my_spd)
	if n <= 0:
		return
	if is_player:
		UiKit.float_text(self, GameData.atkspd_word(my_spd, op_spd), UiKit.GOLD, 208.0)
	else:
		UiKit.float_text(self, "来敌快出一截——连补 " + str(n) + " 下", UiKit.SEAL, 208.0)
	for k in n:
		if is_player and _foe_hp() <= 0:
			break
		if not is_player and _hp <= 0:
			break
		if _fx != null:
			_fx.flash(Color(1, 1, 1, 0.10))
		if is_player:
			var r := _roll_p_damage(1.0)
			var d2 := _foe_take(int(r["dmg"]))
			if _fx != null and _foe != null and is_instance_valid(_foe):
				_fx.burst(_foe.global_position + Vector2(0.0, -95.0), "cut")
				_num_foe(d2)
				_foe.play_hit()
			_update_bars()
		else:
			var er := _roll_e_damage()
			var d3 := int(er["dmg"])
			_hp = maxi(0, _hp - d3)   # v35：0 ＝ 闪掉（浮字在 _p_mitigate 里给过）
			if d3 > 0 and _fx != null and _player != null and is_instance_valid(_player):
				_num_me(d3, _player)
				_player.play_hit()
			_update_bars()
		await _wait(0.16)
