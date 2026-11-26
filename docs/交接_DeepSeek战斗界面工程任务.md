# DeepSeek 任务交接 · Godot 战斗界面拆分与回归

请独立完成下面三个批次的代码、验证和交付。项目位于 `D:/1/wuxia-demo`，当前版本为 720×1280 竖屏。优先完成结算页。之后依次处理抽卡和战斗弹窗，每批独立验收和提交。

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
