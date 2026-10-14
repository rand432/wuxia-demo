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
const DMG_METAL := "金系"       # v4j 张道陵·天雷道术
const DMG_WOOD := "木系"        # v4k 柳卿卿·回春（毒）
const DMG_FIRE := "火系"        # v4k 季沧海·怒火焚身
const DMG_WATER := "水系"       # v4l 崔三娘·雾海龙王（召唤物的大浪拍击）
const DMG_EARTH := "土系"       # v4o 法度·怒目金刚（护盾破碎的震荡）
# 规则（v4j/v4k 统一）：**元素（金/木/火）都不吃兵器防御**，只看对应的抗性（现在默认 0）

# v5f：这一版起，**主角出伤统一走 hero_out_dmg()**（全伤害增加 → 元素加成 → 暴击[仅物理] → 幸运一击），
#   这里只管"怪那一侧的防御/抗性"——所以两处都不会重复乘，加新技能也不必各自记得加。
# v15w 临时增益的计时 —— 只减时间，效果在各自用到的地方读
#   主角：lifesteal（吸血）· dr（减伤）· drunk（酒气加攻）
#   怪：armor_break（破甲）· blind（致盲）· slow（减速）
func _buffs_tick(delta: float) -> void:
	for k in ["lifesteal_t", "dr_t", "drunk_t"]:
		if float(hero.get(k, 0.0)) > 0.0:
			hero[k] = maxf(0.0, float(hero[k]) - delta)
	for f_v in foes:
		var f: Dictionary = f_v
		for k2 in ["armor_break_t", "blind_t", "slow_t"]:
			if float(f.get(k2, 0.0)) > 0.0:
				f[k2] = maxf(0.0, float(f[k2]) - delta)

func _apply_dmg(f: Dictionary, amount: float, dtype: String) -> float:
	# v15w 醉太岁「酒气」：窗口内主角出伤 +25%
	if float(hero.get("drunk_t", 0.0)) > 0.0:
		amount *= 1.0 + float(hero.get("drunk_atk", 0.0))
	var o := hero_out_dmg(amount, dtype)
	var amt := float(o["dmg"])
	var final := amt
	if dtype == DMG_PHYS:
		final = maxf(1.0, amt - float(f["hp_max"]) * 0.02)      # 物理吃怪的"防御"折算
	# v15w 破阵刀客「破甲」：被破甲的目标护甲 −20%
	if float(f.get("armor_break_t", 0.0)) > 0.0:
		final *= 0.80
	if float(f.get("boss_cut", 0.0)) > 0.0:
		final *= 1.0 - float(f["boss_cut"])            # v14g：boss 词缀"重甲"减伤
	elif dtype == DMG_METAL:
		final = maxf(1.0, amt * (1.0 - float(f.get("res_metal", 0.0))))
	elif dtype == DMG_WOOD:
		final = maxf(1.0, amt * (1.0 - float(f.get("res_wood", 0.0))))
	elif dtype == DMG_FIRE:
		final = maxf(1.0, amt * (1.0 - float(f.get("res_fire", 0.0))))
	elif dtype == DMG_WATER:
		final = maxf(1.0, amt * (1.0 - float(f.get("res_water", 0.0))))
	elif dtype == DMG_EARTH:
		final = maxf(1.0, amt * (1.0 - float(f.get("res_earth", 0.0))))
	# 暴击/幸运的飘字标记挂在"这一帧最后一次伤害"上（外层读它来飘字）
	_last_crit = bool(o["crit"])
	_last_lucky = bool(o["lucky"])
	# v13d P3：石像在，怪少挨 20%
	if float(f.get("buff", 0.0)) > 0.0:
		final *= STATUE_CUT
	f["hp"] = float(f["hp"]) - final
	# v15w 杏林医女「回春针」：吸血窗口内，按伤害的百分比回血
	if float(hero.get("lifesteal_t", 0.0)) > 0.0 and float(hero["hp"]) > 0.0:
		var ls := final * float(hero.get("lifesteal", 0.04))
		hero["hp"] = minf(float(hero["hp_max"]), float(hero["hp"]) + ls)
	dmg_done += final
	f["last_dtype"] = dtype
	return final

var _last_crit := false
var _last_lucky := false
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
# v14g（用户："不同boss有不同的技能 大招 和词缀"）：每阶 3 只 boss，各带**技能 / 大招 / 词缀**
#   · 词缀＝登场就吃的增益（数值型，spawn 时应用）
#   · 技能＝被动型（数值/机制，spawn 时写进 foe 字段，由各自逻辑读）
#   · 大招＝周期性范围技（ult_cd 秒一次，砸一圈 + 震屏）
const BOSS_TIER := [
	{"name": "看门恶犬", "hp": 1600.0, "atk": 22.0,
		"skill": "撕咬连击", "ult": "狂吠震地", "affix": "狂暴（攻击 +25%）",
		"affix_k": "atk_up", "affix_v": 0.25, "ult_cd": 14.0},
	{"name": "铁背苍狼", "hp": 2000.0, "atk": 19.0,
		"skill": "铁背（减伤 30%）", "ult": "冲撞", "affix": "铁壁（生命 +35%）",
		"affix_k": "hp_up", "affix_v": 0.35, "ult_cd": 16.0},
	{"name": "毒牙蟒", "hp": 1750.0, "atk": 20.0,
		"skill": "剧毒（攻击带毒）", "ult": "毒雾喷吐", "affix": "迅捷（移速 +30%）",
		"affix_k": "spd_up", "affix_v": 0.30, "skill_k": "poison", "ult_cd": 12.0},
	{"name": "双头狮", "hp": 5200.0, "atk": 40.0,
		"skill": "双头夹击", "ult": "狮吼", "affix": "嗜血（击中回血）",
		"affix_k": "lifesteal", "affix_v": 0.15, "ult_cd": 13.0},
	{"name": "独眼狱卒", "hp": 6200.0, "atk": 36.0,
		"skill": "锁链拖拽", "ult": "铁链横扫", "affix": "重甲（减伤 40%）",
		"affix_k": "cut_up", "affix_v": 0.40, "ult_cd": 15.0},
	{"name": "火尾狐妖", "hp": 5600.0, "atk": 43.0,
		"skill": "狐火（火系溅射）", "ult": "焚身爆", "affix": "疾风（攻速 +30%）",
		"affix_k": "aspd_up", "affix_v": 0.30, "skill_k": "foxfire", "ult_cd": 11.0},
	{"name": "场主亲养·狴犴", "hp": 14000.0, "atk": 64.0,
		"skill": "牢狱威压", "ult": "断罪一击", "affix": "王威（全属性 +30%）",
		"affix_k": "all_up", "affix_v": 0.30, "ult_cd": 12.0},
	{"name": "血手判官", "hp": 16500.0, "atk": 58.0,
		"skill": "血判（吸血 25%）", "ult": "血海", "affix": "再生（每秒回 1%）",
		"affix_k": "regen", "affix_v": 0.01, "ult_cd": 10.0},
	{"name": "困兽之主", "hp": 19000.0, "atk": 70.0,
		"skill": "兽王号令（召小怪）", "ult": "万兽奔踏", "affix": "不死（濒死回血一次）",
		"affix_k": "revive", "affix_v": 1.0, "skill_k": "summon", "ult_cd": 9.0},
]

# v14g：每阶 3 只里随机挑一只出场（词缀/大招各不相同）
func _boss_pick(tier: int) -> Dictionary:
	var lo := (tier - 1) * 3
	var idx := lo + (randi() % 3)
	return BOSS_TIER[clampi(idx, 0, BOSS_TIER.size() - 1)]
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
# v14d：宠物配置（外壳通过 set_pet_cfg 推进来；默认＝白狐）
var pet_cfg := {"cd": 1.1, "dmg": 0.35, "elem": "", "chain": 1, "room": 0.0, "verb": "咬 "}

func set_pet_cfg(d: Dictionary) -> void:
	for k in d.keys():
		pet_cfg[k] = d[k]
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
const HERO_TOP := 0.25              # 主角/宠物能到的最高那条线（战场高度的比例）
									#   v3j 从 0.40 收到 0.25；两条路都吃它：自动追击 与 点哪走哪
									#   ⚠ v15j 一度改成 0.30，用户确认 25% 才是原设计 → 已改回
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
	_mp_base = float(hero["mp_max"])       # 纳气按"原本内力"的百分比涨，先记下基数

# 重开一局：伙伴全部退回未入队（招募是这一局的事）
func reset_partners() -> void:
	for pid in partners.keys():
		var p: Dictionary = partners[pid]
		p["owned"] = false
		p["cd"] = 0.0
		p["active"] = 0.0
	_minions.clear()
	_dg_list.clear()
	_qi_list.clear()
	_jg_list.clear()

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

# v14e：关卡难度倍率（外壳按所选关卡推进来）
# v15s（用户："目前难度太低了 提升50%"）：
#   全局难度系数 —— 乘在**每一处怪的血/攻**上（普通怪、boss、挑战怪）。
#   ⚠ 没有去改 foe_mul：那个是"关卡难度倍率"，外壳每局会覆盖它（只剩一个赋值点），
#     改它会被盖掉。这里单独一个系数，各处用量自行相乘。
const DIFFICULTY := 1.5           # 第 10 波起的难度倍率（满值）
var foe_mul := 1.0

# v15y（用户："前十波难度下调"）：
#   原来 DIFFICULTY 是**常数**、所有波都 ×1.5 —— 开局十波也被抬了 50%。
#   而现在前十波本来不出 boss（boss 从第 10 波起），等于"最难的开头配最弱的奖励"。
#   现在：**前十波从 ×1.0 线性爬到 ×1.5**（波1 就是加强前的原样），第 10 波起保持 ×1.5。
func diff_mul() -> float:
	var w := maxi(1, wave)
	if w >= 10:
		return DIFFICULTY
	return 1.0 + (DIFFICULTY - 1.0) * float(w - 1) / 9.0

func _foe_hp() -> float:
	return BASE_FOE_HP * pow(WAVE_HP, float(wave - 1)) * foe_mul * diff_mul()      # v14e：关卡难度倍率

func _foe_atk() -> float:
	return BASE_FOE_ATK * pow(WAVE_ATK, float(wave - 1)) * foe_mul * diff_mul()    # v14e：关卡难度倍率

func _spawn_foe(kind := "normal", hp_mul := 1.0, atk_mul := 1.0, big := false, tier := 1, nm := "") -> void:
	if foes.size() >= MAX_FOES and kind == "normal":
		return
	# v13g：**总上限**——挑战怪/招怪套原来绕过了 MAX_FOES，挂机久了能堆到几百只
	if foes.size() >= MAX_FOES + 16 and kind != "boss" and kind != "champion" and kind != "elite":
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


# v9g（用户："文钱/经验/灵晶都是群怪 boss和宝物是大怪"）：
#   **挑战真的刷怪**——群怪走一群小怪；大怪走"体型大、血厚、掉更好"的单只大怪。
#   kind: 0 文钱 · 1 灵晶 · 2 经验 · 3 宝物（大怪）· 4 boss（大怪）
const CHAL_FOE_HP := [1.0, 1.2, 1.0, 2.6, 3.2]        # 血量倍率（大怪明显厚）
const CHAL_FOE_ATK := [0.9, 1.0, 0.9, 1.5, 1.8]       # 攻击倍率
const CHAL_FOE_SCALE := [0.86, 0.86, 0.86, 1.7, 2.0]  # 体型（大怪一眼看得出来）
const CHAL_FOE_NAME := ["钱怪", "晶怪", "书怪", "宝箱大怪", "挑战 boss"]
# v15o（用户："挑战方面 也会随着波次增强 奖励也会随之提升"）：
#   挑战原来跟普通怪吃**同一条**波次曲线（血 1.12^波 / 攻 1.08^波），后期会觉得"白送"。
#   这里再叠一层**挑战专属**的线性爬升：怪涨得比奖励快（不然灵晶经济会崩）。
const CHAL_HP_RAMP := 0.06          # 挑战怪血：每波 +6%（波30 → ×2.74）
const CHAL_ATK_RAMP := 0.05         # 挑战怪攻：每波 +5%（波30 → ×2.45）
const CHAL_MONEY_RAMP := 0.05       # 钱怪文钱：每波 +5%
const CHAL_CRYSTAL_RAMP := 0.03     # 晶怪灵晶：每波 +3%（保守：挑战每波都能刷，涨猛了一局 1500+ 灵晶）
const CHAL_EXP_RAMP := 0.04         # 书怪经验：每波 +4%

func chal_hp_mul() -> float:
	return 1.0 + CHAL_HP_RAMP * float(maxi(0, wave - 1))

func chal_atk_mul() -> float:
	return 1.0 + CHAL_ATK_RAMP * float(maxi(0, wave - 1))

func chal_money_mul() -> float:
	return 1.0 + CHAL_MONEY_RAMP * float(maxi(0, wave - 1))

func chal_crystal_mul() -> float:
	return 1.0 + CHAL_CRYSTAL_RAMP * float(maxi(0, wave - 1))

func chal_exp_mul() -> float:
	return 1.0 + CHAL_EXP_RAMP * float(maxi(0, wave - 1))

func spawn_challenge(kind_i: int, n: int) -> void:
	var i := clampi(kind_i, 0, 4)
	var big := i >= 3
	for k in maxi(1, n):
		# v15s：挑战怪也吃全局难度 +50%
		_spawn_foe("chal", float(CHAL_FOE_HP[i]) * chal_hp_mul() * diff_mul(),
			float(CHAL_FOE_ATK[i]) * chal_atk_mul() * diff_mul(), big, 1, str(CHAL_FOE_NAME[i]))
		var f: Dictionary = foes[foes.size() - 1]
		f["scale"] = float(CHAL_FOE_SCALE[i])
		f["chal"] = i                              # 掉什么由这个字段决定（结算侧读它）
		f["stop"] = (FOE_STOP + 60.0 if big else FOE_STOP) + randf() * 20.0
	_banner = ("挑战：" + str(CHAL_FOE_NAME[i]) + ("　大怪" if big else ("　一群 " + str(n) + " 只")))
	_banner_t = 2.0
	Audio.sfx("bell", -8.0)
	if big:
		Audio.sfx("drum", -6.0)
# 叫 boss（阶 1~3）
func start_boss(tier: int) -> void:
	var tt := clampi(tier, 1, 3)
	var d := _boss_pick(tt)                     # v14g：每阶 3 只随机一只（技能/大招/词缀都不同）
	var mul := pow(WAVE_HP, float(wave - 1)) * foe_mul * diff_mul()
	_spawn_foe("boss", 1.0, 1.0, true, tt, str(d["name"]))
	var f: Dictionary = foes[foes.size() - 1]
	var hp_mul := mul
	var atk_mul := pow(WAVE_ATK, float(wave - 1)) * foe_mul * diff_mul()
	# ---- 技能（登场写进字段，由各自逻辑读）----
	#   v14t：只剩这两条没接了，补齐——召小怪（兽王号令）· 狐火（攻击带火系溅射）
	match str(d.get("skill_k", "")):
		"poison":
			f["boss_poison"] = true
		"summon":
			f["boss_summon"] = 1
			f["boss_summon_t"] = 8.0          # 登场 8 秒后第一次号令，之后每 12 秒
		"foxfire":
			f["boss_foxfire"] = 1
	# ---- 词缀（登场就吃）----
	match str(d.get("affix_k", "")):
		"hp_up":
			hp_mul *= 1.0 + float(d["affix_v"])
		"atk_up":
			atk_mul *= 1.0 + float(d["affix_v"])
		"cut_up":
			f["boss_cut"] = float(d["affix_v"])          # 减伤（_apply_dmg 读）
		"spd_up":
			f["boss_spd"] = float(d["affix_v"])
		"poison":
			f["boss_poison"] = true
		"aspd_up":
			f["boss_aspd"] = float(d["affix_v"])
		"all_up":
			hp_mul *= 1.0 + float(d["affix_v"])
			atk_mul *= 1.0 + float(d["affix_v"])
		"lifesteal":
			f["boss_lifesteal"] = float(d["affix_v"])
		"regen":
			f["boss_regen"] = float(d["affix_v"])
		"revive":
			f["boss_revive"] = 1
	f["hp"] = float(d["hp"]) * hp_mul
	f["hp_max"] = float(d["hp"]) * hp_mul
	f["atk"] = float(d["atk"]) * atk_mul
	f["bname"] = str(d["name"])
	f["bskill"] = str(d.get("skill", ""))
	f["bult"] = str(d.get("ult", ""))
	f["baffix"] = str(d.get("affix", ""))
	f["ult_t"] = float(d.get("ult_cd", 14.0))     # v14g：大招计时
	boss_alive = true
	_banner = ["", "一阶 boss", "二阶 boss", "三阶 boss"][tt] + "　" + str(d["name"])
	_banner_t = 2.4
	_push_float(hero_pos.x + 80.0, hero_pos.y - 120.0, str(d.get("affix", "")), Color(0.96, 0.72, 0.42), true)
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
	kill_normal = 0
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
		# v13d P3：石像是任务目标，浴血不清它
		if bool(f.get("still", false)):
			continue
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
	for i7 in range(_blood.size() - 1, -1, -1):
		var bl: Dictionary = _blood[i7]
		bl["t"] = float(bl["t"]) + delta
		bl["y"] = float(bl["y"]) - 54.0 * delta
		bl["x"] = float(bl["x"]) + float(bl["vx"]) * delta
		if float(bl["t"]) > 0.7:
			_blood.remove_at(i7)
	for i8 in range(_qi_threads.size() - 1, -1, -1):
		var qt: Dictionary = _qi_threads[i8]
		qt["t"] = float(qt["t"]) + delta
		# 从外往身上收（跟"肝"的往上飘正好相反）
		qt["x"] = lerpf(float(qt["x"]), float(qt["px"]), delta * 3.2)
		qt["y"] = lerpf(float(qt["y"]), float(qt["py"]), delta * 3.2)
		if float(qt["t"]) > 0.7:
			_qi_threads.remove_at(i8)
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
	_fx_trim()          # v13g：特效超预算就丢老的（大场面保帧率）
	if not running:
		queue_redraw()
		return
	# v13b：点地的指令圈淡出
	for i9 in range(_order_fx.size() - 1, -1, -1):
		var ofx: Dictionary = _order_fx[i9]
		ofx["t"] = float(ofx["t"]) + delta
		if float(ofx["t"]) > 0.5:
			_order_fx.remove_at(i9)
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
	_hero_cd -= delta
	# v13b P1：点击指令计时（走位指令到点/超时自动撤销 → 回自动战斗）
	_order_t += delta
	var target := _order_target()
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
	elif _order_has_pos:
		# v13b P1：**走位指令优先**（自动追怪让位）——走到点、或 6 秒后自动撤销
		var od := hero_pos.distance_to(_order_pos)
		if od <= ORDER_STOP_DIST or _order_t > ORDER_MOVE_SEC:
			_order_has_pos = false
		else:
			hero_pos += (_order_pos - hero_pos).normalized() * minf(HERO_SPD_FAR * delta, od)
			_hero_step += delta * 8.0
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
	# v15j（用户：临时指令倒是不限制）：**有手动指令时这条线放开** —— 手指点上去就让它上去；
	#   自动追击仍旧卡在 HERO_TOP（否则它会一路追到怪出生点，屏幕里全是空的）。
	# v15o：放开的下限从 8.0 收到 HERO_LINE（脚的位置），保证整个小人还在战场框里
	var top_line := (HERO_LINE if _order_has_pos else size.y * HERO_TOP)
	hero_pos.y = clampf(hero_pos.y, top_line, size.y - HERO_LINE * 0.5)
	# v13d P3：法阵——站圈里累计，出圈按半速回退
	if not zone.is_empty() and bool(zone.get("on", false)):
		if _in_zone():
			zone["prog"] = float(zone["prog"]) + delta
		else:
			zone["prog"] = maxf(0.0, float(zone["prog"]) - delta * ZONE_DECAY)
	# v13e P4：牢车挨打的闪白
	if not guard.is_empty():
		guard["flash"] = maxf(0.0, float(guard.get("flash", 0.0)) - delta)
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
	# v15u（用户："还有主角和宠物还是会往上跑"）：⚠ 原来这里上限是**写死**的
	#   `size.y * HERO_TOP + 12` —— 两个毛病：
	#     ① 主角手动走位时那条线已经放开（v15j），宠物却还被卡在老位置 → 主人上去了它上不去；
	#     ② `+12` 是"往上加"，让宠物比主角还靠上 12px，反而更早探出战场框。
	#   现在：跟主角**共用同一条 top_line**（上面刚算过），并且往下收 6px 而不是往上加。
	pet_pos.x = clampf(pet_pos.x, 44.0, size.x - 44.0)
	pet_pos.y = clampf(pet_pos.y, top_line + 6.0, size.y - HERO_LINE * 0.4)
	_pet_cd -= delta
	if _pet_cd <= 0.0 and not target.is_empty() and pet_pos.distance_to(tpos) <= PET_REACH + 18.0:
		# v14d（用户："宠物在困兽里面毕竟是没有生命的…给他一个加成效果【或者特效技能】和攻击伤害即可
		#        "做一些不同类型的宠物"）：宠物只做两件事——**咬人**（伤害/频率/元素/连锁各不同）＋ **给主人的被动加成**
		_pet_cd = float(pet_cfg.get("cd", 1.1))
		_pet_wind = 1.0
		_pet_lunge = 1.0
		_pet_dir = (tpos - pet_pos).normalized()
		var pd := maxf(1.0, float(hero["atk"]) * float(pet_cfg.get("dmg", 0.35)))
		var elem := str(pet_cfg.get("elem", ""))
		var chain := maxi(1, int(pet_cfg.get("chain", 1)))
		var room := float(pet_cfg.get("room", 0.0))
		var hits: Array = [target]
		if chain > 1 or room > 0.0:
			var at := Vector2(float(target["x"]), float(target["y"]))
			for f_v in foes:
				var fx: Dictionary = f_v
				if fx == target or float(fx.get("dying", 0.0)) > 0.0:
					continue
				if room > 0.0 and at.distance_to(Vector2(float(fx["x"]), float(fx["y"]))) <= room:
					hits.append(fx)
				elif hits.size() < chain:
					hits.append(fx)
		for h_v in hits:
			var h: Dictionary = h_v
			var dm := _apply_dmg(h, pd * (0.7 if h != target else 1.0), elem if elem != "" else DMG_PHYS)
			h["flash"] = 0.12
			_slashes.append({"x": float(h["x"]) + _pet_dir.x * 10.0, "y": float(h["y"]) + _pet_dir.y * 10.0,
				"t": 0.0, "ang": randf_range(-1.2, 1.2), "crit": false})
			_push_float(float(h["x"]) + 16.0, float(h["y"]) - 10.0, str(pet_cfg.get("verb", "咬 ")) + str(int(dm)),
				Color(0.84, 0.90, 0.98), true)
			if float(h["hp"]) <= 0.0:
				_kill_foe(h)
		_shake = maxf(_shake, 3.0)
		Audio.sfx("melee", -10.0, randf_range(0.92, 1.12))
		if float(target["hp"]) <= 0.0:
			_kill_foe(target)
	# 出手：只在**够得着**的时候打（不再隔着半屏砍）；开场等待期间也不出手
	if intro_wait <= 0.0 and _hero_cd <= 0.0 and not target.is_empty() and hero_pos.distance_to(tpos) <= HERO_REACH + 16.0:
		var tgt := target
		if true:
			# 出手间隔吃"攻速提升"（技能）
			# v14a 连杀卡：连杀每 10 层 → 攻速 +5%（上限 +50%）
			var combo_aspd := 0.0
			if float(hero.get("mech_comboaspd", 0.0)) > 0.0:
				combo_aspd = minf(0.50, float(_combo) / 10.0 * float(hero["mech_comboaspd"]))
			_hero_cd = 1.0 / maxf(0.2, float(hero["aspd"]) * aspd_mul() * (1.0 + combo_aspd))
			_hero_strike(tgt)
	# 怪：往下走 / 贴上来打
	# 连杀计时：1.4 秒内没有新击杀就归零
	if _combo_t > 0.0:
		_combo_t -= dt
		if _combo_t <= 0.0:
			_combo = 0
	# 主角的"家"跟着窗口尺寸走（没怪时退回这里）
	_home = Vector2(size.x * 0.5, size.y - HERO_LINE)
	# v13d P3：这一帧"活着的石像"位置（给怪算 buff 用；碎一座立刻失效）
	var live_st: Array = []
	for fst_v in foes:
		var fst: Dictionary = fst_v
		if bool(fst.get("still", false)) and float(fst.get("dying", 0.0)) <= 0.0:
			live_st.append(Vector2(float(fst["x"]), float(fst["y"])))
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
		# 持续伤害（毒/灼烧）：每秒跳一次（麻痹时照样掉血）
		var dots: Array = f.get("dot", [])
		for di in range(dots.size() - 1, -1, -1):
			var dd: Dictionary = dots[di]
			dd["t"] = float(dd["t"]) - dt
			dd["tick"] = float(dd["tick"]) - dt
			if float(dd["tick"]) <= 0.0:
				dd["tick"] = 1.0
				var dtd := str(dd["dtype"])
				var dm3 := _apply_dmg(f, float(hero["atk"]) * float(dd["mul"]), dtd)
				_push_float(float(f["x"]) + 18.0, float(f["y"]) - 22.0, dtd + " " + str(int(dm3)),
					Color(0.64, 0.92, 0.58) if dtd == DMG_WOOD else Color(1.0, 0.66, 0.32))
				if float(f["hp"]) <= 0.0:
					_kill_foe(f)
					break
			if float(dd["t"]) <= 0.0:
				dots.remove_at(di)
		f["dot"] = dots
		if not foes.has(f):
			continue
		# v13d P3：石像——不移动、不出手，只挨打
		if bool(f.get("still", false)):
			f["flash"] = maxf(0.0, float(f.get("flash", 0.0)) - delta)
			continue
		# 麻痹（天雷）：这段时间**不动也不打**
		if float(f.get("para", 0.0)) > 0.0:
			f["para"] = maxf(0.0, float(f["para"]) - dt)
			f["flash"] = maxf(0.0, float(f.get("flash", 0.0)) - delta)
			continue
		# 挨打那一下的击退与闪白
		if float(f.get("kb", 0.0)) > 0.0:
			f["y"] = maxf(20.0, float(f["y"]) - float(f["kb"]) * dt)
			f["kb"] = maxf(0.0, float(f.get("kb", 0.0)) - 130.0 * dt)
		f["flash"] = maxf(0.0, float(f.get("flash", 0.0)) - delta)
		f["lunge"] = maxf(0.0, float(f.get("lunge", 0.0)) - delta * 4.5)
		# v4m：怪打**最近的目标**（主角 **或蛟龙**）——所以蛟龙会被打掉
		var ftgt := hero_pos
		var fmin: Dictionary = {}
		var bd2 := hero_pos.distance_to(Vector2(float(f["x"]), float(f["y"])))
		for m_v in _minions:
			var mm: Dictionary = m_v
			if float(mm.get("dying", 0.0)) > 0.0:
				continue
			var dmv: float = (mm["pos"] as Vector2).distance_to(Vector2(float(f["x"]), float(f["y"])))
			if dmv < bd2:
				bd2 = dmv
				fmin = mm
				ftgt = mm["pos"]
		# v13e P4：守护目标（牢车）也在候选里——离得近就先砸车
		var hit_guard := false
		if not guard.is_empty() and bool(guard.get("on", false)):
			var gp := Vector2(float(guard["x"]), float(guard["y"]))
			var dg := gp.distance_to(Vector2(float(f["x"]), float(f["y"])))
			if dg < bd2:
				bd2 = dg
				fmin = {}
				ftgt = gp
				hit_guard = true
		# v13d P3：石像 buff——附近有活石像 → 攻速 +30% · 少挨 20% 伤害
		var fbuff := 0.0
		for sp_v in live_st:
			if (sp_v as Vector2).distance_to(Vector2(float(f["x"]), float(f["y"]))) <= STATUE_BUFF_R:
				fbuff = 1.0
				break
		f["buff"] = fbuff
		# 怪**朝目标走**（主角会动，所以不再用固定的那条线）——走到 FOE_REACH 就停下开打
		# v14r：boss 词缀"再生"——**只要活着每秒就回**（不能只在贴脸时才回：探针抓到过，
		#   怪还在往下走的那几秒里血一点没涨）
		var breg := float(f.get("boss_regen", 0.0))
		if breg > 0.0 and float(f["hp"]) > 0.0 and float(f["hp"]) < float(f["hp_max"]):
			f["hp"] = minf(float(f["hp_max"]), float(f["hp"]) + float(f["hp_max"]) * breg * delta)
		var to_h := ftgt - Vector2(float(f["x"]), float(f["y"]))
		var dh := to_h.length()
		if dh > FOE_REACH:
			# v3l（用户："boss可以正常速度"）：boss 不再走 0.7 倍——跟寻常怪一个速度
			# v14r：boss 词缀"迅捷"——走得更快（原来 boss_spd 只存着没人读）
			var fspd := FOE_SPD * (1.0 + float(f.get("boss_spd", 0.0)))
			# v15w 冷月娘「寒霜」：被减速的怪走得慢
			if float(f.get("slow_t", 0.0)) > 0.0:
				fspd *= 0.55
			var mv := to_h.normalized() * minf(fspd * delta, dh - FOE_REACH)
			f["x"] = clampf(float(f["x"]) + mv.x, 40.0, size.x - 40.0)
			f["y"] = float(f["y"]) + mv.y
		else:
			# v9i：被雷麻痹的怪，出手计时清零（麻痹 1 秒）
			if float(f.get("para", 0.0)) > 0.0:
				f["para"] = maxf(0.0, float(f["para"]) - delta)
				f["t"] = 0.0
				continue
			f["t"] = float(f["t"]) + delta
			# v14r：boss 词缀"疾风"——出手更频（原来 boss_aspd 只存着没人读）
			var faspd := FOE_ASPD * (1.0 + float(f.get("boss_aspd", 0.0)))
			if float(f["t"]) >= 1.0 / (faspd * (STATUE_ASPD if float(f.get("buff", 0.0)) > 0.0 else 1.0)):
				f["t"] = 0.0
				f["lunge"] = 1.0                 # 怪扑下来那一下
				# 打的是蛟龙：扣它的血（蛟龙没有防御，挨多少掉多少）
				if not fmin.is_empty():
					fmin["hp"] = float(fmin["hp"]) - float(f["atk"])
					_push_float(float((fmin["pos"] as Vector2).x) + 16.0, float((fmin["pos"] as Vector2).y) - 26.0,
						"-" + str(int(f["atk"])), Color(0.94, 0.66, 0.60))
					continue
				# v13e P4：砸牢车（牢车没有防御，挨多少掉多少）
				if hit_guard and not guard.is_empty():
					guard["hp"] = float(guard["hp"]) - float(f["atk"])
					guard["flash"] = 0.20
					_push_float(float(guard["x"]) + 22.0, float(guard["y"]) - 40.0,
						"-" + str(int(f["atk"])), Color(0.98, 0.78, 0.42))
					_shake = maxf(_shake, 3.0)
					if float(guard["hp"]) <= 0.0:
						_break_guard()
					continue
				# v5f：怪打主角走 hero_in_dmg()（物理吃护甲＋全减；元素吃抗性不吃护甲；真实不吃）
				var d2 := hero_in_dmg(float(f["atk"]), DMG_PHYS)
				# v15w 更夫「报更」：被致盲的怪有 35% 概率打空
				if float(f.get("blind_t", 0.0)) > 0.0 and randf() < 0.35:
					_push_float(hero_pos.x, hero_pos.y - 70.0, "打空", Color(0.86, 0.86, 0.62))
					continue
				if randf() < float(hero["dodge"]):
					_push_float(size.x * 0.5, size.y - HERO_LINE - 40.0, "闪", Color(0.60, 0.80, 0.90))
				else:
					d2 = maxf(1.0, d2 * (1.0 - float(hero["cut"])))
					# v4o：先扣护盾（法度·怒目金刚），盾破了才动血
					d2 = _absorb_by_shield(d2)
					hero["hp"] = float(hero["hp"]) - d2
					_hero_hit_flash = 0.18
					_shake = maxf(_shake, 3.5)
					# v14r：boss 词缀"嗜血"（打中回血）与二技能"剧毒"（打中带毒）接上进行为
					# v14t：狐火——这一巴掌带火系溅射（火尾狐妖的技能，原来只是文本）
					if int(f.get("boss_foxfire", 0)) > 0 and d2 > 0.0:
						var ffd := maxf(1.0, hero_in_dmg(float(f["atk"]) * 0.5, DMG_FIRE))
						hero["hp"] = maxf(0.0, float(hero["hp"]) - ffd)
						_bursts.append({"x": hero_pos.x, "y": hero_pos.y - 16.0, "t": 0.0,
							"col": Color(1.0, 0.52, 0.22), "scale": 1.5})
						_push_float(hero_pos.x + 46.0, hero_pos.y - 52.0, "狐火 " + str(int(ffd)), Color(1.0, 0.62, 0.26))
					# v14r：boss 词缀"嗜血"（打中回血）
					var bls := float(f.get("boss_lifesteal", 0.0))
					if bls > 0.0 and float(f["hp"]) > 0.0 and float(f["hp"]) < float(f["hp_max"]):
						var old_hp := float(f["hp"])
						f["hp"] = minf(float(f["hp_max"]), old_hp + d2 * bls)
						if float(f["hp"]) > old_hp:
							_push_float(float(f["x"]) + 14.0, float(f["y"]) - 44.0,
								"嗜血 +" + str(int(float(f["hp"]) - old_hp)), Color(0.86, 0.36, 0.40))
					# v14r：二技能"剧毒"——打中给主角挂毒（每秒跳一次，木系）
					if bool(f.get("boss_poison", false)) and d2 > 0.0:
						hero["poison"] = maxf(float(hero.get("poison", 0.0)), 4.0)
						_push_float(size.x * 0.5 - 40.0, size.y - HERO_LINE - 66.0, "中毒", Color(0.62, 0.90, 0.44))
					# v9f（卡：荆棘 / 护心镜）——**挨打反弹一部分伤害给打你的那只怪**
					var th := float(hero.get("thorns", 0.0))
					if th > 0.0 and float(f.get("dying", 0.0)) <= 0.0:
						var back := maxf(1.0, d2 * th)
						f["hp"] = float(f["hp"]) - back
						_push_float(float(f["x"]) + 10.0, float(f["y"]) - 22.0,
							"反 " + str(int(back)), Color(0.88, 0.62, 0.28))
						_bursts.append({"x": float(f["x"]), "y": float(f["y"]), "t": 0.0,
							"col": Color(0.90, 0.64, 0.30), "scale": 0.6})
					_on_hero_hurt(f)                 # 刺骨：挨打就反真实伤害
					_push_float(size.x * 0.5 + float(randi() % 40 - 20), size.y - HERO_LINE - 40.0, "-" + str(int(d2)), Color(0.86, 0.36, 0.30))
					if float(hero["hp"]) <= 0.0:
						hero["hp"] = 0.0
						running = false
						hero_down.emit()
						break
	_buffs_tick(dt)              # v15w：伙伴给主角挂的那些临时增益（吸血/减伤/酒气）
	_update_card_fx(dt)          # v9i：飞羽 / 流星 / 雷霆
	_update_qi(dt)
	_update_jg(dt)
	_update_partners(dt)
	_update_daggers(dt)
	_update_dagger_motion(dt)
	_update_bolts(dt)
	_update_jicanghai(dt)
	_update_leixiaoqi(dt)       # v14b：雷小七 连环腿
	_update_ximenlie(dt)        # v14b：西门烈 烈焰刀
	_update_minions(dt)
	_update_waves(dt)
	_update_shield(dt)
	if _p_aspd > 0.0:
		_p_aspd = maxf(0.0, _p_aspd - dt)      # v14b：时停的攻速加成倒计时
	# v14a 机制卡：定身脉冲（把全场怪按成"麻痹"）＋ 定期护盾
	if float(hero.get("mech_root", 0.0)) > 0.0:
		_root_t -= dt
		if _root_t <= 0.0:
			_root_t = 25.0
			for f_v in foes:
				var fr: Dictionary = f_v
				if not bool(fr.get("still", false)) and float(fr.get("dying", 0.0)) <= 0.0:
					fr["para"] = maxf(float(fr.get("para", 0.0)), 1.5)
			_push_float(hero_pos.x, hero_pos.y - 100.0, "定身！", Color(0.74, 0.88, 1.0), true)
			Audio.sfx("drum", -6.0)
	if float(hero.get("mech_shield", 0.0)) > 0.0:
		_shield_t -= dt
		if _shield_t <= 0.0:
			_shield_t = 8.0
			var sv := float(hero["hp_max"]) * float(hero["mech_shield"])
			hero["shield_max"] = sv
			hero["shield"] = sv
			hero["shield_t"] = 6.0
			_push_float(hero_pos.x, hero_pos.y - 84.0, "护盾 " + str(int(sv)), Color(0.66, 0.86, 1.0))
	_update_quake(dt)
	for i6 in range(_fire_lines.size() - 1, -1, -1):
		var fl2: Dictionary = _fire_lines[i6]
		fl2["t"] = float(fl2["t"]) + delta
		if float(fl2["t"]) > 0.30:
			_fire_lines.remove_at(i6)
	# v14g：boss 大招——每只 boss 自己那一个，到时砸一圈（带预警震屏）
	for f_v in foes:
		var fb: Dictionary = f_v
		if not bool(fb.get("boss", false)) or float(fb.get("dying", 0.0)) > 0.0:
			continue
		# v14t：兽王号令——定时吼两只小怪下来（跟"大招"分开计时）
		if int(fb.get("boss_summon", 0)) > 0:
			fb["boss_summon_t"] = float(fb.get("boss_summon_t", 12.0)) - dt
			if float(fb["boss_summon_t"]) <= 0.0:
				fb["boss_summon_t"] = 12.0
				var add_n := 2
				for si in add_n:
					if foes.size() < MAX_FOES + 8:
						_spawn_foe("normal", 1.3, 1.1, false, 1, "")
						var addf: Dictionary = foes[foes.size() - 1]
						addf["y"] = -30.0 - float(si) * 40.0
						addf["x"] = clampf(float(fb["x"]) + float(si) * 70.0 - 35.0, 60.0, size.x - 60.0)
				_banner = "兽王号令！" + str(add_n) + " 只走狗扑下来"
				_banner_t = 1.8
				_bursts.append({"x": float(fb["x"]), "y": float(fb["y"]), "t": 0.0,
					"col": Color(0.92, 0.56, 0.28), "scale": 1.8})
				Audio.sfx("tension", -6.0)
		fb["ult_t"] = float(fb.get("ult_t", 14.0)) - dt
		if float(fb["ult_t"]) <= 0.0:
			# ⚠ v14t：这里原来写死 14 秒 —— 表里每只 boss 自己的 ult_cd（9~16）全被吃掉了
			fb["ult_t"] = float(fb.get("ult_cd", 14.0))
			var ult := str(fb.get("bult", "大招"))
			var dmg := float(fb["atk"]) * 1.6
			var d2 := hero_in_dmg(dmg, DMG_PHYS)
			hero["hp"] = maxf(0.0, float(hero["hp"]) - d2)
			_push_float(hero_pos.x, hero_pos.y - 104.0, ult + "！", Color(1.0, 0.48, 0.38), true)
			_bursts.append({"x": hero_pos.x, "y": hero_pos.y - 10.0, "t": 0.0, "col": Color(1.0, 0.46, 0.34), "scale": 2.0})
			_shake = maxf(_shake, 9.0)
			Audio.sfx("drum", -4.0)
			# 大招同时给主角一个"威压"：短暂减攻速
			if float(fb["hp"]) <= 0.0:
				_kill_foe(fb)
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
	# v14b 燕无归「鹰眼」：持续期内暴击 +25%
	var crit_rate := float(hero["crit"])
	if p_active("yanwugui"):
		crit_rate += 0.25 + 0.05 * float(partners["yanwugui"].get("crit_lv", 0))
	var crit := randf() < crit_rate
	_heavy += 1
	var heavy := _heavy % 3 == 0
	var base := float(hero["atk"]) * (1.0 + float(hero["dmg_pct"])) * atk_mul()
	base += float(hero.get("_kill_atk", 0.0))            # v14a 战意：本局每杀一个 +0.4 攻击
	if float(hero.get("mech_laststand", 0.0)) > 0.0 \
			and float(hero["hp"]) / maxf(1.0, float(hero["hp_max"])) <= 0.35:
		base *= 1.0 + float(hero["mech_laststand"])      # v14a 背水：残血 +50%
	if crit:
		base *= 2.0
	if heavy:
		base *= 1.6
	var hit_list: Array = [tgt]
	var dealt := 0.0                                      # v14a 这一刀打出的总伤害（吸血用）
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
		dealt += dmg                                   # v14a 吸血：累计这一刀的总伤害
		if float(h["hp"]) <= 0.0:
			_kill_foe(h)
	# v14a 吸血：按这一刀打出的总伤害回血
	if float(hero.get("mech_lifesteal", 0.0)) > 0.0 and dealt > 0.0:
		var heal := dealt * float(hero["mech_lifesteal"])
		hero["hp"] = minf(float(hero["hp_max"]), float(hero["hp"]) + heal)
		_push_float(hero_pos.x, hero_pos.y - 74.0, "+" + str(int(heal)), Color(0.62, 0.92, 0.72))
	# 刀光：横扫时画一道大弧（动作跟单体突刺不一样）
	if wide:
		_slashes.append({"x": float(tgt["x"]), "y": float(tgt["y"]) - 10.0, "t": 0.0,
			"ang": 0.0, "crit": crit or heavy, "wide": true, "radius": rad})
		Audio.sfx("swing", -3.0, randf_range(0.9, 1.05))      # 横扫的"呼"一声，跟单体刀声分开
	else:
		_slashes.append({"x": float(tgt["x"]), "y": float(tgt["y"]) - 18.0, "t": 0.0,
			"ang": randf_range(-0.9, 0.9), "crit": crit or heavy})
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
	# v13d P3：占点时只认**圈里的怪**——不然主角会追出圈，进度就白站了
	var zc := Vector2.ZERO
	var in_zone := false
	if not zone.is_empty() and bool(zone.get("on", false)):
		zc = Vector2(float(zone["x"]), float(zone["y"]))
		in_zone = hero_pos.distance_to(zc) <= float(zone["r"])
	for f_v in foes:
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0:
			continue                             # 已经躺了的不再补刀
		if in_zone and Vector2(float(f["x"]), float(f["y"])).distance_to(zc) > float(zone["r"]):
			continue                             # 圈外的先不管
		var d := hero_pos.distance_to(Vector2(float(f["x"]), float(f["y"])))
		if d < bd:
			bd = d
			best = f
	return best
