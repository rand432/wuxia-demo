extends Node2D
# ============================================================
# Q版纸片人 v1（战斗用）——一张 Q版立绘 + 弹簧驱动
#
# 为什么要有它：火柴人（journey/stick_fighter.gd）是**骨骼式**画法，招式表 move_db 存的是
#   九个关节角；Q版只有一张平图，关节角用不上，所以另起一个类，但**公开接口与火柴人完全一致**：
#       face / reset_pose / move_time / play_move / play_hit / play_dodge / play_down
#       move_seq / push_move_x / push_move_to / stop_moves / set_equipment / body_color
#   于是战斗逻辑一行都不用改，由 journey/actor_factory.gd 决定用哪个（见那里的开关）。
#
# 坐标约定：节点 position = **脚底中心**（与 StickFighter / pet_actor 一致）
# 角度单位：度。正 = 顺时针
# 动画通道：倾斜 lean / 起落 hop / 横向 sway / 挤压 sx·sy —— 全部走弹簧，临界阻尼、零回摆
#   （v1 沿用 stick_fighter v63l2 的**子步积分**：每帧拆成 h<=1/120 秒的子步，任何 k 都恒稳）
# ============================================================

const MoveDb := preload("res://move_db.gd")
const Audio := preload("res://shared/audio.gd")   # v65：出手/挨打/倒地 各出一声

const ART_DIR := "res://assets/char/"          # 正式资源目录（由 tools/promote_char_art.mjs 从生成稿提升过来）
const ART_SUFFIX := "_q.png"                   # <角色id>_q.png

# 弹簧通道
const CH_LEAN := 0   # 整体倾斜（度）
const CH_HOP := 1    # 上下（像素，负 = 腾空）
const CH_SX := 2     # 横向缩放
const CH_SY := 3     # 纵向缩放
const CH_SWAY := 4   # 横向偏移（像素）

# 视觉参数
var fit_height := 148.0      # 目标身高（脚底到头顶，像素）——火柴人约 140~150
var fit_width_cap := 132.0   # 宽度上限：陈石扛着长枪的图很宽，不压一下会把旁边的人整个糊住
var _base_scale := 0.15      # 内容 → 屏幕 的缩放（由 _relayout() 按 bbox 算）
var is_q_art := true         # v71c：我是纸片人（战斗里**不要**给我套染色——那是给火柴人区分用的）
var role := "shaoxia"        # 角色 id → assets/gen/char/<role>/<role>_Q版_*.png
var art_path := ""           # 显式指定图（优先于 role）
var body_color := Color(1, 1, 1)   # 敌方用来染色（乘算 tint）
var weapon_type := "sword"
var hat_type := "toujin"
var cape_type := "none"
var move_speed := 1.0

var _sprite: Sprite2D
var _shadow: Node2D
var _mat: ShaderMaterial
var _tex_size := Vector2(512, 1024)
var _bbox := Rect2()          # 贴图里真正有内容的矩形（像素，左上原点）
var _dir := 1.0              # +1 面朝右，-1 面朝左
var _t := 0.0
var _down := false
var _arc_t := 0.0          # 出手墨迹的剩余寿命（1→0）
var _arc_move := ""        # 这一手是哪个招式（决定墨迹形状）
var _arc_kind := "crescent"  # 这一手的墨迹型（由招式表定）

