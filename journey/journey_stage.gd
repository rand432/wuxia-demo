extends Control
# ============================================================
# journey_stage.gd —— 总调度（v36 · 文钱收益 ×1.2 ＋ v35 开局行装 ＋ v34 那一批）
# v36（用户："文钱收益提升20%"）：全局文钱收益 MONEY_MUL＝1.2——只作用在 _money_gain
#   （打赢/击退来敌的进账）那一口；卖卡、折现、货栈那些"卖东西换钱"不算收益，不动。
# v35b（用户："装备和功法进包裹就行了"）：开局行装拿到的**装备/功法一律进包裹**，
#   **不自动上身**（原来直接给领队穿上）；发奖那一段抽成 _kit_grant()（纯逻辑，好验）。
#   ⚠ 只有"包裹真满"那种极端情况才兜底给领队穿上——绝不把这一件弄丢。
# v35（用户："进入游历第一节 根据当前难度 给予五个选项 装备 披风 玉佩 功法 初始文钱翻倍
#   且文钱收益增加+20%【此选项不消耗文钱 且带出去才能真正带出去 死亡带不走】"）：
#   正式趟进第 1 节摆一页**开局行装 · 五选一**（护甲/玉佩/披风/功法/文钱，给的都是**成品**）。
#   品阶＝data_ladder.q_of_diff(难度)（8 关一档：1~8 凡品 … 33+ 绝品；装备没绝品就往下借）；
#   "文钱"那张＝盘缠 ×2 ＋ 本趟文钱收益 +20%（在 _money_gain 里乘）；领过记 kit_taken（进续行档）。
# v34（用户报的②）：精英战利·三选一的后两轮**只有包裹一条路**——以前"包裹满→退临时仓库，
#   两处都满就直接 append（越过上限）"，等于精英战利能把临时仓库撑爆。现在包裹满＝
#   停下来问一句：**替换**（点包裹里的一件丢掉，换回它的卖价＝盘缠，这件收下）或
#   **折现**（这件不要了，换 cashout_price 文）——与事件三选一（journey_event_flow）
#   同一套口径、同一个手感。落点函数 _elite_enter_full / _elite_do_replace。
# v33（㊺）：①精英战利三抽——「抽 增益」改即刻生效（直接挂进本趟 buffs：只本趟、
#   带不出去；专属只能在手一张——已有就不再抽到）；另两抽照旧进临时仓库。
#   ②入口卡闸统一走 _entry_open——村里仓库（残卡/成品）＋本趟包裹/临时仓库都算
#   "首片到手"（vault_count / vault_item_count 恢复，㊵ 那次误删回滚）。
# v32（㉙b）：①三个"命数"节点（t="fate"）：横财签（攻-12%·文钱+40%）/ 翻财签（搜刮×2.5·
#   翻找见血）/ 血路签（追六节险路）——弹窗二选一［接这注/不收这注］；
#   解锁口径＝GameState.stage_progress ≥ FATE_UNLOCK_STAGE（5），不到门槛则命数节点不出现；
#   ②血条与警惕分开（条 y66、行 y98）。卡面存 _state.buffs（续行档一起保）。
# v31（㉘）：顶条改＝气血条，条下一行＝警惕值（对调）；每节回复统一 10%；
#   搜刮只在 20% 的节出；左上常驻［卡组］钮（卡面存舞台——关掉重开不免费换）。
# v30（优化批⑳）：［退出］去重只贴到注释的那次真正删掉（先建的孤儿钮已除）。
# v29（优化批⑮）：清［退出］重复粘贴残留；_apply_player_look 核过（读 weapon()）。
# v28（优化批⑩）：#15 右上［退出］＋居中确认页（退出＝放弃本趟）。
# v27（优化批①）：#9 正式趟过一节小回复（NODE_HEAL_RATE）；歇脚全复；引子趟照旧。
# v26（R4）：合成全套 → journey_synth_panel.gd（留 _on_synth_pressed 转发口）。
# v25（R4）：结算/殒命/带出 → journey_settle.gd（留 _open_settle/_open_settle_death）。
# v24（R4）：首通报货源换代；行囊清点加高一行。
# v23（R4 ④b）：续行存档——安全点存；结算开就抹档；菜单见档问［继续/重新开始］。
# v22（R4）：①任意战斗败北＝殒命；②成功结算补"随身物带出"；③趟内合成带出才算。
# v21（拆件批）：只搬不改——背景/公共件/角色/包裹/事件流/货郎担各自成件。
# v20（R3）：警戒拉满→遭遇战（敌先手）；敌源三级；战后警戒归零。
# v19（R3）：搜刮——容器按钮；拿取进临时仓库；警戒条接宠物 fx。
# v18（R2）：残卡品级可见。
# v17（R2）：事件三选一／刷新按池位闸过滤；趟内合成即登记。
# v16（R1）：包裹翻页＋出征交接。
# v15：结算「回村」；v15c：主角快照入账本。
# v14：弹窗统一下沉；v13：触控放大；v12：竖屏坐标；v11：竖屏；v10：Cards.name_of。
# v9：面包屑＋窗口自愈。还剩一笔账：战斗（duel_battle 里两人位置与血条）。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const JourneyData := preload("res://journey/data_journey.gd")
const RunState := preload("res://shared/run_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const CreationFlow := preload("res://journey/creation_flow.gd")
const DuelBattle := preload("res://journey/duel_battle.gd")
const StickFighter := preload("res://journey/stick_fighter.gd")
const ActorFactory := preload("res://journey/actor_factory.gd")   # Q版纸片人 / 火柴人 二选一
const Audio := preload("res://shared/audio.gd")   # v65：BGM / 音效总管
const InkTouch := preload("res://shared/ink_touch.gd")   # v65：点击水墨扩散
const FadeIn := preload("res://shared/fade_in.gd")      # v68：进场淡入 + 震动
const PetActor := preload("res://journey/pet_actor.gd")   # ㊿z11：随行宠物（只画，不参战）
const FxLayer := preload("res://journey/fx_layer.gd")
const GameState := preload("res://shared/game_state.gd")
const Loot := preload("res://shared/data_loot.gd")
const LootPanel := preload("res://journey/loot_panel.gd")
const JourneyCommon := preload("res://journey/journey_common.gd")
const Backdrop := preload("res://journey/journey_backdrop.gd")
const CharPanel := preload("res://journey/journey_char_panel.gd")
const BagPanel := preload("res://journey/journey_bag_panel.gd")
const EventFlow := preload("res://journey/journey_event_flow.gd")
const ShopPanel := preload("res://journey/journey_shop_panel.gd")
const JourneySave := preload("res://journey/journey_save.gd")
const JourneyBuffPanel := preload("res://journey/journey_buff_panel.gd")
const Buffs := preload("res://shared/data_buffs.gd")   # ㊺：精英三抽即刻生效读它
const DataPets := preload("res://shared/data_pets.gd")   # ㊿z10：宠物牌（随行加成）
const Settle := preload("res://journey/journey_settle.gd")
const SynthPanel := preload("res://journey/journey_synth_panel.gd")
const Tuning := preload("res://shared/tuning.gd")   # ㉘：可调参数读取口
const Ladder := preload("res://shared/data_ladder.gd")   # v35：开局行装按"难度→品阶"那把尺子取件

# 「回村」按钮切场用（主界面场景）
const MENU_SCENE := "res://menu_sketch.tscn"

# ㉘ 数值外置：下面这批旋钮可以从 res://tuning.cfg 或 user://tuning.cfg 覆盖
#   （读不到＝用这里写着的默认值，行为与改之前一模一样）。
#   用 static var 是因为 const 不能调 Tuning.num()；好处是用它的地方不用改。
#   ⚠ 别在运行中往这些变量赋值——它们是"开机读一次的配置"，不是状态。
#
# 过一节回复＝上限 10%（原正式趟 6%、引子趟全复——统一到 10%）
static var NODE_HEAL_RATE := Tuning.num("journey", "node_heal_rate", 0.10)
# 每节 20% 才出搜刮（原来几乎节节有）
static var LOOT_NODE_CHANCE := Tuning.num("journey", "loot_node_chance", 0.2)
# v80：搜刮解锁难度——正式游历**难度 3**才开（1、2 两趟不摆容器）；引子趟整趟不开
static var LOOT_MIN_DIFF := Tuning.intv("journey", "loot_min_diff", 3)
# 搜刮概率总封顶（翻财＋舍装＋福缘叠上去也不许超过它）
static var LOOT_CHANCE_CAP := Tuning.num("journey", "loot_chance_cap", 0.75)
# ㉛b：命数解锁门槛——"经历到第 FATE_UNLOCK_DIFF 档"（该档已开＝前几档走完）；改这个数即可
static var FATE_UNLOCK_DIFF := Tuning.intv("journey", "fate_unlock_diff", 5)
# v62r 清理：翻财签已经改成"每走一节必定可搜刮"（chance = 1.0），
#   原来那对"搜刮概率倍率/上限"的常量**再没人用**了——留着只会让人以为它还在起作用。
#   ⚠ 那两个 tuning 键（fate_scavenge_mul / fate_scavenge_cap）就不再生效了。
# ㉙b：横财签——文钱收入倍率
static var FATE_GREED_MONEY := Tuning.num("journey", "fate_greed_money", 2.0)   # v62o：文钱 +100%（原 1.4＝+40%）
# ㉛：短绳签——文钱 +25%；满囊签——文钱 -20%；舍装签——搜刮 ×1.5
# v62p（用户："直接短绳加150% 爆率"）：**颜色爆率**倍率——红/金/紫三条权重 ×2.5
#   （不是"这节有没有东西可搜"那条概率，那条 v62o 接错了，已撤）
static var FATE_SHORTROPE_RATE := Tuning.num("journey", "fate_shortrope_rate", 2.5)
static var FATE_FULLBAG_MONEY := Tuning.num("journey", "fate_fullbag_money", 0.475)   # v62l：0.8 → 0.65（-20% → -35%）
static var FATE_NOARMOR_MULT := Tuning.num("journey", "fate_noarmor_mult", 1.5)

# 弹窗统一顶线——单一源已搬去 journey_common.gd；这里留名转发，老代码消费处不用改。
# （若个别版本对跨文件常量较真报错，把 384.0 抄回来即可——同 game_state 的 TALENTS 先例。）
const POPUP_TOP := JourneyCommon.POPUP_TOP

# ---- 拆件批：四个界面件（件只由舞台驱动；件内不反向引舞台——老铁律） ----
var _char = null       # journey_char_panel.gd
var _bag = null        # journey_bag_panel.gd
var _event = null      # journey_event_flow.gd
var _shop = null       # journey_shop_panel.gd
var _synth = null      # journey_synth_panel.gd

var _phase := "creation"
var _state: RunState = null   # ㊿：标注类型，否则 var x := _state.foo() 推不出类型（编译报错过）
var _nodes: Array = []
var _cur_node: Dictionary = {}
var _node := 0
var _busy := false
var _walking := false
var _walk_delay := -1.0
var _scroll_far := 0.0
var _scroll_mid := 0.0
var _scroll_road := 0.0
var _walk_t := 0.0

var _typing := false
var _type_full := ""
var _type_shown := 0.0

var _overlay: Control = null
var _popup: Control = null
var _detail_idx := -1          # 包裹详情用（弹窗内容由包裹件填、底板在舞台）
var _synth_queue: Array = []   # 合成件持它（待放的成品队列；开新趟清）
var _shop_active := false      # 拆件后仍留舞台：DropPanel 认这个名字（接口，别删）
var _told_card := false        # 事件流件读它（首次收卡提示只看一次）
var _just_synth := false       # 包裹件读它（合成后的提示行分支）
var _run_dead := false         # R4：本趟已殒命（结算/回村分叉用；_reset_run_hud 复位）
var _run_fates: Array = []     # v62r（用户："开局命数可多选"）：出征屏选的**全部**命数（重开一趟沿用）
var _elite_round := 1          # ㊿e：精英战利三选一——当前轮次（1 增益 / 2 武学 / 3 装备·兵器）
var _elite_offers: Array = []  # ㊿e：本轮摆出的候选
var _elite_lock := false       # ㊿e：同一帧的第二次点按不放行（防一次点击跳两轮）
var _elite_pending: Dictionary = {}   # v34：满包待收的那一件（等玩家"替换/折现"）
var _elite_pending_name := ""         # v34：它的名字（文案用）
# v62k（用户："精英关的三抽 可以刷新一次 每次选项"）：
#   记"哪一轮已经刷过"——每轮各一次。用轮次号而不是布尔，就不必在"进下一轮"的
#   三个地方（选中/折现/替换）各复位一遍（少一个漏复位的机会）。
var _elite_reroll_round := 0
var _popup_blocking := false   # ㊻：当前这层小弹窗是不是"必须答完才能继续"的

# ---- R3 搜刮 / 警戒（子批①） ----
var _loot_containers: Array = []    # 本节点容器：{cid, items, opened, anim_done}
var _loot_row: Control = null       # 容器按钮行（节点正事办完才摆）
var _loot_skip_warned := false      # 没搜就赶路：第一次提醒、第二次放行
var _loot_panel_open := false       # 搜刮面板开着时屏蔽推进
var _loot_panel_ref = null          # 搜刮面板引用（遭遇强关用；动态调 _close()，不标类型）
var _encounter_pending := false     # 警戒已满、待开打
var _encounter_running := false     # 遭遇战进行中（防重入）
var _node_done := false             # 本节点正事已办完（防重触发战斗/事件）
var _node_entered := false          # 本节已摆出、还没走完（续行闸：防"退出重进刷同一节"）
var _alert_bar: ProgressBar = null      # ㊱：警惕条（与气血条分开）
var _alert_fill: StyleBoxFlat = null
var _alert_label: Label = null
var _hp_bar: ProgressBar = null         # ㊱：气血条
var _hp_fill: StyleBoxFlat = null
var _hp_label: Label = null
# ㊿z10：宠物牌（随行加成——护主/速度；没随行就整块不显示）
var _pet_chip: Panel = null
var _pet_chip_name: Label = null
var _pet_chip_fx: Label = null
# ㊿z11：路上/战斗里的那只宠物（只画不参战）
#   ⚠ 故意**不标类型**：标成 Node2D 之后，`_pet_actor.kind = ...` 这种"它自己的属性"
#     会被静态检查当成"Node2D 上没有 kind"顶回来（本文件 _pose_one 收无类型参数也是为这个）。
var _pet_actor = null
var _pet_offset := Vector2(58.0, 4.0)   # 相对主人**脚底**的站位（狐在脚跟、隼在半空）
var _alert_w60 := false
var _alert_w85 := false

var _walk_home := Vector2(360, 954)
var _walker: Node2D
# ㊿：路上同行的另外两个人（第 0 位永远是 _walker）。
#   他们**由舞台持有**、战斗直接拿来用——战斗不再另开节点，
#   不然"路上 3 个 + 打起来又开 2 个"会同时出现 5 个小人。
var _companions: Array = []
const COMPANION_DX := -66.0     # 同伴跟队形：往左
const COMPANION_DY := -20.0     # 往上（近大远小，看得出层次）
var _fx: Control
var _sub_bar: Panel
var _sub_text: Label
var _hint: Label
var _money_label: Label
var _node_label: Label
var _quit_btn: Button = null
var _buff_btn: Button = null      # ㉘：卡组钮（左上常驻）
# v63h：出手方式钮已搬到战斗界面右上（duel_battle 的 _mode_btn），舞台不再持有
var _buff_panel: Control = null   # ㉘：卡组面板（开着就挡赶路）
var _buff_offers: Array = []      # ㉘：卡面存舞台——关掉重开不免费换（刷新/买光才变）
var _kit_offers: Array = []       # v35：开局行装那五张牌（摆出来的那一刻就摇定，重开不免费换）

# v35（用户："初始文钱翻倍且文钱收益增加+20%"）：选了"文钱"那一张才有——本趟文钱收益加成。
const KIT_MONEY_PCT := 0.20
# v36（用户："文钱收益提升20%"）：**全局**文钱收益（不分哪一趟、不看拿没拿那张）——只改这一个数。
const MONEY_MUL := 1.2

func _ready() -> void:
	Audio.play_bgm("bgm_journey")   # v65：游历场景 BGM
	InkTouch.attach()               # v65：点击水墨扩散
	FadeIn.attach()                 # v68：进场淡入
	GameState.load_game()   # ㊿l：游历场开工先读账——直跑/兜底进游历场时，写盘不再拿空白村账盖真账
	size = get_viewport_rect().size
	print("[游历] 舞台就绪：size=", size, " 视口=", get_viewport_rect().size)
	_state = RunState.new()
	_nodes = JourneyData.build_nodes()
	# ㉛b：命数节点按解锁口径过滤——"经历到第 FATE_UNLOCK_DIFF 档"（该档已开）
	if not _fate_unlocked():
		_nodes = _nodes.filter(func(n): return str(n.get("t", "")) != "fate")
	# 拆件批：四件接线（件只认舞台注入的引用；舞台是唯一驱动方）
	_char = CharPanel.new()
	_char.setup(self)
	_bag = BagPanel.new()
	_bag.setup(self)
	_event = EventFlow.new()
	_event.setup(self)
	_shop = ShopPanel.new()
	_shop.setup(self)
	_synth = SynthPanel.new()
	_synth.setup(self)
	# ④b：续行——菜单把快照塞了进来（pending），原地接上；不走出征交接、不走五问
	if JourneySave.has_pending():
		JourneySave.apply_resume(self)
		return
	# R1：出征交接——出征屏先 deploy_set，这里取货；有货 = 正式趟（跳过五问）
	var dep: Dictionary = GameState.deploy_take()
	var dep_role := str(dep.get("role", ""))
	var dep_fate := str(dep.get("fate", ""))
	# ㊿：这趟同行的人。老档/老入口没有 party 时就退回单人（领队那一个）
	var dep_party: Array = dep.get("party", [])
	if dep_party.is_empty() and dep_role != "":
		dep_party = [dep_role]
	_run_fates = (dep.get("fates", []) as Array).duplicate()
	if _run_fates.is_empty() and dep_fate != "":
		_run_fates = [dep_fate]   # 老存档/老调用点只有单张
	# ㊿c3：兜底续行——没有出征交接、盘上还有没走完的趟：舞台自己接上（入口没接住也不丢档）
	if dep_role == "" and JourneySave.has_save():
		var snap_r: Dictionary = JourneySave.read_save()
		if not snap_r.is_empty():
			print("[续行] 兜底接档：第 ", int(snap_r.get("node", 0)) + 1, " 节（入口未接档）")
			JourneySave.set_pending(snap_r)
			JourneySave.apply_resume(self)
			return
	if dep_role != "":
		# ㊿：整队交出去（begin_formal 收到数组就按人头各装一份）
		# v63（用户："选多个命数时会出错…选了加包裹位后又选其他的，进去后包裹+8不生效"）：
		#   病根：这里传的是 **dep_fate**（老字段＝只含第一张 ✗）——v62r 已经把整批存进
		#   _run_fates，可"开局那一下"忘了换过来 ✗ 于是第一趟只挂第一张、其余全丢 ✗。
		#   重开沿用那一条（下面 L744）当时改了，这条漏了——现在两处统一走 _run_fates。
		_state.begin_formal(dep_party, int(dep.get("diff", 1)), _run_fates)   # ㉛：命数**整批**随出征带上
	else:
		_state.set_role("player")
	_build()
	_hide_ui_all()
	if dep_role != "":
		_start_formal_run()
		return
	# ㊿m：兜底——首趟已走通、又没有出征交接和续行档（＝直接运行了这个场景）：
	# 不重演"十六岁"，退回主界面走正门（村里点［历练］出征）
	GameState.load_game()
	if GameState.first_journey_done:
		print("[游历] 直跑且首趟已走通——不演引子，退回主界面（下次请从村里［历练］出征）")
		var err_m := get_tree().change_scene_to_file(MENU_SCENE)
		if err_m != OK:
			print("[游历] 退场失败，错误码=", err_m, "；检查路径：", MENU_SCENE)
		return
	var cf := CreationFlow.new()
	cf.done.connect(_on_created)
	add_child(cf)

# ============ 构建 ============

func _build() -> void:
	# ⚠ 战斗（duel_battle）会**直接复用**这个 walker 和下面的同伴节点当自己人，
	#   所以这里必须和战斗用同一个工厂——不然一开打就变成"一个Q版 + 两个火柴人"。
	_walker = ActorFactory.make("player")
	_walker.position = _walk_home
	add_child(_walker)
	_apply_player_look()

	_fx = FxLayer.new()
	add_child(_fx)

	_money_label = UiKit.make_label(self, Vector2(20, 14), Vector2(300, 40), 24, UiKit.INK)
	UiKit.set_text(_money_label, "盘缠 0 文")

	# v63（用户："最上方的文字重叠"）：原来在 (400,18) 宽 300——战斗中【战报/敌情】按钮
	#   就压在它上面 ✗（按钮 x440 起、标签 x400~700）。挪到按钮左边（318~438），不再叠。
	_node_label = UiKit.make_label(self, Vector2(306, 18), Vector2(132, 34), 20, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	_node_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 优化批⑩（#15）：退出游历——右上角小钮（防误触：先弹确认页）
	# v30 补刀：这里曾叠着两颗（v29 只清了注释）——从此只留一颗
	_quit_btn = UiKit.make_button(self, Vector2(600, 16), Vector2(104, 44), "退出", 18)
	_quit_btn.pressed.connect(_ask_quit_journey)

	# ㉘/㊱：卡组——左上常驻小钮（这趟请的卡；只这趟生效）
	_buff_btn = UiKit.make_button(self, Vector2(20, 124), Vector2(150, 48), "卡组", 18)
	_buff_btn.pressed.connect(_open_buffs)

	# v63h（"战斗就爬塔那样"）：出手方式那颗钮**搬回战斗界面右上**了（爬塔同款两排大钮），
	#   这里不再摆——状态仍在 DuelBattle.last_manual，两处共用一份。
	# v63k：取证钮也挪去**战斗界面**第二排了（用户："抽搐是战斗的时候"）——这里不加。

	_build_alert()

	_char._build_char_panel()
	_bag._build_bag()

	_sub_bar = Panel.new()
	_sub_bar.position = Vector2(20, 1030)
	_sub_bar.size = Vector2(680, 210)
	_sub_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.10, 0.09, 0.10, 0.88)
	ssb.set_corner_radius_all(10)
	ssb.border_color = Color(1, 1, 1, 0.10)
	ssb.set_border_width_all(1)
	_sub_bar.add_theme_stylebox_override("panel", ssb)
	_sub_bar.gui_input.connect(_on_sub_gui)
	add_child(_sub_bar)

	_sub_text = UiKit.make_label(_sub_bar, Vector2(24, 20), Vector2(610, 160), 26, Color(0.94, 0.91, 0.84))
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_hint = UiKit.make_label(_sub_bar, Vector2(618, 156), Vector2(48, 48), 26, Color(0.90, 0.85, 0.70))
	UiKit.set_text(_hint, "▼")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = false

	gui_input.connect(_on_root_gui)

# ---- ㊱：气血条一条（上）＋警惕条一条（下）——各一条、分开不叠 ----
func _build_alert() -> void:
	_hp_bar = ProgressBar.new()
	_hp_bar.position = Vector2(178, 66)
	_hp_bar.size = Vector2(228, 18)
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill = StyleBoxFlat.new()
	_hp_fill.bg_color = Color(0.40, 0.60, 0.36)
	_hp_fill.set_corner_radius_all(5)
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill)
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color(0.16, 0.14, 0.14, 0.80)
	hb.set_corner_radius_all(5)
	_hp_bar.add_theme_stylebox_override("background", hb)
	add_child(_hp_bar)
	_hp_label = UiKit.make_label(self, Vector2(178, 66), Vector2(228, 18), 12, Color(0.96, 0.94, 0.90))
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_alert_bar = ProgressBar.new()
	_alert_bar.position = Vector2(178, 94)
	_alert_bar.size = Vector2(228, 14)
	_alert_bar.show_percentage = false
	_alert_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_fill = StyleBoxFlat.new()
	_alert_fill.bg_color = Color(0.42, 0.44, 0.50)
	_alert_fill.set_corner_radius_all(4)
	_alert_bar.add_theme_stylebox_override("fill", _alert_fill)
	var ab := StyleBoxFlat.new()
	ab.bg_color = Color(0.16, 0.14, 0.14, 0.80)
	ab.set_corner_radius_all(4)
	_alert_bar.add_theme_stylebox_override("background", ab)
	add_child(_alert_bar)
	_alert_label = UiKit.make_label(self, Vector2(178, 94), Vector2(228, 14), 11, Color(0.96, 0.94, 0.90))
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# ㊿z10：宠物牌——"护主"这类随行加成以前在游历里一个字都不显示，
	#   玩家只能盯着气血数字猜它到底算没算（其实是算了的，见 run_state 的快照）。
	#   位置：血条/警惕条右边那块空档（x 410~600，y 62~116），退出钮在 y16~60，不撞。
	_pet_chip = Panel.new()
	_pet_chip.position = Vector2(414, 62)
	_pet_chip.size = Vector2(186, 54)
	_pet_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pcb := StyleBoxFlat.new()
	pcb.bg_color = Color(0.97, 0.94, 0.87, 0.93)
	pcb.set_corner_radius_all(8)
	pcb.border_color = Color(0.42, 0.33, 0.22, 0.42)
	pcb.set_border_width_all(1)
	_pet_chip.add_theme_stylebox_override("panel", pcb)
	add_child(_pet_chip)
	_pet_chip_name = UiKit.make_label(_pet_chip, Vector2(10, 5), Vector2(166, 20), 14, UiKit.SEAL)
	_pet_chip_name.max_lines_visible = 1
	_pet_chip_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_pet_chip_fx = UiKit.make_label(_pet_chip, Vector2(10, 26), Vector2(166, 22), 13, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
	_pet_chip_fx.max_lines_visible = 2
	_pet_chip_fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_pet_chip()

func _refresh_alert() -> void:
	if _hp_bar == null or _alert_bar == null or _state == null:
		return
	# ㊱：气血条（上）——低血变黄红；数字嵌在条里
	# ㊿：三人成队后这条＝**全队血线**（三条横条会挤成一团），后面把每个人列出来。
	#   单人时那一串就是"气血 100 / 100"，与以前显示一致。
	var tot := 0.0
	var tot_max := 0.0
	var keep_i: int = _state.active_i
	var seg: Array = []
	var n: int = _state.member_count()
	for i in n:
		_state.use_member(i)
		tot += float(_state.hp)
		tot_max += float(maxi(1, _state.hp_max))
		if n > 1:
			var nm := str(GameState.role_data(str(_state.role_id)).get("name", "?"))
			var tag := "前" if i == 0 else ("中" if i == 1 else "后")
			seg.append(tag + nm + " " + str(_state.hp))
	_state.use_member(keep_i)
	var hpm: float = maxf(1.0, tot_max)
	var hpv: float = clampf(tot / hpm, 0.0, 1.0)
	_hp_bar.max_value = hpm
	_hp_bar.value = tot
	if _hp_fill != null:
		var hcol := Color(0.40, 0.60, 0.36)
		if hpv <= 0.30:
			hcol = Color(0.72, 0.16, 0.12)
		elif hpv <= 0.60:
			hcol = Color(0.85, 0.66, 0.20)
		_hp_fill.bg_color = hcol
	if seg.is_empty():
		UiKit.set_text(_hp_label, "气血 " + str(int(tot)) + " / " + str(int(hpm)))
	else:
		UiKit.set_text(_hp_label, str(int(tot)) + "/" + str(int(hpm)) + "　" + " · ".join(PackedStringArray(seg)))
	# ㊱：警惕条（下）——过半变金、过 85% 变红（字闪烁照旧）
	var mx: float = maxf(1.0, _state.alert_max())
	var v: float = _state.alert
	_alert_bar.max_value = mx
	_alert_bar.value = v
	var col := Color(0.42, 0.44, 0.50)
	if v >= mx * 0.85:
		col = Color(0.72, 0.16, 0.12)
	elif v >= mx * 0.60:
		col = Color(0.85, 0.66, 0.20)
	if _alert_fill != null:
		_alert_fill.bg_color = col
	UiKit.set_text(_alert_label, "警惕 " + str(int(round(v))) + " / " + str(int(round(mx))))
	if v >= mx * 0.60 and not _alert_w60:
		_alert_w60 = true
		UiKit.float_text(self, "风声有点不对……", UiKit.GOLD)
	if v >= mx * 0.85 and not _alert_w85:
		_alert_w85 = true
		UiKit.float_text(self, "杀机四伏！", UiKit.SEAL)
	if _state.alert_full() and not _encounter_running:
		_encounter_pending = true

# ============ 覆盖层（底板留在舞台；弹窗内容由各件自己填） ============

func _make_veil(alpha := 0.52) -> ColorRect:
	_char._set_char_panel(false)
	var veil := UiKit.make_veil(self, size, alpha)
	_overlay = veil
	_bag.bring_panel_front()
	_char.bring_btn_front()
	return veil

func _make_popup_veil(blocking := false) -> ColorRect:
	_char._set_char_panel(false)
	var veil := UiKit.make_veil(self, size, 0.40)
	_popup = veil
	_popup_blocking = blocking
	# ㊻：blocking＝"必须答完才能继续"的选择页/确认页（精英三选一 / 命数抉择 / 签摊 /
	#   离开确认 / 退出确认）。
	#   ⚠ 这两行不能无条件调：bring_panel_front 把包裹提到遮罩**上面**，
	#   于是包裹格还能点——一点就进 _show_card_detail → _close_popup()，
	#   把这一页直接顶掉。而 _busy 还挂着 true、_elite_round 也没往前走，
	#   收尾函数再也不会被调到，人就永久卡在这一节里了。
	#   （表现：精英三选一第三轮点开包裹里的装备介绍 → 卡死，连［退出］都回
	#    "先把手头的事办完"。见 journey_bag_panel._show_card_detail 的同名守卫。）
	if not blocking:
		_bag.bring_panel_front()
		_char.bring_btn_front()
	return veil

func _close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null
	_popup_blocking = false
	_detail_idx = -1

func _close_overlay() -> void:
	_close_popup()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null

# ============ 刷新 ============

func _money() -> void:
	UiKit.set_text(_money_label, "盘缠 " + str(_state.money) + " 文")

func _refresh_all() -> void:
	_char._refresh_stats_ui()
	_bag._refresh_bag()
	_money()
	_refresh_buff_btn()
	_refresh_alert()

# ㊿：队伍里有人带伤吗（决定要不要飘"+N"）
func _party_hurt() -> bool:
	if _state == null:
		return false
	var keep: int = _state.active_i
	var hurt := false
	for i in _state.member_count():
		_state.use_member(i)
		if _state.hp < _state.hp_max:
			hurt = true
			break
	_state.use_member(keep)
	return hurt

func _apply_player_look() -> void:
	if _walker == null or _state == null:
		return
	_walker.set_equipment(_state.weapon(), "douli", "short")
	if _walker.has_method("set_role"):
		_walker.set_role(str(_state.role_id))
	_sync_companions()
	_sync_pet_actor()   # ㊿z11：随行宠物跟着上/下场

# ㊿z11：随行宠物——有就建一个（或换种类），没有就收掉。
#   ⚠ 只画不参战：不加进 _companions、也不进 duel_battle 的成员表；
#     数值加成（护主/速度）在 GameState.effective_stats 那一层，与此无关。
func _sync_pet_actor() -> void:
	if _walker == null:
		return
	var pid := str(GameState.pet_follow)
	if pid == "":
		if _pet_actor != null and is_instance_valid(_pet_actor):
			_pet_actor.queue_free()
		_pet_actor = null
		return
	var kind := "hawk" if pid == "qing_sun" else "fox"
	# 狐在脚跟边（脚下），隼在半空（主人侧上方）——看种类给不同的站位
	_pet_offset = Vector2(52.0, -150.0) if kind == "hawk" else Vector2(58.0, 4.0)
	if _pet_actor == null or not is_instance_valid(_pet_actor):
		_pet_actor = PetActor.new()
		# v93 修（用户："宠物挡住了"）：**摆到队伍后面**——原来 add_child 在主人/同伴之后，
		#   画在最上层，站在脚边时正好糊在队友身上。z_index=-1 让它压在人和场景之下。
		_pet_actor.z_index = -1
		add_child(_pet_actor)
	_pet_actor.kind = kind
	_pet_actor.position = _walker.position + _pet_offset
	_pet_actor.visible = _walker.visible
	print("[游历] 随行宠物上场：", DataPets.name_of(pid), "（", kind, "）")

# ㊿：让路上的同伴人数/装扮/站位跟上"这趟带了谁"。
#   单人趟时 _companions 是空的——路上还是一个 walker，跟以前一模一样。
func _sync_companions() -> void:
	if _state == null or _walker == null:
		return
	# ⚠ 数人用 member_count()（成员表长度），不要用 party_role_ids()——后者会去重，
	#   与"战斗里按成员下标装人"（duel_battle._compose_allies）会数不到一块儿去。
	var want: int = clampi(_state.member_count() - 1, 0, 2)
	while _companions.size() > want:
		var extra = _companions.pop_back()
		if extra != null and is_instance_valid(extra):
			extra.queue_free()
	while _companions.size() < want:
		var nidx := _companions.size() + 1
		var nd = ActorFactory.make(str(_state.member_at(nidx).get("role_id", "")))
		add_child(nd)
		_companions.append(nd)
	for i in _companions.size():
		var c = _companions[i]
		if c == null or not is_instance_valid(c):
			continue
		var idx := i + 1
		c.position = _walk_home + Vector2(COMPANION_DX * float(idx), COMPANION_DY * float(idx))
		var sc := 1.0 - 0.05 * float(idx)
		c.scale = Vector2(sc, sc)
		if c.has_method("set_equipment"):
			c.set_equipment(_state.weapon_of_member(_state.member_at(idx)), "douli", "short")
		if c.has_method("set_role"):
			c.set_role(str(_state.member_at(idx).get("role_id", "")))
		c.visible = _walker.visible

# ㉞：回复飘在角色头上（原来走 UiKit.float_text＝飘屏幕顶上，看不出是谁回的血）
func _float_over_walker(t: String, col: Color) -> void:
	if _walker == null:
		UiKit.float_text(self, t, col)
		return
	var lb := UiKit.make_label(self, _walker.position + Vector2(-140.0, -238.0), Vector2(280, 36), 26, col)
	UiKit.set_text(lb, t)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ⚠ make_label 里已经 add_child 过了——这里再加一次会报
	#   "Can't add child 'X' to 'JourneyStage', already has a parent"（每场战斗收尾都刷一条）
	var tw := create_tween()
	tw.tween_property(lb, "position:y", lb.position.y - 34.0, 0.8)
	tw.parallel().tween_property(lb, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lb.queue_free)

# ---- ㉘：卡组（增益）小担 ----

# v63h：出手方式那颗钮搬到战斗界面右上去了（duel_battle 的 _mode_btn），
#   舞台上的旧钮与旧画法一并撤掉——状态仍走 DuelBattle.last_manual。

func _refresh_buff_btn() -> void:
	if _buff_btn == null or _state == null:
		return
	if _state.buff_count() > 0:
		UiKit.set_btn_text(_buff_btn, "卡组 " + str(_state.buff_count()))
	else:
		UiKit.set_btn_text(_buff_btn, "卡组")

func _open_buffs() -> void:
	if _phase != "journey" or _state == null:
		return
	if _buff_panel != null and is_instance_valid(_buff_panel):
		return
	if _busy or _encounter_running or _loot_panel_open:
		UiKit.float_text(self, "先把手头的事办完", UiKit.SEAL)
		return
	# 首开/买光才重摇——卡面存舞台（关掉重开不免费换）
	# ㊿u：摇之前把"这趟带了谁"递进去——不在阵里的人，他的专属卡不进池
	if _buff_offers.is_empty():
		_buff_offers = Buffs.roll_offers(str(_state.role_id), 3, _state.party_role_ids())
	_buff_panel = JourneyBuffPanel.new()
	add_child(_buff_panel)
	_buff_panel.setup(self, _state, _buff_offers)
	_buff_panel.tree_exited.connect(_on_buff_gone)

func _on_buff_gone() -> void:
	_buff_panel = null

# ============ 界面显隐 ============

func _hide_ui_all() -> void:
	_walker.visible = false
	for _c0 in _companions:
		if _c0 != null and is_instance_valid(_c0):
			_c0.visible = false
	if _pet_actor != null and is_instance_valid(_pet_actor):
		_pet_actor.visible = false
	_sub_bar.visible = false
	_bag.set_ui_visible(false)
	_money_label.visible = false
	_node_label.visible = false
	if _quit_btn != null:
		_quit_btn.visible = false
	if _buff_btn != null:
		_buff_btn.visible = false
	if _buff_panel != null and is_instance_valid(_buff_panel):
		_buff_panel.queue_free()
	_char.set_talent_visible(false)
	_char.set_btn_visible(false)
	_alert_bar.visible = false
	_alert_label.visible = false
	_hp_bar.visible = false
	_hp_label.visible = false
	_char._set_char_panel(false)

func _show_ui_all() -> void:
	_walker.visible = true
	for _c1 in _companions:
		if _c1 != null and is_instance_valid(_c1):
			_c1.visible = true
	if _pet_actor != null and is_instance_valid(_pet_actor):
		_pet_actor.visible = true
		_pet_actor.position = _walker.position + _pet_offset
	_sub_bar.visible = true
	_bag.set_ui_visible(true)
	_money_label.visible = true
	_node_label.visible = true
	if _quit_btn != null:
		_quit_btn.visible = true
	if _buff_btn != null:
		_buff_btn.visible = true
	_char.set_talent_visible(true)
	_char.set_btn_visible(true)
	_alert_bar.visible = true
	_alert_label.visible = true
	_hp_bar.visible = true
	_hp_label.visible = true
	_char._set_char_panel(true)
	_refresh_alert()
	print("[游历] 界面已显示")

# ============ 正式趟开跑（R1） ============

# 出征交接有货时走这里：不走五问，账上拍完快照直接上路。
func _start_formal_run() -> void:
	_phase = "journey"
	# v99（出征屏三档）：这一趟的爆率倍率交给 data_ladder（红/金两条放大；收尾复位）
	Ladder.run_rate_mul = maxf(0.0, GameState.deploy_drop_mul)
	# ㊿b：正式趟按档排新表（五节一轮×轮数，boss 收尾；引子趟照旧吃老表——新手游历不改）
	_nodes = JourneyData.build_nodes_formal(int(_state.diff))
	_show_ui_all()
	_node = 0
	_busy = false
	_walking = true
	_walk_delay = -1.0
	_walk_t = 0.0
	_reset_run_hud()
	# ㉛：血路签（出征屏选的）——出发就把追加的险路整段排在第 1 节后面（节数看 EXTRA_ROADS）
	if _has_fate("fate_bloodpath"):
		var roads: Array = JourneyData.EXTRA_ROADS.duplicate(true)
		for i in roads.size():
			_nodes.insert(1 + i, roads[i])
		UiKit.float_text(self, "近道在后头——前方多出 " + str(roads.size()) + " 节险路", UiKit.SEAL)
	_told_card = true
	_just_synth = false
	_refresh_all()
	UiKit.float_text(self, "出征 · " + GameState.diff_name(_state.diff) + "　盘缠 " + str(_state.money) + " 文", UiKit.GOLD)
	_enter_node()
	# v35（用户："进入游历第一节 根据当前难度 给予五个选项…五选一"）：第一节摆开局行装
	if not _state.kit_taken:
		_open_start_kit()

# ============ 创建完成 → 开局 ============

func _on_created(talents: Array, gift_sid: String) -> void:
	print("[游历] 创建完成：天赋=", talents, " 礼物=", gift_sid)
	_phase = "journey"
	_state.reset(talents, gift_sid)
	_snapshot_player()
	# ㊿g：［下山］即落盘——首趟"开跑"这一刻的全局账当场写进文件，后面任何死法都不亏
	GameState.save_game()
	print("[游历] 下山已落盘：村况=", GameState.village_stage, " 首趟=", GameState.first_journey_done)
	_show_ui_all()
	_node = 0
	_busy = false
	_walking = true
	_walk_delay = -1.0
	_walk_t = 0.0
	_reset_run_hud()
	_told_card = false
	_refresh_all()
	if gift_sid != "":
		UiKit.float_text(self, "三张残卡已入包裹 · 行前盘缠 " + str(RunState.START_MONEY) + " 文", UiKit.SEAL)
	else:
		UiKit.float_text(self, "行前盘缠 " + str(RunState.START_MONEY) + " 文 · 左上角［角色］可开合面板", UiKit.INK)
	_enter_node()

func _start_run() -> void:
	if _state.mode == "formal":
		# v99：重开一趟也照这一档的爆率倍率来
		Ladder.run_rate_mul = maxf(0.0, GameState.deploy_drop_mul)
		# ㊿：重开一趟——节点表重摇（词缀"随机"跟着换手）；血路签的险路照旧补上
		_nodes = JourneyData.build_nodes_formal(int(_state.diff))
		if _has_fate("fate_bloodpath"):
			var re_roads: Array = JourneyData.EXTRA_ROADS.duplicate(true)
			for i in re_roads.size():
				_nodes.insert(1 + i, re_roads[i])
		# ㊿：重开沿用整支队伍，不是只带当前那一个——以前这里传的是 role_id（单人形状）
		_state.begin_formal(_state.party_role_ids(), int(_state.diff), _run_fates)   # ㉛：重开沿用同一批命数
	else:
		var keep: Array = _state.talents.duplicate()
		_state.reset(keep, "")
	_shop_active = false
	_shop._reset()
	_event._reset()
	_synth_queue.clear()
	_close_overlay()
	_node = 0
	_busy = false
	_walking = true
	_walk_delay = -1.0
	_walk_t = 0.0
	_reset_run_hud()
	_told_card = true
	_just_synth = false
	_refresh_all()
	UiKit.float_text(self, "行前盘缠 " + str(RunState.START_MONEY) + " 文", UiKit.GOLD)
	_enter_node()
	# v35：［再来一趟］重开也要摆开局行装（kit_taken 在 begin_formal 里已复位）；
	#   引子趟（mode=="intro"）不算正式游历，不摆。
	if _state.mode == "formal" and not _state.kit_taken:
		_open_start_kit()

func _enter_node() -> void:
	_walk_delay = -1.0
	_busy = false
	_walking = true
	_node_done = false
	_node_entered = true    # 本节内容即将摆出——先记下（存档点就跟着这条走）
	_cur_node = _nodes[_node]
	print("[游历] 第 ", _node + 1, " / ", _nodes.size(), " 节：", str(_cur_node.get("t", "")))
	UiKit.set_text(_node_label, "第 " + str(_node + 1) + " / " + str(_nodes.size()) + " 节")
	_type_full = str(_cur_node.get("text", "……"))
	_type_shown = 0.0
	_typing = true
	UiKit.set_text(_sub_text, _type_full)
	_sub_text.visible_characters = 0
	_hint.visible = false
	JourneySave.save_run(self)   # ④b：安全点——进节点

func _advance() -> void:
	_close_overlay()
	_shop_active = false
	_busy = false
	_walking = true
	_just_synth = false
	_node_done = false
	_node_entered = false   # 本节已经走完／放弃了——闸复位（下一节的 _enter_node 再立）
	_clear_loot()
	if _state != null:
		_state.alert_drop(RunState.ALERT_NODE_DROP)
		# ============================================================
		# v62o（用户重做命数）：短绳签换了效果——**警戒 +15 那条撤掉**，
		#   改成"**每过一节攻击力 -2%**"（可叠，下限 30%）。计数就加在这儿：
		#   每过一节 +1，战斗建人时按它折 atk（见 duel_battle._build_ally）。
		#   ⚠ 只有拿了这张签才累加，没拿的人 `fate_atk_mul()` 恒 1.0。
		# ============================================================
		if _has_fate("fate_shortrope"):
			_state.fate_node_passed += 1
			_refresh_alert()
		# ㉘：统一每节回复＝上限 10%（歇脚全复照旧）
		# ㊿：三个人一起回——以前只回"当前成员"那一个
		if _party_hurt():
			# v36：阅历线·防御「调息」段——每节恢复 10% → +N%
			var heal_rate: float = NODE_HEAL_RATE + float(GameState.insight_fx().get("heal_add", 0.0))
			var heal_n: int = _state.party_heal(heal_rate)
			_float_over_walker("气血 +" + str(heal_n), UiKit.GREEN)   # ㉞：飘人，不飘顶
			_refresh_alert()
	_bag._update_tip()
	if _node >= _nodes.size() - 1:
		return
	_node += 1
	_walk_delay = 0.9
	_typing = false
	_type_full = ""
	UiKit.set_text(_sub_text, "……")
	_sub_text.visible_characters = -1
	_hint.visible = false

func _continue() -> void:
	if _phase != "journey" or _busy or _loot_panel_open:
		return
	if _buff_panel != null and is_instance_valid(_buff_panel):
		return   # ㉘：卡组面板开着——先收摊再赶路
	if _typing:
		_typing = false
		_sub_text.visible_characters = -1
		_hint.visible = true
		return
	if _walk_delay >= 0.0:
		_walk_delay = -1.0
		_enter_node()
		return
	if _node_done:
		_loot_leave_tap()
		return
	match str(_cur_node.get("t", "")):
		"story":
			_advance()
		"gain":
			_open_gain(_cur_node)
		"rest_shop":
			# ㊿：歇脚＋商店算一个节点——先调息（全复），再开货郎担
			# ㊿：全队调息（三个人一起回满）
			_state.party_full_heal()
			_shop._open_shop()
			_float_over_walker("调息半日 · 气血已复", UiKit.GREEN)
		"rest":
			_state.party_full_heal()   # ㊿：全队回满
			_float_over_walker("调息半日 · 气血已复", UiKit.GREEN)   # ㉞：飘人，不飘顶
			_advance()
		"event":
			_event._open_event(_cur_node)
		"battle":
			_begin_fight(_cur_node)
		"shop":
			_shop._open_shop()
		"fate":
			_open_fate(_cur_node)
		"settle":
			_open_settle()

# ============ 每帧 ============

func _process(delta: float) -> void:
	if size.x < 8.0 or size.y < 8.0:
		size = get_viewport_rect().size
		print("[游历] 尺寸异常，已按视口修正=", size)
	if _phase == "journey":
		# ㊿z11：宠物跟着主人（lerp 追，不挂主人身上）——主人被战斗的补间推出去/退回来时，
		#   它慢半拍跟上，看着像"跟在脚边"，也不用去动 duel_battle 的位移队列。
		if _pet_actor != null and is_instance_valid(_pet_actor) and _walker != null and is_instance_valid(_walker):
			if _pet_actor.visible:
				var want: Vector2 = _walker.position + _pet_offset
				_pet_actor.position = _pet_actor.position.lerp(want, clampf(delta * 5.5, 0.0, 1.0))
		if _walking and not _busy and _walk_delay < 0.0:
			_walk_t += delta
			_scroll_far = fposmod(_scroll_far + delta * 11.0, 100000.0)
			_scroll_mid = fposmod(_scroll_mid + delta * 27.0, 100000.0)
			_scroll_road = fposmod(_scroll_road + delta * 95.0, 100000.0)
			_update_walk_pose()
		if _typing:
			_type_shown += delta * 45.0
			if _type_shown >= float(_type_full.length()):
				_typing = false
				_sub_text.visible_characters = -1
				_hint.visible = true
			else:
				_sub_text.visible_characters = int(_type_shown)
		if _walk_delay >= 0.0:
			_walk_delay -= delta
			if _walk_delay <= 0.0:
				_enter_node()
		if _hint.visible:
			_hint.modulate.a = 0.40 + 0.60 * absf(sin(float(Time.get_ticks_msec()) / 320.0))
		if _encounter_pending and not _encounter_running and not _busy and _walk_delay < 0.0:
			_start_encounter()
		if _alert_label != null and _state != null:
			if _state.alert >= _state.alert_max() * 0.85:
				_alert_label.modulate.a = 0.55 + 0.45 * absf(sin(float(Time.get_ticks_msec()) / 260.0))
			else:
				_alert_label.modulate.a = 1.0
	queue_redraw()

func _update_walk_pose() -> void:
	_pose_one(_walker, 0.0)
	# ㊿：同伴一起迈步——各错开一点相位，不然三个人像一个人照出来的
	for i in _companions.size():
		var c = _companions[i]
		if c != null and is_instance_valid(c):
			_pose_one(c, 0.7 + float(i) * 0.9)

func _pose_one(w, off: float) -> void:
	if w == null or not is_instance_valid(w):
		return
	var ph := _walk_t * 8.0 + off
	w.tgt[0] = 86.0 + sin(ph * 2.0) * 1.5
	w.tgt[5] = -74.0 + sin(ph) * 22.0
	w.tgt[6] = -84.0 - maxf(0.0, sin(ph + 0.7)) * 18.0
	w.tgt[7] = -74.0 - sin(ph) * 22.0
	w.tgt[8] = -84.0 - maxf(0.0, -sin(ph + 0.7)) * 18.0
	w.tgt[1] = -72.0 - sin(ph) * 9.0
	w.tgt[2] = -118.0 + sin(ph) * 7.0
	w.tgt[3] = -110.0 + sin(ph) * 9.0
	w.tgt[4] = -95.0 - sin(ph) * 6.0

# ============ 输入 ============

func _on_root_gui(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_continue()

func _on_sub_gui(ev: InputEvent) -> void:
	_on_root_gui(ev)

func _unhandled_input(event: InputEvent) -> void:
	if _phase != "journey":
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and (ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER):
			_continue()

# 全局兜底：在任何地方松开左键，都收起"按住提示"小框（防"按着行拖走再松手"）。
# （小框住在角色件里；件是 RefCounted 收不到输入回调，所以由舞台转发。）
func _input(event: InputEvent) -> void:
	if _char == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_char._press_tip_hide()

# ============ R3 搜刮 / 临时仓库 ============

func _reset_run_hud() -> void:
	_clear_loot()
	_node_done = false
	_node_entered = false
	_run_dead = false
	_encounter_pending = false
	_encounter_running = false
	_loot_panel_open = false
	_loot_panel_ref = null
	_alert_w60 = false
	_alert_w85 = false
	_buff_offers.clear()   # ㉘：新的一趟——卡面重摇
	_refresh_pet_chip()    # ㊿z10：随行宠物可能换过了（回村换的），牌面跟着走
	_refresh_alert()

func _loot_luck() -> float:
	return float(GameState.pet_fx().get("search_luck", 0))

# ㊿z10：宠物牌刷新——没随行就整块藏起来（"只带一只"，留守的那只不算）
func _refresh_pet_chip() -> void:
	if _pet_chip == null or not is_instance_valid(_pet_chip):
		return
	var pid := str(GameState.pet_follow)
	if pid == "":
		_pet_chip.visible = false
		return
	_pet_chip.visible = true
	UiKit.set_text(_pet_chip_name, "宠物 · " + DataPets.name_of(pid))
	var fx := DataPets.fx_text(GameState.pet_fx_of(pid))
	UiKit.set_text(_pet_chip_fx, fx if fx != "" else "——")

func _loot_speed() -> float:
	return float(GameState.pet_fx().get("search_speed", 0))

# ㊲/㊺：入口卡——首片（part 0）到手后，该套其余片才出货；村里仓库（残卡/成品）＋本趟包裹/临时仓库都算"到手"
func _entry_open(sid: String) -> bool:
	if GameState.vault_count(sid, 0) > 0:
		return true
	if GameState.vault_item_count(sid) > 0:
		return true
	if _state == null:
		return false
	if _arr_has_part(_state.bag, sid, 0):
		return true
	if _arr_has_part(_state.loot_bag, sid, 0):
		return true
	return false

func _arr_has_part(arr: Array, sid: String, part: int) -> bool:
	for e_v in arr:
		var e: Dictionary = e_v
		if str(e.get("kind", "")) != "card":
			continue
		var es := str(e.get("set", e.get("id", "")))
		if es == sid and int(e.get("part", -1)) == part:
			return true
	return false

func _filter_entry_cards(items: Array) -> Array:
	var out: Array = []
	for e_v in items:
		var e: Dictionary = e_v
		var keep := true
		if str(e.get("kind", "")) == "card" and int(e.get("part", 0)) > 0:
			var sid := str(e.get("id", e.get("set", "")))
			if not _entry_open(sid):
				keep = false   # 没拿到"上/首片"——其余片不出
		if keep:
			out.append(e)
	return out

# 节点正事办完：摆容器（没得搜就直接赶路）
func _finish_node(kind: String) -> void:
	_close_overlay()
	_node_done = true
	_node_entered = false   # 本节正事办完——内容已兑现，闸先复位再落盘
	_spawn_loot(kind)
	JourneySave.save_run(self)   # ④b：安全点——正事办完（容器摆出）
	if _loot_containers.is_empty():
		_advance()
		return
	_show_loot_row()
	_busy = false
	UiKit.float_text(self, "路边留下了可搜的东西——点它翻找", UiKit.INK)

# v80（用户："移除引子游历的搜刮功能" + "移除正式游历前两关的搜刮功能，正式游历难度3解锁"）：
#   两条门槛**都在这里**收口——搜刮只有这一个生成点，闸在这儿，别处不会漏。
#     ① 引子趟（mode=="intro"）：整趟不摆容器；
#     ② 正式趟：难度 < 3 不摆（难度 1、2 是新手两趟）。
func _loot_allowed() -> bool:
	if str(_state.mode) == "intro":
		return false
	if int(_state.diff) < LOOT_MIN_DIFF:
		return false
	return true

func _spawn_loot(kind: String) -> void:
	_clear_loot()
	if not _loot_allowed():
		print("[搜刮] 本趟不开放（引子趟，或正式难度 < ", LOOT_MIN_DIFF, "）")
		return
	# ㉘：20% 才出——大多数节没有可搜的；㉛：舍装签 ×1.5（合计封顶 75%）
	# ㉗：福缘深厚也加一份
	# v62q（用户终表）：翻财签＝"**每走一节必定可搜刮**"——直接放行，不再走倍率
	var chance := LOOT_NODE_CHANCE
	var lk := 1.0
	if _has_fate("fate_noarmor"):
		lk *= FATE_NOARMOR_MULT
	lk *= 1.0 + _state.talent_loot_bonus()
	# v36：阅历线·财富「眼力」段——搜刮出货率 +N%
	lk *= 1.0 + float(GameState.insight_fx().get("loot_pct", 0.0))
	chance = minf(LOOT_CHANCE_CAP, chance * lk)
	if _has_fate("fate_scavenge"):
		chance = 1.0
	if randf() > chance:
		print("[搜刮] 本节没有产出（概率 ", chance, "）")
		return
	# ============================================================
	# v62p（用户："这个短绳签的爆率指的是假如原红有1%的话 提升就是红1.5% 所以并不高
	#   算了 直接短绳加150% 爆率"）：
	#   ⚠ v62o 我把"爆率"接到了**这一节的出货概率**上 ✗ 那是"有没有东西可搜"，
	#     不是爆率。真正的爆率是**颜色**（红/金/紫的出货率）——所以改接在
	#     `roll_container` 的 `rate_mul` 上：短绳签 **+150%＝×2.5**。
	#   （节点出货概率那条已经撤掉，短绳签不再动它。）
	# ============================================================
	var rate_mul := FATE_SHORTROPE_RATE if _has_fate("fate_shortrope") else 1.0
	for cid_v in Loot.roll_spawn(kind):
		var cid := str(cid_v)
		var items: Array = Loot.roll_container(cid, _loot_luck(), rate_mul)
		items.sort_custom(func(a, b): return int(a.get("red", false)) < int(b.get("red", false)))
		items = _filter_entry_cards(items)   # ㊲：入口卡闸
		_loot_containers.append({"cid": cid, "items": items, "opened": false, "anim_done": false})
	print("[搜刮] 节点产出（", kind, "）：", _loot_containers.size(), " 个容器")

func _clear_loot() -> void:
	_loot_containers.clear()
	_loot_skip_warned = false
	if _loot_row != null and is_instance_valid(_loot_row):
		_loot_row.queue_free()
	_loot_row = null

func _loot_left(c: Dictionary) -> int:
	var arr: Array = c.get("items", [])
	return arr.size()

func _loot_pending() -> int:
	var n := 0
	for c_v in _loot_containers:
		var c: Dictionary = c_v
		n += _loot_left(c)
	return n

func _loot_btn_text(i: int) -> String:
	var c: Dictionary = _loot_containers[i]
	var nm := Loot.container_name(str(c.get("cid", "")))
	var left := _loot_left(c)
	var opened := bool(c.get("opened", false))
	if left <= 0 and opened:
		return nm + " · 空了"
	if opened:
		return nm + " · 剩 " + str(left) + " 件"
	return "搜刮　" + nm

func _show_loot_row() -> void:
	if _loot_row != null and is_instance_valid(_loot_row):
		_loot_row.queue_free()
	_loot_row = null
	var n := _loot_containers.size()
	if n <= 0:
		return
	var bw := 210.0
	var gap := 16.0
	var total := float(n) * bw + float(n - 1) * gap
	_loot_row = Control.new()
	_loot_row.position = Vector2((size.x - total) * 0.5, 958.0)
	_loot_row.size = Vector2(total, 64.0)
	_loot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loot_row)
	for i in n:
		var b := UiKit.make_button(_loot_row, Vector2(float(i) * (bw + gap), 0.0), Vector2(bw, 64.0), _loot_btn_text(i), 18)
		b.pressed.connect(_open_loot.bind(i))

func _refresh_loot_row() -> void:
	if _loot_row == null or not is_instance_valid(_loot_row):
		return
	var kids := _loot_row.get_children()
	for i in mini(kids.size(), _loot_containers.size()):
		if kids[i] is Button:
			UiKit.set_btn_text(kids[i], _loot_btn_text(i))

func _open_loot(i: int) -> void:
	if _state == null or _loot_panel_open or _busy:
		return
	if i < 0 or i >= _loot_containers.size():
		return
	var c: Dictionary = _loot_containers[i]
	if _loot_left(c) <= 0:
		# 优化批⑥（#10）：空壳——翻开也要有个交代（点一次告知，之后按钮显示"空了"）
		if not bool(c.get("opened", false)):
			c["opened"] = true
			_state.alert_gain(RunState.ALERT_OPEN)
			_refresh_alert()
			_refresh_loot_row()
			UiKit.float_text(self, Loot.container_name(str(c.get("cid", ""))) + "是空的——什么都没有", UiKit.DIM)
			print("[搜刮] 开空：", str(c.get("cid", "")))
		return
	if not bool(c.get("opened", false)):
		c["opened"] = true
		_state.alert_gain(RunState.ALERT_OPEN)
		# v62q（用户终表）：翻财签的代价**搬家了**——从"每开一个容器 -12% 上限"
		#   改成"**每取走一种物品，当前气血 -3%**"，落在 loot_panel._take 那里
		#   （粒度按物品、只扣当前气血、不动上限）。这里不再扣。
		_refresh_alert()
	_loot_panel_open = true
	var panel := LootPanel.new()
	_loot_panel_ref = panel
	add_child(panel)
	panel.setup(self, _state, c, _loot_speed())
	panel.closed.connect(_on_loot_closed)

func _on_loot_closed() -> void:
	_loot_panel_open = false
	_loot_panel_ref = null
	_refresh_loot_row()
	_refresh_alert()
	JourneySave.save_run(self)   # ④b：安全点——搜刮关板
	if not _loot_containers.is_empty() and _loot_pending() <= 0 and _loot_all_opened():
		UiKit.float_text(self, "都翻干净了——点画面接着赶路", UiKit.GREEN)

# 优化批⑥（#10）：空壳没翻开过就不算"都翻干净"
func _loot_all_opened() -> bool:
	for c_v in _loot_containers:
		var c: Dictionary = c_v
		if not bool(c.get("opened", false)):
			return false
	return true

func _loot_leave_tap() -> void:
	if _loot_pending() > 0:
		_ask_leave_loot()
		return
	_advance()

# 优化批⑤（#7）：没搜完就赶路 → 居中问一句，别让玩家以为"拿不完走不了"
func _ask_leave_loot() -> void:
	_close_popup()
	var veil := _make_popup_veil(true)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := UiKit.make_paper_panel(veil, Rect2(120, POPUP_TOP, 480, 236))
	var t1 := UiKit.make_label(panel, Vector2(0, 22), Vector2(480, 34), 24, UiKit.INK)
	UiKit.set_text(t1, "还有 " + str(_loot_pending()) + " 件没拿")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := UiKit.make_label(panel, Vector2(40, 66), Vector2(400, 64), 16, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
	UiKit.set_text(t2, "放弃剩余物资，继续前进？\n（留下的就抛在身后了）")
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var go := UiKit.make_button(panel, Vector2(46, 152), Vector2(180, 54), "放弃，继续走", 18)
	go.pressed.connect(_confirm_leave_loot)
	var stay := UiKit.make_button(panel, Vector2(254, 152), Vector2(180, 54), "再搜一会儿", 18)
	stay.pressed.connect(_close_popup)

func _confirm_leave_loot() -> void:
	print("[游历] 放弃剩余搜刮，继续赶路：剩 ", _loot_pending(), " 件")
	_close_popup()
	_advance()

# ---- ㉙b：命数抉择（特殊事件；横财/翻财/血路） ----

# ㉛b：命数已解锁？——"经历到第 FATE_UNLOCK_DIFF 档"：该档已开（前几档走完）
func _fate_unlocked() -> bool:
	return GameState.diff_state(FATE_UNLOCK_DIFF) != "locked"

func _has_fate(id: String) -> bool:
	return _state != null and _state.buffs.has(id)

func _money_gain(g: int) -> int:
	# v36（用户："文钱收益提升20%"）：**全局文钱收益 ×1.2**。
	#   游历里"打赢给的钱"只有这一口（战斗与遭遇战两处调用），所以改这一处就够；
	#   卖卡/折现那些"卖东西换钱"不走这里（那不是收益）。
	#   ⚠ 与开局行装"文钱"那张的 +20% **相乘**（都拿 ＝ ×1.44）——要只留一份就把这张表调成 1.0。
	var k := MONEY_MUL
	if _has_fate("fate_greed"):
		k *= FATE_GREED_MONEY
	if _has_fate("fate_fullbag"):
		k *= FATE_FULLBAG_MONEY
	# v35：开局行装选了"文钱"那一张 → 本趟文钱收益 +20%（与命数那两张相乘，互不顶替）
	if _state != null and _state.kit_money_pct > 0.0:
		k *= 1.0 + float(_state.kit_money_pct)
	# v36：阅历线·财富「财路」段——本趟文钱收益 +N%（同样相乘）
	if _state != null:
		k *= 1.0 + float(GameState.insight_fx().get("money_pct", 0.0))
	return maxi(1, int(round(float(g) * k)))

func _open_fate(node: Dictionary) -> void:
	if _busy or _loot_panel_open:
		return
	# ㉛：出征屏已选过同一张命数——这回不重复摆摊，直接过
	if _has_fate("fate_" + str(node.get("fid", ""))):
		UiKit.float_text(self, "这桩命数你已经接过了——照旧赶路", UiKit.DIM)
		_advance()
		return
	_close_popup()
	var veil := _make_popup_veil(true)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := UiKit.make_paper_panel(veil, Rect2(90, POPUP_TOP, 540, 308))
	var t1 := UiKit.make_label(panel, Vector2(0, 20), Vector2(540, 36), 26, UiKit.INK)
	UiKit.set_text(t1, "命数 · " + str(node.get("title", "抉择")))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := UiKit.make_label(panel, Vector2(36, 64), Vector2(468, 96), 17, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.88))
	UiKit.set_text(t2, str(node.get("text", "")))
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var t3 := UiKit.make_label(panel, Vector2(36, 164), Vector2(468, 60), 16, UiKit.SEAL)
	UiKit.set_text(t3, str(node.get("pick", "")))
	t3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var go := UiKit.make_button(panel, Vector2(40, 232), Vector2(212, 56), "接这注", 19)
	go.pressed.connect(_on_fate_pick.bind(str(node.get("fid", ""))))
	var no := UiKit.make_button(panel, Vector2(288, 232), Vector2(212, 56), "不收这注", 19)
	no.pressed.connect(_on_fate_decline)

func _on_fate_pick(fid: String) -> void:
	_close_popup()
	_apply_fate(fid)
	_advance()

func _on_fate_decline() -> void:
	_close_popup()
	UiKit.float_text(self, "你绕开了这桩事", UiKit.DIM)
	_advance()

func _apply_fate(fid: String) -> void:
	var bid := "fate_" + fid
	if _has_fate(bid):
		return
	match fid:
		"greed":
			_state.buffs.append("fate_greed")
			UiKit.float_text(self, "横财入袋——出手软一点，钱厚一点", UiKit.GOLD)
		"scavenge":
			_state.buffs.append("fate_scavenge")
			UiKit.float_text(self, "见财起意——翻找更多，破皮难免", UiKit.GOLD)
		"shortrope":
			_state.buffs.append("fate_shortrope")
			UiKit.float_text(self, "短绳在手——每过一节警戒更紧，钱多一点", UiKit.GOLD)
		"fullbag":
			_state.buffs.append("fate_fullbag")
			UiKit.float_text(self, "满囊在手——包裹多两格，落袋薄一成", UiKit.GOLD)
		"noarmor":
			_state.buffs.append("fate_noarmor")
			UiKit.float_text(self, "舍装在身——护甲封着，翻找更快", UiKit.GOLD)
		"endure":
			# ㊿：续命签——纯 fx（每 3 手回 4% 气血 / 气血上限 -10%），这里只管入袋
			_state.buffs.append("fate_endure")
			UiKit.float_text(self, "续命在手——气回得慢，命薄一分", UiKit.GOLD)
		"sharpen":
			# ㊿：锐意签——纯 fx（攻击 +20% / 气血上限 -12%）
			_state.buffs.append("fate_sharpen")
			UiKit.float_text(self, "锐意在身——刀口更快，身板更薄", UiKit.SEAL)
		"bloodpath":
			_state.buffs.append("fate_bloodpath")
			var roads: Array = JourneyData.EXTRA_ROADS.duplicate(true)
			for i in roads.size():
				_nodes.insert(_node + 1 + i, roads[i])
			UiKit.float_text(self, "转上近道——前方多出 " + str(roads.size()) + " 节险路", UiKit.SEAL)
		_:
			# v62k：新加的命数（血勇/铁衣/孤注/饮鸩…）都是**纯 fx**，没有额外机制——
			#   走这条通用路：表里有"fate_<fid>"就照着卡面生效。以后再加签也不用改这里。
			var nf := "fate_" + fid
			if Buffs.of(nf).is_empty():
				return
			_state.buffs.append(nf)
			UiKit.float_text(self, Buffs.name_of(nf) + " 已入手", UiKit.GOLD)
	_refresh_buff_btn()

# ---- ㊿：路边签摊（增益节点）——三签选一，白拿一张进卡组 ----

func _open_gain(node: Dictionary) -> void:
	if _busy or _loot_panel_open:
		return
	_close_popup()
	var offers := _gain_offers()
	if offers.is_empty():
		UiKit.float_text(self, "签摊没备下货——先赶路", UiKit.DIM)
		_advance()
		return
	var veil := _make_popup_veil(true)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	# ㊿：与精英三选一同一个毛病：按钮里的长描述不换行、直接冲出窗口。
	#   改成"每行一个面板 + 会换行的说明"（行高按描述长短算）。
	var rows: Array = []
	for i in offers.size():
		var bid := str(offers[i])
		rows.append({
			"title": Buffs.title_of(bid),   # ㊿：专属会带上"谁的专用"
			"sub": Buffs.desc_of(bid),
			"id": bid,
		})
	var heights: Array = []
	var total := 0.0
	for r_v in rows:
		var h := _elite_row_h(r_v)
		heights.append(h)
		total += h + 10.0
	var panel := UiKit.make_paper_panel(veil, Rect2(70, POPUP_TOP, 580, 124.0 + total + 62.0))
	var t1 := UiKit.make_label(panel, Vector2(0, 18), Vector2(580, 36), 26, UiKit.INK)
	UiKit.set_text(t1, "签摊 · 三签选一")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# v54：15 → 19（框高 52 → 62；这一页的 ry 从 124 起，行高另由 _elite_row_h 撑开）
	var t2 := UiKit.make_label(panel, Vector2(36, 58), Vector2(508, 62), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.80))
	UiKit.set_text(t2, str(node.get("text", "")) + "\n（白拿一张，只在这趟里生效）")
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ry := 124.0
	for i in rows.size():
		_elite_row(panel, i, rows[i], ry, float(heights[i]), str((rows[i] as Dictionary).get("id", "")))
		ry += float(heights[i]) + 10.0
	var sk := UiKit.make_button(panel, Vector2(185, ry + 4.0), Vector2(210, 50), "不接，赶路", 19)
	sk.pressed.connect(_advance)

