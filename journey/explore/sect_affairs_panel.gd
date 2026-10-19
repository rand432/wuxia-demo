extends Control
# v253：宗门事务——入门后的贡献 / 任务 / 藏经阁。
signal closed
signal arena_requested

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")

const ARTS := [
	{"sid": "art_cloud", "name": "流云剑法", "cost": 60, "rank": 1},
	{"sid": "art_river", "name": "大江剑势", "cost": 120, "rank": 2},
]

var _top_lb: Label
var _task_btns: Array = []
var _arts_lbs: Array = []
var _art_btns: Array = []
var _arena_btn: Button
var _msg_lb: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.64)
	var panel := UiKit.make_paper_panel(veil, Rect2(50, 280, 620, 760))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.90, 0.83, 1.0)
	sb.border_color = Color(0.42, 0.33, 0.20, 0.60)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.z_index = 200
	panel.modulate = Color(1, 1, 1, 1)
	var title := UiKit.make_label(panel, Vector2(0, 20), Vector2(620, 46), 32, UiKit.INK)
	UiKit.set_text(title, "宗 门 事 务")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top_lb = UiKit.make_label(panel, Vector2(0, 70), Vector2(620, 24), 15, UiKit.DIM)
	_top_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var task_title := UiKit.make_label(panel, Vector2(40, 112), Vector2(540, 26), 17, UiKit.SEAL)
	UiKit.set_text(task_title, "杂 役")
	var tasks := ["交兽骨碎 ×3 · 贡献 +20", "交锻造石 ×2 · 贡献 +25", "跑腿 3 行动 · 贡献 +15"]
	for i in tasks.size():
		var b := UiKit.make_button(panel, Vector2(170, 150 + i * 54), Vector2(280, 44), tasks[i], 16)
		b.pressed.connect(_do_task.bind(i))
		_task_btns.append(b)

	var shop_title := UiKit.make_label(panel, Vector2(40, 330), Vector2(540, 26), 17, UiKit.SEAL)
	UiKit.set_text(shop_title, "藏 经 阁")
	for i in ARTS.size():
		var a: Dictionary = ARTS[i]
		var lb := UiKit.make_label(panel, Vector2(40, 370 + i * 56), Vector2(300, 40), 16, UiKit.INK)
		UiKit.set_text(lb, str(a["name"]) + " · " + str(a["cost"]) + " 贡献")
		_arts_lbs.append(lb)
		var b := UiKit.make_button(panel, Vector2(400, 366 + i * 56), Vector2(180, 42), "借 阅", 16)
		b.pressed.connect(_learn.bind(i))
		_art_btns.append(b)

	_arena_btn = UiKit.make_button(panel, Vector2(170, 486), Vector2(280, 44), "演武场 · 挑战师兄（2行动）", 15)
	_arena_btn.pressed.connect(_arena)
	_msg_lb = UiKit.make_label(panel, Vector2(40, 552), Vector2(540, 54), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.75))
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := UiKit.make_button(panel, Vector2(210, 620), Vector2(200, 46), "回 山 门", 18)
	back.pressed.connect(close)
	visible = false

func _rank_idx() -> int:
	if GS.sect_contrib >= 250:
		return 2
	if GS.sect_contrib >= 100:
		return 1
	return 0

func _rank_name() -> String:
	return ["外门弟子", "内门弟子", "真传弟子"][_rank_idx()]

func open() -> void:
	visible = true
	_msg_lb.text = "贡献可换藏经阁的功法。"
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _refresh() -> void:
	var bonus := 5 if GS.story_title == "青岚客卿" else 0
	_task_btns[0].text = "交兽骨碎 ×3 · 贡献 +" + str(20 + bonus)
	_task_btns[1].text = "交锻造石 ×2 · 贡献 +" + str(25 + bonus)
	_task_btns[2].text = "跑腿 3 行动 · 贡献 +" + str(15 + bonus)
	_top_lb.text = "青岚山门 · " + _rank_name() + " · 贡献 " + str(GS.sect_contrib)
	_task_btns[0].disabled = GS.material_count("bone") < 3
	_task_btns[1].disabled = GS.material_count("forge_stone") < 2
	_task_btns[2].disabled = GS.action < 3
	_arena_btn.disabled = GS.action < 2
	for i in ARTS.size():
		var a: Dictionary = ARTS[i]
		var rank_ok := _rank_idx() >= int(a["rank"])
		var owned := GS.vault_item_count(str(a["sid"])) > 0
		var b: Button = _art_btns[i]
		b.disabled = owned or not rank_ok or GS.sect_contrib < int(a["cost"])
		if owned:
			b.text = "已 学"
		elif not rank_ok:
			b.text = ["", "需 内 门", "需 真 传"][int(a["rank"])]
		else:
			b.text = "借 阅"

func _arena() -> void:
	if GS.action < 2:
		_msg_lb.text = "行动不够——挑战师兄要 2 点行动。"
		return
	arena_requested.emit()

func _do_task(i: int) -> void:
	var bonus := 5 if GS.story_title == "青岚客卿" else 0
	match i:
		0:
			if GS.material_count("bone") < 3:
				return
			GS.add_material("bone", -3)
			GS.sect_contrib += 20 + bonus
			_msg_lb.text = "交了兽骨碎。贡献 +" + str(20 + bonus) + "。"
		1:
			if GS.material_count("forge_stone") < 2:
				return
			GS.add_material("forge_stone", -2)
			GS.sect_contrib += 25 + bonus
			_msg_lb.text = "交了锻造石。贡献 +" + str(25 + bonus) + "。"
		2:
			if not GS.action_spend(3):
				return
			GS.sect_contrib += 15 + bonus
			_msg_lb.text = "跑完一趟腿。贡献 +" + str(15 + bonus) + "。"
	GS.save_game()
	_refresh()

func _learn(i: int) -> void:
	var a: Dictionary = ARTS[i]
	var sid := str(a["sid"])
	if GS.vault_item_count(sid) > 0:
		_msg_lb.text = "这门功法已经在库里了。"
		return
	if _rank_idx() < int(a["rank"]):
		_msg_lb.text = "身份不够——先攒贡献升内门 / 真传。"
		return
	if GS.sect_contrib < int(a["cost"]):
		_msg_lb.text = "贡献不够。"
		return
	GS.sect_contrib -= int(a["cost"])
	GS.vault_add_item(sid, 1)
	GS.save_game()
	_msg_lb.text = "从藏经阁抄了《" + str(a["name"]) + "》，回村可装配。"
	_refresh()
