extends Control
# ============================================================
# battle_lite.gd —— 出村清缴 · 自动战斗 v12（对手清空却卡住：收场总闸）
# v12（用户："爬塔时有时候 对手血量清空了 会卡住不动"）：
#   病根＝**敌人死在"非收尾路径"上时没人收摊**。最典型的是反刺：
#   怪打人 → 被反刺反死（_enemy_act 尾部、_enemy_hit_member 那两段只判"我方死没死"），
#   而 _member_act 又在"没有活着的敌人"时提前 return（want < 0），
#   于是"杀完就收摊"那句永远走不到 → 双方干站着空转（截图里 0/499 那一幕）。
#   改法三处：①_act() 开头放**收场总闸**（敌人清空/我方全灭，无论血是谁扣的都当场收摊）；
#   ②_enemy_death_check 补"敌人清空"分支（怪放完招的收尾那一口）；
#   ③_enemy_act 尾部反刺之后补同一道判定；另把"我方还剩几个"收成 _party_alive()。
#   口径与 _member_act 收尾一致：敌人清完＋我方还有人＝胜；两边同时倒＝败。
# v11（㊿c）：㊿c 补丁误贴的两处重复清掉——①THORN_HP_LO/HI 只留头部那一份
#   （重复定义＝脚本报"已定义"，整场战斗都起不来）；②删多余的 _thorn_reflect()
#   （v10 的 _thorn_calc() 就是同一口径，两处反刺都走它）。
# v10（㉙）：①陈石枪势反刺——不再"敌伤 35%"，改按陈石气血上限的 8%~12% 比例带
#   （THORN_HP_LO/HI；挨得越重比例越高；村战无运签、不吃铁蒺卡）；②反伤/反刺浮字
#   改橙（C_COUNTER）——回复仍是绿（GREEN），两色一眼分开；③枪势起文案随口径更新。
# v9：①怪带词缀（data_affixes）：反伤/速攻/回春/自爆/电盾/狂暴/鼓舞/战意/毒刃全兑现；
#   ②角色被动真生效（怒气/减伤/暴击换血）；③大招三分支（主角一段·陈石枪势·青鸾剑歌）；
#   ④普攻接入暴击。数值初稿——表在 data_affixes 与 game_state。
# v8（优化批㉑：首领带招）
# v8：首领带 1~2 招与 1 大招（表在 game_state.BOSS_ARTS/BOSS_ULTS）：技能按冷却轮放、
#   怒气满放大招；护体类招数会减伤我方输出（全部伤害走 _e_take 结算）。
#   右上［敌情］看招数；看着时不走回合。数值初稿——改 game_state 表即可。
# v7：武学按 data_cards 的 art 数据真接进战斗：
#   伤害（mult / 非本门兵器 off_mult）、连追（dash）、护体（guard：turns/cut）、
#   打断（stone：封锁敌人下一手）、回气（heal：回血 + 下次出手加成）；
#   冷却直接用 art.cd（行动计数）；铁布衫已按 v9 数据削弱（2 次·减 45%）。
#   动画/自动挑战/倒计时同 v6。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const Roles := preload("res://journey/data_roles.gd")   # ㉖：自带天赋（按角色 id 查）
const Cards := preload("res://shared/data_cards.gd")
const GameData := preload("res://shared/game_data.gd")  # ㉝：兵器距离（站位用）
const Affixes := preload("res://shared/data_affixes.gd")
const St := preload("res://shared/data_status.gd")      # v52：负面状态（表＋API，游历那边共用同一份）
const Elem := preload("res://shared/data_elem.gd")      # v58：五行（通道口径/抗性/增伤聚合）

# v58：**首领这一手**的伤害属性。v58 第二批起第 400 关的怪带 `elem`（见 tower.gd），
#   所以这里不再是写死的空串——改成读**当前聚焦那一只**身上那一格。
#   ⚠ 用函数而不是变量：`_focus_on()` 一换目标，变量就得不漏一处地跟着改（容易漏）。
func _foe_elem() -> String:
	return str(_e().get("elem", ""))

# v58（用户："物理也是类型伤害 不要忘了"）：飘字用的"名字"——空串＝没元素，
#   但这一手打出来**就是物理伤害**，所以换成 "phys" 好让徽章显示「物」。
#   引擎逻辑仍读 `_foe_elem()`（空串走物理通道），只有飘字用这一口。
func _foe_elem_mark() -> String:
	var e := _foe_elem()
	return "phys" if e == "" else e

const StatusChips := preload("res://shared/status_chips.gd")   # v54：负面状态的小图标
const Tuning := preload("res://shared/tuning.gd")       # ㉘：可调参数读取口
const StickFighter := preload("res://journey/stick_fighter.gd")
const UiKit := preload("res://shared/ui_kit.gd")

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const GOLD := Color(0.72, 0.58, 0.22)
const GREEN := Color(0.30, 0.52, 0.32)
# ㉙：反伤/反刺——橙（回复=绿，一眼分开）
const C_COUNTER := Color(0.95, 0.52, 0.10)
const C_DODGE := Color(0.42, 0.62, 0.86)   # v35：闪避浮字（蓝——与反伤橙、回复绿分得开）
# ㉙：枪势反刺——按陈石气血上限的比例带；嫌高嫌低改这两个数
#
# ㉘ 数值外置：下面这批旋钮可以从 res://tuning.cfg 或 user://tuning.cfg 覆盖
#   （读不到＝用这里写着的默认值，行为与改之前一模一样）。
#   用 static var 而不是 const，因为 const 只吃"编译期常量"、不能调 Tuning.num()；
#   换成 static var 的好处是所有用它的地方（十几处）一个字都不用改。
#   ⚠ 别在运行中往这些变量赋值——它们是"开机读一次的配置"，不是状态。
static var THORN_HP_LO := Tuning.num("combat", "thorn_hp_lo", 0.08)
static var THORN_HP_HI := Tuning.num("combat", "thorn_hp_hi", 0.12)

static var DMG_MUL := Tuning.num("combat", "dmg_mul", 2.0)
static var STEP := Tuning.num("combat", "step", 0.72)
# v38（用户："前期 300 关我想让玩家很快拿到"）：战斗**快进**。
#   一关一手 0.72 秒，前期几百关一路清下来光看动画就是几十分钟——
#   所以给一个玩家自己按的倍速（×1 / ×2 / ×4），只压缩"出手间隔"这一个数，
#   平衡、掉落、赏钱一个都不碰。默认值可以写在 tuning.cfg 的 combat.speed 里。
#   ⚠ 只影响这一场战斗的节奏；散场后仍是 1 倍（下次进来沿用这次选的）。
static var SPEED := Tuning.num("combat", "speed", 1.0)
const SPEED_STEPS := [1.0, 2.0, 4.0]

# 下一档（×1 → ×2 → ×4 → ×1）——抽出来是为了探针/以后的热键能走同一条算法
static func next_speed(cur: float) -> float:
	var i := SPEED_STEPS.find(cur)
	i = 0 if i < 0 else (i + 1) % SPEED_STEPS.size()
	return float(SPEED_STEPS[i])
static var ULT_MUL := Tuning.num("combat", "ult_mul", 2.5)
static var RAGE_GAIN := Tuning.intv("combat", "rage_gain", 34)
# ㊹：全体怒气恢复 -30%。做法是**在基础值上乘一个总系数**，
#   而不是把 rage_gain 的默认值从 34 改成 24——
#   这样 tuning.cfg 里的 rage_gain 仍然代表"原来的基准值"，
#   rage_mul 单独代表"这次整体下调多少"，两个旋钮互不干扰。
#   我方与敌方共用这一个系数（"全体"），两套战斗也都读它。
static var RAGE_MUL := Tuning.num("combat", "rage_mul", 0.7)
static var TECH_EVERY := Tuning.intv("combat", "tech_every", 4)
static var TECH_HEAL := Tuning.num("combat", "tech_heal", 0.15)
static var ENEMY_FLIP := Tuning.flag("combat", "enemy_flip", true)
static var ENEMY_WEAPON := Tuning.text("combat", "enemy_weapon", "dual")
static var AUTO_DELAY_WIN := Tuning.num("combat", "auto_delay_win", 2.0)
static var AUTO_DELAY_LOSE := Tuning.num("combat", "auto_delay_lose", 2.4)
static var LUNGE_OUT := Tuning.num("combat", "lunge_out", 56.0)
static var SHAKE_DECAY := Tuning.num("combat", "shake_decay", 90.0)

static var ART_FALLBACK_MUL := Tuning.num("combat", "art_fallback_mul", 1.8)
const ART_GUARD_COL := Color(0.46, 0.44, 0.42)
const ART_HEAL_COL := Color(0.34, 0.60, 0.40)
const ART_STONE_COL := Color(0.52, 0.44, 0.32)
const ART_DASH_COL := Color(0.36, 0.58, 0.56)

const ELEM_TINT := {
	"metal": Color(0.87, 0.81, 0.60),
	"wood": Color(0.74, 0.84, 0.71),
	"water": Color(0.71, 0.79, 0.90),
	"fire": Color(0.92, 0.76, 0.66),
	"earth": Color(0.86, 0.79, 0.66),
	"true": Color(0.82, 0.73, 0.88),
}
const ELEM_FX := {
	"metal": Color(0.80, 0.68, 0.30),
	"wood": Color(0.34, 0.60, 0.38),
	"water": Color(0.32, 0.50, 0.72),
	"fire": Color(0.80, 0.32, 0.22),
	"earth": Color(0.60, 0.46, 0.28),
	"true": Color(0.56, 0.38, 0.68),
}
const PHYS_FX := Color(0.28, 0.27, 0.29)
const ELEM_PREVIEW_FORCE := ""

signal done(win: bool)
# ㊿q：半路回村（自动挑战继续，改后台推）——跟 done 分开：done 是"这一关打完了"，
#   left 是"人先走了，这一场不结算"（交给挂机估算去判）。合在一个信号里，
#   村里会把离场当成败退，把自动挑战关掉。
signal left()

var stage_i := 0

# ============================================================
# ㊸ 敌阵容：上多人（跟游历 duel_battle 同一套写法）
#
# 以前敌人是"一个字典 + 一堆散装变量"（_e / _e_hp / _e_max / _e_arts / _e_rage …）。
# 现在全部收进 _foes 数组的一项里，按下标排：0 前排、1 中排、2 后排。
#   · 普通关 1 人；精英关 2 人；首领关 3 人（副手血量按 60% / 40% 折算）
#   · 我方普攻只打最前排；招式按自己写的 target 越前排；sweep 打全部
#   · 敌人一个一个出手，按各自 spd 插进回合里
#
# 老代码里那些 `_e_hp` / `_e_arts` / `_e_rage` 现在都是**函数**（指向当前聚焦的那只），
# 所以下面所有用到它们的地方只要多一对括号就行——不必逐处改成 _foes[i]。
# ⚠ _build_foes 必须在任何 _e_*() 访问器之前跑，否则 _cur() 是空字典。
# ============================================================
var _foes: Array = []
var _foe_nodes: Array = []
var _focus := 0
const E_MID_RATIO := GameData.FOE_MID_RATIO      # 中排副手血量/攻击折算（㊼：真源在 game_data）
const E_BACK_RATIO := GameData.FOE_BACK_RATIO    # 后排副手（㊼：同上）
# ⚠ v46：上面这两个数**只有 foe_hp_scale（整组总账）还在用**——单只敌人的折算改走
#   GameData.FOE_ROWS / foe_layout / foe_row_plan（前排肉 · 后排高伤）。
var _party: Array = []
var _pet = null
var _timer := 0.0
var _turn := 0
var _act_order: Array = []   # ㊿：本轮出手顺序（一轮算一次；见 _act()）
var _over := false
var _win := false
var _done_sent := false
var _auto_t := -1.0
var _dot_n := -1
var _enemy_skip := false
var _info_open := false
var _info_veil: Control = null
var _info_btn: Button = null
var _speed_btn: Button = null   # v38：［快进 ×1/×2/×4］

var _world: Node2D
var _shake_amp := 0.0
var _shake_off := Vector2.ZERO
var _flash := 0.0
var _flash_col := Color(1, 1, 1)

var _log: Array = []
# v46：这一关的"对手站位"文案（_build_foes 攒、_ready 里进战报）
var _foe_lineup_note := ""
var _log_lb: Label
var _e_hp_lb: Label
var _e_st_lb: Label          # v52：首领身上那一行负面状态
var _e_chips = null          # v54：首领身上那排小图标
var _e_fill: ColorRect
var _e_bar_w := 420.0
var _rows: Array = []
var _result_lb: Label
var _auto_lb: Label
var _act_btn: Button
var _bg_btn: Button
var _auto_btn: Button
var _ground_y := 985.0

class PetMark extends Node2D:
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var bob := sin(t * 3.2) * 2.0
		var body := Color(0.965, 0.950, 0.915, 0.98)
		var inkc := Color(0.30, 0.27, 0.28, 0.95)
		draw_circle(Vector2(-6, -10 + bob * 0.4), 10.0, body)
		draw_circle(Vector2(10, -18 + bob), 7.5, body)
		draw_colored_polygon(PackedVector2Array([Vector2(5, -25 + bob), Vector2(9, -32 + bob), Vector2(12, -24 + bob)]), body)
		draw_colored_polygon(PackedVector2Array([Vector2(13, -25 + bob), Vector2(16, -31 + bob), Vector2(18, -23 + bob)]), body)
		draw_arc(Vector2(-15, -14 + bob * 0.6), 10.0, PI * 0.85, PI * 1.45, 10, body, 4.0)
		draw_circle(Vector2(12, -19 + bob), 1.2, inkc)
		draw_circle(Vector2(16, -16 + bob), 1.0, inkc)
		draw_line(Vector2(-10, -3), Vector2(-10, 1), inkc, 1.6)
		draw_line(Vector2(2, -3), Vector2(2, 1), inkc, 1.6)

class Fx extends Node2D:
	var kind := "hit"
	var col := Color(0.3, 0.3, 0.3)
	var dir := 1.0
	var t := 0.0
	var dur := 0.42
	var r := 46.0

	func _process(delta: float) -> void:
		t += delta
		if t >= dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var p := clampf(t / dur, 0.0, 1.0)
		var a := 1.0 - p
		match kind:
			"slash":
				var a0 := -1.0 + 2.1 * p * dir
				draw_arc(Vector2.ZERO, r * (0.85 + 0.35 * p), a0 - 0.85, a0 + 0.85, 18, Color(col.r, col.g, col.b, a * 0.9), 8.0 * a + 1.0)
				draw_arc(Vector2.ZERO, r * (0.66 + 0.35 * p), a0 - 0.6, a0 + 0.6, 14, Color(1, 1, 1, a * 0.6), 4.0 * a + 0.5)
			"hit":
				for i in 7:
					var ang := TAU * float(i) / 7.0 + 0.3
					var l0 := r * (0.22 + 0.75 * p)
					var l1 := l0 + r * 0.5 * a
					var v0 := Vector2(cos(ang), sin(ang)) * l0
					var v1 := Vector2(cos(ang), sin(ang)) * l1
					draw_line(v0, v1, Color(col.r, col.g, col.b, a), 3.0 * a + 0.8)
				draw_circle(Vector2.ZERO, r * 0.30 * (1.0 - p * 0.5), Color(1, 1, 1, a * 0.75))
				draw_arc(Vector2.ZERO, r * (0.35 + 0.8 * p), 0.0, TAU, 20, Color(col.r, col.g, col.b, a * 0.8), 3.0 * a + 0.6)
			"dust":
				for i in 5:
					var ang2 := PI + float(i) * 0.5 * dir - 0.4
					var d := r * (0.2 + 0.9 * p) * (1.0 + 0.12 * float(i))
					draw_circle(Vector2(cos(ang2), sin(ang2)) * d, (8.0 - float(i)) * (1.0 - p) + 1.0, Color(0.55, 0.50, 0.42, a * 0.55))
			"heal":
				for i in 6:
					var ph := fmod(p * 1.6 + float(i) * 0.17, 1.0)
					var x := float(i - 3) * 9.0 * dir
					draw_circle(Vector2(x, -ph * r), 3.2 * (1.0 - ph), Color(col.r, col.g, col.b, a * 0.9))
				draw_arc(Vector2.ZERO, r * (0.3 + 0.6 * p), 0.0, TAU, 20, Color(col.r, col.g, col.b, a * 0.5), 2.5)
			"guard":
				var rr := r * (0.55 + 0.08 * sin(float(Time.get_ticks_msec()) / 120.0))
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 24, Color(col.r, col.g, col.b, a), 3.0)
				draw_arc(Vector2.ZERO, rr * 1.18, 0.0, TAU, 24, Color(1, 1, 1, a * 0.45), 1.5)
			"wave":
				var w := r * (0.5 + 1.7 * p)
				draw_arc(Vector2.ZERO, w, -1.1, 1.1, 26, Color(col.r, col.g, col.b, a), 18.0 * a + 2.0)
				draw_arc(Vector2.ZERO, w * 0.82, -0.9, 0.9, 22, Color(1, 1, 1, a * 0.6), 9.0 * a + 1.5)
			"wind":
				for i in 2:
					var off := float(i) * 0.95 * dir
					draw_arc(Vector2.ZERO, r * (0.6 + 0.55 * p), -1.4 + off, 1.1 + off, 16, Color(col.r, col.g, col.b, a * 0.85), 5.0 * a + 1.0)
			_:
				pass

# ---- ㊸ 敌阵容：建表 / 访问器 ----

func _cur() -> Dictionary:
	if _foes.is_empty():
		return {}
	return _foes[clampi(_focus, 0, _foes.size() - 1)]

# 老代码里的 _e 是"当前敌人的人设字典"，这里照旧返回当前聚焦那只
func _e() -> Dictionary:
	return _cur()

func _e_hp() -> int:
	return int(_cur().get("hp", 0))

func _e_max() -> int:
	return int(_cur().get("hp_max", 1))

