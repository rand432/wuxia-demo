extends RefCounted
# ============================================================
# journey_char_panel.gd —— 角色面板件 v8（㉗：大招也能展开）
# v8（㉗）：大招一行加［展开］——看名字/怎么放/效果全句。
# v7（优化批㉓）：外面只给字 · 详情进展开
# v7 改版（按需求）：
#   ①外面纯文本——属性/天赋/兵器/装备/大招/功法只显示"名字＋关键状态"，不铺效果文；
#     字号放大，看着清楚；
#   ②天赋 / 兵器 / 装备 / 功法 各配一个［展开］：展开里看详情、点条目看效果；
#     装备与功法的"卸下"移进展开（外面不再放卸下钮）；
#   ③按住说明改"新手一句话"（攻击指什么、天赋指什么、装备几格），面板缩小；
#     具体效果一律去［展开］里点着看。
# 接口不变：_build_char_panel / _set_char_panel / _refresh_stats_ui / set_btn_visible /
#   set_talent_visible / bring_btn_front / _press_tip_hide。
# 不引 journey_stage（防循环——老铁律）。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const RunState := preload("res://shared/run_state.gd")
const GameState := preload("res://shared/game_state.gd")
const Elem := preload("res://shared/data_elem.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const Voice := preload("res://shared/voice.gd")   # v87：点开角色面板念一句台词
const CharArt := preload("res://shared/char_art.gd")     # 立绘/头像/Q版取图口
const ArtView := preload("res://shared/art_view.gd")     # 会动的立绘（程序化）
const ArtClip := preload("res://shared/art_clip.gd")     # 立绘演出（看片版，.ogv）

const WEAPON_CN := {"sword": "长剑", "dual": "双刀", "dagger": "匕首", "spear": "长枪", "anqi": "暗器", "fist": "拳法"}
const GEAR_CN := {"armor": "护甲", "helm": "玉佩", "cloak": "披风"}
const GEAR_SLOTS := ["armor", "helm", "cloak"]

# 与弟子面板 STAT_ROWS 同序同口径
const STAT_ROWS := [
	{"k": "atk", "label": "攻击"},
	{"k": "hp", "label": "气血"},
	{"k": "spd", "label": "速度"},
	{"k": "crit", "label": "暴击", "pct": true},
	{"k": "dmg", "label": "伤害加成", "pct": true},
	{"k": "def", "label": "防御"},
	{"k": "dodge", "label": "闪避"},   # v35：闪避是**数值**（不是百分比）——别再加 %
	{"k": "crit_dmg", "label": "暴击伤害", "pct": true},
]

# v60（用户："游历同理——目前游历没有元素属性显示"）：五行那一组（物理/五行增伤 ＋ 五行抗性）。
#   与弟子面板 STAT_ROWS 的后 11 条同序同名；正面摆不下，全部进［详细属性］那一页。
#   数值来自 RunState.stats_of（v60 起也累这一组了，游历与村里同一个口径）。
const ELEM_ROWS := [
	{"k": "phys_dmg", "label": "物理伤害增加"},
	{"k": "metal_dmg", "label": "金元素伤害增加"},
	{"k": "water_dmg", "label": "水元素伤害增加"},
	{"k": "wood_dmg", "label": "木元素伤害增加"},
	{"k": "fire_dmg", "label": "火元素伤害增加"},
	{"k": "earth_dmg", "label": "土元素伤害增加"},
	{"k": "metal_res", "label": "金元素抗性"},
	{"k": "water_res", "label": "水元素抗性"},
	{"k": "wood_res", "label": "木元素抗性"},
	{"k": "fire_res", "label": "火元素抗性"},
	{"k": "earth_res", "label": "土元素抗性"},
]

# v7：按住只给"新手一句话"（详情去［展开］）
const STAT_TIPS := {
	"atk": "攻击力 ＝ 基础攻击 ＋ 额外攻击。\n基础＝人物自己的底子；额外＝随身兵器 ＋ 装备 ＋ 功法。\n这一格显示的是两者相加后的总数（出手伤害 = 攻击 × 招式倍率）。\n村里面板点「攻击」那一格能看到详细拆账。",
	"hp": "气血＝挨打扣的那条命。\n每过一节回一点，歇脚处全复。",
	"spd": "速度＝谁先出手。\n遭遇战的「敌先手」是场面设定，不按这个。",
	"crit": "暴击＝这一下打得更重的几率。",
	"dmg": "伤害加成＝所有出手再放大的百分比。",
	"def": "防御（数值）：与对手的攻击值对拼——挡掉的比例 ＝ 防御 ÷（对手攻击 ＋ 你防御）。",
	"dodge": "闪避（数值）：与对手的命中对拼——命中 ＝ 100 ＋ 对手速度×2；闪开了这一手整个作废。",
	"crit_dmg": "暴击时的加成：暴击打出（1 + 这个数/100）倍伤害（默认 50 = 1.5 倍）。",
}

var _host = null
var _state = null

var _char_btn: Button
var _pick_btns: Array = []      # ㊿：三人成队——"看谁"的切换钮（单人趟自动隐藏）
var _stats_panel: Panel
var _stat_val_lbs: Array = []
var _stat_btn: Button = null   # v60b：［详细属性 ▸］
var _art_btn: Button = null    # v64：［立绘 ▸］

var _talent_zone: Panel = null
var _talent_expand_btn: Button = null
var _talent_l1: Label = null
var _talent_l2: Label = null
var _talent_l3: Label = null

var _weapon_row: Label = null
var _gear_rows: Array = []
var _ult_val: Label = null
var _art_title: Label = null
var _art_rows: Array = []

var _ov: Control = null
var _ov_kind := ""
var _ov_sel := 0

var _press_tip_on := false
var _press_tip_panel: Panel = null
var _press_tip_title: Label = null
var _press_tip_text: Label = null


func setup(host) -> void:
	_host = host
	_state = host._state


# ㊿：切"看谁"——面板上所有数字/装备/功法都跟着走（RunState.active_i）
func _on_pick_member(i: int) -> void:
	if _state == null or i >= _state.member_count():
		return
	_state.use_member(i)
	_refresh_stats_ui()
	_refresh_pick_btns()

func _refresh_pick_btns() -> void:
	if _pick_btns.is_empty():
		return
	var n := 1
	if _state != null:
		n = _state.member_count()
	# 钮是面板的子节点，显隐跟着面板走——这里只管"人数够不够"
	for i in _pick_btns.size():
		var b: Button = _pick_btns[i]
		b.visible = i < n and n > 1
		if not b.visible:
			continue
		var m: Dictionary = _state.member_at(i)
		var nm := str(GameState.role_data(str(m.get("role_id", ""))).get("name", "?"))
		var cur := int(m.get("hp", 0))
		var mx := maxi(1, int(m.get("hp_max", 1)))
		# ㊿：钮大了，正文也跟着加一点——带上"前/中/后"站位（正在看的那颗是 disabled 态，
		#   本来就看得出，所以不再加符号，免得字挤出去）
		var row_cn := "前" if i == 0 else ("中" if i == 1 else "后")
		# v64：钮上带**头像**（人一多，光靠名字认不快）。字缩短成"名 血/血"，
		#   让出图标那 30px——134 宽的钮才装得下（带"前/中/后"会挤爆）。
		# v65（用户："现有立绘去掉，就做几个临时 Q版的"）：头像位改用**Q版裁头**顶，
		#   半写实那套 face/full 先不进游戏（文件还在 assets/char，随时能切回来）。
		var face := CharArt.q_head(str(m.get("role_id", "")))
		if face != null:
			b.icon = face
			# ⚠ 千万不要开 expand_icon：那会让图标"撑满按钮"，26 的上限就白设了
			b.expand_icon = false
			# 图标 20（不是 26）：134 宽的钮要同时装下"图标 + 少侠 100/100"；
			#   ⚠ 字号千万别往下调——设计分辨率 720 到手机/PC 窗口还要再缩一次，
			#   13 号字实际只有 8px，糊成一团（试过了）。
			b.add_theme_constant_override("icon_max_width", 20)
			b.add_theme_constant_override("h_separation", 4)
		b.text = nm + " " + str(cur) + "/" + str(mx)
		b.disabled = (i == _state.active_i)
		b.modulate = Color.WHITE if cur > 0 else Color(0.7, 0.7, 0.7, 0.75)

func _build_char_panel() -> void:
	_char_btn = UiKit.make_button(_host, Vector2(20, 60), Vector2(160, 56), "收起角色", 19)
	_char_btn.pressed.connect(_toggle_char_panel)

	_stats_panel = Panel.new()
	_stats_panel.position = Vector2(20, 124)
	_stats_panel.size = Vector2(640, 896)
	_stats_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_stats_panel.add_theme_stylebox_override("panel", UiKit.paper_box(0.93))
	_host.add_child(_stats_panel)

	# ---- 属性（两列，只给数） ----
	# v60（用户："游历同理——目前游历没有元素属性显示"）：正面只摆老 8 条，
	#   五行那一组（物理/五行增伤 ＋ 五行抗性）全部进［详细属性］那一页。
	# v60b（用户："游历里我没看到详细属性的按钮"）：原来是把"属性"标题做成可点的，
	#   太隐蔽——现在**摆一颗真按钮**（左起 86 宽 130，右缘 216 不撞右上角的切换钮）。
	_head(_stats_panel, "属性", Vector2(20, 8))
	_stat_btn = UiKit.make_button(_stats_panel, Vector2(86, 4), Vector2(130, 38), "详细属性 ▸", 17)
	_stat_btn.pressed.connect(_show_ov.bind("stats"))
	_stat_val_lbs.clear()
	for i in STAT_ROWS.size():
		var row: Dictionary = STAT_ROWS[i]
		var col := 0 if i < 4 else 1
		var r := i % 4
		var x := 20.0 + float(col) * 302.0
		var y := 42.0 + float(r) * 32.0
		var lb := UiKit.make_label(_stats_panel, Vector2(x, y + 2.0), Vector2(84, 26), 17, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.55))
		UiKit.set_text(lb, str(row.get("label", "")))
		var vl := UiKit.make_label(_stats_panel, Vector2(x + 88.0, y), Vector2(190, 30), 22, UiKit.INK)
		UiKit.set_text(vl, "—")
		_stat_val_lbs.append(vl)

	# ㊿：三人成队——面板右上角三个钮切换"看谁"。
	#   放在面板**里面**有两个好处：①跟着面板一起显隐，不用自己管；
	#   ②不会撞上舞台顶上的气血条/警惕条（178~406, 66~108 那一带被它们占着）。
	#   只带一个人时藏起来（老单人趟界面一点没变）。
	#   ㊿：**贴手机改大**——原来是 92×32、14 号字，手指根本点不准。
	#     面板顶那条空带（y 0~42）从 x≈220 往右都是空的（左边只有"属性"小标题），
	#     所以把三颗铺开成 134×40、15 号字（面积差不多翻倍），正好塞到面板右缘。
	_pick_btns.clear()
	for i in 3:
		var b := UiKit.make_button(_stats_panel, Vector2(222.0 + float(i) * 140.0, 2.0), Vector2(134, 40), "—", 15)
		b.focus_mode = Control.FOCUS_NONE
		b.visible = false
		b.pressed.connect(_on_pick_member.bind(i))
		_pick_btns.append(b)

	# v64：［立绘 ▸］——人物立绘/头像这一页的入口。
	#   为什么摆在这条带（y180 那一行）：面板上真的没有别处了——顶带 222~636 被三颗"看谁"钮占满，
	#   下面每一段（属性/天赋/兵器/装备/大招/功法）都排到 876 了。这一行左边只有"天赋"两个字、
	#   右边 x504 才是［展开］，300~500 这段是空的，塞一颗 116×34 正好，也不挡指头。
	_art_btn = UiKit.make_button(_stats_panel, Vector2(376, 180), Vector2(116, 34), "人物 ▸", 17)
	_art_btn.pressed.connect(_show_ov.bind("art"))

	# ---- 天赋（外面只给名字；全文进展开） ----
	_head(_stats_panel, "天赋", Vector2(20, 178))
	_talent_expand_btn = _mk_expand(504.0, 180.0)
	_talent_expand_btn.pressed.connect(_show_ov.bind("talents"))
	_talent_zone = Panel.new()
	_talent_zone.position = Vector2(20, 216)
	_talent_zone.size = Vector2(600, 108)
	_talent_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_talent_zone.add_theme_stylebox_override("panel", _soft_sb())
	_stats_panel.add_child(_talent_zone)
	_talent_l1 = UiKit.make_label(_talent_zone, Vector2(14, 6), Vector2(572, 30), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	_talent_l1.max_lines_visible = 1
	_talent_l1.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_talent_l2 = UiKit.make_label(_talent_zone, Vector2(14, 38), Vector2(572, 30), 18, UiKit.INK)
	_talent_l2.max_lines_visible = 1
	_talent_l2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_talent_l3 = UiKit.make_label(_talent_zone, Vector2(14, 70), Vector2(572, 32), 19, UiKit.SEAL)
	_talent_l3.max_lines_visible = 1
	_talent_l3.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	# ---- 兵器（一行字；详情进展开） ----
	_head(_stats_panel, "兵器", Vector2(20, 334))
	_mk_expand(504.0, 336.0).pressed.connect(_show_ov.bind("weapon"))
	var wcell := Panel.new()
	wcell.position = Vector2(20, 372)
	wcell.size = Vector2(600, 50)
	wcell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wcell.add_theme_stylebox_override("panel", _soft_sb())
	_stats_panel.add_child(wcell)
	_weapon_row = UiKit.make_label(wcell, Vector2(14, 9), Vector2(572, 32), 21, UiKit.SEAL)
	_weapon_row.max_lines_visible = 1
	_weapon_row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiKit.set_text(_weapon_row, "兵器：—")

	# ---- 装备（三行字；详情与卸下进展开） ----
	_head(_stats_panel, "装备（护甲 · 玉佩 · 披风）", Vector2(20, 432))
	_mk_expand(504.0, 434.0).pressed.connect(_show_ov.bind("gear"))
	_gear_rows.clear()
	for i in GEAR_SLOTS.size():
		var slot := str(GEAR_SLOTS[i])
		var ry := 470.0 + float(i) * 42.0
		var rcell := Panel.new()
		rcell.position = Vector2(20, ry)
		rcell.size = Vector2(600, 38)
		rcell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rcell.add_theme_stylebox_override("panel", _soft_sb())
		_stats_panel.add_child(rcell)
		var lb := UiKit.make_label(rcell, Vector2(14, 6), Vector2(572, 26), 19, UiKit.DIM)
		lb.max_lines_visible = 1
		lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		UiKit.set_text(lb, str(GEAR_CN.get(slot, slot)) + "：—")
		_gear_rows.append(lb)

	# ---- 大招（一行字） ----
	var ucell := Panel.new()
	ucell.position = Vector2(20, 602)
	ucell.size = Vector2(600, 52)
	ucell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ucell.add_theme_stylebox_override("panel", _soft_sb())
	_stats_panel.add_child(ucell)
	var uhead := UiKit.make_label(ucell, Vector2(14, 4), Vector2(572, 20), 15, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.55))
	UiKit.set_text(uhead, "大招（怒气满自动放）")
	_ult_val = UiKit.make_label(ucell, Vector2(14, 24), Vector2(430, 26), 20, UiKit.SEAL)
	_ult_val.max_lines_visible = 1
	_ult_val.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiKit.set_text(_ult_val, "—")
	_mk_expand(504.0, 610.0).pressed.connect(_show_ov.bind("ult"))

	# ---- 功法（三行字；详情与卸下进展开） ----
	_art_title = _head(_stats_panel, "功法 0/" + str(RunState.ART_SLOTS), Vector2(20, 664))
	_mk_expand(504.0, 666.0).pressed.connect(_show_ov.bind("arts"))
	_art_rows.clear()
	for i in RunState.ART_SLOTS:
		var y2 := 702.0 + float(i) * 60.0
		var cell := Panel.new()
		cell.position = Vector2(20, y2)
		cell.size = Vector2(600, 54)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_stylebox_override("panel", _soft_sb())
		_stats_panel.add_child(cell)
		var vl2 := UiKit.make_label(cell, Vector2(14, 12), Vector2(572, 30), 19, UiKit.DIM)
		vl2.max_lines_visible = 1
		vl2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		UiKit.set_text(vl2, "功法 " + str(i + 1) + "：（空）")
		_art_rows.append(vl2)


