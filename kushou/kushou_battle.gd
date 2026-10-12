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
# v4h（用户："物理伤害"）：伤害类型做成**真规则**，不只是文案——
#   物理：吃目标的"防御"（现在按目标生命上限的 2% 折算减伤，下限 1）；
#   真实：一点不减（刺骨那种）。
const DMG_PHYS := "物理"
const DMG_TRUE := "真实"
const DMG_METAL := "金系"       # v4j 张道陵·天雷道术：法术伤害，**不吃兵器防御**

func _apply_dmg(f: Dictionary, amount: float, dtype: String) -> float:
	var final := amount
	if dtype == DMG_PHYS:
		final = maxf(1.0, amount - float(f["hp_max"]) * 0.02)
	elif dtype == DMG_METAL:
		# 金系：兵器防御对它无效；将来给怪加"金抗"就在这里乘（现在默认 0）
		final = maxf(1.0, amount * (1.0 - float(f.get("res_metal", 0.0))))
	f["hp"] = float(f["hp"]) - final
	return final
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
const FOE_SPD := 74.0               # 怪往下走的速度（像素/秒）
#   v3i 用户"怪可以稍微再快一点"：42 → 58；v3k 用户"怪再快一点"：58 → 74
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
var intro_wait := 0.0               # 开场等待（站桩，不出手也不动）
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
var _bursts: Array = []             # 命中炸开（溅射/剑气用）：{x,y,t,col,scale}
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
# v3f（用户："主角人物走的再慢一点 起码让怪大部分出现在屏幕里"）：
#   ① 走位速度降下来（168→96，宠物 190→124）；
#   ② 主角**不许越过战场 40% 那条线**——怪得自己走下来，交战点就留在屏幕里，
#      不再"冲到顶上去打"，一屏只看得见两只脚。
const HERO_SPD := 96.0              # 主角"贴近了"的走位速度（慢）
const HERO_SPD_FAR := 178.0         # 主角"离得远"的追击速度（快）
const CHASE_FAR := 230.0            # 超过这个距离算"远"，提速追
const CHASE_NEAR := 96.0            # 进这个距离算"近"，慢下来
const INTRO_WAIT := 3.0             # 开场先站几秒（让怪先走进画面）
const HERO_TOP := 0.25              # 主角/宠物最高只能到战场高度的这个比例（v3j：0.40→0.25）
const HERO_REACH := 74.0            # 进这个距离就出手
const FOE_REACH := 66.0             # 怪进这个距离就停下开打
const PET_SPD := 124.0              # 宠物"贴近了"的速度
const PET_SPD_FAR := 196.0          # 宠物"离得远"的追击速度
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

# 开打：站着等几秒，让怪先走进画面（用户："让主角刚开始等待几秒"）
func start_run() -> void:
	running = true
	intro_wait = INTRO_WAIT

# 距离→速度：远了提速追、近了慢下来（用户："走近了就慢、远了才快"）
func _chase_spd(near: float, far: float, d: float) -> float:
	var k := clampf((d - CHASE_NEAR) / maxf(1.0, CHASE_FAR - CHASE_NEAR), 0.0, 1.0)
	return lerpf(near, far, k)

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

# v3m（用户："任务失败卡住了"）：重开一局——战场这边把这一局的东西**清干净**
func reset_run() -> void:
	foes.clear()
	_floats.clear()
	_slashes.clear()
	_shards.clear()
	_bursts.clear()
	_qi_list.clear()
	_jg_list.clear()
	for k in skill.keys():
		skill[k] = 0
	kills_total = 0
	wave = 1
	_combo = 0
	_combo_t = 0.0
	boss_alive = false
	_boss_seq = 0
	_heavy = 0
	_banner = ""
	_banner_t = 0.0
	hero_pos = Vector2(size.x * 0.5, size.y - HERO_LINE)
	pet_pos = hero_pos + Vector2(-92.0, 26.0)
	hero["hp"] = float(hero["hp_max"])
	start_run()

# v4e（用户："浴血免死清楚场上所有怪物【普通怪奖励照给】挑战怪默认失败…主线boss怪将重置出现时间180s后再出来"）：
#   清场：**普通怪走正常击杀**（掉钱、计数、连杀都算，奖励照给）；挑战怪直接撤走（算失败，不给东西）；
#   boss 也撤走，并且告诉外层"boss 刚被清掉"，好让外层把出现时间重置成 180 秒。
func blood_bath_clear() -> Dictionary:
	var n_normal := 0
	var n_chal := 0
	var had_boss := false
	for f_v in foes.duplicate():
		var f: Dictionary = f_v
		var kind := str(f["kind"])
		if kind == "normal":
			n_normal += 1
			_kill_foe(f)                    # 正常击杀：奖励照给
		else:
			if kind == "boss":
				had_boss = true
				boss_alive = false
			n_chal += 1
			foes.erase(f)                   # 挑战怪：算失败，什么都不给
	_banner = "浴血！清场——普通怪 " + str(n_normal) + " 只（奖励照给）· 挑战怪 " + str(n_chal) + " 只（算失败）"
	_banner_t = 3.4
	Audio.sfx("tension", -3.0)
	return {"normal": n_normal, "challenge": n_chal, "boss": had_boss}

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
	_death_sfx_t = maxf(0.0, _death_sfx_t - delta)
	_aspd_flash = maxf(0.0, _aspd_flash - delta)
	var slash_life := 0.32 if _aspd_flash > 0.0 else 0.20
	for i in range(_slashes.size() - 1, -1, -1):
		var sl: Dictionary = _slashes[i]
		sl["t"] = float(sl["t"]) + delta
		if float(sl["t"]) > slash_life:
			_slashes.remove_at(i)
	for i4 in range(_motes.size() - 1, -1, -1):
		var mo: Dictionary = _motes[i4]
		mo["t"] = float(mo["t"]) + delta
		mo["y"] = float(mo["y"]) - 46.0 * delta
		if float(mo["t"]) > 0.7:
			_motes.remove_at(i4)
	for i5 in range(_thorn_lines.size() - 1, -1, -1):
		var tl: Dictionary = _thorn_lines[i5]
		tl["t"] = float(tl["t"]) + delta
		if float(tl["t"]) > 0.28:
			_thorn_lines.remove_at(i5)
	for i3 in range(_bursts.size() - 1, -1, -1):
		var bu: Dictionary = _bursts[i3]
		bu["t"] = float(bu["t"]) + delta
		if float(bu["t"]) > 0.30:
			_bursts.remove_at(i3)
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
	intro_wait = maxf(0.0, intro_wait - delta)      # 开场等待倒计时
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
	# ⚠ v2o（用户："宠物移动有个小bug 就是走到敌人 会一直走导致不停行走的晃动"）：
	#   两个毛病：① 每帧按 speed*delta 迈步**会迈过头**（在边界上来回蹭）；
	#   ② 宠物"够得着"的时候还在被 home 往回拽 → 原地抖动、腿一直摆。
	#   现在：迈步**截到正好到边界**（min(step, dist-reach)）、停下时**不记步**、
	#   并且留一点回滞（>REACH+10 才重新起步），边界上就不会抖了。
	if intro_wait > 0.0:
		pass                                    # 开场等待：站着不动（但怪照常走进来）
	elif not target.is_empty():
		if dist > HERO_REACH + 10.0:
			# 远快近慢：按当前距离取速度
			var st_h := minf(_chase_spd(HERO_SPD, HERO_SPD_FAR, dist) * delta, dist - HERO_REACH)
			hero_pos += to_t.normalized() * st_h
			if st_h > 0.3:
				_hero_step += delta * 6.0
	elif hero_pos.distance_to(_home) > 6.0:
		var st_b := minf(HERO_SPD * 0.8 * delta, hero_pos.distance_to(_home))
		hero_pos += (_home - hero_pos).normalized() * st_b
		if st_b > 0.3:
			_hero_step += delta * 6.0
	hero_pos.x = clampf(hero_pos.x, 70.0, size.x - 70.0)
	# 上不去：到 HERO_TOP 那条线就停住等怪下来（"让怪大部分出现在屏幕里"）
	hero_pos.y = clampf(hero_pos.y, size.y * HERO_TOP, size.y - HERO_LINE * 0.5)
	# 宠物：跟在主角左后侧一点，也会自己上去咬
	var pet_home := hero_pos + Vector2(-92.0, 26.0)
	if intro_wait > 0.0:
		pass                                    # 开场同样陪着站
	elif not target.is_empty():
		var pd0 := pet_pos.distance_to(tpos)
		if pd0 > PET_REACH + 12.0:
			var st_p := minf(_chase_spd(PET_SPD, PET_SPD_FAR, pd0) * delta, pd0 - PET_REACH)
			pet_pos += (tpos - pet_pos).normalized() * st_p
			if st_p > 0.3:
				_pet_step += delta * 11.0         # 真在跑，腿才摆
		# 够得着就**站住**——不再被 home 往回拽（这是"原地一直走"的根子）
	elif pet_pos.distance_to(pet_home) > 8.0:
		var st_q := minf(PET_SPD * 0.8 * delta, pet_pos.distance_to(pet_home))
		pet_pos += (pet_home - pet_pos).normalized() * st_q
		if st_q > 0.3:
			_pet_step += delta * 8.0
	# v3g（用户："宠物也是"）：宠物同样**不许越过主角那条线**——它是跟着主人的，
	#   不往前冲；怪得自己走下来才咬得到（原来它会独自冲到最上面去）。
	pet_pos.x = clampf(pet_pos.x, 44.0, size.x - 44.0)
	pet_pos.y = clampf(pet_pos.y, size.y * HERO_TOP + 12.0, size.y - HERO_LINE * 0.4)
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
		# ⚠ 原来这里放的是 pet_chirp1（一声鸟叫）——用户："攻击时有个奇怪的鸟叫声"，
		#   换成短促的撞击声，音高随机，听着像"咬"，不像鸟。
		Audio.sfx("melee", -10.0, randf_range(0.92, 1.12))
		if float(target["hp"]) <= 0.0:
			_kill_foe(target)
	# 出手：只在**够得着**的时候打（不再隔着半屏砍）；开场等待期间也不出手
	if intro_wait <= 0.0 and _hero_cd <= 0.0 and not target.is_empty() and hero_pos.distance_to(tpos) <= HERO_REACH + 16.0:
		var tgt := target
		if true:
			# 出手间隔吃"攻速提升"（技能）
			_hero_cd = 1.0 / maxf(0.2, float(hero["aspd"]) * aspd_mul())
			_hero_strike(tgt)
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
			# v3l（用户："boss可以正常速度"）：boss 不再走 0.7 倍——跟寻常怪一个速度
			var mv := to_h.normalized() * minf(FOE_SPD * delta, dh - FOE_REACH)
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
					_on_hero_hurt(f)                 # 刺骨：挨打就反真实伤害
					_push_float(size.x * 0.5 + float(randi() % 40 - 20), size.y - HERO_LINE - 40.0, "-" + str(int(d2)), Color(0.86, 0.36, 0.30))
					if float(hero["hp"]) <= 0.0:
						hero["hp"] = 0.0
						running = false
						hero_down.emit()
						break
	_update_qi(dt)
	_update_jg(dt)
	_update_partners(dt)
	_update_daggers(dt)
	_update_dagger_motion(dt)
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

