extends RefCounted
# ============================================================
# data_events.gd —— 事件卡与支线（第一期 · 内容表）
# 设计稿：docs/事件卡与善恶_设计稿.md
# v107（用户三条）：长线 6~7 步 · 善线恶线同趟可并行 · 大线走完给**整件**且丰厚。
#
# 卡的结构：
#   id → { title, text, line?, step?, phase_min?, once?, options[] }
# 选项（options[]）能挂的后果：
#   karma  善恶 ±          money 盘缠 ±         hp_pct 气血百分比 ±（负=掉血）
#   alert  警戒 ±          flag  记一个这趟的标记   enter/break 入线/断线
#   loot   "card"/"gear"/"art"（残件）            item "art"/"weapon"/"gear"（**整件**）
#   battle "elite"/"normal"（立刻打一场）          buff  挂一个临时增益
#   next   接着出另一张卡（连锁）
# ============================================================

# 四条线：id → {name, align, len, steps[], on_done}
const LINES := {
	"line_letter": {"name": "一封家书", "align": "good", "len": "short",
		"steps": ["letter_1", "letter_2", "letter_3"],
		"on_done": {"karma": 15, "loot": "art", "tag": "信义"}},
	"line_herb": {"name": "药王庙", "align": "good", "len": "long",
		"steps": ["herb_1", "herb_2", "herb_3", "herb_4", "herb_5", "herb_6", "herb_7"],
		"on_done": {"karma": 25, "item": "art", "money": 200, "tag": "仁心"}},
	"line_debt": {"name": "旧债", "align": "evil", "len": "long",
		"steps": ["debt_1", "debt_2", "debt_3", "debt_4", "debt_5", "debt_6", "debt_7"],
		"on_done": {"karma": -25, "item": "weapon", "money": 300, "tag": "血债"}},
	"line_gamble": {"name": "赌坊", "align": "evil", "len": "short",
		"steps": ["gamble_1", "gamble_2"],
		"on_done": {"karma": -12, "money": 260, "tag": "手气"}},
	"line_beggar": {"name": "讨饭的老丐", "align": "good", "len": "short",
		"steps": ["beggar_1"],
		"on_done": {"karma": 8, "tag": "一念"}},
	"line_lostkid": {"name": "走失的孩子", "align": "good", "len": "short",
		"steps": ["kid_1"],
		"on_done": {"karma": 10, "tag": "送还"}},
	"line_purse": {"name": "路上的钱袋", "align": "good", "len": "short",
		"steps": ["purse_1"],
		"on_done": {"karma": 8, "tag": "拾遗"}},
	"line_song": {"name": "卖唱的盲女", "align": "good", "len": "short",
		"steps": ["song_1"],
		"on_done": {"karma": 6, "tag": "听曲"}},
	"line_tiger": {"name": "打虎", "align": "good", "len": "short",
		"steps": ["tiger_1", "tiger_2"],
		"on_done": {"karma": 12, "money": 150, "tag": "伏虎"}},
	"line_salt": {"name": "私盐", "align": "evil", "len": "short",
		"steps": ["salt_1", "salt_2"],
		"on_done": {"karma": -12, "money": 180, "tag": "夹带"}},
	"line_medic": {"name": "同行的病人", "align": "good", "len": "short",
		"steps": ["medic_1", "medic_2"],
		"on_done": {"karma": 12, "loot": "art", "tag": "医者"}},
	"line_monk": {"name": "行脚僧", "align": "good", "len": "short",
		"steps": ["monk_1", "monk_2", "monk_3"],
		"on_done": {"karma": 15, "loot": "art", "tag": "同行"}},
	"line_inn": {"name": "黑店", "align": "evil", "len": "long",
		"steps": ["inn_1", "inn_2", "inn_3", "inn_4", "inn_5", "inn_6"],
		"on_done": {"karma": -25, "item": "gear", "money": 260, "tag": "血店"}},
	"line_lost": {"name": "寻亲", "align": "good", "len": "long",
		"steps": ["lost_1", "lost_2", "lost_3", "lost_4", "lost_5", "lost_6"],
		"on_done": {"karma": 25, "item": "gear", "money": 180, "tag": "还乡"}},
}

