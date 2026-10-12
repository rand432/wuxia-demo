extends Control
# ============================================================
# kushou/kushou_battle.gd —— 困兽 v2 · 战场（**真战斗** · 第 2 步）
#
# 设计稿：docs/困兽_主界面设计稿.md §6.1
#   即时自动战斗：**主角在下面（武器朝上）· 怪从上面涌下来（武器朝下）**；
#   同屏上限 24 只；主角自动打最近的那只；怪贴上来就打主角；飘字＋血条；boss 体型 ×2.2。
#
# 这一版接上的（第 2 步）：
#   刷怪 · 自动出手 · 怪打主角 · 死亡与掉文钱 · 经验/升级 · boss 入场 · 浴血（免死一次）
# 还没接（第 3 步）：卡组效果生效 · 抽卡真扣灵晶 · 事件三选一 · 名声结算
#
# 接口：setup(stats) · set_wave(w) · start_boss(tier, name) · spawn_pack(kind) · revive()
# 信号：coin(n) · kill(n) · hero_down() · boss_arrived(tier) · special(kind, n)
# ============================================================

const GOLD := Color(0.86, 0.68, 0.26)
# v2h（用户："打斗的音效和战斗音乐 以及 boss 登场的音乐也得要"）：
#   全部走工程已有的音频总管 shared/audio.gd（BGM 交叉淡入＋音效一发），
#   音效库是现成的（hit_slash / hit_heavy / coin / levelup / drum / fall_down…），不新增素材；
#   boss 登场那一首是这一轮新做的 assets/audio/bgm_boss_intro.ogg（取不到就退回 drum＋tension）。
const Audio := preload("res://shared/audio.gd")
const SFX_MIN_GAP := 0.09           # 音效最短间隔（免得一群怪一起打的时候"炸音"）

signal coin(n: int)
# v2m（用户："击败挑战怪 比如文钱怪 击败会有文钱掉落 以及音效 然后掉在地上之后
#   随后移动到右上角的文钱 然后文钱的数字开始增加"）：
#   战场这边只负责"**报一次掉落**"（金额 ＋ 死在哪儿），
#   掉地的物理、飞向右上文钱、数字跳动都由外层（kushou_v2 的 CoinLayer）演——
#   因为战场的 clip_contents 把画面裁在框里，钱要飞出框到 HUD 上，只能在框外画。
signal coin_drop(amount: int, pos: Vector2)
signal kill(n: int)
signal hero_down()
signal boss_arrived(tier: int)
# v2n（用户："灵晶 宝物同理"）：掉落统一带上"死在哪儿"，好让外层演"掉地→飞向计数位"
signal special(kind: String, n: int, pos: Vector2)

# ---- 数值（要调就改这一块） ----
const MAX_FOES := 24
const SPAWN_EVERY := 1.2            # 几秒刷一只（第 10 波后 0.9）
const SPAWN_EVERY_LATE := 0.9
const HERO_LINE := 96.0             # 主角离战场底边多高（脚）
const FOE_STOP := 150.0             # 怪走到离主角多近就停下开打
const WAVE_HP := 1.12               # 每波怪血 ×
const WAVE_ATK := 1.08              # 每波怪攻 ×
const BASE_FOE_HP := 30.0
const BASE_FOE_ATK := 4.0
const FOE_ASPD := 0.6               # 怪每秒打几下
const FOE_SPD := 42.0               # 怪往下走的速度（像素/秒）
const BOSS_TIER := [
	{"name": "看门恶犬", "hp": 1600.0, "atk": 22.0},
	{"name": "双头狮", "hp": 5200.0, "atk": 40.0},
	{"name": "场主亲养·狴犴", "hp": 14000.0, "atk": 64.0},
]
const FOE_NAMES := ["狱狼", "疯牛", "毒蝎", "牢鼠"]

var hero := {"atk": 12.0, "hp": 200.0, "hp_max": 200.0, "mp": 100.0, "mp_max": 100.0,
	"aspd": 1.0, "crit": 0.05, "dodge": 0.05, "cut": 0.0, "dmg_pct": 0.0}
var foes: Array = []
var wave := 1
var running := false
var kills_total := 0
var boss_alive := false

var _spawn_t := 0.6
var _hero_cd := 0.0
var _t := 0.0
var _floats: Array = []
var _hero_hit_flash := 0.0
var _banner := ""
var _banner_t := 0.0
var _boss_seq := 0                  # 叫过几个 boss（按 5 波一个）

