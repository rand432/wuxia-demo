extends Control
# ============================================================
# character_panel.gd —— 角色面板 v16（竖屏 720×1280）
# v16（用户报的①）：星改"记在件上"——星级/加成只认**那件东西**，不再问"谁拿着"
#   （旧版 v14 写的是"星按人记、读本角色"，那是错的：卸下来给别人就没星了）。
#   顺带把浮框里"星记在「谁手里那把」上"那句话改成"星记在这件上，换谁拿都算"。
# v15（优化批㊾）：经验改"经验池"口径——经验条上常显池子数。
#   ㊾b（本轮）：［分配］钮与那套"池子→个人"弹窗**撤了**——升级直接花经验池
#   （个人那份先扣、不够从池里补，见 GameState.level_up）。多一步分配只是多点一下。
# v14（优化批⑮）：①武学 2→3 格（武学×3＋大招＝四格）；被动撤格、移入天赋框朱红高亮；
#   ②头饰改名「玉佩」；③（v16 已改：星记在件上，不按人记）；④修一行被贴坏的浮框文案。
# v13 变更：服药改成"一格开弹窗"——
#   ① 右下四格固定丹钮撤掉，换一颗［服药 · N 颗］（N＝包裹总数）；
#   ② 点击开 pill_popup.gd：丹方从 GameState.DAN_RECIPES 现算，
#      几条丹方几行、多了就滚——以后加丹不用再动这个面板；
#   ③ 弹窗每行：丹名 / 说明 / 存量 / 本境已服 x/y /［服下］；
#      养灵丹行标"宠物用"（去宠物面板喂）；没登记的丹摆"没方子"；
#   ④ Esc：先收弹窗，再关面板；点弹窗外收弹窗；服下后本面板当场刷新属性。
# v12 已有：天赋框 340 + 右侧服药区、本境限量、评价彩牌、升星、经验条。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const GameState := preload("res://shared/game_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const Elem := preload("res://shared/data_elem.gd")   # v58：五行真源（键名/中文/配色/通道口径）
const Bonds := preload("res://shared/data_bonds.gd")   # ㊽：上阵羁绊（纯数据）
const PillPopup := preload("res://menu/pill_popup.gd")
const Voice := preload("res://shared/voice.gd")
const DataIcons := preload("res://shared/data_icons.gd")   # v93l：武学/命数图标（素材图集切出来的）   # v93：开面板/换页签念一句（用户："语音包点击没听到"）

const PANEL_W := 640.0
# ㊿：面板加高 1212 → 1250，把省下来的高度全给"天赋"框（见下面那段说明）
const PANEL_H := 1250.0
const FREE_SLOTS := 3

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const GOLD := Color(0.72, 0.58, 0.22)

const EVAL_COL := {
	"绝等": Color(0.74, 0.52, 0.08),
	"甲等": Color(0.24, 0.52, 0.28),
	"乙等": Color(0.24, 0.42, 0.66),
	"丙等": Color(0.56, 0.36, 0.16),
	"丁等": Color(0.42, 0.40, 0.42),
}

const ELEM := {
	"metal": {"text": "金", "col": Color(0.72, 0.58, 0.25)},
	"wood": {"text": "木", "col": Color(0.33, 0.52, 0.31)},
	"water": {"text": "水", "col": Color(0.28, 0.42, 0.58)},
	"fire": {"text": "火", "col": Color(0.70, 0.28, 0.20)},
	"earth": {"text": "土", "col": Color(0.52, 0.40, 0.26)},
	"phys": {"text": "物理", "col": Color(0.36, 0.34, 0.36)},
	"true": {"text": "真实", "col": Color(0.45, 0.32, 0.52)},
}

const SLOTS := [
	{"slot": "weapon", "label": "兵器"},
	{"slot": "armor", "label": "护甲"},
	{"slot": "helm", "label": "玉佩"},
	{"slot": "cloak", "label": "披风"},
]
const SLOT_CN := {"weapon": "兵器", "armor": "护甲", "helm": "玉佩", "cloak": "披风"}
const ROLE_IDS := ["chen_shi", "player", "qingluan"]
const WEAPON_CN := {"sword": "长剑", "dual": "双刀", "dagger": "匕首", "spear": "长枪", "anqi": "暗器", "fist": "拳法"}
const CharArt := preload("res://shared/char_art.gd")   # v90：页签头像
const GameData := preload("res://shared/game_data.gd")   # v142：招式说明走 move_desc（负面/控制那行）

const STAT_ROWS := [
	{"k": "atk", "label": "攻击"},
	{"k": "hp", "label": "气血"},
	{"k": "spd", "label": "速度"},
	{"k": "crit", "label": "暴击", "pct": true},
	{"k": "dmg", "label": "全伤害增加", "pct": true},   # v58：改名（原来叫"伤害加成"）——与新的"物理/元素增伤"分家
	{"k": "def", "label": "防御"},
	{"k": "dodge", "label": "闪避"},   # v35：闪避是**数值**（不是百分比）——别再加 %
	{"k": "crit_dmg", "label": "暴击伤害", "pct": true},
	# ---- v58：五行那一组（用户第 3、4 条）----
	{"k": "phys_dmg", "label": "物理伤害增加", "pct": true},
	{"k": "metal_dmg", "label": "金元素伤害增加", "pct": true},
	{"k": "water_dmg", "label": "水元素伤害增加", "pct": true},
	{"k": "wood_dmg", "label": "木元素伤害增加", "pct": true},
	{"k": "fire_dmg", "label": "火元素伤害增加", "pct": true},
	{"k": "earth_dmg", "label": "土元素伤害增加", "pct": true},
	{"k": "metal_res", "label": "金元素抗性", "pct": true},
	{"k": "water_res", "label": "水元素抗性", "pct": true},
	{"k": "wood_res", "label": "木元素抗性", "pct": true},
	{"k": "fire_res", "label": "火元素抗性", "pct": true},
	{"k": "earth_res", "label": "土元素抗性", "pct": true},
]
const STAT_DEFAULTS := {"def": 5, "dodge": 5, "crit_dmg": 50}
const STAT_TIPS := {
	"atk": "攻击力 ＝ 基础攻击 ＋ 额外攻击（额外＝兵器＋装备＋武学）。出村战斗与游历决斗都用这个总数：出手伤害 = 攻击 × 招式倍率（再与对手的防御对拼，见「防御」）",
	"hp": "挨打扣的就是它（已含装备/升级/丹药/升星加成；出村战斗就按这里打）。右边小字是**每级涨多少**——只随根骨走（基础 2 点 ＋ 每 25 点根骨再 +1）",
	"spd": "出手顺序按它排（越快的越先动手）；快过对手一倍还能多补一下普攻",
	"crit": "暴击率（%）：这一次出手暴击的概率。两套战斗都已接入。\n⚠ **元素伤害不能暴击**（用户第 4 条）——手里那把是五行兵器时，这一栏只对物理伤害有意义",
	"dmg": "**全伤害增加%**：物理与五行**都**吃这一条（v58 起改叫这个名，数值含意没变）。\n最终倍率 ＝ 1 +（全伤害 + 物理或对应元素的那一条）/100",
	"def": "防御（数值）：挨打时与对手的攻击值对拼——你挡掉的比例 ＝ 防御 ÷（对手攻击 ＋ 你防御）。\n例：敌攻 12 打你防 5 → 挡 29%；防 19（一套极品）→ 挡 61%。\n⚠ **v58：防御只对物理有效**（用户第 4 条）——五行伤害不看防御，改看下面那五条抗性",
	"dodge": "闪避（数值）：出手打过来时和对手的命中比——闪避率 ＝ 你闪避 ÷（你闪避 ＋ 对手命中），\n对手命中 ＝ 100 ＋ 对手速度 × 2（越快越难闪）。例：闪避 5 对速度 10 的怪 → 4%；披风拉满 → 两成上下。\n闪开了这一手整个作废（战斗里浮「闪避！」）",
	"crit_dmg": "暴击时的加成：暴击打出（1 + 这个数/100）倍伤害——默认 50 就是 1.5 倍（已接入出村战斗与游历决斗）",
	"phys_dmg": "**物理伤害增加%**：只加物理伤害（手里那把没元素、或武学本身不带元素时走物理）。\n与「全伤害增加」相加后一起乘",
	"metal_dmg": "**金元素伤害增加%**：手里那把是**金**属性兵器、或放的武学是金元素时才吃",
	"water_dmg": "**水元素伤害增加%**：手里那把是**水**属性兵器、或放的武学是水元素时才吃",
	"wood_dmg": "**木元素伤害增加%**：手里那把是**木**属性兵器、或放的武学是木元素时才吃",
	"fire_dmg": "**火元素伤害增加%**：手里那把是**火**属性兵器、或放的武学是火元素时才吃",
	"earth_dmg": "**土元素伤害增加%**：手里那把是**土**属性兵器、或放的武学是土元素时才吃",
	"metal_res": "**金元素抗性%**：挨金伤害时按这个减伤（正＝少挨，负＝多挨）。五行伤害**只看抗性、不看防御**",
	"water_res": "**水元素抗性%**：挨水伤害时按这个减伤。「水浸·踏浪」会把对手的水抗夺走（可夺成负数）",
	"wood_res": "**木元素抗性%**：挨木伤害时按这个减伤",
	"fire_res": "**火元素抗性%**：挨火伤害时按这个减伤",
	"earth_res": "**土元素抗性%**：挨土伤害时按这个减伤",
}
const DEFAULT_HINT := "点装备/武学格从仓库取用｜［升级］直接花经验池｜右下「服药」喂丹｜Esc 关"

# v44：根骨 · 成长页的尺寸（用户要"框和字都大一点"）——屏是 720 宽，620 是稳的
const GROWTH_W := 620.0
# v60b：详细属性页的尺寸
#   v62w（用户："详细属性还是字数超过了框"）：860 → **980**（正文框 712 → 832），
#   字号 19 → **17**（每行约 23 高）→ 那页 ≈27 行（含换行余量）终于装得下 ✓
const STAT_W := 620.0
const STAT_H := 980.0
const GROWTH_H := 520.0

signal closed
# v4.3：［升 星］→ 统一升星页（角色星 + 兵器/防具/功法·武学）。带一个"先看哪一页签"的提示。
signal forge_pressed(which: String)

var _sel := 0
var _panel: Panel
var _deploy_btn: Button
var _tabs: Array = []
var _name_lb: Label
var _avatar: TextureRect          # v93：圆形头像（照用户草图）
var _avatar_rid := ""
var _star_btn: Button
var _break_btn: Button            # v36：［突破］（境界：每 25 级一道关，吃一颗突破丹）
var _sub_lb: Label
var _gengu_chip: Label          # v44：可按的「根骨 N」牌（点开成长页）
var _growth_panel: Panel        # v44：根骨 · 成长页（框和字都大一号）
var _growth_title: Label
var _growth_body: Label
var _eval_chip: Label
var _exp_bg: ColorRect
var _exp_fill: ColorRect
var _exp_lb: Label
var _up1_btn: Button
var _up_all_btn: Button
# ㊾：_alloc_* 那几个变量随"经验分配"弹窗一起撤了——升级直接吃经验池
var _stat_val_lbs: Array = []
var _elem_head: Label
var _elem_big: Label
var _elem_note: Label
var _equip_cells: Array = []
var _equip_vals: Array = []
var _equip_un_btns: Array = []
var _art_cells: Array = []
var _art_icons: Array = []   # v93l：武学格右上角的小图标（取自素材图集 icon_skill）
var _skill_vals: Array = []
var _art_tag_lbs: Array = []
var _art_un_btns: Array = []
var _talent_lb: Label
var _talent_box: VBoxContainer = null   # ㊿：天赋滚动列表（一行一条，各自动换行）
var _passive_lb: Label
var _stat_sub_lbs: Array = []   # ㊺：属性行的"拆账"小字（目前只有攻击那行用）
var _bond_lb: Label            # ㊽：上阵羁绊那行摘要（点开看明细）
var _pill_btn: Button
var _hint_lb: Label
var _tip_panel: Panel
var _tip_title: Label
var _tip_body: Label
var _press_ms := 0
var _warehouse: Control = null
var _pick_kind := ""
var _pick_role := ""
var _pill_popup = null
# v60b：详细属性页（常驻纸面板；点别处或［关闭］收掉）
var _stat_panel: Panel = null
var _stat_title: Label = null
var _stat_body: Label = null

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_pill_popup = PillPopup.new()
	add_child(_pill_popup)
	_pill_popup.fed.connect(_on_pill_fed)
	_refresh()
	visible = get_parent() == get_tree().root

