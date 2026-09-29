extends Control
# ============================================================
# 立绘演出 v1（会动的 · 看片版）：全屏播一段 .ogv，淡入 → 播完淡出
#   · 点任意处 = 跳过（手游习惯）
#   · 播不了（没有 codec / 文件缺失）也不会卡住：直接 finished
# 用法：
#   var cv = ArtClip.new(); host.add_child(cv)
#   cv.play(CharArt.clip("player"), host.size)
# ============================================================

signal done

var _vp: VideoStreamPlayer
var _bg: ColorRect

# max_sec > 0：只放这么久就收（大招 cut-in 用，别让 5 秒片压住整场战斗）
# dim：是否压一层暗底（立绘页要，战斗里不要——战斗的片本来就是满屏的）
func play(stream: VideoStream, area: Vector2, max_sec := 0.0, dim := true) -> void:
	if stream == null:
		done.emit()
		queue_free()
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = area
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.0 if dim else 0.0)
	_bg.size = area
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_vp = VideoStreamPlayer.new()
	_vp.stream = stream
	_vp.expand = true
	_vp.size = area
	_vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp.finished.connect(_on_finished)
	add_child(_vp)
	gui_input.connect(_on_tap)
	if dim:
		var tw := create_tween()
		tw.tween_property(_bg, "color:a", 0.55, 0.25)
	_vp.play()
	if max_sec > 0.0:
		# ⚠ 容错：节点还没进场景树时 get_tree() 是 null（探针在 _initialize 里就 play 会踩到）
		var tree := get_tree()
		if tree != null:
			await tree.create_timer(max_sec).timeout
			if is_inside_tree():
				_on_finished()

func _on_tap(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		_on_finished()

func _on_finished() -> void:
	if _vp != null and _vp.is_playing():
		_vp.stop()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	await tw.finished
	done.emit()
	queue_free()
