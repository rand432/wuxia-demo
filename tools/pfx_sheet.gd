extends Node
# pixelfx 效果预览/对比表：读 res://.pfx_job.json，铺成网格截图后退出
# 用法：写 job → godot --path . res://tools/pfx_sheet.tscn → 看 .shots/<shot>.png

func _ready() -> void:
	var path := "res://.pfx_job.json"
	if not FileAccess.file_exists(path):
		print("[pfx_sheet] 缺 .pfx_job.json")
		get_tree().quit()
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		print("[pfx_sheet] job 解析失败")
		get_tree().quit()
		return
	var job: Dictionary = parsed
	var cols := maxi(1, int(job.get("cols", 4)))
	var cw := float(job.get("cell_w", 168))
	var chh := float(job.get("cell_h", 150))
	var ox := float(job.get("origin_x", 40))
	var oy := float(job.get("origin_y", 200))
	var wait := float(job.get("wait", 0.12))
	var shot := str(job.get("shot", "pfx_sheet"))
	var dark := bool(job.get("dark", false))
	get_window().size = Vector2i(int(job.get("w", 720)), int(job.get("h", 1280)))
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.06) if dark else Color(0.93, 0.90, 0.82)
	bg.size = Vector2(720, 1280)
	add_child(bg)
	var P = load("res://addons/pixelfx/nodes/pixel_fx_2d.gd")
	var font: Font = load("res://fonts/ink.ttf")
	var list: Array = job.get("effects", [])
	for i in list.size():
		var e: Dictionary = list[i]
		var col := i % cols
		var row := i / cols
		var cx := ox + float(col) * cw + cw * 0.5
		var cy := oy + float(row) * chh + chh * 0.48
		var fx = P.new()
		fx.effect = str(e.get("id", ""))
		fx.position = Vector2(cx, cy)
		fx.scale = Vector2.ONE * float(e.get("scale", 1.0))
		fx.light = float(e.get("light", 1.0))
		fx.speed_scale = float(e.get("speed", 1.0))
		fx.seed = int(e.get("seed", -1))
		fx.flip = bool(e.get("flip", false))
		if str(e.get("pal", "")) != "":
			fx.palette_preset = str(e.get("pal", ""))
		fx.free_when_done = false
		add_child(fx)
		var lb := Label.new()
		lb.text = str(e.get("label", e.get("id", "")))
		lb.position = Vector2(cx - cw * 0.5, cy + chh * 0.30)
		lb.size = Vector2(cw, 22)
		lb.add_theme_font_override("font", font)
		lb.add_theme_font_size_override("font_size", 14)
		lb.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80) if dark else Color(0.36, 0.30, 0.22))
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(lb)
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.shots/%s.png" % shot)
	print("[pfx_sheet] %d 个 → .shots/%s.png" % [list.size(), shot])
	get_tree().quit()
