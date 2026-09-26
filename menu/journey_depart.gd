extends Control
# ============================================================
# journey_depart.gd —— 出征屏 v9（㊿c：路程按档）
# v9（㊿c）：①「路程 N 节」按档回填——与 data_journey.formal_cycles 同式：
#   N ＝ min(2＋档, 9) × 5 ＋ 1（1 档 16 节；每高一档 +5；7 档起封顶 46 节）；
#   ②_input 里重复的 ESC 分支（会错跑 debug_clear_diffs）删掉——ESC 只收摊/关屏。
# v8（㉛）：新增「命数」一行——出征前挑一张带上（负面换好处；只顶这一趟；也可以空手走）。
#   六张：横财/翻财/血路/短绳/满囊/舍装；随出征交接（deploy_set 第三参）交给游历舞台。
#   解锁口径＝出村进度 ≥ FATE_MIN_STAGE（5），与游历里的命数节点同一个数（改要两处一起改）。
# v7（㉗）：删掉"四·随身背包"整行（五档背包钮）——容量改由临时仓库担（每趟 6 格底＋买格）。
#   GameState.set_backpack() 仍留着（不再有屏上入口）。
# v6（优化批㉓）：新增「临时扩仓」按钮——花银两给"下一趟"加包裹/临时仓库容量：
#   起步 150 两 = +4 格；同一趟内每再买一次价翻倍（150→300→600…）；只顶下一趟，
#   出发自动带上、结算即失效（不退款；买了没走，下次开屏仍在）。数在 game_state 三个常量里。
# v5（优化批⑱）：出征前自动卸装——点［出发］先弹"出征前整装"确认……
#   （清单列明将卸下的兵器/护甲·玉佩·披风/功法；［确认出征］才真卸，全部放回村仓库）
# v4（优化批⑯）：①修 v3 加背包行留下的压叠；②新增「随身」一行。
# v3（优化批⑧/#2）：加"四 · 随身背包"一行（五档；未到手的显示"锁·首通哪档"）。
# v2（R4 收尾）：右上角"货源"一行。为什么叫这名：出村编队那套是「整备」（formation_panel）。
# 规矩（总案）：已清的档不再列；输了可重试同一档；D1 恒开，逐档解锁。
# 依赖 game_state v33+（deploy_set 第三参）、data_buffs v3.4（命数六张）。
# ============================================================

const GameState := preload("res://shared/game_state.gd")
const Cards := preload("res://shared/data_cards.gd")
const Buffs := preload("res://shared/data_buffs.gd")
const Bonds := preload("res://shared/data_bonds.gd")   # ㊿：出征屏要显示羁绊
const UiKit := preload("res://shared/ui_kit.gd")      # v61：字色六态那一口（font_states）

signal closed
signal deploy_started(party: Array, diff: int)   # ㊿：整车名单（1~3 人）

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)

const PANEL_W := 640.0
# ㊿：面板加高（752 → 1000）。原来那套排法把下半屏挤成一团：
#   · "随身一行"三个人各一条、还自动换行 —— 却只给了 36px，字直接压到下面几行上；
#   · 命数/临时仓库/脚注/报错/按钮彼此只隔 2~6px，一换行就叠；
#   · 选路格最多两行（DIFF_MAX=10），压到"已选"那一行也只剩 6px。
#   现在按"每块都留足自己的高度"重排（见 _build 里的注释），1280 高的屏放得下。
const PANEL_H := 1000.0

const NODE_BASE := 25
const NODE_STEP := 3
const NODE_CAP := 50

# ㉛b：命数解锁门槛——"经历到第 5 档"（该档已开＝前 4 档走完）；与 journey_stage.FATE_UNLOCK_DIFF 同步改
const FATE_MIN_DIFF := 5
# ㉛：六张命数（顺序＝挑卡页里的排法）；㊿：+2（续命/锐意）＝八张
const FATE_LIST := ["fate_greed", "fate_scavenge", "fate_bloodpath", "fate_shortrope", "fate_fullbag", "fate_noarmor", "fate_endure", "fate_sharpen",
	"fate_iron", "fate_allin", "fate_venom"]   # v62o：血勇签已删（用户："血勇签去掉"）
# ㉛：挑卡页里的一行效果（短句；长描述见 data_buffs.desc_of）
const FATE_EFFECT := {
	"fate_greed": "每场文钱 **+100%**　·　攻击 -25%",
	"fate_scavenge": "**每节必定可搜刮**　·　每显示一种物品当前气血 -1.5%",
	"fate_bloodpath": "前方多六节险路（三场精英 + 黑店／破窑／古渡）　·　气血上限 -15% · 攻击 -15%",
		"fate_iron": "**受到的伤害 -50%**　·　**治疗（含吸血）削弱 80%**",
	"fate_allin": "**大招伤害 +100%**　·　**受到的伤害 +50%**",
	"fate_venom": "出手命中即上毒　·　气血上限 -18% · 速度 -18%",
	"fate_shortrope": "**红爆率 +150%**　·　boss 关保底一瓶金酒　·　每节攻击 -2%（无限叠，无下限）",
	"fate_fullbag": "**包裹 +6 格**　·　**速度 -50%**",
	"fate_noarmor": "**攻击 +40% · 暴击 +50%**　·　护甲格封着　·　气血上限 -30%",
	"fate_endure": "**每 2 手回 8% 气血**　·　攻击 -25%",
	"fate_sharpen": "**5% 吸血**　·　气血上限 -50%",
}
# ㊿：挑卡页开多高——按张数算，别写死（加卡时才不会溢出）
const FATE_PANEL_H_BASE := 148.0     # 标题＋说明＋底部"空手走"＋留白
# v62r：挑卡页行高改成多选版那套（78，见 _ask_fate_pick 里的 row_h）——这个常量已退休

