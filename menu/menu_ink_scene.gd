extends Control
# ============================================================
# menu_ink_scene.gd —— 主界面的**水墨村景层**（v96 建 / v97 竖屏适配）
#   数据来自 assets/scenes/village_layout.json（用户在摆景器里排的那一版）：
#     · 13 件：远山×5（0.28→0.60 渐隐）· 村景 · 柳 · 竹 · 水 · 船 · 树×3
#     · 动效：sway / bob / flow + 代码画的烟与鸟
#     · 遮挡：远山在村景处已烘焙裁掉；整层套 720×1280 画框（clip_contents）
#
#   为什么是 Control 而不是 Node2D：**要裁剪**（用户："超出画布的去掉"）。
#   用法：`var s := InkScene.new(); add_child(s)` —— 它自己读 JSON 建件、挂动效。
#
#   v97（用户："让村景层铺满全屏"）：
#     JSON 是**横构图**——13 件全挤在 y≈567~1112 那一条里，直接铺到 720×1280
#     竖屏上就"只在下面露一条"。这里加一段 _fit()：读进来之后、挂动效之前，
#     把件**整体放大 + 上提**（村景往上长、远山撑到天上），JSON 一个字不用动。
# ============================================================
const Layout := preload("res://shared/scene_layout.gd")
const Anim := preload("res://shared/scene_anim.gd")

const LAYOUT_PATH := "res://assets/scenes/village_layout.json"
const PAPER := Color(0.945, 0.925, 0.882, 1.0)

# ---- 竖屏适配参数（改这里就能调，不必动 JSON）----
const FIT := true
const CX := 360.0          # 横向缩放中心（屏宽的一半）
const VIL_K := 1.26        # 村景（z ≥ FAR_SPLIT）放大倍数
const VIL_KX := 1.26       # 村景横向倍数（跟 VIL_K 一样＝等比；调小就是"横着挤进来"）
const GROUND_Y := 1132.0   # 村景脚底线：放大锚在这里（村子底部不动，往上长）
const FAR_K := 1.90        # 远山放大倍数（撑到天上当背景）
const FAR_KX := 0.60       # 远山横向倍数：**要压**，否则 f03/f07 那两座崖壁跑出右边
const FAR_BASE_Y := 1120.0 # 远山缩放锚点
const FAR_SPLIT := 30      # z 小于它的算"远山"，大于等于的算"村景"

var _anim: Node = null
var _pieces: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true                      # 超出画布的一律切掉
	size = Vector2(720, 1280)
	var bg := ColorRect.new()
	bg.name = "纸底"
	bg.color = PAPER
	bg.size = Vector2(720, 1280)
	bg.z_index = -100
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# 读布局
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if f == null:
		push_warning("没有 " + LAYOUT_PATH + "，村景层留空")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	_pieces = d.get("pieces", [])
	var fx: Array = d.get("fx", [])
	var ps: Array = []
	for it in _pieces:
		ps.append((it as Dictionary).duplicate())
	ps.sort_custom(func(p1, p2): return int(p1["z"]) < int(p2["z"]))
	var n := Layout.build(self, ps, "p")
	_apply_fit()                              # v97：先放大上提，再挂动效（顺序不能反）
	var fx2 := fit_fx_list(fx)
	_anim = Anim.new()
	add_child(_anim)
	_anim.setup(self, ps, fx2)
	print("[村景层] 建 ", n, " 件，特效 ", fx2.size(), " 组")

# ---- 竖屏适配：把刚建好的件按"远山 / 村景"两档放大并上提 ----
func fit_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(720, 1280))

static func fit_pos(p: Vector2, far: bool) -> Vector2:
	if not FIT:
		return p
	if far:
		return Vector2(CX + (p.x - CX) * FAR_KX, FAR_BASE_Y + (p.y - FAR_BASE_Y) * FAR_K)
	return Vector2(CX + (p.x - CX) * VIL_KX, GROUND_Y + (p.y - GROUND_Y) * VIL_K)

static func fit_k(far: bool) -> float:
	if not FIT:
		return 1.0
	return FAR_K if far else VIL_K

static func fit_fx_list(fx: Array) -> Array:
	var out: Array = []
	for e in fx:
		var d: Dictionary = (e as Dictionary).duplicate()
		var p := fit_pos(Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0))), false)
		d["x"] = p.x
		d["y"] = p.y
		if d.has("rise"):
			d["rise"] = float(d["rise"]) * VIL_K
		if d.has("w"):
			d["w"] = float(d["w"]) * VIL_K
		out.append(d)
	return out

# Layout.build() 只会建件；缩放统一在这里补（**必须在 Anim.setup 之前**——
# 动效会把当时的 position 记成"基准位"，晚一步就是每帧被拽回原位）。
func _apply_fit() -> void:
	for c in get_children():
		if c is Sprite2D:
			var s: Sprite2D = c
			var far: bool = s.z_index < FAR_SPLIT
			var k := fit_k(far)
			s.scale *= k
			s.position = fit_pos(s.position, far)

# 给外面（主界面）用：村景层是否已经建好
func ready_ok() -> bool:
	return _anim != null
