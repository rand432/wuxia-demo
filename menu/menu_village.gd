extends Node2D
# ============================================================
# menu_village.gd —— 村子层 v13（后山落下一只隼）
# v13：后山加青隼——白狐入队后，最高的那棵松梢上落着一只隼（会转头/理羽）；
#      青隼也入队后松梢空了，只在松脚留一根断羽。状态由 menu_sketch 每帧喂。
# v12：山洞做完任务就消失——cave_opened 置真后 _cave() 整段不画（连"开了"的
# v12：山洞做完任务就消失——cave_opened 置真后 _cave() 整段不画（连"开了"的
#      凉光/滴水一起删，留着也是死代码）。雾不动：雾的开关还是 show_cave。
# v11：四季换装（桃花/花雨/田色/雪）。
# v11：由 menu_sketch 喂 season（0春 1夏 2秋 3冬），村子跟着换装：
#   ① 桃花：春粉 / 夏绿（叶）/ 秋赭 / 冬落雪团（枝上不再是粉花）
#   ② 花雨：春夏秋换色（粉/绿/赭），冬天停
#   ③ 屋瓦与松枝：冬天压一层白雪
#   ④ 田地作物颜色随季（夏浓绿 / 秋赭黄 / 冬苍灰）
#   ⑤ 冬天加：地上积雪软白、路上一道压实白、前层落雪（盖过屋顶）
#   其余（房子、家具、云雾、解锁）一字未动。
# v10 旧注：房子石基/曲檐/瓦垄/门框；建筑家具；两段式动画。
# 注：村里一律不写字；状态位与 v10 完全一致，menu_sketch 只多喂一个 season。
# ============================================================

const Conf := preload("res://menu/menu_conf.gd")
const Draw := preload("res://menu/menu_draw.gd")
const Build := preload("res://menu/data_build.gd")

# 建筑落点（跟 menu_sketch 里的「记号」坐标一致；已对过 data_build 的房/田/篱笆/树）
const POS := {
	"cave": Vector2(470.0, 712.0),      # 左头荒坡——无房无田
	"winery": Vector2(1040.0, 852.0),   # 最前排：房(979..1021)和田(1076..1170)中间的正前方
	"shop": Vector2(1716.0, 850.0),     # 篱笆(1612..1718)前、桃树(1700)下
	"dange": Vector2(1872.0, 800.0),    # 房(1929..1975)左边留檐
	"treasure": Vector2(2140.0, 796.0), # 与 1980..2110 / 2170..2310 两块田贴边
}

var t := 0.0
var cam := 0.0
var stage := 0

# ---- 状态（menu_sketch 每帧喂） ----
var show_cave := false
var cave_opened := false
var show_winery := false
var show_shop := false
var show_dange := false
var dange_busy := false
var show_treasure := false
var disciple_joined := false
var dange_tender := ""     # 看火的人（"" = 没人）
var backhill_open := false # 后山解锁（村况 ≥ 1）
var pet_joined := false    # 白狐入队没
var sun_joined := false    # 青隼入队没（menu_sketch 喂：GameState.pet_has("qing_sun")）
var season := 0            # 0春 1夏 2秋 3冬（menu_sketch 喂）

# 云开的过渡时刻（-1 = 没开；≥0 = 解开的那一帧的 t）
var _bh_t := -1.0
var _cv_t := -1.0

func _draw() -> void:
	# 由远及近
	for it in Build.FIELDS:
		_one_field(it)
	for it in Build.HOUSES:
		_one_house(it)
	for it in Build.FENCES:
		_one_fence(it)
	_yard()
	_stone_table()
	_backhill()
	_cave()
	_winery()
	_shop()
	_dange()
	_treasure()
	_disciple()
	_peach_all()
	_chickens()
	_petals()
	_winter_dress()
	_fog_left()

# ============ 田 ============

func _crop_ink() -> Color:
	if season == 1:
		return Color(0.30, 0.42, 0.22)
	if season == 2:
		return Color(0.62, 0.46, 0.18)
	if season == 3:
		return Color(0.58, 0.60, 0.64)
	return Color(Conf.INK.r, Conf.INK.g, Conf.INK.b)

func _one_field(f: Dictionary) -> void:
	var x0 := float(f["x0"])
	var x1 := float(f["x1"])
	if not Draw.vis(cam, x0, x1):
		return
	var y0 := float(f["y0"])
	var y1 := float(f["y1"])
	var inset := 7.0
	var pts := PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0),
		Vector2(x1 - inset, y1), Vector2(x0 + inset, y1)])
	var done := stage >= int(f["at"])
	if done:
		if bool(f["wet"]):
			draw_colored_polygon(pts, Color(0.845, 0.865, 0.875, 0.45))
		else:
			draw_colored_polygon(pts, Color(0.815, 0.785, 0.700, 0.35))
	else:
		draw_colored_polygon(pts, Color(0.790, 0.762, 0.690, 0.30))
	var bp := pts
	bp.append(pts[0])
	draw_polyline(bp, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.22 if done else 0.14), 1.6, true)
	var ci := _crop_ink()
	if not done:
		for k in 9:
			var tt := float(k) / 8.0
			var xx := lerpf(x0 + 10.0, x1 - 10.0, tt)
			var yy := lerpf(y1 - 5.0, y0 + 8.0, fposmod(tt * 1.7, 1.0))
			Draw.stroke(self, [Vector2(xx, yy), Vector2(xx - 3.0 + sin(xx * 0.5) * 2.0, yy - 5.5)], 1.2, 0.5, Color(ci.r, ci.g, ci.b, 0.22))
		return
	var rows := int(f["rows"])
	for i in rows:
		var tt2 := (float(i) + 1.0) / (float(rows) + 1.0)
		var yy2 := lerpf(y0, y1, tt2)
		var ins := inset * tt2
		Draw.stroke(self, [Vector2(x0 + ins, yy2), Vector2(x1 - ins, yy2)], 1.5, 1.5, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.09 + 0.07 * tt2))
		var n := maxi(3, int((x1 - x0 - ins * 2.0) / 15.0))
		for k in n:
			var xx2 := x0 + ins + 6.0 + float(k) * ((x1 - x0 - ins * 2.0 - 12.0) / maxf(float(n - 1), 1.0))
			var hh := 2.4 + tt2 * 2.4
			Draw.stroke(self, [Vector2(xx2, yy2), Vector2(xx2 - 1.0 + sin(xx2 * 0.7) * 1.2, yy2 - hh)], 1.1, 0.5, Color(ci.r, ci.g, ci.b, 0.16 + 0.10 * tt2))
	# 风过田垄：一道浅浅的亮痕，从这头扫到那头
	var wph := fposmod(t * 0.20 + x0 * 0.013, 1.0)
	var wx := lerpf(x0, x1, wph)
	Draw.stroke(self, [
		Vector2(maxf(wx - 30.0, x0), lerpf(y0, y1, 0.46)),
		Vector2(wx, lerpf(y0, y1, 0.56)),
		Vector2(minf(wx + 30.0, x1), lerpf(y0, y1, 0.46))], 2.2, 1.2, Color(0.98, 0.96, 0.88, 0.24))

# ============ 房子：三种样子 ============

func _one_house(h: Dictionary) -> void:
	var x := float(h["x"])
	var y := float(h["y"])
	var w := float(h["w"])
	if not Draw.vis(cam, x - w * 1.6, x + w * 1.6):
		return
	var hh := float(h["h"])
	var roof := float(h["roof"])
	var at := int(h["at"])
	var st := 0
	if stage >= at:
		st = 2
	elif stage >= 1 and stage == at - 1:
		st = 1
	if st == 2:
		_house_done(x, y, w, hh, roof, bool(h["chim"]), float(h["ph"]), bool(h["tile"]))
	elif st == 1:
		_frame(x, y, w, hh, roof)
	else:
		_ruin(x, y, w, hh)

# 断墙焦木：地上焦痕 + 残墙（锯牙顶）+ 斜插焦梁 + 碎砖
func _ruin(x: float, y: float, w: float, h: float) -> void:
	var hw := w * 0.5
	var char_c := Color(0.13, 0.11, 0.10, 0.78)
	Draw.ellipse(self, Vector2(x, y + 2.0), hw * 1.35, 5.0 / Draw.sy(), Color(0.22, 0.19, 0.17, 0.20))
	Draw.ellipse(self, Vector2(x - hw * 0.35, y + 1.0), hw * 0.70, 3.5 / Draw.sy(), Color(0.18, 0.15, 0.13, 0.16))
	_stub(x - hw, y, w * 0.44, h * 0.46)
	_stub(x + hw * 0.16, y, w * 0.34, h * 0.30)
	Draw.stroke(self, [Vector2(x - hw * 0.45, y - h * 0.30), Vector2(x - hw * 0.02, y - h * 1.18)], 4.4, 2.2, char_c)
	Draw.stroke(self, [Vector2(x + hw * 0.40, y - h * 0.16), Vector2(x - hw * 0.30, y - h * 0.90)], 3.4, 1.8, char_c)
	Draw.ellipse(self, Vector2(x - hw * 0.02, y - h * 1.18), 2.2, 2.2 / Draw.sy(), char_c)
	# 地上碎砖碎瓦
	for k in 6:
		var px := x - hw * 0.9 + float(k) * (w * 0.30)
		var py := y + 1.0 - fposmod(float(k) * 2.7, 3.0)
		draw_rect(Rect2(px, py - 1.6, 3.4, 2.2), Color(0.34, 0.30, 0.26, 0.42))

