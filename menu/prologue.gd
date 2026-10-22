extends Control
# 引子（第一关）：村长第一句 → 是否跳过剧情；继续走三波
signal finished(skipped: bool)
const GS := preload("res://shared/game_state.gd")
const Ui := preload("res://menu/menu_theme.gd")
var _dlg: Panel
var _chief: TextureRect
var _name_lb: Label
var _text_lb: Label
var _next_btn: Button
var _skip_panel: Control
var _lines: Array = [
	{"who": "村长", "text": "孩子，山路不太平，你当真要走？"},
	{"who": "少侠", "text": "嗯。总不能一辈子守在村口。"},
	{"who": "村长", "text": "去吧。记住——遇事别慌，剑在手里。"},
]
var _idx := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/art/bg/bg_village.jpg"):
		bg.texture = load("res://assets/art/bg/bg_village.jpg")
	add_child(bg)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.08, 0.07, 0.06, 0.18)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	# 少侠（左）/ 村长（右）
	var hero := TextureRect.new()
	hero.position = Vector2(30, 470)
	hero.size = Vector2(240, 380)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/char/player_q.png"):
		hero.texture = load("res://assets/char/player_q.png")
	add_child(hero)
	_chief = TextureRect.new()
	var chief := _chief
	chief.position = Vector2(430, 430)
	chief.size = Vector2(270, 420)
	chief.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chief.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/char/village_chief_q_cut.png"):
		chief.texture = load("res://assets/char/village_chief_q_cut.png")
	add_child(chief)
	# 对白卡
	_dlg = Panel.new()
	_dlg.position = Vector2(30, 950)
	_dlg.size = Vector2(660, 280)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.965, 0.947, 0.902, 0.98)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.72, 0.58, 0.25, 0.85)
	sb.set_border_width_all(2)
	_dlg.add_theme_stylebox_override("panel", sb)
	add_child(_dlg)
	_name_lb = _mk(24, Color(0.55, 0.22, 0.18))
	_name_lb.position = Vector2(22, 14)
	_name_lb.size = Vector2(200, 34)
	_dlg.add_child(_name_lb)
	_text_lb = _mk(19, Color(0.18, 0.16, 0.14))
	_text_lb.position = Vector2(22, 56)
	_text_lb.size = Vector2(616, 140)
	_text_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg.add_child(_text_lb)
	_next_btn = Button.new()
	_next_btn.text = "继 续"
	_next_btn.position = Vector2(480, 216)
	_next_btn.size = Vector2(160, 48)
	_next_btn.add_theme_font_size_override("font_size", 17)
	_next_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.pressed.connect(_on_next)
	_ink(_next_btn)
	_dlg.add_child(_next_btn)
	_show_line()

func _mk(fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _ink(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.21, 0.19, 0.20, 0.96)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))

func _show_line() -> void:
	if _idx >= _lines.size():
		_show_skip_prompt()
		return
	var d: Dictionary = _lines[_idx]
	_name_lb.text = str(d["who"])
	_text_lb.text = str(d["text"])
	_next_btn.text = "继 续"

func _on_next() -> void:
	_idx += 1
	_show_line()

func _show_skip_prompt() -> void:
	_skip_panel = Control.new()
	_skip_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skip_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_skip_panel)
	var dim2 := ColorRect.new()
	dim2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim2.color = Color(0.04, 0.03, 0.02, 0.55)
	_skip_panel.add_child(dim2)
	var box := Panel.new()
	box.position = Vector2(90, 455)
	box.size = Vector2(540, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.955, 0.937, 0.886, 0.99)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.72, 0.58, 0.25, 0.85)
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	_skip_panel.add_child(box)
	var t := _mk(26, Color(0.55, 0.22, 0.18))
	t.text = "是否跳过剧情？"
	t.position = Vector2(30, 36)
	t.size = Vector2(480, 40)
	box.add_child(t)
	var sub := _mk(15, Color(0.30, 0.27, 0.22, 0.75))
	sub.text = "跳过只跳这一段，直接接到下一段"
	sub.position = Vector2(30, 86)
	sub.size = Vector2(480, 26)
	box.add_child(sub)
	var b_skip := Button.new()
	b_skip.text = "跳 过"
	b_skip.position = Vector2(40, 196)
	b_skip.size = Vector2(200, 54)
	b_skip.add_theme_font_size_override("font_size", 18)
	b_skip.focus_mode = Control.FOCUS_NONE
	b_skip.pressed.connect(_do_skip)
	_ink(b_skip)
	box.add_child(b_skip)
	var b_go := Button.new()
	b_go.text = "继 续 看"
	b_go.position = Vector2(300, 196)
	b_go.size = Vector2(200, 54)
	b_go.add_theme_font_size_override("font_size", 18)
	b_go.focus_mode = Control.FOCUS_NONE
	b_go.pressed.connect(_do_continue)
	_ink(b_go)
	box.add_child(b_go)