func _set_e_hp(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["hp"] = maxi(0, v)

func _e_arts() -> Array:
	return _cur().get("arts", [])

func _e_ult() -> Dictionary:
	return _cur().get("ult", {})

func _e_affixes() -> Array:
	return _cur().get("affixes", [])

func _e_art_i() -> int:
	return int(_cur().get("art_i", 0))

func _set_e_art_i(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["art_i"] = v

func _e_art_cd() -> int:
	return int(_cur().get("art_cd", 0))

func _set_e_art_cd(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["art_cd"] = v

func _e_rage() -> int:
	return int(_cur().get("rage", 0))

func _set_e_rage(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["rage"] = v

func _e_guard_turns() -> int:
	return int(_cur().get("guard_turns", 0))

func _set_e_guard_turns(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["guard_turns"] = v

func _e_guard_cut() -> float:
	return float(_cur().get("guard_cut", 0.0))

func _set_e_guard_cut(v: float) -> void:
	var c := _cur()
	if not c.is_empty():
		c["guard_cut"] = v

func _e_next_mult() -> float:
	return float(_cur().get("next_mult", 1.0))

func _set_e_next_mult(v: float) -> void:
	var c := _cur()
	if not c.is_empty():
		c["next_mult"] = v

func _e_stack() -> float:
	return float(_cur().get("stack", 0.0))

func _set_e_stack(v: float) -> void:
	var c := _cur()
	if not c.is_empty():
		c["stack"] = v

func _e_acts() -> int:
	return int(_cur().get("acts", 0))

func _set_e_acts(v: int) -> void:
	var c := _cur()
	if not c.is_empty():
		c["acts"] = v

func _enemy_node() -> Node:
	if _focus < _foe_nodes.size():
		return _foe_nodes[_focus]
	return null

func _build_foes(stage_i_arg: int) -> void:
	_foes.clear()
	var base: Dictionary = GameState.enemy_at(stage_i_arg)
	var boss := bool(base.get("boss", false))
	var elite := bool(base.get("elite", false))
	var n := 1
	if boss:
		n = 3
	elif elite:
		n = 2
	var bname := str(base.get("name", "敌人"))
	var bhp := float(base.get("hp", 60))
	var batk := float(base.get("atk", 8))
	# v46：站位——前排肉 / 中排均衡 / 后排高伤（详见 game_data.FOE_ROWS 那段）。
	#   · 首领/精英自己按"站位型"落位（肉盾站前排、高伤躲后排），副手补剩下的位置；
	#   · 整组的总血池/总攻击**跟旧口径一样**（foe_row_plan 归一），所以难度不变；
	#   · 列表**按排号排**（下标即排号）——_row_of / _row_exposed / _pick_target 全靠这条。
	var arch: int = GameData.foe_archetype(stage_i_arg)
	var layout: Array = GameData.foe_layout(n, arch)
	var rows: Array = []
	for e_v in layout:
		rows.append(int((e_v as Dictionary).get("row", 0)))
	var plan: Array = GameData.foe_row_plan(rows)
	# v47：单人关（占 88%）没有"前后排"可讲，改摇一个**体型**——
	#   肉盾（血厚打得轻）/ 寻常 / 高伤（打得疼不经打），按关号轮换；
	#   血×攻 的乘积不变，所以难度不动，变的是"这一关该怎么打"。
	#   实测口径与离线估算同一口（GameData.foe_stage_scale）。
	var solo: Dictionary = {} if n > 1 else GameData.foe_solo_profile(stage_i_arg)
	# 副手（非本体）的武器/名字/颜色——后排给"杀手"、前排给"盾手"，一眼看得出谁疼
	var sub_weapon := ["spear", "dual", "dagger"]
	var sub_color := [[0.34, 0.30, 0.36], [0.40, 0.34, 0.28], [0.30, 0.26, 0.34]]
	var bdef := GameData.foe_def(batk, float(base.get("def", 0)))   # 先按**未折算**的基准攻击算防御
	for i in n:
		var le: Dictionary = layout[i]
		var is_main := bool(le.get("main", true))
		var row := int(le.get("row", 0))
		var pl: Dictionary = plan[i]
		var d: Dictionary = base.duplicate(true)
		if not is_main:
			d["weapon"] = str(sub_weapon[clampi(row, 0, sub_weapon.size() - 1)])
			d["name"] = bname + "·" + GameData.foe_row_sub(row)
			d["color"] = sub_color[clampi(row, 0, sub_color.size() - 1)]
			d["scale"] = maxf(0.7, float(base.get("scale", 1.0)) * 0.92)
			# 副手不带招数/大招：招数是首领的成名技，副手只跟着打
			d["arts"] = []
			d["ult"] = {}
		# 血量/攻击按站位折算（前端肉、后端高伤）；防御也按站位给（前排厚、后排薄）
		#   v47：单人关再乘体型那一份
		var hp := maxi(1, int(round(bhp * float(pl.get("hp", 1.0)) * float(solo.get("hp", 1.0)))))
		var fatk := maxi(1, int(round(batk * float(pl.get("atk", 1.0)) * float(solo.get("atk", 1.0)))))
		var fdef := maxi(0, int(round(float(bdef) * float(pl.get("def", 1.0)) * float(solo.get("def", 1.0)))))
		_foes.append({
			"name": str(d.get("name", bname)),
			"weapon": str(d.get("weapon", ENEMY_WEAPON)),
			"hp": hp, "hp_max": hp,
			"atk": fatk,
			"spd": int(d.get("spd", 100)),
			# v35：防御值——表里带了就用，没带按攻击折一半（GameData.foe_def）。
			#   有了它，"我打过去"那一下也走攻防对拼（攻高就压得住）。
			"def": fdef,
			"color": d.get("color", [0.5, 0.3, 0.28]),
			"scale": float(d.get("scale", 1.0)),
			"chapter": str(d.get("chapter", "")),
			"arts": (d.get("arts", []) as Array).duplicate(true),
			"ult": (d.get("ult", {}) as Dictionary).duplicate(true),
			"affixes": (d.get("affixes", []) as Array).duplicate(),
			"row": row,          # v46：排号（＝下标；前排肉、后排高伤）
			"is_main": is_main,  # 本体（带招的那个）
			"solo_cn": str(solo.get("cn", "")),   # v47：单人关的体型名（多人关是空串）
			"art_i": 0, "art_cd": 0, "rage": 0,
			"guard_turns": 0, "guard_cut": 0.0, "next_mult": 1.0,
			"stack": 0.0, "acts": 0,
		})
	# 这一关的阵容说清楚：谁在前面、谁在打伤害——不然"打谁先"全靠猜
	#   （文案先攒着，等 _ready 里"对手：…"那行之后一起进战报）
	_foe_lineup_note = ""
	if n > 1:
		var who: Array = []
		for i2 in _foes.size():
			var f2: Dictionary = _foes[i2]
			who.append(GameData.foe_row_cn(i2) + "：" + str(f2["name"])
				+ "（气 " + str(f2["hp"]) + " · 攻 " + str(f2["atk"]) + "）")
		_foe_lineup_note = ("对手站位——" + "　".join(PackedStringArray(who))
			+ "\n站位型：" + GameData.foe_archetype_cn(arch) + "｜前排挡刀、后排打得疼，普通攻击只打最前排")
	elif not solo.is_empty():
		# v47：单人关——把这一只的"体型"说清楚（不然玩家只觉得这关莫名其妙更肉/更疼）
		#   寻常那一档不用解释（它就是原来的身板）
		var tail2 := "" if is_equal_approx(float(solo.get("hp", 1.0)), 1.0) else "——血×攻的总账跟寻常怪一样，只是偏了一头"
		_foe_lineup_note = ("这只的体型：" + str(solo.get("cn", "")) + "（" + str(solo.get("desc", ""))
			+ "）｜气 " + str(_foes[0]["hp"]) + " · 攻 " + str(_foes[0]["atk"]) + tail2)

func _focus_on(i: int) -> void:
	_focus = clampi(i, 0, maxi(0, _foes.size() - 1))

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

# v12：我方还剩几个（这段原来在四五处各抄一遍；这次修卡死要用它，收成一口）
func _party_alive() -> int:
	var n := 0
	for m in _party:
		if int((m as Dictionary).get("hp", 0)) > 0:
			n += 1
	return n

func _front_foe() -> int:
	for i in _foes.size():
		if _foe_alive(i):
			return i
	return -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = get_viewport_rect().size
	GameState.battle_live = true   # ㊿：告诉账本"屏幕上正打着"——挂机估算要避开这一关
	GameState._battle_seen = true  # ㊿：这一拍打过真仗（连打时估算整拍让位）
	stage_i = clampi(stage_i, 0, GameState.STAGE_MAX - 1)
	# ㊸：敌阵容——普通 1 / 精英 2 / 首领 3；数据都在 _foes 里
	_build_foes(stage_i)
	_focus_on(0)
	_build_party()
	_build_ui()
	_spawn_fighters()
	_log.append("对手：" + str(_e()["name"]) + "（" + str(_e()["chapter"]) + "）")
	# v46：多人关把"谁站前面、谁打得疼"写进战报（文案在 _build_foes 里攒好）
	if _foe_lineup_note != "":
		for ln in _foe_lineup_note.split("\n"):
			_log.append(str(ln))
	if bool(_e().get("boss", false)):
		_log.append("这关是「首领」——比前几关硬不少")
	if not _e_arts().is_empty() or not _e_ult().is_empty():
		_log.append("首领带招——点右上［敌情］看招数")
	if not _e_affixes().is_empty():
		_log.append("此怪带词缀：" + Affixes.names_text(_e_affixes()) + "——点右上［敌情］看门道")
	if GameState.auto_climb:
		_log.append("自动挑战：开——清完接下一关；想回村点右下［回村·后台继续］")
	else:
		_log.append("自动开打——想走按［撤退］")
	if GameState.pet_passive_pct() > 0:
		_log.append(str(GameState.pet_follow_data().get("name", "宠物")) + "（" + GameState.pet_follow_stage_name() + "）随行：全队气血 +" + str(GameState.pet_passive_pct()) + "%")
	if not _party.is_empty():
		var e0 := Cards.elem_of(str(_party[0].get("weapon", "")))
		if e0 != "":
			_log.append("兵器带五行「" + str(Cards.ELEM_CN.get(e0, e0)) + "」——背景与刀光随它调色")
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(_start_banner)
	print("[出村战斗] 第 ", stage_i + 1, " 关：", _e()["name"], " 我方=", GameState.formation, " 自动挑战=", GameState.auto_climb)
	_refresh_auto_ui()
	_refresh()

func _start_banner() -> void:
	_center_move("开　打", INK)

func _build_party() -> void:
	for id in GameState.formation:
		var d: Dictionary = GameState.role_data(str(id))
		if d.is_empty():
			continue
		# ㊽：队里口径——effective_stats（个人）＋ 上阵羁绊。
		#   战斗必须走这个口，不然面板上"羁绊 +10 攻"看得见、打起来却没有。
		# v48：**宠物护主（气血%）只乘一次**——它已经在 effective_stats 里乘过了
		#   （game_state.gd 的那一段），这里再乘一遍就是"面板 105、打起来 110"那种双算。
		#   对照：青隼的速度% 一直只乘一次（就在 effective_stats 里），气血这条以前漏了。
		var eff: Dictionary = GameState.squad_stats(str(id))
		var hp := int(eff.get("hp", 80))
		var ult: Dictionary = d.get("ult", {})
		var tech: Dictionary = d.get("tech", {})
		var pas: Dictionary = d.get("passive", {})
		var pkind := str(pas.get("kind", ""))
		var pv := float(pas.get("v", 0.0))
		# v48：天赋 ＋ 角色星 stat ＋ 专武常驻 fx —— 走 GameState 那一口（面板/估算读同一份）
		var tfx: Dictionary = GameState.combat_tfx(str(id))
		# 机制那一份（大招增伤/持续/追击段数/被动强化…）——星 mech ＋ **专武 mech** 都已并好。
		#   ⚠ 顺序：先拿 smech 再算 passive_up，否则专武带的 passive_up 不生效（与游历同口径）。
		var smech: Dictionary = GameState.combat_mech(str(id))
		var star_pu := float(smech.get("passive_up", 0.0))   # 被动强化（星＋专武）
		pv = pv * (1.0 + star_pu)
		var cut_v := 0.0
		var rage_mul := 1.0
		var crit_add := 0.0
		match pkind:
			"taken_cut":
				cut_v = pv
			"rage_up":
				rage_mul = 1.0 + pv
			"glass_crit":
				crit_add = pv
				hp = maxi(1, int(round(float(hp) * (1.0 - float(pas.get("hp_cut", 0.0))))))
		# ㉖／㊳：自带天赋（真源 journey/data_roles.gd）
		#   有的自带认兵器（洞察＝用匕首；原来的断枪＝用枪），所以先把手里那把算出来
		var wpn_kind := str(Cards.weapon_of(str(d.get("weapon", ""))))
		var inn: Dictionary = Roles.innate_of(str(id))
		var inn_on := Roles.innate_active(inn, wpn_kind)
		var inn_kind := str(inn.get("kind", "")) if inn_on else ""
		var thorn_mul := 1.0
		var foe_low_mul := 1.0
		var row_prio := ""
		if inn_kind == "innate_hp_pct":
			hp = maxi(1, int(round(float(hp) * (1.0 + float(inn.get("hp_pct", 0.0))))))
		elif inn_kind == "thorn_up":
			thorn_mul = 1.0 + float(inn.get("v", 0.0))
		elif inn_kind == "foe_low_hp_dmg":
			foe_low_mul = float(inn.get("mult", 1.0))
		if inn_on:
			row_prio = str(inn.get("row_priority", ""))
		# ⚠ 先分好"出手轮转的武学(arts)"与"被动功法(passives)"——下面折专武要用 passives，
		#   而折进去的 hp_pct / crit 又必须在 hp / crit_add 结算之前落地。
		#   所以这一段**必须排在这里**（以前排在下面，等于先用后声明：Godot 直接报
		#   "Identifier passives not declared in the current scope"）。
		var arts: Array = []
		var passives: Array = []   # ㊿z4：被动功法（专武那类）——不进出手轮转
		var sk: Array = d.get("skills", [])
		for s in sk:
			var sid := str(s)
			if sid != "" and str(Cards.by_id(sid).get("pool", "")) == "arts":
				if Cards.art_is_passive(sid):
					passives.append(sid)
				else:
					arts.append(sid)
		# ㉗／v48：天赋 ＋ 角色星 stat ＋ 专武常驻 fx —— tfx 与 smech 都在上面取好了
		#   （GameState.combat_tfx / combat_mech）。专武那份 fx 也并进 smech，
		#   所以"受击怒/反刺写在常驻里"照样生效（引擎各读各认得的键）。
		if not tfx.is_empty():
			hp = maxi(1, int(round(float(hp) * (1.0 + float(tfx.get("hp_pct", 0)) / 100.0))))
			crit_add += float(tfx.get("crit", 0))
		# 剑心通明：使剑或空手时增伤。直接并进 atk——这样下面 8 处出手伤害
		# （普攻/武学/大招/追击…）一次全吃到，不用逐处去乘，免得漏一处。
		# ⚠ v37（用户问"武学升星是不是没实装"）：查出来**伤害加成% 在出村战斗里根本没算**——
		#   以前只把天赋的 dmg 当**平面攻击**加上（+15 就是 +15 攻），而装备/武学那一份
		#   `eff.dmg`（面板"伤害加成"那一行，含**武学升星**的每星 +20%）一个都没吃。
		#   后果：武学升到五星在爬塔里毫无变化（离线估算 formation_dps_est 反而算了它，
		#   两边口径还不一致）。现在统一成"**按百分比放大攻击**"，与估算同一把尺子。
		var dmg_pct := float(eff.get("dmg", 0.0)) + float(tfx.get("dmg", 0))
		var t_atk := int(round(float(eff.get("atk", 8)) * (1.0 + dmg_pct / 100.0)))
		if float(tfx.get("art_dmg", 0)) != 0.0 and (wpn_kind == "sword" or wpn_kind == "fist"):
			t_atk = int(round(float(t_atk) * (1.0 + float(tfx.get("art_dmg", 0)) / 100.0)))
		if not inn.is_empty():
			# ⚠ 别写成 append(a, b)——GDScript 的 append 只吃一个参数。
			#   要拼两段就自己拼好再 append。
			_log.append(str(d.get("name", id)) + " 自带【" + str(inn.get("name", "")) + "】："
				+ str(inn.get("desc", ""))
				+ ("（生效中）" if inn_on else "（须持对应兵器，当前未生效）"))
		if pkind != "":
			_log.append(str(d.get("name", id)) + " 被动【" + str(pas.get("name", "")) + "】：" + str(pas.get("desc", "")))
		# ㊿y：角色星的 mech 组——落在下面这些成员字段上（引擎本来就在读它们，
		#   所以每条都只是"换个数值"，不需要新的战斗逻辑）
		var star_um := float(smech.get("ult_dmg", 0.0))      # 大招倍率
		var star_ud := int(smech.get("ult_dur", 0.0))        # 大招持续（手）
		var star_tu := float(smech.get("thorn_up", 0.0))     # 反刺
		# 出手顺序用的速度：资质/装备/星给的都是加数
		#   （㊿z9：宠物那份 spd_pct 已经在 effective_stats 里乘过了，这里别再乘一遍）
		var spd_v := float(eff.get("spd", 10)) + float(tfx.get("spd", 0))
		_party.append({
			"id": str(id),
			"name": str(d.get("name", id)),
			"idx": _party.size(),   # ㊿z3：自己在队里的下标（"self"加持要按它找人）
			"weapon": str(d.get("weapon", "")),
			# v58：手里那把的**件名**（五行元素挂在件名上，见 GameState.item_elems）；
			#   `weapon` 那一格是**类型**（sword/dual/…），查不到元素。
			"weapon_id": str(d.get("weapon", "")),
			# v58：三通道增伤——`dmg` 那一份已经并进 t_atk（见上面 589~590 行，＝**全伤害**），
			#   这里把**物理**与**五行**那两份单独带进来，出手时再乘一道（不重复计）。
			"phys_dmg": float(eff.get("phys_dmg", 0.0)),
			"metal_dmg": float(eff.get("metal_dmg", 0.0)),
			"water_dmg": float(eff.get("water_dmg", 0.0)),
			"wood_dmg": float(eff.get("wood_dmg", 0.0)),
			"fire_dmg": float(eff.get("fire_dmg", 0.0)),
			"earth_dmg": float(eff.get("earth_dmg", 0.0)),
			# v58：五行抗性（挨打时用；怪现在还没有元素，先备着）
			"fire_res": float(eff.get("fire_res", 0.0)),
			"water_res": float(eff.get("water_res", 0.0)),
			"metal_res": float(eff.get("metal_res", 0.0)),
			"wood_res": float(eff.get("wood_res", 0.0)),
			"earth_res": float(eff.get("earth_res", 0.0)),
			"hp": hp, "max": hp,
			"atk": t_atk,
			"spd": spd_v,   # ㊶：出手顺序按它排（㊿z9：宠物速度已并进来）
			"crit": float(eff.get("crit", 5.0)) + crit_add,
			# ㊿y2：暴击伤害——真属性了（倍率 = 1.0 + 它/100；以前写死 1.6）
			"crit_dmg": float(eff.get("crit_dmg", 50.0)) + float(tfx.get("crit_dmg", 0.0)),
			"rage": int(smech.get("open_rage", 0.0)), "acts": 0,
			"arts": arts, "art_i": 0, "art_cd": 2,
			# ㊿y：星给的"武学冷却 -N / 受伤后下一击 +N% / 追剑 +N 段"——存着，到点上再用
			"star_acdm": int(smech.get("art_cd_minus", 0.0)),
			"star_veng": float(smech.get("vengeance", 0.0)),
			"star_follow": int(smech.get("follow_hits", 0.0)),
			# ㊿z：后面这批是"武学宗师 / 铁桩 / 猎影 / 凝息"四条机制
			"star_anyw": float(smech.get("art_any_weapon", 0.0)) > 0.0,   # 无视武学兵器要求
			"star_rage_hit": float(smech.get("rage_on_hit", 0.0)),          # 受击回怒
			"star_crit_low": float(smech.get("crit_low_pct", 0.0)),         # 对手残血时暴击 +N 个百分点
			"star_critmul": float(smech.get("crit_mul_up", 0.0)),           # 暴击伤害 +N（比例）
			# ㊿z6：专武那几条机制（数值已按星数放大）
			"ex_ult_per_hit": float(smech.get("ult_per_hit", 0.0)),         # 大招每击中一名对手再 +N
			"ex_ult_rage": float(smech.get("ult_back_rage", 0.0)),          # 对单人：大招后回怒 N 点
			"ex_ult_cut": float(smech.get("ult_cut", 0.0)),                 # 大招窗口内减伤 +N
			"ex_thorn_all": float(smech.get("thorn_all", 0.0)) > 0.0,       # 反刺打全体
			"ex_thorn_per": float(smech.get("thorn_per_hit", 0.0)),         # 每击中一名敌人反刺 +N
			"ex_thorn_heal": float(smech.get("thorn_heal", 0.0)),           # 每次反刺回 N% 气血
			"ex_follow": float(smech.get("follow_dmg", 0.0)),               # 暴击时追击伤害 +N
			"ex_follow_crit": float(smech.get("follow_crit_up", 0.0)),      # 追击暴击时再 +N
			"ex_chain_up": float(smech.get("ult_chain_up", 0.0)),           # 大招连发：后一下 +N
			"ex_chain_turns": int(smech.get("ult_chain_turns", 0.0)),       # 大招连发窗口（回合）
			"ult_chain_left": 0,                                            # 窗口剩余回合
			"thorn_ramp": 0.0,                                              # 反刺的累计增幅（自己命中攒）
			"guard_turns": 0, "guard_cut": 0.0, "next_mult": 0.0,
			# ㊿：加持（kind "bless"）——减伤走 bless_cut，增伤/暴击直接改 atk/crit
			#   （原值存在 bless_atk_base / bless_crit_base，到期还原）
			"bless_turns": 0, "bless_cut": 0.0, "bless_skip": false,
			"ult": str(ult.get("name", "大招")),
			"ult_kind": str(ult.get("kind", "hit")),
			"ult_mult": float(ult.get("mult", ULT_MUL)) * (1.0 + star_um),
			# ㊺：只剩一个敌人时改用的倍率（群攻大招的"单体档"；0＝不区分）
			"ult_mult_single": float(ult.get("mult_single", 0.0)) * (1.0 + star_um),
			# ㊹：大招的落点。不写＝只打当前那一只；"sweep"＝横扫所有活着的敌人。
			"ult_target": str(ult.get("target", "front")),
			# v52：大招自带的状态（写在 data_roles 的大招里的 "apply"；现在还没有人带，管子先接通）
			"ult_apply": ult.get("apply", {}),
			"ult_turns_max": int(ult.get("turns", 3)) + star_ud,
			"ult_regen": float(ult.get("regen_pct", 0.0)),
			"ult_thorn": float(ult.get("thorn", 0.0)),
			"ult_thorn_on": false,   # ㉙：枪势窗开着的标记（窗口内才反刺）
			"ult_follow": float(ult.get("follow", 0.0)),
			"ult_turns": 0, "ult_new": false, "ult_follow_hits": 1,
			"cut": cut_v, "rage_mul": rage_mul,
			# v35：防御 / 闪避——**数值**（不折算成减伤率）：挨打时走 GameData.def_cut /
			#   dodge_rate 那一套对拼。来源＝effective_stats（等级/根骨/丹药/装备/宠物/羁绊）
			#   ＋ 天赋与星的加数，跟面板上显示的同一个数。
			"def": float(eff.get("def", 5)) + float(tfx.get("def", 0)),
			"dodge": float(eff.get("dodge", 5)) + float(tfx.get("dodge", 0)),
			# ㉗：百折不挠（残血减伤）——按条件现算，跟 duel_battle 同口径
			"talent_cut": float(tfx.get("dmg_cut", 0)) / 100.0,
			# ㊳：自带带来的三条（断枪反刺加成 / 洞察的残敌增伤与绕前排）
			"thorn_mul": thorn_mul * (1.0 + star_tu),   # ㊿y：星的反刺加成并进来
			"foe_low_mul": foe_low_mul,
			"row_prio": row_prio,
			# ============================================================
			# v54：**闭窍**要用的"基准值"（用户："闭窍是针对玩家的"）。
			#   上面这些字段都是"底子 ×(1+被动)"现算出来的，压掉被动之后要还原得了，
			#   就得在**建队时**把"没有被动/没有星的那一份"和"被动加了几点"一起存下来：
			#     *_base  → 压掉时直接写回基准
			#     *_pas   → 压掉时减掉的那几点（加数型）
			#   ⚠ 只有**已经算进气血上限**的那一份退不回来（自家 passive 的 hp_pct、星的 hp）
			#     ——血条不会缩，这条写在状态说明里。
			# ============================================================
			"ult_mult_base": float(ult.get("mult", ULT_MUL)),
			"ult_mult_single_base": float(ult.get("mult_single", 0.0)),
			"ult_turns_base": int(ult.get("turns", 3)),
			"crit_pas": crit_add,
			"def_pas": float(tfx.get("def", 0)),
			"dodge_pas": float(tfx.get("dodge", 0)),
			"atk_artmul": (1.0 + float(tfx.get("art_dmg", 0)) if (float(tfx.get("art_dmg", 0)) != 0.0
				and (wpn_kind == "sword" or wpn_kind == "fist")) else 1.0),
			"stun": 0, "poison": 0,
			"tech": str(tech.get("name", "自带技")),
			"node": null, "base_x": 0.0, "base_y": 0.0,
		})
		if arts.size() > 0:
			var nm2: Array = []
			for a in arts:
				nm2.append(Cards.name_of(str(a)) + "（冷却 " + str(Cards.art_cd(str(a))) + " 次）")
			_log.append(str(d.get("name", id)) + " 带武学：" + "、".join(PackedStringArray(nm2)))
	if _party.is_empty():
		_party.append({"id": "player", "name": "少侠", "weapon": "sword", "hp": 80, "max": 80, "atk": 8, "rage": 0, "acts": 0, "arts": [], "art_i": 0, "art_cd": 2, "guard_turns": 0, "guard_cut": 0.0, "next_mult": 0.0, "bless_turns": 0, "bless_cut": 0.0, "bless_skip": false, "ult": "大招", "tech": "自带技", "node": null, "base_x": 0.0, "base_y": 0.0})

# ---- 界面 ----

func _build_ui() -> void:
	var px := size.x
	var py := size.y
	_ground_y = py * 0.77
	_world = Node2D.new()
	add_child(_world)

	var title := _label("第 " + str(stage_i + 1) + " 关 · " + str(_e()["name"]), 18, INK)
	title.position = Vector2(20, 18)
	title.size = Vector2(380, 28)
	add_child(title)

	# ㊿z7：右上这三颗钮原来只有 12 号字 / 32 高——手机上根本戳不准（用户：
	#   "自动 加速 敌情按钮太小 加大"）。现在 17 号字 / 50 高，两排：
	#   第一排［自动挑战］（通栏），第二排［快进］＋［敌情］。
	#   ⚠ 首领名牌与血条整体下移 70（58→128 起），免得被加高的钮压住。
	_auto_btn = Button.new()
	_auto_btn.focus_mode = Control.FOCUS_NONE
	_auto_btn.add_theme_font_size_override("font_size", 17)
	_auto_btn.text = "自动挑战：关（点我开）"
	_auto_btn.position = Vector2(px - 320.0, 10.0)
	_auto_btn.size = Vector2(308, 50)
	_auto_btn.pressed.connect(_on_auto_toggle)
	add_child(_auto_btn)

	# v8：［敌情］——看首领招数（看着时不走回合）
	_info_btn = Button.new()
	_info_btn.focus_mode = Control.FOCUS_NONE
	_info_btn.add_theme_font_size_override("font_size", 17)
	_info_btn.text = "敌情（招数）"
	_info_btn.position = Vector2(px - 148.0, 64.0)
	_info_btn.size = Vector2(136, 50)
	_info_btn.pressed.connect(_show_info)
	_style_btn(_info_btn, Color(0.21, 0.19, 0.20))
	add_child(_info_btn)

	# v38：［快进］——前期一路清关用（×1 / ×2 / ×4）。只压出手间隔，不动平衡。
	_speed_btn = Button.new()
	_speed_btn.focus_mode = Control.FOCUS_NONE
	_speed_btn.add_theme_font_size_override("font_size", 17)
	# ㊿z7：150 → 164 宽：17 号字下「快进 ×4（点我切）」正好差几个像素，
	#   量过才定这个数（[敌情] 顺势收成 136，两颗之间仍隔 8）。
	_speed_btn.position = Vector2(px - 320.0, 64.0)
	_speed_btn.size = Vector2(164, 50)
	_speed_btn.pressed.connect(_on_speed_toggle)
	_style_btn(_speed_btn, Color(0.21, 0.19, 0.20))
	_refresh_speed_btn()
	add_child(_speed_btn)

	var ename := _label(str(_e()["name"]), 24, INK)
	ename.position = Vector2(px * 0.5 - 180.0, 126)
	ename.size = Vector2(360, 34)
	ename.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ename)

	_e_bar_w = minf(px - 140.0, 420.0)
	var bx := (px - _e_bar_w) * 0.5
	var bg := ColorRect.new()
	bg.position = Vector2(bx, 166)
	bg.size = Vector2(_e_bar_w, 16)
	bg.color = Color(0.10, 0.09, 0.10, 0.20)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_e_fill = ColorRect.new()
	_e_fill.position = Vector2(bx, 166)
	_e_fill.size = Vector2(_e_bar_w, 16)
	_e_fill.color = Color(0.62, 0.22, 0.18, 0.85)
	_e_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_e_fill)
	_e_hp_lb = _label("", 12, Color(0.96, 0.94, 0.90))
	_e_hp_lb.position = Vector2(bx, 166)
	_e_hp_lb.size = Vector2(_e_bar_w, 16)
	_e_hp_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_e_hp_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_e_hp_lb)

	# v54：首领身上那些负面状态的小图标——血条右边那块空处
	_e_chips = StatusChips.new()
	_e_chips.position = Vector2(bx + _e_bar_w + 4.0, 163.0)
	_e_chips.size = Vector2(140.0, 22.0)
	_e_chips.cell = 17.0
	_e_chips.max_n = 5      # 每块 23 像素（17＋6）——血条右边只剩这么宽，再多就画"…"
	add_child(_e_chips)

	# v52：首领身上挂着的负面状态（血条正下方一行）
	_e_st_lb = _label("", 12, St.col_of("burn"))
	_e_st_lb.position = Vector2(bx, 184.0)
	_e_st_lb.size = Vector2(_e_bar_w, 18)
	_e_st_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_e_st_lb)

	_rows = []
	for i in _party.size():
		var y := 212.0 + float(i) * 56.0
		var nm := _label("", 16, INK)
		nm.position = Vector2(20, y)
		nm.size = Vector2(150, 24)
		add_child(nm)
		var b := ColorRect.new()
		b.position = Vector2(170, y + 2)
		b.size = Vector2(200, 14)
		b.color = Color(0.10, 0.09, 0.10, 0.18)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		var fill := ColorRect.new()
		fill.position = Vector2(170, y + 2)
		fill.size = Vector2(200, 14)
		fill.color = GREEN
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fill)
		var rb := ColorRect.new()
		rb.position = Vector2(170, y + 24)
		rb.size = Vector2(200, 5)
		rb.color = Color(0.10, 0.09, 0.10, 0.15)
		rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rb)
		var rf := ColorRect.new()
		rf.position = Vector2(170, y + 24)
		rf.size = Vector2(0, 5)
		rf.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.9)
		rf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rf)
		var hpt := _label("", 13, Color(INK.r, INK.g, INK.b, 0.80))
		hpt.position = Vector2(378, y)
		hpt.size = Vector2(130, 24)
		add_child(hpt)
		# v52：身上挂着的负面状态（"燃烧2 · 缴械"）——这一行平时是空的
		#   ⚠ y+31 而不是 y+28：上面那条怒气条占到 y+29，压上去会跟它叠一条边
		var stq := _label("", 12, St.col_of("burn"))
		stq.position = Vector2(22, y + 31.0)
		stq.size = Vector2(340, 16)
		add_child(stq)
		# v54：负面状态的小图标（一行小方块，一个字一块）——放在血量文字右边那块空处
		var chip := StatusChips.new()
		chip.position = Vector2(510.0, y + 1.0)
		chip.size = Vector2(200.0, 24.0)
		chip.cell = 17.0
		chip.max_n = 8          # 每块 23 像素（17＋6），200 宽放得下 8 块
		add_child(chip)
		_rows.append({"name": nm, "hp_txt": hpt, "hp_fill": fill, "rage_fill": rf, "st": stq, "chip": chip})

	_log_lb = _label("", 14, Color(INK.r, INK.g, INK.b, 0.80))
	_log_lb.position = Vector2(20, py - 150.0)
	_log_lb.size = Vector2(px - 240.0, 84)
	_log_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_log_lb)

	_result_lb = _label("", 64, SEAL)
	_result_lb.position = Vector2(0, py * 0.38)
	_result_lb.size = Vector2(px, 96)
	_result_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lb.visible = false
	add_child(_result_lb)

	_auto_lb = _label("", 20, Color(GREEN.r, GREEN.g, GREEN.b, 0.95))
	_auto_lb.position = Vector2(0, py * 0.38 + 112.0)
	_auto_lb.size = Vector2(px, 30)
	_auto_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_auto_lb.visible = false
	add_child(_auto_lb)

	_act_btn = Button.new()
	_act_btn.text = "撤退"
	_act_btn.position = Vector2(px - 200.0, py - 104.0)
	_act_btn.size = Vector2(180, 66)
	_act_btn.add_theme_font_size_override("font_size", 24)
	_act_btn.focus_mode = Control.FOCUS_NONE
	_act_btn.pressed.connect(_on_act)
	_style_btn(_act_btn, Color(0.21, 0.19, 0.20))
	add_child(_act_btn)

	# ㊿q：［回村·后台继续］——自动挑战开着才出现（见 _refresh_auto_ui）。
	#   跟［撤退］分开：撤退＝这一场算败、自动也停；这个＝人先回村，塔改后台估算接着推。
	#   位置：［撤退］正上方（x 同、y 差 78）——不压左下角的战报（战报右边界 px-220）。
	_bg_btn = Button.new()
	_bg_btn.text = "回村·后台继续"
	_bg_btn.position = Vector2(px - 200.0, py - 182.0)
	_bg_btn.size = Vector2(180, 70)
	_bg_btn.add_theme_font_size_override("font_size", 16)
	_bg_btn.focus_mode = Control.FOCUS_NONE
	_bg_btn.tooltip_text = "人回村，自动挑战不停：塔每 20 秒按估算往上推一关。\n（这一场还没打完就交给估算——它说能过才算过；回村面板里的［自动挑战］仍是总开关）"
	_bg_btn.pressed.connect(_on_bg_leave)
	_style_btn(_bg_btn, GREEN)
	_bg_btn.visible = false
	add_child(_bg_btn)

