extends Control
# ============================================================
# boss_intel_popup.gd —— 首领敌情窗（v145b）
#
# 用户："在boss关卡 可以点击挑战后额外一个窗口 显示该boss敌情 然后给个确定或者放弃"
#      ＋"字体不要超出框 太多内容可以额外加一个详细按钮 再弹一个窗口"
#      ＋"指追剿"（只接追剿那一侧；爬塔的首领关照旧直接开打）
#
#   两层：
#     · **主窗**（这一份）：只摆"一眼能看完"的摘要——气血/攻/速/防、特性一行一条、
#       被动一行、词缀、两招一大招的名字、赏格一行。**排布按行号算，绝不越框**。
#     · **［详细］**：另弹一窗（`BossDetail`，本文件下半段），把所有描述文字铺开、
#       内容超出就滚动（ScrollContainer ＋ VBoxContainer 的标准写法）。
#   两颗主钮：［放弃］/［确定 · 开打］；信号 confirmed / cancelled。
#
# 接口：open_for(i, chase_mode) / close() · 信号 confirmed / cancelled
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const Chase := preload("res://shared/data_chase.gd")
const Affixes := preload("res://shared/data_affixes.gd")
const UiKit := preload("res://shared/ui_kit.gd")

signal confirmed
signal cancelled

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const DIMTXT := Color(0.38, 0.35, 0.33)
const FADE := Color(0.50, 0.47, 0.45)

const DLG_W := 620.0
const DLG_H := 660.0
const LINE := 26.0          # 摘要区一行的高度（字号 17）

var _dialog: Panel
var _title: Label
var _sub: Label
var _rows: Array = []       # 摘要区的 Label（一行一个，按行号定位）
var _ok: Button
var _no: Button
var _more: Button
var _detail: Control = null
var _i := 0
var _chase := false

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 20                      # 一定压在出村面板（含它那些字）之上
	_build()
	visible = false

func _build() -> void:
	var vp := get_viewport_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.48)
	dim.size = vp
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_dialog = Panel.new()
	_dialog.position = Vector2((vp.x - DLG_W) * 0.5, (vp.y - DLG_H) * 0.5)
	_dialog.size = Vector2(DLG_W, DLG_H)
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 1.0)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(SEAL.r, SEAL.g, SEAL.b, 0.60)
	psb.set_border_width_all(2)
	_dialog.add_theme_stylebox_override("panel", psb)
	add_child(_dialog)

	_title = _mk(Vector2(28, 20), Vector2(DLG_W - 56.0, 34), 23, INK)
	_sub = _mk(Vector2(28, 56), Vector2(DLG_W - 56.0, 22), 14, DIMTXT)
	# 摘要区：固定 14 行，一行一个 Label（行号 × LINE）——**行数写死在 _fill 里，
	#   不够就不写，绝不越到按钮上**（用户："字体不要超出框"）
	for k in 14:
		_rows.append(_mk(Vector2(28, 88.0 + float(k) * LINE), Vector2(DLG_W - 56.0, LINE), 17, INK))

	_no = _mk_btn("放弃", Vector2(24, DLG_H - 74.0), Vector2(180, 56), 20, false)
	_no.pressed.connect(_on_no)
	_more = _mk_btn("详细", Vector2(220, DLG_H - 74.0), Vector2(180, 56), 20, false)
	_more.pressed.connect(_on_more)
	_ok = _mk_btn("确定 · 开打", Vector2(DLG_W - 24.0 - 196.0, DLG_H - 74.0), Vector2(196, 56), 20, true)
	_ok.pressed.connect(_on_ok)

func _mk(pos: Vector2, sz: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.add_child(l)
	return l

func _mk_btn(txt: String, pos: Vector2, sz: Vector2, fs: int, seal: bool) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", fs)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(SEAL.r, SEAL.g, SEAL.b, 0.94) if seal else Color(0.20, 0.19, 0.21, 0.95)
	sb.set_corner_radius_all(9)
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate() as StyleBoxFlat
	hb.bg_color = Color(0.30, 0.28, 0.30, 0.95) if not seal else Color(0.74, 0.20, 0.16, 0.98)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)
	b.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	_dialog.add_child(b)
	return b

# ---- 开窗 ----
func open_for(i: int, chase_mode: bool) -> void:
	_i = i
	_chase = chase_mode
	if _chase:
		_fill_chase(i)
	else:
		_fill_tower(i)
	visible = true

func close() -> void:
	if _detail != null and is_instance_valid(_detail):
		_detail.queue_free()
		_detail = null
	visible = false