var _panel: Panel
var _role_btns: Array = []
# v62c：难度只剩一行字（原来是十格按钮），_diff_btns 已退休——留着空字典只为兼容老调用
var _diff_btns: Dictionary = {}
var _sel_lb: Label
var _pet_lb: Label
var _foot_lb: Label
var _msg_lb: Label
var _pool_lb: Label
var _carry_lb: Label
var _bond_lb: Label = null        # ㊿：选谁上阵那行——v62c 起只报**阵型**（前/中/后）
var _diff_lb: Label = null        # v62c：当前游历难度那一行（原来是一排十格）
var _row_veil: Control = null     # ㊿："站哪儿"那个小框
var _expand_btn: Button
var _fate_btn: Button = null      # ㉛：命数一行
var _go_btn: Button
var _pick_roles: Array = []            # ㊿：这趟带谁（最多 GameState.DEPLOY_MAX 个；第一个是领队）
var _pick_diff := 0
var _pick_fates: Array = []     # v62r（用户："开局命数可多选"）：选中的命数 id 列表（空 = 空手走）
var _confirm_veil: Control = null
var _fate_veil: Control = null    # ㉛：挑卡页

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_refresh()
	visible = get_parent() == get_tree().root

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

	var title := _label("出　征", 30, INK)
	title.position = Vector2(28, 20)
	title.size = Vector2(420, 44)
	_panel.add_child(title)

	var sub := _label("选一名弟子，挑一档路——路上轻重，全看这趟", 18, Color(INK.r, INK.g, INK.b, 0.55))   # v54：15 → 18
	sub.position = Vector2(30, 60)
	sub.size = Vector2(560, 22)
	_panel.add_child(sub)

	_pool_lb = _label("", 16, Color(INK.r, INK.g, INK.b, 0.60))   # v54：13 → 16
	_pool_lb.position = Vector2(280, 32)
	_pool_lb.size = Vector2(332, 24)
	_pool_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_pool_lb)

	var sep := ColorRect.new()
	sep.color = Color(INK.r, INK.g, INK.b, 0.22)
	sep.position = Vector2(28, 88)
	sep.size = Vector2(PANEL_W - 56.0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sep)

	var s1 := _label("一 · 选人（入队的都在列；最多三人）", 18, Color(INK.r, INK.g, INK.b, 0.72))   # v54：15 → 18
	s1.position = Vector2(28, 98)
	s1.size = Vector2(560, 24)
	_panel.add_child(s1)

	# v63（用户："游历那个也挺麻烦——在选人这里直接加一个出战配置的按钮"）：
	#   → 打开与爬塔**同一份**整备面板（formation_panel），保存后这边自动跟上。
	var cfg := Button.new()
	cfg.text = "出战配置 ▸"
	cfg.position = Vector2(500, 92)
	cfg.size = Vector2(116, 38)
	cfg.add_theme_font_size_override("font_size", 16)
	cfg.focus_mode = Control.FOCUS_NONE
	cfg.pressed.connect(_open_formation)
	_style_dark_button(cfg)
	_panel.add_child(cfg)

	# ㊿：羁绊一行——"点谁上阵"最该看见的东西：谁和谁同时在阵里才有加成。
	#   以前这一屏**完全不显示羁绊**，玩家选了三个人也不知道白拿了多少。
	# v62c（用户："点击谁上阵之后的那个一长串的说明 其实没必要 就告诉玩家在前谁在后谁在中就好了"）：
	#   这一行原来是**羁绊说明**（三条羁绊各一行，最多三行 62px）——它顶到 y222，
	#   而上面那排选人钮正好到 y232 → **压字**（用户说的"字数重合"就是这儿）。
	#   现在只写**阵型一行**（前/中/后），框 62 → 26、位置 222 → 238：一行、不压、够看。
	_bond_lb = _label("", 18, Color(SEAL.r, SEAL.g, SEAL.b, 0.95))
	_bond_lb.position = Vector2(28, 238)
	_bond_lb.size = Vector2(584, 26)
	_panel.add_child(_bond_lb)

	var s2 := _label("二 · 游历难度（从 1 起，通关就 +1）", 17, Color(INK.r, INK.g, INK.b, 0.55))
	s2.position = Vector2(28, 284)
	s2.size = Vector2(590, 22)
	_panel.add_child(s2)

	# v62c：难度只留一行字（见 _rebuild_diffs）——一大一小两号，扫一眼就知道走到哪了
	_diff_lb = _label("", 22, INK)
	_diff_lb.position = Vector2(28, 308)
	_diff_lb.size = Vector2(400, 30)
	_panel.add_child(_diff_lb)

	_sel_lb = _label("", 19, INK)   # v54：16 → 19
	_sel_lb.position = Vector2(28, 348)   # v62c：难度只剩一行，整段再上移
	_sel_lb.size = Vector2(590, 28)
	_panel.add_child(_sel_lb)

	var s3 := _label("三 · 携宠（只能带一只；换宠去［宠物］面板）", 17, Color(INK.r, INK.g, INK.b, 0.55))
	s3.position = Vector2(28, 396)
	s3.size = Vector2(590, 22)
	_panel.add_child(s3)

	_pet_lb = _label("", 16, INK)
	_pet_lb.position = Vector2(28, 422)
	_pet_lb.size = Vector2(590, 26)
	_panel.add_child(_pet_lb)

	var s4 := _label("四 · 临时仓库（仓格在下面买——买几格顶几格；容量＝包裹＋仓格）", 17, Color(INK.r, INK.g, INK.b, 0.55))   # v54：13 → 17
	s4.position = Vector2(28, 456)
	s4.size = Vector2(590, 22)
	_panel.add_child(s4)

	# ㉓~㉗：临时仓库——每趟 6 格底；买一格 50 两、下一格贵 50（只顶下一趟）
	_expand_btn = Button.new()
	_expand_btn.text = "临时仓库"
	_expand_btn.position = Vector2(28, 480)
	_expand_btn.size = Vector2(584, 50)
	_expand_btn.add_theme_font_size_override("font_size", 19)   # v54：15 → 19
	_expand_btn.focus_mode = Control.FOCUS_NONE
	_expand_btn.pressed.connect(_on_expand)
	_style_light_button(_expand_btn)
	_panel.add_child(_expand_btn)

	# ㉛：命数——出征前挑一张带上（负面换好处；只顶这一趟；也可以空手走）
	_fate_btn = Button.new()
	_fate_btn.text = "命数"
	_fate_btn.position = Vector2(28, 536)
	_fate_btn.size = Vector2(584, 48)
	_fate_btn.add_theme_font_size_override("font_size", 19)   # v54：15 → 19
	_fate_btn.focus_mode = Control.FOCUS_NONE
	_fate_btn.pressed.connect(_ask_fate_pick)
	_style_light_button(_fate_btn)
	_panel.add_child(_fate_btn)

	# v5：随身一行——出征将自动卸下的清单（预告；真卸在确认之后）
	# ㊿：高度按"三个人各两行"留（12 号字 × 6 行 ≈ 100）——原来只给 36，
	#   一上三个人就压到下面的脚注/报错/按钮上，就是"字数重叠"的来源。
	_carry_lb = _label("", 15, Color(INK.r, INK.g, INK.b, 0.70))   # v54：12 → 15
	_carry_lb.position = Vector2(28, 590)
	_carry_lb.size = Vector2(584, 220)   # v62c：难度只剩一行，再让给「随身」   # 15 号字 × 6 行 ≈ 120；再高就会压到下面的脚注
	_carry_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_carry_lb)

	_foot_lb = _label("", 15, Color(INK.r, INK.g, INK.b, 0.55))   # v54：12 → 15
	_foot_lb.position = Vector2(28, 814)
	_foot_lb.size = Vector2(584, 46)
	_foot_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_foot_lb)

	_msg_lb = _label("", 17, Color(SEAL.r, SEAL.g, SEAL.b, 0.85))   # v54：14 → 17
	_msg_lb.position = Vector2(28, 862)
	_msg_lb.size = Vector2(584, 44)
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_msg_lb)

	_go_btn = Button.new()
	_go_btn.text = "出　发"
	_go_btn.position = Vector2(28, 910)
	_go_btn.size = Vector2(380, 56)
	_go_btn.add_theme_font_size_override("font_size", 24)
	_go_btn.focus_mode = Control.FOCUS_NONE
	_go_btn.pressed.connect(_on_go)
	_style_dark_button(_go_btn)
	_panel.add_child(_go_btn)

	var close_btn := Button.new()
	close_btn.text = "暂不"
	close_btn.position = Vector2(432, 918)
	close_btn.size = Vector2(180, 56)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	_style_light_button(close_btn)
	_panel.add_child(close_btn)