func _stub(x0: float, y: float, w: float, h: float) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(x0, y))
	pts.append(Vector2(x0 + w, y))
	var n := 4
	for i in n + 1:
		var tt := 1.0 - float(i) / float(n)
		pts.append(Vector2(x0 + w * tt, y - h * (0.70 + 0.30 * absf(sin(float(i) * 2.3 + x0 * 0.07)))))
	draw_colored_polygon(pts, Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.88))
	var cl := pts
	cl.append(pts[0])
	draw_polyline(cl, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.45), 1.3, true)
	draw_line(Vector2(x0, y - h * 0.78), Vector2(x0 + w, y - h * 0.66), Color(0.14, 0.12, 0.11, 0.30), 2.0, true)

# 屋架：四根新柱 + 顶梁 + 斜撑 + 绑绳结 + 地上木料
func _frame(x: float, y: float, w: float, h: float, roof: float) -> void:
	var hw := w * 0.5
	var wood := Color(0.60, 0.48, 0.32, 0.80)
	var wood2 := Color(0.52, 0.41, 0.27, 0.60)
	var top := y - h * 1.30
	Draw.ellipse(self, Vector2(x, y + 2.0), hw * 1.25, 4.5 / Draw.sy(), Color(0.24, 0.20, 0.17, 0.10))
	Draw.stroke(self, [Vector2(x - hw, y), Vector2(x - hw, top + h * 0.16)], 3.6, 2.8, wood)
	Draw.stroke(self, [Vector2(x + hw, y), Vector2(x + hw, top + h * 0.16)], 3.6, 2.8, wood)
	Draw.stroke(self, [Vector2(x - hw * 0.34, y), Vector2(x - hw * 0.34, top)], 3.0, 2.2, wood2)
	Draw.stroke(self, [Vector2(x + hw * 0.34, y), Vector2(x + hw * 0.34, top)], 3.0, 2.2, wood2)
	Draw.stroke(self, [Vector2(x - hw, top + h * 0.16), Vector2(x + hw, top + h * 0.16)], 4.4, 4.4, wood)
	Draw.stroke(self, [Vector2(x - hw, top + h * 0.16), Vector2(x, top - roof * 0.25)], 3.0, 1.8, wood2)
	Draw.stroke(self, [Vector2(x + hw, top + h * 0.16), Vector2(x, top - roof * 0.25)], 3.0, 1.8, wood2)
	Draw.stroke(self, [Vector2(x - hw, y - h * 0.22), Vector2(x - hw * 0.34, top + h * 0.24)], 2.0, 1.4, wood2)
	for k in 3:
		Draw.stroke(self, [Vector2(x + hw * 0.95, y - float(k) * 3.6), Vector2(x + hw * 1.55, y - 3.0 - float(k) * 3.6)], 3.2, 3.2, Color(0.56, 0.44, 0.29, 0.55))
	# 梁柱接头：绑绳结（叉叉）
	for px in [x - hw, x + hw]:
		draw_line(Vector2(px - 3.2, top + h * 0.16 + 1.6), Vector2(px + 3.2, top + h * 0.16 - 1.6), Color(0.36, 0.27, 0.18, 0.55), 1.2, true)
		draw_line(Vector2(px - 3.2, top + h * 0.16 - 1.6), Vector2(px + 3.2, top + h * 0.16 + 1.6), Color(0.36, 0.27, 0.18, 0.55), 1.2, true)

# 曲檐的取点：二次贝塞尔（a=檐口，b=中控，c=屋脊背）
func _slope_p(s: float, a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var u := 1.0 - s
	return u * u * a + 2.0 * u * s * b + s * s * c

# 成屋（第十版）：石基 + 墙裙 + 墙角 + 檐影 + 曲檐 + 瓦垄 + 烟囱 + 门框门槛 + 窗台
func _house_done(x: float, y: float, w: float, h: float, roof: float, chimney: bool, ph: float, tile: bool) -> void:
	var ink := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.62)
	var ink2 := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.40)
	var hw := w * 0.5
	var rt := y - h
	# 地基：两层软影 + 一条石基座（房子"坐"下去，不再飘）
	Draw.ellipse(self, Vector2(x, y + 2.0), hw * 1.44, 5.4 / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.055))
	Draw.ellipse(self, Vector2(x, y + 2.2), hw * 1.16, 3.4 / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.11))
	draw_rect(Rect2(x - hw * 1.06, y - 4.6, w * 1.12, 4.6), Color(0.60, 0.57, 0.52, 0.92))
	draw_line(Vector2(x - hw * 1.06, y - 4.6), Vector2(x + hw * 1.06, y - 4.6), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.28), 1.0, true)
	draw_line(Vector2(x - hw * 1.06, y - 0.4), Vector2(x + hw * 1.06, y - 0.4), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.14), 0.9, true)
	# 墙：纸墙 + 墙裙 + 左右墙角线
	draw_rect(Rect2(x - hw, rt, w, h), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.96))
	draw_rect(Rect2(x - hw, y - h * 0.30, w, h * 0.30), Color(0.80, 0.76, 0.68, 0.26))
	draw_line(Vector2(x - hw, rt + 1.0), Vector2(x - hw, y - 4.6), ink2, 1.4, true)
	draw_line(Vector2(x + hw, rt + 1.0), Vector2(x + hw, y - 4.6), ink2, 1.4, true)
	# 檐下暗带（屋顶压下来的阴影）
	draw_rect(Rect2(x - hw * 1.02, rt + 0.5, w * 1.04, maxf(3.6, h * 0.10)), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.10))
	# 屋顶：曲檐（两端微翘）
	var l_e := Vector2(x - hw * 1.34, rt + 3.0)
	var l_m := Vector2(x - hw * 0.78, rt - roof * 0.60)
	var pk := Vector2(x, rt - roof)
	var r_m := Vector2(x + hw * 0.78, rt - roof * 0.60)
	var r_e := Vector2(x + hw * 1.34, rt + 3.0)
	var rp := PackedVector2Array([l_e, l_m, pk, r_m, r_e])
	if tile:
		draw_colored_polygon(rp, Color(0.34, 0.29, 0.25, 0.86))
	else:
		draw_colored_polygon(rp, Color(0.70, 0.63, 0.45, 0.64))
	Draw.stroke(self, [l_e, l_m, pk, r_m, r_e], 2.8, 2.8, ink)
	draw_line(l_e + Vector2(0.0, 3.4), r_e + Vector2(0.0, 3.4), ink, 1.8, true)
	draw_line(l_e + Vector2(0.0, 1.0), r_e + Vector2(0.0, 1.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.22), 1.1, true)
	# 正脊（脊头两角微翘）
	draw_line(pk + Vector2(-6.5, -1.0), pk + Vector2(6.5, -1.0), ink, 2.8, true)
	Draw.stroke(self, [pk + Vector2(-6.5, -0.5), pk + Vector2(-11.0, -3.6)], 2.2, 1.2, ink)
	Draw.stroke(self, [pk + Vector2(6.5, -0.5), pk + Vector2(11.0, -3.6)], 2.2, 1.2, ink)
	# 瓦垄（瓦顶）/ 草茎（草顶）：沿两坡排
	if tile:
		for k in 7:
			var u := 0.10 + 0.13 * float(k)
			var pl := _slope_p(u, l_e, l_m, pk)
			var pr := _slope_p(u, r_e, r_m, pk)
			draw_line(pl + Vector2(-1.2, 0.4), pl + Vector2(-3.6, 3.4), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.20), 1.1, true)
			draw_line(pr + Vector2(1.2, 0.4), pr + Vector2(3.6, 3.4), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.20), 1.1, true)
	else:
		for k in 9:
			var u2 := 0.08 + 0.10 * float(k)
			var p2 := _slope_p(u2, l_e, l_m, pk)
			var p3 := _slope_p(u2, r_e, r_m, pk)
			draw_line(p2 + Vector2(-1.0, 1.0), p2 + Vector2(-4.4, 4.4), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.16), 1.0, true)
			draw_line(p3 + Vector2(1.0, 1.0), p3 + Vector2(4.4, 4.4), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.16), 1.0, true)
	# 冬：屋脊屋坡压雪（春来自己化）
	if season == 3:
		Draw.stroke(self, [l_e + Vector2(2.0, -2.0), l_m + Vector2(0.0, -2.8), pk + Vector2(0.0, -2.6), r_m + Vector2(0.0, -2.8), r_e + Vector2(-2.0, -2.0)], 3.4, 2.4, Color(0.97, 0.97, 0.99, 0.82))
		Draw.ellipse(self, Vector2(pk.x, pk.y - 4.8), 7.0, 3.2 / Draw.sy(), Color(0.97, 0.97, 0.99, 0.78))
	# 烟囱：砖砌短囱（有囱的房子，烟从囱口出）
	var smoke_x := x + hw * 0.42
	var smoke_y := rt - roof * 0.30
	if chimney:
		var cp := _slope_p(0.30, r_e, r_m, pk)
		draw_rect(Rect2(cp.x - 4.2, cp.y - 13.0, 8.4, 13.0), Color(0.40, 0.35, 0.31, 0.95))
		draw_line(Vector2(cp.x - 4.2, cp.y - 8.0), Vector2(cp.x + 4.2, cp.y - 8.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.22), 0.9, true)
		draw_rect(Rect2(cp.x - 5.6, cp.y - 15.4, 11.2, 3.0), Color(0.46, 0.41, 0.36, 0.95))
		smoke_x = cp.x
		smoke_y = cp.y - 16.0
	# 门：门楣 + 门柱 + 门扇（内凹）+ 门环 + 门槛
	var dw := maxf(9.0, w * 0.17)
	var dh := h * 0.62
	draw_rect(Rect2(x - dw * 0.5 - 2.2, y - dh - 2.2, dw + 4.4, 2.6), ink2)
	draw_rect(Rect2(x - dw * 0.5 - 2.2, y - dh, 1.9, dh - 3.2), ink2)
	draw_rect(Rect2(x + dw * 0.5 + 0.3, y - dh, 1.9, dh - 3.2), ink2)
	draw_rect(Rect2(x - dw * 0.5, y - dh, dw, dh - 3.2), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.24))
	draw_rect(Rect2(x - dw * 0.5, y - dh, dw, dh - 3.2), ink, false, 1.0)
	draw_line(Vector2(x, y - dh + 1.0), Vector2(x, y - 4.4), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.34), 0.9, true)
	draw_circle(Vector2(x - dw * 0.20, y - dh * 0.52), 0.9, Color(0.72, 0.58, 0.22, 0.70))
	draw_circle(Vector2(x + dw * 0.20, y - dh * 0.52), 0.9, Color(0.72, 0.58, 0.22, 0.70))
	draw_rect(Rect2(x - dw * 0.86, y - 3.0, dw * 1.72, 3.0), Color(0.60, 0.56, 0.50, 0.92))
	draw_line(Vector2(x - dw * 0.86, y - 3.0), Vector2(x + dw * 0.86, y - 3.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.22), 0.9, true)
	# 窗（田字格 + 窗台）
	var wwd := maxf(6.0, w * 0.14)
	var wy := y - h * 0.76
	_window(x - hw * 0.66, wy, wwd, ink2)
	if w >= 54.0:
		_window(x + hw * 0.30, wy, wwd, ink2)
	# 炊烟（第三段起冒烟）
	if chimney and stage >= 3:
		_smoke(smoke_x, smoke_y, ph)