func _label(text: String, font_size: int, col: Color) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", col)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lb

func _flat(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	return sb

func _style_btn(btn: Button, base: Color) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(base.r, base.g, base.b, 0.95)))
	btn.add_theme_stylebox_override("hover", _flat(Color(base.r, base.g, base.b, 0.80)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(base.r * 0.75, base.g * 0.75, base.b * 0.75, 0.95)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.35)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
	btn.add_theme_color_override("font_disabled_color", Color(0.95, 0.92, 0.86, 0.45))

# ---- 自动挑战 ----

func _refresh_auto_ui() -> void:
	if _auto_btn == null:
		return
	if GameState.auto_climb:
		var n := int(Time.get_ticks_msec() / 350) % 4
		_auto_btn.text = "自动挑战中" + "·".repeat(n + 1) + "（点我关）"
		_style_btn(_auto_btn, GREEN)
	else:
		_auto_btn.text = "自动挑战：关（点我开）"
		_style_btn(_auto_btn, Color(0.21, 0.19, 0.20))
	# ㊿q：只在"自动开着、还没交出结果"时给［回村·后台继续］
	#   ⚠ 败了就不给：败退这一趟自动就到头了（村里会把自动关掉），留着这颗钮只会误导
	if _bg_btn != null:
		var bg_ok := GameState.auto_climb and not _done_sent and (not _over or _win)
		_bg_btn.visible = bg_ok
		_bg_btn.disabled = not bg_ok

func _refresh_auto_msg() -> void:
	if _auto_lb == null:
		return
	if _auto_t < 0.0:
		_auto_lb.visible = false
		return
	_auto_lb.visible = true
	var sec := int(ceil(_auto_t))
	var tail := "自动回村"
	if _win and stage_i + 1 < GameState.STAGE_MAX:
		tail = "自动前往第 " + str(stage_i + 2) + " 关"
	_auto_lb.text = "自动中…… " + str(sec) + " 秒后" + tail + "（点［停下］中断）"

func _start_countdown() -> void:
	# v38：快进也压这段"看完再走"的等待（2 秒 ×1 → ×4 时 0.5 秒）
	_auto_t = (AUTO_DELAY_WIN if _win else AUTO_DELAY_LOSE) / maxf(1.0, SPEED)
	_act_btn.text = "停下（回村）"
	_refresh_auto_msg()

# v38：［快进］按钮——×1 → ×2 → ×4 → ×1
func _on_speed_toggle() -> void:
	SPEED = next_speed(SPEED)
	print("[出村战斗] 快进 ×", SPEED)
	_refresh_speed_btn()
	# 正在倒计时的话，按新倍速重算剩下的时间（不然得等旧的那一份走完）
	if _auto_t > 0.0:
		var base := AUTO_DELAY_WIN if _win else AUTO_DELAY_LOSE
		_auto_t = minf(_auto_t, base / maxf(1.0, SPEED))

func _refresh_speed_btn() -> void:
	if _speed_btn == null:
		return
	_speed_btn.text = "快进 ×" + str(int(SPEED)) + "（点我切）"
	_style_btn(_speed_btn, GREEN if SPEED > 1.0 else Color(0.21, 0.19, 0.20))

func _on_auto_toggle() -> void:
	GameState.auto_climb = not GameState.auto_climb
	if not GameState.auto_climb:
		GameState.auto_bg = false   # ㊿q：关了就两种形态一起收
	print("[出村战斗] 自动挑战 = ", GameState.auto_climb)
	_refresh_auto_ui()
	if _over and not _done_sent:
		if GameState.auto_climb:
			_start_countdown()
		else:
			_auto_t = -1.0
			_act_btn.text = "回村"
			_refresh_auto_msg()

func _emit_done(w: bool) -> void:
	if _done_sent:
		return
	_done_sent = true
	_act_btn.disabled = true
	done.emit(w)

func _on_act() -> void:
	if _over:
		if _auto_t >= 0.0:
			GameState.auto_climb = false
			GameState.auto_bg = false
			print("[出村战斗] 点「停下」——自动挑战关")
			_refresh_auto_ui()
		_emit_done(_win)
	else:
		print("[出村战斗] 撤退")
		_emit_done(false)

# ㊿q：［回村·后台继续］——自动挑战开着时的"人先走，塔接着推"。
#   两种情形分开办：
#     · 这一场已经打完（_over）→ 结果照交（_emit_done，村里的清缴/败退结算不变），
#       只是多插一面旗 GameState.auto_bg = true（意思是"别再自动开下一场"）——人回村，
#       塔交给每 20 秒一次的挂机估算往上推（GameState._idle_climb）。
#     · 这一场还打着 → 输赢没定，不能瞎判。这一场既不算赢也不算败：发 left 让村里
#       把这场撤掉，塔停在**当前这一关**，由后台估算重新判一次（估不过就卡住，
#       等你回来自己打——所以它顶多慢，不会替你送掉已经能过的关）。
#   注意 left 和 done 是两个信号：done(false) 在村里是"败退"（会把自动关掉）。
func _on_bg_leave() -> void:
	if _done_sent:
		return
	GameState.auto_bg = true
	GameState.battle_live = false   # 屏幕这场撤了——后台估算可以接手这一关
	GameState._battle_seen = false  # 这一拍没有"接着要开的真仗"了，别让估算白等一拍
	print("[出村战斗] 回村·后台继续：打完没过=", _over, " 第 ", stage_i + 1, " 关 · 自动挑战留开")
	if _over:
		_emit_done(_win)
		return
	_done_sent = true
	_over = true
	if _act_btn != null:
		_act_btn.disabled = true
	if _bg_btn != null:
		_bg_btn.disabled = true
		_bg_btn.visible = false
	left.emit()

# ---- 背景 ----

func _tint_col() -> Color:
	var e := ELEM_PREVIEW_FORCE
	if e == "" and not _party.is_empty():
		e = Cards.elem_of(str(_party[0].get("weapon", "")))
	if e == "" or not ELEM_TINT.has(e):
		return Color(0, 0, 0, 0)
	return ELEM_TINT[e]

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_set_transform(_shake_off, 0.0, Vector2.ONE)
	var tint := _tint_col()
	var bg := PAPER
	var ground_c := Color(0.885, 0.850, 0.775)
	if tint.a > 0.0:
		bg = PAPER.lerp(tint, 0.16)
		ground_c = ground_c.lerp(tint, 0.12)
	draw_rect(Rect2(0, 0, w, h), bg)
	_ridge(w, h * 0.77, 96.0, Color(INK.r, INK.g, INK.b, 0.055), 640.0)
	_ridge(w, h * 0.77, 62.0, Color(INK.r, INK.g, INK.b, 0.095), 470.0)
	draw_rect(Rect2(0, h * 0.77, w, h - h * 0.77), ground_c)
	draw_line(Vector2(0, h * 0.77), Vector2(w, h * 0.77), Color(INK.r, INK.g, INK.b, 0.30), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _flash > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(_flash_col.r, _flash_col.g, _flash_col.b, _flash * 0.35))

func _ridge(w: float, base_y: float, hgt: float, col: Color, wave: float) -> void:
	var pts := PackedVector2Array()
	var x := -60.0
	while x <= w + 60.0:
		var y: float = base_y - hgt * (0.5 + 0.5 * sin(x * TAU / wave))
		pts.append(Vector2(x, y))
		x += 36.0
	pts.append(Vector2(w + 60.0, base_y))
	pts.append(Vector2(-60.0, base_y))
	draw_colored_polygon(pts, col)

# ---- 特效 ----

func _fx(kind: String, pos: Vector2, col: Color, dur := 0.42, r := 46.0, dir := 1.0) -> void:
	var f := Fx.new()
	f.kind = kind
	f.col = col
	f.dir = dir
	f.dur = dur
	f.r = r
	f.position = pos
	if _world != null:
		_world.add_child(f)
	else:
		add_child(f)

func _dust_at(x: float, y: float) -> void:
	_fx("dust", Vector2(x, y), Color(0.55, 0.50, 0.42), 0.5, 40.0, -1.0)

func _shake(a: float) -> void:
	_shake_amp = maxf(_shake_amp, a)

func _flash_now(col: Color, amt: float) -> void:
	_flash_col = col
	_flash = amt

func _fx_col(m: Dictionary) -> Color:
	var e := Cards.elem_of(str(m.get("weapon", "")))
	if e == "" or not ELEM_FX.has(e):
		return PHYS_FX
	return ELEM_FX[e]

# v61（用户："攻速和多段导致人物动画抽搐"）——**位移时长要跟着快进缩**。
#   病根：出手间隔是 STEP / SPEED（STEP 默认 0.72 秒 → 快进 ×4 时只有 0.18 秒），
#   而这三条位移一条要 0.28~0.33 秒。于是每一手新动作都会在上一条位移**演到一半**时
#   把它掐掉（move_seq 是"后来者赢"），人物就在"冲到一半 → 弹回站姿 → 再冲"之间来回抹，
#   看着就是抽搐。缩完以后一条位移稳稳落在两次出手之间，快进只让它更利落。
#   ⚠ 只缩**动画时长**；出手间隔那一条（_timer >= STEP / SPEED）不在这儿，别动。
#   ⚠ 保险：STEP 是可调的（tuning.cfg 的 combat.step）。万一有人把它调小、或把倍速调得更高，
#     位移又会顶到间隔外面去——所以这里再夹一道"总时长不得超过间隔的 70%"。
#     （STEP 调大时这一道自然不起作用，只取 max。）
func _anim_speed() -> float:
	var s := maxf(1.0, SPEED)
	var gap := maxf(0.06, float(STEP) / s)
	return maxf(s, 0.28 / (gap * 0.70))

# ㊿x：三个位移动作**一律起一条新的位移序列**（StickFighter.move_seq：先把上一条掐掉）。
#   以前每叫一次就新开一条补间，身法连击（一手里 2~3 下）＋多怪齐打同一个人时，
#   同一帧会开出好几条，每条都往 position:x 上写，每帧互相覆盖——那就是"角色抽搐"。
#   ⚠ 这里全是"发完就不管"的动画（没有 await），所以可以掐；游历那边 await 的
#     冲上去/退回来走 push_move_*（只接不掐），别混。
func _lunge(node, base_x: float, dx: float) -> void:
	if node == null:
		return
	var s := _anim_speed()
	var tw: Tween = node.move_seq()
	tw.tween_property(node, "position:x", base_x + dx, 0.10 / s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position:x", base_x, 0.18 / s)

func _knock(node, base_x: float, dx: float) -> void:
	if node == null:
		return
	var s := _anim_speed()
	var tw: Tween = node.move_seq()
	tw.tween_interval(0.08 / s)
	tw.tween_property(node, "position:x", base_x + dx, 0.09 / s)
	tw.tween_property(node, "position:x", base_x, 0.16 / s)

func _idle_bob(node) -> void:
	if node == null:
		return
	# ⚠ 这一条是**无限循环**的 y 补间，绝不能进位移队列（排进去就永远轮不到下一段）
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(node, "position:y", node.position.y - 2.2, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position:y", node.position.y, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _fall(node, dir: float) -> void:
	if node == null:
		return
	node.stop_moves()   # ㊿x：倒了就别再往前冲了
	var tw := create_tween()
	tw.tween_property(node, "rotation", 1.35 * dir, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "modulate", Color(0.55, 0.55, 0.55, 0.62), 0.5)

# ---- 出场 ----

# ㉝ 站位（排）规则——两套战斗共用同一套口径
#
# 排号 0 = 最前排（离对面最近），1 = 中排，2 = 后排。
# 我方：_party 的数组顺序就是排号（第 0 位站最前、也最先出手）。
# 敌方：数组顺序就是排号（第 0 位最前）。
#
# 就三条，没有更多花样：
#   ① 普攻只打对面**最靠前的、还活着的那一排**——前排替后排挡刀。
#   ② 技能/大招可以越过前排（原本就是"特殊效果"）：
#        怪的技能够到中排，大招够到后排；敌字典写 "reach": 0/1/2 可覆写。
#   ③ 最前排死光了，最靠前的活人自动成为新的"前排"——不会出现没人可打。
#
# 为什么不做"兵器距离"：原先还按长枪/匕首分够到第几排，太绕、玩家看不见摸不着。
#   越前排的能力改由**怪自己的字段/词缀**决定（见 data_affixes 的 "pierce"），
#   玩家这边普攻一律只打前排——规则少一条，好懂也好调。
# ============================================================

const ROW_FRONT := 0
const ROW_MID := 1
const ROW_BACK := 2

# 某人在自己这一侧的排号
func _row_of(side: String, idx: int) -> int:
	if side == "foe":
		return clampi(idx, 0, ROW_BACK)
	return clampi(idx, 0, ROW_BACK)

# 对面某个排号是否"暴露"——即它前面（更靠前）的排都死光了
func _row_exposed(units: Array, idx: int) -> bool:
	var r := clampi(idx, 0, ROW_BACK)
	for i in idx:
		var u: Dictionary = units[i]
		if _row_of("x", i) < r and int(u.get("hp", 0)) > 0:
			return false
	return true

# 对面最靠前的排号（活着的那些里最小的）；没人活着返回 -1
func _front_most_row(units: Array) -> int:
	for i in units.size():
		var u: Dictionary = units[i]
		if int(u.get("hp", 0)) > 0:
			return _row_of("x", i)
	return -1

# 挑目标：reaches = 这个效果能够到的最远排号（0/1/2）。
#   · 只挑"够得着、而且前面没人挡"的活人
#   · 没人够得着 → 兜底打最前面那个活人（宁可够得着，也别空过一手）
func _pick_target(units: Array, reaches: int, bypass := false) -> Dictionary:
	var pool: Array = []
	for i in units.size():
		var u: Dictionary = units[i]
		if int(u.get("hp", 0)) <= 0:
			continue
		if _row_of("x", i) > reaches:
			continue
		if not bypass and not _row_exposed(units, i):
			continue
		pool.append(u)
	if pool.is_empty():
		# 兜底：够不着任何"暴露"的目标，就打最前面的活人
		for i in units.size():
			var u2: Dictionary = units[i]
			if int(u2.get("hp", 0)) > 0 and _row_of("x", i) == _front_most_row(units):
				pool.append(u2)
	if pool.is_empty():
		return {}
	# ㊿：截后（cutoff）——够得着的人里专挑**站得最靠后**的那个（不按"打最近的"）
	if bypass and _e_affixes().has("cutoff"):
		var best: Dictionary = {}
		for u3 in pool:
			if best.is_empty() or float((u3 as Dictionary).get("base_x", 0.0)) < float(best.get("base_x", 0.0)):
				best = u3
		if not best.is_empty():
			return best
	return pool[randi() % pool.size()]

# 普攻的够到距离：玩家一律 0（只打前排）——越前排靠怪自己的字段/词缀，
# 不再按手里是什么兵器分（那一版太绕，已撤）。
func _member_reach(_m: Dictionary) -> int:
	return 0

func _foe_reach() -> int:
	# 怪的普攻默认只打前排；写了 "reach"（或带"破前/偷袭/截后"词缀）才能越过前排
	var base := clampi(int(_e().get("reach", 0)), 0, ROW_BACK)
	if _e_affixes().has("pierce"):
		base = maxi(base, ROW_MID)
	if _e_affixes().has("ambush") or _e_affixes().has("cutoff"):
		base = maxi(base, ROW_BACK)
	return base

# ㊿：这只怪的普攻能不能破"前排挡刀"那道闸（词缀专有的特权；点名招式走各自的 bypass）
func _foe_pierce_shield() -> bool:
	var af := _e_affixes()
	return af.has("pierce") or af.has("ambush") or af.has("cutoff")

func _spawn_fighters() -> void:
	var px := size.x
	for i in _party.size():
		var m: Dictionary = _party[i]
		var n = StickFighter.new()
		var wid := str(m["weapon"])
		if wid == "":
			wid = "fist"
		n.set_equipment(wid, "douli", "short")
		# ㉝：站位有讲究了——第 0 位在最前（离敌人最近），越靠后站得越远
		var bx := px * 0.30 - float(i) * 58.0
		var by := _ground_y
		n.position = Vector2(bx - 150.0, by)
		n.modulate.a = 0.0
		_world.add_child(n)
		m["node"] = n
		m["base_x"] = bx
		m["base_y"] = by
		m["row"] = _row_of("player", i)
		var tw := create_tween()
		tw.tween_property(n, "modulate:a", 1.0, 0.2)
		# ㊿x：入场那 0.55 秒也起一条位移序列——万一第一手来得早，
		#   新动作会把它掐掉接手（而不是两条补间同时抢 position:x，那就是开场抽搐）
		var mtw: Tween = n.move_seq()
		mtw.tween_property(n, "position:x", bx, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_dust_at.bind(bx, by))
		_idle_bob(n)
	# ㊸：敌人上多人——每人一个节点，按下标排（0 最前、越后排越靠画面中央）
	var ex := px * 0.72
	_foe_nodes.clear()
	for i in _foes.size():
		var f: Dictionary = _foes[i]
		var en = StickFighter.new()
		en.set_equipment(str(f.get("weapon", ENEMY_WEAPON)), "douli", "short")
		var sc := maxf(0.5, float(f.get("scale", 1.0)))
		if bool(_e().get("boss", false)) and i == 0:
			sc *= 1.15
		en.scale = Vector2(-sc if ENEMY_FLIP else sc, sc)
		var ecol: Array = f.get("color", [])
		if ecol.size() >= 3:
			en.body_color = Color(float(ecol[0]), float(ecol[1]), float(ecol[2]))
		var slot := _foe_slot_x(ex, i)
		en.position = Vector2(slot + 200.0, _ground_y)
		en.modulate.a = 0.0
		_world.add_child(en)
		_foe_nodes.append(en)
		var tw2 := create_tween()
		tw2.tween_property(en, "modulate:a", 1.0, 0.3)
		var etw: Tween = en.move_seq()   # ㊿x：同上，入场起位移序列
		etw.tween_property(en, "position:x", slot, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.tween_callback(_dust_at.bind(slot, _ground_y))
		_idle_bob(en)
	_focus_on(0)
	if GameState.pet_passive_pct() > 0:
		_pet = PetMark.new()
		_pet.position = Vector2(-90.0, _ground_y - 2.0)
		_pet.modulate.a = 0.0
		_world.add_child(_pet)
		var tw3 := create_tween()
		tw3.tween_property(_pet, "modulate:a", 1.0, 0.18)
		tw3.tween_property(_pet, "position:x", px * 0.30 + 92.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw3.tween_property(_pet, "position:y", _ground_y - 20.0, 0.12)
		tw3.tween_property(_pet, "position:y", _ground_y - 2.0, 0.16)

# ---- 自动回合 ----

func _process(delta: float) -> void:
	if _shake_amp > 0.0:
		_shake_amp = maxf(0.0, _shake_amp - delta * SHAKE_DECAY)
		_shake_off = Vector2(randf_range(-_shake_amp, _shake_amp), randf_range(-_shake_amp, _shake_amp) * 0.55)
	elif _shake_off != Vector2.ZERO:
		_shake_off = Vector2.ZERO
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.4)
	if _world != null:
		_world.position = _shake_off
	queue_redraw()
	if not _done_sent:
		var n := int(Time.get_ticks_msec() / 350) % 4
		if n != _dot_n:
			_dot_n = n
			_refresh_auto_ui()
	if _info_open:
		return   # v8：看招面板开着——不走回合
	if _over:
		if _auto_t >= 0.0:
			_auto_t -= delta
			_refresh_auto_msg()
			if _auto_t <= 0.0:
				_auto_t = -1.0
				if _auto_lb != null:
					_auto_lb.visible = false
				_emit_done(_win)
		return
	_timer += delta
	# v38：快进——出手间隔按倍速缩（STEP 是"一手多少秒"）
	if _timer >= STEP / SPEED:
		_timer = 0.0
		_act()

# ㊶：出手顺序按"速度"排（在此之前速度在爬塔里一处都没用到，堆速度等于白堆）。
#
# 一轮 = 所有活着的人 + 敌人各出手一次；谁先谁后看速度，快的先动。
#   · 队员之间：按 spd 降序（同速按站位前后）
#   · 敌人在哪个位置：拿它的 spd 跟队员比，插到该在的地方
#   · 站位（谁在前排）**不受影响**——那是"挨打顺序"，跟"出手顺序"是两件事。
#     （以前两者是同一个顺序，现在拆开了：站位管挡刀，速度管先手。）
# 这是"现算"的，所以每轮都会跟着速度变化重排，不需要维护状态。
func _turn_order() -> Array:
	var idxs: Array = []
	for i in _party.size():
		if int((_party[i] as Dictionary)["hp"]) > 0:
			idxs.append(i)
	idxs.sort_custom(func(a: int, b: int) -> bool:
		# v52：「迟缓」按现算的速度排（不是改 m.spd——那会跟加持/还原打架）
		var sa := float((_party[a] as Dictionary).get("spd", 10.0)) * St.spd_mul(_party[a])
		var sb := float((_party[b] as Dictionary).get("spd", 10.0)) * St.spd_mul(_party[b])
		if not is_equal_approx(sa, sb):
			return sa > sb
		return a < b)
	# ㊸：敌人也上多人——每个活着的敌人各占一个出手位（带各自 spd）
	var actors: Array = []
	for i in idxs:
		actors.append({"k": str(i), "s": float((_party[i] as Dictionary).get("spd", 10.0)) * St.spd_mul(_party[i])})
	for i in _foes.size():
		if _foe_alive(i):
			actors.append({"k": "e" + str(i), "s": float(int((_foes[i] as Dictionary).get("spd", 100))) * St.spd_mul(_foes[i])})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["s"]), float(b["s"])):
			return float(a["s"]) > float(b["s"])
		return str(a["k"]) < str(b["k"]))
	var order: Array = []
	for a in actors:
		order.append(str((a as Dictionary)["k"]))
	return order

func _act() -> void:
	# ============================================================
	# v12（用户："爬塔时有时候 对手血量清空了 会卡住不动"）：**收场总闸**。
	#   病根：敌人有几条"死在别人手里"的路——最典型的是**反刺**（怪打人时被反死，
	#   见 _enemy_act 尾部与 _enemy_hit_member 的反刺那两段）。那两条路原来只判
	#   "我方死没死"，**从不判敌人死没死**；而 _member_act 又在"没有活着的敌人"时
	#   提前 return（want < 0 → return）——于是"杀完了就收摊"那一句永远走不到：
	#   双方干站着，血条 0/499，一帧一帧空转（正是玩家截图里那一幕）。
	#   这里放一道总闸：不管血是谁扣的，只要**敌人已清空 / 我方已全灭**，当场收摊。
	#   （口径与 _member_act 收尾那句一致：敌人清完 ＋ 我方还有人 ＝ 胜；两边同时倒 ＝ 败。）
	# ============================================================
	if not _over:
		if _foes_alive() <= 0:
			_enemy_fall_pending()
			_end(_party_alive() > 0)
			return
		if _party_alive() <= 0:
			_end(false)
			return
	# ㊿：出手顺序**一轮算一次**（存 _act_order），不是每个动作都重算。
	#   原先每调一次 _act() 都重算顺序、却拿一个全局游标 _turn 去取——只要顺序
	#   中途变了（比如刚放了「疾风令」加速），游标就指到别人身上：有人连出两手、
	#   有人这一轮轮空。游历那边本来就是"每轮重算"，这里对齐它。
	if _act_order.is_empty() or _turn >= _act_order.size():
		_act_order = _turn_order()
		# ㊿z7：专武·长风诀的"大招连发窗口"按**回合**走——每到回合头，各人窗口减 1
		for mm in _party:
			var d: Dictionary = mm
			if int(d.get("ult_chain_left", 0)) > 0:
				d["ult_chain_left"] = int(d["ult_chain_left"]) - 1
		_turn = 0
	if _act_order.is_empty():
		return
	var key := str(_act_order[_turn])
	_turn = (_turn + 1) % _act_order.size()
	if not key.begins_with("e"):
		var m: Dictionary = _party[int(key)]
		if int(m["hp"]) <= 0:
			return
		# v52：状态结算——**在他自己出手之前**（掉血 + 时长递减）。
		#   "震慑"要在结算**之前**看一眼：那一手要是被震慑，结算就会把它的时长减掉，
		#   减完再判就成了"震慑永远不生效"（差一步的坑）。
		var mskip := St.skips(m)
		var mlines: Array = []
		var mdead := _st_tick(m, int(m["max"]), mlines, float(m["base_x"]))
		if mdead:
			_fall(m["node"], -1.0)
			_dust_at(float(m["base_x"]), _ground_y)
			mlines.append(str(m["name"]) + " 倒下了。")
			_push(mlines)
			_refresh()
			_check_party_dead()
			return
		if mskip:
			_center_move(str(m["name"]) + " 心神被夺", ART_GUARD_COL)
			# ⚠ 顺序：先写"这一手没出"，再把结算那几行接在后面——
			#   反过来的话战报会读成"状态散了，然后他才被震慑"，时序看着是错的。
			var msk: Array = [str(m["name"]) + " 被震慑——这一手整个没使出来。"]
			msk.append_array(mlines)
			_push(msk)
			_refresh()
			_tick_bless(m)
			return
		if not mlines.is_empty():
			_push(mlines)
		_member_act(m)
		_tick_bless(m)   # ㊿：加持按"自己的手"计数——本人出手完再减 1
	else:
		var fi := int(key.substr(1))
		if not _foe_alive(fi):
			return
		_focus_on(fi)
		# v52：首领这边同理（结算 → 震慑跳手 → 出手）
		var eskip := St.skips(_e())
		var elines: Array = []
		var edead := _st_tick(_e(), _e_max(), elines, _enemy_base_x())
		if edead:
			_enemy_fall_pending()
			elines.append(str(_e()["name"]) + " 倒下了。")
			_push(elines)
			_refresh()
			# 与 _member_act 收尾同一口径：先看敌人是不是清完了，再看我方还剩几个
			#   （两边同时倒＝判我方输——以前这条支路没走过，所以这里要自己写全）
			if _foes_alive() <= 0:
				var alive3 := 0
				for m3 in _party:
					if int(m3["hp"]) > 0:
						alive3 += 1
				_end(alive3 > 0)
			return
		if eskip:
			var esk: Array = [str(_e()["name"]) + " 被震慑——这一手整个没使出来。"]
			esk.append_array(elines)
			_push(esk)
			_refresh()
			return
		if not elines.is_empty():
			_push(elines)
		_enemy_act()

# ㊿z：这个人此刻的暴击率（百分点）——含角色星「猎影」：对手残血 +N
# v58：这一名队员此刻手里那把兵器的**元素**（空串＝物理）。
#   走 GameState.elem_of_card（表里写死的功法元素优先 → 兵器的随机元素 → 物理）。
func _member_elem(m: Dictionary) -> String:
	return GameState.elem_of_card(str(m.get("weapon_id", "")))

# v58：这一手还要补多少增伤（百分点）——`atk` 里已经含**全伤害**，这里只补另一半：
#   物理＝物理伤害%；元素＝该元素伤害%。两者相加再乘，不重复计全伤害那一份。
func _elem_bonus_pt(m: Dictionary, mel: String) -> float:
	return float(m.get(Elem.dmg_key(mel), 0.0))

# v58（用户第 6 条）：这一手跟手里那把**合不合**。
#   塔这边普攻不带武学元素（`art_elem` 传空），所以恒返回 1.0；
#   留这个口是给"以后塔里也要走武学元素"用的——两套引擎一个签名，省得将来两处口径打架。
# v58：飘字用的属性名（空串 -> "phys"）。见 _foe_elem_mark 上面那段说明。
func _member_elem_mark(m: Dictionary) -> String:
	var e := _member_elem(m)
	return "phys" if e == "" else e

func _art_fit(m: Dictionary, art_elem: String) -> float:
	if art_elem == "":
		return 1.0
	return Elem.art_fit(_member_elem(m), art_elem)

func _crit_chance(m: Dictionary, foe_low: bool) -> float:
	var c := float(m.get("crit", 5.0))
	if foe_low:
		c += float(m.get("star_crit_low", 0.0))
	return c

# ㊿z：这个人的暴击倍率——**暴击伤害现在是真属性**：
#   1.0 + 暴击伤害/100（面板上那个数），再乘角色星「凝息」的 crit_mul_up。
#   ⚠ 这里以前是写死的 1.6；现在默认暴伤 50 → 1.5 倍（略低一点，总量差不到 1%）。
func _crit_mul(m: Dictionary) -> float:
	var base := 1.0 + float(m.get("crit_dmg", 50.0)) / 100.0
	return base * (1.0 + float(m.get("star_critmul", 0.0)))

# 目标是不是残血（不足一半）——"点名"已经切过去了，所以读 _e_* 就是目标那只
func _foe_below_half() -> bool:
	return _e_hp() * 2 <= _e_max()

func _member_act(m: Dictionary) -> void:
	var n = m["node"]
	var bx := float(m["base_x"])
	# ㊸：先按"打哪儿"定目标——普攻只打最前排；带 row_prio="back" 的自打后排。
	#   定完就把聚焦切过去，后面所有 _e_* 访问器都跟着这只走。
	var want := _enemy_attack_index(m)
	if want < 0:
		return
	_focus_on(want)
	var ex := float(_enemy_base_x())
	# 目标节点的位置可能跟"基准位"略有差别，以节点实际 x 为准（动画才对得上）
	var tn = _enemy_node()
	if tn != null and is_instance_valid(tn):
		ex = tn.position.x
	var col := _fx_col(m)
	var lines: Array = []
	# v9：被电盾电麻——跳过这一手
	if int(m.get("stun", 0)) > 0:
		m["stun"] = int(m["stun"]) - 1
		_center_move(str(m["name"]) + " 手上一麻", ART_GUARD_COL)
		_push([str(m["name"]) + " 被电得手麻——这一手落空。"])
		_refresh()
		return
	# v9：中毒（词缀·毒刃）——每手先掉血
	if int(m.get("poison", 0)) > 0:
		var pdd := maxi(1, int(round(float(m["max"]) * Affixes.POISON_PCT() * float(m["poison"]))))
		m["hp"] = maxi(0, int(m["hp"]) - pdd)
		_fx("hit", Vector2(bx, _ground_y - 92.0), Color(0.42, 0.62, 0.30), 0.4, 34.0)
		_float_at(Vector2(bx, _ground_y - 150.0), "毒 -" + str(pdd), Color(0.42, 0.62, 0.30), 20)
		lines.append(str(m["name"]) + " 毒发：" + str(pdd) + "（" + str(m["poison"]) + " 层）")
		if int(m["hp"]) <= 0:
			_fall(n, -1.0)
			_dust_at(bx, _ground_y)
			lines.append(str(m["name"]) + " 倒下了。")
			_push(lines)
			_refresh()
			_check_party_dead()
			return
	m["acts"] = int(m["acts"]) + 1
	# ㊿：加持回春（回春令）——每手开头先回一口
	# v53：「封脉」把这一口压到三成
	if float(m.get("bless_regen", 0.0)) > 0.0 and int(m["hp"]) > 0:
		var bh := maxi(1, int(round(float(m["max"]) * float(m["bless_regen"]) * St.heal_mul(m))))
		m["hp"] = mini(int(m["max"]), int(m["hp"]) + bh)
		_fx("heal", Vector2(bx, _ground_y - 8.0), GREEN, 0.7, 44.0)
		_float_at(Vector2(bx, _ground_y - 148.0), "回春 +" + str(bh), GREEN, 20)
		lines.append(str(m["name"]) + " 回春 +" + str(bh))
	# ㊿：加持聚气（聚气令）——怒气获取加成
	# v53：「挫锐」——怒气获取只剩四成（乘进来，与加持那条同口径）
	m["rage"] = int(m["rage"]) + int(round(RAGE_GAIN * RAGE_MUL * float(m.get("rage_mul", 1.0))
		* (1.0 + float(m.get("bless_rage", 0.0))) * St.rage_mul(m)))
	if int(m.get("art_cd", 0)) > 0:
		m["art_cd"] = int(m["art_cd"]) - 1
	# v9：枪势在身——每手回气
	# v52/v53：「封脉」把回血压到三成（口子还开着，但灌不进去）
	if int(m.get("ult_turns", 0)) > 0 and float(m.get("ult_regen", 0.0)) > 0.0:
		var urh := maxi(1, int(round(float(m["max"]) * float(m["ult_regen"]) * St.heal_mul(m))))
		m["hp"] = mini(int(m["max"]), int(m["hp"]) + urh)
		_fx("heal", Vector2(bx, _ground_y - 8.0), GREEN, 0.7, 44.0)
		_float_at(Vector2(bx, _ground_y - 148.0), "+" + str(urh), GREEN, 20)
		lines.append(str(m["name"]) + " 枪势回气 +" + str(urh))
	var arts: Array = m.get("arts", [])
	# ㊸：ex（打哪儿）已在上面按目标定好了——聚焦也切到那一只了，这里直接用
	# v53：出手三选一的三道"封"都在这一串条件里，玩家手里**永远还剩一条路**：
	#   · 封招（block_ult）→ 怒气留着但放大招那一支跳过，往下走武学/普攻
	#   · 沉默（block_arts）→ 武学那一支跳过，往下走自带技/普攻
	#   · 缴械（block_plain）→ 见下面那一支：普攻改成格挡
	if int(m["rage"]) >= 100 and not St.blocks_ult(m):
		m["rage"] = 0
		_member_ult(m, n, bx, ex, col, lines)
	elif arts.size() > 0 and int(m.get("art_cd", 0)) <= 0 and not St.blocks_arts(m):
		_use_art(m, arts, n, bx, ex, col, lines)
	elif int(m["acts"]) % TECH_EVERY == 0:
		var heal2 := maxi(1, int(round(float(m["max"]) * TECH_HEAL * St.heal_mul(m))))
		m["hp"] = mini(int(m["max"]), int(m["hp"]) + heal2)
		_center_move("『" + str(m["tech"]) + "』", GREEN)
		_fx("heal", Vector2(bx, _ground_y - 8.0), GREEN, 0.8, 48.0)
		_float_at(Vector2(bx, _ground_y - 152.0), "+" + str(heal2), GREEN, 24)
		_bob_only(n, bx)
		lines.append(str(m["name"]) + " 施『" + str(m["tech"]) + "』：回气 +" + str(heal2))
	elif St.blocks_plain(m):
		# v52：「缴械」——兵器被磕飞，这一手**普攻使不出来**（武学与大招照放，见上面两支；
		#   两手都空就改成格挡：白挨一手，比"照打不误"讲得通）
		_center_move(str(m["name"]) + " 兵器脱手", ART_GUARD_COL)
		_fx("guard", Vector2(bx, _ground_y - 62.0), ART_GUARD_COL, 0.7, 44.0)
		_float_at(Vector2(bx, _ground_y - 152.0), "缴械", St.col_of("disarm"), 20)
		lines.append(str(m["name"]) + " 兵器被打落——这一手只能格挡。")
	else:
		var nmul := 1.0
		var pend := float(m.get("next_mult", 0.0))
		if pend > 0.0:
			nmul = pend
			m["next_mult"] = 0.0
		var crit2 := randf() * 100.0 < _crit_chance(m, _foe_below_half())
		var dmg2 := maxi(1, int(round(float(m["atk"]) * DMG_MUL * nmul * randf_range(0.85, 1.15))))
		# v58（用户第 3、4 条）：这一手走物理还是五行——由手里那把兵器的元素决定。
		#   · 元素：再乘通道底倍率 ELEM_BASE(0.8)
		#   · 增伤：`atk` 里已经含**全伤害**那一份，这里只补"物理 / 该元素"那一份
		#   · **元素不可暴击**：crit2 直接抹掉
		var mel := _member_elem(m)
		dmg2 = int(round(float(dmg2) * Elem.channel_mul(mel)
			* (1.0 + _elem_bonus_pt(m, mel) / 100.0)))
		# v58（用户第 6 条）：武学写了元素、跟手里那把不合 → 倍率 ×0.70
		dmg2 = int(round(float(dmg2) * _art_fit(m, "")))
		if not Elem.can_crit(mel):
			crit2 = false
		if crit2:
			dmg2 = int(round(float(dmg2) * _crit_mul(m)))
		dmg2 = _e_take(dmg2, m)
		_ex_thorn_gain(m)   # ㊿z6：普攻命中也算"击中一名敌人"
		_lunge(n, bx, LUNGE_OUT)
		_fx("slash", Vector2(ex - 38.0, _ground_y - 92.0), col, 0.34, 44.0, 1.0)
		_fx("hit", Vector2(ex, _ground_y - 92.0), col, 0.36, 34.0)
		_knock(_enemy_node(), ex, -18.0)
		_shake(7.0)
		var tail := ""
		if nmul > 1.0:
			tail = "（蓄势 ×" + str(snappedf(nmul, 0.1)) + "）"
		if crit2:
			tail += "（暴击！）"
		_float_at(Vector2(ex, _ground_y - 158.0), "-" + str(dmg2), SEAL if crit2 else INK, 26 if crit2 else 24, _member_elem_mark(m))
		lines.append(str(m["name"]) + " 出手：" + str(dmg2) + tail)
		# ㊿：速度 → 攻速（只加普攻）：快过这只怪一倍就再补一下，最多两下
		var extra_n := GameData.extra_attacks(float(m.get("spd", 10)), float(_e()["spd"]))
		if extra_n > 0 and _e_hp() > 0:
			_float_at(Vector2(bx, _ground_y - 196.0), "身法快出一截", GOLD, 20)
			for xk in extra_n:
				if _e_hp() <= 0:
					break
				var xd := maxi(1, int(round(float(m["atk"]) * DMG_MUL * randf_range(0.85, 1.15))))
				var xcrit := randf() * 100.0 < _crit_chance(m, _foe_below_half())
				if xcrit:
					xd = int(round(float(xd) * _crit_mul(m)))
				xd = _e_take(xd, m)
				_ex_thorn_gain(m)   # ㊿z6：连击每一下也算
				_lunge(n, bx, LUNGE_OUT * 0.8)
				_fx("slash", Vector2(ex - 34.0, _ground_y - 88.0), col, 0.28, 40.0, 1.0)
				_lunge(_enemy_node(), _enemy_base_x(), -14.0)
				_float_at(Vector2(ex, _ground_y - 150.0), "-" + str(xd), SEAL if xcrit else INK, 22, _member_elem_mark(m))
				lines.append("　连击（身法）：" + str(xd) + ("（暴击！）" if xcrit else ""))
		# v9：剑歌窗口——暴击追剑
		# v46（用户："苏的被动暴击追击是只要暴击就追击，释放技能和大招也是哈"）：
		#   这一块从"只在普攻里"抽成了 _song_follow()，武学与大招那两条路也调它。
		if crit2:
			_song_follow(m, n, bx, ex, col, lines)
	# v9：大招窗口计时（刚放的那手不计）
	if bool(m.get("ult_new", false)):
		m["ult_new"] = false
	elif int(m.get("ult_turns", 0)) > 0:
		m["ult_turns"] = int(m["ult_turns"]) - 1
	_push(lines)
	# ㊹：先把这一手里倒下的敌人补上倒地/自爆动画（逐只、只演一次），再判胜负
	_enemy_fall_pending()
	# ㊸：胜负按"所有敌人是不是都倒了"判（以前只看那一只）
	if _foes_alive() <= 0:
		_refresh()
		var alive2 := 0
		for m2 in _party:
			if int(m2["hp"]) > 0:
				alive2 += 1
		if alive2 <= 0:
			_end(false)
		else:
			_end(true)
		return
	_refresh()

# 全部敌人倒下时：逐个补自爆与倒地动画
func _enemy_death_all() -> void:
	_enemy_fall_pending()

# ㊹：逐只补倒地/自爆动画。多人上场后经常"只倒一两只"，不能等全灭才演。
#   用每只自己的 "downed" 标记保证只演一次——全灭那条路也走这里，不会重复炸。
func _enemy_fall_pending() -> void:
	for i in _foes.size():
		var f: Dictionary = _foes[i]
		if int(f.get("hp", 0)) > 0 or bool(f.get("downed", false)):
			continue
		f["downed"] = true
		_focus_on(i)
		_set_e_hp(0)
		_enemy_bomb()
		var en = _enemy_node()
		if en != null and is_instance_valid(en):
			_fall(en, -1.0)

# ---- v9：角色大招（三分支） ----

func _member_ult(m: Dictionary, n, bx: float, ex: float, col: Color, lines: Array) -> void:
	var uk := str(m.get("ult_kind", "hit"))
	_center_move("『" + str(m["ult"]) + "』", SEAL)
	_lunge(n, bx, LUNGE_OUT * 1.3)
	m["ult_new"] = true
	if uk == "hit":
		var crit := randf() * 100.0 < _crit_chance(m, _foe_below_half())
		var mult := float(m.get("ult_mult", ULT_MUL))
		# ㊿z7：专武·长风诀——窗口还在时，这一发大招再 +30%（放完再续窗口，见本函数收尾）
		if int(m.get("ult_chain_left", 0)) > 0 and float(m.get("ex_chain_up", 0.0)) > 0.0:
			mult = mult * (1.0 + float(m["ex_chain_up"]))
			_float_at(Vector2(bx, _ground_y - 206.0), "长风不断 +" + str(int(round(float(m["ex_chain_up"]) * 100.0))) + "%", GOLD, 20)
		var is_sweep_ult := str(m.get("ult_target", "front")) == "sweep"
		var alive_now := _foes_alive()
		# ㊺：群攻大招只在"对手不止一个"时才横扫；只剩一个就转单体重击，
		#   倍率改用 mult_single（主角是 2.8）——不然人少时等于自己打自己六折。
		var solo := float(m.get("ult_mult_single", 0.0))
		if is_sweep_ult and alive_now <= 1 and solo > 0.0:
			mult = solo
		# ㊹：群攻大招（"target": "sweep"）——对所有还站着的敌人各来一下。
		#   暴击/伤害按一发算，落点各自不同；倒地动画交给 _enemy_fall_pending()。
		if is_sweep_ult and alive_now > 1:
			var ebase := size.x * 0.72
			var hits: Array = []
			var k_hit := 0
			for i in _foes.size():
				if not _foe_alive(i):
					continue
				_focus_on(i)
				var exi := _foe_slot_x(ebase, i)
				# ㊿z8：**每一名**中招的对手都算一层（第一个也吃 +6%，第二个 +12%，第三个 +18%）
				var per := float(m.get("ex_ult_per_hit", 0.0))
				k_hit += 1
				var mult_k := mult * (1.0 + per * float(k_hit))
				var d1 := maxi(1, int(round(float(m["atk"]) * mult_k * DMG_MUL * randf_range(0.9, 1.1))))
				if crit:
					d1 = int(round(float(d1) * _crit_mul(m)))
				d1 = _e_take(d1, m)
				_ex_thorn_gain(m)   # ㊿z6：每击中一名敌人，反刺累计 +10%
				# v52：大招带 apply（写在角色大招数据里；现在还没有人带，管子先接通）
				_st_art_foe(m.get("ult_apply", {}), lines, exi)
				_fx("slash", Vector2(exi - 34.0, _ground_y - 96.0), col, 0.34, 46.0, 1.0)
				_fx("hit", Vector2(exi, _ground_y - 92.0), SEAL, 0.42, 40.0)
				_float_at(Vector2(exi, _ground_y - 158.0), "-" + str(d1), SEAL, 26, _member_elem_mark(m))
				hits.append(str((_foes[i] as Dictionary).get("name", "敌")) + " " + str(d1))
			_shake(16.0)
			_flash_now(SEAL, 0.6)
			# 倒地动画统一交给本手收尾处的 _enemy_fall_pending()——
			# 这样"横扫"的战报先出，自爆/倒地的消息后出，顺序跟以前一致。
			var back := _front_foe()
			if back >= 0:
				_focus_on(back)
			lines.append(str(m["name"]) + " 放出『" + str(m["ult"]) + "』——横扫全场：" + "、".join(PackedStringArray(hits)))
			# ㊿z8：**收势也要开连发窗口**——见 _ex_chain_arm 的注释（这一支原来直接 return 走了，
			#   于是"打多人时放完大招"根本开不出窗口：只有打单人才生效，跟设计不符）
			_ex_chain_arm(m)
			# v46：大招暴击也追剑（这一发是对全场的一次掷点，追击落在聚焦的那一只身上）
			if crit:
				_song_follow(m, n, bx, ex, col, lines)
			return
		var dmg := maxi(1, int(round(float(m["atk"]) * mult * DMG_MUL * randf_range(0.9, 1.1))))
		if crit:
			dmg = int(round(float(dmg) * _crit_mul(m)))
		dmg = _e_take(dmg, m)
		_ex_thorn_gain(m)   # ㊿z6：大招命中也算"击中一名敌人"
		# v52：大招带 apply（同上）
		_st_art_foe(m.get("ult_apply", {}), lines, ex)
		_fx("wave", Vector2(ex - 6.0, _ground_y - 96.0), col, 0.62, 150.0, 1.0)
		_fx("hit", Vector2(ex, _ground_y - 92.0), SEAL, 0.5, 60.0)
		_knock(_enemy_node(), ex, -28.0)
		_shake(16.0)
		_flash_now(SEAL, 0.6)
		_float_at(Vector2(ex, _ground_y - 160.0), "-" + str(dmg), SEAL, 30, _member_elem_mark(m))
		# ㊺：横扫落到单体时，把"为什么这一下这么重"写清楚
		var tail1 := "——单体重击" if (is_sweep_ult and mult > float(m.get("ult_mult", ULT_MUL))) else ""
		lines.append(str(m["name"]) + " 放出『" + str(m["ult"]) + "』" + tail1 + "：" + str(dmg) + ("（暴击！）" if crit else ""))
		# ㊿z8：**撤了**"对单人时大招后回怒 20%"（设计改掉了）——`ult_back_rage` 这条
		#   数据已从 data_cards 里删掉，这里不再读；键还在自检表里备着，将来要用再加回来。
		# ㊿z7：专武·长风诀——**放完大招后三回合内再放大招，那一下再 +20%**
		#   窗口按"回合"数：这里设 turns+1（含当前这个不完整的回合），
		#   每过一个回合由 _act() 的回合头统一减 1。
		_ex_chain_arm(m)
		# v46：大招暴击也追剑（用户："释放技能和大招也是哈"）
		if crit:
			_song_follow(m, n, bx, ex, col, lines)
		return
	if uk == "aura":
		m["ult_turns"] = int(m.get("ult_turns_max", 3))
		m["ult_thorn_on"] = true   # ㉙：枪势窗开
		_fx("guard", Vector2(bx, _ground_y - 62.0), ART_GUARD_COL, 1.0, 60.0)
		_float_at(Vector2(bx, _ground_y - 152.0), "枪势起", ART_GUARD_COL, 22)
		lines.append(str(m["name"]) + " 放出『" + str(m["ult"]) + "』：枪势起——此后 " + str(int(m.get("ult_turns_max", 3))) + " 手回气，挨打反刺（按气血上限 8~12%）")
		return
	if uk == "song":
		m["ult_turns"] = int(m.get("ult_turns_max", 3))
		# ㊿y：角色星「引吭/出岫」——追剑段数（1 + 星给的段数）
		m["ult_follow_hits"] = 1 + int(m.get("star_follow", 0))
		_fx("wind", Vector2(bx, _ground_y - 92.0), ART_DASH_COL, 0.8, 80.0, 1.0)
		_float_at(Vector2(bx, _ground_y - 152.0), "剑歌起", ART_DASH_COL, 22)
		lines.append(str(m["name"]) + " 放出『" + str(m["ult"]) + "』：剑歌 " + str(int(m.get("ult_turns_max", 3))) + " 手——期间每次暴击追一剑")
		return
	var dmg2 := maxi(1, int(round(float(m["atk"]) * ULT_MUL * DMG_MUL * randf_range(0.9, 1.1))))
	dmg2 = _e_take(dmg2, m)
	lines.append(str(m["name"]) + " 放出『" + str(m["ult"]) + "』：" + str(dmg2))

# 武学按数据放：伤害 / 连追 / 护体 / 打断 / 回气（冷却走 art.cd）
func _use_art(m: Dictionary, arts: Array, n, bx: float, ex: float, col: Color, lines: Array) -> void:
	var ai := int(m.get("art_i", 0)) % arts.size()
	m["art_i"] = ai + 1
	var aid := str(arts[ai])
	var art: Dictionary = Cards.art_of(aid)
	var anm := Cards.name_of(aid)
	var kind := str(art.get("kind", "damage"))
	# ㊿y：角色星「剑意」——武学冷却 -N（最低 1 次行动，跟运签卡同一条口径）
	# v53：「滞涩」——这一手放完的冷却也要 +2 手（状态压在谁身上，谁的技能就慢）
	m["art_cd"] = maxi(1, Cards.art_cd(aid) - int(m.get("star_acdm", 0))) + St.cd_add(m)
	_center_move("『" + anm + "』", col)
	_lunge(n, bx, LUNGE_OUT * 1.1)
	var nmul := 1.0
	var pend := float(m.get("next_mult", 0.0))
	if pend > 0.0:
		nmul = pend
		m["next_mult"] = 0.0
	if kind == "guard":
		var turns := int(art.get("turns", 2))
		m["guard_turns"] = turns
		m["guard_cut"] = float(art.get("cut", 0.8))
		_fx("guard", Vector2(bx, _ground_y - 62.0), ART_GUARD_COL, 0.9, 46.0)
		_float_at(Vector2(bx, _ground_y - 152.0), "护体", ART_GUARD_COL, 20)
		lines.append(str(m["name"]) + " 施『" + anm + "』：护体——此后 " + str(turns) + " 次受击减伤 " + str(int(round((1.0 - float(art.get("cut", 0.8))) * 100.0))) + "%")
		return
	if kind == "cleanse":
		# v53：驱散（清心诀）——自己这手不出击，给全队洗掉负面，顺便磕掉当前对手的护体与蓄势
		_cleanse_apply(m, art, anm, lines)
		return
	if kind == "heal":
		# v53：「封脉」在身——武学照放，药气只剩三成
		var hm := St.heal_mul(m)
		if hm <= 0.0:
			_float_at(Vector2(bx, _ground_y - 152.0), "封脉", St.col_of("healseal"), 22)
			lines.append(str(m["name"]) + " 施『" + anm + "』：经脉被封——这一口回不上来。")
			return
		var heal := maxi(1, int(round(float(m["max"]) * float(art.get("heal_pct", 0.25)) * hm)))
		m["hp"] = mini(int(m["max"]), int(m["hp"]) + heal)
		m["next_mult"] = float(art.get("next_mult", 1.0))
		_fx("heal", Vector2(bx, _ground_y - 8.0), ART_HEAL_COL, 0.9, 56.0)
		_float_at(Vector2(bx, _ground_y - 152.0), "+" + str(heal), GREEN, 22)
		lines.append(str(m["name"]) + " 施『" + anm + "』：回气 +" + str(heal) + "，下次出手 ×" + str(snappedf(float(art.get("next_mult", 1.0)), 0.1)))
		return
	if kind == "bless":
		# ㊿：加持——不伤人，给自己人上状态（前排/中排/后排/全队）
		_bless_apply(m, art, anm, lines)
		return
	# v62f（用户："将武学现有倍率拆成5份"）：倍率**吃星级**——0★ 就是今天这个数，
	#   每一星加一份（10/15/20/25/30%），满星 ×2。走 GameState.art_mult 这一口，
	#   与面板上显示的是同一个算法（面板读的也是它）。
	var mult := GameState.art_mult(aid, float(art.get("mult", ART_FALLBACK_MUL)))
	var aw := Cards.weapon_of(aid)
	var mw := Cards.weapon_of(str(m.get("weapon", "")))
	var mismatch := false
	if aw != "any" and aw != "" and mw != aw:
		# ㊿z：角色少侠「武学宗师」——无视武学的兵器要求，不趁手也按原本倍率打
		if bool(m.get("star_anyw", false)):
			_float_at(Vector2(bx, _ground_y - 176.0), "武学宗师", GOLD, 20)
		elif art.has("off_mult"):
			mult = GameState.art_mult(aid, float(art.get("off_mult")))
			mismatch = true
	# ============================================================
	# v48：**按招式的 target 挑目标**（出村战斗以前完全忽略这个字段——
	#   `target: back/mid` 的武学在这儿照样只打最前排，而游历那边是照做的）。
	#   · front/mid/back：按"够到第几排"的规矩挑（前后排都死光才轮到后面的；与游历同口径）
	#   · sweep：打**所有活着的**（游历早就是群攻，村里一直是单体——这次对齐）
	#   ⚠ 挑完要把聚焦切过去，后面的 _e_* 访问器（_e_take / _e_hp / 飘字）才跟着那只走。
	# ============================================================
	var is_sweep := str(art.get("target", "front")) == "sweep"
	if is_sweep:
		_art_sweep(m, art, mult, nmul, bx, col, lines, anm, mismatch)
		return
	var tidx := _art_target_index(art)
	if tidx >= 0 and tidx != _focus:
		_focus_on(tidx)
		ex = _foe_x_now(ex)
	# v48：**多段攻击**（art["hits"]＝2~3，每段都是 mult，倍率刻意压得很低）：
	#   每一段**各自掷暴击、各自过一遍结算**（防御/护体/反伤/战意都各算一次），
	#   所以"多段"的价值不在总倍率，而在**多几次暴击机会**——
	#   跟苏青鸾的剑歌追剑（暴击就追）配在一起才有味道。
	var hits := maxi(1, int(art.get("hits", 1)))
	if hits >= 2:
		_art_multi_hits(m, n, art, mult, nmul, bx, ex, col, lines, anm)
		return
	if kind == "stone":
		var scrit := randf() * 100.0 < _crit_chance(m, _foe_below_half())
		var d1 := maxi(1, int(round(float(m["atk"]) * mult * DMG_MUL * nmul * randf_range(0.9, 1.1))))
		if scrit:
			d1 = int(round(float(d1) * _crit_mul(m)))
		# v48：带上出手人——凡与出手人有关的那几层（攻防对拼 / 怪的反伤·战意·电盾）
		#   以前这里空着 src，于是"武学既不吃防御、也不会被反伤弹到"（普攻/大招都吃）。
		d1 = _e_take(d1, m)
		_ex_thorn_gain(m)
		_enemy_skip = true
		_fx("slash", Vector2(ex - 38.0, _ground_y - 128.0), ART_STONE_COL, 0.4, 34.0, 1.0)
		_fx("hit", Vector2(ex, _ground_y - 92.0), ART_STONE_COL, 0.4, 34.0)
		_knock(_enemy_node(), ex, -20.0)
		_shake(9.0)
		_float_at(Vector2(ex, _ground_y - 160.0), "-" + str(d1), ART_STONE_COL, 26, _member_elem_mark(m))
		lines.append(str(m["name"]) + " 施『" + anm + "』：" + str(d1) + ("（暴击！）" if scrit else "") + "——打断其下一手")
		# v46：武学暴击也追剑（用户："释放技能…也是"）
		if scrit:
			_song_follow(m, n, bx, ex, col, lines)
		return
	if kind == "dash":
		# v46：武学也掷暴击了（以前只有普攻/大招掷）——不然"武学暴击追剑"根本无从谈起
		var dcrit := randf() * 100.0 < _crit_chance(m, _foe_below_half())
		var d2 := maxi(1, int(round(float(m["atk"]) * mult * DMG_MUL * nmul * randf_range(0.9, 1.1))))
		var d3 := maxi(1, int(round(float(m["atk"]) * float(art.get("follow", 0.7)) * DMG_MUL * randf_range(0.9, 1.1))))
		if dcrit:
			d2 = int(round(float(d2) * _crit_mul(m)))
			d3 = int(round(float(d3) * _crit_mul(m)))
		var dsum := _e_take(d2 + d3, m)
		_ex_thorn_gain(m)
		_fx("wind", Vector2(ex - 34.0, _ground_y - 92.0), ART_DASH_COL, 0.42, 60.0, 1.0)
		_fx("hit", Vector2(ex, _ground_y - 92.0), ART_DASH_COL, 0.4, 40.0)
		_knock(_enemy_node(), ex, -22.0)
		_shake(10.0)
		_float_at(Vector2(ex, _ground_y - 160.0), "-" + str(dsum), ART_DASH_COL, 27, _member_elem_mark(m))
		lines.append(str(m["name"]) + " 施『" + anm + "』：两段共 " + str(dsum) + ("（暴击！）" if dcrit else ""))
		if dcrit:
			_song_follow(m, n, bx, ex, col, lines)
		return
	var hcrit := randf() * 100.0 < _crit_chance(m, _foe_below_half())
	var dmg := maxi(1, int(round(float(m["atk"]) * mult * DMG_MUL * nmul * randf_range(0.9, 1.1))))
	if hcrit:
		dmg = int(round(float(dmg) * _crit_mul(m)))
	dmg = _e_take(dmg, m)
	_ex_thorn_gain(m)
	_fx("slash", Vector2(ex - 38.0, _ground_y - 92.0), col, 0.42, 52.0, 1.0)
	_fx("hit", Vector2(ex, _ground_y - 92.0), col, 0.42, 40.0)
	_knock(_enemy_node(), ex, -24.0)
	_shake(11.0)
	_float_at(Vector2(ex, _ground_y - 160.0), "-" + str(dmg), col, 28, _member_elem_mark(m))
	var extra := ""
	if mismatch:
		extra = "（非本门兵器 ×" + str(snappedf(mult, 0.1)) + "）"
	elif nmul > 1.0:
		extra = "（蓄势 ×" + str(snappedf(nmul, 0.1)) + "）"
	lines.append(str(m["name"]) + " 施『" + anm + "』：" + str(dmg) + extra + ("（暴击！）" if hcrit else ""))
	# v52：招式自带的状态（烈焰刀/卸甲手/软筋散…）——伤害已经落地，这里挂状态
	_st_art_foe(art, lines, ex)
	if hcrit:
		_song_follow(m, n, bx, ex, col, lines)

# v48：这一招该打哪一只（返回 _foes 下标；-1 ＝ 没挑到）。
#   规矩与游历的 _target_foe 同一条（**在够得着的排里挑站得最靠后的那只**）：
#     · front（reach 0）→ 最前排那只
#     · mid  （reach 1）→ 中排那只（中排空了就退回前排）
#     · back （reach 2）→ **绕过当面挡刀的，直取最后面那只**（与苏青鸾「洞察」同一口径）
#   ⚠ 以前村里完全不读这个字段，破阵刀法/穿云箭法在这儿等于普通单挑武学——
#     描述写着"绕过当面那个"，实现却是照打最前排。
func _art_target_index(art: Dictionary) -> int:
	var reach := GameData.target_reach(str(art.get("target", "front")))
	var best := -1
	for i in _foes.size():
		if not _foe_alive(i):
			continue
		if i <= reach:
			best = i
	return best if best >= 0 else _front_foe()

# 聚焦目标变了之后，把"打点 x"重新取一次（用该怪节点的真实 x，动画才对得上）
func _foe_x_now(fallback: float) -> float:
	var tn = _enemy_node()
	if tn != null and is_instance_valid(tn):
		return tn.position.x
	return fallback

# v48：群伤武学（target: sweep）——对所有活着的敌人各来一下。
#   各只**各自掷暴击、各自结算**（防御/护体/反伤逐只算），所以打几个人就是几份账。
func _art_sweep(m: Dictionary, art: Dictionary, mult: float, nmul: float, bx: float, col: Color, lines: Array, anm: String, mismatch: bool) -> void:
	var ebase := size.x * 0.72
	var hits: Array = []
	var total := 0
	var crit_any := false
	var back := _focus
	for i in _foes.size():
		if not _foe_alive(i):
			continue
		_focus_on(i)
		var exi := _foe_slot_x(ebase, i)
		var sc := randf() * 100.0 < _crit_chance(m, _foe_below_half())
		var one := maxi(1, int(round(float(m["atk"]) * mult * DMG_MUL * nmul * randf_range(0.9, 1.1))))
		if sc:
			one = int(round(float(one) * _crit_mul(m)))
			crit_any = true
		one = _e_take(one, m)
		total += one
		_ex_thorn_gain(m)
		# v52：横扫的招式若带 apply——**每一只中招的都挂上**（聚焦已经在它身上了）
		_st_art_foe(art, lines, exi)
		_fx("slash", Vector2(exi - 38.0, _ground_y - 92.0), col, 0.42, 52.0, 1.0)
		_fx("hit", Vector2(exi, _ground_y - 92.0), col, 0.42, 40.0)
		_float_at(Vector2(exi, _ground_y - 160.0), "-" + str(one), (SEAL if sc else col), 26, _member_elem_mark(m))
		hits.append(str((_foes[i] as Dictionary).get("name", "敌")) + " " + str(one))
		# 暴击就追剑（苏青鸾那条规矩：只要暴击就追）
		if sc and float(m.get("ult_follow", 0.0)) > 0.0:
			_song_follow(m, m.get("node", null), bx, exi, col, lines)
	_shake(13.0)
	if not _foe_alive(back):
		back = _front_foe()
	if back >= 0:
		_focus_on(back)
	var extra := ""
	if mismatch:
		extra = "（非本门兵器 ×" + str(snappedf(mult, 0.1)) + "）"
	elif nmul > 1.0:
		extra = "（蓄势 ×" + str(snappedf(nmul, 0.1)) + "）"
	lines.append(str(m["name"]) + " 施『" + anm + "』横扫：" + "、".join(PackedStringArray(hits)) + extra + ("（暴击！）" if crit_any else ""))

# v48：多段武学（art["hits"] ＝ 2~3 段）——每一段**各自的暴击、各自的结算**。
#   ⚠ 段数上限就是 3（用户："多段攻击【最多3】"），表里写更多也只按 3 段算。
#   每一段的倍率从 art["mult"] 读，本来就该写得很低（0.3~0.8 那种），
#   所以它的定位是"多几次暴击机会"，不是"总倍率更高"。
func _art_multi_hits(m: Dictionary, n, art: Dictionary, mult: float, nmul: float, bx: float, ex: float, col: Color, lines: Array, anm: String) -> void:
	var seg := clampi(int(art.get("hits", 2)), 2, 3)
	var total := 0
	var crit_n := 0
	# v61（用户："多段导致人物动画抽搐"）：**挨打位移只敲一下**。
	#   原来这一段循环里每段都叫一次 _knock()——它们全在同一帧发出，
	#   而 move_seq() 是"后来者赢"：第 1 段刚起头就被第 2 段掐掉、第 2 段又被第 3 段掐掉，
	#   敌人实际只抖了"最后一次"的起手，看着就是原地一抽。
	#   现在把位移提到循环外：一次敲退 + 逐段的刀光/命中/飘字各走各的（伤害与战报一字不改）。
	_knock(_enemy_node(), ex, -12.0)
	for k in seg:
		if _e_hp() <= 0:
			break
		var sc := randf() * 100.0 < _crit_chance(m, _foe_below_half())
		var one := maxi(1, int(round(float(m["atk"]) * mult * DMG_MUL * nmul * randf_range(0.9, 1.1))))
		if sc:
			one = int(round(float(one) * _crit_mul(m)))
		one = _e_take(one, m)
		total += one
		if sc:
			crit_n += 1
		_ex_thorn_gain(m)
		_fx("slash", Vector2(ex - 30.0 - 8.0 * float(k), _ground_y - 96.0), col, 0.3, 42.0, 1.0)
		_fx("hit", Vector2(ex, _ground_y - 92.0), col, 0.3, 30.0)
		_float_at(Vector2(ex + 18.0 * float(k), _ground_y - 158.0 - 14.0 * float(k)), "-" + str(one),
			(SEAL if sc else col), 22)
		lines.append("　第 " + str(k + 1) + " 段：" + str(one) + ("（暴击！）" if sc else ""))
		# 每一段暴击都追剑（与"只要暴击就追"同一条规矩）
		if sc:
			_song_follow(m, n, bx, ex, col, lines)
	_shake(9.0)
	lines.append(str(m["name"]) + " 施『" + anm + "』" + str(seg) + " 段共 " + str(total)
		+ ("（" + str(crit_n) + " 段暴击）" if crit_n > 0 else ""))
	# v52：多段武学也认 apply（表里现在没有这种，留着口径一致）
	_st_art_foe(art, lines, ex)

func _bob_only(node, base_x: float) -> void:
	if node == null:
		return
	# ㊿x：也起新序列（"施自带技"这一步可能紧挨着普攻/连击，同一帧两条 x 补间就是抽搐）
	var s := _anim_speed()
	var tw: Tween = node.move_seq()
	tw.tween_property(node, "position:x", base_x + 14.0, 0.12 / s)
	tw.tween_property(node, "position:x", base_x, 0.16 / s)

# ---- v8：首领带招（大招 / 技能 / 挨打减伤 / 敌情）----

# v9：敌攻击现算（狂暴×1.6；鼓舞/战意叠加）
func _e_atk_eff() -> float:
	var v := float(_e()["atk"])
	if _e_affixes().has("berserk") and _e_hp() * 2 <= _e_max():
		v *= Affixes.BERSERK_MUL()
	return v * (1.0 + _e_stack())

# ㉙：枪势反刺现算——按陈石气血上限的比例带 8%~12%：挨的打越重比例越高。
# ㊳：陈石的「断枪」＝用枪时反刺 ×1.1（kind thorn_up，见 data_roles）。
#   以前这里写着"村战没有加成"，现在加上了。
func _thorn_calc(target: Dictionary, raw_hit: int) -> int:
	var mx := maxi(1, int(target.get("max", 1)))
	var ratio := clampf(float(raw_hit) / float(mx), 0.0, 1.0)
	# ㊿z6：专武·铁壁桩功——"每击中一名敌人，反刺 +10%"攒出来的那份也乘进来（封顶 +100%）
	var ramp := clampf(float(target.get("thorn_ramp", 0.0)), 0.0, 1.0)
	var pct := lerpf(THORN_HP_LO, THORN_HP_HI, ratio) * float(target.get("thorn_mul", 1.0)) * (1.0 + ramp)
	return maxi(1, int(round(float(mx) * pct)))

# ㊿z8：专武·长风诀——"放完大招后"开连发窗口（**不分打几个**：打多人、打单人都算放完了）。
#   ⚠ 这一句必须在 uk=="hit" 的**两支上都调**：横扫那一支以前直接 return 走了，
#     于是"打多人时放完大招"开不出窗口——只有打单人才生效，跟设计不符。
#   回合数 = ult_chain_turns + 1（＋当前这一手所在的、不完整的那个回合），
#   此后每过一个回合由 _act() 的回合头减 1。
func _ex_chain_arm(m: Dictionary) -> void:
	if int(m.get("ex_chain_turns", 0)) > 0:
		m["ult_chain_left"] = int(m["ex_chain_turns"]) + 1

# ============================================================
# v46：剑歌追剑——**苏青鸾（大招「青鸾出岫」开的窗）只要这一手暴击就追**
#   用户："苏的被动暴击追击是只要暴击就追击，释放技能和大招也是哈。"
#   原来这一块只长在**普攻**那一支里，于是"放武学暴击"、"大招暴击"都不追——
#   现在抽成这一口，三条路都调它（普攻 / _use_art / _member_ult）。
#   ⚠ 窗口（ult_turns）与段数（ult_follow_hits，含角色星「出岫」的 +1 段）仍由大招那支设，
#     这里只负责"追"；追剑自己也会掷暴击（专武·短歌行：追击伤害 +50%、追击暴击再 +20%）。
#   返回这一手追出去多少伤害（0 ＝ 没追）。
# ============================================================
# v49（用户："追击的暴击不触发追击"）：**追剑自己暴击 → 再追一层**。
#   以前追剑只把暴击换成伤害（专武·短歌行那条 +20%），不会再生出新的追击——
#   于是"只要暴击就追击"这句话在**追击自己身上**不成立。
#   现在：每一层追剑自己暴击，就再追一层。
#   ⚠ **必须有上限**，不然一暴击就无限连环（尤其暴击率堆高之后）：
#     SONG_CHAIN_MAX ＝ 一次触发最多追到第几层（1 ＝ 老行为；3 ＝ 最多"追了又追"两轮）。
#   期望追击次数（暴击率 p）＝ p + p² + p³，苏青鸾 27% 暴击时约 0.36 次/触发，不会失控。
# ============================================================
const SONG_CHAIN_MAX := 3

func _song_follow(m: Dictionary, n, bx: float, ex: float, col: Color, lines: Array, depth := 1) -> int:
	if depth > SONG_CHAIN_MAX:
		return 0
	if int(m.get("ult_turns", 0)) <= 0 or float(m.get("ult_follow", 0.0)) <= 0.0:
		return 0
	if _e_hp() <= 0 or int(m.get("hp", 0)) <= 0:
		return 0
	var total := 0
	var f_up := 1.0 + float(m.get("ex_follow", 0.0))
	for hi in int(m.get("ult_follow_hits", 1)):
		if _e_hp() <= 0:
			break
		var fdmg := maxi(1, int(round(float(m["atk"]) * float(m["ult_follow"]) * DMG_MUL * f_up * randf_range(0.9, 1.1))))
		var fcrit := randf() * 100.0 < _crit_chance(m, _foe_below_half())
		if fcrit:
			fdmg = int(round(float(fdmg) * _crit_mul(m) * (1.0 + float(m.get("ex_follow_crit", 0.0)))))
		fdmg = _e_take(fdmg, m)
		total += fdmg
		_ex_thorn_gain(m)   # ㊿z6：追剑也是"击中一名敌人"
		_fx("slash", Vector2(ex - 30.0, _ground_y - 104.0), ART_DASH_COL, 0.3, 40.0, 1.0)
		var tag2 := "（暴击！）" if fcrit else ""
		if depth > 1:
			tag2 += "（连环 " + str(depth) + "）"
		_float_at(Vector2(ex, _ground_y - 176.0 - 16.0 * float(depth - 1)), "追剑 -" + str(fdmg) + tag2, ART_DASH_COL, 22)
		lines.append(str(m["name"]) + " 剑歌追剑：" + str(fdmg) + tag2)
		# v49：追剑自己暴击 → 再追一层（有上限，见 SONG_CHAIN_MAX）
		if fcrit and depth < SONG_CHAIN_MAX and _e_hp() > 0:
			total += _song_follow(m, n, bx, ex, col, lines, depth + 1)
	return total

# ㊿z6：专武·铁壁桩功——自己**每击中一名敌人**，反刺累计 +10%（封顶 +100%）。
#   普攻/连击/武学/大招走到伤害那一步时调一下；没有这门专武的人原样不动。
func _ex_thorn_gain(m: Dictionary) -> void:
	var per := float(m.get("ex_thorn_per", 0.0))
	if per <= 0.0:
		return
	m["thorn_ramp"] = minf(1.0, float(m.get("thorn_ramp", 0.0)) + per)

# ㊿z6：专武·铁壁桩功——一次反刺的结算：打谁（全体或只打出手那一个）+ 反刺后回血。
#   返回实际反刺到的敌人数（0 = 没反）。
func _ex_thorn_strike(m: Dictionary, raw_hit: int, tx: float) -> int:
	if int(m.get("hp", 0)) <= 0:
		return 0
	var amount := _thorn_calc(m, raw_hit)
	var idxs: Array = []
	if bool(m.get("ex_thorn_all", false)):
		for i in _foes.size():
			if _foe_alive(i):
				idxs.append(i)
	else:
		idxs.append(_focus)
	var n := 0
	for i_v in idxs:
		var i := int(i_v)
		if not _foe_alive(i):
			continue
		_focus_on(i)
		var rb := amount
		if bool(m.get("ex_thorn_all", false)):
			rb = maxi(1, int(round(float(amount) * 0.6)))   # 打全体时每只按六成，免得"一扫清场"
		_e_take(rb)
		_float_at(Vector2(_foe_slot_x(size.x * 0.72, i), _ground_y - 158.0), "反刺 -" + str(rb), C_COUNTER, 20)
		n += 1
	var back := float(m.get("ex_thorn_heal", 0.0))
	if n > 0 and back > 0.0:
		# v53：专武的回血也吃「封脉」（回血只剩三成）
		var heal := maxi(1, int(round(float(m["max"]) * back * St.heal_mul(m))))
		m["hp"] = mini(int(m["max"]), int(m["hp"]) + heal)
		_float_at(Vector2(tx, _ground_y - 176.0), "桩劲回气 +" + str(heal), GREEN, 20)
	return n

# v9：自爆——倒下时炸头一个还站着的
# v36（用户："自爆全体不要炸到自己人，也要有提示，比如 自爆 180"）：
#   · **只炸对面**：这里从头到尾只遍历 `_party`（我方），绝不会炸到它自己的同伴；
#     游历那边（duel_battle._foe_bomb_if_dead）同理只遍历 `_allies`。
#   · **提示做足**：先算出这一炸最重的一下，横幅写"自爆 N"，每个挨炸的人头上飘 −N
#     （原来只有飘字，没有"这一炸多重"的总数）。
func _enemy_bomb() -> void:
	if not _e_affixes().has("bomb"):
		return
	# ㊿：自爆改成**群体**——不再挑一个人，全队活着的各按**自己的**上限挨四成
	#   （基数仍是挨炸那个人的上限，所以满血的人不会被一下炸死；
	#    但一炸全队都掉四成，两只自爆怪连着死＝全队八成，很凶）。
	var worst := 0
	for i in _party.size():
		var t0: Dictionary = _party[i]
		if int(t0.get("hp", 0)) <= 0:
			continue
		worst = maxi(worst, maxi(1, int(round(float(t0["max"]) * Affixes.BOMB_PCT()))))
	if worst > 0:
		_float_at(Vector2(size.x * 0.5, _ground_y - 226.0), "自爆 " + str(worst), Color(0.85, 0.55, 0.20), 30)
	var hit := 0
	for i in _party.size():
		var target: Dictionary = _party[i]
		if int(target.get("hp", 0)) <= 0:
			continue
		var tx0 := float(target.get("base_x", 0.0))
		var bd := maxi(1, int(round(float(target["max"]) * Affixes.BOMB_PCT())))
		target["hp"] = maxi(0, int(target["hp"]) - bd)
		_fx("hit", Vector2(tx0, _ground_y - 92.0), Color(0.85, 0.55, 0.20), 0.6, 70.0)
		_float_at(Vector2(tx0, _ground_y - 158.0), "-" + str(bd), Color(0.85, 0.55, 0.20), 26)
		_push([str(_e()["name"]) + " 自爆 " + str(worst) + "——" + str(target["name"]) + " 挨了 " + str(bd)])
		if int(target["hp"]) <= 0:
			_fall(target["node"], -1.0)
		hit += 1
	_shake(14.0)
	if hit == 0:
		return
	_check_party_dead()

func _check_party_dead() -> void:
	var alive := 0
	for m in _party:
		if int(m["hp"]) > 0:
			alive += 1
	if alive == 0:
		_end(false)

# ============================================================
# v52：负面状态（缴械 / 燃烧 / 震慑 / 破防 / 虚弱 / 迟缓 / 封脉）
#   用户："参考三国志谋定天下这款 SLG，我要加一些负面状态，类似缴械啊、燃烧啊 等"
#   表与 API 都在 shared/data_status.gd（游历那边共用同一份，规矩只写一遍）。
#   这里只做三件事：
#     ① 每手开头结算（掉血 + 时长递减）——在 _act() 里、本人出手之前
#     ② 效果兑现——不能普攻 / 不能放武学 / 放不出大招 / 整手不出 /
#        出手方攻击 / 挨打方受伤 / 出手顺序 / 怒气获取 / 回血倍率 / 技能冷却 / 被动失效
#     ③ 播报 ＋ 面板上那一行
#     ③ 播报 ＋ 面板上那一行
#   ⚠ 掉血**不吃减伤**（与既有的毒/自爆同口径）：按气血上限的比例直接扣。
# ============================================================

# ============================================================
# v54：**闭窍**（被动失效）——用户："闭窍是针对玩家的"
#   压住的是玩家这一侧的**四条被动线**：
#     · 自带天赋（断枪/洞察/守拙…）——能压的：thorn_mul / foe_low_mul / row_prio / cut
#     · 被动功法（专武）——所有 ex_* 机制
#     · 五问天赋——talent_cut（百折不挠）、crit 与 def/dodge 的加数、剑心通明那份 atk 放大
#     · 角色星——所有 star_* 机制，以及已经乘进大招倍率/持续/反刺的那几项
#   做法＝**备份—压零—还原**（备份存在 pas_bak 里，压着的期间不重复备份，
#   所以"续上"不会把已经压成 0 的值当成原值）：
#     上状态 → _passive_mask()；时长到/被洗掉 → _passive_unmask()
#   ⚠ 还不了的那一份：已经算进**气血上限**的被动（自家 hp_pct、星的 hp）——血条不会缩。
# ============================================================
const PASSIVE_ZERO := {
	"thorn_mul": 1.0, "foe_low_mul": 1.0, "row_prio": "", "cut": 0.0,
	"talent_cut": 0.0, "rage_mul": 1.0,
	"star_acdm": 0, "star_veng": 0.0, "star_follow": 0, "star_anyw": false,
	"star_rage_hit": 0.0, "star_crit_low": 0.0, "star_critmul": 0.0,
	"ex_ult_per_hit": 0.0, "ex_ult_rage": 0.0, "ex_ult_cut": 0.0, "ex_thorn_all": false,
	"ex_thorn_per": 0.0, "ex_thorn_heal": 0.0, "ex_follow": 0.0, "ex_follow_crit": 0.0,
	"ex_chain_up": 0.0, "ex_chain_turns": 0,
}

func _passive_mask(u: Dictionary) -> void:
	if u.is_empty() or u.has("pas_bak"):
		return                      # 已经压着——别把压成 0 的值当成原值再备份一遍
	var bak: Dictionary = {}
	for k in PASSIVE_ZERO.keys():
		if u.has(k):
			bak[k] = u[k]
			u[k] = PASSIVE_ZERO[k]
	# 乘进大招与反刺的那几项：写回建队时存好的基准
	if u.has("ult_mult_base"):
		bak["ult_mult"] = u["ult_mult"]
		u["ult_mult"] = u["ult_mult_base"]
	if u.has("ult_mult_single_base") and float(u.get("ult_mult_single", 0.0)) > 0.0:
		bak["ult_mult_single"] = u["ult_mult_single"]
		u["ult_mult_single"] = u["ult_mult_single_base"]
	if u.has("ult_turns_base"):
		bak["ult_turns_max"] = u["ult_turns_max"]
		u["ult_turns_max"] = u["ult_turns_base"]
	# ⚠ thorn_mul 只在 PASSIVE_ZERO 里压一次（底子 1.0）；星的那一份已经被乘进字段里，
	#   压成 1.0 就等于"自带与星一起停"——以前这里又多压了一道、把备份盖成了 0 值，
	#   还原时反把 1.15 变成 1.0（探针当场抓到的小坑）。
	# 加数型（天赋与星的 crit / def / dodge）：减掉那几点
	for dk in ["crit_pas", "def_pas", "dodge_pas"]:
		var target := str(dk).replace("_pas", "")
		if u.has(dk) and u.has(target):
			bak[target] = u[target]
			u[target] = float(u[target]) - float(u[dk])
	# 剑心通明那份 atk 放大：除回去
	if u.has("atk_artmul") and float(u["atk_artmul"]) > 1.0 and u.has("atk"):
		bak["atk"] = u["atk"]
		u["atk"] = maxi(1, int(round(float(u["atk"]) / float(u["atk_artmul"]))))
	u["pas_bak"] = bak
	_float_at(Vector2(float(u.get("base_x", 0.0)), _ground_y - 176.0), "被动全被压住", St.col_of("nopassive"), 22)

func _passive_unmask(u: Dictionary) -> void:
	if u.is_empty() or not u.has("pas_bak"):
		return
	var bak: Dictionary = u["pas_bak"]
	for k in bak.keys():
		u[k] = bak[k]
	u.erase("pas_bak")

# 给目标挂状态（spec ＝ 武学/怪招/词缀里的 "apply"）。返回 true ＝ 挂上了
# ⚠ is_foe：立刻效果（挫锐打怒气 / 滞涩推后当前冷却）要落在"挨打那一侧"的字段上，
#   而两边的字段名不同（我方 m.rage/m.art_cd，首领走 _e_* 访问器），所以要传进来。
func _st_hit(u: Dictionary, spec: Dictionary, lines: Array, at_x: float, who: String, is_foe := false) -> bool:
	if u.is_empty() or spec.is_empty():
		return false
	var sid := str(spec.get("id", ""))
	if sid == "" or St.def_of(sid).is_empty():
		return false
	var ch := float(spec.get("chance", 1.0))
	if ch < 1.0 and randf() >= ch:
		_float_at(Vector2(at_x, _ground_y - 196.0), "「" + St.name_of(sid) + "」未中", Color(0.55, 0.53, 0.52), 18)
		return false
	var msg := St.apply(u, sid, int(spec.get("turns", 0)), int(spec.get("stacks", 1)))
	if msg == "":
		return false
	_float_at(Vector2(at_x, _ground_y - 196.0), St.name_of(sid) + "！", St.col_of(sid), 22)
	lines.append(who + " 中招：" + msg)
	# v54：「闭窍」——把这一侧的被动线全压住（我方＝自带/被动功法/五问天赋/角色星）
	if bool(St.def_of(sid).get("block_passive", false)):
		_passive_mask(u)
	# ---- v53：上状态那一刻的"立刻效果"（挫锐当场打怒气 / 滞涩把当前冷却推后）----
	var dd: Dictionary = St.def_of(sid)
	var rb := int(dd.get("rage_burn", 0))
	if rb > 0:
		if is_foe:
			_set_e_rage(maxi(0, _e_rage() - rb))
		else:
			u["rage"] = maxi(0, int(u.get("rage", 0)) - rb)
		lines.append("　锐气被打散：怒气 −" + str(rb))
	var ca := int(dd.get("cd_add", 0))
	if ca > 0:
		if is_foe:
			if _e_art_cd() > 0:
				_set_e_art_cd(_e_art_cd() + ca)
		elif int(u.get("art_cd", 0)) > 0:
			u["art_cd"] = int(u["art_cd"]) + ca
		lines.append("　经脉滞涩：技能冷却 +" + str(ca) + " 手")
	return true

# 每手开头结算（护盾衰减 + 掉血 + 印记爆发 + 时长递减）。返回 true ＝ 这一手就别再打了
func _st_tick(u: Dictionary, hp_max: int, lines: Array, at_x: float) -> bool:
	var r: Dictionary = St.tick(u, hp_max, {"atk": float(u.get("atk", 0.0))})
	var dmg := int(r.get("dmg", 0))
	if dmg > 0:
		u["hp"] = maxi(0, int(u.get("hp", 0)) - dmg)
		_float_at(Vector2(at_x, _ground_y - 150.0), "状态 -" + str(dmg), Color(0.62, 0.34, 0.24), 20)
		lines.append(str(u.get("name", "")) + " 状态发作 −" + str(dmg)
			+ "（" + "、".join(PackedStringArray(r.get("msgs", []))) + "）")
	# v58：护盾每回合自然衰减 10%
	var sl := int(r.get("shield_lost", 0))
	if sl > 0:
		_float_at(Vector2(at_x, _ground_y - 128.0), "护盾 -" + str(sl), Color(0.56, 0.42, 0.24), 18)
	# v58：**印记爆发**——数值在 data_status 里算好（含元素加成），这里只管打给谁。
	#   ⚠ 打谁由 list[].to 说了算：负面印记（燃烧/水浸）打**背着它的那个人**；
	#     正面印记（鎏金/寄生/岩甲）打**他的对手**。塔这边"对手"＝另一侧。
	var bd: Dictionary = r.get("burst", {})
	for one_v in (bd.get("list", []) as Array):
		var one: Dictionary = one_v
		var bdmg := int(one.get("dmg", 0))
		if bdmg <= 0:
			continue
		var bel := str(one.get("elem", ""))
		var btxt := str(one.get("lines", []))
		if typeof(one.get("lines", [])) == TYPE_ARRAY:
			btxt = ", ".join(PackedStringArray(one.get("lines", [])))
		var to_carrier := str(one.get("to", "foe")) == "self"
		var is_mem := _is_member(u)
		var hits_foe: bool = (not is_mem) if to_carrier else is_mem
		if hits_foe:
			_set_e_hp(maxi(0, _e_hp() - bdmg))
			lines.append(str(u.get("name", "")) + " 印记爆发 → 首领 −" + str(bdmg) + "（" + btxt + "）")
			_float_at(Vector2(_enemy_base_x(), _ground_y - 150.0), str(bdmg), Elem.col(bel), 24, bel)
		else:
			u["hp"] = maxi(0, int(u.get("hp", 0)) - bdmg)
			lines.append(str(u.get("name", "")) + " 印记爆发 −" + str(bdmg) + "（" + btxt + "）")
			_float_at(Vector2(at_x, _ground_y - 150.0), str(bdmg), Elem.col(bel), 24, bel)
	# v58：「踏浪」——夺对手的水抗（塔里对手恒是首领）
	for sb in (bd.get("self_bursts", []) as Array):
		if str(sb) != "soak":
			continue
		var lv := St.stacks(u, "soak")
		var v := float(St.def_of("soak").get("burst_v", 0.15)) * float(maxi(1, lv))
		var rr: Dictionary = St.steal_res(_e(), u, "water", v)
		lines.append(str(u.get("name", "")) + " 「踏浪」夺首领水抗 " + str(int(rr["res"] * 100.0))
			+ "% → 自己水伤 +" + str(int(rr["dmg_pt"])) + "% · 速度 +" + str(int(rr["spd_pt"])) + "%")
		_float_at(Vector2(at_x, _ground_y - 176.0), "踏浪", Elem.col("water"), 22)
	for g in (r.get("gone", []) as Array):
		lines.append("　「" + str(g) + "」散了")
		# v54：闭窍到期——把被动线原样还回来
		if str(g) == "闭窍" or str(g) == str(St.name_of("nopassive")):
			_passive_unmask(u)
			_float_at(Vector2(at_x, _ground_y - 176.0), "窍穴通了", GREEN, 20)
	return int(u.get("hp", 0)) <= 0

# v58：这一格是"队员"还是"首领"（印记爆发要打对方向）
func _is_member(u: Dictionary) -> bool:
	return u.has("base_x")

# 当前被点名的队员名字（战报用）
func _member_name_now() -> String:
	for m_v in _party:
		var m: Dictionary = m_v
		if int(m.get("idx", -1)) == _focus:
			return str(m.get("name", "我"))
	return "我"

# 面板上那一行（没有状态＝空串）
#   v54：后面缀上全局规则那条底账（"受伤 +8%"）——不然玩家看不出"负面越多越疼"
func _st_line(u: Dictionary) -> String:
	var ln := St.line(u)
	if ln == "":
		return ""
	var vn := St.vuln_note(u)
	return ln if vn == "" else ln + "（" + vn + "）"

# v52：招式自带的状态挂到**当前聚焦的那只怪**身上（打完才挂——调用点都在伤害结算之后）
# v56：去掉第一个参数 `m`——函数体里一个字节都没用到它，Godot 记了一条
#   UNUSED_PARAMETER 告警（"parameter 'm' is never used in the function '_st_art_foe'"）。
#   五处调用点跟着改（都是删掉那个实参）。
func _st_art_foe(art: Dictionary, lines: Array, at_x: float) -> void:
	var spec: Dictionary = art.get("apply", {})
	if spec.is_empty() or _e_hp() <= 0:
		return
	_st_hit(_e(), spec, lines, at_x, str(_e().get("name", "敌")), true)

# v52：词缀"击中就上状态"（火魔/铁锁）——首领的普攻与怪招两条路都调它
# v53：**闭窍**在身时词缀整个失效（_e_affixes 会被压成空表），所以这里天然挂不上
func _st_affix_hit(target: Dictionary, at_x: float, lines: Array) -> void:
	if int(target.get("hp", 0)) <= 0:
		return
	for aid in _e_affixes():
		var spec: Dictionary = Affixes.on_hit(str(aid))
		if not spec.is_empty():
			_st_hit(target, spec, lines, at_x, str(target.get("name", "")), false)

# 首领挨打结算：护体在身先减伤——所有打到首领身上的伤害都过这里（v9：带出手人，兑现词缀）
# v35：**攻防对拼**——出手人的攻击值 vs 首领的防御值（GameData.def_cut）。
#   src 空着的那几路（反刺/反噬这类"不是出手打过去"的伤害）不做对拼，原样算。

# v58：印记播报（塔这边没有游历那种"战报"对象，走 _log 即可）
func lines_ok(msg: String) -> void:
	if msg != "":
		_log.append("　印记：" + msg)

func _e_take(raw: int, src: Dictionary = {}) -> int:
	var dmg := raw
	# v52：**出手方的「虚弱」→ 这一下更轻**；**首领身上的「破防」→ 这一下更重**。
	#   放在最前面（洞察之前）：它们是"打的人没力"与"挨的人没防"，跟用哪一招无关。
	#   src 空着的那几路（反刺/反噬这类"不是出手打过去"的伤害）不吃出手方的那一条。
	if not src.is_empty():
		var sm := St.atk_mul(src)
		if not is_equal_approx(sm, 1.0):
			dmg = maxi(1, int(round(float(dmg) * sm)))
	var tm := St.taken_mul(_e())
	if not is_equal_approx(tm, 1.0):
		dmg = maxi(1, int(round(float(dmg) * tm)))
	# v55：词缀·坚壁——挨打两成半几率硬挡，那一下只吃两成
	#   ⚠ 不做"完全免伤（0）"：战报/浮字到处都在写 "-" + str(dmg)，0 会飘一个 −0 出来，
	#     而且 0 伤害还会让"是否命中"那条判断串味。只吃两成在体感上就是"挡下来了"。
	if dmg > 0 and _e_affixes().has("bulwark") and randf() < Affixes.BULWARK_CHANCE():
		dmg = maxi(1, int(round(float(dmg) * Affixes.BULWARK_TAKE())))
		_float_at(Vector2(_enemy_base_x(), _ground_y - 186.0), "坚壁！", Color(0.44, 0.44, 0.50), 22)
	# ㊳：洞察——出手的人若有"残敌增伤"，且对手气血已不足一半，这一下更重。
	#   放在护体减伤**之前**：它是"打得更狠"，不是"防备得更少"。
	if not src.is_empty():
		var flm := float(src.get("foe_low_mul", 1.0))
		if flm > 1.0 and _e_hp() * 2 <= _e_max():
			dmg = int(round(float(dmg) * flm))
	# v35：防御先挡一道（用出手人的攻击值比首领的防御值）
	# v58（用户第 4 条"防御只对物理有效"）：元素伤害**跳过这一道**，改走首领的对应五行抗性。
	var mel := _member_elem(src)
	if not src.is_empty() and Elem.is_elem_attack(mel):
		var eres := float(_e().get(Elem.res_key(mel), 0.0))
		var ecut: float = Elem.res_mul(eres)
		if not is_equal_approx(ecut, 1.0):
			dmg = maxi(1, int(round(float(dmg) * ecut)))
	else:
		var atk_src := float(src.get("atk", 0.0))
		var def_foe := float(_e().get("def", 0))
		if atk_src > 0.0 and def_foe > 0.0:
			dmg = GameData.after_def(float(dmg), atk_src, def_foe)
	if _e_guard_turns() > 0:
		_set_e_guard_turns(_e_guard_turns() - (1))
		# v48：护体改为**按折后的数**乘（以前写的是 raw）——
		#   写 raw 等于"护体一开，攻防对拼与残敌增伤那一份被一起抹掉"（护体=覆盖防御）。
		#   游历那边一直是折后数相乘（duel_battle._foe_take），两套引擎这次对齐。
		dmg = maxi(1, int(round(float(dmg) * _e_guard_cut())))
		_fx("guard", Vector2(_enemy_base_x(), _ground_y - 62.0), ART_GUARD_COL, 0.5, 44.0)
		if _e_guard_turns() <= 0:
			_set_e_guard_cut(0.0)
	# v58（用户第 5 条）：**元素攻击按属性给印记**——火水打首领、金木土叠自己。
	#   加成记进印记条目（用户："燃烧【吃火属性加成】"），之后掉血与爆发都按它放大。
	#   ⚠ 每一次伤害结算都会调一次（连击/群攻各算一次）——这正是"叠层"的来源。
	if not src.is_empty() and Elem.is_elem_attack(mel) and _e_hp() > 0:
		var eb := 1.0 + _elem_bonus_pt(src, mel) / 100.0
		eb *= 1.0 + St.elem_gain(src, mel) / 100.0
		var mr: Dictionary = St.apply_elem_mark(src, _e(), mel, eb)
		if not mr.is_empty():
			var mmsg := str(mr.get("msg", ""))
			lines_ok(mmsg)
			if str(mr.get("side", "")) == "self":
				_float_at(Vector2(float(src.get("base_x", 0.0)), _ground_y - 176.0), mmsg,
					St.col_of(str(mr.get("id", ""))), 20)
	# v58（用户第 5 条）：**护盾先挨**（岩甲给的额外生命值），没打光不掉气血
	if St.shield_of(_e()) > 0:
		var ab: Dictionary = St.shield_absorb(_e(), dmg)
		if int(ab["absorbed"]) > 0:
			_float_at(Vector2(_enemy_base_x(), _ground_y - 186.0), "护盾 -" + str(int(ab["absorbed"])), Color(0.56, 0.42, 0.24), 20)
		dmg = int(ab["hp"])
		if dmg <= 0:
			return 0
	_set_e_hp(_e_hp() - (dmg))
	if not src.is_empty() and dmg > 0:
		if _e_affixes().has("fury"):
			_set_e_stack(minf(Affixes.FURY_CAP(), _e_stack() + Affixes.FURY_STEP()))
		if _e_affixes().has("thorns"):
			# ㉕：按原始数（不吃减伤）。㊿：再加一道硬上限——
			#   一次反伤最多打掉出手人上限的 THORN_CAP()，从此不会"一击被反死"。
			#   12% 这个比例只在"单次挨打 < 自己上限的 83%"时才是它说了算；
			#   再重的一击就由上限接管（见 data_affixes 那段说明）。
			var rf := maxi(1, int(round(float(raw) * Affixes.THORN_PCT())))
			rf = mini(rf, maxi(1, int(round(float(src.get("max", 1)) * Affixes.THORN_CAP()))))
			src["hp"] = maxi(0, int(src["hp"]) - rf)
			# ㉙：橙字打在我身上——"反伤"（橙）与回复（绿）一眼分开
			_float_at(Vector2(float(src["base_x"]), _ground_y - 148.0), "反伤 -" + str(rf), C_COUNTER, 20)
			if int(src["hp"]) <= 0:
				_fall(src["node"], -1.0)
				_dust_at(float(src["base_x"]), _ground_y)
				_push([str(src["name"]) + " 被反伤拖倒了……"])
				_check_party_dead()
		if _e_affixes().has("shock") and randf() < Affixes.SHOCK_CHANCE():
			src["stun"] = int(src.get("stun", 0)) + 1
			_float_at(Vector2(float(src["base_x"]), _ground_y - 170.0), "电麻！", Color(0.45, 0.55, 0.85), 20)
	return dmg

# ㉗：队员挨打的唯一口径——护体减伤（cut）＋百折不挠（残血减伤）。
# 敌人普攻与敌人技能都走这里：这规则只写一遍，以后调只见一处。
# v35：**闪避 → 防御**的顺序也在这一个口里：
#   ① 先看闪不闪得开（GameData.dodge_rate：我闪避 vs 对手速度）→ 闪了就 0；
#   ② 再按攻防对拼挡一道（对手的攻击值 vs 我的防御值）；
#   ③ 然后才是原来那几层减伤（护体/加持/残血）。
#   "闪避"这一层要浮字，所以放在这里而不是调用点——所有挨打路径都过这个口。
func _member_take_cut(target: Dictionary, raw: int) -> int:
	if target.is_empty():
		return 0
	# v52：**怪身上的「虚弱」→ 这一下更轻**；**队员身上的「破防」→ 这一下更重**。
	#   所有落到我方的伤害都走这个口（普攻/连击/怪招/大招/群攻逐个聚焦），所以只写一处。
	var raw2 := raw
	var fm := St.atk_mul(_e())
	if not is_equal_approx(fm, 1.0):
		raw2 = maxi(1, int(round(float(raw2) * fm)))
	var ptm := St.taken_mul(target)
	if not is_equal_approx(ptm, 1.0):
		raw2 = maxi(1, int(round(float(raw2) * ptm)))
	# ① 闪避（对手越快越难闪）
	var dr := GameData.dodge_rate(float(target.get("dodge", 0.0)), float(_e().get("spd", 10)))
	if dr > 0.0 and randf() < dr:
		_float_at(Vector2(float(target.get("base_x", 0.0)), _ground_y - 158.0), "闪避！", C_DODGE, 22)
		return 0
	var dmg := raw2
	# ② 攻防对拼（出手的是这一只怪：用它此刻的攻击值）
	#   v58（用户第 4 条）：元素伤害跳过这一道，改走五行抗性
	var foe_atk := float(_e_atk_eff())
	var my_def := float(target.get("def", 0.0))
	if _foe_elem() != "":
		# v58：元素那一手**先乘通道底倍率 0.8**（与游历 `_roll_e_damage` 同一处口径），
		#   再走我方的对应五行抗性；不乘防御、也不参与暴击（伤害入口那几处都不在元素路上）
		dmg = maxi(1, int(round(float(dmg) * Elem.channel_mul(_foe_elem_mark()))))
		var eres2 := float(target.get(Elem.res_key(_foe_elem_mark()), 0.0)) + St.res_shift(target, _foe_elem_mark())
		dmg = maxi(1, int(round(float(dmg) * Elem.res_mul(eres2))))
	elif my_def > 0.0:
		dmg = GameData.after_def(float(dmg), foe_atk, my_def)
	# ③ 原有那几层
	dmg = maxi(1, int(round(float(dmg) * (1.0 - float(target.get("cut", 0.0))))))
	var bc := float(target.get("bless_cut", 0.0))   # ㊿：加持减伤（坚壁旗令/同心结阵）
	# ㊿z6：专武·铁壁桩功——大招窗口（枪势）里额外减伤 +15%
	if int(target.get("ult_turns", 0)) > 0:
		bc = maxf(bc, float(target.get("ex_ult_cut", 0.0)))
	if bc > 0.0:
		dmg = maxi(1, int(round(float(dmg) * (1.0 - bc))))
	var tc := float(target.get("talent_cut", 0.0))
	if tc > 0.0 and int(target["hp"]) * 10 <= int(target["max"]) * 3:
		dmg = maxi(1, int(round(float(dmg) * (1.0 - tc))))
	# v58：护盾先挨（岩甲给队员的额外生命值）
	if St.shield_of(target) > 0:
		var ab2: Dictionary = St.shield_absorb(target, dmg)
		if int(ab2["absorbed"]) > 0:
			_float_at(Vector2(float(target.get("base_x", 0.0)), _ground_y - 158.0),
				"护盾 -" + str(int(ab2["absorbed"])), Color(0.56, 0.42, 0.24), 20)
		dmg = int(ab2["hp"])
	return dmg

# ============================================================
# ㊿ 加持（kind "bless"）——出村/爬塔这一场的人手是一组字典（_party），
#   没有游历那边"每人的 fx 表"可读，所以：
#     · 减伤 → 写 bless_cut，由 _member_take_cut 统一读（一处就够）
#     · 增伤/暴击 → **直接改写 m.atk / m.crit**（原值存在 bless_*_base），
#       到期再还原。这样普攻、各种武学、大招那 8 处伤害计算一个字都不用动。
#   语义与游历一致：持续"目标自己的 N 手"，施放那一手不算；同一人只挂一条。
# ============================================================
# ㊿z3：加持目标 → 我方下标数组。
#   "self" = 施放者本人（专属功法走这条）——所以要把施放者传进来找他自己的下标。
#   ⚠ 下标读的是建队时写进成员字典的 "idx"（别用 _party.find(caster)：字典按值比较，
#     两个人数据一样时会认错人）。
func _bless_targets(t: String, caster: Dictionary = {}) -> Array:
	var out: Array = []
	var last := _party.size() - 1
	if last < 0:
		return out
	match t:
		"self":
			out.append(int(caster.get("idx", 0)))
		"ally_front":
			out.append(0)
		"ally_back":
			out.append(last)
		"ally_mid":
			out.append(1 if last >= 2 else 0)
		_:
			for i in _party.size():
				out.append(i)
	return out

func _bless_clear(t: Dictionary) -> void:
	if t.has("bless_atk_base"):
		t["atk"] = int(t["bless_atk_base"])
		t.erase("bless_atk_base")
	if t.has("bless_crit_base"):
		t["crit"] = float(t["bless_crit_base"])
		t.erase("bless_crit_base")
	if t.has("bless_spd_base"):
		t["spd"] = float(t["bless_spd_base"])
		t.erase("bless_spd_base")
	t["bless_cut"] = 0.0
	t["bless_regen"] = 0.0
	t["bless_rage"] = 0.0
	t["bless_turns"] = 0

func _bless_apply(caster: Dictionary, art: Dictionary, anm: String, lines: Array) -> void:
	var turns := int(art.get("turns", 3))
	var cut := float(art.get("cut", 0.0))
	var atk := float(art.get("atk_pct", 0.0))
	var cr := float(art.get("crit_add", 0.0))
	var rg := float(art.get("regen_pct", 0.0))
	var sp := float(art.get("spd_pct", 0.0))
	var ra := float(art.get("rage_pct", 0.0))
	var who: Array = []
	for i_v in _bless_targets(str(art.get("target", "ally_all")), caster):
		var i := int(i_v)
		if i < 0 or i >= _party.size():
			continue
		var t: Dictionary = _party[i]
		if int(t.get("hp", 0)) <= 0:
			continue
		_bless_clear(t)          # 新的顶掉旧的
		t["bless_turns"] = turns
		# ============================================================
		# v52 修正：**加持减伤以前算反了**。表里那个 `cut` 是"伤害系数"（0.85＝受击时
		#   只挨 85%，也就是减伤 15%）——与 `kind:"guard"` 的 cut 同一个口径。
		#   可两套引擎的加持消费者都是按"减伤比例"用的（`dmg × (1 − bless_cut)`），
		#   于是 0.85 被当成"减 85%"。实测（探针 probe_bless）：
		#     坚壁旗令 1000 → 150（应 850）· 铁壁合围 1000 → 200（应 800）
		#     同心结阵 1000 → 90（应 910）
		#   ——即"设计与文案都说 15%，实际给的是 85%"，整整强了五倍多。
		#   修法选在**源头转换**（存进去的就是"减伤比例"）：这样
		#     ① `_member_take_cut` / `_foe_show_hit` 那两处 (1 − bcut) 一个字不用动；
		#     ② 与专武·铁壁桩功的 `ex_ult_cut`（本来就是"减伤比例"）取 max 才同口径；
		#     ③ 游历 `_bless_mark` 打印的也是这个数，显示自然就对上了。
		# ============================================================
		t["bless_cut"] = clampf(1.0 - cut, 0.0, 0.95) if cut > 0.0 else 0.0
		t["bless_regen"] = rg
		t["bless_rage"] = ra
		t["bless_skip"] = true   # 施放这一手不计入"自己的手"
		if atk > 0.0:
			t["bless_atk_base"] = int(t["atk"])
			t["atk"] = maxi(1, int(round(float(t["atk"]) * (1.0 + atk))))
		if cr > 0.0:
			t["bless_crit_base"] = float(t.get("crit", 5.0))
			t["crit"] = float(t.get("crit", 5.0)) + cr
		if sp > 0.0:
			t["bless_spd_base"] = float(t.get("spd", 10.0))
			t["spd"] = float(t.get("spd", 10.0)) * (1.0 + sp)
		who.append(str(t.get("name", "")))
		_fx("heal", Vector2(float(t["base_x"]), _ground_y - 8.0), ART_HEAL_COL, 0.9, 52.0)
		_float_at(Vector2(float(t["base_x"]), _ground_y - 158.0), "加持", ART_HEAL_COL, 20)
	if who.is_empty():
		return
	var what: Array = []
	if atk > 0.0:
		what.append("伤害 +" + str(int(round(atk * 100.0))) + "%")
	if cut > 0.0:
		# v52：文案也跟着改成"减伤比例"（以前印的是 cut 本身＝85%，跟描述打架）
		what.append("减伤 " + str(int(round((1.0 - cut) * 100.0))) + "%")
	if cr > 0.0:
		what.append("暴击 +" + str(int(round(cr))))
	if rg > 0.0:
		what.append("每手回 " + str(int(round(rg * 100.0))) + "%")
	if sp > 0.0:
		what.append("速度 +" + str(int(round(sp * 100.0))) + "%")
	if ra > 0.0:
		what.append("怒气 +" + str(int(round(ra * 100.0))) + "%")
	lines.append(str(caster.get("name", "")) + " 施『" + anm + "』：" + "、".join(PackedStringArray(who)) + " " + "、".join(PackedStringArray(what)) + "（" + str(turns) + " 手）")

# ㊿：加持按"自己的手"计数——由 _act() 在本人出手之后调用
# v53：驱散（清心诀）——全队洗掉负面 + 磕掉当前对手的护体与蓄势。
#   ⚠ 用 `kind: "cleanse"` 而不是"kind: bless + cleanse 字段"：
#     bless 那一套会 `_bless_clear` 顶掉旧的加持——清心诀不该把队友身上的坚壁洗掉。
func _cleanse_apply(caster: Dictionary, art: Dictionary, anm: String, lines: Array) -> void:
	var who: Array = []
	for i_v in _bless_targets(str(art.get("target", "ally_all")), caster):
		var i := int(i_v)
		if i < 0 or i >= _party.size():
			continue
		var t: Dictionary = _party[i]
		if int(t.get("hp", 0)) <= 0:
			continue
		var msg := St.cleanse(t, int(art.get("cleanse", 1)))
		# v54：洗掉「闭窍」＝被动线还原
		if msg.contains(St.name_of("nopassive")):
			_passive_unmask(t)
		_fx("heal", Vector2(float(t["base_x"]), _ground_y - 8.0), ART_HEAL_COL, 0.9, 52.0)
		_float_at(Vector2(float(t["base_x"]), _ground_y - 158.0), "清心" if msg == "" else "洗净", ART_HEAL_COL, 20)
		if msg != "":
			who.append(str(t.get("name", "")) + " " + msg)
	if bool(art.get("dispel_foe", false)) and _foe_alive(_focus):
		# 磕掉对手的护体与蓄势（这两个是首领最硬的两种"起手"）
		var had: Array = []
		if _e_guard_turns() > 0:
			_set_e_guard_turns(0)
			_set_e_guard_cut(0.0)
			had.append("护体")
		if _e_next_mult() > 1.0:
			_set_e_next_mult(1.0)
			had.append("蓄势")
		if not had.is_empty():
			who.append(str(_e().get("name", "敌")) + " 被磕掉" + "、".join(PackedStringArray(had)))
	if who.is_empty():
		lines.append(str(caster.get("name", "")) + " 施『" + anm + "』：身上本就干净，白走一手。")
		return
	lines.append(str(caster.get("name", "")) + " 施『" + anm + "』：" + "；".join(PackedStringArray(who)))

func _tick_bless(t: Dictionary) -> void:
	if int(t.get("bless_turns", 0)) <= 0:
		return
	if bool(t.get("bless_skip", false)):
		t["bless_skip"] = false
		return
	t["bless_turns"] = int(t["bless_turns"]) - 1
	if int(t["bless_turns"]) <= 0:
		_bless_clear(t)
		_push([str(t.get("name", "")) + " 的加持散了"])

# 打到某名队员身上（技能用；含其护体消耗）
func _enemy_hit_member(target: Dictionary, raw: int, tx: float) -> int:
	# ㉝：target 可能为空（够不着任何暴露目标时 pick 会返回空）——空就白打一手，不崩
	if target.is_empty():
		return 0
	# ㊿：偷袭（ambush）——打**不在前排**的目标伤害 +50%（row 就是下标，0＝前排）
	var raw2 := raw
	if _e_affixes().has("ambush") and int(target.get("row", 0)) > 0:
		raw2 = maxi(1, int(round(float(raw) * 1.5)))
	var dmg := _member_take_cut(target, raw2)
	if int(target.get("guard_turns", 0)) > 0:
		target["guard_turns"] = int(target["guard_turns"]) - 1
		dmg = maxi(1, int(round(float(dmg) * float(target.get("guard_cut", 0.8)))))
		_fx("guard", Vector2(tx, _ground_y - 62.0), ART_GUARD_COL, 0.5, 44.0)
	target["hp"] = maxi(0, int(target["hp"]) - dmg)
	_fx("slash", Vector2(tx + 38.0, _ground_y - 92.0), SEAL, 0.34, 44.0, -1.0)
	_fx("hit", Vector2(tx, _ground_y - 92.0), SEAL, 0.36, 34.0)
	_knock(target["node"], tx, 20.0)
	_shake(9.0)
	_float_at(Vector2(tx, _ground_y - 158.0), "-" + str(dmg), SEAL, 26)
	# ㊿y：角色星「蓄势」——挨了打，下一击更重（与运签卡的"回气"同一条口径：
	#   同一手只算一次、取较大的那个；next_mult 在出手时用掉并清零）
	if float(target.get("star_veng", 0.0)) > 0.0 and int(target["hp"]) > 0:
		target["next_mult"] = maxf(float(target.get("next_mult", 0.0)), 1.0 + float(target.get("star_veng", 0.0)))
	# ㊿z：角色星·陈石「铁桩」——受击也涨怒气（不到自己出手，怒气也往上走）
	#   ⚠ 键的单位是**比例**（0.15＝满怒的 15% ＝ 15 点，怒气上限 100）
	if float(target.get("star_rage_hit", 0.0)) > 0.0 and int(target["hp"]) > 0:
		target["rage"] = mini(100, int(target.get("rage", 0))
			+ int(round(100.0 * float(target.get("star_rage_hit", 0.0)) * St.rage_mul(target))))
	if _e_affixes().has("poison") and int(target["hp"]) > 0:
		target["poison"] = mini(Affixes.POISON_MAX(), int(target.get("poison", 0)) + 1)
		_float_at(Vector2(tx, _ground_y - 176.0), "中毒 +1", Color(0.42, 0.62, 0.30), 18)
	# v52：词缀·火魔/铁锁（怪招路同样兑现——与毒刃一样两条路都写）
	var stl: Array = []
	_st_affix_hit(target, tx, stl)
	_push(stl)
	# v55：词缀·吸血（怪招打中同样回血）
	if _e_affixes().has("leech") and _e_hp() > 0 and _e_hp() < _e_max():
		var lh2 := maxi(1, int(round(float(_e_max()) * Affixes.LEECH_PCT())))
		_set_e_hp(mini(_e_max(), _e_hp() + lh2))
		_float_at(Vector2(_enemy_base_x(), _ground_y - 176.0), "吸血 +" + str(lh2), Color(0.62, 0.24, 0.32), 20)
	# ㉙：陈石·枪势反刺——按上限 8~12%；橙字打在敌人身上
	# ㊿z6：专武·铁壁桩功把它扩成"反刺全体 + 每次回血 + 累计增幅"（见 _ex_thorn_strike）；
	#   没这门专武的人走原路：只反出手那一个，数值一模一样。
	if bool(target.get("ult_thorn_on", false)) and int(target.get("ult_turns", 0)) > 0 and _e_hp() > 0:
		if bool(target.get("ex_thorn_all", false)) or float(target.get("ex_thorn_per", 0.0)) > 0.0 or float(target.get("ex_thorn_heal", 0.0)) > 0.0:
			_ex_thorn_strike(target, raw, tx)
		else:
			var rb := _thorn_calc(target, raw)
			_e_take(rb)
			_float_at(Vector2(_enemy_base_x(), _ground_y - 158.0), "反刺 -" + str(rb), C_COUNTER, 20)
	return dmg

func _enemy_death_check(tx: float, target: Dictionary) -> bool:
	if int(target["hp"]) <= 0:
		_fall(target["node"], -1.0)
		_dust_at(tx, _ground_y)
		_push([str(target["name"]) + " 倒下了。"])
	# v12：**反刺把怪反死**也要收摊——这一口是"怪放完招之后的收尾"，
	#   原来只数我方；敌人在它自己出手时被打死就一直没人管（见 _act 开头那段）。
	if _foes_alive() <= 0:
		_enemy_fall_pending()
		_end(_party_alive() > 0)
		return true
	if _party_alive() <= 0:
		_end(false)
		return true
	_refresh()
	return false

func _enemy_use_art(a: Dictionary, target: Dictionary) -> void:
	# ㉝：pick 可能返回空——空就别走这手
	if target.is_empty():
		return
	var anm := str(a.get("name", "杀招"))
	var kind := str(a.get("kind", "damage"))
	# v53：「滞涩」——首领放完这一手，冷却也 +2 手
	_set_e_art_cd(int(a.get("cd", 3)) + St.cd_add(_e()))
	var ex := _enemy_base_x()
	var tx := float(target["base_x"])
	_center_move("『" + anm + "』", SEAL)
	_lunge(_enemy_node(), ex, -LUNGE_OUT)
	if kind == "guard":
		var turns := int(a.get("turns", 2))
		_set_e_guard_turns(turns)
		_set_e_guard_cut(float(a.get("cut", 0.78)))
		_fx("guard", Vector2(ex, _ground_y - 62.0), ART_GUARD_COL, 0.9, 48.0)
		_float_at(Vector2(ex, _ground_y - 158.0), "横练护体", ART_GUARD_COL, 22)
		_push([str(_e()["name"]) + " 施『" + anm + "』：护体——此后 " + str(turns) + " 次挨打减伤 " + str(int(round((1.0 - _e_guard_cut()) * 100.0))) + "%"])
		_refresh()
		return
	if kind == "heal":
		# v53：「封脉」在身——这一口只剩三成
		if St.heal_mul(_e()) <= 0.0:
			_float_at(Vector2(ex, _ground_y - 158.0), "封脉", St.col_of("healseal"), 24)
			_push([str(_e()["name"]) + " 施『" + anm + "』：经脉被封——这一口回不上来。"])
			_refresh()
			return
		var heal := maxi(1, int(round(float(_e_max()) * float(a.get("heal_pct", 0.2)) * St.heal_mul(_e()))))
		_set_e_hp(mini(_e_max(), _e_hp() + heal))
		_set_e_next_mult(float(a.get("next_mult", 1.0)))
		_fx("heal", Vector2(ex, _ground_y - 8.0), ART_HEAL_COL, 0.9, 64.0)
		_float_at(Vector2(ex, _ground_y - 158.0), "+" + str(heal), GREEN, 26)
		_push([str(_e()["name"]) + " 施『" + anm + "』：回气 +" + str(heal) + "（气血 " + str(_e_hp()) + "/" + str(_e_max()) + "）"])
		_refresh()
		return
	if kind == "charge":
		_set_e_next_mult(float(a.get("mult", 1.5)))
		_fx("wind", Vector2(ex, _ground_y - 92.0), ART_DASH_COL, 0.5, 60.0, -1.0)
		_float_at(Vector2(ex, _ground_y - 158.0), "蓄势", ART_DASH_COL, 22)
		_push([str(_e()["name"]) + " 施『" + anm + "』：气势起来了——下一手 ×" + str(snappedf(_e_next_mult(), 0.1))])
		_refresh()
		return
	var mul_all := float(a.get("mult", 1.5)) * _e_next_mult()
	_set_e_next_mult(1.0)
	var d1 := maxi(1, int(round(_e_atk_eff() * mul_all * DMG_MUL * randf_range(0.9, 1.1))))
	var applied := _enemy_hit_member(target, d1, tx)
	var st_lines: Array = []
	if kind == "dash":
		var d2 := maxi(1, int(round(_e_atk_eff() * float(a.get("follow", 0.8)) * DMG_MUL * randf_range(0.9, 1.1))))
		applied += _enemy_hit_member(target, d2, tx)
		_push([str(_e()["name"]) + " 施『" + anm + "』：两段共 " + str(applied) + "（" + str(target["name"]) + "）"])
	else:
		_push([str(_e()["name"]) + " 施『" + anm + "』：" + str(applied) + "（" + str(target["name"]) + "）"])
	# v52：怪招自带的状态（第 50 关往后首领的焚身掌/锁脉手/封穴指）
	if int(target.get("hp", 0)) > 0:
		_st_hit(target, a.get("apply", {}), st_lines, tx, str(target.get("name", "")))
		_push(st_lines)
	if _enemy_death_check(tx, target):
		return
	_refresh()

func _enemy_ult(target: Dictionary) -> void:
	# ㉝：pick 可能返回空（够不着任何暴露目标）——空就别走这手，免得崩
	if target.is_empty():
		return
	var un := str(_e_ult().get("name", "大招"))
	var ex := _enemy_base_x()
	var tx := float(target["base_x"])
	_center_move("『" + un + "』", SEAL)
	_lunge(_enemy_node(), ex, -LUNGE_OUT * 1.3)
	_fx("wave", Vector2(tx + 6.0, _ground_y - 96.0), SEAL, 0.62, 150.0, -1.0)
	_shake(16.0)
	_flash_now(SEAL, 0.6)
	var mul_all := float(_e_ult().get("mult", 2.0)) * _e_next_mult()
	_set_e_next_mult(1.0)
	var d1 := maxi(1, int(round(_e_atk_eff() * mul_all * DMG_MUL * randf_range(0.9, 1.1))))
	# ㊱：群伤大招（"target": "sweep"）打到所有还站着的队员，不是只打一个
	if str(_e_ult().get("target", "front")) == "sweep":
		var hits: Array = []
		var downed: Array = []
		var sulines: Array = []
		for m_v in _party:
			var m2: Dictionary = m_v
			if int(m2["hp"]) <= 0:
				continue
			var tx2 := float(m2["base_x"])
			var ap2 := _enemy_hit_member(m2, d1, tx2)
			hits.append(str(m2["name"]) + " " + str(ap2))
			# v52：横扫大招带状态——**每一个还站着的都挂上**
			if int(m2["hp"]) > 0:
				_st_hit(m2, _e_ult().get("apply", {}), sulines, tx2, str(m2["name"]))
			if int(m2["hp"]) <= 0:
				downed.append(m2)
		_push([str(_e()["name"]) + " 放出『" + un + "』——横扫全场：" + "、".join(PackedStringArray(hits))])
		_push(sulines)
		# 群伤会一次打倒好几个：逐个补倒地下落的动画，再统一判负
		for m_v2 in downed:
			var m3: Dictionary = m_v2
			_fall(m3["node"], -1.0)
			_dust_at(float(m3["base_x"]), _ground_y)
		_refresh()
		_check_party_dead()
		return
	var applied := _enemy_hit_member(target, d1, tx)
	_push([str(_e()["name"]) + " 放出『" + un + "』：" + str(applied) + "（" + str(target["name"]) + "）"])
	# v52：大招带状态（同上）
	if int(target.get("hp", 0)) > 0:
		var ulines: Array = []
		_st_hit(target, _e_ult().get("apply", {}), ulines, tx, str(target.get("name", "")))
		_push(ulines)
	if _enemy_death_check(tx, target):
		return
	_refresh()

# ---- v8：敌情面板（看着不走回合）----

func _show_info() -> void:
	if _over or _info_open:
		return
	_info_open = true
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.42)
	veil.size = size
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(_on_info_blank)
	add_child(veil)
	_info_veil = veil
	var panel := UiKit.make_paper_panel(veil, Rect2(80, 300, 560, 680))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var tt := UiKit.make_label(panel, Vector2(0, 18), Vector2(560, 40), 26, UiKit.INK)
	UiKit.set_text(tt, "敌情 · " + str(_e()["name"]))
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l0 := UiKit.make_label(panel, Vector2(34, 70), Vector2(492, 30), 16, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.75))
	# v47：单人关没有"前后排"可写——改写它的体型（肉盾/寻常/高伤）
	var pos_txt := str(_e().get("solo_cn", ""))
	if pos_txt == "":
		pos_txt = GameData.foe_row_cn(_focus)
	UiKit.set_text(l0, "气血 " + str(_e_hp()) + " / " + str(_e_max()) + "　·　攻 " + str(_e()["atk"])
		+ "　·　" + pos_txt + "　·　第 " + str(stage_i + 1) + " 关"
		# v52：它身上挂着的负面状态也写在这儿（战场血条下面那一行的完整版）
		+ ("" if _st_line(_e()) == "" else "　·　负：" + _st_line(_e())))
	var y := 104.0
	# v46：整组站位一览——谁在前排挡刀、谁在后排打伤害（▶ ＝ 现在盯着的这只）
	if _foes.size() > 1:
		var seg: Array = []
		for i3 in _foes.size():
			var f3: Dictionary = _foes[i3]
			seg.append(("▶ " if i3 == _focus else "　 ") + GameData.foe_row_cn(i3) + " " + str(f3["name"])
				+ "　气 " + str(f3["hp"]) + "/" + str(f3["hp_max"]) + " · 攻 " + str(f3["atk"]))
		var lr := UiKit.make_label(panel, Vector2(34, y - 6.0), Vector2(492, 88), 14, Color(0.24, 0.34, 0.52))
		UiKit.set_text(lr, "站位（前排挡刀 · 后排打得疼，普攻只打最前排）：\n" + "\n".join(PackedStringArray(seg)))
		lr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		y += 92.0
	if not _e_affixes().is_empty():
		var seg: Array = []
		for af in _e_affixes():
			seg.append("「" + Affixes.name_of(str(af)) + "」" + str(Affixes.of(str(af)).get("desc", "")))
		var la := UiKit.make_label(panel, Vector2(34, y), Vector2(492, 96), 15, Color(0.62, 0.30, 0.26))
		UiKit.set_text(la, "词缀：" + "\n".join(PackedStringArray(seg)))
		la.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		y += 104.0
	if _e_arts().is_empty() and _e_ult().is_empty():
		var ln := UiKit.make_label(panel, Vector2(34, y), Vector2(492, 60), 17, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
		UiKit.set_text(ln, "寻常货色——没有成名招数。\n（首领关会带 1~2 招和一门大招）")
		ln.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for a_v in _e_arts():
		var a: Dictionary = a_v
		var l1 := UiKit.make_label(panel, Vector2(34, y), Vector2(492, 84), 16, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))
		# ㊱：说明用 GameData.move_desc 拼——非"只打前排"的招式会自动缀上打哪几排
		UiKit.set_text(l1, "「" + str(a.get("name", "?")) + "」　每 " + str(int(a.get("cd", 3))) + " 手一转\n　" + GameData.move_desc(a))
		l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		y += 92.0
	if not _e_ult().is_empty():
		var lu := UiKit.make_label(panel, Vector2(34, y), Vector2(492, 84), 17, UiKit.SEAL)
		UiKit.set_text(lu, "大招「" + str(_e_ult().get("name", "?")) + "」　怒气满自动放\n　" + GameData.move_desc(_e_ult()))
		lu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cb := UiKit.make_button(panel, Vector2(210, 606), Vector2(140, 52), "知道了", 20)
	cb.pressed.connect(_close_info)

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

