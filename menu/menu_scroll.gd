extends Node2D
# ============================================================
# menu_scroll.gd —— 画心层（拆分 3/6）：纸 + 山水 + 河 + 树 + 小人 + 船
# v8：加"四季"环境层——由 menu_sketch 每帧喂 season（0春 1夏 2秋 3冬）：
#   春：柳絮缓缓漂；夏：蜻蜓贴水打转、日光更强、水色微绿；
#   秋：金叶旋落；冬：落雪 + 地面薄白 + 水色转冷、碎光减半。
#   日、水中日影也随季节微微变；其余一字未动。
# v7：孤树从 x=636 挪到 268（不再被后山挡）。
# v6：水（流光/碎光）、桥影、岸石涟漪、船尾迹桨圈、鱼跃、两层雾、山门灯笼、
#     松落针、路浮尘、两折翅鸟。
# 接口（t / cam / fig_x）与 v5 相同；村子部分在 menu_village.gd。
# ============================================================

const Conf := preload("res://menu/menu_conf.gd")
const Draw := preload("res://menu/menu_draw.gd")
const SceneArt := preload("res://shared/scene_art.gd")   # v91：画卷远景用素材

var t := 0.0
var cam := 0.0
var season := 0   # 0春 1夏 2秋 3冬（menu_sketch 喂）
var _sp: Array = []
var _wash: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260212
	for i in 80:   # v62（用户："太多无用的了"）：260 → 80，纸纹留着，满屏飘点去掉
		_sp.append(Vector4(rng.randf_range(0.0, Conf.STRIP_W), rng.randf_range(Conf.SCENE_TOP + 10.0, Conf.SCENE_BOT - 10.0), rng.randf_range(0.8, 2.4), rng.randf_range(0.015, 0.040)))
	for i in 12:
		_wash.append(Vector4(rng.randf_range(150.0, Conf.STRIP_W - 150.0), rng.randf_range(360.0, 640.0), rng.randf_range(140.0, 240.0), rng.randf_range(0.012, 0.026)))

# 少年走到哪儿（主脚本做点击判定时问这一句，别自己再算一遍）
func fig_x() -> float:
	return Conf.FIG_CX + sin(t * Conf.FIG_RATE) * Conf.FIG_SPAN

func _draw() -> void:
	draw_rect(Rect2(0, Conf.SCENE_TOP, Conf.STRIP_W, Conf.SCENE_BOT - Conf.SCENE_TOP), Conf.PAPER)
	for w in _wash:
		var v: Vector4 = w
		if Draw.vis(cam, v.x - v.z, v.x + v.z):
			Draw.ellipse(self, Vector2(v.x, v.y), v.z, v.z * 0.55, Color(0.55, 0.48, 0.36, v.w))
	for s in _sp:
		var v2: Vector4 = s
		if Draw.vis(cam, v2.x, v2.x):
			draw_circle(Vector2(v2.x, v2.y), v2.z, Color(0.30, 0.24, 0.17, v2.w))
	# 由远及近
	# v92：**远景素材已挪到 menu_village._far_mat()**（在村景层的最底下画，见那边的注）。
	#   这一层（画卷层）画什么都会被村景层盖住，所以远景不放这儿——原来那个
	#   _scroll_far() 写在这一层又没人调用，是死代码，已删。
	_sun()
	_cloud_band()
	_water()
	_sun_on_water()
	_bridge()
	_shore()
	_reeds()
	_pine()
	_trees()
	_bamboo_clump(1176.0)
	_bamboo_clump(1790.0)
	_bamboo_clump(2540.0)
	_path()
	_gate()
	_figure()
	_path_walker()
	_boat()
	_fish()
	_mist()
	_birds()
	_geese()
	_season_air()

# ============ 远景 ============
# v92：这一段原来有个 _scroll_far()（v91 写的素材远景）——**全工程没人调用**，
#   是死代码：画在画卷层还会被村景层盖住。已整段删除，素材远景现在在
#   menu_village._far_mat()（画心最底层，正反交替平铺）。

func _mountains() -> void:
	if Draw.vis(cam, 600.0, 1300.0):
		var m1 := PackedVector2Array([
			Vector2(660, 620), Vector2(760, 470), Vector2(870, 380), Vector2(940, 318),
			Vector2(1020, 390), Vector2(1120, 470), Vector2(1240, 610)])
		draw_colored_polygon(m1, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.072))
		Draw.stroke(self, [Vector2(662, 618), Vector2(770, 465), Vector2(872, 378), Vector2(940, 320), Vector2(1016, 388), Vector2(1124, 466), Vector2(1236, 606)], 3.2, 1.2, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.22))
		for k in 3:
			var xx := 840.0 + float(k) * 46.0
			Draw.stroke(self, [Vector2(xx, 430.0 + float(k) * 34.0), Vector2(xx - 8.0, 476.0 + float(k) * 30.0)], 2.2, 0.8, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.13))
	if Draw.vis(cam, 1100.0, 1700.0):
		var m2 := PackedVector2Array([
			Vector2(1160, 620), Vector2(1270, 520), Vector2(1372, 428),
			Vector2(1450, 470), Vector2(1540, 540), Vector2(1640, 618)])
		draw_colored_polygon(m2, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.100))
		Draw.stroke(self, [Vector2(1162, 618), Vector2(1272, 518), Vector2(1372, 430), Vector2(1448, 470), Vector2(1542, 538), Vector2(1636, 616)], 3.6, 1.3, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.26))
		for k in 4:
			var xx2 := 1300.0 + float(k) * 58.0
			Draw.stroke(self, [Vector2(xx2, 520.0), Vector2(xx2 - 10.0, 560.0 + float(k) * 8.0)], 2.0, 0.8, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.15))
		Draw.ellipse(self, Vector2(1400, 600), 170.0, 170.0 / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.035))

