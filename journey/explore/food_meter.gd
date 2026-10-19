extends Control
# 食物饼：0~100 主条，>100 存粮金环。数值由外部 Label 负责，这里只画饼与进度。

var value := 60
var shown := 60.0
var max_value := 100

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(44, 44)

func set_value(v: int) -> void:
	value = clampi(v, 0, 999)
	if shown <= 0.0:
		shown = float(mini(value, max_value))
		queue_redraw()

func _process(delta: float) -> void:
	var target := float(mini(value, max_value))
	if absf(shown - target) < 0.05:
		if shown != target:
			shown = target
			queue_redraw()
		return
	shown = lerpf(shown, target, minf(1.0, delta * 8.0))
	queue_redraw()

func _draw() -> void:
	var c := Vector2(22, 22)
	var frac := clampf(shown / float(max_value), 0.0, 1.0)
	draw_circle(c + Vector2(0, 2), 21.0, Color(0, 0, 0, 0.38))
	draw_circle(c, 20.0, Color("#b98a4e"))
	draw_circle(c, 17.0, Color("#e8c987"))
	# 芝麻
	for p in [Vector2(-6, -5), Vector2(5, -7), Vector2(7, 6), Vector2(-4, 8), Vector2(0, 0)]:
		draw_circle(c + p, 1.4, Color("#8a642c"))
	# 缺粮咬痕：从右侧边缘咬掉几口
	var bites := int(round((1.0 - frac) * 6.0))
	for i in bites:
		var a := -0.35 + float(i) * 0.55
		var edge := c + Vector2(cos(a), sin(a)) * 19.0
		draw_circle(edge, 5.2, Color("#12100d"))
	# 主条弧
	if frac > 0.02:
		draw_arc(c, 22.5, -PI * 0.5, -PI * 0.5 + TAU * frac, 28, Color("#f0d68a"), 2.6, true)
	if value > max_value:
		draw_arc(c, 25.5, 0.0, TAU, 32, Color("#ffd66a"), 2.0, true)
		draw_circle(c + Vector2(15, -16), 3.0, Color("#ffe6a0"))
