extends Control
# ============================================================
# menu/main_home.gd —— 主界面（半图半控件 · 画卷从上至下铺开）
#   骨架 shared/ui_kit.gd：顶栏 0–90 / 页头 90–152 / 内容 152–1176 / 底栏 1176–1280
# ============================================================
const UI := preload("res://shared/ui_kit.gd")
const P := preload("res://shared/ui_pal.gd")
const GameState := preload("res://shared/game_state.gd")
const LevelState := preload("res://shared/level_state.gd")
const Audio := preload("res://shared/audio.gd")
const STAGE_1 := preload("res://assets/art/ui/stage_1.png")

const ART_RECT := Rect2(80, 282, 560, 600)
const STAGES := [
	{"name": "第 1 关    村口小道", "art": STAGE_1, "power": "—", "reward": "—"},
]

var _stage := 0
var _diff := 0
var _coin_lb: Label = null
var _crystal_lb: Label = null
var _title_lb: Label = null
var _art_rect: TextureRect = null
var _art_clip: Control = null
var _arrow_l: Control = null
var _arrow_r: Control = null
var _tabs: Array = []
var _settings: Control = null
var _last_coin := -1
var _last_crystal := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	UI.bg(self)
	var bars := UI.app_bar(self, GameState.player_name, "玄品", _open_settings)
	_coin_lb = bars["coin"]
	_crystal_lb = bars["crystal"]
	_build_head()
	_build_tabs()
	_build_stage_art()
	_build_info()
	UI.dock(self, "", _on_dock)
	_refresh()
	set_process(true)
	_unroll(0.0)

# ---------------- 页头：只剩关名 ----------------
func _build_head() -> void:
	_title_lb = UI.label(self, "", Vector2(72, 98), Vector2(576, 48), 30, P.INK, HORIZONTAL_ALIGNMENT_CENTER)

func _change_stage(d: int) -> void:
	_stage = wrapi(_stage + d, 0, STAGES.size())
	Audio.sfx("ui_click", -8.0)
	_refresh()
	_unroll(0.0)

# ---------------- 难度 ----------------
func _build_tabs() -> void:
	for i in 2:
		var b := Button.new()
		b.text = "普 通" if i == 0 else "精 英"
		b.position = Vector2(150.0 if i == 0 else 370.0, 168)
		b.size = Vector2(200, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(func() -> void:
			_diff = i
			Audio.sfx("ui_click", -8.0)
			_style_tabs())
		add_child(b)
		_tabs.append(b)
	_style_tabs()

func _style_tabs() -> void:
	for i in _tabs.size():
		var b: Button = _tabs[i]
		var on := i == _diff
		var sb := StyleBoxFlat.new()
		sb.bg_color = P.SEAL if on else P.PAPER_HI
		sb.set_corner_radius_all(10)
		sb.border_color = Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.9) if on else P.LINE
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(0.980, 0.929, 0.839) if on else P.DIM)
		b.add_theme_color_override("font_hover_color", Color(0.980, 0.929, 0.839) if on else P.DIM)

# ---------------- 画（可卷起 / 铺开） ----------------
func _build_stage_art() -> void:
	_art_clip = Control.new()
	_art_clip.position = ART_RECT.position
	_art_clip.size = Vector2(ART_RECT.size.x, 0)
	_art_clip.clip_contents = true
	_art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_clip)
	var card := Panel.new()
	card.position = Vector2.ZERO
	card.size = ART_RECT.size
	var csb := StyleBoxFlat.new()
	csb.bg_color = P.PAPER_HI
	csb.set_corner_radius_all(2)
	card.add_theme_stylebox_override("panel", csb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_clip.add_child(card)
	_art_rect = TextureRect.new()
	_art_rect.position = Vector2(4, 4)
	_art_rect.size = ART_RECT.size - Vector2(8, 8)
	_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_clip.add_child(_art_rect)
	var frame := Panel.new()
	frame.position = Vector2(1, 1)
	frame.size = ART_RECT.size - Vector2(2, 2)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0)
	fsb.border_color = Color(0.769, 0.659, 0.431)
	fsb.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_clip.add_child(frame)
	# 两侧大箭头
	_arrow_l = UI.chevron(-1, Rect2(0, ART_RECT.position.y + ART_RECT.size.y * 0.5 - 80, 72, 160),
		func() -> void: _change_stage(-1))
	_arrow_r = UI.chevron(1, Rect2(648, ART_RECT.position.y + ART_RECT.size.y * 0.5 - 80, 72, 160),
		func() -> void: _change_stage(1))
	add_child(_arrow_l)
	add_child(_arrow_r)

func _unroll(delay: float) -> void:
	if _art_clip == null:
		return
	_art_clip.size = Vector2(ART_RECT.size.x, 0)
	if _arrow_l != null:
		_arrow_l.modulate.a = 0.0
	if _arrow_r != null:
		_arrow_r.modulate.a = 0.0
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(_art_clip, "size:y", ART_RECT.size.y, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(_arrow_l, "modulate:a", 1.0, 0.25)
		tw2.tween_property(_arrow_r, "modulate:a", 1.0, 0.25))

# ---------------- 关卡信息 ----------------
var _info_vals: Array = []

func _build_info() -> void:
	for i in 2:
		var y := 942.0 + float(i) * 68.0
		UI.panel(self, Rect2(24, y, 672, 56), Color(0.969, 0.949, 0.910), 10, Color(0.804, 0.745, 0.647), 1)
		UI.label(self, "推 荐 战 力" if i == 0 else "首 通 奖 励", Vector2(44, y), Vector2(160, 56), 20, P.DIM)
		_info_vals.append(UI.label(self, "—", Vector2(240, y), Vector2(420, 56), 20, Color(0.675, 0.635, 0.576)))

# ---------------- 底栏 ----------------
func _on_dock(key: String) -> void:
	Audio.sfx("ui_click", -6.0)
	match key:
		"role":
			get_tree().change_scene_to_file("res://menu/character_home.tscn")
		"god":
			get_tree().change_scene_to_file("res://menu/partner_home.tscn")
		"curio":
			get_tree().change_scene_to_file("res://menu/curio_home.tscn")
		"start":
			LevelState.ensure_loaded()
			LevelState.current_level = LevelState.max_unlocked
			get_tree().change_scene_to_file("res://kushou/battle_ui.tscn")

# ---------------- 刷新 ----------------
func _refresh() -> void:
	var st: Dictionary = STAGES[_stage]
	if _title_lb != null:
		_title_lb.text = str(st["name"])
	if _art_rect != null:
		_art_rect.texture = st["art"]
	if _info_vals.size() == 2:
		(_info_vals[0] as Label).text = str(st["power"])
		(_info_vals[1] as Label).text = str(st["reward"])
	_last_coin = -1
	_last_crystal = -1

func _process(_d: float) -> void:
	var w := GameState.coin("wen")
	var y := GameState.coin("yuanbao")
	if w != _last_coin and _coin_lb != null:
		_last_coin = w
		_coin_lb.text = str(w)
	if y != _last_crystal and _crystal_lb != null:
		_last_crystal = y
		_crystal_lb.text = str(y)

# ---------------- 设置 ----------------
func _open_settings() -> void:
	Audio.sfx("ui_open", -8.0)
	UI.open_settings(self)
