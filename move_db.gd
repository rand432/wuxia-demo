extends RefCounted
# ============================================================
# 招式表（纯数据）
# 每把武器一张表；每招 = 若干"步"
# 每步 = [姿势字典, 定格秒数, 弹簧K(可选), 弹簧D(可选)]
# K/D 越小动作越慢越重；不写 = 380/27（快）。多个伸/收步 = 连击。
# ============================================================
const T_TORSO := 0
const T_ARM_FU := 1
const T_ARM_FL := 2
const T_ARM_BU := 3
const T_ARM_BL := 4
const T_LEG_FU := 5
const T_LEG_FL := 6
const T_LEG_BU := 7
const T_LEG_BL := 8
static func build() -> Dictionary:
	return {
		"sword": {
			"chop": [
				[{T_TORSO: 94.0, T_ARM_FU: 115.0, T_ARM_FL: 140.0, T_ARM_BU: -100.0, T_ARM_BL: -80.0, T_LEG_FU: -70.0, T_LEG_FL: -88.0, T_LEG_BU: -114.0, T_LEG_BL: -104.0}, 0.45],
				[{T_TORSO: 58.0, T_ARM_FU: -95.0, T_ARM_FL: -80.0, T_ARM_BU: 150.0, T_ARM_BL: 125.0, T_LEG_FU: -60.0, T_LEG_FL: -92.0, T_LEG_BU: -126.0, T_LEG_BL: -98.0}, 0.95, 110.0, 14.5],
			],
			"cut": [
				[{T_TORSO: 95.0, T_ARM_FU: 178.0, T_ARM_FL: 162.0, T_ARM_BU: -55.0, T_ARM_BL: -30.0, T_LEG_FU: -72.0, T_LEG_FL: -88.0, T_LEG_BU: -116.0, T_LEG_BL: -100.0}, 0.42],
				[{T_TORSO: 76.0, T_ARM_FU: 4.0, T_ARM_FL: -12.0, T_ARM_BU: -125.0, T_ARM_BL: -100.0, T_LEG_FU: -64.0, T_LEG_FL: -96.0, T_LEG_BU: -120.0, T_LEG_BL: -98.0}, 0.90, 110.0, 14.5],
			],
			"slice": [
				[{T_TORSO: 98.0, T_ARM_FU: -105.0, T_ARM_FL: -140.0, T_ARM_BU: 140.0, T_ARM_BL: 120.0, T_LEG_FU: -68.0, T_LEG_FL: -104.0, T_LEG_BU: -118.0, T_LEG_BL: -92.0}, 0.40],
				[{T_TORSO: 88.0, T_ARM_FU: 70.0, T_ARM_FL: 55.0, T_ARM_BU: -120.0, T_ARM_BL: -95.0, T_LEG_FU: -78.0, T_LEG_FL: -82.0, T_LEG_BU: -118.0, T_LEG_BL: -102.0}, 0.85, 200.0, 19.0],
			],
			"stab": [
				[{T_TORSO: 96.0, T_ARM_FU: -118.0, T_ARM_FL: -28.0, T_ARM_BU: -70.0, T_ARM_BL: -40.0, T_LEG_FU: -70.0, T_LEG_FL: -96.0, T_LEG_BU: -114.0, T_LEG_BL: -96.0}, 0.45],
				[{T_TORSO: 78.0, T_ARM_FU: 0.0, T_ARM_FL: -2.0, T_ARM_BU: -135.0, T_ARM_BL: -105.0, T_LEG_FU: -58.0, T_LEG_FL: -60.0, T_LEG_BU: -140.0, T_LEG_BL: -100.0}, 0.90, 520.0, 32.0],
			],
			"sweep": [
				[{T_TORSO: 102.0, T_ARM_FU: -140.0, T_ARM_FL: -170.0, T_ARM_BU: -128.0, T_ARM_BL: -100.0, T_LEG_FU: -54.0, T_LEG_FL: -116.0, T_LEG_BU: -116.0, T_LEG_BL: -74.0}, 0.45],
				[{T_TORSO: 74.0, T_ARM_FU: -30.0, T_ARM_FL: -40.0, T_ARM_BU: -105.0, T_ARM_BL: -80.0, T_LEG_FU: -62.0, T_LEG_FL: -104.0, T_LEG_BU: -118.0, T_LEG_BL: -86.0}, 0.95, 110.0, 14.5],
			],
		},
		"dual": {
			"dual_chop": [
				[{T_TORSO: 96.0, T_ARM_FU: 125.0, T_ARM_FL: 150.0, T_ARM_BU: 120.0, T_ARM_BL: 145.0, T_LEG_FU: -70.0, T_LEG_FL: -88.0, T_LEG_BU: -114.0, T_LEG_BL: -104.0}, 0.30],
				[{T_TORSO: 62.0, T_ARM_FU: -95.0, T_ARM_FL: -75.0, T_ARM_BU: -62.0, T_ARM_BL: -38.0, T_LEG_FU: -60.0, T_LEG_FL: -92.0, T_LEG_BU: -126.0, T_LEG_BL: -98.0}, 0.60, 120.0, 15.0],
			],
			"dual_alt": [
				[{T_TORSO: 96.0, T_ARM_FU: 168.0, T_ARM_FL: 172.0, T_ARM_BU: -70.0, T_ARM_BL: -50.0, T_LEG_FU: -70.0, T_LEG_FL: -88.0, T_LEG_BU: -114.0, T_LEG_BL: -104.0}, 0.20],
				[{T_TORSO: 82.0, T_ARM_FU: 28.0, T_ARM_FL: -6.0, T_ARM_BU: -85.0, T_ARM_BL: -75.0}, 0.15, 320.0, 24.0],
				[{T_TORSO: 90.0, T_ARM_FU: -30.0, T_ARM_FL: -60.0, T_ARM_BU: 155.0, T_ARM_BL: 165.0}, 0.13],
				[{T_TORSO: 80.0, T_ARM_FU: -78.0, T_ARM_FL: -95.0, T_ARM_BU: 18.0, T_ARM_BL: -8.0}, 0.15, 320.0, 24.0],
				[{T_TORSO: 94.0, T_ARM_FU: 150.0, T_ARM_FL: 148.0, T_ARM_BU: -40.0, T_ARM_BL: -20.0}, 0.12],
				[{T_TORSO: 78.0, T_ARM_FU: 15.0, T_ARM_FL: -18.0, T_ARM_BU: -25.0, T_ARM_BL: -35.0}, 0.45, 300.0, 24.0],
			],
			"dual_thrust": [
				[{T_TORSO: 96.0, T_ARM_FU: -95.0, T_ARM_FL: -45.0, T_ARM_BU: -95.0, T_ARM_BL: -45.0, T_LEG_FU: -70.0, T_LEG_FL: -96.0, T_LEG_BU: -114.0, T_LEG_BL: -96.0}, 0.25],
				[{T_TORSO: 80.0, T_ARM_FU: -2.0, T_ARM_FL: -2.0, T_ARM_BU: -14.0, T_ARM_BL: -8.0, T_LEG_FU: -58.0, T_LEG_FL: -60.0, T_LEG_BU: -140.0, T_LEG_BL: -100.0}, 0.55, 520.0, 32.0],
			],
			# v57 补：普攻表（run_state.MOVE_TABLE）里有这一招，但动作表里一直缺——
			#   play_move 找不到就退回"表里的第一招"，双撩会演成双劈。
			"dual_rip": [
				[{T_TORSO: 98.0, T_ARM_FU: 132.0, T_ARM_FL: 118.0, T_ARM_BU: 128.0, T_ARM_BL: 112.0, T_LEG_FU: -68.0, T_LEG_FL: -86.0, T_LEG_BU: -116.0, T_LEG_BL: -102.0}, 0.24],
				[{T_TORSO: 70.0, T_ARM_FU: -128.0, T_ARM_FL: -158.0, T_ARM_BU: -124.0, T_ARM_BL: -152.0, T_LEG_FU: -60.0, T_LEG_FL: -94.0, T_LEG_BU: -122.0, T_LEG_BL: -98.0}, 0.72, 180.0, 19.0],
			],
		},
		"dagger": {
			"dagger_slash": [
				[{T_TORSO: 95.0, T_ARM_FU: 165.0, T_ARM_FL: 150.0, T_ARM_BU: -70.0, T_ARM_BL: -150.0, T_LEG_FU: -68.0, T_LEG_FL: -92.0, T_LEG_BU: -110.0, T_LEG_BL: -98.0}, 0.16],
				[{T_TORSO: 78.0, T_ARM_FU: 8.0, T_ARM_FL: -18.0, T_ARM_BU: -60.0, T_ARM_BL: -135.0}, 0.26, 320.0, 24.0],
				[{T_TORSO: 88.0, T_ARM_FU: 130.0, T_ARM_FL: 140.0, T_ARM_BU: -65.0, T_ARM_BL: -140.0}, 0.30, 320.0, 24.0],
			],
			"dagger_stab": [
				[{T_TORSO: 94.0, T_ARM_FU: -88.0, T_ARM_FL: 42.0, T_ARM_BU: -62.0, T_ARM_BL: -142.0, T_LEG_FU: -66.0, T_LEG_FL: -94.0, T_LEG_BU: -108.0, T_LEG_BL: -96.0}, 0.14],
				[{T_TORSO: 82.0, T_ARM_FU: -8.0, T_ARM_FL: -10.0, T_ARM_BU: -58.0, T_ARM_BL: -140.0}, 0.12, 580.0, 34.0],
				[{T_TORSO: 90.0, T_ARM_FU: -70.0, T_ARM_FL: 32.0, T_ARM_BU: -60.0, T_ARM_BL: -142.0}, 0.10, 580.0, 34.0],
				[{T_TORSO: 80.0, T_ARM_FU: -4.0, T_ARM_FL: -6.0, T_ARM_BU: -58.0, T_ARM_BL: -140.0}, 0.12, 580.0, 34.0],
				[{T_TORSO: 88.0, T_ARM_FU: -66.0, T_ARM_FL: 36.0, T_ARM_BU: -60.0, T_ARM_BL: -142.0}, 0.10, 580.0, 34.0],
				[{T_TORSO: 76.0, T_ARM_FU: -2.0, T_ARM_FL: -2.0, T_ARM_BU: -56.0, T_ARM_BL: -138.0}, 0.42, 580.0, 34.0],
			],
			"dagger_flurry": [
				[{T_TORSO: 92.0, T_ARM_FU: -92.0, T_ARM_FL: 46.0, T_ARM_BU: -62.0, T_ARM_BL: -142.0, T_LEG_FU: -66.0, T_LEG_FL: -94.0, T_LEG_BU: -108.0, T_LEG_BL: -96.0}, 0.10],
				[{T_TORSO: 84.0, T_ARM_FU: -6.0, T_ARM_FL: 22.0, T_ARM_BU: -58.0, T_ARM_BL: -140.0}, 0.09, 620.0, 36.0],
				[{T_TORSO: 88.0, T_ARM_FU: -40.0, T_ARM_FL: -42.0, T_ARM_BU: -60.0, T_ARM_BL: -142.0}, 0.09, 620.0, 36.0],
				[{T_TORSO: 82.0, T_ARM_FU: 2.0, T_ARM_FL: -12.0, T_ARM_BU: -56.0, T_ARM_BL: -140.0}, 0.09, 620.0, 36.0],
				[{T_TORSO: 86.0, T_ARM_FU: -30.0, T_ARM_FL: 34.0, T_ARM_BU: -58.0, T_ARM_BL: -142.0}, 0.09, 620.0, 36.0],
				[{T_TORSO: 80.0, T_ARM_FU: -4.0, T_ARM_FL: -8.0, T_ARM_BU: -56.0, T_ARM_BL: -138.0}, 0.09, 620.0, 36.0],
				[{T_TORSO: 78.0, T_ARM_FU: 0.0, T_ARM_FL: -4.0, T_ARM_BU: -54.0, T_ARM_BL: -136.0}, 0.40, 620.0, 36.0],
			],
		},
		"spear": {
			"spear_thrust": [
				[{T_TORSO: 95.0, T_ARM_FU: -110.0, T_ARM_FL: -25.0, T_ARM_BU: -100.0, T_ARM_BL: -70.0, T_LEG_FU: -72.0, T_LEG_FL: -90.0, T_LEG_BU: -114.0, T_LEG_BL: -102.0}, 0.30],
				[{T_TORSO: 76.0, T_ARM_FU: -2.0, T_ARM_FL: -2.0, T_ARM_BU: -118.0, T_ARM_BL: -95.0, T_LEG_FU: -58.0, T_LEG_FL: -62.0, T_LEG_BU: -142.0, T_LEG_BL: -100.0}, 0.26, 540.0, 33.0],
				[{T_TORSO: 88.0, T_ARM_FU: -55.0, T_ARM_FL: -20.0, T_ARM_BU: -105.0, T_ARM_BL: -80.0}, 0.12, 540.0, 33.0],
				[{T_TORSO: 72.0, T_ARM_FU: 2.0, T_ARM_FL: 0.0, T_ARM_BU: -122.0, T_ARM_BL: -98.0, T_LEG_FU: -54.0, T_LEG_FL: -58.0, T_LEG_BU: -146.0, T_LEG_BL: -100.0}, 0.50, 540.0, 33.0],
			],
			"spear_multi": [
				[{T_TORSO: 94.0, T_ARM_FU: -60.0, T_ARM_FL: -5.0, T_ARM_BU: -100.0, T_ARM_BL: -70.0, T_LEG_FU: -72.0, T_LEG_FL: -90.0, T_LEG_BU: -114.0, T_LEG_BL: -102.0}, 0.22],
				[{T_TORSO: 78.0, T_ARM_FU: -4.0, T_ARM_FL: -4.0, T_ARM_BU: -115.0, T_ARM_BL: -90.0, T_LEG_FU: -60.0, T_LEG_FL: -68.0, T_LEG_BU: -134.0, T_LEG_BL: -100.0}, 0.11, 560.0, 34.0],
				[{T_TORSO: 90.0, T_ARM_FU: -48.0, T_ARM_FL: -2.0, T_ARM_BU: -102.0, T_ARM_BL: -74.0}, 0.09, 560.0, 34.0],
				[{T_TORSO: 78.0, T_ARM_FU: -2.0, T_ARM_FL: -2.0, T_ARM_BU: -116.0, T_ARM_BL: -92.0, T_LEG_FU: -60.0, T_LEG_FL: -66.0, T_LEG_BU: -136.0, T_LEG_BL: -100.0}, 0.11, 560.0, 34.0],
				[{T_TORSO: 90.0, T_ARM_FU: -46.0, T_ARM_FL: -2.0, T_ARM_BU: -102.0, T_ARM_BL: -74.0}, 0.09, 560.0, 34.0],
				[{T_TORSO: 76.0, T_ARM_FU: 0.0, T_ARM_FL: 0.0, T_ARM_BU: -118.0, T_ARM_BL: -94.0, T_LEG_FU: -58.0, T_LEG_FL: -62.0, T_LEG_BU: -140.0, T_LEG_BL: -100.0}, 0.11, 560.0, 34.0],
				[{T_TORSO: 88.0, T_ARM_FU: -44.0, T_ARM_FL: -2.0, T_ARM_BU: -102.0, T_ARM_BL: -74.0}, 0.09, 560.0, 34.0],
				[{T_TORSO: 72.0, T_ARM_FU: 4.0, T_ARM_FL: 2.0, T_ARM_BU: -122.0, T_ARM_BL: -96.0, T_LEG_FU: -54.0, T_LEG_FL: -58.0, T_LEG_BU: -146.0, T_LEG_BL: -100.0}, 0.40, 560.0, 34.0],
			],
			"spear_turn": [
				[{T_TORSO: 124.0, T_ARM_FU: -108.0, T_ARM_FL: 6.0, T_ARM_BU: -125.0, T_ARM_BL: -100.0, T_LEG_FU: -60.0, T_LEG_FL: -112.0, T_LEG_BU: -100.0, T_LEG_BL: -58.0}, 0.55],
				[{T_TORSO: 70.0, T_ARM_FU: 4.0, T_ARM_FL: 2.0, T_ARM_BU: -128.0, T_ARM_BL: -100.0, T_LEG_FU: -54.0, T_LEG_FL: -58.0, T_LEG_BU: -148.0, T_LEG_BL: -100.0}, 0.65, 520.0, 32.0],
			],
		},
		# v57：暗器三招（原"棍"三招）——飞掷（顺手甩出）· 连掷（撒手一片）· 踢（近身）
		"anqi": {
			"anqi_throw": [
				[{T_TORSO: 96.0, T_ARM_FU: 60.0, T_ARM_FL: 122.0, T_ARM_BU: -104.0, T_ARM_BL: -78.0, T_LEG_FU: -66.0, T_LEG_FL: -84.0, T_LEG_BU: -116.0, T_LEG_BL: -106.0}, 0.34],
				[{T_TORSO: 74.0, T_ARM_FU: -96.0, T_ARM_FL: -34.0, T_ARM_BU: -70.0, T_ARM_BL: -118.0, T_LEG_FU: -58.0, T_LEG_FL: -70.0, T_LEG_BU: -122.0, T_LEG_BL: -96.0}, 0.95, 150.0, 16.0],
			],
			"anqi_rain": [
				[{T_TORSO: 104.0, T_ARM_FU: 44.0, T_ARM_FL: 148.0, T_ARM_BU: 28.0, T_ARM_BL: 120.0, T_LEG_FU: -58.0, T_LEG_FL: -104.0, T_LEG_BU: -112.0, T_LEG_BL: -80.0}, 0.24],
				[{T_TORSO: 70.0, T_ARM_FU: -112.0, T_ARM_FL: -20.0, T_ARM_BU: -118.0, T_ARM_BL: -26.0, T_LEG_FU: -64.0, T_LEG_FL: -74.0, T_LEG_BU: -120.0, T_LEG_BL: -94.0}, 0.42, 120.0, 13.0],
				[{T_TORSO: 66.0, T_ARM_FU: -104.0, T_ARM_FL: -14.0, T_ARM_BU: -112.0, T_ARM_BL: -20.0, T_LEG_FU: -62.0, T_LEG_FL: -72.0, T_LEG_BU: -118.0, T_LEG_BL: -92.0}, 1.00, 120.0, 13.0],
			],
			"anqi_kick": [
				[{T_TORSO: 88.0, T_ARM_FU: -70.0, T_ARM_FL: 80.0, T_ARM_BU: -100.0, T_ARM_BL: -70.0, T_LEG_FU: -74.0, T_LEG_FL: -84.0, T_LEG_BU: -112.0, T_LEG_BL: -108.0}, 0.20],
				[{T_TORSO: 92.0, T_ARM_FU: -70.0, T_ARM_FL: 80.0, T_ARM_BU: -100.0, T_ARM_BL: -70.0, T_LEG_FU: 20.0, T_LEG_FL: -70.0, T_LEG_BU: -110.0, T_LEG_BL: -106.0}, 0.18],
				[{T_TORSO: 100.0, T_ARM_FU: -70.0, T_ARM_FL: 80.0, T_ARM_BU: -100.0, T_ARM_BL: -70.0, T_LEG_FU: 32.0, T_LEG_FL: 0.0, T_LEG_BU: -108.0, T_LEG_BL: -95.0}, 0.75, 280.0, 22.0],
			],
			# v57 补：普攻表里暗器的第二招是通用的"横扫"（run_state.MOVE_TABLE["anqi"]），
			#   动作表里没有 → 会退回第一招。暗器的"横扫"＝**反手一片撒出去**，不是拿杆子扫。
			"sweep": [
				[{T_TORSO: 104.0, T_ARM_FU: -126.0, T_ARM_FL: -164.0, T_ARM_BU: -74.0, T_ARM_BL: -108.0, T_LEG_FU: -54.0, T_LEG_FL: -116.0, T_LEG_BU: -116.0, T_LEG_BL: -74.0}, 0.30],
				[{T_TORSO: 72.0, T_ARM_FU: 46.0, T_ARM_FL: 154.0, T_ARM_BU: -70.0, T_ARM_BL: -46.0, T_LEG_FU: -64.0, T_LEG_FL: -100.0, T_LEG_BU: -118.0, T_LEG_BL: -84.0}, 0.78, 150.0, 18.0],
			],
		},
		"fist": {
			"fist_punch": [
				[{T_TORSO: 92.0, T_ARM_FU: -62.0, T_ARM_FL: -138.0, T_ARM_BU: -58.0, T_ARM_BL: -138.0, T_LEG_FU: -70.0, T_LEG_FL: -86.0, T_LEG_BU: -110.0, T_LEG_BL: -100.0}, 0.24],
				[{T_TORSO: 78.0, T_ARM_FU: 0.0, T_ARM_FL: 0.0, T_ARM_BU: -56.0, T_ARM_BL: -136.0, T_LEG_FU: -58.0, T_LEG_FL: -62.0, T_LEG_BU: -142.0, T_LEG_BL: -100.0}, 0.45, 560.0, 33.0],
			],
			"fist_combo": [
				[{T_TORSO: 88.0, T_ARM_FU: -20.0, T_ARM_FL: -10.0, T_ARM_BU: -55.0, T_ARM_BL: -135.0, T_LEG_FU: -70.0, T_LEG_FL: -82.0, T_LEG_BU: -100.0, T_LEG_BL: -92.0}, 0.18],
				[{T_TORSO: 82.0, T_ARM_FU: 2.0, T_ARM_FL: 0.0, T_ARM_BU: -58.0, T_ARM_BL: -138.0}, 0.10, 620.0, 36.0],
				[{T_TORSO: 86.0, T_ARM_FU: -60.0, T_ARM_FL: -140.0, T_ARM_BU: -2.0, T_ARM_BL: 0.0}, 0.10, 620.0, 36.0],
				[{T_TORSO: 82.0, T_ARM_FU: 2.0, T_ARM_FL: 0.0, T_ARM_BU: -58.0, T_ARM_BL: -138.0}, 0.10, 620.0, 36.0],
				[{T_TORSO: 86.0, T_ARM_FU: -60.0, T_ARM_FL: -140.0, T_ARM_BU: -2.0, T_ARM_BL: 0.0}, 0.10, 620.0, 36.0],
				[{T_TORSO: 78.0, T_ARM_FU: 2.0, T_ARM_FL: 0.0, T_ARM_BU: -56.0, T_ARM_BL: -136.0, T_LEG_FU: -60.0, T_LEG_FL: -66.0, T_LEG_BU: -134.0, T_LEG_BL: -100.0}, 0.40, 620.0, 36.0],
			],
			"fist_kick": [
				[{T_TORSO: 90.0, T_ARM_FU: -30.0, T_ARM_FL: -12.0, T_ARM_BU: -70.0, T_ARM_BL: -125.0, T_LEG_FU: -70.0, T_LEG_FL: -88.0, T_LEG_BU: -112.0, T_LEG_BL: -108.0}, 0.20],
				[{T_TORSO: 90.0, T_ARM_FU: -30.0, T_ARM_FL: -12.0, T_ARM_BU: -70.0, T_ARM_BL: -125.0, T_LEG_FU: 20.0, T_LEG_FL: -70.0, T_LEG_BU: -108.0, T_LEG_BL: -104.0}, 0.16],
				[{T_TORSO: 100.0, T_ARM_FU: -26.0, T_ARM_FL: -10.0, T_ARM_BU: -66.0, T_ARM_BL: -120.0, T_LEG_FU: 30.0, T_LEG_FL: 0.0, T_LEG_BU: -110.0, T_LEG_BL: -96.0}, 0.65, 300.0, 23.0],
			],
			# v57 补：普攻表里有"推掌"，动作表里缺（会退回直拳）。推掌＝掌根前送，收得比直拳慢。
			"fist_palm": [
				[{T_TORSO: 94.0, T_ARM_FU: -34.0, T_ARM_FL: -96.0, T_ARM_BU: -52.0, T_ARM_BL: -132.0, T_LEG_FU: -72.0, T_LEG_FL: -84.0, T_LEG_BU: -108.0, T_LEG_BL: -98.0}, 0.22],
				[{T_TORSO: 74.0, T_ARM_FU: 10.0, T_ARM_FL: 8.0, T_ARM_BU: -60.0, T_ARM_BL: -128.0, T_LEG_FU: -56.0, T_LEG_FL: -58.0, T_LEG_BU: -140.0, T_LEG_BL: -102.0}, 0.62, 480.0, 30.0],
			],
		},
	}

