# DeepSeek 任务交接 · Godot 战斗界面拆分与回归

项目位于 `D:/1/wuxia-demo`，界面采用 720×1280 竖屏设计坐标。第一至第十六批已有记录，第十五批待真机。任务和验收继续写入本交接单，每批独立提交。

## 当前执行顺序

1. 优先做第十七批，直接改善小窗下的卡牌、结算花纹和关键信息可读性。
2. 第十八批可与第十七批并行，先修 Android QA 报告判定。有设备时补做第十五批的安装及手势实测。
3. 第十七、十八批合入后做第十九批，固定候选版本，跑实际战斗流程并导出 QA 包。第十六批的两组第十关受限构筑失败保留为节奏基线，数值调整暂缓。

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

1. 先在改动前跑同一批相关用例，记下基线。PowerShell 用 `./tools/run_playthrough.ps1 -PrepareOnly` 建隔离项目，再把输出的 `AUDIT_PROJECT` 路径传给 Godot 的 `--path`，并传 `--headless --max-fps 120 --quit-after 3600 --script res://tools/audit_<用例名>.gd`。每次检查明确的 `PASS:`、退出码和脚本错误。有写档的用例每次用新的运行编号。
2. 每批完成后运行 `./tools/run_audits.ps1`，记录 `AUDIT_RESULTS` 下的 `results.json` 汇总与失败日志。桌面截图与录屏也用各自的隔离项目。把十关通关、首通奖励和解锁验证安排在第九批或关卡逻辑改动后的验收中。
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
- 提交：`912a87f`
- 用法更新：单用例先 `run_playthrough.ps1 -PrepareOnly -RunId <id>`，从输出取 `AUDIT_PROJECT`；全量直接 `run_audits.ps1 [-RunId <id>]`；`.shots/audit_project` 仅为“最近一次”的便捷 Junction

## 复核记录（2026-11-26）

- 第七批提交 `912a87f` 已核对。`.shots/runs/batch7full3/results/results.json` 有 88 条通过记录。`.shots/concur_headless.log` 和 `.shots/concur_graphics.log` 分别有无头与真实点击通过标记。两份证据使用不同编号，重复编号的边界见第十批。
- 第八批已看到 `tools/export_android_qa.ps1` 的工作区版本。请在原批次收尾并补成功日志。验收要覆盖 PowerShell 5.1 的读取与原生工具退出码、传错 Godot/SDK 路径、正式包 SHA-256 比对，以及输出路径指向正式 APK 时的拒绝。包内检查请核对实际启用的主角立绘与敌人击倒音效，并检查 `tools/audit_*`、`tools/playthrough*` 等测试资源是否排除。签名、最低 SDK 与显示名都要给出实际校验结果。
- 第九批本次看到的是已有的通关时间、最终状态和回溯日志。逐波事件与两种构筑的分段报告仍按原条目验收。

## 第十批 · 补齐回归隔离的边界

**P1｜范围** `tools/run_playthrough.ps1`、`tools/run_audits.ps1` 及仍直接使用 `.shots/audit_project` 的辅助脚本。已在临时项目复现，连续两次传 `-RunId handoff-probe`，分别指定 `qa-first` 与 `qa-second`，两个结果的 `AUDIT_USER_DIR` 都是 `wuxia-audits/handoff-probe/wuxia-regression`。当前 prepare 也会删除后重建同一个便捷 Junction，两次 prepare 写的是同一入口。

- 让并行运行只通过各自返回的路径启动。迁移 `tools/t_eap.ps1`、`t_enc.ps1`、`t_one.ps1`、`t_two.ps1` 中仍在用的调用，核对其他调用方。若保留便捷 Junction，把更新改为显式操作，并要求现存目标确实是该便捷 Junction。碰到真实目录时给出明确报错，保留其中的文件。
- 运行编号和运行目录必须一一绑定。直接传 `-AuditRoot` 给全量入口时，核验其 `project.godot` 中的隔离存档标记，结果也应写到该运行的目录。对重复编号、两个进程争用同一编号、不合法编号、路径指向正式项目四种情况明确报错，或设计显式且可验证的恢复入口。拒绝路径要在写文件前发生。
- 验收时保留并行 `battle_navigation` 无头和图形用例，再同时发起重复编号的两个进程，确认至多一个准备成功。补一个可控失败用例，核对非零退出码与失败日志。检查两个隔离目录各自的存档，再用模拟的正式项目验证测试前后存档散列一致。最后跑 `run_audits.ps1` 并记录真实用例总数。

