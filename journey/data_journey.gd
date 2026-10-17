extends RefCounted
const Realm := preload("res://shared/data_realm.gd")   # v121：境界压制
const DataAffixes := preload("res://shared/data_affixes.gd")
const GameState := preload("res://shared/game_state.gd")   # v61：游历敌人按队伍等级档放大要用它
# ============================================================
# 游历数据 v10（用户："让难度档真正加强敌人"——正式趟按档加码；引子趟一个字没动）
# v10：build_nodes_formal 里按档放大每一场战斗的血/攻（FORMAL_HP_PER / FORMAL_ATK_PER）。
#   以前档位只管"路有多长"（16~46 节）与词缀条数，敌人血攻恒定 → 高档只是"走更久"，不是"更难"。
# v9：build_nodes_formal()——正式趟按档排表：五节一轮（武学/兵器/装备/战斗/歇脚＋商店），
#   轮数＝min(2＋难度档, 9)（1 档 3 轮 16 节，每高一档加一轮，九轮封顶 46 节）；
#   全趟只第一节战斗是小怪，其余战斗全是精英（带招、不带大招）；boss 收尾（带大招）。
#   战斗词缀＝affix_n 条，按难度档从 data_affixes 现摇（1~2 档池为空＝不带；与遭遇表同口径）。
#   引子趟照旧吃下面那张老表（新手游历不改）。
# v8（㊿）：正式趟新表的旧版（A/B 交替）——已撤；整个文件只许有一份 build_nodes_formal
#   （两份重名，GDScript 直接报错）。
# v7（㉙b）：①三个"命数"节点（t="fate"）：横财签/翻财签/血路签；title/text/pick 全是文案，
#   逻辑在 journey_stage（_open_fate/_apply_fate）；解锁口径＝出村进度 ≥5。
#   ②EXTRA_ROADS＝血路签追的六节险路（三节精英战 + 黑店/破窑/古渡，见那张表上的说明）。
# v6：①固定战敌人血攻整体上调、后几场挂词缀；②遭遇表 ENCOUNTER_TIERS 增强；
#   encounter_node 按难度带词缀（3~5 档 1 条、6~8 档 2 条、9~10 档 3 条；1~2 档不带）。
#   引子趟不吃：词缀/招数在 duel_battle 里按 mode=="intro" 老闸放行（新手宽容）。
# v5：两场精英战加 "arts"/"ult"（duel_battle v6 认）。数值全是初稿——改表即可。
# 老表 28 节（血路签再+3 节险路）：13 事件 / 3 命数 / 6 战斗 / 2 商店（第12、17节）/ 2 歇脚
# ============================================================

# ============================================================
# ⚠ v46（用户："爬塔和游历的怪技能和大招倍率降低"）：精英/boss 的招数与大招倍率整体下调约 25~30%——
#   大招 2.2~2.5 → 1.6~1.8；带追击的招数（mult+follow 两段）也一起压，理由：怪的招比玩家的武学还重，
#   玩家堆了防御/站位也扛不住"一发大招半条命"。只动下面这几张敌表（引子趟老表 + 正式趟精英名录 +
#   boss + EXTRA_ROADS），玩家武学（data_cards）一个字没碰。
#   口径：纯数值——血量/攻击/词缀/掉落与档位加码（FORMAL_HP_PER / FORMAL_ATK_PER）一条没动；
#   蓄势类 charge 的 mult 是"下一手更重"的那个倍率，跟着一起压；护体/回气不涉及倍率，原样保留。
# ============================================================

