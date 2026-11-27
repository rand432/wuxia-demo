extends SceneTree
const Iso := preload("res://tools/test_isolation.gd")
const BATTLE := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
const GS := preload("res://shared/game_state.gd")
const Audio := preload("res://shared/audio.gd")

var b = null
var mode := "battle"
var mute_bgm := false
var t := 0.0
var phase := 0
var timer := 0.0
var boss_primed := false
var scene_node = null

func _initialize() -> void:
	var err := Iso.verify()
	if err != "":
		print("[MIX] ISOLATION_REJECT " + err)
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.get_slice("=", 1)
		if arg == "--mute-bgm=1": mute_bgm = true
	seed(20261116)
	LS.ensure_loaded()
	LS.current_level = 6
	LS.max_unlocked = 10
	GS.ensure_loaded()
	Audio.reset_sfx_stats()
	if mute_bgm:
		Audio.set_bgm_volume(0.0)
	if mode == "battle":
		b = BATTLE.instantiate()
		root.add_child(b)
	elif mode == "menu":
		change_scene_to_file("res://menu/main_home.tscn")
		_menu_flow()

func _process(dt: float) -> bool:
	t += dt
	if mode == "battle":
		if not b.is_inside_tree(): return true
		if t > 0.4 and b._tut != null:
			b._tut.cancel(); b._tut.queue_free(); b.set("_tut", null)
			b._tutorial_pause(false)
		if b._core != null and b._core.foes.size() < 30:
			b._core._spawn_foe("normal", 1.0, 1.0)
		elif b._core != null and not boss_primed and t > 3.0:
			boss_primed = true
			b._core._spawn_foe("boss", 1.0, 1.0, true, 18, "混音首领")
		if t >= 18.0:
			print("[MIX] battle " + JSON.stringify(Audio.sfx_stats()))
			quit(0)
		return false
	if mode == "forge":
		if t > 0.3 and scene_node == null:
			scene_node = load("res://menu/forge_sheet.tscn").instantiate()
			root.add_child(scene_node)
			scene_node.open("weapon")
		if t > 1.0 and timer == 0.0:
			timer = t
			for i in 3:
				var btn = _find_button_text(scene_node, "锤")
				if btn != null: _click(btn)
		if t >= 8.0:
			print("[MIX] forge " + JSON.stringify(Audio.sfx_stats()))
			quit(0)
		return false
	if t >= 6.0:
		print("[MIX] menu " + JSON.stringify(Audio.sfx_stats()))
		quit(0)
	return false

func _menu_flow() -> void:
	await _sleep(1.0)
	for label in ["角色", "关卡", "奇物"]:
		var btn = _find_button_text(root, label)
		if btn != null:
			_click(btn)
		await _sleep(0.8)

func _sleep(sec: float) -> void:
	await create_timer(sec).timeout

func _click(ctrl) -> void:
	if ctrl == null or not (ctrl is Control): return
	var p: Vector2 = ctrl.get_global_transform() * (ctrl.size * 0.5)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		ev.position = p; ev.global_position = p; ev.pressed = pressed
		root.push_input(ev, true)

func _find_button_text(node, text: String) -> Button:
	if node == null: return null
	if node is Button:
		var bt := node as Button
		if bt.is_visible_in_tree() and bt.text.find(text) >= 0: return bt
	for c in node.get_children():
		var f := _find_button_text(c, text)
		if f != null: return f
	return null
