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
const HazardTelegraph := preload("res://kushou/hazard_telegraph.gd")
const BlackMarket := preload("res://kushou/black_market.gd")
const BalanceRules := preload("res://kushou/balance_rules.gd")
const BattleArt := preload("res://kushou/battle_art.gd")
const ResultView := preload("res://kushou/result_view.gd")
const DrawView := preload("res://kushou/draw_view.gd")
const CurioDetailView := preload("res://kushou/curio_detail_view.gd")
const DrawCard := preload("res://kushou/draw_card.gd")
const ChoicePanelView := preload("res://kushou/choice_panel_view.gd")
const MenuUI := preload("res://shared/ui_kit.gd")
const CardFrame := preload("res://kushou/card_frame.gd")
const GodPortraits := preload("res://shared/god_portraits.gd")
const PortraitMotion := preload("res://shared/god_portrait_motion.gd")
var _invocation_portrait: PortraitMotion
var _skill_pose_direction := Vector2.ZERO
var _entry_art: Dictionary = {}
var _entry_cards_ready := false
var _god_portraits: Dictionary = {}
var _draw_art_cache: Dictionary = {}
var _frame_fx_art: Texture2D
var _skill_frame_art: Texture2D
var _dragon_frame_art: Texture2D
var _dragon_wave_art: Texture2D
const FRAME_FX_LIMIT := 16
const FRAME_FX_AMBIENT_LIMIT := 12
var _frame_fx_live := 0
var _frame_fx_pool: Array[FrameBurst] = []
var _impact_sparks: ImpactSparks
var _hazard_view: HazardTelegraph

# 怪物立绘：名字 → assets/gen/enemies/foe_<key>.png；没有就回退旧的圆牌 + 一个字
var _foe_tex_cache := {}
var _foe_animation_cache := {}
const CHALLENGE_RIMS := [Color(0.99, 0.76, 0.31), Color(0.32, 0.79, 0.91), Color(0.47, 0.79, 0.58),
	Color(0.98, 0.53, 0.34), Color(0.79, 0.48, 0.94)]

func _foe_art(nm: String) -> Texture2D:
	var key := str(BattleArt.FOE_ART.get(nm, ""))
	if key == "":
		return null
	if _foe_tex_cache.has(key):
		return _foe_tex_cache[key] as Texture2D
	var t := _entry_texture(BattleArt.foe_art_path(key))
	_foe_tex_cache[key] = t
	return t


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
var _draw_view: DrawView = null
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
var _exp_track: Panel = null
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
var _aug_view: ChoicePanelView = null
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
var _rare_buffs: Array = []     # 限时 buff：{raw_atk, t}，记录属性增幅前的固定攻击。
var _bonds_done := 0            # 这一局已经成过几张
var _trea_charge := TREA_CHARGE_START
var _trea_reroll := 3
var _trea_pending := false
var _trea_layer: Control = null
var _trea_view: ChoicePanelView = null
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
const DENSE_ROSTER_ENTER := 22
const DENSE_ROSTER_EXIT := 18
const MIN_VISIBLE_FOE_Y := 90.0
var _dense_roster := false
var _boss_bar_t := 0.0
var _flash_rect: ColorRect = null  # 技能释放时的整屏微闪
var _flash_tween: Tween
var _cast_dtype := ""              # 最近一次释放的技能属性（决定闪光颜色）
var _boss_veil: ColorRect = null   # 首领登场：压暗
var _boss_spot: Sprite2D = null    # 首领登场：聚光
var _boss_name_lb: Label = null    # 首领登场：名字大字
var _combo_readout: Control
const PFX_MAX_LIVE := 26          # 同屏特效上限（实测 60fps 有余量，放回 26）
var _curio_sq = null             # 奇物方块（战场右下，与挑战对称）
var _curio_cd := 0.0             # 奇物冷却剩余
var _curio_uses := 0             # 本局喝了几次（详情页显示）
var _curio_detail: Control = null
var _curio_detail_frame: Texture2D
var _curio_detail_icon: Texture2D
var _rare_taken: Dictionary = {}   # 抽到过的稀有单卡（全部唯一）
var _wave_lb: Label
var _wave_fill: Panel
var _mp_lb: Label
const VITAL_TRACK_WIDTH := 166.0
const WAVE_TRACK_WIDTH := 140.0
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
const HERO_NAME_OFFSET := Vector2(-60, 9)

func prepare_entry_art() -> Array[String]:
	GameState.ensure_loaded()
	if not _entry_cards_ready:
		_init_cards()
		_entry_cards_ready = true
	var paths: Array[String] = [BattleArt.HERO_FRAMES_PATH, BattleArt.BATTLE_FRAMES_PATH, BattleArt.SKILL_FRAMES_PATH,
		BattleArt.DRAGON_FRAMES_PATH, BattleArt.DRAGON_WAVE_PATH, BgArt.path_for(LevelState.current_level - 1)]
	if LevelState.has_feature("god"):
		paths.append(BattleArt.HERO_SKILL_FRAMES_PATH)
	if LevelState.show_button("curio") and not CurioData.get_curio(GameState.curio_id).is_empty():
		paths.append(BattleArt.CURIO_DETAIL_FRAME_PATH)
		paths.append(BattleArt.CURIO_DETAIL_ICON_PATH % GameState.curio_id)
	for frame_id in _entry_enemy_frame_ids():
		paths.append(_foe_frame_path(frame_id))
	for key in _entry_enemy_art_keys():
		paths.append(BattleArt.foe_art_path(key))
	for id in _pool:
		var card: Dictionary = _card_db.get(id, {})
		var frame := CardFrame.texture_path(int(card.get("quality", 3)))
		var art := str(card.get("art", ""))
		if not paths.has(frame):
			paths.append(frame)
		if not art.is_empty() and not paths.has(art):
			paths.append(art)
	for key in _entry_choice_item_keys():
		var path := _choice_item_path(key)
		if not paths.has(path):
			paths.append(path)
	for aid in LevelState.god_ids():
		if not AncestorData.ANCESTORS.has(aid) or SEALED.has(aid):
			continue
		var icon := _god_skill_path(aid, AncestorData.ANCESTORS[aid]["art"])
		var portrait := GodPortraits.path_for(aid)
		for path in [icon, portrait]:
			if not path.is_empty() and not paths.has(path):
				paths.append(path)
	return paths

func supply_entry_art(path: String, texture: Texture2D) -> void:
	_entry_art[path] = texture

func _entry_texture(path: String) -> Texture2D:
	if _entry_art.has(path):
		return _entry_art[path] as Texture2D
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null

func _foe_frame_path(frame_id: String) -> String:
	return "res://assets/gen/enemies/frames/%s.png" % frame_id

func _entry_enemy_frame_ids() -> Array:
	var ids := BattleArt.CROWD_FRAME_PATH.values()
	for name in _entry_named_foes():
		var frame_id := str(BattleArt.FOE_FRAME_PATH.get(name, ""))
		if not frame_id.is_empty():
			ids.append(frame_id)
	return ids

func _entry_named_foes() -> Array[String]:
	var names: Array[String] = []
	for entry in BattleCore.boss_tier_entries(LevelState.boss_tier()):
		names.append(str(entry["name"]))
	if LevelState.show_button("challenge"):
		names.append_array(BattleCore.CHAL_FOE_NAME)
	return names

func _entry_enemy_art_keys() -> Array[String]:
	var keys: Array[String] = []
	for name in _entry_named_foes():
		var key := str(BattleArt.FOE_ART.get(name, ""))
		if not key.is_empty() and not BattleArt.FOE_FRAME_PATH.has(name):
			keys.append(key)
	return keys

func _ready() -> void:
	GameState.ensure_loaded()
	Aud.play_battle_music()
	var _t_ready := Time.get_ticks_usec()
	_max_wave = LevelState.waves()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 17
	theme = th
	if not _no_ui2:
		if not _entry_cards_ready:
			_init_cards()
		_frame_fx_art = _entry_texture(BattleArt.BATTLE_FRAMES_PATH)
		_skill_frame_art = _entry_texture(BattleArt.SKILL_FRAMES_PATH)
		_dragon_frame_art = _entry_texture(BattleArt.DRAGON_FRAMES_PATH)
		_dragon_wave_art = _entry_texture(BattleArt.DRAGON_WAVE_PATH)
		for frame_id in _entry_enemy_frame_ids():
			_foe_animation_cache[frame_id] = _entry_texture(_foe_frame_path(frame_id))
		for key in _entry_enemy_art_keys():
			var path := BattleArt.foe_art_path(key)
			if _entry_art.has(path):
				_foe_tex_cache[key] = _entry_art[path]
		_build_bg()
	if not _no_ui:
		_build_hud()
	_build_field()
	if not _no_ui:
		if LevelState.show_button("draw"):
			_build_deck()
		_build_bottom()
		_q_init()
		_warm_initial_draw_art()
		_warm_choice_art()
		for aid in LevelState.god_ids():
			var path := GodPortraits.path_for(aid)
			if _entry_art.has(path):
				_god_portraits[aid] = _entry_art[path]
		_build_toast()
	_entry_art.clear()
	if not _no_ui:
		if _entry_cards_ready:
			_build_entry_dialogs.call_deferred()
		else:
			for build in _entry_dialog_builders():
				build.call()
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
	_refresh_vitals_hud()
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

func _entry_dialog_builders() -> Array[Callable]:
	return [_build_exit, _build_draw, _build_combined, _build_god_pick, _build_str, _build_trea]

func _build_entry_dialogs() -> void:
	for build in _entry_dialog_builders():
		await get_tree().process_frame
		if _run_over or not MenuUI.navigation_available(self):
			return
		build.call()

# 上一关首通留下的“预习”：下一关开局生效一次
func _apply_level_preview() -> void:
	var pv := LevelState.take_preview(LevelState.current_level)
	if pv.is_empty():
		if int(LevelState.preview.get("lv", 0)) == LevelState.current_level:
			_toast("预习奖励保存未完成，下次进入本关时可重试")
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
	MenuUI.Motion.bind_button(b)
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
	# 关卡 → 背景轮换；文件不存在时回退到程序画的纸面
	const VILLAGE_YARD := "res://assets/art/bg/bg_village_yard_v1.webp"
	const CLIFF_PASS := "res://assets/art/bg/bg_cliff_pass_v1.webp"
	const FINAL_COURT := "res://assets/art/bg/bg_final_bamboo_court_v1.webp"
	const ARENA_FIELD := Rect2(0, 132, 720, 1080)
	const COURT_Y_OFFSET := 48.0
	const BG_LIST := [
		"res://assets/art/bg/bg_village.jpg",
		"res://assets/art/bg/bg_bamboo.jpg",
		"res://assets/art/bg/bg_rain.jpg",
		"res://assets/art/bg/bg_cave.jpg",
		"res://assets/art/bg/bg_snow.jpg",
		"res://assets/art/bg/bg_night_courtyard_v1.png",
		"res://assets/art/bg/bg_cliff.jpg",
		"res://assets/art/bg/bg_dungeon.jpg",
	]
	var tex: Texture2D = null
	var village_yard := false
	var courtyard := false
	var cliff_pass := false
	var final_court := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	static func path_for(idx: int) -> String:
		if idx == 0 and ResourceLoader.exists(VILLAGE_YARD):
			return VILLAGE_YARD
		if idx == 6 and ResourceLoader.exists(CLIFF_PASS):
			return CLIFF_PASS
		if idx == 9 and ResourceLoader.exists(FINAL_COURT):
			return FINAL_COURT
		return BG_LIST[wrapi(idx, 0, BG_LIST.size())]
	func setup(idx: int, path: String, art: Texture2D) -> void:
		village_yard = path == VILLAGE_YARD
		courtyard = idx == 5
		cliff_pass = path == CLIFF_PASS and art != null
		final_court = path == FINAL_COURT and art != null
		tex = art
	func _draw() -> void:
		if village_yard and tex != null:
			var surround := Color(0.15, 0.12, 0.09)
			var clear := Color(surround, 0.0)
			var field := Rect2(0, 102, 720, 1090)
			var source_size := tex.get_size()
			var scale_to_cover := maxf(field.size.x / source_size.x, field.size.y / source_size.y)
			var crop_size := field.size / scale_to_cover
			draw_rect(Rect2(Vector2.ZERO, size), surround)
			draw_texture_rect_region(tex, field, Rect2((source_size - crop_size) * 0.5, crop_size))
			_fade_band(102, 190, surround, clear)
			_fade_band(1010, 1192, clear, surround)
			return
		if cliff_pass or final_court:
			var surround := Color(0.125, 0.13, 0.10) if final_court else Color(0.17, 0.16, 0.15)
			var clear := Color(surround, 0.0)
			var bottom := 1020.0
			var field := Rect2(ARENA_FIELD.position, Vector2(W, bottom - ARENA_FIELD.position.y))
			var scale_to_source := tex.get_size().y / ARENA_FIELD.size.y
			var crop_start := Vector2(0.0, COURT_Y_OFFSET * scale_to_source if final_court else 0.0)
			var source_size := Vector2(tex.get_size().x, field.size.y * scale_to_source)
			draw_rect(Rect2(0, 0, W, ARENA_FIELD.position.y), surround)
			draw_texture_rect_region(tex, field, Rect2(crop_start, source_size))
			_fade_band(ARENA_FIELD.position.y, 162.0, surround, clear)
			_fade_band(834.0, bottom, clear, surround)
			draw_rect(Rect2(0, bottom, W, H - bottom), surround)
			return
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.93, 0.90, 0.82))
		if courtyard and tex != null:
			draw_texture_rect(tex, Rect2(0, 140, 720, 750), false)
			var paper := Color(0.93, 0.90, 0.82)
			var clear := Color(paper, 0.0)
			_fade_band(140, 209, paper, clear)
			_fade_band(808, 890, clear, paper)
			return
		if tex != null:
			var s := maxf(size.x / float(tex.get_width()), size.y / float(tex.get_height()))
			var w := float(tex.get_width()) * s
			var h := float(tex.get_height()) * s
			draw_texture_rect(tex, Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h), false)
			# 压纸色：中部战斗区轻、上下 UI 区重，保证文字可读
			draw_rect(Rect2(0, 0, 720, 1280), Color(0.965, 0.945, 0.90, 0.26))
			draw_rect(Rect2(0, 0, 720, 160), Color(0.965, 0.945, 0.90, 0.72))
			draw_rect(Rect2(0, 850, 720, 430), Color(0.965, 0.945, 0.90, 0.80))
			return
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
	func _fade_band(top: float, bottom: float, start: Color, end: Color) -> void:
		draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(720, top), Vector2(720, bottom), Vector2(0, bottom)]), PackedColorArray([start, start, end, end]))

# ---------------- 图标 ----------------
class ArtRect extends Control:
	# 把贴图铺到节点矩形：默认拉伸；cover=true 时按比例裁切填满（全屏 CG 用）
	var tex: Texture2D = null
	var cover := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if tex == null:
			return
		if cover:
			var tw := float(tex.get_width())
			var th := float(tex.get_height())
			var s := maxf(size.x / tw, size.y / th)
			var w := tw * s
			var h := th * s
			draw_texture_rect(tex, Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h), false)
		else:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)


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
	var card_name := ""
	var idx = 0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var bounds := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(9)
		sb.set_border_width_all(1 if empty else 2)
		if empty:
			sb.bg_color = Color(0.092, 0.078, 0.063)
			sb.border_color = Color(0.41, 0.32, 0.22)
			draw_style_box(sb, bounds)
			var center := size * 0.5
			var diamond := PackedVector2Array([center + Vector2(0, -11), center + Vector2(8, 0), center + Vector2(0, 11), center + Vector2(-8, 0), center + Vector2(0, -11)])
			draw_polyline(diamond, Color(0.65, 0.52, 0.34, 0.55), 1.2, true)
			return
		var accent: Color = QC[clampi(quality - 1, 0, 4)]
		sb.bg_color = Color(0.93, 0.88, 0.77)
		sb.border_color = accent.lightened(0.22)
		sb.shadow_color = Color(0.02, 0.015, 0.010, 0.56)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 2)
		draw_style_box(sb, bounds)
		if art != null:
			var aperture := Rect2(8, 4, size.x - 16, size.y - 29)
			var source := art.get_size()
			var fitted := source * minf(aperture.size.x / source.x, aperture.size.y / source.y)
			draw_texture_rect(art, Rect2(aperture.get_center() - fitted * 0.5, fitted), false)
		draw_rect(Rect2(4, size.y - 24, size.x - 8, 18), Color(0.19, 0.15, 0.12))
		draw_string(F, Vector2(6, size.y - 10), card_name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 12, 14, Color(1, 0.94, 0.79))
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



func _build_bg() -> void:
	var bg := BgArt.new()
	bg.size = Vector2(W, H)
	var index := LevelState.current_level - 1
	var path := BgArt.path_for(index)
	bg.setup(index, path, _entry_texture(path))
	add_child(bg)
	if bg.cliff_pass or bg.final_court:
		var air := ArenaAir.new()
		air.final_court = bg.final_court
		air.name = "FinalCourtAir" if bg.final_court else "CliffAir"
		add_child(air)
	elif bg.village_yard or bg.courtyard:
		var air := StageAir.new()
		air.name = "StageAir"
		air.lantern = bg.courtyard
		add_child(air)

class StageAir extends Node2D:
	var lantern := false
	var _motes: Array[Sprite2D] = []
	var _elapsed := 0.0

	static func glow_texture(resolution: int) -> GradientTexture2D:
		var glow := Gradient.new()
		glow.set_color(0, Color(1, 1, 1, 0.78))
		glow.set_color(1, Color(1, 1, 1, 0))
		var mote_art := GradientTexture2D.new()
		mote_art.gradient = glow
		mote_art.width = resolution
		mote_art.height = resolution
		mote_art.fill = GradientTexture2D.FILL_RADIAL
		mote_art.fill_from = Vector2(0.5, 0.5)
		mote_art.fill_to = Vector2(1, 0.5)
		return mote_art

	func _ready() -> void:
		var mote_art := glow_texture(20)
		for i in 8:
			var mote := Sprite2D.new()
			mote.texture = mote_art
			mote.modulate = Color(1.0, 0.78, 0.40, 0.0) if lantern else Color(1.0, 0.90, 0.68, 0.0)
			mote.scale = Vector2.ONE * (0.36 + float(i % 3) * 0.13)
			add_child(mote)
			_motes.append(mote)

	func _process(delta: float) -> void:
		_elapsed += delta
		for i in _motes.size():
			var fade := fposmod(_elapsed * (0.07 + float(i % 3) * 0.017) + i * 0.138, 1.0)
			var start := 47.0 + float(i % 4) * 195.0
			var y := 274.0 + float(i % 5) * 102.0
			var mote := _motes[i]
			mote.position = Vector2(start + 38.0 * fade + 14.0 * sin(fade * TAU), y - 65.0 * fade)
			mote.modulate.a = sin(fade * PI) * (0.42 if lantern else 0.31)

class ArenaAir extends Node2D:
	const CLIFF_LANTERNS := [Vector2(0.113, 0.184), Vector2(0.888, 0.128), Vector2(0.951, 0.517)]
	const COURT_LANTERNS := [Vector2(0.339, 0.075), Vector2(0.660, 0.075),
		Vector2(0.054, 0.456), Vector2(0.945, 0.457)]
	var final_court := false
	var _mist_anchors: Array[Vector2] = []
	var _lights: Array[Sprite2D] = []
	var _mist: Array[Sprite2D] = []
	var _elapsed := 0.0

	func _ready() -> void:
		var glow := StageAir.glow_texture(64)
		var blend := CanvasItemMaterial.new()
		blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		var lanterns := COURT_LANTERNS if final_court else CLIFF_LANTERNS
		var shift := Vector2(0.0, BgArt.COURT_Y_OFFSET) if final_court else Vector2.ZERO
		for uv in lanterns:
			var light := Sprite2D.new()
			light.texture = glow
			light.material = blend
			light.position = BgArt.ARENA_FIELD.position + uv * BgArt.ARENA_FIELD.size - shift
			light.modulate = Color(1.0, 0.56, 0.28, 0.18)
			light.scale = Vector2(1.28, 1.10)
			add_child(light)
			_lights.append(light)
		if final_court:
			_mist_anchors.assign([Vector2(20, 325), Vector2(688, 399), Vector2(48, 801)])
		else:
			_mist_anchors.assign([Vector2(75, 380), Vector2(672, 570), Vector2(64, 743)])
		for anchor in _mist_anchors:
			var wisp := Sprite2D.new()
			wisp.texture = glow
			wisp.position = anchor
			wisp.rotation = -0.29
			wisp.modulate = Color(0.54, 0.61, 0.68, 0.12)
			wisp.scale = Vector2(2.60, 0.73)
			add_child(wisp)
			_mist.append(wisp)

	func _process(dt: float) -> void:
		_elapsed += dt
		for i in _lights.size():
			_lights[i].modulate.a = 0.18 + sin(_elapsed * (2.1 + i * 0.72) + i) * 0.06
		for i in _mist.size():
			var phase := fposmod(_elapsed * 0.13 + i * 0.39, 1.0)
			_mist[i].position = _mist_anchors[i] + Vector2(44, -25) * phase
			_mist[i].modulate.a = 0.19 * sin(phase * PI)

func _chip(hud: Control, x: float, width: float, kind: String, value: String, cap: String) -> Label:
	var chip := Control.new()
	chip.position = Vector2(x, 12)
	chip.size = Vector2(width, 52)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(chip)
	_panel(Rect2(Vector2.ZERO, chip.size), Color(0.125, 0.102, 0.082), 8, Color(0.54, 0.42, 0.29), 1, chip)
	var ic := Ico.new()
	ic.kind = kind
	ic.position = Vector2(10, 11)
	ic.size = Vector2(28, 28)
	chip.add_child(ic)
	var vl := _lbl(value, Vector2(78, 9), Vector2(width - 88, 34), 24, LIGHT, chip, HORIZONTAL_ALIGNMENT_RIGHT)
	_lbl(cap, Vector2(43, 15), Vector2(42, 24), 16, Color(0.81, 0.73, 0.59), chip)
	_chips[cap] = chip
	if kind != "coin" and kind != "crystal":
		return vl
	# 点灵晶/文钱给说明（灵晶不足时直接提示无法抽卡）
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var hb := Button.new()
	hb.flat = true
	hb.focus_mode = Control.FOCUS_NONE
	hb.position = Vector2.ZERO
	hb.size = chip.size
	hb.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hb.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hb.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hb.pressed.connect(func() -> void: _on_chip_click(cap))
	chip.add_child(hb)
	MenuUI.Motion.bind_button(hb)
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
	var hud := Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.z_index = 11
	add_child(hud)
	_panel(Rect2(8, 4, 704, 132), Color(0.20, 0.157, 0.115), 12, Color(0.64, 0.48, 0.29), 2, hud)
	var show_crystal := LevelState.show_button("crystal")
	var width := 162.0 if show_crystal else 220.0
	var step := width + 12.0
	_coin_lb = _chip(hud, 18, width, "coin", "0", "文钱")
	_crystal_lb = _chip(hud, 18 + step, width, "crystal", "100", "灵晶")
	_chips["灵晶"].visible = show_crystal
	_kill_lb = _chip(hud, 18 + step * (2 if show_crystal else 1), width, "kill", "0", "杀敌")
	_life_lb = _chip(hud, 18 + step * (3 if show_crystal else 2), width, "heart", "100", "命")
	var well := Color(0.096, 0.078, 0.063)
	_wave_lb = _lbl("", Vector2(22, 75), Vector2(143, 29), 22, LIGHT, hud)
	_panel(Rect2(23, 111, WAVE_TRACK_WIDTH, 6), well, 3, Color.TRANSPARENT, 0, hud)
	_wave_fill = _panel(Rect2(23, 111, 0, 6), GOLD, 3, Color.TRANSPARENT, 0, hud)
	_refresh_wave_hud(1)
	_lbl("气血", Vector2(182, 75), Vector2(56, 24), 17, LIGHT, hud)
	_lbl("内力", Vector2(182, 102), Vector2(56, 24), 17, LIGHT, hud)
	_panel(Rect2(234, 83, VITAL_TRACK_WIDTH, 10), well, 4, Color.TRANSPARENT, 0, hud)
	_panel(Rect2(234, 110, VITAL_TRACK_WIDTH, 10), well, 4, Color.TRANSPARENT, 0, hud)
	_hp_fill = _panel(Rect2(234, 83, VITAL_TRACK_WIDTH, 10), Color(0.76, 0.30, 0.24), 4, Color.TRANSPARENT, 0, hud)
	_mp_bar = _panel(Rect2(234, 110, VITAL_TRACK_WIDTH, 10), Color(0.32, 0.63, 0.65), 4, Color.TRANSPARENT, 0, hud)
	_hp_lb = _lbl("200/200", Vector2(407, 75), Vector2(128, 24), 16, LIGHT, hud)
	_mp_lb = _lbl("100/100", Vector2(407, 102), Vector2(128, 24), 16, LIGHT, hud)
	_tot_btn = _btn("总计", Rect2(542, 79, 73, 44), 17, well, LIGHT, _show_totals, hud)
	_btn("退出", Rect2(625, 79, 73, 44), 17, well, LIGHT, func(): _show_exit(true), hud)
	_boss_bar = BossBar.new()
	_boss_bar.size = Vector2(684, 20)
	_boss_bar.position = Vector2(18, FIELD_POS.y - _boss_bar.size.y)
	_boss_bar.hide()
	hud.add_child(_boss_bar)

