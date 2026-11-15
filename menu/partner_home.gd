extends Control
# ============================================================
# menu/partner_home.gd —— 局外「请神」页（v2 改版）
#
# 版式沿用原页面：底图（顶栏/底栏在图里）+ 禁用技能 + 方案 + 总伤害加成 + 七格
# 改动的只有三处：
#   ① 大立绘 → 祖宗「立绘卡轮播」（中间聚焦、两侧淡出、点两侧切换）
#   ② 七格内容 → 该祖宗的技能（名字 + Lv + 星级）
#   ③ 点立绘 → 「进阶路线」弹窗（六档：星级 / 档位 / 张数 / 组合 / 状态）
# ============================================================
const AD := preload("res://kushou/ancestor_data.gd")
const GameState := preload("res://shared/game_state.gd")
const LevelState := preload("res://shared/level_state.gd")
const UI := preload("res://shared/ui_kit.gd")
# 每个技能自己的描述 + 伤害倍率（跟 battle_ui 的 SKILL_DEFS 保持一份数据）
const SKILL_DEFS := {
	"zl": {"name": "天雷道术", "dtype": "金系", "mul": 1.6, "cd": 10.0, "mp": 260.0, "targets": 3,
		"desc": "引下天雷，对 3 名敌人造成金系伤害"},
	"cuisanniang": {"name": "雾海龙王", "dtype": "召唤", "mul": 2.5, "cd": 60.0, "mp": 300.0, "targets": 1,
		"desc": "召出雾海龙王，对目标造成高额召唤伤害"},
	"jicanghai": {"name": "怒火焚身", "dtype": "火系", "mul": 1.3, "cd": 9.0, "mp": 0.0, "targets": 3,
		"desc": "怒火外放，对 3 名敌人造成火系伤害"},
	"chenshi": {"name": "刺骨", "dtype": "真实", "mul": 1.4, "cd": 8.0, "mp": 90.0, "targets": 1,
		"desc": "直刺骨髓，对单体造成真实伤害"},
	"liuqingqing": {"name": "回春", "dtype": "木系", "mul": 1.2, "cd": 12.0, "mp": 110.0, "targets": 3,
		"desc": "木系回春，对 3 名敌人造成木系伤害并回复自身"},
	"xiaoqier": {"name": "顺手", "dtype": "物理", "mul": 0.9, "cd": 5.0, "mp": 60.0, "targets": 1,
		"desc": "顺手一摸，对单体造成物理伤害"},
	"gundilong": {"name": "肉蛋冲撞", "dtype": "物理", "mul": 1.5, "cd": 6.0, "mp": 80.0, "targets": 1,
		"desc": "滚地冲撞，对单体造成物理伤害"},
	"qingluan": {"name": "青鸾飞刃", "dtype": "物理", "mul": 1.2, "cd": 8.0, "mp": 90.0, "targets": 1,
		"desc": "掷出飞刃，对直线敌人造成物理伤害"},
	"zhujue": {"name": "基础剑法", "dtype": "物理", "mul": 1.0, "cd": 0.0, "mp": 0.0, "targets": 1,
		"desc": "主角的基础剑法，对单体造成物理伤害"},
}

# 每级伤害成长：冷却越长、基础倍率越低的技能，单级成长可以高一点；高频技能低一点
const SKILL_LV_STEP := {
	"zl": 3, "cuisanniang": 5, "jicanghai": 3, "chenshi": 3, "liuqingqing": 3,
	"xiaoqier": 2, "gundilong": 2, "qingluan": 3, "zhujue": 2,
}
const W := 720.0
const H := 1280.0
const INK := Color(0.14, 0.13, 0.15)
const SEAL := Color(0.55, 0.20, 0.12)
const GOLD := Color(0.78, 0.58, 0.22)
const DIM := Color(0.42, 0.38, 0.32)
const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]

# 立绘（真正的图后面做，先用现有三张脸/立绘顶着）
const PORTRAIT := {
	"zl": "res://assets/char/chen_shi_full_cut.png",
	"cuisanniang": "res://assets/char/qingluan_full_cut.png",
	"jicanghai": "res://assets/char/player_full_cut.png",
	"zhujue": "res://assets/char/player_full_cut.png",
}

