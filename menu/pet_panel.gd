extends Control
# ============================================================
# pet_panel.gd —— 宠物面板 v4（优化批㊿z9：升星 · 洗灵丹 · 四档血脉）
# v4 变更：
#   ①右列四颗按钮：升星（吃同名份数，账本 pet_star_*）· 洗灵丹（资质 +2，每阶限 1 颗）
#     · 喂养灵丹 · 让它随行；面板高度 900→940 给新行腾位。
#   ②名字后面挂星级（★★★★☆）——星级同时放大"主加成 + 血脉"（×(1+0.2×星)）。
#   ③「随行加成」那行改成**直接念账本**算出来的 fx：以前写死"护主…气血%"，
#     青隼（主加速度）会被报成 0。
#   ④资质档位跟新量程走（入册 30~60）；血脉分凡/紫/金/绝四档，名字里带档位。
# v3 变更：
#   ①五阶显示（第 N/5 段）+「资质」行；②「血脉」区：每阶开 1 格（至多 5）；
#     契合血脉 ×1.5（预览里明写）；来源提示：密柜偶尔掉、货栈有金色高价限量；
#   ③喂养/随行/画（狐、隼）照旧。
# 接口不变：open() / close() / 信号 closed。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const DataPets := preload("res://shared/data_pets.gd")

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const GREEN := Color(0.30, 0.52, 0.32)
const GOLD := Color(0.72, 0.58, 0.22)

const PANEL_W := 640.0
const PANEL_H := 1070.0   # v61：940 → 1070（护主效果给两行大字、四颗钮改成 2×2 大钮）

signal closed

