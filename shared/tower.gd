extends RefCounted
# ============================================================
# tower.gd —— 出村爬塔（关卡系统）· 从 game_state.gd 拆出来（㉞ 拆分批）
#
# 为什么单独一个文件：塔的事情原本散在 game_state 里（关卡表/首领招数/成长公式/
#   掉落），而那些又是"改了要重算全局"的东西。500 关之后这块只会更重，
#   所以整块搬出来，game_state 只留转发口（老调用点一个字不用改）。
#
# 关卡构成：
#   · 每 5 关一章（沿用原设定，名字取下面 CHAPTER_MOB 那张表）
#   · 首领/精英按段取间隔（前期密、后期疏）——见参数区的规则表
#   · 两个间隔的公倍数关既是精英也是首领（里程碑关，吃两份加码）
#
# 难度用公式长，不写表：写 500 行表没法维护，而且调曲线时得改 500 个数。
#   血量/攻击都按"基准 × (关号^曲线指数) × (每章阶梯)"走，
#   所有系数集中在下面的参数区 —— 调难度只动那几个数。
#
# 前 50 关的首领招数沿用原来手写的那套（BOSS_ARTS_50）；第 50 关往后按
#   "首领档"从模板池里生成，免得几十个首领全是空白（原来表只写到 49 关）。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const GameData := preload("res://shared/game_data.gd")   # ㊼：多人关的血池倍数（纯数据，无循环）
# ⚠ 这里**不能** preload game_state —— game_state 已经 preload 了本文件，
#   互相引就成了环，Godot 会报循环依赖。需要"手上已有几页"这类账本数据时，
#   一律由调用方当参数传进来（见 gift_part_for）。

# ============================================================
# 参数区：调难度基本只动这里
#
# ⚠ 设计前提（㉟ 改）：**这不是一座有终点的塔**。
#   500 关只是"前期的一个强度刻度"，后面还要几万关。所以：
#   · 不用"锚点表"那种按固定终点设计的写法——终点一改，整张表就得重画；
#   · 用一条**纯指数曲线**：hp = BASE × GROW^i。关号翻倍，难度乘一个固定倍数。
#     好处是全段均匀、没有台阶、加多少关都不用改公式。
#   · 成长率取得很小（每关 +0.085%）：500 关约 1.5 倍、2000 关约 5.5 倍。
#     为什么这么小：玩家的攻击力不是指数涨的（等级封顶、升星封顶、品级封顶），
#     敌方要是指数涨太快，几万关之后必然无解。宁可前期偏软。
# ============================================================
const STAGE_MAX := 20000        # 塔的"实际可爬上限"——先给到两万，以后不够再加

# 首领/精英。规则**全塔统一**，不再分"前 50 关用旧规则"那一段：
#   旧版 50 关塔是每 5 关一个首领，新塔要是保留它，前 50 关会挤 10 个首领，
#   而后面每 50 关才一个——前后不是同一套规则，调平衡时会互相打架。
#   所以从第 1 关起重排：详见下面的规则表。
const BOSS_EVERY_EARLY := 25    # 第 1~999 关：每 25 关一个首领
const BOSS_EVERY_MID := 50      # 第 1000~4999 关：每 50 关
const BOSS_EVERY_LATE := 100    # 第 5000 关起：每 100 关
const ELITE_EVERY_EARLY := 10   # 第 1~999 关：每 10 关一个精英
const ELITE_EVERY_MID := 25
const ELITE_EVERY_LATE := 50
const MID_FROM := 1000
const LATE_FROM := 5000

# ---- 成长曲线：纯线性（复利项留着但设为 1.0，即不生效）----
# 为什么最终选纯线性——复利在这个尺度上**没有可用的中间值**，我试了三轮：
#   · 每关 +0.085% → 第 2 万关 94 亿血（爆掉）
#   · 每关 +0.02%  → 第 500 关 438 血、第 2000 关才 591 血（成了一条平线，没有递进感）
#   · 每关 +0.004% → 前 5000 关还行，第 2 万关又到 6.4 亿（还是爆）
# 根因：**玩家的攻击力不是指数涨的**（等级封顶 100、升星封顶 5、品级封顶绝品，
#   都是有上限的系统），所以敌方也不能指数涨——两边形状不一样，早晚会对不上。
# 线性至少有两个好处：量级一眼可算、加多少关都不用重画曲线。
# 第 1 关 110 血 → 第 500 关约 1500 → 第 2000 关约 6000 → 第 2 万关约 6 万。
# 想要后期更强，把 HP_LIN 调大即可（每 +1 就是每关多 1 点血）。
#
# ============================================================
# ⚠ v35（用户实测：50 级 300 血，第 150 关被一拳打掉半血）——**超的是攻击这一条**。
#
# 病根：气血那一头是有天花板的（等级 100＋根骨/装备/星封顶，实际 300~1000），
#   而攻击按 0.12/关线性涨：第 150 关本体 24，套上精英 ×1.15 × 首领 ×1.35 ＝ 37，
#   再乘 DMG_MUL(2.0) 就是**一拳 74~148**；王关三只各打一次（副手 0.6/0.4），
#   一轮下来 ≈148 点 ＝ 300 血的一半——两轮就倒。而血池 4010 那边要打十几手。
#   → "打不打得过"根本不是输出问题，是**挨不住**。（血/攻两条线，攻这条没人对过账。）
#
# 现在按这条尺子重排（只动下面这几个数，规则一个没改、掉落与赏钱一个没动）：
#   · 敌方**一拳** ≈ 同级玩家气血的一成上下（原来第 150 关是五成）
#   · 敌方**一轮**（全队打过来）≈ 气血的 1/6 ~ 1/8 → 能撑 6~8 轮
#   · 一场仗（含武学/大招/暴击）≈ 3~5 手打完 → 打得过，也不是一巴掌拍死
# 实算口径（第 150 关 · 50 级 · 气 296 · 攻 ~114 · 每手约 366 伤害）：
#   旧：本体一拳 74（半血）· 每轮挨 203 · 血池 4010 → 必输（2 轮倒）
#   新：本体一拳 17（一成不到）· 每轮挨  46 · 血池 1537 → 赢得下来（余量约 1.5 倍）
# 头目的"硬"现在靠**三只一起上**撑（血池 ×2、每轮挨的份数 ×2），
#   首领关的总血池仍是一个杂兵关的 2.4 倍——里程碑感没丢，只是不再叠成 3.6 倍。
#
# 墙挪到哪儿了（离线挂机与手动打用**同一把尺子** can_beat，所以两边一致）：
#   ⚠ v38 实测（同一份底子、同一把尺子重测）：1 级卡第 50 关 · 10 级 150 · 25 级 300 ·
#     50 级赤手 500 · 50 级良品一套 900 · 50 级 v38 极品一套 1500。
#     （v35 那一版的口径是"50 级 300 血 ≈ 170~200 关"，现已整体外推。）
# 想把这堵墙往外推：抬 ATK_LIN（每 +0.01 ≈ 多爬二三十关）或降 HP_LIN（每 −0.1 ≈ 全段 −4% 血）；
# 想让前中期更软就往下压。**只有这两个数管"打不打得过"**（HP_* 管一场打多久，ATK_* 管挨不挨得住）。
# ============================================================
# v62h（用户定的成长重排：升级只加气血 · 突破按根骨 · 兵器攻击 ×1.7 · 防具气血 ×5.4）：
#   玩家那条线的**攻击量级从"2000 上下"落到"90 上下"**，所以墙的形状整个重标了一遍。
#   原来敌人是"越往后越肉"（HP_LIN 1.80 把后段顶得太高）——玩家攻击不再随等级涨之后，
#   后段会直接打不动 ✗。所以这次是**调形状**而不是整体乘一个系数：
#     第 50 关 →  ~200 血（几乎没动）      第 1000 关 → ~2600 血（原来 7000+）
#   全程目标：三个人 1.5~2 回合清一场（单人在 4~5 击上下），前后段一致。
# v62i（用户："爬塔和游历总体难度加强30% 给点压迫"）：
#   敌人**血与攻整体 ×1.3**——做法是把下面四个基数/线性项一起乘 1.3（阶梯 TIER_* 不动，
#   于是每一关都是均匀的 +30%，不是越往后越滚）。
#   配套：游历那边加了同一个 FOE_MUL=1.30（见 data_journey._scale_foe）——两边同步。
#   节奏预期：原来 1.0~2.5 回合 → 现在约 1.3~3.2 回合（前 200 关减负曲线照旧生效）。
const HP_BASE := 520.0          # 第 1 关血量（v62i：400 × 1.3）
const HP_LIN := 1.04            # 每关 +N（v62i：0.80 × 1.3）
const HP_GROW := 1.0            # 复利项：留 1.0＝不生效（想启用就填 1.0001 这种）
const ATK_BASE := 6.5           # 第 1 关攻（v62i：5.0 × 1.3）
const ATK_LIN := 0.0403         # 每关 +攻（v62i：0.031 × 1.3）
const ATK_GROW := 1.0

# ============================================================
# v62（用户："不少属性增幅都太大了 数值膨胀太快 装备都没作用了 先伤害增幅全部减半"）
#
#   伤害/气血那几条线已经整体减半（装备/角色星/五问/羁绊/宠物；**专武按用户要求保留**）。
#   实测：满配角色的"出手伤害 +%"从 ~87 降到 ~44、气血 +% 从 ~66 降到 ~33
#   —— 输出约 −23%、有效血量约 −20%。所以敌人这条曲线要跟着下来，但**少降一点**：
#     血量线性项 2.05 → **1.80**、攻击线性项 0.086 → **0.077**
#     （第 1000 关：血 8008 → 约 7000、攻 401 → 约 361）
#   净效果：比 v61 略硬一档——玩家弱了两成多、敌人只弱了一成出头，
#   于是"墙"往前提了一点，正是用户要的**卡关感**。
#   想更松/更紧：只动这两个线性项（每 −0.1 ≈ 全段血量 −5%）。
# ============================================================

