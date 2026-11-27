extends RefCounted
# 批次20：测试入口在任何读档/改档之前先验证隔离目录，防止在正式工程或半配置工程里跑。
static func expected_marker() -> String:
	var res := ProjectSettings.globalize_path("res://").trim_suffix("/").replace("\\", "/")
	var run_id := res.get_base_dir().get_file()
	return "wuxia-audits/" + run_id + "/wuxia-regression"

static func verify() -> String:
	var expected := expected_marker()
	var marker := str(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	if marker != expected:
		return "隔离标记不符：实际 '" + marker + "'，期望 '" + expected + "'"
	var user := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
	if not user.ends_with("/" + expected):
		return "user:// 目录不符：实际 '" + user + "'，期望以 '" + expected + "' 结尾"
	return ""
