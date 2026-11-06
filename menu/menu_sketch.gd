extends Control
# ============================================================
# menu_sketch.gd —— 主界面 v29 总装
# v29（优化批㉒）：①启动先 GameState.load_game()（全档：角色/仓库/宠/血脉…不再进游戏清零）；
#   ②退场与每 20 秒落盘；③R 键＝重置测试（3 秒内连按两次），清全部存档。
# v28 总装
# v28 变更（R4 ④b）：历练入口先查续行档——有档弹［继续／重新开始］；继续=直接切游历
#   （舞台自己接上），重新开始=抹档后走原路（v27 的闸不变）。
# v27 变更（R1 焊接）：
#   ① 历练入口加闸：首趟（引子·五问）走老路；其后都先过「出征屏」
#      （menu/journey_depart.gd）——选人·选难度·看携宠，点出发才切游历
#   ② 后山二遭：白狐入册后松梢落隼（village v13 早已画好，这里补喂 sun_joined）；
#      再点后山＝收隼入册（宠物面板自动多一页签）
#   ③ K 键改「重播整条宠链」：狐、隼都从名册摘掉重走（灵息归零，测试用）
# v26 变更：
#   ① 出战只剩一套面板：formation_panel v3（三格＋名单；首次引导与配置同体）——
#      deploy_panel 整体拆除（menu/deploy_panel.gd 可删），F 键改开整备面板
#   ② 山洞：做完任务记号消失（本文件）；山石画也整段不画（village v12）
#   ③ 货栈上新：兵器残卡 / 武学残页（银两买、每日限购）——账本 v18 已备好行
# v25 已有：底排「宠物」＝HUD 直画；四季轮换；吊绳挂机木牌；左端装裱拔除
# 测试键（字母）：F 出战配置 · I 入门 · K 后山·重播宠链 · M 仓库货 · T 挂机+1时 ·
#   Y 挂机灌满 · G 建筑链+炼丹 · H 酒 · C 炼丹料 · V 炉火快进 · X 推到30关 ·
#   W 窗口 · P 宠物 · Q 女侠 · N 下一季（预览）
# v63 后新增（同样重开游戏才生效）：
#   B 抽搐取证（任何界面）· U 跳引子直达主界面 · S 苏青鸾入队 · E 困兽试玩
# ============================================================

const Conf := preload("res://menu/menu_conf.gd")
const Audio := preload("res://shared/audio.gd")   # v65：BGM / 音效总管
const InkTouch := preload("res://shared/ink_touch.gd")   # v65：点击水墨扩散
const FadeIn := preload("res://shared/fade_in.gd")      # v68：进场淡入 + 震动
const SceneArt := preload("res://shared/scene_art.gd")   # v67：场景/建筑图
const Draw := preload("res://menu/menu_draw.gd")
const ScrollLayer := preload("res://menu/menu_scroll.gd")
const VillageLayer := preload("res://menu/menu_village.gd")
const InkScene := preload("res://menu/menu_ink_scene.gd")   # v96：水墨村景层（摆景器那套）
const PlaqueLayer := preload("res://menu/menu_plaque.gd")   # v97：主界面牌子层（用户标注的 11 处锚点）
const Realm := preload("res://shared/data_realm.gd")        # v122：进阶（主界面那颗按钮）
var _adv_veil: ColorRect = null                             # v122：进阶页的幕布
# 两个开关：村景层开着、纸偶演员关掉（用户 2026-10-08："三个移动小人就不要了"）
const USE_INK_SCENE := true
# 角色五档（天 > 地 > 玄 > 黄 > 宇）；主角倒数第二档 = 黄
const CHAR_GRADES := ["天", "地", "玄", "黄", "宇"]
const PLAYER_GRADE_IDX := 3
const USE_PAPER_ACTORS := false
# v97（用户："让村景层铺满全屏" / 交接 §12.7 第 1 条「收旧画心」）：
#   水墨村景层当底之后，旧的**「少年游」画心长卷**（menu_scroll）与**程序画的村景**
#   （menu_village）就是压在它上面的两层"旧画"——整条画卷还占着屏幕中央，村景只在
#   下面露一条。开关打开＝这两层连同远山层、旧特效层一起收起（**只隐藏、不删**，改 false 就回退）。
const INK_ONLY := true
# v243（用户："少年游这个画卷目前很碍事了 去掉吧 就主界面就行"）：
#   画卷收起——开屏直接是村景主界面，不展卷、不拖卷、不显示封面。
const SCROLL_OFF := true
# v99（用户："用这个吧 把豆包ai p掉"）：主场景改用豆包出的那支 **10 秒动态画**（720×1124，
#   水墨村落：云在飘、鸟在飞、水在动、船在划）。水印已用 tools/spine-bake/wm_clean.mjs 逐帧补掉，
#   成品在 assets/video/village_loop.ogv（Godot 的 VideoStreamPlayer 只吃 Ogg Theora，所以转成 ogv）。
#   关掉这个开关＝回到摆景器那一版（10 件 + 动效），两套随时可切。
const USE_VIDEO_SCENE := true
const VIDEO_SCENE := "res://assets/video/village_loop.ogv"
# v98（用户："之前画卷不是可以滑动吗 把这个画卷形式保留 就保留图前面这个少年游这个封卷封面即可"）：
#   画卷**回来了**，但只有两页：右边一页＝《少年游》封卷封面（装裱层的引首），左边一页＝新村景。
#   开屏停在封面页，**向右拖**＝展卷到村景（跟老版一个手感，见 _sc）。
#   PIN_CAM 仍为 true：老那套 3000 像素的横向长卷（_cam）不再用，镜头钉死；
#   现在的"拖"改由 _sc 驱动。想回老长卷：INK_ONLY=false + PIN_CAM=false。
const PIN_CAM := true
const MountLayer := preload("res://menu/menu_mount.gd")
const HudLayer := preload("res://menu/menu_hud.gd")
const Ui := preload("res://menu/menu_theme.gd")   # v200：影之刃皮肤
const UiKit := preload("res://shared/ui_kit.gd")
const MistLayer := preload("res://menu/menu_mist.gd")   # v72：设置面板用（标签/按钮/纸张面板工厂）
const CharArt := preload("res://shared/char_art.gd")   # v92：村里的同伴/看火人用 Q版立绘（原来画火柴人）
const CharacterPanel := preload("res://menu/character_panel.gd")
const WarehousePanel := preload("res://menu/warehouse_panel.gd")
const ForgeData := preload("res://menu/data_forge.gd")
const TwitchRecorder := preload("res://shared/twitch_recorder.gd")   # v63k：抽搐取证器（B 键用）
const OutPanel := preload("res://menu/out_panel.gd")
const TutorialStage := preload("res://kushou/tutorial_stage.gd")   # 重做期：教学关 v0（村口 · 5 波）
const ChestPanel := preload("res://menu/chest_panel.gd")   # v36：宝箱
const AppraisePanel := preload("res://menu/appraise_panel.gd")   # v39：鉴宝行
const CraftPanel := preload("res://menu/craft_panel.gd")   # v50：百工坊（品酒/炼丹/鉴宝 三合一的门厅）
const ForgePanel := preload("res://menu/forge_panel.gd")   # v242：百工坊门厅第四间——铁砧
const FormationPanel := preload("res://menu/formation_panel.gd")
const WinePanel := preload("res://menu/wine_panel.gd")
const AlchemyPanel := preload("res://menu/alchemy_panel.gd")
const StarPanel := preload("res://menu/star_panel.gd")   # v4.3：统一升星页（角色星 + 兵器/防具/功法·武学）
const PetPanel := preload("res://menu/pet_panel.gd")
const ShopPanel := preload("res://menu/shop_panel.gd")
const JourneyDepart := preload("res://menu/journey_depart.gd")
const RegionSelectPanel := preload("res://menu/region_select.gd")
const WorldPanel := preload("res://menu/world_panel.gd")
const InsightPanel := preload("res://menu/insight_panel.gd")   # v64b：阅历线（底排第 6 格）
const JourneySave := preload("res://journey/journey_save.gd")
const BattleLite := preload("res://menu/battle_lite.gd")
const GameState := preload("res://shared/game_state.gd")
const Tuning := preload("res://shared/tuning.gd")   # ㉘：调参配置状态查询


# ============================================================
# ㉟ 剧情节点在塔上的位置
# 塔从 50 关扩到两万关之后，这几个节点跟着往后排（顺序有意义：先得图、再遇人、最后灵草）。
#   改这里＝改剧情节奏。触发条件是"通关数 >= 这个数且该剧情还没放过"，
#   所以老档不会漏戏：进村时会按顺序补放。
#   ⚠ 炼丹阁是**过 300 关（灵草剧情）才解锁**的——见 _dange_ready()。
#     （旧注释写的是"先有炉子、后有料，300 关前就是个空屋"，
#       那是更早的口径；现在改成"过了 300 关才起得了炉"，以代码为准。）
#   ⚠ ㊿：这三个数**已经搬到 GameState**（STORY_MAP_STAGE 那几个）——因为货栈的
#     "上架闸"（兽骨碎/灵米跟着炉子一起上架）在 game_state 里，而那边不该反向引菜单。
#     这里留成别名：名字没变，下面所有用法一个字不用改。
# ============================================================
const MAP_STAGE := GameState.STORY_MAP_STAGE       # 藏宝图（得「藏宝阁」记号）
const NVXIA_STAGE := GameState.STORY_NVXIA_STAGE   # 苏青鸾入阵（第三人齐）
const HERB_STAGE := GameState.STORY_HERB_STAGE     # 灵草三种（炼丹阁开工）
const JIANBAO_STAGE := GameState.STORY_JIANBAO_STAGE   # v39：打捞上来的货仓（鉴宝行开张）
const BOOT_INTO_INTRO := true   # 新档开机直接进新引子（menu/prologue.tscn）
const TUTORIAL_DEMO := false     # 暂时不要教学关：底排「出村」走原来的出村面板

const SEASON_DAYS := 3        # 每几天换一季（想两天改 2、一天改 1）
const SEASON_CFG := "user://season.cfg"

# 【危险开关】R 键＝清空全部存档（村账 + 备份 + 旁账，见 GameState.reset_full）。
#   这是唯一一个"按下去就不可挽回"的测试键，所以单独设闸：
#     false（默认）＝ 只有编辑器里按 R 才清档，导出的 APK 里按 R 完全没反应
#     true          ＝ 导出之后也允许清档（只在你明确要在手机上测"从零开新档"时打开）
#   其余测试键（F/I/K/M/T/Y/G/H/C/V/X/L/W/P/Q/N）照旧，导出的包里也能用。
#   用完记得改回 false —— 这个包里本来只有你自己用，但改回来只花一秒钟。
const ALLOW_SAVE_WIPE := false
const SEASON_CN := ["春", "夏", "秋", "冬"]
const SEASON_ARRIVE := [
	"春到了——溪边的柳絮飘起来了",
	"入夏——蜻蜓贴着水面打转",
	"秋深——叶子黄了，一片片往下掉",
	"入冬——雪落在屋顶上",
]

const C_SEAL := Color(0.68, 0.15, 0.12)
const C_GOLD := Color(0.72, 0.58, 0.22)
const C_INK := Color(0.14, 0.13, 0.15)

const INTRO_PAGES := [
	["山门外，多了一个人。", "他背着一杆断枪，从早上站到日落。"],
	["「听说您要走远路。」", "「我留下——赶也不走。」"],
	["他单膝跪下，把名字放在你脚边：", "「陈石。」"],
]
const INTRO_AFTER := "陈石——从今往后，在你门下。"

const BACKHILL_PAGES := [
	["临行前，你往后山走了一趟。", "林子比记忆里深——风一过，树影里像藏着什么。"],
	["草窝里蜷着一团白。", "是只小狐，后腿带着伤，眼睛却亮得很。"],
	["它没躲。你把它抱回村里上了药。", "第二天清早，它已经蹲在门槛上了。"],
]
const BACKHILL_AFTER := "白狐留在了村里——下次出战，它会自己跟来。"

# ⚠ 这三段剧情都挂在某个关号上，而**关号只在 game_state 的 STORY_*_STAGE 里定**——
#   文案里别再手写数字（用户报过："第三个弟子的描述还写着第十五关"）。
#   第一句里的关号统一写成 {N}，显示时由 _story_pages() 按常量现算：
#   藏宝图 = 50 关 · 女侠（苏青鸾入阵）= 150 关 · 灵草 = 300 关。
const MAP_PAGES := [
	["{N} 关清完，你在贼首的箱底翻出一张发黄的皮纸。", "半幅旧图：朱砂勾出一条歪路，尽头画着个小小的记号。"],
	["比对半天，那记号不在山外——就在村子边上。", "旁边挤着一行小字：「财货无主，见者有分。」"],
	["你把图卷起来，塞进怀里。", "村里还能再立一间屋——就照图上的地方起。"],
]
const MAP_AFTER := "得「藏宝图」——村边（往右）多了个「藏宝阁」的记号。"

const CAVE_PAGES := [
	["挖开荒坡背阴处，石缝里透出一股凉风。", "洞不深，走十步就到底。"],
	["洞底石案上蹲着一坛酒，泥封完好。", "封口压着块木牌：「此酒待客，勿饮独酌。」"],
	["你把坛子抱回村里。", "坛子一开，满村都是香气。"],
]
const CAVE_AFTER := "得「陈酿」一坛——去「百工坊」看看。"

const HERB_PAGES := [
	["{N} 关清完，收兵回村。", "白狐头一回走得比人快——径直往后山去。"],
	["它叼着一株草回来：叶是紫的，根是白的，果是红的。", "「一株？」陈石凑近看了看：「师父，是三种。」"],
	["紫芝安神，雪参固本，朱果养气。", "灵草在案上摊开——该有座炼丹的炉子了。"],
]
const HERB_AFTER := "得灵草三种（紫芝·雪参·朱果 各 2）——「炼丹阁」能炼灵草丹了（去「百工坊」开炉）。"

const QINGLUAN_PAGES := [
	["第 {N} 关，寨墙塌了半面。", "你收刀的时候，墙头上有人拍了两下手。"],
	["「路见不平，就该这么管。」她跳下来，剑没出鞘。", "「我姓苏，名青鸾。走了三州，头回见人把正道走得这么直。」"],
	["「我跟你走一段——」她把剑横在臂上。", "「不为别的，就为正道这两个字，还有人肯当真。」"],
]
const QINGLUAN_AFTER := "苏青鸾——第三位同行者（已入阵：三人队齐了）。"

# v39：400 关——**打捞上来的货仓**（鉴宝行开张，这段剧情本身就是新手引导）
#   用户给的戏：船上打捞了一个货仓，锈迹斑斑但保存完好，看不出是什么东西；
#   于是教玩家"未知货仓先研究再下手"——三样道具各管一段信息。
const JIANBAO_PAGES := [
	["{N} 关清完，江面上漂来一截断桅。", "渔民把它拖上岸：桅底下还拴着一只货仓。"],
	["仓门锈得死死的，敲上去却是实心响——里头有东西。", "撬开一条缝，只看见黑。谁也说不清装的是什么。"],
	["「先别急着砸。」陈石把灯凑近。", "「城里有家鉴宝行——他们能照出仓里有什么，照完了你再决定买不买。」"],
	["（新手引导：店里有三样家伙——描影镜照出**最值钱那一件**的轮廓、",
		"透物灯照出**几件**的完整轮廓、识宝鉴认下**一件**的全貌。先照，再掏钱。）"],
]
const JIANBAO_AFTER := "「鉴宝行」在村里开张了——那只打捞上来的货仓摆进店里，不收钱，先拿它练手；另送一套侦查道具。"

const HERO_LINES := [
	"这位少年——往后的路，他替你走",
	"他蹲在溪边，把柴刀磨了又磨。",
	"「路，在村子外面。」",
]
const CHEN_LINES := [
	"「师父。」他抱拳行礼。",
	"「枪是断的，手不是。」",
	"他望着山外——那是下一架的方向。",
]

var _font: Font
var _t := 0.0
var _cam := Conf.OPEN_CAM
var _dragging := false
var _moved := 0.0
var _mode := ""
var _pressed_tag := -1
var _active_tag := -1         # v220：当前开着的面板对应底排哪一格（金线提示）
var _toast := ""
var _toast_t := 0.0
var _hint_a := 1.0
var _demo_done := false
var _demo_clock := 0.0
var _tag_rects: Array = []
var _cover_mode := true        # v200：当前停在封面页（收起商店/困兽，给书名让位）
var _skinned := false          # v206：全局换皮扫描是否已跑过
var _panel_open := false
var _last_panel_open := false   # v211：面板开合沿（用来放 0.18s 的 scale/alpha 入场）
var _actors = null            # v93g：人物层（村景之上、UI 之下，等比缩放）
var _ink = null               # v96：水墨村景层（最底，读 village_layout.json）
var _plaques = null           # v97：牌子层（竖排木牌/六边形徽标/头像；位置＝占屏比例）
var _cover_win = null         # v98：封面页窗口（一张与画心同高的纸；引首由装裱层画在上面）
var _ink_clip = null          # v98：画心——村景页裁到装裱以内那一条（y 26~1150）
var _desk_bg = null           # v98：桌面（画卷之外那一圈底色）
var _video = null             # v99：动态画（VideoStreamPlayer；村景页现在放的是它）
var _sc := 720.0              # v98：画卷偏移。0=村景页铺满 · 720=封面页铺满（向右拖＝展开到村景）
var _sc_tween: Tween = null   # v220：松手后吸附到封面/村景，不再停在半路
var _hint_used := false       # v98：玩家拖过一次就不再多嘴"按住画卷"
var _set_btn = null           # v97：旧的右上角「设置」按钮（牌子层接管后收起来，代码留着）
var _tag_notice := -1
var _story_kind := ""
var _story_page := -1
var _hero_i := 0
var _chen_i := 0
var _money_clock := 0.0
var _idle_clock := 0.0
var _season := 0
var _season_clock := 0.0
var _season_lock := false
var _auto_resume_i := -1
var _reset_arm := 0          # 优化批㉒：重置键——第一次按记录时刻，3 秒内再按才真清

var _scroll = null
var _village = null
var _mount = null
var _mist = null                # v232：画心雾气（随季换粒子）
var _hud = null
var _settings_ov = null       # v72：设置面板（音乐/音效音量 + 主界面曲目）
var _char_panel = null
var _warehouse = null
# 引导段落状态（行囊/角色 到剧情才解锁；段落可单独跳过）
var _bag_unlocked := false
var _role_unlocked := false
var _seg2_loot := 50
var _seg2_playing := false
var _seg3_seen := false
var _seg4_seen := false
var _seg4_ended := false
# ㊿z12（抽搐取证）：测试键 B 开的抽帧记录器（见文件末尾 TwitchRecorder）
var _twitch_rec: Node = null
var _out_panel = null
var _tutorial = null
var _loot_pop: Control = null
var _loot_fx: Control = null
var _chief_dlg: Control = null
var _chief_lines: Array = []
var _chief_i := 0
var _chief_name: Label = null
var _chief_text: Label = null
var _chief_done := Callable()
var _chief_portrait: Control = null
var _chief_face: TextureRect = null
var _forge_story_done := false
var _forge_tut := false
var _forge_tut_done := false
var _forge_box: Control = null
var _forge_box_name: Label = null
var _forge_box_text: Label = null
var _forge_guide: Control = null
var _forge_guide_rc := Rect2()
var _forge_pending_sword: Dictionary = {}
var _forge_wait := 0.0
var _forge_wait_kind := ""
var _forge_blank_step := false
var _craft_guide: Control = null
var _craft_guide_rect := Rect2()
var _craft_guide_text := ""
var _craft_guide_step := ""
var _chest_panel = null   # v36：宝箱面板
var _formation = null
var _kushou = null          # v63：困兽 v1 试玩面板（现在按 Shift+E）
var _kushou_v2 = null       # v147：困兽 v2 主界面空壳（按 E）
var _winery_panel = null
var _alchemy_panel = null
var _star_panel = null   # v4.3：统一升星页（替掉旧的升星台）
var _appraise_panel = null   # v39：鉴宝行
var _craft_panel = null      # v50：百工坊（三个作坊的门厅）
var _forge_panel = null      # v242：铁砧屏
var _pet_panel = null
var _shop_panel = null
var _depart = null
var _region_panel = null
var _world_panel = null
var _battle = null
var _veil = null
var _marks_root: Control
var _mark_btns: Array = []
var _fx_root: Node2D
var _money_hud = null
var _idle_btn = null     # IdlePlaque（吊绳尖尾木牌；内类，别标 Button）
var _idle_t_lb: Label
var _idle_time_lb: Label
var _idle_act_lb: Label

# ---- 右上角：银两 / 元宝 ----
class MoneyHud extends Node2D:
	var font: Font = null
	var silver := 0
	var yuanbao := 0
	var _sb1: StyleBoxFlat = null
	var _sb2: StyleBoxFlat = null
	# v220：钱数滚动——目标变了先"数上去"，再停在目标值；同时金一下
	var _disp_silver := 0.0
	var _disp_yuanbao := 0.0
	var _last_silver := -1
	var _last_yuanbao := -1
	var _bump_s := 0.0
	var _bump_y := 0.0
	var _seeded := false

	func _process(delta: float) -> void:
		if not _seeded:
			_disp_silver = float(silver)
			_disp_yuanbao = float(yuanbao)
			_last_silver = silver
			_last_yuanbao = yuanbao
			_seeded = true
		if silver != _last_silver:
			_last_silver = silver
			_bump_s = 1.0
		if yuanbao != _last_yuanbao:
			_last_yuanbao = yuanbao
			_bump_y = 1.0
		var ns := Ui.ease(_disp_silver, float(silver), 9.0, delta)
		if absf(ns - float(silver)) < 0.5:
			ns = float(silver)
		_disp_silver = ns
		var ny := Ui.ease(_disp_yuanbao, float(yuanbao), 9.0, delta)
		if absf(ny - float(yuanbao)) < 0.5:
			ny = float(yuanbao)
		_disp_yuanbao = ny
		_bump_s = maxf(0.0, _bump_s - delta * 5.0)
		_bump_y = maxf(0.0, _bump_y - delta * 5.0)
		queue_redraw()

	func _coin(c: Vector2) -> void:
		draw_circle(c, 12.0, Color(0.90, 0.90, 0.92))
		draw_circle(c, 12.0, Color(0.42, 0.42, 0.50, 0.85), false, 2.0)
		draw_rect(Rect2(c.x - 4.0, c.y - 4.0, 8.0, 8.0), Color(0.42, 0.42, 0.50, 0.85), false, 2.0)

	func _ingot(c: Vector2) -> void:
		var g := Color(0.86, 0.68, 0.26)
		var gd := Color(0.55, 0.42, 0.15, 0.9)
		var pts := PackedVector2Array([
			c + Vector2(-13, 7), c + Vector2(-7, -2),
			c + Vector2(7, -2), c + Vector2(13, 7),
		])
		draw_colored_polygon(pts, g)
		draw_circle(c + Vector2(0, -4), 6.5, g)
		draw_circle(c + Vector2(0, -4), 6.5, gd, false, 1.5)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), gd, 1.5)

	# v200：影之刃式资源条——墨底金线，钱眼/元宝都用金
	func _n_draw() -> void:
		# v211：银两/元宝压进顶栏墨带（右段 340~628），不再浮在画面里
		var r1 := Rect2(340.0, 30.0, 140.0, 38.0)
		var r2 := Rect2(488.0, 30.0, 140.0, 38.0)
		var o := {"fill": Color(0.094, 0.080, 0.070, 0.90),
			"edge": Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.58),
			"cut": 7.0, "bracket": false, "shadow": 0.45, "ink_halo": false,
			"glow": maxf(_bump_s, _bump_y) * 0.55}
		Ui.panel(self, r1, o)
		Ui.panel(self, r2, o)
		# 铜钱：金钱一枚，中间方孔
		var c := Vector2(364.0, 49.0)
		draw_circle(c, 10.5, Color(0.86, 0.71, 0.38))
		draw_arc(c, 10.5, 0.0, TAU, 24, Color(0.38, 0.29, 0.12, 0.85), 1.4, true)
		draw_rect(Rect2(c + Vector2(-3.5, -3.5), Vector2(7.0, 7.0)), Color(0.38, 0.29, 0.12, 0.85), false, 1.4)
		draw_string(font, Vector2(384.0, 57.0), str(int(round(_disp_silver))), HORIZONTAL_ALIGNMENT_RIGHT, 82.0, 20.0,
			Color(0.960, 0.925, 0.820, 0.96).lerp(Ui.GOLD_HI, _bump_s * 0.85))
		# 元宝
		var g := Vector2(512.0, 49.0)
		var pts := PackedVector2Array([g + Vector2(-9.0, 5.0), g + Vector2(-5.0, -1.0),
			g + Vector2(5.0, -1.0), g + Vector2(9.0, 5.0)])
		draw_colored_polygon(pts, Color(0.86, 0.71, 0.38))
		draw_circle(g + Vector2(0.0, -3.0), 4.6, Color(0.90, 0.76, 0.42))
		draw_string(font, Vector2(532.0, 57.0), str(int(round(_disp_yuanbao))), HORIZONTAL_ALIGNMENT_RIGHT, 82.0, 20.0,
			Color(0.960, 0.925, 0.820, 0.96).lerp(Ui.GOLD_HI, _bump_y * 0.85))

	func silver_anchor() -> Vector2:
		if Ui.SKIN == 1:
			return Vector2(364.0, 49.0)
		return Vector2(358.0, 25.0)

	func _draw() -> void:
		if font == null:
			return
		if Ui.SKIN == 1:
			_n_draw()
			return
		if _sb1 == null:
			_sb1 = StyleBoxFlat.new()
			_sb1.bg_color = Color(0.955, 0.937, 0.886, 0.92)
			_sb1.set_corner_radius_all(10)
			_sb1.border_color = Color(0.28, 0.23, 0.19, 0.35)
			_sb1.set_border_width_all(1)
			_sb2 = StyleBoxFlat.new()
			_sb2.bg_color = Color(0.965, 0.945, 0.885, 0.92)
			_sb2.set_corner_radius_all(10)
			_sb2.border_color = Color(0.72, 0.58, 0.25, 0.55)
			_sb2.set_border_width_all(1)
		# v97：整排往左挪 96 像素——用户标注把「设置」钉在**右上角**（x 0.91~1.00），
		#   原来元宝那条正好压在那儿（576~706）。挪完两条落在 334~610，正好在头像与设置之间。
		var r1 := Rect2(334, 8, 136, 34)
		draw_style_box(_sb1, r1)
		_coin(Vector2(358, 25))
		draw_string(font, Vector2(378, 31), str(silver), HORIZONTAL_ALIGNMENT_LEFT, 86, 17, Color(0.14, 0.13, 0.15, 0.92))
		var r2 := Rect2(480, 8, 130, 34)
		draw_style_box(_sb2, r2)
		_ingot(Vector2(504, 26))
		draw_string(font, Vector2(526, 31), str(yuanbao), HORIZONTAL_ALIGNMENT_LEFT, 78, 17, Color(0.14, 0.13, 0.15, 0.92))