func _mk_expand(px: float, py: float) -> Button:
	return UiKit.make_button(_stats_panel, Vector2(px, py), Vector2(116, 34), "展开", 17)


func _head(parent: Control, text: String, pos: Vector2) -> Label:
	var lb := UiKit.make_label(parent, pos, Vector2(600, 32), 24, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.70))
	UiKit.set_text(lb, text)
	return lb


func _soft_sb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.35)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.22)
	sb.set_border_width_all(1)
	return sb


func _toggle_char_panel() -> void:
	_set_char_panel(not _stats_panel.visible)


func _set_char_panel(on: bool) -> void:
	if _stats_panel == null:
		return
	_stats_panel.visible = on
	if _char_btn != null:
		UiKit.set_btn_text(_char_btn, "收起角色" if on else "展开角色")
	if on:
		_stats_panel.move_to_front()
	else:
		_hide_ov()
		_press_tip_hide()
	_refresh_pick_btns()   # ㊿：收起时连切换钮一起藏


func _refresh_stats_ui() -> void:
	if _stats_panel == null or _state == null:
		return
	_press_tip_attach()
	_refresh_pick_btns()   # ㊿：切换钮上的名字/血量跟着刷新
	var rid := str(_state.role_id)
	var st: Dictionary = _state.stats()
	for i in STAT_ROWS.size():
		var row: Dictionary = STAT_ROWS[i]
		var vl: Label = _stat_val_lbs[i]
		var v := int(round(float(st.get(str(row.get("k", "")), 0))))
		var s := str(v)
		if bool(row.get("pct", false)):
			s += "%"
		UiKit.set_text(vl, s)

	# 兵器：换装的优先；没换装＝出发随身那把——只给名字
	var wid := str(_state.weapon_id())
	if wid != "":
		var wn := str(Cards.item_name(wid))
		if wn == "":
			wn = "未识别·" + wid
		var tail := "" if _state.equipped_item != "" else "（随身）"
		UiKit.set_text(_weapon_row, "兵器：" + wn + GameState.star_marks(wid) + tail)
	else:
		UiKit.set_text(_weapon_row, "兵器：空手（拳法）")

	# 装备三行——只给名字
	for i in GEAR_SLOTS.size():
		var slot := str(GEAR_SLOTS[i])
		var gsid := str(_state.gear_of(slot))
		var lb: Label = _gear_rows[i]
		var cn := str(GEAR_CN.get(slot, slot))
		if gsid == "":
			UiKit.set_text(lb, cn + "：—")
			lb.add_theme_color_override("font_color", UiKit.DIM)
		else:
			UiKit.set_text(lb, cn + "：" + str(Cards.item_name(gsid)) + GameState.star_marks(gsid))
			lb.add_theme_color_override("font_color", UiKit.INK)

	# 大招——只给名字
	var rd: Dictionary = GameState.role_data(rid)
	var ud: Dictionary = rd.get("ult", {})
	UiKit.set_text(_ult_val, "大招：「" + str(ud.get("name", "—")) + "」")

	# 功法——名字＋状态（就绪/冷却）
	UiKit.set_text(_art_title, "功法 " + str(_state.arts.size()) + "/" + str(RunState.ART_SLOTS))
	for i in RunState.ART_SLOTS:
		var al: Label = _art_rows[i]
		if i < _state.arts.size():
			var sid := str(_state.arts[i])
			var cd := int(_state.art_cd.get(sid, 0))
			var nm := str(Cards.name_of(sid))
			if Cards.by_id(sid).is_empty():
				nm = "未识别·" + sid
			var stt := " · 就绪" if cd <= 0 else " · 冷却" + str(cd)
			UiKit.set_text(al, "功法 " + str(i + 1) + "：" + nm + GameState.star_marks(sid) + stt)
			al.add_theme_color_override("font_color", UiKit.SEAL if cd <= 0 else UiKit.DIM)
		else:
			UiKit.set_text(al, "功法 " + str(i + 1) + "：（空）")
			al.add_theme_color_override("font_color", UiKit.DIM)

	# 天赋三行——只给名字（五问的括号说明剥掉；被动也只要名字）
	var s_inn := ""
	var iname := str(_state.innate_name())
	if iname != "":
		s_inn = "自带：" + iname
	if _state.talents.is_empty():
		UiKit.set_text(_talent_l2, "天赋：无（五问所定）")
	else:
		var tnames: Array = []
		for t_v in _state.talents:
			tnames.append(str(t_v).split("（")[0].strip_edges())
		UiKit.set_text(_talent_l2, "天赋：" + "、".join(PackedStringArray(tnames)))
	var pd: Dictionary = rd.get("passive", {})
	var s_pas := ""
	if not pd.is_empty():
		s_pas = "被动：" + str(pd.get("name", ""))
	UiKit.set_text(_talent_l1, s_inn)
	_talent_l1.visible = s_inn != ""
	UiKit.set_text(_talent_l3, s_pas)
	_talent_l3.visible = s_pas != ""
	_host._apply_player_look()


