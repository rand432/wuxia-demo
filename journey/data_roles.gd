extends RefCounted
# ============================================================
# data_roles.gd —— 角色表 + 自带天赋【自带】（v4）
# v4 变动（㉖ 接线批）：补上陈石／苏青鸾两条自带——
#   原先 ROLES 只有 player 一条，而出征屏能选三个人（disciple_ids 返回
#   player / chen_shi / qingluan）。选弟子时 innate_of() 查不到 → 返回 {}，
#   于是 duel_battle 的残血增伤、结算页的"自带："、角色面板的【自带】栏
#   全都静默失效。这里把三条补齐，名字/说明仍以 shared/data_talents.gd
#   的 innate 记录为唯一真源，本表只多带一个"怎么算"（kind + 数值）。
#   已接线的 kind：
#     low_hp_dmg      自己气血不足一半时，出手伤害 ×mult
#     innate_hp_pct   气血上限 ×(1 + hp_pct)（常驻，不看血量）
#     thorn_up        反刺/反伤效果 ×(1 + v)（要看手里是不是枪——见 weapon_gate）
#     foe_low_hp_dmg  对手气血不足一半时，出手伤害 ×mult（㊳ 新增，给苏青鸾的「洞察」）
#   另有 row_priority：写在自带上时，满足 weapon_gate 就把普攻目标优先指向那一排
#     （"back" = 后排）。这是"站位反制"的又一条路：别人被前排挡着，她能绕过前排打后排。
# 数值全是初稿——要调只改这一份。
# ============================================================

const Talents := preload("res://shared/data_talents.gd")

const ROLES := [
	{
		"id": "player",
		# v81（用户："开头剧情改一改"）：名字与来历都跟正典对齐——
		#   《气质设定》里他不是"下山游历的少年"，是**坠崖没死的赘婿**，
		#   而"江湖新客"正是你定的面板称谓（原话见 docs/气质设定.md）。
		"name": "江湖新客",
		"innate": "red_heart",
		"note": "崖底爬出来的人，身世不详。",
	},
	{
		"id": "chen_shi",
		"name": "陈石",
		"innate": "shouzhuo",
		"note": "背着一杆断枪来的山里人。",
	},
	{
		"id": "qingluan",
		"name": "苏青鸾",
		"innate": "dongcha",
		"note": "走了三州的游侠女。",
	},
]

const INNATE := {
	"red_heart": {
		"id": "red_heart",
		"name": "赤子之心",
		"kind": "low_hp_dmg",
		"mult": 1.25,
		"desc": "气血不足一半时，出手伤害 +25%",
	},
	# ㊿：断枪——**现在没人用**（陈石的自带换成了下面的守拙）。记录留着：
	#   引擎的 thorn_up 自带照旧支持，将来想给谁用直接挂上去就行。
	"duanqiang": {
		"id": "duanqiang",
		"name": "断枪",
		"kind": "thorn_up",
		"v": 0.10,
		"weapon_gate": "spear",     # 只有在用枪时才生效
		"desc": "手里是枪时，反刺/反伤效果 +10%",
	},
	"dongcha": {
		"id": "dongcha",
		"name": "洞察",
		"kind": "foe_low_hp_dmg",
		"mult": 1.25,
		"weapon_gate": "dagger",    # 优先打后排这条只在用匕首时给
		"row_priority": "back",
		"desc": "持匕首时普攻绕开前排、直取后排；对手气血不足一半时，出手伤害 +25%",
	},
	# ㊿：陈石的自带＝守拙（气血上限）。他原来挂的是断枪（用枪时反刺 ×1.1）——
	#   他是前排站桩那个，给气血上限更贴；换自带**不影响他使枪**，
	#   兵器、"回马断枪"的枪势反刺、铁蒺卡都跟他自带无关。
	"shouzhuo": {
		"id": "shouzhuo",
		"name": "守拙",
		"kind": "innate_hp_pct",
		# v61（用户："陈石守拙降低至15 移除被动增幅的气血成长"）：
		#   ① hp_pct 0.20 → **0.15**（气血上限 +20% → +15%）
		#   ② **删掉 hp_grow**（原来那一条"每级多涨 2 点气血"）——自带的成长加成整条取消；
		#      星的「稳桩」那份 hp_grow 也一并删了（见 data_stars.gd），
		#      于是 GameState.hp_grow_bonus() 恒为 0：每级成长只看"基础 + 根骨档"。
		"hp_pct": 0.15,
		"desc": "气血上限 +15%",
	},
	# 旧 id 留着当别名，免得老存档里的 "yongjue" 查不到（它原来和「赤子之心」同效）
	"yongjue": {
		"id": "yongjue",
		"name": "勇决",
		"kind": "low_hp_dmg",
		"mult": 1.25,
		"desc": "气血不足一半时，出手伤害 +25%",
	},
	"shenfa": {
		"id": "shenfa",
		"name": "身法",
		"kind": "innate_hp_pct",
		"hp_pct": 0.0,
		"desc": "身法更轻（暂未接线）",
	},
}

# 自带是否"此刻生效"——有 weapon_gate 的要手里正好是那把兵器
static func innate_active(inn: Dictionary, weapon_kind: String) -> bool:
	if inn.is_empty():
		return false
	var gate := str(inn.get("weapon_gate", ""))
	if gate == "":
		return true
	return weapon_kind == gate

static func role(role_id: String) -> Dictionary:
	for r in ROLES:
		var d: Dictionary = r
		if str(d.get("id", "")) == role_id:
			return d
	return {}

static func role_name(role_id: String) -> String:
	var r: Dictionary = role(role_id)
	if r.is_empty():
		return role_id
	return str(r.get("name", role_id))

static func innate_of(role_id: String) -> Dictionary:
	var r: Dictionary = role(role_id)
	if r.is_empty():
		return {}
	return innate(str(r.get("innate", "")))

static func innate(iid: String) -> Dictionary:
	if iid == "":
		return {}
	if not INNATE.has(iid):
		return {}
	var d: Dictionary = INNATE[iid]
	return d

# 显示名／说明：名字与文案回 data_talents 那份（唯一真源），查不到才用本表的兜底文案
static func innate_name(iid: String) -> String:
	var t: Dictionary = Talents.by_key(iid)
	if not t.is_empty():
		return str(t.get("name", iid))
	return str(innate(iid).get("name", iid))

static func innate_desc(iid: String) -> String:
	var d: Dictionary = innate(iid)
	if d.is_empty():
		return ""
	var t: Dictionary = Talents.by_key(iid)
	# data_talents 里那几条自带的说明还写着"占位：…（接入后生效）"，接线后以本表数值为准
	if not t.is_empty() and not str(t.get("desc", "")).contains("占位"):
		return str(t.get("desc", ""))
	return str(d.get("desc", ""))