# ---- 教学关回村：银两飞向顶栏 ----
class LootFx extends Control:
	signal all_landed
	var coins: Array = []
	var on_land := Callable()
	var _announced := false

	func start(count: int, from: Vector2, to: Vector2) -> void:
		for i in count:
			var p0 := from + Vector2(randf_range(-26.0, 26.0), randf_range(-16.0, 16.0))
			var p2 := to + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
			var p1 := Vector2((p0.x + p2.x) * 0.5 + randf_range(-90.0, 90.0),
				minf(p0.y, p2.y) - 100.0 - randf_range(0.0, 80.0))
			coins.append({"p0": p0, "p1": p1, "p2": p2, "t": -0.045 * float(i),
				"dur": 0.52 + randf_range(0.0, 0.12), "landed": false})
		queue_redraw()

	func _process(delta: float) -> void:
		if coins.is_empty():
			return
		var all := true
		for c in coins:
			c["t"] = float(c["t"]) + delta
			if float(c["t"]) >= 1.0 and not bool(c["landed"]):
				c["landed"] = true
				if on_land.is_valid():
					on_land.call()
			if not bool(c["landed"]) or float(c["t"]) < 1.05:
				all = false
		queue_redraw()
		if all and not _announced:
			_announced = true
			all_landed.emit()

	func _bez(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
		var q0 := p0.lerp(p1, t)
		var q1 := p1.lerp(p2, t)
		return q0.lerp(q1, t)

	func _draw() -> void:
		for c in coins:
			if float(c["t"]) < 0.0:
				continue
			var tt := clampf(float(c["t"]), 0.0, 1.0)
			var pos := _bez(c["p0"], c["p1"], c["p2"], tt)
			var prev := _bez(c["p0"], c["p1"], c["p2"], maxf(0.0, tt - 0.10))
			var a := 1.0 - clampf((float(c["t"]) - 0.86) / 0.16, 0.0, 1.0)
			draw_line(prev, pos, Color(0.95, 0.90, 0.70, 0.25 * a), 3.0, true)
			draw_circle(pos, 9.0, Color(0.93, 0.92, 0.94, a))
			draw_arc(pos, 9.0, 0.0, TAU, 20, Color(0.45, 0.44, 0.52, a), 1.5, true)
			draw_rect(Rect2(pos + Vector2(-3.0, -3.0), Vector2(6.0, 6.0)), Color(0.45, 0.44, 0.52, a), false, 1.5)
			draw_circle(pos + Vector2(-3.0, -3.0), 2.5, Color(1.0, 1.0, 1.0, 0.45 * a))


# ---- 挂机木牌：吊绳 + 尖尾（自绘按钮） ----
class IdlePlaque extends Button:
	var hover := false
	var down := false
	var warm := 0.9      # 0 旧木 → 1 暖木（有货/满了更暖）
	var gold := 0.0      # 金漆内衬的亮法
	const GOLD_C := Color(0.72, 0.58, 0.22)

	func _ready() -> void:
		mouse_entered.connect(_hv.bind(true))
		mouse_exited.connect(_hv.bind(false))
		button_down.connect(_dn.bind(true))
		button_up.connect(_dn.bind(false))

	func _hv(on: bool) -> void:
		hover = on
		queue_redraw()

	func _dn(on: bool) -> void:
		down = on
		queue_redraw()

	func _draw() -> void:
		# 钉 + 绳（一股绳绕上钉子，分两股吊住牌耳两孔）
		var peg := Vector2(44.0, 8.0)
		var rope := Color(0.35, 0.29, 0.22, 0.92)
		draw_line(peg, Vector2(22.0, 36.0), rope, 2.0, true)
		draw_line(peg, Vector2(66.0, 36.0), rope, 2.0, true)
		draw_arc(peg, 3.2, 0.0, TAU, 12, rope, 1.6)
		draw_circle(peg, 2.0, Color(0.24, 0.18, 0.12, 0.95))
		draw_circle(peg + Vector2(-0.7, -0.7), 0.8, Color(0.72, 0.68, 0.60, 0.55))
		# 木牌（下摆收尖）
		var dy := 2.0 if down else 0.0
		var wood: Color = Color(0.72, 0.56, 0.34, 0.99).lerp(Color(0.87, 0.71, 0.46, 0.99), warm)
		if hover:
			wood = wood.lightened(0.05)
		if down:
			wood = wood.darkened(0.07)
		var pts := PackedVector2Array([
			Vector2(8.0, 30.0 + dy), Vector2(80.0, 30.0 + dy),
			Vector2(80.0, 172.0 + dy), Vector2(44.0, 212.0 + dy), Vector2(8.0, 172.0 + dy)])
		draw_colored_polygon(pts, wood)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), Color(0.42, 0.31, 0.18, 0.90), 1.8, true)
		# 木纹 + 顶部横档 + 牌耳两孔
		for k in 3:
			var gx := 20.0 + float(k) * 24.0
			draw_line(Vector2(gx, 46.0 + dy), Vector2(gx + sin(float(k) * 2.2) * 2.2, 132.0 + dy), Color(0.52, 0.38, 0.21, 0.26), 1.0, true)
		draw_line(Vector2(10.0, 44.0 + dy), Vector2(78.0, 44.0 + dy), Color(0.52, 0.38, 0.21, 0.38), 1.2, true)
		draw_circle(Vector2(22.0, 36.0), 2.2, Color(0.30, 0.22, 0.13, 0.70))
		draw_circle(Vector2(66.0, 36.0), 2.2, Color(0.30, 0.22, 0.13, 0.70))
		# 金漆内衬（满了/有货时亮一档）
		if gold > 0.01:
			var inner := PackedVector2Array([
				Vector2(14.0, 52.0 + dy), Vector2(74.0, 52.0 + dy),
				Vector2(74.0, 168.0 + dy), Vector2(44.0, 200.0 + dy), Vector2(14.0, 168.0 + dy), Vector2(14.0, 52.0 + dy)])
			draw_polyline(inner, Color(GOLD_C.r, GOLD_C.g, GOLD_C.b, 0.30 + 0.55 * gold), 1.4 + 0.8 * gold)
		# 尾端一小红穗
		draw_line(Vector2(44.0, 210.0 + dy), Vector2(44.0, 219.0 + dy), Color(0.68, 0.15, 0.12, 0.72), 1.4, true)
		draw_circle(Vector2(44.0, 220.0 + dy), 1.8, Color(0.68, 0.15, 0.12, 0.62))

# ---- 落成动画 ----
class BuildFx extends Node2D:
	# v62（用户："感觉目前的建筑动画 可以缩减一些 太多无用的了"）：
	#   原来 1.5 秒、10 粒尘土 + 3 层尘环 + 一道金弧，起一间屋子要看足一秒半。
	#   现在 **0.7 秒、4 粒、1 层尘环**，金弧留着（那一下"落成"的准头还得有）。
	#   顺带把"落成之后等 1.6 秒再报下一条"也压到 0.8（见剧情那几处 await）。
	var life := 0.0
	var dur := 0.7
	var rng := RandomNumberGenerator.new()
	var parts: Array = []

	func setup(seed_i: int, stage_now: int) -> void:
		rng.seed = int(Time.get_ticks_msec()) + seed_i * 7919 + stage_now * 104729
		for i in 4:
			parts.append({
				"x": rng.randf_range(-26.0, 26.0),
				"y": rng.randf_range(-8.0, 6.0),
				"vx": rng.randf_range(-42.0, 42.0),
				"vy": rng.randf_range(-120.0, -46.0),
				"s": rng.randf_range(3.0, 7.0),
			})

	func _process(delta: float) -> void:
		life += delta
		if life >= dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := clampf(life / dur, 0.0, 1.0)
		draw_circle(Vector2(0, -10.0 - 26.0 * t), 26.0 + 64.0 * t, Color(0.62, 0.58, 0.50, maxf(0.0, (1.0 - t) * 0.20)))
		draw_arc(Vector2(0, -14.0), 18.0 + 60.0 * t, 0.0, TAU, 24, Color(0.86, 0.70, 0.30, (1.0 - t) * 0.5), 3.0)
		for p in parts:
			var px := float(p["x"]) + float(p["vx"]) * life
			var py := float(p["y"]) + float(p["vy"]) * life + 150.0 * life * life
			var s := float(p["s"]) * (1.0 - t * 0.4)
			draw_rect(Rect2(px - s * 0.5, py - s * 0.5, s, maxf(1.5, s * 0.4)), Color(0.45, 0.34, 0.24, (1.0 - t) * 0.9))

# ---- 顶层罩子（剧情场景 + 立绘） ----
class TopVeil extends Node2D:
	var host = null
	var font: Font = null

	func _process(_delta: float) -> void:
		queue_redraw()

		# v92（用户："程序的画和图都堆在一起"）：**村里的同伴改成 Q版立绘**。
	#   这里原来是 Draw/_person 画的火柴人——旁边就是 AI 出的水墨房子，落差太大。
	#   缺图返回 false，调用方原样退回火柴人（不会开天窗）。
	func _q_figure(rid: String, cx: float, gy: float, bob: float, h: float) -> bool:
		var tex := CharArt.q(rid)
		if tex == null:
			return false
		var w: float = h * float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		draw_texture_rect(tex, Rect2(cx - w * 0.5, gy - h - bob, w, h), false, Color(1, 1, 1, 1))
		return true

	func _person(sx: float, gy: float, col: Color, spear: bool, bob: float, arm: float) -> void:
		draw_circle(Vector2(sx, gy - 86.0 - bob), 9.0, col)
		draw_line(Vector2(sx, gy - 77.0 - bob), Vector2(sx, gy - 40.0 - bob * 0.5), col, 3.0)
		draw_line(Vector2(sx, gy - 40.0 - bob * 0.5), Vector2(sx - 12.0, gy), col, 3.0)
		draw_line(Vector2(sx, gy - 40.0 - bob * 0.5), Vector2(sx + 12.0, gy), col, 3.0)
		draw_line(Vector2(sx, gy - 68.0 - bob), Vector2(sx - 16.0 - arm * 6.0, gy - 50.0 - bob), col, 3.0)
		draw_line(Vector2(sx, gy - 68.0 - bob), Vector2(sx + 16.0 + arm * 6.0, gy - 50.0 - bob), col, 3.0)
		if spear:
			draw_line(Vector2(sx + 26.0 + arm * 1.5, gy - 104.0 - bob), Vector2(sx - 10.0, gy + 2.0), col, 3.0)

	func _pine(x: float, base: float, s: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(x, base - 64.0 * s), Vector2(x - 26.0 * s, base), Vector2(x + 26.0 * s, base)]), col)
		draw_rect(Rect2(x - 3.0 * s, base - 4.0, 6.0 * s, 16.0), Color(0.24, 0.18, 0.12, 0.9))

	func _fox(x: float, y: float, s: float) -> void:
		var body := Color(0.965, 0.950, 0.915, 0.98)
		var inkc := Color(0.30, 0.27, 0.28, 0.95)
		var bob := sin(float(host._t) * 3.0) * 2.0 * s
		draw_circle(Vector2(x - 8.0 * s, y - 12.0 * s + bob * 0.3), 11.0 * s, body)
		draw_circle(Vector2(x + 12.0 * s, y - 22.0 * s + bob), 9.0 * s, body)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 6.0 * s, y - 30.0 * s + bob), Vector2(x + 10.0 * s, y - 40.0 * s + bob), Vector2(x + 14.0 * s, y - 29.0 * s + bob)]), body)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 16.0 * s, y - 29.0 * s + bob), Vector2(x + 20.0 * s, y - 38.0 * s + bob), Vector2(x + 23.0 * s, y - 27.0 * s + bob)]), body)
		draw_arc(Vector2(x - 20.0 * s, y - 16.0 * s + bob * 0.5), 12.0 * s, PI * 0.8, PI * 1.5, 10, body, 5.0 * s)
		draw_circle(Vector2(x + 15.0 * s, y - 23.0 * s + bob), 1.4 * s, inkc)
		draw_circle(Vector2(x + 20.0 * s, y - 19.0 * s + bob), 1.2 * s, inkc)

	func _scene(kind: String) -> void:
		var tt := float(host._t)
		var base := 402.0
		match kind:
			"backhill":
				draw_colored_polygon(PackedVector2Array([Vector2(40, base), Vector2(210, 252), Vector2(400, base)]), Color(0.14, 0.18, 0.14, 0.92))
				draw_colored_polygon(PackedVector2Array([Vector2(320, base), Vector2(500, 236), Vector2(680, base)]), Color(0.11, 0.15, 0.12, 0.95))
				draw_line(Vector2(30, base), Vector2(690, base), Color(0.22, 0.27, 0.20, 0.85), 3.0)
				for i in 4:
					_pine(120.0 + float(i) * 150.0, base, 0.8 + float(i % 2) * 0.25, Color(0.10, 0.16, 0.11, 0.95))
				_fox(520.0 + sin(tt * 0.9) * 26.0, base, 1.0)
			"cave":
				draw_colored_polygon(PackedVector2Array([Vector2(100, 402), Vector2(120, 180), Vector2(300, 150), Vector2(420, 150), Vector2(600, 180), Vector2(620, 402)]), Color(0.13, 0.12, 0.11, 0.95))
				draw_circle(Vector2(360, 402), 150.0, Color(0.08, 0.07, 0.07, 0.98))
				var glow := 0.5 + 0.5 * sin(tt * 1.6)
				for i in 4:
					draw_circle(Vector2(360, 386), 36.0 + float(i) * 22.0, Color(0.85, 0.63, 0.30, 0.05 + 0.03 * glow))
				draw_circle(Vector2(360, 386), 22.0 + 3.0 * glow, Color(0.90, 0.68, 0.34, 0.35 + 0.2 * glow))
				draw_rect(Rect2(320, 372, 80, 30), Color(0.22, 0.20, 0.18, 0.98))
				draw_circle(Vector2(360, 360), 17.0, Color(0.30, 0.26, 0.22, 0.98))
				draw_rect(Rect2(352, 336, 16, 12), Color(0.30, 0.26, 0.22, 0.98))
				draw_arc(Vector2(355, 356), 5.0, PI, TAU, 8, Color(0.55, 0.48, 0.36, 0.9), 2.0)
			"map":
				draw_colored_polygon(PackedVector2Array([Vector2(150, 152), Vector2(568, 158), Vector2(574, 400), Vector2(146, 394)]), Color(0.87, 0.81, 0.61, 0.97))
				draw_polyline(PackedVector2Array([Vector2(150, 152), Vector2(568, 158), Vector2(574, 400), Vector2(146, 394), Vector2(150, 152)]), Color(0.42, 0.34, 0.22, 0.7), 2.0)
				draw_line(Vector2(360, 155), Vector2(358, 397), Color(0.55, 0.46, 0.30, 0.35), 1.5)
				var route := PackedVector2Array([Vector2(200, 330), Vector2(280, 300), Vector2(320, 240), Vector2(420, 226), Vector2(470, 292)])
				draw_polyline(route, Color(0.66, 0.20, 0.14, 0.85), 3.0)
				draw_line(Vector2(462, 284), Vector2(478, 300), Color(0.66, 0.20, 0.14, 0.9), 3.0)
				draw_line(Vector2(478, 284), Vector2(462, 300), Color(0.66, 0.20, 0.14, 0.9), 3.0)
				draw_rect(Rect2(500, 350, 44, 30), Color(0.72, 0.20, 0.15, 0.75))
			"herb":
				draw_rect(Rect2(170, 356, 380, 46), Color(0.40, 0.30, 0.20, 0.96))
				draw_line(Vector2(170, 356), Vector2(550, 356), Color(0.28, 0.20, 0.13, 0.9), 2.0)
				draw_line(Vector2(250, 356), Vector2(250, 300), Color(0.30, 0.34, 0.24, 0.95), 3.0)
				for i in 3:
					draw_circle(Vector2(232.0 + float(i) * 18.0, 296.0 + float(i % 2) * 8.0), 13.0, Color(0.45, 0.31, 0.55, 0.95))
				draw_line(Vector2(360, 356), Vector2(360, 286), Color(0.42, 0.50, 0.34, 0.95), 3.0)
				draw_colored_polygon(PackedVector2Array([Vector2(344, 302), Vector2(360, 336), Vector2(376, 302)]), Color(0.86, 0.86, 0.80, 0.95))
				draw_line(Vector2(352, 316), Vector2(340, 330), Color(0.86, 0.86, 0.80, 0.9), 2.0)
				draw_line(Vector2(368, 316), Vector2(380, 330), Color(0.86, 0.86, 0.80, 0.9), 2.0)
				draw_line(Vector2(470, 356), Vector2(470, 306), Color(0.30, 0.34, 0.24, 0.95), 3.0)
				for i2 in 3:
					draw_circle(Vector2(456.0 + float(i2) * 14.0, 300.0 - float(i2 % 2) * 10.0), 10.0, Color(0.74, 0.20, 0.16, 0.95))
			"qingluan":
				draw_colored_polygon(PackedVector2Array([Vector2(60, 402), Vector2(180, 240), Vector2(360, 402)]), Color(0.15, 0.13, 0.19, 0.9))
				draw_colored_polygon(PackedVector2Array([Vector2(300, 402), Vector2(470, 220), Vector2(660, 402)]), Color(0.12, 0.10, 0.16, 0.95))
				draw_line(Vector2(40, 402), Vector2(680, 402), Color(0.24, 0.20, 0.26, 0.85), 3.0)
				var bob := sin(tt * 2.0) * 2.0
				_person(300.0, base, Color(0.16, 0.15, 0.17, 0.78), false, bob, sin(tt * 2.0 + 1.0) * 0.5)
				_person(440.0, base, Color(0.24, 0.17, 0.26, 0.80), false, -bob, sin(tt * 2.0 + 2.0) * 0.5)
				draw_line(Vector2(418, 316), Vector2(452, 350), Color(0.72, 0.72, 0.78, 0.55), 3.0)
				var spark := 0.5 + 0.5 * sin(tt * 3.0)
				draw_circle(Vector2(452, 314), 4.0 + 2.0 * spark, Color(0.95, 0.84, 0.45, 0.5 + 0.4 * spark))
			_:
				pass

	func _draw() -> void:
		if host == null:
			return
		var story := int(host._story_page)
		var panel_open: bool = host._any_panel_open()
		if story < 0 and not panel_open:
			if host._out_vis():
				var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 360.0)
				var cy := 640.0 + sin(float(Time.get_ticks_msec()) / 300.0) * 9.0
				var r := Rect2(14, cy - 86.0, 96, 172)
				draw_rect(Rect2(r.position - Vector2(10, 10), r.size + Vector2(20, 20)), Color(0.95, 0.83, 0.45, 0.10 + 0.14 * pulse))
				draw_rect(r, Color(0.955, 0.937, 0.886, 0.96))
				draw_rect(r, Color(0.68, 0.15, 0.12, 0.30 + 0.45 * pulse), false, 2.0)
				if font != null:
					var ink_o := Color(0.14, 0.13, 0.15, 0.92)
					draw_string(font, Vector2(r.position.x, r.position.y + 72.0), "出", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, ink_o)
					draw_string(font, Vector2(r.position.x, r.position.y + 128.0), "村", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, ink_o)
			if font != null:
				var ink2 := Color(0.14, 0.13, 0.15)
				# v93：**人交给村景层画**（那边有走/待机/干活的状态机，还会跟着卷轴缩放）；
				#   这里只剩名字标签，位置每帧问图层要（villager_pos 返回世界坐标）。
				if host._chen_visible():
					var vp: Vector2 = host._village.villager_pos("chen_shi")
					var csx: float = vp.x - float(host._cam)
					if vp.x > 0.0 and csx > -80.0 and csx < 800.0:
						draw_string(font, Vector2(csx - 40.0, host._sy(vp.y) - 100.0), "陈石", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 13, Color(ink2.r, ink2.g, ink2.b, 0.70))
				if host._qingluan_visible():
					var vq: Vector2 = host._village.villager_pos("qingluan")
					var qx: float = vq.x - float(host._cam)
					if vq.x > 0.0 and qx > -80.0 and qx < 800.0:
						draw_string(font, Vector2(qx - 40.0, host._sy(vq.y) - 100.0), "苏青鸾", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 13, Color(ink2.r, ink2.g, ink2.b, 0.70))
				# v93：主角（少侠）现在由村景层的 NPC 系统画——他会在石桌/路口之间走动
				var vh: Vector2 = host._village.villager_pos("player")
				var hsx: float = vh.x - float(host._cam)
				if vh.x > 0.0 and hsx > -60.0 and hsx < 780.0:
					draw_string(font, Vector2(hsx - 40.0, host._sy(vh.y) - 100.0), "少侠", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 13, Color(ink2.r, ink2.g, ink2.b, 0.60))
		if not host._disciple_ready() and not panel_open and story < 0 and host._tag_unlocked(1) and (host._tag_rects[1] as Rect2).size.x > 0.0:
			var rc: Rect2 = host._tag_rects[1]
			draw_rect(rc, Color(0.09, 0.07, 0.06, 0.40))
		if story < 0:
			return
		draw_rect(Rect2(-60, -60, 840, 1400), Color(0.07, 0.06, 0.06, 0.62))
		_scene(str(host._story_kind))
		var r2 := Rect2(70, 410, 580, 420)
		draw_rect(Rect2(r2.position + Vector2(4, 6), r2.size), Color(0.06, 0.05, 0.05, 0.35))
		draw_rect(r2, Color(0.955, 0.937, 0.886, 0.98))
		draw_rect(r2, Color(0.28, 0.23, 0.19, 0.55), false, 2.0)
		if font == null:
			return
		var ink := Color(0.14, 0.13, 0.15)
		draw_string(font, Vector2(r2.position.x, r2.position.y + 62.0), host._story_title(), HORIZONTAL_ALIGNMENT_CENTER, r2.size.x, 30, Color(ink.r, ink.g, ink.b, 0.75))
		draw_line(Vector2(r2.position.x + 40.0, r2.position.y + 84.0), Vector2(r2.end.x - 40.0, r2.position.y + 84.0), Color(ink.r, ink.g, ink.b, 0.18), 1.2)
		var page: Array = host._story_pages()[story]
		var y := r2.position.y + 136.0
		for line in page:
			draw_string(font, Vector2(r2.position.x + 24.0, y), str(line), HORIZONTAL_ALIGNMENT_CENTER, r2.size.x - 48.0, 22, Color(ink.r, ink.g, ink.b, 0.92))
			y += 46.0
		draw_string(font, Vector2(r2.position.x + 24.0, r2.end.y - 34.0), host._story_tip(), HORIZONTAL_ALIGNMENT_CENTER, r2.size.x - 48.0, 16, Color(ink.r, ink.g, ink.b, 0.55))

