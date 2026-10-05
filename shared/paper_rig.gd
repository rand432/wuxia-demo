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
const SRC_H := 1018.0          # 源图高度（切框就是按它定的）
const HIP := Vector2(300.0, 890.0)
const FEET_Y := 1018.0        # 脚底在源图里的 y —— 节点原点＝脚底，所以髋部要"往上"摆

# 部件表：切框 + 枢轴（都在源图坐标里）
const PARTS := {
	"head":  {"box": Rect2(20, 0, 480, 455),   "pivot": Vector2(280, 450), "joint": Vector2(0, -438),   "z": 4, "parent": "torso"},
	"torso": {"box": Rect2(150, 445, 330, 460),"pivot": Vector2(165, 430), "joint": Vector2(0, 0),      "z": 2, "parent": "hip"},
	"arm_l": {"box": Rect2(105, 535, 150, 355),"pivot": Vector2(60, 15),   "joint": Vector2(-130, -345), "z": 3, "parent": "torso"},
	"arm_r": {"box": Rect2(445, 535, 160, 360),"pivot": Vector2(75, 15),   "joint": Vector2(190, -345), "z": 3, "parent": "torso"},
	"leg_l": {"box": Rect2(150, 845, 190, 173),"pivot": Vector2(95, 10),   "joint": Vector2(-55, -35),   "z": 1, "parent": "hip"},
	"leg_r": {"box": Rect2(365, 845, 190, 173),"pivot": Vector2(95, 10),   "joint": Vector2(155, -35),   "z": 1, "parent": "hip"},
}
const ORDER := ["leg_l", "leg_r", "torso", "arm_l", "arm_r", "head"]

var k := 1.0                      # 源图 → 游戏尺寸的缩放系数
var _nodes := {}                  # 部件名 → Sprite2D
var _pivots := {}                 # 部件名 → 枢轴（源图坐标）
var _base := {}                   # 部件名 → 初始 position（源图坐标，相对父节点）
var _phase := 0.0
var _bob := 0.0
var _hip_base := Vector2.ZERO

# 载入一个角色的部件并搭好层级；缺任何一件就返回 false（调用方退回别的画法）
func setup(role_id: String, target_h: float) -> bool:
	var texs := {}
	for nm in ORDER:
		var p := DIR + role_id + "_" + str(nm) + ".png"
		if not ResourceLoader.exists(p):
			return false
		texs[nm] = load(p) as Texture2D
	k = target_h / SRC_H
	var hip := Node2D.new()
	hip.name = "hip"
	# ⚠ 原点＝脚底：髋部在脚底**上方** (FEET_Y - HIP.y) 像素处（第一版忘了这个，整个人跑到屏幕外）
	hip.position = Vector2(HIP.x * k, -(FEET_Y - HIP.y) * k)
	_hip_base = hip.position
	add_child(hip)
	_nodes["hip"] = hip
	# 先建躯干与四肢，再按 parent 挂 head/arm（都在 PARTS 里写了）
	for nm in ORDER:
		var d: Dictionary = PARTS[nm]
		var sp := Sprite2D.new()
		sp.name = str(nm)
		sp.texture = texs[nm]
		sp.centered = false
		sp.scale = Vector2(k, k)
		sp.z_index = int(d["z"])
		# ⚠ 两件事分开：**枢轴**用 offset 挪（贴图以源图像素记，不乘 k——节点 scale=k 会自己缩），
		#   **关节**用 position 摆（相对父节点原点；父节点原点＝父的枢轴）。第一版把这两个揉成一个，
		#   于是头/手臂各自被自己的枢轴顶偏，画出来是"头飘在旁边"。
		var pivot: Vector2 = d["pivot"]
		var joint: Vector2 = d["joint"]
		sp.offset = -pivot
		sp.position = joint * k
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
