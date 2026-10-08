extends Control
# ============================================================
# kushou_mode.gd —— 「困兽」v1 试玩面板
#   开局（角色→门派→开局签）→ 牌桌（24 格＋商店）→ 自动波次 → 35 波通关
#   ⚠ v1 试玩：战斗=自动对撞结算；火柴人演出后接
#
# v129（追剿·手牌模式）：同一张牌桌现在有两种场子——
#   · 自由试玩（menu_sketch 按 E）：35 波，敌人是困兽那三怪六 boss；
#   · **追剿**（open_chase(i)，出村面板那颗［手牌］钮）：**五关一波**——
#     从追剿当前进度起连打 5 关（第 5 关通常是 boss），全清则追剿进度 +5。
#     敌人取自 shared/data_chase.gd（与自动战斗同一个 boss、同一套特性）。
#   ⚠ 牌桌是"一局一剿"的 roguelike：输了这一剿不推进度（可以再来）。
# ============================================================

const Kushou := preload("res://kushou/data_kushou.gd")
const Chase := preload("res://shared/data_chase.gd")
const GameState := preload("res://shared/game_state.gd")
const Affixes := preload("res://shared/data_affixes.gd")

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

# ---- v129：追剿那一场 ----
signal chase_done(win: bool, stage_i: int)
var chase := false            # true ＝ 这一局是追剿（一局一剿）
var chase_stage := 0          # 这一剿的第 1 关（＝开局时的追剿进度）
var _locked_card := ""        # 「锁招」：这一关被锁住的那张卡（不生效）
var _last_traits: Array = []  # 这一波的 boss 特性（结算里要用）
var _poison := 0              # 「淬毒」：身上叠的毒（每关 -2 生命，最多 5 层）
var _last_boss := false       # 这一波是不是 boss（结算要看它）

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

# ============================================================
# v129：追剿入口——从追剿当前进度起，连打 5 关（一剿）
# ============================================================
func open_chase(stage_i: int) -> void:
	chase = true
	chase_stage = maxi(0, stage_i)
	_reset_run()
	visible = true
	move_to_front()
	_open_pick_hero()
	print("[困兽] 追剿·手牌模式：从第 ", chase_stage + 1, " 关起（", Chase.chapter_of(chase_stage), "）")

func _reset_run() -> void:
	_free_veil()
	_hero = "player"
	_school = ""
	_sign = ""
	_life = 100
	_money = 5000
	_wave = 1
	_have = []
	_grid_cap = 24
	_revive = 1
	_growth = 0
	_total_settled = 0
	_offer = []
	_ban_mix = false
	_ban_school = ""
	_free_draw = 0
	_free_refresh = 0
	_hero_hp = 100.0
	_over = false
	_locked_card = ""
	_poison = 0
	_last_boss = false

func _on_close() -> void:
	visible = false

# 这一局打几波：追剿 ＝ 5（一剿）· 自由试玩 ＝ 35
func _wave_max() -> int:
	return Chase.KS_WAVES if chase else 35

# 「锁招」锁住的那张卡先摘掉——这一关的牌面按"没有它"算
func _deck_now() -> Array:
	if _locked_card == "":
		return _have
	var out: Array = []
	for c in _have:
		if str(c) != _locked_card:
			out.append(c)
	return out

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
	# v129：追剿的抬头比"困兽 · 第 N/35 波"长（要带剿号/境界那一段）——给它两行
	_top_lb = _label(_root, Vector2(30, 14), Vector2(660, 60), 22, Color(0.94, 0.91, 0.84))
	_top_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# v129 修：这一行原来是**深墨写在深色底上**（几乎看不见）——改回纸色
	_shop_lb = _label(_root, Vector2(30, 150), Vector2(660, 100), 15, Color(PAPER.r, PAPER.g, PAPER.b, 0.92))
	_shop_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	# v129：这张牌桌原来没有退路（试玩时按 E 进来就出不去）——补一颗［关闭］
	_btn(_root, Vector2(548, 968), Vector2(142, 50), "关闭", 17, _on_close)
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

# v129：掉生命只有这一条路（卡面的每波扣命、追剿的淬毒都走它）——
#   归零就走浴血（免死 +1 次全攻血、回到 10 点）；免死用尽才收场。返回 true ＝ 这一局结束了。
func _lose_life(n: int, why: String) -> bool:
	if n <= 0:
		return false
	_life -= n
	_msg_lb.text += " · " + why + "生命 -" + str(n) + "（现 " + str(maxi(0, _life)) + "）"
	if _life > 0:
		return false
	if _revive > 0:
		_revive -= 1
		_life = 10
		_growth += 1
		_msg_lb.text += "（【浴血】又爬起来了！免死剩 " + str(_revive) + "）"
		return false
	_life = 0
	_over = true
	_msg_lb.text += "（免死用尽——你倒在了这一剿里）"
	if chase:
		chase_done.emit(false, chase_stage)
	return true

# ---------- 波次 ----------

