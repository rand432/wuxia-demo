extends SceneTree
const Core := preload("res://kushou/kushou_battle.gd")
var kills := 0
var coins := 0
var bosses := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var core := Core.new()
	root.add_child(core)
	core._spawn_foe()
	var foe: Dictionary = core.foes[0]
	core.coin.connect(func(n): coins += n)
	core.coin_drop.connect(func(n, _pos): coins += n)
	# 模拟击杀信号触发另一个伤害/死亡处理器。
	core.kill.connect(func(n):
		kills += n
		core._kill_foe(foe))
	foe["hp"] = 0.0
	core._kill_foe(foe)
	var first_coins := coins
	var damage_before: float = core.dmg_done
	for i in range(10):
		core._kill_foe(foe)
		assert(core._apply_dmg(foe, 100.0, "真实") == 0.0)
	assert(kills == 1 and core.kills_total == 1)
	assert(coins == first_coins and core.dmg_done == damage_before)
	core._spawn_foe("boss", 1.0, 1.0, true, 1, "test")
	var boss: Dictionary = core.foes[core.foes.size() - 1]
	core.boss_alive = true
	core.boss_died.connect(func(_position): bosses += 1)
	boss["hp"] = 0.0
	core._kill_foe(boss)
	var boss_coins := coins
	core._kill_foe(boss)
	assert(bosses == 1 and kills == 2 and not core.boss_alive)
	assert(coins == boss_coins)
	core.queue_free()
	await process_frame
	print("PASS: repeated and reentrant death settles rewards once; dead target ignores damage")
	quit()
