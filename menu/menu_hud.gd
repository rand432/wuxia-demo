extends Node2D
# ============================================================
# menu_hud.gd —— 界面层（拆分 5/6）：底部按钮 + 提示 + 浮条 + 页脚
# 固定贴屏幕，不随卷滚动。按钮矩形/按下态由 menu_sketch.gd 算好，本层只画。
# v7：底排第 4 格由本层直画「宠物」——不再靠 menu_sketch 盖按钮遮「设置」。
#     有白狐时字面自动变「宠物·幼狐」……（字号超 3 字自动缩到 17）。
# v6 旧注：浮条＝屏幕正中大字，自动折行（每行 26 字，最多 4 行），带投影。
# v5 旧注：页脚带村况与相机读数（都是暂时的，删各自那一行即可）。
# ============================================================

const Conf := preload("res://menu/menu_conf.gd")
const Draw := preload("res://menu/menu_draw.gd")
const Build := preload("res://menu/data_build.gd")
const GameState := preload("res://shared/game_state.gd")

var t := 0.0
var font: Font = null
var host = null      # menu_sketch.gd 塞进来

func _draw() -> void:
	if host == null or font == null:
		return
	if host._panel_open:
		_draw_panel()
		return
	_draw_hint()
	_draw_toast()
	_draw_tags()
	var st: Dictionary = Build.STAGES[int(host._stage)]
	draw_string(font, Vector2(0.0, 1260.0), "主界面 v7 · 村况 " + str(int(host._stage)) + "/" + str(Build.STAGE_MAX) + "·" + str(st["name"]) + " · 卷 " + str(int(host._cam)) + "/" + str(int(Conf.CAM_MAX)), HORIZONTAL_ALIGNMENT_RIGHT, Conf.DW - 18.0, 15, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.32))

func _draw_hint() -> void:
	# v97：镜头钉死（PIN_CAM）＝不再有"拖开画卷"这回事，提示语一并撤掉
	if host.PIN_CAM:
		return
	if host._hint_a <= 0.02 or host._toast_t > 0.0:
		return
	var a: float = host._hint_a * (0.65 + 0.35 * sin(t * 2.2))
	draw_string(font, Vector2(0, Conf.HINT_Y), "按住画卷 · 向右拖开", HORIZONTAL_ALIGNMENT_CENTER, Conf.DW, 20, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.50 * a))
	var ax := Conf.DW * 0.5 + 104.0 + fposmod(t * 50.0, 36.0) - 18.0
	draw_line(Vector2(ax, Conf.HINT_Y - 7.0), Vector2(ax + 16.0, Conf.HINT_Y - 7.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.55 * a), 3.0)
	draw_line(Vector2(ax + 16.0, Conf.HINT_Y - 7.0), Vector2(ax + 9.0, Conf.HINT_Y - 12.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.55 * a), 3.0)
	draw_line(Vector2(ax + 16.0, Conf.HINT_Y - 7.0), Vector2(ax + 9.0, Conf.HINT_Y - 2.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.55 * a), 3.0)

# 浮条：屏幕正中，大字，自动折行（每行 26 字，最多 4 行）
func _draw_toast() -> void:
	if host._toast == "" or host._toast_t <= 0.0:
		return
	var txt := str(host._toast)
	var a := clampf(host._toast_t / 0.5, 0.0, 1.0)
	var fs := 24
	var per := 26
	var lines: Array = []
	var i := 0
	while i < txt.length() and lines.size() < 4:
		lines.append(txt.substr(i, per))
		i += per
	var lh := 36.0
	var h := 30.0 + lh * float(lines.size())
	var maxw := 0.0
	for ln in lines:
		maxw = maxf(maxw, float(str(ln).length()) * float(fs) * 1.04)
	var w := minf(maxw + 64.0, Conf.DW - 36.0)
	var x := (Conf.DW - w) * 0.5
	var ty := (Conf.DH - h) * 0.5
	draw_colored_polygon(Draw.round_poly(Rect2(x + 4.0, ty + 6.0, w, h), 12.0), Color(0.06, 0.05, 0.05, 0.26 * a))
	draw_colored_polygon(Draw.round_poly(Rect2(x, ty, w, h), 12.0), Color(Conf.CHIP_C.r, Conf.CHIP_C.g, Conf.CHIP_C.b, 0.97 * a))
	var bp := Draw.round_poly(Rect2(x, ty, w, h), 12.0)
	bp.append(bp[0])
	draw_polyline(bp, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.38 * a), 1.8)
	var yy := ty + 34.0
	for ln in lines:
		draw_string(font, Vector2(x, yy), str(ln), HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.90 * a))
		yy += lh

