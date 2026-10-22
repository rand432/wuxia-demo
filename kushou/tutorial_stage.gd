extends Control
# ============================================================
# kushou/tutorial_stage.gd —— 教学关 v0（村口 · 5 波）
#
# 目的：先把"出村 → 一局 5 波 → 回村"这条线跑通，验证新手引导的手感。
#   · 普攻/走位/索敌自动；玩家只点两颗：功法（落日剑法）和大招（落日剑诀）
#   · 5 波：方士（躲红圈）→ 波次 → 掉血 → 功法 → 濒危放大招
#   · 引导＝箭头 + 目标金边/按钮金光 + 一行字；引导期间战斗暂停
#   · 人物表现口径（用户 2026-10-22）：素材是静态的，别硬做动作——
#     对话框里用"圆形底 + 头像"的立绘牌；战场要不要把全身小人换成圆牌，待拍。
#   · **铁律：引导不是说明书。先让故事说话，箭头/光只是手指。**
#     提示文案一律写成戏里的短句（"闪开。""一波未平，一波又起。"），
#     不写"点这里/看这里/共几波"这种系统腔。
#   · 教学局不会输：第 5 波血量锁低，放大招清场
#   · 大招口径（用户 2026-10-22）：大招**可更换**；全队**所有人共用一个大招槽**，
#     不是角色专属。现在的「落日剑诀」＝当前共用的那一格，之后换绝招就是换它。
#
# 入口（临时）：主界面底排「出村」→ 直接开本关（menu_sketch 的 TUTORIAL_DEMO 开关）
# 不写存档；退出/清场都只回调 closed。
# ============================================================

signal closed

const GameState := preload("res://shared/game_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const Audio := preload("res://shared/audio.gd")
const TokenActor := preload("res://kushou/token_actor.gd")
const CharArt := preload("res://shared/char_art.gd")
const UI_FONT := preload("res://fonts/ink.ttf")

const W := 720.0
const H := 1280.0
const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.93, 0.90, 0.83)
const SEAL := Color(0.68, 0.15, 0.12)
const GOLD := Color(0.86, 0.68, 0.26)
# 伤害类型：物理 / 元素 / 反伤 / 恢复 / 暴击（金属配色）
const DMG_PHYS := Color(0.40, 0.44, 0.50)     # 物理：钢
const DMG_ELEM := Color(0.80, 0.56, 0.12)     # 元素：金
const DMG_CRIT := Color(0.78, 0.22, 0.10)     # 暴击：铜红
const DMG_REFLECT := Color(0.62, 0.30, 0.14)  # 反伤：古铜
const DMG_HEAL := Color(0.28, 0.55, 0.26)     # 恢复：松绿
const HERO_HOME := Vector2(360.0, 800.0)
const FIELD_MIN := Vector2(70.0, 380.0)
const FIELD_MAX := Vector2(650.0, 940.0)
const HERO_SPEED := 250.0
const HERO_RANGE := 120.0
const HERO_ATK := 30.0
const HERO_ATK_CD := 0.72
const SKILL_CD := 20.0
const SKILL_MULT := 1.5
const ULT_MULT := 2.0
const ULT_DAMAGE := 9999.0
const HERO_HP_MAX := 320.0

# ---- 层 ----
var _bg: Control
var _actors: Node2D
var _fx: Control
var _hud: Control
var _guide_layer: Control
var _pause_ov: Control
var _end_ov: Control
var _end_title: Label

# ---- 对话（圆框立绘 + 名字 + 对话框）----
var _dlg_layer: Control
var _dlg_box: Panel
var _dlg_disc: Control
var _dlg_portrait: TextureRect
var _dlg_name: Label
var _dlg_text: Label
var _dlg_hint: Label
var _dlg_on := false
var _dlg_lines: Array = []
var _dlg_i := 0
var _dlg_cb := Callable()

# ---- 主角 ----
var _hero: Node2D
var _hero_pos := HERO_HOME
var _hero_target := HERO_HOME
var _manual_move := false
var _hero_hp := HERO_HP_MAX
var _hero_rage := 0.0
var _hero_atk_t := 0.4
var _hero_skill_cd := 0.0
var _hero_flash := 0.0
var _hero_dir := 1.0
var _flash_t := 0.0
var _shake_t := 0.0
var _shake_off := Vector2.ZERO
var _zoom := 1.0
var _pivot := Vector2.ZERO
var _ult_cine := -1.0
var _break_cine := -1.0
var _break_burst := false
var _ult_foes: Array = []
var _ult_lb: Label
var _log_lb: Label
var _ult_banner := false
var _ult_ov: Control = null
var _ult_dim: ColorRect = null
var _ult_art: TextureRect = null
var _action_which := ""
var _action_down_ms := 0
var _tip_which := ""
var _tip_until_ms := 0

# ---- 敌人 / 特效 ----
var _enemies: Array = []
var _decor: Array = []
var _telegraphs: Array = []
var _floats: Array = []
var _fx_list: Array = []

# ---- 流程 ----
var _wave := 0
var _wave_max := 3
var _paused := false
var _finished := false
var _victory := false
var _wave_wait := -1.0
var _started := false
var _dodge_taught := false
var _counter_guided := false
var _mage_banner_done := false
var _guide_enemy = null
var _hp_guide_done := false
var _wave5_fight := false
var _wave5_crisis_done := false
var _wave5_t := 0.0
var loot_silver := 0

# ---- 引导 ----
var _guide_on := false
var _guide_text := ""
var _guide_rect := Rect2()
var _guide_mode := "tap"
var _guide_kind := ""
var _guide_cb := Callable()
var _guide_t := 0.0

# ---- 界面 ----
var _skill_btn: Button
var _ult_btn: Button
var _pause_btn: Button
var _exit_btn: Button
var _pause_return: Button
var _pause_exit: Button
var _end_return: Button
var _end_again: Button
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_bg()
	_actors = Node2D.new()
	_actors.z_index = 2
	add_child(_actors)
	_build_fx()
	_build_hud()
	_build_guide()
	_build_dialogue()
	_build_buttons()
	_build_pause()
	_build_end()
	_restart_stage()


# ============================================================
# 建层
# ============================================================

func _build_bg() -> void:
	_bg = Control.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.draw.connect(_draw_bg)
	add_child(_bg)


func _build_fx() -> void:
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.z_index = 4
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.z_index = 6
	_hud.draw.connect(_draw_hud)
	add_child(_hud)

	# 大招红字「起！」
	_ult_lb = UiKit.make_label(self, Vector2(0.0, 350.0), Vector2(720.0, 220.0), 110, SEAL)
	_ult_lb.text = "起！"
	_ult_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ult_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ult_lb.add_theme_font_override("font", UI_FONT)
	_ult_lb.add_theme_constant_override("outline_size", 12)
	_ult_lb.add_theme_color_override("font_outline_color", Color(0.16, 0.04, 0.03, 0.88))
	_ult_lb.z_index = 12
	_ult_lb.visible = false
	_ult_lb.pivot_offset = Vector2(360.0, 110.0)



func _build_guide() -> void:
	_guide_layer = Control.new()
	_guide_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_guide_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_layer.z_index = 8
	_guide_layer.draw.connect(_draw_guide)
	add_child(_guide_layer)


func _build_dialogue() -> void:
	_dlg_layer = Control.new()
	_dlg_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dlg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg_layer.z_index = 9
	_dlg_layer.visible = false
	add_child(_dlg_layer)

	_dlg_box = Panel.new()
	_dlg_box.position = Vector2(60.0, 842.0)
	_dlg_box.size = Vector2(600.0, 216.0)
	_dlg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.94, 0.89, 1.0)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.75)
	sb.set_border_width_all(2)
	_dlg_box.add_theme_stylebox_override("panel", sb)
	_dlg_layer.add_child(_dlg_box)

	_dlg_disc = Control.new()
	_dlg_disc.position = Vector2(72.0, 850.0)
	_dlg_disc.size = Vector2(166.0, 166.0)
	_dlg_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg_disc.draw.connect(_draw_disc)
	_dlg_layer.add_child(_dlg_disc)

	_dlg_portrait = TextureRect.new()
	_dlg_portrait.position = Vector2(80.0, 858.0)
	_dlg_portrait.size = Vector2(150.0, 150.0)
	_dlg_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dlg_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_dlg_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec2 uv = UV - vec2(0.5); if (dot(uv, uv) > 0.25) { discard; } COLOR = texture(TEXTURE, UV); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_dlg_portrait.material = mat
	_dlg_layer.add_child(_dlg_portrait)

	_dlg_name = UiKit.make_label(_dlg_layer, Vector2(270.0, 856.0), Vector2(360.0, 30.0), 24, SEAL)
	_dlg_text = UiKit.make_label(_dlg_layer, Vector2(270.0, 894.0), Vector2(370.0, 140.0), 20, INK)
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_hint = UiKit.make_label(_dlg_layer, Vector2(486.0, 1022.0), Vector2(160.0, 24.0), 14, Color(INK.r, INK.g, INK.b, 0.45))
	_dlg_hint.text = "轻点继续"
	_dlg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dlg_name.add_theme_font_override("font", UI_FONT)
	_dlg_text.add_theme_font_override("font", UI_FONT)
	_dlg_hint.add_theme_font_override("font", UI_FONT)


func _draw_disc() -> void:
	_dlg_disc.draw_circle(Vector2(83.0, 83.0), 80.0, Color(0.90, 0.87, 0.79))
	_dlg_disc.draw_arc(Vector2(83.0, 83.0), 80.0, 0.0, TAU, 64, Color(GOLD.r, GOLD.g, GOLD.b, 0.85), 3.0, true)
	_dlg_disc.draw_arc(Vector2(83.0, 83.0), 73.0, 0.0, TAU, 64, Color(0.42, 0.35, 0.25, 0.35), 1.0, true)


func _dialogue(lines: Array, cb := Callable()) -> void:
	if lines.is_empty():
		if cb.is_valid():
			cb.call()
		return
	_dlg_on = true
	_dlg_lines = lines
	_dlg_i = 0
	_dlg_cb = cb
	_paused = true
	if is_instance_valid(_hero):
		_hero.visible = false
	_dlg_layer.visible = true
	_dlg_show()


