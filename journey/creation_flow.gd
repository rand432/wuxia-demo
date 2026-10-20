extends Control
# ============================================================
# creation_flow.gd —— 开场三页 → 五问 → 临别小结（v4 · 竖屏坐标）
# v4：坐标从横屏 1152×648 搬到竖屏 720×1280：
#   开场页 (40,440) 640×400；五问页 680 宽、面板高度按选项数算
#   （200 + 选项数×84，上下自动居中）；选项按钮 560×64；
#   临别页 (20,390) 680×500；下山 200×68。
#   逻辑零变化。
# v3：每一步打"面包屑"（输出面板可见）：开场页/第N问/临别/下山；
#   修"一次点击跳两页"（同一次点击只算一次）。
# 结束时发 done(talents)，然后自毁（v138：不再带 gift——第五问只出风味，不发东西）
# ============================================================

signal done(talents: Array)

const Cards := preload("res://shared/data_cards.gd")
const Creation := preload("res://journey/data_creation.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const Voice := preload("res://shared/voice.gd")   # v82：剧情配音

var _intro_idx := 0
var _q_idx := 0
var _talents: Array = []
var _intro_active := false
var _intro_guard := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = get_viewport_rect().size
	print("[游历] 开场就绪：尺寸=", size)
	_show_intro()

func _clear() -> void:
	for c in get_children():
		c.queue_free()

func _show_intro() -> void:
	_clear()
	_intro_active = true
	print("[游历] 开场第 ", _intro_idx + 1, " 页 / 共 ", Creation.INTRO.size(), " 页")
	var veil := UiKit.make_veil(self, size, 0.52)
	veil.gui_input.connect(_on_intro_click)
	var panel := UiKit.make_paper_panel(veil, Rect2(40, 440, 640, 400))
	panel.gui_input.connect(_on_intro_click)

	var t1 := UiKit.make_label(panel, Vector2(0, 80), Vector2(640, 44), 32, UiKit.INK)
	# v82：标题也跟着剧情改了（原来写"山门"——那是旧开场的词）
	UiKit.set_text(t1, "崖　下")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var body := UiKit.make_label(panel, Vector2(50, 150), Vector2(540, 156), 26, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))
	var idx := clampi(_intro_idx, 0, Creation.INTRO.size() - 1)
	UiKit.set_text(body, str(Creation.INTRO[idx]))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var tip := UiKit.make_label(panel, Vector2(0, 326), Vector2(640, 34), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.55))
	UiKit.set_text(tip, "（点击 / 任意键继续）")
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _release_intro_guard() -> void:
	_intro_guard = false

func _advance_intro() -> void:
	if not _intro_active:
		return
	if _intro_guard:
		return
	_intro_guard = true
	call_deferred("_release_intro_guard")
	_intro_idx += 1
	if _intro_idx >= Creation.INTRO.size():
		_ask_question(0)
	else:
		_show_intro()

func _on_intro_click(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	_advance_intro()

func _unhandled_input(event: InputEvent) -> void:
	if not _intro_active:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			_advance_intro()

func _ask_question(i: int) -> void:
	_clear()
	_intro_active = false
	_q_idx = i
	print("[游历] 第 ", i + 1, " 问 / 共 ", Creation.QUESTIONS.size(), " 问")
	var q: Dictionary = Creation.QUESTIONS[i]
	var opts: Array = q.get("opts", [])
	# 面板高度按选项个数算（每条 84 高，头尾留白 200），竖直方向自动居中
	var need_h := 200.0 + float(opts.size()) * 84.0
	var top := (size.y - need_h) * 0.5
	var veil := UiKit.make_veil(self, size, 0.52)
	var panel := UiKit.make_paper_panel(veil, Rect2(20, top, 680, need_h))

	var head := UiKit.make_label(panel, Vector2(0, 18), Vector2(680, 26), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.55))
	UiKit.set_text(head, "第 " + str(i + 1) + " 问 · 共五问")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var qt := UiKit.make_label(panel, Vector2(40, 60), Vector2(600, 104), 28, UiKit.INK)
	UiKit.set_text(qt, str(q.get("q", "")))
	qt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	for k in opts.size():
		var opt: Dictionary = opts[k]
		var b := UiKit.make_button(panel, Vector2(60, 190 + k * 84), Vector2(560, 64), str(opt.get("label", "…")), 22)
		b.pressed.connect(_on_answer.bind(opt))

func _on_answer(opt: Dictionary) -> void:
	if opt.has("aff"):
		var t: Dictionary = Creation.pick_talent(str(opt.get("aff", "")), _talents)
		if not t.is_empty():
			_talents.append(str(t.get("name", "")))
	# v138（用户："最后一问还是固定给一个功法【不给武器】"）：第五问**什么都不发**——
	#   以前这里按 opt.gift 摇一套凡品残卡（拳谱／旧剑／布包），现在 opt 里只放一句风味。
	#   固定的那门疾风剑法在引子起手时由 journey_stage._intro_kit 发（不经过五问这一页）。
	print("[游历] 已作答第 ", _q_idx + 1, " 问；天赋=", _talents)
	_q_idx += 1
	if _q_idx >= Creation.QUESTIONS.size():
		_show_verdict()
	else:
		_ask_question(_q_idx)

func _show_verdict() -> void:
	_clear()
	_intro_active = false
	print("[游历] 到临别页（接下来按［上路］）")
	var veil := UiKit.make_veil(self, size, 0.52)
	var panel := UiKit.make_paper_panel(veil, Rect2(20, 390, 680, 500))

	var t1 := UiKit.make_label(panel, Vector2(0, 24), Vector2(680, 44), 32, UiKit.INK)
	# v81（用户："开头剧情改一改"）：这一页不再是"山门临别"，是**崖下起身**——
	#   跟《气质设定》的序章（赘婿→暗算→坠崖→没生→五问→江湖新客）对齐。
	UiKit.set_text(t1, "崖下 · 起身")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var body := "你的天赋：\n"
	if _talents.is_empty():
		body += "　（无）\n"
	else:
		for t in _talents:
			body += "　· " + str(t) + " —— " + str(Creation.talent_desc(str(t))) + "\n"
	# v138：临别页不再讲"三张残卡／怎么合成"——那套教学整个挪到了引子第一节
	#   （尸骨上那把锈剑：journey_stage._tutorial_tip）。这里只交代身世。
	body += "\n崖底的雨还没停。\n"
	body += "你撑着一口气站起来——武艺剩不到三成，佩剑不知丢在哪里。\n"
	body += "先活过今晚。"

	var bd := UiKit.make_label(panel, Vector2(40, 90), Vector2(600, 280), 20, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))
	UiKit.set_text(bd, body)
	bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var go := UiKit.make_button(panel, Vector2(240, 400), Vector2(200, 68), "上　路", 24)
	go.pressed.connect(_on_go)

func _on_go() -> void:
	print("[游历] 按下［上路］，开始交棒")
	done.emit(_talents.duplicate())
	print("[游历] 交棒信号已发出（若上面没有『创建完成』一行，说明问题在这一侧）")
	queue_free()
