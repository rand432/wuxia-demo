extends RefCounted
# ============================================================
# tuning.gd —— 可调参数读取器（㉘ 数值外置批）
#
# 为什么要有这个文件：
#   战斗倍率、词缀概率、命数系数这些"平衡旋钮"原先散在代码各处，改一个数
#   就得重新导出 33 MB 的 APK 发给朋友。现在它们可以放进一份配置文件里，
#   改完只要把文件推给手机，不用重打包。
#
# 读哪几个地方（先找到的先用）：
#   ① user://tuning.cfg  —— 手机上的那份，用 adb 推进去就能覆盖（优先）
#   ② res://tuning.cfg   —— 项目里随包发出去的默认值（不存在就跳过）
#   ③ 找不到 / 键缺失 / 类型不对 → 用调用方传进来的 fallback
#      ＝ 代码里原来那个常数，所以"配置丢了"最坏也就是回到现在的行为。
#
# 用法（新写的代码照这个来）：
#   const Tuning := preload("res://shared/tuning.gd")
#   var mul := Tuning.num("combat", "dmg_mul", DMG_MUL)
#   var flag := Tuning.flag("combat", "enemy_flip", ENEMY_FLIP)
#
# 生成一份带注释的样例配置（把它推给手机就是覆盖）：
#   GameState.tuning_write_example()   —— 控制台会打印存到哪个路径
#
# 注意：这是"改数字"的通道，不是"改结构"的。键名写错了不会报错，
#   只会静默用回代码里的默认值——所以改完要看控制台那行 [调参]
#   确认到底读到了几个键。
# ============================================================

const PATH_USER := "user://tuning.cfg"
const PATH_RES := "res://tuning.cfg"

static var _cfg: ConfigFile = null
static var _loaded := false
static var _loaded_from := ""
static var _hits := 0     # 实际读到过几个键（写样例时报告用）

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var a := ConfigFile.new()
	if a.load(PATH_USER) == OK:
		_cfg = a
		_loaded_from = PATH_USER
		_warn_if_odd()
		return
	var b := ConfigFile.new()
	if b.load(PATH_RES) == OK:
		_cfg = b
		_loaded_from = PATH_RES
		_warn_if_odd()

# 防呆：这份配置本该是 [combat] / [journey] / [affix] 三段。
# 若你（或编辑器）把它存成了别的形状，键名就对不上、会静默全用默认值——
# 那种"改了没反应"最费时间，所以这里直接点破。
static func _warn_if_odd() -> void:
	if _cfg == null:
		return
	var known := ["combat", "journey", "affix"]
	var found := 0
	for s in known:
		if _cfg.has_section(s):
			found += 1
	if found == 0:
		print("[调参] 警告：", _loaded_from, " 里没找到 [combat]/[journey]/[affix] 任何一段——")
		print("[调参]       这文件形状不对，本次全部用代码默认值。正确形状见 GameState.tuning_write_example()")

# 读一个数（int / float 都收；字符串能转也收）。读不到＝用 dv。
static func num(section: String, key: String, dv: float) -> float:
	_ensure()
	if _cfg == null:
		return dv
	if not _cfg.has_section_key(section, key):
		return dv
	var v: Variant = _cfg.get_value(section, key, null)
	var out := dv
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			out = float(v)
		TYPE_STRING:
			if str(v).is_valid_float():
				out = str(v).to_float()
		_:
			return dv   # 类型不对就当没写——不猜
	_hits += 1
	return out

# 读一个整数（内部按 float 读再四舍五入）
static func intv(section: String, key: String, dv: int) -> int:
	_ensure()
	if _cfg == null:
		return dv
	if not _cfg.has_section_key(section, key):
		return dv
	var v: Variant = _cfg.get_value(section, key, null)
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			_hits += 1
			return int(round(float(v)))
		TYPE_STRING:
			if str(v).is_valid_float():
				_hits += 1
				return int(round(str(v).to_float()))
	return dv

# 读一个开关
static func flag(section: String, key: String, dv: bool) -> bool:
	_ensure()
	if _cfg == null:
		return dv
	if not _cfg.has_section_key(section, key):
		return dv
	var v: Variant = _cfg.get_value(section, key, null)
	if typeof(v) == TYPE_BOOL:
		_hits += 1
		return bool(v)
	if typeof(v) == TYPE_INT:
		_hits += 1
		return int(v) != 0
	return dv

# 读一个字符串
static func text(section: String, key: String, dv: String) -> String:
	_ensure()
	if _cfg == null:
		return dv
	if not _cfg.has_section_key(section, key):
		return dv
	var v: Variant = _cfg.get_value(section, key, null)
	if typeof(v) == TYPE_STRING:
		_hits += 1
		return str(v)
	return dv

static func source() -> String:
	_ensure()
	if _cfg == null:
		return "（没有配置文件——全部用代码里的默认值）"
	return _loaded_from

static func describe() -> void:
	_ensure()
	print("[调参] 配置文件=", source(), "；本次已读到的键数=", _hits)
