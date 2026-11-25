extends Control
# 锻造面板：装备行 / 铁砧 / 入神槽 / 五结果 / 道具 / 花费 / 锤与收
signal closed

const UI := preload("res://shared/ui_kit.gd")
const P := preload("res://shared/ui_pal.gd")
const FD := preload("res://shared/forge_data.gd")
const Audio := preload("res://shared/audio.gd")
const STRIKE_TONES := {"大": Color(1.0, 0.79, 0.31), "成": Color(0.85, 0.97, 0.68),
	"维": Color(0.92, 0.70, 0.40), "损": Color(1.0, 0.47, 0.26), "破": Color(0.97, 0.32, 0.23)}

var slot_key := "weapon"
var _panel: Control = null
var _name_lb: Label = null
var _crack_lb: Label = null
var _gauge: GaugeArt = null
var _gauge_lb: Label = null
var _odds: OddsArt = null
var _anvil: AnvilArt = null
var _hammer_btn: Button = null
var _ores_lb: Label = null
var _item_lbs: Array = []
var _chip: Control = null
var _toast: Label = null
var _toast_seq := 0
var _done := false
var _closed := false

func open(key: String) -> void:
	FD.load_game()
	slot_key = key
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.078, 0.067, 0.055, 0.50)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	_build()
	_refresh()
	UI.Motion.present(self, _panel)

func _it() -> Dictionary:
	return FD.equipped.get(slot_key, {})

