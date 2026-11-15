extends SceneTree
const Audio := preload("res://shared/audio.gd")
func _initialize() -> void:
	for key in ["enlighten", "levelup", "hit_slash", "melee", "coin", "drum", "tension"]:
		var stream = Audio._stream("res://assets/audio/sfx/" + key + ".ogg")
		if stream != null:
			print("[AUDIO] %s length=%.2fs" % [key, stream.get_length()])
	quit()
