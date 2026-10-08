extends RefCounted
# ============================================================
# journey_choice_flow.gd —— 事件卡（抉择卡）那一页 v1
# 设计稿：docs/事件卡与善恶_设计稿.md ｜ 内容表：journey/data_events.gd
# v107（用户："善恶相当于各种支线任务 有短线和长线 更有不同的结局"）：
#   一张卡＝标题 ＋ 正文（★ 老的 event 节点写了正文却从没显示过）＋ 2~3 个选项条；
#   点整行即生效：改善恶/盘缠/气血/警戒、入线/断线、给件、开打、连锁下一张。
# 与舞台的接口（照拆件批的老规矩，不反向引 journey_stage）：
#   setup(host) / open(card: Dictionary)
#   host._choice_loot(kind)      → 给残件/整件（舞台那边管货从哪来）
#   host._choice_battle(kind)    → 立刻开打
#   host._choice_buff(bid)       → 挂一个临时增益
#   host._choice_finish()        → 这一节办完，继续走路
# ============================================================

const Events := preload("res://journey/data_events.gd")
const UiKit := preload("res://shared/ui_kit.gd")
const JourneyCommon := preload("res://journey/journey_common.gd")
const GameState := preload("res://shared/game_state.gd")

var _host = null
var _state = null
var _card: Dictionary = {}
var _opened := false

func setup(host) -> void:
	_host = host
	_state = host._state

func is_open() -> bool:
	return _opened

# ------------------------------------------------------------
# 开一张卡
# ------------------------------------------------------------
func open(card: Dictionary) -> void:
	if card.is_empty():
		_host._choice_finish()
		return
	_card = card
	_opened = true
	_host._busy = true
	_mark_seen(str(card.get("id", "")))
	_show()

func _mark_seen(cid: String) -> void:
	if cid != "" and _state != null and not _state.ev_seen.has(cid):
		_state.ev_seen.append(cid)

func _show() -> void:
	_host._close_overlay()
	var veil = _host._make_veil(0.52)
	var panel := UiKit.make_paper_panel(veil, Rect2(30, JourneyCommon.POPUP_TOP, 660, 620))

	# 支线名（在线上就标出来，玩家知道自己正在走哪条线）
	var lid := str(_card.get("line", ""))
	var cap := ""
	if lid != "":
		var step := int(_state.ev_lines.get(lid, 0))
		var total: int = (Events.LINES.get(lid, {}) as Dictionary).get("steps", []).size()
		cap = "支线「" + Events.line_name(lid) + "」" + str(step) + "/" + str(total)
	var head := UiKit.make_label(panel, Vector2(0, 16), Vector2(660, 30), 20, UiKit.SEAL)
	UiKit.set_text(head, cap)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var title := UiKit.make_label(panel, Vector2(0, 48), Vector2(660, 46), 32, UiKit.INK)
	UiKit.set_text(title, str(_card.get("title", "事件")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ★ 正文——老的 event 节点写了这段却从没显示过
	var body := UiKit.make_label(panel, Vector2(46, 104), Vector2(568, 150), 21,
		Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.88))
	UiKit.set_text(body, str(_card.get("text", "")))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# 选项条：点整行即生效
	var opts: Array = _card.get("options", [])
	var y := 286.0
	for i in opts.size():
		var o: Dictionary = opts[i]
		if not _req_ok(o):
			continue
		var b := Button.new()
		b.position = Vector2(40, y)
		b.size = Vector2(580, 68)
		b.focus_mode = Control.FOCUS_NONE
		b.text = str(o.get("label", "…")) + "\n" + _sum_of(o)
		b.add_theme_font_size_override("font_size", 20)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_on_pick.bind(o))
		_style_choice(b)
		panel.add_child(b)
		y += 78.0
	if y > 560.0:
		print("[事件卡] 选项有点多，末条到 y=", y)

func _style_choice(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.42)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.30)
	sb.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", sb)
	var hv: StyleBoxFlat = sb.duplicate()
	hv.bg_color = Color(1, 1, 1, 0.72)
	hv.border_color = Color(UiKit.SEAL.r, UiKit.SEAL.g, UiKit.SEAL.b, 0.75)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", sb)
	UiKit.font_states(b, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.92))

# 条件选项（req）——比如"只有大侠能选的仗义"
func _req_ok(o: Dictionary) -> bool:
	var req: Dictionary = o.get("req", {})
	if req.is_empty():
		return true
	if req.has("karma_min") and int(_state.karma) < int(req["karma_min"]):
		return false
	if req.has("karma_max") and int(_state.karma) > int(req["karma_max"]):
		return false
	if req.has("flag") and not _state.ev_flags.has(str(req["flag"])):
		return false
	return true

