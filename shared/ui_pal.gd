extends RefCounted
# 共享配色（三页同一套）
const FONT := preload("res://fonts/ink.ttf")
const PAPER := Color(0.949, 0.929, 0.886)
const PAPER_HI := Color(0.980, 0.969, 0.937)
const INK := Color(0.133, 0.129, 0.149)
const DIM := Color(0.459, 0.412, 0.361)
const GOLD := Color(0.780, 0.580, 0.220)
const GOLD_HI := Color(0.886, 0.718, 0.412)
const SEAL := Color(0.549, 0.200, 0.122)
const DARK := Color(0.086, 0.075, 0.067)
const DARK2 := Color(0.180, 0.157, 0.129)
const LINE := Color(0.839, 0.784, 0.690)
const RED := Color(0.784, 0.231, 0.169)
const GREEN := Color(0.235, 0.478, 0.290)
const QUALITY := [
	Color(0.541, 0.478, 0.380),
	Color(0.310, 0.478, 0.290),
	Color(0.180, 0.420, 0.451),
	Color(0.420, 0.290, 0.478),
	Color(0.722, 0.529, 0.161),
]
static func quality(i: int) -> Color:
	return QUALITY[clampi(i - 1, 0, 4)]
