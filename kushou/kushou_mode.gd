extends Control
# ============================================================
# kushou_mode.gd —— 「困兽」v1 试玩面板
#   开局（角色→门派→开局签）→ 牌桌（24 格＋商店）→ 自动波次 → 35 波通关
#   ⚠ v1 试玩：战斗=自动对撞结算；火柴人演出后接
# ============================================================

const Kushou := preload("res://kushou/data_kushou.gd")

const INK := Color(0.14, 0.13, 0.15)
const PAPER := Color(0.905, 0.878, 0.795)
const SEAL := Color(0.68, 0.15, 0.12)
const Q_COL := [Color(0.45, 0.44, 0.42), Color(0.32, 0.55, 0.42), Color(0.30, 0.45, 0.68), Color(0.62, 0.45, 0.20), Color(0.75, 0.22, 0.15)]

const GRID_X0 := 40.0
const GRID_Y0 := 250.0
const CELL_W := 156.0
const CELL_H := 96.0

# ---- 运行状态 ----
var _hero := "player"
var _school := ""
var _sign := ""
var _life := 100
var _money := 5000
var _wave := 1
var _have: Array = []
var _grid_cap := 24
var _revive := 1          # 浴血：免死次数（通关 Boss +1）
var _growth := 0          # 浴血成长（每次归零 +1 全攻血）
var _total_settled := 0   # 受咒的赏钱：累计结算
var _offer: Array = []    # 商店当前 4 张
var _ban_mix := false     # 断绝杂学
var _ban_school := ""     # 贪功删掉的门派
var _free_draw := 0
var _free_refresh := 0
var _hero_hp := 100.0
var _over := false

var _root: Control
var _top_lb: Label
var _grid_box: Control
var _shop_lb: Label
var _msg_lb: Label
var _pick_veil: Control
var _cells: Array = []

func _ready() -> void:
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_open_pick_hero()

# ---------- 界面 ----------

func _label(parent: Node, pos: Vector2, sz: Vector2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var lb := Label.new()
	lb.position = pos
	lb.size = sz
	lb.add_theme_font_size_override("font_size", fs)
	lb.add_theme_color_override("font_color", col)
	lb.horizontal_alignment = align
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lb)
	return lb

func _btn(parent: Node, pos: Vector2, sz: Vector2, txt: String, fs: int, cb: Callable) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.text = txt
	b.add_theme_font_size_override("font_size", fs)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.21, 0.19, 0.20, 0.96)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	parent.add_child(b)
	return b

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.09, 0.085, 1)
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_root = Control.new()
	_root.position = Vector2.ZERO
	_root.size = size
	add_child(_root)
	_top_lb = _label(_root, Vector2(30, 14), Vector2(660, 40), 24, Color(0.94, 0.91, 0.84))
	_shop_lb = _label(_root, Vector2(30, 150), Vector2(660, 90), 15, Color(INK.r, INK.g, INK.b, 0.92))
	_grid_box = Control.new()
	_grid_box.position = Vector2(GRID_X0, GRID_Y0)
	_grid_box.size = Vector2(640, 500)
	_root.add_child(_grid_box)
	_msg_lb = _label(_root, Vector2(30, 830), Vector2(660, 60), 17, Color(SEAL.r, SEAL.g, SEAL.b, 0.95))
	_msg_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_btn(_root, Vector2(30, 900), Vector2(150, 56), "刷新 500", 17, _on_refresh)
	_btn(_root, Vector2(196, 900), Vector2(150, 56), "抽卡 1000", 17, _on_draw)
	_btn(_root, Vector2(362, 900), Vector2(150, 56), "断绝 2000", 17, _on_ban)
	_btn(_root, Vector2(528, 900), Vector2(150, 56), "下一波 ▸", 17, _on_next_wave)
	_refresh()

# ---------- 开局 ----------

func _open_pick_hero() -> void:
	var v := _make_veil("选人——牢里这一队，谁先上场？")
	var x := 40.0
	for hid in Kushou.HEROES.keys():
		var h: Dictionary = Kushou.HEROES[hid]
		var b := _btn(v, Vector2(x, 150), Vector2(180, 96), str(h["name"]) + "\n攻" + str(h["atk"]) + " · 血" + str(h["hp"]) + "\n暴" + str(h["crit"]) + "% · 闪" + str(h["dodge"]) + "%", 16, _pick_hero.bind(str(hid)))
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		x += 200.0

func _pick_hero(hid: String) -> void:
	_hero = hid
	_free_veil()
	_open_pick_school()