func bind_warehouse(w: Control) -> void:
	_warehouse = w
	if w != null and not w.picked.is_connected(_on_picked):
		w.picked.connect(_on_picked)
	# v58（用户："装备在仓库也可以装备吧 点击装备跳转到弟子页面就好了"）：
	#   仓库那边点［装备（去弟子页）］→ 这里接住：**关仓库、开弟子页、把这件装上**
	if w != null and not w.equip_requested.is_connected(_on_warehouse_equip):
		w.equip_requested.connect(_on_warehouse_equip)

func _on_warehouse_equip(sid: String) -> void:
	if _warehouse != null and is_instance_valid(_warehouse):
		_warehouse.close()
	open()
	equip_from_warehouse(sid)

func refresh() -> void:
	_refresh()

func _build() -> void:
	var vp := get_viewport_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = vp
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = Panel.new()
	_panel.position = Vector2((vp.x - PANEL_W) * 0.5, (vp.y - PANEL_H) * 0.5)
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.98)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	psb.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", psb)
	add_child(_panel)

	# v61（用户："弟子界面的按钮是不是太拥挤了 是不是重新分布一下"）：
	#   顶上这一行原来是 标题(28..178) ＋［上阵］(178..336) ＋ 三个页签(324..628)——
	#   ［上阵］和第一个页签**压了 12 像素**，页签之间也只隔 8。现在整行重排成一条尺：
	#   标题 90 ｜隔 6｜［上阵］168 ｜隔 8｜ 页签 104×3（彼此隔 8）｜右边留 12
	#   ＝ 28..628，一格不压一格。
	var title := _label("弟子", 28, INK)
	title.position = Vector2(28, 20)
	title.size = Vector2(90, 44)
	_panel.add_child(title)

	_deploy_btn = Button.new()
	_deploy_btn.position = Vector2(124, 18)
	_deploy_btn.size = Vector2(168, 48)
	_deploy_btn.add_theme_font_size_override("font_size", 16)
	_deploy_btn.focus_mode = Control.FOCUS_NONE
	_deploy_btn.pressed.connect(_on_deploy)
	_panel.add_child(_deploy_btn)

	_tabs = []
	for i in ROLE_IDS.size():
		var btn := Button.new()
		btn.text = "?"
		btn.position = Vector2(300.0 + float(i) * 112.0, 18)
		btn.size = Vector2(104, 48)
		btn.add_theme_font_size_override("font_size", 18)
		# v90（用户："还有弟子面板的头像呢"）：**页签上挂头像**——
		#   原来四个页签只有名字，点谁全靠读字；现在左边一张小头像（水墨 LoRA 出的那三张），
		#   一眼认出是谁。取不到图就照旧只有字，不会变空按钮。
		var ft := CharArt.face(str(ROLE_IDS[i]))
		if ft != null:
			btn.icon = ft
			btn.add_theme_constant_override("icon_max_width", 34)
			btn.add_theme_font_size_override("font_size", 16)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_tab.bind(i))
		_panel.add_child(btn)
		_tabs.append(btn)

	var sep := ColorRect.new()
	sep.color = Color(INK.r, INK.g, INK.b, 0.22)
	sep.position = Vector2(28, 74)
	sep.size = Vector2(PANEL_W - 56.0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sep)

	# v93（用户："角色面板你没有看我上次的草图"）：**左上角一个圆形头像**——
	#   草图上就是"圆圈头像 ＋ 名字/星级 ＋〔切换角色〕＋ 经验条"。
	#   圆圈用一个 6 行的 canvas_item 着色器裁（不引外部素材、不增加节点层级）。
	_avatar = TextureRect.new()
	_avatar.position = Vector2(28, 82)
	_avatar.size = Vector2(86, 86)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE     # ⚠ 先设 expand 再设 size
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var av_sh := Shader.new()
	av_sh.code = "shader_type canvas_item;
