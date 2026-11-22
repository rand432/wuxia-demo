extends Control
# ============================================================
# kushou/battle_ui.gd 鈥斺€?鏂版垬鏂楃晫闈紙鎸?v31 鑽夊浘锛?#   鐙珛鍦烘櫙锛氬厛璺戦€氬竷灞€/浜や簰锛屽啀鎺ヨ繘鍏冲崱娴佺▼銆?#   720脳1280锛氶《鏍?0..80 / 鎴樺満 150..870 / 鍗＄粍 880..1050 / 搴曟爮 1076..1280
#   鎶藉崱椤垫棤澶栨銆佷笉鏆傚仠锛涗笁寮犲崱妗嗘诞鍦ㄦ垬鍦轰笂銆?# ============================================================

const W := 720.0
const H := 1280.0
const FONT := preload("res://fonts/ink.ttf")
const PLAYER_TEX := preload("res://assets/char/player_q.png")
const BattleCore := preload("res://kushou/kushou_battle.gd")
const TokenActor := preload("res://kushou/token_actor.gd")
const CardData := preload("res://kushou/card_data.gd")
const LevelState := preload("res://shared/level_state.gd")
const TutorialOverlay := preload("res://kushou/tutorial_overlay.gd")
const AncestorData := preload("res://kushou/ancestor_data.gd")
const AttackFx := preload("res://kushou/attack_fx.gd")
const BlackMarket := preload("res://kushou/black_market.gd")
const MenuUI := preload("res://shared/ui_kit.gd")

# 鎬墿绔嬬粯锛氬悕瀛?鈫?assets/gen/enemies/foe_<key>.png锛涙病鏈夊氨鍥為€€鏃х殑鍦嗙墝 + 涓€涓瓧
const FOE_ART := {
	"鐙辩嫾": "yulang", "鐤墰": "fengniu", "姣掕潕": "duxie", "鐗㈤紶": "laoshu",
	"閽辨€?: "qian", "鏅舵€?: "jing", "涔︽€?: "shu", "瀹濈澶ф€?: "baoxiang", "鎸戞垬 boss": "boss",
	"鐪嬮棬鎭剁姮": "kanmen_quan", "閾佽儗鑻嶇嫾": "tiebei_lang", "姣掔墮锜?: "duya_mang", "鐭崇敳宸ㄧ尶": "shijia_yuan",
	"鍙屽ご鐙?: "shuangtou_shi", "鐙溂鐙卞崚": "duyan_yuzu", "鐏熬鐙愬": "huowei_hu", "璧ょ劙铔?: "chiyan_jiao",
	"鍦轰富浜插吇路鐙寸姶": "bian", "琛€鎵嬪垽瀹?: "xueshou_panguan", "鍥板吔涔嬩富": "kunshou_zhu",
	"骞藉啣鍒ゅ畼": "youming_panguan", "涔濆菇榄斿悰": "jiuyou_mojun", "琛€娴风綏鍒?: "xuehai_luocha",
	"涓囪泭铏瘝": "wanqu_chongmu", "鍥板吔路缁堢剦": "kunshou_zhongyan",
}
var _foe_tex_cache := {}

func _foe_art(nm: String) -> Texture2D:
	var key := str(FOE_ART.get(nm, ""))
	if key == "":
		return null
	if _foe_tex_cache.has(key):
		return _foe_tex_cache[key] as Texture2D
	var p := "res://assets/gen/enemies/foe_%s.png" % key
	var t: Texture2D = null
	if ResourceLoader.exists(p):
		t = load(p) as Texture2D
	_foe_tex_cache[key] = t
	return t

const INK := Color(0.13, 0.12, 0.11)
const PAPER := Color(0.93, 0.90, 0.82)
const PAPER_HI := Color(0.97, 0.95, 0.89)
const GOLD := Color(0.85, 0.66, 0.23)
const SEAL := Color(0.66, 0.22, 0.15)
const DIM := Color(0.42, 0.38, 0.32)
const LIGHT := Color(0.91, 0.87, 0.78)
const QUALITY_COLORS := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]

var _page := 0
var _draw_open := false
var _exit_open := false
var _draw_layer: Control
var _chal_layer: Control
var _detail_layer: Control
var _detail_name: Label
var _detail_sub: Label
var _detail_line: Label
var _detail_card: Panel
var _detail_art: TextureRect
var _detail_effect: Label
var _detail_combo: Label
var _detail_combo_text: Label
var _detail_pips: Array = []
var _deck_count_lb: Label
# 鎬昏椤碉細椤堕儴鍒嗙被閽紙鍗＄粍 / 瀹濈墿 / 缁勫悎锛?var _tot_tabs: Array = []
var _tot_keys: Array = ["bond", "combo"]
var _tot_tab := "combo"          # 榛樿鍏堢湅銆岀粍鍚堛€嶏紙鐜╁鏈€鍏冲績鐨勫凡鍚堟垚鍒楄〃锛?var _tot_btn: Button = null
var _tot_hint_shown := false     # 鏈眬鏄惁宸茬粡鎻愮ず杩囥€岀偣鎬昏鐪嬬粍鍚堛€?var _devoured: Array = []          # 琚悶鍣殑鐐悕鍗曞崱锛堢粍鍚堥〉閲屼篃鏄剧ず锛?var _combo_boost := {}             # 缁勫悎鍚?鈫?鏁堟灉澧炲箙锛堢緛缁婃崲鏉ョ殑锛屾案涔呮湁鏁堬級
var _combo_frac := {}              # 鏁存暟绫荤粍鍚堢殑灏忔暟浣欓锛?40% 鏀掍袱娆＄粰涓€娆★級
var _sys_combos := {}              # 鏅€氬崱缁勫悎鍚嶉泦鍚堬紙璺熷浼犵粍鍚堥噸鍚嶆椂锛屾寜鏅€氬崱绠楋級
var _tot_deck_root: Control = null
var _tot_bond_root: Control = null
var _exit_layer: Control
var _toast_lb: RichTextLabel
var _toast_seq := 0
var _cards: Array = []
var _card_db := {}
var _set_cards := {}
var _pool: Array = []
var _acquired := {}
# v2 娉㈡ / 缁忛獙 / 鍗囩骇锛堟尝娆℃帹杩?+ 鍗囩骇鐐逛寒璇风锛?const MAX_WAVE := 5
var _max_wave := 5
var _chips := {}
var _chal_btn = null
var _tut = null
var _boss_spawned := false
var _market_tile = null
var _draw_tile = null
var _lv := 1
var _exp := 0
var _exp_need := 100
var _draw_charge := 0          # 绱Н鐨勮绁炴鏁帮紙鍗囩骇 +1锛?var _run_cleared := false
var _lv_lb: Label = null
var _exp_lb: Label = null
var _exp_bar: Panel = null
var _mate_tile = null

# ============================================================
# ---------------- 寮哄寲锛坴6锛?---------------
#   鐢ㄦ埛锛?寮哄寲寰堢畝鍗?娑堣€楁枃閽?瀵硅嚜韬繘琛屽己鍖?姣忓己鍖栧崄绾?鍗＄墝涓夐€変竴 鑾峰緱杩涢樁鐨勬暟鍊煎鍔?
#   路 鐐逛竴娆★蓟寮哄寲锛斤細鎵ｆ枃閽?鈫?鑷韩 锛嬫敾鍑?/ 锛嬫皵琛€涓婇檺 / 锛嬫姢鐢?#     鈿?姘旇鎸?*姣斾緥**璺熸定锛堣€佸潙锛氬己鍖栦竴涓嬪氨婊¤ 鈫?瑙?kushou_battle.setup 鐨勬敞閲婏級
#   路 绗?10 / 20 / 30鈥?绾э細寮逛笁閫変竴锛堝搧闃堕殢杞鍗囷細鑹啋鐜勨啋鍦扳啋澶╋級锛岄€変竴寮狅紝姘镐箙鏁板€艰繘闃?#   路 鍏充簡娌￠€変笉瑕佺揣锛氬啀鐐癸蓟寮哄寲锛戒細鎶婇偅涓€鎵嬮噸鏂版墦寮€锛堜笉閲嶅鎵ｉ挶锛?# ============================================================
const STR_COST_BASE := 30          # 绗竴娆″己鍖栫殑浠烽挶
const STR_COST_STEP := 12          # 姣忓崌涓€绾ц吹 12锛堝崄绾у悎璁?840 鏂囬挶 鈮?涓夊垎閽燂級
const STR_PER_ATK := 1.0           # 姣忕骇锛氭敾鍑?+1
const STR_PER_HP := 10.0           # 姣忕骇锛氭皵琛€涓婇檺 +10
const STR_PER_CUT := 0.003         # 姣忕骇锛氭姢鐢?+0.3%
const STR_EVERY := 10              # 姣?10 绾х粰涓€娆′笁閫変竴
# 鏂囬挶鏉ヨ矾锛氭潃鎬簳钖?+ 姣忔尝鍔犳垚 + 娓呮尝濂栧姳锛堜笉璧?core 鐨?coin_drop 涔熻兘鏀掗挶锛?const WEN_KILL_BASE := 12
const WEN_KILL_WAVE := 3
const WEN_WAVE_CLEAR := 60
var _str_lv := 0
var _l1_attr_shown := false
var _l1_aug_shown := false
var _l1_yuhu_shown := false
var _l5_mate_shown := false
var _str_round := 0
var _str_pending := false
var _str_layer: Control = null
var _str_tile = null
# 杩涢樁椤碉紙鍜屾娊鍗″悓涓€濂楋細涓夊紶鍗℃诞鍦ㄦ垬鍦猴紝涓嶉伄涓嶆殏鍋滐紱鍙湁锛诲埛鏂?路 娆℃暟锛藉拰锛婚殣钘忥冀锛?var _aug_cards: Array = []
var _aug_reroll := 3          # 鍒锋柊娆℃暟锛堝紑灞€ 3 娆★紝姣忚繘闃朵竴杞?+1锛?var _aug_rolled_lv := -1      # 杩欎竴鎵嬫槸涓虹鍑犵骇鎺风殑锛堝叧浜嗗啀鐐逛笉鐧藉埛锛?var _aug_refresh_btn: Button = null
var _str_ban_lb: Label = null

# ============================================================
# ---------------- 瀹濈墿锛坴8锛?---------------
#   鐢ㄦ埛锛?瀹濈墿鐨勬娊鍙栫晫闈篃鍜屾娊鍗′竴鑷?銆愬埛鏂版鏁?闅愯棌/鏀惧純銆愬鍔犱竴娆″埛鏂?瀵?杩欎釜杩涢樁涔熻銆戙€?
#   路 姣忔竻涓€娉?+1 娆″疂鐗╂満浼氾紱寮€涓€娆′笁寮狅紝鎸戜竴寮犲甫璧?#   路 鏈€澶氬甫 3 浠讹紱鍝佽川闅忔尝鏁板崌锛?-2 鑹?/ 3 鐜?/ 4 鍦?/ 6+ 澶╋級
#   路 涓変釜鎸夐挳锛氬埛鏂?路 N 娆★紙娆℃暟鍨嬶級/ 闅愯棌锛堟敹璧锋潵锛岃繖涓€鎵嬭繕鍦級/ 鏀惧純锛?1 鍒锋柊锛岃繖鎵嬩綔搴燂級
#   路 锛绘斁寮冿冀杩涢樁椤典篃鏈夛細鏀惧純杩欎竴杞繘闃讹紝鎹?1 娆″埛鏂?# ============================================================
const TREA_CHARGE_START := 1
var _bonds: Array = []          # 韬笂鐨勭緛缁婏紙鍑戦綈灏辨秷鑰楁帀锛屾墍浠ヤ笉璁句笂闄愶級
var _bond_unlocked := {}        # 宸茶В閿佺殑缇佺粖鍚嶏紙鍙湁杩欎簺浼氬嚭鐜板湪涓夐€変竴閲岋級
var _bond_taken := {}           # 宸茬粡缁撹繃鐨勭緛缁婂悕锛堜笉閲嶅鍑虹幇锛?var _crystal_lock := false      # 銆屽€惧泭銆嶄箣鍚庯細鐏垫櫠鏀跺叆褰掗浂
var _rare_buffs: Array = []     # 闄愭椂 buff锛歿raw_atk, t}锛岃褰曞睘鎬у骞呭墠鐨勫浐瀹氭敾鍑汇€?var _bonds_done := 0            # 杩欎竴灞€宸茬粡鎴愯繃鍑犲紶
var _trea_charge := TREA_CHARGE_START
var _trea_reroll := 3
var _trea_pending := false
var _trea_layer: Control = null
var _trea_cards: Array = []
var _trea_refresh_btn: Button = null
var _trea_tile = null
var _exp_pct := 0.0
# v1 璇风路瀹朵紶鍗★細宸茶鍒扮殑绁栧畻锛坅id -> 褰撳墠鍙敹闆嗘。锛夛紡宸叉縺娲荤殑瀹朵紶缁勫悎
var _ancestors := {}
var _ancestor_combos: Array = []
# v4 缁勫悎鍔犳垚钀藉湴锛歛id -> {dmg_pct, cd_pct, mp_flat, para_s, para_amp}锛涘厓绱犲叡浜崟鐙
var _anc_mod := {}
var _elem_mod := {}
# v4 鐐崱锛氭幏涓紙杩涙睜锛夛紡宸插悶锛堜竴灞€涓€娆★級
var _shiny_rolled := {}
var _shiny_used := {}
var _equip_vuln := 0.0               # 榛戝競鎷垮埌瑁呭/绁炲櫒鍚庯紝鍋峰伔缁欐€殑鏄撲激
var _family_shiny_ready := false     # 绗簲鍏筹細绗簩缁勫浼犲悎鎴愬悗锛屼笅涓€鎵嬪繀鍑虹偒褰?var _family_shiny_done := false
# v5 鍙敜鐗?var _minions: Array = []
# v6 鍚炴捣锛堝磾涓夊鐐崱锛夛細铔熼緳姘镐箙 + 姣忕/鍑绘潃 鍙犲睘鎬?var _swallow_sea := false
var _ss_pct := 0.0
var _ss_kills := 0
# v7 鐏肩儳 / 寮曠噧 / 鐒氬ぉ
var _burn_unlimited := false     # 鐒氬ぉ锛氱伡鐑у眰鏁颁笉琛板噺
var _ignite_bonus := 0           # 寮曠噧鐩爣鍔犳垚锛堜笁妗?/ 鐒氬ぉ鍚炲櫖锛?var _fentian := false
var _ft_kills := 0
# v8 鍥炴疆锛堟垚闀跨郴褰╄泲锛夛細涓€灞€涓€娆★紝娉㈡暟鍥為€€ 5
var _backwash_done := false
# 涓昏琚姩锛氬鐩爣 / 杩藉嚮 / 鍓戞皵
var _hero_passive := {}
# v11 涓囧垉锛堣嫃闈掗妇鐐崱锛夛細绌块€忔棤涓婇檺 路 姣忕偣绌块€?+1 鍒€ 路 姣?3 娆″洖绋?+1 绌块€?var _wanren := false
var _wanren_pierce := 0
var _wanren_volleys := 0
# v9 鍓戦瓌锛堜富瑙掔偒鍗★級锛氳繛鍑诲悓涓€鐩爣娑ㄦ敾閫燂紙鎹㈢洰鏍囬噸缃級+ 鍓戞皵杩涘寲涓囧墤褰掑畻
var _hero_jianpo := false
var _jpo_tid := -1
var _jpo_stacks := 0
# 鏀婚€熺‖涓婇檺锛氬彧闃插崱锛?/aspd 绉掍竴涓嬶級锛涙暟鍊间笂銆屽墤榄勩€嶆湰韬笉灏侀《
const MAX_ASPD := 5.0
# v10 鎶藉彇鍔熻兘鏈仛 鈫?澶╁搧绁栧畻鏆傛椂灏佸嵃锛堜笉杩涗笁閫変竴锛?const SEALED := ["zl", "cuisanniang", "jicanghai"]   # 鏈€寮虹殑涓変綅灏佸嵃锛涘叾浣欏叚浣嶅彲鎸夊叧瑙ｉ攣
var _combined: Array = []
var _stats := {"atk": 0.0, "def": 0.0, "hp": 0.0}
# v6锛氬崱姹犮€岄槻寰°€嶆崲绠楁垚鍥哄畾鍑忓厤鐨勭郴鏁帮紙1 鐐归槻寰?= 3%锛屾寜 100 浼ょ瓑鏁堝榻愭棫鎵嬫劅锛?const EquipmentStats := preload("res://shared/equipment_stats.gd")
const DEF_CARD_TO_RED := EquipmentStats.DEF_TO_RED
var _gold_pct := 0.0
var _crystal_pct := 0.0
# v13 缇?闄?涓ょ郴锛氭瘡娉㈠畾棰濆姞鎴?路 鍏ㄥ眬闅惧害 路 鎬墿绫诲瀷鏀剁泭
var _wave_extra := 0
var _diff_pct := 0.0
var _coin_count_extra := 0
var _crystal_count_extra := 0
var _treasure_pct := 0.0
var _boss_pct := 0.0
# v14 璐紙缁忔祹绾匡級锛氬嚮鏉€鏀剁泭鍔犳垚 + 琚悶鍣崱锛堟晥鏋?杩涘害淇濈暀锛?var _kill_pct := 0.0
# v15 缁忛獙绾匡細鏉€鎬暟鎸夌櫨鍒嗘瘮鏀惧ぇ锛堢粡楠?+ 鎵€鏈夋寜鍑绘潃鎴愰暱鐨勬満鍒朵竴璧峰悆锛?var _killnum_pct := 0.0
var _virtual_cards: Array = []
var _last_wave := 1
var _attack_count := 0
var _hit_count := 0
var _combo_t := 0.0
var _combined_layer: Control
var _combined_icons: Control
var _combined_detail: Control
var _toast_queue: Array = []
var _toast_busy := false
var _page_lb: Label
var _slots: Array = []
var _draw_cards: Array = []
var _enemies: Array = []
var _core = null
var _bm = null
var _coin_lb: Label
var _kill_lb: Label
var _life_lb: Label
var _life := 100          # 褰撳眬鐢熷懡锛氫富瑙掑€掍笅涓嶅啀鐩存帴缁撴潫锛屾寜鍓╀綑鎬墸鍛?var _run_over := false            # 鏈眬宸茬粨绠楋紙鍛藉敖 / 閫氬叧锛?var _skip_reward_wave := false    # 杩欎竴娉㈡墦杈撲簡锛氳繃娉絾涓嶇粰濂栧姳
var _run_time := 0.0              # 鏈眬瀛樻椿鏃堕棿
var _chal_cd: Array = [0.0, 0.0, 0.0, 0.0, 0.0]   # 浜旂鎸戞垬鐨勫喎鍗村墿浣?var _fly_layer = null           # 璧勬簮椋炶灞?var _fly: Array = []
var _pulses: Dictionary = {}   # 璧勬簮鏍艰鍔犻挶鏃剁殑缂╂斁鑴夊啿
var _boss_bar = null           # 棣栭琛€鏉?var _foe_pool: Array = []      # 鎬墿鐗屽璞℃睜锛堢渷鎺夋瘡鍙兘寤?Shader/鑺傜偣鐨勫紑閿€锛?var _recycle_q: Array = []     # 闃典骸鍔ㄧ敾鎾畬鍐嶅洖鏀?var _boss_bar_t := 0.0
var _boss_on := false          # 棣栭鍦ㄥ満鏃剁壒鏁堥檷妗ｏ紙棣栭鎴樺満鏅湰鏉ュ氨閲嶏級
var _flash_rect: ColorRect = null  # 鎶€鑳介噴鏀炬椂鐨勬暣灞忓井闂?var _cast_dtype := ""              # 鏈€杩戜竴娆￠噴鏀剧殑鎶€鑳藉睘鎬э紙鍐冲畾闂厜棰滆壊锛?var _boss_veil: ColorRect = null   # 棣栭鐧诲満锛氬帇鏆?var _boss_spot: Sprite2D = null    # 棣栭鐧诲満锛氳仛鍏?var _boss_name_lb: Label = null    # 棣栭鐧诲満锛氬悕瀛楀ぇ瀛?var _last_combo := 0            # 杩炴潃閲岀▼纰戠敤锛堟瘡 10 杩炵偢涓€鍙ｏ級
var _combo_readout: Control
const PFX_MAX_LIVE := 26          # 鍚屽睆鐗规晥涓婇檺锛堝疄娴?60fps 鏈変綑閲忥紝鏀惧洖 26锛?var _curio_sq = null             # 濂囩墿鏂瑰潡锛堟垬鍦哄彸涓嬶紝涓庢寫鎴樺绉帮級
var _curio_cd := 0.0             # 濂囩墿鍐峰嵈鍓╀綑
var _curio_uses := 0             # 鏈眬鍠濅簡鍑犳锛堣鎯呴〉鏄剧ず锛?var _curio_detail: Control = null
var _rare_taken: Dictionary = {}   # 鎶藉埌杩囩殑绋€鏈夊崟鍗★紙鍏ㄩ儴鍞竴锛?var _wave_lb: Label
var _hp_lb: Label
var _wen := 0
var _kills := 0
var _crystal := 100
var _crystal_lb: Label
var _draw_paid := false
var _draw_anim := false
var _draw_refresh_btn: Button = null
var _hero_token = null
var _foe_tokens := {}
var _no_tokens := false   # 瀵圭収娴嬭瘯鐢細涓嶅垱寤?涓嶆洿鏂版€殑鏈綋
var _no_ui := false       # 瀵圭収娴嬭瘯鐢細涓嶅垱寤?UI 闈㈡澘
var _no_ui2 := false      # 瀵圭収娴嬭瘯鐢細杩炶儗鏅?榛戝競/鏁欏/鍗＄墝鏁版嵁閮戒笉寤?var _foe_seq := 0
# 鏀诲嚮琛ㄧ幇锛圥0锛夛細鍚庡眰鍓?寮э紝鍓嶅眰鐧借竟娣＄孩/浼ゅ瀛楋紱椤堕儴琛€鏉℃槸涓昏鍞竴琛€鏉?const FIELD_POS := Vector2(8, 150)
var _fx_back: Control = null
var _fx_front: Control = null
var _prev_hero_hp := -1.0
var _hp_fill: Panel = null
var _hero_hit_btn: Button = null
var _hero_name_lb: Label = null

func _ready() -> void:
	GameState.ensure_loaded()
	var _t_ready := Time.get_ticks_usec()
	_max_wave = LevelState.waves()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 17
	theme = th
	if not _no_ui2:
		_init_cards()
		_build_bg()
	if not _no_ui:
		_build_hud()
	_build_field()
	if not _no_ui:
		_build_deck()
		_build_bottom()
		_q_init()
		_build_draw()
	# v6锛氳鑹插睘鎬х粺涓€璧拌缁嗗睘鎬ч〉锛坅ttr_panel锛夛紝鏃?8 琛岀獥涓嶅啀鍒涘缓
	if not _no_ui:
		_build_exit()
		_build_toast()
		_build_combined()
		_build_god_pick()
		_build_str()
		_build_trea()
	if not _no_ui2:
		_bm = BlackMarket.new()
		_bm.setup(_core, self)
		add_child(_bm)
		_bm.z_index = 40
		_bm.visible = false
		_tut = TutorialOverlay.new()
		add_child(_tut)
	_refresh_deck()
	_apply_level_preview()
	_maybe_level_button_tutorial.call_deferred()
	var fade := ColorRect.new()
	fade.color = Color(0.03, 0.03, 0.04, 1.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.z_index = 200
	add_child(fade)
	var twf := create_tween()
	twf.tween_property(fade, "color:a", 0.0, 0.45)
	twf.tween_callback(func() -> void: fade.queue_free())
	var _el_ready := Time.get_ticks_usec() - _t_ready
	if _el_ready > 50000:
		print("[SLOW] battle_ui ready ", _el_ready / 1000.0, " ms")
	set_process(true)

# 涓婁竴鍏抽閫氱暀涓嬬殑鈥滈涔犫€濓細涓嬩竴鍏冲紑灞€鐢熸晥涓€娆?func _apply_level_preview() -> void:
	var pv := LevelState.take_preview(LevelState.current_level)
	if pv.is_empty():
		return
	if pv.has("crystal"):
		_crystal += int(pv["crystal"])
	if pv.has("wen"):
		_wen += int(pv["wen"])
	if pv.has("god"):
		_draw_charge += int(pv["god"])
	if pv.has("exp_pct"):
		_exp_pct += float(pv["exp_pct"])   # 绗洓鍏抽涔狅細涓嬩竴鍏崇粡楠屽姞鎴?	if pv.has("chal"):
		for i in _chal_cd.size():
			_chal_cd[i] = 0.0
	_update_crystal()
	if _coin_lb != null:
		_coin_lb.text = str(_wen)
	_refresh_level_ui()


# ---------------- 閫氱敤 ----------------
func _panel(rect: Rect2, bg: Color, radius := 8, border := Color(0, 0, 0, 0), bw := 0, parent: Node = null) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(p)
	return p

func _lbl(t: String, pos: Vector2, sz: Vector2, fs: int, col: Color, parent: Node = null, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(l)
	return l

func _btn(t: String, rect: Rect2, fs: int, bg: Color, fg: Color, cb: Callable, parent: Node = null, border := Color(0.85, 0.66, 0.23, 0.55), bw := 1) -> Button:
	var b := Button.new()
	b.text = t
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate()
	hb.bg_color = bg.lightened(0.08)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)
	if cb.is_valid():
		b.pressed.connect(cb)
	(parent if parent != null else self).add_child(b)
	MenuUI.Motion.bind_button(b)
	return b

func _toast(t: String) -> void:
	_toast_queue.append(t)
	if not _toast_busy:
		_toast_next()

func _toast_next() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	var t: String = str(_toast_queue.pop_front())
	if _toast_lb == null:
		_toast_queue.clear()
		_toast_busy = false
		return
	_toast_lb.text = "[center]" + t + "[/center]"
	_toast_lb.visible = true
	_toast_lb.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(_toast_lb, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func() -> void:
		if _toast_lb != null:
			_toast_lb.visible = false
		_toast_busy = false
		_toast_next())

class BgArt extends Control:
	# 鍏冲崱 鈫?鑳屾櫙杞崲锛涙枃浠朵笉瀛樺湪鏃跺洖閫€鍒扮▼搴忕敾鐨勭焊闈?	const BG_LIST := [
		"res://assets/art/bg/bg_village.jpg",
		"res://assets/art/bg/bg_bamboo.jpg",
		"res://assets/art/bg/bg_rain.jpg",
		"res://assets/art/bg/bg_cave.jpg",
		"res://assets/art/bg/bg_snow.jpg",
		"res://assets/art/bg/bg_night_market.jpg",
		"res://assets/art/bg/bg_cliff.jpg",
		"res://assets/art/bg/bg_dungeon.jpg",
	]
	var tex: Texture2D = null
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func setup(idx: int) -> void:
		var p: String = BG_LIST[wrapi(idx, 0, BG_LIST.size())]
		if ResourceLoader.exists(p):
			tex = load(p) as Texture2D
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.93, 0.90, 0.82))
		if tex != null:
			var s := maxf(size.x / float(tex.get_width()), size.y / float(tex.get_height()))
			var w := float(tex.get_width()) * s
			var h := float(tex.get_height()) * s
			draw_texture_rect(tex, Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h), false)
			# 鍘嬬焊鑹诧細涓儴鎴樻枟鍖鸿交銆佷笂涓?UI 鍖洪噸锛屼繚璇佹枃瀛楀彲璇?			draw_rect(Rect2(0, 0, 720, 1280), Color(0.965, 0.945, 0.90, 0.26))
			draw_rect(Rect2(0, 0, 720, 160), Color(0.965, 0.945, 0.90, 0.72))
			draw_rect(Rect2(0, 850, 720, 430), Color(0.965, 0.945, 0.90, 0.80))
			return
		# 绾哥汗/灞?		var pts := [
			Vector2(0, 870), Vector2(90, 730), Vector2(170, 830), Vector2(260, 700),
			Vector2(360, 840), Vector2(470, 710), Vector2(580, 830), Vector2(700, 740),
			Vector2(720, 870)
		]
		draw_polyline(PackedVector2Array(pts), Color(0.52, 0.46, 0.38, 0.30), 2.0, true)
		draw_line(Vector2(0, 870), Vector2(720, 870), Color(0.38, 0.32, 0.24, 0.55), 2.0)
		# 娣″ⅷ鐐?		for i in 6:
			draw_circle(Vector2(60 + i * 118, 200 + (i % 3) * 150), 46.0, Color(0.45, 0.38, 0.30, 0.025))

# ---------------- 鍥炬爣 ----------------
class Ico extends Control:
	var kind := "coin"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		if kind == "dot":
			draw_circle(c, minf(size.x, size.y) * 0.45, Color(0.85, 0.66, 0.23))
			return
		if kind == "coin":
			draw_circle(c, r, Color(0.88, 0.69, 0.29))
			draw_arc(c, r, 0, TAU, 40, Color(0.36, 0.27, 0.12, 0.7), 2.0)
			draw_circle(c, r * 0.30, Color(0.10, 0.09, 0.08))
			draw_rect(Rect2(c - Vector2(r * 0.20, r * 0.20), Vector2(r * 0.40, r * 0.40)), Color(0.10, 0.09, 0.08), false, 3.0)
		elif kind == "heart":
			# 绾㈠績锛堝綋灞€鐢熷懡锛夛細鍙傛暟鏂圭▼鎻忕偣锛屽渾蹇冭惤鍦ㄥ浘鏍囦腑蹇?			var hp := PackedVector2Array()
			for i in 40:
				var t := TAU * float(i) / 40.0
				var hx := 16.0 * pow(sin(t), 3.0)
				var hy := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				hp.append(c + Vector2(hx, -hy) * (r / 17.0))
			draw_colored_polygon(hp, Color(0.80, 0.24, 0.20))
		elif kind == "crystal":
			var pts := PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.72, -r * 0.2), c + Vector2(r * 0.44, r * 0.9),
				c + Vector2(-r * 0.44, r * 0.9), c + Vector2(-r * 0.72, -r * 0.2)
			])
			draw_colored_polygon(pts, Color(0.49, 0.76, 0.85))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.16, 0.31, 0.36, 0.7), 2.0, true)
		else:
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(r * 0.50, -r * 0.50), Color(0.78, 0.35, 0.23), 5.0, true)
			draw_line(c + Vector2(-r * 0.55, -r * 0.55), c + Vector2(r * 0.50, r * 0.50), Color(0.78, 0.35, 0.23), 5.0, true)
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(r * 0.50, -r * 0.50), Color(0.88, 0.69, 0.29), 4.0, true)

class Glyph extends Control:
	var kind := "sword"
	var col := Color(0.13, 0.12, 0.11)
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.40
		if kind == "sword":
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(r * 0.55, -r * 0.55), col, 6.0, true)
			draw_line(c + Vector2(-r * 0.15, r * 0.15), c + Vector2(r * 0.35, -r * 0.35), Color(0.79, 0.64, 0.24), 4.0, true)
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(-r * 0.30, r * 0.30), Color(0.55, 0.18, 0.14), 4.0, true)
		elif kind == "spear":
			draw_line(c + Vector2(-r * 0.6, r * 0.25), c + Vector2(r * 0.45, -r * 0.20), col, 4.0, true)
			var tip := c + Vector2(r * 0.52, -r * 0.25)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-r * 0.18, -r * 0.02), tip + Vector2(-r * 0.12, r * 0.17)]), Color(0.79, 0.64, 0.24))
		else:
			draw_line(c + Vector2(-r * 0.35, r * 0.40), c + Vector2(r * 0.45, -r * 0.40), col, 5.0, true)
			draw_line(c + Vector2(-r * 0.35, -r * 0.40), c + Vector2(r * 0.45, r * 0.40), col, 5.0, true)

class EnemyArt extends Control:
	var r := 30.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, r, Color(0.86, 0.81, 0.70))
		draw_arc(c, r, 0, TAU, 40, Color(0.16, 0.13, 0.10, 0.8), 2.0)
		draw_circle(c + Vector2(-r * 0.28, -r * 0.10), r * 0.07, Color(0.16, 0.13, 0.10, 0.8))
		draw_circle(c + Vector2(r * 0.28, -r * 0.10), r * 0.07, Color(0.16, 0.13, 0.10, 0.8))
		draw_line(c + Vector2(-r * 0.22, r * 0.25), c + Vector2(r * 0.22, r * 0.25), Color(0.16, 0.13, 0.10, 0.55), 1.5, true)

class AvatarArt extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var tex := preload("res://assets/char/player_q.png")
		if tex:
			var s := minf(size.x, size.y) * 0.92
			draw_texture_rect(tex, Rect2(c - Vector2(s * 0.5, s * 0.5), Vector2(s, s)), false)
		draw_arc(c, size.x * 0.50, 0, TAU, 48, Color(0.85, 0.66, 0.23, 0.9), 3.0)


class CardSlot extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal pressed
	var empty := false
	var quality := 3
	var shiny := false
	var art: Texture2D = null
	var idx = 0
	var _back_tex: Texture2D = null
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		if empty:
			var c := Color(0.42, 0.36, 0.28, 0.45)
			if _back_tex == null and ResourceLoader.exists("res://assets/art/cards/card_back.png"):
				_back_tex = load("res://assets/art/cards/card_back.png") as Texture2D
			if _back_tex != null:
				draw_texture_rect(_back_tex, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.92))
				return
			draw_dashed_line(Vector2(2,2), Vector2(size.x-2,2), c, 2.0, 6.0)
			draw_dashed_line(Vector2(size.x-2,2), Vector2(size.x-2,size.y-2), c, 2.0, 6.0)
			draw_dashed_line(Vector2(size.x-2,size.y-2), Vector2(2,size.y-2), c, 2.0, 6.0)
			draw_dashed_line(Vector2(2,size.y-2), Vector2(2,2), c, 2.0, 6.0)
			draw_string(F, size * 0.5 + Vector2(-10, 7), "绌?, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.42,0.36,0.28,0.55))
			return
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.93, 0.86, 0.98)
		sb.set_corner_radius_all(8)
		sb.border_color = QC[clampi(quality-1,0,4)]
		sb.set_border_width_all(5)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if art != null:
			draw_texture_rect(art, Rect2(8, 8, size.x - 16, size.y - 16), false)
		if shiny:
			var cols := [Color(0.85,0.28,0.30), Color(0.93,0.58,0.22), Color(0.90,0.80,0.28),
				Color(0.38,0.70,0.42), Color(0.32,0.62,0.85), Color(0.62,0.42,0.82)]
			for i in 6:
				var sb2 := StyleBoxFlat.new()
				sb2.bg_color = Color(0, 0, 0, 0)
				sb2.set_corner_radius_all(10)
				sb2.border_color = cols[i]
				sb2.set_border_width_all(2)
				draw_style_box(sb2, Rect2(Vector2(-2.0 - float(i) * 2.0, -2.0 - float(i) * 2.0),
					size + Vector2(4.0 + float(i) * 4.0, 4.0 + float(i) * 4.0)))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

class DrawCard extends Control:
	const F := preload("res://fonts/ink.ttf")
	var QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	const CF := preload("res://kushou/card_frame.gd")
	signal picked
	var data: Dictionary = {}
	var progress := 0          # 璇ュ崱鎵€灞炵粍鍚堢殑褰撳墠杩涘害锛堢敱澶栧３鍐欏叆锛?	var _art_rect: TextureRect
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_art_rect = TextureRect.new()
		_art_rect.position = Vector2(40, 52)
		_art_rect.size = Vector2(120, 120)
		_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_art_rect)
	func _draw() -> void:
		if data.is_empty():
			if _art_rect != null:
				_art_rect.visible = false
			return
		if _art_rect != null:
			_art_rect.visible = true
		var q := clampi(int(data.get("quality", 3)) - 1, 0, 4)
		var framed := CF.draw_on(self, int(data.get("quality", 3)), size)
		if framed:
			CF.content_panel(self, Rect2(18, 40, size.x - 36, size.y - 58))
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.96, 0.93, 0.86, 0.99)
			sb.set_corner_radius_all(9)
			sb.border_color = QC[q]
			sb.set_border_width_all(6)
			draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if bool(data.get("shiny", false)):
			# 鐐崱锛氫竷褰╂弿杈圭敱澶栧悜鍐?			var cols := [Color(0.85,0.28,0.30), Color(0.93,0.58,0.22), Color(0.90,0.80,0.28),
				Color(0.38,0.70,0.42), Color(0.32,0.62,0.85), Color(0.62,0.42,0.82)]
			for i in 6:
				var sp := StyleBoxFlat.new()
				sp.bg_color = Color(0, 0, 0, 0)
				sp.set_corner_radius_all(10)
				sp.border_color = cols[i]
				sp.set_border_width_all(2)
				draw_style_box(sp, Rect2(Vector2(-2.0 - float(i) * 2.0, -2.0 - float(i) * 2.0),
					size + Vector2(4.0 + float(i) * 4.0, 4.0 + float(i) * 4.0)))
		CF.title_band(self, Rect2(6, 6, size.x - 12, 30))
		draw_string(F, Vector2(0, 34), str(data.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.14,0.11,0.08))
		var tex := load(str(data.get("art", "")))
		if _art_rect != null:
			_art_rect.texture = tex
		draw_string(F, Vector2(20, 204), str(data.get("own_text", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 21, Color(0.14,0.11,0.08))
		draw_line(Vector2(20, 220), Vector2(size.x - 20, 220), Color(0.5,0.4,0.25,0.35), 1.5)
		if bool(data.get("shiny", false)):
			# 鐐崱锛氫笉鏄剧ず缁勫悎杩涘害锛屾敼鎴愬悶鍣鏄?			draw_string(F, Vector2(20, 240), "杩涘崱缁勫嵆鍚炲敖鍏ㄩ儴瀹朵紶鍗?, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 16, Color(0.42,0.30,0.12))
			draw_string(F, Vector2(20, 264), "姣忓悶涓€寮狅細鐏垫櫠+20 路 鏂囬挶+150", HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 14, Color(0.2,0.16,0.12))
			draw_string(F, Vector2(20, 284), "銆€銆€銆€銆€銆€鎶€鑳戒激瀹?+10%", HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 14, Color(0.2,0.16,0.12))
		else:
			draw_string(F, Vector2(20, 246), str(data.get("combo_name", "")) + " " + str(progress) + "/" + str(data.get("set_size", 0)), HORIZONTAL_ALIGNMENT_LEFT, 140, 18, Color(0.42,0.30,0.12))
			draw_string(F, Vector2(20, 280), str(data.get("trigger", "")) + "锛? + str(data.get("combo_text", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 17, Color(0.2,0.16,0.12))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()


func _build_bg() -> void:
	var bg := BgArt.new()
	bg.size = Vector2(W, H)
	bg.setup(int(LevelState.current_level) - 1)
	add_child(bg)

func _chip(x: float, kind: String, value: String, cap: String) -> Label:
	var box := Control.new()
	box.size = Vector2(720, 80)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	# 鍙鍖哄潡鍗曠嫭涓€涓?Control锛?62脳64锛夛紝鏁欏楂樹寒妗嗗彧妗嗚繖涓€鍧楋紝涓嶄細鎷夋弧鏁磋
	var chip := Control.new()
	chip.position = Vector2(x, 8)
	chip.size = Vector2(162, 64)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(chip)
	_panel(Rect2(0, 0, 162, 64), Color(0.075, 0.068, 0.060, 0.98), 8, Color(0.85, 0.66, 0.23, 0.45), 1, chip)
	var ic := Ico.new()
	ic.kind = kind
	ic.position = Vector2(10, 14)
	ic.size = Vector2(34, 34)
	chip.add_child(ic)
	var vl := _lbl(value, Vector2(48, -4), Vector2(106, 36), 26, Color(0.95, 0.91, 0.83), chip, HORIZONTAL_ALIGNMENT_RIGHT)
	_lbl(cap, Vector2(48, 32), Vector2(106, 20), 16, Color(0.80, 0.75, 0.65), chip, HORIZONTAL_ALIGNMENT_RIGHT)
	# 鐐圭伒鏅?鏂囬挶缁欒鏄庯紙鐏垫櫠涓嶈冻鏃剁洿鎺ユ彁绀烘棤娉曟娊鍗★級
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var hb := Button.new()
	hb.flat = true
	hb.focus_mode = Control.FOCUS_NONE
	hb.position = Vector2.ZERO
	hb.size = Vector2(162, 64)
	hb.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hb.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hb.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hb.pressed.connect(func() -> void: _on_chip_click(cap))
	chip.add_child(hb)
	_chips[cap] = chip
	return vl

func _on_chip_click(cap: String) -> void:
	match cap:
		"鐏垫櫠":
			if _crystal < 20:
				_toast("鐏垫櫠涓嶈冻锛屼笉瓒充互鎶藉崱锛堜竴娆¤ 20锛?)
			else:
				_toast("鐏垫櫠 %d 路 鎶藉崱涓€娆?20" % _crystal)
		"鏂囬挶":
			var cost := _str_cost()
			if _wen < cost:
				_toast("鏂囬挶涓嶈冻锛屾棤娉曞己鍖栵紙闇€瑕?%d锛? % cost)
			else:
				_toast("鏂囬挶 %d 路 寮哄寲涓€娆?%d" % [_wen, cost])

func _build_hud() -> void:
	_coin_lb = _chip(18, "coin", "0", "鏂囬挶")
	_crystal_lb = _chip(192, "crystal", "100", "鐏垫櫠")
	_chips["鐏垫櫠"].visible = LevelState.show_button("crystal")
	_kill_lb = _chip(366, "kill", "0", "鏉€鏁?)
	_life_lb = _chip(540, "heart", "100", "鍛?)
	_wave_lb = _lbl("娉?1/%d" % _max_wave, Vector2(22, 92), Vector2(100, 48), 26, INK)
	for i in 5:
		var d := Color(0.85, 0.66, 0.23) if i == 0 else Color(0.38, 0.33, 0.26, 0.55)
		var c := Control.new()
		c.position = Vector2(112 + i * 18 - 6, 117 - 6)
		c.size = Vector2(12, 12)
		var ci := Ico.new()
		ci.kind = "dot"
		ci.position = Vector2.ZERO
		ci.size = Vector2(12, 12)
		ci.modulate = Color(1, 1, 1, 1) if i == 0 else Color(0.52, 0.47, 0.40, 1)
		c.add_child(ci)
		add_child(c)
	_panel(Rect2(200, 92, 235, 20), Color(0.10, 0.09, 0.08, 0.35), 3)
	_hp_fill = _panel(Rect2(200, 92, 235 * 0.70, 20), Color(0.61, 0.16, 0.13), 3)
	_hp_lb = _lbl("200/200", Vector2(208, 88), Vector2(120, 28), 17, Color(0.98, 0.95, 0.88))
	_panel(Rect2(200, 118, 235, 9), Color(0.10, 0.09, 0.08, 0.22), 4)
	_mp_bar = _panel(Rect2(200, 118, 235 * 0.35, 9), Color(0.30, 0.52, 0.72), 4)
	var _boss_timer_lb := _lbl("", Vector2(450, 96), Vector2(120, 30), 17, SEAL)
	_boss_timer_lb.visible = false   # 鍘熸潵鍐欐鐨勨€滈棰?00:37鈥濇槸鍋囩殑锛屾敼鎴愰棰嗙湡鐨勫嚭鐜版椂鎵嶆樉绀?	_tot_btn = _btn("鎬昏", Rect2(570, 88, 68, 42), 17, Color(0.10, 0.09, 0.08, 0.98), LIGHT, func(): _show_totals())
	_btn("閫€鍑?, Rect2(646, 88, 60, 42), 17, Color(0.10, 0.09, 0.08, 0.98), LIGHT, func(): _show_exit(true))

# ---------------- 鎴樺満 ----------------
# 闀滃ご瀹瑰櫒锛氭垬鍦哄唴瀹归兘鎸傚湪瀹冧笅闈紝鍋氭帹杩涳紙zoom锛夋椂鏁翠綋涓€璧风缉鏀?var _cam: Control = null
func _build_field() -> void:
	_cam = Control.new()
	_cam.size = Vector2(720, 1280)
	_cam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cam.pivot_offset = Vector2(360, 510)   # 浠ユ垬鍦轰腑蹇冧负缂╂斁涓績
	add_child(_cam)
	_core = BattleCore.new()
	_core.position = Vector2(8, 150)
	_core.size = Vector2(704, 720)
	_core.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 鎴樻枟娌℃湁鎵嬪姩锛氱偣鍑荤┛閫?	_core.modulate = Color(1, 1, 1, 0.25)
	_core.show_combo_counter = false
	_core.show_basic_hit_numbers = false
	_cam.add_child(_core)
	_core.setup({"atk": 12.0, "hp_max": 200.0, "mp_max": 100.0})
	_core.hero["basic_skill_bonus"] = _skill_level_bonus("zhujue") / 100.0
	if LevelState.has_feature("equip"):
		var ForgeData := preload("res://shared/forge_data.gd")
		ForgeData.load_game()
		EquipmentStats.apply(_core, ForgeData.totals())
	_core.set_wave(1)
	_core.coin.connect(_on_core_coin)
	_core.coin_drop.connect(_on_coin_drop)   # v6锛氶挶鎬?鍖鎺夌殑鐪熼挶
	_core.kill.connect(_on_core_kill)
	_core.foe_defeated.connect(_on_foe_defeated)
	_core.chal_drop.connect(_on_chal_drop)
	_core.guard_broken.connect(func() -> void: _q_fail_kind("guard"))
	_core.champion_down.connect(func() -> void: _q_done_kind("champion"))
	_core.hero_attack.connect(_on_hero_attack)
	_core.hero_strike_resolved.connect(_hero_extra_hits)
	_core.hero_hit.connect(_on_hero_hit)
	_core.hero_damaged.connect(_curio_on_hero_hurt)
	_core.hero_foe_hit.connect(_on_hero_foe_hit)
	_core.hero_down.connect(_on_hero_down)
	_core.boss_arrived.connect(_on_boss_arrived)
	_core.delayed_land.connect(_on_delayed_land)
	_core.boss_died.connect(_on_boss_died)
	_core.boss_slain.connect(_curio_on_boss_slain)
	_core.wood_expired.connect(_curio_on_wood_expired)
	_core.cold_expired.connect(_curio_on_cold_expired)
	_core.paper_blocked.connect(_on_paper_blocked)
	# 鏁欏鍏虫瘡娉㈠皯鍒峰嚑鍙紝鑺傚鏇村揩锛堝鍔变笉鍙橈級
	if LevelState.current_level <= 5:
		_core.wave_extra = -8       # 鍓嶄簲鍏筹細澶у箙鍑忛噺锛屽揩閫熸帹杩?	elif LevelState.current_level <= 10:
		_core.wave_extra = -4
	_core.start_run()
	_hero_token = TokenActor.new()
	_hero_token.setup(PLAYER_TEX, 44.0, Color(0.85, 0.66, 0.23), true)
	_hero_token.set_role("player")
	_hero_token.set_weapon("sword")
	_hero_token.show_bar = false          # 涓昏琛€鏉″彧鐪嬮《閮?HUD锛屼笉鍐嶆寕婕傛诞琛€鏉?	_hero_token.bar_w = 0.0
	_hero_token.unit_name = ""
	_hero_token.position = _core.position + _core.hero_pos
	_hero_token.z_index = 6
	_cam.add_child(_hero_token)
	_combo_readout = ComboReadout.new()
	_combo_readout.position = Vector2(542, 190)
	_combo_readout.size = Vector2(160, 58)
	_combo_readout.z_index = 12
	add_child(_combo_readout)
	var hit := Button.new()
	hit.position = Vector2(312, 710)
	hit.size = Vector2(96, 96)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hit.pressed.connect(func(): _open_attr_page())
	_cam.add_child(hit)
	_hero_hit_btn = hit
	_hero_hit_btn.position = _hero_token.position - Vector2(48, 48)
	# 鎸戞垬鏂瑰舰
	_chal_btn = _btn("鎸戞垬", Rect2(0, 760, 96, 96), 20, Color(0.075, 0.068, 0.060, 0.98), Color(0.91, 0.78, 0.42), func(): _toggle_challenge())
	_chal_btn.visible = LevelState.show_button("challenge")
	_build_challenge()
	_build_curio()
	# pixelfx 鐗规晥灞傦細鐩栧湪鎴樺満鍜岃鑹蹭箣涓娿€乁I 涔嬩笅
	# 棣栭鐧诲満婕斿嚭涓変欢濂楋紙骞虫椂闅愯棌锛?	_boss_veil = ColorRect.new()
	_boss_veil.color = Color(0.08, 0.06, 0.05, 0.0)
	_boss_veil.position = Vector2(0, 150)
	_boss_veil.size = Vector2(720, 720)
	_boss_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_veil.z_index = 14
	_boss_veil.visible = false
	add_child(_boss_veil)
	_boss_spot = Sprite2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.92, 0.74, 0.75))
	g.set_color(1, Color(1.0, 0.85, 0.6, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 512
	gt.height = 512
	_boss_spot.texture = gt
	_boss_spot.z_index = 15
	_boss_spot.visible = false
	add_child(_boss_spot)
	_boss_name_lb = Label.new()
	_boss_name_lb.size = Vector2(720, 70)
	_boss_name_lb.position = Vector2(0, 468)
	_boss_name_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_name_lb.add_theme_font_override("font", FONT)
	_boss_name_lb.add_theme_font_size_override("font_size", 44)
	_boss_name_lb.add_theme_color_override("font_color", Color(0.42, 0.12, 0.08))
	_boss_name_lb.add_theme_color_override("font_outline_color", Color(0.99, 0.94, 0.84, 0.95))
	_boss_name_lb.add_theme_constant_override("outline_size", 8)
	_boss_name_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name_lb.z_index = 16
	_boss_name_lb.visible = false
	add_child(_boss_name_lb)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1.0, 0.96, 0.85, 0.0)
	_flash_rect.position = Vector2(0, 150)
	_flash_rect.size = Vector2(720, 720)   # 鍙棯鎴樺満锛屼笉鏌?HUD
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.z_index = 20
	add_child(_flash_rect)
	_boss_bar = BossBar.new()
	_boss_bar.position = Vector2(110, 192)
	_boss_bar.size = Vector2(500, 22)
	_boss_bar.visible = false
	_boss_bar.z_index = 6
	add_child(_boss_bar)
	_fly_layer = FlyLayer.new()
	_fly_layer.size = Vector2(720, 1280)
	_fly_layer.z_index = 9
	add_child(_fly_layer)
	_fly = _fly_layer.dots
	_build_card_detail()
	# v3 鎶€鑳芥爮锛堝彸缂樼珫鎺掞紝6 鏍煎彲瑙嗭級
	_build_skill_bar()
	# 鏀诲嚮琛ㄧ幇灞傦細鍚庡眰鍦ㄧ墝涓嬮潰锛堝墤/寮ц鐗屾尅浣忥級锛屽墠灞傚湪鐗屼笂闈紙鐧借竟/娣＄孩/鏁板瓧锛?	_fx_back = AttackFx.new()
	_fx_back.front = false
	_fx_back.position = FIELD_POS
	_fx_back.size = Vector2(704, 720)
	_fx_back.z_index = 4
	_fx_back.clip_contents = true
	add_child(_fx_back)
	_fx_front = AttackFx.new()
	_fx_front.front = true
	_fx_front.position = FIELD_POS
	_fx_front.size = Vector2(704, 720)
	_fx_front.z_index = 7
	_fx_front.clip_contents = true
	add_child(_fx_front)
	_hero_name_lb = _lbl("灏戜緺", _hero_token.position + Vector2(-60, 52), Vector2(120, 24),
		18, Color(0.30, 0.24, 0.16, 0.9), self, HORIZONTAL_ALIGNMENT_CENTER)
	_hero_name_lb.z_index = 9

class SkillIcon extends Control:
	const F := preload("res://fonts/ink.ttf")
	const G := preload("res://shared/glyph_draw.gd")
	signal pressed
	var kind := "sword"
	var cd := 0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 19, Color(0.93, 0.90, 0.82))
		draw_arc(c, 19, 0, TAU, 32, Color(0.85, 0.66, 0.23, 0.85) if cd == 0 else Color(0.45, 0.39, 0.31, 0.8), 2.0)
		G.draw(self, c, 17.0, kind, Color(0.13, 0.12, 0.11))
		if cd > 0:
			draw_circle(c, 19, Color(0.06, 0.05, 0.05, 0.45))
			draw_string(F, c + Vector2(-8, 7), str(cd), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.96, 0.90, 0.74))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

func _toggle_challenge() -> void:
	if not LevelState.show_button("challenge"):
		return
	_chal_layer.visible = not _chal_layer.visible
	if _chal_layer.visible:
		_refresh_chal_panel()
		_chal_layer.move_to_front()
		if _chal_holder != null:
			_pop_bounce(_chal_holder)
			_breathe(_chal_holder)

# ============================================================
# 鎸戞垬锛氬喎鍗村埗 + 鎸夋尝瑙ｉ攣锛屾墦瀹岀粰璧勬簮
# ============================================================
const CHAL_NAMES := ["閽辨€?, "鏅舵€?, "涔︽€?, "瀹濈", "鍖"]
const CHAL_GROUP := [6, 3, 4, 1, 1]

var _chal_btns: Array = []
var _chal_auto_btn: Button = null
var _chal_holder: Control = null
var _auto_chal := false
var _chal_t := 0.0
var _chal_count := 0

func _build_challenge() -> void:
	_chal_layer = Control.new()
	_chal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chal_layer.visible = false
	_chal_layer.z_index = 15
	add_child(_chal_layer)
	_chal_holder = Control.new()
	_chal_holder.position = Vector2(8, 360)
	_chal_holder.size = Vector2(320, 340)
	_chal_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chal_layer.add_child(_chal_holder)
	_panel(Rect2(0, 0, 320, 340), Color(0.94, 0.90, 0.82, 0.98), 8, Color(0.85, 0.66, 0.23, 0.6), 2, _chal_holder)
	for i in CHAL_NAMES.size():
		var x := 16.0 + float(i % 2) * 148.0
		var y := 16.0 + float(i / 2) * 84.0
		var idx := i
		var b := _btn(str(CHAL_NAMES[i]), Rect2(x, y, 132, 72), 17, Color(0.09, 0.08, 0.07, 0.98),
			Color(0.91, 0.78, 0.42), func() -> void: _chal_press(idx), _chal_holder)
		_chal_btns.append(b)
	_chal_auto_btn = _btn("鑷姩鎸戞垬锛氬叧", Rect2(16, 276, 288, 48), 18, Color(0.13, 0.11, 0.09),
		Color(0.91, 0.78, 0.42), func() -> void: _toggle_auto_chal(), _chal_holder)

func _toggle_auto_chal() -> void:
	_auto_chal = not _auto_chal
	if _chal_auto_btn != null:
		_chal_auto_btn.text = "鑷姩鎸戞垬锛? + ("寮€" if _auto_chal else "鍏?)
	_refresh_chal_panel()

func _chal_unlocked(i: int) -> bool:
	if _core == null:
		return false
	return int(_core.wave) >= int(CHAL_MIN_WAVE[clampi(i, 0, CHAL_MIN_WAVE.size() - 1)])

func _chal_press(i: int) -> void:
	if _run_over or _core == null:
		return
	if not _chal_unlocked(i):
		_toast("銆?s銆嶇 %d 娉㈡墠瑙ｉ攣" % [str(CHAL_NAMES[i]), int(CHAL_MIN_WAVE[i])])
		return
	if float(_chal_cd[i]) > 0.0:
		_toast("銆?s銆嶅喎鍗翠腑 %.0f 绉? % [str(CHAL_NAMES[i]), ceil(float(_chal_cd[i]))])
		return
	_chal_cd[i] = _chal_base_cd(i)
	_chal_count += 1
	_qc("chal", 1)
	var grp := int(CHAL_GROUP[i])
	_core.spawn_challenge(i, grp)
	# 鎸戞垬寮€鎵擄細鎴樺満涓婃柟涓€鍙ｈ惤鍦板啿鍑?+ 榧擄紝缁?搴旀垬"鐨勫垎閲?	_spawn_pfx("impacts/ground-slam", Vector2(360, 235), 0.95, "shadow", 1.5)
	Aud.sfx("drum", -12.0, 1.10)
	_toast("鎸戞垬 路 " + str(CHAL_NAMES[i]))
	Aud.sfx("ui_open", -8.0)
	_refresh_chal_panel()

func _refresh_chal_panel() -> void:
	for i in _chal_btns.size():
		var b: Button = _chal_btns[i]
		if b == null:
			continue
		var cd := float(_chal_cd[i])
		if not _chal_unlocked(i):
			b.text = "%s\n绗?%d 娉㈣В閿? % [str(CHAL_NAMES[i]), int(CHAL_MIN_WAVE[i])]
			b.disabled = true
		elif cd > 0.0:
			b.text = "%s\n%.0f 绉? % [str(CHAL_NAMES[i]), ceil(cd)]
			b.disabled = true
		else:
			b.text = "%s\n脳%d" % [str(CHAL_NAMES[i]), int(CHAL_GROUP[i])]
			b.disabled = false
		b.add_theme_font_size_override("font_size", 17)

func _chal_auto_try() -> void:
	if not _auto_chal or _run_over or _core == null:
		return
	for i in _chal_btns.size():
		if _chal_unlocked(i) and float(_chal_cd[i]) <= 0.0:
			_chal_press(i)
			return

func _tick_chal(dt: float) -> void:
	for i in _chal_cd.size():
		if float(_chal_cd[i]) > 0.0:
			_chal_cd[i] = maxf(0.0, float(_chal_cd[i]) - dt)
	_chal_t += dt
	if _chal_t < 0.5:
		return
	_chal_t = 0.0
	if _chal_layer != null and _chal_layer.visible:
		_refresh_chal_panel()
	_chal_auto_try()

# 鎸戞垬鎬浜★細鎸夌被鍨嬬粨绠楋紙閽辨€蛋 coin_drop锛岃繖閲屼笉閲嶅缁欙級
func _on_chal_drop(kind: int, _pos: Vector2) -> void:
	if _run_over or _core == null:
		return
	match kind:
		1:
			_gain_crystal(int(float(4 + randi() % 4) * _core.chal_crystal_mul()))
		2:
			_add_exp(80)                      # 涔︽€細棰濆缁忛獙锛屽揩閫熺粌绾?		3:
			_trea_charge += 1
			_trea_reroll += 1
			if randf() < float(_treasure_pct) / 100.0:
				_trea_reroll += 1
			_refresh_trea_tile()
			_toast("瀹濈 路 瀹濈墿鏈轰細 +1 路 鍒锋柊 +1")
		4:
			_add_wen(int(220.0 * _core.chal_money_mul() * (1.0 + _boss_pct / 100.0)))
			_gain_crystal(int(round(30.0 * _core.chal_crystal_mul() * (1.0 + _boss_pct / 100.0))))
			_trea_charge += 1
			_trea_reroll += 1
			_aug_reroll += 1
			_refresh_trea_tile()
			_toast("鍖 路 鏂囬挶/鐏垫櫠 + 瀹濈墿鏈轰細 + 鍒锋柊")

# ============================================================
# 濂囩墿锛堝眬澶栦竴浠?路 灞€鍐呭叏鑷姩锛屼笉鐢ㄧ帺瀹剁偣锛?#   棣栦欢 鐜茬彂鐜夊６锛氭皵琛€浣庝簬 30% 绔嬪埢鍠濓紱浣庝簬 50% 涓旇韩杈规湁鏁屼篃鍠?#   鍥炴皵琛€ 25% / 鍐呭姏 25%锛屽喎鍗?60 绉?# ============================================================
# ---------------- 濂囩墿锛堝崟妲?路 鍏ㄨ嚜鍔級 ----------------
const CurioData := preload("res://shared/curio_data.gd")
const GameState := preload("res://shared/game_state.gd")

var _curio_id := ""
var _curio_lv := 1
var _curio_atk_t := 0.0        # 琛€钁姦锛氬墿浣欐寔缁?var _curio_atk_add := 0.0      # 琛€钁姦锛氭敾鍑诲姞鎴?var _curio_extend_used := 0.0  # 鏈澧炵泭宸插欢闀跨殑鎬荤鏁帮紝涓嶉殢鍊掕鏃跺洖閫€
var _curio_extra_used := false # 鐜夊６ Lv5锛氭繏姝婚澶栦竴娆?var _curio_kills := 0
var _curio_waves := 0           # 瀹為檯鎴愬姛娓呮尝娆℃暟锛屼笉鍖呭惈鎴樿触璺宠繃鐨勬尝
var _rewarded_waves := {}       # 闃叉娓呮尝鍥炶皟閲嶅缁撶畻
var _tie_stacks := 0           # 閾佸竷琛細纭皵灞傛暟
var _tie_idle := 0.0           # 閾佸竷琛細澶氫箙娌℃尐鎵?var _zhiren := 0               # 绾镐汉鏇胯韩锛氬墿浣欐暟閲?var _draw_free := 0            # 涓囧簲绗︼細鍏嶈垂鎶藉崱鍒锋柊娆℃暟
var _wanying_add := 0          # 涓囧簲绗︼細姣忕鍒锋柊 +N
var _yuhu_shield := 0.0        # 鐜夊６ Lv3锛氬枬瀹屽悗鍑忎激鍓╀綑绉掓暟
var _dart_n := 0               # 閾滈挶鍓戯細鏅敾璁℃暟锛圠v3 姣?3 娆″涓€鏋氾級

func _curio_init_data() -> void:
	_curio_id = GameState.curio_id
	if _curio_id != "" and CurioData.get_curio(_curio_id).is_empty():
		_curio_id = ""
	_curio_lv = GameState.curio_level(_curio_id) if _curio_id != "" else 1

func _foe_near(pos: Vector2, r: float) -> bool:
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0:
			continue
		if pos.distance_to(Vector2(float(f.get("x", 0.0)), float(f.get("y", 0.0)))) <= r:
			return true
	return false

func _build_curio() -> void:
	_curio_init_data()
	var info := CurioData.get_curio(_curio_id)
	_curio_sq = CurioSquare.new()
	_curio_sq.position = Vector2(624, 760)
	_curio_sq.size = Vector2(96, 96)
	_curio_sq.glyph = str(info.get("glyph", "濂?)) if not info.is_empty() else "濂?
	_curio_sq.label = "濂囩墿"
	_curio_sq.cd_max = maxf(1.0, float(info.get("cd", 1.0)))
	_curio_sq.pressed.connect(_show_curio_detail)
	add_child(_curio_sq)
	_curio_apply_static()

func _curio_flash() -> void:
	if _curio_sq != null:
		_curio_sq.flash = 1.0
		_curio_sq.queue_redraw()

# 姣忓抚锛氬喎鍗?+ 鎸佺画 buff + 鍚勫鐗╃殑鑷姩瑙﹀彂
func _tick_curio(dt: float) -> void:
	if _curio_sq == null:
		return
	if _curio_cd > 0.0:
		_curio_cd = maxf(0.0, _curio_cd - dt)
		_curio_sq.cd_left = _curio_cd
		_curio_sq.queue_redraw()
	if _curio_sq.flash > 0.0:
		_curio_sq.flash = maxf(0.0, _curio_sq.flash - dt * 2.2)
		_curio_sq.queue_redraw()
	if _run_over or _core == null or _curio_id == "":
		return
	if _curio_atk_t > 0.0:
		_curio_atk_t = maxf(0.0, _curio_atk_t - dt)
		if _curio_atk_t <= 0.0:
			_curio_atk_add = 0.0
			_core.hero["curio_aspd"] = 0.0
			_core.hero["curio_crit"] = 0.0
	_core.hero["curio_atk"] = _curio_atk_add if _curio_atk_t > 0.0 else 0.0
	match _curio_id:
		"yuhu":
			_curio_tick_yuhu(dt)
		"xuehulu":
			_curio_tick_xuehulu()
		"jingtangmu":
			_curio_tick_jingtangmu()
		"zuiweng":
			_curio_tick_zuiweng(dt)
		"tiebushan":
			_curio_tick_tiebushan(dt)
		"zhaohunfan":
			_curio_tick_zhaohunfan()
		"tongjing":
			_curio_tick_tongjing()
		"zhiren":
			_curio_tick_zhiren()

func _curio_tick_yuhu(dt: float) -> void:
	if _yuhu_shield > 0.0:
		_yuhu_shield = maxf(0.0, _yuhu_shield - dt)
		if _yuhu_shield <= 0.0 and _core != null:
			_core.hero["curio_cut"] = 0.0
	var h: Dictionary = _core.hero
	var mx := maxf(1.0, float(h.get("hp_max", 1.0)))
	var hpr := float(h.get("hp", 0.0)) / mx
	if hpr <= 0.0:
		return
	if _curio_lv >= 5 and not _curio_extra_used and hpr < 0.15:
		_curio_extra_used = true
		_curio_use(true)
		return
	if _curio_cd > 0.0:
		return
	if hpr <= 0.30 or (hpr <= 0.50 and _foe_near(_core.hero_pos, 220.0)):
		_curio_use()

func _curio_use(extra := false) -> void:
	if _run_over or _core == null or float(_core.hero.get("hp", 0.0)) <= 0.0:
		return
	var h: Dictionary = _core.hero
	var mx := float(h.get("hp_max", 1.0))
	var pct := 0.30 if _curio_lv >= 2 else 0.25
	var cd := 45.0 if _curio_lv >= 4 else 60.0
	var hp_add := mx * pct
	_core.heal_hero(hp_add)
	var mp_add := _mp_max * pct
	_mp = minf(_mp_max, _mp + mp_add)
	if not extra:
		_curio_cd = cd
	if _curio_sq != null:
		_curio_sq.cd_max = cd
	if _curio_lv >= 3:
		_yuhu_shield = 4.0
		_core.hero["curio_cut"] = 0.20
	_curio_uses += 1
	_curio_flash()
	_toast("鐜夊６ 路 姘旇 +%d 路 鍐呭姏 +%d" % [int(hp_add), int(mp_add)])
	Aud.sfx("drink", -10.0, 1.05)
	_spawn_pfx("holy/heal", _hero_screen(), 0.85, "heal", 1.5)

func _curio_tick_xuehulu() -> void:
	if _curio_cd > 0.0:
		return
	var h: Dictionary = _core.hero
	var mx := maxf(1.0, float(h.get("hp_max", 1.0)))
	var hpr := float(h.get("hp", 0.0)) / mx
	if hpr <= 0.0 or hpr > 0.70 or not _foe_near(_core.hero_pos, 300.0):
		return
	var cost := float(h.get("hp", 0.0)) * 0.10
	if _curio_lv >= 5:
		cost = (mx - float(h.get("hp", 0.0))) * 0.10
	h["hp"] = maxf(1.0, float(h.get("hp", 1.0)) - cost)
	_curio_atk_add = 0.80 if _curio_lv >= 4 else 0.60
	_curio_atk_t = 11.0 if _curio_lv >= 2 else 8.0
	_curio_extend_used = 0.0
	_curio_cd = 45.0
	_curio_uses += 1
	_curio_flash()
	_toast("琛€钁姦 路 鏀诲嚮 +%d%%" % int(_curio_atk_add * 100.0))
	Aud.sfx("drum", -9.0, 0.9)
	_spawn_pfx("impacts/crit-hit", _hero_screen(), 0.9, "", 1.5)

func _curio_tick_jingtangmu() -> void:
	if _curio_cd > 0.0:
		return
	var live: Array = _live_foes()
	if live.size() < 2:
		return
	var dur := 2.5 if _curio_lv >= 2 else 2.0
	var targets := 2 if _curio_lv >= 4 else 1
	# _live_foes宸叉湁璺濈鎺掑簭锛涜鏉＄洰鏍囦紭鍏堬紝鍚岀粍浠嶆寜璺濈閫夈€?	var ordered: Array = []
	for casting in [true, false]:
		for foe in live:
			if not bool(foe.get("boss", false)) and _core.has_pending_cast(foe) == casting:
				ordered.append(foe)
	var n := 0
	for f_v in ordered:
		if n >= targets:
			break
		var f: Dictionary = f_v
		if bool(f.get("boss", false)):
			continue
		f["para"] = maxf(float(f.get("para", 0.0)), dur)
		f["t"] = 0.0
		f["wood_t"] = dur
		f["wood_vuln"] = 0.30 if _curio_lv >= 3 else 0.0
		f["wood_boom"] = _curio_lv >= 5
		_core.interrupt_cast(f)
		n += 1
		_spawn_pfx("impacts/ground-slam", _core.position + Vector2(float(f["x"]), float(f["y"]) - 20.0), 0.6, "", 1.2)
	if n <= 0:
		return
	_curio_cd = 35.0
	_curio_uses += 1
	_curio_flash()
	Aud.sfx("wood_down", -8.0, 0.9)
	_toast("鎯婂爞鏈?路 瀹氳韩 %d 鍙? % n)

func _curio_on_wood_expired(foe: Dictionary) -> void:
	var boom := bool(foe.get("wood_boom", false))
	foe.erase("wood_vuln")
	foe.erase("wood_boom")
	if _run_over or not boom or float(foe.get("hp", 0.0)) <= 0.0 or float(foe.get("dying", 0.0)) > 0.0:
		return
	if _core == null or not _skill_batch_active(_core._enemy_attack_epoch) or not _core.foes.has(foe):
		return
	_core._apply_dmg(foe, float(_core.hero.get("atk", 12.0)) * 0.8, "鐗╃悊")
	_spawn_pfx("impacts/ground-slam", _core.position + Vector2(float(foe["x"]), float(foe["y"])), 0.8, "", 1.2)
	if float(foe.get("hp", 0.0)) <= 0.0:
		_core._kill_foe(foe)

# 閾滈挶鍓戯細姣忔鏅敾闄勫甫涓€鏋氶挶闀栵紙鎵撳埌鏇磋繙鐨勬€級
func _curio_on_attack() -> void:
	if _run_over or _curio_id != "tongqianjian" or _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	_dart_n += 1
	var shots := 1
	if _curio_lv >= 3 and _dart_n % 3 == 0:
		shots = 2
	var reach: float = _core.HERO_REACH + (200.0 if _curio_lv >= 4 else 120.0)
	var fired := false
	for _shot in shots:
		if not _skill_batch_active(epoch):
			return
		var best: Dictionary = {}
		var bd := 1e9
		for f_v in _core.foes:
			var f: Dictionary = f_v
			if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
				continue
			var d: float = _core.hero_pos.distance_to(Vector2(float(f["x"]), float(f["y"])))
			if d > reach:
				continue
			if d < bd:
				bd = d
				best = f
		if best.is_empty():
			break
		if not fired:
			_curio_uses += 1
			_curio_flash()
			fired = true
		var targets: Array = [best]
		var origin: Vector2 = _core.hero_pos
		var first := Vector2(float(best["x"]), float(best["y"]))
		var dir := (first - origin).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		if _curio_lv >= 5:
			var next: Dictionary = {}
			var nearest := INF
			for foe in _core.foes:
				if is_same(foe, best) or float(foe.get("hp", 0.0)) <= 0.0 or float(foe.get("dying", 0.0)) > 0.0:
					continue
				var rel := Vector2(float(foe["x"]), float(foe["y"])) - origin
				var along := rel.dot(dir)
				# 20px鍗婂娌跨敤鏅€氭€墝鍗婂緞锛涗粎閫夋嫨绗竴鐩爣鍚庢柟鍚屼竴璺緞銆?				if along < bd or rel.length() > reach or absf(rel.cross(dir)) > 20.0:
					continue
				if along < nearest:
					nearest = along
					next = foe
			if not next.is_empty():
				targets.append(next)
		var last_hit: Dictionary = {}
		for i in range(targets.size()):
			if not _skill_batch_active(epoch):
				return
			var target: Dictionary = targets[i]
			if not _core.foes.has(target) or bool(target.get("_death_settled", false)) or float(target.get("hp", 0.0)) <= 0.0 or float(target.get("dying", 0.0)) > 0.0:
				continue
			var mul := (0.45 if _curio_lv >= 2 else 0.35) * (0.5 if i > 0 else 1.0)
			_core._apply_dmg(target, float(_core.hero.get("atk", 12.0)) * mul, "鐗╃悊")
			last_hit = target
			_spawn_pfx("impacts/crit-hit", _core.position + Vector2(float(target["x"]), float(target["y"]) - 16.0), 0.5, "gold", 1.9)
			if float(target.get("hp", 0.0)) <= 0.0:
				_core._kill_foe(target)
				if not _skill_batch_active(epoch):
					return
		if not last_hit.is_empty():
			_curio_dart_trace(origin, Vector2(float(last_hit["x"]), float(last_hit["y"])))
			Aud.sfx("dart", -14.0, 1.1)

func _curio_dart_trace(origin: Vector2, target: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([_core.position + origin, _core.position + target])
	line.width = 2.0
	line.default_color = Color(0.92, 0.72, 0.30)
	line.z_index = 7
	(_cam if _cam != null else self).add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.12)
	tween.tween_callback(line.queue_free)

# 瑙勫垯绫伙細杩涘眬鏃朵竴娆℃€у簲鐢紙鍒锋柊娆℃暟 / 鎶€鑳藉喎鍗达級
func _curio_apply_static() -> void:
	if _curio_id == "wanyingfu":
		var add := 1
		if _curio_lv >= 2:
			add = 2
		if _curio_lv >= 4:
			add = 3
		if _curio_lv >= 5:
			add = 0 # 浜旂骇閫夊厤鑰楁ā寮忥紝涓嶅彔鍔犳鏁拌禒閫併€?		_wanying_add = add
		_trea_reroll += add
		_aug_reroll += add
		_god_reroll += add
		_draw_free += add
		_refresh_draw_btn()
	elif _curio_id == "zhiren":
		_set_paper_count(0)

# 涓囧簲绗?Lv5锛?5% 姒傜巼杩欐鍒锋柊涓嶆秷鑰楁鏁?func _rr_free() -> bool:
	return _curio_id == "wanyingfu" and _curio_lv >= 5 and _roll_refresh_keep()

func _roll_refresh_keep() -> bool:
	return randf() < 0.25

func _roll_wanying_refresh() -> int:
	return randi() % 4

# 瀹氶鐝狅細鎶€鑳藉喎鍗寸缉鍑?func _curio_skill_cd_mul() -> float:
	if _curio_id != "dingfengzhu":
		return 1.0
	if _curio_lv >= 4:
		return 0.75
	if _curio_lv >= 2:
		return 0.80
	return 0.85

# 闀囬瓊閾冿細濂囬亣鍒锋柊闂撮殧
func _q_interval() -> float:
	var base := Q_TICK
	if _curio_id == "zhenhunling":
		if _curio_lv >= 4:
			base = Q_TICK / 1.40
		elif _curio_lv >= 1:
			base = Q_TICK / 1.25
	return base

# ---------------- 鍙敜绫诲鐗?----------------
func _curio_summon(tag: String, nm: String, col: Color, life: float, dmg_pct: float, boom: float, lc := 0.0) -> void:
	if _run_over or _core == null:
		return
	if not _skill_batch_active(_core._enemy_attack_epoch):
		return
	var idx := _curio_count_minions(tag)
	var follow_offset := Vector2(-60.0 + float(idx % 3) * 60.0, 20.0)
	var pos: Vector2 = _core.hero_pos + follow_offset
	var tk = TokenActor.new()
	tk.setup(null, 20.0, col, false)
	tk.show_bar = true
	tk.bar_w = 44.0
	tk.unit_name = nm
	tk.z_index = 5
	tk.position = _core.position + pos
	if _cam != null:
		_cam.add_child(tk)
	else:
		add_child(tk)
	# 鍙敜鐗╁浘鏍囷紙娌℃湁绔嬬粯锛岀敤涓€涓瓧鏍囧嚭韬唤锛?	var mk := Label.new()
	mk.text = nm.substr(0, 1)
	mk.position = Vector2(-22, -44)
	mk.size = Vector2(44, 44)
	mk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mk.add_theme_font_override("font", FONT)
	mk.add_theme_font_size_override("font_size", 24)
	mk.add_theme_color_override("font_color", col.darkened(0.25))
	mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tk.add_child(mk)
	var atk := float(_core.hero.get("atk", 12.0))
	_minions.append({"pos": pos, "life": life, "max_life": life, "atk_cd": 0.5, "wave_cd": 999.0,
		"dmg": atk * dmg_pct, "wave_dmg": 0.0, "tk": tk, "curio": tag, "boom": boom, "lc": lc, "copy_ratio": dmg_pct, "follow_offset": follow_offset})

func _curio_count_minions(tag: String) -> int:
	var n := 0
	for m_v in _minions:
		if str((m_v as Dictionary).get("curio", "")) == tag and float(m_v.get("life", 0.0)) > 0.0:
			n += 1
	return n

func _curio_mirror_hit(target: Dictionary, damage: float) -> void:
	if _run_over or _core == null or damage <= 0.0:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	for mirror in _minions.duplicate():
		if not _skill_batch_active(epoch):
			return
		if not _minions.has(mirror):
			continue
		if str(mirror.get("curio", "")) != "tongjing" or float(mirror.get("life", 0.0)) <= 0.0:
			continue
		var dealt: float = _core.apply_echo_damage(target, damage * float(mirror.get("copy_ratio", 0.5)))
		# 鍑绘潃鍥炶皟鍙粨鏉熸垬鏂楁垨鍥炴疆锛屾棫闀滃儚涓嶈兘鍦ㄦ柊闃舵缁х画婕斿嚭/鍚歌銆?		if not _skill_batch_active(epoch):
			return
		if dealt > 0.0:
			_core._push_float(float(target["x"]), float(target["y"]) - 45.0, "闀?" + str(int(dealt)), Color(0.72, 0.70, 0.90))
			if float(_core.hero.get("hp", 0.0)) > 0.0:
				_core.heal_hero(dealt * float(mirror.get("lc", 0.0)))

func _curio_tick_zhiren() -> void:
	if _core == null:
		return
	# Lv5锛氱焊浜轰篃鑳芥尅棣栭寤惰繜鎶€锛堟牳蹇冭鍒拌繖涓暟灏变細娑堣€楋級
	_core.hero["paper_guard"] = _zhiren if _curio_lv >= 5 else 0

func _set_paper_count(amount: int) -> void:
	_zhiren = clampi(amount, 0, 3 if _curio_lv >= 2 else 2)
	if _core != null:
		_core.hero["paper_guard"] = _zhiren if _curio_id == "zhiren" and _curio_lv >= 5 else 0

func _paper_shatter() -> void:
	if _curio_lv < 3 or _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	for foe in _core.foes.duplicate():
		if not _skill_batch_active(epoch):
			return
		if not _core.foes.has(foe) or bool(foe.get("_death_settled", false)) or float(foe.get("hp", 0.0)) <= 0.0 or float(foe.get("dying", 0.0)) > 0.0:
			continue
		if _core.hero_pos.distance_to(Vector2(float(foe["x"]), float(foe["y"]))) > 140.0:
			continue
		_core._apply_dmg(foe, float(_core.hero.get("atk", 12.0)), "鐗╃悊")
		if float(foe.get("hp", 0.0)) <= 0.0:
			_core._kill_foe(foe)
			if not _skill_batch_active(epoch):
				return
		elif not bool(foe.get("boss", false)):
			foe["kb"] = maxf(float(foe.get("kb", 0.0)), 120.0)

func _curio_tick_zhaohunfan() -> void:
	if _run_over or _curio_cd > 0.0 or _core == null:
		return
	if not _skill_batch_active(_core._enemy_attack_epoch):
		return
	if _live_foes().is_empty():
		return
	var cap := 2 if _curio_lv >= 3 else 1
	if _curio_count_minions("zhaohunfan") >= cap:
		return
	for _i in range(cap - _curio_count_minions("zhaohunfan")):
		_curio_summon("zhaohunfan", "楝煎奖", Color(0.55, 0.45, 0.85),
			10.0 if _curio_lv >= 2 else 8.0,
			0.35 if _curio_lv >= 4 else 0.25,
			0.80 if _curio_lv >= 5 else 0.0)
	_curio_cd = 25.0
	_curio_uses += 1
	_curio_flash()
	_toast("鎷涢瓊骞?路 楝煎奖鐜板舰")
	Aud.sfx("enlighten", -10.0, 0.9)

func _curio_tick_tongjing() -> void:
	if _curio_cd > 0.0 or _core == null:
		return
	if not _skill_batch_active(_core._enemy_attack_epoch):
		return
	if _live_foes().is_empty():
		return
	if _curio_count_minions("tongjing") > 0:
		return
	_curio_summon("tongjing", "闀滃奖", Color(0.72, 0.70, 0.78),
		7.0 if _curio_lv >= 2 else 5.0,
		0.70 if _curio_lv >= 4 else 0.50,
		0.0, 0.10 if _curio_lv >= 3 else 0.0)
	if _curio_lv >= 5:
		var mirror: Dictionary = _minions.back()
		mirror["decoy"] = _core.add_mirror_decoy(mirror["pos"])
	_curio_cd = 20.0
	_curio_uses += 1
	_curio_flash()
	_toast("閾滈暅 路 闀滃奖绂讳綋")
	Aud.sfx("bell", -12.0, 1.2)

# 閱夌縼澹讹細鍑绘潃绱锛堟瘡 10 鍙繘鍏ラ唹锛?func _curio_on_kill(n: int) -> void:
	if _core == null or n <= 0:
		return
	if _curio_id == "xuehulu" and _curio_lv >= 3 and _curio_atk_t > 0.0:
		_curio_extend_buff(0.6 * n, 4.0)
	if _curio_id != "zuiweng":
		return
	_curio_kills += n
	while _curio_kills >= 10:
		_curio_kills -= 10
		_curio_zui_start()

func _curio_zui_start() -> void:
	_curio_atk_add = 0.45 if _curio_lv >= 4 else 0.30
	_curio_atk_t = 10.0 if _curio_lv >= 2 else 8.0
	_curio_extend_used = 0.0
	_core.hero["curio_aspd"] = 0.10
	if _curio_lv >= 3:
		_core.hero["curio_crit"] = 0.10
	_curio_uses += 1
	_curio_flash()
	_toast("閱夌縼澹?路 閱夋剰涓婃秾")
	Aud.sfx("drink", -10.0, 0.95)
	_spawn_pfx("impacts/crit-hit", _hero_screen(), 0.8, "", 1.4)

# 閱夌縼澹讹細杩欓噷鍙 buff 鍒版湡娓呯┖
func _curio_tick_zuiweng(_dt: float) -> void:
	pass

# 閾佸竷琛細5 绉掍笉鎸ㄦ墦娓呯┖灞傛暟
func _curio_tick_tiebushan(dt: float) -> void:
	if _tie_stacks <= 0:
		return
	_tie_idle += dt
	if _tie_idle >= 5.0:
		_tie_stacks = 0
		_core.hero["curio_cut"] = 0.0
		_core.hero["curio_control_immune"] = false

# 閾佸竷琛細鍙楀嚮鍙犲眰 + 婊″眰鍙嶅脊
func _curio_on_hero_hurt(amount: float, attacker: Dictionary) -> void:
	if _run_over or amount <= 0.0 or _curio_id != "tiebushan" or _core == null:
		return
	var cap := 8 if _curio_lv >= 2 else 5
	_tie_stacks = mini(cap, _tie_stacks + 1)
	_tie_idle = 0.0
	var per := 0.03 if _curio_lv >= 4 else 0.02
	_core.hero["curio_cut"] = float(_tie_stacks) * per
	_core.hero["curio_control_immune"] = _curio_lv >= 5 and _tie_stacks >= cap
	if _curio_lv >= 3 and _tie_stacks >= cap:
		_core.reflect_damage(attacker, amount * 0.30)

# 瀵掔帀鎵虫寚锛氭毚鍑诲彔瀵掋€? 灞傚喕缁擄紱閱夌縼澹?Lv5锛氭毚鍑诲欢闀块唹
func _curio_extend_buff(seconds: float, cap: float) -> void:
	var added := minf(seconds, maxf(0.0, cap - _curio_extend_used))
	_curio_extend_used += added
	_curio_atk_t += added

func _curio_on_crit(tgt: Dictionary) -> void:
	if _core == null:
		return
	if not _skill_batch_active(_core._enemy_attack_epoch):
		return
	if _curio_id == "zuiweng" and _curio_lv >= 5 and _curio_atk_t > 0.0:
		_curio_extend_buff(1.0, 5.0)
	if _curio_id != "hanyu" or not _core.foes.has(tgt) or tgt.is_empty() or float(tgt.get("hp", 0.0)) <= 0.0:
		return
	var c := mini(3, int(tgt.get("cold", 0)) + 1)
	tgt["cold"] = c
	tgt["cold_t"] = 3.0
	tgt["cold_slow"] = c * (0.15 if _curio_lv >= 4 else 0.10)
	if _curio_lv < 2 or c < 3 or bool(tgt.get("boss", false)):
		return
	tgt["cold"] = 0
	tgt["cold_freeze_t"] = 0.8
	tgt["cold_boom"] = _curio_lv >= 5
	if _curio_lv >= 3:
		tgt["cold_dmg"] = 0.25
	_curio_uses += 1
	_curio_flash()
	_spawn_pfx("impacts/crit-hit", _core.position + Vector2(float(tgt["x"]), float(tgt["y"]) - 16.0), 0.8, "", 1.4)
	Aud.sfx("bell", -12.0, 1.3)

func _curio_on_cold_expired(tgt: Dictionary) -> void:
	var boom := bool(tgt.get("cold_boom", false))
	tgt.erase("cold_boom")
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch) or not _core.foes.has(tgt):
		return
	if boom and float(tgt.get("hp", 0.0)) > 0.0 and float(tgt.get("dying", 0.0)) <= 0.0:
		var at := Vector2(float(tgt["x"]), float(tgt["y"]))
		_spawn_pfx("impacts/crit-hit", _core.position + at, 1.0, "", 1.4)
		for o_v in _core.foes.duplicate():
			if not _skill_batch_active(epoch):
				return
			var o: Dictionary = o_v
			if not _core.foes.has(o) or o == tgt or bool(o.get("_death_settled", false)) or float(o.get("dying", 0.0)) > 0.0 or float(o.get("hp", 0.0)) <= 0.0:
				continue
			if at.distance_to(Vector2(float(o["x"]), float(o["y"]))) > 70.0:
				continue
			_core._apply_dmg(o, float(_core.hero.get("atk", 12.0)) * 0.6, "鐗╃悊")
			if float(o.get("hp", 0.0)) <= 0.0:
				_core._kill_foe(o)

# 娓呮尝缁撶畻锛氳仛瀹濈泦 / 缁懡鐏?func _curio_on_wave_clear(wave: int) -> void:
	if _core == null:
		return
	_curio_waves += 1
	if _curio_id == "jubaopen":
		var per := 3
		if _curio_lv >= 2:
			per = 4
		if _curio_lv >= 4:
			per = 5
		var amt := per * maxi(1, wave)
		if _curio_lv >= 5 and _wen >= 1000:
			amt += int(floor(float(_wen) * 0.02))
		_add_wen(amt)
		if _curio_lv >= 3 and _roll_curio_crystal():
			_gain_crystal(1)
		_spawn_fly(_hero_screen(), Vector2(99, 40), Color(0.90, 0.71, 0.30), 4)
		_toast("鑱氬疂鐩?路 鏂囬挶 +%d" % amt)
		_curio_uses += 1
		_curio_flash()
	if _curio_id == "wanyingfu" and _curio_lv >= 3 and _curio_lv < 5:
		var which := _roll_wanying_refresh()
		if which == 0:
			_trea_reroll += 1
		elif which == 1:
			_aug_reroll += 1
		elif which == 2:
			_god_reroll += 1
		else:
			_draw_free += 1
		_refresh_draw_btn()
		_toast("涓囧簲绗?路 闅忔満鍒锋柊 +1")
	if _curio_id == "zhiren":
		var cap_z := 3 if _curio_lv >= 2 else 2
		var gain := 2 if _curio_lv >= 4 else 1
		_set_paper_count(mini(cap_z, _zhiren + gain))
		_toast("绾镐汉鏇胯韩 路 鐜版湁 %d 涓? % _zhiren)
		_curio_flash()
	if _curio_id == "xumingdeng":
		var every := 3
		if _curio_lv >= 2:
			every = 2
		if _curio_lv >= 5:
			every = 1
		if _curio_waves % every == 0:
			_curio_gain_life(3 if _curio_lv == 4 else 2)

func _roll_curio_crystal() -> bool:
	return randf() < 0.10

func _curio_gain_life(amount: int) -> void:
	_life += amount
	_refresh_life_ui()
	_toast("缁懡鐏?路 鍛?+%d" % amount)
	_curio_uses += 1
	_curio_flash()
	Aud.sfx("coin", -10.0)

func _curio_on_boss_slain() -> void:
	if not _run_over and _curio_id == "xumingdeng" and _curio_lv >= 3:
		_curio_gain_life(5)

func _show_curio_detail() -> void:
	if _curio_detail != null:
		_curio_detail.queue_free()
	var info := CurioData.get_curio(_curio_id)
	var has := not info.is_empty()
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 32
	add_child(layer)
	_curio_detail = layer
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var holder := Control.new()
	holder.position = Vector2(120, 340)
	holder.size = Vector2(480, 470)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	_panel(Rect2(0, 0, 480, 470), Color(0.97, 0.93, 0.85, 0.99), 10, Color(0.85, 0.66, 0.23), 3, holder)
	if not has:
		_lbl("鏈眬娌℃湁鎼哄甫濂囩墿", Vector2(0, 40), Vector2(480, 44), 28, INK, holder, HORIZONTAL_ALIGNMENT_CENTER)
		_lbl("鍦ㄥ眬澶栥€屽鐗┿€嶉〉閫夋嫨涓€浠跺啀鍑哄嚮", Vector2(0, 96), Vector2(480, 30), 18, DIM, holder, HORIZONTAL_ALIGNMENT_CENTER)
		_btn("脳", Rect2(436, 12, 34, 30), 20, Color(0.97, 0.93, 0.85), DIM,
			func() -> void: _curio_detail.visible = false, holder)
		_pop_bounce(holder)
		return
	_lbl(str(info.get("name", "")), Vector2(0, 16), Vector2(480, 42), 32, INK, holder, HORIZONTAL_ALIGNMENT_CENTER)
	_panel(Rect2(148, 60, 184, 28), Color(0.62, 0.44, 0.12, 0.92), 5, Color(0.62, 0.44, 0.12), 0, holder)
	_lbl("濂囩墿 路 Lv %d" % _curio_lv, Vector2(148, 62), Vector2(184, 24), 15, Color(0.99, 0.95, 0.87), holder, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl(str(info.get("glyph", "?")), Vector2(0, 96), Vector2(480, 70), 46, Color(0.36, 0.28, 0.12), holder, HORIZONTAL_ALIGNMENT_CENTER)
	var cdv := float(info.get("cd", 0.0))
	var rows := [
		["褰撳墠", CurioData.level_text(_curio_id, _curio_lv)],
		["瑙﹀彂", str(info.get("trig", ""))],
		["鍐峰嵈", ("%d 绉掞紙鑷姩浣跨敤锛屼笉鐢ㄦ搷浣滐級" % int(cdv)) if cdv > 0.0 else "琚姩 路 甯搁┗"],
		["鏈眬", "宸茶Е鍙?%d 娆? % _curio_uses],
	]
	var y := 186.0
	for r in rows:
		_lbl(str(r[0]), Vector2(26, y), Vector2(70, 24), 15, Color(0.47, 0.41, 0.33), holder)
		_lbl(str(r[1]), Vector2(92, y - 3), Vector2(360, 26), 18, INK, holder)
		y += 52.0
	if _curio_lv < 5:
		_lbl("涓嬩竴妗ｏ細%s" % CurioData.level_text(_curio_id, _curio_lv + 1),
			Vector2(26, 388), Vector2(430, 24), 16, Color(0.47, 0.41, 0.33), holder)
	_lbl("鍏ㄨ嚜鍔ㄤ娇鐢紝鐜╁涓嶉渶瑕佺偣瀹冿紱鐐硅繖閲屽彧鏄湅璇︽儏", Vector2(26, 424), Vector2(430, 22), 15, Color(0.47, 0.41, 0.33), holder)
	_btn("脳", Rect2(436, 12, 34, 30), 20, Color(0.97, 0.93, 0.85), DIM,
		func() -> void: _curio_detail.visible = false, holder)
	_pop_bounce(holder)
	_breathe(holder)

func _build_card_detail() -> void:
	_detail_layer = Control.new()
	_detail_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_layer.visible = false
	_detail_layer.z_index = 30
	add_child(_detail_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_detail_layer.visible = false)
	_detail_layer.add_child(dim)
	_detail_card = Panel.new()
	_detail_card.position = Vector2(210, 420)
	_detail_card.size = Vector2(300, 420)
	_detail_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_layer.add_child(_detail_card)
	_detail_name = _lbl("闈掗攱", Vector2(230, 438), Vector2(260, 40), 30, INK, _detail_layer, HORIZONTAL_ALIGNMENT_CENTER)
	_detail_art = TextureRect.new()
	_detail_art.position = Vector2(230, 486)
	_detail_art.size = Vector2(260, 150)
	_detail_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_detail_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_layer.add_child(_detail_art)
	_lbl("鏁?鏋?, Vector2(230, 650), Vector2(120, 26), 18, DIM, _detail_layer)
	_detail_effect = _lbl("鏀诲嚮 +6", Vector2(230, 678), Vector2(260, 36), 26, INK, _detail_layer)
	_lbl("缁?鍚?, Vector2(230, 728), Vector2(120, 26), 18, DIM, _detail_layer)
	_detail_combo = _lbl("鎴愰暱 1/3", Vector2(300, 728), Vector2(120, 28), 22, Color(0.54, 0.35, 0.12), _detail_layer)
	for i in 6:
		var pip := ColorRect.new()
		pip.position = Vector2(424 + i * 14, 734)
		pip.size = Vector2(11, 11)
		pip.color = Color(0.42, 0.36, 0.28, 0.3)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_detail_layer.add_child(pip)
		_detail_pips.append(pip)
	_detail_combo_text = _lbl("鎴愰暱锛氭潃鏁屾彁鍗?1 鐐规敾鍑?, Vector2(230, 768), Vector2(260, 44), 17, INK, _detail_layer)
	_btn("脳", Rect2(574, 430, 40, 34), 22, Color(0.95, 0.91, 0.83), DIM, func(): _detail_layer.visible = false, _detail_layer)

# ---------------- 鍗＄粍 ----------------
func _build_deck() -> void:
	_deck_count_lb = _lbl("鍗＄粍 0/10", Vector2(22, 910), Vector2(160, 30), 20, INK)
	_page_lb = _lbl("1/2", Vector2(330, 910), Vector2(60, 30), 17, DIM, self, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("<", Rect2(8, 960, 56, 60), 28, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _flip(-1))
	_btn(">", Rect2(656, 960, 56, 60), 28, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _flip(1))
	for i in 5:
		var s := CardSlot.new()
		s.position = Vector2(46 + i * 132, 940)
		s.size = Vector2(100, 100)
		s.idx = ""
		s.pressed.connect(func(): _pick_card(str(s.idx)))
		add_child(s)
		_slots.append(s)

func _flip(d: int) -> void:
	_page = (_page + d + 2) % 2
	_refresh_deck()

func _refresh_deck() -> void:
	if _page_lb:
		_page_lb.text = str(_page + 1) + "/2"
	if _deck_count_lb:
		_deck_count_lb.text = "鍗＄粍 " + str(_cards.size()) + "/10"
	for i in _slots.size():
		var s: CardSlot = _slots[i]
		var at := _page * 5 + i
		if at < _cards.size():
			var id := str(_cards[at])
			var c: Dictionary = _card_db[id]
			s.empty = false
			s.idx = id
			s.quality = int(c["quality"])
			s.shiny = bool(c.get("shiny", false))
			s.art = load(str(c["art"]))
			s.queue_redraw()
		else:
			s.empty = true
			s.idx = ""
			s.queue_redraw()

func _pick_card(id: String) -> void:
	if id == "" or not _card_db.has(id): return
	var c: Dictionary = _card_db[id]
	_detail_name.text = str(c["name"])
	_detail_art.texture = load(str(c["art"]))
	_detail_effect.text = str(c["own_text"])
	var prog := _set_progress(str(c["set_id"]))
	_detail_combo.text = str(c["combo_name"]) + " " + str(prog) + "/" + str(c["set_size"])
	_detail_combo_text.text = str(c["trigger"]) + "锛? + str(c["combo_text"])
	var q := clampi(int(c["quality"]) - 1, 0, 4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.86, 0.99)
	sb.set_corner_radius_all(9)
	sb.border_color = QUALITY_COLORS[q]
	sb.set_border_width_all(7)
	_detail_card.add_theme_stylebox_override("panel", sb)
	var set_n := int(c["set_size"])
	for i in _detail_pips.size():
		var pip := _detail_pips[i] as ColorRect
		pip.visible = i < set_n
		pip.color = Color(0.78, 0.58, 0.22) if i < prog else Color(0.42, 0.36, 0.28, 0.3)
	_detail_layer.visible = true
	_detail_layer.move_to_front()

# ---------------- 搴曟爮 ----------------
func _build_bottom() -> void:
	_panel(Rect2(8, 1076, 704, 204), Color(0.075, 0.068, 0.060, 0.98), 10, Color(0.85, 0.66, 0.23, 0.45), 2)
	_lv_lb = _lbl("Lv 1", Vector2(22, 1088), Vector2(70, 28), 18, GOLD)
	_panel(Rect2(96, 1090, 600, 16), Color(0.93, 0.90, 0.82, 0.16), 8)
	_exp_bar = _panel(Rect2(96, 1090, 4, 16), Color(0.85, 0.66, 0.23), 8)
	_exp_lb = _lbl("0/100", Vector2(600, 1088), Vector2(92, 20), 15, Color(0.88, 0.82, 0.70), self, HORIZONTAL_ALIGNMENT_RIGHT)
	_market_tile = _tile(24, 1128, 124, "market", "榛戝競", false)
	_market_tile.visible = LevelState.show_button("market")
	_trea_tile = _tile(158, 1128, 124, "treasure", "瀹濈墿", false)
	_trea_tile.visible = LevelState.show_button("treasure")
	_mate_tile = _tile(292, 1128, 124, "mate", "璇风", false)
	_mate_tile.visible = LevelState.show_button("mate")
	_str_tile = _tile(426, 1128, 124, "skill", "寮哄寲", false)
	# 寮哄寲鍥哄畾闅愯棌锛氭竻瀹岀涓€娉㈢殑鏁欏閭ｄ竴鍒绘墠浜嚭鏉ワ紙涓嶅洜閲嶇帺鑰屾彁鍓嶆樉绀猴級
	_str_tile.visible = false
	_str_tile.hot = false
	_draw_tile = _tile(560, 1116, 136, "draw", "鎶藉崱", true)
	_draw_tile.visible = LevelState.show_button("draw")
	_refresh_level_ui()
	_refresh_str_tile()
	_refresh_trea_tile()

func _tile(x: float, y: float, s: float, kind: String, label: String, hot: bool) -> Tile:
	var t := Tile.new()
	t.position = Vector2(x, y)
	t.size = Vector2(s, s)
	t.kind = kind
	t.label = label
	t.hot = hot
	var hit := func() -> void:
		match kind:
			"draw": _show_draw(true)
			"market": _open_bm()
			"treasure": _on_trea_tile()
			"mate": _on_mate_tile()
			"skill": _on_str_tile()
			_: _toast(label)
	t.pressed.connect(hit)
	add_child(t)
	return t

# 濂囩墿鏂瑰潡锛氳窡銆屾寫鎴樸€嶄竴鏍?96脳96锛屽喎鍗存椂鍘嬫殫 + 鏄剧ず绉掓暟
# 棣栭琛€鏉★細椤堕儴妯潯锛屽甫"鎺夎娈嬪奖"锛坓host 鎱㈡參杩戒笂鏉ワ級
class BossBar extends Control:
	const F := preload("res://fonts/ink.ttf")
	var ratio := 1.0
	var ghost := 1.0
	var bname := ""
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.11, 0.08, 0.90)
		sb.set_corner_radius_all(7)
		sb.border_color = Color(0.62, 0.50, 0.32, 0.95)
		sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var inner := Rect2(3, 3, size.x - 6, size.y - 6)
		# 娈嬪奖锛堟帀涓嬪幓鐨勯偅涓€鎴紝鎱㈡參缂╋級
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(ghost, 0.0, 1.0), inner.size.y)),
			Color(0.88, 0.66, 0.36, 0.38))
		# 褰撳墠琛€閲?		draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(ratio, 0.0, 1.0), inner.size.y)),
			Color(0.70, 0.15, 0.11, 0.98))
		# 鍥涚瓑鍒嗗埢搴︼紙鐪嬪緱鍑鸿繕鍓╁嚑娈碉級
		for i in range(1, 4):
			var tx := inner.position.x + inner.size.x * float(i) / 4.0
			draw_line(Vector2(tx, inner.position.y), Vector2(tx, inner.position.y + inner.size.y),
				Color(0.10, 0.08, 0.06, 0.35), 1.0)
		# 鍚嶅瓧锛堝厛鎻忎竴灞傛殫褰憋紝绾㈠簳/閲戝簳涓婇兘鐪嬪緱娓咃級
		draw_string(F, Vector2(1, size.y * 0.5 + 6), bname,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(0.0, 0.0, 0.0, 0.55))
		draw_string(F, Vector2(0, size.y * 0.5 + 5), bname,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(0.98, 0.94, 0.85))

# 璧勬簮椋炶灞傦細鍑绘潃鎺夌殑閲戝竵/鏅剁煶椋炲悜鍙充笂瑙掕祫婧愭潯锛堝壊鑽夌殑姝ｅ弽棣堬級
class FlyLayer extends Control:
	var dots: Array = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for d_v in dots:
			var d: Dictionary = d_v
			draw_circle(Vector2(float(d["x"]), float(d["y"])), float(d["r"]), d["col"])

class CurioSquare extends Control:
	const F := preload("res://fonts/ink.ttf")
	signal pressed
	var glyph := "澹?
	var label := "濂囩墿"
	var cd_left := 0.0
	var cd_max := 60.0
	var flash := 0.0            # 瑙﹀彂鏃堕棯涓€鍦堥噾鐜?	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.068, 0.060, 0.98))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.66, 0.23, 0.55), false, 2.0)
		var ready := cd_left <= 0.001
		var col := Color(0.91, 0.78, 0.42) if ready else Color(0.52, 0.48, 0.40)
		draw_string(F, Vector2(0, 54), glyph, HORIZONTAL_ALIGNMENT_CENTER, size.x, 38, col)
		draw_string(F, Vector2(0, 84), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, col)
		if not ready:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.02, 0.42))
			draw_string(F, Vector2(0, 62), str(int(ceil(cd_left))), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(0.94, 0.89, 0.78))
		if flash > 0.0:
			var k := 1.0 - flash
			draw_arc(size * 0.5, size.x * (0.5 + 0.30 * k), 0.0, TAU, 32,
				Color(0.98, 0.82, 0.36, flash * 0.9), 3.0)

# 濂囬亣鍦嗛挳锛氬彧鍦ㄦ柊濂囬亣鎺峰埌鏃跺嚭鐜帮紝闈犲湪涓昏宸︿晶锛涗笂闈㈡诞鐫€澶х孩瀛椼€屽閬囷紒銆?class QuestOrb extends Control:
	const F := preload("res://fonts/ink.ttf")
	signal pressed
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(c, r, Color(0.12, 0.09, 0.07, 0.96))
		draw_arc(c, r, 0.0, TAU, 48, Color(0.80, 0.24, 0.18), 3.0)
		draw_arc(c, r - 6.0, 0.0, TAU, 48, Color(0.85, 0.66, 0.23, 0.55), 1.5)
		# 鍗疯酱鍥炬爣
		var w := r * 1.0
		var h := r * 0.66
		var box := Rect2(c - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
		draw_rect(box, Color(0.88, 0.83, 0.70), true)
		draw_rect(box, Color(0.28, 0.20, 0.10), false, 2.0)
		for i in 3:
			var yy := c.y - h * 0.22 + float(i) * h * 0.24
			draw_line(Vector2(c.x - w * 0.30, yy), Vector2(c.x + w * 0.30, yy), Color(0.42, 0.32, 0.18), 1.6)

class Tile extends Control:
	const F := preload("res://fonts/ink.ttf")
	signal pressed
	var kind := "market"
	var label := ""
	var hot := false
	var badge := 1
	var sub := ""          # 灏忓瓧锛堝己鍖栵細Lv 路 浠烽挶锛?	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.48, 0.14, 0.10) if hot else Color(0.09, 0.08, 0.07, 0.98)
		sb.set_corner_radius_all(8)
		sb.border_color = Color(0.95, 0.76, 0.36, 0.95) if hot else Color(0.85, 0.66, 0.23, 0.5)
		sb.set_border_width_all(3 if hot else 1)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c := Vector2(size.x * 0.5, size.y * 0.34)
		var ink := Color(0.93, 0.88, 0.76) if hot else Color(0.88, 0.83, 0.73)
		if kind == "market":
			draw_circle(c, 20, Color(0.88, 0.69, 0.29))
			draw_circle(c, 8, Color(0.09, 0.08, 0.07))
		elif kind == "treasure":
			draw_rect(Rect2(c + Vector2(-24, -10), Vector2(48, 24)), Color(0.88, 0.83, 0.73))
			draw_rect(Rect2(c + Vector2(-24, -16), Vector2(48, 8)), Color(0.88, 0.69, 0.29))
			draw_rect(Rect2(c + Vector2(-4, -4), Vector2(8, 13)), Color(0.09, 0.08, 0.07))
		elif kind == "mate":
			draw_circle(c + Vector2(-11, -7), 9, Color(0.88, 0.83, 0.73))
			draw_circle(c + Vector2(11, -7), 9, Color(0.88, 0.83, 0.73))
			draw_circle(c + Vector2(-11, 13), 12, Color(0.88, 0.83, 0.73))
			draw_circle(c + Vector2(11, 13), 12, Color(0.88, 0.83, 0.73))
		elif kind == "skill":
			draw_rect(Rect2(c + Vector2(-17, -22), Vector2(34, 44)), Color(0.88, 0.83, 0.73))
			draw_rect(Rect2(c + Vector2(-2, -13), Vector2(4, 26)), Color(0.88, 0.69, 0.29))
			draw_rect(Rect2(c + Vector2(-13, -2), Vector2(26, 4)), Color(0.88, 0.69, 0.29))
		else:
			draw_set_transform(c + Vector2(-7, 2), -0.25, Vector2.ONE)
			draw_rect(Rect2(-16, -20, 22, 32), Color(0.93, 0.88, 0.76))
			draw_rect(Rect2(-2, -16, 22, 32), Color(0.88, 0.69, 0.29))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if sub != "":
			draw_string(F, Vector2(0, size.y - 40), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15,
				Color(0.86, 0.70, 0.34) if hot else Color(0.66, 0.59, 0.48))
		draw_string(F, Vector2(0, size.y - 14), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20 if size.x < 130 else 22, ink)
		if hot:
			draw_circle(Vector2(size.x - 15, 15), 11, Color(0.88, 0.69, 0.29))
			draw_string(F, Vector2(size.x - 23, 21), str(badge), HORIZONTAL_ALIGNMENT_CENTER, 18, 17, Color(0.18, 0.10, 0.05))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

# ---------------- 鎶藉崱灞?----------------
func _build_draw() -> void:
	_draw_layer = Control.new()
	_draw_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.visible = false
	_draw_layer.z_index = 20
	add_child(_draw_layer)
	var banner := Panel.new()
	banner.position = Vector2(230, 162)
	banner.size = Vector2(260, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.54, 0.23, 0.10)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.95, 0.76, 0.36, 0.9)
	sb.set_border_width_all(2)
	banner.add_theme_stylebox_override("panel", sb)
	_draw_layer.add_child(banner)
	_breathe(banner)
	_lbl("鎶藉崱 路 20 鐏垫櫠", Vector2(0, 0), Vector2(260, 42), 20, Color(0.97, 0.90, 0.74), banner, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("闅愯棌", Rect2(620, 162, 72, 32), 17, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _show_draw(false), _draw_layer)
	for i in 3:
		var d := DrawCard.new()
		d.position = Vector2(30 + i * 220, 220)
		d.set_meta("base", d.position)
		d.pivot_offset = Vector2(100, 150)
		d.size = Vector2(200, 300)
		d.picked.connect(func() -> void: _on_draw_pick(d))
		_draw_layer.add_child(d)
		_draw_cards.append(d)
	_draw_refresh_btn = _btn("鍒锋柊 路 5 鐏垫櫠", Rect2(250, 540, 220, 56), 20, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _on_refresh(), _draw_layer)

func _roll_draw() -> void:
	var cands: Array = []
	for id_v in _pool:
		if _family_card_allowed(str(id_v)):
			cands.append(id_v)
	# 绗洓鍏虫殫鎶嵄閫旂嚎锛氬嵄闄╁崱鍦ㄦ娊鍗℃睜閲屾潈閲?脳2锛岀帺瀹舵洿瀹规槗鎽稿埌澧炴€?鎸戞垬鏀剁泭
	if LevelState.current_level == 4:
		var weighted: Array = []
		for id_v in cands:
			weighted.append(id_v)
			var sid := str(id_v)
			if sid.begins_with("swarm_") or sid.begins_with("peril_"):
				weighted.append(id_v)
		cands = weighted
	# 鏉€鏁岀浉鍏冲崱锛堢粡楠岀郴锛夋潈閲?脳2
	var killw: Array = []
	for id_v in cands:
		killw.append(id_v)
		var kc: Dictionary = _card_db.get(str(id_v), {})
		if str(kc.get("series", "")) == "exp":
			killw.append(id_v)
	cands = killw
	# 璇风鍚庯細璇ョ瀹楃殑瀹朵紶鍗℃潈閲嶅彉澶?	if not _ancestors.is_empty():
		var fam: Array = []
		for id_v in cands:
			fam.append(id_v)
			var cc: Dictionary = _card_db.get(str(id_v), {})
			if str(cc.get("ancestor", "")) != "":
				fam.append(id_v)
		cands = fam
	# 绗節鍏筹細涓昏瀹朵紶鏉冮噸鍐嶆姮涓€妗?	if LevelState.current_level == 9:
		var zj: Array = []
		for id_v in cands:
			zj.append(id_v)
			var zc: Dictionary = _card_db.get(str(id_v), {})
			if str(zc.get("ancestor", "")) == "zhujue":
				zj.append(id_v)
		cands = zj
	cands.shuffle()
	# v4 鐐崱楂樻潈閲嶏細姹犻噷鏈夌偒鍗℃椂 80% 鐩存帴鎺掑埌绗竴寮?	var shiny_id := ""
	for pid_v in _pool:
		var pid := str(pid_v)
		if pid.begins_with("shiny_"):
			shiny_id = pid
			break
	if shiny_id != "" and randf() < 0.80:
		cands.erase(shiny_id)
		cands.push_front(shiny_id)
	# 绗簲鍏筹細绗簩缁勫浼犲悗锛屼笅涓€鎵嬪繀鍑哄叾涓竴浣嶈绁炵殑鐐僵鍗?	if _family_shiny_ready:
		_family_shiny_ready = false
		_family_shiny_done = true
		var sids: Array = []
		for a_v in _ancestors.keys():
			var s := "shiny_" + str(a_v)
			if _card_db.has(s) and not _acquired.has(s) and not _shiny_used.has(str(a_v)):
				sids.append(s)
		if not sids.is_empty():
			var sid := str(sids[randi() % sids.size()])
			if not _pool.has(sid):
				_pool.append(sid)
			cands.erase(sid)
			cands.push_front(sid)
			_toast("鐐僵鍗＄幇涓?)
	# 鍚屼竴鎵嬩笉閲嶅鍑哄悓涓€寮犲崱锛堟睜閲岃嫢鏈夐噸澶?id锛岃繖閲屽厹浣忥級
	var uniq: Array = []
	for id_u in cands:
		var su := str(id_u)
		if uniq.has(su):
			continue
		uniq.append(su)
		if uniq.size() >= _draw_cards.size():
			break
	cands = uniq
	for i in _draw_cards.size():
		var dc: DrawCard = _draw_cards[i]
		if i < cands.size():
			var c: Dictionary = (_card_db[str(cands[i])] as Dictionary).duplicate()
			c["_id"] = str(cands[i])
			dc.data = c
			dc.progress = _set_progress(str(c.get("set_id", "")))
		else:
			dc.data = {}
			dc.progress = 0
		dc.queue_redraw()
	# v4 褰╄泲锛氳繖涓夊紶閲屾湁鏌愪綅绁栧畻鐨勫浼犲崱 鈫?4% 鎺蜂粬鐨勭偒鍗?	_roll_shiny_check(cands.slice(0, _draw_cards.size()))

# 褰╄泲鍒ゅ畾锛氬彧鍦ㄣ€屾娊鍒拌绁栧畻鐨勫浼犲崱銆嶆椂鎺凤紝涓€灞€姣忎綅涓€娆?func _roll_shiny_check(cards: Array) -> void:
	for cid_v in cards:
		var c: Dictionary = _card_db.get(str(cid_v), {})
		if not c.has("ancestor") or bool(c.get("shiny", false)):
			continue
		var aid := str(c["ancestor"])
		if _shiny_used.has(aid) or _shiny_rolled.has(aid):
			continue
		var shiny_p := 0.04
		if LevelState.current_level == 9 and aid == "zhujue":
			shiny_p = 0.20   # 绗節鍏冲彧瀵逛富瑙掔偒褰╁崱澶у箙鎻愬崌
		if randf() < shiny_p:
			_shiny_rolled[aid] = true
			var sid := "shiny_" + aid
			if _card_db.has(sid) and not _pool.has(sid):
				_pool.append(sid)
				_toast("褰╄泲锛佺偒褰╁崱銆?s銆嶅凡鍔犲叆鍗℃睜" % str((_card_db[sid] as Dictionary)["name"]))
				Aud.sfx("ult_ready", -4.0)

func _update_crystal() -> void:
	if _crystal_lb != null:
		_crystal_lb.text = str(_crystal)

func _show_draw(v: bool) -> void:
	if v and _run_over:
		return
	if v:
		_hide_aug_pick()                     # 杩涢樁椤靛紑鐫€涓€骞舵敹鎺?		_hide_trea()                         # 瀹濈墿椤靛悓鐞?		if not _draw_paid:
			if _pool.is_empty():
				_toast("鏈眬鍗℃睜宸茬┖")
				return
			if _crystal < 20:
				_toast("鐏垫櫠涓嶈冻锛屼笉瓒充互鎶藉崱锛堜竴娆¤ 20锛?)
				return
			_crystal -= 20
			_update_crystal()
			_roll_draw()
			_draw_paid = true
		_draw_open = true
		_draw_layer.visible = true
		_layer_in(_draw_layer)
		_draw_layer.move_to_front()
		_pop_draw_cards()
	else:
		_draw_layer.visible = false
		_draw_open = false

func _on_draw_pick(card: DrawCard) -> void:
	if _run_over or not _draw_paid or _draw_layer == null or not _draw_layer.visible:
		return
	if _draw_anim or card == null or not _draw_cards.has(card) or card.data.is_empty(): return
	var id := str(card.data.get("_id", ""))
	if id == "": return
	if _cards.size() >= 10:
		_toast("鍗＄粍宸叉弧锛?0 鏍硷級")
		return
	_draw_anim = true
	var target := Vector2(46 + float(_cards.size() % 5) * 132.0, 870)
	for other in _draw_cards:
		MenuUI.Motion.stop(other)
		if other != card:
			other.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tw0 := create_tween()
			tw0.tween_property(other, "modulate:a", 0.28, 0.18)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 3
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "position", target, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "scale", Vector2(0.36, 0.36), 0.34)
	tw.tween_property(card, "modulate:a", 0.42, 0.34)
	tw.chain().tween_callback(func() -> void:
		_draw_anim = false
		if _run_over:
			return
		_add_card(id)
		_zhongli_try(id))

func _refresh_draw_btn() -> void:
	if _draw_refresh_btn != null:
		_draw_refresh_btn.text = "鍒锋柊 路 鍏嶈垂 %d 娆? % _draw_free if _draw_free > 0 else "鍒锋柊 路 5 鐏垫櫠"

func _on_refresh() -> void:
	if _run_over or _draw_anim or not _draw_paid or _draw_layer == null or not _draw_layer.visible: return
	if _pool.is_empty():
		_toast("鍗℃睜宸茬┖锛屾病娉曞埛鏂?)
		return
	var paid := true
	if _draw_free > 0:
		_draw_free -= 1
		paid = false
	else:
		if _crystal < 5:
			_toast("鐏垫櫠涓嶅锛氬埛鏂拌 5")
			return
		paid = not _rr_free()
	if paid:
		_crystal -= 5
		_update_crystal()
	_refresh_draw_btn()
	_draw_anim = true
	for card in _draw_cards:
		MenuUI.Motion.stop(card)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "scale", Vector2(0.72, 0.72), 0.16)
		tw.tween_property(card, "modulate:a", 0.0, 0.16)
	await get_tree().create_timer(0.2).timeout
	if _run_over:
		_draw_anim = false
		return
	_roll_draw()
	_draw_anim = false
	_pop_draw_cards()
	_toast("鍒锋柊锛? 鐏垫櫠" if paid else "鍏嶈垂鍒锋柊")

func _pop_draw_cards() -> void:
	for i in _draw_cards.size():
		var card: DrawCard = _draw_cards[i]
		var base: Vector2 = card.get_meta("base", Vector2(30 + i * 220, 220))
		card.visible = true
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		MenuUI.Motion.pop(card, true, i * 0.055, base, (i - 1) * 0.025)

# ---------------- 灞炴€?----------------
# v6锛氳缁嗗睘鎬ч〉锛坘ushou/attr_panel.gd锛夛紝鎳掑姞杞戒竴娆★紝涔嬪悗澶嶇敤
var _attr_page = null

func _open_attr_page() -> void:
	if _core == null:
		return
	if _attr_page == null:
		_attr_page = load("res://kushou/attr_panel.gd").new()
		add_child(_attr_page)
		_attr_page.z_index = 60
	_attr_page.setup(_core)
	_attr_page.open()


# v6锛氭柊灞炴€у眰 鈫?鏃?hero 瀛楁锛坅tk / hp锛夈€傛妧鑳姐€佸彫鍞ょ墿銆侀《閮ㄨ鏉¤繕鍦ㄨ鏃у瓧娈点€?# 涓存椂璇婃柇锛氳嫳闆勪负浠€涔堜笉鍑烘墜锛堟瘡 2 绉掍竴琛岋級
var _dbg_atk_t := 0.0
func _dbg_hero_attack(dt: float) -> void:
	if _core == null:
		return
	# 榛樿鍏抽棴锛涢渶瑕佹帓鏌ユ椂璁剧幆澧冨彉閲?DSH_DEBUG=1
	if OS.get_environment("DSH_DEBUG") == "":
		return
	_dbg_atk_t += dt
	if _dbg_atk_t < 2.0:
		return
	_dbg_atk_t = 0.0
	var h: Dictionary = _core.hero
	var t: Dictionary = _core._order_target()
	var tp := Vector2(float(t.get("x", 0.0)), float(t.get("y", 0.0))) if not t.is_empty() else Vector2.ZERO
	print("[ATK] lv=", LevelState.current_level, " wave=", _core.wave, "/", _max_wave, " kills=", _kills,
		" running=", _core.running, " proc=", _core.is_processing(), " selfproc=", is_processing(),
		" hp=", int(float(h.get("hp", 0.0))), "/", int(float(h.get("hp_max", 0.0))),
		" atk=", snappedf(float(h.get("atk", 0.0)), 0.1), " aspd=", snappedf(float(h.get("aspd", 0.0)), 0.01),
		" cd=", snappedf(float(_core._hero_cd), 0.01),
		" tgt=", not t.is_empty(), " dist=", snappedf(_core.hero_pos.distance_to(tp), 0.1),
		" foes=", _core.foes.size(), " live=", _core.live_foes())

func _sync_attrs_to_hero() -> void:
	if _core == null:
		return
	var h: Dictionary = _core.hero
	h["atk"] = _core.attr_final("atk")
	h["basic_skill_bonus"] = _skill_level_bonus("zhujue") / 100.0
	_sync_basic_family_bonus()
	h["crit"] = _core.attr_final("crit")
	h["crit_dmg"] = _core.attr_final("cdmg")
	h["cut"] = _core.type_effective_field("鐗╃悊", "red_f")
	h["cut_all"] = 0.0
	h["dmg_all"] = _core.type_amp("鐗╃悊")
	h["aspd"] = minf(MAX_ASPD, _core.attr_final("aspd") / float(_core.ATTR_BASE["aspd"]))
	var mp_new: float = float(_core.attr_final("mp"))
	h["mp_max"] = mp_new
	h["mp"] = minf(mp_new, _mp)
	_mp_max = mp_new
	_mp = minf(_mp_max, _mp)
	var hp_new: float = float(_core.attr_final("hp"))
	var ratio := 1.0
	if float(h.get("hp_max", 1.0)) > 0.0:
		ratio = clampf(float(h.get("hp", 0.0)) / float(h.get("hp_max", 1.0)), 0.0, 1.0)
	h["hp_max"] = hp_new
	h["hp"] = minf(hp_new, hp_new * ratio)

func _sync_basic_family_bonus() -> void:
	if _core != null:
		_core.hero["basic_family_bonus"] = float((_anc_mod.get("zhujue", {}) as Dictionary).get("dmg_pct", 0.0)) / 100.0

# 骞冲姞鎴愰暱鐨勫嵆鏃舵ˉ涔熻灞炴€у眰銆傜瓑绾ф垚闀夸繚鐣欒閲忔瘮渚嬶紝鍗＄墝骞冲姞姘旇淇濈暀琛ユ柊澧為噺鐨勮鍒欍€?func _apply_flat_growth(atk_add: float, hp_add: float, preserve_hp_ratio := false) -> void:
	if _core == null: return
	var h: Dictionary = _core.hero
	var old_max := float(h.get("hp_max", 0.0))
	var old_hp := float(h.get("hp", 0.0))
	var ratio := clampf(old_hp / maxf(1.0, old_max), 0.0, 1.0)
	_core.attr_add("atk", atk_add)
	_core.attr_add("hp", hp_add)
	h["atk"] = _core.attr_final("atk")
	h["hp_max"] = _core.attr_final("hp")
	if preserve_hp_ratio:
		h["hp"] = float(h["hp_max"]) * ratio
	else:
		h["hp"] = minf(old_hp, float(h["hp_max"]))
		_core.heal_hero(maxf(0.0, float(h["hp_max"]) - old_max))


# ---------------- 閫€鍑?----------------
func _build_exit() -> void:
	_exit_layer = Control.new()
	_exit_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_layer.visible = false
	_exit_layer.z_index = 30
	add_child(_exit_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_layer.add_child(dim)
	var p := Panel.new()
	p.position = Vector2(150, 500)
	p.size = Vector2(420, 220)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.86)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(0.85, 0.66, 0.23, 0.8)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	_exit_layer.add_child(p)
	_lbl("鏄惁閫€鍑猴紵", Vector2(0, 34), Vector2(420, 40), 26, INK, p, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl("閫€鍑哄悗鏈眬浣滃簾锛屽鍔变笉淇濈暀", Vector2(0, 78), Vector2(420, 30), 17, SEAL, p, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("缁х画鎴樻枟", Rect2(60, 130, 150, 48), 18, Color(0.09, 0.08, 0.07, 0.98), LIGHT, func(): _show_exit(false), p)
	_btn("閫€鍑?, Rect2(220, 130, 140, 48), 18, Color(0.48, 0.14, 0.10), Color(0.97, 0.90, 0.74), func(): _quit(), p)

func _show_exit(v: bool) -> void:
	_exit_open = v
	_exit_layer.visible = v
	if v:
		_exit_layer.move_to_front()

func _quit() -> void:
	if _run_over or not MenuUI.navigation_available(self): return
	if MenuUI.navigate(self, "res://menu/main_home.tscn") == OK:
		# 鍦烘櫙浼氬欢杩熼噴鏀撅紱绂绘爲鍚庣珛鍗虫嫆缁濇棫濂栧姳鍜岀粨绠楀洖璋冦€?		_run_over = true
		if _core != null:
			_core.running = false
		if _tut != null:
			_tut.cancel()

# ---------------- 鎻愮ず/鍔ㄧ敾 ----------------
func _build_toast() -> void:
	_toast_lb = RichTextLabel.new()
	_toast_lb.bbcode_enabled = true
	_toast_lb.fit_content = false
	_toast_lb.scroll_active = false
	_toast_lb.position = Vector2(0, 620)
	_toast_lb.size = Vector2(720, 48)
	_toast_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_lb.add_theme_font_override("normal_font", FONT)
	_toast_lb.add_theme_font_size_override("normal_font_size", 26)
	_toast_lb.add_theme_color_override("default_color", INK)
	_toast_lb.visible = false
	_toast_lb.z_index = 40
	add_child(_toast_lb)

func _toast_card(name: String, quality: int, tail: String) -> void:
	var col: String = QUALITY_COLORS[clampi(quality - 1, 0, 4)].to_html(false)
	_toast("[color=#" + col + "]" + name + "[/color]銆€" + tail)

func _process(_delta: float) -> void:
	if _run_over:
		_tick_fly(_delta)
		_tick_pulses(_delta)
		return
	var _t_proc := Time.get_ticks_usec()
	var t := Time.get_ticks_msec() / 1000.0
	for i in _enemies.size():
		var e: Control = _enemies[i]
		e.position.y = float(e.get_meta("base_y", e.position.y)) + sin(t * 1.6 + i) * 2.0
	if _core != null:
		# v6锛氭柊灞炴€у眰鏄粨绠楁簮锛涙瘡甯ф妸鏀诲嚮/姘旇鍥炲啓鍒版棫 hero锛岀粰鎶€鑳?鍙敜鐗?椤堕儴琛€鏉¤
		_sync_attrs_to_hero()
		_dbg_hero_attack(_delta)
		if int(_core.wave) != _last_wave:
			_last_wave = int(_core.wave)
			_trigger_combos("姣忔尝")
		# 鏈€鍚庝竴娉細鍏堟妸灏忔€竻瀹岋紝Boss 鎵嶇櫥鍦猴紙涓嶅悓鏃跺嚭鐜帮級
		if int(_core.wave) >= _max_wave:
			_core.boss_required = true
		if not _boss_spawned and not _run_cleared and int(_core.wave) >= _max_wave 				and _core._wave_spawned >= _core._wave_quota and _core.live_foes() <= 0:
			_boss_spawned = true
			_core.start_boss(LevelState.boss_tier(), "")
		_run_time += _delta
		_combo_t += _delta
		if _combo_t >= 6.0:
			_combo_t -= 6.0
			_trigger_combos("姣?6 绉?)
		if _wave_lb != null:
			_wave_lb.text = "娉?%d/%d" % [int(_core.wave), _max_wave]
		# v2 娉㈡鎺ㄨ繘锛氭湰娉㈠畾棰濆埛瀹?+ 鍦轰笂娓呯┖ 鈫?杩涗笅涓€娉紱婊?MAX_WAVE 鏀跺伐
		if not _run_cleared and _core.wave_cleared():
			var cleared_wave := int(_core.wave)
			if cleared_wave < _max_wave:
				_core.set_wave(cleared_wave + 1)
				_core.wave_reset_quota()
				_spawn_typed_foes()
				_on_wave_clear(cleared_wave)
			else:
				_run_cleared = true
				_on_wave_clear(cleared_wave)
				_end_run(true)
				return
		if _hp_lb != null:
			_hp_lb.text = "%d/%d" % [int(float(_core.hero.get("hp", 0))), int(float(_core.hero.get("hp_max", 1)))]
		var hpr := clampf(float(_core.hero.get("hp", 0.0)) / maxf(1.0, float(_core.hero.get("hp_max", 1.0))), 0.0, 1.0)
		if LevelState.current_level >= 2 and LevelState.current_level <= 4:
			# 涓嶆敼鎬潰鏉匡紝鍙伔鍋峰姞鏄撲激锛氭垚闀?瀹朵紶缁勫悎缁欒冻锛岀粡娴?鍗遍€旂粰灏戜竴鐐?			var vuln := _equip_vuln
			for rec in _combined:
				var s := str(rec.get("series", ""))
				if s in ["gold", "crystal", "exp", "bounty"]:
					vuln += 0.06
				elif s in ["swarm", "peril"]:
					vuln += 0.10
				else:
					vuln += 0.15
			vuln += float(_ancestor_combos.size()) * 0.15
			_core.foe_vuln = minf(0.45, vuln)
		elif LevelState.current_level == 7:
			# 绗竷鍏筹細鎶€鑳藉崌绾ц繃锛屾€伔鍋峰悆鏇村浼ゅ锛涙病鍗囩骇涔熻兘杩囷紝鍙槸鍚冨姏
			var skill_total := 0
			for v in GameState.skill_lv.values():
				skill_total += int(v)
			_core.foe_vuln = minf(0.30, float(skill_total) * 0.015 + _equip_vuln)
		elif LevelState.current_level == 8:
			# 绗叓鍏筹細灞€澶栬澶囧己鍖栬秺楂橈紝鎬伔鍋疯秺鑴嗭紱鍥涗欢 +20 鍏?80 绾?鈫?20% 鏄撲激
			var FD8 := preload("res://shared/forge_data.gd")
			var plus_total := 0
			for slot_v in FD8.SLOT_KEYS:
				plus_total += int((FD8.equipped.get(str(slot_v), {}) as Dictionary).get("plus", 0))
			_core.foe_vuln = minf(0.35, float(plus_total) * 0.0025 + _equip_vuln)
		elif _equip_vuln > 0.0:
			_core.foe_vuln = minf(0.45, _equip_vuln)
		if int(_core.wave) >= 2 and hpr <= 0.50:
			if LevelState.current_level == 1 and not _l1_yuhu_shown:
				_l1_yuhu_shown = true
				_l1_tutorial("l1_yuhu", _curio_sq, "姘旇涓嶈冻鏃讹紝鐜夊６浼氳嚜鍔ㄥ洖琛€", _show_curio_detail)
		_tick_rare_buffs(_delta) # 鍒版湡鍏堢Щ闄わ紝鍐嶇粨绠楁湰甯ф妧鑳斤紝涓嶈兘澶氬€熺敤涓€甯ф敾鍑汇€?		if _hp_fill != null:
			_hp_fill.size = Vector2(maxf(4.0, 235.0 * hpr), 20.0)
			_tick_skills(_delta)
		_tick_curio(_delta)
		_tick_fly(_delta)
		_tick_pulses(_delta)
		if not _recycle_q.is_empty():
			for i in range(_recycle_q.size() - 1, -1, -1):
				var it: Array = _recycle_q[i]
				var tkq = it[0]
				if not is_instance_valid(tkq):
					_recycle_q.remove_at(i)
					continue
				it[1] = float(it[1]) - _delta
				if float(it[1]) <= 0.0:
					tkq.reset_pose()
					tkq.visible = false
					if _foe_pool.size() < 40:
						_foe_pool.append(tkq)
					else:
						tkq.queue_free()
					_recycle_q.remove_at(i)
		if _boss_bar != null:
			var bf: Dictionary = _core._boss_foe() if _core != null else {}
			_boss_on = not bf.is_empty()
			if bf.is_empty():
				if _boss_bar.visible:
					_boss_bar_t = maxf(0.0, _boss_bar_t - _delta)
					if _boss_bar_t <= 0.0:
						_boss_bar.visible = false
			else:
				_boss_bar.visible = true
				_boss_bar_t = 1.2
				var rr := clampf(float(bf["hp"]) / maxf(1.0, float(bf["hp_max"])), 0.0, 1.0)
				var need := false
				if absf(rr - float(_boss_bar.ratio)) > 0.0005:
					_boss_bar.ratio = rr
					need = true
				if float(_boss_bar.ghost) > rr:
					_boss_bar.ghost = move_toward(float(_boss_bar.ghost), rr, _delta * 0.45)
					need = true
				elif not is_equal_approx(float(_boss_bar.ghost), rr):
					_boss_bar.ghost = rr
					need = true
				var nm := str(bf.get("name", "棣栭"))
				if nm != _boss_bar.bname:
					_boss_bar.bname = nm
					need = true
				if need:
					_boss_bar.queue_redraw()
		if _core != null:
			var cb := int(_core._combo)
			if _combo_readout != null:
				_combo_readout.update_combo(cb, float(_core._combo_t))
			if cb != _last_combo:
				if cb > _last_combo and cb % 10 == 0:
					_spawn_pfx("holy/sunburst", _hero_screen(), 1.05, "gold", 1.9)
					_core._shake = maxf(float(_core._shake), 7.0)
				_last_combo = cb
		if not _tick_battle_effects(_delta):
			return
		if _hero_token != null:
			_hero_token.position = _core.position + _core.hero_pos
			var hpr_tok := float(_core.hero.get("hp", 0.0)) / maxf(1.0, float(_core.hero.get("hp_max", 1.0)))
			if absf(hpr_tok - float(_hero_token.hp_ratio)) > 0.0015:
				_hero_token.hp_ratio = hpr_tok
				_hero_token.queue_redraw()
			if _hero_hit_btn != null:
				_hero_hit_btn.position = _hero_token.position - Vector2(48, 48)
			if _hero_name_lb != null:
				_hero_name_lb.position = _hero_token.position + Vector2(-60, 52)
			var hhp := float(_core.hero.get("hp", 0.0))
			if _prev_hero_hp >= 0.0 and hhp < _prev_hero_hp - 0.05:
				_spawn_hit_fx(_hero_token.position, _hero_token.radius,
					int(round(_prev_hero_hp - hhp)), true, false, false)
				_hero_token.play_hit()
			_prev_hero_hp = hhp
		var active := {}
		if _no_tokens:
			for i in range(_enemies.size() - 1, -1, -1):
				_enemies[i].queue_free()
			_enemies.clear()
			for tid0 in _foe_tokens.keys():
				var tk0 = _foe_tokens[tid0]
				if tk0 != null:
					tk0.queue_free()
			_foe_tokens.clear()
		for f in (_core.foes if not _no_tokens else []):
			if not f.has("_tid"):
				_foe_seq += 1
				f["_tid"] = _foe_seq
				_foe_tokens[_foe_seq] = _make_foe_token(f)
			var tid: int = int(f["_tid"])
			active[tid] = true
			var tk = _foe_tokens.get(tid)
			if tk != null:
				tk.position = _core.position + Vector2(float(f["x"]), float(f["y"]))
				var hr := float(f["hp"]) / maxf(1.0, float(f["hp_max"]))
				if absf(hr - float(tk.hp_ratio)) > 0.0015:
					tk.hp_ratio = hr
					tk.queue_redraw()
				var uname := str(f.get("name", ""))
				if uname != tk.unit_name:
					tk.unit_name = uname
					tk.queue_redraw()
				if bool(f.get("_death_settled", false)):
					tk.play_down()
				tk.visible = float(f.get("y", 0.0)) >= 90.0 and not tk.death_finished()
		for tid in _foe_tokens.keys():
			if not active.has(tid):
				var tk = _foe_tokens[tid]
				if tk != null:
					tk.play_down()
					_recycle_q.append([tk, TokenActor.DEATH_DURATION + 0.04])
					# 闃典骸灏忕垎鐐癸紙鍓茶崏鎰燂細姣忔潃涓€鍙兘鏈変竴鍙ｏ級
					if randf() < (0.40 if _boss_on else 0.60):
						_spawn_pfx("impacts/blunt-hit", tk.position + Vector2(0, -8), 0.60, "dust", 1.1, 1.15)
					# 寰】甯э紜杩炴潃杞婚渿锛氭瘡鏉€涓€鍙兘"椤夸竴涓?
					_core._hitstop = maxf(float(_core._hitstop), 0.030)
					if int(_core._combo) >= 5:
						_core._shake = maxf(float(_core._shake), 2.5)
				_foe_tokens.erase(tid)
	var _el := Time.get_ticks_usec() - _t_proc
	if _el > 50000:
		print("[SLOW] battle_ui ", _el / 1000.0, " ms")

func _on_core_kill(n: int) -> void:
	if _run_over or _core == null or n <= 0:
		return
	_curio_on_kill(n)                        # 濂囩墿锛氶唹缈佸６锛堝嚮鏉€绱锛?	# v15 缁忛獙绾匡細鏉€ 1 鍙寜 1+x% 鍙畻锛堢粡楠屼笌鎵€鏈夋寜鍑绘潃鎴愰暱鐨勬満鍒朵竴璧峰悆锛?	var kn := int(round(float(n) * (1.0 + _killnum_pct / 100.0)))
	if kn < n:
		kn = n
	_kills += kn
	_qc("kill", kn)
	if _kill_lb != null:
		_kill_lb.text = str(_kills)
	_pulse_chip(_kill_lb)
	_spawn_fly(_hero_screen() + Vector2(0, -26), Vector2(447, 40), Color(0.80, 0.36, 0.24), 2)
	if _bm != null and LevelState.show_button("market"):
		_bm.add_kill(kn)   # 榛戝競娌″紑鏀惧墠涓嶅杺鏉€鏁屾暟锛岄伩鍏嶅紑灞€寮光€滈粦甯傚崌鍒?Lv鈥?	_add_exp(20 * kn)                      # v2锛氭潃 1 鍙?+20 缁忛獙
	_add_wen(int(round(float(WEN_KILL_BASE + WEN_KILL_WAVE * int(_core.wave)) * (1.0 + _kill_pct / 100.0))))
	if LevelState.current_level == 2:
		_gain_crystal(1)   # 鍙湁绗簩鍏抽潬鏅€氬嚮鏉€琛ョ伒鏅讹紱绗笁鍏宠捣璁╃粡娴庣嚎璇磋瘽
	if _qianzhi:
		for i in kn:
			_core.summon_minion("绾镐汉", Color(0.95, 0.93, 0.86), 0.72, 0.5, 8.0 / 30.0, 1.0, 0.0, 99, "", "paper")
	if _undying_lamp:
		_lamp_kills += kn
		while _lamp_kills >= 5:
			_lamp_kills -= 5
			_aura_extra_radius += 10.0
	if _fentian:
		_ft_kills += kn
		while _ft_kills >= 15:
			_ft_kills -= 15
			_devour_random()
	if _swallow_sea:
		_ss_kills += kn
		while _ss_kills >= 10:
			_ss_kills -= 10
			_ss_pct += 4.0
			_toast("鍚炴捣 路 铔熼緳灞炴€?+4%%锛堢疮璁?%d%%锛? % int(_ss_pct))
	_trigger_combos("姣忔鍑绘潃")

# ---------------- 缁忛獙 / 绛夌骇 / 璇风娆℃暟 ----------------
#   鏉€ 1 鍙?+20 路 娓呬竴娉?+50 路 鍗囩骇闇€姹?100 + 50脳(绾?1)
#   姣忓崌 1 绾?鈫?璇风娆℃暟 +1 鈫?搴曟爮銆岃绁炪€嶉挳浜捣
func _add_exp(v: int) -> void:
	if v <= 0:
		return
	_exp += int(round(float(v) * (1.0 + _exp_pct / 100.0)))
	var up := 0
	var god := 0
	# 绛夌骇涓嶈纭笂闄愶細姝ｅ父缁忛獙鍒伴€氬叧澶х害 20 绾э紱璇风娆℃暟鍙︽湁 god_cap 绠?	while _exp >= _exp_need:
		_exp -= _exp_need
		_lv += 1
		_exp_need += 50
		_level_bonus(1)               # 姣忕骇锛氭敾鍑?+1 路 姘旇涓婇檺 +6锛堝唴鍔涗笂闄愬悓姝?+25锛?		if _lv % 5 == 0:
			_draw_charge += 1   # 姣?5 绾х粰涓€娆★紱鍏佽婧㈠嚭锛屽悗闈㈣绁炲€欓€夌敤瀹屽氨鏀掔潃
			if LevelState.has_feature("mate") and not _l5_mate_shown:
				_l5_mate_shown = true
				_tutorial("l5_mate", _mate_tile, "鍗囩骇鍙互閫夎绁烇紝甯﹀浼犲崱", func() -> void: pass)
			god += 1
		up += 1
	_qc("lv", up)
	if up > 0:
		_choice_fx("lv")
	_refresh_level_ui()
	if up > 0:
		var msg := "鍗囧埌 Lv %d 路 鏀?%d 路 琛€+%d" % [_lv, up, up * 6]
		if god > 0:
			msg += " 路 璇风 +%d" % god
		_toast(msg)

# 鍗囩骇缁欏睘鎬э紙鍙湪鏈眬鐢熸晥锛夛細鏀诲嚮 +1 路 姘旇涓婇檺 +6 路 鍐呭姏涓婇檺 +25
func _level_bonus(n: int) -> void:
	if _core == null or n <= 0:
		return
	var h: Dictionary = _core.hero
	var add_atk := 1.0 * float(n)
	var add_hp := 6.0 * float(n)
	_apply_flat_growth(add_atk, add_hp, true)
	_core.attr_add("mp", 25.0 * float(n))
	h["mp_max"] = _core.attr_final("mp")
	_stats["atk"] = float(_stats["atk"]) + add_atk
	_stats["hp"] = float(_stats["hp"]) + add_hp

func _refresh_level_ui() -> void:
	if _lv_lb != null:
		_lv_lb.text = "Lv " + str(_lv)
	if _exp_lb != null:
		_exp_lb.text = "%d/%d" % [_exp, _exp_need]
	if _exp_bar != null:
		var r := clampf(float(_exp) / maxf(1.0, float(_exp_need)), 0.0, 1.0)
		_exp_bar.size = Vector2(maxf(4.0, 600.0 * r), 16.0)
	if _mate_tile != null:
		var lit := _draw_charge > 0
		if _mate_tile.hot != lit:
			_mate_tile.hot = lit
			_mate_tile.queue_redraw()
		_mate_tile.badge = _draw_charge

# ============================================================
# 褰撳眬鐢熷懡锛氫富瑙掑€掍笅 = 杩欎竴娉㈡病鎵撲笅鏉ワ紝涓嶆槸鐩存帴缁撴潫
#   鎵ｅ懡锛堟寜鍓╀綑鎬潈閲嶏級鈫?鎬叏娓咃紙鏃犳帀钀?鏃犵粡楠岋級鈫?杩囨尝涓旀棤濂栧姳
#   鈫?鎸戞垬鍏ㄩ儴杩涘喎鍗?鈫?涓昏婊¤绔欒捣鏉?鈫?鍛?<= 0 鎵嶇粨绠?# ============================================================
const CHAL_BASE_CD := [25.0, 30.0, 30.0, 90.0, 150.0]
const CHAL_MIN_WAVE := [1, 1, 2, 3, 5]

func _chal_base_cd(i: int) -> float:
	return float(CHAL_BASE_CD[clampi(i, 0, CHAL_BASE_CD.size() - 1)])

# 鎸戞垬鍏ㄩ儴杩涘喎鍗达紙澶辫触鎯╃綒 + 鏈眬缁撴潫鏃朵篃椤烘墜璋冿級
func _chal_all_cd() -> void:
	for i in _chal_cd.size():
		_chal_cd[i] = maxf(float(_chal_cd[i]), _chal_base_cd(i))

# 涓€鍙€姌绠楀灏?鍛?锛氬皬鎬?1 路 鎸戞垬缇ゆ€?2 路 鎸戞垬澶ф€?5 路 棣栭 10
func _foe_life_weight(f: Dictionary) -> int:
	if f.has("chal"):
		return 5 if int(f["chal"]) >= 3 else 2
	if bool(f.get("boss", false)):
		return 10
	return 1

func _refresh_life_ui() -> void:
	if _life_lb == null:
		return
	_life_lb.text = str(_life)
	_life_lb.add_theme_color_override("font_color",
		Color(0.86, 0.24, 0.18) if _life <= 20 else Color(0.95, 0.91, 0.83))

func _on_hero_down() -> void:
	if _run_over:
		return
	# 濂囩墿路绾镐汉鏇胯韩锛氭浛浣犳尅涓€娆¤嚧鍛戒激瀹筹紙涓嶆墸鍛姐€佷笉娓呭満锛?	if _curio_id == "zhiren" and _zhiren > 0:
		_set_paper_count(_zhiren - 1)
		_core.hero["hp"] = float(_core.hero.get("hp_max", 1.0))
		_core.running = true
		_curio_uses += 1
		var epoch: int = _core._enemy_attack_epoch
		_paper_shatter()
		if not _skill_batch_active(epoch):
			return
		_curio_flash()
		_toast("绾镐汉鏇胯韩 路 鎸′綇鑷村懡涓€鍑伙紙鍓?%d锛? % _zhiren)
		Aud.sfx("paper", -6.0, 1.0)
		_spawn_pfx("holy/heal", _hero_screen(), 1.0, "heal", 1.5)
		return
	# 瑁呭鍏嶆蹇呴』鍦ㄦ墸鍛藉拰娓呭満鍓嶅鐞嗭紝涓嶈兘渚濊禆姝讳骸淇″彿杩炴帴椤哄簭銆?	if _bm != null and _bm.try_prevent_death():
		_core.running = true
		return
	var loss := 0
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) > 0.0:
			loss += _foe_life_weight(f)
	loss = maxi(1, loss)
	_life = maxi(0, _life - loss)
	_refresh_life_ui()
	_core.foes.clear()               # 鎬叏娓咃細涓嶆帀钀姐€佷笉缁欑粡楠?	_core.clear_enemy_attacks()       # 鏃ч璀?鍦伴潰浼ゅ涓嶈兘杩藉埌澶嶆椿鍚庣殑涓嬩竴娉?	_chal_all_cd()                   # 鎸戞垬鍏ㄩ儴杩涘喎鍗?	_spawn_pfx("shadow/dark-explosion", _hero_screen(), 1.25, "blood", 1.7)
	_core._shake = maxf(float(_core._shake), 12.0)
	_core.hero["hp"] = float(_core.hero.get("hp_max", 1.0))   # 婊¤绔欒捣鏉ワ紙涓嶅仛娴磋锛?	_core.running = true
	Aud.sfx("ui_back", -4.0)
	# 杩欎竴娉㈢洿鎺ュ垽璐燂細涓嶇粰濂栧姳锛岀珛鍒昏繘涓嬩竴娉紙鏈€鍚庝竴娉㈡墦杈?= 鏈眬缁撴潫锛?	var cleared_wave := int(_core.wave)
	if cleared_wave < _max_wave:
		_toast("绗?%d 娉㈡病鎵撲笅鏉?路 鍛?-%d" % [cleared_wave, loss])
		_core.set_wave(cleared_wave + 1)
		_core.wave_reset_quota()
		_spawn_typed_foes()
	else:
		_toast("绗?%d 娉㈡病鎵撲笅鏉?路 鍛?-%d" % [cleared_wave, loss])
		_end_run(false)
	if _life <= 0:
		_end_run(false)

# ---- 鏈眬缁撴潫锛氬懡灏斤紙杈擄級 / 閫氬叧锛堣耽锛?----
var _result_layer: Control = null

func _end_run(win: bool) -> void:
	if _run_over:
		return
	if win:
		var SaveFile := preload("res://shared/save_file.gd")
		if SaveFile.begin() == OK:
			var first := LevelState.mark_first_clear()
			if first:
				_grant_first_clear(LevelState.current_level)
			if SaveFile.commit() != OK:
				_toast("棣栭€氫繚瀛樺け璐ワ紝璇峰嬁鍏抽棴娓告垙")
		else:
			_toast("棣栭€氳褰曟仮澶嶅け璐ワ紝璇锋鏌ュ瓨鍌ㄧ┖闂?)
	_run_over = true
	if _tut != null:
		_tut.cancel()
	_q_close_popup()
	if _bm != null:
		_bm.close_panel()
	if _core != null:
		_core.running = false
	if _cam != null:
		_cam.scale = Vector2.ONE
	# 缁撶畻鍓嶇殑"瀹氭牸寮?鍙嶉锛氫竴闂?+ 闀块】甯э紝鐒跺悗鎵嶅脊闈㈡澘
	_screen_flash(Color(1.0, 0.96, 0.82) if win else Color(0.52, 0.17, 0.13), 0.34 if win else 0.28, 0.5)
	if _core != null:
		_core._hitstop = maxf(float(_core._hitstop), 0.30)
	if win:
		for i in 10:
			_spawn_fly(Vector2(360, 470), Vector2(99, 40), Color(0.92, 0.74, 0.32), 1)
	_build_result(win)
	Aud.sfx("levelup" if win else "ui_back", -3.0)

func _build_result(win: bool) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 40
	add_child(layer)
	_result_layer = layer
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var holder := Control.new()
	holder.position = Vector2(90, 320)
	holder.size = Vector2(540, 480)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	# 缁撶畻闈㈡澘搴曞浘锛堟湁鍥惧氨鐢ㄥ浘锛屾病鏈夊洖閫€鍘熸潵鐨勭函鑹查潰鏉匡級
	var panel_art := "res://assets/ui/panel_win.png" if win else "res://assets/ui/panel_lose.png"
	var has_art := ResourceLoader.exists(panel_art)
	if has_art:
		var tr := TextureRect.new()
		tr.texture = load(panel_art) as Texture2D
		tr.position = Vector2.ZERO
		tr.size = Vector2(540, 480)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)
	_panel(Rect2(0, 0, 540, 480), Color(0.97, 0.93, 0.85, 0.28) if has_art else Color(0.97, 0.93, 0.85, 0.99), 12,
		Color(0.85, 0.66, 0.23, 0.0) if has_art else (Color(0.85, 0.66, 0.23) if win else Color(0.64, 0.22, 0.15)),
		0 if has_art else 3, holder)
	_lbl("閫氥€€鍏? if win else "鍛姐€€灏?, Vector2(0, 26), Vector2(540, 58), 42,
		Color(0.62, 0.44, 0.12) if win else Color(0.62, 0.20, 0.14), holder, HORIZONTAL_ALIGNMENT_CENTER)
	var mins := int(_run_time) / 60
	var secs := int(_run_time) % 60
	var total_bonds := _bonds.size() + _bonds_done
	var rows := [
		["鍒拌揪娉㈡暟", "%d / %d" % [mini(int(_core.wave), _max_wave), _max_wave]],
		["鍑绘潃", str(_kills)],
		["鏂囬挶", str(_wen)],
		["鐏垫櫠", str(_crystal)],
		["缇佺粖", "%d 鏉★紙宸叉垚 %d锛? % [total_bonds, _bonds_done]],
		["瀛樻椿", "%d 鍒?%02d 绉? % [mins, secs]],
	]
	var y := 126.0
	for r in rows:
		_lbl(str(r[0]), Vector2(56, y), Vector2(150, 30), 20, DIM, holder)
		_lbl(str(r[1]), Vector2(210, y), Vector2(276, 30), 22, INK, holder, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 40.0
	_btn("鍐嶆潵涓€灞€", Rect2(30, 380, 210, 64), 24, Color(0.86, 0.66, 0.24), Color(0.14, 0.11, 0.08),
		func() -> void: _leave_result(true), holder)
	_btn("鍥炰富鐣岄潰", Rect2(300, 380, 210, 64), 24, Color(0.93, 0.89, 0.80), INK,
		func() -> void: _leave_result(false), holder)
	_pop_bounce(holder)
	_breathe(holder)
	_spawn_pfx("holy/sunburst" if win else "shadow/dark-explosion", Vector2(360, 235), 1.9, "holy" if win else "shadow", 1.8)

# 缁撴灉椤垫寜閽悓鏃朵綔涓轰繚瀛橀噸璇曞叆鍙ｏ紝鏈繚瀛樺畬鎴愭椂淇濈暀褰撳墠鍦烘櫙銆?func _leave_result(replay: bool) -> void:
	if not _run_over or _result_layer == null or not MenuUI.navigation_available(self): return
	var SaveFile := preload("res://shared/save_file.gd")
	if SaveFile.recover() != OK:
		_toast("淇濆瓨鏈畬鎴愶紝璇烽噴鏀惧瓨鍌ㄧ┖闂村悗鍐嶆鐐瑰嚮")
		return
	if replay:
		MenuUI.navigate(self, scene_file_path)
	else:
		MenuUI.navigate(self, "res://menu/main_home.tscn")

func _grant_first_clear(lv: int) -> void:
	var stored_equipment := 0
	var r := LevelState.first_reward(lv)
	if r.is_empty():
		return
	if r.has("wen"):
		GameState.add_coin("wen", int(r["wen"]))
	if r.has("skill_book"):
		var bk := str(r["skill_book"])
		GameState.skill_books[bk] = int(GameState.skill_books.get(bk, 0)) + int(r.get("skill_book_n", 1))
	if r.has("equip"):
		var FD := preload("res://shared/forge_data.gd")
		stored_equipment = FD.grant_starter_equipment()
	if r.has("curio_shards"):
		GameState.curio_shards += int(r["curio_shards"])
	if r.has("new_cards"):
		GameState.new_cards_unlocked = true
		_toast("鏂板崱缁勫凡瑙ｉ攣 路 鏁鏈熷緟绗崄涓€鍏?)
	if r.has("shards"):
		var sh: Dictionary = r["shards"]
		for k in sh.keys():
			GameState.shards[str(k)] = int(GameState.shards.get(str(k), 0)) + int(sh[k])
	if r.has("forge_mat"):
		var FD2 := preload("res://shared/forge_data.gd")
		FD2.load_game()
		var ore_n := int(r["forge_mat"])
		FD2.ores += ore_n
		FD2.silver += ore_n * 10   # 鍚屾缁欓敾閫犵敤鐨勯摱涓わ紝澶熷洓浠?+20 杩樻湁瀵屼綑
	if r.has("forge_mat"):
		GameState.forge_mat += int(r["forge_mat"])
	if r.has("equip"):
		GameState.equip_tokens += int(r["equip"])
	if r.has("advance"):
		GameState.advance_tokens += int(r["advance"])
	if r.has("curio"):
		GameState.new_curio_unlocked = true
	if r.has("equip") or r.has("forge_mat"):
		var ForgeData := preload("res://shared/forge_data.gd")
		ForgeData.save_game()
	GameState.save_progress()
	var equipment_note := " 路 %d 浠惰澶囧叆鑳屽寘" % stored_equipment if stored_equipment > 0 else ""
	_toast("棣栭€?路 " + str(r.get("text", "")) + equipment_note)

func _on_wave_clear(cleared_wave: int) -> void:
	if _run_over or _rewarded_waves.has(cleared_wave):
		return
	_rewarded_waves[cleared_wave] = true
	if _skip_reward_wave:
		_skip_reward_wave = false
		_toast("绗?%d 娉㈡病鎵撲笅鏉?路 鏃犲鍔? % cleared_wave)
		return
	_qc("clearwave", 1)
	_add_exp(50)                            # v2锛氭竻涓€娉?+50 缁忛獙
	_add_wen(WEN_WAVE_CLEAR * cleared_wave)  # v6锛氭竻涓€娉㈢粰涓€绗旀枃閽?	_curio_on_wave_clear(cleared_wave)       # 濂囩墿锛氳仛瀹濈泦 / 缁懡鐏?	_trea_charge += 1                      # v8锛氭竻涓€娉㈢粰涓€娆″疂鐗╂満浼?	_refresh_trea_tile()
	_toast("绗?%d 娉㈡竻绌? % cleared_wave)
	if cleared_wave == 1:
		# 鎵€鏈夊叧鍗★細娓呭畬绗?1 娉寒鍑哄己鍖?		if _str_tile != null:
			_str_tile.visible = true
			_str_tile.hot = true
			_str_tile.queue_redraw()
		# 鍙湁绗竴鍏虫墠璺戝己鍖?鏂囬挶/澶村儚杩欐潯鏁欏閾?		if LevelState.current_level == 1:
			_l1_tutorial("l1_wen", _str_tile,
				"寮哄寲鍙互寮哄寲鑷韩\n鎻愬崌姘旇銆佸唴鍔涘拰浼ゅ锛堝己鍖?Lv1锛?,
				func() -> void:
					_l1_tutorial("l1_wen2", _chips.get("鏂囬挶"),
						"寮哄寲闇€瑕佹秷鑰楁枃閽?,
						_on_str_tile))

func _l1_tutorial(key: String, target: Node, text: String, cb: Callable) -> void:
	_tutorial(key, target, text, cb)

func _tutorial(key: String, target: Node, text: String, cb: Callable) -> void:
	if _run_over or _tut == null or not MenuUI.navigation_available(self):
		return
	# 姣忓眬閮芥彁绀轰竴娆″己鍖栧紩瀵硷紙鍘熸潵鍙挱涓€娆★紝閲嶇帺鏃朵笉鍑虹幇锛?	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	LevelState.mark_tutorial(key)
	if OS.get_environment("DSH_DEBUG") != "":
		print("[TUT] lv=", LevelState.current_level, " key=", key, " target=", target.name if target != null else "<null>", " text=", text.replace("\n", " / "))
	_tut.open(target, text, cb, func() -> void: _tutorial_pause(true), func() -> void: _tutorial_pause(false))

# 姣忎竴鍏虫柊鎸夐挳鐨勯娆℃暀瀛︼細鍙嚭涓€鍙ワ紝鐐圭洰鏍囨墠缁х画
func _maybe_level_button_tutorial() -> void:
	var lv := LevelState.current_level
	var key := ""
	var target: Control = null
	var text := ""
	match lv:
		2:
			key = "l2_draw"
			target = _draw_tile
			text = "鐏垫櫠鍙互鎶藉崱锛岀粍鎴愬崱缁?
		3:
			key = "l3_trea"
			target = _trea_tile
			text = "瀹濈墿鍙互寮€鍑鸿祫婧愬拰瑁呭"
		4:
			key = "l4_chal"
			target = _chal_btn
			text = "鎸戞垬浼氬埛鍑洪澶栨€紝鏀剁泭鏇撮珮"
		5:
			return   # 绗簲鍏崇殑璇风鏁欏鏀瑰埌绗竴娆℃敀鍒拌绁炴鏁版椂鍐嶅嚭
		6:
			key = "l6_market"
			target = _market_tile
			text = "榛戝競鍙互涔拌澶囥€佸瓨浠撳簱"
		7:
			key = "l7_skill"
			target = _mate_tile
			text = "璇风椤靛彲浠ョ敤鎶€鑳戒功鍗囩骇鎶€鑳?
		_:
			return
	_tutorial(key, target, text, func() -> void: pass)

var _tutorial_paused := false
var _tutorial_ui_processing := true
var _tutorial_core_processing := true

func _tutorial_pause(p: bool) -> void:
	if p:
		if _tutorial_paused:
			return
		_tutorial_paused = true
		_tutorial_ui_processing = is_processing()
		if _core != null:
			_tutorial_core_processing = _core.is_processing()
		set_process(false)
		if _core != null:
			_core.set_process(false)
	elif _tutorial_paused:
		_tutorial_paused = false
		set_process(_tutorial_ui_processing)
		if _core != null:
			_core.set_process(_tutorial_core_processing)




func _on_mate_tile() -> void:
	if not LevelState.show_button("mate"):
		return
	if _draw_charge <= 0:
		_toast("鍗囩骇鍚庡彲璇风")
		return
	_show_god_pick()

# ============================================================
# ---------------- 寮哄寲锛坴6锛?---------------
# ============================================================
func _str_cost() -> int:
	return STR_COST_BASE + STR_COST_STEP * _str_lv

func _refresh_str_tile() -> void:
	if _str_tile == null:
		return
	var cost := _str_cost()
	var s := "寰呴€夎繘闃? if _str_pending else "Lv %d" % _str_lv   # 鍙樉绀虹瓑绾э紝娑堣€楀湪鐐瑰嚮鏃舵彁绀?	var hot := _str_pending or _wen >= cost
	if _str_tile.sub != s or _str_tile.hot != hot:
		_str_tile.sub = s
		_str_tile.hot = hot
		_str_tile.queue_redraw()

# 鐐癸蓟寮哄寲锛斤細鎵ｆ枃閽卞崌涓€绾э紱姝ｅソ鍒?10 鐨勫€嶆暟灏卞紑涓夐€変竴
func _open_bm() -> void:
	if not LevelState.show_button("market"):
		return
	if _bm != null:
		_bm.open_panel()

func _on_str_tile() -> void:
	if _str_pending:
		_open_aug_pick()                     # 涓婁竴鎵嬭繕娌￠€?鈫?閲嶆柊鎵撳紑锛堜笉閲嶅鎵ｉ挶锛?		return
	var cost := _str_cost()
	if _wen < cost:
		# 璺熷崌绾ф彁绀轰竴鏍凤紝鍦ㄤ富瑙掑ご椤堕涓€琛岀孩瀛?		if _core != null:
			_core._push_float(_core.hero_pos.x, _core.hero_pos.y - 70.0,
				"鏃犳硶寮哄寲 路 闇€瑕?%d 鏂囬挶" % cost, Color(0.94, 0.42, 0.32), true)
		return
	_wen -= cost
	if _coin_lb != null:
		_coin_lb.text = str(_wen)
	_str_lv += 1
	_apply_str_levels(1)
	Aud.sfx("ui_click", -6.0)
	_str_pop("寮哄寲 +1")
	# 涓昏澶撮《涔熼涓€琛岋紙璺熷崌绾ф彁绀轰竴鑷达級
	if _core != null:
		var hh: Dictionary = _core.hero
		_core._push_float(_core.hero_pos.x, _core.hero_pos.y - 70.0,
			"寮哄寲 +1 路 姘旇 %d 路 鏀诲嚮 %d" % [int(float(hh.get("hp_max", 0))), int(float(hh.get("atk", 0)))],
			Color(0.98, 0.86, 0.45), true)
	if _str_tile != null:
		var twp := create_tween()
		twp.tween_property(_str_tile, "scale", Vector2(0.86, 0.86), 0.055)
		twp.tween_property(_str_tile, "scale", Vector2(1.0, 1.0), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_str_tile.pivot_offset = _str_tile.size * 0.5
		var twc := create_tween()
		twc.tween_property(_str_tile, "modulate", Color(1.35, 1.25, 0.9), 0.05)
		twc.tween_property(_str_tile, "modulate", Color(1, 1, 1), 0.18)
	# 寮哄寲杩囦竴娆″悗锛氬紩瀵肩偣澶村儚鏌ョ湅灞炴€э紙灞忓箷鍘嬫殫銆佸ご鍍忎寒璧凤級
	if LevelState.current_level == 1 and not _l1_attr_shown:
		_l1_attr_shown = true
		var portrait: Node = _hero_token if _hero_token != null else _hero_hit_btn
		_l1_tutorial("l1_attr", portrait, "鐐瑰嚮浜虹墿澶村儚鍙互鏌ョ湅褰撳墠灞炴€?, func() -> void: _open_attr_page())
	if _str_lv % STR_EVERY == 0:
		_str_pending = true
		_aug_reroll += 1          # 姣忚繘涓€杞紝鍒锋柊娆℃暟 +1
		_open_aug_pick()
		var aug_t: Node = _str_layer
		if _aug_cards.size() > 1:
			aug_t = _aug_cards[1]          # 妗嗕腑闂撮偅寮犲崱锛岃€屼笉鏄暣灞忛伄缃?		if LevelState.current_level == 1 and not _l1_aug_shown:
			_l1_aug_shown = true
			_l1_tutorial("l1_aug", aug_t,
				"姣忓己鍖?10 绾у彲澶у箙鎻愬崌灞炴€n骞跺彲閫夋嫨鑷繁鐨勫彂灞曟柟鍚?,
				func() -> void: pass)
	_refresh_str_tile()

# 鐐逛竴涓嬬殑鍗虫椂鍙嶉锛氾蓟寮哄寲锛介挳涓婃柟鍐掍竴琛屽瓧锛屽線涓婇璧帮紙涓嶇敤 toast锛屽厤寰楄繛鐐规帓闃燂級
func _str_pop(txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.position = Vector2(426, 998)
	l.size = Vector2(124, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 30
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 40.0, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.62).set_delay(0.18)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(l):
			l.queue_free())

# 姣忕骇鐨勫熀纭€寮哄寲锛氱洿鎺ュ啓杩?core.hero锛堣鎸夋瘮渚嬫定锛屼笉鐧介€佹弧琛€锛?func _apply_str_levels(n: int) -> void:
	if _core == null:
		return
	var h: Dictionary = _core.hero
	_qc("str", n)
	var add_atk := STR_PER_ATK * float(n)
	var add_hp := STR_PER_HP * float(n)
	_apply_flat_growth(add_atk, add_hp, true)
	var cut_add := STR_PER_CUT * float(n)
	for t in _core.DMG_TYPES:
		if t != "鐪熷疄":
			_core.type_add(t, "red_f", cut_add)
	h["cut"] = _core.type_effective_field("鐗╃悊", "red_f")
	_stats["atk"] = float(_stats["atk"]) + add_atk
	_stats["hp"] = float(_stats["hp"]) + add_hp

# ---- 杩涢樁涓夐€変竴 ----
#   鍝侀樁闅忚疆娆℃定锛氱 1 杞壇 路 绗?2 杞巹 路 绗?3 杞湴 路 绗?4 杞捣澶╋紱鏁板€兼寜 1 + 0.4脳(杞?1) 鏀惧ぇ
const AUG_POOL := [
	{"key": "atk_pct", "name": "鐮村啗", "glyph": "鏀?, "v": 15, "text": "鏀诲嚮 +%d%%", "desc": "鍒€閿嬫洿鍒╋紝鍑烘墜瑙佽"},
	{"key": "hp_pct", "name": "閾侀", "glyph": "楠?, "v": 20, "text": "姘旇涓婇檺 +%d%%", "desc": "鐨硻鑲夊帤锛屾墰寰椾綇"},
	{"key": "aspd_pct", "name": "鐤鹃", "glyph": "鐤?, "v": 12, "text": "鏀婚€?+%d%%", "desc": "鎶㈠湪鍗婃嫑涔嬪墠"},
	{"key": "crit_add", "name": "浼氬績", "glyph": "浼?, "v": 8, "text": "鏆村嚮 +%d%%", "desc": "涓撴寫瑕佸鎷涘懠"},
	{"key": "critdmg_add", "name": "閿愭剰", "glyph": "閿?, "v": 25, "text": "鏆村嚮浼ゅ +%d%%", "desc": "鏆村嚮鏃舵洿鐤?},
	{"key": "cut_add", "name": "鐜勭敳", "glyph": "鐢?, "v": 8, "text": "鎶ょ敳 +%d%%", "desc": "鍙尅鍒€鍓戯紝涓嶆尅娉曟湳"},
	{"key": "cutall_add", "name": "閲戝垰", "glyph": "鍒?, "v": 6, "text": "鍏ㄤ激瀹冲噺鍏?+%d%%", "desc": "閲戞湪姘寸伀鍦熶竴姒傜‖鎵?},
	{"key": "pen_flat", "name": "璐煶", "glyph": "璐?, "v": 6, "text": "鍏ㄧ郴绌块€?+%d", "desc": "绠′綘浠€涔堟姢浣擄紝鍏堝嚳涓礊"},
	{"key": "dmgall_add", "name": "鍓戞剰", "glyph": "鎰?, "v": 10, "text": "鍏ㄧ郴澧炲箙 +%d%%", "desc": "涓冪浼ゅ涓€璧锋定"},
	{"key": "mp_add", "name": "钘忔皵", "glyph": "姘?, "v": 60, "text": "鍐呭姏涓婇檺 +%d", "desc": "鍔熸硶鏀惧緱鏇村嫟"},
	{"key": "gold_pct", "name": "鑱氳储", "glyph": "璐?, "v": 20, "text": "鏂囬挶 +%d%%", "desc": "鏉€寰楄秺澶氾紝鏉ュ緱瓒婂"},
	{"key": "killheal", "name": "琛€鎴?, "glyph": "琛€", "v": 3, "text": "鍑绘潃鍥炶 +%d%%", "desc": "瓒婃潃瓒婄簿绁?},
]

# 杩涢樁椤碉細**鐓ф娊鍗＄殑鎺掔増**鈥斺€斾笁寮犲崱鐩存帴娴湪鎴樺満涓婏紙涓嶉伄鏆椼€佷笉鏆傚仠锛夛紝
#   鎸夐挳鍙湁涓や釜锛氾蓟鍒锋柊 路 N 娆★冀锛堟鏁板瀷锛岀敤涓€娆″皯涓€娆★級鍜岋蓟闅愯棌锛姐€?func _build_str() -> void:
	_str_layer = Control.new()
	_str_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_str_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE     # 绌虹櫧澶勬斁琛岀粰鎴樺満
	_str_layer.visible = false
	_str_layer.z_index = 21
	add_child(_str_layer)
	var ban := Panel.new()
	ban.position = Vector2(230, 162)
	ban.size = Vector2(260, 42)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.54, 0.23, 0.10)
	bsb.set_corner_radius_all(4)
	bsb.border_color = Color(0.95, 0.76, 0.36, 0.9)
	bsb.set_border_width_all(2)
	ban.add_theme_stylebox_override("panel", bsb)
	_str_layer.add_child(ban)
	_breathe(ban)
	_str_ban_lb = _lbl("杩涢樁", Vector2(0, 0), Vector2(260, 42), 20, Color(0.97, 0.90, 0.74), ban, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("闅愯棌", Rect2(620, 162, 72, 32), 17, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _hide_aug_pick(), _str_layer)
	for i in 3:
		var d := AugCard.new()
		d.position = Vector2(30 + i * 220, 220)
		d.set_meta("base", d.position)
		d.pivot_offset = Vector2(100, 150)
		d.size = Vector2(200, 300)
		d.picked.connect(func() -> void: _on_aug_card(d))
		_str_layer.add_child(d)
		_aug_cards.append(d)
	_aug_refresh_btn = _btn("鍒锋柊 路 0 娆?, Rect2(140, 540, 200, 54), 19,
		Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _on_aug_refresh(), _str_layer)
	_btn("鏀惧純 +1 鍒锋柊", Rect2(360, 540, 200, 54), 19,
		Color(0.09, 0.08, 0.07, 0.98), Color(0.80, 0.62, 0.34), func(): _on_aug_abandon(), _str_layer)

func _open_aug_pick() -> void:
	if _run_over or not _str_pending or _str_layer == null:
		return
	if _draw_layer != null:
		_draw_layer.visible = false                 # 鎶藉崱椤靛紑鐫€涓€骞舵敹鎺夛紝鍒彔鍦ㄤ竴璧?	_hide_trea()
	_str_round = maxi(1, _str_lv / STR_EVERY)
	# 鍚屼竴鎵嬪彧鎺蜂竴娆★細鐐癸蓟闅愯棌锛藉叧浜嗗啀鐐癸蓟寮哄寲锛斤紝鐪嬪埌鐨勬槸鍚屼竴鎵嬶紙涓嶈兘鐧藉埛锛?	var invalidated := false
	for card in _aug_cards:
		if not card.o.is_empty() and not _aug_has_effect(str(card.o.get("key", ""))):
			invalidated = true
	if _aug_rolled_lv != _str_lv or invalidated:
		_aug_rolled_lv = _str_lv
		_roll_aug()
	if _str_ban_lb != null:
		_str_ban_lb.text = "杩涢樁 路 绗?%d 绾? % _str_lv
	_str_layer.visible = true
	_str_layer.move_to_front()
	_pop_aug_cards()
	Aud.sfx("ui_open", -8.0)

# 鎺蜂笁寮狅細鍝侀樁闅忚疆娆″崌锛堣壇鈫掔巹鈫掑湴鈫掑ぉ锛夛紝鏁板€?脳(1+0.4脳(杞?1))
func _aug_has_effect(key: String) -> bool:
	if _core == null:
		return false
	match key:
		"crit_add": return _core.attr_final("crit") < 0.75 - 0.000001
		"critdmg_add": return _core.attr_final("cdmg") < 4.0 - 0.000001
		"aspd_pct": return _core.attr_final("aspd") / float(_core.ATTR_BASE["aspd"]) < MAX_ASPD - 0.000001
		"cut_add": return _core.type_field("鐗╃悊", "red_f") < 0.60 - 0.000001
		"cutall_add":
			for type in _core.DMG_TYPES:
				if type != "鐪熷疄" and _core.type_field(type, "red_f") < 0.60 - 0.000001:
					return true
			return false
		"pen_flat", "dmgall_add":
			for type in _core.DMG_TYPES:
				if type == "鐪熷疄": continue
				if key == "pen_flat" and _core.type_effective_field(type, "pen_f") < 0.60 - 0.000001: return true
				if key == "dmgall_add" and _core.type_amp(type) < 2.0 - 0.000001: return true
			return false
		"killheal": return float(_core.kill_heal) < 1.0 - 0.000001
	return true

func _eligible_aug_pool() -> Array:
	return AUG_POOL.filter(func(option): return _aug_has_effect(str(option["key"])))

func _roll_aug() -> void:
	var r := maxi(1, _str_round)
	var mult := 1.0 + 0.4 * float(r - 1)
	var quality := clampi(1 + r, 2, 5)
	var pool := _eligible_aug_pool()
	pool.shuffle()
	for i in _aug_cards.size():
		var ac: AugCard = _aug_cards[i]
		if i < pool.size():
			var o: Dictionary = (pool[i] as Dictionary).duplicate()
			ac.o = o
			ac.oval = int(round(float(o["v"]) * mult))
			ac.title = str(o["name"])
			ac.glyph = str(o["glyph"])
			ac.effect = str(o["text"]) % int(ac.oval)
			ac.desc = str(o["desc"])
			if str(o["key"]) == "crit_add": ac.desc += " 路 鏈€楂?5%"
			if str(o["key"]) == "critdmg_add": ac.desc += " 路 鏈€楂?00%"
			if str(o["key"]) in ["cut_add", "cutall_add"]: ac.desc += " 路 鍚勭被鍑忎激鏈€楂?0%"
			if str(o["key"]) == "pen_flat": ac.desc += " 路 鍚勭郴鍥哄畾绌块€忔渶楂?0%"
			if str(o["key"]) == "dmgall_add": ac.desc += " 路 鍚勭郴鏈€缁堝骞呮渶楂?00%"
			ac.quality = quality
			ac.visible = true
			ac.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			ac.visible = false
		ac.queue_redraw()
	_refresh_aug_btn()

func _refresh_aug_btn() -> void:
	if _aug_refresh_btn != null:
		_aug_refresh_btn.text = "鍒锋柊 路 %d 娆? % maxi(0, _aug_reroll)

# 鍒锋柊锛氭鏁板瀷锛堜笉鑺辨枃閽憋紝浣嗙敤涓€娆″皯涓€娆★級
func _on_aug_refresh() -> void:
	if _run_over or not _str_pending or _str_layer == null or not _str_layer.visible:
		return
	if _aug_reroll <= 0:
		_toast("鍒锋柊娆℃暟鐢ㄥ畬浜?)
		return
	if not _rr_free():
		_aug_reroll -= 1
	_roll_aug()
	_pop_aug_cards()
	Aud.sfx("ui_click", -8.0)

# 鏀惧純锛氳繖涓€杞繘闃朵笉瑕佷簡锛屾崲 1 娆″埛鏂帮紙鍒锋柊娆℃暟鏄敀鐫€鐨勶紝涓嬫杩涢樁鑳界敤锛?func _on_aug_abandon() -> void:
	if _run_over or not _str_pending or _str_layer == null or not _str_layer.visible:
		return
	_str_pending = false
	_aug_reroll += 1
	_hide_aug_pick()
	_refresh_str_tile()
	_refresh_aug_btn()
	_toast("鏀惧純杩涢樁 路 鍒锋柊 +1锛堢幇鏈?%d 娆★級" % _aug_reroll)
	Aud.sfx("ui_back", -8.0)

# 涓夊紶鍗′竴璧峰脊鍑烘潵锛堣窡鎶藉崱涓€鏍风殑鎵嬫劅锛?func _pop_aug_cards() -> void:
	for i in _aug_cards.size():
		var card: AugCard = _aug_cards[i]
		var base: Vector2 = card.get_meta("base", Vector2(30 + i * 220, 220))
		card.visible = true
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		MenuUI.Motion.pop(card, true, i * 0.055, base, (i - 1) * 0.025)

func _hide_aug_pick() -> void:
	if _str_layer != null:
		_str_layer.visible = false

func _on_aug_card(card: AugCard) -> void:
	if _run_over or not _str_pending or _str_layer == null or not _str_layer.visible or card == null or not _aug_cards.has(card) or card.o.is_empty():
		return
	_pick_aug(card.o, int(card.oval))

func _pick_aug(o: Dictionary, val: int) -> void:
	if _run_over or not _str_pending:
		return
	if not _aug_has_effect(str(o.get("key", ""))):
		_roll_aug()
		_toast("灞炴€у凡杈句笂闄愶紝宸叉洿鏂拌繘闃跺€欓€?)
		return
	_str_pending = false
	_choice_fx("aug")
	_apply_aug(str(o["key"]), float(val))
	_hide_aug_pick()
	_toast("杩涢樁 路 %s锛?s锛? % [str(o["name"]), str(o["text"]) % val])
	Aud.sfx("levelup", -6.0)
	_refresh_str_tile()

# ============================================================
# ---------------- 瀹濈墿锛坴8锛?---------------
# ============================================================
# 瀹濈墿 = 鍗＄粍缇佺粖锛坴9锛岀敤鎴凤細"瀹濈墿鏆傚畾涓哄崱缁勭緛缁婏紝鏈夎繘搴︼紱鍑戦綈 xx 鍜?xx 缁勫悎鍗★紝鏁堟灉澧炲箙锛涘疂鐗╃畻娑堣€楋紝涓嶉檺浠舵暟"锛?#   路 涓€寮犵緛缁?= 瑕?3 涓粍鍚堬紙濡?涓夐攱 / 閾佸 / 鐢熸満锛夛紝鍑戦綈 3/3 鈫?鏁堟灉姘镐箙鐢熸晥
#   路 杩涘害鎸?杩欎竴灞€宸茬粡婵€娲昏繃鐨勭粍鍚?绠楋紙_combined + _ancestor_combos锛屾縺娲昏繃鐨勪笉浼氬け鏁堬級
#   路 **鎴愮殑閭ｄ竴鍒荤緛缁婂氨娑堣€楁帀**锛堜粠韬笂鍒犳帀锛夆啋 鎵€浠ヤ笉鍗犳牸瀛愩€佷篃娌℃湁鎼哄甫涓婇檺
#   路 鍝佽川闅忔尝鏁板崌锛堣壇/鐜?鍦?澶╋級锛屽彧鏄妸鏁堟灉鏁板€兼斁澶?脳1 / 1.5 / 2 / 3
#   缇佺粖鐨勬晥鏋?*鍙兘鏄?瀵瑰簲缁勫悎鐨勬晥鏋滃骞?**锛堢敤鎴峰彛寰勶級锛?#   鍑戦綈 3 涓粍鍚?鈫?杩欎笁濂楃粍鍚堜互鍚庢瘡娆¤Е鍙戠殑鏁堟灉 脳(1+boost%)
#   锛堟瘮濡傘€屽紑闂ㄤ笁寮忋€嶆垚 鈫?涓夐攱 姣忔尝鏀诲嚮+1 鍙?+1.4銆侀搧澹?闃插尽+1 鍙?+1.4銆佺敓鏈?姘旇+10 鍙?+14锛?# 鍗＄粍鐨?*涓夊ぇ绾?*锛堣璁＄銆婂洶鍏絖璇风涓庡浼犲崱缁刜璁捐绋裤€嬄у叓路鍏紝2026-11-09 瀹氾級
const CARD_LINES := {
	"鎴愰暱绾?: ["atk", "def", "hp", "mp"],
	"缁忔祹绾?: ["gold", "crystal", "exp", "peril", "bounty"],
	"鍗遍€旂嚎": ["swarm"],
}

# 绯?鈫?涓枃鍚嶏紙灏忕緛缁婄殑鍗￠潰/璇︽儏瑕佺敤锛?const SERIES_CN := {
	"atk": "鏀诲嚮", "def": "闃插尽", "hp": "姘旇", "mp": "鍐呭姏",
	"gold": "鏂囬挶", "crystal": "鐏垫櫠", "exp": "鏉€鏁屾暟", "peril": "鎸戞垬",
	"bounty": "鏀剁泭", "swarm": "澧炴€?,
}

const BOND_POOL := [
	# ============ 鍥涙潯缇佺粖閾?============
	#   姣忔鍙粠銆屽凡瑙ｉ攣銆嶇殑缇佺粖閲屾娊涓夊紶锛涚粨鎴愪竴鏉?鈫?瀹冪殑涓嬩竴鏉″叆姹狅紙璺熷崱鐗岀殑鍏ュ彛鍗′竴涓璺級
	#   鈶?鎴愰暱閾?鈶?缁忔祹閾?鈶?鍗遍€旈摼 鈶?瀹朵紶閾?	{"name": "鏀婚槻", "glyph": "鏀?, "need_series": ["atk", "def"], "boost": 30, "desc": "鎴愰暱閾?路 1", "next": "鍐呰"},
	{"name": "鍐呰", "glyph": "鍐?, "need_series": ["hp", "mp"], "boost": 30, "desc": "鎴愰暱閾?路 2", "next": "琛€鍕?},
	{"name": "琛€鍕?, "glyph": "鍕?, "need_series": ["atk", "hp"], "boost": 30, "desc": "鎴愰暱閾?路 3", "next": "瀹堜腑"},
	{"name": "瀹堜腑", "glyph": "瀹?, "need_series": ["def", "mp"], "boost": 30, "desc": "鎴愰暱閾?路 4", "next": "鏍瑰熀"},
	{"name": "鏍瑰熀", "glyph": "鏍?, "line": "鎴愰暱绾?, "need": ["涓夐攱", "閾佸", "鐢熸満", "鍑濇伅"], "boost": 50,
		"lbl": "鎴愰暱绾?+%d%%", "desc": "鎴愰暱閾?路 缁?路 鏀?闃?琛€/鍐?鍥涚郴鍒濋樁"},

	{"name": "閲戦摱", "glyph": "閲?, "need_series": ["gold", "crystal"], "boost": 30, "desc": "缁忔祹閾?路 1", "next": "鎮祻"},
	{"name": "鎮祻", "glyph": "璧?, "need_series": ["exp", "peril"], "boost": 30, "desc": "缁忔祹閾?路 2", "next": "鐢熻储"},
	{"name": "鐢熻储", "glyph": "鐢?, "need_series": ["bounty", "gold"], "boost": 30, "desc": "缁忔祹閾?路 3", "next": "璐㈤櫓"},
	{"name": "璐㈤櫓", "glyph": "闄?, "need_series": ["peril", "crystal"], "boost": 30, "desc": "缁忔祹閾?路 4", "next": "鍚嶅埄"},
	{"name": "鍚嶅埄", "glyph": "鍚?, "need_series": ["atk", "gold"], "boost": 30, "desc": "缁忔祹閾?路 5", "next": "寮€婧?},
	{"name": "寮€婧?, "glyph": "婧?, "line": "缁忔祹绾?, "need": ["鑱氳储", "鐏垫秾", "濂嬭捣", "璧忛噾", "杩涜处"], "boost": 50,
		"lbl": "缁忔祹绾?+%d%%", "desc": "缁忔祹閾?路 缁?路 鏂囬挶/鐏垫櫠/鏉€鏁?鎸戞垬/鏀剁泭 鍒濋樁"},

	{"name": "鍏绘垬", "glyph": "鎴?, "need_series": ["hp", "swarm"], "boost": 30, "desc": "鍗遍€旈摼 路 1", "next": "鍗遍€?},
	{"name": "鍗遍€?, "glyph": "鍗?, "line": "鍗遍€旂嚎", "need": ["铚傛嫢", "娼秾", "铚傝捣", "鍊惧发"], "boost": 50,
		"lbl": "鍗遍€旂嚎 +%d%%", "desc": "鍗遍€旈摼 路 缁?路 澧炴€洓闃跺叏閫?},

	{"name": "鍓戞鍚屾簮", "glyph": "鍓?, "need": ["鍓戝娍", "鍐叉挒"], "boost": 40, "lbl": "瀹朵紶鎶€鑳?+%d%%",
		"desc": "瀹朵紶閾?路 1 路 涓昏锛嬫粴鍦伴緳", "next": "鍚屾皵杩炴灊"},
	{"name": "鍚屾皵杩炴灊", "glyph": "楦?, "need": ["鍓戝娍", "椋炲垉"], "boost": 40, "lbl": "瀹朵紶鎶€鑳?+%d%%",
		"desc": "瀹朵紶閾?路 2 路 涓昏锛嬭嫃闈掗妇", "next": "甯備簳涓変緺"},
	{"name": "甯備簳涓変緺", "glyph": "渚?, "need": ["鎵嬪揩", "鍐叉挒", "椋炲垉"], "boost": 30, "lbl": "瀹朵紶鎶€鑳?+%d%%",
		"desc": "瀹朵紶閾?路 3 路 灏忎篂鍎匡紜婊氬湴榫欙紜鑻忛潚楦?},
]

# 姣忔潯閾剧殑绗竴鏉★紙寮€灞€灏卞湪姹犲瓙閲岋級
const BOND_ENTRIES := ["鏀婚槻", "閲戦摱", "鍏绘垬", "鍓戞鍚屾簮"]

# ============================================================
# 绋€鏈夊崟鍗★紙涓嶆垚濂椼€佷笉鍗犵緛缁婇摼銆佹嬁鍒板嵆鐢紝鏁堟灉鍙仛鏁板€硷級
#   鍥涚被锛氣憼 宸ㄩ鐏垫櫠涓€娆℃€э紙涔嬪悗鐏垫櫠鏀跺叆褰掗浂锛夆憽 鏂囬挶鎹㈢伒鏅?#        鈶?闄愭椂 buff 鈶?鐩存帴缁欒祫婧愶紙鏂囬挶 / 鐏垫櫠 / 鏉€鏁岋紝灏忎腑澶э級
# ============================================================
const RARE_POOL := [
	# 鐗规畩 3
	{"name": "鍊惧泭", "glyph": "鏅?, "rare": true, "kind": "crystal_burst", "v": 2000,
		"effect": "鐏垫櫠 +2000", "desc": "绋€鏈?路 涔嬪悗鐏垫櫠鏀跺叆褰掗浂"},
	{"name": "鎶橀挶", "glyph": "鎹?, "rare": true, "kind": "convert", "v": 10, "cap": 50,
		"effect": "鏂囬挶 10:1 鎹㈢伒鏅?, "desc": "绋€鏈?路 鏈€澶氭崲 50 鐏垫櫠"},
	{"name": "鐙傝", "glyph": "鐙?, "rare": true, "kind": "buff", "stat": "atk_pct", "v": 60, "dur": 30,
		"effect": "30 绉?鏀诲嚮 +60%", "desc": "绋€鏈?路 鍗冲緱鍗崇敤"},
	# 璧勬簮 12锛堜笁绫?脳 鍥涙。锛?	{"name": "灏忔櫠鍥?, "glyph": "灏?, "rare": true, "kind": "res", "res": "crystal", "v": 40, "effect": "鐏垫櫠 +40", "desc": "绋€鏈?路 鐏垫櫠"},
	{"name": "涓櫠鍥?, "glyph": "涓?, "rare": true, "kind": "res", "res": "crystal", "v": 80, "effect": "鐏垫櫠 +80", "desc": "绋€鏈?路 鐏垫櫠"},
	{"name": "澶ф櫠鍥?, "glyph": "澶?, "rare": true, "kind": "res", "res": "crystal", "v": 160, "effect": "鐏垫櫠 +160", "desc": "绋€鏈?路 鐏垫櫠"},
	{"name": "鏅跺北", "glyph": "灞?, "rare": true, "kind": "res", "res": "crystal", "v": 320, "effect": "鐏垫櫠 +320", "desc": "绋€鏈?路 鐏垫櫠"},
	{"name": "灏忛挶琚?, "glyph": "灏?, "rare": true, "kind": "res", "res": "wen", "v": 500, "effect": "鏂囬挶 +500", "desc": "绋€鏈?路 鏂囬挶"},
	{"name": "涓挶琚?, "glyph": "涓?, "rare": true, "kind": "res", "res": "wen", "v": 1000, "effect": "鏂囬挶 +1000", "desc": "绋€鏈?路 鏂囬挶"},
	{"name": "澶ч挶琚?, "glyph": "澶?, "rare": true, "kind": "res", "res": "wen", "v": 2000, "effect": "鏂囬挶 +2000", "desc": "绋€鏈?路 鏂囬挶"},
	{"name": "閲戝簱", "glyph": "搴?, "rare": true, "kind": "res", "res": "wen", "v": 4000, "effect": "鏂囬挶 +4000", "desc": "绋€鏈?路 鏂囬挶"},
	{"name": "灏忔潃浠?, "glyph": "灏?, "rare": true, "kind": "res", "res": "kill", "v": 60, "effect": "鏉€鏁?+60", "desc": "绋€鏈?路 鏉€鏁?},
	{"name": "涓潃浠?, "glyph": "涓?, "rare": true, "kind": "res", "res": "kill", "v": 120, "effect": "鏉€鏁?+120", "desc": "绋€鏈?路 鏉€鏁?},
	{"name": "澶ф潃浠?, "glyph": "澶?, "rare": true, "kind": "res", "res": "kill", "v": 240, "effect": "鏉€鏁?+240", "desc": "绋€鏈?路 鏉€鏁?},
	{"name": "灞犳埉浠?, "glyph": "灞?, "rare": true, "kind": "res", "res": "kill", "v": 480, "effect": "鏉€鏁?+480", "desc": "绋€鏈?路 鏉€鏁?},
	# 娣峰悎 2
	{"name": "鍙屾敹", "glyph": "鍙?, "rare": true, "kind": "mix", "wen": 1000, "crystal": 80,
		"effect": "鏂囬挶 +1000 路 鐏垫櫠 +80", "desc": "绋€鏈?路 娣峰悎"},
	{"name": "涓板勾", "glyph": "涓?, "rare": true, "kind": "mix", "wen": 1500, "crystal": 120, "kill": 120,
		"effect": "閽?1500 路 鏅?120 路 鏉€+120", "desc": "绋€鏈?路 娣峰悎"},
]


# 绋€鏈夊崟鍗″嚭鐜版鐜囷紙姣忎竴鎵嬩笁寮犻噷锛?const RARE_CHANCE := 0.30

# 瀹濈墿椤碉細鍜屾娊鍗?杩涢樁鍚屼竴濂楁帓鐗堬紝鎸夐挳涓変釜锛氬埛鏂?路 N 娆?/ 闅愯棌 / 鏀惧純 +1 鍒锋柊
func _build_trea() -> void:
	_trea_layer = Control.new()
	_trea_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trea_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trea_layer.visible = false
	_trea_layer.z_index = 22
	add_child(_trea_layer)
	var ban := Panel.new()
	ban.position = Vector2(230, 162)
	ban.size = Vector2(260, 42)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.54, 0.23, 0.10)
	bsb.set_corner_radius_all(4)
	bsb.border_color = Color(0.95, 0.76, 0.36, 0.9)
	bsb.set_border_width_all(2)
	ban.add_theme_stylebox_override("panel", bsb)
	_trea_layer.add_child(ban)
	_breathe(ban)
	_lbl("瀹濈墿 路 鎷╀竴缇佺粖", Vector2(0, 0), Vector2(260, 42), 20, Color(0.97, 0.90, 0.74), ban, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("闅愯棌", Rect2(620, 162, 72, 32), 17, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _hide_trea(), _trea_layer)
	for i in 3:
		var d := AugCard.new()
		d.position = Vector2(30 + i * 220, 220)
		d.set_meta("base", d.position)
		d.pivot_offset = Vector2(100, 150)
		d.size = Vector2(200, 300)
		d.picked.connect(func() -> void: _on_trea_card(d))
		_trea_layer.add_child(d)
		_trea_cards.append(d)
	_trea_refresh_btn = _btn("鍒锋柊 路 0 娆?, Rect2(140, 540, 200, 54), 19,
		Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _on_trea_refresh(), _trea_layer)
	_btn("鏀惧純 +1 鍒锋柊", Rect2(360, 540, 200, 54), 19,
		Color(0.09, 0.08, 0.07, 0.98), Color(0.80, 0.62, 0.34), func(): _on_trea_abandon(), _trea_layer)

# 鍝佽川闅忔尝鏁板崌锛?-2 鑹?路 3 鐜?路 4-5 鍦?路 6+ 澶?func _trea_quality() -> int:
	var w := 1
	if _core != null:
		w = int(_core.wave)
	if w >= 6:
		return 5
	if w >= 4:
		return 4
	if w >= 3:
		return 3
	return 2

func _refresh_trea_tile() -> void:
	if _trea_tile == null:
		return
	var s := "寰呴€夌緛缁? if _trea_pending else "缇佺粖 %d" % _bonds.size()
	var hot := _trea_pending or _trea_charge > 0
	if _trea_tile.sub != s or _trea_tile.hot != hot:
		_trea_tile.sub = s
		_trea_tile.hot = hot
		_trea_tile.queue_redraw()
	_trea_tile.badge = 1 if _trea_pending else maxi(0, _trea_charge)

# 鐐癸蓟瀹濈墿锛斤細鏈変竴鎵嬫病閫夊氨鎺ョ潃鐪嬮偅涓€鎵嬶紱鍚﹀垯鑺辨帀涓€娆℃満浼氥€佹幏涓夊紶
func _on_trea_tile() -> void:
	if not LevelState.show_button("treasure"):
		return
	if _trea_pending:
		_open_trea()
		return
	if _trea_charge <= 0:
		_toast("杩樻病鏀掑埌瀹濈墿鏈轰細锛堟瘡娓呬竴娉?+1锛?)
		return
	if _bond_pool().is_empty() and _rare_pool().is_empty():
		_toast("鏈眬瀹濈墿宸叉娊绌?)
		return
	_trea_charge -= 1
	_trea_pending = true
	_roll_trea()
	_refresh_trea_tile()
	_open_trea()

func _open_trea() -> void:
	if _trea_layer == null:
		return
	if _draw_layer != null:
		_draw_layer.visible = false
	if _str_layer != null:
		_str_layer.visible = false
	_trea_layer.visible = true
	_layer_in(_trea_layer)
	_trea_layer.move_to_front()
	_pop_trea_cards()
	Aud.sfx("ui_open", -8.0)

# 鐜板湪鑳芥娊鍒扮殑缇佺粖锛氬凡瑙ｉ攣 涓?杩樻病缁撹繃
func _bond_pool() -> Array:
	var out: Array = []
	for e_v in BOND_POOL:
		var e: Dictionary = e_v
		var nm := str(e["name"])
		if bool(_bond_unlocked.get(nm, false)) and not _bond_taken.has(nm):
			out.append(e)
	return out

# 绋€鏈夊崟鍗℃睜锛氭娊鍒拌繃鐨勶紙鍞竴锛変笉鍐嶅嚭鐜?func _rare_pool() -> Array:
	var out: Array = []
	for e_v in RARE_POOL:
		var e: Dictionary = e_v
		if not _rare_taken.has(str(e["name"])):
			out.append(e)
	return out

func _roll_trea() -> void:
	var q := _trea_quality()
	var mult: float = [1.0, 1.5, 2.0, 3.0][clampi(q - 2, 0, 3)]
	var bp: Array = _bond_pool()
	var rp: Array = _rare_pool()
	# 鏉€鏁?缁忛獙鐩稿叧缇佺粖浼樺厛锛氭偓璧忋€佸紑婧愶紙缁忔祹閾剧粓锛変互鍙婃弿杩伴噷甯︽潃鏁岀殑
	var kill_bonds: Array = []
	var other_bonds: Array = []
	for b_v in bp:
		var b: Dictionary = b_v
		var is_kill := false
		for s_v in (b.get("need_series", []) as Array):
			if str(s_v) == "exp":
				is_kill = true
		var bn := str(b.get("name", ""))
		if bn in ["鎮祻", "寮€婧?] or str(b.get("desc", "")).contains("鏉€鏁?):
			is_kill = true
		if is_kill:
			kill_bonds.append(b)
		else:
			other_bonds.append(b)
	bp = kill_bonds + other_bonds
	bp.shuffle()
	rp.shuffle()
	var picks: Array = []
	var used := {}
	for e_v in bp:
		if picks.size() >= _trea_cards.size():
			break
		var e: Dictionary = e_v
		if used.has(str(e["name"])):
			continue
		used[str(e["name"])] = true
		picks.append(e)
	# 绋€鏈夊崟鍗★細30% 姒傜巼濉炰竴寮狅紙鏈夌┖浣嶅氨琛ヤ綅锛屾病绌轰綅灏遍殢鏈洪《鎺変竴寮狅級
	if not rp.is_empty() and randf() < RARE_CHANCE:
		var r: Dictionary = rp[0]
		if picks.size() < _trea_cards.size():
			picks.append(r)
		else:
			picks[randi() % picks.size()] = r
		used[str(r["name"])] = true
	# 涓ゆ睜鍏滃簳锛氱緛缁婁笉澶熶笁寮犲氨缁х画鐢ㄧ█鏈夎ˉ锛涘悓鍚嶄笉閲嶅
	for e_v2 in rp:
		if picks.size() >= _trea_cards.size():
			break
		var e2: Dictionary = e_v2
		if used.has(str(e2["name"])):
			continue
		used[str(e2["name"])] = true
		picks.append(e2)
	for i in _trea_cards.size():
		var c: AugCard = _trea_cards[i]
		var o: Dictionary = picks[i] if i < picks.size() else {}
		if o.is_empty():
			c.visible = false
			c.queue_redraw()
			continue
		c.o = o
		c.title = str(o["name"])
		c.glyph = str(o["glyph"])
		if bool(o.get("rare", false)):
			# 绋€鏈夊崟鍗★細鏁板€煎浐瀹氾紝涓嶅悆鍝佽川
			c.oval = int(o.get("v", 0))
			c.effect = str(o.get("effect", ""))
			c.desc = str(o.get("desc", "绋€鏈夊崟鍗?))
			c.quality = 5
		else:
			c.oval = int(round(float(o["boost"]) * mult))
			if o.has("need_series"):
				c.effect = "缁勫悎鏁堟灉 +%d%%" % int(c.oval)
				c.desc = "闇€鍚堟垚 " + _series_pair_cn(o) + "锛堜换鎰忎竴闃讹級"
			else:
				c.effect = str(o.get("lbl", "缁勫悎鏁堟灉 +%d%%")) % int(c.oval)
				c.desc = "闇€鍚堟垚 " + "路".join(PackedStringArray(o["need"]))
			c.quality = q
		c.visible = true
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.queue_redraw()
	_refresh_trea_btn()

# 鐏垫櫠涓€鍒囨敹鍏ョ殑鍞竴鍏ュ彛锛堛€屽€惧泭銆嶆妸 _crystal_lock 鎵撳紑鍚庯紝杩欓噷灏卞啀涔熶笉缁欙級
func _gain_crystal(n: int) -> void:
	if n <= 0 or _crystal_lock:
		return
	_crystal += n
	_update_crystal()
	_pulse_chip(_crystal_lb)
	_spawn_fly(_hero_screen() + Vector2(0, -30), Vector2(273, 40), Color(0.52, 0.78, 0.88), 2)

# 绋€鏈夊崟鍗★細鎷垮埌褰撳満缁撶畻锛屼笉杩涚緛缁?func _apply_rare(o: Dictionary) -> void:
	var kind := str(o.get("kind", "res"))
	var v := int(o.get("v", 0))
	match kind:
		"crystal_burst":
			_gain_crystal(v)                 # 鍏堢粰锛屽啀涓婇攣
			_crystal_lock = true
			_update_crystal()
			_toast("绋€鏈?路 鐏垫櫠 +%d锛屾鍚庣伒鏅朵笉鍐嶅鍔? % v)
		"convert":
			if _crystal_lock:
				_toast("鐏垫櫠宸查攣锛屾崲涓嶄簡")
				return
			var rate := maxi(1, v)
			var cap := int(o.get("cap", 50))
			var spend := mini(_wen, rate * cap)
			var got := int(spend / rate)
			if got <= 0:
				_toast("鏂囬挶涓嶅锛屾崲涓嶄簡")
				return
			_wen -= spend
			if _coin_lb != null:
				_coin_lb.text = str(_wen)
			_crystal += got
			_update_crystal()
			_toast("绋€鏈?路 %d 鏂囬挶鎹?%d 鐏垫櫠" % [spend, got])
		"buff":
			_apply_rare_buff(o)
		"mix":
			_add_wen(int(o.get("wen", 0)))
			_gain_crystal(int(o.get("crystal", 0)))
			var kk := int(o.get("kill", 0))
			if kk > 0:
				_kills += kk
				if _kill_lb != null:
					_kill_lb.text = str(_kills)
				_add_exp(20 * kk)
			_toast("绋€鏈?路 " + str(o.get("effect", "")))
		_:
			match str(o.get("res", "")):
				"wen":
					_add_wen(v)
				"crystal":
					_gain_crystal(v)
				"kill":
					_kills += v
					if _kill_lb != null:
						_kill_lb.text = str(_kills)
					_add_exp(20 * v)
			_toast("绋€鏈?路 " + str(o.get("effect", "")))
	Aud.sfx("levelup", -4.0)
	_refresh_trea_tile()
	_refresh_str_tile()

# 闄愭椂 buff锛氬揩鐓т竴浠藉骞呭墠鐨勫浐瀹氭敾鍑伙紝鍒扮偣鍙Щ闄よ嚜韬繖涓€浠姐€?func _apply_rare_buff(o: Dictionary) -> void:
	if _run_over or _core == null:
		return
	var pct := float(o.get("v", 0)) / 100.0
	var dur := float(o.get("dur", 30))
	var a: Dictionary = _core.attr["atk"]
	var add := (float(a["base"]) + float(a["temp"])) * pct
	_core.attr_add("atk", add)
	_core.hero["atk"] = _core.attr_final("atk")
	_rare_buffs.append({"raw_atk": add, "t": dur})
	_toast("绋€鏈?路 鏀诲嚮 +%d%%锛?d 绉掞級" % [int(o.get("v", 0)), int(dur)])

func _tick_rare_buffs(dt: float) -> void:
	if _run_over or _rare_buffs.is_empty() or _core == null or dt <= 0.0:
		return
	for i in range(_rare_buffs.size() - 1, -1, -1):
		var rb: Dictionary = _rare_buffs[i]
		rb["t"] = float(rb["t"]) - dt
		if float(rb["t"]) <= 0.0:
			_core.attr_add("atk", -float(rb["raw_atk"]))
			_core.hero["atk"] = _core.attr_final("atk")
			_rare_buffs.remove_at(i)

func _refresh_trea_btn() -> void:
	if _trea_refresh_btn != null:
		_trea_refresh_btn.text = "鍒锋柊 路 %d 娆? % maxi(0, _trea_reroll)

func _pop_trea_cards() -> void:
	for i in _trea_cards.size():
		var card: AugCard = _trea_cards[i]
		var base: Vector2 = card.get_meta("base", Vector2(30 + i * 220, 220))
		card.visible = true
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		MenuUI.Motion.pop(card, true, i * 0.055, base, (i - 1) * 0.025)

func _hide_trea() -> void:
	if _trea_layer != null:
		_trea_layer.visible = false

func _on_trea_card(card: AugCard) -> void:
	if _run_over or not _trea_pending or _trea_layer == null or not _trea_layer.visible or card == null or card.o.is_empty():
		return
	_choice_fx("rare" if bool(card.o.get("rare", false)) else "trea")
	_pick_trea(card.o, int(card.oval))

func _pick_trea(o: Dictionary, val: int, close_hand := true) -> void:
	if _run_over or o.is_empty() or _rare_taken.has(str(o.get("name", ""))) or _bond_taken.has(str(o.get("name", ""))):
		return
	if close_hand:
		_trea_pending = false
		_hide_trea()
	if bool(o.get("rare", false)):
		_rare_taken[str(o["name"])] = true        # 绋€鏈夊崟鍗′篃鏄敮涓€锛屾嬁杩囦笉鍐嶅嚭
		_qc("trea", 1)
		_apply_rare(o)
		return
	var b := {"name": str(o["name"]), "boost": int(val), "prog": 0,
		"lbl": str(o.get("lbl", "缁勫悎鏁堟灉 +%d%%")),
		"glyph": str(o.get("glyph", "缇?)), "quality": _trea_quality()}
	if o.has("need_series"):
		b["need_series"] = (o["need_series"] as Array).duplicate()   # 灏忕緛缁婏細鎸夌郴绠楋紝浠讳竴涓€闃堕兘琛?	else:
		b["need"] = (o["need"] as Array).duplicate()
	if o.has("line"):
		b["line"] = str(o["line"])          # 绾跨緛缁婏細鎴愬悗鎶暣鏉＄嚎锛屼笉鍙槸闇€姹傞噷閭ｅ嚑涓?	_bonds.append(b)
	_bond_taken[str(o["name"])] = true
	_qc("trea", 1)
	if o.has("next"):
		var nx := str(o["next"])
		if not bool(_bond_unlocked.get(nx, false)):
			_bond_unlocked[nx] = true
			_toast("缇佺粖銆?s銆嶈В閿佸叆姹? % nx)
	_toast("缁撴垚缇佺粖 路 %s锛?d/%d锛屽噾榻愬嵆娑堣€楋級" % [str(o["name"]), _bond_prog(b), _bond_need_n(b)])
	Aud.sfx("levelup", -6.0)
	_bond_check()
	_refresh_trea_tile()

# ---- 缇佺粖缁撶畻 ----
func _grant_random_treasure() -> bool:
	var shown := {}
	if _trea_pending:
		for card in _trea_cards:
			if card.visible and not card.o.is_empty():
				shown[str(card.o.get("name", ""))] = true
	var bonds: Array = _bond_pool().filter(func(o): return not shown.has(str(o["name"])))
	# 鑷姩濂栧姳涓嶈兘鏇跨帺瀹堕€夋嫨鑺遍挶鍏戞崲鎴栨案涔呭叧闂伒鏅舵敹鍏ョ殑浠ｄ环鍗°€?	var rares: Array = _rare_pool().filter(func(o):
		return not shown.has(str(o["name"])) and str(o.get("kind", "")) not in ["convert", "crystal_burst"] and not (_crystal_lock and str(o.get("kind", "")) == "res" and str(o.get("res", "")) == "crystal"))
	var pool: Array = rares if not rares.is_empty() and (bonds.is_empty() or randf() < RARE_CHANCE) else bonds
	if pool.is_empty():
		return false
	var item: Dictionary = pool[randi() % pool.size()]
	var multiplier: float = [1.0, 1.5, 2.0, 3.0][clampi(_trea_quality() - 2, 0, 3)]
	var value := int(item.get("v", 0)) if bool(item.get("rare", false)) else int(round(float(item["boost"]) * multiplier))
	_pick_trea(item, value, false)
	_toast("闀囬瓊閾?路 鑾峰緱瀹濈墿銆?s銆? % str(item["name"]))
	return true

func _combo_has(nm: String) -> bool:
	# 鈿?鍥炴槬 / 鐢熸伅 杩欎袱涓悕瀛椾袱杈归兘鏈夛細鏅€氬崱浼樺厛锛屽懡涓櫘閫氬崱鍚嶅崟灏卞彧璁?_combined
	var sys_first: bool = _sys_combos.has(nm)
	for r_v in _combined:
		if str((r_v as Dictionary).get("name", "")) == nm:
			return true
	if sys_first:
		return false
	for r_v in _ancestor_combos:
		if str((r_v as Dictionary).get("name", "")) == nm:
			return true
	return false

# 杩欎釜缁勫悎鍚嶆槸涓嶆槸鏌愪綅绁栧畻鐨勫浼犵粍鍚堬紵鏄氨杩斿洖绁栧畻 id锛堟煶鍗垮嵖鏈変袱濂楋紝鍙栫涓€濂楀涓婂氨琛岋級
func _ancestor_of_combo(nm: String) -> String:
	for aid_v in AncestorData.ANCESTORS.keys():
		var aid := str(aid_v)
		var a: Dictionary = AncestorData.ANCESTORS[aid]
		for t_v in a.get("tiers", []):
			if str((t_v as Dictionary).get("combo_name", "")) == nm:
				return aid
	return ""

# "姘旇路鍐呭姏" / "鏂囬挶路鐏垫櫠"
func _series_pair_cn(d: Dictionary) -> String:
	var out: Array = []
	for sk_v in d.get("need_series", []):
		out.append(str(SERIES_CN.get(str(sk_v), str(sk_v))))
	return "路".join(PackedStringArray(out))

func _bond_prog(b: Dictionary) -> int:
	var n := 0
	if b.has("need_series"):
		for sk_v in b["need_series"]:
			if _series_active(str(sk_v)):
				n += 1
		return n
	for nm_v in b["need"]:
		if _combo_has(str(nm_v)):
			n += 1
	return n

# 杩欎釜绯绘湁娌℃湁鍚堟垚杩?*浠绘剰涓€闃?*缁勫悎锛堝皬缇佺粖鎸?绯?绠楋紝涓嶆寫鍏蜂綋鏄摢涓€闃讹級
func _series_active(sk: String) -> bool:
	for r_v in _combined:
		if str((r_v as Dictionary).get("series", "")) == sk:
			return true
	return false

# 杩欏紶缇佺粖瑕佸嚑鏉★紙绾?灏忕緛缁婃寜绯伙紝鍏跺畠鎸夌粍鍚堝悕锛?func _bond_need_n(b: Dictionary) -> int:
	if b.has("need_series"):
		return (b["need_series"] as Array).size()
	return (b["need"] as Array).size()

# 璇ョ郴鍥涢樁缁勫悎涓€璧锋姮
func _boost_series(sk: String, pct: float) -> void:
	for tt in 4:
		var cc: Dictionary = _card_db.get("%s_%d_0" % [sk, tt], {})
		var cn := str(cc.get("combo_name", ""))
		if cn != "":
			_combo_boost[cn] = float(_combo_boost.get(cn, 0.0)) + pct

# 姣忔缁勫悎婵€娲诲悗閮界畻涓€閬嶏細鍑戦綈 鈫?鐢熸晥骞?*娑堣€?*杩欏紶缇佺粖
func _bond_check() -> void:
	if _bonds.is_empty():
		return
	var changed := false
	for i in range(_bonds.size() - 1, -1, -1):
		var b: Dictionary = _bonds[i]
		var need: Array = b.get("need", [])
		var prog := _bond_prog(b)
		b["prog"] = prog
		if prog >= _bond_need_n(b):
			# 缇佺粖鎴?鈫?瀹冪偣鍚嶇殑缁勫悎鍏ㄩ儴澧炲箙锛屾案涔咃細
			#   鏅€氬崱缁勫悎锛氫互鍚庢瘡娆¤Е鍙?脳(1+boost%)锛坃apply_combo 閲屼箻锛?			#   瀹朵紶缁勫悎锛氶偅浣嶇瀹楃殑鏈懡鎶€浼ゅ鐩存帴 +boost%锛堣窡瀹朵紶缁勫悎鑷繁閭ｅ璐﹀悓涓€涓?_anc_mod.dmg_pct锛?			var pct := float(b.get("boost", 0)) / 100.0
			if b.has("need_series"):
				# 灏忕緛缁婏細鐐瑰悕鐨勯偅涓や釜绯伙紝鍥涢樁缁勫悎涓€璧锋姮
				for sk_v in (b["need_series"] as Array):
					_boost_series(str(sk_v), pct)
			elif b.has("line"):
				# 绾跨緛缁婏細杩欐潯绾?*鎵€鏈夌郴銆佹墍鏈夐樁**鐨勭粍鍚堜竴璧锋姮锛堜笉姝㈤渶姹傞噷閭ｅ嚑涓級
				for sk_v in (CARD_LINES.get(str(b["line"]), []) as Array):
					_boost_series(str(sk_v), pct)
			for nm2_v in need:
				var nm2 := str(nm2_v)
				var aid2 := "" if _sys_combos.has(nm2) else _ancestor_of_combo(nm2)
				if aid2 != "":
					if not _anc_mod.has(aid2):
						_anc_mod[aid2] = {"dmg_pct": 0.0, "cd_pct": 0.0, "mp_flat": 0.0, "para_s": 0.0, "para_amp": 0.0,
							"life_flat": 0.0, "cap_add": 0.0, "wave_evo": 0.0, "tgt_add": 0.0,
							"ignite_add": 0.0, "burn_add": 0.0}
					_anc_mod[aid2]["dmg_pct"] = float(_anc_mod[aid2].get("dmg_pct", 0.0)) + pct * 100.0
					if aid2 == "zhujue": _sync_basic_family_bonus()
				elif not b.has("line") and not b.has("need_series"):
					_combo_boost[nm2] = float(_combo_boost.get(nm2, 0.0)) + pct
			_bonds.remove_at(i)
			_bonds_done += 1
			if b.has("line"):
				_toast("缇佺粖鎴?路 %s锛?s 鍏ㄩ儴缁勫悎 +%d%%锛? % [str(b["name"]), str(b["line"]), int(b.get("boost", 0))])
			elif b.has("need_series"):
				_toast("缇佺粖鎴?路 %s锛?s 鍏ㄩ儴缁勫悎 +%d%%锛? % [str(b["name"]), _series_pair_cn(b), int(b.get("boost", 0))])
			else:
				_toast("缇佺粖鎴?路 %s锛?s 鏁堟灉 +%d%%锛? % [str(b["name"]),
					"路".join(PackedStringArray(need)), int(b.get("boost", 0))])
			Aud.sfx("levelup", -6.0)
			changed = true
		elif prog > int(b.get("last", 0)):
			b["last"] = prog
			_toast("缇佺粖銆?s銆嶈繘搴?%d/%d" % [str(b["name"]), prog, need.size()])
			changed = true
	if changed:
		_refresh_trea_tile()
		if _combined_layer != null and _combined_layer.visible and _tot_tab == "bond":
			_refresh_tot_bond()

# 鍒锋柊锛氭鏁板瀷
func _on_trea_refresh() -> void:
	if _run_over or not _trea_pending or _trea_layer == null or not _trea_layer.visible:
		return
	if _trea_reroll <= 0:
		_toast("鍒锋柊娆℃暟鐢ㄥ畬浜?)
		return
	if not _rr_free():
		_trea_reroll -= 1
	_roll_trea()
	_pop_trea_cards()
	Aud.sfx("ui_click", -8.0)

# 鏀惧純锛氳繖涓€鎵嬩笉瑕佷簡锛屾崲 1 娆″埛鏂帮紙鏈轰細宸茬粡琚繖娆″紑椤靛悆鎺夛紝涓嶈兘鐧藉埛锛?func _on_trea_abandon() -> void:
	if _run_over or not _trea_pending or _trea_layer == null or not _trea_layer.visible:
		return
	_trea_pending = false
	_trea_reroll += 1
	_hide_trea()
	_refresh_trea_tile()
	_refresh_trea_btn()
	_toast("鏀惧純瀹濈墿 路 鍒锋柊 +1锛堢幇鏈?%d 娆★級" % _trea_reroll)
	Aud.sfx("ui_back", -8.0)

# 椤舵爮锛绘€昏锛斤細鎵撳紑鎬昏椤碉紙椤堕儴涓変釜鍒嗙被閽細鍗＄粍 / 瀹濈墿 / 缁勫悎锛?# 鏁村眰鍏ュ満锛氭贰鍏?+ 浠?0.965 寮瑰洖锛堟瘮"鍟湴鍑虹幇"椤烘粦锛?func _layer_in(c) -> void:
	if c == null:
		return
	MenuUI.Motion.fade_in(c)

func _show_totals() -> void:
	if _combined_layer == null:
		return
	_combined_layer.visible = true
	_combined_layer.move_to_front()
	_layer_in(_combined_layer)
	_set_tot_tab(_tot_tab)

func _set_tot_tab(k: String) -> void:
	_tot_tab = k
	for i in _tot_tabs.size():
		var b: Button = _tot_tabs[i]
		var on := str(_tot_keys[i]) == k
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.48, 0.14, 0.10, 0.96) if on else Color(0.93, 0.90, 0.82, 0.98)
		sb.set_corner_radius_all(6)
		sb.border_color = Color(0.95, 0.76, 0.36, 0.95) if on else Color(0.55, 0.45, 0.30, 0.55)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(0.97, 0.90, 0.74) if on else Color(0.40, 0.33, 0.24))
		b.add_theme_color_override("font_hover_color", Color(0.97, 0.90, 0.74) if on else Color(0.24, 0.18, 0.10))
	if _tot_bond_root == null:
		return
	_tot_bond_root.visible = k == "bond"
	_combined_icons.visible = k == "combo"
	_combined_detail.visible = false
	if k == "bond":
		_refresh_tot_bond()
	else:
		_refresh_combined()

# 鍗＄粍鍒嗛〉锛氳繖涓€灞€鎶藉埌鐨勫崱
# 瀹濈墿鍒嗛〉锛氱緛缁婂浘鏍囧锛堢偣鍥炬爣鎵嶇湅璇︽儏锛?func _refresh_tot_bond() -> void:
	for ch in _tot_bond_root.get_children():
		ch.queue_free()
	_lbl("缇佺粖 %d 寮狅紙宸叉垚 %d锛夈€€路銆€宸茶В閿?%d/%d銆€路銆€鐐瑰浘鏍囩湅璇︽儏" % [_bonds.size(), _bonds_done, _bond_unlocked.size(), BOND_POOL.size()],
		Vector2(0, 0), Vector2(600, 26), 16, DIM, _tot_bond_root)
	if _bonds.is_empty():
		_lbl("杩樻病鏈夌緛缁?鈥斺€?姣忔竻涓€娉㈡湁 1 娆″疂鐗╂満浼?, Vector2(0, 40), Vector2(600, 30), 20,
			Color(0.55, 0.48, 0.36), _tot_bond_root)
		return
	for i in mini(_bonds.size(), 12):
		var b: Dictionary = _bonds[i]
		var ic := BondIcon.new()
		ic.position = Vector2(float(i % 4) * 146.0, 40.0 + float(i / 4) * 152.0)
		ic.size = Vector2(132, 132)
		ic.title = str(b["name"])
		ic.glyph = str(b.get("glyph", "缇?))
		ic.quality = int(b.get("quality", 2))
		ic.prog = _bond_prog(b)
		ic.need_n = _bond_need_n(b)
		ic.pressed.connect(func() -> void: _show_bond_detail(b))
		_tot_bond_root.add_child(ic)

func _show_bond_detail(b: Dictionary) -> void:
	for ch in _combined_detail.get_children():
		ch.queue_free()
	_combined_detail.visible = true
	var p := Panel.new()
	p.position = Vector2(140, 300)
	p.size = Vector2(440, 392)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.85, 0.99)
	sb.set_corner_radius_all(9)
	sb.border_color = QUALITY_COLORS[clampi(int(b.get("quality", 2)) - 1, 0, 4)]
	sb.set_border_width_all(7)
	p.add_theme_stylebox_override("panel", sb)
	_combined_detail.add_child(p)
	var need: Array = b.get("need", [])
	_lbl(str(b["name"]), Vector2(170, 322), Vector2(360, 40), 30, INK, _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl("缇?缁娿€€%d/%d" % [_bond_prog(b), _bond_need_n(b)], Vector2(170, 366), Vector2(360, 28), 19,
		Color(0.46, 0.20, 0.10), _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	if b.has("need_series"):
		_lbl("鎴愬悗锛? + _series_pair_cn(b) + " 鍏ㄩ儴缁勫悎 +%d%%" % int(b.get("boost", 0)), Vector2(170, 402), Vector2(380, 32), 20, INK, _combined_detail)
	else:
		_lbl("鎴愬悗锛? + str(b.get("lbl", "缁勫悎鏁堟灉 +%d%%")) % int(b.get("boost", 0)), Vector2(170, 402), Vector2(380, 32), 21, INK, _combined_detail)
	if b.has("line"):
		_lbl("锛堟暣鏉＄嚎涓嶅垎闃讹紝鍏ㄩ儴鍚冭繖涓骞咃級", Vector2(170, 424), Vector2(380, 24), 15, Color(0.46, 0.20, 0.10), _combined_detail)
	elif b.has("need_series"):
		_lbl("锛堟瘡涓郴浠绘剰涓€闃剁粍鍚堥兘绠楋級", Vector2(170, 424), Vector2(380, 24), 15, Color(0.46, 0.20, 0.10), _combined_detail)
	_lbl("瑕佸噾榻愮殑缁勫悎锛堟瘡濂?3 寮犲悓濂楀崱鍚堟垚锛夛細" if not b.has("need_series") else "瑕佸噾榻愮殑绯伙紙浠讳竴涓€闃剁粍鍚堝嵆鍙級锛?,
		Vector2(170, 442), Vector2(380, 26), 16, DIM, _combined_detail)
	var y := 472.0
	if b.has("need_series"):
		for sk_v in b["need_series"]:
			var sk := str(sk_v)
			var ok2 := _series_active(sk)
			_lbl(("宸插悎鎴愩€€" if ok2 else "杩樼己銆€銆€") + str(SERIES_CN.get(sk, sk)) + " 绯讳换鎰忎竴濂?, Vector2(184, y), Vector2(360, 26), 18,
				Color(0.28, 0.44, 0.26) if ok2 else Color(0.56, 0.40, 0.26), _combined_detail)
			y += 30.0
	else:
		for nm_v in need:
			var nm := str(nm_v)
			var ok := _combo_has(nm)
			_lbl(("宸插悎鎴愩€€" if ok else "杩樼己銆€銆€") + nm, Vector2(184, y), Vector2(360, 26), 18,
				Color(0.28, 0.44, 0.26) if ok else Color(0.56, 0.40, 0.26), _combined_detail)
			y += 30.0
	_btn("脳", Rect2(592, 302, 34, 30), 20, Color(0.97, 0.93, 0.85), DIM,
		func(): _combined_detail.visible = false, _combined_detail)

# 缇佺粖鍥炬爣锛氬搧闃舵弿杈?+ 澧ㄥ瓧鍦嗙珷 + 鍙充笂杩涘害瑙掓爣
class BondIcon extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal pressed
	var title := ""
	var glyph := "缇?
	var quality := 2
	var prog := 0
	var need_n := 3
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var q := clampi(quality - 1, 0, 4)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.93, 0.86, 0.98)
		sb.set_corner_radius_all(8)
		sb.border_color = QC[q]
		sb.set_border_width_all(5)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c := Vector2(size.x * 0.5, size.y * 0.38)
		var r := size.x * 0.24
		draw_circle(c, r, Color(0.93, 0.90, 0.82))
		draw_arc(c, r, 0.0, TAU, 40, QC[q], 2.0)
		draw_string(F, c + Vector2(-r * 0.40, r * 0.42), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(size.x * 0.28), Color(0.14, 0.11, 0.08))
		draw_string(F, Vector2(2, size.y - 12), title, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, 16,
			Color(0.20, 0.16, 0.12))
		var done := prog >= need_n
		draw_rect(Rect2(size.x - 46, 6, 40, 20), Color(0.30, 0.44, 0.26) if done else Color(0.62, 0.42, 0.14))
		draw_string(F, Vector2(size.x - 46, 22), "%d/%d" % [prog, need_n], HORIZONTAL_ALIGNMENT_CENTER,
			40, 14, Color(0.98, 0.96, 0.90))
		draw_rect(Rect2(6, 6, 22, 20), Color(0.64, 0.22, 0.15))
		draw_string(F, Vector2(6, 22), "缇?, HORIZONTAL_ALIGNMENT_CENTER, 22, 14, Color(0.98, 0.92, 0.78))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

func _apply_aug(key: String, val: float) -> void:
	if _core == null:
		return
	var h: Dictionary = _core.hero
	match key:
		"atk_pct":
			_core.attr_add_amp("atk", val / 100.0)
			h["atk"] = _core.attr_final("atk")
		"hp_pct":
			var ratio := 1.0
			if float(h["hp_max"]) > 0.0:
				ratio = clampf(float(h["hp"]) / float(h["hp_max"]), 0.0, 1.0)
			_core.attr_add_amp("hp", val / 100.0)
			h["hp_max"] = _core.attr_final("hp")
			h["hp"] = float(h["hp_max"]) * ratio
		"aspd_pct":
			_core.attr_add_amp("aspd", val / 100.0)
			h["aspd"] = minf(MAX_ASPD, _core.attr_final("aspd") / float(_core.ATTR_BASE["aspd"]))
		"crit_add":
			_core.attr_add("crit", val / 100.0)
			h["crit"] = _core.attr_final("crit")
		"critdmg_add":
			_core.attr_add("cdmg", val / 100.0)
			h["crit_dmg"] = _core.attr_final("cdmg")
		"cut_add":
			_core.type_add("鐗╃悊", "red_f", val / 100.0)
			h["cut"] = _core.type_effective_field("鐗╃悊", "red_f")
		"cutall_add":
			for t in _core.DMG_TYPES:
				if t != "鐪熷疄":
					_core.type_add(t, "red_f", val / 100.0)
			h["cut"] = _core.type_effective_field("鐗╃悊", "red_f")
			h["cut_all"] = 0.0 # 鍏郴瀛楁宸插寘鍚繖娆″鐩娿€?		"pen_flat":
			# v6锛氫竷绯诲浐瀹氱┛閫忎竴璧峰姞锛堢湡瀹炰笉鍚冪┛閫忥紝璺宠繃锛?			for t in _core.DMG_TYPES:
				if t != "鐪熷疄":
					_core.type_add(t, "pen_f", val / 100.0)
		"dmgall_add":
			for t in _core.DMG_TYPES:
				if t != "鐪熷疄":
					_core.type_add(t, "amp_f", val / 100.0)
			h["dmg_all"] = _core.type_amp("鐗╃悊")
		"mp_add":
			_core.attr_add("mp", val)
			_mp_max = maxf(1.0, _core.attr_final("mp"))
			_mp = minf(_mp, _mp_max)
			h["mp_max"] = _mp_max
			h["mp"] = _mp
		"gold_pct":
			_gold_pct += val
		"killheal":
			_core.kill_heal = float(_core.kill_heal) + val / 100.0
		"exp_pct":
			_exp_pct += val

# 杩涢樁鍗★細涓夐€変竴鐨勫崱闈紙200脳300锛?class AugCard extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	const QN := ["鑹搧", "鐜勫搧", "鍦板搧", "澶╁搧"]
	const CF := preload("res://kushou/card_frame.gd")
	signal picked
	var title := ""
	var glyph := "鏀?
	var effect := ""
	var desc := ""
	var quality := 2
	var o: Dictionary = {}      # 杩欎竴寮犳幏鍒板摢鏉¤繘闃?	var oval := 0               # 鏀惧ぇ鍚庣殑鏁板€?	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var q := clampi(quality - 1, 0, 4)
		var framed := CF.draw_on(self, quality, size)
		if framed:
			CF.content_panel(self, Rect2(16, 34, size.x - 32, size.y - 52))
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.96, 0.93, 0.86, 0.99)
			sb.set_corner_radius_all(9)
			sb.border_color = QC[q]
			sb.set_border_width_all(6)
			draw_style_box(sb, Rect2(Vector2.ZERO, size))
		# 鍙充笂瑙掑搧闃跺嵃锛堝拰鎶藉崱鍗￠潰鐨?鏍囬鍦ㄦ渶涓?瀵归綈锛屼笉鎶㈡爣棰樼殑浣嶇疆锛?		var tp := Vector2(size.x - 62, 14)
		draw_rect(Rect2(tp, Vector2(48, 22)), QC[q])
		draw_string(F, tp + Vector2(0, 16), QN[clampi(quality - 2, 0, 3)],
			HORIZONTAL_ALIGNMENT_CENTER, 48, 13, Color(0.98, 0.96, 0.90))
		draw_string(F, Vector2(0, 52), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28 if title.length() <= 3 else 24, Color(0.14, 0.11, 0.08))
		# 鍥炬爣缂╁皬锛岀粰搴曢儴璇存槑鑵惧嚭鏇村ぇ瀛楀彿鐨勭┖闂?		var c := Vector2(size.x * 0.5, 134.0)
		draw_circle(c, 38, Color(0.93, 0.90, 0.82))
		draw_arc(c, 38.0, 0.0, TAU, 48, QC[q], 2.0)
		draw_string(F, c + Vector2(-11, 12), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.13, 0.12, 0.11))
		draw_string(F, Vector2(0, 214), effect, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(0.46, 0.20, 0.10))
		draw_multiline_string(F, Vector2(10, 244), desc, HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 17, 2, Color(0.38, 0.33, 0.26))
		draw_string(F, Vector2(0, 292), "鐐瑰嚮閫夊彇", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(0.58, 0.50, 0.36))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()

func _make_foe_token(f: Dictionary):
	var kind := str(f.get("kind", "normal"))
	var boss := bool(f.get("boss", false))
	var rad := 52.0 if boss else 26.0        # Boss 鍦嗙墝鏄庢樉鏇村ぇ
	var ring := Color(0.42, 0.36, 0.28)
	if kind == "coin":
		ring = Color(0.95, 0.78, 0.25)        # 閽辨€細浜噾
	elif kind == "crystal":
		ring = Color(0.42, 0.72, 0.95)        # 鏅舵€細浜摑
	elif kind == "chal":
		ring = Color(0.68, 0.38, 0.88)        # 鎸戞垬鎬細绱?	elif boss:
		ring = Color(0.95, 0.62, 0.12)        # Boss锛氶噾姗?	var mark_ch := "鐜? if boss else ("閽? if kind == "coin" else ("鏅? if kind == "crystal" else ("鎸? if kind == "chal" else "鎬?)))
	var msize := 22 if not boss else 38
	# 姹犻噷鏈夊氨澶嶇敤锛圱okenActor 姣忓缓涓€涓兘瑕?new Shader/ShaderMaterial锛屽緢璐碉級
	if not _foe_pool.is_empty():
		var tk0 = _foe_pool.pop_back()
		tk0.reset_pose()
		tk0.setup(null, rad, ring, false)
		if is_instance_valid(tk0._sprite):
			tk0._sprite.position = Vector2(0.0, -rad)
		tk0.show_bar = true
		tk0.bar_w = 84.0 if boss else 54.0
		tk0.unit_name = str(f.get("name", ""))
		tk0.position = _core.position + Vector2(float(f["x"]), float(f["y"]))
		tk0.visible = true
		var mk: Label = tk0.get_meta("mark", null)
		if mk != null:
			mk.text = mark_ch
			mk.position = Vector2(-rad, -rad * 2.0 + 6.0)
			mk.size = Vector2(rad * 2.0, rad * 1.5)
			mk.add_theme_font_size_override("font_size", msize)
		tk0.queue_redraw()
		tk0.play_spawn(float(int(f.get("_tid", 0)) % 4) * 0.02)
		return tk0
	var foe_tex := _foe_art(str(f.get("name", "")))
	var tk = TokenActor.new()
	tk.round_mask = foe_tex == null
	tk.setup(foe_tex, rad, ring, false)
	tk.show_bar = true
	tk.bar_w = 84.0 if boss else 54.0
	tk.unit_name = str(f.get("name", ""))
	tk.z_index = 5
	tk.position = _core.position + Vector2(float(f["x"]), float(f["y"]))
	var mark := Label.new()
	mark.visible = foe_tex == null
	mark.text = mark_ch
	mark.position = Vector2(-rad, -rad * 2.0 + 6.0)
	mark.size = Vector2(rad * 2.0, rad * 1.5)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_override("font", FONT)
	mark.add_theme_font_size_override("font_size", msize)
	mark.add_theme_color_override("font_color", Color(0.30, 0.24, 0.16))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tk.add_child(mark)
	tk.set_meta("mark", mark)
	_cam.add_child(tk)
	tk.play_spawn(float(int(f.get("_tid", 0)) % 4) * 0.02)
	return tk

# ---------------- 鍗℃睜 / 缁勫悎 ----------------
func _init_cards() -> void:
	var d: Dictionary = CardData.build()
	_card_db = d["cards"]
	_set_cards = d["sets"]
	# 鈿?鏅€氬崱缁勫悎涓庡浼犵粍鍚堟湁閲嶅悕锛堝洖鏄?/ 鐢熸伅锛夛紝鍏堣涓嬫櫘閫氬崱杩欎竴鎵瑰悕瀛楋紝
	#   缇佺粖缁撶畻鏃朵紭鍏堟寜鏅€氬崱绠楋紝鍒鎴愭煇浣嶇瀹楃殑瀹朵紶缁勫悎
	_sys_combos.clear()
	for sid_v in _set_cards.keys():
		var ids0: Array = _set_cards[sid_v]
		if ids0.is_empty():
			continue
		var c0: Dictionary = _card_db.get(str(ids0[0]), {})
		if not c0.is_empty() and not c0.has("ancestor"):
			_sys_combos[str(c0.get("combo_name", ""))] = true
	_pool = []
	for id_v in d["entries"]:
		if LevelState.card_allowed(str(id_v)):
			_pool.append(id_v)
	if GameState.new_cards_unlocked:
		var ng: Dictionary = CardData.new_group()
		var ng_cards: Dictionary = ng.get("cards", {})
		for cid_v in ng_cards.keys():
			_card_db[str(cid_v)] = ng_cards[cid_v]
		for id_v in ng.get("entries", []):
			_pool.append(id_v)
	_cards.clear()
	_acquired.clear()
	_combined.clear()
	_ancestors.clear()
	_ancestor_combos.clear()
	# 瀹朵紶鍗★細骞惰繘鍚屼竴濂楀崱琛紙褰㈢姸涓庢櫘閫氬崱涓€鑷达紝鎵€浠ョ洿鎺ュ悎骞讹級
	var a: Dictionary = AncestorData.build()
	var acards: Dictionary = a["cards"]
	for cid_v in acards.keys():
		_card_db[cid_v] = acards[cid_v]
	var asets: Dictionary = a["sets"]
	for sid_v in asets.keys():
		_set_cards[sid_v] = asets[sid_v]
	# 鐐崱锛堢嫭绔嬪崱锛屼笉杩涘锛?	var shinies: Dictionary = AncestorData.shiny_cards()
	for sh_v in shinies.keys():
		_card_db[sh_v] = shinies[sh_v]
	_card_db["shiny_zhongli"] = {
		"id": "shiny_zhongli", "shiny": true, "ancestor": "", "ancestor_name": "",
		"series": "zhongli", "label": "閲嶅埄", "tier": -1, "idx": 0,
		"name": "閲嶅埄", "quality": 5, "art": "res://assets/items/loot_silver.png",
		"own_key": "", "own_val": 0, "own_text": "鎶藉崱鏃?10% 澶嶅埗閫変腑鍗?,
		"set_id": "", "set_size": 0, "combo_name": "", "combo_text": "",
		"trigger": "", "combo_key": "", "combo_val": 0,
		"entry": false, "unlock_ids": [],
		"shiny_self": "鎶藉崱鏃?10% 澶嶅埗閫変腑鍗?,
		"shiny_devour": "澶嶅埗浣撳綋鍦哄悶鍣?路 鏁堟灉涓庤繘搴︿繚鐣?,
		"shiny_per": "澶嶅埗浣撳啀鐙珛鎺?路 閾惧紡"}
	_card_db["shiny_backwash"] = {
		"id": "shiny_backwash", "shiny": true, "ancestor": "", "ancestor_name": "",
		"series": "backwash", "label": "鍥炴疆", "tier": -1, "idx": 0,
		"name": "鍥炴疆", "quality": 4, "art": "res://assets/items/chest_jade.png",
		"own_key": "", "own_val": 0, "own_text": "鏀?+4 路 闃?+4 路 琛€ +40 路 鍐?+40",
		"set_id": "", "set_size": 0, "combo_name": "", "combo_text": "",
		"trigger": "", "combo_key": "", "combo_val": 0,
		"entry": false, "unlock_ids": [],
		"shiny_self": "鏀?+4 路 闃?+4 路 琛€ +40 路 鍐?+40",
		"shiny_devour": "杩涘崱缁勫嵆瑙﹀彂锛氭尝鏁板洖閫€ 5 娉?,
		"shiny_per": ""}
	_backwash_done = false
	_devoured.clear()
	_combo_boost.clear()
	_combo_frac.clear()
	_bond_unlocked.clear()
	_bond_taken.clear()
	_crystal_lock = false
	_rare_buffs.clear()
	_rare_taken.clear()
	_curio_cd = 0.0
	_curio_uses = 0
	_run_over = false
	_run_time = 0.0
	for nm_v in BOND_ENTRIES:
		_bond_unlocked[str(nm_v)] = true
	_anc_mod.clear()
	_elem_mod.clear()
	_shiny_rolled.clear()
	_shiny_used.clear()
	# 涓昏榛樿瑙ｉ攣锛屼絾瀹朵紶鍗℃槸銆岃绁炪€嶅眰鐨勪笢瑗匡細绗?5 鍏虫墠寮€濮嬭繘姹?	if LevelState.has_feature("ancestor"):
		_grant_ancestor("zhujue")

# 璇峰埌涓€浣嶇瀹楋細鎶婂畠鐨勩€屽垵绾у叆鍙ｅ崱銆嶆斁杩涙娊鍗℃睜
func _family_card_allowed(id: String) -> bool:
	var card: Dictionary = _card_db.get(id, {})
	if card.is_empty():
		return false
	if not card.has("ancestor") or bool(card.get("shiny", false)):
		return true
	return GameState.family_tier_allowed(str(card["ancestor"]), int(card.get("tier", -1)))

func _grant_ancestor(aid: String) -> void:
	if aid == "mingzhu":
		_mingzhu = true
	if aid == "zhiyuan":
		_enable_zhiyuan()
	if aid == "chenshi2":
		_shixi = true
		_stone_def = float(_core.hero.get("def", 0.0)) if _core != null else 0.0
	if not AncestorData.ANCESTORS.has(aid):
		return
	_ancestors[aid] = 0
	var eid := "%s_t0_0" % aid
	if _card_db.has(eid) and not _pool.has(eid) and not _acquired.has(eid):
		_pool.append(eid)

# 瀹朵紶缁勫悎婵€娲伙細涓嶅仛鏅€氬崱閭ｅ灞炴€х粨绠楋紝鍙櫥璁?+ 瑙ｉ攣涓嬩竴妗ｅ叆鍙?func _activate_ancestor_set(sid: String, first: Dictionary, ids: Array) -> void:
	var srcs: Array = []
	for cid_v in ids:
		var cid := str(cid_v)
		srcs.append(str((_card_db[cid] as Dictionary)["name"]))
		_cards.erase(cid)
	var ai := str(first["ancestor"])
	var t := int(first["tier"])
	var arc := {"ancestor": ai, "tier": t, "sources": srcs,
		"name": str(first["combo_name"]), "text": str(first["combo_text"])}
	var cid0 := "%s_t%d_0" % [ai, t]
	if _card_db.has(cid0):
		var c0: Dictionary = _card_db[cid0]
		arc["art"] = str(c0.get("art", ""))
		arc["quality"] = int(c0.get("quality", 2))
	_ancestor_combos.append(arc)
	# 瀹朵紶缁勫悎涔熸挱涓夊悎涓€鍔ㄧ敾
	_play_merge_fx(arc)
	if LevelState.current_level == 5 and _ancestor_combos.size() == 2 and not _family_shiny_done:
		_family_shiny_ready = true   # 绗簲鍏虫槸璇风寮曞锛氱浜岀粍瀹朵紶鍚庡繀鍑轰竴寮犵偒褰?	_add_ancestor_effects(ai, first.get("effects", {}))
	if ai == "zhujue":
		_apply_hero_passive(first.get("effects", {}))
	_toast_card(str(first["combo_name"]), int(first["quality"]),
		"%s 路 %s锛?d 寮犲凡娓呯┖锛? % [str(first["ancestor_name"]), str(first["combo_text"]), ids.size()])
	var nid := "%s_t%d_0" % [ai, t + 1]
	if _card_db.has(nid) and _family_card_allowed(nid) and not _pool.has(nid) and not _acquired.has(nid):
		_pool.append(nid)
		_toast_card(str((_card_db[nid] as Dictionary)["name"]), int(first["quality"]), "涓嬩竴妗ｅ叆鍙ｅ凡鍏ユ睜")
	elif _card_db.has(nid) and not _family_card_allowed(nid):
		_toast("涓嬩竴妗ｅ浼犻渶 %d 鏄燂紝璇峰湪灞€澶栬繘闃? % (t + 1))
	_page = 0
	_refresh_deck()
	_bond_check()
	if _combined_layer != null and _combined_layer.visible:
		_refresh_combined()

func _set_progress(set_id: String) -> int:
	if not _set_cards.has(set_id):
		return 0
	var n := 0
	for id in _set_cards[set_id]:
		if _cards.has(id):
			n += 1
	return n

func _on_core_coin(n: int) -> void:
	if _run_over:
		return
	_add_wen(n)

# v6锛氫竴鍒囨枃閽辨敹鍏ラ兘璧拌繖閲岋紙濂借锛诲己鍖栵冀鐨勪环閽辩伅璺熺潃浜?鐏級
func _add_wen(raw: int) -> void:
	if LevelState.current_level == 1:
		raw = int(round(float(raw) * 1.8))   # 绗竴鍏虫枃閽卞姞閫燂細10 绾ц繘闃惰 840锛屼袱娉㈠唴鏀掑緱鍑烘潵

	_pulse_chip(_coin_lb)
	if raw <= 0:
		return
	_wen += int(round(float(raw) * (1.0 + _gold_pct / 100.0)))
	if _coin_lb != null:
		_coin_lb.text = str(_wen)
	_refresh_str_tile()

# core 鐨?coin_drop锛氶挶鎬?/ 鍖 / boss 鎺夌殑鐪熼挶锛堝甫钀界偣锛屽厛鍙璐︼級
func _on_coin_drop(amount: int, pos: Vector2) -> void:
	if _run_over or _core == null or amount <= 0:
		return
	_add_wen(amount)
	_spawn_fly(_core.position + pos + Vector2(0, -18), Vector2(99, 40), Color(0.90, 0.71, 0.30), 3)

# 鎾掍竴鎶婇鍚戣硣婧愭潯鐨勫皬鐐癸紙閲戝竵閲戙€佺伒鏅惰摑锛?func _spawn_fly(from: Vector2, to: Vector2, col: Color, n: int) -> void:
	for i in n:
		if _fly.size() > 60:
			break
		_fly.append({"sx": from.x + randf_range(-16.0, 16.0), "sy": from.y + randf_range(-12.0, 12.0),
			"x": from.x, "y": from.y,
			"tx": to.x + randf_range(-18.0, 18.0), "ty": to.y + randf_range(-8.0, 8.0),
			"t": randf_range(0.0, 0.12), "col": col, "r": randf_range(4.5, 7.0)})

# 鏁村睆寰棯锛堟妧鑳介噴鏀?澶т簨浠剁敤锛夛細鏆栫焊鑹蹭竴闂紝涓嶅埡鐪?# 闀滃ご鎺ㄨ繘锛堢缉鏀炬垬鍦哄唴瀹癸紝涓嶅姩 HUD锛?# 鏀跺熬闀滃ご锛氭帹杩?鈫?鍋滀竴涓?鈫?閫€鍥?func _cam_pulse(s: float, hold: float) -> void:
	if _cam == null:
		return
	_cam_zoom_to(s, 0.26)
	var tw := create_tween().bind_node(_cam)
	tw.tween_interval(hold)
	tw.tween_property(_cam, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _cam_zoom_to(s: float, dur: float) -> void:
	if _cam == null:
		return
	var tw := create_tween().bind_node(_cam)
	tw.tween_property(_cam, "scale", Vector2(s, s), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _screen_flash(col: Color, a: float, dur := 0.16) -> void:
	if _flash_rect == null:
		return
	_flash_rect.color = Color(col.r, col.g, col.b, a)
	var tw := create_tween().bind_node(_flash_rect)
	tw.tween_property(_flash_rect, "color:a", 0.0, dur)

# 鎶€鑳介噴鏀剧殑鏁翠綋鍙嶉锛氬井闂?+ 杞婚渿 + 椤垮抚
# 姣忕郴涓€涓棯鍏夐鑹诧細鐏銆侀噾閲戙€佹湪缁裤€佸彫鍞ょ传銆佺湡瀹炴殫绱€佺墿鐞嗙焊
const SKILL_TINT := {
	"閲戠郴": Color(1.0, 0.92, 0.60),
	"鐏郴": Color(1.0, 0.70, 0.40),
	"鏈ㄧ郴": Color(0.70, 0.95, 0.64),
	"鍙敜": Color(0.78, 0.70, 1.0),
	"鐗╃悊": Color(0.96, 0.93, 0.86),
	"鐪熷疄": Color(0.72, 0.52, 0.88),
}

func _skill_cast_juice() -> void:
	_screen_flash(SKILL_TINT.get(_cast_dtype, Color(1.0, 0.94, 0.80)), 0.16, 0.18)
	Aud.sfx("swing", -7.0, 0.85)
	_core._shake = maxf(float(_core._shake), 5.0)
	_core._hitstop = maxf(float(_core._hitstop), 0.045)

func _pulse_chip(lb: Label) -> void:
	if lb == null:
		return
	lb.pivot_offset = lb.size * 0.5
	_pulses[lb] = 1.0

func _tick_pulses(dt: float) -> void:
	if _pulses.is_empty():
		return
	for lb_v in _pulses.keys():
		var lb: Label = lb_v
		var v := float(_pulses[lb_v]) - dt * 3.5
		if v <= 0.0:
			lb.scale = Vector2.ONE
			_pulses.erase(lb_v)
		else:
			_pulses[lb_v] = v
			var k := 1.0 + 0.22 * v
			lb.scale = Vector2(k, k)

func _tick_fly(dt: float) -> void:
	if _fly.is_empty():
		return
	for i in range(_fly.size() - 1, -1, -1):
		var d: Dictionary = _fly[i]
		d["t"] = float(d["t"]) + dt * 2.6
		if float(d["t"]) >= 1.0:
			_fly.remove_at(i)
			continue
		var e := float(d["t"])
		var ee := 1.0 - pow(1.0 - e, 2.0)          # 鍏堝揩鍚庢參
		d["x"] = lerpf(float(d["sx"]), float(d["tx"]), ee)
		d["y"] = lerpf(float(d["sy"]), float(d["ty"]), ee) - sin(e * PI) * 56.0
	_fly_layer.queue_redraw()

func _trigger_combos(trigger: String) -> void:
	for rec in _combined:
		if str(rec.get("trigger", "")) == trigger:
			_apply_combo(rec)
	if _combined_layer != null and _combined_layer.visible:
		_refresh_combined()

# 绗洓鍏虫寫鎴樺埛鎬噺鍗婏紝鍗遍€斺€滄寫鎴樻敹鐩娾€濆崱鍋峰伔琛?1.5 鍊嶏紝淇濅綇椋庨櫓鎹㈡敹鐩?func _peril_scale(v: float) -> float:
	return v

func _apply_combo(rec: Dictionary) -> void:
	rec["stacks"] = int(rec.get("stacks", 0)) + 1
	var key := str(rec.get("combo_key", ""))
	# 缇佺粖澧炲箙锛氳繖寮犵粍鍚堣缇佺粖鐐瑰悕杩囷紝灏辨寜姣斾緥鏀惧ぇ锛坃combo_boost 閲屾槸 0.4 = +40%锛?	var val := float(rec.get("combo_val", 0)) * (1.0 + float(_combo_boost.get(str(rec.get("name", "")), 0.0)))
	match key:
		"atk":
			_stats["atk"] = float(_stats["atk"]) + val
			if _core != null:
				_apply_flat_growth(val, 0.0)
		"def":
			# v6: def removed
			if _core != null:
				# v6锛氱粍鍚堥槻寰′篃璧颁竷绯诲浐瀹氬噺鍏嶏紝鍜屽崱鐗岄槻寰′竴鑷?				var def_red := val * DEF_CARD_TO_RED
				if def_red > 0.0:
					for t in _core.DMG_TYPES:
						if t != "鐪熷疄":
							_core.type_add(t, "red_f", def_red)
		"hp":
			_stats["hp"] = float(_stats["hp"]) + val
			if _core != null:
				_apply_flat_growth(0.0, val)
		"heal":
			if _core != null: _core.heal_hero(val)
		"gold_pct":
			_gold_pct += val
		"gold_flat":
			_wen += _take_int(rec, val)
			if _coin_lb != null: _coin_lb.text = str(_wen)
		"crystal_flat":
			_gain_crystal(_take_int(rec, val))
			_update_crystal()
		"mp_flat":
			_mp = minf(_mp_max, _mp + val)     # v5锛氬唴鍔涚郴缁勫悎 鈫?鍥炲唴鍔?		# ---- v13 缇?/ 闄?----
		"count_flat":
			_wave_extra += _take_int(rec, val)
		"coin_count":
			_coin_count_extra += _take_int(rec, _peril_scale(float(val)))
		"crystal_count":
			_crystal_count_extra += _take_int(rec, _peril_scale(float(val)))
		"treasure_pct":
			_treasure_pct += _peril_scale(val)
		"boss_pct":
			_boss_pct += _peril_scale(val)
		"devour_n":
			_devour_keep(_take_int(rec, val))
		"killnum_pct":
			_killnum_pct += val
	# v13锛氱粍鍚堣繕甯︿竴鏉°€屽叏灞€闅惧害銆?	var ek := str(rec.get("combo_extra_key", ""))
	if ek == "diff_pct":
		_diff_pct += float(rec.get("combo_extra_val", 0))
	if key in ["count_flat", "coin_count", "crystal_count", "treasure_pct", "boss_pct"] or ek == "diff_pct":
		_push_run_mods()

# 鏁存暟绫荤粍鍚堬紙+1 鏂囬挶 / +2 鍙€?/ +1 寮犲悶鍣€︼級鐨勫骞呭彇鏁达細
#   +40% 浣滅敤鍦?1 涓?= 1.4锛岀洿鎺?int() 浼氳鎶规垚 1锛堢瓑浜庢病鍔狅級銆?#   杩欓噷鎶婂皬鏁版敀杩?_combo_frac锛屾敀澶?1 灏卞缁?1 鐐?鈥斺€?闀挎椂闂寸湅灏辨槸瀹炴墦瀹炵殑 +40%銆?func _take_int(rec: Dictionary, val: float) -> int:
	var nm := str(rec.get("name", ""))
	var whole := int(floor(val))
	var frac := val - float(whole)
	if frac <= 0.0001:
		return whole
	var acc := float(_combo_frac.get(nm, 0.0)) + frac
	var extra := int(floor(acc))
	_combo_frac[nm] = acc - float(extra)
	return whole + extra

func _check_sets() -> void:
	var changed := true
	while changed:
		changed = false
		for sid_v in _set_cards.keys():
			var sid := str(sid_v)
			var ids: Array = _set_cards[sid]
			var all_in := true
			for cid in ids:
				if not _cards.has(str(cid)) and not _virtual_cards.has(str(cid)):
					all_in = false
					break
			if all_in:
				_activate_set(sid)
				changed = true
				break

# 涓夊悎涓€鍔ㄧ敾锛氫笁寮犲崱鍚戜腑闂存眹鑱氾紝娣″嚭鍚庡啀鐢熸垚涓€寮狅紝椋炲悜椤舵爮銆屾€昏銆嶅苟鎵撳紑
func _play_merge_fx(rec: Dictionary) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 150
	add_child(layer)
	var ap := str(rec.get("art", ""))
	var tex: Texture2D = null
	if ap != "" and ResourceLoader.exists(ap):
		tex = load(ap)
	var center := Vector2(360, 470)
	for i in 3:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.size = Vector2(92, 124)
		t.position = center + Vector2(-160.0 + float(i) * 160.0, 0.0) - t.size * 0.5
		t.modulate.a = 0.0
		layer.add_child(t)
		var tw := create_tween()
		tw.set_parallel(false)
		tw.tween_property(t, "modulate:a", 1.0, 0.12).set_delay(float(i) * 0.05)
		tw.parallel().tween_property(t, "position", center - t.size * 0.5, 0.30).set_delay(0.18 + float(i) * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.chain().tween_property(t, "modulate:a", 0.0, 0.10)
	# 姹囪仛瀹屾垚鍚庯細鍚堟垚涓€寮狅紝椋炲悜銆屾€昏銆?	var tw2 := create_tween()
	tw2.tween_interval(0.62)
	tw2.tween_callback(func() -> void: _fly_to_totals(layer, tex, center))

func _fly_to_totals(layer: Control, tex: Texture2D, from: Vector2) -> void:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.size = Vector2(92, 124)
	t.position = from - t.size * 0.5
	t.pivot_offset = t.size * 0.5
	layer.add_child(t)
	var twg := create_tween()
	twg.tween_property(t, "modulate", Color(1.6, 1.35, 0.7), 0.08)
	twg.tween_property(t, "modulate", Color(1, 1, 1), 0.12)
	var target := Vector2(604, 109)
	if _tot_btn != null:
		target = _tot_btn.global_position + _tot_btn.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(t, "position", target - t.size * 0.5, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(t, "scale", Vector2(0.28, 0.28), 0.46)
	tw.tween_property(t, "modulate:a", 0.0, 0.14).set_delay(0.34)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
		# 鏈眬绗竴娆＄粍鍚堬細鍘嬫殫灞忓箷 + 楂樹寒銆屾€昏銆嶏紝寮曞鐜╁鍘绘煡鐪?		if not _tot_hint_shown and LevelState.has_feature("draw") and not LevelState.has_feature("treasure"):
			_tot_hint_shown = true
			_l1_tutorial("l1_tot", _tot_btn, "鍚堟垚鍚庣殑鍗＄粍鍙互鍦ㄦ澶勬煡鐪?,
				func() -> void: _show_totals())
		else:
			_pulse_tot_btn())

# 鍗曞崱椋炲悜鎬昏锛堢偒鍗¤鍚炲櫖鏃剁敤锛?func _fly_card_to_totals(art_path: String) -> void:
	var tex: Texture2D = null
	if art_path != "" and ResourceLoader.exists(art_path):
		tex = load(art_path)
	var lay := Control.new()
	lay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.z_index = 150
	add_child(lay)
	_fly_to_totals(lay, tex, Vector2(360, 470))

func _pulse_tot_btn() -> void:
	if _tot_btn == null:
		return
	_tot_btn.pivot_offset = _tot_btn.size * 0.5
	var tw := create_tween()
	tw.tween_property(_tot_btn, "scale", Vector2(1.18, 1.18), 0.08)
	tw.tween_property(_tot_btn, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _activate_set(sid: String) -> void:
	var ids: Array = _set_cards[sid]
	if ids.is_empty(): return
	var first: Dictionary = _card_db[str(ids[0])]
	# 瀹朵紶鍗¤蛋鍙︿竴濂楃粨绠?	if first.has("ancestor"):
		_activate_ancestor_set(sid, first, ids)
		return
	var own_sum := {"atk": 0.0, "def": 0.0, "hp": 0.0, "mp": 0.0, "gold_pct": 0.0, "crystal_pct": 0.0,
		"count": 0.0, "coin_count": 0.0, "crystal_count": 0.0, "treasure_pct": 0.0, "boss_pct": 0.0,
		"wen_flat": 0.0, "crystal_flat": 0.0, "kill_pct": 0.0, "exp_pct": 0.0}
	var srcs: Array = []
	for cid_v in ids:
		var cid := str(cid_v)
		var c: Dictionary = _card_db[cid]
		srcs.append(str(c["name"]))
		var k := str(c["own_key"])
		if own_sum.has(k):
			own_sum[k] = float(own_sum[k]) + float(c["own_val"])
		_cards.erase(cid)
		_virtual_cards.erase(cid)          # 宸茶鍚炲櫖鐨勫壇鏈篃瑕佹竻锛屽惁鍒欒繖濂椾細姘歌繙"鍑戦綈"
	var rec := {"set_id": sid, "series": str(first["series"]), "tier": int(first["tier"]),
		"name": str(first["combo_name"]), "size": int(first["set_size"]),
		"quality": int(first["quality"]), "art": str(first["art"]),
		"own_text": _own_text(own_sum), "combo_text": str(first["combo_text"]),
		"trigger": str(first["trigger"]), "combo_key": str(first["combo_key"]),
		"combo_val": int(first["combo_val"]), "stacks": 0, "sources": srcs,
		"combo_extra_key": str(first.get("combo_extra_key", "")),
		"combo_extra_val": int(first.get("combo_extra_val", 0))}
	_combined.append(rec)
	_apply_own(own_sum)
	# v13锛氱兢/闄?鏄父椹诲瀷 鈥斺€?缁勫悎瀹屾垚鐨勭灛闂村氨鐢熸晥涓€娆★紙涓嶇瓑"姣忔尝"锛?	if str(first["combo_key"]) in ["count_flat", "coin_count", "crystal_count", "treasure_pct", "boss_pct", "devour_n", "killnum_pct"]:
		_apply_combo(rec)
	_toast_card(str(rec["name"]), int(rec["quality"]), "缁勫悎婵€娲伙紝" + str(rec["size"]) + " 寮犲凡娓呯┖")
	# 涓夊悎涓€琛ㄧ幇锛氫笁寮犲崱姹囪仛 鈫?鍚堟垚涓€寮?鈫?椋炶繘銆屾€昏銆?	_play_merge_fx(rec)
	# v8 鎴愰暱绯诲僵铔嬶細鍚堟垚 鏀诲嚮/闃插尽/姘旇/鍐呭姏 鏃?5% 鎺枫€屽洖娼€嶏紙涓€灞€涓€娆★級
	# v13 閲嶅埄锛氬悎鎴愮粡娴庣郴锛堟枃閽?鐏垫櫠锛夋椂 3% 鍏ユ睜
	if str(first["series"]) in ["gold", "crystal"] and not _zhongli_rolled and randf() < 0.03:
		_zhongli_rolled = true
		if not _pool.has("shiny_zhongli"):
			_pool.append("shiny_zhongli")
			_toast("褰╄泲锛併€岄噸鍒┿€嶅叆姹?)
			Aud.sfx("ult_ready", -4.0)
	var ser := str(first["series"])
	if ser in ["atk", "def", "hp", "mp"] and not _backwash_done and randf() < 0.05:
		_backwash_done = true
		if not _pool.has("shiny_backwash") and not _acquired.has("shiny_backwash"):
			_pool.append("shiny_backwash")
			_toast("褰╄泲锛併€屽洖娼€嶅叆姹?鈥斺€?鍒锋柊灏辫兘鐪嬪埌")
			Aud.sfx("ult_ready", -4.0)
	var parts := sid.split("_")
	if parts.size() == 2:
		var tier := int(parts[1])
		if tier < 3:
			var nid := str(parts[0]) + "_" + str(tier + 1)
			if _set_cards.has(nid):
				var entry := str((_set_cards[nid] as Array)[0])
				if not _acquired.has(entry) and not _pool.has(entry):
					_pool.append(entry)
					var ec: Dictionary = _card_db[entry]
					_toast_card(str(ec["name"]), int(ec["quality"]), "宸插姞鍏ュ崱姹?)
	_refresh_deck()
	_bond_check()
	if _combined_layer != null and _combined_layer.visible:
		_refresh_combined()

func _own_text(s: Dictionary) -> String:
	var arr: Array = []
	if float(s["atk"]) > 0: arr.append("鏀诲嚮 +" + str(int(s["atk"])))
	if float(s["def"]) > 0: arr.append("闃插尽 +" + str(int(s["def"])))
	if float(s["hp"]) > 0: arr.append("姘旇 +" + str(int(s["hp"])))
	if float(s.get("mp", 0.0)) > 0: arr.append("鍐呭姏 +" + str(int(s["mp"])))
	if float(s["gold_pct"]) > 0: arr.append("閲戝竵 +" + str(int(s["gold_pct"])) + "%")
	if float(s["crystal_pct"]) > 0: arr.append("鐏垫櫠 +" + str(int(s["crystal_pct"])) + "%")
	if float(s.get("count", 0.0)) > 0: arr.append("姣忔尝 +" + str(int(s["count"])) + " 鍙?)
	if float(s.get("coin_count", 0.0)) > 0: arr.append("鏂囬挶鎬?+" + str(int(s["coin_count"])))
	if float(s.get("crystal_count", 0.0)) > 0: arr.append("鐏垫櫠鎬?+" + str(int(s["crystal_count"])))
	if float(s.get("treasure_pct", 0.0)) > 0: arr.append("瀹濈墿 +" + str(int(s["treasure_pct"])) + "%")
	if float(s.get("boss_pct", 0.0)) > 0: arr.append("棣栭 +" + str(int(s["boss_pct"])) + "%")
	if float(s.get("wen_flat", 0.0)) > 0: arr.append("鏂囬挶 +" + str(int(s["wen_flat"])))
	if float(s.get("crystal_flat", 0.0)) > 0: arr.append("鐏垫櫠 +" + str(int(s["crystal_flat"])))
	if float(s.get("kill_pct", 0.0)) > 0: arr.append("鍑绘潃鏀剁泭 +" + str(int(s["kill_pct"])) + "%")
	if float(s.get("exp_pct", 0.0)) > 0: arr.append("鏉€鎬暟 +" + str(int(s["exp_pct"])) + "%")
	return " 路 ".join(PackedStringArray(arr))

func _apply_own(s: Dictionary) -> void:
	_stats["atk"] = float(_stats["atk"]) + float(s["atk"])
	# v6: def removed
	_stats["hp"] = float(_stats["hp"]) + float(s["hp"])
	if float(s.get("mp", 0.0)) > 0.0:
		if _core != null:
			_core.attr_add("mp", float(s["mp"]))
	_gold_pct += float(s["gold_pct"])
	_crystal_pct += float(s["crystal_pct"])
	# v13 缇?闄?	if float(s.get("count", 0.0)) > 0.0:
		_wave_extra += int(s["count"])
	if float(s.get("coin_count", 0.0)) > 0.0:
		_coin_count_extra += int(round(_peril_scale(float(s["coin_count"]))))
	if float(s.get("crystal_count", 0.0)) > 0.0:
		_crystal_count_extra += int(round(_peril_scale(float(s["crystal_count"]))))
	if float(s.get("treasure_pct", 0.0)) > 0.0:
		_treasure_pct += _peril_scale(float(s["treasure_pct"]))
	if float(s.get("boss_pct", 0.0)) > 0.0:
		_boss_pct += _peril_scale(float(s["boss_pct"]))
	if float(s.get("wen_flat", 0.0)) > 0.0:
		_add_wen(int(s["wen_flat"]))
	if float(s.get("crystal_flat", 0.0)) > 0.0:
		_gain_crystal(int(s["crystal_flat"]))
		_update_crystal()
	if float(s.get("kill_pct", 0.0)) > 0.0:
		_kill_pct += float(s["kill_pct"])
	if float(s.get("exp_pct", 0.0)) > 0.0:
		_killnum_pct += float(s["exp_pct"])
	_push_run_mods()
	if _core != null:
		# v6锛氭柊灞炴€у眰鏄粨绠楁簮锛涙棫 hero 瀛楁缁х画缁欐妧鑳?鍙敜鐗╄锛屼袱杈逛竴璧峰姞
		_apply_flat_growth(float(s["atk"]), float(s["hp"]))
		# v6锛氶槻寰″崱涓嶅啀鍔犮€屾暟鍊煎噺浼ゃ€嶏紝鏀规垚涓冪郴鍥哄畾鍑忓厤锛? 鐐归槻寰?= 3% 鍑忓厤锛岃窡鏃ф墜鎰熷榻愶級
		var def_red := float(s["def"]) * DEF_CARD_TO_RED
		if def_red > 0.0:
			for t in _core.DMG_TYPES:
				if t != "鐪熷疄":
					_core.type_add(t, "red_f", def_red)

# 閫夋嫨绫诲弽棣堬細鎶藉崱 / 杩涢樁 / 瀹濈墿 / 璇风 / 鍗囩骇 鍚勪竴鍙ｇ壒鏁堬紜涓€澹伴煶
# 棣栭鐧诲満锛氭殫绾㈢偢寮€ + 閲嶉渿 + 榧?func _on_boss_arrived(_tier: int) -> void:
	var p := Vector2(360, 250)
	var b: Dictionary = _core._boss_foe() if _core != null else {}
	if not b.is_empty():
		p = _core.position + Vector2(float(b["x"]), float(b["y"]) - 24.0)
	# 鍒硦鍒伴《閮?HUD 涓婏細鍘嬪洖鎴樺満鍐?	p.x = clampf(p.x, 90.0, 630.0)
	p.y = clampf(p.y, 210.0, 800.0)
	_spawn_pfx("shadow/dark-explosion", p, 1.7, "shadow", 1.9)
	_core._shake = maxf(float(_core._shake), 15.0)
	Aud.sfx("drum", -6.0, 0.85)
	Aud.sfx("tension", -14.0, 0.95)
	_boss_intro_show(p, str(b.get("name", "棣栭")) if not b.is_empty() else "棣栭")
	_cam_zoom_to(1.05, 0.75)     # 棣栭鎴橈細闀滃ご鎺ㄨ繎锛屽帇鍦?
# 棣栭鐧诲満婕斿嚭锛氭垬鍦哄帇鏆?鈫?鑱氬厜缃╀綇棣栭 鈫?鍚嶅瓧澶у瓧寮瑰叆
func _boss_intro_show(at: Vector2, nm: String) -> void:
	if _boss_veil == null or _boss_spot == null or _boss_name_lb == null:
		return
	_boss_veil.visible = true
	_boss_veil.color.a = 0.0
	var t1 := create_tween().bind_node(_boss_veil)
	t1.tween_property(_boss_veil, "color:a", 0.55, 0.22)
	t1.tween_interval(0.55)
	t1.tween_property(_boss_veil, "color:a", 0.0, 0.75)
	t1.tween_callback(func() -> void: _boss_veil.visible = false)
	_boss_spot.visible = true
	_boss_spot.position = at
	_boss_spot.scale = Vector2(0.35, 0.35)
	_boss_spot.modulate.a = 0.0
	var t2 := create_tween().bind_node(_boss_spot)
	t2.set_parallel(true)
	t2.tween_property(_boss_spot, "modulate:a", 1.0, 0.16)
	t2.tween_property(_boss_spot, "scale", Vector2(1.25, 1.25), 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t2.chain().tween_property(_boss_spot, "modulate:a", 0.0, 0.45)
	t2.chain().tween_callback(func() -> void: _boss_spot.visible = false)
	_boss_name_lb.text = nm
	_boss_name_lb.visible = true
	_boss_name_lb.pivot_offset = Vector2(360, 35)
	_boss_name_lb.scale = Vector2(1.5, 1.5)
	_boss_name_lb.modulate.a = 0.0
	var t3 := create_tween().bind_node(_boss_name_lb)
	t3.set_parallel(true)
	t3.tween_property(_boss_name_lb, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t3.tween_property(_boss_name_lb, "modulate:a", 1.0, 0.22)
	t3.chain().tween_interval(0.95)
	t3.chain().tween_property(_boss_name_lb, "modulate:a", 0.0, 0.45)
	t3.chain().tween_callback(func() -> void: _boss_name_lb.visible = false)

# Boss/澹眽寤惰繜鎶€鐮镐笅鏉ワ細鎸夊睘鎬х粰涓€鍙ｅ懡涓壒鏁?const LAND_FX := {
	"鐗╃悊": ["impacts/ground-slam", "metal", 0.90],
	"鐏郴": ["fire/fireball", "", 0.90],
	"閲戠郴": ["lightning/zap-hit", "volt", 0.95],
	"鏈ㄧ郴": ["nature/leaf-storm", "leaf", 0.85],
	"鐪熷疄": ["shadow/soul-drain", "", 0.80],
}

func _on_delayed_land(pos: Vector2, elem: String) -> void:
	var e: Array = LAND_FX.get(elem, ["impacts/crit-hit", "", 0.85])
	var wp: Vector2 = _core.position + pos
	_spawn_pfx(str(e[0]), wp, float(e[2]), str(e[1]), 1.30)

# 棣栭鍊掍笅锛氱櫧闂?+ 澶х垎 + 閲戣€€ + 閲嶉渿锛岄厤涓€娈靛緢鐭殑鎱㈤暅澶?# 绾镐汉 Lv5锛氬湪鏍稿績閭ｈ竟鎸′笅浜嗛棰嗗欢杩熸妧
func _on_paper_blocked(pos: Vector2) -> void:
	if _run_over or _core == null or _curio_id != "zhiren":
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	_set_paper_count(mini(_zhiren - 1, int(_core.hero.get("paper_guard", 0))))
	_curio_uses += 1
	_paper_shatter()
	if not _skill_batch_active(epoch):
		return
	_curio_flash()
	_toast("绾镐汉鏇胯韩 路 鎸′笅棣栭涓€鍑伙紙鍓?%d锛? % _zhiren)
	Aud.sfx("paper", -8.0, 1.0)
	if _core != null:
		_spawn_pfx("holy/heal", _core.position + pos, 1.0, "heal", 1.5)

func _on_boss_died(pos: Vector2) -> void:
	var wp: Vector2 = _core.position + pos
	wp.x = clampf(wp.x, 90.0, 630.0)
	wp.y = clampf(wp.y, 210.0, 800.0)
	_screen_flash(Color(1.0, 0.97, 0.88), 0.42, 0.55)
	_spawn_pfx("shadow/dark-explosion", wp, 1.9, "shadow", 1.8)
	_spawn_pfx("holy/sunburst", wp, 1.4, "gold", 1.9)
	_core._shake = maxf(float(_core._shake), 18.0)
	_core._hitstop = maxf(float(_core._hitstop), 0.22)
	Aud.sfx("hit_heavy", -2.0, 0.72)
	Aud.sfx("bell", -4.0, 0.9)
	Aud.sfx("levelup", -6.0, 0.95)
	_cam_zoom_to(1.0, 0.85)      # 棣栭鍊掍笅锛氶暅澶撮€€鍥?
func _choice_fx(kind: String) -> void:
	var hpos := _hero_screen()
	match kind:
		"draw":
			_spawn_pfx("arcane/spell-charge", hpos, 0.90, "arcane", 1.4)
			Aud.sfx("paper", -12.0, 1.05)
		"aug":
			_spawn_pfx("holy/halo", hpos, 0.95, "gold", 1.5)
			Aud.sfx("enlighten", -11.0, 1.02)
		"trea":
			_spawn_pfx("holy/halo", hpos, 1.05, "holy", 1.5)
			Aud.sfx("chest", -10.0, 1.05)
		"rare":
			_spawn_pfx("holy/sunburst", hpos, 1.10, "gold", 1.9)
			Aud.sfx("levelup", -8.0, 1.10)
			_core._shake = maxf(float(_core._shake), 6.0)
		"god":
			_spawn_pfx("holy/sunburst", hpos, 1.25, "holy", 2.1)
			Aud.sfx("enlighten", -7.0, 0.95)
			_core._shake = maxf(float(_core._shake), 8.0)
			_core._hitstop = maxf(float(_core._hitstop), 0.10)
		"lv":
			_spawn_pfx("holy/halo", hpos, 0.80, "heal", 1.2)

func _add_card(id: String) -> void:
	if _run_over:
		return
	if not _card_db.has(id) or _acquired.has(id): return
	if _cards.size() >= 10:
		_toast("鍗＄粍宸叉弧锛?0 鏍硷級")
		return
	_choice_fx("draw")
	_qc("draw", 1)
	if str(id) == "shiny_zhongli":
		_enable_zhongli()
	elif str(id) == "shiny_chenshi2":
		_enable_shiyun()
	elif str(id) == "shiny_zhiyuan":
		_enable_qianzhi()
	elif str(id) == "shiny_mingzhu":
		_enable_undying_lamp()
	elif str(id) in ["shiny_liuqingqing", "shiny_liuqingqing2"]:
		_enable_baicao()
	elif str(id) == "shiny_qingluan":
		_enable_wanren()
	elif str(id) == "shiny_gundilong":
		_enable_gunshan()
	elif str(id) == "shiny_zhujue":
		_enable_jianpo()
	elif str(id) == "shiny_backwash":
		_apply_own({"atk": 4.0, "def": 4.0, "hp": 40.0, "mp": 40.0, "gold_pct": 0.0, "crystal_pct": 0.0})
		_backwash()
	elif str(id) == "shiny_cuisanniang":
		_enable_swallow_sea()
	elif str(id) == "shiny_jicanghai":
		_enable_fentian()
	elif str(id).begins_with("shiny_"):
		_acquired[id] = true
		_draw_paid = false
		_show_draw(false)
		_do_devour(id)
		return
	var c: Dictionary = _card_db[id]
	_pool.erase(id)
	_cards.append(id)
	_acquired[id] = true
	if bool(c.get("entry", false)):
		for uid in c.get("unlock_ids", []):
			var us := str(uid)
			if _family_card_allowed(us) and not _acquired.has(us) and not _pool.has(us):
				_pool.append(us)
				var uc: Dictionary = _card_db[us]
				_toast_card(str(uc["name"]), int(uc["quality"]), "宸插姞鍏ュ崱姹?)
	_check_sets()
	_page = 0
	_refresh_deck()
	_toast_card(str(c["name"]), int(c["quality"]), "宸插叆鍗＄粍")
	_draw_paid = false
	_show_draw(false)

func _build_combined() -> void:
	_combined_layer = Control.new()
	_combined_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_combined_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_combined_layer.visible = false
	_combined_layer.z_index = 32
	add_child(_combined_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_show_combined(false))
	_combined_layer.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(32, 150)
	panel.size = Vector2(656, 900)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.91, 0.83, 0.99)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.70, 0.52, 0.22, 0.7)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_combined_layer.add_child(panel)
	_lbl("鎬?璁?, Vector2(60, 166), Vector2(260, 46), 34, INK, _combined_layer)
	_btn("脳", Rect2(624, 170, 44, 36), 22, Color(0.95, 0.91, 0.83), DIM, func(): _show_combined(false), _combined_layer)
	# 椤堕儴鍒嗙被閽細瀹濈墿 / 缁勫悎
	var tabs := [["bond", "瀹濈墿"], ["combo", "缁勫悎"]]
	_tot_tabs.clear()
	for i in tabs.size():
		var b := _btn(str(tabs[i][1]), Rect2(60.0 + float(i) * 140.0, 216, 128, 42), 20,
			Color(0.09, 0.08, 0.07, 0.98), LIGHT, _set_tot_tab.bind(str(tabs[i][0])), _combined_layer)
		_tot_tabs.append(b)
	# 涓や釜鍒嗛〉鐨勫唴瀹瑰尯锛堥兘鏄浘鏍囧锛氱偣鍥炬爣鎵嶇湅璇︽儏锛?	_tot_bond_root = Control.new()
	_tot_bond_root.position = Vector2(50, 280)
	_tot_bond_root.size = Vector2(620, 640)
	_tot_bond_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combined_layer.add_child(_tot_bond_root)
	_combined_icons = Control.new()
	_combined_icons.position = Vector2(50, 280)
	_combined_icons.size = Vector2(620, 640)
	_combined_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combined_layer.add_child(_combined_icons)
	_combined_detail = Control.new()
	_combined_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_combined_detail.visible = false
	_combined_layer.add_child(_combined_detail)
	_set_tot_tab("combo")

func _show_combined(v: bool) -> void:
	_combined_layer.visible = v
	if v:
		_combined_layer.move_to_front()
		_set_tot_tab(_tot_tab)

# 缁勫悎椤碉細宸插悎鎴愮殑缁勫悎 + 琚悶鍣殑鍗曞崱锛屽叏鏄浘鏍囷紝鐐瑰紑鐪嬭鎯?func _refresh_combined() -> void:
	for ch in _combined_icons.get_children(): ch.queue_free()
	_combined_detail.visible = false
	if _combined.is_empty() and _devoured.is_empty() and _ancestor_combos.is_empty():
		_lbl("杩樻病鏈夊凡婵€娲荤粍鍚?, Vector2(20, 20), Vector2(580, 40), 22, DIM, _combined_icons)
		return
	var k := 0
	for a_v in _ancestor_combos:
		var ar: Dictionary = a_v
		var ica := CombinedIcon.new()
		ica.position = Vector2(float(k % 5) * 120.0, float(k / 5) * 130.0)
		ica.size = Vector2(100, 100)
		ica.quality = int(ar.get("quality", 2))
		var ap2 := str(ar.get("art", ""))
		if ap2 != "" and ResourceLoader.exists(ap2):
			ica.art = load(ap2)
		ica.size_n = 3
		ica.mark = "浼?
		ica.pressed.connect(func() -> void:
			_show_ancestor_combo_detail(ar))
		_combined_icons.add_child(ica)
		k += 1
	for i in _combined.size():
		var rec: Dictionary = _combined[i]
		var ic := CombinedIcon.new()
		ic.position = Vector2(float(k % 5) * 120.0, float(k / 5) * 130.0)
		ic.size = Vector2(100, 100)
		ic.quality = int(rec["quality"])
		ic.art = load(str(rec["art"]))
		ic.size_n = int(rec["size"])
		ic.mark = "鍚?
		ic.pressed.connect(func() -> void: _show_combined_detail(rec))
		_combined_icons.add_child(ic)
		k += 1
	for d_v in _devoured:
		var d: Dictionary = d_v
		var ic2 := CombinedIcon.new()
		ic2.position = Vector2(float(k % 5) * 120.0, float(k / 5) * 130.0)
		ic2.size = Vector2(100, 100)
		ic2.quality = int(d.get("quality", 4))
		var ap := str(d.get("art", ""))
		if ap != "" and ResourceLoader.exists(ap):
			ic2.art = load(ap)
		ic2.size_n = 0
		ic2.mark = "鍚?
		ic2.pressed.connect(func() -> void: _show_devour_detail(d))
		_combined_icons.add_child(ic2)
		k += 1

# 鍚炲櫖鍗曞崱鐨勮鎯?func _show_devour_detail(d: Dictionary) -> void:
	for ch in _combined_detail.get_children():
		ch.queue_free()
	_combined_detail.visible = true
	var p := Panel.new()
	p.position = Vector2(140, 320)
	p.size = Vector2(440, 262)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.85, 0.99)
	sb.set_corner_radius_all(9)
	sb.border_color = QUALITY_COLORS[clampi(int(d.get("quality", 4)) - 1, 0, 4)]
	sb.set_border_width_all(7)
	p.add_theme_stylebox_override("panel", sb)
	_combined_detail.add_child(p)
	_lbl(str(d.get("name", "鐐崱")), Vector2(170, 340), Vector2(360, 40), 30, INK, _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl("鍚炪€€鍣?, Vector2(170, 382), Vector2(360, 26), 18, Color(0.64, 0.22, 0.15), _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl("鍚炰笅 %d 寮犲浼犲崱" % int(d.get("n", 0)), Vector2(170, 422), Vector2(380, 30), 21, INK, _combined_detail)
	_lbl("鐏垫櫠 +%d銆€鏂囬挶 +%d" % [int(d.get("crystal", 0)), int(d.get("wen", 0))], Vector2(170, 458), Vector2(380, 30), 19, INK, _combined_detail)
	_lbl("%s +%d%%" % [str(d.get("skill", "鎶€鑳?)), int(d.get("pct", 0))], Vector2(170, 494), Vector2(380, 30), 19,
		Color(0.46, 0.20, 0.10), _combined_detail)
	_btn("脳", Rect2(592, 322, 34, 30), 20, Color(0.97, 0.93, 0.85), DIM,
		func(): _combined_detail.visible = false, _combined_detail)

func _show_combined_detail(rec: Dictionary) -> void:
	for ch in _combined_detail.get_children(): ch.queue_free()
	_combined_detail.visible = true
	var p := Panel.new()
	p.position = Vector2(140, 300)
	p.size = Vector2(440, 420)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.85, 0.99)
	sb.set_corner_radius_all(9)
	sb.border_color = QUALITY_COLORS[clampi(int(rec["quality"]) - 1, 0, 4)]
	sb.set_border_width_all(7)
	p.add_theme_stylebox_override("panel", sb)
	_combined_detail.add_child(p)
	_lbl(str(rec["name"]), Vector2(170, 326), Vector2(360, 40), 30, INK, _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	var sz_cn: Array = ["涓?, "鍥?, "浜?, "鍏?]
	_lbl(str(sz_cn[clampi(int(rec["size"]) - 3, 0, 3)]) + "鍚堜竴", Vector2(420, 330), Vector2(100, 28), 18, Color(0.64,0.22,0.15), _combined_detail)
	_lbl("鍗￠潰鍚堣锛? + str(rec["own_text"]), Vector2(170, 390), Vector2(380, 32), 20, INK, _combined_detail)
	var bst := float(_combo_boost.get(str(rec["name"]), 0.0))
	var btail := "" if bst <= 0.0 else ("銆€缇佺粖 +%d%%" % int(round(bst * 100.0)))
	_lbl("缁勫悎锛? + str(rec["combo_text"]) + btail, Vector2(170, 430), Vector2(380, 32), 20, INK, _combined_detail)
	_lbl("瑙﹀彂锛? + str(rec["trigger"]) + "銆€宸插彔 " + str(int(rec["stacks"])), Vector2(170, 470), Vector2(380, 30), 18, DIM, _combined_detail)
	_lbl("婧愶細" + " 路 ".join(PackedStringArray(rec["sources"])), Vector2(170, 510), Vector2(380, 60), 17, Color(0.38,0.30,0.20), _combined_detail)
	_btn("脳", Rect2(592, 302, 34, 30), 20, Color(0.97,0.93,0.85), DIM, func(): _combined_detail.visible = false, _combined_detail)


# 瀹朵紶缁勫悎璇︽儏锛堢嫭绔嬩竴濂楀瓧娈碉紝涓嶅鐢ㄦ櫘閫氱粍鍚堢殑 rec锛?func _show_ancestor_combo_detail(ar: Dictionary) -> void:
	for ch in _combined_detail.get_children(): ch.queue_free()
	_combined_detail.visible = true
	var q := clampi(int(ar.get("quality", 2)), 1, 5)
	var p := Panel.new()
	p.position = Vector2(140, 320)
	p.size = Vector2(440, 360)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.85, 0.99)
	sb.set_corner_radius_all(9)
	sb.border_color = QUALITY_COLORS[q - 1]
	sb.set_border_width_all(7)
	p.add_theme_stylebox_override("panel", sb)
	_combined_detail.add_child(p)
	_lbl(str(ar.get("name", "瀹朵紶缁勫悎")), Vector2(170, 346), Vector2(360, 40), 30, INK, _combined_detail, HORIZONTAL_ALIGNMENT_CENTER)
	_lbl("瀹?浼?路 " + str(ar.get("tier", 1)) + " 妗?, Vector2(420, 350), Vector2(140, 28), 18, Color(0.64,0.22,0.15), _combined_detail)
	_lbl("鏁堟灉锛? + str(ar.get("text", "")), Vector2(170, 410), Vector2(380, 80), 20, INK, _combined_detail)
	_lbl("婧愶細" + " 路 ".join(PackedStringArray(ar.get("sources", []))), Vector2(170, 500), Vector2(380, 70), 17, Color(0.38,0.30,0.20), _combined_detail)
	_btn("脳", Rect2(592, 322, 34, 30), 20, Color(0.97,0.93,0.85), DIM, func(): _combined_detail.visible = false, _combined_detail)

class CombinedIcon extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	signal pressed
	var quality := 3
	var art: Texture2D = null
	var size_n := 3
	var mark := "鍚?
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96,0.93,0.86,0.98)
		sb.set_corner_radius_all(8)
		sb.border_color = QC[clampi(quality-1,0,4)]
		sb.set_border_width_all(5)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if art != null:
			draw_texture_rect(art, Rect2(8,8,size.x-16,size.y-16), false)
		draw_rect(Rect2(size.x-32,6,26,22), Color(0.64,0.22,0.15))
		draw_string(F, Vector2(size.x-30,23), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.98,0.92,0.78))
		if size_n > 0:
			draw_string(F, Vector2(size.x-34,size.y-8), str(size_n), HORIZONTAL_ALIGNMENT_RIGHT, 26, 16, Color(0.38,0.30,0.20))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

func _play_attack_fx(hero_attacks: bool) -> void:
	if _core == null or _fx_back == null or _hero_token == null:
		return
	var tgt: Dictionary = _core._hero_pending
	if not hero_attacks or tgt.is_empty():
		tgt = _core._nearest()
	if tgt.is_empty():
		return
	if hero_attacks:
		_hero_token.play_move()
		var to: Vector2 = _core.position + Vector2(float(tgt["x"]), float(tgt["y"]))
		_fx_back.spawn_swing(_hero_token.position - FIELD_POS, to - FIELD_POS, _hero_token.radius, true)
	else:
		var tk = _foe_tokens.get(int(tgt.get("_tid", 0)))
		if tk == null:
			return
		_fx_back.spawn_swing(tk.position - FIELD_POS, _hero_token.position - FIELD_POS, tk.radius, false, false, true)

func _spawn_hit_fx(global_pos: Vector2, radius: float, dmg: int, hero_hit: bool, crit: bool, heavy: bool) -> void:
	if _fx_front == null:
		return
	_fx_front.spawn_hit(global_pos - FIELD_POS, radius, dmg, hero_hit, crit or heavy, heavy)
	var impact := global_pos - Vector2(0, radius * 0.85)
	# 鍍忕礌鍛戒腑鐗规晥锛坧ixelfx锛孧IT锛夛細鏅€氬皬銆佹毚鍑婚噾浜€佹尐鎵撳亸琛€
	if hero_hit:
		_spawn_pfx("impacts/blunt-hit", impact, 0.70, "blood", 1.2)
	elif crit:
		_spawn_pfx("impacts/crit-hit", impact, 0.95, "gold", 1.9)
		# 鏆村嚮鍐嶅彔涓€鍙ｅ皬鐨勯敊浣嶉噾鐖嗭紙鍚屼竴涓凡鐑樺彉浣擄紝鍙敼缂╂斁/浣嶇疆锛?		_spawn_pfx("impacts/crit-hit", impact + Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 6.0)), 0.58, "gold", 1.9)
	elif heavy:
		_spawn_pfx("impacts/crit-hit", impact, 0.80, "", 1.4)
	elif randf() < (0.40 if _boss_on else 0.70):
		# 妯壂涓€娆℃墦濂藉嚑鍙椂锛屾櫘閫氬懡涓笉姣忓彧閮芥斁锛堜繚涓濇粦锛岃鎰熶篃澶燂級锛涢棰嗘垬鍐嶉檷涓€妗?		_spawn_pfx("impacts/hit-spark", impact, 0.72, "", 1.0)

class ComboReadout extends Control:
	var count := 0
	var _pulse := 0.0
	var _remaining := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
	func update_combo(value: int, remaining: float) -> void:
		_remaining = remaining
		visible = value >= 3 and remaining > 0.0
		if count != value:
			count = value
			_pulse = 1.0
			queue_redraw()
	func _process(dt: float) -> void:
		if not visible: return
		_pulse = maxf(0.0, _pulse - dt * 5.5)
		modulate.a = clampf(_remaining / 0.3, 0.0, 1.0)
		queue_redraw()
	func _draw() -> void:
		var pop := 1.0 + 0.12 * sin(_pulse * PI)
		draw_set_transform(size * 0.5 * (1.0 - pop), 0.0, Vector2.ONE * pop)
		draw_line(Vector2(10, 52), Vector2(148, 52), Color(0.66, 0.47, 0.19, 0.65), 1.5, true)
		draw_string(FONT, Vector2(10, 37), "杩炴柀", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(0.42, 0.30, 0.16))
		draw_string(FONT, Vector2(72, 39), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(0.58, 0.22, 0.10))

# 杞婚噺鍛戒腑鐏姳锛氱▼搴忓寲鏀惧皠绾匡紝涓嶉鐑樸€佷笉鐢?pixelfx锛?.18 绉掕嚜姣?class ImpactSpark extends Control:
	var col := Color.WHITE
	var life := 0.18
	var t := 0.0
	var dirs: Array = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 7
		var n := 6 + randi() % 3
		for i in n:
			var a := TAU * float(i) / float(n) + randf_range(-0.4, 0.4)
			dirs.append(Vector2(cos(a), sin(a)) * randf_range(0.8, 1.3))
		set_process(true)
	func _process(dt: float) -> void:
		t += dt
		if t >= life:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var k := 1.0 - t / life
		var c := Color(col.r, col.g, col.b, k)
		draw_circle(Vector2.ZERO, 6.0 * k, Color(col.r, col.g, col.b, k * 0.55))
		for d in dirs:
			var p0: Vector2 = d * 3.0
			var p1: Vector2 = d * (7.0 + 16.0 * (1.0 - k))
			draw_line(p0, p1, c, 2.2 * k + 0.6)

func _pfx_col(pal: String, effect: String) -> Color:
	match pal:
		"gold": return Color(1.0, 0.82, 0.30)
		"blood": return Color(0.82, 0.20, 0.16)
		"heal": return Color(0.42, 0.92, 0.52)
		"holy": return Color(1.0, 0.96, 0.62)
		"arcane": return Color(0.72, 0.52, 1.0)
		"fire": return Color(1.0, 0.52, 0.16)
		"poison": return Color(0.52, 0.84, 0.30)
		"volt": return Color(0.95, 0.90, 0.35)
		"leaf": return Color(0.45, 0.85, 0.35)
		"metal": return Color(0.92, 0.86, 0.70)
		"shadow": return Color(0.55, 0.20, 0.60)
		"dust": return Color(0.80, 0.74, 0.62)
	if effect.contains("shadow"):
		return Color(0.55, 0.20, 0.60)
	return Color(1.0, 0.95, 0.80)

func _spawn_pfx(effect: String, pos: Vector2, s := 1.0, pal := "", lig := 1.0, spd := 1.0, flip := false):
	if _cam == null:
		return null
	var sp := ImpactSpark.new()
	sp.position = pos
	sp.scale = Vector2(s, s) * (1.15 if lig > 1.7 else 1.0)
	sp.col = _pfx_col(pal, effect)
	sp.life = 0.16 / maxf(0.6, spd)
	_cam.add_child(sp)
	return sp

func _on_hero_attack() -> void:
	if _run_over or _core == null or not _core.running:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	_play_attack_fx(true)
	_attack_count += 1
	# 瀹朵紶杩藉姞鏀诲嚮鐢県ero_strike_resolved鍦ㄤ富鍒€鍛戒腑鍚庣粨绠楋紝璧锋墜浠呰鏀诲嚮浜嬩欢銆?	_curio_on_attack()                       # 濂囩墿锛氶摐閽卞墤锛堟櫘鏀婚檮甯﹂挶闀栵級
	if not _skill_batch_active(epoch):
		return
	_trigger_combos("姣忔鏀诲嚮")
	if _attack_count % 5 == 0:
		_trigger_combos("姣?5 娆℃敾鍑?)
	if _attack_count % 10 == 0:
		_trigger_combos("姣?10 娆℃敾鍑?)

func _on_hero_hit() -> void:
	_play_attack_fx(false)
	_hit_count += 1
	_trigger_combos("姣忔鍙楀嚮")
	_stone_on_hit()

func _on_hero_foe_hit(tgt: Dictionary, dmg: float, crit: bool, heavy: bool) -> void:
	if _core == null:
		return
	var epoch: int = _core._hero_hit_epoch if _core._hero_hit_epoch >= 0 else _core._enemy_attack_epoch
	if not _skill_batch_active(epoch) or not _core.foes.has(tgt):
		return
	_curio_mirror_hit(tgt, dmg)
	if not _skill_batch_active(epoch) or not _core.foes.has(tgt):
		return
	if crit:
		_curio_on_crit(tgt)                  # 濂囩墿锛氬瘨鐜夋壋鎸?/ 閱夌縼澹?	if _fx_front == null:
		return
	var tk = _foe_tokens.get(int(tgt.get("_tid", 0)))
	if tk == null:
		return
	_spawn_hit_fx(tk.position, tk.radius, int(round(dmg)), false, crit, heavy)
	tk.play_hit(tk.position - _hero_token.position, crit or heavy)

# ============================================================
# v3 璇风 + 鎶€鑳芥爮锛堢瀹楁妧鑳斤細鍚勮嚜 CD + 鍐呭姏锛?# ============================================================
const Aud := preload("res://shared/audio.gd")

const SKILL_DEFS := {
	"zl": {"name": "澶╅浄閬撴湳", "dtype": "閲戠郴", "mul": 1.6, "cd": 10.0, "mp": 260.0,
		"targets": 3, "col": Color(0.86, 0.78, 0.34)},
	"cuisanniang": {"name": "闆炬捣榫欑帇", "dtype": "鍙敜", "mul": 2.5, "cd": 60.0, "mp": 300.0,
		"targets": 1, "col": Color(0.38, 0.62, 0.82)},
	"jicanghai": {"name": "鎬掔伀鐒氳韩", "dtype": "鐏郴", "mul": 1.3, "cd": 9.0, "mp": 0.0,
		"targets": 3, "col": Color(0.88, 0.42, 0.22)},
	"chenshi": {"name": "鍒洪", "dtype": "鐪熷疄", "mul": 1.4, "cd": 8.0, "mp": 90.0,
		"targets": 1, "col": Color(0.86, 0.55, 0.62)},
	"liuqingqing": {"name": "鍥炴槬", "dtype": "鏈ㄧ郴", "mul": 1.0, "heal_mul": 2.0, "cd": 12.0, "mp": 80.0,
		"targets": 1, "col": Color(0.42, 0.72, 0.42)},
	"xiaoqier": {"name": "椤烘墜", "dtype": "鐗╃悊", "mul": 0.9, "cd": 5.0, "mp": 60.0,
		"targets": 1, "col": Color(0.90, 0.84, 0.66)},
	"gundilong": {"name": "鑲夎泲鍐叉挒", "dtype": "鐗╃悊", "mul": 1.5, "cd": 6.0, "mp": 80.0,
		"targets": 1, "col": Color(0.78, 0.68, 0.42)},
	"qingluan": {"name": "闈掗妇椋炲垉", "dtype": "鐗╃悊", "mul": 1.2, "cd": 8.0, "mp": 90.0,
		"targets": 1, "col": Color(0.55, 0.82, 0.90)},
	"liuqingqing2": {"name": "鍥炴槬", "dtype": "鏈ㄧ郴", "mul": 1.0, "cd": 12.0, "mp": 80.0,
		"targets": 1, "col": Color(0.45, 0.78, 0.42)},
	"zhiyuan": {"name": "鍓焊鎴愬叺", "dtype": "鍙敜", "mul": 1.0, "cd": 10.0, "mp": 90.0,
		"targets": 1, "col": Color(0.94, 0.92, 0.84)},
}

# 鎶€鑳藉浘鏍囷細鍚屼竴鎶€鑳界殑閲嶅鏉＄洰鍏辩敤涓€寮犲浘
const SKILL_ICON_ALIAS := {"liuqingqing2": "liuqingqing"}

# 姣忕骇浼ゅ鎴愰暱锛氶珮棰戞妧鑳藉皬銆佷綆棰?楂樺€嶇巼鎶€鑳藉ぇ锛涜绁為〉涓庢垬鏂楀叡鐢ㄥ悓涓€濂?const SKILL_LV_STEP := {
	"zl": 3, "cuisanniang": 5, "jicanghai": 3, "chenshi": 3, "liuqingqing": 3,
	"xiaoqier": 2, "gundilong": 2, "qingluan": 3, "zhujue": 2,
}

var _skills: Array = []
var _mp := 100.0
var _mp_max := 100.0
var _mp_bar: Panel = null
var _skill_slots: Array = []
var _god_layer: Control = null
var _god_root: Control = null
var _god_ban_lb: Label = null
var _god_refresh_btn: Button = null
var _god_reroll := 0            # 璇风鍒锋柊娆℃暟锛堟斁寮?+1锛屽埛鏂?-1锛?var _god_hand_charge := -1      # 璁颁綇杩欎竴鎵嬫槸鍑犳璇风鏃舵幏鐨勶紙闅愯棌鍐嶅紑涓嶉噸鎺凤級

# ---------------- 鎶€鑳芥爮 ----------------
func _build_skill_bar() -> void:
	for i in 6:
		var s := SkillSlot.new()
		s.position = Vector2(636, 242 + i * 62)
		s.size = Vector2(54, 54)
		s.visible = false
		s.z_index = 8
		add_child(s)
		_skill_slots.append(s)

var _curio_mana_regen_left := 0.0

func _roll_skill_free_cast() -> bool:
	return _curio_id == "dingfengzhu" and _curio_lv >= 5 and randf() < 0.15

func _skill_mana_cost(sk: Dictionary) -> float:
	var mods: Dictionary = _anc_mod.get(str(sk.get("aid", "")), {})
	return maxf(0.0, float(sk.get("mp", 0.0)) - float(mods.get("mp_flat", 0.0)))

func _tick_skills(dt: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	if _core != null and float(_core.hero.get("aspd", 1.0)) > MAX_ASPD:
		_core.hero["aspd"] = MAX_ASPD          # 纭《锛氶槻鏀婚€熷彔澶珮鍗″抚
	var lv_mul := float(_lv - 1)
	_mp_max = maxf(1.0, float(_core.attr_final("mp"))) if _core != null else 100.0
	var boosted_seconds := minf(maxf(0.0, dt), _curio_mana_regen_left)
	_curio_mana_regen_left = maxf(0.0, _curio_mana_regen_left - dt)
	_mp = minf(_mp_max, _mp + (20.0 + 2.0 * lv_mul) * (dt + boosted_seconds * 0.5))
	if _mp_bar != null:
		_mp_bar.size = Vector2(maxf(4.0, 235.0 * clampf(_mp / _mp_max, 0.0, 1.0)), 9.0)
	for i in _skills.size():
		if not _skill_batch_active(epoch):
			return
		var sk: Dictionary = _skills[i]
		if float(sk["cd_t"]) > 0.0:
			sk["cd_t"] = maxf(0.0, float(sk["cd_t"]) - dt)
		var free_cast := _roll_skill_free_cast()
		if float(sk["cd_t"]) <= 0.0 and (_mp >= _skill_mana_cost(sk) or free_cast):
			var cd_before := float(sk["cd_t"])
			var mp_before := _mp
			if free_cast:
				_mp = maxf(_mp_max, _skill_mana_cost(sk))
			_cast_skill(i)
			if free_cast:
				_mp = mp_before
			if not _skill_batch_active(epoch):
				return
			if float(sk["cd_t"]) > cd_before + 0.01:
				if _curio_id == "dingfengzhu" and _curio_lv >= 3:
					_curio_mana_regen_left = 2.0
				if i < _skill_slots.size():
					_skill_slots[i].flash = 1.0
				_skill_cast_juice()
	for i in _skill_slots.size():
		var s = _skill_slots[i]
		if i < _skills.size():
			var sk2: Dictionary = _skills[i]
			s.visible = true
			s.skill_name = str(sk2["name"])
			s.skill_icon = str(sk2.get("icon", ""))
			s.quality = int(sk2.get("quality", 4))
			s.cd_left = float(sk2["cd_t"])
			s.cd_max = maxf(0.01, float(sk2["cd"]))
			s.mp_cost = int(sk2["mp"])
			if s.flash > 0.0:
				s.flash = maxf(0.0, s.flash - dt * 2.2)
			s.queue_redraw()
		else:
			s.visible = false

	if _core != null:
		_core.hero["mp"] = _mp

# 璇风鎶€鑳界壒鏁堬細鎸夋妧鑳藉睘鎬ф寫鏁堟灉 + 鎹㈣壊锛坧ixelfx锛?const SKILL_FX := {
	"閲戠郴": ["lightning/zap-hit", "volt", 1.10],
	"鐏郴": ["fire/fireball", "", 1.00],
	"鏈ㄧ郴": ["nature/leaf-storm", "leaf", 0.95],
	"鍙敜": ["arcane/magic-circle-cast", "", 1.10],
	"鐗╃悊": ["impacts/ground-slam", "metal", 0.95],
	"鐪熷疄": ["shadow/soul-drain", "", 0.85],
}

# 鎶€鑳介煶鏁堬細鎸夊睘鎬ф寫涓€涓?鑷繁鐨勯煶鑹?锛堝彧鏀句竴娆★紝璺熺潃璧锋墜鐗规晥璧帮級
const SKILL_SFX := {
	"閲戠郴": [["slash_light2", -8.0, 1.15], ["bell", -13.0, 1.25]],
	"鐏郴": [["swing", -8.0, 0.88], ["drum", -9.0, 0.90]],
	"鏈ㄧ郴": [["wood_down", -8.0, 1.10], ["dart", -15.0, 1.20]],
	"鍙敜": [["enlighten", -8.0, 1.05], ["flute", -12.0, 1.12]],
	"鐗╃悊": [["sword_in_ground", -7.0, 1.00], ["hit_heavy", -10.0, 0.95]],
	"鐪熷疄": [["heartbeat", -10.0, 0.90], ["tension", -13.0, 1.00]],
}

func _skill_fx(dtype: String, world_pos: Vector2, big := false) -> void:
	var e: Array = SKILL_FX.get(dtype, [])
	if e.is_empty():
		return
	_spawn_pfx(str(e[0]), world_pos, float(e[2]) * (1.35 if big else 1.0), str(e[1]), 1.9, 1.0)
	if not big:
		var layers: Array = SKILL_SFX.get(dtype, [])
		for one in layers:
			if one.size() >= 3:
				Aud.sfx(str(one[0]), float(one[1]), float(one[2]))

func _hero_screen() -> Vector2:
	return _core.position + _core.hero_pos

func _skill_level_bonus(aid: String) -> float:
	return float(GameState.skill_lv.get(aid, 0)) * float(SKILL_LV_STEP.get(aid, 3))

func _skill_batch_active(epoch: int) -> bool:
	return not _run_over and _core != null and _core.running and epoch == _core._enemy_attack_epoch and float(_core.hero.get("hp", 0.0)) > 0.0

func _cast_skill(i: int) -> void:
	if i < 0 or i >= _skills.size():
		return
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	_cast_dtype = str(_skills[i].get("dtype", ""))
	var sk: Dictionary = _skills[i]
	var aid0 := str(sk["aid"])
	var md0: Dictionary = _anc_mod.get(aid0, {})
	var cost0 := maxf(0.0, float(sk["mp"]) - float(md0.get("mp_flat", 0.0)))
	if _mp < cost0:
		return
	# 鐭崇毊娴侊細绾鍔紙涓嶈繘鎶€鑳芥爮锛夛紝杩欓噷鍙负鍏滃簳
	if aid0 == "chenshi2":
		return
	# 鍙敜娴侊細鍓焊鎴愬叺
	if aid0 == "zhiyuan":
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_cast_paper()
		_skill_fx("鍙敜", _hero_screen())
		return
	# 娌荤枟娴侊細鍥炶 + 鐜瘨 + 鏄撲激
	if aid0 in ["liuqingqing", "liuqingqing2"]:
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		var times := 1
		if _baicao:
			times = _baicao_times()
		_skill_fx("鏈ㄧ郴", _hero_screen())
		for _i in times:
			if not _skill_batch_active(epoch): return
			_cast_heal(float(sk["mul"]), aid0)
		if times > 1:
			_toast("鐧捐崏 路 杩炴斁 %d 娆★紙鍙墸涓€娆″唴鍔涳級" % times)
		return
	# 绌块€忔祦锛氱洿绾跨┛閫?+ 鍥炵▼
	if aid0 == "qingluan":
		if _live_foes().is_empty():
			return
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_cast_feiren(float(sk["mul"]))
		if _skill_batch_active(epoch):
			_skill_fx("鐗╃悊", _hero_screen())
		return
	# 鎾炲嚮娴侊細鎸夋皵琛€涓婇檺绠椾激瀹筹紝骞舵妸鐩爣鎾為
	if aid0 == "gundilong":
		if _live_foes().is_empty():
			return
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_charge_ram()
		if _skill_batch_active(epoch):
			_skill_fx("鐗╃悊", _hero_screen(), true)
		return
	# 鐏郴锛氱洿浼?+ 鐏肩儳锛堝紩鐕冨鍚嶏級
	if aid0 == "jicanghai":
		if _live_foes().is_empty():
			return                                  # 绌哄満涓嶇┖鏀撅紝CD 涓庡唴鍔涢兘涓嶆墸
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_cast_fire()
		_skill_fx("鐏郴", _hero_screen())
		return
	# 鍙敜绯伙細涓嶇洿鎺ュ嚭浼わ紝鍙竴鏉¤洘榫欓《涓婂幓
	if aid0 == "cuisanniang":
		_mp -= cost0
		sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(float(md0.get("cd_pct", 0.0)), 0.0, 80.0) / 100.0))
		_summon_dragon(float(md0.get("dmg_pct", 0.0)) + float(_elem_mod.get("鍙敜", 0.0)) + _skill_level_bonus(aid0))
		_skill_fx("鍙敜", _hero_screen())
		return
	var foes: Array = []
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		foes.append(f)
	if foes.is_empty():
		return
	# v4锛氱粍鍚堝姞鎴愬湪杩欓噷鐢熸晥锛堝浼犲崱鎶戒簡鎵嶆湁鎰忎箟锛?	var aid := str(sk["aid"])
	var dtype := str(sk["dtype"])
	var m: Dictionary = _anc_mod.get(aid, {})
	var shared_pct := 0.0 if _core.DMG_TYPES.has(dtype) else float(_elem_mod.get(dtype, 0.0))
	var dmg_pct := float(m.get("dmg_pct", 0.0)) + shared_pct + _skill_level_bonus(aid)
	var cd_pct := float(m.get("cd_pct", 0.0))
	var mp_flat := float(m.get("mp_flat", 0.0))
	var para_s := float(m.get("para_s", 0.0))
	var para_amp := float(m.get("para_amp", 0.0))
	var cost := maxf(0.0, float(sk["mp"]) - mp_flat)
	if _mp < cost:
		return
	_mp -= cost
	sk["cd_t"] = maxf(0.5, float(sk["cd"]) * (1.0 - clampf(cd_pct, 0.0, 80.0) / 100.0))
	var hp0 := Vector2(_core.hero_pos)
	foes.sort_custom(func(a, b) -> bool:
		var da := (Vector2(float(a["x"]), float(a["y"])) - hp0).length()
		var db := (Vector2(float(b["x"]), float(b["y"])) - hp0).length()
		return da < db)
	var base := float(_core.hero.get("atk", 12.0)) * float(sk["mul"]) * (1.0 + dmg_pct / 100.0)
	var n := mini(int(sk["targets"]) + int(m.get("tgt_add", 0.0)), foes.size())
	for k in n:
		if not _skill_batch_active(epoch):
			return
		var f: Dictionary = foes[k]
		if not _core.foes.has(f) or float(f.get("hp", 0.0)) <= 0.0 or bool(f.get("_death_settled", false)) or float(f.get("dying", 0.0)) > 0.0:
			continue
		var extra := 1.0
		if para_amp > 0.0 and float(f.get("para", 0.0)) > 0.0:
			extra = 1.0 + para_amp / 100.0        # 楹荤椆鏈熼棿鍚冮澶栦激瀹?		_core._apply_dmg(f, base * extra, dtype)
		if para_s > 0.0 and float(f.get("hp", 0.0)) > 0.0:
			f["para"] = maxf(float(f.get("para", 0.0)), para_s)
		_core._push_float(float(f["x"]), float(f["y"]) - 46.0, str(sk["name"]), sk["col"], true)
		_skill_fx(dtype, _core.position + Vector2(float(f["x"]), float(f["y"]) - 26.0), true)
		if float(f.get("hp", 0.0)) <= 0.0:
			_core._kill_foe(f)
			if not _skill_batch_active(epoch):
				return
	Aud.sfx("skill", -10.0)

func _add_ancestor_effects(aid: String, eff: Dictionary) -> void:
	if eff.is_empty():
		return
	if not _anc_mod.has(aid):
		_anc_mod[aid] = {"dmg_pct": 0.0, "cd_pct": 0.0, "mp_flat": 0.0, "para_s": 0.0, "para_amp": 0.0,
			"life_flat": 0.0, "cap_add": 0.0, "wave_evo": 0.0, "tgt_add": 0.0,
			"ignite_add": 0.0, "burn_add": 0.0}
	var m: Dictionary = _anc_mod[aid]
	for k in ["dmg_pct", "cd_pct", "mp_flat", "para_s", "para_amp", "life_flat", "cap_add", "wave_evo", "tgt_add",
			"ignite_add", "burn_add", "chain_dmg", "radius_add", "stun_s", "impact",
			"pierce", "knife", "volley", "volley_pct", "heal_pct", "aura", "poison_dur", "vuln",
			"heal_aura", "pull", "minion_pct", "paper_add", "burst", "paper_life",
			"stone_rate", "stone_add", "stone_def", "stone_burst", "stone_cap", "shard_drop"]:
		if eff.has(k):
			m[k] = float(m.get(k, 0.0)) + float(eff[k])
	if eff.has("elem_pct"):
		# 涓冪闈㈡澘绫诲瀷鍦ㄧ粺涓€浼ゅ灞傜粨绠楋紱鍙敜缁х画娌跨幇鏈夌嫭绔嬭矾寰勩€?		var ep: Dictionary = eff["elem_pct"]
		for e in ep.keys():
			_elem_mod[e] = float(_elem_mod.get(e, 0.0)) + float(ep[e])
			if _core != null and _core.DMG_TYPES.has(str(e)):
				_core.type_add(str(e), "amp_f", float(ep[e]) / 100.0)
	if aid == "zhujue" and _core != null:
		_sync_basic_family_bonus()

# 鐐崱鍚炲櫖锛氬悶鎺夎绁栧畻鍏ㄩ儴瀹朵紶鍗★紙杩涘害涓庢晥鏋滀繚鐣欙級鈫?杩旇繕璧勬簮 + 姘镐箙鍔犱激 鈫?鑷韩绂诲満
func _do_devour(shiny_id: String) -> void:
	var c: Dictionary = _card_db.get(shiny_id, {})
	var aid := str(c.get("ancestor", ""))
	var nm := str(c.get("name", "鐐崱"))
	_shiny_used[aid] = true
	_pool.erase(shiny_id)
	var n := 0
	_devoured.append({"name": nm, "art": str(c.get("art", "")), "quality": int(c.get("quality", 4)),
		"n": 0, "skill": _label_skill(aid), "pct": 0, "crystal": 0, "wen": 0})
	var dev_rec: Dictionary = _devoured[_devoured.size() - 1]
	for cid in _cards.duplicate():
		var cc: Dictionary = _card_db.get(str(cid), {})
		if str(cc.get("ancestor", "")) == aid:
			_cards.erase(cid)
			n += 1
	_cards.erase(shiny_id)
	var wen := 150 * n
	var crystal := 20 * n
	dev_rec["n"] = n
	dev_rec["wen"] = wen
	dev_rec["crystal"] = crystal
	dev_rec["pct"] = 10 * n
	_wen += wen
	_gain_crystal(crystal)
	if _coin_lb != null:
		_coin_lb.text = str(_wen)
	_update_crystal()
	if not _anc_mod.has(aid):
		_anc_mod[aid] = {"dmg_pct": 0.0, "cd_pct": 0.0, "mp_flat": 0.0, "para_s": 0.0, "para_amp": 0.0,
			"life_flat": 0.0, "cap_add": 0.0, "wave_evo": 0.0, "tgt_add": 0.0,
			"ignite_add": 0.0, "burn_add": 0.0}
	_anc_mod[aid]["dmg_pct"] = float(_anc_mod[aid].get("dmg_pct", 0.0)) + 10.0 * n
	if aid == "zhujue": _sync_basic_family_bonus()
	_page = 0
	_refresh_deck()
	_fly_card_to_totals(str(c.get("art", "")))
	# ---- 琛ㄧ幇锛氱櫧闂?+ 闇囧睆 + 闊虫晥 ----
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.98, 0.90, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 60
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.85, 0.06)
	tw.tween_property(flash, "color:a", 0.0, 0.30)
	tw.tween_callback(func() -> void: flash.queue_free())
	if _core != null:
		_core.Shake_add(9.0)
	_shiny_present("devour")
	await get_tree().create_timer(0.12).timeout
	_toast("%s 鍚炰簡 %d 寮犲浼?路 鐏垫櫠 +%d 路 鏂囬挶 +%d 路 %s +%d%%" % [nm, n, crystal, wen, str(_label_skill(aid)), 10 * n])

func _label_skill(aid: String) -> String:
	var d: Dictionary = SKILL_DEFS.get(aid, {})
	return str(d.get("name", "鎶€鑳?))

# ---------------- 璇风涓夐€変竴 ----------------
func _build_god_pick() -> void:
	_god_layer = Control.new()
	_god_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_god_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE      # 绌虹櫧澶勬斁琛岀粰鎴樺満
	_god_layer.visible = false
	_god_layer.z_index = 40
	add_child(_god_layer)
	var ban := Panel.new()
	ban.position = Vector2(230, 162)
	ban.size = Vector2(260, 42)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.48, 0.14, 0.10, 0.97)
	bsb.set_corner_radius_all(4)
	bsb.border_color = Color(0.95, 0.76, 0.36, 0.9)
	bsb.set_border_width_all(2)
	ban.add_theme_stylebox_override("panel", bsb)
	_god_layer.add_child(ban)
	_breathe(ban)
	_god_ban_lb = _lbl("璇风", Vector2(0, 0), Vector2(260, 42), 20, Color(0.97, 0.90, 0.74), ban, HORIZONTAL_ALIGNMENT_CENTER)
	_btn("闅愯棌", Rect2(620, 162, 72, 32), 17, Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _hide_god_pick(), _god_layer)
	_god_root = Control.new()
	_god_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_god_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_god_layer.add_child(_god_root)
	_god_refresh_btn = _btn("鍒锋柊 路 0 娆?, Rect2(140, 620, 200, 54), 19,
		Color(0.09, 0.08, 0.07, 0.98), GOLD, func(): _on_god_refresh(), _god_layer)
	_btn("鏀惧純 +1 鍒锋柊", Rect2(360, 620, 200, 54), 19,
		Color(0.09, 0.08, 0.07, 0.98), Color(0.80, 0.62, 0.34), func(): _on_god_abandon(), _god_layer)

func _show_god_pick() -> void:
	if _run_over or _god_layer == null:
		return
	if _draw_charge <= 0:
		_toast("鍗囩骇鍚庡彲璇风")
		return
	if _draw_layer != null:
		_draw_layer.visible = false                    # 鎶藉崱椤靛紑鐫€涓€骞舵敹鎺?	# 鍚屼竴鎵嬪彧鎺蜂竴娆★細鐐癸蓟闅愯棌锛藉叧浜嗗啀鐐癸蓟璇风锛斤紝鐪嬪埌鐨勬槸鍚屼竴鎵嬶紙涓嶈兘鐧藉埛锛?	if _god_hand_charge != _draw_charge:
		_god_hand_charge = _draw_charge
		_roll_god()
	if _god_root.get_child_count() == 0:
		return
	if _god_ban_lb != null:
		_god_ban_lb.text = "璇风 路 鍓?%d 娆? % _draw_charge
	if _god_refresh_btn != null:
		_god_refresh_btn.text = "鍒锋柊 路 %d 娆? % maxi(0, _god_reroll)
		_god_refresh_btn.disabled = _god_reroll <= 0
	_god_layer.visible = true
	_layer_in(_god_layer)
	_god_layer.move_to_front()
	_pop_god_cards()

func _pop_god_cards() -> void:
	var i := 0
	for card in _god_root.get_children():
		MenuUI.Motion.pop(card, true, i * 0.055, card.get_meta("motion_rest_position", card.position), (i - 0.5) * 0.025)
		i += 1

# 鎺疯繖涓€鎵嬶紙浜岄€変竴锛?func _roll_god() -> void:
	for c in _god_root.get_children():
		_god_root.remove_child(c)          # 绔嬪埢鎽樻帀锛屽埆绛夊抚鏈紙鍚﹀垯鏂版棫鍗＄墖浼氬悓鏃跺瓨鍦級
		c.queue_free()
	var cands: Array = []
	var allowed := LevelState.god_ids()
	var unseen := allowed.duplicate()
	# 鍥哄畾椤哄簭锛氱涓€娆¤绁炵粰绗竴浣嶏紝绗簩娆＄粰绗簩浣嶏紝涓嶉殢鏈?	for aid_v in unseen:
		var aid := str(aid_v)
		if SEALED.has(aid):
			continue
		if not _ancestors.has(aid) and AncestorData.ANCESTORS.has(aid):
			cands.append(aid)
	if _god_ban_lb != null:
		_god_ban_lb.text = "璇风 路 鍓?%d 娆? % _draw_charge
	if cands.is_empty():
		_toast("鍙鐨勭瀹楅兘宸蹭笂韬紙楂樺搧绁栧畻闇€鎶藉彇锛屾殏鏈紑鏀撅級")
		_hide_god_pick()
		return
	var n := 1
	if LevelState.current_level >= 7:
		n = 2   # 鍚庣画鍏宠绁炴敼鎴愪簩閫変竴锛堜粛鎸夊浐瀹氶『搴忓彇鍓嶄袱浣嶆湭璇风殑锛?	n = mini(n, cands.size())
	var total_w := float(n) * 260.0 + float(maxi(0, n - 1)) * 40.0
	var x0 := (720.0 - total_w) * 0.5
	for i in n:
		var gc := GodCard.new()
		var aid := str(cands[i])
		var a: Dictionary = AncestorData.ANCESTORS[aid]
		gc.aid = aid
		gc.god_name = str(a["name"])
		gc.skill_name = str(a["skill"])
		gc.element = str(a.get("dtype", ""))
		gc.quality = int(a["quality"])
		gc.icon = load(str(a["art"]))
		gc.position = Vector2(x0 + float(i) * 300.0, 214)
		gc.size = Vector2(260, 390)
		gc.picked.connect(func() -> void: _on_god_card(gc))
		_god_root.add_child(gc)
	if _god_refresh_btn != null:
		_god_refresh_btn.text = "鍒锋柊 路 %d 娆? % maxi(0, _god_reroll)
		_god_refresh_btn.disabled = _god_reroll <= 0

# 鍒锋柊锛氭鏁板瀷锛堢敤涓€娆″皯涓€娆★級
func _on_god_refresh() -> void:
	if _run_over or _god_layer == null or not _god_layer.visible or _draw_charge <= 0:
		return
	if _god_reroll <= 0:
		_toast("鍒锋柊娆℃暟鐢ㄥ畬浜?)
		return
	if not _rr_free():
		_god_reroll -= 1
	_roll_god()
	Aud.sfx("ui_click", -10.0)
	_pop_god_cards()

# 鏀惧純锛氳繖涓€鎵嬩笉瑕佷簡锛屾崲 1 娆″埛鏂帮紙涓嬫璇风鑳界敤锛?func _on_god_abandon() -> void:
	if _run_over or _god_layer == null or not _god_layer.visible or _draw_charge <= 0:
		return
	_god_reroll += 1
	_hide_god_pick()
	_toast("鏀惧純璇风 路 鍒锋柊 +1锛堢幇鏈?%d 娆★級" % _god_reroll)
	Aud.sfx("ui_back", -10.0)

func _hide_god_pick() -> void:
	if _god_layer != null:
		_god_layer.visible = false

func _on_god_card(card: GodCard) -> void:
	if _run_over or _god_layer == null or not _god_layer.visible or not is_instance_valid(card) or card.get_parent() != _god_root:
		return
	_pick_god(card.aid)

func _pick_god(aid: String) -> void:
	if _run_over or _ancestors.has(aid) or not AncestorData.ANCESTORS.has(aid):
		return
	if _draw_charge <= 0:
		return
	_god_hand_charge = -1   # 閫夊畬鍚庢棫鎵嬬墝浣滃簾锛屽嵆浣垮崌绾у張琛ュ洖鐩稿悓娆℃暟涔熷繀椤婚噸鎺?	_choice_fx("god")
	_draw_charge -= 1
	_qc("god", 1)
	_grant_ancestor(aid)
	var def: Dictionary = SKILL_DEFS.get(aid, {})
	if not def.is_empty() and not _has_skill(aid):
		var sk: Dictionary = def.duplicate()
		sk["cd"] = float(sk["cd"]) * _curio_skill_cd_mul()   # 濂囩墿路瀹氶鐝?		sk["aid"] = aid
		sk["cd_t"] = 0.0
		sk["quality"] = int((AncestorData.ANCESTORS[aid] as Dictionary)["quality"])
		var icon_key := str(SKILL_ICON_ALIAS.get(aid, aid))
		var icon_path := "res://assets/gen/icons/skill_%s.png" % icon_key
		sk["icon"] = icon_path if ResourceLoader.exists(icon_path) else ""
		_skills.append(sk)
	_hide_god_pick()
	_refresh_level_ui()
	_toast("璇峰埌 %s 路 鎶€鑳借繘鏍忥紝瀹朵紶鍏ュ彛鍗¤繘姹? % str((AncestorData.ANCESTORS[aid] as Dictionary)["name"]))
	Aud.sfx("levelup", -6.0)

func _has_skill(aid: String) -> bool:
	for sk in _skills:
		if str(sk["aid"]) == aid:
			return true
	return false

# ---------------- 鎶€鑳芥牸 ----------------
class SkillSlot extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	var skill_name := ""
	var skill_icon := ""
	var quality := 4
	var cd_left := 0.0
	var cd_max := 1.0
	var mp_cost := 0
	var flash := 0.0          # 鍒氭斁瀹屾妧鑳斤細涓€鍦堥噾鑹叉墿鏁?	var _tex: Texture2D = null
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var qc: Color = QC[clampi(quality - 1, 0, 4)]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.93, 0.86, 0.98)
		sb.set_corner_radius_all(9)
		sb.border_color = qc
		sb.set_border_width_all(3)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c := size * 0.5
		if skill_icon != "":
			if _tex == null:
				_tex = load(skill_icon) as Texture2D
			if _tex != null:
				var inset := size * 0.10
				draw_texture_rect(_tex, Rect2(inset, size - inset * 2.0), false)
		if _tex == null:
			var ch := "鎶€"
			if skill_name.length() > 0:
				ch = skill_name.substr(1 if skill_name.length() > 1 else 0, 1)
			draw_string(F, Vector2(0, c.y + 8), ch, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(0.20, 0.16, 0.11))
		if flash > 0.0:
			var k := 1.0 - flash
			var rr := size.x * (0.5 + 0.45 * k)
			draw_arc(c, rr, 0.0, TAU, 32, Color(0.98, 0.82, 0.36, flash * 0.9), 3.0)
			draw_circle(c, size.x * (0.55 + 0.25 * k), Color(0.98, 0.82, 0.36, flash * 0.16))
		if cd_left > 0.0:
			draw_circle(c, size.x * 0.5 - 2.0, Color(0.05, 0.04, 0.03, 0.58))
			draw_string(F, Vector2(0, c.y + 8), str(int(ceil(cd_left))),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(0.97, 0.92, 0.80))
		if mp_cost > 0:
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = Color(0.28, 0.48, 0.68, 0.92)
			sb2.set_corner_radius_all(3)
			draw_style_box(sb2, Rect2(Vector2(size.x - 24, 1), Vector2(23, 14)))
			draw_string(F, Vector2(size.x - 24, 12), str(mp_cost),
				HORIZONTAL_ALIGNMENT_CENTER, 23, 10, Color(0.95, 0.98, 1.0))

# ---------------- 璇风鍗?----------------
class GodCard extends Control:
	const F := preload("res://fonts/ink.ttf")
	const QC := [Color(0.54,0.48,0.38), Color(0.31,0.48,0.29), Color(0.18,0.42,0.45), Color(0.42,0.29,0.48), Color(0.72,0.53,0.16)]
	const CF := preload("res://kushou/card_frame.gd")
	signal picked
	var aid := ""
	var god_name := ""
	var skill_name := ""
	var element := ""
	var quality := 5
	var icon: Texture2D = null
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		# 鍏ㄩ儴鎸夊崱鐗囧昂瀵告瘮渚嬬敾 鈥斺€?鍗″澶у瓧灏卞澶э紙璇风鏀规垚浜岄€変竴鍚庡崱鏀惧ぇ鍒?260脳390锛?		var qc: Color = QC[clampi(quality - 1, 0, 4)]
		var w := size.x
		var h := size.y
		if not CF.draw_on(self, quality, size):
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.965, 0.945, 0.90, 1.0)
			sb.set_corner_radius_all(int(11.0 * w / 260.0))
			sb.border_color = qc
			sb.set_border_width_all(int(7.0 * w / 260.0))
			draw_style_box(sb, Rect2(Vector2.ZERO, size))
		else:
			CF.content_panel(self, Rect2(0.07 * w, 0.06 * h, 0.86 * w, 0.88 * h))
		draw_string(F, Vector2(0, h * 0.108), god_name, HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.130), Color(0.14, 0.11, 0.08))
		var side := w * 0.56
		var pr := Rect2(Vector2((w - side) * 0.5, h * 0.145), Vector2(side, side))
		draw_rect(pr, Color(0.88, 0.85, 0.78))
		if icon != null:
			var ts := icon.get_size()
			var asp: float = pr.size.x / pr.size.y
			var iw: float = ts.x
			var ih: float = iw / asp
			if ih > ts.y:
				ih = ts.y
				iw = ih * asp
			draw_texture_rect_region(icon, pr, Rect2((ts.x - iw) * 0.5, (ts.y - ih) * 0.5, iw, ih))
		draw_rect(pr, Color(0.35, 0.30, 0.24, 0.30), false, 2.0)
		draw_string(F, Vector2(0, h * 0.725), skill_name, HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.100), Color(0.20, 0.15, 0.10))
		draw_line(Vector2(w * 0.08, h * 0.768), Vector2(w * 0.92, h * 0.768), Color(0.5, 0.4, 0.25, 0.35), 1.6)
		draw_string(F, Vector2(0, h * 0.845), element, HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.082), Color(0.42, 0.30, 0.12))
		draw_string(F, Vector2(0, h * 0.945), "鐐?鍑?璇?绁?, HORIZONTAL_ALIGNMENT_CENTER, w, int(w * 0.076), Color(0.66, 0.22, 0.15))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()

# ---------------- 鍙敜鐗╋細铔熼緳 ----------------
func _summon_dragon(bonus_pct: float) -> void:
	var m: Dictionary = _anc_mod.get("cuisanniang", {})
	var cap := 1 + int(m.get("cap_add", 0.0))
	var dragon_count := _curio_count_minions("")
	if dragon_count >= cap:
		return
	var hero_atk := float(_core.hero.get("atk", 12.0))
	var life := 30.0 + float(m.get("life_flat", 0.0))
	var idx := dragon_count
	var pos := Vector2(360.0 - 80.0 + float(idx) * 160.0, 726.0)
	var tk = TokenActor.new()
	tk.setup(null, 20.0, Color(0.30, 0.62, 0.80), false)
	tk.show_bar = true
	tk.bar_w = 44.0
	tk.unit_name = "铔熼緳"
	tk.z_index = 5
	tk.position = _core.position + pos
	add_child(tk)
	var mul := 1.0 + bonus_pct / 100.0
	if _swallow_sea:
		life = 999999.0
	var ss := 1.0 + _ss_pct / 100.0
	var bd := hero_atk * 0.8 * mul
	_minions.append({"pos": pos, "life": life, "max_life": life,
		"atk_cd": 0.6, "wave_cd": 20.0,
		"base_dmg": bd, "base_wave": hero_atk * 2.5 * mul,
		"dmg": bd * ss, "wave_dmg": hero_atk * 2.5 * mul * ss, "tk": tk})
	_toast("铔熼緳鐜颁笘 路 瀛樺湪 %d 绉? % int(life))
	Aud.sfx("warcry", -8.0)

var _minions_ticking := false

func _tick_minions(dt: float) -> void:
	if _minions_ticking:
		return
	_minions_ticking = true
	_step_minions(dt)
	_minions_ticking = false

func _step_minions(dt: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	if _swallow_sea:
		_ss_pct += 0.4 * dt                    # 姣忕 +0.4% 铔熼緳灞炴€?	if _minions.is_empty():
		return
	for m_v in _minions.duplicate():
		if not _skill_batch_active(epoch):
			return
		var m: Dictionary = m_v
		if not _minions.has(m):
			continue
		m["life"] = float(m["life"]) - dt
		var tk = m["tk"]
		if _swallow_sea and m.has("base_dmg"):
			m["life"] = float(m["max_life"])
			var ss2 := 1.0 + _ss_pct / 100.0
			m["dmg"] = float(m["base_dmg"]) * ss2
			m["wave_dmg"] = float(m["base_wave"]) * ss2
		if float(m["life"]) <= 0.0:
			_minions.erase(m) # 鍏堥€€鍦猴紝鍑绘潃鍥炶皟涓嶈兘鍐嶆瑙﹀彂鍚屼竴鍙殑鍒版湡鏁堟灉銆?			if m.has("decoy"):
				m["decoy"]["active"] = false
			if tk != null and is_instance_valid(tk):
				tk.play_down()
			# 濂囩墿路鎷涢瓊骞?Lv5锛氶褰辨秷澶辨椂鑷垎
			if float(m.get("boom", 0.0)) > 0.0 and _core != null:
				var at_e: Vector2 = m["pos"]
				for f_v2 in _core.foes.duplicate():
					if not _skill_batch_active(epoch):
						return
					var f2: Dictionary = f_v2
					if not _core.foes.has(f2) or float(f2.get("hp", 0.0)) <= 0.0 or bool(f2.get("_death_settled", false)) or float(f2.get("dying", 0.0)) > 0.0:
						continue
					if at_e.distance_to(Vector2(float(f2["x"]), float(f2["y"]))) > 90.0:
						continue
					_core._apply_dmg(f2, float(_core.hero.get("atk", 12.0)) * float(m["boom"]), "鍙敜")
					if float(f2.get("hp", 0.0)) <= 0.0:
						_core._kill_foe(f2)
					if not _skill_batch_active(epoch):
						return
				if _core != null:
					_spawn_pfx("impacts/crit-hit", _core.position + at_e, 0.9, "", 1.4)
			continue
		if str(m.get("curio", "")) == "tongjing":
			m["pos"] = _core.hero_pos + Vector2(-60.0, 20.0)
			if m.has("decoy"):
				m["decoy"]["pos"] = m["pos"]
			if tk != null and is_instance_valid(tk):
				tk.position = _core.position + Vector2(m["pos"])
				tk.hp_ratio = float(m["life"]) / float(m["max_life"])
				tk.queue_redraw()
			continue # 闀滃儚澶嶅埗鐪熷疄鏅敾锛屼笉鍐嶇嫭绔嬫寜鍥哄畾CD鍑烘墜銆?		var mp0: Vector2 = m["pos"]
		var ghost := str(m.get("curio", "")) == "zhaohunfan"
		var best: Dictionary = {}
		var bd := 1e9
		for f_v in _core.foes:
			var f: Dictionary = f_v
			if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
				continue
			if ghost and _core.hero_pos.distance_to(Vector2(float(f["x"]), float(f["y"]))) > 220.0:
				continue # 楝煎奖鍙敮鎻翠富瑙掗檮杩戠洰鏍囷紝涓嶈拷鍑鸿窡闅忚寖鍥淬€?			var d := (Vector2(float(f["x"]), float(f["y"])) - mp0).length()
			if d < bd:
				bd = d
				best = f
		if not best.is_empty():
			var tgt := Vector2(float(best["x"]), float(best["y"]))
			var dv := tgt - mp0
			if dv.length() > 48.0:
				m["pos"] = mp0 + dv.normalized() * minf(150.0 * dt, dv.length() - 48.0)
			else:
				m["atk_cd"] = float(m["atk_cd"]) - dt
				if float(m["atk_cd"]) <= 0.0:
					m["atk_cd"] = 1.1
					var md: float = _core._apply_dmg(best, float(m["dmg"]), "鍙敜")
					if float(best.get("hp", 0.0)) <= 0.0:
						_core._kill_foe(best)
					if not _skill_batch_active(epoch):
						return
					if not _minions.has(m):
						continue
					# 濂囩墿路閾滈暅 Lv3锛氶暅褰辨敾鍑诲惛琛€
					if float(m.get("lc", 0.0)) > 0.0 and md > 0.0 and _core != null:
						_core.heal_hero(md * float(m["lc"]))
			m["wave_cd"] = float(m["wave_cd"]) - dt
			if float(m["wave_cd"]) <= 0.0:
				m["wave_cd"] = 20.0
				_dragon_wave(m, best)
				if not _skill_batch_active(epoch):
					return
		elif ghost:
			var anchor: Vector2 = _core.hero_pos + Vector2(m.get("follow_offset", Vector2(-60.0, 20.0)))
			var back := anchor - mp0
			m["pos"] = mp0 + back.normalized() * minf(150.0 * dt, back.length())
		if tk != null and is_instance_valid(tk):
			tk.position = _core.position + Vector2(m["pos"])
			tk.hp_ratio = float(m["life"]) / maxf(1.0, float(m["max_life"]))
			tk.queue_redraw()

# 澶ф氮鎷嶅嚮锛氬崟浣擄紱鍏。銆屾€掓稕銆嶈繘鍖栨垚涓€鍦?+ 鍑忛€?func _dragon_wave(m: Dictionary, target: Dictionary) -> void:
	var wm: Dictionary = _anc_mod.get("cuisanniang", {})
	var evo := float(wm.get("wave_evo", 0.0)) > 0.0
	var at := Vector2(float(target["x"]), float(target["y"]))
	for f_v in _core.foes.duplicate():
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		var d := (Vector2(float(f["x"]), float(f["y"])) - at).length()
		if f != target and not (evo and d <= 130.0):
			continue
		_core._apply_dmg(f, float(m["wave_dmg"]), "鍙敜")
		if evo:
			f["slow_t"] = 2.0
		_core._push_float(float(f["x"]), float(f["y"]) - 40.0, "澶ф氮", Color(0.38, 0.62, 0.82), true)
	Aud.sfx("hit_heavy", -10.0)

# ---------------- 鍚炴捣锛堝磾涓夊鐐崱锛?----------------
func _enable_swallow_sea() -> void:
	_swallow_sea = true
	_ss_pct = 10.0          # 鍗曞崱鏁板€硷細铔熼緳灞炴€?+10%
	_ss_kills = 0
	for m_v in _minions:
		var m: Dictionary = m_v
		if str(m.get("curio", "")) != "":
			continue
		m["max_life"] = 999999.0
		m["life"] = 999999.0
	_toast("鍚炴捣鍏ュ崱缁?路 铔熼緳姘镐箙瀛樺湪锛屾瘡绉?+0.4%銆佹瘡 10 鏉€ +4% 灞炴€?)
	_shiny_present("swallow_sea")

# ---------------- 鐏肩儳 / 寮曠噧 / 鐒氬ぉ ----------------
func _live_foes() -> Array:
	var out: Array = []
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		out.append(f)
	var hp0 := Vector2(_core.hero_pos)
	out.sort_custom(func(a, b) -> bool:
		var da := (Vector2(float(a["x"]), float(a["y"])) - hp0).length()
		var db := (Vector2(float(b["x"]), float(b["y"])) - hp0).length()
		return da < db)
	return out

const BATTLE_EFFECT_TICKS := [&"_tick_chal", &"_q_tick", &"_tick_minions", &"_tick_burn", &"_tick_poison", &"_tick_vuln", &"_tick_aura", &"_tick_stone", &"_tick_paper", &"_tick_shards", &"_tick_knock"]

func _tick_battle_effects(dt: float) -> bool:
	if _core == null:
		return false
	var epoch: int = _core._enemy_attack_epoch
	for tick in BATTLE_EFFECT_TICKS:
		if not _skill_batch_active(epoch):
			return false
		call(tick, dt)
	return _skill_batch_active(epoch)

func _apply_burn(f: Dictionary, stacks: float, dur: float) -> void:
	if _core == null or stacks <= 0.0 or dur <= 0.0:
		return
	if not _skill_batch_active(_core._enemy_attack_epoch) or not _core.foes.has(f) or float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0 or bool(f.get("_death_settled", false)):
		return
	if float(f.get("burn", 0.0)) <= 0.0:
		f["burn_acc"] = 0.0
	f["burn"] = float(f.get("burn", 0.0)) + stacks
	f["burn_t"] = maxf(float(f.get("burn_t", 0.0)), dur)

func _burn_dps() -> float:
	return float(_core.hero.get("atk", 12.0)) * 0.12

func _tick_burn(dt: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch) or dt <= 0.0:
		return
	for f_v in _core.foes.duplicate():
		if not _skill_batch_active(epoch):
			return
		var f: Dictionary = f_v
		if not _core.foes.has(f) or float(f.get("burn", 0.0)) <= 0.0 or float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0 or bool(f.get("_death_settled", false)):
			continue
		var remaining := dt
		var elapsed := 0.0
		while remaining > 0.0 and float(f.get("burn", 0.0)) > 0.0:
			var life := remaining if _burn_unlimited else maxf(0.0, float(f.get("burn_t", 4.0)))
			var step := minf(remaining, life)
			remaining -= step
			elapsed += step
			if not _burn_unlimited:
				f["burn_t"] = life - step
			f["burn_acc"] = float(f.get("burn_acc", 0.0)) + step
			while float(f["burn_acc"]) + 0.000000001 >= 1.0:
				f["burn_acc"] = maxf(0.0, float(f["burn_acc"]) - 1.0)
				var at_t := elapsed - float(f["burn_acc"])
				var vuln := 1.0 + float(f.get("vuln_pct", 0.0)) / 100.0 if float(f.get("vuln_t", 0.0)) > at_t else 1.0
				_core._apply_dmg(f, _burn_dps() * float(f["burn"]), "鐏郴", -1, vuln)
				_core._push_float(float(f["x"]), float(f["y"]) - 30.0, "鐑?, Color(0.88, 0.45, 0.20))
				if randf() < 0.6:
					_spawn_pfx("impacts/hit-spark", _core.position + Vector2(float(f["x"]), float(f["y"]) - 18.0), 0.55, "fire", 1.2)
				if float(f.get("hp", 0.0)) <= 0.0:
					_core._kill_foe(f)
				if not _skill_batch_active(epoch):
					return
				if float(f.get("hp", 0.0)) <= 0.0 or not _core.foes.has(f):
					break
			if float(f.get("hp", 0.0)) <= 0.0 or not _core.foes.has(f):
				break
			if not _burn_unlimited and float(f["burn_t"]) <= 0.000000001:
				f["burn"] = maxf(0.0, float(f["burn"]) - 1.0)
				f["burn_t"] = 4.0
		if float(f.get("burn", 0.0)) <= 0.0:
			f.erase("burn")
			f.erase("burn_t")
			f.erase("burn_acc")

func _cast_fire() -> void:
	var m: Dictionary = _anc_mod.get("jicanghai", {})
	var dmg_pct := float(m.get("dmg_pct", 0.0)) + _skill_level_bonus("jicanghai")
	var ign := 1 + int(m.get("ignite_add", 0.0)) + _ignite_bonus
	var stacks := 1.0 + float(m.get("burn_add", 0.0))
	var foes := _live_foes()
	if foes.is_empty():
		return
	var n := mini(ign, foes.size())
	for k in n:
		var f: Dictionary = foes[k]
		_core._apply_dmg(f, float(_core.hero.get("atk", 12.0)) * 0.6 * (1.0 + dmg_pct / 100.0), "鐏郴")
		_apply_burn(f, stacks, 4.0)
		_core._push_float(float(f["x"]), float(f["y"]) - 46.0, "寮曠噧", Color(0.88, 0.45, 0.20), true)
	Aud.sfx("skill", -10.0)

# 鐒氬ぉ锛堝娌ф捣鐐崱锛夛細鐏肩儳涓嶈“鍑?+ 姣?15 鏉€鍚炰竴寮犲崱 + 姣忓悶涓€寮犲紩鐕?+1
func _enable_fentian() -> void:
	_fentian = true
	_burn_unlimited = true
	_ft_kills = 0
	_toast("鐒氬ぉ鍏ュ崱缁?路 鐏肩儳鏃犱笂闄愶紝姣?15 鏉€鍚炰竴寮犲崱銆佸紩鐕?+1")
	_shiny_present("fentian")

func _devour_random() -> void:
	if _cards.is_empty():
		return
	var pick := str(_cards[randi() % _cards.size()])
	_cards.erase(pick)
	_ignite_bonus += 1
	_refresh_deck()
	var nm := str((_card_db.get(pick, {}) as Dictionary).get("name", "涓€寮犲崱"))
	_toast("鐒氬ぉ鍚炲櫖銆?s銆嵚?寮曠噧鐩爣 +1锛堝叡 %d锛? % [nm, 1 + _ignite_bonus])
	Aud.sfx("coin", -8.0)
	Aud.sfx("hit_heavy", -14.0)

# ---------------- 鍥炴疆锛堟垚闀跨郴褰╄泲锛?----------------
#   鍚堟垚 鏀诲嚮/闃插尽/姘旇/鍐呭姏 浠绘剰涓€濂楁椂 5% 鎺凤紱涓€灞€涓€娆?#   杩涘崱缁勶細鍥涚淮绔嬪埢 +4/+4/+40/+40锛屾尝鏁板洖閫€ 5 娉紙褰撳墠娉㈡竻绌洪噸鍒凤級
func _backwash() -> void:
	if _core == null or not _skill_batch_active(_core._enemy_attack_epoch):
		return
	var w := int(_core.wave)
	var nw := maxi(1, w - 5)
	# 鍥炲埌鏅€氭尝鏃朵笉鑳芥部鐢ㄦ湯娉㈢殑棣栭闂ㄦ锛屼篃涓嶈兘璁╂棫鍦轰笂鐨勬敾鍑昏拷鍒伴噸鍒锋尝銆?	if not _q_cur.is_empty() and str(_q_cur.get("kind", "")) in ["statue", "zone", "guard", "champion", "elite"]:
		_q_finish("fail")
	_core.foes.clear()
	_core.clear_enemy_attacks()
	_core._hero_pending = {}
	_core._hero_pending_t = -1.0
	_core.boss_required = false
	_core.boss_spawned_once = false
	_core.boss_alive = false
	_boss_spawned = false
	_chal_all_cd()
	_core.set_wave(nw)
	_core.wave_reset_quota()
	_spawn_typed_foes()
	_last_wave = nw
	_run_cleared = false
	if _wave_lb != null:
		_wave_lb.text = "娉?%d/%d" % [nw, _max_wave]
	_toast("鍥炴疆 路 娉㈡暟 %d 鈫?%d锛岄噸澶村啀鍒? % [w, nw])
	_shiny_present("backwash")

# ============================================================
# 鐐僵鍗″嚭鍦烘紨鍑猴細鍥涘紶鍚勪竴濂楋紙鍔ㄧ敾 / 闊虫晥 / 闊充箰閮戒笉鍚岋級
#   devour       鍣浄 路 鍚炲櫖鏀跺壊 鈥斺€?鐧介棯 + 绔栨潯鍐插嚮 + drum
#   swallow_sea  鍚炴捣 路 鍏婚緳 鈥斺€?钃濇疆浠庡簳鍗囪捣 + warcry
#   fentian      鐒氬ぉ 路 鐏?鈥斺€?姗欒壊鍥涜竟鍚戝唴鐑?+ tension
#   backwash     鍥炴疆 路 鍊掓祦 鈥斺€?鐧藉渾浠庝腑蹇冩墿鏁?+ 浣庨煶閽?# ============================================================
func _shiny_present(kind: String) -> void:
	# ---- 闊充箰锛堢煭淇?stinger锛?.8 绉掑悗鏀舵帀锛?---
	var music := ""
	match kind:
		"devour": music = "bgm_tower"
		"swallow_sea": music = "menu_jiangnan"
		"fentian": music = "menu_youzhou"
		"backwash": music = "menu_wudao"
		"jianpo": music = "menu_shushan"
		"gunshan": music = "menu_shaolin"
		"wanren": music = "menu_jiangnan"
		"baicao": music = "menu_shushan"
		"undying": music = "menu_hejian"
		"qianzhi": music = "menu_youzhou"
		"shiyun": music = "menu_shaolin"
		"zhongli": music = "menu_jiangnan"
	if music != "":
		Aud.play_bgm(music, 0.25)
		_stop_stinger(1.8)
	# ---- 闊虫晥 ----
	match kind:
		"devour":
			Aud.sfx("coin", -6.0, 1.0)
			Aud.sfx("hit_heavy", -10.0, 1.0)
			Aud.sfx("drum", -4.0, 1.0)
		"swallow_sea":
			Aud.sfx("warcry", -6.0, 0.9)
			Aud.sfx("rain", -14.0, 0.8)
		"fentian":
			Aud.sfx("tension", -6.0, 1.2)
			Aud.sfx("hit_slash2", -10.0, 0.9)
		"backwash":
			Aud.sfx("bell", -6.0, 0.6)          # 浣庨煶閽?			Aud.sfx("ink_drop", -10.0, 0.7)
		"jianpo":
			Aud.sfx("sword_draw", -4.0, 1.1)
			Aud.sfx("slash_light2", -8.0, 0.95)
		"gunshan":
			Aud.sfx("wood_down", -4.0, 0.8)
			Aud.sfx("melee", -8.0, 0.9)
		"wanren":
			Aud.sfx("sword_draw", -4.0, 1.25)
			Aud.sfx("slash_light", -8.0, 1.2)
		"baicao":
			Aud.sfx("enlighten", -4.0, 1.0)
			Aud.sfx("pet_chirp1", -12.0, 1.1)
		"undying":
			Aud.sfx("bell", -4.0, 1.1)
			Aud.sfx("wind", -10.0, 0.9)
		"qianzhi":
			Aud.sfx("paper", -4.0, 1.0)
			Aud.sfx("bell", -8.0, 1.3)
		"shiyun":
			Aud.sfx("wood_down", -4.0, 0.7)
			Aud.sfx("hit_heavy", -8.0, 0.8)
		"zhongli":
			Aud.sfx("coin", -4.0, 1.15)
			Aud.sfx("chest", -8.0, 1.0)
	# ---- 瑙嗛锛堟湁瑙嗛灏辩敤瑙嗛锛屾病鏈夋墠閫€鍥炵▼搴忓寲鍔ㄧ敾锛?---
	if _play_shiny_video(kind):
		if _core != null:
			_core.Shake_add(6.0)
		return
	# ---- 鍔ㄧ敾 ----
	match kind:
		"devour":
			_flash(Color(1.0, 0.98, 0.90), 0.85, 0.06, 0.30)
			for i in 3:
				_sweep_bar(Color(1.0, 0.97, 0.86, 0.55), 0.08 * float(i))
		"swallow_sea":
			_flash(Color(0.55, 0.78, 1.0), 0.60, 0.12, 0.45)
			_rise_tide()
		"fentian":
			_flash(Color(1.0, 0.66, 0.30), 0.70, 0.10, 0.40)
			_burn_edges()
		"backwash":
			_flash(Color(0.80, 0.88, 1.0), 0.50, 0.10, 0.40)
			_ring_out()
		"jianpo":
			_flash(Color(0.98, 0.95, 0.80), 0.55, 0.08, 0.34)
			_sword_rain()
		"gunshan":
			_flash(Color(0.82, 0.68, 0.40), 0.60, 0.10, 0.40)
			_rise_tide()
		"wanren":
			_flash(Color(0.62, 0.88, 0.95), 0.55, 0.08, 0.34)
			_sweep_bar(Color(0.75, 0.95, 1.0, 0.55), 0.0)
		"baicao":
			_flash(Color(0.55, 0.88, 0.50), 0.55, 0.08, 0.34)
			_ring_out()
		"undying":
			_flash(Color(1.0, 0.92, 0.62), 0.60, 0.10, 0.40)
			_ring_out()
		"qianzhi":
			_flash(Color(0.96, 0.94, 0.88), 0.60, 0.08, 0.36)
			_sword_rain()
		"shiyun":
			_flash(Color(0.62, 0.58, 0.50), 0.65, 0.10, 0.40)
			_ring_out()
		"zhongli":
			_flash(Color(1.0, 0.92, 0.52), 0.62, 0.08, 0.36)
			_sword_rain()
	if _core != null:
		_core.Shake_add(6.0 if kind != "devour" else 9.0)

func _stop_stinger(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	Aud.stop_bgm(0.6)

func _flash(col: Color, a: float, t_in: float, t_out: float) -> void:
	var r := ColorRect.new()
	r.color = Color(col.r, col.g, col.b, 0.0)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 60
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", a, t_in)
	tw.tween_property(r, "color:a", 0.0, t_out)
	tw.tween_callback(func() -> void: r.queue_free())

func _sweep_bar(col: Color, delay: float) -> void:
	var r := ColorRect.new()
	r.color = col
	r.size = Vector2(18, 1280)
	r.position = Vector2(-30, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 61
	add_child(r)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(r, "position:x", 740.0, 0.22)
	tw.tween_property(r, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void: r.queue_free())

func _rise_tide() -> void:
	var r := ColorRect.new()
	r.color = Color(0.45, 0.72, 0.95, 0.45)
	r.size = Vector2(720, 0)
	r.position = Vector2(0, 1280)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 61
	add_child(r)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "size:y", 1280.0, 0.40)
	tw.tween_property(r, "position:y", 0.0, 0.40)
	tw.chain().tween_property(r, "modulate:a", 0.0, 0.32)
	tw.chain().tween_callback(func() -> void: r.queue_free())

func _burn_edges() -> void:
	for i in 4:
		var r := ColorRect.new()
		r.color = Color(0.95, 0.45, 0.18, 0.40)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.z_index = 61
		if i == 0:
			r.size = Vector2(720, 40); r.position = Vector2(0, -40)
		elif i == 1:
			r.size = Vector2(720, 40); r.position = Vector2(0, 1280)
		elif i == 2:
			r.size = Vector2(40, 1280); r.position = Vector2(-40, 0)
		else:
			r.size = Vector2(40, 1280); r.position = Vector2(720, 0)
		add_child(r)
		var tw := create_tween()
		tw.set_parallel(true)
		if i == 0: tw.tween_property(r, "position:y", 560.0, 0.35)
		elif i == 1: tw.tween_property(r, "position:y", 740.0, 0.35)
		elif i == 2: tw.tween_property(r, "position:x", 300.0, 0.35)
		else: tw.tween_property(r, "position:x", 380.0, 0.35)
		tw.chain().tween_property(r, "modulate:a", 0.0, 0.30)
		tw.chain().tween_callback(func() -> void: r.queue_free())

func _ring_out() -> void:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 61
	add_child(c)
	var r := ColorRect.new()
	r.color = Color(0.85, 0.92, 1.0, 0.42)
	r.size = Vector2(80, 80)
	r.position = Vector2(320, 600)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(r)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "size", Vector2(1600, 1600), 0.45)
	tw.tween_property(r, "position", Vector2(-440, -160), 0.45)
	tw.tween_property(r, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(func() -> void: c.queue_free())

# ---------------- 涓昏锛氬熀纭€鍓戞硶锛堣鍔級 ----------------
#   涓昏涓嶈繘鎶€鑳芥爮锛屼粬鐨勫叚妗ｅ叏閮ㄦ姌鎴愭櫘鏀诲姞鎴愶紝缁勫悎涓€婵€娲诲氨鐩存帴鍔犲湪鑻遍泟韬笂銆?#   dmg_pct灞炰簬鍩虹鍓戞硶锛沞lem_pct.鐗╃悊鐢盻add_ancestor_effects鐧昏鍒扮墿鐞嗙被鍨嬨€?func _apply_hero_passive(eff: Dictionary) -> void:
	if eff.is_empty() or _core == null:
		return
	# dmg_pct宸茬敱_add_ancestor_effects鐧昏鍒版湰鎶€鑳斤紝鐗╃悊鍏变韩宸茶繘绫诲瀷澧炲箙銆?	var pct := float(eff.get("dmg_pct", 0.0))
	var physical_shared := float((eff.get("elem_pct", {}) as Dictionary).get("鐗╃悊", 0.0))
	# 鏀婚€熶粠灞炴€у眰璇诲彇锛屾牳蹇冩寜鐜拌鍩虹鍑烘墜闂撮殧闄や互鍊嶇巼銆?	if eff.has("aspd_pct"):
		_core.attr_add_amp("aspd", float(eff["aspd_pct"]) / 100.0)
		_core.hero["aspd"] = minf(MAX_ASPD, _core.attr_final("aspd") / float(_core.ATTR_BASE["aspd"]))
	# 澶氱洰鏍?/ 杩藉嚮 / 鍓戞皵锛氳涓嬫潵锛屾櫘鏀绘椂缁撶畻
	for k in ["tgt_add", "chase", "qijian"]:
		if eff.has(k):
			_hero_passive[k] = float(_hero_passive.get(k, 0.0)) + float(eff[k])
	var parts: Array = []
	if pct != 0.0: parts.append("鍓戞硶浼ゅ +%d%%" % int(pct))
	if physical_shared != 0.0: parts.append("鐗╃悊鍏变韩 +%d%%" % int(physical_shared))
	if eff.has("aspd_pct"): parts.append("鏀婚€?+%d%%" % int(eff["aspd_pct"]))
	if eff.has("tgt_add"): parts.append("鐩爣 +%d" % int(eff["tgt_add"]))
	if eff.has("chase"): parts.append("杩藉嚮 %d%%" % int(eff["chase"]))
	if eff.has("qijian"): parts.append("鍓戞皵 %d%%" % int(eff["qijian"]))
	if not parts.is_empty():
		_toast("鍩虹鍓戞硶 路 " + " 路 ".join(PackedStringArray(parts)))
	Aud.sfx("skill", -14.0)

# 涓昏鏅敾鐨勯澶栫粨绠楋紙澶氱洰鏍?/ 杩藉嚮 / 鍓戞皵锛?func _hero_extra_hits(primary: Dictionary = {}) -> void:
	if _run_over or _core == null or not _core.running or float(_core.hero.get("hp", 0.0)) <= 0.0:
		return
	var foes := _live_foes()
	if foes.is_empty():
		return
	if primary.is_empty():
		primary = foes[0] # 淇濈暀鐩存帴璋冪敤宸ュ叿鐨勯粯璁ょ洰鏍囷紝瀹炴垬淇″彿鎬绘槸浼犲叆鏈垁鐩爣銆?	var epoch: int = _core._enemy_attack_epoch
	# v9 鍓戦瓌锛氳繛缁墦鍚屼竴鐩爣 鈫?鏀婚€熷彔灞傦紱鎹㈢洰鏍囩珛鍒婚噸缃?	if _hero_jianpo:
		var tid := int(primary.get("_tid", -1))
		if tid != _jpo_tid:
			_jpo_tid = tid
			if _jpo_stacks > 0:
				_core.attr_add_amp("aspd", -0.06 * float(_jpo_stacks))
			_jpo_stacks = 0
		else:
			_jpo_stacks += 1                      # 涓嶈涓婇檺锛氬彧闈?鎹㈢洰鏍?閲嶇疆
			_core.attr_add_amp("aspd", 0.06)
		_core.hero["aspd"] = minf(MAX_ASPD, _core.attr_final("aspd") / float(_core.ATTR_BASE["aspd"]))
	if _hero_passive.is_empty():
		return
	var base: float = float(_core.hero.get("atk", 12.0)) * _core.basic_attack_multiplier()
	var extra := int(_hero_passive.get("tgt_add", 0.0))
	var extra_hits := 0
	for candidate in foes:
		if extra_hits >= extra: break
		if candidate == primary or float(candidate.get("hp", 0.0)) <= 0.0: continue
		if not _hero_extra_damage(candidate, base * 0.7, epoch): return
		extra_hits += 1
	if randf() < float(_hero_passive.get("chase", 0.0)) / 100.0:
		if float(primary.get("hp", 0.0)) > 0.0:
			if not _hero_extra_damage(primary, base * 0.5, epoch): return
			_core._push_float(float(primary["x"]), float(primary["y"]) - 40.0, "杩藉嚮", Color(0.95, 0.85, 0.55))
	if randf() < float(_hero_passive.get("qijian", 0.0)) / 100.0:
		var at := Vector2(float(primary["x"]), float(primary["y"]))
		# 鍓戦瓌锛氬墤姘旇繘鍖栨垚銆屼竾鍓戝綊瀹椼€嶁€斺€旇寖鍥存洿澶с€佷激瀹虫洿鐙?		var rad := 300.0 if _hero_jianpo else 130.0
		var mul := 2.5 if _hero_jianpo else 1.2
		for f_v in foes:
			var f: Dictionary = f_v
			if float(f.get("hp", 0.0)) > 0.0 and (Vector2(float(f["x"]), float(f["y"])) - at).length() <= rad:
				if not _hero_extra_damage(f, base * mul, epoch): return
				_core._push_float(float(f["x"]), float(f["y"]) - 44.0,
					"涓囧墤褰掑畻" if _hero_jianpo else "鍓戞皵",
					Color(0.98, 0.94, 0.74) if _hero_jianpo else Color(0.88, 0.92, 1.0), true)
		Aud.sfx("slash_light2" if _hero_jianpo else "slash_light", -6.0 if _hero_jianpo else -8.0)
		if _hero_jianpo and _core != null:
			_core.Shake_add(5.0)

func _hero_extra_damage(target: Dictionary, amount: float, epoch: int) -> bool:
	if _run_over or not _core.running or epoch != _core._enemy_attack_epoch or float(_core.hero.get("hp", 0.0)) <= 0.0:
		return false
	if float(target.get("hp", 0.0)) <= 0.0 or bool(target.get("_death_settled", false)) or float(target.get("dying", 0.0)) > 0.0:
		return true
	_core._apply_dmg(target, amount, "鐗╃悊")
	if float(target.get("hp", 0.0)) <= 0.0:
		_core._kill_foe(target)
	return not _run_over and _core.running and epoch == _core._enemy_attack_epoch and float(_core.hero.get("hp", 0.0)) > 0.0

# ---------------- 鍓戦瓌锛堜富瑙掔偒鍗★級 ----------------
func _enable_jianpo() -> void:
	_hero_jianpo = true
	_jpo_tid = -1
	_jpo_stacks = 0
	_toast("鍓戦瓌鍏ュ崱缁?路 杩炲嚮鍚屼竴鐩爣鏀婚€熼€掑锛堟崲鐩爣閲嶇疆锛壜?鍓戞皵杩涘寲涓恒€屼竾鍓戝綊瀹椼€?)
	_shiny_present("jianpo")

# 鍓戦洦锛氫竴鎺掔珫鍓戜粠澶╄€岄檷锛堝墤榄勪笓灞炴紨鍑猴級
func _sword_rain() -> void:
	for i in 9:
		var r := ColorRect.new()
		r.color = Color(0.99, 0.97, 0.86, 0.75)
		r.size = Vector2(4, 220)
		r.position = Vector2(40.0 + float(i) * 78.0, -240.0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.z_index = 61
		add_child(r)
		var tw := create_tween()
		tw.tween_interval(0.03 * float(i))
		tw.tween_property(r, "position:y", 1280.0, 0.34)
		tw.tween_property(r, "modulate:a", 0.0, 0.14)
		tw.tween_callback(func() -> void: r.queue_free())

# ============================================================
# 婊氬湴榫?路 鎾炲嚮娴侊紙鐢熷懡鍊肩櫨鍒嗘瘮浼ゅ + 鍙扮悆鍙嶅脊锛?#   鎾炲嚮浼ゅ = 姘旇涓婇檺 脳 6%锛堢墿鐞嗭級锛屾瘡璺冲叏棰濄€佷笉閫掑噺
#   鍙嶅脊棰勭畻锛氭棤鐐崱 鍏ㄥ満 1 娆★紱鏈夈€屾粴灞便€嶆瘡涓晫浜哄悇涓€娆?鈫?鏃犻檺杩為攣
# ============================================================
const RAM_HP_PCT := 6.0          # 鎾炲嚮浼ゅ = 姘旇涓婇檺 脳 6%
const RAM_KNOCK := 1800.0        # 鍑婚€€鍒濋€?px/s锛堣鍘嬭繃鏍稿績鐨勫璺Щ鍔級
const RAM_HIT_R := 34.0          # 纰版挒鍒ゅ畾鍗婂緞锛?鈽?浼氬姞锛?const WALL_X0 := 24.0
const WALL_X1 := 696.0
const WALL_Y0 := 150.0
const WALL_Y1 := 700.0

var _ram_shiny := false          # 婊氬北锛氭瘡涓晫浜哄悇寮逛竴娆?var _ram_foe_seq := 0            # 鍐叉挒鍛戒腑璁板綍浣跨敤鐙珛缂栧彿锛屼笉渚濊禆灏氭湭鐢熸垚鐨勬樉绀簍oken銆?var _ram_step_accum := 0.0
var _ram_step_epoch := -1
const RAM_STEP := 1.0 / 60.0

func _ram_foe_id(f: Dictionary) -> int:
	if not f.has("_ram_uid"):
		_ram_foe_seq += 1
		f["_ram_uid"] = _ram_foe_seq
	return int(f["_ram_uid"])

func _ram_stop(f: Dictionary) -> void:
	f["_kx"] = 0.0
	f["_ky"] = 0.0
	f.erase("_ram_ctx")
	f.erase("_seg_a")

func _ram_mods() -> Dictionary:
	return _anc_mod.get("gundilong", {})

func _ram_damage() -> float:
	var m := _ram_mods()
	var pct := RAM_HP_PCT * (1.0 + (float(m.get("dmg_pct", 0.0)) + _skill_level_bonus("gundilong")) / 100.0)
	return float(_core.hero.get("hp_max", 200.0)) * pct / 100.0

# 鍖栬韩鑲夎泲锛氭妸鏈€杩戠殑涓€鍙挒椋?func _charge_ram() -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	var foes := _live_foes()
	if foes.is_empty():
		return
	var f0: Dictionary = foes[0]
	var hp0 := Vector2(_core.hero_pos)
	var dir := (Vector2(float(f0["x"]), float(f0["y"])) - hp0)
	if dir.length() < 1.0:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	# 姣忔鏂芥硶鍚勮嚜淇濆瓨浼ゅ銆侀绠楀拰鍛戒腑缂栧彿锛涗笉鎸佹湁鏁屼汉寮曠敤锛岄伩鍏嶅惊鐜紩鐢ㄣ€?	var ctx := {"damage": _ram_damage(), "budget": 999 if _ram_shiny else 1,
		"shiny": _ram_shiny, "epoch": epoch, "hits": {_ram_foe_id(f0): true}, "bounced": {}}
	ctx["chain_damage"] = float(ctx["damage"]) * (1.0 + float(_ram_mods().get("chain_dmg", 0.0)) / 100.0)
	# 鍐叉挒婕斿嚭锛氫竴閬撳湡榛剆treak
	_ram_streak(hp0, Vector2(float(f0["x"]), float(f0["y"])))
	_core._apply_dmg(f0, float(ctx["damage"]), "鐗╃悊")
	_core._push_float(float(f0["x"]), float(f0["y"]) - 46.0, "鑲夎泲鍐插嚮", Color(0.92, 0.80, 0.42), true)
	if float(f0.get("hp", 0.0)) <= 0.0:
		_core._kill_foe(f0)
	if not _skill_batch_active(epoch):
		return
	if not _core.foes.has(f0) or float(f0.get("hp", 0.0)) <= 0.0 or bool(f0.get("_death_settled", false)):
		_ram_stop(f0)
		return
	var pm := 1.0 + float(_ram_mods().get("impact", 0.0)) * 0.15   # 鍐插嚮鍔涳細姣忕偣 +15% 鍑婚€€璺濈
	f0["_kx"] = dir.x * RAM_KNOCK * pm
	f0["_ky"] = dir.y * RAM_KNOCK * pm
	f0["_seg_a"] = Vector2(float(f0["x"]), float(f0["y"]))   # 鎵帬璧风偣
	f0["_ram_ctx"] = ctx
	_core.Shake_add(7.0)
	Aud.sfx("hit_heavy", -6.0)

func _ram_streak(a: Vector2, b: Vector2) -> void:
	var r := ColorRect.new()
	r.color = Color(0.92, 0.80, 0.42, 0.55)
	r.size = Vector2(maxf(6.0, (b - a).length()), 10)
	r.position = _core.position + a
	r.pivot_offset = Vector2(0, 5)
	r.rotation = (b - a).angle()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 9
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.30)
	tw.tween_callback(func() -> void: r.queue_free())

func _tick_knock(dt: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	if _ram_step_epoch != epoch:
		_ram_step_epoch = epoch
		_ram_step_accum = 0.0
	var moving := false
	for f in _core.foes:
		if float(f.get("_kx", 0.0)) != 0.0 or float(f.get("_ky", 0.0)) != 0.0:
			moving = true
			break
	if not moving:
		_ram_step_accum = 0.0
		return
	# 淇濈暀鍘?0甯т笅鐨勮繍鍔?澧欓潰/纰版挒椤哄簭锛涙覆鏌撳抚鐜囧彧鍐冲畾鏈抚琛ュ嚑涓浐瀹氭銆?	_ram_step_accum += maxf(0.0, dt)
	while _ram_step_accum + 0.000000001 >= RAM_STEP:
		_ram_step_accum = maxf(0.0, _ram_step_accum - RAM_STEP)
		_step_knock(RAM_STEP, epoch)
		if not _skill_batch_active(epoch):
			_ram_step_accum = 0.0
			return

func _step_knock(dt: float, epoch: int) -> void:
	for f_v in _core.foes.duplicate():
		if not _skill_batch_active(epoch):
			return
		var f: Dictionary = f_v
		if not _core.foes.has(f):
			continue
		var kx := float(f.get("_kx", 0.0))
		var ky := float(f.get("_ky", 0.0))
		if kx == 0.0 and ky == 0.0:
			continue
		var ctx: Dictionary = f.get("_ram_ctx", {})
		if ctx.is_empty() or int(ctx.get("epoch", -1)) != epoch or float(f.get("hp", 0.0)) <= 0.0 or bool(f.get("_death_settled", false)) or float(f.get("dying", 0.0)) > 0.0:
			_ram_stop(f)
			continue
		var px := float(f["x"]) + kx * dt
		var py := float(f["y"]) + ky * dt
		# 鎾炲 鈫?鍙嶅脊涓€娆″悗鍋滐紙鎾炲涓嶇畻娑堣€楅绠楋級
		if px < WALL_X0 or px > WALL_X1:
			kx = -kx * 0.6
			px = clampf(px, WALL_X0, WALL_X1)
		if py < WALL_Y0 or py > WALL_Y1:
			ky = -ky * 0.6
			py = clampf(py, WALL_Y0, WALL_Y1)
		f["x"] = px
		f["y"] = py
		# 琛板噺
		kx *= 0.955
		ky *= 0.955
		if absf(kx) < 6.0 and absf(ky) < 6.0:
			kx = 0.0
			ky = 0.0
		f["_kx"] = kx
		f["_ky"] = ky
		# 鎾炲埌鍒殑鎬?鈫?杩為攣
		if int(ctx["budget"]) <= 0 or (ctx["bounced"] as Dictionary).has(_ram_foe_id(f)):
			continue
		var seg_a: Vector2 = f.get("_seg_a", Vector2(float(f["x"]), float(f["y"])))
		var seg_b := Vector2(px, py)
		f["_seg_a"] = seg_b
		var reach := RAM_HIT_R + _ram_radius_bonus()
		for o_v in _core.foes.duplicate():
			var o: Dictionary = o_v
			if o == f or float(o.get("hp", 0.0)) <= 0.0 or bool(o.get("_death_settled", false)) or float(o.get("dying", 0.0)) > 0.0 or (ctx["hits"] as Dictionary).has(_ram_foe_id(o)):
				continue
			if _dist_point_seg(Vector2(float(o["x"]), float(o["y"])), seg_a, seg_b) > reach:
				continue
			ctx["budget"] = int(ctx["budget"]) - 1
			ctx["bounced"][_ram_foe_id(f)] = true
			ctx["hits"][_ram_foe_id(o)] = true
			_core._apply_dmg(o, float(ctx["chain_damage"]), "鐗╃悊")
			_core._push_float(float(o["x"]), float(o["y"]) - 40.0, "鍙嶅脊", Color(0.92, 0.80, 0.42))
			if float(o.get("hp", 0.0)) <= 0.0:
				_core._kill_foe(o)
			if not _skill_batch_active(epoch):
				return
			var d := (Vector2(float(o["x"]), float(o["y"])) - Vector2(px, py))
			if d.length() < 1.0:
				d = Vector2(0, -1)
			d = d.normalized()
			var sp := float(_ram_mods().get("stun_s", 0.0))
			var alive: bool = _core.foes.has(o) and float(o.get("hp", 0.0)) > 0.0 and not bool(o.get("_death_settled", false))
			if alive:
				o["para"] = maxf(float(o.get("para", 0.0)), sp if sp > 0.0 else 0.0)
			if alive and (bool(ctx["shiny"]) or _ram_mods().get("stun_s", 0.0) != 0.0):
				var pm2 := 1.0 + float(_ram_mods().get("impact", 0.0)) * 0.15
				o["_kx"] = d.x * RAM_KNOCK * pm2
				o["_ky"] = d.y * RAM_KNOCK * pm2
				o["_seg_a"] = Vector2(float(o["x"]), float(o["y"]))
				o["_ram_ctx"] = ctx
			# 婊氬北锛氭瘡娆″弽寮?鈫?姘旇涓婇檺鍥哄畾 +8锛堝崰浣嶏紝鐐崱瀹炶鍚庢墦寮€锛?			if bool(ctx["shiny"]):
				_apply_flat_growth(0.0, 8.0)
			break

func _ram_radius_bonus() -> float:
	return float(_ram_mods().get("radius_add", 0.0))

# 鐐瑰埌绾挎鐨勮窛绂伙紙鐢ㄤ簬"鎾為璺緞鎵繃璋?锛?func _dist_point_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

# ---------------- 婊氬北锛堟粴鍦伴緳鐐崱锛?----------------
#   姣忎釜琚挒鐨勬晫浜洪兘鑳藉悇寮逛竴娆?鈫?鐞嗚涓婃棤闄愯繛閿?#   姣忔瑙﹀彂鍙嶅脊 鈫?姘旇涓婇檺鍥哄畾 +8
const GUNSHAN_HP := 8.0

func _enable_gunshan() -> void:
	_ram_shiny = true
	_toast("婊氬北鍏ュ崱缁?路 姣忎釜琚挒鐨勬晫浜洪兘鑳藉弽寮逛竴娆★紝姣忔鍙嶅脊姘旇涓婇檺 +8")
	_shiny_present("gunshan")

func _gunshan_grow() -> void:
	_apply_flat_growth(0.0, GUNSHAN_HP)

# ============================================================
# 鑻忛潚楦?路 闈掗妇椋炲垉锛堢洿绾跨┛閫?+ 鍥炵▼锛?#   绌块€?= 涓€鏉＄嚎涓婅兘鎵撳埌鍑犱釜浜猴紱椋炲垁 = 鍚屾椂鍑犳潯绾?#   5鈽?鍥炴棆锛氬埌缁堢偣鍚庡師璺啀绌夸竴閬嶏紙浼ゅ 脳鍥炵▼鍊嶇巼锛?# ============================================================
const FEIREN_HALF_W := 26.0       # 椋炲垉鍒ゅ畾鍗婂
const FEIREN_LEN := 780.0         # 椋炲垉闀垮害

func _cast_feiren(mul: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	var m: Dictionary = _anc_mod.get("qingluan", {})
	var foes := _live_foes()
	if foes.is_empty():
		return
	var dmg_pct := float(m.get("dmg_pct", 0.0)) + _skill_level_bonus("qingluan")
	var pierce := 1 + int(m.get("pierce", 0.0))
	if _wanren:
		pierce += 2 + _wanren_pierce            # 鐐崱锛氳捣姝?+2锛屽洖绋嬫垚闀挎棤涓婇檺
	var knives := 1 + int(m.get("knife", 0.0))
	if _wanren:
		knives += pierce                        # 鐐崱锛氭瘡 1 鐐圭┛閫?+1 鎶婇鍒€
	var volley := float(m.get("volley", 0.0)) > 0.0
	var vmul := 1.0 + float(m.get("volley_pct", 0.0)) / 100.0
	var base := float(_core.hero.get("atk", 12.0)) * mul * (1.0 + dmg_pct / 100.0)
	var hp0 := Vector2(_core.hero_pos)
	var dir := (Vector2(float(foes[0]["x"]), float(foes[0]["y"])) - hp0)
	if dir.length() < 1.0:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	for k in knives:
		if not _skill_batch_active(epoch):
			return
		var ang := dir.angle() + (float(k) - float(knives - 1) * 0.5) * 0.16
		_feiren_line(hp0, Vector2(cos(ang), sin(ang)), base, pierce, volley, vmul)
		if not _skill_batch_active(epoch):
			return
	Aud.sfx("slash_light", -8.0)

func _feiren_line(origin: Vector2, d: Vector2, base: float, pierce: int, volley: bool, vmul: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch):
		return
	var hits: Array = []
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		var rel := Vector2(float(f["x"]), float(f["y"])) - origin
		var t := rel.dot(d)
		if t < 0.0 or t > FEIREN_LEN:
			continue
		if absf(rel.cross(d)) > FEIREN_HALF_W:
			continue
		hits.append({"f": f, "t": t})
	hits.sort_custom(func(a, b) -> bool: return float(a["t"]) < float(b["t"]))
	var n := mini(pierce, hits.size())
	for i in n:
		var f: Dictionary = (hits[i] as Dictionary)["f"]
		if not _core.foes.has(f) or float(f.get("hp", 0.0)) <= 0.0 or bool(f.get("_death_settled", false)) or float(f.get("dying", 0.0)) > 0.0:
			continue
		_core._apply_dmg(f, base, "鐗╃悊")
		_core._push_float(float(f["x"]), float(f["y"]) - 42.0, "椋炲垉", Color(0.55, 0.82, 0.90), i == 0)
		if float(f.get("hp", 0.0)) <= 0.0:
			_core._kill_foe(f)
		if not _skill_batch_active(epoch):
			return
	if volley and n > 0:
		if _wanren:
			_wanren_volleys += 1
			if _wanren_volleys % 3 == 0:
				_wanren_pierce += 1
				_toast("涓囧垉 路 绌块€?+1锛堢疮璁?%d锛? % (2 + _wanren_pierce))
		for i in range(n - 1, -1, -1):
			var f2: Dictionary = (hits[i] as Dictionary)["f"]
			if not _core.foes.has(f2) or float(f2.get("hp", 0.0)) <= 0.0 or bool(f2.get("_death_settled", false)) or float(f2.get("dying", 0.0)) > 0.0:
				continue
			_core._apply_dmg(f2, base * vmul, "鐗╃悊")
			_core._push_float(float(f2["x"]), float(f2["y"]) - 62.0, "鍥炵▼", Color(0.75, 0.95, 1.0), true)
			if float(f2.get("hp", 0.0)) <= 0.0:
				_core._kill_foe(f2)
			if not _skill_batch_active(epoch):
				return
	var a: Vector2 = _core.position + origin
	var r := ColorRect.new()
	r.color = Color(0.70, 0.92, 1.0, 0.7)
	r.size = Vector2(FEIREN_LEN, 4)
	r.position = Vector2(a.x, a.y - 2.0)
	r.pivot_offset = Vector2(0, 2)
	r.rotation = d.angle()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 9
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: r.queue_free())

# ---------------- 涓囧垉锛堣嫃闈掗妇鐐崱锛?----------------
func _enable_wanren() -> void:
	_wanren = true
	_wanren_pierce = 0
	_wanren_volleys = 0
	_toast("涓囧垉鍏ュ崱缁?路 绌块€忔棤涓婇檺锛屾瘡鐐圭┛閫?+1 鎶婇鍒€锛屾瘡 3 娆″洖绋嬬┛閫?+1")
	_shiny_present("wanren")

# ============================================================
# 鏌冲嵖鍗?路 鍥炴槬锛堟不鐤?+ 鐜瘨 + 鏄撲激锛?#   娌荤枟 = 鏀诲嚮 脳 200% 脳 (1 + 娌荤枟% + 鏈ㄧ郴%)      鈥斺€?浼ゅ鍒绘剰浣庯紝濂规槸杈呭姪
#   鐜瘨 = 鍦堝唴鏁屼汉姣忕 鏀诲嚮 脳 30% 脳 灞傛暟 脳 (1 + 鏈ㄧ郴%)
#   5鈽?闀挎槬锛氭瘨鏇翠箙锛屼笖涓嫑鑰呭彈浼?+10%锛堝敮涓€涓€灞傦紝鍙埛鏂帮級
# ============================================================
const HEAL_RATIO := 2.0
const POISON_RATE := 0.30
const AURA_BASE_R := 110.0

func _wood_pct() -> float:
	return _core.type_amp("鏈ㄧ郴") * 100.0 if _core != null else 0.0

func _cast_heal(mul: float, aid := "liuqingqing") -> void:
	if _core == null or not _skill_batch_active(_core._enemy_attack_epoch):
		return
	var m: Dictionary = _anc_mod.get(aid, {})
	var wood := _wood_pct()
	var bonus := _skill_level_bonus(aid)
	var heal := float(_core.hero.get("atk", 12.0)) * HEAL_RATIO * mul * (1.0 + (float(m.get("heal_pct", 0.0)) + wood + bonus) / 100.0)
	heal = _core.heal_hero(heal)
	if heal > 0.0:
		_core._push_float(_core.hero_pos.x, _core.hero_pos.y - 60.0, "%+.1f" % heal if heal < 1.0 else "+%d" % int(heal), Color(0.42, 0.85, 0.40), true)
	var rad := AURA_BASE_R + float(m.get("radius_add", 0.0))
	var dur := 4.0 + float(m.get("poison_dur", 0.0))
	var vuln := float(m.get("vuln", 0.0))
	var hp0 := Vector2(_core.hero_pos)
	for f_v in _core.foes:
		if float(m.get("aura", 0.0)) <= 0.0: break
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		if (Vector2(float(f["x"]), float(f["y"])) - hp0).length() > rad:
			continue
		f["poison"] = float(f.get("poison", 0.0)) + 1.0 if _baicao else 1.0
		f["poison_bonus"] = 1.0 + bonus / 100.0
		var layers: Array = f.get("poison_layers", []) if _baicao and float(f["poison"]) > 1.0 else []
		layers.append({"t": dur, "bonus": 1.0 + bonus / 100.0})
		f["poison_layers"] = layers
		f["poison"] = float(layers.size())
		f["poison_t"] = maxf(float(f.get("poison_t", 0.0)), dur)
		if vuln > 0.0:
			f["vuln_t"] = maxf(float(f.get("vuln_t", 0.0)), dur)   # 鍙埛鏂帮紝涓嶅彔灞?			f["vuln_pct"] = vuln
	# 缁胯壊鐜尝
	_heal_ring(rad)
	Aud.sfx("enlighten", -10.0)

func _heal_ring(rad: float) -> void:
	var r := ColorRect.new()
	r.color = Color(0.45, 0.85, 0.42, 0.35)
	r.size = Vector2(60, 60)
	r.position = _core.position + Vector2(_core.hero_pos.x - 30.0, _core.hero_pos.y - 30.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 8
	add_child(r)
	var target := rad * 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "size", Vector2(target, target), 0.45)
	tw.tween_property(r, "position", _core.position + Vector2(_core.hero_pos.x - target * 0.5, _core.hero_pos.y - target * 0.5), 0.45)
	tw.tween_property(r, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(func() -> void: r.queue_free())

func _tick_poison(dt: float) -> void:
	if _core == null:
		return
	var epoch: int = _core._enemy_attack_epoch
	if not _skill_batch_active(epoch): return
	for f_v in _core.foes.duplicate():
		if not _skill_batch_active(epoch): return
		var f: Dictionary = f_v
		if not _core.foes.has(f): continue
		var st := float(f.get("poison", 0.0))
		if st <= 0.0:
			continue
		if float(f.get("hp", 0.0)) <= 0.0 or bool(f.get("_death_settled", false)) or float(f.get("dying", 0.0)) > 0.0:
			f["poison"] = 0.0
			continue
		if f.has("poison_layers"):
			if not _tick_poison_layers(f, maxf(0.0, dt), epoch): return
			continue
		var remaining := maxf(0.0, dt)
		var elapsed := 0.0
		while remaining > 0.0 and float(f.get("poison", 0.0)) > 0.0:
			var life := maxf(0.0, float(f.get("poison_t", 4.0)))
			var step := minf(remaining, life)
			remaining -= step
			elapsed += step
			f["poison_t"] = life - step
			f["poison_acc"] = float(f.get("poison_acc", 0.0)) + step
			while float(f["poison_acc"]) + 0.000000001 >= 1.0:
				f["poison_acc"] = maxf(0.0, float(f["poison_acc"]) - 1.0)
				var at_t := elapsed - float(f["poison_acc"])
				var vuln := 1.0 + float(f.get("vuln_pct", 0.0)) / 100.0 if float(f.get("vuln_t", 0.0)) > at_t else 1.0
				var dmg := float(_core.hero.get("atk", 12.0)) * POISON_RATE * float(f["poison"]) * float(f.get("poison_bonus", 1.0))
				_core._apply_dmg(f, dmg, "鏈ㄧ郴", -1, vuln)
				_core._push_float(float(f["x"]), float(f["y"]) - 34.0, "姣?, Color(0.45, 0.80, 0.40))
				if randf() < 0.6:
					_spawn_pfx("impacts/hit-spark", _core.position + Vector2(float(f["x"]), float(f["y"]) - 18.0), 0.55, "poison", 1.2)
				if float(f.get("hp", 0.0)) <= 0.0: _core._kill_foe(f)
				if not _skill_batch_active(epoch): return
				if float(f.get("hp", 0.0)) <= 0.0 or not _core.foes.has(f): break
			if float(f.get("hp", 0.0)) <= 0.0 or not _core.foes.has(f): break
			if float(f["poison_t"]) <= 0.000000001:
				f["poison"] = maxf(0.0, float(f["poison"]) - 1.0)
				f["poison_t"] = 4.0
		if float(f.get("poison", 0.0)) <= 0.0: f.erase("poison")

func _tick_poison_layers(f: Dictionary, dt: float, epoch: int) -> bool:
	var layers: Array = f["poison_layers"]
	var start_acc := float(f.get("poison_acc", 0.0))
	var at_t := 1.0 - start_acc
	var max_duration := 0.0
	for layer in layers: max_duration = maxf(max_duration, float(layer["t"]))
	while at_t <= minf(dt, max_duration) + 0.000000001:
		var weight := 0.0
		for layer in layers:
			if float(layer["t"]) + 0.000000001 >= at_t:
				weight += float(layer["bonus"])
		if weight > 0.0:
			var vuln := 1.0 + float(f.get("vuln_pct", 0.0)) / 100.0 if float(f.get("vuln_t", 0.0)) > at_t else 1.0
			_core._apply_dmg(f, float(_core.hero.get("atk", 12.0)) * POISON_RATE * weight, "鏈ㄧ郴", -1, vuln)
			_core._push_float(float(f["x"]), float(f["y"]) - 34.0, "姣?, Color(0.45, 0.80, 0.40))
			if randf() < 0.6:
				_spawn_pfx("impacts/hit-spark", _core.position + Vector2(float(f["x"]), float(f["y"]) - 18.0), 0.55, "poison", 1.2)
			if float(f.get("hp", 0.0)) <= 0.0: _core._kill_foe(f)
			if not _skill_batch_active(epoch): return false
			if float(f.get("hp", 0.0)) <= 0.0 or not _core.foes.has(f): return true
		at_t += 1.0
	var alive: Array = []
	var max_life := 0.0
	for layer in layers:
		layer["t"] = maxf(0.0, float(layer["t"]) - dt)
		if float(layer["t"]) > 0.000000001:
			alive.append(layer)
			max_life = maxf(max_life, float(layer["t"]))
	f["poison_acc"] = fposmod(start_acc + dt, 1.0)
	f["poison_t"] = max_life
	f["poison"] = float(alive.size())
	f["poison_layers"] = alive
	if alive.is_empty():
		f.erase("poison")
		f.erase("poison_layers")
		f["poison_acc"] = 0.0
	return true

func _tick_vuln(dt: float) -> void:
	if _core == null:
		return
	for f_v in _core.foes:
		var f: Dictionary = f_v
		if float(f.get("vuln_t", 0.0)) > 0.0:
			f["vuln_t"] = float(f["vuln_t"]) - dt

# ---------------- 鐧捐崏锛堟煶鍗垮嵖鐐崱锛?----------------
var _baicao := false
# v12 鏄庣儧鍏夌幆锛堢函琚姩锛?var _mingzhu := false
var _aura_pull_acc := 0.0
var _undying_lamp := false
var _lamp_kills := 0
var _aura_extra_radius := 0.0

func _enable_baicao() -> void:
	if _baicao: return
	_baicao = true
	_add_ancestor_effects("liuqingqing", {"heal_pct": 10.0})
	_toast("鐧捐崏鍏ュ崱缁?路 姣掔礌鍙彔鍔狅紝鏂芥斁鏈夊嚑鐜囪繛鏀撅紙鍙墸涓€娆″唴鍔涳級")
	_shiny_present("baicao")

# 杩斿洖鏈瀹為檯鏂芥斁娆℃暟锛堝彧鍒や竴绉嶏級
func _baicao_times() -> int:
	var r := randf()
	if r < 0.10:
		return 5
	if r < 0.35:
		return 3
	if r < 0.85:
		return 2
	return 1

# ============================================================
# 鏄庣儧 路 鐏収鍏夌幆锛堢函琚姩锛屼笉杩涙妧鑳芥爮锛?#   鍦堝唴鏁屼汉锛氬噺閫?路 鏄撲激锛?鈽?鑱氱伅锛氭瘡绉?20% 姒傜巼琚惛鍚戜腑蹇?+ 鏈ㄧ郴纾ㄨ锛?#   2鈽?闀挎槑锛氬湀鍐呬富瑙掑洖琛€鍥炲唴
#   鑱氱伅浼ゅ闅忓崐寰勬垚闀匡細鏀诲嚮 脳 15% 脳 (鍗婂緞 / 180)
# ============================================================
const AURA_R_BASE := 180.0
const AURA_PULL_STEP := 120.0

func _aura_radius() -> float:
	var m: Dictionary = _anc_mod.get("mingzhu", {})
	var r := AURA_R_BASE + float(m.get("radius_add", 0.0)) + _aura_extra_radius
	if _undying_lamp:
		r += 40.0
	return r

func _tick_aura(dt: float) -> void:
	if not _mingzhu or _core == null or _run_over or not _core.running or float(_core.hero.get("hp", 0.0)) <= 0.0:
		return
	var epoch: int = _core._enemy_attack_epoch
	var m: Dictionary = _anc_mod.get("mingzhu", {})
	var rad := _aura_radius()
	var vuln := float(m.get("vuln", 0.0))
	var pull := float(m.get("pull", 0.0)) > 0.0
	var heal_aura := float(m.get("heal_aura", 0.0)) > 0.0
	var hp0 := Vector2(_core.hero_pos)
	if heal_aura:
		_core.heal_hero(float(_core.hero["hp_max"]) * 0.008 * dt)
		_mp = minf(_mp_max, _mp + 6.0 * dt)
	_aura_pull_acc += dt
	var do_pull := _aura_pull_acc >= 1.0
	if do_pull:
		_aura_pull_acc -= 1.0
	for f_v in _core.foes.duplicate():
		if _run_over or not _core.running or epoch != _core._enemy_attack_epoch or float(_core.hero.get("hp", 0.0)) <= 0.0:
			return
		var f: Dictionary = f_v
		if float(f.get("hp", 0.0)) <= 0.0 or float(f.get("dying", 0.0)) > 0.0:
			continue
		var d := Vector2(float(f["x"]), float(f["y"])) - hp0
		if d.length() > rad:
			continue
		f["slow_t"] = maxf(float(f.get("slow_t", 0.0)), 0.3)      # 鎸佺画鍑忛€?		if vuln > 0.0:
			f["vuln_t"] = maxf(float(f.get("vuln_t", 0.0)), 0.3)
			f["vuln_pct"] = vuln
		if pull and do_pull and randf() < 0.20:
			var dir := (-d).normalized()
			var step := minf(AURA_PULL_STEP, d.length())
			f["x"] = float(f["x"]) + dir.x * step
			f["y"] = float(f["y"]) + dir.y * step
			var dmg := float(_core.hero.get("atk", 12.0)) * 0.15 * (rad / AURA_R_BASE)
			_core._apply_dmg(f, dmg, "鏈ㄧ郴")
			_core._push_float(float(f["x"]), float(f["y"]) - 30.0, "鑱?, Color(0.95, 0.85, 0.55))
			if float(f.get("hp", 0.0)) <= 0.0:
				_core._kill_foe(f)

# ---------------- 涓嶇伃涔嬬伅锛堟槑鐑涚偒鍗★級 ----------------
func _enable_undying_lamp() -> void:
	_undying_lamp = true
	_lamp_kills = 0
	_toast("涓嶇伃涔嬬伅鍏ュ崱缁?路 鍗婂緞 +40锛屾瘡鍑绘潃 5 鍙啀 +10锛堟棤涓婇檺锛?)
	_shiny_present("undying")

# ============================================================
# 绾搁涪 路 鍓焊鎴愬叺锛堝彫鍞ょ郴锛屽鐢ㄦ牳蹇冪殑鍙敜鐗╃郴缁燂級
#   绾镐汉锛氱户鎵夸富瑙掓敾鍑?15%锛堟牳蹇?"paper" 鍒嗘敮锛壜?浼氭尐鎵?路 浼氬娈?# ============================================================
var _qianzhi := false

func _cast_paper() -> void:
	var m: Dictionary = _anc_mod.get("zhiyuan", {})
	var n := 2 + int(m.get("paper_add", 0.0))
	if _qianzhi:
		n += 0
	var secs := 8.0 + float(m.get("life_flat", 0.0))
	var life_m := secs / 30.0          # cn_life() 鍩哄噯 30 绉?	for i in n:
		_core.summon_minion("绾镐汉", Color(0.95, 0.93, 0.86), 0.72, 0.5, life_m, 1.0, 0.0, 99, "", "paper")
	_toast("鍓焊鎴愬叺 路 鍙?%d 寮犵焊浜猴紙瀛樺湪 %d 绉掞級" % [n, int(secs)])
	Aud.sfx("paper", -8.0)

func _enable_qianzhi() -> void:
	_qianzhi = true
	_toast("鍗冪焊鍏ュ崱缁?路 绾镐汉鍑绘潃浼氬娈栵紝娑堝け鏃跺垎瑁?2 涓皬绾镐汉")
	_shiny_present("qianzhi")

# ============================================================
# 闄堢煶 路 鐭崇毊锛堢函琚姩锛屼笉杩涙妧鑳芥爮锛?#   姣?X 绉?+N 灞傦紙鏃犱笂闄愶級路 姣忓眰闃插尽 +2/+3 路 鎸ㄦ墦鎺?1 灞傚苟鍙嶆墜鐪熷疄浼ゅ锛堥槻寰∶?.5锛?#   5鈽?绱鑴?10 灞?鈫?纰庤锛堣寖鍥寸湡瀹炰激瀹筹級
#   鐐崱鐭虫畳锛氭湁鐨椂 25% 鍥哄畾鍑忎激 路 鎸ㄦ墦 30% 鍐嶆定涓€灞?# ============================================================
var _shixi := false
var _stone_layers := 0
var _stone_acc := 0.0
var _stone_def := 0.0
var _stone_red_applied := 0.0
var _stone_burst := 0
var _shiyun := false

func _stone_per_def() -> float:
	var m: Dictionary = _anc_mod.get("chenshi2", {})
	return 3.0 if float(m.get("stone_def", 0.0)) > 0.0 else 2.0

func _apply_stone_def() -> void:
	if _core == null:
		return
	var def_pts := _stone_def + float(_stone_layers) * _stone_per_def()
	# v6锛氫笉鍐嶈蛋 hero.def 鏁板€煎噺浼わ紱1 鐐归槻寰?= 3% 鍥哄畾鍑忓厤锛岀煶闊靛啀鍔?25%
	var red := def_pts * 0.03 + (0.25 if (_shiyun and _stone_layers > 0) else 0.0)
	var delta := red - _stone_red_applied
	if absf(delta) > 0.0001:
		for t in _core.DMG_TYPES:
			if t != "鐪熷疄":
				_core.type_add(t, "red_f", delta)
		_stone_red_applied = red

func _tick_stone(dt: float) -> void:
	if not _shixi or _core == null:
		return
	var m: Dictionary = _anc_mod.get("chenshi2", {})
	var interval := float(m.get("stone_rate", 3.0))
	if interval <= 0.0:
		interval = 3.0
	var add := int(m.get("stone_add", 1.0))
	if add < 1:
		add = 1
	_stone_acc += dt
	while _stone_acc >= interval:
		_stone_acc -= interval
		_stone_layers += add
	_apply_stone_def()

func _stone_on_hit() -> void:
	if not _shixi or _core == null:
		return
	if _stone_layers > 0:
		_stone_layers -= 1
		_stone_burst += 1
		_apply_stone_def()
		var dmg := float(_core.hero.get("def", 0.0)) * 0.5
		var foes := _live_foes()
		if not foes.is_empty() and dmg > 0.0:
			_core._apply_dmg(foes[0], dmg, "鐪熷疄")
			_core._push_float(float(foes[0]["x"]), float(foes[0]["y"]) - 40.0, "鐭冲睉", Color(0.80, 0.78, 0.72))
		var need := int((_anc_mod.get("chenshi2", {}) as Dictionary).get("stone_burst", 0.0))
		if need > 0 and _stone_burst >= need:
			_stone_burst = 0
			_stone_shatter()
			_stone_drop_shards()
	if _shiyun and randf() < 0.30:
		_stone_layers += 1
		_apply_stone_def()

# 5鈽?纰庤锛氫竴鍦堢湡瀹炰激瀹?func _stone_shatter() -> void:
	var dmg := float(_core.hero.get("def", 0.0)) * 1.5
	var hp0 := Vector2(_core.hero_pos)
	var hit := 0
	for f_v in _live_foes():
		var f: Dictionary = f_v
		if (Vector2(float(f["x"]), float(f["y"])) - hp0).length() <= 140.0:
			_core._apply_dmg(f, dmg, "鐪熷疄")
			_core._push_float(float(f["x"]), float(f["y"]) - 50.0, "纰庤", Color(0.86, 0.84, 0.76), true)
			hit += 1
	if hit > 0:
		_core.Shake_add(6.0)
	_toast("纰庤锛佷竴鍦堢湡瀹炰激瀹筹紙闃插尽 %d锛? % int(float(_core.hero.get("def", 0.0))))

# ---------------- 鐭虫畳锛堥檲鐭崇偒鍗★級 ----------------
func _enable_shiyun() -> void:
	_shiyun = true
	_apply_stone_def()
	_toast("鐭虫畳鍏ュ崱缁?路 鐭崇毊鍦ㄨ韩 25% 鍑忎激锛屾尐鎵?30% 鍐嶆定涓€灞?)
	_shiny_present("shiyun")

# ============================================================
# 鏀跺熬锛氱焊浜虹垎鏁?/ 鍗冪焊鍒嗚 / 鍦伴潰鐭崇毊
# ============================================================
var _zhiyuan := false
var _shards: Array = []          # {pos, t, r} 鍦颁笂鐨勭煶鐨?var _shard_acc := 0.0

func _enable_zhiyuan() -> void:
	_zhiyuan = true

# 姣忓抚鎵弿鏍稿績鐨勫彫鍞ょ墿锛氱焊浜鸿繘鍏?dying 灏辩垎涓€娆★紙涓嶆敼鏍稿績锛?func _tick_paper(dt: float) -> void:
	if not _zhiyuan or _core == null:
		return
	var m: Dictionary = _anc_mod.get("zhiyuan", {})
	var burst := float(m.get("burst", 0.0)) > 0.0
	for m_v in _core._minions:
		var mm: Dictionary = m_v
		if str(mm.get("kind", "")) != "绾镐汉":
			continue
		if float(mm.get("dying", 0.0)) <= 0.0 or bool(mm.get("_burst_done", false)):
			continue
		mm["_burst_done"] = true
		var at: Vector2 = mm["pos"]
		if burst:
			var dmg := float(_core.hero.get("atk", 12.0)) * 1.5
			for f_v in _live_foes():
				var f: Dictionary = f_v
				if (Vector2(float(f["x"]), float(f["y"])) - at).length() <= 110.0:
					_core._apply_dmg(f, dmg, "鍙敜")
					_core._push_float(float(f["x"]), float(f["y"]) - 36.0, "鐖嗘暎", Color(0.94, 0.92, 0.86))
			_paper_puff(at)
			Aud.sfx("paper", -10.0)
		if _qianzhi:
			for k in 2:
				_core.summon_minion("灏忕焊浜?, Color(0.98, 0.96, 0.90), 0.5, 0.3, 5.0 / 30.0, 0.9, 0.0, 99, "", "paper")
			_paper_puff(at)
			Aud.sfx("paper", -12.0)

func _paper_puff(at: Vector2) -> void:
	var r := ColorRect.new()
	r.color = Color(0.96, 0.94, 0.88, 0.55)
	r.size = Vector2(30, 30)
	r.position = _core.position + at - Vector2(15, 15)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 8
	add_child(r)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "size", Vector2(150, 150), 0.35)
	tw.tween_property(r, "position", _core.position + at - Vector2(75, 75), 0.35)
	tw.tween_property(r, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(func() -> void: r.queue_free())

func _stone_drop_shards() -> void:
	var m: Dictionary = _anc_mod.get("chenshi2", {})
	if float(m.get("shard_drop", 0.0)) <= 0.0:
		return
	var hp0 := Vector2(_core.hero_pos)
	for i in 3:
		var ang := randf() * TAU
		var rad := randf_range(30.0, 120.0)
		_shards.append({"pos": hp0 + Vector2(cos(ang), sin(ang)) * rad, "t": 8.0, "r": 30.0})

func _tick_shards(dt: float) -> void:
	if _core == null:
		return
	var extra_r := 50.0 if _shiyun else 0.0
	_shard_acc += dt
	var tick := _shard_acc >= 1.0
	if tick:
		_shard_acc -= 1.0
	var hp0 := Vector2(_core.hero_pos)
	for s_v in _shards:
		var s: Dictionary = s_v
		s["t"] = float(s["t"]) - dt
		var sp: Vector2 = s["pos"]
		if _shixi and hp0.distance_to(sp) <= 40.0:
			s["t"] = 0.0
			_stone_layers += 1
			_apply_stone_def()
			_core._push_float(sp.x, sp.y - 30.0, "鐭崇毊 +1", Color(0.84, 0.82, 0.74))
			continue
		if _shiyun and tick:
			for f_v in _live_foes():
				var f: Dictionary = f_v
				if (Vector2(float(f["x"]), float(f["y"])) - sp).length() <= float(s["r"]) + extra_r:
					var dmg := float(_core.hero.get("def", 0.0)) * 0.2
					if dmg > 0.0:
						_core._apply_dmg(f, dmg, "鐪熷疄")
						_core._push_float(float(f["x"]), float(f["y"]) - 26.0, "鐮?, Color(0.80, 0.78, 0.70))
	for i in range(_shards.size() - 1, -1, -1):
		if float((_shards[i] as Dictionary)["t"]) <= 0.0:
			_shards.remove_at(i)

# ============================================================
# 缇?/ 闄?涓ょ郴锛氭妸鍗＄墝鍔犳垚鎺ㄧ粰鏍稿績锛堟瘡娉㈠畾棰?+ 鍏ㄥ眬闅惧害锛?# ============================================================
func _push_run_mods() -> void:
	if _core == null:
		return
	_core.wave_extra = _wave_extra
	_core.extra_diff_mul = 1.0 + _diff_pct / 100.0
	if _core.has_method("wave_reset_quota"):
		_core.wave_reset_quota()
	pass

# ============================================================
# 闄╃郴锛氭€墿绫诲瀷锛堟枃閽辨€?/ 鐏垫櫠鎬級+ 瀹濈墿路棣栭濂栧姳鍔犳垚
#   棰濆鍒峰嚭鏉ョ殑鎬墦 rtype 鏍囩锛涘彧鍦ㄦ牳蹇冪‘璁ゆ浜℃椂缁撶畻銆?# ============================================================
func _spawn_typed_foes() -> void:
	if _core == null:
		return
	for i in _coin_count_extra:
		_core._spawn_foe("normal")
		_tag_last("coin")
	for i in _crystal_count_extra:
		_core._spawn_foe("normal")
		_tag_last("crystal")

func _tag_last(rt: String) -> void:
	if _core.foes.is_empty():
		return
	var f: Dictionary = _core.foes[_core.foes.size() - 1]
	f["rtype"] = rt

func _on_foe_defeated(foe: Dictionary) -> void:
	if _run_over or _core == null or not _core.foes.has(foe) or not bool(foe.get("_death_settled", false)) or bool(foe.get("_rtype_rewarded", false)):
		return
	# 鍦ㄥ彂鏀惧墠璁拌处锛岄伩鍏嶅鍔?鍑绘潃淇″彿閲嶅叆閲嶅鍙戞斁锛涗笉渚濊禆瑙嗚_tid鎴栧案浣撴秷澶便€?	foe["_rtype_rewarded"] = true
	_grant_rtype(str(foe.get("rtype", "")))

func _grant_rtype(rt: String) -> void:
	match rt:
		"coin":
			_add_wen(int(20.0 * (1.0 + _treasure_pct / 100.0)))
		"crystal":
			_gain_crystal(int(round(2.0 * (1.0 + _treasure_pct / 100.0))))
		"boss":
			_add_wen(int(200.0 * (1.0 + _boss_pct / 100.0)))
			_gain_crystal(int(round(20.0 * (1.0 + _boss_pct / 100.0))))

# ============================================================
# 閲嶅埄锛堢粡娴庣郴鐐崱锛夛細鍚堟垚缁忔祹绯?3% 鍑?#   鎶藉崱閫変腑涓€寮?鈫?姣忓紶閲嶅埄鎺?10% 鈫?涓簡澶嶅埗涓€寮狅紙褰撳満鍚炲櫖銆佷繚鐣欐晥鏋滐級
#   澶嶅埗浣撳啀鐙珛鎺?鈫?閾惧紡
# ============================================================
var _zhongli_count := 0
var _zhongli_rolled := false

func _enable_zhongli() -> void:
	_zhongli_count += 1
	_toast("閲嶅埄鍏ュ崱缁?路 鎶藉崱閫変腑鏃舵湁 %d 娆?10%% 澶嶅埗鏈轰細" % _zhongli_count)
	_shiny_present("zhongli")

func _zhongli_try(id: String) -> void:
	if _run_over or _zhongli_count <= 0:
		return
	var queue: Array = []
	for i in _zhongli_count:
		queue.append(id)
	var guard := 0
	var hits := 0
	while not queue.is_empty() and guard < 12:
		guard += 1
		var cid := str(queue.pop_front())
		if randf() < 0.10:
			hits += 1
			_grant_copy(cid)
			queue.append(cid)          # 澶嶅埗浣撳啀鐙珛鎺?	if hits > 0:
		_toast("閲嶅埄 路 澶嶅埗浜?%d 寮狅紙鍏ㄩ儴鍚炲櫖锛屾晥鏋滀繚鐣欙級" % hits)

# 澶嶅埗浣擄細涓嶈繘鍗＄粍鏍硷紝褰撳満鍚炲櫖锛屼絾鏁堟灉/杩涘害淇濈暀
func _grant_copy(id: String) -> void:
	if _run_over:
		return
	var c: Dictionary = _card_db.get(id, {})
	if c.is_empty():
		return
	if c.has("ancestor"):
		_cards.append(id)
		_check_sets()
		_cards.erase(id)
		_refresh_deck()
	else:
		var own := {"atk": 0.0, "def": 0.0, "hp": 0.0, "mp": 0.0, "gold_pct": 0.0, "crystal_pct": 0.0,
			"count": 0.0, "coin_count": 0.0, "crystal_count": 0.0, "treasure_pct": 0.0, "boss_pct": 0.0}
		var k := str(c.get("own_key", ""))
		if own.has(k):
			own[k] = float(c.get("own_val", 0))
			_apply_own(own)
	_core._push_float(_core.hero_pos.x, _core.hero_pos.y - 80.0, "澶嶅埗 路 " + str(c.get("name", "")), Color(0.96, 0.88, 0.55), true)

# ============================================================
# 璐紙缁忔祹绾匡級锛氶殢鏈哄悶鍣崱缁勭殑鍗?鈥斺€?鏁堟灉涓庤繘搴﹂兘淇濈暀
# ============================================================
var _devouring := false

func _devour_keep(n: int) -> void:
	if _devouring:
		return
	_devouring = true
	if _cards.is_empty():
		_devouring = false
		return
	for i in n:
		if _cards.is_empty():
			break
		var pick := str(_cards[randi() % _cards.size()])
		_cards.erase(pick)
		var c: Dictionary = _card_db.get(pick, {})
		if c.has("ancestor"):
			_virtual_cards.append(pick)
		_toast("璐?路 鍚炲櫖銆?s銆嶏紙鏁堟灉淇濈暀锛? % str(c.get("name", "")))
	_refresh_deck()
	_devouring = false


# ============================================================
# 濂囬亣锛氱┖妲芥寜Q_TICK闂撮殧鎺蜂竴鏉★紱**琛€鏉℃涓嬫柟閭ｄ竴鏉″氨鏄叆鍙?*
#   鎺峰埌 鈫?閭ｄ竴鏉℃樉绀恒€岀偣寮€鐪嬭鎯呫€嶁啋 鐐瑰紑寮规锛绘帴鍙楋冀锛绘斁寮冿冀
#   鎺ュ彈鍚庢墠寮€濮嬭鏃?/ 甯冪疆鎴樺満锛?*鎴樻枟涓€斾笉鑳芥斁寮?*
#   寰呮帴鎴栬繘琛屼腑涓嶅偍瀛樹笅涓€鏉★紝缁撴潫/鏀惧純鍚庨噸鏂拌鏃躲€?# ============================================================
const Q_TICK := 180.0             # 濂囬亣姣?180 绉掍竴娆★紙鏃х増 75s锛屾寜鏂拌妭濂忔媺闀匡級
const Q_TIER_CN := ["绠€鍗?, "鏅€?, "鍥伴毦", "鐗规畩"]
const Q_TIER_W := [[45.0, 55.0, 0.0, 0.0], [20.0, 50.0, 30.0, 0.0], [10.0, 35.0, 40.0, 15.0]]
const Q_TIER_COL := [Color(0.40, 0.46, 0.34), Color(0.40, 0.36, 0.24), Color(0.52, 0.30, 0.16), Color(0.52, 0.18, 0.16)]

const QUEST_POOL := [
	{"id": "tu", "n": "灞犲満", "tier": 0, "kind": "count", "key": "kill", "need": 40, "lim": 60.0, "desc": "鏉€ 40 鍙?, "r": {"crystal": 25}},
	{"id": "can", "n": "鍙傛偀", "tier": 0, "kind": "count", "key": "draw", "need": 3, "lim": 0.0, "desc": "鎶?3 寮犲崱", "r": {"crystal": 25}},
	{"id": "xb", "n": "瀵诲疂", "tier": 0, "kind": "count", "key": "trea", "need": 1, "lim": 0.0, "desc": "鎷?1 浠跺疂鐗?, "r": {"crystal": 25, "trea_rr": 1}},
	{"id": "sl", "n": "璇曠偧", "tier": 0, "kind": "count", "key": "chal", "need": 2, "lim": 0.0, "desc": "瀹屾垚 2 娆℃寫鎴?, "r": {"crystal": 30}},
	{"id": "ch", "n": "娣伀", "tier": 0, "kind": "count", "key": "str", "need": 5, "lim": 0.0, "desc": "寮哄寲鑷韩 5 娆?, "r": {"crystal": 25}},
	{"id": "qs", "n": "璇风", "tier": 0, "kind": "count", "key": "god", "need": 1, "lim": 0.0, "desc": "璇?1 浣嶇瀹?, "r": {"crystal": 30}},
	{"id": "yx", "n": "澶滃贰", "tier": 0, "kind": "survive", "need": 0, "lim": 60.0, "desc": "鎾戣繃 60 绉掍笉鍊?, "r": {"crystal": 30}},

	{"id": "pz", "n": "鐮撮樀", "tier": 1, "kind": "statue", "need": 3, "lim": 60.0, "desc": "鎵撶 3 搴х煶鍍?, "r": {"crystal": 60}},
	{"id": "sg", "n": "鍗囨牸", "tier": 1, "kind": "count", "key": "lv", "need": 2, "lim": 0.0, "desc": "杩炲崌 2 绾?, "r": {"crystal": 50, "aug_rr": 1}},
	{"id": "ky", "n": "鑻﹀焦", "tier": 1, "kind": "restrain", "key": "chal", "lim": 30.0, "desc": "30 绉掑唴涓嶇敤鎸戞垬", "r": {"crystal": 50}},
	{"id": "qdf", "n": "娓呴亾澶?, "tier": 1, "kind": "count", "key": "clearwave", "need": 1, "lim": 0.0, "desc": "涓€娉㈢粨鏉熸椂鍦轰笂鏃犳€?, "r": {"crystal": 50, "trea_rr": 1}},

	{"id": "sh", "n": "瀹堟姢", "tier": 2, "kind": "guard", "need": 0, "lim": 60.0, "desc": "鐗㈣溅涓嶇", "r": {"crystal": 100, "trea_rr": 2}},
	{"id": "zd", "n": "鍗犵偣", "tier": 2, "kind": "zone", "need": 12, "lim": 45.0, "desc": "绔欎綇娉曢樀 12 绉?, "r": {"crystal": 90, "aug_rr": 2}},
	{"id": "bs", "n": "涓嶆潃", "tier": 2, "kind": "restrain", "key": "kill", "lim": 30.0, "desc": "30 绉掑唴涓嶅嚮鏉€", "r": {"crystal": 90}},
	{"id": "xj", "n": "鐚キ", "tier": 2, "kind": "survive", "need": 0, "lim": 60.0, "desc": "鎵?20% 姘旇锛屾椿杩?60 绉?, "r": {"crystal": 130}},

	{"id": "dt", "n": "鍗曟寫", "tier": 3, "kind": "champion", "need": 0, "lim": 90.0, "desc": "鎵撴鎷﹁矾楂樻墜", "r": {"crystal": 180, "trea": 1}},
	{"id": "sy", "n": "涓夎嫳", "tier": 3, "kind": "elite", "need": 3, "lim": 120.0, "desc": "鏉€鎺?3 鍙簿鑻?, "r": {"crystal": 200, "trea": 1}},
	{"id": "dj", "n": "璧屽眬", "tier": 3, "kind": "instant", "need": 0, "lim": 0.0, "desc": "鎶?100 鏂囷紝50% 姒傜巼涓", "r": {"wen": 400}},
]

var _q_offer: Dictionary = {}     # 鎺峰埌銆佺瓑鐜╁鐐瑰紑鐪嬬殑閭ｄ竴鏉?var _q_cur: Dictionary = {}       # 宸叉帴鍙椼€佹鍦ㄥ仛鐨勯偅涓€鏉★紙鍚屾椂鍙湁涓€鏉★級
var _q_t := 0.0
var _q_done := 0
var _q_giveup := 0
var _q_fail := 0
var _q_stats: Dictionary = {}
var _q_layer: Control = null
var _q_bar: Panel = null
var _q_lb: Label = null
var _q_hit: Button = null
var _q_pop: Control = null
var _q_orb: QuestOrb = null
var _q_orb_lb: Label = null
var _q_pulse: Tween = null
var _q_ai_t := 0.0

func _q_init() -> void:
	_q_layer = Control.new()
	_q_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_q_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_q_layer.z_index = 9
	add_child(_q_layer)
	# 涓昏琛€鏉℃涓嬫柟锛氳繖涓€鏉℃湰韬氨鏄叆鍙?	_q_bar = _panel(Rect2(96, 138, 528, 34), Color(0.10, 0.09, 0.08, 0.92), 6, Color(0.85, 0.66, 0.23, 0.75), 2, _q_layer)
	_q_lb = _lbl("", Vector2(110, 145), Vector2(500, 22), 15, Color(0.95, 0.90, 0.80), _q_layer)
	_q_hit = Button.new()
	_q_hit.position = Vector2(96, 138)
	_q_hit.size = Vector2(528, 34)
	_q_hit.flat = true
	_q_hit.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed"]:
		_q_hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_q_hit.pressed.connect(_q_open_popup)
	_q_layer.add_child(_q_hit)
	_q_bar.visible = false
	_q_lb.visible = false
	_q_hit.visible = false
	# 寰呮帴鍙楋細涓昏宸︿晶鐨勫渾閽?+ 澶х孩瀛椼€屽閬囷紒銆?	_q_orb = QuestOrb.new()
	_q_orb.position = Vector2(196, 706)
	_q_orb.size = Vector2(92, 92)
	_q_orb.visible = false
	_q_orb.pressed.connect(_q_open_popup)
	_q_layer.add_child(_q_orb)
	_q_orb_lb = _lbl("濂囬亣锛?, Vector2(132, 644), Vector2(220, 56), 40, Color(0.82, 0.16, 0.10), _q_layer, HORIZONTAL_ALIGNMENT_CENTER)
	_q_orb_lb.visible = false

func _q_refresh() -> void:
	var has_cur := not _q_cur.is_empty()
	var has_offer := (not _q_offer.is_empty()) and _q_cur.is_empty()
	# 杩涜涓細琛€鏉′笅闈㈤偅涓€鏉★紙涓嶅啓鎻愮ず锛岀帺瀹惰嚜宸辩偣浼氬嚭璇︽儏锛?	_q_bar.visible = has_cur
	_q_lb.visible = has_cur
	_q_hit.visible = has_cur
	# 寰呮帴鍙楋細涓昏宸︿晶鐨勫渾閽?+ 澶х孩瀛?	if _q_orb != null:
		_q_orb.visible = has_offer
	if _q_orb_lb != null:
		_q_orb_lb.visible = has_offer
	_q_set_pulse(has_offer)
	if not has_cur:
		return
	var q: Dictionary = _q_cur
	var s := "銆?s銆?s" % [str(q["n"]), str(q["desc"])]
	if int(q.get("need", 0)) > 0:
		s += "  %d/%d" % [int(q.get("prog", 0)), int(q["need"])]
	if float(q.get("lim", 0.0)) > 0.0:
		s += "  路  %.0f 绉? % ceil(float(q["t"]))
	_q_lb.text = s
	_q_bar.add_theme_stylebox_override("panel", _q_style(Color(0.30, 0.24, 0.12), 2))

# 銆屽閬囷紒銆嶅懠鍚革細缂╂斁 + 鍗婇€忔槑鏉ュ洖锛屽彧鍦ㄦ湁濂囬亣寰呮帴鏃惰窇
func _q_set_pulse(on: bool) -> void:
	if _q_orb_lb == null:
		return
	if on:
		if _q_pulse != null and _q_pulse.is_valid():
			return
		_q_orb_lb.pivot_offset = _q_orb_lb.size * 0.5
		_q_orb_lb.scale = Vector2.ONE
		_q_orb_lb.modulate = Color(1, 1, 1, 1)
		_q_pulse = create_tween().set_loops()
		_q_pulse.tween_property(_q_orb_lb, "scale", Vector2(1.12, 1.12), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_q_pulse.parallel().tween_property(_q_orb_lb, "modulate:a", 0.70, 0.5)
		_q_pulse.tween_property(_q_orb_lb, "scale", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_q_pulse.parallel().tween_property(_q_orb_lb, "modulate:a", 1.0, 0.5)
	else:
		if _q_pulse != null:
			_q_pulse.kill()
			_q_pulse = null
		_q_orb_lb.scale = Vector2.ONE
		_q_orb_lb.modulate = Color(1, 1, 1, 1)

# 寮圭獥缁熶竴鎵嬫劅锛氬厛銆屽脊杩涙潵銆嶏紝鍐嶈交杞诲懠鍚?func _pop_bounce(c: Control, delay := 0.0) -> void:
	if c == null:
		return
	MenuUI.Motion.pop(c, false, delay)

func _breathe(c: Control) -> void:
	if c == null:
		return
	MenuUI.Motion.breathe(c)

func _q_style(border: Color, w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.08, 0.92)
	sb.set_corner_radius_all(6)
	sb.border_color = border
	sb.set_border_width_all(w)
	return sb

func _q_close_popup() -> void:
	if _q_pop != null:
		_q_pop.queue_free()
		_q_pop = null

# 鐐归偅涓€鏉★細寮硅鎯咃紙鎺峰埌鐨勶細鎺ュ彈/鏀惧純锛涘凡鎺ュ彈锛氬彧鐪嬶級
func _q_open_popup() -> void:
	if not _q_can_act():
		return
	_q_close_popup()
	var is_offer := _q_cur.is_empty() and not _q_offer.is_empty()
	var q: Dictionary = _q_offer if is_offer else _q_cur
	if q.is_empty():
		return
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 34
	add_child(layer)
	_q_pop = layer
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	# 鍐呭瑁呰繘 holder锛氭暣浣撳脊鍏?+ 鍛煎惛
	var holder := Control.new()
	holder.position = Vector2(120, 330)
	holder.size = Vector2(480, 470)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	_panel(Rect2(0, 0, 480, 470), Color(0.97, 0.93, 0.85, 0.99), 10, Color(0.85, 0.66, 0.23), 3, holder)
	_lbl(str(q["n"]), Vector2(30, 18), Vector2(220, 44), 32, INK, holder)
	var tier := clampi(int(q.get("tier", 0)), 0, 3)
	_panel(Rect2(280, 26, 120, 26), Q_TIER_COL[tier], 4, Q_TIER_COL[tier], 0, holder)
	_lbl("濂囬亣 路 " + str(Q_TIER_CN[tier]), Vector2(280, 28), Vector2(120, 22), 14, Color(0.99, 0.95, 0.87), holder, HORIZONTAL_ALIGNMENT_CENTER)
	var r := _q_rewards(q)
	var rw := "鐏垫櫠 " + str(int(r["crystal"])) if r.has("crystal") else ""
	if r.has("wen"):
		rw += (" 路 " if not rw.is_empty() else "") + "鏂囬挶 " + str(int(r["wen"]))
	if r.has("trea_rr"):
		rw += " 路 瀹濈墿鍒锋柊 " + str(int(r["trea_rr"]))
	if r.has("aug_rr"):
		rw += " 路 杩涢樁鍒锋柊 " + str(int(r["aug_rr"]))
	if r.has("trea"):
		rw += " 路 瀹濈墿鏈轰細 " + str(int(r["trea"]))
	var rows := [
		["鏉′欢", str(q["desc"])],
		["闄愭椂", "鎺ュ彈鍚庣珛鍗崇粨绠? if str(q.get("kind", "")) == "instant" else (("%d 绉掞紙鎺ュ彈鍚庢墠寮€濮嬬畻锛? % int(q["lim"])) if float(q.get("lim", 0.0)) > 0.0 else "涓嶉檺鏃?)],
		["濂栧姳", rw],
		["澶辫触", "鏈腑濂栧垯鎹熷け 100 鏂囨娂閲? if str(q.get("id", "")) == "dj" else "瓒呮椂鑷姩娑堝け锛屼笉缁欎笢瑗?],
	]
	var y := 90.0
	for row in rows:
		_lbl(str(row[0]), Vector2(32, y), Vector2(70, 22), 14, Color(0.47, 0.41, 0.33), holder)
		_lbl(str(row[1]), Vector2(92, y - 3), Vector2(340, 26), 18, INK, holder)
		y += 50.0
	if is_offer:
		_btn("鎺?鍙?, Rect2(32, 370, 180, 62), 26, Color(0.85, 0.66, 0.23), Color(0.13, 0.10, 0.06),
			func() -> void:
				if _q_pop == layer and is_same(_q_offer, q): _q_accept(), holder)
		_btn("鏀?寮?, Rect2(268, 370, 180, 62), 26, Color(0.93, 0.89, 0.80), Color(0.35, 0.28, 0.18),
			func() -> void:
				if _q_pop == layer and is_same(_q_offer, q): _q_decline(), holder)
	else:
		_btn("鍏?闂?, Rect2(150, 370, 180, 62), 26, Color(0.93, 0.89, 0.80), Color(0.35, 0.28, 0.18),
			func() -> void:
				if _q_pop == layer: _q_close_popup(), holder)
		_lbl("鎺ヤ簡灏卞緱鎵撳畬 路 涓€斾笉鑳芥斁寮?, Vector2(30, 342), Vector2(420, 22), 14, Color(0.62, 0.20, 0.14), holder, HORIZONTAL_ALIGNMENT_CENTER)
	_pop_bounce(holder)
	_breathe(holder)

func _q_can_act() -> bool:
	return not _run_over and _core != null and _core.running and float(_core.hero.get("hp", 0.0)) > 0.0

func _q_accept() -> void:
	if not _q_can_act() or not _q_cur.is_empty() or _q_offer.is_empty():
		return
	if str(_q_offer.get("id", "")) == "dj" and _wen < 100:
		_toast("璧屽眬 路 闇€瑕?100 鏂囷紝褰撳墠涓嶈冻")
		return
	var q: Dictionary = _q_offer
	_q_offer = {}
	_q_close_popup()
	_spawn_pfx("arcane/rune-circle", _hero_screen(), 1.0, "arcane", 1.4)
	Aud.sfx("ui_open", -10.0, 1.05)
	_q_activate(q)

func _q_decline() -> void:
	if not _q_can_act() or _q_offer.is_empty():
		return
	_q_giveup += 1
	_q_offer = {}
	_q_t = 0.0
	_q_close_popup()
	_q_refresh()

# 濂囬亣灏介噺涓嶅嚭澹版槑锛氳繖閲岀暀绌猴紙濂栧姳鑷繁鐪嬫暟瀛楀彉鍖栵級
func _q_notify(_text: String) -> void:
	pass

func _q_finish(why: String) -> void:
	if not _q_can_act() or _q_cur.is_empty():
		return
	var q: Dictionary = _q_cur
	_q_cur = {} # 鍏堝叧闂粨绠楀叆鍙ｏ紝濂栧姳/娓呯悊鍥炶皟涓嶈兘鍐嶆瀹屾垚鍚屼竴濂囬亣銆?	_q_close_popup()
	_q_t = 0.0
	_q_cleanup(q)
	match why:
		"done":
			_q_done += 1
			_q_reward(q)
			_spawn_pfx("holy/feather-burst", _hero_screen(), 1.0, "gold", 1.7)
			_spawn_pfx("holy/sunburst", _hero_screen(), 0.9, "gold", 1.9)
			_screen_flash(Color(1.0, 0.92, 0.62), 0.10, 0.22)
			_core._shake = maxf(float(_core._shake), 4.0)
			_cam_pulse(1.05, 0.42)
			if _curio_id == "zhenhunling" and _curio_lv >= 5 and _roll_bell_treasure():
				if not _grant_random_treasure():
					_toast("闀囬瓊閾?路 鏆傛棤鍙彂鏀剧殑瀹濈墿")
			_q_notify("濂囬亣瀹屾垚 路 %s" % str(q["n"]))
			Aud.sfx("levelup", -6.0)
			Aud.sfx("bell", -8.0, 1.05)
		"fail":
			_q_fail += 1
			_screen_flash(Color(0.72, 0.28, 0.22), 0.10, 0.22)
			_spawn_pfx("impacts/blunt-hit", _hero_screen() + Vector2(0, -20), 0.9, "blood", 1.2)
			_cam_pulse(1.03, 0.22)
			Aud.sfx("ui_close", -8.0, 0.9)
			_q_notify("濂囬亣澶辫触 路 %s" % str(q["n"]))
	_q_refresh()

func _roll_bell_treasure() -> bool:
	return randf() < 0.30

func _q_cleanup(q: Dictionary) -> void:
	if _core == null or q.is_empty():
		return
	match str(q.get("kind", "")):
		"statue":
			_core.clear_statues()
		"zone":
			_core.clear_zone()
		"guard":
			_core.clear_guard()
		"champion":
			_core.clear_champion()
		"elite":
			_core.clear_elite()

func _q_rewards(q: Dictionary) -> Dictionary:
	var r: Dictionary = q.get("r", {}).duplicate(true)
	var boost := 1.0
	if _curio_id == "zhenhunling" and _curio_lv >= 2:
		boost = 1.3
	for key in r:
		r[key] = int(round(float(r[key]) * boost))
	return r

func _q_reward(q: Dictionary) -> void:
	var r := _q_rewards(q)
	if r.has("crystal"):
		_gain_crystal(int(r["crystal"]))
	if r.has("wen"):
		var before := _wen
		_add_wen(int(r["wen"]))
		q["_awarded_wen"] = _wen - before
	if r.has("trea_rr"):
		_trea_reroll += int(r["trea_rr"])
	if r.has("aug_rr"):
		_aug_reroll += int(r["aug_rr"])
	if r.has("trea"):
		_trea_charge += int(r["trea"])
	_refresh_trea_tile()

func _q_fail_kind(kind: String) -> void:
	if not _q_cur.is_empty() and str(_q_cur.get("kind", "")) == kind:
		_q_finish("fail")

func _q_done_kind(kind: String) -> void:
	if not _q_cur.is_empty() and str(_q_cur.get("kind", "")) == kind:
		_q_finish("done")

# 鍗曟Ы锛氬緟鎺ユ垨杩涜涓椂涓嶆幏涓嬩竴鏉★紝涓嶇Н鏀掗殣钘忛槦鍒椼€?func _q_roll() -> void:
	if not _q_can_act() or not _q_cur.is_empty() or not _q_offer.is_empty():
		return
	var wave := int(_core.wave)
	var tw: Array = Q_TIER_W[0] if wave <= 2 else (Q_TIER_W[1] if wave == 3 else Q_TIER_W[2])
	if LevelState.current_level == 4:
		tw = [5.0, 25.0, 45.0, 25.0]   # 绗洓鍏冲閬囷細鍥伴毦鍜岀壒娈婃潈閲嶆姮楂?	var roll := randf() * 100.0
	var tier := 0
	var acc := 0.0
	for i in tw.size():
		acc += float(tw[i])
		if roll <= acc:
			tier = i
			break
	var cand: Array = []
	for e_v in QUEST_POOL:
		var e: Dictionary = e_v
		if int(e["tier"]) != tier:
			continue
		if not _q_cur.is_empty() and str(_q_cur["id"]) == str(e["id"]):
			continue
		if not _q_offer.is_empty() and str(_q_offer["id"]) == str(e["id"]):
			continue
		cand.append(e)
	if cand.is_empty():
		return
	var pick := _q_prepare(cand[randi() % cand.size()])
	_q_offer = pick
	_q_refresh()

# 鎺ュ彈鍚庯細甯冪疆鎴樺満 + 鍊掕鏃朵粠杩欓噷鎵嶅紑濮?func _q_prepare(source: Dictionary) -> Dictionary:
	var q := source.duplicate(true)
	if bool(q.get("_prepared", false)):
		return q
	q["_prepared"] = true
	if _curio_id != "zhenhunling" or _curio_lv < 3:
		return q
	var need := int(q.get("need", 0))
	if need > 0:
		var reduced := maxi(1, int(round(need * 0.8)))
		q["need"] = reduced
		q["desc"] = str(q.get("desc", "")).replace(str(need), str(reduced))
	elif str(q.get("kind", "")) in ["survive", "restrain", "guard"]:
		var limit := float(q.get("lim", 0.0))
		q["lim"] = limit * 0.8
		q["desc"] = str(q.get("desc", "")).replace(str(int(limit)), str(int(q["lim"])))
	return q

func _q_activate(q: Dictionary) -> void:
	if not _q_can_act() or not _q_cur.is_empty():
		return
	q = _q_prepare(q)
	q["prog"] = 0
	q["t"] = float(q.get("lim", 0.0))
	q["mark"] = int(_q_stats.get(str(q.get("key", "")), 0))
	match str(q.get("kind", "")):
		"statue":
			_core.spawn_statues(int(q["need"]))
		"zone":
			_core.spawn_zone(150.0, float(q["need"]))
		"guard":
			_core.spawn_guard()
		"champion":
			_core.spawn_champion()
		"elite":
			_core.spawn_elite(int(q["need"]))
		"survive":
			if str(q["id"]) == "xj":
				var h: Dictionary = _core.hero
				var hp := float(h.get("hp", 0.0))
				h["hp"] = minf(hp, maxf(1.0, hp * 0.8)) # 鎵ｈ涓嶈嚧姝伙紝涔熶笉鑳芥妸涓嶈冻1琛€鐨勮鑹叉不鐤楀埌1銆?		"instant":
			if str(q.get("id", "")) == "dj" and _wen < 100:
				_toast("璧屽眬 路 闇€瑕?100 鏂囷紝褰撳墠涓嶈冻")
				return
			_q_cur = q
			_q_instant(q)
			_q_refresh()
			return
	_q_cur = q
	_q_refresh()
	Aud.sfx("ui_open", -10.0)

func _q_instant(q: Dictionary) -> void:
	if not _q_can_act() or not is_same(_q_cur, q) or str(q.get("id", "")) != "dj" or _wen < 100:
		return
	_wen -= 100
	if _coin_lb != null:
		_coin_lb.text = str(_wen)
	_refresh_str_tile()
	if _roll_quest_gamble():
		_q_finish("done")
		_toast("璧屽眬 路 鑾峰緱 %d 鏂囷紝宸蹭粯 100 鏂囨娂閲? % int(q.get("_awarded_wen", 0)))
	else:
		_q_finish("fail")
		_toast("璧屽眬 路 鏈腑濂栵紝鎹熷け 100 鏂囨娂閲?)

func _roll_quest_gamble() -> bool:
	return randf() < 0.5

func _qc(key: String, n: int) -> void:
	if n <= 0:
		return
	_q_stats[key] = int(_q_stats.get(key, 0)) + n
	if _q_cur.is_empty():
		return
	if str(_q_cur.get("kind", "")) != "count" or str(_q_cur.get("key", "")) != key:
		return
	_q_cur["prog"] = int(_q_cur.get("prog", 0)) + n
	if int(_q_cur["prog"]) >= int(_q_cur["need"]):
		_q_finish("done")

func _q_check(q: Dictionary) -> void:
	if _core == null or q.is_empty():
		return
	match str(q.get("kind", "")):
		"statue":
			q["prog"] = int(q["need"]) - _core.statues_left()
		"zone":
			q["prog"] = int(_core.zone_prog())
		"elite":
			var alive := 0
			for f_v in _core.foes:
				if str((f_v as Dictionary).get("kind", "")) == "elite" and float(f_v.get("hp", 0.0)) > 0.0 and float(f_v.get("dying", 0.0)) <= 0.0:
					alive += 1
			q["prog"] = int(q["need"]) - alive

func _q_tick(dt: float) -> void:
	if not _q_can_act():
		return
	# 璁捐绋匡細濂囬亣鏄 4 鍏虫墠瑙ｉ攣鐨勬柊鍔熻兘锛堢粺涓€璧拌В閿佽〃锛?	if not LevelState.has_feature("encounter"):
		return
	if _q_cur.is_empty() and _q_offer.is_empty():
		_q_t += dt
		if _q_t >= _q_interval():
			_q_t = 0.0
			_q_roll()
	else:
		_q_t = 0.0
	if _q_cur.is_empty():
		return
	var q: Dictionary = _q_cur
	_q_check(q)
	if int(q.get("need", 0)) > 0 and int(q.get("prog", 0)) >= int(q["need"]):
		_q_finish("done")
		return
	if str(q.get("kind", "")) == "restrain":
		if int(_q_stats.get(str(q.get("key", "")), 0)) != int(q.get("mark", 0)):
			_q_finish("fail")
			return
	if float(q.get("lim", 0.0)) > 0.0:
		q["t"] = float(q["t"]) - dt
		if float(q["t"]) <= 0.0:
			if str(q["kind"]) in ["survive", "restrain", "guard"]:
				_q_finish("done")
			else:
				_q_finish("fail")
			return
	_q_refresh()
	_q_ai(dt)

func _q_ai(dt: float) -> void:
	if not _q_can_act():
		return
	_q_ai_t += dt
	if _q_ai_t < 0.3:
		return
	_q_ai_t = 0.0
	if _run_over or _core == null or _q_cur.is_empty():
		return
	match str(_q_cur.get("kind", "")):
		"statue":
			var target: Dictionary = {}
			for f_v in _core.foes:
				var f: Dictionary = f_v
				if not bool(f.get("still", false)) or float(f.get("dying", 0.0)) > 0.0:
					continue
				if target.is_empty() or _core.hero_pos.distance_to(Vector2(float(f["x"]), float(f["y"]))) < _core.hero_pos.distance_to(Vector2(float(target["x"]), float(target["y"]))):
					target = f
			if not target.is_empty():
				_core.order_focus(target)
				return
		"zone":
			var z: Dictionary = _core.zone
			if not z.is_empty() and float(z.get("prog", 0.0)) < float(z.get("goal", 12.0)):
				_core.order_move(Vector2(float(z["x"]), float(z["y"])))
				return
		"guard":
			var g: Dictionary = _core.guard
			if not g.is_empty():
				var best: Dictionary = {}
				var bd := 1e9
				for f_v2 in _core.foes:
					var f2: Dictionary = f_v2
					if float(f2.get("hp", 0.0)) <= 0.0 or bool(f2.get("still", false)):
						continue
					var dd := Vector2(float(f2["x"]), float(f2["y"])).distance_to(Vector2(float(g["x"]), float(g["y"])))
					if dd < bd:
						bd = dd
						best = f2
				if not best.is_empty():
					_core.order_focus(best)
					return
		"champion":
			for f_v3 in _core.foes:
				var f3: Dictionary = f_v3
				if str(f3.get("kind", "")) == "champion":
					_core.order_focus(f3)
					return
		"elite":
			for f_v4 in _core.foes:
				var f4: Dictionary = f_v4
				if str(f4.get("kind", "")) == "elite":
					_core.order_focus(f4)
					return
	_core.clear_order()

# ============================================================
# 鐐崱鍑哄満瑙嗛锛坅ssets/video/shiny/*.ogv锛孴heora锛?#   鏆楀簳鐨勪袱娈碉紙鍣浄/婊氬北锛夌敤鍔犺壊娣峰悎锛岄粦=閫忔槑
# ============================================================
const SHINY_VIDEO := {
	"devour": "zl",
	"swallow_sea": "cuisanniang",
	"fentian": "jicanghai",
	"backwash": "backwash",
	"jianpo": "zhujue",
	"gunshan": "gundilong",
	"qianzhi": "zhiyuan",
	"wanren": "qingluan",
	"baicao": "liuqingqing",
	"undying": "mingzhu",
	"shiyun": "chenshi2",
	"zhongli": "zhongli",
}
# 鏆楀簳鐨勬锛堝櫖闆?婊氬北锛夛細瀹炴祴鍔犺壊娣峰悎鍦ㄧ焊鑹茶儗鏅笂浼氳鍐茬櫧锛屾敼鎴愭甯告贩鍚堬紝
# 鐩存帴褰撱€岄浄闆?娉ョ煶娴佽繃鍦恒€嶁€斺€旀垬鏂楀凡鍐荤粨锛岄粦搴曞弽鑰屾洿鏈夊帇杩劅銆?const SHINY_VIDEO_ADD: Array = []

var _shiny_video_busy := false

func _play_shiny_video(kind: String) -> bool:
	var key := str(SHINY_VIDEO.get(kind, ""))
	if key == "":
		return false
	var path := "res://assets/video/shiny/shiny_" + key + ".ogv"
	if not ResourceLoader.exists(path):
		return false
	var stream = load(path)
	if stream == null:
		return false
	var v := VideoStreamPlayer.new()
	v.stream = stream
	v.expand = true
	v.position = Vector2.ZERO
	v.size = Vector2(720, 1280)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.z_index = 71
	if SHINY_VIDEO_ADD.has(key):
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		v.material = mat
	add_child(v)
	v.modulate.a = 0.0
	_shiny_video_busy = true
	var was_running := false
	if _core != null:
		was_running = bool(_core.running)
	# ---- 璧锋墜锛氶】甯?+ 鐧介棯 + 闇囧睆锛堝厛璁╂垬鍦烘姈涓€涓嬶紝鍐嶅垏瑙嗛锛?---
	if _core != null:
		_core.Shake_add(13.0)
		_core._hitstop = maxf(float(_core._hitstop), 0.10)
	_flash(Color(1.0, 0.98, 0.90), 0.90, 0.04, 0.20)
	Aud.sfx("drum", -6.0)
	_play_video_after_beat(v, was_running)
	return true

# 鍏堣鎴樺満鎶?0.12 绉掞紙杩欐蹇呴』淇濇寔 running锛屽惁鍒欓渿灞忓仠浣忕湅涓嶅埌锛夛紝鍐嶅喕缁?+ 鎾棰?func _play_video_after_beat(v: VideoStreamPlayer, was_running: bool) -> void:
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(v):
		return
	if _core != null:
		_core.running = false
	v.play()
	var tw := create_tween()
	tw.tween_property(v, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.55)
	tw.tween_property(v, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(v):
			v.stop()
			v.queue_free()
		_shiny_video_busy = false
		if _core != null and was_running:
			_core.running = true)