static func build_nodes() -> Array:
	# ============================================================
	# v139（用户口述的新引子）：**一场雨、两场仗、一个老人**——20 节，全趟只有两个敌人。
	#   旧表（30 节 · 6 场仗 · 13 个三选一）整张撤掉。现在的线是：
	#     ① 崖底爬出来 → 尸骨上的锈剑（tip=intro_equip：只教"装备"）
	#     ② 追兵：半血、只能普攻（节点 seal=["arts","ult"]），**输了就是殒命**
	#        —— ⚠ 用户定："怪物数值调低就行，引子总共就俩怪"，所以不做"打晕拖走"的特判。
	#     ③ 昏迷 → 醒来（破旧茅屋）→ 老人（**不给名字**：让他死得像个普通人，
	#        等陈石出场时才更震撼）→ 治伤（rest 全复）
	#     ④ 床底：固定翻找（search 节点，必出）→ 疾风剑法三卷 → 合成教学（tip=intro_synth）
	#     ⑤ 次日：门被踹开、老人的人头 → boss
	#     ⑥ 抱着老人下山 → 结算
	#   ⚠ 茅屋段挂了 scene="hut"：背景没有图，由 journey_backdrop.draw_hut() 现画（暗墙＋漏顶＋药炉）。
	#   ⚠ boss 这一场现在是**普通战**；"打不动 → 嘲讽 → 教学大招 → 滑动 QTE"那套剧本战是下一步。
	# ============================================================
	return [
		{"t": "story", "text": "雨砸在脸上，睁不开眼。\n你从崖底的死人堆里往上爬——泥是软的，手是抖的。"},
		{"t": "story", "text": "胸口还插着半截断刃。没敢拔。\n佩剑不知跌在哪个沟里了——一身武艺，剩不到三成。"},
		{"t": "story", "tip": "intro_equip",
			"text": "走了半日，雨小了些。\n路边半坐着一具风干的尸骨，骨头缝里长着草，手里攥着一柄铁剑，锈得厉害。"},
		{"t": "story", "text": "你把剑在裤腿上蹭了两下，锈没蹭掉。\n身后的雨里，有脚步声。不急，不缓——是人踩泥的声音。"},
		{"t": "battle", "name": "追兵", "money": [30, 40], "seal": ["arts", "ult"],
			"text": "三个人。为首那个眯着眼上下打量你，笑了：「就这半条命，也值一趟？」",
			"foe": {"hp": 45, "atk": 7, "spd": 96, "weapon": "dagger", "hat": "toujin", "cape": "none", "color": [0.30, 0.26, 0.24], "scale": 0.96}},
		{"t": "story", "text": "最后一个人倒在泥里。\n你也快站不住了——胸口那道口子在往外渗，热得发烫。"},
		{"t": "story", "text": "眼前一黑。你伸手去扶，什么也没扶着。\n雨声忽然很远。"},
		{"t": "story", "scene": "hut",
			"text": "屋顶是黑的，有一处漏，滴在泥地上。\n墙角堆着干柴，火气里混着药味。\n有人说：「醒了。别动。」"},
		{"t": "story", "scene": "hut",
			"text": "老人把碗搁在床边。\n「山上的屋子空了好些年，我就在这儿落脚。下去一趟要半天——我背不动你。」"},
		{"t": "story", "scene": "hut",
			"text": "「村里去不得。你后头跟着人。」\n他抬手指了指门外，「我是在坡下把你拖上来的。」"},
		{"t": "story", "scene": "hut", "text": "「忍着点。这伤，得慢慢养。」"},
		{"t": "rest", "scene": "hut",
			"text": "一连几天。老人每天来换一次药，药是苦的，烫的。\n你能坐起来了，能扶着墙走到门口，能听见屋檐在滴水。"},
		{"t": "search", "scene": "hut", "title": "床底",
			"cards": [{"set": "art_wind", "parts": [0, 1, 2]}],
			"text": "他不在的时候，屋里静得能听见自己心跳。\n你扶着床沿蹲下去——床底下有个布包。"},
		{"t": "story", "scene": "hut", "tip": "intro_synth",
			"text": "三张散页，纸是皱的，边角被虫蛀了。\n是剑法。你还记得这几笔。"},
		{"t": "story", "scene": "hut", "text": "次日，有脚步声。\n你以为又是他，刚要抬头——"},
		{"t": "story", "scene": "hut",
			"text": "木门被一脚踹开，撞在土墙上。\n门口站着个人，手里提着一颗人头。\n是老人的。"},
		{"t": "story", "scene": "hut",
			"text": "「找到你了。」\n他把人头往地上一丢，滚到门槛边。\n「三年了。你这条命，居然还没断。」"},
		{"t": "battle", "name": "追命人", "money": [60, 90], "elite": true, "scene": "hut",
			"text": "「来啊。你还能还手？」",
			"arts": [
				{"name": "追命一刀", "target": "mid", "kind": "damage", "mult": 1.2, "cd": 3, "desc": "刀走直线，不给你换气的空"},
			],
			"foe": {"hp": 120, "atk": 4, "spd": 99, "weapon": "sword", "hat": "douli", "cape": "long", "color": [0.14, 0.12, 0.16], "scale": 1.06}},
		{"t": "story", "text": "风从屋里穿过去。\n你站着。他站着——然后跪下去了。"},
		{"t": "story", "text": "你把老人抱起来。他比活着的时候轻。\n雨停了。山下的路被冲得不成样子，你一直走到天黑。"},
		{"t": "settle", "text": "路到了尽头。你卸下背囊，把这一路得来的东西一样样摆在石头上。"},
	]

# ---- ㊿c：正式趟节点表——五节一轮（武学/兵器/装备/战斗/歇脚＋商店），轮数随档涨，boss 收尾 ----
#   轮数＝min(2＋档, 9)：1 档＝3 轮＝16 节；每高一档加 1 轮；九轮封顶＝46 节（再加一轮就是 51，过五十线）。
#   全趟只第一节战斗是小怪，往后的战斗全是精英（带招、不带大招）；boss 带大招。
#   词缀＝affix_n 条，按难度档从 data_affixes 现摇（1~2 档池为空＝不带）。
#   引子趟照旧吃上面那张老表（新手游历不改）。
#
# ⚠ v10（用户："让难度档真正加强敌人"）：**档位以前只管"路有多长"，敌人血攻一条都不变**——
#   1 档和 10 档碰到的黑风舵主都是 135 血 / 6 攻，高档只是多走几节、多两条词缀。
#   现在按档给每一场战斗加码（只动**正式趟**；引子趟那张老表与 INTRO_EASE 一个字没碰）：
#     血量 ×(1 + FORMAL_HP_PER × (档-1))     FORMAL_HP_PER = 0.12
#     攻击 ×(1 + FORMAL_ATK_PER × (档-1))    FORMAL_ATK_PER = 0.08
#   → 1 档原样；5 档 ×1.48 / ×1.32；10 档 ×2.08 / ×1.72。
#   为什么血比攻涨得多：攻涨太狠会变成"一巴掌拍死"（爬塔刚踩过这个坑，见 tower.gd 那段），
#   而血涨上去只是"这仗更久"——高档该是"更硬"，不是"更不讲理"。
#   ⚠ 想调手感只改下面这两个数；填 0 就退回"档位只管长度"的旧样子。
const FORMAL_HP_PER := 0.12     # 每高一档：血量 +12%（1 档不加）
const FORMAL_ATK_PER := 0.08    # 每高一档：攻击 +8%（1 档不加）
const FORMAL_CYCLE_CAP := 9