func _enemy_act() -> void:
	if _enemy_skip:
		_enemy_skip = false
		_push([str(_e()["name"]) + " 被打断——这一手没使出来。"])
		return
	var target: Dictionary = _pick_target(_party, _foe_reach(), _foe_pierce_shield())
	if target.is_empty():
		return
	_set_e_acts(_e_acts() + (1))
	# v9 词缀：回春（回气）／鼓舞（士气叠加）
	# v53：「封脉」把回春压到三成；「挫锐」让怒气只剩四成
	# v13（用户："回春词缀改为 10%恢复 两手恢复一次"）：**改成每两手回一次**
	#   （上一行刚把 _e_acts 加过 1，所以"第 2、4、6…手"各回一次；
	#     间距与百分比都在 data_affixes.REGEN_EVERY()/REGEN_PCT() 那一口里）
	if _e_affixes().has("regen") and _e_hp() > 0 and _e_hp() < _e_max() 			and _e_acts() % Affixes.REGEN_EVERY() == 0:
		var rh := maxi(1, int(round(float(_e_max()) * Affixes.REGEN_PCT() * St.heal_mul(_e()))))
		_set_e_hp(mini(_e_max(), _e_hp() + rh))
		_float_at(Vector2(_enemy_base_x(), _ground_y - 158.0), "回春 +" + str(rh), GREEN, 20)
	if _e_affixes().has("rally"):
		_set_e_stack(minf(Affixes.RALLY_CAP(), _e_stack() + Affixes.RALLY_STEP()))
	# v8：首领带招——怒气满先放大招；技能按冷却轮转；都没有＝寻常出手
	_set_e_rage(_e_rage() + (int(round(RAGE_GAIN * RAGE_MUL * St.rage_mul(_e())))))
	if _e_rage() >= 100 and not _e_ult().is_empty():
		_set_e_rage(0)
		# ㊱：大招打哪几排也写在它自己身上（不写＝只打前排）
		# ㊿：点名（mid/back/sweep）＝破闸——不破的话"点名"根本点不到躲在前排后面的人
		var ur := GameData.target_reach(str(_e_ult().get("target", "front")))
		var ut := _pick_target(_party, ur, ur >= 1)
		if not ut.is_empty():
			_enemy_ult(ut)
		return
	if not _e_arts().is_empty():
		if _e_art_cd() > 0:
			_set_e_art_cd(_e_art_cd() - (1))
		if _e_art_cd() <= 0:
			var ai := _e_art_i() % _e_arts().size()
			_set_e_art_i(_e_art_i() + (1))
			# ㊱：技能打哪一排写在招式自己身上（GameData.TARGETS）——
			#   不写＝只打前排；"target": "mid"/"sweep" 这类才是特殊效果。
			var sa: Dictionary = _e_arts()[ai]
			var ar := GameData.target_reach(str(sa.get("target", "front")))
			var at := _pick_target(_party, ar, ar >= 1)   # ㊿：点名＝破闸
			if not at.is_empty():
				_enemy_use_art(sa, at)
			return
	# v52：「缴械」——首领的普攻也使不出来（大招与技能照放，见上面两支）
	if St.blocks_plain(_e()):
		_center_move(str(_e()["name"]) + " 兵器脱手", ART_GUARD_COL)
		_float_at(Vector2(_enemy_base_x(), _ground_y - 158.0), "缴械", St.col_of("disarm"), 22)
		_push([str(_e()["name"]) + " 兵器被打落——这一手没能递上来。"])
		_refresh()
		return
	var raw := maxi(1, int(round(_e_atk_eff() * DMG_MUL * randf_range(0.85, 1.15))))
	if _e_next_mult() > 1.0:
		raw = maxi(1, int(round(float(raw) * _e_next_mult())))
		_set_e_next_mult(1.0)
	var dmg := _member_take_cut(target, raw)
	var blunted := false
	if int(target.get("guard_turns", 0)) > 0:
		target["guard_turns"] = int(target["guard_turns"]) - 1
		dmg = maxi(1, int(round(float(dmg) * float(target.get("guard_cut", 0.8)))))
		blunted = true
	target["hp"] = maxi(0, int(target["hp"]) - dmg)
	var ex := _enemy_base_x()
	var tx := float(target["base_x"])
	_lunge(_enemy_node(), ex, -LUNGE_OUT)
	_fx("slash", Vector2(tx + 38.0, _ground_y - 92.0), Color(0.68, 0.28, 0.22), 0.34, 44.0, -1.0)
	_fx("hit", Vector2(tx, _ground_y - 92.0), SEAL, 0.36, 34.0)
	_knock(target["node"], tx, 20.0)
	_shake(9.0)
	var line := str(_e()["name"]) + " 反手：" + str(target["name"]) + " 挨 " + str(dmg)
	if blunted:
		line += "（护体卸力，原 " + str(raw) + "）"
		_fx("guard", Vector2(tx, _ground_y - 62.0), ART_GUARD_COL, 0.5, 44.0)
	_float_at(Vector2(tx, _ground_y - 158.0), "-" + str(dmg), SEAL, 24, _foe_elem_mark())
	_push([line])
	# ㊿：速度 → 攻速（敌方同理）：这只怪快过挨打那人一倍就再补一下，最多两下。
	#   ⚠ 塔里怪的速度上限 28、人 9~14——后期怪确实会拿到额外普攻，
	#     这是"越往后越吃力"的一部分；要收就在 tuning 里抬 atkspd_min_ratio。
	#   ⚠ 这里**不重复判倒地**：下面的 `if int(target["hp"]) <= 0` 那一段
	#     本来就是这一手之后的收尾，补刀只负责扣血。
	var back_n := GameData.extra_attacks(float(_e()["spd"]), float(target.get("spd", 10)))
	if back_n > 0 and int(target["hp"]) > 0:
		_float_at(Vector2(tx, _ground_y - 190.0), "来敌快出一截", SEAL, 20)
		for yk in back_n:
			if int(target["hp"]) <= 0:
				break
			var yraw := maxi(1, int(round(_e_atk_eff() * DMG_MUL * 0.8 * randf_range(0.85, 1.15))))
			var yd := _member_take_cut(target, yraw)
			target["hp"] = maxi(0, int(target["hp"]) - yd)
			_knock(target["node"], tx, 16.0)
			_float_at(Vector2(tx, _ground_y - 150.0), "-" + str(yd), SEAL, 22, _foe_elem_mark())
			_push(["　连击（身法）：" + str(target["name"]) + " 再挨 " + str(yd)])
	if int(target["hp"]) <= 0:
		_fall(target["node"], -1.0)
		_dust_at(tx, _ground_y)
		_check_party_dead()
	# 词缀·速攻：每第 3 手追一记
	if _e_affixes().has("swift") and _e_acts() % Affixes.SWIFT_EVERY() == 0 and int(target["hp"]) > 0:
		var d2 := maxi(1, int(round(float(dmg) * Affixes.SWIFT_PCT())))
		target["hp"] = maxi(0, int(target["hp"]) - d2)
		_fx("slash", Vector2(tx + 38.0, _ground_y - 104.0), Color(0.68, 0.28, 0.22), 0.3, 40.0, -1.0)
		_float_at(Vector2(tx, _ground_y - 170.0), "速攻 -" + str(d2), Color(0.62, 0.30, 0.26), 20)
		_push([str(_e()["name"]) + " 快招连上：" + str(target["name"]) + " 又挨 " + str(d2)])
	# v55：词缀·回响——每第 2 手追一记四成力的快招（与速攻错开：那条是每第 3 手六成力）
	if _e_affixes().has("echo") and _e_acts() % Affixes.ECHO_EVERY() == 0 and int(target["hp"]) > 0:
		var d3 := maxi(1, int(round(_e_atk_eff() * DMG_MUL * Affixes.ECHO_PCT() * randf_range(0.85, 1.15))))
		var a3 := _member_take_cut(target, d3)
		target["hp"] = maxi(0, int(target["hp"]) - a3)
		_fx("slash", Vector2(tx + 34.0, _ground_y - 88.0), Color(0.62, 0.34, 0.44), 0.28, 38.0, -1.0)
		_float_at(Vector2(tx, _ground_y - 196.0), "回响 -" + str(a3), Color(0.62, 0.34, 0.44), 20)
		_push([str(_e()["name"]) + " 余势回响：" + str(target["name"]) + " 再挨 " + str(a3)])
	# 词缀·毒刃：击中上毒
	if _e_affixes().has("poison") and int(target["hp"]) > 0:
		target["poison"] = mini(Affixes.POISON_MAX(), int(target.get("poison", 0)) + 1)
		_float_at(Vector2(tx, _ground_y - 184.0), "中毒 +1", Color(0.42, 0.62, 0.30), 18)
	# v55：词缀·火魔/铁锁/锁喉/软筋/缠足/裂甲/泄气/滞脉/封穴/点窍
	#   ——击中就上状态（与毒刃同一个位置、同一个口径）。哪些词缀上什么状态写在 data_affixes.ON_HIT，
	#   所以以后再加"上状态"的词缀，只改那张表就行，这里一个字都不用动。
	var stl: Array = []
	_st_affix_hit(target, tx, stl)
	_push(stl)
	# v55：词缀·吸血——击中就回自己上限的 6%（打得越久它越精神）
	if _e_affixes().has("leech") and _e_hp() > 0 and _e_hp() < _e_max():
		var lh := maxi(1, int(round(float(_e_max()) * Affixes.LEECH_PCT())))
		_set_e_hp(mini(_e_max(), _e_hp() + lh))
		_float_at(Vector2(_enemy_base_x(), _ground_y - 176.0), "吸血 +" + str(lh), Color(0.62, 0.24, 0.32), 20)
		_push([str(_e()["name"]) + " 咬住不放，吸回一口气 +" + str(lh)])
	# ㉙：陈石·枪势反刺——按上限 8~12%；橙字打在敌人身上
	# ㊿z6：另一条挨打路（怪的武学/连招）也走同一套"全体反刺/回血/累计"口径
	if bool(target.get("ult_thorn_on", false)) and int(target.get("ult_turns", 0)) > 0 and _e_hp() > 0:
		if bool(target.get("ex_thorn_all", false)) or float(target.get("ex_thorn_per", 0.0)) > 0.0 or float(target.get("ex_thorn_heal", 0.0)) > 0.0:
			_ex_thorn_strike(target, raw, tx)
		else:
			var rb := _thorn_calc(target, raw)
			_e_take(rb)
			_float_at(Vector2(_enemy_base_x(), _ground_y - 158.0), "反刺 -" + str(rb), C_COUNTER, 20)
	# v12：**这一手可能把反刺的怪反死**——当场收摊（与 _member_act 收尾那句同一口径：
	#   敌人清完 ＋ 我方还有人 ＝ 胜；两边同时倒 ＝ 败）。少了这一段就是玩家报的"卡住"。
	if _foes_alive() <= 0:
		_enemy_fall_pending()
		_end(_party_alive() > 0)
		return
	if int(target["hp"]) <= 0:
		_fall(target["node"], -1.0)
		_dust_at(tx, _ground_y)
		_push([str(target["name"]) + " 倒下了。"])
	if _party_alive() <= 0:
		_end(false)
		return
	_refresh()