# 一次出手：算伤害（含技能加成/暴击/重击）→ 打中 → 横扫（溅射）→ 命中后弹剑气 → 手感特效
func _hero_strike(tgt: Dictionary) -> void:
	var crit := randf() < float(hero["crit"])
	_heavy += 1
	var heavy := _heavy % 3 == 0
	var base := float(hero["atk"]) * (1.0 + float(hero["dmg_pct"])) * atk_mul()
	if crit:
		base *= 2.0
	if heavy:
		base *= 1.6
	var hit_list: Array = [tgt]
	# 溅射（范围）：**命中点周围 R 以内**的敌人全扫上（R 随溅射等级变大）
	var rad := splash_radius()
	if rad > 0.0:
		var hit_at := Vector2(float(tgt["x"]), float(tgt["y"]))
		for f_v in foes:
			var f: Dictionary = f_v
			if f == tgt or float(f.get("dying", 0.0)) > 0.0:
				continue
			if hit_at.distance_to(Vector2(float(f["x"]), float(f["y"]))) <= rad:
				hit_list.append(f)
	# 结算（v3b：被"溅"到的目标给更大的闪白/击退/炸开＋橙色"溅"字，一眼能看出是一刀多杀）
	var wide := splash_radius() > 0.0
	for h_v in hit_list:
		var h: Dictionary = h_v
		var is_extra := h != tgt
		var dmg := base * (splash_mul() if is_extra else 1.0)
		dmg = _apply_dmg(h, dmg, DMG_PHYS)          # 基础剑法＝**物理伤害**
		h["hp"] = float(h["hp"])                     # 减伤已在 _apply_dmg 里算过
		h["flash"] = (0.30 if wide else (0.22 if heavy else 0.16))
		h["kb"] = (14.0 if not crit else 24.0) * (1.6 if heavy else 1.0) * (1.5 if is_extra else 1.0)
		_push_float(float(h["x"]), float(h["y"]) - 26.0, str(int(dmg)),
			(Color(1.0, 0.72, 0.30) if is_extra else (GOLD if crit else Color(0.96, 0.95, 0.92))),
			crit or heavy or is_extra)
		if is_extra:
			_bursts.append({"x": float(h["x"]), "y": float(h["y"]) - 18.0, "t": 0.0,
				"col": Color(1.0, 0.74, 0.34), "scale": 1.25})
		if float(h["hp"]) <= 0.0:
			_kill_foe(h)
	# 刀光：横扫时画一道大弧（动作跟单体突刺不一样）
	if wide:
		_slashes.append({"x": float(tgt["x"]), "y": float(tgt["y"]) - 10.0, "t": 0.0,
			"ang": 0.0, "crit": crit or heavy, "wide": true, "radius": rad})
		Audio.sfx("swing", -3.0, randf_range(0.9, 1.05))      # 横扫的"呼"一声，跟单体刀声分开
	else:
		_slashes.append({"x": float(tgt["x"]), "y": float(tgt["y"]) - 18.0, "t": 0.0,
			"ang": randf_range(-0.9, 0.9), "crit": crit or heavy})
	_hero_lunge = 1.0 if not heavy else 1.5
	_hero_step += 1.0
	_shake = maxf(_shake, (7.0 if crit else 4.0) * (1.7 if heavy else 1.0))
	if crit or heavy:
		_hitstop = 0.06 if not heavy else 0.085
	if int(skill["aspd"]) >= 3:
		_aspd_flash = 0.12                      # 攻速叠起来以后，刀光留久一点＝残影
	if _sfx_t <= 0.0:
		Audio.sfx("hit_heavy" if (crit or heavy) else "hit_slash", -5.0 if (crit or heavy) else -8.0)
		_sfx_t = SFX_MIN_GAP
	# 命中后弹剑气（**已从池子里撤下**，代码留着：将来想放回来，把 SKILL_POOL 那三条加回即可）
	if not tgt.is_empty():
		_spawn_qi(Vector2(float(tgt["x"]), float(tgt["y"])), tgt, base)
	# 剑光（v3d ＋ v3e）：按几率、**朝出手方向**甩月牙
	_try_spawn_jg(base, Vector2(float(tgt["x"]), float(tgt["y"])) - hero_pos)

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

# v2p（用户："怪物死亡也有音效"）：死亡音效**分层 ＋ 随机音高**——
#   原来只有一声 -7dB 的 fall_down，被 BGM(-12dB) 和刀声盖住，听着就像"没响"。
#   现在：一记"闷响"（hit_heavy，音高随机）＋ 一声"倒下"（fall_down）；
#   各类挑战怪再叠一个"自己的音色"（钱怪叮当 / 晶怪钟声 / 甲士装备声 / 宝箱怪开箱声）；
#   boss 死是另一套：低音闷响 ＋ 鼓 ＋ 长倒下。同时节流，一群怪一起死不会糊成一片。
var _death_sfx_t := 0.0

func _death_sfx(kind: String, is_boss: bool) -> void:
	var pt := randf_range(0.92, 1.14)          # 每只高一点低一点，听着不机械
	if is_boss:
		Audio.sfx("hit_heavy", -1.0, 0.72)
		Audio.sfx("drum", -2.0, 0.85)
		Audio.sfx("fall_down", -3.0, 0.8)
		return
	if _death_sfx_t > 0.0:
		return                                  # 同一瞬间死一片时只留第一声"闷响"
	_death_sfx_t = 0.06
	Audio.sfx("hit_heavy", -2.0, pt)
	Audio.sfx("fall_down", -4.0, pt)
	match kind:
		"coin":
			Audio.sfx("coin", -5.0, pt + 0.1)
		"crystal":
			Audio.sfx("bell", -6.0, pt + 0.05)
		"gear":
			Audio.sfx("equip", -5.0, pt)
		"treasure":
			Audio.sfx("chest", -4.0, pt)
	Audio.sfx("swing", -12.0, pt)               # 一点点"挥空"的余韵