const CARDS := {
	# ---------- 善 · 短线：一封家书（3 步）----------
	"letter_1": {"title": "老妇人的托付", "line": "line_letter", "step": 1, "phase_min": 2,
		"text": "一个老妇人拦在路口，手里攥着一封信：「前面镇上，我儿在铁匠铺……你帮我递一递。」",
		"options": [
			{"label": "应下", "karma": 12, "flag": "letter", "enter": "line_letter"},
			{"label": "收了信，出镇就把纸卖了", "karma": -8, "money": 30, "break": "line_letter"},
			{"label": "推了", "karma": -3},
		]},
	"letter_2": {"title": "镇上的铁匠铺", "line": "line_letter", "step": 2,
		"text": "镇上只有一间铁匠铺，炉子冷着。铺里坐着个独臂汉子，正拿锉刀磨一截断刃。",
		"options": [
			{"label": "把信交到", "karma": 8, "loot": "card"},
			{"label": "信丢了，编个谎", "karma": -5, "money": 40, "break": "line_letter"},
		]},
	"letter_3": {"title": "回程", "line": "line_letter", "step": 3,
		"text": "走出二里地，身后有人喊。独臂汉子追上来，把一个布包塞进你怀里，转身就走。",
		"options": [
			{"label": "收下", "karma": 5, "loot": "art"},
		]},

	# ---------- 善 · 长线：药王庙（7 步；走完给一整门功法）----------
	"herb_1": {"title": "路倒的人", "line": "line_herb", "step": 1, "phase_min": 2,
		"text": "道边躺着个人，脸白得像纸，嘴角挂着黑血。路过的人都绕着走——这年月，沾上就是麻烦。",
		"options": [
			{"label": "扶起来看看", "karma": 10, "hp_pct": -5, "enter": "line_herb", "flag": "herb"},
			{"label": "绕过去", "karma": -4},
		]},
	"herb_2": {"title": "半张药方", "line": "line_herb", "step": 2,
		"text": "他怀里揣着半张药方，字迹被血洇开了大半，只认得出「药王庙」三个字。",
		"options": [
			{"label": "按方子去找药", "karma": 8, "money": -40},
			{"label": "把他放到庙里就走", "karma": 2, "break": "line_herb"},
		]},
	"herb_3": {"title": "药王庙", "line": "line_herb", "step": 3,
		"text": "庙塌了一半，药王像只剩个底座。偏殿的柜子里还剩几味药，落满了灰。",
		"options": [
			{"label": "抓药、熬药", "karma": 6, "hp_pct": -5},
			{"label": "把药揣走，人不管了", "karma": -12, "money": 120, "break": "line_herb"},
		]},
	"herb_4": {"title": "来的路", "line": "line_herb", "step": 4,
		"text": "他醒了一半，说自己是山下镇上的郎中，被人打了闷棍扔在道边——「他们还在找我。」",
		"options": [
			{"label": "「有我挡着。」", "karma": 10, "battle": "elite"},
			{"label": "「我送你到镇上就走。」", "karma": 4},
		]},
	"herb_5": {"title": "庙里的刀", "line": "line_herb", "step": 5,
		"text": "夜里有三个人摸进庙来，火把照得壁画上的药王像个活人。",
		"options": [
			{"label": "拦在门口", "karma": 12, "hp_pct": -15, "battle": "elite"},
			{"label": "从后墙把郎中背走", "karma": 6, "hp_pct": -8},
		]},
	"herb_6": {"title": "郎中醒了", "line": "line_herb", "step": 6,
		"text": "天快亮时他坐起来，从贴身的夹层里摸出一卷东西：「这个，你拿着。」",
		"options": [
			{"label": "收下", "karma": 5},
		]},
	"herb_7": {"title": "药王庙的香火", "line": "line_herb", "step": 7,
		"text": "他把庙里的碎砖一块块码好，点上三炷香：「往后谁路过，也有个歇脚的地方。」",
		"options": [
			{"label": "陪他把香点完", "karma": 15},
		]},

	# ---------- 恶 · 长线：旧债（7 步；走完给一整件兵器）----------
	"debt_1": {"title": "旧债·破酒肆", "line": "line_debt", "step": 1, "phase_min": 2,
		"text": "你路过一间破酒肆，柜台后的人脸色一僵：「……是你。」",
		"options": [
			{"label": "「我记不得你。」", "karma": -10, "enter": "line_debt", "flag": "debt"},
			{"label": "「当年那笔账，今日结了。」", "karma": 8, "money": -100, "loot": "art"},
			{"label": "转身就走"},
		]},
	"debt_2": {"title": "讨债的打手", "line": "line_debt", "step": 2,
		"text": "出镇不到十里，四个人堵在道上，手里都拎着家伙：「掌柜的说了，账得算清。」",
		"options": [
			{"label": "打过去", "karma": -8, "battle": "elite", "flag": "debt_book"},
			{"label": "掏钱买路", "karma": -2, "money": -150, "break": "line_debt"},
		]},
	"debt_3": {"title": "账本上的名字", "line": "line_debt", "step": 3,
		"text": "打手身上有本账。翻开来，第一页就是你当年的名字，后面还跟着十几个。",
		"options": [
			{"label": "照着名字一个个找上门", "karma": -12},
			{"label": "把账本烧了，从此两清", "karma": 15, "break": "line_debt", "loot": "gear"},
		]},
	"debt_4": {"title": "第二个名字", "line": "line_debt", "step": 4,
		"text": "第二个人在城里开了间绸缎庄，见了你，手一抖，茶盏摔在地上。",
		"options": [
			{"label": "「账，该还了。」", "karma": -10, "money": 250},
			{"label": "「我不要钱。」", "karma": -5, "battle": "elite"},
			{"label": "看了他一眼，走了", "karma": 8, "break": "line_debt"},
		]},
	"debt_5": {"title": "寻仇", "line": "line_debt", "step": 5,
		"text": "夜宿客栈，三更时窗纸被人一刀挑开。来的不止一个。",
		"options": [
			{"label": "迎上去", "karma": -6, "hp_pct": -12, "battle": "elite"},
			{"label": "破窗就走", "karma": -3, "hp_pct": -6},
		]},
	"debt_6": {"title": "最后的债主", "line": "line_debt", "step": 6,
		"text": "城西一间空宅，院里坐着个瞎眼老头，手里摩挲着一把刀的刀柄：「你终于来了。」",
		"options": [
			{"label": "「把刀给我。」", "karma": -12, "battle": "elite"},
			{"label": "「我来还债，不是来要债。」", "karma": 18, "money": -200},
		]},
	"debt_7": {"title": "了断", "line": "line_debt", "step": 7,
		"text": "老头把刀推过来，刀鞘上刻着两个旧字，磨得快要看不清了。",
		"options": [
			{"label": "收刀", "karma": -8},
			{"label": "把刀留下，磕个头走", "karma": 20},
		]},

	# ---------- 恶 · 短线：赌坊（2 步）----------
	"gamble_1": {"title": "镇口的赌坊", "line": "line_gamble", "step": 1, "phase_min": 2,
		"text": "赌坊里吆五喝六，一个手气正旺的胖子面前堆着钱。",
		"options": [
			{"label": "出千赢他一把", "karma": -8, "money": 120, "alert": 20, "enter": "line_gamble"},
			{"label": "押两把，输赢认命", "money": -60},
			{"label": "不进去"},
		]},
	"gamble_2": {"title": "赌坊后巷", "line": "line_gamble", "step": 2,
		"text": "你刚出后门，两条影子就贴了上来——赢的钱，得看有没有命带走。",
		"options": [
			{"label": "迎上去", "karma": -4, "battle": "normal", "money": 140},
			{"label": "把钱撒出去，趁乱走", "karma": -2, "money": -80},
		]},

	# ---------- 1 步短线（一事一线：选完就结）----------
	"beggar_1": {"title": "讨饭的老丐", "line": "line_beggar", "step": 1, "phase_min": 2,
		"text": "一个老丐缩在墙根，伸出豁了口的碗。他的眼睛一直盯着你的鞋。",
		"options": [
			{"label": "给两个钱", "karma": 8, "money": -20, "enter": "line_beggar", "alert": -30},
			{"label": "踢开他的碗", "karma": -8},
			{"label": "绕过去"},
		]},
	"kid_1": {"title": "走失的孩子", "line": "line_lostkid", "step": 1, "phase_min": 2,
		"text": "路边坐着个四五岁的孩子，脸哭花了，问他什么也不说，只攥着一只布老虎。",
		"options": [
			{"label": "带回前面的村子问一问", "karma": 10, "hp_pct": -5, "enter": "line_lostkid"},
			{"label": "不管", "karma": -5},
			{"label": "带去镇上，卖给没孩子的人家", "karma": -18, "money": 150, "enter": "line_lostkid"},
		]},
	"purse_1": {"title": "路上的钱袋", "line": "line_purse", "step": 1, "phase_min": 2,
		"text": "官道正中间躺着一只钱袋，鼓鼓的，四下无人。",
		"options": [
			{"label": "交给前面亭长", "karma": 8, "enter": "line_purse"},
			{"label": "揣走", "karma": -10, "money": 120, "alert": 10, "enter": "line_purse"},
			{"label": "当没看见", "karma": -2},
		]},
	"song_1": {"title": "卖唱的盲女", "line": "line_song", "step": 1, "phase_min": 2,
		"text": "茶棚外一个盲女抱着琵琶唱曲，嗓子已经哑了。听的人多，给钱的少。",
		"options": [
			{"label": "给十文，听她唱完", "karma": 6, "money": -10, "hp_pct": 8, "enter": "line_song"},
			{"label": "白听一场", "karma": -4},
			{"label": "抢她的钱匣", "karma": -15, "money": 60, "alert": 20, "enter": "line_song"},
		]},

	# ---------- 2 步短线 ----------
	"tiger_1": {"title": "村口的悬赏", "line": "line_tiger", "step": 1, "phase_min": 2,
		"text": "村口贴着一张告示：山中大虫伤人，能除者赏银二百。落款是三日前。",
		"options": [
			{"label": "揭了告示进山", "karma": 6, "enter": "line_tiger"},
			{"label": "撕下告示，去镇上冒领赏钱", "karma": -8, "money": 80},
			{"label": "不接"},
		]},
	"tiger_2": {"title": "虎口", "line": "line_tiger", "step": 2,
		"text": "半山腰的草丛里，一团黄影慢慢立起来，比人还高。",
		"options": [
			{"label": "迎上去", "karma": 10, "hp_pct": -20, "battle": "elite", "money": 200},
			{"label": "退下山，另想法子", "karma": 2, "hp_pct": -5},
		]},
	"salt_1": {"title": "私盐", "line": "line_salt", "step": 1, "phase_min": 2,
		"text": "一个挑担子的汉子压低声音：「帮我带两包过卡子，到了地方给你一百五。」",
		"options": [
			{"label": "答应", "karma": -8, "money": 150, "enter": "line_salt"},
			{"label": "报官", "karma": 10, "money": 50},
			{"label": "不掺和"},
		]},
	"salt_2": {"title": "卡子", "line": "line_salt", "step": 2,
		"text": "关卡前排着长队，兵丁拿铁签子一包包地戳，戳到谁的担子谁就脸色发白。",
		"options": [
			{"label": "硬闯", "karma": -6, "battle": "normal"},
			{"label": "把货丢进沟里，空手过", "karma": -2, "money": -60},
		]},
	"medic_1": {"title": "同行的病人", "line": "line_medic", "step": 1, "phase_min": 2,
		"text": "路上搭伴的货郎发起高热，嘴唇烧得起了皮，走两步就要扶一次墙。",
		"options": [
			{"label": "花钱请个郎中", "karma": 8, "money": -80, "enter": "line_medic"},
			{"label": "一个人先走，把他留在破庙里", "karma": -10},
			{"label": "陪他慢慢走", "karma": 4, "hp_pct": -5},
		]},
	"medic_2": {"title": "药引", "line": "line_medic", "step": 2,
		"text": "郎中开的方子里有一味药引，镇上买不到，得自己去山里找。",
		"options": [
			{"label": "上山采", "karma": 10, "hp_pct": -12, "loot": "art"},
			{"label": "花钱托人去办", "karma": 5, "money": -120},
		]},

	# ---------- 3 步短线：行脚僧 ----------
	"monk_1": {"title": "行脚僧", "line": "line_monk", "step": 1, "phase_min": 2,
		"text": "一个背竹篓的僧人跟你同路走了半里，不紧不慢，始终在你侧后方。",
		"options": [
			{"label": "放慢脚程，与他同行一程", "karma": 6, "enter": "line_monk"},
			{"label": "赶他走", "karma": -5},
		]},
	"monk_2": {"title": "夜谈", "line": "line_monk", "step": 2,
		"text": "夜里他生了一堆火，从篓里摸出两个冷馍，分你一个：「施主身上，杀气重。」",
		"options": [
			{"label": "听他讲", "karma": 8, "buff": "run_warm"},
			{"label": "笑一笑，不接话"},
		]},
	"monk_3": {"title": "别过", "line": "line_monk", "step": 3,
		"text": "岔路口，他把竹篓里一卷旧纸塞给你：「路上捡的，我不识字。」",
		"options": [
			{"label": "合十谢过", "karma": 10},
		]},

	# ---------- 长线：黑店（恶 · 6 步）----------
	"inn_1": {"title": "黑店·宿头", "line": "line_inn", "step": 1, "phase_min": 2,
		"text": "荒山脚下只有一间客栈亮着灯。掌柜的笑得太用力，后厨飘出来的味儿不太对。",
		"options": [
			{"label": "住下，夜里看看", "karma": -4, "enter": "line_inn", "flag": "inn"},
			{"label": "连夜赶路", "karma": 2},
		]},
	"inn_2": {"title": "后厨", "line": "line_inn", "step": 2,
		"text": "三更过后，后厨的灯亮了。你贴着窗纸看进去——案板上躺着的，不像猪。",
		"options": [
			{"label": "推门进去", "karma": -6, "battle": "normal"},
			{"label": "回房装作没看见", "karma": -8, "break": "line_inn"},
		]},
	"inn_3": {"title": "掌柜的规矩", "line": "line_inn", "step": 3,
		"text": "掌柜的跪在地上磕头，从柜底摸出一只木匣：「好汉饶命，这些年攒的，都在这儿。」",
		"options": [
			{"label": "拿钱，放他一条命", "karma": -10, "money": 300},
			{"label": "拿钱，再送他上路", "karma": -18, "money": 300},
			{"label": "报官，把人捆了送去", "karma": 18, "money": 60, "break": "line_inn"},
		]},
	"inn_4": {"title": "地窖里的人", "line": "line_inn", "step": 4,
		"text": "地窖里锁着七个人，都是过路的。有人已经不会说话了。",
		"options": [
			{"label": "把锁砸开，放他们走", "karma": 12, "break": "line_inn", "loot": "gear"},
			{"label": "挑两个还走得动的，带去卖掉", "karma": -20, "money": 400},
		]},
	"inn_5": {"title": "店里的牌子", "line": "line_inn", "step": 5,
		"text": "梁上挂着一排木牌，都是住店客人的名字。最上头那块，墨迹最新。",
		"options": [
			{"label": "把牌子全摘下来，埋了", "karma": 8},
			{"label": "照牌子上的名字，一个个找家里要钱", "karma": -15, "money": 350},
		]},
	"inn_6": {"title": "一把剔骨刀", "line": "line_inn", "step": 6,
		"text": "灶台边立着一把剔骨刀，刀身窄长，握在手里刚刚好。",
		"options": [
			{"label": "收下", "karma": -10},
			{"label": "扔进灶膛", "karma": 12},
		]},

	# ---------- 长线：寻亲（善 · 6 步）----------
	"lost_1": {"title": "寻亲·拦路", "line": "line_lost", "step": 1, "phase_min": 2,
		"text": "一个妇人跪在路当中，额头已经磕出血：「我儿被拉去当兵，就在前面大营里……」",
		"options": [
			{"label": "扶她起来，应下这事", "karma": 10, "enter": "line_lost", "flag": "lost"},
			{"label": "推开她赶路", "karma": -10},
		]},
	"lost_2": {"title": "打听", "line": "line_lost", "step": 2,
		"text": "镇上的茶摊、药铺、赌坊，问了一圈。有人说那批丁勇上个月就拨去北边了。",
		"options": [
			{"label": "花点钱买消息", "karma": 6, "money": -60},
			{"label": "沿路一个个问", "karma": 8, "hp_pct": -8},
			{"label": "算了，回不去交差", "karma": -12, "break": "line_lost"},
		]},
	"lost_3": {"title": "北边的营", "line": "line_lost", "step": 3,
		"text": "营栅扎在山口，旗子破了一半。哨兵抱着枪打盹。",
		"options": [
			{"label": "夜里摸进去", "karma": 8, "hp_pct": -10},
			{"label": "拿钱买通伙夫", "karma": 5, "money": -150},
		]},
	"lost_4": {"title": "营里的孩子", "line": "line_lost", "step": 4,
		"text": "草棚里挤着几十个半大孩子，瘦得只剩眼睛。你要找的那一个，手上还攥着半个饼。",
		"options": [
			{"label": "只带他一个走", "karma": 10},
			{"label": "把草棚的门全打开，能跑几个是几个", "karma": 20, "alert": 30, "battle": "elite"},
		]},
	"lost_5": {"title": "追兵", "line": "line_lost", "step": 5,
		"text": "天没亮，后头就传来了马蹄声。孩子跑不动了，蹲在地上直喘。",
		"options": [
			{"label": "背起他跑", "karma": 12, "hp_pct": -18},
			{"label": "留下断后，让他先走", "karma": 15, "hp_pct": -25, "battle": "elite"},
		]},
	"lost_6": {"title": "还乡", "line": "line_lost", "step": 6,
		"text": "那妇人还跪在原来的地方，像是一直没起过身。",
		"options": [
			{"label": "把孩子交到她手里", "karma": 15},
		]},

	# ---------- 散卡（不入线）----------
	"stray_dog": {"title": "瘸腿的老狗", "phase_min": 2,
		"text": "一条瘸腿的老狗远远跟着你，跟了半里地，也不叫。",
		"options": [
			{"label": "分它半块干粮", "karma": 5, "loot": "card"},
			{"label": "扔块石头赶走", "karma": -4},
			{"label": "由它跟着"},
		]},
	"night_temple": {"title": "雨夜的破庙", "phase_min": 2,
		"text": "破庙里已经生了一堆火，一个刀客坐在火边擦刀，抬眼看你一眼，没说话。",
		"options": [
			{"label": "在火边坐下", "karma": 3, "buff": "run_warm"},
			{"label": "让他滚", "karma": -6, "battle": "normal"},
			{"label": "退出去另找地方", "hp_pct": -8},
		]},
	"river_box": {"title": "河心的木箱", "phase_min": 2,
		"text": "河心冲来一只木箱，半沉半浮。水冷得刺骨，流也急。",
		"options": [
			{"label": "下水", "hp_pct": -20, "loot": "gear"},
			{"label": "找根长竿拨过来", "money": -30, "loot": "gear"},
			{"label": "看着它漂走"},
		]},
	"ferryman": {"title": "摆渡人", "phase_min": 2,
		"text": "渡口的船老大伸手：「三十文，过河。」你身上有多少，他没问。",
		"options": [
			{"label": "付钱过河", "money": -30},
			{"label": "自己凫水过去", "hp_pct": -15, "karma": -3},
			{"label": "抢船", "karma": -10, "alert": 25},
		]},
	"grave_name": {"title": "官道上的尸首", "phase_min": 2,
		"text": "一具尸首趴在道边，背后中刀。他怀里露出半块名牌，写着「威远镖局」。",
		"options": [
			{"label": "挖个坑埋了，把名牌收好", "karma": 8, "hp_pct": -5, "flag": "nameplate"},
			{"label": "搜一遍再走", "karma": -10, "money": 50, "alert": 10},
			{"label": "绕开"},
		]},
	"well_child": {"title": "井边的孩子", "phase_min": 2,
		"text": "村口老井的辘轳断了，井里传出孩子断续的哭喊。围观的人多，下去的人没有。",
		"options": [
			{"label": "下井去捞", "karma": 12, "hp_pct": -15, "loot": "card"},
			{"label": "找根绳子来，喊人一起", "karma": 6, "money": -10},
			{"label": "别沾这麻烦", "karma": -6},
		]},
	"shrine": {"title": "山神的供品", "phase_min": 2,
		"text": "山神庙的供桌上摆着三牲与香火钱，落了一层灰——许久没人来了。",
		"options": [
			{"label": "拿了供品与香火钱", "karma": -6, "money": 70},
			{"label": "添一炷香再走", "karma": 5, "hp_pct": 10},
			{"label": "什么也不动"},
		]},
	"stray_grave_new": {"title": "路边的新坟", "phase_min": 2,
		"text": "一座新坟，土还是湿的，坟前插着半截木牌，没刻字。",
		"options": [
			{"label": "把木牌上的字补上", "karma": 6, "money": -10},
			{"label": "挖开看看埋了什么", "karma": -10, "money": 60, "alert": 10},
			{"label": "鞠一躬走开", "karma": 2},
		]},
	"stray_players": {"title": "卖艺的父女", "phase_min": 2,
		"text": "当街上围了一圈人。老汉耍刀，七八岁的丫头端着铜盘挨个讨赏。",
		"options": [
			{"label": "给赏钱", "karma": 5, "money": -20},
			{"label": "指点老汉两招", "karma": 4, "buff": "run_warm"},
			{"label": "趁乱摸了铜盘里的钱", "karma": -12, "money": 50, "alert": 15},
		]},
	"stray_levee": {"title": "河堤决口", "phase_min": 2,
		"text": "下游村子的河堤塌了个口子，十几个汉子正拿沙袋往上堵，水已经漫过膝盖。",
		"options": [
			{"label": "下去一起堵", "karma": 12, "hp_pct": -15, "loot": "card"},
			{"label": "站在岸上看", "karma": -5},
			{"label": "趁乱进村，卷点东西", "karma": -15, "money": 130, "alert": 20},
		]},
	"stray_wreck": {"title": "被抢的商队", "phase_min": 2,
		"text": "两辆翻倒的骡车，货撒了一地，人已经凉了。远处山梁上还有影子在动。",
		"options": [
			{"label": "把活着的人拖出来", "karma": 10, "hp_pct": -8, "alert": 20},
			{"label": "捡能拿的赶紧走", "karma": -8, "money": 180, "alert": 25},
			{"label": "绕开", "karma": -2},
		]},
	"stray_taoist": {"title": "道观的香客", "phase_min": 2,
		"text": "半山道观里,一个穿绸的香客正往功德箱里塞银子，塞得又多又快。",
		"options": [
			{"label": "与他攀谈", "karma": 3, "money": 40},
			{"label": "等他下山，跟上去", "karma": -12, "money": 250, "alert": 25},
			{"label": "上自己的香", "karma": 4, "money": -20, "hp_pct": 6},
		]},
	"stray_shark": {"title": "赌局上的老千", "phase_min": 2,
		"text": "牌桌上一个瘦子手快得看不清，对面的汉子已经输红了眼。",
		"options": [
			{"label": "当众揭穿他", "karma": 8, "alert": 15},
			{"label": "私下敲他一笔", "karma": -10, "money": 120},
			{"label": "不关我的事"},
		]},
	"stray_snow": {"title": "雪地里的脚印", "phase_min": 2,
		"text": "雪地上两行脚印，一行深一行浅，浅的那行边上还有拖拽的痕迹。",
		"options": [
			{"label": "顺着追下去", "karma": 8, "hp_pct": -10, "loot": "gear"},
			{"label": "不追", "karma": -2},
		]},
	"stray_notice": {"title": "桥头的悬赏", "phase_min": 2,
		"text": "桥头贴着一张画像，画的是个刀疤脸，赏格三百两，理由是「劫杀良民」。",
		"options": [
			{"label": "记下这张脸", "karma": 4, "flag": "wanted"},
			{"label": "把告示撕了去领赏", "karma": -8, "money": 100},
			{"label": "撕了烧掉", "karma": 6, "alert": 10},
		]},
	"stray_horse": {"title": "驿站的老马", "phase_min": 2,
		"text": "驿站后槽拴着一匹老马，瘦得能数出肋骨，见人来了打个响鼻。",
		"options": [
			{"label": "喂它点草料", "karma": 5, "money": -10, "hp_pct": 5},
			{"label": "牵走卖了", "karma": -10, "money": 80, "alert": 15},
		]},
	"stray_hanged": {"title": "树上的吊死鬼", "phase_min": 2,
		"text": "老槐树上吊着个人，风一吹就转半圈。树下站着几个看热闹的，谁也不动手。",
		"options": [
			{"label": "放下来埋了", "karma": 8, "hp_pct": -5},
			{"label": "搜他身上", "karma": -10, "money": 70},
			{"label": "走开"},
		]},
	"stray_fortune": {"title": "瞎子的卦摊", "phase_min": 2,
		"text": "瞎子的摊子摆在十字路口，摊上一张旧卦图：「十文一卦，问什么都能答。」",
		"options": [
			{"label": "算一卦", "karma": 2, "money": -10, "buff": "run_warm"},
			{"label": "掀了他的摊子", "karma": -8},
			{"label": "不信这个"},
		]},
	"stray_trap": {"title": "猎户的陷阱", "phase_min": 2,
		"text": "林子里一只鹿被铁夹咬住了后腿，见人来了拼命挣，血把雪地染红了一片。",
		"options": [
			{"label": "掰开夹子放了它", "karma": 8, "hp_pct": -6},
			{"label": "连鹿带夹子一起收走", "karma": -8, "money": 90},
			{"label": "不碰"},
		]},
	"caravan": {"title": "落单的商队", "phase_min": 2,
		"text": "两辆骡车，四个伙计，货堆得高。押队的汉子握刀的手一直在抖。",
		"options": [
			{"label": "抢了", "karma": -15, "money": 200, "alert": 30, "battle": "elite"},
			{"label": "护送到下一个镇", "karma": 10, "money": 40},
			{"label": "各走各的"},
		]},
}