# ============================================================
# v61（用户："对标现在正常1000级属性难度，阶梯式提升爬塔与游历难度"）
#
#   问题：正式趟的敌人血/攻是**手写死的**（拦路恶犬 55 血 / 3 攻，寨主 400 血 / 15 攻），
#   只随"难度档"加码（1 档原样 ~ 10 档 ×2.08）。所以满级队伍（1000 级：攻 1000~2000）
#   打这些怪是**一下一个**，游历整条线没有挑战。
#
#   办法：按**队伍等级档**再阶梯式放大——与爬塔同一套尺子（每 100 级一档）：
#     血量 ×(1 + JOURNEY_HP_PER × 档)     攻击 ×(1 + JOURNEY_ATK_PER × 档)
#     档 = (队里最高等级 − 1) / 100 取整   → 1~100 级＝0 档（原样）、101~200 级＝1 档 …
#   1000 级（10 档）时：血 ×16、攻 ×15.5 —— 寨主 400 血/15 攻 → **6400 血 / 232 攻**，
#   配满级三人（一回合 ~3500 伤害）≈ 两回合；它一巴掌 232，大招 ×2.5 ≈ 580，满级少侠
#   4486 血能挨七八下。低等级那段（0 档）与原来一模一样，新手游历不受影响。
#   想更硬/更软：只改这两个 PER（各填 0 ＝ 退回"只看难度档"的旧样子）。
const JOURNEY_LV_STEP := 100    # 每多少级进一档
# v62h（成长重排：升级只加气血 · 突破按根骨 · 兵器攻击 ×1.7 · 防具气血 ×5.4）：
#   这两个 PER 是照"玩家从 1 级到 1000 级涨了多少"重推的：
#     · 玩家输出（攻击）1 级 25 → 1000 级约 199 = **×8**   → 血 PER 1.35 → **0.80**（9 档 ×8.2）
#     · 玩家气血 1 级 100 → 1000 级约 1489（＋防具）= **×15** → 攻 PER 1.30 → **1.40**（9 档 ×13.6）
#   ⚠ 塔那边这次是"调形状"（HP_LIN 1.80→0.76），游历这边是按等级档的阶梯，所以两处
#     调法不同但目标一致：**全程 1.5~2 回合清一场**。数值先这样落地，实机再微调。
const JOURNEY_HP_PER := 0.80    # 每档：血量 +80%（10 档 ≈ ×8.2 · v62h：1.35 → 0.80）
const JOURNEY_ATK_PER := 1.40   # 每档：攻击 +140%（10 档 ≈ ×13.6 · v62h：1.30 → 1.40）
# ⚠ v62（伤害增幅减半那一批）：玩家满配输出约 −23%、有效血量约 −20%，
#   所以游历这两条也收一点（少收一点＝比原来更硬一档，保留卡关感）。
#   1000 级（第 9 档）时寨主：400 血 / 15 攻 → 约 5260 血 / 194 攻（原来 5800 / 211）。

const ARTS_FLAVOR := [
	"破庙香案下压着半卷残书，纸起了毛边，字句还认得出。",
	"崖壁上刻着几行旧字，日晒雨淋这么多年，笔锋还在。",
	"驿站墙缝里塞着几页旧纸，抽出来一看，是半篇拳谱。",
]
const WEAPON_FLAVOR := [
	"废校场的兵器架上剩着些零碎刀枪，挑得出能用的。",
	"渡口缆桩边弃着几件兵器，柄上缠的布还没烂。",
	"铁匠铺门口靠着几件没修完的兵器，主人说给钱就带走。",
]
const GEAR_FLAVOR := [
	"货栈角落里翻出个旧木匣，里头是些护具的零片。",
	"晒场边晾着一领拆了线的旧甲，风一吹，甲片叮当响。",
	"船篷底下的旧箱里，滚着几片打磨过的玉块。",
]
const REST_FLAVOR := [
	"镇口茶棚支起摊子——歇脚吃饭，顺道逛摊。",
	"山坳里的驿站：先调息，再看货。",
	"渡口茶摊挨着货郎担，就在江风里歇一歇。",
]

# v105（用户："上品有事件后 增加新节点 目前最高不是41节嘛 加到56节"）：
#   轮数改成**按品级那张表**（品级→内部难度 1/3/6/8）：
#     凡品 4 轮 ＝ 21 节 · 良品 6 轮 ＝ 31 节 · 上品 8 轮 ＝ 41 节 · **极品 11 轮 ＝ 56 节**
#   （上品/极品还会往里插"事件卡"节点——那是下一步，见 docs/事件卡与善恶_设计稿.md）
const CYCLES_BY_DIFF := {1: 4, 3: 6, 6: 8, 8: 11}