# ============================================================
# 展开（v7）：天赋 / 兵器 / 装备 / 功法——看详情、点条目、卸下
# ============================================================

func _show_ov(kind: String) -> void:
	_hide_ov()
	_press_tip_hide()
	if _state == null:
		return
	_ov_kind = kind
	var ov := Control.new()
	ov.position = Vector2.ZERO
	ov.size = _host.size
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	_host.add_child(ov)
	ov.move_to_front()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.40)
	dim.size = _host.size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_ov_blank)
	ov.add_child(dim)
	# v62w：纸面 880 → **980**（上移一点，140 → 100）——详细属性那一页现在 ≈ 27 行，
	#   原来的 880 高装不下（底部的"收起"也会被内容压住）。屏高 1280，100+980=1080 稳。
	var panel := UiKit.make_paper_panel(ov, Rect2(20, 100, 680, 980))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var titles := {"stats": "详细属性 · 全览", "talents": "天赋 · 全览", "weapon": "兵器 · 详情", "gear": "装备 · 详情", "arts": "功法 · 详情", "ult": "大招 · 详情", "art": "人物 · Q版（临时）"}
	var tt := UiKit.make_label(panel, Vector2(0, 24), Vector2(680, 48), 32, UiKit.INK)
	UiKit.set_text(tt, str(titles.get(kind, "详情")))
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ov_fill(panel, kind)
	var cb := UiKit.make_button(panel, Vector2(250, 898), Vector2(180, 62), "收起", 24)
	cb.pressed.connect(_hide_ov)
	_ov = ov