func _pet_label() -> String:
	# 底排第 4 格：没狐＝「宠物」；有狐＝「宠物·幼狐」……（太长会自动缩字号）
	if GameState.pet_id == "":
		return "宠物"
	return "宠物·" + GameState.pet_stage_name()

func _draw_tags() -> void:
	for i in host._tag_rects.size():
		if i >= Conf.TAGN.size():
			continue
		var txt := str(Conf.TAGN[i])
		if i == 3:
			txt = _pet_label()   # v7：原「设置」格——现在直画宠物字样（设置以后并进「石桌」）
		_draw_tag(host._tag_rects[i] as Rect2, txt, i == 0, host._pressed_tag == i, i)
		if i == Conf.TAG_CHEST:
			_draw_chest_badge(host._tag_rects[i] as Rect2)
		if i == host._tag_notice:
			var rc: Rect2 = host._tag_rects[i]
			draw_circle(Vector2(rc.end.x - 14.0, rc.position.y + 14.0), 6.0, Conf.SEAL_C)

# v4.2：宝箱那一格的"栏位"标记——右上角一枚小箱子 + 攒着的个数；
#   有货时箱盖缝透一线金光，再加个红点（跟咸鱼之王底排那种"可开"提示一个意思）。
func _draw_chest_badge(rc: Rect2) -> void:
	var n := GameState.chest_total()
	var bx := rc.end.x - 30.0
	var by := rc.position.y + 8.0
	var w := 22.0
	var h := 17.0
	var base := Color(0.62, 0.50, 0.34, 0.95) if n > 0 else Color(0.55, 0.52, 0.48, 0.45)
	var line := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.55)
	# 箱身
	draw_rect(Rect2(bx, by + h * 0.42, w, h * 0.58), base, true)
	# 盖子（有货就掀开一条缝，缝里透金光）
	var open := 2.6 if n > 0 else 0.0
	var lid_r := Rect2(bx - 1.0, by + h * 0.42 - 6.0 - open, w + 2.0, 6.0)
	if n > 0:
		draw_rect(Rect2(bx + 1.0, by + h * 0.42 - open, w - 2.0, open + 1.0), Color(1.0, 0.90, 0.55, 0.85), true)
	draw_rect(lid_r, base.lightened(0.12), true)
	# 箍与锁扣
	draw_line(Vector2(bx + w * 0.5, by + h * 0.10), Vector2(bx + w * 0.5, by + h), Color(0.90, 0.82, 0.58, 0.75), 2.0)
	draw_rect(Rect2(bx + w * 0.42, by + h * 0.52, 4.0, 5.0), Color(0.88, 0.80, 0.56, 0.90), true)
	draw_rect(Rect2(bx, by + h * 0.42, w, h * 0.58), line, false, 1.2)
	draw_rect(lid_r, line, false, 1.2)
	# 个数（红点＋数字：红点＝有货，数字＝几个）
	if n > 0:
		draw_circle(Vector2(bx + w + 2.0, by - 1.0), 7.0, Conf.SEAL_C)
		draw_string(font, Vector2(bx + w - 6.0, by + 3.0), str(mini(n, 99)), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 12, Color(0.98, 0.95, 0.90, 0.96))

