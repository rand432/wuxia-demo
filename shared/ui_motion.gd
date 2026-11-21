extends RefCounted
# 共用的短促触感；不延迟按钮业务回调，空闲时不逐帧处理。
class PressFeedback extends Control:
	var _button: Button
	var _tween: Tween
	var _age := 1.0
	var _stroke := StyleBoxFlat.new()
	var _visual_scale := 1.0:
		set(value):
			_visual_scale = value
			_apply_pose()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_button = get_parent() as Button
		_center()
		_button.resized.connect(_center)
		_button.button_down.connect(_down)
		_button.button_up.connect(_release)
		_button.mouse_exited.connect(_release)
		_button.pressed.connect(_pulse)
		_stroke.bg_color = Color.TRANSPARENT
		_stroke.set_border_width_all(2)
		_stroke.set_corner_radius_all(12)
		set_process(false)

	func _center() -> void:
		_apply_pose()

	func _apply_pose() -> void:
		if not is_instance_valid(_button): return
		var center := _button.size * 0.5
		var pose := Transform2D.IDENTITY.scaled(Vector2.ONE * _visual_scale)
		pose.origin = center * (1.0 - _visual_scale)
		# 只缩放绘制，不缩小实际点击区域，边缘按下后松手也能正常触发。
		RenderingServer.canvas_item_set_transform(_button.get_canvas_item(), _button.get_transform() * pose)

	func _available() -> bool:
		return is_inside_tree() and not _button.is_queued_for_deletion() and _button.is_visible_in_tree() and not _button.disabled

	func _begin() -> void:
		if _tween != null and _tween.is_valid(): _tween.kill()
		_tween = create_tween()

	func _down() -> void:
		if not _available(): return
		_begin()
		_tween.tween_property(self, "_visual_scale", 0.965, 0.065).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func _release() -> void:
		if not is_inside_tree() or _button.is_queued_for_deletion(): return
		_begin()
		_tween.tween_property(self, "_visual_scale", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _pulse() -> void:
		if not _available(): return
		_age = 0.0
		set_process(true)
		queue_redraw()

	func _process(dt: float) -> void:
		_age += dt
		queue_redraw()
		if _age >= 0.32: set_process(false)

	func _draw() -> void:
		if _age >= 0.32: return
		var p := clampf(_age / 0.32, 0.0, 1.0)
		_stroke.border_color = Color(0.86, 0.67, 0.32, 0.5 * (1.0 - p))
		draw_style_box(_stroke, Rect2(Vector2.ZERO, size).grow(2.0 + 9.0 * (1.0 - pow(1.0 - p, 3.0))))

static func bind_button(button: Button) -> void:
	if button.get_node_or_null("PressFeedback") != null: return
	var feedback := PressFeedback.new()
	feedback.name = "PressFeedback"
	button.add_child(feedback)

static func present(overlay: Control, panel: Control) -> void:
	var destination := panel.position
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * 0.94
	panel.position.y += 18.0
	overlay.modulate.a = 0.0
	var tween := panel.create_tween().set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.14)
	tween.tween_property(panel, "position", destination, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
