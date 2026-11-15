extends SceneTree
const Core := preload("res://kushou/kushou_battle.gd")
var kills := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var core := Core.new()
	root.add_child(core)
	core.start_run()
	core.intro_wait = 0.0
	core._spawn_foe()
	core._last_quota_wave = core.wave
	core._spawn_t = 1000.0
	var foe: Dictionary = core.foes[0]
	foe["para"] = 10.0
	core.kill.connect(func(n): kills += n)
	core._apply_dmg(foe, 100000.0, "真实")
	assert(float(foe["hp"]) <= 0.0)
	core._process(0.016)
	assert(kills == 1 and core.live_foes() == 0)
	core._process(0.016)
	assert(kills == 1)
	core._spawn_foe()
	var revive: Dictionary = core.foes[core.foes.size() - 1]
	revive["boss_revive"] = 1
	revive["hp_max"] = 100.0
	revive["hp"] = -1.0
	core._hero_cd = 1000.0
	core._process(0.016)
	assert(is_equal_approx(revive["hp"], 50.0) and kills == 1)
	revive["hp"] = -1.0
	core._process(0.016)
	assert(kills == 2 and core.live_foes() == 0)
	core.queue_free()
	await process_frame
	print("PASS: external damage death settled once; revive occurs once before final kill")
	quit()