func _dlg_show() -> void:
	var line: Dictionary = _dlg_lines[_dlg_i]
	var who := str(line.get("who", ""))
	var txt := str(line.get("text", ""))
	var art := str(line.get("art", ""))
	_dlg_name.text = who
	_dlg_text.text = txt
	var has_art := art != "" and CharArt.face(art) != null
	_dlg_disc.visible = has_art
	_dlg_portrait.visible = has_art
	if has_art:
		_dlg_portrait.texture = CharArt.face(art)
		_dlg_name.position = Vector2(270.0, 856.0)
		_dlg_text.position = Vector2(270.0, 894.0)
		_dlg_text.size = Vector2(370.0, 140.0)
	else:
		_dlg_name.position = Vector2(84.0, 856.0)
		_dlg_text.position = Vector2(84.0, 894.0)
		_dlg_text.size = Vector2(550.0, 140.0)
	var name_col := INK
	if who == "主角":
		name_col = SEAL
	elif who == "引导":
		name_col = Color(0.62, 0.24, 0.12)
	elif who == "旁白":
		name_col = Color(INK.r, INK.g, INK.b, 0.55)
	_dlg_name.add_theme_color_override("font_color", name_col)
	var text_col := Color(INK.r, INK.g, INK.b, 0.92)
	if who == "旁白":
		text_col = Color(INK.r, INK.g, INK.b, 0.78)
	elif who == "引导":
		text_col = Color(0.55, 0.18, 0.10)
	_dlg_text.add_theme_color_override("font_color", text_col)


func _dlg_next() -> void:
	if _dlg_i < _dlg_lines.size() - 1:
		_dlg_i += 1
		_dlg_show()
		return
	_dlg_on = false
	_dlg_layer.visible = false
	_paused = false
	if is_instance_valid(_hero):
		_hero.visible = true
	var cb := _dlg_cb
	_dlg_cb = Callable()
	if cb.is_valid():
		cb.call()


func _build_buttons() -> void:
	_pause_btn = UiKit.make_button(self, Vector2(536.0, 18.0), Vector2(84.0, 44.0), "暂停", 20)
	_pause_btn.z_index = 10
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.pressed.connect(_on_pause)

	_exit_btn = UiKit.make_button(self, Vector2(628.0, 18.0), Vector2(76.0, 44.0), "退出", 18)
	_exit_btn.z_index = 10
	_exit_btn.focus_mode = Control.FOCUS_NONE
	_exit_btn.pressed.connect(_exit_stage)

	# 下方只留两个圆形招式键：透明 Button 做点击区，图标画在 HUD 上
	_skill_btn = Button.new()
	_skill_btn.position = Vector2(236.0, 1106.0)
	_skill_btn.size = Vector2(88.0, 88.0)
	_skill_btn.flat = true
	_skill_btn.text = ""
	_skill_btn.focus_mode = Control.FOCUS_NONE
	_skill_btn.modulate = Color(1, 1, 1, 0)
	_skill_btn.z_index = 10
	_skill_btn.button_down.connect(func() -> void: _on_action_down("skill"))
	_skill_btn.button_up.connect(func() -> void: _on_action_up("skill"))
	add_child(_skill_btn)

	_ult_btn = Button.new()
	_ult_btn.position = Vector2(370.0, 1100.0)
	_ult_btn.size = Vector2(100.0, 100.0)
	_ult_btn.flat = true
	_ult_btn.text = ""
	_ult_btn.focus_mode = Control.FOCUS_NONE
	_ult_btn.modulate = Color(1, 1, 1, 0)
	_ult_btn.z_index = 10
	_ult_btn.button_down.connect(func() -> void: _on_action_down("ult"))
	_ult_btn.button_up.connect(func() -> void: _on_action_up("ult"))
	add_child(_ult_btn)
	_skill_btn.visible = false
	_ult_btn.visible = false


