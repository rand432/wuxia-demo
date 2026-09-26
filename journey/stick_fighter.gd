extends Node2D
# ============================================================
# 侠客火柴人 v15（水墨版）：淡墨晕 + 浓墨主笔 + 飞白 + 墨痕残影
# 招式数据在 move_db.gd；站姿/倒地/绘制都在本文件
# 角度单位：度。0=右（面朝方向），90=上，-90=下
# ============================================================

const MoveDb := preload("res://move_db.gd")

var body_color := Color(0.36, 0.64, 0.96)
var hat_color := Color(0.74, 0.60, 0.40)
var hat_edge_color := Color(0.38, 0.29, 0.17)
var cape_color := Color(0.26, 0.30, 0.44)
var hair_color := Color(0.15, 0.14, 0.19, 0.95)
var sash_color := Color(0.80, 0.60, 0.26, 0.95)
var scabbard_color := Color(0.20, 0.19, 0.24)
var blade_color := Color(0.82, 0.84, 0.87)
var tassel_color := Color(0.78, 0.26, 0.22)
var wood_color := Color(0.45, 0.31, 0.20)
var wrap_color := Color(0.90, 0.93, 0.97, 0.9)
var ink := Color(0.13, 0.12, 0.14)
var paper_color := Color(0.93, 0.90, 0.83)
# v57：暗器那条线的两色——腰囊（皮子）与镖尾红绸
var pouch_color := Color(0.31, 0.24, 0.18)
var fletch_color := Color(0.74, 0.26, 0.22)

const OW := 2.0            # 武器墨边宽
const OW_W := 1.2

# 装备：sword / dual / dagger / spear / anqi(暗器，原"棍") / fist
var weapon_type := "sword"
var hat_type := "douli"       # douli / toujin / none
var cape_type := "short"      # short / long / none

var spring_k := 380.0
# v63f2（用户："修理了好几个版本了"）：**基座弹簧**一起上临界阻尼——v63f 只改了招式/收招两处，
#   这处待机/走路的基座还是老 27（ζ≈0.69 欠阻尼）：走路摆腿会带回摆、收招回站姿会颤一下。
#   d=39 对 k=380 正好 ζ≈1.0：到位即停、零过冲。
var spring_d := 39.0
# v61（用户："攻速和多段导致人物动画抽搐"）：弹簧积分里的**速度上限**。
#   招式按 move_speed 压缩时间轴时（见 play_move 的 v61 段），k/d 会一起放大，
#   角速度也跟着变大——上限必须同比例抬，否则"姿势到位"被这个 clamp 卡住，
#   表现成"抬到一半停一下再走"（另一种抽搐）。
var vel_cap := 1400.0

const TORSO_LEN := 46.0
const HEAD_R := 18.0
const UARM := 28.0
const FARM := 24.0
const THIGH := 36.0
const SHIN := 34.0

var tgt: Array[float] = []
var cur: Array[float] = []
var vel: Array[float] = []

const T_TORSO := 0
const T_ARM_FU := 1
const T_ARM_FL := 2
const T_ARM_BU := 3
const T_ARM_BL := 4
const T_LEG_FU := 5
const T_LEG_FL := 6
const T_LEG_BU := 7
const T_LEG_BL := 8

var hip := Vector2(0, -68)
var sword_drawn := false
var _move_gen := 0
var move_db: Dictionary = {}
# ㊿x：这个人的"位移补间"只留一条（见 push_move_x / push_move_to）
var _move_tw: Tween = null
var _move_busy := false
# ㊿x2：这条位移序列建在哪一帧 / 大约跑到什么时候（毫秒）——决定"能不能追加、要不要排队"
var _move_frame := -1
var _move_end_ms := 0

var _t := 0.0
var _phase := 0.0
var _last_gpos := Vector2.ZERO
var _local_vel := Vector2.ZERO
var _tail: Array = []
var _sash: Array = []
var _cape: Array = []
var _trail: Array = []
var _trail_len := 0

func _init() -> void:
	for i in 9:
		tgt.append(0.0)
		cur.append(0.0)
		vel.append(0.0)
	# v63g（用户："多人重叠的时候引发的抽搐？"）：待机摇摆相位**全队统一**（都从 0 开始）——
	#   以前每人随机相位 ✗ 三人凑近时各晃各的、肢体交叠处看着像乱抖 ✗ 同步后三人一起呼吸 ✓
	_phase = 0.0

func _ready() -> void:
	move_db = MoveDb.build()
	reset_pose()
	for i in cur.size():
		cur[i] = tgt[i]
		vel[i] = 0.0
	for i in 4:
		_tail.append(Vector2(-22.0 - float(i) * 10.0, -34.0 + float(i) * 7.0))
	for i in 3:
		_sash.append(Vector2(-12.0 - float(i) * 9.0, -8.0 + float(i) * 6.0))
	for ci in 2:
		var chain := PackedVector2Array()
		for i in 5:
			chain.append(Vector2(-8.0 - float(ci) * 3.0 - float(i) * 6.0, -14.0 + float(i) * 14.0))
		_cape.append(chain)
	_last_gpos = global_position
	_update_cloth(5.0)
	queue_redraw()

func face(dir: int) -> void:
	scale = Vector2(float(dir), 1.0)

# ============ ㊿x：同一个人的位移永远只有一条在跑（防"抽搐"） ============
# 病根：同一个节点上**同时**跑两条 position 补间，每帧互相覆盖、来回弹，
#   画面上就是"角色抽搐"。多人对打最容易撞上——
#   · 出村战斗：身法快出一截时会在一手里连叫 2~3 次 _lunge（同一帧），
#     首领关 3 只怪同一手打同一个人，又是 2~3 次 _knock；
#   · 游历决斗：挨打抖动 + 冲上去/退回来，也可能是同一个人身上两条。
#
# 两套语义，按"调用方等不等这条补间"分：
#   · move_seq() —— **起一条新的**，先把上一条掐掉（后来者赢）。
#     给"一手连打几下"这种同帧连叫用：出村战斗的 _lunge/_knock/_bob_only。
#     代价是同一手里只演最后一下位移（伤害数字与战报照旧逐下报）。
#     ⚠ 只许给**不 await** 的地方用：killed 的补间不发 finished，await 它会永远卡住。
#   · push_move_x / push_move_to —— **接在后面**（不掐前面的）。
#     给游历决斗那些 `await tw.finished` 的冲上去/退回来用：绝不打断，await 安全。
#   ⚠ 只排"位移"；rotation / modulate / scale 各用各的补间，别混进来。
#   （_move_busy / _move_tw 的声明在文件上面 61~62 行——这里**不再重复声明**，
#     重复声明是 Godot 的硬报错："has the same name as a previously declared variable"）