func _gain_offers() -> Array:
	# ㊿u：池子按"这趟在阵的这几个人"筛——主人没来，他的专属卡不摆
	var pool: Array = Buffs.pool_for_role(str(_state.role_id), _state.party_role_ids())
	if pool.is_empty():
		return []
	var out: Array = []
	var guard := 0
	while out.size() < 3 and guard < 60:
		guard += 1
		var bid := str(pool[randi() % pool.size()])
		if out.has(bid):
			continue
		# ㊾：专属卡——拿过的不再摆（数量限制，留着）
		if str(Buffs.of(bid).get("kind", "")) == "exclusive" and _state.buffs.has(bid):
			continue
		# ㊿：封顶的卡也不再摆（回气卡第 2 张之类：请了也不再更强）
		if Buffs.cap_hint(bid, _buff_owned_in_run(bid)) != "":
			continue
		out.append(bid)
	return out

# ㊿：这趟手里这张有几张（卡组面板里那份 _owned 的同类；给签摊挑货用）
func _buff_owned_in_run(bid: String) -> int:
	var n := 0
	for id_v in _state.buffs:
		if str(id_v) == bid:
			n += 1
	return n

func _on_gain_pick(bid: String) -> void:
	_state.buffs.append(bid)
	_refresh_buff_btn()
	UiKit.float_text(self, "抽到签：「" + Buffs.title_of(bid) + "」——" + Buffs.desc_of(bid), UiKit.GOLD)
	_advance()