# ============================================================
# v61（用户："对标现在正常1000级属性难度，阶梯式提升爬塔与游历难度"）
#
#   口径：**1000 级是属性天花板**（等级封顶 1000、突破 39 次、根骨固定），所以难度曲线
#   要"到第 1000 关左右刚好把满级队伍卡住"，再往后一档一档往上抬（无尽塔该有的样子）。
#
#   1000 级满配参考（按本作自己的公式算，未计装备百分比）：
#     少侠  攻 2047 · 血 4486     陈石  攻 1046 · 血 3477     苏青鸾 攻 1047 · 血 3482
#     （＝ 模板 + 999×(基础成长+根骨档) + 39 次突破）
#   于是目标定在**第 1000 关：敌血 ≈ 8000、敌攻 ≈ 400** ——
#     三人一回合能打掉 ~3500 → 一只杂兵 2~3 回合；敌攻 400 打满级少侠 ≈ 350/下 → 十多下才倒。
#
#   阶梯（这是"阶梯式"那一半）：**每 100 关一档**，档内走线性、档间乘系数——
#     血量 ×TIER_HP^n、攻击 ×TIER_ATK^n（n ＝ 关号/100 取整，第 1~100 关是第 0 档＝×1.0）
#     这样每一百关都有一段"明显变硬"的台阶，而不是一路糊上去。
#   标定完的曲线（本体，不含精英/首领；关号按下标算，血已含前期减负）：
#       关号     血 / 攻
#       1        55 / 5.0          （1 级新手两三下）
#       100      239 / 15.8
#       300      1074 / 48
#       500      2185 / 101
#       1000     8008 / 401        ← 满级队伍的分水岭
#       1500     22741 / 1242
#       2000     57780 / 3444      （这里开始"挨一下就掉半条命"）
#   墙（可打到的关号）大约落在 1300~1700 —— 想要更远/更近只改两个地方：
#     · 整体软硬：HP_LIN（每 −0.1 ≈ 全段 −5% 血）、ATK_LIN（每 −0.01 ≈ 全段 −12% 攻）
#     · 台阶陡不陡：TIER_HP / TIER_ATK（每档只乘一次，改 1.14→1.12 就是明显的松）
#   注意：离线挂机估算与手动打读的是同一份 enemy_at()，所以两边难度天然一致。
# ============================================================
const TIER_EVERY := 100         # 每多少关一个台阶
const TIER_HP := 1.10           # 每上一档：血量 ×1.10（v62h：1.14 → 1.10）
const TIER_ATK := 1.16          # 每上一档：攻击 ×1.16

# ============================================================
# ⚠ v38（用户："爬塔难度可以再降低一点点，前期 300 关我想让玩家很快拿到"）
#   v62h（用户："去掉300关减负 改为前200关减负"）：**只挪窗口、不动深度**——
#     减负段从"前 300 关"收成"前 200 关"（第 1 关 ×0.50 → 第 200 关 ×1.0，之后不减负）。
#     深度仍是 v38 那个 0.50：前期就是要"很快拿到"，200 关之后玩家已经起飞，
#     那一段不该再被削软（这也是收短窗口的目的）。
#   要更软/更硬：改 EARLY_HP_FROM（前期那一段）或 HP_LIN（全段）——
#     EARLY_HP_UNTIL 是"减负到第几关为止"，改它只挪拐点、不改后期。
# ============================================================
const EARLY_HP_UNTIL := 200     # 减负到这一关为止（之后 ×1.0 · v62h：300 → 200）
const EARLY_HP_FROM := 0.50     # 第 1 关的敌人气血系数（线性爬到 1.0 · v38 原值，没动）

# 第 i 关的"前期减负"系数（1.0 ＝ 不减）
static func early_hp_mul(i: int) -> float:
	if i >= EARLY_HP_UNTIL:
		return 1.0
	return lerpf(EARLY_HP_FROM, 1.0, float(maxi(0, i)) / float(EARLY_HP_UNTIL))

# v61：第 i 关属于第几档（每 TIER_EVERY 关进一档）
static func tier_of(i: int) -> int:
	return maxi(0, clampi(i, 0, STAGE_MAX - 1) / TIER_EVERY)
# ㊶ 速度：出手顺序用。基准跟主角们（9~12）同一量级，随关号慢慢变快，
#   但封顶在 SPEED_CAP——不然几百关后敌人永远先手，玩家堆速度也没意义。
#   想调"敌人先手有多频繁"只改这三个数。
# v63（用户："爬塔和游历怪有无速度 如果没有 请设置 对标角色"）：
#   旧口径 9~28 ✗ 而角色速度是 ~100 档 ✗ → 怪永远垫底、闪避口也按错数算 ✗。
#   改成**对标角色**：起步 88、随关数缓涨到 120 封顶（游历怪 88~110 同口径 ✓）。
const SPD_BASE := 88.0
const SPD_LIN := 0.02
const SPD_CAP := 120.0
# v63（用户："爬塔难度 增加档位 每400关提升20% 整体提升50%"）
const TIER400_PCT := 0.20        # 每 400 关一档：+20%（400/800/1200 三档）
# v63b（用户："爬塔难度整体下调 40%"）：1.5 × 0.6 = 0.9
# v80（用户："爬塔难度整体下调10%"）：0.9 → 0.81（再乘 0.9）
const GLOBAL_MUL := 0.81         # 整体系数（1.5 → 降40% → 0.9 → 再降10% → 0.81）
const HP_ELITE := 1.15          # 精英加码（原 1.5）
const HP_BOSS := 1.20           # 首领加码（原 2.4：那一下叠出 3.6 倍血池太长，现在交给"人多"）
const ATK_ELITE := 1.10         # 原 1.15
const ATK_BOSS := 1.15          # 原 1.35

# 每 5 关一章的名字（沿用原表；500 关 ＝ 100 章，章名循环用）
#   v57（用户："要一起换成暗器门派"）：第 5 章「铁棍门」→ **「袖箭门」**——
#   玩家的兵器线已经没有"棍"了（棍 → 暗器），这一门留着"棍"就成了断线。
const CHAPTERS := [
	"落草", "流寇", "黑风寨", "翻江", "袖箭门",
	"残党", "断魂谷", "铁旗堡", "血鹰崖", "天王寨",
]
# 每章的杂兵名（5 个一类：4 个小怪 + 第 5 位是首领位）
const CHAPTER_MOB := [
	["落草喽啰", "落草快手", "落草刀手", "落草镖手", "落草头目"],
	["流寇斥候", "流寇刀客", "流寇弩手", "流寇悍卒", "流寇首领"],
	["黑风哨探", "黑风刀手", "黑风枪手", "黑风掌旗", "黑风舵主"],
	["翻江水鬼", "翻江钩手", "翻江刀客", "翻江悍卒", "翻江龙王"],
	["袖箭门徒", "袖箭镖手", "袖箭护法", "袖箭针师", "袖箭门主"],
	["残党游骑", "残党精锐", "残党死士", "残党暗手", "残党魁首"],
	["断魂刀手", "断魂鬼影", "断魂弩手", "断魂桩主", "断魂谷主"],
	["铁旗卒", "铁旗刃卫", "铁旗弩卫", "铁旗掌旗", "铁旗堡主"],
	["血鹰斥候", "血鹰刀客", "血鹰钩手", "血鹰旗手", "血鹰崖主"],
	["天王精锐", "天王死士", "天王暗哨", "天王悍将", "天王寨主"],
]
# v57：**袖箭门的手下真的使暗器**——不绑的话他们还按 ENEMY_WEAPON（双刀）打，
#   "门派换成暗器"就只剩名字。键＝章号（跟章名/杂兵表一样循环用）；
#   `battle_lite` 从 `d["weapon"]` 取类型（见 battle_lite.gd:408 与 :1262），
#   所以这里的值就是 `stick_fighter` 认的**类型键**（不是卡 id）。
const CHAPTER_WEAPON := {4: "anqi"}

# ============================================================
# v58（用户："敌人的话400关之后给"）：**第 400 关起，敌人带五行**
#   口径：
#     · **按章定属性**（`chapter_idx % 5`）——一章一种，玩家能记住"这一章是火的"，
#       比一关一个乱摇更有"这一门派的武功路子"的味道；章名表 10 个一轮，所以属性也是 10 个一轮
#     · 给 `elem`（它打你就是**元素伤害**：不吃你的防御，走你的对应抗性、且**不能暴击**）
#     · 顺手给它**自己的属性抗性 30%**（火章怕水、不怕火）——于是"换一把兵器去打"有回报
#     · 400 关**之前一个字不动**（老手感的物理对拼照旧）
#   ⚠ 前 3 章（落草/流寇/黑风寨）在 400 关前早就循环过很多轮了，所以"第几章"看的是
#     循环后的下标，不是章名表的前三项。
# v86（用户：「爬塔800关以后加入元素怪」）：400 → **800**。
#   790 关之前都是纯物理（玩家还有一段「熟悉手感」的缓冲带），800 起每章换一种五行。
const ELEM_FROM_STAGE := 800        # 第 800 关（ti=799）起
const CHAPTER_ELEM := ["metal", "wood", "water", "fire", "earth"]
const FOE_OWN_RES := 30             # 对自己那一属性的抗性（百分点）
const FOE_ELEM_DMG := 0             # 敌人不打元素增伤那一份（要狠就抬这个数）
# 百章之后不写名字了：章号超过表长就加"第N轮"前缀，避免几百章重名分不清
const CHAPTER_REPEAT_TAG := "轮"   # 仅换代文案用（实际拼接见 chapter_of / _name_at）

