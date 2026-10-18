extends Node2D
# ============================================================
# menu_mount.gd —— 装裱层（拆分 4/6）：隔水 / 引首《书名》/ 题跋 / 包边 / 木轴
#                   / 左右两卷 / 画布外遮罩
# v5.2 改：左端"封面的竖杠"＝【左隔水绢块＋两条竖框线】＋【左木轴】——
#   这一层画在村子层"上面"，所以那道框线正好把后山图切成两半。
#   现在两样一起拔：show_left_mount 默认 false。想回来：改 true（三样一起回）。
# v5.1 改：左端"题跋"整段铲掉——连那块绢面（"封面"）都不画（show_weiba）。
# v4.1 修：卷筒改为钉在"可见窗口"两侧（内部平移 +cam）。
# ============================================================

const Conf := preload("res://menu/menu_conf.gd")
const Draw := preload("res://menu/menu_draw.gd")
const Ui := preload("res://menu/menu_theme.gd")   # v200：影之刃皮肤

var t := 0.0
var cam := 0.0
var font: Font = null
var _brush: Font = null
var show_weiba := false        # 左端题跋（"结束语"＋封面绢面）：想要回来改 true
var show_left_mount := false   # 左端装裱件（隔水绢块＋两条竖框线＋左木轴）：它们正压在后山图上，默认全不画

func _ready() -> void:
	if font == null:
		font = ThemeDB.fallback_font
	if Ui.SKIN == 1 and ResourceLoader.exists(Ui.FONT_BRUSH):
		var r: Resource = load(Ui.FONT_BRUSH)
		if r is Font:
			_brush = r as Font

# v98：两页画卷的总长只有 1440（封面页 + 村景页），不是老的 3000 长卷——
#   所以卷口大小改由外面喂 roll_ratio（0=村景页铺满 · 1=封面页铺满）。不喂就照老规矩看 cam。
var roll_ratio := -1.0

func _ratio() -> float:
	if roll_ratio >= 0.0:
		return clampf(roll_ratio, 0.0, 1.0)
	return cam / Conf.CAM_MAX

func roll_l() -> float:
	return Conf.ROLL_MAX * sqrt(_ratio())

func roll_r() -> float:
	return Conf.ROLL_MAX * sqrt(clampf(1.0 - _ratio(), 0.0, 1.0))

func _draw() -> void:
	if font == null:
		font = ThemeDB.fallback_font
	_yinshou()
	_gap_rect(Conf.GAP_R0, Conf.GAP_R1)
	if show_left_mount:
		_gap_rect(Conf.GAP_L0, Conf.GAP_L1)
	_weiba()
	draw_rect(Rect2(0, Conf.BAND_TOP, Conf.STRIP_W, Conf.MOUNT), Conf.MOUNT_C)
	draw_rect(Rect2(0, Conf.CONTENT_BOT, Conf.STRIP_W, Conf.MOUNT), Conf.MOUNT_C)
	draw_rect(Rect2(0, Conf.BAND_TOP, Conf.STRIP_W, 2.0), Color(0.22, 0.16, 0.10, 0.36))
	draw_rect(Rect2(0, Conf.CONTENT_TOP - 2.0, Conf.STRIP_W, 2.0), Color(0.22, 0.16, 0.10, 0.20))
	draw_rect(Rect2(0, Conf.CONTENT_BOT, Conf.STRIP_W, 2.0), Color(0.22, 0.16, 0.10, 0.20))
	draw_rect(Rect2(0, Conf.BAND_TOP + Conf.BAND_H - 2.0, Conf.STRIP_W, 2.0), Color(0.22, 0.16, 0.10, 0.36))
	_rod(Conf.STRIP_W - 16.0)
	if show_left_mount:
		_rod(0.0)
	_draw_roll(true)
	_draw_roll(false)
	_cut()