# ============================================================
# v13b P1：点击指令（**临时指令**，优先级高于自动战斗）
#   用户口径：全程自动战斗；点空地＝走过去（到点/6 秒撤销）；点怪＝集火**到死**；双击＝取消指令。
#   ——取目标只走 _order_target() 一个口子，宠物/飞匕/飞剑会自动跟着集火同一个目标。
# ============================================================
var _order_pos := Vector2.ZERO        # 走位目标点（战场局部坐标）
var _order_has_pos := false
var _order_foe: Dictionary = {}       # 集火目标（到死为止）
var _order_t := 0.0                   # 当前指令活了多久
var _order_fx: Array = []             # 点地的扩散圈：{x, y, t}
var _tap_t := 0.0                     # 上一次点击时间（双击判定）
var _tap_last := Vector2.ZERO
const ORDER_MOVE_SEC := 6.0           # 走位指令最多管 6 秒
const ORDER_STOP_DIST := 16.0         # 离目标点多近算"到了"
const TAP_FOE_R := 46.0               # 点到怪的判定半径（跟着体型放大）

# 点到哪只怪（没有就返回空字典）
func foe_at(p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := 1.0e9
	for f_v in foes:
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0:
			continue
		var sc := float(f.get("scale", 1.0))
		var r := TAP_FOE_R * maxf(0.85, sc)
		var d := p.distance_to(Vector2(float(f["x"]), float(f["y"]) - 16.0 * sc))
		if d <= r and d < bd:
			bd = d
			best = f
	return best

# 战场被点（p ＝ 战场局部坐标）：双击＝取消；点到怪＝集火；否则＝走过去
func tap_at(p: Vector2) -> void:
	if not running or intro_wait > 0.0:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	var dbl := (now - _tap_t) < 0.30 and p.distance_to(_tap_last) < 96.0
	_tap_t = now
	_tap_last = p
	if dbl:
		clear_order()
		return
	var f := foe_at(p)
	if not f.is_empty():
		order_focus(f)
	else:
		order_move(p)

func order_move(p: Vector2) -> void:
	_order_foe = {}
	_order_has_pos = true
	_order_t = 0.0
	# v15j（用户：临时指令倒是不限制）：**点哪走哪不卡那条 25% 的线** ——
	#   手动只留在战场框内（别跑到画面外），想上去就上去；
	#   HERO_TOP 只管"自动追击"（让怪大部分出现在屏幕里）。
	# v15o（用户：人物快跑到屏幕外了）：⚠ 原来下限写的是 8.0 —— 那是**脚**的坐标，
	#   而主角整个人是画在脚**上方**约 HERO_LINE(96) 高的地方，所以脚到 y=33 时
	#   头已经到了 y=−63，跑出战场框、压到上面的资源条上（截图里看到的就是这个）。
	#   改成下限 = HERO_LINE：脚最高到 96，头顶就在战场框内。
	_order_pos = Vector2(clampf(p.x, 70.0, size.x - 70.0),
		clampf(p.y, HERO_LINE, size.y - HERO_LINE * 0.5))
	_order_fx.append({"x": _order_pos.x, "y": _order_pos.y, "t": 0.0})
	Audio.sfx("ui_click", -12.0)

func order_focus(f: Dictionary) -> void:
	_order_foe = f
	_order_has_pos = false
	_order_t = 0.0
	_banner = "集火 · " + str(f.get("name", "怪"))
	_banner_t = 1.4
	Audio.sfx("ui_click", -8.0)

func clear_order() -> void:
	if not _order_has_pos and _order_foe.is_empty():
		return
	_order_foe = {}
	_order_has_pos = false
	_banner = "回到自动战斗"
	_banner_t = 1.2

# 取目标：**集火优先**（到死为止）；死了/没了自动回自动索敌
func _order_target() -> Dictionary:
	if not _order_foe.is_empty():
		if foes.has(_order_foe) and float(_order_foe.get("dying", 0.0)) <= 0.0:
			return _order_foe
		_order_foe = {}
	return _nearest()

# 点战场下指令（弹窗开着时点击被弹窗吃掉，这里收不到）
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			tap_at(mb.position)
			accept_event()
# ============================================================
# v13d P3：破阵（石像）＋ 占点（法阵）—— 规格：docs/困兽_事件与任务_设计稿.md
#   · 石像＝**不动的怪**（still=true）：不走不打，但能被主角/宠物/技能打；
#     活着的石像给半径 160 内的怪 **攻速 +30% · 少挨 20% 伤害**（碎一座弱一分）
#   · 法阵＝一个圈：站圈里累计秒数，出圈**按半速回退**；占点期间主角**只打圈里的怪**
# ============================================================
signal statue_down(left: int)
const STATUE_BUFF_R := 160.0
const STATUE_ASPD := 1.3
const STATUE_CUT := 0.8
const ZONE_DECAY := 0.5
var zone := {}

# 还活着几座石像（外壳的破阵任务读它）
func statues_left() -> int:
	var n := 0
	for f_v in foes:
		var f: Dictionary = f_v
		if bool(f.get("still", false)) and float(f.get("dying", 0.0)) <= 0.0:
			n += 1
	return n

# 摆 n 座石像（横着铺开，血跟着波次走）
func spawn_statues(n := 3) -> void:
	clear_statues()
	var hp := _foe_hp()
	for i in n:
		var x := 150.0 + float(i) * ((size.x - 300.0) / maxf(1.0, float(n - 1)))
		foes.append({"x": x, "y": size.y * 0.30, "hp": hp, "hp_max": hp, "atk": 0.0, "t": 0.0,
			"kind": "statue", "boss": false, "tier": 1, "name": "石像", "scale": 1.15,
			"still": true, "stop": 0.0, "flash": 0.0})
	_banner = "破阵：打碎 " + str(n) + " 座石像（它们在给怪加成）"
	_banner_t = 2.6
	Audio.sfx("chest", -6.0)

func clear_statues() -> void:
	for i in range(foes.size() - 1, -1, -1):
		if bool((foes[i] as Dictionary).get("still", false)):
			foes.remove_at(i)

# 开一个法阵（占点）：goal ＝ 要累计多少秒
func spawn_zone(r := 150.0, goal := 12.0) -> void:
	zone = {"x": size.x * 0.5, "y": size.y * 0.66, "r": r, "goal": goal, "prog": 0.0, "on": true}
	_banner = "占点：站进法阵（离开会回退）"
	_banner_t = 2.6
	Audio.sfx("bell", -6.0)

func clear_zone() -> void:
	zone = {}

func zone_prog() -> float:
	return float(zone.get("prog", 0.0))

# 主角是不是站在阵里
func _in_zone() -> bool:
	if zone.is_empty() or not bool(zone.get("on", false)):
		return false
	return hero_pos.distance_to(Vector2(float(zone["x"]), float(zone["y"]))) <= float(zone["r"])
# ============================================================
# v13e P4：守护（牢车）＋ 单挑（高手）
#   · 牢车＝**能被怪打的友方目标**：怪在「主角 / 蛟龙 / 牢车」里挑最近的打；
#     牢车**不回血**，砸碎 → 发 guard_broken，任务立刻失败
#   · 高手＝一只大怪（**不清场**，普通怪照刷），打死发 champion_down
# ============================================================
signal guard_broken()
signal champion_down()
const CHAMPION_NAMES := ["刀疤张", "独眼彪", "铁手判官", "鬼头刀"]
var guard := {}
var champion := 0

# 摆一辆牢车（守护任务）
func spawn_guard() -> void:
	var hp := maxf(200.0, _foe_atk() * 180.0)
	guard = {"x": size.x * 0.5, "y": size.y * 0.42, "hp": hp, "hp_max": hp, "flash": 0.0, "on": true}
	_banner = "守护：别让牢车被砸碎"
	_banner_t = 2.6
	Audio.sfx("chest", -6.0)

func clear_guard() -> void:
	guard = {}

func guard_hp_ratio() -> float:
	if guard.is_empty():
		return 0.0
	return clampf(float(guard["hp"]) / maxf(1.0, float(guard["hp_max"])), 0.0, 1.0)

func _break_guard() -> void:
	if guard.is_empty():
		return
	var gx := float(guard["x"])
	var gy := float(guard["y"])
	for gi in 14:
		_shards.append({"x": gx + randf_range(-20.0, 20.0), "y": gy - 10.0,
			"vx": randf_range(-220.0, 220.0), "vy": randf_range(-340.0, -120.0), "t": 0.0})
	_bursts.append({"x": gx, "y": gy, "t": 0.0, "col": Color(0.72, 0.52, 0.32), "scale": 1.8})
	_shake = maxf(_shake, 14.0)
	_hitstop = maxf(_hitstop, 0.10)
	Audio.sfx("fall_down", -2.0)
	_push_float(gx, gy - 54.0, "牢车被砸碎了！", Color(0.98, 0.72, 0.62), true)
	guard = {}
	guard_broken.emit()

# 高手进场（单挑任务）：一只大怪，**不清场**
func spawn_champion() -> void:
	clear_champion()
	var mul := pow(WAVE_HP, float(wave - 1))
	_spawn_foe("champion", 1.0, 1.0, false, 1, str(CHAMPION_NAMES[randi() % CHAMPION_NAMES.size()]))
	var f: Dictionary = foes[foes.size() - 1]
	f["hp"] = 420.0 * mul
	f["hp_max"] = 420.0 * mul
	f["atk"] = 12.0 * pow(WAVE_ATK, float(wave - 1))
	f["scale"] = 1.6
	f["stop"] = FOE_STOP + 20.0
	champion = 1
	_banner = "单挑：高手来了——" + str(f["name"])
	_banner_t = 2.8
	Audio.sfx("drum", -3.0)
	_shake = 12.0

func clear_champion() -> void:
	for i in range(foes.size() - 1, -1, -1):
		if str((foes[i] as Dictionary).get("kind", "")) == "champion":
			foes.remove_at(i)
	champion = 0
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
# v9h：挑战怪死亡 —— 外壳按类型发奖（文钱/灵晶/经验/宝物）
signal chal_drop(kind_i: int, at: Vector2)

# v14a 机制卡：连锁——击杀时炸一圈（用 _chain_lock 防递归）
var _chain_lock := false
var _root_t := 6.0            # 定身脉冲计时（首发 6 秒后）
var _shield_t := 8.0          # 护盾回复计时

func _chain_blast(at: Vector2) -> void:
	_chain_lock = true
	var dmg := float(hero["atk"]) * float(hero.get("mech_chain", 0.0))
	for f_v in foes.duplicate():
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0 or float(f["hp"]) <= 0.0:
			continue
		if at.distance_to(Vector2(float(f["x"]), float(f["y"]))) <= 110.0:
			var d := _apply_dmg(f, dmg, DMG_PHYS)
			_push_float(float(f["x"]), float(f["y"]) - 30.0, "连锁 " + str(int(d)), Color(1.0, 0.64, 0.30), true)
			if float(f["hp"]) <= 0.0:
				_kill_foe(f)
	_bursts.append({"x": at.x, "y": at.y, "t": 0.0, "col": Color(1.0, 0.66, 0.32), "scale": 1.6})
	_chain_lock = false

func _kill_foe(f: Dictionary) -> void:
	# v14r：boss 词缀"不死"——濒死时**回满一半血**顶一次（整个 boss 只顶一次）
	if int(f.get("boss_revive", 0)) > 0 and float(f.get("dying", 0.0)) <= 0.0:
		f["boss_revive"] = 0     # ⚠ 手工塞进来的怪没有这个键，读法必须是 get（探针抓到过）
		f["hp"] = float(f["hp_max"]) * 0.5
		# ⚠ 死亡标记必须清干净：上面刚把它打成 0 血，可能已经挂了 dying——不清就"复活了但还是死的"（探针抓到过）
		f["dying"] = 0.0
		f["kb"] = 0.0
		f["flash"] = 0.30
		_banner = "不死！" + str(f.get("bname", "boss")) + "　又站起来了"
		_banner_t = 2.0
		_shake = maxf(_shake, 18.0)
		_hitstop = maxf(_hitstop, 0.14)
		_bursts.append({"x": float(f["x"]), "y": float(f["y"]), "t": 0.0, "col": Color(0.86, 0.30, 0.34), "scale": 2.4})
		for ri in 14:
			_shards.append({"x": float(f["x"]), "y": float(f["y"]) - 24.0,
				"vx": randf_range(-230.0, 230.0), "vy": randf_range(-340.0, -90.0), "t": 0.0})
		_push_float(float(f["x"]), float(f["y"]) - 76.0, "不死之身！", Color(1.0, 0.62, 0.58), true)
		Audio.sfx("drum", -3.0)
		return
	# v13f：元素/伙伴技打死的（百步任务）——普通刀砍是物理，不算
	if str(f.get("last_dtype", "")) in ELEMS:
		skill_kills += 1
	# v13e P4：高手被打死——通知外壳（单挑任务），杀敌照样算
	if str(f.get("kind", "")) == "champion":
		champion = 0
		f["dying"] = 0.42
		f["kb"] = 140.0
		f["hp"] = 0.0
		kills_total += 1
		_combo += 1
		_combo_t = 1.4
		_shake = maxf(_shake, 16.0)
		_hitstop = maxf(_hitstop, 0.10)
		for ci in 12:
			_shards.append({"x": float(f["x"]), "y": float(f["y"]) - 20.0,
				"vx": randf_range(-200.0, 200.0), "vy": randf_range(-320.0, -100.0), "t": 0.0})
		_bursts.append({"x": float(f["x"]), "y": float(f["y"]), "t": 0.0, "col": Color(0.92, 0.72, 0.36), "scale": 1.6})
		Audio.sfx("hit_heavy", -4.0, 1.2)
		Audio.sfx("drum", -6.0, 0.9)
		_push_float(float(f["x"]), float(f["y"]) - 64.0, "高手倒地！", Color(1.0, 0.88, 0.46), true)
		kill.emit(1)
		champion_down.emit()
		return
	# v13f：精英被猎杀——通知外壳
	if str(f.get("kind", "")) == "elite":
		f["dying"] = 0.36
		f["kb"] = 120.0
		f["hp"] = 0.0
		_shake = maxf(_shake, 12.0)
		_hitstop = maxf(_hitstop, 0.08)
		for ei in 10:
			_shards.append({"x": float(f["x"]), "y": float(f["y"]) - 20.0,
				"vx": randf_range(-200.0, 200.0), "vy": randf_range(-320.0, -100.0), "t": 0.0})
		Audio.sfx("hit_heavy", -5.0, 1.1)
		_push_float(float(f["x"]), float(f["y"]) - 56.0, "走狗伏诛", Color(1.0, 0.88, 0.46), true)
		kill.emit(1)
		elite_down.emit()
		return
	# v13d P3：石像碎了——不算杀敌、不掉钱，只通知外壳（破阵任务进度）
	if bool(f.get("still", false)):
		f["dying"] = 0.34
		f["kb"] = 40.0
		var n_left := statues_left() - 1
		for si in 10:
			_shards.append({"x": float(f["x"]), "y": float(f["y"]) - 18.0,
				"vx": randf_range(-190.0, 190.0), "vy": randf_range(-320.0, -110.0), "t": 0.0})
		_bursts.append({"x": float(f["x"]), "y": float(f["y"]), "t": 0.0, "col": Color(0.80, 0.78, 0.74), "scale": 1.4})
		_shake = maxf(_shake, 9.0)
		_hitstop = maxf(_hitstop, 0.06)
		Audio.sfx("hit_heavy", -6.0, 0.8)
		_push_float(float(f["x"]), float(f["y"]) - 44.0,
			"石像碎" + ("　还剩 " + str(n_left) + " 座" if n_left > 0 else "　全碎了！"), Color(0.96, 0.90, 0.66), true)
		statue_down.emit(maxi(0, n_left))
		return
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
	if _shards.size() < FX_SHARDS_MAX:      # v13g：碎屑按预算给，别一次塞几千片
		for i in 7:
			_shards.append({"x": float(f["x"]), "y": float(f["y"]) - 20.0,
				"vx": randf_range(-160.0, 160.0), "vy": randf_range(-280.0, -90.0), "t": 0.0})
	if str(f.get("kind", "")) == "normal":
		kill_normal += 1               # v13w：成就「嗜杀如命」数普通怪
	# v14a 机制卡：战意（每杀一个永久加点攻击）＋ 连锁（击杀溅射）
	if float(hero.get("mech_killatk", 0.0)) > 0.0:
		hero["_kill_atk"] = float(hero.get("_kill_atk", 0.0)) + float(hero["mech_killatk"])
	if float(hero.get("mech_chain", 0.0)) > 0.0 and not _chain_lock and not bool(f.get("still", false)):
		_chain_blast(Vector2(float(f["x"]), float(f["y"])))
	# v14b 钱多多「点金」：持续期内每杀一个额外掉 3 文钱
	if p_active("qianduoduo") and not bool(f.get("still", false)):
		coin_drop.emit(3 + int(partners["qianduoduo"].get("gold_lv", 0)), Vector2(float(f["x"]), float(f["y"])))
	var kind := str(f["kind"])
	var coins := 1 + randi() % 3
	# v9h（挑战掉落表）：挑战怪身上带 chal —— 按类型掉，结算交给外壳
	#   0 文钱 · 1 灵晶 · 2 经验 · 3 宝物 · 4 boss
	if f.has("chal"):
		var ci := int(f["chal"])
		if bool(f.get("boss", false)):
			# v15o：挑战的钱随波次涨
			coins = int(float([0, 0, 0, 220, 320][clampi(ci, 0, 4)]) * chal_money_mul())
		else:
			coins = int(float([24 + randi() % 17, 0, 0, 0, 0][clampi(ci, 0, 4)]) * chal_money_mul())
		chal_drop.emit(ci, Vector2(float(f["x"]), float(f["y"])))
	if kind == "coin":
		coins = 30 + randi() % 31
	elif kind == "boss" and not f.has("chal"):
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


# ============================================================
# v9i 触发型卡（用户："额外特效的也可加"）：
#   飞羽（每 3 秒射一支箭，成型后穿透）· 雷霆（暴击落雷＋麻痹）· 流星（每 4 秒落星，成型后范围）
#   开启与否由外壳塞进 hero：cg_feiyu / cg_leiting / cg_liuxing（0/1），冷却自己数。
# ============================================================
var _cg_feiyu_t := 0.0
var _cg_liuxing_t := 0.0
var _cg_leiting_t := 0.0

func _nearest_foe() -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e9
	for f_v in foes:
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0:
			continue
		var d := Vector2(float(f["x"]), float(f["y"])).distance_to(hero_pos)
		if d < bd:
			bd = d
			best = f
	return best

func _update_card_fx(delta: float) -> void:
	# 飞羽：每 3 秒一支箭（成型＝穿透，打两只）
	if float(hero.get("cg_feiyu", 0.0)) > 0.0:
		_cg_feiyu_t += delta
		if _cg_feiyu_t >= 3.0:
			_cg_feiyu_t = 0.0
			var tg := _nearest_foe()
			if not tg.is_empty():
				var hits := 2 if float(hero.get("cg_feiyu_pierce", 0.0)) > 0.0 else 1
				var done := 0
				for f_v in foes.duplicate():
					var f2: Dictionary = f_v
					if float(f2.get("dying", 0.0)) > 0.0:
						continue
					if done >= hits:
						break
					_apply_dmg(f2, float(hero["atk"]) * 0.6, DMG_PHYS)
					_push_float(float(f2["x"]), float(f2["y"]) - 20.0, "飞羽", Color(0.92, 0.86, 0.60))
					_bursts.append({"x": float(f2["x"]), "y": float(f2["y"]), "t": 0.0,
						"col": Color(0.94, 0.90, 0.66), "scale": 0.8})
					done += 1
				Audio.sfx("dart", -10.0)
	# 流星：每 4 秒落一颗（成型＝范围伤害）
	if float(hero.get("cg_liuxing", 0.0)) > 0.0:
		_cg_liuxing_t += delta
		if _cg_liuxing_t >= 4.0:
			_cg_liuxing_t = 0.0
			var tg2 := _nearest_foe()
			if not tg2.is_empty():
				var cx := float(tg2["x"])
				var cy := float(tg2["y"])
				var aoe := float(hero.get("cg_liuxing_aoe", 0.0)) > 0.0
				for f_v in foes.duplicate():
					var f3: Dictionary = f_v
					if float(f3.get("dying", 0.0)) > 0.0:
						continue
					if not aoe and f3 != tg2:
						continue
					if aoe and Vector2(float(f3["x"]), float(f3["y"])).distance_to(Vector2(cx, cy)) > 110.0:
						continue
					_apply_dmg(f3, float(hero["atk"]) * 0.7, DMG_PHYS)
					_push_float(float(f3["x"]), float(f3["y"]) - 26.0, "落星", Color(0.86, 0.78, 1.0))
				_bursts.append({"x": cx, "y": cy, "t": 0.0, "col": Color(0.80, 0.74, 1.0), "scale": 2.2})
				_shake = maxf(_shake, 5.0)
				Audio.sfx("hit_heavy", -8.0)
	# 雷霆：暴击后落雷（成型＝必定麻痹）。_last_crit 由 _apply_dmg 标记。
	if float(hero.get("cg_leiting", 0.0)) > 0.0:
		_cg_leiting_t = maxf(0.0, _cg_leiting_t - delta)
		if _last_crit and _cg_leiting_t <= 0.0 and not foes.is_empty():
			_last_crit = false
			_cg_leiting_t = 0.6                     # 落雷最短间隔，免得刷屏
			var tg3 := _nearest_foe()
			if not tg3.is_empty():
				_apply_dmg(tg3, float(hero["atk"]) * 0.5, DMG_METAL)
				if float(hero.get("cg_leiting_para", 0.0)) > 0.0:
					tg3["para"] = 1.0                # 麻痹 1 秒（怪的出手计时会被清）
				_push_float(float(tg3["x"]), float(tg3["y"]) - 30.0, "雷", Color(0.70, 0.86, 1.0), true)
				_bursts.append({"x": float(tg3["x"]), "y": float(tg3["y"]), "t": 0.0,
					"col": Color(0.72, 0.88, 1.0), "scale": 1.6})
				Audio.sfx("slash_light", -8.0)
# v13g：特效预算——浴血一次清几百只时，别把几千个碎屑/飘字塞进一帧
#   （实测：300 只一起死 → 2100 片碎屑 + 298 条飘字，单帧 100ms，之后 0.45 秒一直在画）
const FX_SHARDS_MAX := 180
const FX_BURSTS_MAX := 90
const FX_FLOATS_MAX := 70

func _fx_trim() -> void:
	if _shards.size() > FX_SHARDS_MAX:
		_shards = _shards.slice(_shards.size() - FX_SHARDS_MAX)
	if _bursts.size() > FX_BURSTS_MAX:
		_bursts = _bursts.slice(_bursts.size() - FX_BURSTS_MAX)
	if _floats.size() > FX_FLOATS_MAX:
		_floats = _floats.slice(_floats.size() - FX_FLOATS_MAX)

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
		"desc": "持续期间杀敌生命上限 +0.5（现 +<KH>）【内力消耗 +20/层】", "anim": "每杀一只飘绿字"},
	{"id": "anying_cost", "name": "肝·减内力", "kind": "num", "max": 3, "req_p": "anying",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "紫光不变，只是更省"},
	{"id": "chenshi_cd", "name": "刺骨·减冷却", "kind": "num", "max": 3, "req_p": "chenshi",
		"desc": "冷却 −3 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "粉光冒得更勤"},
	{"id": "chenshi_dur", "name": "刺骨·加持续", "kind": "num", "max": 3, "req_p": "chenshi",
		"desc": "持续 +2 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "反伤窗口更长"},
	{"id": "chenshi_dmg", "name": "刺骨·加反伤", "kind": "num", "max": 3, "req_p": "chenshi",
		"desc": "反伤 +0.5% 生命上限（现 <TH>%，中品基础 2.5%）【内力消耗 +20/层】", "anim": "反伤数字更大"},
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
	# ---- v4j 张道陵·天雷道术（绝品）：范围金系伤害 ＋ 麻痹 ＋ 多重施法 ----
	{"id": "zhangdaoling_dmg", "name": "天雷·伤害", "kind": "num", "max": 3, "req_p": "zhangdaoling",
		"desc": "天雷伤害 +25%（现 ×<TD>）【内力 +30/层】", "anim": "雷柱更粗更白"},
	{"id": "zhangdaoling_range", "name": "天雷·范围", "kind": "num", "max": 3, "req_p": "zhangdaoling",
		"desc": "范围 +22 像素（现 <TR> 像素，约两个人身位）【内力 +30/层】", "anim": "地上那圈雷光更大"},
	{"id": "zhangdaoling_para", "name": "天雷·麻痹几率", "kind": "mech", "max": 3, "req_p": "zhangdaoling",
		"desc": "麻痹几率 +10%（现 <TP>，麻痹 1 秒起步）【内力 +30/层】", "anim": "被劈中的怪头顶跳电花"},
	{"id": "zhangdaoling_paradur", "name": "天雷·麻痹时长", "kind": "num", "max": 3, "req_p": "zhangdaoling",
		"desc": "麻痹持续 +1 秒（现 <TPD> 秒）【内力 +30/层】", "anim": "电花挂得更久"},
	{"id": "zhangdaoling_multi", "name": "天雷·多重施法", "kind": "mech", "max": 3, "req_p": "zhangdaoling",
		"desc": "额外释放一次的几率 +15%（现 <TM>；那一下**伤害比例不同**，也是金系）【内力 +30/层】",
		"anim": "第二道雷稍细稍快，落点另算"},
	{"id": "zhangdaoling_multidmg", "name": "天雷·多重伤害", "kind": "num", "max": 3, "req_p": "zhangdaoling",
		"desc": "多重施法那一下伤害 +25%（现 ×<TMD>）", "anim": "第二道雷也变粗"},
	{"id": "zhangdaoling_cost", "name": "天雷·减内力", "kind": "num", "max": 3, "req_p": "zhangdaoling",
		"desc": "内力消耗 −25（现 <TMP>）", "anim": "雷不变，只是更省"},
	{"id": "zhangdaoling_cd", "name": "天雷·减冷却", "kind": "num", "max": 3, "req_p": "zhangdaoling",
		"desc": "冷却 −1.5 秒（现 <TCD> 秒）", "anim": "雷落得更勤"},
	# ---- v4k 柳卿卿·回春（上品）：治疗自己 ＋ 最近一名敌人中毒（木系 DoT）----
	{"id": "liuqingqing_heal", "name": "回春·治疗量", "kind": "num", "max": 3, "req_p": "liuqingqing",
		"desc": "回血 +6% 生命上限（现 <LH>%）【内力 +20/层】", "anim": "绿光更浓"},
	{"id": "liuqingqing_poison", "name": "回春·毒伤", "kind": "num", "max": 3, "req_p": "liuqingqing",
		"desc": "毒伤 +25%（现每秒 ×<LP>，木系）【内力 +20/层】", "anim": "毒泡更大更绿"},
	{"id": "liuqingqing_pdur", "name": "回春·毒持续", "kind": "num", "max": 3, "req_p": "liuqingqing",
		"desc": "毒持续 +2 秒（现 <LPD> 秒）【内力 +20/层】", "anim": "毒点挂得更久"},
	{"id": "liuqingqing_spread", "name": "回春·毒扩散", "kind": "mech", "max": 3, "req_p": "liuqingqing",
		"desc": "毒多传给 1 名附近的敌人（现 <LS> 名，一条绿线连过去）【内力 +20/层】",
		"anim": "绿线一跳一跳地连出去"},
	{"id": "liuqingqing_cd", "name": "回春·减冷却", "kind": "num", "max": 3, "req_p": "liuqingqing",
		"desc": "冷却 −1.5 秒（现 <LCD> 秒）", "anim": "回得更勤"},
	{"id": "liuqingqing_cost", "name": "回春·减内力", "kind": "num", "max": 3, "req_p": "liuqingqing",
		"desc": "内力消耗 −15（现 <LMP>）", "anim": "绿光不变，只是更省"},
	# ---- v4k 季沧海·怒火焚身（极品）：每 3 秒烧最近一名（火系）；传火会引燃身边的 ----
	{"id": "jicanghai_dmg", "name": "怒火·伤害", "kind": "num", "max": 3, "req_p": "jicanghai",
		"desc": "火伤 +25%（现 ×<JD>）", "anim": "火焰更旺"},
	{"id": "jicanghai_spread", "name": "怒火·传火", "kind": "mech", "max": 3, "req_p": "jicanghai",
		"desc": "传火多引燃 1 名（现 <JS> 名；引燃线是一道火线）", "anim": "火线一道接一道"},
	{"id": "jicanghai_burn", "name": "怒火·灼烧", "kind": "num", "max": 3, "req_p": "jicanghai",
		"desc": "命中后留下灼烧（每秒额外 ×<JB>，火系，4 秒）", "anim": "橙点挂在头顶"},
	{"id": "jicanghai_sec", "name": "怒火·减秒数", "kind": "num", "max": 3, "req_p": "jicanghai",
		"desc": "出火间隔 −0.4 秒（现 <JCD> 秒）", "anim": "火冒得更勤"},
	# ---- v4l 崔三娘·雾海龙王（绝品）：召唤蛟龙（可多招）＋ 蛟龙自带「大浪拍击」 ----
	{"id": "cuisanniang_inherit", "name": "龙王·继承属性", "kind": "num", "max": 3, "req_p": "cuisanniang",
		"desc": "蛟龙继承主角属性 +5%（现 <CI>%）【内力 +60/层】", "anim": "蛟龙更粗更长"},
	{"id": "cuisanniang_skill", "name": "龙王·技能伤害", "kind": "num", "max": 3, "req_p": "cuisanniang",
		"desc": "大浪拍击 +25%（现 ×<CS>）【内力 +60/层】", "anim": "浪头更高"},
	{"id": "cuisanniang_radius", "name": "龙王·技能范围", "kind": "num", "max": 3, "req_p": "cuisanniang",
		"desc": "大浪从「只打一名」变成一片（现半径 <CR> 像素）【内力 +60/层】", "anim": "水浪扩成一圈"},
	{"id": "cuisanniang_cost", "name": "龙王·降内力", "kind": "num", "max": 3, "req_p": "cuisanniang",
		"desc": "内力消耗 −40（现 <CM>）", "anim": "召唤光不变，只是更省"},
	# ---- v4n 独眼彪·杀气（下品）/ 枯荣·纳气（下品）：跟"肝"一个骨架，更弱，但特效各不同 ----
	{"id": "duyanbiao_cd", "name": "杀气·减冷却", "kind": "num", "max": 3, "req_p": "duyanbiao",
		"desc": "冷却 −3 秒（现 <SBC> 秒）【内力 +20/层】", "anim": "赤气冒得更勤"},
	{"id": "duyanbiao_dur", "name": "杀气·加持续", "kind": "num", "max": 3, "req_p": "duyanbiao",
		"desc": "持续 +2 秒（现 <SBD> 秒）【内力 +20/层】", "anim": "赤刃留得更久"},
	{"id": "duyanbiao_atk", "name": "杀气·杀敌攻击", "kind": "num", "max": 3, "req_p": "duyanbiao",
		"desc": "杀敌攻击 +0.5（现 +<SBA>/只）【内力 +20/层】", "anim": "每杀一只爆一圈红环"},
	{"id": "duyanbiao_cost", "name": "杀气·减内力", "kind": "num", "max": 3, "req_p": "duyanbiao",
		"desc": "内力消耗 −15（现 <SBM>）", "anim": "赤气不变，只是更省"},
	{"id": "kurong_cd", "name": "纳气·减冷却", "kind": "num", "max": 3, "req_p": "kurong",
		"desc": "冷却 −3 秒（现 <KRC> 秒）【内力 +20/层】", "anim": "气丝收得更勤"},
	{"id": "kurong_dur", "name": "纳气·加持续", "kind": "num", "max": 3, "req_p": "kurong",
		"desc": "持续 +2 秒（现 <KRD> 秒）【内力 +20/层】", "anim": "暖环留得更久"},
	{"id": "kurong_mp", "name": "纳气·杀敌内力", "kind": "num", "max": 3, "req_p": "kurong",
		"desc": "杀敌内力上限 +3%（现 +<KRP> 原本内力/只）【内力 +20/层】", "anim": "气丝收得更密"},
	{"id": "kurong_cost", "name": "纳气·减内力", "kind": "num", "max": 3, "req_p": "kurong",
		"desc": "内力消耗 −15（现 <KRM>）", "anim": "暖环不变，只是更省"},
	# ---- v4o 法度·怒目金刚（中品）：护盾 / 破盾土系范围伤害 / 每降 10% 出一段 / **范围** ----
	{"id": "fadu_shield", "name": "怒目·护盾值", "kind": "num", "max": 3, "req_p": "fadu",
		"desc": "护盾 = 生命上限的 +15%（现 <FDS>%）【内力 +20/层】", "anim": "石甲更厚更多"},
	{"id": "fadu_break", "name": "怒目·破盾伤害", "kind": "num", "max": 3, "req_p": "fadu",
		"desc": "破盾那一下 +25%（现 ×<FDB> 护盾值，土系范围）【内力 +20/层】", "anim": "破盾的地裂更大"},
	{"id": "fadu_step", "name": "怒目·层段", "kind": "mech", "max": 3, "req_p": "fadu",
		"desc": "护盾每掉 10% 就震荡一次，造成护盾值的 10%×层（现 <FDP>%）土系范围伤害【内力 +20/层】",
		"anim": "盾一层层碎、地面一圈圈裂"},
	{"id": "fadu_range", "name": "怒目·范围", "kind": "num", "max": 3, "req_p": "fadu",
		"desc": "震荡半径 +25 像素（现 <FDR> 像素）【内力 +20/层】", "anim": "土浪扩得更远"},
	{"id": "fadu_dur", "name": "怒目·持续", "kind": "num", "max": 3, "req_p": "fadu",
		"desc": "护盾持续 +2 秒（现 <FDD> 秒）【内力 +20/层】", "anim": "石甲挂得更久"},
	{"id": "fadu_cd", "name": "怒目·减冷却", "kind": "num", "max": 3, "req_p": "fadu",
		"desc": "冷却 −3 秒（现 <FDC> 秒）", "anim": "盾补得更勤"},
	{"id": "fadu_cost", "name": "怒目·减内力", "kind": "num", "max": 3, "req_p": "fadu",
		"desc": "内力消耗 −15（现 <FDM>）", "anim": "石甲不变，只是更省"},
	{"id": "cuisanniang_life", "name": "龙王·存在时间", "kind": "num", "max": 3, "req_p": "cuisanniang",
		"desc": "蛟龙多活 6 秒（现 <CL> 秒）【内力 +60/层】", "anim": "蛟龙身上的水光留得更久"},
	{"id": "cuisanniang_cd", "name": "龙王·降冷却", "kind": "num", "max": 3, "req_p": "cuisanniang",
		"desc": "冷却 −8 秒（现 <CC> 秒）", "anim": "蛟龙出得更勤"},
	# ---- v15d：新增 12 位的强化档位（各 3 层，出现在升级三选一里）----
	{"id": "tietouseng_cd", "name": "铁头·减冷却", "kind": "num", "max": 3, "req_p": "tietouseng",
		"desc": "冷却 −1.5 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "撞得更勤"},
	{"id": "tietouseng_dmg", "name": "铁头·加伤", "kind": "num", "max": 3, "req_p": "tietouseng",
		"desc": "撞击伤害 +25%/层【内力消耗 +20/层】", "anim": "撞出火星"},
	{"id": "tietouseng_cost", "name": "铁头·减内力", "kind": "num", "max": 3, "req_p": "tietouseng",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "更省力"},
	{"id": "bingshusheng_cd", "name": "咳血·减冷却", "kind": "num", "max": 3, "req_p": "bingshusheng",
		"desc": "冷却 −2 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "咳得更频"},
	{"id": "bingshusheng_dmg", "name": "咳血·加毒", "kind": "num", "max": 3, "req_p": "bingshusheng",
		"desc": "毒伤 +25%/层【内力消耗 +20/层】", "anim": "血更绿"},
	{"id": "bingshusheng_dur", "name": "咳血·加持续", "kind": "num", "max": 3, "req_p": "bingshusheng",
		"desc": "毒持续 +1 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "毒留得久"},
	{"id": "xiaoqier_dur", "name": "牵羊·加持续", "kind": "num", "max": 3, "req_p": "xiaoqier",
		"desc": "持续 +2 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "摸得久"},
	{"id": "xiaoqier_gold", "name": "牵羊·多掉钱", "kind": "num", "max": 3, "req_p": "xiaoqier",
		"desc": "每杀一只多掉 2 文钱【内力消耗 +20/层】", "anim": "钱叮当响"},
	{"id": "xiaoqier_cost", "name": "牵羊·减内力", "kind": "num", "max": 3, "req_p": "xiaoqier",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "手更轻"},
	{"id": "zuijianxian_cd", "name": "醉剑·减冷却", "kind": "num", "max": 3, "req_p": "zuijianxian",
		"desc": "冷却 −1 秒（现 <CD> 秒）", "anim": "醉步更快"},
	{"id": "zuijianxian_dmg", "name": "醉剑·加伤", "kind": "num", "max": 3, "req_p": "zuijianxian",
		"desc": "两下伤害 +25%/层", "anim": "剑花更乱"},
	{"id": "zuijianxian_cost", "name": "醉剑·减内力", "kind": "num", "max": 3, "req_p": "zuijianxian",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "酒还是那壶"},
	{"id": "yaopozi_cd", "name": "金针·减冷却", "kind": "num", "max": 3, "req_p": "yaopozi",
		"desc": "冷却 −1.5 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "针出得更快"},
	{"id": "yaopozi_heal", "name": "金针·加治疗", "kind": "num", "max": 3, "req_p": "yaopozi",
		"desc": "治疗 +3% 生命上限/层【内力消耗 +20/层】", "anim": "针上带光"},
	{"id": "yaopozi_cost", "name": "金针·减内力", "kind": "num", "max": 3, "req_p": "yaopozi",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "省着扎"},
	{"id": "gushangzao_dur", "name": "踏鼓·加持续", "kind": "num", "max": 3, "req_p": "gushangzao",
		"desc": "持续 +1.5 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "鼓点更长"},
	{"id": "gushangzao_aspd", "name": "踏鼓·加攻速", "kind": "num", "max": 3, "req_p": "gushangzao",
		"desc": "攻速 +10%/层【内力消耗 +20/层】", "anim": "鼓点更急"},
	{"id": "gushangzao_cost", "name": "踏鼓·减内力", "kind": "num", "max": 3, "req_p": "gushangzao",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "轻敲"},
	{"id": "jinjiaxianwei_cut", "name": "拒马·加盾", "kind": "num", "max": 3, "req_p": "jinjiaxianwei",
		"desc": "护盾 +4% 生命上限/层【内力消耗 +20/层】", "anim": "甲片更厚"},
	{"id": "jinjiaxianwei_dur", "name": "拒马·加持续", "kind": "num", "max": 3, "req_p": "jinjiaxianwei",
		"desc": "持续 +2 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "架势更稳"},
	{"id": "jinjiaxianwei_cost", "name": "拒马·减内力", "kind": "num", "max": 3, "req_p": "jinjiaxianwei",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "扛得更省"},
	{"id": "huogong_cd", "name": "真火·减冷却", "kind": "num", "max": 3, "req_p": "huogong",
		"desc": "冷却 −1.5 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "火起得更勤"},
	{"id": "huogong_dmg", "name": "真火·加伤", "kind": "num", "max": 3, "req_p": "huogong",
		"desc": "火伤 +25%/层【内力消耗 +20/层】", "anim": "火苗更旺"},
	{"id": "huogong_tgt", "name": "真火·多烧一个", "kind": "num", "max": 3, "req_p": "huogong",
		"desc": "多点燃 1 名敌人/层【内力消耗 +20/层】", "anim": "火线铺开"},
	{"id": "qinchi_dur", "name": "乱神·加持续", "kind": "num", "max": 3, "req_p": "qinchi",
		"desc": "定身 +0.4 秒/层（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "曲子更长"},
	{"id": "qinchi_cd", "name": "乱神·减冷却", "kind": "num", "max": 3, "req_p": "qinchi",
		"desc": "冷却 −2 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "弹得更频"},
	{"id": "qinchi_cost", "name": "乱神·减内力", "kind": "num", "max": 3, "req_p": "qinchi",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "弦更松"},
	{"id": "baiqihouren_dmg", "name": "杀神·加比例", "kind": "num", "max": 3, "req_p": "baiqihouren",
		"desc": "已损失气血那一项 +5%/层【内力消耗 +20/层】", "anim": "刀气更冷"},
	{"id": "baiqihouren_cd", "name": "杀神·减冷却", "kind": "num", "max": 3, "req_p": "baiqihouren",
		"desc": "冷却 −1.5 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "杀意更频"},
	{"id": "baiqihouren_cost", "name": "杀神·减内力", "kind": "num", "max": 3, "req_p": "baiqihouren",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "省着杀"},
	{"id": "dagongfeng_shield", "name": "罡气·加护盾", "kind": "num", "max": 3, "req_p": "dagongfeng",
		"desc": "护盾 +5% 生命上限/层【内力消耗 +20/层】", "anim": "罡气更厚"},
	{"id": "dagongfeng_dur", "name": "罡气·加持续", "kind": "num", "max": 3, "req_p": "dagongfeng",
		"desc": "持续 +2 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "罩得更久"},
	{"id": "dagongfeng_cost", "name": "罡气·减内力", "kind": "num", "max": 3, "req_p": "dagongfeng",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "引气更省"},
	# v15g：补上 11 位伙伴的强化档位（之前一个都没有，升级三选一里刷不到他们）
	{"id": "shigandang_cd", "name": "坚守·减冷却", "kind": "num", "max": 3, "req_p": "shigandang",
		"desc": "冷却 −3 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "扛得更勤"},
	{"id": "shigandang_cut", "name": "坚守·加减伤", "kind": "num", "max": 3, "req_p": "shigandang",
		"desc": "减伤 +5%/层【内力消耗 +20/层】", "anim": "硬抗更稳"},
	{"id": "shigandang_cost", "name": "坚守·减内力", "kind": "num", "max": 3, "req_p": "shigandang",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "更省气"},
	{"id": "qianduoduo_cd", "name": "点金·减冷却", "kind": "num", "max": 3, "req_p": "qianduoduo",
		"desc": "冷却 −3 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "点得更勤"},
	{"id": "qianduoduo_gold", "name": "点金·多掉钱", "kind": "num", "max": 3, "req_p": "qianduoduo",
		"desc": "每杀一只多掉 2 文钱【内力消耗 +20/层】", "anim": "钱更响"},
	{"id": "qianduoduo_cost", "name": "点金·减内力", "kind": "num", "max": 3, "req_p": "qianduoduo",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "手更轻"},
	{"id": "leixiaoqi_dmg", "name": "连环腿·加伤", "kind": "num", "max": 3, "req_p": "leixiaoqi",
		"desc": "两脚伤害 +10%/层", "anim": "踢得更狠"},
	{"id": "leixiaoqi_sec", "name": "连环腿·减秒数", "kind": "num", "max": 3, "req_p": "leixiaoqi",
		"desc": "出腿间隔 −0.3 秒/层（下限 2 秒）", "anim": "腿更快"},
	{"id": "leixiaoqi_cost", "name": "连环腿·减内力", "kind": "num", "max": 3, "req_p": "leixiaoqi",
		"desc": "内力消耗 −15", "anim": "省力气"},
	{"id": "baipopo_cd", "name": "续命·减冷却", "kind": "num", "max": 3, "req_p": "baipopo",
		"desc": "冷却 −2 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "回得更勤"},
	{"id": "baipopo_heal", "name": "续命·加治疗", "kind": "num", "max": 3, "req_p": "baipopo",
		"desc": "回血 +2% 生命上限/层【内力消耗 +20/层】", "anim": "回得更多"},
	{"id": "baipopo_cost", "name": "续命·减内力", "kind": "num", "max": 3, "req_p": "baipopo",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "省着用"},
	{"id": "tiexinwu_dur", "name": "铁壁·加持续", "kind": "num", "max": 3, "req_p": "tiexinwu",
		"desc": "持续 +2 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "窗口更长"},
	{"id": "tiexinwu_cd", "name": "铁壁·减冷却", "kind": "num", "max": 3, "req_p": "tiexinwu",
		"desc": "冷却 −3 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "格挡更勤"},
	{"id": "tiexinwu_cost", "name": "铁壁·减内力", "kind": "num", "max": 3, "req_p": "tiexinwu",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "更省"},
	{"id": "shenqingluo_tgt", "name": "藤缚·多缠一个", "kind": "num", "max": 3, "req_p": "shenqingluo",
		"desc": "多缠 1 名敌人/层【内力消耗 +20/层】", "anim": "藤蔓铺开"},
	{"id": "shenqingluo_dmg", "name": "藤缚·加伤", "kind": "num", "max": 3, "req_p": "shenqingluo",
		"desc": "木系伤害 +15%/层【内力消耗 +20/层】", "anim": "缠得更痛"},
	{"id": "shenqingluo_cost", "name": "藤缚·减内力", "kind": "num", "max": 3, "req_p": "shenqingluo",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "更省"},
	{"id": "yanwugui_dur", "name": "鹰眼·加持续", "kind": "num", "max": 3, "req_p": "yanwugui",
		"desc": "持续 +2 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "眼力更久"},
	{"id": "yanwugui_crit", "name": "鹰眼·加暴击", "kind": "num", "max": 3, "req_p": "yanwugui",
		"desc": "暴击 +5%/层【内力消耗 +20/层】", "anim": "看得更准"},
	{"id": "yanwugui_cost", "name": "鹰眼·减内力", "kind": "num", "max": 3, "req_p": "yanwugui",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "更省"},
	{"id": "ximenlie_dmg", "name": "烈焰刀·加伤", "kind": "num", "max": 3, "req_p": "ximenlie",
		"desc": "火刃伤害 +18%/层", "anim": "刀更烫"},
	{"id": "ximenlie_sec", "name": "烈焰刀·减秒数", "kind": "num", "max": 3, "req_p": "ximenlie",
		"desc": "出刀间隔 −0.4 秒/层（下限 2.5 秒）", "anim": "劈得更频"},
	{"id": "ximenlie_cost", "name": "烈焰刀·减内力", "kind": "num", "max": 3, "req_p": "ximenlie",
		"desc": "内力消耗 −15", "anim": "省柴火"},
	{"id": "duniangzi_dmg", "name": "万毒·加毒", "kind": "num", "max": 3, "req_p": "duniangzi",
		"desc": "毒伤 +6%/层【内力消耗 +20/层】", "anim": "毒更烈"},
	{"id": "duniangzi_dot", "name": "万毒·加持续", "kind": "num", "max": 3, "req_p": "duniangzi",
		"desc": "毒持续 +1 秒/层（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "毒留得久"},
	{"id": "duniangzi_cost", "name": "万毒·减内力", "kind": "num", "max": 3, "req_p": "duniangzi",
		"desc": "内力消耗 −15（现 <MP>，效果不变）", "anim": "省着放"},
	{"id": "xuanjizi_dur", "name": "时停·加持续", "kind": "num", "max": 3, "req_p": "xuanjizi",
		"desc": "定身 +0.4 秒/层（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "停得更久"},
	{"id": "xuanjizi_cd", "name": "时停·减冷却", "kind": "num", "max": 3, "req_p": "xuanjizi",
		"desc": "冷却 −3 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "来得更勤"},
	{"id": "xuanjizi_cost", "name": "时停·减内力", "kind": "num", "max": 3, "req_p": "xuanjizi",
		"desc": "内力消耗 −25（现 <MP>，效果不变）", "anim": "更省"},
	{"id": "laobing_cut", "name": "死撑·加减伤", "kind": "num", "max": 3, "req_p": "laobing",
		"desc": "残血减伤 +4%/层", "anim": "撑得更硬"},
	{"id": "laobing_thr", "name": "死撑·加反伤", "kind": "num", "max": 3, "req_p": "laobing",
		"desc": "残血时反伤 +6%/层", "anim": "残了也要咬一口"},
	{"id": "laobing_hp", "name": "死撑·加气血", "kind": "num", "max": 3, "req_p": "laobing",
		"desc": "气血上限 +60（一层就够）", "anim": "多一点血"},
	# v15w 新增 12 位的强化档位
	{"id": "xinglin_cd", "name": "回春·减冷却", "kind": "num", "max": 3, "req_p": "xinglin",
		"desc": "冷却 −2 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "针扎得更勤"},
	{"id": "xinglin_heal", "name": "回春·加治疗", "kind": "num", "max": 3, "req_p": "xinglin",
		"desc": "治疗 +3% 生命上限/层【内力消耗 +20/层】", "anim": "回得更多"},
	{"id": "xinglin_dur", "name": "回春·加吸血", "kind": "num", "max": 3, "req_p": "xinglin",
		"desc": "吸血窗口 +1 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "吸血更久"},
	{"id": "qiaofu_cd", "name": "劈柴·减冷却", "kind": "num", "max": 3, "req_p": "qiaofu",
		"desc": "冷却 −1.5 秒（现 <CD> 秒）", "anim": "斧头抡得更勤"},
	{"id": "qiaofu_dmg", "name": "劈柴·加伤", "kind": "num", "max": 3, "req_p": "qiaofu",
		"desc": "伤害 +25%/层", "anim": "劈得更狠"},
	{"id": "pozhen_dmg", "name": "破甲·加伤", "kind": "num", "max": 3, "req_p": "pozhen",
		"desc": "伤害 +20%/层", "anim": "破得更深"},
	{"id": "pozhen_cd", "name": "破甲·减冷却", "kind": "num", "max": 3, "req_p": "pozhen",
		"desc": "冷却 −2 秒（现 <CD> 秒）", "anim": "砍得更频"},
	{"id": "busheren_dmg", "name": "蛇咬·加伤", "kind": "num", "max": 3, "req_p": "busheren",
		"desc": "伤害 +20%/层【内力消耗 +20/层】", "anim": "蛇牙更毒"},
	{"id": "busheren_cd", "name": "蛇咬·减冷却", "kind": "num", "max": 3, "req_p": "busheren",
		"desc": "冷却 −2 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "放蛇更勤"},
	{"id": "gengfu_dur", "name": "报更·加持续", "kind": "num", "max": 3, "req_p": "gengfu",
		"desc": "致盲 +1 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "瞎得更久"},
	{"id": "gengfu_cd", "name": "报更·减冷却", "kind": "num", "max": 3, "req_p": "gengfu",
		"desc": "冷却 −3 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "敲得更勤"},
	{"id": "gushi_dmg", "name": "蛊毒·加毒", "kind": "num", "max": 3, "req_p": "gushi",
		"desc": "毒伤 +20%/层【内力消耗 +20/层】", "anim": "蛊更烈"},
	{"id": "gushi_dur", "name": "蛊毒·加持续", "kind": "num", "max": 3, "req_p": "gushi",
		"desc": "毒持续 +1 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "毒留得久"},
	{"id": "kuaidaoshou_dmg", "name": "快刀·加伤", "kind": "num", "max": 3, "req_p": "kuaidaoshou",
		"desc": "每刀 +15%/层", "anim": "刀更快更狠"},
	{"id": "kuaidaoshou_cd", "name": "快刀·减冷却", "kind": "num", "max": 3, "req_p": "kuaidaoshou",
		"desc": "冷却 −1 秒（现 <CD> 秒）", "anim": "砍得更频"},
	{"id": "chuangong_dmg", "name": "撑篙·加伤", "kind": "num", "max": 3, "req_p": "chuangong",
		"desc": "伤害 +20%/层【内力消耗 +20/层】", "anim": "一篙更重"},
	{"id": "chuangong_cd", "name": "撑篙·减冷却", "kind": "num", "max": 3, "req_p": "chuangong",
		"desc": "冷却 −2 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "撑得更勤"},
	{"id": "tiemianseng_cut", "name": "铁面·加减伤", "kind": "num", "max": 3, "req_p": "tiemianseng",
		"desc": "减伤 +4%/层【内力消耗 +20/层】", "anim": "更扛打"},
	{"id": "tiemianseng_dur", "name": "铁面·加持续", "kind": "num", "max": 3, "req_p": "tiemianseng",
		"desc": "持续 +2 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "入定更久"},
	{"id": "lengyueniang_dmg", "name": "寒霜·加伤", "kind": "num", "max": 3, "req_p": "lengyueniang",
		"desc": "伤害 +20%/层【内力消耗 +20/层】", "anim": "霜更冷"},
	{"id": "lengyueniang_dur", "name": "寒霜·加持续", "kind": "num", "max": 3, "req_p": "lengyueniang",
		"desc": "减速 +1 秒（现 <DUR> 秒）【内力消耗 +20/层】", "anim": "冻得更久"},
	{"id": "guijianchou_dmg", "name": "斩首·加比例", "kind": "num", "max": 3, "req_p": "guijianchou",
		"desc": "已损失气血那一项 +5%/层【内力消耗 +20/层】", "anim": "刀更冷"},
	{"id": "guijianchou_cd", "name": "斩首·减冷却", "kind": "num", "max": 3, "req_p": "guijianchou",
		"desc": "冷却 −2 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "斩得更频"},
	{"id": "zuitaisui_dmg", "name": "酒气·加攻", "kind": "num", "max": 3, "req_p": "zuitaisui",
		"desc": "攻击 +3%/层【内力消耗 +20/层】", "anim": "酒更烈"},
	{"id": "zuitaisui_cd", "name": "酒气·减冷却", "kind": "num", "max": 3, "req_p": "zuitaisui",
		"desc": "冷却 −3 秒（现 <CD> 秒）【内力消耗 +20/层】", "anim": "喝得更勤"},

]
func skill_lv(id: String) -> int:
	if skill.has(id):
		return int(skill[id])
	# v15d：⚠ 原来这里只硬编码了 anying/chenshi 两个前缀 —— 别的伙伴的强化项
	#   **存进去了却读不出来**（apply_pick 是通用的，读的时候写死了，档位等于白升）。
	#   现在跟 apply_pick 一个口径：谁的前缀对上就是谁。
	for pid in partners.keys():
		var ps := str(pid)
		if id.begins_with(ps + "_"):
			var key := id.substr(ps.length() + 1) + "_lv"
			return int((partners[ps] as Dictionary).get(key, 0))
	return 0

func atk_mul() -> float:
	return 1.0 + 0.12 * float(skill["dmg"])

# v14b：玄机子「时间停止」给的临时攻速（战场自己管，跟外壳的疾风符互不干扰）
var _p_aspd := 0.0

func aspd_mul() -> float:
	var m := 1.0 + 0.08 * float(skill["aspd"])
	if _p_aspd > 0.0:
		m *= 2.0
	return m

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
#     暗影裁决【下品】技能「肝」：持续时间内杀敌，生命值上限 +1（每层 +0.5）；
#       耗内力 100 · 持续 5s · 冷却 25s（v4s 按用户要求降品削弱）
#       可选：-冷却【提升内力消耗】/ +持续【提升内力消耗】/ +杀敌生命【提升内力消耗】/ -内力消耗
#     陈石【下品】技能「刺骨」：持续时间内被攻击时，对攻击自己的一名敌人造成生命值 2% 的真实伤害；
#       耗内力 100 · 持续 8s · 冷却 20s
#       可选：-冷却【提升内力消耗】/ +持续【提升内力消耗】/ +反伤伤害【内力消耗】/ -内力消耗 / +反伤敌人数量
#   规则：**内力够了且不在冷却就自动放**（战斗是自动打的）；"提升内力消耗"是这些强化项自带的代价。
# ============================================================
var partners := {
	"anying": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0,
		"cd_lv": 0, "dur_lv": 0, "hp_lv": 0, "cost_lv": 0},
	"chenshi": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0,
		"cd_lv": 0, "dur_lv": 0, "dmg_lv": 0, "tgt_lv": 0, "cost_lv": 0},
	# v4f（用户）：苏青鸾【极品】技能「飞匕」——**每隔 8 秒生成一个匕首，命中最近的敌人**
	#   可选：+穿透 / +飞匕伤害 / +弹射【弹射独立伤害】/ +多重【多重独立伤害】/ +弹射伤害 / +弹射独立伤害 / -秒数
	# v4i（用户："穿透【飞匕伤害】弹射【弹射伤害】多重【多重伤害】 比如+多重伤害 多重的整体伤害会增加"）：
	#   **三条并列的伤害账**——飞匕伤害（首击与穿透都用它）／弹射伤害（弹射那一下）／多重伤害（多出来的匕首）；
	#   各自有对应的"+XX伤害"强化项，互不串味。
	# v4j（用户）：张道陵【绝品】技能「天雷道术」——范围金系伤害，耗 300 内力、冷却 10s
	# v4l（用户）崔三娘【绝品】雾海龙王：召唤蛟龙为你作战（继承主角 25% 属性、**可多招**），
	#   蛟龙会普攻，还带自己的技能「大浪拍击」（水系、冷却 20s）；耗 500 内力、冷却 60s
	"cuisanniang": {"owned": false, "mp": 0.0, "cd": 6.0, "active": 0.0,
		"inherit_lv": 0, "skill_lv": 0, "radius_lv": 0, "cost_lv": 0, "cd_lv": 0, "life_lv": 0},
	# v4n（用户："杀敌+攻击的 和杀敌加内力的 下品 和暗影裁决几乎雷同 你帮我想 同样要特效"）
	#   两位下品，跟暗影裁决一个骨架（持续窗口内杀敌涨属性），但**更弱**、**特效各不同**：
	#   独眼彪「杀气」＝杀敌涨**攻击**（赤红杀气）；枯荣「纳气」＝杀敌涨**内力上限**（琥珀气丝往身上收）
	# v4o 法度【中品】怒目金刚：护盾 ＋ 破盾土系范围伤害 ＋ 每降 10% 出一段
	"fadu": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0,
		"shield_lv": 0, "break_lv": 0, "dur_lv": 0, "cd_lv": 0, "cost_lv": 0, "step_lv": 0, "range_lv": 0},
	"duyanbiao": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0,
		"cd_lv": 0, "dur_lv": 0, "atk_lv": 0, "cost_lv": 0},
	"kurong": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0,
		"cd_lv": 0, "dur_lv": 0, "mp_lv": 0, "cost_lv": 0},
	# v4k 柳卿卿【上品】回春：治疗自己 ＋ 让最近一名敌人中毒（木系持续伤害）
	"liuqingqing": {"owned": false, "mp": 0.0, "cd": 2.0, "active": 0.0,
		"heal_lv": 0, "poison_lv": 0, "pdur_lv": 0, "spread_lv": 0, "cd_lv": 0, "cost_lv": 0},
	# v4k 季沧海【极品】怒火焚身：每 3 秒烧最近一名敌人（火系），**传火**会引燃它身边一名
	"jicanghai": {"owned": false, "mp": 0.0, "cd": 2.0, "active": 0.0,
		"dmg_lv": 0, "spread_lv": 0, "burn_lv": 0, "sec_lv": 0},
	"zhangdaoling": {"owned": false, "mp": 0.0, "cd": 3.0, "active": 0.0,
		"dmg_lv": 0, "range_lv": 0, "para_lv": 0, "paradur_lv": 0,
		"cost_lv": 0, "cd_lv": 0, "multi_lv": 0, "multidmg_lv": 0},
	"suqingluan": {"owned": false, "mp": 0.0, "cd": 4.0, "active": 0.0,
		"pierce_lv": 0, "dmg_lv": 0, "bounce_lv": 0, "multi_lv": 0,
		"bdmg_lv": 0, "mdmg_lv": 0, "sec_lv": 0},
	# v14b：新增 10 名（档位键跟老的一致：cd/dur + 各自的效果层 + cost）
	"shigandang": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "cd_lv": 0, "dur_lv": 0, "cut_lv": 0, "cost_lv": 0},
	"qianduoduo": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "cd_lv": 0, "dur_lv": 0, "gold_lv": 0, "cost_lv": 0},
	"leixiaoqi": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0, "sec_lv": 0},
	"baipopo": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "cd_lv": 0, "heal_lv": 0, "cost_lv": 0},
	"tiexinwu": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "cd_lv": 0, "dur_lv": 0, "cost_lv": 0},
	"shenqingluo": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "cd_lv": 0, "tgt_lv": 0, "dmg_lv": 0, "cost_lv": 0},
	"yanwugui": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "cd_lv": 0, "dur_lv": 0, "crit_lv": 0, "cost_lv": 0},
	"ximenlie": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0, "sec_lv": 0},
	"duniangzi": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "cd_lv": 0, "dmg_lv": 0, "dot_lv": 0, "cost_lv": 0},
	"xuanjizi": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "cd_lv": 0, "dur_lv": 0, "cost_lv": 0},
	# v15c 新增 12 位
	"tietouseng": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0},
	"bingshusheng": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0, "dur_lv": 0, "cost_lv": 0},
	"xiaoqier": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dur_lv": 0, "gold_lv": 0, "cost_lv": 0},
	"laobing": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "cut_lv": 0},
	"zuijianxian": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0, "sec_lv": 0},
	"yaopozi": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "heal_lv": 0, "cost_lv": 0},
	"gushangzao": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "aspd_lv": 0, "cost_lv": 0},
	"jinjiaxianwei": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "cut_lv": 0, "cost_lv": 0},
	"huogong": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0, "tgt_lv": 0, "dur_lv": 0, "cost_lv": 0},
	"qinchi": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dur_lv": 0, "cost_lv": 0},
	"baiqihouren": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0, "cost_lv": 0},
	"dagongfeng": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "shield_lv": 0, "dur_lv": 0, "cost_lv": 0},
	# v15w 新增 12 位
	"xinglin": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "heal_lv": 0, "dur_lv": 0, "cost_lv": 0},
	"qiaofu": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0},
	"pozhen": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0},
	"busheren": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0, "cost_lv": 0},
	"gengfu": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dur_lv": 0, "cost_lv": 0},
	"gushi": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0, "dur_lv": 0, "cost_lv": 0},
	"kuaidaoshou": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0},
	"chuangong": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0, "cost_lv": 0},
	"tiemianseng": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "cut_lv": 0, "dur_lv": 0, "cost_lv": 0},
	"lengyueniang": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0, "dur_lv": 0, "cost_lv": 0},
	"guijianchou": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0, "cost_lv": 0},
	"zuitaisui": {"owned": false, "mp": 0.0, "cd": 0.0, "active": 0.0, "dmg_lv": 0},
}
var _dg_list: Array = []            # 飞匕：{pos, dir, tgt, dmg, pierce, bounce, hits, t}
const PARTNER_INFO := {
	# v4s（用户："暗影调整为下品 适当削弱"）：品质降到**下品**，并跟另两位下品（杀气/纳气）对齐——
	#   冷却 20 → **25 秒**；杀敌生命 +2 → **+1**（每层 +0.5）
	"anying": {"name": "暗影裁决", "quality": "下品", "skill": "肝", "dtype": "无伤害", "grow": {"arm": 2, "agi": 1, "wit": 1},
		"desc": "持续时间内杀敌，生命值上限 +1（每层 +0.5）",
		"mp0": 100.0, "cd0": 25.0, "dur0": 5.0},
	# v4t（用户："陈石改为中 略微加强"）：下品 → **中品**；反伤 2% → **2.5%**、冷却 20 → **17 秒**、持续 8 → **9 秒**
	"chenshi": {"name": "陈石", "quality": "中品", "skill": "刺骨", "dtype": "真实", "grow": {"arm": 3, "agi": 1, "wit": 0},
		"desc": "持续时间内被攻击时，对攻击自己的一名敌人造成生命值 2.5% 的真实伤害（无视防御）",
		"mp0": 100.0, "cd0": 17.0, "dur0": 9.0},
	"fadu": {"name": "法度", "quality": "中品", "skill": "怒目金刚", "dtype": "土系（护盾）", "grow": {"arm": 2, "agi": 2, "wit": 1},
		"desc": "给自己套一层护盾（先扣盾再扣血）；护盾被击破时，对周围造成等于护盾值的土系范围伤害",
		"mp0": 150.0, "cd0": 20.0, "dur0": 8.0},
	"duyanbiao": {"name": "独眼彪", "quality": "下品", "skill": "杀气", "dtype": "无伤害", "grow": {"arm": 3, "agi": 2, "wit": 0},
		"desc": "持续时间内每杀一名敌人，攻击 +1（每层强化再 +0.5）——一生二、二生三的滚雪球",
		"mp0": 100.0, "cd0": 25.0, "dur0": 5.0},
	"kurong": {"name": "枯荣", "quality": "下品", "skill": "纳气", "dtype": "无伤害", "grow": {"arm": 1, "agi": 1, "wit": 3},
		"desc": "持续时间内每杀一名敌人，内力上限 +3（并回同样多内力）——越打越能放法术",
		"mp0": 100.0, "cd0": 25.0, "dur0": 5.0},
	"cuisanniang": {"name": "崔三娘", "quality": "绝品", "skill": "雾海龙王", "dtype": "召唤 · 水系", "grow": {"arm": 2, "agi": 1, "wit": 4},
		"desc": "召唤一条蛟龙替你作战（继承主角 25% 属性，可多招）；蛟龙会自行普攻，并带技能「大浪拍击」（水系）",
		"mp0": 500.0, "cd0": 60.0, "dur0": 0.0},
	"liuqingqing": {"name": "柳卿卿", "quality": "上品", "skill": "回春", "dtype": "治疗 + 木系", "grow": {"arm": 1, "agi": 1, "wit": 3},
		"desc": "治疗自己（回生命上限的一部分），同时让最近的敌人中毒——木系持续伤害，每秒跳一次",
		"mp0": 120.0, "cd0": 12.0, "dur0": 0.0},
	"jicanghai": {"name": "季沧海", "quality": "极品", "skill": "怒火焚身", "dtype": "火系", "grow": {"arm": 2, "agi": 2, "wit": 3},
		"desc": "每 3 秒烧最近一名敌人（火系）；传火：会引燃它身边范围内的另一名敌人",
		"mp0": 0.0, "cd0": 3.0, "dur0": 0.0},
	"zhangdaoling": {"name": "张道陵", "quality": "绝品", "skill": "天雷道术", "dtype": "金系", "grow": {"arm": 0, "agi": 2, "wit": 5},
		"desc": "落下一道天雷，砸在最近的敌人身上，**两个人身位**内的敌人一起吃金系伤害；有几率麻痹",
		"mp0": 300.0, "cd0": 10.0, "dur0": 0.0},
	"suqingluan": {"name": "苏青鸾", "quality": "极品", "skill": "飞匕", "dtype": "物理", "grow": {"arm": 1, "agi": 4, "wit": 1},
		"desc": "每隔 8 秒生成一枚飞匕，命中最近的敌人。飞匕/弹射/多重都是物理伤害，只是倍率各算各的（都吃防御）",
		"mp0": 0.0, "cd0": 8.0, "dur0": 0.0},
	# ============================================================
	# v14b：队员扩到 20 名（用户："队员增加到20个 保证每个品级至少3个 下品可以多一点
	#        机制也要有 特效一定要有不同的"）——每个都是独一份的机制
	# ============================================================
	# ---- 下品（共 5：暗影/独眼彪/枯荣 + 这两个）----
	"shigandang": {"name": "石敢当", "quality": "下品", "skill": "坚守", "dtype": "无伤害", "grow": {"arm": 4, "agi": 1, "wit": 0},
		"desc": "持续 6 秒内受到的伤害 −25%（硬抗型）",
		"mp0": 100.0, "cd0": 22.0, "dur0": 6.0},
	"qianduoduo": {"name": "钱多多", "quality": "下品", "skill": "点金", "dtype": "无伤害", "grow": {"arm": 1, "agi": 2, "wit": 2},
		"desc": "持续 6 秒内，每击杀一名敌人额外掉 3 文钱（经济型）",
		"mp0": 100.0, "cd0": 24.0, "dur0": 6.0},
	# ---- 中品（共 4：陈石/法度 + 这两个）----
	"leixiaoqi": {"name": "雷小七", "quality": "中品", "skill": "连环腿", "dtype": "物理", "grow": {"arm": 2, "agi": 4, "wit": 0},
		"desc": "每 4 秒对最近敌人连踢两下（两次独立判定，可能一下暴一下不暴）",
		"mp0": 0.0, "cd0": 4.0, "dur0": 0.0},
	"baipopo": {"name": "白婆婆", "quality": "中品", "skill": "续命", "dtype": "治疗", "grow": {"arm": 1, "agi": 1, "wit": 4},
		"desc": "每 15 秒回一次血（生命上限 12%）；自己残血（低于 40%）时回血翻倍",
		"mp0": 80.0, "cd0": 15.0, "dur0": 0.0},
	# ---- 上品（共 4：柳卿卿 + 这三个）----
	"tiexinwu": {"name": "铁无心", "quality": "上品", "skill": "铁壁", "dtype": "无伤害", "grow": {"arm": 4, "agi": 2, "wit": 1},
		"desc": "持续 8 秒内，第一次受到的伤害完全免疫（一次性格挡）",
		"mp0": 120.0, "cd0": 20.0, "dur0": 8.0},
	"shenqingluo": {"name": "沈青萝", "quality": "上品", "skill": "藤缚", "dtype": "木系", "grow": {"arm": 1, "agi": 2, "wit": 4},
		"desc": "每 12 秒缠住最近的 3 名敌人（定身 2 秒）并造成木系伤害",
		"mp0": 120.0, "cd0": 12.0, "dur0": 0.0},
	"yanwugui": {"name": "燕无归", "quality": "上品", "skill": "鹰眼", "dtype": "无伤害", "grow": {"arm": 1, "agi": 4, "wit": 1},
		"desc": "持续 8 秒内暴击率 +25%（爆发窗口型）",
		"mp0": 110.0, "cd0": 18.0, "dur0": 8.0},
	# ---- 极品（共 4：季沧海/苏青鸾 + 这两个）----
	"ximenlie": {"name": "西门烈", "quality": "极品", "skill": "烈焰刀", "dtype": "火系", "grow": {"arm": 3, "agi": 2, "wit": 3},
		"desc": "每 6 秒劈出一道火刃，横扫最近敌人身前 140 像素范围（火系范围）",
		"mp0": 0.0, "cd0": 6.0, "dur0": 0.0},
	"duniangzi": {"name": "毒娘子", "quality": "极品", "skill": "万毒", "dtype": "木系（持续）", "grow": {"arm": 1, "agi": 2, "wit": 4},
		"desc": "每 10 秒给全场敌人挂毒（木系，每秒跳一次，持续 6 秒）",
		"mp0": 200.0, "cd0": 10.0, "dur0": 0.0},
	# ---- 绝品（共 3：崔三娘/张道陵 + 这个）----
	"xuanjizi": {"name": "玄机子", "quality": "绝品", "skill": "时间停止", "dtype": "无伤害", "grow": {"arm": 1, "agi": 3, "wit": 6},
		"desc": "每 45 秒把全场敌人定身 3 秒，同时自己攻速翻倍 3 秒",
		"mp0": 400.0, "cd0": 45.0, "dur0": 0.0},
# ============================================================
# v15c 新增 12 位（用户：伙伴可以多做一点新的）
#   原则：机制尽量复用战场上**已有**的那几套（持续伤害/定身/治疗/掉钱/护盾/范围），
#   不引入没验证过的新系统；每位的特效各自不同，跟老伙伴不撞。
#   档位分布：下品 +4 · 中品 +3 · 上品 +3 · 极品 +2
# ============================================================
# ---- 下品 +4 ----
	"tietouseng": {"name": "铁头僧", "quality": "下品", "skill": "铁头功", "dtype": "物理", "grow": {"arm": 4, "agi": 1, "wit": 0},
	"desc": "每 6 秒一头撞向最近敌人（物理，一次重击；血越少撞得越狠）",
	"mp0": 0.0, "cd0": 6.0, "dur0": 0.0},
	"bingshusheng": {"name": "病书生", "quality": "下品", "skill": "咳血", "dtype": "木系（持续）", "grow": {"arm": 0, "agi": 2, "wit": 3},
	"desc": "每 9 秒让最近敌人中毒（木系持续伤害，每秒跳一次，持续 4 秒）",
	"mp0": 80.0, "cd0": 9.0, "dur0": 0.0},
	"xiaoqier": {"name": "小乞儿", "quality": "下品", "skill": "顺手牵羊", "dtype": "无伤害", "grow": {"arm": 1, "agi": 3, "wit": 1},
	"desc": "持续 6 秒内，每击杀一名敌人额外掉 2 文钱（比钱多多少，冷却更短）",
	"mp0": 90.0, "cd0": 18.0, "dur0": 6.0},
	"laobing": {"name": "瘸腿老兵", "quality": "下品", "skill": "死撑", "dtype": "无伤害", "grow": {"arm": 3, "agi": 1, "wit": 1},
	"desc": "气血低于 50% 时，全伤害减免 +12%（残血才生效的硬抗）",
	"mp0": 0.0, "cd0": 0.0, "dur0": 0.0},
# ---- 中品 +3 ----
	"zuijianxian": {"name": "醉剑仙", "quality": "中品", "skill": "醉里挑灯", "dtype": "物理", "grow": {"arm": 2, "agi": 4, "wit": 1},
	"desc": "每 5 秒晃到最近敌人身边连刺两下（物理，两下各自判定）",
	"mp0": 0.0, "cd0": 5.0, "dur0": 0.0},
	"yaopozi": {"name": "药婆子", "quality": "中品", "skill": "金针", "dtype": "治疗", "grow": {"arm": 1, "agi": 1, "wit": 4},
	"desc": "每 14 秒回一次血（生命上限 10%），并让最近敌人定身 1.5 秒",
	"mp0": 100.0, "cd0": 14.0, "dur0": 0.0},
	"gushangzao": {"name": "鼓上蚤", "quality": "中品", "skill": "踏鼓", "dtype": "无伤害", "grow": {"arm": 1, "agi": 4, "wit": 1},
	"desc": "持续 7 秒内攻速 +35%（自己敲鼓提气）",
	"mp0": 100.0, "cd0": 20.0, "dur0": 7.0},
# ---- 上品 +3 ----
	"jinjiaxianwei": {"name": "金甲校尉", "quality": "上品", "skill": "拒马", "dtype": "土系（护盾）", "grow": {"arm": 4, "agi": 1, "wit": 2},
	"desc": "持续 8 秒内受到伤害 −30%，并把伤害的一部分反弹给打你的人（土系）",
	"mp0": 130.0, "cd0": 22.0, "dur0": 8.0},
	"huogong": {"name": "火工道人", "quality": "上品", "skill": "三昧真火", "dtype": "火系（持续）", "grow": {"arm": 2, "agi": 2, "wit": 3},
	"desc": "每 11 秒点燃最近的 2 名敌人（火系持续燃烧，每秒跳一次，持续 5 秒）",
	"mp0": 150.0, "cd0": 11.0, "dur0": 0.0},
	"qinchi": {"name": "琴痴", "quality": "上品", "skill": "乱神曲", "dtype": "无伤害", "grow": {"arm": 0, "agi": 2, "wit": 5},
	"desc": "每 16 秒弹一曲：全场敌人定身 2 秒（控制型）",
	"mp0": 180.0, "cd0": 16.0, "dur0": 0.0},
# ---- 极品 +2 ----
	"baiqihouren": {"name": "白起后人", "quality": "极品", "skill": "杀神", "dtype": "真实", "grow": {"arm": 4, "agi": 2, "wit": 1},
	"desc": "每 12 秒对最近的敌人造成基于**已损失气血**的真实伤害（越残越致命，无视防御）",
	"mp0": 160.0, "cd0": 12.0, "dur0": 0.0},
	"dagongfeng": {"name": "大内供奉", "quality": "极品", "skill": "罡气", "dtype": "金系（护盾）", "grow": {"arm": 3, "agi": 1, "wit": 4},
	"desc": "每 24 秒给自己罩一层罡气：吸收 15% 生命上限的伤害，持续 10 秒，破时炸一圈金系伤害",
	"mp0": 200.0, "cd0": 24.0, "dur0": 10.0},
	# ============================================================
	# v15w（用户："伙伴内容不够就加伙伴"）：再添 12 位 —— 总数 32 → 44
	#   档位：下品 +5 · 中品 +3 · 上品 +2 · 极品 +2
	#   原则同前：机制尽量复用战场上已有的那几套
	# ============================================================
	"xinglin": {"name": "杏林医女", "quality": "下品", "skill": "回春针", "dtype": "治疗", "grow": {"arm": 1, "agi": 1, "wit": 3},
		"desc": "每 10 秒扎一针：回一小口血，并把伤害的一部分转成回血（持续 6 秒）",
		"mp0": 80.0, "cd0": 10.0, "dur0": 6.0},
	"qiaofu": {"name": "樵夫", "quality": "下品", "skill": "劈柴", "dtype": "物理", "grow": {"arm": 3, "agi": 1, "wit": 0},
		"desc": "每 7 秒抡一斧：物理重击并把目标击退一段",
		"mp0": 0.0, "cd0": 7.0, "dur0": 0.0},
	"pozhen": {"name": "破阵刀客", "quality": "下品", "skill": "破甲", "dtype": "物理", "grow": {"arm": 2, "agi": 2, "wit": 0},
		"desc": "每 8 秒一刀：物理伤害并让目标护甲 −20%（持续 5 秒）",
		"mp0": 0.0, "cd0": 8.0, "dur0": 0.0},
	"busheren": {"name": "捕蛇人", "quality": "下品", "skill": "蛇咬", "dtype": "木系", "grow": {"arm": 1, "agi": 3, "wit": 1},
		"desc": "每 8 秒放蛇咬最近敌人：木系伤害，目标中毒时伤害翻倍",
		"mp0": 90.0, "cd0": 8.0, "dur0": 0.0},
	"gengfu": {"name": "更夫", "quality": "下品", "skill": "报更", "dtype": "无伤害", "grow": {"arm": 1, "agi": 2, "wit": 2},
		"desc": "每 14 秒敲梆子：最近 2 名敌人致盲（命中降低，持续 5 秒）",
		"mp0": 90.0, "cd0": 14.0, "dur0": 0.0},
	"gushi": {"name": "蛊师", "quality": "中品", "skill": "蛊毒", "dtype": "木系（持续）", "grow": {"arm": 1, "agi": 2, "wit": 4},
		"desc": "每 13 秒撒蛊：给最近 2 名敌人挂毒",
		"mp0": 150.0, "cd0": 13.0, "dur0": 0.0},
	"kuaidaoshou": {"name": "快刀手", "quality": "中品", "skill": "快刀", "dtype": "物理", "grow": {"arm": 1, "agi": 4, "wit": 1},
		"desc": "每 6 秒连砍三刀（物理，三下各自判定）",
		"mp0": 0.0, "cd0": 6.0, "dur0": 0.0},
	"chuangong": {"name": "老船工", "quality": "中品", "skill": "撑篙", "dtype": "水系", "grow": {"arm": 3, "agi": 1, "wit": 2},
		"desc": "每 11 秒一篙：水系伤害并把最近敌人推开",
		"mp0": 110.0, "cd0": 11.0, "dur0": 0.0},
	"tiemianseng": {"name": "铁面僧", "quality": "上品", "skill": "铁面", "dtype": "土系", "grow": {"arm": 4, "agi": 1, "wit": 2},
		"desc": "每 16 秒入定：接下来 6 秒受到伤害 −25%，减免量还给主角回血",
		"mp0": 130.0, "cd0": 16.0, "dur0": 6.0},
	"lengyueniang": {"name": "冷月娘", "quality": "上品", "skill": "寒霜", "dtype": "水系", "grow": {"arm": 1, "agi": 2, "wit": 4},
		"desc": "每 12 秒撒霜：最近 3 名敌人受水系伤害并被减速（6 秒）",
		"mp0": 140.0, "cd0": 12.0, "dur0": 0.0},
	"guijianchou": {"name": "鬼见愁", "quality": "极品", "skill": "斩首", "dtype": "真实", "grow": {"arm": 4, "agi": 3, "wit": 1},
		"desc": "每 18 秒斩血量最低的那个：血越少伤害越高；击杀则冷却立刻减半",
		"mp0": 200.0, "cd0": 18.0, "dur0": 0.0},
	"zuitaisui": {"name": "醉太岁", "quality": "极品", "skill": "酒气", "dtype": "无伤害", "grow": {"arm": 3, "agi": 2, "wit": 3},
		"desc": "每 22 秒灌一口：接下来 8 秒攻击 +25% 且每次命中回 2 点内力",
		"mp0": 180.0, "cd0": 22.0, "dur0": 8.0},
}
const PARTNER_UP_STEP_MP := 20.0      # 每个"提升内力消耗"的强化 +20 内力
const PARTNER_DOWN_STEP_MP := 15.0    # "减内力消耗"每层 −15
# v4j：内力池要为"300 内力一发"的法术留出空间——上限 300 起（每级 +25），每秒回 10
const MP_REGEN := 10.0
const PARTNER_MP_FLOOR := 40.0

