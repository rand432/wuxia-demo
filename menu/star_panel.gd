extends Control
# ============================================================
# star_panel.gd —— 升星台 v2
# 用户：升星台底下的说明字数太小了，字大一点，顶多往上提升一下显示框；
#        上面升星的栏可以滑动不就好了；上面的横框也加大一点，按钮太小了。
#
# v2 四处改动（规则、账本、入口一个都没动）：
#   ① 上面的列表从"翻页"改成**可滑动**（ScrollContainer + VBox，一次能看到六七行，往下滑）
#   ② **行加高**（49 → 64px）：名字 16→18、说明 11→13、星数/差值 13→14
#   ③ **［升星］按钮加大**（140×38 → 148×44，字号 13→15）
#   ④ **底下明细框加大**（12px/130 高 → **15px/190 高**），并整体上移——
#      现在的排版是"列表占上半、明细占下半"，明细那块的显示面积比 v1 大了快一倍
# 一页装两套星，四个页签：
#   ［角色星］材料＝**该角色的碎片**（游历红件掉）＋银两，顺序解锁六级
#        · 行上直接写清：碎片 12/240 · **还差 228 片**；按钮＝升星/差几片
#        · 点一行 → 下面列这个人的**六级明细**（✓已开 / ▷下一级 / ☆未开，各是什么效果）
#        · 行底一条**碎片进度条**，差多少一眼看得见
#   ［兵器］［防具］［功法·武学］ 材料＝**仓库同名份数**＋银两，每星 +20%
#        · 行上写清：仓库 ×N / **差 N 本** / 现 ×倍率；按钮＝升星或差几本
#        · 点一行 → 下面写这一件的**现在加成 → 升后加成**、要几本几两、差多少
#
# ⚠ 这一页**只算账、只显示**：真扣账在 GameState.role_star_up / GameState.star_up
#   里（各一处唯一真源），升完这里落一次盘。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const GameState := preload("res://shared/game_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")     # v58：批量升星窗口的按钮走它
const Elem := preload("res://shared/data_elem.gd")   # v58：五行（元素名/配色/顺序）
signal closed

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const GOLD := Color(0.72, 0.52, 0.14)
const GREEN := Color(0.28, 0.50, 0.30)

const PANEL_W := 640.0
const PANEL_H := 990.0
# v58：批量升星窗口（用户第 2 条）的尺寸
#   ⚠ 580 → **640**：加了"物理"那一行之后共 6 行（起 y=126、每行 58、末行底 468），
#     原来 580 高时提示行在 y=428，会跟第 6 行压在一起。
const PICK_W := 600.0
const PICK_H := 640.0
const LIST_Y := 170.0
const LIST_H := 420.0     # v2：可滑动列表 · v61：468 → 420（把 48 让给明细框；行也加高了）
const ROW_H := 88.0       # v2：行加高（原 49）· v61：64 → 88（说明字 13→15、名字 18→20）
const ROW_GAP := 6.0

# 四个页签：key 决定取哪一批待升的东西
const TABS := [
	{"key": "role", "name": "角色星"},
	{"key": "weapon", "name": "兵器"},
	{"key": "armor", "name": "防具"},
	{"key": "arts", "name": "功法·武学"},
]
const GRADE_COL := {
	"凡品": Color(0.42, 0.40, 0.38),
	"良品": Color(0.30, 0.52, 0.32),
	"上品": Color(0.24, 0.38, 0.62),
	"极品": Color(0.48, 0.30, 0.58),
	"绝品": Color(0.72, 0.52, 0.12),
}

var _panel: Panel
var _tab := 0
var _tabs: Array = []
var _scroll: ScrollContainer
var _list: VBoxContainer
var _rows: Array = []          # 当前建出来的行（下标＝_rows_data 的下标）
var _rows_data: Array = []
var _sel := ""                 # "role:player" / "item:art_wind"——点中的那一项
var _detail_lb: Label
var _msg_lb: Label
var _empty_lb: Label

# v58：批量升星窗口（用户第 2 条）
var _pick_veil: ColorRect = null
var _pick_win: Panel = null
var _pick_ok: Button = null
var _pick_msg: Label = null
var _pick_sid := ""
var _pick: Dictionary = {}      # {元素: 挑几本}
var _pick_elem := ""            # 挑中的那一种用哪一把
var _pick_rows: Array = []      # [{e, num, have}]

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	refresh()
	visible = get_parent() == get_tree().root