# ---- 打击感（用户："打斗的动感要足"）----
#   屏幕震动 · 顿帧（命中瞬间把时间压慢一拍）· 主角突刺 · 刀光 · 击退 · 死亡碎裂 · 飘字弹跳
var _shake := 0.0                   # 屏幕震动强度（像素）
var _hitstop := 0.0                 # 顿帧剩余秒数
var _hero_lunge := 0.0              # 主角突刺（出手瞬间往上一冲）
var _hero_step := 0.0               # 主角走/打的动作相位
var _slashes: Array = []            # 刀光：{x,y,t,ang,crit}
var _shards: Array = []             # 死亡碎屑：{x,y,vx,vy,t}
# v2j（用户："主角和宠物要靠近过去打啊 走过去或者自动寻怪上去打也行"）：
#   主角**真的走位**——自动挑最近的怪、走过去、进了攻击距离才出手；没怪就退回原位。
#   宠物跟在主角后面一点，也会上去咬（伤害是主角的 35%）。
var hero_pos := Vector2(352.0, 608.0)
var pet_pos := Vector2(256.0, 634.0)
var _home := Vector2(352.0, 608.0)
var _pet_cd := 0.0
var _facing := -1.0                 # -1 ＝ 朝上（打上面的怪）
# v2k（用户："宠物打怪也要有动画 这里的宠物不是装饰品"）：
#   宠物是**打架的**——扑咬有整套动作：蓄力（往后坐）→ 前扑（朝目标窜出去）→ 张口 → 收势；
#   跑动时四条腿交替、尾巴摆；咬中那一下也吃抖屏与飘字。
var _pet_lunge := 0.0               # 0..1：扑咬动作进度（1＝刚起跳）
var _pet_wind := 0.0                # 0..1：起跳前的蓄力（往后一坐）
var _pet_dir := Vector2(0.0, -1.0)  # 扑的方向
var _pet_step := 0.0                # 跑动相位（腿摆）
const HERO_SPD := 168.0             # 主角走位速度
const HERO_REACH := 74.0            # 进这个距离就出手
const FOE_REACH := 66.0             # 怪进这个距离就停下开打
const PET_SPD := 190.0
const PET_REACH := 62.0
var _sfx_t := 0.0                   # 距上一次播音效多久（节流用）
var _combo := 0                     # 连杀（爽感：连着杀会喊"连杀 ×N"，抖屏也跟着加码）
var _combo_t := 0.0
var _heavy := 0                     # 每第 3 下算"重击"（更重的手感）

func setup(stats: Dictionary) -> void:
	for k in stats.keys():
		if hero.has(str(k)):
			hero[str(k)] = stats[k]
	hero["hp"] = float(hero["hp_max"])

func set_wave(w: int) -> void:
	wave = maxi(1, w)

func _foe_hp() -> float:
	return BASE_FOE_HP * pow(WAVE_HP, float(wave - 1))

func _foe_atk() -> float:
	return BASE_FOE_ATK * pow(WAVE_ATK, float(wave - 1))

func _spawn_foe(kind := "normal", hp_mul := 1.0, atk_mul := 1.0, big := false, tier := 1, nm := "") -> void:
	if foes.size() >= MAX_FOES and kind == "normal":
		return
	var x := 150.0 + randf() * maxf(60.0, size.x - 320.0)
	var f := {
		"x": x, "y": -40.0,
		"hp": _foe_hp() * hp_mul, "hp_max": _foe_hp() * hp_mul,
		"atk": _foe_atk() * atk_mul, "t": 0.0,
		"kind": kind, "boss": big, "tier": tier,
		"name": (nm if nm != "" else (str(FOE_NAMES[randi() % FOE_NAMES.size()]) if not big else "boss")),
		"scale": (1.9 if big else 0.86),
		"stop": (FOE_STOP + 40.0 if big else FOE_STOP) + randf() * 30.0,
	}
	foes.append(f)

# 叫 boss（阶 1~3）
func start_boss(tier: int) -> void:
	var tt := clampi(tier, 1, BOSS_TIER.size())
	var d: Dictionary = BOSS_TIER[tt - 1]
	var mul := pow(WAVE_HP, float(wave - 1))
	_spawn_foe("boss", 1.0, 1.0, true, tt, str(d["name"]))
	var f: Dictionary = foes[foes.size() - 1]
	f["hp"] = float(d["hp"]) * mul
	f["hp_max"] = float(d["hp"]) * mul
	f["atk"] = float(d["atk"]) * pow(WAVE_ATK, float(wave - 1))
	boss_alive = true
	_banner = ["", "一阶 boss", "二阶 boss", "三阶 boss"][tt] + "　" + str(d["name"])
	_banner_t = 2.4
	# boss 登场：先敲一记鼓，再放专属那一首（曲子取不到就退回 tension）
	Audio.sfx("drum", -2.0)
	if ResourceLoader.exists("res://assets/audio/bgm_boss_intro.ogg"):
		Audio.sfx("bgm_boss_intro", 0.0)
	else:
		Audio.sfx("tension", -4.0)
	_shake = 14.0
	_hitstop = 0.16
	boss_arrived.emit(tt)

# 挑战刷出来的怪（打死掉东西）
func spawn_pack(kind: String) -> void:
	match kind:
		"coin":
			for i in 4:
				_spawn_foe("coin", 1.6, 0.6, false, 1, "钱怪")
		"crystal":
			for i in 2:
				_spawn_foe("crystal", 2.0, 0.8, false, 1, "晶怪")
		"gear":
			_spawn_foe("gear", 6.0, 1.2, false, 1, "甲士")
		"treasure":
			_spawn_foe("treasure", 9.0, 1.0, false, 1, "宝箱怪")
		"boss":
			_boss_seq += 1
			start_boss(clampi(1 + _boss_seq / 2, 1, 3))
	_banner = "挑战：刷出 " + str(foes.size()) + " 只"
	_banner_t = 1.6