# ============================================================
# ⚠ v46（用户："爬塔和游历的怪技能和大招倍率降低"）：首领/精英的招数与大招倍率整体下调约 25~30%——
#   大招 2.0~2.7 → 1.5~2.0；带追击的招数（mult+follow 两段）也一起压，理由：怪的招比玩家的武学还重，
#   玩家堆了防御/站位也扛不住"一发大招半条命"。只动怪的表（BOSS_ARTS_50 / BOSS_ULTS_50 /
#   BOSS_ART_TEMPLATES / BOSS_ULT_TEMPLATES），玩家武学（data_cards）一个字没碰。
#   口径：纯数值表，规则/血量/攻击/词缀/掉落一条没动——蓄势类 charge 的 mult 是"下一手更重"的
#   那个倍率，跟着一起压；护体（guard）与回气（heal）两条不涉及倍率，原样保留。
# ============================================================

# 前 50 关手写的首领招数（原 game_state.BOSS_ARTS，逐条搬来；键＝关号从 0 起）
const BOSS_ARTS_50 := {
	4: [
		{"name": "横劈乱砍", "target": "sweep", "kind": "damage", "mult": 1.15, "cd": 3, "desc": "抡圆了乱砍——架势难看，砸下来生疼"},
		{"name": "咧嘴怪叫", "kind": "charge", "mult": 1.3, "cd": 4, "desc": "怪叫壮胆——下一手更重"},
	],
	9: [
		{"name": "声东击西", "target": "mid", "kind": "dash", "mult": 0.9, "follow": 0.6, "cd": 3, "desc": "虚晃一刀，跟进一记快刀"},
		{"name": "缩身回气", "kind": "heal", "heal_pct": 0.2, "cd": 5, "desc": "缩到刀盾后缓一口气，回血两成"},
	],
	14: [
		{"name": "黑风刀法", "target": "sweep", "kind": "damage", "mult": 1.2, "cd": 3, "desc": "刀风发黑——寨里压箱底的刀法"},
		{"name": "横练护体", "kind": "guard", "turns": 2, "cut": 0.78, "cd": 5, "desc": "筋骨绷紧——此后两下挨打各减两成出头"},
	],
	19: [
		{"name": "翻江钩", "target": "mid", "kind": "damage", "mult": 1.25, "cd": 4, "desc": "沉钩上撩——挨着就见血"},
		{"name": "浪里回气", "kind": "heal", "heal_pct": 0.22, "cd": 5, "desc": "一个猛子扎进水气里回血"},
	],
	24: [
		# v57：原「铁棍横扫」——门派换成袖箭门，招也跟着换成暗器
		{"name": "袖箭连珠", "target": "sweep", "kind": "dash", "mult": 1.0, "follow": 0.65, "cd": 3, "desc": "袖中三箭连珠，一手接一手"},
		{"name": "蛮牛冲撞", "kind": "damage", "mult": 1.35, "cd": 4, "desc": "肩膀当锤使——撞上墙都塌"},
	],
	29: [
		{"name": "残影三连", "target": "mid", "kind": "dash", "mult": 1.05, "follow": 0.7, "cd": 3, "desc": "身影一晃三刀已到"},
		{"name": "龟息护体", "kind": "guard", "turns": 3, "cut": 0.75, "cd": 5, "desc": "气息一沉——此后三下挨打各减两成半"},
	],
	34: [
		{"name": "谷风乱刃", "target": "sweep", "kind": "damage", "mult": 1.2, "cd": 3, "desc": "谷风裹着乱刃卷过来"},
		{"name": "遁影回气", "kind": "heal", "heal_pct": 0.2, "cd": 5, "desc": "黑影一闪，退进谷雾里回口气"},
	],
	39: [
		{"name": "旗卷枪影", "target": "mid", "kind": "dash", "mult": 1.0, "follow": 0.65, "cd": 3, "desc": "大旗一卷，枪影跟着就到"},
		{"name": "铁堡横练", "kind": "guard", "turns": 2, "cut": 0.78, "cd": 5, "desc": "鼓力护身——此后两下挨打各减两成出头"},
	],
	44: [
		{"name": "鹰扑三击", "target": "mid", "kind": "dash", "mult": 1.05, "follow": 0.65, "cd": 3, "desc": "如鹰扑兔，三下连击"},
		{"name": "见血回气", "kind": "heal", "heal_pct": 0.22, "cd": 5, "desc": "舔血回气——伤越重气越顺"},
	],
	49: [
		{"name": "天王三叠", "target": "sweep", "kind": "dash", "mult": 1.05, "follow": 0.7, "cd": 3, "desc": "一掌三叠浪，后手更比前手沉"},
		{"name": "坐镇金刚", "kind": "guard", "turns": 3, "cut": 0.75, "cd": 5, "desc": "坐桩如金刚——此后三下挨打各减两成半"},
	],
}
const BOSS_ULTS_50 := {
	4: {"name": "落草号令", "target": "sweep", "mult": 1.5, "desc": "一声号令，刀风扑面"},
	9: {"name": "流寇突袭", "target": "sweep", "mult": 1.5, "desc": "招呼同伙一拥而上（单挑里就是全力一扑）"},
	14: {"name": "风卷残云", "mult": 1.6, "desc": "整个人卷成一道黑风压过来"},
	19: {"name": "巨浪拍岸", "target": "sweep", "mult": 1.6, "desc": "连人带钩压上来，势如大浪"},
	24: {"name": "漫天针雨", "target": "sweep", "mult": 1.7, "desc": "机簧一响，漫天都是针——无处可躲"},
	29: {"name": "卷土重来", "target": "sweep", "mult": 1.75, "desc": "寨子里最后的家底——倾巢一击"},
	34: {"name": "断魂一斩", "target": "mid", "mult": 1.7, "desc": "谷主出刀——一刀两断"},
	39: {"name": "铁旗压城", "target": "sweep", "mult": 1.75, "desc": "大旗当顶压下来"},
	44: {"name": "血鹰搏兔", "target": "mid", "mult": 1.75, "desc": "居高临下一记狠扑"},
	49: {"name": "天王盖地", "target": "sweep", "mult": 1.8, "desc": "最后一关的家底——倾巢一击"},
}

# 50 关往后的首领招数模板——按"首领档"循环取，倍率随档涨
# ⚠ v46：模板池跟着上面那张表一起压（攻招 mult/follow 同比例下调；护体/回气两条没倍率，不动）。
const BOSS_ART_TEMPLATES := [
	{"name": "连环重击", "target": "mid", "kind": "dash", "mult": 1.05, "follow": 0.7, "cd": 3, "desc": "一记接一记，越打越顺"},
	{"name": "沉身蓄力", "kind": "charge", "mult": 1.3, "cd": 4, "desc": "沉腰蓄势——下一手更重"},
	{"name": "金钟护体", "kind": "guard", "turns": 2, "cut": 0.78, "cd": 5, "desc": "气凝如钟——此后两下挨打各减两成出头"},
	{"name": "吐纳回气", "kind": "heal", "heal_pct": 0.22, "cd": 5, "desc": "退半步吐纳，回血两成有余"},
	{"name": "断岳一击", "target": "sweep", "kind": "damage", "mult": 1.4, "cd": 4, "desc": "倾力一击——中者骨裂"},
	# ============================================================
	# v52：**第 50 关往后**的首领开始带负面状态（前 50 关手写那套一个字没动——
	#   教学段不给玩家上状态）。倍率都压在同档之下：状态本身就是收益。
	#   状态表见 shared/data_status.gd；"apply" 的写法与武学那边完全一样。
	# ============================================================
	{"name": "焚身掌", "target": "front", "kind": "damage", "mult": 1.05, "cd": 4,
		"apply": {"id": "burn", "turns": 3, "stacks": 1},
		"desc": "掌上带火——中者「燃烧」三手，每手掉 3% 气血上限"},
	{"name": "锁脉手", "target": "front", "kind": "damage", "mult": 1.1, "cd": 4,
		"apply": {"id": "disarm", "turns": 2, "stacks": 1},
		"desc": "扣住脉门一拧——中者「缴械」两手，普攻使不出来"},
	{"name": "封穴指", "target": "front", "kind": "damage", "mult": 1.0, "cd": 5,
		"apply": {"id": "healseal", "turns": 2, "stacks": 1},
		"desc": "点在气海旁——中者「封脉」两手，回血只剩三成"},
	# v53：第二轮那几种负面也给首领配上两条（只给两条：一场里最多同时压住"普攻/武学/大招"里的两样，
	#   玩家手里永远还剩一条路——这是控制类负面的底线）
	{"name": "闭气针", "target": "front", "kind": "damage", "mult": 1.05, "cd": 4,
		"apply": {"id": "silence", "turns": 2, "stacks": 1},
		"desc": "针走暗处——中者「沉默」两手，武学放不出来"},
	{"name": "泄气掌", "target": "front", "kind": "damage", "mult": 1.0, "cd": 4,
		"apply": {"id": "ragecut", "turns": 3, "stacks": 1},
		"desc": "一掌拍散锐气——当场打掉 30 点怒气，此后三手怒气只剩四成"},
	# v54：**闭窍**——用户："闭窍是针对玩家的"。所以它只在首领这一侧，
	#   点住玩家的窍穴：自带天赋 / 被动功法（专武）/ 五问天赋 / 角色星 三条线全压住三手。
	#   玩家的解法是「清心诀」（洗掉负面）。
	{"name": "点窍手", "target": "front", "kind": "damage", "mult": 0.95, "cd": 5,
		"apply": {"id": "nopassive", "turns": 3, "stacks": 1},
		"desc": "点在你窍穴上——「闭窍」三手：你的自带天赋、被动功法、五问天赋、角色星全被压住"},
]
const BOSS_ULT_TEMPLATES := [
	{"name": "倾巢一击", "target": "sweep", "mult": 1.8, "desc": "压箱底的一手——全力压下"},
	{"name": "雷霆万钧", "target": "sweep", "mult": 1.9, "desc": "声势压人——避无可避"},
	{"name": "崩山式", "target": "sweep", "mult": 2.0, "desc": "一步踏碎青石，拳到人到"},
	# v52：大招也带状态——一场里挨一次就够难受了（横扫全场，人人中）
	{"name": "焚天一击", "target": "sweep", "mult": 1.75,
		"apply": {"id": "burn", "turns": 2, "stacks": 2},
		"desc": "火势铺天盖地——全场「燃烧」2 层，每手掉 10% 气血上限（只烧两手）"},
]

