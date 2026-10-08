extends Control
# ============================================================
# menu_ink_scene.gd —— 主界面的**水墨村景层**（v96）
#   数据来自 assets/scenes/village_layout.json（用户在摆景器里排的那一版）：
#     · 13 件：远山×5（0.28→0.60 渐隐）· 村景 · 柳 · 竹 · 水 · 船 · 树×3
#     · 动效：sway / bob / flow + 代码画的烟与鸟
#     · 遮挡：远山在村景处已烘焙裁掉；整层套 720×1280 画框（clip_contents）
#
#   为什么是 Control 而不是 Node2D：**要裁剪**（用户："超出画布的去掉"）。
#   用法：`var s := InkScene.new(); add_child(s)` —— 它自己读 JSON 建件、挂动效。
# ============================================================
const Layout := preload("res://shared/scene_layout.gd")
const Anim := preload("res://shared/scene_anim.gd")

const LAYOUT_PATH := "res://assets/scenes/village_layout.json"
const PAPER := Color(0.945, 0.925, 0.882, 1.0)

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
	_anim = Anim.new()
	add_child(_anim)
	_anim.setup(self, ps, fx)
	print("[村景层] 建 ", n, " 件，特效 ", fx.size(), " 组")

# 给外面（主界面）用：村景层是否已经建好
func ready_ok() -> bool:
	return _anim != null
