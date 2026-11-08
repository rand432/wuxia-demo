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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_all()

func _build_all() -> void:
	theme = UI.theme()
	_bag_roots.clear()
	_cats.clear()
	UI.bg(self)
	UI.app_bar(self, GameState.player_name, "玄品", func() -> void: UI.open_settings(self))
	UI.page_head(self, "角 色", func() -> void:
		get_tree().change_scene_to_file("res://menu/main_home.tscn"))
	_build_figure()
	_build_attr()
	_build_bag()
	UI.dock(self, "role", _on_dock)

func _rebuild() -> void:
	await get_tree().process_frame
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build_all()

# ---------------- 立绘 + 四槽 ----------------
func _build_figure() -> void:
	var tex := CharArt.full("player")
	if tex != null:
		var clip := Control.new()
		clip.position = Vector2(196, 158)
		clip.size = Vector2(328, 480)
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(clip)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(tr)
		tr.position = Vector2.ZERO
		tr.size = clip.size
	for s in SLOTS:
		_build_slot(str(s["key"]), s["rect"])

func _build_slot(key: String, rect: Rect2) -> void:
	var root := Control.new()
	root.position = rect.position
	root.size = rect.size
	add_child(root)
	var it: Dictionary = FD.equipped.get(key, {})
	var filled := not it.is_empty()
	var qcol: Color = P.quality(int(it.get("quality", 1))) if filled else Color(0.745, 0.667, 0.643)
	var pan := Panel.new()
	pan.position = Vector2.ZERO
	pan.size = rect.size
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
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.position = Vector2.ZERO
	hit.size = rect.size
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hit.pressed.connect(func() -> void: _on_slot(key))
	root.add_child(hit)

func _on_slot(key: String) -> void:
	Audio.sfx("ui_click", -8.0)
	var it: Dictionary = FD.equipped.get(key, {})
	if it.is_empty():
		_show_toast("该部位还没有装备")
		return
	var dlg: Control = (load("res://menu/equip_detail.tscn") as PackedScene).instantiate()
	add_child(dlg)
	dlg.forge_requested.connect(_open_forge)
	dlg.closed.connect(_rebuild)
	dlg.open(key)

func _open_forge(key: String) -> Node:
	var fs: Control = (load("res://menu/forge_sheet.tscn") as PackedScene).instantiate()
	add_child(fs)
	fs.closed.connect(_rebuild)
	fs.open(key)
	return fs

# ---------------- 属性 ----------------
func _build_attr() -> void:
	UI.label(self, "属 性", Vector2(24, 648), Vector2(120, 32), 22, P.DIM)
	var t := FD.totals()
	var rows := [
		["攻 击", str(int(t["atk"])), "气 血", str(int(t["hp"])), "防 御", str(int(t["def"]))],
		["速 度", str(int(t["spd"])), "暴 击", "15%", "闪 避", "5%"],
	]
	for r in rows.size():
		var y := 690.0 + float(r) * 44.0
		for c in 3:
			var x := 24.0 + float(c) * 224.0
			UI.label(self, str(rows[r][c * 2]), Vector2(x, y), Vector2(96, 32), 20, P.INK)
			UI.label(self, str(rows[r][c * 2 + 1]), Vector2(x + 100, y), Vector2(80, 32), 20, P.INK)

# ---------------- 背包 ----------------
func _build_bag() -> void:
	UI.label(self, "背 包   3 / 40", Vector2(24, 776), Vector2(240, 32), 22, P.DIM)
	for i in 10:
		var r := i / 5
		var c := i % 5
		var rect := Rect2(24.0 + float(c) * 132.0, 812.0 + float(r) * 108.0, 120, 96)
		var pan := Panel.new()
		pan.position = rect.position
		pan.size = rect.size
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.988, 0.976, 0.949)
		sb.set_corner_radius_all(8)
		sb.border_color = Color(0.804, 0.745, 0.647)
		sb.set_border_width_all(1)
		pan.add_theme_stylebox_override("panel", sb)
		add_child(pan)
		_bag_roots.append(pan)
	_fill_bag()
	for i in CATS.size():
		var b := Button.new()
		b.text = CATS[i]
		b.position = Vector2(24.0 + float(i) * 172.0, 1046)
		b.size = Vector2(156, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func() -> void:
			_cat = i
			Audio.sfx("ui_click", -8.0)
			_style_cats())
		add_child(b)
		_cats.append(b)
	_style_cats()
	var all := Button.new()
	all.text = "背包全览 ›"
	all.position = Vector2(516, 1108)
	all.size = Vector2(180, 40)
	all.flat = true
	all.focus_mode = Control.FOCUS_NONE
	all.add_theme_font_size_override("font_size", 21)
	all.add_theme_color_override("font_color", P.SEAL)
	for st in ["normal", "hover", "pressed"]:
		all.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	all.pressed.connect(func() -> void: _show_toast("背包全览（下一步接）"))
	add_child(all)

func _style_cats() -> void:
	for i in _cats.size():
		var b: Button = _cats[i]
		var on := i == _cat
		var sb := StyleBoxFlat.new()
		sb.bg_color = P.SEAL if on else P.PAPER_HI
		sb.set_corner_radius_all(26)
		sb.border_color = P.GOLD if on else Color(0.784, 0.737, 0.659)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(0.980, 0.929, 0.839) if on else P.DIM)

func _fill_bag() -> void:
	for i in FD.bag.size():
		if i >= _bag_roots.size():
			break
		var it: Dictionary = FD.bag[i]
		var root: Panel = _bag_roots[i]
		var q := int(it.get("quality", 1))
		var sb := root.get_theme_stylebox("panel") as StyleBoxFlat
		sb.border_color = P.quality(q)
		sb.set_border_width_all(2)
		var slot := str(it.get("slot", "weapon"))
		var art: String = str(FD.SLOT_ART.get(slot, ""))
		if art != "" and ResourceLoader.exists(art):
			var tr := TextureRect.new()
			tr.texture = load(art)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(tr)
			tr.position = Vector2(32, 4)
			tr.size = Vector2(56, 56)
		var tagp := Panel.new()
		tagp.position = Vector2(84, 4)
		tagp.size = Vector2(28, 20)
		var tsb2 := StyleBoxFlat.new()
		tsb2.bg_color = Color(0.149, 0.129, 0.106)
		tsb2.set_corner_radius_all(4)
		tagp.add_theme_stylebox_override("panel", tsb2)
		tagp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tagp)
		UI.label(root, "+" + str(int(it.get("plus", 0))), Vector2(84, 4), Vector2(28, 20), 12, Color(0.973, 0.886, 0.659), HORIZONTAL_ALIGNMENT_CENTER)

# ---------------- 底栏 / 提示 ----------------
func _on_dock(key: String) -> void:
	Audio.sfx("ui_click", -6.0)
	match key:
		"role":
			pass
		"god":
			get_tree().change_scene_to_file("res://menu/partner_home.tscn")
		"start":
			get_tree().change_scene_to_file("res://kushou/battle_ui.tscn")

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
