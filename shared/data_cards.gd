extends RefCounted
# ============================================================
# 卡牌数据 v18（㊵：整件重发）
# 与《已粘贴的文本(110)》逐字一致，除三处：
#   ①删重名函数——is_buff / is_gear 各只留一份（此前贴了两遍＝解析报错）；
#   ②删 36 条 bc_* 条目——增益不再占卡表：他们是 data_buffs 里的"当局增益"
#     （只本趟、带不出去、三种都可重复拿并叠加），由卡组面板与精英三抽发放；
#   ③保留新装备 6 套（玄铁重甲/金丝软甲/紫玉冠/琉璃佩/玄狐披风/天蚕披风）。
# 其余不动：兵器 25 套、武学 20 套、阶梯链、价表、页数、加成口径。
# ============================================================

const SETS := [
	# ---- v35：装备数值整体上调（用户："装备的增幅太低了"）----
	# ---- v38：再**全方位**加强一次（用户："装备可以全方位再加强一下"）----
	# 这一版三条改法：
	#   ① 档位整体抬 ~50%：兵器攻 6/9/13/17/21 → **9/14/20/26/32**、伤害 6/12/18 → **10/18/26**；
	#      护甲气血 24/38/53/72 → **36/58/82/112**、防御 0/4/6/8 → **3/7/11/15**
	#   ② **每一件都补齐该有的轴**——原来凡品护甲只给气血、青玉佩只给暴击，一件只长一样；
	#      现在：甲＝气血＋防御（极品带闪避）· 佩＝暴击＋气血＋防御（上品起带**暴伤**）·
	#      披风＝速度＋闪避（上品起带气血）——四个格子合起来把
	#      **攻 / 伤 / 气 / 防 / 闪 / 暴 / 暴伤 / 速** 八条轴铺满
	#   ③ 新尺子：**一套极品 ≈ 玩家大半个底子**（气 +210 · 攻 +26 ＋伤害 18% · 暴 15 ·
	#      防 27 · 闪 20 · 速 13 · 暴伤 18）——装备＋升星仍是三条成长线里最重的一条
	#   ④ **v51（用户："暴击都是稀有属性，装备上的、功法上的可以适当降低，增伤也是"）**：
	#      把"暴击"与"增伤"这两条**从装备/功法那一侧整体压低约 1/3**：
	#        玉佩暴击 5/8/11/15 → **3/5/7/10**；兵器增伤 10/18/26 → **7/13/18**；
	#        武学增伤 8/12/16/20 → **5/8/11/14**（凡品兜底 FANPIN_ART_DMG 8→5 同步）；
	#        专武常驻那条也跟着走（长风诀 dmg 8→5 · 短歌行 crit 8→5）；
	#        加持类那两条顺手压了（锐锋旗令 atk_pct 0.35→0.25 · 同心结阵 0.18→0.13、crit_add 8→5）。
	#      ⚠ **攻/气/防/闪/速/暴伤这六条一个字没动**——这一轮只动"暴击"与"增伤"。
	#      ⚠ **角色星、五问天赋、羁绊**那边的暴击（眼力 +6 / 轻灵 +8 / 三人同心 ×1.1）**没动**：
	#        用户那一句说的是"装备上的、功法上的"，那几条是另一条线。
	#        v61 补记：五问那两条**后来单独削过**（用户："少侠的五问属性超模了"）——
	#        目光如炬 +6→**+4**、明察秋毫 +8→**+3**（见 data_talents.LIST 的 v61 段）。
	#      ⚠ 残卡那条线（`card_bonus` 的 `{"dmg": 2 + 2*q}`）也**没动**：那是路上捡的散片份额，
	#        不是成品装备/功法本身。
	# 调法：只改下面每条 item_stats 里那几个数；升星每星 +20% 乘在它们上面。
	#   ⚠ 包里**残片**的加成走 _share_stats（＝这一份 ÷ 页数，每轴至少 1），所以这表一动，
	#     路上捡的散片跟着一起动——这正是不想让"装备加强"只惠及成品的原因。
	#   ⚠ 只用 effective_stats 认的那 8 个键（atk/hp/spd/crit/dmg/def/dodge/crit_dmg）：
	#     写别的键（比如 dmg_cut）不会进面板，也不会进战斗，等于白写。
	{"id": "sword", "name": "长剑", "pool": "weapon", "weapon": "sword", "parts": ["锋", "柄", "鞘"], "item": "青锋剑", "item_stats": {"atk": 15, "phys_dmg": 2}},
	{"id": "dual", "name": "双刀", "pool": "weapon", "weapon": "dual", "parts": ["锋", "柄", "鞘"], "item": "雁翎双刀", "item_stats": {"atk": 15, "phys_dmg": 2}},
	{"id": "dagger", "name": "匕首", "pool": "weapon", "weapon": "dagger", "parts": ["锋", "柄", "鞘"], "item": "寒星匕首", "item_stats": {"atk": 15, "phys_dmg": 2}},
	{"id": "spear", "name": "长枪", "pool": "weapon", "weapon": "spear", "parts": ["锋", "柄", "鞘"], "item": "破阵长枪", "item_stats": {"atk": 15, "phys_dmg": 2}},
	# v57（用户："武器的棍子类型改成暗器类型 棍类武器名称也要改一下"）：
	#   **类型键 `staff` → `anqi`、名字全线换成暗器**。⚠ 只换"类型键 + 显示名"，
	#   **卡 id（staff / staff_tie / …）一个字没动**——id 是存档键（仓库 vault_cards /
	#   三人的 equipped），改了老档的棍就变空气；残片按**下标**存，所以 parts 换名也安全。
	{"id": "staff", "name": "暗器", "pool": "weapon", "weapon": "anqi", "parts": ["锋", "柄", "囊"], "item": "飞蝗石", "item_stats": {"atk": 15, "phys_dmg": 2}},
	{"id": "sword_qiu", "name": "秋水剑", "pool": "weapon", "weapon": "sword", "parts": ["锋", "柄", "鞘", "穗"], "item": "秋水剑", "quality": "良品", "item_stats": {"atk": 24, "phys_dmg": 3}},
	{"id": "spear_han", "name": "寒铁枪", "pool": "weapon", "weapon": "spear", "parts": ["锋", "柄", "鞘", "缨"], "item": "寒铁枪", "quality": "良品", "item_stats": {"atk": 24, "phys_dmg": 3}},
	{"id": "sword_shuang", "name": "霜刃剑", "pool": "weapon", "weapon": "sword", "parts": ["锋", "柄", "鞘", "穗", "铭"], "item": "霜刃剑", "quality": "上品", "item_stats": {"atk": 34, "dmg": 4}},
	{"id": "armor_pi", "name": "皮甲", "pool": "armor", "weapon": "any", "parts": ["片", "衬", "扣"], "item": "皮甲", "item_stats": {"hp": 190, "def": 3}},
	{"id": "armor_tie", "name": "铁叶甲", "pool": "armor", "weapon": "any", "parts": ["片", "衬", "扣"], "item": "铁叶甲", "quality": "良品", "item_stats": {"hp": 310, "def": 7, "earth_res": 4}},
	{"id": "helm_bu", "name": "青玉佩", "pool": "helm", "weapon": "any", "parts": ["身", "结", "穗"], "item": "青玉佩", "item_stats": {"crit": 2, "hp": 64}},
	{"id": "helm_tie", "name": "暖玉牌", "pool": "helm", "weapon": "any", "parts": ["身", "结", "穗"], "item": "暖玉牌", "quality": "良品", "item_stats": {"crit": 4, "hp": 140, "def": 5, "wood_res": 4}},
	{"id": "cloak_bu", "name": "旧披风", "pool": "cloak", "weapon": "any", "parts": ["领", "面", "扣"], "item": "旧披风", "item_stats": {"dodge": 9, "spd": 3, "hp": 30}},
	{"id": "cloak_ling", "name": "雁翎披风", "pool": "cloak", "weapon": "any", "parts": ["领", "面", "扣"], "item": "雁翎披风", "quality": "良品", "item_stats": {"spd": 7, "dodge": 8, "hp": 70, "water_res": 4}},
	# ---- ㊵：新装备 6 套（上品/极品；装备池不上阶梯——进表即全池生效） ----
	{"id": "armor_xuan", "name": "玄铁重甲", "pool": "armor", "weapon": "any", "parts": ["片", "衬", "扣", "环"], "item": "玄铁重甲", "quality": "上品", "item_stats": {"hp": 440, "def": 11, "dodge": 3, "earth_res": 7, "metal_res": 5}},
	{"id": "armor_jin", "name": "金丝软甲", "pool": "armor", "weapon": "any", "parts": ["片", "衬", "扣", "环", "纹"], "item": "金丝软甲", "quality": "极品", "item_stats": {"hp": 600, "def": 15, "dodge": 7, "earth_res": 10, "metal_res": 8, "water_res": 5}},
	{"id": "helm_zi", "name": "紫玉冠", "pool": "helm", "weapon": "any", "parts": ["身", "结", "穗", "铭"], "item": "紫玉冠", "quality": "上品", "item_stats": {"crit": 5, "hp": 205, "def": 8, "crit_dmg": 4, "wood_res": 7, "fire_res": 5}},
	{"id": "helm_liu", "name": "琉璃佩", "pool": "helm", "weapon": "any", "parts": ["身", "结", "穗", "铭", "纹"], "item": "琉璃佩", "quality": "极品", "item_stats": {"crit": 7, "hp": 290, "def": 12, "crit_dmg": 6, "wood_res": 10, "fire_res": 8, "water_res": 5}},
	{"id": "cloak_xuanhu", "name": "玄狐披风", "pool": "cloak", "weapon": "any", "parts": ["领", "面", "扣", "里"], "item": "玄狐披风", "quality": "上品", "item_stats": {"dodge": 16, "spd": 8, "hp": 140, "water_res": 7, "earth_res": 5}},
	{"id": "cloak_tian", "name": "天蚕披风", "pool": "cloak", "weapon": "any", "parts": ["领", "面", "扣", "里", "纹"], "item": "天蚕披风", "quality": "极品", "item_stats": {"spd": 13, "dodge": 13, "hp": 230, "water_res": 10, "earth_res": 8, "metal_res": 5}},
	{"id": "art_wind", "name": "疾风剑法", "pool": "arts", "weapon": "sword", "parts": ["卷上", "卷中", "卷下"], "item": "疾风剑法",
		# ㊿z2：补上 off_mult——它是**唯一一门"指定了兵器却没写打折"的武学**（别的 sword/dual
		#   武学都写了 off_mult），空着就等于"拿枪也使出全套剑法"，跟别的武学口径不一致。
		#   顺手也让角色星「武学宗师」有活干（那一条正是取消这个打折）。
		"art": {"kind": "damage", "mult": 1.8, "off_mult": 1.4, "cd": 3, "move": "风卷残云", "target": "mid", "desc": "剑走轻灵：×1.8（非剑 ×1.4 · 冷却 3 手）"}},
	{"id": "art_cleave", "name": "断岳刀法", "pool": "arts", "weapon": "dual", "parts": ["卷上", "卷中", "卷下"], "item": "断岳刀法", "quality": "良品",
		"art": {"kind": "damage", "mult": 2.4, "off_mult": 1.3, "cd": 4, "move": "断岳开山", "target": "sweep", "desc": "刀势沉猛：×2.4（非刀 ×1.3 · 冷却 4 手）"}},
	{"id": "art_shadow", "name": "影步", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "影步", "quality": "良品",
		"art": {"kind": "dash", "mult": 1.2, "follow": 0.7, "cd": 3, "move": "残影随行", "target": "mid", "desc": "身随影动：×1.2 再追击 ×0.7（冷却 3 手）"}},
	{"id": "art_iron", "name": "铁布衫", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "铁布衫",
		"art": {"kind": "guard", "turns": 2, "cut": 0.78, "cd": 5, "move": "铁桥横挡", "desc": "气凝周身：本手不出击，下 2 次受击减伤 22%（冷却 5 手）"}},
	{"id": "art_stone", "name": "掷石术", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "掷石术",
		"art": {"kind": "stone", "mult": 0.9, "cd": 3, "move": "飞石打穴", "desc": "石出如矢：×0.9，打断敌人下次出手（冷却 3 手）"}},
	{"id": "art_breath", "name": "回气诀", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "回气诀",
		"art": {"kind": "heal", "heal_pct": 0.25, "next_mult": 1.5, "cd": 5, "move": "归元吐纳", "desc": "吐纳归元：回血 25%，下次出手 ×1.5（冷却 5 手）"}},
	{"id": "art_river", "name": "大江剑势", "pool": "arts", "weapon": "sword", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾"], "item": "大江剑势", "quality": "上品", "elem": "water",
		"art": {"kind": "damage", "mult": 3.0, "off_mult": 1.2, "cd": 5, "move": "大江东去", "target": "sweep", "desc": "剑势浩荡：×3.0（非剑 ×1.2 · 冷却 5 手）"}, "item_stats": {"dmg": 4}},
	{"id": "dual_liu", "name": "柳叶双刀", "pool": "weapon", "weapon": "dual", "parts": ["锋", "柄", "鞘", "穗"], "item": "柳叶双刀", "quality": "良品", "item_stats": {"atk": 24, "phys_dmg": 3}},
	{"id": "dagger_qing", "name": "青蛇匕", "pool": "weapon", "weapon": "dagger", "parts": ["锋", "柄", "鞘", "吞"], "item": "青蛇匕", "quality": "良品", "item_stats": {"atk": 24, "phys_dmg": 3}},
	{"id": "staff_tie", "name": "柳叶飞刀", "pool": "weapon", "weapon": "anqi", "parts": ["锋", "柄", "囊", "机"], "item": "柳叶飞刀", "quality": "良品", "item_stats": {"atk": 24, "phys_dmg": 3}},
	{"id": "dual_yue", "name": "寒月双刀", "pool": "weapon", "weapon": "dual", "parts": ["锋", "柄", "鞘", "穗", "铭"], "item": "寒月双刀", "quality": "上品", "item_stats": {"atk": 34, "dmg": 4}},
	{"id": "dagger_chan", "name": "蝉翼匕", "pool": "weapon", "weapon": "dagger", "parts": ["锋", "柄", "鞘", "吞", "铭"], "item": "蝉翼匕", "quality": "上品", "item_stats": {"atk": 34, "dmg": 4}},
	{"id": "spear_long", "name": "游龙枪", "pool": "weapon", "weapon": "spear", "parts": ["锋", "柄", "鞘", "缨", "铭"], "item": "游龙枪", "quality": "上品", "item_stats": {"atk": 34, "dmg": 4}},
	{"id": "staff_pan", "name": "盘龙镖", "pool": "weapon", "weapon": "anqi", "parts": ["锋", "柄", "囊", "机", "铭"], "item": "盘龙镖", "quality": "上品", "item_stats": {"atk": 34, "dmg": 4}},
	{"id": "art_cloud", "name": "流云剑法", "pool": "arts", "weapon": "sword", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "流云剑法", "quality": "良品",
		"art": {"kind": "damage", "mult": 2.2, "off_mult": 1.4, "cd": 3, "move": "流云回雪", "target": "mid", "desc": "剑如流云：×2.2（非剑 ×1.4 · 冷却 3 手）"}},
	{"id": "art_bell", "name": "金钟罩", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "金钟罩", "quality": "良品",
		"art": {"kind": "guard", "turns": 2, "cut": 0.75, "cd": 5, "move": "金钟长鸣", "desc": "凝气如钟：本手不出击，下 2 次受击减伤 25%（冷却 5 手）"}},
	{"id": "art_thunder", "name": "雷动刀法", "pool": "arts", "weapon": "dual", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾"], "item": "雷动刀法", "quality": "上品", "elem": "metal",
		"art": {"kind": "damage", "mult": 2.8, "off_mult": 1.25, "cd": 4, "move": "雷动九天", "target": "sweep", "desc": "刀出如雷：×2.8（非刀 ×1.25 · 冷却 4 手）"}, "item_stats": {"dmg": 4}},
	{"id": "art_swallow", "name": "燕子三抄水", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾"], "item": "燕子三抄水", "quality": "上品",
		"art": {"kind": "dash", "mult": 1.5, "follow": 0.9, "cd": 4, "move": "掠水三叠", "target": "mid", "desc": "身轻如燕：×1.5 再追击 ×0.9（冷却 4 手）"}, "item_stats": {"dmg": 4}},
	{"id": "art_spring", "name": "长春诀", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾"], "item": "长春诀", "quality": "上品",
		"art": {"kind": "heal", "heal_pct": 0.35, "next_mult": 1.6, "cd": 5, "move": "枯木逢春", "target": "mid", "desc": "生机内敛：回血 35%，下次出手 ×1.6（冷却 5 手）"}, "item_stats": {"dmg": 4}},
	{"id": "sword_chang", "name": "长庚剑", "pool": "weapon", "weapon": "sword", "parts": ["锋", "柄", "鞘", "穗", "铭", "纹"], "item": "长庚剑", "quality": "极品", "item_stats": {"atk": 44, "dmg": 7}},
	{"id": "dual_fen", "name": "分水双刀", "pool": "weapon", "weapon": "dual", "parts": ["锋", "柄", "鞘", "穗", "铭", "纹"], "item": "分水双刀", "quality": "极品", "item_stats": {"atk": 44, "dmg": 7}},
	{"id": "dagger_jing", "name": "惊鸿匕", "pool": "weapon", "weapon": "dagger", "parts": ["锋", "柄", "鞘", "吞", "铭", "纹"], "item": "惊鸿匕", "quality": "极品", "item_stats": {"atk": 44, "dmg": 7}},
	{"id": "spear_guan", "name": "贯日枪", "pool": "weapon", "weapon": "spear", "parts": ["锋", "柄", "鞘", "缨", "铭", "纹"], "item": "贯日枪", "quality": "极品", "item_stats": {"atk": 44, "dmg": 7}},
	{"id": "staff_fu", "name": "伏魔针", "pool": "weapon", "weapon": "anqi", "parts": ["锋", "柄", "囊", "机", "铭", "纹"], "item": "伏魔针", "quality": "极品", "item_stats": {"atk": 44, "dmg": 7}},
	{"id": "sword_cheng", "name": "承影剑", "pool": "weapon", "weapon": "sword", "parts": ["锋", "柄", "鞘", "穗", "铭", "纹", "魂"], "item": "承影剑", "quality": "绝品", "item_stats": {"atk": 54, "dmg": 9}},
	{"id": "dual_hai", "name": "覆海双刀", "pool": "weapon", "weapon": "dual", "parts": ["锋", "柄", "鞘", "穗", "铭", "纹", "魂"], "item": "覆海双刀", "quality": "绝品", "item_stats": {"atk": 54, "dmg": 9}},
	{"id": "dagger_yu", "name": "鱼肠匕", "pool": "weapon", "weapon": "dagger", "parts": ["锋", "柄", "鞘", "吞", "铭", "纹", "魂"], "item": "鱼肠匕", "quality": "绝品", "item_stats": {"atk": 54, "dmg": 9}},
	{"id": "spear_dan", "name": "龙胆枪", "pool": "weapon", "weapon": "spear", "parts": ["锋", "柄", "鞘", "缨", "铭", "纹", "魂"], "item": "龙胆枪", "quality": "绝品", "item_stats": {"atk": 54, "dmg": 9}},
	{"id": "staff_qing", "name": "千机针", "pool": "weapon", "weapon": "anqi", "parts": ["锋", "柄", "囊", "机", "铭", "纹", "魂"], "item": "千机针", "quality": "绝品", "item_stats": {"atk": 54, "dmg": 9}},
	{"id": "art_ocean", "name": "沧溟剑诀", "pool": "arts", "weapon": "sword", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾", "秘页"], "item": "沧溟剑诀", "quality": "极品", "elem": "water",
		"art": {"kind": "damage", "mult": 3.6, "off_mult": 1.3, "cd": 5, "move": "沧溟倒卷", "target": "sweep", "desc": "剑吞沧海：×3.6（非剑 ×1.3；冷却 5 手）"}, "item_stats": {"dmg": 6}},
	{"id": "art_bulwark", "name": "金刚不坏", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾", "秘页"], "item": "金刚不坏", "quality": "极品", "elem": "earth",
		"art": {"kind": "guard", "turns": 3, "cut": 0.73, "cd": 5, "move": "不动如山", "target": "mid", "desc": "身若金刚：本手不出击，下 3 次受击减伤 27%（冷却 5 手）"}, "item_stats": {"dmg": 6}},
	{"id": "art_snow", "name": "踏雪无痕", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾", "秘页"], "item": "踏雪无痕", "quality": "极品", "elem": "water",
		"art": {"kind": "dash", "mult": 1.8, "follow": 1.1, "cd": 4, "move": "雪泥鸿爪", "target": "mid", "desc": "踏雪无声：×1.8 再追击 ×1.1（冷却 4 手）"}, "item_stats": {"dmg": 6}},
	{"id": "art_bloom", "name": "生生造化诀", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾", "秘页"], "item": "生生造化诀", "quality": "极品", "elem": "wood",
		"art": {"kind": "heal", "heal_pct": 0.45, "next_mult": 1.7, "cd": 5, "move": "生生不息", "target": "mid", "desc": "生机勃发：回血 45%，下次出手 ×1.7（冷却 5 手）"}, "item_stats": {"dmg": 6}},
	{"id": "art_void", "name": "太虚剑意", "pool": "arts", "weapon": "sword", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾", "秘页", "真解"], "item": "太虚剑意", "quality": "绝品", "elem": "metal",
		"art": {"kind": "damage", "mult": 4.2, "off_mult": 1.5, "cd": 5, "move": "太虚一剑", "target": "sweep", "desc": "剑归太虚：×4.2（非剑 ×1.5；冷却 5 手）"}, "item_stats": {"dmg": 7}},
	{"id": "art_tortoise", "name": "玄武神功", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾", "秘页", "真解"], "item": "玄武神功", "quality": "绝品", "elem": "earth",
		"art": {"kind": "guard", "turns": 3, "cut": 0.68, "cd": 5, "move": "玄武负山", "target": "mid", "desc": "气凝如甲：本手不出击，下 3 次受击减伤 32%（冷却 5 手）"}, "item_stats": {"dmg": 7}},
	{"id": "art_glimmer", "name": "浮光掠影", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾", "秘页", "真解"], "item": "浮光掠影", "quality": "绝品", "elem": "water",
		"art": {"kind": "dash", "mult": 2.0, "follow": 1.3, "cd": 4, "move": "浮光一瞬", "target": "mid", "desc": "身化浮光：×2.0 再追击 ×1.3（冷却 4 手）"}, "item_stats": {"dmg": 7}},
	{"id": "art_mend", "name": "补天诀", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾", "秘页", "真解"], "item": "补天诀", "quality": "绝品", "elem": "wood",
		"art": {"kind": "heal", "heal_pct": 0.6, "next_mult": 1.8, "cd": 5, "move": "妙手补天", "target": "mid", "desc": "回天有力：回血 60%，下次出手 ×1.8（冷却 5 手）"}, "item_stats": {"dmg": 7}},
	# ============================================================
	# ㊲ 破阵武学（新）——专门对付"前排挡刀"
	#   站位规矩带来的第一种新玩法：对面把脆皮藏在后面？这几门就是答案。
	#   良品档（早中期就能拿到），比同档武学略贵在冷却上——能越前排是有代价的。
	# ============================================================
	{"id": "art_breakline", "name": "破阵刀法", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "破阵刀法", "quality": "良品",
		"art": {"kind": "damage", "mult": 2.1, "cd": 4, "move": "破阵斩", "target": "mid",
			"desc": "刀走斜路，绕过当面那个：×2.1（冷却 4 手）"}},
	{"id": "art_snipe", "name": "穿云箭法", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "穿云箭法", "quality": "良品",
		"art": {"kind": "damage", "mult": 1.35, "cd": 4, "move": "穿云射月", "target": "back",
			"desc": "箭走高处，直取躲在最后的那个：×1.35（冷却 4 手）"}},
	{"id": "art_sweep", "name": "横扫千军", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下", "卷尾"], "item": "横扫千军", "quality": "良品",
		"art": {"kind": "damage", "mult": 1.5, "cd": 5, "move": "横扫千军", "target": "sweep",
			"desc": "一记横抡，人人有份：×1.5（冷却 5 手）"}},
	# ============================================================
	# v48 多段武学（新）——用户："增加些许多段攻击【最多3】的，也是倍率很低"
	#   规矩（两套引擎都认，见 battle_lite._art_multi_hits / duel_battle._strike）：
	#     · "hits" ＝ 段数，**2~3 段（写更多也只按 3 段算）**
	#     · 每一段都用同一个 `mult`，**每一段各自掷暴击、各自过一遍结算**
	#       （防御/护体/反伤都各算一次）——所以它的价值是"多几次暴击机会"，
	#       不是"总倍率更高"：下面每段的 mult 都刻意压得很低（0.42~0.68）。
	#     · 每段暴击都会触发"只要暴击就追击"那一套（苏青鸾的剑歌 / 专武·短歌行），
	#       所以它跟"暴击流"是一条线；堆暴击率比堆倍率更划算。
	#   ⚠ 别把它们写强了：三段全暴击的期望已经接近同档单段武学，一旦把 mult 抬高就超模。
	# ============================================================
	{"id": "art_chain3", "name": "连环三击", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "连环三击", "quality": "良品",
		"art": {"kind": "damage", "mult": 0.42, "hits": 3, "cd": 3, "move": "连环三击", "target": "front",
			"desc": "一招三手，招招都轻：三段，每段 ×0.42（每段各自掷暴击；冷却 3 手）"}},
	{"id": "art_twindag", "name": "柳叶双刺", "pool": "arts", "weapon": "dagger", "parts": ["卷上", "卷中", "卷下"], "item": "柳叶双刺", "quality": "良品",
		"art": {"kind": "damage", "mult": 0.6, "hits": 2, "off_mult": 0.4, "cd": 3, "move": "双刺连点", "target": "front",
			"desc": "短刃连点两下：两段，每段 ×0.6（非匕首 ×0.4；每段各自掷暴击；冷却 3 手）"}},
	{"id": "art_ruffle", "name": "乱披风", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "乱披风", "quality": "上品", "elem": "fire",
		"art": {"kind": "damage", "mult": 0.55, "hits": 3, "cd": 4, "move": "乱披风", "target": "front",
			"desc": "刀势散而不乱，一下叠一下：三段，每段 ×0.55（每段各自掷暴击；冷却 4 手）"}, "item_stats": {"dmg": 4}},
	{"id": "art_pearrain", "name": "暴雨梨花", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾"], "item": "暴雨梨花", "quality": "极品", "elem": "metal",
		"art": {"kind": "damage", "mult": 0.68, "hits": 3, "cd": 4, "move": "暴雨梨花", "target": "front",
			"desc": "一线三点，密不透风：三段，每段 ×0.68（每段各自掷暴击；冷却 4 手）"}, "item_stats": {"dmg": 6}},
	# ============================================================
	# ㊿ 加持武学（新）——**不伤人**，改给自己人上状态
	#   站位规矩的另一面：前排扛刀、后排输出，那"给哪一排上什么"就是一门学问。
	#   target 用 ally_front / ally_mid / ally_back / ally_all（加持专用，见 GameData.TARGETS）
	#   kind "bless" 认这些字段（都是"目标自己的手数"）：
	#     turns     持续几张"自己的手"——目标每出一次手减 1（放的那一手不算）
	#     cut       受击减伤（0.30＝减 30%）
	#     atk_pct   出手增伤
	#     crit_add  暴击 +N 个百分点
	#   ⚠ 同一个人身上只挂一条加持：新加持顶掉旧的（免得状态越滚越多、也免得
	#     两套数字叠着算不清）。两场战斗（游历决斗 / 出村爬塔）都认这几个字段。
	# ============================================================
	{"id": "art_aegis", "name": "坚壁旗令", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "坚壁旗令", "quality": "良品",
		"art": {"kind": "bless", "target": "ally_front", "turns": 3, "cut": 0.85, "cd": 4, "move": "坚壁旗令",
			"desc": "旗压前阵：自己这手不出击，最前面那位此后 3 手受击减伤 15%（冷却 4 手）"}},
	{"id": "art_sharporder", "name": "锐锋旗令", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "锐锋旗令", "quality": "良品",
		"art": {"kind": "bless", "target": "ally_back", "turns": 3, "atk_pct": 0.25, "cd": 4, "move": "锐锋旗令",
			"desc": "令指后阵：自己这手不出击，最后面那位此后 3 手伤害 +25%（冷却 4 手）"}},
	{"id": "art_oneheart", "name": "同心结阵", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下", "卷尾"], "item": "同心结阵", "quality": "良品",
		"art": {"kind": "bless", "target": "ally_all", "turns": 2, "cut": 0.91, "atk_pct": 0.13, "crit_add": 5, "cd": 5, "move": "同心结阵",
			"desc": "全队同心：自己这手不出击，全队此后 2 手伤害 +13%、受击减伤 9%、暴击 +5（冷却 5 手）"}},
	{"id": "art_springorder", "name": "回春令", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "回春令", "quality": "良品",
		"art": {"kind": "bless", "target": "ally_all", "turns": 4, "regen_pct": 0.06, "cd": 5, "move": "回春令",
			"desc": "药气弥漫：自己这手不出击，全队此后 4 手，每手开头回 6% 气血上限（冷却 5 手）"}},
	{"id": "art_galeorder", "name": "疾风令", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "疾风令", "quality": "良品",
		"art": {"kind": "bless", "target": "ally_all", "turns": 3, "spd_pct": 0.30, "cd": 5, "move": "疾风令",
			"desc": "脚下生风：自己这手不出击，全队此后 3 手速度 +30%——出手更靠前，快过对面一倍还能多打一下（冷却 5 手）"}},
	{"id": "art_rageorder", "name": "聚气令", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "聚气令", "quality": "良品",
		"art": {"kind": "bless", "target": "ally_back", "turns": 3, "rage_pct": 0.5, "cd": 4, "move": "聚气令",
			"desc": "气聚后阵：自己这手不出击，最后面那位此后 3 手怒气获取 +50%——大招来得更快（冷却 4 手）"}},
	{"id": "art_ironring", "name": "铁壁合围", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下", "卷尾"], "item": "铁壁合围", "quality": "良品",
		"art": {"kind": "bless", "target": "ally_mid", "turns": 3, "cut": 0.80, "cd": 5, "move": "铁壁合围",
			"desc": "护住腰眼：自己这手不出击，中间那位此后 3 手受击减伤 20%（队里只有两人时落到前排那个身上；冷却 5 手）"}},
	# ============================================================
	# v52 负面状态武学（新）——用户："参考三国志谋定天下这款 SLG，我要加一些负面状态，
	#   类似缴械啊、燃烧啊 等"
	#
	#   规矩（表在 shared/data_status.gd，两套引擎都只认那几个字段）：
	#     "apply": {"id": 状态键, "turns": 持续几手, "stacks": 层数, "chance": 触发几率}
	#     · turns 写 0（或省略）＝ 用状态表里的默认时长
	#     · 状态挂在**挨打的那个人**身上，**这一手打完**才挂（伤害先结算，跟别的效果不冲突）
	#     · 层数与时长都由状态表定（叠加/只刷新时长各不同），这里只写"上几层、几手"
	#
	#   ⚠ **倍率刻意压到同档武学的六~七成**——状态本身就是收益，
	#     不然"又疼又上状态"的武学会把纯伤害武学全挤掉。同档参考：
	#     良品单体 2.1~2.2 / 上品 2.6~2.8 / 极品 3.6 上下。
	# ============================================================
	{"id": "art_flameblade", "name": "烈焰刀", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "烈焰刀", "quality": "良品",
		"art": {"kind": "damage", "mult": 1.6, "cd": 4, "move": "烈火燎原", "target": "front",
			"apply": {"id": "burn", "turns": 2, "stacks": 1},
			"desc": "刀身带火：×1.6，并给对手上「燃烧」——此后 2 手每手掉 5% 气血上限（可叠 2 层；冷却 4 手）"}},
	{"id": "art_softsinew", "name": "软筋散", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "软筋散", "quality": "良品",
		"art": {"kind": "damage", "mult": 1.2, "cd": 4, "move": "撒粉拂面", "target": "front",
			"apply": {"id": "weak", "turns": 3, "stacks": 1},
			"desc": "一蓬药粉迎面：×1.2，并给对手上「虚弱」——此后 3 手出手伤害 −25%/层（可叠 2 层；冷却 4 手）"}},
	{"id": "art_disarmhand", "name": "卸甲手", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "卸甲手", "quality": "上品",
		"art": {"kind": "damage", "mult": 2.4, "cd": 4, "move": "反手卸甲", "target": "front",
			"apply": {"id": "disarm", "turns": 2, "stacks": 1},
			"desc": "反手磕在腕上：×2.4，并「缴械」——对手此后 2 手不能普攻（武学与大招照放；冷却 4 手）"}, "item_stats": {"dmg": 4}},
	{"id": "art_soulchime", "name": "摄魂音", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾"], "item": "摄魂音", "quality": "上品", "elem": "wood",
		"art": {"kind": "damage", "mult": 1.8, "cd": 5, "move": "摄魂夺魄", "target": "mid",
			"apply": {"id": "stun", "turns": 1, "stacks": 1, "chance": 0.75},
			"desc": "音到魂摇：×1.8，七成半几率「震慑」——对手下一手整个不出（挨打照旧；冷却 5 手）"}, "item_stats": {"dmg": 4}},
	{"id": "art_stonebreak", "name": "裂石拳", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾", "秘页"], "item": "裂石拳", "quality": "极品", "elem": "earth",
		"art": {"kind": "damage", "mult": 3.2, "cd": 5, "move": "裂石开碑", "target": "front",
			"apply": {"id": "sunder", "turns": 3, "stacks": 2},
			"desc": "一拳打散护体：×3.2，并「破防」2 层——对手此后 3 手挨打受伤 +30%/层（可叠 2 层；冷却 5 手）"}, "item_stats": {"dmg": 6}},
	{"id": "art_silkleg", "name": "缠丝腿", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾", "秘页"], "item": "缠丝腿", "quality": "极品", "elem": "wood",
		"art": {"kind": "damage", "mult": 2.9, "cd": 4, "move": "缠丝绊月", "target": "mid",
			"apply": {"id": "slow", "turns": 3, "stacks": 1},
			"desc": "腿法如丝缠绕：×2.9，并「迟缓」——对手此后 3 手速度 −30%（出手更靠后；冷却 4 手）"}, "item_stats": {"dmg": 6}},
	# ============================================================
	# v53：第二轮点名要的几种负面 + **驱散**
	#   用户："驱散可以加 还有削弱怒气啊 禁止技能释放的啊 禁止大招释放的啊等
	#          还有禁止被动的啊 技能冷却延长的啊 若有负面每一种受到伤害增加的啊
	#          禁疗别百分百吧 60%-80% 就行"
	#   （"受到伤害增加"那一条＝表里早有的「破防」，没再另加一条重复的）
	#   规矩与上面那批一样：`apply` 的 turns/stacks/chance 由这里定，效果由 data_status 定，
	#   倍率同样压在同档的六~七成（状态本身就是收益）。
	# ============================================================
	{"id": "art_throatpin", "name": "封喉指", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "封喉指", "quality": "良品",
		"art": {"kind": "damage", "mult": 1.3, "cd": 4, "move": "锁喉点穴", "target": "front",
			"apply": {"id": "silence", "turns": 2, "stacks": 1},
			"desc": "指风锁喉：×1.3，并「沉默」——对手此后 2 手放不出武学（普攻与大招照放；冷却 4 手）"}},
	{"id": "art_dullrage", "name": "泄气散", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "泄气散", "quality": "良品",
		"art": {"kind": "damage", "mult": 1.1, "cd": 4, "move": "撒粉泄气", "target": "front",
			"apply": {"id": "ragecut", "turns": 3, "stacks": 1},
			"desc": "一蓬泄气药粉：×1.1，并「挫锐」——当场打掉对手 30 点怒气，此后 3 手怒气获取只剩四成（冷却 4 手）"}},
	{"id": "art_ultbreak", "name": "断势拳", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "断势拳", "quality": "上品", "elem": "fire",
		"art": {"kind": "damage", "mult": 2.2, "cd": 4, "move": "断势截招", "target": "front",
			"apply": {"id": "ultseal", "turns": 2, "stacks": 1},
			"desc": "一拳截在起势上：×2.2，并「封招」——对手此后 2 手放不出大招（怒气留着，满了也放不出来；冷却 4 手）"}, "item_stats": {"dmg": 4}},
	{"id": "art_slowcast", "name": "滞气针", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾"], "item": "滞气针", "quality": "上品",
		"art": {"kind": "damage", "mult": 1.6, "cd": 4, "move": "滞气凝脉", "target": "mid",
			"apply": {"id": "cdslow", "turns": 3, "stacks": 1},
			"desc": "细针入脉：×1.6，并「滞涩」——对手此后 3 手技能冷却 +2 手（当下正在冷却的一起往后推；冷却 4 手）"}, "item_stats": {"dmg": 4}},
	# ⚠ 「闭窍」不在这里——用户："闭窍是针对玩家的"：那一条只有**首领**会给你上
	#   （出村第 50 关往后的「点窍手」模板、游历的精英与寨主），玩家的解法是「清心诀」。
	# ---- 驱散（净化）：自己这手不出击，**随机**洗掉全队身上一条负面，顺手磕掉对手的护体与蓄势 ----
	{"id": "art_clearheart", "name": "清心诀", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下", "卷尾"], "item": "清心诀", "quality": "良品",
		"art": {"kind": "cleanse", "target": "ally_all", "cleanse": 1, "dispel_foe": true, "cd": 4, "move": "清心涤虑",
			"desc": "涤荡杂气：自己这手不出击，全队各随机洗掉身上一条负面（挂三条时不一定洗得中你最想洗的那条），并磕掉当前对手的护体与蓄势（冷却 4 手）"}},
	# ---- ㊿z6：专武功法（数值 + 照主人招式定制的机制；**数值随升星提升**）----
	#   照崩铁"专武/光锥"的口径：**按命途限装、不锁人**（别人也能装、也能吃基础收益），
	#   被动**常驻**（不是"放一手"）。这里"命途"那一层不设限：专武认人不认兵器。
	#   · 到手方式**暂不开放**（no_drop＝游历/爬塔/首领赏都不出；等设计好来路再接）
	#   · "role" 只是推荐（面板/仓库标"为某某量身"），**不拦着装**
	#   · "fx" 用五问天赋那套单位（整数＝百分点）；"mech" 用运签卡那套（小数＝比例）
	#     ⚠ 两套单位绝不能混在一个字典里（差 100 倍）
	#   · **随星放大**：装备者每有 1 星，专武的数值 ×(1 + 0.1×(星−1))——
	#     1 星 ×1.0、6 星 ×1.5（见 Cards.art_star_scale）
	{"id": "art_ex_changfeng", "name": "长风诀", "pool": "arts", "weapon": "any", "role": "player", "quality": "绝品", "no_drop": true,
		"parts": ["卷上", "卷中", "卷下", "卷尾"], "item": "长风诀",
		"art": {"kind": "passive", "fx": {"dmg": 5}, "move": "长风自引",
			"mech": {"ult_dmg": 0.10, "ult_per_hit": 0.06, "ult_chain_up": 0.20, "ult_chain_turns": 3},
			"desc": "为少侠量身定做——常驻：出手伤害 +5%。\n专属机制：大招伤害 +10%；对多人时每一名中招的对手让那一击再 +6%（逐个叠）；\n放完大招后三回合内再放大招，那一下再 +20%（续得上就一路 +20%）。数值随星数提升"}},
	{"id": "art_ex_tiebi", "name": "铁壁桩功", "pool": "arts", "weapon": "any", "role": "chen_shi", "quality": "绝品", "no_drop": true,
		"parts": ["卷上", "卷中", "卷下", "卷尾"], "item": "铁壁桩功",
		# v65h（用户：「修专武」）：原来 fx 栏挂着 rage_on_hit / thorn_up ——
		#   这两条是**运签卡那套单位（小数＝比例）**，住在 fx 栏只有游历认（那边两栏都并），
		#   塔战那边 smech 只读 mech 栏 → 「受击回怒 +15%、反刺 +15%」在塔战里整个丢了。
		#   挪进 mech 栏（两套引擎都读）——数值一个没改。
		"art": {"kind": "passive", "fx": {}, "move": "铁桩入地",
			"mech": {"rage_on_hit": 0.15, "thorn_up": 0.15, "ult_cut": 0.075, "thorn_all": 1, "thorn_per_hit": 0.10, "thorn_heal": 0.03},
			"desc": "为陈石量身定做——常驻：受击怒气 +15%、反刺 +15%。\n专属机制：放大招期间减伤 +7.5%，且反刺打全体；\n自己每击中一名敌人，反刺再 +10%（封顶 +100%）；每次反刺回 3% 气血。数值随星数提升"}},
	{"id": "art_ex_duange", "name": "短歌行", "pool": "arts", "weapon": "any", "role": "qingluan", "quality": "绝品", "no_drop": true,
		"parts": ["卷上", "卷中", "卷下", "卷尾"], "item": "短歌行",
		"art": {"kind": "passive", "fx": {"crit": 5, "crit_dmg": 13}, "move": "短歌相和",
			"mech": {"follow_dmg": 0.35, "follow_crit_up": 0.20},
			"desc": "为苏青鸾量身定做（匕首）：暴击 +5%、暴击伤害 +13%——常驻。\n触发暴击时，追击伤害 +35%；追击自己暴击时，再 +20%。数值随星数提升"}},
	# ============================================================
	# v132：补齐「功法归类」里空着的那几类（用户："功法要做归类了 …每种都要有"）
	#   规矩：非元素的从**良品**起、元素的从**上品**起（与 v88 元素那条同一条尺）。
	#   归类写在 ART_CAT 表里（哪一门归哪一类，看那张表；本文只管数值与文案）。
	#   补的是这五类：单段攻击 · 群体控制 · 被动增益 · 单段元素攻击 · 单体元素攻击 · 站位元素单体攻击
	# ============================================================
	# ---- 单段攻击（物理·一段·当面）：原来一门都没有（只有多段/站位/群体）----
	{"id": "art_palm", "name": "劈山掌", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "劈山掌", "quality": "良品",
		"art": {"kind": "damage", "mult": 2.3, "cd": 4, "move": "力劈华山", "target": "front",
			"desc": "一掌当胸，不绕不避：×2.3（冷却 4 手）——最直白的一门，重而慢"}},
	{"id": "art_fist", "name": "伏虎拳", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "伏虎拳", "quality": "良品",
		"art": {"kind": "damage", "mult": 1.9, "cd": 3, "move": "伏虎归山", "target": "front",
			"desc": "拳走中宫，一拳接一拳：×1.9（冷却 3 手）——轻一点，但转得快"}},
	# ---- 群体控制（负面）：原来一门都没有 ----
	{"id": "art_mazedust", "name": "迷魂散", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "迷魂散", "quality": "良品",
		"art": {"kind": "damage", "mult": 1.15, "cd": 5, "move": "满堂迷烟", "target": "sweep",
			"apply": {"id": "weak", "turns": 2, "stacks": 1},
			"desc": "一蓬药粉撒开：×1.15，全场「虚弱」——此后 2 手出手伤害 −25%（冷却 5 手）"}},
	{"id": "art_thunderroar", "name": "惊雷吼", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "惊雷吼", "quality": "上品",
		"art": {"kind": "damage", "mult": 1.35, "cd": 5, "move": "雷吼震野", "target": "sweep",
			"apply": {"id": "stun", "turns": 1, "stacks": 1, "chance": 0.5},
			"desc": "一声暴喝压过去：×1.35，全场五成几率「震慑」——各自下一手整个不出（冷却 5 手）"}, "item_stats": {"dmg": 4}},
	# ---- 被动增益（非专属）：装备即生效、不进出手轮转 ----
	{"id": "art_calm", "name": "静心诀", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "静心诀", "quality": "良品",
		"art": {"kind": "passive", "fx": {"hp_pct": 5, "def": 2}, "move": "心如止水",
			"desc": "常驻：气血上限 +5%、防御 +2。装上就生效，不占出手——被「闭窍」点住时也会失效"}},
	{"id": "art_galeheart", "name": "疾风心法", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "疾风心法", "quality": "上品",
		"art": {"kind": "passive", "fx": {"spd": 3, "crit": 3}, "move": "风随心转",
			"desc": "常驻：速度 +3、暴击 +3。出手更靠前——快过对面一倍还能多打一下"}, "item_stats": {"dmg": 4}},
	# ---- 单段元素攻击（元素·一段·当面·纯伤害）----
	{"id": "art_metalpoint", "name": "庚金指", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "庚金指", "quality": "上品", "elem": "metal",
		"art": {"kind": "damage", "mult": 2.6, "cd": 3, "move": "金锋一点", "target": "front",
			"desc": "指如金锋，一点透甲：×2.6（走金元素通道，不吃对手防御、走它的金抗；冷却 3 手）"}, "item_stats": {"dmg": 4}},
	{"id": "art_firepalm", "name": "离火掌", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "离火掌", "quality": "上品", "elem": "fire",
		"art": {"kind": "damage", "mult": 2.5, "cd": 3, "move": "离火焚风", "target": "front",
			"desc": "掌心一热，火气扑面：×2.5（走火元素通道；冷却 3 手）"}, "item_stats": {"dmg": 4}},
	# ---- 单体元素攻击（元素·单体·以**元素印记**压一个点；它不封手不禁招，所以不算控制）----
	{"id": "art_icedart", "name": "玄冰指", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "玄冰指", "quality": "上品", "elem": "water",
		"art": {"kind": "damage", "mult": 1.9, "cd": 4, "move": "寒指入脉", "target": "front",
			"apply": {"id": "soak", "turns": 3, "stacks": 1},
			"desc": "一指寒意入脉：×1.9，并给对手上「水浸」印记——此后 3 手速度 −25%（可叠 3 层，叠满触发「踏浪」；冷却 4 手）"}, "item_stats": {"dmg": 4}},
	{"id": "art_burnpalm", "name": "燎原掌", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "燎原掌", "quality": "上品", "elem": "fire",
		"art": {"kind": "damage", "mult": 1.85, "cd": 4, "move": "星火燎原", "target": "front",
			"apply": {"id": "burn", "turns": 3, "stacks": 1},
			"desc": "一掌拍上火种：×1.85，并给对手上「燃烧」印记——此后 3 手每手掉 5% 气血上限（可叠 3 层，叠满「爆燃」；冷却 4 手）"}, "item_stats": {"dmg": 4}},
	# ---- 站位元素单体攻击（元素·单体·越过前排够中/后排）----
	{"id": "art_coldriver", "name": "寒江剑法", "pool": "arts", "weapon": "sword", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "寒江剑法", "quality": "上品", "elem": "water",
		"art": {"kind": "damage", "mult": 2.4, "off_mult": 1.3, "cd": 4, "move": "寒江独钓", "target": "back",
			"desc": "剑走寒江，直取躲在最后的那个：×2.4（非剑 ×1.3；走水元素通道；冷却 4 手）"}, "item_stats": {"dmg": 4}},
	{"id": "art_windarrow", "name": "裂风箭", "pool": "arts", "weapon": "anqi", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "裂风箭", "quality": "上品", "elem": "metal",
		"art": {"kind": "damage", "mult": 2.3, "off_mult": 1.25, "cd": 4, "move": "裂风穿云", "target": "mid",
			"desc": "箭破风声，从当面的肩头掠过去：×2.3（非暗器 ×1.25；走金元素通道；冷却 4 手）"}, "item_stats": {"dmg": 4}},
]