func _label(text: String, font_size: int, col: Color) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", col)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lb

func _flat(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	return sb

func _style_dark_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.19, 0.20, 0.96)))
	btn.add_theme_stylebox_override("hover", _flat(Color(0.31, 0.27, 0.27, 0.96)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.11, 0.12, 0.96)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	# v61：六态一起设——只设 font_color 的话，悬停会回落到默认主题的纯白
	UiKit.font_states(btn, Color(0.94, 0.91, 0.84))
	btn.add_theme_color_override("font_disabled_color", Color(0.94, 0.91, 0.84, 0.35))

func _style_light_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.30)))
	btn.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.55)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.60)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	# v61（用户："临时仓库购买一格之后字体自动变成白色，完全融入白色背景"）：
	#   这里是**浅底**按钮（白 0.30 / 悬停白 0.55）——原来只设了 font_color＝墨色，
	#   悬停那条（font_hover_color）没设 → 回落到默认主题的纯白 → 白字压白底，看不见。
	#   现在六态一次设满（见 UiKit.font_states 那段）。
	UiKit.font_states(btn, Color(INK.r, INK.g, INK.b, 0.80))
	# 锁着/买不起时也要看得见（默认的禁用色是半透明白，压浅底同样糊）
	btn.add_theme_color_override("font_disabled_color", Color(INK.r, INK.g, INK.b, 0.38))

func _style_pick(btn: Button, on: bool) -> void:
	# v61：两个分支都改成"六态一次设满"——原来 on 那支漏 pressed，off 那支漏 pressed/focus，
	#   漏掉的那几态会回落到默认主题的纯白（浅底一按就白）。
	if on:
		btn.add_theme_stylebox_override("normal", _flat(Color(INK.r, INK.g, INK.b, 0.90)))
		btn.add_theme_stylebox_override("hover", _flat(Color(INK.r, INK.g, INK.b, 0.84)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.88)))
		UiKit.font_states(btn, PAPER)
	else:
		btn.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.30)))
		btn.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.55)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.60)))
		UiKit.font_states(btn, Color(INK.r, INK.g, INK.b, 0.75))
	btn.add_theme_color_override("font_disabled_color", Color(INK.r, INK.g, INK.b, 0.34))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))

func _rebuild_roles() -> void:
	for b in _role_btns:
		if is_instance_valid(b):
			b.queue_free()
	_role_btns.clear()
	var ids: Array = GameState.disciple_ids()
	var n := ids.size()
	if n <= 0:
		return
	var w := (584.0 - 12.0 * float(maxi(n - 1, 0))) / float(n)
	for i in n:
		var rid := str(ids[i])
		var b := Button.new()
		b.position = Vector2(28.0 + float(i) * (w + 12.0), 126.0)
		b.size = Vector2(w, 106.0)
		b.text = ""   # 文案由 _paint_role_texts() 统一写（要带站位）
		# v61：18 → **17**。三人一排时每颗只有 186 宽，最长的组合
		#   （三字名 ＋ lv1000 ＋ 未上阵）在 18 号下要 179 ＋内边距 → 按钮被 Godot 撑到 200，
		#   顶出 584 的内容区；17 号下同一条只要 169 ✓ 稳稳在框里。
		#   `clip_text` 是保险：真再长出框也只裁字，绝不让按钮去挤邻居。
		b.add_theme_font_size_override("font_size", 17)
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_role.bind(rid))
		_panel.add_child(b)
		_role_btns.append(b)
	_paint_role_texts()

# ㊿：名册钮上**直接写清站位**——"谁前谁后"以前只藏在"点的顺序"里，玩家看不见。
#   上阵的写「前排／中排／后排」，没上阵的写「未上阵」，一眼分明。
func _paint_role_texts() -> void:
	var ids: Array = GameState.disciple_ids()
	for i in _role_btns.size():
		if i >= ids.size():
			break
		var rid := str(ids[i])
		var b: Button = _role_btns[i]
		if b == null or not is_instance_valid(b):
			continue
		var d: Dictionary = GameState.role_data(rid)
		var st: Dictionary = GameState.effective_stats(rid)
		var lv := int(d.get("lv", 1))
		var rc := _row_cn_of(rid)
		# v61（用户："出征界面选人也字体超出 也不用显示那么多 就显示气血 攻击 名字 等级即可"）：
		#   原来是三行——
		#     少侠　前排 / lv 1 · 初出茅庐 / 攻 19 · 气血 100 · 青锋剑
		#   每颗钮只有 **186 宽**（三个人一排），而第三行 18 号字要 250+ → 直接顶出框外。
		#   现在**只留你要的四样**（名字·等级·攻击·气血）＋站位，压成两行：
		#     少侠　lv1　前排
		#     攻 19 · 气血 100
		#   撤掉的：境界名（"初出茅庐"）与随身兵器名——随身那条在下面「随身」明细里另有全文。
		#   站位（前排/中排/后排/未上阵）**留着**：它是这块面板存在的理由，去了就不知道谁挡刀。
		var head := str(d.get("name", rid)) + "　lv" + str(lv) + "　" + (rc if rc != "" else "未上阵")
		b.text = head + "\n" + "攻 " + str(int(st.get("atk", 0))) + " · 气血 " + str(int(st.get("hp", 0)))