# 浴血：回半血站起来
func revive() -> void:
	hero["hp"] = float(hero["hp_max"]) * 0.5
	running = true
	Audio.sfx("levelup", -3.0)
	_banner = "浴血——你偏爬起来"
	_banner_t = 2.4

func _process(delta: float) -> void:
	# 顿帧：命中/暴击/击杀的那一两帧把时间压慢（动感全靠这一下"咬住"）
	var dt := delta
	if _hitstop > 0.0:
		_hitstop = maxf(0.0, _hitstop - delta)
		dt = delta * 0.18
	# 抖屏与特效的衰减走真实时间，别被顿帧拖慢
	_shake = maxf(0.0, _shake - delta * 60.0)
	_hero_lunge = maxf(0.0, _hero_lunge - delta * 5.0)
	_pet_lunge = maxf(0.0, _pet_lunge - delta * 4.2)
	_pet_wind = maxf(0.0, _pet_wind - delta * 5.0)
	_sfx_t = maxf(0.0, _sfx_t - delta)
	for i in range(_slashes.size() - 1, -1, -1):
		var sl: Dictionary = _slashes[i]
		sl["t"] = float(sl["t"]) + delta
		if float(sl["t"]) > 0.20:
			_slashes.remove_at(i)
	for i2 in range(_shards.size() - 1, -1, -1):
		var sh: Dictionary = _shards[i2]
		sh["t"] = float(sh["t"]) + delta
		sh["x"] = float(sh["x"]) + float(sh["vx"]) * delta
		sh["y"] = float(sh["y"]) + float(sh["vy"]) * delta
		sh["vy"] = float(sh["vy"]) + 420.0 * delta
		if float(sh["t"]) > 0.45:
			_shards.remove_at(i2)
	if not running:
		queue_redraw()
		return
	_t += dt
	_hero_hit_flash = maxf(0.0, _hero_hit_flash - delta)
	_banner_t = maxf(0.0, _banner_t - delta)
	delta = dt
	# 刷怪
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = SPAWN_EVERY_LATE if wave >= 10 else SPAWN_EVERY
		_spawn_foe()
	# 主角：**先走过去**（离最近的怪还有距离就移动；进了距离才出手；场上没怪就退回原位）
	_hero_cd -= delta
	var target := _nearest()
	var tpos := Vector2(float(target["x"]), float(target["y"])) if not target.is_empty() else _home
	var to_t := tpos - hero_pos
	var dist := to_t.length()
	if not target.is_empty() and dist > HERO_REACH:
		hero_pos += to_t.normalized() * HERO_SPD * delta
		_hero_step += delta * 6.0
	elif target.is_empty() and hero_pos.distance_to(_home) > 4.0:
		hero_pos += (_home - hero_pos).normalized() * HERO_SPD * 0.8 * delta
		_hero_step += delta * 6.0
	hero_pos.x = clampf(hero_pos.x, 70.0, size.x - 70.0)
	hero_pos.y = clampf(hero_pos.y, 70.0, size.y - HERO_LINE * 0.5)
	# 宠物：跟在主角左后侧一点，也会自己上去咬
	var pet_home := hero_pos + Vector2(-92.0, 26.0)
	if not target.is_empty() and pet_pos.distance_to(tpos) > PET_REACH:
		pet_pos += (tpos - pet_pos).normalized() * PET_SPD * delta
		_pet_step += delta * 11.0                 # 跑起来腿要摆
	else:
		pet_pos += (pet_home - pet_pos) * minf(1.0, delta * 5.0)
		_pet_step += delta * 4.0
	_pet_cd -= delta
	if _pet_cd <= 0.0 and not target.is_empty() and pet_pos.distance_to(tpos) <= PET_REACH + 18.0:
		_pet_cd = 1.1
		# —— 扑咬那一套动作：先蓄力（往后一坐），再朝目标窜出去
		_pet_wind = 1.0
		_pet_lunge = 1.0
		_pet_dir = (tpos - pet_pos).normalized()
		var pd := maxf(1.0, float(hero["atk"]) * 0.35)
		target["hp"] = float(target["hp"]) - pd
		target["flash"] = 0.12
		_shake = maxf(_shake, 3.0)
		_slashes.append({"x": float(target["x"]) + _pet_dir.x * 10.0, "y": float(target["y"]) + _pet_dir.y * 10.0,
			"t": 0.0, "ang": randf_range(-1.2, 1.2), "crit": false})
		_push_float(float(target["x"]) + 16.0, float(target["y"]) - 10.0, "咬 " + str(int(pd)), Color(0.84, 0.90, 0.98), true)
		Audio.sfx("pet_chirp1", -6.0)
		if float(target["hp"]) <= 0.0:
			_kill_foe(target)
	# 出手：只在**够得着**的时候打（不再隔着半屏砍）
	if _hero_cd <= 0.0 and not target.is_empty() and hero_pos.distance_to(tpos) <= HERO_REACH + 16.0:
		var tgt := target
		if true:
			_hero_cd = 1.0 / maxf(0.2, float(hero["aspd"]))
			var crit := randf() < float(hero["crit"])
			_heavy += 1
			var heavy := _heavy % 3 == 0          # 每第三下＝重击：伤害 ×1.6、手感更狠
			var dmg := float(hero["atk"]) * (1.0 + float(hero["dmg_pct"])) * (2.0 if crit else 1.0)
			if heavy:
				dmg *= 1.6
			dmg = maxf(1.0, dmg - float(tgt["hp_max"]) * 0.02)
			tgt["hp"] = float(tgt["hp"]) - dmg
			# —— 出手那一下的"劲儿"：突刺 ＋ 刀光 ＋ 被击者闪白与击退 ＋ 抖屏/顿帧
			_hero_lunge = 1.0 if not heavy else 1.5
			_hero_step += 1.0
			_slashes.append({"x": float(tgt["x"]), "y": float(tgt["y"]) - 18.0, "t": 0.0,
				"ang": randf_range(-0.9, 0.9), "crit": crit or heavy})
			tgt["flash"] = 0.16 if not heavy else 0.22
			tgt["kb"] = (14.0 if not crit else 24.0) * (1.6 if heavy else 1.0)
			_shake = maxf(_shake, (7.0 if crit else 4.0) * (1.7 if heavy else 1.0))
			if crit or heavy:
				_hitstop = 0.06 if not heavy else 0.085
			# 音效：重击/暴击用"重刀"，平常是刀风（节流，别一屏怪一起响）
			if _sfx_t <= 0.0:
				Audio.sfx("hit_heavy" if (crit or heavy) else "hit_slash", -5.0 if (crit or heavy) else -8.0)
				_sfx_t = SFX_MIN_GAP
			_push_float(float(tgt["x"]), float(tgt["y"]) - 26.0, str(int(dmg)), GOLD if crit else Color(0.96, 0.95, 0.92), crit or heavy)
			if float(tgt["hp"]) <= 0.0:
				_kill_foe(tgt)
	# 怪：往下走 / 贴上来打
	# 连杀计时：1.4 秒内没有新击杀就归零
	if _combo_t > 0.0:
		_combo_t -= dt
		if _combo_t <= 0.0:
			_combo = 0
	# 主角的"家"跟着窗口尺寸走（没怪时退回这里）
	_home = Vector2(size.x * 0.5, size.y - HERO_LINE)
	for i in range(foes.size() - 1, -1, -1):
		var f: Dictionary = foes[i]
		# 正在"被打飞"的那半秒：不再走位、不再打人，只上飘淡出
		if float(f.get("dying", 0.0)) > 0.0:
			f["dying"] = float(f["dying"]) - dt
			f["y"] = maxf(-70.0, float(f["y"]) - float(f.get("kb", 0.0)) * dt)
			f["kb"] = maxf(0.0, float(f.get("kb", 0.0)) - 420.0 * dt)
			if float(f["dying"]) <= 0.0:
				foes.erase(f)
			continue
		# 挨打那一下的击退与闪白
		if float(f.get("kb", 0.0)) > 0.0:
			f["y"] = maxf(20.0, float(f["y"]) - float(f["kb"]) * dt)
			f["kb"] = maxf(0.0, float(f.get("kb", 0.0)) - 130.0 * dt)
		f["flash"] = maxf(0.0, float(f.get("flash", 0.0)) - delta)
		f["lunge"] = maxf(0.0, float(f.get("lunge", 0.0)) - delta * 4.5)
		# 怪**朝主角走**（主角会动，所以不再用固定的那条线）——走到 FOE_REACH 就停下开打
		var to_h := hero_pos - Vector2(float(f["x"]), float(f["y"]))
		var dh := to_h.length()
		if dh > FOE_REACH:
			var mv := to_h.normalized() * minf(FOE_SPD * delta * (0.7 if bool(f["boss"]) else 1.0), dh - FOE_REACH)
			f["x"] = clampf(float(f["x"]) + mv.x, 40.0, size.x - 40.0)
			f["y"] = float(f["y"]) + mv.y
		else:
			f["t"] = float(f["t"]) + delta
			if float(f["t"]) >= 1.0 / FOE_ASPD:
				f["t"] = 0.0
				f["lunge"] = 1.0                 # 怪扑下来那一下
				var d2 := float(f["atk"])
				if randf() < float(hero["dodge"]):
					_push_float(size.x * 0.5, size.y - HERO_LINE - 40.0, "闪", Color(0.60, 0.80, 0.90))
				else:
					d2 = maxf(1.0, d2 * (1.0 - float(hero["cut"])))
					hero["hp"] = float(hero["hp"]) - d2
					_hero_hit_flash = 0.18
					_shake = maxf(_shake, 3.5)
					_push_float(size.x * 0.5 + float(randi() % 40 - 20), size.y - HERO_LINE - 40.0, "-" + str(int(d2)), Color(0.86, 0.36, 0.30))
					if float(hero["hp"]) <= 0.0:
						hero["hp"] = 0.0
						running = false
						hero_down.emit()
						break
	# 飘字
	for j in range(_floats.size() - 1, -1, -1):
		var fl: Dictionary = _floats[j]
		fl["t"] = float(fl["t"]) + delta
		fl["y"] = float(fl["y"]) - 34.0 * delta
		if float(fl["t"]) > 0.75:
			_floats.remove_at(j)
	queue_redraw()

