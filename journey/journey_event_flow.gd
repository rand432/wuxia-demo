extends RefCounted
# ============================================================
# journey_event_flow.gd —— 事件三选一件 v5b（签摊不下架：多拿要钱 ＋ ［不选了］）
# v5b（用户："涨价太狠了 就 40 60 80 这样子就好了"）：价目 40/80/120 → **40/60/80**（一张加 20 文）。
# v5（用户："我说的是节点 每走一步不是三选一吗 选完之后就消失吗 现在改为不消失
#   选第二个第三个需要钱 【加个不选了的按钮】"）：
#   以前**拿一张整页就收掉**（_finish_node），剩下两张白作废。现在：
#     · 拿完一张，签面**留着**——那张下架，其余照摆（点一下就是再拿一张）；
#     · **第一张照旧白拿**，第二张起要文钱（价按"已经拿了几张"走，见 PICK_PRICE）；
#     · 盘缠不够就不给拿（这一页不收，等玩家改主意），底排多一颗 **［不选了］** ＝ 收摊赶路；
#     · 拿光了自动收摊；刷新（10 文）照旧一轮一次（价目不清零——拿得越多越贵）。
#   ⚠ 精英战利那三抽（journey_stage._open_elite_draw）**不在这一页**，一个字没动
#     （用户："【精英三选一不算】"）。
# v4（优化批⑥/#8）：三选一页给卡加标注——包里已有同一张（同组同页）＝卡下标
#   "已有一张（重复）"；收下就凑齐整套＝描金边＋"收下即齐！"。只标注，不动出卡/刷新规则。
# v3（R4 门面批）：三选一（含刷新）改从现役卡池出（GameState.pool_active）——
#   越阶"红"只走搜刮，不进事件；刷新仍 10 文。
# v2（R3 货价批）：满包折现改按品级计价（cashout_price）——按钮与文案跟随。
# v1（拆件批）：拆分自 journey_stage v20 的：_event_offer_count / _open_event / _show_event_cards /
# _preview_card / _confirm_pick / _on_card_picked / _on_refresh_pressed /
# _enter_replace_mode / _on_cashout_pressed / _on_replace_back / _do_replace。
# 逐字搬运、零逻辑改；与舞台的接口：
#   _open_event(node) / _reset()
#   _do_replace(i) -> bool（包裹件点格时先问这里：true = 已按"换卡"处理，不弹详情）
# 不引 journey_stage（防循环——老铁律）。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const GameState := preload("res://shared/game_state.gd")
const JourneyCommon := preload("res://journey/journey_common.gd")
const UiKit := preload("res://shared/ui_kit.gd")

var _host = null
var _state = null

var _node: Dictionary = {}
var _pending_offer: Array = []
var _refresh_used := false
var _replace_pending: Dictionary = {}
var _taken := 0               # v5：这一节已经拿了几张（决定下一张的价，也决定还有没有得拿）

# v5：拿第 N 张的价（下标＝**已经拿了几张**：0 张时免费，之后 40 / 60 / 80）。
#   v5b（用户："这个涨价太狠了 就 40 60 80 这样子就好了"）：原来是 40/80/120（每张翻倍），
#   现在一张加 20 文。仍贵过"折现/卖店"，但远低于补齐价（80×品级系数）。
const PICK_PRICE := [0, 40, 60, 80]


func setup(host) -> void:
	_host = host
	_state = host._state


func _reset() -> void:
	_pending_offer = []
	_replace_pending = {}
	_taken = 0
	_refresh_used = false

# v5：下一张要多少文（0 ＝ 白拿）
func _pick_price() -> int:
	var i: int = clampi(_taken, 0, PICK_PRICE.size() - 1)
	return int(PICK_PRICE[i])


func _event_offer_count() -> int:
	if _state.has_talent("贵人相助"):
		return 4
	return 3


func _open_event(node: Dictionary) -> void:
	_host._busy = true
	_refresh_used = false
	_taken = 0
	_host._cur_node = node
	_node = node
	var pool := str(node.get("pool", "arts"))
	# ㉛：统一走 pick_pool——事件三选一也只出现在现阶段的品级内（越阶只留给搜刮）
	_pending_offer = Cards.random_offer_from(GameState.pick_pool(pool), _event_offer_count())
	_show_event_cards()


