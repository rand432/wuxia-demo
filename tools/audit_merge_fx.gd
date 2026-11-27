extends SceneTree
const Iso := preload("res://tools/test_isolation.gd")
const Battle := preload("res://kushou/battle_ui.tscn")
const LS := preload("res://shared/level_state.gd")
var b = null

func _initialize() -> void:
	var e := Iso.verify()
	if e != "":
		print("[MERGE] REJECT " + e); quit(2); return
	seed(20261116)
	LS.ensure_loaded(); LS.current_level = 6
	call_deferred("_run")

func _run() -> void:
	b = Battle.instantiate(); root.add_child(b)
	await process_frame
	b._tut.cancel(); b._tut.queue_free(); b.set("_tut", null)
	b.set_process(true)
	b._core.set_process(false)
	await _wait(0.3)
	var ids3 := _pick_set(3)
	var ids4 := _pick_set(4)
	_check("找到三卡组合", ids3.size() == 3)
	_check("找到四卡组合", ids4.size() == 4)
	await _trigger(ids3, 3)
	await _trigger(ids4, 4)
	# 同帧触发两套组合。先结算二者，演出只显示一组。
	for cid in ids3 + ids4:
		b._cards.append(str(cid))
	var before: int = b._combined.size()
	b._check_sets()
	_check("同帧两套均已结算，后组等待演出", b._combined.size() == before + 2 and b._merge_layers.size() == 1 and b._merge_pending.size() == 1)
	await _wait(1.35)
	_check("第一组播放后接上第二组", b._merge_layers.size() == 1 and b._merge_pending.is_empty())
	var last_layer: Control = b._merge_layers.back() if not b._merge_layers.is_empty() else null
	b._end_run(false)
	_check("结算立刻隐藏合成层", last_layer != null and not last_layer.visible and b._merge_layers.is_empty())
	await _wait(0.85)
	_check("结算后不再生成临时卡", not is_instance_valid(last_layer) and b._merge_pending.is_empty())
	print("PASS: merge FX uses real set sizes 3/4 and cleans layers" if _fail.is_empty() else ("FAIL: " + str(_fail)))
	quit(0 if _fail.is_empty() else 1)

var _fail: Array[String] = []
var _last_combined := 0

func _pick_set(size: int) -> Array:
	for sid in b._set_cards.keys():
		var ids: Array = b._set_cards[sid]
		if ids.size() != size:
			continue
		var c: Dictionary = b._card_db.get(str(ids[0]), {})
		if int(c.get("set_size", 0)) == size:
			return ids.duplicate()
	return []

func _trigger(ids: Array, size: int) -> void:
	_last_combined = b._combined.size()
	for cid in ids:
		b._cards.append(str(cid))
	b._check_sets()
	_check("组合 %d 张激活一次" % size, b._combined.size() == _last_combined + 1)
	var freed := true
	for cid in ids:
		if b._cards.has(str(cid)):
			freed = false
	_check("卡位释放 %d 张" % size, freed)
	_check("合成层卡数 %d" % size, b._merge_layers.size() >= 1 and (b._merge_layers.back() as Control).get_child_count() == size)
	var source_layer: Control = b._merge_layers.back()
	for i in size:
		var card: TextureRect = source_layer.get_child(i)
		var data: Dictionary = b._card_db[str(ids[i])]
		_check("来源卡 %d 纹样一致" % (i + 1), card.texture != null and card.texture == b._draw_art(str(data["art"])))
	await _wait(0.84)
	var layer = b._merge_layers.back() if not b._merge_layers.is_empty() else null
	_check("结果卡只飞一张", layer != null and (layer as Control).get_child_count() == size + 1)
	await _wait(1.1)
	_check("演出后回收合成层", b._merge_layers.is_empty())

func _check(name: String, ok: bool) -> void:
	print(("[MERGE] PASS " if ok else "[MERGE] FAIL ") + name)
	if not ok: _fail.append(name)

func _wait(sec: float) -> void:
	await create_timer(sec).timeout