func _build_pause() -> void:
	_pause_ov = Control.new()
	_pause_ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_ov.z_index = 40
	_pause_ov.visible = false
	add_child(_pause_ov)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.03, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_ov.add_child(dim)
	var box := Panel.new()
	box.position = Vector2(120.0, 470.0)
	box.size = Vector2(480.0, 300.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(4)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	_pause_ov.add_child(box)
	var t := UiKit.make_label(box, Vector2(0.0, 28.0), Vector2(480.0, 44.0), 30, INK)
	t.text = "暂 停"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_return = UiKit.make_button(box, Vector2(80.0, 120.0), Vector2(320.0, 56.0), "继 续", 22)
	_pause_return.focus_mode = Control.FOCUS_NONE
	_pause_return.pressed.connect(_on_resume)
	_pause_exit = UiKit.make_button(box, Vector2(80.0, 200.0), Vector2(320.0, 56.0), "退 出", 22)
	_pause_exit.focus_mode = Control.FOCUS_NONE
	_pause_exit.pressed.connect(_exit_stage)


func _build_end() -> void:
	_end_ov = Control.new()
	_end_ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_ov.z_index = 50
	_end_ov.visible = false
	add_child(_end_ov)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_ov.add_child(dim)
	var box := Panel.new()
	box.position = Vector2(90.0, 430.0)
	box.size = Vector2(540.0, 380.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(4)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.60)
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	_end_ov.add_child(box)
	_end_title = UiKit.make_label(box, Vector2(0.0, 44.0), Vector2(540.0, 90.0), 54, SEAL)
	_end_title.text = "清 场"
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UiKit.make_label(box, Vector2(0.0, 138.0), Vector2(540.0, 38.0), 20, Color(INK.r, INK.g, INK.b, 0.7))
	sub.text = "风停了。断剑斜插在土里。"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var story := UiKit.make_label(box, Vector2(20.0, 182.0), Vector2(500.0, 28.0), 17, Color(INK.r, INK.g, INK.b, 0.74))
	story.text = "剩下的匪徒早已胆寒，跟着头目连滚带爬地退去。"
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var shout := UiKit.make_label(box, Vector2(20.0, 214.0), Vector2(500.0, 30.0), 18, SEAL)
	shout.text = "远远传来一声狠话：「你等着！我这就去请我们老大来！」"
	shout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_return = UiKit.make_button(box, Vector2(60.0, 292.0), Vector2(200.0, 58.0), "回 村", 22)
	_end_return.focus_mode = Control.FOCUS_NONE
	_end_return.pressed.connect(_exit_stage)
	_end_again = UiKit.make_button(box, Vector2(280.0, 292.0), Vector2(200.0, 58.0), "再来一局", 22)
	_end_again.focus_mode = Control.FOCUS_NONE
	_end_again.pressed.connect(_restart_stage)


# ============================================================
# 开场 / 重开 / 退出
# ============================================================

func open() -> void:
	visible = true
	set_process(true)
	Audio.play_bgm("bgm_battle", 0.6)


func _restart_stage() -> void:
	_end_ov.visible = false
	_pause_ov.visible = false
	_finished = false
	if _skill_btn != null:
		_skill_btn.visible = false
	if _ult_btn != null:
		_ult_btn.visible = false
	_paused = false
	_wave = 0
	_wave_wait = -1.0
	_dodge_taught = false
	_counter_guided = false
	_mage_banner_done = false
	_guide_enemy = null
	_wave5_fight = false
	_wave5_crisis_done = false
	_wave5_t = 0.0
	loot_silver = 0
	_hp_guide_done = false
	_hero_hp = HERO_HP_MAX
	_hero_rage = 0.0
	_hero_atk_t = 0.4
	_hero_skill_cd = 0.0
	_hero_flash = 0.0
	_flash_t = 0.0
	_shake_t = 0.0
	_shake_off = Vector2.ZERO
	_zoom = 1.0
	_pivot = Vector2.ZERO
	_ult_cine = -1.0
	_action_which = ""
	_tip_which = ""
	_tip_until_ms = 0
	_break_cine = -1.0
	_break_burst = false
	_ult_banner = false
	_ult_foes.clear()
	if _log_lb != null:
		_log_lb.text = ""
	if _ult_lb != null:
		_ult_lb.visible = false
		_ult_lb.scale = Vector2.ONE
	_actors.scale = Vector2.ONE
	_actors.position = Vector2.ZERO
	_fx.scale = Vector2.ONE
	_fx.pivot_offset = Vector2.ZERO
	_fx.position = Vector2.ZERO
	_hero_pos = HERO_HOME
	_hero_target = HERO_HOME
	_manual_move = false
	_telegraphs.clear()
	_floats.clear()
	_fx_list.clear()
	for e in _enemies:
		if is_instance_valid(e["node"]):
			e["node"].queue_free()
	_enemies.clear()
	if is_instance_valid(_hero):
		_hero.queue_free()
	_hero = _make_token("player", true, 176.0, GOLD, 1.0)
	_hero.position = _hero_pos
	_actors.add_child(_hero)
	_hero.face(1)
	_guide_on = false
	_guide_text = ""
	_guide_layer.queue_redraw()
	_start_wave(1)


func _exit_stage() -> void:
	_end_ov.visible = false
	_pause_ov.visible = false
	visible = false
	set_process(false)
	Audio.play_bgm(Audio.menu_track(), 1.0)
	closed.emit()


# ============================================================
# 波次
# ============================================================

func _start_wave(n: int) -> void:
	_wave = n
	_wave_wait = -1.0
	_telegraphs.clear()   # 上一波没落完的红圈不要带进下一波
	for d in _decor:
		if is_instance_valid(d):
			d.queue_free()
	_decor.clear()
	if n == 1:
		# 第一波·剧情：村长与主角相遇（不刷怪）
		var chief = _make_token("mob_chief", false, 150.0, Color(0.36, 0.30, 0.24), 1.0)
		chief.position = Vector2(500.0, 600.0)
		_decor.append(chief)
		_actors.add_child(chief)
		_dialogue([
			{"who": "村长", "text": "孩子，山路不太平，你当真要走？"},
			{"who": "主角", "text": "嗯。总不能一辈子守在村口。", "art": "player"},
			{"who": "村长", "text": "去吧。记住——遇事别慌，剑在手里。"},
		], func() -> void:
			_start_wave(2)
		)
	elif n == 2:
		# 第二波·怪物偷袭（无延迟技能，只靠近+普攻）
		var m := _spawn_enemy("mage", Vector2(520.0, 580.0), 90.0, 10.0, 90.0)
		m["cast_t"] = -1.0
		_skill_btn.visible = false
		_hero_skill_cd = 0.0
		_dialogue([
			{"who": "旁白", "text": "一步踏出村口，风里忽然多了一股腥气。"},
			{"who": "引导", "text": "小心——有东西扑上来了。"},
		], func() -> void:
			_guide("当心。", Rect2(18.0, 14.0, 240.0, 52.0), "tap", Callable(), "wave")
		)
	elif n == 3:
		# 第三波·回血怪：打得动但回得比掉血快 → 解锁绝学
		var g := _spawn_enemy("brute", Vector2(360.0, 580.0), 180.0, 16.0, 100.0)
		g["atk_t"] = 0.2
		g["regen"] = 0.12
		_skill_btn.visible = false
		_hero_skill_cd = 0.0
		_dialogue([
			{"who": "旁白", "text": "这一只不一样——伤口才裂开，转眼又合上了。"},
			{"who": "引导", "text": "寻常招式伤不了它——用绝学！"},
		], func() -> void:
			_hero_rage = 100.0
			_ult_btn.visible = true
			_guide("落日剑诀。", _ult_btn.get_global_rect(), "ult")
		)

	elif n == 4:
		_spawn_enemy("elite", Vector2(360.0, 580.0), 200.0, 16.0, 100.0)
		_hero_skill_cd = 0.0
		_skill_btn.visible = true
		_ult_btn.visible = false
		_dialogue([
			{"who": "旁白", "text": "血还在滴。你退了一步，脚下踩到半截断刀。"},
			{"who": "旁白", "text": "独臂刀客却不急。他横刀而立，像在看一件死物。"},
			{"who": "主角", "text": "……剑谱上那一式。", "art": "player"},
			{"who": "旁白", "text": "你想起那本旧书。第一页只有四个字——"},
			{"who": "旁白", "text": "「落日，断流。」"},
		], func() -> void:
			_guide("「落日，断流。」", _skill_btn.get_global_rect(), "skill")
		)
	elif n == 5:
		# 血厚到打不死：先让玩家砍一会儿，再进绝境
		# 血够厚：正常打到残血触发剧情时，谁也碰不到 1 点锁血线
		_spawn_enemy("boss", Vector2(360.0, 540.0), 1600.0, 24.0, 95.0)
		_spawn_enemy("minion", Vector2(250.0, 640.0), 800.0, 10.0, 115.0)
		_spawn_enemy("minion", Vector2(470.0, 640.0), 800.0, 10.0, 115.0)
		_spawn_enemy("minion", Vector2(360.0, 680.0), 800.0, 10.0, 115.0)
		for e in _enemies:
			e["no_kill"] = true
		_hero_hp = HERO_HP_MAX
		_hero_rage = 0.0
		_skill_btn.visible = true
		_ult_btn.visible = false
		_wave5_fight = false
		_wave5_crisis_done = false
		_wave5_t = 0.0
		_dialogue([
			{"who": "旁白", "text": "独臂刀客倒下的时候，巷子深处才传来脚步声。"},
			{"who": "旁白", "text": "不快。一步一步，像踩在你心口上。"},
			{"who": "匪首", "text": "小子，手底下倒有几分本事。"},
			{"who": "旁白", "text": "他身后，又慢慢走出三个人。"},
			{"who": "匪首", "text": "可惜，到此为止了。"},
			{"who": "旁白", "text": "你没有答话。你握紧了剑，迎了上去。"},
		], func() -> void:
			_wave5_fight = true
			_wave5_t = 0.0
		)


func _spawn_enemy(kind: String, pos: Vector2, hp: float, atk: float, speed: float) -> Dictionary:
	var role := "mob_lou"
	var height := 128.0
	if kind == "mage":
		role = "mob_lou"
		height = 132.0
	elif kind == "brute":
		role = "mob_chief"
		height = 160.0
	elif kind == "elite":
		role = "mob_one_arm"
		height = 150.0
	elif kind == "boss":
		role = "mob_chief"
		height = 176.0
	var nm := "匪徒"
	match kind:
		"mage":
			nm = "村匪"
		"grunt":
			nm = "村匪"
		"brute":
			nm = "壮汉"
		"elite":
			nm = "独臂刀客"
		"boss":
			nm = "匪首"
	var ring := Color(0.78, 0.20, 0.14) if kind == "boss" else Color(0.58, 0.26, 0.18)
	var a = _make_token(role, false, height, ring, 1.0)
	a.position = pos
	a.show_bar = true
	a.unit_name = nm
	a.bar_w = maxf(70.0, a.radius * 1.35)
	a.hp_ratio = 1.0
	a.name_col = Color(0.86, 0.70, 0.30) if kind == "boss" else Color(0.18, 0.15, 0.12, 0.85)
	_actors.add_child(a)
	var e := {
		"node": a, "pos": pos, "hp": hp, "max": hp, "atk": atk,
		"speed": speed, "kind": kind, "name": nm,
		"atk_t": 0.9, "cast_t": 1.6, "dead": false,
	}
	_enemies.append(e)
	return e


func _spawn_decor(pos: Vector2, height: float, alpha: float) -> void:
	var a = _make_token("mob_lou", false, height, Color(0.55, 0.40, 0.28), alpha)
	a.position = pos
	_actors.add_child(a)
	_decor.append(a)


func _make_token(role: String, use_face: bool, height: float, ring: Color, alpha: float) -> Node2D:
	var t = TokenActor.new()
	t.set_role(role)
	t.weapon_type = "sword"
	t.fit_height = height
	var tex: Texture2D = CharArt.face(role) if use_face else CharArt.q(role)
	t.setup(tex, maxf(26.0, height * 0.38), ring, not use_face)
	t.modulate = Color(1.0, 1.0, 1.0, alpha)
	return t


func _enemy_rect(e: Dictionary) -> Rect2:
	var p: Vector2 = e["pos"]
	return Rect2(p - Vector2(58.0, 120.0), Vector2(116.0, 140.0))


func _check_clear() -> void:
	if _finished or _wave_wait >= 0.0 or _break_cine >= 0.0:
		return
	if not _enemies.is_empty():
		return
	if _wave >= _wave_max:
		_finish(true)
	else:
		_wave_wait = 1.0


func _update_wave(delta: float) -> void:
	if _wave_wait < 0.0:
		return
	_wave_wait -= delta
	if _wave_wait <= 0.0:
		_wave_wait = -1.0
		_start_wave(_wave + 1)


# ============================================================
# 每帧
# ============================================================

func _process(delta: float) -> void:
	_t += delta
	_guide_t += delta
	var now_ms := Time.get_ticks_msec()
	if _action_which != "" and _tip_which != _action_which and now_ms - _action_down_ms >= 360:
		_tip_which = _action_which
	if _tip_which != "" and _action_which == "" and now_ms > _tip_until_ms:
		_tip_which = ""
	_update_buttons()
	_update_glow()
	_update_fx(delta)
	_update_floats(delta)
	_flash_t = maxf(0.0, _flash_t - delta)
	_shake_off = Vector2.ZERO
	if _shake_t > 0.0:
		_shake_t = maxf(0.0, _shake_t - delta)
		var amp := 10.0 * (_shake_t / 0.45)
		_shake_off = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	_bg.queue_redraw()
	_hud.queue_redraw()
	_fx.queue_redraw()
	_guide_layer.queue_redraw()
	if _ult_cine >= 0.0:
		_update_ult_cine(delta)
	if _break_cine >= 0.0:
		_update_break_cine(delta)
	_apply_field_transform()
	if _paused or _finished:
		return
	_hero_flash = maxf(0.0, _hero_flash - delta)
	_update_hero(delta)
	_update_enemies(delta)
	_update_telegraphs(delta)
	_update_wave(delta)
	if _wave == 5 and _wave5_fight and not _wave5_crisis_done:
		_wave5_t += delta
		# 残血才触发；14 秒只是防玩家一直绕圈的兜底
		if _hero_hp <= HERO_HP_MAX * 0.18 or _wave5_t >= 14.0:
			_wave5_crisis()
	# 功法·落日剑法：自动释放（冷却好、场上有怪就放；绝学仍是点击）
	if _hero_skill_cd <= 0.0 and not _nearest_enemy().is_empty():
		_cast_skill()


func _update_hero(delta: float) -> void:
	_hero_skill_cd = maxf(0.0, _hero_skill_cd - delta)
	_hero_atk_t = maxf(0.0, _hero_atk_t - delta)

	# 玩家点了地面：先走到点，到了再自动打（躲闪用）
	if _manual_move:
		if _hero_target.distance_to(_hero_pos) > 8.0:
			var d := _hero_target - _hero_pos
			_hero_pos += d.normalized() * HERO_SPEED * delta
			_hero_pos.x = clampf(_hero_pos.x, FIELD_MIN.x, FIELD_MAX.x)
			_hero_pos.y = clampf(_hero_pos.y, FIELD_MIN.y, FIELD_MAX.y)
			_hero.position = _hero_pos
			_face_dir(d.x)
			return
		_manual_move = false
		_hero_target = _hero_pos

	var target := _nearest_enemy()
	if target.is_empty():
		return
	var tp: Vector2 = target["pos"]
	var dx := tp.x - _hero_pos.x
	var dist := _hero_pos.distance_to(tp)
	# 已经在出手距离内：站定自动打，不再追着走
	if dist <= HERO_RANGE:
		_hero_target = _hero_pos
		_face_dir(dx)
		if _hero_atk_t <= 0.0:
			_hero_atk_t = HERO_ATK_CD
			_hero.play_move("chop", 1.5)
			var hdmg := HERO_ATK * randf_range(0.9, 1.1)
			var hkind := "phys"
			if randf() < 0.15:
				hdmg *= 1.8
				hkind = "crit"
			_damage_enemy(target, hdmg, hkind)
			if is_instance_valid(target["node"]):
				target["node"].play_hit()
			_fx_list.append({"kind": "hit", "pos": tp + Vector2(0.0, -60.0), "t": 0.0, "total": 0.2})
			_shake_t = maxf(_shake_t, 0.08)
			Audio.sfx("hit_slash", -13.0)
			_hero_rage = minf(100.0, _hero_rage + 7.0)
		return
	# 不在距离内：自动靠近
	_face_dir(dx)
	_hero_pos += (tp - _hero_pos).normalized() * HERO_SPEED * delta
	_hero_pos.x = clampf(_hero_pos.x, FIELD_MIN.x, FIELD_MAX.x)
	_hero_pos.y = clampf(_hero_pos.y, FIELD_MIN.y, FIELD_MAX.y)
	_hero.position = _hero_pos


func _face_dir(dx: float) -> void:
	if absf(dx) < 12.0:
		return
	var d := 1 if dx >= 0.0 else -1
	if d != _hero_dir:
		_hero_dir = d
		if is_instance_valid(_hero):
			_hero.face(d)


func _update_enemies(delta: float) -> void:
	for e in _enemies.duplicate():
		if bool(e["dead"]):
			continue
		var pos: Vector2 = e["pos"]
		var to_hero := _hero_pos - pos
		var dist := to_hero.length()
		if str(e["kind"]) == "mage":
			if dist < 235.0:
				pos -= to_hero.normalized() * float(e["speed"]) * delta
			elif dist > 320.0:
				pos += to_hero.normalized() * float(e["speed"]) * delta
			e["cast_t"] = float(e["cast_t"]) - delta
			if float(e["cast_t"]) <= 0.0:
				e["cast_t"] = 4.2
				_mage_cast(e)
		else:
			if dist > 118.0:
				pos += to_hero.normalized() * float(e["speed"]) * delta
			else:
				e["atk_t"] = float(e["atk_t"]) - delta
				if float(e["atk_t"]) <= 0.0:
					e["atk_t"] = 1.15
					if is_instance_valid(e["node"]):
						e["node"].play_move("chop", 1.4)
					if not bool(e.get("banner_done", false)):
						e["banner_done"] = true
						match str(e["kind"]):
							"brute":
								_move_banner("『力劈华山』", Color(0.58, 0.22, 0.16))
							"elite":
								_move_banner("『独臂刀』", Color(0.55, 0.20, 0.14))
							"boss":
								_move_banner("『黑风刀』", Color(0.50, 0.16, 0.12))
					var hk := "phys"
					if str(e["kind"]) == "brute" or str(e["kind"]) == "boss":
						hk = "heavy"
					_damage_hero(float(e["atk"]), hk, e)
		pos.x = clampf(pos.x, 80.0, 640.0)
		pos.y = clampf(pos.y, 620.0, 900.0)
		e["pos"] = pos
		if is_instance_valid(e["node"]):
			e["node"].position = pos
			var dx := _hero_pos.x - pos.x
			if absf(dx) > 6.0:
				e["node"].face(1 if dx >= 0.0 else -1)


func _mage_cast(e: Dictionary) -> void:
	if not _mage_banner_done:
		_mage_banner_done = true
		_move_banner("『飞蝗石』", Color(0.58, 0.22, 0.16))
	var center: Vector2 = _hero_pos
	var from_pos: Vector2 = e["pos"]
	_telegraphs.append({
		"pos": center, "r": 96.0, "t": 0.0, "total": 1.15,
		"dmg": 24.0, "from": from_pos, "src": e,
	})


func _update_telegraphs(delta: float) -> void:
	for t in _telegraphs.duplicate():
		t["t"] = float(t["t"]) + delta
		if float(t["t"]) >= float(t["total"]):
			var p: Vector2 = t["pos"]
			if _hero_pos.distance_to(p) <= float(t["r"]):
				_damage_hero(float(t["dmg"]), "phys", t.get("src"))
			_fx_list.append({"kind": "burst", "pos": p, "t": 0.0, "total": 0.45})
			Audio.sfx("hit_heavy", -7.0, 0.9)
			_telegraphs.erase(t)
			if _wave == 1 and _dodge_taught and not _counter_guided and not _enemies.is_empty():
				_counter_guided = true
				_dialogue([
					{"who": "旁白", "text": "寒光擦着耳边过去，钉进身后的土里。"},
					{"who": "旁白", "text": "方士手腕一翻，还想再摸第二枚。"},
					{"who": "主角", "text": "……就是现在。", "art": "player"},
				], func() -> void:
					_guide_target_enemy()
				)


func _nearest_enemy() -> Dictionary:
	var best := {}
	var best_d := 99999.0
	for e in _enemies:
		if bool(e["dead"]):
			continue
		var d := _hero_pos.distance_to(e["pos"] as Vector2)
		if d < best_d:
			best_d = d
			best = e
	return best


# ============================================================
# 伤害
# ============================================================

func _update_fx(delta: float) -> void:
	for f in _fx_list.duplicate():
		f["t"] = float(f["t"]) + delta
		if float(f["t"]) >= float(f["total"]):
			_fx_list.erase(f)


func _update_floats(delta: float) -> void:
	for f in _floats.duplicate():
		f["t"] = float(f["t"]) + delta
		f["pos"] = (f["pos"] as Vector2) + Vector2(0.0, -46.0 * delta)
		if float(f["t"]) >= float(f["total"]):
			_floats.erase(f)


func _damage_hero(dmg: float, kind: String = "phys", src = null) -> void:
	if _finished:
		return
	_hero_hp = maxf(1.0, _hero_hp - dmg)
	_hero_flash = 0.25
	if is_instance_valid(_hero):
		_hero.play_hit()
	_fx_list.append({"kind": "hit", "pos": _hero_pos + Vector2(0.0, -70.0), "t": 0.0, "total": 0.2})
	_shake_t = maxf(_shake_t, 0.10)
	Audio.sfx("hit_heavy", -11.0)
	_hero_rage = minf(100.0, _hero_rage + 4.0)
	var dcol := DMG_PHYS
	var dsize := 30
	var tag := "物理 "
	match kind:
		"heavy":
			dsize = 36
			tag = "物理 "
		"elem":
			dcol = DMG_ELEM
			dsize = 34
			tag = "元素 "
		"crit":
			dcol = DMG_CRIT
			dsize = 40
			tag = "暴击 "
		_:
			dcol = DMG_PHYS
			dsize = 30
			tag = "物理 "
	_floats.append({"pos": _hero_pos + Vector2(0.0, -150.0), "text": tag + "-" + str(int(dmg)), "t": 0.0, "total": 0.9, "col": dcol, "size": dsize})
	# 护体反震：谁打的，回敬 2 点反伤
	if src != null and is_instance_valid(src.get("node")) and not bool(src.get("dead", false)):
		_damage_enemy(src, 2.0, "reflect")
	if _wave == 3:
		_fx_list.append({"kind": "slash", "pos": _hero_pos + Vector2(0.0, -90.0), "t": 0.0, "total": 0.35})
		if not _hp_guide_done:
			_hp_guide_done = true
			await get_tree().create_timer(0.25).timeout
			if not is_inside_tree():
				return
			_dialogue([
				{"who": "旁白", "text": "没等你喘口气，一个肌肉壮汉已经欺到身前。"},
				{"who": "旁白", "text": "一刀劈下，你躲闪不及，只来得及微微侧身。"},
				{"who": "旁白", "text": "手臂上多了一道深深的血痕。"},
			], func() -> void:
				_guide("血，顺着手臂滴下来。", Rect2(18.0, 68.0, 352.0, 50.0), "tap", Callable(), "hp")
			)


func _damage_enemy(e: Dictionary, dmg: float, kind: String = "phys") -> void:
	if bool(e["dead"]):
		return
	e["hp"] = float(e["hp"]) - dmg
	# 剧情怪：血可以掉到见底，但这一场不许死
	if bool(e.get("no_kill", false)) and float(e["hp"]) <= 0.0:
		e["hp"] = 1.0
	if is_instance_valid(e["node"]):
		e["node"].hp_ratio = clampf(float(e["hp"]) / maxf(1.0, float(e["max"])), 0.0, 1.0)
		e["node"].queue_redraw()
	var p: Vector2 = e["pos"]
	var tr := 50.0
	if is_instance_valid(e["node"]):
		tr = float(e["node"].radius)
	var dcol := DMG_PHYS
	var dsize := 30
	var tag := "物理 "
	match kind:
		"phys_big":
			dcol = DMG_PHYS
			dsize = 34
			tag = "物理 "
		"phys_huge":
			dcol = DMG_PHYS
			dsize = 40
			tag = "物理 "
		"elem":
			dcol = DMG_ELEM
			dsize = 34
			tag = "元素 "
		"elem_big":
			dcol = DMG_ELEM
			dsize = 40
			tag = "元素 "
		"crit":
			dcol = DMG_CRIT
			dsize = 40
			tag = "暴击 "
		"reflect":
			dcol = DMG_REFLECT
			dsize = 30
			tag = "反伤 "
		_:
			dcol = DMG_PHYS
			dsize = 30
			tag = "物理 "
	_floats.append({"pos": p + Vector2(0.0, -tr * 2.0 - 34.0), "text": tag + str(int(dmg)), "t": 0.0, "total": 0.8, "col": dcol, "size": dsize})
	_fx_list.append({"kind": "hit", "pos": p + Vector2(0.0, -60.0), "t": 0.0, "total": 0.25})
	if float(e["hp"]) <= 0.0:
		e["dead"] = true
		if is_instance_valid(e["node"]):
			e["node"].play_down()
		# 击杀回气：恢复 4 点气血
		var before := _hero_hp
		_hero_hp = minf(HERO_HP_MAX, _hero_hp + 4.0)
		var got := _hero_hp - before
		if got > 0.5:
			_floats.append({"pos": _hero_pos + Vector2(0.0, -160.0), "text": "恢复 +" + str(int(got)), "t": 0.0, "total": 0.9, "col": DMG_HEAL, "size": 32})
		Audio.sfx("fall_down", -10.0)
		var node: Node = e["node"]
		await get_tree().create_timer(1.15).timeout
		if is_instance_valid(node):
			node.queue_free()
		_enemies.erase(e)
		_check_clear()


func _cast_skill() -> void:
	if _finished:
		return
	if _paused and not (_guide_on and _guide_mode == "skill"):
		return
	if _hero_skill_cd > 0.0:
		return
	var target := _nearest_enemy()
	if target.is_empty():
		return
	_hero_skill_cd = SKILL_CD
	if is_instance_valid(_hero):
		_hero.play_move("stab", 1.3)
	Audio.sfx("skill", -7.0)
	var from := _hero_pos + Vector2(0.0, -70.0)
	var to: Vector2 = (target["pos"] as Vector2) + Vector2(0.0, -60.0)
	_fx_list.append({"kind": "sword_light", "from": from, "to": to, "t": 0.0, "total": 0.36})
	_fx_list.append({"kind": "burst", "pos": to, "t": 0.0, "total": 0.35})
	_flash_t = 0.22
	_shake_t = 0.18
	if is_instance_valid(target["node"]):
		target["node"].play_hit()
	var sdmg := HERO_ATK * SKILL_MULT
	_damage_enemy(target, sdmg, "phys_big")
	_log_action("少侠 落日·断流 → " + _enemy_name(target) + " −" + str(int(sdmg)))
	_move_banner("『落日剑法』", SEAL)
	if _guide_on and _guide_mode == "skill":
		_end_guide()


func _cast_ult() -> void:
	if _finished:
		return
	if _paused and not (_guide_on and _guide_mode == "ult"):
		return
	if _guide_on and _guide_mode != "ult":
		return
	if _hero_rage < 100.0:
		return
	_hero_rage = 0.0
	if is_instance_valid(_hero):
		_hero.play_move("sweep", 1.2)
	Audio.sfx("skill", -5.0)
	if _guide_on and _guide_mode == "ult":
		_end_guide()
	_start_ult_cine()


func _wave5_crisis() -> void:
	_wave5_crisis_done = true
	_wave5_fight = false
	_hero_rage = 100.0
	_hero_hp = maxf(1.0, HERO_HP_MAX * 0.08)
	_skill_btn.visible = true
	_ult_btn.visible = true
	# 把四个人摆到主角四周：围住，但不叠在一起
	_hero_pos = Vector2(360.0, 780.0)
	_hero_target = _hero_pos
	_manual_move = false
	if is_instance_valid(_hero):
		_hero.position = _hero_pos
	var spots := [
		Vector2(360.0, 520.0), Vector2(180.0, 660.0),
		Vector2(540.0, 660.0), Vector2(500.0, 860.0),
	]
	for i in _enemies.size():
		var e: Dictionary = _enemies[i]
		if i < spots.size():
			e["pos"] = spots[i]
			if is_instance_valid(e["node"]):
				e["node"].position = spots[i]
		# 血条压到三成多——明显挨过打，但一个都不许死
		e["hp"] = minf(float(e["hp"]), float(e["max"]) * 0.38)
		if is_instance_valid(e["node"]):
			e["node"].hp_ratio = clampf(float(e["hp"]) / maxf(1.0, float(e["max"])), 0.0, 1.0)
			e["node"].queue_redraw()
	_dialogue([
		{"who": "匪首", "text": "小子，今天就是你的死期。"},
		{"who": "旁白", "text": "刀光压下来。你心头一震，满是不甘。"},
		{"who": "主角", "text": "……我还没走完这条路。", "art": "player"},
		{"who": "旁白", "text": "不甘心。就这么死在巷子里，你不甘心。"},
		{"who": "旁白", "text": "胸口那口气，忽然烧了起来。"},
	], func() -> void:
		_guide("到时候了。", _ult_btn.get_global_rect(), "ult")
	)


func _start_ult_cine() -> void:
	# 演出开始，解除"不许死"——这一剑才收得掉四条命
	for e in _enemies:
		e["no_kill"] = false
	_ult_cine = 0.0
	_ult_banner = false
	_ult_foes = _enemies.duplicate()
	_paused = true
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.z_index = 20
	add_child(ov)
	_ult_ov = ov
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.0)
	ov.add_child(dim)
	_ult_dim = dim
	var art := TextureRect.new()
	art.position = Vector2(90.0, 300.0)
	art.size = Vector2(540.0, 460.0)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/art/skills/sun_sword_ult.jpg"):
		art.texture = load("res://assets/art/skills/sun_sword_ult.jpg")
	art.modulate = Color(1, 1, 1, 0)
	ov.add_child(art)
	_ult_art = art
	_log_action("少侠 落日剑诀 → 四人 −" + str(int(HERO_ATK * ULT_MULT)))
	_ult_lb.visible = true
	_ult_lb.modulate = Color(1, 1, 1, 0)
	_ult_lb.scale = Vector2(0.72, 0.72)