# ============================================================
# v69：招式 → 身法 + 墨迹（"不同功法不同动作"）
#   两张表各管一半：
#     · 身法——起手/出手的 倾斜、起落、横向位移（以及挤压），照着这一招的性格给
#     · 墨迹——月牙/横削/上撩/直刺/横扫/双弧/乱刃/墨团/飞线
#   表里没有的招式按兵器给个默认（见 _style_for），绝不会没动作。
# ============================================================
const MOVE_STYLE := {
	# ---- 刀剑 ----
	"chop":         {"kind": "crescent", "wu": [-12.0, 2.0, -5.0], "st": [20.0, -6.0, 12.0]},   # 劈：沉肩后坐 → 前倾下压
	"cut":          {"kind": "cross",    "wu": [-6.0, 0.0, -10.0], "st": [8.0, -2.0, 18.0]},   # 削：侧身横扫
	"slice":        {"kind": "rise",     "wu": [12.0, 4.0, -4.0], "st": [-16.0, -11.0, 9.0]},  # 撩：先蹲后挑
	"stab":         {"kind": "thrust",   "wu": [-14.0, 1.0, -11.0], "st": [16.0, -3.0, 24.0]}, # 刺：直线前冲
	"sweep":        {"kind": "sweep",    "wu": [-4.0, 0.0, -15.0], "st": [6.0, -4.0, 20.0]},   # 扫：大转身
	# ---- 双刀 ----
	"dual_chop":    {"kind": "dual",     "wu": [-10.0, 2.0, -6.0], "st": [16.0, -6.0, 12.0]},
	"dual_alt":     {"kind": "dual",     "wu": [-7.0, 1.0, -8.0], "st": [11.0, -4.0, 15.0]},
	"dual_thrust":  {"kind": "thrust",   "wu": [-12.0, 1.0, -10.0], "st": [15.0, -3.0, 22.0]},
	"dual_rip":     {"kind": "cross",    "wu": [6.0, 3.0, -12.0], "st": [-10.0, -8.0, 14.0]},
	# ---- 匕首 ----
	"dagger_slash": {"kind": "dual",     "wu": [-8.0, 1.0, -7.0], "st": [12.0, -5.0, 14.0]},
	"dagger_stab":  {"kind": "thrust",   "wu": [-11.0, 1.0, -9.0], "st": [14.0, -3.0, 20.0]},
	"dagger_flurry": {"kind": "flurry",  "wu": [-5.0, 0.0, -6.0], "st": [9.0, -4.0, 10.0]},
	# ---- 枪 ----
	"spear_thrust": {"kind": "thrust",   "wu": [-15.0, 2.0, -12.0], "st": [18.0, -3.0, 26.0]},
	"spear_multi":  {"kind": "flurry",   "wu": [-9.0, 1.0, -8.0], "st": [13.0, -5.0, 14.0]},
	"spear_turn":   {"kind": "sweep",    "wu": [-5.0, 0.0, -14.0], "st": [7.0, -4.0, 19.0]},
	# ---- 暗器 ----
	"anqi_throw":   {"kind": "darts",    "wu": [-6.0, 1.0, -8.0], "st": [10.0, -3.0, 16.0]},
	"anqi_rain":    {"kind": "darts",    "wu": [-4.0, 0.0, -6.0], "st": [7.0, -2.0, 12.0]},
	"anqi_kick":    {"kind": "impact",   "wu": [-8.0, 3.0, -6.0], "st": [14.0, -7.0, 11.0]},
	# ---- 拳 ----
	"fist_punch":   {"kind": "impact",   "wu": [-9.0, 2.0, -7.0], "st": [15.0, -5.0, 13.0]},
	"fist_combo":   {"kind": "flurry",   "wu": [-6.0, 1.0, -6.0], "st": [10.0, -4.0, 11.0]},
	"fist_kick":    {"kind": "impact",   "wu": [-11.0, 4.0, -5.0], "st": [17.0, -9.0, 10.0]},
	"fist_palm":    {"kind": "cross",    "wu": [-7.0, 1.0, -9.0], "st": [9.0, -3.0, 15.0]},
}

# 招式 → 风格；表里没有就按兵器兜底
func _style_for(move_id: String) -> Dictionary:
	if MOVE_STYLE.has(move_id):
		return MOVE_STYLE[move_id]
	match weapon_type:
		"spear": return {"kind": "thrust", "wu": [-13.0, 2.0, -10.0], "st": [16.0, -3.0, 22.0]}
		"dagger": return {"kind": "dual", "wu": [-8.0, 1.0, -7.0], "st": [12.0, -5.0, 14.0]}
		"fist": return {"kind": "impact", "wu": [-9.0, 2.0, -7.0], "st": [14.0, -5.0, 12.0]}
		"anqi": return {"kind": "darts", "wu": [-6.0, 1.0, -8.0], "st": [10.0, -3.0, 15.0]}
		"dual": return {"kind": "dual", "wu": [-10.0, 2.0, -6.0], "st": [15.0, -6.0, 12.0]}
		_: return {"kind": "crescent", "wu": [-12.0, 2.0, -5.0], "st": [20.0, -6.0, 12.0]}
const ARC_LIFE := 0.20
# 每个人的"笔性"：焦墨（少侠）／湿墨厚重（陈石）／细笔轻灵（苏青鸾）／普通（杂兵）
var ink_weight := 1.0      # 透明度倍率
var ink_width := 1.0       # 笔宽倍率
var ink_len := 1.0         # 弧长倍率

var _last_pos := Vector2.ZERO
var _walk_t := 0.0
var _walk_amt := 0.0

# ============================================================
# v70b：**火柴人同款公开接口**（游历的走路小人会直接写 tgt[0..8]）
#   事故：走路小人早就换成 Q版 了，可 journey_stage._pose_one() 还在写火柴人的
#   9 个关节 → 每帧 "Invalid access to property 'tgt'" → 一进游历就卡死。
#   这里不再只补一个字段，而是把调用方会摸的都补齐（tgt/cur/vel/spring_*/hip/sword_drawn），
#   并把 9 个关节**翻译成纸片人的动作**（起伏/前倾/摆），这样走路小人真的会迈步。
# ============================================================
const J_TORSO := 0
const J_ARM_FU := 1
const J_ARM_FL := 2
const J_ARM_BU := 3
const J_ARM_BL := 4
const J_LEG_FU := 5
const J_LEG_FL := 6
const J_LEG_BU := 7
const J_LEG_BL := 8
# 火柴人的静止姿势（对表 stick_fighter 的待机值）——用来算"偏离多少"
const J_REST := [86.0, -72.0, -118.0, -110.0, -95.0, -74.0, -84.0, -74.0, -84.0]