# 现算的数值（改一项不用到处同步）
func p_mp(id: String) -> float:
	var p: Dictionary = partners[id]
	var info: Dictionary = PARTNER_INFO[id]
	if float(info["mp0"]) <= 0.0:
		return 0.0
	# 通用：**所有**"加效果"的层都 +20 内力（除 cost_lv）——加新伙伴不用改这里
	var ups := 0.0
	for k in p.keys():
		var ks := str(k)
		if ks.ends_with("_lv") and ks != "cost_lv":
			ups += float(p[k])
	var v := float(info["mp0"]) + PARTNER_UP_STEP_MP * ups - PARTNER_DOWN_STEP_MP * float(p.get("cost_lv", 0))
	return maxf(PARTNER_MP_FLOOR, v)

# ⚠ 用 get(…, 0)：不同伙伴的档位键不一样（苏青鸾就没有 cd_lv/dur_lv），
#   直接下标会报 "Invalid access to property or key"（探针抓到的）
func p_cd(id: String) -> float:
	var lv := float((partners[id] as Dictionary).get("cd_lv", 0))
	return maxf(4.0, float(PARTNER_INFO[id]["cd0"]) - 3.0 * lv) / p_star_mul(id)     # v14o：星减冷却

func p_dur(id: String) -> float:
	var lv := float((partners[id] as Dictionary).get("dur_lv", 0))
	return (float(PARTNER_INFO[id]["dur0"]) + 2.0 * lv) * p_star_mul(id)     # v14o：星也加持续

