extends RefCounted
# ============================================================
# menu_theme.gd —— 主界面皮肤层「影之刃 · 玄墨鎏金」（v200 新增）
#
# 用户（2026-10-19）："给现有主界面换皮，主要要丝滑，参考影之刃的 ui 设计"。
#
# 一家之言（改这里就够了）：
#   · 板面＝玄墨（近黑微紫）半透明，45° 切角，鎏金细线收边；
#   · 四角加 **L 形角标**——这是影之刃 UI 最认得出的记号；
#   · 标题用毛笔字（Ma Shan Zheng · fonts/ink.ttf）＋深色描边；
#   · 强调色只有一支：朱砂（印章/可点的动作字）。
#
# 回退：SKIN = 0 → menu_plaque 里所有 _n_* 不画，走回原来的纸木 _draw_*。
# ============================================================

const SKIN := 1

# ---- 板 ----
const INK0 := Color(0.082, 0.067, 0.059, 0.90)      # 牌底（墨褐，不是冷黑）
const INK1 := Color(0.118, 0.096, 0.083, 0.92)      # 牌面
const INK2 := Color(0.172, 0.141, 0.120, 0.95)      # 悬停牌面
const INK3 := Color(0.232, 0.196, 0.168, 1.0)       # 压下去

# ---- 金 ----
const GOLD := Color(0.784, 0.635, 0.306)            # C8A24E
const GOLD_HI := Color(0.941, 0.839, 0.541)         # F0D68A
const GOLD_DK := Color(0.478, 0.373, 0.149)         # 7A5F26
const GOLD_GLOW := Color(1.0, 0.86, 0.48, 0.0)

# ---- 朱 ----
const CINN := Color(0.659, 0.165, 0.118)            # A82A1E
const CINN_HI := Color(0.878, 0.290, 0.196)         # E04A32

# ---- 字 ----
const TXT := Color(0.929, 0.910, 0.855)             # EDE8DA
const TXT_DIM := Color(0.659, 0.635, 0.588)         # A8A296
const TXT_DARK := Color(0.035, 0.030, 0.040, 0.85)

const FONT_BRUSH := "res://fonts/ink.ttf"

# ---- 几何 ----
const CUT := 9.0          # 45° 切角
const ARM := 14.0         # 角标臂长
const ARM_W := 2.2        # 角标线宽
const EDGE_W := 1.35      # 板边线宽

# ============================================================
# 形状
# ============================================================

# 切角矩形（八边形）：四角各切 45°
static func cut_poly(r: Rect2, cut: float) -> PackedVector2Array:
	var c := minf(cut, minf(r.size.x, r.size.y) * 0.5 - 1.0)
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	return PackedVector2Array([
		Vector2(x0 + c, y0), Vector2(x1 - c, y0),
		Vector2(x1, y0 + c), Vector2(x1, y1 - c),
		Vector2(x1 - c, y1), Vector2(x0 + c, y1),
		Vector2(x0, y1 - c), Vector2(x0, y0 + c),
	])

static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var q := PackedVector2Array(pts)
	q.append(pts[0])
	return q

# 板：落影 → 板面 → 内高光 → 金边 → 角标
# o 可选：{"fill": Color, "edge": Color, "cut": float, "bracket": bool, "shadow": 0..1, "glow": 0..1}
static func panel(h: CanvasItem, r: Rect2, o: Dictionary = {}) -> void:
	var cut: float = float(o.get("cut", CUT))
	var fill: Color = o.get("fill", INK1)
	var edge: Color = o.get("edge", Color(GOLD.r, GOLD.g, GOLD.b, 0.62))
	var shadow: float = float(o.get("shadow", 1.0))
	var glow: float = float(o.get("glow", 0.0))
	var pts := cut_poly(r, cut)
	# 墨韵：板外一圈半透明墨晕（塑料贴片与"画上去的"差别就在这一层）
	if bool(o.get("ink_halo", true)):
		for k in 3:
			var d := 2.0 + float(k) * 2.6
			var hp := PackedVector2Array()
			for p in pts:
				var dir := (p - r.get_center())
				hp.append(p + dir.normalized() * d)
			h.draw_colored_polygon(hp, Color(0.055, 0.043, 0.036, 0.10 - 0.025 * float(k)))
	# 落影（往下 4、外扩 1）
	if shadow > 0.01:
		var sp := PackedVector2Array()
		for p in pts:
			sp.append(p + Vector2(2.0, 4.0))
		h.draw_colored_polygon(sp, Color(0.02, 0.02, 0.03, 0.28 * shadow))
	# 板面
	h.draw_colored_polygon(pts, fill)
	# 顶部内高光：一条细亮线（影之刃的面板都是左上受光）
	if not bool(o.get("no_hi", false)):
		var hi := PackedVector2Array([pts[0] + Vector2(4.0, 1.0), pts[1] - Vector2(4.0, -1.0)])
		h.draw_polyline(hi, Color(1.0, 0.92, 0.72, 0.13 + 0.10 * glow), 1.0, true)
	# 金边
	h.draw_polyline(_closed(pts), edge, EDGE_W + 0.5 * glow, true)
	# 角标
	if bool(o.get("bracket", true)):
		brackets(h, r, cut, Color(GOLD_HI.r, GOLD_HI.g, GOLD_HI.b, 0.75 + 0.25 * glow), ARM, ARM_W)