# ══════════════════════════════════════════════════════════
func _build() -> void:
	var vp := get_viewport_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.30)
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

	var title := _label("升　星", 30, INK)
	title.position = Vector2(28, 14)
	title.size = Vector2(240, 44)
	_panel.add_child(title)

	var sub := _label("两套星：**角色星**吃这个人的碎片（游历红件掉），六级顺序解锁；**兵器/防具/功法·武学**吃仓库同名份数，每星 +20%。\n列表可以往下滑；点一行看明细——差多少、升完变成什么样，都写在行上和下面那块里。", 13, Color(INK.r, INK.g, INK.b, 0.62))
	sub.position = Vector2(30, 52)
	sub.size = Vector2(582, 56)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(sub)

	var sep := ColorRect.new()
	sep.color = Color(INK.r, INK.g, INK.b, 0.22)
	sep.position = Vector2(28, 112)
	sep.size = Vector2(PANEL_W - 56.0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sep)

	# v2：页签也放大一点（140×42，字号 17）
	_tabs = []
	for i in TABS.size():
		var tb := Button.new()
		tb.text = str(TABS[i]["name"])
		tb.position = Vector2(28.0 + float(i) * 146.0, 118)
		tb.size = Vector2(140, 46)   # v61（手游）：42 → 46 高
		tb.add_theme_font_size_override("font_size", 17)
		tb.focus_mode = Control.FOCUS_NONE
		tb.pressed.connect(_on_tab.bind(i))
		_panel.add_child(tb)
		_tabs.append(tb)

	# v2：可滑动列表（行在 refresh 里现建）
	_scroll = ScrollContainer.new()
	UiKit.drag_scroll(_scroll)
	_scroll.position = Vector2(28, LIST_Y)
	_scroll.size = Vector2(PANEL_W - 56.0, LIST_H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# v15x（用户："所有滑动不要滑动进度条 用指尖滑动那种就可以了"）：
	#   强制藏掉滚动条（Godot 默认主题在内容超出时会冒出来）——拖拽滚动不受影响。
	_scroll.get_v_scroll_bar().visible = false
	_scroll.get_h_scroll_bar().visible = false
	_panel.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(PANEL_W - 72.0, 0)
	_list.add_theme_constant_override("separation", int(ROW_GAP))
	_scroll.add_child(_list)

	_empty_lb = _label("（这一类还没有能升的东西）", 15, Color(INK.r, INK.g, INK.b, 0.50))
	_empty_lb.position = Vector2(28, LIST_Y + 120.0)
	_empty_lb.size = Vector2(PANEL_W - 56.0, 26)
	_empty_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_lb.visible = false
	_panel.add_child(_empty_lb)

	# ---- 明细区（v2：字 12→15、高 130→190，整体上移）----
	# v61（用户："升星栏升星效果说明超出框【需要字体加大 需要框再大一点实在不行可以滑动】"）：
	#   明细框 190 → **230**、正文 15 → **16**，并且**包一层滚动区**——
	#   六级效果连着写下来（每级一句话＋材料）也不怕撑破框，超了直接滑。
	#   为此列表区让出 48（468 → 420，行本身加高了，能看见的行数本来就少一点）。
	var dhead := _label("明细", 15, Color(INK.r, INK.g, INK.b, 0.60))
	dhead.position = Vector2(28, 598)
	dhead.size = Vector2(584, 22)
	_panel.add_child(dhead)
	var dbox := Panel.new()
	dbox.position = Vector2(28, 620)
	dbox.size = Vector2(PANEL_W - 56.0, 230)
	dbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(1, 1, 1, 0.40)
	dsb.set_corner_radius_all(8)
	dsb.border_color = Color(INK.r, INK.g, INK.b, 0.20)
	dsb.set_border_width_all(1)
	dbox.add_theme_stylebox_override("panel", dsb)
	_panel.add_child(dbox)
	var dscroll = ScrollContainer.new()
	UiKit.drag_scroll(dscroll)
	dscroll.position = Vector2(8, 6)
	dscroll.size = Vector2(PANEL_W - 56.0 - 16.0, 218)
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# v15x（用户："所有滑动不要滑动进度条 用指尖滑动那种就可以了"）：
	#   强制藏掉滚动条（Godot 默认主题在内容超出时会冒出来）——拖拽滚动不受影响。
	dscroll.get_v_scroll_bar().visible = false
	dscroll.get_h_scroll_bar().visible = false
	dbox.add_child(dscroll)
	_detail_lb = _label("", 16, Color(INK.r, INK.g, INK.b, 0.88))
	_detail_lb.custom_minimum_size = Vector2(PANEL_W - 56.0 - 16.0 - 16.0, 0)
	_detail_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_lb.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dscroll.add_child(_detail_lb)

	_msg_lb = _label("", 14, Color(SEAL.r, SEAL.g, SEAL.b, 0.92))
	_msg_lb.position = Vector2(28, 866)
	_msg_lb.size = Vector2(PANEL_W - 56.0, 36)
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_msg_lb)

	var close_btn := Button.new()
	close_btn.text = "关　闭"
	close_btn.position = Vector2(220, 910)
	close_btn.size = Vector2(200, 52)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	_style_dark(close_btn)
	_panel.add_child(close_btn)

# ---- 样式 ----

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

func _soft_sb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.35)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(INK.r, INK.g, INK.b, 0.22)
	sb.set_border_width_all(1)
	return sb

func _sel_sb() -> StyleBoxFlat:
	var sb := _soft_sb()
	sb.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.14)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.85)
	sb.set_border_width_all(2)
	return sb

func _style_dark(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.19, 0.20, 0.96)))
	btn.add_theme_stylebox_override("hover", _flat(Color(0.31, 0.27, 0.27, 0.96)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.11, 0.12, 0.96)))
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.45, 0.43, 0.42, 0.40)))
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))
	btn.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.23, 0.22, 0.55))

# 整行点击层：四态都透明（底下的 bg Panel 才是"底色"）
func _style_hit(btn: Button) -> void:
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(str(st), _flat(Color(1, 1, 1, 0.0)))
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))

func _style_tab(btn: Button, selected: bool) -> void:
	if selected:
		btn.add_theme_stylebox_override("normal", _flat(Color(INK.r, INK.g, INK.b, 0.92)))
		btn.add_theme_stylebox_override("hover", _flat(Color(INK.r, INK.g, INK.b, 0.85)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.90)))
		btn.add_theme_color_override("font_color", PAPER)
		btn.add_theme_color_override("font_hover_color", PAPER)
	else:
		btn.add_theme_stylebox_override("normal", _flat(Color(1, 1, 1, 0.35)))
		btn.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.55)))
		btn.add_theme_stylebox_override("pressed", _flat(Color(SEAL.r, SEAL.g, SEAL.b, 0.60)))
		btn.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.78))
		btn.add_theme_color_override("font_hover_color", INK)
	btn.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0)))