func _ready() -> void:
	# v221：全界面按钮统一点击音——新加的 Button 自动挂，不用每个面板各写一遍
	get_tree().node_added.connect(_on_node_added)
	Audio.play_bgm(Audio.menu_track())   # v72：主界面曲目由玩家在设置里选（默认"江南"）
	_start_ambient.call_deferred()       # v230：等根节点/音频就绪后再起风
	# v83：引子走完回村时，弹一次起名（隔一帧等界面铺好；已起过名就不会再弹）
	call_deferred("_maybe_ask_name")
	InkTouch.attach()            # v65：点击水墨扩散
	FadeIn.attach()              # v68：进场淡入
	GameState.load_game()   # 优化批㉒：先进游戏先读全局档（只读一次）
	# 老档兼容：引子已经走通的，百工坊直接开；否则旧玩家会永远卡在「没起屋」。
	if GameState.first_journey_done:
		var _unlock_done := false
		if not GameState.cave_opened:
			GameState.cave_opened = true
			_unlock_done = true
		if not GameState.winery_built:
			GameState.winery_built = true
			_unlock_done = true
		if _unlock_done:
			GameState.save_game()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = Draw.pick_font(get_theme_default_font())
	_layout_tags()
	if SCROLL_OFF:
		_sc = 0.0
		_demo_done = true
		_cam = Conf.OPEN_CAM
		_hint_used = true
	_scroll = ScrollLayer.new()
	_village = VillageLayer.new()
	_mount = MountLayer.new()
	_hud = HudLayer.new()
	# v96（用户：主界面改用摆景器排的那一版 + "之前原场景三个移动小人就不要了"）：
	#   ① 最底先铺**水墨村景层**（读 village_layout.json；自带动效与画框裁剪）；
	#   ② 纸偶演员层用一个开关关掉（代码保留，随时切回）。
	if USE_INK_SCENE:
		if INK_ONLY:
			# v98（用户："画卷怎么没把主场景装进去"）——**村景页现在也装进画卷里了**：
			#   ① 桌面：画卷之外那一圈底色（老主界面也是这么铺的）；
			#   ② 画心：村景页**裁到装裱以内那一条**（y 26~1150），纸外露出桌面；
			#   ③ 装裱（包边/木轴/卷口/隔水/引首）由 menu_mount 画在上面（见下面 _mount）。
			_desk_bg = ColorRect.new()
			_desk_bg.name = "桌面"
			_desk_bg.color = Conf.DESK_C
			_desk_bg.size = Vector2(Conf.DW, Conf.DH)
			_desk_bg.z_index = -200
			_desk_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_desk_bg)
			_ink_clip = Control.new()
			_ink_clip.name = "画心"
			_ink_clip.clip_contents = true
			_ink_clip.position = Vector2(0.0, Conf.BAND_TOP)
			_ink_clip.size = Vector2(Conf.DW, Conf.BAND_H)
			_ink_clip.z_index = -100
			_ink_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_ink_clip)
			if USE_VIDEO_SCENE:
				# 动态画铺满整条画心（视频本来就是 720×1124，跟画心一比一）
				_video = VideoStreamPlayer.new()
				_video.name = "动态画"
				_video.stream = load(VIDEO_SCENE)
				_video.expand = true
				_video.loop = true
				_video.size = Vector2(Conf.DW, Conf.BAND_H)
				_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_ink_clip.add_child(_video)
				_video.play()
				print("[主界面] 动态画：", VIDEO_SCENE, " 载入=", _video.stream != null)
			else:
				_ink = InkScene.new()
				_ink_clip.add_child(_ink)
				_ink.position = Vector2(0.0, -Conf.BAND_TOP)
			# 封面页：一张与画心同高的纸（引首/隔水/包边由装裱层画在上面）
			_cover_win = Control.new()
			_cover_win.name = "封面页"
			_cover_win.clip_contents = true
			_cover_win.size = Vector2(Conf.DW, Conf.DH)
			_cover_win.z_index = -100
			_cover_win.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_cover_win)
			var cbg := ColorRect.new()
			cbg.name = "封面纸底"
			cbg.color = Conf.PAPER
			cbg.position = Vector2(0.0, Conf.BAND_TOP)
			cbg.size = Vector2(Conf.DW, Conf.BAND_H)
			cbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_cover_win.add_child(cbg)
			if SCROLL_OFF:
				_cover_win.visible = false
		else:
			_ink = InkScene.new()
			add_child(_ink)
	add_child(_scroll)
	add_child(_village)
	# v93g（用户："你是不是应该把画面分层？"）：**人物单独一层**。
	#   原来骨骼是塞在村景层里的——村景层为了让画心铺满竖屏用了**非等比**缩放（sy=1.6625），
	#   人物跟着被拉、被推，还跟面板抢 z 序。现在：村景 → **人物** → 远山 → 特效 → HUD → 记号 → 面板，
	#   人物层等比、开面板就整层藏起来（"点其他界面他还会出现"一并解决）。
	if USE_PAPER_ACTORS:
		_actors = Node2D.new()
		add_child(_actors)
		_village.actor_layer = _actors
	if INK_ONLY:
		# v98：装裱层现在**横跨整幅画卷**（两页都在它里面）——包边/木轴/卷口/隔水/引首全归它画，
		#   位置跟"卷位 V"走（见 _apply_layer_transforms）。
		#   z=-40：压在画心与封面纸之上（村景的件是 -95~-47），又在所有 UI（z=0）之下。
		_mount.z_index = -40
		# v98b：封面页的左半边＝**卷首题记**（六列竖排＋两方印），右边接隔水与《少年游》引首。
		#   老版这里放的是"村子尾巴"，村景换成摆景器那一版之后就成了空纸——现在补上题记。
		_mount.show_weiba = true
		# ⚠ 左边留 60 像素：封面页左边是**卷口**（roll_l≈54px），题记压在那儿会被卷纸盖掉
		_mount.weiba_x = Conf.OPEN_CAM + 60.0               # 2340
		_mount.weiba_w = Conf.YINSHOU_X0 - 30.0 - _mount.weiba_x   # 到隔水为止（2670-2340=330）
		add_child(_mount)
		if SCROLL_OFF:
			_mount.visible = false
	else:
		add_child(_mount)
	# v231：画心雾气/金尘——夹在画心（z -100）与装裱（z -40）之间，不吃鼠标
	var mist_clip := Control.new()
	mist_clip.position = Vector2(0.0, Conf.BAND_TOP)
	mist_clip.size = Vector2(Conf.DW, Conf.BAND_H)
	mist_clip.clip_contents = true
	mist_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist_clip.z_index = -50
	add_child(mist_clip)
	_mist = MistLayer.new()
	mist_clip.add_child(_mist)
	_fx_root = Node2D.new()
	add_child(_fx_root)
	add_child(_hud)
	# v97：收起旧的两层画（见文件头 INK_ONLY 的注）
	if INK_ONLY:
		_scroll.visible = false
		_village.visible = false
		_fx_root.visible = false
		# ⚠ _mount 不在这儿收：v98 起它是"封面页"的主角（已挂进 _cover_win）
	_mount.font = _font
	_hud.font = _font
	_hud.host = self
	_marks_root = Control.new()
	_marks_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks_root)
	# v92 修（用户："设置在打开角色界面还在"）：**「设置」按钮挪到面板之前建**。
	#   以前它建在 32 个面板**后面**（下面那行 v72 的老注释），Control 是后加的盖在上面，
	#   于是开任何面板时它都浮在面板与遮罩之上（截图：弟子面板右上角那个"设置"）。
	#   挪到这里＝压在所有面板与遮罩之下，面板一开就被盖住，跟挂机牌/币值条一个待遇。
	#   ⚠ 位置照旧（628,58）：只在最外层、没有面板时才点得到。
	var set_btn := UiKit.make_button(self, Vector2(628, 58), Vector2(76, 40), "设 置", 17)
	set_btn.pressed.connect(_open_settings)
	_set_btn = set_btn
	_build_idle_plaque()
	# v97：牌子层（用户标注的 11 处锚点）。建在**面板之前**——一开面板就被盖住，
	#   跟旧的记号牌/挂机牌一个待遇（v92 那条"设置浮在角色界面上"的教训）。
	_build_plaques()
	# v211：银两/元宝建在**牌子层之后**——顶栏墨带在牌子层里画，先建就被压暗了（这次踩过）
	_money_hud = MoneyHud.new()
	_money_hud.font = _font
	_money_hud.silver = GameState.coin("silver")
	_money_hud.yuanbao = GameState.coin("yuanbao")
	add_child(_money_hud)
	if INK_ONLY:
		# 旧的挂机牌与「设置」按钮由牌子层接管（**只隐藏，不删**：改回 false 原样回来）
		_idle_btn.visible = false
		_set_btn.visible = false
	_add_mark("wa", 898.0, 728.0, "瓦房", "")
	_add_mark("zhu", 1215.0, 726.0, "竹屋", "行囊 · 仓库")
	_add_mark("stone", 1393.0, 778.0, "石桌", "")
	_add_mark("gate", 1560.0, 586.0, "山门", "")
	_add_mark("hill", 660.0, 700.0, "后山", "")
	_add_mark("treasure", 2140.0, 792.0, "藏宝阁", "")
	_add_mark("cave", 470.0, 712.0, "山洞", "")
	_add_mark("shop", 1720.0, 852.0, "货栈", "")
	# v50：品酒坊 / 炼丹阁 / 鉴宝行 **合成一间「百工坊」**（用户："统一集中到一个建筑物"）
	#   记号只留这一个；里面三块牌子各管一间（见 menu/craft_panel.gd）。
	_add_mark("craft", 1880.0, 794.0, "百工坊", "")
	_char_panel = CharacterPanel.new()
	add_child(_char_panel)
	_char_panel.closed.connect(_on_char_closed)
	_char_panel.guide_finished.connect(_seg4_guide_done)
	_warehouse = WarehousePanel.new()
	add_child(_warehouse)
	_warehouse.closed.connect(_on_warehouse_closed)
	_char_panel.bind_warehouse(_warehouse)
	_char_panel.forge_pressed.connect(_open_star_page)
	_out_panel = OutPanel.new()
	add_child(_out_panel)
	_out_panel.challenge.connect(_on_challenge)
	_out_panel.config_pressed.connect(_on_out_config)
	_out_panel.chase_manual.connect(_on_chase_manual)   # v129：追剿·手牌模式（kushou）
	_out_panel.chase_auto.connect(_on_chase_auto)       # v129：追剿·自动战斗（battle_lite）
	_out_panel.chase_bg_off.connect(_on_chase_bg_off)   # v143：在村里把"后台推进"停掉
	_out_panel.chase_challenge.connect(_on_chase_challenge)   # v144：追剿关卡列表里的［挑战］
	# v36：宝箱面板——出村屏右上角［宝箱］开它；v4.2 底排第 5 格也开它
	_chest_panel = ChestPanel.new()
	add_child(_chest_panel)
	_out_panel.chest_pressed.connect(_open_chests)
	_chest_panel.closed.connect(_on_chest_closed)
	_formation = FormationPanel.new()
	add_child(_formation)
	_formation.confirmed.connect(_on_form_ok)
	_formation.saved.connect(_on_form_saved)
	_formation.cancelled.connect(_on_form_cancel)
	# ============================================================
	# v56 修：**漏实例化了**——`_craft_panel` 只声明、没 new 过，于是点村里的
	#   「百工坊」记号时 `_craft_panel.open()` 打在 null 上，运行时报
	#   "Invalid call. Nonexistent function 'open' in base 'Nil'"
	#   （栈帧：menu_sketch.gd 的 _click_craft ← _on_mark）。
	#   ⚠ 顺序有讲究：它必须排在三个作坊面板**前面**（先加的在下面），
	#     这样从门厅点进品酒/炼丹/鉴宝时，作坊面板画在门厅**上面**，
	#     关掉作坊又能回到门厅（门厅留着不关，正是这个用处）。
	# ============================================================
	# v72：右上角「设置」按钮 —— v92 已挪到上面（面板之前建，好被面板盖住），此处只留位置说明。
	_craft_panel = CraftPanel.new()
	add_child(_craft_panel)
	_craft_panel.room_pressed.connect(_on_craft_room)
	_winery_panel = WinePanel.new()
	add_child(_winery_panel)
	_alchemy_panel = AlchemyPanel.new()
	add_child(_alchemy_panel)
	_forge_panel = ForgePanel.new()
	add_child(_forge_panel)
	_forge_panel.closed.connect(_on_forge_closed)
	_star_panel = StarPanel.new()
	add_child(_star_panel)
	_star_panel.closed.connect(_on_star_closed)
	# v39：鉴宝行面板（400 关剧情后村里出记号）
	_appraise_panel = AppraisePanel.new()
	add_child(_appraise_panel)
	_pet_panel = PetPanel.new()
	add_child(_pet_panel)
	_shop_panel = ShopPanel.new()
	add_child(_shop_panel)
	_depart = JourneyDepart.new()
	add_child(_depart)
	_depart.deploy_started.connect(_on_deploy_started)
	_veil = TopVeil.new()
	_veil.host = self
	_veil.font = _font
	add_child(_veil)
	_apply_layer_transforms()
	_tag_notice = 1 if GameState.disciple_joined else -1
	if GameState.first_journey_done and not GameState.disciple_joined:
		_story_kind = "intro"
		_story_page = 0
	elif GameState.stage_progress >= MAP_STAGE and not GameState.map_found:
		_story_kind = "map"
		_story_page = 0
	elif GameState.stage_progress >= NVXIA_STAGE and not GameState.qingluan_joined:
		_story_kind = "qingluan"
		_story_page = 0
	elif GameState.stage_progress >= HERB_STAGE and not GameState.herbs_granted:
		_story_kind = "herb"
		_story_page = 0
	elif GameState.stage_progress >= JIANBAO_STAGE and not GameState.jianbao_ok():
		_story_kind = "jianbao"   # v39：老档也会按顺序补放（打完 400 关没看过就补）
		_story_page = 0
	var added := GameState.idle_load()
	if added >= 60:
		# v97：木牌挪到头像下方了（用户标注 x 0.23），措辞跟着改，别再写"左上角"
		var im := "挂机池 +" + _fmt_min(added / 60) + "——点「挂机」木牌收取"
		print("[主界面] 挂机：补入 ", added, " 秒，池内 ", GameState.idle_pool_min(), " 分")
		if _story_page < 0:
			_show_toast(im, 3.0)
	else:
		print("[主界面] 挂机：池内 ", GameState.idle_pool_min(), " 分（本次补入 ", added, " 秒）")
	_refresh_idle_btn()
	_init_season()
	var note := GameState.take_pending_note()
	# ㊿v：兜底把"出征时自动卸下的随身之物"穿回去。
	#   正常路上回村那三条道（结算/折返/殒命）已经穿过了；这里管的是
	#   "上趟没走完就关游戏、盘上又没留下可续的档"——那趟没了，随身之物不能跟着丢在仓库里。
	#   ⚠ 盘上还有可续的档时**不许动**：玩家随时可能接着走那一趟。
	if JourneySave.read_save().is_empty():
		var back := GameState.strip_restore()
		if back != "":
			print("[主界面] ", back)
			if note == "":
				note = back
	if note != "" and _story_page < 0:
		_show_toast(note)
	# ㊵：离线爬塔的播报——池子那条更急，所以爬塔这条排在它后面报（同一套 toast）
	var onote := GameState.take_offline_note()
	if onote != "":
		print("[主界面] ", onote)
		if _story_page < 0:
			_show_toast(onote, 4.0)
	# ㊿f：进主界面就落一次盘——不等 20 秒兜底、不赌退场那一笔（每进一次都算）
	GameState.save_game()
	print("[主界面] 进村即落盘：首趟=", GameState.first_journey_done, " 弟子=", GameState.disciple_joined)
	Tuning.describe()   # ㉘：报一下这次是拿哪份调参配置在跑
	# v56：删掉三个没人用的局部变量（编辑器里那三条 UNUSED_VARIABLE 告警：`o` / `zsx` / `sg`）——
	#   都是早期版本留下的残料（`zsx` 算的是"隐身记号"的屏幕 x，后来那条路改了，就没人读了）。
	#   ⚠ `o` 只被 `zsx` 那一行用到，所以这两行**必须一起删**：只删一半，`o` 就变成新的未用变量。
	var z := _zoom()
	print("[主界面] v27 窗口=", size, " 缩放=", z, " 卷长=", int(Conf.STRIP_W), " 纵向拉伸=", Draw.sy())
	print("[主界面] v27：历练先过出征屏（首趟仍走引子）· 后山二遭可收青隼（先狐后隼）· K 键重播整条宠链")
	print("[主界面] 挂机档位：第 ", GameState.idle_tier() + 1, " 档 · ", GameState.idle_rate_text())
	print("[主界面] 账本：灵草=", GameState.material_count("zhi"), "/", GameState.material_count("shen"), "/", GameState.material_count("guo"), " 宠料=", GameState.material_count("bone"), "/", GameState.material_count("rice"), " 弟子=", GameState.disciple_joined, " 青鸾=", GameState.qingluan_joined, " 宠物=", GameState.pet_id, " 阶=", GameState.pet_stage(), " 关卡=", GameState.stage_progress, "/", GameState.STAGE_MAX, " 自动=", GameState.auto_climb, " 阵容=", GameState.formation, " 货币=", GameState.coin_line())
	print("[主界面] 测试键：F 出战配置 · I 入门 · K 后山 · M 仓库货 · T 挂机+1时 · Y 挂机灌满 · G 建筑链+炼丹 · H 酒 · C 炼丹料 · V 炉火快进 · X 推到满关 · W 窗口 · P 宠物 · Q 女侠 · N 下一季 · O 导出调参配置 · J 存档版本自检 · Z 剑胚+锻造石")
	print("[主界面] 测试键（数字，v42）：0 进度归零 · 1→49关 · 2→149关 · 3→299关 · 4→399关(鉴宝行) · 5→499关 · 6 进度+25 · 7 进度-25 · 8 发新手礼包 · 9 直接开鉴宝行")
	# ㊿p（B 案）：新档开机——不进村，直接进引子（十六岁·五问；走到结算回村为止）
	#   只认"首趟未走通"；首趟走过一次后这条路自动关闭（first_journey_done=true）。
	#   半途退出的档：游历场自带续行，会接在断点，不重答五问。
	if BOOT_INTO_INTRO and not GameState.first_journey_done:
		print("[主界面] 新档开机——直接进引子（首趟未走通）→ menu/prologue.tscn")
		_boot_journey.call_deferred()
		return
	# 引子回来：第二段（铁匠）开始前先问「是否跳过引导剧情？」
	if GameState.first_journey_done and not GameState.forge_tut_done:
		_seg2_loot = 50
		_ask_skip_segment.call_deferred(2, _seg2_play, _seg2_skip)

func _boot_journey() -> void:
	var err := get_tree().change_scene_to_file("res://menu/prologue.tscn")
	if err != OK:
		print("[主界面] 进引子失败，错误码=", err, "；检查路径：", Conf.JOURNEY_SCENE)

# ---- 挂机木牌 ----

func _panel_label(txt: String, fs: int, col: Color) -> Label:
	var lb := Label.new()
	lb.text = txt
	lb.add_theme_font_size_override("font_size", fs)
	lb.add_theme_color_override("font_color", col)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lb

func _build_idle_plaque() -> void:
	_idle_btn = IdlePlaque.new()
	_idle_btn.position = Vector2(14, 16)
	_idle_btn.size = Vector2(88, 212)
	_idle_btn.focus_mode = Control.FOCUS_NONE
	_idle_btn.pivot_offset = Vector2(44, 8)   # 钉子处为轴——绳吊着轻轻摆
	_idle_btn.pressed.connect(_on_idle_collect)
	add_child(_idle_btn)
	_idle_t_lb = _panel_label("挂\n机", 26, Color(0.14, 0.13, 0.15, 0.94))
	_idle_t_lb.position = Vector2(0, 38)
	_idle_t_lb.size = Vector2(88, 72)
	_idle_btn.add_child(_idle_t_lb)
	_idle_time_lb = _panel_label("", 13, Color(0.14, 0.13, 0.15, 0.75))
	_idle_time_lb.position = Vector2(2, 112)
	_idle_time_lb.size = Vector2(84, 36)
	_idle_time_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_idle_btn.add_child(_idle_time_lb)
	_idle_act_lb = _panel_label("", 16, Color(0.42, 0.40, 0.38))
	_idle_act_lb.position = Vector2(0, 148)
	_idle_act_lb.size = Vector2(88, 24)
	_idle_btn.add_child(_idle_act_lb)

# ============================================================
# v97：主界面牌子层（用户 2026-10-08 标注的 11 处锚点 + 两处原有功能）
#
#   位置全部写成**占屏比例**（0~1），跟 docs/主界面布局_用户标注.md 那张表一行对一行。
#   每个牌子都接到**原来那个函数**上——牌子只是换了样子与位置，功能一个不丢：
#     头像/名号 → 角色面板 · 挂机 → 收菜 · 设置 → 设置面板 · 商店 → 货栈
#     山洞 → 山洞 · 后山 → 后山 · 出村 → 出村面板 · 百工坊 → 门厅 · 藏宝阁 → 藏宝阁
#   「江湖」那块用户已明确：**只显示玩家 ID**，不要题头（见标注文档"已定"一节）。
# ============================================================
func _build_plaques() -> void:
	_plaques = PlaqueLayer.new()
	_plaques.font = _font
	add_child(_plaques)
	var pn := _player_tag()
	# ===== v211 顶栏（0~96 一条贯通墨带）=====
	#   头像 64 · 名号（左对齐 + 下面一块境界牌）· 进阶小牌 · 银两/元宝（MoneyHud）· 设置小牌
	_plaques.add_disc("avatar", 0.086, 0.0375, "", _open_char_panel, "", {"w": 64.0})
	_plaques.add_txt("name", 0.239, 0.0383, pn, _open_char_panel, _grade_label(), {"w": 140.0, "h": 76.0})
	_plaques.add_chip("advance", 0.403, 0.0383, "进阶", _open_advance, _advance_hint(), {"w": 80.0, "h": 34.0})
	_plaques.add_chip("settings", 0.9264, 0.0375, "设置", _open_settings, "", {"w": 58.0, "h": 34.0})
	# 挂机：还是从横梁上吊下来（这块是"画上的题字"，保留竖排毛笔）
	# v240（用户："挂机和建设上面的横栏 完全放在头像下面"）：
	#   横梁从画面中央（128~292）搬到左上头像下面（14~204），木牌跟着下来；
	#   画面中上留白，不再被梁和绳子切一道。
	_plaques.add_beam("beam", 14.0, 120.0, 122.0, [60.0])   # 装饰件：没有命中盒，不挡拖卷（v242：只剩挂机一块）
	_plaques.add_hang("idle", 0.083, 0.0, "挂机", _on_idle_collect, "", "", {"hang_y": 122.0})
	# ===== v211 右侧功能栏：5 个**等宽格**（金刻线图标 + 大号毛笔字 + 小字名）=====
	#   y 只是初始值；_refresh_plaques 末尾按"当前可见的格子"重排（隐藏一格，下面自动补位）。
	_plaques.add_rail("shop", 0.905, 0.192, "栈", "商店", PlaqueLayer.RAIL_SHOP_TEX, _open_shop, "换材料")
	_plaques.add_rail("kushou_test", 0.905, 0.342, "兽", "困兽", PlaqueLayer.RAIL_BEAST_TEX, _open_stage_pick, "点开选难度")
	_plaques.add_rail("cave", 0.905, 0.492, "洞", "山洞", PlaqueLayer.RAIL_CAVE_TEX, _click_cave)
	_plaques.add_rail("treasure", 0.905, 0.642, "宝", "藏宝阁", PlaqueLayer.RAIL_TREASURE_TEX, _click_treasure)
	_plaques.add_rail("craft", 0.905, 0.792, "坊", "百工坊", PlaqueLayer.RAIL_CRAFT_TEX, _click_craft)
	# ===== 中央朱砂「游历」大碑：接世界窗口（不是旧出村）=====
	_plaques.add_stele("stele", 0.5, 0.828, "游 历", _open_journey_entry, "开始游历", {"w": 452.0, "h": 138.0})
	# ===== 画上的地点牌（跟着画卷左右滑）=====
	var V := {"page": "village", "white": true}
	_plaques.add_hang("hill", 0.215, 0.695, "后山", _click_hill, "", "", {"page": "village", "white": true, "w": 76.0})
	# v237：一次性提示不再占右栏——直接放进画里，用掉就消失
	_plaques.add_hang("cave_scene", 0.660, 0.560, "山洞", _click_cave, "", "", {"page": "village", "white": true, "w": 80.0})
	_plaques.add_hang("treasure_map", 0.660, 0.660, "藏宝图", _click_treasure, "", "", {"page": "village", "white": true, "w": 96.0})
	print("[主界面] 牌子层：", _plaques.items.size(), " 块（v211：顶栏 + 右栏 5 格 + 历练大碑）")

func _grade_label() -> String:
	return GameState.role_grade_cn("player")


func _player_tag() -> String:
	var n := str(GameState.player_name)
	if n == "":
		n = str(GameState.role_data("player").get("name", "少侠"))
	return n

func _open_char_panel() -> void:
	_clear_toast()
	_char_panel.open()

func _show_player_tag() -> void:
	_show_toast("名号「" + _player_tag() + "」——头像：点开角色面板")

# 牌子的"出现时机"与"副标题"原来写在 _update_marks() 里，这里原样搬过来（判据一个字没改）
func _refresh_plaques() -> void:
	if _plaques == null:
		return
	_plaques.visible = (_story_page < 0) and not _any_panel_open()
	if not _plaques.visible:
		return
	# v200/v211：封面页只留顶栏（头像/名号/进阶/银两）与挂机；右栏与大碑全部收起
	var rail_on := not _cover_mode
	# 剧情解锁：目前只开「百工坊（铁匠铺）」与「出村」
	_plaques.set_vis("shop", false)
	_plaques.set_vis("kushou_test", false)
	_plaques.set_vis("hill", false)
	_plaques.set_vis("treasure", false)
	_plaques.set_vis("cave", false)
	_plaques.set_vis("treasure_map", false)
	_plaques.set_vis("cave_scene", false)
	_plaques.set_vis("craft", rail_on and GameState.winery_built)
	_plaques.set_vis("stele", false)
	_plaques.set_vis("advance", false)
	_plaques.set_vis("idle", false)
	# v211：右栏按"当前可见的格子"重排（隐藏一格，下面的平滑往上顶）
	_plaques.layout_rail(PlaqueLayer.RAIL_IDS, PlaqueLayer.RAIL_TOP, PlaqueLayer.RAIL_H, PlaqueLayer.RAIL_GAP)
	# v98：商店**固定**（用户点名）——不再按剧情显隐，也不随风摆
	if not GameState.pet_has("fox"):
		_plaques.set_sub("hill", "山里有动静")
	elif not GameState.pet_has("qing_sun"):
		_plaques.set_sub("hill", "松梢落了只隼")
	else:
		_plaques.set_sub("hill", "白狐的老家")
	_plaques.set_sub("treasure_map", "照图起一间")
	_plaques.set_sub("cave_scene", "扒开荒草")
	var rooms: Array = ["品酒"]
	if GameState.dange_built:
		rooms.append("炼丹")
	if GameState.jianbao_ok():
		rooms.append("鉴宝")
	if GameState.winery_built:
		rooms.append("锻造")
	_plaques.set_sub("craft", "点我进屋\n" + "/".join(PackedStringArray(rooms)))
	_plaques.set_sub("shop", "换材料")
	_plaques.set_sub("stele", "开始游历 · 已历 " + str(GameState.stage_progress) + " 关")
	# v211：中央大碑副题（主操作永远告诉玩家下一步）
	# ⚠ 「挂机」那一块的副标题（攒了多久/收不收）由 _refresh_idle_btn 每 0.5 秒喂，
	#   这里**不要**碰它——每帧清一次的话，那行字根本显示不出来。