func _open_pick_school() -> void:
	var v := _make_veil("拜师——牢里藏龙卧虎，拜哪一路？")
	_btn(v, Vector2(60, 150), Vector2(180, 96), "少林\n长线 · 刚猛", 17, _pick_school.bind("shaolin"))
	_btn(v, Vector2(270, 150), Vector2(180, 96), "唐门\n中线 · 毒械", 17, _pick_school.bind("tangmen"))
	_btn(v, Vector2(480, 150), Vector2(180, 96), "丐帮\n短线 · 快打", 17, _pick_school.bind("gaibang"))

func _pick_school(s: String) -> void:
	_school = s
	_free_veil()
	_open_pick_sign()

func _open_pick_sign() -> void:
	var v := _make_veil("挑一张开局签？（自虐换收益 · 可不挑）")
	var x := 40.0
	for sid in Kushou.STARTER_SIGNS.keys():
		var s: Dictionary = Kushou.STARTER_SIGNS[sid]
		var b := _btn(v, Vector2(x, 150), Vector2(200, 130), str(s["name"]) + "\n" + str(s["desc"]), 13, _pick_sign.bind(str(sid)))
		x += 218.0
	_btn(v, Vector2(270, 360), Vector2(180, 56), "空手进场", 17, _pick_sign.bind(""))

func _pick_sign(sid: String) -> void:
	_sign = sid
	if sid == "greedy":
		var schools := ["shaolin", "tangmen", "gaibang"]
		schools.erase(_school)
		_ban_school = str(schools[randi() % schools.size()])
		_msg_lb.text = "【贪功】永久删掉了「" + _school_cn(_ban_school) + "」一路——它家的武功不再入池"
	_free_veil()
	_refresh()

func _make_veil(title: String) -> Control:
	_pick_veil = Control.new()
	_pick_veil.position = Vector2.ZERO
	_pick_veil.size = size
	_pick_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.055, 0.05, 0.96)
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_pick_veil.add_child(bg)
	add_child(_pick_veil)
	_label(_pick_veil, Vector2(40, 80), Vector2(640, 40), 26, Color(0.94, 0.91, 0.84), HORIZONTAL_ALIGNMENT_CENTER).text = title
	return _pick_veil

func _free_veil() -> void:
	if _pick_veil != null and is_instance_valid(_pick_veil):
		_pick_veil.queue_free()
	_pick_veil = null

# ---------- 商店 ----------

func _school_cn(s: String) -> String:
	return {"shaolin": "少林", "tangmen": "唐门", "gaibang": "丐帮"}.get(s, s)

func _roll_offer() -> void:
	_offer = []
	var ids: Array = []
	for cid in Kushou.CARDS.keys():
		var c: Dictionary = Kushou.CARDS[cid]
		var cs := str(c.get("school", ""))
		if _ban_school != "" and cs == _ban_school:
			continue
		if _ban_mix and cs != _school:
			continue
		if Kushou.can_offer(cid, _have):
			ids.append(cid)
	ids.shuffle()
	for i in mini(4, ids.size()):
		_offer.append(str(ids[i]))

func _on_refresh() -> void:
	if _over:
		return
	var price := 500
	if _free_refresh > 0:
		_free_refresh -= 1
		price = 0
	elif _money < price:
		_msg_lb.text = "文钱不够：刷新要 " + str(price) + "（现有 " + str(_money) + "）"
		return
	_money -= price
	_roll_offer()
	_msg_lb.text = "刷新了货架（" + ("免费" if price == 0 else "花 " + str(price) + " 文") + "）"
	_refresh()

func _on_draw() -> void:
	if _over:
		return
	var price := 1000
	if _free_draw > 0:
		_free_draw -= 1
		price = 0
	elif _money < price:
		_msg_lb.text = "文钱不够：抽卡要 " + str(price) + "（现有 " + str(_money) + "）"
		return
	if _offer.is_empty():
		_roll_offer()
	if _offer.is_empty():
		_msg_lb.text = "没有可抽的卡了"
		return
	var cid := str(_offer[randi() % _offer.size()])
	_offer.erase(cid)
	if _have.size() >= _grid_cap:
		_msg_lb.text = "武学格满了（" + str(_have.size()) + "/" + str(_grid_cap) + "）——先拿能开格的卡"
		return
	_money -= price
	_have.append(cid)
	var d: Dictionary = Kushou.deck_stats(_have)
	var dg := int(d.get("draw_growth", 0))
	if dg > 0:
		_msg_lb.text = "学到「" + str(Kushou.CARDS[cid]["name"]) + "」！偷师：攻/血各 +" + str(dg) + "（抽卡成长）"
	else:
		_msg_lb.text = "学到「" + str(Kushou.CARDS[cid]["name"]) + "」！"
	_refresh()