var tgt: Array[float] = [86.0, -72.0, -118.0, -110.0, -95.0, -74.0, -84.0, -74.0, -84.0]
var cur: Array[float] = [86.0, -72.0, -118.0, -110.0, -95.0, -74.0, -84.0, -74.0, -84.0]
var vel: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var spring_k := 380.0
var spring_d := 39.0
var vel_cap := 1400.0
var hip := Vector2(0, -68)
var sword_drawn := false

var _tgt := [0.0, 0.0, 1.0, 1.0, 0.0]
var _cur := [0.0, 0.0, 1.0, 1.0, 0.0]
var _vel := [0.0, 0.0, 0.0, 0.0, 0.0]
const SPRING_K := 380.0
const SPRING_D := 39.0
const VEL_CAP := 1400.0

var _move_gen := 0
var _move_tw: Tween = null
var move_db: Dictionary = {}

const SHADER := """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	c.rgb *= tint.rgb;
	c.a *= tint.a * alpha;
	COLOR = c;
}"""

# 走路小人专用：把 9 关节的偏离量翻译成"起伏 + 前倾 + 侧摆"
#   腿摆动 → 上下起伏（迈步的弹跳感）；躯干 → 前倾；手臂 → 侧摆
func _walk_apply() -> void:
	if _sprite == null or tgt.size() < 9:
		return
	var leg := (float(tgt[J_LEG_FU]) + float(tgt[J_LEG_BU])) * 0.5 - (J_REST[J_LEG_FU] + J_REST[J_LEG_BU]) * 0.5
	var arm := (float(tgt[J_ARM_FU]) + float(tgt[J_ARM_BU])) * 0.5 - (J_REST[J_ARM_FU] + J_REST[J_ARM_BU]) * 0.5
	var torso := float(tgt[J_TORSO]) - float(J_REST[J_TORSO])
	# 幅度都很小（纸片人不比火柴人，摆大了像在抽）
	_sprite.position = Vector2(0.0, -absf(leg) * 0.16)
	_sprite.rotation = deg_to_rad(clampf(torso * 1.6 + arm * 0.10, -14.0, 14.0) * _dir)
	# cur 也跟着写回去，方便 twitch_recorder 之类的调试口读
	for i in 9:
		if i < cur.size():
			cur[i] = float(tgt[i])

func _init() -> void:
	move_db = MoveDb.build()   # 招式表：与火柴人同源（时长口径一致，战斗才不用改）
	if _tgt.size() != 5:
		_tgt = [0.0, 0.0, 1.0, 1.0, 0.0]
		_cur = [0.0, 0.0, 1.0, 1.0, 0.0]
		_vel = [0.0, 0.0, 0.0, 0.0, 0.0]

func _ready() -> void:
	var tex := _load_art()
	if tex == null:
		tex = _placeholder()
	_tex_size = tex.get_size()
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	_mat.set_shader_parameter("tint", Color(1, 1, 1))
	_mat.set_shader_parameter("flash", 0.0)
	_mat.set_shader_parameter("alpha", 1.0)
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.centered = false
	_sprite.material = _mat
	_sprite.z_index = -1   # v66：墨弧画在**本节点自己身上**（父先画、子后画），贴图压到 -1 才在弧下面
	_arc_t = 0.0
	# 贴图锚到"脚底中心"：局部原点 = 两脚之间
	# v66：**按"内容实际边界"缩放**，不按整张贴图。
	#   生成稿留白多少全看模型心情（敌人的图内容只占 60% 高、主角的抠完就贴边），
	#   照贴图高度缩放会让有的人大一圈有的人小一圈。这里量一次 alpha 边界，
	#   把内容底边中点钉在原点（脚底），再按内容高度缩到 fit_height。
	_bbox = _measure_bbox(tex)
	_relayout()
	add_child(_sprite)
	# v71g（用户："人物不见了"）：**z_index 必须留着**。
	#   v71f 我为了修"五选一挡选项"把它删了——那是错的方向：
	#   删掉之后纸片人掉到**地面/风景的绘制之下**，整个看不见了（比挡住选项严重得多）。
	#   正确解法是"演员留层色、弹窗抬更高"：弹窗遮罩已统一抬到 z_index = 120（见 ui_kit.make_veil），
	#   而 Godot 的 z_index 是**相对父节点**的，面板挂在遮罩下 → 自动也在 120 之上 ✔
	#   所以这里恢复 5：压在风景之上、弹窗之下，两边都对。
	z_index = 5

