extends Node
# ============================================================
# scene_anim.gd —— 摆景的"活起来"（v95）
#   用户（2026-10-08）："这些鸟需要会动 / 树和竹会随风摇摆 / 房子上方些烟囱冒烟 / 船只和水流动"
#
#   分两半：
#     ① **逐件动**（读布局 JSON 里每件的 anim 字段）：
#          sway  = 绕**脚下**来回摆（树、竹）
#          bob   = 上下浮动 + 轻微转（船）
#          flow  = 微微左右淌（水）
#     ② **场景级特效**（读 fx 数组，代码画，不用新素材）：
#          smoke = 从某个点往上冒的白烟（烟囱）
#          birds = 一小群墨鸟横飞（会扇翅膀）
#
#   ⚠ 前提：**要动的东西必须是独立的一件**。像"村景整张画"里画死的船/鸟/树，
#     动不了——得先把它们抠成独立件（这条我在给用户的话里写清楚了）。
# ============================================================
const UIBar := preload("res://shared/ui_bar.gd")   # 只为了确保依赖顺序一致（无实际使用）

var frame: Control = null
var pieces: Array = []
var fx: Array = []
var t := 0.0
var _sprites: Array = []
var _overlay: Control = null

func setup(p_frame: Control, p_pieces: Array, p_fx: Array = []) -> void:
	frame = p_frame
	pieces = p_pieces
	fx = p_fx
	# 收下刚建好的 sprite（按名字对上 JSON）
	# 按**贴图路径**认件（比名字稳：Godot 自动起的名字是 @Sprite2D@12345 这种）
	var all := _all_sprites(frame)
	for i in pieces.size():
		var it: Dictionary = pieces[i]
		var want := str(it.get("tex", ""))
		var s: Sprite2D = null
		for cand in all:
			if cand.texture != null and cand.texture.resource_path == want and not cand.has_meta("_anim_taken"):
				s = cand
				break
		if s != null:
			s.set_meta("_anim_taken", true)
			_sprites.append({"sp": s, "it": it, "base": s.rotation, "bx": s.position.x, "by": s.position.y})
	if not fx.is_empty():
		_overlay = Control.new()
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_overlay.draw.connect(_draw_fx)
		frame.add_child(_overlay)
	set_process(true)

func _all_sprites(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Sprite2D:
			out.append(c)
		out.append_array(_all_sprites(c))
	return out

func _process(d: float) -> void:
	t += d
	for e in _sprites:
		var s: Sprite2D = e["sp"]
		var it: Dictionary = e["it"]
		var a: Dictionary = it.get("anim", {})
		if a.is_empty():
			continue
		var kind := str(a.get("type", ""))
		var amp := float(a.get("amp", 0.02))
		var spd := float(a.get("speed", 1.0))
		var ph := float(a.get("phase", 0.0))
		match kind:
			"sway":
				s.rotation = float(e["base"]) + sin(t * spd + ph) * amp
			"bob":
				var dy: float = sin(t * spd + ph) * float(a.get("dy", 4.0))
				var dx: float = cos(t * spd * 0.7 + ph) * float(a.get("dx", 2.0))
				s.position = Vector2(float(e["bx"]) + dx, float(e["by"]) + dy)
				s.rotation = float(e["base"]) + sin(t * spd * 1.3 + ph) * amp
			"flow":
				s.position = Vector2(float(e["bx"]) + sin(t * spd + ph) * float(a.get("dx", 6.0)), float(e["by"]))
			"idle":
				# v97（用户："村子里的'人'用画里的人，慢慢动就行"）：**极慢**的呼吸式微动。
				#   amp 是"原图像素"，站着的件绕**脚下**轻晃 + 上下浮，一轮十几秒，肉眼只觉得"活着"。
				var ip := t * spd + ph
				s.position = Vector2(float(e["bx"]) + sin(ip * 0.7) * amp * 0.5, float(e["by"]) + sin(ip) * amp)
				s.rotation = float(e["base"]) + sin(ip * 0.5) * 0.02
	if _overlay != null:
		_overlay.queue_redraw()

# ---- 场景级特效：烟 / 鸟（全用代码画，不需要新素材）----
func _draw_fx() -> void:
	if _overlay == null:
		return
	for e in fx:
		var d: Dictionary = e
		match str(d.get("type", "")):
			"smoke":
				_draw_smoke(d)
			"birds":
				_draw_birds(d)

func _draw_smoke(d: Dictionary) -> void:
	var x := float(d.get("x", 0.0))
	var y := float(d.get("y", 0.0))
	var n := int(d.get("n", 3))
	for i in n:
		# 每缕烟按自己的节拍升起、变大、淡出（周期错开，看着才连续）
		var ph := fmod(t * 0.35 + float(i) / float(n), 1.0)
		var cy := y - ph * float(d.get("rise", 46.0))
		var cx := x + sin(ph * 6.283 + float(i)) * 6.0
		var r := 5.0 + ph * 11.0
		var al := (1.0 - ph) * 0.26
		# ⚠ 烟用**淡墨灰**，别用白：底是宣纸色，白烟在纸上等于隐形（第一版就看不见）
		_overlay.draw_circle(Vector2(cx, cy), r, Color(0.58, 0.58, 0.56, al))
		_overlay.draw_circle(Vector2(cx + r * 0.5, cy - r * 0.4), r * 0.7, Color(0.66, 0.66, 0.63, al * 0.8))

func _draw_birds(d: Dictionary) -> void:
	var n := int(d.get("n", 5))
	var w := float(d.get("w", 320.0))
	var x0 := float(d.get("x", 0.0))
	var y0 := float(d.get("y", 0.0))
	for i in n:
		var ph := fmod(t * 0.06 * float(d.get("speed", 1.0)) + float(i) * 0.17, 1.0)
		var bx := x0 + ph * w
		var by := y0 + sin(ph * 6.283 * 1.5 + float(i)) * 10.0 + float(i % 3) * 9.0
		# 翅膀开合：两根短线画成"人"字
		var flap := sin(t * 6.0 + float(i) * 1.3) * 0.5 + 0.5
		var s := 5.0 + float(i % 2) * 2.0
		var c := Color(0.16, 0.15, 0.17, 0.85)
		_overlay.draw_line(Vector2(bx - s, by + s * flap * 0.5), Vector2(bx, by), c, 1.6)
		_overlay.draw_line(Vector2(bx, by), Vector2(bx + s, by + s * flap * 0.5), c, 1.6)
