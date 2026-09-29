extends Control
# ============================================================
# 会动的立绘/头像 v1（零成本程序化动画，不用视频）
#   · 呼吸：纵向 ±1.2%、横向反向补偿（体积守恒，看着像在喘气）
#   · 微摆：绕**脚底**的慢摆 ±0.7°（纸片人的"活气"，比整体平移自然）
#   · 入场：0.35 秒淡入 + 轻微上浮
# 用法：
#   var av = ArtView.new(); panel.add_child(av)
#   av.position = Vector2(x, y)      # 控件左上角
#   av.set_art(tex, 700.0)           # 想画多高（像素）；宽度按比例自动
# 贴图按"脚底中心"对齐控件底边——立绘、Q版、头像都能用（头像就当"底"在下巴）。
# ============================================================

var breath_amp := 0.012     # 呼吸幅度（占身高比例）
var sway_deg := 0.7         # 摆动幅度（度）
var fade_in := true

var _tr: TextureRect
var _t := 0.0
var _phase := 0.0

func set_art(tex: Texture2D, h := 620.0) -> void:
	if tex == null:
		return
	if _tr == null:
		_tr = TextureRect.new()
		_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tr)
	_tr.texture = tex
	var th := maxf(float(tex.get_height()), 1.0)
	var w := float(tex.get_width()) * (h / th)
	_tr.size = Vector2(w, h)
	_tr.position = Vector2.ZERO
	size = Vector2(w, h)
	_tr.pivot_offset = Vector2(w * 0.5, h)   # 绕脚底转
	_phase = randf() * TAU                     # 多人同屏时错开呼吸相位，不然像机器
	if fade_in:
		_tr.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_tr, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if _tr == null:
		return
	_t += delta
	var b := sin(_t * 1.9 + _phase) * breath_amp
	_tr.scale = Vector2(1.0 - b * 0.55, 1.0 + b)
	_tr.rotation = deg_to_rad(sin(_t * 0.85 + _phase) * sway_deg)