# v93g（用户："底部那排按钮也要换 ui"）：**整套重画**。
#   原来是"圆角纸片 + 一行字"，看着像网页按钮。现在按**木牌/签**来画：
#     落影 → 牌面（上亮下暗，像有厚度） → 双线边（主格再套一道朱红内框）
#     → 顶上一个小墨字图标（剑/人/囊/爪/箱/册） → 底下一行字。
#   ⚠ 命中区（_tag_rects）**一个像素都没动**，只是画法变了，按钮行为不受影响。
func _draw_tag(rc: Rect2, txt: String, primary: bool, pressed: bool, idx: int = -1) -> void:
	var off := 3.0 if pressed else 0.0
	var r := Rect2(rc.position + Vector2(0, off), rc.size)
	var base: Color = Conf.CHIP_P if primary else Conf.CHIP_C
	if pressed:
		base = base.darkened(0.08)
	# ① 落影（按下去就收掉，才有"按进去"的手感）
	if not pressed:
		draw_colored_polygon(Draw.round_poly(Rect2(r.position + Vector2(0, 3.5), r.size), 10.0), Color(0.06, 0.05, 0.05, 0.20))
	# ② 牌面：上亮下暗，做出一点厚度
	draw_colored_polygon(Draw.round_poly(r, 10.0), base)
	draw_colored_polygon(Draw.round_poly(Rect2(r.position + Vector2(2.0, 2.0), r.size - Vector2(4.0, 4.0)), 9.0), base.lightened(0.06))
	draw_colored_polygon(Draw.round_poly(Rect2(r.position + Vector2(4.0, r.size.y * 0.52), Vector2(r.size.x - 8.0, r.size.y * 0.46)), 8.0), base.darkened(0.05))
	# ③ 边线：外墨线；主格再套一道朱红细框
	var bp := Draw.round_poly(r, 10.0)
	bp.append(bp[0])
	draw_polyline(bp, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.42), 1.6)
	if primary:
		var bp2 := Draw.round_poly(Rect2(r.position + Vector2(3.5, 3.5), r.size - Vector2(7.0, 7.0)), 8.0)
		bp2.append(bp2[0])
		draw_polyline(bp2, Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b, 0.50), 1.3)
	# ④ 图标：画在字上面
	var ic: Color = Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.74)
	if primary:
		ic = Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b, 0.88)
	var cx := r.position.x + r.size.x * 0.5
	draw_set_transform(Vector2(cx, r.position.y + 27.0), 0.0, Vector2.ONE)
	_draw_tag_icon(idx, Vector2.ZERO, 12.0, ic)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# ⑤ 文字：往下压，给图标让位
	var fs := 25 if primary else 22
	if txt.length() > 3:
		fs = 17     # 宠物·幼狐 这类五六字
	draw_string(font, Vector2(r.position.x, r.position.y + r.size.y - 11.0), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.86))

# 六个格子的图标：全部用最少的线条画，走"墨"的味道（不引美术资源，随时能改）
func _draw_tag_icon(i: int, c: Vector2, s: float, col: Color) -> void:
	match i:
		0:   # 开始历练 = 剑
			draw_line(c + Vector2(-s * 0.85, s * 0.85), c + Vector2(s * 0.62, -s * 0.72), col, 2.2)
			draw_line(c + Vector2(-s * 0.5, s * 0.12), c + Vector2(s * 0.05, s * 0.68), col, 1.8)   # 护手
			draw_circle(c + Vector2(-s * 0.95, s * 0.95), 2.0, col)
		1:   # 弟子 = 人
			draw_circle(c + Vector2(0.0, -s * 0.5), s * 0.34, col)
			draw_arc(c + Vector2(0.0, s * 0.85), s * 0.66, PI, TAU, 18, col, 2.3)
		2:   # 行囊 = 包袱
			draw_arc(c + Vector2(0.0, -s * 0.22), s * 0.46, PI * 1.12, PI * 1.88, 14, col, 2.0)
			var b := Rect2(c + Vector2(-s * 0.66, -s * 0.16), Vector2(s * 1.32, s * 0.98))
			draw_rect(b, col, false, 2.2)
			draw_line(c + Vector2(-s * 0.66, s * 0.22), c + Vector2(s * 0.66, s * 0.22), col, 1.5)
		3:   # 宠物 = 爪印
			draw_circle(c + Vector2(0.0, s * 0.28), s * 0.42, col)
			for k in 3:
				draw_circle(c + Vector2(-s * 0.55 + float(k) * s * 0.55, -s * 0.42), s * 0.19, col)
		4:   # 宝箱 = 箱子
			var bw := s * 1.7
			var bh := s * 1.05
			var br := Rect2(c + Vector2(-bw * 0.5, -bh * 0.5), Vector2(bw, bh))
			draw_rect(br, col, false, 2.2)
			draw_line(c + Vector2(-bw * 0.5, -bh * 0.5 + bh * 0.42), c + Vector2(bw * 0.5, -bh * 0.5 + bh * 0.42), col, 1.8)
			draw_rect(Rect2(c + Vector2(-s * 0.16, -bh * 0.5 + bh * 0.34), Vector2(s * 0.32, s * 0.34)), col, true)
		5:   # 阅历 = 卷册
			draw_rect(Rect2(c + Vector2(-s * 0.75, -s * 0.6), Vector2(s * 1.5, s * 1.2)), col, false, 2.2)
			draw_line(c + Vector2(-s * 0.2, -s * 0.6), c + Vector2(-s * 0.2, s * 0.6), col, 1.5)
			draw_line(c + Vector2(s * 0.2, -s * 0.6), c + Vector2(s * 0.2, s * 0.6), col, 1.5)