func _update_ult_cine(delta: float) -> void:
	_ult_cine += delta
	var t := _ult_cine
	var pivot := _hero_pos + Vector2(0.0, -70.0)
	var z := 1.0
	if t < 0.35:
		z = lerpf(1.0, 1.55, t / 0.35)
	elif t < 0.75:
		z = 1.55
	elif t < 1.0:
		z = lerpf(1.55, 1.0, (t - 0.75) / 0.25)
	_zoom = z
	_pivot = pivot
	var ta := 0.0
	if t > 0.12 and t < 0.72:
		ta = clampf((t - 0.12) / 0.15, 0.0, 1.0) * (1.0 - clampf((t - 0.55) / 0.17, 0.0, 1.0))
	_ult_lb.visible = ta > 0.01
	_ult_lb.modulate = Color(1, 1, 1, ta)
	var ts := 0.72 + 0.42 * clampf((t - 0.12) / 0.35, 0.0, 1.0)
	_ult_lb.scale = Vector2(ts, ts)
	if _ult_dim != null:
		_ult_dim.color.a = clampf((t - 0.10) / 0.25, 0.0, 0.55)
	if _ult_art != null:
		_ult_art.modulate.a = clampf((t - 0.18) / 0.30, 0.0, 1.0) * (1.0 - clampf((t - 1.55) / 0.25, 0.0, 1.0))
	if t >= 1.0:
		if not _ult_banner:
			_ult_banner = true
			_move_banner("『落日剑诀』", SEAL)
		for i in _ult_foes.size():
			var e: Dictionary = _ult_foes[i]
			if e == null or not is_instance_valid(e.get("node")):
				continue
			var delay := 0.07 * float(i)
			var kk := clampf((t - 1.0 - delay) / 0.38, 0.0, 1.0)
			if kk >= 1.0 and not bool(e.get("ult_hit", false)):
				e["ult_hit"] = true
				if is_instance_valid(e["node"]):
					e["node"].play_hit()
				_damage_enemy(e, ULT_DAMAGE, "phys_huge")
				_fx_list.append({"kind": "burst", "pos": (e["pos"] as Vector2) + Vector2(0.0, -60.0), "t": 0.0, "total": 0.5})
				_flash_t = maxf(_flash_t, 0.3)
				_shake_t = maxf(_shake_t, 0.4)
				Audio.sfx("hit_heavy", -8.0)
	if t >= 1.95:
		_ult_cine = -1.0
		_ult_lb.visible = false
		if _ult_ov != null:
			_ult_ov.queue_free()
			_ult_ov = null
			_ult_dim = null
			_ult_art = null
		_zoom = 1.0
		_pivot = Vector2.ZERO
		_apply_field_transform()
		_start_break_cine()