func _on_ok() -> void:
	close()
	confirmed.emit()

func _on_no() -> void:
	close()
	cancelled.emit()

func _on_more() -> void:
	if _detail == null or not is_instance_valid(_detail):
		_detail = (preload("res://menu/boss_detail_popup.gd") as GDScript).new()
		add_child(_detail)
	_detail.open_for(_i, _chase)

# 摘要区：只写"一眼能看完"的那几行（行数上限＝_rows.size()，写满为止）
func _put(k: int, txt: String, col: Color) -> void:
	if k < 0 or k >= _rows.size():
		return
	var l: Label = _rows[k]
	l.text = txt
	l.add_theme_color_override("font_color", col)

func _clear_rows() -> void:
	for l_v in _rows:
		(l_v as Label).text = ""

func _fill_chase(i: int) -> void:
	_clear_rows()
	var e: Dictionary = GameState.chase_enemy_at(i)
	_title.text = "第 " + str(i + 1) + " 关 · " + str(e["name"])
	_sub.text = "追剿 · 第 " + str(Chase.round_of(i)) + "/" + str(Chase.rounds()) + " 剿 ｜ " + Chase.diff_line(i)
	var k := 0
	_put(k, "气血 " + str(e["hp"]) + "　攻 " + str(e["atk"]) + "　速度 " + str(e.get("spd", 0)) + "　防御 " + str(e.get("def", 0)), INK)
	k += 1
	var tl: Array = Chase.trait_lines(Chase.boss_traits_of(i))
	if tl.is_empty():
		_put(k, "特性：无（靠词缀与被动吃饭）", DIMTXT)
		k += 1
	else:
		for t in tl:
			_put(k, "【特性】" + str(t), INK)
			k += 1
	var pd: Dictionary = Chase.passive_def(Chase.passive_of(i))
	if not pd.is_empty():
		_put(k, "【被动】" + str(pd.get("name", "")) + "：" + str(pd.get("desc", "")), INK)
		k += 1
		_put(k, "　　针对：" + str(pd.get("counter", "")), SEAL)
		k += 1
	var af: Array = e.get("affixes", [])
	if not af.is_empty():
		var seg: Array = []
		for a in af:
			seg.append("「" + Affixes.name_of(str(a)) + "」")
		_put(k, "【词缀】" + "　".join(PackedStringArray(seg)), INK)
		k += 1
	var names: Array = []
	for art_v in (e.get("arts", []) as Array):
		names.append("「" + str((art_v as Dictionary).get("name", "?")) + "」")
	var ult: Dictionary = e.get("ult", {})
	if not ult.is_empty():
		names.append("大招「" + str(ult.get("name", "?")) + "」")
	if not names.is_empty():
		_put(k, "【它的招】" + "　".join(PackedStringArray(names)) + ("　（半血换招）" if e.has("phase_arts") else ""), INK)
		k += 1
	_put(k, "【赏格】" + Chase.reward_line(i), INK)
	k += 1
	_put(k, "要点都在这儿了——想看每一招的全文，点下面［详细］。", FADE)
	_more.visible = true

func _fill_tower(i: int) -> void:
	_clear_rows()
	var e: Dictionary = GameState.enemy_at(i)
	_title.text = "第 " + str(i + 1) + " 关 · " + str(e["name"])
	_sub.text = str(e.get("chapter", "")) + " ｜ 这一关是首领"
	var k := 0
	_put(k, "气血 " + str(e["hp"]) + "　攻 " + str(e["atk"]) + "　速度 " + str(e.get("spd", 0)) + "　防御 " + str(e.get("def", 0)), INK)
	k += 1
	var af2: Array = e.get("affixes", [])
	var seg2: Array = []
	for a2 in af2:
		seg2.append("「" + Affixes.name_of(str(a2)) + "」")
	if not seg2.is_empty():
		_put(k, "【词缀】" + "　".join(PackedStringArray(seg2)), INK)
		k += 1
	var names2: Array = []
	for art2_v in (e.get("arts", []) as Array):
		names2.append("「" + str((art2_v as Dictionary).get("name", "?")) + "」")
	if not (e.get("ult", {}) as Dictionary).is_empty():
		names2.append("大招「" + str((e.get("ult", {}) as Dictionary).get("name", "?")) + "」")
	if not names2.is_empty():
		_put(k, "【它的招】" + "　".join(PackedStringArray(names2)), INK)
		k += 1
	_put(k, "【赏格】银两 +" + str(GameState.stage_silver(i)) + " · 经验 +" + str(GameState.stage_exp_gain(i)) + " · 首领赏一件", INK)
	_more.visible = true