const ELEM_CN := {"metal": "金", "wood": "木", "water": "水", "fire": "火", "earth": "土", "phys": "物理", "true": "真实"}

# ---- ㊿z4：被动功法 / 量身定做的辅助功法（带 "role" 的武学）----
#   role：推荐给谁（空串＝通用）。**只是推荐，不拦着装**——照崩铁专武那把尺子
#   （专武按命途限装、不锁人；这里"命途"那一层就是 weapon 的兵器类型）。
const ART_ROLE_CN := {"player": "少侠", "chen_shi": "陈石", "qingluan": "苏青鸾"}

static func art_role(sid: String) -> String:
	return str(by_id(sid).get("role", ""))

static func art_owner_cn(sid: String) -> String:
	var r := art_role(sid)
	if r == "":
		return ""
	return str(ART_ROLE_CN.get(r, r))

# 列表/详情那一行要写的"为某某量身定做"；通用武学＝空串
static func art_owner_note(sid: String) -> String:
	var o := art_owner_cn(sid)
	return "" if o == "" else "为" + o + "量身定做"

# 被动功法（装备即生效、不进出手轮转）
static func art_is_passive(sid: String) -> bool:
	return str(art_of(sid).get("kind", "")) == "passive"

# 被动功法的常驻加成（**五问天赋那套单位**：整数＝百分点）
static func art_passive_fx(sid: String) -> Dictionary:
	return art_of(sid).get("fx", {})

