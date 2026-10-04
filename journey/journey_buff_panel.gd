extends Control
# ============================================================
# journey_buff_panel.gd —— 卡组面板 v6（整件替换版）
# v6（㊼）：①"请卡"改口"请签"（去请签/回签摊）；②专属口径按实义写清——
#   ㊼：专属的「每趟限一张」已撤——三种卡现在都可重复请、叠着生效（签面只做去重＋补位）；
#   ③新增「命数签」页——接往日特殊事件那几桩（横财/翻财/血路）；
#   ④签面摇卡时把"已持有的专属"剔出去，不够三张自动补。
# 请签页：花文钱请签卡——只在这趟里生效、不进包裹、带不出去；
#   普通/特殊/专属一律可重复请、叠着生效。
# 当前卡组页：增益＋专属＋命数合看；点任一卡＝看详情。
# 卡表唯一来源＝shared/data_buffs.gd；签面存舞台（关掉重开不免费换，买光才重摇）。
# 接口（只认舞台这三样）：setup(host, state, offers)；host._refresh_all()；host.take_fate_sign(fid)。
# ============================================================

const Buffs := preload("res://shared/data_buffs.gd")
const UiKit := preload("res://shared/ui_kit.gd")

# ㊿：命数签页摆哪几桩。前三桩＝往日路上的特殊事件（横财/翻财/血路），
#   后五桩是出征屏那张"选一卡"里的其余命数——两边口径现在对齐了
#   （出征屏 FATE_LIST 八张；这里也八张，免得新加的签在这页看不见）。
const FATE_SIGNS := ["greed", "scavenge", "bloodpath", "shortrope", "fullbag", "noarmor", "endure", "sharpen",
	"iron", "allin", "venom"]   # v62o：血勇签已删

var _host = null
var _state = null
var _offers: Array = []
var _root: Control = null
var _body: Control = null
var _page := "shop"          # shop＝请签；fate＝命数签；mine＝当前卡组
var _detail: Control = null
var _msg := ""

func setup(host, state, offers: Array) -> void:
	_host = host
	_state = state
	_offers = offers
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 自给自足：舞台上没备签面就现摇（签面存舞台——关掉重开不免费换）
	# ㊿u：摇的时候带上"这趟在阵的这几个人"——主人没来，他的专属卡不进签面
	if _offers.is_empty():
		_offers.append_array(Buffs.roll_offers(str(_state.role_id), 3, _state.party_role_ids()))
	_sanitize_offers()
	_build()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_blank)
	add_child(dim)
	_root = UiKit.make_paper_panel(self, Rect2(20, 220, 680, 820))
	_rebuild_page()

func _rebuild_page() -> void:
	_close_detail()
	if _body != null and is_instance_valid(_body):
		_body.queue_free()
	_body = Control.new()
	_body.size = Vector2(680, 820)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_body)
	if _page == "mine":
		_build_mine()
	elif _page == "fate":
		_build_fate()
	else:
		_build_shop()

# ---------- 请签页 ----------