# ══════════════════════════════════════════════════════════
# 取数：这一页签要列哪些"待升的东西"

func _pool_match(pool: String, kind: String) -> bool:
	if kind == "weapon":
		return pool == "weapon"
	if kind == "armor":
		return pool == "armor" or pool == "helm" or pool == "cloak"
	return pool == "arts"     # 功法·武学同一张表（被动功法与主动武学都在这儿）

func _kind_cn(pool: String) -> String:
	if pool == "weapon":
		return "兵器"
	if pool == "arts":
		return "功法"
	return str(GameState.SLOT_CN.get(pool, pool))

# 功法那一栏再细分一下：被动功法（专武那类）／主动武学
func _art_kind_cn(sid: String) -> String:
	return "被动功法" if Cards.art_is_passive(sid) else "武学"

func _holder_text(sid: String) -> String:
	var hs: Array = []
	for rid_v in GameState.disciple_ids():
		var rid := str(rid_v)
		var d: Dictionary = GameState.role_data(rid)
		if d.is_empty():
			continue
		var who := str(d.get("name", rid))
		if str(d.get("weapon", "")) == sid:
			hs.append(who + "佩")
			continue
		var gear: Dictionary = d.get("gear", {})
		var got := false
		for slot_v in ["armor", "helm", "cloak"]:
			if str(gear.get(str(slot_v), "")) == sid:
				got = true
				break
		if got:
			hs.append(who + "佩")
			continue
		if (d.get("skills", []) as Array).has(sid):
			hs.append(who + "学")
	if hs.is_empty():
		return "仓库散件"
	if hs.size() == 1:
		return "在 " + str(hs[0])
	return "在 " + str(hs[0]) + " 等 " + str(hs.size()) + " 人"

# v4 口径照旧：仓库有货的 ＋ 已经装在人身上的，同一件只一行
func _entries_for(kind: String) -> Array:
	if kind == "role":
		var rout: Array = []
		for rid_v in GameState.disciple_ids():
			var rid := str(rid_v)
			if GameState.Stars.is_star_role(rid):
				rout.append({"rid": rid})
		return rout
	var seen: Dictionary = {}
	var out: Array = []
	for sid_v in GameState.vault_item_ids():
		var sid := str(sid_v)
		if not GameState.can_star(sid):
			continue
		if not _pool_match(str(Cards.by_id(sid).get("pool", "")), kind):
			continue
		seen[sid] = true
		out.append({"sid": sid})
	for rid_v2 in GameState.disciple_ids():
		var rid2 := str(rid_v2)
		var d: Dictionary = GameState.role_data(rid2)
		if d.is_empty():
			continue
		var cands: Array = []
		var wid := str(d.get("weapon", ""))
		if wid != "":
			cands.append(wid)
		var gear: Dictionary = d.get("gear", {})
		for slot_v in ["armor", "helm", "cloak"]:
			var gsid := str(gear.get(str(slot_v), ""))
			if gsid != "":
				cands.append(gsid)
		for s_v in (d.get("skills", []) as Array):
			cands.append(str(s_v))
		for c_v in cands:
			var sid2 := str(c_v)
			if sid2 == "" or seen.has(sid2) or not GameState.can_star(sid2):
				continue
			if not _pool_match(str(Cards.by_id(sid2).get("pool", "")), kind):
				continue
			seen[sid2] = true
			out.append({"sid": sid2})
	# 排布：品级高的在前，同品级按件名（次序稳定，滑上滑下不会乱跳）
	out.sort_custom(func(a, b):
		var qa := Cards.q_idx(str(a.get("sid", "")))
		var qb := Cards.q_idx(str(b.get("sid", "")))
		if qa != qb:
			return qa > qb
		return str(a.get("sid", "")) < str(b.get("sid", "")))
	return out

# ══════════════════════════════════════════════════════════
# 刷新（v2：行现建现铺，列表可滑）
# ══════════════════════════════════════════════════════════
func refresh() -> void:
	if _panel == null:
		return
	var kind := str(TABS[_tab]["key"])
	_rows_data = _entries_for(kind)
	for i in _tabs.size():
		var tk := str(TABS[i]["key"])
		_tabs[i].text = str(TABS[i]["name"]) + " " + str(_entries_for(tk).size())
		_style_tab(_tabs[i], i == _tab)
	_empty_lb.visible = _rows_data.is_empty()
	# 选中的那条：换了页签/物件没了就默认选第一行
	if _sel == "" or not _sel_matches(kind):
		_sel = _key_of(_rows_data[0]) if not _rows_data.is_empty() else ""
	# 记着滑动位置——重建之后要滑回原处（不然升一次星就跳回顶部）
	var keep_v := _scroll.scroll_vertical if _scroll != null else 0
	_rebuild_rows(kind)
	_refresh_detail()
	if _scroll != null:
		_scroll.set_deferred("scroll_vertical", keep_v)

func _rebuild_rows(kind: String) -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows = []
	for idx in _rows_data.size():
		var ent: Dictionary = _rows_data[idx]
		var row := _make_row(idx)
		var bg: Panel = row["bg"]
		var is_sel: bool = _key_of(ent) == _sel
		bg.add_theme_stylebox_override("panel", _sel_sb() if is_sel else _soft_sb())
		if kind == "role":
			_fill_role_row(row, str(ent.get("rid", "")))
		else:
			_fill_item_row(row, str(ent.get("sid", "")))
		_rows.append(row)