# 场上活着的那只 boss（给顶上的专属血条用）
func _boss_foe() -> Dictionary:
	for f_v in foes:
		var f: Dictionary = f_v
		if bool(f.get("boss", false)) and float(f.get("dying", 0.0)) <= 0.0:
			return f
	return {}

func _nearest() -> Dictionary:
	var best: Dictionary = {}
	# 挑**离主角最近**的那只（原来是按"最靠下"，主角会走位之后要按距离）
	var bd := 1.0e9
	for f_v in foes:
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0:
			continue                             # 已经躺了的不再补刀
		var d := hero_pos.distance_to(Vector2(float(f["x"]), float(f["y"])))
		if d < bd:
			bd = d
			best = f
	return best

# 死：不立刻消失——先"被打飞"半秒（碎片＋淡出＋上飘），爽感全在这一下
func _kill_foe(f: Dictionary) -> void:
	f["dying"] = 0.30
	f["kb"] = 210.0
	f["hp"] = 0.0
	kills_total += 1
	_combo += 1
	_combo_t = 1.4
	_shake = maxf(_shake, 6.0 + minf(6.0, float(_combo) * 0.4))
	_hitstop = maxf(_hitstop, 0.05)
	Audio.sfx("fall_down", -7.0)
	for i in 7:
		_shards.append({"x": float(f["x"]), "y": float(f["y"]) - 20.0,
			"vx": randf_range(-160.0, 160.0), "vy": randf_range(-280.0, -90.0), "t": 0.0})
	var kind := str(f["kind"])
	var coins := 1 + randi() % 3
	if kind == "coin":
		coins = 30 + randi() % 31
	elif kind == "boss":
		coins = 200
		boss_alive = false
		_shake = 22.0                      # boss 死：整屏重震 ＋ 长顿帧
		_hitstop = maxf(_hitstop, 0.28)
	coin_drop.emit(coins, Vector2(float(f["x"]), float(f["y"])))
	if _combo >= 3:
		_push_float(float(f["x"]), float(f["y"]) - 46.0, "连杀 ×" + str(_combo), Color(1.0, 0.84, 0.34), true)
	Audio.sfx("coin", -10.0)
	if kind != "normal" and kind != "coin":
		special.emit(kind, coins, Vector2(float(f["x"]), float(f["y"])))
	kill.emit(1)