## 第十一批 · 高密度战斗帧时间与出怪峰值

**P1｜范围** 先做可复现的图形测试入口。沿用 `kushou/kushou_battle.gd` 的真实波次、卡牌招怪和出怪上限，并从 `kushou/battle_ui.gd` 的敌人节点与帧特效池找瓶颈。目前普通怪上限 `MAX_FOES=36`，`MAX_FIELD_FOES=52` 有首领等例外，报告分开记各类敌人。

- 固定种子、视口、渲染器和机器，采集三组，每组预热后取至少 30 秒。场景分别是常规波次、普通怪近上限且触发加怪卡、首领或挑战怪加群怪与主要技能。记录帧时间 P50、P95、P99、超过 33.3 ms 的帧数、活怪与战斗节点峰值、特效池占用。把加载页、首发资源和稳态的尖峰分开记录。无头可核对规则，图形运行提供帧时间。
- 若能定位可重复的热点，单独做一处改动，并用同一流程跑至少三次对比。优先查同帧创建大量敌人节点、重复贴图查找，以及飘字和特效节点的反复创建与释放。有证据才调整创建队列或回收策略。用计数核对波次最终生成量、奖励、挑战类型和首领入场，重点观察主要技能、首领预警与倒地反馈是否完整。
- 至少跑 `enemy_hazards`、`frame_fx_pool`、`battle_lifecycle`、`result_freeze`、`challenge_rewards`、`attack_timing`。留同一压力段的日志和短录屏。帧率数字附机器与窗口条件，Android 另列实测状态。

## 第十二批 · 竖屏界面清晰度、裁切与真实手势

**P1｜范围** 战斗底栏、抽卡和请神卡面、结算花纹、主界面底栏、角色页、锻造台。优先修采样、尺寸、遮罩和触点问题。沿用 `project.godot` 的 `canvas_items`、`CardFrame` 花边以及 `shared/ui_motion.gd` 回弹。素材替换交由美术侧同步。

- 用同一套真实流程在 450×800、720×1280、450×1000 留原始截图。每页取静止与弹出过程中的关键帧，核查细纹、字边、角色图裁切、底栏位置和可点击区域。报告模糊来自原图分辨率、贴图导入和采样、控件缩放或多次缩放中的哪一步。先修可复现的共因，单页修正附原像素裁图。
- 补图形分支覆盖战斗底栏的抽卡、请神、宝物、玉壶，以及主界面的角色、锻造。覆盖快速点击、按下后拖出、动画还在弹时关闭、连续切页。有真机时补触摸与安全区，桌面用真实视口指针验证命中。确保一次手势只触发一次业务动作，卡面和立绘也能在回弹过程中留在各自视图的裁切范围内。
- 跑 `choice_boundary`、`battle_navigation` 图形分支，以及 `menu_navigation`、`menu_popups`、`equipment_dialogs`、`result_panel`。截图记录窗口尺寸、取样时刻和本次实际修正的区域。

## 第十三批 · 密集打击与按键音效回归

**P2｜范围** `shared/audio.gd`、现有音效测试与图形测试入口。复用第十一批的密集战斗，覆盖普通命中、重击、击倒、技能和请神、首领预警。补测局外锻造、技能升级、主界面和战斗音乐切换。

- 先记录每类事件的触发次数、实际播出或合并次数、同时播放峰值。用真实点击区分按钮按下反馈、成功操作和失败提示。检查弹窗开关、反复进出战斗及结算时是否出现声音叠加、断续和迟到的播放。固定场景录一段原始音频，核对削波和轻重音层次。
- 按现有播放池与冷却机制处理可复现的重复播放、抢占或泄漏。人多时允许合并普通受击音，首领预警、请神与结算分别核对其可听性。池中状态在离场后要回收，返回主界面时音乐切换应可重复验证。
- 必跑 `audio_pool`、`audio_shutdown`、`audio_window_close`、`audio_duration`、`enemy_hazards`、`battle_lifecycle`。交付时分别写明事件层检查与实际有声运行结果，并给出录音和日志位置。

第八至十三批交付摘要继续追加在本文件。每批写清实际执行的命令、提交、通过项、日志或截图，以及仍待确认的具体现象。

