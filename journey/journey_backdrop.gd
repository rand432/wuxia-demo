extends RefCounted
# ============================================================
# journey_backdrop.gd —— 游历背景绘制件 v1（拆件批）
# 拆分自 journey_stage v20 的 _draw 与四个绘制助手（_ridge/_props/_road_marks/
# _ink_capsule），逐字搬运、只改静态：绘制目标由调用方传入。
# 舞台那边 _draw() 里只剩一行：Backdrop.draw_all(self, size, 三个滚动量)。
# ============================================================

const UiKit := preload("res://shared/ui_kit.gd")
const SceneArt := preload("res://shared/scene_art.gd")   # v78：素材里的水墨城郭远景


static func draw_all(ctrl: Control, sz: Vector2, scroll_far: float, scroll_mid: float, scroll_road: float) -> void:
	var w: float = sz.x
	var h: float = sz.y
	ctrl.draw_rect(Rect2(0, 0, w, h), UiKit.PAPER)
	# v78（用户："图4 不适合做游历旅途的更换场景？"）：**远景真的换成素材里那幅水墨城郭了**
	#   （影之刃 Atlas_MainMap 切出来的月夜城郭）——视差最慢、横向无缝平铺。
	#   找不到图就退回原来的程序化远山，功能不受影响。
	# v146（用户："游历背景换成这个"）：主背景＝assets/scenes/journey_xishan.png
	#   （一幅水墨山水）。它是一张**整幅画**，不是"远景剪影"——所以用它的时候
	#   程序化那两层远山/近树就不画了（会跟画打架），只留地平线、地面压色与路标。
	var art_tex := SceneArt.journey_scene()
	if art_tex != null:
		_draw_painting(ctrl, sz, scroll_far, art_tex)
		# 地平线以下那一条压色：0.42 —— 再淡一点画里的水石就透出来了，
		#   再浓一点就糊成一条白带（0.55 试过，看着像被裁掉半张画）
		ctrl.draw_rect(Rect2(0, 950.0, w, h - 950.0), Color(0.885, 0.850, 0.775, 0.42))
		ctrl.draw_line(Vector2(0, 950.0), Vector2(w, 950.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.30), 2.0)
		_road_marks(ctrl, sz, scroll_road)
		return
	var far_tex := SceneArt.map_night()
	if far_tex != null:
		# ⚠ 直接 tile=true 会看出"同一座城并排两份"（第一版就是），改**正反交替**：
		#   一张正着画、下一张水平翻转画（负宽度即翻转），接缝处两边是镜像 → 看不出重复。
		# v92（用户："游历背景图依旧没有全覆盖"）：**铺满整屏**——
		#   原来只铺到 y=950，下面那 330 像素是一条平涂的土色带（画面像被裁掉一半）。
		#   现在贴图直接铺到屏幕底，那条"地"改成**半透明的压色带**：人还是站在 950 的地平线上，
		#   但底下的图透得出来，整屏是一张画。
		var th: float = h
		var tw: float = th * float(far_tex.get_width()) / maxf(float(far_tex.get_height()), 1.0)
		var period := tw * 2.0
		var x := -fposmod(scroll_far * 0.12, period)
		var tint := Color(1, 1, 1, 0.88)
		while x < w:
			ctrl.draw_texture_rect(far_tex, Rect2(x, 0.0, tw, th), false, tint)
			ctrl.draw_texture_rect(far_tex, Rect2(x + tw, 0.0, -tw, th), false, tint)
			x += period
	else:
		_ridge(ctrl, sz, scroll_far, 766.0, 118.0, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.055), 940.0)
	_ridge(ctrl, sz, scroll_mid, 828.0, 88.0, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.095), 720.0)
	_props(ctrl, sz, scroll_mid * 1.35)
	# v92：地平线以下**不再平涂**——改成半透明压色（图透出来，人照样有"地"）
	ctrl.draw_rect(Rect2(0, 950.0, w, h - 950.0), Color(0.885, 0.850, 0.775, 0.62))
	ctrl.draw_line(Vector2(0, 950.0), Vector2(w, 950.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.30), 2.0)
	_road_marks(ctrl, sz, scroll_road)

