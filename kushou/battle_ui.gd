extends Control
# ============================================================
# kushou/battle_ui.gd —— 新战斗界面（按 v31 草图）
#   独立场景：先跑通布局/交互，再接进关卡流程。
#   720×1280：顶部资源 64 / 战场 140..830 / 卡组 830..980 / 底栏 980..1220
#   抽卡页无外框、不暂停；三张卡框浮在战场上。
# ============================================================

const W := 720.0
const H := 1280.0
const FONT := preload("res://fonts/ink.ttf")
const PLAYER_TEX := preload("res://assets/char/player_q.png")
const BattleCore := preload("res://kushou/kushou_battle.gd")
const TokenActor := preload("res://kushou/token_actor.gd")
const CardData := preload("res://kushou/card_data.gd")
const AncestorData := preload("res://kushou/ancestor_data.gd")
const AttackFx := preload("res://kushou/attack_fx.gd")

const INK := Color(0.13, 0.12, 0.11)
const PAPER := Color(0.93, 0.90, 0.82)
const PAPER_HI := Color(0.97, 0.95, 0.89)
const GOLD := Color(0.85, 0.66, 0.23)
const SEAL := Color(0.66, 0.22, 0.15)
const DIM := Color(0.42, 0.38, 0.32)
const LIGHT := Color(0.91, 0.87, 0.78)
const QUALITY_COLORS := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]

var _page := 0
var _draw_open := false
var _attr_open := false
var _exit_open := false
var _draw_layer: Control
var _chal_layer: Control
var _detail_layer: Control
var _detail_name: Label
var _detail_sub: Label
var _detail_line: Label
var _detail_card: Panel
var _detail_art: TextureRect
var _detail_effect: Label
var _detail_combo: Label
var _detail_combo_text: Label
var _detail_pips: Array = []
var _deck_count_lb: Label
var _attr_layer: Control
var _attr_val_lbs: Array = []
# 总计页：顶部分类钮（卡组 / 宝物 / 组合）
var _tot_tabs: Array = []
var _tot_keys: Array = ["deck", "bond", "combo"]
var _tot_tab := "deck"
var _tot_deck_root: Control = null
var _tot_bond_root: Control = null
var _exit_layer: Control
var _toast_lb: RichTextLabel
var _toast_seq := 0
var _cards: Array = []
var _card_db := {}
var _set_cards := {}
var _pool: Array = []
var _acquired := {}
# v2 波次 / 经验 / 升级（波次推进 + 升级点亮请神）
const MAX_WAVE := 5
var _lv := 1
var _exp := 0
var _exp_need := 100
var _draw_charge := 0          # 累积的请神次数（升级 +1）
var _run_cleared := false
var _lv_lb: Label = null
var _exp_lb: Label = null
var _exp_bar: Panel = null
var _mate_tile = null

# ============================================================
# ---------------- 强化（v6）----------------
#   用户："强化很简单 消耗文钱 对自身进行强化 每强化十级 卡牌三选一 获得进阶的数值奖励"
#   · 点一次［强化］：扣文钱 → 自身 ＋攻击 / ＋气血上限 / ＋护甲
#     ⚠ 气血按**比例**跟涨（老坑：强化一下就满血 → 见 kushou_battle.setup 的注释）
#   · 第 10 / 20 / 30… 级：弹三选一（品阶随轮次升：良→玄→地→天），选一张，永久数值进阶
#   · 关了没选不要紧：再点［强化］会把那一手重新打开（不重复扣钱）
# ============================================================
const STR_COST_BASE := 30          # 第一次强化的价钱
const STR_COST_STEP := 12          # 每升一级贵 12（十级合计 840 文钱 ≈ 三分钟）
const STR_PER_ATK := 1.0           # 每级：攻击 +1
const STR_PER_HP := 10.0           # 每级：气血上限 +10
const STR_PER_CUT := 0.003         # 每级：护甲 +0.3%
const STR_EVERY := 10              # 每 10 级给一次三选一
# 文钱来路：杀怪底薪 + 每波加成 + 清波奖励（不走 core 的 coin_drop 也能攒钱）
const WEN_KILL_BASE := 12
const WEN_KILL_WAVE := 3
const WEN_WAVE_CLEAR := 60
var _str_lv := 0
var _str_round := 0
var _str_pending := false
var _str_layer: Control = null
var _str_tile = null
# 进阶页（和抽卡同一套：三张卡浮在战场，不遮不暂停；只有［刷新 · 次数］和［隐藏］）
var _aug_cards: Array = []
var _aug_reroll := 3          # 刷新次数（开局 3 次，每进阶一轮 +1）
var _aug_rolled_lv := -1      # 这一手是为第几级掷的（关了再点不白刷）
var _aug_refresh_btn: Button = null
var _str_ban_lb: Label = null

# ============================================================
# ---------------- 宝物（v8）----------------
#   用户："宝物的抽取界面也和抽卡一致 【刷新次数/隐藏/放弃【增加一次刷新 对 这个进阶也要】】"
#   · 每清一波 +1 次宝物机会；开一次三张，挑一张带走
#   · 最多带 3 件；品质随波数升（1-2 良 / 3 玄 / 4 地 / 6+ 天）
#   · 三个按钮：刷新 · N 次（次数型）/ 隐藏（收起来，这一手还在）/ 放弃（+1 刷新，这手作废）
#   · ［放弃］进阶页也有：放弃这一轮进阶，换 1 次刷新
# ============================================================
const TREA_CHARGE_START := 1
var _bonds: Array = []          # 身上的羁绊（凑齐就消耗掉，所以不设上限）
var _bonds_done := 0            # 这一局已经成过几张
var _trea_charge := TREA_CHARGE_START
var _trea_reroll := 3
var _trea_pending := false
var _trea_layer: Control = null
var _trea_cards: Array = []
var _trea_refresh_btn: Button = null
var _trea_tile = null
var _exp_pct := 0.0
# v1 请神·家传卡：已请到的祖宗（aid -> 当前可收集档）／已激活的家传组合
var _ancestors := {}
var _ancestor_combos: Array = []
# v4 组合加成落地：aid -> {dmg_pct, cd_pct, mp_flat, para_s, para_amp}；元素共享单独记
var _anc_mod := {}
var _elem_mod := {}
# v4 炫卡：掷中（进池）／已吞（一局一次）
var _shiny_rolled := {}
var _shiny_used := {}
# v5 召唤物
var _minions: Array = []
# v6 吞海（崔三娘炫卡）：蛟龙永久 + 每秒/击杀 叠属性
var _swallow_sea := false
var _ss_pct := 0.0
var _ss_kills := 0
# v7 灼烧 / 引燃 / 焚天
var _burn_unlimited := false     # 焚天：灼烧层数不衰减
var _ignite_bonus := 0           # 引燃目标加成（三档 / 焚天吞噬）
var _fentian := false
var _ft_kills := 0
# v8 回潮（成长系彩蛋）：一局一次，波数回退 5
var _backwash_done := false
# 主角被动：多目标 / 追击 / 剑气
var _hero_passive := {}
# v11 万刃（苏青鸾炫卡）：穿透无上限 · 每点穿透 +1 刀 · 每 3 次回程 +1 穿透
var _wanren := false
var _wanren_pierce := 0
var _wanren_volleys := 0
# v9 剑魄（主角炫卡）：连击同一目标涨攻速（换目标重置）+ 剑气进化万剑归宗
var _hero_jianpo := false
var _jpo_tid := -1
var _jpo_stacks := 0
var _jpo_base_aspd := 1.0
# 攻速硬上限：只防卡（1/aspd 秒一下）；数值上「剑魄」本身不封顶
const MAX_ASPD := 5.0
# v10 抽取功能未做 → 天品祖宗暂时封印（不进三选一）
const SEALED := ["zl", "cuisanniang", "jicanghai", "chenshi"]
var _combined: Array = []
var _stats := {"atk": 0.0, "def": 0.0, "hp": 0.0}
var _gold_pct := 0.0
var _crystal_pct := 0.0
# v13 群/险 两系：每波定额加成 · 全局难度 · 怪物类型收益
var _wave_extra := 0
var _diff_pct := 0.0
var _coin_count_extra := 0
var _crystal_count_extra := 0
var _treasure_pct := 0.0
var _boss_pct := 0.0
# v14 财（经济线）：击杀收益加成 + 被吞噬卡（效果/进度保留）
var _kill_pct := 0.0
# v15 经验线：杀怪数按百分比放大（经验 + 所有按击杀成长的机制一起吃）
var _killnum_pct := 0.0
var _virtual_cards: Array = []
var _last_wave := 1
var _attack_count := 0
var _hit_count := 0
var _combo_t := 0.0
var _combined_layer: Control
var _combined_icons: Control
var _combined_detail: Control
var _toast_queue: Array = []
var _toast_busy := false
var _page_lb: Label
var _slots: Array = []
var _draw_cards: Array = []
var _enemies: Array = []
var _core = null
var _coin_lb: Label
var _kill_lb: Label
var _wave_lb: Label
var _hp_lb: Label
var _wen := 0
var _kills := 0
var _crystal := 100
var _crystal_lb: Label
var _draw_paid := false
var _draw_anim := false
var _hero_token = null
var _foe_tokens := {}
var _foe_seq := 0
# 攻击表现（P0）：后层剑/弧，前层白边淡红/伤害字；顶部血条是主角唯一血条
const FIELD_POS := Vector2(8, 150)
var _fx_back: Control = null
var _fx_front: Control = null
var _prev_hero_hp := -1.0
var _hp_fill: Panel = null
var _hero_hit_btn: Button = null
var _hero_name_lb: Label = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 17
	theme = th
	_init_cards()
	_build_bg()
	_build_hud()
	_build_field()
	_build_deck()
	_build_bottom()
	_build_draw()
	_build_attr()
	_build_exit()
	_build_toast()
	_build_combined()
	_build_god_pick()
	_build_str()
	_build_trea()
	_refresh_deck()
	set_process(true)

# ---------------- 通用 ----------------
func _panel(rect: Rect2, bg: Color, radius := 8, border := Color(0, 0, 0, 0), bw := 0, parent: Node = null) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(p)
	return p

func _lbl(t: String, pos: Vector2, sz: Vector2, fs: int, col: Color, parent: Node = null, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(l)
	return l

func _btn(t: String, rect: Rect2, fs: int, bg: Color, fg: Color, cb: Callable, parent: Node = null, border := Color(0.85, 0.66, 0.23, 0.55), bw := 1) -> Button:
	var b := Button.new()
	b.text = t
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate()
	hb.bg_color = bg.lightened(0.08)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)
	if cb.is_valid():
		b.pressed.connect(cb)
	(parent if parent != null else self).add_child(b)
	return b

func _toast(t: String) -> void:
	_toast_queue.append(t)
	if not _toast_busy:
		_toast_next()

func _toast_next() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	var t: String = str(_toast_queue.pop_front())
	if _toast_lb == null:
		_toast_queue.clear()
		_toast_busy = false
		return
	_toast_lb.text = "[center]" + t + "[/center]"
	_toast_lb.visible = true
	_toast_lb.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(_toast_lb, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func() -> void:
		if _toast_lb != null:
			_toast_lb.visible = false
		_toast_busy = false
		_toast_next())

class BgArt extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.93, 0.90, 0.82))
		# 纸纹/山
		var pts := [
			Vector2(0, 830), Vector2(90, 690), Vector2(170, 790), Vector2(260, 660),
			Vector2(360, 800), Vector2(470, 670), Vector2(580, 790), Vector2(700, 700),
			Vector2(720, 830)
		]
		draw_polyline(PackedVector2Array(pts), Color(0.52, 0.46, 0.38, 0.30), 2.0, true)
		draw_line(Vector2(0, 830), Vector2(720, 830), Color(0.38, 0.32, 0.24, 0.55), 2.0)
		# 淡墨点
		for i in 6:
			draw_circle(Vector2(60 + i * 118, 200 + (i % 3) * 150), 46.0, Color(0.45, 0.38, 0.30, 0.025))

# ---------------- 图标 ----------------
class Ico extends Control:
	var kind := "coin"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		if kind == "dot":
			draw_circle(c, minf(size.x, size.y) * 0.45, Color(0.85, 0.66, 0.23))
			return
		if kind == "coin":
			draw_circle(c, r, Color(0.88, 0.69, 0.29))
			draw_arc(c, r, 0, TAU, 40, Color(0.36, 0.27, 0.12, 0.7), 2.0)
			draw_circle(c, r * 0.30, Color(0.10, 0.09, 0.08))
			draw_rect(Rect2(c - Vector2(r * 0.20, r * 0.20), Vector2(r * 0.40, r * 0.40)), Color(0.10, 0.09, 0.08), false, 3.0)
		elif kind == "crystal":
			var pts := PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.72, -r * 0.2), c + Vector2(r * 0.44, r * 0.9),
				c + Vector2(-r * 0.44, r * 0.9), c + Vector2(-r * 0.72, -r * 0.2)
			])
			draw_colored_polygon(pts, Color(0.49, 0.76, 0.85))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.16, 0.31, 0.36, 0.7), 2.0, true)
		else:
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(r * 0.50, -r * 0.50), Color(0.78, 0.35, 0.23), 5.0, true)
			draw_line(c + Vector2(-r * 0.55, -r * 0.55), c + Vector2(r * 0.50, r * 0.50), Color(0.78, 0.35, 0.23), 5.0, true)
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(r * 0.50, -r * 0.50), Color(0.88, 0.69, 0.29), 4.0, true)

class Glyph extends Control:
	var kind := "sword"
	var col := Color(0.13, 0.12, 0.11)
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.40
		if kind == "sword":
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(r * 0.55, -r * 0.55), col, 6.0, true)
			draw_line(c + Vector2(-r * 0.15, r * 0.15), c + Vector2(r * 0.35, -r * 0.35), Color(0.79, 0.64, 0.24), 4.0, true)
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(-r * 0.30, r * 0.30), Color(0.55, 0.18, 0.14), 4.0, true)
		elif kind == "spear":
			draw_line(c + Vector2(-r * 0.6, r * 0.25), c + Vector2(r * 0.45, -r * 0.20), col, 4.0, true)
			var tip := c + Vector2(r * 0.52, -r * 0.25)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-r * 0.18, -r * 0.02), tip + Vector2(-r * 0.12, r * 0.17)]), Color(0.79, 0.64, 0.24))
		else:
			draw_line(c + Vector2(-r * 0.35, r * 0.40), c + Vector2(r * 0.45, -r * 0.40), col, 5.0, true)
			draw_line(c + Vector2(-r * 0.35, -r * 0.40), c + Vector2(r * 0.45, r * 0.40), col, 5.0, true)

class EnemyArt extends Control:
	var r := 30.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, r, Color(0.86, 0.81, 0.70))
		draw_arc(c, r, 0, TAU, 40, Color(0.16, 0.13, 0.10, 0.8), 2.0)
		draw_circle(c + Vector2(-r * 0.28, -r * 0.10), r * 0.07, Color(0.16, 0.13, 0.10, 0.8))
		draw_circle(c + Vector2(r * 0.28, -r * 0.10), r * 0.07, Color(0.16, 0.13, 0.10, 0.8))
		draw_line(c + Vector2(-r * 0.22, r * 0.25), c + Vector2(r * 0.22, r * 0.25), Color(0.16, 0.13, 0.10, 0.55), 1.5, true)

class AvatarArt extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var tex := preload("res://assets/char/player_q.png")
		if tex:
			var s := minf(size.x, size.y) * 0.92
			draw_texture_rect(tex, Rect2(c - Vector2(s * 0.5, s * 0.5), Vector2(s, s)), false)
		draw_arc(c, size.x * 0.50, 0, TAU, 48, Color(0.85, 0.66, 0.23, 0.9), 3.0)


class CardSlot extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal pressed
	var empty := false
	var quality := 3
	var shiny := false
	var art: Texture2D = null
	var idx = 0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		if empty:
			var c := Color(0.42, 0.36, 0.28, 0.45)
			draw_dashed_line(Vector2(2,2), Vector2(size.x-2,2), c, 2.0, 6.0)
			draw_dashed_line(Vector2(size.x-2,2), Vector2(size.x-2,size.y-2), c, 2.0, 6.0)
			draw_dashed_line(Vector2(size.x-2,size.y-2), Vector2(2,size.y-2), c, 2.0, 6.0)
			draw_dashed_line(Vector2(2,size.y-2), Vector2(2,2), c, 2.0, 6.0)
			draw_string(F, size * 0.5 + Vector2(-10, 7), "空", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.42,0.36,0.28,0.55))
			return
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.93, 0.86, 0.98)
		sb.set_corner_radius_all(8)
		sb.border_color = QC[clampi(quality-1,0,4)]
		sb.set_border_width_all(5)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if art != null:
			draw_texture_rect(art, Rect2(8, 8, size.x - 16, size.y - 16), false)
		if shiny:
			var cols := [Color(0.85,0.28,0.30), Color(0.93,0.58,0.22), Color(0.90,0.80,0.28),
				Color(0.38,0.70,0.42), Color(0.32,0.62,0.85), Color(0.62,0.42,0.82)]
			for i in 6:
				var sb2 := StyleBoxFlat.new()
				sb2.bg_color = Color(0, 0, 0, 0)
				sb2.set_corner_radius_all(10)
				sb2.border_color = cols[i]
				sb2.set_border_width_all(2)
				draw_style_box(sb2, Rect2(Vector2(-2.0 - float(i) * 2.0, -2.0 - float(i) * 2.0),
					size + Vector2(4.0 + float(i) * 4.0, 4.0 + float(i) * 4.0)))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

