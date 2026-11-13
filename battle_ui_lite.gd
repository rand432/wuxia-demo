extends Control
# battle_ui 精简版：保留完整战斗，但关掉非战斗 UI 面板，用来定位卡顿
const BATTLE := preload("res://kushou/battle_ui.tscn")
var b = null
var lb: Label = null
var worst := 0.0
var win := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b = BATTLE.instantiate()
	add_child(b)
	# 关掉所有非战斗 UI
	if b._dbg_lb != null:
		b._dbg_lb.visible = false
	if b._draw_layer != null:
		b._draw_layer.visible = false
	if b._god_layer != null:
		b._god_layer.visible = false
	if b._str_layer != null:
		b._str_layer.visible = false
	if b._trea_layer != null:
		b._trea_layer.visible = false
	if b._combined_layer != null:
		b._combined_layer.visible = false
	if b._exit_layer != null:
		b._exit_layer.visible = false
	if b._bm != null:
		b._bm.visible = false
	if b._tut != null:
		b._tut.queue_free()
	lb = Label.new()
	lb.position = Vector2(20, 30)
	lb.size = Vector2(420, 120)
	lb.add_theme_font_size_override("font_size", 20)
	lb.add_theme_color_override("font_color", Color(0.10, 0.55, 0.22))
	lb.z_index = 300
	add_child(lb)
	set_process(true)

func _process(delta: float) -> void:
	worst = maxf(worst, delta)
	win += delta
	if win >= 2.0:
		var foes_n := 0
		if b != null and b._core != null:
			foes_n = b._core.foes.size()
		lb.text = "FPS %d\nworst %.0fms\nfoes %d" % [Engine.get_frames_per_second(), worst * 1000.0, foes_n]
		win = 0.0
		worst = 0.0