# 日：淡朱一枚 + 三层晕（光晕会呼吸；夏更亮、冬更淡）
func _sun() -> void:
	if not Draw.vis(cam, Conf.SUN_X - 200.0, Conf.SUN_X + 200.0):
		return
	var c := Conf.SEAL_C
	var br := 0.90 + 0.10 * sin(t * 0.30)
	var boost := 1.0
	if season == 1:
		boost = 1.20
	elif season == 3:
		boost = 0.80
	Draw.ellipse(self, Vector2(Conf.SUN_X, Conf.SUN_Y), Conf.SUN_HALO, Conf.SUN_HALO / Draw.sy(), Color(c.r, c.g, c.b, 0.040 * br * boost))
	Draw.ellipse(self, Vector2(Conf.SUN_X, Conf.SUN_Y), Conf.SUN_HALO * 0.62, Conf.SUN_HALO * 0.62 / Draw.sy(), Color(c.r, c.g, c.b, 0.060 * br * boost))
	Draw.ellipse(self, Vector2(Conf.SUN_X, Conf.SUN_Y), Conf.SUN_R * 1.12, Conf.SUN_R * 1.12 / Draw.sy(), Color(c.r, c.g, c.b, 0.14 * boost))
	Draw.ellipse(self, Vector2(Conf.SUN_X, Conf.SUN_Y), Conf.SUN_R, Conf.SUN_R / Draw.sy(), Color(c.r, c.g, c.b, 0.34 * boost))

func _cloud_band() -> void:
	var ry := 62.0 / Draw.sy()
	for i in 11:
		var spd := 2.6 + 1.8 * float(i % 3)
		var cx := fposmod(700.0 + float(i) * 196.0 + t * spd, Conf.CLOUD_W) - 200.0
		if not Draw.vis(cam, cx - 240.0, cx + 240.0):
			continue
		var cy := 596.0 + sin(float(i) * 1.9 + t * 0.16) * 26.0
		for k in 5:
			var rr := 52.0 + 10.0 * float(k % 3)
			Draw.ellipse(self, Vector2(cx + float(k - 2) * 56.0, cy + sin(float(k) * 2.1 + float(i)) * 9.0), rr, ry, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.042))
		Draw.ellipse(self, Vector2(cx + 30.0, cy - ry * 0.55), 64.0, ry * 0.60, Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.05))
	for i in 5:
		var cx2 := fposmod(1180.0 + float(i) * 470.0 + t * 1.4, Conf.CLOUD_W + 100.0) - 300.0
		if not Draw.vis(cam, cx2 - 300.0, cx2 + 300.0):
			continue
		var cy2 := 392.0 + sin(float(i) * 2.7 + t * 0.12) * 30.0
		for k in 3:
			Draw.ellipse(self, Vector2(cx2 + float(k - 1) * 96.0, cy2 + sin(float(k) * 1.7) * 6.0), 96.0, (20.0 + 8.0 * float(k)) / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.030))

# ---- 小河：蜿蜒 ----

func _water() -> void:
	if not Draw.vis(cam, Conf.RIVER_X0, Conf.RIVER_X1):
		return
	var x0 := maxf(Conf.RIVER_X0, cam - 80.0)
	var x1 := minf(Conf.RIVER_X1, cam + Conf.DW + 80.0)
	if x1 <= x0:
		return
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var xs := x0
	while xs < x1:
		top.append(Vector2(xs, Draw.river_far(xs)))
		bot.append(Vector2(xs, Draw.river_near(xs)))
		xs += Conf.RIVER_STEP
	top.append(Vector2(x1, Draw.river_far(x1)))
	bot.append(Vector2(x1, Draw.river_near(x1)))
	var poly := PackedVector2Array()
	poly.append_array(top)
	for i in range(bot.size() - 1, -1, -1):
		poly.append(bot[i])
	# 水色随季：夏微绿、冬转冷
	var wf := Color(0.865, 0.885, 0.885, 0.55)
	if season == 1:
		wf = Color(0.855, 0.885, 0.878, 0.56)
	elif season == 2:
		wf = Color(0.862, 0.878, 0.870, 0.55)
	elif season == 3:
		wf = Color(0.888, 0.908, 0.928, 0.62)
	draw_colored_polygon(poly, wf)
	draw_polyline(top, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.20), 2.0, true)
	draw_polyline(bot, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.26), 2.2, true)
	var gf := 0.55 if season == 3 else 1.0
	for k in 6:
		var f := 0.14 + float(k) * 0.14
		var spd2 := 3.2 + 2.4 * float(k % 3)
		var xx := 640.0 + fposmod(t * spd2 + float(k) * 90.0, 180.0)
		while xx < Conf.RIVER_X1 - 30.0:
			var y := lerpf(Draw.river_far(xx), Draw.river_near(xx), f)
			var ln := 20.0 + float(k) * 7.0
			draw_line(Vector2(xx, y + sin(xx * 0.02 + t * 0.8) * 1.5), Vector2(xx + ln, y), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.10 + 0.01 * float(k % 3)), 2.0)
			xx += 96.0
	for k in 16:
		var gx := 640.0 + fposmod(float(k) * 173.0 + t * (6.0 + float(k % 4)), Conf.RIVER_X1 - 640.0)
		if gx > Conf.RIVER_X1 - 20.0:
			continue
		if not Draw.vis(cam, gx - 12.0, gx + 12.0):
			continue
		var f2 := fposmod(float(k) * 0.37, 1.0)
		var gy := lerpf(Draw.river_far(gx), Draw.river_near(gx), f2)
		var ga := (0.06 + 0.10 * maxf(0.0, sin(t * 1.7 + float(k) * 2.3))) * gf
		draw_line(Vector2(gx, gy), Vector2(gx + 7.0, gy), Color(0.98, 0.99, 0.99, ga), 1.6)