class DrawCard extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal picked
	var data: Dictionary = {}
	var _art_rect: TextureRect
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_art_rect = TextureRect.new()
		_art_rect.position = Vector2(40, 52)
		_art_rect.size = Vector2(120, 120)
		_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_art_rect)
	func _draw() -> void:
		if data.is_empty():
			if _art_rect != null:
				_art_rect.visible = false
			return
		if _art_rect != null:
			_art_rect.visible = true
		var q := clampi(int(data.get("quality", 3)) - 1, 0, 4)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.93, 0.86, 0.99)
		sb.set_corner_radius_all(9)
		sb.border_color = QC[q]
		sb.set_border_width_all(6)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if bool(data.get("shiny", false)):
			# 炫卡：七彩描边由外向内
			var cols := [Color(0.85,0.28,0.30), Color(0.93,0.58,0.22), Color(0.90,0.80,0.28),
				Color(0.38,0.70,0.42), Color(0.32,0.62,0.85), Color(0.62,0.42,0.82)]
			for i in 6:
				var sp := StyleBoxFlat.new()
				sp.bg_color = Color(0, 0, 0, 0)
				sp.set_corner_radius_all(10)
				sp.border_color = cols[i]
				sp.set_border_width_all(2)
				draw_style_box(sp, Rect2(Vector2(-2.0 - float(i) * 2.0, -2.0 - float(i) * 2.0),
					size + Vector2(4.0 + float(i) * 4.0, 4.0 + float(i) * 4.0)))
		draw_string(F, Vector2(0, 34), str(data.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.14,0.11,0.08))
		var tex := load(str(data.get("art", "")))
		if _art_rect != null:
			_art_rect.texture = tex
		draw_string(F, Vector2(20, 204), str(data.get("own_text", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 21, Color(0.14,0.11,0.08))
		draw_line(Vector2(20, 220), Vector2(size.x - 20, 220), Color(0.5,0.4,0.25,0.35), 1.5)
		if bool(data.get("shiny", false)):
			# 炫卡：不显示组合进度，改成吞噬说明
			draw_string(F, Vector2(20, 240), "进卡组即吞尽全部家传卡", HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 16, Color(0.42,0.30,0.12))
			draw_string(F, Vector2(20, 264), "每吞一张：灵晶+20 · 文钱+150", HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 14, Color(0.2,0.16,0.12))
			draw_string(F, Vector2(20, 284), "　　　　　技能伤害 +10%", HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 14, Color(0.2,0.16,0.12))
		else:
			draw_string(F, Vector2(20, 246), str(data.get("combo_name", "")) + " 0/" + str(data.get("set_size", 0)), HORIZONTAL_ALIGNMENT_LEFT, 140, 18, Color(0.42,0.30,0.12))
			draw_string(F, Vector2(20, 280), str(data.get("trigger", "")) + "：" + str(data.get("combo_text", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 17, Color(0.2,0.16,0.12))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()


func _build_bg() -> void:
	var bg := BgArt.new()
	bg.size = Vector2(W, H)
	add_child(bg)

func _chip(x: float, kind: String, value: String, cap: String) -> Label:
	_panel(Rect2(x, 8, 216, 64), Color(0.075, 0.068, 0.060, 0.98), 8, Color(0.85, 0.66, 0.23, 0.45), 1)
	var ic := Ico.new()
	ic.kind = kind
	ic.position = Vector2(x + 12, 21)
	ic.size = Vector2(38, 38)
	add_child(ic)
	var vl := _lbl(value, Vector2(x + 58, 4), Vector2(146, 36), 28, Color(0.95, 0.91, 0.83), self, HORIZONTAL_ALIGNMENT_RIGHT)
	_lbl(cap, Vector2(x + 58, 40), Vector2(146, 20), 17, Color(0.80, 0.75, 0.65), self, HORIZONTAL_ALIGNMENT_RIGHT)
	return vl

func _build_hud() -> void:
	_coin_lb = _chip(24, "coin", "0", "文钱")
	_crystal_lb = _chip(252, "crystal", "100", "灵晶")
	_kill_lb = _chip(480, "kill", "0", "杀敌")
	_wave_lb = _lbl("波 1/5", Vector2(22, 92), Vector2(100, 48), 26, INK)
	for i in 5:
		var d := Color(0.85, 0.66, 0.23) if i == 0 else Color(0.38, 0.33, 0.26, 0.55)
		var c := Control.new()
		c.position = Vector2(112 + i * 18 - 6, 117 - 6)
		c.size = Vector2(12, 12)
		var ci := Ico.new()
		ci.kind = "dot"
		ci.position = Vector2.ZERO
		ci.size = Vector2(12, 12)
		ci.modulate = Color(1, 1, 1, 1) if i == 0 else Color(0.52, 0.47, 0.40, 1)
		c.add_child(ci)
		add_child(c)
	_panel(Rect2(200, 92, 235, 20), Color(0.10, 0.09, 0.08, 0.35), 3)
	_hp_fill = _panel(Rect2(200, 92, 235 * 0.70, 20), Color(0.61, 0.16, 0.13), 3)
	_hp_lb = _lbl("200/200", Vector2(208, 88), Vector2(120, 28), 17, Color(0.98, 0.95, 0.88))
	_panel(Rect2(200, 118, 235, 9), Color(0.10, 0.09, 0.08, 0.22), 4)
	_mp_bar = _panel(Rect2(200, 118, 235 * 0.35, 9), Color(0.30, 0.52, 0.72), 4)
	_lbl("首领 00:37", Vector2(450, 96), Vector2(120, 30), 17, SEAL)
	_btn("总计", Rect2(570, 88, 68, 42), 17, Color(0.10, 0.09, 0.08, 0.98), LIGHT, func(): _show_totals())
	_btn("退出", Rect2(646, 88, 60, 42), 17, Color(0.10, 0.09, 0.08, 0.98), LIGHT, func(): _show_exit(true))

# ---------------- 战场 ----------------
func _build_field() -> void:
	_core = BattleCore.new()
	_core.position = Vector2(8, 150)
	_core.size = Vector2(704, 650)
	_core.mouse_filter = Control.MOUSE_FILTER_STOP
	_core.modulate = Color(1, 1, 1, 0.25)
	add_child(_core)
	_core.setup({"atk": 12.0, "hp_max": 200.0, "mp_max": 100.0})
	_core.set_wave(1)
	_core.coin.connect(_on_core_coin)
	_core.coin_drop.connect(_on_coin_drop)   # v6：钱怪/匪首掉的真钱
	_core.kill.connect(_on_core_kill)
	_core.hero_attack.connect(_on_hero_attack)
	_core.hero_hit.connect(_on_hero_hit)
	_core.hero_foe_hit.connect(_on_hero_foe_hit)
	_core.hero_down.connect(func() -> void: _toast("倒下了"))
	_core.boss_arrived.connect(func(_t: int) -> void: _toast("首领来了"))
	_core.start_run()
	# 旧内核的隐形宠物会偷偷咬怪（怪还没到就掉血）；这个模式先关掉宠物伤害
	_core.set_pet_cfg({"cd": 99999.0, "dmg": 0.0})
	_core._pet_cd = 99999.0
	_hero_token = TokenActor.new()
	_hero_token.setup(PLAYER_TEX, 44.0, Color(0.85, 0.66, 0.23), true)
	_hero_token.set_role("player")
	_hero_token.set_weapon("sword")
	_hero_token.show_bar = false          # 主角血条只看顶部 HUD，不再挂漂浮血条
	_hero_token.bar_w = 0.0
	_hero_token.unit_name = ""
	_hero_token.position = _core.position + _core.hero_pos
	_hero_token.z_index = 6
	add_child(_hero_token)
	var hit := Button.new()
	hit.position = Vector2(312, 710)
	hit.size = Vector2(96, 96)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hit.pressed.connect(func(): _show_attr(true))
	add_child(hit)
	_hero_hit_btn = hit
	_hero_hit_btn.position = _hero_token.position - Vector2(48, 48)
	# 挑战方形
	_btn("挑战", Rect2(0, 680, 96, 96), 20, Color(0.075, 0.068, 0.060, 0.98), Color(0.91, 0.78, 0.42), func(): _toggle_challenge())
	_build_challenge()
	_build_card_detail()
	# v3 技能栏（右缘竖排，6 格可视）
	_build_skill_bar()
	# 攻击表现层：后层在牌下面（剑/弧被牌挡住），前层在牌上面（白边/淡红/数字）
	_fx_back = AttackFx.new()
	_fx_back.front = false
	_fx_back.position = FIELD_POS
	_fx_back.size = Vector2(704, 650)
	_fx_back.z_index = 4
	_fx_back.clip_contents = true
	add_child(_fx_back)
	_fx_front = AttackFx.new()
	_fx_front.front = true
	_fx_front.position = FIELD_POS
	_fx_front.size = Vector2(704, 650)
	_fx_front.z_index = 7
	_fx_front.clip_contents = true
	add_child(_fx_front)
	_hero_name_lb = _lbl("少侠", _hero_token.position + Vector2(-60, 52), Vector2(120, 24),
		18, Color(0.30, 0.24, 0.16, 0.9), self, HORIZONTAL_ALIGNMENT_CENTER)
	_hero_name_lb.z_index = 9

class SkillIcon extends Control:
	const F := preload("res://fonts/ink.ttf")
	const G := preload("res://shared/glyph_draw.gd")
	signal pressed
	var kind := "sword"
	var cd := 0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 19, Color(0.93, 0.90, 0.82))
		draw_arc(c, 19, 0, TAU, 32, Color(0.85, 0.66, 0.23, 0.85) if cd == 0 else Color(0.45, 0.39, 0.31, 0.8), 2.0)
		G.draw(self, c, 17.0, kind, Color(0.13, 0.12, 0.11))
		if cd > 0:
			draw_circle(c, 19, Color(0.06, 0.05, 0.05, 0.45))
			draw_string(F, c + Vector2(-8, 7), str(cd), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.96, 0.90, 0.74))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

func _toggle_challenge() -> void:
	_chal_layer.visible = not _chal_layer.visible
	if _chal_layer.visible:
		_chal_layer.move_to_front()

func _build_challenge() -> void:
	_chal_layer = Control.new()
	_chal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chal_layer.visible = false
	_chal_layer.z_index = 15
	add_child(_chal_layer)
	_panel(Rect2(8, 360, 320, 320), Color(0.94, 0.90, 0.82, 0.98), 8, Color(0.85, 0.66, 0.23, 0.6), 2, _chal_layer)
	var names := ["钱怪", "晶怪", "书怪", "宝箱", "匪首"]
	for i in names.size():
		var x := 28.0 + float(i % 2) * 140.0
		var y := 380.0 + float(i / 2) * 96.0
		_btn(names[i], Rect2(x, y, 76, 76), 18, Color(0.09, 0.08, 0.07, 0.98), Color(0.91, 0.78, 0.42), func(): _toast("挑战：" + names[i]); _chal_layer.visible = false, _chal_layer)

func _build_card_detail() -> void:
	_detail_layer = Control.new()
	_detail_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_layer.visible = false
	_detail_layer.z_index = 30
	add_child(_detail_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_detail_layer.visible = false)
	_detail_layer.add_child(dim)
	_detail_card = Panel.new()
	_detail_card.position = Vector2(210, 420)
	_detail_card.size = Vector2(300, 420)
	_detail_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_layer.add_child(_detail_card)
	_detail_name = _lbl("青锋", Vector2(230, 438), Vector2(260, 40), 30, INK, _detail_layer, HORIZONTAL_ALIGNMENT_CENTER)
	_detail_art = TextureRect.new()
	_detail_art.position = Vector2(230, 486)
	_detail_art.size = Vector2(260, 150)
	_detail_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_detail_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_layer.add_child(_detail_art)
	_lbl("效 果", Vector2(230, 650), Vector2(120, 26), 18, DIM, _detail_layer)
	_detail_effect = _lbl("攻击 +6", Vector2(230, 678), Vector2(260, 36), 26, INK, _detail_layer)
	_lbl("组 合", Vector2(230, 728), Vector2(120, 26), 18, DIM, _detail_layer)
	_detail_combo = _lbl("成长 1/3", Vector2(300, 728), Vector2(120, 28), 22, Color(0.54, 0.35, 0.12), _detail_layer)
	for i in 6:
		var pip := ColorRect.new()
		pip.position = Vector2(424 + i * 14, 734)
		pip.size = Vector2(11, 11)
		pip.color = Color(0.42, 0.36, 0.28, 0.3)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_detail_layer.add_child(pip)
		_detail_pips.append(pip)
	_detail_combo_text = _lbl("成长：杀敌提升 1 点攻击", Vector2(230, 768), Vector2(260, 44), 17, INK, _detail_layer)
	_btn("×", Rect2(574, 430, 40, 34), 22, Color(0.95, 0.91, 0.83), DIM, func(): _detail_layer.visible = false, _detail_layer)

# ---------------- 卡组 ----------------
func _build_deck() -> void:
	_deck_count_lb = _lbl("卡组 0/10", Vector2(22, 840), Vector2(160, 30), 20, INK)
	_page_lb = _lbl("1/2", Vector2(330, 840), Vector2(60, 30), 17, DIM, self, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("<", Rect2(8, 890, 56, 60), 28, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _flip(-1))
	_btn(">", Rect2(656, 890, 56, 60), 28, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _flip(1))
	for i in 5:
		var s := CardSlot.new()
		s.position = Vector2(46 + i * 132, 870)
		s.size = Vector2(100, 100)
		s.idx = ""
		s.pressed.connect(func(): _pick_card(str(s.idx)))
		add_child(s)
		_slots.append(s)

func _flip(d: int) -> void:
	_page = (_page + d + 2) % 2
	_refresh_deck()

func _refresh_deck() -> void:
	if _page_lb:
		_page_lb.text = str(_page + 1) + "/2"
	if _deck_count_lb:
		_deck_count_lb.text = "卡组 " + str(_cards.size()) + "/10"
	for i in _slots.size():
		var s: CardSlot = _slots[i]
		var at := _page * 5 + i
		if at < _cards.size():
			var id := str(_cards[at])
			var c: Dictionary = _card_db[id]
			s.empty = false
			s.idx = id
			s.quality = int(c["quality"])
			s.shiny = bool(c.get("shiny", false))
			s.art = load(str(c["art"]))
			s.queue_redraw()
		else:
			s.empty = true
			s.idx = ""
			s.queue_redraw()

func _pick_card(id: String) -> void:
	if id == "" or not _card_db.has(id): return
	var c: Dictionary = _card_db[id]
	_detail_name.text = str(c["name"])
	_detail_art.texture = load(str(c["art"]))
	_detail_effect.text = str(c["own_text"])
	var prog := _set_progress(str(c["set_id"]))
	_detail_combo.text = str(c["combo_name"]) + " " + str(prog) + "/" + str(c["set_size"])
	_detail_combo_text.text = str(c["trigger"]) + "：" + str(c["combo_text"])
	var q := clampi(int(c["quality"]) - 1, 0, 4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.86, 0.99)
	sb.set_corner_radius_all(9)
	sb.border_color = QUALITY_COLORS[q]
	sb.set_border_width_all(7)
	_detail_card.add_theme_stylebox_override("panel", sb)
	var set_n := int(c["set_size"])
	for i in _detail_pips.size():
		var pip := _detail_pips[i] as ColorRect
		pip.visible = i < set_n
		pip.color = Color(0.78, 0.58, 0.22) if i < prog else Color(0.42, 0.36, 0.28, 0.3)
	_detail_layer.visible = true
	_detail_layer.move_to_front()

# ---------------- 底栏 ----------------
func _build_bottom() -> void:
	_panel(Rect2(8, 980, 704, 240), Color(0.075, 0.068, 0.060, 0.98), 10, Color(0.85, 0.66, 0.23, 0.45), 2)
	_lv_lb = _lbl("Lv 1", Vector2(22, 992), Vector2(70, 28), 18, GOLD)
	_panel(Rect2(96, 992, 520, 12), Color(0.93, 0.90, 0.82, 0.16), 6)
	_exp_bar = _panel(Rect2(96, 992, 4, 12), Color(0.85, 0.66, 0.23), 6)
	_exp_lb = _lbl("0/100", Vector2(616, 986), Vector2(90, 24), 16, Color(0.80, 0.75, 0.65), self, HORIZONTAL_ALIGNMENT_RIGHT)
	_tile(24, 1020, 124, "market", "黑市", false)
	_trea_tile = _tile(158, 1020, 124, "treasure", "宝物", false)
	_mate_tile = _tile(292, 1020, 124, "mate", "请神", false)
	_str_tile = _tile(426, 1020, 124, "skill", "强化", false)
	_tile(560, 1008, 136, "draw", "抽卡", true)
	_refresh_level_ui()
	_refresh_str_tile()
	_refresh_trea_tile()

func _tile(x: float, y: float, s: float, kind: String, label: String, hot: bool):
	var t := Tile.new()
	t.position = Vector2(x, y)
	t.size = Vector2(s, s)
	t.kind = kind
	t.label = label
	t.hot = hot
	var hit := func() -> void:
		match kind:
			"draw": _show_draw(true)
			"market": _toast("黑市")
			"treasure": _on_trea_tile()
			"mate": _on_mate_tile()
			"skill": _on_str_tile()
			_: _toast(label)
	t.pressed.connect(hit)
	add_child(t)
	return t

class Tile extends Control:
	const F := preload("res://fonts/ink.ttf")
	signal pressed
	var kind := "market"
	var label := ""
	var hot := false
	var badge := 1
	var sub := ""          # 小字（强化：Lv · 价钱）
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.48, 0.14, 0.10) if hot else Color(0.09, 0.08, 0.07, 0.98)
		sb.set_corner_radius_all(8)
		sb.border_color = Color(0.95, 0.76, 0.36, 0.95) if hot else Color(0.85, 0.66, 0.23, 0.5)
		sb.set_border_width_all(3 if hot else 1)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c := Vector2(size.x * 0.5, size.y * 0.34)
		var ink := Color(0.93, 0.88, 0.76) if hot else Color(0.88, 0.83, 0.73)
		if kind == "market":
			draw_circle(c, 20, Color(0.88, 0.69, 0.29))
			draw_circle(c, 8, Color(0.09, 0.08, 0.07))
		elif kind == "treasure":
			draw_rect(Rect2(c + Vector2(-24, -10), Vector2(48, 24)), Color(0.88, 0.83, 0.73))
			draw_rect(Rect2(c + Vector2(-24, -16), Vector2(48, 8)), Color(0.88, 0.69, 0.29))
			draw_rect(Rect2(c + Vector2(-4, -4), Vector2(8, 13)), Color(0.09, 0.08, 0.07))
		elif kind == "mate":
			draw_circle(c + Vector2(-11, -7), 9, Color(0.88, 0.83, 0.73))
			draw_circle(c + Vector2(11, -7), 9, Color(0.88, 0.83, 0.73))
			draw_circle(c + Vector2(-11, 13), 12, Color(0.88, 0.83, 0.73))
			draw_circle(c + Vector2(11, 13), 12, Color(0.88, 0.83, 0.73))
		elif kind == "skill":
			draw_rect(Rect2(c + Vector2(-17, -22), Vector2(34, 44)), Color(0.88, 0.83, 0.73))
			draw_rect(Rect2(c + Vector2(-2, -13), Vector2(4, 26)), Color(0.88, 0.69, 0.29))
			draw_rect(Rect2(c + Vector2(-13, -2), Vector2(26, 4)), Color(0.88, 0.69, 0.29))
		else:
			draw_set_transform(c + Vector2(-7, 2), -0.25, Vector2.ONE)
			draw_rect(Rect2(-16, -20, 22, 32), Color(0.93, 0.88, 0.76))
			draw_rect(Rect2(-2, -16, 22, 32), Color(0.88, 0.69, 0.29))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if sub != "":
			draw_string(F, Vector2(0, size.y - 40), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15,
				Color(0.86, 0.70, 0.34) if hot else Color(0.66, 0.59, 0.48))
		draw_string(F, Vector2(0, size.y - 14), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20 if size.x < 130 else 22, ink)
		if hot:
			draw_circle(Vector2(size.x - 15, 15), 11, Color(0.88, 0.69, 0.29))
			draw_string(F, Vector2(size.x - 23, 21), str(badge), HORIZONTAL_ALIGNMENT_CENTER, 18, 17, Color(0.18, 0.10, 0.05))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

# ---------------- 抽卡层 ----------------
func _build_draw() -> void:
	_draw_layer = Control.new()
	_draw_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.visible = false
	_draw_layer.z_index = 20
	add_child(_draw_layer)
	var banner := Panel.new()
	banner.position = Vector2(230, 162)
	banner.size = Vector2(260, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.54, 0.23, 0.10)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.95, 0.76, 0.36, 0.9)
	sb.set_border_width_all(2)
	banner.add_theme_stylebox_override("panel", sb)
	_draw_layer.add_child(banner)
	_lbl("抽卡 · 20 灵晶", Vector2(0, 0), Vector2(260, 42), 20, Color(0.97, 0.90, 0.74), banner, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("隐藏", Rect2(620, 162, 72, 32), 17, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _show_draw(false), _draw_layer)
	for i in 3:
		var d := DrawCard.new()
		d.position = Vector2(30 + i * 220, 220)
		d.set_meta("base", d.position)
		d.pivot_offset = Vector2(100, 150)
		d.size = Vector2(200, 300)
		d.picked.connect(func() -> void: _on_draw_pick(d))
		_draw_layer.add_child(d)
		_draw_cards.append(d)
	_btn("刷新 · 5 灵晶", Rect2(250, 540, 220, 56), 20, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _on_refresh(), _draw_layer)

func _roll_draw() -> void:
	var cands := _pool.duplicate()
	cands.shuffle()
	# v4 炫卡高权重：池里有炫卡时 80% 直接排到第一张
	var shiny_id := ""
	for pid_v in _pool:
		var pid := str(pid_v)
		if pid.begins_with("shiny_"):
			shiny_id = pid
			break
	if shiny_id != "" and randf() < 0.80:
		cands.erase(shiny_id)
		cands.push_front(shiny_id)
	for i in _draw_cards.size():
		var dc: DrawCard = _draw_cards[i]
		if i < cands.size():
			var c: Dictionary = (_card_db[str(cands[i])] as Dictionary).duplicate()
			c["_id"] = str(cands[i])
			dc.data = c
		else:
			dc.data = {}
		dc.queue_redraw()
	# v4 彩蛋：这三张里有某位祖宗的家传卡 → 4% 掷他的炫卡
	_roll_shiny_check(cands.slice(0, _draw_cards.size()))

# 彩蛋判定：只在「抽到该祖宗的家传卡」时掷，一局每位一次
func _roll_shiny_check(cards: Array) -> void:
	for cid_v in cards:
		var c: Dictionary = _card_db.get(str(cid_v), {})
		if not c.has("ancestor") or bool(c.get("shiny", false)):
			continue
		var aid := str(c["ancestor"])
		if _shiny_used.has(aid) or _shiny_rolled.has(aid):
			continue
		if randf() < 0.04:
			_shiny_rolled[aid] = true
			var sid := "shiny_" + aid
			if _card_db.has(sid) and not _pool.has(sid):
				_pool.append(sid)
				_toast("彩蛋！「%s」入池 —— 刷新就能看到" % str((_card_db[sid] as Dictionary)["name"]))
				Aud.sfx("ult_ready", -4.0)

func _update_crystal() -> void:
	if _crystal_lb != null:
		_crystal_lb.text = str(_crystal)

func _show_draw(v: bool) -> void:
	if v:
		_hide_aug_pick()                     # 进阶页开着一并收掉
		_hide_trea()                         # 宝物页同理
		if not _draw_paid:
			if _pool.is_empty():
				_toast("本局卡池已空")
				return
			if _crystal < 20:
				_toast("灵晶不够：抽卡要 20")
				return
			_crystal -= 20
			_update_crystal()
			_roll_draw()
			_draw_paid = true
		_draw_layer.visible = true
		_draw_layer.move_to_front()
		_pop_draw_cards()
	else:
		_draw_layer.visible = false
		_draw_open = false

func _on_draw_pick(card: DrawCard) -> void:
	if _draw_anim or card == null or card.data.is_empty(): return
	var id := str(card.data.get("_id", ""))
	if id == "": return
	if _cards.size() >= 10:
		_toast("卡组已满（10 格）")
		return
	_draw_anim = true
	var target := Vector2(46 + float(_cards.size() % 5) * 132.0, 870)
	for other in _draw_cards:
		if other != card:
			other.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tw0 := create_tween()
			tw0.tween_property(other, "modulate:a", 0.28, 0.18)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 3
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "position", target, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "scale", Vector2(0.36, 0.36), 0.34)
	tw.tween_property(card, "modulate:a", 0.42, 0.34)
	tw.chain().tween_callback(func() -> void:
		_draw_anim = false
		_add_card(id)
		_zhongli_try(id))

func _on_refresh() -> void:
	if _draw_anim: return
	if _pool.is_empty():
		_toast("卡池已空，没法刷新")
		return
	if _crystal < 5:
		_toast("灵晶不够：刷新要 5")
		return
	_crystal -= 5
	_update_crystal()
	_draw_anim = true
	for card in _draw_cards:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "scale", Vector2(0.72, 0.72), 0.16)
		tw.tween_property(card, "modulate:a", 0.0, 0.16)
	await get_tree().create_timer(0.2).timeout
	_roll_draw()
	_draw_anim = false
	_pop_draw_cards()
	_toast("刷新：5 灵晶")

func _pop_draw_cards() -> void:
	for i in _draw_cards.size():
		var card: DrawCard = _draw_cards[i]
		var base: Vector2 = card.get_meta("base", Vector2(30 + i * 220, 220))
		card.visible = true
		card.position = base + Vector2(0, 70)
		card.scale = Vector2(0.82, 0.82)
		card.modulate.a = 0.0
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "position", base, 0.24).set_delay(i * 0.055).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.24).set_delay(i * 0.055)
		tw.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(i * 0.055)

# ---------------- 属性 ----------------
func _build_attr() -> void:
	_attr_layer = Control.new()
	_attr_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_attr_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attr_layer.visible = false
	_attr_layer.z_index = 25
	add_child(_attr_layer)
	var p := Panel.new()
	p.position = Vector2(50, 300)
	p.size = Vector2(620, 240)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.92, 0.85)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.85, 0.66, 0.23, 0.7)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	_attr_layer.add_child(p)
	# v9：属性表改成**真数据**（原来写死 320/21/8/15%）
	var names := ["气血", "攻击", "速度", "暴伤", "护甲", "闪避", "暴击", "伤害"]
	_attr_val_lbs.clear()
	for r in 4:
		var y := 26.0 + float(r) * 42.0
		_lbl(names[r * 2], Vector2(30, y), Vector2(110, 30), 19, DIM, p)
		_attr_val_lbs.append(_lbl("-", Vector2(140, y), Vector2(120, 30), 21, INK, p, HORIZONTAL_ALIGNMENT_RIGHT))
		_lbl(names[r * 2 + 1], Vector2(330, y), Vector2(110, 30), 19, DIM, p)
		_attr_val_lbs.append(_lbl("-", Vector2(440, y), Vector2(120, 30), 21, INK, p, HORIZONTAL_ALIGNMENT_RIGHT))
	_lbl("羁绊与卡组看顶栏［总计］", Vector2(30, 206), Vector2(500, 24), 15, DIM, p)
	_btn("×", Rect2(566, 8, 44, 36), 22, Color(0.95, 0.92, 0.85), DIM, func(): _show_attr(false), p)

func _show_attr(v: bool) -> void:
	_attr_open = v
	_attr_layer.visible = v
	if v:
		_attr_layer.move_to_front()
		_refresh_attr_values()

# 属性表：直接从 core.hero 读（不再写死数字）
func _refresh_attr_values() -> void:
	if _core == null or _attr_val_lbs.size() < 8:
		return
	var h: Dictionary = _core.hero
	var vals := [
		"%d/%d" % [int(float(h.get("hp", 0))), int(float(h.get("hp_max", 1)))],
		"%.0f" % float(h.get("atk", 0.0)),
		"%.2f" % float(h.get("aspd", 1.0)),
		"%d%%" % int(round(float(h.get("crit_dmg", 2.0)) * 100.0)),
		"%d%%" % int(round(float(h.get("cut", 0.0)) * 100.0)),
		"%d%%" % int(round(float(h.get("dodge", 0.0)) * 100.0)),
		"%d%%" % int(round(float(h.get("crit", 0.0)) * 100.0)),
		"+%d%%" % int(round(float(h.get("dmg_all", 0.0)) * 100.0)),
	]
	for i in 8:
		if i < _attr_val_lbs.size():
			(_attr_val_lbs[i] as Label).text = str(vals[i])