# 被动功法的常驻机制（**运签卡那套单位**：小数＝比例）——照主人招式定制的那一条
static func art_passive_mech(sid: String) -> Dictionary:
	return art_of(sid).get("mech", {})

# 这件是不是**不可掉落**的（专武：游历/爬塔/首领赏都不出，等设计好来路再接）
static func is_no_drop(sid: String) -> bool:
	return bool(by_id(sid).get("no_drop", false))

# ㊿z6：专武的数值**随装备者的星数**放大：1 星 ×1.0、每多 1 星 +10%（6 星 ×1.5）。
#   ⚠ **计数类与旗标类不放大**（"持续几手/几回合/几段"随星变长会走样；
#     `ult_dur / follow_hits / art_cd_minus / ult_chain_turns / thorn_all / art_any_weapon`）。
const EX_STAR_STEP := 0.1
const EX_NO_SCALE := ["ult_dur", "follow_hits", "art_cd_minus", "ult_chain_turns", "thorn_all", "art_any_weapon"]

static func art_star_scale(star: int) -> float:
	return 1.0 + EX_STAR_STEP * float(maxi(0, star - 1))

# 取专武的常驻数值 / 机制（已按星数放大过）——两套引擎都读这两个口
static func art_passive_fx_scaled(sid: String, star: int) -> Dictionary:
	return _scale_dict(art_passive_fx(sid), art_star_scale(star))

