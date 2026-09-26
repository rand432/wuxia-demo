extends RefCounted
# ============================================================
# journey_synth_panel.gd —— 合成件 v3（优化批⑰）
# v3（优化批⑰）：身上已有同款时——按钮 [装备] 变 [替换]，提示讲清"身上不动、
#   多出的结算时带进村仓库"；点 [替换] 由 run_state v20 走"同款替换"，多出的一件不再被吞。
# 注：v3 首次粘贴残留了半个旧 else（120 行报错）——此版为整文件重贴的干净版。
# v2（优化批⑯）：合成页"去向"提示按件分口径——护甲/玉佩/披风讲"替换该位、旧件进包裹"；
#   兵器改看 weapon_id()（正式趟没换装时报"会盖过随身那把"，不再误报"现在空手"）。
# v1（R4 收尾 · 搬家第二半）：
# 从 journey_stage.gd（v25）原样搬来，纯搬不改行为：
#   press()    ← _on_synth_pressed（扫可合成整件：先收料入队，再逐件弹"去向"页）
#   _show_page ← _show_synth_popup
#   _place     ← _on_synth_place
#   _finish    ← _finish_synth
# 老例（同包裹/事件件的办法）：件收舞台注入引用，只读/写舞台写明的接口——
#   _state / 合成队列 / _just_synth / _close_popup() / _make_popup_veil() /
#   _refresh_all() / _fx / _bag._update_tip()；这些名字是契约，别改。
# 舞台转发口：_on_synth_pressed（包裹件的合成按钮认它）。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const GameState := preload("res://shared/game_state.gd")   # v37：显示含升星的加成
const RunState := preload("res://shared/run_state.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const JourneyCommon := preload("res://journey/journey_common.gd")

# 弹窗统一顶线——单一源在 journey_common.gd（同舞台转发法）
const POPUP_TOP := JourneyCommon.POPUP_TOP

var _stage = null

func setup(stage) -> void:
	_stage = stage

# 包裹件"合成"按钮 → 舞台 _on_synth_pressed → 到这里
# v2（用户："三合一的情况下我包裹四本，也全合了"）：
#   查过了——**吃页数是对的**（每套各吃一页，重复的那张留着；见 _pages_line 的说明）。
#   真正会让人误会的是"**一按把包裹里所有凑齐的套一起合了**"：按一下冒出好几页"放哪儿"，
#   看着就像"全被合了"。现在改成 **一按只合一（最前面那套）**，按钮上也写清"还有几套"。
func press() -> void:
	var st = _stage._state
	if st == null:
		return
	var synthables: Array = st.ready_sets()
	if synthables.is_empty():
		return
	_stage._synth_queue.clear()
	var sid := str(synthables[0])            # v2：只合一套（其余留在包裹里，想合再按）
	var parts: Array = Cards.parts_of(sid)
	var can: Dictionary = st.can_place_item(sid)
	var bag_after: int = int(st.bag.size()) - parts.size() + 1
	if not bool(can.get("equip", false)) and bag_after > st.bag_cap():
		UiKit.float_text(_stage, "位置不足，没合成：" + str(Cards.item_name(sid)), UiKit.SEAL)
		_stage._refresh_all()
		return
	for i in parts.size():
		st.take_one_card(sid, i)
	_stage._synth_queue.append(sid)
	if _stage._fx != null:
		_stage._fx.flash(Color(1, 1, 1, 0.16))
	_stage._refresh_all()
	_show_page()

func _show_page() -> void:
	if _stage._synth_queue.is_empty():
		_finish()
		return
	var st = _stage._state
	var sid := str(_stage._synth_queue[0])
	var is_arts: bool = Cards.is_arts(sid)
	var can: Dictionary = st.can_place_item(sid)
	var can_equip: bool = bool(can.get("equip", false))
	var can_bag: bool = bool(can.get("bag", false))
	var extra := ""
	var hint := ""
	var gcn := ""
	if not is_arts:
		var pool2 := str(Cards.by_id(sid).get("pool", ""))
		if pool2 == "armor":
			gcn = "护甲"
		elif pool2 == "helm":
			gcn = "玉佩"
		elif pool2 == "cloak":
			gcn = "披风"
	var dup := false
	if is_arts:
		var art: Dictionary = Cards.art_of(sid)
		extra = "招式：『" + str(Cards.name_of(sid)) + "』" + str(art.get("move", "")) + "\n" + "效果：" + str(art.get("desc", ""))
		if st.arts.has(sid):
			# v60（用户报的："合成了功法也无法装备，只能放在包里"）：这里以前只写"已有同名功法"，
			#   而下面那颗［装备］是灰的——玩家看不出"是谁已经有了、多的这本会去哪"，
			#   就当成"合成了却装不上"。写清人名与去处（跟兵器/装备那几条"同款"一个口径）。
			hint = str(_stage.member_name_of(st.active_i)) + " 已经带着这门了——多的这本放包裹（结算带进村仓库）"
		elif st.arts.size() >= RunState.ART_SLOTS:
			hint = "功法栏已满 " + str(RunState.ART_SLOTS) + " 门，先卸下一门"
		else:
			hint = "装上后：实战自动释放，中央打出招式名"
	elif gcn != "":
		var old_g := str(st.gear_of(str(Cards.by_id(sid).get("pool", ""))))
		extra = "装上后：替换身上「" + gcn + "」位（换下的旧件进包裹）"
		if old_g == sid:
			dup = true
			extra = "同款已在身上——替换后：身上不动，多出的一件进包裹"
			hint = "点［替换］：多出的结算时带进村仓库"
		elif old_g != "":
			hint = "会替换下 " + str(Cards.item_name(old_g)) + "（旧件进包裹）"
		else:
			hint = gcn + "位现在是空的"
	else:
		extra = "装上后：普攻改用该兵器招式"
		if str(st.weapon_id()) == "":
			hint = "现在空手，没有旧兵器要替换"
		elif str(st.weapon_id()) == sid:
			dup = true
			extra = "同款已在身上——装上后：普攻招式不变"
			hint = "点［替换］：多出的结算时带进村仓库"
		elif st.equipped_item == "":
			hint = "会盖过随身那把（" + str(Cards.item_name(str(st.base_weapon))) + "）——想换回点［卸下］"
		else:
			hint = "会替换下 " + str(Cards.item_name(st.equipped_item)) + "（旧兵器放回包裹）"
	if not can_bag:
		hint += "；包裹已满"

	# ㊿w：多人趟——"装得上吗"要按**有没有人能穿**算（当前看着的那个放不下，
	#   别人也许放得下）；点［装备］会先弹一层选人。
	var multi: bool = st.members.size() > 1
	if multi:
		var any_ok := false
		for mi in st.members.size():
			if bool(st.can_place_item_for(mi, sid).get("equip", false)):
				any_ok = true
				break
		can_equip = any_ok
		if hint != "":
			hint += "；"
		hint += "多人同行：点［装备］先选给谁"

	_stage._close_popup()
	var veil: ColorRect = _stage._make_popup_veil()
	var panel := UiKit.make_paper_panel(veil, Rect2(160, POPUP_TOP, 400, 400))

	var t1 := UiKit.make_label(panel, Vector2(0, 14), Vector2(400, 36), 26, UiKit.INK)
	UiKit.set_text(t1, "合成成功")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var t2 := UiKit.make_label(panel, Vector2(0, 52), Vector2(400, 34), 24, UiKit.SEAL)
	UiKit.set_text(t2, str(Cards.item_name(sid)))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var t3 := UiKit.make_label(panel, Vector2(30, 90), Vector2(340, 26), 16, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
	# v37：显示含升星的加成（与包裹详情/角色面板同一口径）
	UiKit.set_text(t3, "加成：" + str(Cards.bonus_text(GameState.starred_stats(sid))) + GameState.star_marks(sid))
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var t3b := UiKit.make_label(panel, Vector2(24, 118), Vector2(352, 74), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.78))
	UiKit.set_text(t3b, extra)
	t3b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t3b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# v2：把"这一套是几页、吃了哪几页、包裹里还剩几套"写清楚——
	#   "三合一/四合一"随品质不同（凡 3 页、良 4 页……），不写出来最容易误会成"全合了"
	var t3c := UiKit.make_label(panel, Vector2(20, 176), Vector2(360, 24), 13, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.62))
	UiKit.set_text(t3c, _pages_line(int(_stage._state.ready_sets().size())))
	t3c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var t4 := UiKit.make_label(panel, Vector2(30, 196), Vector2(340, 46), 15, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.62))
	UiKit.set_text(t4, hint)
	t4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var both: bool = (not can_equip) and (not can_bag)
	if both:
		var db := UiKit.make_button(panel, Vector2(130, 252), Vector2(140, 54), "丢弃", 20)
		db.pressed.connect(_place.bind("drop"))
	else:
		# ㊿w：多人趟不写"替换"——换谁还没定，写死"替换"反而误导
		var eq_txt := "选人装备" if multi else ("替换" if dup else "装备")
		var eq := UiKit.make_button(panel, Vector2(46, 252), Vector2(140, 54), eq_txt, 20)
		eq.disabled = not can_equip
		eq.pressed.connect(_place.bind("equip"))
		var pg := UiKit.make_button(panel, Vector2(214, 252), Vector2(140, 54), "放包裹", 20)
		pg.disabled = not can_bag
		pg.pressed.connect(_place.bind("bag"))

	var tip := UiKit.make_label(panel, Vector2(30, 320), Vector2(340, 60), 14, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.55))
	if both:
		UiKit.set_text(tip, "两边都放不下：先在左上角［角色］里卸下一门，或去商店卖掉些残卡")
	else:
		UiKit.set_text(tip, "先放包裹也行——之后点包裹里的它，同样能装备")
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# ㊿w：多人趟里"这件给谁穿"——先选人，再动手。
#   单人趟 / 选"放包裹"时，ask_member 会直接回调，等于以前的老样子。
func _place(k: String) -> void:
	if _stage._synth_queue.is_empty():
		_stage._close_popup()
		return
	var sid := str(_stage._synth_queue[0])
	if k == "equip":
		_stage.ask_member(sid, "这件给谁穿", _place_for.bind(sid), _place_bag.bind(sid))
		return
	_apply(sid, k, -1)

