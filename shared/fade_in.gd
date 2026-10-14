extends Control
# ============================================================
# 进场淡入 v1（v68）：切场景时先盖一层纸色，0.35 秒"化开"露出画面。
#
#   为什么只做淡入不做淡出：淡出要拦住每一个跳转点（十来处按钮 + 自动流程），
#   漏一个就卡死；淡入挂在场景自己身上，零风险，观感上已经"接得住"了。
#
#   挂法：在场景 _ready 里 FadeIn.attach()（每次调用都会重新盖一层）
# ============================================================

# 震动：大招/重击时给手机一下（PC 上是空操作）
static func buzz(ms := 90) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

static func attach() -> void:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return
	var root := (ml as SceneTree).root
	if root == null:
		return
	# 上一场的遮罩若还在，先摘掉再挂新的（切场景就是要重新盖一次）
	var old := root.get_node_or_null("FadeIn")
	if old != null:
		root.remove_child(old)
		old.queue_free()
	var c := Control.new()
	c.set_script(load("res://shared/fade_in.gd"))
	c.name = "FadeIn"
	# v15h：同上 —— 启动时根节点还在建子节点，直接 add_child 会失败
	root.add_child.call_deferred(c)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 300
	var r := ColorRect.new()
	r.color = Color(0.94, 0.92, 0.87, 1.0)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(queue_free)