func _refresh_wave_hud(wave: int, complete := false) -> void:
	if _wave_lb == null:
		return
	var caption := "波 %d/%d" % [wave, _max_wave]
	if _wave_lb.text != caption:
		_wave_lb.text = caption
	var fraction := clampf(float(wave if complete else wave - 1) / maxf(1.0, float(_max_wave)), 0.0, 1.0)
	_wave_fill.visible = fraction > 0.0
	_wave_fill.size.x = WAVE_TRACK_WIDTH * fraction

func _refresh_vitals_hud() -> void:
	if _hp_fill == null or _core == null:
		return
	var hp := float(_core.hero.get("hp", 0.0))
	var hp_max := maxf(1.0, float(_core.hero.get("hp_max", 1.0)))
	_set_vital_hud(_hp_fill, _hp_lb, hp, hp_max)
	_set_vital_hud(_mp_bar, _mp_lb, _mp, maxf(1.0, _mp_max))

func _set_vital_hud(fill: Panel, caption: Label, value: float, maximum: float) -> void:
	var text := "%d/%d" % [int(maxf(0.0, value)), int(maximum)]
	if caption.text != text:
		caption.text = text
	fill.visible = value > 0.0
	fill.size.x = VITAL_TRACK_WIDTH * clampf(value / maximum, 0.0, 1.0)

# ---------------- 战场 ----------------
# 镜头容器：战场内容都挂在它下面，做推进（zoom）时整体一起缩放
var _cam: Control = null
var _camera_tween: Tween
var _camera_base_scale := Vector2.ONE
const LampField := preload("res://kushou/lamp_field.gd")
var _lamp_field: LampField

func _build_field() -> void:
	var field_clip := Control.new()
	field_clip.position = FIELD_POS
	field_clip.size = Vector2(704, 720)
	field_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_clip.clip_contents = true
	add_child(field_clip)
	_cam = Control.new()
	# 用固定战场裁切框，镜头内仍沿用整个界面的坐标。
	_cam.position = -FIELD_POS
	_cam.size = Vector2(720, 1280)
	_cam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cam.pivot_offset = Vector2(360, 510)   # 以战场中心为缩放中心
	field_clip.add_child(_cam)
	_core = BattleCore.new()
	_core.position = FIELD_POS
	_core.size = field_clip.size
	_core.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 战斗没有手动：点击穿透
	_core.self_modulate = Color(1, 1, 1, 0.25)
	_core.show_combo_counter = false
	_core.show_basic_hit_numbers = false
	_core.draw_hazard_warnings = false
	_cam.add_child(_core)
	_lamp_field = LampField.new()
	_lamp_field.position = _core.position
	_lamp_field.size = _core.size
	_cam.add_child(_lamp_field)
	_hazard_view = HazardTelegraph.new()
	_hazard_view.core = _core
	_hazard_view.position = _core.position
	_cam.add_child(_hazard_view)
	_core.setup({"atk": 12.0, "hp_max": 200.0, "mp_max": 100.0})
	_core.hero["basic_skill_bonus"] = _skill_level_bonus("zhujue") / 100.0
	if LevelState.has_feature("equip"):
		var ForgeData := preload("res://shared/forge_data.gd")
		ForgeData.load_game()
		EquipmentStats.apply(_core, ForgeData.totals())
	_core.set_wave(1)
	_core.coin.connect(_on_core_coin)
	_core.coin_drop.connect(_on_coin_drop)   # v6：钱怪/匪首掉的真钱
	_core.kill.connect(_on_core_kill)
	_core.foe_defeated.connect(_on_foe_defeated)
	_core.chal_drop.connect(_on_chal_drop)
	_core.guard_broken.connect(func() -> void: _q_fail_kind("guard"))
	_core.champion_down.connect(func() -> void: _q_done_kind("champion"))
	_core.hero_attack.connect(_on_hero_attack)
	_core.foe_attack.connect(_on_foe_attack)
	_core.foe_missed.connect(_on_foe_missed)
	_core.foe_windup.connect(_on_foe_windup)
	_core.foe_blocked.connect(_on_foe_blocked)
	_core.hero_strike_resolved.connect(_hero_slash_frames)
	_core.hero_strike_resolved.connect(_hero_extra_hits)
	_core.hero_hit.connect(_on_hero_hit)
	_core.hero_damaged.connect(_curio_on_hero_hurt)
	_core.hero_foe_hit.connect(_on_hero_foe_hit)
	_core.hero_down.connect(_on_hero_down)
	_core.boss_arrived.connect(_on_boss_arrived)
	_core.delayed_land.connect(_on_delayed_land)
	_core.boss_impact.connect(_on_boss_impact)
	_core.boss_died.connect(_on_boss_died)
	_core.boss_slain.connect(_curio_on_boss_slain)
	_core.wood_expired.connect(_curio_on_wood_expired)
	_core.cold_expired.connect(_curio_on_cold_expired)
	_core.paper_blocked.connect(_on_paper_blocked)
	# 教学关每波少刷几只，节奏更快（奖励不变）
	if LevelState.current_level <= 5:
		_core.wave_stage_adjustment = -8
	elif LevelState.current_level <= 10:
		_core.wave_stage_adjustment = -4
	_core.start_run()
	_hero_token = TokenActor.new()
	_hero_token.round_mask = false
	_hero_token.setup(PLAYER_TEX, 44.0, Color(0.96, 0.74, 0.30), false, _entry_texture(BattleArt.HERO_FRAMES_PATH))
	_hero_token.set_role("player")
	if LevelState.has_feature("god"):
		_hero_token.skill_atlas = _entry_texture(BattleArt.HERO_SKILL_FRAMES_PATH)
	_hero_token.set_weapon("sword")
	_hero_token.show_bar = false          # 主角血条只看顶部 HUD，不再挂漂浮血条
	_hero_token.bar_w = 0.0
	_hero_token.unit_name = ""
	_hero_token.position = _core.position + _core.hero_pos
	_hero_token.z_index = 6
	_cam.add_child(_hero_token)
	_combo_readout = ComboReadout.new()
	_combo_readout.position = Vector2(448, 225)
	_combo_readout.size = Vector2(166, 58)
	_combo_readout.z_index = 12
	add_child(_combo_readout)
	var hit := Button.new()
	hit.size = Vector2(96, 96)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hit.pressed.connect(func(): _open_attr_page())
	_cam.add_child(hit)
	MenuUI.Motion.bind_button(hit)
	_hero_hit_btn = hit
	_hero_hit_btn.position = _hero_token.position - Vector2(48, 48 + _hero_token.radius)
	# 挑战方形
	_chal_btn = Tile.new()
	_chal_btn.kind = "challenge"
	_chal_btn.label = "挑战"
	_chal_btn.position = Vector2(8, 760)
	_chal_btn.size = Vector2(96, 96)
	_chal_btn.pressed.connect(_toggle_challenge)
	add_child(_chal_btn)
	_chal_btn.visible = LevelState.show_button("challenge")
	if _chal_btn.visible:
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
	_flash_rect.position = FIELD_POS
	_flash_rect.size = _core.size
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.z_index = 20
	add_child(_flash_rect)
	_fly_layer = FlyLayer.new()
	_fly_layer.size = Vector2(720, 1280)
	_fly_layer.z_index = 12
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
	_cam.add_child(_fx_back)
	_fx_front = AttackFx.new()
	_fx_front.front = true
	_fx_front.position = FIELD_POS
	_fx_front.size = Vector2(704, 720)
	_fx_front.z_index = 7
	_fx_front.clip_contents = true
	_cam.add_child(_fx_front)
	_hero_name_lb = _lbl("少侠", _hero_token.position + HERO_NAME_OFFSET, Vector2(120, 24),
		17, LIGHT, _cam, HORIZONTAL_ALIGNMENT_CENTER)
	_hero_name_lb.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.06, 0.85))
	_hero_name_lb.add_theme_constant_override("outline_size", 4)
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
	if _run_over or _chal_layer == null:
		return
	if _chal_layer.visible:
		_close_challenge()
		return
	if _draw_layer != null:
		_show_draw(false)
	_hide_aug_pick()
	_hide_trea()
	_hide_god_pick()
	_chal_layer.show()
	_chal_btn.hot = true
	_chal_btn.queue_redraw()
	_refresh_chal_panel()
	_pop_bounce(_chal_holder)
	Aud.sfx("ui_open", -8.0)

func _close_challenge() -> void:
	if _chal_layer == null or not _chal_layer.visible:
		return
	MenuUI.Motion.stop(_chal_holder)
	_chal_layer.hide()
	_chal_btn.hot = false
	_chal_btn.queue_redraw()

# ============================================================
# 挑战：冷却制 + 按波解锁，打完给资源
# ============================================================
const CHAL_NAMES := ["钱怪", "晶怪", "书怪", "宝箱", "匪首"]
const CHAL_GROUP := [6, 3, 4, 1, 1]
const CHAL_REWARD := ["额外文钱", "额外灵晶", "额外经验", "宝物机会和刷新", "文钱、灵晶、宝物和刷新"]

var _chal_btns: Array[ChallengeCard] = []
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
	_chal_holder.position = Vector2(24, 342)
	_chal_holder.size = Vector2(672, 368)
	_chal_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	_chal_layer.add_child(_chal_holder)
	_panel(Rect2(3, 6, 666, 365), Color(0.04, 0.03, 0.025, 0.62), 16, Color.TRANSPARENT, 0, _chal_holder)
	_panel(Rect2(Vector2.ZERO, _chal_holder.size), Color(0.13, 0.105, 0.078), 13, Color(0.74, 0.55, 0.29), 2, _chal_holder)
	_panel(Rect2(8, 8, 656, 352), Color.TRANSPARENT, 9, Color(0.70, 0.53, 0.32, 0.50), 1, _chal_holder)
	_lbl("挑战", Vector2(25, 14), Vector2(150, 38), 26, LIGHT, _chal_holder)
	_btn("收起", Rect2(556, 16, 92, 34), 18, MenuUI.P.DARK, MenuUI.P.GOLD_HI, _close_challenge, _chal_holder)
	for i in CHAL_NAMES.size():
		var card := ChallengeCard.new()
		card.position = Vector2(20 + i * 214, 58) if i < 3 else Vector2(20 + (i - 3) * 320, 185)
		card.size = Vector2(204 if i < 3 else 312, 117)
		card.title = CHAL_NAMES[i]
		card.reward = CHAL_REWARD[i]
		card.group = CHAL_GROUP[i]
		card.accent = CHALLENGE_RIMS[i]
		var foe_name: String = BattleCore.CHAL_FOE_NAME[i]
		var atlas := _foe_animation_cache.get(BattleArt.FOE_FRAME_PATH.get(foe_name, "")) as Texture2D
		card.art = _foe_art(foe_name) if atlas == null else atlas
		if atlas != null:
			var cell := float(atlas.get_width()) / 4.0
			card.art_region = Rect2(Vector2.ZERO, Vector2.ONE * cell)
		card.pressed.connect(_chal_press.bind(i))
		_chal_holder.add_child(card)
		_chal_btns.append(card)
	_chal_auto_btn = _btn("自动挑战 · 关", Rect2(432, 312, 220, 42), 20, MenuUI.P.DARK, MenuUI.P.GOLD_HI,
		_toggle_auto_chal, _chal_holder)

class ChallengeCard extends Button:
	const P := preload("res://shared/ui_pal.gd")
	var title := ""
	var reward := ""
	var group := 1
	var accent := Color.WHITE
	var art: Texture2D
	var art_region := Rect2()
	var status := ""

	func _ready() -> void:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.19, 0.155, 0.117).lerp(accent, 0.07)
		normal.border_color = Color(accent, 0.54)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(8)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = normal.bg_color.lightened(0.08)
		hover.border_color = Color(accent, 0.88)
		var inactive := normal.duplicate() as StyleBoxFlat
		inactive.bg_color = P.DARK
		inactive.border_color = Color(accent, 0.32)
		add_theme_stylebox_override("normal", normal)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", hover)
		add_theme_stylebox_override("disabled", inactive)
		MenuUI.Motion.bind_button(self)

	func show_status(value: String, unavailable: bool) -> void:
		if status == value and disabled == unavailable:
			return
		status = value
		disabled = unavailable
		accessibility_name = "%s ×%d，%s，%s" % [title, group, reward, status]
		queue_redraw()

	func _draw() -> void:
		var hue := accent.lerp(P.DIM, 0.47) if disabled else accent
		var wide := size.x > 240.0
		var center := Vector2(46 if wide else 40, 59)
		var radius := 35.0 if wide else 28.0
		draw_circle(center, radius, Color(0.070, 0.056, 0.043), true, -1.0, true)
		draw_arc(center, radius, 0, TAU, 40, Color(hue, 0.50), 1.25, true)
		if art != null:
			var source := art_region if art_region.has_area() else Rect2(Vector2.ZERO, art.get_size())
			var fit := source.size * ((77.0 if wide else 49.0) / maxf(source.size.x, source.size.y))
			var tint := Color(0.74, 0.71, 0.66) if disabled else Color.WHITE
			draw_texture_rect_region(art, Rect2(center - fit * 0.5, fit), source, tint)
		var text_x := 94.0 if wide else 77.0
		draw_string(P.FONT, Vector2(text_x, 35), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, P.PAPER_HI)
		draw_string(P.FONT, Vector2(size.x - 54, 34), "×%d" % group, HORIZONTAL_ALIGNMENT_RIGHT, 40, 18, hue)
		draw_string(P.FONT, Vector2(text_x, 62), reward, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, P.LINE)
		draw_line(Vector2(text_x, 74), Vector2(size.x - 13, 74), Color(hue, 0.32), 1.0, true)
		draw_string(P.FONT, Vector2(text_x, 98), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, hue)

func _toggle_auto_chal() -> void:
	if _run_over:
		return
	_auto_chal = not _auto_chal
	if _chal_auto_btn != null:
		_chal_auto_btn.text = "自动挑战 · " + ("开" if _auto_chal else "关")

func _chal_unlocked(i: int) -> bool:
	if _core == null:
		return false
	return int(_core.wave) >= int(CHAL_MIN_WAVE[clampi(i, 0, CHAL_MIN_WAVE.size() - 1)])

func _chal_press(i: int, automatic := false) -> void:
	if _run_over or _core == null:
		return
	if not _chal_unlocked(i):
		_toast("「%s」第 %d 波才解锁" % [str(CHAL_NAMES[i]), int(CHAL_MIN_WAVE[i])])
		return
	if float(_chal_cd[i]) > 0.0:
		_toast("「%s」冷却中 %.0f 秒" % [str(CHAL_NAMES[i]), ceil(float(_chal_cd[i]))])
		return
	var group := int(CHAL_GROUP[i])
	var spawned: int = _core.spawn_challenge(i, group)
	if spawned == 0:
		if not automatic:
			_toast("场上怪物已满，击败部分后再挑战")
		return
	_chal_cd[i] = _chal_base_cd(i)
	_chal_count += 1
	_qc("chal", 1)
	# 挑战开打：战场上方一口落地冲击 + 鼓，给"应战"的分量
	_spawn_pfx("impacts/ground-slam", Vector2(360, 235), 0.95, "shadow", 1.5)
	Aud.sfx("drum", -12.0, 1.10)
	var title := str(CHAL_NAMES[i])
	_toast("挑战 · " + title if spawned == group else "挑战 · %s ×%d" % [title, spawned])
	Aud.sfx("ui_open", -8.0)
	_refresh_chal_panel()
	if not automatic:
		_close_challenge()

func _refresh_chal_panel() -> void:
	for i in _chal_btns.size():
		var card := _chal_btns[i]
		var cd := float(_chal_cd[i])
		if not _chal_unlocked(i):
			card.show_status("第 %d 波解锁" % CHAL_MIN_WAVE[i], true)
		elif cd > 0.0:
			card.show_status("冷却 %d 秒" % ceili(cd), true)
		else:
			card.show_status("应战", false)

func _chal_auto_try() -> void:
	if not _auto_chal or _run_over or _core == null:
		return
	for i in _chal_btns.size():
		if _chal_unlocked(i) and float(_chal_cd[i]) <= 0.0:
			_chal_press(i, true)
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
	if _run_over or _core == null:
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
	_curio_detail_frame = _entry_art.get(BattleArt.CURIO_DETAIL_FRAME_PATH) as Texture2D
	_curio_detail_icon = _entry_art.get(BattleArt.CURIO_DETAIL_ICON_PATH % _curio_id) as Texture2D
	var info := CurioData.get_curio(_curio_id)
	_curio_sq = CurioSquare.new()
	_curio_sq.position = Vector2(624, 760)
	_curio_sq.size = Vector2(96, 96)
	_curio_sq.glyph = str(info.get("glyph", "奇")) if not info.is_empty() else "奇"
	_curio_sq.equipped = not info.is_empty()
	_curio_sq.label = "玉壶" if _curio_id == "yuhu" else (_curio_sq.glyph + " · 奇物" if not info.is_empty() else "未携带")
	_curio_sq.tooltip_text = str(info.get("name", "未携带奇物"))
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
	if _run_over or _core == null or float(_core.hero.get("hp", 0.0)) <= 0.0:
		return
	var h: Dictionary = _core.hero
	var mx := float(h.get("hp_max", 1.0))
	var pct := 0.30 if _curio_lv >= 2 else 0.25
	var cd := 45.0 if _curio_lv >= 4 else 60.0
	var hp_add := mx * pct
	_core.heal_hero(hp_add)
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
	if hpr <= 0.0 or hpr > 0.70 or not _foe_near(_core.hero_pos, 300.0):
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
	if _core == null or not _skill_batch_active(_core._enemy_attack_epoch) or not _core.foes.has(foe):
		return
	_core._apply_dmg(foe, float(_core.hero.get("atk", 12.0)) * 0.8, "物理")
	_spawn_pfx("impacts/ground-slam", _core.position + Vector2(float(foe["x"]), float(foe["y"])), 0.8, "", 1.2)
	if float(foe.get("hp", 0.0)) <= 0.0:
		_core._kill_foe(foe)

# 铜钱剑：每次普攻附带一枚钱镖（打到更远的怪）
func _curio_on_attack() -> void:
	if _run_over or _curio_id != "tongqianjian" or _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	_dart_n += 1
	var shots := 1
	if _curio_lv >= 3 and _dart_n % 3 == 0:
		shots = 2
	var reach: float = _core.HERO_REACH + (200.0 if _curio_lv >= 4 else 120.0)
	var fired := false
	for _shot in shots:
		if not _skill_batch_active(epoch):
			return
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
		var last_hit: Dictionary = {}
		for i in range(targets.size()):
			if not _skill_batch_active(epoch):
				return
			var target: Dictionary = targets[i]
			if not _core.foes.has(target) or bool(target.get("_death_settled", false)) or float(target.get("hp", 0.0)) <= 0.0 or float(target.get("dying", 0.0)) > 0.0:
				continue
			var mul := (0.45 if _curio_lv >= 2 else 0.35) * (0.5 if i > 0 else 1.0)
			_core._apply_dmg(target, float(_core.hero.get("atk", 12.0)) * mul, "物理")
			last_hit = target
			_spawn_pfx("impacts/crit-hit", _core.position + Vector2(float(target["x"]), float(target["y"]) - 16.0), 0.5, "gold", 1.9)
			if float(target.get("hp", 0.0)) <= 0.0:
				_core._kill_foe(target)
				if not _skill_batch_active(epoch):
					return
		if not last_hit.is_empty():
			_curio_dart_trace(origin, Vector2(float(last_hit["x"]), float(last_hit["y"])))
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
	if not _skill_batch_active(_core._enemy_attack_epoch):
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
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	for mirror in _minions.duplicate():
		if not _skill_batch_active(epoch):
			return
		if not _minions.has(mirror):
			continue
		if str(mirror.get("curio", "")) != "tongjing" or float(mirror.get("life", 0.0)) <= 0.0:
			continue
		var dealt: float = _core.apply_echo_damage(target, damage * float(mirror.get("copy_ratio", 0.5)))
		# 击杀回调可结束战斗或回潮，旧镜像不能在新阶段继续演出/吸血。
		if not _skill_batch_active(epoch):
			return
		if dealt > 0.0:
			_core._push_float(float(target["x"]), float(target["y"]) - 45.0, "镜 " + str(int(dealt)), Color(0.72, 0.70, 0.90))
			if float(_core.hero.get("hp", 0.0)) > 0.0:
				_core.heal_hero(dealt * float(mirror.get("lc", 0.0)))

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
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	for foe in _core.foes.duplicate():
		if not _skill_batch_active(epoch):
			return
		if not _core.foes.has(foe) or bool(foe.get("_death_settled", false)) or float(foe.get("hp", 0.0)) <= 0.0 or float(foe.get("dying", 0.0)) > 0.0:
			continue
		if _core.hero_pos.distance_to(Vector2(float(foe["x"]), float(foe["y"]))) > 140.0:
			continue
		_core._apply_dmg(foe, float(_core.hero.get("atk", 12.0)), "物理")
		if float(foe.get("hp", 0.0)) <= 0.0:
			_core._kill_foe(foe)
			if not _skill_batch_active(epoch):
				return
		elif not bool(foe.get("boss", false)):
			foe["kb"] = maxf(float(foe.get("kb", 0.0)), 120.0)

func _curio_tick_zhaohunfan() -> void:
	if _run_over or _curio_cd > 0.0 or _core == null:
		return
	if not _skill_batch_active(_core._enemy_attack_epoch):
		return
	if _live_foes().is_empty():
		return
	var cap := 2 if _curio_lv >= 3 else 1
	if _curio_count_minions("zhaohunfan") >= cap:
		return
	for _i in range(cap - _curio_count_minions("zhaohunfan")):
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
	if not _skill_batch_active(_core._enemy_attack_epoch):
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
	if not _skill_batch_active(_core._enemy_attack_epoch):
		return
	if _curio_id == "zuiweng" and _curio_lv >= 5 and _curio_atk_t > 0.0:
		_curio_extend_buff(1.0, 5.0)
	if _curio_id != "hanyu" or not _core.foes.has(tgt) or tgt.is_empty() or float(tgt.get("hp", 0.0)) <= 0.0:
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
	Aud.sfx("bell", -12.0, 1.3, 120)