# 量 alpha 边界：扫一遍像素，找到 alpha > 24 的最小外包矩形。
#   贴图最大也就 340×340 量级（提升脚本已经缩过），几万次循环，进场时算一次不心疼。
func _measure_bbox(tex: Texture2D) -> Rect2:
	var full := Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img == null:
		return full
	var w := img.get_width()
	var h := img.get_height()
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	# 隔行隔列采样（贴图小，全扫也行，但 2 步长快一倍、边界误差 ≤1px）
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if img.get_pixel(x, y).a > 0.09:
				if x < x0: x0 = x
				if x > x1: x1 = x
				if y < y0: y0 = y
				if y > y1: y1 = y
	if x1 < 0 or y1 < 0:
		return full
	return Rect2(Vector2(x0, y0), Vector2(x1 - x0 + 1, y1 - y0 + 1))

# 把贴图按 bbox 摆好：内容底边中点 = 节点原点（脚底），高度 = fit_height（宽度另有上限）
func _relayout() -> void:
	if _sprite == null or _tex_size.y <= 0.0:
		return
	var bw: float = maxf(_bbox.size.x, 1.0)
	var bh: float = maxf(_bbox.size.y, 1.0)
	var base: float = fit_height / bh
	base = minf(base, fit_width_cap / bw)
	_sprite.offset = Vector2(-(_bbox.position.x + bw * 0.5) * base, -(_bbox.position.y + bh) * base)
	_base_scale = base

func _load_art() -> Texture2D:
	var p := art_path
	if p == "":
		p = ART_DIR + role + ART_SUFFIX
	if not ResourceLoader.exists(p):
		return null
	var res := load(p)
	return res as Texture2D

# 没图先给个墨块占位——绝不因为缺图崩掉战斗
func _placeholder() -> Texture2D:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(128):
		for x in range(64):
			var dx := (x - 32.0) / 26.0
			var dy := (y - 74.0) / 58.0
			if dx * dx + dy * dy < 1.0:
				img.set_pixel(x, y, Color(0.16, 0.17, 0.2, 0.95))
	for y in range(34):
		for x in range(64):
			var dx2 := (x - 32.0) / 17.0
			var dy2 := (y - 20.0) / 17.0
			if dx2 * dx2 + dy2 * dy2 < 1.0:
				img.set_pixel(x, y, Color(0.18, 0.19, 0.22, 0.95))
	return ImageTexture.create_from_image(img)

# ============ 接口：朝向与装备 ============

# 朝向：**不用 flip_h**——翻转交给 scale.x 的符号（见 _apply_visual 的 eff 补偿），
#   这样和战斗里 n.scale = Vector2(-scl, scl) 的整体镜像不会互相打架（翻两次 = 没翻）
func face(dir: int) -> void:
	_dir = 1.0 if dir >= 0 else -1.0

func set_equipment(weapon: String, hat: String, cape: String) -> void:
	weapon_type = weapon
	hat_type = hat
	cape_type = cape

func set_weapon(w: String) -> void:
	weapon_type = w

func set_role(r: String) -> void:
	role = r
	_apply_ink_style()

# 兵器 → 音效（v67：素材包里的真·游戏音效；缺 key 时 Audio.sfx 自己会静默跳过）
func _sfx_swing() -> String:
	match weapon_type:
		"anqi": return "dart"
		"fist": return "swing"
		_: return "swing"

func _sfx_hit() -> String:
	match weapon_type:
		"anqi": return "dart"
		"fist": return "hit_heavy"
		"spear": return "hit_slash2"
		_: return "hit_slash"

# 笔性表：同一个人从头到尾一个笔法，换人换笔（v66）
func _apply_ink_style() -> void:
	match role:
		"player":
			ink_weight = 1.10; ink_width = 0.95; ink_len = 1.05   # 焦墨：浓、快、锋利
		"chen_shi":
			ink_weight = 0.95; ink_width = 1.35; ink_len = 0.88   # 湿墨：厚重、慢、短
		"qingluan":
			ink_weight = 0.85; ink_width = 0.70; ink_len = 1.25   # 细笔：轻灵、细、长
		"mob_chief", "mob_one_arm":
			ink_weight = 1.15; ink_width = 1.25; ink_len = 1.10   # 精英：墨重、笔宽、弧长（有压迫感）
		"mob_lou", "mob_bow":
			ink_weight = 0.80; ink_width = 0.80; ink_len = 0.92   # 小兵：墨薄、笔细（看着就弱）
		"mob_hook", "mob_flag":
			ink_weight = 0.95; ink_width = 1.15; ink_len = 0.95   # 莽夫：笔粗而短
		"mob_dog":
			ink_weight = 1.05; ink_width = 1.30; ink_len = 0.85   # 野兽：又粗又短（扑咬）
		_:
			ink_weight = 1.00; ink_width = 1.00; ink_len = 1.00   # 其他：普通
	if _sprite != null:
		var tex := _load_art()
		if tex != null:
			_sprite.texture = tex
			_tex_size = tex.get_size()
			_bbox = _measure_bbox(tex)
			_relayout()

# ============ 接口：位移（与火柴人同语义） ============

