extends RefCounted
# ============================================================
# game_state.gd —— 小账本（静态类）v37
# v64（货栈四连改 · 用户："基础残兵/基础残装备/基础功法 价格下调40% 增加限购 10/每种；
#   购买时弥补仓库最缺的那一件或者没有的那一件；增加良品的残卡【武器/装备/功法】限购5"）：
#   价 91/119/91 → **55/71/55**（×0.6）；限购 3/2/2 → **每种 10**；新增**良品**残卡三种
#   （110/142/110，限购 5，按自己那一档定价）；买残卡**不再是随机一张**——
#   走 _shop_pick_missing()：优先"差一张就齐"的套，其次一张没有的套，全齐了才退回随机。
# v37（用户定的两件）：①**爬塔宝箱**（咸鱼之王那套）——每清一关给一个箱子（手动打与挂机
#   推都算），品质跟关卡走（杂兵木箱 / 精英银箱 / 首领金箱 / 里程碑玉箱·小概率龙箱）；
#   开箱先掷两次运气（**角色碎片** / **突破丹**），其余给银两与炼丹材料。表与掷法在
#   shared/tower.gd 的 CHESTS，账与落点在 chest_* 几个口，面板在 menu/chest_panel.gd。
#   ②**突破也要银两**（BREAK_SILVER 按品级抬、吃妙手折扣）——"清关＋开箱攒银两"成了正路。
#   存档：world.chests / world.chest_stage。
# v36（用户定的三件）：①满级 1000；②每 25 级一道关，吃「突破丹」突破（五品，炼丹或
#   货栈每日限购），突破给一截基础属性；面板那颗"评价"改成显示**境界等级**；
#   ③角色碎片升星改 60/120/240/480/960/1920（红件一次掉一把 10 片）。
#   ⚠ v45 已改：升星 60/120/180/240/300/360（满星 1260 片）· 红件一次 2~5 片——见 data_stars.STAR_FRAG。
# v35（用户报的三处）：①**升星改"记在件上"**——键从「主人|件名」改成「件名」，一件兵器/
#   一门功法升上去就是**那件**的属性，卸下来换别人拿照样算（老档 v1→v2 自动拍平，取最高星）；
#   ②品酒坊堵掉"酿→卖"无限刷银两：没品过的酒只按**生酒**贱卖（WINE_RAW_MUL），
#   并且**每日限酿** WINE_BREW_LIMIT 坛（真实日期；账存 user://wine.cfg，跟货栈一个路子）；
#   ③精英三选一的"满包"出口改在 journey_stage（不再往临时仓库塞、也不再超上限）——
#   详见那边的 _elite_draw_give。
# v34b（㊾b）：［分配］钮撤了——升级直接花经验池（level_up 先扣个人那份、不够从池里补）；
#   exp_to_next / exp_pool_levels / grant_pool_exp 三个"分配专用"的口一并删掉。
# v34（优化批㊾）：经验改"独立经验池"——挂机收取/出村清缴不再直接塞给上阵的人，
#   全部进池（总量＝原口径：每人一份 × 上阵人数）；池子存 save.cfg（world 段）、reset 清零。
# v33（优化批㉓）：①升星加银两（STAR_SILVER×品级系数；不够即拦）；②出征临时扩仓（150 两起、
#   每买一次价翻倍、只顶一趟；run_expand 存 save.cfg 的 world 段）。
# v32（优化批㉒）：①宠物五阶＋资质＋血脉（融合/纯度/契合；值＝基础×资质×纯度）；②全局
#   存档 save.cfg（角色/仓库/材料/丹酒/碎片/星/宠/血脉/村况/货币）＋reset_full（菜单 R 键）；
#   ③货栈上「金纹血脉囊」（高价限量）；④journey_deposit 收血脉桶。
# v31（优化批⑧）：随行背包五档——容量对整趟生效（包裹＋临时仓库同享，出口在
#   run_state.bag_cap）；解锁随首通（D1/D3/D6/D10）；引子趟固定 8 格；存 journey.cfg
#   的 "pack" 段；reset 一并归零。
# v30（R4 收尾）：①十档取名（DIFF_NAMES 十项全填）；②退役池位闸清理——POOL_Q_NEED /
#   pool_q_max / pool_q_line / collected_in 四处齐删（门面已全换手，兼容件功成身退）。
# v29（R4 内容批②）：M 自检加"红池"一行（pool_red_line）——任何阶段红池为空一眼可见。
# v28（R4 卡池换届）：卡池改难度驱动——pool_active/pool_red 两个口子（链在 data_cards
#   .LADDER_CHAIN）；每首通一档换一手（旧组退场）；越阶"红"=阶段+1~2 品（封顶绝）。
#   村货栈残卡吃现役卡池＋按"池顶品级"定一口价（shop_card_price）；收集册降为
#   "合成纯记录"——游历带出的整件不再登记。旧 pool_q_max/POOL_Q_NEED 保留兼容，
#   门面全换手后删。
# v27（R3 子批①）：角色碎片账（fragments，升星系统未开先只记）；journey_deposit
#   扩碎片/丹药/酒酿三路，成品带出即登记收集册；M 键自检加一行搜刮抽查。
# v26（可选·R2 补漏）：村货栈残卡与游历同一条池位闸——不再提前漏高品残卡。
# v25（R2 品级池位）：按《收集册》推池位——凡品恒开，池内收满 N 种开下一品；
#   闸函数 pool_q_max(pool) 一处管三出口（事件三选一／货郎／补齐）；M 键自检加池位一行。
# v24：清理批——品级名表 GRADE_CN 转发 data_cards、SLOT_CN 加"arts"、_pool_ids 删（已落盘）。
# v23：天赋只有一个文件（data_talents v3）——roll_talents 只认 good/bad，
#      自带 kind "innate" 不再被误当坏签抽走。
# v22：R1 出征底座——难度档状态（diff_state/diff_clear，存 journey.cfg）、
#      出征交接（deploy_set/deploy_take）、M 键自检加难度一行、归零一并清难度。
# v21：卡组底座（R0）——①品级改读 data_cards（grade_of 转发）；
#      ②合成唯一来源 can_synthesize / synthesize；③收集登记（journey.cfg）；
#      ④游历结算入账口 journey_deposit（提取唯一管道）；⑤货栈/测试键不再写死 3。
# v20：宠物改"名册"——可养多只、随行只带一只；每只各自攒灵息/升阶；
#      宠物名录（名字/阶名/fx 五键）搬去 shared/data_pets.gd，这里留 PETS 转发；
#      新宠「青隼」（测试尺）；旧符号 pet_id / pet_active / pet_xp 留作兼容镜像。
# v19：货栈数据分页——SHOP_ITEMS 每条加 cat（basic/weapon/arts），两张卡改名
#      「基础兵器残卡 / 基础武学残页」；"每日限购"字样从说明里挪去面板，
#      写在银两下面；新增 SHOP_CATS 页签表与 shop_items_of()。
# v18：货栈上新（银两买、按真实日期每日限购）；天赋表搬去 data_talents.gd。
# v17：丹药统一叫"包裹"（文案）；v16：G 键连炼丹链一起开；v15：挂机随章节升档。
# ============================================================

const Cards := preload("res://shared/data_cards.gd")
const DataTalents := preload("res://shared/data_talents.gd")
const DataPets := preload("res://shared/data_pets.gd")
const Loot := preload("res://shared/data_loot.gd")
const DataAffixes := preload("res://shared/data_affixes.gd")
# ㉖：自带天赋的真源在 journey/data_roles.gd（run_state 也是这么引的，同一惯例）；
# 它只引 data_talents，不回头引本文件，所以不成环。
const Roles := preload("res://journey/data_roles.gd")
const Bonds := preload("res://shared/data_bonds.gd")   # ㊽：上阵羁绊（纯数据，无循环）
const Stars := preload("res://shared/data_stars.gd")   # ㊿y：角色星（命座/星魂排布，纯数据）
const Appraise := preload("res://shared/data_appraise.gd")   # v39：鉴宝行（货仓档位/侦查道具，纯数据）
const Tuning := preload("res://shared/tuning.gd")   # ㉘：可调参数读取口

const VILLAGE_MAX := 4
const BOSS_SILVER := 20        # 首领赏原值；实发走 boss_silver_gain() 按系数减
const STAGE_EXP_BONUS := 9     # v62m：12 → 9（跟着经验收益再砍 25%）    # 每人每关固定 +N 经验
const STAGE_SILVER_MUL := 0.5  # ㊿n：过关银两系数（砍半；改回 1.0 = 恢复原样）
const DEPLOY_MAX := 3
const FREE_SKILL_SLOTS := 3

# ---- 挂机 ----
const IDLE_CFG := "user://idle.cfg"
const IDLE_CAP_SEC := 28800
const IDLE_SILVER_PER_MIN := 1
const IDLE_EXP_PER_MIN := 2
const ACTION_START := 60      # 食物（原行动值）：开局 60，主条满值 100，库存上限 999
const ACTION_MAX := 999
# ㉞：每清几关挂机收益涨一档。
#   原来是 5——那时塔只有 50 关，顶天 10 档（+10 银两/分）还算克制。
#   塔扩到 500 关后，5 会变成 100 档（+100 银两/分），直接把过关赏（每关十几两）
#   压成零头——挂机比推关划算，玩法就歪了。所以改成 50：仍是 10 档封顶，
#   与原来同量级。（将来做"离线自动爬塔"时，这一块要跟关卡推进一起重新设计。）
# v62n（用户："档位可以按照100/1档算 1000关后 按照250/1算 挂机不封顶 挂机倍率降低30%"）：
#   IDLE_STEP 50 → **100**（每 100 关一档）· 新增 IDLE_STEP_LATE = **250**（1000 关后每 250 关一档）
#   · IDLE_TIER_SWITCH = 1000（两条斜率的交接点）
#   · 速率整体再 ×0.7（挂机倍率降低 30%）——银两与经验两条一起降。
const IDLE_STEP := 100                # v62n：50 → 100
const IDLE_STEP_LATE := 250           # v62n：1000 关之后每 250 关一档
const IDLE_TIER_SWITCH := 1000        # v62n：两条斜率的交接关卡
const IDLE_RATE_MUL := 0.7            # v62n：挂机倍率 ×0.7（在下面两条 rate 里乘）
# v80（用户：「挂机的经验收益提高20%」）：只加经验这一条，银两/木料不动。
const IDLE_EXP_MUL := 1.2

static var idle_pool_sec := 0
static var _idle_last_ts := 0

# ---- 等级 / 境界 / 根骨 / 评价 ----
# v36（用户定）：①满级先给到 **1000 级**；②**每 25 级一道关**——到顶要服一颗
#   「突破丹」突破（炼丹炼得出、货栈每日限购有卖），突破一次上限 +25 级、
#   并且**基础属性当场涨一截**（BREAK_GAIN，见下面）；
#   ③原来那颗"评价"（按根骨分的 丁/丙/乙/甲/绝）改成显示**境界等级**。
# 于是境界＝突破次数（0~39）：境界 n 的上限是 25×(n+1) 级。
#   ⚠ 突破丹分五品：每 8 个境界换一品（凡 → 良 → 上 → 极 → 绝，正好 40 档）。
const LEVEL_MAX := 1000
# v120（用户："算了 突破改回来吧"）：v117 那一整套（100 级一重 / ×4 / 材料增多 / 丹率降 / 会失败）
#   **全部撤回**——下面这些常量回到 v62 的口径（25 级一重 · 39 重 · 丹 1/2/4/8/16/32 · 银两 8 档）。
const BREAK_STEP := 25            # 每 25 级一道关
const BREAK_MAX := LEVEL_MAX / BREAK_STEP - 1   # 39：突破满 39 次就能到 1000 级
# 突破一次的"基础属性数值增幅"——直接加进 role.stats 的底子上。
# v61（用户："突破 气血+10 攻击+1 防御+1"）：
#   原来 {hp 60, atk 12, def 2, dodge 2} → 现在 **{hp 10, atk 1, def 1}**（闪避那条整条去掉）。
#   39 次合计：气血 **+390**、攻击 **+39**、防御 **+39**（原来 +2340 / +468 / +78 / +78）。
#   也就是说：突破现在只"开等级上限 + 给一点点基础"，不再是主要成长来源。
#   觉得多/少就改这一张表（键＝面板上的属性键）。
# v62h（用户："突破 根据根骨的资质进行属性数值增幅"）：
#   突破给的三条属性**按这名角色的根骨**折算——根骨是人物固有资质（暂不做成长途径），
#   所以等于"资质定额"：少侠（62）每次 +2攻/+10血/+2防，陈石（35）每次 +1/+6/+1。
#   ⚠ 39 次合计：少侠 攻+78 · 血+390 · 防+78；陈石 攻+39 · 血+234 · 防+39。
#     （与"升到 1000 级只给气血 +999"合起来，"角色"这条线总攻约 90、总血约 1500）
const BREAK_ATK_PER_GENGU := 30.0
const BREAK_HP_PER_GENGU := 6.0
const BREAK_DEF_PER_GENGU := 40.0

# v117：40 重 → 10 重，所以**单次 ×4**（总加成与老版一模一样）。
const BREAK_GAIN_MUL := 4.0

static func break_gain(role_id: String) -> Dictionary:
	var g := int(_role_mut(role_id).get("gengu", 0))
	return {
		"atk": int(round(float(g) / BREAK_ATK_PER_GENGU)),
		"hp": int(round(float(g) / BREAK_HP_PER_GENGU)),
		"def": int(round(float(g) / BREAK_DEF_PER_GENGU)),
	}
# v36b（用户："角色突破需要消耗银两"）：**突破还要银两**，按品级抬（吃"妙手"折扣）。
#   每一次的银两＝下表[品级] × player_talent_cost_mul()。
#   ⚠ v62（用户："银两本身就比较难攒 之前给的收益也是太高了 导致银两都不值钱了"）：
#     银两**收入**在 v61 已经砍了 70%（清关/首领/宝箱/挂机），但**花费**还是老价格——
#     实测：爬到第 1300 关（现在的墙）**总共**只赚 110,619 两，而满突破按旧价要 354,800 两/人
#     （比整条爬塔赚的还多 3 倍）→ 突破根本买不起，银两成了废纸。
#     所以价格按**同一把尺子**折算（×0.3）：原 400/1200/3600/10800/32400
#                                                  → **120/360/1080/3240/9720**
#     满突破 = **106,440 两/人** ≈ 一趟爬塔的总收入：
#     银两仍然紧（三个人凑不齐），但"攒够一个人的突破钱"是够得着的目标 ✓
#   嫌贵嫌便宜只改这一行。
const BREAK_SILVER := [170, 500, 1500, 4500, 13500]
# 突破丹五品（id 与 DAN_RECIPES 里那几条一致）；境界 1~8 用凡品、9~16 良品……33~40 绝品
const BREAK_PILLS := ["tupo_fan", "tupo_liang", "tupo_shang", "tupo_ji", "tupo_jue"]
const BREAK_PILL_CN := ["凡品", "良品", "上品", "极品", "绝品"]
const BREAK_PER_TIER := 8      # ⚠ 只给"突破银两"分档用（v62 起丹药消耗另有一套：见 BREAK_PILL_SLOTS）

# 四十重境界名（每 25 级一重）。前 10 个沿用旧表，往后按"越走越玄"接着排。
#   境界由**突破**推进（不是按等级自动跳），等级只是它的上限表现。
const REALMS := [
	"初出茅庐", "略有小成", "功法大成", "登峰造极", "返璞归真",
	"出神入化", "超凡入圣", "天人合一", "深不可测", "一代宗师",
	"开宗立派", "独步天下", "笑傲江湖", "天下无敌", "神而明之",
	"万法归一", "与道合真", "陆地神仙", "剑心通神", "气吞山河",
	"星移斗转", "移山填海", "摘星拿月", "破碎虚空", "超凡脱俗",
	"羽化登仙", "万古长空", "太虚之境", "大道无形", "返本还源",
	"混元一气", "两仪归元", "三花聚顶", "五气朝元", "周天圆满",
	"金身不坏", "咫尺天涯", "一念千里", "无我之境", "道法自然",
]
const EVAL_TIERS := [
	{"min": 80, "cn": "绝等"},
	{"min": 60, "cn": "甲等"},
	{"min": 40, "cn": "乙等"},
	{"min": 20, "cn": "丙等"},
	{"min": 0,  "cn": "丁等"},
]
# 升级经验：一级比一级贵（40 + 20×(lv-1)）。1000 级合计约 1000 万点——
#   挂机 2 点/分、爬塔每关 24+0.5×关号，是个长线目标（想快点就压 EXP_STEP）。
const EXP_BASE := 40
const EXP_STEP := 20
# v62h（用户："我想好了 角色升级只加气血 … 突破 根据根骨的资质进行属性数值增幅"）：
#   **升一级只给气血，不再给攻击**。攻击那条线整体挪到「突破（按根骨）＋装备＋功法」上，
#   于是角色攻击不再随等级膨胀（1000 级也只有 90 上下），"角色在面板里占多少"这才配得动。
#   ⚠ 每级 +1 气血（1000 级 = +999）：与"防具气血 ×5.4"合起来，角色正好占面板气血的 40%。
const LEVEL_GROWTH := {"hp": 1, "atk": 0}
const GENGU_HP_EVERY := 50
const GENGU_ATK_EVERY := 100

static var level_notes: Array = []
static var formation_intro_done := false

# ---- 升星 / 品级 ----
const STAR_MAX := 5
const STAR_COST := [0, 1, 2, 4, 8, 16]
const STAR_SILVER := [0, 280, 560, 1100, 2200, 4500]   # 优化批㉓：升星银两（×品级系数；逐星翻倍）
const STAR_MUL_PER := 0.2
static var item_stars := {}    # v35：件名 → 星数（**星记在件上**，不记在谁手里）

# 品级名表唯一源 = data_cards.QUALITY_ORDER（v24 起转发；老引用照旧可用）
const GRADE_CN := Cards.QUALITY_ORDER


static func grade_of(sid: String) -> String:
	return Cards.quality_of(sid)

# v35（用户报的①）：星改"记在件上"——键**只有件名**。
#   旧版（优化批⑬/#22）是「主人|件名」：主角升的枪，卸下来交给陈石就没星了——
#   那不是"每个兵器功法各自独立"，是"星挂在人身上"。现在同一件兵器/同一门功法，
#   谁拿都吃到它的星（升星台也从"按人列"改成"按件列"，仓库散件不必先装到人身上）。
#   为什么按**名**而不按"这一把"：村里仓库按同名计数存（vault_items[sid] = 份数），
#   装备栏/包裹也只存件名——没有"这一把 / 那一把"的身份。星跟名走，四处口径才一致。
#   ⚠ 老档（v1）的「主人|件名」键在 _migrate 里已经拍平；取同名**最高**星
#     （宁可偏强，也不该把玩家已花掉的同名份数与银两凭空抹掉）。
static func star_of(sid: String) -> int:
	return int(item_stars.get(sid, 0))

static func star_cost_next(sid: String) -> int:
	var star := star_of(sid)
	if star >= STAR_MAX:
		return 0
	return int(STAR_COST[star + 1])

# ㉗：妙手——升星银两打折（天赋是主角五问所得，所以按主角那份算）
static func player_talent_cost_mul() -> float:
	return maxf(0.1, 1.0 + float(talent_fx_of("player").get("cost_pct", 0)) / 100.0)

# 优化批㉓：升星要银两——花费＝表值 × 品级系数（和货栈一口价一个口径）
# ㉗：再乘妙手折扣。改在这里而不是面板里，是为了"面板显示的数"和 star_up 真扣的数
#   一定一致（面板和扣款都调这一个口）。
static func star_silver_next(sid: String) -> int:
	var star := star_of(sid)
	if star >= STAR_MAX:
		return 0
	var q := Cards.q_idx(sid)
	var mul := float(Cards.PRICE_MUL[clampi(q, 0, Cards.PRICE_MUL.size() - 1)])
	return int(round(float(STAR_SILVER[star + 1]) * mul * player_talent_cost_mul()))

static func star_mul(sid: String) -> float:
	return 1.0 + float(star_of(sid)) * STAR_MUL_PER

# ============================================================
# v62f（用户："将武学现有倍率拆成5份 【专武的升星我单独设计】升星加成由低到高 幅度要大
#   根据武学定位 给予一定的特殊效果 属性啊 额外加伤啊【数值不是百分比】
#   最后一星可以给予定位这个武学对这个武学的专属效果【类似专武 不过专武对应角色
#   而这个武学对应本身 可以少许百分比】"）
#
#   v62f-b（用户追问："倍率拆成 5 份 我说的是包括他本身的倍率哦 比如xx 原本倍率 2.8
#   现在可能1.1 剩余的被拆成加成了"）
#
#   于是规矩定成——**表上印的那个倍率 ＝ 满星值**：
#     · **0★ 只拿 40%**（例：原本 2.8 → 0★ **1.12**，正是用户举的"1.1"）
#     · 剩下 60% 拆成 5 份，**由低到高**发给 1~5★：**6% / 9% / 12% / 15% / 18%**
#     · 满星正好回到表上那个数（2.8 → ×1.00）：**满星才是"原来那门武学"**
#   ⚠ 后果说清：**没升星的武学比之前弱 60%** → 前中期会明显更难，这正是"升星＝进度"
#     该有的样子。**天花板一点没动**（满星＝原值），所以爬塔/游历的最终那道墙没变——
#     我也**没有**去动敌人曲线（动了反而让满星玩家碾压）。
#   ⚠ 专武（no_drop 那三门）**完全不参与**：它们没有 0★ 这一说，照旧用表上的倍率
#     （用户："专武的升星我单独设计"）——于是专武在前期相对更强，这是有意的。
#
#   v62f-c（用户："最终可以到150% 且 品质可以提升这个1-4星的基础属性"）
#     · **满星改成 150%**：份额合计 110%（12/18/23/27/30，仍是由低到高），加上底子 40%
#       → 满星 ×1.50。例：原本 2.8 → 0★ 1.12 · 3★ 2.07 · **满星 4.20**
#     · **1~4★ 的数值属性按品质放大**（`ART_STAR_Q_MUL`：凡1.0 良1.3 上1.6 极2.0 绝2.5）——
#       同一门功法做到绝品，升星给的攻击/气血也跟着厚。
#       ⚠ 只放大 **1~4★ 那几份数值**；**5★ 的专属效果不放大**（用户说的就是"1-4星的基础属性"）。
#
#   三件事，分开说：
#   ① 倍率按上面那套拆（本段）
#   ② **每星顺带给数值型属性**（`ART_STAR_FLAT`，按定位）：攻击/气血/防御/速度/暴击
#      **点数，不是百分比**——"额外加伤"落在**攻击点**上（本作的伤害＝攻 × 倍率 × 伤害%，
#      加攻就是实打实的加伤，且是数值不是百分比）。
#   ③ **满星（5★）给这门武学自己的专属效果**（`ART_STAR5`，按定位）：数值上"类似专武"的
#      少许百分比（出手伤害 +6% / 暴击 +5% / 减伤 -4% 这种）。
#
#   ⚠ 属性与专属效果都**并进 starred_stats()**，所以战斗/面板/结算全都自动吃到，
#     不需要在别处再各写一遍。
# ============================================================
const ART_BASE_RATIO := 0.40                                # 0★ 拿原倍率的四成
const ART_STAR_SHARE := [0.12, 0.18, 0.23, 0.27, 0.30]      # 五份由低到高（合计 1.10）
# 1~4★ 那份数值属性按**品质**放大（凡/良/上/极/绝）——用户："品质可以提升这个1-4星的基础属性"
const ART_STAR_Q_MUL := [1.0, 1.3, 1.6, 2.0, 2.5]

const ART_STAR_FLAT := {
	"damage":  [{"atk": 2}, {"atk": 3}, {"atk": 4}, {"atk": 6}],
	"sweep":   [{"atk": 2}, {"atk": 3}, {"atk": 4}, {"atk": 6}],
	"dash":    [{"atk": 1, "spd": 1}, {"atk": 2, "spd": 1}, {"atk": 3, "spd": 2}, {"atk": 4, "spd": 2}],
	"stone":   [{"atk": 1}, {"atk": 2, "spd": 1}, {"atk": 3, "spd": 1}, {"atk": 4, "spd": 2}],
	"guard":   [{"def": 1}, {"def": 2, "hp": 12}, {"def": 3, "hp": 20}, {"def": 4, "hp": 30}],
	"passive": [{"hp": 10}, {"hp": 16, "def": 1}, {"hp": 24, "def": 2}, {"hp": 34, "def": 3}],
	"heal":    [{"hp": 10}, {"hp": 16}, {"hp": 24, "def": 1}, {"hp": 34, "def": 2}],
	"cleanse": [{"hp": 8}, {"hp": 14}, {"hp": 20}, {"hp": 28}],
	"bless":   [{"spd": 1}, {"spd": 1, "crit": 1}, {"spd": 2, "crit": 1}, {"spd": 2, "crit": 2}],
}

const ART_STAR5 := {
	"damage":  {"dmg": 6, "say": "招意吃透：出手伤害 +6%"},
	"sweep":   {"dmg": 6, "say": "横扫成势：出手伤害 +6%"},
	"dash":    {"crit": 5, "say": "身法入微：暴击 +5%"},
	"stone":   {"crit_dmg": 8, "say": "石随手走：暴击伤害 +8%"},
	"guard":   {"dmg_cut": 4, "say": "护体成罡：受到伤害 -4%"},
	"passive": {"hp_pct": 5, "say": "底子养厚：气血上限 +5%"},
	"heal":    {"hp_pct": 5, "say": "回春有术：气血上限 +5%"},
	"cleanse": {"hp_pct": 4, "say": "心法通透：气血上限 +4%"},
	"bless":   {"crit": 4, "say": "令旗所指：暴击 +4%"},
}

# 这门武学的定位（kind：damage/sweep/dash/stone/guard/passive/heal/cleanse/bless…）
static func art_kind_of(sid: String) -> String:
	return str((Cards.art_of(sid) as Dictionary).get("kind", "damage"))

# 专武（不掉落的那几门）——升星由用户单独设计，先不参与
static func is_ex_art(sid: String) -> bool:
	return bool(Cards.by_id(sid).get("no_drop", false))

# 这一门**当前**的倍率系数——v62f-b：**0★ = 0.40**，每星加一份（6/9/12/15/18%），
#   **满星 = 1.00**（就是表上印的那个数）。专武不参与，恒 1.00。
static func art_star_mul(sid: String) -> float:
	if not Cards.is_arts(sid) or is_ex_art(sid):
		return 1.0
	var s := clampi(star_of(sid), 0, ART_STAR_SHARE.size())
	var acc := ART_BASE_RATIO
	for i in s:
		acc += float(ART_STAR_SHARE[i])
	return acc

# 战斗里读武学倍率**一律走这一口**（把基础倍率按星级放大）
static func art_mult(sid: String, base: float) -> float:
	if sid == "":
		return base
	return base * art_star_mul(sid)

# 满星那一门武学的专属效果（文案 + 数值）
static func art_star5_line(sid: String) -> String:
	if not Cards.is_arts(sid) or is_ex_art(sid):
		return ""
	if star_of(sid) < STAR_MAX:
		return ""
	return str((ART_STAR5.get(art_kind_of(sid), {}) as Dictionary).get("say", ""))

static func star_marks(sid: String) -> String:
	var n := star_of(sid)
	if n <= 0:
		return ""
	return " 星" + str(n)

static func starred_stats(sid: String) -> Dictionary:
	var base := Cards.item_stats(sid)
	var m := star_mul(sid)
	var out := {}
	for k in base.keys():
		out[k] = int(round(float(base[k]) * m))
	# v58（用户："装备可以给一些了"）：**上品起的兵器自带一条元素伤害加成**——
	#   表里写不出来（元素是**逐件随机**的），只能按"这一把用哪个元素"现算。
	#   值随品级走、并吃升星倍率（与 item_stats 同一把尺子）。
	#   ⚠ 走这里而不是"装备栏单独加"，是为了**一处落地**：面板、effective_stats、
	#     游历的出征快照读的都是这一份，不必去三个地方各写一遍。
	for k2 in elem_weapon_dmg(sid).keys():
		out[k2] = int(out.get(k2, 0)) + int(elem_weapon_dmg(sid)[k2])
	# v62f：武学升星额外给的东西（按定位）——**数值型属性**（每星一份，低→高）
	#   ＋ **满星的专属效果**（少许百分比）。并在这一处，战斗/面板/结算自动全吃到。
	if Cards.is_arts(sid) and not is_ex_art(sid):
		var s := star_of(sid)
		var kind := art_kind_of(sid)
		# v62f-c：1~4★ 的数值属性按**品质**放大（凡1.0/良1.3/上1.6/极2.0/绝2.5）
		var qm := float(ART_STAR_Q_MUL[clampi(Cards.q_idx(sid), 0, ART_STAR_Q_MUL.size() - 1)])
		var flats: Array = ART_STAR_FLAT.get(kind, [])
		for i in mini(s, flats.size()):
			var row: Dictionary = flats[i]
			for k3 in row.keys():
				out[str(k3)] = int(out.get(str(k3), 0)) + int(round(float(row[k3]) * qm))
		if s >= STAR_MAX:
			# ⚠ 5★ 那条专属**不**吃品质放大（用户说的是"1-4星的基础属性"）
			var s5: Dictionary = ART_STAR5.get(kind, {})
			for k4 in s5.keys():
				if str(k4) == "say":
					continue
				out[str(k4)] = int(out.get(str(k4), 0)) + int(s5[k4])
	return out

# 上品起的兵器：按"当前用哪一把"给**类型**伤害加成（百分点）
#   凡 0 / 良 0 / 上 6 / 极 10 / 绝 15（×升星倍率）
#   ⚠ v58（用户："武器随机元素 也会随到空的 也就是物理 因为物理也是类型伤害"）：
#     摇到**物理**的那一把，给的是 **`phys_dmg`（物理伤害增加%）**而不是元素增伤——
#     "上品兵器必有一条类型增伤"这件事不会因为摇到物理就落空。
#     键名统一走 `Elem.dmg_key()`（它对 "phys" 与 "" 都返回 "phys_dmg"）。
const ELEM_WPN_DMG := [0, 0, 6, 10, 15]

static func elem_weapon_dmg(sid: String) -> Dictionary:
	var out: Dictionary = {}
	if not elem_eligible(sid):
		return out
	var e := elem_pick(sid)
	var q := clampi(Cards.q_idx(sid), 0, ELEM_WPN_DMG.size() - 1)
	var pt := int(round(float(ELEM_WPN_DMG[q]) * star_mul(sid)))
	if pt <= 0:
		return out
	var k := Elem.dmg_key(e)
	if k == "":
		return out
	out[k] = pt
	return out

# v35：这件能不能合星（升星台列件、以及 star_up 的第一道闸——同一份口径）
#   v62f（用户："专武的升星我单独设计"）：**专武不参与**——它们 no_drop，
#   同名份数永远拿不到，摆在升星台上就是个死按钮。这里直接挡掉。
static func can_star(sid: String) -> bool:
	if is_ex_art(sid):
		return false
	var pool := str(Cards.by_id(sid).get("pool", ""))
	return pool == "weapon" or pool == "armor" or pool == "helm" or pool == "cloak" or pool == "arts"

static func star_up(sid: String) -> String:
	if not can_star(sid):
		return "这件不能合星"
	var star := star_of(sid)
	var nm := Cards.name_of(sid)
	if star >= STAR_MAX:
		return "「" + nm + "」已经是五星了"
	var cost := int(STAR_COST[star + 1])
	var have := vault_item_count(sid)
	if have < cost:
		return "同名份数不够：升 " + str(star + 1) + " 星要 " + str(cost) + " 本（仓库只有 " + str(have) + "）"
	var sp := star_silver_next(sid)   # 优化批㉓：另收银两
	if coin("silver") < sp:
		return "银两不够：升 " + str(star + 1) + " 星还要 " + str(sp) + " 两（现有 " + str(coin("silver")) + "）"
	vault_items[sid] = have - cost
	add_coin("silver", -sp)
	item_stars[sid] = star + 1   # v35：记在件名上（谁拿都算）
	return "「" + nm + "」升到 " + str(star + 1) + " 星！（同名 -" + str(cost) + " · 银两 -" + str(sp) + "）每星 +" + str(int(STAR_MUL_PER * 100.0)) + "%（现 ×" + str(snappedf(star_mul(sid), 0.1)) + "）——星跟着这件走，换谁拿都算"

# ============================================================
# v58：**元素挂在哪一层**（用户第 1、2 条 + 追问后的选择 B）
#   用户："元素武器从上品开始 元素是随机给的"；"升星…想保留某个元素也方便"。
#
#   现状（老代码注释里写死的规矩）：仓库按**同名计数**存（`vault_items[sid] = 份数`），
#   星记在**件名**上——「没有『这一把 / 那一把』的身份」。真正的"一把一份身份"要把
#   仓库/装备栏/包裹/鉴宝/存档全翻一遍并迁移老档，代价太大。
#
#   所以选 **B：按件名分组记元素**——
#     `item_elems[sid] = {"fire": 2, "water": 1}`  ＝ 这件名下你攒了哪些元素的几把
#     `item_elem_pick[sid] = "fire"`                ＝ 现在**用**哪一把（装备/出战取它）
#   于是：同名可以攒到不同元素的几把（元素随机给），升星时**挑着吃**（保留你想要的那个），
#   想换手感就把 pick 一改。星仍旧按件名走，一个字没动——**老档语义不变**，只多两个键。
#
#   ⚠ 不变式：`sum(item_elems[sid]) == vault_items[sid]`。
#     新到手的份数用 `_elem_topup()` **懒补**（读的时候补），所以
#     **不用去每一个发东西的地方挨个加元素**——掉落/合成/鉴宝/测试包全都自动吃上。
#     懒补用的是 `hash(件名|第几份)` 做种，所以"没存盘就退出"也不会把元素摇成另一个。
# ============================================================
static var item_elems := {}       # 件名 → {元素: 份数}（只有**上品及以上的兵器**才有）
static var item_elem_pick := {}   # 件名 → 现在用哪一把的元素

const Elem := preload("res://shared/data_elem.gd")
const Ladder := preload("res://shared/data_ladder.gd")   # v58：掉落阶梯（货仓与搜刮共用）

# 这一件名该不该有元素：**兵器**池 + 上品（q≥2）起
static func elem_eligible(sid: String) -> bool:
	var d: Dictionary = Cards.by_id(sid)
	if str(d.get("pool", "")) != "weapon":
		return false
	return Elem.tier_has_elem(Cards.q_idx(sid))

# 摇一份的元素。seed_key 非空＝**确定性地**摇（懒补用，保证同一份每次摇到同一个）
static func _elem_roll(sid: String, seed_key: String) -> String:
	if not elem_eligible(sid):
		return ""
	if seed_key == "":
		return Elem.roll()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sid + "|" + seed_key)
	return Elem.roll(rng)

# 把这一件名的元素桶补齐到"仓库份数"那么多（懒补；多出来的按确定性顺序摇）
#
#   ⚠ v58 修：**只增不减**。第一版按 `sum(桶) == vault_items[sid]` 维护，结果
#     **一装备就把元素吃掉了**——装备会把兵器从仓库扣掉（`vault_items[sid] -= 1`），
#     桶比仓库多 1，那条"多了就削"的分支当场把元素削没。探针里主角装了霜刃剑，
#     查出来的元素直接变成"物理"，才抓到的。
#     现在的口径：桶记的是"**这一件名下到手过的**元素构成"，只增不减；
#     **唯一会减的地方是 `elem_take()`**（升星主动挑着吃，那里两边一起扣，账是平的）。
#     代价：卖掉/丢掉不会把桶里的数扣回去（可能"用着一把已经不在手里的元素"）——
#     比"装一下就丢元素"轻得多，也更好懂。
static func _elem_topup(sid: String) -> Dictionary:
	var b: Dictionary = item_elems.get(sid, {})
	if not elem_eligible(sid):
		return b
	var have := vault_item_count(sid)
	var n := 0
	for k in b.keys():
		n += int(b[k])
	var guard := 0
	while n < have and guard < 999:
		guard += 1
		var e := _elem_roll(sid, str(n))
		if e == "":
			break
		b[e] = int(b.get(e, 0)) + 1
		n += 1
	item_elems[sid] = b
	return b

# 这一件名下各元素各几份（只读，但会顺手补齐）
static func elem_own(sid: String) -> Dictionary:
	return _elem_topup(sid).duplicate()

# 一共有几份（= 仓库份数，元素桶的和）
static func elem_total(sid: String) -> int:
	var n := 0
	for k in _elem_topup(sid).keys():
		n += int(_elem_topup(sid)[k])
	return n

# v58：桶里所有可能出现的"类型"（五行 + **物理**）——摇得到的都在这一串里
const ELEM_POOL_KEYS := ["metal", "water", "wood", "fire", "earth", "phys"]

# 这件名**表里写死**的元素（功法走这条；兵器表里不写，见 elem_of_card）
static func elem_fixed(sid: String) -> String:
	return Cards.elem_of(sid)

# 现在**用**哪一把的元素：pick 有效就用 pick，否则用桶里第一种（再没有＝物理）
#   ⚠ v58：`phys` 也是合法结果（摇到物理的那一把）——所以这里不能只认 Elem.ORDER
static func elem_pick(sid: String) -> String:
	var b := _elem_topup(sid)
	var p := str(item_elem_pick.get(sid, ""))
	if p != "" and int(b.get(p, 0)) > 0:
		return p
	for k in ELEM_POOL_KEYS:
		if int(b.get(k, 0)) > 0:
			return str(k)
	return ""

# 改"用哪一把"（升星窗口/装备界面用）。返回一句播报
static func elem_set_pick(sid: String, e: String) -> String:
	var b := _elem_topup(sid)
	if e == "" or int(b.get(e, 0)) <= 0:
		return "这一件名下没有" + Elem.cn(e) + "属性的"
	item_elem_pick[sid] = e
	return "「" + Cards.item_name(sid) + "」改用 **" + Elem.cn(e) + "** 那一把"

# 升星要吃掉指定元素的 n 份（用户第 2 条："想保留某个元素"）
static func elem_take(sid: String, e: String, n := 1) -> bool:
	var b := _elem_topup(sid)
	if int(b.get(e, 0)) < n:
		return false
	b[e] = int(b[e]) - n
	if int(b[e]) <= 0:
		b.erase(e)
	item_elems[sid] = b
	vault_items[sid] = maxi(0, vault_item_count(sid) - n)
	if str(item_elem_pick.get(sid, "")) == e and int(b.get(e, 0)) <= 0:
		item_elem_pick.erase(sid)
	return true

# **引擎唯一该调的那一口**：这件东西此刻算什么属性。
#   表里写死的（功法）优先；兵器的随机"元素"看"当前用哪一把"；其余＝物理（空串）。
#   ⚠ v58：兵器那一侧现在会返回 **"phys"**（摇到物理的那一把）——它对引擎是安全的：
#     `Elem.is_elem_attack("phys")` 为假 → 走物理通道；`atk_bonus(st,"phys")` 取的是
#     **物理伤害增加%**（`dmg_key("phys") == "phys_dmg"`）→ 与"空串＝物理"完全同一条路。
static func elem_of_card(sid: String) -> String:
	if sid == "":
		return ""
	var fixed := elem_fixed(sid)
	if fixed != "":
		return fixed
	if elem_eligible(sid):
		return elem_pick(sid)
	return ""

# 一行小字（面板/提示用）："火"／"金×2 水×1"／"物理"
static func elem_line(sid: String) -> String:
	var fixed := elem_fixed(sid)
	if fixed != "":
		return Elem.cn(fixed)
	if not elem_eligible(sid):
		return Elem.cn("")
	var b := _elem_topup(sid)
	if b.is_empty():
		return Elem.cn("")
	var seg: Array = []
	for e in ELEM_POOL_KEYS:
		var c := int(b.get(e, 0))
		if c > 0:
			seg.append(Elem.cn(e) + ("×" + str(c) if c > 1 else ""))
	if seg.is_empty():
		return Elem.cn("")
	var p := elem_pick(sid)
	# 只有一种时不必写"（用 ×）"——那正是玩家默认看到的那把
	var tag := ""
	if b.size() > 1 and p != "":
		tag = "（用 " + Elem.cn(p) + "）"
	return " ".join(PackedStringArray(seg)) + tag

# ============================================================
# v58（用户第 2 条）：**批量升星窗口**的账
#   "武器的升星栏和功法升星栏最好有一个额外窗口可以选择或者选择多个同类型升星
#    这样人家想保留某个元素也方便"
#
#   口径：`picks = {"fire": 1, "water": 1}` ＝ 这一次**挑哪几份吃**（合计必须正好等于
#   这一星要的本数 `STAR_COST[star+1]`）。没被挑到的元素**原样留着**——
#   这就是"想保留某个元素"的实现：把不想要的那几份喂掉，想要的那份留住。
#   ⚠ 只有**能带元素的件**（上品起的兵器）才走这一口；下品/护甲/功法没有元素可挑，
#     照旧走 `star_up()`（那边按仓库总份数扣，行为一个字没变）。
# ============================================================
static func star_pick_ok(sid: String, picks: Dictionary) -> bool:
	if not elem_eligible(sid):
		return false
	var star := star_of(sid)
	if star >= STAR_MAX:
		return false
	return star_pick_total(picks) == int(STAR_COST[star + 1])

static func star_pick_total(picks: Dictionary) -> int:
	var n := 0
	for k in picks.keys():
		n += int(picks[k])
	return n

static func star_up_pick(sid: String, picks: Dictionary) -> String:
	var nm := Cards.name_of(sid)
	var star := star_of(sid)
	if star >= STAR_MAX:
		return "「" + nm + "」已经是五星了"
	if not elem_eligible(sid):
		return "「" + nm + "」没有元素可挑，直接升星即可"
	var cost := int(STAR_COST[star + 1])
	var total := star_pick_total(picks)
	if total != cost:
		return "要挑满 " + str(cost) + " 本（现在挑了 " + str(total) + " 本）"
	var own := elem_own(sid)
	var seg: Array = []
	# ⚠ v58 修（用户："物理也是类型伤害 不要忘了"）：这两段原来遍历的是 `Elem.ORDER`
	#   （只有五行），**"物理"那一份既没被校验、也没被扣**——于是"挑物理升星"会
	#   **白升一星、一本不扣**（探针当场抓到的）。改成遍历含物理的 ELEM_POOL_KEYS。
	for e_v in ELEM_POOL_KEYS:
		var e := str(e_v)
		var n := int(picks.get(e, 0))
		if n <= 0:
			continue
		if int(own.get(e, 0)) < n:
			return "「" + nm + "」名下 " + Elem.cn(e) + " 属性的不够（要 " + str(n) + "，只有 " + str(int(own.get(e, 0))) + " 本）"
		seg.append(Elem.cn(e) + "×" + str(n))
	var sp := star_silver_next(sid)
	if coin("silver") < sp:
		return "银两不够：升 " + str(star + 1) + " 星还要 " + str(sp) + " 两（现有 " + str(coin("silver")) + "）"
	for e2_v in ELEM_POOL_KEYS:
		var e2 := str(e2_v)
		var n2 := int(picks.get(e2, 0))
		if n2 > 0 and not elem_take(sid, e2, n2):
			return "扣份数失败（" + Elem.cn(e2) + "×" + str(n2) + "）"
	add_coin("silver", -sp)
	item_stars[sid] = star + 1
	var left := elem_line(sid)
	var msg := "「" + nm + "」升到 " + str(star + 1) + " 星！（吃 " + "、".join(PackedStringArray(seg))
	msg += " · 银两 -" + str(sp) + "）剩下：" + left
	return msg


# ---- ㊿y：角色星（命座/星魂排布）----
# 表在 shared/data_stars.gd（十八级内容、碎片与银两表）。
#   · 顺序解锁：第 n 星只能从 n-1 星升上来（跟命座/星魂一样，不能跳级）
#   · 材料：该角色的**碎片**（游历红件掉，一次 1 片）+ 银两（吃"妙手"折扣）
#   · 收益分两路：stat 走进 tfx 那一套（战斗/面板/估算都吃），
#     mech 走进运签卡那一套（见 role_star_mech_fx 与各引擎的落点）
#   · 存档键 world.role_stars；capture_player 的白名单里必须有它，
#     否则引子快照那一下会把主角的星抹掉
static var role_stars := {}

static func role_star_of(rid: String) -> int:
	return int(role_stars.get(rid, 0))

# ============================================================
# v65f（用户："大招的怒气的显示是不是该更新了 怎么还是34？"）：
#   弟子面板的大招页把"每行动一次 +34"**写死**了——可战斗里实际涨的是
#     **34 × 0.7（全体怒气 -30%）× 本人的怒气加成**
#   （出口：journey/duel_battle 3868 与 menu/battle_lite 1632，两条式子同源）。
#   少侠带「引气归元」（rage_up +30%）→ 34×0.7×1.3 ≈ **31**；陈石/苏 的被动不是
#   rage 类 → **24**。这里给"某个角色每行动一次涨多少"的**唯一出口**，
#   面板只许读它——以后再调怒气的旋钮，显示自动跟着变。
#   ⚠ 这一份是**村里口径**（不含这一趟的卡组/加持：聚气令 bless_rage、挫锐…）。
# ============================================================
static func rage_per_action(rid: String) -> int:
	# 两个旋钮：游历那套读 journey/duel_rage_gain · 塔战那套读 combat/rage_gain（默认都是 34）。
	#   显示取两者较大的一档，免得调了其中一个、面板还写旧数。
	var base_gain := maxi(Tuning.intv("journey", "duel_rage_gain", 34), Tuning.intv("combat", "rage_gain", 34))
	var base := float(base_gain) * Tuning.num("combat", "rage_mul", 0.7)
	var ps: Dictionary = _role_mut(rid).get("passive", {})
	var pv := 0.0
	if str(ps.get("kind", "")) == "rage_up":
		pv = float(ps.get("v", 0.0))
	# 被动强化（角色星 ＋ 专武的 passive_up）——与两套战斗的 rage_mul 同一口径
	var pup := 1.0 + float(combat_mech(rid).get("passive_up", 0.0))
	return maxi(1, int(round(base * (1.0 + pv * pup))))

static func role_star_max() -> int:
	return Stars.MAX

static func role_star_frag_name(rid: String) -> String:
	return fragment_name(Stars.frag_key(rid))

static func role_star_cost_frag(rid: String) -> int:
	return Stars.cost_frag(role_star_of(rid) + 1)

static func role_star_cost_silver(rid: String) -> int:
	var s := Stars.cost_silver(role_star_of(rid) + 1)
	if s <= 0:
		return 0
	return int(round(float(s) * player_talent_cost_mul()))

# 能不能升（只算账，不动）
static func role_star_can(rid: String) -> Dictionary:
	if not Stars.is_star_role(rid):
		return {"ok": false, "msg": "这个人还没有星谱"}
	var cur := role_star_of(rid)
	if Stars.levels(rid).is_empty():
		return {"ok": false, "msg": "这个人还没有星谱"}
	if cur >= role_star_max():
		return {"ok": false, "msg": "已经是 " + str(role_star_max()) + " 星（满）"}
	var need := role_star_cost_frag(rid)
	var have := fragment_count(Stars.frag_key(rid))
	if have < need:
		return {"ok": false, "msg": role_star_frag_name(rid) + "不够：升到 " + str(cur + 1) + " 星要 " + str(need) + " 片（现有 " + str(have) + "）"}
	var sp := role_star_cost_silver(rid)
	if coin("silver") < sp:
		return {"ok": false, "msg": "银两不够：还要 " + str(sp) + " 两（现有 " + str(coin("silver")) + "）"}
	return {"ok": true, "msg": ""}

static func role_star_up(rid: String) -> String:
	var chk := role_star_can(rid)
	if not bool(chk.get("ok", false)):
		return str(chk.get("msg", "升不了"))
	var cur := role_star_of(rid)
	var fid := Stars.frag_key(rid)
	var need := role_star_cost_frag(rid)
	var sp := role_star_cost_silver(rid)
	fragments[fid] = fragment_count(fid) - need
	add_coin("silver", -sp)
	role_stars[rid] = cur + 1
	var nm := str(_role_mut(rid).get("name", rid))
	var msg := "「" + nm + "」升到 " + str(cur + 1) + " 星【" + Stars.star_name(rid, cur + 1) + "】：" + Stars.star_desc(rid, cur + 1)
	msg += "（" + role_star_frag_name(rid) + " -" + str(need) + " · 银两 -" + str(sp) + "）"
	# v38/v44：这一星要是带"成长"（气血成长等），把已经过的级数一次补齐
	#   （不然只从下一级才开始涨）。补课口＝ grow_sync。
	var grow := grow_sync(rid)
	if int(grow.get("hp", 0)) != 0 or int(grow.get("atk", 0)) != 0:
		msg += "｜成长补课：已过的级数一次补上 气血 +" + str(int(grow.get("hp", 0))) + " · 攻击 +" + str(int(grow.get("atk", 0)))
	# ㊿z6：**来路暂不开放**（用户自己设计）——所以不再自动发满星礼。
	#   表还在 data_stars.EXCLUSIVE_ART（来路设计好之后直接用它）。
	# if cur + 1 >= role_star_max():
	#     var exs := Stars.exclusive_art(rid)
	#     if exs != "": vault_add_item(exs, 1)
	print("[账本] 角色升星：", msg)
	return msg

# 星带来的两路收益（前 lv 级合并）——战斗/面板/估算都读这两个口
static func role_star_stat_fx(rid: String) -> Dictionary:
	return Stars.stat_fx(rid, role_star_of(rid))

static func role_star_mech_fx(rid: String) -> Dictionary:
	return Stars.mech_fx(rid, role_star_of(rid))

# ---- 建筑链 ----
static var map_found := false
static var b2_built := false
static var cave_opened := false
static var winery_built := false
static var herbs_granted := false
static var dange_built := false
static var auto_climb := false
# ㊿q：自动挑战"人在村里、塔在后台推"。
#   自动挑战（auto_climb）说的是"塔自己往上走"，走法有两种：
#     · 屏幕里连打（auto_bg = false）——清完一关马上开下一场，你要看着；
#     · 后台估算（auto_bg = true）——你按了［挂机回村］，人已经在村里，
#       塔每 20 秒按 formation_dps_est 的估算往上推一关（跟离线挂机同一条路）。
#   它只回答一个问题：**下一关要不要在屏幕上自动开**。auto_climb 关了它就没意义
#   （读它的地方都先看 auto_climb），所以不必每处都同步清掉。
static var auto_bg := false

# ---- 货币 ----
const COIN_CN := {"wen": "文钱", "silver": "银两", "yuanbao": "元宝"}

const STAT_DEFAULTS := {"def": 5, "dodge": 5, "crit_dmg": 50}
const SLOT_CN := {"weapon": "兵器", "armor": "护甲", "helm": "玉佩", "cloak": "披风", "arts": "武学"}

static var village_stage := 0
static var first_journey_done := false
static var first_explore_done := false
static var world_difficulty := 1
static var world_created := false
static var world_history: Array = []
# v139（调试）：**强制重播引子**——只活在内存里，不写盘。
#   存档里 first_journey_done 已经是 true 的档，想再测一遍引子就靠它（主界面 F9 开）。
static var intro_force := false
# v83（用户："引子结束后 给玩家一个弹出起名的窗口【不起名就默认叫少侠】"）：
#   空串＝还没起过名（＝用默认「少侠」）。起了就落盘，全工程的显示都跟着变。
static var player_name := ""
static var disciple_joined := false
static var qingluan_joined := false
static var pending_note := ""
static var vault_cards := {}
static var vault_items := {}
# v242：锻造 V0.1——砧上那一把 ＋ 已收下的成品
static var forge_item := {}
static var forge_bag: Array = []
# v242：锻造动态件（sid -> Cards 动态卡集）——存档载入时重建
static var forge_cards := {}
static var forge_seq := 0
# v242：锻造图鉴（合中过的胚子 id）
static var forge_compendium := {}
static var materials := {}
static var material_q := {}   # "材料|品质" -> 数量；materials 仍是总数量
static var formation := ["player"]
static var stage_progress := 0

# ============================================================
# ㊿ 剧情节点在塔上的位置
#
# 从 menu_sketch 搬过来的（那边原来自己写着三个数）。搬家的原因：
#   货栈的"上架闸"要判"炼丹阁解锁没有"，而那道闸在**本文件**里（shop_items_of），
#   本文件又不该反向去引菜单。数字跟着 stage_progress 放，两边都读这一份。
#   menu_sketch 里那三个常量现在只是这里的别名——名字没变，那边的用法一个字不用改。
#
# 触发条件是"通关数 >= 这个数且该剧情还没放过"，所以老档不会漏戏（进村按顺序补放）。
# 顺序有意义：先得图、再遇人、最后灵草。
# ============================================================
const STORY_MAP_STAGE := 50      # 藏宝图（得「藏宝阁」记号）
const STORY_NVXIA_STAGE := 150   # 苏青鸾入阵（第三人齐）
const STORY_HERB_STAGE := 300    # 灵草三种（炼丹阁开工）
const STORY_JIANBAO_STAGE := 400 # v39：打捞上来的货仓（鉴宝行开张 · 新手引导）

# ㊿：炼丹阁解锁了吗——**过第 300 关（灵草剧情）才算**。
#   菜单那边"牌子要不要显"、货栈那边"宠物丹料要不要上架"、开炉那道闸，
#   三处都问这一口，免得同一件事写三遍。
#   · dange_built   —— 已经起好的炉子不再收回去（老档/按过测试键的档里可能早有）
#   · herbs_granted —— 灵草剧情已放
#   · stage_progress >= STORY_HERB_STAGE —— 兜底：剧情还没补放但关已经过了
static func dange_unlocked() -> bool:
	if dange_built:
		return true
	return herbs_granted or stage_progress >= STORY_HERB_STAGE
static var coins := {"wen": 0, "silver": 0, "yuanbao": 0}

# ---- v64b：**阅历线**（场外养成 → 游历内辅助）----
#   用户："增加一个新线 阅历线 这个是专门场外给予游历内辅助的 挂机给阅历值
#   消耗银两和阅历值可以提升阅历线 · 游历也可以给一点 · 吃挂机档位 ·
#   分四条线 财富【经济】进攻 防御 技巧【暴击 闪避】· 走满要很久 · 要洗点但消耗银两"
#   · 表与价目全在 shared/data_insight.gd（唯一真源）
#   · insight＝现有阅历值；insight_lv＝{支线 → 已升到第几段}
static var insight := 0
static var insight_lv := {}

# ---- v242：**行动资源**（游历门票）----
#   塔挂机产；进图按“一次移动”烧 1 点；站着不动不扣；空了自动安全回村。
static var action := ACTION_START
# v243：山门占位（四道门）
static var sect_favor := 0
static var sect_rep := 0
static var sect_test := false
static var sect_art := false
# v253：入门前后的宗门线
static var sect_joined := false
static var sect_contrib := 0
static var sect_betrayed := false
# v244：世界档 / 舆图（换新世界用）
static var world_seed := 0
static var world_tier := 1
# v246：货郎人情（世界内关系网的第一根线）
static var merchant_favor := 0
# v247：通缉（0~5）——打劫货郎涨，洗白清零
static var wanted := 0
# v249：Boss 首杀记录（山君/夜叉/老妖）
static var boss_kills: Array = []
# v252：常驻牢房（0=自由，3=关押中）
static var jailed_days := 0
# v256：赤水寨归属（0=未动 / 1=已破 / 2=青岚控制）
static var red_water := 0
static var red_water_wall := false
static var red_water_market := false
static var red_water_garrison := false
static var red_water_taxpost := false
static var red_water_peace := false
static var war_score := 0
static var broker_rep := 0
static var broker_quest := 0
static var broker_pardon := false
# v263：北境黑风寨战线（抽象战线）
static var north_score := 0
static var north_peace := false
static var north_wins := 0
static var north_weapon := false
static var north_tax_day := ""
static var ng_plus := 0
static var map_owners: Dictionary = {}
static var world_flags: Dictionary = {}
const PROSPERITY_STEPS := [0, 30, 70, 120, 180]
static var world_prosperity := 0
const REGION_NAMES := ["山", "水", "林", "石", "雪"]
const REGION_BOSSES := ["山君", "夜叉", "老妖", "石傀", "雪魈"]
const REGION_DIFFS := [1, 2, 3, 4, 5]
const REGION_COSTS := [0, 0, 0, 2, 3]
static var current_region := 0
static var region_unlocked: Array = [true, true, true, false, false]
const TIME_NAMES := ["晨", "昼", "夜"]
static var time_slot := 0
static var time_day := 1
static var slot_progress := 0
static var region_rep: Array = [0, 0, 0, 0, 0]
static var region_seen: Array = [false, false, false, false, false]
static var region_walk: Array = [0, 0, 0, 0, 0]
static var merchant_stock_slot := ""
static var merchant_stock: Dictionary = {}
static var npc_stock: Dictionary = {}
static var region_landmarks: Dictionary = {}
static var npc_budget := -1
static var sect_prosperity_rank := 0
static var forge_names: Array = []
static var ng_event_seen := false
static var ng_event_choice := -1
static var ng_echo_seen := false
static var ng_final_seen := false
static var ng_final_choice := -1
static var ng_wuxia_done := false
static var story_title_prosperity := false
static var north_garrison := false
static var broker_weapon := false
# v260：听雨楼密信剧情（0=未触发 / 1=交青岚 / 2=卖赤水 / 3=烧掉）
static var story_letter := 0
static var story_follow := 0
static var story_title := ""
static var snow_charm := false
static var snow_charm2 := false
static var turf_tax_day := ""
static var war_notes: Array = []

static func action_add(n: int) -> int:
	action = clampi(action + n, 0, ACTION_MAX)
	return action

static func food_cap() -> int:
	return ACTION_MAX

static func action_spend(n := 1) -> bool:
	if action < n:
		return false
	action -= n
	slot_progress += n
	while slot_progress >= 20:
		slot_progress -= 20
		time_slot += 1
		if time_slot >= 3:
			time_slot = 0
			time_day += 1
	return true

static func check_sect_rank() -> void:
	var r := 0
	if sect_contrib >= 250:
		r = 2
	elif sect_contrib >= 100:
		r = 1
	if r > sect_prosperity_rank:
		var gain := 5 if r == 1 else 15
		if sect_prosperity_rank >= 1:
			gain = 10
		add_prosperity(gain, "宗门晋升")
		sect_prosperity_rank = r
		save_game()

static func mark_landmark(id: String) -> void:
	var rk := str(current_region)
	var arr: Array = region_landmarks.get(rk, [])
	if not arr.has(id):
		arr.append(id)
	region_landmarks[rk] = arr

static func landmarks(region: int) -> Array:
	return (region_landmarks.get(str(clampi(region, 0, 4)), []) as Array).duplicate()

static func ensure_merchant_stock() -> void:
	var key := str(time_day) + ":" + str(time_slot)
	if merchant_stock_slot == key and not merchant_stock.is_empty():
		return
	merchant_stock_slot = key
	merchant_stock = {"forge_stone": 1, "atlas": 1, "rice": 2, "bone": 2}

static func time_text() -> String:
	return str(TIME_NAMES[clampi(time_slot, 0, 2)]) + " · 第 " + str(time_day) + " 天"

static func add_region_rep(region: int, n: int) -> void:
	var i := clampi(region, 0, 4)
	while region_rep.size() < 5:
		region_rep.append(0)
	region_rep[i] = clampi(int(region_rep[i]) + n, 0, 100)

# ---- 货栈（银两换材料 / 残卡；残卡每日限购，按真实日期重置） ----
const SHOP_CFG := "user://shop.cfg"

const SHOP_ITEMS := [
	# ㊿：兽骨碎/灵米只用于养灵丹，而养灵丹要炼丹阁（300 关）——所以这两样跟着炉子
	#   一起上架。不然第 1 关就能买一堆，压在包里到 300 关才用得上（"上架闸"）。
	{"key": "bone", "name": "兽骨碎", "price": 14, "cat": "basic", "need": "dange", "desc": "养灵丹主料——猎人剩下的硬货"},
	{"key": "rice", "name": "灵米", "price": 11, "cat": "basic", "need": "dange", "desc": "养灵丹辅料——喂灵兽的细粮"},   # v62：10 → 15（×1.4 后被"取整到十"吃掉了，手工补上）
	# ============================================================
	# v64（用户："商店的基础残兵 基础残装备 基础功法 价格下调40% 增加限购 10/每种
	#   同时增加特殊效果 购买时 弥补仓库最缺的那一件或者没有的那一件残页或者残兵 残装备
	#   同时增加良品的残卡【武器/装备/功法】限购5"）：
	#   ① 价：91/119/91 →（v64b 定稿）**凡品一口价 150/120/120**，**不再乘池顶系数**；
	#      良品卡按自己那一档 ×2（300/240/240）。两档都走 shop_card_price() 那一个口。
	#   ② **限购 3/2/2 → 每种 10**（每日，凌晨 4 点换日）。
	#   ③ **不再是"随机一张"**：买的时候**补你仓库里最缺的那一张**——优先"差一张就齐"的套，
	#      其次一张都没有的套，再次缺得最多的套；全齐了才退回随机（见 _shop_pick_missing）。
	#   ④ 新增**良品**残卡三种（限购 **5**）：只补良品套的缺页——池子滑过去了也能补齐旧套。
	#   ⚠ desc 都要短（货栈那一行只放得下 ~19 字，长了会溢到右边价格/按钮上）。
	# ============================================================
	#   v64b（用户："基础的就是凡品 这个价格太低了 全部120吧 兵器150"）：
	#     **基础卡＝凡品货**，价按凡品一口价写死——**不再跟现役池顶品级涨**（原来池子一升价就跟着翻）：
	#     兵器 **150** · 武学 **120** · 装备 **120**；补缺也只在**凡品套**里补（它就是凡品那一档的货）。
	{"key": "weapon_card", "name": "基础兵器残卡", "price": 150, "cat": "weapon", "desc": "一张凡品兵器残卡", "kind": "card", "pool": "weapon", "q": 0, "limit": 10},
	{"key": "art_card", "name": "基础武学残页", "price": 120, "cat": "arts", "desc": "一张凡品武学残页", "kind": "card", "pool": "arts", "q": 0, "limit": 10},
	{"key": "gear_card", "name": "基础装备残卡", "price": 120, "cat": "gear", "desc": "一张凡品装备残卡", "kind": "card", "pool": "gear", "q": 0, "limit": 10},
	#   ⚠ 良品卡的 price 写**凡品基价**，实际价由 shop_card_price 按它自己的 q 乘系数
	#     （良品 ×2）——用户："良品你看着来"：就按品级系数走，与凡品同比例：
	#     兵器 150→**300** · 武学 120→**240** · 装备 120→**240**。
	{"key": "weapon_card_l", "name": "良品兵器残卡", "price": 150, "cat": "weapon", "desc": "一张良品兵器残卡", "kind": "card", "pool": "weapon", "q": 1, "limit": 5},
	{"key": "art_card_l", "name": "良品武学残页", "price": 120, "cat": "arts", "desc": "一张良品武学残页", "kind": "card", "pool": "arts", "q": 1, "limit": 5},
	{"key": "gear_card_l", "name": "良品装备残卡", "price": 120, "cat": "gear", "desc": "一张良品装备残卡", "kind": "card", "pool": "gear", "q": 1, "limit": 5},
	# v62c（用户："商店卖的那个血脉变为随机 90%紫色 8.9%金色 0.1%红色"）：
	#   名字从「金纹血脉囊」改成**「血脉囊」**——原来名字里写死"金"，现在九成是紫的，
	#   挂着"金纹"就是名不副实（想改回去只动 name 这一处）。
	# v63（用户："这里显示有点问题"）：血脉囊的 desc 太长 ✗ 一路溢进右边价格/按钮区 ✗。
	#   拆短：概率放第一行（框内 19 字 ✓），纯度/用途挪进货栈自己的"开出血脉"行。
	{"key": "blood_gold", "name": "血脉囊", "price": 273, "cat": "basic", "desc": "里面包裹着一个未知的血脉", "kind": "blood", "limit": 1},
	# v36：突破丹五品（货栈这一路——每天限购几颗，炼丹阁是另一条路）。
	#   品级跟境界走：1~8 重凡品、9~16 良品……33~40 绝品（见 GameState.BREAK_PILLS）。
	#   ⚠ v47（用户："商店突破丹只给低级和中级的【现在阶段够用】"）：
	#     **货栈只上架凡品与良品**；上品 / 极品 / 绝品从货栈撤了——
	#     那三品往后靠**炼丹阁**（DAN_RECIPES 五品都在）与**爬塔宝箱**（金/玉/龙箱出上品起）拿。
	#     理由：现在游戏推进到的阶段（境界十几重上下）用得上、也买得起的就是这两品；
	#     高品挂在店里既没人买得起，又显得"花钱就能一路突破"。
	{"key": "tupo_fan", "name": "突破丹（凡品）", "price": 147, "cat": "pill", "kind": "pill", "pid": "tupo_fan", "limit": 3, "desc": "突破使用的丹药"},
	{"key": "tupo_liang", "name": "突破丹（良品）", "price": 413, "cat": "pill", "kind": "pill", "pid": "tupo_liang", "limit": 2, "desc": "突破使用的丹药"},
	{"key": "adv_fan", "name": "进阶丹（凡品）", "price": 800, "cat": "pill", "kind": "pill", "pid": "adv_fan", "limit": 2, "desc": "冲境界使用的丹药"},
	{"key": "adv_liang", "name": "进阶丹（良品）", "price": 2400, "cat": "pill", "kind": "pill", "pid": "adv_liang", "limit": 1, "desc": "冲境界使用的丹药"},
	# v41：金色材料「金髓」——洗灵丹的硬门槛。贵、且每日只放一块（其余靠宝箱与搜刮）
	{"key": "jin", "name": "◆金髓", "price": 910, "cat": "basic", "need": "dange", "limit": 1, "desc": "稀有材料"},
	# v39：鉴宝行的侦查道具（过 400 关才上架）——三样各管一段信息，见 shared/data_appraise.gd
	{"key": "tool_sight", "name": "描影镜", "price": 119, "cat": "jianbao", "kind": "tool", "tid": "sight", "limit": 3,
		"need": "jianbao", "desc": "照出货仓里最值钱的一件"},
	{"key": "tool_lamp", "name": "透物灯", "price": 196, "cat": "jianbao", "kind": "tool", "tid": "lamp", "limit": 2,
		"need": "jianbao", "desc": "照出两三件货的轮廓"},
	{"key": "tool_seal", "name": "识宝鉴", "price": 315, "cat": "jianbao", "kind": "tool", "tid": "seal", "limit": 2,
		"need": "jianbao", "desc": "看清一件货的详情"},
	# v50（用户："解锁鉴宝后 商店卖限购的鉴定道具（效果较强的价格也贵）；同时增加一个
	#   可以显示当前仓库多少格子（较贵）和显示所有紫色轮廓/金色轮廓/绿色轮廓等"）：
	#   数格尺（最贵的那一档信息——店里不给格数）＋ 四把按成色筛的筛子。价钱按效果排。
	{"key": "tool_count", "name": "数格尺", "price": 413, "cat": "jianbao", "kind": "tool", "tid": "count", "limit": 2,
		"need": "jianbao", "desc": "量出货仓的格数"},
	{"key": "tool_sift_g", "name": "碧砂筛", "price": 154, "cat": "jianbao", "kind": "tool", "tid": "sift_g", "limit": 3,
		"need": "jianbao", "desc": "标出全部绿档货"},
	{"key": "tool_sift_p", "name": "紫霞筛", "price": 294, "cat": "jianbao", "kind": "tool", "tid": "sift_p", "limit": 2,
		"need": "jianbao", "desc": "标出全部紫档货"},
	{"key": "tool_sift_j", "name": "金纹筛", "price": 609, "cat": "jianbao", "kind": "tool", "tid": "sift_j", "limit": 2,
		"need": "jianbao", "desc": "标出全部金档货"},
	{"key": "tool_sift_r", "name": "朱砂筛", "price": 1050, "cat": "jianbao", "kind": "tool", "tid": "sift_r", "limit": 1,
		"need": "jianbao", "desc": "标出全部红档货"},
]

# ㊿：上架闸——这一条现在该不该摆在货架上。
#   没写 need 的永远上架；写了就按那个条件判（现在只有 "dange" 一种）。
static func shop_need_met(it: Dictionary) -> bool:
	var need := str(it.get("need", ""))
	if need == "":
		return true
	if need == "dange":
		return dange_unlocked()
	if need == "jianbao":
		return jianbao_ok()   # v39：鉴宝行的侦查道具（过 400 关才进货）
	return true

const SHOP_CATS := [
	{"id": "basic", "name": "材料"},
	{"id": "weapon", "name": "兵器"},
	{"id": "arts", "name": "武学"},
	{"id": "gear", "name": "装备"},
	{"id": "pill", "name": "丹药"},
	{"id": "jianbao", "name": "鉴宝"},  # v39：三种侦查道具（过 400 关才上架）
]

static var shop_day := ""      # 今日（真实日期；跨天自动重置）
static var shop_used := {}     # 今日各限购品已买数

static func shop_item_of(k: String) -> Dictionary:
	for it in SHOP_ITEMS:
		if str(it["key"]) == k:
			return it
	return {}

# v112（用户："商店的档位也同时更改 如果是凡品档就出凡品 极品档就出极品【随着档位增加限购减少】"）：
#   货栈的**残卡那一行**不再写死凡品/良品两档——按玩家当下的品级（ladder_phase）动态出：
#     凡品档 → 凡品残卡（每日限购 10）· 良品 → 5 · 上品 → 3 · **极品 → 2**
#   于是"档位越高，货越好、量越少"。价不用管——面板按 q 走 shop_card_price 那一口。
#   ⚠ 良品那三行（key 以 _l 结尾）撤掉，否则同一件货会摆两遍。
const SHOP_CARD_LIMIT := [10, 5, 3, 2]

static func shop_items_of(cat: String) -> Array:
	var out: Array = []
	var ph := clampi(ladder_phase(), 0, SHOP_CARD_LIMIT.size() - 1)
	for it in SHOP_ITEMS:
		if str(it.get("cat", "")) != cat:
			continue
		# ㊿：上架闸——没解锁的那几样不摆出来（面板直接读这个口，所以一处就够）
		if not shop_need_met(it):
			continue
		if str(it.get("kind", "")) == "card":
			if str(it.get("key", "")).ends_with("_l"):
				continue   # v112：良品那一套行撤掉——档位改由品级动态决定
			var row: Dictionary = (it as Dictionary).duplicate()
			var qn := str(Cards.QUALITY_ORDER[ph])
			row["q"] = ph
			row["limit"] = int(SHOP_CARD_LIMIT[ph])
			row["name"] = qn + String(row["name"]).replace("基础", "")
			row["desc"] = qn + "残卡一张——补仓库最缺的那张（本档每日 " + str(int(SHOP_CARD_LIMIT[ph])) + " 张）"
			out.append(row)
			continue
		out.append(it)
	return out

static func _shop_sync_day() -> void:
	# v39：换日点是**凌晨 4:00**（见上面的 DAY_RESET_HOUR）——不再按日历日 0:00
	var d := day_key()
	if shop_day == d:
		return
	shop_day = d
	var u := {}
	var cf := ConfigFile.new()
	if cf.load(SHOP_CFG) == OK and str(cf.get_value("shop", "day", "")) == d:
		u = cf.get_value("shop", "used", {})
	shop_used = u
	_shop_save()

static func _shop_save() -> void:
	var cf := ConfigFile.new()
	cf.load(SHOP_CFG)
	cf.set_value("shop", "day", shop_day)
	cf.set_value("shop", "used", shop_used)
	cf.save(SHOP_CFG)

static func shop_left(k: String) -> int:
	# -1 = 不限购；0 = 今日已售罄
	var item := shop_item_of(k)
	if item.is_empty():
		return 0
	var kd := str(item.get("kind", "mat"))
	# v36：突破丹（kind="pill"）也是限购货——口径与残卡、血脉囊一样
	# v39：鉴宝道具（kind="tool"）同样每日限购
	if kd != "card" and kd != "blood" and kd != "pill" and kd != "tool":
		return -1
	_shop_sync_day()
	return maxi(0, int(item.get("limit", 0)) - int(shop_used.get(k, 0)))

# R4：村货栈残卡一口价＝基价 ×（现役池里最高品级的系数）——池里最贵的货什么价，
# 零售就按它收（可能付高品价开出凡品，认这一点；池一变价自动跟）。
static func shop_card_price(k: String) -> int:
	var item := shop_item_of(k)
	if item.is_empty():
		return 0
	var base := int(item.get("price", 0))
	if str(item.get("kind", "mat")) != "card":
		return base
	# v64：**自己点了品级的货（良品残卡）按自己那一档算**，不再跟池顶跑
	#   （它给的就是良品，跟着池顶涨到极品价就名不副实了）；基础残卡照旧＝池顶一口价。
	if item.has("q"):
		var qq := clampi(int(item.get("q", 0)), 0, Cards.PRICE_MUL.size() - 1)
		return int(round(float(base) * float(Cards.PRICE_MUL[qq])))
	var ids: Array = shop_pool_of(str(item.get("pool", "")))
	var q := 0
	for sid_v in ids:
		q = maxi(q, Cards.q_idx(str(sid_v)))
	return int(round(float(base) * float(Cards.PRICE_MUL[clampi(q, 0, Cards.PRICE_MUL.size() - 1)])))


static func buy_material(k: String, n: int) -> Dictionary:
	var item := shop_item_of(k)
	if item.is_empty():
		return {"ok": false, "msg": "货架上没有这个"}
	# ㊿：上架闸的第二道——没解锁的东西就算有人拿 key 直接调也买不到
	if not shop_need_met(item):
		var need0 := str(item.get("need", ""))
		var gate := "过第 " + str(STORY_HERB_STAGE) + " 关（灵草剧情）后才进货"
		if need0 == "jianbao":
			gate = "过第 " + str(STORY_JIANBAO_STAGE) + " 关（打捞上来的货仓那段剧情）后才进货"
		return {"ok": false, "msg": "「" + str(item.get("name", k)) + "」还没上架——" + gate}
	if str(item.get("kind", "mat")) == "blood":
		return _buy_blood(item)
	if str(item.get("kind", "mat")) == "pill":
		return _buy_pill(item, maxi(n, 1))   # v36：突破丹（每日限购）
	if str(item.get("kind", "mat")) == "tool":
		return _buy_tool(item, maxi(n, 1))   # v39：鉴宝道具（每日限购）
	if str(item.get("kind", "mat")) == "card":
		return _buy_card(item, maxi(n, 1))
	var price := int(item["price"]) * n
	if coin("silver") < price:
		return {"ok": false, "msg": "银两不够：要 " + str(price) + "（现有 " + str(coin("silver")) + "）"}
	add_coin("silver", -price)
	add_material(k, n)
	return {"ok": true, "msg": "买了「" + str(item["name"]) + "」×" + str(n) + "（花 " + str(price) + " 两，现共 " + str(material_count(k)) + "）"}

# v64：这一套在仓库里还差几张（0 ＝ 齐了）
static func _shop_set_missing(sid: String) -> int:
	var parts: Array = Cards.parts_of(sid)
	if parts.is_empty():
		return 0
	var bucket: Dictionary = vault_cards.get(sid, {})
	var n := 0
	for i in parts.size():
		if int(bucket.get(i, 0)) <= 0:
			n += 1
	return n

# ============================================================
# v64（用户："购买时 弥补仓库最缺的那一件或者没有的那一件残页或者残兵 残装备"）：
#   从这几套里挑"最该补的那一张"，返回 {"sid":…, "part":…}；**全都齐了**才返回 {}
#   （调用方退回随机——不让钱白花）。优先级（越靠前越该补）：
#     ① **差一张就齐**的套——拿下去当场能合成，最有用（同档里挑手里件数最多的那套）
#     ② **一张都没有**的套——开个头
#     ③ 其余：缺得越多的套越优先
#   ⚠ 只看**仓库残卡**（vault_cards）——店里买来的也是进那里，口径同一处。
# ============================================================
static func _shop_pick_missing(ids: Array) -> Dictionary:
	var best_sid := ""
	var best_part := -1
	var best_score := -1
	for sid_v in ids:
		var sid := str(sid_v)
		var parts: Array = Cards.parts_of(sid)
		if parts.is_empty():
			continue
		var bucket: Dictionary = vault_cards.get(sid, {})
		var own := 0
		var miss: Array = []
		for i in parts.size():
			var c := int(bucket.get(i, 0))
			own += c
			if c <= 0:
				miss.append(i)
		if miss.is_empty():
			continue              # 这套已经齐了
		var score := 0
		if miss.size() == 1:
			score = 100000 + own
		elif own == 0:
			score = 50000
		else:
			score = miss.size()
		if score > best_score:
			best_score = score
			best_sid = sid
			best_part = int(miss[randi() % miss.size()])
	if best_sid == "":
		return {}
	return {"sid": best_sid, "part": best_part}

static func _buy_card(item: Dictionary, n: int) -> Dictionary:
	_shop_sync_day()
	var key := str(item.get("key", ""))
	var lim := int(item.get("limit", 1))
	var left := maxi(0, lim - int(shop_used.get(key, 0)))
	if left <= 0:
		return {"ok": false, "msg": "「" + str(item["name"]) + "」今日已经卖完了——明天再来（每日限购 " + str(lim) + "）"}
	var cnt := mini(n, left)
	var price := shop_card_price(key) * cnt   # R4：池顶品级一口价
	if coin("silver") < price:
		return {"ok": false, "msg": "银两不够：要 " + str(price) + "（现有 " + str(coin("silver")) + "）——「" + str(item["name"]) + "」" + str(shop_card_price(key)) + " 两/张"}
	var pool := str(item.get("pool", ""))
	var ids: Array = shop_pool_of(pool)   # R4/㊽：普通池走现役卡池；装备走三池合一
	if ids.is_empty():
		return {"ok": false, "msg": "这类货还没备好（数据表里查不到）——再看"}
	# v64（用户："购买时 弥补仓库最缺的那一件或者没有的那一件"）：
	#   **良品残卡**只在良品套里补缺（池子是滑动窗，旧套滑出去了也得能补齐）；
	#   基础残卡仍在**现役池**里补缺（它的货就是"现役"那几套）。
	if item.has("q"):
		var by_q: Array = Ladder.sets_of_q(pool, int(item.get("q", 0)))
		if not by_q.is_empty():
			ids = by_q
	add_coin("silver", -price)
	var got: Array = []
	for i in cnt:
		var pick := _shop_pick_missing(ids)
		var sid := ""
		var part := 0
		var tail := ""
		if pick.is_empty():
			# 这一类的套**全都齐了**——没得补，退回随机一张（不让钱白花）
			sid = str(ids[randi() % ids.size()])
			part = randi() % maxi(1, Cards.part_count(sid))
		else:
			sid = str(pick["sid"])
			part = int(pick["part"])
			var leave := _shop_set_missing(sid) - 1
			tail = "（这套齐了！）" if leave <= 0 else "（还差 " + str(leave) + " 张）"
		vault_deposit({sid: {part: 1}})
		got.append(str(Cards.card_name(sid, part)) + tail)
	shop_used[key] = int(shop_used.get(key, 0)) + cnt
	_shop_save()
	print("[账本] 货栈残卡：", key, " ×", cnt, " → ", got, "（今日剩 ", left - cnt, "）")
	return {"ok": true, "msg": "买了「" + str(item["name"]) + "」×" + str(cnt) + "——开出：" + "、".join(PackedStringArray(got)) + "（收进仓库 · 今日还剩 " + str(left - cnt) + " 张）", "got": got}

static func _buy_blood(item: Dictionary) -> Dictionary:
	_shop_sync_day()
	var key := str(item.get("key", ""))
	var lim := int(item.get("limit", 1))
	var left := maxi(0, lim - int(shop_used.get(key, 0)))
	if left <= 0:
		return {"ok": false, "msg": "「" + str(item["name"]) + "」今日已经卖完了——明天再来（每日限购 " + str(lim) + "）"}
	var price := int(item.get("price", 0))
	if coin("silver") < price:
		return {"ok": false, "msg": "银两不够：要 " + str(price) + "（现有 " + str(coin("silver")) + "）"}
	add_coin("silver", -price)
	# v62c（用户："商店卖的那个血脉变为随机 90%紫色 8.9%金色 0.1%红色"）：
	#   原来是**指定金品**（roll_blood(3)）；现在按 DataPets.POUCH_ROLL 摇档再摇具体那味。
	var bid := DataPets.roll_blood_pouch()
	var pur := randi_range(30, 100)
	blood_add(bid, pur)
	shop_used[key] = int(shop_used.get(key, 0)) + 1
	_shop_save()
	save_game()
	return {"ok": true, "msg": "开出「" + DataPets.blood_name(bid) + "」（纯 " + str(pur) + "）——已放进行囊，去宠物面板融合"}

# v36：突破丹（货栈这一路）——按颗卖、每日限购，收进丹药包裹（与炼丹阁同一个库）。
static func _buy_pill(item: Dictionary, n: int) -> Dictionary:
	_shop_sync_day()
	var key := str(item.get("key", ""))
	var pid := str(item.get("pid", key))
	var lim := int(item.get("limit", 1))
	var left := maxi(0, lim - int(shop_used.get(key, 0)))
	if left <= 0:
		return {"ok": false, "msg": "「" + str(item["name"]) + "」今日已经卖完了——明天再来（每日限购 " + str(lim) + "）"}
	var cnt := mini(n, left)
	var price := int(item.get("price", 0)) * cnt
	if coin("silver") < price:
		return {"ok": false, "msg": "银两不够：要 " + str(price) + "（现有 " + str(coin("silver")) + "）——「" + str(item["name"]) + "」" + str(int(item.get("price", 0))) + " 两/颗"}
	add_coin("silver", -price)
	pills[pid] = int(pills.get(pid, 0)) + cnt
	shop_used[key] = int(shop_used.get(key, 0)) + cnt
	_shop_save()
	save_game()
	print("[账本] 货栈丹药：", key, " ×", cnt, "（今日剩 ", left - cnt, "）")
	return {"ok": true, "msg": "买了「" + str(item["name"]) + "」×" + str(cnt) + "（花 " + str(price) + " 两 · 包裹共 " + str(int(pills.get(pid, 0))) + " 颗 · 今日还剩 " + str(left - cnt) + "）"}

# v39：鉴宝道具（货栈这一路）——与突破丹同一个限购口径。
static func _buy_tool(item: Dictionary, n: int) -> Dictionary:
	_shop_sync_day()
	var key := str(item.get("key", ""))
	var tid := str(item.get("tid", ""))
	var lim := int(item.get("limit", 1))
	var left := maxi(0, lim - int(shop_used.get(key, 0)))
	if left <= 0:
		return {"ok": false, "msg": "「" + str(item["name"]) + "」今日已经卖完了——明天再来（每日限购 " + str(lim) + "）"}
	var cnt := mini(n, left)
	var price := int(item.get("price", 0)) * cnt
	if coin("silver") < price:
		return {"ok": false, "msg": "银两不够：要 " + str(price) + "（现有 " + str(coin("silver")) + "）——「" + str(item["name"]) + "」" + str(int(item.get("price", 0))) + " 两/个"}
	add_coin("silver", -price)
	appraise_tool_add(tid, cnt)
	shop_used[key] = int(shop_used.get(key, 0)) + cnt
	_shop_save()
	save_game()
	print("[账本] 货栈鉴宝道具：", key, " ×", cnt, "（今日剩 ", left - cnt, "）")
	return {"ok": true, "msg": "买了「" + str(item["name"]) + "」×" + str(cnt) + "（花 " + str(price) + " 两 · 现有 " + str(appraise_tool_count(tid)) + " 个 · 今日还剩 " + str(left - cnt) + "）"}

# ============================================================
# v39：鉴宝行（用户设计：400 关剧情"打捞上来的货仓"→ 解锁；用银两买未知货仓，
#   买之前可以用道具侦查；内容＝搜刮那一套但爆率更高）
#
# 三块账：
#   · `jianbao_unlocked` —— 剧情放过没有（也是货栈"侦查道具"的上架闸）
#   · `appraise_tools`   —— 道具背包（tid → 个数）
#   · `appraise_offers`  —— **摆在店里的三只未知货仓**：一条＝
#        {"uid": 唯一号, "hid": 档位, "items": [内容…], "seen": {格号: "outline"/"full"},
#         "best": 最值钱那一格的号（描影镜照出来的）, "free": 是不是剧情送的那只}
#     内容**买之前就掷好了**（不然"侦查"没有意义）；掷好就存进档，
#     所以读档/退出不会刷新货仓（不能靠"重进刷货"）。
#   ⚠ 后续联机：一只货仓＝一条独立数据，要同步/分享就搬这一条，别另起结构。
# ============================================================
static var jianbao_unlocked := false
static var appraise_tools := {}
static var appraise_offers: Array = []
static var appraise_opened := 0        # 一共开过几只（面板上写着玩）
static var appraise_best := 0          # 开出来最值钱的一件的估价（记一笔"战果"）
static var _appraise_uid := 0          # 报价单的自增号（存档里也留着，免得重进撞号）

static func jianbao_ok() -> bool:
	return jianbao_unlocked

# ---- 道具 ----
static func appraise_tool_count(tid: String) -> int:
	return int(appraise_tools.get(tid, 0))

static func appraise_tool_add(tid: String, n := 1) -> void:
	if tid == "":
		return
	appraise_tools[tid] = maxi(0, int(appraise_tools.get(tid, 0)) + n)

static func appraise_tool_line() -> String:
	var out: Array = []
	for tid in Appraise.TOOL_ORDER:
		out.append(Appraise.tool_name(str(tid)) + "×" + str(appraise_tool_count(str(tid))))
	return " · ".join(PackedStringArray(out))

# ---- 报价单 ----
static func world_resource_mul() -> float:
	return [1.0, 1.3, 1.6][clampi(world_difficulty - 1, 0, 2)]

static func gear_salvage_mats(sid: String) -> Dictionary:
	var q := Cards.q_idx(sid)
	var out := {"forge_stone": int([2, 4, 6, 8, 12][clampi(q, 0, 4)])}
	if q == 1:
		out["bone"] = 1
	elif q == 2:
		out["rice"] = 1
	elif q >= 3:
		out["jin"] = 1
	return out

static func _appraise_strip_gear(items: Array) -> Array:
	var out: Array = []
	for e_v in items:
		var e: Dictionary = e_v
		var ek := str(e.get("kind", ""))
		var eid := str(e.get("id", ""))
		var s: Dictionary = Cards.by_id(eid)
		var pool := str(s.get("pool", ""))
		if (ek == "item" or ek == "card") and ["weapon", "armor", "helm", "cloak"].has(pool):
			var q := Cards.q_idx(eid)
			var stones: int = [2, 4, 6, 8, 12][clampi(q, 0, 4)]
			out.append({"kind": "mat", "id": "forge_stone", "name": "锻造石 ×" + str(stones),
				"amount": stones, "gap": 2, "red": false})
			if q == 1:
				out.append({"kind": "mat", "id": "bone", "name": "兽骨碎 ×1", "amount": 1, "gap": 1, "red": false})
			elif q == 2:
				out.append({"kind": "mat", "id": "rice", "name": "灵米 ×1", "amount": 1, "gap": 1, "red": false})
			elif q >= 3:
				out.append({"kind": "mat", "id": "jin", "name": "金髓 ×1", "amount": 1, "gap": 1, "red": false})
			continue
		if ek == "pill":
			var rr: Dictionary = recipe_of(eid)
			if not rr.is_empty():
				for ck in (rr.get("cost", {}) as Dictionary).keys():
					var cn := int(rr["cost"][ck])
					out.append({"kind": "mat", "id": str(ck), "name": mat_name(str(ck)) + " ×" + str(cn), "amount": cn, "gap": 1, "red": false})
				continue
		out.append(e)
	return out

static func _appraise_new_offer(hid: String, free := false) -> Dictionary:
	var d: Dictionary = Appraise.hold_def(hid)
	if d.is_empty():
		return {}
	_appraise_uid += 1
	var raw_items: Array = Ladder.roll_hold(int(d.get("cells", 24)), int(d.get("tier", 0)),
		Ladder.base_q_now(ladder_phase()), float(d.get("luck", 1.0)))
	var items: Array = _appraise_strip_gear(raw_items)
	var mq := clampi(int(d.get("tier", 0)), 0, 4)
	for e_v in items:
		var e: Dictionary = e_v
		if str(e.get("kind", "")) == "mat":
			e["q"] = mq
	return {
		"uid": _appraise_uid,
		"hid": hid,
		# v59：改用**六行阶梯表**（Ladder.roll_hold）——
		#   行＝大件/大奖具/中件/中奖具/小件/稀有小件；列＝蓝(良品)/紫(上品)/金(极品)/红(绝品)
		#   每一行只抽**它自己那一档的色**（用户："每档只能抽它自己那一行的色"），
		#   村里炉火进度（ladder_phase）决定基准难度：0→凡品 1→良品 2→上品 3→极品，
		#   绝品只能靠"红行 +1/+2"越阶（"后面就是良品了/16之后就是上品"）。
		"items": items,
		"seen": {},
		"best": -1,
		"free": free,
		# v50：这只仓一共几格（画格子区用）。**店里不显示**——想知道得花「数格尺」。
		"cells": maxi(4, int(d.get("cells", 8))),
		"cells_known": false,
	}

# 保证店里有 OFFER_N 只——不够就补（补出来的按档位权重抽）
static func _appraise_drop_retired_offers() -> void:
	# v59：货仓档位从 9 档换成 5 档（wood/lacq/bronze/silver/gold），**老档里躺在货架上的
	#   那三只**还是旧 id（rust/sealed/lacquer/iron/…）。`Appraise.hold_def()` 对它们返回空：
	#   名字会显示成 "rust"，`hold_price_now()` 返回 **0** —— 于是变成"0 两白拿一只空箱子"
	#   （买下时 `_appraise_new_offer` 又返回 {} ，钱货两空）。
	#   这里在**读档时**把认不出的货仓摘掉，让 `appraise_ensure_offers()` 重新铺三只新的。
	#   ⚠ 只丢"货架上的未知货仓"——已经买下的东西在仓库里，这条不碰。
	if appraise_offers.is_empty():
		return
	var left: Array = []
	var dropped := 0
	for o_v in appraise_offers:
		var o: Dictionary = o_v
		if Appraise.hold_def(str(o.get("hid", ""))).is_empty():
			dropped += 1
			continue
		left.append(o)
	if dropped > 0:
		appraise_offers = left
		print("[鉴宝行] 清掉 ", dropped, " 只**换档前的老货仓**（旧档 id 已经不认了），重新铺货")

static func appraise_ensure_offers() -> void:
	if not jianbao_unlocked:
		return
	for o_v in appraise_offers:
		var o: Dictionary = o_v
		o["items"] = _appraise_strip_gear(o.get("items", []))
	Appraise.sync_phase(hold_phase())        # v59：先把手里的货色相位交给鉴宝行（价与闸都看它）· v110：夹到 2~3
	while appraise_offers.size() < Appraise.OFFER_N:
		var o: Dictionary = _appraise_new_offer(Appraise.roll_hold_id(hold_phase()))   # v110：货仓档位同上品/极品
		if o.is_empty():
			return
		appraise_offers.append(o)

static func appraise_offer(uid: int) -> Dictionary:
	for o_v in appraise_offers:
		var o: Dictionary = o_v
		if int(o.get("uid", -1)) == uid:
			return o
	return {}

# 解锁（400 关剧情那一下调它）：开张 + 送一套**新手道具** + 把"打捞上来的那只"摆上架
static func jianbao_unlock() -> String:
	if jianbao_unlocked:
		appraise_ensure_offers()
		return "鉴宝行早就开张了（店里 " + str(appraise_offers.size()) + " 只货仓等着看）"
	jianbao_unlocked = true
	appraise_tool_add("sight", 2)
	appraise_tool_add("lamp", 1)
	appraise_tool_add("seal", 1)
	var first: Dictionary = _appraise_new_offer("rust", true)
	if not first.is_empty():
		appraise_offers.append(first)
	appraise_ensure_offers()
	save_game()
	var msg := "「鉴宝行」开张了——那只打捞上来的货仓就摆在店里（不收钱，先拿它练手）｜送："
	msg += appraise_tool_line()
	print("[账本] 鉴宝行：", msg)
	return msg

# 侦查：用掉一个道具，按道具的 kind 亮出信息。返回 {ok, msg}
static func appraise_use(uid: int, tid: String) -> Dictionary:
	var o: Dictionary = appraise_offer(uid)
	if o.is_empty():
		return {"ok": false, "msg": "这只货仓不在店里了"}
	var d: Dictionary = Appraise.tool_def(tid)
	if d.is_empty():
		return {"ok": false, "msg": "没有这种道具"}
	if appraise_tool_count(tid) <= 0:
		return {"ok": false, "msg": "「" + Appraise.tool_name(tid) + "」用完了——货栈有卖（过 " + str(STORY_JIANBAO_STAGE) + " 关才进货）"}
	var items: Array = o.get("items", [])
	if items.is_empty():
		return {"ok": false, "msg": "这只是空仓——直接买下来看看"}
	var seen: Dictionary = o.get("seen", {})
	var kind := str(d.get("kind", ""))
	var msg := ""
	if kind == "best":
		# 描影镜：标出**最值钱那一件**的轮廓（不知是哪一格？知道是它，但只给轮廓）
		var bi := _appraise_best_idx(items)
		o["best"] = bi
		seen[str(bi)] = "outline"
		msg = "「" + Appraise.tool_name(tid) + "」照出一件硬货的轮廓——" + Loot.entry_kind_cn(items[bi] as Dictionary) + "（占 " + str(int((items[bi] as Dictionary).get("gap", 1))) + " 格）"
	elif kind == "many":
		# 透物灯：随机几件给完整轮廓（跳过已经全知的）
		var cands: Array = []
		for i in items.size():
			if str(seen.get(str(i), "")) != "full":
				cands.append(i)
		if cands.is_empty():
			return {"ok": false, "msg": "这一仓的东西你已经全认得了"}
		var k := mini(Appraise.lamp_count(), cands.size())
		var outs: Array = []
		for _j in k:
			var pick := int(cands[randi() % cands.size()])
			cands.erase(pick)
			seen[str(pick)] = "outline"
			outs.append(_appraise_outline_text(items[pick] as Dictionary))
			if cands.is_empty():
				break
		msg = "「" + Appraise.tool_name(tid) + "」照出 " + str(outs.size()) + " 件的轮廓：" + "、".join(PackedStringArray(outs))
	elif kind == "slots":
		# v50：数格尺——量出这只仓一共几格（店里不写格数，这是"要不要下手"的第一道信息）
		o["cells_known"] = true
		msg = "「" + Appraise.tool_name(tid) + "」量过了——这只仓一共 " + str(int(o.get("cells", 0))) + " 格"
	elif kind == "tier":
		# v50：按成色筛——把该档的货**全部**标成轮廓（绿/紫/金/红各一把筛子）
		var want := clampi(int(d.get("tier", 0)), 1, 4)
		var got: Array = []
		for i3 in items.size():
			var e3: Dictionary = items[i3]
			if Loot.tier_of(e3) != want:
				continue
			if str(seen.get(str(i3), "")) == "full":
				continue          # 已经全知的不用再标
			seen[str(i3)] = "outline"
			got.append(_appraise_outline_text(e3))
		if got.is_empty():
			return {"ok": false, "msg": "这一仓里没有" + str(d.get("name", "")) + "管的那种成色——道具没动（下次换个仓再试）"}
		msg = "「" + Appraise.tool_name(tid) + "」筛出 " + str(got.size()) + " 件：" + "、".join(PackedStringArray(got))
	else:
		# 识宝鉴：认下**一件**的完整信息——挑"还没认过里**最值钱**的那一件"
		#   （第一版挑的是"第一件没认过的"，于是可能花 320 两照出一味 1 两的药材——
		#     玩家要的是"这一仓里哪件最值"，所以这里按估价挑）
		var target := -1
		var best_v := -1
		for i2 in items.size():
			if str(seen.get(str(i2), "")) == "full":
				continue
			var v2 := Loot.entry_value(items[i2] as Dictionary)
			if v2 > best_v:
				best_v = v2
				target = i2
		if target < 0:
			return {"ok": false, "msg": "这一仓的东西你已经全认得了"}
		seen[str(target)] = "full"
		msg = "「" + Appraise.tool_name(tid) + "」认下一件：" + _appraise_full_text(items[target] as Dictionary)
	o["seen"] = seen
	appraise_tool_add(tid, -1)
	return {"ok": true, "msg": msg}

static func _appraise_best_idx(items: Array) -> int:
	var bi := 0
	var bv := -1
	for i in items.size():
		var v := Loot.entry_value(items[i] as Dictionary)
		if v > bv:
			bv = v
			bi = i
	return bi

# 轮廓那一行（知道"是什么类、几格、什么成色"，不知道名字）
static func _appraise_outline_text(e: Dictionary) -> String:
	var cn := Loot.entry_kind_cn(e)
	var gap := int(e.get("gap", 1))
	var tier := Loot.tier_of(e)
	var tier_cn := "暗"
	match tier:
		1:
			tier_cn = "寻常"
		2:
			tier_cn = "上等"
		3:
			tier_cn = "贵重"
		4:
			tier_cn = "极品"
	return cn + "（" + str(gap) + " 格 · " + tier_cn + "）"

# 全知那一行（名字 + 加成 + 估价）
static func _appraise_full_text(e: Dictionary) -> String:
	var sid := str(e.get("id", ""))
	var txt := str(e.get("name", "?"))
	if sid != "" and not Cards.by_id(sid).is_empty():
		txt += "（" + Cards.quality_of(sid) + "）"
	var extra := ""
	if sid != "":
		var pool := str(Cards.by_id(sid).get("pool", ""))
		if pool == "arts" or pool == "weapon" or pool == "armor" or pool == "helm" or pool == "cloak":
			extra = " 加成 " + Cards.bonus_text(Cards.item_stats(sid))
	return txt + extra + " · 估价约 " + str(Loot.entry_value(e)) + " 两"

# 买下一只货仓：扣银两 → 内容全亮 → **并进村账**（和搜刮带出村一个口径）
#   返回 {ok, msg, items:[…], value: 估价合计}
static func appraise_buy(uid: int) -> Dictionary:
	var o: Dictionary = appraise_offer(uid)
	if o.is_empty():
		return {"ok": false, "msg": "这只货仓不在店里了"}
	var hid := str(o.get("hid", ""))
	var free := bool(o.get("free", false))
	var price := 0 if free else Appraise.hold_price_now(hid)   # v39：按当下红池相位现算
	if coin("silver") < price:
		return {"ok": false, "msg": "银两不够：这只「" + Appraise.hold_name(hid) + "」要 " + str(price) + " 两（现有 " + str(coin("silver")) + "）"}
	var items: Array = o.get("items", [])
	if price > 0:
		add_coin("silver", -price)
	# 并账：与游历结算同一套桶（银两/材料/残卡/成品/碎片/丹/酒/血脉/元宝）
	var got: Array = []
	var total := 0
	for e_v in items:
		var e: Dictionary = e_v
		total += Loot.entry_value(e)
		got.append(str(e.get("name", "?")))
		_deposit_one(e)
	appraise_opened += 1
	appraise_best = maxi(appraise_best, _appraise_best_value(items))
	# 从报价单里拿走，再补一只新的
	var left: Array = []
	for o2_v in appraise_offers:
		var o2: Dictionary = o2_v
		if int(o2.get("uid", -1)) != uid:
			left.append(o2)
	appraise_offers = left
	appraise_ensure_offers()
	save_game()
	var head := "「" + Appraise.hold_name(hid) + "」" + ("（打捞上来的那只，不收钱）" if free else "（花 " + str(price) + " 两）")
	var msg := head + "开出 " + str(items.size()) + " 件："
	msg += "、".join(PackedStringArray(got)) if not got.is_empty() else "空空如也"
	msg += "｜估价合计约 " + str(total) + " 两" + ("（赚了 " + str(total - price) + "）" if price > 0 and total > price else ("（亏了 " + str(price - total) + "）" if price > 0 else ""))
	print("[账本] 鉴宝行：", msg)
	return {"ok": true, "msg": msg, "items": items, "value": total, "price": price}

static func _appraise_best_value(items: Array) -> int:
	var v := 0
	for e_v in items:
		v = maxi(v, Loot.entry_value(e_v as Dictionary))
	return v

# 一件货并进村账——**与游历结算 _loot_dict 同一套桶**，只是这里一件一件来。
#   ⚠ 想加新的货型，这里与 journey_settle 一起加，别只改一边。
static func _deposit_one(e: Dictionary) -> void:
	var k := str(e.get("kind", ""))
	var sid := str(e.get("id", ""))
	var amt := maxi(1, int(e.get("amount", 1)))
	match k:
		"silver":
			add_coin("silver", amt)
		"yuanbao":
			add_coin("yuanbao", amt)
		"junk":
			add_coin("silver", int(e.get("value", 1)) * amt)   # 杂物当场折银（与游历一个口径）
		"mat":
			add_material(sid, amt, int(e.get("q", 0)))
		"pill":
			pills[sid] = int(pills.get(sid, 0)) + amt
		"wine":
			var wd := wine_roll()
			add_wine(str(wd["name"]), wd["q"], int(wd["base"]), str(wd["hint"]))
		"blood":
			blood_add(sid, int(e.get("pur", 50)))
		"fragment":
			add_fragment(sid, amt)
		"card":
			vault_deposit({sid: {int(e.get("part", 0)): 1}})
		"item":
			vault_add_item(sid, amt)


# ============================================================
# ㉞ 出村爬塔：整块搬去 shared/tower.gd（500 关 + 公式成长）
# 这里只留转发口 —— 老调用点（battle_lite / out_panel / menu_sketch）
# 一个字都不用改，名字与语义照旧。
# 关卡/敌人/收益/离线估算的参数全在 tower.gd 顶部，调难度只开那一个文件。
# ============================================================
const Tower := preload("res://shared/tower.gd")
const Insight := preload("res://shared/data_insight.gd")   # v64b：阅历线表（唯一真源）

const STAGE_MAX := Tower.STAGE_MAX

static func is_boss(i: int) -> bool:
	return Tower.is_boss(i)

static func is_elite(i: int) -> bool:
	return Tower.is_elite(i)

static func chapter_of(i: int) -> String:
	return Tower.chapter_of(i)

# v128（用户："爬塔和游历整体难度提升15%"）：塔这边的 +15% 就压在这一口（塔的怪只有一个出口）
const TOWER_HARD_MUL := 1.15

static func enemy_at(i: int) -> Dictionary:
	# ㉞：主体在 tower.gd；词缀这层留在账本里，因为它要读难度池（DataAffixes）
	var out: Dictionary = Tower.enemy_at(i)
	# v125（用户："游历和爬塔的敌情要显示敌人的境界"）：塔里的怪按**关卡**给境界
	#   （每 350 关一境，与 18 境对齐），并同样按境界差折算血攻——两处一条尺。
	var fr := clampi(int(i) / 350, 0, Realm.MAX_LV)
	out["realm"] = fr
	var sup := Realm.suppress_mul(advance_lv, fr) * TOWER_HARD_MUL   # v128：再 ×1.15（整体难度 +15%）
	out["hp"] = maxi(1, int(round(float(out.get("hp", 1)) * sup)))
	out["atk"] = maxi(1, int(round(float(out.get("atk", 1)) * sup)))
	var n := int(out.get("affix_n", 0))
	if n > 0:
		# 池档＝章号收口到第 6 池——防词缀表档数不够时越界崩
		# v55：词缀从 14 条涨到 25 条、池子重排成四档（早/中/晚/硬），硬池从第 6 章起；
		#   收口从 5 放到 6，让 36 关往后的章也能吃到硬池（再多也没有更高档了）。
		var tier := Tower.chapter_idx(i)
		var affixes: Array = DataAffixes.roll_from(DataAffixes.pool_for(mini(tier, 6)), n)
		if not affixes.is_empty():
			out["affixes"] = affixes
	return out

# ============================================================
# v129 追剿（精英爬塔）—— 数据在 shared/data_chase.gd
#
# 用户 2026-10-08："增加精英爬塔【500关解锁】…剧情是公主的部分追杀队已经来到了这村落…
#   也是在点出村之后 那个关卡列表里显示 这个可手动【手牌模式】可自动 难度略高
#   按照五关一boss形成 boss需要富有特色 特性什么的 让玩家可以针对的进行战术【奖励暂时不给】"
# 用户 2026-10-09（本轮）："当前先做500关 每五关一个boss"
#
# 账本这一层只管三件：**进度**（chase_progress）、**存档**、以及"给怪补境界与压制"。
# 关卡表 / boss / 特性 / 杂兵名全在 data_chase.gd——调难度只开那一个文件。
# ⚠ 奖励**先留空**（用户："奖励暂时不给 做好再设置"）：chase_clear 只推关，不给银两/经验/箱子。
# ⚠ 追剿的自动连打是**独立的开关**（chase_auto）——不能蹭爬塔的 auto_climb，
#   那个开关同时还管着"挂机后台推塔"（_idle_climb），蹭上去两头都会乱。
# ============================================================
const Chase := preload("res://shared/data_chase.gd")

static var chase_progress := 0     # 追剿已清关数（0 ~ Chase.STAGE_MAX）
static var chase_auto := false     # 追剿的"自动连打"（与爬塔 auto_climb 分开）

static func chase_unlocked() -> bool:
	return stage_progress >= Chase.UNLOCK_STAGE

static func chase_gap() -> int:
	return maxi(0, Chase.UNLOCK_STAGE - stage_progress)

static func chase_enemy_at(i: int) -> Dictionary:
	# 与爬塔（enemy_at）同一把尺：
	#   ① 境界按关卡给——追剿第 i 关用的是"塔上等价关"（OFFSET+i）/ 350，与塔的 i/350 一条线；
	#   ② 再按境界差折算血攻（±10%/境、夹 ±80%），并同样吃 1.15 的整体难度；
	#   ③ 杂兵那一条随机词缀与塔同池同规矩（boss 的词缀是**写死的**——那是它的性格）。
	var ti := clampi(i, 0, Chase.STAGE_MAX - 1)
	var out: Dictionary = Chase.enemy_at(ti)
	var fr := clampi((Chase.OFFSET + ti) / Chase.REALM_DIV, 0, Realm.MAX_LV)
	out["realm"] = fr
	var sup := Realm.suppress_mul(advance_lv, fr) * TOWER_HARD_MUL
	out["hp"] = maxi(1, int(round(float(out.get("hp", 1)) * sup)))
	out["atk"] = maxi(1, int(round(float(out.get("atk", 1)) * sup)))
	var n := int(out.get("affix_n", 0))
	if n > 0:
		var tier := mini(1 + (Chase.round_of(ti) - 1) / 10, 6)
		var affixes: Array = DataAffixes.roll_from(DataAffixes.pool_for(tier), n)
		if not affixes.is_empty():
			out["affixes"] = affixes
	return out

# v136（用户："追剿给宝箱和大量银两【也不要太多】和大量经验【也不要太多】
#   boss关给一本完整功法或者武器装备 每80关提升一个档次 最高极品"）：
#   清一关＝**银两 ＋ 经验 ＋ 一个宝箱**；boss 关（每 5 关）再加**一件完整的东西**。
#   档位与数量都在 data_chase 那六个常数里（每 80 关升一档、封顶极品）。
static var last_chase_line := ""     # 最近一次清关的收益播报（战斗结算/面板读它）

static func chase_clear(i: int, save_now := true) -> bool:
	if i != chase_progress:
		return false
	if i >= Chase.STAGE_MAX:
		return false
	chase_last_gift = ""
	var silver := Chase.reward_silver(i)
	var exp := Chase.reward_exp(i)
	var chests: Array = Chase.reward_chests(i)      # v139：每关 2 个（boss 关＝升一档＋同档）
	var item := Chase.reward_item(i)
	chase_progress += 1
	add_coin("silver", silver)
	exp_pool += exp
	# 追剿＝食物储存主路：清一关给粮
	var chase_food := 3 + Chase.reward_q(i)
	action_add(chase_food)
	for c_v in chests:
		chest_add(str(c_v))
	# 开箱的赏格按"最后清掉的那一关"算（与爬塔同一条口径）
	chest_set_stage_hint(i)
	var got: Array = []
	got.append("银两 +" + str(silver))
	got.append("经验 +" + str(exp))
	got.append("食物 +" + str(chase_food))
	got.append(Chase.chest_summary(chests))
	if item != "":
		var pi := randi() % maxi(1, Cards.part_count(item))
		var bucket: Dictionary = vault_cards.get(item, {})
		bucket[pi] = int(bucket.get(pi, 0)) + 1
		vault_cards[item] = bucket
		chase_last_gift = item          # v143：后台推进的汇总要数它（别再掷第二次）
		got.append("功法残页「" + Cards.card_name(item, pi) + "」（" + Cards.quality_of(item) + "）")
	last_chase_line = "、".join(PackedStringArray(got))
	# v143：后台批量推进时由调用方统一落盘一次（save_now=false），别一关一次
	if save_now:
		save_game()
	print("[账本] 追剿清关：第 ", i + 1, " 关（", Chase.enemy_name(i), "）——", last_chase_line, "｜进度 ", chase_progress, "/", Chase.STAGE_MAX)
	return true

# ---- 品酒坊 ----
const TASTERS := [
	{"key": "color", "name": "柳先生", "low": "「色浑发浊——可惜。」", "mid": "「色正，过得去。」", "high": "「好色！亮得像新漆的梁。」"},
	{"key": "aroma", "name": "闻婆", "low": "「寡淡，香灰都比它冲。」", "mid": "「香沉得住。」", "high": "「这一鼻——三天忘不掉。」"},
	{"key": "taste", "name": "陈九爷", "low": "「入口像漱口水。」", "mid": "「顺口，醇。」", "high": "「含在舌上，化开了。」"},
	{"key": "after", "name": "哑婆", "low": "「白水一碗，没回味。」", "mid": "「有余味，不长。」", "high": "「一盏下肚，半刻说不出话——这才叫韵。」"},
	{"key": "body", "name": "铁头", "low": "「没劲，跟露水似的。」", "mid": "「劲儿稳，暖。」", "high": "「一道火线落喉——够劲！」"},
]
const AXIS_CN := {"color": "色", "aroma": "香", "taste": "味", "after": "韵", "body": "劲"}
const STAR_STEP := 0.2
const BREW_COST := 60
const WINE_NAMES := ["新酿米酒", "山果烧", "浊酒", "村酿", "竹叶酒"]

# ============================================================
# v35（用户报的③）：品酒坊的**无限刷银两**堵口。
#
# 病根（两条，叠在一起才是"印钞机"）：
#   ① 没品过的酒也按 base 全价卖——而 base 恒 ≥ 50 > 酿价 40。
#      于是"酿一坛 → 立刻卖掉"两次点击必然赚 10~40 两，**跟品酒毫无关系**。
#   ② 就算按规矩品完再卖，一趟也只是 5 次白点的点击，期望价 ≈ 69 两 > 40 两。
#      收益是正的、动作可无限重复——那就是"无限刷"。（挂机才 1 两/分。）
#
# 两条口子各堵一刀（都是本文件里的常数，想改手感只动这两行）：
#   · WINE_RAW_MUL：**没品过的酒＝生酒**，只按 base 的四成半贱卖（50~80 → 22~36 两，
#     低于酿价 40）——"酿了立刻卖"变成亏本，FOOT 上那句"五家品定再卖最划算"
#     从此是字面意思，而不是一句空话。
#   · WINE_BREW_LIMIT：**每日限酿** N 坛（真实日期，跨天自动重来；账存 wine.cfg，
#     与货栈每日限购同一套路子）——这是真正把"无限"变成"有限"的那一刀：
#     品酒坊从"印钞机"变回"每天一小笔进项 + 一个讲究运气的小玩法"。
#     想让品酒坊彻底不限量（回到旧手感）：把它改成 -1 即可。
#   ⚠ 限的是**酿**（银两→酒）那一头，不是卖：路上捡回来的酒酿（搜刮/结算入村）
#     照样能品、能卖——那是玩一趟换来的，不是点两下刷出来的。
# ============================================================
const WINE_CFG := "user://wine.cfg"
const WINE_RAW_MUL := 0.45     # 生酒（一口没品过）折价
const WINE_BREW_LIMIT := 5     # 每日限酿坛数；-1 = 不限

static var wines: Array = []
static var wine_day := ""      # 今日（真实日期；跨天自动重置）
static var wine_used := 0      # 今日已酿坛数

static func stars_of(v: int) -> int:
	if v >= 85:
		return 5
	if v >= 68:
		return 4
	if v >= 50:
		return 3
	if v >= 30:
		return 2
	return 1

static func wine_price(w: Dictionary) -> int:
	var base := int(w.get("base", 60))
	var rated: Dictionary = w.get("rated", {})
	if rated.is_empty():
		# v35：一口没品过＝生酒——只值四成半（低于酿价，堵掉"酿→卖"白赚）
		return maxi(5, int(round(float(base) * WINE_RAW_MUL)))
	var k := 1.0
	for key in rated.keys():
		k += (float(int(rated[key])) - 3.0) * STAR_STEP
	k = clampf(k, 0.4, 3.0)
	return maxi(5, int(round(float(base) * k)))

# ============================================================
# v39：**每日刷新时刻 ＝ 凌晨 4:00**（用户定）。
#
#   原来两处（货栈限购 `_shop_sync_day`、品酒坊限酿 `_wine_sync_day`）都按**日历日 0:00**
#   翻页，于是有两个说不清的地方：
#     ① 玩家熬夜到 0~4 点：他心里的"今天"还没过完，限购却已经翻页/还没翻页，看着像没刷新；
#     ② 面板**开着不动**时不会重画——真跨过那一刻，界面上还是旧字（用户报的"血脉今天没刷新"）。
#   现在统一走这两口：
#     · `day_key()`   —— "按 4 点换日"的日期串（存进 cfg，人能看懂；凌晨 0~4 点算前一天）
#     · `day_tick()`  —— 面板轮询用：它自己记住上次的 key，变了就重画（返回 true ＝ 刚换日）
#   ⚠ 以后再加"每日限X"，一律用这两口，别再直接调 Time.get_date_string_from_system()。
# ============================================================
const DAY_RESET_HOUR := 4

# 本地时间往前挪 DAY_RESET_HOUR 小时再取日期——于是"凌晨 4 点"才是换日点
static func day_key() -> String:
	var tz := Time.get_time_zone_from_system()
	var t := Time.get_unix_time_from_system() + float(tz.get("bias", 0)) * 60.0
	return Time.get_date_string_from_unix_time(int(t - float(DAY_RESET_HOUR) * 3600.0))

# 面板用：把上次看到的 key 传进来，返回 (换日了吗, 新的 key)。
#   面板在 _process 里每半秒问一次即可（跨过 4:00 那一刻，界面自己就刷新了）。
static func day_tick(last_key: String) -> Array:
	var k := day_key()
	return [k != last_key, k]

# ---- v35：每日限酿（照货栈"每日限购"那一套：真实日期 + 单独一份 cfg + 买一次就落盘）----

static func _wine_sync_day() -> void:
	var d := day_key()
	if wine_day == d:
		return
	wine_day = d
	wine_used = 0
	var cf := ConfigFile.new()
	if cf.load(WINE_CFG) == OK and str(cf.get_value("wine", "day", "")) == d:
		wine_used = maxi(0, int(cf.get_value("wine", "used", 0)))
	_wine_save()

static func _wine_save() -> void:
	var cf := ConfigFile.new()
	cf.load(WINE_CFG)
	cf.set_value("wine", "day", wine_day)
	cf.set_value("wine", "used", wine_used)
	cf.save(WINE_CFG)

# 今日还能酿几坛（-1 = 不限）
static func wine_left_today() -> int:
	if WINE_BREW_LIMIT < 0:
		return -1
	_wine_sync_day()
	return maxi(0, WINE_BREW_LIMIT - wine_used)

static func wine_limit_text() -> String:
	var left := wine_left_today()
	if left < 0:
		return "不限量"
	return "今日还能酿 " + str(left) + "/" + str(WINE_BREW_LIMIT) + " 坛"

static func add_wine(nm: String, q: Dictionary, base: int, hint: String) -> void:
	wines.append({"name": nm, "q": q, "base": base, "hint": hint, "rated": {}})

static func wine_give_chenniang() -> void:
	add_wine("陈酿", {"color": 30, "aroma": 82, "taste": 74, "after": 90, "body": 58}, 80, "泥封一开，满村飘香；只是倒出来色重发浊。")

static func wine_roll(hard := false) -> Dictionary:
	var keys: Array = []
	for t in TASTERS:
		keys.append(str(t["key"]))
	keys.shuffle()
	var hi := str(keys[0])
	var lo := str(keys[1])
	# v63（用户："品级酒好酒几率也 -50% 品酒坊自酿也改为 -50% 都一视同仁"）：
	#   hard 阈值 0.30 → **0.50**——自酿与品级酒的好酒概率都砍一半（赌徒心理：更稀有）。
	if hard and randf() < 0.50:
		hi = ""
	var q := {}
	for t2 in TASTERS:
		var key := str(t2["key"])
		var v := randi_range(45, 75)
		if key == hi:
			v = randi_range(78, 95)
		elif key == lo:
			v = randi_range(22, 45)
		q[key] = v
	var nm := str(WINE_NAMES[randi() % WINE_NAMES.size()])
	var hint := "这坛平平，没什么可点的。" if hi == "" else "开坛先「" + str(AXIS_CN[hi]) + "」；「" + str(AXIS_CN[lo]) + "」上差口气。"
	return {"name": nm, "q": q, "base": 50 + randi_range(0, 30), "hint": hint}

# v62（用户："酒分品级 加入搜刮和货仓 最低紫 最高红 3格"）：
#   从游历带回来的酒**按品级**兑成那一坛——紫＝村酿 · 金＝竹叶酒 · 红＝陈酿。
#   口味（五项评分）仍然现摇（品酒坊那一套不能变成"看品级就知道分"），
#   但高品级会把两头抬起来：金 +8、绝 +16（封顶 100）——好酒平均就是更好喝。
# v63（用户："品级酒好酒几率也 -50%…两种的价格增幅拉高一点，吊起欲望"）：
#   · 基础价与掉落表同数（90/180/360 → **270/540/1080**，即上浮 100% 后再 +50%）
#   · 品级酒的**口味评分**也吃 -50%（wine_roll(hard)）——与自酿一视同仁。
const WINE_GRADE_INFO := {
	2: {"name": "村酿", "base": 270, "lift": 0},
	3: {"name": "竹叶酒", "base": 540, "lift": 8},
	4: {"name": "陈酿", "base": 1080, "lift": 16},
}

static func add_wine_of_grade(grade: int) -> String:
	var g := clampi(grade, 2, 4)
	var info: Dictionary = WINE_GRADE_INFO[g]
	var wd := wine_roll(true)   # v63：品级酒与自酿一视同仁——好酒几率 -50%
	var q: Dictionary = wd.get("q", {})
	var lift := int(info["lift"])
	if lift > 0:
		for k in q.keys():
			q[k] = clampi(int(q[k]) + lift, 0, 100)
	add_wine(str(info["name"]), q, int(info["base"]), str(wd.get("hint", "")))
	return str(info["name"])

static func wine_taste(wi: int, ti: int) -> Dictionary:
	if wi < 0 or wi >= wines.size() or ti < 0 or ti >= TASTERS.size():
		return {"ok": false, "stars": 0, "say": "……"}
	var w: Dictionary = wines[wi]
	var t: Dictionary = TASTERS[ti]
	var key := str(t["key"])
	var rated: Dictionary = w.get("rated", {})
	if rated.has(key):
		return {"ok": false, "stars": int(rated[key]), "say": "他已经品过了。"}
	var q: Dictionary = w.get("q", {})
	var st := stars_of(int(q.get(key, 50)))
	rated[key] = st
	w["rated"] = rated
	wines[wi] = w
	var say := str(t["mid"])
	if st >= 4:
		say = str(t["high"])
	elif st <= 2:
		say = str(t["low"])
	return {"ok": true, "stars": st, "say": say}

static func wine_sell(wi: int) -> Dictionary:
	if wi < 0 or wi >= wines.size():
		return {"ok": false, "price": 0, "name": ""}
	var w: Dictionary = wines[wi]
	var p := wine_price(w)
	add_coin("silver", p)
	wines.remove_at(wi)
	return {"ok": true, "price": p, "name": str(w.get("name", "酒"))}

static func wine_brew() -> Dictionary:
	# v35：先过"每日限酿"这道闸——这一步是"无限刷银两"真正的封口
	if WINE_BREW_LIMIT >= 0:
		var left := wine_left_today()
		if left <= 0:
			return {"ok": false, "msg": "今日的酒已经酿够了（每日 " + str(WINE_BREW_LIMIT) + " 坛，跨天重来）——先把窖里的品一品、卖掉"}
	if coin("silver") < BREW_COST:
		return {"ok": false, "msg": "银两不够：酿一坛要 " + str(BREW_COST) + "（现有 " + str(coin("silver")) + "）"}
	add_coin("silver", -BREW_COST)
	var d := wine_roll(true)   # v63：品酒坊自酿——好酒几率 -30%
	add_wine(str(d["name"]), d["q"], int(d["base"]), str(d["hint"]))
	if WINE_BREW_LIMIT >= 0:
		wine_used += 1
		_wine_save()   # 立刻落盘——退出重进不该把今天这一坛"洗掉"（否则限酿等于没有）
	return {"ok": true, "msg": "酿出一坛「" + str(d["name"]) + "」——" + str(d["hint"]) + "（" + wine_limit_text() + "）"}

# ---- 宠物（v20：名册——可养多只，随行只带一只） ----

# 名录（名字/阶名/fx 五键）都在 shared/data_pets.gd；这里留转发，老的引用照样能用。
# 若这行报错（个别版本不吃"跨文件常量"），把 PETS 原样抄回本文件即可。
const PETS := DataPets.PETS

# v32：五阶（幼→成长→成熟→通灵→化形）；阶名在 data_pets，每宠一套
const PET_STAGE_NAMES := ["幼年期", "成长期", "成熟期", "通灵期", "化形期"]   # ㊿z9：通用阶名（真源在 DataPets.STAGE_CN，这里留一份兼容旧读法）
const PET_STAGE_MAX := 4        # 0..4 共五段（旧第 6 档并入化形）
const PET_XP_PER_STAGE := 30
const PET_PILL_XP := 30
# ㊿z9：入册赠送的资质改成 **30~60 随机**（原来是 40~90）。
#   配上新丹药「洗灵丹」才有成长空间——资质是血脉效果的直接乘数，见 DataPets.blood_value。
const PET_APT_MIN := 30
const PET_APT_MAX := 60
const PET_APT_PILL_ADD := 2     # 洗灵丹：资质 +2
const PET_APT_PER_STAGE := 1    # 每阶最多吃几颗（跟洗髓丹的"每境 1 颗"一个口径）
# ㊿z9：宠物升星——照功法升星那一套（同名合星：每星 +20%，五星封顶）
const PET_STAR_MAX := 5
const PET_STAR_MUL_PER := 0.2
static var pet_stars := {}      # id -> 星数
static var pet_dups := {}       # id -> 同名份数（升星材料；来路待定，先只记账）

static var pet_roster := {}   # id -> 灵息（各宠自己攒）
static var pet_sel := ""      # 面板正看着的那只
static var pet_follow := ""   # 随行的那只（"" = 都不随行；"只带一只"就靠它）
static var pet_apt := {}      # id -> 资质（㊿z9：入册 30~60，洗灵丹 +2/颗，最多顶到 70）
static var pet_bl := {}       # id -> [{id, pur}]（按融合顺序，最多 5）
static var blood_inv: Array = []   # 血脉行囊：[{id, pur}]
# 旧符号（兼容老读法；别直接改，写名册的函数会同步它们）
static var pet_id := ""
static var pet_active := true
static var pet_xp := 0

static func _pet_sync() -> void:
	pet_id = pet_sel if pet_sel != "" else pet_follow
	pet_active = pet_follow != ""
	pet_xp = pet_xp_of(pet_cur())

# ---- 名册 ----

static func pet_owned() -> Array:
	return pet_roster.keys()

static func pet_has(pid: String) -> bool:
	return pet_roster.has(pid)

static func pet_cur() -> String:
	if pet_sel != "" and pet_roster.has(pet_sel):
		return pet_sel
	return pet_follow

static func pet_name_of(pid: String) -> String:
	return DataPets.name_of(pid)

static func pet_join(pid: String = "fox") -> void:
	if DataPets.of(pid).is_empty():
		return
	if not pet_roster.has(pid):
		pet_roster[pid] = 0
		pet_apt[pid] = randi_range(PET_APT_MIN, PET_APT_MAX)   # 资质：入册时定死
	pet_sel = pid
	if pet_follow == "":
		pet_follow = pid
	_pet_sync()

static func pet_select(pid: String) -> void:
	if not pet_roster.has(pid):
		return
	pet_sel = pid
	_pet_sync()

static func pet_xp_of(pid: String) -> int:
	return int(pet_roster.get(pid, 0))

static func pet_progress_of(pid: String) -> Dictionary:
	var s := 0
	var xp := pet_xp_of(pid)
	while s < PET_STAGE_MAX and xp >= PET_XP_PER_STAGE * (s + 1):
		xp -= PET_XP_PER_STAGE * (s + 1)
		s += 1
	return {"stage": s, "into": xp, "need": PET_XP_PER_STAGE * (s + 1)}

static func pet_stage_of(pid: String) -> int:
	return int(pet_progress_of(pid)["stage"])

static func pet_stage_name_of(pid: String, stage: int = -1) -> String:
	if stage < 0:
		stage = pet_stage_of(pid)
	return DataPets.stage_name_of(pid, stage)

# ---- v32：资质与血脉（每阶开 1 格；效果＝基础×资质×纯度×契合） ----

static func pet_apt_of(pid: String) -> int:
	if not pet_roster.has(pid):
		return 0
	if not pet_apt.has(pid):
		pet_apt[pid] = randi_range(PET_APT_MIN, PET_APT_MAX)   # 老档补抽一次
	return int(pet_apt[pid])

static func pet_apt_tier(apt: int) -> String:
	# ㊿z9：档位跟着新量程走（入册 30~60，洗灵丹每阶 +2，最多顶到 70）。
	#   旧档位是按 40~90 定的——照旧读法"绝佳"永远拿不到，等于白写一档。
	if apt >= 60:
		return "绝佳"
	if apt >= 50:
		return "上乘"
	if apt >= 40:
		return "中平"
	return "平平"

static func blood_add(bid: String, pur: int) -> void:
	blood_inv.append({"id": bid, "pur": clampi(pur, 30, 100)})

static func blood_inv_size() -> int:
	return blood_inv.size()

static func blood_get(i: int) -> Dictionary:
	if i < 0 or i >= blood_inv.size():
		return {}
	var e: Dictionary = blood_inv[i]
	return e

static func blood_name(bid: String) -> String:
	return DataPets.blood_name(bid)

static func pet_bl_list(pid: String) -> Array:
	return pet_bl.get(pid, [])

static func pet_bl_slots(pid: String) -> int:
	return pet_stage_of(pid) + 1   # 幼 1 格 → 化形 5 格

static func pet_bl_fx_of(pid: String) -> Dictionary:
	var out: Dictionary = {}
	if not pet_roster.has(pid):
		return out
	for e_v in pet_bl_list(pid):
		var e: Dictionary = e_v
		var bid := str(e.get("id", ""))
		var d: Dictionary = DataPets.blood_value(bid, int(e.get("pur", 50)), pet_apt_of(pid), DataPets.fit_of(pid, bid))
		for k in d.keys():
			out[k] = int(out.get(k, 0)) + int(d[k])
	return out

static func blood_preview_text(pid: String, inv_i: int) -> String:
	var e := blood_get(inv_i)
	if e.is_empty():
		return ""
	var bid := str(e.get("id", ""))
	var pur := int(e.get("pur", 50))
	var fit := DataPets.fit_of(pid, bid)
	var d: Dictionary = DataPets.blood_value(bid, pur, pet_apt_of(pid), fit)
	var t := DataPets.blood_fx_text(d)
	if t == "":
		t = "（无加成）"
	if fit:
		t += "　·　契合 ×1.5 已计"
	return t

static func pet_fuse_blood(pid: String, inv_i: int) -> Dictionary:
	if not pet_roster.has(pid):
		return {"ok": false, "msg": "先有宠物，再谈血脉"}
	if inv_i < 0 or inv_i >= blood_inv.size():
		return {"ok": false, "msg": "先在行囊里选中一枚血脉"}
	var fused: Array = pet_bl_list(pid).duplicate()
	var open_n := pet_bl_slots(pid)
	if fused.size() >= open_n:
		return {"ok": false, "msg": DataPets.name_of(pid) + "现在开 " + str(open_n) + " 格——再升一阶才多一格"}
	var e := blood_get(inv_i)
	var bid := str(e.get("id", ""))
	var pur := int(e.get("pur", 50))
	fused.append({"id": bid, "pur": pur})
	pet_bl[pid] = fused
	blood_inv.remove_at(inv_i)
	_pet_sync()
	save_game()
	var got: Dictionary = DataPets.blood_value(bid, pur, pet_apt_of(pid), DataPets.fit_of(pid, bid))
	return {"ok": true, "msg": DataPets.name_of(pid) + " 融入「" + DataPets.blood_name(bid) + "」（纯 " + str(pur) + "）：" + DataPets.blood_fx_text(got)}

static func pet_passive_pct_of(pid: String) -> int:
	if pid == "" or not pet_roster.has(pid):
		return 0
	# ㊿z9：护主＝宠物主加成（带阶数）＋血脉的 pct；再乘升星倍率
	var n := int(DataPets.stage_fx_of(pid, pet_stage_of(pid)).get("pct", 0))
	n += int(pet_bl_fx_of(pid).get("pct", 0))
	return int(round(float(n) * pet_star_mul(pid)))

static func pet_fx_of(pid: String) -> Dictionary:
	if pid == "" or not pet_roster.has(pid):
		return {}
	# ㊿z9：主加成（白狐＝护主 / 青隼＝速度）＋血脉；再乘**升星**倍率
	var out: Dictionary = DataPets.stage_fx_of(pid, pet_stage_of(pid))
	var bfx := pet_bl_fx_of(pid)
	for k in bfx.keys():
		out[k] = int(out.get(k, 0)) + int(bfx[k])
	var m := pet_star_mul(pid)
	if m != 1.0:
		for k2 in out.keys():
			out[k2] = int(round(float(out[k2]) * m))
	return out

# ---- ㊿z9：宠物升星（同名合星，照功法升星那一套）----

static func pet_star_of(pid: String) -> int:
	return int(pet_stars.get(pid, 0))

static func pet_dup_count(pid: String) -> int:
	return int(pet_dups.get(pid, 0))

# 同名份数记一笔（来路由设计定：后山再遇、密柜、货栈…都往这儿加就行）
static func pet_dup_add(pid: String, n := 1) -> int:
	if pid == "":
		return 0
	pet_dups[pid] = pet_dup_count(pid) + n
	return int(pet_dups[pid])

static func pet_star_mul(pid: String) -> float:
	return 1.0 + float(pet_star_of(pid)) * PET_STAR_MUL_PER

# 升一星要几只同名（与功法升星同一张表：1/2/4/8/16）
static func pet_star_cost_next(pid: String) -> int:
	var s := pet_star_of(pid)
	if s >= PET_STAR_MAX:
		return 0
	return int(STAR_COST[s + 1])

static func pet_star_can(pid: String) -> Dictionary:
	if pid == "" or not pet_roster.has(pid):
		return {"ok": false, "msg": "先有这只宠物"}
	var s := pet_star_of(pid)
	if s >= PET_STAR_MAX:
		return {"ok": false, "msg": DataPets.name_of(pid) + "已经是五星了"}
	var need := pet_star_cost_next(pid)
	var have := pet_dup_count(pid)
	if have < need:
		return {"ok": false, "msg": "同名份数不够：升 " + str(s + 1) + " 星要 " + str(need) + " 只（现有 " + str(have) + "）"}
	return {"ok": true, "msg": ""}

static func pet_star_up(pid: String) -> String:
	var chk := pet_star_can(pid)
	if not bool(chk.get("ok", false)):
		return str(chk.get("msg", "升不了"))
	var s := pet_star_of(pid)
	var need := pet_star_cost_next(pid)
	pet_dups[pid] = pet_dup_count(pid) - need
	pet_stars[pid] = s + 1
	var nm := DataPets.name_of(pid)
	# 升星会抬高主加成/血脉那一份——面板上的数下次刷新就变
	var msg := "「" + nm + "」升到 " + str(s + 1) + " 星（同名 -" + str(need) + "）——效果 ×" + str(snappedf(pet_star_mul(pid), 0.1))
	print("[账本] 宠物升星：", msg)
	return msg

# ---- ㊿z9：洗灵丹（宠物资质丹；红件搜刮才出，不可炼）----
static func pet_apt_allow(pid: String) -> int:
	return (pet_stage_of(pid) + 1) * PET_APT_PER_STAGE

static func pet_apt_used(pid: String) -> int:
	return int(pet_apt.get(str(pid) + "_used", 0))

static func pet_eat_apt() -> Dictionary:
	var pid := pet_cur()
	if pid == "":
		return {"ok": false, "msg": "还没有宠物"}
	if pill_count("xiling") <= 0:
		return {"ok": false, "msg": "包裹里没有「洗灵丹」——搜刮红件里偶尔能翻到，炼不出来"}
	var used := pet_apt_used(pid)
	var allow := pet_apt_allow(pid)
	if used >= allow:
		return {"ok": false, "msg": DataPets.name_of(pid) + "这一阶已服 " + str(used) + "/" + str(allow) + "——升一阶可再喂"}
	pills["xiling"] = pill_count("xiling") - 1
	pet_apt[pid] = pet_apt_of(pid) + PET_APT_PILL_ADD
	pet_apt[str(pid) + "_used"] = used + 1
	var msg := DataPets.name_of(pid) + "服下「洗灵丹」：资质 +" + str(PET_APT_PILL_ADD) + " → " + str(pet_apt_of(pid)) + "（" + pet_apt_tier(pet_apt_of(pid)) + "；本阶已服 " + str(used + 1) + "/" + str(allow) + "）"
	print("[账本] ", msg)
	return {"ok": true, "msg": msg}

# ---- 兼容旧名（无参 = 随行那只优先；没随行就看选中的） ----

static func pet_data(pid: String = "") -> Dictionary:
	var p: String = pid if pid != "" else (pet_follow if pet_follow != "" else pet_cur())
	return DataPets.of(p)

static func pet_follow_data() -> Dictionary:
	return DataPets.of(pet_follow)

static func pet_progress() -> Dictionary:
	return pet_progress_of(pet_follow if pet_follow != "" else pet_cur())

static func pet_stage() -> int:
	return pet_stage_of(pet_follow if pet_follow != "" else pet_cur())

static func pet_stage_name() -> String:
	var pid: String = pet_follow if pet_follow != "" else pet_cur()
	return pet_stage_name_of(pid, pet_stage_of(pid))

static func pet_follow_stage_name() -> String:
	return pet_stage_name_of(pet_follow, pet_stage_of(pet_follow))

static func pet_passive_pct() -> int:
	if pet_follow == "":
		return 0
	return pet_passive_pct_of(pet_follow)

static func pet_fx() -> Dictionary:
	return pet_fx_of(pet_follow)

# ---- 随行（同时只带一只）与喂养 ----

static func pet_toggle() -> String:
	var pid := pet_cur()
	if pid == "":
		return "还没有宠物——去后山看看"
	var nm := DataPets.name_of(pid)
	if pet_follow == pid:
		pet_follow = ""
		_pet_sync()
		return nm + " 留在村里歇着（被动暂时失效）"
	var old := pet_follow
	pet_follow = pid
	_pet_sync()
	if old != "" and old != pid:
		return nm + " 跟上来了（已换下" + DataPets.name_of(old) + "——同时只带一只）"
	return nm + " 跟上来了（随行中）"

# ㊿z9：**点名**那只随行/留守——整备面板按名字说话（"让白狐留在村里"），
#   而 pet_toggle() 动的是"当前选中"那只：两者不是一回事时按钮会做错事。
#   这里先把选中的换成点名的，再交给 pet_toggle()，于是字面与动作一定一致。
static func pet_follow_toggle(pid: String) -> String:
	if pid == "" or not pet_roster.has(pid):
		return pet_toggle()
	pet_sel = pid
	return pet_toggle()

static func pet_feed() -> Dictionary:
	var pid := pet_cur()
	if pid == "":
		return {"ok": false, "msg": "还没有宠物——去后山看看"}
	var nm := DataPets.name_of(pid)
	if pet_stage_of(pid) >= PET_STAGE_MAX:
		return {"ok": false, "msg": nm + "已至" + pet_stage_name_of(pid, pet_stage_of(pid)) + "——到顶了，丹药先留着"}
	if pill_count("yangling") <= 0:
		return {"ok": false, "msg": "包裹里没有「养灵丹」——炼丹阁能炼（兽骨碎×2·灵米×1）"}
	pills["yangling"] = pill_count("yangling") - 1
	var before := pet_stage_of(pid)
	pet_roster[pid] = pet_xp_of(pid) + PET_PILL_XP
	var after := pet_stage_of(pid)
	_pet_sync()
	if after > before:
		# ㊿z9：别写死"护主"——青隼的主加成是速度，写死就报错项了
		var fts := DataPets.fx_text(pet_fx_of(pid))
		return {"ok": true, "msg": nm + " 吃下养灵丹：灵息 +" + str(PET_PILL_XP) + "——进阶「" + pet_stage_name_of(pid, after) + "」！现在：" + fts}
	var pr := pet_progress_of(pid)
	return {"ok": true, "msg": nm + " 吃下养灵丹：灵息 +" + str(PET_PILL_XP) + "（" + pet_stage_name_of(pid, after) + " · 距下一阶还差 " + str(int(pr["need"]) - int(pr["into"])) + " 灵息）"}
	# ---- 天赋表（v18 起搬到 shared/data_talents.gd；这里转发，老的引用照样能用） ----
# 若这行报错（个别版本不吃"跨文件常量"），删掉它，并把 roll_talents 里的
# TALENTS 换成 DataTalents.LIST 即可——两处都行，效果一样。
const TALENTS := DataTalents.LIST

# ㉗：天赋一律存"纯名字"。以前存的是"名字（说明）"，而 talent_fx_sum() / fx_of()
#   是按名字查表的——名字里混着说明就查不到，加成会静默失效（正式趟的天赋以前
#   就是这么丢的）。说明改成现查：显示的地方调 talent_desc()。
static func _talent_line(t: Dictionary) -> String:
	return str(t["name"])

# 按名字取说明（给显示用；查不到返回空串，显示方自己兜底）
static func talent_desc(t: String) -> String:
	return DataTalents.desc_of(str(t).split("（")[0].strip_edges())

# ㉗：某一角色的天赋 fx 合计（村内用；游历趟内那份在 run_state.talent_fx_sum）。
# 键口径见 data_talents 顶部。查不到的天赋（旧档存着"名字（说明）"）按名字硬查一次，再查不到就当没有。
static func talent_fx_of(role_id: String) -> Dictionary:
	var role := _role_mut(role_id)
	var out := {}
	if role.is_empty():
		return out
	for t_v in role.get("talents", []):
		var fx: Dictionary = DataTalents.fx_of(str(t_v))
		if fx.is_empty():
			fx = DataTalents.fx_of(str(t_v).split("（")[0].strip_edges())
		for k in fx.keys():
			out[k] = float(out.get(k, 0.0)) + float(fx[k])
	return out

# ============================================================
# v48：**战斗 / 面板 / 离线估算读同一份 tfx**（天赋 ＋ 角色星 stat ＋ 专武常驻 fx）
#   用户："增幅都是线性叠加的吧…看看计算方式" —— 一查发现这三处**各拼各的**：
#     · battle_lite 手工并"天赋＋星＋专武"     ✔ 齐
#     · 弟子面板   一个都不并                   ✘ 于是"面板写 18%、战斗按 26% 打"
#     · 离线估算   只并"天赋＋星"，**漏专武**   ✘ 于是"装了专武手动打得过、挂机不敢推"
#   现在只留这一口：要这几个数就来这里拿（_merge_num 是"同键相加"，
#   与 tfx 一贯的口径一致——百分点就是加点，比例键就是加比例）。
# ============================================================
static func _merge_num(out: Dictionary, add: Dictionary) -> void:
	for k in add.keys():
		out[k] = float(out.get(k, 0.0)) + float(add[k])

# 常驻数值那一份（dmg / hp_pct / crit / crit_dmg / def / dodge / spd / art_dmg …）
static func combat_tfx(role_id: String) -> Dictionary:
	var out: Dictionary = talent_fx_of(role_id)
	_merge_num(out, role_star_stat_fx(role_id))
	var role := _role_mut(role_id)
	for s_v in (role.get("skills", []) as Array):
		var sid := str(s_v)
		if sid == "" or not Cards.art_is_passive(sid):
			continue
		_merge_num(out, Cards.art_passive_fx_scaled(sid, role_star_of(role_id)))
	return out

# 机制那一份（大招增伤 / 追击段数 / 被动强化 / 反刺…）——星 mech ＋ 专武 mech 都并
#   ⚠ 顺序要紧：**专武 mech 必须先并进来**再用 passive_up（陈石「守拙」那种
#     "被动效果 +50%" 要是专武也带，就得连专武那份一起放大，见 duel_battle 的同款口径）。
static func combat_mech(role_id: String) -> Dictionary:
	var out: Dictionary = role_star_mech_fx(role_id).duplicate()
	var role := _role_mut(role_id)
	for s_v in (role.get("skills", []) as Array):
		var sid := str(s_v)
		if sid == "" or not Cards.art_is_passive(sid):
			continue
		_merge_num(out, Cards.art_passive_mech_scaled(sid, role_star_of(role_id)))
	return out

# v48：**面板那一份"能打的样子"** ＝ squad_stats（个人＋羁绊）再把战斗那份 tfx 折进去。
#   折法与 battle_lite._build_party 逐条对齐（同样每样只折一次）：
#     气血 ×(1+hp_pct/100) · 暴击/暴伤/防/闪/速 **加点** · 伤害加成 **加点**
#   ⚠ **攻击那一行不折 dmg%**：面板的攻击是"基础＋额外"的拆账（atk_parts），
#     dmg% 在面板上是单独一行（伤害加成），战斗里才乘上去——
#     硬折进去会让"拆账加起来≠总数"，那正是这套面板最忌讳的账。
static func panel_stats(role_id: String) -> Dictionary:
	var out := squad_stats(role_id)
	var tfx: Dictionary = combat_tfx(role_id)
	if not tfx.is_empty():
		out["hp"] = int(round(float(out.get("hp", 0)) * (1.0 + float(tfx.get("hp_pct", 0)) / 100.0)))
		for k in ["crit", "crit_dmg", "dmg", "def", "dodge", "spd"]:
			out[k] = int(round(float(out.get(k, 0)) + float(tfx.get(k, 0))))
	# v48：**自带那两路也要折进来**——它们以前只在战斗里生效，面板上完全看不到：
	#   · 守拙（innate_hp_pct 20%）→ 气血 ×1.20（陈石实测：面板 164、战斗 197 就是这个差）
	#   · 剑走轻灵（glass_crit 的 hp_cut 15%）→ 气血 ×0.85
	#   折法与 battle_lite._build_party 逐条对齐（同样只折一次）。
	var inn: Dictionary = Roles.innate_of(role_id)
	if not inn.is_empty():
		var wpn := str(Cards.weapon_of(str(_role_mut(role_id).get("weapon", ""))))
		if Roles.innate_active(inn, wpn):
			var ik := str(inn.get("kind", ""))
			if ik == "innate_hp_pct":
				out["hp"] = int(round(float(out.get("hp", 0)) * (1.0 + float(inn.get("hp_pct", 0.0)))))
	var pas: Dictionary = _role_mut(role_id).get("passive", {})
	if str(pas.get("kind", "")) == "glass_crit":
		out["hp"] = maxi(1, int(round(float(out.get("hp", 0)) * (1.0 - float(pas.get("hp_cut", 0.0))))))
	return out

# ⚠ v65b（用户：「不需要抽天赋 就正常我定的那几个天赋 那些随机天赋我后面用」）：
#   **当前没有任何人调它**——人物一律用"定好的那几条"（苏青鸾＝QINGLUAN_TALENTS，
#   陈石/少侠＝不带）。这一口原样留着，等以后给弟子/新角色用。
static func roll_talents(good_n := 1, bad_n := 1) -> Array:
	var goods: Array = []
	var bads: Array = []
	for t in TALENTS:
		var kind := str(t["kind"])
		if kind == "good":
			goods.append(t)
		elif kind == "bad":
			bads.append(t)
	goods.shuffle()
	bads.shuffle()
	var out: Array = []
	for i in mini(good_n, goods.size()):
		out.append(_talent_line(goods[i]))
	for i2 in mini(bad_n, bads.size()):
		out.append(_talent_line(bads[i2]))
	return out

# ---- 角色档案 ----

const CHEN_SHI_DEFAULT := {
	"name": "陈石",
	"sub": "弟子 · 阿石",
	"lv": 1,
	"exp": 0,
	"gengu": 35,
	"realm": 0,
	"pills_used": 0,
	"gengu_used": 0,
	"stats": {"atk": 8, "hp": 90, "spd": 9, "crit": 8, "dmg": 0, "def": 6, "dodge": 6, "crit_dmg": 50},
	"weapon": "spear",
	"weapon_label": "断枪",
	"gear": {},
	"skills": [],
	"talents": [],
	"innate": "",
	"innate_desc": "",
		"ult": {"name": "回马断枪", "kind": "aura", "turns": 3, "regen_pct": 0.08, "thorn": 0.35, "desc": "怒气满时自动放出：枪势起——其后 3 手，每手回 8% 气血；期间挨打反刺（按气血上限的 8~12%）"},
	"tech": {"name": "扎马稳桩", "desc": "每 4 次行动：回复 15% 气血（暂定）"},
	# v65（用户：「陈石加强天赋减伤提升至10%」）：6% → **10%**。
	#   ⚠ 面板显示的就是这一行 desc——改数值必须两处一起改（与 data_talents 的「守拙」不是同一条：
	#     守拙是自带天赋·气血上限 +15%，这里是专属被动·受伤减免）。
	# v65e（用户：「陈石 专属被动 额外加一个气血成长+1【突破不加 就升级加】」）：
	#   hp_grow 这一格走的是**每级成长**那条管线（hp_grow_bonus → level_gain → 升级结算），
	#   与「突破」（break_gain，按根骨现算）**互不相干**——正是「只升级加、突破不加」。
	#   ⚠ 成长一变，已过的级数由 grow_sync 在读档时补回来（见那条注释）。
	"passive": {"kind": "taken_cut", "v": 0.10, "hp_grow": 1, "name": "扎马稳桩",
		"desc": "专属被动：受到的伤害 -10%（出村战斗与游历决斗都已接入）· 每级气血成长 +1"},
}

const PLAYER_DEFAULT := {
	"name": "少侠",
	"sub": "主角 · 江湖新客（测试档）",
	"lv": 1,
	"exp": 0,
	"gengu": 62,
	"realm": 0,
	"pills_used": 0,
	"gengu_used": 0,
	"stats": {"atk": 10, "hp": 100, "spd": 10, "crit": 10, "dmg": 0, "def": 5, "dodge": 5, "crit_dmg": 50},
	"weapon": "sword",
	"weapon_label": "",
	"gear": {},
	"skills": ["art_wind"],
	"talents": [],
	"innate": "",
	"innate_desc": "",
	# ㊹：主角大招改群攻——倍率从 ×2.8 降到 ×1.7。
	#   原来 ×2.8 是"单体全力"的定价；改成打全部之后，再留 2.8 就成了
	#   既能扫场又比谁都重，等于白拿。1.7 ≈ 2.8 ÷ 1.65，跟其它群伤招式同一档。
	# ㊺：再改一层——横扫只在"对手不止一个"时发生。
	#   只剩一个敌人时它转回单体重击，倍率用 mult_single（＝原来那个 2.8），
	#   不然对着一个杂兵放横扫，等于自己把大招打了个六折。
	"ult": {"name": "长风破浪", "target": "sweep", "kind": "hit", "mult": 1.7, "mult_single": 2.8, "desc": "怒气满时自动放出：对手不止一人时横扫全场（各 ×1.7）；只剩一人时转为单体重击（×2.8）"},
	"tech": {"name": "调息归元", "desc": "每 4 次行动：回复 15% 气血（暂定）"},
	"passive": {"kind": "rage_up", "v": 0.3, "name": "引气归元", "desc": "专属被动：怒气获取 +30%——大招来得更快（出村战斗与游历决斗都已接入）"},
}

const QINGLUAN_DEFAULT := {
	"name": "苏青鸾",
	"sub": "弟子 · 游侠女",
	"lv": 1,
	"exp": 0,
	"gengu": 48,
	"realm": 0,
	"pills_used": 0,
	"gengu_used": 0,
	"stats": {"atk": 9, "hp": 95, "spd": 12, "crit": 12, "dmg": 0, "def": 5, "dodge": 8, "crit_dmg": 50},
	# ㊿z5：苏青鸾改用**匕首**——她的自带「洞察」本来就写着 weapon_gate "dagger"
	#   （持匕首时残敌增伤 +25%、普攻绕前排直取后排），拿剑等于这条自带一直睡着。
	#   起手功法也跟着换：原来那门「疾风剑法」是剑法，拿匕首会吃 off_mult 惩罚，
	#   换成通用的「影步」（any）——她自己不该先吃自己一刀。
	"weapon": "dagger",
	"weapon_label": "",
	"gear": {},
	"skills": ["art_iron", "art_shadow"],
	"talents": [],
	"innate": "",
	"innate_desc": "",
	# v65（用户："苏的大招看一下"）：**原来那支偏弱**——
	#   剑歌 3 手 · 追击六成力 · 触发条件是"这一手暴击"。她暴击 27%（12 底子 ＋ 被动 15），
	#   期望追击 ＝ p+p²+p³ ≈ 0.36 次/触发 → 0.36×0.6 ＝ **0.22 手/次**，
	#   3 手合计只有 **0.65 手**的额外伤害（主角大招 ×1.7 群攻、陈石大招 3 手回气＋反刺，
	#   都比它实在得多）。
	#   v65b/c（用户：「还是六成力 她的大招不是还有个多段伤害吗」）：
	#   **追击六成力（不动）· 窗口 3 手 · 窗口内暴击 +15 个百分点**（27% → 42%）。
	#   ⚠ **算这支大招必须把「段数」算进去**——一次追击不是一剑，是 **N 段**：
	#     角色星「出岫」（ult_dur+1 · follow_hits+1）· 引吭卡（follow_hits+1）· 专武「短歌行」再抬追击伤害。
	#   每一段各自掷暴击，暴击了再往下追一层（上限 SONG_CHAIN_MAX=3 层）。
	#   期望 = p × [N + N²p + N³p²] 段，每段 ×0.6：
	#     N=1（白板）   ≈ 0.67 段/手 → 3 手 ≈ **1.2 手**
	#     N=2（带星）   ≈ 2.14 段/手 → 4 手（星还 +1 手）≈ **5.1 手**
	#     N=3（星＋引吭）≈ 4.85 段/手 → 4 手 ≈ **11.6 手**
	#   所以力度**不能给八成**（那样 N=3 会爆），六成是对的。
	#   ⚠ 窗口里那 +15 的落点在两个战斗引擎各一处：duel_battle._roll_p_damage /
	#     battle_lite._crit_chance（都叫 SONG_CRIT_UP，改一处必须改两处）。
	# v65d（用户："她的大招 出手有一个大招伤害 2-3段 打完之后 附加一个追击状态
	#   接下来三回合 暴击额外追击0.6 优先攻击后排【追击可暴击 但是不会继续追击】"）：
	#   ① 出手：**3 段**（每段 ×0.8，取后排）；② 打完挂**追击状态 3 手**：
	#      期间每次暴击额外追一剑 ×0.6，优先后排，**可暴击但不连锁**（SONG_CHAIN_MAX = 1）。
	#   账：出手 3×0.8 = **2.4 手**（与主角大招 ×1.7 群攻 / ×2.8 单体同档）；
	#   追击部分每手期望 = p×N×0.6（不连锁了）：N=1 时 0.25 手/手 → 3 手 ≈ 0.76 手，
	#   带星「出岫」（+1 段 +1 手）→ 0.5 手/手 × 4 手 ≈ 2.0 手。
	"ult": {"name": "青鸾出岫", "target": "mid", "kind": "song", "hits": 3, "mult": 0.8,
		"turns": 3, "follow": 0.6,
		"desc": "怒气满时自动放出：先取后排连击 3 段（各 ×0.8）；此后 3 手，每次暴击额外追一剑（六成力 · 取后排 · 可暴击但不连锁）"},
	"tech": {"name": "剑心如镜", "desc": "每 4 次行动：回复 15% 气血（暂定）"},
	"passive": {"kind": "glass_crit", "v": 15, "hp_cut": 0.15, "name": "剑走轻灵", "desc": "专属被动：暴击 +15%，气血上限 -15%（出村战斗与游历决斗都已接入）"},
}

static var chen_shi := {}
static var player_role := {}
static var qingluan := {}

# ㉖：自带的"唯一真源"是 journey/data_roles.gd（按角色 id 查）。
# 账本三个模板里的 innate / innate_desc 是给人看的副本——这里统一刷一遍，
# 新档、旧档（存着空字符串）、以后改表，走这一条路就都能对上。
# ============================================================
# v65i（用户：「少侠的速度是不是太高了」）：**是**——而且后果比「抢出手位」重得多。
#
#   设计量级是「**10 ＝ 常人**」：村里三人底子 9/10/12 · 塔战的怪 9~28 ·
#   游历敌人表里写的是 88~110，但 duel_battle._foe_spd() **已经 ÷10 折过**
#   （→ 8.8~11）——三边本来就该在同一档。
#
#   而少侠存档里的 stats.spd 是 **104**（旧档遗留；现在的代码里**没有任何一条**
#   会把速度加进 stats：升级只涨气血、突破涨攻/血/防、属性丹只有强身(气血)/淬体(攻击)、
#   星/装备/天赋/宠物都走另外的层）。104 ÷ 9.5 ≈ **11 倍** →
#   GameData.extra_attacks() 是**倍率**规矩（≥2 倍 → 多打 floor(比)−1 下，封顶 2）→
#   **他的每一次普攻都自动多打 2 下**（战报上就是连着三条「少侠 普攻」）。
#
#   只校正一次（spd_fixed 标记）。想让谁真的「身法快」，要走正规来源：
#   装备（披风）· 天赋（料敌先机 +4）· 宠物青隼（速度%）——别留旧档的野数。
# ============================================================
static func role_spd_base(id: String) -> int:
	if id == "chen_shi":
		return int((CHEN_SHI_DEFAULT.get("stats", {}) as Dictionary).get("spd", 9))
	if id == "qingluan":
		return int((QINGLUAN_DEFAULT.get("stats", {}) as Dictionary).get("spd", 12))
	return int((PLAYER_DEFAULT.get("stats", {}) as Dictionary).get("spd", 10))

static func _fix_legacy_spd(role: Dictionary, id: String) -> void:
	if role.is_empty() or bool(role.get("spd_fixed", false)):
		return
	var base := role_spd_base(id)
	var st: Dictionary = role.get("stats", {})
	var cur := int(st.get("spd", base))
	if cur != base:
		st["spd"] = base
		role["stats"] = st
		print("[账本] 速度校正：", str(role.get("name", id)), " ", cur, " → ", base,
			"（旧档遗留值；设计量级 10＝常人——不校正的话「快一倍多打一下」那条会把普攻翻三倍）")
	role["spd_fixed"] = true

static func _sync_role_innate(role: Dictionary, id: String) -> void:
	if role.is_empty():
		return
	var inn: Dictionary = Roles.innate_of(id)
	if inn.is_empty():
		return
	var iid := str(inn.get("id", ""))
	role["innate"] = Roles.innate_name(iid)
	role["innate_desc"] = Roles.innate_desc(iid)

# v47：**被动 / 大招 / 自带技也照这一套读档时刷正**——
#   这三块挂在 role 字典里、会随存档落盘，于是"改了表里的数，老档还是旧数"。
#   撞上的一次：减伤砍半时把陈石「扎马稳桩」从 12% 改成 6%，可老档存着 12%，
#   读档后战斗里仍旧吃 12%——表改了等于没改。
#   所以名字/说明/数值一律以三个模板（CHEN_SHI_DEFAULT / PLAYER_DEFAULT / QINGLUAN_DEFAULT）为准，
#   读档时整块换掉（与 _sync_role_innate 同一口径）。
#   ⚠ 以后若有"给某人换被动/换大招"的玩法，得改成"只刷模板里那几个字段"，别整块覆盖。
static func _sync_role_kit(role: Dictionary, id: String) -> void:
	if role.is_empty():
		return
	var tpl: Dictionary = PLAYER_DEFAULT
	if id == "chen_shi":
		tpl = CHEN_SHI_DEFAULT
	elif id == "qingluan":
		tpl = QINGLUAN_DEFAULT
	for k in ["passive", "ult", "tech"]:
		var blk: Dictionary = tpl.get(k, {})
		if not blk.is_empty():
			role[k] = blk.duplicate(true)

static func _role_mut(id: String) -> Dictionary:
	if id == "chen_shi":
		if chen_shi.is_empty():
			chen_shi = CHEN_SHI_DEFAULT.duplicate(true)
			_sync_role_innate(chen_shi, id)
		return chen_shi
	if id == "player":
		if player_role.is_empty():
			player_role = PLAYER_DEFAULT.duplicate(true)
			_sync_role_innate(player_role, id)
		return player_role
	if id == "qingluan":
		if qingluan.is_empty():
			qingluan = QINGLUAN_DEFAULT.duplicate(true)
			_sync_role_innate(qingluan, id)
		return qingluan
	return {}

static func role_data(id: String) -> Dictionary:
	var d := _role_mut(id)
	# v83：**名字只在这一处拦**——战斗、结算、角色面板、游历 HUD 全都读这一口，
	#   所以起名之后不用去十来个地方改文案。
	if id == "player" and player_name != "":
		d["name"] = player_name
	return d

# 起名（空串＝回到默认「少侠」）。落盘交给调用方或下次自动存。
static func set_player_name(n: String) -> void:
	var t := n.strip_edges()
	player_name = t if t != "" else ""

static func capture_player(d: Dictionary) -> void:
	var base: Dictionary = PLAYER_DEFAULT.duplicate(true)
	for k in d.keys():
		base[k] = d[k]
	if not player_role.is_empty():
		# ㊿y：role_stars 不在 role 字典里，是账本单独一份——这里不用搬；
		#   但**主角的星跟着 id 走**，不随快照被覆盖，所以白名单只管下面这几个字段。
		for k2 in ["lv", "gengu", "exp", "pills_used", "gengu_used", "realm", "grow_paid"]:   # v36 境界 · v44 成长账本
			if player_role.has(k2):
				base[k2] = player_role[k2]
	var sk: Array = base.get("skills", [])
	if sk.size() > FREE_SKILL_SLOTS:
		base["skills"] = sk.slice(0, FREE_SKILL_SLOTS)
		print("[账本] 主角快照武学超过 ", FREE_SKILL_SLOTS, " 门，只留前 ", FREE_SKILL_SLOTS, " 门：", base["skills"])
	if not base.has("gear"):
		base["gear"] = {}
	player_role = base

# ---- 等级 / 境界 / 评价 ----

# 境界名（下标即境界等级 0~39）。面板、出征屏那些"只有等级"的地方走 realm_of(lv)——
#   等级隐含的境界＝(lv-1)/25，与"上限＝25×(境界+1)"是同一条线，不会自相矛盾。
static func realm_name(idx: int) -> String:
	return str(REALMS[clampi(idx, 0, REALMS.size() - 1)])

static func realm_of(lv: int) -> String:
	return realm_name((maxi(lv, 1) - 1) / BREAK_STEP)

static func eval_of(gengu: int) -> String:
	for t in EVAL_TIERS:
		if gengu >= int(t["min"]):
			return str(t["cn"])
	return "丁等"

# ---- v36：突破（境界）----
# 境界＝已经突破过几次（存在 role["realm"]，跟人走，也跟存档走）。
static func role_realm(role_id: String) -> int:
	return clampi(int(_role_mut(role_id).get("realm", 0)), 0, BREAK_MAX)

static func realm_max() -> int:
	return BREAK_MAX

# 这个人现在能升到几级：境界 n → 上限 25×(n+1)（境界 39 → 1000）
static func level_cap(role_id: String) -> int:
	return mini(LEVEL_MAX, BREAK_STEP * (role_realm(role_id) + 1))

# 下一次突破要哪一品突破丹（丹 id / 中文品名）。已满境界返回空串。
#
# v62（用户："突破丹可以先凡 1/2/4/8…不要进第二轮 每档七次 1/2/4/8/16/32 最后绝品不够就变成8档"）：
#   规矩重排成 **档内递增** 那一套：
#     · **每档 8 次**（凡 1~8 · 良 9~16 · 上 17~24 · 极 25~32 · 绝 33~39）——
#       8×5 = 40 ≥ 39，所以**一轮走完就到 1000 级，不进第二轮**（最后一档只用到第 7 格）
#     · **档内消耗按 1/2/4/8/16/32 递增，第 7、8 次封顶在 32**（BREAK_PILL_SEQ 最后一个值）
#     · 于是 39 次共 **603 颗/人**（每档 127 颗，最后一档 95 颗）
#   嫌重/嫌轻只改两个数：BREAK_PILL_SLOTS（每档几次）与 BREAK_PILL_SEQ（档内序列）。
const BREAK_PILL_SLOTS := 8                          # 每档管几次突破
const BREAK_PILL_SEQ := [1, 2, 4, 8, 16, 32]         # 档内第 1~6 次的消耗；再多就取末值（封顶 32）

# 第 n 次突破（1 起）在第几档、档内第几格
static func break_tier_of(n: int) -> int:
	return clampi((maxi(1, n) - 1) / BREAK_PILL_SLOTS, 0, BREAK_PILLS.size() - 1)

static func break_slot_of(n: int) -> int:
	return (maxi(1, n) - 1) % BREAK_PILL_SLOTS

# 第 n 次突破要吃几颗（v62：不再是"一律 1 颗"）
static func break_need_of(n: int) -> int:
	if n < 1 or n > BREAK_MAX:
		return 0
	var slot := break_slot_of(n)
	return int(BREAK_PILL_SEQ[mini(slot, BREAK_PILL_SEQ.size() - 1)])

static func break_pill(role_id: String) -> String:
	var n := role_realm(role_id) + 1        # 第 n 次突破（1 起）
	if n > BREAK_MAX:
		return ""
	return str(BREAK_PILLS[break_tier_of(n)])

static func break_pill_cn(role_id: String) -> String:
	var n := role_realm(role_id) + 1
	if n > BREAK_MAX:
		return ""
	return str(BREAK_PILL_CN[break_tier_of(n)])

# 这一次要几颗丹（面板/提示/账本都读它）
static func break_pill_need(role_id: String) -> int:
	return break_need_of(role_realm(role_id) + 1)

# v36b：这一次突破要多少银两（吃妙手折扣）
# 第 n 次突破的银两**原价**（不含"妙手"折扣）——账本/探针/面板都读它
static func break_silver_of(n: int) -> int:
	if n < 1 or n > BREAK_MAX:
		return 0
	return int(BREAK_SILVER[clampi((n - 1) / BREAK_PER_TIER, 0, BREAK_SILVER.size() - 1)])

static func break_silver(role_id: String) -> int:
	var n := role_realm(role_id) + 1        # 第 n 次突破（1 起）
	if n > BREAK_MAX:
		return 0
	return int(round(float(break_silver_of(n)) * player_talent_cost_mul()))

# 到顶了没有（"该突破了"）——［升级］按不动就是因为它
static func need_break(role_id: String) -> bool:
	var role := _role_mut(role_id)
	if role.is_empty():
		return false
	return int(role.get("lv", 1)) >= level_cap(role_id) and role_realm(role_id) < BREAK_MAX

# 能不能突破（只算账，不动）
static func break_can(role_id: String) -> Dictionary:
	var role := _role_mut(role_id)
	if role.is_empty():
		return {"ok": false, "msg": "没有这个人"}
	var cur := role_realm(role_id)
	if cur >= BREAK_MAX:
		return {"ok": false, "msg": "已经是" + realm_name(BREAK_MAX) + "（境界满 " + str(BREAK_MAX) + "）"}
	var lv := int(role.get("lv", 1))
	if lv < level_cap(role_id):
		return {"ok": false, "msg": "还没到顶——先把等级练到 " + str(level_cap(role_id)) + " 级（现在 " + str(lv) + "）"}
	var pid := break_pill(role_id)
	if pid == "":
		return {"ok": false, "msg": "没有对应的突破丹"}
	# v62：不是一颗——这一次要 need 颗（档内 1/2/4/8/16/32 递增）
	var need := break_pill_need(role_id)
	if pill_count(pid) < need:
		return {"ok": false, "msg": "「突破丹（" + break_pill_cn(role_id) + "）」不够：这次要 " + str(need)
			+ " 颗（包裹里 " + str(pill_count(pid)) + " 颗）——去炼丹阁炼，或上货栈买（每日限购）"}
	# v36b：还要银两
	var sp := break_silver(role_id)
	if coin("silver") < sp:
		return {"ok": false, "msg": "银两不够：突破还要 " + str(sp) + " 两（现有 " + str(coin("silver")) + "）——清关/开宝箱攒一攒"}
	return {"ok": true, "msg": ""}

# 突破：吃丹 → 境界 +1（等级上限 +25）＋基础属性涨一截（BREAK_GAIN）
#   v62：一次要**几颗**（档内 1/2/4/8/16/32 递增，见 break_pill_need）
static func break_do(role_id: String) -> String:
	var chk := break_can(role_id)
	if not bool(chk.get("ok", false)):
		return str(chk.get("msg", "突破不了"))
	var role := _role_mut(role_id)
	var pid := break_pill(role_id)
	var cur := role_realm(role_id)
	var sp := break_silver(role_id)
	var need := break_pill_need(role_id)     # v62：这一次吃几颗（档内递增）
	pills[pid] = pill_count(pid) - need
	add_coin("silver", -sp)          # v36b：突破也吃银两
	role["realm"] = cur + 1
	var st: Dictionary = role.get("stats", {})
	var gained: Array = []
	# v62h：突破的增幅**按根骨**现算（见 break_gain）
	var bgain := break_gain(role_id)
	for k in bgain.keys():
		var kk := str(k)
		var v := int(bgain[k])
		st[kk] = int(st.get(kk, 0)) + v
		gained.append(str(Cards.STAT_CN.get(kk, kk)) + " +" + str(v))
	role["stats"] = st
	var nm := str(role.get("name", role_id))
	var msg := nm + " 突破成功：境界 " + str(cur) + " → " + str(cur + 1) + " 重「" + realm_name(cur + 1) + "」"
	msg += "（服下「突破丹（" + break_pill_cn(role_id) + "）」×" + str(need) + " · 银两 -" + str(sp) + " · 等级上限 " + str(level_cap(role_id)) + " 级）"
	msg += "｜基础属性：" + "、".join(PackedStringArray(gained))
	print("[账本] 突破：", msg)
	return msg

static func exp_need(lv: int) -> int:
	return EXP_BASE + (maxi(lv, 1) - 1) * EXP_STEP

# ============================================================
# v38：**气血成长**（每级多涨几点气血）——用户："陈石 守拙加强 气血成长+2；
#   升星里面被动也加一个气血成长。"
#
#   与"气血% (hp_pct)"是两件事，别混：
#     · hp_pct  → 当下这一口气涨两成（战斗/面板立刻算，见 battle_lite / run_state）
#     · hp_grow → **以后每一级都多涨几点**（只在升级时结算，落点在 level_gain）
#   来源三处（以后加第四条就在这里加一行）：
#     · 人物自带（Roles.innate_of 的 hp_grow）——v62x 起已清空（现为 0）
#     · 角色星（Stars.grow_fx 的 hp_grow）——同上，已清空
#     · **专属被动**（role.passive 的 hp_grow）——v65e 新开的一路：陈石「扎马稳桩」+1
#   ⚠ 这里给的是「**升级**那一份」；突破给的是 break_gain（按根骨），两码事。
#   ⚠ 老档补课：这条成长是**后加**的，所以只要它变了就得把"已经过的级数"补上，
#     否则 50 级的人拿到星也只从 51 级才开始涨。补课口＝ hp_grow_sync（见下）。
# ============================================================
static func hp_grow_bonus(role_id: String) -> int:
	var n := 0
	var inn: Dictionary = Roles.innate_of(role_id)
	if not inn.is_empty():
		n += int(inn.get("hp_grow", 0))
	n += int(Stars.grow_fx(role_id, role_star_of(role_id)).get("hp_grow", 0.0))
	# v65e：专属被动那一路（陈石「扎马稳桩」+1）——读角色身上那一份（老档由 _sync_role_kit 刷新）
	var ps: Dictionary = _role_mut(role_id).get("passive", {})
	n += int(ps.get("hp_grow", 0))
	return maxi(0, n)

# v44（用户："我刚刚给苏用了洗髓丹 到50点 但是前面升了等级没有补回来"）：
#   上面那套补课原来**只管气血成长（hp_grow）**——守拙/星那一份补了，**根骨那一份没补**：
#   每级涨多少 ＝ 2 + 根骨/25（气）· 1 + 根骨/50（攻）；根骨一涨（洗髓丹），
#   过去那些级也该跟着涨。可 stats 是"升级那一刻"按当时的根骨加进去的，
#   所以只在下一级才见效——玩家一眼就看出来"前面升的等级没补回来"。
#
#   现在统一成**一笔记账**：role["grow_paid"] ＝ {"hp": 每级气血, "atk": 每级攻击, "lv": 结账时的等级}
#     · 该给多少（want）＝ level_gain()（＝基础成长 + 根骨档 + 气血成长）
#     · 已经结过多少（paid）＝ 上一次结账时那两个数
#     · 差额 × "已过的级数"（＝现在等级 −1）一次性补进 stats.hp / stats.atk
#   三个结账口：**吃洗髓丹（根骨变）· 升星（成长变）· 读档**（以后再有第三处变成长的就加个口）。
#   ⚠ 老档没有 grow_paid：按**模板根骨**当基线补一次（模板根骨＝这个人 1 级时的资质），
#     于是"以前喂过的洗髓丹"这一次会一次性补回来——这正是用户要的那口气；
#     气血那一份再把老字段 hp_grow（已经结过的成长加成）算进基线，避免重复给。
#   ⚠ 补的是**现在**等级 −1 那么多级（不是"上次结账时"的级数）：
#     结账之后新升的那几级，也是按旧成长加上去的，所以它们同样欠这一份。
#     账本里的 "lv" 是"上一次结账时的等级"，留着给人看（与文案对照），不参与算数。
#   ⚠ 因此**每一条改根骨/改成长的路都必须立刻调一次 grow_sync**（现在三处都接了：
#     吃洗髓丹 · 升星 · 读档）；漏调一次，下次结账就会把中间那几级多补一遍。
static func _template_gengu(role_id: String) -> int:
	if role_id == "chen_shi":
		return int(CHEN_SHI_DEFAULT.get("gengu", 0))
	if role_id == "qingluan":
		return int(QINGLUAN_DEFAULT.get("gengu", 0))
	return int(PLAYER_DEFAULT.get("gengu", 0))

# 老档第一次结账用的"已付基线"：模板根骨 ＋ 已经结过的气血成长（老字段 hp_grow）
#   v62h：攻击那条已经不再随等级给（LEVEL_GROWTH.atk = 0），这里照实算即可——
#   老档若当年按"每级 +攻"结过账，差额会被 grow_sync 夹成 0（只补不扣）✓
static func _paid_baseline(role_id: String, role: Dictionary) -> Dictionary:
	var g := _template_gengu(role_id)
	return {
		"hp": int(LEVEL_GROWTH["hp"]) + int(role.get("hp_grow", 0)),
		"atk": int(LEVEL_GROWTH["atk"]),
		"lv": int(role.get("lv", 1)),
	}

# 结账：把"每级成长变了"的那一份按**已过的级数**一次补进 stats。返回 {"hp": 补了多少气, "atk": 补了多少攻}
static func grow_sync(role_id: String) -> Dictionary:
	var role := _role_mut(role_id)
	if role.is_empty():
		return {"hp": 0, "atk": 0}
	var lv := maxi(1, int(role.get("lv", 1)))
	var want := level_gain(role_id)
	var paid_v: Variant = role.get("grow_paid", null)
	var paid: Dictionary = {}
	if paid_v is Dictionary and not (paid_v as Dictionary).is_empty():
		paid = (paid_v as Dictionary).duplicate()
	else:
		paid = _paid_baseline(role_id, role)
	var base_lv := maxi(0, lv - 1)   # "已过的级数"＝**现在**的等级 −1
	# v62g（压平等级成长那一批）：**只补不扣**。
	#   原来差额带符号——这次把每级成长调低，旧档一加载就会算出负数，
	#   等于**追溯倒扣**玩家已经练出来的属性 ✗。现在夹到 ≥0：
	#   老角色保住已经拿到的，只是**以后的每一级**按新曲线走。
	var dhp := maxi(0, (int(want.get("hp", 0)) - int(paid.get("hp", 0))) * base_lv)
	var datk := maxi(0, (int(want.get("atk", 0)) - int(paid.get("atk", 0))) * base_lv)
	# 账本每次都推进到"现在"（哪怕差额是 0）——下次再变就照这一次算
	role["grow_paid"] = {"hp": int(want.get("hp", 0)), "atk": int(want.get("atk", 0)), "lv": lv}
	role.erase("hp_grow")   # 老字段已并入 grow_paid.hp，不留了
	if dhp == 0 and datk == 0:
		return {"hp": 0, "atk": 0}
	var st: Dictionary = role.get("stats", {})
	st["hp"] = maxi(1, int(st.get("hp", 0)) + dhp)
	st["atk"] = maxi(1, int(st.get("atk", 0)) + datk)
	role["stats"] = st
	print("[账本] 成长补课：", str(role.get("name", role_id)),
		" 每级 气血 ", int(paid.get("hp", 0)), "→", int(want.get("hp", 0)),
		" · 攻击 ", int(paid.get("atk", 0)), "→", int(want.get("atk", 0)),
		"（已过 ", base_lv, " 级）→ 气血 +", dhp, " · 攻击 +", datk,
		"（现 气血 ", int(st["hp"]), " · 攻击 ", int(st["atk"]), "）")
	return {"hp": dhp, "atk": datk}

static func level_gain(role_id: String) -> Dictionary:
	var g := int(_role_mut(role_id).get("gengu", 0))
	# v62h：**升级只给气血**——攻击那条线交给突破（按根骨）、装备、功法。
	return {
		"hp": int(LEVEL_GROWTH["hp"]) + hp_grow_bonus(role_id),
		"atk": 0,
	}

# v39（用户问："角色升级不是根据资质固定成长吗？之前 30 级升苏 攻击 +2，现在 50 级只 +1"）：
#   成长**确实只跟资质（根骨）走，跟等级一点关系都没有**——level_gain 里没有 lv 这一项。
#   会看岔的是**升级那句话**：连升 N 级时它报的是"这一趟的合计"（N 级相加），
#   所以 28→30 级那一下写"攻击 +2"，而单升一级写"攻击 +1"——看着像成长变了。
#   对策两条：
#     ① level_up 的播报改成"**每级** X（本次 N 级共 Y）"——单位写清；
#     ② 面板/浮框里把"每级涨多少 + 离下一档还差几点根骨"写出来（下面这两口）。
#   ⚠ 门槛是整数除法：每 25 点根骨 → 每级气血 +1；每 50 点根骨 → 每级攻击 +1。
static func growth_line(role_id: String) -> String:
	var gain := level_gain(role_id)
	return "每级 气血 +" + str(int(gain.get("hp", 0))) + " · 攻击 +" + str(int(gain.get("atk", 0)))

# 门槛那一版（浮框里用）：说清"为什么是 +1"以及"还差几点根骨能到下一档"
static func growth_detail(role_id: String) -> String:
	var g := maxi(0, int(_role_mut(role_id).get("gengu", 0)))
	var to_hp := GENGU_HP_EVERY - (g % GENGU_HP_EVERY)
	var to_atk := GENGU_ATK_EVERY - (g % GENGU_ATK_EVERY)
	var grow := hp_grow_bonus(role_id)
	return (growth_line(role_id) + "（只随根骨，跟等级无关）"
		+ "｜根骨 " + str(g) + "：每 " + str(GENGU_HP_EVERY) + " 点 → 每级气血 +1、每 " + str(GENGU_ATK_EVERY) + " 点 → 每级攻击 +1"
		+ "（再 " + str(to_hp) + " 点根骨：气血再 +1；再 " + str(to_atk) + " 点：攻击再 +1）"
		+ ("｜成长类：气血 +" + str(grow) + "／级" if grow > 0 else ""))

# v44（用户："点击根骨可以显示当前成长 以及下一次成长需要多少根骨"）：
#   弟子面板上那颗「根骨」点开就是这一页——**现在每级涨多少** ＋ **到下一档还差几点根骨**。
#   数全在这里算（唯一真源），面板只管用大字把它画出来（字号/框在 character_panel）。
static func growth_box(role_id: String) -> Dictionary:
	var role := _role_mut(role_id)
	if role.is_empty():
		return {}
	var g := maxi(0, int(role.get("gengu", 0)))
	var lv := maxi(1, int(role.get("lv", 1)))
	var gain := level_gain(role_id)
	var grow := hp_grow_bonus(role_id)
	# v65e：这一段文案早就跟实现对不上了（写着「基础 2/1 ＋ 根骨档」，可 level_gain 早就
	#   压平成「基础 1 ＋ 成长类」，根骨也不再进每级成长了）——顺手改成实话：
	#   每级成长 ＝ 基础 ＋ 成长类；根骨改由**突破**折算（break_gain）。
	var bg := break_gain(role_id)
	var lines: Array = []
	lines.append("根骨 " + str(g) + "　·　" + str(lv) + " 级（已过 " + str(maxi(0, lv - 1)) + " 级）")
	lines.append("现在每级：气血 +" + str(int(gain.get("hp", 0))) + "　攻击 +" + str(int(gain.get("atk", 0))))
	lines.append("　＝ 基础 " + str(int(LEVEL_GROWTH["hp"])) + "/" + str(int(LEVEL_GROWTH["atk"]))
		+ (" ＋ 成长类 气+" + str(grow) if grow > 0 else "（现在没有成长类加成）"))
	lines.append("")
	lines.append("根骨不进每级成长——它管**突破**：每 " + str(BREAK_STEP) + " 级一道关，每次按根骨折算")
	lines.append("　　根骨 " + str(g) + " → 突破一次：攻 +" + str(int(bg.get("atk", 0)))
		+ " · 血 +" + str(int(bg.get("hp", 0))) + " · 防 +" + str(int(bg.get("def", 0))))
	lines.append("")
	# v61：洗髓丹已下线 → 根骨只由人物模板定，这里说明一句，别再指路丹药
	lines.append("根骨已定（不随等级、也没有丹药可涨）——每级成长就看上面那一行")
	var body := "\n".join(PackedStringArray(lines))
	return {"title": "根骨 · 成长（" + str(role.get("name", role_id)) + "）", "body": body.replace("**", "")}

static func add_exp(role_id: String, n: int) -> Array:
	var role := _role_mut(role_id)
	if role.is_empty() or n <= 0:
		return []
	role["exp"] = int(role.get("exp", 0)) + n
	return []

# ---- ㊾：经验池（独立经验 · 升级时直接扣）----
# 挂机收取、出村清缴的经验先进池子；**点［升级］就直接从池里扣**，不再需要先"分配"给谁。
# 个人那一份 exp 只作为"先花的钱"：看火 +20 这类直接给个人的经验先花掉，不够再动池子。
#   （旧口径：池子→［分配］→个人 exp→［升级］。多一步，已按需求撤掉。）
static var exp_pool := 0

# ㊾：exp_to_next / exp_pool_levels / grant_pool_exp 三个"分配专用"的口随［分配］钮一起删了——
#   现在唯一的花经验口就是 level_up（自己从 exp_pool 里扣），
#   "能升几级"看 levels_available（个人＋池子一起算）。

static func can_level(role_id: String) -> bool:
	return levels_available(role_id) > 0

# 这个人现在能升几级（个人经验 ＋ 经验池一起算；只算账，不动）
# v36：上限是**境界给的**（25×(境界+1)）——到顶就得先突破，见 break_do。
static func levels_available(role_id: String) -> int:
	var role := _role_mut(role_id)
	if role.is_empty():
		return 0
	var lv := int(role.get("lv", 1))
	var cap := level_cap(role_id)
	var exp := int(role.get("exp", 0))
	var pool := exp_pool
	var n := 0
	while lv < cap:
		var need := exp_need(lv)
		if exp >= need:
			exp -= need
		else:
			var short := need - exp
			if pool < short:
				break
			pool -= short
			exp = 0
		lv += 1
		n += 1
	return n

# v62m（用户："等级突破 也需要消耗银两"）：**升级的银两单价**
#   （2 + 等级/20；人从 1 练到 1000 级累计约 2.7 万两，约等于推满塔收益的 1/4）
static func level_silver_cost(lv: int) -> int:
	return maxi(1, 2 + int(maxi(1, lv) / 20))

static func level_up(role_id: String, times: int = 1) -> Dictionary:
	var role := _role_mut(role_id)
	if role.is_empty():
		return {"ok": false, "msg": "没有这个人", "levels": 0, "lv": 1}
	var lv := int(role.get("lv", 1))
	var cap := level_cap(role_id)        # v36：上限随境界走
	var exp := int(role.get("exp", 0))     # 个人那份（看火 +20 之类）——先花它
	var pool := exp_pool                   # ㊾：不够就直接从池里扣，不再要求先"分配"
	var st: Dictionary = role.get("stats", {})
	var done := 0
	var hp_sum := 0
	var atk_sum := 0
	var from_pool := 0
	var silver_sum := 0      # v62m：这一趟升级花掉的银两
	while done < times and lv < cap:
		var need := exp_need(lv)
		if exp >= need:
			exp -= need
		else:
			# 先花个人、再花池子——个人那份不会白搁着
			var short := need - exp
			if pool < short:
				break
			pool -= short
			from_pool += short
			exp = 0
		# ============================================================
		# v62m（用户："另外等级突破 也需要消耗银两"）：**升级本身也要银两**。
		#   单价随等级涨（2 + 等级/20）：1 级 2 两 · 100 级 7 两 · 500 级 27 两 ·
		#   1000 级 52 两 → 一个人从 1 练到 1000 级累计约 **2.7 万两**。
		#   ⚠ 银两不够就**停在当前等级**（已经花掉的经验不白费，只是升不动了），
		#     提示写在返回的 msg 里——不静默吞掉。
		# ============================================================
		var sp_lv := level_silver_cost(lv)
		if coin("silver") < sp_lv:
			break
		add_coin("silver", -sp_lv)
		silver_sum += sp_lv
		lv += 1
		var gain: Dictionary = level_gain(role_id)
		hp_sum += int(gain.get("hp", 0))
		atk_sum += int(gain.get("atk", 0))
		for k in gain.keys():
			st[k] = int(st.get(k, 0)) + int(gain[k])
		done += 1
	role["lv"] = lv
	role["exp"] = exp
	role["stats"] = st
	exp_pool = pool
	var nm := str(role.get("name", role_id))
	if done == 0:
		if need_break(role_id):
			return {"ok": false, "msg": nm + " 已到境界上限（" + str(cap) + " 级）——先突破（要 " + str(break_pill_need(role_id)) + " 颗「突破丹（" + break_pill_cn(role_id) + "）」）", "levels": 0, "lv": lv}
		if lv >= LEVEL_MAX:
			return {"ok": false, "msg": nm + " 已满级（" + str(LEVEL_MAX) + "）", "levels": 0, "lv": lv}
		var lack := exp_need(lv) - exp - pool
		return {"ok": false, "msg": "经验不够——个人＋经验池还差 " + str(maxi(0, lack)) + " 点才够升下一级", "levels": 0, "lv": lv}
	var msg := nm + " 升到 " + str(lv) + " 级（" + realm_of(lv) + "）"
	if done > 1:
		msg = nm + " 连升 " + str(done) + " 级 → " + str(lv) + " 级（" + realm_of(lv) + "）"
	# v39：单位写清——连升时报的是**这一趟的合计**，看着像"成长变了"。
	#   所以先写"每级"，再写"本次 N 级共"。成长只跟根骨走（见 GameState.growth_detail）。
	msg += "：" + growth_line(role_id)
	if done > 1:
		msg += "（本次 " + str(done) + " 级共：气血 +" + str(hp_sum) + " · 攻击 +" + str(atk_sum) + "）"
	if from_pool > 0:
		msg += "（从经验池扣 " + str(from_pool) + "）"
	if silver_sum > 0:
		msg += "（银两 -" + str(silver_sum) + "）"
	# v62m：银两见底而停下——把原因说出来（不然"点了没反应"最难查）
	if done < times and lv < cap and coin("silver") < level_silver_cost(lv):
		msg += "　⚠ 银两不够了：再升一级要 " + str(level_silver_cost(lv)) + " 两（现有 " + str(coin("silver")) + "）"
	var left := levels_available(role_id)
	if left > 0:
		msg += "（还能再升 " + str(left) + " 级）"
	print("[账本] 升级：", msg)
	return {"ok": true, "msg": msg, "levels": done, "lv": lv}

static func take_level_notes() -> Array:
	var a := level_notes
	level_notes = []
	return a

# ---- 合计属性 ----

static func _merge_stats(out: Dictionary, add: Dictionary) -> void:
	for k in add.keys():
		out[k] = int(out.get(k, 0)) + int(add[k])

# ============================================================
# v121（用户："去掉原先角色的境界标识 做一个新功能进阶【无关等级 根据关卡来突破境界】
#   境界提升所有角色的整体属性 还有境界压制…突破境界需要很多材料【增加新材料 有成功率】
#   可以从九品开始 暂定为18个境界"）：
#   **进阶（境界）＝全队共享的一条成长轴**，门槛看爬塔关卡、材料要得多、成功有几率；
#   加成的落点就在下面 effective_stats 的最后（所有角色一起吃）。
# ============================================================
const Realm := preload("res://shared/data_realm.gd")

static var advance_lv := 0                  # 当前境界下标（0 ＝ 九品）

static func advance_name() -> String:
	return Realm.name_of(advance_lv)

static func advance_pct() -> float:
	return Realm.pct_of(advance_lv)

static func advance_stage_need() -> int:
	if advance_lv >= Realm.MAX_LV:
		return -1                       # 已满
	return int(Realm.at(advance_lv + 1).get("stage_need", 0))

static func advance_pill_id() -> String:
	if advance_lv >= Realm.MAX_LV:
		return ""
	var t := advance_lv + 1
	if t <= 3:
		return "adv_fan"
	if t <= 6:
		return "adv_liang"
	if t <= 8:
		return "adv_shang"
	if t <= 11:
		return "adv_ji"
	return "adv_jue"

static func advance_pill_name() -> String:
	var pid := advance_pill_id()
	if pid == "":
		return ""
	return str(recipe_of(pid).get("name", pid))

static func advance_can() -> Dictionary:
	if advance_lv >= Realm.MAX_LV:
		return {"ok": false, "msg": "已是最高境界「" + advance_name() + "」"}
	var nx: Dictionary = Realm.at(advance_lv + 1)
	var need_stage := int(nx.get("stage_need", 0))
	if stage_progress < need_stage:
		return {"ok": false, "msg": "关卡不够：要到第 " + str(need_stage) + " 关（现在 " + str(stage_progress) + "）"}
	var pid := advance_pill_id()
	var lack: Array = []
	if pill_count(pid) < 1:
		lack.append(advance_pill_name() + " " + str(pill_count(pid)) + "/1")
	var sil := advance_silver()
	if coin("silver") < sil:
		lack.append("银两 " + str(coin("silver")) + "/" + str(sil))
	if not lack.is_empty():
		return {"ok": false, "msg": "材料不够：" + "、".join(PackedStringArray(lack))}
	return {"ok": true, "msg": "可以冲「" + str(nx.get("name", "")) + "」——成功率 " + str(int(float(nx.get("rate", 1.0)) * 100.0)) + "% · 用 1 颗 " + advance_pill_name() + " · 银两 " + str(sil)}

static func advance_cost() -> Dictionary:
	if advance_lv >= Realm.MAX_LV:
		return {}
	var nx: Dictionary = Realm.at(advance_lv + 1)
	var out: Dictionary = {}
	if int(nx.get("stone", 0)) > 0:
		out["jingshi"] = int(nx["stone"])
	if int(nx.get("dao", 0)) > 0:
		out["daoxin"] = int(nx["dao"])
	if int(nx.get("jin", 0)) > 0:
		out["jin"] = int(nx["jin"])
	return out

# v121b（用户："同时也会消耗银两"）：银两按"材料越多越贵"折算（境界石 ×40 两 + 道心砂 ×400 两）
static func advance_silver() -> int:
	if advance_lv >= Realm.MAX_LV:
		return 0
	var nx: Dictionary = Realm.at(advance_lv + 1)
	return int(nx.get("stone", 0)) * 40 + int(nx.get("dao", 0)) * 400

static func advance_rate() -> float:
	if advance_lv >= Realm.MAX_LV:
		return 0.0
	return float(Realm.at(advance_lv + 1).get("rate", 1.0))

# 冲境界：**先扣材料**，再掷成功率——失败材料全损（用户要的"有成功率"）
static func advance_try() -> Dictionary:
	var chk := advance_can()
	if not bool(chk.get("ok", false)):
		return {"ok": false, "msg": str(chk.get("msg", ""))}
	var pid := advance_pill_id()
	if not take_pill(pid, 1):
		return {"ok": false, "msg": "没有" + advance_pill_name()}
	add_coin("silver", -advance_silver())      # v121b：银两一起扣（失败也不退）
	var nx: Dictionary = Realm.at(advance_lv + 1)
	var nm := str(nx.get("name", ""))
	if randf() > float(nx.get("rate", 1.0)):
		return {"ok": false, "fail": true,
			"msg": "冲「" + nm + "」失败——进阶丹与银两尽毁，气机未成（成功率 " + str(int(float(nx.get("rate", 1.0)) * 100.0)) + "%，可再攒重来）"}
	advance_lv += 1
	save_game()
	var msg := "进阶成功：境界 → 「" + advance_name() + "」　全体属性 +" + str(int(advance_pct() * 100.0)) + "%"
	print("[账本] ", msg)
	return {"ok": true, "msg": msg}

static func effective_stats(role_id: String) -> Dictionary:
	var role := _role_mut(role_id)
	var out := {"atk": 0, "hp": 0, "spd": 0, "crit": 0, "dmg": 0, "def": 0, "dodge": 0, "crit_dmg": 0}
	# v58：五行那一组先摆 0（物理/元素增伤 + 五行抗性）——`_merge_stats` 是按源字典的键累加的，
	#   所以装备/功法/角色星/血脉里写了 `<elem>_dmg` / `<elem>_res` 就自动进来，
	#   读的人也不用再 `.get(k, 0)`。
	for k_e in Elem.stat_keys():
		out[k_e] = 0
	var base: Dictionary = role.get("stats", {})
	for k in out.keys():
		if base.has(k):
			out[k] = int(round(float(base[k])))
	for k2 in STAT_DEFAULTS.keys():
		if not base.has(k2):
			out[k2] = int(STAT_DEFAULTS[k2])
	# v62h：装备不再随等级放大（那条已回滚）——装备靠"数值本身被抬高了 70%/5.4 倍"
	#   在终局面板里占到应有的份额。
	var wid := str(role.get("weapon", ""))
	if wid != "":
		_merge_stats(out, starred_stats(wid))
	var gear: Dictionary = role.get("gear", {})
	for slot in gear.keys():
		var gsid := str(gear[slot])
		if gsid != "":
			_merge_stats(out, starred_stats(gsid))
	# 优化批⑬（#5）：村里面板全算上——功法（武学）的加成也计入合计
	var sk: Array = role.get("skills", [])
	for s_v in sk:
		var aid := str(s_v)
		if aid != "":
			_merge_stats(out, starred_stats(aid))
	# ㊺：攻击力改走"基础攻击 + 额外攻击"这一份口径——见 atk_parts()。
	#   这里直接把总数抄过来，保证面板/战斗看到的攻永远等于 atk_parts() 的 total，
	#   不会出现"拆账一个数、实际另一个数"。
	out["atk"] = int(atk_parts(role_id).get("total", out["atk"]))
	# ㊿z9：宠物随行的两条加成（护主＝全队气血% / 青隼＝速度%）就落在这里。
	#   放这一层的理由：村内战斗（squad_stats）、游历快照（carry_stats 取自这一份）、
	#   弟子面板、出征屏、离线爬塔估算读的都是这一份——只改一处，各处自动一致，
	#   不会出现"面板写着 +8%、打起来没有"这种自相矛盾。
	#   ⚠ 游历那边的算术（别当成 bug）：出征会先把随身兵器/装备/功法**全卸回仓库**，
	#     所以正式趟的快照 = 底子×(1+护主%)，随后 stats_of 再把"路上捡到又穿上的"
	#     那几件平面值加回来（那几件不再乘护主%，一趟下来差个位数的气血）。
	#     想让路捡的装备也吃这份加成，就得把"先乘后扣"改成"扣完再乘"——
	#     收益个位数气血，代价是多一条口径，不值当。
	var petc := pet_fx()
	var pet_hp := float(petc.get("pct", 0))
	if pet_hp != 0.0:
		out["hp"] = int(round(float(out["hp"]) * (1.0 + pet_hp / 100.0)))
	var pet_spd := float(petc.get("spd_pct", 0))
	if pet_spd != 0.0:
		out["spd"] = int(round(float(out["spd"]) * (1.0 + pet_spd / 100.0)))
	# v58（用户："血脉可以给一些了"）：宠物/血脉的**五行那一组**也并进来——
	#   `pct`/`spd_pct` 是"乘"，而增伤与抗性是**百分点加数**（与装备同口径），
	#   所以这里是 `+=`，别照上面那两条写成乘法。
	#   来源：`pet_fx()`（随行宠的阶加成 ＋ 已融合血脉的 `blood_value`，已乘升星倍率）。
	#   于是"血脉给火元素伤害 +8"这种东西一路走到面板、出村战斗、以及游历的出征快照。
	for k_p in Elem.stat_keys():
		var pv := float(petc.get(k_p, 0))
		if pv != 0.0:
			out[k_p] = int(out.get(k_p, 0)) + int(round(pv))
	# v121：**境界加成**（全队共享）——放在最末尾乘，三围一起抬。
	var ap := advance_pct()
	if ap > 0.0:
		for k_a in ["atk", "hp", "def"]:
			out[k_a] = maxi(1, int(round(float(out.get(k_a, 1)) * (1.0 + ap))))
	return out

# ㊽：队里口径 ＝ 个人口径 effective_stats ＋ 上阵羁绊。
#   谁要"这一队在场上时的属性"就用它：出村战斗、弟子面板、离线爬塔估算。
#   v48：面板要用的是 **panel_stats**（＝这一份再折进战斗那份 tfx），别直接读这一份。
#   ⚠ 游历**不吃这一份**，但**照样吃羁绊**——游历那边是 run_state.stats_of 自己按
#     "这趟带了谁"（party_role_ids）再调一次 Bonds.apply_to（所以别把羁绊挪进
#     effective_stats：那会让游历拿两份）。这条路以前那句注释写的是"羁绊天然带不出去"，
#     与实现相反，已改正。另外个人口径那份快照里**不含宠物**，宠物是这里乘的。
static func squad_stats(role_id: String) -> Dictionary:
	var out := effective_stats(role_id)
	Bonds.apply_to(out, role_id, formation)
	return out

# ㊺：攻击力拆账——基础攻击 + 额外攻击。
#   基础＝人物自己的攻击（PLAYER_DEFAULT 那份 stats，升级/丹药已经写进 stats 里）
#   额外＝手上兵器 ＋ 随身装备 ＋ 所习武学（＋ ㊽ 上阵羁绊，with_bonds=true 时）
#   合计(total) 就是出村战斗与游历决斗实际用的那个攻击力。
static func atk_parts(role_id: String, with_bonds := false) -> Dictionary:
	var role := _role_mut(role_id)
	var base := 0
	var st: Dictionary = role.get("stats", {})
	if st.has("atk"):
		base = int(round(float(st["atk"])))
	var weapon := 0
	var wid := str(role.get("weapon", ""))
	if wid != "":
		weapon = int(starred_stats(wid).get("atk", 0))
	var gear := 0
	var g: Dictionary = role.get("gear", {})
	for slot in g.keys():
		var gsid := str(g[slot])
		if gsid != "":
			gear += int(starred_stats(gsid).get("atk", 0))
	var arts := 0
	var sk2: Array = role.get("skills", [])
	for s2 in sk2:
		var aid2 := str(s2)
		if aid2 != "":
			arts += int(starred_stats(aid2).get("atk", 0))
	# ㊽：上阵羁绊给的那一份（面板要看得见；effective_stats 那条路不带它）。
	#   ⚠ 算法必须与 Bonds.apply_to 逐字一致（先按百分比放大、再加平面值），
	#     否则面板的"攻击 18"和拆账加起来会是 19——那个 1 点的差最难查。
	var bond := 0
	if with_bonds:
		var bfx: Dictionary = Bonds.fx_for(role_id, formation)
		var pre := base + weapon + gear + arts
		var bpct := float((bfx.get("pct", {}) as Dictionary).get("atk", 0.0))
		if bpct != 0.0:
			bond += int(round(float(pre) * (1.0 + bpct / 100.0))) - pre
		bond += int((bfx.get("flat", {}) as Dictionary).get("atk", 0))
	var extra := weapon + gear + arts + bond
	return {
		"base": base, "weapon": weapon, "gear": gear, "arts": arts, "bond": bond,
		"extra": extra, "total": base + extra,
	}

# ㊺：拆账的一句话写法（面板与提示共用一份，免得两处各写各的）
static func atk_parts_text(role_id: String, with_bonds := false) -> String:
	var p := atk_parts(role_id, with_bonds)
	var s := "基础 " + str(int(p["base"])) + " ＋ 兵器 " + str(int(p["weapon"]))
	if int(p["gear"]) != 0:
		s += " ＋ 装备 " + str(int(p["gear"]))
	if int(p["arts"]) != 0:
		s += " ＋ 武学 " + str(int(p["arts"]))
	if int(p.get("bond", 0)) != 0:
		s += " ＋ 羁绊 " + str(int(p["bond"]))
	return s + " ＝ " + str(int(p["total"]))

# ---- 出战阵容 ----

static func is_deployed(id: String) -> bool:
	return formation.has(id)

static func formation_names() -> Array:
	var out: Array = []
	for id in formation:
		var d := role_data(str(id))
		if not d.is_empty():
			out.append(str(d.get("name", id)))
	return out

static func formation_add(id: String) -> String:
	if formation.has(id):
		return "他已经在阵里了"
	if formation.size() >= DEPLOY_MAX:
		return "最多 " + str(DEPLOY_MAX) + " 人出战"
	formation.append(id)
	return str(role_data(id).get("name", id)) + " 上阵（" + str(formation.size()) + "/" + str(DEPLOY_MAX) + "）"

# v63（用户：阵型重做——"点哪条栏，点谁，谁就站那排"）：
#   把某人**插到指定的排位**（前/中/后）。已经在阵里就先摘下来再插；
#   插位超出现有长度就落在末尾。满了且人不在阵里 → 拒绝。
static func formation_put(id: String, slot_i: int) -> String:
	var name := str(role_data(id).get("name", id))
	if formation.has(id):
		formation.erase(id)   # 从旧位子摘下来
	elif formation.size() >= DEPLOY_MAX:
		return "位子满了（" + str(DEPLOY_MAX) + "/" + str(DEPLOY_MAX) + "）——先撤下一位"
	var i := clampi(slot_i, 0, formation.size())
	formation.insert(i, id)
	return name + " 站上「" + str(["前", "中", "后"][clampi(slot_i, 0, 2)]) + "」排（前→后＝出手先后）"

static func formation_remove(id: String) -> String:
	if not formation.has(id):
		return "他不在阵里"
	if formation.size() <= 1:
		return "至少留一人出战"
	formation.erase(id)
	return str(role_data(id).get("name", id)) + " 已撤下"

static func toggle_deploy(id: String) -> String:
	if formation.has(id):
		return formation_remove(id)
	return formation_add(id)

static func join_disciple() -> void:
	disciple_joined = true

# v65（用户：「苏 移除天赋 悟性高 和闪避那个」）：
#   原来 join_qingluan 给她 roll_talents(2, 1)（随机两条好签 ＋ 一条坏签），
#   于是会抽到「悟性过人（经验 +15%）」「身轻如燕（闪避 +4）」这种**跟她打法无关**的签——
#   她是匕首暴击刺客（自带洞察·残敌增伤 ＋ 被动剑走轻灵·暴击 +15%），要的是暴击与先手。
#   现在改成**固定两条**（下表），新档招募即如此；老档里已抽过的由
#   _sync_qingluan_talents 在读档时走一遍（只走一次，用 talents_fixed 标记）。
# v65c（用户：「苏天赋也无 就专属就够了」）：**空表**——她只靠专属那两条：
#   自带「洞察」（持匕首·绕前排直取后排 ＋ 残敌增伤）＋ 被动「剑走轻灵」（暴击 +15%、气血 -15%）。
#   想给她补签就往这个数组里写名字（表在 shared/data_talents.gd）。
const QINGLUAN_TALENTS: Array = []

static func _sync_qingluan_talents(role: Dictionary) -> void:
	if role.is_empty() or bool(role.get("talents_fixed", false)):
		return
	role["talents"] = QINGLUAN_TALENTS.duplicate()
	role["talents_fixed"] = true
	if QINGLUAN_TALENTS.is_empty():
		print("[账本] 苏青鸾不带天赋（只靠专属：洞察 ＋ 剑走轻灵）——原来的随机签已清掉")
	else:
		print("[账本] 苏青鸾的天赋已改为固定：", QINGLUAN_TALENTS)

static func join_qingluan() -> String:
	qingluan_joined = true
	var role := _role_mut("qingluan")
	_sync_qingluan_talents(role)
	var ts: Array = role.get("talents", [])
	if not formation.has("qingluan") and formation.size() < DEPLOY_MAX:
		formation.append("qingluan")
	var lines: Array = []
	for t in ts:
		lines.append(str(t))
	return "苏青鸾入队（上阵 " + str(formation.size()) + "/" + str(DEPLOY_MAX) + "）——天赋：" + "；".join(PackedStringArray(lines))

static func disciple_ids() -> Array:
	var out: Array = ["player"]
	if disciple_joined:
		out.append("chen_shi")
	if qingluan_joined:
		out.append("qingluan")
	return out

# ---- 装备操作 ----
#
# v60（用户报的："点上装备/武学，把没合成的碎片变完整穿上了"）：
#   ⚠ 名字有两套，**装备口径一律用 item_name（成品名）**：
#     · Cards.name_of(sid)   ＝ **套名／残卡名**：长剑、双刀、匕首、长枪、暗器（凡品那 5 套与成品不同名）
#     · Cards.item_name(sid) ＝ **成品名**：青锋剑、雁翎双刀、寒星匕首、破阵长枪、飞蝗石
#   以前这里的飘字与弟子面板读的是 name_of——于是玩家仓库里摆着「长剑·锋」的**残卡**，
#   装上一把青锋剑后消息写"已换上兵器：**长剑**"、弟子面板也写"长剑"，看着就像
#   "没合成的碎片自己变完整、还被穿上了"。村外（出征屏/游历/仓库/装配窗）早就全是
#   item_name 那一套，这里跟它们对齐（其余幾处见 character_panel / journey_shop_panel /
#   journey_bag_panel 的同名注释）。
#   ⚠ strip_restore 认的是前缀（"已换上"／"已装上"／"已卸下"），下面**别改前缀**。

static func vault_add_item(sid: String, n := 1) -> void:
	vault_items[sid] = int(vault_items.get(sid, 0)) + n
	# v58：新到手的份数**当场摇元素**（上品起的兵器）。这里摇、也就是"到手那一刻随机"，
	#   摇完就落盘；懒补（_elem_topup）只是老档与漏网路径的兜底。
	if n > 0:
		_elem_topup(sid)

# ---- v242：锻造动态件 ----
static func forge_next_sid() -> String:
	forge_seq += 1
	var sid := "forge_%04d" % forge_seq
	while forge_cards.has(sid) or not Cards.by_id(sid).is_empty():
		forge_seq += 1
		sid = "forge_%04d" % forge_seq
	return sid

static func note_forge(nm: String) -> void:
	if nm == "" or forge_names.has(nm):
		return
	forge_names.append(nm)
	add_prosperity(2, "新成品")

static func note_story_title(title: String) -> void:
	if title == "" or story_title_prosperity:
		return
	story_title_prosperity = true
	add_prosperity(5, "称号")

static func forge_add(sid: String, set: Dictionary) -> void:
	forge_cards[sid] = set
	Cards.register_forged(sid, set)
	vault_add_item(sid, 1)
	note_forge(str(set.get("name", "")))

static func grant_boss_weapon(boss_name: String) -> Dictionary:
	# v250：Boss 首杀专属兵器——直接进锻造库 / 仓库，可装备。
	var data := {
		"山君": {"name": "山君骨刃", "kind": "sword", "atk": 46, "dmg": 5, "affix": "pojun"},
		"夜叉": {"name": "夜叉鬼爪", "kind": "dual", "atk": 42, "dmg": 6, "affix": "yinrui"},
		"老妖": {"name": "老妖杖", "kind": "staff", "atk": 40, "dmg": 6, "affix": "buzhe"},
		"石傀": {"name": "石傀重锤", "kind": "staff", "atk": 48, "dmg": 7, "affix": "buzhe"},
		"无相": {"name": "无相刃", "kind": "sword", "atk": 60, "dmg": 9, "affix": "fengrui"},
		"雪魈": {"name": "雪魈獠牙", "kind": "dual", "atk": 44, "dmg": 6, "affix": "qingshen"},
	}
	var d: Dictionary = data.get(boss_name, {"name": "凶骨刃", "kind": "sword", "atk": 40, "dmg": 5, "affix": "pojun"})
	var nm := str(d["name"])
	note_forge(nm)
	var kind := str(d["kind"])
	var atk := int(d["atk"])
	var dmg := int(d["dmg"])
	var affix := str(d["affix"])
	var mul := 1.2 * ng_mul()
	var st := {"atk": int(round(atk * mul)), "dmg": int(round(dmg * mul))}
	var af := {"fengrui": {"crit": 5}, "buzhe": {"def": 3}, "yinrui": {"atk": 4}, "pojun": {"dmg": 4}, "qingshen": {"spd": 3}, "tiegu": {"hp": 80}}
	for k_v in (af.get(affix, {}) as Dictionary).keys():
		st[str(k_v)] = int(st.get(str(k_v), 0)) + int(af[affix][k_v])
	var sid := forge_next_sid()
	var set := {
		"id": sid, "name": nm, "item": nm, "pool": "weapon",
		"quality": "上品", "weapon": kind, "no_drop": true, "forge": true,
		"parts": [], "item_stats": st, "desc": "Boss 首杀专属（" + boss_name + "）",
	}
	forge_cards[sid] = set
	Cards.register_forged(sid, set)
	vault_add_item(sid, 1)
	forge_bag.append({
		"sid": sid, "blank": "boss", "weapon": nm, "kind": kind,
		"quality": 2, "cap": 4, "enhance": 10, "cracks": 0,
		"base_atk": float(atk), "base_dmg": float(dmg),
		"inspired_left": 0, "round_inspired": false, "awaiting": false,
		"affixes": [affix], "rule": "no_break", "source": "boss",
	})
	if forge_bag.size() > 40:
		forge_bag.pop_front()
	return {"sid": sid, "name": nm}

static func grant_broker_weapon() -> Dictionary:
	# v259：听雨楼楼主藏货——一次性专属成品。
	var nm := "听雨刃"
	note_forge(nm)
	var kind := "sword"
	var atk := 62
	var dmg := 8
	var st := {"atk": atk, "dmg": dmg, "crit": 5, "spd": 3}
	var sid := forge_next_sid()
	var set := {
		"id": sid, "name": nm, "item": nm, "pool": "weapon",
		"quality": "绝品", "weapon": kind, "no_drop": true, "forge": true,
		"parts": [], "item_stats": st, "desc": "听雨楼楼主藏货",
	}
	forge_cards[sid] = set
	Cards.register_forged(sid, set)
	vault_add_item(sid, 1)
	forge_bag.append({
		"sid": sid, "blank": "broker", "weapon": nm, "kind": kind,
		"quality": 4, "cap": 4, "enhance": 10, "cracks": 0,
		"base_atk": float(atk), "base_dmg": float(dmg),
		"inspired_left": 0, "round_inspired": false, "awaiting": false,
		"affixes": ["fengrui", "qingshen"], "rule": "no_break", "source": "broker",
	})
	if forge_bag.size() > 40:
		forge_bag.pop_front()
	return {"sid": sid, "name": nm}

static func grant_ng_weapon() -> Dictionary:
	var nm := "旧梦"
	note_forge(nm)
	var kind := "sword"
	var atk := 58 + mini(20, ng_plus * 4)
	var dmg := 8 + mini(6, ng_plus)
	var st := {"atk": atk, "dmg": dmg, "crit": 6, "spd": 3}
	var sid := forge_next_sid()
	var set := {
		"id": sid, "name": nm, "item": nm, "pool": "weapon",
		"quality": "绝品", "weapon": kind, "no_drop": true, "forge": true,
		"parts": [], "item_stats": st, "desc": "轮回旧梦专属",
	}
	forge_cards[sid] = set
	Cards.register_forged(sid, set)
	vault_add_item(sid, 1)
	forge_bag.append({
		"sid": sid, "blank": "ng", "weapon": nm, "kind": kind,
		"quality": 4, "cap": 4, "enhance": 10, "cracks": 0,
		"base_atk": float(atk), "base_dmg": float(dmg),
		"inspired_left": 0, "round_inspired": false, "awaiting": false,
		"affixes": ["fengrui"], "rule": "no_break", "source": "ng",
	})
	if forge_bag.size() > 40:
		forge_bag.pop_front()
	return {"sid": sid, "name": nm}

static func grant_north_weapon() -> Dictionary:
	# v264：北境平定专属——黑风刀。
	var nm := "黑风刀"
	note_forge(nm)
	var kind := "dual"
	var atk := 52
	var dmg := 7
	var st := {"atk": atk + 4, "dmg": dmg, "spd": 3}
	var sid := forge_next_sid()
	var set := {
		"id": sid, "name": nm, "item": nm, "pool": "weapon",
		"quality": "绝品", "weapon": kind, "no_drop": true, "forge": true,
		"parts": [], "item_stats": st, "desc": "北境平定专属",
	}
	forge_cards[sid] = set
	Cards.register_forged(sid, set)
	vault_add_item(sid, 1)
	forge_bag.append({
		"sid": sid, "blank": "north", "weapon": nm, "kind": kind,
		"quality": 4, "cap": 4, "enhance": 10, "cracks": 0,
		"base_atk": float(atk), "base_dmg": float(dmg),
		"inspired_left": 0, "round_inspired": false, "awaiting": false,
		"affixes": ["yinrui", "qingshen"], "rule": "no_break", "source": "north",
	})
	if forge_bag.size() > 40:
		forge_bag.pop_front()
	return {"sid": sid, "name": nm}

static func forge_remove(sid: String) -> void:
	forge_cards.erase(sid)
	Cards.unregister_forged(sid)

static func forge_wearer(sid: String) -> String:
	for rid in ["player", "chen_shi", "qingluan"]:
		var d: Dictionary = role_data(str(rid))
		if str(d.get("weapon", "")) == sid:
			return str(d.get("name", rid))
	return ""

static func vault_item_count(sid: String) -> int:
	return int(vault_items.get(sid, 0))

# v35：仓库里**还有货**的成品件名清单（升星台列件用：仓库散件也能直接升，不必先装到人身上）。
#   排序/过滤交给调用方——这里只回一份"有货的件名"。
static func vault_item_ids() -> Array:
	var out: Array = []
	for k in vault_items.keys():
		var sid := str(k)
		if int(vault_items[k]) > 0:
			out.append(sid)
	return out

static func equip_weapon(role_id: String, sid: String) -> String:
	var role := _role_mut(role_id)
	if role.is_empty():
		return "没有这个人"
	if str(Cards.by_id(sid).get("pool", "")) != "weapon":
		return "这件不是兵器"
	if vault_item_count(sid) <= 0:
		return "仓库里没有「" + Cards.item_name(sid) + "」"
	var old := str(role.get("weapon", ""))
	if old == sid:
		return "已经用的是这件"
	vault_items[sid] = vault_item_count(sid) - 1
	if old != "":
		vault_add_item(old, 1)
	role["weapon"] = sid
	role["weapon_label"] = ""
	return "已换上兵器：" + Cards.item_name(sid)

static func unequip_weapon(role_id: String) -> String:
	var role := _role_mut(role_id)
	var old := str(role.get("weapon", ""))
	if old == "":
		return "本来就没装兵器"
	vault_add_item(old, 1)
	role["weapon"] = ""
	role["weapon_label"] = ""
	return "已卸下：" + Cards.item_name(old) + "（放回仓库）"

static func equip_gear(role_id: String, slot: String, sid: String) -> String:
	var role := _role_mut(role_id)
	if role.is_empty():
		return "没有这个人"
	if slot != "armor" and slot != "helm" and slot != "cloak":
		return "没有这个槽位"
	if str(Cards.by_id(sid).get("pool", "")) != slot:
		return "这件不是" + str(SLOT_CN.get(slot, slot))
	if vault_item_count(sid) <= 0:
		return "仓库里没有「" + Cards.item_name(sid) + "」"
	var gear: Dictionary = role.get("gear", {})
	var old := str(gear.get(slot, ""))
	if old == sid:
		return "已经用的是这件"
	vault_items[sid] = vault_item_count(sid) - 1
	if old != "":
		vault_add_item(old, 1)
	gear[slot] = sid
	role["gear"] = gear
	return "已换上" + str(SLOT_CN.get(slot, slot)) + "：" + Cards.item_name(sid)

static func unequip_gear(role_id: String, slot: String) -> String:
	var role := _role_mut(role_id)
	var gear: Dictionary = role.get("gear", {})
	var old := str(gear.get(slot, ""))
	if old == "":
		return "这格本来就没装"
	vault_add_item(old, 1)
	gear[slot] = ""
	role["gear"] = gear
	return "已卸下：" + Cards.item_name(old) + "（放回仓库）"

static func equip_art(role_id: String, sid: String) -> String:
	var role := _role_mut(role_id)
	if role.is_empty():
		return "没有这个人"
	if str(Cards.by_id(sid).get("pool", "")) != "arts":
		return "这不是武学"
	# ㊿z4：量身定做的功法**不锁人**——照崩铁专武那把尺子（专武按命途限装，不按人锁）。
	#   别人装得上、也吃得到基础收益，只是"效果是照原主量身定的"。
	#   想提醒的话，卡片说明与仓库格子上已经写了"为某某量身定做"。
	if vault_item_count(sid) <= 0:
		return "仓库里没有「" + Cards.item_name(sid) + "」"
	var skills: Array = role.get("skills", [])
	if skills.has(sid):
		return "已经带着这门武学了"
	if skills.size() >= FREE_SKILL_SLOTS:
		return "可装武学只有 " + str(FREE_SKILL_SLOTS) + " 格（大招与自带技各占自己的位置，不吃这 3 格），先卸下一门"
	vault_items[sid] = vault_item_count(sid) - 1
	skills.append(sid)
	role["skills"] = skills
	return "已装上武学：" + Cards.item_name(sid)

static func unequip_art(role_id: String, idx: int) -> String:
	var role := _role_mut(role_id)
	var skills: Array = role.get("skills", [])
	if idx < 0 or idx >= skills.size():
		return "这一格是空的"
	var sid := str(skills[idx])
	skills.remove_at(idx)
	role["skills"] = skills
	vault_add_item(sid, 1)
	return "已卸下：" + Cards.item_name(sid) + "（放回仓库）"

# ---- 关卡收益（㉞：实现在 shared/tower.gd，这里转发）----
# 500 关之后收益曲线跟关号走，改曲线只动 tower.gd 顶部那几个系数。

static func stage_silver(i: int) -> int:
	return Tower.stage_silver(i)

static func boss_silver_gain(i := 0) -> int:
	return Tower.boss_silver_gain(i)

static func stage_exp(i: int) -> int:
	return Tower.stage_exp(i)

static func stage_exp_gain(i: int) -> int:
	# ㊿n：过关实发经验＝本关经验＋固定加成——每人一份 × 上阵人数
	# ㊴：接上「悟性过人／懒散」的 exp_pct（这条天赋一直没被消费过，是死的）
	var v := (Tower.stage_exp(i) + STAGE_EXP_BONUS) * formation.size()
	return maxi(1, int(round(float(v) * player_talent_exp_mul())))

# 上阵弟子里取最大的经验加成（悟性过人在谁身上就按谁算；没有＝1.0）
static func player_talent_exp_mul() -> float:
	var best := 0.0
	for id in formation:
		var v := float(talent_fx_of(str(id)).get("exp_pct", 0.0))
		if v > best:
			best = v
	return 1.0 + best / 100.0

# ㊳：首领赏改版——只有首领给，一件一件发（详见 tower.gift_next）
# 这个数组要落盘：不记的话每次重进游戏都会重发同一件。
static var tower_gifts: Array = []

static var last_stage_gift := ""        # 最近一次过关赏（sid；""＝这关没有）
static var last_stage_gift_line := ""   # 上面那件的展示串（"青锋剑（凡品）"）

# 面板用：下一件会是什么品级（让玩家看得见"线还有多长"）
static func tower_gift_tier_now() -> int:
	return Tower.gift_tier_of(tower_gifts.size())

# ============================================================
# v36（用户定）：宝箱账（表与掷法在 shared/tower.gd）
#   · stage_clear 里每清一关发一个（手动打、挂机推都算）
#   · 开箱落账：银两 / 角色碎片（有几率）/ 炼丹材料 / 突破丹（有几率）
#   · chest_inv 要落盘（world 段）——不记的话重进游戏箱子就没了
# ============================================================
static var chest_inv := {}     # cid -> 个数
static var chest_notes: Array = []   # 最近一次开箱的明细（面板显示用）

static func chest_add(cid: String, n := 1) -> void:
	if cid == "":
		return
	chest_inv[cid] = int(chest_inv.get(cid, 0)) + n

static func chest_count(cid := "") -> int:
	if cid == "":
		var n := 0
		for k in chest_inv.keys():
			n += int(chest_inv[k])
		return n
	return int(chest_inv.get(cid, 0))

static func chest_total() -> int:
	return chest_count("")

# ============================================================
# v133：宝箱的三条残卡线（武学残页 / 残兵 / 残装备）
#
#   用户："开宝箱给武学残页残兵 但是比角色碎片几率低 宝箱品质不同 给的残页品质也不同" +"也给残装备"
#
#   口径：
#     · 池子按**品级现算**（Tower.chest_card_pool：grad 就是品级下标），专武不进池；
#     · 一次给**同一套的 n 页**（页不重复）——分散给四套等于一套都凑不齐，所以必须同一套；
#     · 页数会被"这一套有几页"夹住（三页的套最多给三页）。
#   下面是两个小工具：攒账（pages 那种 {套id: {页号: 张数}}）与写明细。
# ============================================================
static func _chest_pages_into(acc: Dictionary, kind: String, grad: int, n_rng: Array) -> void:
	var ids: Array = Tower.chest_card_pool(kind, grad)
	if ids.is_empty():
		return
	var sid := str(ids[randi() % ids.size()])
	var parts: Array = Cards.parts_of(sid)
	var idxs: Array = []
	for i in parts.size():
		idxs.append(i)
	idxs.shuffle()
	var n := randi_range(int(n_rng[0]), int(n_rng[1]))
	var bucket: Dictionary = acc.get(sid, {})
	for i2 in mini(n, idxs.size()):
		var p := int(idxs[i2])
		bucket[p] = int(bucket.get(p, 0)) + 1
	acc[sid] = bucket

static func _chest_gear_into(mats: Dictionary, kind: String, grad: int, n_rng: Array) -> void:
	var ids: Array = Tower.chest_card_pool(kind, grad)
	if ids.is_empty():
		return
	var sid := str(ids[randi() % ids.size()])
	var n := randi_range(int(n_rng[0]), int(n_rng[1]))
	var mm: Dictionary = gear_salvage_mats(sid)
	for k in mm.keys():
		mats[str(k)] = int(mats.get(str(k), 0)) + int(mm[k]) * n

static func _bucket_sum(d: Dictionary) -> int:
	var n := 0
	for k in d.keys():
		n += int(d[k])
	return n

# "劈山掌·残页（卷上×1、卷中×1）"——哪一套、凑到哪几页，一句话说清
static func _chest_pages_text(sid: String, bucket: Dictionary) -> String:
	var parts: Array = Cards.parts_of(sid)
	var seg: Array = []
	for p_v in bucket.keys():
		var p := int(p_v)
		var pn := str(parts[p]) if p < parts.size() else "?"
		seg.append(pn + "×" + str(int(bucket[p_v])))
	var tail := "残页" if Cards.is_arts(sid) else ("残兵" if str(Cards.by_id(sid).get("pool", "")) == "weapon" else "残片")
	return Cards.item_name(sid) + "·" + tail + "（" + "、".join(PackedStringArray(seg)) + "）"

# 开 n 个某品质的箱子（返回 {"ok","msg","got"}；got 是明细数组）
static func chest_open(cid: String, n := 1) -> Dictionary:
	var d: Dictionary = Tower.chest_def(cid)
	if d.is_empty():
		return {"ok": false, "msg": "没这种箱子", "got": []}
	var have := chest_count(cid)
	if have <= 0:
		return {"ok": false, "msg": "没有「" + Tower.chest_name(cid) + "」可开——清关攒箱子", "got": []}
	var cnt := mini(maxi(n, 1), have)
	chest_inv[cid] = have - cnt
	var silver := 0
	var mats: Dictionary = {}
	var frags: Dictionary = {}
	var pill_got: Dictionary = {}
	# v133：三条残卡线（武学残页 / 残兵 / 残装备）——都按"套 → 页"收，最后一次性进仓库
	var pages: Dictionary = {}
	for k in cnt:
		# ① 角色碎片（有几率）
		if randf() < float(d.get("frag_chance", 0.0)):
			var fr: Array = d.get("frag", [1, 1])
			var pick: Dictionary = Loot.FRAGMENTS[randi() % Loot.FRAGMENTS.size()]
			var fid := str(pick.get("id", "frag_player"))
			var fn := randi_range(int(fr[0]), int(fr[1]))
			frags[fid] = int(frags.get(fid, 0)) + fn
		# ② v273：宝箱不再出成品突破丹——改成突破材料
		if randf() < float(d.get("pill_chance", 0.0)):
			var bq := clampi(int(d.get("grad", 0)), 0, 4)
			mats["pojing"] = int(mats.get("pojing", 0)) + 1 + int(bq / 2)
			if bq >= 2:
				mats["xuantie"] = int(mats.get("xuantie", 0)) + 1
		# ④ v133：武学残页（几率**比角色碎片低**，品质跟箱子走）
		if randf() < float(d.get("page_chance", 0.0)):
			_chest_pages_into(pages, "arts", int(d.get("grad", 0)), d.get("page_n", [1, 1]))
		# ⑤ v133：残兵残卡（比残页再低一点）
		if randf() < float(d.get("blade_chance", 0.0)):
			_chest_gear_into(mats, "weapon", int(d.get("grad", 0)), d.get("blade_n", [1, 1]))
		# ⑥ v133：残装备残片（护甲/玉佩/披风三池合一）
		if randf() < float(d.get("gear_chance", 0.0)):
			_chest_gear_into(mats, "gear", int(d.get("grad", 0)), d.get("gear_n", [1, 1]))
		# ⑦ 银两与材料（掷 rolls 次）
		silver += Tower.chest_silver_total(_chest_stage_hint, cid)
		# v134：材料那一掷的命中率改成**表里可调**（mat_chance，默认 0.45 是旧值）——
		#   45% → 30%，但一次给的量翻倍（mat_n），总期望反而涨两~三成
		for r in int(d.get("rolls", 1)):
			if randf() < float(d.get("mat_chance", 0.45)):
				var mn: Array = d.get("mat_n", [1, 1])
				var mid := Tower.chest_roll_mat()
				mats[mid] = int(mats.get(mid, 0)) + randi_range(int(mn[0]), int(mn[1]))
	# 落账
	add_coin("silver", silver)
	var mq2 := clampi(int(d.get("grad", 0)), 0, 4)
	for k2 in mats.keys():
		add_material(str(k2), int(mats[k2]), mq2)
	for k3 in frags.keys():
		add_fragment(str(k3), int(frags[k3]))
	# v133：残卡进仓库（vault_deposit 吃 {套id: {页号: 张数}}）
	if not pages.is_empty():
		vault_deposit(pages)
	for k4 in pill_got.keys():
		pills[str(k4)] = int(pills.get(str(k4), 0)) + int(pill_got[k4])
	# 明细（面板显示 + 日志）
	var got: Array = []
	got.append("银两 +" + str(silver))
	for k5 in mats.keys():
		got.append(mat_name(str(k5)) + " ×" + str(int(mats[k5])))
	for k6 in frags.keys():
		got.append(fragment_name(str(k6)) + " ×" + str(int(frags[k6])))
	# v133：三条残卡线的明细（写清"哪一套、缺的哪几页"，开箱完一眼知道凑到哪了）
	for k6b in pages.keys():
		got.append(_chest_pages_text(str(k6b), pages[k6b]))
	for k7 in pill_got.keys():
		got.append(str(recipe_of(str(k7)).get("name", k7)) + " ×" + str(int(pill_got[k7])))
	chest_notes = got.duplicate()
	# v2：再给一份**结构化**明细——开箱动画要按"件型"上色/排先后（银两/材料/碎片/丹）。
	#   顺序＝由稀到常（碎片 → 突破丹 → 银两 → 材料），飞出来的头几件就是好东西。
	#   ⚠ got（字符串那串）照旧不动：它是账本口径，别的地方在读。
	var items: Array = []
	# v133：残卡排在**最前面**（比角色碎片更稀罕——先飞出来的就是好东西）
	for k7p in pages.keys():
		items.append({"kind": "page", "name": Cards.item_name(str(k7p)) + "残页", "n": _bucket_sum(pages[k7p])})
	for k7b in frags.keys():
		items.append({"kind": "frag", "name": fragment_name(str(k7b)), "n": int(frags[k7b])})
	for k8 in pill_got.keys():
		items.append({"kind": "pill", "name": str(recipe_of(str(k8)).get("name", k8)), "n": int(pill_got[k8])})
	items.append({"kind": "silver", "name": "银两", "n": silver})
	for k9 in mats.keys():
		items.append({"kind": "mat", "name": mat_name(str(k9)), "n": int(mats[k9])})
	var msg := "开了 " + str(cnt) + " 个「" + Tower.chest_name(cid) + "」：" + "、".join(PackedStringArray(got))
	print("[账本] 宝箱：", msg)
	return {"ok": true, "msg": msg, "got": got, "items": items, "n": cnt, "cid": cid}

# 开箱银两要按"哪一关的箱子"算——箱子上不记关号（省字段），
#   统一按**当前进度那一关**的赏格（挂机推完再开，给的就是推到的那一关的价）。
static var _chest_stage_hint := 0
static func chest_set_stage_hint(i: int) -> void:
	_chest_stage_hint = maxi(0, i)

static func stage_clear(i: int) -> bool:
	if i != stage_progress:
		return false
	if i >= STAGE_MAX:
		return false
	stage_progress += 1
	chest_set_stage_hint(i)          # v36：开箱按"最后清掉那一关"的赏格算
	chest_add(Tower.chest_for_stage(i))   # v36：每清一关给一个宝箱
	# ㊿n：木料收益取消（折进经验）；银两按系数实发
	add_coin("silver", stage_silver(i))
	# 爬塔＝食物储存主路：清一关给粮，越往后越多
	var stage_food := 2 + mini(12, int(i / 80))
	action_add(stage_food)
	if is_boss(i):
		add_coin("silver", boss_silver_gain(i))   # ㉞：首领赏随档涨，要传关号
	exp_pool += stage_exp_gain(i)
	last_stage_gift = ""
	last_stage_gift_line = ""
	# ㊳：首领才掉装备/兵器/功法。凡品给整套；良品起按顺序发残页——
	#   一件一件来、页也一页一页来，凑齐了才开新的一件（件件都保证能到手）
	if is_boss(i):
		var have_of := func(sid: String) -> Array:
			var arr: Array = []
			for k in maxi(1, Cards.part_count(sid)):
				arr.append(vault_count(sid, k))
			return arr
		var got: Dictionary = Tower.gift_next(tower_gifts, have_of)
		if not got.is_empty():
			var sid := str(got.get("sid", ""))
			var gpool := str(Cards.by_id(sid).get("pool", ""))
			if ["weapon", "armor", "helm", "cloak"].has(gpool):
				# 爬塔不给装备：装备赏改成粮草
				var food_gain := 4 + mini(8, int(i / 80))
				action_add(food_gain)
				if not tower_gifts.has(sid):
					tower_gifts.append(sid)
				last_stage_gift = sid
				last_stage_gift_line = "粮草 +" + str(food_gain)
				print("[账本] 首领赏：第 ", i + 1, " 关 → 粮草 +", food_gain, "（装备赏已换成粮草）")
				return true
			if bool(got.get("complete", false)):
				# v268：整本不出；拆成一页残页（整本的主路留给货仓）
				var part0 := 0
				var bucket0: Dictionary = vault_cards.get(sid, {})
				bucket0[part0] = int(bucket0.get(part0, 0)) + 1
				vault_cards[sid] = bucket0
				if not tower_gifts.has(sid):
					tower_gifts.append(sid)
				last_stage_gift = sid
				last_stage_gift_line = Cards.card_name(sid, part0) + "（残页 · " + Cards.quality_of(sid) + "）"
				print("[账本] 首领赏：第 ", i + 1, " 关 → ", last_stage_gift_line, "（整本不出，只给残页）")
				return true
			else:
				var part := int(got.get("part", 0))
				var bucket: Dictionary = vault_cards.get(sid, {})
				bucket[part] = int(bucket.get(part, 0)) + 1
				vault_cards[sid] = bucket
				last_stage_gift = sid
				last_stage_gift_line = Cards.card_name(sid, part) + "（残页 · " + Cards.quality_of(sid) + "）"
				var finished := bool(got.get("done", false))
				if finished:
					# 这页是最后缺的一页 → 这套齐了，记为"已给过"，下次开新的一件
					tower_gifts.append(sid)
				print("[账本] 首领赏：第 ", i + 1, " 关 → ", last_stage_gift_line,
					"（这套凑齐了）" if finished else "")
	return true

# ---- 材料（含灵草 / 宠物料） ----

# v121（用户："增加新材料"）：境界石 / 道心砂——进阶专用（别的路不掉、也不花）
const MAT_CN := {"zhi": "紫芝", "shen": "雪参", "guo": "朱果", "bone": "兽骨碎", "rice": "灵米", "jin": "金髓",
	"forge_stone": "锻造石", "jingshi": "境界石（金）", "daoxin": "道心砂（红）", "atlas": "舆图",
	"soul": "兽魂", "lingguo": "灵兽果",
	"daoguo": "悟道果", "hundun": "混沌砂", "xinghui": "星辉",
	"pojing": "破境花", "xuantie": "玄铁精"}
# v271：材料四类——战斗 / 成长 / 突破 / 宠物。
const MAT_GROUP := {"guo": "battle", "bone": "battle", "rice": "battle",
	"zhi": "growth", "shen": "growth", "jin": "growth",
	"jingshi": "advance", "daoxin": "advance", "daoguo": "advance", "hundun": "advance", "xinghui": "advance",
	"pojing": "break", "xuantie": "break", "soul": "pet", "lingguo": "pet"}
const MAT_GROUP_CN := {"battle": "战斗材料", "growth": "成长材料", "advance": "进阶材料", "break": "突破材料", "pet": "宠物材料"}
const PILL_GROUP_CN := {"battle": "战斗丹", "growth": "成长丹", "advance": "进阶丹", "break": "突破丹", "pet": "宠物丹"}
const PILL_GROUP_ORDER := ["battle", "growth", "advance", "break", "pet"]

# v41（用户："增加金色材料，同时让洗灵丹也能炼，也是稀有的金色材料才能炼制"）：
#   **金髓** ＝ 稀有的**金色材料**——洗髓丹与宠物资质丹（洗灵丹）都要它才能开炉。
#   来路三处（都偏稀）：爬塔宝箱（权重 3）· 游历搜刮的药材池（权重 5）· 货栈每日限购 1 块。
#   `MAT_RARE` 里列的材料，凡是在界面上出现都会带一个 ◆ 前缀（一眼看出"这是那味金材料"）。
const MAT_RARE := ["jin", "jingshi", "daoxin", "daoguo", "hundun", "xinghui", "pojing", "xuantie", "soul", "lingguo"]

static func mat_is_rare(k: String) -> bool:
	return MAT_RARE.has(k)

static func mat_name(k: String) -> String:
	var nm := str(MAT_CN.get(k, k))
	return ("◆" + nm) if mat_is_rare(k) else nm

static func _mq_key(k: String, q: int) -> String:
	return k + "|" + str(clampi(q, 0, 4))

static func material_count_q(k: String, q: int) -> int:
	return int(material_q.get(_mq_key(k, q), 0))

static func add_material(k: String, n: int, q := 0) -> int:
	if n < 0:
		var need := -n
		for qi in range(4, -1, -1):
			var key := _mq_key(k, qi)
			var have := int(material_q.get(key, 0))
			if have <= 0:
				continue
			var take := mini(have, need)
			material_q[key] = have - take
			need -= take
			if need <= 0:
				break
		if need > 0:
			# 老档 / 无品质栈——按凡品兜底
			material_q[_mq_key(k, 0)] = int(material_q.get(_mq_key(k, 0), 0)) - need
		materials[k] = maxi(0, int(materials.get(k, 0)) - (-n))
		return int(materials[k])
	var qq := clampi(q, 0, 4)
	var key2 := _mq_key(k, qq)
	material_q[key2] = int(material_q.get(key2, 0)) + n
	materials[k] = int(materials.get(k, 0)) + n
	return int(materials[k])

static func consume_material(k: String, n: int) -> int:
	if n <= 0:
		return 0
	if material_count(k) < n:
		return -1
	var low := 4
	var need := n
	for qi in range(4, -1, -1):
		var key := _mq_key(k, qi)
		var have := int(material_q.get(key, 0))
		if have <= 0:
			continue
		var take := mini(have, need)
		material_q[key] = have - take
		low = mini(low, qi)
		need -= take
		if need <= 0:
			break
	if need > 0:
		low = mini(low, 0)
	materials[k] = maxi(0, int(materials.get(k, 0)) - n)
	return low



static func highest_material_quality(k: String) -> int:
	for q in range(4, -1, -1):
		if material_count_q(k, q) > 0:
			return q
	return 0

static func estimate_quality(rid: String, count := 1) -> int:
	var r := recipe_of(rid)
	if r.is_empty():
		return -1
	var low := 4
	for k in (r.get("cost", {}) as Dictionary).keys():
		if material_count(str(k)) < int(r["cost"][k]) * maxi(1, count):
			return -1
		low = mini(low, highest_material_quality(str(k)))
	return low

static func quality_cn(q: int) -> String:
	return str(Cards.QUALITY_ORDER[clampi(q, 0, 4)])

static func material_quality_text(k: String) -> String:
	var arr: Array = []
	for q in range(4, -1, -1):
		var n := material_count_q(k, q)
		if n > 0:
			arr.append(quality_cn(q) + "×" + str(n))
	return " · ".join(PackedStringArray(arr))

static func material_count(k: String) -> int:
	return int(materials.get(k, 0))

static func grant_herbs() -> void:
	herbs_granted = true
	add_material("zhi", 2)
	add_material("shen", 2)
	add_material("guo", 2)

# ---- 炼丹 ----

const DAN_RECIPES := [
	{"id": "qiangshen", "name": "强身丹", "desc": "气血 +10", "stat": "hp", "add": 10, "cost": {"zhi": 2}, "min": 3, "group": "growth"},
	{"id": "cuiti", "name": "淬体丹", "desc": "攻击 +2", "stat": "atk", "add": 2, "cost": {"shen": 2}, "min": 5, "group": "growth"},
	{"id": "qingshen", "name": "轻身丹", "desc": "速度 +2", "stat": "spd", "add": 2, "cost": {"zhi": 1, "shen": 1}, "min": 6, "group": "growth"},
	{"id": "ningshen", "name": "凝神丹", "desc": "暴击 +1", "stat": "crit", "add": 1, "cost": {"jin": 1}, "min": 8, "group": "growth"},
	# v61（用户："移除洗髓丹"）：原来这里有一条
	#   {"id": "xisui", ... "stat": "gengu", "add": 1, cost 含 jin ...}（根骨 +1）
	#   —— 整条**删掉**：丹方、掉落（data_loot.pill_by_id）、搜刮阶梯（data_ladder）都下线了。
	#   ⚠ 后果：**根骨再没有成长途径**，只由人物模板定（少侠 62 / 陈石 35 / 苏青鸾 48）；
	#     「服药」弹窗、弟子面板、炼丹阁里那些"洗髓 x/y"的文案也一并去掉了。
	#   想恢复：把这一条加回来，再把 data_loot / data_ladder 那两处一起加回来。
	{"id": "yangling", "name": "养灵丹", "desc": "宠物灵息 +30", "stat": "pet", "add": 30, "cost": {"soul": 1}, "min": 2, "group": "pet"},
	# ㊿z9：洗灵丹——宠物资质丹。**炼不出来**（loot_only）：只从搜刮红件里偶尔翻到，
	#   稀有、限量，每阶最多吃 1 颗。
	# v41：洗灵丹（宠物资质丹）**改成能炼了**——但只有金髓能开炉（以前是 loot_only，只能搜刮）
	# v62b（用户："洗灵丹丹方 材料全部去掉"）：`cost` 清空——**一颗料都不用**，
	#   只吃炉时（min 14）与炉位。于是"极度稀有"落在**掉落那一头**（红稀有行 4%），
	#   想稳定拿就在炼丹阁排炉子——不再是"攒够金髓"的攒料题。
	#   ⚠ 连带：`金髓`（jin）从此**没有丹方在用它**了（原本只此一处）。材料本身、宝箱权重、
	#     货栈每日限购那件都**照旧保留**（等以后有新丹方再用），只是眼下属于"先留着"的稀有料。
	{"id": "xiling", "name": "洗灵丹", "desc": "宠物资质 +2（极稀）", "stat": "pet_apt", "add": PET_APT_PILL_ADD, "cost": {"soul": 1, "lingguo": 1}, "min": 14, "group": "pet"},
	# ---- v36：突破丹五品（用户定：每 25 级突破一次，吃一颗对应品级的丹）----
	#   stat 写成 "break"：它**不是吃的丹**——不涨属性，也不进［服药］列表，
	#   只在角色面板点［突破］用（见 break_do）。炼丹炼得出；货栈每日限购也有卖。
	#   成本与炉时随品级抬（min＝炉时分钟）：凡品最便宜，绝品要一堆好料 + 20 分钟。
	# v272：进阶丹五品——只用于冲境界，不直接吃。
	{"id": "adv_fan", "name": "进阶丹（凡品）", "desc": "冲境界用 · 八品~六品", "stat": "advance", "add": 0, "cost": {"jingshi": 2}, "min": 6, "group": "advance"},
	{"id": "adv_liang", "name": "进阶丹（良品）", "desc": "冲境界用 · 五品~三品", "stat": "advance", "add": 0, "cost": {"jingshi": 3, "daoxin": 1}, "min": 10, "group": "advance"},
	{"id": "adv_shang", "name": "进阶丹（上品）", "desc": "冲境界用 · 二品~一品", "stat": "advance", "add": 0, "cost": {"jingshi": 4, "daoxin": 2, "daoguo": 1}, "min": 14, "group": "advance"},
	{"id": "adv_ji", "name": "进阶丹（极品）", "desc": "冲境界用 · 上品~绝品", "stat": "advance", "add": 0, "cost": {"jingshi": 5, "daoxin": 3, "daoguo": 2, "hundun": 1}, "min": 18, "group": "advance"},
	{"id": "adv_jue", "name": "进阶丹（绝品）", "desc": "冲境界用 · 化境~神境", "stat": "advance", "add": 0, "cost": {"jingshi": 6, "daoxin": 4, "daoguo": 3, "hundun": 2, "xinghui": 1}, "min": 22, "group": "advance"},
	{"id": "tupo_fan", "name": "突破丹（凡品）", "desc": "境界 1~8 重用的突破丹（每 25 级一重）", "stat": "break", "add": 0, "cost": {"pojing": 1}, "min": 4, "group": "break"},
	{"id": "tupo_liang", "name": "突破丹（良品）", "desc": "境界 9~16 重用的突破丹", "stat": "break", "add": 0, "cost": {"pojing": 1, "xuantie": 1}, "min": 8, "group": "break"},
	{"id": "tupo_shang", "name": "突破丹（上品）", "desc": "境界 17~24 重用的突破丹", "stat": "break", "add": 0, "cost": {"pojing": 2, "xuantie": 1}, "min": 12, "group": "break"},
	{"id": "tupo_ji", "name": "突破丹（极品）", "desc": "境界 25~32 重用的突破丹", "stat": "break", "add": 0, "cost": {"pojing": 2, "xuantie": 2}, "min": 16, "group": "break"},
	{"id": "tupo_jue", "name": "突破丹（绝品）", "desc": "境界 33~39 重用的突破丹", "stat": "break", "add": 0, "cost": {"pojing": 3, "xuantie": 3}, "min": 20, "group": "break"},
	# v269：探险战斗丹（简单三味；不入永久属性）
	{"id": "combat_hp", "name": "气血丹", "desc": "探险中服下：全队回复 35% 气血", "stat": "combat", "effect": "heal", "add": 35, "cost": {"guo": 1}, "min": 2, "combat": true, "group": "battle"},
	{"id": "combat_rage", "name": "怒气丹", "desc": "下一场战斗：全队开场怒气满（固定极品）", "stat": "combat", "effect": "rage", "add": 100, "cost": {"guo": 1, "rice": 1}, "min": 2, "combat": true, "group": "battle"},
	{"id": "combat_atk", "name": "攻丹", "desc": "下一场战斗：全队攻击提升", "stat": "combat", "effect": "atk", "add": 15, "cost": {"bone": 2}, "min": 3, "combat": true, "group": "battle"},
	{"id": "combat_crit", "name": "暴击丹", "desc": "下一场战斗：全队暴击提升", "stat": "combat", "effect": "crit", "add": 5, "cost": {"bone": 1, "guo": 1}, "min": 3, "combat": true, "group": "battle"},
	{"id": "combat_def", "name": "守丹", "desc": "下一场战斗：全队受到伤害降低", "stat": "combat", "effect": "def", "add": 10, "cost": {"rice": 2}, "min": 3, "combat": true, "group": "battle"},
	{"id": "combat_spd", "name": "疾丹", "desc": "下一场战斗：全队速度提升", "stat": "combat", "effect": "spd", "add": 10, "cost": {"rice": 1}, "min": 2, "combat": true, "group": "battle"},
	{"id": "combat_dodge", "name": "闪丹", "desc": "下一场战斗：全队闪避提升", "stat": "combat", "effect": "dodge", "add": 5, "cost": {"rice": 1, "guo": 1}, "min": 2, "combat": true, "group": "battle"},
	{"id": "combat_critdmg", "name": "暴伤丹", "desc": "下一场战斗：全队暴击伤害提升", "stat": "combat", "effect": "critdmg", "add": 15, "cost": {"bone": 2, "guo": 1}, "min": 3, "combat": true, "group": "battle"},
	{"id": "combat_dmg", "name": "破军丹", "desc": "下一场战斗：全队造成伤害提升（直接乘最终伤害）", "stat": "combat", "effect": "dmg", "add": 10, "cost": {"bone": 2, "rice": 1}, "min": 3, "combat": true, "group": "battle"},

]
const PILLS_PER_REALM := 3
const GENGU_PER_REALM := 1
const TEND_FAST := 0.7
const TEND_MUL := {"player": 0.85, "chen_shi": 0.70, "qingluan": 0.80}   # 看火效率（暂定）
const ALCHEMY_TEND_EXP := 7     # v62m：9 → 7（跟着经验收益再砍 25%）     # 看火的人每收一炉得的经验（v62：12 → 9，跟着"经验再砍一批"）

static var pills := {}
static var alchemy := {}      # ⚠ v41 起**只用来读老档**（以前是"唯一那一炉"）——新账看 furnaces

# ============================================================
# v41：炼丹改成**多炉 + 同类型多颗**（用户："炼丹不用只能练一颗，而且收起来才能练下一颗，
#   太麻烦了；可以同类型多颗；想练不同的类型需要花费银两开启下一个炼丹炉【也是在炼丹窗口
#   界面】越往下开越贵。"）
#
#   · `furnaces`       —— 炉位表，长度 ＝ 已开炉位数；每个已用炉位一条：
#                          {"recipe": rid, "tender": tid, "end_ts": 秒, "count": N}
#                        空炉位就是 {}（不删，靠下标定位）
#   · `furnace_slots`  —— 已开几个炉位（1 起，最多 FURNACE_MAX）
#   · **同类型多颗**：一炉点 N 颗 = 材料 ×N、时间 ×N×0.8（一次点完省两成时间）
#   · **开炉位**：第 2 个 2000 两、第 3 个 6000、第 4 个 16000、第 5 个 40000（越往下越贵），
#     按钮就在炼丹窗口里（用户要求）
#   ⚠ 老档迁移：以前存的是**一个** `alchemy` 字典 {recipe,tender,end_ts}——读档时搬进 0 号炉。
# ============================================================
const FURNACE_MAX := 5
const FURNACE_COST := [0, 2800, 8400, 22500, 56000]   # 下标＝"现在已有几个炉位"，即开下一个的价
const ALCHEMY_BATCH_MAX := 5      # 一炉最多同时炼几颗
const ALCHEMY_BATCH_TIME := 0.8   # 同类型多颗的时间折扣（材料照 ×N 收）

static var furnaces: Array = []
static var furnace_slots := 1

static func furnace_count() -> int:
	return clampi(furnace_slots, 1, FURNACE_MAX)

static func furnace_at(i: int) -> Dictionary:
	if i < 0 or i >= furnaces.size():
		return {}
	return furnaces[i] as Dictionary

static func furnace_is_busy(i: int) -> bool:
	return not furnace_at(i).is_empty()

static func furnace_free() -> int:
	for i in furnace_count():
		if furnace_at(i).is_empty():
			return i
	return -1

static func furnace_used() -> int:
	var n := 0
	for i in furnace_count():
		if furnace_is_busy(i):
			n += 1
	return n

static func furnace_cost_next() -> int:
	var cur := furnace_count()
	if cur >= FURNACE_MAX:
		return 0
	return int(FURNACE_COST[clampi(cur, 0, FURNACE_COST.size() - 1)])

# 某一炉还剩几秒（slot < 0 ＝ 全部炉里最短的那一个——村口牌子与旧调用点用这个）
static func alchemy_remain_sec(slot := -1) -> int:
	var now := int(Time.get_unix_time_from_system())
	if slot >= 0:
		var f := furnace_at(slot)
		if f.is_empty():
			return 0
		return maxi(0, int(f.get("end_ts", 0)) - now)
	var best := -1
	for i in furnace_count():
		var f2 := furnace_at(i)
		if f2.is_empty():
			continue
		var rem := maxi(0, int(f2.get("end_ts", 0)) - now)
		if best < 0 or rem < best:
			best = rem
	return maxi(0, best)

static func alchemy_busy() -> bool:
	return furnace_used() > 0

# 已经炼好、等着收的炉位
static func alchemy_ready_slots() -> Array:
	var out: Array = []
	for i in furnace_count():
		if furnace_is_busy(i) and alchemy_remain_sec(i) <= 0:
			out.append(i)
	return out

# 村口牌子/日志要的一句摘要
static func furnace_line() -> String:
	var used := furnace_used()
	if used <= 0:
		return "炉火都闲着（" + str(furnace_count()) + " 个炉位）"
	var ready := alchemy_ready_slots().size()
	var s := str(used) + "/" + str(furnace_count()) + " 炉在炼"
	if ready > 0:
		s += "，有 " + str(ready) + " 炉丹成了"
	else:
		s += "，最快还差 " + str((alchemy_remain_sec() + 59) / 60) + " 分"
	return s

static func furnace_tender_text() -> String:
	var names: Array = []
	for i in furnace_count():
		var f := furnace_at(i)
		if f.is_empty():
			continue
		var tid := str(f.get("tender", ""))
		if tid != "":
			names.append(tend_name(tid))
	return "" if names.is_empty() else " · ".join(PackedStringArray(names))

# v270：丹药品质——货仓能掉带品质的战斗丹；基础配方炼出来是凡品。
static func pill_base(rid: String) -> String:
	return rid.split("#")[0]

static func pill_quality(rid: String) -> int:
	if pill_base(rid) == "combat_rage":
		return 4
	var parts := rid.split("#")
	if parts.size() > 1:
		return clampi(int(parts[1]), 0, 4)
	return 0

static func pill_quality_name(rid: String) -> String:
	return str(Cards.QUALITY_ORDER[pill_quality(rid)])

static func pill_full_name(rid: String) -> String:
	var r := recipe_of(rid)
	return str(r.get("name", rid))

static func pill_entries() -> Array:
	var out: Array = []
	for rid_v in pills.keys():
		var rid := str(rid_v)
		var n := pill_count(rid)
		if n <= 0:
			continue
		var r := recipe_of(rid)
		if r.is_empty():
			continue
		out.append({"id": rid, "name": str(r.get("name", rid)), "count": n, "group": str(r.get("group", ""))})
	return out

static func recipe_of(rid: String) -> Dictionary:
	var base: String = pill_base(rid)
	var q: int = pill_quality(rid)
	for r in DAN_RECIPES:
		if str(r["id"]) != base:
			continue
		var out: Dictionary = (r as Dictionary).duplicate(true)
		if base == "combat_rage":
			out.erase("quality")
			out["id"] = "combat_rage"
			out["name"] = "怒气丹"
			out["add"] = 100
			out["desc"] = "下一场战斗：全队开场怒气满。固定效果，不分品质。"
			return out
		if q <= 0 and rid == base:
			return out
		out["id"] = rid
		out["quality"] = q
		out["name"] = str(r.get("name", base)) + "（" + str(Cards.QUALITY_ORDER[q]) + "）"
		var eff := str(r.get("effect", ""))
		if eff == "heal":
			out["add"] = 35 + q * 10
		elif eff == "rage":
			out["add"] = 60 + q * 10
		elif eff == "atk":
			out["add"] = 15 + q * 8
		elif eff == "crit":
			out["add"] = 5 + q * 4
		elif eff == "def":
			out["add"] = 10 + q * 6
		elif eff == "spd":
			out["add"] = 10 + q * 5
		elif eff == "dodge":
			out["add"] = 5 + q * 3
		elif eff == "critdmg":
			out["add"] = 15 + q * 10
		elif eff == "dmg":
			out["add"] = 10 + q * 9
		out["desc"] = str(r.get("desc", "")) + "（" + str(Cards.QUALITY_ORDER[q]) + "）"
		return out
	return {}

static func cost_text(cost: Dictionary) -> String:
	var arr: Array = []
	for k in cost.keys():
		arr.append(mat_name(str(k)) + "×" + str(int(cost[k])))
	return " · ".join(PackedStringArray(arr))

# ⚠ v41：`alchemy_busy()` / `alchemy_remain_sec()` 的实现在上面"多炉"那一节里
#   （带 slot 参数；不传就是"任意炉／最快那炉"）——这里不再重复定义。

static func tend_mul(id: String) -> float:
	if id == "":
		return 1.0
	return float(TEND_MUL.get(id, 1.0))

static func tend_name(id: String) -> String:
	if id == "":
		return "没人"
	return str(_role_mut(id).get("name", id))

static func can_tend(id: String) -> String:
	if id == "":
		return ""
	if _role_mut(id).is_empty():
		return "没有这个人"
	if id == "chen_shi" and not disciple_joined:
		return "陈石还没入门——先去历练"
	if id == "qingluan" and not qingluan_joined:
		return "苏青鸾还没入队——清到第 " + str(STORY_NVXIA_STAGE) + " 关"
	if is_deployed(id):
		return tend_name(id) + " 正在出战——先在弟子面板把他/她［撤下］（下战），才能来看火"
	return ""

static func alchemy_start(rid: String, tender: String, count := 1, slot := -1) -> String:
	# ㊿：没有炉子就开不了炉——这道闸是硬的。菜单那边"炼丹阁的牌子要过 300 关才显"
	#   是第一道；这里是第二道，防的是"以后从别处调进来"（或者档里状态不对）。
	if not dange_built:
		return "还没起炼丹阁——过第 300 关（灵草剧情）后回村起一间"
	# v41：炉位——slot < 0 ＝ 自己找第一个空炉；一个空炉都没有就让他去开炉位
	var s := slot
	if s < 0:
		s = furnace_free()
	if s < 0:
		return "炉位都占着（" + str(furnace_count()) + "/" + str(FURNACE_MAX) + "）——要么先收一炉，要么花 " + str(furnace_cost_next()) + " 两在炼丹窗口点［开新炉］"
	if not furnace_is_busy(s):
		pass
	elif true:
		return "第 " + str(s + 1) + " 号炉上正忙——换一个炉位，或先收那一炉"
	var r := recipe_of(rid)
	if r.is_empty():
		return "没有这炉方子"
	var why := can_tend(tender)
	if why != "":
		return why
	# v41：同类型多颗
	var n := clampi(count, 1, ALCHEMY_BATCH_MAX)
	var cost: Dictionary = r.get("cost", {})
	var need: Dictionary = {}
	for k in cost.keys():
		need[str(k)] = int(cost[k]) * n
	for k2 in need.keys():
		if material_count(str(k2)) < int(need[k2]):
			return "材料不够：这一炉 ×" + str(n) + " 要 " + cost_text(need) + "（现有 " + cost_text(_have_of(need)) + "）"
	var pq := 4
	for k3 in need.keys():
		var q3 := consume_material(str(k3), int(need[k3]))
		if q3 < 0:
			return "材料不够：这一炉 ×" + str(n) + " 要 " + cost_text(need)
		pq = mini(pq, q3)
	# 时长：第 1 颗照原时长，之后每颗 ×0.8（见 batch_minutes）——单颗的老手感一点没变
	var mins := batch_minutes(rid, n, tender)
	var mul := 1.0
	var who := "没人看火"
	if tender != "":
		mul = tend_mul(tender)
		who = tend_name(tender) + "看火 ×" + str(snappedf(mul, 0.05))
	var secs := int(ceil(mins * 60.0))
	_ensure_furnace_slots()
	furnaces[s] = {"recipe": rid, "tender": tender, "end_ts": int(Time.get_unix_time_from_system()) + secs, "count": n, "pq": pq}
	return ("第 " + str(s + 1) + " 号炉开火：「" + str(r["name"]) + "」×" + str(n)
		+ "——约 " + str(snappedf(mins, 0.1)) + " 分后成丹（" + who + "）")

# 一炉 N 颗要多久（**唯一口径**：状态与面板都读这一口）
#   ⚠ 折扣只加在"多出来的那几颗"上：第 1 颗照原时长，之后每颗 ×0.8——
#     这样 n=1 时与以前一模一样（以前单颗就是 min 分）。
static func batch_minutes(rid: String, count: int, tender: String) -> float:
	var r := recipe_of(rid)
	var n := clampi(count, 1, ALCHEMY_BATCH_MAX)
	var mins := float(int(r.get("min", 3))) * (1.0 + float(n - 1) * ALCHEMY_BATCH_TIME)
	if tender != "":
		mins *= tend_mul(tender)
	return mins

# 账上"现有多少材料"（提示里用）
static func _have_of(need: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in need.keys():
		out[str(k)] = material_count(str(k))
	return out

# 炉位数组补齐到 furnace_slots（老档/新开炉位都走这一口）
static func _ensure_furnace_slots() -> void:
	while furnaces.size() < furnace_count():
		furnaces.append({})
	while furnaces.size() > FURNACE_MAX:
		furnaces.remove_at(furnaces.size() - 1)

# 花银两开下一个炉位（用户："越往下开越贵"，按钮在炼丹窗口里）
static func furnace_unlock() -> Dictionary:
	var cur := furnace_count()
	if cur >= FURNACE_MAX:
		return {"ok": false, "msg": "炉位已经全开了（" + str(FURNACE_MAX) + " 个）"}
	var price := furnace_cost_next()
	if coin("silver") < price:
		return {"ok": false, "msg": "银两不够：开第 " + str(cur + 1) + " 个炉位要 " + str(price) + " 两（现有 " + str(coin("silver")) + "）"}
	add_coin("silver", -price)
	furnace_slots = cur + 1
	_ensure_furnace_slots()
	save_game()
	var msg := "开了第 " + str(furnace_slots) + " 个炉位（花 " + str(price) + " 两）"
	if furnace_cost_next() > 0:
		msg += "｜下一炉位要 " + str(furnace_cost_next()) + " 两"
	else:
		msg += "｜炉位已全开"
	print("[账本] 炼丹阁：", msg)
	return {"ok": true, "msg": msg}

static func alchemy_rush() -> bool:
	# 测试键 V：**所有在炼的炉**一起快进（原来只有一个炉，语义没变）
	var any := false
	var now := int(Time.get_unix_time_from_system())
	for i in furnace_count():
		var f := furnace_at(i)
		if f.is_empty():
			continue
		furnaces[i]["end_ts"] = now
		any = true
	return any

# 收丹：slot < 0 ＝ 收**第一个炼好的**炉（面板与旧调用点都走这一口）
static func alchemy_collect(slot := -1) -> Dictionary:
	var s := slot
	if s < 0:
		var ready := alchemy_ready_slots()
		if ready.is_empty():
			if not alchemy_busy():
				return {"ok": false, "msg": "炉子是空的"}
			return {"ok": false, "msg": "丹还在炉里——最快那炉还差约 " + str((alchemy_remain_sec() + 59) / 60) + " 分钟"}
		s = int(ready[0])
	var f := furnace_at(s)
	if f.is_empty():
		return {"ok": false, "msg": "第 " + str(s + 1) + " 号炉是空的"}
	var rem := alchemy_remain_sec(s)
	if rem > 0:
		return {"ok": false, "msg": "第 " + str(s + 1) + " 号炉还在炼——还差约 " + str((rem + 59) / 60) + " 分钟"}
	var rid := str(f.get("recipe", ""))
	var tender := str(f.get("tender", ""))
	var n := maxi(1, int(f.get("count", 1)))
	var pq := clampi(int(f.get("pq", 0)), 0, 4)
	var key := rid if pq <= 0 else rid + "#" + str(pq)
	var r := recipe_of(key)
	pills[key] = int(pills.get(key, 0)) + n
	furnaces[s] = {}
	var msg := "丹成：「" + str(r.get("name", key)) + "」×" + str(n) + " 收进包裹（包裹共 " + str(int(pills.get(key, 0))) + " 颗）"
	if tender != "":
		add_exp(tender, ALCHEMY_TEND_EXP * n)
		msg += "｜" + tend_name(tender) + "看火 +" + str(ALCHEMY_TEND_EXP * n) + " 经验"
	return {"ok": true, "msg": msg, "slot": s, "n": n}

static func pill_count(rid: String) -> int:
	return int(pills.get(rid, 0))

static func take_pill(rid: String, n := 1) -> bool:
	var have := pill_count(rid)
	if have < n:
		return false
	pills[rid] = have - n
	return true

# v269：战斗丹药

# v36：每"境"能给几颗——境＝**境界**（突破次数），不再是"每 10 级"。
#   境界 39 时：属性丹 120 颗、洗髓 40 颗。
static func realm_idx(role_id: String) -> int:
	return role_realm(role_id)

static func stat_pill_allow(role_id: String) -> int:
	return (realm_idx(role_id) + 1) * PILLS_PER_REALM

static func gengu_pill_allow(role_id: String) -> int:
	return (realm_idx(role_id) + 1) * GENGU_PER_REALM

static func eat_pill(role_id: String, rid: String) -> String:
	var r := recipe_of(rid)
	if r.is_empty():
		return "没有这炉方子"
	# ㊿z9：宠物那一族的丹（养灵丹 stat="pet"、洗灵丹 stat="pet_apt"）一律挡在这里。
	#   旧代码只挡了 "pet"——洗灵丹会被写进 role.stats["pet_apt"]，等于白扔一颗稀有丹。
	if str(r.get("stat", "")).begins_with("pet"):
		return "这是宠物的丹药——去「宠物」面板喂它（人吃了没用）"
	# v36：突破丹也不是吃的——它是突破用的材料（角色面板点［突破］）
	if str(r.get("stat", "")) == "break":
		return "「" + str(r.get("name", rid)) + "」是突破用的——去弟子面板点［突破］，别当丹药吃了"
	if pill_count(rid) <= 0:
		return "包裹里没有「" + str(r.get("name", rid)) + "」——先去炼丹阁炼一炉"
	var role := _role_mut(role_id)
	if role.is_empty():
		return "没有这个人"
	var is_g := str(r.get("stat", "")) == "gengu"
	var used_key := "gengu_used" if is_g else "pills_used"
	var used := int(role.get(used_key, 0))
	var allow := gengu_pill_allow(role_id) if is_g else stat_pill_allow(role_id)
	if used >= allow:
		return "服用已满 " + str(used) + "/" + str(allow) + "——境界提升（每突破一重）可再扩"
	pills[rid] = pill_count(rid) - 1
	var msg := str(role.get("name", role_id)) + "服下「" + str(r.get("name", rid)) + "」：" + str(r.get("desc", ""))
	if is_g:
		role["gengu"] = int(role.get("gengu", 0)) + int(r.get("add", 1))
		# v44（用户："给苏用了洗髓丹到 50 点，但是前面升了等级没有补回来"）：
		#   根骨一涨，**过去那些级的成长也得跟着涨**——这里立刻结一次账，
		#   把 (新每级 − 旧每级) × 已过的级数 一次补进 stats（见 grow_sync）。
		var sync := grow_sync(role_id)
		var dhp2 := int(sync.get("hp", 0))
		var datk2 := int(sync.get("atk", 0))
		if dhp2 != 0 or datk2 != 0:
			# ⚠ 这句话会落到弟子面板底部那行小字（374 宽 / 14 号，只装两行），
			#   所以要短：单位、数字都压到最小，别在这儿展开成长明细（那在根骨页里）。
			msg += "｜" + str(maxi(0, int(role.get("lv", 1)) - 1)) + " 级补课："
			if dhp2 != 0:
				msg += "气血+" + str(dhp2)
			if datk2 != 0:
				msg += ("·攻击+" + str(datk2))
	else:
		var st: Dictionary = role.get("stats", {})
		var sk := str(r.get("stat", ""))
		st[sk] = int(st.get(sk, 0)) + int(r.get("add", 0))
		role["stats"] = st
	role[used_key] = used + 1
	return msg + "（本境已服 " + str(used + 1) + "/" + str(allow) + "）"

# ---- 货币 ----

static func add_coin(k: String, n: int) -> int:
	coins[k] = maxi(0, int(coins.get(k, 0)) + n)
	return int(coins[k])

static func coin(k: String) -> int:
	return int(coins.get(k, 0))

static func coin_line(include_wen := true) -> String:
	if include_wen:
		return "文钱 " + str(coin("wen")) + " · 银两 " + str(coin("silver")) + " · 元宝 " + str(coin("yuanbao"))
	return "银两 " + str(coin("silver")) + " · 元宝 " + str(coin("yuanbao"))

# ---- 挂机（在线+离线同池；8 小时封顶；手动收取；收益随章节升档） ----

static func _idle_now() -> int:
	return int(Time.get_unix_time_from_system())

static func idle_absorb(sec: int) -> void:
	if sec <= 0:
		return
	idle_pool_sec = mini(idle_pool_sec + sec, IDLE_CAP_SEC)

static func idle_load() -> int:
	var cf := ConfigFile.new()
	var now := _idle_now()
	var err := cf.load(IDLE_CFG)
	if err != OK:
		idle_pool_sec = 0
		_idle_last_ts = now
		_idle_save()
		return 0
	idle_pool_sec = int(cf.get_value("idle", "pool_sec", 0))
	_idle_last_ts = int(cf.get_value("idle", "last_ts", now))
	var before := idle_pool_sec
	var elapsed := now - _idle_last_ts
	idle_absorb(elapsed)
	var added := idle_pool_sec - before
	_idle_last_ts = now
	_idle_save()
	# ㊵：离线自动爬塔——按"正常打一关要多久"逐关往上推，打不过就卡住。
	#   ㊼：驱动口收进 _idle_climb，离线回来和"在线每 20 秒"走同一条路。
	_idle_climb(elapsed)
	return added

# ㊼：挂机爬塔的唯一驱动口。
#   ㊿：**闸门改了**——现在必须玩家自己开［自动挑战］才会推塔。
#     原来这里写的是"开了自动挑战才**不**推"（怕跟屏幕上的战斗抢关卡），
#     结果是：**什么都没点的时候挂机自己爬塔**，玩家眼里就是"它怎么自己开始了"。
#     现在口径跟玩家的直觉对齐：
#       · ［自动挑战］关（默认）→ 挂机只攒银两/经验，**塔不动**
#       · ［自动挑战］开         → 挂机照推（屏幕外按估算推，屏幕内是真打）
#   另外：屏幕上正打着这一关时不推（估算跟真战斗抢同一关会跳关/重复结算）。
const CLIMB_MIN_SEC := 20          # 少于这么多秒不值得推一关（免得每帧都算）

static func _idle_climb(elapsed: int) -> void:
	if elapsed < CLIMB_MIN_SEC or stage_progress >= STAGE_MAX:
		return
	if not auto_climb:
		return
	if battle_live:
		return
	# ㊿：这一拍里屏幕上打过真仗（哪怕现在正好在两场之间的空档）——让位给它。
	#   不加这条的话，同步点正好落在"打完一关、下一关还没开"的那一两秒里，
	#   估算会把同一关再推一次（重复结算/跳关）。
	if _battle_seen:
		_battle_seen = false
		return
	# ㊿r：剧情关（第 50/150/300 关）之前停下——那三关**必须真打一场**，
	#   不许估算替你过（见 climb_gate）。
	if stage_progress >= climb_gate():
		return
	run_offline_climb(float(elapsed))

# ㊿r：后台估算（挂机/离线）最远只能推到哪一关**之前**。
#   第 50/150/300 关是剧情关（藏宝图／青鸾入阵／灵草），它们同时是逢 25 的首领关。
#   规矩：这三关必须**真打一场**——估算（formation_dps_est + Tower.can_beat）只按
#   血池/输出/减伤粗算，不看武学大招、也不细算词缀，替你把首领和剧情一起过了不公平。
#   所以后台推到它前一关就停：回来点［挑战］打这一场，剧情照常在村里弹。
#   ⚠ 两个护栏，免得塔被永久卡死：
#     · 标志已置真（剧情放过了）→ 这一道闸门撤掉；
#     · 关卡已经越过去了（老档、或你自己打过了标志却没置上）→ 也撤掉，不再回头拦。
static func climb_gate() -> int:
	var g := STAGE_MAX
	if not map_found and stage_progress < STORY_MAP_STAGE:
		g = mini(g, STORY_MAP_STAGE - 1)
	if not qingluan_joined and stage_progress < STORY_NVXIA_STAGE:
		g = mini(g, STORY_NVXIA_STAGE - 1)
	if not herbs_granted and stage_progress < STORY_HERB_STAGE:
		g = mini(g, STORY_HERB_STAGE - 1)
	return g

# ㊿r：这一关是不是"必须真打"的剧情关（给面板文案用）
static func is_story_stage(i: int) -> bool:
	var n := i + 1
	return n == STORY_MAP_STAGE or n == STORY_NVXIA_STAGE or n == STORY_HERB_STAGE

# ---- ㊵ 离线爬塔 ----

static var offline_note := ""      # 回村播报（菜单取走即清）
# ㊿：屏幕上有没有正在打的那一场（battle_lite 进出时置）。
#   挂机估算靠它避开"正打的这一关"，免得两边抢关卡。
static var battle_live := false
# ㊿：这一拍（两次 idle_sync 之间）里打过真仗没有——哪怕现在在两场之间的空档，
#   估算也要让位（见 _idle_climb）。battle_lite 开打时置真。
static var _battle_seen := false

static func take_offline_note() -> String:
	var s := offline_note
	offline_note = ""
	return s

# 我方每回合大概能打多少（离线估算用）
static func formation_dps_est() -> Dictionary:
	var dps := 0.0
	# ㊼：血池按"前排先挨打"算，不再把全队血量当成一个整池。
	#   普攻只打前排（站位规则），只有前排倒了后排才顶上——那会儿输出也少了一截。
	#   以前是"全队血量相加 ＋ 全队最高减伤"，两头都取最好的，估出来自然乐观得多。
	#
	#   这里把每个人的血量折成"能扛下多少原始伤害"（hp ÷ (1-减伤)）：
	#   前排算全份，后排算半份。返回的 cut 因此固定是 0（已经折进 hp 里了）。
	var pool := 0.0
	var idx := 0
	# v35：防御 / 闪避也一起报出去（前排那一名说了算——挨打的就是他）。
	#   它们是**数值**，具体挡多少要看对手的攻击值，所以不在这里折成 cut，
	#   而是交给 Tower.run_offline / _after_my_def 按每一关的敌人现算（同一个公式）。
	var front_def := 0.0
	var front_dodge := 0.0
	var front_atk := 0.0
	for id_v in formation:
		var id := str(id_v)
		var role := _role_mut(id)
		if role.is_empty():
			continue
		# ㊽：这里也走队里口径（含羁绊）——离线估的是"这一队在场上"的仗，
		#   跟 battle_lite 用同一份，不然挂机推的关和手动打的对不上。
		var eff := squad_stats(id)
		var atk := float(eff.get("atk", 8))
		# ㊿y／v48：天赋 ＋ 角色星 stat ＋ 专武常驻 fx —— 走 combat_tfx 那一口
		#   （以前这里漏了专武：装了专武"手动打得过、挂机不敢推"，见 combat_tfx 的注）
		var tfx: Dictionary = combat_tfx(id)
		# 伤害% 与暴击都按"期望值"折进去
		var dmg_pct := float(eff.get("dmg", 0)) + float(tfx.get("dmg", 0))
		var crit := float(eff.get("crit", 5)) + float(tfx.get("crit", 0))
		# v48：暴击的期望值改按**真暴伤**算（以前写死 ×0.6 的系数）：
		#   期望倍率 = 1 + 暴击率 ×（暴伤倍率 − 1）。
		#   爆伤那一份 = 面板暴伤 ＋ tfx 暴伤（星「凝息」那种"乘倍率"的 crit_mul_up 也并进来）。
		var crit_dmg := float(eff.get("crit_dmg", 50)) + float(tfx.get("crit_dmg", 0))
		var crit_mul_up := 1.0 + float(combat_mech(id).get("crit_mul_up", 0.0))
		var crit_p := clampf(crit, 0.0, 100.0) / 100.0
		var crit_mul := 1.0 + crit_p * ((1.0 + crit_dmg / 100.0) * crit_mul_up - 1.0)
		# 普攻基准倍率借用出村战斗的 DMG_MUL（2.0）——离线只求量级对
		dps += atk * (1.0 + dmg_pct / 100.0) * crit_mul * 2.0
		var my_hp := float(eff.get("hp", 80))
		# ㊿y：气血% 也要折进来（以前只吃自带的 hp_pct，天赋与星的那一份漏掉了——
		#   估出来偏保守，塔会在"其实打得过"的地方停下）
		my_hp *= 1.0 + float(tfx.get("hp_pct", 0)) / 100.0
		# 减伤：v48 改成**与实战同口径的逐层相乘**——
		#   被动 taken_cut（吃星/专武的 passive_up）× 五问的 dmg_cut（残血那一层）。
		#   以前这里写的是"取最大"，估出来比实战硬，塔会在打不过的地方硬推（或反过来不敢推）。
		var pas: Dictionary = role.get("passive", {})
		var c := 0.0
		if str(pas.get("kind", "")) == "taken_cut":
			# 角色星/专武的「被动强化」在这里也要算（跟两套引擎同一个口径）
			c = float(pas.get("v", 0.0)) * (1.0 + float(combat_mech(id).get("passive_up", 0.0)))
		var inn := Roles.innate_of(id)
		if str(inn.get("kind", "")) == "innate_hp_pct":
			my_hp *= 1.0 + float(inn.get("hp_pct", 0.0))
		elif str(inn.get("kind", "")) == "thorn_up":
			pass   # 反刺对"能不能打赢"影响小，离线不细算
		var tc := clampf(float(tfx.get("dmg_cut", 0)) / 100.0, 0.0, 0.9)
		var keep := (1.0 - clampf(c, 0.0, 0.9)) * (1.0 - tc)   # 两层相乘（＝实战的算法）
		var absorb := my_hp / maxf(0.1, keep)
		pool += absorb if idx == 0 else absorb * 0.5
		if idx == 0:
			# 前排：防/闪取面板那一份（含装备/宠物/羁绊/星/专武），与 battle_lite 的建队口径一致
			front_def = float(eff.get("def", 5)) + float(tfx.get("def", 0))
			front_dodge = float(eff.get("dodge", 5)) + float(tfx.get("dodge", 0))
			front_atk = float(eff.get("atk", 8))
		idx += 1
	return {
		"dps": maxf(1.0, dps), "hp": maxf(1.0, pool), "cut": 0.0,
		"def": maxf(0.0, front_def), "dodge": maxf(0.0, front_dodge), "atk": maxf(0.0, front_atk),
	}

# ============================================================
# v143：**追剿的后台 / 离线推进**（用户："追缴无法离线和后台"）
#
#   爬塔那条路早就有（_idle_climb → run_offline_climb）；追剿从 v129 起是**故意藏着**的
#   （battle_lite 的［回村·后台继续］在追剿里根本不显示）。这一版按同一套口径补齐：
#     · 触发：`chase_auto` 开着 · 人不在战斗里（battle_live / _battle_seen）· 还有下一关；
#       节奏跟爬塔同一条闸（`CLIMB_MIN_SEC`＝每 20 秒一拍）；
#     · 判定：走 `Tower.run_offline`（与塔共用"血池 / 输出 / 每关耗时"那一套估算），
#       倍率默认 **1.0（与爬塔同口径）**。`CHASE_BG_HAIRCUT` 是留给"想让它保守一点"的旋钮：
#       调 0.9 之类的话，**boss 关会卡住**（实测：一支刚够打的队伍在 0.9 下正好卡在每个 boss 关，
#       于是后台每推 4 关就要你回来打一口）——想挂着刷就别动它。
#       ⚠ 估算看不到 boss 的特性＋专属被动（号令/背水/护体罡气…），所以后台推 boss 关偏乐观；
#         这是"挂机估算"这条线一贯的粗法（爬塔那边同理）。
#     · 清关仍走 `chase_clear()`：银两 / 经验 / 2 个宝箱 / boss 关那件整品照发；
#     · 汇总那一行并进 `offline_note`——回村时与挂机那条一起报（同一个 toast）。
# ============================================================
const CHASE_BG_HAIRCUT := 1.0       # 估算倍率（1.0＝与爬塔同口径；调小会让 boss 关卡住）
static var chase_bg := false        # 人在村里、追剿连打交给后台估算（与塔的 auto_bg 对称）
static var chase_last_gift := ""    # 上一次 chase_clear 给的整品（后台汇总用）

# 后台估算最远推到哪一关之前（追剿现在没有"必须真打"的关卡——以后加剧情就返回它前一关）
static func chase_gate() -> int:
	return Chase.STAGE_MAX

static func _idle_chase(elapsed: int) -> void:
	if elapsed < CLIMB_MIN_SEC or chase_progress >= Chase.STAGE_MAX:
		return
	if not chase_auto:
		return
	if battle_live or _battle_seen:
		return
	if chase_progress >= chase_gate():
		return
	run_offline_chase(float(elapsed))

# 跑一次追剿的后台推进（在线挂机与离线开局走的是同一条路）。返回结果字典。
static func run_offline_chase(seconds: float) -> Dictionary:
	if seconds <= 0.0 or chase_progress >= Chase.STAGE_MAX:
		return {}
	var est := formation_dps_est()
	var clear_one := func(i: int) -> Variant:
		var before := chase_progress
		if not chase_clear(i, false):
			return null
		if chase_progress == before:
			return null
		return {
			"silver": Chase.reward_silver(i),
			"exp": Chase.reward_exp(i),
			"gift": chase_last_gift != "",
		}
	var r: Dictionary = Tower.run_offline(chase_progress, seconds,
		float(est["dps"]) * CHASE_BG_HAIRCUT, float(est["hp"]) * CHASE_BG_HAIRCUT, float(est["cut"]),
		clear_one, func(i: int) -> Dictionary: return chase_enemy_at(i), chase_gate(),
		float(est.get("def", 0.0)), float(est.get("dodge", 0.0)), float(est.get("atk", 0.0)))
	if r.is_empty():
		return {}
	var n := int(r.get("cleared", 0))
	if n <= 0:
		return r
	var line := "追剿（后台）：推进 " + str(n) + " 关，到第 " + str(int(r.get("stage", 0)) + 1) + " 关"
	if int(r.get("gifts", 0)) > 0:
		line += "（boss 赏 " + str(int(r.get("gifts", 0))) + " 件）"
	if bool(r.get("stuck", false)):
		line += "——这一关估算过不去，回来自己打"
	elif int(r.get("stage", 0)) >= Chase.STAGE_MAX:
		line += "——追剿清净了"
	offline_note = (offline_note + "｜" + line) if offline_note != "" else line
	save_game()
	print("[挂机] 追剿后台推进：", r)
	return r

# 跑一次离线爬塔。返回结果字典（无进展时 cleared=0）。
static func run_offline_climb(seconds: float) -> Dictionary:
	if seconds <= 0.0 or stage_progress >= STAGE_MAX:
		return {}
	var est := formation_dps_est()
	var clear_one := func(i: int) -> Variant:
		# 走正式结算：银两/经验/首领赏都照发；失败就返回 null 让塔停下
		if not stage_clear(i):
			return null
		return {
			"silver": stage_silver(i) + (boss_silver_gain(i) if is_boss(i) else 0),
			"exp": stage_exp_gain(i),
			"gift": last_stage_gift != "",
		}
	var r: Dictionary = Tower.run_offline(stage_progress, seconds, float(est["dps"]), float(est["hp"]), float(est["cut"]), clear_one, Callable(enemy_at), climb_gate(), float(est.get("def", 0.0)), float(est.get("dodge", 0.0)), float(est.get("atk", 0.0)))
	if r.is_empty():
		return {}
	offline_note = Tower.offline_line(r)
	# 挂了多久、推了多少，写清楚（回村播报 + 控制台）
	if int(r.get("cleared", 0)) > 0:
		offline_note += "（离线 " + str(int(seconds / 60.0)) + " 分 · 银两 +" + str(int(r.get("gold", 0))) + " · 经验 +" + str(int(r.get("exp", 0))) + "）"
		if int(r.get("gifts", 0)) > 0:
			offline_note += "｜首领赏 " + str(int(r.get("gifts", 0))) + " 件"
		save_game()
	print("[挂机] 离线 ", int(seconds), " 秒：", r)
	return r

static func idle_sync() -> void:
	var now := _idle_now()
	var elapsed := now - _idle_last_ts
	idle_absorb(elapsed)
	_idle_last_ts = now
	_idle_save()
	# ㊼：在线挂机也推塔（与离线同一条路）——菜单每 20 秒一拍会调到这里
	_idle_climb(elapsed)
	# v143：追剿那条线同理（用户："追缴无法离线和后台"）
	_idle_chase(elapsed)

static func idle_display_sec() -> int:
	var extra := maxi(0, _idle_now() - _idle_last_ts)
	return mini(idle_pool_sec + extra, IDLE_CAP_SEC)

static func idle_pool_min() -> int:
	return idle_pool_sec / 60

static func idle_tier() -> int:
	# ============================================================
	# v62n（用户："挂机不封顶 需求档位越来越大 档位可以按照100/1档算
	#   1000关后 按照250/1算 挂机倍率降低30%"）：
	#   · **前 1000 关：每 100 关一档**（第 1~100 关＝0 档，101~200＝1 档…）
	#   · **1000 关之后：每 250 关一档**（越往上档位涨得越慢＝需求档位越来越大）
	#   · **不再封顶**（原来 clampi 到 STAGE_MAX/IDLE_STEP ≈ 10 档，
	#     600 关以后挂机一分不涨 ✗ —— 现在推到哪一档就吃哪一档）
	#   连续性：第 1000 关正好是第 10 档，两条斜率在这里接上，不会跳档。
	# ============================================================
	var s := maxi(0, stage_progress)
	if s <= IDLE_TIER_SWITCH:
		return s / IDLE_STEP
	return IDLE_TIER_SWITCH / IDLE_STEP + (s - IDLE_TIER_SWITCH) / IDLE_STEP_LATE

static func idle_silver_per_min() -> int:
	# 显示用（整数）：真实速率见 idle_silver_rate()
	return maxi(1, int(round(idle_silver_rate())))

static func idle_silver_rate() -> float:
	# v61（用户："降低70%银两"）：挂机银两也 ×0.3（与清关/首领/宝箱同一个口径）。
	#   ⚠ 走**浮点**：低档时 1×0.3＝0.3，若直接用整数会在前两档被抹成 0（等于白挂）
	#   ——结算时按"分钟数 × 这个速率"算，攒够 1 两才入账。
	# v62n：再挂上 IDLE_RATE_MUL（0.7）——"挂机倍率降低 30%"
	return float(IDLE_SILVER_PER_MIN + idle_tier()) * 0.225 * IDLE_RATE_MUL

static func idle_action_per_10min() -> int:
	return 1 + idle_tier() / 2

static func idle_exp_per_min() -> int:
	# 显示用；真实速率见 idle_exp_rate()
	return maxi(1, int(round(idle_exp_rate())))

static func idle_exp_rate() -> float:
	# v61（用户："经验收益降低40%"）：×Tower.EXP_INCOME_MUL（0.6），同样走浮点
	# v62n：再挂 IDLE_RATE_MUL（0.7）——挂机倍率降低 30%
	# v80：经验这条 ×1.2（用户：「挂机的经验收益提高20%」）
	return float(IDLE_EXP_PER_MIN + idle_tier() * 2) * Tower.EXP_INCOME_MUL * IDLE_RATE_MUL * IDLE_EXP_MUL

static func idle_rate_text() -> String:
	# v62n：档位说明跟着两条斜率走（前 100 关一档 / 1000 关后 250 关一档、不封顶）
	var tier_note := ""
	if stage_progress <= IDLE_TIER_SWITCH:
		tier_note = "每清 " + str(IDLE_STEP) + " 关涨一档"
	else:
		tier_note = str(IDLE_TIER_SWITCH) + " 关后每 " + str(IDLE_STEP_LATE) + " 关涨一档（不封顶）"
	return "银两 " + str(idle_silver_per_min()) + "/分 · 食物 " + str(idle_action_per_10min()) + "/10分 · 经验 " + str(idle_exp_per_min()) + "/分 · 阅历 " + str(snappedf(insight_rate(), 0.1)) + "/分（第 " + str(idle_tier() + 1) + " 档；" + tier_note + "）"

static func idle_collect() -> Dictionary:
	idle_sync()
	var mins := idle_pool_sec / 60
	# v61：两条速率都走浮点（见 idle_silver_rate / idle_exp_rate），保证正好 −70% / −40%
	var silver := int(round(float(mins) * idle_silver_rate()))
	var exp_each := int(round(float(mins) * idle_exp_rate()))
	if silver > 0:
		add_coin("silver", silver)
	# ㊾：经验进池——总量照原口径（每人一份 × 上阵人数）；给谁由你在弟子面板分配
	var exp_total := exp_each * formation.size()
	if exp_total > 0:
		exp_pool += exp_total
	# v64b：阅历——与银两/经验同一个池、同一口收取（用户："挂机给阅历值 · 吃挂机档位"）
	var ins := int(round(float(mins) * insight_rate()))
	insight_add(ins)
	# v242：行动资源也进挂机池（10 分钟 1 点起，吃塔档位；上限 ACTION_MAX）
	var act := mini(ACTION_MAX - action, (mins / 10) * idle_action_per_10min())
	if act > 0:
		action += act
	idle_pool_sec = 0
	_idle_save()
	return {"minutes": mins, "silver": silver, "action": act, "exp": exp_total, "exp_pool": exp_pool, "insight": ins}

# ============================================================
# v64b：**阅历线**的账（唯一真源＝shared/data_insight.gd；这里只管"攒/花/并进属性"）
# ============================================================

# 每分多少阅历——**吃挂机档位**（用户点名）：0 档 1/分，每高一档 +0.5
static func insight_rate() -> float:
	# v109（用户："可"——采纳"挂机系数 0.5 → 0.8"）：
	#   老兵一句：挂机从 1/分 涨到 24/分要 **10,000 关**，而阅历线后段一组就要 6,660 ✗
	#   两条曲线不匹配（早段靠游历扛得住，后段只能干挂）。0.5 → 0.8 让挂机跟上成长：
	#     10 档（1000 关）6 → **9/分** · 26 档（5000 关）14 → **21.8/分**
	return 1.0 + float(idle_tier()) * 0.8

static func insight_add(n: int) -> void:
	if n > 0:
		insight += n

# 已升的那些段合起来给什么（fx 键见 data_insight 文件头）
static func insight_fx() -> Dictionary:
	return Insight.fx_of_levels(insight_lv)

static func insight_lv_of(bid: String) -> int:
	return clampi(int(insight_lv.get(bid, 0)), 0, Insight.max_lv(bid))

static func insight_cost(bid: String) -> Dictionary:
	return Insight.cost_next(bid, insight_lv_of(bid))

# 能不能升下一段（顺带给一句人话）
static func insight_can(bid: String) -> Dictionary:
	if Insight.branch_of(bid).is_empty():
		return {"ok": false, "msg": "没有这一支"}
	var lv := insight_lv_of(bid)
	if lv >= Insight.max_lv(bid):
		return {"ok": false, "msg": "「" + str(Insight.branch_of(bid).get("name", bid)) + "」已经走满了"}
	var c := insight_cost(bid)
	if insight < int(c.get("insight", 0)):
		return {"ok": false, "msg": "阅历不够：还差 " + str(int(c["insight"]) - insight) + " 点"}
	if coin("silver") < int(c.get("silver", 0)):
		return {"ok": false, "msg": "银两不够：还差 " + str(int(c["silver"]) - coin("silver")) + " 两"}
	return {"ok": true, "msg": ""}

static func insight_upgrade(bid: String) -> Dictionary:
	var can := insight_can(bid)
	if not bool(can.get("ok", false)):
		return can
	var lv := insight_lv_of(bid)
	var nd := Insight.node_next(bid, lv)
	var c := insight_cost(bid)
	insight -= int(c.get("insight", 0))
	add_coin("silver", -int(c.get("silver", 0)))
	insight_lv[bid] = lv + 1
	save_game()
	var b := Insight.branch_of(bid)
	print("[阅历] ", b.get("name", bid), " 第 ", lv + 1, " 段「", nd.get("name", ""), "」——", nd.get("desc", ""))
	return {"ok": true, "msg": "「" + str(b.get("name", bid)) + "·" + str(nd.get("name", "")) + "」已通——" + str(nd.get("desc", ""))}

# 洗点（用户："要 但是消耗银两"）：**退全部阅历**、收手续费（每级 200 两），银两不退
static func insight_respec_cost() -> int:
	return Insight.total_lv(insight_lv) * Insight.RESPEC_SILVER_PER_LV

static func insight_respec() -> Dictionary:
	var lv := Insight.total_lv(insight_lv)
	if lv <= 0:
		return {"ok": false, "msg": "还没点过阅历——没什么可洗的"}
	var fee := insight_respec_cost()
	if coin("silver") < fee:
		return {"ok": false, "msg": "洗点要 " + str(fee) + " 两（现有 " + str(coin("silver")) + "）"}
	add_coin("silver", -fee)
	var back := Insight.spent_insight(insight_lv)
	insight += back
	insight_lv = {}
	save_game()
	print("[阅历] 洗点：退回阅历 ", back, " 点，花 ", fee, " 两")
	return {"ok": true, "msg": "已洗点——退回阅历 " + str(back) + " 点（花 " + str(fee) + " 两手续费；银两不退）"}

# 把阅历线并进**一份游历属性**（run_state.stats_of 的最后一道；村里那份不走这里）
static func insight_apply_to(st: Dictionary) -> void:
	var fx := insight_fx()
	if fx.is_empty():
		return
	# 顺序：**先加平面、再乘百分比**（用户："小节点给数值，大节点数值+百分比"）
	st["atk"] = (float(st.get("atk", 0.0)) + float(fx.get("atk_flat", 0.0))) * (1.0 + float(fx.get("atk_pct", 0.0)))
	st["hp"] = (float(st.get("hp", 0.0)) + float(fx.get("hp_flat", 0.0))) * (1.0 + float(fx.get("hp_pct", 0.0)))
	# v2i：防御也吃一道百分比（用户："防御加成"）——先加平面、再乘百分比，与攻击/气血同序
	st["def"] = (float(st.get("def", 0.0)) + float(fx.get("def_flat", 0.0)) + float(fx.get("def_add", 0.0))) 		* (1.0 + float(fx.get("def_pct", 0.0)))
	st["dodge"] = float(st.get("dodge", 0.0)) + float(fx.get("dodge_flat", 0.0)) + float(fx.get("dodge_add", 0.0))
	st["spd"] = float(st.get("spd", 0.0)) + float(fx.get("spd_add", 0.0))
	st["crit"] = float(st.get("crit", 0.0)) + float(fx.get("crit_add", 0.0))
	st["crit_dmg"] = float(st.get("crit_dmg", 0.0)) + float(fx.get("crit_dmg_add", 0.0))
	# 伤害增幅（dmg 在引擎里就是"百分点"：面板 ×(1 + dmg/100)）——
	#   表里写 0.04 表示 +4%
	st["dmg"] = float(st.get("dmg", 0.0)) + float(fx.get("dmg_add", 0.0)) + float(fx.get("dmg_pct", 0.0)) * 100.0

static func idle_debug_add(sec: int) -> void:
	idle_pool_sec = mini(idle_pool_sec + sec, IDLE_CAP_SEC)
	_idle_last_ts = _idle_now()
	_idle_save()

static func _idle_save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("idle", "pool_sec", idle_pool_sec)
	cf.set_value("idle", "last_ts", _idle_last_ts)
	cf.save(IDLE_CFG)

static func idle_touch() -> void:
	idle_sync()

static func idle_claim() -> Dictionary:
	return idle_collect()

# ---- 游历回村 ----

static func finish_journey() -> void:
	first_journey_done = true
	# v40：**引子下山通关那一下**，仓库里塞一只「新手关卡礼包」（测试版的专武来路）
	note_push(grant_stage_gift())

# v40：回村播报是"一条串"——以前各处直接 `pending_note = "..."`，后写的会把先写的吃掉
#   （引子那趟就是：先记了礼包，紧接着"回到村子…"把它覆盖了）。以后一律走这一口。
static func note_push(s: String) -> void:
	if s == "":
		return
	pending_note = s if pending_note == "" else pending_note + "｜" + s

static func broker_rank_name() -> String:
	if broker_rep >= 90:
		return "楼主"
	if broker_rep >= 60:
		return "贵客"
	if broker_rep >= 30:
		return "熟客"
	return "生客"

static func ng_mul() -> float:
	return 1.0 + 0.15 * float(ng_plus)

static func tier_for_prosperity(points: int) -> int:
	var t := 1
	for i in PROSPERITY_STEPS.size():
		if points >= int(PROSPERITY_STEPS[i]):
			t = i + 1
	return t

static func prosperity_need(tier: int) -> int:
	return int(PROSPERITY_STEPS[clampi(tier - 1, 0, 4)])

static func add_prosperity(n: int, reason := "") -> void:
	var old := world_tier
	world_prosperity = maxi(0, world_prosperity + n)
	world_tier = tier_for_prosperity(world_prosperity)
	if world_tier > old:
		note_push("世界繁荣：第 " + str(world_tier) + " 档" + ("（" + reason + "）" if reason != "" else ""))

static func region_cost(i: int) -> int:
	return int(REGION_COSTS[clampi(i, 0, 4)])

static func region_unlocked_at(i: int) -> bool:
	var idx := clampi(i, 0, 4)
	if idx >= region_unlocked.size():
		return false
	return bool(region_unlocked[idx])

static func world_has(kind: String, key: String) -> bool:
	var w: Dictionary = world_flags.get(str(world_seed), {})
	var arr: Array = w.get(kind, [])
	return arr.has(str(current_region) + "|" + key)

static func world_mark(kind: String, key: String) -> void:
	var sk := str(world_seed)
	var w: Dictionary = world_flags.get(sk, {})
	var arr: Array = w.get(kind, [])
	var kk := str(current_region) + "|" + key
	if not arr.has(kk):
		arr.append(kk)
	w[kind] = arr
	world_flags[sk] = w

static func world_clear() -> void:
	world_flags.clear()

static func map_owner_of(seed: int) -> int:
	return clampi(int(map_owners.get(str(seed), 0)), 0, 3)

static func set_map_owner(seed: int, owner: int) -> void:
	map_owners[str(seed)] = clampi(owner, 0, 3)

static func cycle_title() -> String:
	if ng_plus <= 0:
		return "初入江湖"
	if ng_plus == 1:
		return "轮回客"
	if ng_plus == 2:
		return "两世客"
	if ng_plus == 3:
		return "三生客"
	return "百世客"

static func begin_new_cycle() -> void:
	ng_plus = mini(99, ng_plus + 1)
	map_owners.clear()
	world_flags.clear()
	world_prosperity = 0
	world_tier = 1
	time_slot = 0
	time_day = 1
	slot_progress = 0
	region_rep = [0, 0, 0, 0, 0]
	region_seen = [false, false, false, false, false]
	region_walk = [0, 0, 0, 0, 0]
	merchant_stock_slot = ""
	merchant_stock.clear()
	npc_stock.clear()
	region_landmarks.clear()
	npc_budget = -1
	sect_prosperity_rank = 0
	forge_names.clear()
	story_title_prosperity = false
	ng_event_seen = false
	ng_event_choice = -1
	ng_echo_seen = false
	ng_final_seen = false
	ng_final_choice = -1
	ng_wuxia_done = false
	current_region = 0
	region_unlocked = [true, true, true, false, false]
	world_seed += 1
	red_water = 0
	red_water_wall = false
	red_water_market = false
	red_water_garrison = false
	red_water_taxpost = false
	red_water_peace = false
	war_score = 0
	turf_tax_day = ""
	north_score = 0
	north_peace = false
	north_garrison = false
	north_wins = 0
	north_tax_day = ""
	story_letter = 0
	story_follow = 0
	broker_rep = 0
	broker_quest = 0
	broker_pardon = false
	boss_kills.clear()
	wanted = 0
	jailed_days = 0
	action = ACTION_MAX
	war_notes.clear()
	save_game()

static func note_war(s: String) -> void:
	if s == "":
		return
	var ts := Time.get_datetime_string_from_system()
	if ts.length() >= 16:
		ts = ts.substr(5, 11).replace("T", " ")
	war_notes.append(ts + " · " + s)
	while war_notes.size() > 12:
		war_notes.pop_front()

# ============================================================
# v40：**新手关卡礼包**（测试版）
#   用户："引子下山通关后额外在仓库塞入一个新手关卡礼包，50 关获取一本主角专武功法、
#          150 关陈石专武功法、300 关苏专武功法，一共可以开三次。"
#   一只礼包、按关号分三次开（表在 Stars.EXCLUSIVE_STAGE）；开出来的是**专武成品**
#   （三门 art_ex_* 都是 no_drop——这是它们目前唯一的来路）。
#   账两个字段：`stage_gift_got`（到手没有）、`stage_gift_opened`（开了几次 0~3）。
#   ⚠ 正式来路定了之后，把 grant 那一下挪走即可；面板读的是"还能不能开"，不用改。
# ============================================================
static var stage_gift_got := false
static var stage_gift_opened := 0

static func stage_gift_total() -> int:
	return Stars.EXCLUSIVE_STAGE.size()

# 下一次该开哪一门（三次都开完回 {}）
static func stage_gift_next() -> Dictionary:
	if stage_gift_opened >= stage_gift_total():
		return {}
	var e: Dictionary = Stars.EXCLUSIVE_STAGE[clampi(stage_gift_opened, 0, stage_gift_total() - 1)]
	return e

# 下一格的"要到第几关 / 给谁 / 是哪一门功法"——面板与提示都读这一份
static func stage_gift_next_line() -> String:
	var nxt := stage_gift_next()
	if nxt.is_empty():
		return "三次都开完了"
	var stage := int(nxt.get("stage", 0))
	var art := Stars.exclusive_art(str(nxt.get("role", "")))
	var who := str(Stars.ROLE_CN.get(str(nxt.get("role", "")), "?"))
	return ("第 " + str(stage) + " 关开出「" + Cards.item_name(art) + "」（" + who + "的专武）"
		+ ("——还差 " + str(stage - stage_progress) + " 关" if stage_progress < stage else "——现在就能开"))

static func stage_gift_can() -> Dictionary:
	if not stage_gift_got:
		return {"ok": false, "msg": "礼包还没到手（引子下山通关那一下给）"}
	if stage_gift_opened >= stage_gift_total():
		return {"ok": false, "msg": "礼包三次都开完了"}
	var nxt := stage_gift_next()
	var stage := int(nxt.get("stage", 0))
	if stage_progress < stage:
		return {"ok": false, "msg": "还差 " + str(stage - stage_progress) + " 关——到第 " + str(stage) + " 关才能开这一格"}
	return {"ok": true, "msg": ""}

static func stage_gift_open() -> Dictionary:
	var chk := stage_gift_can()
	if not bool(chk.get("ok", false)):
		return {"ok": false, "msg": str(chk.get("msg", ""))}
	var nxt := stage_gift_next()
	var art := Stars.exclusive_art(str(nxt.get("role", "")))
	if art == "":
		return {"ok": false, "msg": "这一格还没配好（表里查不到功法）"}
	vault_add_item(art, 1)
	mark_collected(art)
	stage_gift_opened += 1
	save_game()
	var left := stage_gift_total() - stage_gift_opened
	var msg := "「新手关卡礼包」开出「" + Cards.item_name(art) + "」（" + Cards.quality_of(art) + "）——已放进仓库"
	msg += "，还能开 " + str(left) + " 次" if left > 0 else "，三次都开完了"
	print("[账本] 新手关卡礼包：", msg)
	return {"ok": true, "msg": msg, "art": art}

# 引子通关那一下调它（重复调不会重复给）
static func grant_stage_gift() -> String:
	if stage_gift_got:
		return ""
	stage_gift_got = true
	var msg := "仓库里多了一只「新手关卡礼包」——" + Stars.exclusive_stage_line() + "，一共能开三次"
	print("[账本] ", msg)
	return msg

static func take_pending_note() -> String:
	var s := pending_note
	pending_note = ""
	return s

# ---- 仓库残卡 ----

static func vault_deposit(counts: Dictionary) -> int:
	var n := 0
	for sid_key in counts.keys():
		var sid := str(sid_key)
		var parts: Dictionary = counts[sid_key]
		var bucket: Dictionary = vault_cards.get(sid, {})
		for p_key in parts.keys():
			var p := int(p_key)
			var c := int(parts[p_key])
			bucket[p] = int(bucket.get(p, 0)) + c
			n += c
		vault_cards[sid] = bucket
	return n

static func vault_total() -> int:
	var n := 0
	for sid in vault_cards.keys():
		var bucket: Dictionary = vault_cards[sid]
		for p in bucket.keys():
			n += int(bucket[p])
	return n

static func vault_item_total() -> int:
	var n := 0
	for sid in vault_items.keys():
		n += int(vault_items[sid])
	return n

static func vault_count(sid: String, part: int) -> int:
	if not vault_cards.has(sid):
		return 0
	var bucket: Dictionary = vault_cards[sid]
	return int(bucket.get(part, 0))

# ---- R3 角色碎片：搜刮带出，通关入账（升星系统未开，先只记账） ----
# 名字键与 shared/data_loot.gd 的 FRAGMENTS 对齐（那边管搜刮显示，这边管入账/查询）。
const FRAGMENT_CN := {"frag_player": "少侠碎片", "frag_chen": "陈石碎片", "frag_qing": "苏青鸾碎片"}
static var fragments := {}

static func fragment_name(fid: String) -> String:
	return str(FRAGMENT_CN.get(fid, fid))

static func add_fragment(fid: String, n := 1) -> int:
	fragments[fid] = int(fragments.get(fid, 0)) + n
	return int(fragments[fid])

static func fragment_count(fid: String) -> int:
	return int(fragments.get(fid, 0))

# ---- 合成（唯一来源 · v21）：仓库、游历、村内合成台共用 ----
# 游历那边的旧合成码先不动（R1 迁移到这个口子）；仓库里的合成按钮按 R5 合成台走。

# 还缺哪几页（返回页号数组；空 = 齐了）
static func synth_missing(sid: String) -> Array:
	var parts: Array = Cards.parts_of(sid)
	var miss: Array = []
	for i in parts.size():
		if vault_count(sid, i) <= 0:
			miss.append(i)
	return miss

static func can_synthesize(sid: String) -> bool:
	if Cards.by_id(sid).is_empty():
		return false
	return synth_missing(sid).is_empty()

# 合一套：各吃一页 → 成品进仓库，并登记收集。返回 {ok, msg}
static func synthesize(sid: String) -> Dictionary:
	if Cards.by_id(sid).is_empty():
		return {"ok": false, "msg": "没有这一套（数据表里查不到）"}
	var parts: Array = Cards.parts_of(sid)
	var miss := synth_missing(sid)
	if not miss.is_empty():
		var arr: Array = []
		for i in miss:
			arr.append(str(parts[i]))
		return {"ok": false, "msg": "还缺：" + "、".join(PackedStringArray(arr))}
	for i in parts.size():
		vault_cards[sid][i] = vault_count(sid, i) - 1
	vault_add_item(sid, 1)
	mark_collected(sid)
	return {"ok": true, "msg": "合成「" + Cards.item_name(sid) + "」——收进仓库（已记收集）"}

# ---- 游历收集（journey.cfg · v21）：合成过至少一件即登记 ----
# v28：降为"合成纯记录"——卡池改难度驱动（见上面 R4 段），册子不再推任何东西。

const JOURNEY_CFG := "user://journey.cfg"
static var collected := {}        # sid -> true
static var _collected_loaded := false

static func _collected_sync() -> void:
	if _collected_loaded:
		return
	_collected_loaded = true
	var cf := ConfigFile.new()
	if cf.load(JOURNEY_CFG) == OK:
		var d: Variant = cf.get_value("collect", "sets", {})
		if typeof(d) == TYPE_DICTIONARY:
			collected = d

static func _collected_save() -> void:
	var cf := ConfigFile.new()
	cf.load(JOURNEY_CFG)
	cf.set_value("collect", "sets", collected)
	cf.save(JOURNEY_CFG)

static func mark_collected(sid: String) -> void:
	_collected_sync()
	if collected.has(sid):
		return
	collected[sid] = true
	_collected_save()
	print("[账本] 收集 +1：", sid, "（共 ", collected.size(), "）")

static func is_collected(sid: String) -> bool:
	_collected_sync()
	return collected.has(sid)

static func collected_total() -> int:
	_collected_sync()
	return collected.size()

# ---- R4 卡池换届：难度驱动 ----
# 规矩：每"首次通关一档"换一手（奇手兵器、偶手武学交替；引子趟/重刷不推进）。
# 换手表在 data_cards.LADDER_CHAIN；越阶红＝现役阶段 +1~2 品（封顶绝）。
static func ladder_clears() -> int:
	_diff_sync()
	return diff_cleared.size()

# 当前阶段品级：0=未通(凡池) 1=良 2=上 3=极 4=绝（每 8 手升一段）
static func ladder_phase() -> int:
	# v101：品级＝主轴——返回**最高已解锁的那一品**（0 凡 / 1 良 / 2 上 / 3 极）。
	#   绝品（4）不再是"一档"，只作越阶红的落点（见 data_ladder.COLOR_OFFSET）。
	_diff_sync()
	var top := 0
	for i in PHASES.size():
		if phase_unlocked(i):
			top = i
	return top

static func ladder_swaps(pool: String) -> int:
	var c := ladder_clears()
	if pool == "weapon":
		return (c + 1) / 2
	if pool == "arts":
		return c / 2
	return 0

# 现役卡池——事件/货郎/补齐/村货栈/搜刮"普通"一律从这里出
static func pool_active(pool: String) -> Array:
	# ㉛：装备池转发给 pool_gear()——以前这里自己拼了一份"三池合一、不限品级"，
	#   和 pool_gear() 的"按阶段限品级"是两套口径，容易走岔（精英三抽就栽在这上面）。
	#   现在只有 pool_gear() 一个源。
	if pool == "gear":
		return pool_gear()
	if not Cards.LADDER_CHAIN.has(pool):
		return Cards.pool_sets(pool)
	return Cards.ladder_sets(pool, ladder_swaps(pool))

# ㊽：装备池——护甲/玉佩/披风三池合一。装备不上阶梯，品级闸借 ladder_phase：
# 阶段 0 只出凡品（皮甲/青玉佩/旧披风）；首通越多开越高，**封顶极品**
#   （v137 起装备也有绝品了，但那三件只从"龙箱绝品残片 / 搜刮越阶红"出，正路池子不开）
static func pool_gear() -> Array:
	var top: int = mini(ladder_phase(), 3)
	var out: Array = []
	for gp_v in ["armor", "helm", "cloak"]:
		out.append_array(Cards.pool_sets(str(gp_v), top))
	return out

# ㊽：货栈"残卡"取池口——普通池走现役卡池；装备（pool="gear"）走三池合一
static func shop_pool_of(pool: String) -> Array:
	if pool == "gear":
		return pool_gear()
	return pool_active(pool)

# ============================================================
# ㉛ "选卡"统一闸（事件三选一 / 精英三抽×3 / 货郎货架 / 补齐 都走这里）
#
# 修之前有个漏洞：精英三抽的装备分支直接调 Cards.pool_sets("armor")，
#   而那个函数的 max_q 默认是 4＝**全品级全开**，于是"选一件"这条路上
#   能直接摸到极品装备，完全绕过品级闸；同一时期的货郎却按 pool_gear()
#   只到上品——两条路口径不一致。
#
# 现在的规矩（"越阶"只有一个来源）：
#   · 选卡（事件/精英三抽/货摊/补齐）→ 只出 <= 现阶段的品级
#   · 搜刮（loot）→ 走 pool_red，允许越阶 1~2 品 —— 越阶只此一条路
# 品级由 ladder_phase() 定（每 8 次首通升一段），装备封顶极品（装备无绝品）。
# ============================================================
static func pick_pool(pool: String) -> Array:
	if pool == "gear":
		return pool_gear()
	return pool_active(pool)

# 越阶"红"池——现役阶段 +1~2 品（封顶绝）；阶段到顶后＝必绝。
# 红池为空时（内容缺档）调用方按不红处理。
static func pool_red(pool: String) -> Array:
	var top := Cards.QUALITY_ORDER.size() - 1
	var lo: int = mini(top, ladder_phase() + 1)
	var hi: int = mini(top, ladder_phase() + 2)
	return Cards.ladder_red_sets(pool, lo, hi)

# 一行摘要（M 自检/控制台）
static func pool_line(pool: String) -> String:
	var act: Array = pool_active(pool)
	var names: Array = []
	for sid_v in act:
		names.append(str(Cards.name_of(str(sid_v))))
	var s := ladder_swaps(pool)
	var at_end: bool = Cards.LADDER_CHAIN.has(pool) and s > Cards.ladder_start(pool, s)
	var tail := "" if not at_end else "（链到头·等补内容）"
	return str(Cards.QUALITY_ORDER[ladder_phase()]) + "阶段 已换" + str(s) + "手" + tail + " · 现役：" + "/".join(PackedStringArray(names))

# R4 批②补：红池一行摘要（M 自检用；"空"＝该阶段没内容——内容满编后不该再出现）
static func pool_red_line(pool: String) -> String:
	var names: Array = []
	for sid_v in pool_red(pool):
		names.append(str(Cards.name_of(str(sid_v))))
	if names.is_empty():
		return "红（越阶）：空"
	return "红（越阶）：" + "/".join(PackedStringArray(names))
# ---- 游历难度（R1 · 存 journey.cfg 的 "diff" 段）----
# 状态：cleared 已清 / open 可打 / locked 未开。规矩：D1 恒开；前一档清了才开下一档；
# 输了不改状态（可重试）；已清的档出征屏不再列。
# ============================================================
# v101（用户："如果击败普通模式 即可解锁下一个品级 比如凡品普通过关 即可解锁良品难度
#   移除最高的绝品难度【最高极品】… 档位整体难度 按照凡品 良品 上品 极品 进行依次划分"）：
#   **品级＝难度主轴**（四档，绝品不再是一档）：凡品 → 良品 → 上品 → 极品，
#   每一品级下再分 简单/普通/困难（＝爆率与怪物那一档的倍率，在出征屏选）。
#   解锁：**通关上一品级的「普通」** 才开下一品级。
#   记档用 code = 品级×4 ＋ 模式 ＋ 1（所以 diff_cleared 里存的是这种编号，不再是老档 1~10）。
const PHASES := [
	{"name": "凡品", "diff": 1},   # 路程 21 节 · boss 852/32
	{"name": "良品", "diff": 3},   # 31 节 · 1515/53
	{"name": "上品", "diff": 6},   # 41 节 · 3115/102
	{"name": "极品", "diff": 8},   # 41 节 · 3582/114
]
const MODE_NORMAL := 1
static var deploy_code := 0        # 这一趟的品级×4＋模式＋1（结算按它记档）

static func phase_code(pi: int, mi: int) -> int:
	return clampi(pi, 0, PHASES.size() - 1) * 4 + clampi(mi, 0, 2) + 1

# 这一趟出征选的品级 / 模式（出征时交下来的编号里取）
static func deploy_phase() -> int:
	if deploy_code <= 0:
		return 0
	return clampi((deploy_code - 1) / 4, 0, PHASES.size() - 1)

static func deploy_mode() -> int:
	if deploy_code <= 0:
		return MODE_NORMAL
	return clampi((deploy_code - 1) % 4, 0, 2)

# v110（用户："货仓 档位从上品开始 当玩家打过上品到极品就按照极品档位算即可"）：
#   货仓（鉴宝行那些木箱/漆箱/铜锁/银扣/金匮）**只在两个档位之间走**：
#     没通关上品 → 按**上品**（phase 2，银扣仓露面）
#     通关上品了 → 按**极品**（phase 3，金匮仓露面）
#   也就是把进度相位夹到 [2, 3]——货仓不再有凡品/良品那两档。
static func hold_phase() -> int:
	return clampi(ladder_phase(), 2, 3)

# v110（用户："事件是通关上品解锁"）：事件卡系统的闸——**通关上品的「普通」**才开
static func event_unlocked() -> bool:
	return phase_cleared(2, MODE_NORMAL)

static func phase_name(pi: int) -> String:
	return str((PHASES[clampi(pi, 0, PHASES.size() - 1)] as Dictionary)["name"])

static func mode_name(mi: int) -> String:
	return ["简单", "普通", "困难"][clampi(mi, 0, 2)]

static func phase_unlocked(pi: int) -> bool:
	_diff_sync()
	if pi <= 0:
		return true
	if pi >= PHASES.size():
		return false
	# ① 永久保留的"打到过"（跨周也在）② 本周刚通关的上一品级「普通」
	return pi <= best_phase or diff_cleared.has(phase_code(pi - 1, MODE_NORMAL))

static func phase_cleared(pi: int, mi: int) -> bool:
	_diff_sync()
	return diff_cleared.has(phase_code(pi, mi))

const DIFF_MAX := 10
# 十档名字（改字只动这张表；整表空着则显示"第 N 程"）
# v62（用户："游历不用设置名称了 就当前游历难度1 然后打过了就2 以此类推 节省空间"）：
#   **十档不再取名**——表留空，diff_name() 一律回落到"难度 N"。
#   规矩也简化成一句话：**当前这一档打完，下一档自动开**（选路那块只列没走通的档）。
#   （原来那十个名字：风平浪静/山雨欲来/风起云涌/暗流涌动/刀光剑影/群凶环伺/龙潭虎穴/血雨腥风/九死一生/十死无生）
const DIFF_NAMES := []
static var diff_cleared := {}
# v103（用户："每周重置 如果打到三档上品 下次可以直接从三档开始【当然前面的关卡也能挑战】"）：
#   · **每周重置**：新的一周把"本周已通关"清空（首通奖励可以再拿一遍）；
#   · **最高品级永久留着**（best_phase）——下周直接从上品起挑，前面的品级照样能打。
static var diff_week := 0
static var best_phase := 0
static var _diff_loaded := false

# 周编号（Unix 时间 / 一周秒数）——不看时区，够用
static func _week_now() -> int:
	return int(Time.get_unix_time_from_system() / 604800.0)

# ============================================================
# v108（用户："玩家失败给阅历要加点限制…同一档反复失败：100% → 50% → 25% → 0（每天重置）"）：
#   失败阅历的**递减**——同一品级今天第 1 / 2 / 3 / 4+ 次殒命 → ×1.0 / ×0.5 / ×0.25 / ×0
#   （真正的"按完成度给"在 journey_settle.open_death 里算，这里只管次数）
# ============================================================
static var fail_day := 0
static var fail_count: Dictionary = {}      # 品级 → 今天失败了几次
static var _fail_loaded := false

static func _day_now() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

static func _fail_sync() -> void:
	if _fail_loaded:
		return
	_fail_loaded = true
	var cf := ConfigFile.new()
	if cf.load(JOURNEY_CFG) == OK:
		fail_day = int(cf.get_value("fail", "day", 0))
		var d: Variant = cf.get_value("fail", "count", {})
		if typeof(d) == TYPE_DICTIONARY:
			fail_count = d
	var now := _day_now()
	if fail_day != now:
		fail_count = {}
		fail_day = now
		_fail_save()

static func _fail_save() -> void:
	var cf := ConfigFile.new()
	cf.load(JOURNEY_CFG)
	cf.set_value("fail", "day", fail_day)
	cf.set_value("fail", "count", fail_count)
	cf.save(JOURNEY_CFG)

# 今天这一品级再失败一次，能拿几成（1.0 / 0.5 / 0.25 / 0）
static func fail_mul(pi: int) -> float:
	_fail_sync()
	var c := int(fail_count.get(clampi(pi, 0, PHASES.size() - 1), 0))
	if c <= 0:
		return 1.0
	if c == 1:
		return 0.5
	if c == 2:
		return 0.25
	return 0.0

static func fail_note(pi: int) -> void:
	_fail_sync()
	var k := clampi(pi, 0, PHASES.size() - 1)
	fail_count[k] = int(fail_count.get(k, 0)) + 1
	_fail_save()

static func _diff_sync() -> void:
	if _diff_loaded:
		return
	_diff_loaded = true
	var cf := ConfigFile.new()
	if cf.load(JOURNEY_CFG) == OK:
		var d: Variant = cf.get_value("diff", "cleared", {})
		if typeof(d) == TYPE_DICTIONARY:
			diff_cleared = d
		diff_week = int(cf.get_value("diff", "week", 0))
		best_phase = clampi(int(cf.get_value("diff", "best_phase", 0)), 0, PHASES.size() - 1)
	# v103：跨周了——清掉"本周已通关"，但最高品级留着
	var now := _week_now()
	if diff_week != now:
		if not diff_cleared.is_empty():
			print("[账本] 新的一周：游历通关记录重置（上周 ", diff_cleared.size(), " 档）；最高品级仍是「",
				str((PHASES[best_phase] as Dictionary)["name"]), "」")
		diff_cleared = {}
		diff_week = now
		_diff_save()

static func _diff_save() -> void:
	var cf := ConfigFile.new()
	cf.load(JOURNEY_CFG)
	cf.set_value("diff", "cleared", diff_cleared)
	cf.set_value("diff", "week", diff_week)
	cf.set_value("diff", "best_phase", best_phase)
	cf.save(JOURNEY_CFG)

static func diff_name(d: int) -> String:
	var i := clampi(d, 1, DIFF_MAX) - 1
	if i < DIFF_NAMES.size() and str(DIFF_NAMES[i]) != "":
		return str(DIFF_NAMES[i])
	# v62：表留空了，所以现在一律走这一句——"难度 N"，短、好扫、省地方
	return "难度 " + str(d)

static func diff_state(d: int) -> String:
	_diff_sync()
	if d <= 0 or d > DIFF_MAX:
		return "locked"
	if diff_cleared.has(d):
		return "cleared"
	if d == 1 or diff_cleared.has(d - 1):
		return "open"
	return "locked"

static func diff_is_cleared(d: int) -> bool:
	return diff_state(d) == "cleared"

static func diff_clear(d: int) -> void:
	_diff_sync()
	# v103：d 现在可能是"品级×4＋模式＋1"的编号（最大 16），不再只到 DIFF_MAX
	if d <= 0 or d > PHASES.size() * 4:
		return
	# v103：**每个难度只记一次首通**（用户："游历每个难度只能通关一次"）——
	#   已记过就直接返回，不重复记、也不再给首通换代那一弹。
	if diff_cleared.has(d):
		return
	diff_cleared[d] = true
	# 通关某品级的「普通」＝ 解锁下一品级——把它记进**永久**的最高品级里
	var mi: int = (int(d) - 1) % 4
	var pi: int = (int(d) - 1) / 4
	if mi == MODE_NORMAL and pi + 1 < PHASES.size():
		best_phase = maxi(best_phase, pi + 1)
	_diff_save()
	print("[账本] 通关已记：", diff_name(d), "（本周共 ", diff_cleared.size(), " 档 · 最高品级 ",
		str((PHASES[clampi(best_phase, 0, PHASES.size() - 1)] as Dictionary)["name"]), "）")
	print("[账本] 卡池换手：", pool_line("weapon"))
	print("[账本] 　　　　　：", pool_line("arts"))

static func diff_cleared_count() -> int:
	_diff_sync()
	return diff_cleared.size()

# 【测试用·上线前删】一键把前 n 档标记为已走通（出征屏 F9 键用；测第 5 档/命数解锁）
static func debug_clear_diffs(n: int) -> String:
	_diff_sync()
	var got: Array = []
	for d in range(1, mini(n, DIFF_MAX) + 1):
		if not diff_cleared.has(d):
			diff_cleared[d] = true
			got.append(diff_name(d))
	_diff_save()
	if got.is_empty():
		return "前 " + str(n) + " 档早就走通了（已走通 " + str(diff_cleared.size()) + " 档）"
	return "测试：已标记走通 " + "、".join(PackedStringArray(got)) + "——第 " + str(mini(n, DIFF_MAX) + 1) + " 档已开（命数随之解锁）"

# ---- 随行背包（优化批⑧/#2）：五档；capacity 对整趟生效（包裹＋临时仓库同享） ----
# need = 要先首通的难度档号；引子趟固定 8 格（由 run_state 管）。存 journey.cfg "pack" 段。
const BACKPACKS := [
	{"id": "cloth",   "name": "粗布囊",   "cap": 8,  "need": 0},
	{"id": "leather", "name": "皮褡裢",   "cap": 10, "need": 1},
	{"id": "rattan",  "name": "藤编行囊", "cap": 12, "need": 3},
	{"id": "oxhide",  "name": "牛皮大包", "cap": 14, "need": 6},
	{"id": "caravan", "name": "行商背箱", "cap": 16, "need": 10},
]
static var pack_id := "cloth"
static var _pack_loaded := false

static func _pack_sync() -> void:
	if _pack_loaded:
		return
	_pack_loaded = true
	var cf := ConfigFile.new()
	if cf.load(JOURNEY_CFG) == OK:
		var s := str(cf.get_value("pack", "id", "cloth"))
		if not backpack_find(s).is_empty():
			pack_id = s

static func _pack_save() -> void:
	var cf := ConfigFile.new()
	cf.load(JOURNEY_CFG)
	cf.set_value("pack", "id", pack_id)
	cf.save(JOURNEY_CFG)

static func backpack_find(id: String) -> Dictionary:
	for p in BACKPACKS:
		if str(p.get("id", "")) == id:
			return p
	return {}

static func backpack_of(id: String) -> Dictionary:
	var p := backpack_find(id)
	if p.is_empty():
		return BACKPACKS[0]
	return p

static func backpack_owned(id: String) -> bool:
	var p := backpack_find(id)
	if p.is_empty():
		return false
	var need := int(p.get("need", 0))
	if need <= 0:
		return true
	return diff_is_cleared(need)

static func backpack_id() -> String:
	_pack_sync()
	return pack_id

static func backpack_cap() -> int:
	return int(backpack_of(backpack_id()).get("cap", 8))

static func backpack_name() -> String:
	return str(backpack_of(backpack_id()).get("name", "粗布囊"))

static func set_backpack(id: String) -> String:
	var p := backpack_find(id)
	if p.is_empty():
		return "没有这个包"
	if not backpack_owned(id):
		return "「" + str(p.get("name", "")) + "」还没到手——首通「" + diff_name(int(p.get("need", 1))) + "」就能换"
	pack_id = id
	_pack_save()
	print("[账本] 换背包：", id, "（容量 ", int(p.get("cap", 8)), " 格）")
	return "换上「" + str(p.get("name", "")) + "」——本趟包裹与临时仓库同享 " + str(int(p.get("cap", 8))) + " 格"

static func backpack_line() -> String:
	var p := backpack_of(backpack_id())
	var have: Array = []
	for it in BACKPACKS:
		if backpack_owned(str(it.get("id", ""))):
			have.append(str(it.get("name", "")))
	return "当前「" + str(p.get("name", "")) + "」" + str(int(p.get("cap", 8))) + " 格 · 已到手：" + "/".join(PackedStringArray(have))

# ---- 出征交接（R1）：出征屏写、游历舞台读；读过即清（防串趟）----
static var deploy_role := ""
static var deploy_diff := 0
static var deploy_fate := ""   # ㉛：出征屏选的命数 id（"" = 空手走）——第一张（老读法兼容）
static var deploy_fates: Array = []   # v62r（用户："开局命数可多选"）：这一趟带的**全部**命数
static var deploy_party: Array = []   # ㊿：这趟同行的人（1~DEPLOY_MAX 个；第一个是领队）
# v99（出征屏三档：简单 0.5 / 普通 1.0 / 困难 2.0）：这一趟的怪物倍率与爆率倍率
static var deploy_foe_mul := 1.0
static var deploy_drop_mul := 1.0

# ㊿：整队出征。rids 可以是字符串（单人，老调用点照旧）或数组（1~3 人）。
#   deploy_role 记领队——存档里的 role_id 与"默认对谁操作"都用它。
# v62r（用户："开局命数可多选"）：fate 现在可以是字符串或**数组**（多选）。
static func deploy_set(rids, d: int, fate: Variant = "", foe_mul := 1.0, drop_mul := 1.0, code := 0) -> void:
	deploy_foe_mul = maxf(0.0, float(foe_mul))
	deploy_drop_mul = maxf(0.0, float(drop_mul))
	deploy_code = int(code)
	var list: Array = []
	if typeof(rids) == TYPE_ARRAY:
		for v in (rids as Array):
			var s := str(v)
			if s != "" and not list.has(s):
				list.append(s)
	else:
		var s1 := str(rids)
		if s1 != "":
			list.append(s1)
	if list.size() > DEPLOY_MAX:
		list = list.slice(0, DEPLOY_MAX)
	deploy_party = list
	deploy_role = str(list[0]) if not list.is_empty() else ""
	deploy_diff = maxi(1, d)
	# 命数：字符串/数组都收，统一成数组（顺带去掉空串与重复）
	var fl: Array = []
	if typeof(fate) == TYPE_ARRAY:
		for fv in (fate as Array):
			var fs := str(fv)
			if fs != "" and not fl.has(fs):
				fl.append(fs)
	else:
		var f1 := str(fate)
		if f1 != "":
			fl.append(f1)
	deploy_fates = fl
	deploy_fate = str(fl[0]) if not fl.is_empty() else ""

static func deploy_take() -> Dictionary:
	var out := {"role": deploy_role, "diff": deploy_diff, "fate": deploy_fate,
		"fates": deploy_fates.duplicate(), "party": deploy_party.duplicate()}
	deploy_role = ""
	deploy_diff = 0
	deploy_fate = ""
	deploy_fates = []
	deploy_party = []
	return out

# ---- ㊿v：出征自动卸下的随身之物（按人记）——回来照原样穿回去 ----
# 病根：出征屏 _do_depart 会先把三个人的兵器/三件套/功法**真卸下来**（放回村仓库），
#   本趟从此赤手上路（这是设计）。但回来那几条路（结算/半路折返/殒命/退出）都没人把它穿回去，
#   于是"每次历练完出来，装备武学总得重新穿"。
# 这里就干两件事：卸之前记一份；回村时按记录装回去。
#   · 只补**空着的**格子（玩家回来后自己换过的东西不动）
#   · 记录里的件若已经不在仓库（卖掉/换掉了）就跳过，报出来
#   · 存档里跟着走（中途退游戏也不丢），开新档清空
static var strip_saved := {}

static func strip_remember(d: Dictionary) -> void:
	strip_saved = d.duplicate(true)

# 回村穿回去。返回一句人话（没记录/没得补就返回空串）。
#   ⚠ 一律走 equip_weapon / equip_gear / equip_art 那三个正式口——
#     它们管着"从仓库扣一件 / 老件放回仓库 / 校验槽位"，自己抄一遍迟早走岔。
static func strip_restore() -> String:
	if strip_saved.is_empty():
		return ""
	var back: Array = []
	var miss: Array = []
	for rid_v in strip_saved.keys():
		var rid := str(rid_v)
		var rec: Dictionary = strip_saved[rid_v]
		var nm := str(_role_mut(rid).get("name", rid))
		# 兵器（只补空着的格子——玩家回来后自己换过的不动）
		var wid := str(rec.get("weapon", ""))
		if wid != "" and str(_role_mut(rid).get("weapon", "")) == "":
			var m1 := equip_weapon(rid, wid)
			if m1.begins_with("已换上"):
				back.append(nm + "：" + Cards.item_name(wid))
			else:
				miss.append(Cards.item_name(wid))
		# 三件套
		var g: Dictionary = rec.get("gear", {})
		for slot_v in g.keys():
			var slot := str(slot_v)
			var gsid := str(g[slot_v])
			if gsid == "":
				continue
			var gear: Dictionary = _role_mut(rid).get("gear", {})
			if str(gear.get(slot, "")) != "":
				continue
			var m2 := equip_gear(rid, slot, gsid)
			if m2.begins_with("已换上"):
				back.append(nm + "：" + Cards.item_name(gsid))
			else:
				miss.append(Cards.item_name(gsid))
		# 功法
		for sid_v in rec.get("skills", []):
			var asid := str(sid_v)
			if asid == "":
				continue
			var sk: Array = _role_mut(rid).get("skills", [])
			if sk.has(asid) or sk.size() >= FREE_SKILL_SLOTS:
				continue
			var m3 := equip_art(rid, asid)
			if m3.begins_with("已装上"):
				back.append(nm + "：" + Cards.name_of(asid))
			else:
				miss.append(Cards.name_of(asid))
	strip_saved = {}
	if back.is_empty() and miss.is_empty():
		return ""
	var msg := ""
	if not back.is_empty():
		msg = "回村已照原样穿回——" + "、".join(PackedStringArray(back))
	if not miss.is_empty():
		msg += ("；" if msg != "" else "回村没穿回——") + "仓库里找不到：" + "、".join(PackedStringArray(miss))
	return msg

# ----优化批㉓：出征临时扩仓…150 两起…翻倍」——顺手改成「6 格底、每格 +50」即可，不单给块。----
# 出发时由 run_state.begin_formal 调 take_run_expand() 取走；结算即失效、不退款。
const RUN_EXPAND_BASE := 70    # 第一格 50 两
const RUN_EXPAND_STEP := 70    # 每多买一格贵 50：50 → 100 → 150 → 200…
const RUN_EXPAND_SLOTS := 1    # 一次 +1 格，一格一格加
const RUN_EXPAND_FREE := 0     # ㉖：临时仓库每趟白搭格数——现定 0（不白搭）；要 6 格底就把 0 改成 6
static var run_expand_n := 0

static func run_expand_bought() -> int:
	return run_expand_n

static func run_expand_slots() -> int:
	return RUN_EXPAND_FREE + run_expand_n * RUN_EXPAND_SLOTS

static func run_expand_price() -> int:
	return RUN_EXPAND_BASE + RUN_EXPAND_STEP * run_expand_n

static func run_expand_price_after() -> int:
	return RUN_EXPAND_BASE + RUN_EXPAND_STEP * (run_expand_n + 1)

static func buy_run_expand() -> Dictionary:
	var price := run_expand_price()
	if coin("silver") < price:
		return {"ok": false, "msg": "银两不够：临时扩仓要 " + str(price) + " 两（现有 " + str(coin("silver")) + "）"}
	add_coin("silver", -price)
	run_expand_n += 1
	save_game()
	return {"ok": true, "msg": "临时仓库 +1 格（本趟共 " + str(run_expand_slots()) + " 格；再买一格要 " + str(run_expand_price()) + " 两）"}

static func take_run_expand() -> int:
	var n := RUN_EXPAND_FREE + run_expand_n * RUN_EXPAND_SLOTS
	run_expand_n = 0
	chest_inv.clear()      # v36：宝箱账
	chest_notes.clear()
	chest_set_stage_hint(0)
	return n

# ---- 游历结算入账（提取唯一管道 · v21；R4 接结算页）----
# loot 形状（R3 加后三路；v32 加 bloods）：
#   {"cards": {sid: {part: n}},       # 残卡/残页（与 vault_deposit 同形）
#    "items": {sid: n},              # 成品（只入仓库；登记只认合成产物）
#    "mats":  {材料键: n},           # 材料
#    "fragments": {碎片键: n},       # 角色碎片（键见 FRAGMENT_CN）
#    "pills": {丹方键: n},           # 丹药
#    "wines": int,                   # 酒酿坛数（现滚现入村酒坊）
#    "bloods": [{id, pur}],          # 血脉（v32：进血脉行囊）
#    "silver": int, "yuanbao": int}  # 带出的钱（文钱不走这里——盘缠就地作废）
# 返回一行摘要（给结算页用）
static func journey_deposit(loot: Dictionary) -> String:
	var got: Array = []
	var cards: Dictionary = loot.get("cards", {})
	if not cards.is_empty():
		got.append("残卡 " + str(vault_deposit(cards)))
	var items: Dictionary = loot.get("items", {})
	if not items.is_empty():
		var names: Array = []
		for sid_v in items.keys():
			var sid := str(sid_v)
			var c := int(items[sid_v])
			if c <= 0:
				continue
			vault_add_item(sid, c)
			# v28：只入仓库、不登记——登记只认合成产物（搜刮来的整件不算数）
			names.append(Cards.item_name(sid) + ("×" + str(c) if c > 1 else ""))
		if not names.is_empty():
			got.append("成品 " + "、".join(PackedStringArray(names)))
	var mats: Dictionary = loot.get("mats", {})
	if not mats.is_empty():
		var mn: Array = []
		for k_v in mats.keys():
			var k := str(k_v)
			var c2 := int(mats[k_v])
			if c2 <= 0:
				continue
			add_material(k, c2)
			mn.append(mat_name(str(k)) + "×" + str(c2))
		if not mn.is_empty():
			got.append("材料 " + "、".join(PackedStringArray(mn)))
	var frags: Dictionary = loot.get("fragments", {})
	if not frags.is_empty():
		var fn: Array = []
		for fid_v in frags.keys():
			var fid := str(fid_v)
			var fc := int(frags[fid_v])
			if fc <= 0:
				continue
			add_fragment(fid, fc)
			fn.append(fragment_name(fid) + "×" + str(fc))
		if not fn.is_empty():
			got.append("碎片 " + "、".join(PackedStringArray(fn)))
	var pills_in: Dictionary = loot.get("pills", {})
	if not pills_in.is_empty():
		var pn: Array = []
		for pid_v in pills_in.keys():
			var pid := str(pid_v)
			var pc := int(pills_in[pid_v])
			if pc <= 0:
				continue
			pills[pid] = int(pills.get(pid, 0)) + pc
			pn.append(str(recipe_of(pid).get("name", pid)) + "×" + str(pc))
		if not pn.is_empty():
			got.append("丹药 " + "、".join(PackedStringArray(pn)))
	var wine_n := int(loot.get("wines", 0))
	# v62：**按品级兑**（紫/金/红 各兑成 村酿/竹叶酒/陈酿）。老档/旧路径没带品级时，
	#   退回原来那套"现摇一坛"。顺带把品级写进结算那一行，玩家看得见带回了什么好酒。
	var wgrades: Array = loot.get("wine_grades", [])
	var wnames: Array = []
	for wi in wine_n:
		var g := int(wgrades[wi]) if wi < wgrades.size() else 0
		if g >= 2:
			wnames.append(add_wine_of_grade(g))
		else:
			var wd := wine_roll()
			add_wine(str(wd["name"]), wd["q"], int(wd["base"]), str(wd["hint"]))
			wnames.append(str(wd["name"]))
	if wine_n > 0:
		got.append("酒酿 ×" + str(wine_n) + "（" + "、".join(PackedStringArray(wnames)) + "）")
	var bloods: Array = loot.get("bloods", [])
	if not bloods.is_empty():
		var bn: Array = []
		for b_v in bloods:
			var bd: Dictionary = b_v
			var bid := str(bd.get("id", ""))
			if bid == "":
				continue
			var bpur := int(bd.get("pur", 50))
			blood_add(bid, bpur)
			bn.append(DataPets.blood_name(bid) + "（纯" + str(bpur) + "）")
		if not bn.is_empty():
			got.append("血脉 " + "、".join(PackedStringArray(bn)))
	var silver := int(loot.get("silver", 0))
	if silver > 0:
		add_coin("silver", silver)
		got.append("银两 " + str(silver))
	var yuanbao := int(loot.get("yuanbao", 0))
	if yuanbao > 0:
		add_coin("yuanbao", yuanbao)
		got.append("元宝 " + str(yuanbao))
	save_game()
	if got.is_empty():
		return "这一趟两手空空"
	var line := "带出：" + " · ".join(PackedStringArray(got))
	print("[账本] 游历入账：", line)
	return line

# ---- 全局存档（优化批㉒）----
# 一本簿子装全村账：角色/仓库/材料/丹酒碎片/升星/宠与血脉/村况/货币。存 user://save.cfg。
# 载入只做一次（_save_loaded）；没档＝照旧默认。难度/收集/背包仍在 journey.cfg（各自懒加载）。
# 落盘点：菜单启动读、退场与每 20 秒写；游历每条安全点、血脉融合/买袋/游历入账即刻落。
const SAVE_CFG := "user://save.cfg"
const SAVE_BAK := "user://save.bak"
const SAVE_VER := 2
static var _save_loaded := false
static var _save_from_bak := false   # 这次是拿备份接上的——下一笔落盘不许拿它盖备份

static func _sd(v: Variant, dv: Dictionary) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else dv.duplicate()

static func _sa(v: Variant, dv: Array) -> Array:
	return v if typeof(v) == TYPE_ARRAY else dv.duplicate()

# ============================================================
# ㉘ 数值外置：把当前所有可调旋钮连注释写成一份配置文件
# 用法：在菜单里按 O 键（或控制台调 GameState.tuning_write_example()）。
# 写出来的 user://tuning.cfg 就是"覆盖档"：改哪行生效哪行，没写的键
# 继续用代码里的默认值。手机上的路径看控制台打印（OS.get_user_data_dir）。
# 想恢复默认：把文件删掉，或把键名改错（读不到＝用默认值，不会报错）。
# ============================================================
static func tuning_write_example() -> String:
	var cf := ConfigFile.new()
	cf.set_value("combat", "dmg_mul", 2.0)
	cf.set_value("combat", "step", 0.72)
	cf.set_value("combat", "ult_mul", 2.5)
	cf.set_value("combat", "rage_gain", 34)
	# ㊹：全体怒气恢复总系数（0.7 = 比基准少 30%）。想恢复原样填 1.0；
	#   想再整体砍一半就填 0.35——两套战斗共用这一个键。
	cf.set_value("combat", "rage_mul", 0.7)
	# ㊿：速度 → 攻速。快过对手 atkspd_min_ratio 倍就每手多打一下**普攻**，
	#   再快一倍多打一下，最多 atkspd_max_extra 下。不想有这条就填 99。
	cf.set_value("combat", "atkspd_min_ratio", 2.0)
	cf.set_value("combat", "atkspd_max_extra", 2)
	cf.set_value("combat", "tech_every", 4)
	cf.set_value("combat", "tech_heal", 0.15)
	cf.set_value("combat", "enemy_flip", true)
	cf.set_value("combat", "enemy_weapon", "dual")
	cf.set_value("combat", "auto_delay_win", 2.0)
	cf.set_value("combat", "auto_delay_lose", 2.4)
	cf.set_value("combat", "lunge_out", 56.0)
	cf.set_value("combat", "shake_decay", 90.0)
	cf.set_value("combat", "art_fallback_mul", 1.8)
	cf.set_value("combat", "thorn_hp_lo", 0.08)
	cf.set_value("combat", "thorn_hp_hi", 0.12)
	cf.set_value("journey", "foe_hp_mult", 3.0)
	cf.set_value("journey", "money_mult", 0.6)
	cf.set_value("journey", "duel_rage_gain", 34)
	cf.set_value("journey", "thorn_hp_lo", 0.08)
	cf.set_value("journey", "thorn_hp_hi", 0.12)
	cf.set_value("journey", "node_heal_rate", 0.10)
	# ㊿：游历敌人的速度在 data_journey 里是 100 量级（88~110），
	#   而村里角色/出村怪是 10 量级（9~28）。这里把它折到 10 量级再比，
	#   否则玩家永远后手、"快一倍多打一下"也会全判给敌人。
	cf.set_value("journey", "foe_spd_div", 10.0)
	cf.set_value("journey", "loot_node_chance", 0.2)
	cf.set_value("journey", "loot_chance_cap", 0.75)
	cf.set_value("journey", "fate_unlock_diff", 5)
	cf.set_value("journey", "fate_scavenge_mul", 1.8)
	cf.set_value("journey", "fate_scavenge_cap", 0.6)
	cf.set_value("journey", "fate_greed_money", 2.0)
	cf.set_value("journey", "fate_shortrope_rate", 2.5)
	cf.set_value("journey", "fate_fullbag_money", 0.475)
	cf.set_value("journey", "fate_noarmor_mult", 1.5)
	# ㊿：词缀这几行**必须跟 data_affixes 里的默认值一致**——这个文件是"导出样例"，
	#   谁按下 O 生成 tuning.cfg，以后就由这个文件说了算；先前这里还写着
	#   反伤 0.25 / 自爆 0.15（老数值），一按 O 就会把新数值悄悄顶回去。
	cf.set_value("affix", "thorn_pct", 0.12)
	cf.set_value("affix", "thorn_cap", 0.10)     # 先前漏了这一行
	cf.set_value("affix", "swift_every", 3)
	cf.set_value("affix", "swift_pct", 0.6)
	cf.set_value("affix", "regen_pct", 0.06)
	cf.set_value("affix", "bomb_pct", 0.40)
	cf.set_value("affix", "shock_chance", 0.30)
	cf.set_value("affix", "berserk_mul", 1.6)
	cf.set_value("affix", "rally_step", 0.06)
	cf.set_value("affix", "rally_cap", 0.6)
	cf.set_value("affix", "fury_step", 0.08)
	cf.set_value("affix", "fury_cap", 0.8)
	cf.set_value("affix", "poison_pct", 0.03)
	cf.set_value("affix", "poison_max", 3)
	# ㉚：货价梯子——买进基价 30（货摊，代码里在 run_state.make_shop_offers）
	#   必须 > 卖店 12 > 折现 6，否则会出现"攒满包折现比卖店还赚"的套利
	cf.set_value("price", "sell_card", 12)
	cf.set_value("price", "sell_item", 25)
	cf.set_value("price", "cashout", 6)
	cf.set_value("price", "fix_base", 80)
	var err := cf.save(Tuning.PATH_USER)
	if err != OK:
		print("[调参] 写样例配置失败＝", err)
		return ""
	var full := ProjectSettings.globalize_path(Tuning.PATH_USER)
	print("[调参] 样例配置已写到：", full)
	print("[调参] 说明：")
	print("  · [combat]  出村战斗（battle_lite）的倍率与节奏；敌方大招/技能表在 game_state")
	print("  · [journey] 游历（duel_battle + journey_stage）：敌人血量总系数、文钱系数、")
	print("              命数倍率、搜刮概率、过节点回血")
	print("  · [affix]   怪词缀数值，两套战斗共用（shared/data_affixes.gd）")
	print("  · [price]   货价梯子：卖店 / 折现 / 补齐。规矩是 买进(30) > 卖店 > 折现，")
	print("              顺序一乱就会出现套利（攒满包折现比卖店还赚）")
	print("  · 没写的键＝用代码里的默认值；删掉这个文件＝全部回默认")
	print("  · 手机：adb push 到上面那个路径（uid 要能读写自己 files 目录即可）")
	return full

# ㉙ 自检：模拟"盘上有一份比本程序新的档"，验证"改名留档、不静默丢"这条真会发生。
# 用的是探针文件（save.vertest.cfg），**完全不碰你真正的 save.cfg / save.bak**。
# 菜单里按 J 键就能跑（见 menu_sketch）。
static func debug_version_probe() -> void:
	var probe := "user://save.vertest.cfg"
	var gone := "user://save.vertest.cfg.v99.bak"
	var da := DirAccess.open("user://")
	if da == null:
		print("[自检] 打不开 user:// ——跳过")
		return
	if da.file_exists(gone.get_file()):
		da.remove(gone.get_file())
	# 造一份"版本 99"的档
	var cf := ConfigFile.new()
	cf.set_value("save", "ver", 99)
	cf.set_value("world", "village", {"stage": 3})
	if cf.save(probe) != OK:
		print("[自检] 造探针档失败——跳过")
		return
	# 跑一遍启动时的识别逻辑
	_open_save()
	# 看结果
	var moved := da.file_exists(gone.get_file())
	var left := da.file_exists(probe.get_file())
	print("[自检] ── 版本迁移自检 ──")
	if moved and not left:
		print("[自检] 通过：版本 99 的档被改名留档成 save.vertest.cfg.v99.bak，原件没被删")
		print("[自检] （真档 save.cfg / save.bak 全程没被碰过）")
	else:
		print("[自检] 不通过：moved=", moved, " left=", left, " —— 这条路没按预期工作，请告诉我")
	if da.file_exists(gone.get_file()):
		da.remove(gone.get_file())   # 收尾：把探针清掉
		print("[自检] 探针已清理")

# ============================================================
# 存档安全网（优化批㉖）：以前的写法是直接覆盖同一个文件。
# 写到一半被系统杀掉（手机上很常见），那份档就废了——而且读不出来时
# 旧代码一声不响当成"没有档"，玩家的村子直接归零。
# 现在三步走：
#   ① 把当前这份（不管好坏）原样改名到 .bak——纯改名，是原子操作，不会写一半
#   ② 新档先写进 .tmp
#   ③ 读回来验一遍，能读才顶掉正式档；读不出来就保留旧的
# 于是任何时刻磁盘上至少有一份能读的档：正式档坏了读 .bak，两份都读不出才是真新档。
# ============================================================

# 把当前正式档挪到备份位（纯改名，不改内容）。
# 不做"先验一遍好不好"的判断：改名本身是原子的，无论旧档是好是坏，挪过去都不亏——
# 挪走好的＝备份是好的；挪走坏的＝备份位里原来那份好的正好被清掉（反正也不能用）。
# 绝不删原件：即便这里失败，正式档原封不动，下一次落盘照样走"写 .tmp → 验 → 顶掉"。
static func _keep_backup(path: String, bak_path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var da := DirAccess.open("user://")
	if da == null:
		return
	# rename 会直接顶掉已存在的目标（引擎文档明说），所以不用先删——先删反而多一个
	# "删掉了、改名却失败"的空窗，那才是最坏情况。
	var r := da.rename(path.get_file(), bak_path.get_file())
	if r != OK:
		print("[存档] 没能把上一份留成备份（错误码 ", r, "）——不影响这次落盘")

# 安全落盘：写 .tmp → 验一遍 → 顶掉正式档。失败时正式档保持原样。
# section/ver_key/ver 是给"验一遍"用的（ver 传 -1＝这份不写版本号，跳过版本校验）。
static func safe_write(path: String, cf: ConfigFile, section := "save", ver_key := "ver", ver := SAVE_VER) -> bool:
	var tmp := path + ".tmp"
	var err := cf.save(tmp)
	if err != OK:
		print("[存档] 写临时档失败＝", err, "；正式档没动。路径=", tmp)
		return false
	var check := ConfigFile.new()
	if check.load(tmp) != OK:
		print("[存档] 临时档读不回来，已放弃这次落盘（正式档没动）")
		return false
	if ver >= 0 and int(check.get_value(section, ver_key, -1)) != ver:
		print("[存档] 临时档版本号不对，已放弃这次落盘（正式档没动）")
		return false
	var rn := DirAccess.rename_absolute(tmp, path)
	if rn != OK:
		print("[存档] 顶掉正式档失败＝", rn, "；这次落盘没生效，临时档留在 ", tmp)
		return false
	return true

# ============================================================
# ㉙ 存档版本与迁移
# 旧行为：ver != SAVE_VER 就直接 return —— 玩家的村子一声不响归零，
#   而且那份档还躺在盘上、下次落盘就被覆盖掉，等于永久销毁。
# 新行为分三种：
#   ① ver == 当前      正常读
#   ② ver <  当前      走迁移链（migrate 一版一版往上抬）；抬不动才当读不出来
#   ③ ver >  当前      这是"新版本游戏写的老机器读不了"的档——不敢乱读（可能缺字段、
#                      也可能字段意思变了），但它很可能是玩家在新版里练的号：
#                      改名留档 + 控制台喊一声，绝不静默丢
# 版本约定：字段只增不改意思时**不用**升版本——下面每个读取都写了默认值，
#   缺字段会自然取默认。只有"老字段意思变了 / 结构变了"才升 SAVE_VER 并补一步迁移。
# ============================================================
const SAVE_VER_MIN := 1   # 还能迁移的最老版本

# 一版一版往上抬。**已有一步**：v1→v2 拍平升星的键（星改记在件上，见 _migrate）。
# 写法照这个加（一步一个 if，别写成循环——将来真加步骤时循环容易写错）：
#   if v == 1:
#       # 例：1→2 把 world.coins 拆成 world.coins / world.tokens
#       ...
#       v = 2
# 落盘时版本号会自动写成新值，玩家下次进游戏就是新版档了。
static func _migrate(cf: ConfigFile, v: int) -> int:
	var cur := v
	# ↓↓↓ 迁移步骤加在这里 ↓↓↓
	if cur < 1:
		cur = 1   # 兜底：没有版本号的远古档，按第一版处理
	if cur < 2:
		# v1→v2（v35）：升星的键从「主人|件名」拍平成「件名」——星改记在**件**上。
		#   · 同一个件名若有多条（主角升的枪 / 陈石升的枪），取**最高**那一份：
		#     玩家的投入不缩水（宁可偏强，也不该把已花掉的同名份数与银两凭空抹掉）。
		#   · 没有 "|" 的老键照抄（万一手改过档，也不丢）。
		var vlt_m: Dictionary = _sd(cf.get_value("world", "vault", {}), {})
		var old_st: Dictionary = _sd(vlt_m.get("stars", {}), {})
		var new_st: Dictionary = {}
		for k_v in old_st.keys():
			var key := str(k_v)
			var sid := key
			if key.contains("|"):
				var seg: PackedStringArray = key.split("|")
				sid = str(seg[seg.size() - 1])
			new_st[sid] = maxi(int(new_st.get(sid, 0)), int(old_st[k_v]))
		vlt_m["stars"] = new_st
		cf.set_value("world", "vault", vlt_m)
		if not old_st.is_empty():
			print("[账本] 迁移 v1→v2：升星的键拍平 ", old_st.size(), " 条 → ", new_st.size(), " 件（同件取最高星）")
		cur = 2
	# ↑↑↑ 迁移步骤加在这里 ↑↑↑
	if not cf.has_section("save"):
		print("[账本] 迁移时发现这份档连 [save] 段都没有——按空档处理")
	if cur > SAVE_VER:
		cur = SAVE_VER
	return cur

# ㉙：收掉"版本对不上"的留档（save.cfg.v99.bak 这类）。
# 为什么要收：留着是为了"换回新版程序还能接着玩"，但如果反复切版本，
#   这类文件会一个一个堆下去、永远没人清。所以只留最新的一份，旧的删掉。
# 注意只认 save.cfg.v*.bak 这一种形状——绝不碰 save.cfg / save.bak / save.cfg.tmp。
static func _prune_version_baks() -> void:
	var da := DirAccess.open("user://")
	if da == null:
		return
	var mine: Array = []
	for f in da.get_files():
		var n := str(f)
		if n.begins_with("save.cfg.v") and n.ends_with(".bak"):
			mine.append(n)
	if mine.size() <= 1:
		return
	mine.sort()   # 名字里带版本号，字典序＝大致的新旧序
	for i in mine.size() - 1:   # 除了最后一个（最大的），其余删掉
		da.remove(str(mine[i]))
		print("[账本] 清掉旧的版本留档：", mine[i])

# 读一份档出来（含"正规档坏了就试备份"）。返回的 cfg 为 null ＝ 没有可用档。
# 不兼容的档会被改名留档，不会覆盖、不会删。
static func _open_save() -> Dictionary:
	_prune_version_baks()
	var out := {"cfg": null, "from_bak": false, "ver": 0}
	var tried: Array = [SAVE_CFG, SAVE_BAK]
	for i in tried.size():
		var path := str(tried[i])
		var cf := ConfigFile.new()
		if cf.load(path) != OK:
			continue
		var v := int(cf.get_value("save", "ver", 0))
		if v == SAVE_VER:
			out["cfg"] = cf
			out["from_bak"] = (i == 1)
			out["ver"] = v
			if i == 1:
				print("[账本] 正式档读不出来——已用备份 save.bak 接上")
			return out
		if v >= SAVE_VER_MIN and v < SAVE_VER:
			var nv := _migrate(cf, v)
			print("[账本] 存档版本 ", v, " → ", nv, "（已迁移，", path, "）")
			out["cfg"] = cf
			out["from_bak"] = (i == 1)
			out["ver"] = nv
			return out
		if v > SAVE_VER:
			# 不认识的"未来档"：留档不删——玩家宁可看到"读不了"，也不该看到村子归零
			var keep := path + ".v" + str(v) + ".bak"
			var da := DirAccess.open("user://")
			if da != null:
				da.rename(path.get_file(), keep.get_file())
				print("[账本] 存档版本 ", v, " 比本程序（", SAVE_VER, "）新，读不了。")
				print("[账本] 已把它改名留档：", keep, "（没有删——换回新版程序还能接着玩）")
		# ver < SAVE_VER_MIN，或读不出 ver：这份档认不出来，试下一份
	return out

static func load_game() -> void:
	if _save_loaded:
		return
	_save_loaded = true
	var opened := _open_save()
	var cf: ConfigFile = opened["cfg"]
	if cf == null:
		return
	_save_from_bak = bool(opened["from_bak"])
	var vd := _sd(cf.get_value("world", "village", {}), {})
	village_stage = int(vd.get("stage", village_stage))
	first_journey_done = bool(vd.get("first_journey_done", first_journey_done))
	first_explore_done = bool(vd.get("first_explore_done", first_explore_done))
	world_difficulty = clampi(int(vd.get("world_difficulty", world_difficulty)), 1, 3)
	world_created = bool(vd.get("world_created", world_created))
	if not world_created and (first_explore_done or not world_flags.is_empty()):
		world_created = true
	world_history = (vd.get("world_history", world_history) as Array).duplicate(true)
	player_name = str(vd.get("player_name", player_name))   # v83
	disciple_joined = bool(vd.get("disciple_joined", disciple_joined))
	qingluan_joined = bool(vd.get("qingluan_joined", qingluan_joined))
	map_found = bool(vd.get("map_found", map_found))
	b2_built = bool(vd.get("b2_built", b2_built))
	cave_opened = bool(vd.get("cave_opened", cave_opened))
	winery_built = bool(vd.get("winery_built", winery_built))
	herbs_granted = bool(vd.get("herbs_granted", herbs_granted))
	dange_built = bool(vd.get("dange_built", dange_built))
	auto_climb = bool(vd.get("auto_climb", auto_climb))
	stage_progress = int(vd.get("stage_progress", stage_progress))
	# v129：追剿（精英爬塔）进度——老档没有这两键＝还没打过，从 0 起（不报错）
	chase_progress = clampi(int(vd.get("chase_progress", chase_progress)), 0, Chase.STAGE_MAX)
	chase_auto = bool(vd.get("chase_auto", chase_auto))
	formation = _sa(vd.get("formation", formation), formation)
	formation_intro_done = bool(vd.get("formation_intro_done", formation_intro_done))
	tower_gifts = _sa(vd.get("tower_gifts", tower_gifts), tower_gifts)   # ㊱：已发过的首领赏
	chest_inv = _sd(vd.get("chests", chest_inv), chest_inv)              # v36：攒着的宝箱
	chest_set_stage_hint(int(vd.get("chest_stage", stage_progress)))     # v36：开箱按"推到的那一关"的赏格
	# v39：鉴宝行——解锁 / 道具背包 / 店里那几只货仓（含已侦查的格子）
	jianbao_unlocked = bool(vd.get("jianbao", jianbao_unlocked))
	appraise_tools = _sd(vd.get("appraise_tools", appraise_tools), appraise_tools)
	appraise_offers = _sa(vd.get("appraise_offers", appraise_offers), appraise_offers)
	_appraise_drop_retired_offers()      # v59：换档位后，老档里的旧档 id 要清掉（不然是"白拿的空箱子"）
	_appraise_uid = int(vd.get("appraise_uid", _appraise_uid))
	appraise_opened = int(vd.get("appraise_opened", appraise_opened))
	appraise_best = int(vd.get("appraise_best", appraise_best))
	appraise_ensure_offers()
	# v40：新手关卡礼包
	stage_gift_got = bool(vd.get("stage_gift", stage_gift_got))
	stage_gift_opened = clampi(int(vd.get("stage_gift_opened", stage_gift_opened)), 0, stage_gift_total())
	coins = _sd(cf.get_value("world", "coins", coins), coins)
	insight = maxi(0, int(cf.get_value("world", "insight", 0)))            # v64b：阅历值
	action = clampi(int(cf.get_value("world", "action", ACTION_START)), 0, ACTION_MAX)   # v242：行动资源
	var sd := _sd(cf.get_value("world", "sect", {}), {})
	sect_favor = clampi(int(sd.get("favor", 0)), 0, 100)
	sect_rep = clampi(int(sd.get("rep", 0)), 0, 100)
	sect_test = bool(sd.get("test", false))
	sect_art = bool(sd.get("art", false))
	sect_joined = bool(sd.get("joined", false))
	sect_contrib = maxi(0, int(sd.get("contrib", 0)))
	sect_betrayed = bool(sd.get("betrayed", false))
	world_seed = maxi(0, int(cf.get_value("world", "world_seed", 0)))
	world_tier = clampi(int(cf.get_value("world", "world_tier", 1 + int(world_seed / 2))), 1, 5)
	merchant_favor = clampi(int(cf.get_value("world", "merchant_favor", 0)), 0, 100)
	wanted = clampi(int(cf.get_value("world", "wanted", 0)), 0, 5)
	boss_kills = _sa(cf.get_value("world", "boss_kills", []), boss_kills)
	jailed_days = clampi(int(cf.get_value("world", "jailed_days", 0)), 0, 3)
	red_water = clampi(int(cf.get_value("world", "red_water", 0)), 0, 2)
	red_water_wall = bool(cf.get_value("world", "red_water_wall", false))
	red_water_market = bool(cf.get_value("world", "red_water_market", false))
	red_water_garrison = bool(cf.get_value("world", "red_water_garrison", false))
	red_water_taxpost = bool(cf.get_value("world", "red_water_taxpost", false))
	red_water_peace = bool(cf.get_value("world", "red_water_peace", false))
	war_score = clampi(int(cf.get_value("world", "war_score", 0)), 0, 100)
	broker_rep = clampi(int(cf.get_value("world", "broker_rep", 0)), 0, 100)
	broker_quest = clampi(int(cf.get_value("world", "broker_quest", 0)), 0, 3)
	broker_pardon = bool(cf.get_value("world", "broker_pardon", false))
	north_score = clampi(int(cf.get_value("world", "north_score", 0)), 0, 100)
	north_peace = bool(cf.get_value("world", "north_peace", false))
	north_wins = clampi(int(cf.get_value("world", "north_wins", 0)), 0, 999)
	north_weapon = bool(cf.get_value("world", "north_weapon", false))
	north_tax_day = str(cf.get_value("world", "north_tax_day", ""))
	ng_plus = clampi(int(cf.get_value("world", "ng_plus", 0)), 0, 99)
	map_owners = _sd(cf.get_value("world", "map_owners", {}), map_owners)
	world_flags = _sd(cf.get_value("world", "world_flags", {}), world_flags)
	var old_tier := world_tier
	world_prosperity = int(cf.get_value("world", "world_prosperity", -1))
	if world_prosperity < 0:
		world_prosperity = int(PROSPERITY_STEPS[clampi(old_tier - 1, 0, 4)])
	world_tier = tier_for_prosperity(world_prosperity)
	current_region = clampi(int(cf.get_value("world", "current_region", 0)), 0, 4)
	region_unlocked = _sa(cf.get_value("world", "region_unlocked", [true, true, true, false, false]), [true, true, true, false, false]).duplicate()
	time_slot = clampi(int(cf.get_value("world", "time_slot", 0)), 0, 2)
	time_day = maxi(1, int(cf.get_value("world", "time_day", 1)))
	slot_progress = maxi(0, int(cf.get_value("world", "slot_progress", 0)))
	region_rep = _sa(cf.get_value("world", "region_rep", [0, 0, 0, 0, 0]), [0, 0, 0, 0, 0]).duplicate()
	while region_rep.size() < 5:
		region_rep.append(0)
	region_seen = _sa(cf.get_value("world", "region_seen", [false, false, false, false, false]), [false, false, false, false, false]).duplicate()
	while region_seen.size() < 5:
		region_seen.append(false)
	region_walk = _sa(cf.get_value("world", "region_walk", [0, 0, 0, 0, 0]), [0, 0, 0, 0, 0]).duplicate()
	while region_walk.size() < 5:
		region_walk.append(0)
	merchant_stock_slot = str(cf.get_value("world", "merchant_stock_slot", ""))
	merchant_stock = _sd(cf.get_value("world", "merchant_stock", {}), merchant_stock)
	npc_stock = _sd(cf.get_value("world", "npc_stock", {}), npc_stock)
	region_landmarks = _sd(cf.get_value("world", "region_landmarks", {}), region_landmarks)
	npc_budget = int(cf.get_value("world", "npc_budget", -1))
	sect_prosperity_rank = clampi(int(cf.get_value("world", "sect_prosperity_rank", 0)), 0, 2)
	forge_names = _sa(cf.get_value("world", "forge_names", []), forge_names)
	ng_event_seen = bool(cf.get_value("world", "ng_event_seen", false))
	ng_event_choice = clampi(int(cf.get_value("world", "ng_event_choice", -1)), -1, 1)
	ng_echo_seen = bool(cf.get_value("world", "ng_echo_seen", false))
	ng_final_seen = bool(cf.get_value("world", "ng_final_seen", false))
	ng_final_choice = clampi(int(cf.get_value("world", "ng_final_choice", -1)), -1, 1)
	ng_wuxia_done = bool(cf.get_value("world", "ng_wuxia_done", false))
	story_title_prosperity = bool(cf.get_value("world", "story_title_prosperity", false))
	while region_unlocked.size() < 5:
		region_unlocked.append(false)
	north_garrison = bool(cf.get_value("world", "north_garrison", false))
	broker_weapon = bool(cf.get_value("world", "broker_weapon", false))
	story_letter = clampi(int(cf.get_value("world", "story_letter", 0)), 0, 3)
	story_follow = clampi(int(cf.get_value("world", "story_follow", 0)), 0, 1)
	story_title = str(cf.get_value("world", "story_title", ""))
	snow_charm = bool(cf.get_value("world", "snow_charm", false))
	snow_charm2 = bool(cf.get_value("world", "snow_charm2", false))
	turf_tax_day = str(cf.get_value("world", "turf_tax_day", ""))
	war_notes = _sa(cf.get_value("world", "war_notes", []), war_notes)
	advance_lv = clampi(int(cf.get_value("world", "advance_lv", 0)), 0, Realm.MAX_LV)   # v121：进阶境界
	insight_lv = _sd(cf.get_value("world", "insight_lv", {}), insight_lv)  # v64b：四支等级
	exp_pool = maxi(0, int(cf.get_value("world", "exp_pool", 0)))   # ㊾：经验池
	run_expand_n = int(cf.get_value("world", "run_expand", 0))
	var rd := _sd(cf.get_value("world", "roles", {}), {})
	chen_shi = _sd(rd.get("chen", {}), chen_shi)
	player_role = _sd(rd.get("player", {}), player_role)
	qingluan = _sd(rd.get("qing", {}), qingluan)
	# ㉖：自带只认真源（data_roles）——老档里那两个字段是空串，读档时一并刷正
	# v47：被动/大招/自带技也从模板刷一遍（老档存着旧数值，改表不刷就白改）
	_sync_role_innate(chen_shi, "chen_shi")
	_sync_role_innate(player_role, "player")
	_sync_role_innate(qingluan, "qingluan")
	_sync_role_kit(chen_shi, "chen_shi")
	_sync_role_kit(player_role, "player")
	_sync_role_kit(qingluan, "qingluan")
	_sync_qingluan_talents(qingluan)   # v65：老档里她那些随机天赋（悟性/闪避）换成固定两条
	# v65i：速度校正（旧档遗留的野数——见 _fix_legacy_spd 的长注）
	_fix_legacy_spd(chen_shi, "chen_shi")
	_fix_legacy_spd(player_role, "player")
	_fix_legacy_spd(qingluan, "qingluan")
	# ㊿v：出征自动卸下的记录（回来后照原样穿回去用）
	strip_saved = _sd(cf.get_value("world", "strip_saved", {}), {})
	# ㊿y：角色星
	role_stars = _sd(cf.get_value("world", "role_stars", {}), {})
	# v38/v44：成长补课——自带/角色星那条"每级多涨几点"是后加的，**根骨那一份**更是
	#   从来就没补过（洗髓丹喂完只在下一级见效）。老档在这里一次补齐；
	#   role["grow_paid"] 记着已按几点/级结过账（含气血成长）。
	for rid_s in ["player", "chen_shi", "qingluan"]:
		grow_sync(str(rid_s))
	var vlt := _sd(cf.get_value("world", "vault", {}), {})
	vault_cards = _sd(vlt.get("cards", {}), vault_cards)
	vault_items = _sd(vlt.get("items", {}), vault_items)
	forge_item = _sd(vlt.get("forge_item", {}), forge_item)
	forge_bag = _sa(vlt.get("forge_bag", []), forge_bag)
	forge_cards = _sd(vlt.get("forge_cards", {}), {})
	forge_seq = int(vlt.get("forge_seq", forge_seq))
	forge_compendium = _sd(vlt.get("forge_compendium", {}), {})
	Cards.clear_forged()
	for fsid_v in forge_cards.keys():
		var fsid := str(fsid_v)
		Cards.register_forged(fsid, forge_cards[fsid])
	materials = _sd(vlt.get("materials", {}), materials)
	material_q = _sd(vlt.get("material_q", material_q), material_q)
	if material_q.is_empty() and not materials.is_empty():
		for mk in materials.keys():
			if int(materials[mk]) > 0:
				material_q[_mq_key(str(mk), 0)] = int(materials[mk])
	# v257：青岚控制赤水寨 → 每日地盘税（一天一次）
	if red_water == 2:
		var today := Time.get_date_string_from_system()
		if turf_tax_day != today:
			turf_tax_day = today
			var tax_s := (100 if red_water_taxpost else 60) + (20 if red_water_peace else 0)
			var tax_st := (4 if red_water_taxpost else 2) + (1 if red_water_peace else 0)
			add_coin("silver", tax_s)
			add_material("forge_stone", tax_st)
			note_war("青岚地盘税：银两 +" + str(tax_s) + " · 锻造石 +" + str(tax_st))
			note_push("青岚地盘税入账：银两 +" + str(tax_s) + " · 锻造石 +" + str(tax_st))
	# v265：北境平定 → 每日哨税（40 两 +1 石）
	if north_peace:
		var today2 := Time.get_date_string_from_system()
		if north_tax_day != today2:
			north_tax_day = today2
			var ns := 60 if north_garrison else 40
			var nst := 2 if north_garrison else 1
			add_coin("silver", ns)
			add_material("forge_stone", nst)
			note_war("北境哨税：银两 +" + str(ns) + " · 锻造石 +" + str(nst))
			note_push("北境哨税入账：银两 +" + str(ns) + " · 锻造石 +" + str(nst))
	# v244：老档 / 新档给一张舆图；用掉后 world_seed > 0，不再补发
	if int(materials.get("atlas", 0)) <= 0 and world_seed == 0:
		materials["atlas"] = 1
	materials.erase("wood")   # v242：建设删了，木料一并下线（老档里剩下的不再显示）
	fragments = _sd(vlt.get("fragments", {}), fragments)
	pills = _sd(vlt.get("pills", {}), pills)
	wines = _sa(vlt.get("wines", []), wines)
	item_stars = _sd(vlt.get("stars", {}), item_stars)
	# v58：元素两键（**老档没有＝空字典**，读进来是空的就靠 _elem_topup 懒补——
	#   补出来的元素用 `hash(件名|第几份)` 做种，所以"没存盘就退出"也不会换一个）
	item_elems = _sd(vlt.get("elems", {}), item_elems)
	item_elem_pick = _sd(vlt.get("elem_pick", {}), item_elem_pick)
	# v41：多炉——新键 furnaces/furnace_slots；老档只有单个 `alchemy`，搬进 0 号炉
	furnaces = _sa(vlt.get("furnaces", []), furnaces)
	furnace_slots = clampi(int(vlt.get("furnace_slots", 1)), 1, FURNACE_MAX)
	alchemy = _sd(vlt.get("alchemy", {}), alchemy)
	if furnaces.is_empty() and not alchemy.is_empty():
		furnaces = [alchemy.duplicate(true)]
		alchemy = {}
	# ⚠ 删掉了一处遗留的调试重置（`furnaces = []` / `furnace_slots = 1`）：
	#   它每次读档都把**买过的炉位和正在炼的那几炉一起清掉**，
	#   等于多炉白买、炼到一半回村就没了。（炉位只由 furnace_unlock() 涨。）
	_ensure_furnace_slots()
	var pd := _sd(cf.get_value("world", "pets", {}), {})
	pet_roster = _sd(pd.get("roster", {}), pet_roster)
	pet_sel = str(pd.get("sel", pet_sel))
	pet_follow = str(pd.get("follow", pet_follow))
	pet_apt = _sd(pd.get("apt", {}), pet_apt)
	pet_stars = _sd(pd.get("stars", {}), pet_stars)   # ㊿z9
	pet_dups = _sd(pd.get("dups", {}), pet_dups)
	pet_bl = _sd(pd.get("bl", {}), pet_bl)
	blood_inv = _sa(pd.get("blood_inv", []), blood_inv)
	_pet_sync()
	print("[账本] 存档已载入：村况=", village_stage, " 弟子=", disciple_joined, " 宠=", pet_owned().size(), " 血脉=", blood_inv.size())

static func save_game() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_CFG)
	cf.set_value("save", "ver", SAVE_VER)
	cf.set_value("world", "village", {
		"stage": village_stage, "first_journey_done": first_journey_done, "first_explore_done": first_explore_done, "world_difficulty": world_difficulty, "world_created": world_created, "world_history": world_history,
		"player_name": player_name,   # v83：玩家起的名字
		"disciple_joined": disciple_joined, "qingluan_joined": qingluan_joined,
		"map_found": map_found, "b2_built": b2_built, "cave_opened": cave_opened,
		"winery_built": winery_built, "herbs_granted": herbs_granted, "dange_built": dange_built,
		"auto_climb": auto_climb, "stage_progress": stage_progress,
		"chase_progress": chase_progress, "chase_auto": chase_auto,   # v129：追剿进度与自动连打
		"formation": formation, "formation_intro_done": formation_intro_done,
		"tower_gifts": tower_gifts,
		"chests": chest_inv, "chest_stage": _chest_stage_hint,   # v36：宝箱账
		# v39：鉴宝行（货仓报价单＋道具背包——货仓内容买之前就掷好，也要落盘）
		"jianbao": jianbao_unlocked, "appraise_tools": appraise_tools,
		"appraise_offers": appraise_offers, "appraise_uid": _appraise_uid,
		"appraise_opened": appraise_opened, "appraise_best": appraise_best,
		# v40：新手关卡礼包（引子通关给的；开了几次）
		"stage_gift": stage_gift_got, "stage_gift_opened": stage_gift_opened,
	})
	cf.set_value("world", "coins", coins)
	# v64b：阅历线（阅历值 ＋ 四支各自升到第几段）
	cf.set_value("world", "insight", insight)
	cf.set_value("world", "action", action)
	cf.set_value("world", "sect", {"favor": sect_favor, "rep": sect_rep, "test": sect_test, "art": sect_art, "joined": sect_joined, "contrib": sect_contrib, "betrayed": sect_betrayed})
	cf.set_value("world", "world_seed", world_seed)
	cf.set_value("world", "world_tier", world_tier)
	cf.set_value("world", "merchant_favor", merchant_favor)
	cf.set_value("world", "wanted", wanted)
	cf.set_value("world", "boss_kills", boss_kills)
	cf.set_value("world", "jailed_days", jailed_days)
	cf.set_value("world", "red_water", red_water)
	cf.set_value("world", "red_water_wall", red_water_wall)
	cf.set_value("world", "red_water_market", red_water_market)
	cf.set_value("world", "red_water_garrison", red_water_garrison)
	cf.set_value("world", "red_water_taxpost", red_water_taxpost)
	cf.set_value("world", "red_water_peace", red_water_peace)
	cf.set_value("world", "war_score", war_score)
	cf.set_value("world", "broker_rep", broker_rep)
	cf.set_value("world", "broker_quest", broker_quest)
	cf.set_value("world", "broker_pardon", broker_pardon)
	cf.set_value("world", "north_score", north_score)
	cf.set_value("world", "north_peace", north_peace)
	cf.set_value("world", "north_wins", north_wins)
	cf.set_value("world", "north_weapon", north_weapon)
	cf.set_value("world", "north_tax_day", north_tax_day)
	cf.set_value("world", "ng_plus", ng_plus)
	cf.set_value("world", "map_owners", map_owners)
	cf.set_value("world", "world_flags", world_flags)
	cf.set_value("world", "world_prosperity", world_prosperity)
	cf.set_value("world", "current_region", current_region)
	cf.set_value("world", "region_unlocked", region_unlocked)
	cf.set_value("world", "time_slot", time_slot)
	cf.set_value("world", "time_day", time_day)
	cf.set_value("world", "slot_progress", slot_progress)
	cf.set_value("world", "region_rep", region_rep)
	cf.set_value("world", "region_seen", region_seen)
	cf.set_value("world", "region_walk", region_walk)
	cf.set_value("world", "merchant_stock_slot", merchant_stock_slot)
	cf.set_value("world", "merchant_stock", merchant_stock)
	cf.set_value("world", "npc_stock", npc_stock)
	cf.set_value("world", "region_landmarks", region_landmarks)
	cf.set_value("world", "npc_budget", npc_budget)
	cf.set_value("world", "sect_prosperity_rank", sect_prosperity_rank)
	cf.set_value("world", "forge_names", forge_names)
	cf.set_value("world", "ng_event_seen", ng_event_seen)
	cf.set_value("world", "ng_event_choice", ng_event_choice)
	cf.set_value("world", "ng_echo_seen", ng_echo_seen)
	cf.set_value("world", "ng_final_seen", ng_final_seen)
	cf.set_value("world", "ng_final_choice", ng_final_choice)
	cf.set_value("world", "ng_wuxia_done", ng_wuxia_done)
	cf.set_value("world", "story_title_prosperity", story_title_prosperity)
	cf.set_value("world", "north_garrison", north_garrison)
	cf.set_value("world", "broker_weapon", broker_weapon)
	cf.set_value("world", "story_letter", story_letter)
	cf.set_value("world", "story_follow", story_follow)
	cf.set_value("world", "story_title", story_title)
	cf.set_value("world", "snow_charm", snow_charm)
	cf.set_value("world", "snow_charm2", snow_charm2)
	cf.set_value("world", "turf_tax_day", turf_tax_day)
	cf.set_value("world", "war_notes", war_notes)
	cf.set_value("world", "advance_lv", advance_lv)          # v121：进阶境界
	cf.set_value("world", "insight_lv", insight_lv)
	cf.set_value("world", "exp_pool", exp_pool)   # ㊾：经验池
	cf.set_value("world", "run_expand", run_expand_n)
	cf.set_value("world", "roles", {"chen": chen_shi, "player": player_role, "qing": qingluan})
	# ㊿y：角色星（命座/星魂式，按人记级数）
	cf.set_value("world", "role_stars", role_stars)
	# ㊿v：出征自动卸下的那份记录——跟着存档走，中途退游戏也不丢
	cf.set_value("world", "strip_saved", strip_saved)
	cf.set_value("world", "vault", {
		"cards": vault_cards, "items": vault_items, "materials": materials, "material_q": material_q,
		"forge_item": forge_item, "forge_bag": forge_bag,
		"forge_cards": forge_cards, "forge_seq": forge_seq,
		"forge_compendium": forge_compendium,
		"fragments": fragments, "pills": pills, "wines": wines,
		"stars": item_stars, "alchemy": alchemy,   # alchemy 只为兼容老档（v41 起不写新内容）
		# v58：五行元素（件名 → {元素:份数}）与"现在用哪一把"——**新增键，老档读进来是空的**
		"elems": item_elems, "elem_pick": item_elem_pick,
		"furnaces": furnaces, "furnace_slots": furnace_slots,   # v41：多炉
	})
	cf.set_value("world", "pets", {
		"roster": pet_roster, "sel": pet_sel, "follow": pet_follow,
		"apt": pet_apt, "bl": pet_bl, "blood_inv": blood_inv,
		# ㊿z9：升星与同名份数
		"stars": pet_stars, "dups": pet_dups,
	})
	# 优化批㉖：先备份（这次读进来的若是备份本身，就不许再拿它去盖备份，
	# 否则一旦这份是坏的，最后一份好的也没了），再走"写 .tmp → 验 → 顶掉"
	if not _save_from_bak:
		_keep_backup(SAVE_CFG, SAVE_BAK)
	if safe_write(SAVE_CFG, cf):
		_save_from_bak = false
	else:
		print("[账本] 存档没写成功——上一次的档还在（save.cfg / save.bak）")

# 重置测试键用：一切归零＋清旁账（菜单 R 键）
static func reset_full() -> void:
	reset()
	var da := DirAccess.open("user://")
	if da != null:
		for f in ["journey.cfg", "shop.cfg", "wine.cfg", "run.cfg", "save.cfg", "save.bak", "save.cfg.tmp", "run.cfg.tmp"]:
			if da.file_exists(f):
				da.remove(f)
	_save_from_bak = false
	save_game()
	print("[账本] 全档重置完成（reset_full）")

# 【测试用·上线前删】M 键
static func vault_test_fill() -> void:
	vault_deposit({"sword": {0: 2, 1: 1}, "dagger": {2: 1}, "art_wind": {0: 1}, "staff": {0: 1, 1: 1, 2: 1}})
	vault_add_item("sword", 1)
	vault_add_item("dual", 1)
	vault_add_item("dagger", 1)
	vault_add_item("spear", 1)
	vault_add_item("staff", 1)
	vault_add_item("armor_pi", 1)
	vault_add_item("armor_tie", 1)
	vault_add_item("helm_bu", 1)
	vault_add_item("helm_tie", 1)
	vault_add_item("cloak_bu", 1)
	vault_add_item("cloak_ling", 1)
	vault_add_item("art_wind", 1)
	vault_add_item("art_iron", 1)
	vault_add_item("art_breath", 1)
	# R0 自检：合成唯一来源（刚凑齐的暗器散片，直接合了——看控制台与仓库）
	#   ⚠ v57："staff" 是**卡 id**（= 白档暗器「暗器／飞蝗石」），类型键已改成 anqi，id 没动
	var sr := synthesize("staff")
	print("[账本] 合成自检：", sr.get("msg", sr))
	print("[账本] 难度自检：D1=", diff_state(1), " D2=", diff_state(2), "（清一档后 D2 应变 open）")
	print("[账本] 卡池自检（R4）：武器 ", pool_line("weapon"))
	print("[账本] 　　　　　　　武学 ", pool_line("arts"), "（首通档数=", ladder_clears(), "）")
	print("[账本] 红池自检（R4）：武器 ", pool_red_line("weapon"))
	print("[账本] 　　　　　　　武学 ", pool_red_line("arts"))
	print("[账本] 背包自检（优化⑧）：", backpack_line())
	var c1: Array = Loot.roll_container("corpse")
	var c2: Array = Loot.roll_container("safe")
	print("[账本] 搜刮自检（R3）：尸体 ", c1.size(), " 件 ", c1, "｜密柜 ", c2.size(), " 件 ", c2)

# 【测试用·上线前删】G 键：建筑链 + 炼丹链一起开（v16 补的）
static func debug_unlock_chain() -> void:
	map_found = true
	b2_built = true
	cave_opened = true
	winery_built = true
	herbs_granted = true
	dange_built = true
	add_coin("silver", 100)
	add_material("zhi", 2)
	add_material("shen", 2)
	add_material("guo", 2)

# 【测试用·上线前删】H 键
static func debug_give_wine() -> String:
	var d := wine_roll()
	add_wine(str(d["name"]), d["q"], int(d["base"]), str(d["hint"]))
	return str(d["name"])

# 【测试用·上线前删】C 键
static func debug_alchemy_fill() -> void:
	dange_built = true
	disciple_joined = true
	add_material("zhi", 2)
	add_material("shen", 2)
	add_material("guo", 2)

# 【测试用·上线前删】P 键：宠物测试包（v20：两只都发；丹加量——升阶验 fx 用）
static func debug_pet_fill() -> void:
	pet_join("fox")
	pet_join("qing_sun")
	add_coin("silver", 200)
	add_material("bone", 4)
	add_material("rice", 4)
	pills["yangling"] = int(pills.get("yangling", 0)) + 10
	# 优化批㉒：三枚试融合的血脉（玉髓＝灵系，白狐契合；疾风翎＝风系，青隼契合）
	blood_add("bl_yusui", 82)
	blood_add("bl_jifeng", 61)
	blood_add("bl_longxian", 55)
	# ㊿z9：新加的三样也一起发，不然试不出来——
	#   洗灵丹（资质丹）×3 · 同名份数（升星材料，正式来路还没定）· 一枚绝品血脉
	pills["xiling"] = int(pills.get("xiling", 0)) + 3
	pet_dup_add("fox", 3)
	pet_dup_add("qing_sun", 3)
	blood_add("bl_yufeng", 88)

# 调试用：账本归零
static func reset() -> void:
	village_stage = 0
	first_journey_done = false
	first_explore_done = false
	world_difficulty = 1
	world_created = false
	world_history.clear()
	disciple_joined = false
	qingluan_joined = false
	pending_note = ""
	vault_cards.clear()
	vault_items.clear()
	forge_item.clear()
	forge_bag.clear()
	forge_cards.clear()
	forge_seq = 0
	forge_compendium.clear()
	Cards.clear_forged()
	materials.clear()
	material_q.clear()
	materials["atlas"] = 1
	fragments.clear()
	formation = ["player"]
	stage_progress = 0
	pet_roster.clear()
	pet_sel = ""
	pet_follow = ""
	pet_apt.clear()
	pet_bl.clear()
	blood_inv.clear()
	pet_stars.clear()   # ㊿z9：升星账
	pet_dups.clear()    # ㊿z9：同名份数
	_pet_sync()
	exp_pool = 0
	coins = {"wen": 0, "silver": 0, "yuanbao": 0}
	chen_shi = {}
	player_role = {}
	qingluan = {}
	idle_pool_sec = 0
	action = ACTION_START
	sect_favor = 0
	sect_rep = 0
	sect_test = false
	sect_art = false
	sect_joined = false
	sect_contrib = 0
	sect_betrayed = false
	world_seed = 0
	world_tier = 1
	world_prosperity = 0
	time_slot = 0
	time_day = 1
	slot_progress = 0
	region_rep = [0, 0, 0, 0, 0]
	region_seen = [false, false, false, false, false]
	region_walk = [0, 0, 0, 0, 0]
	merchant_stock_slot = ""
	merchant_stock.clear()
	npc_stock.clear()
	region_landmarks.clear()
	npc_budget = -1
	sect_prosperity_rank = 0
	forge_names.clear()
	story_title_prosperity = false
	ng_event_seen = false
	ng_event_choice = -1
	ng_echo_seen = false
	ng_final_seen = false
	ng_final_choice = -1
	ng_wuxia_done = false
	merchant_favor = 0
	wanted = 0
	boss_kills.clear()
	jailed_days = 0
	red_water = 0
	red_water_wall = false
	red_water_market = false
	red_water_garrison = false
	red_water_taxpost = false
	red_water_peace = false
	war_score = 0
	broker_rep = 0
	broker_quest = 0
	broker_pardon = false
	broker_weapon = false
	story_letter = 0
	story_follow = 0
	story_title = ""
	snow_charm = false
	snow_charm2 = false
	north_score = 0
	north_peace = false
	north_wins = 0
	north_weapon = false
	north_tax_day = ""
	north_garrison = false
	ng_plus = 0
	map_owners.clear()
	world_flags.clear()
	current_region = 0
	region_unlocked = [true, true, true, false, false]
	turf_tax_day = ""
	war_notes.clear()
	_idle_last_ts = _idle_now()
	_idle_save()
	level_notes.clear()
	formation_intro_done = false
	map_found = false
	b2_built = false
	cave_opened = false
	winery_built = false
	herbs_granted = false
	dange_built = false
	auto_climb = false
	auto_bg = false   # ㊿q：开新档——自动挑战两种形态一起收
	run_expand_n = 0
	chest_inv.clear()      # v36：宝箱账
	chest_notes.clear()
	chest_set_stage_hint(0)
	# v39：鉴宝行（解锁标记 / 道具背包 / 店里的货仓 / 统计）
	jianbao_unlocked = false
	appraise_tools.clear()
	appraise_offers.clear()
	_appraise_uid = 0
	appraise_opened = 0
	appraise_best = 0
	# v40：新手关卡礼包
	stage_gift_got = false
	stage_gift_opened = 0
	wines.clear()
	pills.clear()
	alchemy = {}
	furnaces = []
	furnace_slots = 1   # v41：回到"一口炉"
	item_stars.clear()    # v35：升星账（星记在件上）
	item_elems.clear()    # v58：五行元素账（件名 → {元素:份数}）
	item_elem_pick.clear()   # v58：现在用哪一把
	strip_saved.clear()   # ㊿v：出征卸装记录——开新档一并清
	role_stars.clear()    # ㊿y：角色星
	shop_day = ""
	shop_used = {}
	wine_day = ""         # v35：品酒坊"今日已酿"——开新档一起清
	wine_used = 0
	collected.clear()
	_collected_loaded = true
	_collected_save()
	diff_cleared.clear()
	_diff_loaded = true
	_diff_save()
	pack_id = "cloth"
	_pack_loaded = true
	_pack_save()
