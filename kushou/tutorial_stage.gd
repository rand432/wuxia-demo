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
#
# 入口（临时）：主界面底排「出村」→ 直接开本关（menu_sketch 的 TUTORIAL_DEMO 开关）
# 不写存档；退出/清场都只回调 closed。
# ============================================================

signal closed

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
const HERO_HOME := Vector2(360.0, 980.0)
const FIELD_MIN := Vector2(70.0, 680.0)
const FIELD_MAX := Vector2(650.0, 1060.0)
const HERO_SPEED := 250.0
const HERO_RANGE := 78.0
const HERO_ATK := 30.0
const HERO_ATK_CD := 0.72
const SKILL_CD := 20.0
const SKILL_MULT := 1.5
const ULT_MULT := 2.0
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
var _hero_hp := HERO_HP_MAX
var _hero_rage := 0.0
var _hero_atk_t := 0.4
var _hero_skill_cd := 0.0
var _hero_flash := 0.0
var _hero_dir := 1.0
var _flash_t := 0.0
var _shake_t := 0.0

# ---- 敌人 / 特效 ----
var _enemies: Array = []
var _decor: Array = []
var _telegraphs: Array = []
var _floats: Array = []
var _fx_list: Array = []

# ---- 流程 ----
var _wave := 0
var _wave_max := 5
var _paused := false
var _finished := false
var _victory := false
var _wave_wait := -1.0
var _started := false
var _dodge_taught := false
var _counter_guided := false
var _guide_enemy = null
var _hp_guide_done := false

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

	_skill_btn = UiKit.make_button(self, Vector2(48.0, 1108.0), Vector2(300.0, 96.0), "落日剑法", 26)
	_skill_btn.z_index = 10
	_skill_btn.focus_mode = Control.FOCUS_NONE
	_skill_btn.pressed.connect(_cast_skill)

	_ult_btn = UiKit.make_button(self, Vector2(372.0, 1108.0), Vector2(300.0, 96.0), "落日剑诀", 26)
	_ult_btn.z_index = 10
	_ult_btn.focus_mode = Control.FOCUS_NONE
	_ult_btn.pressed.connect(_cast_ult)


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
	var sub := UiKit.make_label(box, Vector2(0.0, 142.0), Vector2(540.0, 40.0), 20, Color(INK.r, INK.g, INK.b, 0.7))
	sub.text = "风停了。剑上的血，一滴一滴落进土里。"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_return = UiKit.make_button(box, Vector2(60.0, 250.0), Vector2(200.0, 58.0), "回 村", 22)
	_end_return.focus_mode = Control.FOCUS_NONE
	_end_return.pressed.connect(_exit_stage)
	_end_again = UiKit.make_button(box, Vector2(280.0, 250.0), Vector2(200.0, 58.0), "再来一局", 22)
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
	_paused = false
	_wave = 0
	_wave_wait = -1.0
	_dodge_taught = false
	_counter_guided = false
	_guide_enemy = null
	_hp_guide_done = false
	_hero_hp = HERO_HP_MAX
	_hero_rage = 0.0
	_hero_atk_t = 0.4
	_hero_skill_cd = 0.0
	_hero_flash = 0.0
	_flash_t = 0.0
	_shake_t = 0.0
	_actors.position = Vector2.ZERO
	_fx.position = Vector2.ZERO
	_hero_pos = HERO_HOME
	_hero_target = HERO_HOME
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
		var m := _spawn_enemy("mage", Vector2(520.0, 700.0), 90.0, 10.0, 90.0)
		m["cast_t"] = 8.0
		_dialogue([
			{"who": "旁白", "text": "风从村口卷过，带着土腥气。"},
			{"who": "村匪", "text": "小子，这条路，你也敢走？"},
			{"who": "主角", "text": "这就是村匪？", "art": "player"},
			{"who": "村匪", "text": "识相的，退回去。爷今日不想见血。"},
			{"who": "旁白", "text": "你没有动。"},
			{"who": "旁白", "text": "他眼里闪过一丝戾气，手腕一翻——"},
			{"who": "引导", "text": "小心！这是暗器——点地面躲开。"},
		], func() -> void:
			_mage_cast(m)
			_dodge_taught = true
			_guide("闪开。", Rect2(_hero_pos - Vector2(96.0, 96.0), Vector2(192.0, 192.0)), "dodge")
		)
	elif n == 2:
		# 巷口后头灰压压的一片人影（只做背景，不参战）
		for i in 4:
			_spawn_decor(Vector2(170.0 + float(i) * 120.0, 636.0 + float(i % 2) * 18.0), 104.0, 0.52)
		var m2 := _spawn_enemy("mage", Vector2(400.0, 720.0), 70.0, 10.0, 110.0)
		m2["cast_t"] = 5.0
		_dialogue([
			{"who": "旁白", "text": "你刚收剑，巷口后头又涌出一片灰影。"},
			{"who": "旁白", "text": "当先一个身法极快——和方才那人，是一路货色。"},
			{"who": "旁白", "text": "前头那具尸首，并没让他们生出半点惧色。"},
			{"who": "旁白", "text": "后头还跟着几条人影。你心里清楚：得快。"},
		], func() -> void:
			_guide("一波未平，一波又起。", Rect2(18.0, 14.0, 240.0, 52.0), "tap", Callable(), "wave")
		)
	elif n == 3:
		var g := _spawn_enemy("brute", Vector2(360.0, 720.0), 180.0, 16.0, 100.0)
		g["atk_t"] = 0.2
	elif n == 4:
		_spawn_enemy("elite", Vector2(360.0, 700.0), 200.0, 16.0, 100.0)
		_hero_skill_cd = 0.0
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
		_spawn_enemy("boss", Vector2(360.0, 660.0), 60.0, 18.0, 95.0)
		_spawn_enemy("minion", Vector2(250.0, 760.0), 30.0, 8.0, 115.0)
		_spawn_enemy("minion", Vector2(470.0, 760.0), 30.0, 8.0, 115.0)
		_spawn_enemy("minion", Vector2(360.0, 820.0), 30.0, 8.0, 115.0)
		_hero_hp = maxf(1.0, HERO_HP_MAX * 0.2)
		_hero_rage = 100.0
		_dialogue([
			{"who": "旁白", "text": "独臂刀客倒下的时候，巷子深处才传来脚步声。"},
			{"who": "旁白", "text": "不快。一步一步，像踩在你心口上。"},
			{"who": "匪首", "text": "小子，手底下倒有几分本事。"},
			{"who": "旁白", "text": "他身后，又慢慢走出三个人。"},
			{"who": "匪首", "text": "可惜，到此为止了。"},
			{"who": "旁白", "text": "你没有答话。你握紧了剑。"},
			{"who": "旁白", "text": "胸口那口气，烧得发烫。"},
		], func() -> void:
			_guide("到时候了。", _ult_btn.get_global_rect(), "ult")
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
	var ring := Color(0.78, 0.20, 0.14) if kind == "boss" else Color(0.58, 0.26, 0.18)
	var a = _make_token(role, false, height, ring, 1.0)
	a.position = pos
	_actors.add_child(a)
	var e := {
		"node": a, "pos": pos, "hp": hp, "max": hp, "atk": atk,
		"speed": speed, "kind": kind, "atk_t": 0.9, "cast_t": 1.6, "dead": false,
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
	if _finished or _wave_wait >= 0.0:
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
	_update_buttons()
	_update_glow()
	_update_fx(delta)
	_update_floats(delta)
	_flash_t = maxf(0.0, _flash_t - delta)
	if _shake_t > 0.0:
		_shake_t = maxf(0.0, _shake_t - delta)
		var amp := 10.0 * (_shake_t / 0.45)
		var off := Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		_actors.position = off
		_fx.position = off
	else:
		_actors.position = Vector2.ZERO
		_fx.position = Vector2.ZERO
	_bg.queue_redraw()
	_hud.queue_redraw()
	_fx.queue_redraw()
	_guide_layer.queue_redraw()
	if _paused or _finished:
		return
	_hero_flash = maxf(0.0, _hero_flash - delta)
	_update_hero(delta)
	_update_enemies(delta)
	_update_telegraphs(delta)
	_update_wave(delta)


func _update_hero(delta: float) -> void:
	_hero_skill_cd = maxf(0.0, _hero_skill_cd - delta)
	_hero_atk_t = maxf(0.0, _hero_atk_t - delta)

	if _hero_target.distance_to(_hero_pos) > 6.0:
		var d := _hero_target - _hero_pos
		_hero_pos += d.normalized() * HERO_SPEED * delta
		_hero_pos.x = clampf(_hero_pos.x, FIELD_MIN.x, FIELD_MAX.x)
		_hero_pos.y = clampf(_hero_pos.y, FIELD_MIN.y, FIELD_MAX.y)
		_hero.position = _hero_pos
		_face_dir(d.x)
		return

	var target := _nearest_enemy()
	if target.is_empty():
		return
	var tp: Vector2 = target["pos"]
	var dx := tp.x - _hero_pos.x
	var dist := _hero_pos.distance_to(tp)
	_face_dir(dx)
	if dist > HERO_RANGE:
		_hero_pos += (tp - _hero_pos).normalized() * HERO_SPEED * delta
		_hero_pos.x = clampf(_hero_pos.x, FIELD_MIN.x, FIELD_MAX.x)
		_hero_pos.y = clampf(_hero_pos.y, FIELD_MIN.y, FIELD_MAX.y)
		_hero.position = _hero_pos
	elif _hero_atk_t <= 0.0:
		_hero_atk_t = HERO_ATK_CD
		_hero.play_move("chop", 1.5)
		_damage_enemy(target, HERO_ATK * randf_range(0.9, 1.1), Color(0.93, 0.86, 0.66))
		_hero_rage = minf(100.0, _hero_rage + 7.0)


func _face_dir(dx: float) -> void:
	if absf(dx) < 6.0:
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
			if dist > 84.0:
				pos += to_hero.normalized() * float(e["speed"]) * delta
			else:
				e["atk_t"] = float(e["atk_t"]) - delta
				if float(e["atk_t"]) <= 0.0:
					e["atk_t"] = 1.15
					if is_instance_valid(e["node"]):
						e["node"].play_move("chop", 1.4)
					_damage_hero(float(e["atk"]))
		pos.x = clampf(pos.x, 80.0, 640.0)
		pos.y = clampf(pos.y, 620.0, 900.0)
		e["pos"] = pos
		if is_instance_valid(e["node"]):
			e["node"].position = pos
			var dx := _hero_pos.x - pos.x
			if absf(dx) > 6.0:
				e["node"].face(1 if dx >= 0.0 else -1)


func _mage_cast(e: Dictionary) -> void:
	var center: Vector2 = _hero_pos
	var from_pos: Vector2 = e["pos"]
	_telegraphs.append({
		"pos": center, "r": 96.0, "t": 0.0, "total": 1.15,
		"dmg": 24.0, "from": from_pos,
	})


func _update_telegraphs(delta: float) -> void:
	for t in _telegraphs.duplicate():
		t["t"] = float(t["t"]) + delta
		if float(t["t"]) >= float(t["total"]):
			var p: Vector2 = t["pos"]
			if _hero_pos.distance_to(p) <= float(t["r"]):
				_damage_hero(float(t["dmg"]))
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


func _damage_hero(dmg: float) -> void:
	if _finished:
		return
	_hero_hp = maxf(1.0, _hero_hp - dmg)
	_hero_flash = 0.25
	_hero_rage = minf(100.0, _hero_rage + 4.0)
	_floats.append({"pos": _hero_pos + Vector2(0.0, -150.0), "text": "-" + str(int(dmg)), "t": 0.0, "total": 0.9, "col": SEAL})
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
				_guide("血，顺着手臂滴下来。", Rect2(18.0, 70.0, 330.0, 40.0), "tap", Callable(), "hp")
			)


func _damage_enemy(e: Dictionary, dmg: float, col: Color) -> void:
	if bool(e["dead"]):
		return
	e["hp"] = float(e["hp"]) - dmg
	var p: Vector2 = e["pos"]
	_floats.append({"pos": p + Vector2(0.0, -110.0), "text": str(int(dmg)), "t": 0.0, "total": 0.8, "col": col})
	_fx_list.append({"kind": "hit", "pos": p + Vector2(0.0, -60.0), "t": 0.0, "total": 0.25})
	if float(e["hp"]) <= 0.0:
		e["dead"] = true
		if is_instance_valid(e["node"]):
			e["node"].play_down()
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
	_damage_enemy(target, HERO_ATK * SKILL_MULT, Color(0.95, 0.78, 0.30))
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
	_fx_list.append({"kind": "sun", "pos": _hero_pos + Vector2(0.0, -80.0), "t": 0.0, "total": 0.9})
	_fx_list.append({"kind": "ring", "pos": _hero_pos, "t": 0.0, "total": 0.6})
	_flash_t = 0.5
	_shake_t = 0.45
	for e in _enemies.duplicate():
		var to: Vector2 = (e["pos"] as Vector2) + Vector2(0.0, -50.0)
		_fx_list.append({"kind": "sword_light", "from": _hero_pos + Vector2(0.0, -70.0), "to": to, "t": 0.0, "total": 0.42})
		if is_instance_valid(e["node"]):
			e["node"].play_hit()
		_damage_enemy(e, HERO_ATK * ULT_MULT, Color(0.95, 0.72, 0.24))
	if _guide_on and _guide_mode == "ult":
		_end_guide()


# ============================================================
# 引导
# ============================================================

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
	var k := 0.5 + 0.5 * sin(_t * 5.2)
	var warm := Color(1.0 + 0.28 * k, 1.0 + 0.20 * k, 1.0 - 0.04 * k)
	if _guide_on and _guide_mode == "skill":
		_skill_btn.modulate = warm
	else:
		_skill_btn.modulate = Color(1, 1, 1)
	if _guide_on and _guide_mode == "ult":
		_ult_btn.modulate = warm
	else:
		_ult_btn.modulate = Color(1, 1, 1)


func _update_buttons() -> void:
	if _hero_skill_cd > 0.0:
		_skill_btn.text = "落日剑法 · " + str(int(ceil(_hero_skill_cd))) + "s"
		_skill_btn.disabled = true
	else:
		_skill_btn.text = "落日剑法 · 就绪"
		_skill_btn.disabled = false
	if _hero_rage >= 100.0:
		_ult_btn.text = "落日剑诀 · 就绪"
		_ult_btn.disabled = false
	else:
		_ult_btn.text = "落日剑诀 · " + str(int(_hero_rage))
		_ult_btn.disabled = true


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
			_fx_list.append({"kind": "click", "pos": _hero_target, "t": 0.0, "total": 0.35})
			_end_guide()
		elif _guide_mode == "target":
			var e = _guide_enemy
			if e != null and not bool(e.get("dead", false)) and _enemy_rect(e).has_point(pos):
				_hero_target = e["pos"] as Vector2
				_fx_list.append({"kind": "click", "pos": _hero_target, "t": 0.0, "total": 0.35})
				_guide_enemy = null
				_end_guide()
		return
	if _paused:
		return
	_hero_target = _clamp_pos(pos)
	_fx_list.append({"kind": "click", "pos": _hero_target, "t": 0.0, "total": 0.35})


func _clamp_pos(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, FIELD_MIN.x, FIELD_MAX.x), clampf(p.y, FIELD_MIN.y, FIELD_MAX.y))


