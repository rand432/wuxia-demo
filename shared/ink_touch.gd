extends Control
# ============================================================
# 点击 · 水滴入墨 v1
#   点哪儿，哪儿就晕开一圈墨：中心一点浓墨 + 两圈不规则墨环向外扩散、变淡；
#   笔画边缘故意抖动（不是正圆），才像毛笔点在宣纸上，而不是 UI 的圆角动画。
#
#   挂法：InkTouch.attach()（同一棵树上只会挂一个）
#   输入：mouse_filter = IGNORE，绝不吞点击；用 _input 收全局按下（按钮点掉的也照样收得到）
# ============================================================

const LIFE := 0.62          # 一滴墨的寿命（秒）
const MAX_R := 150.0        # 最大半径（设计分辨率 720 宽下）
const INK := Color(0.10, 0.10, 0.12)

static var _inst: Control = null

static func attach() -> void:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return
	var root := (ml as SceneTree).root
	if root == null:
		return
	if _inst != null and is_instance_valid(_inst) and _inst.get_parent() == root:
		return
	var c := Control.new()
	c.set_script(load("res://shared/ink_touch.gd"))
	c.name = "InkTouch"
	# v15h：⚠ 根节点"正在建子节点"时 add_child 会直接失败（启动时报 Parent node is busy）。
	#   这些都是被 _ready() 里调到的，所以必须 deferred 挂。
	root.add_child.call_deferred(c)

var _drops: Array = []
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200

func _input(ev: InputEvent) -> void:
	var pos := Vector2.ZERO
	var hit := false
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (ev as InputEventMouseButton).position
		hit = true
	elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
		pos = (ev as InputEventScreenTouch).position
		hit = true
	if hit:
		drop_at(pos)

# 程序化点一滴墨（脚本演出、剧情提示也能用）
func drop_at(pos: Vector2) -> void:
	_drops.append({"p": pos, "t": 0.0, "seed": randf() * 100.0})
	if _drops.size() > 8:
		_drops.pop_front()
	queue_redraw()

func _process(delta: float) -> void:
	if _drops.is_empty():
		return
	_t += delta
	var i := _drops.size() - 1
	while i >= 0:
		var d: Dictionary = _drops[i]
		d["t"] = float(d["t"]) + delta
		if float(d["t"]) >= LIFE:
			_drops.remove_at(i)
		i -= 1
	queue_redraw()

# 一滴墨分三层画（不然只是"线框圆"，一点墨味都没有）：
#   ① 墨心——一小团浓墨，先浓后淡
#   ② 墨晕——由内而外几层抖动多边形，边缘毛、中心厚
#   ③ 溅环——一圈细而快的墨线，甩到最外
func _draw() -> void:
	for dv in _drops:
		var d: Dictionary = dv
		var k := clampf(float(d["t"]) / LIFE, 0.0, 1.0)
		var p: Vector2 = d["p"]
		var sd: float = d["seed"]
		var core := clampf(1.0 - k / 0.45, 0.0, 1.0)
		if core > 0.0:
			var cr := 3.0 + 11.0 * (1.0 - core)
			for i in 3:
				draw_circle(p, cr * (1.0 - float(i) * 0.26), Color(INK.r, INK.g, INK.b, 0.30 * core))
		var wash := clampf(k / 0.85, 0.0, 1.0)
		if wash > 0.0 and wash < 1.0:
			var wr := MAX_R * 0.72 * pow(wash, 0.5)
			for i in 4:
				var wa := (1.0 - wash) * 0.16 * (0.55 + 0.15 * float(i))
				_ink_blob(p, wr * (1.0 - float(i) * 0.16), wa, sd + float(i) * 1.7)
		var rk := clampf(k / 0.75, 0.0, 1.0)
		if rk > 0.0 and rk < 1.0:
			_ink_ring(p, MAX_R * pow(rk, 0.5), (1.0 - rk) * 0.34, sd, 2.6 * (1.0 - rk) + 1.2)

const SEG := 26

func _blob_pts(c: Vector2, r: float, seed_v: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(SEG):
		var ang := TAU * float(i) / float(SEG)
		var j := 1.0 + 0.10 * sin(ang * 3.0 + seed_v) + 0.05 * sin(ang * 5.0 + seed_v * 2.3) + 0.03 * sin(ang * 11.0 + seed_v * 4.1)
		pts.append(c + Vector2(cos(ang), sin(ang)) * r * j)
	return pts

func _ink_blob(c: Vector2, r: float, a: float, seed_v: float) -> void:
	if r < 2.0 or a <= 0.0:
		return
	draw_colored_polygon(_blob_pts(c, r, seed_v), Color(INK.r, INK.g, INK.b, a))

func _ink_ring(c: Vector2, r: float, a: float, seed_v: float, w: float) -> void:
	if r < 1.5 or a <= 0.0:
		return
	var pts := _blob_pts(c, r, seed_v)
	pts.append(pts[0])
	draw_polyline(pts, Color(INK.r, INK.g, INK.b, a), w, true)