# v64：人物演出——全屏播 <角色>_clip.ogv（智谱 CogVideoX 出的 5 秒片，见 tools/gen_video_zhipu.mjs）
func _play_clip(rid: String) -> void:
	var stream := CharArt.clip(rid)
	if stream == null:
		return
	var cv = ArtClip.new()
	_host.add_child(cv)
	cv.play(stream, _host.size)


func _hide_ov() -> void:
	if _ov != null and is_instance_valid(_ov):
		_ov.queue_free()
	_ov = null


func _ov_rebuild() -> void:
	if _ov == null:
		return
	var k := _ov_kind
	_hide_ov()
	_show_ov(k)


func _on_ov_blank(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_hide_ov()


# v60b：详细属性全览——老 8 条 ＋ 物理/五行增伤 ＋ 五行抗性（数值＝RunState.stats_of）
#   游历这一趟"随身三样 ＋ 包里残卡"都算在里面（v60 起五行那一组也算了）。
func _ov_stats(panel: Control) -> void:
	var st: Dictionary = _state.stats()
	var lines: Array = []
	lines.append("【常用】")
	# v62w（用户："详细属性还是字数超过了框"）：
	#   ⚠ 这里原来是 `for i in STAT_ROWS.size()`——把 **19 条全列了** ✗（下面是另外 11 条
	#     五行/增伤），一页 38 行塞进 664 高的框、字号 20 又没有自动换行 → 必然溢出 ✗✗。
	#   改成与弟子面板同一口径：正面只列**前 8 条**（见 character_panel 的同款注释）。
	for i in mini(STAT_ROWS.size(), 8):
		var row: Dictionary = STAT_ROWS[i]
		var k := str(row.get("k", ""))
		var s := str(int(round(float(st.get(k, 0)))))
		if bool(row.get("pct", false)):
			s += "%"
		lines.append("　" + str(row.get("label", "")) + "：" + s)
	lines.append("")
	lines.append("【物理 / 元素增伤（%）——出手时按这个加】")
	for r2_v in ELEM_ROWS:
		var r2: Dictionary = r2_v
		var k2 := str(r2.get("k", ""))
		if not k2.ends_with("_dmg"):
			continue
		lines.append("　" + str(r2.get("label", "")) + "：" + str(int(round(float(st.get(k2, 0))))) + "%")
	lines.append("")
	lines.append("【五行抗性（%）——挨打时按这个减伤，可正可负】")
	for r3_v in ELEM_ROWS:
		var r3: Dictionary = r3_v
		var k3 := str(r3.get("k", ""))
		if not k3.ends_with("_res"):
			continue
		lines.append("　" + str(r3.get("label", "")) + "：" + str(int(round(float(st.get(k3, 0))))) + "%")
	lines.append("")
	lines.append("通道：**物理**吃防御、可以暴击；**元素**不吃防御、不可暴击（基础倍率 ×"
		+ str(snappedf(Elem.ELEM_BASE, 0.01)) + "），改看对手的对应抗性。")
	lines.append("手里那把的元素看［兵器］那一页；抗性上下限 +"
		+ str(int(Elem.RES_CAP * 100.0)) + "% / " + str(int(Elem.RES_FLOOR * 100.0)) + "%。")
	# v62w：字号 20 → **17**、框加高到 800、并**开自动换行**——三件一起才治得住溢出
	#   （原来那两行长句"通道：…／手里那把的元素…"没有换行，会直接画出纸面 ✗）
	var lb := UiKit.make_label(panel, Vector2(40, 104), Vector2(600, 800), 17, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiKit.set_text(lb, "\n".join(PackedStringArray(lines)))


# v64：人物 · 立绘页——左边头像＋名号，右边会动的全身立绘。
#   图来自 assets/char/<角色id>_{face,full}.png（tools/promote_char_art.mjs 提升过来的正式资源）；
#   缺图不崩：缺哪张就少画哪张，名字照常显示。
func _ov_art(panel: Control) -> void:
	var rid := str(_state.role_id)
	# v87（用户：「陈石是那种憨憨的壮壮的感觉」）：**点开角色面板就念一句他的招牌台词**——
	#   剧情对话还没接上，先给个能听见人的入口。没录音的自动跳过（Voice 内部静默）。
	#   说话人前缀：player / chen_shi → chenshi / qingluan
	var spk := rid
	if rid == "chen_shi":
		spk = "chenshi"
	Voice.say_file(spk + "_01")
	var info: Dictionary = GameState.role_data(rid)
	var face := CharArt.q_head(rid)
	if face != null:
		var fr := TextureRect.new()
		# ⚠ 顺序要紧：expand_mode 必须**先**设。默认的 EXPAND_KEEP_SIZE 会把控件最小尺寸
		#   顶成贴图原尺寸（407×460），先设 size 再改 expand_mode，size 已经被顶回去了 ✗
		fr.texture = face
		fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fr.position = Vector2(40, 118)
		fr.size = Vector2(260, 276)
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(fr)
	# v82（用户："角色面板记得也加头像"）：名字**左边挂一张胸像**（水墨 LoRA 出的那三张）。
	#   取不到就退回首字（不再画框），面板照旧能用。
	var fav := TextureRect.new()
	fav.texture = CharArt.face(rid)
	if fav.texture != null:
		fav.position = Vector2(52, 396)
		fav.size = Vector2(56, 56)
		fav.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fav.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fav.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(fav)
	var nm := UiKit.make_label(panel, Vector2(40 if fav.texture == null else 116, 402), Vector2(200, 44), 30, UiKit.INK)
	UiKit.set_text(nm, str(info.get("name", rid)))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UiKit.make_label(panel, Vector2(40, 450), Vector2(260, 30), 17, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.6))
	UiKit.set_text(sub, str(info.get("sub", "")))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var st: Dictionary = _state.stats()
	var rows := ["气血 " + str(int(st.get("hp", 0))), "攻击 " + str(int(st.get("atk", 0))),
		"速度 " + str(int(st.get("spd", 0))), "防御 " + str(int(st.get("def", 0)))]
	# v80（用户："舍装签，攻击暴击好像都没生效，角色面板都没显示"）：
	#   **加成本身是生效的**（buff_fx → fx_buff → 引擎读 atk_pct/crit_pct，链路查过没断），
	#   但 stats_of() 故意不含卡组 fx（见 run_state 的注释：那些在战斗里才折算），
	#   于是面板上一片空白，玩家自然以为没生效。这里把"命数/运签的即时加成"单列一行。
	var bfx: Dictionary = _state.buff_fx(rid)
	var bp: Array = []
	var _pct := func(k: String, label: String) -> void:
		var v := float(bfx.get(k, 0.0))
		if absf(v) > 0.001:
			bp.append(label + " " + ("+" if v > 0.0 else "") + str(int(round(v * 100.0))) + "%")
	_pct.call("atk_pct", "攻击")
	_pct.call("crit_pct", "暴击")
	_pct.call("hp_pct", "气血上限")
	_pct.call("spd_pct", "速度")
	_pct.call("ult_dmg", "大招")
	if bp.size() > 0:
		rows.append("签加成 " + " · ".join(PackedStringArray(bp)))
	for i in rows.size():
		var lb := UiKit.make_label(panel, Vector2(40, 500.0 + float(i) * 34.0), Vector2(260, 30), 19, UiKit.DIM)
		UiKit.set_text(lb, str(rows[i]))
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# v65：演出片（.ogv）撤掉——那几条是拿立绘去图生视频做的，风格跟"临时 Q版"这一版对不上。
	#   代码与文件都留着（_play_clip / assets/clips），等立绘定了再开。
	# _play_clip(rid)
	# 右侧大图：Q版（临时）——不是立绘。会呼吸微摆的 ArtView 照样能用
	var qtex := CharArt.q(rid)
	if qtex != null:
		var av = ArtView.new()
		panel.add_child(av)
		av.position = Vector2(360, 260)
		av.set_art(qtex, 560.0)
	else:
		var miss := UiKit.make_label(panel, Vector2(330, 420), Vector2(320, 40), 20, UiKit.DIM)
		UiKit.set_text(miss, "（还没有这个人的 Q版图）")
		miss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _ov_fill(panel: Control, kind: String) -> void:
	match kind:
		"stats":
			_ov_stats(panel)
		"talents":
			_ov_talents(panel)
		"weapon":
			_ov_weapon(panel)
		"gear":
			_ov_gear(panel)
		"arts":
			_ov_arts(panel)
		"ult":
			_ov_ult(panel)
		"art":
			_ov_art(panel)


func _ov_talents(panel: Control) -> void:
	var rid := str(_state.role_id)
	var rd: Dictionary = GameState.role_data(rid)
	var y := 108.0
	var iname := str(_state.innate_name())
	if iname != "":
		var l1 := UiKit.make_label(panel, Vector2(40, y), Vector2(600, 120), 22, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.80))
		UiKit.set_text(l1, "【自带】" + iname + "：" + str(_state.innate_desc()))
		l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		y += 132.0
	var l2 := UiKit.make_label(panel, Vector2(40, y), Vector2(600, 120), 22, UiKit.INK)
	if _state.talents.is_empty():
		UiKit.set_text(l2, "天赋：无（五问所定）")
	else:
		UiKit.set_text(l2, "天赋（五问所定）：" + "、".join(PackedStringArray(_state.talents)))
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	y += 132.0
	var pd: Dictionary = rd.get("passive", {})
	if not pd.is_empty():
		var l3 := UiKit.make_label(panel, Vector2(40, y), Vector2(600, 190), 24, UiKit.SEAL)
		UiKit.set_text(l3, "【被动】" + str(pd.get("name", "")) + "：" + str(pd.get("desc", "")))
		l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _ov_ult(panel: Control) -> void:
	var rid := str(_state.role_id)
	var rd: Dictionary = GameState.role_data(rid)
	var ud: Dictionary = rd.get("ult", {})
	var y := 108.0
	var l1 := UiKit.make_label(panel, Vector2(40, y), Vector2(600, 44), 28, UiKit.SEAL)
	UiKit.set_text(l1, "『" + str(ud.get("name", "—")) + "』")
	y += 56.0
	var l2 := UiKit.make_label(panel, Vector2(40, y), Vector2(600, 30), 17, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	UiKit.set_text(l2, "怎么放：自己每出手攒怒气，怒气满下一次出手自动放")
	y += 40.0
	var l3 := UiKit.make_label(panel, Vector2(40, y), Vector2(600, 200), 22, UiKit.INK)
	UiKit.set_text(l3, str(ud.get("desc", "（这门角色没有登记大招）")))
	l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	y += 216.0
	var l4 := UiKit.make_label(panel, Vector2(40, y), Vector2(600, 90), 16, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.65))
	UiKit.set_text(l4, "看家本事——不占功法格、卸不下来。\n游历决斗里血条旁有个「怒」字：满了就放。")
	l4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _ov_weapon(panel: Control) -> void:
	var wid := str(_state.weapon_id())
	var y := 110.0
	if wid == "":
		var l0 := UiKit.make_label(panel, Vector2(40, y), Vector2(600, 40), 26, UiKit.INK)
		UiKit.set_text(l0, "空手（拳法）")
		y += 48.0
	else:
		var l1 := UiKit.make_label(panel, Vector2(40, y), Vector2(600, 40), 26, UiKit.INK)
		UiKit.set_text(l1, str(Cards.item_name(wid)) + GameState.star_marks(wid))
		y += 48.0
		var l2 := UiKit.make_label(panel, Vector2(40, y), Vector2(600, 44), 20, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.80))
		UiKit.set_text(l2, "加成：" + str(Cards.bonus_text(GameState.starred_stats(wid))))
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		y += 52.0
		var l3 := UiKit.make_label(panel, Vector2(40, y), Vector2(600, 32), 18, UiKit.DIM)
		UiKit.set_text(l3, "兵器路数：" + str(WEAPON_CN.get(str(Cards.weapon_of(wid)), "拳脚")))
		y += 44.0
	var l4 := UiKit.make_label(panel, Vector2(40, y + 16.0), Vector2(600, 220), 17, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	UiKit.set_text(l4, "装什么兵器，普攻就用什么招式。\n趟内换装：包裹里点新兵器→［装备］；换下的那把进包裹。\n出门随身那把没换装时，按随身那把算。")
	l4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _state.equipped_item != "":
		var ub := UiKit.make_button(panel, Vector2(240, 720), Vector2(200, 54), "卸下此件", 20)
		ub.pressed.connect(_on_unequip_weapon)


func _ov_gear(panel: Control) -> void:
	for i in GEAR_SLOTS.size():
		var slot := str(GEAR_SLOTS[i])
		var gsid := str(_state.gear_of(slot))
		var cn := str(GEAR_CN.get(slot, slot))
		var txt := "　" + cn + "：" + ("（空）" if gsid == "" else str(Cards.item_name(gsid)) + GameState.star_marks(gsid))
		if i == _ov_sel:
			txt = "▶" + cn + "：" + ("（空）" if gsid == "" else str(Cards.item_name(gsid)) + GameState.star_marks(gsid))
		var btn := UiKit.make_button(panel, Vector2(20, 104.0 + float(i) * 58.0), Vector2(640, 52), txt, 19)
		btn.pressed.connect(_on_ov_pick.bind(i))
	_ov_sel = clampi(_ov_sel, 0, GEAR_SLOTS.size() - 1)
	var slot2 := str(GEAR_SLOTS[_ov_sel])
	var gsid2 := str(_state.gear_of(slot2))
	var cn2 := str(GEAR_CN.get(slot2, slot2))
	var name_lb := UiKit.make_label(panel, Vector2(40, 300), Vector2(600, 40), 26, UiKit.INK)
	if gsid2 == "":
		UiKit.set_text(name_lb, cn2 + "：（空）")
	else:
		UiKit.set_text(name_lb, cn2 + "：" + str(Cards.item_name(gsid2)) + GameState.star_marks(gsid2))
		var b_lb := UiKit.make_label(panel, Vector2(40, 348), Vector2(600, 52), 20, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.80))
		UiKit.set_text(b_lb, "加成：" + str(Cards.bonus_text(GameState.starred_stats(gsid2))))
		b_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note := UiKit.make_label(panel, Vector2(40, 428), Vector2(600, 160), 17, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	UiKit.set_text(note, "装备共 3 格：护甲 · 玉佩 · 披风——每格一件。\n趟内换装：包裹里点新件→［装备］；换下的旧件进包裹。\n出发时带的是村里那套——数值在上表里已算上。")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if gsid2 != "":
		var ub := UiKit.make_button(panel, Vector2(240, 720), Vector2(200, 54), "卸下此件", 20)
		ub.pressed.connect(_on_unequip_gear.bind(slot2))


func _ov_arts(panel: Control) -> void:
	for i in RunState.ART_SLOTS:
		var txt := "　功法 " + str(i + 1) + "：（空）"
		if i < _state.arts.size():
			var sid := str(_state.arts[i])
			var nm := str(Cards.name_of(sid))
			if Cards.by_id(sid).is_empty():
				nm = "未识别·" + sid
			txt = "　功法 " + str(i + 1) + "：" + nm + GameState.star_marks(sid)
		if i == _ov_sel:
			txt = "▶" + txt.substr(1)
		var btn := UiKit.make_button(panel, Vector2(20, 104.0 + float(i) * 64.0), Vector2(640, 58), txt, 19)
		btn.pressed.connect(_on_ov_pick.bind(i))
	_ov_sel = clampi(_ov_sel, 0, RunState.ART_SLOTS - 1)
	if _ov_sel < _state.arts.size():
		var sid2 := str(_state.arts[_ov_sel])
		var art: Dictionary = Cards.art_of(sid2)
		var cd := int(_state.art_cd.get(sid2, 0))
		var n_lb := UiKit.make_label(panel, Vector2(40, 318), Vector2(600, 36), 24, UiKit.INK)
		UiKit.set_text(n_lb, "『" + str(Cards.name_of(sid2)) + "』" + GameState.star_marks(sid2))
		var m_lb := UiKit.make_label(panel, Vector2(40, 354), Vector2(600, 30), 18, UiKit.DIM)
		UiKit.set_text(m_lb, "招式：" + str(art.get("move", "—")))
		var d_lb := UiKit.make_label(panel, Vector2(40, 384), Vector2(600, 84), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
		UiKit.set_text(d_lb, str(art.get("desc", "—")))
		d_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var s_lb := UiKit.make_label(panel, Vector2(40, 478), Vector2(600, 28), 17, UiKit.SEAL if cd <= 0 else UiKit.DIM)
		if cd <= 0:
			UiKit.set_text(s_lb, "状态：就绪——轮到你出手时自动放")
		else:
			UiKit.set_text(s_lb, "状态：冷却中——还要 " + str(cd) + " 次行动")
		var b_lb := UiKit.make_label(panel, Vector2(40, 510), Vector2(600, 56), 16, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.65))
		UiKit.set_text(b_lb, "加成：" + str(Cards.bonus_text(GameState.starred_stats(sid2))))
		b_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var ub := UiKit.make_button(panel, Vector2(240, 720), Vector2(200, 54), "卸下此门", 20)
		ub.pressed.connect(_on_unequip_art.bind(_ov_sel))
	else:
		var e_lb := UiKit.make_label(panel, Vector2(40, 318), Vector2(600, 80), 20, UiKit.DIM)
		UiKit.set_text(e_lb, "（空）——凑齐残页合成后装上。\n功法自动放：轮到你出手时，冷却好的自己使。")
		e_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _on_ov_pick(i: int) -> void:
	_ov_sel = i
	_ov_rebuild()


func _on_unequip_weapon() -> void:
	if _state == null:
		return
	var msg: String = str(_state.unequip_weapon())
	if msg != "":
		UiKit.float_text(_host, msg, UiKit.INK)
	_host._refresh_all()
	_ov_rebuild()


func _on_unequip_art(i: int) -> void:
	if _state == null:
		return
	var msg: String = str(_state.unequip_art(i))
	if msg != "":
		UiKit.float_text(_host, msg, UiKit.INK)
	_host._refresh_all()
	_ov_rebuild()


func _on_unequip_gear(slot: String) -> void:
	if _state == null:
		return
	var msg: String = str(_state.unequip_gear(slot))
	if msg != "":
		UiKit.float_text(_host, msg, UiKit.INK)
	_host._refresh_all()
	_ov_rebuild()


# ============================================================
# 舞台显隐接线
# ============================================================

func set_btn_visible(v: bool) -> void:
	if _char_btn != null:
		_char_btn.visible = v


func set_talent_visible(v: bool) -> void:
	if _talent_zone != null:
		_talent_zone.visible = v
	if _talent_expand_btn != null:
		_talent_expand_btn.visible = v


func bring_btn_front() -> void:
	if _char_btn != null:
		_char_btn.move_to_front()


# ============================================================
# 按住一行看说明（v7：只给新手一句话；面板缩小）
# ============================================================

func _press_tip_attach() -> void:
	if _press_tip_on:
		return
	if _stat_val_lbs.size() != STAT_ROWS.size():
		return
	if _weapon_row == null or _ult_val == null or _art_title == null:
		return
	if _talent_zone == null or _talent_l1 == null or _talent_l2 == null or _talent_l3 == null:
		return
	if _gear_rows.size() < GEAR_SLOTS.size():
		return
	if _art_rows.size() < RunState.ART_SLOTS:
		return
	_press_tip_on = true

	_press_tip_panel = Panel.new()
	_press_tip_panel.size = Vector2(310, 150)
	_press_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_press_tip_panel.add_theme_stylebox_override("panel", UiKit.paper_box(0.97))
	_press_tip_panel.visible = false
	_host.add_child(_press_tip_panel)

	_press_tip_title = UiKit.make_label(_press_tip_panel, Vector2(12, 8), Vector2(286, 22), 16, UiKit.SEAL)
	_press_tip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_press_tip_text = UiKit.make_label(_press_tip_panel, Vector2(12, 34), Vector2(286, 106), 13, UiKit.INK)
	_press_tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_press_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_press_tip_panel.move_to_front()

	for i in STAT_ROWS.size():
		_press_tip_bind(_stat_val_lbs[i], "stat", i)
	_press_tip_bind(_weapon_row, "weapon", -1)
	for i in _gear_rows.size():
		_press_tip_bind(_gear_rows[i], "gear_row", i)
	_press_tip_bind(_ult_val, "ult", -1)
	_press_tip_bind(_art_title, "art_how", -1)
	for i in _art_rows.size():
		_press_tip_bind(_art_rows[i], "art", i)
	_press_tip_bind(_talent_l1, "talents", -1)
	_press_tip_bind(_talent_l2, "talents", -1)
	_press_tip_bind(_talent_l3, "talents", -1)

	if _stats_panel != null:
		_stats_panel.visibility_changed.connect(_press_tip_on_stats_vis)


func _press_tip_bind(ctrl: Control, kind: String, idx: int) -> void:
	if ctrl == null:
		return
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ctrl.gui_input.connect(_press_tip_on_gui.bind(ctrl, kind, idx))


func _press_tip_on_stats_vis() -> void:
	if _stats_panel != null and not _stats_panel.visible:
		_press_tip_hide()


func _press_tip_on_gui(ev: InputEvent, ctrl: Control, kind: String, idx: int) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_press_tip_show(ctrl, kind, idx)
	else:
		_press_tip_hide()


func _press_tip_show(ctrl: Control, kind: String, idx: int) -> void:
	if _press_tip_panel == null or _state == null or _stats_panel == null:
		return
	if not _stats_panel.visible:
		return
	var d: Dictionary = _press_tip_text_for(kind, idx)
	if d.is_empty():
		return
	UiKit.set_text(_press_tip_title, str(d.get("title", "说明")))
	UiKit.set_text(_press_tip_text, str(d.get("body", "")))
	var h := _press_tip_panel.size.y
	var y := 96.0
	if ctrl != null and is_instance_valid(ctrl):
		var r := ctrl.get_global_rect()
		y = r.position.y + r.size.y * 0.5 - h * 0.5
	y = clampf(y, 12.0, maxf(12.0, _host.size.y - h - 12.0))
	_press_tip_panel.position = Vector2(384, y)
	_press_tip_panel.visible = true
	_press_tip_panel.move_to_front()


func _press_tip_hide() -> void:
	if _press_tip_panel != null and is_instance_valid(_press_tip_panel):
		_press_tip_panel.visible = false


func _press_tip_text_for(kind: String, idx: int) -> Dictionary:
	match kind:
		"stat":
			if idx < 0 or idx >= STAT_ROWS.size():
				return {}
			var row: Dictionary = STAT_ROWS[idx]
			var k := str(row.get("k", ""))
			var v := "—"
			if _state != null:
				var st: Dictionary = _state.stats()
				v = str(int(round(float(st.get(k, 0)))))
				if bool(row.get("pct", false)):
					v += "%"
			return {"title": str(row.get("label", "")) + "　=　" + v, "body": str(STAT_TIPS.get(k, "——"))}
		"talents":
			return {"title": "天赋", "body": "天赋＝你（玩家）开局五问定下的签。\n【自带】角色起手就会的；【被动】角色专属本事。\n全部内容看［展开］。"}
		"weapon":
			return {"title": "兵器（1 格）", "body": "装什么兵器，普攻就用什么招式。\n换装：趟内包裹里点新兵器→［装备］。\n效果与卸下：看［展开］。"}
		"gear_row":
			if idx < 0 or idx >= GEAR_SLOTS.size():
				return {}
			var cn := str(GEAR_CN.get(str(GEAR_SLOTS[idx]), "装备"))
			return {"title": cn + "（装备 3 格之一）", "body": "装备共 3 格：护甲 · 玉佩 · 披风。\n趟内可以从包裹里换上来。\n效果与卸下：看［展开］。"}
		"ult":
			return {"title": "大招", "body": "怒气满自动放（自己每出手攒怒气）。\n效果全句与怎么放：点［展开］看。\n不占功法格、卸不下来。"}
		"art_how":
			return {"title": "功法（共 " + str(RunState.ART_SLOTS) + " 格）", "body": "轮到你出手时，冷却好的会自动放。\n详情、冷却与卸下：看［展开］。"}
		"art":
			return {"title": "功法槽 " + str(idx + 1), "body": "点［展开］看这门的效果、冷却与卸下。\n（轮到你出手时，冷却好的自动放）"}
	return {}
