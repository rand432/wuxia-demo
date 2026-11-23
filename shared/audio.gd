extends RefCounted

# 离树时先释放播放流，避免退出时混音线程仍持有 Ogg 播放资源。
class ManagedPlayer extends AudioStreamPlayer:
	func _exit_tree() -> void:
		stop()
		stream = null
# ============================================================
# 音频总管 v1：BGM 交叉淡入淡出 ＋ 音效一发
#
#   Audio.play_bgm("bgm_journey")      # 场景 BGM（重复调用同一首不会重头播）
#   Audio.sfx("hit_slash", -6.0)       # 音效（一发即弃）
#   Audio.ui_click()                   # 统一的界面点击音（水滴入墨）
#
# 资源：assets/audio/bgm_*.ogg（4 首场景 BGM）＋ assets/audio/sfx/*.ogg（20+ 条音效）
#   —— 都是从项目已有的"开场动画那批音乐/音效"里挑出来重新配的（见对话记录），
#      所以**不花一分钱**、也不依赖任何音频通道（MiniMax 音乐 API 已停服）。
#
# 实现说明：
#   · 不用 autoload（工程里一个 autoload 都没有，加一个要动 project.godot）；
#     这里按需把播放器挂到 scene tree 的 root 上，跨场景不会被回收。
#   · BGM 两路 player 交叉淡入淡出；SFX 最多 32 路同时播放，结束后复用，闲置池最多 16 路。
# ============================================================

const DIR_BGM := "res://assets/audio/"
const DIR_SFX := "res://assets/audio/sfx/"

static var _cur_bgm := ""
static var _music_context := ""
static var _bgm_request := 0
static var _shutting_down := false
static var _quit_hook_installed := false
static var _amb: AudioStreamPlayer = null   # v230：循环环境音（风/雨）
static var _amb_key := ""
static var _bgm_a: AudioStreamPlayer = null
static var _bgm_b: AudioStreamPlayer = null
static var _use_a := true
static var _cache := {}
static var _bgm_db := -18.0     # BGM 基准音量
# v16n（用户："背景音有点吵"）：⚠ 原来是 -12dB —— 跟音效（-3~-14dB）几乎一样响，
#   打着打着就嫌吵。压到 -18dB（约一半响度），音效仍然压得住它。
#   玩家还能在［设置］里再调（音乐/音效各 5 档，存进设置文档）。

# v230：循环环境音——挂到 root，跨场景不回收；换 key 时先停旧的
static func play_ambient(key: String, vol_db := -26.0) -> void:
	if key == _amb_key and _amb != null and is_instance_valid(_amb) and _amb.playing:
		return
	stop_ambient()
	var s := _stream(DIR_SFX + key + ".ogg")
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	var root := _root()
	if root == null:
		return
	_amb = ManagedPlayer.new()
	_amb.stream = s
	_amb.volume_db = vol_db + _vol_db(_sfx_vol)
	root.add_child(_amb)
	_amb.play()
	_ensure_playing(_amb)   # 跟 sfx 一样：偶发第一下没起播时补两脚
	_amb_key = key

static func stop_ambient() -> void:
	if _amb != null and is_instance_valid(_amb):
		_amb.queue_free()
	_amb = null
	_amb_key = ""

static func _root() -> Node:
	if _shutting_down:
		return null
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		if not _quit_hook_installed:
			_quit_hook_installed = true
			(ml as SceneTree).auto_accept_quit = false
			(ml as SceneTree).root.close_requested.connect(quit_cleanly.bind(0))
		return (ml as SceneTree).root
	return null

static func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	_cache[path] = s
	return s