# 散卡（不入线的那些）——抽取时从这里挑
const STRAYS := ["stray_dog", "night_temple", "river_box", "ferryman",
	"grave_name", "well_child", "shrine", "caravan",
	"stray_grave_new", "stray_players", "stray_levee", "stray_wreck",
	"stray_taoist", "stray_shark", "stray_snow", "stray_notice",
	"stray_horse", "stray_hanged", "stray_fortune", "stray_trap"]

# ⚠ 卡的身份是**字典的键**，不是卡里的字段——发出去时把 id 补进去，
#   否则"同趟不重复"（ev_seen）永远记不上（探针当场抓到：山神庙连出三次）。
static func card(id: String) -> Dictionary:
	var d: Dictionary = CARDS.get(id, {})
	if d.is_empty():
		return {}
	var out: Dictionary = d.duplicate(true)
	out["id"] = id
	return out

static func line_of(cid: String) -> String:
	return str((CARDS.get(cid, {}) as Dictionary).get("line", ""))

# 某条线的第 n 步卡 id（steps 表）
static func step_card(lid: String, step: int) -> String:
	var L: Dictionary = LINES.get(lid, {})
	var steps: Array = L.get("steps", [])
	if step < 1 or step > steps.size():
		return ""
	return str(steps[step - 1])

