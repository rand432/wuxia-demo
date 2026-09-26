extends Control
# ============================================================
# status_chips.gd —— **负面状态的小图标**（v54，用户："记得负面的小图标也得有"）
#
# 一行小方块，每块一个汉字（燃/械/默/招/震/破/弱/迟/挫/滞/窍/脉），底色＝那条状态的颜色，
# 层数 >1 时在右下角写个小数字。**纯代码绘制**——这个项目没有图标资源，一切靠画。
#
# 用法（两套引擎都一样）：
#   var chips := StatusChips.new()      # 加进某个容器/面板
#   chips.position = Vector2(...)
#   chips.size = Vector2(...)
#   ...
#   chips.set_unit(某个单位字典)          # 每帧/每次刷新调一次；空字典＝什么都不画
#
# ⚠ 字体优先用项目那份楷体（`assets/fonts/lxgw_wenkai.ttf`），与 menu_draw.draw_string 同一份，
#   不然小方块里会出现豆腐块。取不到就退回主题字体 / Godot 兜底字体。
# ============================================================

const St := preload("res://shared/data_status.gd")
const FONT_PATH := "res://assets/fonts/lxgw_wenkai.ttf"

static var _font: Font = null

var unit: Dictionary = {}
var cell := 17.0          # 每块边长
var gap := 6.0            # 块间距（要给右上角那颗"层数"小徽章留出位置）
var max_n := 12           # 最多画几块（再多就收尾一个"…"）
var draw_pos := true      # 是否画层数徽章（>1 层才画）

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font == null:
		if ResourceLoader.exists(FONT_PATH):
			var r: Resource = load(FONT_PATH)
			if r is Font:
				_font = r as Font
		if _font == null:
			_font = ThemeDB.fallback_font

# 换一只单位（空字典＝清空）
func set_unit(u: Dictionary) -> void:
	unit = u
	queue_redraw()

func count() -> int:
	return St.chips(unit).size()

func _draw() -> void:
	if _font == null or unit.is_empty():
		return
	var chips: Array = St.chips(unit)
	if chips.is_empty():
		return
	var y0 := maxf(2.0, (size.y - cell) * 0.5)
	var n_draw := mini(chips.size(), max_n)
	for i in n_draw:
		var c: Dictionary = chips[i]
		var col: Color = c.get("col", Color(0.42, 0.40, 0.42))
		var r := Rect2(float(i) * (cell + gap), y0, cell, cell)
		# 底：状态色；边：更深的同色（小方块＝一枚小印）
		draw_rect(r, Color(col.r * 0.94, col.g * 0.94, col.b * 0.94, 0.94))
		draw_rect(r, Color(col.r * 0.42, col.g * 0.42, col.b * 0.42, 0.95), false, 1.3)
		# 字：一格一个字，居中
		var g := St.glyph_of(str(c.get("id", "")))
		draw_string(_font, Vector2(r.position.x, r.position.y + cell * 0.76), g,
			HORIZONTAL_ALIGNMENT_CENTER, cell, int(round(cell * 0.70)), Color(0.98, 0.96, 0.92, 0.97))
		# 层数：**右上角挂一颗小徽章**（画在块外，不压字）——>1 层才画
		var st := int(c.get("n", 1))
		if draw_pos and st > 1:
			var b := Rect2(r.position.x + cell - 6.0, r.position.y - 4.0, 11.0, 11.0)
			draw_rect(b, Color(0.16, 0.14, 0.16, 0.92))
			draw_rect(b, Color(1.0, 0.96, 0.88, 0.85), false, 1.0)
			draw_string(_font, Vector2(b.position.x, b.position.y + 9.0), str(mini(st, 9)),
				HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 9, Color(1.0, 0.98, 0.94, 0.98))
	# 多到画不下：收尾一个省略号，别硬挤
	if chips.size() > max_n:
		var xp := float(n_draw) * (cell + gap)
		draw_string(_font, Vector2(xp, y0 + cell * 0.78), "…", HORIZONTAL_ALIGNMENT_CENTER,
			cell, int(round(cell * 0.70)), Color(0.30, 0.28, 0.30, 0.85))
