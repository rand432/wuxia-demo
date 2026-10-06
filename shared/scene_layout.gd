extends RefCounted
# ============================================================
# scene_layout.gd —— 「摆景」的存/读核心（v94）
#
#   用户（2026-10-06）："你能专门做一个工具 用于布置我这个游戏的场景…我直接拖动需要的素材进行拼接
#   然后方便你也理解这种"
#
#   分工：
#     · **编辑器插件**（addons/scene_painter）负责让你拖——它只调这里的两个函数；
#     · 这里是**纯逻辑**，编辑器内外都能跑（所以我能用探针headless测它，游戏里也直接读同一个 JSON）。
#
#   JSON 长这样（人能读、我更能读、游戏直接读）：
#     { "version": 1, "pieces": [ {"tex": "res://assets/scenes/ink/house/h12.png",
#       "x": 320.0, "y": 880.0, "scale": 1.2, "rot": 0.0, "z": 3, "alpha": 1.0 }, … ] }
# ============================================================
const VERSION := 1

# ---- 从场景里"扫"出可保存的节点：Sprite2D（子树全扫）----
static func collect(root: Node) -> Array:
	var out: Array = []
	_walk(root, out)
	return out

static func _walk(n: Node, out: Array) -> void:
	if n is Sprite2D and n.texture != null:
		var s: Sprite2D = n
		out.append({
			"name": str(s.name),
			"tex": s.texture.resource_path,
			# 同时记下"现在多高"（h）——你摆完存盘，我看到的就是"这栋房子 168 像素高"，
			# 比 0.0837 这种倍数好读得多
			"h": snappedf(float(s.texture.get_height()) * s.scale.y, 1.0),
			"x": snappedf(s.position.x, 0.5),
			"y": snappedf(s.position.y, 0.5),
			"scale": snappedf(s.scale.x, 0.001),
			"rot": snappedf(s.rotation, 0.001),
			"z": s.z_index,
			"alpha": snappedf(s.modulate.a, 0.01),
		})
	for c in n.get_children():
		_walk(c, out)

# ---- 存盘 ----
static func save_layout(root: Node, path: String) -> int:
	var pieces := collect(root)
	var data := {"version": VERSION, "pieces": pieces}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("写不了 " + path)
		return 0
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return pieces.size()

# ---- 读盘（原样返回 pieces）----
static func read_layout(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary and (parsed as Dictionary).has("pieces"):
		return (parsed as Dictionary)["pieces"]
	return []

# ---- 把 JSON 摆成一个 Node2D 子树（游戏里直接用；编辑器里也能"按 JSON 重摆"）----
static func build(parent: Node2D, pieces: Array, name_prefix := "p") -> int:
	var n := 0
	for i in pieces.size():
		var it: Dictionary = pieces[i]
		var t: Texture2D = null
		var p := str(it.get("tex", ""))
		if p != "" and ResourceLoader.exists(p):
			t = load(p)
		if t == null:
			continue
		var s := Sprite2D.new()
		s.name = str(it.get("name", name_prefix + str(i)))
		s.texture = t
		s.centered = false
		# 统一"锚在脚下中间"：贴图左上角 = 位置 - (宽/2, 高)
		s.offset = Vector2(-float(t.get_width()) * 0.5, -float(t.get_height()))
		s.position = Vector2(float(it.get("x", 0.0)), float(it.get("y", 0.0)))
		# 支持两种写法：给 scale（倍数）或给 h（**目标高度像素**）。
		# 后者更符合"摆景"的直觉——"这栋房子在画面上大概 170 像素高"，
		# 而且不会像第一版起手布局那样：2000×2000 的原图乘 0.8 直接铺满整屏。
		var sc := float(it.get("scale", 1.0))
		if it.has("h"):
			sc = float(it["h"]) / maxf(1.0, float(t.get_height()))
		s.scale = Vector2(sc, sc)
		s.rotation = float(it.get("rot", 0.0))
		s.z_index = int(it.get("z", 0))
		s.modulate = Color(1, 1, 1, float(it.get("alpha", 1.0)))
		parent.add_child(s)
		n += 1
	return n