# ============ v35：开局行装 · 五选一（进游历第一节摆一次） ============
# 用户："进入游历第一节 根据当前难度 给予五个选项 装备 披风 玉佩 功法 初始文钱翻倍且文钱收益增加+20%
#   【此选项不消耗文钱 且带出去才能真正带出去 死亡带不走】"
#   · 五张牌＝**护甲 / 玉佩 / 披风 / 功法 / 文钱**，五选一（跟事件三选一同一个手感：点整行即拿）。
#   · 品阶＝data_ladder.q_of_diff(当前难度)——**8 关一档**那把尺子
#     （1~8 凡品 · 9~16 良品 · 17~24 上品 · 25~32 极品 · 33+ 绝品），与掉落表同源；
#     装备没有绝品 → 往上没货就往下借一件（Ladder.pick_of_q 里办）。
#   · **给的是成品**（用户："【给的完整】"），不是残卡。
#   · 白拿，不消耗文钱；拿到的件照旧"活着走出游历才算你的"——
#     结算才入村仓库（journey_settle._deposit_run_items），殒命全丢（open_death），
#     所以这里**不盖 village 章**、也不写村账。
#   · 领过就记 kit_taken（随续行档走）：摆出这一页先记上再落盘，强杀重进不会重复领。
func _open_start_kit() -> void:
	if _state == null or _busy:
		return
	var offers := _kit_make_offers()
	_state.kit_taken = true     # 摆过就算领过——防"退出重进再白拿一件"
	JourneySave.save_run(self)
	if offers.is_empty():
		return
	_busy = true                # 这一页是阻塞页：不点完不给赶路
	_kit_offers = offers
	_close_overlay()
	var veil := _make_popup_veil(true)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var row_h := 92.0
	var ph := 156.0 + float(offers.size()) * (row_h + 8.0)
	var panel := UiKit.make_paper_panel(veil, Rect2(58, POPUP_TOP, 604, ph))
	var t1 := UiKit.make_label(panel, Vector2(0, 16), Vector2(604, 38), 28, UiKit.INK)
	UiKit.set_text(t1, "开局行装 · 五选一")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var q: int = Ladder.q_of_diff(int(_state.diff))
	var qn := str(Cards.QUALITY_ORDER[clampi(q, 0, Cards.QUALITY_ORDER.size() - 1)])
	var t2 := UiKit.make_label(panel, Vector2(22, 56), Vector2(560, 56), 17,
		Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	UiKit.set_text(t2, "难度 " + str(_state.diff) + " · 本档给的是「" + qn
		+ "」成品——挑一样带走，白拿。路上捡的、这里拿的，都得活着走出游历才算你的。")
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ry := 122.0
	for i in offers.size():
		_kit_row(panel, i, offers[i], ry, row_h)
		ry += row_h + 8.0
	print("[游历] 开局行装：摆出 ", offers.size(), " 张（难度 ", _state.diff, " · 品阶 ", qn, "）")

func _kit_row(panel: Control, i: int, o: Dictionary, y: float, h: float) -> void:
	var row := Panel.new()
	row.position = Vector2(24, y)
	row.size = Vector2(556, h)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.86, 1.0)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.45)
	sb.set_border_width_all(2)
	row.add_theme_stylebox_override("panel", sb)
	row.gui_input.connect(_on_kit_row_input.bind(i))
	panel.add_child(row)
	var ttl := UiKit.make_label(row, Vector2(16, 8), Vector2(524, 32), 21, UiKit.INK)
	UiKit.set_text(ttl, str(o.get("title", "?")))
	var ds := UiKit.make_label(row, Vector2(16, 42), Vector2(524, h - 50.0), 17,
		Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.82))
	UiKit.set_text(ds, str(o.get("sub", "")))
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _on_kit_row_input(ev: InputEvent, i: int) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_on_kit_pick(i)