func _window(wx: float, wy: float, wwd: float, ink2: Color) -> void:
	draw_rect(Rect2(wx, wy, wwd, wwd * 0.88), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.60))
	draw_rect(Rect2(wx, wy, wwd, wwd * 0.88), ink2, false, 1.1)
	draw_line(Vector2(wx + wwd * 0.5, wy + 1.0), Vector2(wx + wwd * 0.5, wy + wwd * 0.88 - 1.0), ink2, 0.8, true)
	draw_line(Vector2(wx + 1.0, wy + wwd * 0.44), Vector2(wx + wwd - 1.0, wy + wwd * 0.44), ink2, 0.8, true)
	draw_line(Vector2(wx - 1.4, wy + wwd * 0.88), Vector2(wx + wwd + 1.4, wy + wwd * 0.88), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.30), 1.2, true)

# 炊烟：一缕细线（不断）+ 六团渐散（带横向漂移）
func _smoke(x: float, y: float, ph: float) -> void:
	Draw.stroke(self, [
		Vector2(x, y),
		Vector2(x + sin(t * 0.9 + ph) * 6.0, y - 34.0),
		Vector2(x + sin(t * 0.9 + ph + 0.7) * 10.0, y - 72.0),
		Vector2(x + sin(t * 0.9 + ph + 1.4) * 14.0, y - 108.0)], 2.2, 0.6, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.07))
	for k in 6:
		var sw := fposmod(t * Conf.SMOKE_RATE * 0.75 + float(k) * 0.167 + ph, 1.0)
		var rr := 3.4 + sw * 11.0
		var xx := x + sin(sw * 2.6 + ph * 6.0 + float(k)) * (7.0 + sw * 9.0)
		var yy := y - sw * 132.0
		var a := (1.0 - sw) * (0.13 if k % 2 == 0 else 0.08)
		Draw.ellipse(self, Vector2(xx, yy), rr, rr / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, a))

# ============ 篱笆 ============

func _one_fence(f: Dictionary) -> void:
	var x0 := float(f["x0"])
	var x1 := float(f["x1"])
	if not Draw.vis(cam, x0, x1):
		return
	var y := float(f["y"])
	if stage >= int(f["at"]):
		var col := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.34)
		draw_line(Vector2(x0, y - 12.0), Vector2(x1, y - 12.0), col, 1.6, true)
		draw_line(Vector2(x0, y - 4.0), Vector2(x1, y - 4.0), col, 1.4, true)
		var n := int((x1 - x0) / 13.0)
		for k in n:
			var px := x0 + 4.0 + float(k) * 13.0
			draw_line(Vector2(px, y), Vector2(px, y - 14.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.30), 1.4, true)
	else:
		for k in 5:
			var px2 := x0 + (x1 - x0) * float(k) / 4.0
			var lean := sin(float(k) * 2.1 + x0 * 0.03) * 2.4
			Draw.stroke(self, [Vector2(px2, y), Vector2(px2 + lean, y - 10.0 - fposmod(float(k) * 3.0, 5.0))], 1.6, 1.1, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.26))
		Draw.stroke(self, [Vector2(x0 + 5.0, y - 9.0), Vector2(x0 + (x1 - x0) * 0.40, y - 6.0)], 1.3, 1.0, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.20))

# ============ 打谷场 / 石桌 ============

func _yard() -> void:
	var x := float(Build.YARD["x"])
	var y := float(Build.YARD["y"])
	if not Draw.vis(cam, x - 120.0, x + 120.0):
		return
	if stage >= int(Build.YARD["at"]):
		Draw.ellipse(self, Vector2(x, y), 84.0, 22.0 / Draw.sy(), Color(0.80, 0.755, 0.660, 0.40))
		Draw.ellipse(self, Vector2(x, y), 60.0, 15.0 / Draw.sy(), Color(0.78, 0.735, 0.640, 0.28))
		_hay(x - 48.0, y - 6.0, 1.0)
		_hay(x + 50.0, y - 4.0, 0.82)
		# 场上的糠屑：慢慢飘起、渐淡
		for k in 5:
			var ph := fposmod(t * 0.09 + float(k) * 0.21, 1.0)
			var cx := x - 40.0 + float(k) * 19.0 + sin(ph * 5.0 + float(k)) * 6.0
			var cy := y - 8.0 - ph * 26.0
			draw_circle(Vector2(cx, cy), 1.1 * (1.0 - ph) + 0.3, Color(0.62, 0.54, 0.34, 0.35 * (1.0 - ph)))
	else:
		Draw.ellipse(self, Vector2(x, y), 80.0, 20.0 / Draw.sy(), Color(0.24, 0.20, 0.17, 0.13))
		for k in 4:
			Draw.stroke(self, [Vector2(x - 40.0 + float(k) * 26.0, y - 4.0), Vector2(x - 38.0 + float(k) * 26.0, y - 12.0)], 1.6, 0.8, Color(0.14, 0.12, 0.11, 0.34))

func _hay(x: float, y: float, s: float) -> void:
	var pts := PackedVector2Array([Vector2(x - 15.0 * s, y), Vector2(x, y - 28.0 * s), Vector2(x + 15.0 * s, y)])
	draw_colored_polygon(pts, Color(0.72, 0.63, 0.42, 0.52))
	var bp := pts
	bp.append(pts[0])
	draw_polyline(bp, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.34), 1.3, true)
	for k in 3:
		var tt := 0.24 + 0.24 * float(k)
		var w := 15.0 * s * (1.0 - tt)
		draw_line(Vector2(x - w, y - 28.0 * s * tt), Vector2(x + w * 0.86, y - 24.0 * s * tt), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.14), 1.0, true)

# 石桌石凳（设置锚点）：石头烧不掉，一直在——桌上还煮着一壶茶
func _stone_table() -> void:
	var x := 1392.0
	var y := 800.0
	if not Draw.vis(cam, x - 44.0, x + 44.0):
		return
	var col := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.50)
	Draw.ellipse(self, Vector2(x, y + 2.0), 27.0, 4.2 / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.08))
	Draw.stroke(self, [Vector2(x - 4.0, y), Vector2(x - 4.0, y - 13.0)], 5.0, 4.0, col)
	draw_rect(Rect2(x - 16.0, y - 18.0, 32.0, 6.0), Color(0.62, 0.60, 0.56, 0.95))
	draw_rect(Rect2(x - 16.0, y - 18.0, 32.0, 6.0), col, false, 1.2)
	draw_line(Vector2(x - 16.0, y - 15.0), Vector2(x + 16.0, y - 15.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.16), 0.9, true)
	Draw.stroke(self, [Vector2(x + 21.0, y), Vector2(x + 21.0, y - 8.0)], 7.0, 5.5, col)
	Draw.stroke(self, [Vector2(x - 26.0, y), Vector2(x - 26.0, y - 7.0)], 6.0, 5.0, col)
	# 茶壶（壶身/提梁/壶嘴）＋茶气
	var tx := x + 6.0
	var ty := y - 18.0
	Draw.ellipse(self, Vector2(tx, ty - 3.0), 4.6, 3.6 / Draw.sy(), Color(0.34, 0.27, 0.22, 0.92))
	draw_arc(Vector2(tx, ty - 6.4), 3.4, PI * 1.05, PI * 1.95, 8, Color(0.34, 0.27, 0.22, 0.92), 1.4)
	Draw.stroke(self, [Vector2(tx - 4.0, ty - 3.6), Vector2(tx - 7.6, ty - 6.0)], 1.6, 0.8, Color(0.34, 0.27, 0.22, 0.92))
	draw_circle(Vector2(tx, ty - 6.6), 1.3, Color(0.55, 0.46, 0.32, 0.90))
	for k in 2:
		var ph := fposmod(t * 0.22 + float(k) * 0.5, 1.0)
		var sx := tx + sin(ph * 4.0 + float(k) * 2.0) * 3.4
		var sy := ty - 11.0 - ph * 16.0
		Draw.ellipse(self, Vector2(sx, sy), 2.6 + ph * 2.6, (1.6 + ph * 1.4) / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.10 * (1.0 - ph)))
	# 一只茶盏
	Draw.ellipse(self, Vector2(x - 8.0, y - 19.0), 2.6, 1.6 / Draw.sy(), Color(0.92, 0.90, 0.84, 0.95))
	draw_arc(Vector2(x - 8.0, y - 19.0), 2.6, 0.0, TAU, 10, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.35), 0.9)