# v146：把那张水墨山水铺满整屏——**按屏幕高度缩放**（1680×720 的横画 → 1280 高、
#   约 2987 宽），横向按视差缓慢平移、正反交替接缝（与老远景同一套写法，接缝处是镜像，
#   看不出重复）。竖屏里一屏只看到整幅画的四分之一左右——正好是"走在画里"的感觉。
static func _draw_painting(ctrl: Control, sz: Vector2, scroll: float, tex: Texture2D) -> void:
	var th: float = sz.y
	var tw: float = th * float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
	var period := tw * 2.0
	var x := -fposmod(scroll * 0.12, period)
	while x < sz.x:
		ctrl.draw_texture_rect(tex, Rect2(x, 0.0, tw, th), false, Color(1, 1, 1, 1.0))
		ctrl.draw_texture_rect(tex, Rect2(x + tw, 0.0, -tw, th), false, Color(1, 1, 1, 1.0))
		x += period

static func _ridge(ctrl: Control, sz: Vector2, offset: float, base_y: float, hgt: float, col: Color, wave: float) -> void:
	var pts := PackedVector2Array()
	var x := -60.0
	while x <= sz.x + 60.0:
		var y: float = base_y - hgt * (0.5 + 0.5 * sin((x + offset) * TAU / wave))
		pts.append(Vector2(x, y))
		x += 36.0
	pts.append(Vector2(sz.x + 60.0, 950.0))
	pts.append(Vector2(-60.0, 950.0))
	ctrl.draw_colored_polygon(pts, col)

static func _props(ctrl: Control, sz: Vector2, offset: float) -> void:
	var span := sz.x + 600.0
	var period := 260.0
	var n := int(span / period) + 2
	for i in n:
		var x := fposmod(float(i) * period - offset, span) - 120.0
		if x < -140.0 or x > sz.x + 140.0:
			continue
		var hgt := 120.0 + fposmod(float(i) * 53.0, 90.0)
		var c1 := Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.10)
		var c2 := Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.07)
		_ink_capsule(ctrl, Vector2(x, 952.0), Vector2(x + 7.0, 952.0 - hgt), 5.0, 3.2, c1)
		_ink_capsule(ctrl, Vector2(x + 42.0, 952.0), Vector2(x + 47.0, 952.0 - hgt * 0.72), 4.2, 2.8, c2)
		var ty := 952.0 - hgt
		ctrl.draw_line(Vector2(x + 6.0, ty + 16.0), Vector2(x + 30.0, ty - 4.0), c1, 3.0, true)
		ctrl.draw_line(Vector2(x + 6.0, ty + 34.0), Vector2(x - 18.0, ty + 14.0), c2, 3.0, true)

static func _road_marks(ctrl: Control, sz: Vector2, scroll_road: float) -> void:
	var span := sz.x + 240.0
	var count := int(span / 170.0) + 1
	for i in count:
		var x := fposmod(float(i) * 170.0 - scroll_road, span)
		ctrl.draw_line(Vector2(x, 986.0), Vector2(x + 48.0, 986.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.10), 3.0, true)
	var count2 := int(span / 240.0) + 1
	for i in count2:
		var x2 := fposmod(float(i) * 240.0 - scroll_road * 1.25, span)
		var yy := 1016.0 + float(i % 3) * 14.0
		ctrl.draw_circle(Vector2(x2, yy), 2.6, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.09))