# 选项下面那行小字：把后果说清（玩家不用猜）
func _sum_of(o: Dictionary) -> String:
	var segs: Array = []
	var k := int(o.get("karma", 0))
	if k > 0:
		segs.append("善 +" + str(k))
	elif k < 0:
		segs.append("恶 " + str(k))
	if o.has("money"):
		var m := int(o["money"])
		segs.append(("盘缠 +" if m > 0 else "盘缠 ") + str(m) + " 文")
	if o.has("hp_pct"):
		var h := float(o["hp_pct"])
		segs.append(("气血 +" if h > 0 else "气血 ") + str(int(h)) + "%")
	if o.has("alert"):
		segs.append("警戒 +" + str(int(o["alert"])))
	if o.has("battle"):
		segs.append("立刻开打")
	if o.has("loot"):
		segs.append("得一件" + ("残卡" if str(o["loot"]) == "card" else ("装备残片" if str(o["loot"]) == "gear" else "功法残页")))
	if o.has("item"):
		segs.append("得一整件" + ("功法" if str(o["item"]) == "art" else ("兵器" if str(o["item"]) == "weapon" else "装备")))
	if o.has("buff"):
		segs.append("得临时增益")
	if o.has("enter"):
		segs.append("接下这桩事")
	if o.has("break"):
		segs.append("这桩事到此为止")
	if segs.is_empty():
		return "无事"
	return " · ".join(PackedStringArray(segs))

# ------------------------------------------------------------
# 点了某个选项
# ------------------------------------------------------------
func _on_pick(o: Dictionary) -> void:
	_apply(o)
	_opened = false
	_host._close_overlay()
	UiKit.float_text(_host, _result_text(o), UiKit.GOLD if int(o.get("karma", 0)) >= 0 else UiKit.SEAL)
	# 该开打就先打，打完舞台会再叫回来（_choice_finish 由舞台在战后调用）
	if o.has("battle"):
		_host._choice_battle(str(o["battle"]))
		return
	_host._choice_finish()

# 后果落地：能自己改的直接改；要货/要打/要 buff 的交给舞台
func _apply(o: Dictionary) -> void:
	# ① 善恶（夹在 −100 ~ +100）
	var k := int(o.get("karma", 0))
	if k != 0:
		_state.karma = clampi(int(_state.karma) + k, -100, 100)
	# ② 盘缠
	if o.has("money"):
		_state.money = maxi(0, int(_state.money) + int(o["money"]))
	# ③ 气血（百分比；舞台那边管血条重画）
	if o.has("hp_pct"):
		_host._choice_hp(float(o["hp_pct"]))
	# ④ 警戒
	if o.has("alert"):
		_host._choice_alert(float(o["alert"]))
	# ⑤ 标记
	if o.has("flag"):
		var f := str(o["flag"])
		if not _state.ev_flags.has(f):
			_state.ev_flags.append(f)
	# ⑥ 入线 / 断线 / 线的下一步
	if o.has("enter"):
		var lid := str(o["enter"])
		_state.ev_lines[lid] = 1
		_note("支线「" + Events.line_name(lid) + "」开了头 1/" + str(_steps_of(lid)))
	elif o.has("break"):
		var lb := str(o["break"])
		if _state.ev_lines.has(lb):
			var at := int(_state.ev_lines[lb])
			_state.ev_lines.erase(lb)
			_note("支线「" + Events.line_name(lb) + "」断了——走到第 " + str(at) + " 步")
	# ⑦ 给件 / 打 / buff → 舞台
	if o.has("loot"):
		_host._choice_loot(str(o["loot"]))
	if o.has("item"):
		_host._choice_item(str(o["item"]))
	if o.has("buff"):
		_host._choice_buff(str(o["buff"]))

func _steps_of(lid: String) -> int:
	return (Events.LINES.get(lid, {}) as Dictionary).get("steps", []).size()

func _note(t: String) -> void:
	if _host != null and _host.has_method("_note_line"):
		_host._note_line(t)
	else:
		print("[支线] ", t)

func _result_text(o: Dictionary) -> String:
	var k := int(o.get("karma", 0))
	var head := ""
	if k >= 10:
		head = "善 +" + str(k) + "　"
	elif k > 0:
		head = "善 +" + str(k) + "　"
	elif k <= -10:
		head = "恶 " + str(k) + "　"
	elif k < 0:
		head = "恶 " + str(k) + "　"
	var band := ""
	if _host != null and _host.has_method("_karma_band_name"):
		band = str(_host._karma_band_name())
	return head + band
