extends Control
# ============================================================
# menu/character_home.gd —— 装备页（一屏看完）
#   立绘 + 四槽 + 属性 + 背包（5×2 + 分类）
# ============================================================
const UI := preload("res://shared/ui_kit.gd")
const P := preload("res://shared/ui_pal.gd")
const FD := preload("res://shared/forge_data.gd")
const CharArt := preload("res://shared/char_art.gd")
const GameState := preload("res://shared/game_state.gd")
const Audio := preload("res://shared/audio.gd")

const SLOTS := [
	{"key": "weapon", "rect": Rect2(32, 180, 132, 132)},
	{"key": "armor", "rect": Rect2(556, 180, 132, 132)},
	{"key": "jade", "rect": Rect2(32, 418, 132, 132)},
	{"key": "cloak", "rect": Rect2(556, 418, 132, 132)},
]
const BAG_RECT := Rect2(24, 812, 672, 204)
const CATS := ["全 部", "装 备", "材 料", "丹 药"]

var _bag_roots: Array = []
var _cats: Array = []
var _cat := 0
var _rebuild_pending := false

func _ready() -> void:
	GameState.ensure_loaded()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_all()

func _build_all() -> void:
	FD.load_game()
	theme = UI.theme()
	_bag_roots.clear()
	_cats.clear()
	UI.bg(self)
	UI.app_bar(self, GameState.player_name, "玄品", func() -> void: UI.open_settings(self))
	UI.page_head(self, "角 色", func() -> void:
		UI.navigate(self, "res://menu/main_home.tscn"))
	_build_figure()
	_build_attr()
	_build_bag()
	UI.dock(self, "role", _on_dock)

func _rebuild() -> void:
	if _rebuild_pending or not UI.navigation_available(self): return
	_rebuild_pending = true
	await get_tree().process_frame
	_rebuild_pending = false
	if not UI.navigation_available(self): return
	_detail = null
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build_all()

# ---------------- 立绘 + 四槽 ----------------
func _build_figure() -> void:
	UI.panel(self, Rect2(22, 154, 676, 452), Color(0.90, 0.865, 0.79), 14, P.LINE, 1)
	var tex := CharArt.full("player")
	if tex != null:
		var clip := Control.new()
		clip.position = Vector2(196, 152)
		clip.size = Vector2(328, 448)
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(clip)
		UI.panel(clip, Rect2(0, 4, 328, 440), Color(0.15, 0.16, 0.145), 12, Color(0.66, 0.51, 0.32), 2)
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = tex
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(tr)
		tr.position = Vector2(6, 10)
		tr.size = clip.size - Vector2(12, 20)
	for s in SLOTS:
		_build_slot(str(s["key"]), s["rect"])