# v93（用户："宠物界面我也想有待机啊 卖萌 睡觉等等动作" / "点击它提示 被你摸摸头 然后会叫的音效"）：
#   ① 从 Node2D 换成 **Control**——Node2D 收不到点击，摸头得有 gui_input；
#   ② 三套帧序列（智谱图生视频 → tools/bake_walk.mjs）：pet_idle / pet_cute / pet_sleep；
#   ③ 摸头：切"卖萌"动作 + 铃铛声 + 叫声 + 飘一行"被你摸摸头～"；长时间没人理 → 自己睡。
class PetArt extends Control:
	const PArt := preload("res://shared/char_art.gd")   # v92：Q版宠物图（白狐/青隼）
	const Audio := preload("res://shared/audio.gd")
	var t := 0.0
	var stage := 0
	var has_pet := true
	var kind := "fox"
	var act := "idle"        # idle / cute / sleep
	var act_t := 0.0         # 当前动作还剩多久（<=0 就回 idle）
	var quiet := 0.0         # 多久没被摸（超过 IDLE_SLEEP 就睡）
	var pets := 0            # 被摸过几次
	var say := ""            # 飘字
	var say_t := 0.0
	const SLEEP_AFTER := 24.0

	func _ready() -> void:
		size = Vector2(584.0, 170.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		gui_input.connect(_on_gui)

	func _on_gui(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed 				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			pet_head()

	# 摸头（面板里点它）
	func pet_head() -> void:
		if not has_pet:
			return
		pets += 1
		quiet = 0.0
		act = "cute"
		act_t = 2.6
		say = "被你摸摸头～" if pets % 3 != 0 else "它把头往你手心里拱了拱～"
		say_t = 2.2
		Audio.sfx("bell", -5.0, 1.12)               # 脖子上的铃铛
		Audio.sfx("pet_chirp" + ("1" if pets % 2 == 1 else "2"), -9.0, 1.15)   # 叫一声
		queue_redraw()

	func _process(delta: float) -> void:
		t += delta
		quiet += delta
		if act_t > 0.0:
			act_t -= delta
			if act_t <= 0.0:
				act = "idle"
		if say_t > 0.0:
			say_t -= delta
		# 没人理它 → 自己蜷起来睡（一被摸就醒）
		if act == "idle" and quiet > SLEEP_AFTER:
			act = "sleep"
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 584, 170), Color(0.93, 0.90, 0.83, 0.85))
		draw_colored_polygon(PackedVector2Array([Vector2(-10, 150), Vector2(140, 62), Vector2(330, 150)]), Color(0.16, 0.14, 0.13, 0.30))
		draw_colored_polygon(PackedVector2Array([Vector2(280, 150), Vector2(450, 46), Vector2(596, 150)]), Color(0.13, 0.11, 0.11, 0.40))
		draw_line(Vector2(0, 150), Vector2(584, 150), Color(0.30, 0.24, 0.18, 0.50), 2.0)
		if not has_pet:
			return
		# v92（用户："宠物面板也没有变化"）：**面板里的狐/隼也换成 Q版图**——
		#   跟路上那只走的是同一个取图口（CharArt.pet），一处换图两处都变。
		#   ⚠ 顺序：先给 Rect2 定尺寸再画，不套任何 draw_set_transform（v91 白方块的教训）。
		# v93：**帧序列优先**（待机/卖萌/睡觉三套），没有帧序列才退回单张静图
		var anim := "pet_" + ("idle" if kind == "fox" else "hawk_idle")
		if act == "cute":
			anim = "pet_cute"
		elif act == "sleep":
			anim = "pet_sleep"
		if kind != "fox":
			anim = "pet_" + act if act != "idle" else "pet_hawk_idle"
		var sheet := PArt.sheet(anim)
		var nfr := PArt.sheet_count(anim)
		if sheet != null and nfr > 0:
			var aw := PArt.sheet_aspect(anim)
			var fh := float(sheet.get_height())
			var fw := fh * aw
			# 待机/卖萌/睡觉 各自不同的播放速度（睡觉最慢）
			var spd := 9.0
			if act == "sleep":
				spd = 3.0
			elif act == "cute":
				spd = 12.0
			var fi := int(floor(t * spd)) % nfr
			var dh := 138.0 * (1.0 + 0.06 * float(stage))
			var dw := dh * aw
			draw_texture_rect_region(sheet, Rect2(292.0 - dw * 0.5, 150.0 - dh, dw, dh),
				Rect2(float(fi) * fw, 0.0, fw, fh), Color(1, 1, 1, 1))
			if act == "sleep":
				var zz := 0.8 + 0.2 * sin(t * 1.6)
				draw_string(ThemeDB.fallback_font, Vector2(360.0, 56.0 - sin(t * 1.6) * 3.0), "Zzz…",
					HORIZONTAL_ALIGNMENT_LEFT, 120.0, 20, Color(0.35, 0.32, 0.30, 0.55 * zz))
			if say_t > 0.0 and say != "":
				# 飘字画在**画框里面**（上方 y<0 会被同层的其它标签盖住）
				var a := clampf(say_t / 0.5, 0.0, 1.0)
				var yy: float = 46.0 - (2.2 - say_t) * 9.0
				draw_string(ThemeDB.fallback_font, Vector2(292.0 - 150.0, maxf(20.0, yy)),
					say, HORIZONTAL_ALIGNMENT_CENTER, 300.0, 21, Color(0.72, 0.16, 0.12, a))
			return
		var qtex := PArt.pet(kind)
		if qtex != null:
			var qh := 138.0 * (1.0 + 0.06 * float(stage))
			var qw := qh * float(qtex.get_width()) / maxf(float(qtex.get_height()), 1.0)
			var qbob := sin(t * 2.6) * 2.5
			var qlift := 26.0 if kind == "hawk" else 0.0
			draw_texture_rect(qtex, Rect2(292.0 - qw * 0.5, 150.0 - qh - qlift - qbob, qw, qh), false)
			return
		if kind == "hawk":
			_draw_hawk()
		else:
			_draw_fox()

	func _draw_fox() -> void:
		var cx := 292.0
		var cy := 118.0
		var s := 1.0 + 0.08 * float(stage)
		var bob := sin(t * 2.6) * 2.5
		var body := Color(0.965, 0.950, 0.915, 0.98)
		var inkc := Color(0.30, 0.27, 0.28, 0.95)
		for i in stage:
			var rr := 52.0 + float(i) * 14.0
			draw_arc(Vector2(cx, cy - 26.0), rr, 0.0, TAU, 40, Color(0.72, 0.58, 0.22, 0.10 + 0.05 * sin(t * 2.0 + float(i))), 2.0)
		draw_circle(Vector2(cx - 18.0 * s, cy - 12.0 * s + bob * 0.4), 20.0 * s, body)
		draw_circle(Vector2(cx + 22.0 * s, cy - 32.0 * s + bob), 15.0 * s, body)
		draw_colored_polygon(PackedVector2Array([Vector2(cx + 10.0 * s, cy - 44.0 * s + bob), Vector2(cx + 16.0 * s, cy - 62.0 * s + bob), Vector2(cx + 24.0 * s, cy - 42.0 * s + bob)]), body)
		draw_colored_polygon(PackedVector2Array([Vector2(cx + 26.0 * s, cy - 42.0 * s + bob), Vector2(cx + 34.0 * s, cy - 58.0 * s + bob), Vector2(cx + 40.0 * s, cy - 38.0 * s + bob)]), body)
		var wag := sin(t * 5.0) * 0.35
		draw_arc(Vector2(cx - 40.0 * s, cy - 22.0 * s + bob * 0.5), 20.0 * s, PI * 0.7 + wag, PI * 1.6 + wag, 14, body, 9.0 * s)
		draw_circle(Vector2(cx + 27.0 * s, cy - 34.0 * s + bob), 2.2 * s, inkc)
		draw_circle(Vector2(cx + 36.0 * s, cy - 29.0 * s + bob), 1.8 * s, inkc)
		draw_circle(Vector2(cx + 24.0 * s, cy - 34.0 * s + bob), 1.6 * s, Color(0.98, 0.90, 0.86, 0.95))
		draw_line(Vector2(cx - 26.0 * s, cy + 6.0 * s), Vector2(cx - 26.0 * s, cy + 14.0 * s), inkc, 2.4)
		draw_line(Vector2(cx + 4.0 * s, cy + 6.0 * s), Vector2(cx + 4.0 * s, cy + 14.0 * s), inkc, 2.4)
		for i2 in stage:
			var ph := fmod(t * 0.8 + float(i2) * 0.31, 1.0)
			draw_circle(Vector2(cx + 70.0 + sin(ph * 5.0 + float(i2)) * 24.0, cy - 40.0 - ph * 40.0), 3.0 * (1.0 - ph), Color(0.95, 0.84, 0.45, 0.7 * (1.0 - ph)))

	func _draw_hawk() -> void:
		var cx := 292.0
		var cy := 96.0
		var s := 1.0 + 0.06 * float(stage)
		var bob := sin(t * 2.2) * 2.0
		var body := Color(0.55, 0.60, 0.68)
		var wing := Color(0.42, 0.47, 0.56)
		var head_c := Color(0.63, 0.68, 0.76)
		var inkc := Color(0.30, 0.27, 0.28, 0.95)
		# 栖枝
		draw_line(Vector2(cx - 96.0, 150.0), Vector2(cx + 96.0, 150.0), Color(0.45, 0.31, 0.20, 0.90), 7.0)
		draw_line(Vector2(cx - 96.0, 155.0), Vector2(cx + 96.0, 155.0), Color(0.45, 0.31, 0.20, 0.30), 3.0)
		# 阶环（金）
		for i in stage:
			var rr := 58.0 + float(i) * 16.0
			draw_arc(Vector2(cx, cy), rr, 0.0, TAU, 40, Color(0.72, 0.58, 0.22, 0.10 + 0.05 * sin(t * 2.0 + float(i))), 2.0)
		# 腿爪
		draw_line(Vector2(cx - 8.0 * s, cy + 34.0), Vector2(cx - 8.0 * s, 148.0), Color(0.70, 0.55, 0.30), 3.0)
		draw_line(Vector2(cx + 8.0 * s, cy + 34.0), Vector2(cx + 8.0 * s, 148.0), Color(0.70, 0.55, 0.30), 3.0)
		draw_line(Vector2(cx - 14.0 * s, 148.0), Vector2(cx - 2.0 * s, 148.0), Color(0.70, 0.55, 0.30), 2.4)
		draw_line(Vector2(cx + 2.0 * s, 148.0), Vector2(cx + 14.0 * s, 148.0), Color(0.70, 0.55, 0.30), 2.4)
		# 尾羽
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 14.0 * s, cy + 6.0 + bob * 0.3),
			Vector2(cx - 54.0 * s, cy + 46.0 + bob * 0.3),
			Vector2(cx - 46.0 * s, cy + 52.0 + bob * 0.3),
			Vector2(cx - 6.0 * s, cy + 14.0 + bob * 0.3),
		]), Color(0.36, 0.41, 0.50))
		# 身
		draw_circle(Vector2(cx, cy + bob * 0.3), 24.0 * s, body)
		draw_circle(Vector2(cx + 9.0 * s, cy + 6.0 + bob * 0.3), 13.0 * s, Color(0.80, 0.80, 0.78, 0.85))
		# 折翅
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 6.0 * s, cy - 18.0 * s + bob * 0.5),
			Vector2(cx - 34.0 * s, cy + 16.0 * s + bob * 0.5),
			Vector2(cx - 24.0 * s, cy + 26.0 * s + bob * 0.5),
			Vector2(cx + 6.0 * s, cy - 2.0 * s + bob * 0.5),
		]), wing)
		draw_line(Vector2(cx - 26.0 * s, cy + 14.0 * s + bob * 0.5), Vector2(cx - 8.0 * s, cy - 6.0 * s + bob * 0.5), Color(0.30, 0.34, 0.42, 0.7), 2.0)
		# 头 / 喙 / 眼
		draw_circle(Vector2(cx + 16.0 * s, cy - 34.0 * s + bob), 13.0 * s, head_c)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx + 27.0 * s, cy - 38.0 * s + bob),
			Vector2(cx + 41.0 * s, cy - 32.0 * s + bob),
			Vector2(cx + 27.0 * s, cy - 28.0 * s + bob),
		]), Color(0.85, 0.68, 0.30))
		draw_circle(Vector2(cx + 20.0 * s, cy - 36.0 * s + bob), 2.2 * s, inkc)
		draw_circle(Vector2(cx + 19.0 * s, cy - 37.0 * s + bob), 0.8 * s, Color(0.98, 0.96, 0.90, 0.9))
		# 尘光
		for i2 in stage:
			var ph := fmod(t * 0.8 + float(i2) * 0.31, 1.0)
			draw_circle(Vector2(cx + 60.0 + sin(ph * 5.0 + float(i2)) * 22.0, cy - 30.0 - ph * 38.0), 3.0 * (1.0 - ph), Color(0.95, 0.84, 0.45, 0.7 * (1.0 - ph)))

