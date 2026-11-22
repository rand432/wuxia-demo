extends Control
# 局外请神图录、家传进阶与技能升级。

const AD := preload("res://kushou/ancestor_data.gd")
const GameState := preload("res://shared/game_state.gd")
const LevelState := preload("res://shared/level_state.gd")
const UI := preload("res://shared/ui_kit.gd")
# 每个技能自己的描述 + 伤害倍率（跟 battle_ui 的 SKILL_DEFS 保持一份数据）
const SKILL_DEFS := {
	"zl": {"name": "天雷道术", "dtype": "金系", "mul": 1.6, "cd": 10.0, "mp": 260.0, "targets": 3,
		"desc": "引下天雷，对 3 名敌人造成金系伤害"},
	"cuisanniang": {"name": "雾海龙王", "dtype": "召唤", "mul": 2.5, "cd": 60.0, "mp": 300.0, "targets": 1,
		"desc": "召出雾海龙王，对目标造成高额召唤伤害"},
	"jicanghai": {"name": "怒火焚身", "dtype": "火系", "mul": 1.3, "cd": 9.0, "mp": 0.0, "targets": 3,
		"desc": "怒火外放，对 3 名敌人造成火系伤害"},
	"chenshi": {"name": "刺骨", "dtype": "真实", "mul": 1.4, "cd": 8.0, "mp": 90.0, "targets": 1,
		"desc": "直刺骨髓，对单体造成真实伤害"},
	"liuqingqing": {"name": "回春", "dtype": "木系", "mul": 1.0, "heal_mul": 2.0, "cd": 12.0, "mp": 80.0, "targets": 1,
		"desc": "治疗自身；医毒家传解锁周围环毒"},
	"xiaoqier": {"name": "顺手", "dtype": "物理", "mul": 0.9, "cd": 5.0, "mp": 60.0, "targets": 1,
		"desc": "顺手一摸，对单体造成物理伤害"},
	"gundilong": {"name": "肉蛋冲撞", "dtype": "物理", "mul": 1.5, "cd": 6.0, "mp": 80.0, "targets": 1,
		"desc": "滚地冲撞，对单体造成物理伤害"},
	"qingluan": {"name": "青鸾飞刃", "dtype": "物理", "mul": 1.2, "cd": 8.0, "mp": 90.0, "targets": 1,
		"desc": "掷出飞刃，对直线敌人造成物理伤害"},
	"zhujue": {"name": "基础剑法", "dtype": "物理", "mul": 1.0, "cd": 0.0, "mp": 0.0, "targets": 1,
		"desc": "主角的基础剑法，对单体造成物理伤害"},
}

# 每级伤害成长：冷却越长、基础倍率越低的技能，单级成长可以高一点；高频技能低一点
const SKILL_LV_STEP := {
	"zl": 3, "cuisanniang": 5, "jicanghai": 3, "chenshi": 3, "liuqingqing": 3,
	"xiaoqier": 2, "gundilong": 2, "qingluan": 3, "zhujue": 2,
}

const P := UI.P
const FRAME := Color(0.45, 0.36, 0.24)
const GOLD := Color(0.85, 0.69, 0.42)
const TEXT := Color(0.96, 0.91, 0.81)
const MUTED := Color(0.77, 0.71, 0.61)
const CABINET := Color(0.123, 0.112, 0.096, 0.84)
const INSET := Color(0.105, 0.096, 0.083)
const PAPER := Color(0.89, 0.85, 0.74)
const BACKDROP := "res://assets/art/ui/partner_pavilion_v1.webp"

const PORTRAIT := {
	"zl": "res://assets/gen/qingshen/portrait_zl.jpg",
	"cuisanniang": "res://assets/gen/qingshen/portrait_cuisanniang.jpg",
	"jicanghai": "res://assets/gen/qingshen/portrait_jicanghai.jpg",
	"zhujue": "res://assets/gen/qingshen/portrait_zhujue.jpg",
	"chenshi": "res://assets/gen/qingshen/portrait_chenshi.jpg",
	"liuqingqing": "res://assets/gen/qingshen/portrait_liuqingqing_ink_v1.png",
	"xiaoqier": "res://assets/gen/qingshen/portrait_xiaoqier.jpg",
	"gundilong": "res://assets/gen/qingshen/portrait_gundilong.jpg",
	"qingluan": "res://assets/gen/qingshen/portrait_qingluan.jpg",
	"mingzhu": "res://assets/gen/qingshen/portrait_mingzhu.jpg",
	"zhiyuan": "res://assets/gen/qingshen/portrait_zhiyuan.jpg",
}