# 起一条新的位移序列（掐掉上一条）
func move_seq() -> Tween:
	stop_moves()
	_move_tw = create_tween()
	_move_frame = Engine.get_process_frames()
	_move_end_ms = Time.get_ticks_msec()
	_move_busy = true
	_move_tw.finished.connect(_on_move_done.bind(_move_tw))
	return _move_tw

# ㊿x2（用户报的："游历战斗卡住 / Cannot call method 'set_trans' on a null value"）：
#   病根——**Godot 只允许往"还没开跑"的补间上追加**。补间一旦开始推进，再调
#     tween_property 就直接返回 null（引擎原话："Can't append to a Tween that has
#     started. Use stop() first."），而紧跟其后的 `.set_trans(...)` 就成了
#     "Cannot call method 'set_trans' on a null value"——函数当场中断，游历决斗里
#     "挨打抖一下"的第二次位移就撞在这上面（日志里的栈：push_move_to ← _foe_show_hit），
#     一手打完战斗就卡死。_move_busy 那条判据不够：is_valid() 对"已经开跑"的补间仍是 true。
#
#   现在分三种情形：
#     · 同帧、还没开跑 → 直接追加（"一手连打几下"的排队手感，且不会抽搐）
#     · 上一条**还在跑**（跨帧） → 另起一条、先用 interval 等它跑完再动：
#       绝不 kill 上一条——killed 的补间不发 finished，别处 `await tw.finished` 会永远卡住
#     · 空着 → 起新的一条
func _move_can_append() -> bool:
	return _move_busy and _move_tw != null and _move_tw.is_valid() \
		and Engine.get_process_frames() == _move_frame

func _move_queue(dur: float) -> Tween:
	if _move_can_append():
		_move_end_ms += int(round(dur * 1000.0))
		return _move_tw
	var now := Time.get_ticks_msec()
	if _move_busy and _move_tw != null and _move_tw.is_valid() and now < _move_end_ms:
		var wait := float(_move_end_ms - now) / 1000.0 + 0.02   # 多留一帧的余量
		var tw := create_tween()
		tw.tween_interval(wait)
		_move_tw = tw
		_move_frame = Engine.get_process_frames()
		_move_end_ms += int(round((wait + dur) * 1000.0))
		_move_busy = true
		tw.finished.connect(_on_move_done.bind(tw))
		return tw
	return move_seq()

# 只有"当前那条"跑完才算空出来——排队期间上一条先跑完，不能把标志清掉
func _on_move_done(tw: Tween) -> void:
	if is_same(tw, _move_tw):
		_move_busy = false

func push_move_x(to_x: float, dur: float, trans: Tween.TransitionType = Tween.TRANS_QUAD, ease_t: Tween.EaseType = Tween.EASE_OUT) -> Tween:
	var tw := _move_queue(dur)
	var pt = tw.tween_property(self, "position:x", to_x, dur)
	if pt == null:
		# 兜底（正常走不到）：这条补间不让追加了——另起一条，同样不 kill 前面的
		tw = create_tween()
		_move_tw = tw
		_move_frame = Engine.get_process_frames()
		_move_end_ms = Time.get_ticks_msec() + int(round(dur * 1000.0))
		_move_busy = true
		tw.finished.connect(_on_move_done.bind(tw))
		pt = tw.tween_property(self, "position:x", to_x, dur)
	if pt != null:
		pt.set_trans(trans).set_ease(ease_t)
	return tw

func push_move_to(to_p: Vector2, dur: float, trans: Tween.TransitionType = Tween.TRANS_QUAD, ease_t: Tween.EaseType = Tween.EASE_OUT) -> Tween:
	var tw := _move_queue(dur)
	var pt = tw.tween_property(self, "position", to_p, dur)
	if pt == null:
		tw = create_tween()
		_move_tw = tw
		_move_frame = Engine.get_process_frames()
		_move_end_ms = Time.get_ticks_msec() + int(round(dur * 1000.0))
		_move_busy = true
		tw.finished.connect(_on_move_done.bind(tw))
		pt = tw.tween_property(self, "position", to_p, dur)
	if pt != null:
		pt.set_trans(trans).set_ease(ease_t)
	return tw

# 掐掉还没走完的位移（倒地、离场、或"后来者赢"的新动作）
func stop_moves() -> void:
	if _move_tw != null and _move_tw.is_valid():
		_move_tw.kill()
	_move_tw = null
	_move_busy = false
	_move_frame = -1
	_move_end_ms = 0

func set_equipment(weapon: String, hat: String, cape: String) -> void:
	if ["sword", "dual", "dagger", "spear", "anqi", "fist"].has(weapon):
		weapon_type = weapon
	if ["douli", "toujin", "none"].has(hat):
		hat_type = hat
	if ["short", "long", "none"].has(cape):
		cape_type = cape
	reset_pose()

func set_weapon(w: String) -> void:
	if not ["sword", "dual", "dagger", "spear", "anqi", "fist"].has(w):
		return
	if weapon_type != w:
		weapon_type = w
		reset_pose()

# ============ 五套站姿 ============

func reset_pose() -> void:
	sword_drawn = false
	tgt[T_TORSO] = 86.0
	tgt[T_ARM_BU] = -110.0
	tgt[T_ARM_BL] = -95.0
	match weapon_type:
		"spear":
			tgt[T_TORSO] = 88.0
			tgt[T_ARM_FU] = -40.0
			tgt[T_ARM_FL] = -70.0
			tgt[T_ARM_BU] = -100.0
			tgt[T_ARM_BL] = -75.0
		"dual":
			tgt[T_TORSO] = 84.0
			tgt[T_ARM_FU] = -58.0
			tgt[T_ARM_FL] = -92.0
			tgt[T_ARM_BU] = -96.0
			tgt[T_ARM_BL] = -72.0
		"dagger":
			tgt[T_TORSO] = 92.0
			tgt[T_ARM_FU] = -78.0
			tgt[T_ARM_FL] = -55.0
			tgt[T_ARM_BU] = -62.0
			tgt[T_ARM_BL] = -130.0
		"anqi":
			# v57：暗器站姿——侧身、右手扣着镖藏在腰侧（跟剑的"手往前伸"明显不同）
			tgt[T_TORSO] = 96.0
			tgt[T_ARM_FU] = -52.0
			tgt[T_ARM_FL] = 46.0
			tgt[T_ARM_BU] = -84.0
			tgt[T_ARM_BL] = -96.0
		"fist":
			tgt[T_TORSO] = 88.0
			tgt[T_ARM_FU] = -18.0
			tgt[T_ARM_FL] = -8.0
			tgt[T_ARM_BU] = -55.0
			tgt[T_ARM_BL] = -135.0
		_:
			tgt[T_ARM_FU] = -72.0
			tgt[T_ARM_FL] = -118.0
	match weapon_type:
		"dagger":
			tgt[T_LEG_FU] = -66.0
			tgt[T_LEG_FL] = -94.0
			tgt[T_LEG_BU] = -108.0
			tgt[T_LEG_BL] = -96.0
		"fist":
			tgt[T_LEG_FU] = -70.0
			tgt[T_LEG_FL] = -82.0
			tgt[T_LEG_BU] = -102.0
			tgt[T_LEG_BL] = -94.0
		"dual":
			tgt[T_LEG_FU] = -76.0
			tgt[T_LEG_FL] = -86.0
			tgt[T_LEG_BU] = -116.0
			tgt[T_LEG_BL] = -110.0
		_:
			tgt[T_LEG_FU] = -74.0
			tgt[T_LEG_FL] = -84.0
			tgt[T_LEG_BU] = -112.0
			tgt[T_LEG_BL] = -108.0