# 一件成品是哪一品（"凡品/良品/…"）——标题照真实的那一件写，别照难度档写
func _q_cn(sid: String) -> String:
	var qi: int = clampi(Cards.q_idx(sid), 0, Cards.QUALITY_ORDER.size() - 1)
	return str(Cards.QUALITY_ORDER[qi])

# 五张牌的内容——摆出来的那一刻就摇定
func _kit_make_offers() -> Array:
	var q: int = Ladder.q_of_diff(int(_state.diff))
	var qn := str(Cards.QUALITY_ORDER[clampi(q, 0, Cards.QUALITY_ORDER.size() - 1)])
	var out: Array = []
	var slots := [["armor", "护甲"], ["helm", "玉佩"], ["cloak", "披风"]]
	for s_v in slots:
		var pool := str(s_v[0])
		var cn := str(s_v[1])
		var sid := Ladder.pick_of_q(pool, q)
		if sid == "":
			continue
		out.append({
			"kind": "gear", "slot": pool, "sid": sid,
			# ⚠ 品阶照**这件真实**的写：绝品难度下装备没有绝品、会往下借到极品——
			#   写 qn 的话会把极品标成"绝品"（探针当场抓到的）。
			"title": cn + " · " + str(Cards.item_name(sid)) + "（" + _q_cn(sid) + "）",
			"sub": str(Cards.bonus_text(Cards.item_bonus(sid))) + "（装备格＝" + cn + "）——拿了放包裹里，自己穿",
		})
	var asid := Ladder.pick_of_q("arts", q)
	if asid != "":
		out.append({
			"kind": "arts", "sid": asid,
			"title": "功法 · " + str(Cards.item_name(asid)) + "（" + _q_cn(asid) + "）",
			"sub": str(Cards.art_of(asid).get("desc", "—")) + "——拿了放包裹里，自己装",
		})
	out.append({
		"kind": "money",
		"title": "文钱 · 盘缠翻倍（" + str(_state.money) + " → " + str(int(_state.money) * 2) + " 文）",
		# ⚠ 界面是纯 Label（不吃 ** 加粗），文案里别写 markdown
		"sub": "本趟文钱收益 +" + str(int(KIT_MONEY_PCT * 100.0)) + "%；这一样不花文钱。盘缠出局清零，只顶这一趟。",
	})
	return out

