# DeepSeek 任务交接 · Godot 战斗界面拆分与回归

项目位于 `D:/1/wuxia-demo`，界面采用 720×1280 竖屏设计坐标。第一至第六批已交付，证据见本文件的交付记录及 `docs/交付_总报告_批次4-6_2026-11-26.md`。本轮从第七批开始，每批独立验收和提交。任务与后续交付摘要继续记在这一份交接单里。

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

### 第六批 · 宝物/强化共用选卡面板（2026-11-26）

- 文件：新增 `kushou/choice_panel_view.gd`；删除 `treasure_view.gd` / `aug_view.gd`；`battle_ui.gd` 改型并分别 `configure("宝物","选择一件")` / `configure("进阶","")`
- 交付说明：`docs/交付_批次6_共用选卡面板_2026-11-26.md`
- 对照：同尺寸 596×1061，标题带/按钮带像素差 **0**（宝物、强化各一组）
- 验证：treasure_flow、aug_limits、choice_boundary（无头+图形）、menu_navigation、result_freeze、battle_lifecycle 全 PASS；全量 88/88（`.shots/audit_batch6.txt`）
- 提交：`1078ded`（自动存档一并收录；本批内容在该提交内）

### 第五批 · DrawCard 迁出（2026-11-26）

- 文件：`kushou/draw_card.gd`（新增 81 行）；`battle_ui.gd` 删除内部类 75 行
- 交付说明：`docs/交付_批次5_DrawCard迁出_2026-11-26.md`
- 对照：固定种子 seed(20261126)，静止/炫卡/飞入三帧卡面区域像素差 **0**
- 验证：choice_boundary（无头+图形）、draw_claim、menu_navigation、battle_lifecycle 全 PASS；全量 88/88（`.shots/audit_batch5.txt`）
- 提交：2b78b9f

### 第四批 · 结算页真实输入与生命周期（2026-11-26）

- 文件：`tools/audit_battle_navigation.gd`（新增 `_click_control` 与图形分支 `_audit_real_input`）
- 交付说明：`docs/交付_批次4_真实输入_2026-11-26.md`
- 无头：PASS，打印 `[HEADLESS] real-input branch skipped`
- 图形（`--resolution 450x800`）：PASS，打印 `[GRAPHICS] real click replay/home/save-fail/double-click/delayed-release PASS`
- 全量：88 / 88（`.shots/audit_batch4.txt`）
- 提交：0c76904

## 最终汇总（三批全量与十关）

- 全量回归：批次 4/5/6 各跑一次 `run_all_audits.ps1`，均为 **88 / 88，FAILED_COUNT=0**（`.shots/audit_batch4.txt` / `batch5.txt` / `batch6.txt`）
- 十关隔离通关（最终）：L1–L10 全 WIN，用时 75/144/201/327/300/367/359/330/380/453 秒；存档 `max=10`、`first_clear` 1~10 全 true、碎片七人各 135（主角 195）（`.shots/run_tenlevel_final.txt`）
- 证据汇总：`docs/交付_总报告_批次4-6_2026-11-26.md`
- 提交：批次 4 `0c76904`、批次 5 `2b78b9f`、批次 6 代码随 `1078ded`（文档 `68b2561`）

## 第七批 · 并行回归的隔离存档与日志

**优先级 P1，先做。** 当前 `tools/run_playthrough.ps1 -PrepareOnly` 和 `tools/run_audits.ps1` 会写入固定的 `.shots/audit_project/project.godot`。两个回归进程同时准备目录时，后启动的进程可能改掉前一个进程后续用例的存档路径。结算导航的无头与图形分支也需要各自的干净存档。

- 修改这两份脚本，让每次运行得到各自的测试项目、`user://` 目录和结果目录。命令输出实际项目路径和结果路径，保留 `-PrepareOnly`，同步更新本交接单里的用法。可以复用共享的只读源码和导入缓存。先盘点仍依赖固定路径的脚本，再迁移受影响的入口。
- 初次测试同时跑两份 `battle_navigation`，无头和图形各一份。确认进程实际启动的项目路径不同，两边使用不同的测试装备和首通记录，退出后读回各自存档。再验证两份阻塞或失败日志各写各的。全量 88 项需在新入口跑一遍，失败仍需以非零退出码返回。
- 使用 `wuxia-regression` 测试目录后缀，沿用现有安全门槛。默认保留当前测试证据。运行与清理均以明确的测试目录为作用范围。

