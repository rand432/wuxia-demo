extends Control
# ============================================================
# kushou/battle_ui.gd —— 新战斗界面（按 v31 草图）
#   独立场景：先跑通布局/交互，再接进关卡流程。
#   720×1280：顶栏 0..80 / 战场 150..870 / 卡组 880..1050 / 底栏 1076..1280
#   抽卡页无外框、不暂停；三张卡框浮在战场上。
# ============================================================

const W := 720.0
const H := 1280.0
const FONT := preload("res://fonts/ink.ttf")
const PLAYER_TEX := preload("res://assets/char/player_q.png")
const BattleCore := preload("res://kushou/kushou_battle.gd")
const TokenActor := preload("res://kushou/token_actor.gd")
const CardData := preload("res://kushou/card_data.gd")
const LevelState := preload("res://shared/level_state.gd")
const TutorialOverlay := preload("res://kushou/tutorial_overlay.gd")
const AncestorData := preload("res://kushou/ancestor_data.gd")
const AttackFx := preload("res://kushou/attack_fx.gd")
const BlackMarket := preload("res://kushou/black_market.gd")

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
# 总计页：顶部分类钮（卡组 / 宝物 / 组合）
var _tot_tabs: Array = []
var _tot_keys: Array = ["bond", "combo"]
var _tot_tab := "combo"          # 默认先看「组合」（玩家最关心的已合成列表）
var _tot_btn: Button = null
var _tot_hint_shown := false     # 本局是否已经提示过「点总计看组合」
var _devoured: Array = []          # 被吞噬的炫名单卡（组合页里也显示）
var _combo_boost := {}             # 组合名 → 效果增幅（羁绊换来的，永久有效）
var _combo_frac := {}              # 整数类组合的小数余额（+40% 攒两次给一次）
var _sys_combos := {}              # 普通卡组合名集合（跟家传组合重名时，按普通卡算）
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
var _max_wave := 5
var _chips := {}
var _chal_btn = null
var _tut = null
var _boss_spawned := false
var _market_tile = null
var _draw_tile = null
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
var _l1_attr_shown := false
var _l1_aug_shown := false
var _l1_yuhu_shown := false
var _l5_mate_shown := false
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
var _bond_unlocked := {}        # 已解锁的羁绊名（只有这些会出现在三选一里）
var _bond_taken := {}           # 已经结过的羁绊名（不重复出现）
var _crystal_lock := false      # 「倾囊」之后：灵晶收入归零
var _rare_buffs: Array = []     # 限时 buff：{amount, t}
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
var _equip_vuln := 0.0               # 黑市拿到装备/神器后，偷偷给怪的易伤
var _family_shiny_ready := false     # 第五关：第二组家传合成后，下一手必出炫彩
var _family_shiny_done := false
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
const SEALED := ["zl", "cuisanniang", "jicanghai"]   # 最强的三位封印；其余六位可按关解锁
var _combined: Array = []
var _stats := {"atk": 0.0, "def": 0.0, "hp": 0.0}
# v6：卡池「防御」换算成固定减免的系数（1 点防御 = 3%，按 100 伤等效对齐旧手感）
const EquipmentStats := preload("res://shared/equipment_stats.gd")
const DEF_CARD_TO_RED := EquipmentStats.DEF_TO_RED
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
var _bm = null
var _coin_lb: Label
var _kill_lb: Label
var _life_lb: Label
var _life := 100          # 当局生命：主角倒下不再直接结束，按剩余怪扣命
var _run_over := false            # 本局已结算（命尽 / 通关）
var _skip_reward_wave := false    # 这一波打输了：过波但不给奖励
var _run_time := 0.0              # 本局存活时间
var _chal_cd: Array = [0.0, 0.0, 0.0, 0.0, 0.0]   # 五种挑战的冷却剩余
var _fly_layer = null           # 资源飞行层
var _fly: Array = []
var _pulses: Dictionary = {}   # 资源格被加钱时的缩放脉冲
var _boss_bar = null           # 首领血条
var _foe_pool: Array = []      # 怪物牌对象池（省掉每只都建 Shader/节点的开销）
var _recycle_q: Array = []     # 阵亡动画播完再回收
var _boss_bar_t := 0.0
var _boss_on := false          # 首领在场时特效降档（首领战场景本来就重）
var _flash_rect: ColorRect = null  # 技能释放时的整屏微闪
var _cast_dtype := ""              # 最近一次释放的技能属性（决定闪光颜色）
var _boss_veil: ColorRect = null   # 首领登场：压暗
var _boss_spot: Sprite2D = null    # 首领登场：聚光
var _boss_name_lb: Label = null    # 首领登场：名字大字
var _last_combo := 0            # 连杀里程碑用（每 10 连炸一口）
const PFX_MAX_LIVE := 26          # 同屏特效上限（实测 60fps 有余量，放回 26）
var _curio_sq = null             # 奇物方块（战场右下，与挑战对称）
var _curio_cd := 0.0             # 奇物冷却剩余
var _curio_uses := 0             # 本局喝了几次（详情页显示）
var _curio_detail: Control = null
var _rare_taken: Dictionary = {}   # 抽到过的稀有单卡（全部唯一）
var _wave_lb: Label
var _hp_lb: Label
var _wen := 0
var _kills := 0
var _crystal := 100
var _crystal_lb: Label
var _draw_paid := false
var _draw_anim := false
var _draw_refresh_btn: Button = null
var _hero_token = null
var _foe_tokens := {}
var _no_tokens := false   # 对照测试用：不创建/不更新怪的本体
var _no_ui := false       # 对照测试用：不创建 UI 面板
var _no_ui2 := false      # 对照测试用：连背景/黑市/教学/卡牌数据都不建
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
	GameState.ensure_loaded()
	var _t_ready := Time.get_ticks_usec()
	_max_wave = LevelState.waves()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 17
	theme = th
	if not _no_ui2:
		_init_cards()
		_build_bg()
	if not _no_ui:
		_build_hud()
	_build_field()
	if not _no_ui:
		_build_deck()
		_build_bottom()
		_q_init()
		_build_draw()
	# v6：角色属性统一走详细属性页（attr_panel），旧 8 行窗不再创建
	if not _no_ui:
		_build_exit()
		_build_toast()
		_build_combined()
		_build_god_pick()
		_build_str()
		_build_trea()
	if not _no_ui2:
		_bm = BlackMarket.new()
		_bm.setup(_core, self)
		add_child(_bm)
		_bm.z_index = 40
		_bm.visible = false
		_tut = TutorialOverlay.new()
		add_child(_tut)
	_refresh_deck()
	_apply_level_preview()
	_maybe_level_button_tutorial.call_deferred()
	var fade := ColorRect.new()
	fade.color = Color(0.03, 0.03, 0.04, 1.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.z_index = 200
	add_child(fade)
	var twf := create_tween()
	twf.tween_property(fade, "color:a", 0.0, 0.45)
	twf.tween_callback(func() -> void: fade.queue_free())
	var _el_ready := Time.get_ticks_usec() - _t_ready
	if _el_ready > 50000:
		print("[SLOW] battle_ui ready ", _el_ready / 1000.0, " ms")
	set_process(true)

# 上一关首通留下的“预习”：下一关开局生效一次
func _apply_level_preview() -> void:
	var pv := LevelState.take_preview(LevelState.current_level)
	if pv.is_empty():
		return
	if pv.has("crystal"):
		_crystal += int(pv["crystal"])
	if pv.has("wen"):
		_wen += int(pv["wen"])
	if pv.has("god"):
		_draw_charge += int(pv["god"])
	if pv.has("exp_pct"):
		_exp_pct += float(pv["exp_pct"])   # 第四关预习：下一关经验加成
	if pv.has("chal"):
		for i in _chal_cd.size():
			_chal_cd[i] = 0.0
	_update_crystal()
	if _coin_lb != null:
		_coin_lb.text = str(_wen)
	_refresh_level_ui()


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
			Vector2(0, 870), Vector2(90, 730), Vector2(170, 830), Vector2(260, 700),
			Vector2(360, 840), Vector2(470, 710), Vector2(580, 830), Vector2(700, 740),
			Vector2(720, 870)
		]
		draw_polyline(PackedVector2Array(pts), Color(0.52, 0.46, 0.38, 0.30), 2.0, true)
		draw_line(Vector2(0, 870), Vector2(720, 870), Color(0.38, 0.32, 0.24, 0.55), 2.0)
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
		elif kind == "heart":
			# 红心（当局生命）：参数方程描点，圆心落在图标中心
			var hp := PackedVector2Array()
			for i in 40:
				var t := TAU * float(i) / 40.0
				var hx := 16.0 * pow(sin(t), 3.0)
				var hy := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				hp.append(c + Vector2(hx, -hy) * (r / 17.0))
			draw_colored_polygon(hp, Color(0.80, 0.24, 0.20))
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
	var progress := 0          # 该卡所属组合的当前进度（由外壳写入）
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
			draw_string(F, Vector2(20, 246), str(data.get("combo_name", "")) + " " + str(progress) + "/" + str(data.get("set_size", 0)), HORIZONTAL_ALIGNMENT_LEFT, 140, 18, Color(0.42,0.30,0.12))
			draw_string(F, Vector2(20, 280), str(data.get("trigger", "")) + "：" + str(data.get("combo_text", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 17, Color(0.2,0.16,0.12))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()


func _build_bg() -> void:
	var bg := BgArt.new()
	bg.size = Vector2(W, H)
	add_child(bg)

func _chip(x: float, kind: String, value: String, cap: String) -> Label:
	var box := Control.new()
	box.size = Vector2(720, 80)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	# 可视区块单独一个 Control（162×64），教学高亮框只框这一块，不会拉满整行
	var chip := Control.new()
	chip.position = Vector2(x, 8)
	chip.size = Vector2(162, 64)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(chip)
	_panel(Rect2(0, 0, 162, 64), Color(0.075, 0.068, 0.060, 0.98), 8, Color(0.85, 0.66, 0.23, 0.45), 1, chip)
	var ic := Ico.new()
	ic.kind = kind
	ic.position = Vector2(10, 14)
	ic.size = Vector2(34, 34)
	chip.add_child(ic)
	var vl := _lbl(value, Vector2(48, -4), Vector2(106, 36), 26, Color(0.95, 0.91, 0.83), chip, HORIZONTAL_ALIGNMENT_RIGHT)
	_lbl(cap, Vector2(48, 32), Vector2(106, 20), 16, Color(0.80, 0.75, 0.65), chip, HORIZONTAL_ALIGNMENT_RIGHT)
	# 点灵晶/文钱给说明（灵晶不足时直接提示无法抽卡）
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var hb := Button.new()
	hb.flat = true
	hb.focus_mode = Control.FOCUS_NONE
	hb.position = Vector2.ZERO
	hb.size = Vector2(162, 64)
	hb.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hb.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hb.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hb.pressed.connect(func() -> void: _on_chip_click(cap))
	chip.add_child(hb)
	_chips[cap] = chip
	return vl

func _on_chip_click(cap: String) -> void:
	match cap:
		"灵晶":
			if _crystal < 20:
				_toast("灵晶不足，不足以抽卡（一次要 20）")
			else:
				_toast("灵晶 %d · 抽卡一次 20" % _crystal)
		"文钱":
			var cost := _str_cost()
			if _wen < cost:
				_toast("文钱不足，无法强化（需要 %d）" % cost)
			else:
				_toast("文钱 %d · 强化一次 %d" % [_wen, cost])

func _build_hud() -> void:
	_coin_lb = _chip(18, "coin", "0", "文钱")
	_crystal_lb = _chip(192, "crystal", "100", "灵晶")
	_chips["灵晶"].visible = LevelState.show_button("crystal")
	_kill_lb = _chip(366, "kill", "0", "杀敌")
	_life_lb = _chip(540, "heart", "100", "命")
	_wave_lb = _lbl("波 1/%d" % _max_wave, Vector2(22, 92), Vector2(100, 48), 26, INK)
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
	var _boss_timer_lb := _lbl("", Vector2(450, 96), Vector2(120, 30), 17, SEAL)
	_boss_timer_lb.visible = false   # 原来写死的“首领 00:37”是假的，改成首领真的出现时才显示
	_tot_btn = _btn("总计", Rect2(570, 88, 68, 42), 17, Color(0.10, 0.09, 0.08, 0.98), LIGHT, func(): _show_totals())
	_btn("退出", Rect2(646, 88, 60, 42), 17, Color(0.10, 0.09, 0.08, 0.98), LIGHT, func(): _show_exit(true))

# ---------------- 战场 ----------------
# 镜头容器：战场内容都挂在它下面，做推进（zoom）时整体一起缩放
var _cam: Control = null
func _build_field() -> void:
	_cam = Control.new()
	_cam.size = Vector2(720, 1280)
	_cam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cam.pivot_offset = Vector2(360, 510)   # 以战场中心为缩放中心
	add_child(_cam)
	_core = BattleCore.new()
	_core.position = Vector2(8, 150)
	_core.size = Vector2(704, 720)
	_core.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 战斗没有手动：点击穿透
	_core.modulate = Color(1, 1, 1, 0.25)
	_cam.add_child(_core)
	_core.setup({"atk": 12.0, "hp_max": 200.0, "mp_max": 100.0})
	if LevelState.has_feature("equip"):
		var ForgeData := preload("res://shared/forge_data.gd")
		ForgeData.load_game()
		EquipmentStats.apply(_core, ForgeData.totals())
	_core.set_wave(1)
	_core.coin.connect(_on_core_coin)
	_core.coin_drop.connect(_on_coin_drop)   # v6：钱怪/匪首掉的真钱
	_core.kill.connect(_on_core_kill)
	_core.chal_drop.connect(_on_chal_drop)
	_core.guard_broken.connect(func() -> void: _q_fail_kind("guard"))
	_core.champion_down.connect(func() -> void: _q_done_kind("champion"))
	_core.hero_attack.connect(_on_hero_attack)
	_core.hero_hit.connect(_on_hero_hit)
	_core.hero_damaged.connect(_curio_on_hero_hurt)
	_core.hero_foe_hit.connect(_on_hero_foe_hit)
	_core.hero_down.connect(_on_hero_down)
	_core.boss_arrived.connect(_on_boss_arrived)
	_core.delayed_land.connect(_on_delayed_land)
	_core.boss_died.connect(_on_boss_died)
	_core.boss_slain.connect(_curio_on_boss_slain)
	_core.wood_expired.connect(_curio_on_wood_expired)
	_core.cold_expired.connect(_curio_on_cold_expired)
	_core.paper_blocked.connect(_on_paper_blocked)
	# 教学关每波少刷几只，节奏更快（奖励不变）
	if LevelState.current_level <= 5:
		_core.wave_extra = -8       # 前五关：大幅减量，快速推进
	elif LevelState.current_level <= 10:
		_core.wave_extra = -4
	_core.start_run()
	_hero_token = TokenActor.new()
	_hero_token.setup(PLAYER_TEX, 44.0, Color(0.85, 0.66, 0.23), true)
	_hero_token.set_role("player")
	_hero_token.set_weapon("sword")
	_hero_token.show_bar = false          # 主角血条只看顶部 HUD，不再挂漂浮血条
	_hero_token.bar_w = 0.0
	_hero_token.unit_name = ""
	_hero_token.position = _core.position + _core.hero_pos
	_hero_token.z_index = 6
	_cam.add_child(_hero_token)
	var hit := Button.new()
	hit.position = Vector2(312, 710)
	hit.size = Vector2(96, 96)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hit.pressed.connect(func(): _open_attr_page())
	_cam.add_child(hit)
	_hero_hit_btn = hit
	_hero_hit_btn.position = _hero_token.position - Vector2(48, 48)
	# 挑战方形
	_chal_btn = _btn("挑战", Rect2(0, 760, 96, 96), 20, Color(0.075, 0.068, 0.060, 0.98), Color(0.91, 0.78, 0.42), func(): _toggle_challenge())
	_chal_btn.visible = LevelState.show_button("challenge")
	_build_challenge()
	_build_curio()
	# pixelfx 特效层：盖在战场和角色之上、UI 之下
	# 首领登场演出三件套（平时隐藏）
	_boss_veil = ColorRect.new()
	_boss_veil.color = Color(0.08, 0.06, 0.05, 0.0)
	_boss_veil.position = Vector2(0, 150)
	_boss_veil.size = Vector2(720, 720)
	_boss_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_veil.z_index = 14
	_boss_veil.visible = false
	add_child(_boss_veil)
	_boss_spot = Sprite2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.92, 0.74, 0.75))
	g.set_color(1, Color(1.0, 0.85, 0.6, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 512
	gt.height = 512
	_boss_spot.texture = gt
	_boss_spot.z_index = 15
	_boss_spot.visible = false
	add_child(_boss_spot)
	_boss_name_lb = Label.new()
	_boss_name_lb.size = Vector2(720, 70)
	_boss_name_lb.position = Vector2(0, 468)
	_boss_name_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_name_lb.add_theme_font_override("font", FONT)
	_boss_name_lb.add_theme_font_size_override("font_size", 44)
	_boss_name_lb.add_theme_color_override("font_color", Color(0.42, 0.12, 0.08))
	_boss_name_lb.add_theme_color_override("font_outline_color", Color(0.99, 0.94, 0.84, 0.95))
	_boss_name_lb.add_theme_constant_override("outline_size", 8)
	_boss_name_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name_lb.z_index = 16
	_boss_name_lb.visible = false
	add_child(_boss_name_lb)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1.0, 0.96, 0.85, 0.0)
	_flash_rect.position = Vector2(0, 150)
	_flash_rect.size = Vector2(720, 720)   # 只闪战场，不染 HUD
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.z_index = 20
	add_child(_flash_rect)
	_boss_bar = BossBar.new()
	_boss_bar.position = Vector2(110, 192)
	_boss_bar.size = Vector2(500, 22)
	_boss_bar.visible = false
	_boss_bar.z_index = 6
	add_child(_boss_bar)
	_fly_layer = FlyLayer.new()
	_fly_layer.size = Vector2(720, 1280)
	_fly_layer.z_index = 9
	add_child(_fly_layer)
	_fly = _fly_layer.dots
	_build_card_detail()
	# v3 技能栏（右缘竖排，6 格可视）
	_build_skill_bar()
	# 攻击表现层：后层在牌下面（剑/弧被牌挡住），前层在牌上面（白边/淡红/数字）
	_fx_back = AttackFx.new()
	_fx_back.front = false
	_fx_back.position = FIELD_POS
	_fx_back.size = Vector2(704, 720)
	_fx_back.z_index = 4
	_fx_back.clip_contents = true
	add_child(_fx_back)
	_fx_front = AttackFx.new()
	_fx_front.front = true
	_fx_front.position = FIELD_POS
	_fx_front.size = Vector2(704, 720)
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
	if not LevelState.show_button("challenge"):
		return
	_chal_layer.visible = not _chal_layer.visible
	if _chal_layer.visible:
		_refresh_chal_panel()
		_chal_layer.move_to_front()
		if _chal_holder != null:
			_pop_bounce(_chal_holder)
			_breathe(_chal_holder)

# ============================================================
# 挑战：冷却制 + 按波解锁，打完给资源
# ============================================================
const CHAL_NAMES := ["钱怪", "晶怪", "书怪", "宝箱", "匪首"]
const CHAL_GROUP := [6, 3, 4, 1, 1]

var _chal_btns: Array = []
var _chal_auto_btn: Button = null
var _chal_holder: Control = null
var _auto_chal := false
var _chal_t := 0.0
var _chal_count := 0

func _build_challenge() -> void:
	_chal_layer = Control.new()
	_chal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chal_layer.visible = false
	_chal_layer.z_index = 15
	add_child(_chal_layer)
	_chal_holder = Control.new()
	_chal_holder.position = Vector2(8, 360)
	_chal_holder.size = Vector2(320, 340)
	_chal_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chal_layer.add_child(_chal_holder)
	_panel(Rect2(0, 0, 320, 340), Color(0.94, 0.90, 0.82, 0.98), 8, Color(0.85, 0.66, 0.23, 0.6), 2, _chal_holder)
	for i in CHAL_NAMES.size():
		var x := 16.0 + float(i % 2) * 148.0
		var y := 16.0 + float(i / 2) * 84.0
		var idx := i
		var b := _btn(str(CHAL_NAMES[i]), Rect2(x, y, 132, 72), 17, Color(0.09, 0.08, 0.07, 0.98),
			Color(0.91, 0.78, 0.42), func() -> void: _chal_press(idx), _chal_holder)
		_chal_btns.append(b)
	_chal_auto_btn = _btn("自动挑战：关", Rect2(16, 276, 288, 48), 18, Color(0.13, 0.11, 0.09),
		Color(0.91, 0.78, 0.42), func() -> void: _toggle_auto_chal(), _chal_holder)

func _toggle_auto_chal() -> void:
	_auto_chal = not _auto_chal
	if _chal_auto_btn != null:
		_chal_auto_btn.text = "自动挑战：" + ("开" if _auto_chal else "关")
	_refresh_chal_panel()

func _chal_unlocked(i: int) -> bool:
	if _core == null:
		return false
	return int(_core.wave) >= int(CHAL_MIN_WAVE[clampi(i, 0, CHAL_MIN_WAVE.size() - 1)])

func _chal_press(i: int) -> void:
	if _run_over or _core == null:
		return
	if not _chal_unlocked(i):
		_toast("「%s」第 %d 波才解锁" % [str(CHAL_NAMES[i]), int(CHAL_MIN_WAVE[i])])
		return
	if float(_chal_cd[i]) > 0.0:
		_toast("「%s」冷却中 %.0f 秒" % [str(CHAL_NAMES[i]), ceil(float(_chal_cd[i]))])
		return
	_chal_cd[i] = _chal_base_cd(i)
	_chal_count += 1
	_qc("chal", 1)
	var grp := int(CHAL_GROUP[i])
	_core.spawn_challenge(i, grp)
	# 挑战开打：战场上方一口落地冲击 + 鼓，给"应战"的分量
	_spawn_pfx("impacts/ground-slam", Vector2(360, 235), 0.95, "shadow", 1.5)
	Aud.sfx("drum", -12.0, 1.10)
	_toast("挑战 · " + str(CHAL_NAMES[i]))
	Aud.sfx("ui_open", -8.0)
	_refresh_chal_panel()

func _refresh_chal_panel() -> void:
	for i in _chal_btns.size():
		var b: Button = _chal_btns[i]
		if b == null:
			continue
		var cd := float(_chal_cd[i])
		if not _chal_unlocked(i):
			b.text = "%s\n第 %d 波解锁" % [str(CHAL_NAMES[i]), int(CHAL_MIN_WAVE[i])]
			b.disabled = true
		elif cd > 0.0:
			b.text = "%s\n%.0f 秒" % [str(CHAL_NAMES[i]), ceil(cd)]
			b.disabled = true
		else:
			b.text = "%s\n×%d" % [str(CHAL_NAMES[i]), int(CHAL_GROUP[i])]
			b.disabled = false
		b.add_theme_font_size_override("font_size", 17)

func _chal_auto_try() -> void:
	if not _auto_chal or _run_over or _core == null:
		return
	for i in _chal_btns.size():
		if _chal_unlocked(i) and float(_chal_cd[i]) <= 0.0:
			_chal_press(i)
			return

func _tick_chal(dt: float) -> void:
	for i in _chal_cd.size():
		if float(_chal_cd[i]) > 0.0:
			_chal_cd[i] = maxf(0.0, float(_chal_cd[i]) - dt)
	_chal_t += dt
	if _chal_t < 0.5:
		return
	_chal_t = 0.0
	if _chal_layer != null and _chal_layer.visible:
		_refresh_chal_panel()
	_chal_auto_try()

# 挑战怪死亡：按类型结算（钱怪走 coin_drop，这里不重复给）
func _on_chal_drop(kind: int, _pos: Vector2) -> void:
	if _core == null:
		return
	match kind:
		1:
			_gain_crystal(int(float(4 + randi() % 4) * _core.chal_crystal_mul()))
		2:
			_add_exp(80)                      # 书怪：额外经验，快速练级
		3:
			_trea_charge += 1
			_trea_reroll += 1
			if randf() < float(_treasure_pct) / 100.0:
				_trea_reroll += 1
			_refresh_trea_tile()
			_toast("宝箱 · 宝物机会 +1 · 刷新 +1")
		4:
			_add_wen(int(220.0 * _core.chal_money_mul() * (1.0 + _boss_pct / 100.0)))
			_gain_crystal(int(round(30.0 * _core.chal_crystal_mul() * (1.0 + _boss_pct / 100.0))))
			_trea_charge += 1
			_trea_reroll += 1
			_aug_reroll += 1
			_refresh_trea_tile()
			_toast("匪首 · 文钱/灵晶 + 宝物机会 + 刷新")

# ============================================================
# 奇物（局外一件 · 局内全自动，不用玩家点）
#   首件 玲珑玉壶：气血低于 30% 立刻喝；低于 50% 且身边有敌也喝
#   回气血 25% / 内力 25%，冷却 60 秒
# ============================================================
# ---------------- 奇物（单槽 · 全自动） ----------------
const CurioData := preload("res://shared/curio_data.gd")
const GameState := preload("res://shared/game_state.gd")

var _curio_id := ""
var _curio_lv := 1
var _curio_atk_t := 0.0        # 血葫芦：剩余持续
var _curio_atk_add := 0.0      # 血葫芦：攻击加成
var _curio_extend_used := 0.0  # 本次增益已延长的总秒数，不随倒计时回退
var _curio_extra_used := false # 玉壶 Lv5：濒死额外一次
var _curio_kills := 0
var _curio_waves := 0           # 实际成功清波次数，不包含战败跳过的波
var _rewarded_waves := {}       # 防止清波回调重复结算
var _tie_stacks := 0           # 铁布衫：硬气层数
var _tie_idle := 0.0           # 铁布衫：多久没挨打
var _zhiren := 0               # 纸人替身：剩余数量
var _draw_free := 0            # 万应符：免费抽卡刷新次数
var _wanying_add := 0          # 万应符：每种刷新 +N
var _yuhu_shield := 0.0        # 玉壶 Lv3：喝完后减伤剩余秒数
var _dart_n := 0               # 铜钱剑：普攻计数（Lv3 每 3 次多一枚）

func _curio_init_data() -> void:
	_curio_id = GameState.curio_id
	if _curio_id != "" and CurioData.get_curio(_curio_id).is_empty():
		_curio_id = ""
	_curio_lv = GameState.curio_level(_curio_id) if _curio_id != "" else 1

func _foe_near(pos: Vector2, r: float) -> bool:
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0:
			continue
		if pos.distance_to(Vector2(float(f.get("x", 0.0)), float(f.get("y", 0.0)))) <= r:
			return true
	return false

func _build_curio() -> void:
	_curio_init_data()
	var info := CurioData.get_curio(_curio_id)
	_curio_sq = CurioSquare.new()
	_curio_sq.position = Vector2(624, 760)
	_curio_sq.size = Vector2(96, 96)
	_curio_sq.glyph = str(info.get("glyph", "奇")) if not info.is_empty() else "奇"
	_curio_sq.label = "奇物"
	_curio_sq.cd_max = maxf(1.0, float(info.get("cd", 1.0)))
	_curio_sq.pressed.connect(_show_curio_detail)
	add_child(_curio_sq)
	_curio_apply_static()

func _curio_flash() -> void:
	if _curio_sq != null:
		_curio_sq.flash = 1.0
		_curio_sq.queue_redraw()

# 每帧：冷却 + 持续 buff + 各奇物的自动触发
func _tick_curio(dt: float) -> void:
	if _curio_sq == null:
		return
	if _curio_cd > 0.0:
		_curio_cd = maxf(0.0, _curio_cd - dt)
		_curio_sq.cd_left = _curio_cd
		_curio_sq.queue_redraw()
	if _curio_sq.flash > 0.0:
		_curio_sq.flash = maxf(0.0, _curio_sq.flash - dt * 2.2)
		_curio_sq.queue_redraw()
	if _run_over or _core == null or _curio_id == "":
		return
	if _curio_atk_t > 0.0:
		_curio_atk_t = maxf(0.0, _curio_atk_t - dt)
		if _curio_atk_t <= 0.0:
			_curio_atk_add = 0.0
			_core.hero["curio_aspd"] = 0.0
			_core.hero["curio_crit"] = 0.0
	_core.hero["curio_atk"] = _curio_atk_add if _curio_atk_t > 0.0 else 0.0
	match _curio_id:
		"yuhu":
			_curio_tick_yuhu(dt)
		"xuehulu":
			_curio_tick_xuehulu()
		"jingtangmu":
			_curio_tick_jingtangmu()
		"zuiweng":
			_curio_tick_zuiweng(dt)
		"tiebushan":
			_curio_tick_tiebushan(dt)
		"zhaohunfan":
			_curio_tick_zhaohunfan()
		"tongjing":
			_curio_tick_tongjing()
		"zhiren":
			_curio_tick_zhiren()

func _curio_tick_yuhu(dt: float) -> void:
	if _yuhu_shield > 0.0:
		_yuhu_shield = maxf(0.0, _yuhu_shield - dt)
		if _yuhu_shield <= 0.0 and _core != null:
			_core.hero["curio_cut"] = 0.0
	var h: Dictionary = _core.hero
	var mx := maxf(1.0, float(h.get("hp_max", 1.0)))
	var hpr := float(h.get("hp", 0.0)) / mx
	if hpr <= 0.0:
		return
	if _curio_lv >= 5 and not _curio_extra_used and hpr < 0.15:
		_curio_extra_used = true
		_curio_use(true)
		return
	if _curio_cd > 0.0:
		return
	if hpr <= 0.30 or (hpr <= 0.50 and _foe_near(_core.hero_pos, 220.0)):
		_curio_use()

func _curio_use(extra := false) -> void:
	var h: Dictionary = _core.hero
	var mx := float(h.get("hp_max", 1.0))
	var pct := 0.30 if _curio_lv >= 2 else 0.25
	var cd := 45.0 if _curio_lv >= 4 else 60.0
	var hp_add := mx * pct
	h["hp"] = minf(mx, float(h.get("hp", 0.0)) + hp_add)
	var mp_add := _mp_max * pct
	_mp = minf(_mp_max, _mp + mp_add)
	if not extra:
		_curio_cd = cd
	if _curio_sq != null:
		_curio_sq.cd_max = cd
	if _curio_lv >= 3:
		_yuhu_shield = 4.0
		_core.hero["curio_cut"] = 0.20
	_curio_uses += 1
	_curio_flash()
	_toast("玉壶 · 气血 +%d · 内力 +%d" % [int(hp_add), int(mp_add)])
	Aud.sfx("drink", -10.0, 1.05)
	_spawn_pfx("holy/heal", _hero_screen(), 0.85, "heal", 1.5)

func _curio_tick_xuehulu() -> void:
	if _curio_cd > 0.0:
		return
	var h: Dictionary = _core.hero
	var mx := maxf(1.0, float(h.get("hp_max", 1.0)))
	var hpr := float(h.get("hp", 0.0)) / mx
	if hpr > 0.70 or not _foe_near(_core.hero_pos, 300.0):
		return
	var cost := float(h.get("hp", 0.0)) * 0.10
	if _curio_lv >= 5:
		cost = (mx - float(h.get("hp", 0.0))) * 0.10
	h["hp"] = maxf(1.0, float(h.get("hp", 1.0)) - cost)
	_curio_atk_add = 0.80 if _curio_lv >= 4 else 0.60
	_curio_atk_t = 11.0 if _curio_lv >= 2 else 8.0
	_curio_extend_used = 0.0
	_curio_cd = 45.0
	_curio_uses += 1
	_curio_flash()
	_toast("血葫芦 · 攻击 +%d%%" % int(_curio_atk_add * 100.0))
	Aud.sfx("drum", -9.0, 0.9)
	_spawn_pfx("impacts/crit-hit", _hero_screen(), 0.9, "", 1.5)

func _curio_tick_jingtangmu() -> void:
	if _curio_cd > 0.0:
		return
	var live: Array = _live_foes()
	if live.size() < 2:
		return
	var dur := 2.5 if _curio_lv >= 2 else 2.0
	var targets := 2 if _curio_lv >= 4 else 1
	# _live_foes已有距离排序；读条目标优先，同组仍按距离选。
	var ordered: Array = []
	for casting in [true, false]:
		for foe in live:
			if not bool(foe.get("boss", false)) and _core.has_pending_cast(foe) == casting:
				ordered.append(foe)
	var n := 0
	for f_v in ordered:
		if n >= targets:
			break
		var f: Dictionary = f_v
		if bool(f.get("boss", false)):
			continue
		f["para"] = maxf(float(f.get("para", 0.0)), dur)
		f["t"] = 0.0
		f["wood_t"] = dur
		f["wood_vuln"] = 0.30 if _curio_lv >= 3 else 0.0
		f["wood_boom"] = _curio_lv >= 5
		_core.interrupt_cast(f)
		n += 1
		_spawn_pfx("impacts/ground-slam", _core.position + Vector2(float(f["x"]), float(f["y"]) - 20.0), 0.6, "", 1.2)
	if n <= 0:
		return
	_curio_cd = 35.0
	_curio_uses += 1
	_curio_flash()
	Aud.sfx("wood_down", -8.0, 0.9)
	_toast("惊堂木 · 定身 %d 只" % n)

func _curio_on_wood_expired(foe: Dictionary) -> void:
	var boom := bool(foe.get("wood_boom", false))
	foe.erase("wood_vuln")
	foe.erase("wood_boom")
	if _run_over or not boom or float(foe.get("hp", 0.0)) <= 0.0 or float(foe.get("dying", 0.0)) > 0.0:
		return
	_core._apply_dmg(foe, float(_core.hero.get("atk", 12.0)) * 0.8, "物理")
	_spawn_pfx("impacts/ground-slam", _core.position + Vector2(float(foe["x"]), float(foe["y"])), 0.8, "", 1.2)
	if float(foe.get("hp", 0.0)) <= 0.0:
		_core._kill_foe(foe)

# 铜钱剑：每次普攻附带一枚钱镖（打到更远的怪）
func _curio_on_attack() -> void:
	if _run_over or _curio_id != "tongqianjian" or _core == null:
		return
	_dart_n += 1
	var shots := 1
	if _curio_lv >= 3 and _dart_n % 3 == 0:
		shots = 2
	var reach: float = _core.HERO_REACH + (200.0 if _curio_lv >= 4 else 120.0)
	var fired := false
	for _shot in shots:
		var best: Dictionary = {}
		var bd := 1e9
		for f_v in _core.foes:
			var f: Dictionary = f_v
			if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
				continue
			var d: float = _core.hero_pos.distance_to(Vector2(float(f["x"]), float(f["y"])))
			if d > reach:
				continue
			if d < bd:
				bd = d
				best = f
		if best.is_empty():
			break
		if not fired:
			_curio_uses += 1
			_curio_flash()
			fired = true
		var targets: Array = [best]
		var origin: Vector2 = _core.hero_pos
		var first := Vector2(float(best["x"]), float(best["y"]))
		var dir := (first - origin).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		if _curio_lv >= 5:
			var next: Dictionary = {}
			var nearest := INF
			for foe in _core.foes:
				if is_same(foe, best) or float(foe.get("hp", 0.0)) <= 0.0 or float(foe.get("dying", 0.0)) > 0.0:
					continue
				var rel := Vector2(float(foe["x"]), float(foe["y"])) - origin
				var along := rel.dot(dir)
				# 20px半宽沿用普通怪牌半径；仅选择第一目标后方同一路径。
				if along < bd or rel.length() > reach or absf(rel.cross(dir)) > 20.0:
					continue
				if along < nearest:
					nearest = along
					next = foe
			if not next.is_empty():
				targets.append(next)
		for i in range(targets.size()):
			var target: Dictionary = targets[i]
			if float(target.get("hp", 0.0)) <= 0.0 or float(target.get("dying", 0.0)) > 0.0:
				continue
			var mul := (0.45 if _curio_lv >= 2 else 0.35) * (0.5 if i > 0 else 1.0)
			_core._apply_dmg(target, float(_core.hero.get("atk", 12.0)) * mul, "物理")
			_spawn_pfx("impacts/crit-hit", _core.position + Vector2(float(target["x"]), float(target["y"]) - 16.0), 0.5, "gold", 1.9)
			if float(target.get("hp", 0.0)) <= 0.0:
				_core._kill_foe(target)
		var last: Dictionary = targets.back()
		_curio_dart_trace(origin, Vector2(float(last["x"]), float(last["y"])))
		Aud.sfx("dart", -14.0, 1.1)

func _curio_dart_trace(origin: Vector2, target: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([_core.position + origin, _core.position + target])
	line.width = 2.0
	line.default_color = Color(0.92, 0.72, 0.30)
	line.z_index = 7
	(_cam if _cam != null else self).add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.12)
	tween.tween_callback(line.queue_free)

# 规则类：进局时一次性应用（刷新次数 / 技能冷却）
func _curio_apply_static() -> void:
	if _curio_id == "wanyingfu":
		var add := 1
		if _curio_lv >= 2:
			add = 2
		if _curio_lv >= 4:
			add = 3
		if _curio_lv >= 5:
			add = 0 # 五级选免耗模式，不叠加次数赠送。
		_wanying_add = add
		_trea_reroll += add
		_aug_reroll += add
		_god_reroll += add
		_draw_free += add
		_refresh_draw_btn()
	elif _curio_id == "zhiren":
		_set_paper_count(0)

# 万应符 Lv5：25% 概率这次刷新不消耗次数
func _rr_free() -> bool:
	return _curio_id == "wanyingfu" and _curio_lv >= 5 and _roll_refresh_keep()

func _roll_refresh_keep() -> bool:
	return randf() < 0.25

func _roll_wanying_refresh() -> int:
	return randi() % 4

# 定风珠：技能冷却缩减
func _curio_skill_cd_mul() -> float:
	if _curio_id != "dingfengzhu":
		return 1.0
	if _curio_lv >= 4:
		return 0.75
	if _curio_lv >= 2:
		return 0.80
	return 0.85

# 镇魂铃：奇遇刷新间隔
func _q_interval() -> float:
	var base := Q_TICK
	if _curio_id == "zhenhunling":
		if _curio_lv >= 4:
			base = Q_TICK / 1.40
		elif _curio_lv >= 1:
			base = Q_TICK / 1.25
	return base

# ---------------- 召唤类奇物 ----------------
func _curio_summon(tag: String, nm: String, col: Color, life: float, dmg_pct: float, boom: float, lc := 0.0) -> void:
	if _run_over or _core == null:
		return
	var idx := _curio_count_minions(tag)
	var follow_offset := Vector2(-60.0 + float(idx % 3) * 60.0, 20.0)
	var pos: Vector2 = _core.hero_pos + follow_offset
	var tk = TokenActor.new()
	tk.setup(null, 20.0, col, false)
	tk.show_bar = true
	tk.bar_w = 44.0
	tk.unit_name = nm
	tk.z_index = 5
	tk.position = _core.position + pos
	if _cam != null:
		_cam.add_child(tk)
	else:
		add_child(tk)
	# 召唤物图标（没有立绘，用一个字标出身份）
	var mk := Label.new()
	mk.text = nm.substr(0, 1)
	mk.position = Vector2(-22, -44)
	mk.size = Vector2(44, 44)
	mk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mk.add_theme_font_override("font", FONT)
	mk.add_theme_font_size_override("font_size", 24)
	mk.add_theme_color_override("font_color", col.darkened(0.25))
	mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tk.add_child(mk)
	var atk := float(_core.hero.get("atk", 12.0))
	_minions.append({"pos": pos, "life": life, "max_life": life, "atk_cd": 0.5, "wave_cd": 999.0,
		"dmg": atk * dmg_pct, "wave_dmg": 0.0, "tk": tk, "curio": tag, "boom": boom, "lc": lc, "copy_ratio": dmg_pct, "follow_offset": follow_offset})

func _curio_count_minions(tag: String) -> int:
	var n := 0
	for m_v in _minions:
		if str((m_v as Dictionary).get("curio", "")) == tag and float(m_v.get("life", 0.0)) > 0.0:
			n += 1
	return n

func _curio_mirror_hit(target: Dictionary, damage: float) -> void:
	if _run_over or _core == null or damage <= 0.0:
		return
	for mirror in _minions:
		if str(mirror.get("curio", "")) != "tongjing" or float(mirror.get("life", 0.0)) <= 0.0:
			continue
		var dealt: float = _core.apply_echo_damage(target, damage * float(mirror.get("copy_ratio", 0.5)))
		if dealt > 0.0:
			_core._push_float(float(target["x"]), float(target["y"]) - 45.0, "镜 " + str(int(dealt)), Color(0.72, 0.70, 0.90))
			if float(_core.hero.get("hp", 0.0)) > 0.0:
				_core.hero["hp"] = minf(float(_core.hero["hp_max"]), float(_core.hero["hp"]) + dealt * float(mirror.get("lc", 0.0)))

func _curio_tick_zhiren() -> void:
	if _core == null:
		return
	# Lv5：纸人也能挡首领延迟技（核心读到这个数就会消耗）
	_core.hero["paper_guard"] = _zhiren if _curio_lv >= 5 else 0

func _set_paper_count(amount: int) -> void:
	_zhiren = clampi(amount, 0, 3 if _curio_lv >= 2 else 2)
	if _core != null:
		_core.hero["paper_guard"] = _zhiren if _curio_id == "zhiren" and _curio_lv >= 5 else 0

func _paper_shatter() -> void:
	if _curio_lv < 3 or _core == null:
		return
	for foe in _core.foes.duplicate():
		if float(foe.get("hp", 0.0)) <= 0.0 or float(foe.get("dying", 0.0)) > 0.0:
			continue
		if _core.hero_pos.distance_to(Vector2(float(foe["x"]), float(foe["y"]))) > 140.0:
			continue
		_core._apply_dmg(foe, float(_core.hero.get("atk", 12.0)), "物理")
		if float(foe.get("hp", 0.0)) <= 0.0:
			_core._kill_foe(foe)
		elif not bool(foe.get("boss", false)):
			foe["kb"] = maxf(float(foe.get("kb", 0.0)), 120.0)

func _curio_tick_zhaohunfan() -> void:
	if _run_over or _curio_cd > 0.0 or _core == null:
		return
	if _live_foes().is_empty():
		return
	var cap := 2 if _curio_lv >= 3 else 1
	if _curio_count_minions("zhaohunfan") >= cap:
		return
	_curio_summon("zhaohunfan", "鬼影", Color(0.55, 0.45, 0.85),
		10.0 if _curio_lv >= 2 else 8.0,
		0.35 if _curio_lv >= 4 else 0.25,
		0.80 if _curio_lv >= 5 else 0.0)
	_curio_cd = 25.0
	_curio_uses += 1
	_curio_flash()
	_toast("招魂幡 · 鬼影现形")
	Aud.sfx("enlighten", -10.0, 0.9)

func _curio_tick_tongjing() -> void:
	if _curio_cd > 0.0 or _core == null:
		return
	if _live_foes().is_empty():
		return
	if _curio_count_minions("tongjing") > 0:
		return
	_curio_summon("tongjing", "镜影", Color(0.72, 0.70, 0.78),
		7.0 if _curio_lv >= 2 else 5.0,
		0.70 if _curio_lv >= 4 else 0.50,
		0.0, 0.10 if _curio_lv >= 3 else 0.0)
	if _curio_lv >= 5:
		var mirror: Dictionary = _minions.back()
		mirror["decoy"] = _core.add_mirror_decoy(mirror["pos"])
	_curio_cd = 20.0
	_curio_uses += 1
	_curio_flash()
	_toast("铜镜 · 镜影离体")
	Aud.sfx("bell", -12.0, 1.2)

# 醉翁壶：击杀累计（每 10 只进入醉）
func _curio_on_kill(n: int) -> void:
	if _core == null or n <= 0:
		return
	if _curio_id == "xuehulu" and _curio_lv >= 3 and _curio_atk_t > 0.0:
		_curio_extend_buff(0.6 * n, 4.0)
	if _curio_id != "zuiweng":
		return
	_curio_kills += n
	while _curio_kills >= 10:
		_curio_kills -= 10
		_curio_zui_start()

func _curio_zui_start() -> void:
	_curio_atk_add = 0.45 if _curio_lv >= 4 else 0.30
	_curio_atk_t = 10.0 if _curio_lv >= 2 else 8.0
	_curio_extend_used = 0.0
	_core.hero["curio_aspd"] = 0.10
	if _curio_lv >= 3:
		_core.hero["curio_crit"] = 0.10
	_curio_uses += 1
	_curio_flash()
	_toast("醉翁壶 · 醉意上涌")
	Aud.sfx("drink", -10.0, 0.95)
	_spawn_pfx("impacts/crit-hit", _hero_screen(), 0.8, "", 1.4)

# 醉翁壶：这里只管 buff 到期清空
func _curio_tick_zuiweng(_dt: float) -> void:
	pass

# 铁布衫：5 秒不挨打清空层数
func _curio_tick_tiebushan(dt: float) -> void:
	if _tie_stacks <= 0:
		return
	_tie_idle += dt
	if _tie_idle >= 5.0:
		_tie_stacks = 0
		_core.hero["curio_cut"] = 0.0
		_core.hero["curio_control_immune"] = false

# 铁布衫：受击叠层 + 满层反弹
func _curio_on_hero_hurt(amount: float, attacker: Dictionary) -> void:
	if _run_over or amount <= 0.0 or _curio_id != "tiebushan" or _core == null:
		return
	var cap := 8 if _curio_lv >= 2 else 5
	_tie_stacks = mini(cap, _tie_stacks + 1)
	_tie_idle = 0.0
	var per := 0.03 if _curio_lv >= 4 else 0.02
	_core.hero["curio_cut"] = float(_tie_stacks) * per
	_core.hero["curio_control_immune"] = _curio_lv >= 5 and _tie_stacks >= cap
	if _curio_lv >= 3 and _tie_stacks >= cap:
		_core.reflect_damage(attacker, amount * 0.30)

# 寒玉扳指：暴击叠寒、3 层冻结；醉翁壶 Lv5：暴击延长醉
func _curio_extend_buff(seconds: float, cap: float) -> void:
	var added := minf(seconds, maxf(0.0, cap - _curio_extend_used))
	_curio_extend_used += added
	_curio_atk_t += added

func _curio_on_crit(tgt: Dictionary) -> void:
	if _core == null:
		return
	if _curio_id == "zuiweng" and _curio_lv >= 5 and _curio_atk_t > 0.0:
		_curio_extend_buff(1.0, 5.0)
	if _curio_id != "hanyu" or _run_over or tgt.is_empty() or float(tgt.get("hp", 0.0)) <= 0.0:
		return
	var c := mini(3, int(tgt.get("cold", 0)) + 1)
	tgt["cold"] = c
	tgt["cold_t"] = 3.0
	tgt["cold_slow"] = c * (0.15 if _curio_lv >= 4 else 0.10)
	if _curio_lv < 2 or c < 3 or bool(tgt.get("boss", false)):
		return
	tgt["cold"] = 0
	tgt["cold_freeze_t"] = 0.8
	tgt["cold_boom"] = _curio_lv >= 5
	if _curio_lv >= 3:
		tgt["cold_dmg"] = 0.25
	_curio_uses += 1
	_curio_flash()
	_spawn_pfx("impacts/crit-hit", _core.position + Vector2(float(tgt["x"]), float(tgt["y"]) - 16.0), 0.8, "", 1.4)
	Aud.sfx("bell", -12.0, 1.3)

func _curio_on_cold_expired(tgt: Dictionary) -> void:
	var boom := bool(tgt.get("cold_boom", false))
	tgt.erase("cold_boom")
	if boom and not _run_over and float(tgt.get("hp", 0.0)) > 0.0:
		var at := Vector2(float(tgt["x"]), float(tgt["y"]))
		_spawn_pfx("impacts/crit-hit", _core.position + at, 1.0, "", 1.4)
		for o_v in _core.foes.duplicate():
			var o: Dictionary = o_v
			if o == tgt or float(o.get("hp", 0.0)) <= 0.0:
				continue
			if at.distance_to(Vector2(float(o["x"]), float(o["y"]))) > 70.0:
				continue
			_core._apply_dmg(o, float(_core.hero.get("atk", 12.0)) * 0.6, "物理")
			if float(o.get("hp", 0.0)) <= 0.0:
				_core._kill_foe(o)

# 清波结算：聚宝盆 / 续命灯
func _curio_on_wave_clear(wave: int) -> void:
	if _core == null:
		return
	_curio_waves += 1
	if _curio_id == "jubaopen":
		var per := 3
		if _curio_lv >= 2:
			per = 4
		if _curio_lv >= 4:
			per = 5
		var amt := per * maxi(1, wave)
		if _curio_lv >= 5 and _wen >= 1000:
			amt += int(floor(float(_wen) * 0.02))
		_add_wen(amt)
		if _curio_lv >= 3 and _roll_curio_crystal():
			_gain_crystal(1)
		_spawn_fly(_hero_screen(), Vector2(99, 40), Color(0.90, 0.71, 0.30), 4)
		_toast("聚宝盆 · 文钱 +%d" % amt)
		_curio_uses += 1
		_curio_flash()
	if _curio_id == "wanyingfu" and _curio_lv >= 3 and _curio_lv < 5:
		var which := _roll_wanying_refresh()
		if which == 0:
			_trea_reroll += 1
		elif which == 1:
			_aug_reroll += 1
		elif which == 2:
			_god_reroll += 1
		else:
			_draw_free += 1
		_refresh_draw_btn()
		_toast("万应符 · 随机刷新 +1")
	if _curio_id == "zhiren":
		var cap_z := 3 if _curio_lv >= 2 else 2
		var gain := 2 if _curio_lv >= 4 else 1
		_set_paper_count(mini(cap_z, _zhiren + gain))
		_toast("纸人替身 · 现有 %d 个" % _zhiren)
		_curio_flash()
	if _curio_id == "xumingdeng":
		var every := 3
		if _curio_lv >= 2:
			every = 2
		if _curio_lv >= 5:
			every = 1
		if _curio_waves % every == 0:
			_curio_gain_life(3 if _curio_lv == 4 else 2)

func _roll_curio_crystal() -> bool:
	return randf() < 0.10

func _curio_gain_life(amount: int) -> void:
	_life += amount
	_refresh_life_ui()
	_toast("续命灯 · 命 +%d" % amount)
	_curio_uses += 1
	_curio_flash()
	Aud.sfx("coin", -10.0)

func _curio_on_boss_slain() -> void:
	if not _run_over and _curio_id == "xumingdeng" and _curio_lv >= 3:
		_curio_gain_life(5)

func _show_curio_detail() -> void:
	if _curio_detail != null:
		_curio_detail.queue_free()
	var info := CurioData.get_curio(_curio_id)
	var has := not info.is_empty()
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 32
	add_child(layer)
	_curio_detail = layer
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var holder := Control.new()
	holder.position = Vector2(120, 340)
	holder.size = Vector2(480, 470)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	_panel(Rect2(0, 0, 480, 470), Color(0.97, 0.93, 0.85, 0.99), 10, Color(0.85, 0.66, 0.23), 3, holder)
	if not has:
		_lbl("本局没有携带奇物", Vector2(0, 40), Vector2(480, 44), 28, INK, holder, HORIZONTAL_ALIGNMENT_CENTER)
		_lbl("在局外「奇物」页选择一件再出击", Vector2(0, 96), Vector2(480, 30), 18, DIM, holder, HORIZONTAL_ALIGNMENT_CENTER)
		_btn("×", Rect2(436, 12, 34, 30), 20, Color(0.97, 0.93, 0.85), DIM,
			func() -> void: _curio_detail.visible = false, holder)
		_pop_bounce(holder)
		return
	_lbl(str(info.get("name", "")), Vector2(0, 16), Vector2(480, 42), 32, INK, holder, HORIZONTAL_ALIGNMENT_CENTER)
	_panel(Rect2(148, 60, 184, 28), Color(0.62, 0.44, 0.12, 0.92), 5, Color(0.62, 0.44, 0.12), 0, holder)
	_lbl("奇物 · Lv %d" % _curio_lv, Vector2(148, 62), Vector2(184, 24), 15, Color(0.99, 0.95, 0.87), holder, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl(str(info.get("glyph", "?")), Vector2(0, 96), Vector2(480, 70), 46, Color(0.36, 0.28, 0.12), holder, HORIZONTAL_ALIGNMENT_CENTER)
	var cdv := float(info.get("cd", 0.0))
	var rows := [
		["当前", CurioData.level_text(_curio_id, _curio_lv)],
		["触发", str(info.get("trig", ""))],
		["冷却", ("%d 秒（自动使用，不用操作）" % int(cdv)) if cdv > 0.0 else "被动 · 常驻"],
		["本局", "已触发 %d 次" % _curio_uses],
	]
	var y := 186.0
	for r in rows:
		_lbl(str(r[0]), Vector2(26, y), Vector2(70, 24), 15, Color(0.47, 0.41, 0.33), holder)
		_lbl(str(r[1]), Vector2(92, y - 3), Vector2(360, 26), 18, INK, holder)
		y += 52.0
	if _curio_lv < 5:
		_lbl("下一档：%s" % CurioData.level_text(_curio_id, _curio_lv + 1),
			Vector2(26, 388), Vector2(430, 24), 16, Color(0.47, 0.41, 0.33), holder)
	_lbl("全自动使用，玩家不需要点它；点这里只是看详情", Vector2(26, 424), Vector2(430, 22), 15, Color(0.47, 0.41, 0.33), holder)
	_btn("×", Rect2(436, 12, 34, 30), 20, Color(0.97, 0.93, 0.85), DIM,
		func() -> void: _curio_detail.visible = false, holder)
	_pop_bounce(holder)
	_breathe(holder)

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
	_deck_count_lb = _lbl("卡组 0/10", Vector2(22, 910), Vector2(160, 30), 20, INK)
	_page_lb = _lbl("1/2", Vector2(330, 910), Vector2(60, 30), 17, DIM, self, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("<", Rect2(8, 960, 56, 60), 28, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _flip(-1))
	_btn(">", Rect2(656, 960, 56, 60), 28, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _flip(1))
	for i in 5:
		var s := CardSlot.new()
		s.position = Vector2(46 + i * 132, 940)
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
	_panel(Rect2(8, 1076, 704, 204), Color(0.075, 0.068, 0.060, 0.98), 10, Color(0.85, 0.66, 0.23, 0.45), 2)
	_lv_lb = _lbl("Lv 1", Vector2(22, 1088), Vector2(70, 28), 18, GOLD)
	_panel(Rect2(96, 1090, 600, 16), Color(0.93, 0.90, 0.82, 0.16), 8)
	_exp_bar = _panel(Rect2(96, 1090, 4, 16), Color(0.85, 0.66, 0.23), 8)
	_exp_lb = _lbl("0/100", Vector2(600, 1088), Vector2(92, 20), 15, Color(0.88, 0.82, 0.70), self, HORIZONTAL_ALIGNMENT_RIGHT)
	_market_tile = _tile(24, 1128, 124, "market", "黑市", false)
	_market_tile.visible = LevelState.show_button("market")
	_trea_tile = _tile(158, 1128, 124, "treasure", "宝物", false)
	_trea_tile.visible = LevelState.show_button("treasure")
	_mate_tile = _tile(292, 1128, 124, "mate", "请神", false)
	_mate_tile.visible = LevelState.show_button("mate")
	_str_tile = _tile(426, 1128, 124, "skill", "强化", false)
	# 强化固定隐藏：清完第一波的教学那一刻才亮出来（不因重玩而提前显示）
	_str_tile.visible = false
	_str_tile.hot = false
	_draw_tile = _tile(560, 1116, 136, "draw", "抽卡", true)
	_draw_tile.visible = LevelState.show_button("draw")
	_refresh_level_ui()
	_refresh_str_tile()
	_refresh_trea_tile()

func _tile(x: float, y: float, s: float, kind: String, label: String, hot: bool) -> Tile:
	var t := Tile.new()
	t.position = Vector2(x, y)
	t.size = Vector2(s, s)
	t.kind = kind
	t.label = label
	t.hot = hot
	var hit := func() -> void:
		match kind:
			"draw": _show_draw(true)
			"market": _open_bm()
			"treasure": _on_trea_tile()
			"mate": _on_mate_tile()
			"skill": _on_str_tile()
			_: _toast(label)
	t.pressed.connect(hit)
	add_child(t)
	return t

# 奇物方块：跟「挑战」一样 96×96，冷却时压暗 + 显示秒数
# 首领血条：顶部横条，带"掉血残影"（ghost 慢慢追上来）
class BossBar extends Control:
	const F := preload("res://fonts/ink.ttf")
	var ratio := 1.0
	var ghost := 1.0
	var bname := ""
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.11, 0.08, 0.90)
		sb.set_corner_radius_all(7)
		sb.border_color = Color(0.62, 0.50, 0.32, 0.95)
		sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var inner := Rect2(3, 3, size.x - 6, size.y - 6)
		# 残影（掉下去的那一截，慢慢缩）
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(ghost, 0.0, 1.0), inner.size.y)),
			Color(0.88, 0.66, 0.36, 0.38))
		# 当前血量
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(ratio, 0.0, 1.0), inner.size.y)),
			Color(0.70, 0.15, 0.11, 0.98))
		# 四等分刻度（看得出还剩几段）
		for i in range(1, 4):
			var tx := inner.position.x + inner.size.x * float(i) / 4.0
			draw_line(Vector2(tx, inner.position.y), Vector2(tx, inner.position.y + inner.size.y),
				Color(0.10, 0.08, 0.06, 0.35), 1.0)
		# 名字（先描一层暗影，红底/金底上都看得清）
		draw_string(F, Vector2(1, size.y * 0.5 + 6), bname,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(0.0, 0.0, 0.0, 0.55))
		draw_string(F, Vector2(0, size.y * 0.5 + 5), bname,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(0.98, 0.94, 0.85))