func _build_shop() -> void:
	var tt := UiKit.make_label(_body, Vector2(0, 20), Vector2(680, 44), 30, UiKit.INK)
	UiKit.set_text(tt, "卡组 · 增益")
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UiKit.make_label(_body, Vector2(30, 70), Vector2(620, 92), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.70))
	UiKit.set_text(sub, "花文钱请一张签卡——只在这趟里生效；不进包裹、带不出去。\n普通/特殊可重复请、叠着生效（对全队）；专属同一张每趟只能请一次，且只对卡上那个人生效。\n另一条路：打精英，战利三抽里也能摸到。")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var vis := 0
	for i in _offers.size():
		var bid := str(_offers[i])
		# ㊾：专属请过就下架（数量限制，留着）；「只认本角色」那道闸撤了
		if _is_excl(bid) and _owned(bid) > 0:
			continue
		# ㊿：封顶的卡（回气卡第 2 张、冰心卡第 3 张…）也一样——架上别摆"请了也不更强"的货
		if _capped(bid):
			continue
		var b: Dictionary = Buffs.of(bid)
		var price := int(b.get("price", 40))
		# ㊿：标题走 Buffs.title_of——专属卡会带上"谁的专用"（免得三张专属卡分不清）
		var txt := "『" + Buffs.title_of(bid) + "』　" + str(price) + " 文\n" + str(b.get("desc", ""))
		if _is_excl(bid):
			txt += "\n（专属 · " + Buffs.owner_cn(bid) + "专用 · 同一张每趟限一次）"
		# v54（玩家反馈："选卡字体还是太小了"）：卡面 18 → 21、卡高 136 → 150、行距 148 → 162，
		#   起点 144 → 168（说明那三行也跟着放大到 19 号、占 92 高）
		var oy := 168.0 + float(vis) * 162.0
		# ㊿：**点卡面＝看详情，不再直接买**。
		#   以前整张卡就是"买"按钮，想先看看说明都不行（一碰就花钱）。
		#   现在拆成两块：左边卡面看详情，右边［请这张］才花钱。
		var card := UiKit.make_button(_body, Vector2(30, oy), Vector2(476, 150), txt, 21)
		# v54：字放大之后，长一点的说明在卡面上会横着顶出去——让它自动换行（卡高 150 放得下三行）
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.pressed.connect(_open_detail.bind(bid))
		var buy := UiKit.make_button(_body, Vector2(514, oy), Vector2(136, 150), "请这张\n" + str(price) + " 文", 21)
		buy.disabled = _state.money < price
		buy.pressed.connect(_on_buy.bind(i))
		vis += 1
	if vis == 0:
		var e := UiKit.make_label(_body, Vector2(30, 170), Vector2(620, 60), 23, UiKit.DIM)
		UiKit.set_text(e, "架子空了——刷新一次换新签。")
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var mLb := UiKit.make_label(_body, Vector2(30, 656), Vector2(620, 64), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.80))
	if _msg != "":
		UiKit.set_text(mLb, _msg)
	else:
		UiKit.set_text(mLb, "现有 " + str(_state.money) + " 文　·　已请 " + str(_state.buff_count()) + " 张——点［当前卡组］逐张查看。")
	mLb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var rb := UiKit.make_button(_body, Vector2(30, 726), Vector2(152, 58), "刷新 10文", 20)
	rb.disabled = _state.money < 10
	rb.pressed.connect(_on_refresh)
	var fb := UiKit.make_button(_body, Vector2(192, 726), Vector2(152, 58), "命数签", 20)
	fb.pressed.connect(_go_fate)
	var vb := UiKit.make_button(_body, Vector2(354, 726), Vector2(152, 58), "当前卡组", 20)
	vb.pressed.connect(_go_mine)
	var cb := UiKit.make_button(_body, Vector2(516, 726), Vector2(152, 58), "收起", 20)
	cb.pressed.connect(queue_free)

# ---------- 当前卡组页（增益＋专属＋命数合看；点一张看详情） ----------

