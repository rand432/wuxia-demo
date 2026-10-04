extends RefCounted
# ============================================================
# journey_bag_panel.gd —— 包裹板件 v4（放大批）
# v4（放大批）：玩家"包裹的字还是太小"——本件字号整体上调：
#   行标题 16→21 · 格内卡名 14→19 · 翻页钮 17→19 · 板下提示 17→19 ·
#   详情正文 16→21 · 详情按钮 16→19（详情大标题 28 本就在档内，不动）。
#   ⚠ 几何：板面仍 290×306、底边仍 366——journey_common.POPUP_TOP(=384)
#     就是挂在"板底 366 + 18"上的，板高一改全游历七个弹窗都要跟着挪，所以不动。
#     只把标题框 26→30 高（y 6~36，格子仍在 y=40 起，不压字）。
#     合成钮 (414,380)、提示 (414,444) 两个 y 也没动：提示框 92 高，19 号字最长
#     那条（45 字）排 3 行 ≈ 78，仍装得下。
# v3（优化批⑰）：同款在身时，详情直说"这件留在包裹（结算带进村仓库）"——按钮保持
#   ［装备］：此格动作本就无事可做（件已在包裹里），改成"替换"反而是第二次撒谎。
# v2（优化批⑯）：装备（护甲/玉佩/披风）详情按"替换该位"口径说话——［装备］按钮本就
#   通吃（equip_from_bag 已认三件套），之前只是话按兵器讲的。
# v1（拆件批）：
# 拆分自 journey_stage v20 的：DragCell / _build_bag / _refresh_bag / _bag_page_count /
# _on_bag_page_next / _cell_box / _update_tip / _on_bag_slot / _show_card_detail /
# _on_detail_action。逐字搬运、零逻辑改；与舞台的接口：
#   _build_bag() / _refresh_bag() / _update_tip() / set_ui_visible(v) / bring_panel_front()
# DragCell.stage_ref 现指向本件（读本件的 _state 与 _bag_page）——拖拽数据格式不变。
# 不引 journey_stage（防循环——老铁律）。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const GameState := preload("res://shared/game_state.gd")   # v37：成品显示含升星的加成
const JourneyCommon := preload("res://journey/journey_common.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const ItemArt := preload("res://shared/item_art.gd")   # v73：按名字取水墨图

# 包裹每页格数（右下角那格给翻页钮，3×3 里只看 8 格/页）。
# 容量上限在 run_state.bag_cap()——宠物驮运加格数时只改那边。
const BAG_PAGE := 8


# ---- 包裹格子：可拖动（原 journey_stage.DragCell，逐字搬；stage_ref 改指本件） ----
class DragCell extends Panel:
	var idx := -1
	var stage_ref = null

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if stage_ref == null or not is_instance_valid(stage_ref):
			return null
		var bag: Array = stage_ref._state.bag
		var bi := idx + int(stage_ref._bag_page) * 8   # 视图格 → 真实包裹序号（每页 8 格）
		if bi < 0 or bi >= bag.size():
			return null
		var label_txt := str(stage_ref._state.card_label(bag[bi]))
		var d := {"bag_index": bi, "label": label_txt}
		var prev := Label.new()
		prev.text = label_txt
		prev.add_theme_font_size_override("font_size", 19)   # v4：跟格内卡名（14→19）一个号
		prev.add_theme_color_override("font_color", Color(0.12, 0.11, 0.13))
		set_drag_preview(prev)
		return d


var _host = null
var _state = null

var _bag_panel: Panel
var _bag_title: Label
var _cell_panels: Array = []
var _cell_labels: Array = []
var _cell_icons: Array = []     # v73：每格一张水墨图（道具/兵器/功法）
var _bag_page := 0
var _page_btn: Button = null
var _synth_btn: Button
var _tip_label: Label


func setup(host) -> void:
	_host = host
	_state = host._state


func _build_bag() -> void:
	_bag_panel = Panel.new()
	_bag_panel.position = Vector2(414, 60)
	_bag_panel.size = Vector2(290, 306)
	_bag_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_bag_panel.add_theme_stylebox_override("panel", UiKit.paper_box(0.95))
	_host.add_child(_bag_panel)

	# v4：16→21；框高 26→30（y 6~36）——格子仍在 y=40 起，留 4 像素不压字
	_bag_title = UiKit.make_label(_bag_panel, Vector2(12, 6), Vector2(266, 30), 21, UiKit.INK)
	UiKit.set_text(_bag_title, "包裹 0/8")

	_cell_panels.clear()
	_cell_labels.clear()
	_cell_icons.clear()
	for i in BAG_PAGE:
		var col := i % 3
		var row := int(i / 3)
		var cell := DragCell.new()
		cell.idx = i
		cell.stage_ref = self
		cell.position = Vector2(16 + col * 88, 40 + row * 88)
		cell.size = Vector2(82, 82)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(_on_bag_slot.bind(i))
		_bag_panel.add_child(cell)
		# v73（用户：「道具武器功法都没有图」）：格子里压一张水墨图（按名字选），
		#   40×40 摆在正中偏上，名字仍居中压在下面，两者不打架。
		# v76（用户：「装备功法图有点不居中」）：图上、字下，各占一半，互不压
		var ic := TextureRect.new()
		ic.position = Vector2(22, 5)
		ic.size = Vector2(38, 38)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.modulate.a = 0.92
		cell.add_child(ic)
		_cell_icons.append(ic)
		var lb := Label.new()
		lb.position = Vector2(2, 44)      # v76：名字挪到图下面
		lb.size = Vector2(78, 36)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# v4：格内卡名 14→20 起——探针实测 20 号下最长的"燕子三抄水·卷首"（8 字）
		#   在 78 宽的框里要 3 行、需要 90 高 > 78，字会漏到格子外面（82 高），于是收到 19：
		#   19 号下一行 4 个字（76 ≤ 78），8 字名 2 行、需要 59 ≤ 78，稳装。
		#   max_lines_visible=3 是保险：真出现 12 字以上的名字也只截尾打省略号，不漏字。
		lb.add_theme_font_size_override("font_size", 15)   # v76：给图让出上半格
		lb.max_lines_visible = 2
		lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lb.add_theme_color_override("font_color", UiKit.INK)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(lb)
		_cell_panels.append(cell)
		_cell_labels.append(lb)

	# 右下角空位 = 翻页钮（3×3 里的第 9 格）
	_page_btn = Button.new()
	_page_btn.position = Vector2(16 + 2 * 88, 40 + 2 * 88)
	_page_btn.size = Vector2(82, 82)
	_page_btn.focus_mode = Control.FOCUS_NONE
	_page_btn.flat = true
	_page_btn.add_theme_font_size_override("font_size", 19)   # v4：17→19（框 82×82 装"▶\n1/2"两行）
	_page_btn.add_theme_color_override("font_color", UiKit.INK)
	_page_btn.add_theme_color_override("font_hover_color", UiKit.SEAL)
	_page_btn.pressed.connect(_on_bag_page_next)
	_bag_panel.add_child(_page_btn)

	# v4：合成钮 20 号本就在档内（19~21），不动——它下面那颗提示才是小字
	_synth_btn = UiKit.make_button(_host, Vector2(414, 380), Vector2(290, 52), "合成（0）", 20)
	_synth_btn.disabled = true
	_synth_btn.pressed.connect(_host._on_synth_pressed)

	# v4：提示 17→19（次要信息档）。框仍 92 高：最长那条 45 字，19 号下 290 宽一行 15 字，
	#   排 3 行 ≈ 78 ≤ 92，装得下；y=444 没动，底边 536 离底部日志条（y=1030）还远。
	_tip_label = UiKit.make_label(_host, Vector2(414, 444), Vector2(290, 92), 19, UiKit.DIM)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _refresh_bag() -> void:
	if _bag_title == null or _state == null:
		return
	var synthables: Array = _state.ready_sets()
	var pages := _bag_page_count()
	_bag_page = clampi(_bag_page, 0, pages - 1)
	var pg_tail := ""
	if pages > 1:
		pg_tail = "　·　第 " + str(_bag_page + 1) + "/" + str(pages) + " 页"
	UiKit.set_text(_bag_title, "包裹 " + str(_state.bag.size()) + "/" + str(_state.bag_cap()) + pg_tail)
	for i in BAG_PAGE:
		var cell: Panel = _cell_panels[i]
		var lb: Label = _cell_labels[i]
		var bi := _bag_page * BAG_PAGE + i        # 视图格 → 真实包裹序号
		if bi < _state.bag.size():
			var e: Dictionary = _state.bag[bi]
			var sid := str(e.get("set", ""))
			var kind := str(e.get("kind", "card"))
			var is_ready := false
			if kind == "card":
				is_ready = synthables.has(sid)
			var nm2: String = str(_state.card_label(e))
			UiKit.set_text(lb, nm2)
			if i < _cell_icons.size():
				# 先按 id（准），配不上再按名字兜一层
				var ic_tex := ItemArt.icon_for_set(sid)
				if ic_tex == null:
					ic_tex = ItemArt.icon_for_name(nm2)
				_cell_icons[i].texture = ic_tex
			if kind == "item":
				lb.add_theme_color_override("font_color", UiKit.SEAL)
			else:
				lb.add_theme_color_override("font_color", UiKit.INK)
			cell.add_theme_stylebox_override("panel", _cell_box(kind, is_ready))
		else:
			UiKit.set_text(lb, "")
			if i < _cell_icons.size():
				_cell_icons[i].texture = null
			cell.add_theme_stylebox_override("panel", _cell_box("", false))
	# v2：按钮写清"合哪一套、还剩几套"——一按只合一（见 journey_synth_panel.press）
	if synthables.is_empty():
		UiKit.set_btn_text(_synth_btn, "合成（0）")
	else:
		var s0 := str(synthables[0])
		var nm0 := str(Cards.item_name(s0))
		UiKit.set_btn_text(_synth_btn, "合成 " + nm0 + ("　＋" + str(synthables.size() - 1) + " 套" if synthables.size() > 1 else ""))
	_synth_btn.disabled = synthables.is_empty()
	if _page_btn != null:
		UiKit.set_btn_text(_page_btn, "▶\n" + str(_bag_page + 1) + "/" + str(pages))
		_page_btn.disabled = pages <= 1
	_update_tip()


func _bag_page_count() -> int:
	if _state == null:
		return 1
	return maxi(1, int(ceil(float(_state.bag_cap()) / float(BAG_PAGE))))


func _on_bag_page_next() -> void:
	var pages := _bag_page_count()
	if pages <= 1:
		return
	_bag_page = (_bag_page + 1) % pages
	_refresh_bag()


func _cell_box(kind: String, is_ready: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	if kind == "":
		sb.bg_color = Color(1, 1, 1, 0.30)
		sb.border_color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.18)
		sb.set_border_width_all(1)
		return sb
	sb.set_border_width_all(2)
	if kind == "item":
		sb.bg_color = Color(0.95, 0.89, 0.76)
		sb.border_color = UiKit.SEAL
		return sb
	if is_ready:
		sb.bg_color = Color(0.96, 0.87, 0.60)
		sb.border_color = UiKit.GOLD
		return sb
	sb.bg_color = UiKit.PAPER_DARK
	sb.border_color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.40)
	return sb