func _curio_on_cold_expired(tgt: Dictionary) -> void:
	var boom := bool(tgt.get("cold_boom", false))
	tgt.erase("cold_boom")
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch) or not _core.foes.has(tgt):
		return
	if boom and float(tgt.get("hp", 0.0)) > 0.0 and float(tgt.get("dying", 0.0)) <= 0.0:
		var at := Vector2(float(tgt["x"]), float(tgt["y"]))
		const BURST_RADIUS := 70.0
		if _fx_front != null and at.y >= MIN_VISIBLE_FOE_Y:
			_fx_front.spawn_ice_burst(_core.position + at - FIELD_POS, BURST_RADIUS)
			Aud.sfx("slash_light2", -16.0, 1.32, 140)
		for o_v in _core.foes.duplicate():
			if not _skill_batch_active(epoch):
				return
			var o: Dictionary = o_v
			if not _core.foes.has(o) or o == tgt or bool(o.get("_death_settled", false)) or float(o.get("dying", 0.0)) > 0.0 or float(o.get("hp", 0.0)) <= 0.0:
				continue
			if at.distance_squared_to(Vector2(float(o["x"]), float(o["y"]))) > BURST_RADIUS * BURST_RADIUS:
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
		_spawn_fly(_hero_screen(), _chip_target("文钱"), Color(0.90, 0.71, 0.30), 4)
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
	if _run_over or is_instance_valid(_curio_detail):
		return
	var info := CurioData.get_curio(_curio_id)
	var has := not info.is_empty()
	if has and _curio_detail_frame == null:
		_curio_detail_frame = _entry_texture(BattleArt.CURIO_DETAIL_FRAME_PATH)
	var icon: Texture2D = null
	if has:
		var icon_path := BattleArt.CURIO_DETAIL_ICON_PATH % _curio_id
		if _curio_detail_icon == null or _curio_detail_icon.resource_path != icon_path:
			_curio_detail_icon = _entry_texture(icon_path)
		icon = _curio_detail_icon
	var view := CurioDetailView.new()
	view.name = "CurioDetailView"
	view.present(info, _curio_id, _curio_lv, _curio_uses, _curio_detail_frame if has else null, icon)
	view.closed.connect(func() -> void: _close_curio_detail(view))
	add_child(view)
	_curio_detail = view

func _close_curio_detail(layer: Control) -> void:
	if layer == null or layer != _curio_detail:
		return
	_curio_detail = null
	if layer is CurioDetailView:
		(layer as CurioDetailView).close()
	else:
		layer.hide()
		layer.queue_free()

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
	var tray := _panel(Rect2(8, 882, 704, 175), Color(0.20, 0.157, 0.115), 12, Color(0.64, 0.48, 0.29), 2)
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rail := _panel(Rect2(16, 921, 688, 123), Color(0.13, 0.106, 0.081), 8, Color(0.39, 0.28, 0.18), 1)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_count_lb = _lbl("卡组 0/10", Vector2(24, 888), Vector2(160, 30), 20, LIGHT)
	_page_lb = _lbl("1/2", Vector2(624, 889), Vector2(60, 28), 17, LIGHT, self, HORIZONTAL_ALIGNMENT_RIGHT)
	_btn("‹", Rect2(12, 958, 36, 50), 24, Color(0.19, 0.15, 0.11), GOLD, func(): _flip(-1))
	_btn("›", Rect2(672, 958, 36, 50), 24, Color(0.19, 0.15, 0.11), GOLD, func(): _flip(1))
	for i in 5:
		var s := CardSlot.new()
		s.position = Vector2(56 + i * 127, 933)
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
			s.art = _draw_art(str(c["art"]))
			s.card_name = str(c["name"])
			s.queue_redraw()
		else:
			s.empty = true
			s.idx = ""
			s.art = null
			s.card_name = ""
			s.queue_redraw()

func _pick_card(id: String) -> void:
	if id == "" or not _card_db.has(id): return
	var c: Dictionary = _card_db[id]
	_detail_name.text = str(c["name"])
	_detail_art.texture = _draw_art(str(c["art"]))
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
	var village := LevelState.current_level == 1
	var base_rect := Rect2(8, 1144, 704, 128) if village else Rect2(8, 1071, 704, 209)
	_panel(base_rect, Color(0.20, 0.157, 0.115), 12, Color(0.64, 0.48, 0.29), 2)
	if not village:
		_panel(Rect2(16, 1114, 688, 154), Color(0.13, 0.106, 0.081), 8, Color(0.39, 0.28, 0.18), 1)
	var track := Rect2(24, 1218, 672, 16) if village else Rect2(96, 1090, 600, 16)
	var level_pos := Vector2(24, 1181) if village else Vector2(22, 1088)
	var exp_pos := Vector2(604, 1184) if village else Vector2(600, 1088)
	_lv_lb = _lbl("Lv 1", level_pos, Vector2(70, 28), 18, GOLD)
	_exp_track = _panel(track, Color(0.93, 0.90, 0.82, 0.16), 8)
	_exp_bar = _panel(Rect2(track.position, Vector2(4, track.size.y)), Color(0.85, 0.66, 0.23), 8)
	_exp_lb = _lbl("0/100", exp_pos, Vector2(92, 20), 15, Color(0.88, 0.82, 0.70), self, HORIZONTAL_ALIGNMENT_RIGHT)
	_market_tile = _tile(24, 1128, 124, "market", "黑市", false)
	_market_tile.visible = LevelState.show_button("market")
	_trea_tile = _tile(158, 1128, 124, "treasure", "宝物", false)
	_trea_tile.visible = LevelState.show_button("treasure")
	_mate_tile = _tile(292, 1128, 124, "mate", "请神", false)
	_mate_tile.visible = LevelState.show_button("mate")
	_str_tile = _tile(590, 1152, 112, "skill", "强化", false) if village else _tile(426, 1128, 124, "skill", "强化", false)
	# 强化固定隐藏：清完第一波的教学那一刻才亮出来（不因重玩而提前显示）
	_str_tile.visible = false
	_str_tile.hot = false
	_draw_tile = _tile(560, 1116, 136, "draw", "抽卡", true)
	_draw_tile.visible = LevelState.show_button("draw")
	_refresh_draw_tile()
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
		if _run_over or not t.is_visible_in_tree():
			return
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
	const NAME_WIDTH := 164.0
	var ratio := 1.0
	var ghost := 1.0
	var bname := ""
	var _backing := StyleBoxFlat.new()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_backing.bg_color = Color(0.14, 0.11, 0.08)
		_backing.set_corner_radius_all(5)
		_backing.border_color = Color(0.62, 0.50, 0.32)
		_backing.set_border_width_all(1)
	func _draw() -> void:
		draw_style_box(_backing, Rect2(Vector2.ZERO, size))
		var inner := Rect2(NAME_WIDTH + 8.0, 5.0, size.x - NAME_WIDTH - 16.0, size.y - 10.0)
		draw_rect(inner, Color(0.076, 0.055, 0.044))
		# 残影（掉下去的那一截，慢慢缩）
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(ghost, 0.0, 1.0), inner.size.y)),
			Color(0.88, 0.66, 0.36, 0.38))
		# 当前血量
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(ratio, 0.0, 1.0), inner.size.y)),
			Color(0.78, 0.24, 0.17))
		# 四等分刻度（看得出还剩几段）
		for i in range(1, 4):
			var tx := inner.position.x + inner.size.x * float(i) / 4.0
			draw_line(Vector2(tx, inner.position.y), Vector2(tx, inner.position.y + inner.size.y),
				Color(0.10, 0.08, 0.06, 0.35), 1.0)
		draw_string(F, Vector2(8, size.y * 0.5 + 5), bname,
			HORIZONTAL_ALIGNMENT_CENTER, NAME_WIDTH, 15, Color(0.98, 0.94, 0.85))

# 资源飞行层：击杀掉的金币/晶石飞向右上角资源条（割草的正反馈）
class FlyLayer extends Control:
	var dots: Array = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for d_v in dots:
			var d: Dictionary = d_v
			draw_circle(Vector2(float(d["x"]), float(d["y"])), float(d["r"]), d["col"])

class CurioSquare extends Button:
	const F := preload("res://fonts/ink.ttf")
	const Glyph := preload("res://shared/glyph_draw.gd")
	var glyph := "壶"
	var label := "奇物"
	var equipped := false
	var cd_left := 0.0
	var cd_max := 60.0
	var flash := 0.0

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		var blank := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, blank)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		MenuUI.Motion.bind_button(self)

	func _draw() -> void:
		var cooling := cd_left > 0.001
		var edge := Color(0.76, 0.61, 0.36)
		if equipped and not cooling:
			edge = Color(0.63, 0.82, 0.68)
		var face := StyleBoxFlat.new()
		face.bg_color = Color(0.16, 0.13, 0.10) if equipped else Color(0.11, 0.10, 0.08)
		if is_hovered():
			face.bg_color = face.bg_color.lightened(0.065)
		face.border_color = edge
		face.set_border_width_all(2)
		face.set_corner_radius_all(12)
		draw_style_box(face, Rect2(Vector2.ZERO, size))
		var c := Vector2(size.x * 0.5, 34)
		draw_circle(c, 25, Color(0.08, 0.07, 0.055, 0.72), true, -1.0, true)
		if glyph == "壶" or not equipped:
			Glyph.draw_ui(self, c, 41, "curio", Color(edge, 0.42) if cooling or not equipped else edge)
		else:
			draw_string(F, Vector2(0, 46), glyph, HORIZONTAL_ALIGNMENT_CENTER, size.x, 35, Color(edge, 0.38) if cooling else edge)
		if cooling:
			var remaining := clampf(cd_left / maxf(cd_max, 0.001), 0.0, 1.0)
			draw_arc(c, 26, -PI * 0.5, -PI * 0.5 + TAU * remaining, 36, edge, 2.0, true)
			draw_string_outline(F, Vector2(0, 45), str(ceili(cd_left)), HORIZONTAL_ALIGNMENT_CENTER, size.x, 25, 5, Color(0.10, 0.08, 0.05))
			draw_string(F, Vector2(0, 45), str(ceili(cd_left)), HORIZONTAL_ALIGNMENT_CENTER, size.x, 25, Color(0.99, 0.91, 0.75))
		draw_string(F, Vector2(0, 76), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color(0.94, 0.87, 0.74))
		if flash > 0.0:
			draw_arc(c, 26.0 + 12.0 * (1.0 - flash), 0, TAU, 36, Color(edge, flash * 0.90), 2.0, true)



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

class Tile extends Button:
	const Glyph := preload("res://shared/glyph_draw.gd")
	const F := preload("res://fonts/ink.ttf")
	var kind := "market"
	var label := ""
	var hot := false
	var badge := 1
	var sub := ""          # 小字（强化：Lv · 价钱）
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		var blank := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, blank)
		preload("res://shared/ui_motion.gd").bind_button(self)
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		var primary := kind == "draw"
		sb.bg_color = Color(0.46, 0.19, 0.13) if primary and hot else Color(0.25, 0.19, 0.13)
		if is_hovered(): sb.bg_color = sb.bg_color.lightened(0.06)
		sb.set_corner_radius_all(10)
		sb.border_color = Color(0.94, 0.74, 0.39) if hot else Color(0.57, 0.44, 0.29)
		sb.set_border_width_all(2 if hot else 1)
		sb.shadow_color = Color(0.055, 0.037, 0.024, 0.7)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 3)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c := Vector2(size.x * 0.5, size.y * 0.34)
		var ink := Color(0.98, 0.91, 0.75) if hot else Color(0.89, 0.81, 0.66)
		draw_circle(c, 30, Color(0.10, 0.072, 0.050, 0.44), true, -1.0, true)
		draw_arc(c, 30, 0.0, TAU, 40, Color(ink, 0.28), 1.0, true)
		Glyph.draw_ui(self, c, 54, kind, ink)
		if sub != "":
			draw_string(F, Vector2(0, size.y - 40), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15,
				Color(0.86, 0.70, 0.34) if hot else Color(0.66, 0.59, 0.48))
		draw_string(F, Vector2(0, size.y - 14), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20 if size.x < 130 else 22, ink)
		if hot and badge > 0 and kind in ["treasure", "mate"]:
			var value := str(badge)
			var badge_width := maxf(22.0, F.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 10.0)
			draw_rect(Rect2(size.x - badge_width - 6, 6, badge_width, 21), Color(0.86, 0.65, 0.29))
			draw_string(F, Vector2(size.x - badge_width - 6, 22), value, HORIZONTAL_ALIGNMENT_CENTER, badge_width, 16, Color(0.18, 0.10, 0.05))

# ---------------- 抽卡层 ----------------
func _build_draw() -> void:
	if _draw_layer != null:
		return
	var view := DrawView.new()
	view.name = "DrawView"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.visible = false
	view.z_index = 20
	view.card_factory = func() -> Control: return DrawCard.new()
	view.card_picked.connect(func(card) -> void: _on_draw_pick(card))
	view.refresh_pressed.connect(_on_refresh)
	view.hide_pressed.connect(func() -> void: _show_draw(false))
	add_child(view)
	view.build()
	_draw_view = view
	_draw_layer = view
	_draw_cards = view.cards
	_draw_refresh_btn = view.refresh_btn

func _warm_initial_draw_art() -> void:
	# 只预热开局能抽到的卡，避免给家传、炫卡或未解锁卡占内存。
	for id in _pool:
		var card: Dictionary = _card_db.get(id, {})
		CardFrame.tex_of(int(card.get("quality", 3)))
		_draw_art(str(card.get("art", "")))

func _draw_art(path: String) -> Texture2D:
	if not _draw_art_cache.has(path):
		_draw_art_cache[path] = _entry_texture(path)
	return _draw_art_cache[path]

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
			dc.set_art(_draw_art(str(c.get("art", ""))))
			dc.progress = _set_progress(str(c.get("set_id", "")))
		else:
			dc.data = {}
			dc.set_art(null)
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
	_refresh_draw_tile()

func _refresh_draw_tile() -> void:
	if _draw_tile == null:
		return
	var available := _draw_paid or (_crystal >= 20 and not _pool.is_empty())
	var subtitle := "继续选卡" if _draw_paid else "20 灵晶"
	if _draw_tile.hot != available or _draw_tile.sub != subtitle:
		_draw_tile.hot = available
		_draw_tile.sub = subtitle
		_draw_tile.queue_redraw()

func _show_draw(v: bool) -> void:
	if v and (_run_over or _draw_anim or _no_ui):
		return
	if v:
		if not _draw_paid:
			if _pool.is_empty():
				MenuUI.Motion.reject_button(_draw_tile)
				_toast("本局卡池已空")
				return
			if _crystal < 20:
				MenuUI.Motion.reject_button(_draw_tile)
				_toast("灵晶不足，不足以抽卡（一次要 20）")
				return
			_build_draw()
			_crystal -= 20
			_update_crystal()
			_roll_draw()
			_draw_paid = true
		_hide_aug_pick()
		_hide_trea()
		_hide_god_pick()
		_close_challenge()
		_draw_open = true
		_draw_view.open()
	else:
		_draw_view.close()
		_draw_open = false
	_refresh_draw_tile()

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
	var target: Vector2 = card.position
	if not _slots.is_empty():
		var slot: CardSlot = _slots[_cards.size() % _slots.size()]
		_page = _cards.size() / _slots.size()
		_refresh_deck()
		target = _draw_layer.get_global_transform().affine_inverse() * slot.get_global_rect().get_center() - card.size * 0.5
	var on_fly_done := func() -> void:
		_draw_anim = false
		if _run_over:
			return
		_add_card(id)
		_zhongli_try(id)
	_draw_view.fly_card(card, target, on_fly_done)

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
	_draw_view.fade_cards_out()
	await get_tree().create_timer(0.2).timeout
	if _run_over:
		_draw_anim = false
		return
	_roll_draw()
	_draw_anim = false
	if _draw_layer.visible:
		_pop_draw_cards()
	_toast("刷新：5 灵晶" if paid else "免费刷新")

func _pop_draw_cards() -> void:
	if _draw_view != null:
		_draw_view.pop_cards()

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
	h["basic_skill_bonus"] = _skill_level_bonus("zhujue") / 100.0
	_sync_basic_family_bonus()
	h["crit"] = _core.attr_final("crit")
	h["crit_dmg"] = _core.attr_final("cdmg")
	h["cut"] = _core.type_effective_field("物理", "red_f")
	h["cut_all"] = 0.0
	h["dmg_all"] = _core.type_amp("物理")
	h["aspd"] = minf(MAX_ASPD, _core.attr_final("aspd") / float(_core.ATTR_BASE["aspd"]))
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

func _sync_basic_family_bonus() -> void:
	if _core != null:
		_core.hero["basic_family_bonus"] = float((_anc_mod.get("zhujue", {}) as Dictionary).get("dmg_pct", 0.0)) / 100.0

# 平加成长的即时桥也读属性层。等级成长保留血量比例，卡牌平加气血保留补新增量的规则。
func _apply_flat_growth(atk_add: float, hp_add: float, preserve_hp_ratio := false) -> void:
	if _core == null: return
	var h: Dictionary = _core.hero
	var old_max := float(h.get("hp_max", 0.0))
	var old_hp := float(h.get("hp", 0.0))
	var ratio := clampf(old_hp / maxf(1.0, old_max), 0.0, 1.0)
	_core.attr_add("atk", atk_add)
	_core.attr_add("hp", hp_add)
	h["atk"] = _core.attr_final("atk")
	h["hp_max"] = _core.attr_final("hp")
	if preserve_hp_ratio:
		h["hp"] = float(h["hp_max"]) * ratio
	else:
		h["hp"] = minf(old_hp, float(h["hp_max"]))
		_core.heal_hero(maxf(0.0, float(h["hp_max"]) - old_max))


# ---------------- 退出 ----------------
func _build_exit() -> void:
	if _exit_layer != null:
		return
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
	if v and not _no_ui:
		_build_exit()
	if _exit_layer == null:
		return
	_exit_open = v
	_exit_layer.visible = v
	if v:
		_exit_layer.move_to_front()

func _quit() -> void:
	if _run_over or not MenuUI.navigation_available(self): return
	if MenuUI.navigate(self, "res://menu/main_home.tscn") == OK:
		# 场景会延迟释放；离树后立即拒绝旧奖励和结算回调。
		_run_over = true
		_reset_camera()
		_clear_invocation_portrait()
		_clear_field_flash()
		_clear_lamp_field()
		if _core != null:
			_core.running = false
		if _tut != null:
			_tut.cancel()

# ---------------- 提示/动画 ----------------
func _build_toast() -> void:
	_toast_lb = RichTextLabel.new()
	_toast_lb.bbcode_enabled = true
	_toast_lb.fit_content = false
	_toast_lb.scroll_active = false
	_toast_lb.position = Vector2(100, 812)
	_toast_lb.size = Vector2(520, 48)
	_toast_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_lb.add_theme_font_override("normal_font", FONT)
	_toast_lb.add_theme_font_size_override("normal_font_size", 22)
	_toast_lb.add_theme_color_override("default_color", INK)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.97, 0.93, 0.84, 0.94)
	paper.border_color = Color(0.71, 0.53, 0.29, 0.75)
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(7)
	paper.content_margin_top = 7.0
	paper.content_margin_left = 12.0
	paper.content_margin_right = 12.0
	_toast_lb.add_theme_stylebox_override("normal", paper)
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
	var lamp_radius := _aura_radius() if _aura_active() else 0.0
	var lamp_radius_squared := lamp_radius * lamp_radius
	if lamp_radius > 0.0:
		_lamp_field.update_field(_core.hero_pos, lamp_radius)
	elif _lamp_field != null and _lamp_field.visible:
		_clear_lamp_field()
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
		if not _boss_spawned and not _run_cleared and int(_core.wave) >= _max_wave \
				and _core.wave_spawn_complete() and _core.live_foes() <= 0:
			_boss_spawned = true
			_core.start_boss(LevelState.boss_tier(), "")
		_run_time += _delta
		_combo_t += _delta
		if _combo_t >= 6.0:
			_combo_t -= 6.0
			_trigger_combos("每 6 秒")
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
		_refresh_wave_hud(int(_core.wave))
		var hpr := clampf(float(_core.hero.get("hp", 0.0)) / maxf(1.0, float(_core.hero.get("hp_max", 1.0))), 0.0, 1.0)
		# 逐关易伤规则集中在 balance_rules.gd（-1 = 本关不覆盖）
		var level_vuln := BalanceRules.level_vuln(LevelState.current_level, _equip_vuln, _combined, _ancestor_combos)
		if level_vuln >= 0.0:
			_core.foe_vuln = level_vuln
		if int(_core.wave) >= 2 and hpr <= 0.50:
			if LevelState.current_level == 1 and not _l1_yuhu_shown:
				_l1_yuhu_shown = true
				_l1_tutorial("l1_yuhu", _curio_sq, "气血不足时，玉壶会自动回血", _show_curio_detail)
		_tick_rare_buffs(_delta) # 到期先移除，再结算本帧技能，不能多借用一帧攻击。
		if _hp_fill != null:
			_tick_skills(_delta)
		_tick_curio(_delta)
		_refresh_vitals_hud()
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
					tkq.visible = false
					tkq.set_process(false)
					if _foe_pool.size() < 40:
						_foe_pool.append(tkq)
					else:
						tkq.queue_free()
					_recycle_q.remove_at(i)
		if _boss_bar != null:
			var bf: Dictionary = _core._boss_foe(false) if _core != null else {}
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
	if _combo_readout != null:
		_combo_readout.update_combo(int(_core._combo), float(_core._combo_t))
		if not _tick_battle_effects(_delta):
			return
		if _hero_token != null:
			_hero_token.position = _core.position + _core.hero_pos
			var hpr_tok := float(_core.hero.get("hp", 0.0)) / maxf(1.0, float(_core.hero.get("hp_max", 1.0)))
			if absf(hpr_tok - float(_hero_token.hp_ratio)) > 0.0015:
				_hero_token.hp_ratio = hpr_tok
				_hero_token.queue_redraw()
			if _hero_hit_btn != null:
				_hero_hit_btn.position = _hero_token.position - Vector2(48, 48 + _hero_token.radius)
			if _hero_name_lb != null:
				_hero_name_lb.position = _hero_token.position + HERO_NAME_OFFSET
			var hhp := float(_core.hero.get("hp", 0.0))
			if _prev_hero_hp >= 0.0 and hhp < _prev_hero_hp - 0.05:
				_spawn_hit_fx(_hero_token.position, _hero_token.radius,
					int(round(_prev_hero_hp - hhp)), true, false, false)
				_hero_token.play_hit()
			_prev_hero_hp = hhp
		var active := {}
		var was_dense := _dense_roster
		_update_roster_density()
		var density_changed := was_dense != _dense_roster
		var boss_casts := {}
		for hazard: Dictionary in _core._delayed:
			if not bool(hazard.get("boss_attack", false)) or bool(hazard.get("landed", false)):
				continue
			# 连爆只有首个落点对应首领的蓄力和释放。
			if int(hazard.get("chain_step", 0)) > 0:
				continue
			var caster: Dictionary = hazard.get("caster", {})
			var id := int(caster.get("_tid", 0))
			var first: Dictionary = boss_casts.get(id, {})
			if first.is_empty() or float(hazard["warn"]) - float(hazard["t"]) < float(first["warn"]) - float(first["t"]):
				boss_casts[id] = hazard
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
			var tid: int = int(f["_tid"])
			var tk := _foe_tokens.get(tid) as TokenActor
			var y := float(f["y"])
			var on_field := y >= MIN_VISIBLE_FOE_Y
			var hp := float(f["hp"])
			if tk == null and (not on_field or hp <= 0.0 or bool(f.get("_death_settled", false))):
				continue
			var ratio := hp / maxf(1.0, float(f["hp_max"]))
			var new_token := tk == null
			if new_token:
				tk = _make_foe_token(f)
				tk.hp_ratio = ratio
				_foe_tokens[tid] = tk
			active[tid] = true
			var feet := Vector2(float(f["x"]), y)
			tk.position = _core.position + feet
			if f.has("cold_t") or tk.frost_chilled or tk.frost_frozen:
				var alive := hp > 0.0 and float(f.get("dying", 0.0)) <= 0.0
				var chilled := alive and float(f.get("cold_t", 0.0)) > 0.0
				tk.set_frost(int(f.get("cold", 0)) if chilled else 0, chilled, alive and float(f.get("cold_freeze_t", 0.0)) > 0.0)
			if f.has("poison") or tk.poisoned:
				tk.set_poisoned(hp > 0.0 and float(f.get("dying", 0.0)) <= 0.0 and float(f.get("poison", 0.0)) > 0.0)
			if lamp_radius > 0.0:
				tk.set_lamp_lit(on_field and hp > 0.0 and float(f.get("dying", 0.0)) <= 0.0
					and feet.distance_squared_to(_core.hero_pos) <= lamp_radius_squared)
			if new_token or density_changed:
				# 类型在生成时确定，密度跨阈值时才重新计算血条样式。
				var ordinary: bool = f.get("kind", "") == "normal" and not f.has("rtype")
				var small_challenge := tk.challenge_kind >= 0 and tk.challenge_kind < 3
				var compact := _dense_roster and (ordinary or small_challenge)
				if compact != tk.compact_bar:
					tk.compact_bar = compact
					tk.queue_redraw()
			if bool(f.get("boss", false)):
				tk.boss_warning = boss_casts.get(tid, {})
			if ratio > 0.0 and ratio < tk.hp_ratio - 0.0015 and tk._hit_t <= 0.0:
				tk.play_hit(tk.position - _hero_token.position)
			if absf(ratio - tk.hp_ratio) > 0.0015:
				tk.hp_ratio = ratio
				tk.queue_redraw()
			if bool(f.get("_death_settled", false)):
				tk.play_down()
			tk.visible = on_field and not tk.death_finished()
		for tid in _foe_tokens.keys():
			if not active.has(tid):
				var tk = _foe_tokens[tid]
				if tk != null:
					tk.play_down()
					_recycle_q.append([tk, TokenActor.DEATH_DURATION + 0.04])
				_foe_tokens.erase(tid)
	var _el := Time.get_ticks_usec() - _t_proc
	if _el > 50000:
		print("[SLOW] battle_ui ", _el / 1000.0, " ms")