# v35b（用户："装备和功法进包裹就行了"）：这一张的**落点**抽成纯逻辑（不碰 UI、不落盘），
#   _on_kit_pick 只负责"发奖 → 收摊 → 落盘"这三步。探针可以直接调这一口验"进没进包裹"。
func _kit_grant(o: Dictionary) -> String:
	if str(o.get("kind", "")) == "money":
		var before: int = int(_state.money)
		_state.money = before * 2
		_state.kit_money_pct = KIT_MONEY_PCT
		return "盘缠翻倍：" + str(before) + " → " + str(_state.money) + " 文　本趟文钱收益 +" + str(int(KIT_MONEY_PCT * 100.0)) + "%"
	var sid := str(o.get("sid", ""))
	# 用户："装备和功法进包裹就行了"——**不自动上身**：放进包裹，由玩家自己决定给谁穿。
	if _state.add_item(sid):
		return str(Cards.item_name(sid)) + " 已放进包裹（到包裹里自己穿）"
	# 兜底（开局包裹基本不可能是满的）：真满了就直接给领队穿上，绝不把这一件弄丢
	return "包裹满了——先给领队穿上：" + _state.place_item_for(0, sid, "equip")

func _on_kit_pick(i: int) -> void:
	if i < 0 or i >= _kit_offers.size():
		return
	var o: Dictionary = _kit_offers[i]
	var msg := _kit_grant(o)
	_close_popup()
	_kit_offers = []
	_busy = false
	_money()
	_refresh_all()
	JourneySave.save_run(self)   # 领了立刻落盘：强杀重进既不重复领、也不落空
	UiKit.float_text(self, msg, UiKit.GOLD)
	print("[游历] 开局行装：", str(o.get("title", "")), " → ", msg)