# 一行（v2：高 64、字更大、按钮更大）
func _make_row(idx: int) -> Dictionary:
	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(0, ROW_H)
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(bg)
	# 整行可点（看明细）——必须**先加**，这样它上面的［升星］按钮才抢得到点击
	var hit := Button.new()
	hit.size = Vector2(PANEL_W - 72.0, ROW_H)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	# v61（用户："升星的弟子面板也很难滑动 容易误触，因为是手游"）：
	#   整行点击层原来是普通 Button（STOP）——手指一按就被它吃掉，列表滑不动；
	#   松手又不管拖了多远照样发 pressed → 一滑就误点。改走「拖得动、点得准」那一口。
	UiKit.tap_in_scroll(hit, _on_row_click.bind(idx))
	_style_hit(hit)
	bg.add_child(hit)
	var grade_lb := _label("", 16, INK)
	grade_lb.position = Vector2(14, 14)
	grade_lb.size = Vector2(60, 26)
	bg.add_child(grade_lb)
	# v61：名字 18→20、说明 13→**15 且给两行**（300 宽 × 44 高，开了自动换行）——
	#   原来说明只有 250×22（一行 13 号），长一点的效果（"被动「扎马稳桩」效果 +50%…"）
	#   就被切在框外，这就是"升星效果说明超出框"。
	var name_lb := _label("", 20, INK)
	name_lb.position = Vector2(78, 6)
	name_lb.size = Vector2(300, 28)
	bg.add_child(name_lb)
	var sub_lb := _label("", 15, Color(INK.r, INK.g, INK.b, 0.62))
	sub_lb.position = Vector2(78, 38)
	sub_lb.size = Vector2(300, 44)
	sub_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lb.clip_text = true
	bg.add_child(sub_lb)
	var cnt_lb := _label("", 16, Color(INK.r, INK.g, INK.b, 0.70))
	cnt_lb.position = Vector2(296, 10)
	cnt_lb.size = Vector2(114, 28)
	cnt_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bg.add_child(cnt_lb)
	# 角色星那一页才有：碎片进度条（贴在行底）
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(78, 82)
	bar_bg.size = Vector2(240, 4)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.visible = false
	bg.add_child(bar_bg)
	var bar_fill := ColorRect.new()
	bar_fill.color = GOLD
	bar_fill.position = Vector2(78, 82)
	bar_fill.size = Vector2(0, 4)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_fill.visible = false
	bg.add_child(bar_fill)
	var up_btn := Button.new()
	up_btn.text = "升星"
	up_btn.position = Vector2(PANEL_W - 72.0 - 148.0, 22.0)
	up_btn.size = Vector2(148, 44)
	up_btn.add_theme_font_size_override("font_size", 16)
	up_btn.focus_mode = Control.FOCUS_NONE
	UiKit.tap_in_scroll(up_btn, _on_row_up.bind(idx))   # v61：滚动区里的钮也要拖得动
	_style_dark(up_btn)
	bg.add_child(up_btn)
	return {"bg": bg, "hit": hit, "grade": grade_lb, "name": name_lb, "sub": sub_lb,
		"cnt": cnt_lb, "bar_bg": bar_bg, "bar_fill": bar_fill, "btn": up_btn}

# ============================================================
# v58（用户第 2 条）：**批量升星窗口**
#   "武器的升星栏和功法升星栏最好有一个额外窗口可以选择或者选择多个同类型升级，
#   带元素的件（**上品起的兵器**）点［升星…］会先开这一页：
#     · 列出这件名下**各元素各几本**，每行一个：[−] N [+]
#     · 底下一行实时算"已挑 x / 共 y 本"，挑够才让点［确定升星］
#   于是"想保留某个元素"＝把不想要的那几份喂掉、把想要的那份留住。
#   ⚠ 没有元素可挑的（下品兵器／护甲／玉佩／披风／功法）**照旧一键升星**，行为一个字没变。
# ============================================================
#   于是"想保留某个元素"＝把不想要的那几份喂掉、把想要的那份留住。
#   ⚠ 没有元素可挑的（下品兵器／护甲／玉佩／披风／功法）**照旧一键升星**，行为一个字没变。
# ============================================================
func _open_pick(sid: String) -> void:
	_close_pick()
	_pick_sid = sid
	_pick = {}
	_pick_elem = GameState.elem_pick(sid)
	var vp := get_viewport_rect().size
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.34)
	veil.size = vp
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	_pick_veil = veil
	var w := Panel.new()
	w.position = Vector2((vp.x - PICK_W) * 0.5, (vp.y - PICK_H) * 0.5)
	w.size = Vector2(PICK_W, PICK_H)
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.995)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(0.32, 0.27, 0.22, 0.60)
	sb.set_border_width_all(2)
	w.add_theme_stylebox_override("panel", sb)
	veil.add_child(w)
	_pick_win = w
	_pick_rows = []
	_pick_msg = _label("", 15, SEAL)
	_pick_msg.position = Vector2(28, PICK_H - 152.0)
	_pick_msg.size = Vector2(PICK_W - 56.0, 46)
	_pick_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w.add_child(_pick_msg)
	var ok := UiKit.make_button(w, Vector2(PICK_W * 0.5 - 196.0, PICK_H - 96.0), Vector2(184, 56), "确定升星", 21)
	_pick_ok = ok
	ok.pressed.connect(_pick_confirm)
	var back := UiKit.make_button(w, Vector2(PICK_W * 0.5 + 12.0, PICK_H - 96.0), Vector2(184, 56), "取消", 21)
	back.pressed.connect(_close_pick)
	_fill_pick()