func _build_slot(key: String, rect: Rect2) -> void:
	var root := Button.new()
	root.name = "Slot_%s" % key
	root.position = rect.position
	root.size = rect.size
	root.focus_mode = Control.FOCUS_NONE
	root.tooltip_text = str(FD.SLOT_LABEL.get(key, key))
	var blank := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "focus"]:
		root.add_theme_stylebox_override(style, blank)
	root.pressed.connect(_on_slot.bind(key))
	add_child(root)
	var it: Dictionary = FD.equipped.get(key, {})
	var filled := not it.is_empty()
	var qcol: Color = P.quality(int(it.get("quality", 1))) if filled else Color(0.745, 0.667, 0.643)
	var pan := Panel.new()
	pan.position = Vector2.ZERO
	pan.size = rect.size
	pan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.988, 0.976, 0.949)
	sb.set_corner_radius_all(12)
	sb.border_color = qcol
	sb.set_border_width_all(3 if filled else 2)
	pan.add_theme_stylebox_override("panel", sb)
	root.add_child(pan)
	if filled:
		var art: String = str(FD.SLOT_ART.get(key, "res://assets/items/it_sword.png"))
		if ResourceLoader.exists(art):
			var tr := TextureRect.new()
			tr.texture = load(art)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(tr)
			tr.position = Vector2(28, 10)
			tr.size = Vector2(76, 76)
		var plus := int(it.get("plus", 0))
		var tag := Panel.new()
		tag.position = Vector2(78, 6)
		tag.size = Vector2(50, 24)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(0.149, 0.129, 0.106)
		tsb.set_corner_radius_all(5)
		tsb.border_color = P.GOLD
		tsb.set_border_width_all(1)
		tag.add_theme_stylebox_override("panel", tsb)
		root.add_child(tag)
		UI.label(root, "+" + str(plus), Vector2(78, 6), Vector2(50, 24), 14, Color(0.973, 0.886, 0.659), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var dash := Panel.new()
		dash.position = Vector2(12, 12)
		dash.size = Vector2(rect.size.x - 24, 76)
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color(0, 0, 0, 0)
		dsb.border_color = Color(0.804, 0.753, 0.675)
		dsb.set_border_width_all(1)
		dash.add_theme_stylebox_override("panel", dsb)
		dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(dash)
		UI.label(root, "空", Vector2(0, 12), Vector2(rect.size.x, 76), 17, Color(0.737, 0.698, 0.639), HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(root, str(FD.SLOT_LABEL.get(key, key)), Vector2(0, 100), Vector2(rect.size.x, 26), 19, P.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	# 入神中：流动彩虹边 + 呼吸金晕
	var stt: Dictionary = FD.state.get(key, {}) if FD.state.has(key) else {}
	if int(stt.get("trance", 0)) > 0:
		var ov := SlotTrance.new()
		ov.size = rect.size
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ov)
	UI.Motion.bind_button(root)

func _on_slot(key: String) -> void:
	if _rebuild_pending or not UI.navigation_available(self): return
	Audio.sfx("ui_click", -8.0)
	var it: Dictionary = FD.equipped.get(key, {})
	if it.is_empty():
		_show_toast("该部位还没有装备")
		return
	var dlg: Control = (load("res://menu/equip_detail.tscn") as PackedScene).instantiate()
	add_child(dlg)
	var forging := [false]
	dlg.forge_requested.connect(func(key: String) -> void:
		forging[0] = true
		_open_forge(key))
	dlg.closed.connect(func() -> void:
		# 锻造页关闭后才重建，不能把刚打开的锻造页一起删掉。
		if not forging[0]: _rebuild())
	dlg.open(key)

func _open_forge(key: String) -> Node:
	if _rebuild_pending or not UI.navigation_available(self): return null
	var fs: Control = (load("res://menu/forge_sheet.tscn") as PackedScene).instantiate()
	add_child(fs)
	fs.closed.connect(_rebuild)
	fs.open(key)
	return fs

# ---------------- 属性（一行四条：攻击 / 气血 / 内力 / 攻速） ----------------
#   数值来自 shared/char_sheet.gd（装备合计 ＋ 基础常量），
#   **点这一行任意处** → 打开详细属性页（和战斗里同一套面板）。
var _sheet = null          # shared/char_sheet.gd
var _detail = null         # kushou/attr_panel.gd

func _build_attr() -> void:
	if _sheet == null:
		_sheet = load("res://shared/char_sheet.gd").new()
	_sheet.refresh()
	var h: Dictionary = _sheet.hero
	UI.label(self, "属 性", Vector2(24, 648), Vector2(120, 32), 22, P.DIM)
	# 「ⓘ」：点它或点整行都能开详细属性
	var info := Panel.new()
	info.position = Vector2(150, 654)
	info.size = Vector2(22, 22)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0, 0, 0, 0)
	isb.set_corner_radius_all(11)
	isb.border_color = Color(0.627, 0.588, 0.533)
	isb.set_border_width_all(1)
	info.add_theme_stylebox_override("panel", isb)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	UI.label(self, "i", Vector2(150, 654), Vector2(22, 22), 14, Color(0.588, 0.549, 0.494), HORIZONTAL_ALIGNMENT_CENTER)
	var cells := [
		["攻 击", str(int(float(h["atk"])))],
		["气 血", str(int(float(h["hp_max"])))],
		["内 力", str(int(float(h["mp_max"])))],
		["攻 速", "%.2f/秒" % (1.0 / _sheet.hero_attack_interval())],
	]
	for c in cells.size():
		var x := 24.0 + float(c) * 168.0
		UI.label(self, str(cells[c][0]), Vector2(x, 690), Vector2(96, 32), 20, P.DIM)
		UI.label(self, str(cells[c][1]), Vector2(x + 76, 686), Vector2(92, 34), 24, P.INK)
	# 属性区与背包区之间的极淡分隔线
	var line := ColorRect.new()
	line.position = Vector2(24, 752)
	line.size = Vector2(672, 1)
	line.color = Color(0.804, 0.757, 0.678)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	# 整块可点：标题行 + 四条属性
	var hit := Button.new()
	hit.position = Vector2(24, 644)
	hit.size = Vector2(672, 96)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.pressed.connect(_open_detail)
	add_child(hit)
	UI.Motion.bind_button(hit)

func _open_detail() -> void:
	if _sheet == null or _rebuild_pending or not UI.navigation_available(self):
		return
	if not is_instance_valid(_detail):
		_detail = load("res://kushou/attr_panel.gd").new()
		add_child(_detail)
		_detail.z_index = 60
	_detail.setup(_sheet)
	_detail.open()

# ---------------- 背包（三类 + 竖直滚动） ----------------
const CATS2 := ["装备", "材料", "道具"]
var _scroll: ScrollContainer = null
var _grid: GridContainer = null
var _count_lb: Label = null
var _bag_empty: Label

func _build_bag() -> void:
	UI.label(self, "背 包", Vector2(24, 770), Vector2(120, 34), 22, P.DIM)
	_count_lb = UI.label(self, "", Vector2(140, 770), Vector2(200, 34), 18, Color(0.588, 0.541, 0.471))
	for i in CATS2.size():
		var b := Button.new()
		b.text = CATS2[i]
		b.position = Vector2(300.0 + float(i) * 136.0, 766)
		b.size = Vector2(126, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(func() -> void:
			_cat = i
			Audio.sfx("ui_click", -8.0)
			_style_cats()
			_fill_grid())
		add_child(b)
		UI.Motion.bind_button(b)
		_cats.append(b)
	_style_cats()
	UI.panel(self, Rect2(24, 818, 672, 344), Color(0.94, 0.914, 0.86, 0.78), 12, P.LINE, 1)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(24, 818)
	_scroll.size = Vector2(660, 348)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_scroll.add_child(_grid)
	_bag_empty = UI.label(self, "该分类暂无物品", Vector2(24, 932), Vector2(672, 58), 22, P.DIM,
		HORIZONTAL_ALIGNMENT_CENTER)
	_fill_grid()

func _style_cats() -> void:
	for i in _cats.size():
		var b: Button = _cats[i]
		var on := i == _cat
		var sb := StyleBoxFlat.new()
		sb.bg_color = P.SEAL if on else P.PAPER_HI
		sb.set_corner_radius_all(22)
		sb.border_color = P.GOLD if on else Color(0.784, 0.737, 0.659)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(0.980, 0.929, 0.839) if on else P.DIM)

func _fill_grid() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var cat: String = str(CATS2[_cat])
	var list: Array = FD.bag_of(cat)
	for it_v in list:
		var it: Dictionary = it_v
		_grid.add_child(_bag_cell(it))
	if _count_lb != null:
		_count_lb.text = str(list.size()) + "　件"
	_bag_empty.visible = list.is_empty()

func _bag_cell(it: Dictionary) -> Control:
	var root := Panel.new()
	root.custom_minimum_size = Vector2(120, 104)
	root.size = Vector2(120, 104)
	var q := int(it.get("quality", 1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.988, 0.976, 0.949)
	sb.set_corner_radius_all(8)
	sb.border_color = P.quality(q) if str(it.get("cat", "")) == "装备" else Color(0.784, 0.737, 0.659)
	sb.set_border_width_all(2 if str(it.get("cat", "")) == "装备" else 1)
	root.add_theme_stylebox_override("panel", sb)
	var art: String = str(it.get("icon", ""))
	if art != "" and ResourceLoader.exists(art):
		var tr := TextureRect.new()
		tr.texture = load(art)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tr)
		tr.position = Vector2(34, 8)
		tr.size = Vector2(52, 52)
	UI.label(root, str(it.get("name", "")), Vector2(0, 64), Vector2(120, 24), 15, P.INK, HORIZONTAL_ALIGNMENT_CENTER)
	if int(it.get("plus", 0)) > 0:
		var tagp := Panel.new()
		tagp.position = Vector2(88, 4)
		tagp.size = Vector2(28, 20)
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(0.149, 0.129, 0.106)
		tsb.set_corner_radius_all(4)
		tagp.add_theme_stylebox_override("panel", tsb)
		tagp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tagp)
		UI.label(root, "+" + str(int(it.get("plus", 0))), Vector2(88, 4), Vector2(28, 20), 12, Color(0.973, 0.886, 0.659), HORIZONTAL_ALIGNMENT_CENTER)
	return root

