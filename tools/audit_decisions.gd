extends SceneTree
const Iso := preload("res://tools/test_isolation.gd")
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

var b = null
var fails: Array[String] = []

func _initialize() -> void:
	var e := Iso.verify()
	if e != "":
		print("[DEC] REJECT " + e); quit(2); return
	seed(20261116)
	LS.ensure_loaded(); LS.current_level = 6; LS.max_unlocked = 10
	GS.ensure_loaded()
	b = BATTLE.instantiate(); root.add_child(b)

func _process(_dt: float) -> bool:
	if b == null or b._core == null or not b.is_inside_tree():
		return true
	if b._tut != null:
		b._tut.cancel(); b._tut.queue_free(); b.set("_tut", null); b._tutorial_pause(false)
	var core = b._core
	core.intro_wait = 0.0
	# 宝物里程碑
	var c0: int = b._trea_charge
	b._grant_treasure_milestones(4)
	_check("20% 波给第 1 次宝物", b._trea_charge == c0 + 1)
	b._grant_treasure_milestones(10)
	_check("50% 波给第 2 次宝物", b._trea_charge == c0 + 2)
	b._grant_treasure_milestones(16)
	_check("78% 波给第 3 次宝物", b._trea_charge == c0 + 3)
	var before_clear: int = b._trea_charge
	b._on_wave_clear(7)
	_check("清波不再送宝物", b._trea_charge == before_clear)
	# 奇遇低频
	_check("奇遇基础间隔 300s", is_equal_approx(b._q_interval(), 300.0))
	# 暂停一致性
	b._crystal = 999
	var clock0: float = b._wave_clock
	var q0: float = b._q_t
	b._show_draw(true)
	b._process(0.6)
	_check("开抽卡暂停核心", not core.is_processing())
	_check("开抽卡暂停调度钟", is_equal_approx(b._wave_clock, clock0))
	_check("开抽卡暂停奇遇钟", is_equal_approx(b._q_t, q0))
	b._show_draw(false)
	b._process(0.2)
	_check("关抽卡恢复核心", core.is_processing())
	# 强化批升
	b._wen = 10000
	b._str_lv = 0
	b._on_str_tile()
	_check("首次单级强化", b._str_lv == 1)
	var wen0: int = b._wen
	var expect: int = int(b._str_batch_cost())
	b._open_str_menu()
	_check("强化菜单打开", b._str_menu != null and b._str_menu.visible)
	b._str_batch_upgrade()
	_check("批升到下一节点", b._str_lv == 10)
	_check("批升扣总价", b._wen == wen0 - expect)
	_check("批升后进入待选", b._str_pending)
	for s in fails: print("[DEC] FAIL " + s)
	print("PASS: treasure milestones, encounter interval, panel pause and batch strengthen" if fails.is_empty() else ("FAIL: " + str(fails)))
	quit(0 if fails.is_empty() else 1)
	return false

func _check(name: String, ok: bool) -> void:
	print(("[DEC] PASS " if ok else "[DEC] FAIL ") + name)
	if not ok: fails.append(name)