var _panel: Panel
var _art: PetArt
var _chips: Array = []
var _stage_lb: Label
var _name_lb: Label
var _apt_lb: Label
var _pass_lb: Label
var _fx_lb: Label
var _xp_bg: ColorRect
var _xp_fill: ColorRect
var _xp_lb: Label
var _feed_btn: Button
var _toggle_btn: Button
var _star_btn: Button
var _apt_btn: Button
var _bl_head: Label
var _bl_slots: Label
var _bl_pick: Label
var _bl_pre: Label
var _bl_prev: Button
var _bl_next: Button
var _bl_fuse: Button
var _bl_sel := 0
var _msg_lb: Label
var _hint_lb: Label
var _tick := 0.0

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	refresh()
	visible = get_parent() == get_tree().root

func _process(delta: float) -> void:
	if not visible:
		return
	_tick += delta
	if _tick < 0.5:
		return
	_tick = 0.0
	refresh()

func _build() -> void:
	var vp := get_viewport_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = vp
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = Panel.new()
	_panel.position = Vector2((vp.x - PANEL_W) * 0.5, (vp.y - PANEL_H) * 0.5)
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.98)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	psb.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", psb)
	add_child(_panel)

	var title := _label("宠　物", 30, INK)
	title.position = Vector2(28, 18)
	title.size = Vector2(200, 44)
	_panel.add_child(title)

	_stage_lb = _label("", 18, SEAL)
	_stage_lb.position = Vector2(240, 22)
	_stage_lb.size = Vector2(372, 36)
	_stage_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_stage_lb)

	# ---- 名册一排（拿到了才亮） ----
	_chips = []
	var pet_ids: Array = DataPets.PETS.keys()
	var ci := 0
	for pid_v in pet_ids:
		var pid := str(pid_v)
		var btn := Button.new()
		btn.text = DataPets.name_of(pid)
		btn.position = Vector2(28.0 + float(ci) * 142.0, 68.0)
		btn.size = Vector2(132, 44)
		btn.add_theme_font_size_override("font_size", 16)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_pick.bind(pid))
		_panel.add_child(btn)
		_chips.append({"pid": pid, "btn": btn})
		ci += 1

	_art = PetArt.new()
	_art.position = Vector2(28, 120)
	_panel.add_child(_art)

	_name_lb = _label("", 26, INK)
	_name_lb.position = Vector2(28, 296)
	_name_lb.size = Vector2(400, 34)
	_panel.add_child(_name_lb)

	# v61（用户："宠物界面显示的护主效果也超出 字还小 按钮也小"）：
	#   中段整块重排——原来这一列是 名字/资质/随行/护主(14 号·1 行·**还带省略号**)/经验条，
	#   右边竖着挤四颗 150×30 的小钮。现在：
	#     · 资质 16→17、随行 15→**16 给两行**
	#     · **护主效果 14→17、给两行**（去掉"只许一行 + 省略号"，长效果不再被截）
	#     · 经验条挪到它下面、拉满整幅宽
	#     · 四颗钮改成 **2×2 大钮（284×52、18 号字）**，排在经验条下面
	#   面板跟着长高（PANEL_H 940 → 1070），下面血脉区整体下移，
	#   ［关闭］也往下让（984 起，仍旧贴底）。
	_apt_lb = _label("", 17, Color(INK.r, INK.g, INK.b, 0.72))
	_apt_lb.position = Vector2(28, 332)
	_apt_lb.size = Vector2(584, 26)
	_apt_lb.clip_text = true          # 保险：真长出框也只裁字，不顶到隔壁
	_panel.add_child(_apt_lb)

	_pass_lb = _label("", 16, Color(INK.r, INK.g, INK.b, 0.72))
	_pass_lb.position = Vector2(28, 360)
	_pass_lb.size = Vector2(584, 44)
	_pass_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_pass_lb)

	_fx_lb = _label("", 17, GOLD)
	_fx_lb.position = Vector2(28, 408)
	_fx_lb.size = Vector2(584, 54)
	_fx_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_fx_lb)

	_xp_bg = ColorRect.new()
	_xp_bg.position = Vector2(28, 468)
	_xp_bg.size = Vector2(584, 20)
	_xp_bg.color = Color(0.10, 0.09, 0.10, 0.18)
	_xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_xp_bg)
	_xp_fill = ColorRect.new()
	_xp_fill.position = Vector2(28, 468)
	_xp_fill.size = Vector2(0, 20)
	_xp_fill.color = GOLD
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_xp_fill)
	_xp_lb = _label("", 13, Color(0.96, 0.94, 0.90))
	_xp_lb.position = Vector2(28, 468)
	_xp_lb.size = Vector2(584, 20)
	_xp_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(_xp_lb)

	# ㊿z9：右列四颗按钮 → v61：改成经验条下面的 **2×2 大钮**
	_star_btn = Button.new()
	_star_btn.text = "升星"
	_star_btn.position = Vector2(28, 496)
	_star_btn.size = Vector2(284, 52)
	_star_btn.add_theme_font_size_override("font_size", 18)
	_star_btn.focus_mode = Control.FOCUS_NONE
	_star_btn.pressed.connect(_on_star)
	_style_seal(_star_btn)
	_panel.add_child(_star_btn)

	_apt_btn = Button.new()
	_apt_btn.text = "服洗灵丹"
	_apt_btn.position = Vector2(320, 496)
	_apt_btn.size = Vector2(284, 52)
	_apt_btn.add_theme_font_size_override("font_size", 18)
	_apt_btn.focus_mode = Control.FOCUS_NONE
	_apt_btn.pressed.connect(_on_apt)
	_style_dark(_apt_btn)
	_panel.add_child(_apt_btn)

	_feed_btn = Button.new()
	_feed_btn.text = "喂养灵丹"
	_feed_btn.position = Vector2(28, 556)
	_feed_btn.size = Vector2(284, 52)
	_feed_btn.add_theme_font_size_override("font_size", 18)
	_feed_btn.focus_mode = Control.FOCUS_NONE
	_feed_btn.pressed.connect(_on_feed)
	_style_seal(_feed_btn)
	_panel.add_child(_feed_btn)

	_toggle_btn = Button.new()
	_toggle_btn.text = "让它随行"
	_toggle_btn.position = Vector2(320, 556)
	_toggle_btn.size = Vector2(284, 52)
	_toggle_btn.add_theme_font_size_override("font_size", 18)
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.pressed.connect(_on_toggle)
	_style_dark(_toggle_btn)
	_panel.add_child(_toggle_btn)

	# ---- 血脉区（v3）· v61：整段下移（中段变高：护主两行 + 2×2 大钮） ----
	_bl_head = _label("", 17, SEAL)
	_bl_head.position = Vector2(28, 626)
	_bl_head.size = Vector2(584, 26)
	_panel.add_child(_bl_head)

	_bl_slots = _label("", 14, Color(INK.r, INK.g, INK.b, 0.85))
	_bl_slots.position = Vector2(28, 654)
	_bl_slots.size = Vector2(584, 58)
	_bl_slots.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_bl_slots)

	_bl_prev = Button.new()
	_bl_prev.text = "◀"
	# v61（手游）：44×40 → 52×44（翻页钮也要抓得住）
	_bl_prev.position = Vector2(28, 724)
	_bl_prev.size = Vector2(52, 44)
	_bl_prev.focus_mode = Control.FOCUS_NONE
	_bl_prev.pressed.connect(_on_bl_prev)
	_style_dark(_bl_prev)
	_panel.add_child(_bl_prev)

	_bl_pick = _label("", 16, INK)
	_bl_pick.position = Vector2(88, 726)
	_bl_pick.size = Vector2(288, 40)
	_bl_pick.max_lines_visible = 1
	_bl_pick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_panel.add_child(_bl_pick)

	_bl_next = Button.new()
	_bl_next.text = "▶"
	_bl_next.position = Vector2(384, 724)
	_bl_next.size = Vector2(52, 44)
	_bl_next.focus_mode = Control.FOCUS_NONE
	_bl_next.pressed.connect(_on_bl_next)
	_style_dark(_bl_next)
	_panel.add_child(_bl_next)

	_bl_fuse = Button.new()
	_bl_fuse.text = "融　合"
	_bl_fuse.position = Vector2(444, 724)
	_bl_fuse.size = Vector2(168, 44)
	_bl_fuse.add_theme_font_size_override("font_size", 17)
	_bl_fuse.focus_mode = Control.FOCUS_NONE
	_bl_fuse.pressed.connect(_on_fuse)
	_style_seal(_bl_fuse)
	_panel.add_child(_bl_fuse)

	_bl_pre = _label("", 15, GOLD)
	_bl_pre.position = Vector2(28, 782)
	_bl_pre.size = Vector2(584, 30)
	_bl_pre.max_lines_visible = 1
	_bl_pre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_panel.add_child(_bl_pre)

	_msg_lb = _label("", 15, Color(SEAL.r, SEAL.g, SEAL.b, 0.92))
	_msg_lb.position = Vector2(28, 818)
	_msg_lb.size = Vector2(584, 52)
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_msg_lb)

	# v63（用户："宠物界面也是一塌糊涂 你看着优化"）：说明**精简成两句半、字号 13→15**——
	#   原来那段 190 字的长文在 13 号字下又密又糊 ✗；配方/细节以后长按问号再看（预留）。
	_hint_lb = _label("血脉：密柜红件偶尔翻出（凡/紫/金/绝四档，越稀越好）。\n养灵丹升阶（开血脉格）、洗灵丹提资质（+2）、升星吃同名 1/2/4/8/16。\n可养多只——只有随行那只的护主与加成生效。", 15, Color(INK.r, INK.g, INK.b, 0.72))
	_hint_lb.position = Vector2(28, 872)
	_hint_lb.size = Vector2(584, 88)
	_hint_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_hint_lb)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(412, 976)
	close_btn.size = Vector2(200, 52)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	_style_dark(close_btn)
	_panel.add_child(close_btn)