# ============================================================
# 三波引子战斗：站桩自动普攻；第3波回血怪+绝学按钮（时间冷却）
# ============================================================
var _battle: Control
var _hero: TextureRect
var _foe: TextureRect
var _foe_hp_lb: Label
var _foe_hp_fill: ColorRect
var _hero_hp_lb: Label
var _hero_hp_fill: ColorRect
var _banner: Label
var _banner_tw: Tween
var _battle_on := false
var _wave := 1
var _foe_hp := 100.0
var _foe_hp_max := 100.0
var _hero_hp := 100.0
var _atk_t := 0.0
var _foe_t := 0.0
var _ult_cd := 0.0
var _ult_btn: Button
var _ult_busy := false
var _prompt_lb: Label

func _start_battle() -> void:
	_dlg.visible = false
	if _chief != null:
		_chief.visible = false
	_battle_on = true
	_wave = 2
	_foe_hp = 100.0
	_foe_hp_max = 100.0
	_hero_hp = 100.0
	_battle = Control.new()
	_battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_battle)
	_hero = TextureRect.new()
	_hero.position = Vector2(60, 520)
	_hero.size = Vector2(210, 330)
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/char/player_q.png"):
		_hero.texture = load("res://assets/char/player_q.png")
	_battle.add_child(_hero)
	_foe = TextureRect.new()
	_foe.position = Vector2(430, 520)
	_foe.size = Vector2(230, 330)
	_foe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_foe.flip_h = true
	if ResourceLoader.exists("res://assets/char/mob_dog_q.png"):
		_foe.texture = load("res://assets/char/mob_dog_q.png")
	_battle.add_child(_foe)
	# 血条（上：怪；下：少侠）
	_foe_hp_lb = _mk(15, Color(0.94, 0.91, 0.84))
	_foe_hp_lb.position = Vector2(160, 120)
	_foe_hp_lb.size = Vector2(420, 22)
	_foe_hp_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_battle.add_child(_foe_hp_lb)
	var fbg := ColorRect.new()
	fbg.position = Vector2(160, 146)
	fbg.size = Vector2(400, 14)
	fbg.color = Color(0.16, 0.13, 0.12, 0.55)
	_battle.add_child(fbg)
	_foe_hp_fill = ColorRect.new()
	_foe_hp_fill.position = Vector2(160, 146)
	_foe_hp_fill.size = Vector2(400, 14)
	_foe_hp_fill.color = Color(0.62, 0.22, 0.18)
	_battle.add_child(_foe_hp_fill)
	_hero_hp_lb = _mk(14, Color(0.94, 0.91, 0.84))
	_hero_hp_lb.position = Vector2(60, 880)
	_hero_hp_lb.size = Vector2(220, 20)
	_battle.add_child(_hero_hp_lb)
	var hbg := ColorRect.new()
	hbg.position = Vector2(60, 904)
	hbg.size = Vector2(220, 12)
	hbg.color = Color(0.16, 0.13, 0.12, 0.55)
	_battle.add_child(hbg)
	_hero_hp_fill = ColorRect.new()
	_hero_hp_fill.position = Vector2(60, 904)
	_hero_hp_fill.size = Vector2(220, 12)
	_hero_hp_fill.color = Color(0.30, 0.52, 0.34)
	_battle.add_child(_hero_hp_fill)
	# 绝学按钮（第3波才出现）
	_ult_btn = Button.new()
	_ult_btn.text = "落日剑诀"
	_ult_btn.position = Vector2(470, 1050)
	_ult_btn.size = Vector2(200, 64)
	_ult_btn.add_theme_font_size_override("font_size", 20)
	_ult_btn.focus_mode = Control.FOCUS_NONE
	_ult_btn.visible = false
	_ult_btn.pressed.connect(_press_ult)
	_ink(_ult_btn)
	_battle.add_child(_ult_btn)
	_prompt_lb = _mk(16, Color(0.94, 0.91, 0.84))
	_prompt_lb.position = Vector2(60, 960)
	_prompt_lb.size = Vector2(600, 26)
	_prompt_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_battle.add_child(_prompt_lb)
	_banner = _mk(20, Color(0.98, 0.90, 0.72))
	_banner.position = Vector2(0, 220)
	_banner.size = Vector2(720, 40)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_outline_color", Color(0.25, 0.16, 0.06, 0.9))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.modulate = Color(1, 1, 1, 0)
	_battle.add_child(_banner)
	_refresh_bars()
	_prompt_lb.text = "山道忽有动静——有东西扑了出来！"