# ---------------- 退出 ----------------
func _build_exit() -> void:
	_exit_layer = Control.new()
	_exit_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_layer.visible = false
	_exit_layer.z_index = 30
	add_child(_exit_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_layer.add_child(dim)
	var p := Panel.new()
	p.position = Vector2(150, 500)
	p.size = Vector2(420, 220)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.86)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(0.85, 0.66, 0.23, 0.8)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	_exit_layer.add_child(p)
	_lbl("是否退出？", Vector2(0, 34), Vector2(420, 40), 26, INK, p, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl("退出后本局作废，奖励不保留", Vector2(0, 78), Vector2(420, 30), 17, SEAL, p, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("继续战斗", Rect2(60, 130, 150, 48), 18, Color(0.09, 0.08, 0.07, 0.98), LIGHT, func(): _show_exit(false), p)
	_btn("退出", Rect2(220, 130, 140, 48), 18, Color(0.48, 0.14, 0.10), Color(0.97, 0.90, 0.74), func(): _quit(), p)

func _show_exit(v: bool) -> void:
	_exit_open = v
	_exit_layer.visible = v
	if v:
		_exit_layer.move_to_front()

func _quit() -> void:
	get_tree().change_scene_to_file("res://menu/main_home.tscn")

# ---------------- 提示/动画 ----------------
func _build_toast() -> void:
	_toast_lb = RichTextLabel.new()
	_toast_lb.bbcode_enabled = true
	_toast_lb.fit_content = false
	_toast_lb.scroll_active = false
	_toast_lb.position = Vector2(0, 620)
	_toast_lb.size = Vector2(720, 48)
	_toast_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_lb.add_theme_font_override("normal_font", FONT)
	_toast_lb.add_theme_font_size_override("normal_font_size", 26)
	_toast_lb.add_theme_color_override("default_color", INK)
	_toast_lb.visible = false
	_toast_lb.z_index = 40
	add_child(_toast_lb)

func _toast_card(name: String, quality: int, tail: String) -> void:
	var col: String = QUALITY_COLORS[clampi(quality - 1, 0, 4)].to_html(false)
	_toast("[color=#" + col + "]" + name + "[/color]　" + tail)

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _enemies.size():
		var e: Control = _enemies[i]
		e.position.y = float(e.get_meta("base_y", e.position.y)) + sin(t * 1.6 + i) * 2.0
	if _core != null:
		if int(_core.wave) != _last_wave:
			_last_wave = int(_core.wave)
			_trigger_combos("每波")
		_combo_t += _delta
		if _combo_t >= 6.0:
			_combo_t -= 6.0
			_trigger_combos("每 6 秒")
		if _wave_lb != null:
			_wave_lb.text = "波 %d/%d" % [int(_core.wave), MAX_WAVE]
		# v2 波次推进：本波定额刷完 + 场上清空 → 进下一波；满 MAX_WAVE 收工
		if not _run_cleared and _core.wave_cleared():
			var cleared_wave := int(_core.wave)
			if cleared_wave < MAX_WAVE:
				_core.set_wave(cleared_wave + 1)
				_core.wave_reset_quota()
				_spawn_typed_foes()
				_on_wave_clear(cleared_wave)
			else:
				_run_cleared = true
				_toast("第 %d 波清空 · 本局收工" % MAX_WAVE)
		if _hp_lb != null:
			_hp_lb.text = "%d/%d" % [int(float(_core.hero.get("hp", 0))), int(float(_core.hero.get("hp_max", 1)))]
		var hpr := clampf(float(_core.hero.get("hp", 0.0)) / maxf(1.0, float(_core.hero.get("hp_max", 1.0))), 0.0, 1.0)
		if _hp_fill != null:
			_hp_fill.size = Vector2(maxf(4.0, 235.0 * hpr), 20.0)
		_tick_skills(_delta)
		_tick_minions(_delta)
		_tick_burn(_delta)
		_tick_poison(_delta)
		_tick_vuln(_delta)
		_tick_aura(_delta)
		_tick_stone(_delta)
		_tick_paper(_delta)
		_tick_rtype()
		_tick_shards(_delta)
		_tick_knock(_delta)
		if _hero_token != null:
			_hero_token.position = _core.position + _core.hero_pos
			_hero_token.hp_ratio = float(_core.hero.get("hp", 0.0)) / maxf(1.0, float(_core.hero.get("hp_max", 1.0)))
			_hero_token.queue_redraw()
			if _hero_hit_btn != null:
				_hero_hit_btn.position = _hero_token.position - Vector2(48, 48)
			if _hero_name_lb != null:
				_hero_name_lb.position = _hero_token.position + Vector2(-60, 52)
			var hhp := float(_core.hero.get("hp", 0.0))
			if _prev_hero_hp >= 0.0 and hhp < _prev_hero_hp - 0.05:
				_spawn_hit_fx(_hero_token.position, _hero_token.radius,
					int(round(_prev_hero_hp - hhp)), true, false, false)
				_hero_token.play_hit()
			_prev_hero_hp = hhp
		var active := {}
		for f in _core.foes:
			if not f.has("_tid"):
				_foe_seq += 1
				f["_tid"] = _foe_seq
				_foe_tokens[_foe_seq] = _make_foe_token(f)
			var tid: int = int(f["_tid"])
			active[tid] = true
			var tk = _foe_tokens.get(tid)
			if tk != null:
				tk.position = _core.position + Vector2(float(f["x"]), float(f["y"]))
				tk.hp_ratio = float(f["hp"]) / maxf(1.0, float(f["hp_max"]))
				tk.unit_name = str(f.get("name", ""))
				tk.visible = float(f.get("y", 0.0)) >= 90.0
				tk.queue_redraw()
		for tid in _foe_tokens.keys():
			if not active.has(tid):
				var tk = _foe_tokens[tid]
				if tk != null:
					tk.play_down()
				_foe_tokens.erase(tid)

func _on_core_kill(n: int) -> void:
	# v15 经验线：杀 1 只按 1+x% 只算（经验与所有按击杀成长的机制一起吃）
	var kn := int(round(float(n) * (1.0 + _killnum_pct / 100.0)))
	if kn < n:
		kn = n
	_kills += kn
	if _kill_lb != null:
		_kill_lb.text = str(_kills)
	_add_exp(20 * kn)                      # v2：杀 1 只 +20 经验
	_add_wen(int(round(float(WEN_KILL_BASE + WEN_KILL_WAVE * int(_core.wave)) * (1.0 + _kill_pct / 100.0))))
	if _qianzhi:
		for i in kn:
			_core.summon_minion("纸人", Color(0.95, 0.93, 0.86), 0.72, 0.5, 8.0 / 30.0, 1.0, 0.0, 99, "", "paper")
	if _undying_lamp:
		_lamp_kills += kn
		while _lamp_kills >= 5:
			_lamp_kills -= 5
			_aura_extra_radius += 10.0
	if _fentian:
		_ft_kills += kn
		while _ft_kills >= 15:
			_ft_kills -= 15
			_devour_random()
	if _swallow_sea:
		_ss_kills += kn
		while _ss_kills >= 10:
			_ss_kills -= 10
			_ss_pct += 4.0
			_toast("吞海 · 蛟龙属性 +4%%（累计 %d%%）" % int(_ss_pct))
	_trigger_combos("每次击杀")

# ---------------- 经验 / 等级 / 请神次数 ----------------
#   杀 1 只 +20 · 清一波 +50 · 升级需求 100 + 50×(级-1)
#   每升 1 级 → 请神次数 +1 → 底栏「请神」钮亮起
func _add_exp(v: int) -> void:
	if v <= 0:
		return
	_exp += int(round(float(v) * (1.0 + _exp_pct / 100.0)))
	var up := 0
	while _exp >= _exp_need:
		_exp -= _exp_need
		_lv += 1
		_exp_need += 50
		_draw_charge += 1
		up += 1
	_refresh_level_ui()
	if up > 0:
		_toast("升到 Lv %d · 请神 +%d" % [_lv, up])

func _refresh_level_ui() -> void:
	if _lv_lb != null:
		_lv_lb.text = "Lv " + str(_lv)
	if _exp_lb != null:
		_exp_lb.text = "%d/%d" % [_exp, _exp_need]
	if _exp_bar != null:
		var r := clampf(float(_exp) / maxf(1.0, float(_exp_need)), 0.0, 1.0)
		_exp_bar.size = Vector2(maxf(4.0, 520.0 * r), 12.0)
	if _mate_tile != null:
		var lit := _draw_charge > 0
		if _mate_tile.hot != lit:
			_mate_tile.hot = lit
			_mate_tile.queue_redraw()
		_mate_tile.badge = _draw_charge

func _on_wave_clear(cleared_wave: int) -> void:
	_add_exp(50)                            # v2：清一波 +50 经验
	_add_wen(WEN_WAVE_CLEAR * cleared_wave)  # v6：清一波给一笔文钱
	_trea_charge += 1                      # v8：清一波给一次宝物机会
	_refresh_trea_tile()
	_toast("第 %d 波清空" % cleared_wave)

func _on_mate_tile() -> void:
	if _draw_charge <= 0:
		_toast("升级后可请神")
		return
	_show_god_pick()

# ============================================================
# ---------------- 强化（v6）----------------
# ============================================================
func _str_cost() -> int:
	return STR_COST_BASE + STR_COST_STEP * _str_lv

func _refresh_str_tile() -> void:
	if _str_tile == null:
		return
	var cost := _str_cost()
	var s := "待选进阶" if _str_pending else "Lv %d · %d文" % [_str_lv, cost]
	var hot := _str_pending or _wen >= cost
	if _str_tile.sub != s or _str_tile.hot != hot:
		_str_tile.sub = s
		_str_tile.hot = hot
		_str_tile.queue_redraw()

# 点［强化］：扣文钱升一级；正好到 10 的倍数就开三选一
func _on_str_tile() -> void:
	if _str_pending:
		_open_aug_pick()                     # 上一手还没选 → 重新打开（不重复扣钱）
		return
	var cost := _str_cost()
	if _wen < cost:
		_toast("文钱不足：强化一次要 %d" % cost)
		return
	_wen -= cost
	if _coin_lb != null:
		_coin_lb.text = str(_wen)
	_str_lv += 1
	_apply_str_levels(1)
	Aud.sfx("ui_click", -6.0)
	_str_pop("强化 +1")
	if _str_lv % STR_EVERY == 0:
		_str_pending = true
		_aug_reroll += 1          # 每进一轮，刷新次数 +1
		_open_aug_pick()
	_refresh_str_tile()

# 点一下的即时反馈：［强化］钮上方冒一行字，往上飘走（不用 toast，免得连点排队）
func _str_pop(txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.position = Vector2(426, 998)
	l.size = Vector2(124, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 30
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 40.0, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.62).set_delay(0.18)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(l):
			l.queue_free())

# 每级的基础强化：直接写进 core.hero（血按比例涨，不白送满血）
func _apply_str_levels(n: int) -> void:
	if _core == null:
		return
	var h: Dictionary = _core.hero
	var ratio := 1.0
	if float(h["hp_max"]) > 0.0:
		ratio = clampf(float(h["hp"]) / float(h["hp_max"]), 0.0, 1.0)
	var add_atk := STR_PER_ATK * float(n)
	var add_hp := STR_PER_HP * float(n)
	h["atk"] = float(h["atk"]) + add_atk
	h["cut"] = float(h.get("cut", 0.0)) + STR_PER_CUT * float(n)
	h["hp_max"] = float(h["hp_max"]) + add_hp
	h["hp"] = float(h["hp_max"]) * ratio
	_stats["atk"] = float(_stats["atk"]) + add_atk
	_stats["hp"] = float(_stats["hp"]) + add_hp

# ---- 进阶三选一 ----
#   品阶随轮次涨：第 1 轮良 · 第 2 轮玄 · 第 3 轮地 · 第 4 轮起天；数值按 1 + 0.4×(轮-1) 放大
const AUG_POOL := [
	{"key": "atk_pct", "name": "破军", "glyph": "攻", "v": 15, "text": "攻击 +%d%%", "desc": "刀锋更利，出手见血"},
	{"key": "hp_pct", "name": "铁骨", "glyph": "骨", "v": 20, "text": "气血上限 +%d%%", "desc": "皮糙肉厚，扛得住"},
	{"key": "aspd_pct", "name": "疾风", "glyph": "疾", "v": 12, "text": "攻速 +%d%%", "desc": "抢在半招之前"},
	{"key": "crit_add", "name": "会心", "glyph": "会", "v": 8, "text": "暴击 +%d%%", "desc": "专挑要害招呼"},
	{"key": "critdmg_add", "name": "锐意", "glyph": "锐", "v": 25, "text": "暴击伤害 +%d%%", "desc": "暴击时更疼"},
	{"key": "cut_add", "name": "玄甲", "glyph": "甲", "v": 8, "text": "护甲 +%d%%", "desc": "只挡刀剑，不挡法术"},
	{"key": "cutall_add", "name": "金刚", "glyph": "刚", "v": 6, "text": "全伤害减免 +%d%%", "desc": "金木水火土一概硬扛"},
	{"key": "dodge_add", "name": "身法", "glyph": "身", "v": 6, "text": "闪避 +%d%%", "desc": "闪得开才有下一招"},
	{"key": "dmgall_add", "name": "剑意", "glyph": "意", "v": 10, "text": "全部伤害 +%d%%", "desc": "刀、术、火、召唤一起涨"},
	{"key": "mp_add", "name": "藏气", "glyph": "气", "v": 60, "text": "内力上限 +%d", "desc": "功法放得更勤"},
	{"key": "gold_pct", "name": "聚财", "glyph": "财", "v": 20, "text": "文钱 +%d%%", "desc": "杀得越多，来得越多"},
	{"key": "killheal", "name": "血战", "glyph": "血", "v": 3, "text": "击杀回血 +%d%%", "desc": "越杀越精神"},
]

# 进阶页：**照抽卡的排版**——三张卡直接浮在战场上（不遮暗、不暂停），
#   按钮只有两个：［刷新 · N 次］（次数型，用一次少一次）和［隐藏］。
func _build_str() -> void:
	_str_layer = Control.new()
	_str_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_str_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE     # 空白处放行给战场
	_str_layer.visible = false
	_str_layer.z_index = 21
	add_child(_str_layer)
	var ban := Panel.new()
	ban.position = Vector2(230, 162)
	ban.size = Vector2(260, 42)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.54, 0.23, 0.10)
	bsb.set_corner_radius_all(4)
	bsb.border_color = Color(0.95, 0.76, 0.36, 0.9)
	bsb.set_border_width_all(2)
	ban.add_theme_stylebox_override("panel", bsb)
	_str_layer.add_child(ban)
	_str_ban_lb = _lbl("进阶", Vector2(0, 0), Vector2(260, 42), 20, Color(0.97, 0.90, 0.74), ban, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("隐藏", Rect2(620, 162, 72, 32), 17, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _hide_aug_pick(), _str_layer)
	for i in 3:
		var d := AugCard.new()
		d.position = Vector2(30 + i * 220, 220)
		d.set_meta("base", d.position)
		d.pivot_offset = Vector2(100, 150)
		d.size = Vector2(200, 300)
		d.picked.connect(func() -> void: _on_aug_card(d))
		_str_layer.add_child(d)
		_aug_cards.append(d)
	_aug_refresh_btn = _btn("刷新 · 0 次", Rect2(140, 540, 200, 54), 19,
		Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _on_aug_refresh(), _str_layer)
	_btn("放弃 +1 刷新", Rect2(360, 540, 200, 54), 19,
		Color(0.09, 0.08, 0.07, 0.98), Color(0.80, 0.62, 0.34), func(): _on_aug_abandon(), _str_layer)

func _open_aug_pick() -> void:
	if _str_layer == null:
		return
	if _draw_layer != null:
		_draw_layer.visible = false                 # 抽卡页开着一并收掉，别叠在一起
	_hide_trea()
	_str_round = maxi(1, _str_lv / STR_EVERY)
	# 同一手只掷一次：点［隐藏］关了再点［强化］，看到的是同一手（不能白刷）
	if _aug_rolled_lv != _str_lv:
		_aug_rolled_lv = _str_lv
		_roll_aug()
	if _str_ban_lb != null:
		_str_ban_lb.text = "进阶 · 第 %d 级" % _str_lv
	_str_layer.visible = true
	_str_layer.move_to_front()
	_pop_aug_cards()
	Aud.sfx("ui_open", -8.0)

# 掷三张：品阶随轮次升（良→玄→地→天），数值 ×(1+0.4×(轮-1))
func _roll_aug() -> void:
	var r := maxi(1, _str_round)
	var mult := 1.0 + 0.4 * float(r - 1)
	var quality := clampi(1 + r, 2, 5)
	var pool: Array = AUG_POOL.duplicate()
	pool.shuffle()
	for i in _aug_cards.size():
		var ac: AugCard = _aug_cards[i]
		if i < pool.size():
			var o: Dictionary = (pool[i] as Dictionary).duplicate()
			ac.o = o
			ac.oval = int(round(float(o["v"]) * mult))
			ac.title = str(o["name"])
			ac.glyph = str(o["glyph"])
			ac.effect = str(o["text"]) % int(ac.oval)
			ac.desc = str(o["desc"])
			ac.quality = quality
			ac.visible = true
			ac.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			ac.visible = false
		ac.queue_redraw()
	_refresh_aug_btn()

func _refresh_aug_btn() -> void:
	if _aug_refresh_btn != null:
		_aug_refresh_btn.text = "刷新 · %d 次" % maxi(0, _aug_reroll)

# 刷新：次数型（不花文钱，但用一次少一次）
func _on_aug_refresh() -> void:
	if _str_layer == null or not _str_layer.visible:
		return
	if _aug_reroll <= 0:
		_toast("刷新次数用完了")
		return
	_aug_reroll -= 1
	_roll_aug()
	_pop_aug_cards()
	Aud.sfx("ui_click", -8.0)

# 放弃：这一轮进阶不要了，换 1 次刷新（刷新次数是攒着的，下次进阶能用）
func _on_aug_abandon() -> void:
	if not _str_pending:
		return
	_str_pending = false
	_aug_reroll += 1
	_hide_aug_pick()
	_refresh_str_tile()
	_refresh_aug_btn()
	_toast("放弃进阶 · 刷新 +1（现有 %d 次）" % _aug_reroll)
	Aud.sfx("ui_back", -8.0)

# 三张卡一起弹出来（跟抽卡一样的手感）
func _pop_aug_cards() -> void:
	for i in _aug_cards.size():
		var card: AugCard = _aug_cards[i]
		var base: Vector2 = card.get_meta("base", Vector2(30 + i * 220, 220))
		card.visible = true
		card.position = base + Vector2(0, 70)
		card.scale = Vector2(0.82, 0.82)
		card.modulate.a = 0.0
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "position", base, 0.24).set_delay(i * 0.055).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.24).set_delay(i * 0.055)
		tw.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(i * 0.055)

func _hide_aug_pick() -> void:
	if _str_layer != null:
		_str_layer.visible = false

func _on_aug_card(card: AugCard) -> void:
	if card == null or card.o.is_empty():
		return
	_pick_aug(card.o, int(card.oval))

func _pick_aug(o: Dictionary, val: int) -> void:
	_apply_aug(str(o["key"]), float(val))
	_str_pending = false
	_hide_aug_pick()
	_toast("进阶 · %s（%s）" % [str(o["name"]), str(o["text"]) % val])
	Aud.sfx("levelup", -6.0)
	_refresh_str_tile()

# ============================================================
# ---------------- 宝物（v8）----------------
# ============================================================
# 宝物 = 卡组羁绊（v9，用户："宝物暂定为卡组羁绊，有进度；凑齐 xx 和 xx 组合卡，效果增幅；宝物算消耗，不限件数"）
#   · 一张羁绊 = 要 3 个组合（如 三锋 / 铁壁 / 生机），凑齐 3/3 → 效果永久生效
#   · 进度按"这一局已经激活过的组合"算（_combined + _ancestor_combos，激活过的不会失效）
#   · **成的那一刻羁绊就消耗掉**（从身上删掉）→ 所以不占格子、也没有携带上限
#   · 品质随波数升（良/玄/地/天），只是把效果数值放大 ×1 / 1.5 / 2 / 3
const BOND_POOL := [
	{"name": "开门三式", "glyph": "三", "need": ["三锋", "铁壁", "生机"], "key": "dmgall_add", "v": 8, "text": "全部伤害 +%d%%", "desc": "攻守血，三才初成"},
	{"name": "锋芒", "glyph": "锋", "need": ["三锋", "蓄势", "战意"], "key": "atk_pct", "v": 15, "text": "攻击 +%d%%", "desc": "一路磨到顶"},
	{"name": "坚壁", "glyph": "壁", "need": ["铁壁", "龟息", "血守"], "key": "cut_add", "v": 6, "text": "护甲 +%d%%", "desc": "守在原地，寸步不让"},
	{"name": "生生", "glyph": "生", "need": ["生机", "回春", "不屈"], "key": "hp_pct", "v": 18, "text": "气血上限 +%d%%", "desc": "打不死的才叫活着"},
	{"name": "聚财", "glyph": "财", "need": ["聚财", "生息", "掠夺"], "key": "gold_pct", "v": 30, "text": "文钱 +%d%%", "desc": "钱要生钱才算钱"},
	{"name": "灵脉", "glyph": "灵", "need": ["灵涌", "凝晶", "猎晶"], "key": "mp_add", "v": 60, "text": "内力上限 +%d", "desc": "灵气灌顶，气走周天"},
	{"name": "攻守", "glyph": "守", "need": ["三锋", "铁壁", "龟息"], "key": "crit_add", "v": 7, "text": "暴击 +%d%%", "desc": "先站住，再找破绽"},
	{"name": "迅雷", "glyph": "疾", "need": ["蓄势", "灵涌", "聚财"], "key": "aspd_pct", "v": 12, "text": "攻速 +%d%%", "desc": "快一步，处处先手"},
	{"name": "血战", "glyph": "血", "need": ["血守", "不屈", "掠夺"], "key": "killheal", "v": 3, "text": "击杀回血 +%d%%", "desc": "杀得多，活得久"},
	{"name": "同源", "glyph": "源", "need": ["三锋", "聚财", "灵涌"], "key": "dmgall_add", "v": 10, "text": "全部伤害 +%d%%", "desc": "刀钱灵，本是一家"},
	{"name": "守拙", "glyph": "拙", "need": ["铁壁", "回春", "生息"], "key": "cutall_add", "v": 5, "text": "全伤害减免 +%d%%", "desc": "越笨的法子越管用"},
	{"name": "破阵", "glyph": "破", "need": ["战意", "血守", "掠夺"], "key": "critdmg_add", "v": 25, "text": "暴击伤害 +%d%%", "desc": "阵一破，人就散了"},
]