var _ids: Array = []
var _sel := 0
var _stars := {}          # 占位：祖宗星级（正式版要从存档读）
var _cards: Array = []
var _pop: Control = null
var _plan := 0
var _plan_btns: Array = []

func _ready() -> void:
	GameState.ensure_loaded()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	LevelState.ensure_loaded()
	# 只显示当前关卡已解锁的请神角色；主角始终在列表里（基础剑法）
	for aid_v in LevelState.god_ids():
		_ids.append(str(aid_v))
	if not _ids.has("zhujue"):
		_ids.append("zhujue")
	# 星级优先读局外存档；空存档才用占位
	var demo := [3, 2, 1, 2]
	for i in _ids.size():
		var aid0 := str(_ids[i])
		_stars[aid0] = int(GameState.stars.get(aid0, mini(5, demo[i] if i < demo.size() else 0)))
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/ui/partner_bg.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	UI.app_bar(self, GameState.player_name, GameState.role_grade_cn(""), func() -> void: UI.open_settings(self))
	_build_carousel()
	_build_rest()
	_build_hot()
	UI.dock(self, "god", _on_dock)

# ---------------- 立绘卡轮播 ----------------
func _build_carousel() -> void:
	for i in 3:
		var c := GodArt.new()
		c.size = Vector2(280, 372) if i == 1 else Vector2(200, 266)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.pressed.connect(func() -> void: _on_card_click(i))
		add_child(c)
		_cards.append(c)
	_refresh_carousel()

func _refresh_carousel() -> void:
	var n := _ids.size()
	if n == 0:
		return
	var order := [(_sel - 1 + n) % n, _sel, (_sel + 1) % n]
	var geo := [Vector2(-40, 176), Vector2(220, 116), Vector2(560, 176)]
	for i in 3:
		var c: GodArt = _cards[i]
		var aid := str(_ids[order[i]])
		c.aid = aid
		c.god_name = str((AD.ANCESTORS[aid] as Dictionary)["name"])
		c.skill_name = str((AD.ANCESTORS[aid] as Dictionary)["skill"])
		c.quality = int((AD.ANCESTORS[aid] as Dictionary)["quality"])
		c.dtype = str((AD.ANCESTORS[aid] as Dictionary).get("dtype", ""))
		c.stars = int(_stars.get(aid, 0))
		c.art = load(str(PORTRAIT.get(aid, "res://assets/char/player_full_cut.png")))
		c.focus = i == 1
		c.position = geo[i]
		c.size = Vector2(280, 372) if i == 1 else Vector2(200, 266)
		c.modulate = Color(1, 1, 1, 1.0 if i == 1 else 0.32)
		c.queue_redraw()

func _on_card_click(i: int) -> void:
	if i == 1:
		_show_advance()
		return
	var n := _ids.size()
	_sel = (_sel + (1 if i == 2 else -1) + n) % n
	_refresh_carousel()

# ---------------- 其余（保持原版式） ----------------
func _build_rest() -> void:
	_lbl("禁用技能(0/3)", 18, Color(0.62,0.55,0.38), Vector2(240, 516))
	_lbl("ⓘ", 18, Color(0.62,0.55,0.38), Vector2(408, 514))
	_lbl("方案", 16, Color(0.46,0.42,0.36), Vector2(40, 566))
	for i in 3:
		var b := Button.new()
		b.text = str(i + 1)
		b.position = Vector2(100.0 + float(i) * 46.0, 558)
		b.size = Vector2(40, 34)
		b.add_theme_font_size_override("font_size", 17)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_plan.bind(i))
		add_child(b)
		_plan_btns.append(b)
	_style_plan()
	_lbl("总伤害加成 0%", 24, Color(0.55,0.38,0.12), Vector2(40, 620))
	_lbl("ⓘ", 20, Color(0.55,0.48,0.34), Vector2(300, 620))
	var edit := Button.new()
	edit.text = "禁用编辑"
	edit.position = Vector2(430, 610)
	edit.size = Vector2(250, 54)
	edit.add_theme_font_size_override("font_size", 22)
	edit.focus_mode = Control.FOCUS_NONE
	var esb := StyleBoxFlat.new()
	esb.bg_color = Color(0.94,0.89,0.79,0.98)
	esb.set_corner_radius_all(4)
	esb.border_color = Color(0.65,0.46,0.20,0.9)
	esb.set_border_width_all(2)
	edit.add_theme_stylebox_override("normal", esb)
	edit.add_theme_stylebox_override("hover", esb)
	edit.add_theme_stylebox_override("pressed", esb)
	edit.add_theme_color_override("font_color", Color(0.36,0.20,0.09))
	edit.pressed.connect(func() -> void: print("[请神页] 禁用编辑"))
	add_child(edit)
	_build_slots()

