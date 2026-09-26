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
# 结束时发 done(talents, gift_sid)，然后自毁
# ============================================================

signal done(talents: Array, gift_sid: String)

const Cards := preload("res://shared/data_cards.gd")
const Creation := preload("res://journey/data_creation.gd")
const UiKit := preload("res://shared/ui_kit.gd")

var _intro_idx := 0
var _q_idx := 0
var _talents: Array = []
var _gift_sid := ""
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
	UiKit.set_text(t1, "山　门")
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
	if opt.has("gift"):
		var pool := str(opt.get("gift", "arts"))
		# ㊿t：**点明了的**礼物（手抄拳谱／没开锋的旧剑）定签——同一选项两次开局给同一套残卡。
		#   只有"布包"留着随机：它的选项文案本来就写着"不知装的什么"，那是这里唯一的赌一把。
		var gamble := pool == "random"
		if gamble:
			pool = "arts" if randf() < 0.5 else "weapon"
			# ㊿d：礼物封顶凡品（全是 3 页套）——原先没封顶，会摇到 4~7 页的高品套（含绝品）
		var sets: Array = Cards.pool_sets(pool, 0)
		if not sets.is_empty():
			# ⚠ 别写成三元表达式塞进 :=（GDScript 对它的类型推断不稳），分行写
			var gi := 0
			if gamble:
				gi = randi() % sets.size()
			_gift_sid = str(sets[gi])
	print("[游历] 已作答第 ", _q_idx + 1, " 问；天赋=", _talents, " 行囊礼物=", _gift_sid)
	_q_idx += 1
	if _q_idx >= Creation.QUESTIONS.size():
		_show_verdict()
	else:
		_ask_question(_q_idx)

func _show_verdict() -> void:
	_clear()
	_intro_active = false
	print("[游历] 到临别页（接下来按［下山］）")
	var veil := UiKit.make_veil(self, size, 0.52)
	var panel := UiKit.make_paper_panel(veil, Rect2(20, 390, 680, 500))

	var t1 := UiKit.make_label(panel, Vector2(0, 24), Vector2(680, 44), 32, UiKit.INK)
	UiKit.set_text(t1, "临别 · 山门")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var body := "你的天赋：\n"
	if _talents.is_empty():
		body += "　（无）\n"
	else:
		for t in _talents:
			body += "　· " + str(t) + " —— " + str(Creation.talent_desc(str(t))) + "\n"
	body += "\n行囊里多了三张残卡：\n"
	if _gift_sid != "":
		var names: Array = []
		var parts: Array = Cards.parts_of(_gift_sid)
		for i in parts.size():
			names.append(str(Cards.card_name(_gift_sid, i)))
		body += "　" + "、".join(PackedStringArray(names)) + "\n"
		body += "　三张凑齐 → 点右上角［合成］，之后可以选装备或放包裹\n"

	var bd := UiKit.make_label(panel, Vector2(40, 90), Vector2(600, 280), 20, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))
	UiKit.set_text(bd, body)
	bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var go := UiKit.make_button(panel, Vector2(240, 400), Vector2(200, 68), "下山", 24)
	go.pressed.connect(_on_go)

func _on_go() -> void:
	print("[游历] 按下［下山］，开始交棒")
	done.emit(_talents.duplicate(), _gift_sid)
	print("[游历] 交棒信号已发出（若上面没有『创建完成』一行，说明问题在这一侧）")
	queue_free()