# 宝物页：和抽卡/进阶同一套排版，按钮三个：刷新 · N 次 / 隐藏 / 放弃 +1 刷新
func _build_trea() -> void:
	_trea_layer = Control.new()
	_trea_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trea_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trea_layer.visible = false
	_trea_layer.z_index = 22
	add_child(_trea_layer)
	var ban := Panel.new()
	ban.position = Vector2(230, 162)
	ban.size = Vector2(260, 42)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.54, 0.23, 0.10)
	bsb.set_corner_radius_all(4)
	bsb.border_color = Color(0.95, 0.76, 0.36, 0.9)
	bsb.set_border_width_all(2)
	ban.add_theme_stylebox_override("panel", bsb)
	_trea_layer.add_child(ban)
	_lbl("宝物 · 择一羁绊", Vector2(0, 0), Vector2(260, 42), 20, Color(0.97, 0.90, 0.74), ban, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("隐藏", Rect2(620, 162, 72, 32), 17, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _hide_trea(), _trea_layer)
	for i in 3:
		var d := AugCard.new()
		d.position = Vector2(30 + i * 220, 220)
		d.set_meta("base", d.position)
		d.pivot_offset = Vector2(100, 150)
		d.size = Vector2(200, 300)
		d.picked.connect(func() -> void: _on_trea_card(d))
		_trea_layer.add_child(d)
		_trea_cards.append(d)
	_trea_refresh_btn = _btn("刷新 · 0 次", Rect2(140, 540, 200, 54), 19,
		Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _on_trea_refresh(), _trea_layer)
	_btn("放弃 +1 刷新", Rect2(360, 540, 200, 54), 19,
		Color(0.09, 0.08, 0.07, 0.98), Color(0.80, 0.62, 0.34), func(): _on_trea_abandon(), _trea_layer)

# 品质随波数升：1-2 良 · 3 玄 · 4-5 地 · 6+ 天
func _trea_quality() -> int:
	var w := 1
	if _core != null:
		w = int(_core.wave)
	if w >= 6:
		return 5
	if w >= 4:
		return 4
	if w >= 3:
		return 3
	return 2

func _refresh_trea_tile() -> void:
	if _trea_tile == null:
		return
	var s := "待选羁绊" if _trea_pending else "羁绊 %d" % _bonds.size()
	var hot := _trea_pending or _trea_charge > 0
	if _trea_tile.sub != s or _trea_tile.hot != hot:
		_trea_tile.sub = s
		_trea_tile.hot = hot
		_trea_tile.queue_redraw()
	_trea_tile.badge = 1 if _trea_pending else maxi(0, _trea_charge)

# 点［宝物］：有一手没选就接着看那一手；否则花掉一次机会、掷三张
func _on_trea_tile() -> void:
	if _trea_pending:
		_open_trea()
		return
	if _trea_charge <= 0:
		_toast("还没攒到宝物机会（每清一波 +1）")
		return
	_trea_charge -= 1
	_trea_pending = true
	_roll_trea()
	_refresh_trea_tile()
	_open_trea()

func _open_trea() -> void:
	if _trea_layer == null:
		return
	if _draw_layer != null:
		_draw_layer.visible = false
	if _str_layer != null:
		_str_layer.visible = false
	_trea_layer.visible = true
	_trea_layer.move_to_front()
	_pop_trea_cards()
	Aud.sfx("ui_open", -8.0)

func _roll_trea() -> void:
	var q := _trea_quality()
	var mult: float = [1.0, 1.5, 2.0, 3.0][clampi(q - 2, 0, 3)]
	var pool: Array = BOND_POOL.duplicate()
	pool.shuffle()
	for i in _trea_cards.size():
		var c: AugCard = _trea_cards[i]
		if i < pool.size():
			var o: Dictionary = (pool[i] as Dictionary).duplicate()
			c.o = o
			c.oval = int(round(float(o["v"]) * mult))
			c.title = str(o["name"])
			c.glyph = str(o["glyph"])
			c.effect = str(o["text"]) % int(c.oval)
			c.desc = "需合成 " + "·".join(PackedStringArray(o["need"]))
			c.quality = q
			c.visible = true
			c.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			c.visible = false
		c.queue_redraw()
	_refresh_trea_btn()

func _refresh_trea_btn() -> void:
	if _trea_refresh_btn != null:
		_trea_refresh_btn.text = "刷新 · %d 次" % maxi(0, _trea_reroll)

func _pop_trea_cards() -> void:
	for i in _trea_cards.size():
		var card: AugCard = _trea_cards[i]
		var base: Vector2 = card.get_meta("base", Vector2(30 + i * 220, 220))
		card.visible = true
		card.position = base + Vector2(0, 70)
		card.scale = Vector2(0.82, 0.82)
		card.modulate.a = 0.0
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "position", base, 0.24).set_delay(i * 0.055).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.24).set_delay(i * 0.055)
		tw.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(i * 0.055)

func _hide_trea() -> void:
	if _trea_layer != null:
		_trea_layer.visible = false

func _on_trea_card(card: AugCard) -> void:
	if card == null or card.o.is_empty():
		return
	_pick_trea(card.o, int(card.oval))

func _pick_trea(o: Dictionary, val: int) -> void:
	var b := {"name": str(o["name"]), "need": (o["need"] as Array).duplicate(),
		"key": str(o["key"]), "val": int(val), "text": str(o["text"]), "prog": 0}
	_bonds.append(b)
	_trea_pending = false
	_hide_trea()
	_toast("结成羁绊 · %s（%d/%d，凑齐即消耗）" % [str(o["name"]), _bond_prog(b), (b["need"] as Array).size()])
	Aud.sfx("levelup", -6.0)
	_bond_check()
	_refresh_trea_tile()

# ---- 羁绊结算 ----
func _combo_has(nm: String) -> bool:
	for r_v in _combined:
		if str((r_v as Dictionary).get("name", "")) == nm:
			return true
	for r_v in _ancestor_combos:
		if str((r_v as Dictionary).get("name", "")) == nm:
			return true
	return false

func _bond_prog(b: Dictionary) -> int:
	var n := 0
	for nm_v in b["need"]:
		if _combo_has(str(nm_v)):
			n += 1
	return n

# 每次组合激活后都算一遍：凑齐 → 生效并**消耗**这张羁绊
func _bond_check() -> void:
	if _bonds.is_empty():
		return
	var changed := false
	for i in range(_bonds.size() - 1, -1, -1):
		var b: Dictionary = _bonds[i]
		var need: Array = b["need"]
		var prog := _bond_prog(b)
		b["prog"] = prog
		if prog >= need.size():
			_apply_aug(str(b["key"]), float(b["val"]))
			_bonds.remove_at(i)
			_bonds_done += 1
			_toast("羁绊成 · %s（%s）" % [str(b["name"]), str(b["text"]) % int(b["val"])])
			Aud.sfx("levelup", -6.0)
			changed = true
		elif prog > int(b.get("last", 0)):
			b["last"] = prog
			_toast("羁绊「%s」进度 %d/%d" % [str(b["name"]), prog, need.size()])
			changed = true
	if changed:
		_refresh_trea_tile()
		if _combined_layer != null and _combined_layer.visible and _tot_tab == "bond":
			_refresh_tot_bond()

# 刷新：次数型
func _on_trea_refresh() -> void:
	if _trea_layer == null or not _trea_layer.visible:
		return
	if _trea_reroll <= 0:
		_toast("刷新次数用完了")
		return
	_trea_reroll -= 1
	_roll_trea()
	_pop_trea_cards()
	Aud.sfx("ui_click", -8.0)

# 放弃：这一手不要了，换 1 次刷新（机会已经被这次开页吃掉，不能白刷）
func _on_trea_abandon() -> void:
	if not _trea_pending:
		return
	_trea_pending = false
	_trea_reroll += 1
	_hide_trea()
	_refresh_trea_tile()
	_refresh_trea_btn()
	_toast("放弃宝物 · 刷新 +1（现有 %d 次）" % _trea_reroll)
	Aud.sfx("ui_back", -8.0)

# 顶栏［总计］：打开总计页（顶部三个分类钮：卡组 / 宝物 / 组合）
func _show_totals() -> void:
	if _combined_layer == null:
		return
	_combined_layer.visible = true
	_combined_layer.move_to_front()
	_set_tot_tab(_tot_tab)

func _set_tot_tab(k: String) -> void:
	_tot_tab = k
	for i in _tot_tabs.size():
		var b: Button = _tot_tabs[i]
		var on := str(_tot_keys[i]) == k
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.48, 0.14, 0.10, 0.96) if on else Color(0.93, 0.90, 0.82, 0.98)
		sb.set_corner_radius_all(6)
		sb.border_color = Color(0.95, 0.76, 0.36, 0.95) if on else Color(0.55, 0.45, 0.30, 0.55)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(0.97, 0.90, 0.74) if on else Color(0.40, 0.33, 0.24))
		b.add_theme_color_override("font_hover_color", Color(0.97, 0.90, 0.74) if on else Color(0.24, 0.18, 0.10))
	if _tot_deck_root == null:
		return
	_tot_deck_root.visible = k == "deck"
	_tot_bond_root.visible = k == "bond"
	_combined_icons.visible = k == "combo"
	if k == "deck":
		_refresh_tot_deck()
	elif k == "bond":
		_refresh_tot_bond()
	else:
		_refresh_combined()

# 卡组分页：这一局抽到的卡
func _refresh_tot_deck() -> void:
	for ch in _tot_deck_root.get_children():
		ch.queue_free()
	var head := "卡组 %d/10" % _cards.size()
	if _core != null:
		head += "　·　攻击 %.0f　气血 %d/%d" % [float(_core.hero.get("atk", 0.0)),
			int(float(_core.hero.get("hp", 0))), int(float(_core.hero.get("hp_max", 1)))]
	_lbl(head, Vector2(0, 0), Vector2(600, 26), 18, DIM, _tot_deck_root)
	if _cards.is_empty():
		_lbl("卡组是空的 —— 去［抽卡］", Vector2(0, 40), Vector2(600, 30), 20,
			Color(0.55, 0.48, 0.36), _tot_deck_root)
		return
	for i in mini(_cards.size(), 10):
		var c: Dictionary = _card_db.get(str(_cards[i]), {})
		var y := 34.0 + float(i) * 58.0
		_panel(Rect2(0, y, 600, 50), Color(0.99, 0.97, 0.92, 0.92), 6, Color(0.55, 0.45, 0.30, 0.22), 1, _tot_deck_root)
		_lbl(str(c.get("name", "?")), Vector2(16, y + 10), Vector2(220, 30), 22,
			QUALITY_COLORS[clampi(int(c.get("quality", 1)) - 1, 0, 4)], _tot_deck_root)
		_lbl(str(c.get("own_text", "")), Vector2(250, y + 14), Vector2(330, 26), 17, INK,
			_tot_deck_root, HORIZONTAL_ALIGNMENT_RIGHT)

# 宝物分页：羁绊清单（进度 X/3 · 缺哪个组合 · 成后效果）
func _refresh_tot_bond() -> void:
	for ch in _tot_bond_root.get_children():
		ch.queue_free()
	_lbl("羁绊 %d 张（已消耗 %d）　·　凑齐 3 个组合即成　·　组合 = 同系同阶 3 张卡合成" % [_bonds.size(), _bonds_done],
		Vector2(0, 0), Vector2(600, 26), 16, DIM, _tot_bond_root)
	if _bonds.is_empty():
		_lbl("还没有羁绊 —— 每清一波有 1 次宝物机会", Vector2(0, 40), Vector2(600, 30), 20,
			Color(0.55, 0.48, 0.36), _tot_bond_root)
		return
	for i in mini(_bonds.size(), 8):
		var b: Dictionary = _bonds[i]
		var need: Array = b["need"]
		var miss: Array = []
		for nm_v in need:
			if not _combo_has(str(nm_v)):
				miss.append(str(nm_v))
		var y := 34.0 + float(i) * 76.0
		_panel(Rect2(0, y, 600, 68), Color(0.99, 0.97, 0.92, 0.92), 6, Color(0.55, 0.45, 0.30, 0.22), 1, _tot_bond_root)
		_lbl(str(b["name"]), Vector2(16, y + 6), Vector2(200, 30), 22, Color(0.46, 0.20, 0.10), _tot_bond_root)
		_lbl("%d/%d" % [_bond_prog(b), need.size()], Vector2(210, y + 8), Vector2(70, 28), 20,
			Color(0.30, 0.42, 0.28) if miss.is_empty() else Color(0.62, 0.42, 0.14), _tot_bond_root)
		_lbl(str(b["text"]) % int(b["val"]), Vector2(300, y + 10), Vector2(284, 26), 17, INK,
			_tot_bond_root, HORIZONTAL_ALIGNMENT_RIGHT)
		_lbl("已完成" if miss.is_empty() else ("缺 " + "·".join(PackedStringArray(miss))),
			Vector2(16, y + 38), Vector2(570, 24), 15, Color(0.48, 0.40, 0.30), _tot_bond_root)
	if _bonds.size() > 8:
		_lbl("…… 还有 %d 张" % (_bonds.size() - 8), Vector2(0, 34.0 + 8.0 * 76.0), Vector2(600, 24), 15, DIM, _tot_bond_root)

func _apply_aug(key: String, val: float) -> void:
	if _core == null:
		return
	var h: Dictionary = _core.hero
	match key:
		"atk_pct":
			h["atk"] = float(h["atk"]) * (1.0 + val / 100.0)
		"hp_pct":
			var ratio := 1.0
			if float(h["hp_max"]) > 0.0:
				ratio = clampf(float(h["hp"]) / float(h["hp_max"]), 0.0, 1.0)
			h["hp_max"] = float(h["hp_max"]) * (1.0 + val / 100.0)
			h["hp"] = float(h["hp_max"]) * ratio
		"aspd_pct":
			h["aspd"] = minf(MAX_ASPD, float(h.get("aspd", 1.0)) * (1.0 + val / 100.0))
		"crit_add":
			h["crit"] = minf(1.0, float(h.get("crit", 0.05)) + val / 100.0)
		"critdmg_add":
			h["crit_dmg"] = float(h.get("crit_dmg", 2.0)) + val / 100.0
		"cut_add":
			h["cut"] = float(h.get("cut", 0.0)) + val / 100.0
		"cutall_add":
			h["cut_all"] = float(h.get("cut_all", 0.0)) + val / 100.0
		"dodge_add":
			h["dodge"] = minf(0.75, float(h.get("dodge", 0.05)) + val / 100.0)
		"dmgall_add":
			h["dmg_all"] = float(h.get("dmg_all", 0.0)) + val / 100.0
		"mp_add":
			_mp_bonus += val
		"gold_pct":
			_gold_pct += val
		"killheal":
			_core.kill_heal = float(_core.kill_heal) + val / 100.0
		"exp_pct":
			_exp_pct += val

# 进阶卡：三选一的卡面（200×300）
class AugCard extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	const QN := ["良品", "玄品", "地品", "天品"]
	signal picked
	var title := ""
	var glyph := "攻"
	var effect := ""
	var desc := ""
	var quality := 2
	var o: Dictionary = {}      # 这一张掷到哪条进阶
	var oval := 0               # 放大后的数值
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var q := clampi(quality - 1, 0, 4)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.93, 0.86, 0.99)
		sb.set_corner_radius_all(9)
		sb.border_color = QC[q]
		sb.set_border_width_all(6)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		# 右上角品阶印（和抽卡卡面的"标题在最上"对齐，不抢标题的位置）
		var tp := Vector2(size.x - 62, 14)
		draw_rect(Rect2(tp, Vector2(48, 22)), QC[q])
		draw_string(F, tp + Vector2(0, 16), QN[clampi(quality - 2, 0, 3)],
			HORIZONTAL_ALIGNMENT_CENTER, 48, 13, Color(0.98, 0.96, 0.90))
		draw_string(F, Vector2(0, 52), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(0.14, 0.11, 0.08))
		var c := Vector2(size.x * 0.5, 150.0)
		draw_circle(c, 50, Color(0.93, 0.90, 0.82))
		draw_arc(c, 50.0, 0.0, TAU, 48, QC[q], 2.0)
		draw_string(F, c + Vector2(-15, 16), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0.13, 0.12, 0.11))
		draw_string(F, Vector2(0, 232), effect, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(0.46, 0.20, 0.10))
		draw_string(F, Vector2(10, 262), desc, HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 14, Color(0.38, 0.33, 0.26))
		draw_string(F, Vector2(0, 284), "点击选取", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(0.58, 0.50, 0.36))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()

func _make_foe_token(f: Dictionary):
	var kind := str(f.get("kind", "normal"))
	var boss := bool(f.get("boss", false))
	var rad := 36.0 if boss else 26.0
	var ring := Color(0.42, 0.36, 0.28)
	if kind == "coin":
		ring = Color(0.85, 0.66, 0.23)
	elif kind == "crystal":
		ring = Color(0.35, 0.55, 0.75)
	elif boss:
		ring = Color(0.68, 0.18, 0.14)
	var tk = TokenActor.new()
	tk.setup(null, rad, ring, false)
	tk.show_bar = true
	tk.bar_w = 84.0 if boss else 54.0
	tk.unit_name = str(f.get("name", ""))
	tk.z_index = 5
	tk.position = _core.position + Vector2(float(f["x"]), float(f["y"]))
	add_child(tk)
	var mark := Label.new()
	mark.text = "王" if boss else ("钱" if kind == "coin" else ("晶" if kind == "crystal" else "怪"))
	mark.position = Vector2(-rad, -rad * 2.0 + 6.0)
	mark.size = Vector2(rad * 2.0, rad * 1.5)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_override("font", FONT)
	mark.add_theme_font_size_override("font_size", 22 if not boss else 28)
	mark.add_theme_color_override("font_color", Color(0.30, 0.24, 0.16))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tk.add_child(mark)
	return tk

# ---------------- 卡池 / 组合 ----------------
func _init_cards() -> void:
	var d: Dictionary = CardData.build()
	_card_db = d["cards"]
	_set_cards = d["sets"]
	_pool = (d["entries"] as Array).duplicate()
	_cards.clear()
	_acquired.clear()
	_combined.clear()
	_ancestors.clear()
	_ancestor_combos.clear()
	# 家传卡：并进同一套卡表（形状与 5 系一致，所以直接合并）
	var a: Dictionary = AncestorData.build()
	var acards: Dictionary = a["cards"]
	for cid_v in acards.keys():
		_card_db[cid_v] = acards[cid_v]
	var asets: Dictionary = a["sets"]
	for sid_v in asets.keys():
		_set_cards[sid_v] = asets[sid_v]
	# 炫卡（独立卡，不进套）
	var shinies: Dictionary = AncestorData.shiny_cards()
	for sh_v in shinies.keys():
		_card_db[sh_v] = shinies[sh_v]
	_card_db["shiny_zhongli"] = {
		"id": "shiny_zhongli", "shiny": true, "ancestor": "", "ancestor_name": "",
		"series": "zhongli", "label": "重利", "tier": -1, "idx": 0,
		"name": "重利", "quality": 5, "art": "res://assets/items/loot_silver.png",
		"own_key": "", "own_val": 0, "own_text": "抽卡时 10% 复制选中卡",
		"set_id": "", "set_size": 0, "combo_name": "", "combo_text": "",
		"trigger": "", "combo_key": "", "combo_val": 0,
		"entry": false, "unlock_ids": [],
		"shiny_self": "抽卡时 10% 复制选中卡",
		"shiny_devour": "复制体当场吞噬 · 效果与进度保留",
		"shiny_per": "复制体再独立掷 · 链式"}
	_card_db["shiny_backwash"] = {
		"id": "shiny_backwash", "shiny": true, "ancestor": "", "ancestor_name": "",
		"series": "backwash", "label": "回潮", "tier": -1, "idx": 0,
		"name": "回潮", "quality": 4, "art": "res://assets/items/chest_jade.png",
		"own_key": "", "own_val": 0, "own_text": "攻 +4 · 防 +4 · 血 +40 · 内 +40",
		"set_id": "", "set_size": 0, "combo_name": "", "combo_text": "",
		"trigger": "", "combo_key": "", "combo_val": 0,
		"entry": false, "unlock_ids": [],
		"shiny_self": "攻 +4 · 防 +4 · 血 +40 · 内 +40",
		"shiny_devour": "进卡组即触发：波数回退 5 波",
		"shiny_per": ""}
	_backwash_done = false
	_anc_mod.clear()
	_elem_mod.clear()
	_shiny_rolled.clear()
	_shiny_used.clear()
	# 主角默认解锁：开局就把他的家传入口卡放进池（他走被动，不需要请）
	_grant_ancestor("zhujue")

# 请到一位祖宗：把它的「初级入口卡」放进抽卡池
func _grant_ancestor(aid: String) -> void:
	if aid == "mingzhu":
		_mingzhu = true
	if aid == "zhiyuan":
		_enable_zhiyuan()
	if aid == "chenshi2":
		_shixi = true
		_stone_def = float(_core.hero.get("def", 0.0)) if _core != null else 0.0
	if not AncestorData.ANCESTORS.has(aid):
		return
	_ancestors[aid] = 0
	var eid := "%s_t0_0" % aid
	if _card_db.has(eid) and not _pool.has(eid) and not _acquired.has(eid):
		_pool.append(eid)

# 家传组合激活：不做 5 系那套属性结算，只登记 + 解锁下一档入口
func _activate_ancestor_set(sid: String, first: Dictionary, ids: Array) -> void:
	var srcs: Array = []
	for cid_v in ids:
		var cid := str(cid_v)
		srcs.append(str((_card_db[cid] as Dictionary)["name"]))
		_cards.erase(cid)
	var ai := str(first["ancestor"])
	var t := int(first["tier"])
	_ancestor_combos.append({"ancestor": ai, "tier": t, "sources": srcs,
		"name": str(first["combo_name"]), "text": str(first["combo_text"])})
	_add_ancestor_effects(ai, first.get("effects", {}))
	if ai == "zhujue":
		_apply_hero_passive(first.get("effects", {}))
	_toast_card(str(first["combo_name"]), int(first["quality"]),
		"%s · %s（%d 张已清空）" % [str(first["ancestor_name"]), str(first["combo_text"]), ids.size()])
	var nid := "%s_t%d_0" % [ai, t + 1]
	if _card_db.has(nid) and not _pool.has(nid) and not _acquired.has(nid):
		_pool.append(nid)
		_toast_card(str((_card_db[nid] as Dictionary)["name"]), int(first["quality"]), "下一档入口已入池")
	_page = 0
	_refresh_deck()
	_bond_check()
	if _combined_layer != null and _combined_layer.visible:
		_refresh_combined()

func _set_progress(set_id: String) -> int:
	if not _set_cards.has(set_id):
		return 0
	var n := 0
	for id in _set_cards[set_id]:
		if _cards.has(id):
			n += 1
	return n

func _on_core_coin(n: int) -> void:
	_add_wen(n)

# v6：一切文钱收入都走这里（好让［强化］的价钱灯跟着亮/灭）
func _add_wen(raw: int) -> void:
	if raw <= 0:
		return
	_wen += int(round(float(raw) * (1.0 + _gold_pct / 100.0)))
	if _coin_lb != null:
		_coin_lb.text = str(_wen)
	_refresh_str_tile()

# core 的 coin_drop：钱怪 / 匪首 / boss 掉的真钱（带落点，先只记账）
func _on_coin_drop(amount: int, _pos: Vector2) -> void:
	_add_wen(amount)

func _trigger_combos(trigger: String) -> void:
	for rec in _combined:
		if str(rec.get("trigger", "")) == trigger:
			_apply_combo(rec)
	if _combined_layer != null and _combined_layer.visible:
		_refresh_combined()