func _build_mine() -> void:
	var tt := UiKit.make_label(_body, Vector2(0, 20), Vector2(680, 44), 30, UiKit.INK)
	UiKit.set_text(tt, "当前卡组 · 增益＋专属")
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var agg := _agg()
	var total := 0
	for a_v in agg:
		total += int((a_v as Dictionary).get("n", 1))
	var fates: Array = []
	for f_v in FATE_SIGNS:
		if _own_fate(str(f_v)):
			fates.append(Buffs.name_of("fate_" + str(f_v)))
	var head := UiKit.make_label(_body, Vector2(30, 70), Vector2(620, 92), 20, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
	if agg.is_empty() and fates.is_empty():
		UiKit.set_text(head, "还没请签——点［去请签］翻回上一页。")
	else:
		var parts: Array = []
		for a_v in agg:
			var a: Dictionary = a_v
			parts.append(str(a.get("name", "?")) + ("×" + str(int(a.get("n", 1))) if int(a.get("n", 1)) > 1 else ""))
		var txt2 := "综合（" + str(total) + " 张）：\n" + "、".join(PackedStringArray(parts))
		if not fates.is_empty():
			txt2 += "\n命数：" + "、".join(PackedStringArray(fates))
		UiKit.set_text(head, txt2)
	# v84（用户：「增益卡分类…集齐3/6/9 会获得额外效果」）：
	#   综合那行下面**单列"流派进度"**——玩家一眼看出离下一档还差几张、下一档给什么。
	var prows: Array = Buffs.path_progress(_state.buffs)
	var py := 168.0
	for r_v in prows:
		var pr: Dictionary = r_v
		var lb := UiKit.make_label(_body, Vector2(40, py), Vector2(600, 26), 17, pr["color"])
		var tail := "　已满阶（3/6/9 全开）"
		if int(pr["next"]) > 0:
			tail = "　再 " + str(int(pr["next"]) - int(pr["n"])) + " 张 → " + str(pr["next"]) + " 张：" + str(pr["next_say"])
		UiKit.set_text(lb, "◆ " + str(pr["name"]) + " ×" + str(pr["n"]) + tail)
		py += 26.0
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# ㊿：卡多了原来只排得下 5~6 格，剩下的只写一句"没排下"。
	#   改成**可滚动列表**（跟炼丹阁丹方行同一套写法：ScrollContainer + VBoxContainer）。
	#   ScrollContainer 自带拖动与滚轮，手机上直接滑。
	var sc = ScrollContainer.new()
	UiKit.drag_scroll(sc)
	sc.position = Vector2(30, 176)
	sc.size = Vector2(620, 462)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(sc)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(604, 0)
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)

	var shown := 0
	for a_v in agg:
		var a: Dictionary = a_v
		var bid := str(a.get("id", ""))
		var b: Dictionary = Buffs.of(bid)
		# ㊿：卡名后面带上"专属是谁的"——当前卡组这一页以前只写『破军卡』（专属卡），
		#   而手里可能同时躺着三个人的专属卡，光看名字分不出哪张对谁出力。
		var lbl := "『" + Buffs.title_of(bid) + "』"
		if int(a.get("n", 1)) > 1:
			lbl += " ×" + str(int(a.get("n", 1)))
		# ㊿：请重了也标出来——"×2"不等于"效果×2"的那些卡，在这儿说清楚
		if int(a.get("n", 1)) > 1 and _capped(bid):
			lbl += "（多张只算一份）"
		lbl += "\n" + str(b.get("desc", ""))
		var btn := UiKit.make_button(list, Vector2.ZERO, Vector2(596, 100), lbl, 20)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # v54：允许换行，长说明不再横着顶出去
		# 进了 VBoxContainer 之后位置/尺寸由容器定，这里只报"至少多高"（跟丹方行一个写法）
		btn.custom_minimum_size = Vector2(0, 100)
		btn.pressed.connect(_open_detail.bind(bid))
		shown += 1
	if shown == 0:
		var e2 := UiKit.make_label(_body, Vector2(30, 200), Vector2(620, 60), 21, UiKit.DIM)
		UiKit.set_text(e2, "（这趟还没请签）")
		e2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bb := UiKit.make_button(_body, Vector2(60, 700), Vector2(180, 58), "去请签", 20)
	bb.pressed.connect(_go_shop)
	var fb2 := UiKit.make_button(_body, Vector2(270, 700), Vector2(180, 58), "命数签", 20)
	fb2.pressed.connect(_go_fate)
	var cb2 := UiKit.make_button(_body, Vector2(480, 700), Vector2(180, 58), "收起", 20)
	cb2.pressed.connect(queue_free)

# ---------- 命数签页（八桩：往日特殊事件三桩 + 出征屏那几张命数） ----------

func _build_fate() -> void:
	var tt := UiKit.make_label(_body, Vector2(0, 20), Vector2(680, 44), 30, UiKit.INK)
	UiKit.set_text(tt, "卡组 · 命数签")
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UiKit.make_label(_body, Vector2(30, 70), Vector2(620, 92), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.70))
	UiKit.set_text(sub, "命数签——接一桩，本趟里一直挂着（横财/翻财/血路那几桩路上的事，加上出征屏能挑的几张）。\n负面换好处；每桩只接一次，接过就从这页消失（只本趟，带不出去）。")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# ㊿：签从三桩涨到八桩，原来那套"152 起、每行 128"直接排到纸外面去了。
	#   改成可滚列表（与"当前卡组"页同一套写法）。
	var sc2 = ScrollContainer.new()
	UiKit.drag_scroll(sc2)
	sc2.position = Vector2(30, 176)
	sc2.size = Vector2(620, 446)
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(sc2)
	var flist := VBoxContainer.new()
	flist.custom_minimum_size = Vector2(604, 0)
	flist.add_theme_constant_override("separation", 8)
	sc2.add_child(flist)

	var left_n := 0
	for fid_v in FATE_SIGNS:
		var fid := str(fid_v)
		var bid := "fate_" + fid
		var b: Dictionary = Buffs.of(bid)
		var nm := str(b.get("name", bid))
		var btn := UiKit.make_button(flist, Vector2.ZERO, Vector2(600, 132), "", 21)
		# v54：同上——命数签的说明更长，必须允许换行
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, 132)
		if _own_fate(fid):
			UiKit.set_btn_text(btn, "『" + nm + "』　已接（本趟）\n" + str(b.get("desc", "")))
			btn.disabled = true
		else:
			UiKit.set_btn_text(btn, "请『" + nm + "』\n" + str(b.get("desc", "")))
			btn.pressed.connect(_take_fate.bind(fid))
			left_n += 1

	var mLb := UiKit.make_label(_body, Vector2(30, 644), Vector2(620, 46), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.80))
	if _msg != "":
		UiKit.set_text(mLb, _msg)
	elif left_n == 0:
		UiKit.set_text(mLb, "都接过了——再往前走便是。")
	else:
		UiKit.set_text(mLb, "命数接了就一直挂着——权衡好了再动手（可上下滑）。")
	mLb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var bb := UiKit.make_button(_body, Vector2(120, 700), Vector2(200, 58), "回签摊", 20)
	bb.pressed.connect(_go_shop)
	var cb := UiKit.make_button(_body, Vector2(360, 700), Vector2(200, 58), "收起", 20)
	cb.pressed.connect(queue_free)