# 第 i 个敌人站哪：0 号最靠我方（最前），往后依次往画面中央退一点
func _foe_slot_x(base_x: float, i: int) -> float:
	return base_x - 58.0 * float(i)

func _enemy_base_x() -> float:
	# 敌人出手/受击的基准位置：当前聚焦的那只（多人时各自不同）
	var i := _focus
	return size.x * 0.72 - 58.0 * float(clampi(i, 0, 2))

# ㊳／㊸：我方普攻该打哪一只（返回 _foes 下标；-1＝没有可打的）。
#   默认＝最前排（前排替后排挡刀）。
#   带 row_prio="back" 的自带（苏青鸾·洞察 持匕首）＝绕开前排，挑最靠后的活人。
func _enemy_attack_index(m: Dictionary) -> int:
	if str(m.get("row_prio", "")) != "back":
		return _front_foe()
	for i in range(_foes.size() - 1, -1, -1):
		if _foe_alive(i):
			return i
	return _front_foe()

func _center_move(txt: String, col: Color) -> void:
	var lb := _label(txt, 30, col)
	lb.position = Vector2(0, size.y * 0.30)
	lb.size = Vector2(size.x, 40)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lb)
	var tw := create_tween()
	tw.tween_property(lb, "position:y", lb.position.y - 34.0, 0.9)
	tw.parallel().tween_property(lb, "modulate:a", 0.0, 0.9)
	tw.tween_callback(lb.queue_free)