# 资源飞行层：击杀掉的金币/晶石飞向右上角资源条（割草的正反馈）
class FlyLayer extends Control:
	var dots: Array = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for d_v in dots:
			var d: Dictionary = d_v
			draw_circle(Vector2(float(d["x"]), float(d["y"])), float(d["r"]), d["col"])

class CurioSquare extends Control:
	const F := preload("res://fonts/ink.ttf")
	signal pressed
	var glyph := "壶"
	var label := "奇物"
	var cd_left := 0.0
	var cd_max := 60.0
	var flash := 0.0            # 触发时闪一圈金环
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.068, 0.060, 0.98))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.66, 0.23, 0.55), false, 2.0)
		var ready := cd_left <= 0.001
		var col := Color(0.91, 0.78, 0.42) if ready else Color(0.52, 0.48, 0.40)
		draw_string(F, Vector2(0, 54), glyph, HORIZONTAL_ALIGNMENT_CENTER, size.x, 38, col)
		draw_string(F, Vector2(0, 84), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, col)
		if not ready:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.02, 0.42))
			draw_string(F, Vector2(0, 62), str(int(ceil(cd_left))), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(0.94, 0.89, 0.78))
		if flash > 0.0:
			var k := 1.0 - flash
			draw_arc(size * 0.5, size.x * (0.5 + 0.30 * k), 0.0, TAU, 32,
				Color(0.98, 0.82, 0.36, flash * 0.9), 3.0)