func p_kill_hp() -> float:                 # 肝：杀敌给的生命上限（下品削弱：2 → 1，每层 +0.5）
	return (1.0 + 0.5 * float(partners["anying"]["hp_lv"])) * p_star_mul("anying")

func p_thorns() -> float:                  # 刺骨：反伤（占生命上限的比例）——v4t 中品：2% → 2.5%
	return (0.025 + 0.005 * float(partners["chenshi"]["dmg_lv"])) * p_star_mul("chenshi")

func p_thorn_targets() -> int:
	return 1 + int(partners["chenshi"]["tgt_lv"])

# ============================================================
# 法度·怒目金刚（v4o）：护盾 ＋ 破盾土系**范围**伤害 ＋"每降 10% 出一段"
#   护盾：先扣盾、再扣血；破盾那一下＝对**周围一圈**造成等于护盾值的土系伤害
#   层段（用户点名）：护盾每掉 10% 就震荡一次，造成"10% × 层数"的护盾值土系伤害——**也是范围**
# ============================================================
var _quake_fx: Array = []           # 土系震荡：{x, y, r, t, big}

func fd_shield() -> float:
	return float(hero["hp_max"]) * (0.40 + 0.15 * float(partners["fadu"].get("shield_lv", 0))) * p_star_mul("fadu")