# ============ 招式播放 ============

# v57（用户："可以 你继续"）：**把招式播放接上**——原来 `play_move()` 全项目一处都没调，
#   招式表（move_db）是死的。现在战斗里普攻会真的播姿势，所以要给个倍速口：
#   招式表是按"单看一招"排的（起手 0.10~0.55 秒、全程 0.7~1.4 秒），
#   放进战斗的连续出手里整体要快一档，见 duel_battle.MOVE_SPEED。
var move_speed := 1.0

# 这一招要多久（给战斗算"什么时候该挨打"用）
#   windup ＝ 第 1 步的定格（＝起手，跟 move_db 的姿势严格同源，表改了这个跟着改）
#   total  ＝ 各步之和（播完才会进收招）
#   ⚠ 除以同一个 speed，所以战斗的等待与姿势的时间轴**不会各走各的**
func move_time(move_id: String, speed := 1.0) -> Dictionary:
	var sp := maxf(0.25, speed)
	var table: Dictionary = move_db.get(weapon_type, {})
	var mv := move_id
	if not table.has(mv):
		mv = str(table.keys()[0]) if not table.is_empty() else ""
	if mv == "" or not table.has(mv):
		return {"windup": 0.20, "total": 0.20, "speed": sp}
	var steps: Array = table[mv]
	var sum := 0.0
	for s_v in steps:
		sum += float((s_v as Array)[1])
	return {
		"windup": float((steps[0] as Array)[1]) / sp,
		"total": sum / sp,
		"speed": sp,
	}

func _finish_move(gen: int) -> void:
	if gen != _move_gen:
		return
	# v61：收招这一段也按倍速缩（与 play_move 同一套弹簧缩放，别一边硬一边软）
	# v63（玩家反馈 1号/2号："加了多人上阵后才抽搐、现在走路都带抽搐"）：
	#   弹簧原口径 ζ≈0.69（欠阻尼 ✗）——目标一跳就超调、来回荡 ✗ 人多+动画多之后
	#   越来越显。拉到 ζ≈0.87（d 27→34）——几乎不过冲，抽那一下没了。
	# v63f（用户："攻击时各种动作摇晃摆动，收招后也抽搐晃动"）：还不够 ✗
	#   直接上**临界阻尼**（d 34→39，ζ≈1.0）——到位即停、零过冲零回摆。
	var sp := maxf(0.25, move_speed)
	spring_k = 380.0 * sp * sp
	spring_d = 39.0 * sp
	vel_cap = 1400.0 * sp
	var seq: Array = MoveDb.end_seq(weapon_type)
	for step in seq:
		if gen != _move_gen:
			return
		_pose(step[0])
		await get_tree().create_timer(maxf(float(step[1]) / sp, 0.045)).timeout
		if step.size() > 2 and bool(step[2]):
			sword_drawn = false
	if gen != _move_gen:
		return
	reset_pose()
	await get_tree().create_timer(maxf(0.30 / sp, 0.06)).timeout

func play_move(move_id: String, speed := 1.0) -> void:
	var wid: String = weapon_type
	if not move_db.has(wid):
		wid = "sword"
	var table: Dictionary = move_db[wid]
	var mv: String = move_id
	if not table.has(mv):
		# 表里没有这一招：退回第一招（⚠ 缺招式请看 move_db 顶上的注释，别让它默默退）
		mv = str(table.keys()[0])
	move_speed = maxf(0.25, speed)
	_move_gen += 1
	var gen: int = _move_gen
	sword_drawn = true
	var steps: Array = table[mv]
	# v61（用户："攻速和多段导致人物动画抽搐"）——**弹簧要跟时间轴一起缩**。
	#   招式表按"单看一招"排（每步 0.05~0.55 秒），放进战斗里整体倍速（游历 MOVE_SPEED=1.8、
	#   出村快进还要更快）。原来只缩了 create_timer，**弹簧还是原来那副软硬**：
	#   时间轴缩到 1/s 之后，每步只剩几十毫秒，弹簧却要 0.2~0.3 秒才稳下来，
	#   于是四肢在"上一个姿势 → 下一个姿势"之间来回反弹——画面上就是抽搐。
	#   弹簧的时间常数：响应 ∝ 1/√k、阻尼比 ∝ d/(2√k)。要让姿势在 1/s 的时间里到位，
	#   就取 **k×s²、d×s**（阻尼比不变 → 只变快、不会振）；速度上限同比例抬。
	#   每步最短停留 0.045 秒：再快也得给四肢一点位移时间，否则就是"抖一下"。
	var sp := maxf(0.25, move_speed)
	for step in steps:
		if gen != _move_gen:
			return
		var pose: Dictionary = step[0]
		var hold: float = float(step[1])
		var bk := float(step[2]) if step.size() > 2 else 380.0
		var bd := float(step[3]) if step.size() > 3 else 39.0   # v63f：默认阻尼 27→39（临界阻尼，零回摆）
		# v63l（取证数据定案——躯干/四肢逐帧 ±70° 猛甩的病因）：
		#   表里显式写的 bd 大多欠阻尼（ζ≈0.65~0.75）。平时没事，一卡帧（delta 封顶 1/30）
		#   离散极点 |λ|>1 弹簧失稳，四肢以 vel_cap 满速来回甩 = 抽搐。
		#   修三件一起上：①强制**临界阻尼**（d = 2√k，离散系统恒稳）；
		#   ②招式播放期间速度上限 1400 → 300（逐帧摆幅封顶 ≈18°/帧 @30fps——
		#     满速猛甩的"油门"掐死）；③每步最短停留 0.045 → 0.10（给弹簧落位时间）。
		spring_k = bk * sp * sp
		spring_d = maxf(bd, 2.0 * sqrt(maxf(bk, 1.0))) * sp
		vel_cap = 300.0 * sp
		_pose(pose)
		await get_tree().create_timer(maxf(hold / sp, 0.10)).timeout
	if gen != _move_gen:
		return
	await _finish_move(gen)