func _fmt_min_tight(m: int) -> String:
	if m >= 60:
		var h := m / 60
		var mm := m % 60
		if mm > 0:
			return str(h) + "时" + str(mm) + "分"
		return str(h) + "时"
	return str(m) + "分"

func _refresh_idle_btn() -> void:
	if _idle_btn == null or _idle_time_lb == null:
		return
	var sec := GameState.idle_display_sec()
	var cap_h := GameState.IDLE_CAP_SEC / 3600
	var blink := int(Time.get_ticks_msec() / 500) % 2 == 0
	if sec >= GameState.IDLE_CAP_SEC:
		_idle_time_lb.text = str(cap_h) + " 时\n已满"
		_idle_act_lb.text = "收取"
		_idle_act_lb.add_theme_color_override("font_color", C_GOLD if blink else C_SEAL)
		_idle_btn.warm = 1.0
		_idle_btn.gold = 1.0 if blink else 0.55
	elif sec < 60:
		_idle_time_lb.text = "不到\n1 分"
		_idle_act_lb.text = "攒着"
		_idle_act_lb.add_theme_color_override("font_color", Color(0.42, 0.40, 0.38))
		_idle_btn.warm = 0.30
		_idle_btn.gold = 0.0
	else:
		_idle_time_lb.text = _fmt_min_tight(sec / 60)
		_idle_act_lb.text = "收取"
		_idle_act_lb.add_theme_color_override("font_color", C_SEAL if blink else Color(0.66, 0.44, 0.12))
		_idle_btn.warm = 0.92
		_idle_btn.gold = 0.55 if blink else 0.18
	_idle_btn.queue_redraw()
	# v97：同一份状态喂给牌子层的「挂机」木牌（老的 IdlePlaque 收起来了，随时能切回）
	if _plaques != null:
		_plaques.set_sub("idle", _idle_time_lb.text)
		_plaques.set_act("idle", _idle_act_lb.text)
		_plaques.set_warm("idle", _idle_btn.warm, _idle_btn.gold)
	_idle_btn.tooltip_text = "挂机（第 " + str(GameState.idle_tier() + 1) + " 档）——点木牌收取\n" + GameState.idle_rate_text() + "\n8 小时封顶；在线离线都往池里攒"

# ---- 四季 ----

func _season_now() -> int:
	# 按真实时间：每 SEASON_DAYS 天一块，0春 1夏 2秋 3冬——想换起跑点就在这儿加偏移
	var days := int(Time.get_unix_time_from_system() / 86400.0)
	return (days / SEASON_DAYS) % 4

func _init_season() -> void:
	_season = _season_now()
	if _mist != null:
		_mist.set_season(_season)
	# ⚠ 这里不要直接 _sync_ambient()：_init_season 在 _ready 里跑，root 还在建子节点，
	#   add_child(环境音播放器) 会失败。交给 deferred 的 _start_ambient()。
	var cf := ConfigFile.new()
	var prev := -1
	if cf.load(SEASON_CFG) == OK:
		prev = int(cf.get_value("season", "last", -1))
	if prev != _season:
		if prev < 0:
			_show_toast("现在是「" + str(SEASON_CN[_season]) + "」——四季每 " + str(SEASON_DAYS) + " 天轮换一次（N 键预览）", 3.2)
		else:
			_show_toast("换季——" + str(SEASON_ARRIVE[_season]), 3.2)
		cf.set_value("season", "last", _season)
		cf.save(SEASON_CFG)

# ㊿i：险前落盘——系统在真正杀进程前，通常还会给的最后几次机会：
#   手机切后台（APPLICATION_PAUSED）／Android 返回键（WM_GO_BACK_REQUEST）／关窗请求（WM_CLOSE_REQUEST）。
#   强杀本身没有钩子可接；能接到这几条的场合，先把全局账写下去。
#   （游历侧不用加：那趟里全局账本来就不动，"走一段"的续行档天生按节点即存。）
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.idle_sync()
		GameState.save_game()
		print("[主界面] 险前落盘（通知码 ", what, "）")

func _start_ambient() -> void:
	_sync_ambient()

# v234：夏雨用 rain，其余用 wind；换季时调用
func _sync_ambient() -> void:
	if _season == 1:
		Audio.play_ambient("rain", -25.0)
	else:
		Audio.play_ambient("wind", -27.0)

func _exit_tree() -> void:
	Audio.stop_ambient()    # v230：离开主界面（进游历/战斗）就把风停掉
	GameState.idle_sync()
	GameState.save_game()   # 优化批㉒：退场落盘
	print("[主界面] 离场落盘：首趟=", GameState.first_journey_done)   # ㊿h：切场即存（主界面侧）

# v4.2：5 格 → 6 格（新增「宝箱」）。宽度得跟着收：720 - 2×10 边距 = 700，
#   主键 146 + 5×96 + 5×11 缝 = 681，居中后左右各留 ~19。
func _tag_unlocked(i: int) -> bool:
	# 出村牌子隐藏（引子改走开场场景）；角色/行囊按剧情解锁
	return (i == 1 and _role_unlocked) or (i == 2 and _bag_unlocked)


func _layout_tags() -> void:
	# v211：6 格**等宽**（底栏抬到 100 高）——主格不再独大，整排像一条真正的功能带
	var gap := 8.0
	var n := Conf.TAGN.size()
	var w := (Conf.DW - 24.0 - gap * float(n - 1)) / float(n)
	var x := 12.0
	var rects: Array = []
	for i in n:
		rects.append(Rect2(x, Conf.TAG_Y, w, Conf.TAG_H))
		x += w + gap
	var unlocked := 0
	for i in n:
		if _tag_unlocked(i):
			unlocked += 1
	if unlocked <= 1:
		for i in n:
			rects[i] = Rect2(0.0, 0.0, 0.0, 0.0)
		rects[1] = Rect2(240.0, Conf.TAG_Y, 240.0, Conf.TAG_H)
	_tag_rects = rects

# ---- 场景标语 ----


# ============================================================
# v72：**设置面板**（用户：「主界面加一个设置按钮，可以调节背景音乐和音效的音量大小」）
#   · 音乐音量 / 音效音量（0~100%，拖动即时生效、即时落盘）
#   · 主界面曲目：6 首可选（素材包那批真曲），点了立刻换曲
#   · 存 user://audio.cfg，跟村账存档分开
# ============================================================

# ============================================================
# v83：**起名弹窗**（用户：「引子结束后 给玩家一个弹出起名的窗口【不起名就默认叫少侠】」）
#   触发：首趟（引子）走完 + 还没起过名 → 回村时弹一次。
#   不起名也行：输入框预填「少侠」，直接点确定就是默认名。
#   名字只写进 GameState.player_name，显示那一层由 role_data() 统一拦（见那边的注释）。
# ============================================================
var _name_asked := false
var _name_ov = null

func _maybe_ask_name() -> void:
	if _name_asked or _name_ov != null:
		return
	if not GameState.first_journey_done or GameState.player_name != "":
		return
	_name_asked = true
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	_name_ov = ov
	var veil := UiKit.make_veil(ov, size, 0.55)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var pw := 520.0
	var ph := 300.0
	var panel := UiKit.make_paper_panel(ov, Rect2((size.x - pw) * 0.5, (size.y - ph) * 0.5, pw, ph))
	var t1 := UiKit.make_label(panel, Vector2(0, 26), Vector2(pw, 44), 30, UiKit.INK)
	UiKit.set_text(t1, "报个名号")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := UiKit.make_label(panel, Vector2(30, 76), Vector2(pw - 60.0, 30), 17,
		Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.62))
	UiKit.set_text(t2, "江湖上总得有个称呼。不填，就叫「少侠」。")
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var le := LineEdit.new()
	le.text = "少侠"
	le.max_length = 8
	le.position = Vector2(70, 126)
	le.size = Vector2(pw - 140.0, 52)
	le.add_theme_font_size_override("font_size", 26)
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(le)
	le.grab_focus()
	le.select_all()
	le.text_submitted.connect(func(_t: String) -> void: _confirm_name(le.text))
	var ok := UiKit.make_button(panel, Vector2((pw - 240.0) * 0.5, ph - 78.0), Vector2(240, 52), "就　叫　这　个", 21)
	ok.pressed.connect(func() -> void: _confirm_name(le.text))
	print("[起名] 弹窗（引子已走完、尚未起名）")

func _confirm_name(n: String) -> void:
	GameState.set_player_name(n)
	GameState.save_game()
	print("[起名] 定了：", GameState.role_data("player").get("name", "?"))
	if _name_ov != null and is_instance_valid(_name_ov):
		_name_ov.queue_free()
	_name_ov = null
	UiKit.float_text(self, "往后江湖上，你就是「" + str(GameState.role_data("player").get("name", "少侠")) + "」", UiKit.SEAL)

# v16z（用户："可以再主界面加一个困兽【测试】按钮了"）：
#   把"开困兽"抽成一个函数 —— **E 键和主界面那颗按钮共用**
#   （原来只有 E 键能进，手机上没键盘根本进不去）。
# v17a（用户："点击困兽测试 然后弹出难度选择窗口 点击难度选择窗口然后才会进入困兽主界面"）：
#   困兽的 12 关＝难度档（mul 就是倍率）。这里做一个选关浮层，选完才进困兽。
#   数据跟 kushou_v2.gd 里的 STAGES 对齐：id / 名称 / mul / **本关专属 boss** / 首通 3 项。
#   ⚠ 这是一份**手抄的副本** —— 改 kushou_v2.gd 的 STAGES 时这里要一起改（v18f 同步过一次）。
const KUSHOU_STAGES := [
	["1-1", "牢门初开", 1.0, "看门恶犬", "卡组·磐石心 ＋ 队员·法度 ＋ 宝物·虎符"],
	["1-2", "铁栅血痕", 1.4, "铁背苍狼", "卡组·铁布衫 ＋ 队员·铁无心 ＋ 宠物·雷鹫"],
	["1-3", "断锁残灯", 1.8, "毒牙蟒", "队员·白婆婆 ＋ 卡组·磐石 ＋ 装备·兵器·刀"],
	["2-1", "典吏巡夜", 2.6, "双头狮", "宝物·灵晶袋 ＋ 队员·蛊师 ＋ 卡组·灵犀"],
	["2-2", "五行乱阵", 3.1, "独眼狱卒", "卡组·五行 ＋ 队员·季沧海 ＋ 宠物·金蟾"],
	["2-3", "贪墨之狱", 3.7, "火尾狐妖", "装备·聚财珠 ＋ 队员·苏青鸾 ＋ 卡组·聚宝"],
	["3-1", "龙纹石壁", 4.6, "场主亲养·狴犴", "宝物·龙纹佩 ＋ 队员·西门烈 ＋ 卡组·飞羽"],
	["3-2", "雷罚天牢", 5.4, "血手判官", "卡组·雷罚 ＋ 队员·毒娘子 ＋ 装备·护心镜"],
	["3-3", "传家之秘", 6.3, "困兽之主", "装备·传家宝 ＋ 队员·鬼见愁 ＋ 卡组·猎杀"],
	["4-1", "火麟熔狱", 7.5, "九幽魔君", "宠物·火麟 ＋ 队员·醉太岁 ＋ 卡组·悟道"],
	["4-2", "诛心绝境", 8.6, "血海罗刹", "卡组·诛心 ＋ 队员·白起后人 ＋ 宝物·灵石"],
	["4-3", "困兽之斗", 9.5, "困兽·终焉", "宝物·悟道果 ＋ 队员·大内供奉 ＋ 卡组·天命"],
]

var _stage_ov: Control = null

func _open_stage_pick() -> void:
	if _stage_ov != null and is_instance_valid(_stage_ov):
		return
	var vp := get_viewport_rect().size
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.08, 0.86)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(bg)
	var title := Label.new()
	title.position = Vector2(0, vp.y * 0.055)
	title.size = Vector2(vp.x, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	title.text = "困兽 · 选择难度"
	ov.add_child(title)
	var sub := Label.new()
	sub.position = Vector2(0, vp.y * 0.055 + 50.0)
	sub.size = Vector2(vp.x, 34)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Color(0.72, 0.70, 0.66))
	sub.text = "倍率越高怪越硬（×1.0 ~ ×9.5）· 波数 20~40 · 每关一只专属 boss · 首通解锁 3 项"
	ov.add_child(sub)
	# 4 列 × 4 行 的关卡格
	var cw := minf(300.0, (vp.x - 80.0) / 4.0 - 12.0)
	var ch := 118.0
	var gx := (vp.x - (cw * 4.0 + 36.0)) * 0.5
	var gy := vp.y * 0.055 + 104.0
	for i in KUSHOU_STAGES.size():
		var st: Array = KUSHOU_STAGES[i]
		var sx := gx + float(i % 4) * (cw + 12.0)
		var sy := gy + float(i / 4) * (ch + 14.0)
		var b := Button.new()
		b.position = Vector2(sx, sy)
		b.size = Vector2(cw, ch)
		b.text = str(st[0]) + "  " + str(st[1]) + "\n×" + str(st[2]) + " · " + str(st[3])
		b.tooltip_text = "本关 boss：" + str(st[3]) + "\n首通 3 项：" + str(st[4])
		b.add_theme_font_size_override("font_size", 20)
		var sb := StyleBoxFlat.new()
		# 倍率越高底色越红（一眼看出哪关难）
		var heat := clampf((float(st[2]) - 1.0) / 1.6, 0.0, 1.0)
		sb.bg_color = Color(0.20, 0.18, 0.20).lerp(Color(0.42, 0.13, 0.13), heat)
		sb.set_corner_radius_all(10)
		sb.border_color = Color(0.85, 0.74, 0.42)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
		b.pressed.connect(_pick_stage.bind(str(st[0]), str(st[1])))
		ov.add_child(b)
	# 取消
	var rows := int(ceil(float(KUSHOU_STAGES.size()) / 4.0))
	var cb := Button.new()
	cb.position = Vector2(vp.x * 0.5 - 110.0, gy + float(rows) * (ch + 14.0) + 10.0)
	cb.size = Vector2(220, 62)
	cb.text = "取消"
	cb.add_theme_font_size_override("font_size", 22)
	cb.pressed.connect(func(): _stage_ov.queue_free())
	# v17v（用户："存档和成就按钮放在困兽测试按钮出的窗口里"）：
	#   不用先选关 —— 这两颗点了直接进困兽并弹出对应的窗。
	var by := gy + float(rows) * (ch + 14.0) + 10.0
	for bi in 2:
		var bx2 := Button.new()
		bx2.position = Vector2(vp.x * 0.5 - 350.0 + float(bi) * 480.0, by)
		bx2.size = Vector2(220, 62)
		bx2.text = "存档" if bi == 0 else "成就"
		bx2.add_theme_font_size_override("font_size", 22)
		bx2.pressed.connect(_pick_popup.bind("存档" if bi == 0 else "成就"))
		ov.add_child(bx2)
	ov.add_child(cb)
	add_child(ov)
	move_child(ov, get_child_count() - 1)
	_stage_ov = ov

# v17v：从主界面选关窗直接开困兽的某个窗（存档/成就）
func _pick_popup(which: String) -> void:
	var kz = load("res://kushou/kushou_v2.gd")
	if kz != null:
		kz.boot_popup = which
		kz.boot_popup_only = true
	if _stage_ov != null and is_instance_valid(_stage_ov):
		_stage_ov.queue_free()
		_stage_ov = null
	_open_kushou_v2()

func _pick_stage(id: String, nm: String) -> void:
	var kz = load("res://kushou/kushou_v2.gd")
	if kz != null:
		kz.boot_stage = id
	if _stage_ov != null and is_instance_valid(_stage_ov):
		_stage_ov.queue_free()
		_stage_ov = null
	_open_kushou_v2()
	_show_toast("[困兽·测试] " + id + " " + nm + "　（倍率见关卡页）")

func _open_kushou_v2() -> void:
	if _kushou_v2 == null:
		_kushou_v2 = (preload("res://kushou/kushou_v2.gd") as GDScript).new()
		add_child(_kushou_v2)
	_kushou_v2.open()
	_show_toast("[困兽·测试] 直接进——左侧抽卡/挑战/任务/卡组，右上存档/成就/黑市")

func _open_settings() -> void:
	if _settings_ov != null and is_instance_valid(_settings_ov):
		return
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	_settings_ov = ov
	# v19a（用户："设置就设置成主界面模式的设置一样 加一个退出就行了"）：
	#   困兽开着的时候，这个面板里多一颗［退出困兽 · 回主界面］，面纱也压深一点，面板长一点
	var in_kz: bool = _kushou_v2 != null and is_instance_valid(_kushou_v2) and _kushou_v2.visible
	var veil := UiKit.make_veil(ov, size, 0.66 if in_kz else 0.50)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var pw := 560.0
	var ph: float = 486.0 + (74.0 if in_kz else 0.0)
	var px := (size.x - pw) * 0.5
	var py := (size.y - ph) * 0.5
	var panel := UiKit.make_paper_panel(ov, Rect2(px, py, pw, ph))
	var ttl := UiKit.make_label(panel, Vector2(0, 16), Vector2(pw, 40), 30, UiKit.INK)
	UiKit.set_text(ttl, "设　置")
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sep := ColorRect.new()
	sep.color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.20)
	sep.position = Vector2(28, 62)
	sep.size = Vector2(pw - 56.0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sep)
	# ---- 音乐音量 ----
	_slider_row(panel, 82.0, pw, "音　乐", Audio.bgm_volume(), func(v: float) -> void:
		Audio.set_bgm_volume(v))
	# ---- 音效音量 ----
	_slider_row(panel, 148.0, pw, "音　效", Audio.sfx_volume(), func(v: float) -> void:
		Audio.set_sfx_volume(v))
	# ---- 主界面曲目 ----
	var lbt := UiKit.make_label(panel, Vector2(32, 220), Vector2(pw - 64.0, 26), 19, UiKit.INK)
	UiKit.set_text(lbt, "主界面曲目（点一下试听，自动记住）")
	var tracks: Array = Audio.MENU_TRACKS
	for i in tracks.size():
		var tk: Dictionary = tracks[i]
		var col := i % 3
		var row := int(i / 3)
		var bx := 32.0 + float(col) * 168.0
		var by := 254.0 + float(row) * 52.0
		var on := str(tk["key"]) == Audio.menu_track()
		var tb := UiKit.make_button(panel, Vector2(bx, by), Vector2(156, 44), str(tk["name"]), 18)
		tb.pressed.connect(_pick_menu_track.bind(str(tk["key"])))
		if on:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.28, 0.24, 0.20, 0.95)
			sb.set_corner_radius_all(6)
			tb.add_theme_stylebox_override("normal", sb)
	if in_kz:
		var xb := UiKit.make_button(panel, Vector2((pw - 340.0) * 0.5, ph - 130.0), Vector2(340, 48), "退出困兽 · 回主界面", 20)
		xb.pressed.connect(_exit_kushou)
	# ---- 关闭 ----
	var cb := UiKit.make_button(panel, Vector2((pw - 200.0) * 0.5, ph - 66.0), Vector2(200, 48), "关　闭", 20)
	cb.pressed.connect(_close_settings)
	print("[设置] 打开：音乐 ", int(Audio.bgm_volume() * 100.0), "% · 音效 ", int(Audio.sfx_volume() * 100.0), "% · 曲目 ", Audio.menu_track())

# 一行「标签 + 滑条 + 百分比」
func _slider_row(panel: Control, y: float, pw: float, title: String, val: float, cb: Callable) -> void:
	var lb := UiKit.make_label(panel, Vector2(32, y), Vector2(110, 30), 19, UiKit.INK)
	UiKit.set_text(lb, title)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = val
	sl.position = Vector2(140, y + 2)
	sl.size = Vector2(pw - 250.0, 34)
	sl.custom_minimum_size = Vector2(pw - 250.0, 34)
	panel.add_child(sl)
	var pv := UiKit.make_label(panel, Vector2(pw - 96.0, y), Vector2(70, 30), 19, UiKit.INK)
	UiKit.set_text(pv, str(int(round(val * 100.0))) + "%")
	pv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sl.value_changed.connect(func(v: float) -> void:
		UiKit.set_text(pv, str(int(round(v * 100.0))) + "%")
		cb.call(v))

func _pick_menu_track(key: String) -> void:
	Audio.set_menu_track(key)
	_close_settings()
	_open_settings()     # 重开一次，把选中的高亮刷新掉

# 从设置面板直接退出困兽：收面板 → 藏起困兽 → 回主界面
func _exit_kushou() -> void:
	_close_settings()
	if _kushou_v2 != null and is_instance_valid(_kushou_v2):
		_kushou_v2.close()
	_show_toast("已退出困兽，回到主界面")

func _close_settings() -> void:
	if _settings_ov != null and is_instance_valid(_settings_ov):
		_settings_ov.queue_free()
	_settings_ov = null
func _add_mark(kind: String, cx: float, wy: float, title: String, sub: String) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(_on_mark.bind(kind))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.955, 0.937, 0.886, 0.93)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(0.28, 0.23, 0.19, 0.45)
	sb.set_border_width_all(1)
	var hv: StyleBoxFlat = sb.duplicate()
	hv.bg_color = Color(1.0, 0.97, 0.90, 0.98)
	hv.border_color = Color(0.72, 0.58, 0.25, 0.85)
	var pr: StyleBoxFlat = sb.duplicate()
	pr.bg_color = Color(0.90, 0.88, 0.82, 0.95)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("focus", sb)
	# v69（用户："AI 做的房子建筑不要了，尽量做到风格统一"）：
	#   记号上的 AI 建筑图**撤掉**了——那批是生成图，和村里手写的水墨房子不是一套语言。
	#   村子本身（menu_village）是水墨画的屋檐/田埂/篱笆，天然统一，也更有武侠味。
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 17)
	tl.add_theme_color_override("font_color", Color(0.14, 0.13, 0.15))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tl)
	var sl := Label.new()
	sl.text = sub
	sl.add_theme_font_size_override("font_size", 13)   # v61（手游）：12 → 13 号（村口那几块牌子的副标题）
	sl.add_theme_color_override("font_color", Color(0.14, 0.13, 0.15, 0.62))
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sl)
	# v69：记号牌也上学 ui_kit 那套"按下缩一点"的反馈（和面板按钮同一手感）
	b.pivot_offset = b.size * 0.5
	b.button_down.connect(func() -> void: _mark_press(b, 0.94))
	b.button_up.connect(func() -> void: _mark_press(b, 1.0))
	b.mouse_exited.connect(func() -> void: _mark_press(b, 1.0))
	_marks_root.add_child(b)
	_mark_btns.append({"kind": kind, "cx": cx, "wy": wy, "title": title, "sub": sub, "btn": b, "tl": tl, "sl": sl, "phase": float(_mark_btns.size()) * 1.3})

func _mark_press(b: Button, to: float) -> void:
	if not is_instance_valid(b):
		return
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(to, to), 0.09).set_trans(Tween.TRANS_SINE)