func _label(text: String, font_size: int, col: Color) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", col)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lb

func _flat(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	return sb

func _style_dark(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.19, 0.20, 0.96)))
	btn.add_theme_stylebox_override("hover", _flat(Color(0.31, 0.27, 0.27, 0.96)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.11, 0.12, 0.96)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.40)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.55))

func _style_seal(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.92)))
	btn.add_theme_stylebox_override("hover", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.80)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r * 0.75, SEAL.g * 0.75, SEAL.b * 0.75, 0.95)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.35)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.87))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.50))

func _style_tab(btn: Button, selected: bool) -> void:
	if selected:
		btn.add_theme_stylebox_override("normal", _flat(Color(INK.r, INK.g, INK.b, 0.90)))
		btn.add_theme_stylebox_override("hover", _flat(Color(INK.r, INK.g, INK.b, 0.84)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.88)))
		btn.add_theme_color_override("font_color", PAPER)
		btn.add_theme_color_override("font_hover_color", PAPER)
	else:
		btn.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.30)))
		btn.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.55)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.60)))
		btn.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.75))
		btn.add_theme_color_override("font_hover_color", INK)
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))

# ---- 刷新 ----

func refresh() -> void:
	if _panel == null:
		return
	var owned: Array = GameState.pet_owned()
	var sel := str(GameState.pet_sel)
	if sel == "" and not owned.is_empty():
		GameState.pet_select(str(owned[0]))
		sel = str(GameState.pet_sel)
	var follow := str(GameState.pet_follow)
	for c in _chips:
		var pid := str(c["pid"])
		var btn: Button = c["btn"]
		var own := GameState.pet_has(pid)
		btn.visible = own
		if own:
			var txt := GameState.pet_name_of(pid)
			if pid == follow:
				txt += "·随行"
			btn.text = txt
			_style_tab(btn, pid == sel)
	if owned.is_empty():
		_art.has_pet = false
		_stage_lb.text = "未得"
		_name_lb.text = "（还没遇见它）"
		_apt_lb.text = ""
		_pass_lb.text = "修出村况 1 段后，去后山看看——林子里有动静。"
		_fx_lb.text = ""
		_xp_lb.text = ""
		_xp_fill.size = Vector2(0, 20)   # v61：经验条 18 → 20 高
		_feed_btn.disabled = true
		_feed_btn.text = "喂养灵丹"
		_star_btn.disabled = true
		_star_btn.text = "升星"
		_apt_btn.disabled = true
		_apt_btn.text = "洗灵丹"
		_toggle_btn.disabled = true
		_toggle_btn.text = "让它随行"
		_bl_head.text = "血脉"
		_bl_slots.text = "（遇见宠物后开放：每阶开 1 格）"
		_bl_pick.text = ""
		_bl_pre.text = ""
		_bl_prev.disabled = true
		_bl_next.disabled = true
		_bl_fuse.disabled = true
		return
	var st := GameState.pet_stage_of(sel)
	_art.has_pet = true
	_art.kind = "hawk" if sel == "qing_sun" else "fox"
	_art.stage = st
	_stage_lb.text = GameState.pet_stage_name_of(sel) + " · 第 " + str(st + 1) + "/" + str(GameState.PET_STAGE_MAX + 1) + " 段"
	# ㊿z9：名字后面挂星级（5 格，实心＝已有星）——一眼看出这只养到哪了
	_name_lb.text = GameState.pet_name_of(sel) + "　" + _star_text(GameState.pet_star_of(sel))
	var apt := GameState.pet_apt_of(sel)
	var apt_used := GameState.pet_apt_used(sel)
	var apt_allow := GameState.pet_apt_allow(sel)
	_apt_lb.text = "资质 " + str(apt) + "（" + GameState.pet_apt_tier(apt) + "）　·　洗灵丹本阶 " + str(apt_used) + "/" + str(apt_allow) + "　·　亲和：" + DataPets.elem_cn(DataPets.elem_of(sel))
	var act := "随行中"
	if follow == "":
		act = "留守（现在没有宠物随行——加成暂失效）"
	elif follow != sel:
		act = "留守（随行的是" + GameState.pet_name_of(follow) + "）"
	# ㊿z9：这两行以前写死"护主…气血%"——青隼的主加成是速度，写死就把它的加成报成 0。
	#   改成直接念账本算出来的那一份（哪只给什么就显示什么）
	var ft := DataPets.fx_text(GameState.pet_fx_of(sel))
	_pass_lb.text = "随行加成：" + (ft if ft != "" else "——") + "（基础 + 每阶 2 + 血脉，再乘升星倍率）· " + act
	if ft == "":
		_fx_lb.text = "加成：——（这只现在没沾任何一档）"
		_fx_lb.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.45))
	else:
		_fx_lb.text = "加成：" + ft + "（已并入全队属性——村内与游历都吃）"
		_fx_lb.add_theme_color_override("font_color", GOLD)
	if st >= GameState.PET_STAGE_MAX:
		_xp_lb.text = "已至 " + GameState.pet_stage_name_of(sel) + "（到顶）"
		_xp_fill.size = Vector2(584, 20)
		_feed_btn.disabled = true
		_feed_btn.text = "已到顶"
	else:
		var pr: Dictionary = GameState.pet_progress_of(sel)
		var into := int(pr["into"])
		var need := int(pr["need"])
		_xp_lb.text = "灵息 " + str(into) + " / " + str(need)
		_xp_fill.size = Vector2(584.0 * clampf(float(into) / float(maxi(1, need)), 0.0, 1.0), 20)
		var cnt := GameState.pill_count("yangling")
		_feed_btn.disabled = cnt <= 0
		_feed_btn.text = "喂养灵丹（存 " + str(cnt) + "）"
	# ㊿z9：升星（吃同名份数）与洗灵丹（资质丹）——判灰一律问账本那份 can 口径，
	#   面板不自己算"够不够"，免得两处标准打架
	var s_cur := GameState.pet_star_of(sel)
	if s_cur >= GameState.PET_STAR_MAX:
		_star_btn.text = "已满星"
		_star_btn.disabled = true
	else:
		var s_need := GameState.pet_star_cost_next(sel)
		var s_have := GameState.pet_dup_count(sel)
		_star_btn.text = "升 " + str(s_cur + 1) + " 星（" + str(s_have) + "/" + str(s_need) + "）"
		var sc := GameState.pet_star_can(sel)
		_star_btn.disabled = not bool(sc.get("ok", false))
	var xl := GameState.pill_count("xiling")
	# 按钮字宽有上限（Godot 的按钮文字不换行，超了就裁掉）——这里用最短说法
	if xl <= 0:
		_apt_btn.text = "洗灵丹（无）"
		_apt_btn.disabled = true
	elif apt_used >= apt_allow:
		_apt_btn.text = "洗灵丹（本阶满）"
		_apt_btn.disabled = true
	else:
		_apt_btn.text = "洗灵丹（存" + str(xl) + "）"
		_apt_btn.disabled = false
	_toggle_btn.disabled = false
	if sel == follow:
		_toggle_btn.text = "随行中 · 点我歇着"
	elif follow != "":
		_toggle_btn.text = "让它随行（换下" + GameState.pet_name_of(follow) + "）"
	else:
		_toggle_btn.text = "让它随行"

	# ---- 血脉区 ----
	var bl: Array = GameState.pet_bl_list(sel)
	var open_n := GameState.pet_bl_slots(sel)
	_bl_head.text = "血脉 " + str(bl.size()) + "/" + str(open_n) + " 格（每升 1 阶开 1 格）"
	var segs: Array = []
	for i in GameState.PET_STAGE_MAX + 1:
		var mark := str(i + 1) + " "
		if i < bl.size():
			var e: Dictionary = bl[i]
			var bid := str(e.get("id", ""))
			var s1 := DataPets.blood_name(bid) + "（纯" + str(int(e.get("pur", 50)))
			if DataPets.fit_of(sel, bid):
				s1 += "·契合"
			s1 += "）"
			mark += s1
		elif i == bl.size() and i < open_n:
			mark += "（空·可融合）"
		else:
			mark += "——"
		segs.append(mark)
	_bl_slots.text = "　".join(PackedStringArray(segs))
	var n := GameState.blood_inv_size()
	if n <= 0:
		_bl_pick.text = "行囊空——血脉从密柜偶尔翻出，货栈也有金色卖"
		_bl_pre.text = ""
		_bl_prev.disabled = true
		_bl_next.disabled = true
		_bl_fuse.disabled = true
	else:
		_bl_sel = clampi(_bl_sel, 0, n - 1)
		var e2 := GameState.blood_get(_bl_sel)
		var bid2 := str(e2.get("id", ""))
		var q2 := int(DataPets.blood_of(bid2).get("q", 2))
		_bl_pick.text = "选中：" + DataPets.blood_name(bid2) + "（" + DataPets.quality_cn(q2) + " · 纯 " + str(int(e2.get("pur", 50))) + "）"
		_bl_prev.disabled = n <= 1
		_bl_next.disabled = n <= 1
		if bl.size() >= open_n:
			_bl_pre.text = "（本段格位已用满——升 1 阶再开 1 格）"
			_bl_fuse.disabled = true
		else:
			_bl_pre.text = "预计：" + GameState.blood_preview_text(sel, _bl_sel)
			_bl_fuse.disabled = false