func _build() -> void:
	UI.panel(_panel, Rect2(16, 96, 688, 1144), Color(0.965, 0.941, 0.894), 10, P.LINE, 2)
	UI.label(_panel, "锻 造", Vector2(56, 126), Vector2(200, 52), 36, P.INK)
	UI.button(_panel, "×", Rect2(628, 128, 48, 48), 26, Color(0, 0, 0, 0), P.DIM,
		func() -> void: _close(), P.LINE, 1, 8)
	# 装备行
	var it0 := _it()
	var q0 := int(it0.get("quality", 1))
	UI.panel(_panel, Rect2(56, 214, 96, 96), Color(0.988, 0.976, 0.949), 10, P.quality(q0), 3)
	var art0: String = str(FD.SLOT_ART.get(slot_key, "res://assets/items/it_sword.png"))
	if ResourceLoader.exists(art0):
		var tr0 := TextureRect.new()
		tr0.texture = load(art0)
		tr0.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr0.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr0.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(tr0)
		tr0.position = Vector2(66, 222)
		tr0.size = Vector2(76, 80)
	_anvil = AnvilArt.new()
	_anvil.item_art = load(art0) as Texture2D if ResourceLoader.exists(art0) else null
	_anvil.as_weapon = slot_key == "weapon"
	UI.panel(_panel, Rect2(40, 326, 640, 314), Color(0.22, 0.181, 0.139), 15, Color(0.63, 0.48, 0.29), 2)
	_anvil.position = Vector2(40, 330)
	_anvil.size = Vector2(640, 320)
	_anvil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_anvil)
	_name_lb = UI.label(_panel, "", Vector2(176, 224), Vector2(420, 44), 34, P.INK)
	_crack_lb = UI.label(_panel, "", Vector2(176, 274), Vector2(420, 30), 20, P.DIM)
	# 入神槽
	UI.label(_panel, "入 神", Vector2(56, 664), Vector2(120, 34), 22, P.DIM)
	_gauge_lb = UI.label(_panel, "", Vector2(520, 664), Vector2(140, 34), 22, P.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_gauge = GaugeArt.new()
	_gauge.position = Vector2(56, 706)
	_gauge.size = Vector2(608, 44)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_gauge)
	# 五结果
	_odds = OddsArt.new()
	_odds.position = Vector2(56, 786)
	_odds.size = Vector2(608, 72)
	_odds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_odds)
	# 道具
	UI.label(_panel, "锻 炉 道 具", Vector2(56, 886), Vector2(220, 34), 22, P.DIM)
	for i in FD.ITEM_KEYS.size():
		var nm := str(FD.ITEM_KEYS[i])
		var x := 56.0 + float(i) * 150.0
		var hit := UI.button(_panel, "", Rect2(x, 930, 132, 128), 17, Color(0.957, 0.933, 0.886), P.INK,
			_open_item.bind(nm), Color(0.68, 0.58, 0.43), 1, 10)
		hit.name = "Material_%d" % i
		hit.tooltip_text = nm
		var art: String = str(FD.ITEM_ICON.get(nm, ""))
		if art != "" and ResourceLoader.exists(art):
			var tr := TextureRect.new()
			tr.texture = load(art)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hit.add_child(tr)
			tr.position = Vector2(32, 5)
			tr.size = Vector2(68, 64)
		UI.label(hit, nm, Vector2(0, 74), Vector2(132, 26), 17, P.INK, HORIZONTAL_ALIGNMENT_CENTER)
		var cnt := UI.label(hit, "×0", Vector2(0, 98), Vector2(132, 23), 16, P.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_item_lbs.append(cnt)
	# 花费 + 按钮
	_ores_lb = UI.label(_panel, "", Vector2(56, 1086), Vector2(360, 34), 22, P.INK)
	_hammer_btn = UI.button(_panel, "锤 一 下", Rect2(56, 1130, 414, 78), 32, P.SEAL, Color(0.988, 0.941, 0.839),
		func() -> void: _hammer(), P.GOLD, 3, 12)
	_hammer_btn.button_down.connect(func() -> void:
		if not _closed and is_instance_valid(_anvil): _anvil.set_raised(true))
	_hammer_btn.button_up.connect(func() -> void:
		if is_instance_valid(_anvil): _anvil.set_raised(false))
	UI.button(_panel, "收 下", Rect2(494, 1130, 170, 74), 26, Color(0.22, 0.18, 0.14), Color(0.94, 0.91, 0.85),
		func() -> void:
			if _closed or not is_inside_tree() or is_queued_for_deletion(): return
			Audio.sfx("ui_close", -10.0)
			FD.save_game()
			_close(), Color(0.47, 0.40, 0.31), 1, 12)

func _refresh() -> void:
	if _closed or not is_inside_tree() or is_queued_for_deletion():
		return
	var it := _it()
	if it.is_empty():
		_close()
		return
	var st := FD.st_of(slot_key)
	var q := int(it.get("quality", 1))
	_name_lb.text = str(it.get("name", "装备")) + " +" + str(int(it.get("plus", 0)))
	_crack_lb.text = "裂纹 " + str(int(st.get("crack", 0))) + "　·　" + FD.qname(q)
	_gauge.crack = int(st.get("crack", 0))
	_gauge.count = int(st.get("gauge", 0))
	_gauge.trance = int(st.get("trance", 0))
	_gauge.queue_redraw()
	_gauge_lb.text = (str(int(st.get("trance", 0))) + " 锤") if int(st.get("trance", 0)) > 0 else (str(int(st.get("gauge", 0))) + " / 10")
	_odds.w = FD.odds(st, str(it.get("trait", "")))
	_odds.queue_redraw()
	_anvil.trance = int(st.get("trance", 0)) > 0
	_anvil.queue_redraw()
	_ores_lb.text = "锻造石 ×" + str(FD.COST_ORE) + "　　银两 " + str(FD.COST_SILVER)
	for i in _item_lbs.size():
		var nm := str(FD.ITEM_KEYS[i])
		var n := int(FD.items.get(nm, 0))
		(_item_lbs[i] as Label).text = "×" + str(n)
		(_item_lbs[i] as Label).add_theme_color_override("font_color", P.DIM if n > 0 else Color(0.72, 0.69, 0.65))
	var capped := int(it.get("plus", 0)) >= FD.cap(q)
	if capped:
		_ores_lb.text = "已到%s强化上限 +%d" % [FD.qname(q), FD.cap(q)]
	_hammer_btn.text = "已 满" if capped else "锤 一 下"
	_hammer_btn.disabled = capped
	_hammer_btn.modulate = Color(0.82, 0.80, 0.76) if capped else Color(1, 1, 1)
	_chip_refresh(st)

func _chip_refresh(st: Dictionary) -> void:
	if _chip != null and is_instance_valid(_chip):
		_chip.queue_free()
		_chip = null
	var n := int(st.get("protect", 0))
	if n <= 0:
		return
	var c := UI.panel(_panel, Rect2(470, 218, 194, 40), Color(0.941, 0.886, 0.769), 20, P.GOLD, 1)
	UI.label(c, "龙鳞 · 保护 " + str(n) + " 锤", Vector2(0, 0), Vector2(194, 40), 17, Color(0.376, 0.290, 0.157), HORIZONTAL_ALIGNMENT_CENTER)
	_chip = c

# ---------------- 锤 ----------------
func _hammer() -> void:
	if _closed or _done or not is_inside_tree() or is_queued_for_deletion():
		return
	var transaction := FD.hammer(slot_key)
	if not bool(transaction["ok"]):
		_anvil.set_raised(false)
		UI.Motion.reject_button(_hammer_btn)
		_show_toast(str(transaction["reason"]))
		return
	var res := str(transaction["result"])
	var out: Dictionary = transaction["outcome"]
	Audio.sfx("forge_hammer", -8.0)
	var tone: Color = STRIKE_TONES[res]
	if bool(out["blocked"]):
		tone = Color(0.58, 0.93, 0.83)
	elif bool(out["trance"]):
		tone = STRIKE_TONES["大"]
	_anvil.strike(tone)
	match res:
		"大":
			_show_toast("大 成 功 ！  +2")
			Audio.sfx("ult_ready", -10.0)
		"成":
			_show_toast("成 功  +1")
			Audio.sfx("equip", -12.0, 1.12)
		"维":
			_show_toast("维 持")
		"损":
			_show_toast("损 伤  −1　裂纹 +1")
			Audio.sfx("wood_down", -12.0)
		"破":
			if bool(out["blocked"]):
				_show_toast("龙鳞挡下了破碎")
				Audio.sfx("arrow_block", -8.0)
			else:
				_on_broken()
				return
	if bool(out["trance"]):
		Audio.sfx("enlighten", -4.0)
		_show_toast("入 神")
	_refresh()

func _on_broken() -> void:
	Audio.sfx("sword_in_ground", -6.0)
	Audio.sfx("fall_down", -10.0)
	_done = true
	for c in _panel.get_children():
		c.queue_free()
	_anvil = null
	UI.panel(_panel, Rect2(16, 96, 688, 1144), Color(0.965, 0.941, 0.894), 10, P.LINE, 2)
	UI.label(_panel, "锻 造", Vector2(56, 126), Vector2(200, 52), 36, P.INK)
	var anvil := AnvilArt.new()
	anvil.position = Vector2(40, 380)
	anvil.size = Vector2(640, 320)
	anvil.empty = true
	anvil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(anvil)
	anvil.strike(STRIKE_TONES["破"])
	UI.label(_panel, "砧 上 无 物", Vector2(0, 330), Vector2(720, 40), 26, Color(0.588, 0.541, 0.471), HORIZONTAL_ALIGNMENT_CENTER)
	UI.button(_panel, "关 闭", Rect2(240, 1100, 240, 78), 26, Color(0.22, 0.18, 0.14), Color(0.94, 0.91, 0.85),
		func() -> void: _close(), Color(0.47, 0.40, 0.31), 1, 12)

func _show_toast(t: String) -> void:
	_toast_seq += 1
	var seq := _toast_seq
	if _toast != null and is_instance_valid(_toast):
		_toast.queue_free()
	var lb := UI.label(self, t, Vector2(0, 620), Vector2(720, 52), 26, P.SEAL, HORIZONTAL_ALIGNMENT_CENTER)
	lb.z_index = 60
	_toast = lb
	await get_tree().create_timer(1.1).timeout
	if seq == _toast_seq and lb != null and is_instance_valid(lb):
		lb.queue_free()
		_toast = null

# ---------------- 道具 ----------------
func _open_item(nm: String) -> void:
	if _closed or _done or not is_inside_tree() or is_queued_for_deletion():
		return
	if _done:
		return
	Audio.sfx("ui_click", -8.0)
	var n := int(FD.items.get(nm, 0))
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.z_index = 80
	add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.04, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	UI.panel(ov, Rect2(100, 330, 520, 570), Color(0.965, 0.941, 0.894), 10, P.LINE, 2)
	var art: String = str(FD.ITEM_ICON.get(nm, ""))
	if art != "" and ResourceLoader.exists(art):
		var tr := TextureRect.new()
		tr.texture = load(art)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.add_child(tr)
		tr.position = Vector2(275, 350)
		tr.size = Vector2(170, 170)
	UI.label(ov, nm, Vector2(0, 540), Vector2(720, 44), 34, P.INK, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(ov, "持 有 ×" + str(n), Vector2(0, 584), Vector2(720, 30), 18, P.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(ov, str(FD.ITEM_DESC.get(nm, "")), Vector2(0, 632), Vector2(720, 36), 20, P.INK, HORIZONTAL_ALIGNMENT_CENTER)
	UI.button(ov, "关 闭", Rect2(130, 790, 200, 62), 24, Color(0.22, 0.18, 0.14), Color(0.94, 0.91, 0.85),
		func() -> void: ov.queue_free(), Color(0.47, 0.40, 0.31), 1, 10)
	if n > 0:
		UI.button(ov, "使 用", Rect2(390, 790, 200, 62), 24, Color(0.902, 0.698, 0.259), Color(0.188, 0.125, 0.047),
			func() -> void: _confirm_use(nm, n, ov), Color(0.588, 0.412, 0.102), 2, 10)

func _confirm_use(nm: String, n: int, parent_ov: Control) -> void:
	if _closed or _done or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(parent_ov) or parent_ov.is_queued_for_deletion():
		return
	var cf := Control.new()
	cf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cf.z_index = 90
	parent_ov.add_child(cf)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.04, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cf.add_child(dim)
	UI.panel(cf, Rect2(140, 540, 440, 220), Color(0.965, 0.941, 0.894), 10, P.LINE, 2)
	UI.label(cf, "使用 " + nm + " ×1 ？", Vector2(0, 576), Vector2(720, 40), 28, P.INK, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(cf, "用掉后剩 " + str(n - 1) + " 个", Vector2(0, 618), Vector2(720, 28), 17, P.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var finished := [false]
	UI.button(cf, "取 消", Rect2(168, 668, 176, 60), 23, Color(0.22, 0.18, 0.14), Color(0.94, 0.91, 0.85),
		func() -> void:
			if finished[0]: return
			finished[0] = true
			cf.queue_free(), Color(0.47, 0.40, 0.31), 1, 10)
	UI.button(cf, "确 定", Rect2(376, 668, 176, 60), 24, P.SEAL, Color(0.988, 0.941, 0.839),
		func() -> void:
			if finished[0] or _closed or _done or cf.is_queued_for_deletion() or parent_ov.is_queued_for_deletion(): return
			finished[0] = true
			cf.queue_free()
			parent_ov.queue_free()
			_use_item(nm), P.GOLD, 2, 10)

func _use_item(nm: String) -> void:
	if _closed or _done or not is_inside_tree() or is_queued_for_deletion():
		return
	var result := FD.use_forge_item(slot_key, nm)
	if not bool(result["ok"]):
		_show_toast(str(result["reason"]))
		return
	if bool(result["trance"]):
		Audio.sfx("enlighten", -6.0)
	if nm == "龙鳞":
		Audio.sfx("equip", -10.0)
	_refresh()

func _close() -> void:
	if _closed or not is_inside_tree() or is_queued_for_deletion():
		return
	_closed = true
	hide()
	closed.emit()
	queue_free()

# ============================================================
class AnvilArt extends Control:
	const P := preload("res://shared/ui_pal.gd")
	const SCENE_ART := "res://assets/art/ui/forge_workbench_v1.webp"
	const STRIKE_TIME := 0.34
	const IMPACT_POINT := Vector2(318, 104)
	var trance := false:
		set(value):
			trance = value
			_update_processing()
	var empty := false
	var item_art: Texture2D
	var as_weapon := false
	var _scene_art: Texture2D
	var _t := 0.0
	var _raised := false
	var _strike_left := 0.0
	var _strike_tone := Color.WHITE
	func _ready() -> void:
		if ResourceLoader.exists(SCENE_ART):
			_scene_art = load(SCENE_ART) as Texture2D
		_update_processing()
	func _update_processing() -> void:
		set_process(trance or _strike_left > 0.0)
	func set_raised(value: bool) -> void:
		_raised = value
		queue_redraw()
	func strike(tone: Color) -> void:
		_raised = false
		_strike_tone = tone
		_strike_left = STRIKE_TIME
		_update_processing()
		queue_redraw()
	func _process(d: float) -> void:
		if trance:
			_t += d
		_strike_left = maxf(0.0, _strike_left - d)
		_update_processing()
		queue_redraw()
	func _draw_strike() -> void:
		var p := 1.0 - _strike_left / STRIKE_TIME
		var fade := 1.0 - p
		if _strike_left > 0.0:
			draw_circle(IMPACT_POINT, 20.0 * fade, Color(_strike_tone, 0.5 * fade), true, -1.0, true)
			for i in range(9):
				var ray := Vector2.from_angle(PI + float(i) * PI / 8.0)
				var from := IMPACT_POINT + ray * (12.0 + p * (46.0 + 5.0 * float(i % 3)))
				draw_line(from, from + ray * (9.0 + 9.0 * fade), Color(_strike_tone, fade), 1.0 + 1.8 * fade, true)
		if not empty and (_raised or (_strike_left > 0.0 and p < 0.66)):
			var lift := 1.0 if _raised else ease(clampf(p / 0.66, 0.0, 1.0), 0.46)
			var at := IMPACT_POINT + Vector2(55, -66) * lift
			draw_set_transform(at, -0.8 * lift)
			draw_line(Vector2(13, -6), Vector2(80, -39), Color(0.31, 0.18, 0.11), 11.0, true)
			draw_rect(Rect2(-24, -19, 48, 19), Color(0.24, 0.21, 0.18))
			draw_rect(Rect2(-24, -19, 48, 4), Color(0.67, 0.54, 0.39))
			draw_rect(Rect2(-24, -19, 48, 19), Color(0.10, 0.075, 0.055), false, 2.0)
			draw_set_transform(Vector2.ZERO)
	func _draw() -> void:
		if _scene_art != null:
			draw_texture_rect(_scene_art, Rect2(8, 4, size.x - 16, size.y - 22), false)
		var ox := 0.0
		var oy := 0.0
		if trance and not empty:
			var pulse := 0.5 + 0.5 * sin(_t * 2.2)
			for i in 5:
				draw_circle(Vector2(320 + ox, 150 + oy), 290.0 - float(i) * 44.0,
					Color(1.0, 0.84, 0.46, 0.020 + 0.016 * float(i) * (0.7 + 0.5 * pulse)))
			draw_arc(Vector2(320 + ox, 150 + oy), 250.0 + 12.0 * pulse, 0, TAU, 64,
				Color(1.0, 0.90, 0.62, 0.16 + 0.14 * pulse), 3.0, true)
		if _scene_art != null:
			if not empty and item_art != null:
				var extent := item_art.get_size()
				var fit := extent * ((232.0 if as_weapon else 126.0) / maxf(extent.x, extent.y))
				draw_set_transform(Vector2(318, 108), PI * 0.5 if as_weapon else 0.0)
				draw_texture_rect(item_art, Rect2(-fit * 0.5, fit), false, Color(1.0, 0.91, 0.76))
				draw_set_transform(Vector2.ZERO)
			_draw_strike()
			return
		var body := Color(0.39, 0.34, 0.28)
		draw_rect(Rect2(100 + ox, 96 + oy, 384, 32), body)
		draw_colored_polygon(PackedVector2Array([
			Vector2(484 + ox, 96 + oy), Vector2(538 + ox, 112 + oy), Vector2(484 + ox, 128 + oy)
		]), body)
		draw_colored_polygon(PackedVector2Array([
			Vector2(190 + ox, 128 + oy), Vector2(394 + ox, 128 + oy), Vector2(362 + ox, 218 + oy), Vector2(222 + ox, 218 + oy)
		]), Color(0.31, 0.26, 0.21))
		if empty:
			_draw_strike()
			return
		if trance:
			# 剑身：流光彩虹（沿剑身跑色相）
			var seg := 16
			var sw := 218.0 / float(seg)
			for i in seg:
				var h := fmod(float(i) / float(seg) * 0.85 + _t * 0.30, 1.0)
				var c := Color.from_hsv(h, 0.42, 1.0)
				draw_rect(Rect2(150 + ox + sw * float(i), 72 + oy, sw + 1.0, 20), c)
			var tipH := fmod(0.85 + _t * 0.30, 1.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(150 + ox, 72 + oy), Vector2(150 + ox, 92 + oy), Vector2(120 + ox, 82 + oy)
			]), Color.from_hsv(tipH, 0.42, 1.0))
			# 高光扫过
			var hx := 150.0 + fmod(_t * 150.0, 300.0)
			draw_rect(Rect2(hx + ox, 72 + oy, 26, 20), Color(1, 1, 1, 0.55))
			draw_rect(Rect2(150 + ox, 74 + oy, 218, 3), Color(1, 1, 1, 0.6))
			# 彩花
			for i in 16:
				var ph := float(i) * 0.7
				var cx2 := 200.0 + fmod(float(i) * 41.0 + _t * 22.0, 300.0)
				var cy2 := 52.0 + sin(_t * 1.5 + ph) * 30.0 + float(i % 5) * 18.0
				var col := Color.from_hsv(fmod(float(i) * 0.17 + _t * 0.12, 1.0), 0.55, 0.98, 0.85)
				var r := 4.0 + float(i % 3) * 1.6
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx2, cy2 - r), Vector2(cx2 + r, cy2), Vector2(cx2, cy2 + r), Vector2(cx2 - r, cy2)
				]), col)
			# 剑身星点
			for i in 4:
				var sx := 170.0 + float(i) * 62.0 + fmod(_t * 40.0, 20.0)
				var a := 0.4 + 0.5 * absf(sin(_t * 3.0 + float(i)))
				draw_circle(Vector2(sx + ox, 82 + oy), 2.4, Color(1, 1, 1, a))
		else:
			var blade := Color(0.796, 0.675, 0.439)
			draw_rect(Rect2(150 + ox, 72 + oy, 218, 20), blade)
			draw_colored_polygon(PackedVector2Array([
				Vector2(150 + ox, 72 + oy), Vector2(150 + ox, 92 + oy), Vector2(120 + ox, 82 + oy)
			]), blade)
		draw_rect(Rect2(368 + ox, 60 + oy, 12, 44), Color(0.588, 0.471, 0.235))
		draw_rect(Rect2(380 + ox, 68 + oy, 50, 28), Color(0.361, 0.275, 0.188))
		draw_circle(Vector2(434 + ox, 82 + oy), 10.0, Color(0.878, 0.678, 0.294))
		_draw_strike()