func _update_tip() -> void:
	if _tip_label == null or _state == null:
		return
	var synthables: Array = _state.ready_sets()
	if _state.bag_full():
		UiKit.set_text(_tip_label, "包裹已满：点包裹里的东西可查看／丢弃／装备")
	elif not synthables.is_empty():
		UiKit.set_text(_tip_label, "有 " + str(synthables.size()) + " 套凑齐了 → 点上面［合成］，合成后选装备或放包裹")
	elif _host._just_synth:
		UiKit.set_text(_tip_label, "成品装好后：功法实战自动放，兵器改普攻招式。点包裹里的东西也能装备／丢弃")
	else:
		UiKit.set_text(_tip_label, "左上角［角色］可开合面板；点包裹里东西可查看／丢弃／装备；凑齐一套（页数随品质）点［合成］")


# ---- 点格：正在"换卡"就先换卡，否则弹详情 ----

func _on_bag_slot(ev: InputEvent, i: int) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	if _state == null:
		return
	var bi := _bag_page * BAG_PAGE + i        # 视图格 → 真实包裹序号
	if bi < 0 or bi >= _state.bag.size():
		return
	if _host._event._do_replace(bi):
		return
	# v34：精英战利满包时也走"点包裹里的东西丢掉"这条路（与事件三选一同一个手感）
	if _host._elite_do_replace(bi):
		return
	_show_card_detail(bi)