# 七格：该祖宗的技能
func _build_slots() -> void:
	var n := _ids.size()
	for i in 7:
		var row := 0 if i < 4 else 1
		var col := i % 4
		var p := Vector2(36.0 + float(col) * 166.0, 690.0 + float(row) * 168.0)
		if i >= n:
			var cell := Panel.new()
			cell.position = p
			cell.size = Vector2(150, 150)
			var csb := StyleBoxFlat.new()
			csb.bg_color = Color(0.99,0.97,0.93,0.75)
			csb.set_corner_radius_all(8)
			csb.border_color = Color(0.80,0.76,0.68)
			csb.set_border_width_all(2)
			cell.add_theme_stylebox_override("panel", csb)
			add_child(cell)
			continue
		var aid := str(_ids[i])
		var a: Dictionary = AD.ANCESTORS[aid]
		var cell2 := Panel.new()
		cell2.position = p
		cell2.size = Vector2(150, 150)
		var csb2 := StyleBoxFlat.new()
		csb2.bg_color = Color(0.99,0.97,0.93,0.98)
		csb2.set_corner_radius_all(8)
		csb2.border_color = QC[clampi(int(a["quality"]) - 1, 0, 4)]
		csb2.set_border_width_all(3)
		cell2.add_theme_stylebox_override("panel", csb2)
		cell2.mouse_filter = Control.MOUSE_FILTER_STOP
		cell2.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_sel = i
				_refresh_carousel()
				_show_skill_detail(i))
		add_child(cell2)
		var tr := TextureRect.new()
		tr.position = Vector2(22, 16)
		tr.size = Vector2(106, 96)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = load(str(a["art"]))
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell2.add_child(tr)
		var nm := Label.new()
		nm.text = str(a["skill"])
		nm.position = Vector2(0, 116)
		nm.size = Vector2(150, 22)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 15)
		nm.add_theme_color_override("font_color", Color(0.30,0.26,0.20))
		cell2.add_child(nm)
		var lv := Label.new()
		lv.text = "Lv 1"
		lv.position = Vector2(96, 134)
		lv.size = Vector2(48, 18)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lv.add_theme_font_size_override("font_size", 13)
		lv.add_theme_color_override("font_color", GOLD)
		cell2.add_child(lv)