func fd_break_mul() -> float:
	return 1.0 + 0.25 * float(partners["fadu"].get("break_lv", 0))

# v4p（用户："我单指的法度有范围"）：**只有法度**这条 +范围（天雷/龙王那两条是原本就有的）
func fd_range() -> float:
	return 150.0 + 25.0 * float(partners["fadu"].get("range_lv", 0))

func fd_step_pct() -> float:
	return 0.10 * float(partners["fadu"].get("step_lv", 0))     # 0 ＝ 没学"层段"

func fd_dur() -> float:
	return (8.0 + 2.0 * float(partners["fadu"].get("dur_lv", 0))) * p_star_mul("fadu")

func fd_cd() -> float:
	return maxf(6.0, 20.0 - 3.0 * float(partners["fadu"].get("cd_lv", 0))) / p_star_mul("fadu")

func _cast_shield() -> void:
	var sv := fd_shield()
	hero["shield_max"] = sv
	hero["shield"] = sv
	hero["shield_t"] = fd_dur()
	_push_float(hero_pos.x, hero_pos.y - 84.0, "怒目金刚　盾 " + str(int(sv)), Color(0.86, 0.72, 0.42), true)
	_quake_fx.append({"x": hero_pos.x, "y": hero_pos.y + 6.0, "r": 70.0, "t": 0.0, "big": false})
	Audio.sfx("drum", -8.0)

# 土系**范围**震荡：主角周围一圈敌人一起吃
func _earth_quake(dmg: float, big: bool) -> void:
	if dmg <= 0.0:
		return
	var r := 150.0 if not big else 210.0
	for f_v in foes.duplicate():
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0:
			continue
		if hero_pos.distance_to(Vector2(float(f["x"]), float(f["y"]))) > r:
			continue
		var dm := _apply_dmg(f, dmg, DMG_EARTH)
		f["flash"] = 0.16
		f["kb"] = 10.0 if not big else 18.0
		_push_float(float(f["x"]), float(f["y"]) - 32.0, "震荡 " + str(int(dm)), Color(0.90, 0.76, 0.46), big)
		if float(f["hp"]) <= 0.0:
			_kill_foe(f)
	_quake_fx.append({"x": hero_pos.x, "y": hero_pos.y + 6.0, "r": r, "t": 0.0, "big": big})
	_shake = maxf(_shake, 10.0 if big else 5.0)
	Audio.sfx("hit_heavy" if big else "melee", -6.0)

func _update_shield(delta: float) -> void:
	if float(hero.get("shield", 0.0)) <= 0.0:
		return
	hero["shield_t"] = float(hero.get("shield_t", 0.0)) - delta
	if float(hero["shield_t"]) <= 0.0:
		hero["shield"] = 0.0
		_push_float(hero_pos.x, hero_pos.y - 70.0, "护盾消散", Color(0.80, 0.74, 0.60))

# 挨打先扣盾：返回"还有多少要打到血上"；跨过每个 10% 就震荡一段，盾碎再来一发大的（都是范围）
func _absorb_by_shield(dmg: float) -> float:
	var sh := float(hero.get("shield", 0.0))
	if sh <= 0.0:
		return dmg
	var mx := maxf(1.0, float(hero.get("shield_max", 1.0)))
	var before := sh / mx
	var left := maxf(0.0, sh - dmg)
	hero["shield"] = left
	var after := left / mx
	var step := fd_step_pct()
	if step > 0.0:
		var a := int(floor(before * 10.0))
		var b := int(floor(after * 10.0))
		if b < a:
			_earth_quake(mx * step, false)
	if left <= 0.0:
		_earth_quake(mx * fd_break_mul(), true)
		_push_float(hero_pos.x - 20.0, hero_pos.y - 96.0, "盾破！", Color(0.96, 0.82, 0.50), true)
		Audio.sfx("sword_in_ground", -4.0)
		# v14a 回流卡：盾破回血
		if float(hero.get("mech_shieldheal", 0.0)) > 0.0:
			var hl := float(hero["hp_max"]) * float(hero["mech_shieldheal"])
			hero["hp"] = minf(float(hero["hp_max"]), float(hero["hp"]) + hl)
			_push_float(hero_pos.x, hero_pos.y - 74.0, "回流 +" + str(int(hl)), Color(0.62, 0.92, 0.86))
	return maxf(0.0, dmg - sh)

func _update_quake(delta: float) -> void:
	for i in range(_quake_fx.size() - 1, -1, -1):
		var q: Dictionary = _quake_fx[i]
		q["t"] = float(q["t"]) + delta
		if float(q["t"]) > 0.45:
			_quake_fx.remove_at(i)

# 画护盾：身周六片石甲 ＋ 一道环；震荡时地面扩开一圈土浪（破盾那圈更大并带放射裂痕）
func _draw_shield(shk: Vector2) -> void:
	var sh := float(hero.get("shield", 0.0))
	var hp2 := hero_pos + shk
	if sh > 0.0:
		var ratio := clampf(sh / maxf(1.0, float(hero.get("shield_max", 1.0))), 0.0, 1.0)
		for i in 6:
			var a := TAU * float(i) / 6.0 + _t * 0.8
			var pp := hp2 + Vector2(cos(a), sin(a) * 0.6) * 52.0
			var plate := PackedVector2Array([pp + Vector2(0, -9), pp + Vector2(8, 0), pp + Vector2(0, 9), pp + Vector2(-8, 0)])
			draw_colored_polygon(plate, Color(0.86, 0.72, 0.42, 0.30 + 0.45 * ratio))
		draw_arc(hp2 + Vector2(0, 12), 54.0, 0.0, TAU, 30, Color(0.92, 0.80, 0.48, 0.30 + 0.4 * ratio), 3.0)
	for q_v in _quake_fx:
		var q2: Dictionary = q_v
		var qa := 1.0 - float(q2["t"]) / 0.45
		var rr := float(q2["r"]) * (0.4 + 0.9 * (1.0 - qa))
		var qp := Vector2(float(q2["x"]), float(q2["y"])) + shk
		draw_arc(qp, rr, 0.0, TAU, 30, Color(0.92, 0.76, 0.44, qa), 8.0 if bool(q2["big"]) else 5.0)
		if bool(q2["big"]):
			for k in 8:
				var a6 := TAU * float(k) / 8.0
				draw_line(qp + Vector2(cos(a6), sin(a6) * 0.6) * rr * 0.6,
					qp + Vector2(cos(a6), sin(a6) * 0.6) * rr * 1.1, Color(0.86, 0.70, 0.40, qa), 4.0)

# ============================================================
# 崔三娘·雾海龙王（v4l）：**召唤物**这一套
#   蛟龙：继承主角 25% 属性（可强化）· 会自己走位普攻 · 自带技能「大浪拍击」（水系，冷却 20s）
#   召唤：耗 500 内力、冷却 60s；**可多招**（同时在场最多 6 条）
# ============================================================
const MINION_MAX := 6
var _minions: Array = []            # 蛟龙：{pos, tgt, atk_cd, skill_cd, born}
var _waves_fx: Array = []           # 大浪拍击的水浪：{x, y, r, t}

func cn_inherit() -> float:
	return 0.25 + 0.05 * float(partners["cuisanniang"]["inherit_lv"])

func cn_skill_mul() -> float:
	return 2.50 * (1.0 + 0.25 * float(partners["cuisanniang"]["skill_lv"])) * p_star_mul("cuisanniang")

# 大浪拍击的范围：0 ＝ 只打一名（升级后变成一片水浪）
func cn_skill_radius() -> float:
	return 60.0 * float(partners["cuisanniang"]["radius_lv"])

func cn_mp() -> float:
	var p: Dictionary = partners["cuisanniang"]
	var ups := float(p.get("inherit_lv", 0)) + float(p.get("skill_lv", 0)) + float(p.get("radius_lv", 0))
	ups += float(p.get("life_lv", 0))
	return maxf(200.0, 500.0 + 60.0 * ups - 40.0 * float(p.get("cost_lv", 0)))

func cn_cd() -> float:
	return maxf(20.0, 60.0 - 8.0 * float(partners["cuisanniang"].get("cd_lv", 0))) / p_star_mul("cuisanniang")

# 蛟龙的存在时间（用户："有存在时间 【+存在时间】"）
func cn_life() -> float:
	return 30.0 + 6.0 * float(partners["cuisanniang"].get("life_lv", 0))

# 蛟龙的血量：继承主角气血的一部分（所以"会被怪打掉"）
func cn_hp() -> float:
	return maxf(30.0, float(hero["hp_max"]) * cn_inherit() * 1.2)

func _summon_dragon() -> void:
	if _minions.size() >= MINION_MAX:
		return
	_minions.append({"pos": hero_pos + Vector2(randf_range(-70.0, 70.0), randf_range(-20.0, 30.0)),
		"tgt": {}, "atk_cd": 0.6, "skill_cd": 20.0, "born": _t,
		"hp": cn_hp(), "hp_max": cn_hp(), "life": cn_life(), "life_max": cn_life(), "dying": 0.0})
	_push_float(hero_pos.x, hero_pos.y - 70.0, "雾海龙王！", Color(0.60, 0.88, 1.0), true)
	_bursts.append({"x": hero_pos.x, "y": hero_pos.y - 10.0, "t": 0.0, "col": Color(0.52, 0.84, 1.0), "scale": 2.0})
	Audio.sfx("bell", -5.0, 0.9)

# 蛟龙：自己找最近的敌人 → 走过去 → 普攻；技能好了就"大浪拍击"
func _update_minions(delta: float) -> void:
	for i in range(_minions.size() - 1, -1, -1):
		var m: Dictionary = _minions[i]
		# 寿终 / 被打死：先"归海"半秒再消失
		if float(m.get("dying", 0.0)) > 0.0:
			m["dying"] = float(m["dying"]) - delta
			if float(m["dying"]) <= 0.0:
				_minions.remove_at(i)
			continue
		m["life"] = float(m["life"]) - delta
		if float(m["life"]) <= 0.0:
			m["dying"] = 0.45
			_push_float(float((m["pos"] as Vector2).x), float((m["pos"] as Vector2).y) - 30.0, "蛟龙归海", Color(0.62, 0.86, 1.0))
			continue
		if float(m["hp"]) <= 0.0:
			m["dying"] = 0.45
			_bursts.append({"x": float((m["pos"] as Vector2).x), "y": float((m["pos"] as Vector2).y), "t": 0.0,
				"col": Color(0.52, 0.80, 1.0), "scale": 1.4})
			_push_float(float((m["pos"] as Vector2).x), float((m["pos"] as Vector2).y) - 30.0, "蛟龙被打散", Color(0.94, 0.72, 0.72))
			Audio.sfx("fall_down", -6.0)
			continue
		var mp2: Vector2 = m["pos"]
		var tg: Dictionary = m["tgt"]
		if tg.is_empty() or not foes.has(tg) or float(tg.get("dying", 0.0)) > 0.0:
			tg = _nearest_except(mp2, [])
			m["tgt"] = tg
		m["atk_cd"] = maxf(0.0, float(m["atk_cd"]) - delta)
		m["skill_cd"] = maxf(0.0, float(m["skill_cd"]) - delta)
		if tg.is_empty():
			# 没敌人：跟在主角旁边
			var home := hero_pos + Vector2(-120.0, 30.0)
			m["pos"] = mp2 + (home - mp2) * minf(1.0, delta * 2.0)
			continue
		var tp := Vector2(float(tg["x"]), float(tg["y"]))
		var to_t := tp - mp2
		if to_t.length() > 58.0:
			m["pos"] = mp2 + to_t.normalized() * minf(128.0 * delta, to_t.length() - 50.0)
		else:
			# 够得着：普攻（物理）——继承主角攻击的一部分
			if float(m["atk_cd"]) <= 0.0:
				m["atk_cd"] = 1.1
				var dm := _apply_dmg(tg, float(hero["atk"]) * cn_inherit() * 0.5, DMG_PHYS)
				tg["flash"] = 0.10
				_push_float(float(tg["x"]) - 20.0, float(tg["y"]) - 20.0, str(int(dm)), Color(0.66, 0.90, 1.0))
				if float(tg["hp"]) <= 0.0:
					_kill_foe(tg)
		# 大浪拍击：到点就放（水系；升级后带范围）
		if float(m["skill_cd"]) <= 0.0:
			m["skill_cd"] = 20.0
			_cast_wave(tp)
		# 别跑出战场
		var p2: Vector2 = m["pos"]
		m["pos"] = Vector2(clampf(p2.x, 40.0, size.x - 40.0), clampf(p2.y, size.y * 0.10, size.y - 40.0))

func _cast_wave(at: Vector2) -> void:
	# v4q 调伤害：6 条同时在场的总量要收——大浪 ×0.72
	var base := float(hero["atk"]) * cn_inherit() * cn_skill_mul() * 0.72
	var r := cn_skill_radius()
	var n := 0
	for f_v in foes.duplicate():
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0:
			continue
		var fp := Vector2(float(f["x"]), float(f["y"]))
		if r > 0.0:
			if at.distance_to(fp) > r:
				continue
		elif n > 0:
			continue
		var dm := _apply_dmg(f, base, DMG_WATER)
		f["flash"] = 0.14
		f["kb"] = 12.0
		_push_float(float(f["x"]), float(f["y"]) - 32.0, "大浪 " + str(int(dm)), Color(0.62, 0.88, 1.0), true)
		n += 1
		if float(f["hp"]) <= 0.0:
			_kill_foe(f)
	_waves_fx.append({"x": at.x, "y": at.y, "r": maxf(70.0, r), "t": 0.0})
	Audio.sfx("rain", -6.0)

func _update_waves(delta: float) -> void:
	for i in range(_waves_fx.size() - 1, -1, -1):
		var wv: Dictionary = _waves_fx[i]
		wv["t"] = float(wv["t"]) + delta
		if float(wv["t"]) > 0.45:
			_waves_fx.remove_at(i)

# 画蛟龙：一串由粗到细的青色圆（蛇身）＋ 头 ＋ 角 ＋ 鳍，随移动摆动
func _draw_minions(shk: Vector2) -> void:
	for m_v in _minions:
		var m: Dictionary = m_v
		var c: Vector2 = m["pos"] + shk
		var tg: Dictionary = m["tgt"]
		var face := Vector2(0.0, -1.0)
		if not tg.is_empty():
			face = (Vector2(float(tg["x"]), float(tg["y"])) - (m["pos"] as Vector2)).normalized()
		var side := face.orthogonal()
		var fade := clampf(float(m.get("dying", 0.0)) / 0.45, 0.0, 1.0)
		for k in 6:
			var f2 := float(k) / 5.0
			var seg := c - face * (10.0 + 16.0 * float(k)) + side * sin(_t * 6.0 + float(k) * 0.8) * 7.0
			draw_circle(seg, 12.0 - 1.4 * float(k), Color(0.30, 0.62, 0.86, (0.95 - 0.08 * f2) * (1.0 if fade <= 0.0 else fade)))
		draw_circle(c, 13.0, Color(0.42, 0.76, 0.96, 1.0 if fade <= 0.0 else fade))
		draw_line(c + face * 12.0, c + face * 22.0, Color(0.90, 0.96, 1.0), 3.0)
		draw_line(c - side * 8.0, c - side * 16.0 - face * 6.0, Color(0.72, 0.90, 1.0), 3.0)
		draw_line(c + side * 8.0, c + side * 16.0 - face * 6.0, Color(0.72, 0.90, 1.0), 3.0)
		draw_circle(c + face * 6.0 - side * 4.0, 2.2, Color(0.10, 0.16, 0.22))
		# 蛟龙的血条（青）＋ 存在时间条（白），让它"会被打掉/会到点"一眼可见
		var hpr := clampf(float(m.get("hp", 1.0)) / maxf(1.0, float(m.get("hp_max", 1.0))), 0.0, 1.0)
		var lfr := clampf(float(m.get("life", 1.0)) / maxf(1.0, float(m.get("life_max", 1.0))), 0.0, 1.0)
		draw_rect(Rect2(c.x - 26.0, c.y - 30.0, 52.0, 6.0), Color(0.12, 0.16, 0.20))
		draw_rect(Rect2(c.x - 26.0, c.y - 30.0, 52.0 * hpr, 6.0), Color(0.42, 0.80, 0.96))
		draw_rect(Rect2(c.x - 26.0, c.y - 22.0, 52.0 * lfr, 3.0), Color(0.88, 0.96, 1.0, 0.85))
		if float(m.get("dying", 0.0)) > 0.0:
			draw_circle(c, 18.0, Color(0.62, 0.88, 1.0, float(m["dying"]) * 0.6))
	# 大浪：一圈扩散的蓝环＋几道浪线
	for w_v in _waves_fx:
		var w: Dictionary = w_v
		var wa := 1.0 - float(w["t"]) / 0.45
		var rr := float(w["r"]) * (0.5 + 0.6 * (1.0 - wa))
		var wp := Vector2(float(w["x"]), float(w["y"])) + shk
		draw_arc(wp, rr, 0.0, TAU, 30, Color(0.54, 0.84, 1.0, wa * 0.9), 7.0)
		draw_arc(wp, rr * 0.7, 0.0, TAU, 26, Color(0.78, 0.94, 1.0, wa * 0.6), 4.0)
# ============================================================
# 柳卿卿·回春（v4k）＋ 季沧海·怒火焚身（v4k）
#   回春：治疗自己 ＋ 最近一名敌人中毒（**木系** DoT，每秒跳一次）
#   怒火：每 3 秒烧最近一名敌人（**火系**）；**传火**＝连它身边范围内的一名一起点着
#   两者都不吃兵器防御（元素规则），只看 res_wood / res_fire
# ============================================================
var _fire_lines: Array = []         # 传火的火线：{from,to,t}

# ---- 柳卿卿 ----
func lq_heal() -> float:
	return (0.18 + 0.06 * float(partners["liuqingqing"]["heal_lv"])) * p_star_mul("liuqingqing")

func lq_poison_mul() -> float:
	return 0.30 * (1.0 + 0.25 * float(partners["liuqingqing"]["poison_lv"])) * p_star_mul("liuqingqing")

func lq_poison_dur() -> float:
	return 4.0 + 2.0 * float(partners["liuqingqing"]["pdur_lv"])

func lq_spread() -> int:
	return 1 + int(partners["liuqingqing"]["spread_lv"])

func lq_cd() -> float:
	return maxf(4.0, 12.0 - 1.5 * float(partners["liuqingqing"].get("cd_lv", 0))) / p_star_mul("liuqingqing")

func lq_mp() -> float:
	var p: Dictionary = partners["liuqingqing"]
	var ups := float(p.get("heal_lv", 0)) + float(p.get("poison_lv", 0)) + float(p.get("pdur_lv", 0))
	ups += float(p.get("spread_lv", 0))
	return maxf(60.0, 120.0 + 20.0 * ups - 15.0 * float(p.get("cost_lv", 0)))

func _cast_spring() -> void:
	# 治疗：回生命上限的一部分（并飘绿字＋绿色光点）
	var heal := float(hero["hp_max"]) * lq_heal()
	hero["hp"] = minf(float(hero["hp_max"]), float(hero["hp"]) + heal)
	_push_float(hero_pos.x - 30.0, hero_pos.y - 60.0, "回春 +" + str(int(heal)), Color(0.60, 0.94, 0.66), true)
	for i in 5:
		_motes.append({"x": hero_pos.x + randf_range(-30.0, 30.0), "y": hero_pos.y + randf_range(-4.0, 24.0), "t": 0.0})
	# 中毒：最近的敌人 ＋ 几率再扩散给身边的几只
	var n := lq_spread()
	var done := 0
	var from := hero_pos
	var cur := _nearest_except(hero_pos, [])
	while not cur.is_empty() and done < n:
		_add_dot(cur, lq_poison_mul(), lq_poison_dur(), DMG_WOOD)
		_push_float(float(cur["x"]), float(cur["y"]) - 34.0, "中毒", Color(0.62, 0.90, 0.58))
		_bursts.append({"x": float(cur["x"]), "y": float(cur["y"]) - 12.0, "t": 0.0,
			"col": Color(0.56, 0.88, 0.52), "scale": 1.1})
		_thorn_lines.append({"from": from, "to": Vector2(float(cur["x"]), float(cur["y"])), "t": 0.0,
			"col": Color(0.60, 0.92, 0.56)})
		from = Vector2(float(cur["x"]), float(cur["y"]))
		done += 1
		cur = _nearest_except(from, [])
	Audio.sfx("bell", -8.0, 1.1)

# ---- 季沧海 ----
func jc_dmg_mul() -> float:
	# v4q 调伤害：0.70 → 0.60（无内力消耗、每 3 秒一发还带传火，收一点更稳）
	return 0.60 * (1.0 + 0.25 * float(partners["jicanghai"]["dmg_lv"])) * p_star_mul("jicanghai")

func jc_spread() -> int:
	return 1 + int(partners["jicanghai"]["spread_lv"])          # 传火：多引燃几名

func jc_burn_mul() -> float:
	return 0.12 * float(partners["jicanghai"]["burn_lv"])        # 灼烧：每秒额外火伤

func jc_interval() -> float:
	return maxf(1.2, 3.0 - 0.4 * float(partners["jicanghai"]["sec_lv"])) / p_star_mul("jicanghai")

func _cast_fire() -> void:
	var tg := _nearest()
	if tg.is_empty():
		return
	var base := float(hero["atk"]) * (1.0 + float(hero["dmg_pct"])) * jc_dmg_mul()
	var dm := _apply_dmg(tg, base, DMG_FIRE)
	tg["flash"] = 0.14
	_push_float(float(tg["x"]), float(tg["y"]) - 34.0, "怒火 " + str(int(dm)), Color(1.0, 0.66, 0.34), true)
	_bursts.append({"x": float(tg["x"]), "y": float(tg["y"]) - 12.0, "t": 0.0,
		"col": Color(1.0, 0.60, 0.26), "scale": 1.3})
	if jc_burn_mul() > 0.0:
		_add_dot(tg, jc_burn_mul(), 4.0, DMG_FIRE)
	if float(tg["hp"]) <= 0.0:
		_kill_foe(tg)
	# **传火**：把火引到它身边范围内的另一名敌人（升级可以多引几名）
	var tp := Vector2(float(tg["x"]), float(tg["y"]))
	var hit: Array = [tg]
	for i in jc_spread():
		var nx := _nearest_except(tp, hit)
		if nx.is_empty():
			break
		if tp.distance_to(Vector2(float(nx["x"]), float(nx["y"]))) > 150.0:
			break
		var d2 := _apply_dmg(nx, base * 0.7, DMG_FIRE)     # 传过去那一下略弱
		nx["flash"] = 0.12
		_push_float(float(nx["x"]), float(nx["y"]) - 34.0, "传火 " + str(int(d2)), Color(1.0, 0.74, 0.40))
		_fire_lines.append({"from": tp, "to": Vector2(float(nx["x"]), float(nx["y"])), "t": 0.0})
		_bursts.append({"x": float(nx["x"]), "y": float(nx["y"]) - 12.0, "t": 0.0,
			"col": Color(1.0, 0.62, 0.28), "scale": 1.0})
		hit.append(nx)
		if float(nx["hp"]) <= 0.0:
			_kill_foe(nx)
	Audio.sfx("slash_light", -9.0, 0.9)

