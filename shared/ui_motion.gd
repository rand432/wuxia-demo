extends RefCounted
# 共用的短促触感；不延迟按钮业务回调，空闲时不逐帧处理。
const Audio := preload("res://shared/audio.gd")
class PressFeedback extends Control:
	const CLICK_COLOR := Color(0.86, 0.67, 0.32)
	const REJECT_COLOR := Color(1.0, 0.43, 0.34)
	var _button: Button
	var _tween: Tween
	var _age := 1.0
	var _stroke := StyleBoxFlat.new()
	var _pulse_color := CLICK_COLOR
	var _rejected_at_frame := -1
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
		if _rejected_at_frame == Engine.get_process_frames():
			return
		Audio.sfx("ui_click", -13.0)
		if not _available(): return
		_flash(CLICK_COLOR)

	func reject() -> void:
		if not _available(): return
		_rejected_at_frame = Engine.get_process_frames()
		Audio.sfx("ui_back", -11.0, 0.9, 90)
		_flash(REJECT_COLOR)

	func _flash(color: Color) -> void:
		_pulse_color = color
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
		_stroke.border_color = Color(_pulse_color, 0.65 * (1.0 - p))
		draw_style_box(_stroke, Rect2(Vector2.ZERO, size).grow(2.0 + 9.0 * (1.0 - pow(1.0 - p, 3.0))))

static func bind_button(button: Button) -> void:
	if button.get_node_or_null("PressFeedback") != null: return
	var feedback := PressFeedback.new()
	feedback.name = "PressFeedback"
	button.add_child(feedback)

static func reject_button(button: Button) -> void:
	if not is_instance_valid(button): return
	var feedback := button.get_node_or_null("PressFeedback") as PressFeedback
	if feedback != null:
		feedback.reject()

static func present(overlay: Control, panel: Control) -> void:
	pop(panel)
	fade_in(overlay)

static func fade_in(overlay: Control) -> void:
	stop(overlay)
	overlay.modulate.a = 0.0
	overlay.scale = Vector2.ONE
	var tween := overlay.create_tween()
	overlay.set_meta("motion_entry", tween)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.14)

static func stop(control: Control) -> void:
	for key in ["motion_entry", "motion_idle"]:
		var old = control.get_meta(key) if control.has_meta(key) else null
		if old is Tween and old.is_valid(): old.kill()
		if control.has_meta(key): control.remove_meta(key)
	_restore_pointer(control)

static func _restore_pointer(control: Control) -> void:
	if control.has_meta("motion_pointer_filter"):
		control.mouse_filter = int(control.get_meta("motion_pointer_filter"))
		control.remove_meta("motion_pointer_filter")

static func pop(control: Control, card := false, delay := 0.0, origin := Vector2.INF, tilt := 0.0) -> Tween:
	stop(control)
	var destination: Vector2 = control.get_meta("motion_rest_position", control.position) if origin == Vector2.INF else origin
	control.set_meta("motion_rest_position", destination)
	control.pivot_offset = control.size * 0.5
	control.position = destination + Vector2(0, 46.0 if card else 18.0)
	control.scale = Vector2(0.80, 0.86) if card else Vector2(0.91, 0.94)
	control.rotation = tilt
	control.modulate.a = 0.0
	var tween := control.create_tween().set_parallel(true)
	control.set_meta("motion_entry", tween)
	if card and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		control.set_meta("motion_pointer_filter", control.mouse_filter)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tween.tween_callback(_restore_pointer.bind(control)).set_delay(delay + 0.075)
	tween.tween_property(control, "position", destination, 0.31).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "rotation", 0.0, 0.30).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.12).set_delay(delay)
	tween.tween_property(control, "scale", Vector2(1.055, 1.025) if card else Vector2(1.025, 1.012), 0.18).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2(0.99, 0.985), 0.085).set_delay(delay + 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.095).set_delay(delay + 0.265).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween

static func breathe(control: Control) -> void:
	var entry = control.get_meta("motion_entry") if control.has_meta("motion_entry") else null
	var begin := _begin_breathe.bind(control)
	if entry is Tween and entry.is_running():
		if not entry.finished.is_connected(begin): entry.finished.connect(begin, CONNECT_ONE_SHOT)
	else:
		_begin_breathe(control)

static func _begin_breathe(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree() or not control.is_visible_in_tree(): return
	var old = control.get_meta("motion_idle") if control.has_meta("motion_idle") else null
	if old is Tween and old.is_valid(): old.kill()
	var tween := control.create_tween().set_loops()
	control.set_meta("motion_idle", tween)
	tween.tween_property(control, "scale", Vector2.ONE * 1.007, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