# 引首（右端）：竖排书名 + 印章
func _yinshou() -> void:
	if not Draw.vis(cam, Conf.YINSHOU_X0 - 20.0, Conf.YINSHOU_X1 + 20.0):
		return
	draw_rect(Rect2(Conf.YINSHOU_X0, Conf.CONTENT_TOP, Conf.YINSHOU_X1 - Conf.YINSHOU_X0, Conf.CONTENT_BOT - Conf.CONTENT_TOP), Conf.YIN_C)
	draw_line(Vector2(Conf.YINSHOU_X0, Conf.CONTENT_TOP), Vector2(Conf.YINSHOU_X0, Conf.CONTENT_BOT), Color(0.25, 0.18, 0.12, 0.25), 1.5)
	var cx := Conf.YINSHOU_CX
	var n := Conf.TITLE.length()
	var y0 := 479.0 - float(n - 1) * 56.0
	if Ui.SKIN == 1:
		# v200：金漆书名 + 内框 + 四角标（影之刃的"引首"做法）
		var fr := Rect2(Conf.YINSHOU_X0 + 12.0, Conf.CONTENT_TOP + 26.0,
			Conf.YINSHOU_X1 - Conf.YINSHOU_X0 - 24.0, Conf.CONTENT_BOT - Conf.CONTENT_TOP - 52.0)
		Ui.panel(self, fr, {"fill": Color(0.0, 0.0, 0.0, 0.0), "edge": Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.42),
			"cut": 8.0, "bracket": true, "shadow": 0.0, "ink_halo": false, "no_hi": true})
		var f: Font = _brush if _brush != null else font
		# ⚠ 纸面上不能用亮金（#F0D68A 压在 #EDE7D8 上几乎看不见）——
		#   改成**墨字描金边**：金在外圈提气，墨在内里压住，远看就是"金字招牌"。
		for i in n:
			var tp := Vector2(cx - 56.0, y0 + float(i) * 112.0 + 34.0)
			var ch := Conf.TITLE.substr(i, 1)
			draw_string_outline(f, tp, ch, HORIZONTAL_ALIGNMENT_CENTER, 112.0, 84, 6, Color(0.80, 0.63, 0.26, 0.90))
			draw_string(f, tp, ch, HORIZONTAL_ALIGNMENT_CENTER, 112.0, 84, Color(0.098, 0.082, 0.078, 0.97))
		_seal(Vector2(cx, y0 + float(n) * 112.0 + 54.0), 58.0, "无名")
		draw_string(font, Vector2(cx - 110.0, 898.0), "一 卷 山 水", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 20,
			Color(0.62, 0.48, 0.18, 0.80))
		return
	for i in n:
		draw_string(font, Vector2(cx - 56.0, y0 + float(i) * 112.0 + 32.0), Conf.TITLE.substr(i, 1), HORIZONTAL_ALIGNMENT_CENTER, 112.0, 76, Conf.INK)
	_seal(Vector2(cx, y0 + float(n) * 112.0 + 49.0), 56.0, "无名")
	draw_string(font, Vector2(cx - 110.0, 881.0), "一 卷 山 水", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 21, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.35))

# 题跋（卷首那段题记）：六列竖排 + 两方印 + 卷末一句。
#   v98b：改成**按 weiba_x / weiba_w 摆**——默认还是老位置（卷最左端 0~590），
#   新主界面把它挪到"封面页的左半边"（2280~2670，正好在隔水与《少年游》引首的左边），
#   省得那半边留一张空纸（用户："这左半边是干嘛的"）。
var weiba_x := 0.0
var weiba_w := 590.0

func _weiba() -> void:
	if not show_weiba:
		return
	if not Draw.vis(cam, weiba_x, weiba_x + weiba_w):
		return
	draw_rect(Rect2(weiba_x, Conf.CONTENT_TOP, weiba_w, Conf.CONTENT_BOT - Conf.CONTENT_TOP), Conf.WEI_C)
	draw_line(Vector2(weiba_x, Conf.CONTENT_TOP), Vector2(weiba_x, Conf.CONTENT_BOT), Color(0.25, 0.18, 0.12, 0.25), 1.5)
	draw_line(Vector2(weiba_x + weiba_w, Conf.CONTENT_TOP), Vector2(weiba_x + weiba_w, Conf.CONTENT_BOT), Color(0.25, 0.18, 0.12, 0.25), 1.5)
	if Ui.SKIN == 1:
		# v200：题记加一道内框 + 四角标（纸面留白，只收边，不压暗）
		var fr := Rect2(weiba_x + 16.0, Conf.CONTENT_TOP + 24.0, weiba_w - 32.0, Conf.CONTENT_BOT - Conf.CONTENT_TOP - 48.0)
		Ui.panel(self, fr, {"fill": Color(0.0, 0.0, 0.0, 0.0), "edge": Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.34),
			"cut": 8.0, "bracket": true, "shadow": 0.0, "ink_halo": false, "no_hi": true})
		# 下半留白补两片淡远山：只加层次，不抢题记
		_ink_ridge(weiba_x + 28.0, Conf.CONTENT_BOT - 118.0, weiba_w - 56.0, 0.10, 1.0)
		_ink_ridge(weiba_x + 28.0, Conf.CONTENT_BOT - 60.0, weiba_w - 56.0, 0.07, 2.3)
	var dn := Conf.DISCIPLE_NAME
	var cols: Array = [
		["此卷记一少年", 418.0, 29.0],
		["自山门而下", 418.0, 29.0],
		["斩贼于野", 430.0, 29.0],
		["至" + Conf.VILLAGE_NAME, 430.0, 29.0],
		["村破·与村人共修", 430.0, 27.0],
		["得一徒" + ("·" + dn if dn != "" else ""), 442.0, 27.0],
	]
	var step := (weiba_w - 92.0) / float(cols.size() - 1)
	for i in cols.size():
		var c: Array = cols[i]
		_vtext(str(c[0]), weiba_x + weiba_w - 46.0 - float(i) * step, float(c[1]), float(c[2]))
	_seal(Vector2(weiba_x + weiba_w - 46.0, 806.0), 42.0, "记")
	_seal(Vector2(weiba_x + 46.0, 806.0), 46.0, "无名")
	var foot_c := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.40)
	if Ui.SKIN == 1:
		foot_c = Color(0.60, 0.46, 0.17, 0.72)
	draw_string(font, Vector2(weiba_x, 869.0), "—— 未完 · 待续 ——", HORIZONTAL_ALIGNMENT_CENTER, weiba_w, 21, foot_c)

