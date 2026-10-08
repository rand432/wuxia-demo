@tool
extends Control
# ============================================================
# dock.gd —— 「摆景器」面板（v94）
#   左边一列：类别 → 缩略图；点一下就把这件素材放进正在编辑的场景里（落在 2D 视图正中）
#   底下：保存布局 JSON / 按 JSON 重摆 / 地平线参考
#
#   设计原则（给用户用，不是给我用）：
#     · 打开就能用：点一下就有东西，不用看说明书；
#     · 存盘只写一个 JSON，人能读、AI 能读、游戏直接读；
#     · 参考线不写进场景（owner 留空 → Godot 不会存它）。
# ============================================================
const Layout := preload("res://shared/scene_layout.gd")

const ART_ROOT := "res://assets/scenes/ink"
const LAYOUT_PATH := "res://assets/scenes/village_layout.json"
const GROUND_Y := 900.0

var _cat_btns: Array = []
var _grid: GridContainer = null
var _status: Label = null
var _cat := ""
var _cats: Array = []
var _horizon: Node2D = null
var _size_btn: OptionButton = null
var _horizon_on := false      # 供「项目 → 工具」菜单里的那一项同步开关状态
# 放进来时的**目标高度**（像素）——比"缩放 0.0837"直观得多；
# 大中小三档覆盖：小件（花草）/ 中件（房子、树）/ 大件（整幅背景、牌坊）
const SIZES := [{"cn": "小 90", "h": 90.0}, {"cn": "中 180", "h": 180.0}, {"cn": "大 320", "h": 320.0}, {"cn": "很大 520", "h": 520.0}]

func _ready() -> void:
	_build_ui()
	_scan_cats()

func _build_ui() -> void:
	custom_minimum_size = Vector2(240, 400)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var title := Label.new()
	title.text = "摆 景 器"
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)

	var hint := Label.new()
	hint.text = "点缩略图 → 落到画面正中\n拖/缩放用 Godot 自己的操作"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.6)
	root.add_child(hint)

	var cats := HBoxContainer.new()
	root.add_child(cats)
	for c in ["house", "tree", "water", "far", "bg"]:
		var b := Button.new()
		b.text = {"house": "房", "tree": "树", "water": "水", "far": "山", "bg": "整"}.get(c, c)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(52, 28)
		b.pressed.connect(_on_cat.bind(c))
		cats.add_child(b)
		_cat_btns.append(b)

	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(230, 320)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	sc.add_child(_grid)

	var size_row := HBoxContainer.new()
	root.add_child(size_row)
	var sl := Label.new()
	sl.text = "放进来的大小"
	sl.add_theme_font_size_override("font_size", 11)
	size_row.add_child(sl)
	_size_btn = OptionButton.new()
	for s in SIZES:
		_size_btn.add_item(str(s["cn"]))
	_size_btn.selected = 1
	size_row.add_child(_size_btn)

	# ---- 叠层（用户："不能叠层吗"）----
	#   Godot 的 2D 编辑器本来就能叠层，两条路：
	#     ① Scene 面板里上下拖节点（同级后画的盖前面的）；
	#     ② Inspector 改 Z Index（**z 大的永远盖住 z 小的，跟树顺序无关**）。
	#   我存/读走的正是 z_index，所以给你两颗一键按钮，省得天天进 Inspector。
	var layer_row := HBoxContainer.new()
	root.add_child(layer_row)
	var up := Button.new()
	up.text = "上移一层"
	up.tooltip_text = "选中件 z+1（往前站）"
	up.pressed.connect(_bump_z.bind(1))
	layer_row.add_child(up)
	var dn := Button.new()
	dn.text = "下移一层"
	dn.tooltip_text = "选中件 z-1（往后退）"
	dn.pressed.connect(_bump_z.bind(-1))
	layer_row.add_child(dn)

	var save_btn := Button.new()
	save_btn.text = "保存布局 JSON"
	save_btn.pressed.connect(_on_save)
	root.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "按 JSON 重摆"
	load_btn.pressed.connect(_on_reload)
	root.add_child(load_btn)

	var hb := Button.new()
	hb.text = "地平线参考（不存盘）"
	hb.toggle_mode = true
	hb.pressed.connect(_on_horizon)
	root.add_child(hb)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	root.add_child(_status)

func _say(t: String) -> void:
	if _status != null:
		_status.text = t
	print("[摆景器] " + t)

# ---------------- 素材扫描 ----------------
func _scan_cats() -> void:
	_cats = []
	var d := DirAccess.open(ART_ROOT)
	if d != null:
		for sub in d.get_directories():
			_cats.append(sub)
	if not _cats.has("house"):
		_cats.append("house")
	_on_cat(_cats[0] if not _cats.is_empty() else "house")