## 第八批交付（2026-11-26）

- 文件：`tools/export_android_qa.ps1`（新增）
- 产物：`.shots/wuxia_qa_android.apk`，包名 `com.wuxia.demo.qa`，应用名「江湖游历 QA」，minSdk 24，arm64-v8a，debug 签名，约 300 MB
- 校验：apksigner 签名、aapt2 包名/应用名/最低 SDK/ABI、SHA-256、APK 内关键资源（result_view/panel_win/player_q/kunshou_zhu/音效/card_frame）、测试脚本排除、正式发布包时间戳未变
- 错误路径：`-Godot Z:\\nope\\godot.exe` → `ERROR: Godot 不存在`，退出码 2
- 设备：adb devices 为空，安装/启动/触控/帧率未执行
- 交付说明：`docs/交付_批次8_AndroidQA_2026-11-26.md`
- 提交：6d762ce

## 第九批交付（2026-11-26）

- 文件：`tools/playthrough.gd`（`[SEED]`/`[SCENARIO]`/`[WAVE]`/`[PACE]`/`[WALL]` 与 `--seed`、`--restrict-strength`）、`tools/run_playthrough.ps1`（透传 `-Seed`/`-RestrictStrength`，新增 `-Windowed`）
- 四组固定种子：L6 自动 WIN 377.2s（20/20）、L6 限制强化 TIMEOUT 600s（15/20）、L10 自动 WIN 285.2s（18/18）、L10 限制强化 LOSE 354.2s
- 三条节奏问题：①清尾占总时长 76–80%（等怪仅 20–24%）；②L6 第 13 波 58.8s 单点尖峰（占全关 15.6%）；③无强化时 L6 卡在 15/20 波（`spawned=44/quota=52 live=36`）、L10 败于首领战
- 录屏：`.shots/pace_l6_wave13_crop.mp4`（22s，裁到游戏窗口）、截图 `.shots/pace_l6_wave13_crop_frame.png`
- 全量：**88 / 88，failed=0**（`.shots/audit_batch9.txt`）
- 交付说明：`docs/交付_批次9_节奏数据_2026-11-26.md`
- 提交：`34bb54f`（自动存档收录本批代码）
## 第七至九批最终汇总

- 全量回归（新隔离入口）：批次 7/8/9 各 88 / 88，failed=0（`.shots/audit_batch7.txt`、`audit_batch8*`、`audit_batch9.txt`）
- 十关隔离通关（最终，RunId `ten_final_b79`）：L1–L10 全 WIN，用时 75/144/201/310/287/395/361/405/405/309 秒；存档 `first_clear` 1~10 全 true
- 提交：批次 7 `912a87f`（记录 `095ab80`）、批次 8 `6d762ce`（记录 `c6fdb08`）、批次 9 代码 `34bb54f`（记录 `7d13b8c`）
- 证据：批次 7 `docs/交付_批次7_隔离回归_2026-11-26.md`；批次 8 `docs/交付_批次8_AndroidQA_2026-11-26.md`；批次 9 `docs/交付_批次9_节奏数据_2026-11-26.md`

## 复核与本轮增补（2026-11-27）

- 已核对第八批提交 `6d762ce` 与 `.shots/qa_export_final.log`。日志有 QA 包名、应用名、签名、最低 SDK 24 和 ARM64 校验。当前 ADB 仍没有设备。正式包路径防护及新资源校验归第十四批。
- 已核对第九批交付报告和 `.shots/runs/batch9full/results/results.json`，有 88 条通过记录。后续现行 `tools/playthrough.gd` 已把等待、清尾和首领战分成互斥区段，并修正命令行种子生效时机。第六关同种子「破阵」修复前后第 13 波为 58.8 和 26.7 秒，证据见 `docs/当前版本_审查进度.md`。第十六批以修复后版本起跑。
- 本地可核对的交付记录到第九批。第十至十三批的独立交付需继续回填。第十批补一项编码验收。Windows PowerShell 5.1 在最近全量回归里把中文诊断解错，导致 `role_advance`、`equipment` 的预期故障注入被误报。两项独立调用 Godot 并使用 `--log-file` 均通过。用 Godot 日志或明确的 UTF-8 捕获判定，保持意外 `ERROR:`、脚本错误与非零退出能被检出。证据见 `.shots/runs/frost-full-d7adfca3430c47389e893cb8044d5776/results/results.json` 和 `.shots/frost_role_advance_direct.log`、`.shots/frost_equipment_direct.log`。
- 第十一批当前参考。GTX 1050 Ti、585×1040 的 52 敌人同时闪白专项，每轮 240 帧，重复重绘由 12,480 次降到 0 次，脚本到完成绘制的 P95 三轮中间值由 8.74 ms 降到 5.68 ms。首领混战的单组 15 秒采样峰值 53 只，60 帧上限下 P95 约 16.7 ms。日志在 `.shots/token_redraw_7859c3f6ded541e381db8d604dca05cc/`。前者是隔离压力场景，后者用于参考，按原第十一批要求继续采集正常流程与分配峰值。