# 奇遇圆钮：只在新奇遇掷到时出现，靠在主角左侧；上面浮着大红字「奇遇！」
class QuestOrb extends Control:
	const F := preload("res://fonts/ink.ttf")
	signal pressed
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(c, r, Color(0.12, 0.09, 0.07, 0.96))
		draw_arc(c, r, 0.0, TAU, 48, Color(0.80, 0.24, 0.18), 3.0)
		draw_arc(c, r - 6.0, 0.0, TAU, 48, Color(0.85, 0.66, 0.23, 0.55), 1.5)
		# 卷轴图标
		var w := r * 1.0
		var h := r * 0.66
		var box := Rect2(c - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
		draw_rect(box, Color(0.88, 0.83, 0.70), true)
		draw_rect(box, Color(0.28, 0.20, 0.10), false, 2.0)
		for i in 3:
			var yy := c.y - h * 0.22 + float(i) * h * 0.24
			draw_line(Vector2(c.x - w * 0.30, yy), Vector2(c.x + w * 0.30, yy), Color(0.42, 0.32, 0.18), 1.6)

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
	_breathe(banner)
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
	_draw_refresh_btn = _btn("刷新 · 5 灵晶", Rect2(250, 540, 220, 56), 20, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _on_refresh(), _draw_layer)

func _roll_draw() -> void:
	var cands: Array = []
	for id_v in _pool:
		if _family_card_allowed(str(id_v)):
			cands.append(id_v)
	# 第四关暗抬危途线：危险卡在抽卡池里权重 ×2，玩家更容易摸到增怪/挑战收益
	if LevelState.current_level == 4:
		var weighted: Array = []
		for id_v in cands:
			weighted.append(id_v)
			var sid := str(id_v)
			if sid.begins_with("swarm_") or sid.begins_with("peril_"):
				weighted.append(id_v)
		cands = weighted
	# 杀敌相关卡（经验系）权重 ×2
	var killw: Array = []
	for id_v in cands:
		killw.append(id_v)
		var kc: Dictionary = _card_db.get(str(id_v), {})
		if str(kc.get("series", "")) == "exp":
			killw.append(id_v)
	cands = killw
	# 请神后：该祖宗的家传卡权重变大
	if not _ancestors.is_empty():
		var fam: Array = []
		for id_v in cands:
			fam.append(id_v)
			var cc: Dictionary = _card_db.get(str(id_v), {})
			if str(cc.get("ancestor", "")) != "":
				fam.append(id_v)
		cands = fam
	# 第九关：主角家传权重再抬一档
	if LevelState.current_level == 9:
		var zj: Array = []
		for id_v in cands:
			zj.append(id_v)
			var zc: Dictionary = _card_db.get(str(id_v), {})
			if str(zc.get("ancestor", "")) == "zhujue":
				zj.append(id_v)
		cands = zj
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
	# 第五关：第二组家传后，下一手必出其中一位请神的炫彩卡
	if _family_shiny_ready:
		_family_shiny_ready = false
		_family_shiny_done = true
		var sids: Array = []
		for a_v in _ancestors.keys():
			var s := "shiny_" + str(a_v)
			if _card_db.has(s) and not _acquired.has(s) and not _shiny_used.has(str(a_v)):
				sids.append(s)
		if not sids.is_empty():
			var sid := str(sids[randi() % sids.size()])
			if not _pool.has(sid):
				_pool.append(sid)
			cands.erase(sid)
			cands.push_front(sid)
			_toast("炫彩卡现世")
	# 同一手不重复出同一张卡（池里若有重复 id，这里兜住）
	var uniq: Array = []
	for id_u in cands:
		var su := str(id_u)
		if uniq.has(su):
			continue
		uniq.append(su)
		if uniq.size() >= _draw_cards.size():
			break
	cands = uniq
	for i in _draw_cards.size():
		var dc: DrawCard = _draw_cards[i]
		if i < cands.size():
			var c: Dictionary = (_card_db[str(cands[i])] as Dictionary).duplicate()
			c["_id"] = str(cands[i])
			dc.data = c
			dc.progress = _set_progress(str(c.get("set_id", "")))
		else:
			dc.data = {}
			dc.progress = 0
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
		var shiny_p := 0.04
		if LevelState.current_level == 9 and aid == "zhujue":
			shiny_p = 0.20   # 第九关只对主角炫彩卡大幅提升
		if randf() < shiny_p:
			_shiny_rolled[aid] = true
			var sid := "shiny_" + aid
			if _card_db.has(sid) and not _pool.has(sid):
				_pool.append(sid)
				_toast("彩蛋！炫彩卡「%s」已加入卡池" % str((_card_db[sid] as Dictionary)["name"]))
				Aud.sfx("ult_ready", -4.0)

func _update_crystal() -> void:
	if _crystal_lb != null:
		_crystal_lb.text = str(_crystal)

func _show_draw(v: bool) -> void:
	if v and _run_over:
		return
	if v:
		_hide_aug_pick()                     # 进阶页开着一并收掉
		_hide_trea()                         # 宝物页同理
		if not _draw_paid:
			if _pool.is_empty():
				_toast("本局卡池已空")
				return
			if _crystal < 20:
				_toast("灵晶不足，不足以抽卡（一次要 20）")
				return
			_crystal -= 20
			_update_crystal()
			_roll_draw()
			_draw_paid = true
		_draw_open = true
		_draw_layer.visible = true
		_layer_in(_draw_layer)
		_draw_layer.move_to_front()
		_pop_draw_cards()
	else:
		_draw_layer.visible = false
		_draw_open = false

func _on_draw_pick(card: DrawCard) -> void:
	if _run_over or not _draw_paid or _draw_layer == null or not _draw_layer.visible:
		return
	if _draw_anim or card == null or not _draw_cards.has(card) or card.data.is_empty(): return
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
		if _run_over:
			return
		_add_card(id)
		_zhongli_try(id))

func _refresh_draw_btn() -> void:
	if _draw_refresh_btn != null:
		_draw_refresh_btn.text = "刷新 · 免费 %d 次" % _draw_free if _draw_free > 0 else "刷新 · 5 灵晶"

func _on_refresh() -> void:
	if _run_over or _draw_anim or not _draw_paid or _draw_layer == null or not _draw_layer.visible: return
	if _pool.is_empty():
		_toast("卡池已空，没法刷新")
		return
	var paid := true
	if _draw_free > 0:
		_draw_free -= 1
		paid = false
	else:
		if _crystal < 5:
			_toast("灵晶不够：刷新要 5")
			return
		paid = not _rr_free()
	if paid:
		_crystal -= 5
		_update_crystal()
	_refresh_draw_btn()
	_draw_anim = true
	for card in _draw_cards:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "scale", Vector2(0.72, 0.72), 0.16)
		tw.tween_property(card, "modulate:a", 0.0, 0.16)
	await get_tree().create_timer(0.2).timeout
	if _run_over:
		_draw_anim = false
		return
	_roll_draw()
	_draw_anim = false
	_pop_draw_cards()
	_toast("刷新：5 灵晶" if paid else "免费刷新")

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
# v6：详细属性页（kushou/attr_panel.gd），懒加载一次，之后复用
var _attr_page = null

func _open_attr_page() -> void:
	if _core == null:
		return
	if _attr_page == null:
		_attr_page = load("res://kushou/attr_panel.gd").new()
		add_child(_attr_page)
		_attr_page.z_index = 60
	_attr_page.setup(_core)
	_attr_page.open()


# v6：新属性层 → 旧 hero 字段（atk / hp）。技能、召唤物、顶部血条还在读旧字段。
# 临时诊断：英雄为什么不出手（每 2 秒一行）
var _dbg_atk_t := 0.0
func _dbg_hero_attack(dt: float) -> void:
	if _core == null:
		return
	# 默认关闭；需要排查时设环境变量 DSH_DEBUG=1
	if OS.get_environment("DSH_DEBUG") == "":
		return
	_dbg_atk_t += dt
	if _dbg_atk_t < 2.0:
		return
	_dbg_atk_t = 0.0
	var h: Dictionary = _core.hero
	var t: Dictionary = _core._order_target()
	var tp := Vector2(float(t.get("x", 0.0)), float(t.get("y", 0.0))) if not t.is_empty() else Vector2.ZERO
	print("[ATK] lv=", LevelState.current_level, " wave=", _core.wave, "/", _max_wave, " kills=", _kills,
		" running=", _core.running, " proc=", _core.is_processing(), " selfproc=", is_processing(),
		" hp=", int(float(h.get("hp", 0.0))), "/", int(float(h.get("hp_max", 0.0))),
		" atk=", snappedf(float(h.get("atk", 0.0)), 0.1), " aspd=", snappedf(float(h.get("aspd", 0.0)), 0.01),
		" cd=", snappedf(float(_core._hero_cd), 0.01),
		" tgt=", not t.is_empty(), " dist=", snappedf(_core.hero_pos.distance_to(tp), 0.1),
		" foes=", _core.foes.size(), " live=", _core.live_foes())

func _sync_attrs_to_hero() -> void:
	if _core == null:
		return
	var h: Dictionary = _core.hero
	h["atk"] = _core.attr_final("atk")
	h["crit"] = _core.attr_final("crit")
	h["crit_dmg"] = _core.attr_final("cdmg")
	h["cut"] = _core.type_effective_field("物理", "red_f")
	h["cut_all"] = 0.0
	h["dmg_all"] = _core.type_amp("物理")
	h["aspd"] = float(_core.attr_final("aspd")) / 1.8
	var mp_new: float = float(_core.attr_final("mp"))
	h["mp_max"] = mp_new
	h["mp"] = minf(mp_new, _mp)
	_mp_max = mp_new
	_mp = minf(_mp_max, _mp)
	var hp_new: float = float(_core.attr_final("hp"))
	var ratio := 1.0
	if float(h.get("hp_max", 1.0)) > 0.0:
		ratio = clampf(float(h.get("hp", 0.0)) / float(h.get("hp_max", 1.0)), 0.0, 1.0)
	h["hp_max"] = hp_new
	h["hp"] = minf(hp_new, hp_new * ratio)


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
	if _run_over:
		_tick_fly(_delta)
		_tick_pulses(_delta)
		return
	var _t_proc := Time.get_ticks_usec()
	var t := Time.get_ticks_msec() / 1000.0
	for i in _enemies.size():
		var e: Control = _enemies[i]
		e.position.y = float(e.get_meta("base_y", e.position.y)) + sin(t * 1.6 + i) * 2.0
	if _core != null:
		# v6：新属性层是结算源；每帧把攻击/气血回写到旧 hero，给技能/召唤物/顶部血条读
		_sync_attrs_to_hero()
		_dbg_hero_attack(_delta)
		if int(_core.wave) != _last_wave:
			_last_wave = int(_core.wave)
			_trigger_combos("每波")
		# 最后一波：先把小怪清完，Boss 才登场（不同时出现）
		if int(_core.wave) >= _max_wave:
			_core.boss_required = true
		if not _boss_spawned and not _run_cleared and int(_core.wave) >= _max_wave 				and _core._wave_spawned >= _core._wave_quota and _core.live_foes() <= 0:
			_boss_spawned = true
			_core.start_boss(LevelState.boss_tier(), "")
		_run_time += _delta
		_combo_t += _delta
		if _combo_t >= 6.0:
			_combo_t -= 6.0
			_trigger_combos("每 6 秒")
		if _wave_lb != null:
			_wave_lb.text = "波 %d/%d" % [int(_core.wave), _max_wave]
		# v2 波次推进：本波定额刷完 + 场上清空 → 进下一波；满 MAX_WAVE 收工
		if not _run_cleared and _core.wave_cleared():
			var cleared_wave := int(_core.wave)
			if cleared_wave < _max_wave:
				_core.set_wave(cleared_wave + 1)
				_core.wave_reset_quota()
				_spawn_typed_foes()
				_on_wave_clear(cleared_wave)
			else:
				_run_cleared = true
				_on_wave_clear(cleared_wave)
				_end_run(true)
				return
		if _hp_lb != null:
			_hp_lb.text = "%d/%d" % [int(float(_core.hero.get("hp", 0))), int(float(_core.hero.get("hp_max", 1)))]
		var hpr := clampf(float(_core.hero.get("hp", 0.0)) / maxf(1.0, float(_core.hero.get("hp_max", 1.0))), 0.0, 1.0)
		if LevelState.current_level >= 2 and LevelState.current_level <= 4:
			# 不改怪面板，只偷偷加易伤：成长/家传组合给足，经济/危途给少一点
			var vuln := _equip_vuln
			for rec in _combined:
				var s := str(rec.get("series", ""))
				if s in ["gold", "crystal", "exp", "bounty"]:
					vuln += 0.06
				elif s in ["swarm", "peril"]:
					vuln += 0.10
				else:
					vuln += 0.15
			vuln += float(_ancestor_combos.size()) * 0.15
			_core.foe_vuln = minf(0.45, vuln)
		elif LevelState.current_level == 7:
			# 第七关：技能升级过，怪偷偷吃更多伤害；没升级也能过，只是吃力
			var skill_total := 0
			for v in GameState.skill_lv.values():
				skill_total += int(v)
			_core.foe_vuln = minf(0.30, float(skill_total) * 0.015 + _equip_vuln)
		elif LevelState.current_level == 8:
			# 第八关：局外装备强化越高，怪偷偷越脆；四件 +20 共 80 级 → 20% 易伤
			var FD8 := preload("res://shared/forge_data.gd")
			var plus_total := 0
			for slot_v in FD8.SLOT_KEYS:
				plus_total += int((FD8.equipped.get(str(slot_v), {}) as Dictionary).get("plus", 0))
			_core.foe_vuln = minf(0.35, float(plus_total) * 0.0025 + _equip_vuln)
		elif _equip_vuln > 0.0:
			_core.foe_vuln = minf(0.45, _equip_vuln)
		if int(_core.wave) >= 2 and hpr <= 0.50:
			if LevelState.current_level == 1 and not _l1_yuhu_shown:
				_l1_yuhu_shown = true
				_l1_tutorial("l1_yuhu", _curio_sq, "气血不足时，玉壶会自动回血", _show_curio_detail)
		if _hp_fill != null:
			_hp_fill.size = Vector2(maxf(4.0, 235.0 * hpr), 20.0)
			_tick_skills(_delta)
		_tick_rare_buffs(_delta)
		_tick_curio(_delta)
		_tick_fly(_delta)
		_tick_pulses(_delta)
		if not _recycle_q.is_empty():
			for i in range(_recycle_q.size() - 1, -1, -1):
				var it: Array = _recycle_q[i]
				var tkq = it[0]
				if not is_instance_valid(tkq):
					_recycle_q.remove_at(i)
					continue
				it[1] = float(it[1]) - _delta
				if float(it[1]) <= 0.0:
					tkq.reset_pose()
					tkq.visible = false
					if _foe_pool.size() < 40:
						_foe_pool.append(tkq)
					else:
						tkq.queue_free()
					_recycle_q.remove_at(i)
		if _boss_bar != null:
			var bf: Dictionary = _core._boss_foe() if _core != null else {}
			_boss_on = not bf.is_empty()
			if bf.is_empty():
				if _boss_bar.visible:
					_boss_bar_t = maxf(0.0, _boss_bar_t - _delta)
					if _boss_bar_t <= 0.0:
						_boss_bar.visible = false
			else:
				_boss_bar.visible = true
				_boss_bar_t = 1.2
				var rr := clampf(float(bf["hp"]) / maxf(1.0, float(bf["hp_max"])), 0.0, 1.0)
				var need := false
				if absf(rr - float(_boss_bar.ratio)) > 0.0005:
					_boss_bar.ratio = rr
					need = true
				if float(_boss_bar.ghost) > rr:
					_boss_bar.ghost = move_toward(float(_boss_bar.ghost), rr, _delta * 0.45)
					need = true
				elif not is_equal_approx(float(_boss_bar.ghost), rr):
					_boss_bar.ghost = rr
					need = true
				var nm := str(bf.get("name", "首领"))
				if nm != _boss_bar.bname:
					_boss_bar.bname = nm
					need = true
				if need:
					_boss_bar.queue_redraw()
		if _core != null:
			var cb := int(_core._combo)
			if cb != _last_combo:
				if cb > _last_combo and cb % 10 == 0:
					_spawn_pfx("holy/sunburst", _hero_screen(), 1.05, "gold", 1.9)
					_core._shake = maxf(float(_core._shake), 7.0)
				_last_combo = cb
		_tick_chal(_delta)
		_q_tick(_delta)
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
			var hpr_tok := float(_core.hero.get("hp", 0.0)) / maxf(1.0, float(_core.hero.get("hp_max", 1.0)))
			if absf(hpr_tok - float(_hero_token.hp_ratio)) > 0.0015:
				_hero_token.hp_ratio = hpr_tok
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
		if _no_tokens:
			for i in range(_enemies.size() - 1, -1, -1):
				_enemies[i].queue_free()
			_enemies.clear()
			for tid0 in _foe_tokens.keys():
				var tk0 = _foe_tokens[tid0]
				if tk0 != null:
					tk0.queue_free()
			_foe_tokens.clear()
		for f in (_core.foes if not _no_tokens else []):
			if not f.has("_tid"):
				_foe_seq += 1
				f["_tid"] = _foe_seq
				_foe_tokens[_foe_seq] = _make_foe_token(f)
			var tid: int = int(f["_tid"])
			active[tid] = true
			var tk = _foe_tokens.get(tid)
			if tk != null:
				tk.position = _core.position + Vector2(float(f["x"]), float(f["y"]))
				var hr := float(f["hp"]) / maxf(1.0, float(f["hp_max"]))
				if absf(hr - float(tk.hp_ratio)) > 0.0015:
					tk.hp_ratio = hr
					tk.queue_redraw()
				var uname := str(f.get("name", ""))
				if uname != tk.unit_name:
					tk.unit_name = uname
					tk.queue_redraw()
				tk.visible = float(f.get("y", 0.0)) >= 90.0
		for tid in _foe_tokens.keys():
			if not active.has(tid):
				var tk = _foe_tokens[tid]
				if tk != null:
					tk.play_down()
					_recycle_q.append([tk, 1.10])
					# 阵亡小爆点（割草感：每杀一只都有一口）
					if randf() < (0.40 if _boss_on else 0.60):
						_spawn_pfx("impacts/blunt-hit", tk.position + Vector2(0, -8), 0.60, "dust", 1.1, 1.15)
					# 微顿帧＋连杀轻震：每杀一只都"顿一下"
					_core._hitstop = maxf(float(_core._hitstop), 0.030)
					if int(_core._combo) >= 5:
						_core._shake = maxf(float(_core._shake), 2.5)
				_foe_tokens.erase(tid)
	var _el := Time.get_ticks_usec() - _t_proc
	if _el > 50000:
		print("[SLOW] battle_ui ", _el / 1000.0, " ms")

func _on_core_kill(n: int) -> void:
	_curio_on_kill(n)                        # 奇物：醉翁壶（击杀累计）
	# v15 经验线：杀 1 只按 1+x% 只算（经验与所有按击杀成长的机制一起吃）
	var kn := int(round(float(n) * (1.0 + _killnum_pct / 100.0)))
	if kn < n:
		kn = n
	_kills += kn
	_qc("kill", kn)
	if _kill_lb != null:
		_kill_lb.text = str(_kills)
	_pulse_chip(_kill_lb)
	_spawn_fly(_hero_screen() + Vector2(0, -26), Vector2(447, 40), Color(0.80, 0.36, 0.24), 2)
	if _bm != null and LevelState.show_button("market"):
		_bm.add_kill(kn)   # 黑市没开放前不喂杀敌数，避免开局弹“黑市升到 Lv”
	_add_exp(20 * kn)                      # v2：杀 1 只 +20 经验
	_add_wen(int(round(float(WEN_KILL_BASE + WEN_KILL_WAVE * int(_core.wave)) * (1.0 + _kill_pct / 100.0))))
	if LevelState.current_level == 2:
		_gain_crystal(1)   # 只有第二关靠普通击杀补灵晶；第三关起让经济线说话
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
	var god := 0
	# 等级不设硬上限：正常经验到通关大约 20 级；请神次数另有 god_cap 管
	while _exp >= _exp_need:
		_exp -= _exp_need
		_lv += 1
		_exp_need += 50
		_level_bonus(1)               # 每级：攻击 +1 · 气血上限 +6（内力上限同步 +25）
		if _lv % 5 == 0:
			_draw_charge += 1   # 每 5 级给一次；允许溢出，后面请神候选用完就攒着
			if LevelState.has_feature("mate") and not _l5_mate_shown:
				_l5_mate_shown = true
				_tutorial("l5_mate", _mate_tile, "升级可以选请神，带家传卡", func() -> void: pass)
			god += 1
		up += 1
	_qc("lv", up)
	if up > 0:
		_choice_fx("lv")
	_refresh_level_ui()
	if up > 0:
		var msg := "升到 Lv %d · 攻+%d · 血+%d" % [_lv, up, up * 6]
		if god > 0:
			msg += " · 请神 +%d" % god
		_toast(msg)

# 升级给属性（只在本局生效）：攻击 +1 · 气血上限 +6 · 内力上限 +25
func _level_bonus(n: int) -> void:
	if _core == null or n <= 0:
		return
	var h: Dictionary = _core.hero
	var ratio := 1.0
	if float(h["hp_max"]) > 0.0:
		ratio = clampf(float(h["hp"]) / float(h["hp_max"]), 0.0, 1.0)
	var add_atk := 1.0 * float(n)
	var add_hp := 6.0 * float(n)
	_core.attr_add("atk", add_atk)
	_core.attr_add("hp", add_hp)
	_core.attr_add("mp", 25.0 * float(n))
	h["mp_max"] = _core.attr_final("mp")
	h["atk"] = float(h["atk"]) + add_atk
	h["hp_max"] = float(h["hp_max"]) + add_hp
	h["hp"] = float(h["hp_max"]) * ratio
	_stats["atk"] = float(_stats["atk"]) + add_atk
	_stats["hp"] = float(_stats["hp"]) + add_hp

func _refresh_level_ui() -> void:
	if _lv_lb != null:
		_lv_lb.text = "Lv " + str(_lv)
	if _exp_lb != null:
		_exp_lb.text = "%d/%d" % [_exp, _exp_need]
	if _exp_bar != null:
		var r := clampf(float(_exp) / maxf(1.0, float(_exp_need)), 0.0, 1.0)
		_exp_bar.size = Vector2(maxf(4.0, 600.0 * r), 16.0)
	if _mate_tile != null:
		var lit := _draw_charge > 0
		if _mate_tile.hot != lit:
			_mate_tile.hot = lit
			_mate_tile.queue_redraw()
		_mate_tile.badge = _draw_charge

# ============================================================
# 当局生命：主角倒下 = 这一波没打下来，不是直接结束
#   扣命（按剩余怪权重）→ 怪全清（无掉落/无经验）→ 过波且无奖励
#   → 挑战全部进冷却 → 主角满血站起来 → 命 <= 0 才结算
# ============================================================
const CHAL_BASE_CD := [25.0, 30.0, 30.0, 90.0, 150.0]
const CHAL_MIN_WAVE := [1, 1, 2, 3, 5]

func _chal_base_cd(i: int) -> float:
	return float(CHAL_BASE_CD[clampi(i, 0, CHAL_BASE_CD.size() - 1)])

# 挑战全部进冷却（失败惩罚 + 本局结束时也顺手调）
func _chal_all_cd() -> void:
	for i in _chal_cd.size():
		_chal_cd[i] = maxf(float(_chal_cd[i]), _chal_base_cd(i))

# 一只怪折算多少"命"：小怪 1 · 挑战群怪 2 · 挑战大怪 5 · 首领 10
func _foe_life_weight(f: Dictionary) -> int:
	if f.has("chal"):
		return 5 if int(f["chal"]) >= 3 else 2
	if bool(f.get("boss", false)):
		return 10
	return 1

func _refresh_life_ui() -> void:
	if _life_lb == null:
		return
	_life_lb.text = str(_life)
	_life_lb.add_theme_color_override("font_color",
		Color(0.86, 0.24, 0.18) if _life <= 20 else Color(0.95, 0.91, 0.83))

func _on_hero_down() -> void:
	if _run_over:
		return
	# 奇物·纸人替身：替你挡一次致命伤害（不扣命、不清场）
	if _curio_id == "zhiren" and _zhiren > 0:
		_set_paper_count(_zhiren - 1)
		_core.hero["hp"] = float(_core.hero.get("hp_max", 1.0))
		_core.running = true
		_paper_shatter()
		_curio_uses += 1
		_curio_flash()
		_toast("纸人替身 · 挡住致命一击（剩 %d）" % _zhiren)
		Aud.sfx("paper", -6.0, 1.0)
		_spawn_pfx("holy/heal", _hero_screen(), 1.0, "heal", 1.5)
		return
	# 装备免死必须在扣命和清场前处理，不能依赖死亡信号连接顺序。
	if _bm != null and _bm.try_prevent_death():
		_core.running = true
		return
	var loss := 0
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) > 0.0:
			loss += _foe_life_weight(f)
	loss = maxi(1, loss)
	_life = maxi(0, _life - loss)
	_refresh_life_ui()
	_core.foes.clear()               # 怪全清：不掉落、不给经验
	_core.clear_enemy_attacks()       # 旧预警/地面伤害不能追到复活后的下一波
	_chal_all_cd()                   # 挑战全部进冷却
	_spawn_pfx("shadow/dark-explosion", _hero_screen(), 1.25, "blood", 1.7)
	_core._shake = maxf(float(_core._shake), 12.0)
	_core.hero["hp"] = float(_core.hero.get("hp_max", 1.0))   # 满血站起来（不做浴血）
	_core.running = true
	Aud.sfx("ui_back", -4.0)
	# 这一波直接判负：不给奖励，立刻进下一波（最后一波打输 = 本局结束）
	var cleared_wave := int(_core.wave)
	if cleared_wave < _max_wave:
		_toast("第 %d 波没打下来 · 命 -%d" % [cleared_wave, loss])
		_core.set_wave(cleared_wave + 1)
		_core.wave_reset_quota()
		_spawn_typed_foes()
	else:
		_toast("第 %d 波没打下来 · 命 -%d" % [cleared_wave, loss])
		_end_run(false)
	if _life <= 0:
		_end_run(false)

# ---- 本局结束：命尽（输） / 通关（赢） ----
var _result_layer: Control = null