func _push_float(x: float, y: float, txt: String, col: Color, big := false) -> void:
	_floats.append({"x": x, "y": y, "txt": txt, "col": col, "t": 0.0, "big": big})

# ============================================================
# 画：主角在下（武器朝上）· 怪在上（武器朝下）
# ============================================================
func _draw() -> void:
	var w := size.x
	var h := size.y
	# 抖屏：整幅画先按震动量偏一下（打击感的第一层）——记下偏移，画完宠物要还原回来
	var shk := Vector2.ZERO
	if _shake > 0.05:
		shk = Vector2(randf_range(-1.0, 1.0) * _shake, randf_range(-1.0, 1.0) * _shake)
	draw_set_transform(shk)
	draw_rect(Rect2(0, 0, w, 46), Color(1, 1, 1, 0.030))
	draw_rect(Rect2(0, h - 84.0, w, 84), Color(1, 1, 1, 0.045))
	draw_line(Vector2(24, h - 84.0), Vector2(w - 24, h - 84.0), Color(1, 1, 1, 0.06), 2.0)
	# 怪（先画，压在主角下面一层）
	for f_v in foes:
		var f: Dictionary = f_v
		var sc := float(f["scale"])
		if float(f["y"]) < -20.0:
			continue
		var dying := float(f.get("dying", 0.0))
		var flash := float(f.get("flash", 0.0))
		var lunge := float(f.get("lunge", 0.0))
		var fc := Color(0.66, 0.62, 0.60)
		if flash > 0.0:
			fc = Color(1.0, 0.97, 0.90)                    # 挨打闪白
		if dying > 0.0:
			fc = Color(fc.r, fc.g, fc.b, clampf(dying / 0.30, 0.0, 1.0))
		# v2g（用户："挑战怪 要和不同怪不同 比如文钱 就是文钱的样子等"）：
		#   按 kind 各画各的——钱怪是铜钱、晶怪是晶石、甲士带盾、宝箱怪是箱子、boss 带肩甲
		_foe_art(f, sc, fc)
		var bw := 46.0 * sc
		var bx := float(f["x"]) - bw * 0.5 + (randf_range(-2.0, 2.0) if flash > 0.0 else 0.0)
		draw_rect(Rect2(bx, float(f["y"]) - 58.0 * sc, bw, 6.0), Color(0.28, 0.26, 0.28))
		var ratio := clampf(float(f["hp"]) / maxf(1.0, float(f["hp_max"])), 0.0, 1.0)
		var col := Color(0.62, 0.30, 0.28)
		if str(f["kind"]) == "coin":
			col = Color(0.86, 0.68, 0.26)
		elif str(f["kind"]) == "crystal":
			col = Color(0.42, 0.62, 0.78)
		elif bool(f["boss"]):
			col = Color(0.72, 0.22, 0.20)
		draw_rect(Rect2(bx, float(f["y"]) - 58.0 * sc, bw * ratio, 6.0), col)
		if bool(f["boss"]):
			var nm := str(f["name"])
			draw_string(ThemeDB.fallback_font, Vector2(float(f["x"]) - 70.0, float(f["y"]) - 66.0 * sc), nm,
				HORIZONTAL_ALIGNMENT_CENTER, 140.0, 20, Color(0.95, 0.86, 0.66))
	# 主角＋宠物
	var hx := hero_pos.x
	var hy := hero_pos.y
	var hero_col := Color(0.94, 0.92, 0.86)
	if _hero_hit_flash > 0.0:
		hero_col = Color(0.98, 0.62, 0.56)
	# 出手那一下往上一冲（突刺），平时轻轻起伏
	var hy2 := hy + sin(_t * 4.0) * 3.0 - _hero_lunge * 16.0
	_stick(Vector2(hx, hy2), 1.35, hero_col, true)
	# 突刺时手边拖一道刀光
	if _hero_lunge > 0.35:
		draw_line(Vector2(hx + 26.0, hy2 - 10.0), Vector2(hx + 40.0, hy2 - 66.0),
			Color(1.0, 0.96, 0.86, _hero_lunge * 0.9), 5.0)
	_pet(pet_pos, shk)
	# 刀光（打中那一下的一撇）
	for sl_v in _slashes:
		var sl: Dictionary = sl_v
		var a := 1.0 - float(sl["t"]) / 0.20
		var c := (Color(1.0, 0.86, 0.42, a) if bool(sl["crit"]) else Color(1.0, 0.98, 0.94, a))
		var cx := float(sl["x"])
		var cy := float(sl["y"])
		var ang := float(sl["ang"])
		var len := (40.0 if bool(sl["crit"]) else 28.0)
		var d := Vector2(cos(ang), sin(ang)) * len
		draw_line(Vector2(cx - d.x, cy - d.y), Vector2(cx + d.x, cy + d.y), c, (5.0 if bool(sl["crit"]) else 3.5))
		draw_line(Vector2(cx - d.y * 0.6, cy + d.x * 0.6), Vector2(cx + d.y * 0.6, cy - d.x * 0.6),
			Color(c.r, c.g, c.b, a * 0.7), 2.5)
	# 死亡碎屑
	for sh_v in _shards:
		var sh: Dictionary = sh_v
		var a2 := 1.0 - float(sh["t"]) / 0.45
		draw_line(Vector2(float(sh["x"]), float(sh["y"])),
			Vector2(float(sh["x"]) - float(sh["vx"]) * 0.03, float(sh["y"]) - float(sh["vy"]) * 0.03),
			Color(0.86, 0.80, 0.72, a2), 3.0)
	# 飘字
	for fl_v in _floats:
		var fl: Dictionary = fl_v
		var ft := float(fl["t"])
		var a := 1.0 - ft / 0.75
		var c: Color = fl["col"]
		var big := bool(fl.get("big", false))
		# 飘字弹一下：冒头时放大，然后收回正常大小
		var pop := 1.0 + (0.75 * (1.0 - ft / 0.14) if ft < 0.14 else 0.0)
		var fs := int(round((34.0 if big else 24.0) * pop))
		draw_string(ThemeDB.fallback_font, Vector2(float(fl["x"]) - 60.0, float(fl["y"])), str(fl["txt"]),
			HORIZONTAL_ALIGNMENT_CENTER, 120.0, fs, Color(c.r, c.g, c.b, a))
	# 连杀：屏幕中上那行大字（3 连以上才喊）
	if _combo >= 3 and _combo_t > 0.0:
		var k := clampf(_combo_t / 1.4, 0.0, 1.0)
		var cs := int(round(30.0 + 16.0 * k))
		draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 160.0, 168.0), "连杀 ×" + str(_combo),
			HORIZONTAL_ALIGNMENT_CENTER, 320.0, cs, Color(1.0, 0.84, 0.34, 0.35 + 0.65 * k))
	# v2i（用户："boss到场时 可以显示的血条可以再战斗画面的上方"）：
	#   boss 活着的时候，**战场最上面**挂一条专属血条（名字 ＋ 阶 ＋ 大红条），
	#   头顶那条小血条照旧留着（看得清它在哪）。入场横幅往下让开 62，不跟血条叠。
	var bo := _boss_foe()
	if not bo.is_empty():
		var bw3 := minf(620.0, w - 60.0)
		var bx3 := (w - bw3) * 0.5
		draw_rect(Rect2(bx3, 8.0, bw3, 30.0), Color(0.12, 0.10, 0.10, 0.92))
		var r3 := clampf(float(bo["hp"]) / maxf(1.0, float(bo["hp_max"])), 0.0, 1.0)
		draw_rect(Rect2(bx3 + 3.0, 11.0, (bw3 - 6.0) * r3, 24.0), Color(0.70, 0.18, 0.16))
		draw_rect(Rect2(bx3, 8.0, bw3, 30.0), Color(0.86, 0.72, 0.40, 0.85), false, 2.0)
		var tag: String = str(["", "一阶", "二阶", "三阶"][clampi(int(bo["tier"]), 1, 3)])
		draw_string(ThemeDB.fallback_font, Vector2(bx3 + 12.0, 30.0), tag + "　" + str(bo["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, bw3 - 24.0, 22, Color(0.98, 0.94, 0.88))
	# boss 横幅
	# ⚠ 入场横幅原来落在 62..118，正好压着刚走下来的 boss 脑袋（截图看出来的）——
	#   现在贴着 boss 血条下面（44）并且压扁一点，条与字各占各的
	if _banner_t > 0.0 and _banner != "":
		var bw2 := 460.0
		draw_rect(Rect2(w * 0.5 - bw2 * 0.5, 44.0, bw2, 44.0), Color(0.10, 0.09, 0.10, 0.86))
		draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - bw2 * 0.5, 74.0), _banner,
			HORIZONTAL_ALIGNMENT_CENTER, bw2, 24, Color(0.97, 0.90, 0.72))

# ---- 各类挑战怪的长相（"不同怪不同样子"）----
func _foe_art(f: Dictionary, sc: float, fc: Color) -> void:
	var c := Vector2(float(f["x"]), float(f["y"]) + float(f.get("lunge", 0.0)) * 12.0)
	match str(f["kind"]):
		"coin":
			_draw_coin(c, sc, fc)
		"crystal":
			_draw_crystal(c, sc, fc)
		"gear":
			_draw_gear(c, sc, fc)
		"treasure":
			_draw_chest(c, sc, fc)
		"boss":
			_draw_boss(c, sc, fc)
		_:
			_stick(c, sc, fc, false)
	# 每只脚下一小片影子（站得住）
	draw_circle(Vector2(c.x, c.y + 30.0 * sc), 16.0 * sc, Color(0, 0, 0, 0.18))

# 钱怪：一枚会蹦的铜钱（外圆内方，跟 HUD 那个图标一套）
func _draw_coin(c: Vector2, sc: float, fc: Color) -> void:
	var y := c.y + sin(_t * 7.0 + c.x * 0.1) * 4.0
	var r := 20.0 * sc
	draw_circle(Vector2(c.x, y), r, Color(0.90, 0.74, 0.30) if fc.a > 0.99 else Color(fc.r, fc.g, fc.b, fc.a))
	draw_circle(Vector2(c.x, y), r, Color(0.55, 0.42, 0.15, 0.9), false, 3.0)
	draw_rect(Rect2(c.x - r * 0.34, y - r * 0.34, r * 0.68, r * 0.68), Color(0, 0, 0, 0))
	draw_rect(Rect2(c.x - r * 0.34, y - r * 0.34, r * 0.68, r * 0.68), Color(0.55, 0.42, 0.15, 0.9), false, 3.0)
	draw_line(Vector2(c.x - r * 0.6, y - r * 0.55), Vector2(c.x - r * 0.2, y - r * 0.8), Color(1, 0.97, 0.86, 0.8), 2.5)

# 晶怪：一颗六棱晶（跟 HUD 那个图标一套）
func _draw_crystal(c: Vector2, sc: float, fc: Color) -> void:
	var y := c.y + sin(_t * 4.0 + c.x * 0.08) * 3.0
	var r := 22.0 * sc
	var pts := PackedVector2Array([Vector2(c.x, y - r), Vector2(c.x + r * 0.66, y), Vector2(c.x, y + r), Vector2(c.x - r * 0.66, y)])
	draw_colored_polygon(pts, Color(0.42, 0.62, 0.78) if fc.a > 0.99 else Color(fc.r, fc.g, fc.b, fc.a))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.20, 0.38, 0.56), 3.0)
	draw_line(Vector2(c.x - 4, y - r * 0.5), Vector2(c.x + 2, y - r * 0.85), Color(0.90, 0.97, 1.0, 0.9), 3.0)

