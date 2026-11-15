extends Control
# 装备详情：名字 + 强化数 / 品质边框 / 属性 / 换装对比 / 卖出·锻造·卸下
signal closed
signal forge_requested(slot_key: String)

const UI := preload("res://shared/ui_kit.gd")
const P := preload("res://shared/ui_pal.gd")
const FD := preload("res://shared/forge_data.gd")
const Audio := preload("res://shared/audio.gd")

var slot_key := "weapon"
var _root: Control = null

func open(key: String) -> void:
	slot_key = key
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.078, 0.067, 0.055, 0.46)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close())
	add_child(dim)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build()

func _build() -> void:
	var it: Dictionary = FD.equipped.get(slot_key, {})
	if it.is_empty():
		_close()
		return
	var q := int(it.get("quality", 1))
	UI.panel(_root, Rect2(45, 340, 630, 600), Color(0.965, 0.941, 0.894), 10, P.LINE, 2)
	# 插画 + 品质边框
	UI.panel(_root, Rect2(72, 372, 220, 300), Color(0.980, 0.965, 0.933), 2, P.quality(q), 3)
	var art: String = str(FD.SLOT_ART.get(slot_key, "res://assets/items/it_sword.png"))
	if ResourceLoader.exists(art):
		var tr := TextureRect.new()
		tr.texture = load(art)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(tr)
		tr.position = Vector2(92, 402)
		tr.size = Vector2(180, 240)
	UI.label(_root, str(it.get("name", "装备")) + " +" + str(int(it.get("plus", 0))),
		Vector2(316, 372), Vector2(340, 44), 30, P.INK)
	UI.label(_root, FD.qname(q) + " · 第 " + str(FD.grade_of(int(it.get("plus", 0)))) + " 阶",
		Vector2(316, 418), Vector2(340, 28), 17, P.DIM)
	var stat_map := {"weapon": "攻 击", "armor": "防 御", "jade": "气 血", "cloak": "速 度"}
	var stat_name: String = str(stat_map.get(slot_key, "攻 击"))
	UI.label(_root, str(stat_name), Vector2(316, 458), Vector2(160, 32), 20, P.INK)
	UI.label(_root, "+" + str(int(FD.stat_of(it, slot_key))), Vector2(560, 458), Vector2(88, 32), 21, P.RED, HORIZONTAL_ALIGNMENT_RIGHT)
	UI.label(_root, "特 性", Vector2(316, 500), Vector2(160, 32), 20, P.INK)
	var tr_name := str(it.get("trait", ""))
	UI.label(_root, tr_name if tr_name != "" else "无", Vector2(430, 500), Vector2(218, 32), 20,
		P.SEAL if tr_name != "" else Color(0.62, 0.58, 0.54), HORIZONTAL_ALIGNMENT_RIGHT)
	UI.label(_root, "上限 +" + str(FD.cap(q)), Vector2(316, 542), Vector2(160, 28), 18, P.DIM)
	# 按钮
	var y := 846.0
	UI.button(_root, "卖 出", Rect2(92, y, 150, 62), 22, Color(0.22, 0.18, 0.14), Color(0.94, 0.91, 0.85),
		func() -> void: _sell(), Color(0.47, 0.40, 0.31), 1, 8)
	UI.button(_root, "锻 造", Rect2(266, y, 190, 62), 24, Color(0.902, 0.698, 0.259), Color(0.188, 0.125, 0.047),
		func() -> void: _forge(), Color(0.588, 0.412, 0.102), 2, 8)
	UI.button(_root, "收 起", Rect2(480, y, 168, 62), 22, Color(0.22, 0.18, 0.14), Color(0.94, 0.91, 0.85),
		func() -> void: _close(), Color(0.47, 0.40, 0.31), 1, 8)

func _forge() -> void:
	Audio.sfx("ui_click", -6.0)
	forge_requested.emit(slot_key)
	_close()

func _sell() -> void:
	if not FD.sell_equipped(slot_key):
		return
	Audio.sfx("ui_click", -6.0)
	Audio.sfx("coin", -10.0)
	_close()

func _close() -> void:
	closed.emit()
	queue_free()