var _ids: Array[String] = []
var _sel := 0
var _stars := {}
var _cards: Array[GodArt] = []
var _skill_tiles: Array[Button] = []
var _skill_levels: Array[Label] = []
var _portraits := {}
var _skill_icons := {}
var _pop: Control = null

func _ready() -> void:
	GameState.ensure_loaded()
	LevelState.ensure_loaded()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for aid in LevelState.god_ids():
		_ids.append(str(aid))
	if not _ids.has("zhujue"):
		_ids.append("zhujue")
	for aid in _ids:
		_stars[aid] = clampi(int(GameState.stars.get(aid, 0)), 0, GameState.ROLE_STAR_MAX)
		_portraits[aid] = load(str(PORTRAIT.get(aid, "res://assets/char/player_full_cut.png"))) as Texture2D
	_build_backdrop()
	UI.app_bar(self, GameState.player_name, GameState.role_grade_cn(""), func(): UI.open_settings(self))
	_build_carousel()
	_build_slots()
	_build_hot()
	UI.dock(self, "god", _on_dock)

func _build_backdrop() -> void:
	var ground := ColorRect.new()
	ground.color = P.DARK
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	if ResourceLoader.exists(BACKDROP):
		var art := TextureRect.new()
		art.texture = load(BACKDROP) as Texture2D
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)

func _title(parent: Control, text: String, pos: Vector2, area: Vector2, font_size: int) -> Label:
	var label := UI.label(parent, text, pos, area, font_size, TEXT)
	label.add_theme_font_override("font", P.FONT)
	return label

func _build_carousel() -> void:
	var cabinet := UI.panel(self, Rect2(18, 106, 684, 682), Color(0.12, 0.104, 0.086, 0.55), 14, FRAME, 1)
	_title(cabinet, "请神", Vector2(18, 14), Vector2(220, 46), 34)
	UI.panel(cabinet, Rect2(18, 67, 648, 1), FRAME, 0)
	var boxes := [Rect2(34, 278, 130, 308), Rect2(174, 186, 372, 514), Rect2(556, 278, 130, 308)]
	for i in boxes.size():
		var box: Rect2 = boxes[i]
		var mount := Control.new()
		mount.position = box.position
		mount.size = box.size
		mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mount)
		var card := GodArt.new()
		card.size = box.size
		card.featured = i == 1
		card.pressed.connect(_on_card_click.bind(i))
		mount.add_child(card)
		_cards.append(card)
	UI.button(self, "进阶路线  ›", Rect2(228, 720, 264, 51), 21, Color(0.25, 0.19, 0.13), TEXT,
		_show_advance, GOLD, 1, 9)
	_refresh_carousel()

func _refresh_carousel(slide := 0) -> void:
	var count := _ids.size()
	var order := [posmod(_sel - 1, count), _sel, posmod(_sel + 1, count)]
	for i in _cards.size():
		var card := _cards[i]
		var visible_card := i == 1 or count > 1
		(card.get_parent() as Control).visible = visible_card
		if visible_card:
			_set_portrait(card, _ids[order[i]])
	if slide != 0:
		UI.Motion.pop(_cards[1].get_parent() as Control, false, 0.0, Vector2.INF, 0.018 * float(slide))
	_refresh_slots()

func _set_portrait(card: GodArt, aid: String) -> void:
	var role: Dictionary = AD.ANCESTORS[aid]
	card.god_name = str(role["name"])
	card.dtype = str(role.get("dtype", ""))
	card.quality = int(role["quality"])
	card.stars = int(_stars[aid])
	card.art = _portraits[aid] as Texture2D
	card.tooltip_text = card.god_name
	card.queue_redraw()

func _on_card_click(i: int) -> void:
	if i == 1:
		_show_advance()
	elif _ids.size() > 1:
		var direction := 1 if i == 2 else -1
		_sel = posmod(_sel + direction, _ids.size())
		_refresh_carousel(direction)

