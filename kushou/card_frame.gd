extends RefCounted
# 卡牌花边框：按品质取一张 2:3 的框，画在卡面最底层；没有图时调用方回退到原来的 StyleBox。
const QC := [Color(0.54, 0.48, 0.38), Color(0.31, 0.48, 0.29), Color(0.18, 0.42, 0.45), Color(0.42, 0.29, 0.48), Color(0.72, 0.53, 0.16)]

static var _cache: Dictionary = {}

static func texture_path(quality: int) -> String:
	return "res://assets/art/cards/frames/frame_%d.png" % clampi(quality, 1, 5)

static func tex_of(quality: int) -> Texture2D:
	var q := clampi(quality - 1, 0, 4)
	if _cache.has(q):
		return _cache[q] as Texture2D
	var path := texture_path(quality)
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		var art := load(path) as Texture2D
		if art != null:
			var frame := CanvasTexture.new()
			frame.diffuse_texture = art
			frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			t = frame
	_cache[q] = t
	return t

# 在目标 Control 上画框；返回 true 表示画了图（调用方就不用再画 StyleBox 了）
static func draw_on(c: CanvasItem, quality: int, size: Vector2) -> bool:
	var t := tex_of(quality)
	if t == null:
		return false
	c.draw_texture_rect(t, Rect2(Vector2.ZERO, size), false)
	return true

# 标题底色：框顶部有花边，压一条纸色带保证字看得清
static func title_band(c: CanvasItem, rect: Rect2) -> void:
	c.draw_rect(rect, Color(0.878, 0.843, 0.757, 0.96))

# 内容区：暖纸色半透明，压住框内花边保证文字可读；色值贴近花边框的宣纸底，避免出现"白块"
static func content_panel(c: CanvasItem, rect: Rect2) -> void:
	c.draw_rect(rect, Color(0.878, 0.843, 0.757, 0.95))