func move_seq() -> Tween:
	if _move_tw != null and _move_tw.is_valid():
		_move_tw.kill()
	_move_tw = create_tween()
	return _move_tw

func push_move_x(to_x: float, dur: float, trans: Tween.TransitionType = Tween.TRANS_QUAD, ease_t: Tween.EaseType = Tween.EASE_OUT) -> Tween:
	return push_move_to(Vector2(to_x, position.y), dur, trans, ease_t)

func push_move_to(to_p: Vector2, dur: float, trans: Tween.TransitionType = Tween.TRANS_QUAD, ease_t: Tween.EaseType = Tween.EASE_OUT) -> Tween:
	# ⚠ v71c（用户报的「战斗卡死 / Cannot call method 'set_trans' on a null value」）：
	#   这是**火柴人踩过、并且在 stick_fighter 里已经修好**的老坑——
	#   当 tween 已经跑完／已被 kill 时，tween_property() 会返回 null（Godot 先警告
	#   "Use stop() first."），紧跟其后的链式 .set_trans(...) 就当场炸，调用方函数中断 →
	#   游历／决斗整个卡死。我写 Q版 时把**没修的那个写法**抄了过来，所以又犯一遍。
	#   正确写法：先拿 PropertyTweener、判空；空就重开一条 tween 再来一次。
	if _move_tw == null or not _move_tw.is_valid():
		_move_tw = create_tween()
	var pt = _move_tw.tween_property(self, "position", to_p, maxf(dur, 0.01))
	if pt == null:
		_move_tw = create_tween()
		pt = _move_tw.tween_property(self, "position", to_p, maxf(dur, 0.01))
	if pt != null:
		pt.set_trans(trans).set_ease(ease_t)
	return _move_tw

func stop_moves() -> void:
	if _move_tw != null and _move_tw.is_valid():
		_move_tw.kill()

# ============ 招式（时长口径与火柴人严格同源：都走 move_db） ============

func move_time(move_id: String, speed := 1.0) -> Dictionary:
	var sp := maxf(0.25, speed)
	var table: Dictionary = move_db.get(weapon_type, {})
	if table.is_empty():
		return {"windup": 0.20, "total": 0.20, "speed": sp}
	var mv := move_id
	if not table.has(mv):
		mv = str(table.keys()[0])
	var steps: Array = table[mv]
	var sum := 0.0
	for s_v in steps:
		sum += float((s_v as Array)[1])
	return {"windup": float((steps[0] as Array)[1]) / sp, "total": sum / sp, "speed": sp}

func _set_pose(d: Dictionary) -> void:
	for k in d.keys():
		_tgt[int(k)] = float(d[k])

# ⚠ 倒地之后**也要能扶起来**（战斗收尾/复活会调 reset_pose），所以这里必须清 _down
func reset_pose() -> void:
	_down = false
	if _mat != null:
		_mat.set_shader_parameter("alpha", 1.0)
	_set_pose({CH_LEAN: 0.0, CH_HOP: 0.0, CH_SX: 1.0, CH_SY: 1.0, CH_SWAY: 0.0})

func play_move(move_id: String, speed := 1.0) -> void:
	_down = false
	move_speed = maxf(0.25, speed)
	_move_gen += 1
	var gen := _move_gen
	var mt := move_time(move_id, move_speed)
	var windup: float = maxf(float(mt["windup"]), 0.06)
	var total: float = maxf(float(mt["total"]), windup + 0.06)
	# 起手／出手：**照这一招的性格给身法**（v69：不同功法不同动作）
	var st := _style_for(move_id)
	var wu: Array = st.get("wu", [-9.0, 1.5, -5.0])
	var sk: Array = st.get("st", [15.0, -5.0, 11.0])
	_arc_kind = str(st.get("kind", "crescent"))
	# 音效按兵器分：暗器"嗒"、弓"弦"、拳"闷"、刀剑"挥"
	Audio.sfx(_sfx_swing(), -11.0, randf_range(0.94, 1.06))
	# ① 起手：沉肩后坐、身子压低（"蓄"）
	_set_pose({CH_LEAN: float(wu[0]) * _dir, CH_HOP: float(wu[1]), CH_SX: 0.95, CH_SY: 1.05, CH_SWAY: float(wu[2]) * _dir})
	await _wait(windup)
	if gen != _move_gen:
		return
	# ② 进身：半个身子先欺过去（"欺身"）——出手前有一小段过渡，动作才像人做的，
	#    不是"啪"地从一个姿势跳到另一个（v70：真动作四段里的第二段）
	var mide: float = maxf((total - windup) * 0.38, 0.05)
	_set_pose({
		CH_LEAN: (float(wu[0]) * 0.25 + float(sk[0]) * 0.75) * _dir,
		CH_HOP: float(wu[1]) * 0.3 + float(sk[1]) * 0.7,
		CH_SX: 0.99, CH_SY: 1.02,
		CH_SWAY: (float(wu[2]) * 0.2 + float(sk[2]) * 0.8) * _dir,
	})
	await _wait(mide)
	if gen != _move_gen:
		return
	# ③ 出手：到位 + 墨迹炸开（"发"）
	_set_pose({CH_LEAN: float(sk[0]) * _dir, CH_HOP: float(sk[1]), CH_SX: 1.03, CH_SY: 0.97, CH_SWAY: float(sk[2]) * _dir})
	_arc_move = move_id          # 墨迹形状读它
	_arc_t = 1.0
	queue_redraw()
	await _wait(maxf(total - windup - mide, 0.08))
	if gen != _move_gen:
		return
	# ④ 收势：先回一半（留一点"余劲"），再回站姿——比直接弹回站姿顺得多
	_set_pose({
		CH_LEAN: float(sk[0]) * 0.28 * _dir, CH_HOP: float(sk[1]) * 0.3,
		CH_SX: 1.01, CH_SY: 0.99, CH_SWAY: float(sk[2]) * 0.3 * _dir,
	})
	await _wait(0.09)
	if gen != _move_gen:
		return
	reset_pose()
	await _wait(0.10)
	if gen == _move_gen:
		reset_pose()