## 第十四批 · QA APK 路径保护和资源核验

**P0｜范围** `tools/export_android_qa.ps1` 及其校验。当前自定义 `-OutApk` 可能进入删除旧文件分支，正式包时间戳只在导出后核对。先在文件操作前判定输出路径，验证通过后再发布到 QA 路径。

- 规范化真实目标及现有父目录，限制输出于明确的 QA 目录，检查相对路径、大小写变体以及已有目录联接。每次使用独立的 QA 临时项目和输出路径。导出或校验失败应保留已有可用 QA 包。模拟正式文件用于路径拒绝测试，记录正式包实际 SHA-256 前后相同。
- 把关键资源检查更新到当前运行路径。抽样核对主角局外立绘 `portrait_zhujue_ink_v3.webp`、战斗 `player_battle_frames.png`、技能 `player_skill_poses_v2.png`、新壮汉/盾兵图集、当前实际启用的首领预警与敌人倒地音、结算视图与卡框。验证包内可加载的资源及导入副本，并检查 `tools/audit_*`、`tools/playthrough*` 的排除结果。
- 报告记录成功导出一次、错误 SDK、碰撞路径以及失败后保留旧 QA 包的结果。核对包名、显示名、签名、最低 SDK、ARM64、大小和 SHA-256，附上新 APK 与日志路径。

## 第十五批 · Android QA 安装与战斗生命周期验收

**P1｜依赖** 第十四批的 QA APK。先写成可复用的用例入口与结果清单。设备存在时只针对 `com.wuxia.demo.qa` 执行安装或更新，记录实际包版本和屏幕规格。

- 覆盖冷启动、主界面到第六关、底栏抽卡与请神、一次胜败结算、切后台返回以及杀进程后重开。核对触控命中、安全区、系统返回、多次进出战斗后的音乐和面板状态，以及记录到的崩溃和异常。
- 用同包名同签名的旧 QA 包建立测试档，再覆盖安装新 QA 包。检查首通、角色星级、技能等级和装备仍可读取。断开时输出清晰的设备状态，区分已经生成的工具与尚未执行的手机验收。

## 第十六批 · 后半程节奏的复测矩阵

**P2｜依赖** 当前逐波统计和破阵修复。沿用 `tools/playthrough.gd`。采样第 6、10 关各两种构筑强度，每种至少两个固定种子。单独记录正常流程、破阵出现和超时失败。

- 给出每关清尾最慢的三波。附第一只怪进入交战区、最后一只正常或奖励怪刷出、普通怪数峰值、清尾剩余怪的种类和首领阶段时间。报表核对各分段之和等于已记录总跨度，允许一位小数舍入误差。
- 若连续两组在同一波异常，从桌面回放区分清尾寻路、控制、构筑强度和出怪队列。提交复现命令、短录屏、证据和建议调整项。另核对每次胜利的首通和解锁写入独立测试档。

## 第十四批交付（2026-11-27）