# v58（用户："伤害弹出记得标注是什么类型伤害"）：加一个可选 `elem`——
#   有元素时在数字左边挂一枚属性徽章（UiKit.elem_number_row，与游历同一处口径）；
#   空串＝物理/真实，维持老样子（只有数字）。
func _float_at(pos: Vector2, txt: String, col: Color, fs: int, elem := "") -> void:
	var node: Control = UiKit.elem_number_row(txt, col, elem, fs)
	var w: float = node.custom_minimum_size.x
	node.position = Vector2(pos.x - w * 0.5, pos.y - 16.0)
	node.size = node.custom_minimum_size
	add_child(node)
	var tw := create_tween()
	tw.tween_property(node, "position:y", node.position.y - 26.0, 0.7)
	tw.parallel().tween_property(node, "modulate:a", 0.0, 0.7)
	tw.tween_callback(node.queue_free)

func _push(lines: Array) -> void:
	for l in lines:
		_log.append(str(l))
	while _log.size() > 4:
		_log.remove_at(0)
	if _log_lb != null:
		_log_lb.text = "\n".join(PackedStringArray(_log))

func _end(win: bool) -> void:
	if _over:
		return
	_over = true
	_win = win
	GameState.battle_live = false   # ㊿：这一场收摊了——挂机估算可以接着推
	if _info_btn != null:
		_info_btn.visible = false
	_close_info()
	_result_lb.text = "胜" if win else "败"
	_result_lb.add_theme_color_override("font_color", SEAL if win else Color(0.35, 0.33, 0.34, 0.90))
	_result_lb.visible = true
	if win:
		_fx("hit", Vector2(_enemy_base_x(), _ground_y - 92.0), GOLD, 0.55, 64.0)
		_shake(10.0)
	if not win:
		for m in _party:
			if int(m["hp"]) <= 0:
				_fall(m["node"], -1.0)
	_push(["——" + ("清缴了这关。" if win else "退回去再整备。")])
	if GameState.auto_climb:
		_start_countdown()
		# ㊿q：把"人可以先走"这件事说在战报里——手机上没有 tooltip，只能靠这行
		_push(["自动挑战：接着开下一关；想先回村就点［回村·后台继续］"])
	else:
		_act_btn.text = "回村"
	_refresh_auto_ui()