# ============================================================
# v36（用户定）：**宝箱**——咸鱼之王那套"每清一关攒一个箱子"
#
# 规矩：
#   · **每清一关给一个**（`stage_clear` 里发；手动打与挂机推都算——挂机回来一堆箱子）
#   · 品质跟关卡走：杂兵＝木箱，精英＝银箱，首领＝金箱，里程碑（精英＋首领同关）＝玉箱，
#     玉箱再往上还有一层龙箱（里程碑小概率出）——越往后关卡本身也越值钱
#   · 开箱：**先掷两次运气**（角色碎片 / 突破丹），再掷 `rolls` 次银两与炼丹材料
#   · 银两按**那一关的赏格 × 品质系数**给，所以第 1000 关的木箱也比第 10 关的厚
#
# ⚠ v43（用户："宝箱爆率太高了，片数给太多了，几率也给高了，突破丹也是——咸鱼的初始宝箱才 3%"）：
#   整张表按"**初始箱 3%**"这条尺子重排（咸鱼之王就是拿初始箱当基准的）：
#     碎片几率 10/18/28/38/55% → **3/5/8/14/25%**
#     碎片片数 2~5/4~9/8~16/15~30/30~60 → **1~2/2~3/3~5/5~9/8~16**
#     突破丹几率 0/5/12/20/32% → **0/1/2/4/8%**
#   实测（清关模拟，`_probe_chest_rate` 量的）：清 100 关的碎片期望 75.7 → **8.7 片**、
#     突破丹 1.63 → **0.31 颗**；清 300 关 268.6 → **31.1 片**、5.57 → **1.1 颗**。
#   **银两与材料那一份一点没动**（突破要花银两，这是它的正路）。
#   想再松/再紧：只改下面 `frag_chance`/`frag`/`pill_chance` 三列即可。
#
# ⚠ v44（用户："突破丹的几率可以给高一点，**比碎片高就行**"）：
#   只动 `pill_chance` 一列——每一档都压过同档的碎片几率一头（丹 > 片）：
#     突破丹几率 0/1/2/4/8% → **4/7/10/17/30%**
#   实测（同一份模拟，400 趟平均；纯模拟不碰存档）：
#     清 100 关：突破丹 0.37 → **4.9 颗**（凡 3.6 / 良 0.9 / 上 0.3 / 极 0.1）｜碎片 ~9.7 片没动
#     清 300 关：1.17 → **15.3 颗**（凡 11.3 / 良 2.6 / 上 0.8 / 极 0.5 / 绝 0.1）｜碎片 ~28.6 片
#     清 1000 关：3.63 → **51.6 颗**（凡 38.3 / 良 9.0 / 上 2.5 / 极 1.4 / 绝 0.3）｜碎片 ~96 片
#   单箱期望（开 10000 个）：木 0.041 · 银 0.068 · 金 0.098 · 玉 0.174 · 龙 0.289 颗
#   ⚠ 为什么"丹比片还多"不亏：碎片一个掉落是 1~16 片、突破丹一次只 1 颗，
#     且丹**按境界分品**（凡品只在境界 1~8 有用，龙箱才出绝品）——稀的是高品那几档。
# ============================================================
const CHESTS := [
	# v62（用户："突破丹权重略微降低"）：`pill_chance` 整体 **×0.8**（略微，不是砍半）：
	#   0.04→0.03 · 0.07→0.06 · 0.10→0.08 · 0.17→0.14 · 0.30→0.24
	#   理由：突破丹现在是**最硬的那道进度闸**（一个人满突破要 603 颗，v62 定），
	#   宝箱只是它的补充来路（主路是炼丹阁自己炼）——所以只轻轻收一点，别把闸门焊死。
	#
	# v133（用户："开宝箱给武学残页残兵 但是比角色碎片几率低 宝箱品质不同 给的残页品质也不同"
	#    ＋"也给残装备"）：每一档再加**三条残卡线**，三条的几率**一律低于角色碎片**：
	#     page_chance  武学残页（pool "arts"）
	#     blade_chance 残兵残卡（pool "weapon"）
	#     gear_chance  残装备残片（pool armor / helm / cloak 三池合一）
	#   · **品质跟着箱子走**：木凡 · 银良 · 金上 · 玉极 · 龙绝（就是 `grad`，与 QUALITY_ORDER 同下标）；
	#   · 一次给**同一套的 n 页**（页不重复）——凑齐了在仓库合成整件；n 看 `page_n/blade_n/gear_n`；
	#   · 专武（no_drop）永不进宝箱池（见 chest_card_pool）。
	#   ⚠ 改动这三条只动下面每个箱子的那两行（chance 与 [_n]）；池子由 chest_card_pool 现算。
	#
	# v134（用户："突破丹炼丹材料增加 爆率降低"）：**少而厚**——出现的几率降下来，一次给的量抬上去。
	#   · 突破丹：几率**砍半上下**（3/5.5/8/14/24% → 1.5/2.8/4/6/10%）；
	#     ⚠ **v137 再改（用户："宝箱突破丹 一次也只给一颗"）**：`pill_n` 全部锁成 **[1, 1]**——
	#       现在一箱命中就一颗（原来 2~5 颗）。几率**不再动**（还是 v134 砍过的那几个数），
	#       所以突破丹的每箱期望回到 **0.015/0.028/0.04/0.06/0.10 颗**（比 v134 低约 60~75%）。
	#       嫌太干就把 `pill_chance` 抬回去（只动这一列）；
	#   · 炼丹材料：每一掷的命中率 `mat_chance` 45% → **30%**（少了三分之一），
	#     但一次给 `mat_n` 翻倍（如龙箱 3~7 → 6~12）→ 总期望 **+20%~+33%**。
	#   ⚠ 两条都是"单次更厚、出现更少"：手感上从"每箱都掉一点"变成"隔几箱掉一堆"。
	# v137（用户："宝箱残页再次降低80% 一次最多一页"）：三条残卡线的几率**再 ×0.2**（再降 80%），
	#   且 `*_n` 一律锁成 **[1, 1]**（一次最多一页）。
	#   改前 → 改后（残页 / 残兵 / 残装备）：
	#     木 2.0/1.5/1.5% → **0.4/0.3/0.3%**　银 3.2/2.4/2.4% → **0.64/0.48/0.48%**
	#     金 5.0/3.8/3.8% → **1.0/0.8/0.8%**　玉 9.0/6.8/6.8% → **1.8/1.4/1.4%**
	#     龙 16/12/12% → **3.2/2.4/2.4%**
	#   ⚠ 这么一来残卡只剩"细水长流"——**整品的主路是追剿的 boss 赏与爬塔首领赏**，
	#     宝箱这条线是补充。嫌太稀就把这六个数一起抬（都是同一把尺）。
	{"id": "wood", "name": "木箱", "grad": 0, "rolls": 2, "silver_mul": 0.6,
		"frag_chance": 0.01, "frag": [1, 2], "mat_chance": 0.55, "mat_n": [2, 4],
		"pill_chance": 0.01, "pill_n": [1, 1], "pills": ["tupo_fan"],
		"page_chance": 0.002, "page_n": [1, 1],
		"blade_chance": 0.0, "blade_n": [1, 1],
		"gear_chance": 0.0, "gear_n": [1, 1]},
	{"id": "iron", "name": "银箱", "grad": 1, "rolls": 3, "silver_mul": 1.0,
		"frag_chance": 0.015, "frag": [2, 3], "mat_chance": 0.55, "mat_n": [3, 5],
		"pill_chance": 0.02, "pill_n": [1, 1], "pills": ["tupo_fan", "tupo_liang"],
		"page_chance": 0.003, "page_n": [1, 1],
		"blade_chance": 0.0, "blade_n": [1, 1],
		"gear_chance": 0.0, "gear_n": [1, 1]},
	{"id": "gold", "name": "金箱", "grad": 2, "rolls": 4, "silver_mul": 1.6,
		"frag_chance": 0.02, "frag": [3, 5], "mat_chance": 0.55, "mat_n": [4, 7],
		"pill_chance": 0.03, "pill_n": [1, 1], "pills": ["tupo_fan", "tupo_liang", "tupo_shang"],
		"page_chance": 0.005, "page_n": [1, 1],
		"blade_chance": 0.0, "blade_n": [1, 1],
		"gear_chance": 0.0, "gear_n": [1, 1]},
	{"id": "jade", "name": "玉箱", "grad": 3, "rolls": 5, "silver_mul": 2.4,
		"frag_chance": 0.03, "frag": [5, 9], "mat_chance": 0.55, "mat_n": [5, 9],
		"pill_chance": 0.05, "pill_n": [1, 1], "pills": ["tupo_liang", "tupo_shang", "tupo_ji"],
		"page_chance": 0.008, "page_n": [1, 1],
		"blade_chance": 0.0, "blade_n": [1, 1],
		"gear_chance": 0.0, "gear_n": [1, 1]},
	{"id": "dragon", "name": "龙箱", "grad": 4, "rolls": 6, "silver_mul": 3.5,
		"frag_chance": 0.05, "frag": [8, 16], "mat_chance": 0.55, "mat_n": [6, 12],
		"pill_chance": 0.08, "pill_n": [1, 1], "pills": ["tupo_shang", "tupo_ji", "tupo_jue"],
		"page_chance": 0.012, "page_n": [1, 1],
		"blade_chance": 0.0, "blade_n": [1, 1],
		"gear_chance": 0.0, "gear_n": [1, 1]},
]

