extends TextureRect

const PORTRAIT_SHADER := preload("res://shared/god_portrait_motion.gdshader")
const DEMO_TIME := 1.10
const GESTURES := {"zhujue": Vector2(0.95, -0.38), "chenshi": Vector2(-0.85, 0.72),
	"liuqingqing": Vector2(0.32, -0.68), "qingluan": Vector2(1.0, -0.22),
	"xiaoqier": Vector2(0.85, 0.38), "gundilong": Vector2(-0.75, 0.93), "mingzhu": Vector2(-0.36, -0.75)}

var spectral := false
var character_id := ""
var _material := ShaderMaterial.new()
var _elapsed := 0.0
var _demo_left := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_material.shader = PORTRAIT_SHADER
	_material.set_shader_parameter("spectral", spectral)
	material = _material
	resized.connect(_update_crop)
	_update_crop()

func set_portrait(art: Texture2D, aid: String) -> void:
	if character_id != aid:
		_demo_left = 0.0
		_elapsed = 0.0
		_apply_pose()
	character_id = aid
	texture = art
	_update_crop()

func demonstrate() -> void:
	_elapsed = 0.0
	_demo_left = DEMO_TIME
	_apply_pose()

func _update_crop() -> void:
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var art_size := texture.get_size()
	var scale_to_cover := maxf(size.x / art_size.x, size.y / art_size.y)
	var region := (size / scale_to_cover) / art_size
	var vertical_anchor := 0.04 if character_id == "zhujue" else 0.32
	_material.set_shader_parameter("source_scale", region)
	_material.set_shader_parameter("source_origin", (Vector2.ONE - region) * Vector2(0.5, vertical_anchor))

func _process(delta: float) -> void:
	if texture == null or not is_visible_in_tree():
		return
	_elapsed += delta
	_demo_left = maxf(0.0, _demo_left - delta)
	_apply_pose()

func _apply_pose() -> void:
	var progress := 1.0 - _demo_left / DEMO_TIME
	var emphasis := sin(PI * progress) if _demo_left > 0.0 else 0.0
	var shift: Vector2 = GESTURES.get(character_id, Vector2(0.45, -0.28))
	_material.set_shader_parameter("breath", sin(_elapsed * 2.3))
	_material.set_shader_parameter("gesture", shift * emphasis)
	_material.set_shader_parameter("glow", emphasis)