# ============ 后山（左端卷面） / 山洞 ============

func _backhill() -> void:
	var x := 660.0
	if not Draw.vis(cam, x - 212.0, x + 212.0):
		return
	# 远岭（淡）
	var far := PackedVector2Array([
		Vector2(x - 196.0, 766.0), Vector2(x - 128.0, 690.0),
		Vector2(x - 52.0, 638.0), Vector2(x + 24.0, 670.0),
		Vector2(x + 104.0, 638.0), Vector2(x + 172.0, 708.0), Vector2(x + 208.0, 766.0)])
	draw_colored_polygon(far, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.070))
	Draw.stroke(self, [Vector2(x - 194.0, 764.0), Vector2(x - 126.0, 689.0),
		Vector2(x - 52.0, 639.0), Vector2(x + 24.0, 669.0),
		Vector2(x + 102.0, 639.0), Vector2(x + 170.0, 707.0), Vector2(x + 206.0, 764.0)],
		2.6, 1.0, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.20))
	# 山腰一缕薄雾（慢慢移）
	for k in 2:
		var phm := fposmod(t * 0.02 + float(k) * 0.5, 1.0)
		var mx := x - 120.0 + phm * 240.0
		Draw.ellipse(self, Vector2(mx, 700.0 - float(k) * 22.0), 74.0, 12.0 / Draw.sy(), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.16))
	# 近岗（浓）+ 谷口豁
	var near := PackedVector2Array([
		Vector2(x - 130.0, 770.0), Vector2(x - 40.0, 714.0),
		Vector2(x + 40.0, 704.0), Vector2(x + 120.0, 734.0), Vector2(x + 165.0, 770.0)])
	draw_colored_polygon(near, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.105))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 22.0, 770.0), Vector2(x - 8.0, 718.0),
		Vector2(x + 26.0, 714.0), Vector2(x + 40.0, 770.0)]), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.55))
	# 五棵松（随风摆）
	_pine_on(x - 150.0, 736.0, 0.66, 0)
	_pine_on(x - 100.0, 726.0, 0.80, 1)
	_pine_on(x + 5.0, 706.0, 0.95, 2)
	_pine_on(x + 96.0, 730.0, 0.74, 3)
	_pine_on(x + 148.0, 740.0, 0.62, 4)
	# 山脚草丛（会摆）
	for k in 8:
		var gx := x - 168.0 + float(k) * 46.0
		var sw := sin(t * Conf.WIND_RATE * 1.3 + float(k) * 0.8) * 2.0
		Draw.stroke(self, [Vector2(gx, 768.0), Vector2(gx + sw, 768.0 - 9.0 - fposmod(float(k) * 3.3, 5.0))], 1.6, 0.7, Color(0.45, 0.42, 0.30, 0.35))
	# 两三枚松针慢慢落
	for k in 3:
		var phn := fposmod(t * 0.05 + float(k) * 0.31, 1.0)
		var nx := x - 120.0 + float(k) * 118.0 + sin(phn * 7.0 + float(k)) * 10.0
		var ny := 660.0 + phn * 96.0
		Draw.stroke(self, [Vector2(nx, ny), Vector2(nx + 2.6, ny + 3.6)], 1.3, 0.5, Color(0.30, 0.36, 0.26, 0.30))
	# 草窝（白狐的老家）
	_nest(x + 176.0, 764.0)
	# 青隼（白狐跟定你之后，才落在最高的那棵松上）
	_falcon(x)

func _pine_on(x: float, base: float, s: float, i: int) -> void:
	var sw := sin(t * Conf.WIND_RATE + float(i) * 1.9) * 2.0
	var col := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.52)
	Draw.stroke(self, [Vector2(x, base), Vector2(x + sw * 0.7, base - 70.0 * s)], 3.4 * s, 1.6 * s, col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + sw * 0.6, base - 46.0 * s),
		Vector2(x - 22.0 * s, base - 6.0 * s),
		Vector2(x + 22.0 * s, base - 6.0 * s)]), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.34))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + sw * 0.4, base - 78.0 * s),
		Vector2(x - 16.0 * s, base - 38.0 * s),
		Vector2(x + 16.0 * s, base - 38.0 * s)]), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.40))
	# 冬：松枝压雪
	if season == 3:
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + sw * 0.4, base - 72.0 * s),
			Vector2(x - 12.0 * s, base - 42.0 * s),
			Vector2(x + 12.0 * s, base - 42.0 * s)]), Color(0.96, 0.97, 0.99, 0.50))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + sw * 0.55, base - 42.0 * s),
			Vector2(x - 16.0 * s, base - 12.0 * s),
			Vector2(x + 16.0 * s, base - 12.0 * s)]), Color(0.96, 0.97, 0.99, 0.46))

func _nest(x: float, y: float) -> void:
	Draw.ellipse(self, Vector2(x, y + 2.0), 26.0, 8.0 / Draw.sy(), Color(0.55, 0.48, 0.32, 0.28))
	for k in 7:
		var gx := x - 18.0 + float(k) * 6.0
		var sw := sin(t * Conf.WIND_RATE * 1.2 + float(k) * 0.9) * 2.2
		Draw.stroke(self, [Vector2(gx, y + 1.0), Vector2(gx + sw, y - 9.0 - fposmod(float(k) * 3.1, 5.0))], 1.5, 0.7, Color(0.45, 0.40, 0.26, 0.45))
	if pet_joined:
		# 它跟定你了——窝空了，只剩爪印
		for k2 in 3:
			Draw.ellipse(self, Vector2(x - 24.0 - float(k2) * 9.0, y + 1.0 - float(k2) * 2.0), 1.6, 1.6 / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.18))
		return
	var br := 1.0 + 0.07 * sin(t * 1.7)
	var body := Color(0.965, 0.950, 0.915, 0.98)
	var inkc := Color(0.30, 0.27, 0.28, 0.95)
	var twitch := clampf((sin(t * 0.8 + 1.0) - 0.92) / 0.08, 0.0, 1.0)
	# 尾巴：慢慢扫一下
	var tail := sin(t * 0.7) * 2.4
	Draw.ellipse(self, Vector2(x - 13.0 + tail * 0.4, y - 6.0 - tail * 0.3), 7.0, 4.5 / Draw.sy(), body)
	Draw.stroke(self, [Vector2(x - 18.0 + tail * 0.4, y - 7.0 - tail * 0.3), Vector2(x - 23.0 + tail, y - 10.0 - tail * 0.5)], 2.6, 1.2, body)
	# 身子 + 头 + 两耳（偶尔抖一下）
	Draw.ellipse(self, Vector2(x, y - 5.0), 13.0 * br, 8.5 * br / Draw.sy(), body)
	Draw.ellipse(self, Vector2(x + 12.0, y - 9.0), 7.0 * br, 6.0 * br / Draw.sy(), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 7.0, y - 14.0), Vector2(x + 9.0 - twitch * 1.4, y - 20.0 - twitch * 1.6), Vector2(x + 12.0, y - 13.0)]), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 13.0, y - 13.0), Vector2(x + 16.0 - twitch * 1.4, y - 19.0 - twitch * 1.6), Vector2(x + 18.0, y - 12.0)]), body)
	draw_circle(Vector2(x + 13.0, y - 10.0), 1.1, inkc)
	draw_circle(Vector2(x + 7.0, y - 9.0), 1.1, inkc)
