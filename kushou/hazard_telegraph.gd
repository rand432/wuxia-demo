extends Node2D

const BEAM_BACK := 40.0
const RING_PADDING := 26.0
const BOLT_ABOVE := 260.0
const BOLT_BELOW := 60.0
const SECTOR_FLASH_TIME := 0.24

var core: Control
var _had_warnings := false
var _ring_flashes: Array[Dictionary] = []
var _sector_flashes: Array[Dictionary] = []

func flash_ring(center: Vector2, radius: float) -> void:
	_ring_flashes.append({"center": center, "radius": radius, "elapsed": 0.0})
	queue_redraw()

func flash_sector(center: Vector2, direction: Vector2, radius: float, spread: float) -> void:
	if _sector_flashes.size() >= 4:
		_sector_flashes.pop_front()
	_sector_flashes.append({"center": center, "angle": direction.angle(), "radius": radius,
		"half": spread * 0.5, "elapsed": 0.0})
	queue_redraw()

func _process(delta: float) -> void:
	var has_warnings: bool = is_instance_valid(core) and (not core._delayed.is_empty()
		or not _ring_flashes.is_empty() or not _sector_flashes.is_empty())
	if has_warnings or _had_warnings:
		queue_redraw()
	_had_warnings = has_warnings
	for i in range(_ring_flashes.size() - 1, -1, -1):
		_ring_flashes[i]["elapsed"] += delta
		if float(_ring_flashes[i]["elapsed"]) >= 0.24:
			_ring_flashes.remove_at(i)
	for i in range(_sector_flashes.size() - 1, -1, -1):
		_sector_flashes[i]["elapsed"] += delta
		if float(_sector_flashes[i]["elapsed"]) >= SECTOR_FLASH_TIME:
			_sector_flashes.remove_at(i)

func _draw() -> void:
	if is_instance_valid(core):
		paint(self, core._delayed, core._t)
	for ring in _ring_flashes:
		var progress := float(ring["elapsed"]) / 0.24
		var center: Vector2 = ring["center"]
		var radius: float = ring["radius"]
		draw_arc(center, radius, 0, TAU, 56, Color(1.0, 0.48, 0.17, 0.8 * (1.0 - progress)), 4.0, true)
		draw_arc(center, radius * lerpf(0.65, 1.0, progress), 0, TAU, 56, Color(1.0, 0.77, 0.37, 0.65 * (1.0 - progress)), 2.0, true)
	for sweep in _sector_flashes:
		var progress := float(sweep["elapsed"]) / SECTOR_FLASH_TIME
		var alpha := 1.0 - progress
		var center: Vector2 = sweep["center"]
		var from := float(sweep["angle"]) - float(sweep["half"])
		var to := float(sweep["angle"]) + float(sweep["half"])
		var radius := float(sweep["radius"]) * lerpf(0.73, 0.98, ease(progress, 0.55))
		draw_arc(center, radius - 7.0, from, to, 35, Color(0.58, 0.13, 0.05, alpha * 0.78), 13.0 * alpha + 2.0, true)
		draw_arc(center, radius, from, to, 35, Color(1.0, 0.40, 0.11, alpha * 0.92), 6.0 * alpha + 1.0, true)
		draw_arc(center, radius, from + 0.10, to - 0.08, 35, Color(1.0, 0.82, 0.44, alpha), 2.8 * alpha + 0.5, true)

static func paint(canvas: CanvasItem, hazards: Array, clock: float) -> void:
	for hazard: Dictionary in hazards:
		var landed := bool(hazard.get("landed", false))
		var progress := clampf(float(hazard["t"]) / float(hazard["warn"]), 0.0, 1.0)
		var late := smoothstep(0.76, 1.0, progress)
		var edge := Color(0.95, 0.37, 0.23, 0.57 + progress * 0.40).lerp(Color(1.0, 0.74, 0.42), late * 0.55)
		var fill := Color(0.67, 0.15, 0.08, 0.055 + 0.16 * progress)
		var center := Vector2(hazard["x"], hazard["y"])
		var radius := float(hazard["r"])
		var shape := str(hazard["shape"])
		match shape:
			"beam":
				var dir := Vector2(hazard["dir"]).normalized()
				var side := dir.orthogonal() * radius
				var near := center - dir * BEAM_BACK
				var length := float(hazard["len"]) + BEAM_BACK
				var far := near + dir * length
				var reach := near.lerp(far, progress)
				_outline(canvas, [near + side, far + side, far - side, near - side], fill, edge)
				if progress > 0.0:
					canvas.draw_colored_polygon(PackedVector2Array([near + side, reach + side, reach - side, near - side]), Color(edge, 0.13))
			"sector":
				var angle := Vector2(hazard["dir"]).angle()
				var half := float(hazard["spread"]) * 0.5
				var vertices := PackedVector2Array([center])
				for i in 25:
					var a := lerpf(angle - half, angle + half, float(i) / 24.0)
					vertices.append(center + Vector2.from_angle(a) * radius)
				canvas.draw_colored_polygon(vertices, fill)
				vertices.append(center)
				canvas.draw_polyline(vertices, edge, 2.3, true)
				if progress > 0.0:
					canvas.draw_arc(center, radius * progress, angle - half, angle + half, 24, Color(edge, 0.52), 2.0, true)
			"bolt":
				_outline(canvas, [center + Vector2(-radius, -BOLT_ABOVE), center + Vector2(radius, -BOLT_ABOVE),
					center + Vector2(radius, BOLT_BELOW), center + Vector2(-radius, BOLT_BELOW)], fill, edge)
				var y := lerpf(-BOLT_ABOVE, BOLT_BELOW, progress)
				canvas.draw_line(center + Vector2(-radius, y), center + Vector2(radius, y), edge, 2.0, true)
			_:
				if shape == "ring":
					radius += RING_PADDING
				if landed:
					canvas.draw_circle(center, radius, Color(0.68, 0.24, 0.13, 0.15), true, -1.0, true)
					canvas.draw_arc(center, radius, 0, TAU, 48, Color(0.81, 0.49, 0.31, 0.65), 2.0, true)
					canvas.draw_arc(center, radius * (0.71 + sin(clock * 3.8) * 0.11), 0, TAU, 36, Color(0.88, 0.51, 0.32, 0.22), 1.8, true)
				else:
					canvas.draw_circle(center, radius, fill, true, -1.0, true)
					canvas.draw_arc(center, radius, 0, TAU, 48, edge, 2.0 + late * 1.4, true)
					if progress > 0.0:
						canvas.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(1.0, 0.76, 0.46, 0.78), 3.0, true)
					if shape == "ring" and progress > 0.0:
						canvas.draw_arc(center, radius * progress, 0, TAU, 36, Color(edge, 0.36 + late * 0.26), 2.0, true)

static func _outline(canvas: CanvasItem, edges: Array[Vector2], fill: Color, edge: Color) -> void:
	var points := PackedVector2Array(edges)
	canvas.draw_colored_polygon(points, fill)
	points.append(points[0])
	canvas.draw_polyline(points, edge, 2.3, true)