func _update_marks() -> void:
	var can := (_story_page < 0) and not _any_panel_open()
	_marks_root.visible = can and not INK_ONLY   # v97：记号牌的位置改由牌子层接管（代码保留）
	if not can:
		return
	for e in _mark_btns:
		var kind := str(e["kind"])
		var btn: Button = e["btn"]
		var tl: Label = e["tl"]
		var sl: Label = e["sl"]
		var sub := str(e["sub"])
		match kind:
			"hill":
				if not GameState.pet_has("fox"):
					sub = "新解锁：山林里有动静"
				elif not GameState.pet_has("qing_sun"):
					sub = "松梢上落了只隼——去看看"
				else:
					sub = "白狐的老家（松梢空了）"
			"treasure":
				if not GameState.map_found:
					btn.visible = false
					continue
				if GameState.b2_built:
					sub = "图收在里头（用处以后再定）"
				else:
					sub = "照图起一间"
			"cave":
				# v26：做完任务山洞就没了——记号也不再冒出来
				if not GameState.b2_built or GameState.cave_opened:
					btn.visible = false
					continue
				sub = "荒草盖着个洞"
			"craft":
				# v50：「百工坊」＝品酒坊 ＋ 炼丹阁 ＋ 鉴宝行 的门厅（用户："统一集中到一个建筑物"）
				#   出现时机＝原来品酒坊那一条（过山洞剧情）；里面三间各有各的开法。
				if not GameState.cave_opened:
					btn.visible = false
					continue
				if not GameState.winery_built:
					sub = "陈酿有地方去了"
				else:
					var rooms: Array = ["品酒"]
					if GameState.dange_built:
						rooms.append("炼丹")
					if GameState.jianbao_ok():
						rooms.append("鉴宝")
					var tail2 := ""
					if GameState.alchemy_busy():
						tail2 = " · " + GameState.furnace_line()
					sub = "点我进屋：" + " / ".join(PackedStringArray(rooms)) + tail2
			"shop":
				if not (GameState.first_journey_done or GameState.stage_progress >= 1):
					btn.visible = false
					continue
				sub = "银两换材料／残卡（残卡与血脉囊每日限购）"
		tl.text = str(e["title"])
		sl.text = sub
		var show_sub := sub != ""
		sl.visible = show_sub
		var w := _font.get_string_size(str(e["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 26.0
		if show_sub:
			w = maxf(w, _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 20.0)   # v61：跟着副标题字号走
		w = maxf(w, 96.0)
		var h := 46.0 if show_sub else 30.0   # v61（手游）：44 → 46（副标题 13 号要一行高）
		var sx := float(e["cx"]) - _cam
		if sx < -160.0 or sx > Conf.DW + 160.0:
			btn.visible = false
			continue
		btn.visible = true
		var sy := Draw.sy_at(float(e["wy"]))
		# v62b（用户："建筑名牌 挂机钮 还是动态吧"）：上一条我把它钉死了——**恢复**。
		#   名牌照旧各自带相位轻轻起伏 ±5 像素（一屏七八块，像画上挂着的木牌随风水动）。
		var bob := sin(_t * 1.6 + float(e["phase"])) * 5.0
		btn.size = Vector2(w, h)
		btn.position = Vector2(clampf(sx - w * 0.5, 6.0, Conf.DW - w - 6.0), sy - h - 26.0 + bob)
		tl.position = Vector2(0, 3.0)
		tl.size = Vector2(w, 20.0)
		sl.position = Vector2(0, 22.0)
		sl.size = Vector2(w, 18.0)

# v67：点建筑先"推门而入"——闪一张内景图（淡入 → 停 0.75 秒 → 淡出），
#   面板照常在它后面打开，所以看得到"门开了、里面是这个样子"的过场。
func _enter_flash(tex: Texture2D) -> void:
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate.a = 0.0
	add_child(tr)
	var tw := create_tween()
	tw.tween_property(tr, "modulate:a", 1.0, 0.22)
	tw.tween_interval(0.75)
	tw.tween_property(tr, "modulate:a", 0.0, 0.30)
	tw.tween_callback(tr.queue_free)

func _on_mark(kind: String) -> void:
	_enter_flash(SceneArt.enter_scene(kind))
	match kind:
		"wa":
			_show_toast("「瓦房」——村里的第一户人家，以后能进来歇脚")
		"zhu":
			_open_warehouse()
		"stone":
			_show_toast("「石桌」——以后是：设置")
		"gate":
			_show_toast("「山门」——以后是：回山门 · 关于")
		"hill":
			_click_hill()
		"treasure":
			_click_treasure()
		"cave":
			_click_cave()
		"winery":
			_click_craft()        # v50：品酒坊的记号已并进「百工坊」（老档里若还留着这一条，走同一条路）
		"dange":
			_click_craft()
		"jianbao":
			_click_craft()
		"craft":
			_click_craft()
		"shop":
			_open_shop()

func _click_hill() -> void:
	if not GameState.pet_has("fox"):
		_story_start("backhill")
		return
	if not GameState.pet_has("qing_sun"):
		GameState.pet_join("qing_sun")
		_show_toast("松梢的隼绕着你飞了一圈——它认你了。（青隼入册 · 想带它随行，去宠物面板）", 3.4)
		print("[主界面] 青隼入册：", GameState.pet_owned())
		return
	_show_toast("后山很安静——草窝空了，松脚上留着一根断羽。")

# ---- 建筑链 ----

func _click_treasure() -> void:
	if GameState.b2_built:
		_show_toast("「藏宝阁」——图上画的那块地方，如今是间空屋。用处以后再定。")
		return
	GameState.b2_built = true
	_spawn_build_fx(Vector2(2140.0, 812.0))
	_show_toast("「藏宝阁」起好了——图收在里头。乱草堆后面，像还压着别的记号……", 2.6)
	await get_tree().create_timer(0.8).timeout   # v62：建筑动画缩到 0.7 秒，这句跟着提前
	_show_toast("后山那头多出个「山洞」记号——看看去")

func _click_cave() -> void:
	if GameState.cave_opened:
		_show_toast("洞里很凉——石案上只剩个湿印子。")
		return
	_spawn_build_fx(Vector2(470.0, 730.0))
	_story_start("cave")

# ============================================================
# v50：「百工坊」——品酒坊 ＋ 炼丹阁 ＋ 鉴宝行 **合成一间屋子**
#   用户："品酒 炼丹 鉴宝统一集中到一个建筑物吧，也好点。就一个主界面，上面品酒/炼丹/鉴宝。"
#   村里只留一个记号；点进来是门厅（menu/craft_panel.gd），三块牌子各管一间。
#   三个作坊的账**一个都没动**（winery_built / dange_built / jianbao_unlocked），
#   所以老档照样认；这里只管"屋起没起、门开不开"。
# ============================================================
func _click_craft() -> void:
	# 老档兜底：引子已经走通的，百工坊不再卡旗标；第一下就直接开门。
	if GameState.first_journey_done:
		GameState.cave_opened = true
		GameState.winery_built = true
	if not GameState.cave_opened:
		_show_toast("这屋子还没影——先把山洞那段过了")
		return
	if not GameState.winery_built:
		GameState.winery_built = true
		_spawn_build_fx(Vector2(1040.0, 852.0))
		_show_toast("「百工坊」起好了——里面能进品酒坊了", 2.6)
	_clear_toast()
	print("[主界面] 开百工坊：cave=", GameState.cave_opened, " wine=", GameState.winery_built)
	if _craft_panel == null:
		_show_toast("百工坊面板没挂上——看控制台")
		return
	_craft_panel.open()
	_craft_panel.move_to_front()
	if _craft_guide != null and _craft_guide_step == "craft":
		_start_forge_guide()

# 门厅里点了哪一间：能开就开；炼丹阁还带"起炉"那一步（与原来 _click_dange 同一笔账）
func _on_craft_room(room: String) -> void:
	if _craft_guide != null:
		_end_craft_guide()
	# 进作坊前先把门厅收掉；否则门厅那张纸会压在新面板上面（用户："原百工坊窗口覆盖了品酒坊"）。
	if _craft_panel != null:
		_craft_panel.visible = false
	match room:
		"wine":
			_open_winery()
			if _winery_panel != null:
				_winery_panel.move_to_front()
		"alchemy":
			if GameState.dange_built:
				_alchemy_panel.open()
				_alchemy_panel.move_to_front()
				return
			if not _dange_ready():
				_show_toast("炼丹阁要过第 " + str(HERB_STAGE) + " 关（灵草剧情）才起得了炉")
				return
			GameState.dange_built = true
			_spawn_build_fx(Vector2(1872.0, 815.0))
			_show_toast("「炼丹阁」起好了——开炉前可以先派个没出战的人看火", 2.8)
			_alchemy_panel.open()
			_alchemy_panel.move_to_front()
		"jianbao":
			if not GameState.jianbao_ok():
				_show_toast("鉴宝行还没开张——过第 " + str(JIANBAO_STAGE) + " 关（打捞上来的货仓）")
				return
			_open_appraise()
			if _appraise_panel != null:
				_appraise_panel.move_to_front()
		"forge":
			_clear_toast()
			_forge_panel.open()
			_forge_panel.move_to_front()
			_show_forge_story()

func _click_winery() -> void:
	_click_craft()

func _open_winery() -> void:
	print("[主界面] 百工坊 · 品酒坊")
	_clear_toast()
	_winery_panel.open()

# 炼丹阁：**清到第 300 关（灵草剧情）才起得了炉**。
#
# ⚠ 这里以前有一条近路：`手里有兽骨碎/灵米` 也算"能起炉"。可那两样是货栈里
#   10~15 文的大路货，等于第 1 关就能把炼丹阁起出来，把「300 关解锁」整条线绕过去了。
#   已按"必须过 300 关"的口径撤掉那条；那两样货现在也跟着炉子一起上架（见 GameState.SHOP_ITEMS 的 need）。
#
# 判据整份搬到 GameState.dange_unlocked() 了——货栈"上架闸"、开炉那道闸、
# 这里"牌子显不显"三处共用同一口，免得同一件事写三遍、改一处漏两处。
func _dange_ready() -> bool:
	return GameState.dange_unlocked()

func _click_dange() -> void:
	_on_craft_room("alchemy")

# 各层的位置与缩放
func _apply_layer_transforms() -> void:
	if PIN_CAM:
		_cam = Conf.OPEN_CAM      # v97：一屏村景，不再横向拖卷（拖动代码留着，随时能放开）
	var z := _zoom()
	var o := _origin()
	var sy := Draw.sy()
	_scroll.position = Vector2(o.x - _cam * z, o.y + (Conf.CONTENT_TOP - Conf.SCENE_TOP * sy) * z)
	_scroll.scale = Vector2(z, z * sy)
	_scroll.cam = _cam
	_scroll.t = _t
	_scroll.season = _season
	_village.position = _scroll.position
	_village.scale = _scroll.scale
	_village.cam = _cam
	_village.t = _t
	_village.stage = GameState.VILLAGE_MAX
	_village.show_cave = GameState.b2_built
	_village.cave_opened = GameState.cave_opened
	_village.show_winery = GameState.winery_built
	_village.show_dange = GameState.dange_built
	_village.dange_busy = GameState.alchemy_busy()
	_village.show_shop = GameState.first_journey_done or GameState.stage_progress >= 1
	_village.show_treasure = GameState.b2_built
	_village.disciple_joined = GameState.disciple_joined
	_village.qingluan_joined = GameState.qingluan_joined   # v93：她也要在村里活动
	_village.backhill_open = true
	_village.pet_joined = GameState.pet_id != ""
	_village.sun_joined = GameState.pet_has("qing_sun")
	_village.season = _season
	var vt := ""
	if GameState.alchemy_busy():
		# v41：多炉——村景里那个小人按"第一炉的看火人"站（有多炉时只画一个）
		for fi in GameState.furnace_count():
			var f: Dictionary = GameState.furnace_at(fi)
			if f.is_empty():
				continue
			var t0 := str(f.get("tender", ""))
			if t0 != "" and not GameState.is_deployed(t0):
				vt = t0
				break
	_village.dange_tender = vt
	# v96：纸偶演员层关掉时 _actors 是 null —— 这里必须先判空（否则每帧刷报错）
	if _actors != null:
		_actors.position = _scroll.position
		_actors.scale = _scroll.scale
		_actors.visible = not _any_panel_open() and _story_page < 0   # 开面板/看剧情就整层收起
	_fx_root.position = _scroll.position
	_fx_root.scale = _scroll.scale
	_mount.position = Vector2(o.x - _cam * z, o.y)
	_mount.scale = Vector2(z, z)
	_mount.cam = _cam
	_mount.t = _t
	_hud.position = Vector2(o.x, o.y)
	_hud.scale = Vector2(z, z)
	_hud.t = _t
	_veil.position = Vector2(o.x, o.y)
	_veil.scale = Vector2(z, z)
	_marks_root.position = Vector2(o.x, o.y)
	_marks_root.scale = Vector2(z, z)
	if _plaques != null:
		_plaques.position = Vector2(o.x, o.y)
		_plaques.scale = Vector2(z, z)
		_plaques.set_slide(_sc)          # v98：村里的牌子跟着画卷一起滑
		_refresh_plaques()
		# 百工坊是后加的右栏格：老档/早期帧可能停在 vis=false，直接补亮（只限村景页）。
		if (not _cover_mode) and GameState.first_journey_done:
			_plaques.force_vis("craft", true)
	# v98：两页画卷——村景页（画心 _ink_clip）与封面页（_cover_win）一左一右，_sc 是卷轴位置。
	#   V＝"卷位"（画卷在长卷坐标里的位置）：村景页 1560 · 封面页 2280——装裱层按 V 画包边/木轴/引首。
	var V := Conf.OPEN_CAM - (Conf.DW - _sc)
	if _ink_clip != null:
		_ink_clip.position = Vector2(o.x, o.y + Conf.BAND_TOP * z)
		_ink_clip.scale = Vector2(z, z)
		if _ink != null:
			_ink.size = Vector2(Conf.DW, Conf.DH)          # ⚠ 画心比它矮，别让锚点把它压扁
			_ink.position = Vector2(-_sc, -Conf.BAND_TOP)  # 村景跟着卷走
	if _cover_win != null:
		_cover_win.position = Vector2(o.x + (Conf.DW - _sc) * z, o.y)
		_cover_win.scale = Vector2(z, z)
		_cover_win.visible = _sc > 0.5
	if _mount != null and INK_ONLY:
		_mount.position = Vector2(o.x - V * z, o.y)
		_mount.scale = Vector2(z, z)
		_mount.cam = V
		_mount.roll_ratio = _sc / Conf.DW     # 卷口：村景页时右边卷着，封面页时左边卷着
		_mount.queue_redraw()
	if _money_hud != null:
		_money_hud.position = Vector2(o.x, o.y)
		_money_hud.scale = Vector2(z, z)
	if _idle_btn != null:
		_idle_btn.position = Vector2(o.x + 14.0 * z, o.y + 16.0 * z)
		_idle_btn.scale = Vector2(z, z)
		# v62b（用户："建筑名牌 挂机钮 还是动态吧"）：恢复 ±1.8° 的慢摇。
		_idle_btn.rotation = sin(_t * 1.15) * 0.032
	_update_marks()
	_scroll.queue_redraw()
	_village.queue_redraw()
	_mount.queue_redraw()
	_hud.queue_redraw()

func _sy(wy: float) -> float:
	return Draw.sy_at(wy)

func _spawn_build_fx(pos: Vector2) -> void:
	if _fx_root == null:
		return
	var fx := BuildFx.new()
	fx.position = pos
	fx.setup(randi() % 1000, 0)
	_fx_root.add_child(fx)

# v63j（用户："b 和 u 依旧没啥反应"）：B/U 挪进 **_input**——它在 GUI/焦点之前就到，
#   任何界面/剧情挡着都收得到；其余测试键留在 _unhandled_input 照旧。
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke2 := event as InputEventKey
	if not (ke2.pressed and not ke2.echo):
		return
	if ke2.keycode == KEY_B:
		# ㊿z12（抽搐取证）：把 5 秒内**所有火柴人**每帧的位移与关节角记进 user://twitch_dump.csv
		if _twitch_rec != null and is_instance_valid(_twitch_rec):
			_show_toast("[抽搐取证] 已在记录中", 2.0)
		else:
			_twitch_rec = TwitchRecorder.new()
			add_child(_twitch_rec)
			_show_toast("[抽搐取证] 开始——屏幕顶部黄字计数＝录上了；5 秒后写入 twitch_dump.csv", 3.0)
			print("[抽搐取证] 开始记录（twitch_dump.csv）")
		return
	if ke2.keycode == KEY_U:
		# v63d/v63i：跳引子直达主界面——若正放着剧情，直接把剧情翻到最后一页走完
		GameState.first_journey_done = true
		if _story_page >= 0:
			_story_page = _story_pages().size() - 1
			_story_next()
		_show_toast("[测试] 引子已跳过——直达主界面（新手关卡礼包要的话按 8）", 2.6)
		return

# 【测试用·上线前删】字母键：见文件头
func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey):
		return
	var ke := ev as InputEventKey
	if not (ke.pressed and not ke.echo):
		return
	if ke.keycode == KEY_F:
		if _story_page >= 0:
			return
		_clear_toast()
		print("[主界面][测试] 整备·阵容（三格面板）：", GameState.formation)
		_formation.open_config()
		return
	if ke.keycode == KEY_I:
		GameState.first_journey_done = true
		GameState.disciple_joined = false
		GameState.formation = ["player"]
		GameState.formation_intro_done = false
		_tag_notice = -1
		_story_kind = "intro"
		_story_page = 0
		if _char_panel != null:
			_char_panel.close()
		print("[主界面][测试] 重播弟子入门剧情（出战引导也重置）")
		return
	if ke.keycode == KEY_K:
		# 重播整条宠链：狐、隼都从名册摘掉（灵息归零）——狐剧情重开，通关后狐入册，再点后山收隼
		GameState.pet_roster.erase("fox")
		GameState.pet_roster.erase("qing_sun")
		GameState.pet_sel = ""
		GameState.pet_follow = ""
		GameState._pet_sync()
		_story_start("backhill")
		print("[主界面][测试] 重播宠链：狐隼已摘、后山剧情重开（村况抬到 1：后山头一片云该开了）")
		return
	if ke.keycode == KEY_M:
		GameState.vault_test_fill()
		if _warehouse != null:
			_warehouse.refresh()
		print("[主界面][测试] 仓库塞了测试货，库里残卡 ", GameState.vault_total(), " · 成品 ", GameState.vault_item_total())
		return
	if ke.keycode == KEY_T:
		GameState.idle_debug_add(3600)
		_refresh_idle_btn()
		_show_toast("[测试] 挂机池 +1 小时（现 " + _fmt_min(GameState.idle_pool_min()) + "）")
		print("[主界面][测试] 挂机池 +3600 秒，现 ", GameState.idle_pool_min(), " 分")
		return
	if ke.keycode == KEY_Y:
		GameState.idle_debug_add(GameState.IDLE_CAP_SEC)
		_refresh_idle_btn()
		_show_toast("[测试] 挂机池灌满（" + _fmt_min(GameState.idle_pool_min()) + "）——点「挂机」木牌收取")
		print("[主界面][测试] 挂机池灌满，现 ", GameState.idle_pool_min(), " 分")
		return
	if ke.keycode == KEY_G:
		GameState.debug_unlock_chain()
		if GameState.wines.is_empty():
			GameState.wine_give_chenniang()
		if _winery_panel != null:
			_winery_panel.refresh()
		if _alchemy_panel != null:
			_alchemy_panel.refresh()
		_show_toast("[测试] 建筑链 + 炼丹链全解锁：灵草各+2 · 银两+100 · 送一坛「陈酿」", 3.0)
		print("[主界面][测试] G：建筑链+炼丹链全解锁（灵草/丹阁/材料）")
		return
	if ke.keycode == KEY_H:
		var wn := GameState.debug_give_wine()
		if _winery_panel != null:
			_winery_panel.refresh()
		_show_toast("[测试] 塞了一坛「" + wn + "」（共 " + str(GameState.wines.size()) + " 坛）")
		return
	if ke.keycode == KEY_C:
		GameState.debug_alchemy_fill()
		if _alchemy_panel != null:
			_alchemy_panel.refresh()
		_show_toast("[测试] 灵草各 +2 · 炼丹阁解锁 · 收下陈石", 2.8)
		return
	if ke.keycode == KEY_V:
		if GameState.alchemy_rush():
			_show_toast("[测试] 炉火快进——丹成了，去收")
		else:
			_show_toast("[测试] 炉子是空的")
		if _alchemy_panel != null:
			_alchemy_panel.refresh()
		return
	if ke.keycode == KEY_X:
		GameState.stage_progress = GameState.STAGE_MAX - 1
		_show_toast("[测试] 进度推到第 " + str(GameState.STAGE_MAX) + " 关——打完它通关（灵草剧情在第 " + str(HERB_STAGE) + " 关，漏了下次进村会补放）", 3.2)
		print("[主界面][测试] stage_progress=", GameState.stage_progress)
		return
	# ---- v63：「困兽」试玩入口（新独立模式）----
	#   v63n（用户："困兽也开启不了"）：原来挂在 K 上，但 K 早被"后山·重播宠链"
	#   （本函数前面那一段）抢先 return 了 ✗——K 永远到不了这里。改挂 **E** 键。
	#   v147：**E 改成开 v2 主界面空壳**（kushou/kushou_v2.gd，设计稿见 docs/困兽_主界面设计稿.md），
	#     老的 v1 试玩挪到 **Shift+E**（还能进，方便对照）。
	if ke.keycode == KEY_E:
		if ke.shift_pressed:
			if _kushou == null:
				_kushou = (preload("res://kushou/kushou_mode.gd") as GDScript).new()
				add_child(_kushou)
			_kushou.visible = true
			_kushou.move_to_front()
			_show_toast("[困兽·v1 旧试玩] Shift+E 进的是旧版牌桌")
			return
		_open_kushou_v2()
		_show_toast("[困兽·v2] 主界面空壳——按钮/字都按大的排，H 扣血、B 叫 boss")
		return
	# ---- v63d（用户："给个快捷键让我直接过引子"）：U = 跳引子（已挪进 _input，v63j）----
	# ---- v63m（用户："主角团还差一人，三人阵要测"）：S = 直接招苏青鸾入队 ----
	#   不用打 150 关剧情——入队+自动上阵（满三人为止），正好测"三人抽不抽搐"。
	if ke.keycode == KEY_S:
		if GameState.qingluan_joined:
			_show_toast("[测试] 苏青鸾已在队", 2.0)
		else:
			var jmsg := GameState.join_qingluan()
			if _char_panel != null:
				_char_panel.refresh()
			_show_toast("[测试] " + jmsg, 3.2)
			print("[主界面][测试] S：", jmsg)
		return
	# ---- v42：测试键补一排**数字键**（用户："我想测关卡和鉴宝行都不行了"）----
	#   1/2/3/4/5 = 进度直接跳到"某个剧情关的**前一关**"（进村就会把剧情补放出来）：
	#     1 → 49（女侠前）· 2 → 149（女侠前）· 3 → 299（灵草前）· 4 → 399（鉴宝行前）· 5 → 499（更后一档）
	#   0 = 进度归零（回第 1 关，重走一遍前期）
	#   6 = 推进度 +25 关（细调用）· 7 = 推进度 −25 关
	#   8 = 直接给「新手关卡礼包」（不用重走引子）· 9 = 直接开鉴宝行（跳过 400 关剧情）
	if ke.keycode >= KEY_0 and ke.keycode <= KEY_9:
		var digit := int(ke.keycode) - int(KEY_0)
		match digit:
			0:
				GameState.stage_progress = 0
				_show_toast("[测试] 进度归零——回第 1 关重走", 2.4)
			1:
				GameState.stage_progress = NVXIA_STAGE - 101   # 49
				_show_toast("[测试] 进度推到 " + str(GameState.stage_progress) + " 关（下一关 50 = 藏宝图剧情）", 3.0)
			2:
				GameState.stage_progress = NVXIA_STAGE - 1
				_show_toast("[测试] 进度推到 " + str(GameState.stage_progress) + " 关（下一关 150 = 女侠剧情）", 3.0)
			3:
				GameState.stage_progress = HERB_STAGE - 1
				_show_toast("[测试] 进度推到 " + str(GameState.stage_progress) + " 关（下一关 300 = 灵草剧情）", 3.0)
			4:
				GameState.stage_progress = JIANBAO_STAGE - 1
				_show_toast("[测试] 进度推到 " + str(GameState.stage_progress) + " 关（下一关 400 = 打捞货仓 · 鉴宝行剧情）", 3.4)
			5:
				GameState.stage_progress = 499
				_show_toast("[测试] 进度推到 499 关（测后期赏格/宝箱）", 2.8)
			6:
				GameState.stage_progress = mini(GameState.STAGE_MAX - 1, GameState.stage_progress + 25)
				_show_toast("[测试] 进度 +25 → " + str(GameState.stage_progress) + " 关", 2.0)
			7:
				GameState.stage_progress = maxi(0, GameState.stage_progress - 25)
				_show_toast("[测试] 进度 −25 → " + str(GameState.stage_progress) + " 关", 2.0)
			8:
				var g := GameState.grant_stage_gift()
				_show_toast("[测试] " + ("新手关卡礼包已放进仓库（" + str(GameState.stage_gift_opened) + "/3 已开）" if g == "" else g), 3.0)
			9:
				var jm := GameState.jianbao_unlock()
				_show_toast("[测试] " + jm, 3.4)
		print("[主界面][测试] 数字键 ", digit, " → stage_progress=", GameState.stage_progress,
			" 鉴宝行=", GameState.jianbao_ok(), " 礼包=", GameState.stage_gift_got)
		if _alchemy_panel != null:
			_alchemy_panel.refresh()
		return
	if ke.keycode == KEY_P:
		GameState.debug_pet_fill()
		if _pet_panel != null:
			_pet_panel.refresh()
		_show_toast("[测试] 银两+200 · 兽骨碎×4 · 灵米×4 · 养灵丹×10 · 洗灵丹×3 · 同名份数各+3 · 绝品血脉一枚", 3.4)
		print("[主界面][测试] 宠物包：银两=", GameState.coin("silver"), " 骨=", GameState.material_count("bone"), " 米=", GameState.material_count("rice"), " 养灵丹=", GameState.pill_count("yangling"))
		return
	if ke.keycode == KEY_Q:
		if GameState.qingluan_joined:
			GameState.qingluan_joined = false
			_story_start("qingluan")
			print("[主界面][测试] 重播女侠剧情")
		else:
			GameState.stage_progress = NVXIA_STAGE - 1
			_show_toast("[测试] 进度推到 " + str(NVXIA_STAGE - 1) + " 关——再打一场（第 " + str(NVXIA_STAGE) + " 关）就能遇见她", 2.8)
			print("[主界面][测试] stage_progress=", GameState.stage_progress)
		return
	if ke.keycode == KEY_N:
		_season = (_season + 1) % 4
		if _mist != null:
			_mist.set_season(_season)
		_sync_ambient()
		_season_lock = true
		_show_toast("[测试] 季节预览「" + str(SEASON_CN[_season]) + "」——看卷面动静", 2.6)
		print("[主界面][测试] 季节预览：", SEASON_CN[_season])
		return
	if ke.keycode == KEY_O:
		# ㉘：把当前所有可调旋钮写成一份带说明的配置文件（数值外置）
		var tf := GameState.tuning_write_example()
		if tf == "":
			_show_toast("[调参] 写配置失败——看控制台", 3.0)
		else:
			_show_toast("[调参] 配置已写出——路径见控制台；改完重启游戏生效", 3.4)
		return
	if ke.keycode == KEY_F9:
		# v139（测试）：**不碰存档**，直接重播引子——调剧情时用这个，不用清档。
		#   游历场那边认 GameState.intro_force，只在"没有出征交接"的裸进时才生效。
		GameState.intro_force = true
		print("[主界面][测试] F9：强制重播引子（存档不动）")
		_boot_journey()
		return
	if ke.keycode == KEY_Z:
		GameState.add_material("common", 3)
		GameState.add_material("forge_stone", 30)
		GameState.add_material("iron_sand", 20)
		GameState.add_material("bone_coal", 10)
		GameState.add_material("forge_oil", 3)
		GameState.add_material("fine_iron", 2)
		GameState.add_material("meteor_iron", 3)
		GameState.add_material("cold_iron", 2)
		GameState.add_material("star_iron", 1)
		GameState.save_game()
		_show_toast("测试：剑胚+3 · 锻造石+30 · 锻造材料一包", 2.4)
		return
	if ke.keycode == KEY_J:
		# ㉙：存档版本自检——模拟"盘上是新版档"，看会不会改名留档而不是静默丢。
		# 用探针文件，不碰真档。结果看控制台 [自检] 那几行。
		GameState.debug_version_probe()
		_show_toast("[自检] 存档版本迁移——结果看控制台", 3.0)
		return
	if ke.keycode == KEY_R:
		# 优化批㉒：重置测试键——防误触：3 秒内连按两次才真清
		# ㉖：再加一道闸——清档是唯一不可挽回的操作，默认只在编辑器里放行（见 ALLOW_SAVE_WIPE）
		if not ALLOW_SAVE_WIPE and not OS.has_feature("editor"):
			print("[主界面][测试] R 已挡下：这个包不是编辑器跑的，清档闸关着（想放开改 ALLOW_SAVE_WIPE）")
			_show_toast("[测试] R 键清档在导出包里被挡住了——要清档请改 ALLOW_SAVE_WIPE", 3.0)
			return
		var now_ms := Time.get_ticks_msec()
		if _reset_arm > 0 and now_ms - _reset_arm <= 3000:
			_reset_arm = 0
			GameState.reset_full()
			_tag_notice = -1
			_show_toast("[测试] 已重置全部存档——一切从头开始（再按 R 还能清一次）", 3.2)
			print("[主界面][测试] reset_full：全档已清")
		else:
			_reset_arm = now_ms
			_show_toast("[测试] 再按一次 R 确认重置全部存档（3 秒内）", 2.4)
		return
	if ke.keycode != KEY_W:
		return
	var w := get_window()
	if w.size.y < 1000:
		var ur := DisplayServer.screen_get_usable_rect()
		var hh := mini(1240, ur.size.y - 60)
		w.size = Vector2i(700, hh)
		w.position = Vector2i(ur.position.x + 20, ur.position.y + 30)
	else:
		w.size = Vector2i(1152, 648)

func _process(delta: float) -> void:
	_t += delta * Conf.TIME_SCALE
	if _forge_wait > 0.0:
		_forge_wait -= delta
		if _forge_wait <= 0.0:
			var wk := _forge_wait_kind
			_forge_wait_kind = ""
			match wk:
				"free":
					_forge_say("铁匠", "剩下的，你自己来。手稳心定，别贪。")
				"speech":
					_forge_panel.tutorial_pause(false)
					_forge_say("铁匠", "抓紧！")
					_forge_guide_to(_forge_panel.inspire_bar_rect())
				"stop":
					_forge_say("铁匠", "此剑静待冷却。一会儿我给壮士送来。")
					_forge_guide_to(_forge_panel.anvil_rect())
				"end":
					_forge_tut_end()
	if _forge_blank_step and _forge_panel != null and _forge_panel._blank_panel.visible:
		_forge_guide_to(_forge_panel.blank_card_rect("wpn_0"))
	if _forge_guide != null and _forge_guide.visible:
		_forge_guide.queue_redraw()
	if _craft_guide != null:
		_craft_guide.queue_redraw()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast_t = 0.0
			_toast = ""
	if _money_hud != null:
		_money_hud.silver = GameState.coin("silver")
		_money_hud.yuanbao = GameState.coin("yuanbao")
		# v211：顶栏墨带随牌子层一起收（面板/剧情），钱条别单独挂在半空
		_money_hud.visible = _story_page < 0 and not _any_panel_open()
	_money_clock += delta
	if _money_clock >= 0.5:
		_money_clock = 0.0
		_refresh_idle_btn()
	_idle_clock += delta
	if _idle_clock >= 20.0:
		_idle_clock = 0.0
		GameState.idle_sync()
		GameState.save_game()   # 优化批㉒：20 秒一次的兜底落盘
		# ㊼：在线挂机现在也会推塔了（idle_sync 里驱动）——推了就当场在村里报一声。
		#   以前只有"进村那一刻"会报，在线推的那些没人说，玩家看不到。
		var cnote := GameState.take_offline_note()
		if cnote != "" and _story_page < 0:
			print("[主界面] 在线挂机：", cnote)
			_show_toast(cnote, 3.6)
	_season_clock += delta
	if _season_clock >= 30.0:
		_season_clock = 0.0
		if not _season_lock:
			var s := _season_now()
			if s != _season:
				_season = s
				if _mist != null:
					_mist.set_season(_season)
				_sync_ambient()
				_show_toast("换季——" + str(SEASON_ARRIVE[_season]), 3.2)
	if not _demo_done:
		# v62（用户："同时画卷也可以缩一些"）：开场那次"画卷推过去"原来 1.2 秒等待 +
		#   1.8 秒推 150 像素（共 3 秒），进屋先看三秒空镜。现在 **0.35 秒 + 0.7 秒推 60 像素**，
		#   一眨眼就到位，只剩一点"画展开卷"的意思。
		_demo_clock += delta
		var p := clampf((_demo_clock - 0.35) / 0.7, 0.0, 1.0)
		if p >= 1.0:
			_demo_done = true
			_cam = Conf.OPEN_CAM
			if INK_ONLY:
				_sc = Conf.DW
		elif p > 0.0:
			_cam = Conf.OPEN_CAM - 60.0 * sin(PI * p)
			if INK_ONLY:
				_sc = Conf.DW - 60.0 * sin(PI * p)   # 开屏"展一下卷"，再停在封面页
	if Ui.SKIN == 1 and not _skinned and _t > 0.4:
		_skinned = true
		_skin_pass()
	if INK_ONLY:
		var on_cover := _sc > Conf.DW * 0.45
		if on_cover != _cover_mode:
			_cover_mode = on_cover
			_refresh_plaques()
	_apply_layer_transforms()
	_check_panel_anim()
	# v220：底排金线——哪个面板开着，哪一格亮
	var tp := _top_panel()
	var at := -1
	if tp == _depart:
		at = 0
	elif tp == _char_panel:
		at = 1
	elif tp == _warehouse:
		at = 2
	elif tp == _pet_panel:
		at = 3
	elif tp == _chest_panel:
		at = 4
	elif tp == _insight_panel:
		at = 5
	_active_tag = at
	queue_redraw()

# v211（用户："需要动的也动起来"）：面板开场——scale 0.96→1 + alpha，0.18s TRANS_BACK。
#   放在这里做"全局一份"，各个面板的 open() 不用各写一遍。
func _check_panel_anim() -> void:
	var now := _any_panel_open()
	if now == _last_panel_open:
		return
	_last_panel_open = now
	if not now:
		return
	var pn: Control = _top_panel()
	if pn == null:
		return
	Audio.sfx("ui_open", -16.0, 1.0)
	pn.pivot_offset = pn.size * 0.5
	pn.scale = Vector2(0.96, 0.96)
	pn.modulate.a = 0.0
	var tw := pn.create_tween()
	tw.set_parallel(true)
	tw.tween_property(pn, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pn, "modulate:a", 1.0, 0.15)

# 最上层的那个面板（后建的在上；作坊面板叠在百工坊门厅之上）
func _top_panel() -> Control:
	var arr: Array = [_insight_panel, _winery_panel, _alchemy_panel, _forge_panel, _appraise_panel, _star_panel,
		_pet_panel, _shop_panel, _chest_panel, _craft_panel, _warehouse, _char_panel,
		_out_panel, _formation, _depart]
	for p in arr:
		var c: Control = p as Control
		if c != null and is_instance_valid(c) and c.visible:
			return c
	return null

# ============================================================
# v206 · 全局换皮扫描：把各面板自己造的"纸面大板"统一改成
#   近方角 + 金线（影之刃的板是硬的，不是圆卡片）。
#   只动**浅色 + 大圆角**的 StyleBoxFlat —— 格子(半径 8)、印章、彩色条不碰。
#   注：直接改 StyleBoxFlat 实例（节点上挂的就是它，改一次全局生效）。
# ============================================================
func _skin_pass() -> void:
	var stack: Array = [self]
	var n_panel := 0
	var n_label := 0
	var n_heads := 0
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Label:
			# 面板大标题统一毛笔字（纯汉字、无数字的短标题才算）
			var lb := n as Label
			var fs2: int = lb.get_theme_font_size("font_size")
			var t2 := lb.text.strip_edges()
			var pure_cjk := t2.length() > 0 and t2.length() <= 8
			for ch in t2:
				if ch.is_valid_int() or ch == "." or ch == "%" or ch == "/" or ch == ":":
					pure_cjk = false
					break
			if fs2 >= 26 and pure_cjk and lb.get_theme_color("font_color").v < 0.45:
				var bf2 := Ui.brush_font()
				if bf2 != null:
					lb.add_theme_font_override("font", bf2)
					n_label += 1
		if n is Panel:
			var pn := n as Panel
			var sb: StyleBox = pn.get_theme_stylebox("panel")
			if sb is StyleBoxFlat:
				var s := sb as StyleBoxFlat
				if s.corner_radius_top_left >= 10 and s.bg_color.v > 0.72 and s.bg_color.a > 0.8:
					# v208（用户："怎么感觉和原版差不多"）：问题不在细节，在**大色块**——
					#   1px 金线在 450 宽的截图上只有 0.6 像素，压根看不见。
					#   所以把整块面板翻成玄墨底 + 3px 金框，再把这板上的深色字提成纸白。
					s.set_corner_radius_all(4)
					s.border_color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.55)
					s.set_border_width_all(2)
					n_panel += 1

			# v207：给"有标题的面板"自动补一条刊头（已经手工做过的跳过：
			#   判据＝标题字已经是亮金，或面板上已挂 skin_header 标记）
			if pn.size.x >= 380.0 and not pn.has_meta("skin_header"):
				var tlb: Label = null
				for c in pn.get_children():
					if c is Label:
						var l2 := c as Label
						if l2.position.y < 45.0 and l2.get_theme_font_size("font_size") >= 26:
							tlb = l2
							break
				if tlb != null and tlb.get_theme_color("font_color").v < 0.6:
					# 标题底下若还有一行小字（副题/说明），刊头就收矮，别把人家的字盖掉
					var hh := 78.0
					for c3 in pn.get_children():
						if c3 is Label:
							var l4 := c3 as Label
							if l4 != tlb and l4.position.y > 46.0 and l4.position.y < 108.0 									and l4.get_theme_font_size("font_size") < 24:
								hh = 52.0
								break
					var ch2 := Control.new()
					ch2.size = pn.size
					ch2.mouse_filter = Control.MOUSE_FILTER_IGNORE
					var pw: float = pn.size.x
					var ph: float = 78.0     # 固定 78：标题(34号，y18起)正好装下
					ch2.draw.connect(func() -> void: Ui.header(ch2, pw, ph))
					pn.add_child(ch2)
					pn.move_child(ch2, 0)
					pn.set_meta("skin_header", true)
					tlb.add_theme_color_override("font_color", Ui.GOLD_HI)
					n_heads += 1
					# 刊头带里的其它深色字（副标题/银两那些）一起提亮，免得墨底墨字看不见

	print("[主界面] 换皮扫描：", n_panel, " 块面板 / ", n_label, " 个标题 / ", n_heads, " 条刊头")

func _zoom() -> float:
	return maxf(minf(size.x / Conf.DW, size.y / Conf.DH), 0.01)

func _origin() -> Vector2:
	return (size - Vector2(Conf.DW, Conf.DH) * _zoom()) * 0.5

func _dpos(p: Vector2) -> Vector2:
	return (p - _origin()) / _zoom()

func _disciple_ready() -> bool:
	return GameState.disciple_joined

func _out_vis() -> bool:
	return _cam <= Conf.CAM_MIN + 140.0 and _story_page < 0 and not _any_panel_open()

func _any_panel_open() -> bool:
	var a: bool = _char_panel != null and _char_panel.visible
	var b: bool = _warehouse != null and _warehouse.visible
	var c: bool = _out_panel != null and _out_panel.visible
	var d: bool = _formation != null and _formation.visible
	var e: bool = _battle != null and is_instance_valid(_battle)
	var f: bool = _winery_panel != null and _winery_panel.visible
	var g: bool = _alchemy_panel != null and _alchemy_panel.visible
	var h: bool = _star_panel != null and _star_panel.visible
	var i: bool = _pet_panel != null and _pet_panel.visible
	var j: bool = _shop_panel != null and _shop_panel.visible
	var k: bool = _depart != null and _depart.visible
	# v4.2：宝箱专页也算"面板开着"——不然宝箱页底下还能点出村/点人
	var l: bool = _chest_panel != null and _chest_panel.visible
	# v39：鉴宝行也算"面板开着"
	var m: bool = _appraise_panel != null and _appraise_panel.visible
	# v50：百工坊门厅也算"面板开着"
	var n2: bool = _craft_panel != null and _craft_panel.visible
	var p2: bool = _forge_panel != null and _forge_panel.visible
	# v220：阅历线面板也补进来（原来漏了，开着时底下还能点）
	var o2: bool = _insight_panel != null and _insight_panel.visible
	return a or b or c or d or e or f or g or h or i or j or k or l or m or n2 or o2 or p2

func _chen_visible() -> bool:
	return GameState.disciple_joined and _story_page < 0 and not _any_panel_open()

func _qingluan_visible() -> bool:
	return GameState.qingluan_joined and _story_page < 0 and not _any_panel_open()

func _open_warehouse() -> void:
	print("[主界面] 打开仓库")
	_clear_toast()
	_warehouse.open()

func _open_chests() -> void:
	print("[主界面] 宝箱")
	if _chest_panel != null:
		_clear_toast()
		_chest_panel.open()

# 关掉宝箱页后：出村屏上那个［宝箱 ×N］的数是旧的（它只在 open() 时刷），补一下
func _on_chest_closed() -> void:
	if _out_panel != null and _out_panel.visible:
		_out_panel.refresh()

func _open_out() -> void:
	print("[主界面] 出村面板")
	_clear_toast()
	_out_panel.open()

# 重做期：教学关 v0——底排「出村」直接进（暂时绕过出村面板）
func _open_tutorial() -> void:
	_clear_toast()
	if _tutorial == null:
		_tutorial = TutorialStage.new()
		_tutorial.closed.connect(_on_tutorial_closed)
		add_child(_tutorial)
	_tutorial.open()
	_tutorial.move_to_front()
	_show_toast("教学关（临时入口）：村口 · 5 波", 2.4)

func _on_tutorial_closed() -> void:
	var loot := 0
	if _tutorial != null:
		loot = int(_tutorial.loot_silver)
		_tutorial.queue_free()
		_tutorial = null
	Audio.play_bgm(Audio.menu_track(), 1.0)
	_seg2_loot = loot if loot > 0 else 50
	_ask_skip_segment(2, _seg2_play, _seg2_skip)


# ============================================================
# 引导段落：段前问「是否跳过引导剧情？」；跳过只落该段完成态
# ============================================================
func _ask_skip_segment(_n: int, on_play: Callable, on_skip: Callable) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.z_index = 72
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var box := Panel.new()
	box.position = Vector2(90.0, 455.0)
	box.size = Vector2(540.0, 300.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.955, 0.937, 0.886, 0.99)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.72, 0.58, 0.25, 0.8)
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(box)
	var t := Label.new()
	t.text = "是否跳过引导剧情？"
	t.position = Vector2(0, 44)
	t.size = Vector2(540, 46)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", _font)
	t.add_theme_font_size_override("font_size", 27)
	t.add_theme_color_override("font_color", Color(0.14, 0.13, 0.15))
	box.add_child(t)
	var sub := Label.new()
	sub.text = "跳过只跳这一段"
	sub.position = Vector2(0, 100)
	sub.size = Vector2(540, 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", _font)
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.30, 0.26, 0.20, 0.55))
	box.add_child(sub)
	var b_skip := UiKit.make_button(box, Vector2(60, 180), Vector2(190, 70), "跳 过", 24)
	var b_play := UiKit.make_button(box, Vector2(290, 180), Vector2(190, 70), "继 续 看", 24)
	b_skip.pressed.connect(func() -> void:
		root.queue_free()
		on_skip.call()
	)
	b_play.pressed.connect(func() -> void:
		root.queue_free()
		on_play.call()
	)