static func art_passive_mech_scaled(sid: String, star: int) -> Dictionary:
	return _scale_dict(art_passive_mech(sid), art_star_scale(star))

static func _scale_dict(d: Dictionary, k: float) -> Dictionary:
	var out: Dictionary = {}
	for key in d.keys():
		var kk := str(key)
		if EX_NO_SCALE.has(kk):
			out[kk] = d[key]        # 计数/旗标原样搬过去
		else:
			out[kk] = float(d[key]) * k
	return out

const STAT_ORDER := ["atk", "hp", "spd", "crit", "def", "dodge", "dmg", "crit_dmg"]
const STAT_CN := {"atk": "攻", "hp": "气血", "spd": "速度", "crit": "暴击", "def": "防御", "dodge": "闪避", "dmg": "伤害", "crit_dmg": "暴伤"}
# v35：闪避**移出**百分比表——它现在是"数值"（与防御一样两数对拼），不再带 %
const STAT_PCT := ["crit", "dmg", "crit_dmg"]

static func by_id(id: String) -> Dictionary:
	for s in SETS:
		if str(s["id"]) == id:
			return s
	return {}

# 注：本函数绝不能叫 set_name —— 与引擎内置 Resource.set_name 撞名时，
# Cards.set_name(...) 会命中内置方法、静默返回空值（曾导致界面显示 <null>）。
static func name_of(id: String) -> String:
	return str(by_id(id).get("name", id))

