extends Node
# ============================================================
# twitch_recorder.gd —— 抽搐取证器（v63k 抽成独立文件，主界面 B 键 / 游历按钮共用）
#   按开始后 5 秒（约 300 帧）内，**所有**火柴人每帧记一行：
#   x/y 位移 + 躯干/前腿/前臂角 + 位移补间是否在跑。
#   写进 user://twitch_dump.csv（约 300 行 × 几人，几 KB）。
#   屏幕顶部挂黄字计数器（录没录上一眼可见），录完换成"完成"字样停 3.5 秒自毁。
#   把文件发回来就能算：谁在抖、抖多快、是"位置跳"（补间抢写）还是"关节跳"（弹簧）。
# ============================================================

const SF := preload("res://journey/stick_fighter.gd")

var frames := 0
var total := 300
var out: FileAccess = null
var tag: Label = null
var done_t := -1.0
var _path := "res://twitch_dump.csv"   # v63k：优先写项目目录（开发机上一录完就在工程里）；导出包退回 user://

func _ready() -> void:
	out = FileAccess.open(_path, FileAccess.WRITE)
	if out == null:
		_path = "user://twitch_dump.csv"
		out = FileAccess.open(_path, FileAccess.WRITE)
	if out == null:
		queue_free()
		return
	out.store_line("frame,node,x,y,torso,leg_f,arm_f,k,d,cap,tgt0,busy")
	tag = Label.new()
	tag.text = "● 抽搐取证 0/" + str(total)
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	var vp: Vector2 = get_viewport().get_visible_rect().size
	tag.position = Vector2(vp.x * 0.5 - 360.0, 8.0)
	tag.size = Vector2(720, 36)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tag)

func _process(delta: float) -> void:
	if done_t > 0.0:
		done_t -= delta
		if done_t <= 0.0:
			queue_free()
		return
	if out == null:
		queue_free()
		return
	frames += 1
	var list: Array = []
	_collect(get_tree().root, list)
	var line := str(frames)
	for n in list:
		line += (",%s,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%s"
			% [str(n.name), n.global_position.x, n.global_position.y,
			n.cur[0], n.cur[5], n.cur[1],
			n.spring_k, n.spring_d, n.vel_cap, n.tgt[0],
			"1" if n._move_busy else "0"])
	out.store_line(line)
	if tag != null:
		tag.text = "● 抽搐取证 " + str(frames) + "/" + str(total)
	if frames >= total:
		out.close()
		out = null
		done_t = 3.5
		if tag != null:
			tag.text = "● 取证完成 → twitch_dump.csv（" + str(list.size()) + " 人 · " + str(frames) + " 帧）"
		print("[抽搐取证] 完成：", ProjectSettings.globalize_path(_path),
			"（", frames, " 帧 · 火柴人 ", list.size(), "）")

func _collect(n: Node, arr: Array) -> void:
	for c in n.get_children():
		if c.get_script() == SF:
			arr.append(c)
		_collect(c, arr)