# 装备三件套的汉名（⑯：趟内换甲的详情页用）
func _gear_cn(sid: String) -> String:
	var pool := str(Cards.by_id(sid).get("pool", ""))
	if pool == "armor":
		return "护甲"
	if pool == "helm":
		return "玉佩"
	if pool == "cloak":
		return "披风"
	return ""


func _show_card_detail(i: int) -> void:
	if _state == null or i < 0 or i >= _state.bag.size():
		return
	# ㊻：选择页/确认页挂着的时候不许开详情。
	#   这一页一开就会 _close_popup()，把上面那张必须回答的页顶掉——
	#   而它的收尾（_elite_draw_done / _finish_node）再也不会被调到，
	#   _busy 永远挂着 true，连［退出］都只会回"先把手头的事办完"。
	#   正常路径上遮罩已经把包裹盖住了（见 _make_popup_veil(true)），
	#   这里是最后一道保险，防的是以后又有人绕过来调。
	if _host._popup_blocking:
		UiKit.float_text(_host, "先把上面这一页答完", UiKit.SEAL)
		return
	_host._close_popup()
	_host._detail_idx = i
	var e: Dictionary = _state.bag[i]
	var sid := str(e.get("set", ""))
	var is_item: bool = str(e.get("kind", "")) == "item"
	var veil = _host._make_popup_veil()
	var panel := UiKit.make_paper_panel(veil, Rect2(80, JourneyCommon.POPUP_TOP, 560, 452))

	var nm := UiKit.make_label(panel, Vector2(0, 16), Vector2(560, 42), 28, UiKit.INK)
	UiKit.set_text(nm, _state.card_label(e))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var gcn := ""
	if is_item:
		gcn = _gear_cn(sid)
	var kind_txt := ""
	if is_item:
		if Cards.is_arts(sid):
			kind_txt = "武学功法"
		elif gcn != "":
			kind_txt = gcn + "成品"
		else:
			kind_txt = "兵器成品"
	else:
		kind_txt = "武学残页" if Cards.is_arts(sid) else "残缺兵器"
	var qn := Cards.quality_of(sid)
	if qn != "凡品":
		kind_txt += "（" + qn + "）"
	var b: Dictionary = {}
	if is_item:
		# v37：成品显示**含升星**的那份（以前显示表值，升了星也看不出来）
		b = GameState.starred_stats(sid)
	else:
		b = Cards.card_bonus(sid)

	# v60：这一行原来读 Cards.name_of(sid)——那是**残卡套名**（长剑），
	#   而页眉写的是 card_label（成品名青锋剑 / 残卡名长剑·锋）。一页里两个名字，
	#   玩家看着"没合成的碎片"跟"穿上的成品"同名，就以为碎片自己变完整了。
	#   统一走 card_label：成品给成品名、残卡给"套名·页名"。
	var lines := "类别：" + kind_txt + " · " + str(_state.card_label(e)) + GameState.star_marks(sid) + "\n"
	lines += "加成：" + str(Cards.bonus_text(b)) + "\n"
	if is_item:
		var st_n := GameState.star_of(sid)
		lines += ("星级：" + str(st_n) + "/" + str(GameState.STAR_MAX)
			+ ("（每星 +20%，现 ×" + str(snappedf(GameState.star_mul(sid), 0.1)) + "，已算进上面的加成）" if st_n > 0 else "（去［升 星］合星；每星 +20%）") + "\n")

	if not is_item:
		if Cards.is_arts(sid):
			var art: Dictionary = Cards.art_of(sid)
			lines += "合成后：" + str(Cards.bonus_text(GameState.starred_stats(sid))) + "，可装功法栏\n"
			lines += "功法效果：" + str(art.get("desc", "—")) + "\n"
			lines += "招式：" + str(Cards.name_of(sid)) + " · " + str(art.get("move", "")) + "\n"
		else:
			lines += "成品：" + str(Cards.item_name(sid)) + "（" + str(Cards.bonus_text(GameState.starred_stats(sid))) + "）\n"
			lines += "装上后：普攻改用该兵器招式\n"
		var ps: Dictionary = _state.part_status(sid)
		var have: Array = ps.get("have", [])
		var miss: Array = ps.get("miss", [])
		if have.is_empty():
			lines += "本套已有：无\n"
		else:
			lines += "本套已有：" + "、".join(PackedStringArray(have)) + "\n"
		if miss.is_empty():
			lines += "尚缺：齐了，可点［合成］"
		else:
			lines += "尚缺：" + "、".join(PackedStringArray(miss))
	else:
		if Cards.is_arts(sid):
			var art2: Dictionary = Cards.art_of(sid)
			lines += "功法效果：" + str(art2.get("desc", "—")) + "\n"
			lines += "招式：" + str(Cards.name_of(sid)) + "\n"
			if _state.arts.has(sid):
				# v60（用户报的："点击装备提示已装备，但还是空手"）：以前这里只写"已装备"，
				#   玩家点［装备］又拿到"这本已经装备了"——两处都没说"在谁身上、多的这件去哪"，
				#   看着就像按钮坏了、或者这块碎片自己变完整了。改成与兵器/装备那几条
				#   "同款"一个口径，并点出人名。
				lines += "状态：" + str(_host.member_name_of(_state.active_i)) + " 身上已有这门——多的这件留在包裹（结算带进村仓库）"
			else:
				lines += "状态：未装备（点下［装备］）"
		elif gcn != "":
			var slot_c := str(Cards.by_id(sid).get("pool", ""))
			var old_g2 := str(_state.gear_of(slot_c))
			if old_g2 == sid:
				lines += "状态：身上已有同款——这件留在包裹（结算带进村仓库）"
			else:
				lines += "说明：装上后替换身上「" + gcn + "」位；换下的旧件进包裹\n"
				if old_g2 == "":
					lines += "状态：这个位子现在空着（点下［装备］）"
				else:
					lines += "状态：会换下 " + str(Cards.item_name(old_g2)) + "（点下［装备］）"
		else:
			lines += "说明：装上后普攻改用该兵器招式\n"
			if str(_state.weapon_id()) == sid:
				lines += "状态：身上已有同款——这把留在包裹（结算带进村仓库）"
			else:
				lines += "状态：装上即生效（点下［装备］）"

	# v4：正文 16→21（详情里最要紧的那几行）。框 (40,68,480,268) 没动——
	#   21 号下一行 22 个全角字，探针实测最长的一份（武学残页：类别／加成／合成后／
	#   功法效果／招式／本套已有／尚缺）排 8 行、需要 211 ≤ 268，压不到下面 y=372 的按钮。
	var bd := UiKit.make_label(panel, Vector2(40, 68), Vector2(480, 268), 21, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))
	UiKit.set_text(bd, lines)
	bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var btns: Array = []
	if is_item:
		btns.append({"t": "装备", "k": "equip"})
	if _host._shop_active:
		# v4：16→19 之后"卖出 +N 文"在 122 宽的钮里放不下（探针实测：钮内框 102，
		#   全服最长的一笔卖价 200 → "卖出 +200 文"＝111 > 102，会顶出钮外）。
		#   按"字号优先"去掉尾巴那个"文"——盘缠单位全局都是文（顶栏就写着"盘缠 N 文"），
		#   去掉后"卖出 +200"＝87 ≤ 102，再添一位数也仍放得下，钮的尺寸不用动。
		btns.append({"t": "卖出 +" + str(_state.price_of(e)), "k": "sell"})
	btns.append({"t": "丢弃", "k": "drop"})
	btns.append({"t": "关闭", "k": "close"})

	var n: int = btns.size()
	var bw := 122.0
	var gap := 12.0
	var total := float(n) * bw + float(maxi(n - 1, 0)) * gap
	var x0 := (560.0 - total) * 0.5
	for k in n:
		var a: Dictionary = btns[k]
		# v4：钮上字 16→19（122×54 的钮装得下两三个全角字＋号）
		var btn := UiKit.make_button(panel, Vector2(x0 + float(k) * (bw + gap), 372), Vector2(bw, 54), str(a.get("t", "确定")), 19)
		btn.pressed.connect(_on_detail_action.bind(str(a.get("k", "close"))))