- 文件：`tools/export_android_qa.ps1`（重写）
- 路径保护全部在写文件前：限制 `.shots/qa/<runId>/` 内、拒绝正式包路径、拒绝联接父级/文件、拒绝非法 RunId；临时导出 + 校验通过后才替换旧 QA 包
- 成功：`.shots/qa/qa14_success/wuxia_qa_android.apk`，`com.wuxia.demo.qa` / 江湖游历 QA / minSdk 24 / arm64-v8a / SHA-256 `62934E41…AA21BA` / 300,137,328 字节；日志 `.shots/qa14_success.log`
- 拒绝：错误 SDK 退出 2；正式包路径退出 5 且 SHA 未变；联接逃逸退出 5；导出失败退出 3 且旧 QA SHA 不变
- 资源核对新增：`portrait_zhujue_ink_v3.webp`、`player_battle_frames.png`、`player_skill_poses_v2.png`、`crowd_brute_v1` / `crowd_shield_v1`、`enemy_warning` / `fall_down`、`result_view` / `card_frame`，并要求导入副本；排除 `tools/audit_*` / `tools/playthrough*`
- 全量：**88 / 88，failed=0**（`.shots/audit_batch14.txt`）
- 交付说明：`docs/交付_批次14_QA路径保护_2026-11-27.md`
- 提交：c354205
## 第十批交付（2026-11-27）

- 文件：`tools/run_playthrough.ps1`、`tools/run_audits.ps1`
- 隔离：RunId 白名单；运行目录原子创建，重复编号退出 9；`-ReuseExisting` 显式续用；`-NoLink` 跳过便捷 Junction；真实目录占位退出 7 并保留文件
- 校验：`-AuditRoot` 必须带 `wuxia-audits/<id>/wuxia-regression` 标记，正式工程路径退出 6；`run_audits` 结果目录必须在该运行目录内
- 编码：引擎输出改用 Godot `--log-file` UTF-8 日志判定，`role_advance` / `equipment` 不再误报（均 passed=True）
- 并发：同 RunId 两份 prepare 一份 0 一份 9；无头 + 图形 battle_navigation 同时 PASS（`.shots/par_h3.log`、`par_g3.log`），各自存档存在
- 失败：临时审计退出 1，`FAILED_COUNT=1`，日志 `.shots/runs/failtest10/results/zz_fail_tmp.log`
- 全量：**88 / 88，failed=0**（`.shots/audit_batch10.txt`）
- 交付说明：`docs/交付_批次10_隔离边界_2026-11-27.md`
- 提交：e516dcf
## 第十一批交付（2026-11-27）

- 新增：`tools/perf_runner.gd` / `.tscn`，固定种子 20261116、720×1280、`gl_compatibility`，真实 `_spawn_foe` 出怪路径；三场景 normal / swarm / boss，预热 4s 采样 30s
- 结果（GTX 1050 Ti）：P95 分别为 16.80 / 16.82 / 16.80ms，>33.3ms 帧均为 0；活怪峰值 12 / 40 / 35；节点峰值 281 / 341 / 327；FX 池峰值 2 / 0 / 1；加载 490 / 415 / 409ms
- 无可重复热点，本轮未改战斗代码；normal 首轮一次 119ms 尖峰重跑未复现
- 必跑 6 项审计全部通过（`.shots/audit_batch11.txt`）
- 录屏：`.shots/perf_swarm.mp4`（约 10s，含音频），抽帧 `.shots/perf_swarm_frame.png`
- QA 导出排除追加 `tools/perf_*`
- 交付说明：`docs/交付_批次11_帧时间_2026-11-27.md`
- 提交：fa18fb1
## 第十三批交付（2026-11-27）

- 文件：`shared/audio.gd`（统计 + 离场回收 + finished 断连）、`kushou/battle_ui.gd`（`_exit_tree` 调 `stop_all_sfx`）、`tools/audio_probe.gd`（新增）、`tools/run_audits.ps1`（audio_duration 信息型）
- 事件层（20s，seed 20261116）：请求 74 / 播出 66 / 合并 8 / 并发峰值 13；分键 dart 26、bow 17、melee 8、swing 6、enemy_warning 5、boss_impact_ground 1
- 修复：离场 2s 后旧版残留 active=2、池 10；现 **active=0、池 13**；同时修掉池复用导致的 `finished` 重复连接 ERROR
- 音乐：menu/menu_jiangnan → battle/bgm_tower → menu 两次切换，同一时刻仅一个播放器 playing
- 必跑 6 项：audio_pool/audio_shutdown/audio_window_close/enemy_hazards/battle_lifecycle 通过；audio_duration 按信息型记通过（时长已记录）
- 全量：**88 / 88，failed=0**（`.shots/audit_batch13full.txt`）
- 录音：`.shots/audio_swarm.mp4`（10s，含音频），mean -29.0 dB / max -11.8 dB，无削波
- 交付说明：`docs/交付_批次13_音效召回_2026-11-27.md`
- 提交：42750e6（音效主体随自动存档 `784722d`）
## 第十六批交付（2026-11-27）