func _sun_on_water() -> void:
	if not Draw.vis(cam, Conf.SUN_X - 120.0, Conf.SUN_X + 120.0):
		return
	var c := Conf.SEAL_C
	var smul := 1.0
	if season == 1:
		smul = 1.15
	elif season == 3:
		smul = 0.70
	var base := Draw.river_near(Conf.SUN_X) - 44.0
	Draw.ellipse(self, Vector2(Conf.SUN_X, base), 84.0, 20.0 / Draw.sy(), Color(c.r, c.g, c.b, 0.05 * smul))
	for k in 4:
		var yy := base - 24.0 + float(k) * 16.0
		var hw := 80.0 - float(k) * 17.0
		var wob := sin(t * 1.1 + float(k)) * 1.6
		var aa := (0.12 - float(k) * 0.024) * (0.85 + 0.15 * sin(t * 1.9 + float(k) * 1.3)) * smul
		draw_line(Vector2(Conf.SUN_X - hw + wob, yy), Vector2(Conf.SUN_X + hw + wob, yy), Color(c.r, c.g, c.b, aa), 2.0)

func _bridge() -> void:
	var bx := 1010.0
	if not Draw.vis(cam, bx - 70.0, bx + 70.0):
		return
	var gy := Draw.river_near(bx)
	var col := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.55)
	Draw.ellipse(self, Vector2(bx, gy - 22.0), 44.0, 9.0 / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.05))
	Draw.stroke(self, [Vector2(bx - 34.0, gy - 28.0), Vector2(bx - 15.0, gy - 42.0), Vector2(bx + 15.0, gy - 42.0), Vector2(bx + 34.0, gy - 28.0)], 3.0, 3.0, col)
	Draw.stroke(self, [Vector2(bx - 44.0, gy - 26.0), Vector2(bx - 16.0, gy - 41.0), Vector2(bx + 16.0, gy - 41.0), Vector2(bx + 44.0, gy - 26.0)], 4.0, 4.0, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.62))
	draw_line(Vector2(bx - 38.0, gy - 34.0), Vector2(bx - 16.0, gy - 48.0), col, 1.6, true)
	draw_line(Vector2(bx + 16.0, gy - 48.0), Vector2(bx + 38.0, gy - 34.0), col, 1.6, true)
	for k in 5:
		var px := bx - 30.0 + float(k) * 15.0
		var py := gy - 42.0 - absf(float(k) - 2.0) * 2.6
		draw_line(Vector2(px, py + 2.0), Vector2(px, py - 9.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.38), 1.4, true)
	for k in 3:
		var ryy := gy + 8.0 + float(k) * 7.0
		var hw2 := 34.0 - float(k) * 9.0
		draw_line(Vector2(bx - hw2 + sin(t * 1.1 + float(k)) * 1.5, ryy), Vector2(bx + hw2 + sin(t * 1.1 + float(k)) * 1.5, ryy), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.10 - float(k) * 0.02), 2.0)

func _shore() -> void:
	for i in 18:
		var cx := 640.0 + float(i) * 108.0 + sin(float(i) * 3.1) * 26.0
		if not Draw.vis(cam, cx, cx + 90.0):
			continue
		var y := Draw.river_near(cx) + 12.0 + sin(float(i) * 2.2) * 5.0
		Draw.stroke(self, [Vector2(cx, y), Vector2(cx + 66.0, y - 3.0)], 2.4, 0.9, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.14))
	for i2 in 24:
		var px2 := 660.0 + float(i2) * 96.0 + sin(float(i2) * 3.7) * 22.0
		if not Draw.vis(cam, px2 - 4.0, px2 + 4.0):
			continue
		var py2 := Draw.river_near(px2) + 15.0 + sin(float(i2) * 2.5) * 4.0
		Draw.ellipse(self, Vector2(px2, py2), 2.4 + float(i2 % 3) * 0.8, (1.4 + float(i2 % 2) * 0.5) / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.10 + 0.02 * float(i2 % 3)))
	for k in 3:
		var rx := 800.0 + float(k) * 520.0
		if not Draw.vis(cam, rx - 20.0, rx + 20.0):
			continue
		var rph := fposmod(t * 0.30 + float(k) * 0.33, 1.0)
		var rrad := 5.0 + rph * 15.0
		var ry2 := Draw.river_near(rx) + 3.0
		draw_arc(Vector2(rx, ry2), rrad, 0.0, TAU, 14, Color(0.90, 0.93, 0.93, 0.18 * (1.0 - rph)), 1.0)