uniform vec4 ring_col : source_color = vec4(0.32,0.27,0.22,0.60);
void fragment(){
	vec4 c = texture(TEXTURE, UV);
	float d = distance(UV, vec2(0.5));
	float a = smoothstep(0.5, 0.47, d);
	float ring = smoothstep(0.5, 0.47, d) - smoothstep(0.45, 0.42, d);
	c.rgb = mix(c.rgb, ring_col.rgb, ring * ring_col.a);
	c.a = max(c.a * a, ring * ring_col.a);
	COLOR = c;
}
"
	var av_mat := ShaderMaterial.new()
	av_mat.shader = av_sh
	_avatar.material = av_mat
	_panel.add_child(_avatar)

	_name_lb = _label("", 32, INK)
	_name_lb.position = Vector2(132, 82)
	_name_lb.size = Vector2(320, 38)
	_panel.add_child(_name_lb)
	_sub_lb = _label("", 15, Color(INK.r, INK.g, INK.b, 0.60))
	_sub_lb.position = Vector2(132, 130)
	_sub_lb.size = Vector2(360, 22)
	_sub_lb.mouse_filter = Control.MOUSE_FILTER_STOP
	_sub_lb.gui_input.connect(_press_gui.bind(_sub_lb, "profile", -1))
	_panel.add_child(_sub_lb)

	# v44（用户："点击根骨可以显示当前成长 以及下一次成长需要多少根骨"）：
	#   根骨从副标题里那一小截「｜根骨 50」**独立成一颗可按的牌**（挂在名字右边），
	#   点一下开「根骨 · 成长」页（GameState.growth_box 出数，这里只管大字画）。
	#   副标题里不再重复写根骨——一处显示，点它就有账。
	_gengu_chip = Label.new()
	_gengu_chip.text = "根骨 0 ▾"
	_gengu_chip.position = Vector2(456, 84)
	_gengu_chip.size = Vector2(156, 36)
	_gengu_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gengu_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gengu_chip.add_theme_font_size_override("font_size", 16)
	_gengu_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	_gengu_chip.gui_input.connect(_chip_gui)
	_panel.add_child(_gengu_chip)

	# v36：这一格原来是"评价"（按根骨分 丁/丙/乙/甲/绝）——用户改成显示**境界等级**
	#   （境界＝突破次数，0~39；每重 25 级的上限）。评价挪到说明浮框里当附注。
	_eval_chip = Label.new()
	_eval_chip.text = "境界 0"
	_eval_chip.position = Vector2(500, 122)
	_eval_chip.size = Vector2(112, 28)
	_eval_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eval_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_eval_chip.add_theme_font_size_override("font_size", 15)
	_eval_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	_eval_chip.gui_input.connect(_press_gui.bind(_eval_chip, "profile", -1))
	_panel.add_child(_eval_chip)

	# ---- 经验条 + 手动升级 ----
	# v61：经验条改成**整条通栏**（28..612），把［升级］那三颗钮**单独给一整行**——
	#   原来是"经验条 360 宽 ＋ 三颗 64×34 的小钮挤在右边"，14 号字戳起来太小
	#   （用户："升级的按钮也大一点 太小了"）。现在升级 200×50、连升 180×50、
	#   突破 188×50，20 号字，三颗之间各隔 8。
	_exp_bg = ColorRect.new()
	_exp_bg.position = Vector2(28, 156)
	_exp_bg.size = Vector2(584, 24)   # v62x（用户："经验条的字小了"）：20 → 24，好装更大的字
	_exp_bg.color = Color(0.10, 0.09, 0.10, 0.18)
	_exp_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_exp_bg.gui_input.connect(_press_gui.bind(_exp_bg, "exp", -1))
	_panel.add_child(_exp_bg)
	_exp_fill = ColorRect.new()
	_exp_fill.position = Vector2(28, 156)
	_exp_fill.size = Vector2(0, 24)
	_exp_fill.color = Color(0.34, 0.52, 0.62)
	_exp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_exp_fill)
	_exp_lb = _label("", 16, Color(0.96, 0.94, 0.90))   # v62x：13 → 16（字太小 ✗）
	_exp_lb.position = Vector2(28, 156)
	_exp_lb.size = Vector2(584, 24)
	_exp_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exp_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(_exp_lb)

	_up1_btn = Button.new()
	_up1_btn.text = "升级"
	_up1_btn.position = Vector2(28, 184)
	_up1_btn.size = Vector2(200, 50)
	_up1_btn.add_theme_font_size_override("font_size", 20)
	_up1_btn.focus_mode = Control.FOCUS_NONE
	_up1_btn.pressed.connect(_on_level_up.bind(1))
	_apply_ink_button(_up1_btn)
	_panel.add_child(_up1_btn)
	_up_all_btn = Button.new()
	_up_all_btn.text = "连升"
	_up_all_btn.position = Vector2(236, 184)
	_up_all_btn.size = Vector2(180, 50)
	_up_all_btn.add_theme_font_size_override("font_size", 20)
	_up_all_btn.focus_mode = Control.FOCUS_NONE
	_up_all_btn.pressed.connect(_on_level_up.bind(-1))
	_apply_ink_button(_up_all_btn)
	_panel.add_child(_up_all_btn)
	# ㊾：［分配］钮撤了——升级现在直接吃经验池（见 GameState.level_up），
	#   再留一个"池子→个人"的中间步骤只会让人多点一下。
	# v36：［突破］——等级练到境界上限就按它（吃一颗突破丹）。
	_break_btn = Button.new()
	_break_btn.text = "突破"
	_break_btn.position = Vector2(424, 184)
	_break_btn.size = Vector2(188, 50)
	_break_btn.add_theme_font_size_override("font_size", 20)
	_break_btn.focus_mode = Control.FOCUS_NONE
	_break_btn.pressed.connect(_on_break)
	_apply_ink_button(_break_btn)
	_panel.add_child(_break_btn)

	# ---- 属性（合计值） ----
	_panel.add_child(_head("属性（基础 ＋ 额外）", Vector2(28, 242)))
	# v60（用户："弟子属性栏那一块，元素加伤和抗性重叠了……可以做个额外按钮详细属性"）：
	#   正面这一块**只摆最开始那 8 条**（2 列 × 4 行，正好一格不叠一格）；
	#   v58 新加的五行那一组（物理/五行增伤 ＋ 五行抗性，共 11 条）塞不进这块地方，
	#   以前硬按"两列"排，结果第 3 组开始**全叠在同一位置上**（看起来就是"加伤和抗性糊成一团"）。
	#   现在它们统一去［详细属性］那一页（下面这颗钮）。
	#   v60b（用户："详细属性按钮太小了 要加大一些"）：14 号小字 → **18 号真按钮**、38 高。
	#   v61：这一页按钮跟"属性"标题同一条带（240..276），底边不再压到第一行数值。
	var sdb := Button.new()
	sdb.text = "详细属性 ▸"
	# v61（手游）：36 → 44 高、上沿提到 236（下面 282 起是属性行）
	sdb.position = Vector2(424, 236)
	sdb.size = Vector2(188, 44)
	sdb.add_theme_font_size_override("font_size", 17)
	sdb.focus_mode = Control.FOCUS_NONE
	sdb.pressed.connect(_on_stat_detail)
	_apply_ink_button(sdb)
	_panel.add_child(sdb)
	_stat_val_lbs = []
	_stat_sub_lbs = []
	for i in mini(STAT_ROWS.size(), 8):
		var row: Dictionary = STAT_ROWS[i]
		var col := 0 if i < 4 else 1
		var r := i % 4
		var x := 28.0 + float(col) * 308.0
		var y := 282.0 + float(r) * 32.0
		var lb := _label(str(row.get("label", "")), 15, Color(INK.r, INK.g, INK.b, 0.55))
		lb.position = Vector2(x, y)
		lb.size = Vector2(96, 26)
		_panel.add_child(lb)
		# ㊺：数值格收窄到只放总数，右边空出来给"拆账"小字
		#   （攻击那一行会写成 基础10＋兵器4；其它行留空）
		var vl := _label("—", 19, INK)
		vl.position = Vector2(x + 104.0, y - 2.0)
		vl.size = Vector2(58, 30)
		vl.mouse_filter = Control.MOUSE_FILTER_STOP
		vl.gui_input.connect(_press_gui.bind(vl, "stat", i))
		_panel.add_child(vl)
		_stat_val_lbs.append(vl)
		var sl := _label("", 12, Color(SEAL.r, SEAL.g, SEAL.b, 0.85))
		sl.position = Vector2(x + 164.0, y + 7.0)
		# 130 宽：第二列用满也不会顶到 PANEL_W(640) 的边（336+164+130=630）
		sl.size = Vector2(130, 20)
		sl.clip_text = true
		_panel.add_child(sl)
		_stat_sub_lbs.append(sl)

	# ---- 攻击属性：只显示当前（v11） ----
	_elem_head = _head("攻击属性", Vector2(28, 414))
	_elem_head.mouse_filter = Control.MOUSE_FILTER_STOP
	_elem_head.gui_input.connect(_press_gui.bind(_elem_head, "elem", -1))
	_panel.add_child(_elem_head)

	_elem_big = Label.new()
	_elem_big.text = "—"
	_elem_big.position = Vector2(28, 438)
	_elem_big.size = Vector2(150, 46)
	_elem_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_elem_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_elem_big.add_theme_font_size_override("font_size", 22)
	_elem_big.mouse_filter = Control.MOUSE_FILTER_STOP
	_elem_big.gui_input.connect(_press_gui.bind(_elem_big, "elem", -1))
	_panel.add_child(_elem_big)

	_elem_note = _label("只显示当前：空手 / 无元素兵器按「物理」——换兵器它就跟着变\n（七类：金木水火土／物理／真实；相克细则等正式战斗再定）", 13, Color(INK.r, INK.g, INK.b, 0.45))   # v61（手游）：12 → 13 号
	_elem_note.position = Vector2(190, 440)
	_elem_note.size = Vector2(438, 42)
	_elem_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_elem_note)

	# ---- ㊽：上阵羁绊（一行摘要；点开看明细）----
	_bond_lb = _label("羁绊：—", 14, GOLD)
	_bond_lb.position = Vector2(28, 490)
	_bond_lb.size = Vector2(600, 24)
	_bond_lb.clip_text = true
	_bond_lb.mouse_filter = Control.MOUSE_FILTER_STOP
	_bond_lb.gui_input.connect(_press_gui.bind(_bond_lb, "bond", -1))
	_panel.add_child(_bond_lb)

	# ---- 装备（四格全通）+ 升星 ----
	_panel.add_child(_head("装备", Vector2(28, 522)))

	# v4.3（用户："弟子界面加一个升星按钮，展开的页面可以看到差多少碎片、和升星什么效果，
	#   功法和武学也要加"）：原来这儿是两颗按钮（［角色星 0/6］开一个小弹窗 ＋［升星台］
	#   开器物星面板），一台手机上一个升星要分两处点，很容易以为"功法没地方升"。
	#   现在**并成一颗**［升 星］→ 一页四个页签：角色星 / 兵器 / 防具 / 功法·武学。
	#   碎片的"还差几片"、功法的"差几本"都在那一页的行上和明细里。
	_star_btn = Button.new()
	# v61（手游）：34 → 44 高、字 16 → 18（并把上沿提到 512，别压到 560 起的装备格）
	_star_btn.position = Vector2(146, 512)
	_star_btn.size = Vector2(466, 44)
	_star_btn.add_theme_font_size_override("font_size", 18)
	_star_btn.focus_mode = Control.FOCUS_NONE
	_star_btn.pressed.connect(_on_forge)
	_apply_ink_button(_star_btn)
	_panel.add_child(_star_btn)

	_equip_cells = []
	_equip_vals = []
	_equip_un_btns = []
	for k in 4:
		var slot := str(SLOTS[k]["slot"])
		var col2 := k % 2
		var row2 := 0 if k < 2 else 1
		# v61（用户："弟子界面 装备栏装备文字超出【框加大】"）：
		#   病根：格内文字是 **22 号**、可用宽只有 **154**（右边要给［卸下］留位），
		#   而"青锋剑★★（火）"这类要 170~180 宽 → 自动换行折成两行，
		#   但那个 Label 只有 **26 高（一行）**，第二行被切掉——看着就是"字超出框"。
		#   现在格高 84 → **100**、文字框 26 → **56（两行）**，两行都看得见。
		var cell := _make_cell(str(SLOTS[k]["label"]), Vector2(28.0 + float(col2) * 292.0, 560.0 + float(row2) * 104.0), Vector2(284, 100), true)
		_panel.add_child(cell)
		_equip_cells.append(cell)
		_equip_vals.append(cell.get_meta("value_label"))
		_wire_cell(cell, slot, k)
		var ub := _make_unequip_btn(cell, Vector2(176, 44))
		ub.pressed.connect(_on_slot_unequip.bind(slot))
		_equip_un_btns.append(ub)

	# ---- 武学（3 可装 + 大招；被动在天赋框） ----
	# v61：整段下移 32（装备格加高让位）——776 起
	_panel.add_child(_head("武学", Vector2(28, 776)))
	_art_cells = []
	_skill_vals = []
	_art_tag_lbs = []
	_art_un_btns = []
	for k in 4:
		var col3 := k % 2
		var row3 := 0 if k < 2 else 1
		var head_txt := "武学 " + str(k + 1)
		var kind := "art"
		if k == 3:
			head_txt = "大招（怒气）"
			kind = "ult"
		var cell2 := _make_cell(head_txt, Vector2(28.0 + float(col3) * 292.0, 800.0 + float(row3) * 90.0), Vector2(284, 86), true)
		_panel.add_child(cell2)
		_art_cells.append(cell2)
		_skill_vals.append(cell2.get_meta("value_label"))
		# v93l（用户："武学…图标也换成图集里的"）：格右上角挂一枚**武学图标**
		var ic := TextureRect.new()
		ic.position = Vector2(284.0 - 46.0, 6.0)
		ic.size = Vector2(34, 34)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell2.add_child(ic)
		_art_icons.append(ic)
		var tag := _label("", 13, Color(INK.r, INK.g, INK.b, 0.50))   # v61（手游）：12 → 13 号
		tag.position = Vector2(16, 60)
		tag.size = Vector2(252, 22)
		cell2.add_child(tag)
		_art_tag_lbs.append(tag)
		_wire_cell(cell2, kind, k)
		if k < FREE_SLOTS:
			var ub2 := _make_unequip_btn(cell2, Vector2(176, 38))
			ub2.pressed.connect(_on_art_unequip.bind(k))
			_art_un_btns.append(ub2)

	# ---- 天赋（左） ----
	# ㊹ 修"天赋框字体重合"：框加高到 182、天赋区 12~146、被动 148，两个 Label 开 clip_text。
	# ㊿ 再修"主角这种天赋多的还是会超出窗口"：
	#   · 主角走五问，一人 5 条天赋 ＋ 自带 ＋ 被动 —— 条数是**会长**的，
	#     再高的固定框迟早也会满，所以天赋区改成**可滚动列表**（一行一条，各自动换行）；
	#   · 框本身也加高：182 → 238（面板 1212 → 1250 补回来），被动挪到 198；
	#   · 底下的提示行 /［关闭］跟着往下让位（提示行 1204、关闭 1194）。
	#   ⚠ 滚动区是 STOP（要吃拖动）；所以"长按看说明"挪到**标题**上（点"天赋"两个字）。
	# v61：整段下移 32（装备格加高让位）；框本身收 32（222 → 190）把空间还回去——
	#   天赋区本来就是滚动列表，少 32 只少半行，比"装备名被切掉"划算。
	var th := _head("天赋", Vector2(28, 988))
	# ㊿：滚动区吃掉拖动（要能滑），所以"长按看说明"改绑在**标题**上
	th.mouse_filter = Control.MOUSE_FILTER_STOP
	th.gui_input.connect(_press_gui.bind(th, "talents", -1))
	_panel.add_child(th)
	var bar := Panel.new()
	bar.position = Vector2(28, 1010)
	bar.size = Vector2(340.0, 190.0)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_theme_stylebox_override("panel", _soft_sb())
	bar.gui_input.connect(_press_gui.bind(bar, "talents", -1))
	_panel.add_child(bar)
	var tscroll = ScrollContainer.new()
	UiKit.drag_scroll(tscroll)
	tscroll.position = Vector2(16, 12)
	tscroll.size = Vector2(308.0, 132.0)
	tscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bar.add_child(tscroll)
	_talent_box = VBoxContainer.new()
	_talent_box.custom_minimum_size = Vector2(292, 0)
	_talent_box.add_theme_constant_override("separation", 2)
	tscroll.add_child(_talent_box)
	# v14：被动撤格——搬进天赋框，朱红高亮
	_passive_lb = _label("", 14, SEAL)
	_passive_lb.position = Vector2(16, 148)
	_passive_lb.size = Vector2(308.0, 34.0)
	_passive_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_passive_lb.clip_text = true
	bar.add_child(_passive_lb)

	# ---- 服药 · 包裹（右，v13：一格开弹窗——丹方随便加，弹窗里滚动） ----
	# v61（用户："主界面的弟子面板那里除去这个显示"）：
	#   **"本境：属性丹 x/y ＋ 包裹：…"那一整块撤掉**——它信息又密又小（12 号字挤 228 宽），
	#   现在挪进服药弹窗里那两个新选项：【当前服用状态查明】/【当前丹药查明】。
	#   空出来的地方留给［服药］按钮本身（52 → 64 高，字 18 → 20）。
	var phead := _label("服药 · 包裹", 20, Color(INK.r, INK.g, INK.b, 0.70))
	phead.position = Vector2(384, 988)
	phead.size = Vector2(228, 28)
	phead.mouse_filter = Control.MOUSE_FILTER_STOP
	phead.gui_input.connect(_press_gui.bind(phead, "pills", -1))
	_panel.add_child(phead)
	_pill_btn = Button.new()
	_pill_btn.text = "服药"
	_pill_btn.position = Vector2(384, 1016)
	_pill_btn.size = Vector2(228, 64)
	_pill_btn.add_theme_font_size_override("font_size", 20)
	_pill_btn.focus_mode = Control.FOCUS_NONE
	_pill_btn.pressed.connect(_on_pill_open)
	_apply_ink_button(_pill_btn)
	_panel.add_child(_pill_btn)
	# （v61 删：_pill_info —— 原来那个 228×70 的"本境/包裹"小字块）

	# v61：提示行改成**整条页脚**（584 宽）。
	#   ⚠ 探针查出来的一处老毛病：这是 CJK 文本 + 自动换行（WORD_SMART），
	#     Godot 会把 Label 的"最小宽度"算成**整句**（中文没有空格可断），
	#     所以写 size=(374,…) 时它实际被撑到 564 宽——尾巴正好钻到［关闭］底下。
	#     现在给它整幅宽度（584）：一句长的也就一行，真要两行就往下排，不再横着顶出去。
	# v62x（用户："底部的字去掉"）：页脚那一行常驻提示**不再显示**。
	#   ⚠ 这个 Label 保留着——它是"银两不够 / 这格装不了"那些**瞬时提示**的落脚点
	#   （_set_msg 会写它），只是默认不再摆 DEFAULT_HINT 那串常驻文字。
	_hint_lb = _label("", 13, Color(INK.r, INK.g, INK.b, 0.55))
	_hint_lb.position = Vector2(28, 1206)
	_hint_lb.size = Vector2(584, 36)
	_hint_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_hint_lb)

	# ［关闭］挪到"服药"那一列的下沿（提示行上面那条空带，1140 上下）——
	#   原来是跟提示行并排，两颗都在底下挤。
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(384, 1128)
	close_btn.size = Vector2(228, 56)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	_apply_ink_button(close_btn)
	_panel.add_child(close_btn)

	# ---- 说明浮框 ----
	# ㊿：浮框放大（390×200 → 560×440）。主角那条"天赋"正文有 200~300 字，
	#   老框按 14 号字只装得下 ~190 字，于是"天赋多的还是超出窗口"。
	# ㊿s：再放大到 620×660——"羁绊"那条明细是**三条羁绊逐条列**（头部＋说明＋
	#   每个人拿什么＋全队＋当前看的人拿到什么），三人全在阵里时有 20~25 行，
	#   15 号字约 500px，440 高的框（正文只有 374）装不下 → 就是"羁绊框字幕超出"。
	#   正文给到 584 宽 × 590 高（≈29 行 ≈ 580px），顺带把"天赋"那条也一起宽松了。
	_tip_panel = Panel.new()
	_tip_panel.size = Vector2(620, 660)
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_theme_stylebox_override("panel", _soft_sb(true))
	_tip_panel.visible = false
	add_child(_tip_panel)
	_tip_title = _label("", 18, SEAL)
	_tip_title.position = Vector2(18, 12)
	_tip_title.size = Vector2(584, 30)
	_tip_panel.add_child(_tip_title)
	_tip_body = _label("", 15, INK)
	_tip_body.position = Vector2(18, 52)
	_tip_body.size = Vector2(584, 590)
	_tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_panel.add_child(_tip_body)

	# ---- v44：根骨 · 成长页 ----
	#   用户："点击根骨可以显示当前成长 以及下一次成长需要多少根骨【框和字都大一点】"。
	#   所以它不跟普通浮框共用一套（那个是按住才显示、一松手就收）：
	#   这是**点一下常驻**的一页，框 620×520、标题 26 号、正文 21 号（浮框是 18/15）。
	_growth_panel = Panel.new()
	_growth_panel.size = Vector2(GROWTH_W, GROWTH_H)
	_growth_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_growth_panel.add_theme_stylebox_override("panel", _soft_sb(true))
	_growth_panel.visible = false
	add_child(_growth_panel)
	_growth_title = _label("", 26, SEAL)
	_growth_title.position = Vector2(24, 18)
	_growth_title.size = Vector2(GROWTH_W - 48.0, 40)
	_growth_panel.add_child(_growth_title)
	_growth_body = _label("", 23, INK)   # v62x（用户："长按的天赋说明 字也小了"）：21 → 23
	_growth_body.position = Vector2(24, 70)
	_growth_body.size = Vector2(GROWTH_W - 48.0, GROWTH_H - 148.0)
	_growth_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_growth_panel.add_child(_growth_body)
	var gclose := Button.new()
	gclose.text = "收　起"
	gclose.position = Vector2((GROWTH_W - 180.0) * 0.5, GROWTH_H - 74.0)
	gclose.size = Vector2(180, 50)
	gclose.add_theme_font_size_override("font_size", 19)
	gclose.focus_mode = Control.FOCUS_NONE
	gclose.pressed.connect(_hide_growth)
	_growth_panel.add_child(gclose)

	# ---- v60b：（用户："详细属性按钮太小了"）详细属性页——跟根骨页同一个路数 ----
	#   正面 8 条 ＋ 物理/五行增伤 ＋ 五行抗性，一共 19 行；620×860 的纸上 19 号字
	#   排 26 行（约 676）≤ 正文框 712，装得下。
	_stat_panel = Panel.new()
	_stat_panel.size = Vector2(STAT_W, STAT_H)
	_stat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_stat_panel.add_theme_stylebox_override("panel", _soft_sb(true))
	_stat_panel.visible = false
	add_child(_stat_panel)
	_stat_title = _label("详细属性 · 全览", 26, SEAL)
	_stat_title.position = Vector2(24, 18)
	_stat_title.size = Vector2(STAT_W - 48.0, 40)
	_stat_panel.add_child(_stat_title)
	_stat_body = _label("", 17, INK)   # v62w：19 → 17（装得下的关键之一）
	_stat_body.position = Vector2(24, 70)
	_stat_body.size = Vector2(STAT_W - 48.0, STAT_H - 158.0)   # v62w：留出底部按钮的位置
	_stat_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stat_panel.add_child(_stat_body)
	var sclose := Button.new()
	sclose.text = "关　闭"
	sclose.position = Vector2((STAT_W - 180.0) * 0.5, STAT_H - 74.0)
	sclose.size = Vector2(180, 50)
	sclose.add_theme_font_size_override("font_size", 19)
	sclose.focus_mode = Control.FOCUS_NONE
	sclose.pressed.connect(_hide_stat_detail)
	_stat_panel.add_child(sclose)