# v133：宝箱那三条残卡线各取哪个池（"gear" 是三池合一）
const CHEST_CARD_POOLS := {"arts": ["arts"], "weapon": ["weapon"], "gear": ["armor", "helm", "cloak"]}

# v133：这一档箱子的残卡池——**按品级现算**（grad 就是品级下标），专武不进池。
#   返回一套的 id 数组；空数组＝这一档这一类没内容（调用方跳过）。
#   ⚠ 空档回退：某一档若一门都没有，就**往下退一档**再取（退到有货为止）。
#     v137 起护甲/玉佩/披风也有绝品了（龙鳞宝甲/混元玉璧/流云飞氅），所以龙箱的残装备
#     拿的就是"绝品残片"；这条回退留着当保险（以后哪一档空了也不会白掷）。
static func chest_card_pool(kind: String, grad: int) -> Array:
	var pools: Array = CHEST_CARD_POOLS.get(kind, [])
	var q := clampi(grad, 0, Cards.QUALITY_ORDER.size() - 1)
	while q >= 0:
		var out: Array = []
		for s in Cards.SETS:
			if not pools.has(str(s.get("pool", ""))):
				continue
			if bool(s.get("no_drop", false)):
				continue
			if Cards.q_idx(str(s["id"])) != q:
				continue
			out.append(str(s["id"]))
		if not out.is_empty():
			return out
		q -= 1
	return []
# 材料权重（开箱那几掷在这个池子里挑；键＝game_state.MAT_CN 的键）
# v121（用户："突破境界需要很多材料【增加新材料】"）：境界石 / 道心砂 从宝箱出（进阶专用）
const CHEST_MATS := {"zhi": 8, "guo": 8, "shen": 6, "bone": 6, "rice": 3, "jin": 1,
	"forge_stone": 70, "jingshi": 2, "daoxin": 1, "daoguo": 1, "hundun": 1, "xinghui": 1,
	"pojing": 1, "xuantie": 1, "soul": 1, "lingguo": 1, "atlas": 1,
	"iron_sand": 12, "bone_coal": 8, "forge_oil": 3, "fine_iron": 2, "meteor_iron": 1, "star_iron": 1}
#   ⚠ v41：`jin`（金髓）是**稀有金色材料**——洗髓丹/洗灵丹的硬门槛，所以权重压到 3（约 3%）。
#     想让它更好出就抬这个数；它同时也是货栈每日限购那件（900 两、日限 1）。

static func chest_def(cid: String) -> Dictionary:
	for c in CHESTS:
		if str(c["id"]) == cid:
			return c
	return {}

static func chest_name(cid: String) -> String:
	var d := chest_def(cid)
	return str(d.get("name", cid)) if not d.is_empty() else cid

# 这一关给什么箱子
#
# v139（用户："玉宝箱爆率大幅降低 而龙宝箱只有爬塔和追缴的boss关才会爆"）：
#   · **玉箱大幅降低**：里程碑 85%→**30%**、首领关 20%→**10%**（金箱接走那部分）；
#   · **龙箱只在首领关出**：里程碑 15% 保留，另外**每个首领关**加一条 2% 的小口
#     （以前只有"首领＋精英"那种里程碑关才有龙箱）——精英关/杂兵关永远不出龙。
#   实测（每 50 关的期望）：玉 1.25 → **0.50** 个（−60%）；龙 0.15 → **0.19** 个（且只从首领关出）。
static func chest_for_stage(i: int) -> String:
	var boss := is_boss(i)
	var elite := is_elite(i)
	if boss and elite:
		# 里程碑（每 50 关）：龙 15% · 玉 30% · 金 55%
		var r := randf()
		if r < 0.15:
			return "dragon"
		if r < 0.45:
			return "jade"
		return "gold"
	if boss:
		# 首领关（每 25 关）：龙 2% · 玉 10% · 金 88%
		var r2 := randf()
		if r2 < 0.02:
			return "dragon"
		if r2 < 0.12:
			return "jade"
		return "gold"
	if elite:
		# 精英关（每 10 关）：金 10% · 银 90%（原来 20% 金）
		return "gold" if randf() < 0.10 else "iron"
	# 杂兵关：银 15% · 木 85%（没动）
	return "iron" if randf() < 0.15 else "wood"

# 一个箱子里的银两总额（按"那一关的赏格 × 品质系数"，掷 rolls 次就乘 rolls）
static func chest_silver_total(i: int, cid: String) -> int:
	var d := chest_def(cid)
	if d.is_empty():
		return 0
	var per := float(stage_silver(i)) * float(d.get("silver_mul", 1.0))
	return maxi(1, int(round(per * float(d.get("rolls", 1)))))

# 材料池按权重挑一个（纯数据，不开箱——开箱在 game_state 里落账）
# 箱子品质越高，越容易出稀有锻造 / 炼丹材料；木箱基本是铁矿砂、骨炭和普通药草。
static func chest_roll_mat(grade := 0) -> String:
	var pool: Dictionary = CHEST_MATS.duplicate()
	if int(grade) <= 1:
		pool["star_iron"] = 0
		pool["fine_iron"] = 0
		pool["meteor_iron"] = 0
		pool["jin"] = 0
		pool["forge_oil"] = 0
		pool["iron_sand"] = 22
		pool["bone_coal"] = 16
	elif int(grade) == 2:
		pool["star_iron"] = 1
		pool["fine_iron"] = 5
		pool["meteor_iron"] = 3
		pool["forge_oil"] = 6
		pool["iron_sand"] = 12
		pool["bone_coal"] = 9
	else:
		pool["star_iron"] = 5
		pool["fine_iron"] = 9
		pool["meteor_iron"] = 6
		pool["forge_oil"] = 9
		pool["jin"] = 4
		pool["shen"] = 10
	var total := 0
	for k in pool.keys():
		total += int(pool[k])
	if total <= 0:
		return "wood"
	var r := randi() % total
	for k2 in pool.keys():
		r -= int(pool[k2])
		if r < 0:
			return str(k2)
	return "wood"

# 一行摘要（面板/日志）
static func chest_line() -> String:
	return "木箱/银箱/金箱/玉箱/龙箱 —— 杂兵、精英、首领、里程碑各给各的"

# ---- 判定 ----

# 首领/精英：按所在段取间隔。全塔统一规则，没有"旧规则区"。
static func _every(i: int, early: int, mid: int, late: int) -> int:
	if i < MID_FROM:
		return early
	if i < LATE_FROM:
		return mid
	return late

static func is_boss(i: int) -> bool:
	var ti := clampi(i, 0, STAGE_MAX - 1)
	return ((ti + 1) % _every(ti, BOSS_EVERY_EARLY, BOSS_EVERY_MID, BOSS_EVERY_LATE)) == 0

static func is_elite(i: int) -> bool:
	var ti := clampi(i, 0, STAGE_MAX - 1)
	# 精英与首领各自独立：两个间隔的公倍数关两个都算——它是里程碑，
	# 血量吃两份加码、赏也吃两份，正合适，不做互斥。
	return ((ti + 1) % _every(ti, ELITE_EVERY_EARLY, ELITE_EVERY_MID, ELITE_EVERY_LATE)) == 0

# 这是第几个首领（从 1 起）。段间隔不一样，所以按段累计，不能直接除。
static func boss_ordinal(i: int) -> int:
	var ti := clampi(i, 0, STAGE_MAX - 1)
	var n := 0
	if ti >= LATE_FROM:
		n += (LATE_FROM / BOSS_EVERY_MID) - (MID_FROM / BOSS_EVERY_MID)
		n += ((ti + 1) / BOSS_EVERY_LATE) - (LATE_FROM / BOSS_EVERY_LATE)
	elif ti >= MID_FROM:
		n += (MID_FROM / BOSS_EVERY_EARLY)
		n += ((ti + 1) / BOSS_EVERY_MID) - (MID_FROM / BOSS_EVERY_MID)
	else:
		n += (ti + 1) / BOSS_EVERY_EARLY
	return maxi(1, n)

# 章号（从 0 起）
static func chapter_idx(i: int) -> int:
	return clampi(i, 0, STAGE_MAX - 1) / 5

