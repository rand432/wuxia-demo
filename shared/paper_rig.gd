extends Node2D
# ============================================================
# paper_rig.gd —— 纸片骨骼（v93）
#
#   干什么：把一张 Q版 立绘按**手工定好的切框**切成 6~8 个部件，装成一副能摆姿势的身架，
#   再用代码摆走路/待机/干活——比"图生视频抽帧"干净、能完美循环、能按速度调步频（不滑步）。
#
#   部件与枢轴（**源图坐标**，源图 582×1018，改切框只改这张表）：
#     head   枢轴＝脖子   torso  枢轴＝髋（腰）
#     arm_l  枢轴＝左肩   arm_r  枢轴＝右肩
#     leg_l  枢轴＝左髋   leg_r  枢轴＝右髋
#   层级：hip → (leg_l, leg_r, torso → (arm_l, arm_r, head))，全部绕枢轴转。
#
#   用法：
#     var rig := PaperRig.new()
#     if rig.setup("shaoxia", 92.0):
#         add_child(rig)
#         rig.set_gait(phase01)     # 每帧喂一个 0~1 的步态相位
# ============================================================

const DIR := "res://assets/char/rig/"

# 每个角色一套部件表：源图高度 / 髋部位置 / 部件的枢轴·关节·层级（全部**源图坐标**）。
#   joint 是相对父节点原点的偏移（父原点＝父的枢轴）。⚠ 陈石那张图长枪斜跨全身，
#   切成手臂会在摆动时把枪切断——所以他的双臂**并进躯干**，只让腿和身体动（刻意的取舍）。
const RIGS := {
	"shaoxia": {
		"src_h": 1018.0, "hip": Vector2(300, 890), "order": ["leg_l", "leg_r", "torso", "arm_l", "arm_r", "head"],
		"parts": {
			"head":  {"pivot": Vector2(280, 450), "joint": Vector2(0, -438),   "z": 4, "parent": "torso"},
			"torso": {"pivot": Vector2(150, 445), "joint": Vector2(0, 0),      "z": 2, "parent": "hip"},
			"arm_l": {"pivot": Vector2(65, 10),   "joint": Vector2(-130, -345), "z": 3, "parent": "torso"},
			"arm_r": {"pivot": Vector2(45, 10),   "joint": Vector2(190, -345),  "z": 3, "parent": "torso"},
			"leg_l": {"pivot": Vector2(95, 10),   "joint": Vector2(-55, -35),   "z": 1, "parent": "hip"},
			"leg_r": {"pivot": Vector2(90, 10),   "joint": Vector2(155, -35),   "z": 1, "parent": "hip"},
		},
	},
	"chenshi": {
		"src_h": 1017.0, "hip": Vector2(500, 790), "order": ["leg_l", "leg_r", "torso", "head"],
		"parts": {
			"head":  {"pivot": Vector2(143, 360), "joint": Vector2(-37, -385), "z": 3, "parent": "torso"},
			"torso": {"pivot": Vector2(320, 390), "joint": Vector2(0, 0),     "z": 2, "parent": "hip"},
			"leg_l": {"pivot": Vector2(54, 12),   "joint": Vector2(-186, -13), "z": 1, "parent": "hip"},
			"leg_r": {"pivot": Vector2(66, 12),   "joint": Vector2(186, -13),  "z": 1, "parent": "hip"},
		},
	},
	"qingluan": {
		"src_h": 1024.0, "hip": Vector2(545, 790), "order": ["leg_l", "leg_r", "torso", "arm_l", "arm_r", "head"],
		"parts": {
			"head":  {"pivot": Vector2(199, 414), "joint": Vector2(-46, -361), "z": 4, "parent": "torso"},
			"torso": {"pivot": Vector2(205, 360), "joint": Vector2(0, 0),     "z": 2, "parent": "hip"},
			"arm_l": {"pivot": Vector2(276, 57),  "joint": Vector2(-169, -213), "z": 3, "parent": "torso"},
			"arm_r": {"pivot": Vector2(42, 57),   "joint": Vector2(137, -213),  "z": 3, "parent": "torso"},
			"leg_l": {"pivot": Vector2(85, 7),    "joint": Vector2(-125, -38),  "z": 1, "parent": "hip"},
			"leg_r": {"pivot": Vector2(92, 7),    "joint": Vector2(67, -38),    "z": 1, "parent": "hip"},
		},
	},
}

