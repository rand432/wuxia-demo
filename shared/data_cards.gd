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
			"desc": "反手磕在腕上：×2.4，并「缴械」——对手此后 2 手**不能普攻**（武学与大招照放；冷却 4 手）"}, "item_stats": {"dmg": 4}},
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
			"desc": "指风锁喉：×1.3，并「沉默」——对手此后 2 手**放不出武学**（普攻与大招照放；冷却 4 手）"}},
	{"id": "art_dullrage", "name": "泄气散", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下"], "item": "泄气散", "quality": "良品",
		"art": {"kind": "damage", "mult": 1.1, "cd": 4, "move": "撒粉泄气", "target": "front",
			"apply": {"id": "ragecut", "turns": 3, "stacks": 1},
			"desc": "一蓬泄气药粉：×1.1，并「挫锐」——当场打掉对手 30 点怒气，此后 3 手怒气获取只剩四成（冷却 4 手）"}},
	{"id": "art_ultbreak", "name": "断势拳", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下"], "item": "断势拳", "quality": "上品", "elem": "fire",
		"art": {"kind": "damage", "mult": 2.2, "cd": 4, "move": "断势截招", "target": "front",
			"apply": {"id": "ultseal", "turns": 2, "stacks": 1},
			"desc": "一拳截在起势上：×2.2，并「封招」——对手此后 2 手**放不出大招**（怒气留着，满了也放不出来；冷却 4 手）"}, "item_stats": {"dmg": 4}},
	{"id": "art_slowcast", "name": "滞气针", "pool": "arts", "weapon": "any", "parts": ["卷首", "卷上", "卷中", "卷下", "卷尾"], "item": "滞气针", "quality": "上品",
		"art": {"kind": "damage", "mult": 1.6, "cd": 4, "move": "滞气凝脉", "target": "mid",
			"apply": {"id": "cdslow", "turns": 3, "stacks": 1},
			"desc": "细针入脉：×1.6，并「滞涩」——对手此后 3 手**技能冷却 +2 手**（当下正在冷却的一起往后推；冷却 4 手）"}, "item_stats": {"dmg": 4}},
	# ⚠ 「闭窍」不在这里——用户："闭窍是针对玩家的"：那一条只有**首领**会给你上
	#   （出村第 50 关往后的「点窍手」模板、游历的精英与寨主），玩家的解法是「清心诀」。
	# ---- 驱散（净化）：自己这手不出击，**随机**洗掉全队身上一条负面，顺手磕掉对手的护体与蓄势 ----
	{"id": "art_clearheart", "name": "清心诀", "pool": "arts", "weapon": "any", "parts": ["卷上", "卷中", "卷下", "卷尾"], "item": "清心诀", "quality": "良品",
		"art": {"kind": "cleanse", "target": "ally_all", "cleanse": 1, "dispel_foe": true, "cd": 4, "move": "清心涤虑",
			"desc": "涤荡杂气：自己这手不出击，全队各**随机洗掉身上一条负面**（挂三条时不一定洗得中你最想洗的那条），并磕掉当前对手的护体与蓄势（冷却 4 手）"}},
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
			"desc": "为少侠量身定做——常驻：出手伤害 +5%。\n专属机制：大招伤害 +10%；对多人时**每一名**中招的对手让那一击再 +6%（逐个叠）；\n放完大招后**三回合**内再放大招，那一下再 +20%（续得上就一路 +20%）。数值随星数提升"}},
	{"id": "art_ex_tiebi", "name": "铁壁桩功", "pool": "arts", "weapon": "any", "role": "chen_shi", "quality": "绝品", "no_drop": true,
		"parts": ["卷上", "卷中", "卷下", "卷尾"], "item": "铁壁桩功",
		"art": {"kind": "passive", "fx": {"rage_on_hit": 0.15, "thorn_up": 0.15}, "move": "铁桩入地",
			"mech": {"ult_cut": 0.075, "thorn_all": 1, "thorn_per_hit": 0.10, "thorn_heal": 0.03},
			"desc": "为陈石量身定做——常驻：受击怒气 +15%、反刺 +15%。\n专属机制：放大招期间减伤 +7.5%，且反刺**打全体**；\n自己每击中一名敌人，反刺再 +10%（封顶 +100%）；每次反刺回 3% 气血。数值随星数提升"}},
	{"id": "art_ex_duange", "name": "短歌行", "pool": "arts", "weapon": "any", "role": "qingluan", "quality": "绝品", "no_drop": true,
		"parts": ["卷上", "卷中", "卷下", "卷尾"], "item": "短歌行",
		"art": {"kind": "passive", "fx": {"crit": 5, "crit_dmg": 13}, "move": "短歌相和",
			"mech": {"follow_dmg": 0.35, "follow_crit_up": 0.20},
			"desc": "为苏青鸾量身定做（匕首）：暴击 +5%、暴击伤害 +13%——常驻。\n触发暴击时，追击伤害 +35%；追击自己暴击时，再 +20%。数值随星数提升"}},
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
	#   art_wind~art_breath＝凡品(0~3)，art_cleave~art_bell＝良品(4~7)，
	#   往下依次是上品/极品/绝品。新加的加持武学是良品，所以插在 art_bell 后面——
	#   **不在链上的东西抽不到**（事件/货郎/补齐/搜刮普通池全走这一条），
	#   代价只是后面的品级晚 2 次首通 × 3 格 ＝ 6 次首通露头。
	"arts": ["art_wind", "art_iron", "art_stone", "art_breath", "art_cleave", "art_shadow", "art_cloud", "art_bell",
		"art_aegis", "art_sharporder", "art_oneheart", "art_springorder", "art_galeorder", "art_rageorder", "art_ironring",
		"art_river", "art_thunder", "art_swallow", "art_spring", "art_ocean", "art_bulwark", "art_snow", "art_bloom", "art_void", "art_tortoise", "art_glimmer", "art_mend"],
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
