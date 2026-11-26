# DeepSeek 任务交接 · Godot 战斗界面拆分与回归

项目位于 `D:/1/wuxia-demo`，界面采用 720×1280 竖屏设计坐标。第一至第三批已交付，见 `docs/交接_GPT_变更说明_2026-11-26.md`。本轮从第四批开始，按第四、第五、第六批依次做，每批独立验收和提交。任务与后续交付摘要继续记在这一份交接单里。

## 开工前

- 先看 `git status --short` 和近期变更，以当前代码为准。同一工作区有人在做首领、动画及素材接线。用独立分支或工作树。若只能共用目录，先做新视图文件，修改 `kushou/battle_ui.gd` 前核对最新差异。发现变更重叠时先保留双方改动，再处理合并。
- 已拆出的 `kushou/battle_art.gd` 和 `kushou/balance_rules.gd` 继续由现有调用链使用。请沿用 `shared/ui_kit.gd`、`shared/ui_motion.gd`、`kushou/card_frame.gd` 的现成能力。
- 每批以可见行为一致为验收。这个任务的范围是视图和输入接线。数值、存档协议、美术、战场演出及停用系统由原流程负责。遇到可复现的行为缺陷，单独报告或另做独立修复，避免混在搬迁提交里。

## 第一批 · 结算页

**交付** `kushou/result_view.gd`，从 `kushou/battle_ui.gd` 移出结算界面的 CG、遮罩、纸框、六行数据、按钮和界面内的入场动画。视图接收战斗传来的结算数据，并通过信号或回调上报「再来一局」「回主界面」。视图负责自己的节点和动画生命周期。可以先保留 `_result_layer` 作为战斗持有的结果视图引用，便于现有审计和调用继续运行。

- 现行入口是 `_end_run → _build_result → _fill_result`。由战斗继续决定何时冻结、何时等待首领倒地完成、何时调用结果特效。等待期间仍需挡住战斗区的输入。延迟显示过程中离树，结果层和待执行的回调应随场景释放。
- `_save_result`、`_grant_first_clear`、`_unrecorded_clear_level` 和 `_leave_result` 留在战斗层。保留存档失败时在当前页重试、首次奖励只发一次、两按钮连续点击也只发起一次场景切换。局内文钱与灵晶只做结算展示，按现行规则处理结转。
- 胜败两种状态都核对 CG 存在和缺图回退、文本落在纸框内、按钮按下与回弹、演出与结算音的触发时机。至少留胜利和失败的改前、改后截图。
- 必跑 `result_panel`、`result_freeze`、`battle_navigation`、`reward_save`、`battle_lifecycle`。用真实点击验证两按钮，也核对测试模拟的保存失败与恢复。

## 第二批 · 抽卡视图

**交付** 独立的抽卡视图模块，接现有 `_build_draw`、`_show_draw`、`_pop_draw_cards` 和卡面绘制。先迁移视图创建、显示和动画，再处理卡组展示。把卡标识和选择动作回传给战斗层。当前手牌、发牌、消耗、满牌处理、吞噬和领取结果继续走原有入口。

- 按现行时序复现按钮按下、卡牌弹出、短暂输入门槛、刷新与关闭。验证连按、同帧选两张、关闭重开、额度不足和战斗结束后的点击。抽卡页的暂停行为以当前代码与实际运行结果为准。
- 保留加载页提前准备首屏卡面、资源复用、重开与关窗清理。用现有素材做桌面录屏或连续截图，确认卡牌出处、裁切和层级一致。
- 必跑 `draw_claim`、`choice_boundary`、`menu_navigation`、`battle_lifecycle`。如要连带重构牌组的数据来源，先单独完成并验收这批视图。

## 第三批 · 宝物、强化与奇物详情

**交付** 把 `_open_trea`、`_open_aug_pick`、`_show_curio_detail` 对应的三个视图拆出。可以共享发牌弹窗的基础视图，但保留各自的数据、按钮可用条件和回调。奇物的状态、冷却、等级及施放仍由战斗层维护。

- 先拆一个面板，验证后再做下一个。覆盖打开、刷新、选定、放弃、互斥切换、点击遮罩关闭，以及结算或离场时清理。保留图标预热、弹跳、声音和低额度时的反馈。
- 必跑 `treasure_flow`、`aug_limits`、`choice_boundary`、`curio_timing`、`curio_save`、`menu_navigation`、`battle_lifecycle`。

## 每批验收和交付

1. 先在改动前跑同一批相关用例，记下基线。PowerShell 用 `./tools/run_playthrough.ps1 -PrepareOnly` 建隔离项目。随后向 Godot 传 `--headless --path .shots/audit_project --max-fps 120 --quit-after 3600 --script res://tools/audit_<用例名>.gd`。每次检查明确的 `PASS:`、退出码和脚本错误。有写档的用例需要干净基线时，重新准备隔离项目。
2. 每批完成后运行 `./tools/run_audits.ps1`，提交 `.shots/audit_results/results.json` 的汇总与失败日志路径。全部批次完成再以 `./tools/run_playthrough.ps1 -StartLevel 1 -EndLevel 10` 检查十关、首通奖励和解锁。桌面截图与录屏也用隔离项目。两个进程之间共用 `.shots/audit_project` 的配置，避免同时运行会重新准备该目录的命令。若协作分支也使用该目录，请各自用独立工作树。
3. 维持现有测试断言强度。视图节点迁移时，更新审计的定位方式并保留原有行为检查。已有失败需要报出改前、改后结果与复现命令，避免把测试噪声当作本批通过。
4. 每批回报四项即可：提交或差异、通过的专项和全量结果、截图或录像路径、仍然存在的具体问题。提交只包含该批的代码和必要测试。