# 技能详情：点七格里的技能 → 上面立绘跳到该祖宗，同时弹详情；升级放在详情里
func _show_skill_detail(i: int) -> void:
	if i < 0 or i >= _ids.size():
		return
	var aid := str(_ids[i])
	var a: Dictionary = AD.ANCESTORS[aid]
	if _pop != null and is_instance_valid(_pop):
		_pop.queue_free()
		_pop = null
	_pop = Control.new()
	_pop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pop.mouse_filter = Control.MOUSE_FILTER_STOP
	_pop.z_index = 80
	add_child(_pop)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pop.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(90, 300)
	panel.size = Vector2(540, 470)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.85, 0.99)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.78, 0.58, 0.22)
	sb.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", sb)
	_pop.add_child(panel)
	var title := Label.new()
	title.text = "技能详情"
	title.position = Vector2(30, 18)
	title.size = Vector2(300, 40)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.30, 0.20, 0.10))
	panel.add_child(title)
	var nm := Label.new()
	nm.text = str(a["skill"])
	nm.position = Vector2(30, 72)
	nm.size = Vector2(470, 44)
	nm.add_theme_font_size_override("font_size", 32)
	nm.add_theme_color_override("font_color", Color(0.55, 0.20, 0.12))
	panel.add_child(nm)
	var owner_lb := Label.new()
	owner_lb.text = "所属：%s · %s" % [str(a["name"]), str(a.get("dtype", ""))]
	owner_lb.position = Vector2(30, 122)
	owner_lb.size = Vector2(470, 28)
	owner_lb.add_theme_font_size_override("font_size", 18)
	owner_lb.add_theme_color_override("font_color", Color(0.40, 0.36, 0.28))
	panel.add_child(owner_lb)
	var lv_lb := Label.new()
	lv_lb.text = "当前等级：Lv %d" % int(GameState.skill_lv.get(aid, 0))
	lv_lb.position = Vector2(30, 162)
	lv_lb.size = Vector2(300, 30)
	lv_lb.add_theme_font_size_override("font_size", 20)
	lv_lb.add_theme_color_override("font_color", Color(0.55, 0.38, 0.12))
	panel.add_child(lv_lb)
	# 伤害倍率：当前 → 下一级（每级只 +3%，慢慢养成）
	var sk: Dictionary = SKILL_DEFS.get(aid, {})
	var mul_pct := int(round(float(sk.get("mul", 1.0)) * 100.0))
	var sk_desc := str(sk.get("desc", ""))
	if sk_desc == "":
		sk_desc = "对 %d 名敌人造成 %s 伤害" % [int(sk.get("targets", 1)), str(sk.get("dtype", a.get("dtype", "")))]
	var desc_lb := Label.new()
	desc_lb.text = sk_desc
	desc_lb.position = Vector2(30, 196)
	desc_lb.size = Vector2(470, 26)
	desc_lb.add_theme_font_size_override("font_size", 17)
	desc_lb.add_theme_color_override("font_color", Color(0.40, 0.36, 0.28))
	panel.add_child(desc_lb)
	var dmg_lb := Label.new()
	var lv_now := int(GameState.skill_lv.get(aid, 0))
	var lv_step := int(SKILL_LV_STEP.get(aid, 3))
	var cur_pct := mul_pct + lv_now * lv_step
	var nxt_pct := cur_pct + lv_step
	dmg_lb.text = "伤害：%d%% → %d%%（%s）" % [cur_pct, nxt_pct, str(sk.get("dtype", a.get("dtype", "")))]
	dmg_lb.position = Vector2(30, 226)
	dmg_lb.size = Vector2(470, 26)
	dmg_lb.add_theme_font_size_override("font_size", 18)
	dmg_lb.add_theme_color_override("font_color", Color(0.55, 0.20, 0.12))
	panel.add_child(dmg_lb)
	var qnames := ["", "凡品", "良品", "玄品", "地品", "天品"]
	var qn: String = str(qnames[clampi(int(a["quality"]), 1, 5)])
	var cost_wen := 200
	var book_n := int(GameState.skill_books.get(qn, 0))
	# 文钱：需求 / 已有
	var coin_tex: Texture2D = load("res://assets/items/loot_silver.png")
	var coin_ic := TextureRect.new()
	coin_ic.texture = coin_tex
	coin_ic.position = Vector2(30, 266)
	coin_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_ic.stretch_mode = TextureRect.STRETCH_SCALE
	coin_ic.size = coin_tex.get_size()
	coin_ic.scale = Vector2(16.0 / maxf(1.0, coin_tex.get_width()), 16.0 / maxf(1.0, coin_tex.get_height()))
	panel.add_child(coin_ic)
	var coin_lb := Label.new()
	coin_lb.text = "文钱 %d / %d" % [cost_wen, GameState.coin("wen")]
	coin_lb.position = Vector2(52, 258)
	coin_lb.size = Vector2(420, 30)
	coin_lb.add_theme_font_size_override("font_size", 20)
	coin_lb.add_theme_color_override("font_color", Color(0.30, 0.26, 0.20))
	panel.add_child(coin_lb)
	# 技能书：需求 / 已有
	var book_tex: Texture2D = load("res://assets/items/it_book.png")
	var book_ic := TextureRect.new()
	book_ic.texture = book_tex
	book_ic.position = Vector2(30, 308)
	book_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	book_ic.stretch_mode = TextureRect.STRETCH_SCALE
	book_ic.size = book_tex.get_size()
	book_ic.scale = Vector2(16.0 / maxf(1.0, book_tex.get_width()), 16.0 / maxf(1.0, book_tex.get_height()))
	panel.add_child(book_ic)
	var book_lb := Label.new()
	book_lb.text = "%s技能书 1 / %d" % [qn, book_n]
	book_lb.position = Vector2(52, 300)
	book_lb.size = Vector2(420, 30)
	book_lb.add_theme_font_size_override("font_size", 20)
	book_lb.add_theme_color_override("font_color", Color(0.30, 0.26, 0.20))
	panel.add_child(book_lb)
	var up := Button.new()
	up.text = "升级"
	up.position = Vector2(160, 372)
	up.size = Vector2(220, 56)
	up.add_theme_font_size_override("font_size", 22)
	up.focus_mode = Control.FOCUS_NONE
	up.pressed.connect(func() -> void:
		var book := int(GameState.skill_books.get(qn, 0))
		if book <= 0 or GameState.coin("wen") < cost_wen:
			coin_lb.text = "文钱 %d / %d（不足）" % [cost_wen, GameState.coin("wen")]
			book_lb.text = "%s技能书 1 / %d（不足）" % [qn, book]
			return
		GameState.skill_books[qn] = book - 1
		GameState.coins["wen"] = int(GameState.coins.get("wen", 0)) - cost_wen
		GameState.skill_lv[aid] = int(GameState.skill_lv.get(aid, 0)) + 1
		GameState.save_progress()
		_pop.queue_free()
		_pop = null
		_show_skill_detail(i)
		_build_slots()
	)
	panel.add_child(up)
	var close := Button.new()
	close.text = "×"
	close.position = Vector2(472, 16)
	close.size = Vector2(44, 40)
	close.add_theme_font_size_override("font_size", 22)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void:
		_pop.queue_free()
		_pop = null
	)
	panel.add_child(close)