# v111（用户："命数后续可以加在增加的节点里 击败敌人后的节点中 当然如果节点不够用可以再加一些"）：
#   **每到"击败敌人之后"插一个命数节点**（沿用路上那套签摊弹窗：接这注／不收这注）。
#   开局只能带一张（用户定过），路上再捡的就往上累加——这是"命数"从一次性选择变成 build 的那一步。
#   fid 留空＝**开节点时**从"还没接过的"里随机挑一个（避免摆出已经拿过的签，白跑一趟）。
#   ⚠ 节点数因此变长：上品 41 → 49 · 极品 56 → 67（用户："节点不够用可以再加一些"）。
const FATE_IDS := ["fate_greed", "fate_scavenge", "fate_bloodpath", "fate_shortrope",
	"fate_fullbag", "fate_noarmor", "fate_endure", "fate_iron", "fate_allin",
	"fate_venom", "fate_sharpen"]

static func fate_nodes_on() -> bool:
	# 命数解锁（通关良品）之后的路，才有"战后签摊"
	return GameState.phase_cleared(1, GameState.MODE_NORMAL)

static func _formal_fate() -> Dictionary:
	return {"t": "fate", "fid": ""}

static func formal_cycles(diff: int) -> int:
	var d := maxi(1, int(diff))
	if CYCLES_BY_DIFF.has(d):
		return int(CYCLES_BY_DIFF[d])
	# 表外的档（老存档/测试）按老式子兜底，封顶 11 轮
	return mini(3 + d, 11)

static func formal_node_count(diff: int) -> int:
	# v111：命数节点也要算进去（不然出征屏的"路程 N 节"与失败完成度都会对不上）
	var c := formal_cycles(int(diff))
	return c * 5 + 1 + (c if fate_nodes_on() else 0)

static func build_nodes_formal(diff := 1) -> Array:
	var out: Array = []
	var cyc := formal_cycles(int(diff))
	# v107（用户："上品有事件后 增加新节点"）：**上品/极品**每轮插一张"事件卡"——位置在轮首，
	#   总长不变（把这一轮的第 2 张残页事件顶掉，见下面那句 pop）——凡品/良品一个卡都不插。
	# v110（用户："事件是通关上品解锁"）：闸从"这一趟是上品/极品"改成**全局解锁**——
	#   通关上品（其「普通」）之后，往后每一趟都可能碰上事件卡（与搜刮/命数同一种口径）。
	#   所以第一次见到卡，是在**极品**那一趟。
	var with_card: bool = GameState.event_unlocked()
	var fate_on: bool = fate_nodes_on()   # v111：命数节点（通关良品之后）
	for c in cyc:
		if with_card:
			out.append({"t": "choice"})
		out.append({"t": "event", "title": "武学残页", "pool": "arts", "text": _flavor(ARTS_FLAVOR, c)})
		out.append({"t": "event", "title": "兵器残卡", "pool": "weapon", "text": _flavor(WEAPON_FLAVOR, c)})
		if not with_card:
			out.append({"t": "event", "title": "装备残片", "pool": "gear", "text": _flavor(GEAR_FLAVOR, c)})
		out.append(_formal_battle(c))
		if fate_on:
			out.append(_formal_fate())   # v111：击败敌人之后的节点——签摊
		out.append({"t": "rest_shop", "text": _flavor(REST_FLAVOR, c)})
	out.append(_formal_boss())
	var ni := 0
	for n_v in out:
		var n: Dictionary = n_v
		var cnt := int(n.get("affix_n", 0))
		if cnt > 0:
			# ㊿c：词缀＝按难度档从 data_affixes 现摇（1~2 档池为空＝不带，与遭遇表同口径）
			var got: Array = DataAffixes.roll_from(DataAffixes.pool_for_diff(maxi(1, int(diff))), cnt)
			if not got.is_empty():
				n["affixes"] = got
		# v10：按档给敌人加码（只正式趟；引子趟不走这里）
		if str(n.get("t", "")) == "battle":
			_scale_foe(n, int(diff), ni)   # v63：带节数进去（轴三/轴四按它加码）
		ni += 1
	return out

# v10：按难度档放大这一场的敌人血/攻（1 档＝原样）。写回节点里的 foe 字典本身，
#   后面 duel_battle._build_foes 照旧读它——不动那边的任何代码。
# v61：再叠一层"队伍等级档"（见上面 JOURNEY_* 那段）——两把尺子相乘：
#   难度档＝玩家自己选的挑战，等级档＝对标 1000 级的天花板。
# v62i（用户："爬塔和游历总体难度加强30% 给点压迫"）：
#   游历敌人**血与攻整体 ×1.3**——用一个总系数，而不是去改 ENCOUNTER_TIERS / 每一场的基础值。
#   与爬塔那四个常数（也 ×1.3）同步，两边一起紧一档。
#   ⚠ 它**无条件**生效（原来 `d<=0 and tier<=0` 会直接 return，那样难度 1 + 低等级一点没变），
#     所以新手第一趟也会感到这 30%——这正是"给点压迫"的意思。
# v63（用户："游历要变成四轴难度…整体难度再加20%"）：
#   轴一＝难度档 · 轴二＝等级档（原有）；**轴三＝每过一节难度 +8%**（节数按 0 起）；
#   **轴四＝品质线**：8 节起 +20% → 16 节 +40% → 24 节 +80% → 32 节 +160%（40 节到顶，封住）。
# v63b（用户："游历每节难度 8%→1.5%（只在当前游历难度这刀生效）· 游历整体难度降低 25%"）：
#   FOE_MUL 1.56 → **1.17**（×0.75）；AXIS3_PER 0.08 → **0.015**。
# v128（用户："爬塔和游历整体难度提升15%"）：1.17 → **1.35**（≈ +15%）
const FOE_MUL := 1.35
const AXIS3_PER := 0.015              # 每过一节：难度 +1.5%（原 8% → 用户下调）
const AXIS4_STEPS := [8, 16, 24, 32]  # 品质线：良品/上品/极品/绝品
const AXIS4_PCT := [0.20, 0.40, 0.80, 1.60]