func _label(text: String, font_size: int, col: Color) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", col)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lb

func _head(text: String, pos: Vector2) -> Label:
	var lb := _label(text, 20, Color(INK.r, INK.g, INK.b, 0.70))
	lb.position = pos
	lb.size = Vector2(320, 28)
	return lb

func _soft_sb(opaque := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if opaque:
		sb.bg_color = Color(0.955, 0.937, 0.886, 0.99)
	else:
		sb.bg_color = Color(1.0, 1.0, 1.0, 0.35)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(INK.r, INK.g, INK.b, 0.22)
	sb.set_border_width_all(1)
	return sb

func _flat(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	return sb

func _eval_sb(tier: String) -> StyleBoxFlat:
	var c: Color = EVAL_COL.get(tier, INK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c.r, c.g, c.b, 0.94)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(INK.r, INK.g, INK.b, 0.45)
	sb.set_border_width_all(1)
	return sb

func _make_cell(head_text: String, pos: Vector2, sz: Vector2, reserve_right: bool) -> Panel:
	var cell := Panel.new()
	cell.position = pos
	cell.size = sz
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_stylebox_override("panel", _soft_sb())
	var head := _label(head_text, 16, Color(INK.r, INK.g, INK.b, 0.55))
	head.position = Vector2(16, 8)
	head.size = Vector2(sz.x - 32.0, 24)
	cell.add_child(head)
	var val := _label("—", 22, INK)
	val.position = Vector2(16, 34)
	if reserve_right:
		# v61：高度按格子给（原来的 26 只够一行，长件名折行就被切）
		val.size = Vector2(sz.x - 130.0, maxf(26.0, sz.y - 44.0))
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		val.size = Vector2(sz.x - 32.0, 34)
	cell.add_child(val)
	cell.set_meta("value_label", val)
	return cell

func _wire_cell(cell: Control, kind: String, idx: int) -> void:
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.gui_input.connect(_press_gui.bind(cell, kind, idx))

func _make_unequip_btn(cell: Control, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = "卸下"
	b.position = pos
	# v61（手游）：96×38 → 104×44、字 15 → 17（这是最容易被误触的一颗小钮）
	b.size = Vector2(104, 44)
	b.add_theme_font_size_override("font_size", 17)
	b.focus_mode = Control.FOCUS_NONE
	b.visible = false
	_apply_ink_button(b)
	cell.add_child(b)
	return b

func _apply_ink_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.19, 0.20, 0.96)))
	btn.add_theme_stylebox_override("hover", _flat(Color(0.31, 0.27, 0.27, 0.96)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.11, 0.12, 0.96)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.35)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	btn.add_theme_color_override("font_disabled_color", Color(0.94, 0.91, 0.84, 0.45))

func _style_deploy(on: bool) -> void:
	if on:
		_deploy_btn.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.19, 0.20, 0.96)))
		_deploy_btn.add_theme_stylebox_override("hover", _flat(Color(0.31, 0.27, 0.27, 0.96)))
		_deploy_btn.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.11, 0.12, 0.96)))
	else:
		_deploy_btn.add_theme_stylebox_override("normal", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.92)))
		_deploy_btn.add_theme_stylebox_override("hover", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.78)))
		_deploy_btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r * 0.7, SEAL.g * 0.7, SEAL.b * 0.7, 0.95)))
	_deploy_btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	_deploy_btn.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))

func _style_tab(btn: Button, selected: bool) -> void:
	if selected:
		btn.add_theme_stylebox_override("normal", _flat(Color(INK.r, INK.g, INK.b, 0.92)))
		btn.add_theme_stylebox_override("hover", _flat(Color(INK.r, INK.g, INK.b, 0.85)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.90)))
		btn.add_theme_color_override("font_color", PAPER)
		btn.add_theme_color_override("font_hover_color", PAPER)
	else:
		btn.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.30)))
		btn.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.55)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.60)))
		btn.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.75))
		btn.add_theme_color_override("font_hover_color", INK)
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))

func _style_chip(chip: Label, lit: bool, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	if lit:
		sb.bg_color = Color(col.r, col.g, col.b, 0.92)
		sb.border_color = Color(INK.r, INK.g, INK.b, 0.55)
		chip.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	else:
		sb.bg_color = Color(0, 0, 0, 0.05)
		sb.border_color = Color(INK.r, INK.g, INK.b, 0.16)
		chip.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.35))
	chip.add_theme_stylebox_override("normal", sb)

# ---- 数据 ----

func _joined(i: int) -> bool:
	var rid := str(ROLE_IDS[i])
	if rid == "chen_shi":
		return GameState.disciple_joined
	if rid == "qingluan":
		return GameState.qingluan_joined
	return true

func _role(i: int) -> Dictionary:
	var d: Dictionary = GameState.role_data(str(ROLE_IDS[i]))
	if d.is_empty():
		return {"name": "?", "sub": "", "lv": 1, "exp": 0, "gengu": 0, "stats": {}, "weapon": "", "weapon_label": "", "gear": {}, "skills": [], "talents": [], "innate": "", "innate_desc": "", "ult": {}, "tech": {}}
	return d