func _rebuild_diffs() -> void:
	# v62c（用户："游历难度也是 给那么多格干什么 就当前游历难度 x不就好了 剩下太多空间了"）：
	#   原来是一排十个数字格（1 / 2锁 / 3锁…），但**同时永远只有一档能走**
	#   （diff_state：已通的藏起来、没到的不给走），所以那一排十格纯属摆设。
	#   现在只留**一行字**：当前游历难度 X。那一行从 52px 缩到 26px，
	#   省下的空间全给了下面的「随身」清单（168 → 220）。
	for b in _diff_btns.values():
		if is_instance_valid(b):
			b.queue_free()
	_diff_btns.clear()
	_pick_diff = 0
	for d in range(1, GameState.DIFF_MAX + 1):
		if GameState.diff_state(d) == "open":
			_pick_diff = d
			break
	if _diff_lb == null:
		return
	if _pick_diff > 0:
		_diff_lb.text = "当前游历难度 " + str(_pick_diff)
	else:
		_diff_lb.text = "所有难度都走通了（新路在后面的版本里）"
#（此处不留——整段删掉；背包改由临时仓库，不再有换装入口）
# v6：临时扩仓——买了会扣银两；出发时 run_state 自动取走
func _on_expand() -> void:
	var r := GameState.buy_run_expand()
	_msg_lb.text = str(r.get("msg", ""))
	print("[出征] ", _msg_lb.text)
	_paint()

func _on_role(rid: String) -> void:
	# ㊿：点一个人不再"直接加进队尾"——弹个小框问"站哪儿"。
	#   原来站位＝点的先后，既看不见也改不了（想换前排得先点掉重选），
	#   而站位是能改命的规矩（敌人普攻只打最前排活人、加持也按排给），必须摆在明面上。
	_ask_row(rid)

# ㊿：某个人该站哪一排——名额跟着"这趟几个人"走：
#   1 人＝只有前排；2 人＝前排/后排；3 人＝前/中/后。
#   机制上站位就是"名册里的下标"（0 前 1 中 2 后），所以这里排的是**名册顺序**。
func _row_names(n: int) -> Array:
	if n <= 1:
		return ["前排"]
	if n == 2:
		return ["前排", "后排"]
	return ["前排", "中排", "后排"]

func _row_cn_of(rid: String) -> String:
	var idx := _pick_roles.find(rid)
	if idx < 0:
		return ""
	var names: Array = _row_names(_pick_roles.size())
	if idx >= names.size():
		return ""
	return str(names[idx])

func _ask_row(rid: String) -> void:
	if _row_veil != null and is_instance_valid(_row_veil):
		return
	var d: Dictionary = GameState.role_data(rid)
	var nm := str(d.get("name", rid))
	var in_party: bool = _pick_roles.has(rid)
	# 选完之后会有几个人（已经在队里的：人数不变；新加的：+1）
	var n_after: int = _pick_roles.size() if in_party else _pick_roles.size() + 1
	n_after = clampi(n_after, 1, GameState.DEPLOY_MAX)
	var vp := get_viewport_rect().size
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.42)
	veil.size = vp
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	_row_veil = veil
	var pw := 520.0
	var ph := 96.0 + float(_row_names(n_after).size()) * 60.0 + (60.0 if in_party else 0.0)
	var panel := Panel.new()
	panel.position = Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.99)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	psb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", psb)
	veil.add_child(panel)

	var tt := _label("「" + nm + "」站哪儿？", 24, INK)
	tt.position = Vector2(0, 16)
	tt.size = Vector2(pw, 34)
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(tt)

	var now_cn := _row_cn_of(rid)
	var sub := _label("这一趟 " + str(n_after) + " 人——前排先挨打，后排躲着输出" + ("（现在站：" + now_cn + "）" if now_cn != "" else ""), 13, Color(INK.r, INK.g, INK.b, 0.62))
	sub.position = Vector2(0, 54)
	sub.size = Vector2(pw, 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sub)

	var y := 84.0
	var names: Array = _row_names(n_after)
	for si in names.size():
		var b := Button.new()
		b.position = Vector2(24, y)
		b.size = Vector2(pw - 48.0, 50)
		var note := "（先挨打）" if si == 0 else ("（躲后面）" if si == names.size() - 1 else "")
		b.text = "站" + str(names[si]) + note
		b.add_theme_font_size_override("font_size", 19)   # v54：17 → 19
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_row_pick.bind(rid, si))
		# 已经在队里、又正好站这一排：标出来（点它＝不动的意思）
		_style_pick(b, in_party and now_cn == str(names[si]))
		panel.add_child(b)
		y += 60.0
	if in_party:
		var off := Button.new()
		off.position = Vector2(24, y + 4.0)
		off.size = Vector2(pw - 48.0, 44)
		off.text = "不上阵（点掉）"
		off.add_theme_font_size_override("font_size", 18)   # v54：15 → 18
		off.focus_mode = Control.FOCUS_NONE
		off.pressed.connect(_on_row_off.bind(rid))
		_style_light_button(off)
		panel.add_child(off)
	# 点空白处＝算了（和"再想想"同义）
	veil.gui_input.connect(_on_row_blank)

func _on_row_pick(rid: String, slot: int) -> void:
	# ㊿：把这个人挪到第 slot 排（其余人依次让位）。
	#   名册顺序＝站位，所以"插进第几位"就是"站第几排"。
	var order: Array = _pick_roles.duplicate()
	if order.has(rid):
		order.erase(rid)
	if order.size() >= GameState.DEPLOY_MAX:
		_msg_lb.text = "最多 " + str(GameState.DEPLOY_MAX) + " 个人同行"
		_close_row()
		_paint()
		return
	var si: int = clampi(slot, 0, order.size())
	order.insert(si, rid)
	_pick_roles = order
	_msg_lb.text = ""
	_close_row()
	_paint()