func _show_event_cards() -> void:
	_host._close_overlay()
	var veil = _host._make_veil(0.52)
	# v54（玩家反馈："选卡字体还是太小了"）：470 → 500 高（底排按钮放大之后要地方）
	var panel := UiKit.make_paper_panel(veil, Rect2(20, JourneyCommon.POPUP_TOP, 680, 500))

	var title := UiKit.make_label(panel, Vector2(0, 20), Vector2(680, 44), 32, UiKit.INK)
	UiKit.set_text(title, str(_node.get("title", "事件")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var n: int = _pending_offer.size()
	var cw := 200.0
	var hug := 20.0
	if n >= 4:
		cw = 150.0
		hug = 10.0
	var total := float(n) * cw + float(maxi(n - 1, 0)) * hug
	var x0 := (680.0 - total) * 0.5
	for i in n:
		var card: Dictionary = _pending_offer[i]
		var b := JourneyCommon.make_card_button(card, cw, 270.0)
		b.position = Vector2(x0 + float(i) * (cw + hug), 88.0)
		b.pressed.connect(_preview_card.bind(card))
		panel.add_child(b)
		# 优化批⑥（#8）：重复＝灰字提示；"收下即齐"＝描金边＋金字
		var hint := _offer_hint(card)
		if hint == "complete":
			var halo := Panel.new()
			halo.position = b.position
			halo.size = b.size
			halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var hs := StyleBoxFlat.new()
			hs.bg_color = Color(0, 0, 0, 0)
			hs.set_corner_radius_all(10)
			hs.set_border_width_all(3)
			hs.border_color = UiKit.GOLD
			halo.add_theme_stylebox_override("panel", hs)
			panel.add_child(halo)
			var lb := UiKit.make_label(panel, Vector2(b.position.x, 362.0), Vector2(cw, 28), 18, UiKit.GOLD)
			UiKit.set_text(lb, "收下即齐！")
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif hint == "dup":
			var lb2 := UiKit.make_label(panel, Vector2(b.position.x, 362.0), Vector2(cw, 28), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.55))
			UiKit.set_text(lb2, "已有一张（重复）")
			lb2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb2.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rb := UiKit.make_button(panel, Vector2(20, 404), Vector2(150, 52), "刷新（10 文）", 19)
	if _refresh_used:
		UiKit.set_btn_text(rb, "已刷新")
		rb.disabled = true
	elif _state.money < 10:
		rb.disabled = true
	rb.pressed.connect(_on_refresh_pressed)

	# v5：［不选了］——这一页的正门出口。以前"拿一张就自动收摊"，根本没有"够了"这个动作。
	var dn := UiKit.make_button(panel, Vector2(180, 404), Vector2(150, 52), "不选了", 21)
	dn.pressed.connect(_leave_event)

	var mid := UiKit.make_label(panel, Vector2(336, 404), Vector2(200, 52), 17, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.62))
	UiKit.set_text(mid, _row_status_text())
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mid.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var hl := UiKit.make_label(panel, Vector2(540, 404), Vector2(124, 52), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.70))
	UiKit.set_text(hl, "包裹 " + str(_state.bag.size()) + "/" + str(_state.bag_cap()))
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

# v5：底排那句状态——第一张白拿，之后写明"再拿要多少文、盘缠够不够"
func _row_status_text() -> String:
	if _pending_offer.is_empty():
		return "签面拿光了"
	var p := _pick_price()
	if p <= 0:
		return "第一张不要钱"
	var tail := "" if _state.money >= p else "（盘缠不够）"
	return "已拿 " + str(_taken) + " 张\n再拿 " + str(p) + " 文" + tail

# v5：收摊赶路——［不选了］与"签面拿光"都走这里（正好一次 _finish_node）
func _leave_event() -> void:
	_pending_offer = []
	_replace_pending = {}
	_host._close_overlay()
	_host._finish_node("event")

# v5：把一张从签面上摘掉（同组同页只摘一张）
func _drop_offer(card: Dictionary) -> void:
	var sid := str(card.get("set_id", ""))
	var part := int(card.get("part", 0))
	var rest: Array = []
	for c_v in _pending_offer:
		var c2: Dictionary = c_v
		if str(c2.get("set_id", "")) == sid and int(c2.get("part", 0)) == part:
			continue
		rest.append(c2)
	_pending_offer = rest