static func axis4_mul(node_i: int) -> float:
	var m := 0.0
	for k in AXIS4_STEPS.size():
		if node_i >= int(AXIS4_STEPS[k]):
			m = float(AXIS4_PCT[k])
	return 1.0 + m

# v86：游历的元素怪门槛（用户：「游历难度25后加入元素怪」）。爬塔那边是 800 关，
#   两边难度刻度不同，所以各留各的常量——以后要调只改这一个数。
# v113（用户："同时增加元素词缀和元素怪 和元素技能"）：
#   原来写的是"难度 25 起"——四品级制的内部难度只有 1/3/6/8，**永远到不了** ✗。
#   现在改成 **6 ＝ 上品起**：上品/极品的敌人带五行（elem 一格），它出手就按五行通道算
#   （吃抗性、暴击规则不同、有增伤聚合）＝"元素怪 ＋ 元素技能"一起到位。
const ELEM_FROM_DIFF := 6
const CHAPTER_ELEM := ["metal", "wood", "water", "fire", "earth"]
const FOE_OWN_RES := 30             # 对自己那一属性的抗性（百分点）——与 tower 同口径

static func _scale_foe(n: Dictionary, diff: int, node_i := 0) -> void:
	# v99（出征屏三档：简单 0.5 / 普通 1.0 / 困难 2.0）：出征屏选的那一档，先乘在血/攻上。
	#   引子趟不设（deploy 默认 1.0）——新手第一趟照旧。
	var tier_mul: float = maxf(0.0, GameState.deploy_foe_mul)
	# v113（用户："上品之后【包括上品】游历整体难度提升50%"）：上品/极品这一挡整体 ×1.5。
	#   与"模式倍率"（简单 0.5 / 普通 1 / 困难 2）相乘，所以上品困难 ＝ ×3.0。
	if GameState.deploy_phase() >= 2:
		tier_mul *= 1.5
	var d := maxi(1, diff) - 1
	var tier := party_tier()
	var f: Dictionary = n.get("foe", {})
	if f.is_empty():
		return
	var hp_mul := FOE_MUL
	var atk_mul := FOE_MUL
	if d > 0 or tier > 0:
		hp_mul *= (1.0 + FORMAL_HP_PER * float(d)) * (1.0 + JOURNEY_HP_PER * float(tier))
		atk_mul *= (1.0 + FORMAL_ATK_PER * float(d)) * (1.0 + JOURNEY_ATK_PER * float(tier))
	# v63：轴三（每过一节 +8%）× 轴四（品质线：8/16/24/32 节 → +20/40/80/160%）
	var n3 := 1.0 + AXIS3_PER * float(node_i)
	var n4 := axis4_mul(int(node_i))
	hp_mul *= n3 * n4
	atk_mul *= n3 * n4
	# v99：出征屏那一档（简单 0.5 / 普通 1.0 / 困难 2.0）
	hp_mul *= tier_mul
	atk_mul *= tier_mul
	# v121（用户："还有境界压制【怪也可以有境界压制】"）：
	#   怪的境界跟着这一档走（凡/良/上/极 → 2/6/12/16 境），再按 (我方境界 − 怪境界) 折算血攻——
	#   高境界的怪碾压你，低境界的怪被你压制。同一个尺子在 GameState.advance / data_realm。
	var foe_realm := clampi(int(diff) * 2, 0, 17)
	f["realm"] = foe_realm
	var sup := Realm.suppress_mul(int(GameState.advance_lv), foe_realm)
	hp_mul *= sup
	atk_mul *= sup
	f["hp"] = maxi(1, int(round(float(f.get("hp", 60)) * hp_mul)))
	f["atk"] = maxi(1, int(round(float(f.get("atk", 8)) * atk_mul)))
	# v86（用户：「游历难度25后加入元素怪」）：
	#   难度 25 起敌人带五行——**跟爬塔同一套口径**（打你就是元素伤害：不吃你的防御、
	#   走抗性、不可暴击；它自己对自己那一属性抗 30%）。按难度 + 节数轮换，不会场场同一种。
	if maxi(1, diff) >= ELEM_FROM_DIFF:
		var fe: String = str(CHAPTER_ELEM[(maxi(1, diff) + node_i) % CHAPTER_ELEM.size()])
		f["elem"] = fe
		f[fe + "_res"] = FOE_OWN_RES
	n["foe"] = f

# v61：队伍等级档——取"队里最高等级"（1~100 级＝0 档，之后每 100 级一档）
#   取最高而不是平均：带一个满级大哥出门，怪就该按大哥的档次来。
static func party_tier() -> int:
	var lv := 1
	for id in ["player", "chen_shi", "qingluan"]:
		lv = maxi(lv, int(GameState.role_data(str(id)).get("lv", 1)))
	return maxi(0, (lv - 1) / JOURNEY_LV_STEP)

