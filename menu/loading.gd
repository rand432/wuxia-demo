extends Control
# 战斗加载页：场景与首屏贴图就绪后再切入。
const BATTLE := "res://kushou/battle_ui.tscn"
const FONT := preload("res://fonts/ink.ttf")
const UI := preload("res://shared/ui_kit.gd")
var _fill: ColorRect = null
var _pct: Label = null
var _tip: Label = null
var _done := false
var _requesting := false
var _recovery: HBoxContainer
var _battle: Control
var _art_pending: Array[String] = []
var _art_total := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.048, 0.040, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "江 湖 游 历"
	title.position = Vector2(0, 470)
	title.size = Vector2(720, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.88, 0.78, 0.55))
	add_child(title)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.14, 0.12, 0.10, 1.0)
	bar_bg.position = Vector2(100, 566)
	bar_bg.size = Vector2(520, 18)
	add_child(bar_bg)
	_fill = ColorRect.new()
	_fill.color = Color(0.72, 0.56, 0.24, 1.0)
	_fill.position = Vector2(100, 566)
	_fill.size = Vector2(0, 18)
	add_child(_fill)
	_pct = Label.new()
	_pct.text = "0%"
	_pct.position = Vector2(0, 600)
	_pct.size = Vector2(720, 30)
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct.add_theme_font_override("font", FONT)
	_pct.add_theme_font_size_override("font_size", 18)
	_pct.add_theme_color_override("font_color", Color(0.66, 0.60, 0.48))
	add_child(_pct)
	_tip = Label.new()
	_tip.text = "正在踏入江湖…"
	_tip.position = Vector2(0, 640)
	_tip.size = Vector2(720, 26)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.add_theme_font_override("font", FONT)
	_tip.add_theme_font_size_override("font_size", 15)
	_tip.add_theme_color_override("font_color", Color(0.45, 0.41, 0.34))
	add_child(_tip)
	_recovery = HBoxContainer.new()
	_recovery.position = Vector2(160, 710)
	_recovery.add_theme_constant_override("separation", 24)
	add_child(_recovery)
	for caption in ["重试", "返回主页"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size = Vector2(188, 64)
		button.add_theme_font_override("font", FONT)
		_recovery.add_child(button)
		if caption == "重试":
			button.pressed.connect(_start_loading)
		else:
			button.pressed.connect(_return_home)
		UI.Motion.bind_button(button)
	_start_loading()

func _start_loading() -> void:
	if not UI.navigation_available(self) or _requesting: return
	_done = false
	_requesting = true
	_recovery.hide()
	_fill.size.x = 0.0
	_pct.text = "0%"
	_tip.text = "正在踏入江湖…"
	if _request_battle() != OK:
		_loading_failed()

func _request_battle() -> Error:
	return ResourceLoader.load_threaded_request(BATTLE, "", true)

func _return_home() -> void:
	if not _done or not _recovery.visible: return
	UI.navigate(self, "res://menu/main_home.tscn")

func _loading_failed() -> void:
	_done = true
	_requesting = false
	_tip.text = "加载失败，请重试或返回主页"
	_recovery.show()

func _exit_tree() -> void:
	if _battle != null:
		_battle.free()
		_battle = null

func _process(_delta: float) -> void:
	if _done or not UI.navigation_available(self):
		return
	if _battle != null:
		_poll_art()
		return
	var prog: Array = []
	var st := ResourceLoader.load_threaded_get_status(BATTLE, prog)
	var v := float(prog[0]) if prog.size() > 0 else 0.0
	_show_progress(0.45 * v)
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		var ps: PackedScene = ResourceLoader.load_threaded_get(BATTLE)
		if ps == null:
			_loading_failed()
			return
		var instance := ps.instantiate()
		if not instance is Control:
			if instance != null:
				instance.free()
			_loading_failed()
			return
		_battle = instance
		var paths: Array[String] = _battle.prepare_entry_art()
		for path in paths:
			if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path, "Texture2D") == OK:
				_art_pending.append(path)
		_art_total = _art_pending.size()
		_tip.text = "正在准备战场和卡牌…"
		_show_progress(1.0 if _art_pending.is_empty() else 0.45)
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		if st == ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(BATTLE)
		_loading_failed()

func _poll_art() -> void:
	if _art_pending.is_empty():
		_done = true
		_requesting = false
		# 切换场景时当前页会先退出，提前转交新节点的所有权。
		var battle := _battle
		_battle = null
		if UI.navigate_instance(self, battle) != OK:
			battle.free()
			_loading_failed()
		return
	for i in range(_art_pending.size() - 1, -1, -1):
		var path := _art_pending[i]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_FAILED:
			_battle.supply_entry_art(path, ResourceLoader.load_threaded_get(path) as Texture2D)
		_art_pending.remove_at(i)
	_show_progress(1.0 - 0.55 * float(_art_pending.size()) / float(_art_total))

func _show_progress(value: float) -> void:
	var fraction := clampf(value, 0.0, 1.0)
	_fill.size.x = 520.0 * fraction
	_pct.text = "%d%%" % int(fraction * 100.0)