func _apply_combo(rec: Dictionary) -> void:
	rec["stacks"] = int(rec.get("stacks", 0)) + 1
	var key := str(rec.get("combo_key", ""))
	var val := float(rec.get("combo_val", 0))
	match key:
		"atk":
			_stats["atk"] = float(_stats["atk"]) + val
			if _core != null: _core.hero["atk"] = float(_core.hero.get("atk", 0.0)) + val
		"def":
			_stats["def"] = float(_stats["def"]) + val
			if _core != null: _core.hero["def"] = float(_core.hero.get("def", 0.0)) + val
		"hp":
			_stats["hp"] = float(_stats["hp"]) + val
			if _core != null:
				_core.hero["hp_max"] = float(_core.hero.get("hp_max", 1.0)) + val
				_core.hero["hp"] = float(_core.hero.get("hp", 0.0)) + val
		"heal":
			if _core != null: _core.hero["hp"] = minf(float(_core.hero.get("hp_max", 1.0)), float(_core.hero.get("hp", 0.0)) + val)
		"gold_pct":
			_gold_pct += val
		"gold_flat":
			_wen += int(val)
			if _coin_lb != null: _coin_lb.text = str(_wen)
		"crystal_flat":
			_crystal += int(val)
			_update_crystal()
		"mp_flat":
			_mp = minf(_mp_max, _mp + val)     # v5：内力系组合 → 回内力
		# ---- v13 群 / 险 ----
		"count_flat":
			_wave_extra += int(val)
		"coin_count":
			_coin_count_extra += int(val)
		"crystal_count":
			_crystal_count_extra += int(val)
		"treasure_pct":
			_treasure_pct += val
		"boss_pct":
			_boss_pct += val
		"devour_n":
			_devour_keep(int(val))
		"killnum_pct":
			_killnum_pct += val
	# v13：组合还带一条「全局难度」
	var ek := str(rec.get("combo_extra_key", ""))
	if ek == "diff_pct":
		_diff_pct += float(rec.get("combo_extra_val", 0))
	if key in ["count_flat", "coin_count", "crystal_count", "treasure_pct", "boss_pct"] or ek == "diff_pct":
		_push_run_mods()

func _check_sets() -> void:
	var changed := true
	while changed:
		changed = false
		for sid_v in _set_cards.keys():
			var sid := str(sid_v)
			var ids: Array = _set_cards[sid]
			var all_in := true
			for cid in ids:
				if not _cards.has(str(cid)) and not _virtual_cards.has(str(cid)):
					all_in = false
					break
			if all_in:
				_activate_set(sid)
				changed = true
				break

func _activate_set(sid: String) -> void:
	var ids: Array = _set_cards[sid]
	if ids.is_empty(): return
	var first: Dictionary = _card_db[str(ids[0])]
	# 家传卡走另一套结算
	if first.has("ancestor"):
		_activate_ancestor_set(sid, first, ids)
		return
	var own_sum := {"atk": 0.0, "def": 0.0, "hp": 0.0, "mp": 0.0, "gold_pct": 0.0, "crystal_pct": 0.0,
		"count": 0.0, "coin_count": 0.0, "crystal_count": 0.0, "treasure_pct": 0.0, "boss_pct": 0.0,
		"wen_flat": 0.0, "crystal_flat": 0.0, "kill_pct": 0.0, "exp_pct": 0.0}
	var srcs: Array = []
	for cid_v in ids:
		var cid := str(cid_v)
		var c: Dictionary = _card_db[cid]
		srcs.append(str(c["name"]))
		var k := str(c["own_key"])
		if own_sum.has(k):
			own_sum[k] = float(own_sum[k]) + float(c["own_val"])
		_cards.erase(cid)
		_virtual_cards.erase(cid)          # 已被吞噬的副本也要清，否则这套会永远"凑齐"
	var rec := {"set_id": sid, "series": str(first["series"]), "tier": int(first["tier"]),
		"name": str(first["combo_name"]), "size": int(first["set_size"]),
		"quality": int(first["quality"]), "art": str(first["art"]),
		"own_text": _own_text(own_sum), "combo_text": str(first["combo_text"]),
		"trigger": str(first["trigger"]), "combo_key": str(first["combo_key"]),
		"combo_val": int(first["combo_val"]), "stacks": 0, "sources": srcs,
		"combo_extra_key": str(first.get("combo_extra_key", "")),
		"combo_extra_val": int(first.get("combo_extra_val", 0))}
	_combined.append(rec)
	_apply_own(own_sum)
	# v13：群/险 是常驻型 —— 组合完成的瞬间就生效一次（不等"每波"）
	if str(first["combo_key"]) in ["count_flat", "coin_count", "crystal_count", "treasure_pct", "boss_pct", "devour_n", "killnum_pct"]:
		_apply_combo(rec)
	_toast_card(str(rec["name"]), int(rec["quality"]), "组合激活，" + str(rec["size"]) + " 张已清空")
	# v8 成长系彩蛋：合成 攻击/防御/气血/内力 时 5% 掷「回潮」（一局一次）
	# v13 重利：合成经济系（文钱/灵晶）时 3% 入池
	if str(first["series"]) in ["gold", "crystal"] and not _zhongli_rolled and randf() < 0.03:
		_zhongli_rolled = true
		if not _pool.has("shiny_zhongli"):
			_pool.append("shiny_zhongli")
			_toast("彩蛋！「重利」入池")
			Aud.sfx("ult_ready", -4.0)
	var ser := str(first["series"])
	if ser in ["atk", "def", "hp", "mp"] and not _backwash_done and randf() < 0.05:
		_backwash_done = true
		if not _pool.has("shiny_backwash") and not _acquired.has("shiny_backwash"):
			_pool.append("shiny_backwash")
			_toast("彩蛋！「回潮」入池 —— 刷新就能看到")
			Aud.sfx("ult_ready", -4.0)
	var parts := sid.split("_")
	if parts.size() == 2:
		var tier := int(parts[1])
		if tier < 3:
			var nid := str(parts[0]) + "_" + str(tier + 1)
			if _set_cards.has(nid):
				var entry := str((_set_cards[nid] as Array)[0])
				if not _acquired.has(entry) and not _pool.has(entry):
					_pool.append(entry)
					var ec: Dictionary = _card_db[entry]
					_toast_card(str(ec["name"]), int(ec["quality"]), "已加入卡池")
	_refresh_deck()
	_bond_check()
	if _combined_layer != null and _combined_layer.visible:
		_refresh_combined()

func _own_text(s: Dictionary) -> String:
	var arr: Array = []
	if float(s["atk"]) > 0: arr.append("攻击 +" + str(int(s["atk"])))
	if float(s["def"]) > 0: arr.append("防御 +" + str(int(s["def"])))
	if float(s["hp"]) > 0: arr.append("气血 +" + str(int(s["hp"])))
	if float(s.get("mp", 0.0)) > 0: arr.append("内力 +" + str(int(s["mp"])))
	if float(s["gold_pct"]) > 0: arr.append("金币 +" + str(int(s["gold_pct"])) + "%")
	if float(s["crystal_pct"]) > 0: arr.append("灵晶 +" + str(int(s["crystal_pct"])) + "%")
	if float(s.get("count", 0.0)) > 0: arr.append("每波 +" + str(int(s["count"])) + " 只")
	if float(s.get("coin_count", 0.0)) > 0: arr.append("文钱怪 +" + str(int(s["coin_count"])))
	if float(s.get("crystal_count", 0.0)) > 0: arr.append("灵晶怪 +" + str(int(s["crystal_count"])))
	if float(s.get("treasure_pct", 0.0)) > 0: arr.append("宝物 +" + str(int(s["treasure_pct"])) + "%")
	if float(s.get("boss_pct", 0.0)) > 0: arr.append("首领 +" + str(int(s["boss_pct"])) + "%")
	if float(s.get("wen_flat", 0.0)) > 0: arr.append("文钱 +" + str(int(s["wen_flat"])))
	if float(s.get("crystal_flat", 0.0)) > 0: arr.append("灵晶 +" + str(int(s["crystal_flat"])))
	if float(s.get("kill_pct", 0.0)) > 0: arr.append("击杀收益 +" + str(int(s["kill_pct"])) + "%")
	if float(s.get("exp_pct", 0.0)) > 0: arr.append("杀怪数 +" + str(int(s["exp_pct"])) + "%")
	return " · ".join(PackedStringArray(arr))

func _apply_own(s: Dictionary) -> void:
	_stats["atk"] = float(_stats["atk"]) + float(s["atk"])
	_stats["def"] = float(_stats["def"]) + float(s["def"])
	_stats["hp"] = float(_stats["hp"]) + float(s["hp"])
	if float(s.get("mp", 0.0)) > 0.0:
		_mp_bonus += float(s["mp"])          # v5：内力系卡 → 内力上限
	_gold_pct += float(s["gold_pct"])
	_crystal_pct += float(s["crystal_pct"])
	# v13 群/险
	if float(s.get("count", 0.0)) > 0.0:
		_wave_extra += int(s["count"])
	if float(s.get("coin_count", 0.0)) > 0.0:
		_coin_count_extra += int(s["coin_count"])
	if float(s.get("crystal_count", 0.0)) > 0.0:
		_crystal_count_extra += int(s["crystal_count"])
	if float(s.get("treasure_pct", 0.0)) > 0.0:
		_treasure_pct += float(s["treasure_pct"])
	if float(s.get("boss_pct", 0.0)) > 0.0:
		_boss_pct += float(s["boss_pct"])
	if float(s.get("wen_flat", 0.0)) > 0.0:
		_add_wen(int(s["wen_flat"]))
	if float(s.get("crystal_flat", 0.0)) > 0.0:
		_crystal += int(s["crystal_flat"])
		_update_crystal()
	if float(s.get("kill_pct", 0.0)) > 0.0:
		_kill_pct += float(s["kill_pct"])
	if float(s.get("exp_pct", 0.0)) > 0.0:
		_killnum_pct += float(s["exp_pct"])
	_push_run_mods()
	if _core != null:
		_core.hero["atk"] = float(_core.hero.get("atk", 0.0)) + float(s["atk"])
		_core.hero["def"] = float(_core.hero.get("def", 0.0)) + float(s["def"])
		var hp_add := float(s["hp"])
		_core.hero["hp_max"] = float(_core.hero.get("hp_max", 1.0)) + hp_add
		_core.hero["hp"] = float(_core.hero.get("hp", 0.0)) + hp_add

func _add_card(id: String) -> void:
	if not _card_db.has(id): return
	if str(id) == "shiny_zhongli":
		_enable_zhongli()
	elif str(id) == "shiny_chenshi2":
		_enable_shiyun()
	elif str(id) == "shiny_zhiyuan":
		_enable_qianzhi()
	elif str(id) == "shiny_mingzhu":
		_enable_undying_lamp()
	elif str(id) == "shiny_liuqingqing2":
		_enable_baicao()
	elif str(id) == "shiny_qingluan":
		_enable_wanren()
	elif str(id) == "shiny_gundilong":
		_enable_gunshan()
	elif str(id) == "shiny_zhujue":
		_enable_jianpo()
	elif str(id) == "shiny_backwash":
		_apply_own({"atk": 4.0, "def": 4.0, "hp": 40.0, "mp": 40.0, "gold_pct": 0.0, "crystal_pct": 0.0})
		_backwash()
	elif str(id) == "shiny_cuisanniang":
		_enable_swallow_sea()
	elif str(id) == "shiny_jicanghai":
		_enable_fentian()
	elif str(id).begins_with("shiny_"):
		_do_devour(id)
		return
	if _cards.size() >= 10:
		_toast("卡组已满（10 格）")
		return
	var c: Dictionary = _card_db[id]
	_pool.erase(id)
	_cards.append(id)
	_acquired[id] = true
	if bool(c.get("entry", false)):
		for uid in c.get("unlock_ids", []):
			var us := str(uid)
			if not _acquired.has(us) and not _pool.has(us):
				_pool.append(us)
				var uc: Dictionary = _card_db[us]
				_toast_card(str(uc["name"]), int(uc["quality"]), "已加入卡池")
	_check_sets()
	_page = 0
	_refresh_deck()
	_toast_card(str(c["name"]), int(c["quality"]), "已入卡组")
	_draw_paid = false
	_show_draw(false)

func _build_combined() -> void:
	_combined_layer = Control.new()
	_combined_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_combined_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_combined_layer.visible = false
	_combined_layer.z_index = 32
	add_child(_combined_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_show_combined(false))
	_combined_layer.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(32, 150)
	panel.size = Vector2(656, 900)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.91, 0.83, 0.99)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.70, 0.52, 0.22, 0.7)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_combined_layer.add_child(panel)
	_lbl("总 计", Vector2(60, 166), Vector2(260, 46), 34, INK, _combined_layer)
	_btn("×", Rect2(624, 170, 44, 36), 22, Color(0.95, 0.91, 0.83), DIM, func(): _show_combined(false), _combined_layer)
	# 顶部分类钮：卡组 / 宝物 / 组合
	var tabs := [["deck", "卡组"], ["bond", "宝物"], ["combo", "组合"]]
	_tot_tabs.clear()
	for i in tabs.size():
		var b := _btn(str(tabs[i][1]), Rect2(60.0 + float(i) * 136.0, 216, 128, 42), 20,
			Color(0.09, 0.08, 0.07, 0.98), LIGHT, _set_tot_tab.bind(str(tabs[i][0])), _combined_layer)
		_tot_tabs.append(b)
	# 三个分页的内容区
	_tot_deck_root = Control.new()
	_tot_deck_root.position = Vector2(50, 280)
	_tot_deck_root.size = Vector2(620, 640)
	_tot_deck_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combined_layer.add_child(_tot_deck_root)
	_tot_bond_root = Control.new()
	_tot_bond_root.position = Vector2(50, 280)
	_tot_bond_root.size = Vector2(620, 640)
	_tot_bond_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combined_layer.add_child(_tot_bond_root)
	_combined_icons = Control.new()
	_combined_icons.position = Vector2(50, 280)
	_combined_icons.size = Vector2(620, 640)
	_combined_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combined_layer.add_child(_combined_icons)
	_combined_detail = Control.new()
	_combined_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_combined_detail.visible = false
	_combined_layer.add_child(_combined_detail)
	_set_tot_tab("deck")

func _show_combined(v: bool) -> void:
	_combined_layer.visible = v
	if v:
		_combined_layer.move_to_front()
		_set_tot_tab(_tot_tab)

func _refresh_combined() -> void:
	for ch in _combined_icons.get_children(): ch.queue_free()
	_combined_detail.visible = false
	if _combined.is_empty():
		_lbl("还没有已激活组合", Vector2(20, 20), Vector2(580, 40), 22, DIM, _combined_icons)
		return
	for i in _combined.size():
		var rec: Dictionary = _combined[i]
		var ic := CombinedIcon.new()
		ic.position = Vector2(float(i % 5) * 120.0, float(i / 5) * 130.0)
		ic.size = Vector2(100, 100)
		ic.quality = int(rec["quality"])
		ic.art = load(str(rec["art"]))
		ic.size_n = int(rec["size"])
		ic.pressed.connect(func() -> void: _show_combined_detail(rec))
		_combined_icons.add_child(ic)

func _show_combined_detail(rec: Dictionary) -> void:
	for ch in _combined_detail.get_children(): ch.queue_free()
	_combined_detail.visible = true
	var p := Panel.new()
	p.position = Vector2(140, 300)
	p.size = Vector2(440, 420)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.85, 0.99)
	sb.set_corner_radius_all(9)
	sb.border_color = QUALITY_COLORS[clampi(int(rec["quality"]) - 1, 0, 4)]
	sb.set_border_width_all(7)
	p.add_theme_stylebox_override("panel", sb)
	_combined_detail.add_child(p)
	_lbl(str(rec["name"]), Vector2(170, 326), Vector2(360, 40), 30, INK, _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	var sz_cn: Array = ["", "三", "四", "五", "六"]
	_lbl(str(sz_cn[clampi(int(rec["size"]), 1, 6)]) + "合一", Vector2(420, 330), Vector2(100, 28), 18, Color(0.64,0.22,0.15), _combined_detail)
	_lbl("卡面合计：" + str(rec["own_text"]), Vector2(170, 390), Vector2(380, 32), 20, INK, _combined_detail)
	_lbl("组合：" + str(rec["combo_text"]), Vector2(170, 430), Vector2(380, 32), 20, INK, _combined_detail)
	_lbl("触发：" + str(rec["trigger"]) + "　已叠 " + str(int(rec["stacks"])), Vector2(170, 470), Vector2(380, 30), 18, DIM, _combined_detail)
	_lbl("源：" + " · ".join(PackedStringArray(rec["sources"])), Vector2(170, 510), Vector2(380, 60), 17, Color(0.38,0.30,0.20), _combined_detail)
	_btn("×", Rect2(592, 302, 34, 30), 20, Color(0.97,0.93,0.85), DIM, func(): _combined_detail.visible = false, _combined_detail)

class CombinedIcon extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal pressed
	var quality := 3
	var art: Texture2D = null
	var size_n := 3
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96,0.93,0.86,0.98)
		sb.set_corner_radius_all(8)
		sb.border_color = QC[clampi(quality-1,0,4)]
		sb.set_border_width_all(5)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if art != null:
			draw_texture_rect(art, Rect2(8,8,size.x-16,size.y-16), false)
		draw_rect(Rect2(size.x-32,6,26,22), Color(0.64,0.22,0.15))
		draw_string(F, Vector2(size.x-30,23), "合", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.98,0.92,0.78))
		draw_string(F, Vector2(size.x-34,size.y-8), str(size_n), HORIZONTAL_ALIGNMENT_RIGHT, 26, 16, Color(0.38,0.30,0.20))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

func _play_attack_fx(hero_attacks: bool) -> void:
	if _core == null or _fx_back == null or _hero_token == null:
		return
	var tgt: Dictionary = _core._hero_pending
	if not hero_attacks or tgt.is_empty():
		tgt = _core._nearest()
	if tgt.is_empty():
		return
	if hero_attacks:
		var to: Vector2 = _core.position + Vector2(float(tgt["x"]), float(tgt["y"]))
		_fx_back.spawn_swing(_hero_token.position - FIELD_POS, to - FIELD_POS, _hero_token.radius, true)
	else:
		var tk = _foe_tokens.get(int(tgt.get("_tid", 0)))
		if tk == null:
			return
		_fx_back.spawn_swing(tk.position - FIELD_POS, _hero_token.position - FIELD_POS, tk.radius, false, false, true)

func _spawn_hit_fx(global_pos: Vector2, radius: float, dmg: int, hero_hit: bool, crit: bool, heavy: bool) -> void:
	if _fx_front == null:
		return
	_fx_front.spawn_hit(global_pos - FIELD_POS, radius, dmg, hero_hit, crit or heavy, heavy)

func _on_hero_attack() -> void:
	_play_attack_fx(true)
	_attack_count += 1
	_hero_extra_hits()                       # 主角被动：多目标 / 追击 / 剑气
	_trigger_combos("每次攻击")
	if _attack_count % 5 == 0:
		_trigger_combos("每 5 次攻击")
	if _attack_count % 10 == 0:
		_trigger_combos("每 10 次攻击")

func _on_hero_hit() -> void:
	_play_attack_fx(false)
	_hit_count += 1
	_trigger_combos("每次受击")
	_stone_on_hit()

func _on_hero_foe_hit(tgt: Dictionary, dmg: float, crit: bool, heavy: bool) -> void:
	if _fx_front == null:
		return
	var tk = _foe_tokens.get(int(tgt.get("_tid", 0)))
	if tk == null:
		return
	_spawn_hit_fx(tk.position, tk.radius, int(round(dmg)), false, crit, heavy)
	tk.play_hit()

# ============================================================
# v3 请神 + 技能栏（祖宗技能：各自 CD + 内力）
# ============================================================
const Aud := preload("res://shared/audio.gd")

const SKILL_DEFS := {
	"zl": {"name": "天雷道术", "dtype": "金系", "mul": 1.6, "cd": 10.0, "mp": 260.0,
		"targets": 3, "col": Color(0.86, 0.78, 0.34)},
	"cuisanniang": {"name": "雾海龙王", "dtype": "召唤", "mul": 2.5, "cd": 60.0, "mp": 300.0,
		"targets": 1, "col": Color(0.38, 0.62, 0.82)},
	"jicanghai": {"name": "怒火焚身", "dtype": "火系", "mul": 1.3, "cd": 9.0, "mp": 0.0,
		"targets": 3, "col": Color(0.88, 0.42, 0.22)},
	"chenshi": {"name": "刺骨", "dtype": "真实", "mul": 1.4, "cd": 8.0, "mp": 90.0,
		"targets": 1, "col": Color(0.86, 0.55, 0.62)},
	"liuqingqing": {"name": "回春", "dtype": "木系", "mul": 1.2, "cd": 12.0, "mp": 110.0,
		"targets": 3, "col": Color(0.42, 0.72, 0.42)},
	"xiaoqier": {"name": "顺手", "dtype": "物理", "mul": 0.9, "cd": 5.0, "mp": 60.0,
		"targets": 1, "col": Color(0.90, 0.84, 0.66)},
	"gundilong": {"name": "肉蛋冲撞", "dtype": "物理", "mul": 1.5, "cd": 6.0, "mp": 80.0,
		"targets": 1, "col": Color(0.78, 0.68, 0.42)},
	"qingluan": {"name": "青鸾飞刃", "dtype": "物理", "mul": 1.2, "cd": 8.0, "mp": 90.0,
		"targets": 1, "col": Color(0.55, 0.82, 0.90)},
	"liuqingqing2": {"name": "回春", "dtype": "木系", "mul": 1.0, "cd": 12.0, "mp": 80.0,
		"targets": 1, "col": Color(0.45, 0.78, 0.42)},
	"zhiyuan": {"name": "剪纸成兵", "dtype": "召唤", "mul": 1.0, "cd": 10.0, "mp": 90.0,
		"targets": 1, "col": Color(0.94, 0.92, 0.84)},
}

var _skills: Array = []
var _mp := 300.0
var _mp_max := 300.0
var _mp_bonus := 0.0        # 内力系卡牌给的内力上限加成
var _mp_bar: Panel = null
var _skill_slots: Array = []
var _god_layer: Control = null
var _god_root: Control = null

# ---------------- 技能栏 ----------------
func _build_skill_bar() -> void:
	for i in 6:
		var s := SkillSlot.new()
		s.position = Vector2(636, 242 + i * 62)
		s.size = Vector2(54, 54)
		s.visible = false
		s.z_index = 8
		add_child(s)
		_skill_slots.append(s)

