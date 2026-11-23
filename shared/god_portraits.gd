extends RefCounted

const PATHS := {
	"zl": "res://assets/gen/qingshen/portrait_zl.jpg",
	"cuisanniang": "res://assets/gen/qingshen/portrait_cuisanniang.jpg",
	"jicanghai": "res://assets/gen/qingshen/portrait_jicanghai.jpg",
	"zhujue": "res://assets/gen/qingshen/portrait_zhujue.jpg",
	"chenshi": "res://assets/gen/qingshen/portrait_chenshi.jpg",
	"liuqingqing": "res://assets/gen/qingshen/portrait_liuqingqing_ink_v1.png",
	"xiaoqier": "res://assets/gen/qingshen/portrait_xiaoqier.jpg",
	"gundilong": "res://assets/gen/qingshen/portrait_gundilong.jpg",
	"qingluan": "res://assets/gen/qingshen/portrait_qingluan.jpg",
	"mingzhu": "res://assets/gen/qingshen/portrait_mingzhu.jpg",
	"zhiyuan": "res://assets/gen/qingshen/portrait_zhiyuan.jpg",
}

static func path_for(aid: String) -> String:
	return str(PATHS.get(aid, ""))