# 四角 L 形角标（画在切角以内）
static func brackets(h: CanvasItem, r: Rect2, cut: float, col: Color, arm: float, w: float) -> void:
	var c := cut
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	var a := minf(arm, minf(r.size.x, r.size.y) * 0.42)
	# 左上：从切角斜边两端出发
	h.draw_line(Vector2(x0 + c, y0 + 2.0), Vector2(x0 + c + a, y0 + 2.0), col, w, true)
	h.draw_line(Vector2(x0 + 2.0, y0 + c), Vector2(x0 + 2.0, y0 + c + a), col, w, true)
	# 右上
	h.draw_line(Vector2(x1 - c, y0 + 2.0), Vector2(x1 - c - a, y0 + 2.0), col, w, true)
	h.draw_line(Vector2(x1 - 2.0, y0 + c), Vector2(x1 - 2.0, y0 + c + a), col, w, true)
	# 左下
	h.draw_line(Vector2(x0 + c, y1 - 2.0), Vector2(x0 + c + a, y1 - 2.0), col, w, true)
	h.draw_line(Vector2(x0 + 2.0, y1 - c), Vector2(x0 + 2.0, y1 - c - a), col, w, true)
	# 右下
	h.draw_line(Vector2(x1 - c, y1 - 2.0), Vector2(x1 - c - a, y1 - 2.0), col, w, true)
	h.draw_line(Vector2(x1 - 2.0, y1 - c), Vector2(x1 - 2.0, y1 - c - a), col, w, true)

# 金环（头像框 / 涟漪）
static func ring(h: CanvasItem, c: Vector2, rad: float, col: Color, w: float, seg: int = 48) -> void:
	if rad <= 0.5:
		return
	h.draw_arc(c, rad, 0.0, TAU, seg, col, w, true)

# 菱形环（影之刃的头像框就是菱形/六边形）
static func diamond(h: CanvasItem, c: Vector2, rad: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array([
		c + Vector2(0.0, -rad), c + Vector2(rad * 0.82, 0.0),
		c + Vector2(0.0, rad), c + Vector2(-rad * 0.82, 0.0)])
	h.draw_polyline(_closed(pts), col, w, true)

# ============================================================
# 字
# ============================================================

# 毛笔金字：先描深边，再填金（影之刃的标题都是这个做法）
static func gold_text(h: CanvasItem, font: Font, pos: Vector2, txt: String, fs: int,
		align: int, width: float, col: Color = GOLD_HI, outline: int = 3) -> void:
	if font == null or txt == "":
		return
	if outline > 0:
		h.draw_string_outline(font, pos, txt, align, width, fs, outline, TXT_DARK)
	h.draw_string(font, pos, txt, align, width, fs, col)

# ============================================================
# 缓动（丝滑的底子：帧率无关的指数趋近 + 阻尼弹簧）
# ============================================================

# 指数趋近：rate 越大越快（8~14 比较跟手）
static func ease(cur: float, target: float, rate: float, dt: float) -> float:
	return lerpf(cur, target, 1.0 - exp(-rate * dt))

# 一维阻尼弹簧：p=[位置, 速度]，k 刚度、d 阻尼
static func spring(p: Array, target: float, k: float, d: float, dt: float) -> Array:
	var x: float = p[0]
	var v: float = p[1]
	var steps := 3
	var h := dt / float(steps)
	for i in steps:
		v += (-k * (x - target) - d * v) * h
		x += v * h
	return [x, v]

# 颜色溶解（hover 亮度）
static func lerp_c(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))

# 一点暖光（跟着 hover 走）
static func glow(c: Color, amount: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(c.a * amount, 0.0, 1.0))

# ============================================================
# 面板通用件（v201：角色面板起用，后续背包/商店/困兽都套这套）
# ============================================================

# 刊头：墨底 + 底部金线 + 左端朱砂竖条。w=面板宽，hgt=高度
static func header(h: CanvasItem, w: float, hgt: float = 78.0) -> void:
	h.draw_rect(Rect2(0.0, 0.0, w, hgt), INK0)
	h.draw_rect(Rect2(0.0, hgt - 4.0, w, 4.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.95))
	h.draw_rect(Rect2(26.0, 22.0, 6.0, 36.0), CINN)

# 分区标题：朱砂竖条 + 一条金线拉到右边
static func sect(h: CanvasItem, x0: float, y: float, w: float, name: String, font: Font, fs: int = 22) -> void:
	h.draw_rect(Rect2(x0, y + 2.0, 5.0, 24.0), CINN)
	gold_text(h, font, Vector2(x0 + 14.0, y + 24.0), name, fs, HORIZONTAL_ALIGNMENT_LEFT, w, TXT, 0)
	var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if font != null else 0.0
	h.draw_line(Vector2(x0 + 14.0 + tw + 16.0, y + 14.0), Vector2(x0 + w, y + 14.0),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.22), 1.0, true)

# 卡片：纸面 + 切角 + 金线
static func card(h: CanvasItem, r: Rect2, cut: float = 10.0, fill: Color = Color(0.886, 0.859, 0.784, 0.99)) -> void:
	# 卡片要比面板底"沉"一点，否则同色看不见（面板 #F5F0E5 → 卡片 #E6E0CF）
	var pts := cut_poly(r, cut)
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(0.0, 3.0))
	h.draw_colored_polygon(sh, Color(0.20, 0.16, 0.10, 0.10))
	h.draw_colored_polygon(pts, fill)
	var q := PackedVector2Array(pts)
	q.append(pts[0])
	h.draw_polyline(q, Color(GOLD.r, GOLD.g, GOLD.b, 0.56), 1.2, true)