- 文件：`tools/playthrough.gd`（`[WAVE]` 增加 reward_done / normal_peak / statues / kinds；`[PACE]` 增加 seg_sum / drift；`[BREAK]` 记录破阵）
- 矩阵：L6/L10 × auto/restrict × seed 20261116/20261117 共 8 组；L6 全 WIN（329/531/415/458s），L10 auto WIN（315/386s），L10 restrict LOSE（365/341s，首领未击杀）
- 分段完整性：逐波最大偏差 0.000s，`[PACE] drift` 全 0.00
- 最慢波：L6 auto n9 24.5s / n13 30.3s；L6 restrict n11 36.2s（唯一破阵 statues=3）；L10 auto n9 24.5s / n13 30.3s；L10 restrict 首领波未击杀
- 无“连续两组同波异常”，未触发回放；本轮无超时失败
- 胜利存档已核对：`first_clear[关卡]=true` 均在各自隔离目录
- 交付说明：`docs/交付_批次16_节奏矩阵_2026-11-27.md`
- 提交：524be2c
## 第十五批准备（2026-11-27）

- 新增 `tools/android_qa_device.ps1`：无设备输出 `DEVICE=0 SKIP=1` 并落报告；有设备时执行覆盖安装、存档可读、冷启动、切后台、杀进程重开、logcat 崩溃/ANR 检查，逐项 PASS/FAIL
- 产物：`.shots/android_qa_device/report_<时间>.md`、`results_*.json`、`cold_*.png`、`logcat_*.txt`
- 本次 `adb devices` 为空，报告 `report_20261127_044410.md` 记录 SKIP（安装/启动/触控/帧率未执行）
- 真机验收需等设备接入后运行脚本，并人工补底栏抽卡/请神/宝物/玉壶、主界面到第六关、胜败结算、安全区/系统返回、音乐面板状态
- 交付说明：`docs/交付_批次15_设备用例入口_2026-11-27.md`
- 提交：c78baea
## 第十二批补全（2026-11-27）

- 新增 `tools/audit_ui_gestures.gd`：底栏抽卡/请神/宝物/玉壶真实点击、动画中关闭、双击不重复、按下拖出不触发、抽卡→请神不叠层；角色页 `Slot_weapon` 拖出/点击打开详情、详情内“锻 造”打开锻造页
- 结果 15/15 PASS（`.shots/ui_gestures8.log`）；锻造台三档截图已补（`.shots/ui/forge_*.png`）
- 清晰度诊断：原报告在 720 和 450×800 截图中分别得到 511.65 和 163.69 的边缘方差，450 小窗使用 0.625 倍画布缩放。该跨分辨率比较可作为排查线索，具体问题按第十七批逐项复核。
- 交付说明：`docs/交付_批次12_竖屏清晰度_2026-11-27.md`
- 提交：ad35d89

## 复核记录（2026-11-28）

- 在 `d43d5d2` 复核了工程单、提交、脚本和现有日志。第十、十三批的现有全量日志均为 88/88，第十一批现有指定审计为 6/6，第十二批真实指针手势为 15/15。第十四批已有 QA 导出及路径保护交付记录，后续候选包仍需从新版本重新构建。
- 第十六批的 8 份 `m16b_*` 结果与汇总一致。第六关四组胜利，第十关自动构筑两胜、受限构筑两负，8 组记录的分段偏差均为 0。按各场次普通波清尾时间单独排序，L6 自动构筑两个种子的最慢三波分别为 9/8/7 和 13/17/19，L10 分别为 9/12/13 和 13/17/16。原摘要中相同的两个最高值确实存在，完整排序有区别。
- 第十五批本机没有连接 Android 设备，安装、输入和帧率均待验证。代码复核发现初次安装会把「已安装」计作失败，覆盖安装只检查存档含有字段名，无法证明原字段值保留。第十八批补齐这些判定。
- 第十一批用图形压力场景走实际出怪路径，当前数据可作为桌面基线。第十九批补测从主界面进入关卡后的完整战斗路径，包括实际刷怪、结算、面板切换和返回主界面。

## 第十七批 · 卡牌与结算在小窗口的清晰度