static func parts_of(id: String) -> Array:
	return by_id(id).get("parts", ["一", "二", "三"])

static func part_count(id: String) -> int:
	return maxi(1, parts_of(id).size())

const QUALITY_ORDER := ["凡品", "良品", "上品", "极品", "绝品"]

static func quality_of(id: String) -> String:
	return str(by_id(id).get("quality", "凡品"))

static func q_idx(id: String) -> int:
	return maxi(0, QUALITY_ORDER.find(quality_of(id)))

const PRICE_MUL := [1.0, 2.0, 3.0, 5.0, 8.0]

static func price_mul(id: String) -> float:
	return float(PRICE_MUL[clampi(q_idx(id), 0, PRICE_MUL.size() - 1)])

static func is_arts(id: String) -> bool:
	return str(by_id(id).get("pool", "")) == "arts"

static func is_buff(id: String) -> bool:
	return str(by_id(id).get("pool", "")) == "buff"

static func is_gear(id: String) -> bool:
	var p := str(by_id(id).get("pool", ""))
	return p == "armor" or p == "helm" or p == "cloak"

static func weapon_of(id: String) -> String:
	return str(by_id(id).get("weapon", "any"))

static func elem_of(id: String) -> String:
	return str(by_id(id).get("elem", ""))

static func art_of(id: String) -> Dictionary:
	return by_id(id).get("art", {})

