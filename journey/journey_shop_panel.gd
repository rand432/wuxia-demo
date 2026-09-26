extends RefCounted
# ============================================================
# journey_shop_panel.gd —— 货郎担件 v3（优化批㉔：运签上架）
# v3：货架加「运签」——普通/特殊/专属（按本趟角色出）；花文钱请，只这趟生效；
#   刷新（10 文）一并购新签；已挂清单摊上可见。（顺手清掉首行"journey_sho"残字）
# v2（R3 货价批）：货架价 = 基价×品级系数（run_state 侧算好）；补齐价动态（fix_price）；
#   提示行改报品级卖价区间（sell_range_text）。系数初值见 data_cards.PRICE_MUL。
# v1（拆件批）：拆分自 journey_stage v20 的：_open_shop / _show_shop / DropPanel / on_shop_drop /
# _on_shop_buy / _on_shop_fix / _on_shop_refresh / _on_shop_leave。
# 逐字搬运、零逻辑改；与舞台的接口：
#   _open_shop() / _show_shop() / _reset() / _on_shop_drop(bag_index)
# （DropPanel 逐字不动、仍认舞台——所以新 stage 会保留 _shop_active 与
#  on_shop_drop 转发口，这两样是给 DropPanel 的接口，别删。）
# 不引 journey_stage（防循环——老铁律）。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const Buffs := preload("res://shared/data_buffs.gd")
const JourneyCommon := preload("res://journey/journey_common.gd")
const UiKit := preload("res://shared/ui_kit.gd")


# ---- 商店纸面：接住拖来的东西 = 卖出（原 journey_stage.DropPanel，逐字搬） ----
class DropPanel extends Panel:
	var stage_ref: Node = null

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if stage_ref == null or not is_instance_valid(stage_ref):
			return false
		if not (data is Dictionary):
			return false
		return data.has("bag_index") and bool(stage_ref._shop_active)

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if stage_ref == null or not is_instance_valid(stage_ref):
			return
		stage_ref.on_shop_drop(int(data["bag_index"]))


var _host = null
var _state = null

var _offers: Array = []
var _fix: Dictionary = {}
var _buff_offers: Array = []


func setup(host) -> void:
	_host = host
	_state = host._state


func _reset() -> void:
	_offers = []
	_fix = {}
	_buff_offers = []


func _open_shop() -> void:
	_host._busy = true
	_host._shop_active = true
	_host._cur_node = _host._nodes[_host._node]
	_offers = _state.make_shop_offers(_host._node)
	_fix = _state.missing_card()
	# ㉞：签面与左上［运签］共用同一份——都存舞台（空才摇）
	# ㊿u：带上"这趟在阵的这几个人"——主人没来，他的专属卡不上货架
	if _host._buff_offers.is_empty():
		_host._buff_offers = Buffs.roll_offers(str(_state.role_id), 3, _state.party_role_ids())
	_buff_offers = _host._buff_offers
	_show_shop()