# ---------- 操作 ----------

func _on_buy(i: int) -> void:
	if i < 0 or i >= _offers.size():
		return
	var bid := str(_offers[i])
	# ㊾：同一张专属每趟只能请一次（数量限制）；「只认本角色」那道闸撤了
	if _is_excl(bid) and _owned(bid) > 0:
		_msg = "同一张专属卡每趟只能请一次——这张已经请过了。"
		_rebuild_page()
		return
	var r: Dictionary = _state.add_buff(bid)
	if bool(r.get("ok", false)):
		_offers.remove_at(i)
		_host._refresh_all()
		_msg = "已收入卡组——本趟生效，带不出去。"
		UiKit.float_text(_host, str(r.get("msg", "")), UiKit.GOLD)
	else:
		UiKit.float_text(_host, str(r.get("msg", "")), UiKit.SEAL)
	_rebuild_page()

func _on_refresh() -> void:
	if _state.money < 10:
		UiKit.float_text(_host, "文钱不够（刷新要 10 文）", UiKit.SEAL)
		return
	_state.money -= 10
	_offers.clear()
	_offers.append_array(Buffs.roll_offers(str(_state.role_id), 3, _state.party_role_ids()))
	_sanitize_offers()
	_host._refresh_all()
	_msg = "换了一批新签。"
	_rebuild_page()

func _go_shop() -> void:
	_page = "shop"
	_msg = ""
	_rebuild_page()

func _go_mine() -> void:
	_page = "mine"
	_msg = ""
	_rebuild_page()

func _go_fate() -> void:
	_page = "fate"
	_msg = ""
	_rebuild_page()

func _take_fate(fid: String) -> void:
	if _host == null or not _host.has_method("take_fate_sign"):
		UiKit.float_text(_host, "眼下接不了命数——先收摊", UiKit.SEAL)
		return
	var r: Dictionary = _host.take_fate_sign(fid)
	if bool(r.get("ok", false)):
		_msg = "接下了——本趟里一直挂着。"
	else:
		UiKit.float_text(_host, str(r.get("msg", "接不了")), UiKit.SEAL)
	_rebuild_page()

func _own_fate(fid: String) -> bool:
	return _state.buffs.has("fate_" + fid)

# ㊾：签面清一遍——已持有的专属剔出去（请过就从签池消失）；不够三张自动补
# ㊿：封顶的（请了也不再更强的）同样剔出去——货架上不该摆"买了没用"的东西
# ㊿u：主人不在阵里的专属卡也剔出去（请了不出力；签面可能是舞台那边递过来的旧货）
func _sanitize_offers() -> void:
	var party: Array = _state.party_role_ids()
	var clean: Array = []
	for id_v in _offers:
		var sid := str(id_v)
		if _is_excl(sid) and _owned(sid) > 0:
			continue
		if not Buffs.owner_deployed(sid, party):
			continue
		if _capped(sid):
			continue
		clean.append(sid)
	var pool: Array = Buffs.pool_for_role(str(_state.role_id), party)
	pool.shuffle()
	for sid_v in pool:
		if clean.size() >= 3:
			break
		var sid := str(sid_v)
		if clean.has(sid):
			continue
		if _is_excl(sid) and _owned(sid) > 0:
			continue
		if _capped(sid):
			continue
		clean.append(sid)
	_offers.clear()
	_offers.append_array(clean)

# ---------- 卡详情 ----------