static func art_move(id: String) -> String:
	return str(by_id(id).get("art", {}).get("move", ""))

static func art_cd(id: String) -> int:
	return int(by_id(id).get("art", {}).get("cd", 3))

# ============================================================
# v132：**功法归类**（用户："功法要做归类了 …每种都要有 从良品开始 元素从上品开始"）
#
#   15 类，真源就是下面这两张表：
#     · CATS    —— 类目本身（名字 / 组 / 门槛 / 一句话说明）
#     · ART_CAT —— **每一门功法归哪一类**（谁归错、谁漏了，一眼看得出）
#
#   三条规矩（`cat_check()` 逐条自检，自检/探针会把结果打出来）：
#     ① **每种都要有**：15 类各自至少两门（最少的一类也有 2 门）；
#     ② **从良品起**：非元素四路（攻击/增益/控制/被动）在**良品**档就有货；
#     ③ **元素从上品起**：凡带 `elem` 的功法一律**上品及以上**（与 v88 那条元素规矩同一条尺），
#        五类元素功法（单段/多段/单体/站位单体/群体）全落在上品~绝品。
#
#   ⚠ 判类口径（免得两类打架）：
#     · **控制**＝限制行动 / 削弱的负面（缴械·沉默·封招·虚弱·破防·迟缓·挫锐·滞涩·震慑·封脉·打断）
#     · **单体元素攻击**＝元素·单体，上的是**元素印记**（燃烧/水浸这种持续元素伤害）——
#       它不封手不禁招，所以不算"控制"
#     · **多段**＝`hits` 2~3，或 `kind:"dash"`（本体一击＋追击一击，本来就是两段）
#     · **站位单体**＝只打一个、但 `target` 是 mid/back（越过前排够后排）
#     · **群体**＝`target:"sweep"`
#     · **增益**＝`kind:"bless"`（给同伴上）或 `guard`/`heal`（自身护体/回气/回血）
#     · **被动**＝`kind:"passive"`；带 `role` 的那三门是**专武**（单独一类）
# ============================================================
const CAT_GROUP_CN := {"atk": "攻击", "buff": "增益", "ctrl": "控制", "pass": "被动", "elem": "元素", "ex": "专属"}
const CAT_GROUPS := ["atk", "buff", "ctrl", "pass", "elem", "ex"]