# 真正开播：先等一帧（跳出 _ready 的调用栈），再加载、建播放器、淡入
static func _begin_bgm(key: String, fade: float, request: int) -> void:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		_cur_bgm = ""
		return
	await (ml as SceneTree).process_frame
	if _shutting_down or request != _bgm_request:
		return
	var root := _root()
	if root == null:
		_cur_bgm = ""
		return
	var s := _stream(DIR_BGM + key + ".ogg")
	if s == null:
		await (ml as SceneTree).process_frame      # 再给一帧机会
		if _shutting_down or request != _bgm_request:
			return
		_cache.erase(DIR_BGM + key + ".ogg")       # 清掉可能缓存下来的 null
		s = _stream(DIR_BGM + key + ".ogg")
	if s == null:
		_cur_bgm = ""                              # 失败就复位，下次还能再试
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	if _bgm_a == null:
		_bgm_a = ManagedPlayer.new()
		_bgm_a.name = "BgmA"
		root.add_child(_bgm_a)
	if _bgm_b == null:
		_bgm_b = ManagedPlayer.new()
		_bgm_b.name = "BgmB"
		root.add_child(_bgm_b)
	# ⚠ 三元表达式两边都是 AudioStreamPlayer，但 Godot 推不出类型（Variant）——
	#   后面 create_tween() 就"无法推断 tw 的类型"直接 Parse Error，所以这里必须显式标类型
	var old: AudioStreamPlayer = _bgm_b if _use_a else _bgm_a
	var newp: AudioStreamPlayer = _bgm_a if _use_a else _bgm_b
	_use_a = not _use_a
	_cancel_music_fade(newp)
	newp.stream = s
	newp.volume_db = -60.0
	newp.play()
	_ensure_playing(newp)
	_ensure_loaded()
	_fade_music(newp, _bgm_db + _vol_db(_bgm_vol), fade)
	if old.playing:
		_fade_music(old, -60.0, fade, true)

static func _cancel_music_fade(player: AudioStreamPlayer) -> void:
	if player.has_meta("music_fade"):
		var fade := player.get_meta("music_fade") as Tween
		if fade != null and fade.is_valid():
			fade.kill()

static func _fade_music(player: AudioStreamPlayer, db: float, seconds: float, stop_after := false) -> void:
	_cancel_music_fade(player)
	var fade := player.create_tween()
	player.set_meta("music_fade", fade)
	fade.tween_property(player, "volume_db", db, maxf(0.01, seconds))
	if stop_after:
		fade.tween_callback(player.stop)

# v71d：**播放兜底**——用户问「音乐音效呢」，查出来是这个：
#   音频设备/混音线程还没就绪时，AudioStreamPlayer.play() 会**静默失败**（不报错、playing 一直是 false）。
#   探针实测：在 SceneTree._initialize() 里调 play_bgm → playing=false；改到 _process 里调 → playing=true。
#   游戏里场景 _ready 一般晚于设备就绪，但**开场第一帧**这种边界不该赌，
#   所以这里隔帧补两次：真在播就立刻返回，白等一帧的代价可以忽略。
static func _ensure_playing(p: AudioStreamPlayer) -> void:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return
	for i in 3:
		if _shutting_down or not is_instance_valid(p) or p.playing:
			return
		await (ml as SceneTree).process_frame
		if not _shutting_down and is_instance_valid(p) and not p.playing:
			p.play()

# ============================================================
# v72：**玩家设置**（音乐音量 / 音效音量 / 主界面曲目）
#   · 存 `user://audio.cfg`（ConfigFile）——**不动存档**（save.cfg 是村账，别混）
#   · 音量用 0..1 线性，落到 dB 时 0 走 -80（等于静音）
#   · 主界面曲目 = 素材包里那批真曲里挑的 6 首（见 MENU_TRACKS）
# ============================================================
const SETTINGS_PATH := "user://audio.cfg"
static var _loaded := false
static var _bgm_vol := 1.0
static var _sfx_vol := 1.0
static var _menu_track := "menu_jiangnan"

# v16q（用户："换一首吧"——战斗曲 bgm_battle 里有呐喊，听着吵）：
#   战斗曲改成**可选**，默认换成"悟 道"（纯器乐、清净）。
#   列表里把原来那首（战鼓/呐喊那首）也留着，想换回去随时能选。
# v16q-1（用户："燃一点有激情的"）：
#   ⚠ 试过让 AI 生成一首，但 MiniMax 的音乐 API 对本账号已关闭
#     （HTTP 410 / status_code 2153「不再对新用户开放」），三个模型 music-3.0/2.6/cover 全一样。
#   改为默认用工程里本来就有的**爬塔战斗曲 bgm_tower** —— 它也是战斗曲，但没有原曲那种呐喊。
#   不满意可在［设置］里逐首试（共 8 首可选）。
static var _battle_track := "bgm_tower"

const BATTLE_TRACKS := [
	{"key": "bgm_tower", "name": "爬塔战曲（默认）"},
	{"key": "menu_wudao", "name": "悟 道"},
	{"key": "menu_shushan", "name": "蜀 山"},
	{"key": "menu_youzhou", "name": "幽 州"},
	{"key": "menu_shaolin", "name": "少 林"},
	{"key": "menu_hejian", "name": "河 间"},
	{"key": "menu_jiangnan", "name": "江 南"},
	{"key": "bgm_battle", "name": "原战斗曲（有呐喊）"},
]