func play_hit() -> void:
	_down = false
	_move_gen += 1
	var gen := _move_gen
	Audio.sfx(_sfx_hit(), -6.0, randf_range(0.95, 1.10))
	_set_pose({CH_LEAN: -16.0 * _dir, CH_HOP: 2.0, CH_SX: 1.10, CH_SY: 0.90, CH_SWAY: -9.0 * _dir})
	_flash(0.85, 0.13)
	await _wait(0.16)
	if gen != _move_gen:
		return
	reset_pose()

func play_dodge() -> void:
	_down = false
	_move_gen += 1
	var gen := _move_gen
	_set_pose({CH_LEAN: 10.0 * _dir, CH_HOP: -14.0, CH_SX: 0.90, CH_SY: 1.10, CH_SWAY: 16.0 * _dir})
	await _wait(0.20)
	if gen != _move_gen:
		return
	reset_pose()

func play_down() -> void:
	Audio.sfx("fall_down", -5.0)
	_down = true
	_move_gen += 1
	_set_pose({CH_LEAN: 86.0 * _dir, CH_HOP: 6.0, CH_SX: 1.02, CH_SY: 0.98, CH_SWAY: 12.0 * _dir})
	if _mat != null:
		_mat.set_shader_parameter("alpha", 0.92)

func _flash(v: float, dur: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("flash", v)
	await _wait(dur)
	if _mat != null:
		_mat.set_shader_parameter("flash", 0.0)

func _wait(sec: float) -> void:
	await get_tree().create_timer(maxf(sec, 0.01)).timeout

# ============ 每帧：子步积分 + 待机呼吸 ============

# 出手墨弧：贴着人身从后往前扫，从浓到淡、末端飞白（三段粗细叠出毛笔味）
func _draw() -> void:
	if _arc_t <= 0.0 or _sprite == null:
		return
	var k := 1.0 - _arc_t                        # 0→1 进度
	var sgn := -1.0 if scale.x < 0.0 else 1.0
	var eff := _dir * sgn
	# 弧心放在胸口、半径按身高给；角度从"斜上方"扫到"斜下方"——**只朝面前那一边**（0° = 正右）
	# 弧心放在胸口略前、半径只到身高的 0.44——太大了会绕到头顶去（第一版就是绕头一圈）
	# 弧心推到身前 0.55r（不是在人身子里），角度对称张开——这样那道月牙一定是"扫在面前"
	var r := fit_height * 0.46
	var c := Vector2(r * 0.55 * eff, -fit_height * 0.48)
	var kk := clampf(k / 0.6, 0.0, 1.0)
	var half := deg_to_rad(lerpf(28.0, 62.0, kk))
	var tilt := deg_to_rad(lerpf(-18.0, 8.0, kk))
	var a0 := tilt - half
	var a1 := tilt + half
	var s := minf(a0, a1) * eff
	var e := maxf(a0, a1) * eff
	var life := 1.0 - clampf((k - 0.35) / 0.65, 0.0, 1.0)   # 前段实、后段淡出
	# 三条叠出"月牙"：外条长而宽、内条短而浓（角度也往里收，才像一笔扫出的月牙，
	#   而不是一条等宽的灰弧——第一版就是等宽灰弧，看着像 UI 进度条）
	# v66：墨迹按**兵器**分型——刀一道月牙、枪一条直刺带枪花、匕首两道短弧、
	#   拳一记墨团冲撞、暗器三点飞线。同一个角色换兵器，出手就不一样了。
	match _arc_kind:
		"thrust":
			_draw_thrust(c, r, s, e, life, eff)
		"dual":
			_draw_twin(c, r, s, e, life)
		"impact":
			_draw_impact(c, r, life)
		"darts":
			_draw_darts(c, r, life, eff)
		"cross":
			_draw_cross(c, r, s, e, life, eff)
		"rise":
			_draw_rise(c, r, s, e, life, eff)
		"sweep":
			_draw_sweep(c, r, s, e, life)
		"flurry":
			_draw_flurry(c, r, life, eff)
		_:
			_draw_crescent(c, r, s, e, life)

# 刀/剑：一道月牙（外长内短、外淡内浓）
func _draw_crescent(c: Vector2, r: float, s: float, e: float, life: float) -> void:
	var mid_a := (s + e) * 0.5
	for i in 3:
		var t := float(i)
		var lo := lerpf(s, mid_a, 0.14 * t)
		var hi := lerpf(e, mid_a, 0.14 * t)
		draw_arc(c, r * ink_len * (1.0 - 0.075 * t), lo, hi, 26,
			_ink(life * (0.88 - 0.22 * t)), (11.0 - 3.4 * t) * ink_width, true)

# 枪：一条笔直的突刺 + 枪尖一点枪花（直线才像"扎"，弧线就成砍了）
func _draw_thrust(c: Vector2, r: float, _s: float, _e: float, life: float, eff: float) -> void:
	var a := Vector2(1.0, 0.0) * eff
	var from := c - a * r * 0.35
	var to := c + a * r * ink_len * 1.05
	draw_line(from, to, _ink(life * 0.85), 5.0 * ink_width, true)
	draw_line(from + Vector2(0.0, 3.0), to + Vector2(0.0, 2.0), _ink(life * 0.45), 2.5 * ink_width, true)
	# 枪花：尖端点一个小圈
	var tip := c + a * r * ink_len * 1.0
	draw_arc(tip, 9.0 * ink_len, 0.0, TAU, 14, _ink(life * 0.6), 2.4 * ink_width, true)

# 匕首：两道短促的交叉短弧（左右各一，快而碎）
func _draw_twin(c: Vector2, r: float, s: float, e: float, life: float) -> void:
	var mid_a := (s + e) * 0.5
	for k in 2:
		var flip := 1.0 if k == 0 else -1.0
		var lo := lerpf(s, mid_a, 0.30)
		var hi := lerpf(e, mid_a, 0.30)
		draw_arc(c + Vector2(0.0, -18.0 * flip * ink_len), r * 0.62 * ink_len,
			lo * flip, hi * flip, 18, _ink(life * (0.80 - 0.25 * float(k))), 6.0 * ink_width, true)

# 拳：一记墨团冲撞（几层圆往外炸，没有弧）
func _draw_impact(c: Vector2, r: float, life: float) -> void:
	var t := 1.0 - life
	for i in 4:
		var rr := r * ink_len * (0.20 + 0.30 * float(i)) * (0.5 + 0.5 * t)
		draw_circle(c + Vector2(r * 0.35 * ink_len, 0.0), rr, _ink(life * 0.30))
	draw_circle(c + Vector2(r * 0.35 * ink_len, 0.0), r * 0.22 * ink_len, _ink(life * 0.75))

# 暗器：三点飞线（斜着扎出去，每点带一条短尾）
func _draw_darts(c: Vector2, r: float, life: float, eff: float) -> void:
	for i in 3:
		var yy := -26.0 + 26.0 * float(i)
		var x0 := c.x + r * 0.15 * ink_len
		var x1 := c.x + r * (0.75 + 0.12 * float(i)) * ink_len
		draw_line(Vector2(x0, c.y + yy) , Vector2(x0 + (x1 - x0) * eff, c.y + yy - 6.0),
			_ink(life * 0.7), 2.6 * ink_width, true)

# 削：横着的一道（上下压扁的弧），像贴着腰线横拉
func _draw_cross(c: Vector2, r: float, _s: float, _e: float, life: float, eff: float) -> void:
	var cc := c + Vector2(0.0, 10.0)
	for i in 3:
		var t := float(i)
		var lo := deg_to_rad(-14.0 + 3.0 * t)
		var hi := deg_to_rad(14.0 - 3.0 * t)
		draw_arc(cc, r * ink_len * (1.15 - 0.10 * t), minf(lo, hi) , maxf(lo, hi), 20,
			_ink(life * (0.85 - 0.22 * t)), (8.0 - 2.4 * t) * ink_width, true)
	# 横拉的两端各带一截"飞白"
	var a := Vector2(1.0, 0.0) * eff
	draw_line(cc - a * r * ink_len * 1.2, cc - a * r * ink_len * 0.5, _ink(life * 0.42), 2.0 * ink_width, true)

# 撩：由下往上挑的一道弧
func _draw_rise(c: Vector2, r: float, s: float, e: float, life: float, eff: float) -> void:
	var mid_a := (s + e) * 0.5
	for i in 3:
		var t := float(i)
		var lo := lerpf(s, mid_a, 0.16 * t) - deg_to_rad(52.0)
		var hi := lerpf(e, mid_a, 0.16 * t) - deg_to_rad(16.0)
		draw_arc(c + Vector2(0.0, 16.0), r * ink_len * (0.95 - 0.07 * t), lo * eff if eff > 0.0 else hi * eff,
			hi * eff if eff > 0.0 else lo * eff, 22, _ink(life * (0.86 - 0.20 * t)), (9.0 - 3.0 * t) * ink_width, true)

# 扫：一大圈横弧（转到身前再兜回来）
func _draw_sweep(c: Vector2, r: float, _s: float, _e: float, life: float) -> void:
	for i in 3:
		var t := float(i)
		draw_arc(c, r * ink_len * (1.45 - 0.12 * t), deg_to_rad(-118.0 + 6.0 * t), deg_to_rad(118.0 - 6.0 * t), 40,
			_ink(life * (0.72 - 0.18 * t)), (8.0 - 2.6 * t) * ink_width, true)

# 乱刃（连击/连刺）：三四道短弧铺开，角度各不同——"一顿乱削"
func _draw_flurry(c: Vector2, r: float, life: float, eff: float) -> void:
	for i in 4:
		var t := float(i)
		var off := Vector2(r * (0.35 + 0.16 * t) * eff, -34.0 + 22.0 * t)
		var half := deg_to_rad(20.0 + 4.0 * t)
		var tilt := deg_to_rad(-40.0 + 26.0 * t)
		var lo := tilt - half
		var hi := tilt + half
		if eff < 0.0:
			var tmp := lo
			lo = -hi
			hi = -tmp
		draw_arc(c + off, r * 0.42 * ink_len, lo, hi, 14,
			_ink(life * (0.78 - 0.13 * t)), (6.5 - 1.0 * t) * ink_width, true)

# 统一墨色：按"笔性"给透明度（少侠偏焦墨、陈石偏湿墨、苏青鸾偏细笔）
func _ink(a: float) -> Color:
	return Color(0.07, 0.07, 0.09, clampf(a * ink_weight, 0.0, 1.0))

func _process(delta: float) -> void:
	_t += delta
	if _arc_t > 0.0:
		_arc_t = maxf(0.0, _arc_t - delta / ARC_LIFE)
		queue_redraw()
	# 走路颠：节点位置在动就自动叠一层上下颠 + 左右微摆。
	#   舞台上赶路、战斗里前冲/后撤都吃这一层——不然纸片人只会"滑步"。
	var dx := absf(position.x - _last_pos.x)
	_last_pos = position
	var want := 0.0 if _down else clampf(dx * 12.0, 0.0, 1.0)
	_walk_amt = lerpf(_walk_amt, want, minf(1.0, delta * 8.0))
	if _walk_amt > 0.02:
		_walk_t += delta * 11.0
	var left := minf(delta, 1.0 / 30.0)
	while left > 0.0001:
		var h := minf(1.0 / 120.0, left)
		_integrate(h)
		left -= h
	_apply_visual()
	# v70b：走路小人（游历）写的是火柴人那套 9 关节——翻译成纸片人的起伏/前倾
	_walk_apply()

func _integrate(h: float) -> void:
	var sp := maxf(0.25, move_speed)
	var k := SPRING_K * sp * sp
	var d := SPRING_D * sp
	var cap := VEL_CAP * sp
	for i in range(_cur.size()):
		var a: float = (float(_tgt[i]) - float(_cur[i])) * k - float(_vel[i]) * d
		_vel[i] = clampf(_vel[i] + a * h, -cap, cap)
		_cur[i] = _cur[i] + _vel[i] * h

func _apply_visual() -> void:
	if _sprite == null:
		return
	var breath := 0.0
	var sway_idle := 0.0
	if not _down:
		breath = sin(_t * 2.3) * 0.012          # 呼吸：纵向 ±1.2%
		sway_idle = sin(_t * 1.15) * 1.2        # 站姿微晃
	var sx: float = _cur[CH_SX] * (1.0 - breath * 0.6)
	var sy: float = _cur[CH_SY] * (1.0 + breath)
	var base: float = _base_scale
	# 敌人是用 n.scale = Vector2(-scl, scl) 整体镜像的（见 duel_battle/battle_lite）：
	#   节点负缩放会把朝向和倾斜**再翻一次**，所以这里按 scale.x 的符号补偿，
	#   保证"最终朝向 = _dir"，倾斜方向也跟着对（不然敌人出手会朝反方向倒）
	var sgn := -1.0 if scale.x < 0.0 else 1.0
	var eff := _dir * sgn
	_sprite.scale = Vector2(base * sx * eff, base * sy)
	var bob := absf(sin(_walk_t)) * 4.5 * _walk_amt
	var wob := sin(_walk_t * 0.5) * 1.5 * _walk_amt
	_sprite.position = Vector2(float(_cur[CH_SWAY]) + sway_idle + wob, float(_cur[CH_HOP]) - bob)
	_sprite.rotation = deg_to_rad(float(_cur[CH_LEAN])) * eff
	if _mat != null:
		_mat.set_shader_parameter("tint", body_color)