## 第四批 · 补齐结算的真实输入与生命周期回归

**优先级 P1，先完成。** 把结算页最关键的两个缺口补在现有审计中。现有 `audit_choice_boundary.gd` 已用视口输入覆盖抽卡、请神、奇物和卡片弹出的点击。这批复用这个方法，重点补结算页。

- 扩充 `tools/audit_battle_navigation.gd` 的图形运行分支，按按钮的实际全局矩形发送鼠标按下和抬起，通过 GUI 命中「再来一局」和「回主界面」。在 450×800 窗口验证，覆盖胜败两种结算以及两按钮快速连续点击。保留现有协议层的 `pressed.emit()` 用例。记录按钮命中、目标场景和实际切换次数。
- 复用现有隔离存档故障注入，验证一次真实点击失败后页面继续可操作。恢复写入后再次点击，只切场景一次，首通奖励只入账一次。另测延迟结算建立后、揭幕前立即释放场景，跨过原定揭幕时刻，确认无结果视图残留、无迟到的特效或声音触发、无脚本错误，并且新场景可接收输入。现有 `audit_result_freeze.gd` 检查首领倒地后才揭幕，沿用该覆盖。
- 必跑 `battle_navigation`（无头与图形两次）、`result_freeze`、`reward_save`、`battle_lifecycle`。报告中给出图形命令与明确的图形分支通过标记，避免将无头通过计为图形通过。该批发现实际缺陷时，先留用例再做最小修复。

## 第五批 · 迁移抽卡卡面控件

**优先级 P2。** 将实际使用的 `DrawCard` 从 `kushou/battle_ui.gd` 迁入独立脚本，例如 `kushou/draw_card.gd`。先列出 `_build_draw` 的构造接口、`_on_draw_pick` 的消费接口和加载页预热路径。现有 `draw_view.gd` 工厂和信号可以继续使用，战斗层负责池子、支付、羁绊和吞噬结算。

- 保留普通卡与炫卡的特效、回弹、短暂点击门槛、图标裁切和展示字段。按当前版本保留 `CardFrame` 的五档花边以及多级纹理采样，保留 `canvas_items` 渲染模式。预热和显示应使用同一份贴图缓存。同期如有卡面美术更新，以当前版本为截图基线。
- 用固定种子和相同窗口尺寸，对照同一手牌的弹出、静止和飞入。至少覆盖一张普通卡和一张炫卡。必跑 `choice_boundary` 图形分支、`draw_claim`、`menu_navigation` 和 `battle_lifecycle`。

## 第六批 · 抽出宝物和强化共用的选卡面板

**优先级 P2。** `kushou/treasure_view.gd` 与 `kushou/aug_view.gd` 目前大部分相同。合并真正相同的框体、标题区、三张卡的挂载、按钮绑定和弹出/关闭逻辑。两处保留原有入口与各自按钮文案、位置、额外等级文字、刷新费和状态条件。可以组合共用控件或用单个轻量视图交由双方配置。

- 奇物详情保留现有独立视图，它的整屏遮罩关闭行为不同。大型 `AugCard` 及其卡面规则留待后续单独审查。此批重点检查刷新、选定、放弃、互斥切换、结算和离场。保留最近修过的遮罩铺满、奇物回弹清理及点击反馈。
- 必跑 `treasure_flow`、`aug_limits`、`choice_boundary` 图形分支、`menu_navigation`、`result_freeze` 和 `battle_lifecycle`。给出宝物、强化同尺寸对照截图。最后汇总这三批的全量回归和十关隔离通关记录，并把每批提交号和可打开的证据路径补到本文件。

本轮把精力放在可直接验证的交互和两处明确的代码重复上。关卡难度、战场节点与每帧循环另排。自动构筑通关记录可用于回归，后四关的玩家节奏需要单独的玩法证据。


## 交付记录

### 第四批 · 结算页真实输入与生命周期（2026-11-26）

- 文件：`tools/audit_battle_navigation.gd`（新增 `_click_control` 与图形分支 `_audit_real_input`）
- 交付说明：`docs/交付_批次4_真实输入_2026-11-26.md`
- 无头：PASS，打印 `[HEADLESS] real-input branch skipped`
- 图形（`--resolution 450x800`）：PASS，打印 `[GRAPHICS] real click replay/home/save-fail/double-click/delayed-release PASS`
- 全量：88 / 88（`.shots/audit_batch4.txt`）
- 提交：__COMMIT__