# 优化批⑩（#15）：退出游历——居中确认页；退出＝放弃本趟（同败走：东西全丢、不记档）
# ㊿：可接的命数＝八张。前六张靠 journey 这边的 flag 生效（搜刮/文钱/护甲），
#   后两张（续命/锐意）纯靠 fx —— 它们照样要在这张名单里，否则面板/路event 接不上。
const FATE_SIGN_IDS := ["greed", "scavenge", "bloodpath", "shortrope", "fullbag", "noarmor", "endure", "sharpen",
	"iron", "allin", "venom"]   # v62o：血勇签已删

func take_fate_sign(fid: String) -> Dictionary:
	if _state == null or _phase != "journey":
		return {"ok": false, "msg": "还没上路"}
	if _busy or _encounter_running or _loot_panel_open:
		return {"ok": false, "msg": "先把手头的事办完"}
	if not FATE_SIGN_IDS.has(fid):
		return {"ok": false, "msg": "没有这一桩命数"}
	if _has_fate("fate_" + fid):
		return {"ok": false, "msg": "这一桩本趟已经接过了——不再出现"}
	_apply_fate(fid)
	JourneySave.save_run(self)
	return {"ok": true, "msg": ""}

# 优化批⑩（#15）：退出游历——居中确认页；退出＝放弃本趟（同败走：东西全丢、不记档）
func _ask_quit_journey() -> void:
	if _phase != "journey":
		return
	if _busy or _encounter_running or _loot_panel_open:
		UiKit.float_text(self, "先把手头的事办完", UiKit.SEAL)
		return
	_close_popup()
	var veil := _make_popup_veil(true)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := UiKit.make_paper_panel(veil, Rect2(110, POPUP_TOP, 500, 268))
	var t1 := UiKit.make_label(panel, Vector2(0, 22), Vector2(500, 36), 26, UiKit.INK)
	UiKit.set_text(t1, "退出游历？")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := UiKit.make_label(panel, Vector2(36, 68), Vector2(428, 92), 16, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
	UiKit.set_text(t2, "现在退出＝放弃这一趟：\n包裹与临时仓库里的东西都带不走，难度也不记档。\n（想留东西，就活着走到结算）")
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var go := UiKit.make_button(panel, Vector2(46, 184), Vector2(190, 56), "放弃，回村", 19)
	go.pressed.connect(_confirm_quit_journey)
	var stay := UiKit.make_button(panel, Vector2(264, 184), Vector2(190, 56), "继续赶路", 19)
	stay.pressed.connect(_close_popup)

func _confirm_quit_journey() -> void:
	print("[游历] 主动退出：第 ", _node + 1, " / ", _nodes.size(), " 节")
	_run_dead = true
	JourneySave.erase()
	_clear_loot()
	_close_overlay()
	GameState.pending_note = _restore_strip("半路折返——这一趟的东西都没能带回来")
	var err := get_tree().change_scene_to_file(MENU_SCENE)
	if err != OK:
		print("[游历] 回村失败，错误码=", err, "；检查路径：", MENU_SCENE)
		UiKit.float_text(self, "回村失败：看看控制台", UiKit.SEAL)

# ---- R3 遭遇战（子批②）：警戒拉满 → 关面板 → 敌先手开打 ----

func _make_encounter_node() -> Dictionary:
	# 三级敌源：本节点敌 → 最近敌阵容 → 本档默认敌组（引子趟 diff=0 按第 1 档）
	if _cur_node.has("foe"):
		print("[遭遇] 敌源=本节点：", str(_cur_node.get("name", "")))
		return _cur_node
	if not _state.last_foe.is_empty():
		print("[遭遇] 敌源=最近敌阵容：", str(_state.last_foe.get("name", "")))
		return _state.last_foe
	print("[遭遇] 敌源=本档默认：第 ", maxi(1, int(_state.diff)), " 档")
	return JourneyData.encounter_node(int(_state.diff))

# 优化批⑥（#9）：居中大字红字提醒（遭遇开场用；约 1.5 秒后淡出）
func _warn_banner(t: String) -> void:
	var lb := UiKit.make_label(self, Vector2(0, 540), Vector2(720, 96), 46, Color(0.80, 0.10, 0.08))
	UiKit.set_text(lb, t)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.z_index = 50
	add_child(lb)
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(lb, "modulate:a", 0.0, 0.45)
	tw.tween_callback(lb.queue_free)

func _start_encounter() -> void:
	_encounter_running = true
	_encounter_pending = false
	print("[遭遇] 警戒拉满，触发遭遇战（敌先手）")
	# 强关搜刮面板：已揭晓/未拿的都留在容器里，之后可接着搜
	if _loot_panel_open and _loot_panel_ref != null and is_instance_valid(_loot_panel_ref):
		_loot_panel_ref._close()
	_loot_panel_open = false
	_loot_panel_ref = null
	_close_overlay()
	_busy = true
	_warn_banner("警戒已满 · 你被敌人偷袭！")
	await get_tree().create_timer(1.4).timeout
	_set_battle_hud(true)
	var battle := DuelBattle.new()
	add_child(battle)
	var enode := _make_encounter_node()
	var res: Dictionary = await battle.run(_state, _walker, _fx, enode, true, _companions)
	if is_instance_valid(battle):
		battle.queue_free()
	# R4（Q1=b）：遭遇败北同样＝殒命
	var won := bool(res.get("won", false))
	var gain := int(res.get("gain", 0))
	if won:
		_state.money += _money_gain(gain)
	_refresh_all()
	if won:
		UiKit.float_text(self, "击退来敌，收下 " + str(_money_gain(gain)) + " 文", UiKit.GOLD)
	else:
		UiKit.float_text(self, "你倒下了……", UiKit.SEAL)
	_set_battle_hud(false)
	var back := create_tween()
	back.tween_property(_walker, "position", _walk_home, 0.4)
	_retreat_companions(back)
	await back.finished
	_encounter_running = false
	_busy = false
	if not won:
		_open_settle_death()
		return
	_state.alert_reset()
	_alert_w60 = false
	_alert_w85 = false
	_refresh_alert()
	if _loot_pending() > 0:
		UiKit.float_text(self, "尘头落了——还能接着搜", UiKit.INK)

# ============ ㊿e：精英战利·三选一×3（增益卡 → 武学 → 装备·兵器） ============
# 改版（㊿e）：连着三轮三选一——每轮摆三个候选挑一个；不想要就点［跳过］放空这一轮。
#   第 1 轮 增益卡（进卡组：本趟生效、带不出去）→ 第 2 轮 武学残页 → 第 3 轮 装备·兵器残卡。
#   ⚠ v34（用户报的②）：后两轮的落点**只有包裹**——以前是"包裹装不下就退临时仓库，
#     临时仓库也满就直接 append（越过上限）"，于是精英战利能把临时仓库撑爆、
#     还绕开了"包裹满＝要取舍"这条设计。现在满包只给两条路：
#     · 替换：点右上角包裹里的东西丢掉（换回它的卖价＝盘缠），这一件收下；
#     · 折现：这一件按折现价（cashout_price）换盘缠，不要了。
#     照抄事件三选一那套（journey_event_flow 的"满包：替换/折现"），口径完全一致。

func _open_elite_draw() -> void:
	if _state == null:
		return
	_elite_round = 1
	_elite_pending = {}
	_show_elite_round()

# ㊿e：摆一轮三选一；三轮走完＝收摊（照旧去摆搜刮）
#   keep_offers=true：用手上这一轮已经摆出来的候选重画（"满包→返回"走它，不重摇）
func _show_elite_round(keep_offers := false) -> void:
	# v34：走 _close_overlay 而不是 _close_popup——"满包"那一页是 overlay（遮罩型），
	#   这里必须连它一起收掉，不然它会盖在下一轮候选上面（页越叠越多）。
	_close_overlay()
	if _elite_round > 3:
		_elite_draw_done()
		return
	if not keep_offers:
		_elite_offers = _elite_offer_make(_elite_round)
	if _elite_offers.is_empty():
		UiKit.float_text(self, "这一样没备下货——先过", UiKit.SEAL)
		_elite_round += 1
		_show_elite_round()
		return
	print("[战利] 三选一第 ", _elite_round, " 轮：摆出 ", _elite_offers.size(), " 个候选")
	var veil := _make_popup_veil(true)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	# ㊿：**行高按描述长短算**，面板跟着长高。
	#   原来三行都写死 64 高、用按钮装"标题＋效果"——而**按钮里的文字不换行**，
	#   回气卡那种长描述直接画到窗口外面去了（后半句看不见）。
	#   现在每行＝面板＋会自动换行的说明，点整行即选中。
	var heights: Array = []
	var total := 0.0
	for i in _elite_offers.size():
		var h := _elite_row_h(_elite_offers[i])
		heights.append(h)
		total += h + 10.0
	var panel := UiKit.make_paper_panel(veil, Rect2(70, POPUP_TOP, 580, 124.0 + total + 58.0))
	var t1 := UiKit.make_label(panel, Vector2(0, 18), Vector2(580, 36), 26, UiKit.INK)
	UiKit.set_text(t1, "战利 · 三选一（" + str(_elite_round) + " / 3）")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := UiKit.make_label(panel, Vector2(30, 58), Vector2(520, 56), 15, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	UiKit.set_text(t2, _elite_round_tip())
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ry := 124.0
	for i in _elite_offers.size():
		_elite_row(panel, i, _elite_offers[i], ry, float(heights[i]))
		ry += float(heights[i]) + 10.0
	var sk := UiKit.make_button(panel, Vector2(110, ry + 4.0), Vector2(170, 44), "都不要，跳过", 15)
	sk.pressed.connect(_on_elite_skip)
	# v62k（用户："精英关的三抽 可以刷新一次 每次选项"）：每轮**一次**重摇。
	#   ⚠ 用按钮而不是"关掉再开"：关掉再开会走 keep_offers=true 那条（候选不重摇），
	#     玩家没法自己刷；这里给一个明面上的、每轮限一次的刷新口。
	var used := _elite_reroll_round == _elite_round
	var rf := UiKit.make_button(panel, Vector2(300, ry + 4.0), Vector2(170, 44),
		("本轮已刷新" if used else "刷新（本轮 1 次）"), 15)
	rf.pressed.connect(_on_elite_reroll)

# ㊿：一行要多高——14 号字、492 宽大约每行 34 个汉字
func _elite_row_h(offer: Dictionary) -> float:
	var n := str(offer.get("sub", "")).length()
	# v54：字号放大之后这一行也得跟着长——说明 14 → 18（一行约 27 字）、行高 21 → 25，
	#   标题占的那一段 46 → 54（标题自己也从 17 涨到 20）。
	var lines := maxi(1, int(ceil(float(n) / 27.0)))
	return 54.0 + float(lines) * 25.0

# ㊿：三选一的一行＝面板＋标题＋**会换行**的说明；点整行即选中。
#   pick_id 给了就走签摊那条口（_on_gain_pick），没给就是精英三选一（_on_elite_pick）。
func _elite_row(panel: Control, i: int, offer: Dictionary, y: float, h: float, pick_id := "") -> void:
	var row := Panel.new()
	row.position = Vector2(30, y)
	row.size = Vector2(520, h)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.86, 1.0)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.45)
	sb.set_border_width_all(2)
	row.add_theme_stylebox_override("panel", sb)
	if pick_id == "":
		row.gui_input.connect(_on_elite_row_input.bind(i))
	else:
		row.gui_input.connect(_on_gain_row_input.bind(pick_id))
	panel.add_child(row)
	# v54（玩家反馈："选卡字体还是太小了"）：行标题 17 → 20、说明 14 → 18
	var ttl := UiKit.make_label(row, Vector2(14, 8), Vector2(492, 30), 20, UiKit.INK)
	UiKit.set_text(ttl, str(offer.get("title", "?")))
	var ds := UiKit.make_label(row, Vector2(14, 42), Vector2(492, h - 52.0), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.82))
	UiKit.set_text(ds, str(offer.get("sub", "")))
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _on_elite_row_input(ev: InputEvent, i: int) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_on_elite_pick(i)