func _reeds() -> void:
	_reed_clump(1856.0)
	_reed_clump(2340.0)
	for i in 3:
		var rx := 700.0 + float(i) * 13.0
		Draw.ellipse(self, Vector2(rx, Draw.river_near(rx) + 10.0), 7.0 + float(i) * 2.0, 4.0 / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.12))
	_reed_small(1896.0)
	_reed_small(2306.0)

func _reed_clump(x: float) -> void:
	if not Draw.vis(cam, x - 24.0, x + 30.0):
		return
	var gy := Draw.river_near(x) + 16.0
	for i in 7:
		var xx := x - 24.0 + float(i) * 8.5
		var h := 20.0 + fposmod(float(i) * 7.0, 16.0)
		var sw := sin(t * Conf.WIND_RATE * 1.3 + float(i) * 0.7) * 4.0
		Draw.stroke(self, [Vector2(xx, gy), Vector2(xx + sw, gy - h)], 1.8, 0.8, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.30))

func _reed_small(x: float) -> void:
	if not Draw.vis(cam, x - 18.0, x + 22.0):
		return
	var gy := Draw.river_near(x) + 14.0
	for i in 5:
		var xx := x - 16.0 + float(i) * 8.0
		var h := 10.0 + fposmod(float(i) * 5.0, 9.0)
		var sw := sin(t * Conf.WIND_RATE * 1.6 + float(i) * 1.1) * 3.0
		Draw.stroke(self, [Vector2(xx, gy), Vector2(xx + sw, gy - h)], 1.5, 0.7, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.24))

# ============ 树 ============

func _pine() -> void:
	if not Draw.vis(cam, 680.0, 900.0):
		return
	draw_set_transform_matrix(Draw.bend_xf(Vector2(792.0, 764.0), sin(t * Conf.WIND_RATE) * Conf.WIND_AMP / 120.0))
	var col := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.55)
	draw_colored_polygon(PackedVector2Array([Vector2(690, 762), Vector2(720, 742), Vector2(800, 738), Vector2(880, 752), Vector2(886, 762)]), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.06))
	Draw.stroke(self, [Vector2(792, 758), Vector2(783, 700), Vector2(789, 646)], 11.0, 5.0, col)
	Draw.stroke(self, [Vector2(786, 706), Vector2(752, 672), Vector2(736, 652)], 5.0, 1.8, col)
	Draw.stroke(self, [Vector2(788, 668), Vector2(824, 640), Vector2(842, 632)], 4.6, 1.6, col)
	for k in 5:
		var a := -2.6 + float(k) * 0.32
		var bx := 738.0 + cos(a) * 14.0
		var by := 654.0 + sin(a) * 10.0
		Draw.stroke(self, [Vector2(bx, by), Vector2(bx - 26.0, by - 8.0 + sin(a) * 8.0)], 3.0, 0.7, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.45))
	for k in 5:
		var a2 := -0.6 + float(k) * 0.30
		var bx2 := 840.0 + cos(a2) * 12.0
		var by2 := 634.0 + sin(a2) * 8.0
		Draw.stroke(self, [Vector2(bx2, by2), Vector2(bx2 + 24.0, by2 - 6.0 + sin(a2) * 8.0)], 3.0, 0.7, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.42))
	for k in 4:
		var bx3 := 789.0 + float(k - 2) * 7.0
		Draw.stroke(self, [Vector2(bx3, 650.0), Vector2(bx3 - 16.0 + float(k) * 8.0, 622.0)], 2.6, 0.7, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.40))
	for k in 7:
		var dx := 700.0 + float(k) * 26.0
		Draw.ellipse(self, Vector2(dx, 752.0 + sin(float(k) * 1.8) * 4.0), 2.0, 2.0 / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.28))
	for k in 3:
		var phn := fposmod(t * 0.045 + float(k) * 0.33, 1.0)
		var nx := 730.0 + float(k) * 54.0 + sin(phn * 6.0 + float(k) * 1.7) * 9.0
		var ny := 640.0 + phn * 112.0
		Draw.stroke(self, [Vector2(nx, ny), Vector2(nx + 2.4, ny + 3.4)], 1.2, 0.5, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.22 * (1.0 - phn)))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _trees() -> void:
	_tree(268.0, 768.0, 0.80, 0.6)   # 原在 636——被后山山脊挡住，v7 挪到卷首空纸上
	_tree(1852.0, 772.0, 0.66, 2.6)
	_tree(2620.0, 776.0, 0.90, 1.2)

