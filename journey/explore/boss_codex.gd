extends Control
# v262：凶物图鉴——四只区域 Boss（含雪原雪魈）的首杀 / 专属记录。
signal closed

const UiKit := preload("res://shared/ui_kit.gd")
const GS := preload("res://shared/game_state.gd")

const BOSSES := [
	{"name": "山君", "weapon": "山君骨刃", "weak": "左肋旧伤——再战气血 -10%", "lore": "盘踞山坳的虎形凶物，喜食过路商队。"},
	{"name": "夜叉", "weapon": "夜叉鬼爪", "weak": "怕火——再战气血 -10%", "lore": "古战场残念所化，夜行如风。"},
	{"name": "老妖", "weapon": "老妖杖", "weak": "根须怕断——再战气血 -10%", "lore": "老树成精，根须缠住整条山道。"},
	{"name": "石傀", "weapon": "石傀重锤", "weak": "核心外露——再战气血 -10%", "lore": "石谷深处的守矿巨像，醒来只为碾碎入侵者。"},
	{"name": "雪魈", "weapon": "雪魈獠牙", "weak": "畏热——再战气血 -10%", "lore": "雪原深处的高大人形凶物，毛色与雪同白。"},
	{"name": "无相", "weapon": "无相刃", "weak": "无相无形——首杀后识破", "lore": "轮回台上的无面之影，像是上一世的你。"},
]

var _sub_lb: Label
var _rows: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := UiKit.make_veil(self, Vector2(720, 1280), 0.62)
	var panel := UiKit.make_paper_panel(veil, Rect2(50, 200, 620, 860))
	panel.add_theme_stylebox_override("panel", UiKit.paper_box(1.0))
	var title := UiKit.make_label(panel, Vector2(0, 20), Vector2(620, 46), 34, UiKit.INK)
	UiKit.set_text(title, "凶 物 图 鉴")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lb = UiKit.make_label(panel, Vector2(0, 70), Vector2(620, 24), 15, UiKit.DIM)
	_sub_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in BOSSES.size():
		var b: Dictionary = BOSSES[i]
		var y := 90.0 + float(i) * 112.0
		if i > 0:
			# v248：六只凶物之间加一道极细金线，免得名字/弱点/典故糊成一片
			var sep := ColorRect.new()
			sep.position = Vector2(40, y - 8.0)
			sep.size = Vector2(540, 1)
			sep.color = Color(0.72, 0.58, 0.22, 0.22)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(sep)
		var nm := UiKit.make_label(panel, Vector2(40, y), Vector2(540, 34), 24, UiKit.SEAL)
		UiKit.set_text(nm, str(b["name"]))
		var st := UiKit.make_label(panel, Vector2(40, y + 30), Vector2(540, 20), 15, UiKit.INK)
		var wp := UiKit.make_label(panel, Vector2(40, y + 50), Vector2(540, 18), 14, UiKit.DIM)
		UiKit.set_text(wp, "专属：" + str(b["weapon"]))
		var wk := UiKit.make_label(panel, Vector2(40, y + 70), Vector2(540, 18), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.52))
		var lo := UiKit.make_label(panel, Vector2(40, y + 88), Vector2(540, 24), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.68))
		UiKit.set_text(lo, str(b["lore"]))
		lo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rows.append({"name": str(b["name"]), "status": st, "weak": wk, "weak_txt": str(b["weak"])})
	var back := UiKit.make_button(panel, Vector2(210, 800), Vector2(200, 46), "关 闭", 18)
	back.pressed.connect(close)
	visible = false

func open() -> void:
	var got := 0
	for r_v in _rows:
		var r: Dictionary = r_v
		var killed := GS.boss_kills.has(str(r["name"]))
		if killed:
			got += 1
		var st: Label = r["status"]
		st.text = "已首杀 · 专属已入手" if killed else "未首杀"
		st.add_theme_color_override("font_color", UiKit.GOLD if killed else Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.55))
		var wk: Label = r["weak"]
		wk.text = "弱点：" + str(r["weak_txt"]) if killed else "弱点：未识破（首杀后记下）"
		wk.add_theme_color_override("font_color", UiKit.SEAL if killed else Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.42))
	_sub_lb.text = "已首杀 " + str(got) + " / " + str(BOSSES.size()) + " · 已识破 " + str(got) + " 处弱点"
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