# 弟子小板（点按钮开，点任意处关）
func _draw_panel() -> void:
	draw_rect(Rect2(0, 0, Conf.DW, Conf.DH), Color(0.08, 0.07, 0.08, 0.58))
	var r := Rect2(76.0, 372.0, 568.0, 486.0)
	draw_rect(Rect2(r.position + Vector2(4.0, 6.0), r.size), Color(0.06, 0.05, 0.05, 0.30))
	draw_colored_polygon(Draw.round_poly(r, 14.0), Color(0.955, 0.937, 0.886, 0.98))
	var bp := Draw.round_poly(r, 14.0)
	bp.append(bp[0])
	draw_polyline(bp, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.45), 2.0)
	draw_string(font, Vector2(r.position.x, 424.0), "弟　子", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.72))
	draw_line(Vector2(r.position.x + 40.0, 442.0), Vector2(r.end.x - 40.0, 442.0), Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.18), 1.2)
	draw_string(font, Vector2(r.position.x, 506.0), Conf.DISCIPLE_NAME, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 38, Conf.SEAL_C)
	draw_string(font, Vector2(r.position.x, 556.0), Conf.DISCIPLE_QUOTE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.85))
	var lx := r.position.x + 56.0
	var lw := r.size.x - 112.0
	var c1 := Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.80)
	var sg: Dictionary = Build.STAGES[int(host._stage)]
	draw_string(font, Vector2(lx, 622.0), "来　历：" + Conf.DISCIPLE_ORIGIN, HORIZONTAL_ALIGNMENT_LEFT, lw, 17, c1)
	draw_string(font, Vector2(lx, 654.0), "起　因：你应下了重修村子的事", HORIZONTAL_ALIGNMENT_LEFT, lw, 17, c1)
	draw_string(font, Vector2(lx, 686.0), "状　态：随行中（第一个弟子）", HORIZONTAL_ALIGNMENT_LEFT, lw, 17, c1)
	draw_string(font, Vector2(lx, 718.0), "村　况：第 " + str(int(host._stage)) + " 段 · " + str(sg["name"]) + "——" + str(sg["note"]), HORIZONTAL_ALIGNMENT_LEFT, lw, 15, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.66))
	draw_string(font, Vector2(lx, 756.0), Conf.DISCIPLE_NOTE, HORIZONTAL_ALIGNMENT_LEFT, lw, 15, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.58))
	draw_string(font, Vector2(r.position.x, 820.0), "点任意处关闭", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Color(Conf.INK.r, Conf.INK.g, Conf.INK.b, 0.45))
	draw_colored_polygon(Draw.round_poly(Rect2(r.end.x - 74.0, r.position.y + 26.0, 34.0, 34.0), 4.0), Color(Conf.SEAL_C.r, Conf.SEAL_C.g, Conf.SEAL_C.b, 0.84))
	draw_string(font, Vector2(r.end.x - 74.0, r.position.y + 52.0), "徒", HORIZONTAL_ALIGNMENT_CENTER, 34.0, 18, Color(0.97, 0.94, 0.88, 0.92))