func _elem_key(role: Dictionary) -> String:
	var wid := str(role.get("weapon", ""))
	if wid == "":
		return "phys"
	# v58：元素活起来了——兵器的五行是**逐件摇的**（上品起），存在 GameState.item_elems，
	#   所以不能再直接读表（`Cards.elem_of` 只对"表里写死元素"的功法有效）。
	#   口径：表里写死的优先 → 兵器的"当前那一把" → 都没有＝物理。
	var e := GameState.elem_of_card(wid)
	if e == "":
		return "phys"
	return e

func _elem_cn(key: String) -> String:
	if ELEM.has(key):
		return str(ELEM[key].get("text", ""))
	return Elem.cn(key if key != "phys" else "")

func _slot_sid(role: Dictionary, slot: String) -> String:
	if slot == "weapon":
		return str(role.get("weapon", ""))
	var gear: Dictionary = role.get("gear", {})
	return str(gear.get(slot, ""))

func _weapon_text(role: Dictionary) -> String:
	if str(role.get("weapon", "")) == "":
		return "空手（拳法·物理）"
	var wid := str(role.get("weapon", ""))
	var nm := str(role.get("weapon_label", ""))
	if nm == "":
		# v60（用户报的："点上装备，没合成的碎片变完整穿上了"）：这里原来读 name_of——那是
		#   **残卡的套名**（长剑），而玩家手里的成品叫青锋剑（item_name）。仓库格子上写着
		#   「长剑·锋」，弟子面板却写"兵器：长剑"，看着就像那片碎片自己变完整穿上身了。
		#   出征屏/游历/仓库/装配窗全是 item_name，这里对齐。
		nm = Cards.item_name(wid)
	# v35：星记在件上——面板这里不再问"谁拿着"
	return nm + GameState.star_marks(wid) + "（" + _elem_cn(_elem_key(role)) + "）"

func _slot_text(role: Dictionary, slot: String) -> String:
	if slot == "weapon":
		return _weapon_text(role)
	var sid := _slot_sid(role, slot)
	if sid == "":
		return "—"
	# 三件套的套名与成品名现在一致（皮甲/青玉佩/旧披风…），仍统一走 item_name：与仓库同口径
	return Cards.item_name(sid) + GameState.star_marks(sid)

func _stat_text(stats: Dictionary, row: Dictionary) -> String:
	var k := str(row.get("k", ""))
	var val := 0
	if stats.has(k):
		val = int(round(float(stats[k])))
	elif STAT_DEFAULTS.has(k):
		val = int(STAT_DEFAULTS[k])
	else:
		return "—"
	var s := str(val)
	if bool(row.get("pct", false)):
		s += "%"
	return s

# ㊿：天赋那一段拆成"一条一行"——滚动列表要的是每一行的真实高度，
#   一个整段的大 Label 在容器里量不出换行后的高度（会算成一行）。
func _talent_lines(role: Dictionary) -> Array:
	# v62x（用户："天赋只显示天赋名字——毕竟长按显示全部"）：
	#   这里只给**名字**（说明全挪到长按「天赋」标题的那一页）。
	var lines: Array = []
	var inn := str(role.get("innate", ""))
	if inn != "":
		lines.append("【自带】" + inn)
	for t in role.get("talents", []):
		lines.append("· " + str(t))
	if lines.is_empty():
		lines.append("（无）")
	return lines

# ㊿：把天赋灌进滚动列表。天赋条数是会长的（五问给 5 条），所以这里**不设上限**，
#   多了就往下滚——不再是"写满就裁掉"。
func _fill_talent_box(role: Dictionary) -> void:
	if _talent_box == null:
		return
	# ⚠ 先 remove_child 再 queue_free：queue_free 要等到帧末，只调它的话，
	#   这一帧里新旧两批会同时在容器里（高度算成两份，看着会闪一下）。
	for c in _talent_box.get_children():
		_talent_box.remove_child(c)
		c.queue_free()
	for ln_v in _talent_lines(role):
		var lb := _label(str(ln_v), 13, INK)
		lb.custom_minimum_size = Vector2(292, 0)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_talent_box.add_child(lb)

func _talent_text(role: Dictionary) -> String:
	var lines: Array = []
	var inn := str(role.get("innate", ""))
	if inn != "":
		var d := str(role.get("innate_desc", ""))
		var tail := ""
		if d != "":
			tail = "：" + d
		lines.append("【自带】" + inn + tail)
	var ts: Array = role.get("talents", [])
	for t in ts:
		# ㉗：账本里现在只存纯名字，说明现查（以前是把说明拼在名字里存的）
		var td := GameState.talent_desc(str(t))
		lines.append("· " + str(t) + ("（" + td + "）" if td != "" else ""))
	if lines.is_empty():
		lines.append("（无）")
	return "\n".join(PackedStringArray(lines))

# ---- 刷新 ----

func _refresh() -> void:
	var role := _role(_sel)
	var rid := str(ROLE_IDS[_sel])
	var lv := int(role.get("lv", 1))
	var gengu := int(role.get("gengu", 0))
	var exp := int(role.get("exp", 0))
	var avail := GameState.levels_available(rid)
	_name_lb.text = str(role.get("name", "?")) + _star_suffix(rid)
	# v93：换人就把圆形头像一起换（胸像优先，没有就退回 Q版）
	if _avatar != null and _avatar_rid != rid:
		_avatar_rid = rid
		# v93f 修（用户："怎么你给个了身体 头只有一半"）：**要头就用头的图**——
		#   face() 是胸像，圆形遮罩按 KEEP_ASPECT_COVERED 居中一裁，正好把头切掉半截。
		var atex := CharArt.q_head(rid)
		if atex == null:
			atex = CharArt.face(rid)
		if atex == null:
			atex = CharArt.q(rid)
		_avatar.texture = atex
	var cap := GameState.level_cap(rid)      # v36：上限随境界走（25×(境界+1)）
	var realm := GameState.role_realm(rid)
	_sub_lb.text = (str(role.get("sub", "")) + "　·　" + str(lv) + "/" + str(cap) + " 级")
	# v44：根骨独立成可按的牌（点开成长页）——副标题里不再重复写
	if _gengu_chip != null:
		_gengu_chip.text = "根骨 " + str(gengu) + " ▾"
		_gengu_chip.add_theme_stylebox_override("normal", _eval_sb(GameState.eval_of(gengu)))
		_gengu_chip.add_theme_color_override("font_color", Color(0.97, 0.95, 0.90))
	if _growth_panel != null and _growth_panel.visible:
		_fill_growth()   # 开着就跟着刷新——刚喂完洗髓丹那笔补课立刻能看见
	# v121（用户："去掉原先角色的境界标识"）：这一格改成显示**进阶境界**（全队共享那条新轴）；
	#   每人一个的"突破次数境界"不再露面（等级上限照旧按它走，只是不显示）。
	_eval_chip.text = "进阶 " + GameState.advance_name() + " · 全体 +" + str(int(GameState.advance_pct() * 100.0)) + "%"
	_eval_chip.add_theme_stylebox_override("normal", _eval_sb(GameState.eval_of(gengu)))
	_eval_chip.add_theme_color_override("font_color", Color(0.97, 0.95, 0.90))
	# ［突破］：到顶才亮（要一颗对应品级的突破丹）
	if _break_btn != null:
		var bchk: Dictionary = GameState.break_can(rid)
		var bpid := GameState.break_pill(rid)
		if bpid == "":
			_break_btn.text = "境界满"
			_break_btn.disabled = true
		elif GameState.need_break(rid):
			var have := GameState.pill_count(bpid)
			_break_btn.text = "突破 ↥" if have > 0 else "缺丹"
			_break_btn.disabled = not bool(bchk.get("ok", false))
		else:
			_break_btn.text = "突破"
			_break_btn.disabled = true
	if lv >= cap:
		if GameState.need_break(rid):
			_exp_lb.text = "已到境界上限（" + str(cap) + "）——先突破　｜ 经验池 " + str(GameState.exp_pool)
			_exp_fill.size = Vector2(584, 20)
			_exp_fill.color = SEAL
		else:
			_exp_lb.text = "已满级（" + str(GameState.LEVEL_MAX) + "）　｜ 经验池 " + str(GameState.exp_pool)
			_exp_fill.size = Vector2(584, 20)
			_exp_fill.color = GOLD
	else:
		var need := GameState.exp_need(lv)
		# ㊾：经验条上的分子改成"个人＋池子可用"——升级钮花的就是这个数，
		#   只显示个人那份会让"可升级！"看起来没道理（池里明明有经验）。
		var usable := exp + GameState.exp_pool
		# v62m（用户："等级突破 也需要消耗银两"）：**升级还要银两**——
		#   单价随等级走，所以这一行把它写出来；银两不够时直接说清（不然"点了没反应"）。
		var sp_lv := GameState.level_silver_cost(lv)
		var sp_txt := "　银两 " + str(sp_lv) + "/级"
		if avail > 0 and GameState.coin("silver") < sp_lv:
			sp_txt += "（不够，现有 " + str(GameState.coin("silver")) + "）"
		_exp_lb.text = "可用经验 " + str(usable) + " / " + str(need) + ("　可升级！" if avail > 0 else "") + "　｜ 池 " + str(GameState.exp_pool) + sp_txt
		_exp_fill.size = Vector2(584.0 * clampf(float(usable) / float(maxi(1, need)), 0.0, 1.0), 20)
		_exp_fill.color = GOLD if avail > 0 else Color(0.34, 0.52, 0.62)
	_up1_btn.disabled = avail < 1
	_up1_btn.text = "升级 ↑" if avail > 0 else "升级"
	_up_all_btn.disabled = avail < 2
	_up_all_btn.text = "连升 " + str(avail) if avail > 1 else "连升"
	var on := GameState.is_deployed(rid)
	_deploy_btn.text = "已上阵 · 点我撤下" if on else "未上阵 · 点我上阵"
	_style_deploy(on)
	_refresh_star_btn(rid)   # ㊿y：角色星按钮（显示 n/6）
	var eff: Dictionary = GameState.panel_stats(rid)   # v48：＝squad_stats ＋ 战斗那份 tfx（天赋/星/专武）
	# ㊺：攻击力 = 基础攻击 + 额外攻击（额外＝兵器＋装备＋武学＋㊽羁绊）。
	#   总数走 panel_stats（＝出村战斗那份口径），拆账走 atk_parts()。
	#   ⚠ 攻击这一行**不折 dmg%**：伤害加成是单独一行，战斗里才乘上去——
	#     折进去会让"拆账加起来≠总数"，那正是这块面板最忌讳的账。
	var ap: Dictionary = GameState.atk_parts(rid, true)
	for i in _stat_val_lbs.size():
		var vl: Label = _stat_val_lbs[i]
		# ⚠ 取下标要先落到显式类型上：STAT_ROWS[i] 是 Variant，
		#   直接 .get() 会吃 UNSAFE_METHOD_ACCESS（这里一律走 Dictionary 局部变量）
		var row0: Dictionary = STAT_ROWS[i]
		vl.text = _stat_text(eff, row0)
		# 只在"攻击"这一行的右边写拆账；其它行清空
		if i < _stat_sub_lbs.size():
			var sl: Label = _stat_sub_lbs[i]
			var kk := str(row0.get("k", ""))
			if kk == "atk":
				var extra := int(ap["extra"])
				sl.text = "基础" + str(int(ap["base"])) + "＋额外" + str(extra)
				sl.add_theme_color_override("font_color", SEAL if extra > 0 else Color(INK.r, INK.g, INK.b, 0.45))
			elif kk == "hp":
				# v38：气血那行写清"每级涨多少"，并且把**成长加成**标出来
				#   （守拙 +2 / 稳桩星再 +2 —— 见 GameState.hp_grow_bonus）
				var gain: Dictionary = GameState.level_gain(rid)
				var grow := GameState.hp_grow_bonus(rid)
				sl.text = "每级 +" + str(int(gain.get("hp", 0))) + ("（成长 +" + str(grow) + "）" if grow > 0 else "")
				sl.add_theme_color_override("font_color", GOLD if grow > 0 else Color(INK.r, INK.g, INK.b, 0.45))
			else:
				sl.text = ""
	var lit := _elem_key(role)
	var info: Dictionary = ELEM[lit]
	_elem_big.text = str(info.get("text", ""))
	_style_chip(_elem_big, true, info.get("col", INK))
	# ㊽：羁绊摘要——生效的金色，一条没生效的写灰并提示"还差谁"
	if _bond_lb != null:
		var on_bonds: Array = Bonds.active(GameState.formation)
		var btxt := "羁绊：" + Bonds.line_for(GameState.formation)
		if on_bonds.is_empty():
			var need: Array = []
			for b in Bonds.all():
				if int((b.get("members", []) as Array).size()) == 2:
					var miss: Array = Bonds.missing(b, GameState.formation)
					if miss.size() == 1:
						need.append(str(b.get("name", "")) + "（差 " + Bonds.role_cn(str(miss[0])) + "）")
			if not need.is_empty():
				btxt += "　·　可凑：" + "、".join(PackedStringArray(need))
			_bond_lb.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.50))
		else:
			_bond_lb.add_theme_color_override("font_color", GOLD)
		_bond_lb.text = btxt
	for j in _equip_vals.size():
		var slot := str(SLOTS[j]["slot"])
		var ev: Label = _equip_vals[j]
		ev.text = _slot_text(role, slot)
		var ub: Button = _equip_un_btns[j]
		ub.visible = _slot_sid(role, slot) != ""
	var sk: Array = role.get("skills", [])
	var ult: Dictionary = role.get("ult", {})
	var passive: Dictionary = role.get("passive", {})
	for j in _skill_vals.size():
		var sv: Label = _skill_vals[j]
		var tag: Label = _art_tag_lbs[j]
		var ic2: TextureRect = _art_icons[j]
		if j < FREE_SLOTS:
			tag.text = "可从仓库取用"
			if j < sk.size():
				sv.text = str(Cards.name_of(str(sk[j]))) + GameState.star_marks(str(sk[j]))
				sv.add_theme_color_override("font_color", INK)
				ic2.texture = DataIcons.art(str(sk[j]))      # 装了哪本就画哪本的图标
			else:
				sv.text = "—"
				sv.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.40))
				ic2.texture = null
			var ub2: Button = _art_un_btns[j]
			ub2.visible = j < sk.size()
		else:
			sv.text = str(ult.get("name", "—"))
			sv.add_theme_color_override("font_color", SEAL)
			tag.text = "怒气满时自动放（游历已接入）"
			ic2.texture = DataIcons.art("art_ult")           # 大招格：一枚固定的"绝招"图标
	_fill_talent_box(role)
	if not passive.is_empty():
		_passive_lb.text = "【被动】" + str(passive.get("name", "")) + "：" + str(passive.get("desc", ""))
	else:
		_passive_lb.text = ""
	# ---- 服药 · 包裹（v13：一格开弹窗；这里只把颗数写在按钮上） ----
	# v61（用户："主界面的弟子面板那里除去这个显示"）：原来这里还往 _pill_info 写
	#   "本境：属性丹 x/y ＋ 包裹：…"一大块小字——**已撤掉**，
	#   那两条信息现在在服药弹窗里：【当前服用状态查明】/【当前丹药查明】。
	var total := 0
	for r in GameState.DAN_RECIPES:
		var pid := str(r["id"])
		# ⚠ 只数"人能吃的"：宠物丹与突破丹不算——它们在包裹里，但不进这个数
		var st := str(r.get("stat", ""))
		if st.begins_with("pet") or st == "break":
			continue
		var c := GameState.pill_count(pid)
		if c > 0:
			total += c
	if total > 0:
		_pill_btn.text = "服药 · " + str(total) + " 颗"
	else:
		_pill_btn.text = "服药 · 包裹空"
	for i in _tabs.size():
		var tb: Button = _tabs[i]
		if not _joined(i):
			tb.text = "？？"
		else:
			var rn := str(_role(i).get("name", "?"))
			if GameState.levels_available(str(ROLE_IDS[i])) > 0:
				rn += " ↑"
			tb.text = rn
		_style_tab(tb, i == _sel)

