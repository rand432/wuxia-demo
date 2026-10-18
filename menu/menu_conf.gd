extends RefCounted
# ============================================================
# menu_conf.gd —— 主界面·参数总表（拆分 1/6）
# 想调任何数字/颜色，只改这个文件。其余文件的几何全部从这里取。
# v4.1 增：底部五个按钮（多一个「弟子」）；剧本常量（村名/弟子名）。
# ============================================================

# ---- 画布与卷 ----
const DW := 720.0
const DH := 1280.0
const STRIP_W := 3000.0
const BAND_TOP := 26.0
const BAND_BOT := 1150.0
const BAND_H := BAND_BOT - BAND_TOP
const MOUNT := 30.0
const SCENE_TOP := 200.0
const SCENE_BOT := 840.0
const CONTENT_TOP := BAND_TOP + MOUNT
const CONTENT_BOT := BAND_BOT - MOUNT
const CAM_MAX := STRIP_W - DW
const CAM_MIN := 0.0
const ROLL_MAX := 54.0
# 开屏停在哪儿：默认最右端（先看见书名）。改成 1180.0 = 开屏先看村子废墟
const OPEN_CAM := CAM_MAX
const START_STAGE := 0

# ---- 底部按钮 ----
# v4.2：底排 5 格 → **6 格**，新增第 5 格「宝箱」（宝箱专页，见 chest_panel.gd）。
#   注意下标的坑：第 4 格（下标 3）画的是「宠物」，`TAGN[3]` 那串"设置"只是占位
#   （设置以后并进「石桌」）。加/删底排格子时，`menu_sketch._tag_fire()` 的 case 要一起改。
const TAG_BM := 16.0
const TAG_H := 100.0
const TAG_Y := DH - TAG_BM - TAG_H
const HINT_Y := TAG_Y - 20.0
const TOAST_Y := TAG_Y - 66.0
# v64b：第 6 格「关于」→ **「阅历」**（用户挑的入口：第 5 问"可"）——阅历线面板
#   ⚠ 改这一格时 memu_sketch._tag_fire() 的 case 5 要一起改。
const TAGN := ["开始历练", "弟子", "行囊", "设置", "宝箱", "阅历"]
const TAG_CHEST := 4   # 宝箱那一格的下标（HUD 在那儿画计数角标，sketch 在那儿开面板）

# ---- 剧本：游历结束、落脚青山村之后（名字随便改，只影响显示） ----
const VILLAGE_NAME := "青山村"
const DISCIPLE_NAME := "阿石"
const DISCIPLE_ORIGIN := "青山村口的小伙"
const DISCIPLE_QUOTE := "「我跟你走。」"
const DISCIPLE_NOTE := "见你应下了重修村子的事，他就站在门外等着。"

# ---- 全卷动效总闸与节奏（数字越小越慢越静；TIME_SCALE=0 = 全静止） ----
const TIME_SCALE := 1.0
const FIG_CX := 1500.0
const FIG_SPAN := 58.0
const FIG_RATE := 0.26
const FIG_STEP := 4.2
const GAIT_RATE := 1.9
const ROAD_RATE := 0.045
const ROW_RATE := 0.9
const SUN_X := 1780.0
const SUN_Y := 372.0
const SUN_R := 44.0
const SUN_HALO := 112.0
const WIND_RATE := 0.42
const WIND_AMP := 4.0
const SMOKE_RATE := 0.09
const PETAL_RATE := 13.0
const CLOUD_W := 3300.0
const GOOSE_PERIOD := 47.0

# ---- 河 ----
const RIVER_X0 := 620.0
const RIVER_X1 := 2590.0
const RIVER_FAR_Y := 653.0
const RIVER_NEAR_Y := 736.0
const RIVER_FAR_AMP := 17.0
const RIVER_NEAR_AMP := 9.0
const RIVER_STEP := 40.0

# ---- 装裱 ----
const YINSHOU_X0 := 2700.0
const YINSHOU_X1 := 3000.0
const YINSHOU_CX := 2850.0
const GAP_R0 := 2670.0
const GAP_R1 := 2700.0
const GAP_L0 := 590.0
const GAP_L1 := 620.0
const WEIBA_X1 := 590.0

# ---- 文字与场景 ----
const TITLE := "少年游"
const FONT_PATH := "res://assets/fonts/lxgw_wenkai.ttf"
const JOURNEY_SCENE := "res://journey_test.tscn"
const EXPLORE_SCENE := "res://journey/explore/explore_map.tscn"

# ---- 颜色 ----
const INK := Color(0.16, 0.155, 0.18)
const PAPER := Color(0.947, 0.929, 0.874)
const MOUNT_C := Color(0.845, 0.780, 0.660)
const GAP_C := Color(0.878, 0.853, 0.792)
const YIN_C := Color(0.927, 0.907, 0.848)
const WEI_C := Color(0.917, 0.895, 0.835)
const SEAL_C := Color(0.72, 0.20, 0.15)
const DESK_C := Color(0.792, 0.742, 0.660)
const BG_C := Color(0.135, 0.125, 0.145)
const DESK_L := Color(0.815, 0.768, 0.690)
const CHIP_C := Color(0.930, 0.906, 0.850)
const CHIP_P := Color(0.905, 0.868, 0.795)
const BACK_C := Color(0.848, 0.780, 0.660)
const CAP_C := Color(0.800, 0.710, 0.560)
const CAP_C2 := Color(0.745, 0.650, 0.500)
const WOOD_L := Color(0.520, 0.410, 0.300)