func _tree(x: float, y: float, s: float, ph: float) -> void:
	if not Draw.vis(cam, x - 60.0, x + 60.0):
		return
	var h := 54.0 * s
	var sw := sin(t * Conf.WIND_RATE + ph) * Conf.WIND_AMP
	draw_set_transform_matrix(Draw.bend_xf(Vector2(x, y), sw / h))
	var col := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.50)
	var col2 := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.38)
	Draw.ellipse(self, Vector2(x, y + 2.0), 20.0 * s, 4.0 * s / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.07))
	Draw.stroke(self, [Vector2(x, y), Vector2(x - 1.0 * s, y - h * 0.55), Vector2(x + 2.0 * s, y - h)], 4.0 * s, 1.6 * s, col)
	for k in 3:
		var t2 := float(k)
		Draw.stroke(self, [Vector2(x + 1.0 * s, y - h * (0.42 + 0.14 * t2)), Vector2(x + (9.0 + 4.0 * t2) * s, y - h * (0.62 + 0.10 * t2))], 2.4 * s, 0.9 * s, col2)
	for k in 5:
		var t3 := float(k) / 4.0
		var nx := x - 17.0 * s + t3 * 34.0 * s
		var ny := y - h * (0.80 + 0.10 * sin(t3 * 5.0 + t * 0.6))
		Draw.stroke(self, [Vector2(nx, ny), Vector2(nx - 11.0 * s, ny - 8.0 * s)], 2.0 * s, 0.7 * s, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.32))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _bamboo_clump(x: float) -> void:
	if not Draw.vis(cam, x - 30.0, x + 50.0):
		return
	var sway := sin(t * Conf.WIND_RATE + x * 0.01) * 3.0
	var col := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.46)
	Draw.stroke(self, [Vector2(x + 14.0, 758.0), Vector2(x + 10.0 + sway, 600.0)], 4.0, 2.0, col)
	Draw.stroke(self, [Vector2(x + 32.0, 758.0), Vector2(x + 29.0 + sway, 620.0)], 3.4, 1.8, col)
	Draw.stroke(self, [Vector2(x, 760.0), Vector2(x - 2.0 + sway * 0.7, 650.0)], 3.0, 1.6, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.42))
	Draw.stroke(self, [Vector2(x + 46.0, 759.0), Vector2(x + 44.0 + sway * 1.2, 628.0)], 2.8, 1.4, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.40))
	for k in 10:
		var tt := 0.30 + 0.07 * float(k)
		var by := 758.0 - tt * 158.0
		var dir := 1.0 if (k % 2) == 0 else -1.0
		var swl := sin(t * Conf.WIND_RATE * 1.4 + float(k) * 0.7 + x * 0.01) * 1.6
		Draw.stroke(self, [Vector2(x + 14.0, by), Vector2(x + 14.0 + dir * (20.0 + 6.0 * float(k % 3)) + swl, by - 14.0)], 3.0, 0.8, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.38))

# ============ 路 / 山门 / 人 / 船 / 鱼 / 雾 / 鸟 ============

func _path() -> void:
	for i in 16:
		var tt := float(i) / 15.0
		var x := lerpf(660.0, 1490.0, tt)
		var y := lerpf(832.0, 782.0, tt) + sin(tt * 6.0) * 4.0
		if not Draw.vis(cam, x, x):
			continue
		draw_circle(Vector2(x, y), 2.2 - tt * 0.6, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.13 + tt * 0.07))
		if i % 4 == 1:
			Draw.stroke(self, [Vector2(x - 8.0, y + 5.5), Vector2(x + 8.0, y + 4.5)], 2.2, 1.8, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.10))
	for k in 3:
		var ph2 := fposmod(t * 0.11 + float(k) * 0.29, 1.0)
		var u2 := fposmod(float(k) * 0.37 + ph2 * 0.20, 1.0)
		var mx := lerpf(690.0, 1460.0, u2)
		var my := lerpf(830.0, 780.0, u2) - 6.0 - ph2 * 14.0
		if Draw.vis(cam, mx, mx):
			draw_circle(Vector2(mx, my), 0.9, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.10 * (1.0 - ph2)))

func _gate() -> void:
	if not Draw.vis(cam, 1480.0, 1720.0):
		return
	var col := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.62)
	var col2 := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.50)
	draw_line(Vector2(1512, 762), Vector2(1600, 762), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.10), 4.0)
	Draw.ellipse(self, Vector2(1530, 761.0), 9.0, 3.2 / Draw.sy(), Color(0.55, 0.52, 0.47, 0.55))
	Draw.ellipse(self, Vector2(1590, 761.0), 9.0, 3.2 / Draw.sy(), Color(0.55, 0.52, 0.47, 0.55))
	Draw.stroke(self, [Vector2(1530, 760), Vector2(1528, 640)], 9.0, 6.5, col)
	Draw.stroke(self, [Vector2(1590, 760), Vector2(1592, 640)], 9.0, 6.5, col)
	Draw.stroke(self, [Vector2(1516, 640), Vector2(1604, 640)], 7.0, 7.0, col)
	Draw.stroke(self, [Vector2(1522, 622), Vector2(1598, 622)], 5.0, 5.0, col2)
	Draw.stroke(self, [Vector2(1508, 614), Vector2(1560, 600), Vector2(1612, 614)], 7.5, 4.0, col)
	Draw.stroke(self, [Vector2(1516, 606), Vector2(1560, 594), Vector2(1604, 606)], 4.0, 2.2, col2)
	draw_rect(Rect2(1540, 644, 40, 15), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.90))
	draw_rect(Rect2(1540, 644, 40, 15), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.45), false, 1.5)
	draw_circle(Vector2(1560, 651.5), 4.2, Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b, 0.42))
	draw_circle(Vector2(1560, 651.5), 1.8, Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.95))
	for k in 2:
		var lx := 1533.0 + float(k) * 54.0
		var ly := 648.0
		var swy := sin(t * 0.85 + float(k) * 1.7) * 2.2
		draw_line(Vector2(lx, 641.0), Vector2(lx + swy, ly - 4.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.45), 1.0, true)
		var glow2 := 0.5 + 0.5 * sin(t * 2.0 + float(k) * 2.1)
		Draw.ellipse(self, Vector2(lx + swy, ly + 4.0), 12.0 + 1.6 * glow2, (9.6 + 1.4 * glow2) / Draw.sy(), Color(0.95, 0.72, 0.34, 0.05 + 0.04 * glow2))
		Draw.ellipse(self, Vector2(lx + swy, ly + 4.0), 4.6, 6.0 / Draw.sy(), Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b, 0.80))
		draw_line(Vector2(lx + swy - 3.4, ly - 0.5), Vector2(lx + swy + 3.4, ly - 0.5), Color(0.45, 0.35, 0.22, 0.85), 1.0, true)
		draw_line(Vector2(lx + swy - 3.4, ly + 9.5), Vector2(lx + swy + 3.4, ly + 9.5), Color(0.45, 0.35, 0.22, 0.85), 1.0, true)