static func _flavor(rows: Array, i: int) -> String:
	return str(rows[i % rows.size()])

# 战斗：第 0 轮是小怪，往后全是精英
static func _formal_battle(cycle_idx: int) -> Dictionary:
	if cycle_idx == 0:
		return {
			"t": "battle", "name": "拦路恶犬", "money": [12, 18], "affix_n": 1,
			"text": "林口窜出一条瘦狗，龇着牙，不肯让路。",
			"foe": {"hp": 55, "atk": 3, "spd": 105, "weapon": "fist", "hat": "none", "cape": "none", "color": [0.42, 0.32, 0.24], "scale": 0.86},
		}
	return _formal_elite(cycle_idx)

# 精英名录（按轮次顺序出场，越往后越硬；无 ult——大招只留给 boss）
# ⚠ v46：名录里的招（含上面引子趟老表同名的黑风掠阵 / 单臂快刀）倍率一并下调，见文件头那段。
static func _formal_elite(i: int) -> Dictionary:
	var roster: Array = [
		{
			"name": "黑风舵主", "money": [30, 42], "text": "一骑快马自坡上冲下，黑袍蒙面，勒马横刀，挡在路心。",
			"arts": [
				{"name": "黑风掠阵", "target": "mid", "kind": "dash", "mult": 1.0, "follow": 0.6, "cd": 3, "desc": "马快刀更快——连削两刀"},
				{"name": "勒马回气", "kind": "heal", "heal_pct": 0.2, "cd": 5, "desc": "勒住缰绳缓一口气，回血两成"},
			],
			"foe": {"hp": 135, "atk": 6, "spd": 96, "weapon": "dual", "hat": "none", "cape": "short", "color": [0.16, 0.15, 0.20], "scale": 1.06},
		},
		{
			"name": "守关·独臂刀客", "money": [36, 48], "text": "山道尽头，一个独臂刀客靠着石壁，刀横在膝上。他抬眼看了看你。",
			"arts": [
				{"name": "单臂快刀", "target": "mid", "kind": "damage", "mult": 1.2, "cd": 3, "desc": "独臂出刀反而更快更直"},
				{"name": "背崖而立", "kind": "guard", "turns": 2, "cut": 0.80, "cd": 5, "desc": "背靠石壁——此后两下挨打各减两成"},
			],
			"foe": {"hp": 160, "atk": 8, "spd": 94, "weapon": "sword", "hat": "douli", "cape": "long", "color": [0.22, 0.24, 0.34], "scale": 1.10},
		},
		{
			"name": "黑风副寨主", "money": [45, 60], "text": "山口横着一面黑风旗，旗下有人按刀而立：「此路，归黑风寨。」",
			"arts": [
				{"name": "快刀截脉", "target": "mid", "kind": "damage", "mult": 1.25, "cd": 3, "desc": "刀走轻快，专削下三路"},
				{"name": "寨门横练", "kind": "guard", "turns": 2, "cut": 0.78, "cd": 5, "desc": "横练的筋骨一绷——此后两下挨打各减两成出头"},
			],
			"foe": {"hp": 190, "atk": 9, "spd": 92, "weapon": "sword", "hat": "toujin", "cape": "short", "color": [0.30, 0.24, 0.30], "scale": 1.08},
		},
		{
			"name": "亡命枪客", "money": [52, 68], "text": "断桥头，一个枪客负手站着，枪插在脚边：「借道，先过我。」",
			"arts": [
				{"name": "枪出如龙", "target": "sweep", "kind": "dash", "mult": 1.05, "follow": 0.6, "cd": 3, "desc": "一枪扎来，枪尾又扫"},
				{"name": "吞息回力", "kind": "heal", "heal_pct": 0.2, "cd": 5, "desc": "退半步喘定，回血两成"},
			],
			"foe": {"hp": 215, "atk": 10, "spd": 97, "weapon": "spear", "hat": "none", "cape": "short", "color": [0.40, 0.30, 0.24], "scale": 1.10},
		},
		{
			"name": "黑风堂主", "money": [60, 80], "text": "寨门三层台阶，堂主立在最高一级，双刀交叉抱在胸前。",
			"arts": [
				{"name": "双刀卷雪", "target": "sweep", "kind": "dash", "mult": 1.1, "follow": 0.65, "cd": 3, "desc": "双刀翻飞，像一卷雪压过来"},
				{"name": "坐关吐纳", "kind": "heal", "heal_pct": 0.22, "cd": 5, "desc": "站桩一沉，回血两成有余"},
			],
			"foe": {"hp": 245, "atk": 11, "spd": 96, "weapon": "dual", "hat": "none", "cape": "long", "color": [0.18, 0.14, 0.22], "scale": 1.12},
		},
		{
			"name": "断魂崖·剑客", "money": [70, 90], "text": "断魂崖上风大，剑客的衣角猎猎作响，剑尖垂着三寸，没抬头。",
			"arts": [
				{"name": "断魂三式", "target": "mid", "kind": "dash", "mult": 1.1, "follow": 0.7, "cd": 3, "desc": "一式接一式，不给你换气的空"},
				{"name": "崖前蓄势", "kind": "charge", "mult": 1.4, "cd": 5, "desc": "剑收鞘半寸——下一手更重"},
				# v54：闭窍——用户："闭窍是针对玩家的"（压住你的自带/被动功法/五问天赋/角色星）
				{"name": "点窍手", "target": "front", "kind": "damage", "mult": 0.95, "cd": 5,
					"apply": {"id": "nopassive", "turns": 3, "stacks": 1},
					"desc": "剑指虚点——「闭窍」三手：你的被动全被压住"},
			],
			"foe": {"hp": 270, "atk": 12, "spd": 100, "weapon": "sword", "hat": "douli", "cape": "long", "color": [0.20, 0.22, 0.32], "scale": 1.12},
		},
		{
			"name": "铁掌阿七", "money": [80, 105], "text": "浮桥头，赤手汉子把拳面在桥栏上蹭了蹭：「过桥钱——用你的手腕来付。」",
			"arts": [
				{"name": "崩山掌", "target": "sweep", "kind": "damage", "mult": 1.25, "cd": 3, "desc": "一掌拍下来，桥板都嗡一声"},
				{"name": "沉桥吐纳", "kind": "heal", "heal_pct": 0.2, "cd": 5, "desc": "桥心一沉，回血两成"},
			],
			"foe": {"hp": 295, "atk": 13, "spd": 95, "weapon": "fist", "hat": "toujin", "cape": "none", "color": [0.36, 0.26, 0.20], "scale": 1.10},
		},
		{
			"name": "黑风左使", "money": [90, 120], "text": "寨旗底下立着个提枪的人，枪尖点地：「堂主折了，我接着守——出枪吧。」",
			"arts": [
				{"name": "回马枪", "target": "mid", "kind": "dash", "mult": 1.1, "follow": 0.65, "cd": 3, "desc": "一退一进，枪从意想不到的角度来"},
				{"name": "按兵不动", "kind": "guard", "turns": 2, "cut": 0.78, "cd": 5, "desc": "枪一横——此后两下挨打各减两成出头"},
				{"name": "点窍手", "target": "front", "kind": "damage", "mult": 0.95, "cd": 5,
					"apply": {"id": "nopassive", "turns": 3, "stacks": 1},
					"desc": "枪尾一压——「闭窍」三手：你的被动全被压住"},
			],
			"foe": {"hp": 320, "atk": 14, "spd": 98, "weapon": "spear", "hat": "none", "cape": "long", "color": [0.14, 0.16, 0.24], "scale": 1.14},
		},
	]
	var e: Dictionary = roster[clampi(i - 1, 0, roster.size() - 1)].duplicate(true)
	e["t"] = "battle"
	e["elite"] = true
	e["affix_n"] = 2
	return e