# 青隼：白狐跟定你之后，它落在后山 2 号松（最高那棵）的梢上。
# 青隼也入队后，松梢空了，只在松脚留一根断羽。
# 坐标跟着 _pine_on(x + 5.0, 706.0, 0.95, 2) —— 改那棵松时，这里一起改。
func _falcon(x: float) -> void:
	if not pet_joined:
		return
	var sw := sin(t * Conf.WIND_RATE + 3.8) * 2.0     # 2.0 * 1.9：与 2 号松同相
	var fx := x + 5.0 + sw * 0.4                       # 梢上（随松摆）
	var fy := 631.9                                    # 706.0 - 78.0 * 0.95：爪下着力点
	if sun_joined:
		Draw.stroke(self, [Vector2(x - 6.0, 704.0), Vector2(x + 0.4, 710.0)], 1.6, 0.6, Color(0.42, 0.47, 0.56, 0.48))
		Draw.stroke(self, [Vector2(x + 0.4, 710.0), Vector2(x - 3.6, 713.2)], 1.2, 0.4, Color(0.42, 0.47, 0.56, 0.36))
		return
	var bob := sin(t * 1.9) * 0.9
	var glance := clampf((sin(t * 0.55) - 0.86) / 0.14, 0.0, 1.0)     # 偶尔转头看你
	var preen := clampf((sin(t * 0.9 + 2.4) - 0.90) / 0.10, 0.0, 1.0)  # 偶尔低头理羽
	var gold := Color(0.85, 0.68, 0.30)
	var inkc := Color(0.16, 0.15, 0.17, 0.95)
	# 爪子
	Draw.stroke(self, [Vector2(fx - 3.0, fy - 6.0), Vector2(fx - 4.2, fy + 0.6)], 1.4, 0.6, gold)
	Draw.stroke(self, [Vector2(fx + 3.0, fy - 6.0), Vector2(fx + 4.2, fy + 0.6)], 1.4, 0.6, gold)
	# 尾羽（斜垂，随身体微动）
	draw_colored_polygon(PackedVector2Array([
		Vector2(fx - 2.0, fy - 9.0 + bob * 0.3),
		Vector2(fx - 9.4, fy + 0.6 + bob * 0.3),
		Vector2(fx - 5.2, fy + 2.2 + bob * 0.3),
		Vector2(fx - 0.6, fy - 5.4 + bob * 0.3)]), Color(0.33, 0.38, 0.47, 0.92))
	# 身子（立蛋形）
	Draw.ellipse(self, Vector2(fx, fy - 10.0 + bob * 0.3), 5.6, 7.4 / Draw.sy(), Color(0.47, 0.52, 0.60, 0.96))
	# 胸脯
	Draw.ellipse(self, Vector2(fx + 2.4, fy - 8.4 + bob * 0.3), 2.8, 4.4 / Draw.sy(), Color(0.74, 0.72, 0.67, 0.92))
	# 折翅
	draw_colored_polygon(PackedVector2Array([
		Vector2(fx - 0.8, fy - 16.2 + bob * 0.5),
		Vector2(fx - 7.6, fy - 6.4 + bob * 0.5),
		Vector2(fx - 4.6, fy - 4.4 + bob * 0.5),
		Vector2(fx + 1.8, fy - 13.8 + bob * 0.5)]), Color(0.36, 0.41, 0.50, 0.96))
	Draw.stroke(self, [Vector2(fx - 5.8, fy - 5.8 + bob * 0.5), Vector2(fx - 0.4, fy - 12.6 + bob * 0.5)], 0.9, 0.4, Color(0.24, 0.28, 0.36, 0.60))
	# 头（转头 / 理羽时低下）
	var hx := fx + 1.6 + glance * 1.4 - preen * 2.8
	var hy := fy - 19.6 + bob + preen * 5.4
	draw_circle(Vector2(hx, hy), 4.4, Color(0.55, 0.60, 0.68, 0.97))
	# 喙
	draw_colored_polygon(PackedVector2Array([
		Vector2(hx + 3.4, hy - 1.4),
		Vector2(hx + 7.4, hy + 0.4),
		Vector2(hx + 3.4, hy + 2.0)]), gold)
	# 眼
	draw_circle(Vector2(hx + 1.6, hy - 0.9), 1.1, inkc)
	draw_circle(Vector2(hx + 1.9, hy - 1.3), 0.4, Color(0.97, 0.96, 0.92, 0.9))
# ============ 山洞 ============

func _cave() -> void:
	# v12：做过任务（cave_opened）就整段不画——山洞没了
	if not show_cave or cave_opened:
		return
	var x := POS["cave"].x
	var y := POS["cave"].y
	if not Draw.vis(cam, x - 100.0, x + 100.0):
		return
	Draw.ellipse(self, Vector2(x, y + 2.0), 86.0, 26.0 / Draw.sy(), Color(0.72, 0.69, 0.60, 0.42))
	Draw.ellipse(self, Vector2(x - 42.0, y + 4.0), 34.0, 12.0 / Draw.sy(), Color(0.66, 0.62, 0.53, 0.38))
	Draw.ellipse(self, Vector2(x + 46.0, y + 2.0), 30.0, 11.0 / Draw.sy(), Color(0.66, 0.62, 0.53, 0.34))
	# 洞口两侧的石堆（把洞"压"在山里）
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 46.0, y + 2.0), Vector2(x - 40.0, y - 13.0),
		Vector2(x - 28.0, y - 16.0), Vector2(x - 21.0, y + 2.0)]), Color(0.54, 0.51, 0.46, 0.60))
	draw_line(Vector2(x - 40.0, y - 13.0), Vector2(x - 29.0, y - 15.6), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.30), 1.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 20.0, y + 2.0), Vector2(x + 26.0, y - 11.0),
		Vector2(x + 38.0, y - 13.0), Vector2(x + 44.0, y + 2.0)]), Color(0.56, 0.53, 0.47, 0.52))
	draw_line(Vector2(x + 27.0, y - 10.6), Vector2(x + 37.0, y - 12.6), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.26), 1.0, true)
	# 洞口
	var pts := PackedVector2Array([
		Vector2(x - 26.0, y + 2.0), Vector2(x - 20.0, y - 22.0),
		Vector2(x, y - 30.0), Vector2(x + 20.0, y - 22.0), Vector2(x + 26.0, y + 2.0)])
	draw_colored_polygon(pts, Color(0.10, 0.09, 0.09, 0.88))
	var bp := pts
	bp.append(pts[0])
	draw_polyline(bp, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.55), 1.6, true)
	# 没开：荒草半掩（草会摇）——开了整段被上面的闸拦掉，这儿只剩这一种情形
	for k in 7:
		var px := x - 24.0 + float(k) * 8.0
		var hh := 10.0 + fposmod(float(k) * 3.7, 6.0)
		var sw2 := sin(t * Conf.WIND_RATE * 1.4 + float(k) * 0.9) * 2.2
		Draw.stroke(self, [Vector2(px, y + 1.0), Vector2(px - 2.0 + sw2, y + 1.0 - hh)], 1.5, 0.7, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.32))

# ============ 品酒坊 ============

func _winery() -> void:
	if not show_winery:
		return
	var x := POS["winery"].x
	var y := POS["winery"].y
	if not Draw.vis(cam, x - 128.0, x + 128.0):
		return
	_house_done(x, y, 84.0, 46.0, 26.0, false, 0.0, true)
	# 门前酒案：案板 + 两条腿 + 案上（酒提、两盏）
	var tx := x + 18.0
	var ty := y + 6.0
	draw_rect(Rect2(tx - 30.0, ty - 17.0, 60.0, 4.0), Color(0.56, 0.44, 0.29, 0.94))
	draw_line(Vector2(tx - 30.0, ty - 17.0), Vector2(tx + 30.0, ty - 17.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.30), 1.0, true)
	draw_line(Vector2(tx - 24.0, ty - 13.0), Vector2(tx - 26.0, ty), Color(0.48, 0.38, 0.25, 0.90), 3.0, true)
	draw_line(Vector2(tx + 24.0, ty - 13.0), Vector2(tx + 26.0, ty), Color(0.48, 0.38, 0.25, 0.90), 3.0, true)
	Draw.stroke(self, [Vector2(tx + 12.0, ty - 17.0), Vector2(tx + 6.0, ty - 30.0)], 2.4, 1.4, Color(0.42, 0.33, 0.22, 0.88))
	Draw.ellipse(self, Vector2(tx + 6.0, ty - 31.0), 4.0, 2.6 / Draw.sy(), Color(0.50, 0.40, 0.26, 0.92))
	Draw.ellipse(self, Vector2(tx - 14.0, ty - 18.4), 3.0, 1.8 / Draw.sy(), Color(0.93, 0.90, 0.84, 0.95))
	Draw.ellipse(self, Vector2(tx - 5.0, ty - 19.0), 3.0, 1.8 / Draw.sy(), Color(0.93, 0.90, 0.84, 0.95))
	# 酒旗：杆 + 横臂 + 旗（会摆），旗上压着"坛形"小纹
	Draw.stroke(self, [Vector2(x + 58.0, y), Vector2(x + 58.0, y - 64.0)], 2.2, 1.5, Color(0.42, 0.33, 0.22, 0.88))
	draw_line(Vector2(x + 46.0, y - 62.0), Vector2(x + 62.0, y - 62.0), Color(0.42, 0.33, 0.22, 0.88), 2.0, true)
	var sway := sin(t * 1.25) * 2.0
	var f0 := Vector2(x + 46.0, y - 61.0)
	var f1 := Vector2(x + 68.0 + sway, y - 58.0)
	var f2 := Vector2(x + 68.0 + sway, y - 38.0)
	var f3 := Vector2(x + 46.0, y - 41.0)
	draw_colored_polygon(PackedVector2Array([f0, f1, f2, f3]), Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b, 0.78))
	Draw.stroke(self, [f3.lerp(f2, 0.5), f0.lerp(f1, 0.5)], 1.0, 1.0, Color(1.0, 0.96, 0.90, 0.30))
	var mx := (f0.x + f1.x + f2.x + f3.x) * 0.25
	var my := (f0.y + f1.y + f2.y + f3.y) * 0.25
	Draw.ellipse(self, Vector2(mx, my + 1.0), 3.4, 2.6 / Draw.sy(), Color(1.0, 0.96, 0.90, 0.66))
	draw_rect(Rect2(mx - 1.6, my - 4.4, 3.2, 2.0), Color(1.0, 0.96, 0.90, 0.66))
	# 坛子三只（大小不一，红布封口）
	_jar(x - 66.0, y + 1.0, 1.0)
	_jar(x - 52.0, y + 3.0, 0.82)
	_jar(x - 41.0, y + 1.0, 0.66)

