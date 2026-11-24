---
name: jianghu
description: 《江湖游历》Godot 4.7 竖屏水墨卡牌工程的导航与协作约定：目录职责、数据入口（card_data / level_state / curio / forge / equipment）、启动与存档、测试命令、资源命名、文档与归档规矩。当用户在这个工程里改玩法、加卡、调数值、做界面、接素材、跑回归、写交接时使用。
whenToUse: 在本仓库做任何代码、数值、美术接入或文档工作之前；尤其是“加一张卡/加一个奇物/改关卡节奏/改 UI/接立绘/跑十关测试”这类具体任务。
---

# 江湖游历 · 工程技能

竖屏水墨卡牌手游，当前玩法是**「困兽」**（十关教学 + 局外养成）。旧的「游历 / 修村 / 江湖图」已搁置，对应代码和文档都已删除或归档。

## 先读两页

1. `README.md` —— 当前功能、已确认规则、存档与验证入口（最权威）
2. `docs/项目现状总览_2026-11-24.md` —— 代码地图、资源结构、已知风险

历史文档在 `docs/_archive/`，**不代表现状**，不要拿它当实现依据。

## 铁律

- **不改代码，除非用户明确要求改**。审计/查看任务只读。
- **不改素材内容**（图片、音频、场景二进制）；新增可以，覆盖要先问。
- 删除/移动文件前先列清单并说明理由；删除走 `docs/` 记录。
- 一次只做一件事，改完立刻用 §验证 里的命令跑一次。
- 新增/修改数据后，同步更新 `docs/` 里对应的设计稿，别让代码和文档分叉。

## 工程事实

| 项 | 值 |
|---|---|
| 引擎 | Godot **4.7.2**，可执行文件 `C:\Users\zq300\Desktop\Godot_v4.7.2-stable_win64.exe` |
| 画面 | 720×1280 竖屏，stretch=viewport，Compatibility/OpenGL3 |
| 启动链 | `menu/opening.tscn`（首启播片）→ `loading` → `menu/main_home.tscn` → `kushou/battle_ui.tscn` |
| 主场景配置 | `project.godot` 里写 `opening.tscn`；播过一次后由 `user://opening.cfg` 决定直接进主界面 |
| 场景总数 | 14 个 `.tscn`（不含 addons） |
| 核心大文件 | `kushou/battle_ui.gd` **366 KB**、`kushou/kushou_battle.gd` **334 KB**（改动务必局部化，先搜定位再改） |

## 目录职责

| 目录 | 干什么 |
|---|---|
| `menu/` | 局外页面：opening、loading、main_home、character_home、curio_home、forge_sheet、partner_home、equip_detail |
| `shared/` | 数据与基础设施：level_state（十关+功能解锁）、card 相关在 kushou、game_state、save_file、audio、ui_kit、ui_pal、ui_motion、char_art、curio_data、forge_data、equipment_stats、combat_rules |
| `kushou/` | 战斗与困兽玩法：battle_ui、kushou_battle、card_data、ancestor_data、black_market、attr_panel、attack_fx、token_actor、hazard_telegraph、card_frame、tutorial_overlay |
| `assets/` | 所有运行时素材（见 references/assets.md） |
| `tools/` | 测试/审计脚本（不进游戏） |
| `docs/` | 设计稿与记录；`_archive/` 是历史 |

## 数据入口（改数值先找这里）

| 要改什么 | 文件 | 关键点 |
|---|---|---|
| 组合卡 10 系 × 4 阶 | `kushou/card_data.gd` | `SELFS` 常量；`own_*`、`combo_*`、`arts` 图标路径 |
| 十关波数 / 按钮显隐 / 功能解锁 | `shared/level_state.gd` | `LEVELS`、`FEATURE_LEVEL`；**功能是否开放一律走 has_feature()**，不要另写 `current_level >= N` |
| 祖宗家传（请神） | `kushou/ancestor_data.gd` | 每位 6 档 × 3 张；同档集齐成组 |
| 奇物 15 件 | `shared/curio_data.gd` | 主动/被动、触发、冷却、五级文案 |
| 装备 / 锻造 | `shared/forge_data.gd` | 品质定上限与增幅；品阶每 20 级 +1；特性 |
| 装备属性换算 | `shared/equipment_stats.gd` | 防御 1 点 = 3% 固定减免；速度 1 点 = 1% 攻速 |
| 黑市 / 仓库 | `kushou/black_market.gd` | 六格随机货、折扣、Lv1-5 |
| 货币与名号 | `shared/game_state.gd` | 只保留 wen/silver/yuanbao |

