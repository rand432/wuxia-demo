extends Control
# 世界窗口：先生成世界，再进入游历配置。
# 第一次生成不显示难度，默认简单；之后创建新世界才选难度。

signal closed
signal enter_requested
signal world_generated

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")

var _panel: Panel
var _title: Label
var _body: Control
var _mode := "main"
var _diff := 1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.66)
	_panel = UiKit.make_paper_panel(veil, Rect2(50, 190, 620, 900))
	_panel.add_theme_stylebox_override("panel", UiKit.paper_box(1.0))
	_title = UiKit.make_label(_panel, Vector2(0, 20), Vector2(620, 46), 32, UiKit.INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body = Control.new()
	_body.position = Vector2(30, 86)
	_body.size = Vector2(560, 720)
	_panel.add_child(_body)
	visible = false

func open() -> void:
	_mode = "main"
	visible = true
	_rebuild()

func close() -> void:
	visible = false
	closed.emit()

func _clear_body() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()

func _rebuild() -> void:
	_clear_body()
	if _mode == "create":
		_build_create()
	elif _mode == "records":
		_build_records()
	else:
		_build_main()

func _build_main() -> void:
	_title.text = "世 界"
	if not GS.world_created:
		var l := _label("还没有世界。\n先生成一个，再进游历。", 22, UiKit.INK)
		l.position = Vector2(20, 70)
		l.size = Vector2(520, 100)
		var b := _button("生 成 新 世 界", Vector2(130, 210), Vector2(300, 56))
		b.pressed.connect(_on_create)
		var close_b := _button("关 闭", Vector2(210, 620), Vector2(140, 44))
		close_b.pressed.connect(close)
		return
	var info := _label(_world_line(), 20, UiKit.INK)
	info.position = Vector2(20, 20)
	info.size = Vector2(520, 70)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var diff_l := _label("难度：" + _diff_name(GS.world_difficulty) + " · 资源 ×" + str(GS.world_resource_mul()), 17, UiKit.DIM)
	diff_l.position = Vector2(20, 90)
	diff_l.size = Vector2(520, 28)
	var rl := _label("去处（只列已生成的区块）", 17, UiKit.DIM)
	rl.position = Vector2(20, 126)
	rl.size = Vector2(520, 26)
	var idx := 0
	for i in 5:
		if not bool(GS.region_unlocked[i]):
			continue
		var mark := "● " if i == GS.current_region else ""
		var rb := _button(mark + str(GS.REGION_NAMES[i]), Vector2(20 + idx * 100, 158), Vector2(92, 44))
		rb.pressed.connect(_pick_region.bind(i))
		idx += 1
	var enter := _button("进 入 世 界", Vector2(130, 230), Vector2(300, 56))
	enter.pressed.connect(_on_enter)
	var rec := _button("游 历 记 录", Vector2(80, 320), Vector2(200, 48))
	rec.pressed.connect(_on_records)
	var create := _button("创 建 新 世 界", Vector2(300, 320), Vector2(200, 48))
	create.pressed.connect(_on_create)
	var close_b2 := _button("关 闭", Vector2(210, 620), Vector2(140, 44))
	close_b2.pressed.connect(close)

func _build_create() -> void:
	_title.text = "创 建 新 世 界"
	var first := not GS.world_created
	var l := _label(("这是你的第一个世界。\n默认简单难度。" if first else "当前世界会被替换，旧世界只留一条游历记录。"), 19, UiKit.INK)
	l.position = Vector2(20, 10)
	l.size = Vector2(520, 60)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cost := 0 if first else 1
	var c := _label("消耗：舆图 ×" + str(cost) + ("（首次免费）" if first else ""), 17, UiKit.DIM)
	c.position = Vector2(20, 80)
	c.size = Vector2(520, 26)
	if not first:
		var dl := _label("难度（生成后固定）", 17, UiKit.DIM)
		dl.position = Vector2(20, 130)
		dl.size = Vector2(520, 26)
		var names := ["简单", "普通", "困难"]
		for i in 3:
			var b := _button(names[i] + " ×" + ["1.0", "1.3", "1.6"][i], Vector2(20 + i * 175, 164), Vector2(160, 52))
			b.pressed.connect(_pick_diff.bind(i + 1))
		var sel := _label("已选：" + _diff_name(_diff), 16, UiKit.SEAL)
		sel.position = Vector2(20, 226)
		sel.size = Vector2(520, 24)
	var tip := _label("一键默认：山 / 水 / 林 + 舆图够就自动加石 / 雪。", 15, UiKit.DIM)
	tip.position = Vector2(20, 270)
	tip.size = Vector2(520, 46)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var go := _button("一 键 默 认 生 成", Vector2(130, 360), Vector2(300, 56))
	go.pressed.connect(_generate)
	var back := _button("返 回", Vector2(210, 620), Vector2(140, 44))
	back.pressed.connect(func() -> void: _mode = "main"; _rebuild())

func _build_records() -> void:
	_title.text = "游 历 记 录"
	if GS.world_history.is_empty():
		var l := _label("还没有旧世界。\n当前世界是第一段游历。", 20, UiKit.DIM)
		l.position = Vector2(20, 80)
		l.size = Vector2(520, 100)
	else:
		var y := 20.0
		for i in mini(5, GS.world_history.size()):
			var e: Dictionary = GS.world_history[GS.world_history.size() - 1 - i]
			var txt := "第" + str(int(e.get("week", 1))) + "周 · " + str(e.get("regions", "山/水/林")) + "\n繁荣 " + str(int(e.get("prosperity", 0))) + " · " + str(e.get("title", "无名"))
			var lb := _label(txt, 16, UiKit.INK)
			lb.position = Vector2(20, y)
			lb.size = Vector2(520, 56)
			lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			y += 66.0
	var back2 := _button("返 回", Vector2(210, 620), Vector2(140, 44))
	back2.pressed.connect(func() -> void: _mode = "main"; _rebuild())

func _on_create() -> void:
	_mode = "create"
	_diff = clampi(GS.world_difficulty, 1, 3)
	_rebuild()

func _pick_region(i: int) -> void:
	GS.current_region = clampi(i, 0, 4)
	GS.save_game()
	_rebuild()

func _on_records() -> void:
	_mode = "records"
	_rebuild()

func _on_enter() -> void:
	visible = false
	enter_requested.emit()

func _pick_diff(d: int) -> void:
	_diff = d
	_rebuild()

func _generate() -> void:
	var first := not GS.world_created
	var cost := 0 if first else 1
	if GS.material_count("atlas") < cost:
		_show_msg("舆图不够")
		return
	GS.add_material("atlas", -cost)
	if not first and GS.world_seed >= 0:
		GS.world_history.append({
			"week": GS.ng_plus + 1,
			"regions": _region_text(GS.region_unlocked),
			"prosperity": GS.world_prosperity,
			"title": GS.story_title,
		})
	GS.world_flags.clear()
	GS.current_region = 0
	GS.region_unlocked = [true, true, true, false, false]
	# 一键默认：舆图够就自动把石 / 雪加进去（先石后雪）
	if GS.material_count("atlas") >= 2:
		GS.add_material("atlas", -2)
		GS.region_unlocked[3] = true
	if GS.material_count("atlas") >= 3:
		GS.add_material("atlas", -3)
		GS.region_unlocked[4] = true
	GS.world_seed += 1
	GS.world_prosperity = 0
	GS.world_tier = 1
	GS.world_difficulty = 1 if first else clampi(_diff, 1, 3)
	GS.world_created = true
	GS.first_explore_done = false
	GS.time_slot = 0
	GS.time_day = 1
	GS.slot_progress = 0
	GS.region_rep = [0, 0, 0, 0, 0]
	GS.region_seen = [false, false, false, false, false]
	GS.region_walk = [0, 0, 0, 0, 0]
	GS.merchant_stock_slot = ""
	GS.merchant_stock.clear()
	GS.npc_stock.clear()
	GS.region_landmarks.clear()
	GS.npc_budget = -1
	GS.ng_event_seen = false
	GS.ng_event_choice = -1
	GS.ng_echo_seen = false
	GS.ng_final_seen = false
	GS.ng_final_choice = -1
	GS.ng_wuxia_done = false
	GS.save_game()
	visible = false
	world_generated.emit()

func _show_msg(t: String) -> void:
	var l := _label(t, 18, UiKit.SEAL)
	l.position = Vector2(20, 440)
	l.size = Vector2(520, 30)

func _world_line() -> String:
	return "第" + str(GS.ng_plus + 1) + "周 · " + _region_text(GS.region_unlocked) + "\n繁荣 " + str(GS.world_prosperity) + " · 世界档 " + str(GS.world_tier)

func _region_text(arr: Array) -> String:
	var out: Array = []
	for i in mini(5, arr.size()):
		if bool(arr[i]):
			out.append(str(GS.REGION_NAMES[i]))
	return " / ".join(PackedStringArray(out))

func _diff_name(d: int) -> String:
	return ["简单", "普通", "困难"][clampi(d - 1, 0, 2)]

func _label(t: String, sz: int, col: Color) -> Label:
	var l := UiKit.make_label(_body, Vector2.ZERO, Vector2(520, 30), sz, col)
	UiKit.set_text(l, t)
	return l

func _button(t: String, p: Vector2, s: Vector2) -> Button:
	var b := UiKit.make_button(_body, p, s, t, 18)
	return b