static func chapter_of(i: int) -> String:
	var ci := chapter_idx(i)
	var base := str(CHAPTERS[ci % CHAPTERS.size()])
	if ci >= CHAPTERS.size():
		# 第 11 章往后：章名循环用，前面加"第N轮"——
		# 20000 关＝4000 章，不加以区分的话满屏都是重名。
		return "第" + str(ci / CHAPTERS.size() + 1) + "轮·" + base
	return base

# ============================================================
# 敌人
# ============================================================

static func _name_at(ti: int) -> String:
	var ci := chapter_idx(ti)
	var pos := ti % 5
	var row: Array = CHAPTER_MOB[ci % CHAPTER_MOB.size()]
	var nm := str(row[clampi(pos, 0, row.size() - 1)])
	if ci >= CHAPTER_MOB.size():
		nm = "第" + str(ci / CHAPTER_MOB.size() + 1) + "轮" + nm
	return nm

static func enemy_at(i: int) -> Dictionary:
	var ti := clampi(i, 0, STAGE_MAX - 1)
	var boss := is_boss(ti)
	var elite := is_elite(ti)
	var f := float(ti)

	# 线性 × 小幅复利：每关都在变强，后期再拉开
	# v38：前 300 关再乘一条递减的减负曲线（见 EARLY_HP_*）——只压前期，后期不动
	# v61：再乘**阶梯系数**（每 100 关一档，见上面那段说明）——这是"阶梯式提升难度"的落点
	var tier_n := tier_of(ti)
	var hp := (HP_BASE + HP_LIN * f) * pow(HP_GROW, f) * early_hp_mul(ti) * pow(TIER_HP, float(tier_n))
	var atk := (ATK_BASE + ATK_LIN * f) * pow(ATK_GROW, f) * pow(TIER_ATK, float(tier_n))
	# v63（用户："爬塔难度 增加档位 每400关 提升20% 整体提升50%"）：
	#   · **每 400 关一档**：400+ ×1.2 · 800+ ×1.4 · 1200+ ×1.6
	#   · **整体 ×1.5**（GLOBAL_MUL）——两条都在基础曲线上乘，精英/首领加码照旧叠在上面
	var tier400 := 1.0 + TIER400_PCT * float(ti / 400)
	hp *= tier400 * GLOBAL_MUL
	atk *= tier400 * GLOBAL_MUL
	# 精英/首领加码（两个都算时两份都吃：第 50 关那种里程碑）
	if elite:
		hp *= HP_ELITE
		atk *= ATK_ELITE
	if boss:
		hp *= HP_BOSS
		atk *= ATK_BOSS

	var nm := _name_at(ti)
	if boss:
		nm = "【首领】" + nm
	elif elite:
		nm = "【精英】" + nm

	var out := {
		"name": nm,
		"hp": maxi(1, int(round(hp))),
		"atk": maxi(1, int(round(atk))),
		"spd": int(round(minf(SPD_CAP, SPD_BASE + SPD_LIN * f))),   # ㊶：出手顺序用
		# v35：防御值——攻防对拼要用它（没写就是按攻击折一半，见 GameData.foe_def）。
		#   它同时是"我打过去"那一下的守方数值，离线估算也读同一份。
		"def": GameData.foe_def(atk),
		"boss": boss,
		"elite": elite,
		"chapter": chapter_of(ti),
	}
	if boss:
		var tier := boss_ordinal(ti)          # 第几个首领（从 1 起）
		if BOSS_ARTS_50.has(ti):
			out["arts"] = (BOSS_ARTS_50[ti] as Array).duplicate(true)
			out["ult"] = (BOSS_ULTS_50[ti] as Dictionary).duplicate(true)
		else:
			# 50 关往后：从模板池按档取两招一大招，倍率随档位抬
			var k := float(tier - 1)
			var a1: Dictionary = (BOSS_ART_TEMPLATES[ti % BOSS_ART_TEMPLATES.size()] as Dictionary).duplicate(true)
			var a2: Dictionary = (BOSS_ART_TEMPLATES[(ti + 2) % BOSS_ART_TEMPLATES.size()] as Dictionary).duplicate(true)
			var boost := 1.0 + 0.06 * minf(k, 12.0)
			for a in [a1, a2]:
				var d: Dictionary = a
				if d.has("mult"):
					d["mult"] = snappedf(float(d["mult"]) * boost, 0.01)
			var u: Dictionary = (BOSS_ULT_TEMPLATES[ti % BOSS_ULT_TEMPLATES.size()] as Dictionary).duplicate(true)
			u["mult"] = snappedf(float(u.get("mult", 2.5)) * (1.0 + 0.04 * minf(k, 15.0)), 0.01)
			out["arts"] = [a1, a2]
			out["ult"] = u
	# 词缀：第 4 关起有；精英/首领多一条；第 3 章起再多一条（至多 3 条）
	if ti >= 3:
		var n := 1
		if elite or boss:
			n += 1
		if chapter_idx(ti) >= 3:
			n += 1
		out["affix_n"] = mini(n, 3)
	# v57：袖箭门那一章的手里是暗器（类型键，见 CHAPTER_WEAPON 那段注释）。
	#   ⚠ 放在最后、且只在有值时写——没写这一键的怪照旧吃 ENEMY_WEAPON 的默认。
	var cw: String = str(CHAPTER_WEAPON.get(chapter_idx(ti) % CHAPTER_MOB.size(), ""))
	if cw != "":
		out["weapon"] = cw
	# v58：第 400 关起敌人带五行（见上面那几行的口径注释）
	if ti + 1 >= ELEM_FROM_STAGE:
		var fe: String = str(CHAPTER_ELEM[chapter_idx(ti) % CHAPTER_ELEM.size()])
		out["elem"] = fe                      # 打你就是元素伤害（不吃你的防御、走抗性、不可暴击）
		out[fe + "_res"] = FOE_OWN_RES        # 自己的属性抗 30%（火章怕水）
		if FOE_ELEM_DMG > 0:
			out[fe + "_dmg"] = FOE_ELEM_DMG
	return out

# ============================================================
# 收益（㉞：总关数从 50 涨到 500 —— 每关实发按曲线递减，
#   但关号越大给得越多，所以总量仍是涨的）
# ============================================================

# 每关银两：基础随关号涨，但"每关涨幅"被压低（分摊到更多关）
# v61（用户："降低70%银两"）：SILVER_MUL 0.5 → **0.15**（＝整体砍 70%）。
#   ⚠ 这一个旋钮**同时管三处**，因为它们同源：
#     · 清关赏 stage_silver()            · 首领赏 boss_silver_gain()
#     · 宝箱银两 chest_silver_total()（＝ stage_silver × 箱子系数 × 掷数）
#   实测（改前）：清 100 关在 300 关附近给 1.28 万两、其中宝箱占 71%。
#   改后同区间 ≈ 0.38 万两；满突破（35.48 万两/人）从"约 28 个百关"变成"约 93 个百关"。
const SILVER_BASE := 8.0
const SILVER_GROW := 0.22       # 每关 +0.22（原表是每关 +5，摊薄后小得多）
const SILVER_MUL := 0.1125          # v62m：0.15 → 0.1125（银两收益再砍 25%，含宝箱）        # v61：0.5 → 0.15（银两整体 −70%）
const SILVER_ELITE_MUL := 2.5   # 精英关
const BOSS_SILVER := 20         # 首领赏原值
const BOSS_SILVER_GROW := 0.5   # 首领赏随档涨

static func stage_silver(i: int) -> int:
	var ti := clampi(i, 0, STAGE_MAX - 1)
	var v := (SILVER_BASE + SILVER_GROW * float(ti)) * SILVER_MUL
	if is_elite(ti):
		v *= SILVER_ELITE_MUL
	return maxi(1, int(round(v)))

static func boss_silver_gain(i := 0) -> int:
	var ti := clampi(i, 0, STAGE_MAX - 1)
	var tier := float(boss_ordinal(ti))
	var v := (float(BOSS_SILVER) + BOSS_SILVER_GROW * tier) * SILVER_MUL
	return maxi(1, int(round(v)))

# 每关经验：同样摊薄
# v61（用户："经验收益降低40%"）：经验**统一乘 EXP_INCOME_MUL**。
#   这一乘放在 stage_exp() 里，所以"面板上写的 +N"就是"实发的那份"，不会显示与到账两张皮。
#   挂机经验在 game_state.idle_exp_rate() 里乘同一个数；木料折经验那一份
#   （STAGE_EXP_BONUS）与看火经验（ALCHEMY_TEND_EXP）也一起折。
#
# ============================================================
# v62（用户："经验可能还要砍 没改之前 冲到了4000关 十多万的银两 700级 也就4个小时 这个你看着来 实在太快了"）
#
#   先把账算清（每人每关的经验）：
#       0.6×(24 + 0.5×关号) + 18(木料折经验)        ← v61 那版
#   问题不在"总量"，在**斜率**：每关经验随关号线性涨，4000 关时一关就 2000+ ，
#   三个人一起算就是 6000+/关——越往后越快，于是"4 小时 700 级"。
#   而升级要的经验只是**随等级线性**涨（40 + 20×等级），追不上这条斜率。
#
#   所以这一刀砍在斜率上，顺带再收总量：
#     · EXP_GROW       0.5  → **0.25**   ｜ 关号带来的经验增长砍半（高关不再滚雪球）
#     · EXP_INCOME_MUL 0.6  → **0.45**   ｜ 总量再 −25%（叠上 v61 那次＝比最初 −75%）
#     · STAGE_EXP_BONUS 18  → **12**     ｜ 木料折经验跟着收
#     · ALCHEMY_TEND_EXP 12 → **9**      ｜ 看火经验跟着收
#
#   实测（每人，清关 1→4000 关的总经验）：
#       最初 ≈ 4,160,000（≈700 级）｜ v61 ≈ 2,529,000（≈500 级）｜ **现在 ≈ 990,000（≈330 级）**
#   前期基本不动（1~100 关只慢两成），砍的是后期那条飞起来的曲线。
#   嫌快嫌慢：动 EXP_GROW（斜率）与 EXP_INCOME_MUL（总量）这两个数就够。
# ============================================================
const EXP_BASE := 24.0
const EXP_GROW := 0.25          # v62：0.5 → 0.25（每关经验的增长斜率减半）
const EXP_ELITE_MUL := 2.0
const EXP_INCOME_MUL := 0.3375      # v62m：0.45 → 0.3375（经验收益再砍 25%）    # v62：0.6 → 0.45（叠上 v61 的 0.6，比最初 −75%）

