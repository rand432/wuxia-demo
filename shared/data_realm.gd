extends RefCounted
# ============================================================
# data_realm.gd —— **进阶（境界）** 唯一真源
# 用户 2026-10-08："去掉原先角色的境界标识 做一个新功能进阶【无关等级 根据关卡来突破境界】
#   境界提升所有角色的整体属性 还有境界压制【怪也可以有境界压制】具体境界在主界面角色头像名字
#   那里显示 突破境界需要很多材料【增加新材料 有成功率】可以从九品开始 暂定为18个境界"
#
# 口径：
#   · **与等级无关**——门槛看**爬塔关卡**（stage_need），关卡到了、材料够了才能冲；
#   · 境界是**全队**的：stat_pct 给所有角色加整体属性（在 GameState.effective_stats 里乘）；
#   · **境界压制**：出手时按 (我方境界 − 对方境界) 加/减伤（见 duel_battle），怪也有境界；
#   · 突破要**很多材料**（境界石 / 道心砂是这一版新加的），并且**有成功率**，失败材料全损。
# ============================================================

# 18 境：九品 → 一品 → 上/极/绝品 → 化/玄/地/天/圣/神
#   stage_need ＝ 爬塔关卡门槛 · stone/dao/jin ＝ 三样材料 · rate ＝ 成功率 · pct ＝ 全体属性加成（累加）
const LIST := [
	{"name": "九品", "stage_need": 0,    "stone": 0,    "dao": 0,    "jin": 0,  "rate": 1.00, "pct": 0.00},
	{"name": "八品", "stage_need": 30,   "stone": 8,    "dao": 0,    "jin": 0,  "rate": 1.00, "pct": 0.06},
	{"name": "七品", "stage_need": 80,   "stone": 18,   "dao": 2,    "jin": 0,  "rate": 0.95, "pct": 0.12},
	{"name": "六品", "stage_need": 150,  "stone": 34,   "dao": 6,    "jin": 0,  "rate": 0.90, "pct": 0.18},
	{"name": "五品", "stage_need": 250,  "stone": 56,   "dao": 14,   "jin": 0,  "rate": 0.85, "pct": 0.24},
	{"name": "四品", "stage_need": 380,  "stone": 88,   "dao": 26,   "jin": 1,  "rate": 0.80, "pct": 0.30},
	{"name": "三品", "stage_need": 550,  "stone": 130,  "dao": 44,   "jin": 2,  "rate": 0.75, "pct": 0.36},
	{"name": "二品", "stage_need": 760,  "stone": 185,  "dao": 70,   "jin": 4,  "rate": 0.70, "pct": 0.42},
	{"name": "一品", "stage_need": 1000, "stone": 255,  "dao": 105,  "jin": 6,  "rate": 0.65, "pct": 0.48},
	{"name": "上品", "stage_need": 1300, "stone": 340,  "dao": 150,  "jin": 9,  "rate": 0.62, "pct": 0.54},
	{"name": "极品", "stage_need": 1650, "stone": 445,  "dao": 210,  "jin": 13, "rate": 0.60, "pct": 0.60},
	{"name": "绝品", "stage_need": 2050, "stone": 575,  "dao": 285,  "jin": 18, "rate": 0.58, "pct": 0.66},
	{"name": "化境", "stage_need": 2500, "stone": 730,  "dao": 380,  "jin": 24, "rate": 0.55, "pct": 0.72},
	{"name": "玄境", "stage_need": 3000, "stone": 915,  "dao": 500,  "jin": 32, "rate": 0.52, "pct": 0.78},
	{"name": "地境", "stage_need": 3600, "stone": 1130, "dao": 650,  "jin": 42, "rate": 0.50, "pct": 0.84},
	{"name": "天境", "stage_need": 4300, "stone": 1380, "dao": 840,  "jin": 55, "rate": 0.48, "pct": 0.90},
	{"name": "圣境", "stage_need": 5100, "stone": 1670, "dao": 1080, "jin": 70, "rate": 0.45, "pct": 0.96},
	{"name": "神境", "stage_need": 6000, "stone": 2010, "dao": 1380, "jin": 90, "rate": 0.40, "pct": 1.02},
]
const MAX_LV := 17            # 下标上限（18 境：0 = 九品）

static func at(lv: int) -> Dictionary:
	return LIST[clampi(lv, 0, MAX_LV)]

static func name_of(lv: int) -> String:
	return str(at(lv).get("name", "?"))

static func pct_of(lv: int) -> float:
	return float(at(lv).get("pct", 0.0))

# v124（用户："境界压制10%每一层境界 无上限"）→ v126（用户："算了还是加一个80%限制"）：
#   **每差一境 ±10%**，但结果**夹在 ±80%**（×0.2 ~ ×1.8）——恩威都不出格。
const SUPPRESS_PER := 0.10
const SUPPRESS_CAP := 0.80

static func suppress_mul(mine: int, theirs: int) -> float:
	var d := int(mine) - int(theirs)
	return clampf(1.0 + float(d) * SUPPRESS_PER, 1.0 - SUPPRESS_CAP, 1.0 + SUPPRESS_CAP)