extends Control
# 对照：完整 battle_ui，但不创建怪的本体（怪只在核心逻辑里）
const BATTLE := preload("res://kushou/battle_ui.tscn")
var b = null
var lb: Label = null
var worst := 0.0
var win := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b = BATTLE.instantiate()
	add_child(b)
	b._no_tokens = true
	if b._dbg_lb != null:
		b._dbg_lb.visible = false
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