func _refresh() -> void:
	if _e_hp_lb == null:
		return
	_e_hp_lb.text = str(_e_hp()) + " / " + str(_e_max())
	_e_fill.size.x = _e_bar_w * clampf(float(_e_hp()) / float(maxi(1, _e_max())), 0.0, 1.0)
	# v52：首领身上那一行状态（没有＝空串）
	if _e_st_lb != null:
		var eln := _st_line(_e())
		_e_st_lb.text = "" if eln == "" else "负：" + eln
		_e_st_lb.visible = eln != ""
	# v54：小图标（与文字同一份数据）
	if _e_chips != null:
		_e_chips.set_unit(_e())
		_e_chips.visible = _e_chips.count() > 0
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var m: Dictionary = _party[i]
		var nm: Label = r["name"]
		var ht: Label = r["hp_txt"]
		var hf: ColorRect = r["hp_fill"]
		var rf: ColorRect = r["rage_fill"]
		# ㉝：名字后面缀上排位——让"站位"在场上看得见（越前排的能力交给怪那边表达）
		# ⚠ 取下标要用 String 显式标注：["前","中","后"][i] 在 GDScript 里被当成
		#   Variant，:= 推不出类型会报 "Cannot infer the type"
		var row_names: Array = ["前", "中", "后"]
		var row_cn: String = str(row_names[clampi(int(m.get("row", 0)), 0, 2)])
		nm.text = str(m["name"]) + "〔" + row_cn + "排〕"
		ht.text = str(m["hp"]) + " / " + str(m["max"])
		hf.size.x = 200.0 * clampf(float(m["hp"]) / float(maxi(1, int(m["max"]))), 0.0, 1.0)
		hf.color = GREEN if int(m["hp"]) > 0 else Color(0.55, 0.52, 0.50, 0.60)
		rf.size.x = 200.0 * clampf(float(m["rage"]) / 100.0, 0.0, 1.0)
		# v52：状态那一行（颜色跟着第一条状态走；没有就隐藏）
		var stq: Label = r.get("st", null)
		if stq != null:
			var sln := _st_line(m)
			if sln == "":
				stq.visible = false
			else:
				stq.visible = true
				stq.text = sln
				var chip: Array = St.chips(m)
				stq.add_theme_color_override("font_color",
					St.col_of(str((chip[0] as Dictionary).get("id", "burn"))) if not chip.is_empty() else INK)
		# v54：小图标
		var ch = r.get("chip", null)
		if ch != null:
			ch.set_unit(m)
			ch.visible = ch.count() > 0
	if _log_lb != null:
		_log_lb.text = "\n".join(PackedStringArray(_log))