func _on_ban() -> void:
	if _over:
		return
	if _money < 2000:
		_msg_lb.text = "文钱不够：断绝杂学要 2000"
		return
	_money -= 2000
	_ban_mix = not _ban_mix
	_msg_lb.text = ("已【断绝杂学】——本局卡池只出本派与散件" if _ban_mix else "已重新开门——杂学回到卡池")
	_roll_offer()
	_refresh()

# ---------- 波次 ----------

func _on_next_wave() -> void:
	if _over or _school == "":
		return
	_battle(_wave)
	if _over:
		return
	_settle()
	_wave += 1
	_refresh()

func _monster_of(w: int) -> Dictionary:
	var bs := [10, 15, 20, 25, 30, 35]
	var bi := bs.find(w)
	if bi >= 0:
		return Kushou.BOSSES[bi]
	var m: Dictionary = Kushou.MONSTERS[(w - 1) % Kushou.MONSTERS.size()]
	var scale := 1.0 + 0.15 * float(w - 1)
	var out := m.duplicate()
	out["atk"] = int(round(float(m["atk"]) * scale))
	out["hp"] = int(round(float(m["hp"]) * scale))
	if _sign == "arrogant":
		out["atk"] = int(round(float(out["atk"]) * 1.5))
		out["hp"] = int(round(float(out["hp"]) * 1.5))
	return out

func _hero_stats() -> Dictionary:
	var h: Dictionary = Kushou.HEROES[_hero]
	var d: Dictionary = Kushou.deck_stats(_have)
	var atk := int(h["atk"]) + int(d["atk"]) + _growth * 2
	var hp := int(h["hp"]) + int(d["hp"]) + _growth * 20
	var dmg := float(d["dmg"]) - float(d["neg_dmg"])
	var aspd := float(d["aspd"]) - float(d["neg_aspd"])
	return {"atk": atk, "hp": hp, "dmg": dmg, "aspd": aspd, "crit": int(h["crit"]) + int(d["crit"]),
		"dodge": int(h["dodge"]) + int(d["dodge"]), "taken": int(d["taken"]), "regen": int(d["regen"])}

func _battle(w: int) -> void:
	var m := _monster_of(w)
	var hs := _hero_stats()
	var hero_dps := float(hs["atk"]) * (1.0 + float(hs["dmg"]) / 100.0) * (1.0 + float(hs["aspd"]) / 100.0) * (1.0 + float(hs["crit"]) / 100.0 * 0.5)
	var mon_dps := float(m["atk"]) * (1.0 - float(hs["taken"]) / 100.0) * (1.0 - float(hs["dodge"]) / 100.0)
	if hero_dps < 0.5:
		hero_dps = 0.5
	var t := float(m["hp"]) / hero_dps
	var lost := int(round(mon_dps * t))
	_hero_hp = float(hs["hp"]) - float(lost)
	if _hero_hp > 0.0:
		_msg_lb.text = "第 " + str(w) + " 波 · " + str(m["name"]) + " 倒——你损血 " + str(lost) + "（剩 " + str(int(_hero_hp)) + "）"
		return
	# 角色倒下 → 玩家生命 -15 → 归 0 走浴血
	_msg_lb.text = "第 " + str(w) + " 波 · " + str(m["name"]) + " 把你打趴了……玩家生命 -15"
	_life -= 15
	if _life <= 0:
		if _revive > 0:
			_revive -= 1
			_life = 10
			_growth += 1
			_msg_lb.text += "\n【浴血】观众赌你死——你偏爬起来：免死（剩 " + str(_revive) + " 次），全攻 +2 全血 +20！"
		else:
			_life = 0
			_over = true
			_msg_lb.text += "\n免死用尽——你死在了笼子里。观众散场。"
			return
	# 爬起来接着打这一波
	_hero_hp = float(_hero_stats()["hp"])