# 酒坛：肚上釉光 + 弦纹 + 红布封口
func _jar(x: float, y: float, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 8.4 * s, y), Vector2(x - 11.4 * s, y - 12.0 * s),
		Vector2(x - 5.2 * s, y - 19.0 * s), Vector2(x + 5.2 * s, y - 19.0 * s),
		Vector2(x + 11.4 * s, y - 12.0 * s), Vector2(x + 8.4 * s, y)]), Color(0.31, 0.27, 0.23, 0.94))
	draw_line(Vector2(x - 5.0 * s, y - 16.0 * s), Vector2(x - 7.4 * s, y - 6.0 * s), Color(0.62, 0.58, 0.50, 0.30), 1.2 * s, true)
	draw_arc(Vector2(x, y - 11.5 * s), 9.0 * s, PI * 0.12, PI * 0.88, 10, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.22), 0.9)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 5.6 * s, y - 19.6 * s), Vector2(x + 5.6 * s, y - 19.6 * s),
		Vector2(x + 4.4 * s, y - 23.6 * s), Vector2(x - 4.4 * s, y - 23.6 * s)]),
		Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b, 0.80))
	draw_line(Vector2(x - 3.0 * s, y - 20.2 * s), Vector2(x - 2.2 * s, y - 23.0 * s), Color(1.0, 0.95, 0.88, 0.30), 0.8, true)
	draw_line(Vector2(x - 5.4 * s, y - 19.4 * s), Vector2(x + 5.4 * s, y - 19.4 * s), Color(0.55, 0.44, 0.28, 0.75), 1.0, true)

# ============ 货栈 ============

func _shop() -> void:
	if not show_shop:
		return
	var x := POS["shop"].x
	var y := POS["shop"].y
	if not Draw.vis(cam, x - 128.0, x + 128.0):
		return
	_house_done(x, y - 6.0, 88.0, 44.0, 24.0, false, 0.0, false)
	# 雨棚：两色条纹 + 波浪边
	var a0 := Vector2(x - 66.0, y - 12.0)
	var b0 := Vector2(x - 20.0, y - 12.0)
	var b1 := Vector2(x - 25.0, y + 4.0)
	var a1 := Vector2(x - 71.0, y + 4.0)
	draw_colored_polygon(PackedVector2Array([a0, b0, b1, a1]), Color(0.80, 0.74, 0.60, 0.82))
	for k in 3:
		var u := float(k) / 3.0
		var v := float(k + 1) / 3.0
		var s0 := a0.lerp(b0, u)
		var s1 := a0.lerp(b0, v)
		var t0 := a1.lerp(b1, u)
		var t1 := a1.lerp(b1, v)
		draw_colored_polygon(PackedVector2Array([s0, s1, t1, t0]), Color(0.72, 0.44, 0.36, 0.30 if k % 2 == 0 else 0.16))
	draw_line(a0, b0, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.42), 1.6, true)
	for k2 in 5:
		var cx := lerpf(a1.x + 5.0, b1.x - 1.0, float(k2) / 4.0)
		draw_arc(Vector2(cx, y + 4.0), 5.0, 0.0, PI, 8, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.30), 1.0)
	# 柜台 + 秤（横梁会轻晃，两只吊盘跟着摆）
	var qx := x - 48.0
	var qy := y + 8.0
	draw_rect(Rect2(qx - 22.0, qy - 16.0, 44.0, 4.0), Color(0.58, 0.46, 0.30, 0.94))
	draw_line(Vector2(qx - 22.0, qy - 16.0), Vector2(qx + 22.0, qy - 16.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.30), 1.0, true)
	draw_line(Vector2(qx - 18.0, qy - 12.0), Vector2(qx - 20.0, qy), Color(0.48, 0.38, 0.25, 0.90), 3.0, true)
	draw_line(Vector2(qx + 18.0, qy - 12.0), Vector2(qx + 20.0, qy), Color(0.48, 0.38, 0.25, 0.90), 3.0, true)
	var px2 := qx + 6.0
	draw_line(Vector2(px2, qy - 16.0), Vector2(px2, qy - 30.0), Color(0.40, 0.33, 0.24, 0.92), 2.0, true)
	var tilt := sin(t * 1.1) * 0.05
	var beam_l := Vector2(px2 - 15.0, qy - 30.0 + tilt * 40.0)
	var beam_r := Vector2(px2 + 15.0, qy - 30.0 - tilt * 40.0)
	draw_line(beam_l, beam_r, Color(0.40, 0.33, 0.24, 0.92), 1.6, true)
	draw_line(beam_l, beam_l + Vector2(0.0, 6.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.50), 0.8, true)
	draw_line(beam_r, beam_r + Vector2(0.0, 6.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.50), 0.8, true)
	draw_arc(beam_l + Vector2(0.0, 8.0), 4.0, 0.0, PI, 8, Color(0.52, 0.42, 0.26, 0.90), 1.4)
	draw_arc(beam_r + Vector2(0.0, 8.0), 4.0, 0.0, PI, 8, Color(0.52, 0.42, 0.26, 0.90), 1.4)
	# 木箱两只（叠）+ 麻袋 + 坛
	_crate(qx - 40.0, qy + 2.0, 1.0)
	_crate(qx - 40.0, qy - 12.0, 0.80)
	_sack(x + 34.0, y + 6.0, 0.90)
	_jar(x + 48.0, y + 5.0, 0.62)
	# 挂招牌（木牌 + 铜钱纹），随风轻摆
	var gx := x + 30.0
	var gy := y - 26.0
	var sw2 := sin(t * 0.85 + 1.2) * 1.6
	draw_line(Vector2(gx, gy - 12.0), Vector2(gx + sw2, gy), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.45), 1.0, true)
	draw_line(Vector2(gx + 14.0, gy - 12.0), Vector2(gx + 14.0 + sw2, gy), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.45), 1.0, true)
	draw_rect(Rect2(gx + sw2 - 3.0, gy, 20.0, 15.0), Color(0.52, 0.40, 0.26, 0.92))
	draw_rect(Rect2(gx + sw2 - 3.0, gy, 20.0, 15.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.42), false, 1.0)
	draw_circle(Vector2(gx + sw2 + 7.0, gy + 7.5), 4.0, Color(0.82, 0.66, 0.30, 0.75))
	draw_circle(Vector2(gx + sw2 + 7.0, gy + 7.5), 1.6, Color(0.52, 0.40, 0.26, 0.90))

func _crate(x: float, y: float, s: float) -> void:
	var w := 16.0 * s
	var h := 12.0 * s
	draw_rect(Rect2(x, y - h, w, h), Color(0.62, 0.48, 0.30, 0.92))
	draw_rect(Rect2(x, y - h, w, h), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.40), false, 1.0)
	draw_line(Vector2(x, y - h), Vector2(x + w, y), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.30), 0.9, true)
	draw_line(Vector2(x + w, y - h), Vector2(x, y), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.30), 0.9, true)

func _sack(x: float, y: float, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 9.0 * s, y), Vector2(x - 11.0 * s, y - 14.0 * s),
		Vector2(x - 4.0 * s, y - 22.0 * s), Vector2(x + 4.0 * s, y - 22.0 * s),
		Vector2(x + 11.0 * s, y - 14.0 * s), Vector2(x + 9.0 * s, y)]), Color(0.66, 0.60, 0.45, 0.88))
	draw_line(Vector2(x - 5.0 * s, y - 20.0 * s), Vector2(x + 5.0 * s, y - 20.0 * s), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.40), 1.2, true)

# ============ 炼丹阁 ============