func _set_msg(s: String) -> void:
	if _hint_lb != null:
		_hint_lb.text = s

# ---- 手动升级 / 服药 ----

func _on_level_up(n: int) -> void:
	var rid := str(ROLE_IDS[_sel])
	var times := n
	if n < 0:
		times = GameState.levels_available(rid)
		if times < 1:
			times = 1
	var r: Dictionary = GameState.level_up(rid, times)
	_set_msg(str(r.get("msg", "")))
	_refresh()

# v36：突破——到境界上限时服一颗对应品级的突破丹（境界 +1、上限 +25 级、基础属性涨一截）
func _on_break() -> void:
	var rid := str(ROLE_IDS[_sel])
	_set_msg(GameState.break_do(rid))
	GameState.save_game()   # 突破是"改了底子"的操作，当场落盘
	_refresh()

func _on_pill_open() -> void:
	_tip_hide()
	_pill_popup.open_for(str(ROLE_IDS[_sel]))

func _on_pill_fed() -> void:
	_refresh()

# ---- ㊾：经验分配弹窗已撤 ----
# ［分配］那套（池子→个人 exp→［升级］）现在并进了 GameState.level_up：
#   点［升级］/［连升］直接从经验池扣（个人那份先花）。所以这里不再有弹窗。

# ---- 说明浮框 ----

# v60b（用户："详细属性按钮太小了"）：换成真按钮后走这一口——开一页**常驻**的全览
#   （跟风骨页一个路数：一块纸面板；点别处就收掉。旧的"按住看说明"一松手就没，
#    装不下 19 行也不方便看。）
func _on_stat_detail() -> void:
	if _stat_panel == null:
		return
	if _stat_panel.visible:
		_hide_stat_detail()
		return
	_tip_hide()
	_hide_growth()
	_fill_stat_detail()
	_stat_panel.position = Vector2((size.x - _stat_panel.size.x) * 0.5,
		clampf(150.0, 8.0, size.y - _stat_panel.size.y - 8.0))
	_stat_panel.visible = true
	_stat_panel.move_to_front()

func _fill_stat_detail() -> void:
	var tip: Dictionary = _tip_for("statall", -1)
	_stat_title.text = str(tip.get("title", "详细属性 · 全览"))
	_stat_body.text = str(tip.get("body", ""))

func _hide_stat_detail() -> void:
	if _stat_panel != null:
		_stat_panel.visible = false


func _press_gui(ev: InputEvent, ctrl: Control, kind: String, idx: int) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_press_ms = Time.get_ticks_msec()
		_tip_show(ctrl, kind, idx)
	else:
		_tip_hide()
		if Time.get_ticks_msec() - _press_ms <= 420:
			_cell_click(kind, idx)

func _tip_show(ctrl: Control, kind: String, idx: int) -> void:
	var d := _tip_for(kind, idx)
	if d.is_empty():
		return
	_hide_growth()   # v44：开别的说明就收掉根骨页（别两页叠着）
	_tip_title.text = str(d.get("title", ""))
	_tip_body.text = str(d.get("body", ""))
	var r := ctrl.get_global_rect()
	# ㊿：浮框放大到 560 宽之后，"贴着控件左右放"已经放不下了（屏才 720）——
	#   改成**水平居中**、纵向贴着被按的那个控件（再夹在屏幕内），看着更稳。
	var x := (size.x - _tip_panel.size.x) * 0.5
	var y := clampf(r.position.y + r.size.y * 0.5 - _tip_panel.size.y * 0.5, 8.0, size.y - _tip_panel.size.y - 8.0)
	_tip_panel.position = Vector2(x, y)
	_tip_panel.visible = true
	_tip_panel.move_to_front()

func _tip_hide() -> void:
	if _tip_panel != null:
		_tip_panel.visible = false

# ---- v44：根骨 · 成长页 ----