static func stage_exp(i: int) -> int:
	var ti := clampi(i, 0, STAGE_MAX - 1)
	var v := (EXP_BASE + EXP_GROW * float(ti)) * EXP_INCOME_MUL
	if is_elite(ti):
		v *= EXP_ELITE_MUL
	return maxi(1, int(round(v)))

# ============================================================
# ㊱ 首领赏：装备/兵器/功法（大奖改版）
#
# 旧版：逢五关给一件，品级按章号开，第 400 关就封顶绝品——
#   20000 关的塔里，第 400 关之后的 19600 关"大奖"全是绝品，等于没有奖。
#
# 新版规矩（就是"把线做长"）：
#   · **只有首领给**（普通关、精英关都不给）——首领才配掉装备/兵器/功法
#   · **每一品级的每一件，都要至少给过一次**，这一级才算发完 → 再升下一级
#   · **凡品给成品**（整套直接进仓库）
#   · **良品起给残页**（一张一张给，凑齐自己合）—— 这是"线拉长"的关键：
#       一件 3~7 页，等于同一件要发 3~7 次首领才凑得齐
#   · **绝品不开放**：只发到极品为止（绝品留给"搜刮越阶"那条路，不白送）
#   · 极品也发完之后：从凡品重来一轮 —— **想更长就加池子**（往 data_cards
#     添新套装），池子越大一轮越长，代码这边不用改
#
# 实算这条线（按现在 data_cards 的件数）：凡品/良品/上品/极品各 12 件。
#   凡品一轮 12 次首领；良品起每件平均 3~4 页 → 每级约 40 次；
#   四级合计约 150~250 次首领赏。首领每 25/50 关一个 → 约 6000 关上下。
#
# 记档：GameState.tower_gifts（已给过的 sid 列表，存 save.cfg）。
# ============================================================

# 发放的最高品级：0=凡品 1=良品 2=上品 3=极品（4=绝品，**不开放**）
const GIFT_TIER_MAX := 3

# 这一品级是否给成品（凡品给整套；良品起给残页）
static func gift_is_complete(tier: int) -> bool:
	return tier <= 0

# 当前该发第几品：按"已发过多少件"推——发满一类的量就升一档
static func gift_tier_of(given_count: int) -> int:
	var tier := 0
	var left := given_count
	while tier < GIFT_TIER_MAX:
		var n := _tier_size(tier)
		if n <= 0:
			break
		if left < n:
			return tier
		left -= n
		tier += 1
	return GIFT_TIER_MAX

# 某一品级一共有多少件（三类合计）——用来算"发多少件才升档"
static func _tier_size(tier: int) -> int:
	var n := 0
	for s in Cards.SETS:
		if Cards.q_idx(str(s["id"])) == tier:
			n += 1
	return n

# 挑一件还没发过的；given 是已给过的 sid 数组。
# 只在 0~GIFT_TIER_MAX 之间找；绝品永不入选。
# 返回 {"sid", "tier", "complete"}；全发完返回 {}。
static func gift_pick(given: Array) -> Dictionary:
	var start_tier := gift_tier_of(given.size())
	for step in GIFT_TIER_MAX + 1:
		var tier := start_tier + step
		if tier > GIFT_TIER_MAX:
			# 极品也发完了：从凡品重来一轮（想更长就加池子）
			tier = tier - (GIFT_TIER_MAX + 1)
		var cand: Array = []
		for s in Cards.SETS:
			var sid := str(s["id"])
			if Cards.q_idx(sid) != tier:
				continue
			if given.has(sid):
				continue
			cand.append(sid)
		if not cand.is_empty():
			return {
				"sid": str(cand[randi() % cand.size()]),
				"tier": tier,
				"complete": gift_is_complete(tier),
			}
	return {}

# ============================================================
# ㊳ 残页按顺序发（不挑页）
#
# 上一版让"缺哪页补哪页"，看着聪明其实没必要——反而打乱顺序、不好预期。
# 现在最简单也最稳：**一件一件来，页也一页一页来**。
#   正在发的那一件（还没凑齐）优先继续发，接着发它的下一未满页；
#   凑齐了才开新的一件。
# 这样保证两件事：
#   · 每件都一定凑得齐（不会永远卡在缺某页）
#   · 顺序可预期，玩家看得出"还差几页"
# ============================================================

# 挑这一轮要发的东西。given = 已"给过"的 sid 列表；have_of = func(sid) -> Array（各页已有数）。
# 返回 {"sid", "tier", "part", "complete", "done"}；done=true 表示这套这一页是最后缺的一页。
# complete=true 表示"给整套"（凡品档）。
static func gift_next(given: Array, have_of: Callable) -> Dictionary:
	# ① 先看"正在发的那一件"还有没有没满的页——有就接着发它
	if not given.is_empty():
		var cur := str(given[given.size() - 1])
		if Cards.q_idx(cur) <= GIFT_TIER_MAX:
			var parts: int = maxi(1, Cards.part_count(cur))
			var have: Array = have_of.call(cur)
			for p in parts:
				var c := 0
				if p < have.size():
					c = int(have[p])
				if c <= 0:
					# 这一页还没给过 → 就发它（顺序发＝从前往后找第一个缺的）
					return {
						"sid": cur,
						"tier": Cards.q_idx(cur),
						"part": p,
						"complete": false,
						"done": _count_empty(cur, have) <= 1,
					}
	# ② 没有在发的了 → 开新的一件（先补当前档里没给过的）
	var pick := gift_pick(given)
	if pick.is_empty():
		return {}
	var sid := str(pick.get("sid", ""))
	if bool(pick.get("complete", false)):
		# 凡品：整套直接给，没有"页"这回事
		return {"sid": sid, "tier": int(pick.get("tier", 0)), "part": -1, "complete": true, "done": true}
	# 残页档：新开一件，从第一页开始
	return {"sid": sid, "tier": int(pick.get("tier", 0)), "part": 0, "complete": false, "done": false}

# 这套还有几页是空的（用来判断"这一页给完就齐了"）
static func _count_empty(sid: String, have: Array) -> int:
	var parts: int = maxi(1, Cards.part_count(sid))
	var n := 0
	for p in parts:
		var c := 0
		if p < have.size():
			c = int(have[p])
		if c <= 0:
			n += 1
	return n

# ============================================================
# ㊵ 离线/后台自动爬塔
#
# 玩法：人不在的时候，按"正常打一关要多久"逐关往上推；**打不过就卡在当前关**
#   （跟咸鱼之王那类挂机塔一个意思），不倒退、不跳关。
#
# 怎么估：
#   ① 我方每回合输出 ≈ Σ(成员攻击 × 兵器距离之类的加成) × 暴击期望
#      ——不算精确模拟，只要量级对得上就够了（离线本来就是估算）
#   ② 一关的时长 ＝ 打死它要几回合 → 换算成秒（TURN_SEC 与 battle_lite.STEP 对齐）
#   ③ 从当前关开始，一关一关扣时间预算；碰上"打不过"或"时间不够"就停
#
# 打不打得过用 can_beat 判：自己死之前能不能打死它（留 1.15 倍余量）。
# 估算终究是估算——所以离线只推**普通关卡**，碰到首领/精英也照样打
#   （它们的血攻都在 enemy_at 里，估出来自然更久），不做特殊处理。
#
# 调用方（game_state）负责：给预算秒数、给一个"结算这一关"的回调、拿到推进结果。
# ============================================================

# 一次离线最多推多少关（防止极端数值下一口气推到天上去）
const OFFLINE_MAX_STAGES := 300

# ㊿：词缀给"我方挨打压力"的粗估倍数。
#   ⚠ 离线估算以前**完全没算词缀**：狂暴（半血 ×1.6）、鼓舞（每手 +6%，最多 +60%）、
#     战意（每挨一下 +8%，最多 +80%）、速攻、毒刃… 一个都没进 can_beat。
#     于是"挂机推过的关，手动打不过"——这次补上（表在下面，嫌松/嫌紧改这一张）。
static func pressure_mul(e: Dictionary) -> float:
	var m := 1.0
	for af_v in e.get("affixes", []):
		match str(af_v):
			"berserk": m += 0.20      # 半血以下 ×1.6，整场折两成
			"rally":   m += 0.22      # 每出一手 +6%，叠到 +60%
			"fury":    m += 0.22      # 每挨一下 +8%，叠到 +80%
			"swift":   m += 0.16      # 每第 3 手追一记六成力
			"regen":   m += 0.12      # 回血——战斗拖长，我方压力更久
			"poison":  m += 0.06
			"thorns":  m += 0.06
			"shock":   m += 0.04
			"pierce", "ambush", "cutoff": m += 0.06   # 打得到后排＝脆皮也挨打
			# v52/v55：上负面状态与机制那几条
			"flame":   m += 0.08
			"lockchain": m += 0.08
			"choke":   m += 0.06      # 沉默：两手放不出武学
			"soften":  m += 0.05      # 虚弱：出手 −25%
			"entangle": m += 0.04     # 迟缓：速度 −30%
			"armorcrack": m += 0.07   # 裂甲：挨打受伤 +30%
			"drainrage": m += 0.05    # 泄气：怒气被削
			"stagnant": m += 0.05     # 滞脉：技能冷却 +2
			"sealvein": m += 0.05     # 封穴：回血只剩三成
			"acuity":  m += 0.10      # 点窍：被动全失效（最狠的一条）
			"leech":   m += 0.10      # 吸血：战斗被拖长
			"bulwark": m += 0.08      # 坚壁：两成半几率只吃两成
			"echo":    m += 0.10      # 回响：每第 2 手多打一记四成
			_: m += 0.04
	# 首领带招/大招：离线不细算，给一成多的量
	if bool(e.get("boss", false)):
		m += 0.15
	return minf(m, 2.5)