func _figure() -> void:
	if not Draw.vis(cam, 1400.0, 1620.0):
		return
	var w := t * Conf.FIG_RATE
	var vel := cos(w)
	var moving := absf(vel)
	var facing := 1.0 if vel >= 0.0 else -1.0
	var step := sin(t * Conf.GAIT_RATE) * Conf.FIG_STEP * moving
	var bob := (1.0 - moving) * 0.6
	Draw.ellipse(self, Vector2(fig_x(), 759.0), 12.0, 3.0 / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.08))
	Draw.mini_person(self, fig_x(), 758.0, facing, step, bob, false)

func _path_walker() -> void:
	if not Draw.vis(cam, 620.0, 1520.0):
		return
	var w := t * Conf.ROAD_RATE
	var vel := cos(w)
	var moving := absf(vel)
	var s := 0.5 + sin(w) * 0.47
	var x := lerpf(660.0, 1490.0, s)
	var y := lerpf(832.0, 782.0, s) + sin(s * 6.0) * 4.0
	var facing := 1.0 if vel >= 0.0 else -1.0
	var step := sin(t * Conf.GAIT_RATE) * Conf.FIG_STEP * moving * 0.9
	var bob := (1.0 - moving) * 0.8
	Draw.ellipse(self, Vector2(x, y + 1.0), 10.0, 2.6 / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.07))
	Draw.mini_person(self, x, y, facing, step, bob, true)

func _boat() -> void:
	var swing := sin(t * Conf.ROW_RATE)
	var bx := 1120.0 + sin(t * 0.05) * 46.0
	var by := Draw.river_near(bx) - 36.0 + sin(t * 0.35) * 1.5 + swing * 0.5
	if not Draw.vis(cam, bx - 70.0, bx + 70.0):
		return
	var col := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.55)
	for k in 3:
		var wl := 26.0 + float(k) * 22.0
		var wy2 := by + 6.0 + float(k) * 3.4
		draw_line(Vector2(bx - 46.0 - wl, wy2), Vector2(bx - 22.0 - wl * 0.4, wy2 + 1.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.10 - float(k) * 0.025), 1.8)
	var bow_y := by + 4.0 + swing * 1.0
	var stern_y := by - 0.6 * swing
	Draw.stroke(self, [Vector2(bx - 34.0, stern_y), Vector2(bx, by + 4.0), Vector2(bx + 34.0, bow_y)], 4.0, 2.2, col)
	Draw.ellipse(self, Vector2(bx + 8.0, by - 12.0), 2.6, 2.6 / Draw.sy(), col)
	Draw.stroke(self, [Vector2(bx + 8.0, by - 9.0), Vector2(bx + 6.0, by - 1.0)], 4.0, 2.0, col)
	Draw.stroke(self, [Vector2(bx + 7.0, by - 7.0), Vector2(bx + 7.0 - swing * 3.0, by - 12.0 - swing * 2.0)], 1.8, 0.9, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.45))
	Draw.stroke(self, [Vector2(bx - 4.0 - swing * 6.0, by - 20.0 + swing * 3.0), Vector2(bx + 20.0 - swing * 8.0, by + 6.0 - swing * 5.0)], 1.6, 0.8, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.35))
	var wa := 0.07 + 0.05 * absf(swing)
	for k in 2:
		draw_line(Vector2(bx - 60.0 - float(k) * 24.0, by + 8.0 + float(k) * 4.0), Vector2(bx - 20.0 - float(k) * 20.0, by + 8.0 + float(k) * 4.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, wa), 2.0)
	var splash := clampf((absf(swing) - 0.86) / 0.14, 0.0, 1.0)
	if splash > 0.02:
		draw_arc(Vector2(bx - 20.0, by + 6.0), 5.0 + splash * 5.0, 0.0, TAU, 12, Color(0.85, 0.88, 0.88, 0.30 * splash), 1.0)