const MENU_TRACKS := [
	{"key": "menu_jiangnan", "name": "江 南"},
	{"key": "menu_hejian", "name": "河 间"},
	{"key": "menu_wudao", "name": "悟 道"},
	{"key": "menu_shaolin", "name": "少 林"},
	{"key": "menu_youzhou", "name": "幽 州"},
	{"key": "menu_shushan", "name": "蜀 山"},
]

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		_bgm_vol = clampf(float(cf.get_value("audio", "bgm", 1.0)), 0.0, 1.0)
		_sfx_vol = clampf(float(cf.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
		_menu_track = str(cf.get_value("audio", "menu_track", "menu_jiangnan"))
		_battle_track = str(cf.get_value("audio", "battle_track", "bgm_tower"))

static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "bgm", _bgm_vol)
	cf.set_value("audio", "sfx", _sfx_vol)
	cf.set_value("audio", "menu_track", _menu_track)
	cf.set_value("audio", "battle_track", _battle_track)
	cf.save(SETTINGS_PATH)

static func _vol_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(clampf(v, 0.001, 1.0))

static func bgm_volume() -> float:
	_ensure_loaded()
	return _bgm_vol

static func sfx_volume() -> float:
	_ensure_loaded()
	return _sfx_vol

static func menu_track() -> String:
	_ensure_loaded()
	return _menu_track

# 战斗曲（可换）
static func battle_track() -> String:
	_ensure_loaded()
	return _battle_track

static func set_battle_track(key: String) -> void:
	_ensure_loaded()
	_battle_track = key
	save_settings()
	# 正在放战斗曲就**立刻换掉**（换完这首重新流进来）
	if _music_context == "battle":
		play_bgm(key, 0.6)

# 改音量：立刻作用到**正在播的那一路**上（不然要等下一首才生效）
static func set_bgm_volume(v: float) -> void:
	_ensure_loaded()
	_bgm_vol = clampf(v, 0.0, 1.0)
	var active := _bgm_b if _use_a else _bgm_a
	if is_instance_valid(active) and active.playing:
		_cancel_music_fade(active)
		active.volume_db = _bgm_db + _vol_db(_bgm_vol)
	save_settings()

static func set_sfx_volume(v: float) -> void:
	_ensure_loaded()
	_sfx_vol = clampf(v, 0.0, 1.0)
	save_settings()
	sfx("ui_click", -10.0)     # 拖完给一声，听得见效果

# 换主界面曲目：存盘 + 立刻换（在播的是主界面那首才切，别打断战斗 BGM）
static func set_menu_track(key: String) -> void:
	_ensure_loaded()
	_menu_track = key
	save_settings()
	if _music_context == "menu":
		play_bgm(key, 0.8)

# ---------------- BGM ----------------

static func play_menu_music(fade := 0.7) -> void:
	_music_context = "menu"
	play_bgm(menu_track(), fade)

static func play_battle_music(fade := 0.55) -> void:
	_music_context = "battle"
	play_bgm(battle_track(), fade)

static func play_bgm(key: String, fade := 1.2) -> void:
	if key == _cur_bgm:
		return
	# v71e（用户报的「主界面没有 BGM，但游历里有声音」）：**真凶就是下面这一步的时机**。
	#   主界面是**开场第一帧**的 _ready 里调过来的，那时候资源系统/音频设备都还没就绪：
	#   load(ogg) 会失败（探针里直接卡住不再返回）→ 原来的代码在 s == null 处 return，
	#   **播放器根本没建**，而 _cur_bgm 也没写上——于是主界面永远静音；
	#   游历/战斗是后面进的场景，那时候一切都就绪，所以有声。
	#   修法：**把开播推迟一帧**（跳出 _ready 的调用栈），并且加载失败时再等一帧重试。
	_cur_bgm = key
	_bgm_request += 1
	_begin_bgm(key, fade, _bgm_request)

static func stop_bgm(fade := 0.8) -> void:
	_cur_bgm = ""
	_music_context = ""
	_bgm_request += 1
	for p in [_bgm_a, _bgm_b]:
		if p != null and p.playing:
			_fade_music(p, -60.0, fade, true)

# ---------------- 音效 ----------------

# 音效播放器池：原来每放一声都 ManagedPlayer.new()（一场战斗几十个），
# 现在复用。放完回收，池满/不在树里才真释放。
static var _sfx_pool: Array = []
static var _sfx_active: Array = []
static var _last_sfx_msec := {}
const SFX_POOL_MAX := 16
const SFX_ACTIVE_MAX := 32

static func _acquire_sfx_player() -> AudioStreamPlayer:
	_sfx_active = _sfx_active.filter(func(p): return is_instance_valid(p))
	if _sfx_active.size() >= SFX_ACTIVE_MAX:
		return null
	while not _sfx_pool.is_empty():
		var q = _sfx_pool.pop_back()
		if is_instance_valid(q):
			return q
	return ManagedPlayer.new()

static func _release_sfx_player(p: AudioStreamPlayer) -> void:
	if p == null or not is_instance_valid(p) or not _sfx_active.has(p):
		return
	_sfx_active.erase(p)
	p.stop()
	p.stream = null
	if _sfx_pool.size() < SFX_POOL_MAX and p.is_inside_tree():
		_sfx_pool.append(p)
	else:
		p.queue_free()

static func sfx(key: String, vol_db := -6.0, pitch := 1.0, min_gap_ms := 0) -> void:
	var gap := maxi(min_gap_ms, 45 if key == "ui_click" else 0)
	var now := Time.get_ticks_msec()
	if gap > 0 and now - int(_last_sfx_msec.get(key, -gap)) < gap:
		return
	var root := _root()
	if root == null:
		return
	var s := _stream(DIR_SFX + key + ".ogg")
	if s == null:
		return
	_ensure_loaded()
	var p := _acquire_sfx_player()
	if p == null:
		return
	if gap > 0:
		_last_sfx_msec[key] = now
	_sfx_active.append(p)
	p.stream = s
	p.volume_db = vol_db + _vol_db(_sfx_vol)
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	# v15h：⚠ 启动时如果有谁在 _ready() 里调 sfx()，根节点还在"建子节点"。
	#   那时候 add_child 会**直接失败**，玩家节点没进树 → play() 报"Playback can only happen
	#   when a node is inside the scene tree"（启动日志里那一串就是它）。
	#   现在：进树了照旧；没进树就 deferred 补一脚（音效晚一帧，听不出来）。
	p.finished.connect(_release_sfx_player.bind(p), CONNECT_ONE_SHOT)
	# ⚠ 关键：add_child 失败时"补 deferred 的 play"是没用的 —— 节点压根没进树。
	#   所以整串（入树 → 播放 → 起播兜底）都得放到父节点空闲之后再走。
	# 池里捞出来的可能已经挂在 root 下面了（回收时不摘），别再 add_child
	var need_add := p.get_parent() == null
	if root.is_node_ready():
		if need_add:
			root.add_child(p)
		p.play()
		_ensure_playing(p)
	else:
		if need_add:
			root.add_child.call_deferred(p)
		_play_when_free.call_deferred(p)

# v15h：延迟起播（父节点建完子节点之后再入树＋播放）
static func _play_when_free(p: AudioStreamPlayer) -> void:
	if _shutting_down:
		return
	if p == null or not is_instance_valid(p):
		return
	if not p.is_inside_tree():
		return
	p.play()
	_ensure_playing(p)

# 界面点击：统一走这一口（后面接"水滴墨扩散"特效时也挂这里）
static func ui_click() -> void:
	# v67：换成素材包里的真·UI 音（原来用"墨滴"充数）；要回墨滴就改回 "ink_drop"
	sfx("ui_click", -12.0, randf_range(0.96, 1.06))

# 退出前让播放器和混音线程有机会释放正在使用的播放资源。
static func shutdown() -> void:
	_shutting_down = true
	var seen := {}
	for player in _sfx_active + _sfx_pool + [_bgm_a, _bgm_b, _amb]:
		if not is_instance_valid(player) or seen.has(player.get_instance_id()):
			continue
		seen[player.get_instance_id()] = true
		player.stop()
		player.stream = null
		player.queue_free()
	_sfx_active.clear()
	_sfx_pool.clear()
	_last_sfx_msec.clear()
	_cache.clear()
	_bgm_a = null
	_bgm_b = null
	_amb = null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null: return
	var until := Time.get_ticks_msec() + 100
	while Time.get_ticks_msec() < until:
		await tree.process_frame

static func quit_cleanly(code: int = 0) -> void:
	if _shutting_down: return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null: return
	tree.paused = true
	await shutdown()
	tree.quit(code)
