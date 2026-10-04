extends RefCounted
# ============================================================
# 配音总管 v1（v82）
#
#   用法：
#     Voice.say("narr", 1)              # 旁白第 1 句
#     Voice.say("player", 3)            # 主角第 3 句
#     Voice.say_file("chenshi_02")      # 直接按文件名
#     Voice.stop()
#
#   文件约定：assets/voice/<speaker>_<两位序号>.ogg
#     旁白 narr_01…  主角 player_01…  陈石 chenshi_01…  苏青鸾 qingluan_01…
#     清单见 docs/配音清单.md
#
#   ⚠ **没有音频文件时全部静默跳过**——配音是"锦上添花"，
#     绝不能因为缺一个 ogg 就让开场页卡住或报错。
# ============================================================

const DIR := "res://assets/voice/"
static var _player: AudioStreamPlayer = null
static var _cache := {}

static func _root() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root
	return null

static func _stream(file_key: String) -> AudioStream:
	if _cache.has(file_key):
		return _cache[file_key]
	var p := DIR + file_key + ".ogg"
	var s: AudioStream = null
	if ResourceLoader.exists(p):
		s = load(p) as AudioStream
	_cache[file_key] = s
	return s

static func has(file_key: String) -> bool:
	return _stream(file_key) != null

# 播一句。speaker＝narr/player/chenshi/qingluan；n＝第几句（1 起）
static func say(speaker: String, n: int) -> bool:
	return say_file(speaker + "_" + ("%02d" % n))

static func say_file(file_key: String) -> bool:
	var s := _stream(file_key)
	if s == null:
		return false          # 没录就没有——静默
	var root := _root()
	if root == null:
		return false
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		_player.name = "VoicePlayer"
		root.add_child(_player)
	_player.stream = s
	_player.volume_db = -4.0
	_player.play()
	return true

static func stop() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()

# 这一句配了音吗（给"要不要在字幕上多停一会儿"这类判断用）
static func timing_bonus(speaker: String, n: int, base := 0.0) -> float:
	if not has(speaker + "_" + ("%02d" % n)):
		return base
	var s := _stream(speaker + "_" + ("%02d" % n))
	return maxf(base, float(s.get_length()) + 0.25)