func _skill_icon(aid: String) -> Texture2D:
	if not _skill_icons.has(aid):
		var icon_path := "res://assets/gen/icons/skill_%s.png" % aid
		_skill_icons[aid] = load(icon_path if ResourceLoader.exists(icon_path) else str(AD.ANCESTORS[aid]["art"])) as Texture2D
	return _skill_icons[aid] as Texture2D

func _build_slots() -> void:
	var shelf_height := 361.0 if _ids.size() > 4 else 218.0
	var tile_width := 240.0 if _ids.size() == 1 else 151.0
	var book := UI.panel(self, Rect2(18, 800, 684, shelf_height), CABINET, 14, FRAME, 1)
	_title(book, "技能", Vector2(18, 9), Vector2(168, 43), 31)
	for i in _ids.size():
		var aid := _ids[i]
		var role: Dictionary = AD.ANCESTORS[aid]
		var row := floori(float(i) / 4.0)
		var cols := mini(4, _ids.size() - row * 4)
		var x := (684.0 - (cols * tile_width + (cols - 1) * 14.0)) * 0.5 + float(i % 4) * (tile_width + 14.0)
		var y := 60.0 + float(row) * 145.0
		var tile := UI.button(book, "", Rect2(x, y, tile_width, 133), 20, INSET, TEXT, _show_skill_detail.bind(i), FRAME, 1, 9)
		tile.tooltip_text = str(role["name"])
		_skill_tiles.append(tile)
		UI.panel(tile, Rect2(9, 8, tile_width - 18, 69), PAPER, 6)
		_add_icon(tile, _skill_icon(aid), Rect2((tile_width - 79.0) * 0.5, 8, 79, 69))
		UI.label(tile, str(role["skill"]), Vector2(5, 79), Vector2(tile_width - 10, 27), 17, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		var level := UI.label(tile, "", Vector2(5, 105), Vector2(tile_width - 10, 21), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_skill_levels.append(level)
	_refresh_slots()

func _refresh_slots() -> void:
	for i in _skill_tiles.size():
		var aid := _ids[i]
		var role: Dictionary = AD.ANCESTORS[aid]
		_skill_levels[i].text = "%s · Lv %d" % [role["name"], int(GameState.skill_lv.get(aid, 0))]
		var tile := _skill_tiles[i]
		var edge := GOLD if i == _sel else FRAME
		for state in ["normal", "hover", "pressed"]:
			var style := tile.get_theme_stylebox(state) as StyleBoxFlat
			style.border_color = edge
			style.set_border_width_all(2 if i == _sel else 1)

func _add_icon(parent: Control, texture: Texture2D, rect: Rect2) -> void:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.position = rect.position
	tr.size = rect.size
	tr.texture = texture
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)

func _open_panel(rect: Rect2, panel_name: String) -> Panel:
	_close_pop()
	var popup := Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 80
	add_child(popup)
	_pop = popup
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.021, 0.017, 0.76)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_pop(popup))
	popup.add_child(dim)
	var panel := UI.panel(popup, rect, Color(0.153, 0.126, 0.099), 15, GOLD, 2)
	panel.name = panel_name
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel

func _close_button(panel: Panel, popup: Control) -> void:
	UI.button(panel, "×", Rect2(panel.size.x - 62, 18, 44, 42), 26, INSET, TEXT,
		_close_pop.bind(popup), FRAME, 1, 8)

func _action(parent: Control, text: String, rect: Rect2, callback: Callable) -> Button:
	var button := UI.button(parent, text, rect, 22, Color(0.36, 0.25, 0.14), TEXT, callback, GOLD, 1, 9)
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = INSET
	disabled.border_color = FRAME
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(9)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button

