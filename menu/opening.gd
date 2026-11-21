extends Control
# ============================================================
# menu/opening.gd —— 首次启动的开场动画（30 秒）
#
#   片源：assets/video/opening.ogv（720x1280 / 24fps / 30s，由 download.mp4 转码）
#   规则：**只在第一次打开游戏时播**，播完或点「跳过」都进主界面；
#         之后每次启动直接进主界面（不闪黑、不加载视频）。
#
#   为什么用 ogv：Godot 4 的 VideoStreamPlayer 只认 Ogg Theora，mp4 放不进去。
#   记录位置：user://opening.cfg（跟存档分开，别混）
#   调试：启动参数加 --replay-opening 可以强制重播
# ============================================================

const NEXT_SCENE := "res://menu/main_home.tscn"
const VIDEO_PATH := "res://assets/video/opening.ogv"
const CFG_PATH := "user://opening.cfg"

const GOLD := Color(0.86, 0.68, 0.26)
const INK := Color(0.10, 0.09, 0.08)

var _player: VideoStreamPlayer = null
var _skip: Button = null
var _fade: ColorRect = null
var _done := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 已经看过 / 片源缺失 → 直接进主界面
	if _seen() and not _force():
		_goto_next()
		return
	if not ResourceLoader.exists(VIDEO_PATH):
		push_warning("[opening] 找不到 " + VIDEO_PATH + "，跳过开场")
		_goto_next()
		return

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.03)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_player = VideoStreamPlayer.new()
	_player.stream = load(VIDEO_PATH)
	_player.expand = true
	_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.finished.connect(_on_finished)
	add_child(_player)
	_player.play()

	# 跳过键（右上角，别挡字幕）
	_skip = Button.new()
	_skip.text = "跳 过"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.position = Vector2(584, 44)
	_skip.size = Vector2(104, 46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.08, 0.62)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.86, 0.68, 0.26, 0.55)
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

	# 黑场淡入，避免第一帧硬切
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.35)
	tw.tween_callback(_clear_fade)

	# 保险：万一 finished 不触发（某些平台视频解码失败），36 秒后也必须进主界面
	var wd := get_tree().create_timer(36.0)
	wd.timeout.connect(_finish)

func _clear_fade() -> void:
	if _fade != null and is_instance_valid(_fade):
		_fade.queue_free()
		_fade = null

func _on_finished() -> void:
	_finish()

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
		return   # 调试重播时不留痕
	var cf := ConfigFile.new()
	cf.load(CFG_PATH)
	cf.set_value("opening", "seen", true)
	cf.save(CFG_PATH)

func _force() -> bool:
	for a in OS.get_cmdline_args():
		if a == "--replay-opening":
			return true
	return false