# v61：挨打/闪避这两种"一次性定格"用**代号**收尾——
#   病根：多段武学（2~3 段，每段 0.12 秒）连着叫 play_hit()，每一次都在 0.16 秒后
#   无条件 reset_pose()。于是"第 2 段刚把姿势打出去"，第 1 段那支计时器到点了，
#   把四肢**掰回站姿**——第 2 段接着再打出去。一来一回就是"挨打抽搐"。
#   现在只有**最后那一次**（_move_gen 还等于自己那一代号）才有资格收尾。
func play_hit() -> void:
	_move_gen += 1
	var gen := _move_gen
	spring_k = 380.0
	spring_d = 39.0   # v63f2：挨打定格也上临界阻尼（老 27 欠阻尼，每挨一下都带回摆）
	vel_cap = 1400.0
	_pose({T_TORSO: 104.0, T_ARM_FU: -50.0, T_ARM_FL: -84.0, T_ARM_BU: -108.0, T_LEG_FU: -56.0, T_LEG_FL: -112.0})
	await get_tree().create_timer(0.16).timeout
	if gen != _move_gen:
		return
	reset_pose()

func play_dodge() -> void:
	_move_gen += 1
	var gen := _move_gen
	spring_k = 380.0
	spring_d = 39.0   # v63f2：闪避定格同款——临界阻尼，不留回摆
	vel_cap = 1400.0
	_pose({T_TORSO: 96.0, T_ARM_FU: -64.0, T_ARM_FL: -100.0, T_LEG_FU: -64.0, T_LEG_FL: -104.0})
	await get_tree().create_timer(0.18).timeout
	if gen != _move_gen:
		return
	reset_pose()

# ============ 倒地 ============

func play_down() -> void:
	_move_gen += 1
	spring_k = 320.0
	spring_d = 36.0   # v63f2：倒地也是临界阻尼（2√320≈35.8；老 25 欠阻尼，倒下还在晃）
	match weapon_type:
		"sword":
			_pose({T_TORSO: 98.0, T_ARM_FU: -80.0, T_ARM_FL: -85.0, T_ARM_BU: -60.0, T_ARM_BL: -20.0, T_LEG_FU: -40.0, T_LEG_FL: -128.0, T_LEG_BU: -122.0, T_LEG_BL: -60.0})
		"dual":
			_pose({T_TORSO: 96.0, T_ARM_FU: -125.0, T_ARM_FL: -165.0, T_ARM_BU: -118.0, T_ARM_BL: -158.0, T_LEG_FU: -46.0, T_LEG_FL: -120.0, T_LEG_BU: -128.0, T_LEG_BL: -64.0})
		"dagger":
			_pose({T_TORSO: 112.0, T_ARM_FU: -40.0, T_ARM_FL: -122.0, T_ARM_BU: -75.0, T_ARM_BL: -142.0, T_LEG_FU: -34.0, T_LEG_FL: -132.0, T_LEG_BU: -132.0, T_LEG_BL: -88.0})
		"spear":
			_pose({T_TORSO: 92.0, T_ARM_FU: -34.0, T_ARM_FL: -88.0, T_ARM_BU: -95.0, T_ARM_BL: -55.0, T_LEG_FU: -36.0, T_LEG_FL: -130.0, T_LEG_BU: -124.0, T_LEG_BL: -58.0})
		_:
			_pose({T_TORSO: 64.0, T_ARM_FU: -12.0, T_ARM_FL: -30.0, T_ARM_BU: -110.0, T_ARM_BL: -140.0, T_LEG_FU: -50.0, T_LEG_FL: -110.0, T_LEG_BU: -118.0, T_LEG_BL: -70.0})
	sword_drawn = true

func _pose(d: Dictionary) -> void:
	for k in d:
		tgt[k] = d[k]

# ============ 每帧 ============

func _process(delta: float) -> void:
	# v62y（用户："多人的动作还是会抽搐"）：**帧差保护**——半隐式欧拉弹簧对"卡帧"很敏感：
	#   一帧 hitch 就吃进超大的 delta ✗ 弹簧超调、人物猛抖一下 ✗（人越多越容易卡 ✗ 所以"多人抽搐"）。
	#   把单帧步长封顶到 1/30 秒：正常 60fps 不受影响，卡帧时弹簧不炸、待机摆动不抽。
	delta = minf(delta, 1.0 / 30.0)
	# v63l2（第二份取证：躯干每帧 ±35° **递增**猛甩——离散弹簧在大 k×大 dt 下越过稳定区，
	#   k·dt² ≥ 4 之后连"临界阻尼"都振荡发散（λ≈-2，逐帧翻号、越翻越大）。
	#   病根在**单步欧拉**本身，跟 k/d 参数无关。改成**子步积分**：每步 h ≤ 1/120 秒，
	#   表内任何 k 都满足 k·h² ≪ 4——恒稳、逐帧单调收敛，卡帧只是"慢"，永远不会翻。
	var substeps := int(ceil(delta / (1.0 / 120.0)))
	var h: float = delta / float(maxi(1, substeps))
	for s in substeps:
		for i in cur.size():
			# v63c（用户："这人物动不动就跳霹雳舞"）：角度通道（0~8）的弹簧**要走最短弧**——
			#   翻面时目标跨过 180° 边界，老写法直接奔长弧绕大圈 ✗ 四肢就跟跳舞一样甩一整圈 ✗。
			var diff: float = tgt[i] - cur[i]
			if i <= 8:
				diff = fposmod(diff + 180.0, 360.0) - 180.0
			var acc: float = diff * spring_k - vel[i] * spring_d
			vel[i] = clampf(vel[i] + acc * h, -vel_cap, vel_cap)
			cur[i] += vel[i] * h
	_t += delta

	var gv: Vector2 = (global_position - _last_gpos) / maxf(delta, 0.001)
	_last_gpos = global_position
	var facing: float = signf(scale.x)
	if facing == 0.0:
		facing = 1.0
	# v63（玩家反馈："走路都带抽搐"）：位移 tween 起步/收尾那一帧速度尖峰 → 腿被猛拽一下。
	#   平滑系数 0.5（两帧就响应）→ 0.22（五六帧慢慢跟上）——走路不再抽，起步只是稍缓。
	_local_vel = _local_vel.lerp(gv * facing, 0.22)
	_update_cloth(delta)

	if sword_drawn:
		_push_trail()
	elif _trail.size() > 0:
		_trail.pop_front()

	queue_redraw()