static func line_name(lid: String) -> String:
	return str((LINES.get(lid, {}) as Dictionary).get("name", lid))

# ------------------------------------------------------------
# 这一步该出哪张卡（舞台每进一个 choice 节点就叫一次）
#   ① 身上挂着的线 → 走它的下一步（走得动就走）
#   ② 否则抽一条新线的头一步（品级够 + 没见过）
#   ③ 再否则从散卡里抽（没见过的）
# ------------------------------------------------------------
static func pick_next(st, phase: int) -> Dictionary:
	if st == null:
		return {}
	# ① 线的下一步（多条线挂身上时，先走"最早挂上"的那条——字典序稳定，玩家感觉是"接着上次"）
	var riding: Array = st.ev_lines.keys()
	riding.sort()
	for lid_v in riding:
		var lid := str(lid_v)
		var at := int(st.ev_lines[lid])
		var nxt := step_card(lid, at + 1)
		if nxt == "" or st.ev_seen.has(nxt):
			continue
		st.ev_lines[lid] = at + 1
		return card(nxt)
	# ② 新线的头一步
	var pool: Array = []
	var lids: Array = LINES.keys()
	lids.sort()
	for lid_v2 in lids:
		var lid2 := str(lid_v2)
		if st.ev_lines.has(lid2):
			continue
		var c0 := step_card(lid2, 1)
		if c0 == "" or st.ev_seen.has(c0):
			continue
		if phase < int((CARDS.get(c0, {}) as Dictionary).get("phase_min", 0)):
			continue
		pool.append(c0)
	# ③ 散卡
	for cid_v in STRAYS:
		var cid := str(cid_v)
		if st.ev_seen.has(cid):
			continue
		if phase < int((CARDS.get(cid, {}) as Dictionary).get("phase_min", 0)):
			continue
		pool.append(cid)
	if pool.is_empty():
		return {}
	return card(str(pool[randi() % pool.size()]))

# 走完一条线（舞台在"线的最后一步"点完时叫它）：发终奖、记结局标记
static func finish_line(st, lid: String) -> String:
	var L: Dictionary = LINES.get(lid, {})
	if L.is_empty():
		return ""
	st.ev_lines.erase(lid)
	if not st.ev_done.has(lid):
		st.ev_done.append(lid)
	var on: Dictionary = L.get("on_done", {})
	st.karma = clampi(int(st.karma) + int(on.get("karma", 0)), -100, 100)
	if on.has("money"):
		st.money = maxi(0, int(st.money) + int(on["money"]))
	return "支线「" + line_name(lid) + "」走完了——" + str(on.get("tag", ""))