func _on_row_off(rid: String) -> void:
	if _pick_roles.size() <= 1:
		_msg_lb.text = "至少带一个人上路"
	else:
		_pick_roles.erase(rid)
		_msg_lb.text = ""
	_close_row()
	_paint()

func _on_row_blank(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_close_row()

func _close_row() -> void:
	if _row_veil != null and is_instance_valid(_row_veil):
		_row_veil.queue_free()
	_row_veil = null

func _refresh() -> void:
	if _panel == null:
		return
	var ids: Array = GameState.disciple_ids()
	# ㊿：名单变了（有人加入/离开）就对一遍——把不在册的剔掉，空了补第一个
	var keep: Array = []
	for r in _pick_roles:
		if ids.has(str(r)):
			keep.append(str(r))
	_pick_roles = keep
	if _pick_roles.is_empty() and ids.size() > 0:
		_pick_roles.append(str(ids[0]))
	if _pick_diff <= 0 or GameState.diff_state(_pick_diff) != "open":
		_pick_diff = 0
		for d in range(1, GameState.DIFF_MAX + 1):
			if GameState.diff_state(d) == "open":
				_pick_diff = d
				break
	_rebuild_roles()
	_rebuild_diffs()
	_paint()

# v63（用户："游历那个也挺麻烦——选人那里直接加一个出战配置的按钮"）：
#   打开与爬塔同一份整备面板（formation_panel）；保存后这边的选人自动跟上阵型。
var _formation_panel = null

func _open_formation() -> void:
	if _formation_panel == null:
		_formation_panel = (preload("res://menu/formation_panel.gd") as GDScript).new()
		_formation_panel.saved.connect(_on_formation_saved)
		add_child(_formation_panel)
	_formation_panel.open_config()

func _on_formation_saved() -> void:
	_pick_roles = GameState.formation.duplicate()
	_paint()

func _paint() -> void:
	if _expand_btn != null:
		var price: int = GameState.run_expand_price()
		_expand_btn.text = "临时仓库 " + str(GameState.run_expand_slots()) + " 格：买一格 ＝ " + str(price) + " 两（下一格 " + str(GameState.run_expand_price_after()) + " 两 · 只顶下一趟）"
	var ids: Array = GameState.disciple_ids()
	for i in _role_btns.size():
		var b: Button = _role_btns[i]
		# ㊿：勾中的都亮起来（不是只亮一个）
		_style_pick(b, i < ids.size() and _pick_roles.has(str(ids[i])))
	_paint_role_texts()   # ㊿：站位就写在钮上——换排之后要立刻跟着变
	if _pick_diff > 0:
		# v62c：难度已有自己那一行，这里不再重复——只报路程与同行人数
		_sel_lb.text = "路程 " + str(_nodes_of(_pick_diff)) + " 节 · 最多带 " + str(GameState.DEPLOY_MAX) + " 人"
		if _pick_fates.has("fate_bloodpath"):
			_sel_lb.text += "　＋3 节险路（血路签）"
		# ㊿：站位只在这里点一句——详细的"谁前谁后"在确认页（这里下面只有 38px，
		#   塞两行会压到下一段小标题）
		if _pick_roles.size() > 1:
			_sel_lb.text += "　·　" + str(_pick_roles.size()) + " 人同行"
	else:
		_sel_lb.text = "没有可走的路——能走的档都走通了（新路在后面的版本里）"
	var sw: int = GameState.ladder_swaps("weapon")
	var sa: int = GameState.ladder_swaps("arts")
	_pool_lb.text = "货源：" + _pool_stage_cn() + "段 · 兵器已换 " + str(sw) + " 手／武学已换 " + str(sa) + " 手"
	var pd: Dictionary = GameState.pet_follow_data()
	if pd.is_empty():
		_pet_lb.text = "未携宠（去［宠物］面板点［随行］）"
	else:
		_pet_lb.text = str(pd.get("name", "宠物")) + " · " + str(GameState.pet_follow_stage_name()) + "　随行中"
	_paint_carry()
	_paint_bonds()
	_foot_lb.text = "本趟残卡到结算收进仓库；盘缠不带出；随身装备与功法出征前已自动卸回仓库。"
	_paint_fate_btn()
	_go_btn.disabled = (_pick_roles.is_empty() or _pick_diff <= 0)
	if _go_btn.disabled and _pick_diff <= 0:
		_msg_lb.text = "眼下没有可出征的路——走通的档不再列，新路等后续版本。"

# ---- ㉛：命数一行 + 挑卡页 ----

# ㉛b：命数已解锁？——"经历到第 FATE_MIN_DIFF 档"：该档已开（前几档走完）
func _fate_open() -> bool:
	return GameState.diff_state(FATE_MIN_DIFF) != "locked"

func _paint_fate_btn() -> void:
	if _fate_btn == null:
		return
	if not _fate_open():
		_fate_btn.text = "命数：走通前 " + str(FATE_MIN_DIFF - 1) + " 档才开（已走通 " + str(GameState.diff_cleared_count()) + " 档）"
		_fate_btn.disabled = true
		return
	_fate_btn.disabled = false
	if _pick_fates.is_empty():
		_fate_btn.text = "命数：空手走——点我挑一张带上（负面换好处）"
	else:
		var fnames: Array = []
		for f_v in _pick_fates:
			fnames.append(str(Buffs.name_of(str(f_v))))
		_fate_btn.text = "命数：" + str(_pick_fates.size()) + " 张（" + "、".join(PackedStringArray(fnames)) + "）　（点我改）"

func _ask_fate_pick() -> void:
	if not _fate_open():
		return
	if _fate_veil != null and is_instance_valid(_fate_veil):
		return
	var vp := get_viewport_rect().size
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.42)
	veil.size = vp
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	_fate_veil = veil
	var pw := 640.0
	# v62z（用户："字体超出框 且字小 框也小 大一点 不够容量就上下滑动"）：
	#   面板 560 → 640；行内三行字**开自动换行**、字号各 +1；行高按内容自适应
	#   （每行＝VBoxContainer，高度由换行后的文字撑）；整列放进 **ScrollContainer**，
	#   放不下就上下滑，不再溢出右框。
	var ph := minf(vp.y - 100.0, 1080.0)
	var panel := Panel.new()
	panel.position = Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.99)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	psb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", psb)
	veil.add_child(panel)

	var tt := _label("命数 · 可多选（再点一下取消）", 26, INK)
	tt.position = Vector2(0, 14)
	tt.size = Vector2(pw, 34)
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(tt)

	var sub := _label("负面换好处——每张只顶这一趟；多带一张，好处与代价一起背。全不选＝空手走。", 17, Color(INK.r, INK.g, INK.b, 0.60))
	sub.position = Vector2(0, 48)
	sub.size = Vector2(pw, 26)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sub)

	# 可滚动列表：行高自适应（换行撑开），装不下就上下滑
	var scroll = ScrollContainer.new()
	UiKit.drag_scroll(scroll)
	scroll.position = Vector2(20, 80)
	scroll.size = Vector2(pw - 40.0, ph - 80.0 - 78.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(pw - 40.0, 0)
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	for fid_v in FATE_LIST:
		var fid := str(fid_v)
		var picked := _pick_fates.has(fid)
		var row := VBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(INK.r, INK.g, INK.b, 0.10) if picked else Color(0.96, 0.93, 0.86, 1.0)
		rsb.set_corner_radius_all(8)
		rsb.border_color = Color(INK.r, INK.g, INK.b, 0.85) if picked else Color(INK.r, INK.g, INK.b, 0.35)
		rsb.set_border_width_all(3 if picked else 2)
		rsb.set_content_margin_all(8)
		row.add_theme_stylebox_override("panel", rsb)
		row.gui_input.connect(_on_fate_row_input.bind(fid))
		box.add_child(row)
		var nm := _label(("✔ " if picked else "") + Buffs.name_of(fid), 20, INK)
		nm.custom_minimum_size = Vector2(0, 0)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(nm)
		var ln1 := _label(str(FATE_EFFECT.get(fid, "")), 17, UiKit.SEAL)
		ln1.custom_minimum_size = Vector2(0, 0)
		ln1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(ln1)
		var ln2 := _label(_fate_cost_text(fid), 16, Color(INK.r, INK.g, INK.b, 0.72))
		ln2.custom_minimum_size = Vector2(0, 0)
		ln2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(ln2)

	# 底部固定条：已选 N 张 ／ 全部取消 ／ 就这些
	var cnt := _label("", 17, INK)
	cnt.name = "FateCount"
	cnt.position = Vector2(24, ph - 64)
	cnt.size = Vector2(240, 26)
	panel.add_child(cnt)
	_refresh_fate_count()
	var clr := Button.new()
	clr.position = Vector2(pw - 320.0, ph - 68)
	clr.size = Vector2(140, 46)
	clr.text = "全部取消"
	clr.add_theme_font_size_override("font_size", 18)
	clr.focus_mode = Control.FOCUS_NONE
	clr.pressed.connect(_on_fate_clear)
	_style_light_button(clr)
	panel.add_child(clr)
	var ok := Button.new()
	ok.position = Vector2(pw - 166.0, ph - 68)
	ok.size = Vector2(142, 46)
	ok.text = "就这些"
	ok.add_theme_font_size_override("font_size", 18)
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(_on_fate_confirm)
	_style_dark_button(ok)
	panel.add_child(ok)

# 这一张的"代价"那一行（从卡面 desc 里把代价那段拎出来；拎不到就整句）
func _fate_cost_text(fid: String) -> String:
	var d := str(Buffs.desc_of(fid))
	var i := d.find("；")
	if i >= 0 and i + 1 < d.length():
		return d.substr(i + 1)
	return d

func _refresh_fate_count() -> void:
	if _fate_veil == null or not is_instance_valid(_fate_veil):
		return
	var lb := _fate_veil.find_child("FateCount", true, false)
	if lb is Label:
		var names: Array = []
		for f_v in _pick_fates:
			names.append(str(Buffs.name_of(str(f_v))))
		(lb as Label).text = "已选 " + str(_pick_fates.size()) + " 张" + ("：" + "、".join(PackedStringArray(names)) if not names.is_empty() else "（空手走）")

# 点整行＝切换这一张（多选的核心：不清空别的）
func _on_fate_row_input(ev: InputEvent, fid: String) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _pick_fates.has(fid):
		_pick_fates.erase(fid)
	else:
		_pick_fates.append(fid)
	_close_fate_pick()
	_ask_fate_pick()   # 重画（✔ 与边框立刻反映选中状态）

func _on_fate_clear() -> void:
	_pick_fates.clear()
	_close_fate_pick()
	_ask_fate_pick()

func _on_fate_confirm() -> void:
	_close_fate_pick()
	if _pick_fates.is_empty():
		_msg_lb.text = "命数：空手走。"
	else:
		var names: Array = []
		for f_v in _pick_fates:
			names.append(str(Buffs.name_of(str(f_v))))
		_msg_lb.text = "命数已选 " + str(_pick_fates.size()) + " 张：" + "、".join(PackedStringArray(names)) + "（出发后一起生效）"
	_paint()

func _close_fate_pick() -> void:
	if _fate_veil != null and is_instance_valid(_fate_veil):
		_fate_veil.queue_free()
	_fate_veil = null

func _paint_carry() -> void:
	if _carry_lb == null:
		return
	if _pick_roles.is_empty():
		_carry_lb.text = ""
		return
	# ㊿：三个人就各列一行——"出征自动卸下"这件事是按人算的
	var lines: Array = []
	for r_v in _pick_roles:
		lines.append(_carry_line(str(r_v)))
	_carry_lb.text = "\n".join(PackedStringArray(lines))

# ㊿：羁绊一行——本趟生效的羁绊（带效果），一条都没成时提示"还差谁"。
#   v62c（用户："点击谁上阵之后的那个一长串的说明 其实没必要 就告诉玩家在前谁在后谁在中就好了"）：
#     原来这里写"羁绊（本趟生效）：师徒……／同门……／三人同心……"（最多三行，还把上面那排
#     选人钮压掉 10px）。现在只报**阵型**：谁前、谁中、谁后——一行，一眼看完。
func _paint_bonds() -> void:
	if _bond_lb == null:
		return
	var names: Array = []
	for r_v in _pick_roles:
		var rid := str(r_v)
		names.append(str(GameState.role_data(rid).get("name", rid)))
	match names.size():
		0:
			_bond_lb.text = "阵型：还没点人——点上面的弟子，第一个点的站前排"
		1:
			_bond_lb.text = "阵型：前 " + str(names[0]) + "（再点一位就有中·后）"
		2:
			_bond_lb.text = "阵型：前 " + str(names[0]) + "　后 " + str(names[1])
		_:
			_bond_lb.text = "阵型：前 " + str(names[0]) + "　中 " + str(names[1]) + "　后 " + str(names[2])

func _carry_line(rid: String) -> String:
	var rd: Dictionary = GameState.role_data(rid)
	var who := str(rd.get("name", rid))
	var segs: Array = []
	var wsid := str(rd.get("weapon", ""))
	# v62h：兵器随身带走（不卸），其余照卸——这一行就是"本趟随身清单"的预告
	segs.append("兵器（随身）" + ("（空手）" if wsid == "" else str(Cards.item_name(wsid))))
	var sk: Array = rd.get("skills", [])
	var snames: Array = []
	for a_v in sk:
		snames.append(str(Cards.name_of(str(a_v))))
	segs.append("功法 " + str(sk.size()) + "/3 " + ("（空）" if snames.is_empty() else "、".join(PackedStringArray(snames))))
	var gear: Dictionary = rd.get("gear", {})
	var gsegs: Array = []
	for slot_v in ["armor", "helm", "cloak"]:
		var slot := str(slot_v)
		var cn := "护甲"
		if slot == "helm":
			cn = "玉佩"
		elif slot == "cloak":
			cn = "披风"
		var gsid := str(gear.get(slot, ""))
		gsegs.append(cn + " " + ("—" if gsid == "" else str(Cards.item_name(gsid))))
	segs.append("｜".join(PackedStringArray(gsegs)))
	var tail := ""
	var ult: Dictionary = rd.get("ult", {})
	var pas: Dictionary = rd.get("passive", {})
	if not ult.is_empty():
		tail = "大招「" + str(ult.get("name", "")) + "」"
	if not pas.is_empty():
		if tail != "":
			tail += " · "
		tail += "被动「" + str(pas.get("name", "")) + "」"
	# ㊿：这一行原来写得又长又绕，三个人就换到六七行、压住下面几行字。
	#   现在只留必要信息，句尾收成一句短的：三人大约各两行。
	var note := "　（随身不变" + ("：" + tail if tail != "" else "") + "）"
	return who + "｜卸下：" + " · ".join(PackedStringArray(segs)) + note

func _nodes_of(d: int) -> int:
	# ㊿c：正式趟按档——与 data_journey.formal_cycles 同式：轮数＝min(3＋档, 8)，五节一轮，boss 收尾
	# v63（用户："游历得加关卡了"）：2+档 → 3+档：档 1 由 16 节 → 21 节
	return mini(3 + maxi(1, d), 8) * 5 + 1

func _pool_stage_cn() -> String:
	var arr: Array = Cards.QUALITY_ORDER
	var ph: int = clampi(GameState.ladder_phase(), 0, arr.size() - 1)
	return str(arr[ph])

func _on_go() -> void:
	if _pick_roles.is_empty() or _pick_diff <= 0:
		_msg_lb.text = "先挑至少一个人、再挑一条路。"
		return
	_ask_strip_confirm()

func _ask_strip_confirm() -> void:
	if _confirm_veil != null and is_instance_valid(_confirm_veil):
		return
	# ㊿：确认页按"整队"列——带了谁就逐个人说一遍要卸什么
	var body_txt := ""
	if _pick_roles.size() == 1:
		body_txt = _strip_text_for(str(_pick_roles[0]), false)
	else:
		# 把站位说清楚：第 1 个站前排挡刀，后面的躲在他身后。
		#   这是能改命的规则（敌人普攻只打最前排活人），不能藏在代码里。
		#   ㊿：站位现在是"点人时那个框"里选的，所以不再说"按点的先后排"；
		#     名号也跟着人数走（两人趟就是"前/后"，没有"中"）。
		var names: Array = _row_names(_pick_roles.size())
		var who: Array = []
		for r_v in _pick_roles:
			who.append(str(GameState.role_data(str(r_v)).get("name", str(r_v))))
		body_txt = "本趟同行 " + str(_pick_roles.size()) + " 人　站位：" + str(names[0]) + " " + str(who[0]) + "（先挨打）"
		for oi in range(1, who.size()):
			body_txt += " · " + str(names[oi]) + " " + str(who[oi])
		body_txt += "\n（换排：上一页点那个人重挑）\n\n"
		# ⚠ 站位名要先落到 Array 局部变量再 str() 取——直接写 ("前","中","后")[i3]
		#   在 GDScript 里是 Variant，喂给 String 形参会吃警告（这个坑项目里踩过）
		for i3 in _pick_roles.size():
			body_txt += _strip_text_for(str(_pick_roles[i3]), true, str(names[i3])) + "\n"
	if not _pick_fates.is_empty():
		var flines: Array = []
		for f_v in _pick_fates:
			flines.append(str(Buffs.name_of(str(f_v))) + "——" + str(FATE_EFFECT.get(str(f_v), "")))
		body_txt += "\n命数（" + str(_pick_fates.size()) + " 张）：" + "；".join(PackedStringArray(flines)) + "（本趟）"

	var vp := get_viewport_rect().size
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.42)
	veil.size = vp
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	_confirm_veil = veil
	var pw := 560.0
	var ph := 400.0
	var panel := Panel.new()
	panel.position = Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.99)
	psb.set_corner_radius_all(14)
	psb.border_color = Color(0.32, 0.27, 0.22, 0.55)
	psb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", psb)
	veil.add_child(panel)

	var tt := _label("出征前整装（兵器随身）", 28, INK)
	tt.position = Vector2(0, 18)
	tt.size = Vector2(pw, 40)
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(tt)

	var bd := _label(body_txt, 15, Color(INK.r, INK.g, INK.b, 0.88))
	bd.position = Vector2(34, 72)
	bd.size = Vector2(pw - 68.0, 250)
	bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(bd)

	var go := Button.new()
	go.text = "确认出征"
	go.position = Vector2(56, ph - 76.0)
	go.size = Vector2(200, 56)
	go.add_theme_font_size_override("font_size", 20)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(_do_depart)
	_style_dark_button(go)
	panel.add_child(go)

	var back := Button.new()
	back.text = "再想想"
	back.position = Vector2(pw - 256.0, ph - 76.0)
	back.size = Vector2(200, 56)
	back.add_theme_font_size_override("font_size", 20)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_close_strip_confirm)
	_style_light_button(back)
	panel.add_child(back)