func _update_roster_density() -> void:
	var threshold := DENSE_ROSTER_EXIT if _dense_roster else DENSE_ROSTER_ENTER
	if _core.foes.size() >= threshold:
		var visible_count := 0
		for foe: Dictionary in _core.foes:
			if float(foe["y"]) >= MIN_VISIBLE_FOE_Y and float(foe["hp"]) > 0.0 and float(foe.get("dying", 0.0)) <= 0.0:
				visible_count += 1
				if visible_count == threshold:
					_dense_roster = true
					return
	_dense_roster = false

func _on_core_kill(n: int) -> void:
	if _run_over or _core == null or n <= 0:
		return
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
	var add_atk := 1.0 * float(n)
	var add_hp := 6.0 * float(n)
	_apply_flat_growth(add_atk, add_hp, true)
	_core.attr_add("mp", 25.0 * float(n))
	h["mp_max"] = _core.attr_final("mp")
	_stats["atk"] = float(_stats["atk"]) + add_atk
	_stats["hp"] = float(_stats["hp"]) + add_hp

func _refresh_level_ui() -> void:
	if _lv_lb != null:
		_lv_lb.text = "Lv " + str(_lv)
	if _exp_lb != null:
		_exp_lb.text = "%d/%d" % [_exp, _exp_need]
	if _exp_bar != null:
		var r := clampf(float(_exp) / maxf(1.0, float(_exp_need)), 0.0, 1.0)
		_exp_bar.size.x = maxf(4.0, _exp_track.size.x * r)
	if _mate_tile != null:
		var lit := _draw_charge > 0
		var subtitle := "待请神" if lit else "升级获得"
		if _mate_tile.hot != lit or _mate_tile.badge != _draw_charge or _mate_tile.sub != subtitle:
			_mate_tile.hot = lit
			_mate_tile.badge = _draw_charge
			_mate_tile.sub = subtitle
			_mate_tile.queue_redraw()

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
		_curio_uses += 1
		var epoch: int = _core._enemy_attack_epoch
		_paper_shatter()
		if not _skill_batch_active(epoch):
			return
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
	if _hero_token != null:
		_hero_token.play_down(_life > 0 and int(_core.wave) < _max_wave)
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
var _result_layer: ResultView = null
var _fallen_guardian: TokenActor
var _unrecorded_clear_level := 0
var _result_save_pending := false

func _save_result() -> Error:
	var SaveFile := preload("res://shared/save_file.gd")
	var err := SaveFile.recover()
	if err != OK or _unrecorded_clear_level == 0:
		return err
	var lv := _unrecorded_clear_level
	LevelState.ensure_loaded()
	GameState.ensure_loaded()
	var reward := LevelState.first_reward(lv)
	if reward.has("equip") or reward.has("forge_mat"):
		preload("res://shared/forge_data.gd").load_game()
	err = SaveFile.begin()
	if err != OK:
		return err
	if LevelState.mark_first_clear(lv):
		_grant_first_clear(lv)
	# 提交失败时已有待恢复快照，重试只重放快照，不能再发奖励。
	_unrecorded_clear_level = 0
	return SaveFile.commit()

func _end_run(win: bool) -> void:
	if _run_over:
		return
	if _core != null:
		_refresh_wave_hud(int(_core.wave), win)
		_refresh_vitals_hud()
	if win:
		_unrecorded_clear_level = LevelState.current_level
		_result_save_pending = _save_result() != OK
		# 局内文钱不结转：局外是局外（首通奖励单独发，见 _grant_first_clear）。
		if OS.get_environment("DSH_DEBUG") != "":
			print("[RUN] lv=", LevelState.current_level, " wave=", _max_wave, " kills=", _kills,
				" wen=", _wen, " crystal=", _crystal)
	_run_over = true
	_clear_invocation_portrait()
	_clear_lamp_field()
	if _hero_token != null:
		_hero_token.cancel_cast_poses()
	_close_challenge()
	_show_draw(false)
	_hide_aug_pick()
	_hide_trea()
	_hide_god_pick()
	_close_curio_detail(_curio_detail)
	if _tut != null:
		_tut.cancel()
	_q_close_popup()
	if _bm != null:
		_bm.close_panel()
	if _core != null:
		_core.running = false
		_core.clear_enemy_attacks()
	for token in _foe_tokens.values():
		if is_instance_valid(token):
			token.boss_warning = {}
			token.set_frost(0, false, false)
			token.set_poisoned(false)
	_reset_camera()
	# 结算前的"定格式"反馈：一闪 + 长顿帧，然后才弹面板
	_screen_flash(Color(1.0, 0.96, 0.82) if win else Color(0.52, 0.17, 0.13), 0.34 if win else 0.28, 0.5)
	if _core != null:
		_core._hitstop = maxf(float(_core._hitstop), 0.30)
	if win:
		for i in 10:
			_spawn_fly(Vector2(360, 470), _chip_target("文钱"), Color(0.92, 0.74, 0.32), 1)
	var reveal_delay := 0.0
	if win and is_instance_valid(_fallen_guardian) and _fallen_guardian.guardian:
		reveal_delay = _fallen_guardian.death_time_left()
	_build_result(win, reveal_delay)

func _build_result(win: bool, reveal_delay := 0.0) -> void:
	var view := ResultView.new()
	view.name = "ResultView"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.z_index = 40
	add_child(view)
	_result_layer = view
	view.set_save_blocked(_result_save_pending)
	view.replay_pressed.connect(func() -> void: _leave_result(true))
	view.home_pressed.connect(func() -> void: _leave_result(false))
	# 结局面特效仍由战斗舞台播放（特效系统不搬进视图）
	view.on_presented = func(fx: String, pos: Vector2) -> void:
		_spawn_pfx(fx, pos, 1.9, "holy" if win else "shadow", 1.8)
	var payload := {
		"win": win,
		"wave": int(_core.wave) if _core != null else 0,
		"max_wave": _max_wave,
		"kills": _kills,
		"wen": _wen,
		"crystal": _crystal,
		"bonds": _bonds.size(),
		"bonds_done": _bonds_done,
		"run_time": _run_time,
	}
	if reveal_delay > 0.0:
		var reveal := create_tween().bind_node(view)
		reveal.tween_interval(reveal_delay)
		reveal.tween_callback(view.present.bind(payload))
	else:
		view.present(payload)

# 结果页按钮同时作为保存重试入口，未保存完成时保留当前场景。
func _leave_result(replay: bool) -> void:
	if not _run_over or _result_layer == null or not MenuUI.navigation_available(self): return
	if not _try_save_result_before_exit():
		return
	if replay:
		MenuUI.navigate(self, scene_file_path)
	else:
		MenuUI.navigate(self, "res://menu/main_home.tscn")

func prepare_window_close() -> bool:
	# 正常关闭窗口时，给仍在内存里的首通结果一次保存机会。
	return not _result_save_pending or _try_save_result_before_exit()

func _try_save_result_before_exit() -> bool:
	var saved := _save_result() == OK
	if saved:
		_result_save_pending = false
	if is_instance_valid(_result_layer):
		_result_layer.set_save_blocked(not saved)
	return saved

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
			if _str_tile != null:
				var track_end: float = _str_tile.position.x - 16.0
				_exp_track.size.x = track_end - _exp_track.position.x
				_exp_lb.position.x = track_end - _exp_lb.size.x
				_refresh_level_ui()
			_l1_tutorial("l1_wen", _str_tile,
				"强化可以强化自身\n提升气血、内力和伤害（强化 Lv1）",
				func() -> void:
					_l1_tutorial("l1_wen2", _chips.get("文钱"),
						"强化需要消耗文钱",
						_on_str_tile))

func _l1_tutorial(key: String, target: Node, text: String, cb: Callable) -> void:
	_tutorial(key, target, text, cb)

func _tutorial(key: String, target: Node, text: String, cb: Callable) -> void:
	if _run_over or _tut == null or not MenuUI.navigation_available(self):
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
		MenuUI.Motion.reject_button(_mate_tile)
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
		MenuUI.Motion.reject_button(_str_tile)
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
	l.position = _str_tile.position - Vector2(0, 60) if _str_tile != null else Vector2(426, 1068)
	l.size = Vector2(_str_tile.size.x if _str_tile != null else 124.0, 26)
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
	_qc("str", n)
	var add_atk := STR_PER_ATK * float(n)
	var add_hp := STR_PER_HP * float(n)
	_apply_flat_growth(add_atk, add_hp, true)
	var cut_add := STR_PER_CUT * float(n)
	for t in _core.DMG_TYPES:
		if t != "真实":
			_core.type_add(t, "red_f", cut_add)
	h["cut"] = _core.type_effective_field("物理", "red_f")
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

const AUG_ART := {
	"atk_pct": "it_sword", "hp_pct": "mat_bone", "aspd_pct": "it_dart",
	"crit_add": "it_spear", "critdmg_add": "it_blade", "cut_add": "it_armor",
	"cutall_add": "armor2", "pen_flat": "it_sword2", "dmgall_add": "fate_sharpen",
	"mp_add": "it_jar", "gold_pct": "it_ingot", "killheal": "it_herb",
}

func _build_str() -> void:
	if _str_layer != null:
		return
	var view := ChoicePanelView.new()
	view.configure("进阶", "")
	view.name = "AugView"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.visible = false
	view.z_index = 21
	view.card_factory = func() -> Control: return AugCard.new()
	view.hide_pressed.connect(_hide_aug_pick)
	view.refresh_pressed.connect(_on_aug_refresh)
	view.abandon_pressed.connect(_on_aug_abandon)
	view.card_picked.connect(func(card) -> void: _on_aug_card(card as AugCard))
	add_child(view)
	view.build()
	_aug_view = view
	_str_layer = view
	_aug_cards = view.cards
	_aug_refresh_btn = view.refresh_btn
	_str_ban_lb = view.caption

func _open_aug_pick() -> void:
	if _run_over or not _str_pending or _no_ui:
		return
	_build_str()
	_close_challenge()
	if _draw_layer != null:
		_show_draw(false)
	_hide_trea()
	_hide_god_pick()
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
		_str_ban_lb.text = "强化 %d 级" % _str_lv
	_aug_view.open()
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
		ac.o = {}
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
			ac.artwork = _choice_item(str(AUG_ART.get(str(o["key"]), "")))
			ac.visible = true
			ac.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			ac.visible = false
		ac.refresh_face()
	_refresh_aug_btn()

func _refresh_aug_btn() -> void:
	if _aug_refresh_btn != null:
		_aug_refresh_btn.text = "刷新 · %d 次" % maxi(0, _aug_reroll)
		_aug_refresh_btn.disabled = _aug_reroll <= 0

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
	if _aug_view != null:
		_aug_view.pop_cards()

func _hide_aug_pick() -> void:
	if _aug_view != null:
		_aug_view.close()

func _on_aug_card(card: AugCard) -> void:
	if _run_over or not _str_pending or _str_layer == null or not _str_layer.visible or card == null or not _aug_cards.has(card) or card.o.is_empty():
		return
	_pick_aug(card.o, int(card.oval))

func _pick_aug(o: Dictionary, val: int) -> void:
	if _run_over or not _str_pending:
		return
	if not _aug_has_effect(str(o.get("key", ""))):
		_roll_aug()
		_pop_aug_cards()
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

func _build_trea() -> void:
	if _trea_layer != null:
		return
	var view := ChoicePanelView.new()
	view.configure("宝物", "选择一件")
	view.name = "TreasureView"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.visible = false
	view.z_index = 22
	view.card_factory = func() -> Control: return AugCard.new()
	view.hide_pressed.connect(_hide_trea)
	view.refresh_pressed.connect(_on_trea_refresh)
	view.abandon_pressed.connect(_on_trea_abandon)
	view.card_picked.connect(func(card) -> void: _on_trea_card(card as AugCard))
	add_child(view)
	view.build()
	_trea_view = view
	_trea_layer = view
	_trea_cards = view.cards
	_trea_refresh_btn = view.refresh_btn

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
	var count := 1 if _trea_pending else maxi(0, _trea_charge)
	if _trea_tile.sub != s or _trea_tile.hot != hot or _trea_tile.badge != count:
		_trea_tile.sub = s
		_trea_tile.hot = hot
		_trea_tile.badge = count
		_trea_tile.queue_redraw()

# 点［宝物］：有一手没选就接着看那一手；否则花掉一次机会、掷三张
func _on_trea_tile() -> void:
	if not LevelState.show_button("treasure"):
		return
	if _trea_pending:
		_open_trea()
		return
	if _trea_charge <= 0:
		MenuUI.Motion.reject_button(_trea_tile)
		_toast("还没攒到宝物机会（每清一波 +1）")
		return
	if _bond_pool().is_empty() and _rare_pool().is_empty():
		MenuUI.Motion.reject_button(_trea_tile)
		_toast("本局宝物已抽空")
		return
	_trea_charge -= 1
	_trea_pending = true
	_roll_trea()
	_refresh_trea_tile()
	_open_trea()

func _open_trea() -> void:
	if _no_ui:
		return
	_build_trea()
	_close_challenge()
	if _draw_layer != null:
		_show_draw(false)
	_hide_aug_pick()
	_hide_god_pick()
	_trea_view.open()
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
	if _no_ui:
		return
	_build_trea()
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
		c.o = o
		if o.is_empty():
			c.visible = false
			continue
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
		c.artwork = _choice_item(_treasure_art_key(o))
		c.visible = true
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.refresh_face()
	_refresh_trea_btn()

# 灵晶一切收入的唯一入口（「倾囊」把 _crystal_lock 打开后，这里就再也不给）
func _gain_crystal(n: int) -> void:
	if n <= 0 or _crystal_lock:
		return
	_crystal += n
	_update_crystal()
	_pulse_chip(_crystal_lb)
	_spawn_fly(_hero_screen() + Vector2(0, -30), _chip_target("灵晶"), Color(0.52, 0.78, 0.88), 2)

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

# 限时 buff：快照一份增幅前的固定攻击，到点只移除自身这一份。
func _apply_rare_buff(o: Dictionary) -> void:
	if _run_over or _core == null:
		return
	var pct := float(o.get("v", 0)) / 100.0
	var dur := float(o.get("dur", 30))
	var a: Dictionary = _core.attr["atk"]
	var add := (float(a["base"]) + float(a["temp"])) * pct
	_core.attr_add("atk", add)
	_core.hero["atk"] = _core.attr_final("atk")
	_rare_buffs.append({"raw_atk": add, "t": dur})
	_toast("稀有 · 攻击 +%d%%（%d 秒）" % [int(o.get("v", 0)), int(dur)])

func _tick_rare_buffs(dt: float) -> void:
	if _run_over or _rare_buffs.is_empty() or _core == null or dt <= 0.0:
		return
	for i in range(_rare_buffs.size() - 1, -1, -1):
		var rb: Dictionary = _rare_buffs[i]
		rb["t"] = float(rb["t"]) - dt
		if float(rb["t"]) <= 0.0:
			_core.attr_add("atk", -float(rb["raw_atk"]))
			_core.hero["atk"] = _core.attr_final("atk")
			_rare_buffs.remove_at(i)

func _refresh_trea_btn() -> void:
	if _trea_refresh_btn != null:
		_trea_refresh_btn.text = "刷新 · %d 次" % maxi(0, _trea_reroll)
		_trea_refresh_btn.disabled = _trea_reroll <= 0

func _pop_trea_cards() -> void:
	if _trea_view != null:
		_trea_view.pop_cards()

func _hide_trea() -> void:
	if _trea_view != null:
		_trea_view.close()

func _on_trea_card(card: AugCard) -> void:
	if _run_over or not _trea_pending or _trea_layer == null or not _trea_layer.visible or card == null or not _trea_cards.has(card) or card.o.is_empty():
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
					if aid2 == "zhujue": _sync_basic_family_bonus()
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
	MenuUI.Motion.fade_in(c)

func _hide_choice_layer(layer: Control, cards: Array) -> void:
	if layer == null or not layer.visible:
		return
	layer.hide()
	MenuUI.Motion.stop(layer)
	for card: Control in cards:
		MenuUI.Motion.stop(card)

func _show_totals() -> void:
	if _no_ui:
		return
	_build_combined()
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
class AugCard extends Button:
	const F := preload("res://fonts/ink.ttf")
	const P := preload("res://shared/ui_pal.gd")
	const Motion := preload("res://shared/ui_motion.gd")
	signal picked
	var title := ""
	var glyph := ""
	var effect := ""
	var desc := ""
	var quality := 2
	var o: Dictionary = {}
	var oval := 0
	var artwork: Texture2D
	var _effect_ink: Label
	var _desc_ink: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		var blank := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, blank)
		_effect_ink = _text_block(Rect2(10, 178, 156, 51), 18, Color(0.98, 0.87, 0.65))
		_desc_ink = _text_block(Rect2(13, 231, 150, 61), 16, Color(0.88, 0.82, 0.70))
		resized.connect(func():
			_effect_ink.size.x = size.x - 20
			_desc_ink.size.x = size.x - 26)
		pressed.connect(func(): picked.emit())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		Motion.bind_button(self)

	func _text_block(rect: Rect2, font_size: int, color: Color) -> Label:
		var block := Label.new()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		block.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		block.max_lines_visible = 3
		block.add_theme_font_override("font", F)
		block.add_theme_font_size_override("font_size", font_size)
		block.add_theme_color_override("font_color", color)
		block.position = rect.position
		block.size = rect.size
		add_child(block)
		return block

	func refresh_face() -> void:
		_effect_ink.text = effect
		_desc_ink.text = desc
		tooltip_text = effect + "\n" + desc
		queue_redraw()

	func _draw() -> void:
		if o.is_empty():
			return
		var tone := P.quality(quality)
		var rim := tone.lerp(Color(0.91, 0.76, 0.48), 0.65)
		if is_hovered():
			rim = rim.lightened(0.18)
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.195, 0.155, 0.109)
		frame.set_corner_radius_all(10)
		frame.border_color = rim
		frame.set_border_width_all(2)
		frame.shadow_color = Color(0.02, 0.015, 0.01, 0.7)
		frame.shadow_size = 5
		frame.shadow_offset = Vector2(0, 3)
		draw_style_box(frame, Rect2(Vector2.ZERO, size))
		var paper := StyleBoxFlat.new()
		paper.bg_color = Color(0.88, 0.83, 0.70).lerp(tone, 0.16)
		paper.set_corner_radius_all(7)
		paper.border_color = rim
		paper.set_border_width_all(1)
		draw_style_box(paper, Rect2(8, 48, size.x - 16, 126))
		var c := Vector2(size.x * 0.5, 111)
		draw_circle(c, 48, Color(0.96, 0.91, 0.77, 0.80), true, -1.0, true)
		draw_arc(c, 48, 0, TAU, 42, Color(tone, 0.48), 1.3, true)
		if artwork == null:
			draw_string(F, Vector2(10, 124), glyph, HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 38, P.INK)
		else:
			var source := artwork.get_size()
			var fit := source * (92.0 / maxf(source.x, source.y))
			draw_texture_rect(artwork, Rect2(c - fit * 0.5, fit), false)
		var rare := bool(o.get("rare", false))
		var grade: String = "稀有" if rare else ["凡品", "良品", "玄品", "地品", "天品"][clampi(quality - 1, 0, 4)]
		draw_string(F, Vector2(10, 33), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 62, 22, P.PAPER_HI)
		draw_string(F, Vector2(size.x - 49, 32), grade, HORIZONTAL_ALIGNMENT_RIGHT, 38, 14, rim.lightened(0.22))
		draw_line(Vector2(12, 298), Vector2(size.x - 12, 298), Color(rim, 0.57), 1.0, true)
		draw_string(F, Vector2(8, 321), "选取", HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 18, rim.lightened(0.25))



func _foe_display_name(foe: Dictionary) -> String:
	if str(foe.get("kind", "normal")) == "normal":
		if bool(foe.get("mage", false)):
			return "符杖术士"
		if bool(foe.get("ranged", false)):
			return "山匪弓手"
		if bool(foe.get("brute", false)):
			return "山匪壮汉"
		if bool(foe.get("shield", false)):
			return "山匪盾兵"
		if _foe_animation_cache.get("crowd_bandit") != null:
			return "山匪"
	return str(foe.get("name", ""))

func _make_foe_token(f: Dictionary):
	var kind := str(f.get("kind", "normal"))
	var boss := bool(f.get("boss", false))
	var challenge := clampi(int(f.get("chal", -1)), -1, 4)
	var rad := 52.0 if boss else 26.0
	if kind == "normal" and bool(f.get("brute", false)):
		rad = 30.0
	if challenge == 3:
		rad = 41.0
	elif challenge == 4:
		rad = 47.0
	var ring := Color(0.42, 0.36, 0.28)
	if challenge >= 0:
		ring = CHALLENGE_RIMS[challenge]
	elif kind == "coin":
		ring = Color(0.95, 0.78, 0.25)        # 钱怪：亮金
	elif kind == "crystal":
		ring = Color(0.42, 0.72, 0.95)        # 晶怪：亮蓝
	elif kind == "chal":
		ring = Color(0.68, 0.38, 0.88)        # 挑战怪：紫
	elif boss:
		ring = Color(0.95, 0.62, 0.12)        # Boss：金橙
	var title := _foe_display_name(f)
	var frames: Texture2D = null
	if kind == "normal":
		frames = _foe_animation_cache.get(BattleArt.CROWD_FRAME_PATH.get(title, "")) as Texture2D
		if frames == null:
			frames = _foe_animation_cache.get(BattleArt.CROWD_FRAME_PATH["山匪"]) as Texture2D
	var frame_id := str(BattleArt.FOE_FRAME_PATH.get(title, ""))
	if frames == null and not frame_id.is_empty():
		if not _foe_animation_cache.has(frame_id):
			_foe_animation_cache[frame_id] = _entry_texture(_foe_frame_path(frame_id))
		frames = _foe_animation_cache[frame_id] as Texture2D
	var foe_tex := _foe_art(str(f.get("name", ""))) if frames == null else null
	var needs_mark := foe_tex == null and frames == null
	var fresh := _foe_pool.is_empty()
	var tk: TokenActor = TokenActor.new() if fresh else _foe_pool.pop_back()
	tk.position = _core.position + Vector2(float(f["x"]), float(f["y"]))
	tk.round_mask = needs_mark
	tk.challenge_kind = challenge
	tk.guardian = boss and challenge < 0
	tk.set_role("enemy")
	tk.setup(foe_tex, rad, ring, false, frames)
	tk.hp_ratio = 1.0
	tk.show_bar = true
	tk.bar_w = 84.0 if boss else 54.0
	tk.unit_name = title
	var mark: Label = tk.get_meta("mark") if tk.has_meta("mark") else null
	if needs_mark:
		if mark == null:
			mark = Label.new()
			mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			mark.add_theme_font_override("font", FONT)
			mark.add_theme_color_override("font_color", Color(0.30, 0.24, 0.16))
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tk.add_child(mark)
			tk.set_meta("mark", mark)
		mark.text = "王" if boss else ("钱" if kind == "coin" else ("晶" if kind == "crystal" else ("挑" if kind == "chal" else "怪")))
		mark.position = Vector2(-rad, -rad * 2.0 + 6.0)
		mark.add_theme_font_size_override("font_size", 38 if boss else 22)
		mark.size = Vector2(rad * 2.0, rad * 1.5)
	if mark != null:
		mark.visible = needs_mark
	if fresh:
		tk.z_index = 5
		_cam.add_child(tk)
	else:
		tk.reset_pose()
		tk.set_process(true)
		tk.queue_redraw()
	tk.play_spawn(float(int(f.get("_tid", 0)) % 4) * 0.02)
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
	if _run_over:
		return
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
	if _run_over or _core == null or amount <= 0:
		return
	_add_wen(amount)
	_spawn_fly(_core.position + pos + Vector2(0, -18), _chip_target("文钱"), Color(0.90, 0.71, 0.30), 3 if amount >= 20 else 1)