## 第八批 · 可复用的 Android QA 导出与校验

**优先级 P1。** 将本机已成功的独立包导出过程做成仓库里的 PowerShell 入口，例如 `tools/export_android_qa.ps1`。以当前 production preset 为模板生成 QA 配置。现有对照包是 `.shots/wuxia_qa_android.apk`，当前发布包是 `D:/1/wuxia-export/wuxia.apk`。

- 使用应用 ID `com.wuxia.demo.qa` 和显示名「江湖游历 QA」，输出到独立的 `.shots/` 路径，保留正式应用 ID、发布文件、签名设置及玩家存档。允许传入 Godot 和 Android SDK 路径。安装、卸载和清数据均排除在本批的默认运行范围之外。
- 成功时核对签名、包名、ARM64、最低 SDK、SHA-256，以及 APK 中真正包含卡框、主角新版立绘、任一新首领图集、预警与击倒音效、结算视图。项目的临时探针和测试目录排除在 APK 外。故意传一次错误路径，确认失败提示和退出码明确，发布包时间戳保持一致。
- 报告中写明有无设备。导出、签名和包内容可以在无设备时验收，安装、启动、触控和帧率各自记实测结果。目前 SDK 位于 `D:/Android`，ADB 暂无连接设备。

## 第九批 · 后半程节奏数据与复现工具

**优先级 P2。** 在现有 `tools/playthrough.gd` 或其配套脚本增加可复现的分段报告，解释第 6–10 关时间花在何处。上一批的十关记录仅有全关通关时间，例如第 6 关 367 秒、第 10 关 453 秒。这些数字来自自动构筑。

- 逐波输出进场、第一只怪抵达交战区、最后一只怪刷出、清尾结束、首领入场与死亡。尽量沿用真实的波次状态、出怪队列、击杀和首领事件，标出超时及倒地。同一格式汇总每关的刷怪等待、清尾和首领战时长。为报告附上关号、种子、构筑场景、自动策略和执行用时。
- 用固定种子至少跑第 6 关与第 10 关各两次，记录自动构筑和限制强化的两种场景。各场景使用独立存档，报告有通关或失败结果及卡住的位置。用总时长和波数检查分段完整性。再挑最慢的一段，用真实桌面流程录一小段，便于判断是等怪、清场耗时还是连续无输入。
- 这一批只改测试和证据输出。关卡波数、怪物生命、奖励、卡池、存档规则及正式场景接线沿用当前版本。交付时列出最多三条有证据的节奏问题，供下一轮选择调参。

第七至九批的验收报告继续追加到本文件。每批附上对应提交、命令、实际日志路径和验证范围。

---

## 第七批交付（2026-11-26）

- 文件：`tools/run_playthrough.ps1`、`tools/run_audits.ps1`、`.shots/run_all_audits.ps1`
- 每次运行独立：项目 `.shots/runs/<runId>/audit_project`、user `wuxia-audits/<runId>/wuxia-regression`、结果 `.shots/runs/<runId>/results`
- 输出：`AUDIT_RUN_ID` / `AUDIT_PROJECT` / `AUDIT_USER_DIR` / `AUDIT_RESULTS`；保留 `-PrepareOnly`；新增 `-RunId`、`-AuditRoot`、`-ResultRoot`
- 并发验证：runA 无头 + runB 图形同时跑 `battle_navigation`，两者 PASS（各带 `[HEADLESS]` / `[GRAPHICS]` 标记），项目/存档/日志互不覆盖（`.shots/concur_headless.log`、`.shots/concur_graphics.log`）
- 全量：新入口 **88 / 88，failed=0**（`.shots/audit_batch7.txt`、`audit_batch7c.txt`）
- 交付说明：`docs/交付_批次7_隔离回归_2026-11-26.md`
- 用法更新：单用例先 `run_playthrough.ps1 -PrepareOnly -RunId <id>`，从输出取 `AUDIT_PROJECT`；全量直接 `run_audits.ps1 [-RunId <id>]`；`.shots/audit_project` 仅为“最近一次”的便捷 Junction