func _start_break_cine() -> void:
	_break_cine = 0.0
	_break_burst = false
	_paused = true
	# 断剑是独角戏：把还没收完的尸体和战斗按钮都收掉
	for e in _enemies.duplicate():
		if is_instance_valid(e["node"]):
			e["node"].queue_free()
	_enemies.clear()
	if _skill_btn != null:
		_skill_btn.visible = false
	if _ult_btn != null:
		_ult_btn.visible = false


func _update_break_cine(delta: float) -> void:
	_break_cine += delta
	var t := _break_cine
	if not _break_burst and t >= 1.55:
		_break_burst = true
		_flash_t = maxf(_flash_t, 0.40)
		_shake_t = maxf(_shake_t, 0.55)
		Audio.sfx("hit_heavy", -6.0, 0.62)
	if t >= 3.3:
		_break_cine = -1.0
		_paused = false
		_finish(true)


func _apply_field_transform() -> void:
	if _zoom > 1.0001:
		_actors.scale = Vector2(_zoom, _zoom)
		_actors.position = _pivot - _pivot * _zoom + _shake_off
		_fx.scale = Vector2(_zoom, _zoom)
		_fx.pivot_offset = _pivot
		_fx.position = _shake_off
	else:
		_actors.scale = Vector2.ONE
		_actors.position = _shake_off
		_fx.scale = Vector2.ONE
		_fx.pivot_offset = Vector2.ZERO
		_fx.position = _shake_off


# ============================================================
# 引导
# ============================================================

func _move_banner(txt: String, col: Color) -> void:
	if txt == "":
		return
	var lb := UiKit.make_label(self, Vector2(60.0, 452.0), Vector2(600.0, 64.0), 36, col)
	lb.text = txt
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_override("font", UI_FONT)
	lb.add_theme_constant_override("outline_size", 7)
	lb.add_theme_color_override("font_outline_color", Color(0.16, 0.05, 0.03, 0.78))
	lb.z_index = 11
	lb.modulate.a = 0.0
	lb.scale = Vector2(1.08, 1.08)
	lb.pivot_offset = Vector2(300.0, 32.0)
	var tw := create_tween()
	tw.tween_property(lb, "modulate:a", 1.0, 0.10)
	tw.parallel().tween_property(lb, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.75)
	tw.tween_property(lb, "modulate:a", 0.0, 0.28)
	tw.finished.connect(lb.queue_free)


func _log_action(txt: String) -> void:
	if _log_lb != null:
		_log_lb.text = txt


func _enemy_name(e: Dictionary) -> String:
	return str(e.get("name", "匪徒"))


func _guide_target_enemy() -> void:
	if _enemies.is_empty():
		return
	var e: Dictionary = _enemies[0]
	if bool(e.get("dead", false)):
		return
	_guide_enemy = e
	_guide("追上去。", _enemy_rect(e), "target", Callable(), "enemy")


func _guide(text: String, rect: Rect2, mode: String, cb := Callable(), kind := "") -> void:
	_guide_on = true
	_guide_text = text
	_guide_rect = rect
	_guide_mode = mode
	_guide_kind = kind if kind != "" else mode
	_guide_cb = cb
	_guide_t = 0.0
	_paused = true


