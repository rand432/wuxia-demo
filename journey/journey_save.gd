extends RefCounted
# ============================================================
# journey_save.gd —— 续行存档 v1（R4 ④b）
# 单档位、覆盖式；只存安全点：进节点／正事办完（容器摆出）／搜刮关板。
# 结算页一开就抹（成功、殒命都抹——这趟已结束）；菜单选「重新开始」也抹。
# 档 = run_state 整局快照 + 舞台侧（节点表／第几节／正事办完没／容器残局）。
# 读档：菜单【游历】见档 → 询问 → 继续＝快照进 pending → 切游历场 →
#   舞台 _ready 见 pending → apply_resume() 原地接上（弹窗一律关着）。
# 不引 journey_stage（防循环——老铁律）；舞台侧数据用"传舞台引用"的件式写法。
# ============================================================

const UiKit := preload("res://shared/ui_kit.gd")
const GameState := preload("res://shared/game_state.gd")

const PATH := "user://run.cfg"
const BAK := "user://run.bak"
const VER := 1
const VER_MIN := 1   # ㉙：还能迁移的最老版本（现在没有历史版本，v1 就是第一版）

static var _pending: Dictionary = {}
static var _from_bak := false   # 这次是拿备份接上的——下一笔落盘不许拿它盖备份

# ---- 文件读写 ----

static func has_save() -> bool:
	return not read_save().is_empty()

# ㉙：版本不对不再"静默当没档"——比本程序新的档改名留档（不删），
#   因为那多半是玩家在新版里走到一半的趟，静默丢掉等于抹了他的进度。
static func read_save() -> Dictionary:
	var tried: Array = [PATH, BAK]
	for i in tried.size():
		var path := str(tried[i])
		var cf := ConfigFile.new()
		if cf.load(path) != OK:
			continue
		var v := int(cf.get_value("save", "ver", 0))
		if v < VER_MIN or v > VER:
			if v > VER:
				var keep := path + ".v" + str(v) + ".bak"
				var da := DirAccess.open("user://")
				if da != null:
					da.rename(path.get_file(), keep.get_file())
					print("[续行] 档版本 ", v, " 比本程序（", VER, "）新，读不了。")
					print("[续行] 已改名留档：", keep, "（没删——换回新版程序还能接着走）")
			continue   # 这份认不出来，试下一份
		var d: Variant = cf.get_value("save", "data", {})
		if typeof(d) != TYPE_DICTIONARY or not (d as Dictionary).has("state"):
			continue
		if i == 1:
			print("[续行] 正式档读不出来——已用备份 run.bak 接上")
			_from_bak = true
		else:
			_from_bak = false
		return d
	return {}