func _seg1_skip() -> void:
	GameState.first_journey_done = true
	GameState.save_game()
	_seg2_loot = 50
	_ask_skip_segment(2, _seg2_play, _seg2_skip)


func _seg2_play() -> void:
	_seg2_playing = true
	_show_loot_popup(_seg2_loot)


func _seg2_skip() -> void:
	GameState.add_coin("silver", _seg2_loot)
	if _money_hud != null:
		_money_hud.silver = GameState.coin("silver")
	GameState.first_journey_done = true
	GameState.cave_opened = true
	GameState.winery_built = true
	_grant_forge_sword()
	GameState.forge_tut_done = true
	GameState.save_game()
	_refresh_plaques()
	_seg3_prompt()


func _seg3_prompt() -> void:
	_ask_skip_segment(3, _seg3_play, _seg3_skip)


func _seg3_play() -> void:
	_show_dialogue([
		{"who": "旁白", "text": "不多时，铁匠送来武器。"},
		{"who": "铁匠", "text": "壮士，剑冷好了。壮士可以看看这把武器。"},
		{"who": "旁白", "text": "你接过长剑，开始观摩。"},
	], _seg3_unlock)


func _seg3_unlock() -> void:
	_bag_unlocked = true
	_seg3_seen = true
	_layout_tags()
	_refresh_plaques()
	_show_tag_guide(2, "行囊")
	_show_toast("点下面「行囊」，看看这把剑", 3.0)


func _seg3_skip() -> void:
	_bag_unlocked = true
	_seg3_seen = false
	_layout_tags()
	_refresh_plaques()
	_seg4_prompt()



func _seg4_intro() -> void:
	_show_dialogue([
		{"who": "旁白", "text": "这里是装备武器装备的地方，一共四个装备类型。"},
		{"who": "旁白", "text": "武器管攻击与伤害，护甲管气血，玉佩管暴击与爆伤，鞋子管速度。"},
		{"who": "旁白", "text": "少侠的出手是「物理」——四栏的加成，最后都落在这一下上。"},
		{"who": "旁白", "text": "功法固定在每个人身上，不能换；家传绝学，则是所有人共用的一格。"},
	], _seg4_guide_start)

func _seg4_guide_start() -> void:
	if _char_panel != null:
		_char_panel.start_guide()


func _seg4_guide_done() -> void:
	if not _seg4_seen:
		return
	_seg4_seen = false
	_seg4_end()


func _seg4_prompt() -> void:
	if _seg4_ended:
		return
	_ask_skip_segment(4, _seg4_play, _seg4_skip)


func _seg4_play() -> void:
	_role_unlocked = true
	_seg4_seen = true
	_layout_tags()
	_refresh_plaques()
	_show_tag_guide(1, "角色")
	_show_toast("点下面「角色」，看看四栏装备", 3.0)


func _seg4_skip() -> void:
	_role_unlocked = true
	_layout_tags()
	_refresh_plaques()
	_seg4_end()


func _seg4_end() -> void:
	if _seg4_ended:
		return
	_seg4_ended = true
	_seg4_seen = false
	_show_toast("引导完成——百工坊、行囊、角色都开了", 3.0)


func _on_forge_closed() -> void:
	if not _seg2_playing:
		return
	_seg2_playing = false
	_grant_forge_sword()
	GameState.forge_tut_done = true
	GameState.save_game()
	_seg3_prompt()


func _on_warehouse_closed() -> void:
	if not _seg3_seen:
		return
	_seg3_seen = false
	_seg4_prompt()


func _on_char_closed() -> void:
	if not _seg4_seen:
		return
	_seg4_seen = false
	_seg4_end()


func _grant_forge_sword() -> void:
	for b_v in GameState.forge_bag:
		var b: Dictionary = b_v
		if str(b.get("blank", "")) == "wpn_0":
			return
	var it: Dictionary = ForgeData.make_item("wpn_0")
	if it.is_empty():
		return
	it["craft_grade"] = 2
	it["finished"] = true
	var sid: String = GameState.forge_next_sid()
	var set: Dictionary = ForgeData.card_set(it, sid)
	GameState.forge_add(sid, set)
	it["sid"] = sid
	GameState.forge_bag.append(it.duplicate(true))


func _show_tag_guide(i: int, text: String) -> void:
	if i < 0 or i >= _tag_rects.size():
		return
	_end_craft_guide()
	_craft_guide_rect = _tag_rects[i]
	_craft_guide_text = text
	_craft_guide_step = "tag"
	var g := Control.new()
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.z_index = 48
	g.draw.connect(_draw_craft_guide)
	add_child(g)
	_craft_guide = g


func _show_loot_popup(amount: int) -> void:
	if _loot_pop != null:
		return
	var pop := Control.new()
	pop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pop.z_index = 50
	pop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pop)
	_loot_pop = pop
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.03, 0.58)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pop.add_child(dim)
	var box := Panel.new()
	box.position = Vector2(120.0, 410.0)
	box.size = Vector2(480.0, 300.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.955, 0.937, 0.886, 0.98)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.72, 0.58, 0.25, 0.75)
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	pop.add_child(box)
	var title := Label.new()
	title.position = Vector2(0.0, 28.0)
	title.size = Vector2(480.0, 40.0)
	title.text = "匪首身上"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.68, 0.15, 0.12))
	box.add_child(title)
	var line := Label.new()
	line.position = Vector2(40.0, 92.0)
	line.size = Vector2(400.0, 80.0)
	line.text = "你从匪首那里摸到了些许银两。"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_override("font", _font)
	line.add_theme_font_size_override("font_size", 22)
	line.add_theme_color_override("font_color", Color(0.14, 0.13, 0.15))
	box.add_child(line)
	var amt := Label.new()
	amt.position = Vector2(0.0, 168.0)
	amt.size = Vector2(480.0, 34.0)
	amt.text = "银两 +" + str(amount)
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amt.add_theme_font_override("font", _font)
	amt.add_theme_font_size_override("font_size", 20)
	amt.add_theme_color_override("font_color", Color(0.72, 0.58, 0.22))
	box.add_child(amt)
	var btn := UiKit.make_button(box, Vector2(150.0, 220.0), Vector2(180.0, 52.0), "收下", 22)
	btn.pressed.connect(func() -> void:
		Audio.sfx("ui_click", -10.0)
		pop.queue_free()
		_loot_pop = null
		_start_loot_coins(amount)
	)


func _start_loot_coins(amount: int) -> void:
	var anchor := Vector2(364.0, 49.0)
	if _money_hud != null:
		anchor = _money_hud.position + _money_hud.silver_anchor() * _money_hud.scale
	var fx := LootFx.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.z_index = 60
	add_child(fx)
	_loot_fx = fx
	var pack := {"left": amount}
	fx.on_land = func() -> void:
		var add := mini(5, int(pack["left"]))
		if add <= 0:
			return
		pack["left"] = int(pack["left"]) - add
		GameState.add_coin("silver", add)
		if _money_hud != null:
			_money_hud.silver = GameState.coin("silver")
		Audio.sfx("coin", -8.0, randf_range(0.92, 1.08))
		if int(pack["left"]) <= 0:
			GameState.save_game()
			Audio.sfx("coin", -3.0, 0.8)
			_show_loot_float(anchor, amount)
	fx.all_landed.connect(func() -> void:
		if is_instance_valid(fx):
			fx.queue_free()
		if _loot_fx == fx:
			_loot_fx = null
		_show_chief_story()
	)
	fx.start(10, Vector2(360.0, 520.0), anchor)


func _show_chief_story() -> void:
	_show_dialogue([
		{"who": "旁白", "text": "村长拄着拐杖，从巷口匆匆赶来。"},
		{"who": "村长", "text": "壮士！壮士出手相救，老朽替全村上下，谢过壮士。"},
		{"who": "村长", "text": "只是……匪人吃了这么大的亏，怕不会善罢甘休。"},
		{"who": "村长", "text": "壮士若不嫌弃，今晚就留在村里。村里，还需壮士助一臂之力。"},
		{"who": "少侠", "text": "……有心无力。剑断了，剑法使不出来。如今的我，只剩几成实力。"},
		{"who": "村长", "text": "剑断了？村里正好有间铁匠铺。老朽带壮士去看看。"},
		{"who": "旁白", "text": "不多时，村长带着主角走到了百工坊旁。"},
		{"who": "村长", "text": "到了，就是这里。"},
	], _start_craft_guide)


func _show_forge_story() -> void:
	if _forge_story_done:
		return
	_forge_story_done = true
	_show_dialogue([
		{"who": "旁白", "text": "炉火正旺。你看见一个赤膊汉子站在砧前，一锤接一锤，火星四溅。"},
		{"who": "旁白", "text": "村长喊了一声。那人放下锤，转过身来。"},
		{"who": "旁白", "text": "村长把村口的事，从头到尾说了一遍。"},
		{"who": "旁白", "text": "铁匠沉吟片刻。"},
		{"who": "铁匠", "text": "我这里倒是有少侠需要的胚子。"},
		{"who": "铁匠", "text": "不过，上好的胚子，要与主人人器合一。得由主人亲手锻造，才发挥得出最完美的威力。"},
		{"who": "少侠", "text": "我不会，怎么办？"},
		{"who": "铁匠", "text": "这个简单。我指导你就行。"},
	], _start_forge_tut)



# ============================================================
# 铁匠教学：20 锻造石 + 50 两 → 四锤 → 自由锤 → 入神 → 停炉 → 卸下
# ============================================================
func _start_forge_tut() -> void:
	if _forge_tut_done or _forge_panel == null or GameState.forge_tut_done:
		return
	_forge_tut_done = true
	_show_dialogue([
		{"who": "铁匠", "text": "锻造石我这儿还有些，先拿二十块去用。"},
		{"who": "少侠", "text": "这怎么好意思。您教我手艺，还倒贴材料……"},
		{"who": "少侠", "text": "这些银两，您收下。"},
		{"who": "铁匠", "text": "使不得。"},
		{"who": "少侠", "text": "您不收，我这锤落不下去。"},
		{"who": "铁匠", "text": "……也罢。"},
	], _forge_tut_begin)