func _on_gain_row_input(ev: InputEvent, bid: String) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_on_gain_pick(bid)

# ㊿e：本轮的一句话
func _elite_round_tip() -> String:
	if _elite_round == 1:
		return "精英毙命——先挑一张增益卡。\n（进卡组：只本趟生效、带不出去；普通/特殊对全队，专属只对卡上那个人、同一张每趟限一次）"
	if _elite_round == 2:
		return "再挑一张武学残页。\n（进包裹——和路上捡的一样：趟内能用、结算带走；包裹满就先替一件出来、或把这张折现）"
	return "最后挑一件装备·兵器残卡。\n（进包裹 · 护甲／玉佩／披风／兵器混着出；包裹满同样是「替换 or 折现」）"

# ㊿e：选中本轮的一件——增益即刻入账；残卡/残页只有**包裹**一条路
# （v34：满包改"替换 / 折现"，不再往临时仓库塞、更不越过上限）
func _on_elite_pick(i: int) -> void:
	if _elite_lock:
		return
	_elite_lock = true
	call_deferred("_elite_unlock")
	if i < 0 or i >= _elite_offers.size():
		return
	var offer: Dictionary = _elite_offers[i]
	print("[战利] 三选一第 ", _elite_round, " 轮：选了 ", str(offer.get("name", "?")), "（", str(offer.get("kind", "")), "）")
	if str(offer.get("kind", "")) == "buff":
		_state.buffs.append(str(offer.get("id", "")))
		UiKit.float_text(self, "摸到『" + str(offer.get("name", "?")) + "』——已收入卡组（本趟生效）", UiKit.GOLD)
		_refresh_all()
		_elite_round += 1
		_show_elite_round()
		return
	# v34：满包＝先问"替一件还是折现"，这一轮**先不往前走**——答完才续下一轮
	if _state.bag_full():
		_elite_enter_full(offer.get("entry", {}), str(offer.get("name", "?")))
		return
	_elite_draw_give(offer.get("entry", {}))
	UiKit.float_text(self, "摸到：" + str(offer.get("name", "?")), UiKit.GOLD)
	_refresh_all()
	_elite_round += 1
	_show_elite_round()

# ㊿e：这一轮都不要——看下一样
func _on_elite_skip() -> void:
	if _elite_lock:
		return
	_elite_lock = true
	call_deferred("_elite_unlock")
	print("[战利] 三选一第 ", _elite_round, " 轮：跳过")
	_elite_round += 1
	_show_elite_round()

# v62k（用户："精英关的三抽 可以刷新一次 每次选项"）：把**本轮**的候选重摇一遍。
#   · 每轮限一次（_elite_reroll_round 记住刷过哪一轮；进下一轮自然就又能刷）
#   · 重摇走 _show_elite_round()（keep_offers 默认 false）——与"跳过"同一条重画路
#   · 不影响轮次：刷完还是这一轮，选完才进下一轮
func _on_elite_reroll() -> void:
	if _elite_lock:
		return
	if _elite_reroll_round == _elite_round:
		UiKit.float_text(self, "这一轮已经刷新过了——下一轮还能再刷一次", UiKit.SEAL)
		return
	_elite_reroll_round = _elite_round
	_elite_lock = true
	call_deferred("_elite_unlock")
	print("[战利] 三选一第 ", _elite_round, " 轮：刷新候选")
	UiKit.float_text(self, "重摇一次（第 " + str(_elite_round) + " 轮）", UiKit.GOLD)
	_show_elite_round()

func _elite_unlock() -> void:
	_elite_lock = false

# ㊿e：本轮候选——1 增益卡（三张不同）/ 2 武学（残页）/ 3 装备·兵器（混着出）
func _elite_offer_make(round_i: int) -> Array:
	if round_i == 1:
		return _elite_buff_offers()
	if round_i == 2:
		return _elite_card_offers("arts")
	return _elite_card_offers("gear")

# ㊿e：增益候选——复用老骰子（_elite_buff_pick），去重摆最多三张
func _elite_buff_offers() -> Array:
	var out: Array = []
	var guard := 0
	while out.size() < 3 and guard < 40:
		guard += 1
		var bid := _elite_buff_pick()
		if bid == "":
			break
		if out.has(bid):
			continue
		out.append({
			"kind": "buff",
			"id": bid,
			"name": Buffs.name_of(bid),
			"title": Buffs.title_of(bid),   # ㊿：专属卡带上"谁的专用"
			"sub": Buffs.desc_of(bid),
		})
	return out

# ㊿e：残卡候选——复用老骰子（_elite_draw_roll：入口卡闸/兵器装备混池照旧），按套去重摆最多三张
func _elite_card_offers(cat: String) -> Array:
	var out: Array = []
	var guard := 0
	while out.size() < 3 and guard < 60:
		guard += 1
		var e := _elite_draw_roll(cat)
		if e.is_empty():
			break
		var sid := str(e.get("set", e.get("id", "")))
		if sid == "" or _elite_offer_has(out, sid):
			continue
		var pool := str(Cards.by_id(sid).get("pool", ""))
		var slot_cn := str(GameState.SLOT_CN.get(pool, pool))
		out.append({
			"kind": "card",
			"sid": sid,
			"name": str(e.get("name", "?")),
			"title": str(e.get("name", "?")),
			"sub": slot_cn + " · " + str(GameState.grade_of(sid)),
			"entry": e,
		})
	return out

func _elite_offer_has(out: Array, sid: String) -> bool:
	for o_v in out:
		var o: Dictionary = o_v
		if str(o.get("sid", "")) == sid:
			return true
	return false

# 增益抽——普通/特殊可重复拿；专属同一张每趟只出一次（拿过的剔掉）
# （pool_for_role 自带过滤：命数不进池、㊿u 主人不在阵就不出；请得到就只对本人生效）
func _elite_buff_pick() -> String:
	var cand: Array = []
	for id_v in Buffs.pool_for_role(str(_state.role_id), _state.party_role_ids()):
		var bid := str(id_v)
		if str(Buffs.of(bid).get("kind", "")) == "exclusive" and _state.buffs.has(bid):
			continue
		# ㊿：封顶的也不再抽（回气卡第 2 张之类：拿了也不再更强）
		if Buffs.cap_hint(bid, _buff_owned_in_run(bid)) != "":
			continue
		cand.append(bid)
	if cand.is_empty():
		return ""
	return str(cand[randi() % cand.size()])

func _elite_draw_roll(cat: String) -> Dictionary:
	if cat == "arts":
		var ap: Array = GameState.pick_pool("arts")
		if ap.is_empty():
			return {}
		var asid := str(ap[randi() % ap.size()])
		return Loot.make_draw_entry("card", asid, _entry_gate(asid))
	if randf() < 0.5:
		var wp: Array = GameState.pick_pool("weapon")
		if wp.is_empty():
			return {}
		var wsid := str(wp[randi() % wp.size()])
		return Loot.make_draw_entry("card", wsid, _entry_gate(wsid))
	# ㉛：这里以前是 Cards.pool_sets("armor") 等——那个口默认全品级，
	#   于是"精英三抽"能直接摸到极品装备、绕开品级闸（同一时期货摊却只到上品）。
	#   改走 pick_pool("gear")＝按阶段限品级。越阶只留给搜刮（pool_red）。
	var gsets: Array = GameState.pick_pool("gear")
	if gsets.is_empty():
		return {}
	var gsid := str(gsets[randi() % gsets.size()])
	return Loot.make_draw_entry("card", gsid, _entry_gate(gsid))

# 入口卡闸：首片没在手（村里仓库/本趟包裹/临时仓库都算），只出首片
func _entry_gate(sid: String) -> int:
	var parts: int = maxi(1, Cards.part_count(sid))
	if parts <= 1:
		return 0
	var p := randi() % parts
	if p > 0 and not _entry_open(sid):
		p = 0
	return p

# ㊿e2：残卡/残页**只进包裹**——趟内能用、结算带走。
#   ⚠ v34（用户报的②）：这里以前是"包裹满 → 退临时仓库 → 两处都满就 append 越上限"。
#     现改成：包裹满＝在 _on_elite_pick 就拦下来，走"替换 / 折现"（见 _elite_enter_full）。
#     这个函数只剩"有位置就收下"这一条路——临时仓库不再替包裹兜底，也不会被撑过上限。
func _elite_draw_give(e: Dictionary) -> void:
	var sid := _elite_entry_sid(e)
	var part := int(e.get("part", 0))
	if sid != "" and _state.add_card(sid, part):
		return
	# 兜底：调用方漏判了"满包"（比如以后有人绕过来调）——也不许越限，只提示
	UiKit.float_text(self, "包裹满了——先替一件出来或折现", UiKit.SEAL)

# v34：这一件是哪一套——**两种键都要认**：战利走 Loot.make_draw_entry（键="id"），
#   包里/临时仓库的件走 add_card（键="set"）。折现价、收件都得按同一个 sid 算，
#   不然"折现价"会按凡品（sid=""）算，白亏品级那一段。
func _elite_entry_sid(e: Dictionary) -> String:
	return str(e.get("set", e.get("id", "")))

# ============ v34：精英战利 · 满包（替换 / 折现） ============
# 口径与事件三选一（journey_event_flow._enter_replace_mode）**一模一样**：
#   · 替换＝点右上角包裹里的一件丢掉，换回它的**卖价**（盘缠），新版战利收下；
#   · 折现＝这一件按**折现价**（cashout_price＝低于卖店）换盘缠，等于放弃它。
# 这一页用 _make_veil（非 blocking）：包裹面板要留在遮罩上面，玩家才点得到格子。

func _elite_enter_full(entry: Dictionary, nm: String) -> void:
	_elite_pending = entry
	_elite_pending_name = nm
	_close_overlay()
	var veil := _make_veil(0.52)
	var panel := UiKit.make_paper_panel(veil, Rect2(110, POPUP_TOP, 500, 380))

	var title := UiKit.make_label(panel, Vector2(0, 24), Vector2(500, 44), 30, UiKit.INK)
	UiKit.set_text(title, "包裹已满")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var cp := int(_state.cashout_price(_elite_entry_sid(entry)))
	var body := UiKit.make_label(panel, Vector2(30, 76), Vector2(440, 170), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.88))
	UiKit.set_text(body, "「" + nm + "」得先腾出一格——两条路：\n· 替换：点右上角包裹里的东西丢掉（换回它的卖价＝盘缠），这件收下；\n· 折现：这件不要了，直接换 " + str(cp) + " 文盘缠。\n（临时仓库不再代收——包裹满，就得舍一件）")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var b1 := UiKit.make_button(panel, Vector2(60, 274), Vector2(180, 46), "折现（+" + str(cp) + " 文）", 18)
	b1.pressed.connect(_on_elite_full_cashout)
	var b2 := UiKit.make_button(panel, Vector2(260, 274), Vector2(180, 46), "返回（看别的）", 18)
	b2.pressed.connect(_on_elite_full_back)

# 折现：这一件换盘缠（照旧用折现价——它低于卖店价，是"省事的代价"）
func _on_elite_full_cashout() -> void:
	if _elite_pending.is_empty():
		return
	var cp := int(_state.cashout_price(_elite_entry_sid(_elite_pending)))
	_state.money += cp
	print("[战利] 满包折现：", _elite_pending_name, " +", cp, " 文")
	_elite_pending = {}
	_elite_pending_name = ""
	_refresh_all()
	UiKit.float_text(self, "折现 +" + str(cp) + " 文", UiKit.GOLD)
	_elite_round += 1
	_show_elite_round()

# 返回：这一轮重新看（候选不重摇——免得"返回"变成免费刷新）
func _on_elite_full_back() -> void:
	_elite_pending = {}
	_elite_pending_name = ""
	_show_elite_round(true)

# 替换：包裹格被点到了（journey_bag_panel 先问这里）。
#   丢掉那件 → 换回它的卖价（盘缠）→ 把战利收进包裹 → 续下一轮。返回 true＝已处理。
func _elite_do_replace(i: int) -> bool:
	if _elite_pending.is_empty():
		return false
	if _state == null:
		return true
	# 上面压着"必须答完"的页（退出确认 / 命数抉择…）时不接这一下——
	#   交给包裹件的 _show_card_detail 去提示"先把上面这一页答完"。
	if _popup_blocking:
		return false
	if i < 0 or i >= _state.bag.size():
		return true
	var e: Dictionary = _state.bag[i]
	var sp: int = int(_state.price_of(e))
	var lost := str(_state.card_label(e))
	_state.money += sp
	_state.bag.remove_at(i)
	var card: Dictionary = _elite_pending
	_elite_pending = {}
	_elite_pending_name = ""
	_elite_draw_give(card)
	print("[战利] 满包替换：丢掉 ", lost, "（+", sp, " 文）→ 收下 ", _elite_entry_sid(card), " 第 ", int(card.get("part", 0)), " 片")
	_refresh_all()
	UiKit.float_text(self, "舍「" + lost + "」+ " + str(sp) + " 文 → 收下新的一件", UiKit.GOLD)
	_elite_round += 1
	_show_elite_round()
	return true

func _elite_draw_done() -> void:
	_close_popup()
	_busy = false
	_finish_node("elite")

# ============ 合成（v26 搬家：全套 → journey_synth_panel.gd；此处只留转发口，名字别改） ============
# 老契约：包裹件的合成按钮走本转发口——它转发给合成件（件持队列，弹"去向"页）。

func _on_synth_pressed() -> void:
	_synth.press()

# ============ ㊿w：这件给谁穿（合成去向页 / 包裹详情页共用） ============
# 病根：多人上场时，［装备］永远穿在"当前看着的那个人"身上（要换人得先去左上角
#   ［角色］切人再回来点——等于没得选）。这里补一步显式选人。
# 单人趟不问（直接回调 0，跟以前一模一样）。
#   on_pick 收一个成员下标；调用方拿它走 place_item_for / equip_from_bag_for。
#   on_bag（可选）：合成去向页那条"放包裹"的路仍要留着——给传了就多一颗
#     ［放包裹（先不穿）］；不传就只有［先不穿］（包裹详情页那边本来就在包裹里）。
func ask_member(sid: String, title: String, on_pick: Callable, on_bag := Callable()) -> void:
	if _state == null:
		return
	if _state.members.size() <= 1:
		on_pick.call(0)
		return
	_open_member_pick(sid, title, on_pick, on_bag)