func _show_shop() -> void:
	_host._close_overlay()
	_host._shop_active = true
	var veil = _host._make_veil(0.52)
	var panel := DropPanel.new()
	panel.stage_ref = _host
	panel.position = Vector2(20, JourneyCommon.POPUP_TOP)
	# v54（玩家反馈："游历的商店字体还是太小了"）：面板从 620 加到 700，字号整体上调、
	#   行距跟着重排（下面每一行的 y 都按新字号挪过，注释里写清）。
	panel.size = Vector2(680, 700)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UiKit.paper_box(0.97))
	veil.add_child(panel)

	var title := UiKit.make_label(panel, Vector2(0, 14), Vector2(680, 48), 32, UiKit.INK)
	UiKit.set_text(title, "货郎担子")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for i in _offers.size():
		var o: Dictionary = _offers[i]
		var x := 30.0 + float(i) * 160.0
		var b := JourneyCommon.make_card_button(o, 140.0, 190.0)
		b.position = Vector2(x, 72.0)
		# ㉜：点卡片＝先看说明，再决定买不买（以前是点一下就扣钱买走，
		#   买错了只能再卖回去，一进一出亏一半）
		b.pressed.connect(_preview_offer.bind(i))
		panel.add_child(b)
		var price := int(o.get("price", 40))
		# v54：价格 17 → 22
		var pl := UiKit.make_label(panel, Vector2(x, 266.0), Vector2(140.0, 30.0), 22, UiKit.INK)
		UiKit.set_text(pl, str(price) + " 文")
		if _state.money < price:
			pl.add_theme_color_override("font_color", UiKit.SEAL)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# v54：这一行原来是 14 号单行——14 号在 720 宽上根本看不清。现在 19 号 + 自动换行两行，
	#   所以框给到 66 高，后面的按钮整体往下挪（326 → 372）。
	var hint := UiKit.make_label(panel, Vector2(20, 300), Vector2(640, 66), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.68))
	UiKit.set_text(hint, "点卡片先看说明再买；把包裹里的东西拖到这张纸上即卖出（按品级计价：" + str(_state.sell_range_text()) + "）；点开卡也有［卖出］")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var fb := UiKit.make_button(panel, Vector2(20, 372), Vector2(640, 52), "补齐", 21)
	if _fix.is_empty():
		UiKit.set_btn_text(fb, "补齐：眼下不缺什么")
		fb.disabled = true
	else:
		var fix_p: int = int(_state.fix_price(str(_fix.get("set", ""))))
		UiKit.set_btn_text(fb, "补齐：" + str(Cards.card_name(str(_fix.get("set", "")), int(_fix.get("part", 0)))) + " —— " + str(fix_p) + " 文")
		fb.disabled = _state.money < fix_p
	fb.pressed.connect(_on_shop_fix)

	var sep2 := ColorRect.new()
	sep2.color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.20)
	sep2.position = Vector2(20, 436)
	sep2.size = Vector2(640, 2)
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sep2)

	# v54：16 → 20
	var bh := UiKit.make_label(panel, Vector2(20, 444), Vector2(640, 30), 20, UiKit.INK)
	UiKit.set_text(bh, "卡组（增益）——花文钱请一卡：只在这趟里生效，带不出去")

	# ㊿：摆位用 vis2 而不是 i2——跳过封顶的卡时 i2 还在涨，直接用 i2 会在
	#   货架左边留个空洞（买/看说明绑的仍是真下标 i2，所以下标不能动）。
	var vis2 := 0
	for i2 in _buff_offers.size():
		var bid := str(_buff_offers[i2])
		var bd2: Dictionary = Buffs.of(bid)
		# ㊿：封顶的卡（回气卡第 2 张之类）不再摆上架——请了也不再更强，摆着只是坑钱。
		#   判据在 data_buffs.USEFUL_COPIES。
		if Buffs.cap_hint(bid, _buff_owned(bid)) != "":
			continue
		var price2 := int(bd2.get("price", 40))
		var bx := 20.0 + float(vis2) * 216.0
		# ㊿：专属卡在卡面上就写明是**谁的**（以前只写"专属卡"，三张长得一样分不出）
		var own2 := Buffs.owner_note(str(bid))
		var line2 := str(bd2.get("name", bid)) + ("｜" + own2 if own2 != "" else "") + "\n" + str(price2) + " 文 · " + Buffs.kind_cn(bid)
		if _state.money < price2:
			line2 += "（钱不够）"
		# v54：卡面 15 → 18，按钮也跟着加高（58 → 66）
		var bb := UiKit.make_button(panel, Vector2(bx, 478), Vector2(206, 66), line2, 18)
		# ㊿：**点卡面＝先看说明，再决定请不请**——跟上面那排装备卡一个规矩（装备早就是
		#   ㉜ 那套"先看再买"，只有这一排运签还是一碰就扣钱，看不到效果）。
		#   ⚠ 卡面**不能** disable：disable 的按钮不响 pressed，钱不够的人就永远看不到
		#   这张卡是干什么的（想看看再攒钱都不行）。买不动由说明页里的按钮把关。
		bb.pressed.connect(_preview_buff.bind(i2))
		vis2 += 1
	if vis2 == 0:
		# v54：15 → 19
		var be := UiKit.make_label(panel, Vector2(20, 496), Vector2(640, 34), 19, UiKit.DIM)
		UiKit.set_text(be, "（架上的卡都请光了、或都到封顶了——刷新一次会换新卡）")

	# ㊿：这一行原来是一行不换行的长句——卡一多就冲出纸面（"只看得见五六张"）。
	#   改成自动换行两行，再把它往下挪一点、给下面的按钮让位。
	# v54：13 → 18，框给到 60 高（两行）
	var own := UiKit.make_label(panel, Vector2(20, 556), Vector2(640, 60), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.72))
	UiKit.set_text(own, "已请（" + str(_state.buff_count()) + " 张，生效中）：" + _state.buff_lines())
	own.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# v54：按钮跟着加高（44 → 52）与放大（18/20 → 21/22）
	var rb := UiKit.make_button(panel, Vector2(20, 626), Vector2(220, 52), "刷新（10 文）", 21)
	rb.disabled = _state.money < 10
	rb.pressed.connect(_on_shop_refresh)

	var lb := UiKit.make_button(panel, Vector2(510, 622), Vector2(150, 56), "确定", 22)
	lb.pressed.connect(_on_shop_leave)