var k := 1.0                      # 源图 → 游戏尺寸的缩放系数
var _nodes := {}                  # 部件名 → Sprite2D
var _pivots := {}                 # 部件名 → 枢轴（源图坐标）
var _base := {}                   # 部件名 → 初始 position（源图坐标，相对父节点）
var _phase := 0.0
var _bob := 0.0
var _hip_base := Vector2.ZERO
var _parts := {}                  # 当前角色的部件表
var _hip_src := Vector2.ZERO
var _feet_y := 1018.0

# 载入一个角色的部件并搭好层级；缺任何一件就返回 false（调用方退回别的画法）
func setup(rig_key: String, target_h: float) -> bool:
	if not RIGS.has(rig_key):
		return false
	var cfg: Dictionary = RIGS[rig_key]
	var order: Array = cfg["order"]
	_parts = cfg["parts"]
	_hip_src = cfg["hip"]
	_feet_y = float(cfg["src_h"])
	var texs := {}
	for nm in order:
		var p := DIR + rig_key + "_" + str(nm) + ".png"
		if not ResourceLoader.exists(p):
			return false
		texs[nm] = load(p) as Texture2D
	k = target_h / float(cfg["src_h"])
	var hip := Node2D.new()
	hip.name = "hip"
	# ⚠⚠ v93f **真正的大坑**（用户："头怎么不见了 手脚也不见了"）：
	#   原来我给**每个部件**都设了 scale=k，而 head/arm 是 **torso 的子节点** →
	#   全局缩放变成 k×k ≈ 1/11，头和手臂小到看不见（腿和躯干是 hip 的直接子节点，所以看着正常）。
	#   正确做法：**缩放只放在 hip 上**，各部件保持 1.0；关节坐标则写"源图单位"，由 hip 的缩放统一带。
	hip.scale = Vector2(k, k)
	# ⚠ 原点＝脚底：髋部在脚底**上方** (脚底y - 髋y) 像素处（第一版忘了这个，整个人跑到屏幕外）
	# ⚠ **x 不加偏移**：节点原点＝角色脚下那一点（中线），髋部的源图 x 只是"图里身体在哪"，
	#   把它当偏移会让整个人往右飘半个身位（苏青鸾因此直接飘出屏幕）。
	hip.position = Vector2(0.0, -(_feet_y - _hip_src.y) * k)
	_hip_base = hip.position
	add_child(hip)
	_nodes["hip"] = hip
	# 先建躯干与四肢，再按 parent 挂 head/arm（层级都写在 RIGS 表里）
	for nm in order:
		var d: Dictionary = _parts[nm]
		var sp := Sprite2D.new()
		sp.name = str(nm)
		sp.texture = texs[nm]
		sp.centered = false
		sp.scale = Vector2.ONE          # 缩放交给 hip，部件自己不再缩（见上面那段注释）
		sp.z_index = int(d["z"])
		# ⚠ 两件事分开：**枢轴**用 offset 挪（贴图以源图像素记，不乘 k——节点 scale=k 会自己缩），
		#   **关节**用 position 摆（相对父节点原点；父节点原点＝父的枢轴）。第一版把这两个揉成一个，
		#   于是头/手臂各自被自己的枢轴顶偏，画出来是"头飘在旁边"。
		var pivot: Vector2 = d["pivot"]
		var joint: Vector2 = d["joint"]
		sp.offset = -pivot
		sp.position = joint            # 源图单位——hip 的 scale=k 会把它换成像素
		_nodes[nm] = sp
		_pivots[nm] = pivot
		_base[nm] = sp.position
		var parent: String = str(d["parent"])
		if parent == "hip":
			hip.add_child(sp)
		else:
			(_nodes[parent] as Node2D).add_child(sp)
	return true

# 摆一个姿势：angles 是"部件名 → 弧度"，bob 是髋部的上下浮动（源图单位）
func pose(angles: Dictionary, bob := 0.0) -> void:
	for nm in angles.keys():
		var n: Node2D = _nodes.get(str(nm))
		if n != null:
			n.rotation = float(angles[nm])
	var hip: Node2D = _nodes.get("hip")
	if hip != null:
		hip.position = _hip_base + Vector2(0.0, bob * k)