# 死：不立刻消失——先"被打飞"半秒（碎片＋淡出＋上飘），爽感全在这一下
func _kill_foe(f: Dictionary) -> void:
	f["dying"] = 0.30
	f["kb"] = 210.0
	f["hp"] = 0.0
	kills_total += 1
	_combo += 1
	_combo_t = 1.4
	_on_kill_partner()                       # 肝：持续期间杀敌涨生命上限
	_shake = maxf(_shake, 6.0 + minf(6.0, float(_combo) * 0.4))
	_hitstop = maxf(_hitstop, 0.05)
	_death_sfx(str(f["kind"]), bool(f.get("boss", false)))
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
# 技能：基础剑法（**普攻本体**）—— 见 docs/困兽_技能设计稿.md
#   七个选项：伤害提升 / 攻速提升 / 溅射 / 溅射伤害提升 /
#             剑气 / 剑气穿透 / 剑气伤害提升
#   三选一由 roll_choices() 抽（不重复；还有没解锁的机制就保证出 1 个机制）；
#   选完 apply_pick() 直接改这里这份 skill —— 数值与动作都跟着变。
# ============================================================
var skill := {"dmg": 0, "aspd": 0, "splash": 0, "splash_dmg": 0, "qi": 0, "qi_pierce": 0, "qi_dmg": 0,
	"jg": 0, "jg_c": 0, "jg_d": 0, "jg_w": 0, "jg_p": 0, "jg_s": 0}
var _jg_list: Array = []            # 剑光（月牙）：{pos, dmg, pierce, spd, w, hits, t}
var _qi_list: Array = []            # 飞剑：{pos, dir, tgt, dmg, pierce, t, hits}
var _aspd_flash := 0                # 攻速叠到 3 层以后，刀光留得久一点（残影感）