func _fish() -> void:
	var ph := fposmod(t + 6.0, 13.0)
	if ph > 1.2:
		return
	var fx := 1050.0 + sin(t * 0.02) * 60.0
	if not Draw.vis(cam, fx - 90.0, fx + 90.0):
		return
	var wy := Draw.river_near(fx) - 26.0
	var u := ph / 1.2
	if u < 0.5:
		var j := u / 0.5
		var bx := fx - 26.0 + j * 52.0
		var byy := wy - sin(j * PI) * 24.0
		Draw.ellipse(self, Vector2(bx, byy), 6.4, 2.4 / Draw.sy(), Color(0.28, 0.26, 0.32, 0.78))
		Draw.stroke(self, [Vector2(bx - 5.6, byy + 0.4), Vector2(bx - 9.4, byy - 2.4)], 1.6, 0.8, Color(0.28, 0.26, 0.32, 0.70))
		Draw.stroke(self, [Vector2(bx + 5.4, byy + 0.6), Vector2(bx + 8.6, byy + 2.8)], 1.4, 0.7, Color(0.28, 0.26, 0.32, 0.62))
	else:
		var j2 := (u - 0.5) / 0.5
		draw_arc(Vector2(fx + 26.0, wy + 3.0), 3.0 + j2 * 11.0, 0.0, TAU, 14, Color(0.85, 0.88, 0.88, 0.28 * (1.0 - j2)), 1.1)
		draw_arc(Vector2(fx - 26.0, wy + 3.0), 2.0 + j2 * 7.0, 0.0, TAU, 12, Color(0.85, 0.88, 0.88, 0.22 * (1.0 - j2)), 1.0)

func _mist() -> void:
	var ry1 := 72.0 / Draw.sy()
	var ry2 := 110.0 / Draw.sy()
	for i in 3:   # v62：6 → 3（雾团减半）
		var cx := fposmod(float(i) * 340.0 + t * 2.2, 2850.0) + 50.0
		if not Draw.vis(cam, cx - 240.0, cx + 240.0):
			continue
		var cy := 560.0 + sin(float(i) * 1.7 + t * 0.25) * 60.0
		for k in 3:
			Draw.ellipse(self, Vector2(cx + float(k - 1) * 80.0, cy + sin(float(k) * 2.0 + t * 0.5) * 7.0), 72.0, ry1, Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.05))
	for i in 2:   # v62：3 → 2
		var cx2 := fposmod(float(i) * 700.0 + t * 3.8 + 200.0, 2850.0) + 50.0
		if not Draw.vis(cam, cx2 - 200.0, cx2 + 200.0):
			continue
		Draw.ellipse(self, Vector2(cx2, 720.0), 110.0, ry2, Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.07))
	for i in 2:   # v62：3 → 2
		var cx3 := fposmod(float(i) * 850.0 - t * 1.1 + 400.0, 2850.0) + 50.0
		if not Draw.vis(cam, cx3 - 220.0, cx3 + 220.0):
			continue
		var cy3 := 640.0 + sin(float(i) * 2.3 + t * 0.30) * 24.0
		for k in 2:
			Draw.ellipse(self, Vector2(cx3 + float(k) * 70.0 - 35.0, cy3 + float(k) * 10.0), 96.0 - float(k) * 22.0, (26.0 - float(k) * 6.0) / Draw.sy(), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.045))

func _birds() -> void:
	var ph := fposmod(t, 26.0)
	if ph > 10.0:
		return
	var bx := 580.0 + (ph / 10.0) * 2000.0
	for i in 2:   # v62：3 → 2（两折翅鸟，一对就够）
		var x := bx - float(i) * 30.0
		var y := 248.0 + float(i) * 12.0 + sin(t * 0.8 + float(i)) * 5.0
		if not Draw.vis(cam, x - 40.0, x + 40.0):
			continue
		var flap := sin(t * 6.0 + float(i) * 1.7) * 3.5
		Draw.stroke(self, [Vector2(x - 9.0, y + 3.0), Vector2(x - 4.5, y + 0.6 + flap * 0.5), Vector2(x, y - 2.0 + flap)], 2.4, 1.2, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.48))
		Draw.stroke(self, [Vector2(x + 9.0, y + 3.0), Vector2(x + 4.5, y + 0.6 + flap * 0.5), Vector2(x, y - 2.0 + flap)], 2.4, 1.2, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.48))

func _geese() -> void:
	var ph := fposmod(t + 13.0, Conf.GOOSE_PERIOD)
	if ph > 12.0:
		return
	var p := ph / 12.0
	var fx := 200.0 + p * 2700.0
	var fy := 300.0 + sin(ph * 0.5) * 9.0
	if not Draw.vis(cam, fx - 160.0, fx + 40.0):
		return
	for i in 3:   # v62（用户："太多无用的了"）：雁阵 5 → 3 只
		var side := 1.0 if (i % 2) == 1 else -1.0
		var rank := float(i + 1) * 0.5
		var x := fx - rank * 22.0
		var y := fy + side * rank * 13.0
		var flap := sin(t * 5.0 + float(i) * 1.3) * 3.0
		Draw.stroke(self, [Vector2(x - 8.0, y + 2.5), Vector2(x, y - 1.5 + flap), Vector2(x + 8.0, y + 2.5)], 2.2, 0.9, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.46))
	draw_circle(Vector2(fx - 6.0, fy - 1.0), 1.2, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.50))

# ============ 四季环境层（menu_sketch 每帧喂 season） ============

