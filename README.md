# 江湖游历

Godot 4.7.2 · 竖屏 720×1280 · 武侠卡牌 roguelite 的**可运行 demo**。
主场景 `res://menu/main_home.tscn`，点「开始游戏」进「困兽」战斗界面 `res://kushou/battle_ui.tscn`。

> 工程名沿用 `project.godot` 里的 `config/name="江湖游历"`；游戏内实际内容现在就是「困兽」。

---

## 运行

用 Godot 4.7.2 打开本目录即可。命令行：

```powershell
& 'C:\Users\zq300\Desktop\Godot_v4.7.2-stable_win64.exe' --path 'D:\1\wuxia-demo'
```

- 视口 720×1280（`canvas_items` 拉伸），窗口默认 450×800
- 渲染 `gl_compatibility` / `opengl3`
- 导出只有一份 Android preset（`export_presets.cfg`，输出到 `../wuxia-export/wuxia.apk`）

---

## 现在真的能玩到的

| 位置 | 内容 |
|---|---|
| **主界面** | 整屏贴图 `assets/art/ui/main_home_ref.png`（1152×2048）＋ 一层透明热区；顶栏两个数字由 `GameState` 覆盖到图上；难度钮 / 关卡箭头目前只记录或打印 |
| **战斗界面** | 顶栏（文钱 / 灵晶 / 杀敌）· 波数与气血 · 战场 · 功法面板 · 卡组 · 底栏五钮 · 抽卡页 · 属性窗 · 退出确认 |
| **抽卡** | 20 灵晶抽 3 张，点一张飞进卡组；刷新 5 灵晶；卡组 10 格（2 页 × 5） |
| **组合** | 集齐同系同阶全部卡 → 清空这几个卡位、永久结算属性、生成一条按触发条件生效的组合，并把下一阶入口卡塞进卡池 |
| **战斗内层** | `kushou_battle.gd` 以 **25% 透明度**当战场底：自动打最近的怪、刷怪、掉文钱、气血与击杀实时同步到界面 |
| **角色页 / 伙伴页** | 静态骨架：装备槽、背包、武学格都是画出来的占位，属性数字写死 |
| **设置** | 音乐 / 音效两条 −／＋，存 `user://audio.cfg`（即 `%APPDATA%\Godot\app_userdata\江湖游历\audio.cfg`） |

---

## 还没接的（**别当 bug 查**）

1. **波次不推进** —— `_core.set_wave(1)` 只在建场景时调一次；内核的 `wave` 只靠外部改，
   所以难度永远停在波 1、每波固定 8 只。界面上「波 x/5」的五个点、「首领 00:37」、气血条长度都是写死的。
2. **灵晶没有收入源** —— 内核的 `special` 信号（晶怪掉灵晶）没连，
   `_crystal` 只有初始 100 ＋ 晶系组合的 `crystal_flat`。100 ÷ 20 → **抽 5 次就断粮**。
3. **底栏五钮**：只有「抽卡」真接线，黑市 / 宝物 / 伙伴 / 强化 只弹一句 toast。
4. **功法面板**：3 个画出来的图标（剑 / 棍 / 匕首），点一下只 toast。
5. **属性窗**：320 / 21 / 8 / 15% 那一组数字是写死的。
6. **没有存档** —— `shared/game_state.gd` 是内存静态变量，退出即清零；只有音量落盘。
7. **音乐没接** —— `shared/audio.gd` 里有 10 首 BGM 和交叉淡入，但当前场景没人调 `play_bgm`，
   所以现在**只有战斗音效**（`kushou_battle` 里 80 处 `Audio.sfx`），UI 点击音也没接。
8. 卡牌目前只往英雄身上加裸属性（攻 / 防 / 血 / 金 / 晶），没接内核里的伙伴、召唤、元素技能。

---

## 卡池规则

- **5 系 × 4 阶 = 90 张**：攻（砺锋…）· 防（铁壁…）· 气血（生机…）· 金币（聚财…）· 灵晶（灵涌…）
- 每阶 3 / 4 / 5 / 6 张，**第一张是入口卡**；拿到入口卡才把同阶其余卡放进抽卡池
- 品质跟阶走：良 → 玄 → 地 → 天（`QUALITY_OF_TIER = [2,3,4,5]`）
- 集齐一整套 → **组合激活**：卡从卡组清空、属性永久结算、组合按
  「每波 / 每 6 秒 / 每次击杀 / 每 10 次攻击」触发；同时解锁下一阶入口卡
- 卡图：`assets/art/cards/gen/<系>_<阶>_<序号>.png`，一卡一图
- 卡名 / 数值 / 触发方式全在 `kushou/card_data.gd`，只有这一个文件

---

## 目录

| 目录 | 内容 |
|---|---|
| `menu/` | 主界面 `main_home` · 角色页 `character_home` · 伙伴页 `partner_home` |
| `kushou/` | 困兽：战斗界面 `battle_ui` · 战斗内核 `kushou_battle` · 卡池 `card_data` · 圆形人物牌 `token_actor` |
| `shared/` | 音频总管 `audio` · 取图口 `char_art` · 全局状态 `game_state` · 笔画图标 `glyph_draw` |
| `assets/` | `art/`（含 90 张卡图）· `audio/`（10 首 BGM ＋ 42 条音效）· `char/` `ui/` `items/` `voice/` `clips/` `scenes/` `gen/` |
| `fonts/` | `fonts/ink.ttf` 水墨字；整套 UI 都是 `_draw()` 手画，字体只有这一个 |
| `docs/` | 设计 / 交接文档（见文末，多数是旧版） |
| `tools/` | 构建与自动化脚本（含 30 分钟自动提交） |

---

## 关键文件