const SKILL_POOL := [
	{"id": "dmg", "name": "伤害提升", "kind": "num", "max": 5,
		"desc": "基础剑法伤害 +12%", "anim": "刀光更长更亮"},
	{"id": "aspd", "name": "攻速提升", "kind": "num", "max": 5,
		"desc": "出手速度 +8%", "anim": "挥砍更快，3 层起带残影"},
	{"id": "splash", "name": "溅射", "kind": "mech", "max": 5,
		"desc": "解锁横扫：命中点周围 <R> 内的敌人一起吃伤害（每级 +26 范围）", "anim": "扇形弧光横扫，范围一级比一级大"},
	{"id": "splash_dmg", "name": "溅射伤害提升", "kind": "num", "max": 3, "req": "splash",
		"desc": "被溅到的目标伤害 +15%（基础 70%）", "anim": "弧光变亮，边缘多一圈光"},
	# v3d（用户："剑气去掉【内容保留】新增剑光 攻击时有几率出现一道月牙剑光缓慢向前移动"）：
	#   剑气那三条**从池子里撤下**（代码与数值都留着，随时能放回来），换成"剑光"这一条线：
	#   剑光＝几率触发、月牙形状、**缓慢向前推**、碰到敌人造成伤害、能穿几个（穿透＋）。
	{"id": "jg", "name": "剑光", "kind": "mech", "max": 1,
		"desc": "解锁剑光：出手时 <C> 几率甩出一道**月牙剑光**，缓慢向前推，碰到敌人就伤", "anim": "一道月牙慢慢推出去"},
	{"id": "jg_c", "name": "剑光·几率", "kind": "num", "max": 3, "req": "jg",
		"desc": "触发几率 +15%（现 <C>）", "anim": "月牙出得更勤"},
	{"id": "jg_d", "name": "剑光·伤害", "kind": "num", "max": 3, "req": "jg",
		"desc": "剑光伤害 +25%（现 ×<D>）", "anim": "月牙更亮，命中炸环更大"},
	{"id": "jg_w", "name": "剑光·宽度", "kind": "num", "max": 3, "req": "jg",
		"desc": "月牙更宽（现 ×<W>），扫到的敌人更多", "anim": "月牙变宽变厚"},
	{"id": "jg_p", "name": "剑光·穿透", "kind": "num", "max": 3, "req": "jg",
		"desc": "可多穿 1 名敌人（现 <P>；0 就碰一个造成一次伤害即散）", "anim": "穿过敌人时留一道残影"},
	{"id": "jg_s", "name": "剑光·速度", "kind": "num", "max": 3, "req": "jg",
		"desc": "推进速度 +60（现 <S> 像素/秒）", "anim": "月牙推得更快，拖尾更长"},
	# ---- v4a 伙伴强化（req_p ＝ 要有这位伙伴才出现；"提升内力消耗"是它们自带的代价）----
	{"id": "anying_cd", "name": "肝·减冷却", "kind": "num", "max": 3, "req_p": "anying",
		"desc": "冷却 −3 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "紫色气劲冒得更勤"},
	{"id": "anying_dur", "name": "肝·加持续", "kind": "num", "max": 3, "req_p": "anying",
		"desc": "持续 +2 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "身上那层紫光留得久"},
	{"id": "anying_hp", "name": "肝·杀敌生命", "kind": "num", "max": 3, "req_p": "anying",
		"desc": "持续期间杀敌生命上限 +1（现 +<KH>）【内力消耗 +20/层】", "anim": "每杀一只飘绿字"},
	{"id": "anying_cost", "name": "肝·减内力", "kind": "num", "max": 3, "req_p": "anying",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "紫光不变，只是更省"},
	{"id": "chenshi_cd", "name": "刺骨·减冷却", "kind": "num", "max": 3, "req_p": "chenshi",
		"desc": "冷却 −3 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "粉光冒得更勤"},
	{"id": "chenshi_dur", "name": "刺骨·加持续", "kind": "num", "max": 3, "req_p": "chenshi",
		"desc": "持续 +2 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "反伤窗口更长"},
	{"id": "chenshi_dmg", "name": "刺骨·加反伤", "kind": "num", "max": 3, "req_p": "chenshi",
		"desc": "反伤 +0.5% 生命上限（现 <TH>%）【内力消耗 +20/层】", "anim": "反伤数字更大"},
	{"id": "chenshi_tgt", "name": "刺骨·反伤敌人", "kind": "num", "max": 3, "req_p": "chenshi",
		"desc": "反伤敌人 +1（现 <TG> 名）【内力消耗 +20/层】", "anim": "一次弹向多个敌人"},
	{"id": "chenshi_cost", "name": "刺骨·减内力", "kind": "num", "max": 3, "req_p": "chenshi",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "粉光不变，只是更省"},
	# ---- v4f 苏青鸾·飞匕（极品）：穿透 / 伤害 / 弹射 / 多重 / 弹射伤害 / 弹射独立伤害 / 减秒数 ----
	{"id": "suqingluan_pierce", "name": "飞匕·穿透", "kind": "mech", "max": 3, "req_p": "suqingluan",
		"desc": "飞匕多穿 1 名敌人（现 <DP>）；穿透那一段按「飞匕伤害」算", "anim": "匕首穿过敌人时留一道寒光"},
	{"id": "suqingluan_dmg", "name": "飞匕·伤害", "kind": "num", "max": 3, "req_p": "suqingluan",
		"desc": "飞匕伤害 +25%（现 ×<DD>）", "anim": "匕身更亮"},
	{"id": "suqingluan_bounce", "name": "飞匕·弹射", "kind": "mech", "max": 3, "req_p": "suqingluan",
		"desc": "命中后弹射到下一个敌人（现 <DB> 次）；弹射那一下按「弹射伤害」算", "anim": "匕首拐个弯再扎一次"},
	{"id": "suqingluan_multi", "name": "飞匕·多重", "kind": "mech", "max": 3, "req_p": "suqingluan",
		"desc": "一次多出 1 枚飞匕（现 <DM> 枚；多出来的吃「多重伤害」）", "anim": "几道寒光同时飞出"},
	{"id": "suqingluan_bdmg", "name": "飞匕·弹射伤害", "kind": "num", "max": 3, "req_p": "suqingluan",
		"desc": "弹射伤害 +25%（现 ×<DBM>）", "anim": "弹射那一下更亮"},
	{"id": "suqingluan_mdmg", "name": "飞匕·多重伤害", "kind": "num", "max": 3, "req_p": "suqingluan",
		"desc": "多重那几枚的伤害 +25%（现 ×<MD>）——多重的整体伤害会增加", "anim": "多出来的寒光更亮更粗"},
	{"id": "suqingluan_sec", "name": "飞匕·减秒数", "kind": "num", "max": 3, "req_p": "suqingluan",
		"desc": "出匕间隔 −1 秒（现 <DS> 秒）", "anim": "寒光冒得更勤"},
]

func skill_lv(id: String) -> int:
	if skill.has(id):
		return int(skill[id])
	var pid := ""
	if id.begins_with("anying_"):
		pid = "anying"
	elif id.begins_with("chenshi_"):
		pid = "chenshi"
	if pid != "":
		var key := id.substr(pid.length() + 1) + "_lv"
		return int((partners[pid] as Dictionary).get(key, 0))
	return 0

func atk_mul() -> float:
	return 1.0 + 0.12 * float(skill["dmg"])

func aspd_mul() -> float:
	return 1.0 + 0.08 * float(skill["aspd"])

# v3c（用户："溅射 可以改为范围吗 就是每一级范围 感觉更好一点"）：
#   溅射从"同时打 N 个"改成"**按范围**打"——每级把横扫半径撑大，
#   命中点周围 R 以内的敌人**全都被扫到**（不必再数目标数，玩家看得见圈在变大）。
#   R = 84 ＋ 26×(等级−1)：Lv1 84 → Lv5 188（战场上差不多是半个横排）。
func splash_radius() -> float:
	var lv := int(skill["splash"])
	if lv <= 0:
		return 0.0
	return 84.0 + 26.0 * float(lv - 1)

func splash_mul() -> float:
	if int(skill["splash"]) <= 0:
		return 1.0
	return 0.70 * (1.0 + 0.15 * float(skill["splash_dmg"]))

func qi_mul() -> float:
	return 0.60 * (1.0 + 0.20 * float(skill["qi_dmg"])) * pow(0.80, float(skill["qi_pierce"]))

# ---- 剑光（v3d）：几率触发 · 月牙 · 缓慢向前 · 可穿透 ----
func jg_chance() -> float:
	if int(skill["jg"]) <= 0:
		return 0.0
	return 0.20 + 0.15 * float(skill["jg_c"])

func jg_dmg_mul() -> float:
	return 0.80 * (1.0 + 0.25 * float(skill["jg_d"]))

func jg_width() -> float:
	return 1.0 + 0.35 * float(skill["jg_w"])

func jg_pierce() -> int:
	return int(skill["jg_p"])

func jg_speed() -> float:
	return 190.0 + 60.0 * float(skill["jg_s"])

# 出手时按几率甩一道月牙剑光（v3e：朝**出手方向**推——就是被打的那只所在的方向）
func _try_spawn_jg(base_dmg: float, dir: Vector2) -> void:
	if int(skill["jg"]) <= 0 or randf() > jg_chance():
		return
	var d := dir.normalized() if dir.length() > 0.01 else Vector2(0.0, -1.0)
	_jg_list.append({"pos": hero_pos + d * 40.0, "dir": d,
		"dmg": base_dmg * jg_dmg_mul(), "pierce": jg_pierce(), "spd": jg_speed(),
		"w": jg_width(), "hits": [], "t": 0.0})
	Audio.sfx("swing", -4.0, randf_range(0.85, 1.0))

func _update_jg(delta: float) -> void:
	for i in range(_jg_list.size() - 1, -1, -1):
		var j: Dictionary = _jg_list[i]
		j["t"] = float(j["t"]) + delta
		j["pos"] = (j["pos"] as Vector2) + (j["dir"] as Vector2) * float(j["spd"]) * delta
		var p: Vector2 = j["pos"]
		# 碰到就伤：月牙是**垂直于前进方向的一条带**（v3e：方向由出手方向决定，所以判定也跟着转）
		var w := float(j["w"])
		var jd: Vector2 = j["dir"]
		var jn := jd.orthogonal()
		for f_v in foes.duplicate():
			var f: Dictionary = f_v
			if (j["hits"] as Array).has(f) or float(f.get("dying", 0.0)) > 0.0:
				continue
			var fp := Vector2(float(f["x"]), float(f["y"]))
			var rel := fp - p
			if absf(rel.dot(jd)) <= 18.0 and absf(rel.dot(jn)) <= 46.0 * w:
				var dm: float = _apply_dmg(f, float(j["dmg"]), DMG_PHYS)   # 剑光：物理
				f["flash"] = 0.14
				f["kb"] = 10.0
				_push_float(float(f["x"]), float(f["y"]) - 34.0, "剑光 " + str(int(dm)), Color(0.98, 0.92, 0.62), true)
				_bursts.append({"x": float(f["x"]), "y": float(f["y"]) - 14.0, "t": 0.0,
					"col": Color(1.0, 0.90, 0.52), "scale": 1.2 * w})
				Shake_add(4.0)
				(j["hits"] as Array).append(f)
				if float(f["hp"]) <= 0.0:
					_kill_foe(f)
				if int(j["pierce"]) <= 0:
					_jg_list.remove_at(i)          # 没穿透：伤一个就散
					break
				j["pierce"] = int(j["pierce"]) - 1
		if not _jg_list.has(j):
			continue
		# 飞出战场就散（上/左/右/下都算）
		var pp: Vector2 = j["pos"]
		if pp.y < -60.0 or pp.y > size.y + 60.0 or pp.x < -60.0 or pp.x > size.x + 60.0:
			_jg_list.remove_at(i)

# 月牙剑光：一道弧形厚光 ＋ 内侧一道亮线（宽窄随"剑光·宽度"）
func _draw_jg(shk: Vector2) -> void:
	for j_v in _jg_list:
		var j: Dictionary = j_v
		var p: Vector2 = j["pos"]
		var w := float(j["w"])
		var jd: Vector2 = j["dir"]
		# 弧口朝着前进方向：先把坐标系转到"上＝前进方向"，画完再还原（不然后面的东西全跟着转）
		draw_set_transform(p + shk, atan2(jd.y, jd.x) + PI * 0.5, Vector2.ONE)
		draw_arc(Vector2.ZERO, 40.0 * w, PI * 1.02, PI * 1.98, 26, Color(1.0, 0.90, 0.50, 0.85), 12.0 * w)
		draw_arc(Vector2.ZERO, 46.0 * w, PI * 1.06, PI * 1.94, 26, Color(1.0, 0.97, 0.82, 0.95), 5.0 * w)
		draw_arc(Vector2.ZERO, 34.0 * w, PI * 1.10, PI * 1.90, 26, Color(1.0, 0.84, 0.42, 0.5), 4.0 * w)
		draw_set_transform(shk)

func Shake_add(v: float) -> void:
	_shake = maxf(_shake, v)

# 抽三选一：不重复；还有没解锁的机制就保证出 1 个
func roll_choices() -> Array:
	var pool: Array = []
	for e_v in SKILL_POOL:
		var e: Dictionary = e_v
		var req: String = str(e.get("req", ""))
		if req != "" and int(skill[req]) <= 0:
			continue
		var reqp: String = str(e.get("req_p", ""))       # 伙伴的强化项：得先有这位伙伴
		if reqp != "" and not bool((partners[reqp] as Dictionary)["owned"]):
			continue
		# ⚠ 用 skill_lv() 而不是直接查 skill 字典——伙伴那些强化项的档位不在 skill 里，
		#   直接下标会报 "Invalid access to property or key" 并把整次抽取打断（探针抓到的）
		if skill_lv(str(e["id"])) >= int(e["max"]):
			continue
		pool.append(e)
	pool.shuffle()
	var out: Array = []
	for e2 in pool:
		if str(e2["kind"]) == "mech":
			out.append(e2)
			break
	for e3 in pool:
		if out.size() >= 3:
			break
		if out.has(e3):
			continue
		out.append(e3)
	return out

func apply_pick(id: String) -> void:
	if skill.has(id):
		skill[id] = int(skill[id]) + 1
		return
	for pid in partners.keys():                 # 通用：加了新伙伴不用改这里
		if id.begins_with(str(pid) + "_"):
			var key := id.substr(pid.length() + 1) + "_lv"
			var p: Dictionary = partners[pid]
			p[key] = int(p.get(key, 0)) + 1
			return

# 命中后的剑气：朝**最近的另一个**敌人弹出一道飞剑
func _spawn_qi(from: Vector2, hit_foe: Dictionary, dmg: float) -> void:
	if int(skill["qi"]) <= 0:
		return
	var nxt := _nearest_except(from, [hit_foe])
	if nxt.is_empty():
		return
	_qi_list.append({"pos": from, "tgt": nxt, "dmg": dmg * qi_mul(),
		"pierce": int(skill["qi_pierce"]), "t": 0.0, "hits": [hit_foe], "dir": Vector2(0, -1)})

func _nearest_except(from: Vector2, skip: Array) -> Dictionary:
	var best: Dictionary = {}
	var bd := 1.0e9
	for f_v in foes:
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0 or skip.has(f):
			continue
		var d := from.distance_to(Vector2(float(f["x"]), float(f["y"])))
		if d < bd:
			bd = d
			best = f
	return best

func _update_qi(delta: float) -> void:
	for i in range(_qi_list.size() - 1, -1, -1):
		var q: Dictionary = _qi_list[i]
		q["t"] = float(q["t"]) + delta
		var tg: Dictionary = q["tgt"]
		if tg.is_empty() or float(tg.get("dying", 0.0)) > 0.0 or not foes.has(tg):
			_qi_list.remove_at(i)          # 目标没了，飞剑自己散
			continue
		var tp := Vector2(float(tg["x"]), float(tg["y"]))
		var to_t: Vector2 = tp - (q["pos"] as Vector2)
		var d := to_t.length()
		if d <= 22.0:
			# 命中：伤害 ＋ 小十字光 ＋ 飘字；还能穿就换下一个目标
			var dm: float = float(q["dmg"])
			tg["hp"] = float(tg["hp"]) - dm
			tg["flash"] = 0.12
			tg["kb"] = 8.0
			_push_float(float(tg["x"]), float(tg["y"]) - 30.0, "剑气 " + str(int(dm)), Color(0.80, 0.92, 1.0), true)
			# 命中炸开（更大的一圈）＋ 抖屏，让"飞剑打到了"这件事看得见
			_bursts.append({"x": float(tg["x"]), "y": float(tg["y"]) - 14.0, "t": 0.0,
				"col": Color(0.62, 0.86, 1.0), "scale": 1.5})
			_shake = maxf(_shake, 5.0)
			Audio.sfx("slash_light", -6.0, randf_range(0.95, 1.15))
			Audio.sfx("dart", -10.0, randf_range(0.9, 1.1))
			if float(tg["hp"]) <= 0.0:
				_kill_foe(tg)
			var hits: Array = q["hits"]
			hits.append(tg)
			if int(q["pierce"]) > 0:
				var nx := _nearest_except(tp, hits)
				if not nx.is_empty():
					q["pierce"] = int(q["pierce"]) - 1
					q["tgt"] = nx
					q["pos"] = tp
					q["hits"] = hits
					continue
			_qi_list.remove_at(i)
		else:
			q["dir"] = to_t.normalized()
			q["pos"] = (q["pos"] as Vector2) + (q["dir"] as Vector2) * 560.0 * delta

# 画飞剑（细长光刃 ＋ 穿透时的残影线）
# v3b：飞剑加大加亮——三层拖尾 ＋ 亮芯 ＋ 剑尖光点，飞过去能看见一条光
func _draw_qi() -> void:
	for q_v in _qi_list:
		var q: Dictionary = q_v
		var p: Vector2 = q["pos"]
		var dir: Vector2 = q["dir"]
		var n := dir.orthogonal()
		var long := 52.0 + 12.0 * float(skill["qi_pierce"])
		# 拖尾（三条，越远越淡）
		for k in 3:
			var back := p - dir * (30.0 + 26.0 * float(k))
			draw_line(back, back + dir * 22.0, Color(0.66, 0.82, 1.0, 0.34 - 0.09 * float(k)), 7.0 - 1.6 * float(k))
		# 外光 ＋ 亮芯
		draw_colored_polygon(PackedVector2Array([
			p + dir * long, p + n * 8.0, p - dir * 14.0, p - n * 8.0]), Color(0.42, 0.66, 0.95, 0.55))
		draw_colored_polygon(PackedVector2Array([
			p + dir * long, p + n * 3.6, p - dir * 10.0, p - n * 3.6]), Color(0.90, 0.96, 1.0, 0.98))
		draw_circle(p + dir * (long - 4.0), 6.0, Color(0.78, 0.92, 1.0, 0.85))

# ============================================================
# 伙伴（v4a）—— 见 docs/困兽_伙伴设计稿.md
#   用户口径：
#     暗影裁决【上品】技能「肝」：持续时间内杀敌，生命值上限 +2；耗内力 100 · 持续 5s · 冷却 20s
#       可选：-冷却【提升内力消耗】/ +持续【提升内力消耗】/ +杀敌生命【提升内力消耗】/ -内力消耗
#     陈石【下品】技能「刺骨」：持续时间内被攻击时，对攻击自己的一名敌人造成生命值 2% 的真实伤害；
#       耗内力 100 · 持续 8s · 冷却 20s
#       可选：-冷却【提升内力消耗】/ +持续【提升内力消耗】/ +反伤伤害【内力消耗】/ -内力消耗 / +反伤敌人数量
#   规则：**内力够了且不在冷却就自动放**（战斗是自动打的）；"提升内力消耗"是这些强化项自带的代价。
# ============================================================
var partners := {
	"anying": {"owned": true, "mp": 0.0, "cd": 0.0, "active": 0.0,
		"cd_lv": 0, "dur_lv": 0, "hp_lv": 0, "cost_lv": 0},
	"chenshi": {"owned": true, "mp": 0.0, "cd": 0.0, "active": 0.0,
		"cd_lv": 0, "dur_lv": 0, "dmg_lv": 0, "tgt_lv": 0, "cost_lv": 0},
	# v4f（用户）：苏青鸾【极品】技能「飞匕」——**每隔 8 秒生成一个匕首，命中最近的敌人**
	#   可选：+穿透 / +飞匕伤害 / +弹射【弹射独立伤害】/ +多重【多重独立伤害】/ +弹射伤害 / +弹射独立伤害 / -秒数
	# v4i（用户："穿透【飞匕伤害】弹射【弹射伤害】多重【多重伤害】 比如+多重伤害 多重的整体伤害会增加"）：
	#   **三条并列的伤害账**——飞匕伤害（首击与穿透都用它）／弹射伤害（弹射那一下）／多重伤害（多出来的匕首）；
	#   各自有对应的"+XX伤害"强化项，互不串味。
	# v4j（用户）：张道陵【绝品】技能「天雷道术」——范围金系伤害，耗 300 内力、冷却 10s
	"zhangdaoling": {"owned": true, "mp": 0.0, "cd": 3.0, "active": 0.0,
		"dmg_lv": 0, "range_lv": 0, "para_lv": 0, "paradur_lv": 0,
		"cost_lv": 0, "cd_lv": 0, "multi_lv": 0, "multidmg_lv": 0},
	"suqingluan": {"owned": true, "mp": 0.0, "cd": 4.0, "active": 0.0,
		"pierce_lv": 0, "dmg_lv": 0, "bounce_lv": 0, "multi_lv": 0,
		"bdmg_lv": 0, "mdmg_lv": 0, "sec_lv": 0},
}
var _dg_list: Array = []            # 飞匕：{pos, dir, tgt, dmg, pierce, bounce, hits, t}
const PARTNER_INFO := {
	"anying": {"name": "暗影裁决", "quality": "上品", "skill": "肝", "dtype": "无伤害",
		"desc": "持续时间内杀敌，生命值上限 +2（每层 +1）",
		"mp0": 100.0, "cd0": 20.0, "dur0": 5.0},
	"chenshi": {"name": "陈石", "quality": "下品", "skill": "刺骨", "dtype": "真实",
		"desc": "持续时间内被攻击时，对攻击自己的一名敌人造成生命值 2% 的真实伤害",
		"mp0": 100.0, "cd0": 20.0, "dur0": 8.0},
	"zhangdaoling": {"name": "张道陵", "quality": "绝品", "skill": "天雷道术", "dtype": "金系",
		"desc": "落下一道天雷，砸在最近的敌人身上，**两个人身位**内的敌人一起吃金系伤害；有几率麻痹",
		"mp0": 300.0, "cd0": 10.0, "dur0": 0.0},
	"suqingluan": {"name": "苏青鸾", "quality": "极品", "skill": "飞匕", "dtype": "物理",
		"desc": "每隔 8 秒生成一枚飞匕，命中最近的敌人。飞匕/弹射/多重都是物理伤害，只是倍率各算各的（都吃防御）",
		"mp0": 0.0, "cd0": 8.0, "dur0": 0.0},
}
const PARTNER_UP_STEP_MP := 20.0      # 每个"提升内力消耗"的强化 +20 内力
const PARTNER_DOWN_STEP_MP := 15.0    # "减内力消耗"每层 −15
const MP_REGEN := 2.0                 # 内力每秒回（角色页写的就是"每秒回 2"）
const PARTNER_MP_FLOOR := 40.0

# 现算的数值（改一项不用到处同步）
func p_mp(id: String) -> float:
	var p: Dictionary = partners[id]
	var info: Dictionary = PARTNER_INFO[id]
	if float(info["mp0"]) <= 0.0:
		return 0.0
	var ups := float(p.get("cd_lv", 0)) + float(p.get("dur_lv", 0))
	ups += float(p.get("hp_lv", 0)) if id == "anying" else float(p.get("dmg_lv", 0)) + float(p.get("tgt_lv", 0))
	var v := float(info["mp0"]) + PARTNER_UP_STEP_MP * ups - PARTNER_DOWN_STEP_MP * float(p.get("cost_lv", 0))
	return maxf(PARTNER_MP_FLOOR, v)

# ⚠ 用 get(…, 0)：不同伙伴的档位键不一样（苏青鸾就没有 cd_lv/dur_lv），
#   直接下标会报 "Invalid access to property or key"（探针抓到的）
func p_cd(id: String) -> float:
	var lv := float((partners[id] as Dictionary).get("cd_lv", 0))
	return maxf(4.0, float(PARTNER_INFO[id]["cd0"]) - 3.0 * lv)

func p_dur(id: String) -> float:
	var lv := float((partners[id] as Dictionary).get("dur_lv", 0))
	return float(PARTNER_INFO[id]["dur0"]) + 2.0 * lv

func p_kill_hp() -> float:                 # 肝：杀敌给的生命上限
	return 2.0 + 1.0 * float(partners["anying"]["hp_lv"])

func p_thorns() -> float:                  # 刺骨：反伤（占生命上限的比例）
	return 0.02 + 0.005 * float(partners["chenshi"]["dmg_lv"])

func p_thorn_targets() -> int:
	return 1 + int(partners["chenshi"]["tgt_lv"])

# ============================================================
# 张道陵·天雷道术（v4j）：范围金系伤害 ＋ 几率麻痹 ＋ 几率多重施法
#   "两个人身位"≈ 110 像素半径（简笔小人一人约 50 像素宽）；每级 +22。
# ============================================================
var _bolts: Array = []              # 雷电特效：{x, y, t, segs}

func tl_radius() -> float:
	return 110.0 + 22.0 * float(partners["zhangdaoling"]["range_lv"])

func tl_dmg_mul() -> float:
	return 1.60 * (1.0 + 0.25 * float(partners["zhangdaoling"]["dmg_lv"]))

func tl_para_chance() -> float:
	return 0.20 + 0.10 * float(partners["zhangdaoling"]["para_lv"])

func tl_para_dur() -> float:
	return 1.0 + 1.0 * float(partners["zhangdaoling"]["paradur_lv"])

func tl_multi_chance() -> float:
	return 0.25 + 0.15 * float(partners["zhangdaoling"]["multi_lv"])

# 多重施法那一下：**不同伤害比例**，但也是金系
func tl_multi_mul() -> float:
	return 0.60 * (1.0 + 0.25 * float(partners["zhangdaoling"]["multidmg_lv"]))

func tl_mp() -> float:
	var p: Dictionary = partners["zhangdaoling"]
	var ups := float(p.get("dmg_lv", 0)) + float(p.get("range_lv", 0)) + float(p.get("para_lv", 0))
	ups += float(p.get("paradur_lv", 0)) + float(p.get("multi_lv", 0)) + float(p.get("multidmg_lv", 0))
	return maxf(120.0, 300.0 + 30.0 * ups - 25.0 * float(p.get("cost_lv", 0)))

func tl_cd() -> float:
	return maxf(3.0, 10.0 - 1.5 * float(partners["zhangdaoling"].get("cd_lv", 0)))

func _cast_tianlei(ratio: float, tag: String) -> void:
	var tg := _nearest()
	var center := hero_pos + Vector2(0.0, -90.0)
	if not tg.is_empty():
		center = Vector2(float(tg["x"]), float(tg["y"]))
	var r := tl_radius()
	var base := float(hero["atk"]) * (1.0 + float(hero["dmg_pct"])) * tl_dmg_mul() * ratio
	var n := 0
	for f_v in foes.duplicate():
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0:
			continue
		if center.distance_to(Vector2(float(f["x"]), float(f["y"]))) > r:
			continue
		var dm := _apply_dmg(f, base, DMG_METAL)
		f["flash"] = 0.18
		f["kb"] = 6.0
		n += 1
		var para := randf() < tl_para_chance()
		if para:
			f["para"] = maxf(float(f.get("para", 0.0)), tl_para_dur())
		_push_float(float(f["x"]), float(f["y"]) - 32.0, tag + " " + str(int(dm)),
			Color(1.0, 0.94, 0.58), true)
		_bursts.append({"x": float(f["x"]), "y": float(f["y"]) - 12.0, "t": 0.0,
			"col": Color(1.0, 0.90, 0.50), "scale": 1.4})
		if para:
			_push_float(float(f["x"]) + 26.0, float(f["y"]) - 52.0, "麻痹", Color(0.86, 0.90, 1.0))
		if float(f["hp"]) <= 0.0:
			_kill_foe(f)
	# 雷柱：从顶上劈到落点，路径随机折几折
	var segs: Array = []
	var steps := 7
	for i in range(steps + 1):
		segs.append(Vector2(center.x + randf_range(-26.0, 26.0) * (1.0 - float(i) / float(steps)), center.y * float(i) / float(steps)))
	_bolts.append({"x": center.x, "y": center.y, "t": 0.0, "segs": segs})
	_shake = maxf(_shake, 16.0)
	_hitstop = maxf(_hitstop, 0.10)
	Audio.sfx("drum", -3.0)
	Audio.sfx("bell", -8.0, 0.8)

func _update_bolts(delta: float) -> void:
	for i in range(_bolts.size() - 1, -1, -1):
		var b: Dictionary = _bolts[i]
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) > 0.32:
			_bolts.remove_at(i)

func _draw_bolts(shk: Vector2) -> void:
	for b_v in _bolts:
		var b: Dictionary = b_v
		var a := 1.0 - float(b["t"]) / 0.32
		var segs: Array = b["segs"]
		for i in range(segs.size() - 1):
			var p0: Vector2 = segs[i]
			var p1: Vector2 = segs[i + 1]
			draw_line(p0 + shk, p1 + shk, Color(1.0, 0.98, 0.86, a), 5.0)
			draw_line(p0 + shk + Vector2(2, 0), p1 + shk + Vector2(2, 0), Color(0.86, 0.92, 1.0, a * 0.7), 2.0)
		draw_circle(Vector2(float(b["x"]), float(b["y"])) + shk, 52.0 * (1.0 - a * 0.4), Color(1.0, 0.94, 0.62, a * 0.35))

# ---- 苏青鸾·飞匕（v4f）----
func dg_interval() -> float:
	return maxf(2.0, 8.0 - 1.0 * float(partners["suqingluan"]["sec_lv"]))

func dg_dmg_mul() -> float:
	return 0.80 * (1.0 + 0.25 * float(partners["suqingluan"]["dmg_lv"]))

func dg_pierce() -> int:
	return int(partners["suqingluan"]["pierce_lv"])

func dg_bounce() -> int:
	return int(partners["suqingluan"]["bounce_lv"])

func dg_multi() -> int:
	return 1 + int(partners["suqingluan"]["multi_lv"])

# 弹射伤害：弹射那一下单算（跟飞匕伤害分开）
func dg_bounce_mul() -> float:
	return 0.60 * (1.0 + 0.25 * float(partners["suqingluan"]["bdmg_lv"]))

# 多重伤害：多出来的那几枚匕首单算（+多重伤害 = 多重的整体伤害增加）
func dg_multi_mul() -> float:
	return 0.80 * (1.0 + 0.25 * float(partners["suqingluan"]["mdmg_lv"]))

# 每 8 秒（可减）放一把；多重就是一次放好几把，各自独立结算
func _update_daggers(delta: float) -> void:
	var p: Dictionary = partners["suqingluan"]
	if not bool(p["owned"]):
		return
	p["cd"] = maxf(0.0, float(p["cd"]) - delta)
	if float(p["cd"]) <= 0.0:
		p["cd"] = dg_interval()
		for i in dg_multi():
			var tg := _nearest_except(hero_pos, [] if i == 0 else _thrown_targets())
			if tg.is_empty():
				break
			# 第 1 枚吃"飞匕伤害"，多出来的那几枚吃"多重伤害"
			var mul := dg_dmg_mul() if i == 0 else dg_multi_mul()
			_dg_list.append({"pos": hero_pos + Vector2(0.0, -30.0), "dir": Vector2(0.0, -1.0),
				"tgt": tg, "dmg": float(hero["atk"]) * (1.0 + float(hero["dmg_pct"])) * mul,
				"pierce": dg_pierce(), "bounce": dg_bounce(), "hits": [], "t": 0.0, "multi": i > 0})
		_push_float(hero_pos.x + 70.0, hero_pos.y - 56.0, "飞匕！", Color(0.96, 0.90, 0.62), true)
		Audio.sfx("dart", -6.0, randf_range(0.95, 1.15))

# 多重时别都盯着同一只
func _thrown_targets() -> Array:
	var skip: Array = []
	for d_v in _dg_list:
		var t = (d_v as Dictionary)["tgt"]
		if t != null:
			skip.append(t)
	return skip

func _update_dagger_motion(delta: float) -> void:
	for i in range(_dg_list.size() - 1, -1, -1):
		var d: Dictionary = _dg_list[i]
		d["t"] = float(d["t"]) + delta
		var tg: Dictionary = d["tgt"]
		if tg.is_empty() or float(tg.get("dying", 0.0)) > 0.0 or not foes.has(tg):
			_dg_list.remove_at(i)
			continue
		var tp := Vector2(float(tg["x"]), float(tg["y"]))
		var to_t: Vector2 = tp - (d["pos"] as Vector2)
		var dist := to_t.length()
		if dist <= 20.0:
			# 命中：这一段自己掷一次（"独立伤害"），不吃防御减伤
			var roll := randf()
			# 飞匕＝**物理伤害**（吃防御）；弹射那一段也是物理，只是伤害独立掷
			var dm: float = _apply_dmg(tg, float(d["dmg"]) * (1.8 if roll < float(hero["crit"]) else 1.0), DMG_PHYS)
			tg["flash"] = 0.12
			tg["kb"] = 8.0
			_push_float(float(tg["x"]), float(tg["y"]) - 30.0, "飞匕 " + str(int(dm)),
				Color(0.98, 0.92, 0.66), roll < float(hero["crit"]))
			_bursts.append({"x": float(tg["x"]), "y": float(tg["y"]) - 12.0, "t": 0.0,
				"col": Color(0.98, 0.90, 0.60), "scale": 0.9})
			(d["hits"] as Array).append(tg)
			if float(tg["hp"]) <= 0.0:
				_kill_foe(tg)
			# 先吃穿透，再吃弹射（弹射那一段是"独立"的一笔）
			var nxt: Dictionary = {}
			if int(d["pierce"]) > 0:
				nxt = _nearest_except(tp, d["hits"])
				if not nxt.is_empty():
					d["pierce"] = int(d["pierce"]) - 1
			elif int(d["bounce"]) > 0:
				nxt = _nearest_except(tp, d["hits"])
				if not nxt.is_empty():
					d["bounce"] = int(d["bounce"]) - 1
					# 弹射那一段**换成"弹射伤害"这本账**（不再沿用飞匕伤害）
					d["dmg"] = float(hero["atk"]) * (1.0 + float(hero["dmg_pct"])) * dg_bounce_mul()
					d["multi"] = false
					_push_float(tp.x + 20.0, tp.y - 44.0, "弹射", Color(0.86, 0.94, 1.0))
			if nxt.is_empty():
				_dg_list.remove_at(i)
			else:
				d["tgt"] = nxt
				d["pos"] = tp
		else:
			d["dir"] = to_t.normalized()
			d["pos"] = (d["pos"] as Vector2) + (d["dir"] as Vector2) * 620.0 * delta

# 画飞匕：一柄小匕首（刃 ＋ 护手 ＋ 柄），朝着飞的方向
func _draw_daggers(shk: Vector2) -> void:
	for d_v in _dg_list:
		var d: Dictionary = d_v
		var p: Vector2 = d["pos"]
		var dir: Vector2 = d["dir"]
		var n := dir.orthogonal()
		draw_set_transform(p + shk, atan2(dir.y, dir.x) + PI * 0.5, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -18), Vector2(4, 4), Vector2(-4, 4)]), Color(0.94, 0.94, 0.90))
		draw_line(Vector2(-9, 5), Vector2(9, 5), Color(0.72, 0.66, 0.48), 4.0)
		draw_line(Vector2(0, 5), Vector2(0, 14), Color(0.60, 0.52, 0.40), 4.0)
		draw_set_transform(shk)

