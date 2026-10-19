extends Control
# v261：江湖后记——把称号 / 青岚 / 赤水 / 听雨 / 密信 / 凶物收成一页。
signal closed

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")
const POIPanel := preload("res://journey/explore/poi_panel.gd")

var _body_lb: Label
var _new_btn: Button
var _back_btn: Button
var _confirm_panel: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.66)
	var panel := UiKit.make_paper_panel(veil, Rect2(50, 160, 620, 920))
	panel.add_theme_stylebox_override("panel", UiKit.paper_box(1.0))
	var title := UiKit.make_label(panel, Vector2(0, 20), Vector2(620, 46), 32, UiKit.INK)
	UiKit.set_text(title, "江 湖 后 记")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UiKit.make_label(panel, Vector2(0, 70), Vector2(620, 24), 14, UiKit.DIM)
	UiKit.set_text(sub, "走过的路，都记在这里")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_lb = UiKit.make_label(panel, Vector2(40, 112), Vector2(540, 700), 15, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.82))
	_body_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_new_btn = UiKit.make_button(panel, Vector2(210, 760), Vector2(200, 46), "再入江湖", 16)
	_new_btn.pressed.connect(_open_confirm)
	_back_btn = UiKit.make_button(panel, Vector2(210, 830), Vector2(200, 46), "关 闭", 18)
	_back_btn.pressed.connect(close)
	visible = false

func open() -> void:
	var lines: Array = []
	lines.append("周目：第 " + str(GS.ng_plus + 1) + " 周")
	lines.append("称号：" + (GS.story_title if GS.story_title != "" else "尚未定下"))
	var rank := "外门弟子"
	if GS.sect_contrib >= 250:
		rank = "真传弟子"
	elif GS.sect_contrib >= 100:
		rank = "内门弟子"
	lines.append("青岚：" + ("已入门 · " + rank if GS.sect_joined else "未入门") + " · 贡献 " + str(GS.sect_contrib) + " · 好感 " + str(GS.sect_favor))
	var rw: String = str(["未动", "已破", "青岚控制"][clampi(GS.red_water, 0, 2)])
	lines.append("赤水寨：" + str(rw) + (" · 已平" if GS.red_water_peace else "") + " · 战线 " + str(GS.war_score) + "/100")
	var b: Array = []
	if GS.red_water_wall:
		b.append("寨墙")
	if GS.red_water_market:
		b.append("货栈")
	if GS.red_water_garrison:
		b.append("驻军")
	if GS.red_water_taxpost:
		b.append("税所")
	lines.append("寨务：" + (" · ".join(PackedStringArray(b)) if not b.is_empty() else "未建"))
	lines.append("北境：" + ("已平" if GS.north_peace else ("战线 " + str(GS.north_score) + "/100")) + " · 小胜 " + str(GS.north_wins) + (" · 黑风刀已得" if GS.north_weapon else "") + (" · 驻军" if GS.north_garrison else ""))
	lines.append("听雨楼：" + GS.broker_rank_name() + " · 名声 " + str(GS.broker_rep) + "/100 · 委托 " + str(GS.broker_quest) + "/3")
	lines.append("听雨刃：" + ("已得" if GS.broker_weapon else "未得") + " · 听雨令：" + ("已用" if GS.broker_pardon else "未用"))
	var letter := "未遇"
	if GS.story_letter == 1:
		letter = "交给了青岚"
	elif GS.story_letter == 2:
		letter = "卖给了赤水"
	elif GS.story_letter == 3:
		letter = "烧掉了"
	lines.append("密信：" + letter)
	lines.append("凶物首杀：" + str(GS.boss_kills.size()) + "/4")
	var after := ""
	match GS.story_title:
		"青岚客卿":
			after = "青岚后山给你留了一间屋子。窗对着旧练武场，夜里能听见弟子收剑。"
		"听雨客":
			after = "听雨楼最高一层留了一盏不灭的灯。楼主说，灯亮着，你就还有一处可回。"
		"江湖散人":
			after = "没人知道你从哪来。你也不急着说。路还长，酒还温。"
	if after != "":
		lines.append("—— 后日谈 ——\n" + after)
	if GS.red_water_peace and GS.north_peace:
		lines.append("—— 天下太平 ——\n赤水与北境都已平定。江湖上暂时没有你的仗，只有还没走完的路。")
	_body_lb.text = "\n\n".join(PackedStringArray(lines))
	_new_btn.visible = GS.red_water_peace and GS.north_peace
	_back_btn.visible = true
	visible = true

func _open_confirm() -> void:
	if _confirm_panel == null:
		var cp = POIPanel.new()
		cp.connect("picked", _on_confirm_pick)
		cp.connect("closed", _on_confirm_closed)
		add_child(cp)
		_confirm_panel = cp
	_back_btn.visible = false
	_new_btn.visible = false
	_confirm_panel.call("open", {
		"title": "再 入 江 湖",
		"sub": "第 " + str(GS.ng_plus + 2) + " 周",
		"body": "赤水与北境会重新立起来，密信 / 名声 / 战线重走。\n锻造库、称号、材料、银两会留下。",
		"choices": [{"id": "yes", "label": "确 认"}, {"id": "no", "label": "再 想 想"}],
	})

func _on_confirm_pick(id: String) -> void:
	_confirm_panel.call("close")
	if id != "yes":
		_back_btn.visible = true
		_new_btn.visible = GS.red_water_peace and GS.north_peace
		return
	GS.begin_new_cycle()
	close()

func _on_confirm_closed() -> void:
	if visible:
		_back_btn.visible = true
		_new_btn.visible = GS.red_water_peace and GS.north_peace

func close() -> void:
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if _confirm_panel != null and _confirm_panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
