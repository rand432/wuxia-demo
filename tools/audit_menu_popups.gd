extends SceneTree
const Curio := preload("res://menu/curio_home.tscn")
const Partner := preload("res://menu/partner_home.tscn")
const GS := preload("res://shared/game_state.gd")
const LS := preload("res://shared/level_state.gd")
const AD := preload("res://kushou/ancestor_data.gd")
const Audio := preload("res://shared/audio.gd")

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").ends_with("wuxia-regression"):
		quit(2)
		return
	call_deferred("_run")

func _button(parent, prefix: String) -> Button:
	for b in parent.find_children("*", "Button", true, false):
		if b.text.begins_with(prefix): return b
	assert(false, "missing button " + prefix)
	return null

func _picture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)

func _run() -> void:
	GS.ensure_loaded()
	GS._curio_ensure()
	GS.curio_lv = {}
	var curio = Curio.instantiate()
	root.add_child(curio)
	var id: String = curio._ids[curio._sel]
	curio._open_pop()
	var old = curio._pop
	var old_up := _button(old, "强 化")
	var old_close := _button(old, "×")
	old_close.pressed.emit()
	curio._open_pop()
	var current = curio._pop
	old_up.pressed.emit()
	old_close.pressed.emit()
	assert(curio._pop == current and GS.curio_level(id) == 1)
	var up := _button(current, "强 化")
	up.pressed.emit()
	up.pressed.emit()
	assert(GS.curio_level(id) == 2 and curio._pop == null)
	var cfg := ConfigFile.new()
	assert(cfg.load("user://curio.cfg") == OK and cfg.get_value("curio", "lv")[id] == 2)
	curio._sel = 1
	var other_id: String = curio._ids[1]
	curio._open_pop()
	current = curio._pop
	old_up.pressed.emit()
	old_close.pressed.emit()
	assert(curio._pop == current and GS.curio_level(other_id) == 1)
	await _picture("res://curio_popup.png")
	up = _button(current, "强 化")
	curio.queue_free()
	up.pressed.emit()
	assert(GS.curio_level(other_id) == 1)
	await process_frame
	LS.ensure_loaded()
	LS.current_level = 6
	GS.coins["wen"] = 5000
	GS.skill_books = {"凡品": 5, "良品": 5, "玄品": 5, "地品": 5, "天品": 5}
	GS.skill_lv = {}
	GS.stars = {}
	GS.shards = {}
	var partner = Partner.instantiate()
	root.add_child(partner)
	var first_id: String = partner._ids[0]
	var second_id: String = partner._ids[1]
	partner._show_skill_detail(0)
	old = partner._pop
	old_up = _button(old, "升级")
	old_close = _button(old, "×")
	partner._show_skill_detail(1)
	current = partner._pop
	old_up.pressed.emit()
	old_close.pressed.emit()
	assert(partner._pop == current and GS.coin("wen") == 5000 and GS.skill_lv.is_empty())
	up = _button(current, "升级")
	up.pressed.emit()
	var refreshed = partner._pop
	up.pressed.emit()
	_button(current, "×").pressed.emit()
	var qn: String = ["", "凡品", "良品", "玄品", "地品", "天品"][int(AD.ANCESTORS[second_id]["quality"])]
	assert(partner._pop == refreshed and GS.coin("wen") == 4800 and GS.skill_lv[second_id] == 1 and GS.skill_books[qn] == 4)
	assert(not GS.skill_lv.has(first_id))
	partner._sel = 0
	GS.shards[first_id] = 300
	partner._show_advance()
	old = partner._pop
	old_up = _button(old, "进阶")
	old_close = _button(old, "×")
	old_up.pressed.emit()
	current = partner._pop
	old_up.pressed.emit()
	old_close.pressed.emit()
	assert(partner._pop == current and GS.stars[first_id] == 1 and GS.shards[first_id] == 240 and GS.coin("wen") == 4300)
	await _picture("res://partner_advance_popup.png")
	up = _button(current, "进阶")
	_button(current, "×").pressed.emit()
	up.pressed.emit()
	assert(partner._pop == null and GS.stars[first_id] == 1 and GS.coin("wen") == 4300)
	assert(cfg.load("user://progress.cfg") == OK)
	assert(cfg.get_value("progress", "stars")[first_id] == 1 and cfg.get_value("progress", "skill_lv")[second_id] == 1)
	partner.queue_free()
	await process_frame
	print("PASS: curio/skill/star popup ownership; stale close never closes replacement; double/closed/queued-page actions never upgrade or charge; real upgrades and isolated save readback")
	Audio.quit_cleanly()