# v5：拿到一张之后——那张下架、**其余的照摆**，价按张数涨
func _after_take(card: Dictionary, quiet := false) -> void:
	_taken += 1
	_drop_offer(card)
	_host._refresh_all()
	if not quiet:
		UiKit.float_text(_host, "收下 " + str(Cards.card_name(str(card.get("set_id", "")), int(card.get("part", 0)))), UiKit.INK)
	if _pending_offer.is_empty():
		_leave_event()
		return
	_show_event_cards()


# 优化批⑥（#8）：给出卡提示——"dup"＝同组同页已有一张；"complete"＝收下就凑齐
func _offer_hint(card: Dictionary) -> String:
	if _state == null:
		return ""
	var sid := str(card.get("set_id", ""))
	var part := int(card.get("part", 0))
	var m: Dictionary = _state.count_cards()
	var mine: Dictionary = {}
	if m.has(sid):
		mine = m[sid]
	if int(mine.get(part, 0)) > 0:
		return "dup"
	var parts: Array = Cards.parts_of(sid)
	if parts.is_empty():
		return ""
	var missing := 0
	for i in parts.size():
		var cnt := int(mine.get(i, 0))
		if i == part:
			cnt += 1
		if cnt <= 0:
			missing += 1
	if missing == 0:
		return "complete"
	return ""


# ---- 三选一：先看说明，再确认 ----
func _preview_card(card: Dictionary) -> void:
	var sid := str(card.get("set_id", ""))
	var part := int(card.get("part", 0))
	var is_arts := Cards.is_arts(sid)
	var parts: Array = Cards.parts_of(sid)
	var m: Dictionary = _state.count_cards()
	var mine: Dictionary = {}
	if m.has(sid):
		mine = m[sid]
	var have: Array = []
	var miss: Array = []
	for i in parts.size():
		var cnt := int(mine.get(i, 0))
		if i == part:
			cnt += 1
		if cnt > 0:
			have.append(str(parts[i]))
		else:
			miss.append(str(parts[i]))

	var body := ""
	if is_arts:
		var art: Dictionary = Cards.art_of(sid)
		body += "加成：" + str(Cards.bonus_text(Cards.card_bonus(sid))) + "（合成后可装备）\n"
		if Cards.cat_of(sid) != "":
			body += "归类：" + Cards.cat_name(Cards.cat_of(sid)) + "\n"
		body += "功法效果：" + str(art.get("desc", "—")) + "\n"
		body += "招式：『" + str(Cards.name_of(sid)) + "』" + str(art.get("move", "")) + "\n"
	else:
		body += "加成：" + str(Cards.bonus_text(Cards.card_bonus(sid))) + "（合成后可装备）\n"
		body += "成品：" + str(Cards.item_name(sid)) + "（" + str(Cards.bonus_text(Cards.item_bonus(sid))) + "）\n"
		body += "装备后普攻改用该兵器招式\n"
	if have.is_empty():
		body += "本套已有：无\n"
	else:
		body += "本套已有：" + "、".join(PackedStringArray(have)) + "\n"
	if miss.is_empty():
		body += "收下后三张齐了，可直接合成"
	else:
		body += "尚缺：" + "、".join(PackedStringArray(miss))
	if _state.bag_full():
		body += "\n（包裹已满：收下要先舍一件）"

	_host._close_popup()
	var veil = _host._make_popup_veil()
	# v54：440 → 500 高（正文 16 → 21）
	var panel := UiKit.make_paper_panel(veil, Rect2(80, JourneyCommon.POPUP_TOP, 560, 500))

	var head := UiKit.make_label(panel, Vector2(0, 16), Vector2(560, 28), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.55))
	UiKit.set_text(head, "看清了再拿")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var nm := UiKit.make_label(panel, Vector2(0, 42), Vector2(560, 42), 27, UiKit.INK)
	UiKit.set_text(nm, str(Cards.card_name(sid, part)))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bd := UiKit.make_label(panel, Vector2(40, 100), Vector2(480, 300), 21, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))
	UiKit.set_text(bd, body)
	bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var ok := UiKit.make_button(panel, Vector2(139, 420), Vector2(140, 60), "收下", 22)
	ok.pressed.connect(_confirm_pick.bind(card))
	var back := UiKit.make_button(panel, Vector2(287, 420), Vector2(140, 60), "返回", 22)
	back.pressed.connect(_host._close_popup)