func _open_member_pick(sid: String, title: String, on_pick: Callable, on_bag: Callable) -> void:
	_close_popup()
	var veil: ColorRect = _make_popup_veil(true)
	var n: int = _state.members.size()
	var ph := 160.0 + float(n) * 80.0
	var panel := UiKit.make_paper_panel(veil, Rect2(120.0, POPUP_TOP, 480.0, ph))

	var t1 := UiKit.make_label(panel, Vector2(0, 16), Vector2(480, 34), 24, UiKit.INK)
	UiKit.set_text(t1, title + "：『" + str(Cards.item_name(sid)) + "』")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var t2 := UiKit.make_label(panel, Vector2(24, 54), Vector2(432, 24), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.60))
	UiKit.set_text(t2, "点谁就穿在谁身上（各人的兵器/三件套/功法是分开的）")
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for i in n:
		var info := _member_pick_info(i, sid)
		var txt := str(info.get("name", "")) + "　" + str(info.get("row", "")) + " · " + str(info.get("tail", ""))
		var b := UiKit.make_button(panel, Vector2(30, 88 + float(i) * 80), Vector2(420, 62), txt, 17)
		b.disabled = not bool(info.get("can", true))
		if not b.disabled:
			b.pressed.connect(_on_member_pick.bind(i, veil, on_pick))

	if on_bag.is_valid():
		var bg := UiKit.make_button(panel, Vector2(120, 100 + float(n) * 80), Vector2(240, 48), "放包裹（先不穿）", 17)
		bg.pressed.connect(_on_member_bag.bind(veil, on_bag))
	else:
		var cb := UiKit.make_button(panel, Vector2(170, 100 + float(n) * 80), Vector2(140, 48), "先不穿", 17)
		cb.pressed.connect(_close_popup)

func _drop_pick_veil(veil: Control) -> void:
	if veil != null and is_instance_valid(veil):
		veil.queue_free()
	if _popup == veil:
		_popup = null
		_popup_blocking = false

func _on_member_pick(i: int, veil: Control, on_pick: Callable) -> void:
	_drop_pick_veil(veil)
	on_pick.call(i)

func _on_member_bag(veil: Control, on_bag: Callable) -> void:
	_drop_pick_veil(veil)
	on_bag.call()

# ㊿w 补刀：这一名成员**叫什么**（选人行、飘字都用它）。
#   病根：成员表（run_state._blank_member）里**没有 name 键**，以前这里一律退成
#     "成员1／成员2"——多人趟里两行长得一模一样，玩家根本认不出点的是谁。
#     （用户报的"点击装备、提示已装上，人还是空手"就是从这儿来的：
#      他点的那一行不是面板正看着的那位，穿完面板/小人一动不动。）
#   口径：名字的真源是**村账**（弟子面板、出征屏读的都是它）；查不到才退回"成员N"。
func member_name_of(i: int) -> String:
	if _state == null:
		return "成员" + str(i + 1)
	var m: Dictionary = _state.member_at(i)
	var nm := str(m.get("name", ""))
	if nm == "":
		nm = str(GameState.role_data(str(m.get("role_id", ""))).get("name", ""))
	if nm == "":
		nm = "成员" + str(i + 1)
	return nm

# 这一行文案：谁 · 什么排 · 他现在这一格是什么
func _member_pick_info(i: int, sid: String) -> Dictionary:
	var keep: int = _state.active_i
	_state.use_member(i)
	var can: Dictionary = _state.can_place_item(sid)
	var nm := member_name_of(i)
	var tail := ""
	if Cards.is_arts(sid):
		var arts: Array = _state.arts
		tail = "功法 " + str(arts.size()) + "/" + str(RunState.ART_SLOTS)
		if arts.has(sid):
			tail += " · 已有同名"
		elif not bool(can.get("equip", false)):
			tail += " · 满了，得先卸一门"
	else:
		# ⚠ 显式标注：_state 是 RunState，但 GDScript 对"经 var 转一手的调用"推断不稳
		var slot: String = _state.gear_slot_of(sid)
		if slot != "":
			var cur := str((_state.run_gear as Dictionary).get(slot, ""))
			tail = str(RunState.SLOT_CN.get(slot, slot)) + "：" + ("（空着）" if cur == "" else str(Cards.item_name(cur)))
		else:
			var w := str(_state.weapon_id())
			tail = "兵器：" + ("（空手）" if w == "" else str(Cards.item_name(w)))
	if i == keep:
		tail += " · 现在看着他"
	_state.use_member(keep)
	return {"name": nm, "row": _member_row_cn(i), "tail": tail, "can": bool(can.get("equip", false))}

# 队伍里的排位（1 人＝单 · 2 人＝前/后 · 3 人＝前/中/后）
func _member_row_cn(i: int) -> String:
	var n: int = _state.members.size()
	var names: Array = ["前", "中", "后"]
	if n == 1:
		names = ["单"]
	elif n == 2:
		names = ["前", "后"]
	return str(names[clampi(i, 0, names.size() - 1)]) + "排"

# ============ 战斗 ============

func _begin_fight(node: Dictionary) -> void:
	_busy = true
	_close_overlay()
	_set_battle_hud(true)
	var battle := DuelBattle.new()
	add_child(battle)
	var res: Dictionary = await battle.run(_state, _walker, _fx, node, false, _companions)
	if is_instance_valid(battle):
		battle.queue_free()
	# R4（Q1=b）：败北＝殒命——不拾钱、不搜刮，直接走殒命结算
	var won := bool(res.get("won", false))
	var gain := int(res.get("gain", 0))
	if won:
		_state.money += _money_gain(gain)
	_refresh_all()
	if won:
		UiKit.float_text(self, "胜！收下 " + str(_money_gain(gain)) + " 文", UiKit.GOLD)
	else:
		UiKit.float_text(self, "你倒下了……", UiKit.SEAL)
	_set_battle_hud(false)
	var back := create_tween()
	back.tween_property(_walker, "position", _walk_home, 0.4)
	_retreat_companions(back)
	await back.finished
	_busy = false
	# ㊾：打完这一仗立刻落盘。
	#   这时 _state.hp（残血）与 _state.money（赏钱）都已经是最终值了
	#   （duel_battle._end 回写气血 → 上面加钱 → 走回原位的补间也放完了）。
	#   ⚠ 以前最近的安全点是"进节点"，也就是**打仗之前**那一笔：
	#   精英三抽/结算里一强退，这一仗的残血就整笔丢掉，回来人是满血
	#   （duel_battle 明明写回了 _state.hp，可存档里根本没存 hp——两处一起漏）。
	#   放这里不会让人重打这一节：_node_entered 早在进节点时就存过了。
	JourneySave.save_run(self)
	if won:
		if bool(node.get("boss", false)):
			# v62o（用户重做命数）：短绳签——**每打过一个 boss 关保底一瓶金色品质的酒**
			#   （金＝竹叶酒，grade 3）。放进 _state.bonus_wines，结算时并进战利——
			#   不走临时仓库（那个格子少，保底被"包满"吞掉就白给了）。
			if _has_fate("fate_shortrope"):
				_state.bonus_wines.append(3)
				UiKit.float_text(self, "爆率签保底：得一瓶「竹叶酒（上品）」", UiKit.GOLD)
				print("[战利] 短绳签 boss 保底：+1 瓶金酒（grade 3）")
			# ㊿：boss收尾——打完直接进结算（这趟到头）
			_open_settle()
			return
		if bool(node.get("elite", false)):
			# ㊳：精英毙命——先摸三抽，收好再摆搜刮
			_busy = true
			_open_elite_draw()
			return
		_finish_node("battle")
	else:
		_open_settle_death()

# ============ 事件 / 商店（已拆件；此处只留接口转发） ============
# 事件三选一全套 → journey_event_flow.gd；货郎担全套 → journey_shop_panel.gd。

# 商店拖卖落点：DropPanel（在货郎件里）认舞台这个名字——转发给货郎件，名字别改。
func on_shop_drop(bag_index: int) -> void:
	_shop._on_shop_drop(bag_index)

# ============ 结算（v25 搬家：全套 → journey_settle.gd；此处只留转发口，名字别改） ============
# 老契约：_continue 的 "settle" 节点调 _open_settle；战斗败北 / 遭遇败北调 _open_settle_death。
# 件不反向引舞台（老铁律）：这里把 状态·幕布·两个回程回调 递进去，件只管摆页。

func _open_settle() -> void:
	_busy = true
	Ladder.run_rate_mul = 1.0    # v99：这一趟完了，爆率倍率复位（别漏到村里/爬塔）
	# ㊿c4b：进结算页＝引子走通——先记账落盘，再抹续行档（这一页怎么关都不亏）
	if _state != null and str(_state.mode) == "intro" and not GameState.first_journey_done:
		_snapshot_player()
		GameState.finish_journey()
		GameState.save_game()
		print("[游历] 引子走通·已记账：村况=", GameState.village_stage, " · 首趟=", GameState.first_journey_done)
	JourneySave.erase()   # ④b：这趟完了（先抹档，再入账）
	_close_overlay()
	Settle.open(_state, _make_veil(0.52), _on_restart, _on_return_village)

func _open_settle_death() -> void:
	_busy = true
	Ladder.run_rate_mul = 1.0    # v99：同上，殒命也复位
	_run_dead = true
	JourneySave.erase()   # ④b：这趟完了（殒命）——档抹掉
	_clear_loot()
	_close_overlay()
	Settle.open_death(_state, _make_veil(0.52), _on_restart, _on_return_village)

func _on_restart() -> void:
	_close_overlay()
	_start_run()

# v15：回村——记一笔账，然后让主界面接手
# v16：正式趟不写主角快照、不动村况——只留一句归宿（难度已在结算开启时记过）
func _on_return_village() -> void:
	_close_overlay()
	if _run_dead:
		# 殒命回村：不写主角快照、不加村况、不提示难度——只留一句归宿
		GameState.pending_note = _restore_strip("回到村子——这一趟折在了外头，东西没能带回来")
		print("[游历] 殒命回村：mode=", _state.mode)
		var err_d := get_tree().change_scene_to_file(MENU_SCENE)
		if err_d != OK:
			print("[游历] 回村失败，错误码=", err_d, "；检查路径：", MENU_SCENE)
			UiKit.float_text(self, "回村失败：看看控制台", UiKit.SEAL)
		return
	if _state.mode == "formal":
		GameState.note_push("回到村子——" + GameState.diff_name(int(_state.diff)) + "走通了（已记档）")
		print("[游历] 正式趟回村：难度=", _state.diff, " 已清=", GameState.diff_is_cleared(int(_state.diff)))
	else:
		# ㊿c4：走通已在进结算页时记过——这里只在漏记时补一笔，然后留归宿句
		if not GameState.first_journey_done:
			_snapshot_player()
			GameState.finish_journey()
		# v40：走 note_push（不再直接赋值）——引子那趟 finish_journey 里"礼包到手"那句
		#   就是被这一行吃掉过，现在两句会串在一起播。
		GameState.note_push("回到村子——又修好一段（" + str(GameState.village_stage) + "/" + str(GameState.VILLAGE_MAX) + "）")
		print("[游历] 回村：村况=", GameState.village_stage, " 首趟=", GameState.first_journey_done)
	# ㊿v：走通/殒命两条路都要把出征时卸下的随身之物穿回去（殒命那条上面已单独过一遍）
	GameState.pending_note = _restore_strip(GameState.pending_note)
	# ㊿f：点［回村］先落盘再切场——村况/首趟/弟子先写进文件
	GameState.save_game()
	print("[游历] 点［回村］已落盘：首趟=", GameState.first_journey_done, " 村况=", GameState.village_stage)
	var err := get_tree().change_scene_to_file(MENU_SCENE)
	if err != OK:
		print("[游历] 回村失败，错误码=", err, "；检查路径：", MENU_SCENE)
		UiKit.float_text(self, "回村失败：看看控制台", UiKit.SEAL)

# ㊿v：回村前把"出征时自动卸下的随身之物"照原样穿回去（村账上的那几个人）。
#   三条回村路（半路折返 / 殒命 / 走通）都从这儿过——漏一条，玩家的兵器与功法
#   就会留在村仓库里，下次出门前还得自己一件件重新穿（就是那个反馈）。
#   引子趟没有出征卸装记录，这里天然是空操作。
func _restore_strip(note: String) -> String:
	var back := GameState.strip_restore()
	if back == "":
		return note
	print("[游历] ", back)
	if note == "":
		return back
	return note + "｜" + back

# v15c：把主角的"毕业状态"记进账本（属性/兵器/功法/天赋/自带）
func _snapshot_player() -> void:
	if _state == null:
		return
	if str(_state.mode) != "intro":
		return   # R1 红线：正式趟绝不回写账本（角色面板只读引子趟/村内账）
	var snap := {
		"name": "少侠",
		"sub": "主角 · 江湖新客",
		"stats": _state.stats().duplicate(),
		"weapon": str(_state.equipped_item),
		"skills": _state.arts.duplicate(),
		"talents": _state.talents.duplicate(),
		"innate": str(_state.innate_name()),
		"innate_desc": str(_state.innate_desc()),
	}
	GameState.capture_player(snap)
	print("[游历] 主角快照入账本：攻=", int(snap["stats"].get("atk", 0)), " 兵器=", snap["weapon"], " 功法=", snap["skills"].size(), " 天赋=", snap["talents"])

# ============ 背景绘制（已拆件：全套搬去 journey_backdrop.gd） ============

func _draw() -> void:
	Backdrop.draw_all(self, size, _scroll_far, _scroll_mid, _scroll_road)

# ㊿h：切场即存——离开游历场（回村/殒命/放弃/直接关窗）时把全局账落一次盘。
# 主界面侧同款规则早在 menu_sketch 的 _exit_tree；两处合起来＝凡切场必存。
func _exit_tree() -> void:
	GameState.save_game()
	print("[游历] 离场落盘：村况=", GameState.village_stage, " 首趟=", GameState.first_journey_done)

# 战斗中收起游历界面，打完还原（此前整份重发曾漏掉本函数，已补回）
func _set_battle_hud(in_battle: bool) -> void:
	_sub_bar.visible = not in_battle
	_bag.set_ui_visible(not in_battle)
	_char.set_btn_visible(not in_battle)
	_alert_bar.visible = not in_battle
	_alert_label.visible = not in_battle
	_hp_bar.visible = not in_battle
	_hp_label.visible = not in_battle
	# ㊿z10：宠物牌跟血条/警惕条一批显隐（战斗里藏起来，别挤战场）
	if _pet_chip != null and is_instance_valid(_pet_chip):
		_pet_chip.visible = (not in_battle) and str(GameState.pet_follow) != ""
	if _quit_btn != null:
		_quit_btn.visible = not in_battle
	if _buff_btn != null:
		_buff_btn.visible = not in_battle
	if in_battle and _buff_panel != null and is_instance_valid(_buff_panel):
		_buff_panel.queue_free()
	if _loot_row != null and is_instance_valid(_loot_row):
		_loot_row.visible = not in_battle
	if in_battle:
		_char._set_char_panel(false)
	_refresh_alert()

# ㊿：打完仗，同伴跟着走回队伍原位（两处收尾都用它）
func _retreat_companions(tw: Tween) -> void:
	for i in _companions.size():
		var c = _companions[i]
		if c == null or not is_instance_valid(c):
			continue
		var idx := i + 1
		tw.parallel().tween_property(c, "position", _walk_home + Vector2(COMPANION_DX * float(idx), COMPANION_DY * float(idx)), 0.4)