# ⚠ **参数顺序别改**（这一条踩过坑，用户报的"合成直接卡住"就是它）：
#   Godot 的 Callable.bind() 把绑定参数**接在调用参数后面**，不是前面——
#   ask_member 里是 on_pick.call(mi)，配上 _place_for.bind(sid) 实际调用的是
#   `_place_for(mi, sid)`。所以这里必须**成员下标在前、件名在后**；
#   写成 (sid: String, mi: int) 就是一个类型错误（int→String），
#   点［装备］当场报 "Invalid type ... Cannot convert argument 1 from int to String"，
#   而合成队列还没往前走（_apply 没被调到），整页就卡在"合成成功"上。
func _place_for(mi: int, sid: String) -> void:
	_apply(sid, "equip", mi)

# on_bag 是"无参回调"（_on_member_bag 里 on_bag.call()），所以绑定件名在前没问题。
func _place_bag(sid: String) -> void:
	_apply(sid, "bag", -1)

func _apply(sid: String, k: String, mi: int) -> void:
	if _stage._synth_queue.is_empty():
		_stage._close_popup()
		return
	# mi < 0＝不分人（放包裹是全队共用一只包裹；单人趟也走这条）
	var mi2: int = mi if mi >= 0 else int(_stage._state.active_i)
	var msg: String = str(_stage._state.place_item_for(mi2, sid, k))
	_stage._synth_queue.remove_at(0)
	_stage._close_popup()
	# ㊿w 补刀：玩家在"这件给谁穿"里点了谁，就把镜头切给谁，并在飘字里点出名字——
	#   不然"装给队友"之后面板还看着原来那位，看着像什么都没发生
	#   （与包裹详情页那条路同一处口径，见 journey_bag_panel._do_equip）。
	if mi >= 0 and _stage._state.members.size() > 1:
		_stage._state.use_member(mi)
		if msg != "":
			msg = str(_stage.member_name_of(mi)) + "：" + msg
	_stage._refresh_all()
	UiKit.float_text(_stage, msg, UiKit.SEAL)
	if _stage._synth_queue.is_empty():
		_finish()
	else:
		_show_page()

func _finish() -> void:
	_stage._just_synth = true
	_stage._bag._update_tip()

# v2：这一套要几页 / 刚吃了哪几页 / 包裹里还凑齐了几套
func _pages_line(ready_left: int) -> String:
	if _stage._synth_queue.is_empty():
		return ""
	var sid := str(_stage._synth_queue[0])
	var parts: Array = Cards.parts_of(sid)
	var names: Array = []
	for p in parts:
		names.append(str(p))
	var tail := "　·　包裹里还凑齐 " + str(ready_left) + " 套（再按［合成］继续）" if ready_left > 0 else ""
	return "本套 " + str(parts.size()) + " 页（" + "、".join(PackedStringArray(names)) + "）各吃一张" + tail