func _end_run(win: bool) -> void:
	if _run_over:
		return
	if win:
		var SaveFile := preload("res://shared/save_file.gd")
		if SaveFile.begin() == OK:
			var first := LevelState.mark_first_clear()
			if first:
				_grant_first_clear(LevelState.current_level)
			if SaveFile.commit() != OK:
				_toast("首通保存失败，请勿关闭游戏")
		else:
			_toast("首通记录恢复失败，请检查存储空间")
	_run_over = true
	if _core != null:
		_core.running = false
	if _cam != null:
		_cam.scale = Vector2.ONE
	# 结算前的"定格式"反馈：一闪 + 长顿帧，然后才弹面板
	_screen_flash(Color(1.0, 0.96, 0.82) if win else Color(0.52, 0.17, 0.13), 0.34 if win else 0.28, 0.5)
	if _core != null:
		_core._hitstop = maxf(float(_core._hitstop), 0.30)
	if win:
		for i in 10:
			_spawn_fly(Vector2(360, 470), Vector2(99, 40), Color(0.92, 0.74, 0.32), 1)
	_build_result(win)
	Aud.sfx("levelup" if win else "ui_back", -3.0)

func _build_result(win: bool) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 40
	add_child(layer)
	_result_layer = layer
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var holder := Control.new()
	holder.position = Vector2(90, 320)
	holder.size = Vector2(540, 480)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	_panel(Rect2(0, 0, 540, 480), Color(0.97, 0.93, 0.85, 0.99), 12,
		Color(0.85, 0.66, 0.23) if win else Color(0.64, 0.22, 0.15), 3, holder)
	_lbl("通　关" if win else "命　尽", Vector2(0, 26), Vector2(540, 58), 42,
		Color(0.62, 0.44, 0.12) if win else Color(0.62, 0.20, 0.14), holder, HORIZONTAL_ALIGNMENT_CENTER)
	var mins := int(_run_time) / 60
	var secs := int(_run_time) % 60
	var total_bonds := _bonds.size() + _bonds_done
	var rows := [
		["到达波数", "%d / %d" % [mini(int(_core.wave), _max_wave), _max_wave]],
		["击杀", str(_kills)],
		["文钱", str(_wen)],
		["灵晶", str(_crystal)],
		["羁绊", "%d 条（已成 %d）" % [total_bonds, _bonds_done]],
		["存活", "%d 分 %02d 秒" % [mins, secs]],
	]
	var y := 108.0
	for r in rows:
		_lbl(str(r[0]), Vector2(56, y), Vector2(150, 30), 20, DIM, holder)
		_lbl(str(r[1]), Vector2(210, y), Vector2(276, 30), 22, INK, holder, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 44.0
	_btn("再来一局", Rect2(30, 380, 210, 64), 24, Color(0.86, 0.66, 0.24), Color(0.14, 0.11, 0.08),
		func() -> void: _leave_result(true), holder)
	_btn("回主界面", Rect2(300, 380, 210, 64), 24, Color(0.93, 0.89, 0.80), INK,
		func() -> void: _leave_result(false), holder)
	_pop_bounce(holder)
	_breathe(holder)
	_spawn_pfx("holy/sunburst" if win else "shadow/dark-explosion", Vector2(360, 235), 1.9, "holy" if win else "shadow", 1.8)

# 结果页按钮同时作为保存重试入口，未保存完成时保留当前场景。
func _leave_result(replay: bool) -> void:
	var SaveFile := preload("res://shared/save_file.gd")
	if SaveFile.recover() != OK:
		_toast("保存未完成，请释放存储空间后再次点击")
		return
	if replay:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("res://menu/main_home.tscn")

func _grant_first_clear(lv: int) -> void:
	var stored_equipment := 0
	var r := LevelState.first_reward(lv)
	if r.is_empty():
		return
	if r.has("wen"):
		GameState.add_coin("wen", int(r["wen"]))
	if r.has("skill_book"):
		var bk := str(r["skill_book"])
		GameState.skill_books[bk] = int(GameState.skill_books.get(bk, 0)) + int(r.get("skill_book_n", 1))
	if r.has("equip"):
		var FD := preload("res://shared/forge_data.gd")
		stored_equipment = FD.grant_starter_equipment()
	if r.has("curio_shards"):
		GameState.curio_shards += int(r["curio_shards"])
	if r.has("new_cards"):
		GameState.new_cards_unlocked = true
		_toast("新卡组已解锁 · 敬请期待第十一关")
	if r.has("shards"):
		var sh: Dictionary = r["shards"]
		for k in sh.keys():
			GameState.shards[str(k)] = int(GameState.shards.get(str(k), 0)) + int(sh[k])
	if r.has("forge_mat"):
		var FD2 := preload("res://shared/forge_data.gd")
		FD2.load_game()
		var ore_n := int(r["forge_mat"])
		FD2.ores += ore_n
		FD2.silver += ore_n * 10   # 同步给锻造用的银两，够四件 +20 还有富余
	if r.has("forge_mat"):
		GameState.forge_mat += int(r["forge_mat"])
	if r.has("equip"):
		GameState.equip_tokens += int(r["equip"])
	if r.has("advance"):
		GameState.advance_tokens += int(r["advance"])
	if r.has("curio"):
		GameState.new_curio_unlocked = true
	if r.has("equip") or r.has("forge_mat"):
		var ForgeData := preload("res://shared/forge_data.gd")
		ForgeData.save_game()
	GameState.save_progress()
	var equipment_note := " · %d 件装备入背包" % stored_equipment if stored_equipment > 0 else ""
	_toast("首通 · " + str(r.get("text", "")) + equipment_note)

func _on_wave_clear(cleared_wave: int) -> void:
	if _run_over or _rewarded_waves.has(cleared_wave):
		return
	_rewarded_waves[cleared_wave] = true
	if _skip_reward_wave:
		_skip_reward_wave = false
		_toast("第 %d 波没打下来 · 无奖励" % cleared_wave)
		return
	_qc("clearwave", 1)
	_add_exp(50)                            # v2：清一波 +50 经验
	_add_wen(WEN_WAVE_CLEAR * cleared_wave)  # v6：清一波给一笔文钱
	_curio_on_wave_clear(cleared_wave)       # 奇物：聚宝盆 / 续命灯
	_trea_charge += 1                      # v8：清一波给一次宝物机会
	_refresh_trea_tile()
	_toast("第 %d 波清空" % cleared_wave)
	if cleared_wave == 1:
		# 所有关卡：清完第 1 波亮出强化
		if _str_tile != null:
			_str_tile.visible = true
			_str_tile.hot = true
			_str_tile.queue_redraw()
		# 只有第一关才跑强化/文钱/头像这条教学链
		if LevelState.current_level == 1:
			_l1_tutorial("l1_wen", _str_tile,
				"强化可以强化自身\n提升气血、内力和伤害（强化 Lv1）",
				func() -> void:
					_l1_tutorial("l1_wen2", _chips.get("文钱"),
						"强化需要消耗文钱",
						_on_str_tile))

func _l1_tutorial(key: String, target: Node, text: String, cb: Callable) -> void:
	_tutorial(key, target, text, cb)

func _tutorial(key: String, target: Node, text: String, cb: Callable) -> void:
	if _tut == null:
		return
	# 每局都提示一次强化引导（原来只播一次，重玩时不出现）
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	LevelState.mark_tutorial(key)
	if OS.get_environment("DSH_DEBUG") != "":
		print("[TUT] lv=", LevelState.current_level, " key=", key, " target=", target.name if target != null else "<null>", " text=", text.replace("\n", " / "))
	_tut.open(target, text, cb, func() -> void: _tutorial_pause(true), func() -> void: _tutorial_pause(false))

# 每一关新按钮的首次教学：只出一句，点目标才继续
func _maybe_level_button_tutorial() -> void:
	var lv := LevelState.current_level
	var key := ""
	var target: Control = null
	var text := ""
	match lv:
		2:
			key = "l2_draw"
			target = _draw_tile
			text = "灵晶可以抽卡，组成卡组"
		3:
			key = "l3_trea"
			target = _trea_tile
			text = "宝物可以开出资源和装备"
		4:
			key = "l4_chal"
			target = _chal_btn
			text = "挑战会刷出额外怪，收益更高"
		5:
			return   # 第五关的请神教学改到第一次攒到请神次数时再出
		6:
			key = "l6_market"
			target = _market_tile
			text = "黑市可以买装备、存仓库"
		7:
			key = "l7_skill"
			target = _mate_tile
			text = "请神页可以用技能书升级技能"
		_:
			return
	_tutorial(key, target, text, func() -> void: pass)

var _tutorial_paused := false
var _tutorial_ui_processing := true
var _tutorial_core_processing := true

func _tutorial_pause(p: bool) -> void:
	if p:
		if _tutorial_paused:
			return
		_tutorial_paused = true
		_tutorial_ui_processing = is_processing()
		if _core != null:
			_tutorial_core_processing = _core.is_processing()
		set_process(false)
		if _core != null:
			_core.set_process(false)
	elif _tutorial_paused:
		_tutorial_paused = false
		set_process(_tutorial_ui_processing)
		if _core != null:
			_core.set_process(_tutorial_core_processing)




func _on_mate_tile() -> void:
	if not LevelState.show_button("mate"):
		return
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
	var s := "待选进阶" if _str_pending else "Lv %d" % _str_lv   # 只显示等级，消耗在点击时提示
	var hot := _str_pending or _wen >= cost
	if _str_tile.sub != s or _str_tile.hot != hot:
		_str_tile.sub = s
		_str_tile.hot = hot
		_str_tile.queue_redraw()

# 点［强化］：扣文钱升一级；正好到 10 的倍数就开三选一
func _open_bm() -> void:
	if not LevelState.show_button("market"):
		return
	if _bm != null:
		_bm.open_panel()

func _on_str_tile() -> void:
	if _str_pending:
		_open_aug_pick()                     # 上一手还没选 → 重新打开（不重复扣钱）
		return
	var cost := _str_cost()
	if _wen < cost:
		# 跟升级提示一样，在主角头顶飘一行红字
		if _core != null:
			_core._push_float(_core.hero_pos.x, _core.hero_pos.y - 70.0,
				"无法强化 · 需要 %d 文钱" % cost, Color(0.94, 0.42, 0.32), true)
		return
	_wen -= cost
	if _coin_lb != null:
		_coin_lb.text = str(_wen)
	_str_lv += 1
	_apply_str_levels(1)
	Aud.sfx("ui_click", -6.0)
	_str_pop("强化 +1")
	# 主角头顶也飘一行（跟升级提示一致）
	if _core != null:
		var hh: Dictionary = _core.hero
		_core._push_float(_core.hero_pos.x, _core.hero_pos.y - 70.0,
			"强化 +1 · 气血 %d · 攻击 %d" % [int(float(hh.get("hp_max", 0))), int(float(hh.get("atk", 0)))],
			Color(0.98, 0.86, 0.45), true)
	if _str_tile != null:
		var twp := create_tween()
		twp.tween_property(_str_tile, "scale", Vector2(0.86, 0.86), 0.055)
		twp.tween_property(_str_tile, "scale", Vector2(1.0, 1.0), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_str_tile.pivot_offset = _str_tile.size * 0.5
		var twc := create_tween()
		twc.tween_property(_str_tile, "modulate", Color(1.35, 1.25, 0.9), 0.05)
		twc.tween_property(_str_tile, "modulate", Color(1, 1, 1), 0.18)
	# 强化过一次后：引导点头像查看属性（屏幕压暗、头像亮起）
	if LevelState.current_level == 1 and not _l1_attr_shown:
		_l1_attr_shown = true
		var portrait: Node = _hero_token if _hero_token != null else _hero_hit_btn
		_l1_tutorial("l1_attr", portrait, "点击人物头像可以查看当前属性", func() -> void: _open_attr_page())
	if _str_lv % STR_EVERY == 0:
		_str_pending = true
		_aug_reroll += 1          # 每进一轮，刷新次数 +1
		_open_aug_pick()
		var aug_t: Node = _str_layer
		if _aug_cards.size() > 1:
			aug_t = _aug_cards[1]          # 框中间那张卡，而不是整屏遮罩
		if LevelState.current_level == 1 and not _l1_aug_shown:
			_l1_aug_shown = true
			_l1_tutorial("l1_aug", aug_t,
				"每强化 10 级可大幅提升属性\n并可选择自己的发展方向",
				func() -> void: pass)
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
	_qc("str", n)
	var add_atk := STR_PER_ATK * float(n)
	var add_hp := STR_PER_HP * float(n)
	_core.attr_add("atk", add_atk)
	_core.attr_add("hp", add_hp)
	h["atk"] = float(h["atk"]) + add_atk
	var cut_add := STR_PER_CUT * float(n)
	for t in _core.DMG_TYPES:
		if t != "真实":
			_core.type_add(t, "red_f", cut_add)
	h["cut"] = float(h.get("cut", 0.0)) + cut_add
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
	{"key": "pen_flat", "name": "贯石", "glyph": "贯", "v": 6, "text": "全系穿透 +%d", "desc": "管你什么护体，先凿个洞"},
	{"key": "dmgall_add", "name": "剑意", "glyph": "意", "v": 10, "text": "全系增幅 +%d%%", "desc": "七种伤害一起涨"},
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
	_breathe(ban)
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
	if _run_over or not _str_pending or _str_layer == null:
		return
	if _draw_layer != null:
		_draw_layer.visible = false                 # 抽卡页开着一并收掉，别叠在一起
	_hide_trea()
	_str_round = maxi(1, _str_lv / STR_EVERY)
	# 同一手只掷一次：点［隐藏］关了再点［强化］，看到的是同一手（不能白刷）
	var invalidated := false
	for card in _aug_cards:
		if not card.o.is_empty() and not _aug_has_effect(str(card.o.get("key", ""))):
			invalidated = true
	if _aug_rolled_lv != _str_lv or invalidated:
		_aug_rolled_lv = _str_lv
		_roll_aug()
	if _str_ban_lb != null:
		_str_ban_lb.text = "进阶 · 第 %d 级" % _str_lv
	_str_layer.visible = true
	_str_layer.move_to_front()
	_pop_aug_cards()
	Aud.sfx("ui_open", -8.0)

# 掷三张：品阶随轮次升（良→玄→地→天），数值 ×(1+0.4×(轮-1))
func _aug_has_effect(key: String) -> bool:
	if _core == null:
		return false
	match key:
		"crit_add": return _core.attr_final("crit") < 0.75 - 0.000001
		"critdmg_add": return _core.attr_final("cdmg") < 4.0 - 0.000001
		"aspd_pct": return _core.attr_final("aspd") / float(_core.ATTR_BASE["aspd"]) < MAX_ASPD - 0.000001
		"cut_add": return _core.type_field("物理", "red_f") < 0.60 - 0.000001
		"cutall_add":
			for type in _core.DMG_TYPES:
				if type != "真实" and _core.type_field(type, "red_f") < 0.60 - 0.000001:
					return true
			return false
		"pen_flat", "dmgall_add":
			for type in _core.DMG_TYPES:
				if type == "真实": continue
				if key == "pen_flat" and _core.type_effective_field(type, "pen_f") < 0.60 - 0.000001: return true
				if key == "dmgall_add" and _core.type_amp(type) < 2.0 - 0.000001: return true
			return false
		"killheal": return float(_core.kill_heal) < 1.0 - 0.000001
	return true

func _eligible_aug_pool() -> Array:
	return AUG_POOL.filter(func(option): return _aug_has_effect(str(option["key"])))

func _roll_aug() -> void:
	var r := maxi(1, _str_round)
	var mult := 1.0 + 0.4 * float(r - 1)
	var quality := clampi(1 + r, 2, 5)
	var pool := _eligible_aug_pool()
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
			if str(o["key"]) == "crit_add": ac.desc += " · 最高75%"
			if str(o["key"]) == "critdmg_add": ac.desc += " · 最高400%"
			if str(o["key"]) in ["cut_add", "cutall_add"]: ac.desc += " · 各类减伤最高60%"
			if str(o["key"]) == "pen_flat": ac.desc += " · 各系固定穿透最高60%"
			if str(o["key"]) == "dmgall_add": ac.desc += " · 各系最终增幅最高200%"
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
	if _run_over or not _str_pending or _str_layer == null or not _str_layer.visible:
		return
	if _aug_reroll <= 0:
		_toast("刷新次数用完了")
		return
	if not _rr_free():
		_aug_reroll -= 1
	_roll_aug()
	_pop_aug_cards()
	Aud.sfx("ui_click", -8.0)

# 放弃：这一轮进阶不要了，换 1 次刷新（刷新次数是攒着的，下次进阶能用）
func _on_aug_abandon() -> void:
	if _run_over or not _str_pending or _str_layer == null or not _str_layer.visible:
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
	if _run_over or not _str_pending or _str_layer == null or not _str_layer.visible or card == null or not _aug_cards.has(card) or card.o.is_empty():
		return
	_pick_aug(card.o, int(card.oval))

func _pick_aug(o: Dictionary, val: int) -> void:
	if _run_over or not _str_pending:
		return
	if not _aug_has_effect(str(o.get("key", ""))):
		_roll_aug()
		_toast("属性已达上限，已更新进阶候选")
		return
	_str_pending = false
	_choice_fx("aug")
	_apply_aug(str(o["key"]), float(val))
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
#   羁绊的效果**只能是"对应组合的效果增幅"**（用户口径）：
#   凑齐 3 个组合 → 这三套组合以后每次触发的效果 ×(1+boost%)
#   （比如「开门三式」成 → 三锋 每波攻击+1 变 +1.4、铁壁 防御+1 变 +1.4、生机 气血+10 变 +14）
# 卡组的**三大线**（设计稿《困兽_请神与家传卡组_设计稿》§八·八，2026-11-09 定）
const CARD_LINES := {
	"成长线": ["atk", "def", "hp", "mp"],
	"经济线": ["gold", "crystal", "exp", "peril", "bounty"],
	"危途线": ["swarm"],
}

# 系 → 中文名（小羁绊的卡面/详情要用）
const SERIES_CN := {
	"atk": "攻击", "def": "防御", "hp": "气血", "mp": "内力",
	"gold": "文钱", "crystal": "灵晶", "exp": "杀敌数", "peril": "挑战",
	"bounty": "收益", "swarm": "增怪",
}

const BOND_POOL := [
	# ============ 四条羁绊链 ============
	#   每次只从「已解锁」的羁绊里抽三张；结成一条 → 它的下一条入池（跟卡牌的入口卡一个套路）
	#   ① 成长链 ② 经济链 ③ 危途链 ④ 家传链
	{"name": "攻防", "glyph": "攻", "need_series": ["atk", "def"], "boost": 30, "desc": "成长链 · 1", "next": "内视"},
	{"name": "内视", "glyph": "内", "need_series": ["hp", "mp"], "boost": 30, "desc": "成长链 · 2", "next": "血勇"},
	{"name": "血勇", "glyph": "勇", "need_series": ["atk", "hp"], "boost": 30, "desc": "成长链 · 3", "next": "守中"},
	{"name": "守中", "glyph": "守", "need_series": ["def", "mp"], "boost": 30, "desc": "成长链 · 4", "next": "根基"},
	{"name": "根基", "glyph": "根", "line": "成长线", "need": ["三锋", "铁壁", "生机", "凝息"], "boost": 50,
		"lbl": "成长线 +%d%%", "desc": "成长链 · 终 · 攻/防/血/内 四系初阶"},

	{"name": "金银", "glyph": "金", "need_series": ["gold", "crystal"], "boost": 30, "desc": "经济链 · 1", "next": "悬赏"},
	{"name": "悬赏", "glyph": "赏", "need_series": ["exp", "peril"], "boost": 30, "desc": "经济链 · 2", "next": "生财"},
	{"name": "生财", "glyph": "生", "need_series": ["bounty", "gold"], "boost": 30, "desc": "经济链 · 3", "next": "财险"},
	{"name": "财险", "glyph": "险", "need_series": ["peril", "crystal"], "boost": 30, "desc": "经济链 · 4", "next": "名利"},
	{"name": "名利", "glyph": "名", "need_series": ["atk", "gold"], "boost": 30, "desc": "经济链 · 5", "next": "开源"},
	{"name": "开源", "glyph": "源", "line": "经济线", "need": ["聚财", "灵涌", "奋起", "赏金", "进账"], "boost": 50,
		"lbl": "经济线 +%d%%", "desc": "经济链 · 终 · 文钱/灵晶/杀敌/挑战/收益 初阶"},

	{"name": "养战", "glyph": "战", "need_series": ["hp", "swarm"], "boost": 30, "desc": "危途链 · 1", "next": "危途"},
	{"name": "危途", "glyph": "危", "line": "危途线", "need": ["蜂拥", "潮涌", "蜂起", "倾巢"], "boost": 50,
		"lbl": "危途线 +%d%%", "desc": "危途链 · 终 · 增怪四阶全通"},

	{"name": "剑棍同源", "glyph": "剑", "need": ["剑势", "冲撞"], "boost": 40, "lbl": "家传技能 +%d%%",
		"desc": "家传链 · 1 · 主角＋滚地龙", "next": "同气连枝"},
	{"name": "同气连枝", "glyph": "鸾", "need": ["剑势", "飞刃"], "boost": 40, "lbl": "家传技能 +%d%%",
		"desc": "家传链 · 2 · 主角＋苏青鸾", "next": "市井三侠"},
	{"name": "市井三侠", "glyph": "侠", "need": ["手快", "冲撞", "飞刃"], "boost": 30, "lbl": "家传技能 +%d%%",
		"desc": "家传链 · 3 · 小乞儿＋滚地龙＋苏青鸾"},
]

# 每条链的第一条（开局就在池子里）
const BOND_ENTRIES := ["攻防", "金银", "养战", "剑棍同源"]

# ============================================================
# 稀有单卡（不成套、不占羁绊链、拿到即用，效果只做数值）
#   四类：① 巨额灵晶一次性（之后灵晶收入归零）② 文钱换灵晶
#        ③ 限时 buff ④ 直接给资源（文钱 / 灵晶 / 杀敌，小中大）
# ============================================================
const RARE_POOL := [
	# 特殊 3
	{"name": "倾囊", "glyph": "晶", "rare": true, "kind": "crystal_burst", "v": 2000,
		"effect": "灵晶 +2000", "desc": "稀有 · 之后灵晶收入归零"},
	{"name": "折钱", "glyph": "换", "rare": true, "kind": "convert", "v": 10, "cap": 50,
		"effect": "文钱 10:1 换灵晶", "desc": "稀有 · 最多换 50 灵晶"},
	{"name": "狂血", "glyph": "狂", "rare": true, "kind": "buff", "stat": "atk_pct", "v": 60, "dur": 30,
		"effect": "30 秒 攻击 +60%", "desc": "稀有 · 即得即用"},
	# 资源 12（三类 × 四档）
	{"name": "小晶囊", "glyph": "小", "rare": true, "kind": "res", "res": "crystal", "v": 40, "effect": "灵晶 +40", "desc": "稀有 · 灵晶"},
	{"name": "中晶囊", "glyph": "中", "rare": true, "kind": "res", "res": "crystal", "v": 80, "effect": "灵晶 +80", "desc": "稀有 · 灵晶"},
	{"name": "大晶囊", "glyph": "大", "rare": true, "kind": "res", "res": "crystal", "v": 160, "effect": "灵晶 +160", "desc": "稀有 · 灵晶"},
	{"name": "晶山", "glyph": "山", "rare": true, "kind": "res", "res": "crystal", "v": 320, "effect": "灵晶 +320", "desc": "稀有 · 灵晶"},
	{"name": "小钱袋", "glyph": "小", "rare": true, "kind": "res", "res": "wen", "v": 500, "effect": "文钱 +500", "desc": "稀有 · 文钱"},
	{"name": "中钱袋", "glyph": "中", "rare": true, "kind": "res", "res": "wen", "v": 1000, "effect": "文钱 +1000", "desc": "稀有 · 文钱"},
	{"name": "大钱袋", "glyph": "大", "rare": true, "kind": "res", "res": "wen", "v": 2000, "effect": "文钱 +2000", "desc": "稀有 · 文钱"},
	{"name": "金库", "glyph": "库", "rare": true, "kind": "res", "res": "wen", "v": 4000, "effect": "文钱 +4000", "desc": "稀有 · 文钱"},
	{"name": "小杀令", "glyph": "小", "rare": true, "kind": "res", "res": "kill", "v": 60, "effect": "杀敌 +60", "desc": "稀有 · 杀敌"},
	{"name": "中杀令", "glyph": "中", "rare": true, "kind": "res", "res": "kill", "v": 120, "effect": "杀敌 +120", "desc": "稀有 · 杀敌"},
	{"name": "大杀令", "glyph": "大", "rare": true, "kind": "res", "res": "kill", "v": 240, "effect": "杀敌 +240", "desc": "稀有 · 杀敌"},
	{"name": "屠戮令", "glyph": "屠", "rare": true, "kind": "res", "res": "kill", "v": 480, "effect": "杀敌 +480", "desc": "稀有 · 杀敌"},
	# 混合 2
	{"name": "双收", "glyph": "双", "rare": true, "kind": "mix", "wen": 1000, "crystal": 80,
		"effect": "文钱 +1000 · 灵晶 +80", "desc": "稀有 · 混合"},
	{"name": "丰年", "glyph": "丰", "rare": true, "kind": "mix", "wen": 1500, "crystal": 120, "kill": 120,
		"effect": "钱+1500 · 晶+120 · 杀+120", "desc": "稀有 · 混合"},
]


# 稀有单卡出现概率（每一手三张里）
const RARE_CHANCE := 0.30

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
	_breathe(ban)
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
	if not LevelState.show_button("treasure"):
		return
	if _trea_pending:
		_open_trea()
		return
	if _trea_charge <= 0:
		_toast("还没攒到宝物机会（每清一波 +1）")
		return
	if _bond_pool().is_empty() and _rare_pool().is_empty():
		_toast("本局宝物已抽空")
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
	_layer_in(_trea_layer)
	_trea_layer.move_to_front()
	_pop_trea_cards()
	Aud.sfx("ui_open", -8.0)

# 现在能抽到的羁绊：已解锁 且 还没结过
func _bond_pool() -> Array:
	var out: Array = []
	for e_v in BOND_POOL:
		var e: Dictionary = e_v
		var nm := str(e["name"])
		if bool(_bond_unlocked.get(nm, false)) and not _bond_taken.has(nm):
			out.append(e)
	return out

# 稀有单卡池：抽到过的（唯一）不再出现
func _rare_pool() -> Array:
	var out: Array = []
	for e_v in RARE_POOL:
		var e: Dictionary = e_v
		if not _rare_taken.has(str(e["name"])):
			out.append(e)
	return out

func _roll_trea() -> void:
	var q := _trea_quality()
	var mult: float = [1.0, 1.5, 2.0, 3.0][clampi(q - 2, 0, 3)]
	var bp: Array = _bond_pool()
	var rp: Array = _rare_pool()
	# 杀敌/经验相关羁绊优先：悬赏、开源（经济链终）以及描述里带杀敌的
	var kill_bonds: Array = []
	var other_bonds: Array = []
	for b_v in bp:
		var b: Dictionary = b_v
		var is_kill := false
		for s_v in (b.get("need_series", []) as Array):
			if str(s_v) == "exp":
				is_kill = true
		var bn := str(b.get("name", ""))
		if bn in ["悬赏", "开源"] or str(b.get("desc", "")).contains("杀敌"):
			is_kill = true
		if is_kill:
			kill_bonds.append(b)
		else:
			other_bonds.append(b)
	bp = kill_bonds + other_bonds
	bp.shuffle()
	rp.shuffle()
	var picks: Array = []
	var used := {}
	for e_v in bp:
		if picks.size() >= _trea_cards.size():
			break
		var e: Dictionary = e_v
		if used.has(str(e["name"])):
			continue
		used[str(e["name"])] = true
		picks.append(e)
	# 稀有单卡：30% 概率塞一张（有空位就补位，没空位就随机顶掉一张）
	if not rp.is_empty() and randf() < RARE_CHANCE:
		var r: Dictionary = rp[0]
		if picks.size() < _trea_cards.size():
			picks.append(r)
		else:
			picks[randi() % picks.size()] = r
		used[str(r["name"])] = true
	# 两池兜底：羁绊不够三张就继续用稀有补；同名不重复
	for e_v2 in rp:
		if picks.size() >= _trea_cards.size():
			break
		var e2: Dictionary = e_v2
		if used.has(str(e2["name"])):
			continue
		used[str(e2["name"])] = true
		picks.append(e2)
	for i in _trea_cards.size():
		var c: AugCard = _trea_cards[i]
		var o: Dictionary = picks[i] if i < picks.size() else {}
		if o.is_empty():
			c.visible = false
			c.queue_redraw()
			continue
		c.o = o
		c.title = str(o["name"])
		c.glyph = str(o["glyph"])
		if bool(o.get("rare", false)):
			# 稀有单卡：数值固定，不吃品质
			c.oval = int(o.get("v", 0))
			c.effect = str(o.get("effect", ""))
			c.desc = str(o.get("desc", "稀有单卡"))
			c.quality = 5
		else:
			c.oval = int(round(float(o["boost"]) * mult))
			if o.has("need_series"):
				c.effect = "组合效果 +%d%%" % int(c.oval)
				c.desc = "需合成 " + _series_pair_cn(o) + "（任意一阶）"
			else:
				c.effect = str(o.get("lbl", "组合效果 +%d%%")) % int(c.oval)
				c.desc = "需合成 " + "·".join(PackedStringArray(o["need"]))
			c.quality = q
		c.visible = true
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.queue_redraw()
	_refresh_trea_btn()

# 灵晶一切收入的唯一入口（「倾囊」把 _crystal_lock 打开后，这里就再也不给）
func _gain_crystal(n: int) -> void:
	if n <= 0 or _crystal_lock:
		return
	_crystal += n
	_update_crystal()
	_pulse_chip(_crystal_lb)
	_spawn_fly(_hero_screen() + Vector2(0, -30), Vector2(273, 40), Color(0.52, 0.78, 0.88), 2)

# 稀有单卡：拿到当场结算，不进羁绊
func _apply_rare(o: Dictionary) -> void:
	var kind := str(o.get("kind", "res"))
	var v := int(o.get("v", 0))
	match kind:
		"crystal_burst":
			_gain_crystal(v)                 # 先给，再上锁
			_crystal_lock = true
			_update_crystal()
			_toast("稀有 · 灵晶 +%d，此后灵晶不再增加" % v)
		"convert":
			if _crystal_lock:
				_toast("灵晶已锁，换不了")
				return
			var rate := maxi(1, v)
			var cap := int(o.get("cap", 50))
			var spend := mini(_wen, rate * cap)
			var got := int(spend / rate)
			if got <= 0:
				_toast("文钱不够，换不了")
				return
			_wen -= spend
			if _coin_lb != null:
				_coin_lb.text = str(_wen)
			_crystal += got
			_update_crystal()
			_toast("稀有 · %d 文钱换 %d 灵晶" % [spend, got])
		"buff":
			_apply_rare_buff(o)
		"mix":
			_add_wen(int(o.get("wen", 0)))
			_gain_crystal(int(o.get("crystal", 0)))
			var kk := int(o.get("kill", 0))
			if kk > 0:
				_kills += kk
				if _kill_lb != null:
					_kill_lb.text = str(_kills)
				_add_exp(20 * kk)
			_toast("稀有 · " + str(o.get("effect", "")))
		_:
			match str(o.get("res", "")):
				"wen":
					_add_wen(v)
				"crystal":
					_gain_crystal(v)
				"kill":
					_kills += v
					if _kill_lb != null:
						_kill_lb.text = str(_kills)
					_add_exp(20 * v)
			_toast("稀有 · " + str(o.get("effect", "")))
	Aud.sfx("levelup", -4.0)
	_refresh_trea_tile()
	_refresh_str_tile()

# 限时 buff：先加一份固定的攻击，到点再把这同一份减掉（不吃后续变化的账）
func _apply_rare_buff(o: Dictionary) -> void:
	if _core == null:
		return
	var pct := float(o.get("v", 0)) / 100.0
	var dur := float(o.get("dur", 30))
	var h: Dictionary = _core.hero
	var add := float(h.get("atk", 0.0)) * pct
	h["atk"] = float(h.get("atk", 0.0)) + add
	if _core != null:
		_core.attr_add("atk", add)
	_rare_buffs.append({"amount": add, "t": dur})
	_toast("稀有 · 攻击 +%d%%（%d 秒）" % [int(o.get("v", 0)), int(dur)])

func _tick_rare_buffs(dt: float) -> void:
	if _rare_buffs.is_empty() or _core == null:
		return
	for i in range(_rare_buffs.size() - 1, -1, -1):
		var rb: Dictionary = _rare_buffs[i]
		rb["t"] = float(rb["t"]) - dt
		if float(rb["t"]) <= 0.0:
			_core.hero["atk"] = maxf(1.0, float(_core.hero.get("atk", 0.0)) - float(rb["amount"]))
			_core.attr_add("atk", -float(rb["amount"]))
			_rare_buffs.remove_at(i)

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
	if _run_over or not _trea_pending or _trea_layer == null or not _trea_layer.visible or card == null or card.o.is_empty():
		return
	_choice_fx("rare" if bool(card.o.get("rare", false)) else "trea")
	_pick_trea(card.o, int(card.oval))

func _pick_trea(o: Dictionary, val: int, close_hand := true) -> void:
	if _run_over or o.is_empty() or _rare_taken.has(str(o.get("name", ""))) or _bond_taken.has(str(o.get("name", ""))):
		return
	if close_hand:
		_trea_pending = false
		_hide_trea()
	if bool(o.get("rare", false)):
		_rare_taken[str(o["name"])] = true        # 稀有单卡也是唯一，拿过不再出
		_qc("trea", 1)
		_apply_rare(o)
		return
	var b := {"name": str(o["name"]), "boost": int(val), "prog": 0,
		"lbl": str(o.get("lbl", "组合效果 +%d%%")),
		"glyph": str(o.get("glyph", "羁")), "quality": _trea_quality()}
	if o.has("need_series"):
		b["need_series"] = (o["need_series"] as Array).duplicate()   # 小羁绊：按系算，任一一阶都行
	else:
		b["need"] = (o["need"] as Array).duplicate()
	if o.has("line"):
		b["line"] = str(o["line"])          # 线羁绊：成后抬整条线，不只是需求里那几个
	_bonds.append(b)
	_bond_taken[str(o["name"])] = true
	_qc("trea", 1)
	if o.has("next"):
		var nx := str(o["next"])
		if not bool(_bond_unlocked.get(nx, false)):
			_bond_unlocked[nx] = true
			_toast("羁绊「%s」解锁入池" % nx)
	_toast("结成羁绊 · %s（%d/%d，凑齐即消耗）" % [str(o["name"]), _bond_prog(b), _bond_need_n(b)])
	Aud.sfx("levelup", -6.0)
	_bond_check()
	_refresh_trea_tile()

# ---- 羁绊结算 ----
func _grant_random_treasure() -> bool:
	var shown := {}
	if _trea_pending:
		for card in _trea_cards:
			if card.visible and not card.o.is_empty():
				shown[str(card.o.get("name", ""))] = true
	var bonds: Array = _bond_pool().filter(func(o): return not shown.has(str(o["name"])))
	# 自动奖励不能替玩家选择花钱兑换或永久关闭灵晶收入的代价卡。
	var rares: Array = _rare_pool().filter(func(o):
		return not shown.has(str(o["name"])) and str(o.get("kind", "")) not in ["convert", "crystal_burst"] and not (_crystal_lock and str(o.get("kind", "")) == "res" and str(o.get("res", "")) == "crystal"))
	var pool: Array = rares if not rares.is_empty() and (bonds.is_empty() or randf() < RARE_CHANCE) else bonds
	if pool.is_empty():
		return false
	var item: Dictionary = pool[randi() % pool.size()]
	var multiplier: float = [1.0, 1.5, 2.0, 3.0][clampi(_trea_quality() - 2, 0, 3)]
	var value := int(item.get("v", 0)) if bool(item.get("rare", false)) else int(round(float(item["boost"]) * multiplier))
	_pick_trea(item, value, false)
	_toast("镇魂铃 · 获得宝物「%s」" % str(item["name"]))
	return true

func _combo_has(nm: String) -> bool:
	# ⚠ 回春 / 生息 这两个名字两边都有：普通卡优先，命中普通卡名单就只认 _combined
	var sys_first: bool = _sys_combos.has(nm)
	for r_v in _combined:
		if str((r_v as Dictionary).get("name", "")) == nm:
			return true
	if sys_first:
		return false
	for r_v in _ancestor_combos:
		if str((r_v as Dictionary).get("name", "")) == nm:
			return true
	return false

# 这个组合名是不是某位祖宗的家传组合？是就返回祖宗 id（柳卿卿有两套，取第一套对上就行）
func _ancestor_of_combo(nm: String) -> String:
	for aid_v in AncestorData.ANCESTORS.keys():
		var aid := str(aid_v)
		var a: Dictionary = AncestorData.ANCESTORS[aid]
		for t_v in a.get("tiers", []):
			if str((t_v as Dictionary).get("combo_name", "")) == nm:
				return aid
	return ""

# "气血·内力" / "文钱·灵晶"
func _series_pair_cn(d: Dictionary) -> String:
	var out: Array = []
	for sk_v in d.get("need_series", []):
		out.append(str(SERIES_CN.get(str(sk_v), str(sk_v))))
	return "·".join(PackedStringArray(out))

func _bond_prog(b: Dictionary) -> int:
	var n := 0
	if b.has("need_series"):
		for sk_v in b["need_series"]:
			if _series_active(str(sk_v)):
				n += 1
		return n
	for nm_v in b["need"]:
		if _combo_has(str(nm_v)):
			n += 1
	return n

# 这个系有没有合成过**任意一阶**组合（小羁绊按"系"算，不挑具体是哪一阶）
func _series_active(sk: String) -> bool:
	for r_v in _combined:
		if str((r_v as Dictionary).get("series", "")) == sk:
			return true
	return false

# 这张羁绊要几条（线/小羁绊按系，其它按组合名）
func _bond_need_n(b: Dictionary) -> int:
	if b.has("need_series"):
		return (b["need_series"] as Array).size()
	return (b["need"] as Array).size()

# 该系四阶组合一起抬
func _boost_series(sk: String, pct: float) -> void:
	for tt in 4:
		var cc: Dictionary = _card_db.get("%s_%d_0" % [sk, tt], {})
		var cn := str(cc.get("combo_name", ""))
		if cn != "":
			_combo_boost[cn] = float(_combo_boost.get(cn, 0.0)) + pct

# 每次组合激活后都算一遍：凑齐 → 生效并**消耗**这张羁绊
func _bond_check() -> void:
	if _bonds.is_empty():
		return
	var changed := false
	for i in range(_bonds.size() - 1, -1, -1):
		var b: Dictionary = _bonds[i]
		var need: Array = b.get("need", [])
		var prog := _bond_prog(b)
		b["prog"] = prog
		if prog >= _bond_need_n(b):
			# 羁绊成 → 它点名的组合全部增幅，永久：
			#   普通卡组合：以后每次触发 ×(1+boost%)（_apply_combo 里乘）
			#   家传组合：那位祖宗的本命技伤害直接 +boost%（跟家传组合自己那套账同一个 _anc_mod.dmg_pct）
			var pct := float(b.get("boost", 0)) / 100.0
			if b.has("need_series"):
				# 小羁绊：点名的那两个系，四阶组合一起抬
				for sk_v in (b["need_series"] as Array):
					_boost_series(str(sk_v), pct)
			elif b.has("line"):
				# 线羁绊：这条线**所有系、所有阶**的组合一起抬（不止需求里那几个）
				for sk_v in (CARD_LINES.get(str(b["line"]), []) as Array):
					_boost_series(str(sk_v), pct)
			for nm2_v in need:
				var nm2 := str(nm2_v)
				var aid2 := "" if _sys_combos.has(nm2) else _ancestor_of_combo(nm2)
				if aid2 != "":
					if not _anc_mod.has(aid2):
						_anc_mod[aid2] = {"dmg_pct": 0.0, "cd_pct": 0.0, "mp_flat": 0.0, "para_s": 0.0, "para_amp": 0.0,
							"life_flat": 0.0, "cap_add": 0.0, "wave_evo": 0.0, "tgt_add": 0.0,
							"ignite_add": 0.0, "burn_add": 0.0}
					_anc_mod[aid2]["dmg_pct"] = float(_anc_mod[aid2].get("dmg_pct", 0.0)) + pct * 100.0
				elif not b.has("line") and not b.has("need_series"):
					_combo_boost[nm2] = float(_combo_boost.get(nm2, 0.0)) + pct
			_bonds.remove_at(i)
			_bonds_done += 1
			if b.has("line"):
				_toast("羁绊成 · %s（%s 全部组合 +%d%%）" % [str(b["name"]), str(b["line"]), int(b.get("boost", 0))])
			elif b.has("need_series"):
				_toast("羁绊成 · %s（%s 全部组合 +%d%%）" % [str(b["name"]), _series_pair_cn(b), int(b.get("boost", 0))])
			else:
				_toast("羁绊成 · %s（%s 效果 +%d%%）" % [str(b["name"]),
					"·".join(PackedStringArray(need)), int(b.get("boost", 0))])
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
	if _run_over or not _trea_pending or _trea_layer == null or not _trea_layer.visible:
		return
	if _trea_reroll <= 0:
		_toast("刷新次数用完了")
		return
	if not _rr_free():
		_trea_reroll -= 1
	_roll_trea()
	_pop_trea_cards()
	Aud.sfx("ui_click", -8.0)

# 放弃：这一手不要了，换 1 次刷新（机会已经被这次开页吃掉，不能白刷）
func _on_trea_abandon() -> void:
	if _run_over or not _trea_pending or _trea_layer == null or not _trea_layer.visible:
		return
	_trea_pending = false
	_trea_reroll += 1
	_hide_trea()
	_refresh_trea_tile()
	_refresh_trea_btn()
	_toast("放弃宝物 · 刷新 +1（现有 %d 次）" % _trea_reroll)
	Aud.sfx("ui_back", -8.0)

# 顶栏［总计］：打开总计页（顶部三个分类钮：卡组 / 宝物 / 组合）
# 整层入场：淡入 + 从 0.965 弹回（比"啪地出现"顺滑）
func _layer_in(c) -> void:
	if c == null:
		return
	c.pivot_offset = Vector2(360, 640)
	c.scale = Vector2(0.965, 0.965)
	c.modulate.a = 0.0
	var tw := create_tween().bind_node(c)
	tw.set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.15)
	tw.tween_property(c, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_totals() -> void:
	if _combined_layer == null:
		return
	_combined_layer.visible = true
	_combined_layer.move_to_front()
	_layer_in(_combined_layer)
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
	if _tot_bond_root == null:
		return
	_tot_bond_root.visible = k == "bond"
	_combined_icons.visible = k == "combo"
	_combined_detail.visible = false
	if k == "bond":
		_refresh_tot_bond()
	else:
		_refresh_combined()

# 卡组分页：这一局抽到的卡
# 宝物分页：羁绊图标墙（点图标才看详情）
func _refresh_tot_bond() -> void:
	for ch in _tot_bond_root.get_children():
		ch.queue_free()
	_lbl("羁绊 %d 张（已成 %d）　·　已解锁 %d/%d　·　点图标看详情" % [_bonds.size(), _bonds_done, _bond_unlocked.size(), BOND_POOL.size()],
		Vector2(0, 0), Vector2(600, 26), 16, DIM, _tot_bond_root)
	if _bonds.is_empty():
		_lbl("还没有羁绊 —— 每清一波有 1 次宝物机会", Vector2(0, 40), Vector2(600, 30), 20,
			Color(0.55, 0.48, 0.36), _tot_bond_root)
		return
	for i in mini(_bonds.size(), 12):
		var b: Dictionary = _bonds[i]
		var ic := BondIcon.new()
		ic.position = Vector2(float(i % 4) * 146.0, 40.0 + float(i / 4) * 152.0)
		ic.size = Vector2(132, 132)
		ic.title = str(b["name"])
		ic.glyph = str(b.get("glyph", "羁"))
		ic.quality = int(b.get("quality", 2))
		ic.prog = _bond_prog(b)
		ic.need_n = _bond_need_n(b)
		ic.pressed.connect(func() -> void: _show_bond_detail(b))
		_tot_bond_root.add_child(ic)

func _show_bond_detail(b: Dictionary) -> void:
	for ch in _combined_detail.get_children():
		ch.queue_free()
	_combined_detail.visible = true
	var p := Panel.new()
	p.position = Vector2(140, 300)
	p.size = Vector2(440, 392)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.85, 0.99)
	sb.set_corner_radius_all(9)
	sb.border_color = QUALITY_COLORS[clampi(int(b.get("quality", 2)) - 1, 0, 4)]
	sb.set_border_width_all(7)
	p.add_theme_stylebox_override("panel", sb)
	_combined_detail.add_child(p)
	var need: Array = b.get("need", [])
	_lbl(str(b["name"]), Vector2(170, 322), Vector2(360, 40), 30, INK, _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl("羁 绊　%d/%d" % [_bond_prog(b), _bond_need_n(b)], Vector2(170, 366), Vector2(360, 28), 19,
		Color(0.46, 0.20, 0.10), _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	if b.has("need_series"):
		_lbl("成后：" + _series_pair_cn(b) + " 全部组合 +%d%%" % int(b.get("boost", 0)), Vector2(170, 402), Vector2(380, 32), 20, INK, _combined_detail)
	else:
		_lbl("成后：" + str(b.get("lbl", "组合效果 +%d%%")) % int(b.get("boost", 0)), Vector2(170, 402), Vector2(380, 32), 21, INK, _combined_detail)
	if b.has("line"):
		_lbl("（整条线不分阶，全部吃这个增幅）", Vector2(170, 424), Vector2(380, 24), 15, Color(0.46, 0.20, 0.10), _combined_detail)
	elif b.has("need_series"):
		_lbl("（每个系任意一阶组合都算）", Vector2(170, 424), Vector2(380, 24), 15, Color(0.46, 0.20, 0.10), _combined_detail)
	_lbl("要凑齐的组合（每套 3 张同套卡合成）：" if not b.has("need_series") else "要凑齐的系（任一一阶组合即可）：",
		Vector2(170, 442), Vector2(380, 26), 16, DIM, _combined_detail)
	var y := 472.0
	if b.has("need_series"):
		for sk_v in b["need_series"]:
			var sk := str(sk_v)
			var ok2 := _series_active(sk)
			_lbl(("已合成　" if ok2 else "还缺　　") + str(SERIES_CN.get(sk, sk)) + " 系任意一套", Vector2(184, y), Vector2(360, 26), 18,
				Color(0.28, 0.44, 0.26) if ok2 else Color(0.56, 0.40, 0.26), _combined_detail)
			y += 30.0
	else:
		for nm_v in need:
			var nm := str(nm_v)
			var ok := _combo_has(nm)
			_lbl(("已合成　" if ok else "还缺　　") + nm, Vector2(184, y), Vector2(360, 26), 18,
				Color(0.28, 0.44, 0.26) if ok else Color(0.56, 0.40, 0.26), _combined_detail)
			y += 30.0
	_btn("×", Rect2(592, 302, 34, 30), 20, Color(0.97, 0.93, 0.85), DIM,
		func(): _combined_detail.visible = false, _combined_detail)

# 羁绊图标：品阶描边 + 墨字圆章 + 右上进度角标
class BondIcon extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal pressed
	var title := ""
	var glyph := "羁"
	var quality := 2
	var prog := 0
	var need_n := 3
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var q := clampi(quality - 1, 0, 4)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.93, 0.86, 0.98)
		sb.set_corner_radius_all(8)
		sb.border_color = QC[q]
		sb.set_border_width_all(5)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c := Vector2(size.x * 0.5, size.y * 0.38)
		var r := size.x * 0.24
		draw_circle(c, r, Color(0.93, 0.90, 0.82))
		draw_arc(c, r, 0.0, TAU, 40, QC[q], 2.0)
		draw_string(F, c + Vector2(-r * 0.40, r * 0.42), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(size.x * 0.28), Color(0.14, 0.11, 0.08))
		draw_string(F, Vector2(2, size.y - 12), title, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, 16,
			Color(0.20, 0.16, 0.12))
		var done := prog >= need_n
		draw_rect(Rect2(size.x - 46, 6, 40, 20), Color(0.30, 0.44, 0.26) if done else Color(0.62, 0.42, 0.14))
		draw_string(F, Vector2(size.x - 46, 22), "%d/%d" % [prog, need_n], HORIZONTAL_ALIGNMENT_CENTER,
			40, 14, Color(0.98, 0.96, 0.90))
		draw_rect(Rect2(6, 6, 22, 20), Color(0.64, 0.22, 0.15))
		draw_string(F, Vector2(6, 22), "羁", HORIZONTAL_ALIGNMENT_CENTER, 22, 14, Color(0.98, 0.92, 0.78))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

func _apply_aug(key: String, val: float) -> void:
	if _core == null:
		return
	var h: Dictionary = _core.hero
	match key:
		"atk_pct":
			_core.attr_add_amp("atk", val / 100.0)
			h["atk"] = _core.attr_final("atk")
		"hp_pct":
			var ratio := 1.0
			if float(h["hp_max"]) > 0.0:
				ratio = clampf(float(h["hp"]) / float(h["hp_max"]), 0.0, 1.0)
			_core.attr_add_amp("hp", val / 100.0)
			h["hp_max"] = _core.attr_final("hp")
			h["hp"] = float(h["hp_max"]) * ratio
		"aspd_pct":
			_core.attr_add_amp("aspd", val / 100.0)
			h["aspd"] = minf(MAX_ASPD, _core.attr_final("aspd") / float(_core.ATTR_BASE["aspd"]))
		"crit_add":
			_core.attr_add("crit", val / 100.0)
			h["crit"] = _core.attr_final("crit")
		"critdmg_add":
			_core.attr_add("cdmg", val / 100.0)
			h["crit_dmg"] = _core.attr_final("cdmg")
		"cut_add":
			_core.type_add("物理", "red_f", val / 100.0)
			h["cut"] = _core.type_effective_field("物理", "red_f")
		"cutall_add":
			for t in _core.DMG_TYPES:
				if t != "真实":
					_core.type_add(t, "red_f", val / 100.0)
			h["cut"] = _core.type_effective_field("物理", "red_f")
			h["cut_all"] = 0.0 # 六系字段已包含这次增益。
		"pen_flat":
			# v6：七系固定穿透一起加（真实不吃穿透，跳过）
			for t in _core.DMG_TYPES:
				if t != "真实":
					_core.type_add(t, "pen_f", val / 100.0)
		"dmgall_add":
			for t in _core.DMG_TYPES:
				if t != "真实":
					_core.type_add(t, "amp_f", val / 100.0)
			h["dmg_all"] = _core.type_amp("物理")
		"mp_add":
			_core.attr_add("mp", val)
			_mp_max = maxf(1.0, _core.attr_final("mp"))
			_mp = minf(_mp, _mp_max)
			h["mp_max"] = _mp_max
			h["mp"] = _mp
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
		draw_string(F, Vector2(0, 52), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28 if title.length() <= 3 else 24, Color(0.14, 0.11, 0.08))
		# 图标缩小，给底部说明腾出更大字号的空间
		var c := Vector2(size.x * 0.5, 134.0)
		draw_circle(c, 38, Color(0.93, 0.90, 0.82))
		draw_arc(c, 38.0, 0.0, TAU, 48, QC[q], 2.0)
		draw_string(F, c + Vector2(-11, 12), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.13, 0.12, 0.11))
		draw_string(F, Vector2(0, 214), effect, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(0.46, 0.20, 0.10))
		draw_multiline_string(F, Vector2(10, 244), desc, HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 17, 2, Color(0.38, 0.33, 0.26))
		draw_string(F, Vector2(0, 292), "点击选取", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(0.58, 0.50, 0.36))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()

func _make_foe_token(f: Dictionary):
	var kind := str(f.get("kind", "normal"))
	var boss := bool(f.get("boss", false))
	var rad := 52.0 if boss else 26.0        # Boss 圆牌明显更大
	var ring := Color(0.42, 0.36, 0.28)
	if kind == "coin":
		ring = Color(0.95, 0.78, 0.25)        # 钱怪：亮金
	elif kind == "crystal":
		ring = Color(0.42, 0.72, 0.95)        # 晶怪：亮蓝
	elif kind == "chal":
		ring = Color(0.68, 0.38, 0.88)        # 挑战怪：紫
	elif boss:
		ring = Color(0.95, 0.62, 0.12)        # Boss：金橙
	var mark_ch := "王" if boss else ("钱" if kind == "coin" else ("晶" if kind == "crystal" else ("挑" if kind == "chal" else "怪")))
	var msize := 22 if not boss else 38
	# 池里有就复用（TokenActor 每建一个都要 new Shader/ShaderMaterial，很贵）
	if not _foe_pool.is_empty():
		var tk0 = _foe_pool.pop_back()
		tk0.reset_pose()
		tk0.setup(null, rad, ring, false)
		if is_instance_valid(tk0._sprite):
			tk0._sprite.position = Vector2(0.0, -rad)
		tk0.show_bar = true
		tk0.bar_w = 84.0 if boss else 54.0
		tk0.unit_name = str(f.get("name", ""))
		tk0.position = _core.position + Vector2(float(f["x"]), float(f["y"]))
		tk0.visible = true
		var mk: Label = tk0.get_meta("mark", null)
		if mk != null:
			mk.text = mark_ch
			mk.position = Vector2(-rad, -rad * 2.0 + 6.0)
			mk.size = Vector2(rad * 2.0, rad * 1.5)
			mk.add_theme_font_size_override("font_size", msize)
		tk0.queue_redraw()
		return tk0
	var tk = TokenActor.new()
	tk.setup(null, rad, ring, false)
	tk.show_bar = true
	tk.bar_w = 84.0 if boss else 54.0
	tk.unit_name = str(f.get("name", ""))
	tk.z_index = 5
	tk.position = _core.position + Vector2(float(f["x"]), float(f["y"]))
	var mark := Label.new()
	mark.text = mark_ch
	mark.position = Vector2(-rad, -rad * 2.0 + 6.0)
	mark.size = Vector2(rad * 2.0, rad * 1.5)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_override("font", FONT)
	mark.add_theme_font_size_override("font_size", msize)
	mark.add_theme_color_override("font_color", Color(0.30, 0.24, 0.16))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tk.add_child(mark)
	tk.set_meta("mark", mark)
	_cam.add_child(tk)
	return tk

# ---------------- 卡池 / 组合 ----------------
func _init_cards() -> void:
	var d: Dictionary = CardData.build()
	_card_db = d["cards"]
	_set_cards = d["sets"]
	# ⚠ 普通卡组合与家传组合有重名（回春 / 生息），先记下普通卡这一批名字，
	#   羁绊结算时优先按普通卡算，别认成某位祖宗的家传组合
	_sys_combos.clear()
	for sid_v in _set_cards.keys():
		var ids0: Array = _set_cards[sid_v]
		if ids0.is_empty():
			continue
		var c0: Dictionary = _card_db.get(str(ids0[0]), {})
		if not c0.is_empty() and not c0.has("ancestor"):
			_sys_combos[str(c0.get("combo_name", ""))] = true
	_pool = []
	for id_v in d["entries"]:
		if LevelState.card_allowed(str(id_v)):
			_pool.append(id_v)
	if GameState.new_cards_unlocked:
		var ng: Dictionary = CardData.new_group()
		var ng_cards: Dictionary = ng.get("cards", {})
		for cid_v in ng_cards.keys():
			_card_db[str(cid_v)] = ng_cards[cid_v]
		for id_v in ng.get("entries", []):
			_pool.append(id_v)
	_cards.clear()
	_acquired.clear()
	_combined.clear()
	_ancestors.clear()
	_ancestor_combos.clear()
	# 家传卡：并进同一套卡表（形状与普通卡一致，所以直接合并）
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
	_devoured.clear()
	_combo_boost.clear()
	_combo_frac.clear()
	_bond_unlocked.clear()
	_bond_taken.clear()
	_crystal_lock = false
	_rare_buffs.clear()
	_rare_taken.clear()
	_curio_cd = 0.0
	_curio_uses = 0
	_run_over = false
	_run_time = 0.0
	for nm_v in BOND_ENTRIES:
		_bond_unlocked[str(nm_v)] = true
	_anc_mod.clear()
	_elem_mod.clear()
	_shiny_rolled.clear()
	_shiny_used.clear()
	# 主角默认解锁，但家传卡是「请神」层的东西：第 5 关才开始进池
	if LevelState.has_feature("ancestor"):
		_grant_ancestor("zhujue")

# 请到一位祖宗：把它的「初级入口卡」放进抽卡池
func _family_card_allowed(id: String) -> bool:
	var card: Dictionary = _card_db.get(id, {})
	if card.is_empty():
		return false
	if not card.has("ancestor") or bool(card.get("shiny", false)):
		return true
	return GameState.family_tier_allowed(str(card["ancestor"]), int(card.get("tier", -1)))

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

# 家传组合激活：不做普通卡那套属性结算，只登记 + 解锁下一档入口
func _activate_ancestor_set(sid: String, first: Dictionary, ids: Array) -> void:
	var srcs: Array = []
	for cid_v in ids:
		var cid := str(cid_v)
		srcs.append(str((_card_db[cid] as Dictionary)["name"]))
		_cards.erase(cid)
	var ai := str(first["ancestor"])
	var t := int(first["tier"])
	var arc := {"ancestor": ai, "tier": t, "sources": srcs,
		"name": str(first["combo_name"]), "text": str(first["combo_text"])}
	var cid0 := "%s_t%d_0" % [ai, t]
	if _card_db.has(cid0):
		var c0: Dictionary = _card_db[cid0]
		arc["art"] = str(c0.get("art", ""))
		arc["quality"] = int(c0.get("quality", 2))
	_ancestor_combos.append(arc)
	# 家传组合也播三合一动画
	_play_merge_fx(arc)
	if LevelState.current_level == 5 and _ancestor_combos.size() == 2 and not _family_shiny_done:
		_family_shiny_ready = true   # 第五关是请神引导：第二组家传后必出一张炫彩
	_add_ancestor_effects(ai, first.get("effects", {}))
	if ai == "zhujue":
		_apply_hero_passive(first.get("effects", {}))
	_toast_card(str(first["combo_name"]), int(first["quality"]),
		"%s · %s（%d 张已清空）" % [str(first["ancestor_name"]), str(first["combo_text"]), ids.size()])
	var nid := "%s_t%d_0" % [ai, t + 1]
	if _card_db.has(nid) and _family_card_allowed(nid) and not _pool.has(nid) and not _acquired.has(nid):
		_pool.append(nid)
		_toast_card(str((_card_db[nid] as Dictionary)["name"]), int(first["quality"]), "下一档入口已入池")
	elif _card_db.has(nid) and not _family_card_allowed(nid):
		_toast("下一档家传需 %d 星，请在局外进阶" % (t + 1))
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
	if LevelState.current_level == 1:
		raw = int(round(float(raw) * 1.8))   # 第一关文钱加速：10 级进阶要 840，两波内攒得出来

	_pulse_chip(_coin_lb)
	if raw <= 0:
		return
	_wen += int(round(float(raw) * (1.0 + _gold_pct / 100.0)))
	if _coin_lb != null:
		_coin_lb.text = str(_wen)
	_refresh_str_tile()

# core 的 coin_drop：钱怪 / 匪首 / boss 掉的真钱（带落点，先只记账）
func _on_coin_drop(amount: int, pos: Vector2) -> void:
	_add_wen(amount)
	_spawn_fly(_core.position + pos + Vector2(0, -18), Vector2(99, 40), Color(0.90, 0.71, 0.30), 3)

# 撒一把飞向資源条的小点（金币金、灵晶蓝）
func _spawn_fly(from: Vector2, to: Vector2, col: Color, n: int) -> void:
	for i in n:
		if _fly.size() > 60:
			break
		_fly.append({"sx": from.x + randf_range(-16.0, 16.0), "sy": from.y + randf_range(-12.0, 12.0),
			"x": from.x, "y": from.y,
			"tx": to.x + randf_range(-18.0, 18.0), "ty": to.y + randf_range(-8.0, 8.0),
			"t": randf_range(0.0, 0.12), "col": col, "r": randf_range(4.5, 7.0)})

# 整屏微闪（技能释放/大事件用）：暖纸色一闪，不刺眼
# 镜头推进（缩放战场内容，不动 HUD）
# 收尾镜头：推近 → 停一下 → 退回
func _cam_pulse(s: float, hold: float) -> void:
	if _cam == null:
		return
	_cam_zoom_to(s, 0.26)
	var tw := create_tween().bind_node(_cam)
	tw.tween_interval(hold)
	tw.tween_property(_cam, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _cam_zoom_to(s: float, dur: float) -> void:
	if _cam == null:
		return
	var tw := create_tween().bind_node(_cam)
	tw.tween_property(_cam, "scale", Vector2(s, s), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _screen_flash(col: Color, a: float, dur := 0.16) -> void:
	if _flash_rect == null:
		return
	_flash_rect.color = Color(col.r, col.g, col.b, a)
	var tw := create_tween().bind_node(_flash_rect)
	tw.tween_property(_flash_rect, "color:a", 0.0, dur)

# 技能释放的整体反馈：微闪 + 轻震 + 顿帧
# 每系一个闪光颜色：火橙、金金、木绿、召唤紫、真实暗紫、物理纸
const SKILL_TINT := {
	"金系": Color(1.0, 0.92, 0.60),
	"火系": Color(1.0, 0.70, 0.40),
	"木系": Color(0.70, 0.95, 0.64),
	"召唤": Color(0.78, 0.70, 1.0),
	"物理": Color(0.96, 0.93, 0.86),
	"真实": Color(0.72, 0.52, 0.88),
}

func _skill_cast_juice() -> void:
	_screen_flash(SKILL_TINT.get(_cast_dtype, Color(1.0, 0.94, 0.80)), 0.16, 0.18)
	Aud.sfx("swing", -7.0, 0.85)
	_core._shake = maxf(float(_core._shake), 5.0)
	_core._hitstop = maxf(float(_core._hitstop), 0.045)

func _pulse_chip(lb: Label) -> void:
	if lb == null:
		return
	lb.pivot_offset = lb.size * 0.5
	_pulses[lb] = 1.0

func _tick_pulses(dt: float) -> void:
	if _pulses.is_empty():
		return
	for lb_v in _pulses.keys():
		var lb: Label = lb_v
		var v := float(_pulses[lb_v]) - dt * 3.5
		if v <= 0.0:
			lb.scale = Vector2.ONE
			_pulses.erase(lb_v)
		else:
			_pulses[lb_v] = v
			var k := 1.0 + 0.22 * v
			lb.scale = Vector2(k, k)

func _tick_fly(dt: float) -> void:
	if _fly.is_empty():
		return
	for i in range(_fly.size() - 1, -1, -1):
		var d: Dictionary = _fly[i]
		d["t"] = float(d["t"]) + dt * 2.6
		if float(d["t"]) >= 1.0:
			_fly.remove_at(i)
			continue
		var e := float(d["t"])
		var ee := 1.0 - pow(1.0 - e, 2.0)          # 先快后慢
		d["x"] = lerpf(float(d["sx"]), float(d["tx"]), ee)
		d["y"] = lerpf(float(d["sy"]), float(d["ty"]), ee) - sin(e * PI) * 56.0
	_fly_layer.queue_redraw()

func _trigger_combos(trigger: String) -> void:
	for rec in _combined:
		if str(rec.get("trigger", "")) == trigger:
			_apply_combo(rec)
	if _combined_layer != null and _combined_layer.visible:
		_refresh_combined()

# 第四关挑战刷怪减半，危途“挑战收益”卡偷偷补 1.5 倍，保住风险换收益
func _peril_scale(v: float) -> float:
	return v

func _apply_combo(rec: Dictionary) -> void:
	rec["stacks"] = int(rec.get("stacks", 0)) + 1
	var key := str(rec.get("combo_key", ""))
	# 羁绊增幅：这张组合被羁绊点名过，就按比例放大（_combo_boost 里是 0.4 = +40%）
	var val := float(rec.get("combo_val", 0)) * (1.0 + float(_combo_boost.get(str(rec.get("name", "")), 0.0)))
	match key:
		"atk":
			_stats["atk"] = float(_stats["atk"]) + val
			if _core != null:
				_core.attr_add("atk", val)
				_core.hero["atk"] = float(_core.hero.get("atk", 0.0)) + val
		"def":
			# v6: def removed
			if _core != null:
				# v6：组合防御也走七系固定减免，和卡牌防御一致
				var def_red := val * DEF_CARD_TO_RED
				if def_red > 0.0:
					for t in _core.DMG_TYPES:
						if t != "真实":
							_core.type_add(t, "red_f", def_red)
		"hp":
			_stats["hp"] = float(_stats["hp"]) + val
			if _core != null:
				_core.attr_add("hp", val)
				_core.hero["hp_max"] = float(_core.hero.get("hp_max", 1.0)) + val
				_core.hero["hp"] = float(_core.hero.get("hp", 0.0)) + val
		"heal":
			if _core != null: _core.hero["hp"] = minf(float(_core.hero.get("hp_max", 1.0)), float(_core.hero.get("hp", 0.0)) + val)
		"gold_pct":
			_gold_pct += val
		"gold_flat":
			_wen += _take_int(rec, val)
			if _coin_lb != null: _coin_lb.text = str(_wen)
		"crystal_flat":
			_gain_crystal(_take_int(rec, val))
			_update_crystal()
		"mp_flat":
			_mp = minf(_mp_max, _mp + val)     # v5：内力系组合 → 回内力
		# ---- v13 群 / 险 ----
		"count_flat":
			_wave_extra += _take_int(rec, val)
		"coin_count":
			_coin_count_extra += _take_int(rec, _peril_scale(float(val)))
		"crystal_count":
			_crystal_count_extra += _take_int(rec, _peril_scale(float(val)))
		"treasure_pct":
			_treasure_pct += _peril_scale(val)
		"boss_pct":
			_boss_pct += _peril_scale(val)
		"devour_n":
			_devour_keep(_take_int(rec, val))
		"killnum_pct":
			_killnum_pct += val
	# v13：组合还带一条「全局难度」
	var ek := str(rec.get("combo_extra_key", ""))
	if ek == "diff_pct":
		_diff_pct += float(rec.get("combo_extra_val", 0))
	if key in ["count_flat", "coin_count", "crystal_count", "treasure_pct", "boss_pct"] or ek == "diff_pct":
		_push_run_mods()

# 整数类组合（+1 文钱 / +2 只怪 / +1 张吞噬…）的增幅取整：
#   +40% 作用在 1 上 = 1.4，直接 int() 会被抹成 1（等于没加）。
#   这里把小数攒进 _combo_frac，攒够 1 就多给 1 点 —— 长时间看就是实打实的 +40%。
func _take_int(rec: Dictionary, val: float) -> int:
	var nm := str(rec.get("name", ""))
	var whole := int(floor(val))
	var frac := val - float(whole)
	if frac <= 0.0001:
		return whole
	var acc := float(_combo_frac.get(nm, 0.0)) + frac
	var extra := int(floor(acc))
	_combo_frac[nm] = acc - float(extra)
	return whole + extra

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

# 三合一动画：三张卡向中间汇聚，淡出后再生成一张，飞向顶栏「总计」并打开
func _play_merge_fx(rec: Dictionary) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 150
	add_child(layer)
	var ap := str(rec.get("art", ""))
	var tex: Texture2D = null
	if ap != "" and ResourceLoader.exists(ap):
		tex = load(ap)
	var center := Vector2(360, 470)
	for i in 3:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.size = Vector2(92, 124)
		t.position = center + Vector2(-160.0 + float(i) * 160.0, 0.0) - t.size * 0.5
		t.modulate.a = 0.0
		layer.add_child(t)
		var tw := create_tween()
		tw.set_parallel(false)
		tw.tween_property(t, "modulate:a", 1.0, 0.12).set_delay(float(i) * 0.05)
		tw.parallel().tween_property(t, "position", center - t.size * 0.5, 0.30).set_delay(0.18 + float(i) * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.chain().tween_property(t, "modulate:a", 0.0, 0.10)
	# 汇聚完成后：合成一张，飞向「总计」
	var tw2 := create_tween()
	tw2.tween_interval(0.62)
	tw2.tween_callback(func() -> void: _fly_to_totals(layer, tex, center))

func _fly_to_totals(layer: Control, tex: Texture2D, from: Vector2) -> void:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.size = Vector2(92, 124)
	t.position = from - t.size * 0.5
	t.pivot_offset = t.size * 0.5
	layer.add_child(t)
	var twg := create_tween()
	twg.tween_property(t, "modulate", Color(1.6, 1.35, 0.7), 0.08)
	twg.tween_property(t, "modulate", Color(1, 1, 1), 0.12)
	var target := Vector2(604, 109)
	if _tot_btn != null:
		target = _tot_btn.global_position + _tot_btn.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(t, "position", target - t.size * 0.5, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(t, "scale", Vector2(0.28, 0.28), 0.46)
	tw.tween_property(t, "modulate:a", 0.0, 0.14).set_delay(0.34)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
		# 本局第一次组合：压暗屏幕 + 高亮「总计」，引导玩家去查看
		if not _tot_hint_shown and LevelState.has_feature("draw") and not LevelState.has_feature("treasure"):
			_tot_hint_shown = true
			_l1_tutorial("l1_tot", _tot_btn, "合成后的卡组可以在此处查看",
				func() -> void: _show_totals())
		else:
			_pulse_tot_btn())

# 单卡飞向总计（炫卡被吞噬时用）
func _fly_card_to_totals(art_path: String) -> void:
	var tex: Texture2D = null
	if art_path != "" and ResourceLoader.exists(art_path):
		tex = load(art_path)
	var lay := Control.new()
	lay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.z_index = 150
	add_child(lay)
	_fly_to_totals(lay, tex, Vector2(360, 470))

func _pulse_tot_btn() -> void:
	if _tot_btn == null:
		return
	_tot_btn.pivot_offset = _tot_btn.size * 0.5
	var tw := create_tween()
	tw.tween_property(_tot_btn, "scale", Vector2(1.18, 1.18), 0.08)
	tw.tween_property(_tot_btn, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	# 三合一表现：三张卡汇聚 → 合成一张 → 飞进「总计」
	_play_merge_fx(rec)
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
	# v6: def removed
	_stats["hp"] = float(_stats["hp"]) + float(s["hp"])
	if float(s.get("mp", 0.0)) > 0.0:
		if _core != null:
			_core.attr_add("mp", float(s["mp"]))
	_gold_pct += float(s["gold_pct"])
	_crystal_pct += float(s["crystal_pct"])
	# v13 群/险
	if float(s.get("count", 0.0)) > 0.0:
		_wave_extra += int(s["count"])
	if float(s.get("coin_count", 0.0)) > 0.0:
		_coin_count_extra += int(round(_peril_scale(float(s["coin_count"]))))
	if float(s.get("crystal_count", 0.0)) > 0.0:
		_crystal_count_extra += int(round(_peril_scale(float(s["crystal_count"]))))
	if float(s.get("treasure_pct", 0.0)) > 0.0:
		_treasure_pct += _peril_scale(float(s["treasure_pct"]))
	if float(s.get("boss_pct", 0.0)) > 0.0:
		_boss_pct += _peril_scale(float(s["boss_pct"]))
	if float(s.get("wen_flat", 0.0)) > 0.0:
		_add_wen(int(s["wen_flat"]))
	if float(s.get("crystal_flat", 0.0)) > 0.0:
		_gain_crystal(int(s["crystal_flat"]))
		_update_crystal()
	if float(s.get("kill_pct", 0.0)) > 0.0:
		_kill_pct += float(s["kill_pct"])
	if float(s.get("exp_pct", 0.0)) > 0.0:
		_killnum_pct += float(s["exp_pct"])
	_push_run_mods()
	if _core != null:
		# v6：新属性层是结算源；旧 hero 字段继续给技能/召唤物读，两边一起加
		_core.attr_add("atk", float(s["atk"]))
		_core.attr_add("hp", float(s["hp"]))
		_core.hero["atk"] = float(_core.hero.get("atk", 0.0)) + float(s["atk"])
		# v6：防御卡不再加「数值减伤」，改成七系固定减免（1 点防御 = 3% 减免，跟旧手感对齐）
		var def_red := float(s["def"]) * DEF_CARD_TO_RED
		if def_red > 0.0:
			for t in _core.DMG_TYPES:
				if t != "真实":
					_core.type_add(t, "red_f", def_red)
		var hp_add := float(s["hp"])
		_core.hero["hp_max"] = float(_core.hero.get("hp_max", 1.0)) + hp_add
		_core.hero["hp"] = float(_core.hero.get("hp", 0.0)) + hp_add

# 选择类反馈：抽卡 / 进阶 / 宝物 / 请神 / 升级 各一口特效＋一声音
# 首领登场：暗红炸开 + 重震 + 鼓
func _on_boss_arrived(_tier: int) -> void:
	var p := Vector2(360, 250)
	var b: Dictionary = _core._boss_foe() if _core != null else {}
	if not b.is_empty():
		p = _core.position + Vector2(float(b["x"]), float(b["y"]) - 24.0)
	# 别糊到顶部 HUD 上：压回战场内
	p.x = clampf(p.x, 90.0, 630.0)
	p.y = clampf(p.y, 210.0, 800.0)
	_spawn_pfx("shadow/dark-explosion", p, 1.7, "shadow", 1.9)
	_core._shake = maxf(float(_core._shake), 15.0)
	Aud.sfx("drum", -6.0, 0.85)
	Aud.sfx("tension", -14.0, 0.95)
	_boss_intro_show(p, str(b.get("name", "首领")) if not b.is_empty() else "首领")
	_cam_zoom_to(1.05, 0.75)     # 首领战：镜头推近，压场

# 首领登场演出：战场压暗 → 聚光罩住首领 → 名字大字弹入
func _boss_intro_show(at: Vector2, nm: String) -> void:
	if _boss_veil == null or _boss_spot == null or _boss_name_lb == null:
		return
	_boss_veil.visible = true
	_boss_veil.color.a = 0.0
	var t1 := create_tween().bind_node(_boss_veil)
	t1.tween_property(_boss_veil, "color:a", 0.55, 0.22)
	t1.tween_interval(0.55)
	t1.tween_property(_boss_veil, "color:a", 0.0, 0.75)
	t1.tween_callback(func() -> void: _boss_veil.visible = false)
	_boss_spot.visible = true
	_boss_spot.position = at
	_boss_spot.scale = Vector2(0.35, 0.35)
	_boss_spot.modulate.a = 0.0
	var t2 := create_tween().bind_node(_boss_spot)
	t2.set_parallel(true)
	t2.tween_property(_boss_spot, "modulate:a", 1.0, 0.16)
	t2.tween_property(_boss_spot, "scale", Vector2(1.25, 1.25), 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t2.chain().tween_property(_boss_spot, "modulate:a", 0.0, 0.45)
	t2.chain().tween_callback(func() -> void: _boss_spot.visible = false)
	_boss_name_lb.text = nm
	_boss_name_lb.visible = true
	_boss_name_lb.pivot_offset = Vector2(360, 35)
	_boss_name_lb.scale = Vector2(1.5, 1.5)
	_boss_name_lb.modulate.a = 0.0
	var t3 := create_tween().bind_node(_boss_name_lb)
	t3.set_parallel(true)
	t3.tween_property(_boss_name_lb, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t3.tween_property(_boss_name_lb, "modulate:a", 1.0, 0.22)
	t3.chain().tween_interval(0.95)
	t3.chain().tween_property(_boss_name_lb, "modulate:a", 0.0, 0.45)
	t3.chain().tween_callback(func() -> void: _boss_name_lb.visible = false)

# Boss/壮汉延迟技砸下来：按属性给一口命中特效
const LAND_FX := {
	"物理": ["impacts/ground-slam", "metal", 0.90],
	"火系": ["fire/fireball", "", 0.90],
	"金系": ["lightning/zap-hit", "volt", 0.95],
	"木系": ["nature/leaf-storm", "leaf", 0.85],
	"真实": ["shadow/soul-drain", "", 0.80],
}

func _on_delayed_land(pos: Vector2, elem: String) -> void:
	var e: Array = LAND_FX.get(elem, ["impacts/crit-hit", "", 0.85])
	var wp: Vector2 = _core.position + pos
	_spawn_pfx(str(e[0]), wp, float(e[2]), str(e[1]), 1.30)

# 首领倒下：白闪 + 大爆 + 金耀 + 重震，配一段很短的慢镜头
# 纸人 Lv5：在核心那边挡下了首领延迟技
func _on_paper_blocked(pos: Vector2) -> void:
	if _run_over or _curio_id != "zhiren":
		return
	_set_paper_count(mini(_zhiren - 1, int(_core.hero.get("paper_guard", 0))))
	_paper_shatter()
	_curio_uses += 1
	_curio_flash()
	_toast("纸人替身 · 挡下首领一击（剩 %d）" % _zhiren)
	Aud.sfx("paper", -8.0, 1.0)
	if _core != null:
		_spawn_pfx("holy/heal", _core.position + pos, 1.0, "heal", 1.5)

func _on_boss_died(pos: Vector2) -> void:
	var wp: Vector2 = _core.position + pos
	wp.x = clampf(wp.x, 90.0, 630.0)
	wp.y = clampf(wp.y, 210.0, 800.0)
	_screen_flash(Color(1.0, 0.97, 0.88), 0.42, 0.55)
	_spawn_pfx("shadow/dark-explosion", wp, 1.9, "shadow", 1.8)
	_spawn_pfx("holy/sunburst", wp, 1.4, "gold", 1.9)
	_core._shake = maxf(float(_core._shake), 18.0)
	_core._hitstop = maxf(float(_core._hitstop), 0.22)
	Aud.sfx("hit_heavy", -2.0, 0.72)
	Aud.sfx("bell", -4.0, 0.9)
	Aud.sfx("levelup", -6.0, 0.95)
	_cam_zoom_to(1.0, 0.85)      # 首领倒下：镜头退回

func _choice_fx(kind: String) -> void:
	var hpos := _hero_screen()
	match kind:
		"draw":
			_spawn_pfx("arcane/spell-charge", hpos, 0.90, "arcane", 1.4)
			Aud.sfx("paper", -12.0, 1.05)
		"aug":
			_spawn_pfx("holy/halo", hpos, 0.95, "gold", 1.5)
			Aud.sfx("enlighten", -11.0, 1.02)
		"trea":
			_spawn_pfx("holy/halo", hpos, 1.05, "holy", 1.5)
			Aud.sfx("chest", -10.0, 1.05)
		"rare":
			_spawn_pfx("holy/sunburst", hpos, 1.10, "gold", 1.9)
			Aud.sfx("levelup", -8.0, 1.10)
			_core._shake = maxf(float(_core._shake), 6.0)
		"god":
			_spawn_pfx("holy/sunburst", hpos, 1.25, "holy", 2.1)
			Aud.sfx("enlighten", -7.0, 0.95)
			_core._shake = maxf(float(_core._shake), 8.0)
			_core._hitstop = maxf(float(_core._hitstop), 0.10)
		"lv":
			_spawn_pfx("holy/halo", hpos, 0.80, "heal", 1.2)

func _add_card(id: String) -> void:
	if _run_over:
		return
	if not _card_db.has(id) or _acquired.has(id): return
	if _cards.size() >= 10:
		_toast("卡组已满（10 格）")
		return
	_choice_fx("draw")
	_qc("draw", 1)
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
		_acquired[id] = true
		_draw_paid = false
		_show_draw(false)
		_do_devour(id)
		return
	var c: Dictionary = _card_db[id]
	_pool.erase(id)
	_cards.append(id)
	_acquired[id] = true
	if bool(c.get("entry", false)):
		for uid in c.get("unlock_ids", []):
			var us := str(uid)
			if _family_card_allowed(us) and not _acquired.has(us) and not _pool.has(us):
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
	# 顶部分类钮：宝物 / 组合
	var tabs := [["bond", "宝物"], ["combo", "组合"]]
	_tot_tabs.clear()
	for i in tabs.size():
		var b := _btn(str(tabs[i][1]), Rect2(60.0 + float(i) * 140.0, 216, 128, 42), 20,
			Color(0.09, 0.08, 0.07, 0.98), LIGHT, _set_tot_tab.bind(str(tabs[i][0])), _combined_layer)
		_tot_tabs.append(b)
	# 两个分页的内容区（都是图标墙：点图标才看详情）
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
	_set_tot_tab("combo")

func _show_combined(v: bool) -> void:
	_combined_layer.visible = v
	if v:
		_combined_layer.move_to_front()
		_set_tot_tab(_tot_tab)

# 组合页：已合成的组合 + 被吞噬的单卡，全是图标，点开看详情
func _refresh_combined() -> void:
	for ch in _combined_icons.get_children(): ch.queue_free()
	_combined_detail.visible = false
	if _combined.is_empty() and _devoured.is_empty() and _ancestor_combos.is_empty():
		_lbl("还没有已激活组合", Vector2(20, 20), Vector2(580, 40), 22, DIM, _combined_icons)
		return
	var k := 0
	for a_v in _ancestor_combos:
		var ar: Dictionary = a_v
		var ica := CombinedIcon.new()
		ica.position = Vector2(float(k % 5) * 120.0, float(k / 5) * 130.0)
		ica.size = Vector2(100, 100)
		ica.quality = int(ar.get("quality", 2))
		var ap2 := str(ar.get("art", ""))
		if ap2 != "" and ResourceLoader.exists(ap2):
			ica.art = load(ap2)
		ica.size_n = 3
		ica.mark = "传"
		ica.pressed.connect(func() -> void:
			_show_ancestor_combo_detail(ar))
		_combined_icons.add_child(ica)
		k += 1
	for i in _combined.size():
		var rec: Dictionary = _combined[i]
		var ic := CombinedIcon.new()
		ic.position = Vector2(float(k % 5) * 120.0, float(k / 5) * 130.0)
		ic.size = Vector2(100, 100)
		ic.quality = int(rec["quality"])
		ic.art = load(str(rec["art"]))
		ic.size_n = int(rec["size"])
		ic.mark = "合"
		ic.pressed.connect(func() -> void: _show_combined_detail(rec))
		_combined_icons.add_child(ic)
		k += 1
	for d_v in _devoured:
		var d: Dictionary = d_v
		var ic2 := CombinedIcon.new()
		ic2.position = Vector2(float(k % 5) * 120.0, float(k / 5) * 130.0)
		ic2.size = Vector2(100, 100)
		ic2.quality = int(d.get("quality", 4))
		var ap := str(d.get("art", ""))
		if ap != "" and ResourceLoader.exists(ap):
			ic2.art = load(ap)
		ic2.size_n = 0
		ic2.mark = "吞"
		ic2.pressed.connect(func() -> void: _show_devour_detail(d))
		_combined_icons.add_child(ic2)
		k += 1

# 吞噬单卡的详情
func _show_devour_detail(d: Dictionary) -> void:
	for ch in _combined_detail.get_children():
		ch.queue_free()
	_combined_detail.visible = true
	var p := Panel.new()
	p.position = Vector2(140, 320)
	p.size = Vector2(440, 262)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.85, 0.99)
	sb.set_corner_radius_all(9)
	sb.border_color = QUALITY_COLORS[clampi(int(d.get("quality", 4)) - 1, 0, 4)]
	sb.set_border_width_all(7)
	p.add_theme_stylebox_override("panel", sb)
	_combined_detail.add_child(p)
	_lbl(str(d.get("name", "炫卡")), Vector2(170, 340), Vector2(360, 40), 30, INK, _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl("吞　噬", Vector2(170, 382), Vector2(360, 26), 18, Color(0.64, 0.22, 0.15), _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl("吞下 %d 张家传卡" % int(d.get("n", 0)), Vector2(170, 422), Vector2(380, 30), 21, INK, _combined_detail)
	_lbl("灵晶 +%d　文钱 +%d" % [int(d.get("crystal", 0)), int(d.get("wen", 0))], Vector2(170, 458), Vector2(380, 30), 19, INK, _combined_detail)
	_lbl("%s +%d%%" % [str(d.get("skill", "技能")), int(d.get("pct", 0))], Vector2(170, 494), Vector2(380, 30), 19,
		Color(0.46, 0.20, 0.10), _combined_detail)
	_btn("×", Rect2(592, 322, 34, 30), 20, Color(0.97, 0.93, 0.85), DIM,
		func(): _combined_detail.visible = false, _combined_detail)

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
	var sz_cn: Array = ["三", "四", "五", "六"]
	_lbl(str(sz_cn[clampi(int(rec["size"]) - 3, 0, 3)]) + "合一", Vector2(420, 330), Vector2(100, 28), 18, Color(0.64,0.22,0.15), _combined_detail)
	_lbl("卡面合计：" + str(rec["own_text"]), Vector2(170, 390), Vector2(380, 32), 20, INK, _combined_detail)
	var bst := float(_combo_boost.get(str(rec["name"]), 0.0))
	var btail := "" if bst <= 0.0 else ("　羁绊 +%d%%" % int(round(bst * 100.0)))
	_lbl("组合：" + str(rec["combo_text"]) + btail, Vector2(170, 430), Vector2(380, 32), 20, INK, _combined_detail)
	_lbl("触发：" + str(rec["trigger"]) + "　已叠 " + str(int(rec["stacks"])), Vector2(170, 470), Vector2(380, 30), 18, DIM, _combined_detail)
	_lbl("源：" + " · ".join(PackedStringArray(rec["sources"])), Vector2(170, 510), Vector2(380, 60), 17, Color(0.38,0.30,0.20), _combined_detail)
	_btn("×", Rect2(592, 302, 34, 30), 20, Color(0.97,0.93,0.85), DIM, func(): _combined_detail.visible = false, _combined_detail)


# 家传组合详情（独立一套字段，不套用普通组合的 rec）
func _show_ancestor_combo_detail(ar: Dictionary) -> void:
	for ch in _combined_detail.get_children(): ch.queue_free()
	_combined_detail.visible = true
	var q := clampi(int(ar.get("quality", 2)), 1, 5)
	var p := Panel.new()
	p.position = Vector2(140, 320)
	p.size = Vector2(440, 360)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.85, 0.99)
	sb.set_corner_radius_all(9)
	sb.border_color = QUALITY_COLORS[q - 1]
	sb.set_border_width_all(7)
	p.add_theme_stylebox_override("panel", sb)
	_combined_detail.add_child(p)
	_lbl(str(ar.get("name", "家传组合")), Vector2(170, 346), Vector2(360, 40), 30, INK, _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl("家 传 · " + str(ar.get("tier", 1)) + " 档", Vector2(420, 350), Vector2(140, 28), 18, Color(0.64,0.22,0.15), _combined_detail)
	_lbl("效果：" + str(ar.get("text", "")), Vector2(170, 410), Vector2(380, 80), 20, INK, _combined_detail)
	_lbl("源：" + " · ".join(PackedStringArray(ar.get("sources", []))), Vector2(170, 500), Vector2(380, 70), 17, Color(0.38,0.30,0.20), _combined_detail)
	_btn("×", Rect2(592, 322, 34, 30), 20, Color(0.97,0.93,0.85), DIM, func(): _combined_detail.visible = false, _combined_detail)

class CombinedIcon extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal pressed
	var quality := 3
	var art: Texture2D = null
	var size_n := 3
	var mark := "合"
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
		draw_string(F, Vector2(size.x-30,23), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.98,0.92,0.78))
		if size_n > 0:
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
	# 像素命中特效（pixelfx，MIT）：普通小、暴击金亮、挨打偏血
	if hero_hit:
		_spawn_pfx("impacts/blunt-hit", global_pos + Vector2(0, -14), 0.70, "blood", 1.2)
	elif crit:
		_spawn_pfx("impacts/crit-hit", global_pos + Vector2(0, -8), 0.95, "gold", 1.9)
		# 暴击再叠一口小的错位金爆（同一个已烘变体，只改缩放/位置）
		_spawn_pfx("impacts/crit-hit", global_pos + Vector2(randf_range(-14.0, 14.0), -8.0 + randf_range(-10.0, 6.0)), 0.58, "gold", 1.9)
	elif heavy:
		_spawn_pfx("impacts/crit-hit", global_pos + Vector2(0, -8), 0.80, "", 1.4)
	elif randf() < (0.40 if _boss_on else 0.70):
		# 横扫一次打好几只时，普通命中不每只都放（保丝滑，观感也够）；首领战再降一档
		_spawn_pfx("impacts/hit-spark", global_pos + Vector2(0, -6), 0.72, "", 1.0)

# 轻量命中火花：程序化放射线，不预烘、不用 pixelfx，0.18 秒自毁
class ImpactSpark extends Control:
	var col := Color.WHITE
	var life := 0.18
	var t := 0.0
	var dirs: Array = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 7
		var n := 6 + randi() % 3
		for i in n:
			var a := TAU * float(i) / float(n) + randf_range(-0.4, 0.4)
			dirs.append(Vector2(cos(a), sin(a)) * randf_range(0.8, 1.3))
		set_process(true)
	func _process(dt: float) -> void:
		t += dt
		if t >= life:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var k := 1.0 - t / life
		var c := Color(col.r, col.g, col.b, k)
		draw_circle(Vector2.ZERO, 6.0 * k, Color(col.r, col.g, col.b, k * 0.55))
		for d in dirs:
			var p0: Vector2 = d * 3.0
			var p1: Vector2 = d * (7.0 + 16.0 * (1.0 - k))
			draw_line(p0, p1, c, 2.2 * k + 0.6)

func _pfx_col(pal: String, effect: String) -> Color:
	match pal:
		"gold": return Color(1.0, 0.82, 0.30)
		"blood": return Color(0.82, 0.20, 0.16)
		"heal": return Color(0.42, 0.92, 0.52)
		"holy": return Color(1.0, 0.96, 0.62)
		"arcane": return Color(0.72, 0.52, 1.0)
		"fire": return Color(1.0, 0.52, 0.16)
		"poison": return Color(0.52, 0.84, 0.30)
		"volt": return Color(0.95, 0.90, 0.35)
		"leaf": return Color(0.45, 0.85, 0.35)
		"metal": return Color(0.92, 0.86, 0.70)
		"shadow": return Color(0.55, 0.20, 0.60)
		"dust": return Color(0.80, 0.74, 0.62)
	if effect.contains("shadow"):
		return Color(0.55, 0.20, 0.60)
	return Color(1.0, 0.95, 0.80)

func _spawn_pfx(effect: String, pos: Vector2, s := 1.0, pal := "", lig := 1.0, spd := 1.0, flip := false):
	if _cam == null:
		return null
	var sp := ImpactSpark.new()
	sp.position = pos
	sp.scale = Vector2(s, s) * (1.15 if lig > 1.7 else 1.0)
	sp.col = _pfx_col(pal, effect)
	sp.life = 0.16 / maxf(0.6, spd)
	_cam.add_child(sp)
	return sp

func _on_hero_attack() -> void:
	_play_attack_fx(true)
	_attack_count += 1
	_hero_extra_hits()                       # 主角被动：多目标 / 追击 / 剑气
	_curio_on_attack()                       # 奇物：铜钱剑（普攻附带钱镖）
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
	_curio_mirror_hit(tgt, dmg)
	if crit:
		_curio_on_crit(tgt)                  # 奇物：寒玉扳指 / 醉翁壶
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

# 每级伤害成长：高频技能小、低频/高倍率技能大；请神页与战斗共用同一套
const SKILL_LV_STEP := {
	"zl": 3, "cuisanniang": 5, "jicanghai": 3, "chenshi": 3, "liuqingqing": 3,
	"xiaoqier": 2, "gundilong": 2, "qingluan": 3, "zhujue": 2,
}

var _skills: Array = []
var _mp := 100.0
var _mp_max := 100.0
var _mp_bar: Panel = null
var _skill_slots: Array = []
var _god_layer: Control = null
var _god_root: Control = null
var _god_ban_lb: Label = null
var _god_refresh_btn: Button = null
var _god_reroll := 0            # 请神刷新次数（放弃 +1，刷新 -1）
var _god_hand_charge := -1      # 记住这一手是几次请神时掷的（隐藏再开不重掷）

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

var _curio_mana_regen_left := 0.0

func _roll_skill_free_cast() -> bool:
	return _curio_id == "dingfengzhu" and _curio_lv >= 5 and randf() < 0.15

func _skill_mana_cost(sk: Dictionary) -> float:
	var mods: Dictionary = _anc_mod.get(str(sk.get("aid", "")), {})
	return maxf(0.0, float(sk.get("mp", 0.0)) - float(mods.get("mp_flat", 0.0)))

func _tick_skills(dt: float) -> void:
	if _run_over:
		return
	if _core != null and float(_core.hero.get("aspd", 1.0)) > MAX_ASPD:
		_core.hero["aspd"] = MAX_ASPD          # 硬顶：防攻速叠太高卡帧
	var lv_mul := float(_lv - 1)
	_mp_max = maxf(1.0, float(_core.attr_final("mp"))) if _core != null else 100.0
	var boosted_seconds := minf(maxf(0.0, dt), _curio_mana_regen_left)
	_curio_mana_regen_left = maxf(0.0, _curio_mana_regen_left - dt)
	_mp = minf(_mp_max, _mp + (20.0 + 2.0 * lv_mul) * (dt + boosted_seconds * 0.5))
	if _mp_bar != null:
		_mp_bar.size = Vector2(maxf(4.0, 235.0 * clampf(_mp / _mp_max, 0.0, 1.0)), 9.0)
	for i in _skills.size():
		var sk: Dictionary = _skills[i]
		if float(sk["cd_t"]) > 0.0:
			sk["cd_t"] = maxf(0.0, float(sk["cd_t"]) - dt)
		var free_cast := _roll_skill_free_cast()
		if float(sk["cd_t"]) <= 0.0 and (_mp >= _skill_mana_cost(sk) or free_cast):
			var cd_before := float(sk["cd_t"])
			var mp_before := _mp
			if free_cast:
				_mp = maxf(_mp_max, _skill_mana_cost(sk))
			_cast_skill(i)
			if free_cast:
				_mp = mp_before
			if float(sk["cd_t"]) > cd_before + 0.01:
				if _curio_id == "dingfengzhu" and _curio_lv >= 3:
					_curio_mana_regen_left = 2.0
				if i < _skill_slots.size():
					_skill_slots[i].flash = 1.0
				_skill_cast_juice()
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
			if s.flash > 0.0:
				s.flash = maxf(0.0, s.flash - dt * 2.2)
			s.queue_redraw()
		else:
			s.visible = false

	if _core != null:
		_core.hero["mp"] = _mp

# 请神技能特效：按技能属性挑效果 + 换色（pixelfx）
const SKILL_FX := {
	"金系": ["lightning/zap-hit", "volt", 1.10],
	"火系": ["fire/fireball", "", 1.00],
	"木系": ["nature/leaf-storm", "leaf", 0.95],
	"召唤": ["arcane/magic-circle-cast", "", 1.10],
	"物理": ["impacts/ground-slam", "metal", 0.95],
	"真实": ["shadow/soul-drain", "", 0.85],
}

# 技能音效：按属性挑一个"自己的音色"（只放一次，跟着起手特效走）
const SKILL_SFX := {
	"金系": [["slash_light2", -8.0, 1.15], ["bell", -13.0, 1.25]],
	"火系": [["swing", -8.0, 0.88], ["drum", -9.0, 0.90]],
	"木系": [["wood_down", -8.0, 1.10], ["dart", -15.0, 1.20]],
	"召唤": [["enlighten", -8.0, 1.05], ["flute", -12.0, 1.12]],
	"物理": [["sword_in_ground", -7.0, 1.00], ["hit_heavy", -10.0, 0.95]],
	"真实": [["heartbeat", -10.0, 0.90], ["tension", -13.0, 1.00]],
}

func _skill_fx(dtype: String, world_pos: Vector2, big := false) -> void:
	var e: Array = SKILL_FX.get(dtype, [])
	if e.is_empty():
		return
	_spawn_pfx(str(e[0]), world_pos, float(e[2]) * (1.35 if big else 1.0), str(e[1]), 1.9, 1.0)
	if not big:
		var layers: Array = SKILL_SFX.get(dtype, [])
		for one in layers:
			if one.size() >= 3:
				Aud.sfx(str(one[0]), float(one[1]), float(one[2]))

func _hero_screen() -> Vector2:
	return _core.position + _core.hero_pos

func _skill_level_bonus(aid: String) -> float:
	return float(GameState.skill_lv.get(aid, 0)) * float(SKILL_LV_STEP.get(aid, 3))

func _cast_skill(i: int) -> void:
	if _run_over:
		return
	if i < 0 or i >= _skills.size():
		return
	_cast_dtype = str(_skills[i].get("dtype", ""))
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
		_skill_fx("召唤", _hero_screen())
		return
	# 治疗流：回血 + 环毒 + 易伤
	if aid0 == "liuqingqing2":
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		var times := 1
		if _baicao:
			times = _baicao_times()
		_skill_fx("木系", _hero_screen())
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
		_skill_fx("物理", _hero_screen())
		return
	# 撞击流：按气血上限算伤害，并把目标撞飞
	if aid0 == "gundilong":
		if _live_foes().is_empty():
			return
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_charge_ram()
		_skill_fx("物理", _hero_screen(), true)
		return
	# 火系：直伤 + 灼烧（引燃多名）
	if aid0 == "jicanghai":
		if _live_foes().is_empty():
			return                                  # 空场不空放，CD 与内力都不扣
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_cast_fire()
		_skill_fx("火系", _hero_screen())
		return
	# 召唤系：不直接出伤，召一条蛟龙顶上去
	if aid0 == "cuisanniang":
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_summon_dragon(float(md0.get("dmg_pct", 0.0)) + float(_elem_mod.get("召唤", 0.0)) + _skill_level_bonus(aid0))
		_skill_fx("召唤", _hero_screen())
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
	var dmg_pct := float(m.get("dmg_pct", 0.0)) + float(_elem_mod.get(dtype, 0.0)) + _skill_level_bonus(aid)
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
		_skill_fx(dtype, _core.position + Vector2(float(f["x"]), float(f["y"]) - 26.0), true)
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
	_devoured.append({"name": nm, "art": str(c.get("art", "")), "quality": int(c.get("quality", 4)),
		"n": 0, "skill": _label_skill(aid), "pct": 0, "crystal": 0, "wen": 0})
	var dev_rec: Dictionary = _devoured[_devoured.size() - 1]
	for cid in _cards.duplicate():
		var cc: Dictionary = _card_db.get(str(cid), {})
		if str(cc.get("ancestor", "")) == aid:
			_cards.erase(cid)
			n += 1
	_cards.erase(shiny_id)
	var wen := 150 * n
	var crystal := 20 * n
	dev_rec["n"] = n
	dev_rec["wen"] = wen
	dev_rec["crystal"] = crystal
	dev_rec["pct"] = 10 * n
	_wen += wen
	_gain_crystal(crystal)
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
	_fly_card_to_totals(str(c.get("art", "")))
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
	_god_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE      # 空白处放行给战场
	_god_layer.visible = false
	_god_layer.z_index = 40
	add_child(_god_layer)
	var ban := Panel.new()
	ban.position = Vector2(230, 162)
	ban.size = Vector2(260, 42)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.48, 0.14, 0.10, 0.97)
	bsb.set_corner_radius_all(4)
	bsb.border_color = Color(0.95, 0.76, 0.36, 0.9)
	bsb.set_border_width_all(2)
	ban.add_theme_stylebox_override("panel", bsb)
	_god_layer.add_child(ban)
	_breathe(ban)
	_god_ban_lb = _lbl("请神", Vector2(0, 0), Vector2(260, 42), 20, Color(0.97, 0.90, 0.74), ban, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("隐藏", Rect2(620, 162, 72, 32), 17, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _hide_god_pick(), _god_layer)
	_god_root = Control.new()
	_god_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_god_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_god_layer.add_child(_god_root)
	_god_refresh_btn = _btn("刷新 · 0 次", Rect2(140, 620, 200, 54), 19,
		Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _on_god_refresh(), _god_layer)
	_btn("放弃 +1 刷新", Rect2(360, 620, 200, 54), 19,
		Color(0.09, 0.08, 0.07, 0.98), Color(0.80, 0.62, 0.34), func(): _on_god_abandon(), _god_layer)

func _show_god_pick() -> void:
	if _run_over or _god_layer == null:
		return
	if _draw_charge <= 0:
		_toast("升级后可请神")
		return
	if _draw_layer != null:
		_draw_layer.visible = false                    # 抽卡页开着一并收掉
	# 同一手只掷一次：点［隐藏］关了再点［请神］，看到的是同一手（不能白刷）
	if _god_hand_charge != _draw_charge:
		_god_hand_charge = _draw_charge
		_roll_god()
	if _god_root.get_child_count() == 0:
		return
	if _god_ban_lb != null:
		_god_ban_lb.text = "请神 · 剩 %d 次" % _draw_charge
	if _god_refresh_btn != null:
		_god_refresh_btn.text = "刷新 · %d 次" % maxi(0, _god_reroll)
		_god_refresh_btn.disabled = _god_reroll <= 0
	_god_layer.visible = true
	_layer_in(_god_layer)
	_god_layer.move_to_front()

# 掷这一手（二选一）
func _roll_god() -> void:
	for c in _god_root.get_children():
		_god_root.remove_child(c)          # 立刻摘掉，别等帧末（否则新旧卡片会同时存在）
		c.queue_free()
	var cands: Array = []
	var allowed := LevelState.god_ids()
	var unseen := allowed.duplicate()
	# 固定顺序：第一次请神给第一位，第二次给第二位，不随机
	for aid_v in unseen:
		var aid := str(aid_v)
		if SEALED.has(aid):
			continue
		if not _ancestors.has(aid) and AncestorData.ANCESTORS.has(aid):
			cands.append(aid)
	if _god_ban_lb != null:
		_god_ban_lb.text = "请神 · 剩 %d 次" % _draw_charge
	if cands.is_empty():
		_toast("可请的祖宗都已上身（高品祖宗需抽取，暂未开放）")
		_hide_god_pick()
		return
	var n := 1
	if LevelState.current_level >= 7:
		n = 2   # 后续关请神改成二选一（仍按固定顺序取前两位未请的）
	n = mini(n, cands.size())
	var total_w := float(n) * 260.0 + float(maxi(0, n - 1)) * 40.0
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
		gc.position = Vector2(x0 + float(i) * 300.0, 214)
		gc.size = Vector2(260, 390)
		gc.picked.connect(func() -> void: _on_god_card(gc))
		_god_root.add_child(gc)
	if _god_refresh_btn != null:
		_god_refresh_btn.text = "刷新 · %d 次" % maxi(0, _god_reroll)
		_god_refresh_btn.disabled = _god_reroll <= 0

# 刷新：次数型（用一次少一次）
func _on_god_refresh() -> void:
	if _run_over or _god_layer == null or not _god_layer.visible or _draw_charge <= 0:
		return
	if _god_reroll <= 0:
		_toast("刷新次数用完了")
		return
	if not _rr_free():
		_god_reroll -= 1
	_roll_god()
	Aud.sfx("ui_click", -10.0)

# 放弃：这一手不要了，换 1 次刷新（下次请神能用）
func _on_god_abandon() -> void:
	if _run_over or _god_layer == null or not _god_layer.visible or _draw_charge <= 0:
		return
	_god_reroll += 1
	_hide_god_pick()
	_toast("放弃请神 · 刷新 +1（现有 %d 次）" % _god_reroll)
	Aud.sfx("ui_back", -10.0)

func _hide_god_pick() -> void:
	if _god_layer != null:
		_god_layer.visible = false

func _on_god_card(card: GodCard) -> void:
	if _run_over or _god_layer == null or not _god_layer.visible or not is_instance_valid(card) or card.get_parent() != _god_root:
		return
	_pick_god(card.aid)

func _pick_god(aid: String) -> void:
	if _run_over or _ancestors.has(aid) or not AncestorData.ANCESTORS.has(aid):
		return
	if _draw_charge <= 0:
		return
	_god_hand_charge = -1   # 选完后旧手牌作废，即使升级又补回相同次数也必须重掷
	_choice_fx("god")
	_draw_charge -= 1
	_qc("god", 1)
	_grant_ancestor(aid)
	var def: Dictionary = SKILL_DEFS.get(aid, {})
	if not def.is_empty() and not _has_skill(aid):
		var sk: Dictionary = def.duplicate()
		sk["cd"] = float(sk["cd"]) * _curio_skill_cd_mul()   # 奇物·定风珠
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
	var flash := 0.0          # 刚放完技能：一圈金色扩散
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
		if flash > 0.0:
			var k := 1.0 - flash
			var rr := size.x * (0.5 + 0.45 * k)
			draw_arc(c, rr, 0.0, TAU, 32, Color(0.98, 0.82, 0.36, flash * 0.9), 3.0)
			draw_circle(c, size.x * (0.55 + 0.25 * k), Color(0.98, 0.82, 0.36, flash * 0.16))
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
		# 全部按卡片尺寸比例画 —— 卡多大字就多大（请神改成二选一后卡放大到 260×390）
		var qc: Color = QC[clampi(quality - 1, 0, 4)]
		var w := size.x
		var h := size.y
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.965, 0.945, 0.90, 1.0)
		sb.set_corner_radius_all(int(11.0 * w / 260.0))
		sb.border_color = qc
		sb.set_border_width_all(int(7.0 * w / 260.0))
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		draw_string(F, Vector2(0, h * 0.108), god_name, HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.130), Color(0.14, 0.11, 0.08))
		var side := w * 0.56
		var pr := Rect2(Vector2((w - side) * 0.5, h * 0.145), Vector2(side, side))
		draw_rect(pr, Color(0.88, 0.85, 0.78))
		if icon != null:
			var ts := icon.get_size()
			var asp: float = pr.size.x / pr.size.y
			var iw: float = ts.x
			var ih: float = iw / asp
			if ih > ts.y:
				ih = ts.y
				iw = ih * asp
			draw_texture_rect_region(icon, pr, Rect2((ts.x - iw) * 0.5, (ts.y - ih) * 0.5, iw, ih))
		draw_rect(pr, Color(0.35, 0.30, 0.24, 0.30), false, 2.0)
		draw_string(F, Vector2(0, h * 0.725), skill_name, HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.100), Color(0.20, 0.15, 0.10))
		draw_line(Vector2(w * 0.08, h * 0.768), Vector2(w * 0.92, h * 0.768), Color(0.5, 0.4, 0.25, 0.35), 1.6)
		draw_string(F, Vector2(0, h * 0.845), element, HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.082), Color(0.42, 0.30, 0.12))
		draw_string(F, Vector2(0, h * 0.945), "点 击 请 神", HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.076), Color(0.66, 0.22, 0.15))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()

# ---------------- 召唤物：蛟龙 ----------------
func _summon_dragon(bonus_pct: float) -> void:
	var m: Dictionary = _anc_mod.get("cuisanniang", {})
	var cap := 1 + int(m.get("cap_add", 0.0))
	var dragon_count := _curio_count_minions("")
	if dragon_count >= cap:
		return
	var hero_atk := float(_core.hero.get("atk", 12.0))
	var life := 30.0 + float(m.get("life_flat", 0.0))
	var idx := dragon_count
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
	if _run_over or _core == null:
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
			if m.has("decoy"):
				m["decoy"]["active"] = false
			if tk != null and is_instance_valid(tk):
				tk.play_down()
			# 奇物·招魂幡 Lv5：鬼影消失时自爆
			if float(m.get("boom", 0.0)) > 0.0 and _core != null:
				var at_e: Vector2 = m["pos"]
				for f_v2 in _core.foes.duplicate():
					var f2: Dictionary = f_v2
					if float(f2.get("hp", 0.0)) <= 0.0:
						continue
					if at_e.distance_to(Vector2(float(f2["x"]), float(f2["y"]))) > 90.0:
						continue
					_core._apply_dmg(f2, float(_core.hero.get("atk", 12.0)) * float(m["boom"]), "召唤")
					if float(f2.get("hp", 0.0)) <= 0.0:
						_core._kill_foe(f2)
				if _core != null:
					_spawn_pfx("impacts/crit-hit", _core.position + at_e, 0.9, "", 1.4)
			_minions.erase(m)
			continue
		if str(m.get("curio", "")) == "tongjing":
			m["pos"] = _core.hero_pos + Vector2(-60.0, 20.0)
			if m.has("decoy"):
				m["decoy"]["pos"] = m["pos"]
			if tk != null and is_instance_valid(tk):
				tk.position = _core.position + Vector2(m["pos"])
				tk.hp_ratio = float(m["life"]) / float(m["max_life"])
				tk.queue_redraw()
			continue # 镜像复制真实普攻，不再独立按固定CD出手。
		var mp0: Vector2 = m["pos"]
		var ghost := str(m.get("curio", "")) == "zhaohunfan"
		var best: Dictionary = {}
		var bd := 1e9
		for f_v in _core.foes:
			var f: Dictionary = f_v
			if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
				continue
			if ghost and _core.hero_pos.distance_to(Vector2(float(f["x"]), float(f["y"]))) > 220.0:
				continue # 鬼影只支援主角附近目标，不追出跟随范围。
			var d := (Vector2(float(f["x"]), float(f["y"])) - mp0).length()
			if d < bd:
				bd = d
				best = f
		if not best.is_empty():
			var tgt := Vector2(float(best["x"]), float(best["y"]))
			var dv := tgt - mp0
			if dv.length() > 48.0:
				m["pos"] = mp0 + dv.normalized() * minf(150.0 * dt, dv.length() - 48.0)
			else:
				m["atk_cd"] = float(m["atk_cd"]) - dt
				if float(m["atk_cd"]) <= 0.0:
					m["atk_cd"] = 1.1
					var md: float = _core._apply_dmg(best, float(m["dmg"]), "召唤")
					if float(best.get("hp", 0.0)) <= 0.0:
						_core._kill_foe(best)
					# 奇物·铜镜 Lv3：镜影攻击吸血
					if float(m.get("lc", 0.0)) > 0.0 and md > 0.0 and _core != null:
						var hh: Dictionary = _core.hero
						hh["hp"] = minf(float(hh.get("hp_max", 1.0)), float(hh.get("hp", 0.0)) + md * float(m["lc"]))
			m["wave_cd"] = float(m["wave_cd"]) - dt
			if float(m["wave_cd"]) <= 0.0:
				m["wave_cd"] = 20.0
				_dragon_wave(m, best)
		elif ghost:
			var anchor: Vector2 = _core.hero_pos + Vector2(m.get("follow_offset", Vector2(-60.0, 20.0)))
			var back := anchor - mp0
			m["pos"] = mp0 + back.normalized() * minf(150.0 * dt, back.length())
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
		if str(m.get("curio", "")) != "":
			continue
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
			if randf() < 0.6:
				_spawn_pfx("impacts/hit-spark", _core.position + Vector2(float(f["x"]), float(f["y"]) - 18.0), 0.55, "fire", 1.2)
		f["burn_t"] = float(f.get("burn_t", 0.0)) - dt
		if float(f["burn_t"]) <= 0.0 and not _burn_unlimited:
			f["burn"] = maxf(0.0, st - 1.0)
			f["burn_t"] = 4.0
			if float(f["burn"]) <= 0.0:
				f.erase("burn")

func _cast_fire() -> void:
	var m: Dictionary = _anc_mod.get("jicanghai", {})
	var dmg_pct := float(m.get("dmg_pct", 0.0)) + float(_elem_mod.get("火系", 0.0)) + _skill_level_bonus("jicanghai")
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
		_wave_lb.text = "波 %d/%d" % [nw, _max_wave]
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
	# ---- 视频（有视频就用视频，没有才退回程序化动画）----
	if _play_shiny_video(kind):
		if _core != null:
			_core.Shake_add(6.0)
		return
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
		_core.attr_add_amp("atk", pct / 100.0)
		_core.hero["atk"] = float(_core.hero["atk"]) * (1.0 + pct / 100.0)
	# 攻速：直接抬 hero.aspd（核心的普攻间隔就是 1/aspd）
	if eff.has("aspd_pct"):
		_core.attr_add_amp("aspd", float(eff["aspd_pct"]) / 100.0)
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
			if _jpo_stacks > 0:
				_core.attr_add_amp("aspd", -0.06 * float(_jpo_stacks))
			_jpo_stacks = 0
		else:
			_jpo_stacks += 1                      # 不设上限：只靠"换目标"重置
			_core.attr_add_amp("aspd", 0.06)
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
	var pct := RAM_HP_PCT * (1.0 + (float(m.get("dmg_pct", 0.0)) + float(_elem_mod.get("物理", 0.0)) + _skill_level_bonus("gundilong")) / 100.0)
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
				_core.attr_add("hp", 8.0)
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
	_core.attr_add("hp", GUNSHAN_HP)
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
	var dmg_pct := float(m.get("dmg_pct", 0.0)) + float(_elem_mod.get("物理", 0.0)) + _skill_level_bonus("qingluan")
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
			if randf() < 0.6:
				_spawn_pfx("impacts/hit-spark", _core.position + Vector2(float(f["x"]), float(f["y"]) - 18.0), 0.55, "poison", 1.2)
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
var _stone_red_applied := 0.0
var _stone_burst := 0
var _shiyun := false

func _stone_per_def() -> float:
	var m: Dictionary = _anc_mod.get("chenshi2", {})
	return 3.0 if float(m.get("stone_def", 0.0)) > 0.0 else 2.0

func _apply_stone_def() -> void:
	if _core == null:
		return
	var def_pts := _stone_def + float(_stone_layers) * _stone_per_def()
	# v6：不再走 hero.def 数值减伤；1 点防御 = 3% 固定减免，石韵再加 25%
	var red := def_pts * 0.03 + (0.25 if (_shiyun and _stone_layers > 0) else 0.0)
	var delta := red - _stone_red_applied
	if absf(delta) > 0.0001:
		for t in _core.DMG_TYPES:
			if t != "真实":
				_core.type_add(t, "red_f", delta)
		_stone_red_applied = red

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
			_core._apply_dmg(f, dmg, "真实")
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
			_gain_crystal(int(round(2.0 * (1.0 + _treasure_pct / 100.0))))
		"boss":
			_add_wen(int(200.0 * (1.0 + _boss_pct / 100.0)))
			_gain_crystal(int(round(20.0 * (1.0 + _boss_pct / 100.0))))

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
	if _run_over or _zhongli_count <= 0:
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
	if _run_over:
		return
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


# ============================================================
# 奇遇：空槽按Q_TICK间隔掷一条；**血条正下方那一条就是入口**
#   掷到 → 那一条显示「点开看详情」→ 点开弹框［接受］［放弃］
#   接受后才开始计时 / 布置战场；**战斗中途不能放弃**
#   待接或进行中不储存下一条，结束/放弃后重新计时。
# ============================================================
const Q_TICK := 180.0             # 奇遇每 180 秒一次（旧版 75s，按新节奏拉长）
const Q_TIER_CN := ["简单", "普通", "困难", "特殊"]
const Q_TIER_W := [[45.0, 55.0, 0.0, 0.0], [20.0, 50.0, 30.0, 0.0], [10.0, 35.0, 40.0, 15.0]]
const Q_TIER_COL := [Color(0.40, 0.46, 0.34), Color(0.40, 0.36, 0.24), Color(0.52, 0.30, 0.16), Color(0.52, 0.18, 0.16)]

const QUEST_POOL := [
	{"id": "tu", "n": "屠场", "tier": 0, "kind": "count", "key": "kill", "need": 40, "lim": 60.0, "desc": "杀 40 只", "r": {"crystal": 25}},
	{"id": "can", "n": "参悟", "tier": 0, "kind": "count", "key": "draw", "need": 3, "lim": 0.0, "desc": "抽 3 张卡", "r": {"crystal": 25}},
	{"id": "xb", "n": "寻宝", "tier": 0, "kind": "count", "key": "trea", "need": 1, "lim": 0.0, "desc": "拿 1 件宝物", "r": {"crystal": 25, "trea_rr": 1}},
	{"id": "sl", "n": "试炼", "tier": 0, "kind": "count", "key": "chal", "need": 2, "lim": 0.0, "desc": "完成 2 次挑战", "r": {"crystal": 30}},
	{"id": "ch", "n": "淬火", "tier": 0, "kind": "count", "key": "str", "need": 5, "lim": 0.0, "desc": "强化自身 5 次", "r": {"crystal": 25}},
	{"id": "qs", "n": "请神", "tier": 0, "kind": "count", "key": "god", "need": 1, "lim": 0.0, "desc": "请 1 位祖宗", "r": {"crystal": 30}},
	{"id": "yx", "n": "夜巡", "tier": 0, "kind": "survive", "need": 0, "lim": 60.0, "desc": "撑过 60 秒不倒", "r": {"crystal": 30}},

	{"id": "pz", "n": "破阵", "tier": 1, "kind": "statue", "need": 3, "lim": 60.0, "desc": "打碎 3 座石像", "r": {"crystal": 60}},
	{"id": "sg", "n": "升格", "tier": 1, "kind": "count", "key": "lv", "need": 2, "lim": 0.0, "desc": "连升 2 级", "r": {"crystal": 50, "aug_rr": 1}},
	{"id": "ky", "n": "苦役", "tier": 1, "kind": "restrain", "key": "chal", "lim": 30.0, "desc": "30 秒内不用挑战", "r": {"crystal": 50}},
	{"id": "qdf", "n": "清道夫", "tier": 1, "kind": "count", "key": "clearwave", "need": 1, "lim": 0.0, "desc": "一波结束时场上无怪", "r": {"crystal": 50, "trea_rr": 1}},

	{"id": "sh", "n": "守护", "tier": 2, "kind": "guard", "need": 0, "lim": 60.0, "desc": "牢车不碎", "r": {"crystal": 100, "trea_rr": 2}},
	{"id": "zd", "n": "占点", "tier": 2, "kind": "zone", "need": 12, "lim": 45.0, "desc": "站住法阵 12 秒", "r": {"crystal": 90, "aug_rr": 2}},
	{"id": "bs", "n": "不杀", "tier": 2, "kind": "restrain", "key": "kill", "lim": 30.0, "desc": "30 秒内不击杀", "r": {"crystal": 90}},
	{"id": "xj", "n": "献祭", "tier": 2, "kind": "survive", "need": 0, "lim": 60.0, "desc": "扣 20% 气血，活过 60 秒", "r": {"crystal": 130}},

	{"id": "dt", "n": "单挑", "tier": 3, "kind": "champion", "need": 0, "lim": 90.0, "desc": "打死拦路高手", "r": {"crystal": 180, "trea": 1}},
	{"id": "sy", "n": "三英", "tier": 3, "kind": "elite", "need": 3, "lim": 120.0, "desc": "杀掉 3 只精英", "r": {"crystal": 200, "trea": 1}},
	{"id": "dj", "n": "赌局", "tier": 3, "kind": "instant", "need": 0, "lim": 0.0, "desc": "押 100 文，50% 概率中奖", "r": {"wen": 400}},
]

var _q_offer: Dictionary = {}     # 掷到、等玩家点开看的那一条
var _q_cur: Dictionary = {}       # 已接受、正在做的那一条（同时只有一条）
var _q_t := 0.0
var _q_done := 0
var _q_giveup := 0
var _q_fail := 0
var _q_stats: Dictionary = {}
var _q_layer: Control = null
var _q_bar: Panel = null
var _q_lb: Label = null
var _q_hit: Button = null
var _q_pop: Control = null
var _q_orb: QuestOrb = null
var _q_orb_lb: Label = null
var _q_pulse: Tween = null
var _q_ai_t := 0.0

func _q_init() -> void:
	_q_layer = Control.new()
	_q_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_q_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_q_layer.z_index = 9
	add_child(_q_layer)
	# 主角血条正下方：这一条本身就是入口
	_q_bar = _panel(Rect2(96, 138, 528, 34), Color(0.10, 0.09, 0.08, 0.92), 6, Color(0.85, 0.66, 0.23, 0.75), 2, _q_layer)
	_q_lb = _lbl("", Vector2(110, 145), Vector2(500, 22), 15, Color(0.95, 0.90, 0.80), _q_layer)
	_q_hit = Button.new()
	_q_hit.position = Vector2(96, 138)
	_q_hit.size = Vector2(528, 34)
	_q_hit.flat = true
	_q_hit.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed"]:
		_q_hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_q_hit.pressed.connect(_q_open_popup)
	_q_layer.add_child(_q_hit)
	_q_bar.visible = false
	_q_lb.visible = false
	_q_hit.visible = false
	# 待接受：主角左侧的圆钮 + 大红字「奇遇！」
	_q_orb = QuestOrb.new()
	_q_orb.position = Vector2(196, 706)
	_q_orb.size = Vector2(92, 92)
	_q_orb.visible = false
	_q_orb.pressed.connect(_q_open_popup)
	_q_layer.add_child(_q_orb)
	_q_orb_lb = _lbl("奇遇！", Vector2(132, 644), Vector2(220, 56), 40, Color(0.82, 0.16, 0.10), _q_layer, HORIZONTAL_ALIGNMENT_CENTER)
	_q_orb_lb.visible = false

func _q_refresh() -> void:
	var has_cur := not _q_cur.is_empty()
	var has_offer := (not _q_offer.is_empty()) and _q_cur.is_empty()
	# 进行中：血条下面那一条（不写提示，玩家自己点会出详情）
	_q_bar.visible = has_cur
	_q_lb.visible = has_cur
	_q_hit.visible = has_cur
	# 待接受：主角左侧的圆钮 + 大红字
	if _q_orb != null:
		_q_orb.visible = has_offer
	if _q_orb_lb != null:
		_q_orb_lb.visible = has_offer
	_q_set_pulse(has_offer)
	if not has_cur:
		return
	var q: Dictionary = _q_cur
	var s := "「%s」%s" % [str(q["n"]), str(q["desc"])]
	if int(q.get("need", 0)) > 0:
		s += "  %d/%d" % [int(q.get("prog", 0)), int(q["need"])]
	if float(q.get("lim", 0.0)) > 0.0:
		s += "  ·  %.0f 秒" % ceil(float(q["t"]))
	_q_lb.text = s
	_q_bar.add_theme_stylebox_override("panel", _q_style(Color(0.30, 0.24, 0.12), 2))

# 「奇遇！」呼吸：缩放 + 半透明来回，只在有奇遇待接时跑
func _q_set_pulse(on: bool) -> void:
	if _q_orb_lb == null:
		return
	if on:
		if _q_pulse != null and _q_pulse.is_valid():
			return
		_q_orb_lb.pivot_offset = _q_orb_lb.size * 0.5
		_q_orb_lb.scale = Vector2.ONE
		_q_orb_lb.modulate = Color(1, 1, 1, 1)
		_q_pulse = create_tween().set_loops()
		_q_pulse.tween_property(_q_orb_lb, "scale", Vector2(1.12, 1.12), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_q_pulse.parallel().tween_property(_q_orb_lb, "modulate:a", 0.70, 0.5)
		_q_pulse.tween_property(_q_orb_lb, "scale", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_q_pulse.parallel().tween_property(_q_orb_lb, "modulate:a", 1.0, 0.5)
	else:
		if _q_pulse != null:
			_q_pulse.kill()
			_q_pulse = null
		_q_orb_lb.scale = Vector2.ONE
		_q_orb_lb.modulate = Color(1, 1, 1, 1)

# 弹窗统一手感：先「弹进来」，再轻轻呼吸
func _pop_bounce(c: Control, delay := 0.0) -> void:
	if c == null:
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.88, 0.88)
	c.modulate.a = 0.0
	var tw := create_tween().bind_node(c)   # 节点被 free 时自动收回，避免空转
	tw.set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.28).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.16).set_delay(delay)

func _breathe(c: Control) -> void:
	if c == null:
		return
	c.pivot_offset = c.size * 0.5
	var tw := create_tween().bind_node(c).set_loops()
	tw.tween_property(c, "scale", Vector2(1.015, 1.015), 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _q_style(border: Color, w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.08, 0.92)
	sb.set_corner_radius_all(6)
	sb.border_color = border
	sb.set_border_width_all(w)
	return sb

func _q_close_popup() -> void:
	if _q_pop != null:
		_q_pop.queue_free()
		_q_pop = null

# 点那一条：弹详情（掷到的：接受/放弃；已接受：只看）
func _q_open_popup() -> void:
	_q_close_popup()
	var is_offer := _q_cur.is_empty() and not _q_offer.is_empty()
	var q: Dictionary = _q_offer if is_offer else _q_cur
	if q.is_empty():
		return
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 34
	add_child(layer)
	_q_pop = layer
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	# 内容装进 holder：整体弹入 + 呼吸
	var holder := Control.new()
	holder.position = Vector2(120, 330)
	holder.size = Vector2(480, 470)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	_panel(Rect2(0, 0, 480, 470), Color(0.97, 0.93, 0.85, 0.99), 10, Color(0.85, 0.66, 0.23), 3, holder)
	_lbl(str(q["n"]), Vector2(30, 18), Vector2(220, 44), 32, INK, holder)
	var tier := clampi(int(q.get("tier", 0)), 0, 3)
	_panel(Rect2(280, 26, 120, 26), Q_TIER_COL[tier], 4, Q_TIER_COL[tier], 0, holder)
	_lbl("奇遇 · " + str(Q_TIER_CN[tier]), Vector2(280, 28), Vector2(120, 22), 14, Color(0.99, 0.95, 0.87), holder, HORIZONTAL_ALIGNMENT_CENTER)
	var r := _q_rewards(q)
	var rw := "灵晶 " + str(int(r["crystal"])) if r.has("crystal") else ""
	if r.has("wen"):
		rw += (" · " if not rw.is_empty() else "") + "文钱 " + str(int(r["wen"]))
	if r.has("trea_rr"):
		rw += " · 宝物刷新 " + str(int(r["trea_rr"]))
	if r.has("aug_rr"):
		rw += " · 进阶刷新 " + str(int(r["aug_rr"]))
	if r.has("trea"):
		rw += " · 宝物机会 " + str(int(r["trea"]))
	var rows := [
		["条件", str(q["desc"])],
		["限时", "接受后立即结算" if str(q.get("kind", "")) == "instant" else (("%d 秒（接受后才开始算）" % int(q["lim"])) if float(q.get("lim", 0.0)) > 0.0 else "不限时")],
		["奖励", rw],
		["失败", "未中奖则损失 100 文押金" if str(q.get("id", "")) == "dj" else "超时自动消失，不给东西"],
	]
	var y := 90.0
	for row in rows:
		_lbl(str(row[0]), Vector2(32, y), Vector2(70, 22), 14, Color(0.47, 0.41, 0.33), holder)
		_lbl(str(row[1]), Vector2(92, y - 3), Vector2(340, 26), 18, INK, holder)
		y += 50.0
	if is_offer:
		_btn("接 受", Rect2(32, 370, 180, 62), 26, Color(0.85, 0.66, 0.23), Color(0.13, 0.10, 0.06),
			func() -> void: _q_accept(), holder)
		_btn("放 弃", Rect2(268, 370, 180, 62), 26, Color(0.93, 0.89, 0.80), Color(0.35, 0.28, 0.18),
			func() -> void: _q_decline(), holder)
	else:
		_btn("关 闭", Rect2(150, 370, 180, 62), 26, Color(0.93, 0.89, 0.80), Color(0.35, 0.28, 0.18),
			func() -> void: _q_close_popup(), holder)
		_lbl("接了就得打完 · 中途不能放弃", Vector2(30, 342), Vector2(420, 22), 14, Color(0.62, 0.20, 0.14), holder, HORIZONTAL_ALIGNMENT_CENTER)
	_pop_bounce(holder)
	_breathe(holder)

func _q_accept() -> void:
	if _run_over or not _q_cur.is_empty() or _q_offer.is_empty():
		return
	if str(_q_offer.get("id", "")) == "dj" and _wen < 100:
		_toast("赌局 · 需要 100 文，当前不足")
		return
	var q: Dictionary = _q_offer
	_q_offer = {}
	_q_close_popup()
	_spawn_pfx("arcane/rune-circle", _hero_screen(), 1.0, "arcane", 1.4)
	Aud.sfx("ui_open", -10.0, 1.05)
	_q_activate(q)

func _q_decline() -> void:
	if _q_offer.is_empty():
		return
	_q_giveup += 1
	_q_offer = {}
	_q_t = 0.0
	_q_close_popup()
	_q_refresh()

# 奇遇尽量不出声明：这里留空（奖励自己看数字变化）
func _q_notify(_text: String) -> void:
	pass

func _q_finish(why: String) -> void:
	if _run_over or _q_cur.is_empty():
		return
	var q: Dictionary = _q_cur
	_q_cur = {} # 先关闭结算入口，奖励/清理回调不能再次完成同一奇遇。
	_q_t = 0.0
	_q_cleanup(q)
	match why:
		"done":
			_q_done += 1
			_q_reward(q)
			_spawn_pfx("holy/feather-burst", _hero_screen(), 1.0, "gold", 1.7)
			_spawn_pfx("holy/sunburst", _hero_screen(), 0.9, "gold", 1.9)
			_screen_flash(Color(1.0, 0.92, 0.62), 0.10, 0.22)
			_core._shake = maxf(float(_core._shake), 4.0)
			_cam_pulse(1.05, 0.42)
			if _curio_id == "zhenhunling" and _curio_lv >= 5 and _roll_bell_treasure():
				if not _grant_random_treasure():
					_toast("镇魂铃 · 暂无可发放的宝物")
			_q_notify("奇遇完成 · %s" % str(q["n"]))
			Aud.sfx("levelup", -6.0)
			Aud.sfx("bell", -8.0, 1.05)
		"fail":
			_q_fail += 1
			_screen_flash(Color(0.72, 0.28, 0.22), 0.10, 0.22)
			_spawn_pfx("impacts/blunt-hit", _hero_screen() + Vector2(0, -20), 0.9, "blood", 1.2)
			_cam_pulse(1.03, 0.22)
			Aud.sfx("ui_close", -8.0, 0.9)
			_q_notify("奇遇失败 · %s" % str(q["n"]))
	_q_refresh()

func _roll_bell_treasure() -> bool:
	return randf() < 0.30

func _q_cleanup(q: Dictionary) -> void:
	if _core == null or q.is_empty():
		return
	match str(q.get("kind", "")):
		"statue":
			_core.clear_statues()
		"zone":
			_core.clear_zone()
		"guard":
			_core.clear_guard()
		"champion":
			_core.clear_champion()
		"elite":
			_core.clear_elite()

func _q_rewards(q: Dictionary) -> Dictionary:
	var r: Dictionary = q.get("r", {}).duplicate(true)
	var boost := 1.0
	if _curio_id == "zhenhunling" and _curio_lv >= 2:
		boost = 1.3
	for key in r:
		r[key] = int(round(float(r[key]) * boost))
	return r

func _q_reward(q: Dictionary) -> void:
	var r := _q_rewards(q)
	if r.has("crystal"):
		_gain_crystal(int(r["crystal"]))
	if r.has("wen"):
		var before := _wen
		_add_wen(int(r["wen"]))
		q["_awarded_wen"] = _wen - before
	if r.has("trea_rr"):
		_trea_reroll += int(r["trea_rr"])
	if r.has("aug_rr"):
		_aug_reroll += int(r["aug_rr"])
	if r.has("trea"):
		_trea_charge += int(r["trea"])
	_refresh_trea_tile()

func _q_fail_kind(kind: String) -> void:
	if not _q_cur.is_empty() and str(_q_cur.get("kind", "")) == kind:
		_q_finish("fail")

func _q_done_kind(kind: String) -> void:
	if not _q_cur.is_empty() and str(_q_cur.get("kind", "")) == kind:
		_q_finish("done")

# 单槽：待接或进行中时不掷下一条，不积攒隐藏队列。
func _q_roll() -> void:
	if _run_over or _core == null or not _q_cur.is_empty() or not _q_offer.is_empty():
		return
	var wave := int(_core.wave)
	var tw: Array = Q_TIER_W[0] if wave <= 2 else (Q_TIER_W[1] if wave == 3 else Q_TIER_W[2])
	if LevelState.current_level == 4:
		tw = [5.0, 25.0, 45.0, 25.0]   # 第四关奇遇：困难和特殊权重抬高
	var roll := randf() * 100.0
	var tier := 0
	var acc := 0.0
	for i in tw.size():
		acc += float(tw[i])
		if roll <= acc:
			tier = i
			break
	var cand: Array = []
	for e_v in QUEST_POOL:
		var e: Dictionary = e_v
		if int(e["tier"]) != tier:
			continue
		if not _q_cur.is_empty() and str(_q_cur["id"]) == str(e["id"]):
			continue
		if not _q_offer.is_empty() and str(_q_offer["id"]) == str(e["id"]):
			continue
		cand.append(e)
	if cand.is_empty():
		return
	var pick := _q_prepare(cand[randi() % cand.size()])
	_q_offer = pick
	_q_refresh()

# 接受后：布置战场 + 倒计时从这里才开始
func _q_prepare(source: Dictionary) -> Dictionary:
	var q := source.duplicate(true)
	if bool(q.get("_prepared", false)):
		return q
	q["_prepared"] = true
	if _curio_id != "zhenhunling" or _curio_lv < 3:
		return q
	var need := int(q.get("need", 0))
	if need > 0:
		var reduced := maxi(1, int(round(need * 0.8)))
		q["need"] = reduced
		q["desc"] = str(q.get("desc", "")).replace(str(need), str(reduced))
	elif str(q.get("kind", "")) in ["survive", "restrain", "guard"]:
		var limit := float(q.get("lim", 0.0))
		q["lim"] = limit * 0.8
		q["desc"] = str(q.get("desc", "")).replace(str(int(limit)), str(int(q["lim"])))
	return q

func _q_activate(q: Dictionary) -> void:
	if _run_over or not _q_cur.is_empty():
		return
	q = _q_prepare(q)
	q["prog"] = 0
	q["t"] = float(q.get("lim", 0.0))
	q["mark"] = int(_q_stats.get(str(q.get("key", "")), 0))
	match str(q.get("kind", "")):
		"statue":
			_core.spawn_statues(int(q["need"]))
		"zone":
			_core.spawn_zone(150.0, float(q["need"]))
		"guard":
			_core.spawn_guard()
		"champion":
			_core.spawn_champion()
		"elite":
			_core.spawn_elite(int(q["need"]))
		"survive":
			if str(q["id"]) == "xj":
				var h: Dictionary = _core.hero
				h["hp"] = maxf(1.0, float(h.get("hp", 0.0)) * 0.8)
		"instant":
			if str(q.get("id", "")) == "dj" and _wen < 100:
				_toast("赌局 · 需要 100 文，当前不足")
				return
			_q_cur = q
			_q_instant(q)
			_q_refresh()
			return
	_q_cur = q
	_q_refresh()
	Aud.sfx("ui_open", -10.0)

func _q_instant(q: Dictionary) -> void:
	if _run_over or not is_same(_q_cur, q) or str(q.get("id", "")) != "dj" or _wen < 100:
		return
	_wen -= 100
	if _coin_lb != null:
		_coin_lb.text = str(_wen)
	_refresh_str_tile()
	if _roll_quest_gamble():
		_q_finish("done")
		_toast("赌局 · 获得 %d 文，已付 100 文押金" % int(q.get("_awarded_wen", 0)))
	else:
		_q_finish("fail")
		_toast("赌局 · 未中奖，损失 100 文押金")

func _roll_quest_gamble() -> bool:
	return randf() < 0.5

func _qc(key: String, n: int) -> void:
	if n <= 0:
		return
	_q_stats[key] = int(_q_stats.get(key, 0)) + n
	if _q_cur.is_empty():
		return
	if str(_q_cur.get("kind", "")) != "count" or str(_q_cur.get("key", "")) != key:
		return
	_q_cur["prog"] = int(_q_cur.get("prog", 0)) + n
	if int(_q_cur["prog"]) >= int(_q_cur["need"]):
		_q_finish("done")

func _q_check(q: Dictionary) -> void:
	if _core == null or q.is_empty():
		return
	match str(q.get("kind", "")):
		"statue":
			q["prog"] = int(q["need"]) - _core.statues_left()
		"zone":
			q["prog"] = int(_core.zone_prog())
		"elite":
			var alive := 0
			for f_v in _core.foes:
				if str((f_v as Dictionary).get("kind", "")) == "elite" and float(f_v.get("hp", 0.0)) > 0.0 and float(f_v.get("dying", 0.0)) <= 0.0:
					alive += 1
			q["prog"] = int(q["need"]) - alive

func _q_tick(dt: float) -> void:
	if _run_over:
		return
	# 设计稿：奇遇是第 4 关才解锁的新功能（统一走解锁表）
	if not LevelState.has_feature("encounter"):
		return
	if _q_cur.is_empty() and _q_offer.is_empty():
		_q_t += dt
		if _q_t >= _q_interval():
			_q_t = 0.0
			_q_roll()
	else:
		_q_t = 0.0
	if _q_cur.is_empty():
		return
	var q: Dictionary = _q_cur
	_q_check(q)
	if int(q.get("need", 0)) > 0 and int(q.get("prog", 0)) >= int(q["need"]):
		_q_finish("done")
		return
	if str(q.get("kind", "")) == "restrain":
		if int(_q_stats.get(str(q.get("key", "")), 0)) != int(q.get("mark", 0)):
			_q_finish("fail")
			return
	if float(q.get("lim", 0.0)) > 0.0:
		q["t"] = float(q["t"]) - dt
		if float(q["t"]) <= 0.0:
			if str(q["kind"]) in ["survive", "restrain", "guard"]:
				_q_finish("done")
			else:
				_q_finish("fail")
			return
	_q_refresh()
	_q_ai(dt)

func _q_ai(dt: float) -> void:
	_q_ai_t += dt
	if _q_ai_t < 0.3:
		return
	_q_ai_t = 0.0
	if _run_over or _core == null or _q_cur.is_empty():
		return
	match str(_q_cur.get("kind", "")):
		"statue":
			var target: Dictionary = {}
			for f_v in _core.foes:
				var f: Dictionary = f_v
				if not bool(f.get("still", false)) or float(f.get("dying", 0.0)) > 0.0:
					continue
				if target.is_empty() or _core.hero_pos.distance_to(Vector2(float(f["x"]), float(f["y"]))) < _core.hero_pos.distance_to(Vector2(float(target["x"]), float(target["y"]))):
					target = f
			if not target.is_empty():
				_core.order_focus(target)
				return
		"zone":
			var z: Dictionary = _core.zone
			if not z.is_empty() and float(z.get("prog", 0.0)) < float(z.get("goal", 12.0)):
				_core.order_move(Vector2(float(z["x"]), float(z["y"])))
				return
		"guard":
			var g: Dictionary = _core.guard
			if not g.is_empty():
				var best: Dictionary = {}
				var bd := 1e9
				for f_v2 in _core.foes:
					var f2: Dictionary = f_v2
					if float(f2.get("hp", 0.0)) <= 0.0 or bool(f2.get("still", false)):
						continue
					var dd := Vector2(float(f2["x"]), float(f2["y"])).distance_to(Vector2(float(g["x"]), float(g["y"])))
					if dd < bd:
						bd = dd
						best = f2
				if not best.is_empty():
					_core.order_focus(best)
					return
		"champion":
			for f_v3 in _core.foes:
				var f3: Dictionary = f_v3
				if str(f3.get("kind", "")) == "champion":
					_core.order_focus(f3)
					return
		"elite":
			for f_v4 in _core.foes:
				var f4: Dictionary = f_v4
				if str(f4.get("kind", "")) == "elite":
					_core.order_focus(f4)
					return
	_core.clear_order()

# ============================================================
# 炫卡出场视频（assets/video/shiny/*.ogv，Theora）
#   暗底的两段（噬雷/滚山）用加色混合，黑=透明
# ============================================================
const SHINY_VIDEO := {
	"devour": "zl",
	"swallow_sea": "cuisanniang",
	"fentian": "jicanghai",
	"backwash": "backwash",
	"jianpo": "zhujue",
	"gunshan": "gundilong",
	"qianzhi": "zhiyuan",
	"wanren": "qingluan",
	"baicao": "liuqingqing2",
	"undying": "mingzhu",
	"shiyun": "chenshi2",
	"zhongli": "zhongli",
}
# 暗底的段（噬雷/滚山）：实测加色混合在纸色背景上会被冲白，改成正常混合，
# 直接当「雷雨/泥石流过场」——战斗已冻结，黑底反而更有压迫感。
const SHINY_VIDEO_ADD: Array = []

var _shiny_video_busy := false

func _play_shiny_video(kind: String) -> bool:
	var key := str(SHINY_VIDEO.get(kind, ""))
	if key == "":
		return false
	var path := "res://assets/video/shiny/shiny_" + key + ".ogv"
	if not ResourceLoader.exists(path):
		return false
	var stream = load(path)
	if stream == null:
		return false
	var v := VideoStreamPlayer.new()
	v.stream = stream
	v.expand = true
	v.position = Vector2.ZERO
	v.size = Vector2(720, 1280)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.z_index = 71
	if SHINY_VIDEO_ADD.has(key):
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		v.material = mat
	add_child(v)
	v.modulate.a = 0.0
	_shiny_video_busy = true
	var was_running := false
	if _core != null:
		was_running = bool(_core.running)
	# ---- 起手：顿帧 + 白闪 + 震屏（先让战场抖一下，再切视频）----
	if _core != null:
		_core.Shake_add(13.0)
		_core._hitstop = maxf(float(_core._hitstop), 0.10)
	_flash(Color(1.0, 0.98, 0.90), 0.90, 0.04, 0.20)
	Aud.sfx("drum", -6.0)
	_play_video_after_beat(v, was_running)
	return true

# 先让战场抖 0.12 秒（这段必须保持 running，否则震屏停住看不到），再冻结 + 播视频
func _play_video_after_beat(v: VideoStreamPlayer, was_running: bool) -> void:
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(v):
		return
	if _core != null:
		_core.running = false
	v.play()
	var tw := create_tween()
	tw.tween_property(v, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.55)
	tw.tween_property(v, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(v):
			v.stop()
			v.queue_free()
		_shiny_video_busy = false
		if _core != null and was_running:
			_core.running = true)
