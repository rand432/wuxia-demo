extends RefCounted
# ============================================================
# ui_kit.gd —— 通用界面小工厂（全静态函数，不挂场景）
# 规矩：Label 文字一律走 set_text()，内部 str() 兜底；
#       数据缺失最多显示 "<null>"，绝不崩溃。
# v11：float_text 的浮字条从横屏坐标 (430,y) 搬到竖屏居中 (150,y)。
# ============================================================

const Audio := preload("res://shared/audio.gd")   # v65：点击音（全game 按钮都出自 make_button，一处挂全）

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.93, 0.90, 0.83)
const PAPER_DARK := Color(0.87, 0.83, 0.74)
const SEAL := Color(0.68, 0.15, 0.12)
const GOLD := Color(0.72, 0.55, 0.18)
const GREEN := Color(0.30, 0.50, 0.34)
const BLUE := Color(0.28, 0.42, 0.58)
const DIM := Color(0.38, 0.36, 0.34)

static func font() -> Font:
	if ResourceLoader.exists("res://fonts/ink.ttf"):
		var f: Resource = load("res://fonts/ink.ttf")
		if f is Font:
			return f
	return null

static func set_text(lb: Label, v: Variant) -> void:
	if lb == null:
		return
	lb.text = str(v)

static func set_btn_text(btn: Button, v: Variant) -> void:
	if btn == null:
		return
	btn.text = str(v)

static func make_label(parent: Node, pos: Vector2, sz: Vector2, fs: int, col: Color) -> Label:
	var lb := Label.new()
	lb.position = pos
	lb.size = sz
	lb.add_theme_font_size_override("font_size", fs)
	lb.add_theme_color_override("font_color", col)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := font()
	if f != null:
		lb.add_theme_font_override("font", f)
	parent.add_child(lb)
	return lb

static func paper_box(alpha := 0.95) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, alpha)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	sb.set_border_width_all(2)
	return sb