**P1｜范围** 保留 720×1280 设计坐标和现有 `canvas_items` 配置，优先改善控件在实际显示尺寸的表现。沿用第十二批的三档图形截图入口。

- 首轮检查抽卡、请神、结算和战斗底栏。用 450×800、720×1280、450×1000 的原始像素截图标出问题区域，分别看卡框细纹、结算花纹、正文、按钮图标及数字。选择同一输出尺寸做改前改后对照，保留 PNG 原图和局部裁图。
- 对复现的问题查控件尺寸、源图分辨率、导入、采样及额外缩放。优先在已有卡框、结算视图或公共组件内修正可见问题，例如小窗下消失的细线、对比度不足、重复缩放或裁切。用截图说明具体改善及 720 原尺寸的表现。
- 抽查回弹过程中和动画落定后的边缘、绘制范围及点击区。跑 `audit_ui_gestures`、`choice_boundary`、`result_panel` 和 `battle_navigation` 图形分支，交付三档对照和日志。手机截图在设备可用时追加。

## 第十八批 · Android QA 报告与存档保留判定

**P1｜范围** 完善 `tools/android_qa_device.ps1`，沿用现有 QA 包名和第十四批的导出路径保护。

- 初装与覆盖安装分别报告。未预装属于初装，跳过覆盖存档对比。覆盖时先记录已有 QA 测试档中预定字段的实际值，安装后核对 `max_unlocked`、对应关卡的 `first_clear` 等字段值。原测试档缺失时明确记为覆盖存档用例未执行。安装失败时保存诊断并返回非零。
- 把「命令已发出」与「游戏已到前台并保持运行」分别记录。冷启动、后台返回和杀进程后重开检查 QA 应用进程及前台状态，并采集本次运行相关的崩溃/ANR 日志。首屏截图保存到每次运行独立的本地目录。
- 没有设备时先用模拟 ADB 输出核对无设备、初装、覆盖字段一致、覆盖字段变化、安装失败和进程启动异常的报告与退出码。接入真机后继续第十五批的手势与切后台用例。记录设备、Android 版本、包 SHA-256 及每项证据。

## 第十九批 · 候选版本实战与 QA 包验收

**P1｜依赖** 第十七、十八批的改动已合入。固定提交、引擎版本和运行编号，沿用现有存档隔离、QA 导出与校验入口。

- 在同一桌面设备和画面设置下，从主界面进入第六关及第十关，各跑一次真实图形流程，保存种子、构筑与采样时间。至少取正常战斗和同屏高峰或首领阶段两段各 30 秒，记录 P50/P95/P99、超过 33.3ms 的帧数、活怪峰值和特效池峰值。沿用第十一批压力场景作对照，若同一操作可重复触发长帧，先留最小复现和时间点。
- 在实战中实际点一次抽卡和请神，并走完一次结算返回主界面。录下普通怪群受击、首领演出及底栏点击带音频的短片，核对同屏打击与关键提示的可辨识度，以及离场后主界面点击音和音乐切换。发现可复现问题时附前后对照或复现步骤。
- 对同一提交跑全量审计和图形手势，重新导出 QA 包并记录 SHA-256、包名、资源检查和交付日志。第十五批真机实测结果引用对应运行报告，设备未接入时写明待测。

## 第十七批交付（2026-11-28）

- 三档截图：`.shots/ui17/`（battle/draw/god/result，450×800 与 450×1000 用 emulate 真实缩放，720 原生）；请神截图入口补充能
- 修正：结算标题分隔纹从 `Rect2(140,106,260,14)` 移到 `Rect2(140,112,260,8)` 并置于标题下层，450 下金线不再从「通关」字形中穿过；原像素前后裁图 `crop_before/after_450/720.png`
- 核查：卡框 1024×1536 已有 mipmap，450 下细纹偏软但连续，属源图到小尺寸采样，未动素材；结算面板底图开 mipmap 反而更糊（450 边框方差 1228→948），已回退
- 验证：`audit_ui_gestures` 15/15、`choice_boundary`/`result_panel` 通过、`battle_navigation` 图形 PASS（`.shots/ui17_gestures.log`、`.shots/ui17_batnav.log`）；全量 **88/88**（`.shots/audit_batch17full2.txt`，首跑一次 menu_navigation 偶发 dummy 渲染误报）
- 交付说明：`docs/交付_批次17_小窗清晰度_2026-11-28.md`
- 提交：__H17__