func _weapon_tips() -> Array:
	var j: Dictionary = _joints()
	var hand_f: Vector2 = j["hand_f"]
	var hand_b: Vector2 = j["hand_b"]
	match weapon_type:
		"sword":
			return [hand_f + _dir(deg_to_rad(cur[T_ARM_FL] + 8.0)) * 68.0]
		"dual":
			return [
				hand_f + _dir(deg_to_rad(cur[T_ARM_FL] + 10.0)) * 66.0,
				hand_b + _dir(deg_to_rad(cur[T_ARM_BL] + 10.0)) * 66.0,
			]
		"dagger":
			return [hand_f + _dir(deg_to_rad(cur[T_ARM_FL] + 10.0)) * 30.0]
		"spear":
			return [hand_f + _dir(deg_to_rad(cur[T_ARM_FL] + 4.0)) * 102.0]
		"anqi":
			return [hand_f + _dir(deg_to_rad(cur[T_ARM_FL] + 10.0)) * 30.0]
		"fist":
			return [hand_f]
	return []

func _push_trail() -> void:
	var tips: Array = _weapon_tips()
	if tips.size() == 0:
		return
	if _trail_len != tips.size():
		_trail.clear()
		_trail_len = tips.size()
	_trail.push_back(tips)
	while _trail.size() > 10:
		_trail.pop_front()

func _draw_trails() -> void:
	var n: int = _trail.size()
	if _trail_len <= 0 or n < 2:
		return
	for k in _trail_len:
		for i in range(n - 1):
			var e0: Array = _trail[i]
			var e1: Array = _trail[i + 1]
			if k >= e0.size() or k >= e1.size():
				continue
			var p0: Vector2 = e0[k]
			var p1: Vector2 = e1[k]
			var f: float = float(i + 1) / float(n)
			var w: float = lerpf(1.0, 7.0, f)
			var a: float = 0.03 + 0.20 * f
			draw_line(p0, p1, Color(ink.r, ink.g, ink.b, a), w, true)

func _update_cloth(delta: float) -> void:
	var j: Dictionary = _joints()
	var head_c: Vector2 = j["head"]
	var hip_pos: Vector2 = j["hip"]
	var blend := 1.0 - exp(-12.0 * delta)
	var lag: Vector2 = _local_vel.limit_length(320.0) * -0.025

	var cape_scale := 1.0
	if cape_type == "long":
		cape_scale = 1.45
	elif cape_type == "none":
		cape_scale = 0.0

	var base_t: Vector2 = head_c + Vector2(-11.0, -2.0)
	var p_t: Vector2 = base_t
	for i in _tail.size():
		p_t += Vector2(-9.0, 4.5).rotated(deg_to_rad(sin(_t * 3.0 + float(i) * 0.9) * 12.0))
		p_t += lag * (0.6 + 0.4 * float(i))
		_tail[i] = (_tail[i] as Vector2).lerp(p_t, blend)

	var base_s: Vector2 = hip_pos + Vector2(-3.0, -3.0)
	var p_s: Vector2 = base_s
	for i in _sash.size():
		p_s += Vector2(-8.5, 5.0).rotated(deg_to_rad(sin(_t * 2.6 + float(i) * 1.1 + 1.0) * 14.0))
		p_s += lag * (0.5 + 0.5 * float(i))
		_sash[i] = (_sash[i] as Vector2).lerp(p_s, blend)

	for ci in _cape.size():
		var chain: PackedVector2Array = _cape[ci]
		var anchor: Vector2 = hip_pos + Vector2(-3.0 + float(ci) * 3.0, -40.0)
		chain[0] = anchor
		var p_c: Vector2 = anchor
		for i in range(1, chain.size()):
			p_c += Vector2(-5.0 - float(ci) * 2.0, 14.0 + float(ci) * 2.5) * cape_scale
			p_c += lag * (0.35 + 0.3 * float(i))
			chain[i] = (chain[i] as Vector2).lerp(p_c, blend)
		_cape[ci] = chain

func _joints() -> Dictionary:
	# v63e（用户："攻击时手中武器无意识上下摆动"）：出招期间把待机摇摆/起伏**压掉**——
	#   不然手的上下晃会顺着手臂带进武器，招式看着像在抖。
	var moving := _move_tw != null and _move_tw.is_valid()
	var sway: float = 0.0 if moving else sin(_t * 0.9 + _phase)
	var bob: float = 0.0 if moving else sin(_t * 1.7 + _phase) * 2.2
	var hip_pos: Vector2 = hip + Vector2(sway * 1.6, bob)
	var torso_a: float = cur[T_TORSO] + sway * 1.3
	var neck: Vector2 = hip_pos + _dir(deg_to_rad(torso_a)) * TORSO_LEN
	var head_c: Vector2 = neck + _dir(deg_to_rad(torso_a)) * (HEAD_R + 3.0)
	var shoulder: Vector2 = neck + _dir(deg_to_rad(torso_a)) * 2.0 - Vector2(0.0, 2.0)

	var afu: float = cur[T_ARM_FU] + sway * 1.6
	var afl: float = cur[T_ARM_FL] - sway * 1.2
	var abu: float = cur[T_ARM_BU] + sway * 1.2
	var abl: float = cur[T_ARM_BL] - sway * 1.4

	var elbow_f: Vector2 = shoulder + _dir(deg_to_rad(afu)) * UARM
	var hand_f: Vector2 = elbow_f + _dir(deg_to_rad(afl)) * FARM
	var elbow_b: Vector2 = shoulder + _dir(deg_to_rad(abu)) * UARM
	var hand_b: Vector2 = elbow_b + _dir(deg_to_rad(abl)) * FARM

	var knee_f: Vector2 = hip_pos + _dir(deg_to_rad(cur[T_LEG_FU])) * THIGH
	var foot_f: Vector2 = knee_f + _dir(deg_to_rad(cur[T_LEG_FL])) * SHIN
	var knee_b: Vector2 = hip_pos + _dir(deg_to_rad(cur[T_LEG_BU])) * THIGH
	var foot_b: Vector2 = knee_b + _dir(deg_to_rad(cur[T_LEG_BL])) * SHIN
	return {
		"hip": hip_pos, "neck": neck, "shoulder": shoulder, "head": head_c,
		"elbow_f": elbow_f, "hand_f": hand_f, "elbow_b": elbow_b, "hand_b": hand_b,
		"knee_f": knee_f, "foot_f": foot_f, "knee_b": knee_b, "foot_b": foot_b,
	}

# ============ 笔触 ============

func _brush(a: Vector2, b: Vector2, bow: float, ra: float, rb: float, col: Color, wash: bool = true, dry: bool = false) -> void:
	if wash:
		var wc := col
		wc.a = col.a * 0.20
		_curve(a, b, bow, ra * 1.55, rb * 1.55, wc)
	_curve(a, b, bow, ra, rb, col)
	if dry:
		_dry(a, b, ra)