func _close_pick() -> void:
	if _pick_veil != null and is_instance_valid(_pick_veil):
		_pick_veil.queue_free()
	_pick_veil = null
	_pick_win = null
	_pick_ok = null
	_pick_msg = null
	_pick_rows = []
	_pick_sid = ""

func _fill_pick() -> void:
	if _pick_win == null or not is_instance_valid(_pick_win):
		return
	for c in _pick_win.get_children():
		if c == _pick_msg or c == _pick_ok:
			continue
		if c is Label or c is Button or c is ColorRect:
			if c != _pick_ok:
				c.queue_free()
	_pick_rows = []
	var sid := _pick_sid
	# v60：名字口径统一走 item_name（成品名）——name_of 是残卡套名（长剑），
	#   跟仓库格子上写的"青锋剑"对不上，玩家会以为两份东西。（同装备/弟子面板那几处）
	var nm := Cards.item_name(sid)
	var star := GameState.star_of(sid)
	var cost := GameState.star_cost_next(sid)
	var sp := GameState.star_silver_next(sid)
	var t1 := _label(nm + GameState.star_marks(sid), 26, INK)
	t1.position = Vector2(28, 20)
	t1.size = Vector2(PICK_W - 56.0, 36)
	_pick_win.add_child(t1)
	var t2 := _label("升 " + str(star + 1) + " 星　要同名 **" + str(cost) + "** 本 · 银两 " + str(sp)
		+ "　（仓库 " + str(GameState.vault_item_count(sid)) + " 本）", 16, Color(INK.r, INK.g, INK.b, 0.72))
	t2.position = Vector2(28, 58)
	t2.size = Vector2(PICK_W - 56.0, 26)
	_pick_win.add_child(t2)
	var t3 := _label("挑这一次要吃的份数——没挑到的元素原样留着（这就是「保留某个元素」）", 15, Color(INK.r, INK.g, INK.b, 0.52))
	t3.position = Vector2(28, 88)
	t3.size = Vector2(PICK_W - 56.0, 24)
	_pick_win.add_child(t3)
	var own := GameState.elem_own(sid)
	var y := 126.0
	# ⚠ v58（用户："武器随机元素 也会随到空的 也就是物理"）：**物理那一档也要列出来**——
	#   摇到物理的份数同样要能被挑着吃掉，不然那些份数就"看得见、吃不着"。
	for e_v in GameState.ELEM_POOL_KEYS:
		# ⚠ v58 的补丁：物理那一档的元素名与配色也走 Elem.col(e)——别漏了物理
		var e := str(e_v)
		var have := int(own.get(e, 0))
		var row := Panel.new()
		row.position = Vector2(28, y)
		row.size = Vector2(PICK_W - 56.0, 52)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(Elem.col(e).r, Elem.col(e).g, Elem.col(e).b, 0.13 if have > 0 else 0.05)
		rsb.set_corner_radius_all(8)
		rsb.border_color = Color(Elem.col(e).r, Elem.col(e).g, Elem.col(e).b, 0.55)
		rsb.set_border_width_all(1)
		row.add_theme_stylebox_override("panel", rsb)
		_pick_win.add_child(row)
		var lb := _label(Elem.cn(e) + "属性　仓库 " + str(have) + " 本", 18, Elem.col(e) if have > 0 else Color(INK.r, INK.g, INK.b, 0.35))
		lb.position = Vector2(14, 12)
		lb.size = Vector2(240, 28)
		row.add_child(lb)
		var use := Button.new()
		use.text = ("用这一把" if _pick_elem == e else "改用这把")
		use.position = Vector2(268, 8)
		use.size = Vector2(112, 36)
		use.focus_mode = Control.FOCUS_NONE
		use.add_theme_font_size_override("font_size", 14)
		use.disabled = have <= 0
		use.pressed.connect(_pick_use.bind(e))
		_style_dark(use)
		row.add_child(use)
		var minus := Button.new()
		minus.text = "−"
		minus.position = Vector2(392, 8)
		minus.size = Vector2(44, 36)
		minus.focus_mode = Control.FOCUS_NONE
		minus.disabled = have <= 0
		minus.pressed.connect(_pick_step.bind(e, -1))
		_style_dark(minus)
		row.add_child(minus)
		var num := _label("0", 20, INK)
		num.position = Vector2(442, 12)
		num.size = Vector2(48, 28)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(num)
		var plus := Button.new()
		plus.text = "＋"
		plus.position = Vector2(492, 8)
		plus.size = Vector2(44, 36)
		plus.focus_mode = Control.FOCUS_NONE
		plus.disabled = have <= 0
		plus.pressed.connect(_pick_step.bind(e, 1))
		_style_dark(plus)
		row.add_child(plus)
		_pick_rows.append({"e": e, "num": num, "have": have})
		y += 58.0
	_pick_refresh()

func _pick_step(e: String, d: int) -> void:
	var have := 0
	for r_v in _pick_rows:
		if str((r_v as Dictionary).get("e", "")) == e:
			have = int((r_v as Dictionary).get("have", 0))
	var cur := int(_pick.get(e, 0))
	_pick[e] = clampi(cur + d, 0, have)
	_pick_msg.text = ""
	_pick_refresh()

func _pick_use(e: String) -> void:
	_pick_elem = e
	var msg := GameState.elem_set_pick(_pick_sid, e)
	_pick_msg.text = msg
	_pick_refresh()