const CATS := [
	{"id": "atk_one", "grp": "atk", "name": "单段攻击", "short": "单段", "min_q": 1,
		"desc": "一段打完、打当面的敌人（物理；胜在冷却短）"},
	{"id": "atk_multi", "grp": "atk", "name": "多段攻击", "short": "多段", "min_q": 1,
		"desc": "2~3 段（含追击），每段各自掷暴击（物理）"},
	{"id": "atk_row", "grp": "atk", "name": "站位单体攻击", "short": "站位", "min_q": 1,
		"desc": "只打一个，但越过前排够得到中/后排（物理）"},
	{"id": "atk_all", "grp": "atk", "name": "群体攻击", "short": "群体", "min_q": 1,
		"desc": "一扫一片，场上活着的都挨（物理）"},
	{"id": "buff_one", "grp": "buff", "name": "单体增益", "short": "单增", "min_q": 1,
		"desc": "给自己或一个同伴：护体 / 回气 / 增伤 / 聚气"},
	{"id": "buff_all", "grp": "buff", "name": "群体增益", "short": "群增", "min_q": 1,
		"desc": "全队一起吃：护体 / 增伤 / 加速 / 回春 / 驱散"},
	{"id": "ctrl_one", "grp": "ctrl", "name": "控制（负面）", "short": "控制", "min_q": 1,
		"desc": "打一个并上负面状态（缴械 / 沉默 / 封招 / 虚弱 / 破防 …）"},
	{"id": "ctrl_all", "grp": "ctrl", "name": "群体控制（负面）", "short": "群控", "min_q": 1,
		"desc": "全场一起上负面状态"},
	{"id": "passive", "grp": "pass", "name": "被动增益", "short": "被动", "min_q": 1,
		"desc": "装备即生效、不进出手轮转（常驻数值 / 机制）"},
	{"id": "elem_seg", "grp": "elem", "name": "单段元素攻击", "short": "单段元", "min_q": 2,
		"desc": "元素·一段·打当面（上品起）"},
	{"id": "elem_multi", "grp": "elem", "name": "多段元素攻击", "short": "多段元", "min_q": 2,
		"desc": "元素·2~3 段（上品起）"},
	{"id": "elem_one", "grp": "elem", "name": "单体元素攻击", "short": "单体元", "min_q": 2,
		"desc": "元素·单体·以元素印记压一个点（上品起）"},
	{"id": "elem_row", "grp": "elem", "name": "站位元素单体攻击", "short": "站位元", "min_q": 2,
		"desc": "元素·单体·越过前排够中/后排（上品起）"},
	{"id": "elem_all", "grp": "elem", "name": "群体元素攻击", "short": "群体元", "min_q": 2,
		"desc": "元素·一扫一片（上品起）"},
	{"id": "ex", "grp": "ex", "name": "专武功法", "short": "专武", "min_q": 4,
		"desc": "为某个人量身定做、常驻被动（暂不掉落，等来路设计好再接）"},
]

# 每一门功法的归类（60 门：45 门旧的 ＋ v132 新补的 12 门 ＋ 3 门专武）
const ART_CAT := {
	# ---- 凡品（4）——入门那一窗，照旧排在最前 ----
	"art_wind": "atk_row", "art_iron": "buff_one", "art_stone": "ctrl_one", "art_breath": "buff_one",
	# ---- 良品（25）：攻击 ----
	"art_palm": "atk_one", "art_fist": "atk_one",
	"art_chain3": "atk_multi", "art_twindag": "atk_multi", "art_shadow": "atk_multi",
	"art_cloud": "atk_row", "art_breakline": "atk_row", "art_snipe": "atk_row",
	"art_sweep": "atk_all", "art_cleave": "atk_all",
	# 良品：增益
	"art_aegis": "buff_one", "art_sharporder": "buff_one", "art_rageorder": "buff_one", "art_ironring": "buff_one",
	"art_bell": "buff_one",
	"art_oneheart": "buff_all", "art_springorder": "buff_all", "art_galeorder": "buff_all", "art_clearheart": "buff_all",
	# 良品：控制
	"art_flameblade": "ctrl_one", "art_softsinew": "ctrl_one", "art_throatpin": "ctrl_one", "art_dullrage": "ctrl_one",
	"art_mazedust": "ctrl_all",
	# 良品：被动
	"art_calm": "passive",
	# ---- 上品（17）----
	"art_swallow": "atk_multi", "art_spring": "buff_one",
	"art_disarmhand": "ctrl_one", "art_soulchime": "ctrl_one", "art_ultbreak": "ctrl_one", "art_slowcast": "ctrl_one",
	"art_thunderroar": "ctrl_all", "art_galeheart": "passive",
	"art_metalpoint": "elem_seg", "art_firepalm": "elem_seg",
	"art_icedart": "elem_one", "art_burnpalm": "elem_one",
	"art_coldriver": "elem_row", "art_windarrow": "elem_row",
	"art_ruffle": "elem_multi",
	"art_river": "elem_all", "art_thunder": "elem_all",
	# ---- 极品（7）----
	"art_bulwark": "buff_one", "art_bloom": "buff_one",
	"art_stonebreak": "ctrl_one", "art_silkleg": "ctrl_one",
	"art_snow": "elem_multi", "art_pearrain": "elem_multi", "art_ocean": "elem_all",
	# ---- 绝品（4）＋ 专武（3）----
	"art_tortoise": "buff_one", "art_mend": "buff_one",
	"art_glimmer": "elem_multi", "art_void": "elem_all",
	"art_ex_changfeng": "ex", "art_ex_tiebi": "ex", "art_ex_duange": "ex",
}

static func cat_of(sid: String) -> String:
	return str(ART_CAT.get(sid, ""))

static func cat_def(cid: String) -> Dictionary:
	for c in CATS:
		if str(c["id"]) == cid:
			return c
	return {}

static func cat_name(cid: String) -> String:
	return str(cat_def(cid).get("name", "未归类"))

static func cat_short(cid: String) -> String:
	return str(cat_def(cid).get("short", "?"))

static func cat_group_of(sid: String) -> String:
	return str(cat_def(cat_of(sid)).get("grp", ""))

# 卡面/列表上那一小段（没归类＝空串，不会凭空多两个字）
static func cat_tag(sid: String) -> String:
	var c := cat_of(sid)
	return "" if c == "" else "【" + cat_name(c) + "】"

# 详情里那一行："归类：单段攻击（攻击）——一段打完…"
static func cat_line(sid: String) -> String:
	var d := cat_def(cat_of(sid))
	if d.is_empty():
		return ""
	return "归类：" + str(d["name"]) + "（" + str(CAT_GROUP_CN.get(str(d["grp"]), "")) + "）——" + str(d["desc"])

# 类里都有哪几门（按 SETS 顺序）
static func arts_in_cat(cid: String) -> Array:
	var out: Array = []
	for s in SETS:
		if str(s.get("pool", "")) != "arts":
			continue
		var sid := str(s["id"])
		if cat_of(sid) == cid:
			out.append(sid)
	return out

# 一组的类（给"归类"筛选按钮用：攻击/增益/控制/被动/元素/专属）
static func cats_of_group(g: String) -> Array:
	var out: Array = []
	for c in CATS:
		if str(c["grp"]) == g:
			out.append(str(c["id"]))
	return out

static func cat_count(cid: String) -> int:
	return arts_in_cat(cid).size()

# 这一门能不能进"这一类"的筛选（组的粗筛）
static func in_group(sid: String, g: String) -> bool:
	if g == "":
		return true
	return cat_group_of(sid) == g

# ============================================================
# 自检：三条规矩逐条查（返回问题清单，空＝全过）
#   · 15 类都有货 · 非元素类良品起有货 · 元素类全是上品起 · 没有漏归类的功法
#   自检/探针里调它（print(Cards.cat_check())）——加新功法忘了归类，这里会当场报出来。
# ============================================================
static func cat_check() -> Array:
	var out: Array = []
	for c in CATS:
		var cid := str(c["id"])
		var ids := arts_in_cat(cid)
		if ids.is_empty():
			out.append("✗ 类目空着：「" + str(c["name"]) + "」一门都没有")
			continue
		var minq := int(c["min_q"])
		var has_top := false
		for sid_v in ids:
			if q_idx(str(sid_v)) >= minq:
				has_top = true
				break
		if not has_top:
			out.append("✗ 「" + str(c["name"]) + "」没有 " + str(QUALITY_ORDER[clampi(minq, 0, 4)]) + " 及以上的功法")
	for s in SETS:
		if str(s.get("pool", "")) != "arts":
			continue
		var sid := str(s["id"])
		if cat_of(sid) == "":
			out.append("✗ 没归类：" + sid + "（" + str(s.get("name", "")) + "）")
			continue
		if elem_of(sid) != "" and q_idx(sid) < 2:
			out.append("✗ 元素功法低于上品：" + sid + "（" + str(s.get("name", "")) + "）")
	return out

# 归类总表（一行一类，给自检/文档用）
static func cat_table_lines() -> Array:
	var out: Array = []
	for c in CATS:
		var cid := str(c["id"])
		var names: Array = []
		for sid_v in arts_in_cat(cid):
			names.append(str(name_of(str(sid_v))) + "·" + quality_of(str(sid_v)))
		out.append("【" + str(c["name"]) + "】×" + str(names.size()) + "：" + "、".join(PackedStringArray(names)))
	return out

static func card_name(id: String, part_index: int) -> String:
	var s := by_id(id)
	var parts: Array = s.get("parts", [])
	if part_index >= 0 and part_index < parts.size():
		return str(s.get("name", id)) + "·" + str(parts[part_index])
	return str(s.get("name", id))

static func item_name(id: String) -> String:
	return str(by_id(id).get("item", id))