func _gap_rect(x0: float, x1: float) -> void:
	if not Draw.vis(cam, x0, x1):
		return
	draw_rect(Rect2(x0, Conf.CONTENT_TOP, x1 - x0, Conf.CONTENT_BOT - Conf.CONTENT_TOP), Conf.GAP_C)
	draw_line(Vector2(x0, Conf.CONTENT_TOP), Vector2(x0, Conf.CONTENT_BOT), Color(0.25, 0.18, 0.12, 0.25), 1.5)
	draw_line(Vector2(x1, Conf.CONTENT_TOP), Vector2(x1, Conf.CONTENT_BOT), Color(0.25, 0.18, 0.12, 0.25), 1.5)

# 淡墨远山（封面页下半的留白）：一道起伏的墨坡，alpha 很低，只当水印
func _ink_ridge(x0: float, y0: float, w: float, a: float, ph: float) -> void:
	var n := 11
	var pts := PackedVector2Array([Vector2(x0, y0 + 60.0)])
	for i in n:
		var tx := x0 + w * float(i) / float(n - 1)
		var hh := 22.0 + 26.0 * sin(float(i) * 1.15 + ph) + 12.0 * sin(float(i) * 2.7 + ph * 1.9)
		pts.append(Vector2(tx, y0 - hh))
	pts.append(Vector2(x0 + w, y0 + 60.0))
	draw_colored_polygon(pts, Color(0.16, 0.15, 0.17, a))

func _vtext(s: String, x: float, y0: float, fs: float) -> void:
	for i in s.length():
		draw_string(font, Vector2(x - 30.0, y0 + float(i) * (fs + 7.0)), s.substr(i, 1), HORIZONTAL_ALIGNMENT_CENTER, 60.0, int(fs), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.68))

func _seal(c: Vector2, sz: float, s: String) -> void:
	var col := Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b, 0.84)
	if Ui.SKIN == 1:
		col = Color(0.706, 0.157, 0.118, 0.94)
	draw_colored_polygon(Draw.round_poly(Rect2(c.x - sz * 0.5, c.y - sz * 0.5, sz, sz), 4.0), col)
	if Ui.SKIN == 1:
		var rp := Draw.round_poly(Rect2(c.x - sz * 0.5 + 3.0, c.y - sz * 0.5 + 3.0, sz - 6.0, sz - 6.0), 3.0)
		rp.append(rp[0])
		draw_polyline(rp, Color(Ui.GOLD_HI.r, Ui.GOLD_HI.g, Ui.GOLD_HI.b, 0.42), 1.0, true)
	var fs := int(sz * 0.42)
	var n := s.length()
	for i in n:
		var ox := (float(i) - float(n - 1) * 0.5) * float(fs) * 1.25
		draw_string(font, Vector2(c.x + ox - 12.0, c.y + sz * 0.16), s.substr(i, 1), HORIZONTAL_ALIGNMENT_CENTER, 24.0, fs, Color(0.97, 0.94, 0.88, 0.92))

func _rod(x: float) -> void:
	if not Draw.vis(cam, x, x + 20.0):
		return
	draw_rect(Rect2(x, Conf.BAND_TOP - 8.0, 12.0, Conf.BAND_H + 16.0), Conf.WOOD_L)
	draw_circle(Vector2(x + 6.0, Conf.BAND_TOP - 10.0), 5.0, Color(0.36, 0.27, 0.19))
	draw_circle(Vector2(x + 6.0, Conf.BAND_TOP + Conf.BAND_H + 10.0), 5.0, Color(0.36, 0.27, 0.19))