func _dange() -> void:
	if not show_dange:
		return
	var x := POS["dange"].x
	var y := POS["dange"].y
	if not Draw.vis(cam, x - 132.0, x + 132.0):
		return
	_house_done(x, y - 8.0, 92.0, 48.0, 28.0, false, 0.0, true)
	var fx := x - 64.0
	var fy := y + 2.0
	# 炉：石座 + 砖身 + 炉沿 + 炉顶烟囱
	draw_rect(Rect2(fx - 21.0, fy - 4.0, 42.0, 4.0), Color(0.50, 0.47, 0.42, 0.92))
	draw_rect(Rect2(fx - 18.0, fy - 28.0, 36.0, 24.0), Color(0.34, 0.31, 0.28, 0.96))
	draw_line(Vector2(fx - 18.0, fy - 19.0), Vector2(fx + 18.0, fy - 19.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.22), 0.9, true)
	draw_line(Vector2(fx - 18.0, fy - 10.0), Vector2(fx + 18.0, fy - 10.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.18), 0.9, true)
	draw_line(Vector2(fx - 9.0, fy - 28.0), Vector2(fx - 9.0, fy - 19.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.14), 0.8, true)
	draw_line(Vector2(fx + 9.0, fy - 28.0), Vector2(fx + 9.0, fy - 19.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.14), 0.8, true)
	draw_rect(Rect2(fx - 22.0, fy - 33.0, 44.0, 5.5), Color(0.41, 0.37, 0.33, 0.96))
	draw_rect(Rect2(fx - 5.0, fy - 45.0, 10.0, 12.0), Color(0.38, 0.35, 0.31, 0.96))
	draw_rect(Rect2(fx - 7.2, fy - 47.6, 14.4, 3.0), Color(0.46, 0.41, 0.36, 0.96))
	# 炉口 + 火（呼吸）
	var g := 0.5 + 0.5 * sin(t * 3.0)
	var lit := 0.55 if dange_busy else 0.24
	draw_arc(Vector2(fx, fy - 12.5), 10.6, PI, TAU, 14, Color(0.18, 0.15, 0.13, 0.85), 2.6)
	Draw.ellipse(self, Vector2(fx, fy - 12.0), 9.4 + 2.4 * g, (6.6 + 1.8 * g) / Draw.sy(), Color(0.92, 0.60, 0.24, lit + 0.15 * g))
	Draw.ellipse(self, Vector2(fx, fy - 12.0), 4.4 + 1.3 * g, 3.4 / Draw.sy(), Color(0.98, 0.84, 0.46, lit + 0.25 * g))
	# 风箱：拉杆一进一出（有人看火时踩得急）
	var be := sin(t * (3.6 if dange_busy else 1.7))
	var bx := fx + 27.0
	draw_rect(Rect2(bx - 11.0, fy - 15.0, 22.0, 11.0), Color(0.42, 0.34, 0.24, 0.94))
	draw_rect(Rect2(bx - 11.0, fy - 15.0, 22.0, 11.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.35), false, 1.0)
	draw_line(Vector2(bx + 11.0, fy - 9.5), Vector2(bx + 19.0 + be * 4.0, fy - 9.5), Color(0.40, 0.33, 0.24, 0.92), 2.0, true)
	draw_line(Vector2(bx + 19.0 + be * 4.0, fy - 14.0), Vector2(bx + 19.0 + be * 4.0, fy - 5.0), Color(0.40, 0.33, 0.24, 0.92), 2.4, true)
	draw_line(Vector2(bx - 11.0, fy - 12.0), Vector2(fx + 18.0, fy - 12.0), Color(0.30, 0.27, 0.24, 0.75), 1.6, true)
	# 余烬（忙时火星上飘）
	if dange_busy:
		for k in 7:
			var ph2 := fposmod(t * 0.55 + float(k) * 0.143, 1.0)
			var exr := fx + sin(ph2 * 5.2 + float(k) * 2.1) * 5.6
			var eyr := fy - 14.0 - ph2 * 40.0
			draw_circle(Vector2(exr, eyr), 1.3 * (1.0 - ph2) + 0.3, Color(0.95, 0.62, 0.26, 0.60 * (1.0 - ph2)))
		_smoke(fx, fy - 49.0, 0.31)
	# 门侧挂葫芦（轻摆）
	var hx := x + 26.0
	var hy := y - 34.0
	var sw3 := sin(t * 0.9 + 0.4) * 1.6
	draw_line(Vector2(hx, hy - 10.0), Vector2(hx + sw3, hy), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.42), 0.9, true)
	draw_circle(Vector2(hx + sw3, hy + 3.4), 3.0, Color(0.78, 0.64, 0.32, 0.85))
	draw_circle(Vector2(hx + sw3, hy + 8.4), 4.0, Color(0.78, 0.64, 0.32, 0.85))
	# 看火的人：站炉子左边，扇着蒲扇
	if dange_tender != "":
		var tx2 := fx - 30.0
		var ty2 := fy - 1.0
		var step := sin(t * 5.4) * 0.9
		var bob2 := sin(t * 1.5) * 0.6
		Draw.mini_person(self, tx2, ty2, 1.0, step, bob2, false)
		var fw := sin(t * 5.4) * 2.6
		Draw.stroke(self, [Vector2(tx2 + 7.0, ty2 - 30.0), Vector2(tx2 + 17.0, ty2 - 34.0 + fw)], 1.8, 1.0, Color(0.44, 0.32, 0.20, 0.85))

# ============ 藏宝阁 ============

func _treasure() -> void:
	if not show_treasure:
		return
	var x := POS["treasure"].x
	var y := POS["treasure"].y
	if not Draw.vis(cam, x - 116.0, x + 116.0):
		return
	_house_done(x, y, 76.0, 42.0, 24.0, false, 0.0, false)
	# 台阶
	draw_rect(Rect2(x - 26.0, y + 1.0, 52.0, 4.0), Color(0.62, 0.60, 0.56, 0.88))
	draw_line(Vector2(x - 26.0, y + 1.0), Vector2(x + 26.0, y + 1.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.22), 0.9, true)
	# 门侧灯笼（轻摆 + 暖光呼吸）
	var lx := x - 30.0
	var ly := y - 32.0
	var swy := sin(t * 0.8 + 0.6) * 2.0
	draw_line(Vector2(lx, ly - 12.0), Vector2(lx + swy, ly - 2.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.42), 1.0, true)
	var glow := 0.5 + 0.5 * sin(t * 2.1 + 0.7)
	Draw.ellipse(self, Vector2(lx + swy, ly + 4.0), 13.5 + 2.0 * glow, (10.5 + 2.0 * glow) / Draw.sy(), Color(0.95, 0.72, 0.34, 0.05 + 0.05 * glow))
	Draw.ellipse(self, Vector2(lx + swy, ly + 4.0), 5.0, 6.4 / Draw.sy(), Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b, 0.78))
	draw_line(Vector2(lx + swy - 5.4, ly + 4.0), Vector2(lx + swy + 5.4, ly + 4.0), Color(0.55, 0.44, 0.28, 0.80), 1.0, true)
	draw_rect(Rect2(lx + swy - 3.0, ly - 1.6, 6.0, 2.0), Color(0.45, 0.35, 0.22, 0.90))
	draw_rect(Rect2(lx + swy - 3.0, ly + 8.6, 6.0, 2.0), Color(0.45, 0.35, 0.22, 0.90))
	# 倚着的梯子（两杆 + 四踏）
	var dx := x + 50.0
	Draw.stroke(self, [Vector2(dx - 6.0, y - 2.0), Vector2(dx - 10.0, y - 42.0)], 2.2, 1.6, Color(0.52, 0.40, 0.26, 0.90))
	Draw.stroke(self, [Vector2(dx + 4.0, y - 2.0), Vector2(dx + 0.0, y - 42.0)], 2.2, 1.6, Color(0.52, 0.40, 0.26, 0.90))
	for k in 4:
		var u := 0.16 + 0.22 * float(k)
		var p0 := Vector2(dx - 6.0, y - 2.0).lerp(Vector2(dx - 10.0, y - 42.0), u)
		var p1 := Vector2(dx + 4.0, y - 2.0).lerp(Vector2(dx + 0.0, y - 42.0), u)
		draw_line(p0, p1, Color(0.48, 0.37, 0.24, 0.85), 1.6, true)
	# 一张旧皮纸（藏宝图）倚在门边
	draw_rect(Rect2(x + 20.0, y - 30.0, 16.0, 22.0), Color(0.87, 0.81, 0.61, 0.95))
	draw_rect(Rect2(x + 20.0, y - 30.0, 16.0, 22.0), Color(0.42, 0.34, 0.22, 0.60), false, 1.2)
	draw_line(Vector2(x + 24.0, y - 26.0), Vector2(x + 32.0, y - 26.0), Color(0.60, 0.24, 0.18, 0.75), 1.2, true)
	draw_line(Vector2(x + 24.0, y - 21.0), Vector2(x + 30.0, y - 19.0), Color(0.60, 0.24, 0.18, 0.60), 1.0, true)
	# 门边旧箱
	_crate(x - 52.0, y + 2.0, 0.90)

# ============ 桃 / 鸡 / 花瓣 ============

func _peach_all() -> void:
	for it in Build.PEACHES:
		_peach_one(it)

func _peach_one(p: Dictionary) -> void:
	var x := float(p["x"])
	var y := float(p["y"])
	var s := float(p["s"])
	var ph := float(p["ph"])
	if not Draw.vis(cam, x - 70.0, x + 70.0):
		return
	var h := 84.0 * s
	var sw := sin(t * Conf.WIND_RATE + ph) * Conf.WIND_AMP * 0.9
	draw_set_transform_matrix(Draw.bend_xf(Vector2(x, y), sw / h))
	var done := stage >= int(p["at"])
	var br := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.50 if done else 0.44)
	Draw.ellipse(self, Vector2(x, y + 2.0), 22.0 * s, 4.0 * s / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.06))
	Draw.stroke(self, [Vector2(x, y), Vector2(x - 2.0 * s, y - h * 0.50), Vector2(x + 3.0 * s, y - h * 0.92)], 4.6 * s, 1.8 * s, br)
	Draw.stroke(self, [Vector2(x - 1.0 * s, y - h * 0.62), Vector2(x - 16.0 * s, y - h * 0.80)], 2.4 * s, 1.0 * s, br)
	Draw.stroke(self, [Vector2(x + 1.0 * s, y - h * 0.72), Vector2(x + 15.0 * s, y - h * 0.88)], 2.4 * s, 1.0 * s, br)
	if done:
		# 树下一圈落花影 + 枝头随季换色：春粉 / 夏绿 / 秋赭 / 冬雪团
		Draw.ellipse(self, Vector2(x, y + 1.0), 26.0 * s, 5.0 * s / Draw.sy(), Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b, 0.05))
		var breathe := 0.82 + 0.18 * sin(t * 0.9 + ph)
		var bc := Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b, 0.26 * breathe)
		var br2 := 2.4 * s
		if season == 1:
			bc = Color(0.32, 0.50, 0.27, 0.24 * breathe)
			br2 = 3.0 * s
		elif season == 2:
			bc = Color(0.76, 0.56, 0.22, 0.28 * breathe)
		elif season == 3:
			bc = Color(0.97, 0.97, 0.99, 0.85)
			br2 = 2.8 * s
		for k in 12:
			var ang := -PI * (0.07 + 0.86 * float(k) / 11.0)
			var rr := h * (0.26 + 0.20 * absf(sin(float(k) * 2.7 + ph)))
			var px := x + cos(ang) * rr * 1.45
			var py := y - h * 0.70 + sin(ang) * rr * 0.95
			Draw.ellipse(self, Vector2(px, py), br2, br2 / Draw.sy(), bc)
	else:
		for k in 5:
			var ang2 := -PI * (0.10 + 0.70 * float(k) / 4.0)
			var rr2 := h * 0.42
			Draw.ellipse(self, Vector2(x + cos(ang2) * rr2 * 1.30, y - h * 0.74 + sin(ang2) * rr2 * 0.80), 1.7 * s, 1.7 * s / Draw.sy(), Color(0.12, 0.10, 0.10, 0.45))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _chickens() -> void:
	if stage < Build.CHICKEN_AT:
		return
	_chicken(966.0, 824.0, 0.0)
	_chicken(996.0, 832.0, 2.2)
	_chicken(1022.0, 826.0, 4.1)