static func write_save(snap: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.set_value("save", "ver", VER)
	cf.set_value("save", "data", snap)
	# 优化批㉖：备份 + "写 .tmp → 验 → 顶掉"，跟村账同一套（见 game_state.safe_write）
	if not _from_bak:
		GameState._keep_backup(PATH, BAK)
	if GameState.safe_write(PATH, cf, "save", "ver", VER):
		_from_bak = false
	else:
		print("[续行] 这趟的档没写成功——上一次的还在（run.cfg / run.bak）")

static func erase() -> void:
	var da := DirAccess.open("user://")
	if da == null:
		return
	var removed := 0
	for f in ["run.cfg", "run.bak", "run.cfg.tmp"]:
		if da.file_exists(f):
			da.remove(f)
			removed += 1
	_from_bak = false
	if removed > 0:
		print("[续行] 档已抹（含备份，共 ", removed, " 个文件）")

# ---- 舞台侧：存（舞台在三个安全点各调一次） ----

static func save_run(host) -> void:
	if host._state == null:
		return
	var snap := {
		"state": host._state.to_save(),
		"nodes": host._nodes,
		"node": int(host._node),
		"node_done": bool(host._node_done),
		"node_entered": bool(host._node_entered),
		"containers": host._loot_containers,
	}
	write_save(snap)
	GameState.save_game()   # 优化批㉒：每条安全点顺手把村账落盘（宠/血脉/仓库不再看时机）
	print("[续行] 已存：第 ", int(host._node) + 1, " 节 · 盘缠 ", int(host._state.money), " 文")

# ---- 菜单侧：快照交接 ----

static func set_pending(snap: Dictionary) -> void:
	_pending = snap

static func has_pending() -> bool:
	return not _pending.is_empty()

# ---- 舞台侧：接上（舞台 _ready 里调） ----

static func apply_resume(host) -> void:
	var snap: Dictionary = _pending
	_pending = {}
	host._state.resume_from(snap.get("state", {}))
	if snap.has("nodes"):
		host._nodes = snap["nodes"]
	host._build()
	host._hide_ui_all()
	host._phase = "journey"
	host._node = clampi(int(snap.get("node", 0)), 0, maxi(0, host._nodes.size() - 1))
	host._reset_run_hud()
	host._told_card = true
	host._just_synth = false
	host._shop_active = false
	host._show_ui_all()
	host._enter_node()
	# v2（v35 配套）：开局行装那一页是"摆出来就落盘"的——万一在下手之前被强杀/切后台回收，
	#   接档时补摆一次（kit_taken 没记上就说明还没领）。领过的人这里一个字都不会发生。
	if str(host._state.mode) == "formal" and not bool(host._state.kit_taken):
		host._open_start_kit()
	host._node_done = bool(snap.get("node_done", false))
	var cont: Array = snap.get("containers", [])
	host._loot_containers = cont
	if host._node_done and not cont.is_empty():
		host._show_loot_row()
	host._node_entered = bool(snap.get("node_entered", false))
	# ④b 堵口：上次是"本节摆出来了、还没走完"时被关掉（手机强杀／切后台被回收）——
	#   若照旧重摆一遍，同一节的事件／战斗／精英三抽就能反复领。这里判它已办：直接赶路。
	#   （"办完了还有容器没搜"那种残局走上面的 node_done 分支，不进这里。）
	if host._node_entered and not host._node_done and cont.is_empty():
		host._node_entered = false
		host._loot_leave_tap()
		host._refresh_all()
		host._refresh_alert()
		save_run(host)
		print("[续行] 第 ", int(host._node) + 1, " 节是上次没走完的那一节——判作已过，不重摆")
		return
	host._refresh_all()
	host._refresh_alert()
	save_run(host)   # ④b 螺丝：复位后再落一次盘——"办完/容器残局"写成真相（_enter_node 那笔是中间态）
	print("[续行] 已接上：第 ", int(host._node) + 1, " 节 · 办完=", host._node_done, " · 容器 ", cont.size(), " 个")
	if host._node_done and not cont.is_empty():
		UiKit.float_text(host, "接着搜——还剩 " + str(host._loot_pending()) + " 件", UiKit.INK)
	else:
		UiKit.float_text(host, "续行——接着赶路", UiKit.GOLD)

# ---- 菜单侧：续行询问框 ----

static func show_prompt(host: Control, scene_path: String, on_fresh: Callable) -> void:
	var snap := read_save()
	if snap.is_empty():
		on_fresh.call()
		return
	var st: Dictionary = snap.get("state", {})
	var vp := host.get_viewport_rect().size
	var veil := UiKit.make_veil(host, vp, 0.45)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(_prompt_dismiss.bind(veil))
	var pw := 560.0
	var ph := 360.0
	var panel := UiKit.make_paper_panel(veil, Rect2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5, pw, ph))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var t1 := UiKit.make_label(panel, Vector2(0, 20), Vector2(pw, 40), 28, UiKit.INK)
	UiKit.set_text(t1, "江湖未完")
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var mode_txt := "引子趟"
	if str(st.get("mode", "intro")) == "formal":
		mode_txt = GameState.diff_name(int(st.get("diff", 1)))
	var total := 0
	if snap.has("nodes"):
		total = (snap["nodes"] as Array).size()
	var line := "上一趟还没走完：\n\n"
	line += "　" + mode_txt + " · 走到第 " + str(int(snap.get("node", 0)) + 1) + "/" + str(total) + " 节\n"
	line += "　盘缠 " + str(int(st.get("money", 0))) + " 文 · 包裹 " + str((st.get("bag", []) as Array).size()) + " 件\n"
	line += "　临时仓库 " + str((st.get("loot_bag", []) as Array).size()) + " 件\n\n"
	line += "接着走，还是从头来？"
	var body := UiKit.make_label(panel, Vector2(40, 74), Vector2(pw - 80.0, 180), 18, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.90))
	UiKit.set_text(body, line)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var go := UiKit.make_button(panel, Vector2(48, ph - 74.0), Vector2(220, 54), "继续", 22)
	go.pressed.connect(_do_continue.bind(host, scene_path, snap, veil))
	var fresh := UiKit.make_button(panel, Vector2(pw - 268.0, ph - 74.0), Vector2(220, 54), "重新开始", 22)
	fresh.pressed.connect(_do_fresh.bind(veil, on_fresh))

static func _do_continue(host: Control, scene_path: String, snap: Dictionary, veil: Control) -> void:
	set_pending(snap)
	var err := host.get_tree().change_scene_to_file(scene_path)
	if err != OK:
		print("[续行] 打不开游历，错误码=", err, "；检查路径：", scene_path)
		_pending = {}
	if veil != null and is_instance_valid(veil):
		veil.queue_free()

static func _do_fresh(veil: Control, on_fresh: Callable) -> void:
	erase()
	if veil != null and is_instance_valid(veil):
		veil.queue_free()
	on_fresh.call()

static func _prompt_dismiss(ev: InputEvent, veil: Control) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if veil != null and is_instance_valid(veil):
				veil.queue_free()