func _close_strip_confirm() -> void:
	if _confirm_veil != null and is_instance_valid(_confirm_veil):
		_confirm_veil.queue_free()
	_confirm_veil = null

# ㊿：某个人的"出征前要卸下什么"。compact=true 时压成一行（多人同行时用）；
#   row_cn 给了就在前面缀上站位（前/中/后）。
#   v62h（用户："游历允许每个角色允许装备武器"）：**兵器随身带走、不卸**——
#     所以这里它从"要卸的清单"变成"随身清单"的第一行（仍列出来，让玩家看清带了什么）。
func _strip_text_for(rid: String, compact: bool, row_cn := "") -> String:
	var rd: Dictionary = GameState.role_data(rid)
	var rname := str(rd.get("name", rid))
	var lines: Array = []
	var wsid := str(rd.get("weapon", ""))
	if wsid != "":
		# v62h（用户："游历允许每个角色允许装备武器"）：兵器**不卸**，随身带走。
		lines.append("兵器（随身）：" + str(Cards.item_name(wsid)))
	var gear: Dictionary = rd.get("gear", {})
	var gsegs: Array = []
	for slot_v in ["armor", "helm", "cloak"]:
		var slot := str(slot_v)
		var cn := "护甲"
		if slot == "helm":
			cn = "玉佩"
		elif slot == "cloak":
			cn = "披风"
		var gsid := str(gear.get(slot, ""))
		if gsid != "":
			gsegs.append(cn + "：" + str(Cards.item_name(gsid)))
	if not gsegs.is_empty():
		lines.append("装备：" + " · ".join(PackedStringArray(gsegs)))
	var sk: Array = rd.get("skills", [])
	if not sk.is_empty():
		var sn: Array = []
		for a_v in sk:
			sn.append(str(Cards.name_of(str(a_v))))
		lines.append("功法：" + "、".join(PackedStringArray(sn)))
	if compact:
		var pre := ""
		if row_cn != "":
			pre = row_cn + "　"
		if lines.is_empty():
			return "· " + pre + rname + "：随身空着，赤手上路"
		return "· " + pre + rname + "：" + "｜".join(PackedStringArray(lines))
	if lines.is_empty():
		lines.append("　（随身没有可卸的——本来就空着）")
	else:
		for i in lines.size():
			lines[i] = "　" + str(lines[i])
	return rname + " 出征前将自动卸下随身之物（全部放回村仓库）：\n" + "\n".join(PackedStringArray(lines)) + "\n\n本趟从零开始：赤手空拳上路，兵器、装备与功法靠沿途再捡。\n（收工回村时会照这一份原样穿回去——殒命/中途退出也一样穿回，只有这趟捡的东西带不带得回另说）"