func _on_cat(c: String) -> void:
	_cat = c
	for i in _cat_btns.size():
		(_cat_btns[i] as Button).button_pressed = (str((_cat_btns[i] as Button).text) == {"house": "房", "tree": "树", "water": "水", "far": "山", "bg": "整"}.get(c, c))
	for ch in _grid.get_children():
		ch.queue_free()
	var dir := ART_ROOT + "/" + c
	var dd := DirAccess.open(dir)
	if dd == null:
		_say("没有这个目录：" + dir)
		return
	var names: Array = []
	for f in dd.get_files():
		if f.to_lower().ends_with(".png"):
			names.append(f)
	names.sort()
	for nm in names:
		var p := dir + "/" + str(nm)
		if not ResourceLoader.exists(p):
			continue
		var t: Texture2D = load(p)
		if t == null:
			continue
		var tb := TextureButton.new()
		tb.texture_normal = t
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tb.custom_minimum_size = Vector2(70, 70)
		tb.tooltip_text = str(nm)
		tb.pressed.connect(_on_piece.bind(p))
		_grid.add_child(tb)
	_say("素材 " + str(names.size()) + " 件（" + c + "）")

# ---------------- 放一件 ----------------
func _view_center() -> Vector2:
	var ei := EditorInterface
	var vp := ei.get_editor_viewport_2d()
	if vp != null:
		var xf: Transform2D = vp.global_canvas_transform
		return -xf.origin / xf.get_scale()
	return Vector2(360.0, GROUND_Y)

func _on_piece(path: String) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_say("先打开一个场景（比如 village_edit.tscn）")
		return
	var t: Texture2D = load(path)
	if t == null:
		return
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.offset = Vector2(-float(t.get_width()) * 0.5, -float(t.get_height()))   # 锚在脚下中间
	# 按"目标高度"自动定缩放（否则 2000×2000 的原图一放进来就铺满整屏）
	var want_h := 180.0
	if _size_btn != null and _size_btn.selected >= 0 and _size_btn.selected < SIZES.size():
		want_h = float(SIZES[_size_btn.selected]["h"])
	var kk := want_h / maxf(1.0, float(t.get_height()))
	s.scale = Vector2(kk, kk)
	var c := _view_center()
	s.position = Vector2(snappedf(c.x, 1.0), snappedf(c.y, 1.0))
	s.name = str(path.get_file().get_basename())
	root.add_child(s)
	s.owner = root                     # 有了 owner 才会被存进场景
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(s)
	_say("放了一件：" + s.name + " → 拖到你要的位置")

# ---------------- 叠层 ----------------
func _bump_z(d: int) -> void:
	var sel := EditorInterface.get_selection().get_selected_nodes()
	if sel.is_empty():
		_say("先选中要调的件（在画布上点一下它）")
		return
	var n := 0
	var z_now := 0
	for node in sel:
		if node is Sprite2D:
			var s: Sprite2D = node
			s.z_index += d
			z_now = s.z_index
			n += 1
	if n > 0:
		EditorInterface.mark_scene_as_unsaved()
		_say("调了 " + str(n) + " 件；当前 z=" + str(z_now) + "（z 越大越靠前）")

# ---------------- 存 / 读 ----------------
func _on_save() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_say("没有打开的场景")
		return
	var n := Layout.save_layout(root, LAYOUT_PATH)
	_say("存了 " + str(n) + " 件（含挂在别人底下的）→ village_layout.json")

func _on_reload() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var pieces := Layout.read_layout(LAYOUT_PATH)
	if pieces.is_empty():
		_say("还没有 village_layout.json")
		return
	# 先清掉旧件：**递归清**（你手工摆的时候很可能把素材挂成了父子，
	#   只清第一层会漏掉挂在别人底下的那些 → 重摆之后新旧叠在一起）
	for c in _all_sprites(root):
		c.queue_free()
	# 摆进「画框」：一个 720×1280 的 Control，clip_contents 开着
	#   —— 用户（2026-10-08）："超出画布的去掉"。素材探出画布的部分从此看不见。
	var frame := root.get_node_or_null("画框") as Control
	if frame == null:
		frame = Layout.make_frame(root)
		frame.owner = root
	var n := Layout.build(frame, pieces, "p")
	for c2 in _all_sprites(root):
		c2.owner = root
	EditorInterface.mark_scene_as_unsaved()
	_say("按 JSON 重摆了 " + str(n) + " 件（旧的已清 · 画框裁剪已开）")

# 递归收出这棵场景里所有的 Sprite2D（含挂在别人底下的）
func _all_sprites(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Sprite2D:
			out.append(c)
		out.append_array(_all_sprites(c))
	return out

# ---------------- 参考线（不存盘）----------------
func _on_horizon(on: bool) -> void:
	_horizon_on = on
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	if on:
		if _horizon != null and is_instance_valid(_horizon):
			return
		var ln := Line2D.new()
		ln.name = "_地平线参考"
		ln.points = PackedVector2Array([Vector2(-2000, GROUND_Y), Vector2(4000, GROUND_Y)])
		ln.width = 2.0
		ln.default_color = Color(0.85, 0.3, 0.25, 0.55)
		root.add_child(ln)
		_horizon = ln
		_say("地平线画在 y=" + str(GROUND_Y) + "（owner 留空，不会存进场景）")
	else:
		if _horizon != null and is_instance_valid(_horizon):
			_horizon.queue_free()
		_horizon = null
		_say("参考线收起来了")