func _on_detail_action(k: String) -> void:
	var i: int = _host._detail_idx
	if _state == null or i < 0 or i >= _state.bag.size():
		_host._close_popup()
		return
	var e: Dictionary = _state.bag[i]
	if k == "drop":
		_state.bag.remove_at(i)
		_host._close_popup()
		_host._refresh_all()
		UiKit.float_text(_host, "已丢弃", UiKit.SEAL)
		if _host._shop_active:
			_host._shop._show_shop()
		return
	if k == "sell":
		var sp: int = int(_state.price_of(e))
		_state.money += sp
		_state.bag.remove_at(i)
		_host._close_popup()
		_host._refresh_all()
		UiKit.float_text(_host, "卖出 +" + str(sp) + " 文", UiKit.GOLD)
		if _host._shop_active:
			_host._shop._show_shop()
		return
	if k == "equip":
		# ㊿w：多人趟里先问"这件给谁"——单人趟 ask_member 直接回调 0，跟以前一样
		_host.ask_member(str(e.get("set", "")), "这件给谁穿", _do_equip.bind(i))
		return
	_host._close_popup()

# ㊿w：选完人之后真装（**mi＝队伍成员下标在前，i＝包裹下标在后**）
# ⚠ **参数顺序别改**：Godot 的 Callable.bind() 把绑定参数**接在调用参数后面**——
#   ask_member 里是 on_pick.call(mi)，配上 _do_equip.bind(i) 实际调用的就是
#   `_do_equip(mi, i)`。写成 (i, mi) 时两个都是 int，**不会报错**，
#   只会把"包裹第几个"和"给谁"对调——装错件、装错人，静默出错最难查。
#   （合成页那条路第一参是 String，写反了当场报类型错、页面卡住，见
#    journey_synth_panel._place_for 的同名注释。）
# ㊿w 补刀（用户报的："包裹出问题了，点击装备提示已装备，但还是空手"）：
#   病根——多人趟里［装备］先问"这件给谁穿"，件是穿在 **mi** 身上的；
#     而角色面板（兵器行/属性/功法）与路上的小人都画 **active_i** 那位。
#     玩家点的那一行若不是他正看着的人（选人页以前还只写"成员1／成员2"，认不出谁是谁），
#     穿完面板与小人一动不动——看上去就是"说了装上了、人还空手"。
#   口径：**谁收到这件，就把镜头切给谁**（跟面板右上角那三个切换钮同一条路：
#     use_member ＋ _refresh_all），飘字里也点出名字，两处一起改这坑才算填上。
#     单人趟没有这一层（成员≤1 时不切，老样子）。
func _do_equip(mi: int, i: int) -> void:
	var msg: String = str(_state.equip_from_bag_for(mi, i))
	if msg != "":
		_host._close_popup()
		if _state.members.size() > 1:
			_state.use_member(mi)
			msg = str(_host.member_name_of(mi)) + "：" + msg
		_host._refresh_all()
		UiKit.float_text(_host, msg, UiKit.SEAL)
		if _host._shop_active:
			_host._shop._show_shop()


# ---- 舞台显隐接线（原舞台直接点 _bag_panel / _synth_btn / _tip_label 的地方） ----

func set_ui_visible(v: bool) -> void:
	_bag_panel.visible = v
	_synth_btn.visible = v
	_tip_label.visible = v


func bring_panel_front() -> void:
	if _bag_panel != null:
		_bag_panel.move_to_front()