func _forge_tut_begin() -> void:
	GameState.add_material("forge_stone", 20)
	GameState.add_coin("silver", -50)
	GameState.add_material("wpn_0", 1)
	GameState.save_game()
	if _money_hud != null:
		_money_hud.silver = GameState.coin("silver")
		_money_hud.yuanbao = GameState.coin("yuanbao")
	Audio.sfx("coin", -8.0)
	_forge_panel.refresh()
	_forge_tut = true
	_forge_panel.tutorial_mode = true
	_forge_panel.tutorial_pause(false)
	_forge_panel.tutorial_set_no_break(false)
	if not _forge_panel.blank_picker_opened.is_connected(_forge_on_picker):
		_forge_panel.blank_picker_opened.connect(_forge_on_picker)
		_forge_panel.blank_picked.connect(_forge_on_blank)
		_forge_panel.tutorial_hammered.connect(_forge_on_hammer)
		_forge_panel.tutorial_inspire_start.connect(_forge_on_inspire)
		_forge_panel.tutorial_inspire_end.connect(_forge_on_inspire_end)
		_forge_panel.tutorial_unloaded.connect(_forge_on_unload)
	_forge_box_build()
	_forge_guide_build()
	_forge_guide_to(_forge_panel.anvil_rect())
	_forge_say("铁匠", "先挑一块胚子。点砧子，把家伙摆上来。")


func _forge_box_build() -> void:
	if _forge_box != null:
		return
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 56
	add_child(root)
	_forge_box = root
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.10)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var box := Panel.new()
	box.position = Vector2(30, 830)
	box.size = Vector2(660, 290)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.955, 0.937, 0.886, 0.98)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.72, 0.58, 0.25, 0.75)
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	_forge_box_name = Label.new()
	_forge_box_name.position = Vector2(40, 24)
	_forge_box_name.size = Vector2(560, 36)
	_forge_box_name.add_theme_font_override("font", _font)
	_forge_box_name.add_theme_font_size_override("font_size", 24)
	_forge_box_name.add_theme_color_override("font_color", Color(0.68, 0.15, 0.12))
	_forge_box_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_forge_box_name)
	_forge_box_text = Label.new()
	_forge_box_text.position = Vector2(40, 72)
	_forge_box_text.size = Vector2(580, 150)
	_forge_box_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_forge_box_text.add_theme_font_override("font", _font)
	_forge_box_text.add_theme_font_size_override("font_size", 22)
	_forge_box_text.add_theme_color_override("font_color", Color(0.14, 0.13, 0.15))
	_forge_box_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_forge_box_text)
	_forge_box.visible = false


func _forge_guide_build() -> void:
	if _forge_guide != null:
		return
	var g := Control.new()
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.z_index = 54
	g.draw.connect(_draw_forge_guide)
	add_child(g)
	_forge_guide = g


func _forge_say(who: String, text: String) -> void:
	if _forge_box == null:
		return
	_forge_box.visible = true
	_forge_box_name.text = who
	_forge_box_text.text = text


func _forge_guide_to(rc: Rect2) -> void:
	_forge_guide_rc = rc
	if _forge_guide != null:
		_forge_guide.visible = rc.size.x > 0.0


func _forge_guide_off() -> void:
	_forge_guide_rc = Rect2()
	if _forge_guide != null:
		_forge_guide.visible = false


func _draw_forge_guide() -> void:
	if _forge_guide == null or _forge_guide_rc.size.x <= 0.0:
		return
	var a := 0.55 + 0.35 * absf(sin(_t * 3.2))
	var gold := Color(0.86, 0.68, 0.26, a)
	var rc := _forge_guide_rc.grow(6.0)
	_forge_guide.draw_rect(rc, gold, false, 2.5)
	var c := 16.0
	_forge_guide.draw_line(rc.position, rc.position + Vector2(c, 0), gold, 4.0)
	_forge_guide.draw_line(rc.position, rc.position + Vector2(0, c), gold, 4.0)
	_forge_guide.draw_line(Vector2(rc.end.x, rc.position.y), Vector2(rc.end.x - c, rc.position.y), gold, 4.0)
	_forge_guide.draw_line(Vector2(rc.end.x, rc.position.y), Vector2(rc.end.x, rc.position.y + c), gold, 4.0)
	_forge_guide.draw_line(Vector2(rc.position.x, rc.end.y), Vector2(rc.position.x + c, rc.end.y), gold, 4.0)
	_forge_guide.draw_line(Vector2(rc.position.x, rc.end.y), Vector2(rc.position.x, rc.end.y - c), gold, 4.0)
	_forge_guide.draw_line(rc.end, rc.end - Vector2(c, 0), gold, 4.0)
	_forge_guide.draw_line(rc.end, rc.end - Vector2(0, c), gold, 4.0)
	var from := Vector2(360, 812)
	var to := _forge_guide_rc.get_center()
	if to.y > 810.0:
		to.y = _forge_guide_rc.position.y
	_forge_guide.draw_line(from, to, gold, 3.0)
	var dir := (to - from).normalized()
	var n := Vector2(-dir.y, dir.x)
	_forge_guide.draw_colored_polygon(PackedVector2Array([to, to - dir * 14.0 + n * 8.0, to - dir * 14.0 - n * 8.0]), gold)


func _forge_on_picker() -> void:
	if not _forge_tut:
		return
	_forge_blank_step = true
	_forge_say("铁匠", "你手上那块普通武器胚，底子干净，先拿它练手。")
	_forge_guide_to(_forge_panel.blank_card_rect("wpn_0"))


func _forge_on_blank(_bid: String) -> void:
	if not _forge_tut:
		return
	_forge_blank_step = false
	_forge_panel.tutorial_force(1)
	_forge_say("铁匠", "放上砧。第一锤，轻些。听个响就够。")
	_forge_guide_to(_forge_panel.hammer_rect())


func _forge_on_hammer(result: int) -> void:
	if not _forge_tut:
		return
	match result:
		1:
			_forge_panel.tutorial_force(2)
			_forge_say("铁匠", "好！第一锤见响了。不过记住——成功出得越多，下一锤再想成，就难一分。")
			_forge_guide_to(_forge_panel.hammer_rect())
		2:
			_forge_panel.tutorial_force(0)
			_forge_say("铁匠", "别灰心。维持不长进，可它把下一锤的成功、大成功往上垫。")
			_forge_guide_to(_forge_panel.hammer_rect())
		0:
			_forge_panel.tutorial_force(3)
			_forge_say("铁匠", "漂亮！大成功，锋口更利。可别飘——大成功之后，最容易吃损伤。")
			_forge_guide_to(_forge_panel.hammer_rect())
		3:
			_forge_panel.tutorial_set_no_break(true)
			_forge_guide_off()
			_forge_say("铁匠", "糟了。损伤会抬高破坏，锋口也要钝。再坏一次，胚子就废了。稳稳心态。")
			_forge_wait = 3.2
			_forge_wait_kind = "free"


func _forge_on_inspire() -> void:
	if not _forge_tut:
		return
	_forge_panel.tutorial_pause(true)
	_forge_say("铁匠", "这……入神！心神合一，锤下不损。可它撑不了多久——抓紧！")
	_forge_guide_to(_forge_panel.inspire_bar_rect())
	_forge_wait = 3.0
	_forge_wait_kind = "speech"


func _forge_on_inspire_end() -> void:
	if not _forge_tut:
		return
	_forge_panel.tutorial_stop()
	_forge_guide_off()
	_forge_say("铁匠", "这个装备已经很完美了，不能贪心。")
	_forge_wait = 2.8
	_forge_wait_kind = "stop"


func _forge_on_unload() -> void:
	if not _forge_tut:
		return
	_forge_pending_sword = _forge_panel.tutorial_taken_item()
	_forge_guide_off()
	_forge_say("铁匠", "一会儿我给壮士送来。")
	_forge_wait = 2.8
	_forge_wait_kind = "end"


func _forge_tut_end() -> void:
	_forge_tut = false
	_forge_panel.tutorial_mode = false
	_forge_panel.tutorial_pause(false)
	_forge_panel.tutorial_set_no_break(false)
	if _forge_box != null:
		_forge_box.visible = false
	_forge_guide_off()
	GameState.forge_tut_done = true
	GameState.save_game()
	_show_toast("剑留在铁匠铺冷却——铁匠随后送来", 3.0)


func _show_dialogue(lines: Array, on_done: Callable) -> void:
	if _chief_dlg != null:
		return
	_chief_lines = lines
	_chief_i = 0
	_chief_done = on_done
	var dlg := Control.new()
	dlg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dlg.z_index = 55
	dlg.mouse_filter = Control.MOUSE_FILTER_STOP
	dlg.gui_input.connect(func(ev: InputEvent) -> void:
		var clicked: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
		if clicked:
			_chief_advance()
	)
	add_child(dlg)
	_chief_dlg = dlg
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.46)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlg.add_child(dim)
	var box := Panel.new()
	box.position = Vector2(30.0, 830.0)
	box.size = Vector2(660.0, 290.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.955, 0.937, 0.886, 0.98)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.72, 0.58, 0.25, 0.75)
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlg.add_child(box)
	# 少侠说话时的圆牌立绘（纸底 + 金边 + 圆内头像）
	_chief_portrait = Control.new()
	_chief_portrait.position = Vector2(30.0, 54.0)
	_chief_portrait.size = Vector2(130.0, 130.0)
	_chief_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chief_portrait.visible = false
	box.add_child(_chief_portrait)
	_chief_portrait.draw.connect(func() -> void:
		_chief_portrait.draw_circle(Vector2(65.0, 65.0), 63.0, Color(0.94, 0.91, 0.85))
		_chief_portrait.draw_arc(Vector2(65.0, 65.0), 63.0, 0.0, TAU, 48, Color(0.72, 0.58, 0.25, 0.90), 2.5)
	)
	_chief_face = TextureRect.new()
	_chief_face.position = Vector2(6.0, 6.0)
	_chief_face.size = Vector2(118.0, 118.0)
	_chief_face.texture = CharArt.face("player")
	_chief_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chief_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_chief_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask_sh := Shader.new()
	mask_sh.code = "shader_type canvas_item;
void fragment(){ vec2 uv = UV - vec2(0.5); if (dot(uv, uv) > 0.25) { discard; } COLOR = texture(TEXTURE, UV); }"
	var mask_mat := ShaderMaterial.new()
	mask_mat.shader = mask_sh
	_chief_face.material = mask_mat
	_chief_portrait.add_child(_chief_face)
	_chief_name = Label.new()
	_chief_name.position = Vector2(40.0, 24.0)
	_chief_name.size = Vector2(560.0, 36.0)
	_chief_name.add_theme_font_override("font", _font)
	_chief_name.add_theme_font_size_override("font_size", 24)
	_chief_name.add_theme_color_override("font_color", Color(0.68, 0.15, 0.12))
	_chief_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_chief_name)
	_chief_text = Label.new()
	_chief_text.position = Vector2(40.0, 72.0)
	_chief_text.size = Vector2(580.0, 150.0)
	_chief_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chief_text.add_theme_font_override("font", _font)
	_chief_text.add_theme_font_size_override("font_size", 22)
	_chief_text.add_theme_color_override("font_color", Color(0.14, 0.13, 0.15))
	_chief_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_chief_text)
	var hint := Label.new()
	hint.text = "轻点继续"
	hint.position = Vector2(500.0, 238.0)
	hint.size = Vector2(130.0, 30.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.30, 0.26, 0.20, 0.55))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hint)
	_chief_update()


func _chief_update() -> void:
	if _chief_i < 0 or _chief_i >= _chief_lines.size():
		return
	var ln: Dictionary = _chief_lines[_chief_i]
	var who := str(ln.get("who", ""))
	var hero := who == "少侠" or who == "主角" or who == str(GameState.player_name)
	_chief_name.text = who
	_chief_text.text = str(ln.get("text", ""))
	if _chief_portrait != null:
		_chief_portrait.visible = hero
	_chief_name.position.x = 172.0 if hero else 40.0
	_chief_name.size.x = 448.0 if hero else 560.0
	_chief_text.position.x = 172.0 if hero else 40.0
	_chief_text.size.x = 448.0 if hero else 580.0


func _chief_advance() -> void:
	if _chief_dlg == null:
		return
	_chief_i += 1
	if _chief_i >= _chief_lines.size():
		_chief_close()
	else:
		_chief_update()


func _chief_close() -> void:
	if _chief_dlg != null:
		_chief_dlg.queue_free()
		_chief_dlg = null
	var cb := _chief_done
	_chief_done = Callable()
	if cb.is_valid():
		cb.call()


func _start_craft_guide() -> void:
	if _craft_guide != null:
		return
	GameState.cave_opened = true
	GameState.winery_built = true
	GameState.save_game()
	_refresh_plaques()
	if _plaques != null:
		_plaques.set_vis("craft", true)
		_plaques.layout_rail(PlaqueLayer.RAIL_IDS, PlaqueLayer.RAIL_TOP, PlaqueLayer.RAIL_H, PlaqueLayer.RAIL_GAP)
		_craft_guide_rect = _plaques.item_rect("craft")
	_craft_guide_text = "百工坊"
	_craft_guide_step = "craft"
	var g := Control.new()
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.z_index = 48
	g.draw.connect(_draw_craft_guide)
	add_child(g)
	_craft_guide = g


func _start_forge_guide() -> void:
	if _craft_guide == null:
		return
	_craft_guide_step = "forge"
	_craft_guide_text = "铁匠铺"
	if _craft_panel != null:
		_craft_guide_rect = _craft_panel.forge_card_rect()


func _end_craft_guide() -> void:
	if _craft_guide != null:
		_craft_guide.queue_free()
		_craft_guide = null
	_craft_guide_step = ""
	_craft_guide_text = ""


func _draw_craft_guide() -> void:
	if _craft_guide == null:
		return
	var r := _craft_guide_rect
	if r.size.x <= 0.0:
		return
	var k := 0.5 + 0.5 * sin(_t * 5.2)
	var ring := r.grow(8.0 + 4.0 * k)
	_craft_guide.draw_rect(ring.grow(12.0), Color(1.0, 0.78, 0.28, 0.10 + 0.10 * k), false, 10.0)
	_craft_guide.draw_rect(ring, Color(1.0, 0.84, 0.36, 0.95), false, 3.0)
	var tx := Rect2(130.0, 128.0, 530.0, 64.0)
	_craft_guide.draw_rect(tx, Color(0.96, 0.94, 0.89, 0.97))
	_craft_guide.draw_rect(tx, Color(0.86, 0.68, 0.26, 0.90), false, 2.0)
	_craft_guide.draw_string(_font, Vector2(152.0, 169.0), _craft_guide_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.14, 0.13, 0.15))
	var start := Vector2(360.0, 196.0)
	var c := r.get_center()
	var dir := (c - start).normalized()
	var side := Vector2(-dir.y, dir.x)
	_craft_guide.draw_line(start, c - dir * 10.0, Color(0.55, 0.12, 0.10, 0.55), 5.0, true)
	_craft_guide.draw_line(start, c - dir * 10.0, Color(1.0, 0.84, 0.36, 0.95), 2.5, true)
	var tip := c
	var a1 := tip - dir * 18.0 + side * 9.0
	var a2 := tip - dir * 18.0 - side * 9.0
	_craft_guide.draw_colored_polygon(PackedVector2Array([tip, a1, a2]), Color(1.0, 0.84, 0.36, 0.95))


func _show_loot_float(anchor: Vector2, amount: int) -> void:
	var lb := Label.new()
	lb.text = "+" + str(amount)
	lb.position = anchor + Vector2(-10.0, 8.0)
	lb.size = Vector2(120.0, 30.0)
	lb.add_theme_font_override("font", _font)
	lb.add_theme_font_size_override("font_size", 22)
	lb.add_theme_color_override("font_color", Color(0.86, 0.68, 0.26))
	lb.z_index = 61
	add_child(lb)
	var tw := create_tween()
	tw.tween_property(lb, "position:y", lb.position.y + 44.0, 0.9)
	tw.parallel().tween_property(lb, "modulate:a", 0.0, 0.9)
	tw.finished.connect(lb.queue_free)

func _open_star_page(which := "") -> void:
	print("[主界面] 升星页", which)
	if _star_panel != null:
		_star_panel.open(which)

func _on_star_closed() -> void:
	if _char_panel != null and _char_panel.visible:
		_char_panel.refresh()

func _on_pet_open() -> void:
	if _story_page >= 0:
		return
	print("[主界面] 宠物面板")
	_clear_toast()
	if _pet_panel != null:
		_pet_panel.open()

func _open_shop() -> void:
	print("[主界面] 货栈")
	_clear_toast()
	if _shop_panel != null:
		_shop_panel.open()

# v39：鉴宝行——村里记号点开它（400 关剧情后才有记号）
func _open_appraise() -> void:
	print("[主界面] 鉴宝行")
	_clear_toast()
	if _appraise_panel != null:
		_appraise_panel.open()

# ---- 挂机 ----

func _fmt_min(m: int) -> String:
	if m >= 60:
		return str(m / 60) + " 时 " + str(m % 60) + " 分"
	return str(m) + " 分"

func _on_idle_collect() -> void:
	var r := GameState.idle_collect()
	var mins := int(r["minutes"])
	if mins < 1:
		_show_toast("挂机还不到 1 分钟——再等等（在线离线都往池里攒）")
		_refresh_idle_btn()
		return
	Audio.sfx("coin", -7.0, randf_range(1.0, 1.08))   # v98：收着钱了给一声
	var parts: Array = ["银两 +" + str(int(r["silver"]))]
	if int(r.get("action", 0)) > 0:
		var ft := "食物 +" + str(int(r["action"])) + "（现 " + str(mini(GameState.action, 100)) + "/100"
		if GameState.action > 100:
			ft += " · 存粮 +" + str(GameState.action - 100)
		parts.append(ft + "）")
	var ex := int(r.get("exp", 0))
	if ex > 0:
		parts.append("经验 +" + str(ex) + " 入经验池（现 " + str(GameState.exp_pool) + "，弟子面板［分配］）")
	# v64b：阅历（阅历线）——与银两/经验同一口收
	var ins := int(r.get("insight", 0))
	if ins > 0:
		parts.append("阅历 +" + str(ins) + "（现 " + str(GameState.insight) + "，底排［阅历］点线）")
	_show_toast("挂机（第 " + str(GameState.idle_tier() + 1) + " 档）收取：" + _fmt_min(mins) + " → " + " · ".join(PackedStringArray(parts)), 3.4)
	print("[主界面] 挂机收取：", mins, " 分（第 ", GameState.idle_tier() + 1, " 档）→ 银两 +", int(r["silver"]), " · 经验 +", ex, " 入池（现 ", GameState.exp_pool, "）· 阅历 +", ins, "（现 ", GameState.insight, "）")
	_refresh_idle_btn()
	if _char_panel != null and _char_panel.visible:
		_char_panel.refresh()

# ---- 剧情 ----

func _clear_toast() -> void:
	_toast = ""
	_toast_t = 0.0

func _story_start(kind: String) -> void:
	_clear_toast()
	_story_kind = kind
	_story_page = 0
	if _char_panel != null:
		_char_panel.close()
	print("[主界面] 剧情：", kind)

# 这段剧情挂在第几关（0＝不挂关号，文案里也没有 {N} 可填）
func _story_stage_no() -> int:
	if _story_kind == "map":
		return MAP_STAGE
	if _story_kind == "herb":
		return HERB_STAGE
	if _story_kind == "qingluan":
		return NVXIA_STAGE
	if _story_kind == "jianbao":
		return JIANBAO_STAGE
	return 0

func _story_pages() -> Array:
	var pages: Array = INTRO_PAGES
	if _story_kind == "backhill":
		pages = BACKHILL_PAGES
	elif _story_kind == "map":
		pages = MAP_PAGES
	elif _story_kind == "cave":
		pages = CAVE_PAGES
	elif _story_kind == "herb":
		pages = HERB_PAGES
	elif _story_kind == "qingluan":
		pages = QINGLUAN_PAGES
	elif _story_kind == "jianbao":
		pages = JIANBAO_PAGES
	# {N} → 关号（常量现算，见 MAP_PAGES 上面那段告诫）。
	#   ⚠ 只改第一页第一句，而且**改副本**——const 数组是只读的，就地改会报错。
	var n := _story_stage_no()
	if n <= 0:
		return pages
	var out: Array = pages.duplicate()
	var first: Array = (out[0] as Array).duplicate()
	first[0] = str(first[0]).replace("{N}", str(n))
	out[0] = first
	return out

func _story_title() -> String:
	if _story_kind == "backhill":
		return "后　山"
	if _story_kind == "map":
		return "藏宝图"
	if _story_kind == "cave":
		return "山　洞"
	if _story_kind == "herb":
		return "灵　草"
	if _story_kind == "qingluan":
		return "女　侠"
	if _story_kind == "jianbao":
		return "货　仓"
	return "弟　子"

func _story_tip() -> String:
	var last := _story_page >= _story_pages().size() - 1
	if _story_kind == "backhill":
		return "轻点——它跟定你了" if last else "轻点继续"
	if _story_kind == "map":
		return "轻点——收起来" if last else "轻点继续"
	if _story_kind == "cave":
		return "轻点——抱它回村" if last else "轻点继续"
	if _story_kind == "herb":
		return "轻点——收下灵草" if last else "轻点继续"
	if _story_kind == "qingluan":
		return "轻点——请她同行" if last else "轻点继续"
	return "轻点——收下他" if last else "轻点继续"

func _story_next() -> void:
	Audio.sfx("paper", -21.0, randf_range(0.98, 1.06))   # v98：翻一页一声纸响（很轻，别盖过配音）
	_story_page += 1
	if _story_page < _story_pages().size():
		return
	var kind := _story_kind
	_story_page = -1
	_story_kind = ""
	if _veil != null:
		_veil.queue_redraw()
	print("[主界面] 剧情结束：", kind)
	if kind == "intro":
		GameState.join_disciple()
		_tag_notice = 1
		_show_toast(INTRO_AFTER)
	elif kind == "backhill":
		GameState.pet_join()
		_show_toast(BACKHILL_AFTER)
	elif kind == "map":
		GameState.map_found = true
		_show_toast(MAP_AFTER, 2.8)
	elif kind == "cave":
		GameState.cave_opened = true
		GameState.wine_give_chenniang()
		_show_toast(CAVE_AFTER, 2.8)
	elif kind == "herb":
		GameState.grant_herbs()
		_show_toast(HERB_AFTER, 3.0)
	elif kind == "qingluan":
		var jmsg := GameState.join_qingluan()
		_show_toast(QINGLUAN_AFTER + "｜" + jmsg, 3.6)
	elif kind == "jianbao":
		var bmsg := GameState.jianbao_unlock()   # v39：开张 + 送道具 + 把那只货仓摆上架
		_show_toast(JIANBAO_AFTER + "｜" + bmsg, 4.2)
	if _auto_resume_i >= 0:
		var t := _auto_resume_i
		_auto_resume_i = -1
		if GameState.auto_climb and GameState.stage_progress == t and t < GameState.STAGE_MAX:
			await get_tree().create_timer(1.2).timeout
			if _story_page < 0 and not _any_panel_open() and GameState.stage_progress == t:
				print("[主界面] 自动挑战（剧情后）：第 ", t + 1, " 关")
				_start_stage(t)

# ---- 底：桌子 ----
func _draw() -> void:
	# v97：只留村景层时，**桌面那套（深底＋木纹＋卷轴压影）不再画**——
	#   它会把村景层自己的"纸底"（z=-100）整个盖住，整屏发灰发褐（村景看着像蒙了层土）。
	#   这里改铺一张宣纸，村景就落在纸上了。
	if INK_ONLY:
		# ⚠ 这里**一笔都不画**：村景层的"纸底"（z=-100 相对 → 生效 -200）已经在最底下铺好，
		#   而本函数是 z=0——一画就把整层村景盖住（"远山看不见"的老坑就是这个）。
		return
	draw_rect(Rect2(Vector2.ZERO, size), Conf.BG_C)
	draw_set_transform(_origin(), 0.0, Vector2(_zoom(), _zoom()))
	draw_rect(Rect2(0, 0, Conf.DW, Conf.DH), Conf.DESK_C)
	for i in 5:
		var gy := 70.0 + float(i) * 250.0 + sin(float(i) * 2.3) * 8.0
		draw_line(Vector2(0, gy), Vector2(Conf.DW, gy), Color(Conf.DESK_L.r, Conf.DESK_L.g, Conf.DESK_L.b, 0.55), 2.0)
	draw_rect(Rect2(0, Conf.BAND_TOP + 12.0, Conf.DW, Conf.BAND_H + 18.0), Color(0.08, 0.06, 0.05, 0.07))
	draw_rect(Rect2(0, Conf.BAND_TOP + 6.0, Conf.DW, Conf.BAND_H + 10.0), Color(0.08, 0.06, 0.05, 0.10))

# ============ 输入 ============