func _show_skill_detail(i: int) -> void:
	if i < 0 or i >= _ids.size():
		return
	if _sel != i:
		_sel = i
		_refresh_carousel()
	var aid := _ids[i]
	var role: Dictionary = AD.ANCESTORS[aid]
	var panel := _open_panel(Rect2(74, 314, 572, 550), "SkillPanel")
	var popup := _pop
	var header := UI.panel(panel, Rect2(14, 14, 544, 144), INSET, 11, FRAME, 1)
	UI.panel(header, Rect2(14, 16, 112, 112), PAPER, 8)
	_add_icon(header, _skill_icon(aid), Rect2(22, 22, 96, 100))
	UI.label(header, "技能详情", Vector2(146, 13), Vector2(247, 27), 16, GOLD)
	_title(header, str(role["skill"]), Vector2(146, 43), Vector2(334, 51), 38)
	var lv_now := int(GameState.skill_lv.get(aid, 0))
	UI.label(header, "%s · %s · Lv %d" % [role["name"], role.get("dtype", ""), lv_now],
		Vector2(146, 99), Vector2(370, 30), 17, MUTED)
	var sk: Dictionary = SKILL_DEFS.get(aid, {})
	var base_pct := int(round(float(sk.get("heal_mul", sk.get("mul", 1.0))) * 100.0))
	var desc := str(sk.get("desc", ""))
	if desc.is_empty():
		desc = "对 %d 名敌人造成 %s 伤害" % [int(sk.get("targets", 1)), str(sk.get("dtype", role.get("dtype", "")))]
	UI.label(panel, desc, Vector2(32, 175), Vector2(508, 42), 19, TEXT)
	var growth := float(int(SKILL_LV_STEP.get(aid, 3))) / 100.0
	var current := float(base_pct) * (1.0 + float(lv_now) * growth)
	var next := float(base_pct) * (1.0 + float(lv_now + 1) * growth)
	var effect := "治疗 · 攻击" if sk.has("heal_mul") else "伤害 · " + str(sk.get("dtype", role.get("dtype", "")))
	var strip := UI.panel(panel, Rect2(30, 229, 512, 60), INSET, 8, FRAME, 1)
	UI.label(strip, effect, Vector2(16, 0), Vector2(173, 60), 17, GOLD)
	UI.label(strip, "%.1f%%  →  %.1f%%" % [current, next], Vector2(183, 0), Vector2(309, 60), 23,
		TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	# 技能书沿用存档的五种品级名称。
	var book_grade: String = ["凡品", "良品", "玄品", "地品", "天品"][clampi(int(role["quality"]) - 1, 0, 4)]
	var cost := 200
	var coin := UI.label(panel, "", Vector2(32, 317), Vector2(508, 32), 19, TEXT)
	var book := UI.label(panel, "", Vector2(32, 364), Vector2(508, 32), 19, TEXT)
	var refresh_cost := func() -> void:
		var wen := GameState.coin("wen")
		var stock := int(GameState.skill_books.get(book_grade, 0))
		coin.text = "文钱 %d / %d" % [wen, cost]
		book.text = "%s技能书 %d / 1" % [book_grade, stock]
		coin.add_theme_color_override("font_color", GOLD if wen < cost else TEXT)
		book.add_theme_color_override("font_color", GOLD if stock < 1 else TEXT)
	refresh_cost.call()
	var up := _action(panel, "升级", Rect2(32, 459, 508, 58), Callable())
	up.pressed.connect(func() -> void:
		if not _popup_current(popup) or up.disabled:
			return
		if int(GameState.skill_books.get(book_grade, 0)) < 1 or GameState.coin("wen") < cost:
			refresh_cost.call()
			up.text = "升级 · 材料不足"
			return
		up.disabled = true
		if not GameState.upgrade_skill(aid, book_grade, cost):
			up.disabled = false
			up.text = "升级 · 保存失败"
			return
		_refresh_slots()
		_show_skill_detail(i))
	_close_button(panel, popup)
	UI.Motion.present(popup, panel)

func _show_advance() -> void:
	var aid := _ids[_sel]
	var role: Dictionary = AD.ANCESTORS[aid]
	var star := int(_stars[aid])
	var panel := _open_panel(Rect2(38, 107, 644, 1059), "AdvancePanel")
	var popup := _pop
	var hero := UI.panel(panel, Rect2(14, 14, 616, 289), INSET, 11, FRAME, 1)
	var portrait := GodArt.new()
	portrait.art_only = true
	portrait.position = Vector2(305, 0)
	portrait.size = Vector2(311, 289)
	hero.add_child(portrait)
	_set_portrait(portrait, aid)
	UI.label(hero, "进阶路线", Vector2(19, 20), Vector2(263, 35), 19, GOLD)
	_title(hero, str(role["name"]), Vector2(17, 59), Vector2(273, 70), 48)
	UI.label(hero, "%s · %s" % [grade_cn(int(role["quality"])), str(role.get("dtype", ""))],
		Vector2(20, 138), Vector2(262, 31), 20, MUTED)
	UI.label(hero, "%d / %d 星" % [star, GameState.ROLE_STAR_MAX],
		Vector2(20, 179), Vector2(262, 35), 23, GOLD)
	UI.label(hero, "技能 · %s" % str(role["skill"]), Vector2(20, 232), Vector2(262, 33), 18, TEXT)
	_close_button(panel, popup)
	_title(panel, "家传卡", Vector2(29, 320), Vector2(149, 41), 28)
	UI.label(panel, "每升 1 星开启下一档 · 局内每档集齐 3 张成组",
		Vector2(158, 321), Vector2(448, 39), 16, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var tiers: Array = role["tiers"]
	for i in tiers.size():
		_build_tier(panel, tiers[i], i, star)
	var footer := UI.panel(panel, Rect2(14, 872, 616, 169), INSET, 10, FRAME, 1)
	var shard := int(GameState.shards.get(aid, 0))
	var wen := GameState.coin("wen")
	var full := star >= GameState.ROLE_STAR_MAX
	if not full:
		UI.label(footer, "碎片 %d / %d" % [shard, GameState.ROLE_ADVANCE_SHARDS],
			Vector2(20, 23), Vector2(270, 33), 21, GOLD if shard < GameState.ROLE_ADVANCE_SHARDS else TEXT)
		UI.label(footer, "文钱 %d / %d" % [wen, GameState.ROLE_ADVANCE_WEN],
			Vector2(306, 23), Vector2(290, 33), 21, GOLD if wen < GameState.ROLE_ADVANCE_WEN else TEXT,
			HORIZONTAL_ALIGNMENT_RIGHT)
	var action_rect := Rect2(20, 55 if full else 83, 576, 59)
	var up := _action(footer, "已满星" if full else "进阶", action_rect, Callable())
	up.disabled = not GameState.can_advance_role(aid, star)
	up.pressed.connect(func() -> void:
		if not _popup_current(popup) or up.disabled:
			return
		up.disabled = true
		if not GameState.advance_role(aid, star):
			up.disabled = not GameState.can_advance_role(aid, star)
			up.text = "进阶未完成，请检查资源或存储空间"
			return
		_stars[aid] = int(GameState.stars[aid])
		_refresh_carousel()
		_show_advance())
	UI.Motion.present(popup, panel)

func _build_tier(panel: Panel, tier: Dictionary, index: int, star: int) -> void:
	var current := index == star
	var unlocked := index <= star
	var color := TEXT if unlocked else MUTED
	var row := UI.panel(panel, Rect2(28, 378.0 + float(index) * 79.0, 588, 69),
		Color(0.244, 0.181, 0.119) if current else INSET, 8, GOLD if current else FRAME, 1)
	UI.label(row, "%d 星" % index, Vector2(8, 0), Vector2(65, 69), 20, GOLD if unlocked else MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(row, "%s · %s" % [AD.TIER_NAMES[index], str(tier["combo_name"])],
		Vector2(81, 4), Vector2(390, 29), 19, color)
	UI.label(row, str(tier["combo_text"]), Vector2(81, 34), Vector2(390, 29), 16, color)
	UI.label(row, "已解锁" if unlocked else "需 %d 星" % index,
		Vector2(474, 0), Vector2(97, 69), 15, GOLD if unlocked else MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

func _popup_current(popup: Control) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(popup) and _pop == popup and not popup.is_queued_for_deletion()

func _close_pop(expected: Control = null) -> void:
	if expected != null and not _popup_current(expected):
		return
	if is_instance_valid(_pop):
		_pop.hide()
		_pop.queue_free()
	_pop = null

func grade_cn(q: int) -> String:
	return ["凡品", "良品", "玄品", "地品", "绝品"][clampi(q - 1, 0, 4)]

func _build_hot() -> void:
	var back := Button.new()
	back.position = Vector2(10, 6)
	back.size = Vector2(240, 76)
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		back.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	back.pressed.connect(func(): UI.navigate(self, "res://menu/main_home.tscn"))
	add_child(back)
	UI.Motion.bind_button(back)

func _on_dock(key: String) -> void:
	if not UI.navigation_available(self):
		return
	match key:
		"start":
			UI.navigate(self, "res://menu/main_home.tscn")
		"role":
			UI.navigate(self, "res://menu/character_home.tscn")
		"curio":
			UI.navigate(self, "res://menu/curio_home.tscn")

class GodArt extends Button:
	var god_name := ""
	var dtype := ""
	var quality := 5
	var stars := 0
	var featured := false
	var art_only := false
	var art: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE if art_only else Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		var blank := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, blank)
		if not art_only:
			UI.Motion.bind_button(self)
			mouse_entered.connect(queue_redraw)
			mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var hue := P.quality(quality)
		var rim := hue.lerp(GOLD, 0.69 if featured else 0.40)
		if is_hovered():
			rim = rim.lightened(0.18)
		var frame := StyleBoxFlat.new()
		frame.bg_color = INSET
		frame.set_corner_radius_all(10)
		frame.border_color = rim
		frame.set_border_width_all(2)
		frame.shadow_color = Color(0.025, 0.021, 0.017, 0.8)
		frame.shadow_size = 8 if featured else 3
		frame.shadow_offset = Vector2(0, 4)
		draw_style_box(frame, Rect2(Vector2.ZERO, size))
		var inset := 5.0
		var image := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
		if art != null:
			var asset_size := art.get_size()
			var source_size := image.size / maxf(image.size.x / asset_size.x, image.size.y / asset_size.y)
			var anchor := Vector2(0.5, 0.24 if art_only else 0.32)
			draw_texture_rect_region(art, image, Rect2((asset_size - source_size) * anchor, source_size))
			if not featured and not art_only:
				draw_rect(image, Color(0.071, 0.063, 0.054, 0.24))
		var foot := size.y - (146.0 if featured else (58.0 if art_only else 90.0))
		var dark := Color(0.075, 0.072, 0.066, 0.98)
		draw_polygon(PackedVector2Array([Vector2(inset, foot), Vector2(size.x - inset, foot),
			image.end, Vector2(inset, image.end.y)]),
			PackedColorArray([Color(dark, 0.0), Color(dark, 0.0), dark, dark]))
		draw_rect(image, Color(rim, 0.68), false, 1.0)
		if art_only:
			return
		if featured:
			var seal := StyleBoxFlat.new()
			seal.bg_color = Color(hue.darkened(0.30), 0.96)
			seal.set_corner_radius_all(5)
			seal.border_color = rim
			seal.set_border_width_all(1)
			draw_style_box(seal, Rect2(14, 15, 58, 30))
			var grade: String = ["凡品", "良品", "玄品", "地品", "绝品"][clampi(quality - 1, 0, 4)]
			draw_string(P.FONT, Vector2(14, 36), grade, HORIZONTAL_ALIGNMENT_CENTER, 58, 16, TEXT)
			draw_string(P.FONT, Vector2(20, size.y - 48), god_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 154, 38, TEXT)
			draw_string(P.FONT, Vector2(size.x - 122, size.y - 47), dtype, HORIZONTAL_ALIGNMENT_RIGHT, 100, 22, TEXT)
			draw_line(Vector2(18, size.y - 39), Vector2(size.x - 18, size.y - 39), Color(GOLD, 0.45), 1.0, true)
			for i in GameState.ROLE_STAR_MAX:
				_star(Vector2(size.x * 0.5 - 52.0 + float(i) * 26.0, size.y - 21.0), i < stars)
		else:
			draw_string(P.FONT, Vector2(7, size.y - 24), god_name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 14, 19, TEXT)

	func _star(center: Vector2, filled: bool) -> void:
		var points := PackedVector2Array()
		for i in 10:
			var angle := -PI * 0.5 + float(i) * PI / 5.0
			points.append(center + Vector2.from_angle(angle) * (8.0 if i % 2 == 0 else 3.5))
		if filled:
			draw_colored_polygon(points, GOLD)
		else:
			points.append(points[0])
			draw_polyline(points, Color(GOLD, 0.68), 1.0, true)