func _chip_target(key: String) -> Vector2:
	var chip := _chips.get(key) as Control
	if chip == null or not chip.is_visible_in_tree():
		return Vector2.INF
	return chip.position + Vector2(24, 25)

# 撒一把飞向資源条的小点（金币金、灵晶蓝）
func _spawn_fly(from: Vector2, to: Vector2, col: Color, n: int) -> void:
	if to == Vector2.INF:
		return
	for i in n:
		if _fly.size() > 60:
			break
		_fly.append({"sx": from.x + randf_range(-16.0, 16.0), "sy": from.y + randf_range(-12.0, 12.0),
			"x": from.x, "y": from.y,
			"tx": to.x + randf_range(-18.0, 18.0), "ty": to.y + randf_range(-8.0, 8.0),
			"t": randf_range(0.0, 0.12), "col": col, "r": randf_range(4.5, 7.0)})

# 整屏微闪（技能释放/大事件用）：暖纸色一闪，不刺眼
# 镜头推进（缩放战场内容，不动 HUD）
# 临时推镜结束后回到首领战或普通战斗的当前机位。
func _cam_pulse(s: float, hold: float) -> void:
	if _cam == null or _run_over:
		return
	var tw := _begin_camera_tween()
	var approach := minf(0.26, hold)
	tw.tween_property(_cam, "scale", Vector2.ONE * s, approach)
	if hold > approach:
		tw.tween_interval(hold - approach)
	tw.tween_property(_cam, "scale", _camera_base_scale, 0.42)

func _cam_zoom_to(s: float, dur: float) -> void:
	if _cam == null or _run_over:
		return
	_camera_base_scale = Vector2.ONE * s
	_begin_camera_tween().tween_property(_cam, "scale", _camera_base_scale, dur)

func _begin_camera_tween() -> Tween:
	_cancel_camera_tween()
	_camera_tween = create_tween().bind_node(_cam).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return _camera_tween

func _cancel_camera_tween() -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null

func _reset_camera() -> void:
	_cancel_camera_tween()
	_camera_base_scale = Vector2.ONE
	if _cam != null:
		_cam.scale = _camera_base_scale

func _screen_flash(col: Color, a: float, dur := 0.16) -> void:
	if _flash_rect == null:
		return
	_clear_field_flash()
	_flash_rect.color = Color(col.r, col.g, col.b, a)
	_flash_tween = create_tween().bind_node(_flash_rect)
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, dur)

func _clear_field_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	if _flash_rect != null:
		_flash_rect.color.a = 0.0

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

func _skill_cast_juice(aid: String = "") -> void:
	if _hero_token != null:
		_hero_token.play_skill_cast(int(BattleArt.HERO_SKILL_ROWS.get(aid, -1)), _skill_pose_direction)
	var tint: Color = SKILL_TINT.get(_cast_dtype, Color(1.0, 0.94, 0.80))
	if _fx_front != null:
		_fx_front.spawn_cast_seal(_hero_screen() - FIELD_POS, tint)
	var layers: Array = PICKPOCKET_SFX if aid == "xiaoqier" else SKILL_SFX.get(_cast_dtype, [])
	for layer: Array in layers:
		Aud.sfx(str(layer[0]), float(layer[1]), float(layer[2]))
	_core._shake = maxf(float(_core._shake), 5.0)
	_core._hitstop = maxf(float(_core._hitstop), 0.045)

func _pulse_chip(lb: Label) -> void:
	if lb == null:
		return
	lb.pivot_offset = Vector2(lb.size.x, lb.size.y * 0.5)
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
				_apply_flat_growth(val, 0.0)
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
				_apply_flat_growth(0.0, val)
		"heal":
			if _core != null: _core.heal_hero(val)
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
		_apply_flat_growth(float(s["atk"]), float(s["hp"]))
		# v6：防御卡不再加「数值减伤」，改成七系固定减免（1 点防御 = 3% 减免，跟旧手感对齐）
		var def_red := float(s["def"]) * DEF_CARD_TO_RED
		if def_red > 0.0:
			for t in _core.DMG_TYPES:
				if t != "真实":
					_core.type_add(t, "red_f", def_red)

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

const BOSS_IMPACT_SOUNDS := {
	"sector": "boss_impact_sweep",
	"beam": "boss_impact_charge",
	"follow": "boss_impact_tracker",
}

func _on_boss_impact(hazard: Dictionary) -> void:
	if _run_over:
		return
	if int(hazard.get("chain_step", 0)) > 0:
		# 慢帧内补结算多个落点时，音效池只放一次短爆。
		Aud.sfx("boss_chain_pop", -17.0, 1.0, 100)
		return
	var pos := Vector2(float(hazard["x"]), float(hazard["y"]))
	var shape := str(hazard["shape"])
	var caster: Dictionary = hazard.get("caster", {})
	var sound := "boss_impact_chain" if hazard.has("chain_step") else str(BOSS_IMPACT_SOUNDS.get(shape, "boss_impact_ground"))
	Aud.sfx(sound, -8.0, 1.0, 140)
	if shape == "ring":
		_hazard_view.flash_ring(pos, float(hazard["r"]) + HazardTelegraph.RING_PADDING)
	elif shape == "sector":
		_hazard_view.flash_sector(pos, Vector2(hazard["dir"]), float(hazard["r"]), float(hazard["spread"]))
	var token := _foe_tokens.get(int(caster.get("_tid", 0))) as TokenActor
	if token != null:
		var direction: Vector2 = _core.position + pos - token.position
		if shape == "sector" or shape == "beam" or hazard.has("chain_step"):
			direction = Vector2(hazard["dir"]) * 40.0
		if is_same(token.boss_warning, hazard):
			token.boss_warning = {}
		token.play_boss_impact(direction)
		if shape == "follow" and caster.get("name", "") == "毒牙蟒" and _fx_front != null:
			var mouth := token.position - FIELD_POS - Vector2(0, token.radius * 2.0)
			_fx_front.spawn_skill_trail(mouth, _core.position + pos - FIELD_POS, Color(0.68, 0.84, 0.37), 13.0)

# 首领倒下：白闪 + 大爆 + 金耀 + 重震，配一段很短的慢镜头
# 纸人 Lv5：在核心那边挡下了首领延迟技
func _on_paper_blocked(pos: Vector2) -> void:
	if _run_over or _core == null or _curio_id != "zhiren":
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	_set_paper_count(mini(_zhiren - 1, int(_core.hero.get("paper_guard", 0))))
	_curio_uses += 1
	_paper_shatter()
	if not _skill_batch_active(epoch):
		return
	_curio_flash()
	_toast("纸人替身 · 挡下首领一击（剩 %d）" % _zhiren)
	Aud.sfx("paper", -8.0, 1.0)
	if _core != null:
		_spawn_pfx("holy/heal", _core.position + pos, 1.0, "heal", 1.5)

func _on_boss_died(pos: Vector2) -> void:
	if _run_over or _core == null:
		return
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
	elif str(id) in ["shiny_liuqingqing", "shiny_liuqingqing2"]:
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
	var claimed_at := _cards.find(id)
	_page = (claimed_at if claimed_at >= 0 else maxi(0, _cards.size() - 1)) / 5
	_refresh_deck()
	_toast_card(str(c["name"]), int(c["quality"]), "已入卡组")
	_draw_paid = false
	_show_draw(false)

func _build_combined() -> void:
	if _combined_layer != null:
		return
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

func _play_attack_fx() -> void:
	if _core == null or _fx_back == null or _hero_token == null:
		return
	var tgt: Dictionary = _core._hero_pending
	if tgt.is_empty():
		tgt = _core._nearest()
	if tgt.is_empty():
		return
	var destination: Vector2 = _core.position + Vector2(float(tgt["x"]), float(tgt["y"]))
	var windup: float = _core._hero_pending_t
	_hero_token.play_attack(destination - _hero_token.position, windup)
	if _frame_fx_art == null:
		_fx_back.spawn_swing(_hero_token.position - FIELD_POS, destination - FIELD_POS, _hero_token.radius, windup)

func _hero_slash_frames(target: Dictionary) -> void:
	if _run_over or _frame_fx_art == null or _hero_token == null or _core == null or target.is_empty():
		return
	var from: Vector2 = _hero_token.position - Vector2(0, 43)
	var dst: Vector2 = _core.position + Vector2(float(target["x"]), float(target["y"]) - 34)
	_spawn_frame_burst(0, from.lerp(dst, 0.60), 0.98, 0.17, (dst - from).angle())

func _spawn_hit_fx(global_pos: Vector2, radius: float, dmg: int, hero_hit: bool, crit: bool, heavy: bool) -> void:
	if _fx_front != null:
		_fx_front.spawn_hit(global_pos - FIELD_POS, radius, dmg, hero_hit, crit, heavy)