func _chip_gui(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	_toggle_growth()

func _toggle_growth() -> void:
	if _growth_panel == null:
		return
	if _growth_panel.visible:
		_hide_growth()
		return
	_tip_hide()
	_fill_growth()
	# 水平居中、纵向贴着「根骨」那块牌（再夹进屏幕里）
	var r := _gengu_chip.get_global_rect()
	var x := (size.x - _growth_panel.size.x) * 0.5
	var y := clampf(r.position.y + r.size.y + 6.0, 8.0, size.y - _growth_panel.size.y - 8.0)
	_growth_panel.position = Vector2(x, y)
	_growth_panel.visible = true
	_growth_panel.move_to_front()

func _fill_growth() -> void:
	var d: Dictionary = GameState.growth_box(str(ROLE_IDS[_sel]))
	_growth_title.text = str(d.get("title", "根骨 · 成长"))
	_growth_body.text = str(d.get("body", ""))

func _hide_growth() -> void:
	if _growth_panel != null:
		_growth_panel.visible = false

# ============================================================
# v4.3：角色星 —— 面板上只留**一颗**［升 星］按钮（显示这个人几星），
#   点开是统一的升星页（menu/star_panel.gd）：角色星 / 兵器 / 防具 / 功法·武学 四个页签。
#   碎片的"还差几片"、功法的"差几本"、每一星的**效果明细**都在那一页里——
#   原来这儿那个小弹窗（六级清单 + 升星键）已经并过去了，别在这儿再加第二套。
#   表仍唯一真源：shared/data_stars.gd；账在 GameState.role_stars。
# ============================================================

func _star_suffix(rid: String) -> String:
	if not GameState.Stars.is_star_role(rid):
		return ""
	var n := GameState.role_star_of(rid)
	if n <= 0:
		return "　☆" + str(GameState.role_star_max())
	return "　" + "★".repeat(n) + "☆".repeat(maxi(0, GameState.role_star_max() - n))

# 按钮上写：升星 · 角色星 n/6（并提示"有没有东西可升"）
func _refresh_star_btn(rid: String) -> void:
	if _star_btn == null:
		return
	if not GameState.Stars.is_star_role(rid):
		_star_btn.visible = false
		return
	_star_btn.visible = true
	var cur := GameState.role_star_of(rid)
	var maxn := GameState.role_star_max()
	var txt := "升　星　·　角色星 " + str(cur) + "/" + str(maxn)
	if cur >= maxn:
		txt += " · 满"
	elif bool(GameState.role_star_can(rid).get("ok", false)):
		txt += " · 可升"
	_star_btn.text = txt

func _tip_for(kind: String, idx: int) -> Dictionary:
	var role := _role(_sel)
	var eff: Dictionary = GameState.effective_stats(str(ROLE_IDS[_sel]))
	if kind == "stat":
		if idx < 0 or idx >= STAT_ROWS.size():
			return {}
		var row: Dictionary = STAT_ROWS[idx]
		var k := str(row.get("k", ""))
		if k == "atk":
			# ㊺：攻击力单独给一份"拆账"——基础多少、兵器/装备/武学各加多少
			var ap: Dictionary = GameState.atk_parts(str(ROLE_IDS[_sel]))
			return {
				"title": "攻击　=　" + _stat_text(eff, row),
				"body": "攻击力 ＝ 基础攻击 ＋ 额外攻击\n"
					+ GameState.atk_parts_text(str(ROLE_IDS[_sel])) + "\n"
					+ "· 基础攻击：" + str(int(ap["base"])) + "（人物自己的底子；升级、丹药都写在这里面）\n"
					+ "· 兵器攻击：" + str(int(ap["weapon"])) + "（手上那把自带的，写在这件兵器的 item_stats 里）\n"
					+ "· 装备攻击：" + str(int(ap["gear"])) + "（护甲/玉佩/披风里带 atk 的那些）\n"
					+ "· 武学攻击：" + str(int(ap["arts"])) + "（所习武学里带 atk 的那些）\n"
					+ "出村战斗与游历决斗用的就是这个总数：出手伤害 = 攻击 × 招式倍率。",
			}
		return {
			"title": str(row.get("label", "")) + "　=　" + _stat_text(eff, row),
			# v39：气血/攻击这两行把"每级涨多少、离下一档还差几点根骨"接在后面——
			#   玩家问"为什么攻击只 +1"时，第一眼看的就是这两行（见 GameState.growth_detail）
			"body": str(STAT_TIPS.get(k, "——")) + ("\n\n" + GameState.growth_detail(str(ROLE_IDS[_sel])) if k == "hp" or k == "atk" else ""),
		}
	if kind == "bond":
		# ㊽：羁绊明细——生效的打勾并写出给谁加什么，没生效的写差谁
		var lines: Array = []
		for b in Bonds.all():
			var ms: Array = b.get("members", [])
			var is_on := Bonds.is_on(b, GameState.formation)
			var head := ("【已生效】" if is_on else "【未生效】") + str(b.get("name", "")) + "（" + str(b.get("who", "")) + "）"
			if not is_on:
				var miss_names: Array = []
				for m in Bonds.missing(b, GameState.formation):
					miss_names.append(Bonds.role_cn(str(m)))
				head += "　还差：" + "、".join(PackedStringArray(miss_names))
			lines.append(head)
			lines.append("　" + str(b.get("desc", "")))
			var f: Dictionary = b.get("flat", {})
			for rid_k in f.keys():
				lines.append("　· " + Bonds.role_cn(str(rid_k)) + "：" + Bonds.fx_text({"flat": f[rid_k], "pct": {}}))
			var pa: Dictionary = b.get("pct_all", {})
			if not pa.is_empty():
				# ㊿s：跟出征屏同一句（等值就合成"各 +10%"）——两处说法别打架
				lines.append("　· 全队：" + Bonds.pct_text(pa))
			var mine: Dictionary = Bonds.fx_for(str(ROLE_IDS[_sel]), GameState.formation)
			if is_on:
				lines.append("　→ 当前看的人（" + Bonds.role_cn(str(ROLE_IDS[_sel])) + "）拿到：" + Bonds.fx_text(mine))
			lines.append("")
		lines.append("规矩：members 得一个不少地在阵里才生效（点下面［上阵/撤下］调阵容）。")
		lines.append("只算村内这一队——游历是单人上路，没有同伴，所以不带羁绊。")
		return {
			"title": "上阵羁绊　（" + Bonds.line_for(GameState.formation) + "）",
			"body": "\n".join(PackedStringArray(lines)),
		}
	if kind == "exp":
		return {
			"title": "经验条 · 经验池",
			"body": "经验怎么来：挂机收取、出村清缴——都先进「经验池」（看火 +20 是例外，直接记在个人头上）\n㊾：点［升级］/［连升］直接花经验池——个人那份先扣，不够再从池里补；不用先「分配」给谁\n经验只存着、不会自动升：要升就自己点，［连升］把够的等级一次花掉",
		}
	if kind == "statall":
		# v60（用户："元素加伤和抗性重叠了……做个额外按钮详细属性"）：
		#   正面只摆 8 条，剩下的（物理/五行增伤 ＋ 五行抗性，共 11 条）全在这一页。
		#   一页按 19 行排：15 号字、584 宽、每行约 21 高 ≈ 400 ≤ 590（框装得下）。
		var sa: Dictionary = eff
		var sl: Array = []
		sl.append("【常用】")
		for i in mini(STAT_ROWS.size(), 8):
			var r0: Dictionary = STAT_ROWS[i]
			sl.append("　" + str(r0.get("label", "")) + "　" + _stat_text(sa, r0))
		sl.append("")
		sl.append("【物理 / 元素增伤（%）——出手时按这个加】")
		for i2 in range(8, STAT_ROWS.size()):
			var r2: Dictionary = STAT_ROWS[i2]
			var k2 := str(r2.get("k", ""))
			if not k2.ends_with("_dmg"):
				continue
			sl.append("　" + str(r2.get("label", "")) + "　" + _stat_text(sa, r2))
		sl.append("")
		sl.append("【五行抗性（%）——挨打时按这个减伤，可正可负】")
		for i3 in range(8, STAT_ROWS.size()):
			var r3: Dictionary = STAT_ROWS[i3]
			var k3 := str(r3.get("k", ""))
			if not k3.ends_with("_res"):
				continue
			sl.append("　" + str(r3.get("label", "")) + "　" + _stat_text(sa, r3))
		sl.append("")
		sl.append("通道：**物理**吃防御、可以暴击；**元素**不吃防御、不可暴击（基础倍率 ×"
			+ str(snappedf(Elem.ELEM_BASE, 0.01)) + "），改看对手的对应抗性。")
		sl.append("抗性上下限：+" + str(int(Elem.RES_CAP * 100.0)) + "% / " + str(int(Elem.RES_FLOOR * 100.0)) + "%。")
		return {"title": "详细属性 · 全览", "body": "\n".join(PackedStringArray(sl))}
	if kind == "elem":
		# v58：这里成了"五行一页"——把新加的那 11 条属性按当前值列出来
		#   （面板正面 8 行那一片已经占满 1250 高，塞不下；点这一块看明细）
		var st: Dictionary = eff   # `_tip_for` 顶上已经算好这一份了，别重算
		var eb: Array = []
		var cur := _elem_key(role)
		eb.append("只显示当前：空手 / 无元素兵器 = 物理；兵器带五行就按那个亮。")
		eb.append("　　现在：**" + _elem_cn(cur) + "**" + ("（走元素通道）" if Elem.is_elem(cur) else "（走物理通道）"))
		eb.append("")
		eb.append("【伤害通道（用户第 3、4 条）】")
		eb.append("· 物理：吃防御、可以暴击。增伤 ＝ 全伤害 ＋ 物理伤害")
		eb.append("· 元素：**不吃防御、不可暴击**，基础倍率 ×" + str(snappedf(Elem.ELEM_BASE, 0.01))
			+ "，改看对手的对应抗性。增伤 ＝ 全伤害 ＋ 该元素伤害")
		eb.append("")
		eb.append("【增伤（%）】全伤害 " + str(int(st.get("dmg", 0) + st.get("all_dmg", 0)))
			+ "　物理 " + str(int(st.get("phys_dmg", 0))))
		var dl: Array = []
		for e2 in Elem.ORDER:
			dl.append(Elem.cn(e2) + " " + str(int(st.get(e2 + "_dmg", 0))))
		eb.append("　　" + "　".join(PackedStringArray(dl)))
		eb.append("")
		eb.append("【五行抗性（%）——挨打时按这个减伤，可正可负】")
		var rl: Array = []
		for e3 in Elem.ORDER:
			rl.append(Elem.cn(e3) + " " + str(int(st.get(e3 + "_res", 0))))
		eb.append("　　" + "　".join(PackedStringArray(rl)))
		eb.append("抗性上下限：+" + str(int(Elem.RES_CAP * 100.0)) + "% / "
			+ str(int(Elem.RES_FLOOR * 100.0)) + "%（负抗性＝多挨）")
		return {
			"title": "五行 · 元素（" + _elem_cn(cur) + "）",
			"body": "\n".join(PackedStringArray(eb)),
		}
	if kind == "pills":
		return {
			"title": "服药 · 包裹",
			"body": "点［服药］开药包弹窗——丹方有多少种，列多少行（弹窗里可滚动）。\n属性丹（强身·淬体）每人每境 3 颗——每突破一重（境界 +1）+3。\n突破丹不在这里吃——回「弟子」面板点［突破］。\n养灵丹是宠物粮——去「宠物」面板喂。\n弹窗底下两颗钮：【当前服用状态查明】（这名弟子本境还能吃几颗、都吃过什么）与【当前丹药查明】（包裹里现存哪些丹、各多少颗）。",
		}
	if kind == "weapon":
		var wid := str(role.get("weapon", ""))
		if wid == "":
			return {"title": "兵器 · 空手", "body": "空手（拳法）：元素按物理算\n点这里可以从仓库取一件兵器装上"}
		var nm := str(role.get("weapon_label", ""))
		if nm == "":
			nm = Cards.item_name(wid)   # v60：成品名（青锋剑），不是残卡套名（长剑）——见 _weapon_text
		var wcn := str(WEAPON_CN.get(str(Cards.weapon_of(wid)), "拳法"))
		return {
			"title": "兵器 · " + GameState.grade_of(wid),
						"body": nm + GameState.star_marks(wid) + "（" + _elem_cn(_elem_key(role)) + "）\n加成：" + Cards.bonus_text(GameState.starred_stats(wid)) + "\n升星 ×" + str(snappedf(GameState.star_mul(wid), 0.1)) + "（去［升 星］合星——星记在这件上，换谁拿都算）\n装上后：普攻改用" + wcn + "招式",
		}
	if kind == "armor" or kind == "helm" or kind == "cloak":
		var sid := _slot_sid(role, kind)
		var cn := str(SLOT_CN.get(kind, kind))
		if sid == "":
			return {"title": cn + " · 空", "body": "（空）\n点一下：从仓库取一件装上\n加成会计入左边的属性"}
		return {
			"title": cn + " · " + GameState.grade_of(sid),
			"body": Cards.item_name(sid) + GameState.star_marks(sid) + "\n加成：" + Cards.bonus_text(GameState.starred_stats(sid)) + "\n升星 ×" + str(snappedf(GameState.star_mul(sid), 0.1)) + "（去［升 星］合星——星记在这件上，换谁拿都算）\n点格内［卸下］放回仓库",
		}
	if kind == "art":
		var sk: Array = role.get("skills", [])
		if idx < 0 or idx >= FREE_SLOTS:
			return {}
		if idx >= sk.size():
			return {"title": "武学槽 " + str(idx + 1), "body": "（空）\n点一下：从仓库取一本装上\n武学 3 格；第 4 格是大招；被动在天赋框里"}
		var aid := str(sk[idx])
		var art: Dictionary = Cards.art_of(aid)
		return {
			"title": "『" + Cards.name_of(aid) + "』· " + GameState.grade_of(aid),
			"body": "归类：" + (Cards.cat_name(Cards.cat_of(aid)) if Cards.cat_of(aid) != "" else "—") + "\n招式：" + str(art.get("move", "—")) + "\n" + GameData.move_desc(art) + "\n出村战斗：按冷却自动放（冷却 " + str(Cards.art_cd(aid)) + " 次行动）\n星级：" + str(GameState.star_of(aid)) + " / " + str(GameState.STAR_MAX) + "（去［升 星］合星——星记在这门功法上，换谁拿都算）",
		}
	if kind == "ult":
		var ult: Dictionary = role.get("ult", {})
		return {
			"title": "『" + str(ult.get("name", "—")) + "』· 大招",
			# v65f（用户："大招的怒气的显示是不是该更新了 怎么还是34？"）：
			#   这里原来写死 +34，可战斗里实际是 34 × 0.7 × 本人的怒气加成 →
			#   少侠（引气归元 +30%）约 31、陈石/苏 24。改成读 GameState.rage_per_action()。
			"body": str(ult.get("desc", "—")) + "\n怒气：自己每行动一次 +"
				+ str(GameState.rage_per_action(str(ROLE_IDS[_sel])))
				+ "，满 100 下一次出手自动放大招（这一趟带上聚气令／加持还会更多）\n后两格不可卸——这是他的看家本事",
		}
	if kind == "tech":
		var pas: Dictionary = role.get("passive", {})
		return {
			"title": "『" + str(pas.get("name", "—")) + "』· 专属被动",
			"body": str(pas.get("desc", "—")) + "\n被动生效、不需要出手（原自带技转来；数值暂定）\n后两格不可卸",
		}
	if kind == "talents":
		var body_t := _talent_text(role)
		var pas_t: Dictionary = role.get("passive", {})
		if not pas_t.is_empty():
			body_t += "\n【被动】" + str(pas_t.get("name", "")) + "：" + str(pas_t.get("desc", ""))
		return {"title": "天赋", "body": body_t}
	if kind == "profile":
		var lv := int(role.get("lv", 1))
		var gengu := int(role.get("gengu", 0))
		var exp := int(role.get("exp", 0))
		var rid_p := str(ROLE_IDS[_sel])
		var gain: Dictionary = GameState.level_gain(rid_p)
		var allow_s := GameState.stat_pill_allow(rid_p)
		var avail := GameState.levels_available(rid_p)
		var realm := GameState.role_realm(rid_p)
		var cap := GameState.level_cap(rid_p)
		var bpid := GameState.break_pill(rid_p)
		var pill_line := "突破：已是最高境界（" + str(GameState.realm_max()) + " 重）"
		if bpid != "":
			# v62：这一次要几颗（档内 1/2/4/8/16/32 递增）+ 够不够，一眼看清
			var need := GameState.break_pill_need(rid_p)
			var have := GameState.pill_count(bpid)
			pill_line = ("突破：到 " + str(cap) + " 级后要吃 **" + str(need) + " 颗**「" + str(GameState.recipe_of(bpid).get("name", bpid))
				+ "」（包裹里有 " + str(have) + " 颗" + ("——够了" if have >= need else "——还差 " + str(maxi(0, need - have)) + " 颗") + "）"
				+ " ＋ 银两 " + str(GameState.break_silver(rid_p)) + "（现有 " + str(GameState.coin("silver")) + "）")
		return {
			"title": "境界 · 等级 · 根骨",
			"body": ("境界：" + str(realm) + " 重「" + GameState.realm_name(realm) + "」/ 共 " + str(GameState.realm_max())
				+ " 重（**每 25 级一道关**，用突破丹突破一次；上限 " + str(cap) + " / " + str(GameState.LEVEL_MAX) + " 级）\n"
				+ pill_line + "\n"
				+ "突破收益（按根骨 " + str(gengu) + "）：" + _break_gain_text(rid_p) + "\n"
				+ "升级收益：只涨气血（攻击靠突破/装备/功法）\n"
				+ "升级消耗：银两 " + str(GameState.level_silver_cost(lv)) + " 两/级（随等级涨；不够就升不动）\n"
				+ "经验：" + str(exp) + " / " + str(GameState.exp_need(lv)) + "（个人攒的 · 可升 " + str(avail) + " 级）｜经验池 " + str(GameState.exp_pool) + "\n"
				+ "根骨：" + str(gengu) + "（固有资质：越高突破涨得越多）· 评价：" + GameState.eval_of(gengu) + "（附注）\n"
				+ GameState.growth_detail(rid_p) + "\n"
				+ "丹药：已服 " + str(int(role.get("pills_used", 0))) + "/" + str(allow_s) + "（每突破一重可再扩）").replace("**", ""),
		}
	return {}

# v62h：突破的增幅改成**按根骨现算**（BREAK_GAIN 那张定表已退休），所以这里要传角色。
func _break_gain_text(rid: String) -> String:
	var arr: Array = []
	var g := GameState.break_gain(rid)
	for k in g.keys():
		var kk := str(k)
		arr.append(str(Cards.STAT_CN.get(kk, kk)) + " +" + str(int(g[k])))
	return "、".join(PackedStringArray(arr))

# ---- 点击动作 ----

func _cell_click(kind: String, idx: int) -> void:
	_hide_growth()   # v44：点了别处就收掉根骨页
	_hide_stat_detail()   # v60b：详细属性页同理
	if kind == "weapon" or kind == "armor" or kind == "helm" or kind == "cloak":
		_open_pick(kind)
	elif kind == "art":
		if idx >= FREE_SLOTS:
			_set_msg("后两格是大招与自带技——不能换")
			return
		var role := _role(_sel)
		var sk: Array = role.get("skills", [])
		if idx < sk.size():
			_set_msg("这格已经装了——要换先按格里的［卸下］")
		else:
			_open_pick("arts")
	elif kind == "ult":
		_set_msg("大招会在怒气满时自动放——战斗里看它露面")
	elif kind == "tech":
		_set_msg("这是专属被动——不用出手，随行自动生效")
	elif kind == "exp":
		# ㊾：经验条点一下只给句话——升级钮现在直接吃池子，没有"分配"这一步了
		_set_msg("升级直接花经验池：个人那份先扣，不够从池里补。池子现有 " + str(GameState.exp_pool) + " 点。")
	elif kind == "pills":
		_set_msg("点［服药］开药包——丹方在弹窗里按行列；每境限量，升境扩容。")
	elif kind == "profile":
		var role2 := _role(_sel)
		var lv := int(role2.get("lv", 1))
		var lv2 := int(role2.get("lv", 1))
		var rid2 := str(ROLE_IDS[_sel])
		_set_msg("经验 " + str(int(role2.get("exp", 0))) + "/" + str(GameState.exp_need(lv2)) + "——境界 " + str(GameState.role_realm(rid2)) + " 重「" + GameState.realm_name(GameState.role_realm(rid2)) + "」（" + str(lv2) + "/" + str(GameState.level_cap(rid2)) + " 级）")

func _on_forge() -> void:
	# v4.3：带一嘴"先看角色星"——这颗按钮长在弟子面板上，玩家按它多半是来升这人的。
	forge_pressed.emit("role")

func _open_pick(cat: String) -> void:
	if _warehouse == null:
		_set_msg("仓库没接上（面板要挂在主界面里才有）")
		return
	_tip_hide()
	_pick_kind = cat
	_pick_role = str(ROLE_IDS[_sel])
	print("[弟子面板] 从仓库取用：", cat)
	_warehouse.begin_pick(cat)

func _on_picked(sid: String) -> void:
	var msg := ""
	if _pick_kind == "weapon":
		msg = GameState.equip_weapon(_pick_role, sid)
	elif _pick_kind == "arts":
		msg = GameState.equip_art(_pick_role, sid)
	else:
		msg = GameState.equip_gear(_pick_role, _pick_kind, sid)
	_set_msg(msg)
	_refresh()

# ============================================================
# v58（用户："装备在仓库也可以装备吧 点击装备跳转到弟子页面就好了"）：
#   **从仓库直接装**——主界面收到仓库的 equip_requested 之后，开这一页并调这个口。
#   槽位由**卡自己的 pool** 决定（weapon/armor/helm/cloak/arts），装给"当前选中那个人"。
#   ⚠ 仍然只走 GameState.equip_*（与面板里点格子那条路同一个口），不另写一套装配逻辑。
# ============================================================
func equip_from_warehouse(sid: String) -> void:
	if sid == "":
		return
	var pool := str(Cards.by_id(sid).get("pool", ""))
	var rid := str(ROLE_IDS[_sel])
	var msg := ""
	if pool == "weapon":
		msg = GameState.equip_weapon(rid, sid)
	elif pool == "arts":
		msg = GameState.equip_art(rid, sid)
	elif pool == "armor" or pool == "helm" or pool == "cloak":
		msg = GameState.equip_gear(rid, pool, sid)
	else:
		msg = "这件不是能装的东西（" + pool + "）"
	_set_msg(msg)
	_refresh()
	print("[弟子面板] 从仓库直接装：", sid, " -> ", str(GameState.role_data(rid).get("name", rid)), "：", msg)

func _on_slot_unequip(slot: String) -> void:
	var rid := str(ROLE_IDS[_sel])
	var msg := ""
	if slot == "weapon":
		msg = GameState.unequip_weapon(rid)
	else:
		msg = GameState.unequip_gear(rid, slot)
	_set_msg(msg)
	_refresh()

func _on_art_unequip(idx: int) -> void:
	var msg := GameState.unequip_art(str(ROLE_IDS[_sel]), idx)
	_set_msg(msg)
	_refresh()

func _on_deploy() -> void:
	var id := str(ROLE_IDS[_sel])
	if id == "chen_shi" and not GameState.disciple_joined:
		_set_msg("他还没入门——先去历练，回村见过他再说")
		return
	if id == "qingluan" and not GameState.qingluan_joined:
		_set_msg("还没遇上她——先清到第 " + str(GameState.STORY_NVXIA_STAGE) + " 关")
		return
	var msg := GameState.toggle_deploy(id)
	_set_msg(msg + "（站位排序在「出村 → 出战配置」里调；被撤下的人可以去炼丹阁看火）")
	_refresh()

# ---- 开合 ----

# v93：说话人前缀——"chen_shi" 的文件名是 chenshi_01（跟游历那边同一套口径）
func _voice_say() -> void:
	var rid := str(ROLE_IDS[_sel])
	var spk := "chenshi" if rid == "chen_shi" else rid
	Voice.say_file(spk + "_01")

func open() -> void:
	_sel = 0
	if _sel == 0 and not GameState.disciple_joined:
		_sel = 1
	_refresh()
	_voice_say()
	_set_msg("")   # v62x：底部的常驻提示去掉——开屏不再摆 DEFAULT_HINT（要提示看长按）
	visible = true

func close() -> void:
	if not visible:
		return
	_tip_hide()
	_hide_growth()
	if _pill_popup != null and _pill_popup.visible:
		_pill_popup.close()
	visible = false
	closed.emit()

func _on_tab(idx: int) -> void:
	if not _joined(idx):
		var rid := str(ROLE_IDS[idx])
		if rid == "chen_shi":
			_set_msg("他还没入门——先去历练，回村见过他再说")
		else:
			_set_msg("还没遇上她——先清到第 " + str(GameState.STORY_NVXIA_STAGE) + " 关")
		return
	_sel = idx
	_refresh()
	_voice_say()      # v93：换谁就念谁那一句（没录音的静默跳过）

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			close()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_tip_hide()
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _growth_panel != null and _growth_panel.visible:
				_hide_growth()
				return
			if _pill_popup != null and _pill_popup.visible:
				_pill_popup.close()
				return
			close()
