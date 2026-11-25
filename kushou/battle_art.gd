extends RefCounted
# ============================================================
# kushou/battle_art.gd —— 战斗美术资源路径表（从 battle_ui.gd 抽出）
#
#   只放「名字 → 资源路径」的约定，不加载、不缓存：
#   加载与缓存仍在 battle_ui（_entry_texture / _entry_art），行为不变。
# ============================================================

const FOE_ART := {
	"狱狼": "yulang", "疯牛": "fengniu", "毒蝎": "duxie", "牢鼠": "laoshu",
	"钱怪": "qian", "晶怪": "jing", "书怪": "shu", "宝箱大怪": "baoxiang", "挑战匪首": "boss",
	"看门恶犬": "kanmen_quan", "铁背苍狼": "tiebei_lang", "毒牙蟒": "duya_mang", "石甲巨猿": "shijia_yuan",
	"双头狮": "shuangtou_shi", "独眼狱卒": "duyan_yuzu", "火尾狐妖": "huowei_hu", "赤焰蛟": "chiyan_jiao",
	"场主亲养·狴犴": "bian", "血手判官": "xueshou_panguan", "困兽之主": "kunshou_zhu",
	"幽冥判官": "youming_panguan", "九幽魔君": "jiuyou_mojun", "血海罗刹": "xuehai_luocha",
	"万蛊虫母": "wanqu_chongmu", "困兽·终焉": "kunshou_zhongyan",
}
const FOE_FRAME_PATH := {
	"狱狼": "yulang", "石甲巨猿": "shijia_yuan", "看门恶犬": "kanmen_quan_v1",
	"铁背苍狼": "tiebei_lang_v1", "毒牙蟒": "duya_mang_v1",
	"双头狮": "shuangtou_shi_v1", "独眼狱卒": "duyan_yuzu_v1",
	"火尾狐妖": "huowei_hu_v1", "赤焰蛟": "chiyan_jiao_v1",
	"山匪弓手": "archer", "符杖术士": "talisman_mage",
	"钱怪": "challenge_coin_v1", "晶怪": "challenge_crystal_v1", "书怪": "challenge_scroll_v1",
	"宝箱大怪": "challenge_mimic", "挑战匪首": "challenge_chief",
	"困兽·终焉": FINAL_BEAST_FRAME_ID,
}
const CROWD_FRAME_PATH := {"山匪": "crowd_bandit", "山匪弓手": "crowd_archer", "符杖术士": "crowd_mage"}

const HERO_FRAMES_PATH := "res://assets/char/player_battle_frames.png"
const HERO_SKILL_FRAMES_PATH := "res://assets/char/player_skill_poses_v2.png"
const HERO_SKILL_ROWS := {"chenshi": 0, "liuqingqing": 1, "qingluan": 2, "gundilong": 3, "xiaoqier": 4}
const BATTLE_FRAMES_PATH := "res://assets/art/fx/battle_bursts_v1.png"
const SKILL_FRAMES_PATH := "res://assets/art/fx/skill_bursts_v1.png"
const DRAGON_FRAMES_PATH := "res://assets/gen/allies/river_dragon.png"
const DRAGON_WAVE_PATH := "res://assets/art/fx/dragon_wave_v1.png"
const CURIO_DETAIL_FRAME_PATH := "res://assets/ui/detail_frame.png"
const CURIO_DETAIL_ICON_PATH := "res://assets/gen/icons/curio_%s.png"
const FINAL_BEAST_FRAME_ID := "kunshou_zhongyan_v1"

static func foe_art_path(key: String) -> String:
	return "res://assets/gen/enemies/foe_%s.png" % key
