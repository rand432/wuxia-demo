extends RefCounted
# ============================================================
# 音频总管 v1：BGM 交叉淡入淡出 ＋ 音效一发
#
#   Audio.play_bgm("bgm_journey")      # 场景 BGM（重复调用同一首不会重头播）
#   Audio.sfx("hit_slash", -6.0)       # 音效（一发即弃）
#   Audio.ui_click()                   # 统一的界面点击音（水滴入墨）
#
# 资源：assets/audio/bgm_*.ogg（4 首场景 BGM）＋ assets/audio/sfx/*.ogg（20+ 条音效）
#   —— 都是从项目已有的"开场动画那批音乐/音效"里挑出来重新配的（见对话记录），
#      所以**不花一分钱**、也不依赖任何音频通道（MiniMax 音乐 API 已停服）。
#
# 实现说明：
#   · 不用 autoload（工程里一个 autoload 都没有，加一个要动 project.godot）；
#     这里按需把播放器挂到 scene tree 的 root 上，跨场景不会被回收。
#   · BGM 两路 player 交叉淡入淡出；SFX 用一次性 player，播完自己 queue_free。
# ============================================================

const DIR_BGM := "res://assets/audio/"
const DIR_SFX := "res://assets/audio/sfx/"

static var _cur_bgm := ""
static var _bgm_a: AudioStreamPlayer = null
static var _bgm_b: AudioStreamPlayer = null
static var _use_a := true
static var _cache := {}
static var _bgm_db := -12.0     # BGM 基准音量（音效比它响，避免盖过打击声）

static func _root() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root
	return null

static func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	_cache[path] = s
	return s

# ---------------- BGM ----------------

static func play_bgm(key: String, fade := 1.2) -> void:
	if key == _cur_bgm:
		return
	var root := _root()
	if root == null:
		return
	var s := _stream(DIR_BGM + key + ".ogg")
	if s == null:
		return
	_cur_bgm = key
	if _bgm_a == null:
		_bgm_a = AudioStreamPlayer.new()
		_bgm_a.name = "BgmA"
		root.add_child(_bgm_a)
	if _bgm_b == null:
		_bgm_b = AudioStreamPlayer.new()
		_bgm_b.name = "BgmB"
		root.add_child(_bgm_b)
	# ⚠ 三元表达式两边都是 AudioStreamPlayer，但 Godot 推不出类型（Variant）——
	#   后面 create_tween() 就"无法推断 tw 的类型"直接 Parse Error，所以这里必须显式标类型
	var old: AudioStreamPlayer = _bgm_b if _use_a else _bgm_a
	var newp: AudioStreamPlayer = _bgm_a if _use_a else _bgm_b
	_use_a = not _use_a
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	newp.stream = s
	newp.volume_db = -60.0
	newp.play()
	var tw := newp.create_tween()
	tw.tween_property(newp, "volume_db", _bgm_db, fade)
	if old.playing:
		var tw2 := old.create_tween()
		tw2.tween_property(old, "volume_db", -60.0, fade)
		tw2.tween_callback(old.stop)

static func stop_bgm(fade := 0.8) -> void:
	_cur_bgm = ""
	for p in [_bgm_a, _bgm_b]:
		if p != null and p.playing:
			var tw: Tween = p.create_tween()
			tw.tween_property(p, "volume_db", -60.0, fade)
			tw.tween_callback(p.stop)

# ---------------- 音效 ----------------

static func sfx(key: String, vol_db := -6.0, pitch := 1.0) -> void:
	var root := _root()
	if root == null:
		return
	var s := _stream(DIR_SFX + key + ".ogg")
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

# 界面点击：统一走这一口（后面接"水滴墨扩散"特效时也挂这里）
static func ui_click() -> void:
	# v67：换成素材包里的真·UI 音（原来用"墨滴"充数）；要回墨滴就改回 "ink_drop"
	sfx("ui_click", -12.0, randf_range(0.96, 1.06))