func _open_detail(bid: String) -> void:
	_close_detail()
	var b: Dictionary = Buffs.of(bid)
	var veil := UiKit.make_veil(self, size, 0.35)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(_on_detail_blank)
	_detail = veil
	# v54：详情页 420 → 470 高（正文 19 → 22）
	var panel := UiKit.make_paper_panel(veil, Rect2(100, 300, 520, 470))
	var t1 := UiKit.make_label(panel, Vector2(0, 22), Vector2(520, 40), 27, UiKit.INK)
	UiKit.set_text(t1, "『" + str(b.get("name", bid)) + "』")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := UiKit.make_label(panel, Vector2(36, 76), Vector2(448, 34), 19, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.70))
	# ㊿：专属卡第一行就把"是谁的"写在最前面（类型后面才轮到别的）
	var kind_line := "类型：" + Buffs.kind_cn(bid)
	if _is_excl(bid):
		kind_line += "　·　" + Buffs.owner_note(bid) + "（只对他出力）"
	kind_line += "　·　已请 ×" + str(_owned(bid))
	if _is_excl(bid):
		kind_line += "　·　同一张每趟限一次"
	UiKit.set_text(t2, kind_line)
	var t3 := UiKit.make_label(panel, Vector2(36, 122), Vector2(448, 236), 22, UiKit.INK)
	# ㊿：手里已经到封顶张数时，详情页把"再请也不会更强"写在效果下面
	var hin := Buffs.cap_hint(bid, _owned(bid))
	var extra := ""
	if hin != "":
		extra = "\n⚠ " + hin
	UiKit.set_text(t3, str(b.get("desc", "")) + extra + "\n\n只在这趟里生效；不进包裹、带不出去。")
	t3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# ㊿：详情页里也能直接请——在签摊那一页点卡面进来的人，不用退出去再点一次。
	#   只有"在售"的卡才给这个钮（从"当前卡组"点进来的没有价格，就不显示）。
	var price := int(b.get("price", 0))
	var in_shop: bool = price > 0 and _offers.has(bid) and not (_is_excl(bid) and _owned(bid) > 0) and not _capped(bid)
	if in_shop:
		var buy := UiKit.make_button(panel, Vector2(50, 382), Vector2(200, 56), "请这张 " + str(price) + " 文", 20)
		buy.disabled = _state.money < price
		buy.pressed.connect(_buy_from_detail.bind(bid))
		var cb := UiKit.make_button(panel, Vector2(280, 382), Vector2(180, 56), "知道了", 21)
		cb.pressed.connect(_close_detail)
	else:
		var cb2 := UiKit.make_button(panel, Vector2(170, 382), Vector2(180, 56), "知道了", 21)
		cb2.pressed.connect(_close_detail)

# ㊿：从详情页请这一张——先关详情，再走原购买口（买卖逻辑只留一份）
func _buy_from_detail(bid: String) -> void:
	var i := _offers.find(bid)
	_close_detail()
	if i < 0:
		_msg = "这张已经不在架子上了——刷新看看"
		_rebuild_page()
		return
	_on_buy(i)

func _close_detail() -> void:
	if _detail != null and is_instance_valid(_detail):
		_detail.queue_free()
	_detail = null

func _on_detail_blank(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_close_detail()

# ---------- 小工具 ----------

func _is_excl(bid: String) -> bool:
	return str(Buffs.of(bid).get("kind", "")) == "exclusive"

# ㊿：这张卡"再请一张也没用了"吗？（回气卡第 2 张、冰心卡第 3 张、淬毒卡第 2 张）
#   判据在 data_buffs.USEFUL_COPIES —— 只有引擎侧真有封顶/只判 >0 的键才算，
#   其余键都是"请几张叠几份"（别凭印象往里加，会让提示说谎）。
func _capped(bid: String) -> bool:
	return Buffs.cap_hint(bid, _owned(bid)) != ""

func _owned(bid: String) -> int:
	var n := 0
	for id_v in _state.buffs:
		if str(id_v) == bid:
			n += 1
	return n

# 按 id 合并计数（命数单独走"命数："一行）
func _agg() -> Array:
	var out: Array = []
	var idx: Dictionary = {}
	for id_v in _state.buffs:
		var sid := str(id_v)
		if sid.begins_with("fate_"):
			continue
		if idx.has(sid):
			var a: Dictionary = out[int(idx[sid])]
			a["n"] = int(a.get("n", 1)) + 1
			continue
		idx[sid] = out.size()
		out.append({"id": sid, "name": str(Buffs.of(sid).get("name", sid)), "n": 1})
	return out

func _on_blank(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		queue_free()