func _season_air() -> void:
	match season:
		0:
			_spring_fluff()
		1:
			_summer_dragonflies()
		2:
			_autumn_leaves()
		3:
			_winter_snow()
			_winter_ground()

# 春：柳絮（小白点，慢慢横着漂）
func _spring_fluff() -> void:
	for i in 5:   # v62：9 → 5
		var p := fposmod(t * (0.018 + 0.006 * float(i % 3)) + float(i) * 0.113, 1.0)
		var x := 40.0 + p * (Conf.STRIP_W - 80.0)
		if not Draw.vis(cam, x - 20.0, x + 20.0):
			continue
		var y := 430.0 + sin(p * 9.0 + float(i) * 1.7) * 46.0 + float(i % 3) * 62.0
		var r := 1.4 + 0.6 * float(i % 2)
		var a := maxf(0.10, 0.34 + 0.18 * sin(t * 0.9 + float(i)))
		Draw.ellipse(self, Vector2(x, y), r + 1.3, (r + 1.3) / Draw.sy(), Color(0.97, 0.96, 0.93, a * 0.45))
		draw_circle(Vector2(x, y), r, Color(0.99, 0.98, 0.95, a))

# 夏：蜻蜓（贴水打转，翅膀高频抖）
func _summer_dragonflies() -> void:
	var bases: Array = [830.0, 1060.0, 1560.0]   # v62：5 → 3（蜻蜓）
	for i in bases.size():
		var bx: float = bases[i]
		var x := bx + sin(t * 0.9 + float(i) * 1.4) * 54.0
		if not Draw.vis(cam, x - 30.0, x + 30.0):
			continue
		var y := Draw.river_near(x) - 18.0 + sin(t * 2.1 + float(i) * 2.0) * 10.0
		var flap := sin(t * 18.0 + float(i)) * 1.6
		var c := Color(0.24, 0.27, 0.25, 0.55)
		draw_line(Vector2(x - 5.0, y), Vector2(x + 5.0, y), c, 1.3, true)
		draw_line(Vector2(x - 1.0, y - 0.6), Vector2(x - 4.2, y - 3.4 - flap), Color(0.55, 0.62, 0.60, 0.42), 1.0, true)
		draw_line(Vector2(x - 1.0, y + 0.6), Vector2(x - 4.6, y + 2.6 + flap), Color(0.55, 0.62, 0.60, 0.36), 1.0, true)
		draw_circle(Vector2(x + 5.6, y - 0.6), 1.0, Color(0.24, 0.27, 0.25, 0.50))

# 秋：金叶旋落
func _autumn_leaves() -> void:
	for i in 6:   # v62：12 → 6
		var p := fposmod(t * (0.030 + 0.008 * float(i % 4)) + float(i) * 0.137, 1.0)
		var x := 80.0 + fposmod(float(i) * 227.0 + sin(p * 7.0 + float(i)) * 30.0, Conf.STRIP_W - 160.0)
		if not Draw.vis(cam, x - 16.0, x + 16.0):
			continue
		var y := 470.0 + p * 350.0
		var rot := sin(p * 10.0 + float(i) * 2.2) * 1.8
		var a := 0.34 * sin(PI * p) + 0.10
		var cc := Color(0.74, 0.56, 0.24, a)
		if (i % 2) == 1:
			cc = Color(0.58, 0.36, 0.20, a)
		Draw.stroke(self, [Vector2(x, y), Vector2(x + 3.4 + rot, y + 4.0 - rot * 0.5)], 2.2, 0.6, cc)
		Draw.stroke(self, [Vector2(x + 0.6, y + 0.6), Vector2(x - 1.8 + rot * 0.7, y + 3.2)], 1.3, 0.5, Color(cc.r, cc.g, cc.b, cc.a * 0.7))

# 冬：落雪 + 地上薄白
func _winter_snow() -> void:
	for i in 10:   # v62：24 → 10（雪还是会下，不再糊满屏）
		var spd := 0.035 + 0.012 * float(i % 3)
		var p := fposmod(t * spd + float(i) * 0.183, 1.0)
		var x := 30.0 + fposmod(float(i) * 197.0, Conf.STRIP_W - 60.0) + sin(p * 6.0 + float(i) * 1.3) * 16.0
		if not Draw.vis(cam, x - 10.0, x + 10.0):
			continue
		var y := 360.0 + p * 470.0
		var r := 1.0 + 0.7 * float(i % 3)
		draw_circle(Vector2(x, y), r, Color(0.97, 0.97, 0.99, 0.44))
		draw_circle(Vector2(x - r * 0.6, y - r * 0.6), r * 0.5, Color(0.99, 0.99, 1.0, 0.30))

func _winter_ground() -> void:
	for i in 10:
		var x := 120.0 + float(i) * 296.0 + sin(float(i) * 3.3) * 40.0
		if not Draw.vis(cam, x - 90.0, x + 90.0):
			continue
		var y := 812.0 + sin(float(i) * 2.1) * 8.0
		Draw.ellipse(self, Vector2(x, y), 78.0, 12.0 / Draw.sy(), Color(0.97, 0.97, 0.99, 0.10))
	Draw.stroke(self, [Vector2(680.0, 828.0), Vector2(1080.0, 806.0), Vector2(1460.0, 782.0)], 6.0, 2.4, Color(0.97, 0.97, 0.99, 0.16))
