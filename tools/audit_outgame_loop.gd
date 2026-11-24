extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")
const FD := preload("res://shared/forge_data.gd")


var _save_backup := {}
const SAVE_FILES := ["user://progress.cfg", "user://level_state.cfg", "user://curio.cfg", "user://forge.cfg", "user://reward_pending.cfg"]

func _snapshot_saves() -> void:
	for f in SAVE_FILES:
		if FileAccess.file_exists(f):
			_save_backup[f] = FileAccess.get_file_as_bytes(f)

func _restore_saves() -> void:
	for f in SAVE_FILES:
		if _save_backup.has(f):
			var fp := FileAccess.open(f, FileAccess.WRITE)
			if fp != null:
				fp.store_buffer(_save_backup[f])
				fp.close()
		elif FileAccess.file_exists(f):
			# 用例跑之前没有这个档：删掉，别把新档留给下一个用例
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

func _initialize() -> void:
	_snapshot_saves()
	call_deferred("_run")

func _fail(msg: String) -> void:
	_restore_saves()
	push_error("AUDIT FAIL: " + msg)
	quit(1)

func _run() -> void:
	GS.ensure_loaded()
	LS.ensure_loaded()
	LS.current_level = 3
	LS.max_unlocked = 10
	# 1) 局外文钱能花：技能升级
	GS.coins["wen"] = 1000
	GS.skill_books["凡品"] = 1
	var ok1: bool = GS.upgrade_skill("zhujue", "凡品", 200)
	print("[1] upgrade=", ok1, " wen=", GS.coin("wen"), " lv=", int(GS.skill_lv.get("zhujue", 0)), " book=", int(GS.skill_books.get("凡品", 0)))
	if not ok1 or GS.coin("wen") != 800 or int(GS.skill_lv.get("zhujue", 0)) != 1:
		_fail("skill upgrade did not spend/apply")
		return
	# 2) 角色进阶
	GS.shards["zhujue"] = 120
	var ok2: bool = GS.advance_role("zhujue", 0)
	print("[2] advance=", ok2, " wen=", GS.coin("wen"), " stars=", int(GS.stars.get("zhujue", 0)), " shards=", int(GS.shards.get("zhujue", 0)))
	if not ok2 or GS.coin("wen") != 300 or int(GS.stars.get("zhujue", 0)) != 1:
		_fail("role advance did not spend/apply")
		return
	# 3) 进阶后家传档位解锁
	if not GS.family_tier_allowed("zhujue", 1):
		_fail("star 1 did not unlock family tier 1")
		return
	# 4) 进入战斗后技能等级加成生效
	assert(change_scene_to_packed(Battle) == OK)
	await scene_changed
	var b = current_scene
	b.set_process(false)
	b._core.set_process(false)
	var bonus: float = b._skill_level_bonus("zhujue")
	print("[3] battle skill bonus=", bonus)
	if bonus <= 0.0:
		_fail("skill level bonus not applied in battle")
		return
	print("PASS: out-of-battle loop (spend -> apply -> battle bonus)")
	_restore_saves()
	quit(0)