func _dry(a: Vector2, b: Vector2, ra: float) -> void:
	var seg: Vector2 = b - a
	if seg.length() < 8.0 or ra < 2.5:
		return
	var d: Vector2 = seg.normalized()
	var n: Vector2 = Vector2(-d.y, d.x)
	var pc := Color(paper_color.r, paper_color.g, paper_color.b, 0.20)
	var g0: Vector2 = a.lerp(b, 0.24)
	var g1: Vector2 = a.lerp(b, 0.80)
	draw_line(g0 + n * ra * 0.35, g1 + n * ra * 0.18, pc, ra * 0.22, true)
	draw_line(a.lerp(b, 0.34) + n * -ra * 0.10, a.lerp(b, 0.68) + n * -ra * 0.20, Color(paper_color.r, paper_color.g, paper_color.b, 0.14), ra * 0.16, true)

func _capsule(a: Vector2, b: Vector2, ra: float, rb: float, col: Color, ow: float = 0.0) -> void:
	if ow > 0.0:
		_capsule_raw(a, b, ra + ow, rb + ow, ink)
	_capsule_raw(a, b, ra, rb, col)

func _capsule_raw(a: Vector2, b: Vector2, ra: float, rb: float, col: Color) -> void:
	var seg: Vector2 = b - a
	if seg.length() < 0.01:
		draw_circle(a, maxf(ra, rb), col)
		return
	var th: float = seg.angle()
	var pts := PackedVector2Array()
	for i in 6:
		var ang: float = th - PI * 0.5 + PI * float(i) / 5.0
		pts.append(b + Vector2(cos(ang), sin(ang)) * rb)
	for i in 6:
		var ang2: float = th + PI * 0.5 + PI * float(i) / 5.0
		pts.append(a + Vector2(cos(ang2), sin(ang2)) * ra)
	draw_colored_polygon(pts, col)

func _curve(a: Vector2, b: Vector2, bow: float, ra: float, rb: float, col: Color, ow: float = 0.0) -> void:
	var seg: Vector2 = b - a
	if seg.length() < 0.5:
		_capsule(a, b, ra, rb, col, ow)
		return
	var dirn: Vector2 = seg.normalized()
	var nrm: Vector2 = Vector2(-dirn.y, dirn.x)
	var ctrl: Vector2 = (a + b) * 0.5 + nrm * bow * 2.0
	var n := 4
	if ow > 0.0:
		var pv: Vector2 = a
		for i in range(1, n + 1):
			var t: float = float(i) / float(n)
			var p: Vector2 = a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
			var t0: float = float(i - 1) / float(n)
			_capsule_raw(pv, p, lerpf(ra + ow, rb + ow, t0), lerpf(ra + ow, rb + ow, t), ink)
			pv = p
	var prev: Vector2 = a
	for i in range(1, n + 1):
		var t2: float = float(i) / float(n)
		var p2: Vector2 = a.lerp(ctrl, t2).lerp(ctrl.lerp(b, t2), t2)
		var t02: float = float(i - 1) / float(n)
		_capsule_raw(prev, p2, lerpf(ra, rb, t02), lerpf(ra, rb, t2), col)
		prev = p2

func _dot(c: Vector2, r: float, col: Color) -> void:
	var wc := col
	wc.a = col.a * 0.20
	draw_circle(c, r + 2.8, wc)
	draw_circle(c, r, col)

func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

# ============ 绘制 ============

func _draw() -> void:
	var j: Dictionary = _joints()
	var hip_pos: Vector2 = j["hip"]
	var neck: Vector2 = j["neck"]
	var shoulder: Vector2 = j["shoulder"]
	var head_c: Vector2 = j["head"]
	var elbow_f: Vector2 = j["elbow_f"]
	var hand_f: Vector2 = j["hand_f"]
	var elbow_b: Vector2 = j["elbow_b"]
	var hand_b: Vector2 = j["hand_b"]
	var knee_f: Vector2 = j["knee_f"]
	var foot_f: Vector2 = j["foot_f"]
	var knee_b: Vector2 = j["knee_b"]
	var foot_b: Vector2 = j["foot_b"]
	var back: Color = body_color.darkened(0.30)

	# 脚下墨影
	_ellipse(Vector2(0.0, 2.0), 30.0, 5.6, Color(ink.r, ink.g, ink.b, 0.09))
	_ellipse(Vector2(0.0, 1.0), 20.0, 3.8, Color(ink.r, ink.g, ink.b, 0.10))
	_ellipse(Vector2(0.0, 0.0), 11.0, 2.4, Color(ink.r, ink.g, ink.b, 0.12))

	# 后臂
	_brush(shoulder, elbow_b, -1.6, 6.0, 4.7, back, true, true)
	_brush(elbow_b, hand_b, 1.4, 4.7, 3.1, back, false, false)
	_dot(elbow_b, 4.7, back)
	_dot(hand_b, 3.2, back)
	if weapon_type == "dual":
		_draw_saber_in_hand(hand_b)
	if weapon_type == "fist":
		draw_arc(hand_b, 4.6, 0.0, TAU, 16, wrap_color, 2.0, true)

	# 后腿
	_brush(hip_pos, knee_b, 2.0, 7.8, 5.8, back, true, true)
	_brush(knee_b, foot_b, -1.6, 5.8, 4.0, back, false, false)
	_dot(knee_b, 5.8, back)
	_brush(foot_b, foot_b + Vector2(7.0, 0.0), 0.0, 4.0, 3.0, back, false, false)

	# 披风 / 发带 / 腰带
	_draw_cape(j)
	_draw_ponytail(j)
	_draw_sash(j)

	# 躯干
	_brush(hip_pos, neck, 1.2, 8.8, 6.4, body_color, true, true)

	# 头 / 脸 / 帽
	_draw_head(head_c)

	# 前腿
	_brush(hip_pos, knee_f, -1.8, 7.8, 5.8, body_color, false, true)
	_brush(knee_f, foot_f, 1.4, 5.8, 4.0, body_color, false, false)
	_dot(knee_f, 5.8, body_color)
	_brush(foot_f, foot_f + Vector2(7.0, 0.0), 0.0, 4.0, 3.0, body_color, false, false)

	# 前臂
	_brush(shoulder, elbow_f, 1.6, 6.0, 4.7, body_color, false, true)
	_brush(elbow_f, hand_f, -1.4, 4.7, 3.1, body_color, false, false)
	_dot(elbow_f, 4.7, body_color)
	_dot(hand_f, 3.2, body_color)
	if weapon_type == "fist":
		draw_arc(hand_f, 4.6, 0.0, TAU, 16, wrap_color, 2.0, true)

	# 武器
	if weapon_type == "dual":
		_draw_saber_in_hand(hand_f)
	elif weapon_type == "dagger":
		_draw_dagger_in_hand(hand_f)
	elif weapon_type == "fist":
		pass
	elif sword_drawn:
		_draw_weapon_in_hand(hand_f)
	else:
		if weapon_type == "spear":
			_draw_pole_idle(hand_f, true)
		elif weapon_type == "anqi":
			_draw_pouch_idle(hip_pos)          # v57：暗器不拿在手里——腰上挂个镖囊
		elif weapon_type == "sword":
			_draw_waist_sword(hip_pos)

	# 墨痕残影
	if sword_drawn and _trail.size() >= 2:
		_draw_trails()