# boss 收尾——带大招
# ⚠ v46：boss 的黑风刀法与大招风卷残云同批下调（大招 2.5 → 1.8）。
static func _formal_boss() -> Dictionary:
	return {
		"t": "battle", "name": "黑风寨主", "money": [150, 220], "boss": true, "affix_n": 2,
		"text": "寨门大开。黑风寨主负手立于阶前，声音不高：「到了这一步……来吧。」",
		"arts": [
			{"name": "黑风刀法", "target": "sweep", "kind": "damage", "mult": 1.25, "cd": 3, "desc": "刀风发黑——寨里压箱底的刀法"},
			{"name": "横练护体", "kind": "guard", "turns": 3, "cut": 0.75, "cd": 5, "desc": "筋骨绷紧——此后三下挨打各减两成半"},
			# v54：寨主会点窍——「闭窍」针对玩家（压住自带/被动功法/五问天赋/角色星三手）
			{"name": "点窍手", "target": "front", "kind": "damage", "mult": 0.95, "cd": 5,
				"apply": {"id": "nopassive", "turns": 3, "stacks": 1},
				"desc": "指风点到窍穴上——「闭窍」三手：你的被动全被压住"},
		],
		"ult": {"name": "风卷残云", "mult": 1.8, "desc": "整个寨子压上来的一击——怒气满时放出"},
		"foe": {"hp": 400, "atk": 15, "spd": 102, "weapon": "sword", "hat": "none", "cape": "long", "color": [0.12, 0.12, 0.18], "scale": 1.18},
	}