# 甲士：简笔小人 ＋ 头盔 ＋ 一面盾（比寻常怪"厚"）
func _draw_gear(c: Vector2, sc: float, fc: Color) -> void:
	_stick(c, sc * 1.1, fc, false)
	var y := c.y
	draw_rect(Rect2(c.x - 15.0 * sc, y - 44.0 * sc, 30.0 * sc, 7.0 * sc), Color(0.72, 0.70, 0.66))     # 盔沿
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 20.0 * sc, y - 12.0 * sc), Vector2(c.x + 20.0 * sc, y - 12.0 * sc),
		Vector2(c.x + 20.0 * sc, y + 12.0 * sc), Vector2(c.x - 20.0 * sc, y + 12.0 * sc)]),
		Color(0.52, 0.50, 0.46))                                                                        # 盾
	draw_rect(Rect2(c.x - 20.0 * sc, y - 12.0 * sc, 40.0 * sc, 24.0 * sc), Color(0.34, 0.32, 0.30), false, 3.0)

# 宝箱怪：一口带腿的箱子（掀盖＋锁眼）
func _draw_chest(c: Vector2, sc: float, fc: Color) -> void:
	var y := c.y + sin(_t * 5.0 + c.x * 0.05) * 3.0
	var w2 := 26.0 * sc
	var h2 := 20.0 * sc
	draw_rect(Rect2(c.x - w2, y - h2, w2 * 2.0, h2 * 2.0), Color(0.55, 0.38, 0.22) if fc.a > 0.99 else Color(fc.r, fc.g, fc.b, fc.a))
	draw_rect(Rect2(c.x - w2, y - h2, w2 * 2.0, h2 * 0.7), Color(0.66, 0.47, 0.28))
	draw_rect(Rect2(c.x - w2, y - h2, w2 * 2.0, h2 * 1.9), Color(0.30, 0.20, 0.12), false, 3.0)
	draw_circle(Vector2(c.x, y), 4.0 * sc, Color(0.92, 0.82, 0.40))
	draw_line(Vector2(c.x - w2 * 0.6, y + h2), Vector2(c.x - w2 * 0.6, y + h2 + 8.0 * sc), Color(0.40, 0.30, 0.20), 4.0)
	draw_line(Vector2(c.x + w2 * 0.6, y + h2), Vector2(c.x + w2 * 0.6, y + h2 + 8.0 * sc), Color(0.40, 0.30, 0.20), 4.0)

