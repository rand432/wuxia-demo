extends Control
# 原版顶栏组合：PlaqueLayer（头像/名号/设置）＋ MoneyHud（银两/元宝）
signal profile_pressed
signal settings_pressed

const PlaqueLayer := preload("res://menu/menu_plaque.gd")
const MoneyHud := preload("res://menu/money_hud.gd")
const Draw := preload("res://menu/menu_draw.gd")
const GameState := preload("res://shared/game_state.gd")

var _plaque
var _money

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque = PlaqueLayer.new()
	_plaque.font = Draw.pick_font(null)
	add_child(_plaque)
	_plaque.add_disc("avatar", 0.086, 0.0375, "", func() -> void: profile_pressed.emit(), "", {"w": 64.0})
	var pn := str(GameState.player_name)
	if pn == "":
		pn = str(GameState.role_data("player").get("name", "少侠"))
	_plaque.add_txt("name", 0.239, 0.0383, pn, func() -> void: profile_pressed.emit(), GameState.role_grade_cn("player"), {"w": 140.0, "h": 76.0})
	_plaque.add_chip("settings", 0.9264, 0.0375, "设置", func() -> void: settings_pressed.emit(), "", {"w": 58.0, "h": 34.0})
	_money = MoneyHud.new()
	_money.font = _plaque.font
	_money.silver = GameState.coin("silver")
	_money.yuanbao = GameState.coin("yuanbao")
	add_child(_money)

func refresh() -> void:
	if _money != null:
		_money.silver = GameState.coin("silver")
		_money.yuanbao = GameState.coin("yuanbao")
