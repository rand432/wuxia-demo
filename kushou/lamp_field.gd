extends Control

const GLOW := Color(0.97, 0.73, 0.41)
const ANIMATION_INTERVAL := 1.0 / 24.0
const PULL_TRACE_LIMIT := 10
const PULL_TRACE_DURATION := 0.26

var center := Vector2.ZERO
var radius := 0.0
var _angle := 0.0
var _elapsed := 0.0
var _pull_traces: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	hide()
	set_process(false)

func update_field(at: Vector2, extent: float) -> void:
	if center == at and radius == extent:
		return
	center = at
	radius = extent
	visible = radius > 0.0
	set_process(visible)
	if not visible:
		_pull_traces.clear()
	queue_redraw()

func show_pull(origin: Vector2, destination: Vector2) -> void:
	if not visible:
		return
	if _pull_traces.size() >= PULL_TRACE_LIMIT:
		_pull_traces.pop_front()
	_pull_traces.append({"origin": origin, "destination": destination, "age": 0.0})
	queue_redraw()

func _process(delta: float) -> void:
	for i in range(_pull_traces.size() - 1, -1, -1):
		_pull_traces[i]["age"] += delta
		if _pull_traces[i]["age"] >= PULL_TRACE_DURATION:
			_pull_traces.remove_at(i)
	_elapsed += delta
	if _elapsed >= ANIMATION_INTERVAL:
		_angle = fposmod(_angle + _elapsed * 0.34, TAU)
		_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	if radius <= 0.0:
		return
	var segments := clampi(ceili(radius * 0.31), 48, 100)
	draw_circle(center, radius, Color(GLOW, 0.042), true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, segments, Color(0.18, 0.12, 0.08, 0.28), 4.0, true)
	draw_arc(center, radius, 0.0, TAU, segments, Color(GLOW, 0.48), 1.6, true)
	for i in 4:
		var angle := _angle + i * TAU / 4.0
		draw_arc(center, radius, angle - 0.15, angle + 0.15, 9, Color(GLOW, 0.86), 2.4, true)
		var at := center + Vector2.from_angle(angle) * (radius - 7.0)
		draw_circle(at, 2.0, Color(1.0, 0.88, 0.64, 0.75), true, -1.0, true)
	for trace in _pull_traces:
		_draw_pull(trace)

func _draw_pull(trace: Dictionary) -> void:
	var origin: Vector2 = trace["origin"]
	var destination: Vector2 = trace["destination"]
	var progress := float(trace["age"]) / PULL_TRACE_DURATION
	var fade := 1.0 - progress
	var travel := destination - origin
	if progress > 0.0 and travel.length_squared() > 36.0:
		var normal := travel.normalized().orthogonal() * minf(19.0, travel.length() * 0.23)
		var tip := smoothstep(0.0, 0.68, progress)
		var tail := smoothstep(0.12, 1.0, progress) * 0.97
		for side: float in [-1.0, 1.0]:
			var points := PackedVector2Array()
			for i in range(8):
				var t := lerpf(tail, tip, float(i) / 7.0)
				points.append(origin.lerp(destination, t) + normal * (side * sin(t * PI)))
			draw_polyline(points, Color(GLOW, fade * 0.9), 2.2, true)
	var arrival := smoothstep(0.30, 0.68, progress) * fade
	if arrival > 0.01:
		draw_arc(destination, 6.0 + progress * 12.0, 0.0, TAU, 16, Color(GLOW, arrival), 2.1, true)