func _end_guide() -> void:
	_guide_on = false
	_guide_text = ""
	_guide_mode = "tap"
	_paused = false
	if _guide_cb.is_valid():
		var cb := _guide_cb
		_guide_cb = Callable()
		cb.call()


func _update_glow() -> void:
	# 圆形图标用自己的金边呼吸，不再调按钮本身
	pass


func _update_buttons() -> void:
	# 冷却/怒气由圆形图标自己画
	pass


# ============================================================
# 输入
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if _finished:
		return
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pos = mb.position
			pressed = true
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			pos = st.position
			pressed = true
	if not pressed:
		return
	if _dlg_on:
		_dlg_next()
		return
	if _guide_on:
		if _guide_mode == "tap":
			_end_guide()
		elif _guide_mode == "dodge":
			_hero_target = _clamp_pos(pos)
			_manual_move = true
			_fx_list.append({"kind": "click", "pos": _hero_target, "t": 0.0, "total": 0.35})
			_end_guide()
		elif _guide_mode == "target":
			var e = _guide_enemy
			if e != null and not bool(e.get("dead", false)) and _enemy_rect(e).has_point(pos):
				_hero_target = e["pos"] as Vector2
				_manual_move = false
				_fx_list.append({"kind": "click", "pos": _hero_target, "t": 0.0, "total": 0.35})
				_guide_enemy = null
				_end_guide()
		return
	if _paused:
		return
	_hero_target = _clamp_pos(pos)
	_manual_move = true
	_fx_list.append({"kind": "click", "pos": _hero_target, "t": 0.0, "total": 0.35})


func _clamp_pos(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, FIELD_MIN.x, FIELD_MAX.x), clampf(p.y, FIELD_MIN.y, FIELD_MAX.y))


func _on_action_down(which: String) -> void:
	if _finished:
		return
	_action_which = which
	_action_down_ms = Time.get_ticks_msec()


func _on_action_up(which: String) -> void:
	if _action_which != which:
		return
	var held := Time.get_ticks_msec() - _action_down_ms
	var was_tip := _tip_which == which
	_action_which = ""
	if was_tip or held >= 360:
		_tip_which = which
		_tip_until_ms = Time.get_ticks_msec() + 700
		return
	if which == "skill":
		_cast_skill()
	else:
		_cast_ult()


func _on_pause() -> void:
	if _guide_on or _dlg_on or _finished or _break_cine >= 0.0 or _ult_cine >= 0.0:
		return
	_paused = true
	_pause_ov.visible = true


func _on_resume() -> void:
	_pause_ov.visible = false
	_paused = false


func _finish(win: bool) -> void:
	if _finished:
		return
	_finished = true
	_victory = win
	_paused = true
	loot_silver = 50 if win else 0
	_end_title.text = "清 场" if win else "败"
	# 引子通关：记首趟完成（回主界面后接第二段铁匠）
	if win:
		GameState.first_journey_done = true
		GameState.save_game()
	_end_ov.visible = true
	Audio.sfx("win" if win else "lose", -8.0)


# ============================================================
# 绘制
# ============================================================

func _draw_bg() -> void:
	_bg.draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), PAPER)
	# 远山拉高做大——战斗就在山前
	_bg.draw_colored_polygon(PackedVector2Array([
		Vector2(-40.0, 650.0), Vector2(160.0, 300.0), Vector2(340.0, 650.0),
	]), Color(0.75, 0.76, 0.69, 0.62))
	_bg.draw_colored_polygon(PackedVector2Array([
		Vector2(200.0, 650.0), Vector2(430.0, 220.0), Vector2(680.0, 650.0),
	]), Color(0.67, 0.68, 0.61, 0.52))
	_bg.draw_colored_polygon(PackedVector2Array([
		Vector2(480.0, 650.0), Vector2(660.0, 350.0), Vector2(800.0, 650.0),
	]), Color(0.71, 0.71, 0.64, 0.46))
	# 山脚薄雾
	_bg.draw_rect(Rect2(0.0, 600.0, W, 48.0), Color(0.90, 0.86, 0.76, 0.34))
	# 地面从山脚开始，整块抬上来
	_bg.draw_rect(Rect2(0.0, 640.0, W, 640.0), Color(0.86, 0.82, 0.72))
	_bg.draw_line(Vector2(0.0, 640.0), Vector2(W, 640.0), Color(0.45, 0.38, 0.28, 0.38), 2.0)
	for i in 7:
		var y := 700.0 + float(i) * 88.0
		_bg.draw_line(Vector2(16.0, y), Vector2(704.0, y), Color(0.55, 0.48, 0.36, 0.10), 2.0)
	for i in 6:
		var x := 80.0 + float(i) * 120.0
		_bg.draw_line(Vector2(x, 640.0), Vector2(x, 1280.0), Color(0.55, 0.48, 0.36, 0.06), 2.0)


func _draw_fx() -> void:
	for t in _telegraphs:
		var p: Vector2 = t["pos"]
		var r := float(t["r"])
		var k := clampf(float(t["t"]) / float(t["total"]), 0.0, 1.0)
		_fx.draw_circle(p, r, Color(0.72, 0.16, 0.12, 0.20))
		_fx.draw_arc(p, r, 0.0, TAU, 48, Color(0.95, 0.76, 0.30, 0.92), 3.0, true)
		_fx.draw_arc(p, r * (1.0 - k), 0.0, TAU, 40, Color(0.88, 0.26, 0.16, 0.55), 2.0, true)
		var from: Vector2 = t.get("from", p)
		var orb := from.lerp(p, minf(1.0, k * 1.25))
		_fx.draw_line(from, orb, Color(0.92, 0.92, 0.88, 0.55), 3.0, true)
		_fx.draw_circle(orb, 7.0, Color(0.96, 0.96, 0.90, 0.95))
		_fx.draw_circle(orb, 14.0, Color(0.96, 0.96, 0.90, 0.18))
	for f in _fx_list:
		var k := clampf(float(f["t"]) / float(f["total"]), 0.0, 1.0)
		var p: Vector2 = f.get("pos", Vector2.ZERO)
		match str(f["kind"]):
			"hit":
				_fx.draw_arc(p, 26.0 + 18.0 * k, 0.0, TAU, 20, Color(0.95, 0.85, 0.55, 1.0 - k), 3.0)
			"burst":
				_fx.draw_arc(p, 30.0 + 50.0 * k, 0.0, TAU, 28, Color(0.88, 0.32, 0.16, 1.0 - k), 4.0)
				_fx.draw_circle(p, 18.0 * (1.0 - k), Color(0.95, 0.55, 0.20, 0.6 * (1.0 - k)))
			"ring":
				_fx.draw_arc(_hero_pos, 40.0 + 360.0 * k, 0.0, TAU, 64, Color(0.96, 0.74, 0.28, 1.0 - k), 6.0)
			"click":
				_fx.draw_arc(p, 26.0 * (1.0 - k) + 8.0, 0.0, TAU, 20, Color(0.86, 0.68, 0.26, 0.8 * (1.0 - k)), 2.0)
			"slash":
				_fx.draw_line(p + Vector2(-34.0, -18.0), p + Vector2(34.0, 18.0), Color(0.62, 0.10, 0.08, 1.0 - k), 4.0, true)
			"sword_light":
				var from: Vector2 = f["from"]
				var to: Vector2 = f["to"]
				var al := 1.0 - k
				_fx.draw_line(from, to, Color(0.70, 0.10, 0.08, 0.30 * al), 18.0, true)
				_fx.draw_line(from, to, Color(1.0, 0.72, 0.24, 0.85 * al), 7.0, true)
				_fx.draw_line(from, to, Color(1.0, 0.97, 0.86, 0.95 * al), 2.0, true)
				var head := from.lerp(to, minf(1.0, k * 1.6))
				_fx.draw_circle(head, 20.0 * (1.0 - k) + 6.0, Color(1.0, 0.86, 0.50, 0.75 * al))
				for i in 6:
					var pp := from.lerp(to, (float(i) + 1.0) / 7.0)
					_fx.draw_circle(pp + Vector2(sin(k * 9.0 + float(i)) * 12.0, cos(float(i)) * 8.0), 3.0, Color(1.0, 0.78, 0.40, 0.5 * al))
			"sun":
				var sp: Vector2 = f["pos"]
				var rr := 40.0 + 180.0 * k
				_fx.draw_circle(sp, rr, Color(0.82, 0.20, 0.08, 0.10 * (1.0 - k)))
				_fx.draw_circle(sp, rr * 0.72, Color(1.0, 0.52, 0.14, 0.16 * (1.0 - k)))
				_fx.draw_arc(sp, rr, 0.0, TAU, 64, Color(1.0, 0.78, 0.30, 0.9 * (1.0 - k)), 4.0, true)
				for i in 14:
					var ang := float(i) * TAU / 14.0 + k * 1.4
					var inner := sp + Vector2(cos(ang), sin(ang)) * rr * 0.5
					var outer2 := sp + Vector2(cos(ang), sin(ang)) * rr * 0.95
					_fx.draw_line(inner, outer2, Color(1.0, 0.70, 0.24, 0.42 * (1.0 - k)), 3.0, true)
	if _ult_cine >= 1.0:
		for i in _ult_foes.size():
			var e: Dictionary = _ult_foes[i]
			if e == null or not is_instance_valid(e.get("node")):
				continue
			var delay := 0.07 * float(i)
			var kk := clampf((_ult_cine - 1.0 - delay) / 0.38, 0.0, 1.0)
			if kk <= 0.0:
				continue
			var target := (e["pos"] as Vector2) + Vector2(0.0, -60.0)
			var sword_pos := Vector2(target.x, lerpf(-260.0, target.y, kk * kk))
			if kk >= 1.0:
				sword_pos = target
			var fade := 1.0
			if _ult_cine > 1.78:
				fade = clampf(1.0 - (_ult_cine - 1.78) / 0.2, 0.0, 1.0)
			_draw_sword(sword_pos, fade)
	if _flash_t > 0.0:
		var fa := clampf(_flash_t / 0.5, 0.0, 1.0) * 0.38
		_fx.draw_rect(Rect2(0.0, 0.0, W, H), Color(1.0, 0.92, 0.72, fa))
	for fl in _floats:
		var a := 1.0 - clampf(float(fl["t"]) / float(fl["total"]), 0.0, 1.0)
		var col: Color = fl["col"]
		col.a = a
		var fp: Vector2 = fl["pos"]
		var fs := int(fl.get("size", 24))
		var ftxt := str(fl["text"])
		_fx.draw_string(UI_FONT, fp + Vector2(1.6, 1.8), ftxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.10, 0.08, 0.06, 0.50 * a))
		_fx.draw_string(UI_FONT, fp + Vector2(-1.0, -1.2), ftxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.98, 0.90, 0.55 * a))
		_fx.draw_string(UI_FONT, fp, ftxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if _break_cine >= 0.0:
		_draw_break(_break_cine)


func _draw_hud() -> void:
	var wave_txt := "波 " + str(_wave) + "/" + str(_wave_max)
	var wave_col := INK
	if _guide_on and _guide_kind == "wave":
		var wk := 0.5 + 0.5 * sin(_guide_t * 9.0)
		wave_col = INK.lerp(Color(1.0, 0.80, 0.30), 0.45 + 0.55 * wk)
		for off in [Vector2(-2.0, 0.0), Vector2(2.0, 0.0), Vector2(0.0, -2.0), Vector2(0.0, 2.0)]:
			_hud.draw_string(UI_FONT, Vector2(22.0, 46.0) + off, wave_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.78, 0.28, 0.16 + 0.26 * wk))
	_hud.draw_string(UI_FONT, Vector2(22.0, 46.0), wave_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, wave_col)
	# 气血
	var hr := Rect2(22.0, 74.0, 340.0, 34.0)
	_hud.draw_rect(hr, Color(0.25, 0.22, 0.18, 0.30))
	var ratio := clampf(_hero_hp / HERO_HP_MAX, 0.0, 1.0)
	_hud.draw_rect(Rect2(hr.position, Vector2(hr.size.x * ratio, hr.size.y)), Color(0.62, 0.16, 0.12))
	_hud.draw_rect(Rect2(hr.position, Vector2(hr.size.x * ratio, 4.0)), Color(1.0, 0.72, 0.55, 0.22))
	_hud.draw_rect(hr, Color(0.28, 0.22, 0.16, 0.78), false, 2.0)
	_hud.draw_string(UI_FONT, Vector2(30.0, 98.0), str(int(_hero_hp)) + " / " + str(int(HERO_HP_MAX)), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.97, 0.94, 0.86))
	# 怒气
	var rr := Rect2(22.0, 114.0, 340.0, 12.0)
	_hud.draw_rect(rr, Color(0.25, 0.22, 0.18, 0.25))
	var rr2 := clampf(_hero_rage / 100.0, 0.0, 1.0)
	_hud.draw_rect(Rect2(rr.position, Vector2(rr.size.x * rr2, rr.size.y)), GOLD)
	_hud.draw_rect(rr, Color(0.28, 0.22, 0.16, 0.55), false, 1.0)
	# 底部圆形招式键
	if _skill_btn != null and _skill_btn.visible and not _finished:
		_draw_action_icon(Vector2(280.0, 1150.0), 44.0, "skill")
	if _ult_btn != null and _ult_btn.visible and not _finished:
		_draw_action_icon(Vector2(420.0, 1150.0), 50.0, "ult")
	if _tip_which != "" and ((_tip_which == "skill" and _skill_btn != null and _skill_btn.visible) or (_tip_which == "ult" and _ult_btn != null and _ult_btn.visible)):
		_draw_action_tip()