func _refresh_bars() -> void:
	_foe_hp = clampf(_foe_hp, 0.0, _foe_hp_max)
	_hero_hp = clampf(_hero_hp, 0.0, 100.0)
	_foe_hp_fill.size.x = 400.0 * _foe_hp / _foe_hp_max
	_hero_hp_fill.size.x = 220.0 * _hero_hp / 100.0
	_foe_hp_lb.text = "山贼　" + str(int(_foe_hp)) + "/" + str(int(_foe_hp_max))
	_hero_hp_lb.text = "少侠　" + str(int(_hero_hp)) + "/100"

func _process(delta: float) -> void:
	if not _battle_on or _ult_busy:
		return
	_atk_t += delta
	if _atk_t >= 1.4:
		_atk_t = 0.0
		_hero_attack()
	_foe_t += delta
	if _foe_t >= 2.6:
		_foe_t = 0.0
		_foe_attack()
	if _wave == 3 and _foe_hp > 0.0:
		_foe_hp = minf(_foe_hp_max, _foe_hp + 9.0 * delta)
		_refresh_bars()
	if _wave == 3:
		if _ult_cd > 0.0:
			_ult_cd -= delta
			_ult_btn.text = "落日剑诀 " + str(snappedf(_ult_cd, 0.1))
			_ult_btn.disabled = true
		else:
			_ult_btn.text = "落日剑诀"
			_ult_btn.disabled = false

func _hero_attack() -> void:
	var tw := create_tween()
	tw.tween_property(_hero, "position:x", _hero.position.x + 46, 0.12)
	tw.tween_property(_hero, "position:x", _hero.position.x, 0.22)
	_slash_arc()
	var dmg := 10
	_foe_hp -= dmg
	_refresh_bars()
	_show_banner("落日剑法")
	_dmg_float(_foe.position + Vector2(110, 90), dmg)
	if _foe_hp <= 0.0:
		_win()
	elif _wave == 2 and _foe_hp <= 50.0:
		_to_wave3()

func _foe_attack() -> void:
	if _foe_hp <= 0.0:
		return
	var tw := create_tween()
	tw.tween_property(_foe, "position:x", _foe.position.x - 40, 0.12)
	tw.tween_property(_foe, "position:x", _foe.position.x, 0.22)
	_hero_hp -= 4
	_refresh_bars()
	_dmg_float(_hero.position + Vector2(100, 90), 4)
	if _hero_hp <= 0.0:
		_lose()

func _to_wave3() -> void:
	_wave = 3
	_foe_hp_max = 100.0
	_foe_hp = 40.0
	_refresh_bars()
	_prompt_lb.text = "这怪一直在回血，寻常招式伤不了它——用落日剑诀！"
	_ult_btn.visible = true
	_ult_cd = 6.0
	_ult_btn.disabled = true