static func ink_box(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb

static func style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", ink_box(Color(0.21, 0.19, 0.20, 0.96)))
	btn.add_theme_stylebox_override("hover", ink_box(Color(0.31, 0.27, 0.27, 0.96)))
	btn.add_theme_stylebox_override("pressed", ink_box(Color(0.13, 0.11, 0.12, 0.96)))
	btn.add_theme_stylebox_override("disabled", ink_box(Color(0.30, 0.28, 0.27, 0.45)))
	btn.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	btn.add_theme_color_override("font_disabled_color", Color(0.94, 0.91, 0.84, 0.35))
	var f := font()
	if f != null:
		btn.add_theme_font_override("font", f)

# ============================================================
# v61（用户："临时仓库购买一格之后字体自动变成白色，完全融入白色背景中看不见了"）
#
#   病根：**只设了 `font_color` 一个状态**。Godot 的 Button 有六个字色状态，
#   没设的那几个会回落到**默认主题**——而默认主题里 hover / pressed / focus /
#   hover_pressed 全是**纯白**（(0.95,0.95,0.95) 与 (1,1,1)）。
#   于是浅底按钮（出征屏的「临时仓库 N 格：买一格 ＝ X 两」「命数」「暂不」
#   以及九只锁着的路）只要鼠标一停上去，字就变白、压在白底上，一个字都看不见。
#   为什么"买了之后才发现"：点完那一下鼠标还停在按钮上，走的正是 hover 那条色。
#
#   规矩：**给按钮上字色，一律走这一口**（六态一次设满）；深底按钮也走它——
#   反正同一个色在深底上照样清楚，省得下次再漏。
#   要单独禁用态就自己补一句 `font_disabled_color`。
# ============================================================
static func font_states(btn: Button, col: Color) -> void:
	if btn == null:
		return
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", col)
	btn.add_theme_color_override("font_pressed_color", col)
	btn.add_theme_color_override("font_focus_color", col)
	btn.add_theme_color_override("font_hover_pressed_color", col)

# ============================================================
# v61（用户："升星的弟子面板也很难滑动 容易误触……因为是手游"）
#
#   病根：滚动区里那种"整行/整格可点"的 Button 是 `MOUSE_FILTER_STOP`——
#   手指一按上去，事件就被它吃掉，**滚动区根本收不到拖动** → 列表滑不动；
#   而松手时不管刚才拖了多远，Button 照样发 `pressed` → 一滑就误点。
#
#   这一口把点击层改成"**拖得动、点得准**"：
#     · `mouse_filter = PASS`：事件照收，但也继续传给父级滚动区 → 拖动生效；
#     · 自己判手势：按下到抬起**位移 ≤ 14 像素且 ≤ 0.7 秒**才算"点了"，
#       超过就当"在滑列表"，什么都不触发。
#     · 同时认触摸（手机）与鼠标（桌面上调试）两种事件。
#
#   用法：`UiKit.tap_in_scroll(cell, func(): ...)` —— **不要再接自己的 pressed/gui_input**，
#   否则拖动松手时两边都触发，等于白改。
#
#   v61b（用户："仓库的上下滑动需要优化 极易误触仓库物品"）：
#     · 参数从 Button 放宽到 **Control**（仓库/货仓的格子是 Panel，不是 Button）；
#     · 第三参 `swallow`：左键按下时 `accept_event()`（给"底下的父级也在收左键"的场合——
#       鉴宝行货仓格就是这样：不吞掉的话，这一下会顺手把父面板的"跳过动画"也触发了）。
# ============================================================
const TAP_SLOP := 14.0      # 允许的抖动像素
const TAP_MS := 700         # 最长算"点击"的按压时长（毫秒）

static func tap_in_scroll(c: Control, on_tap: Callable, swallow := false) -> void:
	if c == null:
		return
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var st := {"x": 0.0, "y": 0.0, "t": 0, "drag": false}
	c.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			var t := ev as InputEventScreenTouch
			if t.pressed:
				st["x"] = t.position.x
				st["y"] = t.position.y
				st["t"] = Time.get_ticks_msec()
				st["drag"] = false
				if swallow:
					c.accept_event()
			elif not bool(st["drag"]) and Time.get_ticks_msec() - int(st["t"]) <= TAP_MS:
				on_tap.call()
		elif ev is InputEventScreenDrag:
			var d := ev as InputEventScreenDrag
			if Vector2(d.position.x - float(st["x"]), d.position.y - float(st["y"])).length() > TAP_SLOP:
				st["drag"] = true
		elif ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			if mb.pressed:
				st["x"] = mb.position.x
				st["y"] = mb.position.y
				st["t"] = Time.get_ticks_msec()
				st["drag"] = false
				if swallow:
					c.accept_event()
			elif not bool(st["drag"]) and Time.get_ticks_msec() - int(st["t"]) <= TAP_MS:
				on_tap.call()
		elif ev is InputEventMouseMotion:
			var mm := ev as InputEventMouseMotion
			if mm.button_mask != 0 and Vector2(mm.position.x - float(st["x"]), mm.position.y - float(st["y"])).length() > TAP_SLOP:
				st["drag"] = true
	)

# v63（用户："右边上下滑动用着不太顺，每次要拉好几次…做成指尖滑动那种"）：
#   给滚动区挂上"按住内容上下拖＝滚动"——不用再对准那条细滚动条。
#   与 tap_in_scroll 兼容：拖得远＝滚（点击判定因位移超界自动取消），几乎没动＝点。
static func drag_scroll(sc: ScrollContainer) -> void:
	if sc == null:
		return
	sc.gui_input.connect(_on_drag_scroll.bind(sc))

static func _on_drag_scroll(ev: InputEvent, sc: ScrollContainer) -> void:
	if ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT and mm.relative.y != 0.0:
			sc.scroll_vertical = int(sc.scroll_vertical - mm.relative.y)
			sc.accept_event()

static func make_button(parent: Node, pos: Vector2, sz: Vector2, txt: String, fs: int) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	style_button(b)
	set_btn_text(b, txt)
	# v68：点一下出声 + **按下去缩一点**（手游的"到手感"；松手弹回）。
	#   pivot 必须设成按钮中心，不然是从左上角缩放、看着像歪了。
	b.pressed.connect(func() -> void: Audio.ui_click())
	b.button_down.connect(func() -> void: _press_fx(b, 0.955))
	b.button_up.connect(func() -> void: _press_fx(b, 1.0))
	b.mouse_exited.connect(func() -> void: _press_fx(b, 1.0))
	parent.add_child(b)
	return b

# 按下/松开的小缩放动画
static func _press_fx(b: Button, to: float) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(to, to), 0.08).set_trans(Tween.TRANS_SINE)

