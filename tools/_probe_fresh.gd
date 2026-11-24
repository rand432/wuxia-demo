extends SceneTree
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")

const FILES := ["user://progress.cfg", "user://level_state.cfg", "user://curio.cfg", "user://forge.cfg", "user://reward_pending.cfg", "user://opening.cfg"]
var backup := {}

func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	for i in 8:
		await process_frame
	await create_timer(0.45).timeout
	var img: Image = get_root().get_texture().get_image()
	img.save_png("D:/1/wuxia-demo/.shots/fresh_" + name + ".png")
	print("[SHOT] ", name)

func _run() -> void:
	for f in FILES:
		if FileAccess.file_exists(f):
			backup[f] = FileAccess.get_file_as_bytes(f)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	# 全新档：不调用 ensure_loaded，先直接进局外页面
	for n in ["main_home", "character_home", "curio_home", "partner_home"]:
		var err := change_scene_to_file("res://menu/" + n + ".tscn")
		if err != OK:
			print("[ERR] scene ", n, " ", err)
			continue
		await scene_changed
		await _shot(n)
	# 新档进第一关
	LS.ensure_loaded()
	assert(change_scene_to_packed(Battle) == OK)
	await scene_changed
	var b = current_scene
	b.set_process(false)
	b._core.set_process(false)
	print("[BATTLE] level=", LS.current_level, " max_unlocked=", LS.max_unlocked, " tut_visible=", b._tut != null and b._tut.visible)
	await _shot("battle_l1")
	# 还原
	for f in FILES:
		if backup.has(f):
			var fp := FileAccess.open(f, FileAccess.WRITE)
			if fp != null:
				fp.store_buffer(backup[f])
				fp.close()
		elif FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("[FRESH] done")
	quit(0)