func _press_ult() -> void:
	if _ult_cd > 0.0 or _ult_busy:
		return
	_ult_busy = true
	_prompt_lb.text = "落日剑诀——"
	_ult_btn.visible = false
	# 约2秒分镜：压暗 → 技能名 → 红日立绘叠化 → 四道剑痕 → 震屏+四个200 → 秒杀
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.0)
	_battle.add_child(dim)
	var tw := create_tween()
	tw.tween_property(dim, "color:a", 0.55, 0.25)
	tw.tween_callback(func() -> void:
		_show_banner("落日剑诀")
		var art := TextureRect.new()
		art.position = Vector2(90, 250)
		art.size = Vector2(540, 460)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists("res://assets/art/skills/sun_sword_ult.jpg"):
			art.texture = load("res://assets/art/skills/sun_sword_ult.jpg")
		art.modulate = Color(1, 1, 1, 0)
		_battle.add_child(art)
		var tw2 := create_tween()
		tw2.tween_property(art, "modulate:a", 1.0, 0.3)
		tw2.tween_callback(func() -> void:
			# 四道剑痕依次落下
			for i in 4:
				var ln := Line2D.new()
				ln.width = 6.0
				ln.default_color = Color(0.95, 0.30, 0.20, 0.0)
				ln.add_point(Vector2(210.0 + i * 78.0, 250.0))
				ln.add_point(Vector2(210.0 + i * 78.0, 780.0))
				_battle.add_child(ln)
				var tw3 := create_tween()
				tw3.tween_interval(i * 0.10)
				tw3.tween_property(ln, "default_color:a", 0.95, 0.08)
				tw3.tween_property(ln, "default_color:a", 0.0, 0.35)
				tw3.chain().tween_callback(ln.queue_free)
			var tw4 := create_tween()
			tw4.tween_interval(0.5)
			tw4.tween_callback(func() -> void:
				var sh := create_tween()
				sh.tween_property(_battle, "position:x", 10.0, 0.05)
				sh.tween_property(_battle, "position:x", -10.0, 0.05)
				sh.tween_property(_battle, "position:x", 0.0, 0.05)
				_foe_hp = 0.0
				_refresh_bars()
				for i in 4:
					_dmg_float(Vector2(300.0 + i * 70.0, 420.0 + i * 60.0), 200)
				_win()))
		tw2.tween_interval(1.6))
	tw.tween_interval(2.2)

func _win() -> void:
	_battle_on = false
	_prompt_lb.text = "山贼倒了！"
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(_do_skip)

func _lose() -> void:
	_battle_on = false
	_prompt_lb.text = "你倒下了……（按退出重来）"


func _slash_arc() -> void:
	var c := Node2D.new()
	c.position = _foe.position + Vector2(115, 170)
	_battle.add_child(c)
	c.draw.connect(func() -> void:
		c.draw_circle(Vector2.ZERO, 70.0, Color(0.85, 0.32, 0.16, 0.25))
		c.draw_arc(Vector2.ZERO, 80.0, -2.2, 0.6, 24, Color(0.98, 0.72, 0.34, 0.95), 9.0, true)
		c.draw_arc(Vector2.ZERO, 66.0, -1.9, 0.3, 24, Color(1.0, 0.9, 0.72, 0.9), 4.0, true))
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(c.queue_free)

func _show_banner(t: String) -> void:
	if _banner_tw != null and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner.text = t
	_banner.modulate = Color(1, 1, 1, 1)
	_banner.position = Vector2(0, 220)
	_banner_tw = create_tween()
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.6).set_delay(0.4)

func _dmg_float(pos: Vector2, dmg: int) -> void:
	var lb := _mk(26, Color(0.96, 0.72, 0.32))
	lb.text = "-" + str(dmg)
	lb.position = pos
	lb.size = Vector2(120, 40)
	_battle.add_child(lb)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lb, "position:y", pos.y - 60, 0.6)
	tw.tween_property(lb, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(lb.queue_free)

func _do_skip() -> void:
	GS.first_journey_done = true
	GS.save_game()
	finished.emit(true)
	get_tree().change_scene_to_file("res://menu_sketch.tscn")

func _do_continue() -> void:
	_start_battle()