func _pick_refresh() -> void:
	if _pick_win == null or not is_instance_valid(_pick_win):
		return
	for r_v in _pick_rows:
		var r: Dictionary = r_v
		var e := str(r.get("e", ""))
		var lb: Label = r.get("num")
		if lb != null and is_instance_valid(lb):
			lb.text = str(int(_pick.get(e, 0)))
			lb.add_theme_color_override("font_color",
				Elem.col(e) if int(_pick.get(e, 0)) > 0 else Color(INK.r, INK.g, INK.b, 0.45))
	var star := GameState.star_of(_pick_sid)
	var cost := GameState.star_cost_next(_pick_sid)
	var total := GameState.star_pick_total(_pick)
	var sp := GameState.star_silver_next(_pick_sid)
	if _pick_ok != null and is_instance_valid(_pick_ok):
		_pick_ok.disabled = (total != cost) or GameState.coin("silver") < sp
		_pick_ok.text = "确定升星（" + str(total) + "/" + str(cost) + " 本）"
	if _pick_msg != null and is_instance_valid(_pick_msg) and _pick_msg.text == "":
		if total == cost:
			_pick_msg.text = "挑好了：吃 " + str(total) + " 本 → 升到 " + str(star + 1) + " 星（银两 -" + str(sp) + "）"
			_pick_msg.add_theme_color_override("font_color", GREEN)
		else:
			_pick_msg.text = "还要挑 " + str(maxi(0, cost - total)) + " 本（也可以挑多了再减）"
			_pick_msg.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.55))

func _pick_confirm() -> void:
	var msg := GameState.star_up_pick(_pick_sid, _pick)
	_msg_lb.text = msg
	if msg.begins_with("「"):
		GameState.save_game()
		_close_pick()
		refresh()


func _key_of(ent: Dictionary) -> String:
	if ent.has("rid"):
		return "role:" + str(ent.get("rid", ""))
	return "item:" + str(ent.get("sid", ""))

func _sel_matches(kind: String) -> bool:
	if kind == "role":
		return _sel.begins_with("role:")
	for ent_v in _rows_data:
		if _key_of(ent_v as Dictionary) == _sel:
			return true
	return false

func _fill_role_row(row: Dictionary, rid: String) -> void:
	var cur := GameState.role_star_of(rid)
	var maxn := GameState.role_star_max()
	var nm := str(GameState.role_data(rid).get("name", rid))
	var grade_lb: Label = row["grade"]
	grade_lb.text = str(cur) + "/" + str(maxn)
	grade_lb.add_theme_color_override("font_color", GOLD if cur > 0 else Color(INK.r, INK.g, INK.b, 0.45))
	var name_lb: Label = row["name"]
	name_lb.text = nm + "　" + "★".repeat(cur) + "☆".repeat(maxi(0, maxn - cur))
	var sub_lb: Label = row["sub"]
	var cnt_lb: Label = row["cnt"]
	var btn: Button = row["btn"]
	var bar_bg: ColorRect = row["bar_bg"]
	var bar_fill: ColorRect = row["bar_fill"]
	bar_bg.visible = true
	bar_fill.visible = true
	if cur >= maxn:
		sub_lb.text = "已满星（" + str(maxn) + " 星）"
		cnt_lb.text = "满星"
		cnt_lb.add_theme_color_override("font_color", GOLD)
		btn.text = "满星"
		btn.disabled = true
		bar_fill.size = Vector2(240, 4)
		return
	var need := GameState.role_star_cost_frag(rid)
	var have := GameState.fragment_count(GameState.Stars.frag_key(rid))
	var sp := GameState.role_star_cost_silver(rid)
	var gap := maxi(0, need - have)
	sub_lb.text = GameState.role_star_frag_name(rid) + " " + str(have) + "/" + str(need)
	bar_fill.size = Vector2(240.0 * clampf(float(have) / float(maxi(need, 1)), 0.0, 1.0), 4)
	var can := GameState.role_star_can(rid)
	var ok := bool(can.get("ok", false))
	if gap > 0:
		cnt_lb.text = "还差 " + str(gap) + " 片"
		cnt_lb.add_theme_color_override("font_color", SEAL)
		btn.text = "差 " + str(gap) + " 本"
		btn.disabled = true
	elif not ok:
		cnt_lb.text = "银两不够"
		cnt_lb.add_theme_color_override("font_color", SEAL)
		btn.text = "缺 " + str(sp) + " 两"
		btn.disabled = true
	else:
		cnt_lb.text = "可升 " + str(sp) + " 两"
		cnt_lb.add_theme_color_override("font_color", GREEN)
		btn.text = "升星 " + str(sp) + " 两"
		btn.disabled = false