class GaugeArt extends Control:
	const P := preload("res://shared/ui_pal.gd")
	var count := 0
	var trance := 0
	var crack := 0
	func _draw() -> void:
		var w := size.x
		var gap := 7.0
		var cw := (w - gap * 9.0) / 10.0
		for i in 10:
			var x := float(i) * (cw + gap)
			var sb := StyleBoxFlat.new()
			var on := i < count or trance > 0
			sb.bg_color = Color(0.788, 0.604, 0.220) if on else Color(0.902, 0.867, 0.804)
			sb.set_corner_radius_all(7)
			sb.border_color = Color(0.690, 0.533, 0.227) if on else Color(0.816, 0.769, 0.690)
			sb.set_border_width_all(2 if trance > 0 else 1)
			draw_style_box(sb, Rect2(x, 0, cw, size.y))

class OddsArt extends Control:
	const P := preload("res://shared/ui_pal.gd")
	var w := {"破": 0.0, "损": 0.0, "维": 0.0, "成": 0.0, "大": 0.0}
	const NAME := {"破": "破坏", "损": "损伤", "维": "维持", "成": "成功", "大": "大成功"}
	const COL := {
		"破": Color(0.753, 0.224, 0.169), "损": Color(0.788, 0.541, 0.227),
		"维": Color(0.604, 0.561, 0.502), "成": Color(0.310, 0.478, 0.290), "大": Color(0.780, 0.580, 0.220),
	}
	func _draw() -> void:
		var tot := 0.0
		for k in w:
			tot += float(w[k])
		if tot <= 0.0:
			return
		var x := 0.0
		for k in ["破", "损", "维", "成", "大"]:
			var seg: float = size.x * float(w[k]) / tot
			draw_rect(Rect2(x, 0, seg, 34), COL[k])
			x += seg
		var lx := 0.0
		for k in ["破", "损", "维", "成", "大"]:
			draw_rect(Rect2(lx, 46, 12, 12), COL[k])
			var t: String = str(NAME[k]) + " " + str(snappedf(float(w[k]), 0.1)) + "%"
			draw_string(P.FONT, Vector2(lx + 18, 57), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.133, 0.129, 0.149))
			lx += size.x / 5.0