# 走路：phase01 ∈ [0,1) 是一个完整步态循环（左右各迈一步）
#   腿摆 ±LEG，手臂反向摆 ±ARM，躯干略前倾，髋部一步一浮（通过姿势最高）
const LEG := 0.46        # ≈26°
const ARM := 0.30        # ≈17°

func set_gait(phase01: float) -> void:
	_phase = fposmod(phase01, 1.0)
	var w := TAU * _phase
	var leg_l := sin(w) * LEG
	var leg_r := -leg_l
	var bob := -absf(sin(w)) * 10.0 + 5.0        # 一步一浮（两次/循环）
	pose({
		"leg_l": leg_l,
		"leg_r": leg_r,
		"arm_l": -leg_l * (ARM / LEG),
		"arm_r": leg_l * (ARM / LEG),
		"torso": 0.06 + sin(w * 2.0) * 0.015,
		"head": -0.04 - sin(w * 2.0) * 0.01,
	}, bob)

# 跑：比走更大的摆幅、更快、身体更前倾、起伏更明显（腿不一定有——按表里有的部件摆）
const RUN_LEG := 0.78        # ≈45°
const RUN_ARM := 0.62        # ≈36°

func set_run(phase01: float) -> void:
	var w := TAU * fposmod(phase01, 1.0)
	var leg_l := sin(w) * RUN_LEG
	var leg_r := -leg_l
	var bob := -absf(sin(w)) * 18.0 + 9.0
	pose({
		"leg_l": leg_l,
		"leg_r": leg_r,
		"arm_l": -leg_l * (RUN_ARM / RUN_LEG),
		"arm_r": leg_l * (RUN_ARM / RUN_LEG),
		"torso": 0.16 + sin(w * 2.0) * 0.03,
		"head": -0.10 - sin(w * 2.0) * 0.02,
	}, bob)

# 出手：k ∈ [0,1] —— 0 起手（沉肩后坐）→ 0.35 蓄力最低点 → 1 收势（前倾压出）
#   用的是"少侠"那套：前手挥出、后手后拉、上身先蹲后压。
func set_attack(k: float) -> void:
	var t := clampf(k, 0.0, 1.0)
	# 前 40% 蓄，后 60% 发
	var wind := sin(clampf(t / 0.4, 0.0, 1.0) * PI * 0.5)
	var strike := clampf((t - 0.4) / 0.6, 0.0, 1.0)
	var swing := -0.9 * wind + 2.1 * strike       # 前臂挥出去
	var back := 0.5 * wind - 0.7 * strike         # 后臂往后拉
	pose({
		"arm_l": swing,
		"arm_r": back,
		"torso": 0.22 * wind - 0.30 * strike,
		"head": -0.06 + 0.16 * strike,
		"leg_l": 0.22 * wind - 0.14 * strike,
		"leg_r": -0.22 * wind + 0.26 * strike,
	}, 6.0 * wind - 10.0 * strike)

# 挨打：k 从 1 衰减到 0（后仰 + 手臂上扬）
func set_hit(k: float) -> void:
	var a := clampf(k, 0.0, 1.0)
	pose({
		"arm_l": -0.85 * a,
		"arm_r": -0.62 * a,
		"torso": -0.30 * a,
		"head": -0.26 * a,
		"leg_l": -0.18 * a,
		"leg_r": 0.24 * a,
	}, -5.0 * a)

# 倒地：整身向后倒（靠躯干 + 头部角度，不真的躺平——纸片人躺平会穿帮）
func set_down() -> void:
	pose({
		"arm_l": -1.25,
		"arm_r": -1.05,
		"torso": -0.95,
		"head": -0.55,
		"leg_l": -0.5,
		"leg_r": 0.35,
	}, 2.0)

# 待机：轻微呼吸起伏 + 极小的重心晃
func set_idle(t: float) -> void:
	var b := sin(t * 1.35) * 2.4
	var sway := sin(t * 0.7) * 0.012
	pose({
		"leg_l": 0.0,
		"leg_r": 0.0,
		"arm_l": sway,
		"arm_r": -sway,
		"torso": 0.02 + sin(t * 1.35) * 0.01,
		"head": -0.012 + sin(t * 0.9) * 0.012,
	}, b)