# 左右两卷：钉在"可见窗口"的两边（不随卷子滚动、随拖动伸缩）。
# 本层变换里带了 -cam，所以这里先平移 +cam：画的 0..DW 就是屏幕上那 720 宽的可视画布。
func _draw_roll(is_left: bool) -> void:
	var rw: float = roll_l() if is_left else roll_r()
	if rw < 2.0:
		return
	draw_set_transform(Vector2(cam, 0.0))
	var x0: float = 0.0 if is_left else Conf.DW - rw
	draw_rect(Rect2(x0 + 3.0, Conf.BAND_TOP + 8.0, rw, Conf.BAND_H + 8.0), Color(0.08, 0.06, 0.05, 0.06))
	var r := Rect2(x0, Conf.BAND_TOP - 6.0, rw, Conf.BAND_H + 12.0)
	var px: float = x0 + rw * 0.5
	draw_rect(Rect2(px - 3.0, Conf.BAND_TOP - 14.0, 6.0, Conf.BAND_H + 28.0), Conf.WOOD_L)
	draw_circle(Vector2(px, Conf.BAND_TOP - 16.0), 4.0, Color(0.36, 0.27, 0.19))
	draw_circle(Vector2(px, Conf.BAND_TOP + Conf.BAND_H + 16.0), 4.0, Color(0.36, 0.27, 0.19))
	draw_rect(r, Conf.BACK_C)
	var n := 14
	var bw := (rw * 0.5) / float(n)
	for k in n:
		var a := 0.15 * pow(1.0 - float(k) / float(n), 1.6)
		draw_rect(Rect2(x0 + float(k) * bw, r.position.y, bw, r.size.y), Color(0.20, 0.14, 0.09, a))
		draw_rect(Rect2(x0 + rw - float(k + 1) * bw, r.position.y, bw, r.size.y), Color(0.20, 0.14, 0.09, a))
	for k in 5:
		var hw := (float(k) + 1.0) * rw * 0.09
		draw_rect(Rect2(px - hw, r.position.y, hw * 2.0, r.size.y), Color(Conf.PAPER.r, Conf.PAPER.g, Conf.PAPER.b, 0.045))
	Draw.ellipse(self, Vector2(px, Conf.BAND_TOP - 4.0), rw * 0.5, rw * 0.15, Conf.CAP_C)
	Draw.ellipse(self, Vector2(px, Conf.BAND_TOP - 4.0), rw * 0.34, rw * 0.10, Conf.CAP_C2)
	Draw.ellipse(self, Vector2(px, Conf.BAND_TOP - 4.0), rw * 0.16, rw * 0.05, Conf.CAP_C)
	draw_circle(Vector2(px, Conf.BAND_TOP - 4.0), maxf(4.0, rw * 0.045), Color(0.30, 0.22, 0.15))
	Draw.ellipse(self, Vector2(px, Conf.BAND_TOP + Conf.BAND_H + 4.0), rw * 0.5, rw * 0.15, Conf.CAP_C)
	Draw.ellipse(self, Vector2(px, Conf.BAND_TOP + Conf.BAND_H + 4.0), rw * 0.34, rw * 0.10, Conf.CAP_C2)
	Draw.ellipse(self, Vector2(px, Conf.BAND_TOP + Conf.BAND_H + 4.0), rw * 0.16, rw * 0.05, Conf.CAP_C)
	draw_circle(Vector2(px, Conf.BAND_TOP + Conf.BAND_H + 4.0), maxf(4.0, rw * 0.045), Color(0.30, 0.22, 0.15))
	var ex: float = x0 + rw if is_left else x0
	var dir := 1.0 if is_left else -1.0
	draw_line(Vector2(ex, Conf.BAND_TOP - 4.0), Vector2(ex, Conf.BAND_TOP + Conf.BAND_H + 4.0), Color(0.98, 0.96, 0.90, 0.45), 1.5)
	for k in 3:
		draw_rect(Rect2(ex + dir * (2.0 + float(k) * 4.0), Conf.BAND_TOP - 2.0, 5.0, Conf.BAND_H + 4.0), Color(0.05, 0.04, 0.03, 0.05))
	draw_set_transform(Vector2.ZERO)

# 画布外遮罩：卷子整条 3000 宽，纸/包边/框线会铺到可视窗口之外，画完用底色盖回。
func _cut() -> void:
	draw_rect(Rect2(cam - 10000.0, Conf.BAND_TOP - 40.0, 10000.0, Conf.BAND_H + 80.0), Conf.BG_C)
	draw_rect(Rect2(cam + Conf.DW, Conf.BAND_TOP - 40.0, 10000.0, Conf.BAND_H + 80.0), Conf.BG_C)
