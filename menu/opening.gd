extends Control
# ============================================================
# menu/opening.gd —— 首次启动的开场（开场片 → 画卷过场 → 主界面）
#
#   第一段：assets/video/opening.ogv          30s  屠龙术·杀猪
#   第二段：assets/video/scroll_transition.ogv 5s  画卷展开（落点＝主界面那张山水）
#   规则：**只在第一次打开游戏时播**；播完 / 点「跳过」都进主界面；
#         之后每次启动直接进主界面（不加载视频、不闪黑）。
#
#   为什么用 ogv：Godot 4 的 VideoStreamPlayer 只认 Ogg Theora，mp4 放不进去。
#   记录：user://opening.cfg（seen=true），跟存档分开
#   调试：启动参数加 --replay-opening 可强制重播
# ============================================================

const NEXT_SCENE := "res://menu/main_home.tscn"
const CFG_PATH := "user://opening.cfg"

# 每段：片源 + 保险丝（万一 finished 不触发也能往下走）
const STAGES := [
	{"path": "res://assets/video/opening.ogv", "timeout": 36.0},
	{"path": "res://assets/video/scroll_transition.ogv", "timeout": 10.0},
]

const GOLD := Color(0.86, 0.68, 0.26)

var _player: VideoStreamPlayer = null
var _skip: Button = null
var _fade: ColorRect = null
var _done := false
var _stage := 0
var _wd_seq := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 已经看过 / 强制重播判定
	if _seen() and not _force():
		_goto_next()
		return

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.03)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_player = VideoStreamPlayer.new()
	_player.expand = true
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.finished.connect(_on_finished)
	add_child(_player)

	_build_skip()
	_fade_in()

	_play_stage(0)

func _build_skip() -> void:
	_skip = Button.new()
	_skip.text = "跳 过"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.position = Vector2(584, 44)
	_skip.size = Vector2(104, 46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.08, 0.42)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.86, 0.68, 0.26, 0.45)
	sb.set_border_width_all(1)
	_skip.add_theme_stylebox_override("normal", sb)
	_skip.add_theme_stylebox_override("hover", sb)
	_skip.add_theme_stylebox_override("pressed", sb)
	_skip.add_theme_color_override("font_color", GOLD)
	_skip.add_theme_font_size_override("font_size", 18)
	if ResourceLoader.exists("res://fonts/ink.ttf"):
		_skip.add_theme_font_override("font", load("res://fonts/ink.ttf"))
	_skip.pressed.connect(_finish)
	add_child(_skip)

func _fade_in() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.35)
	tw.tween_callback(_clear_fade)

func _clear_fade() -> void:
	if _fade != null and is_instance_valid(_fade):
		_fade.queue_free()
		_fade = null

# ---------------- 分段播放 ----------------
func _play_stage(i: int) -> void:
	_stage = i
	if i >= STAGES.size():
		_end_naturally()
		return
	var st: Dictionary = STAGES[i]
	var path := str(st["path"])
	if not ResourceLoader.exists(path):
		push_warning("[opening] 找不到 " + path + "，跳过这一段")
		_play_stage(i + 1)
		return
	var st2 := load(path) as VideoStream
	if st2 == null:
		_play_stage(i + 1)
		return
	_player.stop()
	_player.stream = st2
	_player.play()
	_arm_watchdog(float(st["timeout"]))

func _on_finished() -> void:
	_play_stage(_stage + 1)

func _arm_watchdog(t: float) -> void:
	_wd_seq += 1
	var seq := _wd_seq
	await get_tree().create_timer(t).timeout
	if _done or seq != _wd_seq:
		return
	_play_stage(_stage + 1)

# ---------------- 收尾 ----------------
func _end_naturally() -> void:
	if _done:
		return
	_done = true
	_mark_seen()
	if _player != null:
		_player.stop()
	# 结束前压一层黑，把「整幅画」和主界面的「画框」接起来，不硬切
	if _skip != null:
		_skip.visible = false
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.30)
	tw.tween_callback(_goto_next)

func _finish() -> void:
	if _done:
		return
	_done = true
	_mark_seen()
	_goto_next()

func _goto_next() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and (ev as InputEventKey).keycode == KEY_ESCAPE:
		_finish()

# ---------------- 记录「看过」 ----------------
func _seen() -> bool:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		return false
	return bool(cf.get_value("opening", "seen", false))

func _mark_seen() -> void:
	if _force():
		return
	var cf := ConfigFile.new()
	cf.load(CFG_PATH)
	cf.set_value("opening", "seen", true)
	cf.save(CFG_PATH)

func _force() -> bool:
	for a in OS.get_cmdline_args():
		if a == "--replay-opening":
			return true
	return false