func _tick_skills(dt: float) -> void:
	if _core != null and float(_core.hero.get("aspd", 1.0)) > MAX_ASPD:
		_core.hero["aspd"] = MAX_ASPD          # 硬顶：防攻速叠太高卡帧
	var lv_mul := float(_lv - 1)
	_mp_max = 300.0 + 25.0 * lv_mul + _mp_bonus
	_mp = minf(_mp_max, _mp + (20.0 + 2.0 * lv_mul) * dt)
	if _mp_bar != null:
		_mp_bar.size = Vector2(maxf(4.0, 235.0 * clampf(_mp / _mp_max, 0.0, 1.0)), 9.0)
	for i in _skills.size():
		var sk: Dictionary = _skills[i]
		if float(sk["cd_t"]) > 0.0:
			sk["cd_t"] = maxf(0.0, float(sk["cd_t"]) - dt)
		if float(sk["cd_t"]) <= 0.0 and _mp >= float(sk["mp"]):
			_cast_skill(i)
	for i in _skill_slots.size():
		var s = _skill_slots[i]
		if i < _skills.size():
			var sk2: Dictionary = _skills[i]
			s.visible = true
			s.skill_name = str(sk2["name"])
			s.quality = int(sk2.get("quality", 4))
			s.cd_left = float(sk2["cd_t"])
			s.cd_max = maxf(0.01, float(sk2["cd"]))
			s.mp_cost = int(sk2["mp"])
			s.queue_redraw()
		else:
			s.visible = false

func _cast_skill(i: int) -> void:
	var sk: Dictionary = _skills[i]
	var aid0 := str(sk["aid"])
	var md0: Dictionary = _anc_mod.get(aid0, {})
	var cost0 := maxf(0.0, float(sk["mp"]) - float(md0.get("mp_flat", 0.0)))
	if _mp < cost0:
		return
	# 石皮流：纯被动（不进技能栏），这里只为兜底
	if aid0 == "chenshi2":
		return
	# 召唤流：剪纸成兵
	if aid0 == "zhiyuan":
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_cast_paper()
		return
	# 治疗流：回血 + 环毒 + 易伤
	if aid0 == "liuqingqing2":
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		var times := 1
		if _baicao:
			times = _baicao_times()
		for _i in times:
			_cast_heal(float(sk["mul"]))
		if times > 1:
			_toast("百草 · 连放 %d 次（只扣一次内力）" % times)
		return
	# 穿透流：直线穿透 + 回程
	if aid0 == "qingluan":
		if _live_foes().is_empty():
			return
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_cast_feiren(float(sk["mul"]))
		return
	# 撞击流：按气血上限算伤害，并把目标撞飞
	if aid0 == "gundilong":
		if _live_foes().is_empty():
			return
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_charge_ram()
		return
	# 火系：直伤 + 灼烧（引燃多名）
	if aid0 == "jicanghai":
		if _live_foes().is_empty():
			return                                  # 空场不空放，CD 与内力都不扣
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_cast_fire()
		return
	# 召唤系：不直接出伤，召一条蛟龙顶上去
	if aid0 == "cuisanniang":
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_summon_dragon(float(md0.get("dmg_pct", 0.0)) + float(_elem_mod.get("召唤", 0.0)))
		return
	var foes: Array = []
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		foes.append(f)
	if foes.is_empty():
		return
	# v4：组合加成在这里生效（家传卡抽了才有意义）
	var aid := str(sk["aid"])
	var dtype := str(sk["dtype"])
	var m: Dictionary = _anc_mod.get(aid, {})
	var dmg_pct := float(m.get("dmg_pct", 0.0)) + float(_elem_mod.get(dtype, 0.0))
	var cd_pct := float(m.get("cd_pct", 0.0))
	var mp_flat := float(m.get("mp_flat", 0.0))
	var para_s := float(m.get("para_s", 0.0))
	var para_amp := float(m.get("para_amp", 0.0))
	var cost := maxf(0.0, float(sk["mp"]) - mp_flat)
	if _mp < cost:
		return
	_mp -= cost
	sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(cd_pct, 0.0, 80.0) / 100.0))
	var hp0 := Vector2(_core.hero_pos)
	foes.sort_custom(func(a, b) -> bool:
		var da := (Vector2(float(a["x"]), float(a["y"])) - hp0).length()
		var db := (Vector2(float(b["x"]), float(b["y"])) - hp0).length()
		return da < db)
	var base := float(_core.hero.get("atk", 12.0)) * float(sk["mul"]) * (1.0 + dmg_pct / 100.0)
	var n := mini(int(sk["targets"]) + int(m.get("tgt_add", 0.0)), foes.size())
	for k in n:
		var f: Dictionary = foes[k]
		var extra := 1.0
		if para_amp > 0.0 and float(f.get("para", 0.0)) > 0.0:
			extra = 1.0 + para_amp / 100.0        # 麻痹期间吃额外伤害
		_core._apply_dmg(f, base * extra, dtype)
		if para_s > 0.0:
			f["para"] = maxf(float(f.get("para", 0.0)), para_s)
		_core._push_float(float(f["x"]), float(f["y"]) - 46.0, str(sk["name"]), sk["col"], true)
	Aud.sfx("skill", -10.0)

func _add_ancestor_effects(aid: String, eff: Dictionary) -> void:
	if eff.is_empty():
		return
	if not _anc_mod.has(aid):
		_anc_mod[aid] = {"dmg_pct": 0.0, "cd_pct": 0.0, "mp_flat": 0.0, "para_s": 0.0, "para_amp": 0.0,
			"life_flat": 0.0, "cap_add": 0.0, "wave_evo": 0.0, "tgt_add": 0.0,
			"ignite_add": 0.0, "burn_add": 0.0}
	var m: Dictionary = _anc_mod[aid]
	for k in ["dmg_pct", "cd_pct", "mp_flat", "para_s", "para_amp", "life_flat", "cap_add", "wave_evo", "tgt_add",
			"ignite_add", "burn_add", "chain_dmg", "radius_add", "stun_s", "impact",
			"pierce", "knife", "volley", "volley_pct", "heal_pct", "aura", "poison_dur", "vuln",
			"heal_aura", "pull", "minion_pct", "paper_add", "burst", "paper_life",
			"stone_rate", "stone_add", "stone_def", "stone_burst", "stone_cap", "shard_drop"]:
		if eff.has(k):
			m[k] = float(m.get(k, 0.0)) + float(eff[k])
	if eff.has("elem_pct"):
		var ep: Dictionary = eff["elem_pct"]
		for e in ep.keys():
			_elem_mod[e] = float(_elem_mod.get(e, 0.0)) + float(ep[e])

# 炫卡吞噬：吞掉该祖宗全部家传卡（进度与效果保留）→ 返还资源 + 永久加伤 → 自身离场
func _do_devour(shiny_id: String) -> void:
	var c: Dictionary = _card_db.get(shiny_id, {})
	var aid := str(c.get("ancestor", ""))
	var nm := str(c.get("name", "炫卡"))
	_shiny_used[aid] = true
	_pool.erase(shiny_id)
	var n := 0
	for cid in _cards.duplicate():
		var cc: Dictionary = _card_db.get(str(cid), {})
		if str(cc.get("ancestor", "")) == aid:
			_cards.erase(cid)
			n += 1
	_cards.erase(shiny_id)
	var wen := 150 * n
	var crystal := 20 * n
	_wen += wen
	_crystal += crystal
	if _coin_lb != null:
		_coin_lb.text = str(_wen)
	_update_crystal()
	if not _anc_mod.has(aid):
		_anc_mod[aid] = {"dmg_pct": 0.0, "cd_pct": 0.0, "mp_flat": 0.0, "para_s": 0.0, "para_amp": 0.0,
			"life_flat": 0.0, "cap_add": 0.0, "wave_evo": 0.0, "tgt_add": 0.0,
			"ignite_add": 0.0, "burn_add": 0.0}
	_anc_mod[aid]["dmg_pct"] = float(_anc_mod[aid].get("dmg_pct", 0.0)) + 10.0 * n
	_page = 0
	_refresh_deck()
	# ---- 表现：白闪 + 震屏 + 音效 ----
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.98, 0.90, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 60
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.85, 0.06)
	tw.tween_property(flash, "color:a", 0.0, 0.30)
	tw.tween_callback(func() -> void: flash.queue_free())
	if _core != null:
		_core.Shake_add(9.0)
	_shiny_present("devour")
	await get_tree().create_timer(0.12).timeout
	_toast("%s 吞了 %d 张家传 · 灵晶 +%d · 文钱 +%d · %s +%d%%" % [nm, n, crystal, wen, str(_label_skill(aid)), 10 * n])

func _label_skill(aid: String) -> String:
	var d: Dictionary = SKILL_DEFS.get(aid, {})
	return str(d.get("name", "技能"))

# ---------------- 请神三选一 ----------------
func _build_god_pick() -> void:
	_god_layer = Control.new()
	_god_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_god_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_god_layer.visible = false
	_god_layer.z_index = 40
	add_child(_god_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_hide_god_pick())
	_god_layer.add_child(dim)
	var ban := Panel.new()
	ban.position = Vector2(230, 168)
	ban.size = Vector2(260, 48)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.48, 0.14, 0.10, 0.97)
	bsb.set_corner_radius_all(5)
	bsb.border_color = Color(0.95, 0.76, 0.36, 0.9)
	bsb.set_border_width_all(2)
	ban.add_theme_stylebox_override("panel", bsb)
	_god_layer.add_child(ban)
	_lbl("请  神", Vector2(0, 0), Vector2(260, 48), 24, Color(0.97, 0.90, 0.74), ban, HORIZONTAL_ALIGNMENT_CENTER)
	_god_root = Control.new()
	_god_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_god_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_god_layer.add_child(_god_root)

func _show_god_pick() -> void:
	if _god_layer == null:
		return
	if _draw_charge <= 0:
		_toast("升级后可请神")
		return
	for c in _god_root.get_children():
		c.queue_free()
	var cands: Array = []
	for aid_v in AncestorData.ANCESTORS.keys():
		var aid := str(aid_v)
		if SEALED.has(aid):
			continue
		if not _ancestors.has(aid):
			cands.append(aid)
	if cands.is_empty():
		_toast("可请的祖宗都已上身（高品祖宗需抽取，暂未开放）")
		return
	cands.shuffle()
	var n := mini(3, cands.size())
	var total_w := float(n) * 200.0 + float(n - 1) * 20.0
	var x0 := (720.0 - total_w) * 0.5
	for i in n:
		var gc := GodCard.new()
		var aid := str(cands[i])
		var a: Dictionary = AncestorData.ANCESTORS[aid]
		gc.aid = aid
		gc.god_name = str(a["name"])
		gc.skill_name = str(a["skill"])
		gc.element = str(a.get("dtype", ""))
		gc.quality = int(a["quality"])
		gc.icon = load(str(a["art"]))
		gc.position = Vector2(x0 + float(i) * 220.0, 250)
		gc.size = Vector2(200, 300)
		gc.picked.connect(func() -> void: _pick_god(aid))
		_god_root.add_child(gc)
	_lbl("择一祖宗上身 · 剩余 %d 次" % _draw_charge, Vector2(0, 224), Vector2(720, 24), 17,
		Color(0.92, 0.88, 0.78), _god_root, HORIZONTAL_ALIGNMENT_CENTER)
	_god_layer.visible = true
	_god_layer.move_to_front()

func _hide_god_pick() -> void:
	if _god_layer != null:
		_god_layer.visible = false

func _pick_god(aid: String) -> void:
	if _draw_charge <= 0:
		return
	_draw_charge -= 1
	_grant_ancestor(aid)
	var def: Dictionary = SKILL_DEFS.get(aid, {})
	if not def.is_empty() and not _has_skill(aid):
		var sk: Dictionary = def.duplicate()
		sk["aid"] = aid
		sk["cd_t"] = 0.0
		sk["quality"] = int((AncestorData.ANCESTORS[aid] as Dictionary)["quality"])
		_skills.append(sk)
	_hide_god_pick()
	_refresh_level_ui()
	_toast("请到 %s · 技能进栏，家传入口卡进池" % str((AncestorData.ANCESTORS[aid] as Dictionary)["name"]))
	Aud.sfx("levelup", -6.0)

func _has_skill(aid: String) -> bool:
	for sk in _skills:
		if str(sk["aid"]) == aid:
			return true
	return false

# ---------------- 技能格 ----------------
class SkillSlot extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	var skill_name := ""
	var quality := 4
	var cd_left := 0.0
	var cd_max := 1.0
	var mp_cost := 0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var qc: Color = QC[clampi(quality - 1, 0, 4)]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.93, 0.86, 0.98)
		sb.set_corner_radius_all(9)
		sb.border_color = qc
		sb.set_border_width_all(3)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c := size * 0.5
		var ch := "技"
		if skill_name.length() > 0:
			ch = skill_name.substr(1 if skill_name.length() > 1 else 0, 1)
		draw_string(F, Vector2(0, c.y + 8), ch, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(0.20, 0.16, 0.11))
		if cd_left > 0.0:
			draw_circle(c, size.x * 0.5 - 2.0, Color(0.05, 0.04, 0.03, 0.58))
			draw_string(F, Vector2(0, c.y + 8), str(int(ceil(cd_left))),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(0.97, 0.92, 0.80))
		if mp_cost > 0:
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = Color(0.28, 0.48, 0.68, 0.92)
			sb2.set_corner_radius_all(3)
			draw_style_box(sb2, Rect2(Vector2(size.x - 24, 1), Vector2(23, 14)))
			draw_string(F, Vector2(size.x - 24, 12), str(mp_cost),
				HORIZONTAL_ALIGNMENT_CENTER, 23, 10, Color(0.95, 0.98, 1.0))

# ---------------- 请神卡 ----------------
class GodCard extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal picked
	var aid := ""
	var god_name := ""
	var skill_name := ""
	var element := ""
	var quality := 5
	var icon: Texture2D = null
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var qc: Color = QC[clampi(quality - 1, 0, 4)]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.965, 0.945, 0.90, 1.0)
		sb.set_corner_radius_all(9)
		sb.border_color = qc
		sb.set_border_width_all(6)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		draw_string(F, Vector2(0, 36), god_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(0.14, 0.11, 0.08))
		var pr := Rect2(Vector2(40, 52), Vector2(120, 120))
		draw_rect(pr, Color(0.88, 0.85, 0.78))
		if icon != null:
			var ts := icon.get_size()
			var asp: float = pr.size.x / pr.size.y
			var w: float = ts.x
			var h: float = w / asp
			if h > ts.y:
				h = ts.y
				w = h * asp
			draw_texture_rect_region(icon, pr, Rect2((ts.x - w) * 0.5, (ts.y - h) * 0.5, w, h))
		draw_rect(pr, Color(0.35, 0.30, 0.24, 0.30), false, 1.5)
		draw_string(F, Vector2(0, 204), skill_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 21, Color(0.20, 0.15, 0.10))
		draw_line(Vector2(18, 220), Vector2(size.x - 18, 220), Color(0.5, 0.4, 0.25, 0.35), 1.5)
		draw_string(F, Vector2(0, 246), element, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color(0.42, 0.30, 0.12))
		draw_string(F, Vector2(0, 280), "点 击 请 神", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(0.66, 0.22, 0.15))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()

# ---------------- 召唤物：蛟龙 ----------------
func _summon_dragon(bonus_pct: float) -> void:
	var m: Dictionary = _anc_mod.get("cuisanniang", {})
	var cap := 1 + int(m.get("cap_add", 0.0))
	if _minions.size() >= cap:
		return
	var hero_atk := float(_core.hero.get("atk", 12.0))
	var life := 30.0 + float(m.get("life_flat", 0.0))
	var idx := _minions.size()
	var pos := Vector2(360.0 - 80.0 + float(idx) * 160.0, 726.0)
	var tk = TokenActor.new()
	tk.setup(null, 20.0, Color(0.30, 0.62, 0.80), false)
	tk.show_bar = true
	tk.bar_w = 44.0
	tk.unit_name = "蛟龙"
	tk.z_index = 5
	tk.position = _core.position + pos
	add_child(tk)
	var mul := 1.0 + bonus_pct / 100.0
	if _swallow_sea:
		life = 999999.0
	var ss := 1.0 + _ss_pct / 100.0
	var bd := hero_atk * 0.8 * mul
	_minions.append({"pos": pos, "life": life, "max_life": life,
		"atk_cd": 0.6, "wave_cd": 20.0,
		"base_dmg": bd, "base_wave": hero_atk * 2.5 * mul,
		"dmg": bd * ss, "wave_dmg": hero_atk * 2.5 * mul * ss, "tk": tk})
	_toast("蛟龙现世 · 存在 %d 秒" % int(life))
	Aud.sfx("warcry", -8.0)

func _tick_minions(dt: float) -> void:
	if _core == null:
		return
	if _swallow_sea:
		_ss_pct += 0.4 * dt                    # 每秒 +0.4% 蛟龙属性
	if _minions.is_empty():
		return
	for m_v in _minions.duplicate():
		var m: Dictionary = m_v
		m["life"] = float(m["life"]) - dt
		var tk = m["tk"]
		if _swallow_sea and m.has("base_dmg"):
			m["life"] = float(m["max_life"])
			var ss2 := 1.0 + _ss_pct / 100.0
			m["dmg"] = float(m["base_dmg"]) * ss2
			m["wave_dmg"] = float(m["base_wave"]) * ss2
		if float(m["life"]) <= 0.0:
			if tk != null and is_instance_valid(tk):
				tk.play_down()
			_minions.erase(m)
			continue
		var mp0: Vector2 = m["pos"]
		var best: Dictionary = {}
		var bd := 1e9
		for f_v in _core.foes:
			var f: Dictionary = f_v
			if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
				continue
			var d := (Vector2(float(f["x"]), float(f["y"])) - mp0).length()
			if d < bd:
				bd = d
				best = f
		if not best.is_empty():
			var tgt := Vector2(float(best["x"]), float(best["y"]))
			var dv := tgt - mp0
			if dv.length() > 48.0:
				m["pos"] = mp0 + dv.normalized() * 150.0 * dt
			else:
				m["atk_cd"] = float(m["atk_cd"]) - dt
				if float(m["atk_cd"]) <= 0.0:
					m["atk_cd"] = 1.1
					_core._apply_dmg(best, float(m["dmg"]), "召唤")
			m["wave_cd"] = float(m["wave_cd"]) - dt
			if float(m["wave_cd"]) <= 0.0:
				m["wave_cd"] = 20.0
				_dragon_wave(m, best)
		if tk != null and is_instance_valid(tk):
			tk.position = _core.position + Vector2(m["pos"])
			tk.hp_ratio = float(m["life"]) / maxf(1.0, float(m["max_life"]))
			tk.queue_redraw()

# 大浪拍击：单体；六档「怒涛」进化成一圈 + 减速
func _dragon_wave(m: Dictionary, target: Dictionary) -> void:
	var wm: Dictionary = _anc_mod.get("cuisanniang", {})
	var evo := float(wm.get("wave_evo", 0.0)) > 0.0
	var at := Vector2(float(target["x"]), float(target["y"]))
	for f_v in _core.foes.duplicate():
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		var d := (Vector2(float(f["x"]), float(f["y"])) - at).length()
		if f != target and not (evo and d <= 130.0):
			continue
		_core._apply_dmg(f, float(m["wave_dmg"]), "召唤")
		if evo:
			f["slow_t"] = 2.0
		_core._push_float(float(f["x"]), float(f["y"]) - 40.0, "大浪", Color(0.38, 0.62, 0.82), true)
	Aud.sfx("hit_heavy", -10.0)

# ---------------- 吞海（崔三娘炫卡） ----------------
func _enable_swallow_sea() -> void:
	_swallow_sea = true
	_ss_pct = 10.0          # 单卡数值：蛟龙属性 +10%
	_ss_kills = 0
	for m_v in _minions:
		var m: Dictionary = m_v
		m["max_life"] = 999999.0
		m["life"] = 999999.0
	_toast("吞海入卡组 · 蛟龙永久存在，每秒 +0.4%、每 10 杀 +4% 属性")
	_shiny_present("swallow_sea")

# ---------------- 灼烧 / 引燃 / 焚天 ----------------
func _live_foes() -> Array:
	var out: Array = []
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		out.append(f)
	var hp0 := Vector2(_core.hero_pos)
	out.sort_custom(func(a, b) -> bool:
		var da := (Vector2(float(a["x"]), float(a["y"])) - hp0).length()
		var db := (Vector2(float(b["x"]), float(b["y"])) - hp0).length()
		return da < db)
	return out

func _apply_burn(f: Dictionary, stacks: float, dur: float) -> void:
	f["burn"] = float(f.get("burn", 0.0)) + stacks
	f["burn_t"] = maxf(float(f.get("burn_t", 0.0)), dur)

func _burn_dps() -> float:
	return float(_core.hero.get("atk", 12.0)) * 0.12

func _tick_burn(dt: float) -> void:
	if _core == null:
		return
	for f_v in _core.foes:
		var f: Dictionary = f_v
		var st := float(f.get("burn", 0.0))
		if st <= 0.0:
			continue
		if float(f.get("hp", 0.0)) <= 0.0:
			continue
		f["burn_acc"] = float(f.get("burn_acc", 0.0)) + dt
		while float(f["burn_acc"]) >= 1.0:
			f["burn_acc"] = float(f["burn_acc"]) - 1.0
			_core._apply_dmg(f, _burn_dps() * st, "火系")
			_core._push_float(float(f["x"]), float(f["y"]) - 30.0, "烧", Color(0.88, 0.45, 0.20))
		f["burn_t"] = float(f.get("burn_t", 0.0)) - dt
		if float(f["burn_t"]) <= 0.0 and not _burn_unlimited:
			f["burn"] = maxf(0.0, st - 1.0)
			f["burn_t"] = 4.0
			if float(f["burn"]) <= 0.0:
				f.erase("burn")

func _cast_fire() -> void:
	var m: Dictionary = _anc_mod.get("jicanghai", {})
	var dmg_pct := float(m.get("dmg_pct", 0.0)) + float(_elem_mod.get("火系", 0.0))
	var ign := 1 + int(m.get("ignite_add", 0.0)) + _ignite_bonus
	var stacks := 1.0 + float(m.get("burn_add", 0.0))
	var foes := _live_foes()
	if foes.is_empty():
		return
	var n := mini(ign, foes.size())
	for k in n:
		var f: Dictionary = foes[k]
		_core._apply_dmg(f, float(_core.hero.get("atk", 12.0)) * 0.6 * (1.0 + dmg_pct / 100.0), "火系")
		_apply_burn(f, stacks, 4.0)
		_core._push_float(float(f["x"]), float(f["y"]) - 46.0, "引燃", Color(0.88, 0.45, 0.20), true)
	Aud.sfx("skill", -10.0)

# 焚天（季沧海炫卡）：灼烧不衰减 + 每 15 杀吞一张卡 + 每吞一张引燃 +1
func _enable_fentian() -> void:
	_fentian = true
	_burn_unlimited = true
	_ft_kills = 0
	_toast("焚天入卡组 · 灼烧无上限，每 15 杀吞一张卡、引燃 +1")
	_shiny_present("fentian")

func _devour_random() -> void:
	if _cards.is_empty():
		return
	var pick := str(_cards[randi() % _cards.size()])
	_cards.erase(pick)
	_ignite_bonus += 1
	_refresh_deck()
	var nm := str((_card_db.get(pick, {}) as Dictionary).get("name", "一张卡"))
	_toast("焚天吞噬「%s」· 引燃目标 +1（共 %d）" % [nm, 1 + _ignite_bonus])
	Aud.sfx("coin", -8.0)
	Aud.sfx("hit_heavy", -14.0)

