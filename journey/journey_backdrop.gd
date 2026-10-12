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