func _lbl(t: String, fs: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.size = Vector2(420, fs + 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _style_plan() -> void:
	for i in _plan_btns.size():
		var b: Button = _plan_btns[i]
		var on := i == _plan
		var sb := StyleBoxFlat.new()
		sb.bg_color = SEAL if on else Color(0.91,0.88,0.82)
		sb.set_corner_radius_all(4)
		sb.border_color = GOLD if on else Color(0.78,0.73,0.64)
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(0.96,0.92,0.80) if on else Color(0.30,0.27,0.22))

func _on_plan(i: int) -> void:
	_plan = i
	_style_plan()

# ---------------- 进阶路线弹窗 ----------------
func _show_advance() -> void:
	if _pop != null and is_instance_valid(_pop):
		_pop.queue_free()
		_pop = null
	var aid := str(_ids[_sel])
	var a: Dictionary = AD.ANCESTORS[aid]
	var star := int(_stars.get(aid, 0))
	_pop = Control.new()
	_pop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pop.mouse_filter = Control.MOUSE_FILTER_STOP
	_pop.z_index = 80
	add_child(_pop)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.03, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_pop())
	_pop.add_child(dim)
	var b := Rect2(Vector2(40, 150), Vector2(640, 930))
	var box := Panel.new()
	box.position = b.position
	box.size = b.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.975, 0.955, 0.915, 1.0)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.72, 0.53, 0.16)
	sb.set_border_width_all(3)
	box.add_theme_stylebox_override("panel", sb)
	_pop.add_child(box)
	# 头像
	var ph := Panel.new()
	ph.position = Vector2(26, 24)
	ph.size = Vector2(190, 246)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.90, 0.86, 0.77)
	psb.set_corner_radius_all(6)
	psb.border_color = QC[clampi(int(a["quality"]) - 1, 0, 4)]
	psb.set_border_width_all(3)
	ph.add_theme_stylebox_override("panel", psb)
	box.add_child(ph)
	var pt := TextureRect.new()
	pt.position = Vector2(6, 6)
	pt.size = Vector2(178, 234)
	pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pt.texture = load(str(PORTRAIT.get(aid, "")))
	ph.add_child(pt)
	_push_label(box, str(a["name"]), 32, INK, Vector2(238, 40))
	_push_label(box, "%s · %s" % [grade_cn(int(a["quality"])), str(a.get("dtype", ""))], 15, DIM, Vector2(238, 82))
	_push_label(box, "%d ★" % star, 20, Color(0.55, 0.40, 0.16), Vector2(238, 112))
	_push_label(box, "来 历", 14, Color(0.55, 0.40, 0.16), Vector2(238, 150))
	_push_label(box, "请神上身，代代相传。", 15, Color(0.28, 0.24, 0.19), Vector2(238, 176), 360)
	# 路线
	_push_label(box, "进 阶 路 线", 20, Color(0.55, 0.30, 0.12), Vector2(26, 292))
	_push_label(box, "每档独立：集齐 3 张 → 组合 → 清空", 14, DIM, Vector2(174, 292), 440)
	# 角色进阶：消耗角色碎片，升 1 星
	var shard_n := int(GameState.shards.get(aid, 0))
	var adv_wen := 500
	var wen_now := GameState.coin("wen")
	var up_btn := Button.new()
	up_btn.text = "进阶（碎片 60 / 已有 %d　·　文钱 %d / 已有 %d）" % [shard_n, adv_wen, wen_now]
	up_btn.position = Vector2(26, 846)
	up_btn.size = Vector2(588, 56)
	up_btn.add_theme_font_size_override("font_size", 19)
	up_btn.focus_mode = Control.FOCUS_NONE
	up_btn.disabled = shard_n < 60 or wen_now < adv_wen
	up_btn.pressed.connect(func() -> void:
		if int(GameState.shards.get(aid, 0)) < 60 or GameState.coin("wen") < adv_wen:
			return
		GameState.shards[aid] = int(GameState.shards.get(aid, 0)) - 60
		GameState.coins["wen"] = GameState.coin("wen") - adv_wen
		GameState.stars[aid] = mini(5, int(GameState.stars.get(aid, _stars.get(aid, 0))) + 1)
		_stars[aid] = int(GameState.stars[aid])
		GameState.save_progress()
		_close_pop()
		_show_advance()
		_build_slots()
	)
	box.add_child(up_btn)
	var tiers: Array = a["tiers"]
	var y := 312.0
	for t in tiers.size():
		var tier: Dictionary = tiers[t]
		var done := t < star
		var cur := t == star
		var rp := Panel.new()
		rp.position = Vector2(26, y)
		rp.size = Vector2(588, 78)
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0.99, 0.965, 0.88) if cur else (Color(0.90, 0.86, 0.77) if done else Color(0.95, 0.92, 0.865))
		rsb.set_corner_radius_all(6)
		if cur:
			rsb.border_color = Color(0.82, 0.50, 0.12, 0.85)
			rsb.set_border_width_all(2)
		rp.add_theme_stylebox_override("panel", rsb)
		box.add_child(rp)
		var lc := Color(0.55, 0.40, 0.16) if (done or cur) else Color(0.62, 0.57, 0.48)
		_push_label(rp, "%d★" % t, 21, lc, Vector2(14, 24))
		_push_label(rp, "%s · 3 张" % str(AD.TIER_NAMES[t]), 18, INK if (done or cur) else Color(0.45, 0.41, 0.35), Vector2(72, 6))
		_push_label(rp, str(tier["combo_text"]), 14, Color(0.45, 0.41, 0.35), Vector2(72, 36), 380)
		var st := "已完成" if done else ("进行中" if cur else "未解锁")
		var sc := Color(0.20, 0.50, 0.28) if done else (Color(0.66, 0.18, 0.12) if cur else Color(0.58, 0.53, 0.45))
		var sl := Label.new()
		sl.text = st
		sl.position = Vector2(430, 28)
		sl.size = Vector2(140, 26)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sl.add_theme_font_size_override("font_size", 16)
		sl.add_theme_color_override("font_color", sc)
		rp.add_child(sl)
		y += 86.0
	_push_label(box, "0★ 时可抽全套 18 张，每张 4% 掷「炫卡」", 14, Color(0.66, 0.18, 0.12), Vector2(26, y + 6), 580)
	var close := Button.new()
	close.text = "关 闭"
	close.position = Vector2(214, 856)
	close.size = Vector2(200, 54)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_close_pop)
	box.add_child(close)