func _on_pause() -> void:
	if _guide_on or _dlg_on or _finished:
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
	_end_title.text = "清 场" if win else "败"
	_end_ov.visible = true
	Audio.sfx("win" if win else "lose", -8.0)


# ============================================================
# 绘制
# ============================================================

func _draw_bg() -> void:
	_bg.draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), PAPER)
	# 远山
	_bg.draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, 560.0), Vector2(150.0, 380.0), Vector2(300.0, 560.0),
	]), Color(0.72, 0.73, 0.66, 0.55))
	_bg.draw_colored_polygon(PackedVector2Array([
		Vector2(240.0, 560.0), Vector2(430.0, 330.0), Vector2(640.0, 560.0),
	]), Color(0.66, 0.67, 0.60, 0.45))
	_bg.draw_colored_polygon(PackedVector2Array([
		Vector2(480.0, 560.0), Vector2(640.0, 410.0), Vector2(760.0, 560.0),
	]), Color(0.70, 0.70, 0.63, 0.40))
	# 村口矮墙（地平线）
	_bg.draw_rect(Rect2(0.0, 560.0, W, 44.0), Color(0.79, 0.75, 0.66))
	_bg.draw_rect(Rect2(0.0, 560.0, W, 3.0), Color(0.42, 0.35, 0.25, 0.45))
	_bg.draw_rect(Rect2(300.0, 548.0, 120.0, 56.0), Color(0.67, 0.63, 0.55))
	_bg.draw_rect(Rect2(300.0, 548.0, 120.0, 3.0), Color(0.42, 0.35, 0.25, 0.45))
	# 院子地面
	_bg.draw_rect(Rect2(0.0, 604.0, W, 676.0), Color(0.86, 0.82, 0.72))
	_bg.draw_line(Vector2(0.0, 604.0), Vector2(W, 604.0), Color(0.45, 0.38, 0.28, 0.45), 2.0)
	for i in 7:
		var y := 666.0 + float(i) * 88.0
		_bg.draw_line(Vector2(16.0, y), Vector2(704.0, y), Color(0.55, 0.48, 0.36, 0.10), 2.0)
	for i in 6:
		var x := 80.0 + float(i) * 120.0
		_bg.draw_line(Vector2(x, 604.0), Vector2(x, 1280.0), Color(0.55, 0.48, 0.36, 0.06), 2.0)


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
		var p: Vector2 = f["pos"]
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
	if _flash_t > 0.0:
		var fa := clampf(_flash_t / 0.5, 0.0, 1.0) * 0.38
		_fx.draw_rect(Rect2(0.0, 0.0, W, H), Color(1.0, 0.92, 0.72, fa))
	for fl in _floats:
		var a := 1.0 - clampf(float(fl["t"]) / float(fl["total"]), 0.0, 1.0)
		var col: Color = fl["col"]
		col.a = a
		var fp: Vector2 = fl["pos"]
		_fx.draw_string(UI_FONT, fp, str(fl["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)


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
	var hr := Rect2(22.0, 74.0, 320.0, 18.0)
	_hud.draw_rect(hr, Color(0.25, 0.22, 0.18, 0.25))
	var ratio := clampf(_hero_hp / HERO_HP_MAX, 0.0, 1.0)
	_hud.draw_rect(Rect2(hr.position, Vector2(hr.size.x * ratio, hr.size.y)), Color(0.62, 0.16, 0.12))
	_hud.draw_rect(hr, Color(0.28, 0.22, 0.16, 0.55), false, 1.0)
	_hud.draw_string(UI_FONT, Vector2(28.0, 88.0), str(int(_hero_hp)) + "/" + str(int(HERO_HP_MAX)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.97, 0.94, 0.86))
	# 怒气
	var rr := Rect2(22.0, 100.0, 320.0, 10.0)
	_hud.draw_rect(rr, Color(0.25, 0.22, 0.18, 0.25))
	var rr2 := clampf(_hero_rage / 100.0, 0.0, 1.0)
	_hud.draw_rect(Rect2(rr.position, Vector2(rr.size.x * rr2, rr.size.y)), GOLD)
	_hud.draw_rect(rr, Color(0.28, 0.22, 0.16, 0.55), false, 1.0)


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