# 挂一层持续伤害（毒/灼烧都用这个；每秒跳一次）
func _add_dot(f: Dictionary, mul: float, dur: float, dtype: String) -> void:
	if mul <= 0.0:
		return
	var dots: Array = f.get("dot", [])
	dots.append({"mul": mul, "t": dur, "tick": 1.0, "dtype": dtype})
	f["dot"] = dots

# 画火线（传火）
func _draw_fire_lines(shk: Vector2) -> void:
	for l_v in _fire_lines:
		var l: Dictionary = l_v
		var la := 1.0 - float(l["t"]) / 0.30
		var a3: Vector2 = l["from"]
		var b3: Vector2 = l["to"]
		draw_line(a3 + shk, b3 + shk, Color(1.0, 0.62, 0.24, la), 5.0)
		draw_line(a3 + shk, b3 + shk, Color(1.0, 0.88, 0.52, la * 0.8), 2.0)
# ============================================================
# 张道陵·天雷道术（v4j）：范围金系伤害 ＋ 几率麻痹 ＋ 几率多重施法
#   "两个人身位"≈ 110 像素半径（简笔小人一人约 50 像素宽）；每级 +22。
# ============================================================
var _bolts: Array = []              # 雷电特效：{x, y, t, segs}

func tl_radius() -> float:
	return 110.0 + 22.0 * float(partners["zhangdaoling"]["range_lv"])

func tl_dmg_mul() -> float:
	return 1.60 * (1.0 + 0.25 * float(partners["zhangdaoling"]["dmg_lv"])) * p_star_mul("zhangdaoling")

func tl_para_chance() -> float:
	return 0.20 + 0.10 * float(partners["zhangdaoling"]["para_lv"])

func tl_para_dur() -> float:
	return 1.0 + 1.0 * float(partners["zhangdaoling"]["paradur_lv"])

func tl_multi_chance() -> float:
	return 0.25 + 0.15 * float(partners["zhangdaoling"]["multi_lv"])

# 多重施法那一下：**不同伤害比例**，但也是金系
func tl_multi_mul() -> float:
	return 0.60 * (1.0 + 0.25 * float(partners["zhangdaoling"]["multidmg_lv"])) * p_star_mul("zhangdaoling")

func tl_mp() -> float:
	var p: Dictionary = partners["zhangdaoling"]
	var ups := float(p.get("dmg_lv", 0)) + float(p.get("range_lv", 0)) + float(p.get("para_lv", 0))
	ups += float(p.get("paradur_lv", 0)) + float(p.get("multi_lv", 0)) + float(p.get("multidmg_lv", 0))
	return maxf(120.0, 300.0 + 30.0 * ups - 25.0 * float(p.get("cost_lv", 0)))

func tl_cd() -> float:
	return maxf(3.0, 10.0 - 1.5 * float(partners["zhangdaoling"].get("cd_lv", 0))) / p_star_mul("zhangdaoling")

# 一次性法术的统一入口（加新伙伴只需在这里加一条）
func _cast_partner(id: String) -> void:
	match id:
		"zhangdaoling":
			_cast_tianlei(1.0, "天雷")
			if randf() < tl_multi_chance():
				_cast_tianlei(tl_multi_mul(), "多重天雷")     # 不同伤害比例，也是金系
		"liuqingqing":
			_cast_spring()
		"baipopo":
			_cast_heal()
		"shenqingluo":
			_cast_vine()
		"duniangzi":
			_cast_poison_all()
		"xuanjizi":
			_cast_timestop()
		"cuisanniang":
			_summon_dragon()
		# v15c/v15w 新增 18 位一次性技能
		# ⚠ 这 6 个 v15c 的分支曾经被一次"删坏行"的批量清理连带删掉过（函数还在、没人调）——
		#   所以这里有"函数定义了但技能不触发"的历史坑，改动时留意。
		"tietouseng":
			_cast_tietou()
		"bingshusheng":
			_cast_keshui()
		"yaopozi":
			_cast_jinzhen()
		"huogong":
			_cast_sanmei()
		"qinchi":
			_cast_luanshen()
		"baiqihouren":
			_cast_shashen()
		"xinglin":
			_cast_huichun()
		"qiaofu":
			_cast_pichai()
		"pozhen":
			_cast_pojia()
		"busheren":
			_cast_sheyao()
		"gengfu":
			_cast_baogeng()
		"gushi":
			_cast_gudu()
		"kuaidaoshou":
			_cast_kuaidao()
		"chuangong":
			_cast_chenggao()
		"tiemianseng":
			_cast_tiemian()
		"lengyueniang":
			_cast_hanshuang()
		"guijianchou":
			_cast_zhenshou()
		"zuitaisui":
			_cast_jiuqi()
		_:
			pass

# ============================================================
# v15c 新增 12 位的实现（机制尽量复用已有那几套）
# ============================================================
# ① 铁头功：一头撞向最近敌人（物理；自己血越少撞得越狠）
func _cast_tietou() -> void:
	var f := _nearest()
	if f.is_empty():
		return
	var hp_r := clampf(float(hero["hp"]) / maxf(1.0, float(hero["hp_max"])), 0.0, 1.0)
	var mul := 1.4 + (1.0 - hp_r) * 1.2
	var dmg := float(hero["atk"]) * mul * (1.0 + 0.25 * float(partners["tietouseng"].get("dmg_lv", 0)))
	var d := _apply_dmg(f, dmg, DMG_PHYS)
	_push_float(float(f["x"]), float(f["y"]) - 30.0, "铁头 " + str(int(d)), Color(0.90, 0.86, 0.72), true)
	_bursts.append({"x": float(f["x"]), "y": float(f["y"]) - 14.0, "t": 0.0, "col": Color(0.86, 0.82, 0.70), "scale": 1.2})
	Audio.sfx("hit_heavy", -6.0)
	if float(f["hp"]) <= 0.0:
		_kill_foe(f)

# ② 咳血：给最近敌人挂木系持续伤害（复用 _add_dot）
func _cast_keshui() -> void:
	var f := _nearest()
	if f.is_empty():
		return
	var mul := (0.30 + 0.06 * float(partners["bingshusheng"].get("dmg_lv", 0))) * p_star_mul("bingshusheng")
	var dur := 4.0 + 1.0 * float(partners["bingshusheng"].get("dur_lv", 0))
	_add_dot(f, mul, dur, DMG_WOOD)
	_push_float(float(f["x"]), float(f["y"]) - 28.0, "咳血", Color(0.62, 0.90, 0.44), true)
	Audio.sfx("skill", -8.0)

# ③ 金针：回血 + 定身最近敌人
func _cast_jinzhen() -> void:
	var heal := float(hero["hp_max"]) * (0.10 + 0.03 * float(partners["yaopozi"].get("heal_lv", 0))) * p_star_mul("yaopozi")
	hero["hp"] = minf(float(hero["hp_max"]), float(hero["hp"]) + heal)
	_push_float(hero_pos.x, hero_pos.y - 86.0, "金针 +" + str(int(heal)), Color(0.66, 0.94, 0.70), true)
	var f := _nearest()
	if not f.is_empty():
		f["para"] = maxf(float(f.get("para", 0.0)), 1.5)
		_push_float(float(f["x"]), float(f["y"]) - 30.0, "定身 1.5s", Color(0.78, 0.86, 0.98))
	Audio.sfx("levelup", -8.0)

# ④ 三昧真火：点燃最近 2 名敌人（火系持续）
func _cast_sanmei() -> void:
	var n := 2 + int(partners["huogong"].get("tgt_lv", 0))
	var mul := (0.26 + 0.05 * float(partners["huogong"].get("dmg_lv", 0))) * p_star_mul("huogong")
	var dur := 5.0 + 1.0 * float(partners["huogong"].get("dur_lv", 0))
	var hit := 0
	for f_v in foes:
		var f: Dictionary = f_v
		if hit >= n:
			break
		if float(f.get("dying", 0.0)) > 0.0 or float(f["hp"]) <= 0.0:
			continue
		_add_dot(f, mul, dur, DMG_FIRE)
		_push_float(float(f["x"]), float(f["y"]) - 28.0, "三昧真火", Color(1.0, 0.62, 0.28), true)
		hit += 1
	Audio.sfx("skill", -7.0)

# ⑤ 乱神曲：全场定身
func _cast_luanshen() -> void:
	var dur := 2.0 + 0.4 * float(partners["qinchi"].get("dur_lv", 0))
	var n := 0
	for f_v in foes:
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0 or bool(f.get("still", false)):
			continue
		f["para"] = maxf(float(f.get("para", 0.0)), dur)
		n += 1
	_push_float(hero_pos.x, hero_pos.y - 104.0, "乱神曲！定身 " + str(n) + " 名", Color(0.90, 0.86, 1.0), true)
	Audio.sfx("tension", -5.0)

# ⑥ 杀神：真实伤害，按目标已损失气血算（越残越致命）
func _cast_shashen() -> void:
	var f := _nearest()
	if f.is_empty():
		return
	var lost := maxf(0.0, float(f["hp_max"]) - float(f["hp"]))
	var mul := (0.18 + 0.05 * float(partners["baiqihouren"].get("dmg_lv", 0))) * p_star_mul("baiqihouren")
	var dmg := maxf(float(hero["atk"]) * 0.8, lost * mul)
	var d := _apply_dmg(f, dmg, DMG_TRUE)
	_push_float(float(f["x"]), float(f["y"]) - 34.0, "杀神 " + str(int(d)), Color(0.94, 0.42, 0.36), true)
	_bursts.append({"x": float(f["x"]), "y": float(f["y"]) - 12.0, "t": 0.0, "col": Color(0.90, 0.34, 0.30), "scale": 1.7})
	Audio.sfx("hit_heavy", -4.0)
	if float(f["hp"]) <= 0.0:
		_kill_foe(f)

# ⑦ 金甲校尉 / 大内供奉 的盾（先扣盾再扣血；走 hero 上那套 shield）
func _cast_extra_shield(id: String) -> void:
	var pct := 0.0
	var elem := DMG_EARTH
	var tag := ""
	if id == "jinjiaxianwei":
		pct = 0.12 + 0.04 * float(partners[id].get("cut_lv", 0))
		tag = "拒马"
	else:
		pct = 0.15 + 0.05 * float(partners[id].get("shield_lv", 0))
		elem = DMG_METAL
		tag = "罡气"
	var sv := float(hero["hp_max"]) * pct * p_star_mul(id)
	hero["shield_max"] = float(hero.get("shield_max", 0.0)) + sv
	hero["shield"] = float(hero.get("shield", 0.0)) + sv
	hero["shield_elem"] = elem
	_push_float(hero_pos.x, hero_pos.y - 92.0, tag + " +" + str(int(sv)), Color(0.86, 0.80, 0.52), true)
	_bursts.append({"x": hero_pos.x, "y": hero_pos.y - 10.0, "t": 0.0, "col": Color(0.80, 0.72, 0.44), "scale": 1.5})
	Audio.sfx("equip", -6.0)

# ============================================================
# v15w 新增 12 位的实现（每人复用一套已有机制）
# ============================================================
# ① 回春针：小治疗 ＋ 攻击吸血（给 hero 挂吸血窗口）
func _cast_huichun() -> void:
	var heal := float(hero["hp_max"]) * 0.06 * p_star_mul("xinglin")
	hero["hp"] = minf(float(hero["hp_max"]), float(hero["hp"]) + heal)
	hero["lifesteal_t"] = 6.0 + 1.0 * float(partners["xinglin"].get("dur_lv", 0))
	hero["lifesteal"] = 0.04 + 0.01 * float(partners["xinglin"].get("heal_lv", 0))
	_push_float(hero_pos.x, hero_pos.y - 86.0, "回春 +" + str(int(heal)) + "　吸血 6s", Color(0.70, 0.94, 0.72), true)
	Audio.sfx("levelup", -8.0)

# ② 劈柴：物理重击 ＋ 击退
func _cast_pichai() -> void:
	var f := _nearest()
	if f.is_empty():
		return
	var base := float(hero["atk"]) * (1.6 + 0.25 * float(partners["qiaofu"].get("dmg_lv", 0))) * (1.0 + float(hero["dmg_pct"]))
	var dm := _apply_dmg(f, base, DMG_PHYS)
	f["kb"] = 26.0
	_push_float(float(f["x"]), float(f["y"]) - 30.0, "劈柴 " + str(int(dm)), Color(0.90, 0.82, 0.66), true)
	Audio.sfx("hit_heavy", -6.0)
	if float(f["hp"]) <= 0.0:
		_kill_foe(f)

# ③ 破甲：物理伤害 ＋ 目标护甲 −20%（5 秒）
func _cast_pojia() -> void:
	var f := _nearest()
	if f.is_empty():
		return
	var base := float(hero["atk"]) * (1.2 + 0.2 * float(partners["pozhen"].get("dmg_lv", 0))) * (1.0 + float(hero["dmg_pct"]))
	var dm := _apply_dmg(f, base, DMG_PHYS)
	f["armor_break_t"] = 5.0
	_push_float(float(f["x"]), float(f["y"]) - 30.0, "破甲 " + str(int(dm)), Color(0.96, 0.72, 0.42), true)
	Audio.sfx("hit_slash", -8.0)
	if float(f["hp"]) <= 0.0:
		_kill_foe(f)

# ④ 蛇咬：木系伤害；目标中毒则翻倍
func _cast_sheyao() -> void:
	var f := _nearest()
	if f.is_empty():
		return
	var mul := 1.1 + 0.2 * float(partners["busheren"].get("dmg_lv", 0))
	if float(f.get("dot_t", 0.0)) > 0.0:
		mul *= 2.0                        # 中毒目标翻倍
	var dm := _apply_dmg(f, float(hero["atk"]) * mul * (1.0 + float(hero["dmg_pct"])), DMG_WOOD)
	_push_float(float(f["x"]), float(f["y"]) - 28.0, "蛇咬 " + str(int(dm)), Color(0.60, 0.92, 0.48), true)
	Audio.sfx("skill", -8.0)
	if float(f["hp"]) <= 0.0:
		_kill_foe(f)

# ⑤ 报更：最近 2 名敌人致盲
func _cast_baogeng() -> void:
	var dur := 5.0 + 1.0 * float(partners["gengfu"].get("dur_lv", 0))
	var n := 0
	for f_v in foes:
		var f: Dictionary = f_v
		if n >= 2:
			break
		if float(f.get("dying", 0.0)) > 0.0 or float(f["hp"]) <= 0.0:
			continue
		f["blind_t"] = dur
		n += 1
	_push_float(hero_pos.x, hero_pos.y - 96.0, "报更：致盲 " + str(n) + " 名", Color(0.86, 0.86, 0.66), true)
	Audio.sfx("bell", -8.0)

# ⑥ 蛊毒：最近 2 名挂毒
func _cast_gudu() -> void:
	var mul := (0.34 + 0.06 * float(partners["gushi"].get("dmg_lv", 0))) * p_star_mul("gushi")
	var dur := 5.0 + 1.0 * float(partners["gushi"].get("dur_lv", 0))
	var n := 0
	for f_v in foes:
		var f: Dictionary = f_v
		if n >= 2:
			break
		if float(f.get("dying", 0.0)) > 0.0 or float(f["hp"]) <= 0.0:
			continue
		_add_dot(f, mul, dur, DMG_WOOD)
		_push_float(float(f["x"]), float(f["y"]) - 28.0, "蛊毒", Color(0.56, 0.86, 0.42), true)
		n += 1
	Audio.sfx("skill", -8.0)

# ⑦ 快刀：连砍三刀
func _cast_kuaidao() -> void:
	var p: Dictionary = partners["kuaidao"]
	for i in 3:
		var f := _nearest()
		if f.is_empty():
			break
		var base := float(hero["atk"]) * (0.55 + 0.08 * float(partners["kuaidaoshou"].get("dmg_lv", 0))) \
			* (1.0 + float(hero["dmg_pct"]))
		var dm := _apply_dmg(f, base, DMG_PHYS)
		_push_float(float(f["x"]), float(f["y"]) - 22.0 - float(i) * 12.0, str(int(dm)), Color(0.94, 0.90, 0.74))
		if float(f["hp"]) <= 0.0:
			_kill_foe(f)
	Audio.sfx("hit_slash", -9.0)

# ⑧ 撑篙：水系伤害 ＋ 推开
func _cast_chenggao() -> void:
	var f := _nearest()
	if f.is_empty():
		return
	var base := float(hero["atk"]) * (1.3 + 0.2 * float(partners["chuangong"].get("dmg_lv", 0))) * (1.0 + float(hero["dmg_pct"]))
	var dm := _apply_dmg(f, base, DMG_WATER)
	f["kb"] = 34.0
	_push_float(float(f["x"]), float(f["y"]) - 30.0, "撑篙 " + str(int(dm)), Color(0.58, 0.84, 0.96), true)
	Audio.sfx("hit_heavy", -7.0)
	if float(f["hp"]) <= 0.0:
		_kill_foe(f)

# ⑨ 铁面：受伤 −25%（6 秒）＋ 减免量回血
func _cast_tiemian() -> void:
	hero["dr_t"] = 6.0 + 1.0 * float(partners["tiemianseng"].get("dur_lv", 0))
	hero["dr"] = 0.22 + 0.03 * float(partners["tiemianseng"].get("cut_lv", 0))
	_push_float(hero_pos.x, hero_pos.y - 90.0, "铁面：受伤 −" + str(int(float(hero["dr"]) * 100.0)) + "%", Color(0.88, 0.80, 0.62), true)
	Audio.sfx("equip", -6.0)

# ⑩ 寒霜：最近 3 名受水系伤害 ＋ 减速
func _cast_hanshuang() -> void:
	var mul := (0.8 + 0.12 * float(partners["lengyueniang"].get("dmg_lv", 0))) * p_star_mul("lengyueniang")
	var sdur := 6.0 + 1.0 * float(partners["lengyueniang"].get("dur_lv", 0))
	var n := 0
	for f_v in foes:
		var f: Dictionary = f_v
		if n >= 3:
			break
		if float(f.get("dying", 0.0)) > 0.0 or float(f["hp"]) <= 0.0:
			continue
		var dm := _apply_dmg(f, float(hero["atk"]) * mul * (1.0 + float(hero["dmg_pct"])), DMG_WATER)
		f["slow_t"] = sdur
		_push_float(float(f["x"]), float(f["y"]) - 28.0, "寒霜 " + str(int(dm)), Color(0.68, 0.88, 1.0), true)
		n += 1
		if float(f["hp"]) <= 0.0:
			_kill_foe(f)
	Audio.sfx("skill", -7.0)

# ⑪ 斩首：打血量最低的；血越少越痛；击杀则冷却减半
func _cast_zhenshou() -> void:
	var best: Dictionary = {}
	var bh := 1.0e12
	for f_v in foes:
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0 or float(f["hp"]) <= 0.0:
			continue
		if float(f["hp"]) < bh:
			bh = float(f["hp"])
			best = f
	if best.is_empty():
		return
	var lost := maxf(0.0, float(best["hp_max"]) - float(best["hp"]))
	var mul := (0.22 + 0.05 * float(partners["guijianchou"].get("dmg_lv", 0))) * p_star_mul("guijianchou")
	var dmg := maxf(float(hero["atk"]) * 1.2, lost * mul)
	var dm := _apply_dmg(best, dmg, DMG_TRUE)
	_push_float(float(best["x"]), float(best["y"]) - 34.0, "斩首 " + str(int(dm)), Color(0.94, 0.36, 0.34), true)
	_bursts.append({"x": float(best["x"]), "y": float(best["y"]) - 12.0, "t": 0.0, "col": Color(0.90, 0.30, 0.28), "scale": 1.8})
	Audio.sfx("hit_heavy", -4.0)
	if float(best["hp"]) <= 0.0:
		_kill_foe(best)
		var p2: Dictionary = partners["guijianchou"]
		p2["cd"] = float(p2["cd"]) * 0.5      # 击杀 → 冷却减半
		_push_float(float(best["x"]), float(best["y"]) - 60.0, "斩首成功·冷却减半", Color(1.0, 0.72, 0.40), true)

# ⑫ 酒气：8 秒攻击 +25% ＋ 命中回内力
func _cast_jiuqi() -> void:
	hero["drunk_t"] = 8.0
	hero["drunk_atk"] = 0.22 + 0.03 * float(partners["zuitaisui"].get("dmg_lv", 0))
	_push_float(hero_pos.x, hero_pos.y - 90.0, "酒气：攻击 +" + str(int(float(hero["drunk_atk"]) * 100.0)) + "%　命中回内力", Color(1.0, 0.84, 0.46), true)
	Audio.sfx("levelup", -7.0)

# 季沧海：每 3 秒（可减）自动烧一次，不吃内力
# ---- v14b 新队员的一次性技能 ----
# 白婆婆：续命（回血；自己残血翻倍）
func _cast_heal() -> void:
	var ratio := (0.12 + 0.02 * float(partners["baipopo"].get("heal_lv", 0))) * p_star_mul("baipopo")
	if float(hero["hp"]) / maxf(1.0, float(hero["hp_max"])) < 0.40:
		ratio *= 2.0
	var heal := float(hero["hp_max"]) * ratio
	hero["hp"] = minf(float(hero["hp_max"]), float(hero["hp"]) + heal)
	_push_float(hero_pos.x, hero_pos.y - 86.0, "续命 +" + str(int(heal)), Color(0.62, 0.94, 0.72), true)
	_bursts.append({"x": hero_pos.x, "y": hero_pos.y - 10.0, "t": 0.0, "col": Color(0.60, 0.92, 0.70), "scale": 1.5})
	Audio.sfx("levelup", -8.0)

# 沈青萝：藤缚（定住最近 3 名 + 木系伤害）
func _cast_vine() -> void:
	var n := 3 + int(partners["shenqingluo"].get("tgt_lv", 0))
	var dmg := float(hero["atk"]) * (0.8 + 0.15 * float(partners["shenqingluo"].get("dmg_lv", 0))) * p_star_mul("shenqingluo")
	var sorted: Array = []
	for f_v in foes:
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0 or float(f["hp"]) <= 0.0 or bool(f.get("still", false)):
			continue
		sorted.append(f)
	sorted.sort_custom(func(a, b): return Vector2(float(a["x"]), float(a["y"])).distance_to(hero_pos) \
		< Vector2(float(b["x"]), float(b["y"])).distance_to(hero_pos))
	var hit := 0
	for f_v in sorted:
		if hit >= n:
			break
		var f: Dictionary = f_v
		f["para"] = maxf(float(f.get("para", 0.0)), 2.0)
		var d := _apply_dmg(f, dmg, DMG_WOOD)
		_push_float(float(f["x"]), float(f["y"]) - 30.0, "藤缚 " + str(int(d)), Color(0.56, 0.86, 0.46), true)
		if float(f["hp"]) <= 0.0:
			_kill_foe(f)
		hit += 1
	Audio.sfx("skill", -6.0)

# 毒娘子：万毒（全场挂毒）
func _cast_poison_all() -> void:
	var dmg := float(hero["atk"]) * (0.25 + 0.06 * float(partners["duniangzi"].get("dmg_lv", 0))) * p_star_mul("duniangzi")
	var dur := 6.0 + 1.0 * float(partners["duniangzi"].get("dot_lv", 0))
	var n := 0
	for f_v in foes:
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0 or float(f["hp"]) <= 0.0:
			continue
		var dots: Array = f.get("dot", [])
		dots.append({"t": dur, "tick": 1.0, "dmg": dmg, "dtype": DMG_WOOD})
		f["dot"] = dots
		f["poison"] = 1.0
		n += 1
	_push_float(hero_pos.x, hero_pos.y - 96.0, "万毒 " + str(n) + " 名", Color(0.62, 0.90, 0.44), true)
	Audio.sfx("skill", -6.0)

# 玄机子：时间停止（全场定身 3 秒 + 自己攻速翻倍 3 秒）
func _cast_timestop() -> void:
	var dur := (3.0 + 0.5 * float(partners["xuanjizi"].get("dur_lv", 0))) * p_star_mul("xuanjizi")
	_p_aspd = maxf(_p_aspd, dur)            # 攻速翻倍（战场自己的临时通道）
	for f_v in foes:
		var f: Dictionary = f_v
		if not bool(f.get("still", false)) and float(f.get("dying", 0.0)) <= 0.0:
			f["para"] = maxf(float(f.get("para", 0.0)), dur)
	_p_aspd = maxf(_p_aspd, dur)          # 攻速翻倍（战场自己的临时通道）
	_push_float(hero_pos.x, hero_pos.y - 110.0, "时间停止！", Color(0.90, 0.86, 1.0), true)
	Audio.sfx("drum", -4.0)

# v14b 雷小七「连环腿」：每 4 秒对最近敌人连踢两下（两次独立判定）
func _update_leixiaoqi(delta: float) -> void:
	var p: Dictionary = partners["leixiaoqi"]
	if not bool(p["owned"]):
		return
	p["cd"] = maxf(0.0, float(p["cd"]) - delta)
	if float(p["cd"]) > 0.0:
		return
	p["cd"] = maxf(2.0, 4.0 - 0.3 * float(p.get("sec_lv", 0)))
	for i in 2:
		var tg := _nearest()
		if tg.is_empty():
			return
		var base := float(hero["atk"]) * (0.55 + 0.10 * float(p.get("dmg_lv", 0))) * (1.0 + float(hero["dmg_pct"]))
		var dm := _apply_dmg(tg, base, DMG_PHYS)
		tg["flash"] = 0.16
		tg["kb"] = 10.0
		_push_float(float(tg["x"]), float(tg["y"]) - 24.0, str(int(dm)), Color(0.92, 0.86, 0.70))
		if float(tg["hp"]) <= 0.0:
			_kill_foe(tg)
	Audio.sfx("hit_slash", -10.0)

# v14b 西门烈「烈焰刀」：每 6 秒劈出一道火刃，横扫最近敌人身前 140 像素
func _update_ximenlie(delta: float) -> void:
	var p: Dictionary = partners["ximenlie"]
	if not bool(p["owned"]):
		return
	p["cd"] = maxf(0.0, float(p["cd"]) - delta)
	if float(p["cd"]) > 0.0:
		return
	p["cd"] = maxf(2.5, 6.0 - 0.4 * float(p.get("sec_lv", 0)))
	var tg := _nearest()
	if tg.is_empty():
		return
	var center := Vector2(float(tg["x"]), float(tg["y"]))
	var base := float(hero["atk"]) * (1.1 + 0.18 * float(p.get("dmg_lv", 0))) * (1.0 + float(hero["dmg_pct"]))
	for f_v in foes.duplicate():
		var f: Dictionary = f_v
		if float(f.get("dying", 0.0)) > 0.0 or float(f["hp"]) <= 0.0:
			continue
		if center.distance_to(Vector2(float(f["x"]), float(f["y"]))) <= 140.0:
			var dm := _apply_dmg(f, base, DMG_FIRE)
			f["flash"] = 0.20
			_push_float(float(f["x"]), float(f["y"]) - 28.0, "烈焰 " + str(int(dm)), Color(1.0, 0.58, 0.30), true)
			if float(f["hp"]) <= 0.0:
				_kill_foe(f)
	_bursts.append({"x": center.x, "y": center.y, "t": 0.0, "col": Color(1.0, 0.56, 0.28), "scale": 1.5})
	Audio.sfx("hit_heavy", -8.0)

func _update_jicanghai(delta: float) -> void:
	var p: Dictionary = partners["jicanghai"]
	if not bool(p["owned"]):
		return
	p["cd"] = maxf(0.0, float(p["cd"]) - delta)
	if float(p["cd"]) <= 0.0:
		p["cd"] = jc_interval()
		_cast_fire()

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
	return maxf(2.0, 8.0 - 1.0 * float(partners["suqingluan"]["sec_lv"])) / p_star_mul("suqingluan")

func dg_dmg_mul() -> float:
	return 0.80 * (1.0 + 0.25 * float(partners["suqingluan"]["dmg_lv"])) * p_star_mul("suqingluan")

func dg_pierce() -> int:
	return int(partners["suqingluan"]["pierce_lv"])

func dg_bounce() -> int:
	return int(partners["suqingluan"]["bounce_lv"])

func dg_multi() -> int:
	return 1 + int(partners["suqingluan"]["multi_lv"])

# 弹射伤害：弹射那一下单算（跟飞匕伤害分开）
func dg_bounce_mul() -> float:
	return 0.60 * (1.0 + 0.25 * float(partners["suqingluan"]["bdmg_lv"])) * p_star_mul("suqingluan")

