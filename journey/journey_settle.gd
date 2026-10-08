extends RefCounted
# ============================================================
# journey_settle.gd —— 结算件 v5（行囊清点：面板撑高 ＋ 正文滚动）
# v5（用户："行囊清点框需要优化 字数超出"）：三个人的清单一屏装不下，文字从"残卡"
#   那一段起画到按钮上、再画到面板外。现在：面板高度按屏幕算（420~860），正文进
#   ScrollContainer（按住上下滑），按钮钉底；放不下时角上给一句"按住上下滑"。
# v4（优化批㉒：杂物银两口径＋血脉带出）
# v4：①杂物行文案改"银两"（杂物值多少银两就是多少——v3 里写"文"是旧口径的误导）；
#   ②临时仓库里的血脉随结算递交（journey_deposit 的"bloods"桶）。
# v3（优化批⑮）：①村里出身的件（随身清单里的三件套/功法）趟内被换下、卸下、落回
#   包裹的——结算不再入库（"village" 标记 + 就位比对两道闸），修掉"换下的村甲被
#   当战利品再入库一份"的重复账；②趟内换上的新装备（非村里原配）随行带出：
#   run_gear 里不是原配的件入仓库并登记；③"行囊清点"的兵器行改看 weapon_id()
#   （没换装时显示随身带着的村里那把），另加"随身装备"一行。
# v2（优化批③）：杂物折银。原为 R4 收尾搬家件——件只收 状态/幕布/两个回程回调；
#   抹档、关幕布、清容器、造幕布都留在舞台转发口里做（老铁律）。
# 舞台转发口：_open_settle / _open_settle_death（名字别改）。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const GameState := preload("res://shared/game_state.gd")
const RunState := preload("res://shared/run_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const JourneyCommon := preload("res://journey/journey_common.gd")

# 弹窗统一顶线——单一源在 journey_common.gd（同舞台转发法）
const POPUP_TOP := JourneyCommon.POPUP_TOP

# 成功结算：记档（首通换代助词）→ 入账（残卡/临时仓库/随身物）→ 摆页。
# 舞台已做完：_busy 置位、抹档、关幕布、造幕布（veil）。
static func open(st: RunState, veil: ColorRect, on_restart: Callable, on_return: Callable) -> void:
	# v16：正式趟走到结算＝这档走通了（记 journey.cfg；输赢细则 R4 重做）
	# v15b：本趟残卡入仓库（内存版；"取用"规则没定，只进不出）
	# v24：首通那一弹，记档前/后各看一眼两池的现役窗——差集就是给玩家的换代交代
	var first_line := ""
	if str(st.mode) == "formal":
		# v101：记档用**品级×4＋模式＋1**（出征屏交下来的编号）——老的 1~10 档已经不是主轴了。
		#   没有编号（老存档/引子趟）就退回老口径，按难度档记。
		var d: int = GameState.deploy_code if GameState.deploy_code > 0 else int(st.diff)
		var was_new: bool = not GameState.diff_is_cleared(d)
		var w0: int = GameState.ladder_swaps("weapon")
		var a0: int = GameState.ladder_swaps("arts")
		GameState.diff_clear(d)
		if was_new:
			var segs: Array = []
			var sw: String = _pool_swap_seg("weapon", w0, GameState.ladder_swaps("weapon"))
			var sa: String = _pool_swap_seg("arts", a0, GameState.ladder_swaps("arts"))
			if sw != "":
				segs.append(sw)
			if sa != "":
				segs.append(sa)
			if not segs.is_empty():
				first_line = "首通此档，货源换代——" + "；".join(PackedStringArray(segs))
				print("[游历] ", first_line)
		else:
			# v103（用户："游历每个难度只能通关一次"）：同一个难度再打＝复刷，不再算首通
			first_line = "此档本周已通关过——本趟按复刷结算（首通换代只给一次）"
	var dep: int = GameState.vault_deposit(st.count_cards())
	if dep > 0:
		print("[游历] 入仓库：本趟 ", dep, " 张；库里共 ", GameState.vault_total(), " 张")
	# R3：临时仓库随通关全数带出（journey_deposit 唯一管道）
	# 优化批③（#5）：杂物带出折银——先点数（显示用）；真折银在 _loot_dict 里并进 silver 桶
	var junk_silver := 0
	for e_v in st.loot_bag:
		var ed: Dictionary = e_v
		if str(ed.get("kind", "")) == "junk":
			junk_silver += int(ed.get("amount", 1)) * int(ed.get("value", 1))
	var loot_line := ""
	if not st.loot_bag.is_empty():
		loot_line = GameState.journey_deposit(_loot_dict(st))
		st.loot_bag.clear()
	if junk_silver > 0:
		loot_line += ("，" if loot_line != "" else "") + "杂物折银 +" + str(junk_silver) + " 银两"
		print("[游历] 杂物折银：+", junk_silver, " 文")
	# R4（Q3=b）：随身成品随通关带出村——带出才登记收集册
	var haul_line := _deposit_run_items(st)
	# v5b（阅历线 · 用户："游历也可以给一点"）：**通关给一笔阅历**（按难度算），
	#   殒命那条路也给三成（见 open_death）——"走过一遭，也算见识"。
	var ins_gain := _insight_of_run(st)
	GameState.insight_add(ins_gain)
	# v5（用户："行囊清点框需要优化 字数超出"）：**面板按屏幕留白撑高 ＋ 正文进滚动区**。
	#   旧版是死高 500、正文框只有 330 高（≈12 行），三个人一列（每人天赋/自带/兵器/
	#   随身装备/功法 五~六行）＋残卡＋盘缠＋带出，二十好几行——从"残卡"那一段起
	#   就画到按钮上、再画到面板外面去了（玩家截图里那一幕）。
	#   现在：面板高度＝按屏幕算（最多 860），正文一律放进 ScrollContainer（按住上下滑），
	#   按钮钉在面板底部，正文再长也不会压到按钮。
	var vp := veil.size
	# 下限 300：小屏（矮窗口）也要整块落在屏幕里——正文那边会自动进滚动
	var ph := clampf(vp.y - POPUP_TOP - 40.0, 300.0, 860.0)
	var panel := UiKit.make_paper_panel(veil, Rect2(60, POPUP_TOP, 600, ph))

	var title := UiKit.make_label(panel, Vector2(0, 18), Vector2(600, 44), 32, UiKit.INK)
	UiKit.set_text(title, "行囊清点")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var lines := ""
	if first_line != "":
		lines += first_line + "\n\n"
	# ㊿：三人成队——"谁带回了什么"按人头各列一段。
	#   单人时就是原来那几行（天赋/自带/兵器/随身装备/功法），一字不差。
	if st.member_count() > 1:
		var keep_m := st.active_i
		for mi in st.member_count():
			st.use_member(mi)
			lines += "【" + str(GameState.role_data(str(st.role_id)).get("name", "?")) + "】\n"
			lines += _member_lines(st)
		st.use_member(keep_m)
	else:
		lines += _member_lines(st)

	var cc: Dictionary = st.count_cards()
	lines += "\n残卡（本趟结束即入仓库）：\n"
	if cc.is_empty():
		lines += "　无\n"
	else:
		for s in cc.keys():
			var parts: Array = Cards.parts_of(str(s))
			var have := 0
			for i in parts.size():
				if int(cc[s].get(i, 0)) > 0:
					have += 1
			lines += "　" + str(Cards.name_of(str(s))) + " · " + str(have) + "/" + str(parts.size()) + "\n"
	lines += "\n盘缠 " + str(st.money) + " 文（出局清零）"
	# v5b：这趟挣到的阅历（阅历线在村口底排「阅历」那一格点）
	if ins_gain > 0:
		lines += "\n阅历 +" + str(ins_gain) + "（现有 " + str(GameState.insight) + " 点——去底排［阅历］点线）"
	if loot_line != "":
		lines += "\n" + loot_line
	if haul_line != "":
		lines += "\n" + haul_line

	# 正文：滚动区（VBox 撑高 → Label 自动换行；装不下就上下滑，不再冲出面板）
	var body_top := 74.0
	var foot_h := 74.0        # 底部留给按钮＋那行小提示
	var scroll := ScrollContainer.new()
	UiKit.drag_scroll(scroll)
	scroll.position = Vector2(30, body_top)
	scroll.size = Vector2(540, maxf(120.0, ph - body_top - foot_h))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(520, 0)
	col.add_theme_constant_override("separation", 0)
	scroll.add_child(col)
	var body := UiKit.make_label(col, Vector2.ZERO, Vector2(520, 0), 18, UiKit.INK)
	UiKit.set_text(body, lines)
	body.custom_minimum_size = Vector2(520, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# 装不下时给一句提示（行数 × 行高 ≈ 需要多高）
	var need_h := float(lines.split("
").size()) * 26.0
	var hint := UiKit.make_label(panel, Vector2(32, ph - foot_h + 6.0), Vector2(300, 22), 15,
		Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.50))
	UiKit.set_text(hint, "（正文放不下：按住上下滑）" if need_h > scroll.size.y else "")

	var by := ph - 58.0
	var rb := UiKit.make_button(panel, Vector2(88, by), Vector2(200, 46), "再来一趟", 20)
	rb.pressed.connect(on_restart)

	var vb := UiKit.make_button(panel, Vector2(312, by), Vector2(200, 46), "回村", 20)
	vb.pressed.connect(on_return)

# v5b：这一趟能给多少阅历——按难度算（难度 1 → 28 点；难度 10 → 100 点）
static func _insight_of_run(st: RunState) -> int:
	if str(st.mode) != "formal":
		return 0
	# v104（用户："现在档位变成4档 原来根据游历奖励也要划分四档了"）：
	#   老的"20 ＋ 难度×8"（10 档 28~100）改成**按四品级分档**：
	#   凡品 28 · 良品 52 · 上品 76 · 极品 100（老档 1/3/6/8 的位置取齐）
	return [28, 52, 76, 100][GameState.deploy_phase()]

# 殒命：全丢——不入仓库、不登记收集册、不记难度、不动村况；盘缠就地作废。
# 舞台已做完：_busy/_run_dead 置位、抹档、清容器、关幕布、造幕布（veil）。
static func open_death(st: RunState, veil: ColorRect, on_restart: Callable, on_return: Callable) -> void:
	var cards_n := 0
	var cc: Dictionary = st.count_cards()
	for sid_k in cc.keys():
		var bucket: Dictionary = cc[sid_k]
		for p_k in bucket.keys():
			cards_n += int(bucket[p_k])
	var items_n := 0
	for e_v in st.bag:
		var ed: Dictionary = e_v
		if str(ed.get("kind", "")) == "item":
			items_n += 1
	# ㊿：随身成品要按人头数——三个人各换了一把就是三件（原来只数当前成员那件）
	var keep_n := st.active_i
	for mi in st.member_count():
		st.use_member(mi)
		if st.equipped_item != "":
			items_n += 1
	st.use_member(keep_n)
	var loot_n: int = int(st.loot_bag.size())
	print("[游历] 殒命：残卡 ", cards_n, " 张 · 随身成品 ", items_n, " 件 · 临时仓库 ", loot_n, " 件——全丢")
	var panel := UiKit.make_paper_panel(veil, Rect2(60, POPUP_TOP, 600, 440))

	var title := UiKit.make_label(panel, Vector2(0, 18), Vector2(600, 44), 32, UiKit.SEAL)
	UiKit.set_text(title, "殒命")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var lines := "江湖路远，你没能走完这一趟。\n\n"
	lines += "背上的东西尽数散失：\n"
	lines += "　残卡 " + str(cards_n) + " 张 · 随身成品 " + str(items_n) + " 件 · 临时仓库 " + str(loot_n) + " 件\n"
	lines += "未入村仓库，也未登记收集册。\n"
	lines += "盘缠 " + str(st.money) + " 文，一并埋在了路边。"
	# v5b：阅历线——东西全丢，但"走过一遭"这件事留得住：给三成
	var ins_lost := int(float(_insight_of_run(st)) * 0.3)
	if ins_lost > 0:
		GameState.insight_add(ins_lost)
		lines += "\n\n只有见识留住了：阅历 +" + str(ins_lost) + "（三成——去底排［阅历］点线）"

	var body := UiKit.make_label(panel, Vector2(40, 86), Vector2(520, 250), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))
	UiKit.set_text(body, lines)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var rb := UiKit.make_button(panel, Vector2(88, 368), Vector2(200, 46), "再来一趟", 20)
	rb.pressed.connect(on_restart)

	var vb := UiKit.make_button(panel, Vector2(312, 368), Vector2(200, 46), "回村", 20)
	vb.pressed.connect(on_return)

# R4：随身物带出——包裹成品＋身上兵器（正式趟）＋趟内换上的装备与功法 → 村仓库并登记。
# 优化批⑮：村里原配（run_base_gear / run_base_arts）不入库——它们本就在村账上；
#   换下/卸下落包的件带 "village" 标记，直接跳过（防重复账）。
# 口径（Q3=b）：成品/功法只有活着带出村才登记收集册。
# 引子趟特殊：装备物由舞台 _snapshot_player 写进账本，这里只带包裹成品，免得两头重复。
# ㊿：一名成员的那几行（天赋/自带/兵器/随身装备/功法）——单人时就是原来的正文
static func _member_lines(st: RunState) -> String:
	var out := ""
	if st.talents.is_empty():
		out += "天赋：无\n"
	else:
		out += "天赋：" + "、".join(PackedStringArray(st.talents)) + "\n"
	var inn_name := str(st.innate_name())
	if inn_name != "":
		out += "自带：" + inn_name + "（" + str(st.innate_desc()) + "）\n"
	# 优化批⑮：兵器行看 weapon_id()——正式趟没换装时，显示随身带着的村里那把
	var wid_d := str(st.weapon_id())
	if wid_d == "":
		out += "兵器：空手\n"
	else:
		var wt_d := ""
		if st.equipped_item == "":
			wt_d = "（随身）"
		out += "兵器：" + str(Cards.item_name(wid_d)) + wt_d + "（" + str(Cards.bonus_text(GameState.starred_stats(wid_d))) + "）\n"
	if str(st.mode) != "intro":
		var gsegs: Array = []
		for slot_v in RunState.GEAR_SLOTS:
			var slot := str(slot_v)
			var gsid := str(st.gear_of(slot))
			var gtxt := "—"
			if gsid != "":
				gtxt = str(Cards.item_name(gsid))
			gsegs.append(str(RunState.SLOT_CN.get(slot, slot)) + "：" + gtxt)
		out += "随身装备：" + "　".join(PackedStringArray(gsegs)) + "\n"
	var art_names: Array = []
	for sid in st.arts:
		art_names.append(str(Cards.name_of(str(sid))))
	if art_names.is_empty():
		out += "功法：无\n"
	else:
		out += "功法：" + "、".join(PackedStringArray(art_names)) + "\n"
	return out

static func _deposit_run_items(st: RunState) -> String:
	if st == null:
		return ""
	var names: Array = []
	for e_v in st.bag:
		var ed: Dictionary = e_v
		if str(ed.get("kind", "")) != "item":
			continue
		var sid := str(ed.get("set", ""))
		if sid == "":
			continue
		if bool(ed.get("village", false)):
			continue   # 村里出身的件（换下/卸下落包）——村账认它，不再入库
		GameState.vault_add_item(sid, 1)
		GameState.mark_collected(sid)
		names.append(str(Cards.item_name(sid)))
	# ㊿：三人成队——随身物**按人头各入一遍**。
	#   以前这里只读"当前成员"那一份，三个人出门的话另外两人的换装/新学功法
	#   就白捡了（结算只认领队）。整队挨个走一遍，逻辑一个字没改。
	if str(st.mode) != "intro":
		var keep := st.active_i
		for mi in st.member_count():
			st.use_member(mi)
			if st.equipped_item != "":
				var wsid := str(st.equipped_item)
				GameState.vault_add_item(wsid, 1)
				GameState.mark_collected(wsid)
				names.append(str(Cards.item_name(wsid)))
			# 优化批⑮：趟内换上的三件套（不是村里原配的那件）随行带出
			for slot_v in st.run_gear.keys():
				var slot := str(slot_v)
				var gsid := str(st.run_gear[slot])
				if gsid == "":
					continue
				if str(st.run_base_gear.get(slot, "")) == gsid:
					continue   # 还是村里那件——村账认它，不入库
				GameState.vault_add_item(gsid, 1)
				GameState.mark_collected(gsid)
				names.append(str(Cards.item_name(gsid)))
			for a_v in st.arts:
				var asid := str(a_v)
				if st.run_base_arts.has(asid):
					continue
				GameState.vault_add_item(asid, 1)
				GameState.mark_collected(asid)
				names.append(str(Cards.item_name(asid)))
		st.use_member(keep)
	if names.is_empty():
		return ""
	var line := "随身物入仓库：" + "、".join(PackedStringArray(names))
	print("[游历] ", line)
	return line

# v24：首通换代反馈——比"记档前/后"两套现役窗的差集（贴尾空转→空串）
static func _pool_swap_seg(pool: String, s0: int, s1: int) -> String:
	var before: Array = Cards.ladder_sets(pool, s0)
	var after: Array = Cards.ladder_sets(pool, s1)
	var outs: Array = []
	var ins: Array = []
	for sid_v in before:
		if not after.has(sid_v):
			outs.append(str(Cards.name_of(str(sid_v))))
	for sid_v in after:
		if not before.has(sid_v):
			ins.append(str(Cards.name_of(str(sid_v))))
	if outs.is_empty() and ins.is_empty():
		return ""
	var txt := ""
	if not outs.is_empty():
		txt += "、".join(PackedStringArray(outs)) + "退场"
	if not ins.is_empty():
		if txt != "":
			txt += "，"
		txt += "、".join(PackedStringArray(ins)) + "入池"
	return ("兵器：" if pool == "weapon" else "武学：") + txt

# 临时仓库 → journey_deposit 的 loot 形状（通关带出）
static func _loot_dict(st: RunState) -> Dictionary:
	var out := {"cards": {}, "items": {}, "mats": {}, "fragments": {}, "pills": {}, "wines": 0, "wine_grades": [], "silver": 0, "yuanbao": 0, "bloods": []}
	# v62o：短绳签的**保底酒**先并进来（它不走 loot_bag——那个格子少，会被"包满"吞掉）
	for g_v in st.bonus_wines:
		out["wines"] = int(out["wines"]) + 1
		(out["wine_grades"] as Array).append(int(g_v))
	for e_v in st.loot_bag:
		var ed: Dictionary = e_v
		var k := str(ed.get("kind", ""))
		var sid := str(ed.get("id", ""))
		var amt := int(ed.get("amount", 1))
		if k == "card":
			if not out["cards"].has(sid):
				out["cards"][sid] = {}
			var bucket: Dictionary = out["cards"][sid]
			var part := int(ed.get("part", 0))
			bucket[part] = int(bucket.get(part, 0)) + 1
		elif k == "item":
			out["items"][sid] = int(out["items"].get(sid, 0)) + amt
		elif k == "mat":
			out["mats"][sid] = int(out["mats"].get(sid, 0)) + amt
		elif k == "fragment":
			out["fragments"][sid] = int(out["fragments"].get(sid, 0)) + amt
		elif k == "pill":
			out["pills"][sid] = int(out["pills"].get(sid, 0)) + amt
		elif k == "wine":
			# v62：坛数照记，**品级也带上**（紫/金/红）——回村按品级兑成对应那一坛
			out["wines"] = int(out["wines"]) + amt
			for wi in amt:
				out["wine_grades"].append(int(ed.get("wgrade", 2)))
		elif k == "silver":
			out["silver"] = int(out["silver"]) + amt
		elif k == "yuanbao":
			out["yuanbao"] = int(out["yuanbao"]) + amt
		elif k == "blood":
			out["bloods"].append({"id": sid, "pur": int(ed.get("pur", 50))})
		elif k == "junk":
			# 优化批③（#5）：杂物折银——带出才作数（死在路上照旧全丢）；v4：值＝银两
			out["silver"] = int(out["silver"]) + amt * int(ed.get("value", 1))
	return out