class ComboReadout extends Control:
	var count := 0
	var _pulse := 0.0
	var _milestone := 0.0
	var _remaining := 0.0
	var _frame := StyleBoxFlat.new()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		hide()
		set_process(false)
		_frame.set_corner_radius_all(9)
		_frame.set_border_width_all(1)

	func update_combo(value: int, remaining: float) -> void:
		_remaining = remaining
		var show_combo := value >= 3 and remaining > 0.0
		if visible != show_combo:
			visible = show_combo
			set_process(show_combo)
		if count != value:
			if value / 10 > count / 10:
				_milestone = 1.0
			elif value < count:
				_milestone = 0.0
			count = value
			_pulse = 1.0
			queue_redraw()

	func _process(dt: float) -> void:
		_pulse = maxf(0.0, _pulse - dt * 5.5)
		_milestone = maxf(0.0, _milestone - dt * 2.8)
		modulate.a = smoothstep(0.0, 0.22, _remaining)
		queue_redraw()

	func _draw() -> void:
		var accent := Color(1.0, 0.72, 0.32) if count >= 10 else Color(0.86, 0.70, 0.41)
		_frame.bg_color = Color(0.13, 0.095, 0.067, 0.96).lerp(Color(0.39, 0.19, 0.08, 0.96), _milestone)
		_frame.border_color = Color(accent, 0.60 + _milestone * 0.40)
		draw_style_box(_frame, Rect2(Vector2.ZERO, size))
		draw_string(FONT, Vector2(14, 34), "连斩", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.98, 0.91, 0.74))
		var pop := 1.0 + (0.11 + 0.15 * _milestone) * sin(_pulse * PI)
		draw_string(FONT, Vector2(65, 39), "×%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, 86, roundi(34.0 * pop), accent)
		var width := (size.x - 24.0) * clampf(_remaining / BattleCore.COMBO_WINDOW, 0.0, 1.0)
		draw_rect(Rect2(12, 49, size.x - 24.0, 3), Color(0.31, 0.23, 0.14))
		draw_rect(Rect2(12, 49, width, 3), accent)

class FrameBurst extends Sprite2D:
	signal finished

	var row := 0
	var lifetime := 0.24
	var elapsed := 0.0
	var _shown := -1
	var _side := 0.0

	func _ready() -> void:
		region_enabled = true
		region_filter_clip_enabled = true
		z_index = 7

	func play(art: Texture2D, atlas_row: int, at: Vector2, size_mul: float, duration: float, angle: float) -> void:
		texture = art
		_side = float(art.get_width()) / 4.0
		row = atlas_row
		position = at
		scale = Vector2.ONE * size_mul
		rotation = angle
		flip_h = false
		lifetime = duration
		elapsed = 0.0
		_shown = -1
		modulate.a = 1.0
		_show(0)
		show()
		set_process(true)

	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed >= lifetime:
			hide()
			set_process(false)
			texture = null
			finished.emit()
			return
		_show(mini(3, int(elapsed * 4.0 / lifetime)))
		modulate.a = 1.0 - smoothstep(0.71, 1.0, elapsed / lifetime)

	func _show(index: int) -> void:
		if index == _shown:
			return
		_shown = index
		region_rect = Rect2(_side * index, _side * row, _side, _side)

func _spawn_frame_burst(row: int, at: Vector2, size_mul: float, duration: float, angle := 0.0, atlas: Texture2D = null, priority := false) -> Sprite2D:
	var art := _frame_fx_art if atlas == null else atlas
	var limit := FRAME_FX_LIMIT if priority else FRAME_FX_AMBIENT_LIMIT
	if art == null or _cam == null or _frame_fx_live >= limit:
		return null
	var burst: FrameBurst
	if _frame_fx_pool.is_empty():
		burst = FrameBurst.new()
		burst.finished.connect(_recycle_frame_burst.bind(burst))
		_cam.add_child(burst)
	else:
		burst = _frame_fx_pool.pop_back()
		_cam.move_child(burst, _cam.get_child_count() - 1)
	_frame_fx_live += 1
	burst.play(art, row, at, size_mul, duration, angle)
	return burst

func _recycle_frame_burst(burst: FrameBurst) -> void:
	_frame_fx_live -= 1
	_frame_fx_pool.append(burst)

# 同一图层绘制短火花。密集毒伤只取分散的几个落点。
class ImpactSparks extends Node2D:
	const LIMIT := 18
	const POISON_LIMIT := 8
	const POISON_SPACING_SQ := 30.0 * 30.0
	var sparks: Array[Dictionary] = []
	var _rng := RandomNumberGenerator.new()
	var _segments := PackedVector2Array()

	func _ready() -> void:
		z_index = 7
		_rng.randomize()
		set_process(false)

	func spawn(at: Vector2, radius_scale: float, tint: Color, lifetime: float, poison: bool) -> void:
		if poison:
			if sparks.size() >= LIMIT or _rng.randf() >= 0.6:
				return
			var poison_count := 0
			for spark in sparks:
				if spark["poison"]:
					poison_count += 1
					if at.distance_squared_to(spark["pos"]) < POISON_SPACING_SQ or poison_count >= POISON_LIMIT:
						return
		elif sparks.size() >= LIMIT:
			var ambient := sparks.find_custom(func(spark: Dictionary) -> bool: return spark["poison"])
			sparks.remove_at(maxi(0, ambient))
		var n := _rng.randi_range(6, 8)
		var dirs := PackedVector2Array()
		dirs.resize(n)
		for i in n:
			var angle := TAU * float(i) / float(n) + _rng.randf_range(-0.4, 0.4)
			dirs[i] = Vector2.from_angle(angle) * _rng.randf_range(0.8, 1.3)
		sparks.append({"pos": at, "scale": radius_scale, "tint": tint, "life": lifetime,
			"age": 0.0, "dirs": dirs, "poison": poison})
		set_process(true)
		queue_redraw()

	func _process(dt: float) -> void:
		for i in range(sparks.size() - 1, -1, -1):
			var spark: Dictionary = sparks[i]
			spark["age"] += dt
			if spark["age"] >= spark["life"]:
				sparks.remove_at(i)
		if sparks.is_empty():
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		for spark in sparks:
			var fade := 1.0 - float(spark["age"]) / float(spark["life"])
			var tint: Color = spark["tint"]
			var dirs: PackedVector2Array = spark["dirs"]
			draw_set_transform(spark["pos"], 0.0, Vector2.ONE * float(spark["scale"]))
			draw_circle(Vector2.ZERO, 6.0 * fade, Color(tint, fade * 0.55))
			_segments.resize(dirs.size() * 2)
			for i in dirs.size():
				_segments[i * 2] = dirs[i] * 3.0
				_segments[i * 2 + 1] = dirs[i] * (7.0 + 16.0 * (1.0 - fade))
			draw_multiline(_segments, Color(tint, fade), 2.2 * fade + 0.6)

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
	if _frame_fx_art != null:
		match effect:
			"holy/heal", "nature/leaf-storm":
				return _spawn_frame_burst(1, pos, s, 0.29)
			"arcane/spell-charge", "holy/sunburst", "holy/halo":
				return _spawn_frame_burst(1 if pal == "heal" else 2, pos, s, 0.27)
			"impacts/ground-slam":
				return _spawn_frame_burst(3, pos, s, 0.25)
	if _impact_sparks == null:
		_impact_sparks = ImpactSparks.new()
		_cam.add_child(_impact_sparks)
	_impact_sparks.spawn(pos, s * (1.15 if lig > 1.7 else 1.0), _pfx_col(pal, effect), 0.16 / maxf(0.6, spd), pal == "poison")
	return _impact_sparks

func _on_hero_attack() -> void:
	if _run_over or _core == null or not _core.running:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	_play_attack_fx()
	_attack_count += 1
	# 家传追加攻击由hero_strike_resolved在主刀命中后结算，起手仅计攻击事件。
	_curio_on_attack()                       # 奇物：铜钱剑（普攻附带钱镖）
	if not _skill_batch_active(epoch):
		return
	_trigger_combos("每次攻击")
	if _attack_count % 5 == 0:
		_trigger_combos("每 5 次攻击")
	if _attack_count % 10 == 0:
		_trigger_combos("每 10 次攻击")

func _on_hero_hit() -> void:
	_hit_count += 1
	_trigger_combos("每次受击")
	_stone_on_hit()

func _on_foe_windup(foe: Dictionary, target: Vector2, seconds: float) -> void:
	var token = _foe_tokens.get(int(foe.get("_tid", 0)))
	if _run_over or token == null: return
	var direction: Vector2 = _core.position + target - token.position
	token.prepare_attack(direction, seconds)

func _on_foe_attack(foe: Dictionary, target: Vector2) -> void:
	var token = _foe_tokens.get(int(foe.get("_tid", 0)))
	if _run_over or token == null: return
	var destination: Vector2 = _core.position + target
	var kind := "melee"
	if bool(foe.get("mage", false)):
		kind = "mage"
	elif bool(foe.get("ranged", false)):
		kind = "bow"
	elif token.challenge_kind == 3:
		kind = "snap"
	elif token.challenge_kind == 4:
		kind = "cleaver"
	var direction: Vector2 = destination - token.position
	match kind:
		"bow": token.play_attack(direction if token._frame_atlas != null else -direction, 0.0, 7.0)
		"mage": token.play_attack(direction if token._frame_atlas != null else Vector2.UP, 0.0, 9.0)
		_: token.play_attack(direction)
	if token.guardian and token._frame_atlas != null and kind == "melee":
		_spawn_frame_burst(3, destination, 1.5, 0.28, 0.0, null, true)
	if _fx_front != null:
		var origin: Vector2 = token.position - Vector2(0, token.radius * (0.85 if kind == "snap" else 1.2)) - FIELD_POS
		if token._frame_atlas != null and (kind == "bow" or kind == "mage"):
			var side := signf(direction.x) if absf(direction.x) > 1.0 else float(token._dir)
			origin.x += token.radius * 0.84 * side
			if kind == "mage":
				origin.y -= token.radius * 0.26
		_fx_front.spawn_enemy_attack(origin, destination - Vector2(0, 26) - FIELD_POS, kind, int(foe.get("_tid", 0)))

func _on_foe_missed(foe: Dictionary) -> void:
	if not _run_over and _fx_front != null:
		_fx_front.mark_enemy_attack_missed(int(foe.get("_tid", 0)))

func _on_foe_blocked(foe: Dictionary) -> void:
	var token := _foe_tokens.get(int(foe.get("_tid", 0))) as TokenActor
	if _run_over or token == null or not token.visible:
		return
	var direction: Vector2 = _core.position + _core.hero_pos - token.position
	token.play_guard(direction)
	if _fx_front != null:
		var side := signf(direction.x) if absf(direction.x) > 1.0 else token._dir
		_fx_front.spawn_guard(token.position - FIELD_POS, token.radius, side)

func _on_hero_foe_hit(tgt: Dictionary, dmg: float, crit: bool, heavy: bool) -> void:
	if _core == null:
		return
	var epoch: int = _core._hero_hit_epoch if _core._hero_hit_epoch >= 0 else _core._enemy_attack_epoch
	if not _skill_batch_active(epoch) or not _core.foes.has(tgt):
		return
	_curio_mirror_hit(tgt, dmg)
	if not _skill_batch_active(epoch) or not _core.foes.has(tgt):
		return
	if crit:
		_curio_on_crit(tgt)                  # 奇物：寒玉扳指 / 醉翁壶
	if _fx_front == null:
		return
	var tk = _foe_tokens.get(int(tgt.get("_tid", 0)))
	if tk == null:
		return
	_spawn_hit_fx(tk.position, tk.radius, int(round(dmg)), false, crit, heavy)
	tk.play_hit(tk.position - _hero_token.position, crit or heavy)

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
	"liuqingqing": {"name": "回春", "dtype": "木系", "mul": 1.0, "heal_mul": 2.0, "cd": 12.0, "mp": 80.0,
		"targets": 1, "col": Color(0.42, 0.72, 0.42)},
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

# 技能图标：同一技能的重复条目共用一张图
const SKILL_ICON_ALIAS := {"liuqingqing2": "liuqingqing"}

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
var _god_art := {}
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

func _start_skill_cooldown(skill: Dictionary, mods: Dictionary) -> void:
	var reduction := clampf(float(mods.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0
	var duration := maxf(0.5, float(skill["cd"]) * (1.0 - reduction))
	skill["cd_t"] = duration
	skill["cd_span"] = duration

func _tick_skills(dt: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	if _core != null and float(_core.hero.get("aspd", 1.0)) > MAX_ASPD:
		_core.hero["aspd"] = MAX_ASPD          # 硬顶：防攻速叠太高卡帧
	var lv_mul := float(_lv - 1)
	_mp_max = maxf(1.0, float(_core.attr_final("mp"))) if _core != null else 100.0
	var boosted_seconds := minf(maxf(0.0, dt), _curio_mana_regen_left)
	_curio_mana_regen_left = maxf(0.0, _curio_mana_regen_left - dt)
	_mp = minf(_mp_max, _mp + (20.0 + 2.0 * lv_mul) * (dt + boosted_seconds * 0.5))
	for i in _skills.size():
		if not _skill_batch_active(epoch):
			return
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
			if not _skill_batch_active(epoch):
				return
			if float(sk["cd_t"]) > cd_before + 0.01:
				if _curio_id == "dingfengzhu" and _curio_lv >= 3:
					_curio_mana_regen_left = 2.0
				if i < _skill_slots.size():
					_skill_slots[i].flash = 1.0
				_skill_cast_juice(str(sk["aid"]))
	_refresh_skill_slots(dt)
	_core.hero["mp"] = _mp

func _refresh_skill_slots(dt: float) -> void:
	for i in _skill_slots.size():
		var slot: SkillSlot = _skill_slots[i]
		if i < _skills.size():
			var skill: Dictionary = _skills[i]
			var cost := _skill_mana_cost(skill)
			slot.update_state(skill, ceili(cost), _mp >= cost, dt)
		else:
			slot.hide()

# 请神技能特效：按技能属性挑效果 + 换色（pixelfx）
const SKILL_FX := {
	"金系": ["lightning/zap-hit", "volt", 1.10],
	"火系": ["fire/fireball", "", 1.00],
	"木系": ["nature/leaf-storm", "leaf", 0.95],
	"召唤": ["arcane/magic-circle-cast", "", 1.10],
	"物理": ["impacts/ground-slam", "metal", 0.95],
	"真实": ["shadow/soul-drain", "", 0.85],
}

const SKILL_FRAMES := {
	"金系": {"row": 0, "duration": 0.34, "offset": 33.0},
	"火系": {"row": 1, "duration": 0.29, "offset": 21.0},
	"真实": {"row": 2, "duration": 0.24, "offset": 0.0},
	"召唤": {"row": 3, "duration": 0.40, "offset": 0.0},
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
const PICKPOCKET_SFX := [["dart", -9.0, 1.30], ["swing", -16.0, 1.32]]

func _skill_fx(dtype: String, world_pos: Vector2, scale_mul := 1.0) -> void:
	if _skill_frame_art != null and SKILL_FRAMES.has(dtype):
		var frames: Dictionary = SKILL_FRAMES[dtype]
		var offset := Vector2(0.0, float(frames["offset"]) * scale_mul)
		_spawn_frame_burst(int(frames["row"]), world_pos - offset, scale_mul, float(frames["duration"]), 0.0, _skill_frame_art, true)
		return
	var e: Array = SKILL_FX.get(dtype, [])
	if e.is_empty():
		return
	_spawn_pfx(str(e[0]), world_pos, float(e[2]) * scale_mul, str(e[1]), 1.9, 1.0)

func _hero_screen() -> Vector2:
	return _core.position + _core.hero_pos

func _skill_level_bonus(aid: String) -> float:
	return float(GameState.skill_lv.get(aid, 0)) * float(SKILL_LV_STEP.get(aid, 3))

func _skill_batch_active(epoch: int) -> bool:
	return not _run_over and _core != null and _core.running and epoch == _core._enemy_attack_epoch and float(_core.hero.get("hp", 0.0)) > 0.0

func _cast_skill(i: int) -> void:
	if i < 0 or i >= _skills.size():
		return
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	_skill_pose_direction = Vector2.ZERO
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
		_start_skill_cooldown(sk, md0)
		_cast_paper()
		return
	# 治疗流：回血 + 环毒 + 易伤
	if aid0 in ["liuqingqing", "liuqingqing2"]:
		_mp -= cost0
		_start_skill_cooldown(sk, md0)
		var times := 1
		if _baicao:
			times = _baicao_times()
		_skill_fx("木系", _hero_screen() - Vector2(0, 32))
		if _fx_front != null and float(md0.get("aura", 0.0)) > 0.0:
			_fx_front.spawn_poison_ring(_hero_screen() - FIELD_POS, _poison_radius(md0))
		for _i in times:
			if not _skill_batch_active(epoch): return
			_cast_heal(float(sk["mul"]), aid0)
		if times > 1:
			_toast("百草 · 连放 %d 次（只扣一次内力）" % times)
		return
	# 穿透流：直线穿透 + 回程
	if aid0 == "qingluan":
		if _live_foes().is_empty():
			return
		_mp -= cost0
		_start_skill_cooldown(sk, md0)
		_cast_feiren(float(sk["mul"]))
		return
	# 撞击流：按气血上限算伤害，并把目标撞飞
	if aid0 == "gundilong":
		if _live_foes().is_empty():
			return
		_mp -= cost0
		_start_skill_cooldown(sk, md0)
		_charge_ram()
		return
	# 火系：直伤 + 灼烧（引燃多名）
	if aid0 == "jicanghai":
		if _live_foes().is_empty():
			return                                  # 空场不空放，CD 与内力都不扣
		_mp -= cost0
		_start_skill_cooldown(sk, md0)
		_cast_fire()
		return
	# 召唤系：不直接出伤，召一条蛟龙顶上去
	if aid0 == "cuisanniang":
		_mp -= cost0
		_start_skill_cooldown(sk, md0)
		_summon_dragon(float(md0.get("dmg_pct", 0.0)) + float(_elem_mod.get("召唤", 0.0)) + _skill_level_bonus(aid0))
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
	var shared_pct := 0.0 if _core.DMG_TYPES.has(dtype) else float(_elem_mod.get(dtype, 0.0))
	var dmg_pct := float(m.get("dmg_pct", 0.0)) + shared_pct + _skill_level_bonus(aid)
	var mp_flat := float(m.get("mp_flat", 0.0))
	var para_s := float(m.get("para_s", 0.0))
	var para_amp := float(m.get("para_amp", 0.0))
	var cost := maxf(0.0, float(sk["mp"]) - mp_flat)
	if _mp < cost:
		return
	_mp -= cost
	_start_skill_cooldown(sk, m)
	var hp0 := Vector2(_core.hero_pos)
	foes.sort_custom(func(a, b) -> bool:
		var da := (Vector2(float(a["x"]), float(a["y"])) - hp0).length()
		var db := (Vector2(float(b["x"]), float(b["y"])) - hp0).length()
		return da < db)
	var base := float(_core.hero.get("atk", 12.0)) * float(sk["mul"]) * (1.0 + dmg_pct / 100.0)
	var n := mini(int(sk["targets"]) + int(m.get("tgt_add", 0.0)), foes.size())
	if n > 0:
		_skill_pose_direction = Vector2(float(foes[0]["x"]), float(foes[0]["y"])) - hp0
	for k in n:
		if not _skill_batch_active(epoch):
			return
		var f: Dictionary = foes[k]
		if not _core.foes.has(f) or float(f.get("hp", 0.0)) <= 0.0 or bool(f.get("_death_settled", false)) or float(f.get("dying", 0.0)) > 0.0:
			continue
		var extra := 1.0
		if para_amp > 0.0 and float(f.get("para", 0.0)) > 0.0:
			extra = 1.0 + para_amp / 100.0        # 麻痹期间吃额外伤害
		_core._apply_dmg(f, base * extra, dtype)
		if para_s > 0.0 and float(f.get("hp", 0.0)) > 0.0:
			f["para"] = maxf(float(f.get("para", 0.0)), para_s)
		_core._push_float(float(f["x"]), float(f["y"]) - 46.0, str(sk["name"]), sk["col"], true)
		var hit_pos: Vector2 = _core.position + Vector2(float(f["x"]), float(f["y"]) - 26.0)
		if aid == "xiaoqier":
			_spawn_pfx("impacts/quick-tap", hit_pos, 0.80, "gold", 1.2, 1.15)
		else:
			_skill_fx(dtype, hit_pos)
		if float(f.get("hp", 0.0)) <= 0.0:
			_core._kill_foe(f)
			if not _skill_batch_active(epoch):
				return
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
		# 七种面板类型在统一伤害层结算；召唤继续沿现有独立路径。
		var ep: Dictionary = eff["elem_pct"]
		for e in ep.keys():
			_elem_mod[e] = float(_elem_mod.get(e, 0.0)) + float(ep[e])
			if _core != null and _core.DMG_TYPES.has(str(e)):
				_core.type_add(str(e), "amp_f", float(ep[e]) / 100.0)
	if aid == "zhujue" and _core != null:
		_sync_basic_family_bonus()

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
	if aid == "zhujue": _sync_basic_family_bonus()
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

# ---------------- 请神选卡 ----------------
func _build_god_pick() -> void:
	if _god_layer != null:
		return
	_god_layer = Control.new()
	_god_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_god_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE      # 空白处放行给战场
	_god_layer.visible = false
	_god_layer.z_index = 40
	add_child(_god_layer)
	var chrome := _build_choice_chrome(_god_layer, "请神", _hide_god_pick, _on_god_refresh, _on_god_abandon)
	_god_ban_lb = chrome[0]
	_god_refresh_btn = chrome[1]
	_god_root = Control.new()
	_god_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_god_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_god_layer.add_child(_god_root)

func _pop_option_cards(cards: Array) -> void:
	var offered := 0
	for card in cards:
		if not card.o.is_empty():
			offered += 1
	var width := 250.0 if offered < 3 else 176.0
	var left := (W - (width * offered + 16.0 * maxi(0, offered - 1))) * 0.5
	var i := 0
	for card in cards:
		card.visible = not card.o.is_empty()
		if not card.visible:
			MenuUI.Motion.stop(card)
			continue
		card.size.x = width
		var goal := Vector2(left + i * (width + 16.0), 242)
		MenuUI.Motion.pop(card, true, i * 0.05, goal, (i - (offered - 1) * 0.5) * 0.018)
		i += 1

var _choice_item_art := {}

func _entry_choice_item_keys() -> Array[String]:
	var keys: Array[String] = []
	keys.assign(AUG_ART.values())
	if LevelState.show_button("treasure"):
		for pool in [BOND_POOL, RARE_POOL]:
			for option in pool:
				var key := _treasure_art_key(option)
				if not keys.has(key):
					keys.append(key)
	return keys

func _warm_choice_art() -> void:
	for key in _entry_choice_item_keys():
		_choice_item(key)
	for aid in LevelState.god_ids():
		if AncestorData.ANCESTORS.has(aid):
			_god_skill_art(aid, AncestorData.ANCESTORS[aid]["art"])

func _choice_item_path(key: String) -> String:
	return "res://assets/items/%s.png" % key

func _choice_item(key: String) -> Texture2D:
	if not _choice_item_art.has(key):
		_choice_item_art[key] = _entry_texture(_choice_item_path(key))
	return _choice_item_art[key] as Texture2D

func _treasure_art_key(option: Dictionary) -> String:
	if not bool(option.get("rare", false)):
		var line := str(option.get("line", ""))
		var series: Array = option.get("need_series", [])
		if line == "危途线" or series.has("swarm"):
			return "it_blade"
		if line == "经济线" or series.has("gold") or series.has("crystal"):
			return "chest_gold"
		return "it_book" if line == "成长线" or not series.is_empty() else "it_scroll"
	match str(option.get("kind", "")):
		"buff": return "fate_bloodpath"
		"convert", "mix": return "it_ingot"
		"crystal_burst": return "fate_allin"
	return str({"wen": "loot_silver", "kill": "it_token", "crystal": "mat_jin"}.get(option.get("res", ""), "it_scroll"))

func _build_choice_chrome(layer: Control, title: String, hide: Callable, refresh: Callable, abandon: Callable) -> Array:
	var ink_wash := Gradient.new()
	var shade_color := Color(0.10, 0.08, 0.06)
	ink_wash.offsets = PackedFloat32Array([0.0, 0.11, 0.70, 1.0])
	ink_wash.colors = PackedColorArray([Color(shade_color, 0.0), Color(shade_color, 0.25), Color(shade_color, 0.21), Color(shade_color, 0.0)])
	var wash_texture := GradientTexture2D.new()
	wash_texture.gradient = ink_wash
	wash_texture.width = 2
	wash_texture.height = 256
	wash_texture.fill_to = Vector2.DOWN
	var shade := TextureRect.new()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.texture = wash_texture
	shade.position = Vector2(0, 136)
	shade.size = Vector2(W, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	var ink := Color(0.13, 0.106, 0.081)
	var rim := Color(0.64, 0.48, 0.29)
	var brass := Color(0.87, 0.73, 0.49)
	_panel(Rect2(52, 166, 616, 498), Color(0.19, 0.15, 0.11, 0.98), 14, rim, 2, layer)
	_panel(Rect2(65, 228, 590, 365), ink, 10, Color(0.39, 0.28, 0.18), 1, layer)
	_lbl(title, Vector2(75, 179), Vector2(152, 43), 32, LIGHT, layer)
	var caption := _lbl("", Vector2(223, 182), Vector2(274, 40), 22, brass, layer, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("隐藏", Rect2(562, 180, 84, 40), 19, ink, LIGHT, hide, layer, rim, 1)
	var refresh_button := _btn("刷新 · 0 次", Rect2(106, 602, 240, 47), 20,
		Color(0.30, 0.22, 0.14), LIGHT, refresh, layer, rim, 1)
	refresh_button.add_theme_stylebox_override("disabled", refresh_button.get_theme_stylebox("normal").duplicate())
	refresh_button.add_theme_color_override("font_disabled_color", Color(0.63, 0.54, 0.43))
	_btn("放弃 · +1 刷新", Rect2(374, 602, 240, 47), 20,
		ink, LIGHT, abandon, layer, rim, 1)
	return [caption, refresh_button]

func _show_god_pick() -> void:
	if _run_over or _no_ui:
		return
	if _draw_charge <= 0:
		_toast("升级后可请神")
		return
	_build_god_pick()
	# 同一手只掷一次：点［隐藏］关了再点［请神］，看到的是同一手（不能白刷）
	if _god_hand_charge != _draw_charge:
		_god_hand_charge = _draw_charge
		_roll_god()
	if _god_root.get_child_count() == 0:
		return
	_close_challenge()
	if _draw_layer != null:
		_show_draw(false)
	_hide_aug_pick()
	_hide_trea()
	if _god_ban_lb != null:
		_god_ban_lb.text = "剩余 %d 次" % _draw_charge
	if _god_refresh_btn != null:
		_god_refresh_btn.text = "刷新 · %d 次" % maxi(0, _god_reroll)
		_god_refresh_btn.disabled = _god_reroll <= 0
	_god_layer.visible = true
	_layer_in(_god_layer)
	_god_layer.move_to_front()
	_pop_god_cards()

func _pop_god_cards() -> void:
	var i := 0
	for card in _god_root.get_children():
		MenuUI.Motion.pop(card, true, i * 0.055, card.get_meta("motion_rest_position", card.position), (i - 0.5) * 0.025)
		i += 1

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
		_god_ban_lb.text = "剩余 %d 次" % _draw_charge
	if cands.is_empty():
		_toast("可请的祖宗都已上身（高品祖宗需抽取，暂未开放）")
		_hide_god_pick()
		return
	var n := 1
	if LevelState.current_level >= 7:
		n = 2   # 后续关请神改成二选一（仍按固定顺序取前两位未请的）
	n = mini(n, cands.size())
	var total_w := float(n) * 250.0 + float(n - 1) * 24.0
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
		gc.skill_art = _god_skill_art(aid, str(a["art"]))
		if not _god_portraits.has(aid):
			_god_portraits[aid] = _entry_texture(GodPortraits.path_for(aid))
		gc.portrait = _god_portraits[aid]
		var skill: Dictionary = SKILL_DEFS.get(aid, {})
		if skill.is_empty():
			gc.skill_meta = "被动光环" if aid == "mingzhu" else "家传入口入池"
		else:
			var seconds := snappedf(float(skill["cd"]) * _curio_skill_cd_mul(), 0.1)
			var cool := str(int(seconds)) if is_equal_approx(seconds, roundf(seconds)) else String.num(seconds, 1)
			gc.skill_meta = "内力 %d  ·  冷却 %s 秒" % [int(skill["mp"]), cool]
		gc.position = Vector2(x0 + float(i) * 274.0, 242)
		gc.size = Vector2(250, 335)
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
	_pop_god_cards()

# 放弃：这一手不要了，换 1 次刷新（下次请神能用）
func _on_god_abandon() -> void:
	if _run_over or _god_layer == null or not _god_layer.visible or _draw_charge <= 0:
		return
	_god_reroll += 1
	_hide_god_pick()
	_toast("放弃请神 · 刷新 +1（现有 %d 次）" % _god_reroll)
	Aud.sfx("ui_back", -10.0)

func _hide_god_pick() -> void:
	if _god_root != null:
		_hide_choice_layer(_god_layer, _god_root.get_children())

func _on_god_card(card: GodCard) -> void:
	if _run_over or _god_layer == null or not _god_layer.visible or not is_instance_valid(card) or card.get_parent() != _god_root:
		return
	var from: Vector2 = get_global_transform().affine_inverse() * (card.get_global_transform() * card.seal_center())
	var old_size := _skills.size()
	var charge := _draw_charge
	_pick_god(card.aid)
	if _draw_charge < charge:
		var slot: SkillSlot = _skill_slots[old_size] if _skills.size() > old_size and old_size < _skill_slots.size() else null
		_show_invocation_portrait(card.portrait, card.aid)
		_fly_god_seal(card.skill_art, from, slot)

func _show_invocation_portrait(art: Texture2D, aid: String) -> void:
	if _run_over or art == null or _hero_token == null:
		return
	_clear_invocation_portrait()
	var shade := PortraitMotion.new()
	shade.name = "GodInvocationPortrait"
	shade.spectral = true
	shade.size = Vector2(210, 290)
	var feet := _hero_screen()
	shade.position = Vector2(clampf(feet.x + (16.0 if feet.x < W * 0.5 else -212.0), 10.0, W - 220.0),
		clampf(feet.y - 305.0, 148.0, 574.0))
	shade.z_index = 14
	shade.modulate.a = 0.92
	_cam.add_child(shade)
	shade.set_portrait(art, aid)
	shade.demonstrate()
	_invocation_portrait = shade
	var fade := create_tween().bind_node(shade).set_parallel(true)
	fade.tween_property(shade, "position:y", shade.position.y - 20.0, PortraitMotion.DEMO_TIME).set_trans(Tween.TRANS_SINE)
	fade.tween_property(shade, "modulate:a", 0.0, PortraitMotion.DEMO_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.chain().tween_callback(shade.queue_free)

func _clear_invocation_portrait() -> void:
	if is_instance_valid(_invocation_portrait):
		_invocation_portrait.hide()
		_invocation_portrait.queue_free()
	_invocation_portrait = null

func _god_skill_icon(aid: String) -> String:
	var icon_key := str(SKILL_ICON_ALIAS.get(aid, aid))
	var path := "res://assets/gen/icons/skill_%s.png" % icon_key
	return path if ResourceLoader.exists(path) else ""

func _god_skill_path(aid: String, fallback: String) -> String:
	var path := _god_skill_icon(aid)
	return fallback if path.is_empty() else path

func _god_skill_art(aid: String, fallback: String) -> Texture2D:
	if not _god_art.has(aid):
		_god_art[aid] = _entry_texture(_god_skill_path(aid, fallback))
	return _god_art[aid] as Texture2D

func _fly_god_seal(tex: Texture2D, from: Vector2, slot: SkillSlot) -> void:
	if tex == null:
		return
	if slot != null:
		slot.arriving = true
		slot.queue_redraw()
	var edge := Color(0.86, 0.68, 0.38)
	var seal := _panel(Rect2(from - Vector2(42, 42), Vector2(84, 84)), Color(0.90, 0.85, 0.72), 14, edge, 2)
	seal.name = "GodSkillSeal"
	seal.z_index = 20
	seal.pivot_offset = seal.size * 0.5
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = tex
	icon.position = Vector2(8, 8)
	icon.size = Vector2(68, 68)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.add_child(icon)
	var dest := slot.position + slot.size * 0.5 if slot != null else _hero_screen()
	var fly := create_tween()
	fly.tween_property(seal, "position", from - seal.pivot_offset + Vector2(0, -18), 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(seal, "position", dest - seal.pivot_offset, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fly.parallel().tween_property(seal, "scale", Vector2.ONE * 0.58, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_callback(func():
		if is_instance_valid(slot):
			slot.arriving = false
			if not _run_over:
				slot.flash = 1.0
			slot.queue_redraw()
		seal.queue_free())

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
		sk["icon"] = _god_skill_icon(aid)
		_skills.append(sk)
		_refresh_skill_slots(0.0)
	_hide_god_pick()
	_refresh_level_ui()
	var role_name := str((AncestorData.ANCESTORS[aid] as Dictionary)["name"])
	var buff_text := "光环生效" if aid == "mingzhu" else "家传入口已入池"
	_toast("请到 %s · %s" % [role_name, buff_text if def.is_empty() else "技能已入栏"])
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
	var skill_icon := ""
	var quality := 4
	var cooldown_seconds := 0
	var cooldown_steps := 0
	var mp_cost := 0
	var affordable := true
	var arriving := false
	var flash := 0.0          # 刚放完技能：一圈金色扩散
	var _tex: Texture2D = null
	var _box := StyleBoxFlat.new()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.set_corner_radius_all(9)
		_box.set_border_width_all(2)

	func update_state(skill: Dictionary, cost: int, can_pay: bool, dt: float) -> void:
		var title := str(skill["name"])
		var icon := str(skill.get("icon", ""))
		var grade := int(skill.get("quality", 4))
		var time := float(skill["cd_t"])
		var seconds := ceili(time)
		var steps := ceili(clampf(time / maxf(0.01, float(skill.get("cd_span", skill["cd"]))), 0.0, 1.0) * 24.0)
		var changed := not visible or skill_name != title or skill_icon != icon or quality != grade \
			or cooldown_seconds != seconds or cooldown_steps != steps or mp_cost != cost or affordable != can_pay
		show()
		if skill_icon != icon:
			skill_icon = icon
			_tex = load(icon) as Texture2D if not icon.is_empty() else null
		skill_name = title
		quality = grade
		cooldown_seconds = seconds
		cooldown_steps = steps
		mp_cost = cost
		affordable = can_pay
		if flash > 0.0:
			flash = maxf(0.0, flash - dt * 2.2)
			changed = true
		if changed:
			queue_redraw()

	func _draw() -> void:
		var qc: Color = QC[clampi(quality - 1, 0, 4)]
		var ready_to_cast := cooldown_seconds <= 0 and affordable
		_box.bg_color = Color(0.15, 0.12, 0.09, 0.96)
		_box.border_color = qc.lightened(0.42) if ready_to_cast and not arriving else qc
		draw_style_box(_box, Rect2(Vector2.ZERO, size))
		var c := size * 0.5
		if arriving:
			draw_arc(c, 15, 0.0, TAU, 32, Color(0.89, 0.73, 0.42, 0.56), 1.5, true)
			return
		if _tex != null:
			var inset := size * 0.10
			draw_texture_rect(_tex, Rect2(inset, size - inset * 2.0), false)
		else:
			var ch := "技"
			if skill_name.length() > 0:
				ch = skill_name.substr(1 if skill_name.length() > 1 else 0, 1)
			draw_string(F, Vector2(0, c.y + 8), ch, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(0.96, 0.89, 0.72))
		if cooldown_seconds > 0:
			draw_circle(c, size.x * 0.5 - 4.0, Color(0.05, 0.04, 0.03, 0.64))
			draw_arc(c, size.x * 0.5 - 5.0, -PI * 0.5, TAU * float(24 - cooldown_steps) / 24.0 - PI * 0.5,
				28, Color(0.92, 0.74, 0.41), 2.2, true)
			draw_string(F, Vector2(0, c.y + 8), str(cooldown_seconds), HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(0.97, 0.92, 0.80))
		elif not affordable:
			draw_circle(c, size.x * 0.5 - 4.0, Color(0.08, 0.15, 0.23, 0.70))
			draw_string(F, Vector2(0, c.y + 5), "缺内力", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(0.74, 0.89, 0.98))
		if flash > 0.0:
			var k := 1.0 - flash
			var rr := size.x * (0.5 + 0.45 * k)
			draw_arc(c, rr, 0.0, TAU, 32, Color(0.98, 0.82, 0.36, flash * 0.9), 3.0)
			draw_circle(c, size.x * (0.55 + 0.25 * k), Color(0.98, 0.82, 0.36, flash * 0.16))
		if mp_cost > 0:
			var cost_text := str(mp_cost)
			var wid := maxf(22.0, F.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 6.0)
			var left := size.x - wid - 2.0
			draw_rect(Rect2(left, 2, wid, 15), Color(0.16, 0.32, 0.48, 0.96))
			draw_string(F, Vector2(left, 14), cost_text, HORIZONTAL_ALIGNMENT_CENTER, wid, 12, Color(0.92, 0.97, 1.0))

# ---------------- 请神卡 ----------------
class GodCard extends Button:
	const F := preload("res://fonts/ink.ttf")
	const P := preload("res://shared/ui_pal.gd")
	const Motion := preload("res://shared/ui_motion.gd")
	const PORTRAIT_CROP := {"liuqingqing": 0.26}
	const ELEMENT_TONES := {"木系": Color(0.58, 0.76, 0.57), "真实": Color(0.83, 0.74, 0.62),
		"物理": Color(0.73, 0.76, 0.83), "火系": Color(0.94, 0.64, 0.43)}
	signal picked
	var aid := ""
	var god_name := ""
	var skill_name := ""
	var element := ""
	var skill_meta := ""
	var quality := 5
	var skill_art: Texture2D = null
	var portrait: Texture2D
	var _frame := StyleBoxFlat.new()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		var blank := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, blank)
		pressed.connect(func(): picked.emit())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		Motion.bind_button(self)
		_frame.bg_color = Color(0.135, 0.110, 0.084)
		_frame.set_corner_radius_all(11)
		_frame.set_border_width_all(2)
		_frame.shadow_color = Color(0.02, 0.015, 0.01, 0.76)
		_frame.shadow_size = 8
		_frame.shadow_offset = Vector2(0, 4)

	func seal_center() -> Vector2:
		return Vector2(31, 272)

	func _draw() -> void:
		var tone := P.quality(quality)
		var metal := tone.lerp(Color(0.86, 0.71, 0.46), 0.65)
		if is_hovered():
			metal = metal.lightened(0.20)
		_frame.border_color = metal
		draw_style_box(_frame, Rect2(Vector2.ZERO, size))
		var image := Rect2(7, 7, size.x - 14, 236)
		var ink := Color(0.083, 0.071, 0.056, 0.97)
		var accent: Color = ELEMENT_TONES.get(element, metal.lightened(0.22))
		if portrait != null:
			var source := portrait.get_size()
			var crop := image.size / maxf(image.size.x / source.x, image.size.y / source.y)
			var anchor := Vector2(0.5, float(PORTRAIT_CROP.get(aid, 0.30)))
			draw_texture_rect_region(portrait, image, Rect2((source - crop) * anchor, crop))
		else:
			draw_rect(image, Color(0.79, 0.73, 0.60).lerp(tone, 0.22))
			_draw_skill_icon(image.get_center(), 124.0)
		var fade_y := image.end.y - 80.0
		draw_polygon(PackedVector2Array([Vector2(image.position.x, fade_y), Vector2(image.end.x, fade_y),
			image.end, Vector2(image.position.x, image.end.y)]),
			PackedColorArray([Color(ink, 0.0), Color(ink, 0.0), ink, ink]))
		draw_rect(image, Color(metal, 0.63), false, 1.0)
		var tag := Rect2(size.x - 69.0, 15, 53, 25)
		draw_rect(tag, ink)
		draw_rect(tag, Color(accent, 0.72), false, 1.0)
		draw_string(F, Vector2(tag.position.x, 33), element, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 17, accent)
		var pale := Color(0.97, 0.91, 0.78)
		draw_string_outline(F, Vector2(17, 230), god_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 34, 32, 4, ink)
		draw_string(F, Vector2(17, 230), god_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 34, 32, pale)
		var sigil := seal_center()
		draw_circle(sigil, 17, Color(0.72, 0.65, 0.48, 0.40))
		draw_arc(sigil, 17, 0.0, TAU, 26, Color(accent, 0.77), 1.0, true)
		_draw_skill_icon(sigil, 30.0)
		draw_string(F, Vector2(57, 268), skill_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 72, 23, pale)
		draw_string(F, Vector2(57, 289), skill_meta, HORIZONTAL_ALIGNMENT_LEFT, size.x - 70, 15, Color(0.87, 0.80, 0.66))
		draw_line(Vector2(14, 301), Vector2(size.x - 14, 301), Color(metal, 0.53), 1.0, true)
		draw_string(F, Vector2(9, 324), "请神", HORIZONTAL_ALIGNMENT_CENTER, size.x - 18, 18, metal.lightened(0.30))

	func _draw_skill_icon(center: Vector2, width: float) -> void:
		if skill_art != null:
			var source_size := skill_art.get_size()
			var art_size := source_size * (width / maxf(source_size.x, source_size.y))
			draw_texture_rect(skill_art, Rect2(center - art_size * 0.5, art_size), false)



# ---------------- 召唤物：蛟龙 ----------------
const DRAGON_TONE := Color(0.38, 0.90, 0.82)
const DRAGON_WAVE_RADIUS := 130.0

func _summon_dragon(bonus_pct: float) -> void:
	var m: Dictionary = _anc_mod.get("cuisanniang", {})
	var cap := 1 + int(m.get("cap_add", 0.0))
	var dragon_count := _curio_count_minions("")
	if dragon_count >= cap:
		return
	var hero_atk := float(_core.hero.get("atk", 12.0))
	var life := 30.0 + float(m.get("life_flat", 0.0))
	var idx := dragon_count
	# 脚底和召唤阵都在提示条上方，入场时也能看见完整动作。
	var pos := Vector2(clampf(280.0 + float(idx) * 160.0, 70.0, _core.size.x - 70.0), _core.size.y - 80.0)
	var tk := TokenActor.new()
	tk.set_role("dragon")
	tk.round_mask = _dragon_frame_art == null
	tk.setup(null, 25.0, DRAGON_TONE, false, _dragon_frame_art)
	tk.show_bar = true
	tk.bar_w = 48.0
	tk.unit_name = "蛟龙"
	tk.name_col = Color(0.74, 0.98, 0.91)
	tk.z_index = 5
	tk.position = _core.position + pos
	_cam.add_child(tk)
	tk.play_spawn()
	_skill_fx("召唤", tk.position - Vector2(0, 12))
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

var _minions_ticking := false

func _tick_minions(dt: float) -> void:
	if _minions_ticking:
		return
	_minions_ticking = true
	_step_minions(dt)
	_minions_ticking = false

func _step_minions(dt: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	if _swallow_sea:
		_ss_pct += 0.4 * dt                    # 每秒 +0.4% 蛟龙属性
	if _minions.is_empty():
		return
	for m_v in _minions.duplicate():
		if not _skill_batch_active(epoch):
			return
		var m: Dictionary = m_v
		if not _minions.has(m):
			continue
		m["life"] = float(m["life"]) - dt
		var tk := m["tk"] as TokenActor
		var is_dragon := is_instance_valid(tk) and tk.role == "dragon"
		if _swallow_sea and m.has("base_dmg"):
			m["life"] = float(m["max_life"])
			var ss2 := 1.0 + _ss_pct / 100.0
			m["dmg"] = float(m["base_dmg"]) * ss2
			m["wave_dmg"] = float(m["base_wave"]) * ss2
		if float(m["life"]) <= 0.0:
			_minions.erase(m) # 先退场，击杀回调不能再次触发同一只的到期效果。
			if m.has("decoy"):
				m["decoy"]["active"] = false
			if tk != null and is_instance_valid(tk):
				tk.retire()
			# 奇物·招魂幡 Lv5：鬼影消失时自爆
			if float(m.get("boom", 0.0)) > 0.0 and _core != null:
				var at_e: Vector2 = m["pos"]
				for f_v2 in _core.foes.duplicate():
					if not _skill_batch_active(epoch):
						return
					var f2: Dictionary = f_v2
					if not _core.foes.has(f2) or float(f2.get("hp", 0.0)) <= 0.0 or bool(f2.get("_death_settled", false)) or float(f2.get("dying", 0.0)) > 0.0:
						continue
					if at_e.distance_to(Vector2(float(f2["x"]), float(f2["y"]))) > 90.0:
						continue
					_core._apply_dmg(f2, float(_core.hero.get("atk", 12.0)) * float(m["boom"]), "召唤")
					if float(f2.get("hp", 0.0)) <= 0.0:
						_core._kill_foe(f2)
					if not _skill_batch_active(epoch):
						return
				if _core != null:
					_spawn_pfx("impacts/crit-hit", _core.position + at_e, 0.9, "", 1.4)
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
				var previous_cd := float(m["atk_cd"])
				m["atk_cd"] = float(m["atk_cd"]) - dt
				if is_dragon and previous_cd > 0.17 and float(m["atk_cd"]) > 0.0 and float(m["atk_cd"]) <= 0.17:
					tk.prepare_attack(dv, float(m["atk_cd"]))
				if float(m["atk_cd"]) <= 0.0:
					m["atk_cd"] = 1.1
					if is_dragon:
						tk.play_attack(dv)
					var md: float = _core._apply_dmg(best, float(m["dmg"]), "召唤")
					if float(best.get("hp", 0.0)) <= 0.0:
						_core._kill_foe(best)
					if not _skill_batch_active(epoch):
						return
					if not _minions.has(m):
						continue
					# 奇物·铜镜 Lv3：镜影攻击吸血
					if float(m.get("lc", 0.0)) > 0.0 and md > 0.0 and _core != null:
						_core.heal_hero(md * float(m["lc"]))
			m["wave_cd"] = float(m["wave_cd"]) - dt
			if float(m["wave_cd"]) <= 0.0 and _core.foes.has(best) and float(best.get("hp", 0.0)) > 0.0:
				m["wave_cd"] = 20.0
				_dragon_wave(m, best)
				if not _skill_batch_active(epoch):
					return
		elif ghost:
			var anchor: Vector2 = _core.hero_pos + Vector2(m.get("follow_offset", Vector2(-60.0, 20.0)))
			var back := anchor - mp0
			m["pos"] = mp0 + back.normalized() * minf(150.0 * dt, back.length())
		if tk != null and is_instance_valid(tk):
			tk.position = _core.position + Vector2(m["pos"])
			var ratio := float(m["life"]) / maxf(1.0, float(m["max_life"]))
			if absf(tk.hp_ratio - ratio) > 0.002:
				tk.hp_ratio = ratio
				tk.queue_redraw()

# 大浪拍击：单体；六档「怒涛」进化成一圈 + 减速
func _dragon_wave(m: Dictionary, target: Dictionary) -> void:
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	var wm: Dictionary = _anc_mod.get("cuisanniang", {})
	var evo := float(wm.get("wave_evo", 0.0)) > 0.0
	var at := Vector2(float(target["x"]), float(target["y"]))
	var origin := Vector2(m["pos"])
	var actor := m["tk"] as TokenActor
	if is_instance_valid(actor):
		actor.play_cast(at - origin)
	if _fx_front != null:
		_fx_front.spawn_skill_trail(origin - Vector2(0, 24), at - Vector2(0, 17), DRAGON_TONE, 12.0)
		if evo:
			_fx_front.spawn_cast_seal(at, DRAGON_TONE, DRAGON_WAVE_RADIUS, 1.0)
	if _dragon_wave_art != null:
		var burst_scale := 1.40 if evo else 1.02
		var wave := _spawn_frame_burst(0, _core.position + at - Vector2(0, 52.0 * burst_scale), burst_scale, 0.36, 0.0, _dragon_wave_art, true)
		if wave != null:
			wave.flip_h = at.x < origin.x
	for f_v in _core.foes.duplicate():
		var f: Dictionary = f_v
		if not _core.foes.has(f) or float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		var d := (Vector2(float(f["x"]), float(f["y"])) - at).length()
		if f != target and not (evo and d <= DRAGON_WAVE_RADIUS):
			continue
		_core._apply_dmg(f, float(m["wave_dmg"]), "召唤")
		if evo:
			f["slow_t"] = 2.0
		_core._push_float(float(f["x"]), float(f["y"]) - 40.0, "大浪", Color(0.38, 0.62, 0.82), true)
		if float(f["hp"]) <= 0.0:
			_core._kill_foe(f)
			if not _skill_batch_active(epoch):
				return
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

const BATTLE_EFFECT_TICKS := [&"_tick_chal", &"_q_tick", &"_tick_minions", &"_tick_burn", &"_tick_poison", &"_tick_vuln", &"_tick_aura", &"_tick_stone", &"_tick_paper", &"_tick_shards", &"_tick_knock"]

func _tick_battle_effects(dt: float) -> bool:
	if _core == null:
		return false
	var epoch: int = _core._enemy_attack_epoch
	for tick in BATTLE_EFFECT_TICKS:
		if not _skill_batch_active(epoch):
			return false
		call(tick, dt)
	return _skill_batch_active(epoch)

func _apply_burn(f: Dictionary, stacks: float, dur: float) -> void:
	if _core == null or stacks <= 0.0 or dur <= 0.0:
		return
	if not _skill_batch_active(_core._enemy_attack_epoch) or not _core.foes.has(f) or float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0 or bool(f.get("_death_settled", false)):
		return
	if float(f.get("burn", 0.0)) <= 0.0:
		f["burn_acc"] = 0.0
	f["burn"] = float(f.get("burn", 0.0)) + stacks
	f["burn_t"] = maxf(float(f.get("burn_t", 0.0)), dur)

func _burn_dps() -> float:
	return float(_core.hero.get("atk", 12.0)) * 0.12

func _tick_burn(dt: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch) or dt <= 0.0:
		return
	for f_v in _core.foes.duplicate():
		if not _skill_batch_active(epoch):
			return
		var f: Dictionary = f_v
		if float(f.get("burn", 0.0)) <= 0.0 or float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0 or bool(f.get("_death_settled", false)) or not _core.foes.has(f):
			continue
		var remaining := dt
		var elapsed := 0.0
		while remaining > 0.0 and float(f.get("burn", 0.0)) > 0.0:
			var life := remaining if _burn_unlimited else maxf(0.0, float(f.get("burn_t", 4.0)))
			var step := minf(remaining, life)
			remaining -= step
			elapsed += step
			if not _burn_unlimited:
				f["burn_t"] = life - step
			f["burn_acc"] = float(f.get("burn_acc", 0.0)) + step
			while float(f["burn_acc"]) + 0.000000001 >= 1.0:
				f["burn_acc"] = maxf(0.0, float(f["burn_acc"]) - 1.0)
				var at_t := elapsed - float(f["burn_acc"])
				var vuln := 1.0 + float(f.get("vuln_pct", 0.0)) / 100.0 if float(f.get("vuln_t", 0.0)) > at_t else 1.0
				_core._apply_dmg(f, _burn_dps() * float(f["burn"]), "火系", -1, vuln)
				_core._push_float(float(f["x"]), float(f["y"]) - 30.0, "烧", Color(0.88, 0.45, 0.20))
				if randf() < 0.6:
					_skill_fx("火系", _core.position + Vector2(float(f["x"]), float(f["y"]) - 14.0), 0.58)
				if float(f.get("hp", 0.0)) <= 0.0:
					_core._kill_foe(f)
				if not _skill_batch_active(epoch):
					return
				if float(f.get("hp", 0.0)) <= 0.0 or not _core.foes.has(f):
					break
			if float(f.get("hp", 0.0)) <= 0.0 or not _core.foes.has(f):
				break
			if not _burn_unlimited and float(f["burn_t"]) <= 0.000000001:
				f["burn"] = maxf(0.0, float(f["burn"]) - 1.0)
				f["burn_t"] = 4.0
		if float(f.get("burn", 0.0)) <= 0.0:
			f.erase("burn")
			f.erase("burn_t")
			f.erase("burn_acc")

func _cast_fire() -> void:
	var m: Dictionary = _anc_mod.get("jicanghai", {})
	var dmg_pct := float(m.get("dmg_pct", 0.0)) + _skill_level_bonus("jicanghai")
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
		_skill_fx("火系", _core.position + Vector2(float(f["x"]), float(f["y"]) - 13.0))
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
	if _core == null or not _skill_batch_active(_core._enemy_attack_epoch):
		return
	var w := int(_core.wave)
	var nw := maxi(1, w - 5)
	# 回到普通波时不能沿用末波的首领门槛，也不能让旧场上的攻击追到重刷波。
	if not _q_cur.is_empty() and str(_q_cur.get("kind", "")) in ["statue", "zone", "guard", "champion", "elite"]:
		_q_finish("fail")
	_core.foes.clear()
	_core.clear_enemy_attacks()
	if _hero_token != null:
		_hero_token.cancel_cast_poses()
	_core._hero_pending = {}
	_core._hero_pending_t = -1.0
	_core.boss_required = false
	_core.boss_spawned_once = false
	_core.boss_alive = false
	_boss_spawned = false
	_chal_all_cd()
	_core.set_wave(nw)
	_core.wave_reset_quota()
	_spawn_typed_foes()
	_last_wave = nw
	_run_cleared = false
	_refresh_wave_hud(nw)
	_toast("回潮 · 波数 %d → %d，重头再刷" % [w, nw])
	_shiny_present("backwash")

# ============================================================
# 炫彩卡出场演出：四张各一套（动画 / 音效 / 音乐都不同）
#   devour       噬雷 · 吞噬收割 —— 白闪 + 竖条冲击 + drum
#   swallow_sea  吞海 · 养龙 —— 蓝潮从底升起 + warcry
#   fentian      焚天 · 火 —— 橙色四边向内烧 + tension
#   backwash     回潮 · 倒流 —— 白圆从中心扩散 + 低音钟
# ============================================================
var _stinger_revision := 0

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
		_stinger_revision += 1
		_stop_stinger(1.8, _stinger_revision)
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

func _stop_stinger(delay: float, revision: int) -> void:
	await get_tree().create_timer(delay).timeout
	if is_inside_tree() and revision == _stinger_revision:
		Aud.play_battle_music(0.6)

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
#   dmg_pct属于基础剑法；elem_pct.物理由_add_ancestor_effects登记到物理类型。
func _apply_hero_passive(eff: Dictionary) -> void:
	if eff.is_empty() or _core == null:
		return
	# dmg_pct已由_add_ancestor_effects登记到本技能，物理共享已进类型增幅。
	var pct := float(eff.get("dmg_pct", 0.0))
	var physical_shared := float((eff.get("elem_pct", {}) as Dictionary).get("物理", 0.0))
	# 攻速从属性层读取，核心按现行基础出手间隔除以倍率。
	if eff.has("aspd_pct"):
		_core.attr_add_amp("aspd", float(eff["aspd_pct"]) / 100.0)
		_core.hero["aspd"] = minf(MAX_ASPD, _core.attr_final("aspd") / float(_core.ATTR_BASE["aspd"]))
	# 多目标 / 追击 / 剑气：记下来，普攻时结算
	for k in ["tgt_add", "chase", "qijian"]:
		if eff.has(k):
			_hero_passive[k] = float(_hero_passive.get(k, 0.0)) + float(eff[k])
	var parts: Array = []
	if pct != 0.0: parts.append("剑法伤害 +%d%%" % int(pct))
	if physical_shared != 0.0: parts.append("物理共享 +%d%%" % int(physical_shared))
	if eff.has("aspd_pct"): parts.append("攻速 +%d%%" % int(eff["aspd_pct"]))
	if eff.has("tgt_add"): parts.append("目标 +%d" % int(eff["tgt_add"]))
	if eff.has("chase"): parts.append("追击 %d%%" % int(eff["chase"]))
	if eff.has("qijian"): parts.append("剑气 %d%%" % int(eff["qijian"]))
	if not parts.is_empty():
		_toast("基础剑法 · " + " · ".join(PackedStringArray(parts)))
	Aud.sfx("skill", -14.0)

# 主角普攻的额外结算（多目标 / 追击 / 剑气）
func _hero_extra_hits(primary: Dictionary = {}) -> void:
	if _run_over or _core == null or not _core.running or float(_core.hero.get("hp", 0.0)) <= 0.0:
		return
	var foes := _live_foes()
	if foes.is_empty():
		return
	if primary.is_empty():
		primary = foes[0] # 保留直接调用工具的默认目标，实战信号总是传入本刀目标。
	var epoch: int = _core._enemy_attack_epoch
	# v9 剑魄：连续打同一目标 → 攻速叠层；换目标立刻重置
	if _hero_jianpo:
		var tid := int(primary.get("_tid", -1))
		if tid != _jpo_tid:
			_jpo_tid = tid
			if _jpo_stacks > 0:
				_core.attr_add_amp("aspd", -0.06 * float(_jpo_stacks))
			_jpo_stacks = 0
		else:
			_jpo_stacks += 1                      # 不设上限：只靠"换目标"重置
			_core.attr_add_amp("aspd", 0.06)
		_core.hero["aspd"] = minf(MAX_ASPD, _core.attr_final("aspd") / float(_core.ATTR_BASE["aspd"]))
	if _hero_passive.is_empty():
		return
	var base: float = float(_core.hero.get("atk", 12.0)) * _core.basic_attack_multiplier()
	var extra := int(_hero_passive.get("tgt_add", 0.0))
	var extra_hits := 0
	for candidate in foes:
		if extra_hits >= extra: break
		if candidate == primary or float(candidate.get("hp", 0.0)) <= 0.0: continue
		if not _hero_extra_damage(candidate, base * 0.7, epoch): return
		extra_hits += 1
	if randf() < float(_hero_passive.get("chase", 0.0)) / 100.0:
		if float(primary.get("hp", 0.0)) > 0.0:
			if not _hero_extra_damage(primary, base * 0.5, epoch): return
			_core._push_float(float(primary["x"]), float(primary["y"]) - 40.0, "追击", Color(0.95, 0.85, 0.55))
	if randf() < float(_hero_passive.get("qijian", 0.0)) / 100.0:
		var at := Vector2(float(primary["x"]), float(primary["y"]))
		# 剑魄：剑气进化成「万剑归宗」——范围更大、伤害更狠
		var rad := 300.0 if _hero_jianpo else 130.0
		var mul := 2.5 if _hero_jianpo else 1.2
		for f_v in foes:
			var f: Dictionary = f_v
			if float(f.get("hp", 0.0)) > 0.0 and (Vector2(float(f["x"]), float(f["y"])) - at).length() <= rad:
				if not _hero_extra_damage(f, base * mul, epoch): return
				_core._push_float(float(f["x"]), float(f["y"]) - 44.0,
					"万剑归宗" if _hero_jianpo else "剑气",
					Color(0.98, 0.94, 0.74) if _hero_jianpo else Color(0.88, 0.92, 1.0), true)
		Aud.sfx("slash_light2" if _hero_jianpo else "slash_light", -6.0 if _hero_jianpo else -8.0)
		if _hero_jianpo and _core != null:
			_core.Shake_add(5.0)

func _hero_extra_damage(target: Dictionary, amount: float, epoch: int) -> bool:
	if _run_over or not _core.running or epoch != _core._enemy_attack_epoch or float(_core.hero.get("hp", 0.0)) <= 0.0:
		return false
	if float(target.get("hp", 0.0)) <= 0.0 or bool(target.get("_death_settled", false)) or float(target.get("dying", 0.0)) > 0.0:
		return true
	_core._apply_dmg(target, amount, "物理")
	if float(target.get("hp", 0.0)) <= 0.0:
		_core._kill_foe(target)
	return not _run_over and _core.running and epoch == _core._enemy_attack_epoch and float(_core.hero.get("hp", 0.0)) > 0.0

# ---------------- 剑魄（主角炫卡） ----------------
func _enable_jianpo() -> void:
	_hero_jianpo = true
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

var _ram_shiny := false          # 滚山：每个敌人各弹一次
var _ram_foe_seq := 0            # 冲撞命中记录使用独立编号，不依赖尚未生成的显示token。
var _ram_step_accum := 0.0
var _ram_step_epoch := -1
const RAM_STEP := 1.0 / 60.0

func _ram_foe_id(f: Dictionary) -> int:
	if not f.has("_ram_uid"):
		_ram_foe_seq += 1
		f["_ram_uid"] = _ram_foe_seq
	return int(f["_ram_uid"])

func _ram_stop(f: Dictionary) -> void:
	f["_kx"] = 0.0
	f["_ky"] = 0.0
	f.erase("_ram_ctx")
	f.erase("_seg_a")

func _ram_mods() -> Dictionary:
	return _anc_mod.get("gundilong", {})

func _ram_damage() -> float:
	var m := _ram_mods()
	var pct := RAM_HP_PCT * (1.0 + (float(m.get("dmg_pct", 0.0)) + _skill_level_bonus("gundilong")) / 100.0)
	return float(_core.hero.get("hp_max", 200.0)) * pct / 100.0

# 化身肉蛋：把最近的一只撞飞
func _charge_ram() -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	var foes := _live_foes()
	if foes.is_empty():
		return
	var f0: Dictionary = foes[0]
	var hp0 := Vector2(_core.hero_pos)
	var dir := (Vector2(float(f0["x"]), float(f0["y"])) - hp0)
	_skill_pose_direction = dir
	if dir.length() < 1.0:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	# 每次施法各自保存伤害、预算和命中编号；不持有敌人引用，避免循环引用。
	var ctx := {"damage": _ram_damage(), "budget": 999 if _ram_shiny else 1,
		"shiny": _ram_shiny, "epoch": epoch, "hits": {_ram_foe_id(f0): true}, "bounced": {}}
	ctx["chain_damage"] = float(ctx["damage"]) * (1.0 + float(_ram_mods().get("chain_dmg", 0.0)) / 100.0)
	# 冲撞演出：一道土黄streak
	_ram_streak(hp0, Vector2(float(f0["x"]), float(f0["y"])))
	_core._apply_dmg(f0, float(ctx["damage"]), "物理")
	_core._push_float(float(f0["x"]), float(f0["y"]) - 46.0, "肉蛋冲击", Color(0.92, 0.80, 0.42), true)
	if float(f0.get("hp", 0.0)) <= 0.0:
		_core._kill_foe(f0)
	if not _skill_batch_active(epoch):
		return
	if not _core.foes.has(f0) or float(f0.get("hp", 0.0)) <= 0.0 or bool(f0.get("_death_settled", false)):
		_ram_stop(f0)
		return
	var pm := 1.0 + float(_ram_mods().get("impact", 0.0)) * 0.15   # 冲击力：每点 +15% 击退距离
	f0["_kx"] = dir.x * RAM_KNOCK * pm
	f0["_ky"] = dir.y * RAM_KNOCK * pm
	f0["_seg_a"] = Vector2(float(f0["x"]), float(f0["y"]))   # 扫掠起点
	f0["_ram_ctx"] = ctx
	_core.Shake_add(7.0)
	Aud.sfx("hit_heavy", -6.0)

func _ram_streak(a: Vector2, b: Vector2) -> void:
	if _fx_front != null:
		_fx_front.spawn_skill_trail(a, b, Color(0.97, 0.70, 0.38), 13.0)
	_skill_fx("物理", _core.position + b)

func _tick_knock(dt: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	if _ram_step_epoch != epoch:
		_ram_step_epoch = epoch
		_ram_step_accum = 0.0
	var moving := false
	for f in _core.foes:
		if float(f.get("_kx", 0.0)) != 0.0 or float(f.get("_ky", 0.0)) != 0.0:
			moving = true
			break
	if not moving:
		_ram_step_accum = 0.0
		return
	# 保留原60帧下的运动/墙面/碰撞顺序；渲染帧率只决定本帧补几个固定步。
	_ram_step_accum += maxf(0.0, dt)
	while _ram_step_accum + 0.000000001 >= RAM_STEP:
		_ram_step_accum = maxf(0.0, _ram_step_accum - RAM_STEP)
		_step_knock(RAM_STEP, epoch)
		if not _skill_batch_active(epoch):
			_ram_step_accum = 0.0
			return

func _step_knock(dt: float, epoch: int) -> void:
	for f_v in _core.foes.duplicate():
		if not _skill_batch_active(epoch):
			return
		var f: Dictionary = f_v
		if not _core.foes.has(f):
			continue
		var kx := float(f.get("_kx", 0.0))
		var ky := float(f.get("_ky", 0.0))
		if kx == 0.0 and ky == 0.0:
			continue
		var ctx: Dictionary = f.get("_ram_ctx", {})
		if ctx.is_empty() or int(ctx.get("epoch", -1)) != epoch or float(f.get("hp", 0.0)) <= 0.0 or bool(f.get("_death_settled", false)) or float(f.get("dying", 0.0)) > 0.0:
			_ram_stop(f)
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
		if int(ctx["budget"]) <= 0 or (ctx["bounced"] as Dictionary).has(_ram_foe_id(f)):
			continue
		var seg_a: Vector2 = f.get("_seg_a", Vector2(float(f["x"]), float(f["y"])))
		var seg_b := Vector2(px, py)
		f["_seg_a"] = seg_b
		var reach := RAM_HIT_R + _ram_radius_bonus()
		for o_v in _core.foes.duplicate():
			var o: Dictionary = o_v
			if o == f or float(o.get("hp", 0.0)) <= 0.0 or bool(o.get("_death_settled", false)) or float(o.get("dying", 0.0)) > 0.0 or (ctx["hits"] as Dictionary).has(_ram_foe_id(o)):
				continue
			if _dist_point_seg(Vector2(float(o["x"]), float(o["y"])), seg_a, seg_b) > reach:
				continue
			ctx["budget"] = int(ctx["budget"]) - 1
			ctx["bounced"][_ram_foe_id(f)] = true
			ctx["hits"][_ram_foe_id(o)] = true
			_core._apply_dmg(o, float(ctx["chain_damage"]), "物理")
			_core._push_float(float(o["x"]), float(o["y"]) - 40.0, "反弹", Color(0.92, 0.80, 0.42))
			if float(o.get("hp", 0.0)) <= 0.0:
				_core._kill_foe(o)
			if not _skill_batch_active(epoch):
				return
			var d := (Vector2(float(o["x"]), float(o["y"])) - Vector2(px, py))
			if d.length() < 1.0:
				d = Vector2(0, -1)
			d = d.normalized()
			var sp := float(_ram_mods().get("stun_s", 0.0))
			var alive: bool = _core.foes.has(o) and float(o.get("hp", 0.0)) > 0.0 and not bool(o.get("_death_settled", false))
			if alive:
				o["para"] = maxf(float(o.get("para", 0.0)), sp if sp > 0.0 else 0.0)
			if alive and (bool(ctx["shiny"]) or _ram_mods().get("stun_s", 0.0) != 0.0):
				var pm2 := 1.0 + float(_ram_mods().get("impact", 0.0)) * 0.15
				o["_kx"] = d.x * RAM_KNOCK * pm2
				o["_ky"] = d.y * RAM_KNOCK * pm2
				o["_seg_a"] = Vector2(float(o["x"]), float(o["y"]))
				o["_ram_ctx"] = ctx
			# 滚山：每次反弹 → 气血上限固定 +8（占位，炫卡实装后打开）
			if bool(ctx["shiny"]):
				_apply_flat_growth(0.0, 8.0)
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
	_apply_flat_growth(0.0, GUNSHAN_HP)

# ============================================================
# 苏青鸾 · 青鸾飞刃（直线穿透 + 回程）
#   穿透 = 一条线上能打到几个人；飞刀 = 同时几条线
#   5★ 回旋：到终点后原路再穿一遍（伤害 ×回程倍率）
# ============================================================
const FEIREN_HALF_W := 26.0       # 飞刃判定半宽
const FEIREN_LEN := 780.0         # 飞刃长度

func _cast_feiren(mul: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	var m: Dictionary = _anc_mod.get("qingluan", {})
	var foes := _live_foes()
	if foes.is_empty():
		return
	var dmg_pct := float(m.get("dmg_pct", 0.0)) + _skill_level_bonus("qingluan")
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
	_skill_pose_direction = dir
	if dir.length() < 1.0:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	for k in knives:
		if not _skill_batch_active(epoch):
			return
		var ang := dir.angle() + (float(k) - float(knives - 1) * 0.5) * 0.16
		_feiren_line(hp0, Vector2(cos(ang), sin(ang)), base, pierce, volley, vmul)
		if not _skill_batch_active(epoch):
			return
	Aud.sfx("slash_light", -8.0)

func _feiren_line(origin: Vector2, d: Vector2, base: float, pierce: int, volley: bool, vmul: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
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
		if not _core.foes.has(f) or float(f.get("hp", 0.0)) <= 0.0 or bool(f.get("_death_settled", false)) or float(f.get("dying", 0.0)) > 0.0:
			continue
		_core._apply_dmg(f, base, "物理")
		_core._push_float(float(f["x"]), float(f["y"]) - 42.0, "飞刃", Color(0.55, 0.82, 0.90), i == 0)
		if float(f.get("hp", 0.0)) <= 0.0:
			_core._kill_foe(f)
		if not _skill_batch_active(epoch):
			return
	if volley and n > 0:
		if _wanren:
			_wanren_volleys += 1
			if _wanren_volleys % 3 == 0:
				_wanren_pierce += 1
				_toast("万刃 · 穿透 +1（累计 %d）" % (2 + _wanren_pierce))
		for i in range(n - 1, -1, -1):
			var f2: Dictionary = (hits[i] as Dictionary)["f"]
			if not _core.foes.has(f2) or float(f2.get("hp", 0.0)) <= 0.0 or bool(f2.get("_death_settled", false)) or float(f2.get("dying", 0.0)) > 0.0:
				continue
			_core._apply_dmg(f2, base * vmul, "物理")
			_core._push_float(float(f2["x"]), float(f2["y"]) - 62.0, "回程", Color(0.75, 0.95, 1.0), true)
			if float(f2.get("hp", 0.0)) <= 0.0:
				_core._kill_foe(f2)
			if not _skill_batch_active(epoch):
				return
	if _fx_front != null:
		var reach := minf(FEIREN_LEN, float(hits[n - 1]["t"]) + 46.0) if n > 0 else FEIREN_LEN
		var tip := origin + d * reach
		_fx_front.spawn_skill_trail(origin, tip, Color(0.49, 0.87, 0.96), 6.5)
		if volley and n > 0:
			_fx_front.spawn_skill_trail(tip + d.orthogonal() * 8.0, origin, Color(0.75, 0.97, 1.0), 5.0)

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
	return _core.type_amp("木系") * 100.0 if _core != null else 0.0

func _poison_radius(mods: Dictionary) -> float:
	return AURA_BASE_R + float(mods.get("radius_add", 0.0))

func _cast_heal(mul: float, aid := "liuqingqing") -> void:
	if _core == null or not _skill_batch_active(_core._enemy_attack_epoch):
		return
	var m: Dictionary = _anc_mod.get(aid, {})
	var wood := _wood_pct()
	var bonus := _skill_level_bonus(aid)
	var heal := float(_core.hero.get("atk", 12.0)) * HEAL_RATIO * mul * (1.0 + (float(m.get("heal_pct", 0.0)) + wood + bonus) / 100.0)
	heal = _core.heal_hero(heal)
	if heal > 0.0:
		_core._push_float(_core.hero_pos.x, _core.hero_pos.y - 60.0, "%+.1f" % heal if heal < 1.0 else "+%d" % int(heal), Color(0.42, 0.85, 0.40), true)
	var rad := _poison_radius(m)
	var dur := 4.0 + float(m.get("poison_dur", 0.0))
	var vuln := float(m.get("vuln", 0.0))
	var hp0 := Vector2(_core.hero_pos)
	for f_v in _core.foes:
		if float(m.get("aura", 0.0)) <= 0.0: break
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		if (Vector2(float(f["x"]), float(f["y"])) - hp0).length() > rad:
			continue
		f["poison"] = float(f.get("poison", 0.0)) + 1.0 if _baicao else 1.0
		f["poison_bonus"] = 1.0 + bonus / 100.0
		var layers: Array = f.get("poison_layers", []) if _baicao and float(f["poison"]) > 1.0 else []
		layers.append({"t": dur, "bonus": 1.0 + bonus / 100.0})
		f["poison_layers"] = layers
		f["poison"] = float(layers.size())
		f["poison_t"] = maxf(float(f.get("poison_t", 0.0)), dur)
		if vuln > 0.0:
			f["vuln_t"] = maxf(float(f.get("vuln_t", 0.0)), dur)   # 只刷新，不叠层
			f["vuln_pct"] = vuln
	Aud.sfx("enlighten", -10.0, 1.0, 90)

func _tick_poison(dt: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch): return
	for f_v in _core.foes.duplicate():
		if not _skill_batch_active(epoch): return
		var f: Dictionary = f_v
		var st := float(f.get("poison", 0.0))
		if st <= 0.0 or not _core.foes.has(f):
			continue
		if float(f.get("hp", 0.0)) <= 0.0 or bool(f.get("_death_settled", false)) or float(f.get("dying", 0.0)) > 0.0:
			f["poison"] = 0.0
			continue
		if f.has("poison_layers"):
			if not _tick_poison_layers(f, maxf(0.0, dt), epoch): return
			continue
		var remaining := maxf(0.0, dt)
		var elapsed := 0.0
		while remaining > 0.0 and float(f.get("poison", 0.0)) > 0.0:
			var life := maxf(0.0, float(f.get("poison_t", 4.0)))
			var step := minf(remaining, life)
			remaining -= step
			elapsed += step
			f["poison_t"] = life - step
			f["poison_acc"] = float(f.get("poison_acc", 0.0)) + step
			while float(f["poison_acc"]) + 0.000000001 >= 1.0:
				f["poison_acc"] = maxf(0.0, float(f["poison_acc"]) - 1.0)
				var at_t := elapsed - float(f["poison_acc"])
				var vuln := 1.0 + float(f.get("vuln_pct", 0.0)) / 100.0 if float(f.get("vuln_t", 0.0)) > at_t else 1.0
				var dmg := float(_core.hero.get("atk", 12.0)) * POISON_RATE * float(f["poison"]) * float(f.get("poison_bonus", 1.0))
				_core._apply_dmg(f, dmg, "木系", -1, vuln)
				_core._push_float(float(f["x"]), float(f["y"]) - 34.0, "毒", Color(0.45, 0.80, 0.40))
				_spawn_pfx("impacts/hit-spark", _core.position + Vector2(float(f["x"]), float(f["y"]) - 18.0), 0.55, "poison", 1.2)
				if float(f.get("hp", 0.0)) <= 0.0: _core._kill_foe(f)
				if not _skill_batch_active(epoch): return
				if float(f.get("hp", 0.0)) <= 0.0 or not _core.foes.has(f): break
			if float(f.get("hp", 0.0)) <= 0.0 or not _core.foes.has(f): break
			if float(f["poison_t"]) <= 0.000000001:
				f["poison"] = maxf(0.0, float(f["poison"]) - 1.0)
				f["poison_t"] = 4.0
		if float(f.get("poison", 0.0)) <= 0.0: f.erase("poison")

func _tick_poison_layers(f: Dictionary, dt: float, epoch: int) -> bool:
	var layers: Array = f["poison_layers"]
	var start_acc := float(f.get("poison_acc", 0.0))
	var at_t := 1.0 - start_acc
	var max_duration := 0.0
	for layer in layers: max_duration = maxf(max_duration, float(layer["t"]))
	while at_t <= minf(dt, max_duration) + 0.000000001:
		var weight := 0.0
		for layer in layers:
			if float(layer["t"]) + 0.000000001 >= at_t:
				weight += float(layer["bonus"])
		if weight > 0.0:
			var vuln := 1.0 + float(f.get("vuln_pct", 0.0)) / 100.0 if float(f.get("vuln_t", 0.0)) > at_t else 1.0
			_core._apply_dmg(f, float(_core.hero.get("atk", 12.0)) * POISON_RATE * weight, "木系", -1, vuln)
			_core._push_float(float(f["x"]), float(f["y"]) - 34.0, "毒", Color(0.45, 0.80, 0.40))
			_spawn_pfx("impacts/hit-spark", _core.position + Vector2(float(f["x"]), float(f["y"]) - 18.0), 0.55, "poison", 1.2)
			if float(f.get("hp", 0.0)) <= 0.0: _core._kill_foe(f)
			if not _skill_batch_active(epoch): return false
			if float(f.get("hp", 0.0)) <= 0.0 or not _core.foes.has(f): return true
		at_t += 1.0
	var alive: Array = []
	var max_life := 0.0
	for layer in layers:
		layer["t"] = maxf(0.0, float(layer["t"]) - dt)
		if float(layer["t"]) > 0.000000001:
			alive.append(layer)
			max_life = maxf(max_life, float(layer["t"]))
	f["poison_acc"] = fposmod(start_acc + dt, 1.0)
	f["poison_t"] = max_life
	f["poison"] = float(alive.size())
	f["poison_layers"] = alive
	if alive.is_empty():
		f.erase("poison")
		f.erase("poison_layers")
		f["poison_acc"] = 0.0
	return true

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
	if _baicao: return
	_baicao = true
	_add_ancestor_effects("liuqingqing", {"heal_pct": 10.0})
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

func _aura_active() -> bool:
	return _mingzhu and _core != null and not _run_over and _core.running and float(_core.hero.get("hp", 0.0)) > 0.0

func _clear_lamp_field() -> void:
	if _lamp_field == null or not _lamp_field.visible:
		return
	_lamp_field.update_field(Vector2.ZERO, 0.0)
	for token: TokenActor in _foe_tokens.values():
		token.set_lamp_lit(false)
		token.clear_lamp_pull()

func _tick_aura(dt: float) -> void:
	if not _aura_active():
		return
	var epoch: int = _core._enemy_attack_epoch
	var m: Dictionary = _anc_mod.get("mingzhu", {})
	var rad := _aura_radius()
	var vuln := float(m.get("vuln", 0.0))
	var pull := float(m.get("pull", 0.0)) > 0.0
	var heal_aura := float(m.get("heal_aura", 0.0)) > 0.0
	var hp0 := Vector2(_core.hero_pos)
	if heal_aura:
		_core.heal_hero(float(_core.hero["hp_max"]) * 0.008 * dt)
		_mp = minf(_mp_max, _mp + 6.0 * dt)
	_aura_pull_acc += dt
	var do_pull := _aura_pull_acc >= 1.0
	if do_pull:
		_aura_pull_acc -= 1.0
	for f_v in _core.foes.duplicate():
		if _run_over or not _core.running or epoch != _core._enemy_attack_epoch or float(_core.hero.get("hp", 0.0)) <= 0.0:
			return
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		var feet := Vector2(float(f["x"]), float(f["y"]))
		var offset := feet - hp0
		var distance := offset.length()
		if distance > rad:
			continue
		f["lamp_slow_t"] = 0.3 # 独立计时，离开灯照后不延长其他来源的减速。
		if vuln > 0.0:
			f["vuln_t"] = maxf(float(f.get("vuln_t", 0.0)), 0.3)
			f["vuln_pct"] = vuln
		if pull and do_pull and randf() < 0.20:
			var destination := feet.move_toward(hp0, AURA_PULL_STEP)
			f["x"] = destination.x
			f["y"] = destination.y
			var token := _foe_tokens.get(int(f.get("_tid", 0))) as TokenActor
			if token != null and token.visible and destination.y >= MIN_VISIBLE_FOE_Y:
				if feet.distance_squared_to(destination) > 1.0:
					token.play_lamp_pull(destination - feet)
				_lamp_field.show_pull(feet, destination)
				Aud.sfx("bell", -21.0, 1.12, 220)
			var dmg := float(_core.hero.get("atk", 12.0)) * 0.15 * (rad / AURA_R_BASE)
			_core._apply_dmg(f, dmg, "木系")
			_core._push_float(float(f["x"]), float(f["y"]) - 30.0, "聚", Color(0.95, 0.85, 0.55))
			if float(f.get("hp", 0.0)) <= 0.0:
				_core._kill_foe(f)

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
		var before: int = _core._minions.size()
		_core.summon_minion("纸人", Color(0.95, 0.93, 0.86), 0.72, 0.5, life_m, 1.0, 0.0, 99, "", "paper")
		if _core._minions.size() > before:
			_skill_fx("召唤", _core.position + Vector2(_core._minions.back()["pos"]), 0.72)
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
					_core._apply_dmg(f, dmg, "召唤")
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
	_core.set_wave_extra(_wave_extra)
	_core.extra_diff_mul = 1.0 + _diff_pct / 100.0

# ============================================================
# 险系：怪物类型（文钱怪 / 灵晶怪）+ 宝物·首领奖励加成
#   额外刷出来的怪打 rtype 标签；只在核心确认死亡时结算。
# ============================================================
func _spawn_typed_foes() -> void:
	if _core == null:
		return
	_core.queue_wave_reward_foes(_coin_count_extra, _crystal_count_extra)

func _on_foe_defeated(foe: Dictionary) -> void:
	if _run_over or _core == null or not _core.foes.has(foe) or not bool(foe.get("_death_settled", false)) or bool(foe.get("_rtype_rewarded", false)):
		return
	# 在发放前记账，避免奖励/击杀信号重入重复发放；不依赖视觉_tid或尸体消失。
	foe["_rtype_rewarded"] = true
	if bool(foe.get("boss", false)) and not foe.has("chal"):
		var token := _foe_tokens.get(int(foe.get("_tid", 0))) as TokenActor
		if is_instance_valid(token) and token.visible:
			_fallen_guardian = token
			token.play_down()
	if _fx_front != null and float(foe.get("y", 0.0)) >= MIN_VISIBLE_FOE_Y:
		var challenge := clampi(int(foe.get("chal", -1)), -1, 4)
		var large := bool(foe.get("boss", false))
		var accent: Color = CHALLENGE_RIMS[challenge] if challenge >= 0 else (GOLD if large else Color(0.79, 0.72, 0.57))
		var feet: Vector2 = _core.position + Vector2(float(foe["x"]), float(foe["y"])) - FIELD_POS
		_fx_front.spawn_defeat(feet, 45.0 if large else 24.0, accent, large or challenge >= 0)
	_grant_rtype(str(foe.get("rtype", "")))

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
	MenuUI.Motion.bind_button(_q_hit)
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
	MenuUI.Motion.pop(c, false, delay)

func _breathe(c: Control) -> void:
	if c == null:
		return
	MenuUI.Motion.breathe(c)

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
	if not _q_can_act():
		return
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
			func() -> void:
				if _q_pop == layer and is_same(_q_offer, q): _q_accept(), holder)
		_btn("放 弃", Rect2(268, 370, 180, 62), 26, Color(0.93, 0.89, 0.80), Color(0.35, 0.28, 0.18),
			func() -> void:
				if _q_pop == layer and is_same(_q_offer, q): _q_decline(), holder)
	else:
		_btn("关 闭", Rect2(150, 370, 180, 62), 26, Color(0.93, 0.89, 0.80), Color(0.35, 0.28, 0.18),
			func() -> void:
				if _q_pop == layer: _q_close_popup(), holder)
		_lbl("接了就得打完 · 中途不能放弃", Vector2(30, 342), Vector2(420, 22), 14, Color(0.62, 0.20, 0.14), holder, HORIZONTAL_ALIGNMENT_CENTER)
	_pop_bounce(holder)
	_breathe(holder)

func _q_can_act() -> bool:
	return not _run_over and _core != null and _core.running and float(_core.hero.get("hp", 0.0)) > 0.0

func _q_accept() -> void:
	if not _q_can_act() or not _q_cur.is_empty() or _q_offer.is_empty():
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
	if not _q_can_act() or _q_offer.is_empty():
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
	if not _q_can_act() or _q_cur.is_empty():
		return
	var q: Dictionary = _q_cur
	_q_cur = {} # 先关闭结算入口，奖励/清理回调不能再次完成同一奇遇。
	_q_close_popup()
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
	var kind := str(q.get("kind", ""))
	if kind in ["statue", "zone", "guard", "champion", "elite"]:
		_core.clear_order()
		_core._order_fx.clear()
	match kind:
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
	if not _q_can_act() or not _q_cur.is_empty() or not _q_offer.is_empty():
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
	if not _q_can_act() or not _q_cur.is_empty():
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
				var hp := float(h.get("hp", 0.0))
				h["hp"] = minf(hp, maxf(1.0, hp * 0.8)) # 扣血不致死，也不能把不足1血的角色治疗到1。
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
	if not _q_can_act() or not is_same(_q_cur, q) or str(q.get("id", "")) != "dj" or _wen < 100:
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
	if not _q_can_act():
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

func _q_focus(target: Dictionary) -> void:
	if not is_same(_core._order_foe, target):
		_core.order_focus(target, false)

func _q_ai(dt: float) -> void:
	if not _q_can_act():
		return
	_q_ai_t += dt
	if _q_ai_t < 0.3:
		return
	_q_ai_t = 0.0
	if _run_over or _core == null or _q_cur.is_empty():
		return
	var kind := str(_q_cur.get("kind", ""))
	match kind:
		"statue":
			var target: Dictionary = {}
			for f_v in _core.foes:
				var f: Dictionary = f_v
				if not bool(f.get("still", false)) or float(f.get("dying", 0.0)) > 0.0 or float(f.get("hp", 0.0)) <= 0.0:
					continue
				if target.is_empty() or _core.hero_pos.distance_to(Vector2(float(f["x"]), float(f["y"]))) < _core.hero_pos.distance_to(Vector2(float(target["x"]), float(target["y"]))):
					target = f
			if not target.is_empty():
				_q_focus(target)
				return
		"zone":
			var z: Dictionary = _core.zone
			if not z.is_empty() and float(z.get("prog", 0.0)) < float(z.get("goal", 12.0)):
				if not _core._order_has_pos and not _core._in_zone():
					_core.order_move(Vector2(float(z["x"]), float(z["y"])), false)
				return
		"guard":
			var g: Dictionary = _core.guard
			if not g.is_empty():
				var best: Dictionary = {}
				var bd := 1e9
				for f_v2 in _core.foes:
					var f2: Dictionary = f_v2
					if float(f2.get("hp", 0.0)) <= 0.0 or float(f2.get("dying", 0.0)) > 0.0 or bool(f2.get("still", false)):
						continue
					var dd := Vector2(float(f2["x"]), float(f2["y"])).distance_to(Vector2(float(g["x"]), float(g["y"])))
					if dd < bd:
						bd = dd
						best = f2
				if not best.is_empty():
					_q_focus(best)
					return
		"champion", "elite":
			for foe: Dictionary in _core.foes:
				if str(foe.get("kind", "")) == kind and float(foe.get("hp", 0.0)) > 0.0 and float(foe.get("dying", 0.0)) <= 0.0:
					_q_focus(foe)
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
	"baicao": "liuqingqing",
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


func _exit_tree() -> void:
	Aud.stop_battle_sfx()