# 残卡/残页的"这一片值多少"——v35（用户报的：护甲残片在包裹里写着"攻 +2"）：
#   以前这里只分"武学 / 其它"两支，其它**一律** {"atk": 1 + q}——于是护甲·玉佩·披风
#   的残片全按兵器算，包裹详情里写"加成：攻 +2"，跟这件东西的属性毫无关系。
#   现在按**成品属性 ÷ 页数**给这一片的份额（一片≈成品的 1/N），于是：
#     兵器 → 攻（/伤害%）· 护甲 → 气血/防御 · 玉佩 → 暴击/防御/气血 ·
#     披风 → 速度/闪避/气血 · 武学 → 伤害%
#   ⚠ 这份份额是**真加进属性**的：游历里"包里带着的残卡"会算进 stats_of（见 run_state），
#     所以不能只改显示——数值大小要与成品对得上（1/N 就是这个道理）。
static func _share_stats(base: Dictionary, parts: int) -> Dictionary:
	var n := maxi(1, parts)
	var out: Dictionary = {}
	for k in base.keys():
		var v := int(round(float(base[k]) / float(n)))
		out[k] = maxi(1, v)   # 最少 1：一片不能是 0（玩家看不到"这一片有什么用"）
	return out

static func card_bonus(id: String) -> Dictionary:
	var q := q_idx(id)
	if is_arts(id):
		return {"dmg": 2 + q}   # v51：残卡这条线也一起压（原 2+2q：2/4/6/8/10 → 现 2/3/4/5/6）
	if is_gear(id):
		# 护甲/玉佩/披风：按成品属性摊（各走各的属性，不再串成攻）
		return _share_stats(item_stats(id), part_count(id))
	return {"atk": 1 + q}

# ㊺：凡品档的数值。兵器/武学凡是表里没写 item_stats 的，都归这一档——
#   写成常量是为了让"6 攻""8 伤"这两个数在表里看得见，而不是藏在函数的兜底里。
#   v35：兵器那一档跟着装备上调一起走（4 → 6）。
const FANPIN_WEAPON_ATK := 9
const FANPIN_ART_DMG := 5
# v63（用户："良品的金钟罩居然加成不如凡品的铁布衫"）：
#   病根：没单独写 item_stats 的武学**一律**按凡品兜底 5% ✗ —— 品质在加成行上完全看不见。
#   现在兜底按品质爬：凡 5 / 良 6 / 上 7 / 极 8 / 绝 10。
const ART_Q_DMG := [5, 6, 7, 8, 10]

static func item_stats(id: String) -> Dictionary:
	var s := by_id(id)
	if s.is_empty():
		# ㊺：查无此 id —— 什么都不加。
		#   以前这里兜底返回 {"atk": 4}，等于把拼错的兵器名静默当成一把 +4 攻的凡品剑，
		#   面板上只表现为"攻击少了 4"，看不出来是名字写错了。
		return {}
	if s.has("item_stats"):
		return s["item_stats"]
	if is_arts(id):
		# v63：兜底按**品质**给加成（凡5/良6/上7/极8/绝10）——品质在加成行上看得见
		return {"dmg": int(ART_Q_DMG[clampi(q_idx(id), 0, ART_Q_DMG.size() - 1)])}
	return {"atk": FANPIN_WEAPON_ATK}

static func item_bonus(id: String) -> Dictionary:
	return item_stats(id)

static func bonus_text(b: Dictionary) -> String:
	var out: Array = []
	for k in STAT_ORDER:
		var v := int(b.get(k, 0))
		if v == 0:
			continue
		var s := str(STAT_CN.get(k, k)) + " +" + str(v)
		if STAT_PCT.has(k):
			s += "%"
		out.append(s)
	return "、".join(PackedStringArray(out))

static func pool_sets(pool: String, max_q := 4) -> Array:
	var out: Array = []
	for s in SETS:
		if str(s["pool"]) != pool:
			continue
		if q_idx(str(s["id"])) > max_q:
			continue
		# ㊿z5：专武（no_drop）永不进任何掉落池——只走它自己的来路
		if bool(s.get("no_drop", false)):
			continue
		out.append(str(s["id"]))
	return out

static func random_offer(pool: String, count: int, max_q := 4) -> Array:
	var sets: Array = pool_sets(pool, max_q)
	sets.shuffle()
	var out: Array = []
	for i in mini(count, sets.size()):
		var sid := str(sets[i])
		var parts: Array = parts_of(sid)
		out.append({"set_id": sid, "part": randi() % maxi(1, parts.size())})
	return out

# ---- R4 卡池阶梯（难度换届）----
const LADDER_SLOTS := {"weapon": 5, "arts": 4}
const LADDER_CHAIN := {
	"weapon": ["sword", "dual", "dagger", "spear", "staff", "sword_qiu", "spear_han", "dual_liu", "dagger_qing", "staff_tie", "sword_shuang", "dual_yue", "dagger_chan", "spear_long", "staff_pan", "sword_chang", "dual_fen", "dagger_jing", "spear_guan", "staff_fu", "sword_cheng", "dual_hai", "dagger_yu", "spear_dan", "staff_qing"],
	# ㊿：链是按**品级排序**的滚动窗口（每 2 次首通滑一格，窗口 4 格）。
	#   **不在链上的东西抽不到**（事件/货郎/补齐/搜刮普通池全走这一条）——
	#   所以每一门能掉的功法都得在这条链上有一格。
	#
	# v132（用户："功法要做归类了 …每种都要有"）：**整条链按归类重排了一遍**——
	#   ① 先把 v37/v48/v52/v53 那几批**漏挂上链**的功法补进来（破阵 3 · 多段 2 · 负面 10 ·
	#      清心诀 1：共 16 门，这一批以前只从"越阶红/首领赏"出得来）；
	#   ② 再把 v132 新补的 12 门按品级插进去；
	#   ③ 每一档内部按**归类**排（攻击 → 增益 → 控制 → 被动 → 元素），
	#      这样同一档里先见到的总是"打人"的，再是"帮自己"的，最后是"上状态"的。
	#   ⚠ 代价说清楚：链从 27 格变成 **57 格**，窗口每 2 次首通滑一格——
	#     上品档（第 29 格起）从"第 30 次首通"推到"第 58 次首通"。
	#     嫌慢就动 `ladder_swaps()` 里 arts 那一行（c / 2 → c 就是每首通滑一格）。
	"arts": [
		# ---- 凡品（4）——入门那一窗，照旧排最前 ----
		"art_wind", "art_iron", "art_stone", "art_breath",
		# ---- 良品（25）：单段/多段/站位/群体 → 单体·群体增益 → 控制·群控 → 被动 ----
		"art_palm", "art_fist", "art_chain3", "art_twindag", "art_shadow", "art_cloud", "art_breakline", "art_snipe", "art_sweep", "art_cleave",
		"art_aegis", "art_sharporder", "art_rageorder", "art_ironring", "art_bell", "art_oneheart", "art_springorder", "art_galeorder", "art_clearheart",
		"art_flameblade", "art_softsinew", "art_throatpin", "art_dullrage", "art_mazedust",
		"art_calm",
		# ---- 上品（17）：先攻击与增益/控制，再五类元素（元素一律上品起）----
		"art_swallow", "art_spring",
		"art_disarmhand", "art_soulchime", "art_ultbreak", "art_slowcast", "art_thunderroar", "art_galeheart",
		"art_metalpoint", "art_firepalm", "art_icedart", "art_burnpalm", "art_coldriver", "art_windarrow", "art_ruffle", "art_river", "art_thunder",
		# ---- 极品（7）----
		"art_bulwark", "art_bloom", "art_stonebreak", "art_silkleg", "art_snow", "art_pearrain", "art_ocean",
		# ---- 绝品（4）——专武（no_drop）永不进链 ----
		"art_tortoise", "art_mend", "art_glimmer", "art_void"],
}

static func ladder_start(pool: String, swaps: int) -> int:
	var chain: Array = LADDER_CHAIN.get(pool, [])
	if chain.is_empty():
		return 0
	var k: int = clampi(int(LADDER_SLOTS.get(pool, 4)), 1, chain.size())
	return clampi(swaps, 0, maxi(0, chain.size() - k))

static func ladder_sets(pool: String, swaps: int) -> Array:
	if not LADDER_CHAIN.has(pool):
		return pool_sets(pool)   # 没上阶梯的池：全开（护甲/头饰/披风）
	var chain: Array = LADDER_CHAIN[pool]
	var k: int = clampi(int(LADDER_SLOTS.get(pool, 4)), 1, maxi(chain.size(), 1))
	var start := ladder_start(pool, swaps)
	var out: Array = []
	for i in range(start, mini(start + k, chain.size())):
		out.append(str(chain[i]))
	return out

static func ladder_red_sets(pool: String, lo_q: int, hi_q: int) -> Array:
	var out: Array = []
	for s in SETS:
		if str(s["pool"]) != pool:
			continue
		# ㊿z5：专武不进越阶红池（"无法从游历爬塔带出"就靠这一句兜住）
		if bool(s.get("no_drop", false)):
			continue
		var q := q_idx(str(s["id"]))
		if q >= lo_q and q <= hi_q:
			out.append(str(s["id"]))
	return out

static func random_offer_from(ids: Array, count: int) -> Array:
	var pool: Array = ids.duplicate()
	pool.shuffle()
	var out: Array = []
	for i in mini(count, pool.size()):
		var sid := str(pool[i])
		var parts: Array = parts_of(sid)
		out.append({"set_id": sid, "part": randi() % maxi(1, parts.size())})
	return out