func _auto_unequip(rid: String) -> Array:
	var out: Array = []
	# v62h（用户："游历允许每个角色允许装备武器"）：**兵器不再卸下**——
	#   它跟人走进游历（出发屏那一行的文案也改成了"兵器（随身）"）。
	#   护甲/玉佩/披风/功法照旧全部卸回村仓库。
	for slot_v in ["armor", "helm", "cloak"]:
		var g := GameState.unequip_gear(rid, str(slot_v))
		if g.begins_with("已卸下"):
			out.append(g)
	var rd: Dictionary = GameState.role_data(rid)
	var sk: Array = (rd.get("skills", []) as Array).duplicate()
	for i in range(sk.size() - 1, -1, -1):
		var a := GameState.unequip_art(rid, i)
		if a.begins_with("已卸下"):
			out.append(a)
	return out

func _do_depart() -> void:
	# ㊿：整队出发——每个人都自动卸装，然后把名单整车交给游历
	var rids: Array = _pick_roles.duplicate()
	if rids.is_empty():
		return
	# ㊿v：上一趟欠着的"穿回去"先补上——不然这次记下的就是一副空身，
	#   上一趟的随身之物会永远留在仓库里（就是"每次历练完出来总得重新穿"）
	var owed := GameState.strip_restore()
	if owed != "":
		print("[出征] 先补上一趟的随身：", owed)
	# ㊿v：**卸之前**把每个人的随身记一份——回来照这个穿回去
	GameState.strip_remember(_strip_snapshot(rids))
	for r_v in rids:
		var got := _auto_unequip(str(r_v))
		if not got.is_empty():
			print("[出征] 自动卸下：", got)
	_close_strip_confirm()
	# ㊿：把**整车**交给出征交接——游历那边是从 deploy_take() 取名单的（信号只负责切场景）。
	#   deploy_set 内部会把第一个记成领队（存档的 role_id 也记他）。
	GameState.deploy_set(rids, _pick_diff, _pick_fates)   # v62r：命数**整批**交出去（多选）
	print("[出征] 出发：队伍=", rids, " 难度=", _pick_diff, " 命数=", _pick_fates, "（已自动卸装，本趟从零开始；临时扩仓 ", GameState.run_expand_slots(), " 格随行）")
	deploy_started.emit(rids, _pick_diff)
	close()