| 文件 | 行数 | 作用 |
|---|---|---|
| `kushou/kushou_battle.gd` | 5833 | 战斗内核（245 个函数）：刷怪、自动出手、元素 / 暴击 / 护盾 / 召唤、预警技、boss |
| `kushou/battle_ui.gd` | 1250 | 战斗界面外壳（抽卡 / 卡组 / 组合 / 属性 / 退出都在这里） |
| `menu/partner_home.gd` | 310 | 伙伴页骨架 |
| `shared/audio.gd` | 316 | BGM 交叉淡入 ＋ 音效一发 ＋ 音量存档 |
| `kushou/token_actor.gd` | 193 | 圆形人物牌（纸底金边、出手前倾、挨打闪红、倒地淡出） |
| `menu/main_home.gd` | 197 | 主界面（贴图 ＋ 热区） |
| `menu/character_home.gd` | 129 | 角色页骨架 |
| `kushou/card_data.gd` | 59 | 卡池定义 ＋ `build()` |
| `shared/game_state.gd` | 17 | 文钱 / 元宝（内存） |
| `shared/glyph_draw.gd` | 15 | 笔画图标（剑 / 棍 / 匕首） |

---

## 调参口

`kushou/battle_ui.gd`
- 抽卡价 `_show_draw()` 里的 20 · 刷新价 `_on_refresh()` 里的 5
- 卡组上限 `_add_card()` 的 10
- 英雄初始：`_core.setup({"atk": 12.0, "hp_max": 200.0, "mp_max": 100.0})`

`kushou/kushou_battle.gd`（文件头有整段注释）
- `MAX_FOES = 24` 同屏上限 · `_wave_quota_for()` 每波定额 8~20
- `kill_heal = 0.08` 击杀回血（占气血上限）· `WAVE_HP = 1.08` / `WAVE_ATK = 1.08` 每波成长
- `SPAWN_EVERY = 1.2` / `SPAWN_EVERY_LATE = 0.9`（第 10 波后）

---

## 改完必跑的自查

```powershell
$G='C:\Users\zq300\Desktop\Godot_v4.7.2-stable_win64.exe'

# 1) 单文件语法
& $G --headless --path D:\1\wuxia-demo --check-only --script res://kushou/battle_ui.gd 2>&1 | Out-String

# 2) 编辑器能不能零报错加载（插件、场景 ext_resource 都在这步暴露）
& $G --headless --path D:\1\wuxia-demo --editor --quit 2>&1 | Out-String

# 3) 正常跑一把
& $G --path D:\1\wuxia-demo
```

`| Out-String` 不能省：不加的话 `$LASTEXITCODE` 会假报错。
当前基线：**2) 的 ERROR / WARNING = 0，11 个在线脚本 `--check-only` 全绿**。

---

## 版本控制与备份

Windows 计划任务 **`wuxia-autocommit`** 每 30 分钟执行一次
（脚本 `tools/autocommit.ps1`，任务定义 `tools/autocommit-task.xml`，日志 `.git/autocommit.log`）：
**有改动才提交，没改动不产生空提交**，然后把提交推到全部远端。

| 远端 | 位置 | 作用 |
|---|---|---|
| `origin` | Gitee 私有仓库 | 异地备份 |
| `backup` | `E:\wuxia-backup.git` | 本机第二副本（裸仓库） |

手动存档一次：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\1\wuxia-demo\tools\autocommit.ps1
```

---

## 素材与体积

工作树里 `assets/` 约 **780MB**，但大部分不进库（`.gitignore` 挡着）：

- **不进库**：`assets/gen/char/`（236MB）· `assets/gen/audio/`（153MB）· `.shots/` · `.yanyu/` · `.yingzhi/`
- **进库**：`assets/` 下 536 个文件（卡图、UI、音频、字体）

`.git` 本身约 660MB —— 历史里躺着已经下线的旧玩法。

---

## 文档

`docs/` 里 80 多个文档**绝大多数写于已下线的旧版本**，读之前先记住：

- ✅ 还有参考价值（机制 / 数值 / 表）：
  [`docs/困兽_属性设计稿.md`](docs/困兽_属性设计稿.md) ·
  [`docs/困兽_卡池表.md`](docs/困兽_卡池表.md) ·
  [`docs/困兽_伙伴设计稿.md`](docs/困兽_伙伴设计稿.md) ·
  [`docs/困兽_技能设计稿.md`](docs/困兽_技能设计稿.md) ·
  [`docs/困兽_事件与任务_设计稿.md`](docs/困兽_事件与任务_设计稿.md) ·
  [`docs/困兽_交接_第二轮.md`](docs/困兽_交接_第二轮.md)（最详尽的踩坑记录）
- ❌ 凡是提到 `kushou/kushou_v2.gd`、`menu/menu_sketch.gd`、`journey/`、`shared/scene_layout.gd`、
  `addons/scene_painter/` 的，**文件都已经不存在了**——2026-11-06 那轮清理删了 232 个文件，
  把「江湖游历」整套玩法（走路 / 遇见 / 宗门 / 地盘 / 锻造 / 听雨楼）统一下线，只留「困兽」
- 老文档说的架构是「外壳 `kushou_v2` ＋ 战场 `kushou_battle`」；现在外壳换成了 `battle_ui.gd`，
  只有战场内核还是同一份代码

---

## 已知边界

- 波次与难度曲线没接 · 灵晶经济没闭环（见「还没接的」第 1、2 条）
- 无存档、无元进度、无成就
- 角色页 / 伙伴页是静态骨架
- 编辑器与游戏均零报错；唯一一条没有的素材是 `assets/audio/bgm_boss_intro.ogg`
  （代码里有 `ResourceLoader.exists` 兜底，取不到就走鼓声 ＋ 紧弦）
