extends Node2D
# ============================================================
# pet_actor.gd —— 游历里跟着走的那只宠物（㊿z11）
#
# 干什么：把"随行宠物"画在路上、也画在战斗里（站/悬在主人身边）。
#   ⚠ 它**不参战**：不挨打、不出手、不进 duel_battle 的成员表——纯粹是"在那儿"。
#     数值上的护主/速度加成走 GameState.effective_stats（见那边的注），与此无关。
#
# 坐标约定：节点 position ＝ **脚底**（与 StickFighter 一致——舞台的 _walk_home 就是脚底），
#   所以绘制时先把坐标系平移到底部中央，再照搬宠物面板那套画法
#   （那边地线在 y=150、狐狸中心 cx=292）。
#   ⚠ 面板（menu/pet_panel.gd 的 PetArt）改了形状，这里要跟着改——两处是同一只狐/隼的两张画。
#
# 用法：舞台每帧 lerp 它的 position 追主人；没随行宠物就整只不建。
# ============================================================

const CharArt := preload("res://shared/char_art.gd")   # v79：Q版宠物图（白狐/青隼）
const PANEL_CX := 292.0     # 面板地线中心（与 pet_panel 对齐）
const PANEL_GROUND := 150.0 # 面板地线

var kind := "fox"           # "fox" 白狐 / "hawk" 青隼
var draw_scale := 0.75      # 屏幕上的大小（面板是 1:1，路上按比例缩小）
var t := 0.0

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

# 脚下那圈淡影——不然像浮在地上（青隼不画：它在半空）
func _shadow(rx: float, ry: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(PANEL_CX + cos(a) * rx, PANEL_GROUND + 3.0 + sin(a) * ry))
	draw_colored_polygon(pts, Color(0.12, 0.10, 0.10, 0.16))

func _draw() -> void:
	# 先把"面板坐标"整体搬过来：地线中心 → 本节点的原点
	draw_set_transform(Vector2(-PANEL_CX * draw_scale, -PANEL_GROUND * draw_scale), 0.0, Vector2(draw_scale, draw_scale))
	# v79（用户："宠物也不是q版"）：**有 Q版 图就用图**（智谱出的白狐/青隼），
	#   没图再退回原来的程序化画法——两条路都通，缺图不会变空白。
	var tex: Texture2D = CharArt.pet(kind)
	if tex != null:
		var h := 132.0
		var w: float = h * float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		var bob2 := sin(t * 2.2) * 2.0
		draw_texture_rect(tex, Rect2(PANEL_CX - w * 0.5, PANEL_GROUND - h + bob2, w, h), false, Color(1, 1, 1, 1))
		return
	if kind == "hawk":
		_draw_hawk()
	else:
		_draw_fox()

# ---- 白狐：站在地上，尾巴一摆一摆 ----
func _draw_fox() -> void:
	var cx := PANEL_CX
	var cy := 118.0
	var s := 1.0
	var bob := sin(t * 2.6) * 2.5
	var body := Color(0.965, 0.950, 0.915, 0.98)
	var inkc := Color(0.30, 0.27, 0.28, 0.95)
	_shadow(34.0, 8.0)
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

# ---- 青隼：在半空悬着（路上跟着飞、打起来悬在主人侧上方），翅膀轻晃 ----
func _draw_hawk() -> void:
	var cx := PANEL_CX
	var cy := 96.0
	var s := 1.0
	var bob := sin(t * 2.2) * 2.0
	var body := Color(0.55, 0.60, 0.68)
	var wing := Color(0.42, 0.47, 0.56)
	var head_c := Color(0.63, 0.68, 0.76)
	var inkc := Color(0.30, 0.27, 0.28, 0.95)
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
	# 双翅：各按自己的相位轻扇（折翅形状照搬面板，另一侧镜像出来）
	var flap := sin(t * 3.4) * 0.16
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 6.0 * s, cy - 18.0 * s + bob * 0.5),
		Vector2(cx - 34.0 * s, cy + 16.0 * s + bob * 0.5 + flap * 22.0),
		Vector2(cx - 24.0 * s, cy + 26.0 * s + bob * 0.5 + flap * 20.0),
		Vector2(cx + 6.0 * s, cy - 2.0 * s + bob * 0.5),
	]), wing)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 6.0 * s, cy - 18.0 * s + bob * 0.5),
		Vector2(cx + 34.0 * s, cy + 16.0 * s + bob * 0.5 - flap * 22.0),
		Vector2(cx + 24.0 * s, cy + 26.0 * s + bob * 0.5 - flap * 20.0),
		Vector2(cx - 6.0 * s, cy - 2.0 * s + bob * 0.5),
	]), Color(0.48, 0.53, 0.62))
	# 头 / 喙 / 眼
	draw_circle(Vector2(cx + 16.0 * s, cy - 34.0 * s + bob), 13.0 * s, head_c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 27.0 * s, cy - 38.0 * s + bob),
		Vector2(cx + 41.0 * s, cy - 32.0 * s + bob),
		Vector2(cx + 27.0 * s, cy - 28.0 * s + bob),
	]), Color(0.85, 0.68, 0.30))
	draw_circle(Vector2(cx + 20.0 * s, cy - 36.0 * s + bob), 2.2 * s, inkc)
	draw_circle(Vector2(cx + 19.0 * s, cy - 37.0 * s + bob), 0.8 * s, Color(0.98, 0.96, 0.90, 0.9))
	# 收着的爪（飞着，不画到地面）
	draw_line(Vector2(cx - 6.0 * s, cy + 22.0 * s), Vector2(cx - 8.0 * s, cy + 34.0 * s + bob * 0.3), Color(0.70, 0.55, 0.30), 2.4)
	draw_line(Vector2(cx + 6.0 * s, cy + 22.0 * s), Vector2(cx + 8.0 * s, cy + 34.0 * s + bob * 0.3), Color(0.70, 0.55, 0.30), 2.4)