func _fill_item_row(row: Dictionary, sid: String) -> void:
	var star := GameState.star_of(sid)
	var grade := GameState.grade_of(sid)
	var pool := str(Cards.by_id(sid).get("pool", ""))
	var tag := _art_kind_cn(sid) if pool == "arts" else _kind_cn(pool)
	var grade_lb: Label = row["grade"]
	grade_lb.text = grade
	grade_lb.add_theme_color_override("font_color", GRADE_COL.get(grade, INK))
	var name_lb: Label = row["name"]
	name_lb.text = Cards.item_name(sid) + GameState.star_marks(sid)   # v60：成品名，见 _pick_open
	var sub_lb: Label = row["sub"]
	var cnt_lb: Label = row["cnt"]
	var btn: Button = row["btn"]
	var bar_bg: ColorRect = row["bar_bg"]
	var bar_fill: ColorRect = row["bar_fill"]
	bar_bg.visible = false
	bar_fill.visible = false
	var have := GameState.vault_item_count(sid)
	sub_lb.text = "【" + tag + "】" + _holder_text(sid) + "　现 " + Cards.bonus_text(GameState.starred_stats(sid))
	cnt_lb.text = "仓库 ×" + str(have)
	if star >= GameState.STAR_MAX:
		cnt_lb.add_theme_color_override("font_color", GOLD)
		btn.text = "已满星"
		btn.disabled = true
		return
	var cost := GameState.star_cost_next(sid)
	var sp := GameState.star_silver_next(sid)
	var enough_books := have >= cost
	var enough_silver := GameState.coin("silver") >= sp
	if not enough_books:
		cnt_lb.add_theme_color_override("font_color", SEAL)
		btn.text = "还差 " + str(cost - have) + " 本"
		btn.disabled = true
	elif not enough_silver:
		cnt_lb.add_theme_color_override("font_color", SEAL)
		btn.text = "缺 " + str(sp) + " 两"
		btn.disabled = true
	else:
		cnt_lb.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.70))
		# v58：带元素的件点的是**批量窗口**（挑哪几份吃），按钮名要跟行为对齐
		if GameState.elem_eligible(sid):
			btn.text = "升星…（挑 " + str(cost) + " 本）"
		else:
			btn.text = "升星 " + str(cost) + "本/" + str(sp) + "两"
		btn.disabled = false
	# v58：行上补一句"这件名下有哪些元素"（一眼看出留哪把、喂哪把）
	if GameState.elem_eligible(sid):
		var el := GameState.elem_line(sid)
		if el != "":
			cnt_lb.text = "仓库 ×" + str(have) + "　" + el
			cnt_lb.add_theme_color_override("font_color", GOLD)

# ---- 明细区 ----

func _refresh_detail() -> void:
	var kind := str(TABS[_tab]["key"])
	if _sel == "":
		_detail_lb.text = "点上面任意一行看明细。"
		return
	if kind == "role":
		_detail_lb.text = _detail_role(_sel.substr(5))
	else:
		_detail_lb.text = _detail_item(_sel.substr(5))

func _detail_role(rid: String) -> String:
	var cur := GameState.role_star_of(rid)
	var maxn := GameState.role_star_max()
	var nm := str(GameState.role_data(rid).get("name", rid))
	var head := nm + " · 角色星 " + str(cur) + "/" + str(maxn)
	if cur >= maxn:
		head += "（已满星）"
	else:
		var need := GameState.role_star_cost_frag(rid)
		var have := GameState.fragment_count(GameState.Stars.frag_key(rid))
		var sp := GameState.role_star_cost_silver(rid)
		head += "　" + GameState.role_star_frag_name(rid) + " " + str(have) + "/" + str(need)
		if have < need:
			head += "（还差 " + str(need - have) + " 片）"
		else:
			head += "（碎片够了）"
		head += "　银两 " + str(sp) + "（现有 " + str(GameState.coin("silver")) + "）"
	var lines: Array = [head]
	if cur < maxn:
		# next_line 自己就带「下一星【名】：…」，这里别再前缀一个
		lines.append(GameState.Stars.next_line(rid, cur))
	var arr: Array = GameState.Stars.levels(rid)
	for i in arr.size():
		var lv := i + 1
		var d: Dictionary = arr[i]
		var mark := "✓"
		if lv <= cur:
			mark = "✓"
		elif lv == cur + 1:
			mark = "▷"
		lines.append(mark + str(lv) + "　" + str(d.get("name", "")) + "　" + str(d.get("desc", "")))
	return "\n".join(PackedStringArray(lines))

func _bonus_at(sid: String, lv: int) -> String:
	var base: Dictionary = Cards.item_stats(sid)
	var mul := 1.0 + float(lv) * GameState.STAR_MUL_PER
	var out: Dictionary = {}
	for k in base.keys():
		out[k] = int(round(float(base[k]) * mul))
	return Cards.bonus_text(out)