# 舞台 on_shop_drop 转发到这里（DropPanel 的落点，名字别改）
func _on_shop_drop(bag_index: int) -> void:
	if not _host._shop_active:
		return
	if bag_index < 0 or bag_index >= _state.bag.size():
		return
	var e: Dictionary = _state.bag[bag_index]
	var sp: int = int(_state.price_of(e))
	_state.money += sp
	_state.bag.remove_at(bag_index)
	_host._refresh_all()
	UiKit.float_text(_host, "卖出 +" + str(sp) + " 文", UiKit.GOLD)
	_show_shop()


# ============================================================
# ㉜ 先看再买：点货架上的卡 → 弹说明页 → ［买下］/［再看看］
# 说明里除了卡本身的加成，还报"手上这套已有哪几片"，并提醒成品装上去会顶掉
# 当前那件（免得买完才发现是重复或更差的）。
# ============================================================
func _preview_offer(i: int) -> void:
	if i < 0 or i >= _offers.size():
		return
	var o: Dictionary = _offers[i]
	var sid := str(o.get("set_id", ""))
	var part := int(o.get("part", 0))
	var price := int(o.get("price", 40))
	var parts: Array = Cards.parts_of(sid)
	var m: Dictionary = _state.count_cards()
	var mine: Dictionary = {}
	if m.has(sid):
		mine = m[sid]
	var have: Array = []
	var miss: Array = []
	for k in parts.size():
		var cnt := int(mine.get(k, 0))
		if k == part:
			cnt += 1
		if cnt > 0:
			have.append(str(parts[k]))
		else:
			miss.append(str(parts[k]))

	var body := ""
	body += "品级：" + str(Cards.quality_of(sid)) + "　·　这是第 " + str(part + 1) + "/" + str(parts.size()) + " 片\n"
	body += "碎片加成：" + str(Cards.bonus_text(Cards.card_bonus(sid))) + "\n"
	if Cards.is_arts(sid):
		var art: Dictionary = Cards.art_of(sid)
		body += "成品：" + str(Cards.item_name(sid)) + "（功法）\n"
		body += "功法效果：" + str(art.get("desc", "—")) + "\n"
	else:
		body += "成品：" + str(Cards.item_name(sid)) + "（" + str(Cards.bonus_text(Cards.item_bonus(sid))) + "）\n"
		# 提醒：装上会顶掉现在身上那件
		var slot := str(Cards.by_id(sid).get("pool", ""))
		var cur := ""
		if slot == "weapon":
			cur = str(_state.weapon_id())
		else:
			cur = str(_state.gear_of(slot))
		if cur != "":
			# v60：身上那件的名字走 item_name（成品名）——name_of 是残卡套名，两套名字会打架
			body += "现在身上：" + str(Cards.item_name(cur)) + "——装配后会换下它\n"
	if have.is_empty():
		body += "本套已有：无\n"
	else:
		body += "本套已有：" + "、".join(PackedStringArray(have)) + "\n"
	if miss.is_empty():
		body += "买下这套就齐了，可直接合成"
	else:
		body += "还缺：" + "、".join(PackedStringArray(miss))
	if _state.bag_full():
		body += "\n（包裹已满：买下要先舍一件）"

	_host._close_popup()
	var veil = _host._make_popup_veil()
	# v54：说明页 460 → 560 高（正文字号 16 → 21，行数没变但每行更高）
	var panel := UiKit.make_paper_panel(veil, Rect2(80, JourneyCommon.POPUP_TOP, 560, 560))

	var head := UiKit.make_label(panel, Vector2(0, 16), Vector2(560, 28), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.55))
	UiKit.set_text(head, "看清楚了再买")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var nm := UiKit.make_label(panel, Vector2(0, 48), Vector2(560, 46), 28, UiKit.INK)
	UiKit.set_text(nm, str(Cards.card_name(sid, part)))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# v54：正文 16 → 21（最该看清的就是这一段）
	var bd := UiKit.make_label(panel, Vector2(36, 104), Vector2(488, 330), 21, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))
	UiKit.set_text(bd, body)
	bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var afford: bool = _state.money >= price and not _state.bag_full()
	var ok := UiKit.make_button(panel, Vector2(110, 470), Vector2(170, 60), "买下（" + str(price) + " 文）", 20)
	UiKit.set_btn_text(ok, "买下（" + str(price) + " 文）")
	ok.disabled = not afford
	ok.pressed.connect(_buy_from_preview.bind(i))
	var back := UiKit.make_button(panel, Vector2(300, 470), Vector2(150, 60), "再看看", 22)
	back.pressed.connect(_close_preview)

	var why := ""
	if _state.bag_full():
		why = "包裹满了——先舍一件再来"
	elif _state.money < price:
		why = "钱不够（现有 " + str(_state.money) + " 文）"
	if why != "":
		# v54：15 → 19
		var wl := UiKit.make_label(panel, Vector2(0, 438), Vector2(560, 30), 19, UiKit.SEAL)
		UiKit.set_text(wl, why)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _buy_from_preview(i: int) -> void:
	# 先收弹窗，再走原来的买入口（它会自己重画货架）
	_host._close_popup()
	_on_shop_buy(i)