func _settle() -> void:
	if _over:
		return
	var gain := 80 + _wave * 20
	var d := Kushou.deck_stats(_have)
	gain += int(d["money_wave"]) - int(d["neg_money_wave"])
	if _sign == "cursed":
		gain += 1000
	_money += gain
	_total_settled += gain
	if _sign == "cursed" and _total_settled >= 5000 and (_total_settled / 5000) > ((_total_settled - gain) / 5000):
		_life -= 2
		_msg_lb.text += "\n【受咒的赏钱】累计结算过 5000——生命再 -2（现 " + str(_life) + "）"
	var bs := [10, 15, 20, 25, 30, 35]
	if bs.has(_wave):
		_revive += 1
		_msg_lb.text += "\n【Boss 击破】免死次数 +1（现 " + str(_revive) + "）· 结算 " + str(gain) + " 文"
		if _sign == "greedy":
			_grid_cap += 1
			_msg_lb.text += "\n【贪功】武学格 +1（现 " + str(_grid_cap) + "）"
	else:
		_msg_lb.text += "\n结算 +" + str(gain) + " 文"
	# 傲慢：击杀概率掉东西
	if _sign == "arrogant" and randf() < 0.3:
		var r := randf()
		if r < 0.5:
			_money += 200
			_msg_lb.text += " · 掉落 200 文"
		elif r < 0.8:
			_free_refresh += 1
			_msg_lb.text += " · 掉了一张刷新券"
		else:
			_free_draw += 1
			_msg_lb.text += " · 掉了一张抽卡券"
	# 每秒回血（角色）
	var d2 := Kushou.deck_stats(_have)
	if int(d2["regen"]) > 0:
		_hero_hp = minf(float(_hero_stats()["hp"]), _hero_hp + float(_hero_stats()["hp"]) * float(d2["regen"]) / 100.0 * 5.0)
	# 五毒功类负面：每波扣命
	if int(d2["neg_life_wave"]) > 0:
		_life -= int(d2["neg_life_wave"])
		_msg_lb.text += " · 以身养毒：生命 -" + str(d2["neg_life_wave"])
		if _life <= 0 and _revive > 0:
			_revive -= 1
			_life = 10
			_growth += 1
			_msg_lb.text += "（毒发身亡——【浴血】又爬起来了！免死剩 " + str(_revive) + "）"
		elif _life <= 0:
			_life = 0
			_over = true
			_msg_lb.text += "（毒发身亡——免死用尽，你死了）"
	if _wave >= 35 and not _over:
		_over = true
		_msg_lb.text += "\n===== 35 波通关——你从死牢里杀出来了！观众记住了你的名字 ====="

# ---------- 刷新 ----------

func _refresh() -> void:
	if _top_lb == null:
		return
	var hs := _hero_stats() if _school != "" else {"atk": 0, "hp": 0, "dmg": 0, "aspd": 0, "crit": 0, "dodge": 0, "taken": 0}
	_top_lb.text = "困兽 · 第 %d/35 波 ｜ 生命 %d ｜ 文钱 %d ｜ 格 %d/%d ｜ 免死 %d ｜ %s（攻 %d · 血 %d · 伤 +%d%% · 速 +%d%%）" % [
		_wave, _life, _money, _have.size(), _grid_cap, _revive,
		str(Kushou.HEROES[_hero]["name"]) if _school != "" else "未选人",
		int(hs["atk"]), int(_hero_hp if _school != "" else hs["hp"]), int(hs["dmg"]), int(hs["aspd"])]
	var sl := ""
	for i in _offer.size():
		var cid := str(_offer[i])
		var c: Dictionary = Kushou.CARDS[cid]
		sl += ("[" + str(Kushou.Q_CN[int(c["q"])] + "·" + str(c["name"]) + " " + Kushou.card_line(cid)) + "]  ")
	_shop_lb.text = "货架（" + ("断绝中·纯本派" if _ban_mix else "混池") + "）：" + (sl if sl != "" else "（空——点刷新）")
	_paint_grid()

func _paint_grid() -> void:
	for cell in _cells:
		if is_instance_valid(cell):
			cell.queue_free()
	_cells = []
	for i in _have.size():
		var cid := str(_have[i])
		var c: Dictionary = Kushou.CARDS[cid]
		var cx := float(i % 4) * (CELL_W + 6.0)
		var cy := float(i / 4) * (CELL_H + 6.0)
		var p := Panel.new()
		p.position = Vector2(cx, cy)
		p.size = Vector2(CELL_W, CELL_H)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.96)
		sb.set_corner_radius_all(8)
		sb.border_color = Q_COL[int(c["q"])]
		sb.set_border_width_all(2)
		p.add_theme_stylebox_override("panel", sb)
		_grid_box.add_child(p)
		var nm := _label(p, Vector2(8, 6), Vector2(CELL_W - 16, 26), 17, INK)
		nm.text = str(c["name"]) + ("·不占格" if bool(c.get("free", false)) else "")
		var ln := _label(p, Vector2(8, 34), Vector2(CELL_W - 16, 56), 12, Color(INK.r, INK.g, INK.b, 0.78))
		ln.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ln.text = Kushou.Q_CN[int(c["q"])] + " · " + Kushou.card_line(cid)
		_cells.append(p)