# ㊿v：出征前记一份随身清单（卸装之前调）——回村时按它穿回去
func _strip_snapshot(rids: Array) -> Dictionary:
	var out: Dictionary = {}
	for r_v in rids:
		var rid := str(r_v)
		var rd: Dictionary = GameState.role_data(rid)
		if rd.is_empty():
			continue
		out[rid] = {
			"weapon": str(rd.get("weapon", "")),
			"gear": (rd.get("gear", {}) as Dictionary).duplicate(),
			"skills": (rd.get("skills", []) as Array).duplicate(),
		}
	return out

func open() -> void:
	_msg_lb.text = ""
	_pick_roles.clear()
	_pick_diff = 0
	_pick_fates.clear()            # ㉛：每次开屏从"空手走"起
	_close_strip_confirm()
	_close_fate_pick()
	_refresh()
	visible = true

func close() -> void:
	if not visible:
		return
	_close_strip_confirm()
	_close_fate_pick()
	visible = false
	closed.emit()

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
	if event is InputEventKey:
		var ke := event as InputEventKey
		# 【测试用·上线前删】F9：一键把前 4 档标记走通（第 5 档立开；命数随之解锁）
		if ke.pressed and not ke.echo and ke.keycode == KEY_F9:
			get_viewport().set_input_as_handled()
			_msg_lb.text = GameState.debug_clear_diffs(4)
			print("[出征] ", _msg_lb.text)
			_refresh()
			return
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _fate_veil != null:
				_close_fate_pick()
				return
			if _confirm_veil != null:
				_close_strip_confirm()
				return
			close()