# 收招（五套分段收势）
# 每段 = [姿势, 定格秒数, 可选 true = 这段走完把武器归位（下一帧起不再握在手里）]
static func end_seq(weapon: String) -> Array:
	match weapon:
		"dual":
			return [
				[{T_TORSO: 88.0, T_ARM_FU: 62.0, T_ARM_FL: 34.0, T_ARM_BU: 68.0, T_ARM_BL: 40.0}, 0.35],
				[{T_TORSO: 86.0, T_ARM_FU: 6.0, T_ARM_FL: -56.0, T_ARM_BU: -6.0, T_ARM_BL: -66.0}, 0.28],
				[{T_TORSO: 84.0, T_ARM_FU: -46.0, T_ARM_FL: -86.0, T_ARM_BU: -88.0, T_ARM_BL: -76.0}, 0.26],
			]
		"dagger":
			return [
				[{T_TORSO: 94.0, T_ARM_FU: -100.0, T_ARM_FL: -150.0, T_ARM_BU: -60.0, T_ARM_BL: -128.0}, 0.42],
				[{T_TORSO: 91.0, T_ARM_FU: -70.0, T_ARM_FL: -62.0, T_ARM_BU: -62.0, T_ARM_BL: -130.0}, 0.30],
			]
		"spear":
			return [
				[{T_TORSO: 90.0, T_ARM_FU: -28.0, T_ARM_FL: 80.0, T_ARM_BU: -104.0, T_ARM_BL: -80.0}, 0.40, true],
				[{T_TORSO: 88.0, T_ARM_FU: -40.0, T_ARM_FL: -70.0, T_ARM_BU: -100.0, T_ARM_BL: -75.0}, 0.32],
			]
		"anqi":
			# v57：暗器收招——手上东西收进腰囊（跟长枪那种"把杆子竖回身侧"不是一回事）
			return [
				[{T_TORSO: 90.0, T_ARM_FU: -46.0, T_ARM_FL: 62.0, T_ARM_BU: -92.0, T_ARM_BL: -84.0}, 0.34, true],
				[{T_TORSO: 88.0, T_ARM_FU: -58.0, T_ARM_FL: -18.0, T_ARM_BU: -96.0, T_ARM_BL: -78.0}, 0.28],
			]
		"fist":
			return [
				[{T_TORSO: 90.0, T_ARM_FU: -58.0, T_ARM_FL: 112.0, T_ARM_BU: -54.0, T_ARM_BL: 116.0}, 0.45],
				[{T_TORSO: 89.0, T_ARM_FU: -22.0, T_ARM_FL: -16.0, T_ARM_BU: -52.0, T_ARM_BL: -132.0}, 0.28],
			]
		_:
			return [
				[{T_TORSO: 91.0, T_ARM_FU: 6.0, T_ARM_FL: 64.0, T_ARM_BU: -106.0, T_ARM_BL: -92.0}, 0.35],
				[{T_TORSO: 88.0, T_ARM_FU: -66.0, T_ARM_FL: -146.0, T_ARM_BU: -108.0, T_ARM_BL: -94.0}, 0.40, true],
				[{T_TORSO: 86.0, T_ARM_FU: -74.0, T_ARM_FL: -116.0, T_ARM_BU: -110.0, T_ARM_BL: -95.0}, 0.30],
			]