func _on_next_wave() -> void:
	if _over or _school == "":
		return
	_battle(_wave)
	if _over:
		_refresh()
		return
	_settle()
	if _over:
		_refresh()
		return
	_wave += 1
	_refresh()

# ============================================================
# v129：追剿的敌人——走 data_chase（与自动战斗同一个 boss、同一套特性），
#   数值换算到牌桌这一档（见 Chase.ks_enemy_at）；特性在这一层"翻译"成牌桌效果：
#     号令  ＝ 带了随从（攻 +15%）        列阵  ＝ 玩家输出 ×0.7（有"伤+"卡只 ×0.85）
#     锁招  ＝ 随机锁一张卡（不生效）      淬毒  ＝ 每关 -2 生命（叠到 5 层）
#     换招  ＝ 半血更凶（攻 +25%）
# ============================================================
func _chase_mon_of(w: int) -> Dictionary:
	var si := clampi(chase_stage + w - 1, 0, Chase.STAGE_MAX - 1)
	var e: Dictionary = Chase.ks_enemy_at(si)
	var tr: Array = e.get("traits", [])
	var notes: Array = []
	var atk := int(e.get("atk", 1))
	if tr.has("summon"):
		atk = int(round(float(atk) * 1.15))
		notes.append("号令：带着随从（攻 +15%）")
	if tr.has("phase"):
		atk = int(round(float(atk) * 1.25))
		notes.append("换招：半血更凶（攻 +25%）")
	var ab: Array = e.get("affixes", [])
	if not ab.is_empty():
		var an: Array = []
		for a in ab:
			an.append(str(Affixes.name_of(str(a))))
		notes.append("词缀：" + "、".join(PackedStringArray(an)))
	return {"name": str(e.get("name", "?")), "atk": atk, "hp": int(e.get("hp", 1)),
		"boss": bool(e.get("boss", false)), "traits": tr, "notes": notes, "stage": si}

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
	# v129：追剿的「锁招」会把一张卡摘掉——牌面按"没有它"算
	var d: Dictionary = Kushou.deck_stats(_deck_now())
	var atk := int(h["atk"]) + int(d["atk"]) + _growth * 2
	var hp := int(h["hp"]) + int(d["hp"]) + _growth * 20
	var dmg := float(d["dmg"]) - float(d["neg_dmg"])
	var aspd := float(d["aspd"]) - float(d["neg_aspd"])
	return {"atk": atk, "hp": hp, "dmg": dmg, "aspd": aspd, "crit": int(h["crit"]) + int(d["crit"]),
		"dodge": int(h["dodge"]) + int(d["dodge"]), "taken": int(d["taken"]), "regen": int(d["regen"])}

func _battle(w: int) -> void:
	var m: Dictionary = _chase_mon_of(w) if chase else _monster_of(w)
	_last_boss = bool(m.get("boss", false))
	_last_traits = (m.get("traits", []) as Array).duplicate()
	_locked_card = ""
	var extra: Array = []
	# v129：追剿 boss 的特性——在牌桌上"翻译"成数值（性格与真战斗一致）
	if chase:
		var tr: Array = _last_traits
		if tr.has("guard_all"):
			var crack := false
			for cid in _deck_now():
				if int((Kushou.CARDS[cid].get("fx", {}) as Dictionary).get("dmg", 0)) > 0:
					crack = true
					break
			m["guard_mul"] = 0.85 if crack else 0.70
			extra.append("【列阵】护体压你的输出 " + ("15%（你有破防卡——伤+那一类）" if crack else "30%——带一张伤+的卡能撕开"))
		if tr.has("seal_ult"):
			var cands: Array = []
			for cid in _have:
				if not bool(Kushou.CARDS[cid].get("free", false)):
					cands.append(cid)
			if not cands.is_empty():
				_locked_card = str(cands[randi() % cands.size()])
				extra.append("【锁招】这一关「" + str(Kushou.CARDS[_locked_card]["name"]) + "」被封（不生效）——不靠单张卡的牌组不怕它")
		for n2 in m.get("notes", []):
			extra.append(str(n2))
	var hs := _hero_stats()
	var hero_dps := float(hs["atk"]) * (1.0 + float(hs["dmg"]) / 100.0) * (1.0 + float(hs["aspd"]) / 100.0) * (1.0 + float(hs["crit"]) / 100.0 * 0.5)
	hero_dps *= float(m.get("guard_mul", 1.0))
	var mon_dps := float(m["atk"]) * (1.0 - float(hs["taken"]) / 100.0) * (1.0 - float(hs["dodge"]) / 100.0)
	if hero_dps < 0.5:
		hero_dps = 0.5
	var t := float(m["hp"]) / hero_dps
	var lost := int(round(mon_dps * t))
	_hero_hp = float(hs["hp"]) - float(lost)
	if _hero_hp > 0.0:
		_msg_lb.text = "第 " + str(w) + " 波 · " + str(m["name"]) + " 倒——你损血 " + str(lost) + "（剩 " + str(int(_hero_hp)) + "）"
		if not extra.is_empty():
			_msg_lb.text += "