func _close_pop() -> void:
	if _pop != null and is_instance_valid(_pop):
		_pop.queue_free()
		_pop = null

func _push_label(parent: Control, t: String, fs: int, col: Color, pos: Vector2, w := 260.0) -> void:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = Vector2(w, fs + 12)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)

func grade_cn(q: int) -> String:
	return ["凡品", "良品", "玄品", "地品", "绝品"][clampi(q - 1, 0, 4)]

# ---------------- 热区（顶栏 / 底栏） ----------------
func _build_hot() -> void:
	_hot(Rect2(10, 6, 240, 76), func() -> void: get_tree().change_scene_to_file("res://menu/main_home.tscn"))
	_hot(Rect2(630, 20, 82, 50), func() -> void: print("[请神页] 设置"))

func _on_dock(key: String) -> void:
	match key:
		"start":
			get_tree().change_scene_to_file("res://menu/main_home.tscn")
		"role":
			get_tree().change_scene_to_file("res://menu/character_home.tscn")
		"curio":
			get_tree().change_scene_to_file("res://menu/curio_home.tscn")

func _hot(rect: Rect2, cb: Callable) -> void:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	add_child(b)

# ============================================================
# 立绘卡
# ============================================================
class GodArt extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal pressed
	var aid := ""
	var god_name := ""
	var skill_name := ""
	var dtype := ""
	var quality := 5
	var stars := 0
	var focus := false
	var art: Texture2D = null
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var qc: Color = QC[clampi(quality - 1, 0, 4)]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.972, 0.958, 0.930, 1.0)
		sb.set_corner_radius_all(12 if focus else 9)
		sb.border_color = qc
		sb.set_border_width_all(4 if focus else 2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if art != null:
			var pad := 10.0 if focus else 8.0
			var ar := Rect2(Vector2(pad, pad), size - Vector2(pad * 2.0, pad * 2.0 - 26.0))
			var ts := art.get_size()
			var sc: float = minf(ar.size.x / ts.x, ar.size.y / ts.y)
			draw_texture_rect(art, Rect2(ar.position + Vector2((ar.size.x - ts.x * sc) * 0.5, 0), Vector2(ts.x * sc, ts.y * sc)), false)
		# 竖排名牌
		var pw := 28.0 if focus else 22.0
		var phh := 26.0 * float(maxi(1, god_name.length())) + 10.0
		var pp := Rect2(Vector2(14, 14), Vector2(pw, phh))
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color(0.98, 0.96, 0.92, 0.92)
		psb.set_corner_radius_all(4)
		psb.border_color = Color(0.70, 0.60, 0.42, 0.8)
		psb.set_border_width_all(1)
		draw_style_box(psb, pp)
		for i in god_name.length():
			draw_string(F, pp.position + Vector2(4, 24.0 + float(i) * 26.0), god_name.substr(i, 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18 if focus else 15, Color(0.14, 0.13, 0.15))
		# 品质章
		var qs := 34.0 if focus else 26.0
		var qp := Rect2(Vector2(size.x - qs - 12, size.y - qs - 40), Vector2(qs, qs))
		var qsb := StyleBoxFlat.new()
		qsb.bg_color = qc
		qsb.set_corner_radius_all(4)
		draw_style_box(qsb, qp)
		draw_string(F, qp.position + Vector2(0, qs * 0.72), ["凡","良","玄","地","天"][clampi(quality - 1, 0, 4)],
			HORIZONTAL_ALIGNMENT_CENTER, qs, 17 if focus else 13, Color(0.99, 0.96, 0.88))
		# 星级（画在图上）
		if focus:
			var cy := size.y - 22.0
			for i in 5:
				_star(Vector2(size.x * 0.5 - 40.0 + float(i) * 20.0, cy), 7.0, i < stars)
	func _star(c: Vector2, r: float, filled: bool) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var ang := -PI * 0.5 + float(i) * PI / 5.0
			var rr := r if i % 2 == 0 else r * 0.42
			pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
		if filled:
			draw_colored_polygon(pts, GOLD)
		else:
			pts.append(pts[0])
			draw_polyline(pts, Color(0.55, 0.48, 0.38, 0.6), 1.2, true)
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
