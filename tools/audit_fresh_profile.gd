extends SceneTree
# 新号冒烟：没有任何存档时，四个局外页面能打开、第一关能进、开局状态正确。
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")

const FILES := ["user://progress.cfg", "user://level_state.cfg", "user://curio.cfg", "user://forge.cfg", "user://reward_pending.cfg", "user://opening.cfg"]
var _backup := {}

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _restore() -> void:
	for f in FILES:
		if _backup.has(f):
			var fp := FileAccess.open(f, FileAccess.WRITE)
			if fp != null:
				fp.store_buffer(_backup[f])
				fp.close()
		elif FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

func _fail(msg: String) -> void:
	_restore()
	push_error("AUDIT FAIL: " + msg)
	quit(1)

func _run() -> void:
	for f in FILES:
		if FileAccess.file_exists(f):
			_backup[f] = FileAccess.get_file_as_bytes(f)
	for f in FILES:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	# 四个局外页面都要能开
	for n in ["main_home", "character_home", "curio_home", "partner_home"]:
		var path := "res://menu/" + str(n) + ".tscn"
		if change_scene_to_file(path) != OK:
			_fail("cannot load " + path)
			return
		await scene_changed
		for i in 4:
			await process_frame
		if current_scene == null or current_scene.scene_file_path != path:
			_fail("scene not settled: " + path)
			return
	# 新档第一关
	LS.ensure_loaded()
	if LS.max_unlocked != 1 or LS.current_level != 1:
		_fail("fresh state wrong: unlocked=%d level=%d" % [LS.max_unlocked, LS.current_level])
		return
	if change_scene_to_packed(Battle) != OK:
		_fail("cannot load battle")
		return
	await scene_changed
	var b = current_scene
	for i in 4:
		await process_frame
	if b == null or b._core == null:
		_fail("battle not ready")
		return
	_restore()
	print("PASS: fresh profile opens 4 pages and level 1")
	quit(0)