# 结算结果：把"这一关过了"告诉调用方（账本那边去发银两/经验/首领赏）
# 返回 true 表示这一关确实结算成功了。
# ⚠ stage_info：可选。传了就**用它那份关卡数据**（账本那边的 enemy_at 包装会带上词缀），
#   没传就用本文件那份（不带词缀——离线估算会偏乐观）。
static func run_offline(
	start_stage: int,
	budget_sec: float,
	my_dps: float,
	my_hp: float,
	my_cut: float,
	clear_one: Callable,
	stage_info := Callable(),
	stop_stage := 0,
	my_def := 0.0,
	my_dodge := 0.0,
	my_atk := 0.0,
) -> Dictionary:
	var stage := clampi(start_stage, 0, STAGE_MAX - 1)
	var left := budget_sec
	var cleared := 0
	var gold := 0
	var exp := 0
	var gifts := 0
	var stuck := false
	var fatal := false
	var gate := false   # ㊿r：撞上"必须真打的那一关"（剧情关）停的
	while left > 0.0 and cleared < OFFLINE_MAX_STAGES:
		if stage >= STAGE_MAX:
			break
		# ㊿r：stop_stage > 0 时推到它为止（账本传进来的是剧情关的**前一关**下标）。
		#   跟 stuck 分开记：stuck 是"打不过"，这个是"这一关得你真打一场"。
		if stop_stage > 0 and stage >= stop_stage:
			gate = true
			break
		var e := enemy_at(stage)
		if stage_info.is_valid():
			var full: Variant = stage_info.call(stage)
			if full is Dictionary and not (full as Dictionary).is_empty():
				e = full as Dictionary
		var boss := bool(e.get("boss", false))
		var elite := bool(e.get("elite", false))
		# ㊼：多人关要按"整场血池"算——精英 2 人、首领 3 人（站位表保证总账＝foe_hp_scale）。
		# v47：单人关还要乘"体型"那一份（肉盾/寻常/高伤）——**与真战斗读同一口**
		#   （GameData.foe_stage_scale），不然挂机算出的关卡数会跟手动打的对不上。
		var sc: Dictionary = GameData.foe_stage_scale(stage, boss, elite)
		var hp := int(round(float(e.get("hp", 1)) * float(sc["hp"])))
		# ㊿：**挨打的压力也按整场算**。副手的 atk 同样是本体的 0.6/0.4，
		#   所以同一份 scale 正好也是"一回合挨几份打"（首领＝2 份、精英＝1.6 份）。
		#   以前只拿本体那一份 atk，于是离线以为只挨一份打 —— 首领关整整少算一半。
		var atk_all := float(e.get("atk", 1)) * float(sc["atk"]) * pressure_mul(e)
		# v35：防御 / 闪避也折进来（与实战同一个公式、同一把尺子）——
		#   不折的话"挂机推的关"会比"手动打的关"乐观一大截。
		#   ⚠ 估算的 atk_all 与实战一样是**一手**的场合少、一轮的场合多，
		#     这里按"一轮当成一手"近似（与上面 pressure 同一个粗法）。
		atk_all = _after_my_def(atk_all, e, my_def, my_dodge)
		# v35：我打过去那一下也要过敌人的防御（攻高就压得住，跟实战一致）
		var dps_now := float(my_dps)
		if my_atk > 0.0:
			dps_now *= 1.0 - GameData.def_cut(my_atk, float(e.get("def", 0)))
		if not can_beat(hp, atk_all, dps_now, my_hp, my_cut):
			stuck = true
			break
		var sec := battle_seconds_est(hp, int(round(atk_all)), dps_now)
		if sec > left:
			break
		var r: Variant = clear_one.call(stage)
		if r == null or not (r is Dictionary):
			# 结算失败（比如账本那边说不该过）——停下，别硬推
			fatal = true
			break
		var rd: Dictionary = r
		gold += int(rd.get("silver", 0))
		exp += int(rd.get("exp", 0))
		if bool(rd.get("gift", false)):
			gifts += 1
		left -= sec
		cleared += 1
		stage += 1
	return {
		"cleared": cleared,
		"stage": stage,
		"gold": gold,
		"exp": exp,
		"gifts": gifts,
		"stuck": stuck,
		"fatal": fatal,
		"gate": gate,
		"left_sec": left,
	}

# v35：估算里那把"我方挨打"的尺子——与实战同一个公式（GameData.def_cut / dodge_rate）：
#   ① 闪避：按对手速度算闪避率，整轮按它打个折（闪掉的那些手不疼）
#   ② 防御：按对手**本体**的攻击值对拼（副手攻击更低、挡得更多，这里按本体算＝保守）
#   返回削过之后的"每轮挨多少"。
static func _after_my_def(atk_all: float, e: Dictionary, my_def: float, my_dodge: float) -> float:
	var v := maxf(0.0, atk_all)
	if my_dodge > 0.0:
		var dr := GameData.dodge_rate(my_dodge, float(e.get("spd", 10)))
		v *= 1.0 - dr
	if my_def > 0.0:
		v *= 1.0 - GameData.def_cut(float(e.get("atk", 1)), my_def)
	return v

# 一行摘要（回村播报/控制台）
static func offline_line(r: Dictionary) -> String:
	var n := int(r.get("cleared", 0))
	var at := int(r.get("stage", 0)) + 1
	# ㊿r：撞剧情关停下的——说清是"这关必须你真打"，别说成打不过
	if bool(r.get("gate", false)):
		if n <= 0:
			return "挂机（估算）：停在第 " + str(at) + " 关——这关有剧情，得你自己进战斗画面打一场"
		return "挂机（估算）清了 " + str(n) + " 关（到第 " + str(int(r.get("stage", 0))) + " 关）｜停在第 " + str(at) + " 关：这关有剧情，得你自己打"
	# ㊿：明说这是**估算**不是真打——玩家有权知道塔是怎么推上去的
	if n <= 0:
		if bool(r.get("stuck", false)):
			return "挂机（估算）：第 " + str(at) + " 关打不过——先练练再来"
		return "挂机（估算）：时间不够打一场"
	var s := "挂机（估算）清了 " + str(n) + " 关（到第 " + str(int(r.get("stage", 0))) + " 关）"
	if bool(r.get("stuck", false)):
		s += " · 下一关打不过，卡住了"
	return s
# 用在挂机：离线期间按这个时长逐关推进，打不过就卡在当前关。
# ============================================================

# 一场仗的时长估算（秒）：回合数 × 每回合节奏。
#   回合数按"敌人血量 ÷ 我方每回合输出"估，再用 battle_lite.STEP 当节奏。
const TURN_SEC := 0.72          # 与 battle_lite.STEP 对齐（那边是 0.72 秒一手）
const MIN_TURNS := 2.5          # v38：原 4.0——"一关几手打完"的下限，按 4 手算＝每关最少估 12 手，
								#   于是前期 300 关被估成 50 分钟（用户："想让玩家很快拿到"）。
								#   压到 2.5 手（＋固定 4 手 ≈ 9 手一场），挂机推关的节奏跟得上实际手感。
const MAX_TURNS := 40.0         # 一场最多估到这么多手，免得离线段算成天文数字

static func battle_seconds_est(hp: int, atk: int, my_dps: float) -> float:
	if my_dps <= 0.0:
		return 9999.0
	var turns := clampf(float(hp) / my_dps, MIN_TURNS, MAX_TURNS)
	# 敌我各动一次 ≈ 2 手；再加点开场/收尾的固定耗时
	var hands := turns * 2.0 + 4.0
	return hands * TURN_SEC + 1.2

# 粗略判断这一关打不打得过（离线用；不作精确模拟）
# 判据：我方每回合输出 > 敌人每回合对我方的压力 → 打得过
#   ⚠ atk 传的是"**敌方全队**一回合打过来多少"（本体＋副手，再乘词缀膨胀，
#     见 run_offline 里那两行）。以前传的是本体一份 atk，首领关少算一半。
static func can_beat(hp: int, atk: float, my_dps: float, my_hp: float, my_def_cut: float) -> bool:
	if my_dps <= 0.0 or my_hp <= 0.0:
		return false
	var turns_to_kill := float(hp) / my_dps
	var incoming := float(atk) * (1.0 - clampf(my_def_cut, 0.0, 0.9))
	var turns_to_die := my_hp / maxf(1.0, incoming)
	# 留点余量：要能在死之前打死它（1.15 倍富余）
	return turns_to_kill * 1.15 <= turns_to_die