# boss：大只 ＋ 两块肩甲 ＋ 一对角 ＋ 脚下一圈红气
func _draw_boss(c: Vector2, sc: float, fc: Color) -> void:
	draw_circle(Vector2(c.x, c.y + 6.0 * sc), 46.0 * sc, Color(0.62, 0.16, 0.14, 0.16))
	_stick(c, sc, fc, false)
	draw_rect(Rect2(c.x - 30.0 * sc, c.y - 26.0 * sc, 20.0 * sc, 10.0 * sc), Color(0.58, 0.24, 0.22))
	draw_rect(Rect2(c.x + 10.0 * sc, c.y - 26.0 * sc, 20.0 * sc, 10.0 * sc), Color(0.58, 0.24, 0.22))
	draw_line(Vector2(c.x - 8.0 * sc, c.y - 42.0 * sc), Vector2(c.x - 16.0 * sc, c.y - 54.0 * sc), Color(0.80, 0.76, 0.68), 4.0)
	draw_line(Vector2(c.x + 8.0 * sc, c.y - 42.0 * sc), Vector2(c.x + 16.0 * sc, c.y - 54.0 * sc), Color(0.80, 0.76, 0.68), 4.0)

# 宠物（会打架的那只 · v2k 给它整套扑咬动作）
#   蓄力＝往后一坐并压扁；扑出去＝朝目标窜 26 像素并拉长；咬中那一瞬张口；
#   跑动时四条腿交替摆、尾巴一直摇。
func _pet(c: Vector2, sh: Vector2) -> void:
	var off := _pet_dir * (_pet_lunge * 26.0 - _pet_wind * 8.0)
	var c2 := c + off
	var stretch := 1.0 + _pet_lunge * 0.20 - _pet_wind * 0.10
	var squash := 1.0 - _pet_lunge * 0.12 + _pet_wind * 0.14
	draw_set_transform(c2 + sh, atan2(_pet_dir.y, _pet_dir.x) + PI * 0.5, Vector2(stretch, squash))
	var pc := Color(0.87, 0.85, 0.79)
	# 四条腿：跑起来交替摆
	for i in 4:
		var lx := -11.0 + float(i) * 7.3
		var sw := sin(_pet_step + float(i) * 1.7) * 5.0
		draw_line(Vector2(lx, 12.0), Vector2(lx + sw, 26.0), pc, 4.0)
	# 身体＋尾巴（一直摇）
	draw_circle(Vector2(0, 0), 16.0, pc)
	draw_line(Vector2(14, -4), Vector2(30 + sin(_t * 9.0) * 5.0, -20 + cos(_t * 9.0) * 4.0), pc, 5.0)
	# 头 ＋ 耳朵
	draw_circle(Vector2(-19, -14), 11.5, pc)
	draw_colored_polygon(PackedVector2Array([Vector2(-27, -22), Vector2(-20, -33), Vector2(-13, -21)]), pc)
	# 张口：扑咬那一下把嘴张成一个楔子
	if _pet_lunge > 0.25:
		var o := _pet_lunge * 12.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-30, -12), Vector2(-30 - o, -20 - o * 0.4), Vector2(-30 - o, -4 + o * 0.4)]),
			Color(0.42, 0.30, 0.28))
	draw_circle(Vector2(-23, -17), 2.4, Color(0.20, 0.19, 0.20))
	draw_set_transform(sh)      # ⚠ 还原抖屏变换，后面的刀光/飘字才不会被宠物的旋转带跑

func _stick(c: Vector2, s: float, col: Color, up: bool) -> void:
	var w := 3.0 * s
	var d := -1.0 if up else 1.0
	draw_circle(c + Vector2(0, -34.0 * s), 9.0 * s, col)
	draw_line(c + Vector2(0, -25.0 * s), c + Vector2(0, 6.0 * s), col, w)
	draw_line(c + Vector2(0, -18.0 * s), c + Vector2(-13.0 * s, -2.0 * s), col, w)
	draw_line(c + Vector2(0, -18.0 * s), c + Vector2(14.0 * s, -26.0 * s), col, w)
	draw_line(c + Vector2(0, 6.0 * s), c + Vector2(-9.0 * s, 26.0 * s), col, w)
	draw_line(c + Vector2(0, 6.0 * s), c + Vector2(9.0 * s, 26.0 * s), col, w)
	draw_line(c + Vector2(14.0 * s, -10.0 * s), c + Vector2(20.0 * s, -10.0 * s + d * 42.0 * s), Color(0.85, 0.84, 0.80), w)
