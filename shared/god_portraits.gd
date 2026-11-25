extends RefCounted

const PATHS := {
	"zl": "res://assets/gen/qingshen/portrait_zl.jpg",
	"cuisanniang": "res://assets/gen/qingshen/portrait_cuisanniang.jpg",
	"jicanghai": "res://assets/gen/qingshen/portrait_jicanghai.jpg",
	"zhujue": "res://assets/gen/qingshen/portrait_zhujue_ink_v3.webp",
	"chenshi": "res://assets/gen/qingshen/portrait_chenshi_ink_v2.webp",
	"liuqingqing": "res://assets/gen/qingshen/portrait_liuqingqing_ink_v1.png",
	"xiaoqier": "res://assets/gen/qingshen/portrait_xiaoqier_ink_v2.webp",
	"gundilong": "res://assets/gen/qingshen/portrait_gundilong_ink_v2.webp",
	"qingluan": "res://assets/gen/qingshen/portrait_qingluan_ink_v2.webp",
	"mingzhu": "res://assets/gen/qingshen/portrait_mingzhu_ink_v2.webp",
	"zhiyuan": "res://assets/gen/qingshen/portrait_zhiyuan.jpg",
}

static func path_for(aid: String) -> String:
	return str(PATHS.get(aid, ""))