# 每帧：内力回复 ＋ 伙伴技能的冷却/持续/自动释放
func _update_partners(delta: float) -> void:
	hero["mp"] = minf(float(hero["mp_max"]), float(hero["mp"]) + MP_REGEN * delta)
	for id in partners.keys():
		var p: Dictionary = partners[id]
		if not bool(p["owned"]):
			continue
		# 只处理"内力/持续/冷却"型的伙伴技能；苏青鸾那种"每隔 N 秒出一枚"走 _update_daggers
		if float((PARTNER_INFO[id] as Dictionary)["mp0"]) <= 0.0:
			continue
		p["active"] = maxf(0.0, float(p["active"]) - delta)
		p["cd"] = maxf(0.0, float(p["cd"]) - delta)
		if float(p["cd"]) <= 0.0 and float(hero["mp"]) >= p_mp(str(id)):
			hero["mp"] = float(hero["mp"]) - p_mp(str(id))
			p["cd"] = p_cd(str(id))
			p["active"] = p_dur(str(id))
			var info: Dictionary = PARTNER_INFO[id]
			_push_float(hero_pos.x + 60.0, hero_pos.y - 40.0, str(info["skill"]) + "！", Color(0.86, 0.74, 1.0), true)
			_bursts.append({"x": hero_pos.x, "y": hero_pos.y - 10.0, "t": 0.0,
				"col": Color(0.78, 0.62, 1.0), "scale": 1.6})
			Audio.sfx("skill", -6.0)