func _detail_item(sid: String) -> String:
	var star := GameState.star_of(sid)
	var nm := Cards.item_name(sid)   # v60：成品名，见 _pick_open
	var grade := GameState.grade_of(sid)
	var pool := str(Cards.by_id(sid).get("pool", ""))
	var tag := _art_kind_cn(sid) if pool == "arts" else _kind_cn(pool)
	var lines: Array = []
	var is_art := pool == "arts"
	# ⚠ 提到函数级：GDScript 是块级作用域，声明在 if 里的话后面那个 if 用不到
	var base_mul := float((Cards.art_of(sid) as Dictionary).get("mult", 0.0)) if is_art else 0.0
	if is_art:
		# v62f-b（用户："倍率拆成 5 份 我说的是包括他本身的倍率哦 比如xx 原本倍率 2.8
		#   现在可能1.1 剩余的被拆成加成了"）：**表上印的倍率是满星值**，
		#   0★ 只拿 40%（2.8 → 1.12），剩下 60% 拆 5 份（6/9/12/15/18%）发给 1~5★。
		lines.append("「" + nm + "」" + grade + " · 【" + tag + "】　星 " + str(star) + "/" + str(GameState.STAR_MAX) + "　" + _holder_text(sid))
		lines.append("招数倍率：×" + str(snappedf(GameState.art_mult(sid, base_mul), 0.01))
			+ "／满星 ×" + str(snappedf(base_mul * 1.5, 0.01)) + "（星级系数 " + str(snappedf(GameState.art_star_mul(sid), 0.01)) + "）")
	else:
		lines.append("「" + nm + "」" + grade + " · 【" + tag + "】　星 " + str(star) + "/" + str(GameState.STAR_MAX)
			+ "　每星 +" + str(int(GameState.STAR_MUL_PER * 100.0)) + "%　" + _holder_text(sid))
	if star >= GameState.STAR_MAX:
		lines.append("已满星：加成 " + Cards.bonus_text(GameState.starred_stats(sid)) + "（×" + str(snappedf(GameState.star_mul(sid), 0.1)) + "）")
		if is_art:
			var say := GameState.art_star5_line(sid)
			if say != "":
				lines.append("满星专属：" + say)
	else:
		var cost := GameState.star_cost_next(sid)
		var have := GameState.vault_item_count(sid)
		var sp := GameState.star_silver_next(sid)
		if is_art:
			lines.append("现在加成：" + Cards.bonus_text(GameState.starred_stats(sid))
				+ "\n　　→　" + str(star + 1) + " 星：" + _bonus_at(sid, star + 1)
				+ "　倍率 → ×" + str(snappedf(base_mul * (GameState.ART_BASE_RATIO + _share_sum(star + 1)), 0.01))
				+ "（品质系数 " + str(snappedf(float(GameState.ART_STAR_Q_MUL[Cards.q_idx(sid)]), 0.1)) + " 放大属性）")
		else:
			lines.append("现在：" + Cards.bonus_text(GameState.starred_stats(sid)) + "（×" + str(snappedf(GameState.star_mul(sid), 0.1)) + "）"
				+ "\n　　→　" + str(star + 1) + " 星：" + _bonus_at(sid, star + 1) + "（×" + str(snappedf(1.0 + float(star + 1) * GameState.STAR_MUL_PER, 0.1)) + "，够）")
		var gap_txt := "，够）"
		if have < cost:
			gap_txt = "，还差 " + str(cost - have) + " 本）"
		lines.append("要同名份数 " + str(cost) + " 本（仓库 " + str(have) + gap_txt + "　＋　银两 " + str(sp) + "（现有 " + str(GameState.coin("silver")) + "）")
	lines.append(_effect_note(pool))
	return "\n".join(PackedStringArray(lines))

# 前 n 星的份额合计（0★=0，满星=1.0）
func _share_sum(n: int) -> float:
	var acc := 0.0
	for i in clampi(n, 0, GameState.ART_STAR_SHARE.size()):
		acc += float(GameState.ART_STAR_SHARE[i])
	return acc

func _effect_note(pool: String) -> String:
	if pool == "arts":
		# v62f-c：武学升星说明——满星 150% ＋ 1~4★ 数值属性按品质放大
		return "星记在这门功法上，换谁学都算。武学这一份吃**三层**：① 招数倍率随星放大——**表上印的那个数是基准**，0★ 只拿四成、**满星到 150%**（每星加一份 12/18/23/27/30%）；② 每星给一份**数值型**属性（攻击/气血/防御/速度/暴击的点数，按这门武学的定位给，并**按品质放大**：凡1.0／良1.3／上1.6／极2.0／绝2.5）；③ 满星再给这门功法**自己的专属效果**（少许百分比，类似专武，不随品质变）。"
	if pool == "weapon":
		return "星记在这把兵器上，换谁拿都算。加成直接进面板攻击（普攻与招式都按它算）。"
	return "星记在这件防具上，换谁穿都算。加成直接进面板（气血/防御/暴击/闪避那一份）。"

# ══════════════════════════════════════════════════════════
# 交互
# ══════════════════════════════════════════════════════════

func _on_row_click(idx: int) -> void:
	if idx < 0 or idx >= _rows_data.size():
		return
	_sel = _key_of(_rows_data[idx])
	_msg_lb.text = ""
	refresh()

func _on_row_up(idx: int) -> void:
	if idx < 0 or idx >= _rows_data.size():
		return
	var ent: Dictionary = _rows_data[idx]
	_sel = _key_of(ent)
	_msg_lb.text = ""
	if ent.has("rid"):
		var rid := str(ent.get("rid", ""))
		var msg := GameState.role_star_up(rid)
		_msg_lb.text = msg
		if msg.begins_with("「"):
			GameState.save_game()   # 花掉碎片与银两了，立刻落盘
	else:
		var sid := str(ent.get("sid", ""))
		# v58（用户第 2 条）：**带元素的件先开批量窗口**（挑哪几份吃 / 改用哪一把）
		#   没元素可挑的（下品兵器／护甲/玉佩/披风/功法）照旧一键升星，行为一个字没变。
		#   ⚠ 满星时不开窗（按钮本来就禁用了）
		if GameState.elem_eligible(sid) and GameState.star_of(sid) < GameState.STAR_MAX:
			_open_pick(sid)
			return
		var msg2 := GameState.star_up(sid)
		_msg_lb.text = msg2
		if msg2.begins_with("「"):
			GameState.save_game()
	refresh()

func _on_tab(i: int) -> void:
	_tab = i
	_sel = ""
	_msg_lb.text = ""
	refresh()
	if _scroll != null:
		_scroll.set_deferred("scroll_vertical", 0)

# ---- 开合 ----

func open(which := "") -> void:
	_sel = ""
	if which != "":
		for i in TABS.size():
			if str(TABS[i]["key"]) == which:
				_tab = i
	refresh()
	if _scroll != null:
		_scroll.set_deferred("scroll_vertical", 0)
	visible = true

func close() -> void:
	if not visible:
		return
	UiKit.hide_panel(self)
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
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