# ---------------- 底栏 / 提示 ----------------
func _on_dock(key: String) -> void:
	if not UI.navigation_available(self): return
	Audio.sfx("ui_click", -6.0)
	match key:
		"role":
			pass
		"god":
			UI.navigate(self, "res://menu/partner_home.tscn")
		"curio":
			UI.navigate(self, "res://menu/curio_home.tscn")
		"start":
			UI.navigate(self, "res://menu/main_home.tscn")

var _toast: Label = null
var _toast_seq := 0

func _show_toast(t: String) -> void:
	_toast_seq += 1
	var seq := _toast_seq
	if _toast != null and is_instance_valid(_toast):
		_toast.queue_free()
	var lb := UI.label(self, t, Vector2(0, 1120), Vector2(720, 44), 22, P.SEAL, HORIZONTAL_ALIGNMENT_CENTER)
	lb.z_index = 50
	_toast = lb
	await get_tree().create_timer(1.4).timeout
	if seq == _toast_seq and lb != null and is_instance_valid(lb):
		lb.queue_free()
		_toast = null
# ---------------- 槽位·入神流光 ----------------
class SlotTrance extends Control:
	var _t := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * 2.4)
		var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var pts := [
			r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)
		]
		for e in 4:
			draw_line(pts[e], pts[(e + 1) % 4], Color(1.0, 0.84, 0.46, 0.10 + 0.18 * pulse), 10.0, true)
		var n := 8
		var idx := 0
		for e in 4:
			var p0: Vector2 = pts[e]
			var p1: Vector2 = pts[(e + 1) % 4]
			for i in n:
				var u0 := float(i) / float(n)
				var u1 := float(i + 1) / float(n)
				var h := fmod(_t * 0.35 + float(idx) / 32.0, 1.0)
				draw_line(p0.lerp(p1, u0), p0.lerp(p1, u1), Color.from_hsv(h, 0.42, 1.0, 0.95), 3.0, true)
				idx += 1