# ---- ㉙b：血路签追的三节险路（t="battle"；第三节是带招精英） ----
# ⚠ v46：第三节那手石进跟着一起压（1.7 → 1.25）。
# v62j（用户："里面有个多三关 这三关改为三个精英关" → "血路签 多加一些不同的"）：
#   血路签追加的险路：**3 节 → 6 节**，其中**三节是精英关**（位置 1/3/5，各自带招数+词缀），
#   另外三节是**不同的类型**——黑店（商店）/ 破窑（歇脚）/ 古渡（事件），
#   免得整条近道从头到尾只有"打打打"。插入位置仍是第 1 节之后（出发就排好）。
#   ⚠ 精英那三节的**血量/攻击没动**：它们本来就要吃 FOE_MUL(×1.3) 与难度/等级档的加码，
#     这里只补"精英的身份"（奖励 + 招数 + 词缀）。
const EXTRA_ROADS := [
	{"t": "battle", "name": "险道·黑松林", "money": [36, 48], "elite": true, "affixes": ["thorns"],
		"arts": [
			{"name": "松涛斩", "target": "mid", "kind": "damage", "mult": 1.25, "cd": 3, "desc": "刀借松风，一击 ×1.25"},
		],
		"text": "近道钻进黑松林，风一过，松针簌簌地落。有人在林深处等你。",
		"foe": {"hp": 150, "atk": 7, "spd": 97, "weapon": "sword", "hat": "toujin", "cape": "short", "color": [0.20, 0.24, 0.20], "scale": 1.04}},
	{"t": "shop", "text": "崖下有一间黑店，幌子破得只剩半边，柜台后的掌柜笑得太殷勤——近道上没有别的铺子，价随他开。"},
	{"t": "battle", "name": "险道·断涧桥", "money": [38, 50], "elite": true, "affixes": ["swift"],
		"arts": [
			{"name": "断涧镖", "target": "mid", "kind": "damage", "mult": 1.30, "cd": 4, "desc": "暗器走一线，一击 ×1.30"},
		],
		"text": "栈桥断了半截，桥头守着一个不说话的汉子。",
		"foe": {"hp": 165, "atk": 8, "spd": 101, "weapon": "anqi", "hat": "none", "cape": "none", "color": [0.34, 0.28, 0.24], "scale": 1.05}},
	{"t": "rest", "text": "半山有孔塌了口子的旧窑，窑里还堆着半窑干柴。你把火生起来，靠着窑壁歇一歇——外面风声像有人走动。"},
	{"t": "battle", "name": "险道·乱石滩", "money": [42, 56], "elite": true, "affixes": ["fury"], "text": "乱石滩头，一个人负手等着——「借道费，命一条。」",
		"arts": [
			{"name": "石进", "target": "mid", "kind": "damage", "mult": 1.25, "cd": 3, "desc": "踏石扑进，一击极重"},
		],
		"foe": {"hp": 180, "atk": 9, "spd": 95, "weapon": "dual", "hat": "douli", "cape": "long", "color": [0.26, 0.22, 0.30], "scale": 1.08}},
	{"t": "event", "title": "古渡沉船", "pool": "arts", "text": "近道尽头是条淤死的古渡，半条沉船搁在泥里，舱板的缝中露出油布包的一角。"},
]

# ---- R3 遭遇：每档默认敌组（子批②）；优化批㉔：全方位增强＋按档带词缀 ----
const ENCOUNTER_TIERS := [
	{"name": "窥路的拾荒人", "hp": 70, "atk": 3, "spd": 100, "weapon": "dagger", "color": [0.45, 0.38, 0.30]},
	{"name": "拦路的游勇", "hp": 90, "atk": 4, "spd": 96, "weapon": "sword", "color": [0.42, 0.40, 0.44]},
	{"name": "尾随的恶客", "hp": 110, "atk": 5, "spd": 98, "weapon": "dagger", "color": [0.38, 0.30, 0.34]},
	{"name": "黑风探子", "hp": 130, "atk": 6, "spd": 95, "weapon": "dual", "color": [0.30, 0.32, 0.36]},
	{"name": "追踪的猎手", "hp": 155, "atk": 7, "spd": 102, "weapon": "spear", "color": [0.34, 0.38, 0.30]},
	{"name": "亡命之徒", "hp": 180, "atk": 8, "spd": 93, "weapon": "anqi", "color": [0.44, 0.34, 0.28]},
	{"name": "悬赏杀手", "hp": 205, "atk": 9, "spd": 106, "weapon": "dagger", "color": [0.24, 0.22, 0.30]},
	{"name": "悍匪头目", "hp": 235, "atk": 10, "spd": 90, "weapon": "sword", "color": [0.50, 0.30, 0.22]},
	{"name": "独行刀客", "hp": 265, "atk": 12, "spd": 104, "weapon": "dual", "color": [0.22, 0.24, 0.34]},
	{"name": "无名宗师", "hp": 300, "atk": 14, "spd": 110, "weapon": "spear", "color": [0.18, 0.18, 0.24]},
]

static func encounter_node(d: int) -> Dictionary:
	var i := clampi(d, 1, ENCOUNTER_TIERS.size()) - 1
	var t: Dictionary = ENCOUNTER_TIERS[i]
	var foe := {
		# v62i：这张表的值**没跟着队伍等级档走**（它是"本档默认敌组"，是遭遇战的兜底来源），
		#   所以那 30% 在这里单独补上——不然从这儿出的敌人会比节点里的小一号。
		"hp": maxi(1, int(round(float(t.get("hp", 60)) * FOE_MUL))),
		"atk": maxi(1, int(round(float(t.get("atk", 4)) * FOE_MUL))),
		"spd": int(t.get("spd", 95)),
		"weapon": str(t.get("weapon", "dagger")),
		"hat": "toujin",
		"cape": "none",
		"color": t.get("color", [0.5, 0.3, 0.28]),
		"scale": 1.0,
	}
	var out := {"name": str(t.get("name", "不速之客")), "foe": foe, "money": [10 + 4 * i, 16 + 6 * i]}
	var affixes: Array = DataAffixes.roll_from(DataAffixes.pool_for_diff(maxi(1, d)), clampi(d / 3, 0, 3))
	if not affixes.is_empty():
		out["affixes"] = affixes
	return out