# ============================================================
# ㊿ 运签也"先看再请"：点货架上那张签名 → 说明页 → ［请这张］/［再看看］
#   以前这一排是直接扣钱（看不到效果、也看不到是不是已经请过），
#   而隔壁装备卡早就能先看了——两边现在一个规矩。
# ============================================================
func _preview_buff(i: int) -> void:
	if i < 0 or i >= _buff_offers.size():
		return
	var bid := str(_buff_offers[i])
	var bd: Dictionary = Buffs.of(bid)
	var price := int(bd.get("price", 40))
	var excl := str(bd.get("kind", "")) == "exclusive"
	var owned := _buff_owned(bid)

	var body := "类型：" + Buffs.kind_cn(bid)
	if excl:
		body += "　·　" + Buffs.owner_note(bid) + "（只对他出力）"
	body += "\n"
	body += "效果：" + str(bd.get("desc", "")) + "\n"
	body += "已请：×" + str(owned) + "\n"
	# 普通/特殊可以重复请（叠着生效）；专属每趟限一张
	if excl and owned > 0:
		body += "同一张专属卡每趟只能请一次——这张已经请过了。\n"
	else:
		body += "只在这趟里生效；不进包裹、带不出去。\n"
	# ㊿：这一张（或这一排里的别的卡）已经到封顶张数时，直说"再请不会更强"
	var hin := Buffs.cap_hint(bid, owned)
	if hin != "":
		body += "⚠ " + hin + "。\n"
	if excl:
		body += "专属只对卡上写的那个人生效（别人请了不出力）。"
	else:
		body += "普通/特殊对全队生效，可以重复请、叠着生效（标注了封顶的除外）。"
	body += "\n现有 " + str(_state.money) + " 文。"

	_host._close_popup()
	var veil = _host._make_popup_veil()
	# v54：运签说明页 440 → 540 高（正文 16 → 21）
	var panel := UiKit.make_paper_panel(veil, Rect2(90, JourneyCommon.POPUP_TOP, 540, 540))

	var head := UiKit.make_label(panel, Vector2(0, 16), Vector2(540, 28), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.55))
	UiKit.set_text(head, "看清楚了再请")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var nm := UiKit.make_label(panel, Vector2(0, 48), Vector2(540, 46), 28, UiKit.INK)
	UiKit.set_text(nm, "『" + str(bd.get("name", bid)) + "』")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# v54：正文 16 → 21（运签的效果全在这一段里）
	var bd_lb := UiKit.make_label(panel, Vector2(34, 104), Vector2(472, 300), 21, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))
	UiKit.set_text(bd_lb, body)
	bd_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var blocked := excl and owned > 0
	var afford: bool = _state.money >= price and not blocked
	var ok := UiKit.make_button(panel, Vector2(100, 450), Vector2(180, 60), "请这张 " + str(price) + " 文", 19)
	ok.disabled = not afford
	ok.pressed.connect(_buy_buff_from_preview.bind(i))
	var back := UiKit.make_button(panel, Vector2(290, 450), Vector2(150, 60), "再看看", 22)
	back.pressed.connect(_close_preview)

	var why := ""
	if blocked:
		why = "同一张专属每趟限一次——这张请过了"
	elif _state.money < price:
		why = "钱不够（现有 " + str(_state.money) + " 文）"
	if why != "":
		# v54：15 → 19
		var wl := UiKit.make_label(panel, Vector2(0, 418), Vector2(540, 30), 19, UiKit.SEAL)
		UiKit.set_text(wl, why)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _buy_buff_from_preview(i: int) -> void:
	# 同装备那一路：先收弹窗，再走原来的请卡入口（它会自己重画货架）
	_host._close_popup()
	_on_shop_buff(i)


