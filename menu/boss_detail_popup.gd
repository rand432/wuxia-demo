extends Control
# ============================================================
# boss_detail_popup.gd —— 首领"详细"窗（v145b）
#
# 用户："太多内容可以额外加一个详细按钮 再弹一个窗口"。
#   从敌情主窗的［详细］打开：把所有描述文字铺开写全——
#   特性全文（含针对）· 专属被动全文 · 每条词缀的说明 · 每一招与大招的全文与冷却 ·
#   换招提醒 · 赏格明细。
#   **内容超出就滚动**：ScrollContainer ＋ VBoxContainer ＋ 自动换行 Label（标准写法，
#   别再把 Label 直接塞进 ScrollContainer——那样子节点会跑到弹窗左上角去）。
#   右上角一颗［关闭］退回主窗。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const Chase := preload("res://shared/data_chase.gd")
const Affixes := preload("res://shared/data_affixes.gd")

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const DIMTXT := Color(0.40, 0.37, 0.35)

const DLG_W := 640.0
const DLG_H := 1040.0

var _dialog: Panel
var _title: Label
var _body: Label
var _i := 0
var _chase := false

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 30                      # 比主窗（20）再高一层
	_build()
	visible = false

func _build() -> void:
	var vp := get_viewport_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.42)
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

	_title = Label.new()
	_title.position = Vector2(26, 18)
	_title.size = Vector2(DLG_W - 200.0, 32)
	_title.add_theme_font_size_override("font_size", 21)
	_title.add_theme_color_override("font_color", INK)
	_title.clip_text = true
	_dialog.add_child(_title)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(DLG_W - 26.0 - 140.0, 14)
	close_btn.size = Vector2(140, 44)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.19, 0.21, 0.95)
	sb.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", sb)
	close_btn.add_theme_stylebox_override("hover", sb)
	close_btn.add_theme_stylebox_override("pressed", sb)
	close_btn.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	close_btn.pressed.connect(_on_close)
	_dialog.add_child(close_btn)

	# 滚动区：ScrollContainer → VBoxContainer → 自动换行 Label（宽度写死，高度交给内容）
	var sc := ScrollContainer.new()
	sc.position = Vector2(20, 68)
	sc.size = Vector2(DLG_W - 40.0, DLG_H - 68.0 - 20.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialog.add_child(sc)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(DLG_W - 64.0, 0)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)

	_body = Label.new()
	_body.custom_minimum_size = Vector2(DLG_W - 64.0, 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("font_size", 17)
	_body.add_theme_color_override("font_color", INK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_body)

func open_for(i: int, chase_mode: bool) -> void:
	_i = i
	_chase = chase_mode
	if _chase:
		_fill_chase(i)
	else:
		_fill_tower(i)
	visible = true

func _on_close() -> void:
	visible = false

func _h(t: String) -> String:
	return "\n【" + t + "】"

func _fill_chase(i: int) -> void:
	var e: Dictionary = GameState.chase_enemy_at(i)
	_title.text = "第 " + str(i + 1) + " 关 · " + str(e["name"]) + "　（详细）"
	var L: Array = []
	L.append("追剿 · 第 " + str(Chase.round_of(i)) + "/" + str(Chase.rounds()) + " 剿 · " + Chase.diff_line(i))
	L.append("气血 " + str(e["hp"]) + "　攻 " + str(e["atk"]) + "　速度 " + str(e.get("spd", 0)) + "　防御 " + str(e.get("def", 0)))
	if str(e.get("elem", "")) != "":
		L.append("五行：" + str(e["elem"]) + "（抗性 " + str(e.get(str(e["elem"], "") + "_res", 0)) + "）——它打你是元素伤害，不吃你的防御，改吃抗性")
	L.append(_h("特性（可以针对）"))
	var tl: Array = Chase.trait_lines(Chase.boss_traits_of(i))
	if tl.is_empty():
		L.append("　这一门没有特性——它靠词缀与专属被动吃饭。")
	for t in tl:
		L.append("　" + str(t))
	var pd: Dictionary = Chase.passive_def(Chase.passive_of(i))
	if not pd.is_empty():
		L.append(_h("专属被动「" + str(pd.get("name", "")) + "」"))
		L.append("　" + str(pd.get("desc", "")))
		L.append("　针对：" + str(pd.get("counter", "")))
		L.append("　（被动是「一直在身上」的底子，跟「每几手来一次」的特性分开算）")
	var af: Array = e.get("affixes", [])
	if not af.is_empty():
		L.append(_h("词缀"))
		for a in af:
			L.append("　「" + Affixes.name_of(str(a)) + "」" + str(Affixes.of(str(a)).get("desc", "")))
	L.append(_h("它的招"))
	for art_v in (e.get("arts", []) as Array):
		var art: Dictionary = art_v
		L.append("　「" + str(art.get("name", "?")) + "」（冷却 " + str(int(art.get("cd", 3))) + " 手）")
		L.append("　　" + str(art.get("desc", "")))
	var ult: Dictionary = e.get("ult", {})
	if not ult.is_empty():
		L.append("　大招「" + str(ult.get("name", "?")) + "」（怒气满自动放）")
		L.append("　　" + str(ult.get("desc", "")))
	if e.has("phase_arts"):
		L.append(_h("换招提醒"))
		L.append("　气血过半之后它会换一整套招（大招也换）——把爆发留到它换招之后再交。")
	L.append(_h("赏格"))
	L.append("　" + Chase.reward_line(i))
	L.append("　清关固定：银两 ＋ 经验 ＋ 2 个宝箱（首领关另给一件整品）")
	L.append("　档位：" + Chase.tier_line(i) + "（每 80 关升一档，封顶极品）")
	_body.text = "\n".join(PackedStringArray(L))

func _fill_tower(i: int) -> void:
	var e: Dictionary = GameState.enemy_at(i)
	_title.text = "第 " + str(i + 1) + " 关 · " + str(e["name"]) + "　（详细）"
	var L: Array = []
	L.append(str(e.get("chapter", "")) + " ｜ 这一关是首领")
	L.append("气血 " + str(e["hp"]) + "　攻 " + str(e["atk"]) + "　速度 " + str(e.get("spd", 0)) + "　防御 " + str(e.get("def", 0)))
	var af2: Array = e.get("affixes", [])
	if not af2.is_empty():
		L.append(_h("词缀（可以针对）"))
		for a2 in af2:
			L.append("　「" + Affixes.name_of(str(a2)) + "」" + str(Affixes.of(str(a2)).get("desc", "")))
	L.append(_h("它的招"))
	for art2_v in (e.get("arts", []) as Array):
		var art2: Dictionary = art2_v
		L.append("　「" + str(art2.get("name", "?")) + "」")
		L.append("　　" + str(art2.get("desc", "")))
	var ult2: Dictionary = e.get("ult", {})
	if not ult2.is_empty():
		L.append("　大招「" + str(ult2.get("name", "?")) + "」")
		L.append("　　" + str(ult2.get("desc", "")))
	L.append(_h("赏格"))
	L.append("　银两 +" + str(GameState.stage_silver(i)) + " · 经验 +" + str(GameState.stage_exp_gain(i)) + "　（首领再 +" + str(GameState.boss_silver_gain(i)) + " 银两）")
	L.append("　首领赏一件：" + str(GameState.GRADE_CN[GameState.tower_gift_tier_now()]))
	if GameState.is_story_stage(i):
		L.append(_h("注意"))
		L.append("　这是剧情关：过了会弹剧情，后台估算不替你过。")
	_body.text = "\n".join(PackedStringArray(L))
