extends Control
# v243：山门占位——只验「好感 / 声望 / 正邪 / 考验」四道门。
#   不够：给指点；四门皆足：传一门旧武功（疾风剑法）。
signal closed

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")

const FAVOR_NEED := 60
const REP_NEED := 60
const GIFT_SILVER := 20
const DONATE_SILVER := 50
const TEST_SILVER := 30
const TEST_ACTION := 3
const ART_SID := "art_wind"

var _panel: Panel
var _fav_lb: Label
var _rep_lb: Label
var _test_lb: Label
var _gate_lb: Label
var _msg_lb: Label
var _gift_btn: Button
var _donate_btn: Button
var _test_btn: Button
var _learn_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vs := Vector2(720, 1280)
	var veil := UiKit.make_veil(self, vs, 0.62)
	_panel = UiKit.make_paper_panel(veil, Rect2(40, 200, 640, 800))

	var title := UiKit.make_label(_panel, Vector2(0, 18), Vector2(640, 48), 34, UiKit.INK)
	UiKit.set_text(title, "青 岚 山 门")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var sub := UiKit.make_label(_panel, Vector2(0, 68), Vector2(640, 24), 16, UiKit.DIM)
	UiKit.set_text(sub, "中立剑门 · 山门占位 · 只看四道门")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_fav_lb = _row("好 感", 124)
	_gift_btn = UiKit.make_button(_panel, Vector2(400, 112), Vector2(200, 46), "送礼 20两", 16)
	_gift_btn.pressed.connect(_gift)

	_rep_lb = _row("声 望", 198)
	_donate_btn = UiKit.make_button(_panel, Vector2(400, 186), Vector2(200, 46), "捐银 50两", 16)
	_donate_btn.pressed.connect(_donate)

	_row("正 邪", 272)
	var align := UiKit.make_label(_panel, Vector2(180, 272), Vector2(200, 34), 20, UiKit.INK)
	UiKit.set_text(align, "中立 · 不挑出身")

	_test_lb = _row("考 验", 346)
	_test_btn = UiKit.make_button(_panel, Vector2(400, 334), Vector2(200, 46), "跑腿 3行动·30两", 15)
	_test_btn.pressed.connect(_test)

	_gate_lb = UiKit.make_label(_panel, Vector2(40, 416), Vector2(560, 60), 15, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	_gate_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_learn_btn = UiKit.make_button(_panel, Vector2(180, 500), Vector2(280, 56), "求 功 法", 22)
	_learn_btn.pressed.connect(_learn)

	_msg_lb = UiKit.make_label(_panel, Vector2(40, 580), Vector2(560, 62), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var close_btn := UiKit.make_button(_panel, Vector2(220, 676), Vector2(200, 46), "下 山", 18)
	close_btn.pressed.connect(close)
	visible = false

func _row(name: String, y: float) -> Label:
	var lb := UiKit.make_label(_panel, Vector2(40, y), Vector2(150, 34), 20, UiKit.SEAL)
	UiKit.set_text(lb, name)
	var val := UiKit.make_label(_panel, Vector2(180, y), Vector2(210, 34), 20, UiKit.INK)
	return val

func open() -> void:
	visible = true
	_say("山门不拦人，只看四道门。")
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _say(s: String) -> void:
	UiKit.set_text(_msg_lb, s)

func _refresh() -> void:
	UiKit.set_text(_fav_lb, str(GS.sect_favor) + " / " + str(FAVOR_NEED))
	UiKit.set_text(_rep_lb, str(GS.sect_rep) + " / " + str(REP_NEED))
	UiKit.set_text(_test_lb, "已 过" if GS.sect_test else "未 过")
	_gift_btn.disabled = GS.sect_favor >= 100 or GS.coin("silver") < GIFT_SILVER
	_donate_btn.disabled = GS.sect_rep >= 100 or GS.coin("silver") < DONATE_SILVER
	_test_btn.disabled = GS.sect_test or GS.coin("silver") < TEST_SILVER or GS.action < TEST_ACTION
	_gate_lb.text = "四门：好感 " + str(GS.sect_favor) + "/" + str(FAVOR_NEED) + " · 声望 " + str(GS.sect_rep) + "/" + str(REP_NEED) + " · 正邪 中立（过） · 考验 " + ("过" if GS.sect_test else "未过")
	var ready := GS.sect_favor >= FAVOR_NEED and GS.sect_rep >= REP_NEED and GS.sect_test
	_learn_btn.disabled = GS.sect_art or not ready
	_learn_btn.text = "已领功法" if GS.sect_art else ("求 功 法" if ready else "四门未足")

func _gift() -> void:
	if GS.coin("silver") < GIFT_SILVER:
		_say("银两不够——送礼要 " + str(GIFT_SILVER) + " 两。")
		return
	GS.add_coin("silver", -GIFT_SILVER)
	GS.sect_favor = mini(100, GS.sect_favor + 15)
	GS.save_game()
	_say("礼收下了。好感 +15。")
	_refresh()

func _donate() -> void:
	if GS.coin("silver") < DONATE_SILVER:
		_say("银两不够——捐银要 " + str(DONATE_SILVER) + " 两。")
		return
	GS.add_coin("silver", -DONATE_SILVER)
	GS.sect_rep = mini(100, GS.sect_rep + 20)
	GS.save_game()
	_say("山门记下了这份香火。声望 +20。")
	_refresh()

func _test() -> void:
	if GS.sect_test:
		_say("考验已经过了。")
		return
	if GS.coin("silver") < TEST_SILVER:
		_say("跑腿要 " + str(TEST_SILVER) + " 两。")
		return
	if GS.action < TEST_ACTION:
		_say("行动不够——跑这趟要 " + str(TEST_ACTION) + " 点行动。")
		return
	GS.add_coin("silver", -TEST_SILVER)
	GS.action_spend(TEST_ACTION)
	GS.sect_test = true
	GS.save_game()
	_say("一趟脏活跑完，山门认了你这份投名状。")
	_refresh()

func _learn() -> void:
	if GS.sect_art:
		_say("这门功法已经传过你了。")
		return
	if GS.sect_favor < FAVOR_NEED or GS.sect_rep < REP_NEED or not GS.sect_test:
		_say("四门还没足——好感、声望、考验，缺一门都只给指点。")
		return
	GS.sect_art = true
	GS.vault_add_item(ART_SID, 1)
	GS.save_game()
	_say("山门传下《疾风剑法》。回村在角色面板里装到武学槽。")
	_refresh()
