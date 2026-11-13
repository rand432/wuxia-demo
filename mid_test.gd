extends Control
# 中间对照：背景 + 主角 + 战斗核心（刷怪/自绘），不带 UI/黑市/请神/抽卡
const FONT := preload("res://fonts/ink.ttf")
const BattleCore := preload("res://kushou/kushou_battle.gd")
var lb: Label = null
var core = null
var worst := 0.0
var win := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.93, 0.90, 0.82, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	core = BattleCore.new()
	core.position = Vector2(8, 150)
	core.size = Vector2(704, 720)
	core.modulate = Color(1, 1, 1, 1.0)
	core.setup({"atk": 12.0, "hp_max": 200.0, "mp_max": 100.0})
	core.set_wave(1)
	add_child(core)
	core.start_run()
	lb = Label.new()
	lb.position = Vector2(20, 30)
	lb.size = Vector2(420, 120)
	lb.add_theme_font_override("font", FONT)
	lb.add_theme_font_size_override("font_size", 20)
	lb.add_theme_color_override("font_color", Color(0.10, 0.55, 0.22))
	add_child(lb)
	set_process(true)

func _process(delta: float) -> void:
	worst = maxf(worst, delta)
	win += delta
	if win >= 2.0:
		var foes_n := 0
		if core != null:
			foes_n = core.foes.size()
		lb.text = "FPS %d\nworst %.0fms\nfoes %d" % [Engine.get_frames_per_second(), worst * 1000.0, foes_n]
		win = 0.0
		worst = 0.0
