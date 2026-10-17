extends Control
# ============================================================
# qte_slash.gd —— v139：大招·滑动演出（引子 boss 那一场专用）
#   用户："boss 的滑动应该是在他身上滑动的时候出现剑光，跟水果忍者切水果那种一样，带音效。"
#   做法：
#     · 全屏压暗（boss 在后面被放大居中，位置由 duel_battle 摆）
#     · **按住拖动就开始切**：每滑过 26 像素甩出一段剑光 + 一声刀响（音效有 70ms 节流，别糊成一片）
#     · 松手时这一笔够长（≥90 像素）就记一"斩"：一记重震 + 计数
#     · 记满 need 斩 → 淡出 → 发 qte_done
#     · **没有跳过键**——这是演出，不是选择题
# ============================================================

signal qte_done

const UiKit := preload("res://shared/ui_kit.gd")
const FadeIn := preload("res://shared/fade_in.gd")
const Audio := preload("res://shared/audio.gd")

const TRAIL_STEP := 26.0     # 每滑这么多像素甩一段光
const STROKE_MIN := 90.0     # 一整笔至少这么长才算一"斩"
const SLASH_LIFE := 0.42
const SFX_GAP_MS := 70

var _need := 3
var _got := 0
var _down := false
var _from := Vector2.ZERO
var _drag_len := 0.0
var _slashes: Array = []
var _done := false
var _last_sfx := 0
var _hint: Label = null
var _count: Label = null
var _dark: ColorRect = null

func start(need: int) -> void:
	_need = maxi(1, need)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	_dark = ColorRect.new()
	_dark.color = Color(0.05, 0.04, 0.05, 0.42)
	_dark.size = size
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dark)
	var w: float = maxf(720.0, size.x)
	_count = UiKit.make_label(self, Vector2(0, 220), Vector2(w, 72), 46, UiKit.GOLD)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = UiKit.make_label(self, Vector2(0, 1036), Vector2(w, 72), 30, Color(0.95, 0.91, 0.82))
	UiKit.set_text(_hint, "按住，在他身上划")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_count()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)

func _refresh_count() -> void:
	if _count == null:
		return
	UiKit.set_text(_count, "斩　" + str(mini(_got, _need)) + " / " + str(_need))

func _gui_input(ev: InputEvent) -> void:
	if _done:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_down = true
			_from = mb.position
			_drag_len = 0.0
		else:
			if _down:
				_down = false
				if _drag_len >= STROKE_MIN:
					_stroke()
				_drag_len = 0.0
	elif ev is InputEventMouseMotion and _down:
		var mv := ev as InputEventMouseMotion
		var d := mv.position - _from
		var seg := d.length()
		if seg < 0.5:
			return
		_drag_len += seg
		if seg >= TRAIL_STEP:
			_spark(_from, mv.position)
			_from = mv.position

# 拖动时甩出的一段剑光（纯表现：光 + 刀响 + 轻震）
func _spark(a: Vector2, b: Vector2) -> void:
	_slashes.append({"a": a, "b": b, "life": SLASH_LIFE})
	var now := Time.get_ticks_msec()
	if now - _last_sfx >= SFX_GAP_MS:
		_last_sfx = now
		Audio.sfx("hit_slash", -15.0, randf_range(0.92, 1.18))
	FadeIn.buzz(16)
	queue_redraw()

# 一整笔划完，记一"斩"
func _stroke() -> void:
	if _done:
		return
	_got += 1
	Audio.sfx("hit_slash2", -9.0, randf_range(0.95, 1.1))
	FadeIn.buzz(70)
	_refresh_count()
	queue_redraw()
	if _got >= _need:
		_finish()

func _process(delta: float) -> void:
	if _slashes.is_empty():
		return
	var keep: Array = []
	for s_v in _slashes:
		var s: Dictionary = s_v
		s["life"] = float(s.get("life", 0.0)) - delta
		if float(s["life"]) > 0.0:
			keep.append(s)
	_slashes = keep
	queue_redraw()

func _draw() -> void:
	for s_v in _slashes:
		var s: Dictionary = s_v
		var a: Vector2 = s.get("a", Vector2.ZERO)
		var b: Vector2 = s.get("b", Vector2.ZERO)
		var k: float = clampf(float(s.get("life", 0.0)) / SLASH_LIFE, 0.0, 1.0)
		draw_line(a, b, Color(0.96, 0.92, 0.82, 0.20 * k), 26.0, true)
		draw_line(a, b, Color(1.0, 0.98, 0.92, 0.90 * k), 9.0, true)
		draw_line(a, b, Color(1, 1, 1, 0.95 * k), 3.0, true)
	for i in _need:
		var cx := 260.0 + float(i) * 100.0
		var lit := i < _got
		draw_circle(Vector2(cx, 348.0), 12.0, Color(0.95, 0.85, 0.50, 0.85 if lit else 0.22))

func _finish() -> void:
	if _done:
		return
	_done = true
	if _hint != null:
		UiKit.set_text(_hint, "成了。")
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	await tw.finished
	qte_done.emit()