# ---------------- 回潮（成长系彩蛋） ----------------
#   合成 攻击/防御/气血/内力 任意一套时 5% 掷；一局一次
#   进卡组：四维立刻 +4/+4/+40/+40，波数回退 5 波（当前波清空重刷）
func _backwash() -> void:
	if _core == null:
		return
	var w := int(_core.wave)
	var nw := maxi(1, w - 5)
	_core.set_wave(nw)
	_core.wave_reset_quota()
	_last_wave = nw
	_run_cleared = false
	if _wave_lb != null:
		_wave_lb.text = "波 %d/%d" % [nw, MAX_WAVE]
	_toast("回潮 · 波数 %d → %d，重头再刷" % [w, nw])
	_shiny_present("backwash")

# ============================================================
# 炫彩卡出场演出：四张各一套（动画 / 音效 / 音乐都不同）
#   devour       噬雷 · 吞噬收割 —— 白闪 + 竖条冲击 + drum
#   swallow_sea  吞海 · 养龙 —— 蓝潮从底升起 + warcry
#   fentian      焚天 · 火 —— 橙色四边向内烧 + tension
#   backwash     回潮 · 倒流 —— 白圆从中心扩散 + 低音钟
# ============================================================
func _shiny_present(kind: String) -> void:
	# ---- 音乐（短促 stinger，1.8 秒后收掉）----
	var music := ""
	match kind:
		"devour": music = "bgm_tower"
		"swallow_sea": music = "menu_jiangnan"
		"fentian": music = "menu_youzhou"
		"backwash": music = "menu_wudao"
		"jianpo": music = "menu_shushan"
		"gunshan": music = "menu_shaolin"
		"wanren": music = "menu_jiangnan"
		"baicao": music = "menu_shushan"
		"undying": music = "menu_hejian"
		"qianzhi": music = "menu_youzhou"
		"shiyun": music = "menu_shaolin"
		"zhongli": music = "menu_jiangnan"
	if music != "":
		Aud.play_bgm(music, 0.25)
		_stop_stinger(1.8)
	# ---- 音效 ----
	match kind:
		"devour":
			Aud.sfx("coin", -6.0, 1.0)
			Aud.sfx("hit_heavy", -10.0, 1.0)
			Aud.sfx("drum", -4.0, 1.0)
		"swallow_sea":
			Aud.sfx("warcry", -6.0, 0.9)
			Aud.sfx("rain", -14.0, 0.8)
		"fentian":
			Aud.sfx("tension", -6.0, 1.2)
			Aud.sfx("hit_slash2", -10.0, 0.9)
		"backwash":
			Aud.sfx("bell", -6.0, 0.6)          # 低音钟
			Aud.sfx("ink_drop", -10.0, 0.7)
		"jianpo":
			Aud.sfx("sword_draw", -4.0, 1.1)
			Aud.sfx("slash_light2", -8.0, 0.95)
		"gunshan":
			Aud.sfx("wood_down", -4.0, 0.8)
			Aud.sfx("melee", -8.0, 0.9)
		"wanren":
			Aud.sfx("sword_draw", -4.0, 1.25)
			Aud.sfx("slash_light", -8.0, 1.2)
		"baicao":
			Aud.sfx("enlighten", -4.0, 1.0)
			Aud.sfx("pet_chirp1", -12.0, 1.1)
		"undying":
			Aud.sfx("bell", -4.0, 1.1)
			Aud.sfx("wind", -10.0, 0.9)
		"qianzhi":
			Aud.sfx("paper", -4.0, 1.0)
			Aud.sfx("bell", -8.0, 1.3)
		"shiyun":
			Aud.sfx("wood_down", -4.0, 0.7)
			Aud.sfx("hit_heavy", -8.0, 0.8)
		"zhongli":
			Aud.sfx("coin", -4.0, 1.15)
			Aud.sfx("chest", -8.0, 1.0)
	# ---- 动画 ----
	match kind:
		"devour":
			_flash(Color(1.0, 0.98, 0.90), 0.85, 0.06, 0.30)
			for i in 3:
				_sweep_bar(Color(1.0, 0.97, 0.86, 0.55), 0.08 * float(i))
		"swallow_sea":
			_flash(Color(0.55, 0.78, 1.0), 0.60, 0.12, 0.45)
			_rise_tide()
		"fentian":
			_flash(Color(1.0, 0.66, 0.30), 0.70, 0.10, 0.40)
			_burn_edges()
		"backwash":
			_flash(Color(0.80, 0.88, 1.0), 0.50, 0.10, 0.40)
			_ring_out()
		"jianpo":
			_flash(Color(0.98, 0.95, 0.80), 0.55, 0.08, 0.34)
			_sword_rain()
		"gunshan":
			_flash(Color(0.82, 0.68, 0.40), 0.60, 0.10, 0.40)
			_rise_tide()
		"wanren":
			_flash(Color(0.62, 0.88, 0.95), 0.55, 0.08, 0.34)
			_sweep_bar(Color(0.75, 0.95, 1.0, 0.55), 0.0)
		"baicao":
			_flash(Color(0.55, 0.88, 0.50), 0.55, 0.08, 0.34)
			_ring_out()
		"undying":
			_flash(Color(1.0, 0.92, 0.62), 0.60, 0.10, 0.40)
			_ring_out()
		"qianzhi":
			_flash(Color(0.96, 0.94, 0.88), 0.60, 0.08, 0.36)
			_sword_rain()
		"shiyun":
			_flash(Color(0.62, 0.58, 0.50), 0.65, 0.10, 0.40)
			_ring_out()
		"zhongli":
			_flash(Color(1.0, 0.92, 0.52), 0.62, 0.08, 0.36)
			_sword_rain()
	if _core != null:
		_core.Shake_add(6.0 if kind != "devour" else 9.0)

func _stop_stinger(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	Aud.stop_bgm(0.6)

func _flash(col: Color, a: float, t_in: float, t_out: float) -> void:
	var r := ColorRect.new()
	r.color = Color(col.r, col.g, col.b, 0.0)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 60
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", a, t_in)
	tw.tween_property(r, "color:a", 0.0, t_out)
	tw.tween_callback(func() -> void: r.queue_free())

func _sweep_bar(col: Color, delay: float) -> void:
	var r := ColorRect.new()
	r.color = col
	r.size = Vector2(18, 1280)
	r.position = Vector2(-30, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 61
	add_child(r)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(r, "position:x", 740.0, 0.22)
	tw.tween_property(r, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void: r.queue_free())

func _rise_tide() -> void:
	var r := ColorRect.new()
	r.color = Color(0.45, 0.72, 0.95, 0.45)
	r.size = Vector2(720, 0)
	r.position = Vector2(0, 1280)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 61
	add_child(r)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "size:y", 1280.0, 0.40)
	tw.tween_property(r, "position:y", 0.0, 0.40)
	tw.chain().tween_property(r, "modulate:a", 0.0, 0.32)
	tw.chain().tween_callback(func() -> void: r.queue_free())

func _burn_edges() -> void:
	for i in 4:
		var r := ColorRect.new()
		r.color = Color(0.95, 0.45, 0.18, 0.40)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.z_index = 61
		if i == 0:
			r.size = Vector2(720, 40); r.position = Vector2(0, -40)
		elif i == 1:
			r.size = Vector2(720, 40); r.position = Vector2(0, 1280)
		elif i == 2:
			r.size = Vector2(40, 1280); r.position = Vector2(-40, 0)
		else:
			r.size = Vector2(40, 1280); r.position = Vector2(720, 0)
		add_child(r)
		var tw := create_tween()
		tw.set_parallel(true)
		if i == 0: tw.tween_property(r, "position:y", 560.0, 0.35)
		elif i == 1: tw.tween_property(r, "position:y", 740.0, 0.35)
		elif i == 2: tw.tween_property(r, "position:x", 300.0, 0.35)
		else: tw.tween_property(r, "position:x", 380.0, 0.35)
		tw.chain().tween_property(r, "modulate:a", 0.0, 0.30)
		tw.chain().tween_callback(func() -> void: r.queue_free())

func _ring_out() -> void:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 61
	add_child(c)
	var r := ColorRect.new()
	r.color = Color(0.85, 0.92, 1.0, 0.42)
	r.size = Vector2(80, 80)
	r.position = Vector2(320, 600)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(r)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "size", Vector2(1600, 1600), 0.45)
	tw.tween_property(r, "position", Vector2(-440, -160), 0.45)
	tw.tween_property(r, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(func() -> void: c.queue_free())

# ---------------- 主角：基础剑法（被动） ----------------
#   主角不进技能栏，他的六档全部折成普攻加成，组合一激活就直接加在英雄身上。
#   能落地的：伤害类（dmg_pct）、物理共享（elem_pct.物理）
#   还没接的：攻速（二档）、多打一名（三档）—— 需要改核心的普攻逻辑
func _apply_hero_passive(eff: Dictionary) -> void:
	if eff.is_empty() or _core == null:
		return
	var pct := float(eff.get("dmg_pct", 0.0))
	var ep: Dictionary = eff.get("elem_pct", {})
	pct += float(ep.get("物理", 0.0))
	if pct != 0.0:
		_core.hero["atk"] = float(_core.hero["atk"]) * (1.0 + pct / 100.0)
	# 攻速：直接抬 hero.aspd（核心的普攻间隔就是 1/aspd）
	if eff.has("aspd_pct"):
		_core.hero["aspd"] = minf(MAX_ASPD, float(_core.hero.get("aspd", 1.0)) * (1.0 + float(eff["aspd_pct"]) / 100.0))
	# 多目标 / 追击 / 剑气：记下来，普攻时结算
	for k in ["tgt_add", "chase", "qijian"]:
		if eff.has(k):
			_hero_passive[k] = float(_hero_passive.get(k, 0.0)) + float(eff[k])
	var parts: Array = []
	if pct != 0.0: parts.append("物理 +%d%%" % int(pct))
	if eff.has("aspd_pct"): parts.append("攻速 +%d%%" % int(eff["aspd_pct"]))
	if eff.has("tgt_add"): parts.append("目标 +%d" % int(eff["tgt_add"]))
	if eff.has("chase"): parts.append("追击 %d%%" % int(eff["chase"]))
	if eff.has("qijian"): parts.append("剑气 %d%%" % int(eff["qijian"]))
	if not parts.is_empty():
		_toast("基础剑法 · " + " · ".join(PackedStringArray(parts)))
	Aud.sfx("skill", -14.0)

# 主角普攻的额外结算（多目标 / 追击 / 剑气）
func _hero_extra_hits() -> void:
	if _core == null:
		return
	var foes := _live_foes()
	if foes.is_empty():
		return
	# v9 剑魄：连续打同一目标 → 攻速叠层；换目标立刻重置
	if _hero_jianpo:
		var tid := int(foes[0].get("_tid", -1))
		if tid != _jpo_tid:
			_jpo_tid = tid
			_jpo_stacks = 0
		else:
			_jpo_stacks += 1                      # 不设上限：只靠"换目标"重置
		_core.hero["aspd"] = minf(MAX_ASPD, _jpo_base_aspd * (1.0 + 0.06 * float(_jpo_stacks)))
	if _hero_passive.is_empty():
		return
	var base := float(_core.hero.get("atk", 12.0)) * 0.8
	var extra := int(_hero_passive.get("tgt_add", 0.0))
	for i in mini(extra, foes.size()):
		# 跳过最近那只（核心已经打过它），多打的从第二只开始
		if i + 1 >= foes.size():
			break
		_core._apply_dmg(foes[i + 1], base * 0.7, "物理")
	if randf() < float(_hero_passive.get("chase", 0.0)) / 100.0:
		var f0: Dictionary = foes[0]
		_core._apply_dmg(f0, base * 0.5, "物理")
		_core._push_float(float(f0["x"]), float(f0["y"]) - 40.0, "追击", Color(0.95, 0.85, 0.55))
	if randf() < float(_hero_passive.get("qijian", 0.0)) / 100.0:
		var at := Vector2(float(foes[0]["x"]), float(foes[0]["y"]))
		# 剑魄：剑气进化成「万剑归宗」——范围更大、伤害更狠
		var rad := 300.0 if _hero_jianpo else 130.0
		var mul := 2.5 if _hero_jianpo else 1.2
		for f_v in foes:
			var f: Dictionary = f_v
			if (Vector2(float(f["x"]), float(f["y"])) - at).length() <= rad:
				_core._apply_dmg(f, base * mul, "物理")
				_core._push_float(float(f["x"]), float(f["y"]) - 44.0,
					"万剑归宗" if _hero_jianpo else "剑气",
					Color(0.98, 0.94, 0.74) if _hero_jianpo else Color(0.88, 0.92, 1.0), true)
		Aud.sfx("slash_light2" if _hero_jianpo else "slash_light", -6.0 if _hero_jianpo else -8.0)
		if _hero_jianpo and _core != null:
			_core.Shake_add(5.0)

# ---------------- 剑魄（主角炫卡） ----------------
func _enable_jianpo() -> void:
	_hero_jianpo = true
	_jpo_base_aspd = float(_core.hero.get("aspd", 1.0)) if _core != null else 1.0
	_jpo_tid = -1
	_jpo_stacks = 0
	_toast("剑魄入卡组 · 连击同一目标攻速递增（换目标重置）· 剑气进化为「万剑归宗」")
	_shiny_present("jianpo")

# 剑雨：一排竖剑从天而降（剑魄专属演出）
func _sword_rain() -> void:
	for i in 9:
		var r := ColorRect.new()
		r.color = Color(0.99, 0.97, 0.86, 0.75)
		r.size = Vector2(4, 220)
		r.position = Vector2(40.0 + float(i) * 78.0, -240.0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.z_index = 61
		add_child(r)
		var tw := create_tween()
		tw.tween_interval(0.03 * float(i))
		tw.tween_property(r, "position:y", 1280.0, 0.34)
		tw.tween_property(r, "modulate:a", 0.0, 0.14)
		tw.tween_callback(func() -> void: r.queue_free())

# ============================================================
# 滚地龙 · 撞击流（生命值百分比伤害 + 台球反弹）
#   撞击伤害 = 气血上限 × 6%（物理），每跳全额、不递减
#   反弹预算：无炫卡 全场 1 次；有「滚山」每个敌人各一次 → 无限连锁
# ============================================================
const RAM_HP_PCT := 6.0          # 撞击伤害 = 气血上限 × 6%
const RAM_KNOCK := 1800.0        # 击退初速 px/s（要压过核心的寻路移动）
const RAM_HIT_R := 34.0          # 碰撞判定半径（3★ 会加）
const WALL_X0 := 24.0
const WALL_X1 := 696.0
const WALL_Y0 := 150.0
const WALL_Y1 := 700.0

var _ram_budget := 0             # 本次撞击还剩几次反弹
var _ram_shiny := false          # 滚山：每个敌人各弹一次
var _ram_dmg := 0.0              # 本次撞击的单跳伤害

func _ram_mods() -> Dictionary:
	return _anc_mod.get("gundilong", {})

func _ram_damage() -> float:
	var m := _ram_mods()
	var pct := RAM_HP_PCT * (1.0 + (float(m.get("dmg_pct", 0.0)) + float(_elem_mod.get("物理", 0.0))) / 100.0)
	return float(_core.hero.get("hp_max", 200.0)) * pct / 100.0

# 化身肉蛋：把最近的一只撞飞
func _charge_ram() -> void:
	var foes := _live_foes()
	if foes.is_empty():
		return
	var f0: Dictionary = foes[0]
	var hp0 := Vector2(_core.hero_pos)
	var dir := (Vector2(float(f0["x"]), float(f0["y"])) - hp0)
	if dir.length() < 1.0:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	_ram_dmg = _ram_damage()
	_ram_budget = 999 if _ram_shiny else 1
	# 冲撞演出：一道土黄streak
	_ram_streak(hp0, Vector2(float(f0["x"]), float(f0["y"])))
	_core._apply_dmg(f0, _ram_dmg, "物理")
	_core._push_float(float(f0["x"]), float(f0["y"]) - 46.0, "肉蛋冲击", Color(0.92, 0.80, 0.42), true)
	var pm := 1.0 + float(_ram_mods().get("impact", 0.0)) * 0.15   # 冲击力：每点 +15% 击退距离
	f0["_kx"] = dir.x * RAM_KNOCK * pm
	f0["_ky"] = dir.y * RAM_KNOCK * pm
	f0["_seg_a"] = Vector2(float(f0["x"]), float(f0["y"]))   # 扫掠起点
	f0["_bounce_hit"] = true
	_core.Shake_add(7.0)
	Aud.sfx("hit_heavy", -6.0)

func _ram_streak(a: Vector2, b: Vector2) -> void:
	var r := ColorRect.new()
	r.color = Color(0.92, 0.80, 0.42, 0.55)
	r.size = Vector2(maxf(6.0, (b - a).length()), 10)
	r.position = _core.position + a
	r.pivot_offset = Vector2(0, 5)
	r.rotation = (b - a).angle()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 9
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.30)
	tw.tween_callback(func() -> void: r.queue_free())

func _tick_knock(dt: float) -> void:
	if _core == null:
		return
	for f_v in _core.foes:
		var f: Dictionary = f_v
		var kx := float(f.get("_kx", 0.0))
		var ky := float(f.get("_ky", 0.0))
		if kx == 0.0 and ky == 0.0:
			continue
		if float(f.get("hp", 0.0)) <= 0.0:
			f["_kx"] = 0.0
			f["_ky"] = 0.0
			continue
		var px := float(f["x"]) + kx * dt
		var py := float(f["y"]) + ky * dt
		# 撞墙 → 反弹一次后停（撞墙不算消耗预算）
		if px < WALL_X0 or px > WALL_X1:
			kx = -kx * 0.6
			px = clampf(px, WALL_X0, WALL_X1)
		if py < WALL_Y0 or py > WALL_Y1:
			ky = -ky * 0.6
			py = clampf(py, WALL_Y0, WALL_Y1)
		f["x"] = px
		f["y"] = py
		# 衰减
		kx *= 0.955
		ky *= 0.955
		if absf(kx) < 6.0 and absf(ky) < 6.0:
			kx = 0.0
			ky = 0.0
		f["_kx"] = kx
		f["_ky"] = ky
		# 撞到别的怪 → 连锁
		if _ram_budget <= 0:
			continue
		var seg_a: Vector2 = f.get("_seg_a", Vector2(float(f["x"]), float(f["y"])))
		var seg_b := Vector2(px, py)
		f["_seg_a"] = seg_b
		var reach := RAM_HIT_R + _ram_radius_bonus()
		for o_v in _core.foes:
			var o: Dictionary = o_v
			if o == f or float(o.get("hp", 0.0)) <= 0.0 or bool(o.get("_bounce_hit", false)):
				continue
			if _dist_point_seg(Vector2(float(o["x"]), float(o["y"])), seg_a, seg_b) > reach:
				continue
			_ram_budget -= 1
			o["_bounce_hit"] = true
			_core._apply_dmg(o, _ram_dmg, "物理")
			_core._push_float(float(o["x"]), float(o["y"]) - 40.0, "反弹", Color(0.92, 0.80, 0.42))
			var d := (Vector2(float(o["x"]), float(o["y"])) - Vector2(px, py))
			if d.length() < 1.0:
				d = Vector2(0, -1)
			d = d.normalized()
			var sp := float(_ram_mods().get("stun_s", 0.0))
			o["para"] = maxf(float(o.get("para", 0.0)), sp if sp > 0.0 else 0.0)
			if _ram_shiny or _ram_mods().get("stun_s", 0.0) != 0.0:
				var pm2 := 1.0 + float(_ram_mods().get("impact", 0.0)) * 0.15
				o["_kx"] = d.x * RAM_KNOCK * pm2
				o["_ky"] = d.y * RAM_KNOCK * pm2
			# 滚山：每次反弹 → 气血上限固定 +8（占位，炫卡实装后打开）
			if _ram_shiny:
				_core.hero["hp_max"] = float(_core.hero["hp_max"]) + 8.0
				_core.hero["hp"] = float(_core.hero["hp"]) + 8.0
			break

func _ram_radius_bonus() -> float:
	return float(_ram_mods().get("radius_add", 0.0))

# 点到线段的距离（用于"撞飞路径扫过谁"）
func _dist_point_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

# ---------------- 滚山（滚地龙炫卡） ----------------
#   每个被撞的敌人都能各弹一次 → 理论上无限连锁
#   每次触发反弹 → 气血上限固定 +8
const GUNSHAN_HP := 8.0

func _enable_gunshan() -> void:
	_ram_shiny = true
	_toast("滚山入卡组 · 每个被撞的敌人都能反弹一次，每次反弹气血上限 +8")
	_shiny_present("gunshan")

func _gunshan_grow() -> void:
	_core.hero["hp_max"] = float(_core.hero["hp_max"]) + GUNSHAN_HP
	_core.hero["hp"] = float(_core.hero["hp"]) + GUNSHAN_HP

# ============================================================
# 苏青鸾 · 青鸾飞刃（直线穿透 + 回程）
#   穿透 = 一条线上能打到几个人；飞刀 = 同时几条线
#   5★ 回旋：到终点后原路再穿一遍（伤害 ×回程倍率）
# ============================================================
const FEIREN_HALF_W := 26.0       # 飞刃判定半宽
const FEIREN_LEN := 780.0         # 飞刃长度

func _cast_feiren(mul: float) -> void:
	var m: Dictionary = _anc_mod.get("qingluan", {})
	var foes := _live_foes()
	if foes.is_empty():
		return
	var dmg_pct := float(m.get("dmg_pct", 0.0)) + float(_elem_mod.get("物理", 0.0))
	var pierce := 1 + int(m.get("pierce", 0.0))
	if _wanren:
		pierce += 2 + _wanren_pierce            # 炫卡：起步 +2，回程成长无上限
	var knives := 1 + int(m.get("knife", 0.0))
	if _wanren:
		knives += pierce                        # 炫卡：每 1 点穿透 +1 把飞刀
	var volley := float(m.get("volley", 0.0)) > 0.0
	var vmul := 1.0 + float(m.get("volley_pct", 0.0)) / 100.0
	var base := float(_core.hero.get("atk", 12.0)) * mul * (1.0 + dmg_pct / 100.0)
	var hp0 := Vector2(_core.hero_pos)
	var dir := (Vector2(float(foes[0]["x"]), float(foes[0]["y"])) - hp0)
	if dir.length() < 1.0:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	for k in knives:
		var ang := dir.angle() + (float(k) - float(knives - 1) * 0.5) * 0.16
		_feiren_line(hp0, Vector2(cos(ang), sin(ang)), base, pierce, volley, vmul)
	Aud.sfx("slash_light", -8.0)

func _feiren_line(origin: Vector2, d: Vector2, base: float, pierce: int, volley: bool, vmul: float) -> void:
	var hits: Array = []
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		var rel := Vector2(float(f["x"]), float(f["y"])) - origin
		var t := rel.dot(d)
		if t < 0.0 or t > FEIREN_LEN:
			continue
		if absf(rel.cross(d)) > FEIREN_HALF_W:
			continue
		hits.append({"f": f, "t": t})
	hits.sort_custom(func(a, b) -> bool: return float(a["t"]) < float(b["t"]))
	var n := mini(pierce, hits.size())
	for i in n:
		var f: Dictionary = (hits[i] as Dictionary)["f"]
		_core._apply_dmg(f, base, "物理")
		_core._push_float(float(f["x"]), float(f["y"]) - 42.0, "飞刃", Color(0.55, 0.82, 0.90), i == 0)
	if volley and n > 0:
		if _wanren:
			_wanren_volleys += 1
			if _wanren_volleys % 3 == 0:
				_wanren_pierce += 1
				_toast("万刃 · 穿透 +1（累计 %d）" % (2 + _wanren_pierce))
		for i in range(n - 1, -1, -1):
			var f2: Dictionary = (hits[i] as Dictionary)["f"]
			if float(f2.get("hp", 0.0)) <= 0.0:
				continue
			_core._apply_dmg(f2, base * vmul, "物理")
			_core._push_float(float(f2["x"]), float(f2["y"]) - 62.0, "回程", Color(0.75, 0.95, 1.0), true)
	var a: Vector2 = _core.position + origin
	var r := ColorRect.new()
	r.color = Color(0.70, 0.92, 1.0, 0.7)
	r.size = Vector2(FEIREN_LEN, 4)
	r.position = Vector2(a.x, a.y - 2.0)
	r.pivot_offset = Vector2(0, 2)
	r.rotation = d.angle()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 9
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: r.queue_free())