# 面板进场 v69："墨落纸上"——从 0.94 弹回 1、同时淡入（pivot 必须在中心，不然是从左上角涨开）
static func pop_in(c: Control, dur := 0.17) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.94, 0.94)
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.7)

static func make_paper_panel(parent: Node, rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_theme_stylebox_override("panel", paper_box(0.97))
	parent.add_child(p)
	# v69（用户："有的按钮 ui 要会动画，点击有反馈"）：**全工程 32 处面板都出自这里**，
	#   所以进场动画挂在这一处就够了——创建时播一次，之后每次"由隐转显"再播一次。
	pop_in(p)
	p.visibility_changed.connect(func() -> void:
		if is_instance_valid(p) and p.visible:
			pop_in(p))
	return p

static func make_veil(parent: Control, vsize: Vector2, alpha := 0.52) -> ColorRect:
	var veil := ColorRect.new()
	veil.color = Color(0.08, 0.07, 0.08, alpha)
	veil.position = Vector2.ZERO
	veil.size = vsize
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(veil)
	return veil

static func float_text(host: Node, txt: String, col: Color, y := 150.0) -> void:
	if host == null:
		return
	var lb := make_label(host, Vector2(150, y), Vector2(420, 40), 22, col)
	set_text(lb, txt)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.modulate.a = 0.0
	var tw := host.create_tween()
	tw.tween_property(lb, "modulate:a", 1.0, 0.08)
	tw.tween_property(lb, "position:y", y - 44.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lb, "modulate:a", 0.0, 0.25)
	tw.finished.connect(lb.queue_free)

# ============================================================
# v58（用户："记得伤害弹出记得标注是什么类型伤害 比如火元素就火焰图标标志"）：
#   **伤害类型徽章**——一枚小方块，底色＝该属性的颜色，里面一个字（火/水/金/木/土）。
#   项目里没有图标素材（历来都是 draw_rect / draw_string 画的），所以"图标"就用这一枚
#   带底色的小字牌：一眼分得出是火还是水，也不需要外部资源。
#   物理/真实不给徽章（老样子只有数字）——只有**元素伤害**才标，免得满屏都是牌子。
# ============================================================
const ELEM_BADGE := 30.0      # 徽章边长

static func elem_badge(elem: String, side := ELEM_BADGE) -> Control:
	if elem == "":
		return null
	var Elem := load("res://shared/data_elem.gd")
	if not Elem.markable(elem):
		return null
	var col: Color = Elem.col(elem)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(side, side)
	p.size = Vector2(side, side)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.92)
	sb.set_corner_radius_all(int(side * 0.28))
	sb.border_color = Color(0.98, 0.96, 0.91, 0.85)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	var lb := Label.new()
	lb.text = Elem.badge_cn(elem)
	lb.position = Vector2.ZERO
	lb.size = Vector2(side, side)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", int(side * 0.72))
	lb.add_theme_color_override("font_color", Color(0.10, 0.09, 0.10))
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := font()
	if f != null:
		lb.add_theme_font_override("font", f)
	p.add_child(lb)
	return p

# 一行"徽章 + 数字"（返回容器；elem 为空时只返回数字控件）。
# 给两套引擎的飘字用：游历 fx_layer.number / 出村 battle_lite._float_at 都调它，
# 于是"伤害类型怎么标"只有一处口径。
#   gap 徽章与数字之间留多少；fs 数字字号；col 数字颜色
static func elem_number_row(txt: String, col: Color, elem: String, fs: int, gap := 6.0) -> Control:
	var Elem := load("res://shared/data_elem.gd")
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lb := Label.new()
	lb.text = txt
	lb.add_theme_font_size_override("font_size", fs)
	lb.add_theme_color_override("font_color", col)
	lb.add_theme_color_override("font_outline_color", Color(0.98, 0.96, 0.91, 0.55))
	lb.add_theme_constant_override("outline_size", 9)
	var f := font()
	if f != null:
		lb.add_theme_font_override("font", f)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Elem.markable(elem):
		row.add_child(lb)
		row.custom_minimum_size = Vector2(170, 66)
		lb.size = Vector2(170, 66)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return row
	var bs := 30.0
	var badge := elem_badge(elem, bs)
	badge.position = Vector2(0, 18)
	row.add_child(badge)
	lb.position = Vector2(bs + gap, 0)
	lb.size = Vector2(150, 66)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(lb)
	row.custom_minimum_size = Vector2(bs + gap + 150.0, 66)
	return row