func _draw_head(head_c: Vector2) -> void:
	var wc := body_color
	wc.a = body_color.a * 0.16
	draw_circle(head_c, HEAD_R * 1.42, wc)
	draw_circle(head_c, HEAD_R + 2.0, Color(ink.r, ink.g, ink.b, 0.50))
	draw_circle(head_c, HEAD_R, body_color)
	_draw_face(head_c)
	_draw_hat(head_c)

func _draw_face(head_c: Vector2) -> void:
	var ec := Color(0.10, 0.10, 0.14)
	draw_line(head_c + Vector2(0.5, -4.5), head_c + Vector2(9.5, -6.5), ec, 1.8, true)
	draw_line(head_c + Vector2(2.5, 0.0), head_c + Vector2(10.0, -1.5), ec, 2.6, true)

func _draw_cape(_j: Dictionary) -> void:
	if cape_type == "none":
		return
	var long_mode := cape_type == "long"
	var base_w: Array[float] = [12.0, 10.5, 9.0, 7.0, 5.0]
	if long_mode:
		base_w.assign([16.0, 14.0, 12.0, 9.5, 7.0])
	for ci in _cape.size():
		var chain: PackedVector2Array = _cape[ci]
		var col: Color = cape_color if ci != 1 else cape_color.darkened(0.15)
		col.a = 0.90 if ci != 1 else 0.80
		var widen: float = 2.0 if ci == 1 else 0.0
		if long_mode:
			widen += 3.0
		for i in range(1, chain.size()):
			var w0: float = (base_w[i - 1] + widen) * 0.5
			var w1: float = (base_w[i] + widen) * 0.5
			_brush(chain[i - 1], chain[i], 0.0, w0, w1, col, false, i >= 2)

func _draw_ponytail(j: Dictionary) -> void:
	var head_c: Vector2 = j["head"]
	var base: Vector2 = head_c + Vector2(-11.0, -2.0)
	var pts: Array = [base]
	pts.append_array(_tail)
	var w: Array[float] = [5.4, 4.4, 3.2, 2.2, 1.4]
	for i in range(pts.size() - 1):
		_brush(pts[i] as Vector2, pts[i + 1] as Vector2, 0.0, w[i] * 0.5, w[i + 1] * 0.5, hair_color, false, i == 0)
	draw_circle(base, 3.4, Color(0.78, 0.24, 0.20, 0.95))

func _draw_sash(j: Dictionary) -> void:
	var hip_pos: Vector2 = j["hip"]
	var base: Vector2 = hip_pos + Vector2(-3.0, -3.0)
	var pts: Array = [base]
	pts.append_array(_sash)
	var w: Array[float] = [4.6, 3.2, 2.2, 1.4]
	for i in range(pts.size() - 1):
		_brush(pts[i] as Vector2, pts[i + 1] as Vector2, 0.0, w[i] * 0.5, w[i + 1] * 0.5, sash_color, false, false)

func _draw_hat(head_c: Vector2) -> void:
	if hat_type == "toujin":
		var band_c: Vector2 = head_c + Vector2(0.0, -9.0)
		var band_col := Color(0.72, 0.20, 0.18)
		draw_line(band_c + Vector2(-15.0, 3.0), band_c + Vector2(15.0, -3.0), band_col, 6.0, true)
		draw_circle(band_c + Vector2(-15.0, 3.0), 3.6, band_col)
		return
	if hat_type != "douli":
		return
	var c: Vector2 = head_c + Vector2(1.0, -7.0)
	var rx := 26.0
	var ry := 9.0
	var cone := PackedVector2Array()
	cone.append(c + Vector2(-rx, 0.0))
	cone.append(c + Vector2(0.0, -27.0))
	cone.append(c + Vector2(rx, 0.0))
	draw_colored_polygon(cone, hat_color)
	draw_polyline(cone, hat_edge_color, 2.0, true)
	draw_line(c + Vector2(-rx, 0.0), c + Vector2(rx, 0.0), hat_edge_color, 2.0, true)
	var rim := PackedVector2Array()
	for k in 13:
		var a2: float = PI + PI * float(k) / 12.0
		rim.append(c + Vector2(cos(a2) * rx, sin(a2) * ry))
	draw_polyline(rim, hat_edge_color, 2.0, true)

func _draw_waist_sword(hip_pos: Vector2) -> void:
	var w: Vector2 = hip_pos + Vector2(6.0, -12.0)
	var d: Vector2 = _dir(deg_to_rad(-158.0))
	var perp: Vector2 = Vector2(-d.y, d.x)
	var tip: Vector2 = w + d * 58.0
	_capsule(w, tip, 3.2, 2.4, scabbard_color, 1.0)
	draw_circle(tip, 3.0, Color(0.66, 0.56, 0.34))
	draw_line(w + perp * -7.0, w + perp * 7.0, Color(0.70, 0.60, 0.34), 3.5, true)
	var grip_end: Vector2 = w - d * 14.0
	_capsule(w, grip_end, 3.0, 2.8, Color(0.30, 0.22, 0.16), 1.0)
	draw_circle(grip_end, 3.2, Color(0.70, 0.60, 0.34))
	draw_line(w + perp * 5.0, w + perp * 5.0 + Vector2(2, 10), tassel_color, 2.5, true)
	draw_circle(w + perp * 5.0 + Vector2(2, 10), 2.4, tassel_color)

func _draw_weapon_in_hand(hand: Vector2) -> void:
	match weapon_type:
		"dual":
			_draw_saber_in_hand(hand)
		"dagger":
			_draw_dagger_in_hand(hand)
		"spear":
			_draw_spear_in_hand(hand)
		"anqi":
			_draw_dart_in_hand(hand)
		"fist":
			pass
		_:
			_draw_sword_in_hand(hand)

func _draw_sword_in_hand(hand: Vector2) -> void:
	var a: float = deg_to_rad(cur[T_ARM_FL] + 8.0)
	var d: Vector2 = _dir(a)
	var perp: Vector2 = Vector2(-d.y, d.x)
	var guard: Vector2 = hand + d * 9.0
	var tip: Vector2 = hand + d * 68.0
	_capsule(hand - d * 12.0, guard, 2.6, 2.6, Color(0.30, 0.22, 0.16), 1.0)
	draw_line(guard - perp * 10.0, guard + perp * 10.0, Color(0.70, 0.60, 0.34), 4.0, true)
	_capsule(guard + d * 2.0, tip, 2.4, 1.8, blade_color, OW_W)
	draw_circle(tip, 2.2, blade_color)
	draw_circle(hand - d * 13.0, 2.6, Color(0.70, 0.60, 0.34))
	draw_line(guard + d * 3.0 + perp * 1.2, tip - d * 1.5 + perp * 0.9, Color(1, 1, 1, 0.70), 1.0, true)