func _draw_action_icon(c: Vector2, r: float, which: String) -> void:
	var is_skill := which == "skill"
	var ready := (_hero_skill_cd <= 0.0) if is_skill else (_hero_rage >= 100.0)
	var glow := _guide_on and ((_guide_mode == "skill" and is_skill) or (_guide_mode == "ult" and not is_skill))
	var k := 0.5 + 0.5 * sin(_t * 5.2)
	_hud.draw_circle(c + Vector2(0.0, 3.0), r + 2.0, Color(0.10, 0.08, 0.06, 0.18))
	_hud.draw_circle(c, r, Color(0.94, 0.91, 0.85))
	_hud.draw_arc(c, r, 0.0, TAU, 48, Color(0.45, 0.38, 0.28, 0.60), 2.0)
	var ring_col := GOLD if ready else Color(0.52, 0.46, 0.38)
	_hud.draw_arc(c, r - 3.0, 0.0, TAU, 48, ring_col, 2.5)
	if glow:
		_hud.draw_arc(c, r + 5.0, 0.0, TAU, 48, Color(1.0, 0.86, 0.40, 0.45 + 0.45 * k), 4.0)
	if is_skill:
		var d := Vector2(0.72, 0.69).normalized()
		var side := Vector2(-d.y, d.x)
		var base := c - d * r * 0.46
		var tip := c + d * r * 0.52
		var blade := PackedVector2Array([tip, base + side * r * 0.10, base - side * r * 0.10])
		_hud.draw_colored_polygon(blade, Color(0.95, 0.94, 0.88))
		_hud.draw_line(base + side * r * 0.11, tip, Color(0.62, 0.59, 0.52), 1.2)
		_hud.draw_line(base + side * r * 0.24, base - side * r * 0.24, Color(0.84, 0.66, 0.26), 4.0)
		var hilt_end := base - d * r * 0.30
		_hud.draw_line(base - d * r * 0.02, hilt_end, Color(0.55, 0.14, 0.10), 5.0)
		_hud.draw_circle(hilt_end, r * 0.06, Color(0.84, 0.66, 0.26))
	else:
		_hud.draw_circle(c, r * 0.30, Color(0.82, 0.34, 0.10))
		_hud.draw_arc(c, r * 0.46, 0.0, TAU, 32, Color(0.90, 0.62, 0.18), 2.0)
		for i in 10:
			var a := float(i) * TAU / 10.0 + _t * 0.15
			_hud.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.52, c + Vector2(cos(a), sin(a)) * r * 0.70, Color(0.88, 0.60, 0.18), 2.0)
	if is_skill and _hero_skill_cd > 0.0:
		var ratio := clampf(_hero_skill_cd / SKILL_CD, 0.0, 1.0)
		_draw_dark_wedge(c, r, ratio)
		var hand := -PI * 0.5 + TAU * ratio
		_hud.draw_line(c, c + Vector2(cos(hand), sin(hand)) * (r - 5.0), Color(0.95, 0.84, 0.52, 0.90), 2.5, true)
		_hud.draw_circle(c, 3.0, Color(0.95, 0.84, 0.52, 0.90))
		var sec := str(int(ceil(_hero_skill_cd)))
		var spos := c + Vector2(-r * 0.26, 8.0)
		_hud.draw_string(UI_FONT, spos + Vector2(1.2, 1.2), sec, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(0.10, 0.08, 0.06, 0.78))
		_hud.draw_string(UI_FONT, spos, sec, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(0.98, 0.90, 0.62))
	elif not is_skill and _hero_rage < 100.0:
		var missing := 1.0 - clampf(_hero_rage / 100.0, 0.0, 1.0)
		_draw_dark_wedge(c, r, missing)
		var hand2 := -PI * 0.5 + TAU * missing
		_hud.draw_line(c, c + Vector2(cos(hand2), sin(hand2)) * (r - 5.0), Color(0.95, 0.84, 0.52, 0.90), 2.5, true)
		_hud.draw_circle(c, 3.0, Color(0.95, 0.84, 0.52, 0.90))
		var rage_r := clampf(_hero_rage / 100.0, 0.0, 1.0)
		_hud.draw_arc(c, r + 3.0, -PI * 0.5, -PI * 0.5 + TAU * rage_r, 40, Color(0.88, 0.62, 0.20), 4.0)
		var rtxt := str(int(_hero_rage))
		var rpos := c + Vector2(-r * 0.24, 8.0)
		_hud.draw_string(UI_FONT, rpos + Vector2(1.2, 1.2), rtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0.10, 0.08, 0.06, 0.78))
		_hud.draw_string(UI_FONT, rpos, rtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0.98, 0.90, 0.62))
	var label := "落日剑法" if is_skill else "落日剑诀"
	_hud.draw_string(UI_FONT, Vector2(c.x - r, c.y + r + 28.0), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 14, Color(0.28, 0.24, 0.19, 0.80))


func _draw_dark_wedge(c: Vector2, r: float, ratio: float) -> void:
	if ratio <= 0.001:
		return
	var pts := PackedVector2Array([c])
	var steps := 25
	for i in steps:
		var a := -PI * 0.5 + TAU * ratio * float(i) / float(steps - 1)
		pts.append(c + Vector2(cos(a), sin(a)) * (r - 2.0))
	_hud.draw_colored_polygon(pts, Color(0.10, 0.08, 0.07, 0.58))


func _draw_action_tip() -> void:
	var is_skill := _tip_which == "skill"
	var title := "落日剑法" if is_skill else "落日剑诀"
	var desc := "单体 · 150% 物理伤害 · 冷却 20 秒" if is_skill else "群体 · 9999 物理伤害 · 需要满怒气"
	var panel := Rect2(100.0, 998.0, 520.0, 84.0)
	_hud.draw_rect(panel, Color(0.12, 0.10, 0.08, 0.92))
	_hud.draw_rect(panel, Color(GOLD.r, GOLD.g, GOLD.b, 0.85), false, 1.5)
	_hud.draw_string(UI_FONT, Vector2(124.0, 1032.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.96, 0.90, 0.72))
	_hud.draw_string(UI_FONT, Vector2(124.0, 1062.0), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.90, 0.87, 0.80))