# 鸡：会踱步、会停下来啄食、尾巴一甩一甩（三只，相位错开）
func _chicken(x: float, y: float, ph: float) -> void:
	if not Draw.vis(cam, x - 32.0, x + 32.0):
		return
	var col := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.62)
	var walk := sin(t * 0.37 + ph)
	var px := x + walk * 11.0
	var moving := absf(cos(t * 0.37 + ph))
	var peck := absf(sin(t * 1.5 + ph * 1.7))
	# 影子
	Draw.ellipse(self, Vector2(px, y + 0.6), 6.2, 2.0 / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.10))
	# 双腿（交替迈）
	var ls := sin(t * 4.4 + ph) * 1.6 * moving
	draw_line(Vector2(px - 1.6, y - 5.0), Vector2(px - 1.6 + ls, y), col, 1.1, true)
	draw_line(Vector2(px + 1.6, y - 5.0), Vector2(px + 1.6 - ls, y), col, 1.1, true)
	# 身子 + 尾（甩）
	Draw.ellipse(self, Vector2(px, y - 7.0 - peck * 0.4), 5.2, 4.4 / Draw.sy(), col)
	Draw.stroke(self, [Vector2(px - 4.2, y - 8.6), Vector2(px - 8.6, y - 11.0 + sin(t * 2.6 + ph) * 0.8), Vector2(px - 11.6, y - 9.4)], 1.8, 0.8, col)
	# 头（低头啄食）+ 喙 + 冠
	var hy := y - 10.4 + peck * 3.4
	draw_circle(Vector2(px + 3.4, hy), 2.1, col)
	Draw.stroke(self, [Vector2(px + 4.6, hy + 0.4), Vector2(px + 6.8, hy + 1.6 - peck * 1.2)], 1.4, 0.7, col)
	draw_line(Vector2(px + 2.6, hy - 2.4), Vector2(px + 3.4, hy - 1.2), Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b, 0.55), 1.2, true)

func _petals() -> void:
	if stage < Build.PETAL_AT:
		return
	if season == 3:
		return
	var pc := Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b)
	var amul := 1.0
	if season == 1:
		pc = Color(0.35, 0.52, 0.30)
		amul = 0.9
	elif season == 2:
		pc = Color(0.74, 0.55, 0.22)
		amul = 1.3
	var xs: Array = [1636.0, 1652.0, 1668.0, 1684.0, 1698.0, 1284.0, 1300.0, 1316.0]
	for i in xs.size():
		var x0: float = xs[i]
		if not Draw.vis(cam, x0 - 48.0, x0 + 48.0):
			continue
		var ph := fposmod(t / Conf.PETAL_RATE + float(i) * 0.137, 1.0)
		var x := x0 + sin(ph * 6.4 + float(i) * 1.9) * 17.0
		var y := 498.0 + ph * 272.0
		var rot := sin(ph * 9.0 + float(i)) * 1.5
		var a := sin(PI * ph) * (0.30 + 0.12 * sin(float(i) * 2.3)) * amul
		# 两笔交叉 → 像一片旋着落的花瓣
		Draw.stroke(self, [Vector2(x, y), Vector2(x + 3.2 + rot, y + 4.2 - rot * 0.6)], 2.2, 0.6, Color(pc.r, pc.g, pc.b, a))
		Draw.stroke(self, [Vector2(x + 0.6, y + 0.8), Vector2(x - 1.6 + rot * 0.8, y + 3.4)], 1.4, 0.5, Color(pc.r, pc.g, pc.b, a * 0.7))

# ============ 冬装：地上积雪 + 前层落雪 ============

func _winter_dress() -> void:
	if season != 3:
		return
	# 地上积雪（软白几片）
	var gxs: Array = [320.0, 700.0, 980.0, 1240.0, 1520.0, 1840.0, 2120.0, 2420.0]
	for i in gxs.size():
		var x: float = gxs[i]
		if not Draw.vis(cam, x - 120.0, x + 120.0):
			continue
		Draw.ellipse(self, Vector2(x, 826.0 + sin(float(i) * 2.2) * 6.0), 96.0, 11.0 / Draw.sy(), Color(0.97, 0.97, 0.99, 0.11))
	# 路上压实的一道白
	Draw.stroke(self, [Vector2(700.0, 828.0), Vector2(1080.0, 806.0), Vector2(1460.0, 784.0)], 7.0, 2.6, Color(0.97, 0.97, 0.99, 0.15))
	# 前层落雪（盖过屋顶往后飘）
	for i in 14:
		var spd := 0.05 + 0.016 * float(i % 3)
		var p := fposmod(t * spd + float(i) * 0.191, 1.0)
		var x := 30.0 + fposmod(float(i) * 149.0 + sin(p * 5.0 + float(i)) * 18.0, 2760.0)
		if not Draw.vis(cam, x - 10.0, x + 10.0):
			continue
		var y := 460.0 + p * 340.0
		var r := 1.1 + 0.5 * float(i % 3)
		draw_circle(Vector2(x, y), r, Color(0.97, 0.97, 0.99, 0.50))

# ============ 左端云雾：后山 / 山洞各一片（解锁时向左上退开） ============

func _fog_left() -> void:
	if backhill_open:
		if _bh_t < 0.0:
			_bh_t = t
	else:
		_bh_t = -1.0
	if show_cave:
		if _cv_t < 0.0:
			_cv_t = t
	else:
		_cv_t = -1.0
	_fog_patch(660.0, backhill_open, 212.0, _bh_t)
	_fog_patch(470.0, show_cave, 168.0, _cv_t)

func _fog_patch(x: float, open: bool, span: float, open_t: float) -> void:
	if not Draw.vis(cam, x - span, x + span):
		return
	var k := 1.0
	if open:
		k = 0.0 if open_t < 0.0 else clampf(1.0 - (t - open_t) / 2.2, 0.0, 1.0)
	# 大云：未解锁时盖住；解锁后 2.2 秒内向左上退、同时变淡
	if k > 0.02:
		var dx := (1.0 - k) * span * 0.75
		var dy := (1.0 - k) * 14.0
		Draw.ellipse(self, Vector2(x - dx, 720.0 - dy), span * 1.04, 40.0 / Draw.sy(), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.60 * k))
		Draw.ellipse(self, Vector2(x - span * 0.42 - dx, 732.0 - dy), span * 0.62, 30.0 / Draw.sy(), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.52 * k))
		Draw.ellipse(self, Vector2(x + span * 0.46 - dx, 706.0 - dy), span * 0.56, 26.0 / Draw.sy(), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.46 * k))
		Draw.ellipse(self, Vector2(x - dx, 694.0 - dy), span * 0.72, 22.0 / Draw.sy(), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.40 * k))
		Draw.ellipse(self, Vector2(x - dx * 0.5, 748.0 - dy), span * 0.86, 14.0 / Draw.sy(), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.045 * k))
	# 漂着的碎云：解锁后只留薄雾
	var a := lerpf(0.085, 0.32, k)
	for i in 6:
		var ph := fposmod(t * (0.02 + 0.006 * float(i % 3)) + float(i) * 0.163, 1.0)
		var cx := x - span + ph * span * 2.0
		var cy := 712.0 + sin(float(i) * 2.1 + t * 0.42) * 16.0 - float(i % 3) * 16.0
		var rx := 46.0 + 20.0 * float(i % 4)
		Draw.ellipse(self, Vector2(cx, cy), rx, (rx * 0.40) / Draw.sy(), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, a))
		Draw.ellipse(self, Vector2(cx + rx * 0.30, cy - 7.0), rx * 0.52, (rx * 0.24) / Draw.sy(), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, a * 0.80))

# ============ 门外的弟子 ============

func _disciple() -> void:
	# 入门之后交给顶层立绘（TopVeil）画——这里让位，免得上下一叠成两个人
	if disciple_joined:
		return
	var x := 1668.0
	var y := 776.0
	if not Draw.vis(cam, x - 34.0, x + 34.0):
		return
	var bob := sin(t * 1.1) * 0.7
	var look := sin(t * 0.23) * 1.6
	Draw.mini_person(self, x + look, y, -1.0, 1.0 + bob * 0.15, bob, false)
