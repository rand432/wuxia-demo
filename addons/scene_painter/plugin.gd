@tool
extends EditorPlugin
# ============================================================
# 摆景器（v94）
#   两处入口，怕你找不到面板：
#     ① **Dock 面板**（左栏「摆景器」页签）—— 主界面，缩略图 + 按钮都在这；
#     ② **项目 → 工具** 菜单 —— 面板万一被挤没了/藏起来了，从菜单也能用最常用的三件事。
#       （用户 2026-10-08 截图问"按 JSON 重摆 这个按键在哪"——面板当时没露出来，
#         所以补上菜单这条"兜底的路"。）
# ============================================================
const DockScript := preload("res://addons/scene_painter/dock.gd")
const MENU_PREFIX := "摆景器："
var _dock: Control = null

func _enter_tree() -> void:
	_dock = DockScript.new()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UR, _dock)
	add_tool_menu_item(MENU_PREFIX + "保存布局 JSON", _menu_save)
	add_tool_menu_item(MENU_PREFIX + "按 JSON 重摆", _menu_reload)
	add_tool_menu_item(MENU_PREFIX + "地平线参考（开/关）", _menu_horizon)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_PREFIX + "保存布局 JSON")
	remove_tool_menu_item(MENU_PREFIX + "按 JSON 重摆")
	remove_tool_menu_item(MENU_PREFIX + "地平线参考（开/关）")
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

func _menu_save() -> void:
	if _dock != null:
		_dock._on_save()

func _menu_reload() -> void:
	if _dock != null:
		_dock._on_reload()

func _menu_horizon() -> void:
	if _dock != null:
		_dock._horizon_on = not _dock._horizon_on
		_dock._on_horizon(_dock._horizon_on)