func _draw_saber_in_hand(hand: Vector2) -> void:
	var a: float = deg_to_rad(cur[T_ARM_FL] + 10.0)
	var d: Vector2 = _dir(a)
	var perp: Vector2 = Vector2(-d.y, d.x)
	_capsule(hand - d * 14.0, hand + d * 6.0, 3.0, 3.0, Color(0.30, 0.22, 0.16), 1.0)
	draw_circle(hand + d * 7.0, 5.0, Color(0.70, 0.60, 0.34))
	var p0: Vector2 = hand + d * 10.0
	var p1: Vector2 = hand + d * 40.0 + perp * 3.0
	var p2: Vector2 = hand + d * 66.0 + perp * 8.0
	_capsule(p0, p1, 3.2, 2.4, blade_color, OW_W)
	_capsule(p1, p2, 2.4, 1.6, blade_color, OW_W)
	draw_circle(p2, 1.8, blade_color)
	draw_line(p0 + perp * 1.3, p1 + perp * 1.1, Color(1, 1, 1, 0.65), 1.0, true)
	draw_line(p1 + perp * 1.1, p2 + perp * 0.9, Color(1, 1, 1, 0.65), 0.9, true)
	draw_circle(hand - d * 15.0, 2.8, tassel_color)

func _draw_dagger_in_hand(hand: Vector2) -> void:
	var a: float = deg_to_rad(cur[T_ARM_FL] + 10.0)
	var d: Vector2 = _dir(a)
	var perp: Vector2 = Vector2(-d.y, d.x)
	_capsule(hand - d * 9.0, hand + d * 4.0, 2.8, 2.8, Color(0.30, 0.22, 0.16), 1.0)
	draw_line(hand + d * 5.0 - perp * 6.0, hand + d * 5.0 + perp * 6.0, Color(0.70, 0.60, 0.34), 3.0, true)
	_capsule(hand + d * 6.0, hand + d * 30.0, 2.6, 1.6, blade_color, OW_W)
	draw_circle(hand + d * 30.0, 1.8, blade_color)
	draw_line(hand + d * 7.0 + perp * 1.1, hand + d * 29.0 + perp * 0.8, Color(1, 1, 1, 0.70), 0.9, true)
	draw_circle(hand - d * 10.0, 2.4, Color(0.70, 0.60, 0.34))

func _draw_spear_in_hand(hand: Vector2) -> void:
	var a: float = deg_to_rad(cur[T_ARM_FL] + 4.0)
	var d: Vector2 = _dir(a)
	var perp: Vector2 = Vector2(-d.y, d.x)
	_capsule(hand - d * 36.0, hand + d * 76.0, 3.6, 3.0, wood_color, 1.4)
	draw_circle(hand + d * 72.0, 4.2, tassel_color)
	var base_c: Vector2 = hand + d * 78.0
	var tip: Vector2 = hand + d * 102.0
	var head := PackedVector2Array()
	head.append(base_c + perp * 5.5)
	head.append(base_c - perp * 5.5)
	head.append(tip)
	draw_colored_polygon(head, blade_color)
	var edge := PackedVector2Array()
	edge.append(base_c + perp * 5.5)
	edge.append(base_c - perp * 5.5)
	edge.append(tip)
	edge.append(base_c + perp * 5.5)
	draw_polyline(edge, ink, 1.2, true)
	draw_line(base_c - d * 2.0, tip - d * 3.0, Color(1, 1, 1, 0.50), 1.0, true)

# v57：暗器（原"木棍"）——手里捏的是一支短镖，不是一根长杆。
#   镖身短（约 3 厘米画长，跟匕首一个量级）+ 尾上三片小翼 + 一抹红绸，
#   站着手扣在腰侧，出手才甩出去（见 _draw_pouch_idle 的腰囊）。
func _draw_dart_in_hand(hand: Vector2) -> void:
	var a: float = deg_to_rad(cur[T_ARM_FL] + 10.0)
	var d: Vector2 = _dir(a)
	var perp: Vector2 = Vector2(-d.y, d.x)
	var butt: Vector2 = hand - d * 6.0
	var tip: Vector2 = hand + d * 30.0
	_capsule(butt, hand + d * 6.0, 2.4, 2.2, Color(0.28, 0.21, 0.15), 1.0)   # 缠柄
	_capsule(hand + d * 6.0, tip, 2.6, 1.4, blade_color, OW_W)              # 镖身
	draw_circle(tip, 2.0, blade_color)
	# 尾翼（三小片）
	for k in 3:
		var off: float = (float(k) - 1.0) * 2.6
		draw_line(butt + perp * off, butt - d * 5.0 + perp * off * 1.8, fletch_color, 1.6, true)
	draw_line(butt - d * 2.0, butt - d * 8.0, fletch_color, 2.0, true)      # 红绸尾

# 腰囊：暗器件的"待机"样子——一只小皮囊挂在胯边，囊口露出三支镖尾
func _draw_pouch_idle(hip_pos: Vector2) -> void:
	var c: Vector2 = hip_pos + Vector2(4.0, 6.0)
	var w := 13.0
	var h := 15.0
	draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), pouch_color, true)
	draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), ink, false, 1.4)
	draw_line(c + Vector2(-w * 0.5, -h * 0.28), c + Vector2(w * 0.5, -h * 0.28), sash_color, 2.0, true)  # 系带
	for k in 3:
		var fx: float = c.x - 3.6 + 3.6 * float(k)
		draw_line(Vector2(fx, c.y - h * 0.5), Vector2(fx - 1.6, c.y - h * 0.5 - 7.0), blade_color, 1.4, true)
		draw_circle(Vector2(fx - 1.6, c.y - h * 0.5 - 7.4), 1.5, fletch_color)

func _draw_pole_idle(hand: Vector2, with_head: bool) -> void:
	var top: Vector2 = hand + Vector2(0.0, -68.0)
	var bottom: Vector2 = hand + Vector2(0.0, 66.0)
	_capsule(bottom, top, 3.4, 3.4, wood_color, 1.4)
	if with_head:
		var head := PackedVector2Array()
		head.append(top + Vector2(-5.0, 0.0))
		head.append(top + Vector2(5.0, 0.0))
		head.append(top + Vector2(0.0, -22.0))
		draw_colored_polygon(head, blade_color)
		draw_circle(top + Vector2(0.0, 6.0), 4.0, tassel_color)
	else:
		draw_circle(top, 3.2, Color(0.32, 0.22, 0.14))
		draw_circle(bottom, 3.2, Color(0.32, 0.22, 0.14))

func _dir(a: float) -> Vector2:
	return Vector2(cos(a), -sin(a))