# ---------------- 万刃（苏青鸾炫卡） ----------------
func _enable_wanren() -> void:
	_wanren = true
	_wanren_pierce = 0
	_wanren_volleys = 0
	_toast("万刃入卡组 · 穿透无上限，每点穿透 +1 把飞刀，每 3 次回程穿透 +1")
	_shiny_present("wanren")

# ============================================================
# 柳卿卿 · 回春（治疗 + 环毒 + 易伤）
#   治疗 = 攻击 × 200% × (1 + 治疗% + 木系%)      —— 伤害刻意低，她是辅助
#   环毒 = 圈内敌人每秒 攻击 × 30% × 层数 × (1 + 木系%)
#   5★ 长春：毒更久，且中招者受伤 +10%（唯一一层，只刷新）
# ============================================================
const HEAL_RATIO := 2.0
const POISON_RATE := 0.30
const AURA_BASE_R := 110.0

func _wood_pct() -> float:
	return float(_elem_mod.get("木系", 0.0))

func _cast_heal(mul: float) -> void:
	var m: Dictionary = _anc_mod.get("liuqingqing2", {})
	var wood := _wood_pct()
	var heal := float(_core.hero.get("atk", 12.0)) * HEAL_RATIO * (1.0 + (float(m.get("heal_pct", 0.0)) + wood) / 100.0)
	var h: Dictionary = _core.hero
	h["hp"] = minf(float(h["hp_max"]), float(h["hp"]) + heal)
	_core._push_float(_core.hero_pos.x, _core.hero_pos.y - 60.0, "+%d" % int(heal), Color(0.42, 0.85, 0.40), true)
	var rad := AURA_BASE_R + float(m.get("radius_add", 0.0))
	var dur := 4.0 + float(m.get("poison_dur", 0.0))
	var vuln := float(m.get("vuln", 0.0))
	var hp0 := Vector2(_core.hero_pos)
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		if (Vector2(float(f["x"]), float(f["y"])) - hp0).length() > rad:
			continue
		f["poison"] = float(f.get("poison", 0.0)) + 1.0
		f["poison_t"] = maxf(float(f.get("poison_t", 0.0)), dur)
		if vuln > 0.0:
			f["vuln_t"] = maxf(float(f.get("vuln_t", 0.0)), dur)   # 只刷新，不叠层
			f["vuln_pct"] = vuln
	# 绿色环波
	_heal_ring(rad)
	Aud.sfx("enlighten", -10.0)

func _heal_ring(rad: float) -> void:
	var r := ColorRect.new()
	r.color = Color(0.45, 0.85, 0.42, 0.35)
	r.size = Vector2(60, 60)
	r.position = _core.position + Vector2(_core.hero_pos.x - 30.0, _core.hero_pos.y - 30.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 8
	add_child(r)
	var target := rad * 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "size", Vector2(target, target), 0.45)
	tw.tween_property(r, "position", _core.position + Vector2(_core.hero_pos.x - target * 0.5, _core.hero_pos.y - target * 0.5), 0.45)
	tw.tween_property(r, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(func() -> void: r.queue_free())

func _tick_poison(dt: float) -> void:
	if _core == null:
		return
	var wood := _wood_pct()
	for f_v in _core.foes:
		var f: Dictionary = f_v
		var st := float(f.get("poison", 0.0))
		if st <= 0.0:
			continue
		if float(f.get("hp", 0.0)) <= 0.0:
			f["poison"] = 0.0
			continue
		f["poison_acc"] = float(f.get("poison_acc", 0.0)) + dt
		while float(f["poison_acc"]) >= 1.0:
			f["poison_acc"] = float(f["poison_acc"]) - 1.0
			var dmg := float(_core.hero.get("atk", 12.0)) * POISON_RATE * (1.0 + wood / 100.0) * st
			_core._apply_dmg(f, dmg * _vuln_mul(f), "木系")
			_core._push_float(float(f["x"]), float(f["y"]) - 34.0, "毒", Color(0.45, 0.80, 0.40))
		f["poison_t"] = float(f.get("poison_t", 0.0)) - dt
		if float(f["poison_t"]) <= 0.0:
			f["poison"] = maxf(0.0, st - 1.0)
			f["poison_t"] = 4.0
			if float(f["poison"]) <= 0.0:
				f.erase("poison")

# 易伤倍率（柳卿卿 5★）：只刷新不叠加
func _vuln_mul(f: Dictionary) -> float:
	if float(f.get("vuln_t", 0.0)) > 0.0:
		return 1.0 + float(f.get("vuln_pct", 0.0)) / 100.0
	return 1.0

func _tick_vuln(dt: float) -> void:
	if _core == null:
		return
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("vuln_t", 0.0)) > 0.0:
			f["vuln_t"] = float(f["vuln_t"]) - dt

# ---------------- 百草（柳卿卿炫卡） ----------------
var _baicao := false
# v12 明烛光环（纯被动）
var _mingzhu := false
var _aura_pull_acc := 0.0
var _undying_lamp := false
var _lamp_kills := 0
var _aura_extra_radius := 0.0

func _enable_baicao() -> void:
	_baicao = true
	_toast("百草入卡组 · 毒素可叠加，施放有几率连放（只扣一次内力）")
	_shiny_present("baicao")

# 返回本次实际施放次数（只判一种）
func _baicao_times() -> int:
	var r := randf()
	if r < 0.10:
		return 5
	if r < 0.35:
		return 3
	if r < 0.85:
		return 2
	return 1

# ============================================================
# 明烛 · 灯照光环（纯被动，不进技能栏）
#   圈内敌人：减速 · 易伤（5★ 聚灯：每秒 20% 概率被吸向中心 + 木系磨血）
#   2★ 长明：圈内主角回血回内
#   聚灯伤害随半径成长：攻击 × 15% × (半径 / 180)
# ============================================================
const AURA_R_BASE := 180.0
const AURA_PULL_STEP := 120.0

func _aura_radius() -> float:
	var m: Dictionary = _anc_mod.get("mingzhu", {})
	var r := AURA_R_BASE + float(m.get("radius_add", 0.0)) + _aura_extra_radius
	if _undying_lamp:
		r += 40.0
	return r

func _tick_aura(dt: float) -> void:
	if not _mingzhu or _core == null:
		return
	var m: Dictionary = _anc_mod.get("mingzhu", {})
	var rad := _aura_radius()
	var vuln := float(m.get("vuln", 0.0))
	var pull := float(m.get("pull", 0.0)) > 0.0
	var heal_aura := float(m.get("heal_aura", 0.0)) > 0.0
	var hp0 := Vector2(_core.hero_pos)
	if heal_aura:
		var h: Dictionary = _core.hero
		h["hp"] = minf(float(h["hp_max"]), float(h["hp"]) + float(h["hp_max"]) * 0.008 * dt)
		_mp = minf(_mp_max, _mp + 6.0 * dt)
	_aura_pull_acc += dt
	var do_pull := _aura_pull_acc >= 1.0
	if do_pull:
		_aura_pull_acc -= 1.0
	var wood := float(_elem_mod.get("木系", 0.0))
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		var d := Vector2(float(f["x"]), float(f["y"])) - hp0
		if d.length() > rad:
			continue
		f["slow_t"] = maxf(float(f.get("slow_t", 0.0)), 0.3)      # 持续减速
		if vuln > 0.0:
			f["vuln_t"] = maxf(float(f.get("vuln_t", 0.0)), 0.3)
			f["vuln_pct"] = vuln
		if pull and do_pull and randf() < 0.20:
			var dir := (-d).normalized()
			f["x"] = float(f["x"]) + dir.x * AURA_PULL_STEP
			f["y"] = float(f["y"]) + dir.y * AURA_PULL_STEP
			var dmg := float(_core.hero.get("atk", 12.0)) * 0.15 * (rad / AURA_R_BASE) * (1.0 + wood / 100.0)
			_core._apply_dmg(f, dmg * _vuln_mul(f), "木系")
			_core._push_float(float(f["x"]), float(f["y"]) - 30.0, "聚", Color(0.95, 0.85, 0.55))

# ---------------- 不灭之灯（明烛炫卡） ----------------
func _enable_undying_lamp() -> void:
	_undying_lamp = true
	_lamp_kills = 0
	_toast("不灭之灯入卡组 · 半径 +40，每击杀 5 只再 +10（无上限）")
	_shiny_present("undying")

# ============================================================
# 纸鸢 · 剪纸成兵（召唤系，复用核心的召唤物系统）
#   纸人：继承主角攻击 15%（核心 "paper" 分支）· 会挨打 · 会增殖
# ============================================================
var _qianzhi := false

func _cast_paper() -> void:
	var m: Dictionary = _anc_mod.get("zhiyuan", {})
	var n := 2 + int(m.get("paper_add", 0.0))
	if _qianzhi:
		n += 0
	var secs := 8.0 + float(m.get("life_flat", 0.0))
	var life_m := secs / 30.0          # cn_life() 基准 30 秒
	for i in n:
		_core.summon_minion("纸人", Color(0.95, 0.93, 0.86), 0.72, 0.5, life_m, 1.0, 0.0, 99, "", "paper")
	_toast("剪纸成兵 · 召 %d 张纸人（存在 %d 秒）" % [n, int(secs)])
	Aud.sfx("paper", -8.0)

func _enable_qianzhi() -> void:
	_qianzhi = true
	_toast("千纸入卡组 · 纸人击杀会增殖，消失时分裂 2 个小纸人")
	_shiny_present("qianzhi")

# ============================================================
# 陈石 · 石皮（纯被动，不进技能栏）
#   每 X 秒 +N 层（无上限）· 每层防御 +2/+3 · 挨打掉 1 层并反手真实伤害（防御×0.5）
#   5★ 累计脱 10 层 → 碎裂（范围真实伤害）
#   炫卡石殒：有皮时 25% 固定减伤 · 挨打 30% 再涨一层
# ============================================================
var _shixi := false
var _stone_layers := 0
var _stone_acc := 0.0
var _stone_def := 0.0
var _stone_burst := 0
var _shiyun := false

func _stone_per_def() -> float:
	var m: Dictionary = _anc_mod.get("chenshi2", {})
	return 3.0 if float(m.get("stone_def", 0.0)) > 0.0 else 2.0

func _apply_stone_def() -> void:
	if _core == null:
		return
	_core.hero["def"] = _stone_def + float(_stone_layers) * _stone_per_def()
	_core.hero["cut_extra"] = 0.25 if (_shiyun and _stone_layers > 0) else 0.0

func _tick_stone(dt: float) -> void:
	if not _shixi or _core == null:
		return
	var m: Dictionary = _anc_mod.get("chenshi2", {})
	var interval := float(m.get("stone_rate", 3.0))
	if interval <= 0.0:
		interval = 3.0
	var add := int(m.get("stone_add", 1.0))
	if add < 1:
		add = 1
	_stone_acc += dt
	while _stone_acc >= interval:
		_stone_acc -= interval
		_stone_layers += add
	_apply_stone_def()

func _stone_on_hit() -> void:
	if not _shixi or _core == null:
		return
	if _stone_layers > 0:
		_stone_layers -= 1
		_stone_burst += 1
		_apply_stone_def()
		var dmg := float(_core.hero.get("def", 0.0)) * 0.5
		var foes := _live_foes()
		if not foes.is_empty() and dmg > 0.0:
			_core._apply_dmg(foes[0], dmg, "真实")
			_core._push_float(float(foes[0]["x"]), float(foes[0]["y"]) - 40.0, "石屑", Color(0.80, 0.78, 0.72))
		var need := int((_anc_mod.get("chenshi2", {}) as Dictionary).get("stone_burst", 0.0))
		if need > 0 and _stone_burst >= need:
			_stone_burst = 0
			_stone_shatter()
			_stone_drop_shards()
	if _shiyun and randf() < 0.30:
		_stone_layers += 1
		_apply_stone_def()

# 5★ 碎裂：一圈真实伤害
func _stone_shatter() -> void:
	var dmg := float(_core.hero.get("def", 0.0)) * 1.5
	var hp0 := Vector2(_core.hero_pos)
	var hit := 0
	for f_v in _live_foes():
		var f: Dictionary = f_v
		if (Vector2(float(f["x"]), float(f["y"])) - hp0).length() <= 140.0:
			_core._apply_dmg(f, dmg * _vuln_mul(f), "真实")
			_core._push_float(float(f["x"]), float(f["y"]) - 50.0, "碎裂", Color(0.86, 0.84, 0.76), true)
			hit += 1
	if hit > 0:
		_core.Shake_add(6.0)
	_toast("碎裂！一圈真实伤害（防御 %d）" % int(float(_core.hero.get("def", 0.0))))

# ---------------- 石殒（陈石炫卡） ----------------
func _enable_shiyun() -> void:
	_shiyun = true
	_apply_stone_def()
	_toast("石殒入卡组 · 石皮在身 25% 减伤，挨打 30% 再涨一层")
	_shiny_present("shiyun")

# ============================================================
# 收尾：纸人爆散 / 千纸分裂 / 地面石皮
# ============================================================
var _zhiyuan := false
var _shards: Array = []          # {pos, t, r} 地上的石皮
var _shard_acc := 0.0

func _enable_zhiyuan() -> void:
	_zhiyuan = true

# 每帧扫描核心的召唤物：纸人进入 dying 就爆一次（不改核心）
func _tick_paper(dt: float) -> void:
	if not _zhiyuan or _core == null:
		return
	var m: Dictionary = _anc_mod.get("zhiyuan", {})
	var burst := float(m.get("burst", 0.0)) > 0.0
	for m_v in _core._minions:
		var mm: Dictionary = m_v
		if str(mm.get("kind", "")) != "纸人":
			continue
		if float(mm.get("dying", 0.0)) <= 0.0 or bool(mm.get("_burst_done", false)):
			continue
		mm["_burst_done"] = true
		var at: Vector2 = mm["pos"]
		if burst:
			var dmg := float(_core.hero.get("atk", 12.0)) * 1.5
			for f_v in _live_foes():
				var f: Dictionary = f_v
				if (Vector2(float(f["x"]), float(f["y"])) - at).length() <= 110.0:
					_core._apply_dmg(f, dmg * _vuln_mul(f), "召唤")
					_core._push_float(float(f["x"]), float(f["y"]) - 36.0, "爆散", Color(0.94, 0.92, 0.86))
			_paper_puff(at)
			Aud.sfx("paper", -10.0)
		if _qianzhi:
			for k in 2:
				_core.summon_minion("小纸人", Color(0.98, 0.96, 0.90), 0.5, 0.3, 5.0 / 30.0, 0.9, 0.0, 99, "", "paper")
			_paper_puff(at)
			Aud.sfx("paper", -12.0)

func _paper_puff(at: Vector2) -> void:
	var r := ColorRect.new()
	r.color = Color(0.96, 0.94, 0.88, 0.55)
	r.size = Vector2(30, 30)
	r.position = _core.position + at - Vector2(15, 15)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 8
	add_child(r)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "size", Vector2(150, 150), 0.35)
	tw.tween_property(r, "position", _core.position + at - Vector2(75, 75), 0.35)
	tw.tween_property(r, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(func() -> void: r.queue_free())

func _stone_drop_shards() -> void:
	var m: Dictionary = _anc_mod.get("chenshi2", {})
	if float(m.get("shard_drop", 0.0)) <= 0.0:
		return
	var hp0 := Vector2(_core.hero_pos)
	for i in 3:
		var ang := randf() * TAU
		var rad := randf_range(30.0, 120.0)
		_shards.append({"pos": hp0 + Vector2(cos(ang), sin(ang)) * rad, "t": 8.0, "r": 30.0})

func _tick_shards(dt: float) -> void:
	if _core == null:
		return
	var extra_r := 50.0 if _shiyun else 0.0
	_shard_acc += dt
	var tick := _shard_acc >= 1.0
	if tick:
		_shard_acc -= 1.0
	var hp0 := Vector2(_core.hero_pos)
	for s_v in _shards:
		var s: Dictionary = s_v
		s["t"] = float(s["t"]) - dt
		var sp: Vector2 = s["pos"]
		if _shixi and hp0.distance_to(sp) <= 40.0:
			s["t"] = 0.0
			_stone_layers += 1
			_apply_stone_def()
			_core._push_float(sp.x, sp.y - 30.0, "石皮 +1", Color(0.84, 0.82, 0.74))
			continue
		if _shiyun and tick:
			for f_v in _live_foes():
				var f: Dictionary = f_v
				if (Vector2(float(f["x"]), float(f["y"])) - sp).length() <= float(s["r"]) + extra_r:
					var dmg := float(_core.hero.get("def", 0.0)) * 0.2
					if dmg > 0.0:
						_core._apply_dmg(f, dmg, "真实")
						_core._push_float(float(f["x"]), float(f["y"]) - 26.0, "砾", Color(0.80, 0.78, 0.70))
	for i in range(_shards.size() - 1, -1, -1):
		if float((_shards[i] as Dictionary)["t"]) <= 0.0:
			_shards.remove_at(i)

# ============================================================
# 群 / 险 两系：把卡牌加成推给核心（每波定额 + 全局难度）
# ============================================================
func _push_run_mods() -> void:
	if _core == null:
		return
	_core.wave_extra = _wave_extra
	_core.extra_diff_mul = 1.0 + _diff_pct / 100.0
	if _core.has_method("wave_reset_quota"):
		_core.wave_reset_quota()
	pass

# ============================================================
# 险系：怪物类型（文钱怪 / 灵晶怪）+ 宝物·首领奖励加成
#   额外刷出来的怪打 rtype 标签；死了按类型给奖励（用 _tid 消失来判定）
# ============================================================
var _rtype_seen: Dictionary = {}

func _spawn_typed_foes() -> void:
	if _core == null:
		return
	for i in _coin_count_extra:
		_core._spawn_foe("normal")
		_tag_last("coin")
	for i in _crystal_count_extra:
		_core._spawn_foe("normal")
		_tag_last("crystal")

func _tag_last(rt: String) -> void:
	if _core.foes.is_empty():
		return
	var f: Dictionary = _core.foes[_core.foes.size() - 1]
	f["rtype"] = rt

func _tick_rtype() -> void:
	if _core == null:
		return
	var alive := {}
	for f_v in _core.foes:
		var f: Dictionary = f_v
		var rt := str(f.get("rtype", ""))
		if rt == "":
			continue
		var tid := int(f.get("_tid", 0))
		alive[tid] = rt
		if not _rtype_seen.has(tid):
			_rtype_seen[tid] = rt
	for tid in _rtype_seen.keys():
		if not alive.has(tid):
			_grant_rtype(str(_rtype_seen[tid]))
			_rtype_seen.erase(tid)

func _grant_rtype(rt: String) -> void:
	match rt:
		"coin":
			_add_wen(int(20.0 * (1.0 + _treasure_pct / 100.0)))
		"crystal":
			_crystal += int(round(2.0 * (1.0 + _treasure_pct / 100.0)))
			_update_crystal()
		"boss":
			_add_wen(int(200.0 * (1.0 + _boss_pct / 100.0)))
			_crystal += int(round(20.0 * (1.0 + _boss_pct / 100.0)))
			_update_crystal()

# ============================================================
# 重利（经济系炫卡）：合成经济系 3% 出
#   抽卡选中一张 → 每张重利掷 10% → 中了复制一张（当场吞噬、保留效果）
#   复制体再独立掷 → 链式
# ============================================================
var _zhongli_count := 0
var _zhongli_rolled := false

func _enable_zhongli() -> void:
	_zhongli_count += 1
	_toast("重利入卡组 · 抽卡选中时有 %d 次 10%% 复制机会" % _zhongli_count)
	_shiny_present("zhongli")

func _zhongli_try(id: String) -> void:
	if _zhongli_count <= 0:
		return
	var queue: Array = []
	for i in _zhongli_count:
		queue.append(id)
	var guard := 0
	var hits := 0
	while not queue.is_empty() and guard < 12:
		guard += 1
		var cid := str(queue.pop_front())
		if randf() < 0.10:
			hits += 1
			_grant_copy(cid)
			queue.append(cid)          # 复制体再独立掷
	if hits > 0:
		_toast("重利 · 复制了 %d 张（全部吞噬，效果保留）" % hits)

# 复制体：不进卡组格，当场吞噬，但效果/进度保留
func _grant_copy(id: String) -> void:
	var c: Dictionary = _card_db.get(id, {})
	if c.is_empty():
		return
	if c.has("ancestor"):
		_cards.append(id)
		_check_sets()
		_cards.erase(id)
		_refresh_deck()
	else:
		var own := {"atk": 0.0, "def": 0.0, "hp": 0.0, "mp": 0.0, "gold_pct": 0.0, "crystal_pct": 0.0,
			"count": 0.0, "coin_count": 0.0, "crystal_count": 0.0, "treasure_pct": 0.0, "boss_pct": 0.0}
		var k := str(c.get("own_key", ""))
		if own.has(k):
			own[k] = float(c.get("own_val", 0))
			_apply_own(own)
	_core._push_float(_core.hero_pos.x, _core.hero_pos.y - 80.0, "复制 · " + str(c.get("name", "")), Color(0.96, 0.88, 0.55), true)

# ============================================================
# 财（经济线）：随机吞噬卡组的卡 —— 效果与进度都保留
# ============================================================
var _devouring := false

func _devour_keep(n: int) -> void:
	if _devouring:
		return
	_devouring = true
	if _cards.is_empty():
		_devouring = false
		return
	for i in n:
		if _cards.is_empty():
			break
		var pick := str(_cards[randi() % _cards.size()])
		_cards.erase(pick)
		var c: Dictionary = _card_db.get(pick, {})
		if c.has("ancestor"):
			_virtual_cards.append(pick)
		_toast("财 · 吞噬「%s」（效果保留）" % str(c.get("name", "")))
	_refresh_deck()
	_devouring = false