" + " ｜ ".join(PackedStringArray(extra))
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
	# v129：追剿的 boss 是"五关一个"——按这一波的敌人是不是 boss 判（不按波号）
	var is_boss_wave := _last_boss if chase else bs.has(_wave)
	if is_boss_wave:
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
		if _lose_life(int(d2["neg_life_wave"]), "以身养毒："):
			return
	# v129：追剿「淬毒」——每关叠一层（最多五层），每层每关 -1 生命
	if chase and _last_traits.has("venom") and not _over:
		_poison = mini(5, _poison + 1)
		if _lose_life(_poison, "淬毒（" + str(_poison) + " 层）："):
			return
	if _wave >= _wave_max() and not _over:
		_over = true
		if chase:
			# 一剿五关全清：进度一关一关地推（chase_clear 会校验"必须是当前该打的那一关"）
			for k in _wave_max():
				GameState.chase_clear(chase_stage + k)
			_msg_lb.text += "\n===== 这一剿清了——「" + Chase.chapter_of(chase_stage) + "」退了；追剿进度 " + str(GameState.chase_progress) + "/" + str(Chase.STAGE_MAX) + " ====="
			chase_done.emit(true, chase_stage)
		else:
			_msg_lb.text += "\n===== 35 波通关——你从死牢里杀出来了！观众记住了你的名字 ====="

# ---------- 刷新 ----------

func _refresh() -> void:
	if _top_lb == null:
		return
	var hs := _hero_stats() if _school != "" else {"atk": 0, "hp": 0, "dmg": 0, "aspd": 0, "crit": 0, "dodge": 0, "taken": 0}
	# v129：追剿自带抬头（进度/剿号）——自由试玩照旧写 35 波
	if chase:
		var si := clampi(chase_stage + _wave - 1, 0, Chase.STAGE_MAX - 1)
		_top_lb.text = "追剿 · 第 %d/%d 关（第 %d 剿）｜ 生命 %d ｜ 文钱 %d ｜ 格 %d/%d ｜ 免死 %d ｜ %s（攻 %d · 血 %d · 伤 +%d%% · 速 +%d%%）" % [
			si + 1, Chase.STAGE_MAX, Chase.round_of(si),
			_life, _money, _have.size(), _grid_cap, _revive,
			str(Kushou.HEROES[_hero]["name"]) if _school != "" else "未选人",
			int(hs["atk"]), int(_hero_hp if _school != "" else hs["hp"]), int(hs["dmg"]), int(hs["aspd"])]
	else:
		_top_lb.text = "困兽 · 第 %d/35 波 ｜ 生命 %d ｜ 文钱 %d ｜ 格 %d/%d ｜ 免死 %d ｜ %s（攻 %d · 血 %d · 伤 +%d%% · 速 +%d%%）" % [
			_wave, _life, _money, _have.size(), _grid_cap, _revive,
			str(Kushou.HEROES[_hero]["name"]) if _school != "" else "未选人",
			int(hs["atk"]), int(_hero_hp if _school != "" else hs["hp"]), int(hs["dmg"]), int(hs["aspd"])]
	var sl := ""
	for i in _offer.size():
		var cid := str(_offer[i])
		var c: Dictionary = Kushou.CARDS[cid]
		sl += ("[" + str(Kushou.Q_CN[int(c["q"])] + "·" + str(c["name"]) + " " + Kushou.card_line(cid)) + "]  ")
	# v129：追剿——把"下一关是谁、它什么脾气、怎么克"写在货架上面（配牌时就看得见）
	var head := ""
	if chase and _school != "" and not _over:
		var si2 := clampi(chase_stage + _wave - 1, 0, Chase.STAGE_MAX - 1)
		var e2: Dictionary = Chase.ks_enemy_at(si2)
		var tr: Array = e2.get("traits", [])
		head = "下一关：第 " + str(_wave) + "/" + str(_wave_max()) + " 关 · " + str(e2["name"])
		if bool(e2.get("boss", false)):
			head += "【boss】"
		if not tr.is_empty():
			head += "　特性：" + Chase.trait_names(tr)
		head += "\n　　针对：" + _counter_text(tr) + "\n"
	_shop_lb.text = head + "货架（" + ("断绝中·纯本派" if _ban_mix else "混池") + "）：" + (sl if sl != "" else "（空——点刷新）")
	_paint_grid()

# v129：「针对」那半句——特性表里写好了（data_chase.TRAITS.counter），这里只挑出来拼
func _counter_text(ids: Array) -> String:
	var out: Array = []
	for t in ids:
		var d: Dictionary = Chase.trait_of(str(t))
		if not d.is_empty():
			out.append(str(d["counter"]))
	if out.is_empty():
		return "（这一关没有特性——看词缀配牌）"
	return "　".join(PackedStringArray(out))

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