func _gui_input(ev: InputEvent) -> void:
	if _story_page >= 0:
		if ev is InputEventMouseButton:
			var im := ev as InputEventMouseButton
			if im.pressed and im.button_index == MOUSE_BUTTON_LEFT:
				_story_next()
		accept_event()
		return
	if _panel_open:
		if ev is InputEventMouseButton:
			var mp := ev as InputEventMouseButton
			if mp.pressed and mp.button_index == MOUSE_BUTTON_LEFT:
				_panel_open = false
			accept_event()
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var p := _dpos(mb.position)
		if mb.pressed:
			_demo_done = true
			_moved = 0.0
			_mode = ""
			_pressed_tag = -1
			if not SCROLL_OFF and p.y > Conf.BAND_TOP - 60.0 and p.y < Conf.TAG_Y - 8.0:
				_mode = "scroll"
				_dragging = true
				if _sc_tween != null and _sc_tween.is_valid():
					_sc_tween.kill()
				if INK_ONLY:
					Audio.sfx("paper", -20.0, randf_range(0.96, 1.04))   # v98：展卷一声纸响（很轻）
			else:
				for i in _tag_rects.size():
					if not _tag_unlocked(i):
						continue
					if (_tag_rects[i] as Rect2).has_point(p):
						_mode = "tag"
						_pressed_tag = i
						break
			accept_event()
		else:
			var m := _mode
			_mode = ""
			_dragging = false
			var tg := _pressed_tag
			_pressed_tag = -1
			if m == "scroll" and _moved < 12.0:
				_tap_at(p)
			elif m == "tag" and tg >= 0 and _moved < 14.0 and (_tag_rects[tg] as Rect2).has_point(p):
				_tag_fire(tg)
			elif m == "scroll":
				_snap_scroll()
			accept_event()
	elif ev is InputEventMouseMotion and _dragging:
		var mm := ev as InputEventMouseMotion
		_moved += absf(mm.relative.x) + absf(mm.relative.y) * 0.4
		if INK_ONLY:
			# v98：向右拖＝展卷（封面页 → 村景页），跟老版一个方向
			_sc = clampf(_sc - mm.relative.x / _zoom(), 0.0, Conf.DW)
			_hint_used = true
		else:
			_cam = clampf(_cam - mm.relative.x / _zoom(), Conf.CAM_MIN, Conf.CAM_MAX)
		if _moved > 24.0:
			_hint_a = maxf(0.0, _hint_a - 0.05)
		accept_event()

# v220：画卷松手吸附——过半就归到村景，没过半弹回封面；0.32s 缓出
func _snap_scroll() -> void:
	if not INK_ONLY:
		return
	if _sc <= 1.0 or _sc >= Conf.DW - 1.0:
		return
	if _sc_tween != null and _sc_tween.is_valid():
		_sc_tween.kill()
	var target: float = 0.0 if _sc < Conf.DW * 0.5 else Conf.DW
	_sc_tween = create_tween()
	_sc_tween.tween_property(self, "_sc", target, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _tap_at(p: Vector2) -> void:
	if PIN_CAM:
		return      # v98：一屏村景＋牌子，点的判定全在牌子层里；老那套世界坐标点景作废（代码留着）
	if p.y < Conf.CONTENT_TOP or p.y > Conf.CONTENT_BOT:
		return
	var c := p.x + _cam
	if absf(c - Conf.SUN_X) < 72.0 and absf(p.y - Draw.sy_at(Conf.SUN_Y)) < 72.0:
		_show_toast("日出东方——他往后的路，也从这儿亮起来")
	elif absf(c - _scroll.fig_x()) < 28.0 and p.y > Draw.sy_at(716.0) and p.y < Draw.sy_at(772.0):
		_hero_talk()
	elif c >= 1636.0 and c <= 1700.0 and p.y > Draw.sy_at(738.0) and p.y < Draw.sy_at(786.0):
		_chen_talk()
	elif c >= 1490.0 and c <= 1560.0 and p.y > Draw.sy_at(740.0) and p.y < Draw.sy_at(790.0) and GameState.qingluan_joined:
		_show_toast("「先出村，我再看出手。」她把剑往臂上一横。")
	elif c >= 1050.0 and c <= 1175.0 and p.y > Draw.sy_at(660.0) and p.y < Draw.sy_at(750.0):
		_show_toast("一叶扁舟——溪上的人，只是路过")
	elif c >= Conf.YINSHOU_X0 and c <= Conf.YINSHOU_X1:
		_show_toast("书名《" + Conf.TITLE + "》——要改只改 menu_conf.gd 的 TITLE 一行")

func _hero_talk() -> void:
	_show_toast(str(HERO_LINES[_hero_i % HERO_LINES.size()]))
	_hero_i += 1

func _chen_talk() -> void:
	if not GameState.disciple_joined:
		_show_toast("「" + Conf.DISCIPLE_NAME + "」——他站在门外等你（点下面［弟子］）")
		return
	_show_toast(str(CHEN_LINES[_chen_i % CHEN_LINES.size()]))
	_chen_i += 1

func _on_node_added(n: Node) -> void:
	if n is Button:
		var b := n as Button
		var cb := _ui_click_sound.bind(b)
		if not b.pressed.is_connected(cb):
			b.pressed.connect(cb)
		# v225：按压回弹——不是只有声音，按钮自己也按下去
		var down_cb := _btn_press.bind(b)
		var up_cb := _btn_release.bind(b)
		if not b.button_down.is_connected(down_cb):
			b.button_down.connect(down_cb)
		if not b.button_up.is_connected(up_cb):
			b.button_up.connect(up_cb)
		b.visibility_changed.connect(func() -> void:
			if not b.visible:
				b.scale = Vector2.ONE)

# v224：按钮音按语义分流——关/返回、买、翻页不再都是同一声"水滴"
func _button_sfx(b: Button) -> String:
	if b == null:
		return ""
	var s := b.text.replace(" ", "").replace("　", "")
	if s == "":
		return ""
	if s == "‹" or s == "›":
		return "paper"
	if s == "×" or s.contains("关闭") or s.contains("返回") or s.contains("退出"):
		return "ui_back"
	if s.contains("购买") or s.contains("买") or s.contains("购入") or s.contains("兑换"):
		return "coin"
	return ""

func _btn_press(b: Button) -> void:
	if b == null or b.size.x > 620.0 or b.size.y > 1180.0:
		return   # 满屏遮罩类按钮不缩
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(0.95, 0.95), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _btn_release(b: Button) -> void:
	if b == null or b.size.x > 620.0 or b.size.y > 1180.0:
		return
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _ui_click_sound(b: Button = null) -> void:
	match _button_sfx(b):
		"ui_back":
			Audio.sfx("ui_back", -12.0, 0.98)
		"coin":
			Audio.sfx("coin", -12.0, randf_range(1.0, 1.06))
		"paper":
			Audio.sfx("paper", -19.0, randf_range(0.98, 1.05))
		_:
			Audio.ui_click()

func _tag_fire(i: int) -> void:
	Audio.ui_click()      # v98：底排页签原来一声都没有（用户："点击需要有一点反馈的音效"）
	match i:
		0:
			if TUTORIAL_DEMO:
				_ask_skip_segment(1, _open_tutorial, _seg1_skip)
			else:
				_ask_skip_segment(1, _open_out, _seg1_skip)
			return
		1:
			if not _role_unlocked:
				_show_toast("角色还没开——先过完前面的引导")
				return
			_end_craft_guide()
			_tag_notice = -1
			print("[主界面] 「角色」→ 角色面板")
			_char_panel.open()
			if _seg4_seen:
				call_deferred("_seg4_intro")
		2:
			if not _bag_unlocked:
				_show_toast("行囊还没开——先过完前面的引导")
				return
			_end_craft_guide()
			_open_warehouse()
		3:
			# 底排第 4 格＝宠物（menu_hud v7 直接画的字：宠物 / 宠物·幼狐…）
			_on_pet_open()
		4:
			# v4.2：底排第 5 格＝宝箱（宝箱专页：自绘箱子 + 开箱动画，见 chest_panel.gd）
			_open_chests()
		5:
			# v64b：第 6 格「阅历」——阅历线面板（原来是「关于」空壳；TAGN 那边也改了字）
			_open_insight()

# ---- 出村 → 整备/引导 → 自动战斗 ----

func _on_challenge(i: int) -> void:
	_out_panel.close()
	if not GameState.formation_intro_done:
		print("[主界面] 首次出战——先过一遍整备（引导）")
		_formation.open_for_stage(i)
		return
	_start_stage(i)

func _on_out_config() -> void:
	_out_panel.close()
	print("[主界面] 出战配置（整备面板·三格）")
	_formation.open_config()

# ============================================================
# v129：追剿（精英爬塔）——出村面板那颗卡的**两条路**
#   手动 ＝ 手牌模式（kushou：自己配牌，连打这一剿的五关）
#   自动 ＝ 自动战斗（battle_lite：跟爬塔一样看着它打，可开连打）
#   进度与奖励都在账本：GameState.chase_progress（**奖励暂不给**，只推关）。
# ============================================================
const Chase := preload("res://shared/data_chase.gd")

func _on_chase_manual() -> void:
	_out_panel.close()
	if not GameState.chase_unlocked():
		_show_toast("追剿还没开——爬塔到第 " + str(Chase.UNLOCK_STAGE) + " 关（还差 " + str(GameState.chase_gap()) + " 关）", 3.0)
		return
	if GameState.chase_progress >= Chase.STAGE_MAX:
		_show_toast("追剿 500 关已清——村口清净了", 2.6)
		return
	# v135（用户："追剿 的手牌说的是游历的那种出牌 直接加在战斗里设置即可"）：
	#   ［手牌］不再开困兽那张牌桌——**直接进战斗，手动出牌**（战斗里右上那颗钮随时能切回自动）。
	_start_chase_stage(GameState.chase_progress, true)
	_show_toast("[追剿·手牌] 进战斗自己点牌出手——轮到你的人就摊一张手牌", 3.2)

func _on_chase_kushou_done(win: bool, stage_i: int) -> void:
	if win:
		_show_toast("追剿：" + str(Chase.chapter_of(stage_i)) + " 清了——进度 " + str(GameState.chase_progress) + "/" + str(Chase.STAGE_MAX), 3.2)
	else:
		_show_toast("追剿：这一剿没打下来（进度仍是 " + str(GameState.chase_progress) + "）——配好牌再来", 3.0)
	if _out_panel != null:
		_out_panel.refresh()

func _on_chase_auto() -> void:
	_out_panel.close()
	if not GameState.chase_unlocked():
		_show_toast("追剿还没开——爬塔到第 " + str(Chase.UNLOCK_STAGE) + " 关（还差 " + str(GameState.chase_gap()) + " 关）", 3.0)
		return
	if GameState.chase_progress >= Chase.STAGE_MAX:
		_show_toast("追剿 500 关已清——村口清净了", 2.6)
		return
	_start_chase_stage(GameState.chase_progress)

# v144：追剿关卡列表里点［挑战］——只有"当前该打的那一关"能真打，别的关先提示
func _on_chase_challenge(i: int) -> void:
	_out_panel.close()
	if not GameState.chase_unlocked():
		_show_toast("追剿还没开——爬塔到第 " + str(Chase.UNLOCK_STAGE) + " 关（还差 " + str(GameState.chase_gap()) + " 关）", 3.0)
		_out_panel.open()
		return
	if i != GameState.chase_progress:
		_show_toast("追剿要从第 " + str(GameState.chase_progress + 1) + " 关往下打——前面那几关已经清过了", 3.0)
		_out_panel.open()
		return
	_start_chase_stage(i)

# v143：村里点［停推］——把追剿的连打与后台推进一起收
func _on_chase_bg_off() -> void:
	_show_toast("追剿：连打与后台推进都停了（想继续就再点［自动］）", 3.0)

func _start_chase_stage(i: int, manual := false) -> void:
	if i != GameState.chase_progress:
		_show_toast("追剿进度对不上（要打第 " + str(GameState.chase_progress + 1) + " 关）")
		return
	if i >= Chase.STAGE_MAX:
		return
	var b := BattleLite.new()
	b.chase = true
	b.manual = manual          # v135：true ＝ 手动出牌（游历那套手牌）
	b.stage_i = i
	b.done.connect(_on_chase_battle_done.bind(i))
	# v143：追剿也能"人先回村、后台接着推"了——left 信号跟上（与爬塔同一条路）
	b.left.connect(_on_chase_battle_left)
	_battle = b
	add_child(b)
	print("[主界面] 追剿·", "手牌" if manual else "自动", "：第 ", i + 1, "/", Chase.STAGE_MAX, " 关 · ", Chase.enemy_name(i), " 特性=", Chase.boss_traits_of(i))

func _on_chase_battle_done(win: bool, i: int) -> void:
	var was_manual := false
	if _battle != null and is_instance_valid(_battle):
		was_manual = bool(_battle.manual)   # v135：连打时保持"手动/自动"不变
		_battle.queue_free()
	_battle = null
	if win:
		GameState.chase_clear(i)
		# v136：赏格播报（银两/经验/箱子，boss 关那件整品）——账本把这一行攒好了
		_show_toast("追剿清关：第 " + str(i + 1) + "/" + str(Chase.STAGE_MAX) + " 关 · " + Chase.enemy_name(i)
			+ "｜" + GameState.last_chase_line + "｜进度 " + str(GameState.chase_progress), 3.6)
		# v143：人已经回村（chase_bg）——这一胜之后不再自动开下一场，改后台估算接手
		if GameState.chase_bg:
			_show_toast("追剿：已转后台——每 20 秒按估算推一关（不想推就在出村面板把［自动］关掉）", 3.4)
			_out_panel.open()
			return
		# 连打开着就接着下一关（追剿的开关是 chase_auto，与爬塔的 auto_climb 分开）
		if GameState.chase_auto and GameState.chase_progress < Chase.STAGE_MAX and not _any_panel_open():
			await get_tree().create_timer(0.5).timeout
			if GameState.chase_auto and GameState.chase_progress == i + 1 and not _any_panel_open():
				_start_chase_stage(i + 1, was_manual)
				return
		_out_panel.open()
	else:
		if GameState.chase_auto:
			GameState.chase_auto = false
			_show_toast("追剿败退——连打已停；整备好再点［自动］", 3.0)
		else:
			_show_toast("追剿败退——回去整备，再来", 2.6)
		_out_panel.open()

# v143：追剿的［回村·后台继续］——与爬塔那条同一口径：
#   这一场既不算赢也不算败，追剿停在**当前这一关**，交给 _idle_chase 每 20 秒重判一次。
func _on_chase_battle_left() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
	_battle = null
	GameState.chase_bg = true
	print("[主界面] 追剿半路回村：第 ", GameState.chase_progress + 1, " 关交给后台估算（连打仍开）")
	_show_toast("回村了——追剿没停：刚那关交给后台估算（每 20 秒推一关，推完在村里报）", 3.4)
	_out_panel.open()

func _on_form_ok(i: int) -> void:
	_start_stage(i)

func _on_form_saved() -> void:
	print("[主界面] 阵容已记下：", GameState.formation)
	_show_toast("阵容已记下——下次挑战直接开打", 2.2)
	_out_panel.open()

func _on_form_cancel() -> void:
	_open_out()

# ---- 出征屏（R1）：正式游历的入口——选人·选难度·看携宠；点出发才切场 ----

func _open_journey_entry() -> void:
	_open_world_panel()

func _open_world_panel() -> void:
	_clear_toast()
	if _world_panel == null:
		_world_panel = WorldPanel.new()
		_world_panel.enter_requested.connect(_on_world_enter)
		_world_panel.world_generated.connect(_on_world_generated)
		_world_panel.closed.connect(_on_world_closed)
		add_child(_world_panel)
	_world_panel.open()

func _on_world_enter() -> void:
	_on_world_closed()
	_open_depart()

func _on_world_generated() -> void:
	_on_world_closed()
	_open_depart()

func _on_world_closed() -> void:
	if _world_panel != null:
		_world_panel.visible = false

func _open_depart() -> void:
	_clear_toast()
	if _depart == null:
		print("[主界面] 出征屏没挂上（_depart == null）")
		_show_toast("出征屏没挂上——看控制台")
		return
	print("[主界面] 出征屏：D1=", GameState.diff_state(1), " 已清=", GameState.diff_cleared_count(), " 携宠=", GameState.pet_follow)
	_depart.open()

# ---- v64b：阅历线面板 ----
var _insight_panel = null

func _open_insight() -> void:
	_clear_toast()
	if _insight_panel == null:
		_insight_panel = InsightPanel.new()
		add_child(_insight_panel)
	_insight_panel.open()

func _on_deploy_started(party: Array, diff: int) -> void:
	diff = GameState.world_difficulty
	GameState.deploy_set(party, diff)
	if GameState.action <= 0:
		_show_toast("食物空了——先去「挂机」收一次，或爬塔攒一点", 3.2)
		return
	if not GameState.world_created:
		_show_toast("还没有世界——先在世界窗口生成一个", 3.2)
		_open_world_panel()
		return
	if not GameState.first_explore_done:
		GameState.world_difficulty = 1
	GameState.first_explore_done = true
	GameState.save_game()
	print("[主界面] 直接入图：", GameState.REGION_NAMES[GameState.current_region], " · 难度 ", GameState.world_difficulty)
	var err := get_tree().change_scene_to_file(Conf.EXPLORE_SCENE)
	if err != OK:
		_show_toast("进不去游历：路径＝" + Conf.EXPLORE_SCENE)

func _on_region_entered(region: int) -> void:
	GameState.current_region = clampi(region, 0, 4)
	if not GameState.first_explore_done:
		GameState.world_difficulty = 1
	GameState.first_explore_done = true
	GameState.save_game()
	if _region_panel != null:
		_region_panel.close()
	print("[主界面] 入图：", GameState.REGION_NAMES[GameState.current_region], " · 世界档 ", GameState.world_tier)
	var err := get_tree().change_scene_to_file(Conf.EXPLORE_SCENE)
	if err != OK:
		print("[主界面] 打不开游历，错误码=", err, "；检查路径：", Conf.EXPLORE_SCENE)
		_show_toast("进不去游历：路径＝" + Conf.EXPLORE_SCENE)

func _on_region_closed() -> void:
	pass

func _start_stage(i: int) -> void:
	if i != GameState.stage_progress:
		_show_toast("得先清前一关")
		return
	# ㊿q：只要在屏幕上真打，自动挑战就回到"连打"形态——后台估算别跟这场抢关卡。
	GameState.auto_bg = false
	var b := BattleLite.new()
	b.stage_i = i
	b.done.connect(_on_battle_done.bind(i))
	b.left.connect(_on_battle_left)
	_battle = b
	add_child(b)
	print("[主界面] 出村挑战：第 ", i + 1, " 关 · ", GameState.chapter_of(i))

# ㊿q：［回村·后台继续］——这一场没打完人就走了（battle_lite 发的 left 信号）。
#   这里只做两件事：把这场撤掉、把自动挑战留在"开"上（auto_bg = true 已经由战斗置好）。
#   这一关不算赢也不算败——塔停在原地，由挂机估算重新判（判不过就卡住等你回来打）。
func _on_battle_left() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
	_battle = null
	GameState.auto_bg = true
	print("[主界面] 半路回村：第 ", GameState.stage_progress + 1, " 关交给后台估算（自动挑战仍开）")
	_show_toast("回村了——自动挑战没停：刚那关交给后台估算（每 20 秒推一关，推完在村里报）", 3.4)

func _on_battle_done(win: bool, i: int) -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
	_battle = null
	if win:
		GameState.stage_clear(i)
		var e: Dictionary = GameState.enemy_at(i)
		# ㊿n：过关收益只发银两与经验——播报：银两（已减）· 经验入池 · 逢五关卡的大奖
		var msg := "清缴：" + str(e["name"]) + " · 银两 +" + str(GameState.stage_silver(i)) + " · 经验 +" + str(GameState.stage_exp_gain(i)) + " 入经验池（现 " + str(GameState.exp_pool) + "）"
		if GameState.is_boss(i):
			msg += " · 首领赏 +" + str(GameState.boss_silver_gain(i))
		elif GameState.is_elite(i):
			msg += " · 精英关（赏已翻倍）"
		if GameState.last_stage_gift_line != "":
			msg += "｜大奖：" + GameState.last_stage_gift_line + " 已入仓库"
		var up_names: Array = []
		for id in GameState.formation:
			var d2: Dictionary = GameState.role_data(str(id))
			if not d2.is_empty() and GameState.levels_available(str(id)) > 0:
				up_names.append(str(d2.get("name", id)))
		if not up_names.is_empty():
			msg += "｜可升级：" + "、".join(PackedStringArray(up_names))
		# ㊿q：人已经回村（auto_bg）——这一胜之后不再自动开下一场，改后台估算接手
		if GameState.auto_bg:
			msg += "｜自动挑战：已转后台（每 20 秒按估算推一关；不想推就在出村面板关掉）"
		_show_toast(msg, 3.0)
		print("[主界面] 清缴第 ", i + 1, " 关（", GameState.chapter_of(i), "）")
		var sk := ""
		if i == MAP_STAGE - 1 and not GameState.map_found:
			sk = "map"
		elif i == NVXIA_STAGE - 1 and not GameState.qingluan_joined:
			sk = "qingluan"
		elif i == HERB_STAGE - 1 and not GameState.herbs_granted:
			sk = "herb"
		elif i == JIANBAO_STAGE - 1 and not GameState.jianbao_ok():
			sk = "jianbao"
		if sk != "":
			await get_tree().create_timer(0.8).timeout   # v62：等建筑动画落定即可，不用 1.6 秒
			if _story_page < 0 and not _any_panel_open():
				_story_start(sk)
				if GameState.auto_climb and not GameState.auto_bg and i + 1 < GameState.STAGE_MAX:
					_auto_resume_i = i + 1
				return
		if GameState.auto_climb and not GameState.auto_bg and i + 1 < GameState.STAGE_MAX and GameState.stage_progress == i + 1:
			await get_tree().create_timer(0.4).timeout
			if GameState.auto_climb and not GameState.auto_bg and GameState.stage_progress == i + 1 and _story_page < 0 and not _any_panel_open():
				print("[主界面] 自动挑战：下一关 ", i + 2)
				_start_stage(i + 1)
	else:
		if GameState.auto_climb:
			GameState.auto_climb = false
			GameState.auto_bg = false
			_show_toast("败退——自动挑战已停；整备好后在出村面板里再开", 2.6)
		else:
			_show_toast("败退——回去整备，再来")

# ============================================================
# v122（用户："主界面头像名字旁边加这个按钮"）：进阶页——主界面那颗"进阶"牌点开的
# ============================================================
func _advance_hint() -> String:
	if GameState.advance_lv >= Realm.MAX_LV:
		return "已至化境之巅"
	return "→ " + Realm.name_of(GameState.advance_lv + 1)

func _open_advance() -> void:
	if _adv_veil != null and is_instance_valid(_adv_veil):
		return
	_adv_veil = ColorRect.new()
	_adv_veil.color = Color(0, 0, 0, 0.45)
	_adv_veil.size = get_viewport_rect().size
	_adv_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_adv_veil)
	_refresh_advance_panel()

func _close_advance() -> void:
	if _adv_veil != null and is_instance_valid(_adv_veil):
		_adv_veil.queue_free()
	_adv_veil = null

func _refresh_advance_panel() -> void:
	if _adv_veil == null or not is_instance_valid(_adv_veil):
		return
	for c in _adv_veil.get_children():
		c.queue_free()
	var vp := get_viewport_rect().size
	var pw := 600.0
	var ph := 468.0
	var panel := Panel.new()
	panel.position = Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.955, 0.937, 0.886, 0.99)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	psb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", psb)
	_adv_veil.add_child(panel)
	var top := clampi(GameState.advance_lv, 0, Realm.MAX_LV)
	var t1 := UiKit.make_label(panel, Vector2(0, 16), Vector2(pw, 40), 28, UiKit.INK)
	UiKit.set_text(t1, "进阶 · " + GameState.advance_name())
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := ""
	body += "当前境界：" + GameState.advance_name() + "（全体属性 +" + str(int(GameState.advance_pct() * 100.0)) + "%）\n"
	if top >= Realm.MAX_LV:
		body += "已是最高境界。\n"
	else:
		var nx: Dictionary = Realm.at(top + 1)
		body += "下一境界：" + str(nx.get("name", "")) + "（全体 +" + str(int(float(nx.get("pct", 0.0)) * 100.0)) + "%）\n"
		body += "关卡门槛：第 " + str(int(nx.get("stage_need", 0))) + " 关（现在 " + str(GameState.stage_progress) + "）\n"
		body += "成功率：" + str(int(float(nx.get("rate", 1.0)) * 100.0)) + "%　·　失败进阶丹与银两尽毁\n\n"
		var pid := GameState.advance_pill_id()
		var have := GameState.pill_count(pid)
		body += ("✔ " if have >= 1 else "✘ ") + GameState.advance_pill_name() + "　" + str(have) + " / 1\n"
		var sil := GameState.advance_silver()
		var have_s := GameState.coin("silver")
		body += ("✔ " if have_s >= sil else "✘ ") + "银两　" + str(have_s) + " / " + str(sil) + "\n"
	var lb := UiKit.make_label(panel, Vector2(36, 64), Vector2(pw - 72.0, 250), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.88))
	UiKit.set_text(lb, body)
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var chk := GameState.advance_can()
	var tip := UiKit.make_label(panel, Vector2(36, ph - 152.0), Vector2(pw - 72.0, 44), 15, UiKit.SEAL)
	UiKit.set_text(tip, str(chk.get("msg", "")))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var go := UiKit.make_button(panel, Vector2(36, ph - 76.0), Vector2(pw - 72.0, 56), "冲一冲", 21)
	go.disabled = not bool(chk.get("ok", false))
	go.pressed.connect(_on_advance_go)
	var no := Button.new()
	no.text = "再想想"
	no.position = Vector2(pw - 150.0, 12)
	no.size = Vector2(120, 34)
	no.add_theme_font_size_override("font_size", 16)
	no.focus_mode = Control.FOCUS_NONE
	no.pressed.connect(_close_advance)
	panel.add_child(no)

func _on_advance_go() -> void:
	var r := GameState.advance_try()
	_show_toast(str(r.get("msg", "")), 2.6)
	_plaques.set_sub("name", GameState.advance_name())
	_plaques.set_sub("advance", _advance_hint())
	if not bool(r.get("ok", false)):
		_refresh_advance_panel()   # 失败/不够：页面留在原地，材料数已变
	else:
		_close_advance()
func _show_toast(s: String, t := 1.9) -> void:
	_toast = s
	_toast_t = t
# v63k：抽搐取证器已抽成独立文件 shared/twitch_recorder.gd（主界面 B 键与游历按钮共用）