# 多重伤害：多出来的那几枚匕首单算（+多重伤害 = 多重的整体伤害增加）
func dg_multi_mul() -> float:
	# v4q 调伤害：多重 0.80 → 0.70（数量已占优，单枚略低）
	return 0.70 * (1.0 + 0.25 * float(partners["suqingluan"]["mdmg_lv"])) * p_star_mul("suqingluan")

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
	# v5a 主属性：回蓝吃 hero["mp_regen"]（悟性给的），缺省才用常量
	hero["mp"] = minf(float(hero["mp_max"]),
		float(hero["mp"]) + float(hero.get("mp_regen", MP_REGEN)) * delta)
	# 臂力的"生命恢复"：每秒回一点血
	var hpr := float(hero.get("hp_regen", 0.0))
	if hpr > 0.0:
		hero["hp"] = minf(float(hero["hp_max"]), float(hero["hp"]) + hpr * delta)
	# v14r：剧毒（毒牙蟒 / 血手判官那一路）——每秒跳一次木系伤害，无视护甲
	if float(hero.get("poison", 0.0)) > 0.0:
		hero["poison"] = maxf(0.0, float(hero.get("poison", 0.0)) - delta)
		hero["poison_tick"] = float(hero.get("poison_tick", 1.0)) - delta
		if float(hero["poison_tick"]) <= 0.0:
			hero["poison_tick"] = 1.0
			var pdm := maxf(1.0, hero_in_dmg(float(hero["hp_max"]) * 0.012, DMG_WOOD))
			hero["hp"] = float(hero["hp"]) - pdm
			_push_float(hero_pos.x, hero_pos.y - 70.0, "毒 " + str(int(pdm)), Color(0.62, 0.90, 0.44))
	for id in partners.keys():
		var p: Dictionary = partners[id]
		if not bool(p["owned"]):
			continue
		# v14s：**开局出战的那位是主角本人**——他不作为队友出手，技能改由 hero_has_skill 驱动
		if str(id) == hero_mate:
			continue
		# 只处理"内力/持续/冷却"型的伙伴技能；苏青鸾那种"每隔 N 秒出一枚"走 _update_daggers
		if float((PARTNER_INFO[id] as Dictionary)["mp0"]) <= 0.0:
			continue
		var is_nuke: bool = float((PARTNER_INFO[id] as Dictionary)["dur0"]) <= 0.0
		if str(id) == "fadu":
			# 怒目金刚：套盾型（有持续时间，但效果是"给自己挂一层盾"）
			if float(p["cd"]) <= 0.0 and float(hero["mp"]) >= p_mp("fadu"):
				hero["mp"] = float(hero["mp"]) - p_mp("fadu")
				p["cd"] = fd_cd()
				_cast_shield()
			continue
		# v15c：另外两个套盾型（金甲校尉 / 大内供奉）—— 同一套写法，各自的盾值与冷却
		if str(id) == "jinjiaxianwei" or str(id) == "dagongfeng":
			var sc := p_cost_of(str(id))
			if float(p["cd"]) <= 0.0 and float(hero["mp"]) >= sc:
				hero["mp"] = float(hero["mp"]) - sc
				p["cd"] = p_cool_of(str(id))
				_cast_extra_shield(str(id))
			continue
		var cost := p_cost_of(str(id))
		var cool := p_cool_of(str(id))
		var dur2 := p_dur_of(str(id))
		if p_try_cast(str(id), p, cost, cool, dur2, delta):
			continue
	# v14s：出战主角的**专属技能**——同一套"内力够 + 不在冷却就放"，只是算在他自己头上
	if hero_mate != "" and partners.has(hero_mate) and bool((partners[hero_mate] as Dictionary)["owned"]):
		var hp2: Dictionary = partners[hero_mate]
		if float((PARTNER_INFO[hero_mate] as Dictionary)["mp0"]) > 0.0:
			var t := p_try_cast(hero_mate, hp2, p_cost_of(hero_mate), p_cool_of(hero_mate), p_dur_of(hero_mate), delta)
			if t and not bool(p_is_nuke(hero_mate)):
				hero_skill_t = 0.9                 # 冒个"你的技能"提示，跟队友那条分开
	# （"不吃内力"的那几位——苏青鸾飞匕/季沧海怒火/雷小七连环腿/西门烈焰刀——各自 update 里
	#   本来就按 owned 跑，出战主角照样生效；鹰眼/坚守/点金/铁壁是被动，也一直在。）
	if hero_skill_t > 0.0:
		hero_skill_t = maxf(0.0, hero_skill_t - delta)

# ============================================================
# v14o 伙伴星级：★1 起步，每星 ① 成长继承 +3%（外壳算）② 技能威力 +12% ③ 冷却 −5%
#   星数由外壳写进 partners[id]["star"]（存档页花银两升，永久）；这里只读。
# ============================================================
func p_star_mul(id: String) -> float:
	# ★ 与进化**乘算**（v15a）：★1＋无进化＝1.00；★5（+48%）且进化 2 档（+50%）＝2.22
	var st := 1.0 + 0.12 * float(maxi(0, int((partners[id] as Dictionary).get("star", 1)) - 1))
	var ev := 1.0 + 0.25 * float(maxi(0, int((partners[id] as Dictionary).get("evo", 0))))
	return st * ev

# ============================================================
# v14s 开局出战：出战的那位**替换主角**（外壳存档里设，跨局）
#   · hero_mate 记着他是谁；外层画主角时按他换长相
#   · 他不作为队友出手（_update_partners 里跳过），技能改由主角自己放
#   · 一次性 / 套盾 / 持续那几种的算法跟队友时**完全同一套**（抽成下面几个函数，两处共用）
# ============================================================
var hero_mate := ""
var hero_skill_t := 0.0           # "你的技能"提示的剩余秒数（给外层画 HUD 用）


# v14s：开局出战 —— 把"这一局的主角"换成那位伙伴（长相 / 手里的家伙 / 配色）
#   ⚠ 只管画：数值仍旧是主角那一套（成长并进继承，见外壳 _mate_restore）
const HERO_ART := {
	"chenshi": {"hair": "", "wpn": "", "col": Color(0.86, 0.84, 0.78)},
	"anying": {"hair": "hood", "wpn": "blade", "col": Color(0.56, 0.52, 0.62)},
	"fadu": {"hair": "crown", "wpn": "shield", "col": Color(0.82, 0.74, 0.56)},
	"duyanbiao": {"hair": "red", "wpn": "blade", "col": Color(0.80, 0.42, 0.36)},
	"kurong": {"hair": "topknot", "wpn": "staff", "col": Color(0.84, 0.72, 0.44)},
	"cuisanniang": {"hair": "long", "wpn": "fan", "col": Color(0.52, 0.74, 0.80)},
	"liuqingqing": {"hair": "long", "wpn": "staff", "col": Color(0.62, 0.84, 0.60)},
	"jicanghai": {"hair": "red", "wpn": "blade", "col": Color(0.90, 0.56, 0.30)},
	"zhangdaoling": {"hair": "crown", "wpn": "staff", "col": Color(0.88, 0.86, 0.60)},
	"suqingluan": {"hair": "long", "wpn": "blade", "col": Color(0.80, 0.88, 0.94)},
	"shigandang": {"hair": "topknot", "wpn": "shield", "col": Color(0.70, 0.64, 0.54)},
	"qianduoduo": {"hair": "topknot", "wpn": "fan", "col": Color(0.90, 0.80, 0.40)},
	"leixiaoqi": {"hair": "topknot", "wpn": "blade", "col": Color(0.72, 0.70, 0.62)},
	"baipopo": {"hair": "long", "wpn": "staff", "col": Color(0.84, 0.86, 0.88)},
	"tiexinwu": {"hair": "topknot", "wpn": "shield", "col": Color(0.62, 0.62, 0.68)},
	"shenqingluo": {"hair": "long", "wpn": "staff", "col": Color(0.56, 0.80, 0.56)},
	"yanwugui": {"hair": "topknot", "wpn": "bow", "col": Color(0.60, 0.64, 0.72)},
	"ximenlie": {"hair": "red", "wpn": "blade", "col": Color(0.86, 0.48, 0.32)},
	"duniangzi": {"hair": "long", "wpn": "fan", "col": Color(0.66, 0.56, 0.80)},
	"xuanjizi": {"hair": "crown", "wpn": "staff", "col": Color(0.72, 0.78, 0.90)},
}

func set_hero_mate(id: String) -> void:
	hero_mate = id
	var a: Dictionary = HERO_ART.get(id, {})
	hair = str(a.get("hair", ""))
	wpn = str(a.get("wpn", ""))
	if a.has("col"):
		hero["hero_col"] = a["col"]

func p_is_nuke(id: String) -> bool:
	return float((PARTNER_INFO[id] as Dictionary)["dur0"]) <= 0.0

func p_cost_of(id: String) -> float:
	if str(id) == "zhangdaoling":
		return tl_mp()
	return p_mp(id)

func p_cool_of(id: String) -> float:
	match str(id):
		"zhangdaoling":
			return tl_cd()
		"duyanbiao":
			return sb_cd()
		"kurong":
			return kr_cd()
	return p_cd(id)

func p_dur_of(id: String) -> float:
	match str(id):
		"duyanbiao":
			return sb_dur()
		"kurong":
			return kr_dur()
	return p_dur(id)

# 冷却好 + 内力够就放（成／不成返回 true/false）；fadu 的套盾也走这里
func p_try_cast(id: String, p: Dictionary, cost: float, cool: float, dur2: float, delta: float) -> bool:
	if str(id) == "fadu":
		if float(p["cd"]) <= 0.0 and float(hero["mp"]) >= cost:
			hero["mp"] = float(hero["mp"]) - cost
			p["cd"] = cool
			_cast_shield()
			return true
		return false
	p["active"] = maxf(0.0, float(p["active"]) - delta)
	p["cd"] = maxf(0.0, float(p["cd"]) - delta)
	if float(p["cd"]) > 0.0 or float(hero["mp"]) < cost:
		return false
	hero["mp"] = float(hero["mp"]) - cost
	p["cd"] = cool
	if p_is_nuke(id):
		_cast_partner(str(id))                    # 一次性法术：各按各的（天雷/回春…）
		return true
	p["active"] = dur2
	var info: Dictionary = PARTNER_INFO[id]
	_push_float(hero_pos.x + 60.0, hero_pos.y - 40.0, str(info["skill"]) + "！", Color(0.86, 0.74, 1.0), true)
	_bursts.append({"x": hero_pos.x, "y": hero_pos.y - 10.0, "t": 0.0,
		"col": Color(0.78, 0.62, 1.0), "scale": 1.6})
	Audio.sfx("skill", -6.0)
	return true


func p_active(id: String) -> bool:
	return float(partners[id]["active"]) > 0.0

func p_ratio(id: String) -> float:
	var d := p_dur(id)
	if d <= 0.0:
		return 0.0
	return clampf(float(partners[id]["active"]) / d, 0.0, 1.0)

# 杀气：独眼彪——持续期间每杀一只 → 攻击 +（1 + 0.5×层）
func sb_atk_add() -> float:
	return (1.0 + 0.5 * float(partners["duyanbiao"].get("atk_lv", 0))) * p_star_mul("duyanbiao")

func sb_cd() -> float:
	return maxf(6.0, 25.0 - 3.0 * float(partners["duyanbiao"].get("cd_lv", 0))) / p_star_mul("duyanbiao")

func sb_dur() -> float:
	return (5.0 + 2.0 * float(partners["duyanbiao"].get("dur_lv", 0))) * p_star_mul("duyanbiao")

# v4r（用户："不 跟原本内力的百分比增加好一点"）：纳气改成**按原本内力的百分比**涨
#   ——涨的是"开局那管内力"的百分比，所以不会滚雪球
var _mp_base := 300.0

func kr_mp_pct() -> float:
	return (0.03 + 0.03 * float(partners["kurong"].get("mp_lv", 0))) * p_star_mul("kurong")   # 3% → 12%

func kr_mp_add() -> float:
	return _mp_base * kr_mp_pct()

func kr_cd() -> float:
	return maxf(6.0, 25.0 - 3.0 * float(partners["kurong"].get("cd_lv", 0))) / p_star_mul("kurong")

func kr_dur() -> float:
	return (5.0 + 2.0 * float(partners["kurong"].get("dur_lv", 0))) * p_star_mul("kurong")

# 杀敌结算：三位"持续窗口内杀敌涨属性"的伙伴都在这里
func _on_kill_partner() -> void:
	# 肝：生命上限
	if p_active("anying"):
		var add := p_kill_hp()
		hero["hp_max"] = float(hero["hp_max"]) + add
		hero["hp"] = minf(float(hero["hp_max"]), float(hero["hp"]) + add)
		_push_float(hero_pos.x - 46.0, hero_pos.y - 52.0, "生命上限 +" + str(int(add)), Color(0.72, 0.92, 0.72))
		for i in 3:
			_motes.append({"x": hero_pos.x + randf_range(-26.0, 26.0), "y": hero_pos.y + randf_range(-6.0, 22.0), "t": 0.0})
	# 杀气：攻击
	if p_active("duyanbiao"):
		var a2 := sb_atk_add()
		hero["atk"] = float(hero["atk"]) + a2
		_push_float(hero_pos.x + 34.0, hero_pos.y - 58.0, "攻击 +" + str(snappedf(a2, 0.1)), Color(1.0, 0.52, 0.46))
		for i in 3:                                   # 赤红血点：从击杀处炸开再往上飘
			_blood.append({"x": hero_pos.x + randf_range(-30.0, 30.0), "y": hero_pos.y + randf_range(0.0, 26.0),
				"t": 0.0, "vx": randf_range(-40.0, 40.0)})
		_shake = maxf(_shake, 3.0)
	# 纳气：内力上限（并回同样多）
	if p_active("kurong"):
		var m2 := kr_mp_add()
		hero["mp_max"] = float(hero["mp_max"]) + m2
		hero["mp"] = minf(float(hero["mp_max"]), float(hero["mp"]) + m2)
		_push_float(hero_pos.x - 30.0, hero_pos.y - 74.0,
			"内力上限 +" + str(int(m2)) + "（" + str(int(kr_mp_pct() * 100.0)) + "%）", Color(0.96, 0.80, 0.42))
		for i in 3:                                   # 琥珀气丝：**从外往身上收**（方向跟"肝"相反，一眼分得开）
			_qi_threads.append({"x": hero_pos.x + randf_range(-46.0, 46.0), "y": hero_pos.y + randf_range(-58.0, 18.0),
				"t": 0.0, "px": hero_pos.x, "py": hero_pos.y})

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
var _blood: Array = []              # 杀气：赤红血点 {x,y,vx,t}
var _qi_threads: Array = []         # 纳气：琥珀气丝（从外往身上收）{x,y,px,py,t}
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
	# —— 杀气（独眼彪）：赤红杀气——三片旋转的赤刃 ＋ 脚下的红环 ——
	if p_active("duyanbiao"):
		var k3 := 0.45 + 0.55 * p_ratio("duyanbiao")
		for i in 3:
			var a4 := -_t * 4.2 + TAU * float(i) / 3.0
			var base2 := hp2 + Vector2(0, 8) + Vector2(cos(a4), sin(a4) * 0.5) * 44.0
			var d4 := Vector2(cos(a4 + 0.6), sin(a4 + 0.6) * 0.5)
			draw_line(base2 - d4 * 14.0, base2 + d4 * 14.0, Color(1.0, 0.32, 0.26, 0.85 * k3), 5.0)
		draw_arc(hp2 + Vector2(0, 18), 40.0, 0.0, TAU, 24, Color(0.94, 0.24, 0.20, 0.4 * k3), 3.0)
	# —— 纳气（枯荣）：琥珀色气丝往身上收 ＋ 脚下一圈暖环 ——
	if p_active("kurong"):
		var k4 := 0.45 + 0.55 * p_ratio("kurong")
		draw_arc(hp2 + Vector2(0, 20), 46.0, _t * 1.6, _t * 1.6 + 2.0, 18, Color(0.98, 0.78, 0.36, 0.6 * k4), 4.0)
		for i in 6:
			var a5 := TAU * float(i) / 6.0 + _t * 0.9
			var pp3 := hp2 + Vector2(cos(a5), sin(a5) * 0.55) * 56.0
			draw_line(pp3, pp3 + (hp2 - pp3).normalized() * 16.0, Color(1.0, 0.84, 0.44, 0.5 * k4), 3.0)
	# —— 杀气的血点 / 纳气的气丝（实体粒子）——
	for bl_v in _blood:
		var bl2: Dictionary = bl_v
		draw_circle(Vector2(float(bl2["x"]), float(bl2["y"])) + shk, 3.6, Color(0.98, 0.36, 0.30, 1.0 - float(bl2["t"]) / 0.7))
	for qt_v in _qi_threads:
		var qt2: Dictionary = qt_v
		var qp := Vector2(float(qt2["x"]), float(qt2["y"])) + shk
		draw_line(qp, qp + Vector2(0, 7.0), Color(1.0, 0.84, 0.44, 0.85 * (1.0 - float(qt2["t"]) / 0.7)), 3.0)
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
	# v15e：新增 12 位的**专属特效**（用户：所有角色的技能都是不同特效）
	#   每人一套配色 + 一套画法，跟老 20 位不撞。
	# ============================================================
	# ① 铁头僧：土黄——身周放射撞痕 ＋ 一圈撞环
	if p_active("tietouseng"):
		var kt := 0.45 + 0.55 * p_ratio("tietouseng")
		for i in 8:
			var at := TAU * float(i) / 8.0 + _t * 0.4
			var dt := Vector2(cos(at), sin(at) * 0.6)
			draw_line(hp2 + Vector2(0, 10) + dt * 16.0, hp2 + Vector2(0, 10) + dt * 30.0, Color(0.86, 0.74, 0.44, 0.75 * kt), 3.0)
		draw_arc(hp2 + Vector2(0, 12), 34.0, 0.0, TAU, 22, Color(0.82, 0.68, 0.36, 0.5 * kt), 3.0)
	# ② 病书生：青绿——往上飘的血点（咳出来的）
	if p_active("bingshusheng"):
		var kb := 0.45 + 0.55 * p_ratio("bingshusheng")
		for i in 5:
			var pb := float(i) / 5.0
			var yb := fmod(_t * 0.8 + pb, 1.0)
			var xb := hp2.x + sin((_t + pb * 6.0) * 2.0) * 18.0
			draw_circle(Vector2(xb, hp2.y - 20.0 - yb * 60.0), 3.2 * (1.0 - yb), Color(0.56, 0.88, 0.52, kb))
	# ③ 小乞儿：金色——脚边跳动的钱光
	if p_active("xiaoqier"):
		var kx := 0.45 + 0.55 * p_ratio("xiaoqier")
		for i in 4:
			var hx := fmod(_t * 1.3 + float(i) * 1.7, 1.0)
			var cx := hp2.x - 30.0 + float(i) * 20.0
			var cy := hp2.y + 16.0 - absf(sin(hx * PI)) * 26.0
			draw_circle(Vector2(cx, cy), 5.0, Color(1.0, 0.84, 0.34, 0.85 * kx))
			draw_arc(Vector2(cx, cy), 8.0, 0.0, TAU, 12, Color(1.0, 0.92, 0.60, 0.4 * kx), 1.5)
	# ④ 瘸腿老兵：暗红——残血时才亮起来的护命环（被动，没有 active）
	if bool((partners["laobing"] as Dictionary)["owned"]):
		var hp_r2 := float(hero["hp"]) / maxf(1.0, float(hero["hp_max"]))
		if hp_r2 < 0.5:
			var kl := (0.5 - hp_r2) * 2.4
			draw_arc(hp2 + Vector2(0, 14), 42.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(kl, 0.05, 1.0), 22, Color(0.90, 0.34, 0.30, 0.65), 4.0)
			draw_circle(hp2 + Vector2(0, -66), 4.0 + sin(_t * 7.0) * 1.5, Color(1.0, 0.52, 0.44, 0.8))
	# ⑤ 醉剑仙：粉白——歪斜的两道剑光绕着转
	if p_active("zuijianxian"):
		var kz := 0.45 + 0.55 * p_ratio("zuijianxian")
		for i in 2:
			var az := _t * 3.4 + PI * float(i) + sin(_t * 2.0) * 0.4
			var oz := hp2 + Vector2(0, -6) + Vector2(cos(az), sin(az) * 0.5) * 40.0
			draw_line(oz - Vector2(0, 16), oz + Vector2(0, 16), Color(0.98, 0.80, 0.86, 0.85 * kz), 4.0)
		draw_arc(hp2 + Vector2(0, 8), 38.0, 0.0, TAU, 24, Color(0.96, 0.66, 0.76, 0.35 * kz), 2.0)
	# ⑥ 药婆子：淡金——身周几根细针在走
	if p_active("yaopozi"):
		var ky := 0.45 + 0.55 * p_ratio("yaopozi")
		for i in 4:
			var ay2 := TAU * float(i) / 4.0 - _t * 1.4
			var oy := hp2 + Vector2(cos(ay2), sin(ay2) * 0.7) * 32.0
			draw_line(oy, oy + Vector2(0, -12.0), Color(0.98, 0.92, 0.70, 0.9 * ky), 2.0)
		draw_arc(hp2 + Vector2(0, 10), 30.0, 0.0, TAU, 20, Color(0.92, 0.86, 0.58, 0.35 * ky), 2.0)
	# ⑦ 鼓上蚤：橙黄——脚下往外扩的鼓点波纹
	if p_active("gushangzao"):
		var kg := 0.45 + 0.55 * p_ratio("gushangzao")
		for i in 3:
			var rg := fmod(_t * 1.1 + float(i) / 3.0, 1.0)
			draw_arc(hp2 + Vector2(0, 20), 14.0 + rg * 42.0, 0.0, TAU, 24, Color(1.0, 0.72, 0.30, (1.0 - rg) * 0.7 * kg), 3.0)
	# ⑧ 金甲校尉：土黄——六片旋转甲片 ＋ 一圈金环
	if p_active("jinjiaxianwei"):
		var kj := 0.45 + 0.55 * p_ratio("jinjiaxianwei")
		for i in 6:
			var aj := TAU * float(i) / 6.0 + _t * 0.9
			var oj := hp2 + Vector2(0, 4) + Vector2(cos(aj), sin(aj) * 0.75) * 40.0
			var dj := Vector2(cos(aj), sin(aj) * 0.75)
			draw_colored_polygon(PackedVector2Array([oj + dj * 10.0, oj - dj * 6.0 + Vector2(-dj.y, dj.x) * 7.0, oj - dj * 6.0 - Vector2(-dj.y, dj.x) * 7.0]), Color(0.78, 0.66, 0.38, 0.9 * kj))
		draw_arc(hp2 + Vector2(0, 12), 44.0, 0.0, TAU, 26, Color(0.92, 0.80, 0.44, 0.4 * kj), 2.0)
	# ⑨ 火工道人：橙红——三簇火苗绕着转
	if p_active("huogong"):
		var kh := 0.45 + 0.55 * p_ratio("huogong")
		for i in 3:
			var ah := TAU * float(i) / 3.0 + _t * 1.8
			var oh := hp2 + Vector2(0, 6) + Vector2(cos(ah), sin(ah) * 0.6) * 36.0
			var fh := 10.0 + absf(sin(_t * 12.0 + float(i))) * 8.0
			draw_colored_polygon(PackedVector2Array([oh + Vector2(0, 6), oh + Vector2(-4, -fh * 0.5), oh + Vector2(0, -fh), oh + Vector2(4, -fh * 0.5)]), Color(1.0, 0.56, 0.24, 0.9 * kh))
		draw_arc(hp2 + Vector2(0, 14), 36.0, 0.0, TAU, 24, Color(1.0, 0.60, 0.26, 0.28 * kh), 2.0)
	# ⑩ 琴痴：淡紫——音波往外荡 ＋ 几条弦线
	if p_active("qinchi"):
		var kq := 0.45 + 0.55 * p_ratio("qinchi")
		for i in 3:
			var rq := fmod(_t * 0.9 + float(i) / 3.0, 1.0)
			draw_arc(hp2 + Vector2(0, 2), 12.0 + rq * 52.0, PI * 0.15, PI * 0.85, 18, Color(0.86, 0.72, 1.0, (1.0 - rq) * 0.65 * kq), 3.0)
		for i in 4:
			draw_line(hp2 + Vector2(-26.0 + float(i) * 17.0, -30.0), hp2 + Vector2(-26.0 + float(i) * 17.0, 4.0), Color(0.88, 0.80, 0.62, 0.35 * kq), 1.5)
	# ⑪ 白起后人：暗红——杀意环 ＋ 身侧一串血点
	if p_active("baiqihouren"):
		var kqq := 0.45 + 0.55 * p_ratio("baiqihouren")
		draw_arc(hp2 + Vector2(0, 16), 46.0, _t * 1.2, _t * 1.2 + 3.4, 26, Color(0.86, 0.20, 0.18, 0.6 * kqq), 4.0)
		for i in 5:
			draw_circle(hp2 + Vector2(24.0 + float(i) * 3.0, -18.0 - float(i) * 10.0), 2.6, Color(0.94, 0.36, 0.32, 0.8 * kqq))
	# ⑫ 大内供奉：白金——身周一层罡气壳 ＋ 碎金片

	# v15w 新增 12 位的专属特效
	# ① 杏林医女：淡绿——绕身走的药气点 ＋ 一株小草
	if p_active("xinglin"):
		var k1 := 0.45 + 0.55 * p_ratio("xinglin")
		for i in 5:
			var a1 := TAU * float(i) / 5.0 + _t * 1.3
			var o1 := hp2 + Vector2(cos(a1), sin(a1) * 0.6) * (30.0 + sin(_t * 3.0 + float(i)) * 8.0)
			draw_circle(o1, 4.0, Color(0.62, 0.94, 0.68, 0.8 * k1))
	# ② 樵夫：棕绿——扛着斧子挥的一道弧
	if p_active("qiaofu"):
		var k2 := 0.45 + 0.55 * p_ratio("qiaofu")
		draw_arc(hp2 + Vector2(18, -20), 34.0, -PI * 0.7, PI * 0.2, 16, Color(0.72, 0.62, 0.40, 0.8 * k2), 5.0)
		draw_line(hp2 + Vector2(30, -46), hp2 + Vector2(46, -18), Color(0.86, 0.82, 0.66, 0.9 * k2), 3.0)
	# ③ 破阵刀客：橙红——身前一横一竖的刀痕
	if p_active("pozhen"):
		var k3 := 0.45 + 0.55 * p_ratio("pozhen")
		draw_line(hp2 + Vector2(-30, -34), hp2 + Vector2(30, -6), Color(0.96, 0.62, 0.32, 0.85 * k3), 4.0)
		draw_line(hp2 + Vector2(6, -46), hp2 + Vector2(2, -4), Color(0.98, 0.76, 0.46, 0.7 * k3), 3.0)
	# ④ 捕蛇人：草绿——脚边两条游动的蛇影
	if p_active("busheren"):
		var k4 := 0.45 + 0.55 * p_ratio("busheren")
		for i in 2:
			var ph := _t * 3.0 + float(i) * PI
			for j in 4:
				var pj := hp2 + Vector2(-30.0 + float(j) * 18.0 + float(i) * 6.0, 16.0 + sin(ph + float(j) * 0.8) * 7.0)
				draw_circle(pj, 3.0, Color(0.52, 0.88, 0.40, 0.75 * k4))
	# ⑤ 更夫：灰黄——手里一只晃动的灯笼
	if p_active("gengfu"):
		var k5 := 0.45 + 0.55 * p_ratio("gengfu")
		var lp := hp2 + Vector2(26.0, -40.0 + sin(_t * 3.0) * 4.0)
		draw_circle(lp, 12.0, Color(1.0, 0.86, 0.46, 0.28 * k5))
		draw_circle(lp, 6.0, Color(1.0, 0.92, 0.62, 0.9 * k5))
	# ⑥ 蛊师：暗紫——三只绕飞的小蛊虫
	if p_active("gushi"):
		var k6 := 0.45 + 0.55 * p_ratio("gushi")
		for i in 3:
			var a6 := TAU * float(i) / 3.0 + _t * 2.4
			var o6 := hp2 + Vector2(cos(a6), sin(a6) * 0.5) * 42.0 + Vector2(0, -20)
			draw_circle(o6, 4.5, Color(0.66, 0.40, 0.86, 0.85 * k6))
			draw_circle(o6, 8.0, Color(0.52, 0.28, 0.72, 0.25 * k6))
	# ⑦ 快刀手：银白——三道交错的短刀光
	if p_active("kuaidaoshou"):
		var k7 := 0.45 + 0.55 * p_ratio("kuaidaoshou")
		for i in 3:
			var oy := -56.0 + float(i) * 20.0
			var sl := sin(_t * 9.0 + float(i)) * 4.0
			draw_line(hp2 + Vector2(-26, oy + sl), hp2 + Vector2(30, oy - 6.0 + sl), Color(0.94, 0.96, 1.0, 0.75 * k7), 3.0)
	# ⑧ 老船工：青蓝——脚下一道水波 ＋ 手里长篙
	if p_active("chuangong"):
		var k8 := 0.45 + 0.55 * p_ratio("chuangong")
		for i in 3:
			var r8 := fmod(_t * 0.9 + float(i) / 3.0, 1.0)
			draw_arc(hp2 + Vector2(0, 22), 12.0 + r8 * 36.0, PI * 1.1, PI * 1.9, 14, Color(0.52, 0.80, 0.96, (1.0 - r8) * 0.7 * k8), 3.0)
		draw_line(hp2 + Vector2(26, 6), hp2 + Vector2(44, -72), Color(0.72, 0.60, 0.40, 0.9 * k8), 4.0)
	# ⑨ 铁面僧：土黄——一层面具般的方框 ＋ 岩石碎点
	if p_active("tiemianseng"):
		var k9 := 0.45 + 0.55 * p_ratio("tiemianseng")
		var fc := hp2 + Vector2(0, -34)
		draw_rect(Rect2(fc.x - 15.0, fc.y - 15.0, 30.0, 30.0), Color(0.84, 0.74, 0.50, 0.28 * k9), true)
		draw_rect(Rect2(fc.x - 15.0, fc.y - 15.0, 30.0, 30.0), Color(0.92, 0.84, 0.60, 0.85 * k9), false, 3.0)
		for i in 4:
			var a9 := TAU * float(i) / 4.0 + _t * 0.8
			draw_circle(hp2 + Vector2(cos(a9), sin(a9) * 0.6) * 46.0, 3.5, Color(0.80, 0.70, 0.46, 0.7 * k9))
	# ⑩ 冷月娘：冰蓝——几片飘落的霜花
	if p_active("lengyueniang"):
		var k10 := 0.45 + 0.55 * p_ratio("lengyueniang")
		for i in 6:
			var fy := fmod(_t * 0.6 + float(i) / 6.0, 1.0)
			var fxp := hp2.x + sin((_t + float(i) * 1.7) * 1.5) * 34.0
			var fyp := hp2.y - 90.0 + fy * 96.0
			draw_line(Vector2(fxp - 4.0, fyp), Vector2(fxp + 4.0, fyp), Color(0.78, 0.94, 1.0, (1.0 - fy) * 0.85 * k10), 2.0)
			draw_line(Vector2(fxp, fyp - 4.0), Vector2(fxp, fyp + 4.0), Color(0.78, 0.94, 1.0, (1.0 - fy) * 0.85 * k10), 2.0)
	# ⑪ 鬼见愁：血紫——头顶一道悬着的铡刀
	if p_active("guijianchou"):
		var k11 := 0.45 + 0.55 * p_ratio("guijianchou")
		var by := hp2.y - 74.0 + sin(_t * 2.0) * 5.0
		draw_line(Vector2(hp2.x - 26.0, by), Vector2(hp2.x + 26.0, by), Color(0.80, 0.30, 0.42, 0.9 * k11), 5.0)
		draw_line(Vector2(hp2.x - 26.0, by - 10.0), Vector2(hp2.x - 26.0, by + 10.0), Color(0.66, 0.24, 0.34, 0.8 * k11), 3.0)
		draw_arc(hp2 + Vector2(0, 16), 44.0, 0.0, TAU, 24, Color(0.70, 0.24, 0.34, 0.32 * k11), 2.0)
	# ⑫ 醉太岁：酒金——身周飘着几个酒气圈
	if p_active("zuitaisui"):
		var k12 := 0.45 + 0.55 * p_ratio("zuitaisui")
		for i in 3:
			var a12 := TAU * float(i) / 3.0 - _t * 1.1
			var o12 := hp2 + Vector2(cos(a12), sin(a12) * 0.7) * (26.0 + float(i) * 9.0)
			draw_arc(o12, 9.0, 0.0, TAU, 14, Color(1.0, 0.82, 0.40, 0.55 * k12), 2.0)
		draw_arc(hp2 + Vector2(0, 6), 40.0, 0.0, TAU, 22, Color(0.96, 0.76, 0.36, 0.25 * k12), 2.0)
	if p_active("dagongfeng"):
		var kd := 0.45 + 0.55 * p_ratio("dagongfeng")
		draw_arc(hp2 + Vector2(0, -6), 34.0 + sin(_t * 4.0) * 2.0, 0.0, TAU, 28, Color(0.92, 0.90, 0.74, 0.55 * kd), 3.0)
		draw_arc(hp2 + Vector2(0, -6), 40.0, 0.0, TAU, 28, Color(0.86, 0.84, 0.62, 0.28 * kd), 2.0)
		for i in 6:
			var ad := TAU * float(i) / 6.0 - _t * 1.1
			draw_circle(hp2 + Vector2(0, -6) + Vector2(cos(ad), sin(ad)) * 46.0, 3.0, Color(0.96, 0.94, 0.72, 0.75 * kd))