func _buff_owned(bid: String) -> int:
	var n := 0
	for id_v in _state.buffs:
		if str(id_v) == bid:
			n += 1
	return n


func _close_preview() -> void:
	_host._close_popup()
	_show_shop()


func _on_shop_buy(i: int) -> void:
	if i < 0 or i >= _offers.size():
		return
	if _state.bag_full():
		UiKit.float_text(_host, "包裹已满", UiKit.SEAL)
		return
	var o: Dictionary = _offers[i]
	var price := int(o.get("price", 40))
	if _state.money < price:
		UiKit.float_text(_host, "钱不够", UiKit.SEAL)
		return
	_state.money -= price
	_state.add_card(str(o.get("set_id", "")), int(o.get("part", 0)))
	_offers.remove_at(i)
	_host._refresh_all()
	UiKit.float_text(_host, "买入 " + str(Cards.card_name(str(o.get("set_id", "")), int(o.get("part", 0)))), UiKit.INK)
	_show_shop()


func _on_shop_buff(i: int) -> void:
	if i < 0 or i >= _buff_offers.size():
		return
	var bid := str(_buff_offers[i])
	var r: Dictionary = _state.add_buff(bid)
	if bool(r.get("ok", false)):
		_buff_offers.remove_at(i)
		_host._refresh_all()
		UiKit.float_text(_host, str(r.get("msg", "")), UiKit.GOLD)
	else:
		UiKit.float_text(_host, str(r.get("msg", "")), UiKit.SEAL)
	_show_shop()


func _on_shop_fix() -> void:
	if _fix.is_empty():
		return
	if _state.bag_full():
		UiKit.float_text(_host, "包裹已满", UiKit.SEAL)
		return
	var fix_p: int = int(_state.fix_price(str(_fix.get("set", ""))))
	if _state.money < fix_p:
		return
	_state.money -= fix_p
	_state.add_card(str(_fix.get("set", "")), int(_fix.get("part", 0)))
	_host._refresh_all()
	UiKit.float_text(_host, "补齐 +1 张（花 " + str(fix_p) + " 文）", UiKit.INK)
	_fix = _state.missing_card()
	_show_shop()


func _on_shop_refresh() -> void:
	if _state.money < 10:
		return
	_state.money -= 10
	_offers = _state.make_shop_offers(_host._node)
	# ㊿u：刷新也照同一条口径筛（主人不在阵的专属卡不上货架）
	_buff_offers = Buffs.roll_offers(str(_state.role_id), 3, _state.party_role_ids())
	_host._buff_offers = _buff_offers   # ㉞：刷新一并写回舞台签面
	_host._refresh_all()
	_show_shop()


func _on_shop_leave() -> void:
	_host._shop_active = false
	_host._advance()
