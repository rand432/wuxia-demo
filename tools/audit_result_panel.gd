extends SceneTree
# 结算面板回归：底图必须锁在 540×480，六行文字与按钮不能越出面板。
# 2026-11-24 修过一次 TextureRect 被贴图原始尺寸（1024×768）顶爆的 bug。
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")


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
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
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
	assert(change_scene_to_packed(Battle) == OK)
	await scene_changed
	var b = current_scene
	b.set_process(false)
	b._core.set_process(false)
	b._wen = 1000
	b._kills = 42
	b._end_run(true)
	for i in 8:
		await process_frame
	var layer: Control = b._result_layer
	if layer == null:
		_fail("no result layer")
		return
	# holder：540×480 的 Control
	var holder: Control = null
	for c in layer.get_children():
		if c is Control:
			var cs := (c as Control).size
			if absf(cs.x - 540.0) < 1.0 and absf(cs.y - 480.0) < 1.0:
				holder = c
	if holder == null:
		_fail("holder 540x480 not found")
		return
	# 底图尺寸
	var bg_ok := false
	for tr in holder.find_children("*", "TextureRect", true, false):
		var t := tr as TextureRect
		if t.texture != null:
			if absf(t.size.x - 540.0) > 1.0 or absf(t.size.y - 480.0) > 1.0:
				_fail("panel art size %s, expected 540x480" % str(t.size))
				return
			bg_ok = true
	if not bg_ok:
		_fail("panel art not found")
		return
	# 所有 Label 必须落在 holder 内
	for l in holder.find_children("*", "Label", true, false):
		var lb := l as Label
		var right := lb.position.x + lb.size.x
		var bottom := lb.position.y + lb.size.y
		if lb.position.x < 0.0 or lb.position.y < 0.0 or right > 541.0 or bottom > 481.0:
			_fail("label out of panel: '%s' rect=%s,%s" % [lb.text, str(lb.position), str(lb.size)])
			return
	# 带回文案
	var carry_ok := false
	for l in holder.find_children("*", "Label", true, false):
		if str((l as Label).text).find("带回") >= 0:
			carry_ok = true
	if not carry_ok:
		_fail("carry text missing")
		return
	print("PASS: result panel layout + carry row")
	_restore_saves()
	quit(0)
