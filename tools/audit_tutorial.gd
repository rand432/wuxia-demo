extends SceneTree
const Overlay := preload("res://kushou/tutorial_overlay.gd")
var first := 0
var second := 0
var resumed := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var target := Button.new()
	root.add_child(target)
	var overlay := Overlay.new()
	root.add_child(overlay)
	overlay.open(target, "first", func(): first += 1, Callable(), func(): resumed += 1)
	overlay._on_pressed()
	overlay._on_pressed()
	assert(first == 1 and resumed == 1)
	# 完成信号打开下一步，旧步骤只能执行自己的回调。
	overlay.done.connect(func(): overlay.open(target, "second", func(): second += 1), CONNECT_ONE_SHOT)
	overlay.open(target, "first again", func(): first += 1)
	overlay._on_pressed()
	assert(first == 2 and second == 0 and overlay.visible)
	overlay._on_pressed()
	assert(second == 1 and not overlay.visible)
	overlay.open(target, "cancel", func(): first += 1, Callable(), func(): resumed += 1)
	var completed := [0]
	overlay.done.connect(func(): completed[0] += 1)
	overlay.cancel()
	overlay.cancel()
	overlay._on_pressed()
	assert(not overlay.visible and resumed == 2 and first == 2 and completed[0] == 0)
	overlay.free()
	target.free()
	print("PASS: tutorial completion once, nested step callbacks isolated; cancellation resumes once without completion or target action")
	quit()