# ============================================================
# v5f 伤害管线（用户：暴击/暴击伤害无上限 · 元素**不吃暴击也不吃护甲减伤** ·
#   幸运一击上限 300% · 各元素抗性与元素加成 · 全伤害增加与减免）
#   出伤：全伤害增加 → 元素加成（仅元素）→ 暴击（**仅物理**，无上限）→ 幸运一击（上限 300%）
#   受伤：物理吃（护甲＋全减）· 元素吃（该元素抗性＋全减，**不吃护甲**）· 真实什么都不吃
# ============================================================
const LUCKY_CAP := 3.0            # 幸运一击上限 300%
const ELEMS := ["金系", "木系", "火系", "水系", "土系"]
# v13f：给外壳的普通档任务用的两个计数
var dmg_done := 0.0                  # 本局累计造成伤害（以战养战）
var skill_kills := 0                 # 元素/伙伴技击杀数（百步）
var kill_normal := 0                # v13w：普通怪击杀数（成就「嗜杀如命」用）

signal elite_down()
const ELITE_NAME := "典狱长的走狗"

# 猎杀任务：往怪群里塞一只精英（大怪）
func spawn_elite(n := 1) -> void:
	clear_elite()
	var mul := pow(WAVE_HP, float(wave - 1))
	for ei in n:
		_spawn_foe("elite", 1.0, 1.0, false, 1, ELITE_NAME)
		var fe: Dictionary = foes[foes.size() - 1]
		fe["hp"] = 300.0 * mul
		fe["hp_max"] = 300.0 * mul
		fe["atk"] = 10.0 * pow(WAVE_ATK, float(wave - 1))
		fe["scale"] = 1.3
		fe["stop"] = FOE_STOP + 10.0
	_banner = ("猎杀：混进来一只精英——" if n <= 1 else "三英：来了 " + str(n) + " 只精英") + ("" if n > 1 else ELITE_NAME)
	_banner_t = 2.6
	Audio.sfx("drum", -6.0)

func clear_elite() -> void:
	for i in range(foes.size() - 1, -1, -1):
		if str((foes[i] as Dictionary).get("kind", "")) == "elite":
			foes.remove_at(i)

func live_foes() -> int:
	var n := 0
	for f_v in foes:
		var f: Dictionary = f_v
		if bool(f.get("still", false)) or float(f.get("dying", 0.0)) > 0.0:
			continue
		n += 1
	return n

# 出伤：把主角这一下的伤害算全（返回 Dictionary：{dmg, crit, lucky}）
func hero_out_dmg(base: float, dtype: String) -> Dictionary:
	# v5g（用户："真实伤害 不吃增幅 不吃抗性 除了加真实伤害的"）：
	#   真实伤害**只吃"加真实伤害"这一条**——全伤/元素/暴击/幸运/抗性全都不参与
	if dtype == DMG_TRUE:
		return {"dmg": base * (1.0 + float(hero.get("dmg_true", 0.0))), "crit": false, "lucky": false}
	var d := base * (1.0 + float(hero.get("dmg_all", 0.0)))       # 全伤害增加
	if dtype != DMG_PHYS and dtype != DMG_TRUE:
		d *= 1.0 + float(hero.get("elem_amp", 0.0))                # 悟性给的元素攻击
		d *= 1.0 + float((hero.get("dmg_elem", {}) as Dictionary).get(dtype, 0.0))   # 该元素加成
	var crit := false
	if dtype == DMG_PHYS:                                          # **元素与真实不暴击**
		crit = randf() < float(hero.get("crit", 0.05))
		if crit:
			d *= float(hero.get("crit_dmg", 2.0))                  # 暴击伤害（无上限）
	var lucky := false
	var lk := minf(LUCKY_CAP, float(hero.get("lucky", 0.0)))
	if lk > 0.0 and randf() < lk / 3.0:                            # 概率＝幸运/3（满 300% 必触发）
		lucky = true
		d *= 1.0 + lk
	return {"dmg": d, "crit": crit, "lucky": lucky}

# 受伤：主角挨打时按类型减（物理吃护甲；元素吃抗性不吃护甲；真实不吃）
func hero_in_dmg(amount: float, dtype: String) -> float:
	if p_active("tiexinwu") and not bool(partners["tiexinwu"].get("used", false)):
		partners["tiexinwu"]["used"] = true
		_push_float(hero_pos.x, hero_pos.y - 76.0, "铁壁！免伤", Color(0.86, 0.88, 0.94), true)
		return 0.0
	if dtype == DMG_TRUE:
		return amount
	var cut := float(hero.get("cut_all", 0.0))                     # 全伤害减免（含横练）
	if dtype == DMG_PHYS:
		cut += float(hero.get("cut", 0.0))                         # 护甲只减物理
	else:
		cut += float((hero.get("res_elem", {}) as Dictionary).get(dtype, 0.0))
	if p_active("shigandang"):
		cut += 0.25 + 0.05 * float(partners["shigandang"].get("cut_lv", 0))
	# v15w 铁面僧「铁面」：窗口内受伤再 −25%（并且减免量还给主角回血）
	var dr := 0.0
	if float(hero.get("dr_t", 0.0)) > 0.0:
		dr = float(hero.get("dr", 0.0))
		cut += dr
	var taken := maxf(0.0, amount * (1.0 - minf(0.90, cut)))
	if dr > 0.0 and taken > 0.0:
		hero["hp"] = minf(float(hero["hp_max"]), float(hero["hp"]) + amount * dr * 0.5)
	return taken

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
	# v13d P3：法阵（占点）——画在怪下面一层
	if not zone.is_empty() and bool(zone.get("on", false)):
		var zc := Vector2(float(zone["x"]), float(zone["y"]))
		var zr := float(zone["r"])
		var inz := _in_zone()
		var zcol := Color(0.44, 0.86, 0.74, 0.9) if inz else Color(0.62, 0.72, 0.78, 0.5)
		draw_circle(zc, zr, Color(zcol.r, zcol.g, zcol.b, 0.10 if inz else 0.05))
		draw_arc(zc, zr, 0.0, TAU, 64, zcol, 3.0)
		draw_arc(zc, zr - 12.0, 0.0, TAU, 64, Color(zcol.r, zcol.g, zcol.b, 0.32), 2.0)
		var zgoal := maxf(1.0, float(zone.get("goal", 12.0)))
		draw_arc(zc, 36.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(float(zone["prog"]) / zgoal, 0.0, 1.0),
			44, Color(0.98, 0.86, 0.42, 0.92), 5.0)
		draw_circle(zc, 5.0, Color(0.98, 0.86, 0.42, 0.7))
	# v13e P4：牢车（守护目标）——画在怪下面一层
	if not guard.is_empty():
		var gx := float(guard["x"])
		var gy := float(guard["y"])
		var gfl := float(guard.get("flash", 0.0))
		var gbody := Color(1.0, 0.96, 0.88) if gfl > 0.0 else Color(0.62, 0.44, 0.26)
		draw_circle(Vector2(gx, gy + 20.0), 40.0, Color(0, 0, 0, 0.16))
		draw_rect(Rect2(gx - 34.0, gy - 24.0, 68.0, 36.0), gbody)
		draw_rect(Rect2(gx - 34.0, gy - 36.0, 68.0, 12.0), Color(0.46, 0.32, 0.19))
		draw_circle(Vector2(gx - 20.0, gy + 14.0), 13.0, Color(0.32, 0.24, 0.16))
		draw_circle(Vector2(gx + 20.0, gy + 14.0), 13.0, Color(0.32, 0.24, 0.16))
		draw_circle(Vector2(gx - 20.0, gy + 14.0), 5.0, Color(0.74, 0.64, 0.48))
		draw_circle(Vector2(gx + 20.0, gy + 14.0), 5.0, Color(0.74, 0.64, 0.48))
		var gw := 76.0
		draw_rect(Rect2(gx - gw * 0.5, gy - 54.0, gw, 8.0), Color(0.28, 0.26, 0.28))
		var gr := guard_hp_ratio()
		var gcol := Color(0.42, 0.78, 0.50) if gr > 0.5 else (Color(0.88, 0.72, 0.32) if gr > 0.25 else Color(0.86, 0.34, 0.28))
		draw_rect(Rect2(gx - gw * 0.5, gy - 54.0, gw * gr, 8.0), gcol)
		draw_string(ThemeDB.fallback_font, Vector2(gx - 40.0, gy - 60.0), "牢车",
			HORIZONTAL_ALIGNMENT_CENTER, 80.0, 18, Color(0.96, 0.90, 0.74))
	# 怪（先画，压在主角下面一层）
	for f_v in foes:
		var f: Dictionary = f_v
		# ⚠ 用 get 兜底：手工塞进来的怪（探针/召唤）不一定带 scale，硬取会每帧刷错
		var sc := float(f.get("scale", 1.0))
		if float(f["y"]) < -20.0:
			continue
		var dying := float(f.get("dying", 0.0))
		var flash := float(f.get("flash", 0.0))
		var lunge := float(f.get("lunge", 0.0))
		# 中毒/灼烧：头顶挂一个小色点（绿＝毒 · 橙＝烧）
		var dots2: Array = f.get("dot", [])
		if dots2.size() > 0:
			var dd2: Dictionary = dots2[0]
			var dc := Color(0.58, 0.90, 0.54) if str(dd2["dtype"]) == DMG_WOOD else Color(1.0, 0.62, 0.28)
			draw_circle(Vector2(float(f["x"]) + 14.0, float(f["y"]) - 50.0 * sc), 5.0 + sin(_t * 6.0) * 1.2, dc)
			draw_circle(Vector2(float(f["x"]) + 14.0, float(f["y"]) - 50.0 * sc), 8.0, Color(dc.r, dc.g, dc.b, 0.25))
		# 麻痹：头顶跳两下电花（一眼看出"这只动不了"）
		if float(f.get("para", 0.0)) > 0.0:
			var pp2 := Vector2(float(f["x"]), float(f["y"]) - 46.0 * sc)
			for k in 2:
				var off := Vector2(randf_range(-12.0, 12.0), randf_range(-10.0, 10.0))
				draw_line(pp2 + off, pp2 + off + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
					Color(0.92, 0.96, 1.0, 0.85), 2.0)
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
		elif bool(f.get("boss", false)):
			col = Color(0.72, 0.22, 0.20)
		draw_rect(Rect2(bx, float(f["y"]) - 58.0 * sc, bw * ratio, 6.0), col)
		if bool(f.get("boss", false)) or str(f.get("kind", "")) == "champion":
			var nm := str(f["name"])
			draw_string(ThemeDB.fallback_font, Vector2(float(f["x"]) - 70.0, float(f["y"]) - 66.0 * sc), nm,
				HORIZONTAL_ALIGNMENT_CENTER, 140.0, 20, Color(0.95, 0.86, 0.66))
	# v13b P1：点击指令的可视标记（走位目标圈 ＋ 集火红准星）
	if _order_has_pos:
		var opc := _order_pos
		draw_arc(opc, 22.0 + sin(_t * 7.0) * 3.0, 0.0, TAU, 26, Color(0.98, 0.86, 0.42, 0.55), 3.0)
		draw_line(opc + Vector2(-9, 0), opc + Vector2(9, 0), Color(0.98, 0.86, 0.42, 0.85), 2.0)
		draw_line(opc + Vector2(0, -9), opc + Vector2(0, 9), Color(0.98, 0.86, 0.42, 0.85), 2.0)
	for ofx_v in _order_fx:
		var ofx: Dictionary = ofx_v
		var tt := clampf(float(ofx["t"]) / 0.5, 0.0, 1.0)
		draw_arc(Vector2(float(ofx["x"]), float(ofx["y"])), 16.0 + 60.0 * tt, 0.0, TAU, 26,
			Color(0.98, 0.86, 0.42, 0.8 * (1.0 - tt)), 3.0)
	if not _order_foe.is_empty() and foes.has(_order_foe):
		var ffx: Dictionary = _order_foe
		if float(ffx.get("dying", 0.0)) <= 0.0:
			var fsc := float(ffx.get("scale", 1.0))
			var ctr := Vector2(float(ffx["x"]), float(ffx["y"]) - 16.0 * fsc)
			var rr := 30.0 + fsc * 12.0 + sin(_t * 8.0) * 2.0
			for q in 4:
				var sx := 1.0 if q % 2 == 0 else -1.0
				var sy := 1.0 if q < 2 else -1.0
				var corner := ctr + Vector2(sx * rr, sy * rr * 0.85)
				draw_line(corner, corner - Vector2(sx * 11.0, 0.0), Color(0.94, 0.24, 0.18, 0.95), 3.0)
				draw_line(corner, corner - Vector2(0.0, sy * 11.0), Color(0.94, 0.24, 0.18, 0.95), 3.0)
	# 主角＋宠物
	var hx := hero_pos.x
	var hy := hero_pos.y
	var hero_col: Color = hero.get("hero_col", Color(0.94, 0.92, 0.86))     # v14s：出战那位自己的配色
	if _hero_hit_flash > 0.0:
		hero_col = Color(0.98, 0.62, 0.56)
	# 出手那一下往上一冲（突刺），平时轻轻起伏
	var hy2 := hy + sin(_t * 4.0) * 3.0 - _hero_lunge * 16.0
	_stick(Vector2(hx, hy2), 1.35, hero_col, true)
	# v14s：出战那位放技能时，头顶冒一行"你的技能"
	if hero_skill_t > 0.0 and hero_mate != "":
		draw_string(ThemeDB.fallback_font, Vector2(hx - 90.0, hy2 - 108.0),
			str(PARTNER_INFO[hero_mate]["skill"]) + "（你的技能）",
			HORIZONTAL_ALIGNMENT_CENTER, 180.0, 20, Color(0.92, 0.84, 1.0, minf(1.0, hero_skill_t * 1.6)))
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
	_draw_bolts(shk)
	_draw_fire_lines(shk)
	_draw_minions(shk)
	_draw_shield(shk)
	# 命中炸开（溅射/剑气）：一圈冲击环 ＋ 八根放射线
	for bu_v in _bursts:
		var bu: Dictionary = bu_v
		var ba := 1.0 - float(bu["t"]) / 0.30
		var bc: Color = bu["col"]
		# ⚠ 用 get 兜底：漏写 scale 的条目会每帧刷 "Invalid access to property"（探针抓到过）
		var bs := float(bu.get("scale", 1.0)) * (0.6 + 0.9 * (1.0 - ba))
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
		"statue":
			_draw_statue(c, sc, fc)
		"champion":
			_draw_boss(c, sc, fc)
		"elite":
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

# v13d P3：石像——一块立着的石碑（顶上阵纹，一眼看出是任务目标）
func _draw_statue(c: Vector2, sc: float, fc: Color) -> void:
	var w := 34.0 * sc
	var h := 62.0 * sc
	var a := fc.a
	draw_rect(Rect2(c.x - w * 0.5, c.y - h, w, h), Color(0.50, 0.48, 0.46, a))
	draw_rect(Rect2(c.x - w * 0.5 + 3.0, c.y - h + 4.0, w - 6.0, h - 8.0), Color(0.60, 0.58, 0.55, a))
	draw_rect(Rect2(c.x - w * 0.5 - 5.0 * sc, c.y - 9.0 * sc, w + 10.0 * sc, 11.0 * sc), Color(0.42, 0.40, 0.38, a))
	var glow := (0.55 + sin(_t * 3.0) * 0.25) * a
	draw_rect(Rect2(c.x - 9.0 * sc, c.y - h + 12.0 * sc, 18.0 * sc, 4.0 * sc), Color(0.88, 0.74, 0.34, glow))
	draw_rect(Rect2(c.x - 4.0 * sc, c.y - h + 8.0 * sc, 8.0 * sc, 24.0 * sc), Color(0.88, 0.74, 0.34, glow))
# v14e（用户："宠物记得 动画样子也不一样"）：六只宠物**各画各的样子与动作**
#   hu 尖耳大尾狐（扑咬张嘴）· gui 圆龟壳（缩头呼吸）· bao 瘦长豹（甩长尾、大摆腿）
#   jiu 展翅鹫（拍翅悬空）· lin 独角麒麟（火焰鬃毛跳动）· chan 矮胖蟾（后腿蹬跳）
func _pet(c: Vector2, sh: Vector2) -> void:
	var off := _pet_dir * (_pet_lunge * 26.0 - _pet_wind * 8.0)
	var c2 := c + off
	var stretch := 1.0 + _pet_lunge * 0.20 - _pet_wind * 0.10
	var squash := 1.0 - _pet_lunge * 0.12 + _pet_wind * 0.14
	draw_set_transform(c2 + sh, atan2(_pet_dir.y, _pet_dir.x) + PI * 0.5, Vector2(stretch, squash))
	var kind := str(pet_cfg.get("kind", "hu"))
	var pc := Color(0.87, 0.85, 0.79)
	match kind:
		"gui":
			pc = Color(0.62, 0.68, 0.52)
			draw_circle(Vector2(0, 2), 19.0, pc)                      # 龟壳
			draw_circle(Vector2(0, 2), 12.0, Color(0.46, 0.54, 0.40))  # 壳纹
			for i in 4:
				draw_line(Vector2(-11.0 + float(i) * 7.3, 16.0), Vector2(-13.0 + float(i) * 8.0, 24.0), pc, 5.0)
			var hn := sin(_t * 2.2) * 3.0                             # 缩头呼吸
			draw_circle(Vector2(-20, -12 + hn), 10.0, pc)
			draw_circle(Vector2(-24, -15 + hn), 2.2, Color(0.18, 0.18, 0.18))
		"bao":
			pc = Color(0.88, 0.62, 0.32)
			for i in 4:
				var lx2 := -13.0 + float(i) * 8.6
				var sw2 := sin(_pet_step + float(i) * 1.7) * 9.0
				draw_line(Vector2(lx2, 12.0), Vector2(lx2 + sw2, 27.0), pc, 3.6)
			draw_line(Vector2(-14, 2), Vector2(20, -2), pc, 13.0)      # 瘦长身
			draw_line(Vector2(18, -2), Vector2(40 + sin(_t * 11.0) * 10.0, -22 + cos(_t * 11.0) * 8.0), pc, 3.6)
			draw_circle(Vector2(-24, -10), 9.5, pc)                   # 头
			draw_colored_polygon(PackedVector2Array([Vector2(-30, -18), Vector2(-24, -27), Vector2(-18, -17)]), pc)
			for i in 3:                                               # 斑点
				draw_circle(Vector2(-8.0 + float(i) * 10.0, 0.0), 2.0, Color(0.36, 0.24, 0.14))
			draw_circle(Vector2(-28, -13), 2.2, Color(0.18, 0.16, 0.14))
		"jiu":
			pc = Color(0.66, 0.68, 0.78)
			var flap := sin(_t * 12.0) * 12.0                          # 拍翅
			draw_line(Vector2(-4, -4), Vector2(-26, -18 + flap), pc, 6.0)
			draw_line(Vector2(-4, -4), Vector2(22, -18 - flap), pc, 6.0)
			draw_circle(Vector2(0, 4 + sin(_t * 6.0) * 2.0), 12.0, pc) # 悬空浮动
			draw_circle(Vector2(-14, -8), 9.0, pc)
			draw_colored_polygon(PackedVector2Array([Vector2(-22, -10), Vector2(-34, -6), Vector2(-22, -2)]),
				Color(0.92, 0.76, 0.30))                              # 喙
			draw_line(Vector2(8, 6), Vector2(24, 16), pc, 5.0)         # 尾羽
			draw_circle(Vector2(-17, -11), 2.0, Color(0.16, 0.16, 0.18))
		"lin":
			pc = Color(0.90, 0.72, 0.46)
			for i in 4:
				var lx3 := -11.0 + float(i) * 7.3
				draw_line(Vector2(lx3, 12.0), Vector2(lx3 + sin(_pet_step + float(i) * 1.7) * 6.0, 26.0), pc, 4.0)
			draw_circle(Vector2(0, 0), 16.0, pc)
			for i in 5:                                                # 火焰鬃毛（跳动）
				var fy := -14.0 + float(i) * 6.0
				var fh := 8.0 + absf(sin(_t * 14.0 + float(i))) * 10.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(6, fy), Vector2(6 + fh * 0.6, fy - 5), Vector2(6 + fh, fy + 5)]),
					Color(1.0, 0.52 + 0.2 * float(i % 2), 0.18))
			draw_circle(Vector2(-19, -14), 11.5, pc)
			draw_colored_polygon(PackedVector2Array([Vector2(-26, -24), Vector2(-34, -40), Vector2(-20, -26)]),
				Color(0.96, 0.90, 0.62))                              # 独角
			draw_circle(Vector2(-23, -17), 2.4, Color(0.22, 0.16, 0.12))
		"chan":
			pc = Color(0.86, 0.74, 0.34)
			var hop := absf(sin(_t * 7.0)) * 6.0                       # 蹬跳
			draw_circle(Vector2(-19, -8 - hop), 12.0, pc)              # 前身
			draw_circle(Vector2(6, 4), 17.0, pc)                       # 胖后身
			for i in 2:
				draw_line(Vector2(6.0 + float(i) * 8.0, 14.0), Vector2(16.0 + float(i) * 6.0, 26.0), pc, 7.0)
			for i in 2:                                                # 两只大眼
				draw_circle(Vector2(-24.0 + float(i) * 9.0, -18 - hop), 4.6, Color(0.98, 0.96, 0.90))
				draw_circle(Vector2(-24.0 + float(i) * 9.0, -18 - hop), 2.2, Color(0.14, 0.13, 0.12))
		_:
			pc = Color(0.87, 0.85, 0.79)
			for i in 4:
				var lx := -11.0 + float(i) * 7.3
				var sw := sin(_pet_step + float(i) * 1.7) * 5.0
				draw_line(Vector2(lx, 12.0), Vector2(lx + sw, 26.0), pc, 4.0)
			draw_circle(Vector2(0, 0), 16.0, pc)
			draw_line(Vector2(14, -4), Vector2(30 + sin(_t * 9.0) * 5.0, -20 + cos(_t * 9.0) * 4.0), pc, 5.0)
			draw_circle(Vector2(-19, -14), 11.5, pc)
			draw_colored_polygon(PackedVector2Array([Vector2(-27, -22), Vector2(-20, -33), Vector2(-13, -21)]), pc)
			if _pet_lunge > 0.25:
				var o := _pet_lunge * 12.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(-30, -12), Vector2(-30 - o, -20 - o * 0.4), Vector2(-30 - o, -4 + o * 0.4)]),
					Color(0.42, 0.30, 0.28))
			draw_circle(Vector2(-23, -17), 2.4, Color(0.20, 0.19, 0.20))
	if kind == "jiu":
		draw_circle(Vector2(-17, -11), 2.0, Color(0.16, 0.16, 0.18))
	draw_set_transform(sh)      # ⚠ 还原抖屏变换，后面的刀光/飘字才不会被宠物的旋转带跑

# v14s：hair / wpn 是"出战主角的长相"参数（空字符串＝原来那个默认小人，队友/怪都不受影响）
var hair := ""
var wpn := ""

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
	# v14s：开局出战时，主角的小人换成那位伙伴的长相（头发/道冠 ＋ 手里的家伙）
	if hair != "":
		var hc := Color(0.16, 0.15, 0.17)
		var hc2 := Color(0.30, 0.13, 0.16)
		var head := c + Vector2(0, -34.0 * s)
		if hair == "long":
			draw_line(head + Vector2(-8.0 * s, 2.0 * s), head + Vector2(-13.0 * s, 30.0 * s), hc, 4.0 * s)
			draw_line(head + Vector2(8.0 * s, 2.0 * s), head + Vector2(13.0 * s, 30.0 * s), hc, 4.0 * s)
			draw_line(head + Vector2(-9.0 * s, -3.0 * s), head + Vector2(9.0 * s, -3.0 * s), hc, 3.0 * s)
		elif hair == "crown":
			draw_circle(head + Vector2(0, -10.0 * s), 4.0 * s, Color(0.86, 0.70, 0.28))
			draw_line(head + Vector2(-8.0 * s, -7.0 * s), head + Vector2(8.0 * s, -7.0 * s), Color(0.72, 0.58, 0.24), 2.5 * s)
		elif hair == "topknot":
			draw_circle(head + Vector2(0, -11.0 * s), 4.2 * s, hc)
			draw_line(head + Vector2(-7.0 * s, -6.0 * s), head + Vector2(7.0 * s, -6.0 * s), hc, 2.5 * s)
		elif hair == "hood":
			draw_arc(head, 10.5 * s, PI, TAU, 18, hc, 4.0 * s)
			draw_line(head + Vector2(-9.0 * s, 0.0), head + Vector2(-6.0 * s, 16.0 * s), hc, 3.5 * s)
		elif hair == "red":
			draw_line(head + Vector2(-9.0 * s, -4.0 * s), head + Vector2(-15.0 * s, -18.0 * s), hc2, 3.5 * s)
			draw_line(head + Vector2(0, -10.0 * s), head + Vector2(2.0 * s, -24.0 * s), hc2, 3.5 * s)
			draw_line(head + Vector2(9.0 * s, -4.0 * s), head + Vector2(15.0 * s, -18.0 * s), hc2, 3.5 * s)
	# 手里的家伙也按人换（原来一律是那把刀）
	if wpn != "":
		var hd := c + Vector2(14.0 * s, -10.0 * s)
		match wpn:
			"staff":
				draw_line(hd, hd + Vector2(6.0 * s, float(d) * 46.0 * s), Color(0.60, 0.48, 0.30), w)
				draw_circle(hd + Vector2(6.0 * s, float(d) * 50.0 * s), 6.0 * s, Color(0.92, 0.88, 0.56))
			"blade":
				draw_colored_polygon(PackedVector2Array([
					hd + Vector2(-2.0 * s, 4.0 * s), hd + Vector2(2.0 * s, 4.0 * s),
					hd + Vector2(4.0 * s, float(d) * 44.0 * s), hd + Vector2(-4.0 * s, float(d) * 44.0 * s)]),
					Color(0.90, 0.94, 0.98))
			"shield":
				draw_line(hd + Vector2(-2.0 * s, 0.0), hd + Vector2(-14.0 * s, float(d) * 22.0 * s), Color(0.56, 0.46, 0.32), w)
				draw_circle(hd + Vector2(-15.0 * s, float(d) * 24.0 * s), 9.0 * s, Color(0.74, 0.62, 0.34))
			"fan":
				draw_colored_polygon(PackedVector2Array([
					hd, hd + Vector2(-16.0 * s, float(d) * 24.0 * s), hd + Vector2(10.0 * s, float(d) * 30.0 * s)]),
					Color(0.88, 0.86, 0.80, 0.92))
			"bow":
				draw_arc(hd + Vector2(4.0 * s, float(d) * 26.0 * s), 17.0 * s, PI * 0.25, PI * 1.35, 16,
					Color(0.62, 0.44, 0.26), 3.0 * s)
				draw_line(hd + Vector2(-9.0 * s, float(d) * 10.0 * s), hd + Vector2(17.0 * s, float(d) * 12.0 * s),
					Color(0.86, 0.84, 0.78), 1.6 * s)
			_:
				pass