# ---- 点击 ----

func _on_pick(pid: String) -> void:
	GameState.pet_select(pid)
	_msg_lb.text = ""
	_bl_sel = 0
	refresh()

func _on_feed() -> void:
	var r := GameState.pet_feed()
	_msg_lb.text = str(r.get("msg", ""))
	refresh()

# ㊿z9：升星——同名份数（来路还没定，账本先记账；测试包 B 键会发几只）
func _on_star() -> void:
	_msg_lb.text = GameState.pet_star_up(str(GameState.pet_sel))
	refresh()

# ㊿z9：洗灵丹——资质 +2，每阶限 1 颗（与洗髓丹"每境 1 颗"同口径）
func _on_apt() -> void:
	var r := GameState.pet_eat_apt()
	_msg_lb.text = str(r.get("msg", ""))
	refresh()

# 星级那五个格：实心＝已有，空心＝还没到
func _star_text(n: int) -> String:
	var out := ""
	for i in GameState.PET_STAR_MAX:
		out += "★" if i < n else "☆"
	return out

func _on_toggle() -> void:
	_msg_lb.text = GameState.pet_toggle()
	refresh()

func _on_bl_prev() -> void:
	var n := GameState.blood_inv_size()
	if n <= 1:
		return
	_bl_sel = (_bl_sel + n - 1) % n
	refresh()

func _on_bl_next() -> void:
	var n := GameState.blood_inv_size()
	if n <= 1:
		return
	_bl_sel = (_bl_sel + 1) % n
	refresh()

func _on_fuse() -> void:
	var sel := str(GameState.pet_sel)
	var r := GameState.pet_fuse_blood(sel, _bl_sel)
	_msg_lb.text = str(r.get("msg", ""))
	refresh()

func open() -> void:
	_msg_lb.text = ""
	_bl_sel = 0
	refresh()
	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			close()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