## 界面骨架

`shared/ui_kit.gd` 定义统一版式：**顶栏 0–90 / 页头 90–152 / 内容 152–1176 / 底栏 1176–1280**。
颜色走 `shared/ui_pal.gd`，动效走 `shared/ui_motion.gd`，字体 `fonts/ink.ttf`（毛笔）。
新页面必须复用 ui_kit 的骨架与按钮样式，不要自造 StyleBox。

## 存档

`user://` 下：`level_state.cfg`、`progress.cfg`、`forge.cfg`、`curio.cfg`、`audio.cfg`、`opening.cfg`。
写档：先写 `.tmp` 再替换；读档异常保留原文件、禁止覆盖。
`user://reward_pending.cfg` 是跨文件奖励日志，**不要手删**。目前没有备份恢复界面。

## 验证（改完必跑）

```powershell
$godot = 'C:\Users\zq300\Desktop\Godot_v4.7.2-stable_win64.exe'
& $godot --headless --path D:\1\wuxia-demo --quit-after 240      # 冒烟
./tools/run_audits.ps1                                             # 全量审计
./tools/run_playthrough.ps1 -StartLevel 1 -EndLevel 10             # 十关通关
```

测试跑在隔离项目 `.shots/audit_project`，**不要并发**跑会重配它的入口；结果在 `.shots/audit_results`。
断言通过 ≠ 日志无警告，也 ≠ 体验已验收。

## 常见任务怎么下手

- **加/改一张卡**：`card_data.gd` 的 `SELFS` → 找对应系与阶 → 加名字/数值/图标 → 跑 `run_audits` 里的卡池专项。
- **改关卡节奏**：`level_state.gd` 的 `LEVELS` / `FEATURE_LEVEL` → 同步 `docs/困兽_十关教学关_设计原则.md`。
- **加奇物**：`curio_data.gd` 目录 → 效果落地在 `battle_ui._cast_skill` 或对应 hook。
- **改 UI**：先看 `shared/ui_kit.gd` 骨架与 `ui_pal`，新页面复用 `paper_box` / `style_button`。
- **接立绘**：素材进 `assets/char/` 或 `assets/gen/char/`，在 `shared/char_art.gd` / `god_portraits.gd` 注册；记录写到 `docs/立绘接入记录_*.md`。
- **接配音**：`assets/voice/` + `docs/配音清单.md` 的命名契约。
- **动效**：`shared/ui_motion.gd`；战斗表现走 `battle_ui` 的 FX 段。

## 文档与素材规矩

- 新文档：`docs/主题_日期.md`（如 `挑战_设计稿.md`、`审查补记_xxx_2026-11-20.md`）。
- 被取代的文档移进 `docs/_archive/`，不要留在主目录。
- 交接文档只在一次会话结束时写一份，别每个小版本都写。
- 素材目录与命名见 `references/assets.md`；生成物进 `assets/gen/`，手工整理进 `assets/art/`。

## 坑

1. `battle_ui.gd` / `kushou_battle.gd` 太大，改动前先 `grep` 定位，别通读。
2. 测试入口会改 `.shots/audit_project`，并发会互相踩。
3. `opening.gd` 只在首次启动播片（`user://opening.cfg`），调试加 `--replay-opening`。
4. `%APPDATA%\Godot\app_userdata\江湖游历\` 里的真实存档，跑探针前要备份、跑完还原。
5. 仓库有每 30 分钟的自动提交，大文件删除会被记录；`.shots`、`素材`、`.yanyu`、`.yingzhi` 已 gitignore。
