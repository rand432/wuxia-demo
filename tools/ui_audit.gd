extends SceneTree
# probe_ks950：全弹窗 UI 巡检（客观量法）
#   对每个 Label 用字体实测文本宽度 → 跟控件宽度比：
#     · 没开 autowrap 且 宽 > 框宽        → **溢出**（会裁字/压隔壁）
#     · 开了 autowrap 但 高 > 框高        → **折行放不下**（会裁行）
#   同时统计最小字号，守住 §6.4 基线。
var _k = null
var _layer: CanvasLayer = null
var _f := 0
var _kinds: Array = []
var _i := 0
var _phase := 0            # 0 开下一个 · 1 量
var _bad: Array = []
var _minsize := 99
var _nlabel := 0

func _initialize() -> void:
	_layer = CanvasLayer.new()
	get_root().add_child(_layer)
	_k = (load("res://kushou/kushou_v2.gd") as GDScript).new()
	_layer.add_child(_k)
	_k._meta_path = "user://probe_meta.cfg"
	_k.open()
	# ⚠ v18k：抽卡**不是弹窗**了（改成战场区里的一页）→ 从这个清单里拿掉，另在最后单独量它
	_kinds = ["设置", "挑战", "任务", "卡组", "存档", "成就", "黑市", "角色", "技能", "装备",
		"招募", "成长武器", "图鉴", "羁绊详情", "装备详情", "宝物详情", "当前宝物", "宝物三选一",
		"关卡", "局终", "卡组合计", "卡牌详情", "成长武器详情", "仓库"]

func _walk(n: Node, kind: String) -> void:
	for c in n.get_children():
		if c is Label:
			var lb: Label = c
			_nlabel += 1
			var fs := lb.get_theme_font_size("font_size")
			if fs > 0 and fs < _minsize:
				_minsize = fs
			var w := lb.size.x
			var f := lb.get_theme_font("font")
			var txt := lb.text
			if txt != "" and w > 1.0 and f != null:
				var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var wrap := lb.autowrap_mode != TextServer.AUTOWRAP_OFF
				if not wrap and tw > w + 2.0:
					_bad.append("[溢出] " + kind + " 字号" + str(fs) + " 需要 " + str(int(tw)) + "px / 框 " + str(int(w))
						+ "px　「" + txt.substr(0, 26) + "」")
				elif wrap and lb.get_line_count() * float(fs + 4) > lb.size.y + 6.0:
					_bad.append("[折行超框] " + kind + " 字号" + str(fs) + " 行数 " + str(lb.get_line_count())
						+ " / 框高 " + str(int(lb.size.y)) + "　「" + txt.substr(0, 26) + "」")
		_walk(c, kind)

func _process(_d: float) -> bool:
	_f += 1
	if _f < 4:
		return false
	if _phase == 0:
		if _i >= _kinds.size():
			# v18k：抽卡页（铺在战场区那层，不是弹窗）也量一遍
			# v18s：四种三选一页（抽卡/宝物/进阶/技能）都量一遍
			if _k._draw_page != null:
				for pk in ["抽卡", "宝物", "进阶", "技能"]:
					if pk == "技能":
						_k._skill_pts = 1
					if pk == "进阶":
						_k._wpn_await = true
						_k._wpn_roll_choices()
					_k._open_pick_page(str(pk))
					_walk(_k._draw_page, str(pk) + "页")
					_k._close_draw_page()
			print("=== UI 巡检结果 ===")
			print("[k950] 查了 " + str(_kinds.size()) + " 个弹窗 ＋ 抽卡页 / " + str(_nlabel) + " 个 Label · 最小字号 " + str(_minsize))
			print("[k950] 问题 " + str(_bad.size()) + " 处：")
			for b_v in _bad:
				print("[k950]   " + str(b_v))
			OS.delay_msec(200)
			quit(0)
			return false
		_k._open_large(str(_kinds[_i]))
		_phase = 1
		return false
	# 量一帧（等布局算完）
	_walk(_k._popup if _k._popup != null else _k, str(_kinds[_i]))
	_k._close_popup()
	_i += 1
	_phase = 0
	return false