func _rot_points(pts: PackedVector2Array, pivot: Vector2, ang: float, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(pivot + (p - pivot).rotated(ang) + off)
	return out


func _draw_break(t: float) -> void:
	var dim := clampf(t / 0.5, 0.0, 1.0) * 0.42
	_fx.draw_rect(Rect2(0.0, 0.0, W, H), Color(0.08, 0.06, 0.05, dim))
	var appear := clampf(t / 0.35, 0.0, 1.0)
	var bx := 360.0
	var tip_y := 300.0 - 18.0 * (1.0 - appear)
	var break_y := 560.0
	var guard_y := 640.0
	var blade_col := Color(0.96, 0.95, 0.90, appear)
	var white := Color(1.0, 1.0, 0.97, 0.40 * appear)
	var gold := Color(0.84, 0.66, 0.26, appear)
	var hilt_col := Color(0.55, 0.12, 0.10, appear)
	var upper := PackedVector2Array([Vector2(bx, tip_y), Vector2(bx + 18.0, break_y), Vector2(bx - 18.0, break_y)])
	var lower := PackedVector2Array([Vector2(bx - 18.0, break_y), Vector2(bx + 18.0, break_y), Vector2(bx + 22.0, guard_y - 8.0), Vector2(bx - 22.0, guard_y - 8.0)])
	var guard_a := Vector2(bx - 42.0, guard_y)
	var guard_b := Vector2(bx + 42.0, guard_y)
	var hilt_a := Vector2(bx, guard_y + 8.0)
	var hilt_b := Vector2(bx, guard_y + 66.0)
	var pommel := Vector2(bx, guard_y + 76.0)
	var trem := Vector2(sin(t * 55.0) * 1.4, 0.0) if t > 0.9 and t < 1.55 else Vector2.ZERO
	if t < 1.55:
		var u2 := PackedVector2Array()
		for p in upper:
			u2.append(p + trem)
		var l2 := PackedVector2Array()
		for p in lower:
			l2.append(p + trem)
		_fx.draw_colored_polygon(u2, blade_col)
		_fx.draw_colored_polygon(l2, blade_col)
		_fx.draw_line(Vector2(bx, tip_y) + trem, Vector2(bx, guard_y - 8.0) + trem, white, 2.0)
		_fx.draw_line(guard_a + trem, guard_b + trem, gold, 10.0)
		_fx.draw_line(hilt_a + trem, hilt_b + trem, hilt_col, 12.0)
		_fx.draw_circle(pommel + trem, 10.0, gold)
		if t > 1.0:
			var ck := clampf((t - 1.0) / 0.35, 0.0, 1.0)
			var crack := PackedVector2Array([
				Vector2(bx - 22.0, break_y), Vector2(bx - 8.0, break_y - 7.0),
				Vector2(bx + 1.0, break_y + 4.0), Vector2(bx + 11.0, break_y - 8.0),
				Vector2(bx + 22.0, break_y),
			])
			_fx.draw_polyline(crack, Color(0.18, 0.14, 0.12, 0.9 * ck), 3.0)
			_fx.draw_polyline(crack, Color(1.0, 0.92, 0.62, 0.85 * ck), 1.5)
	else:
		var k := clampf((t - 1.55) / 0.5, 0.0, 1.0)
		var pivot := Vector2(bx, break_y)
		var up2 := _rot_points(upper, pivot, -0.65 * k, Vector2(-82.0, -42.0) * k)
		_fx.draw_colored_polygon(up2, blade_col)
		var low2 := _rot_points(lower, pivot, 0.55 * k, Vector2(30.0, 130.0) * k)
		_fx.draw_colored_polygon(low2, blade_col)
		var g2 := _rot_points(PackedVector2Array([guard_a, guard_b]), pivot, 0.55 * k, Vector2(30.0, 130.0) * k)
		_fx.draw_line(g2[0], g2[1], gold, 10.0)
		var h2 := _rot_points(PackedVector2Array([hilt_a, hilt_b]), pivot, 0.55 * k, Vector2(30.0, 130.0) * k)
		_fx.draw_line(h2[0], h2[1], hilt_col, 12.0)
		var p2 := _rot_points(PackedVector2Array([pommel]), pivot, 0.55 * k, Vector2(30.0, 130.0) * k)
		_fx.draw_circle(p2[0], 10.0, gold)
		for i in 7:
			var ang := float(i) * TAU / 7.0 + 0.3
			var sp := pivot + Vector2(cos(ang), sin(ang)) * (26.0 + 70.0 * k)
			var a2 := 0.85 * (1.0 - k)
			_fx.draw_colored_polygon(PackedVector2Array([sp, sp + Vector2(6.0, -11.0), sp + Vector2(12.0, 3.0)]), Color(1.0, 0.95, 0.80, a2))
		var bf := clampf(1.0 - absf(t - 1.58) / 0.16, 0.0, 1.0)
		if bf > 0.0:
			_fx.draw_rect(Rect2(0.0, 0.0, W, H), Color(1.0, 0.95, 0.80, 0.55 * bf))
	var line := ""
	if t < 0.9:
		line = "最后一剑落下。"
	elif t < 1.6:
		line = "剑身发出一声轻响。"
	elif t < 2.3:
		line = "「咔。」"
	else:
		line = "……断了。"
	var boxa := clampf(t / 0.3, 0.0, 1.0)
	if t > 2.9:
		boxa *= clampf((3.3 - t) / 0.4, 0.0, 1.0)
	_fx.draw_rect(Rect2(70.0, 900.0, 580.0, 62.0), Color(0.10, 0.08, 0.07, 0.78 * boxa))
	_fx.draw_rect(Rect2(70.0, 900.0, 580.0, 62.0), Color(0.86, 0.68, 0.26, 0.70 * boxa), false, 1.5)
	var tw := UI_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x
	_fx.draw_string(UI_FONT, Vector2(360.0 - tw * 0.5, 941.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(0.96, 0.93, 0.86, boxa))


func _draw_sword(pos: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var gold := Color(1.0, 0.80, 0.30, alpha)
	var blade := Color(0.97, 0.96, 0.90, alpha)
	var dark := Color(0.55, 0.12, 0.08, alpha)
	_fx.draw_line(pos + Vector2(0.0, -170.0), pos, Color(1.0, 0.85, 0.45, 0.16 * alpha), 22.0, true)
	_fx.draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(-9.0, -150.0), pos + Vector2(9.0, -150.0)]), blade)
	_fx.draw_line(pos + Vector2(-32.0, -150.0), pos + Vector2(32.0, -150.0), gold, 7.0, true)
	_fx.draw_line(pos + Vector2(0.0, -190.0), pos + Vector2(0.0, -152.0), dark, 8.0, true)
	_fx.draw_circle(pos, 12.0, Color(1.0, 0.95, 0.80, 0.55 * alpha))
	_fx.draw_arc(pos, 34.0, 0.0, TAU, 24, Color(1.0, 0.78, 0.30, 0.5 * alpha), 2.0, true)


func _draw_guide() -> void:
	if not _guide_on:
		return
	var c := _guide_rect.get_center()
	var k := 0.5 + 0.5 * sin(_guide_t * 6.0)
	var box_y := 128.0
	var box := Rect2(70.0, box_y, 580.0, 74.0)
	_guide_layer.draw_rect(box, Color(0.96, 0.94, 0.89, 0.97))
	_guide_layer.draw_rect(box, Color(GOLD.r, GOLD.g, GOLD.b, 0.85), false, 2.0)
	_guide_layer.draw_string(UI_FONT, Vector2(92.0, box_y + 46.0), _guide_text, HORIZONTAL_ALIGNMENT_LEFT, 540.0, 21, INK)
	var blink := 0.5 + 0.5 * sin(_guide_t * 7.0)
	var glow := 0.08 + 0.20 * blink
	if _guide_kind == "wave":
		# 波数：墨底金框，字自己在上层闪（不再拿金底盖住字）
		var chip := Rect2(12.0, 6.0, 210.0, 54.0)
		_guide_layer.draw_rect(chip.grow(12.0), Color(1.0, 0.78, 0.28, glow * 0.5), false, 10.0)
		_guide_layer.draw_rect(chip, Color(0.12, 0.10, 0.08, 0.92))
		_guide_layer.draw_rect(chip, Color(1.0, 0.86, 0.40, 0.55 + 0.45 * blink), false, 2.0 + 1.5 * blink)
		var wtxt := "波 " + str(_wave) + "/" + str(_wave_max)
		var wcol := Color(1.0, 0.88, 0.45, 1.0).lerp(Color(1.0, 0.97, 0.88, 1.0), blink)
		_guide_layer.draw_string(UI_FONT, Vector2(24.0, 44.0), wtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, wcol)
	else:
		var ring := _guide_rect.grow(9.0 + 5.0 * blink)
		_guide_layer.draw_rect(ring.grow(16.0), Color(1.0, 0.78, 0.28, glow * 0.55), false, 12.0)
		_guide_layer.draw_rect(ring.grow(7.0), Color(1.0, 0.78, 0.28, glow), false, 7.0)
		_guide_layer.draw_rect(ring, Color(1.0, 0.82, 0.34, 0.06 + 0.12 * blink))
		_guide_layer.draw_rect(ring, Color(1.0, 0.88, 0.48, 0.55 + 0.45 * blink), false, 3.0 + 1.8 * blink)
	# 箭头：从字框上/下沿出发，别穿过字框
	var start := Vector2(360.0, 120.0) if c.y < 128.0 else Vector2(360.0, 212.0)
	var pts := PackedVector2Array()
	for i in 22:
		var t := float(i) / 21.0
		var p := start.lerp(c, t)
		p.y -= sin(t * PI) * 34.0
		pts.append(p)
	_guide_layer.draw_polyline(pts, Color(0.16, 0.08, 0.05, 0.55), 9.0, true)
	_guide_layer.draw_polyline(pts, Color(1.0, 0.84, 0.36, 1.0), 4.5, true)
	var dir := (c - pts[pts.size() - 2]).normalized()
	var side := Vector2(-dir.y, dir.x)
	var tip := c
	var a1 := tip - dir * 26.0 + side * 13.0
	var a2 := tip - dir * 26.0 - side * 13.0
	_guide_layer.draw_colored_polygon(PackedVector2Array([tip, a1, a2]), Color(0.16, 0.08, 0.05, 0.6))
	var g1 := tip
	var g2 := tip + (a1 - tip) * 0.72
	var g3 := tip + (a2 - tip) * 0.72
	_guide_layer.draw_colored_polygon(PackedVector2Array([g1, g2, g3]), Color(1.0, 0.86, 0.40, 1.0))