func _confirm_pick(card: Dictionary) -> void:
	_host._close_popup()
	_on_card_picked(card)


func _on_card_picked(card: Dictionary) -> void:
	var sid := str(card.get("set_id", ""))
	var part := int(card.get("part", 0))
	# v5：第二张起要钱——盘缠不够就不给拿（**这一页不收**，玩家可以改主意或点［不选了］）
	var price := _pick_price()
	if price > 0 and _state.money < price:
		UiKit.float_text(_host, "再拿一张要 " + str(price) + " 文——盘缠不够", UiKit.SEAL)
		_show_event_cards()
		return
	if _state.bag_full():
		_enter_replace_mode(card)
		return
	if price > 0:
		_state.money -= price
		_host._money()
	_state.add_card(sid, part)
	# 第一次收下时那句"包裹在哪"的提示照旧；不然与浮动字撞在一起
	var first: bool = not bool(_host._told_card)
	if first:
		_host._told_card = true
		UiKit.float_text(_host, "收下了：点右上角包裹里的东西可查看／丢弃", UiKit.INK)
	_after_take(card, first)


func _on_refresh_pressed() -> void:
	if _refresh_used or _state.money < 10:
		return
	_state.money -= 10
	_host._money()
	_refresh_used = true
	var pool := str(_node.get("pool", "arts"))
	# ㉛：统一走 pick_pool——事件三选一也只出现在现阶段的品级内（越阶只留给搜刮）
	_pending_offer = Cards.random_offer_from(GameState.pick_pool(pool), _event_offer_count())
	_show_event_cards()


# ============ 满包：替换 / 折现 ============

func _enter_replace_mode(card: Dictionary) -> void:
	_replace_pending = card
	_host._close_overlay()
	var veil = _host._make_veil(0.52)
	var panel := UiKit.make_paper_panel(veil, Rect2(110, JourneyCommon.POPUP_TOP, 500, 400))

	var title := UiKit.make_label(panel, Vector2(0, 24), Vector2(500, 44), 30, UiKit.INK)
	UiKit.set_text(title, "包裹已满")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var cp: int = int(_state.cashout_price(str(card.get("set_id", ""))))
	var body := UiKit.make_label(panel, Vector2(30, 82), Vector2(440, 176), 21, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.88))
	UiKit.set_text(body, "收下「" + str(Cards.card_name(str(card.get("set_id", "")), int(card.get("part", 0)))) + "」得先舍掉一件：点右上角包裹里的东西丢掉（换回些盘缠），或者把这张新的折现 " + str(cp) + " 文。")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var b1 := UiKit.make_button(panel, Vector2(50, 296), Vector2(200, 56), "折现（+" + str(cp) + " 文）", 20)
	b1.pressed.connect(_on_cashout_pressed)
	var b2 := UiKit.make_button(panel, Vector2(264, 296), Vector2(186, 56), "返回", 21)
	b2.pressed.connect(_on_replace_back)


func _on_cashout_pressed() -> void:
	var card: Dictionary = _replace_pending
	var cp: int = int(_state.cashout_price(str(card.get("set_id", ""))))
	_state.money += cp
	_replace_pending = {}
	UiKit.float_text(_host, "折现 +" + str(cp) + " 文", UiKit.GOLD)
	# v5：折现＝这一张不要了——它下架，其余照摆（整页不再收摊）
	_drop_offer(card)
	_host._refresh_all()
	if _pending_offer.is_empty():
		_leave_event()
		return
	_show_event_cards()


func _on_replace_back() -> void:
	_replace_pending = {}
	_show_event_cards()


# 包裹件点格时先问这里：正在"换卡"就替它处理（true=已处理，不弹详情）
func _do_replace(i: int) -> bool:
	if _replace_pending.is_empty():
		return false
	if _state == null or i < 0 or i >= _state.bag.size():
		return true
	var e: Dictionary = _state.bag[i]
	var sp: int = int(_state.price_of(e))
	_state.money += sp
	_state.bag.remove_at(i)
	var card: Dictionary = _replace_pending
	_replace_pending = {}
	_state.add_card(str(card.get("set_id", "")), int(card.get("part", 0)))
	UiKit.float_text(_host, "+" + str(sp) + " 文", UiKit.GOLD)
	# v5：换进来的这一张也算"拿了"——照走"下架＋其余照摆"那条路
	_after_take(card, true)
	return true