func p_active(id: String) -> bool:
	return float(partners[id]["active"]) > 0.0

func p_ratio(id: String) -> float:
	var d := p_dur(id)
	if d <= 0.0:
		return 0.0
	return clampf(float(partners[id]["active"]) / d, 0.0, 1.0)

# 肝：持续时间内每杀一只 → 生命上限 +2（并回同样多的血）
func _on_kill_partner() -> void:
	if not p_active("anying"):
		return
	var add := p_kill_hp()
	hero["hp_max"] = float(hero["hp_max"]) + add
	hero["hp"] = minf(float(hero["hp_max"]), float(hero["hp"]) + add)
	_push_float(hero_pos.x - 46.0, hero_pos.y - 52.0, "生命上限 +" + str(int(add)), Color(0.72, 0.92, 0.72))
	# 肝的动画：三颗绿光点从击杀处飘回主角身上
	for i in 3:
		_motes.append({"x": hero_pos.x + randf_range(-26.0, 26.0), "y": hero_pos.y + randf_range(-6.0, 22.0), "t": 0.0})

# 刺骨：持续时间内被攻击 → 对攻击者造成"生命上限 × 2%"的**真实伤害**（一点不减；升级还能多打几个）
func _on_hero_hurt(src: Dictionary) -> void:
	if not p_active("chenshi") or src.is_empty():
		return
	var dm := float(hero["hp_max"]) * p_thorns()
	var n := p_thorn_targets()
	var done := 0
	for f_v in foes.duplicate():
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0:
			continue
		if done >= n:
			break
		if done > 0 and f != src:
			continue
		f["hp"] = float(f["hp"]) - dm
		f["flash"] = 0.12
		# 刺骨的动画：一根粉色骨刺从主角甩向攻击者
		_thorn_lines.append({"from": hero_pos, "to": Vector2(float(f["x"]), float(f["y"])), "t": 0.0})
		_push_float(float(f["x"]), float(f["y"]) - 30.0, "刺骨 " + str(int(dm)), Color(0.94, 0.72, 0.86), true)
		_bursts.append({"x": float(f["x"]), "y": float(f["y"]) - 14.0, "t": 0.0,
			"col": Color(0.92, 0.60, 0.82), "scale": 1.1})
		done += 1
		if float(f["hp"]) <= 0.0:
			_kill_foe(f)