static func _ink_capsule(ctrl: Control, a: Vector2, b: Vector2, ra: float, rb: float, col: Color) -> void:
	var seg := b - a
	if seg.length() < 0.01:
		ctrl.draw_circle(a, maxf(ra, rb), col)
		return
	var th := seg.angle()
	var pts := PackedVector2Array()
	for i in 6:
		var ang := th - PI * 0.5 + PI * float(i) / 5.0
		pts.append(b + Vector2(cos(ang), sin(ang)) * rb)
	for i in 6:
		var ang2 := th + PI * 0.5 + PI * float(i) / 5.0
		pts.append(a + Vector2(cos(ang2), sin(ang2)) * ra)
	ctrl.draw_colored_polygon(pts, col)

# ============================================================
# v139（用户："茅屋背景没有图"）：**茅屋是现画的**——没有美术也能读成"屋里"：
#   暗墙、顶梁、漏顶的一道光柱与一滴水、药炉的一点火、右下床板、左下门缝。
#   全部程序化；t（走路的累计秒数）只用来让那滴水往下走。
#   以后有图就把这里整段换成 draw_texture_rect 铺一张。
# ============================================================
static func draw_hut(ctrl: Control, sz: Vector2, t: float) -> void:
	var w: float = sz.x
	var h: float = sz.y
	# 墙：上亮下暗
	ctrl.draw_rect(Rect2(0, 0, w, h), Color(0.105, 0.092, 0.088))
	ctrl.draw_rect(Rect2(0, 0, w, h * 0.55), Color(0.135, 0.118, 0.108))
	# 顶梁
	ctrl.draw_rect(Rect2(0, 96, w, 26), Color(0.075, 0.065, 0.060))
	ctrl.draw_rect(Rect2(0, 122, w, 8), Color(0.058, 0.050, 0.046))
	# 门（左下）：门板 + 门缝一线光
	ctrl.draw_rect(Rect2(28, 620, 132, 330), Color(0.088, 0.076, 0.070))
	ctrl.draw_line(Vector2(160, 620), Vector2(160, 950), Color(0.85, 0.80, 0.66, 0.22), 2.0)
	# 床（右下）：板 + 床沿 + 床腿
	ctrl.draw_rect(Rect2(392, 838, 300, 42), Color(0.145, 0.120, 0.098))
	ctrl.draw_rect(Rect2(392, 880, 300, 14), Color(0.095, 0.078, 0.062))
	ctrl.draw_rect(Rect2(392, 894, 300, 56), Color(0.125, 0.105, 0.088))
	# 漏顶：一道斜光柱 + 一滴正在落的水
	var hole := Vector2(w * 0.70, 130.0)
	ctrl.draw_colored_polygon(PackedVector2Array([
		hole + Vector2(-26, 0), hole + Vector2(26, 0),
		hole + Vector2(120, 700), hole + Vector2(20, 700),
	]), Color(0.86, 0.82, 0.68, 0.055))
	ctrl.draw_circle(hole, 5.0, Color(0.90, 0.86, 0.72, 0.35))
	var drip := fposmod(t * 260.0, 700.0)
	ctrl.draw_circle(hole + Vector2(0, drip), 2.6, Color(0.86, 0.82, 0.70, 0.55))
	if drip > 690.0:
		ctrl.draw_circle(Vector2(hole.x + 60, 900), 10.0, Color(0.86, 0.82, 0.70, 0.10))
	# 药炉（右下偏中）：一点火
	var fire := Vector2(300, 900)
	for i in 3:
		ctrl.draw_circle(fire, 26.0 + float(i) * 16.0, Color(0.92, 0.55, 0.20, 0.05))
	ctrl.draw_circle(fire, 12.0, Color(0.95, 0.62, 0.26, 0.55))
	ctrl.draw_circle(fire, 5.0, Color(1.0, 0.86, 0.55, 0.85))
	# 四边压角
	ctrl.draw_rect(Rect2(0, 0, w, 70), Color(0, 0, 0, 0.22))
	ctrl.draw_rect(Rect2(0, h - 120.0, w, 120.0), Color(0, 0, 0, 0.28))
