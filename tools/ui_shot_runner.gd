extends Control
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")
var scene_path := ""
var out_path := ""
var action := "still"
var target_w := 450
var target_h := 800
var emulate_window := false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="): scene_path = arg.get_slice("=", 1)
		if arg.begins_with("--out="): out_path = arg.get_slice("=", 1)
		if arg.begins_with("--action="): action = arg.get_slice("=", 1)
		if arg.begins_with("--emulate="): emulate_window = arg.get_slice("=", 1) == "1"
		if arg.begins_with("--size="):
			var w := arg.get_slice("=", 1).split("x")
			if w.size() == 2:
				target_w = int(w[0]); target_h = int(w[1])
	LS.ensure_loaded()
	LS.current_level = 6
	GS.ensure_loaded()
	if scene_path.is_empty() or out_path.is_empty():
		push_error("缺少 --scene 或 --out")
		get_tree().quit(2)
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(target_w, target_h) if emulate_window else Vector2i(720, 1280)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	var node = null
	if scene_path == "result":
		node = load("res://kushou/result_view.gd").new()
	else:
		node = load(scene_path).instantiate()
	var holder := Control.new()
	holder.size = Vector2(720, 1280)
	if emulate_window:
		var s := minf(float(target_w) / 720.0, float(target_h) / 1280.0)
		holder.scale = Vector2(s, s)
		holder.position = Vector2((target_w - 720.0 * s) * 0.5, (target_h - 1280.0 * s) * 0.5)
	vp.add_child(holder)
	holder.add_child(node)
	if node is Control:
		(node as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if scene_path.find("forge_sheet") >= 0 and node.has_method("open"):
		node.open("weapon")
	if node.has_method("_show_god_pick"):
		node._draw_charge = 3
		node._trea_charge = 3
		node._crystal = 999
	if node.has_method("present"):
		node.present({"win": true, "run_time": 228, "wave": 18, "max_wave": 18, "kills": 688,
			"wen": 1234, "crystal": 56, "bonds": 3, "bonds_done": 1})
	if node.has_method("_show_draw") and node.get("_tut") != null:
		var tut = node.get("_tut")
		tut.cancel()
		tut.queue_free()
		node.set("_tut", null)
		node._tutorial_pause(false)
	await _wait(600)
	if action == "float":
		if node.get("_core") != null:
			for i in 20:
				node._core._spawn_foe("normal", 1.0, 1.0)
			var fc = node._core.foes[0]
			node._core._push_float(float(fc["x"]), float(fc["y"]) - 44.0, "格挡", Color(0.72, 0.82, 0.94))
			await _wait(120)
			await _capture(vp, out_path.get_basename() + "_mid.png")
			await _wait(200)
			await _capture(vp, out_path.get_basename() + "_end.png")
		if node.get("_core") != null:
			pass
	elif action != "still":
		_trigger(node)
		await _wait(120)
		await _capture(vp, out_path.get_basename() + "_mid.png")
		await _wait(600)
		await _capture(vp, out_path.get_basename() + "_end.png")
	else:
		await _capture(vp, out_path)
	get_tree().quit(0)

func _trigger(node: Node) -> void:
	if not node.has_method("_show_draw") and not node.has_method("_open_trea"):
		return
	match action:
		"draw": node._show_draw(true)
		"treasure": node._open_trea()
		"god": node._show_god_pick()
		"curio": node._show_curio_detail()
		_: pass

func _wait(ms: int) -> void:
	await get_tree().create_timer(float(ms) / 1000.0).timeout

func _capture(vp: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var scaled := img
	if not emulate_window:
		if img.get_width() != 720:
			img.resize(720, 1280, Image.INTERPOLATE_BILINEAR)
		scaled = _fit(img, target_w, target_h)
	scaled.save_png(path)
	print("[SHOT] " + path + " " + str(scaled.get_width()) + "x" + str(scaled.get_height()) + " from " + str(img.get_width()) + "x" + str(img.get_height()))

func _fit(src: Image, w: int, h: int) -> Image:
	var scale := minf(float(w) / 720.0, float(h) / 1280.0)
	var cw := maxi(1, int(round(720.0 * scale)))
	var ch := maxi(1, int(round(1280.0 * scale)))
	var resized := src.duplicate()
	resized.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
	if cw == w and ch == h:
		return resized
	var canvas := Image.create(w, h, false, src.get_format())
	canvas.fill(Color(0, 0, 0, 1))
	canvas.blit_rect(resized, Rect2i(0, 0, cw, ch), Vector2i((w - cw) / 2, (h - ch) / 2))
	return canvas