# ============================================================
# 伙伴技能的**专属特效**（v4g 用户：「所有角色的技能都是不同特效 特效动画」）
#   肝（暗影裁决）＝暗紫暗影：脚下旋转的三道暗环 ＋ 三颗绕行暗珠 ＋ 一道竖直紫气
#   刺骨（陈石）　 ＝粉色骨刺：身周六根骨刺随呼吸伸缩 ＋ 一圈脉动环；挨打时甩出一道刺线
#   飞匕（苏青鸾） ＝手上两点寒光（待机）＋ 飞出去的小匕首（在 _draw_daggers 里）
# ============================================================
var _motes: Array = []              # 肝：杀敌时冒起的绿色光点 {x,y,vy,t}
var _thorn_lines: Array = []        # 刺骨：反伤刺线 {from,to,t}

func _draw_partner_fx(shk: Vector2) -> void:
	var hp2 := hero_pos + shk
	# —— 肝：暗影 ——
	if p_active("anying"):
		var k := 0.45 + 0.55 * p_ratio("anying")
		for i in 3:
			var a0 := _t * 2.4 + TAU * float(i) / 3.0
			draw_arc(hp2 + Vector2(0, 16), 40.0 + 12.0 * float(i), a0, a0 + 1.7, 16,
				Color(0.60, 0.38, 0.94, 0.5 * k), 4.0)
		for j in 3:
			var a1 := -_t * 3.1 + TAU * float(j) / 3.0
			var op := hp2 + Vector2(0, 10) + Vector2(cos(a1), sin(a1) * 0.35) * 54.0
			draw_circle(op, 6.0, Color(0.72, 0.52, 1.0, 0.85 * k))
			draw_circle(op, 11.0, Color(0.52, 0.30, 0.86, 0.25 * k))
		draw_line(hp2 + Vector2(0, -104), hp2 + Vector2(0, 14), Color(0.66, 0.46, 0.96, 0.22 * k), 12.0)
	# —— 刺骨：骨刺 ——
	if p_active("chenshi"):
		var k2 := 0.45 + 0.55 * p_ratio("chenshi")
		var pulse := 1.0 + sin(_t * 9.0) * 0.16
		for i in 6:
			var a2 := TAU * float(i) / 6.0 + _t * 0.6
			var d2 := Vector2(cos(a2), sin(a2) * 0.85)
			var base := hp2 + Vector2(0, 6) + d2 * 26.0
			draw_line(base, base + d2 * 20.0 * pulse, Color(0.92, 0.55, 0.78, 0.9 * k2), 4.0)
			draw_line(base + d2 * 20.0 * pulse, base + d2 * 27.0 * pulse, Color(0.98, 0.80, 0.90, 0.7 * k2), 2.0)
		draw_arc(hp2 + Vector2(0, 6), 34.0, 0.0, TAU, 26, Color(0.90, 0.45, 0.72, 0.35 * k2), 2.0)
	# —— 飞匕：待机时手上一点寒光 ——
	if bool((partners["suqingluan"] as Dictionary)["owned"]):
		var tw := 0.5 + 0.5 * sin(_t * 6.0)
		draw_circle(hp2 + Vector2(26, -22), 3.0 + 1.6 * tw, Color(0.86, 0.96, 1.0, 0.8))
		draw_circle(hp2 + Vector2(34, -6), 2.2 + 1.2 * (1.0 - tw), Color(0.80, 0.94, 1.0, 0.7))
	# —— 肝的杀敌绿光点（往上飘）——
	for m_v in _motes:
		var m: Dictionary = m_v
		var ma := 1.0 - float(m["t"]) / 0.7
		draw_circle(Vector2(float(m["x"]), float(m["y"])), 3.5, Color(0.66, 0.96, 0.72, ma))
	# —— 刺骨的刺线（从主角甩向攻击者）——
	for l_v in _thorn_lines:
		var l: Dictionary = l_v
		var la := 1.0 - float(l["t"]) / 0.28
		var a3: Vector2 = l["from"]
		var b3: Vector2 = l["to"]
		var mid := (a3 + b3) * 0.5 + (b3 - a3).orthogonal().normalized() * 14.0
		draw_line(a3 + shk, mid + shk, Color(0.94, 0.52, 0.78, la), 4.0)
		draw_line(mid + shk, b3 + shk, Color(0.98, 0.78, 0.90, la), 3.0)
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
		var life := 0.32 if _aspd_flash > 0.0 else 0.20
		var a := 1.0 - float(sl["t"]) / life
		var c := (Color(1.0, 0.86, 0.42, a) if bool(sl["crit"]) else Color(1.0, 0.98, 0.94, a))
		var cx := float(sl["x"])
		var cy := float(sl["y"])
		var ang := float(sl["ang"])
		var len := (40.0 if bool(sl["crit"]) else 28.0)
		# 横扫（溅射）——v3b 加大加亮：一层**扇形光幕** ＋ 三道弧 ＋ 一道亮边，一眼分得出是范围技
		if bool(sl.get("wide", false)):
			var oc := Vector2(cx, cy + 40.0)
			# 半径跟着**溅射等级**走（v3c：范围技——玩家一眼看出圈变大了）
			var R := float(sl.get("radius", 110.0))
			var k2 := R / 110.0
			# ① 扇形光幕（从主角身前铺开的一片光）
			var fan := PackedVector2Array()
			fan.append(oc)
			for k in 13:
				var ang2 := PI * 1.02 + PI * 0.96 * float(k) / 12.0
				fan.append(oc + Vector2(cos(ang2), sin(ang2)) * R)
			draw_colored_polygon(fan, Color(1.0, 0.86, 0.52, a * 0.28))
			# ② 三道弧（越外越淡）——半径按等级放大
			draw_arc(oc, 108.0 * k2, PI * 1.06, PI * 1.94, 34, Color(1.0, 0.92, 0.66, a), 9.0 if bool(sl["crit"]) else 7.0)
			draw_arc(oc, 88.0 * k2, PI * 1.10, PI * 1.90, 34, Color(1.0, 0.88, 0.58, a * 0.8), 6.0)
			draw_arc(oc, 132.0 * k2, PI * 1.16, PI * 1.84, 34, Color(1.0, 0.80, 0.44, a * 0.45), 4.0)
			# ③ 亮边（刀锋那一线）
			draw_arc(oc, 118.0 * k2, PI * 1.02, PI * 1.20, 10, Color(1.0, 0.98, 0.92, a), 3.0)
			# ④ 范围边界：一圈淡光，把"打到哪儿"画清楚
			draw_arc(Vector2(cx, cy), R, 0.0, TAU, 34, Color(1.0, 0.84, 0.48, a * 0.35), 2.5)
			continue
		var d := Vector2(cos(ang), sin(ang)) * len
		draw_line(Vector2(cx - d.x, cy - d.y), Vector2(cx + d.x, cy + d.y), c, (5.0 if bool(sl["crit"]) else 3.5))
		draw_line(Vector2(cx - d.y * 0.6, cy + d.x * 0.6), Vector2(cx + d.y * 0.6, cy - d.x * 0.6),
			Color(c.r, c.g, c.b, a * 0.7), 2.5)
	_draw_qi()
	_draw_jg(shk)
	_draw_daggers(shk)
	_draw_partner_fx(shk)
	# 命中炸开（溅射/剑气）：一圈冲击环 ＋ 八根放射线
	for bu_v in _bursts:
		var bu: Dictionary = bu_v
		var ba := 1.0 - float(bu["t"]) / 0.30
		var bc: Color = bu["col"]
		var bs := float(bu["scale"]) * (0.6 + 0.9 * (1.0 - ba))
		var bp := Vector2(float(bu["x"]), float(bu["y"]))
		draw_arc(bp, 30.0 * bs, 0.0, TAU, 22, Color(bc.r, bc.g, bc.b, ba * 0.9), 4.0)
		for k2 in 8:
			var ang3 := TAU * float(k2) / 8.0 + float(bu["t"]) * 3.0
			draw_line(bp + Vector2(cos(ang3), sin(ang3)) * 12.0 * bs,
				bp + Vector2(cos(ang3), sin(ang3)) * 40.0 * bs, Color(bc.r, bc.g, bc.b, ba), 3.5)
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
	# 开场等待：屏幕上写清"为什么还没动"
	if intro_wait > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 200.0, h * 0.40), "预备… " + str(int(ceil(intro_wait))) + " 秒",
			HORIZONTAL_ALIGNMENT_CENTER, 400.0, 30, Color(0.94, 0.90, 0.80, 0.9))
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
