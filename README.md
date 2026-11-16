# 江湖游历

Godot 4.7.2，竖屏 720×1280。当前接入玩法为「困兽」，主场景 `res://menu/main_home.tscn`，经加载页进入 `res://kushou/battle_ui.tscn`。

以当前代码和现行设计稿为准。旧游历、修村等玩法已搁置，不按旧文档恢复。

## 运行

用 Godot 打开本目录 project.godot，运行主场景。当前配置为 720×1280 视口、450×800 默认窗口、viewport 拉伸、Compatibility / OpenGL 渲染。

## 当前流程

- 主界面选择已解锁关卡；底栏进入装备、请神与奇物页。
- 十关教学包含波次、首领、功能解锁与首通奖励，配置位于 shared/level_state.gd。
- 战斗已接入自动出手、抽卡组合、强化进阶、请神家传、奇物、挑战与黑市。
- 局外已接入装备锻造出售、技能升级、角色进阶、奇物强化携带；部分背包和配置入口仍有占位内容。

## 已确认规则

- 家传：0 星开放初档，每升一星开放下一档，最高 5 星；局内仍逐档集齐三张成组。
- 装备：第八关解锁后建场应用；攻击与气血按装备数值增加，每点防御提供 3% 非真实固定减免，每点披风速度提供 1% 攻速。最终减免上限沿用核心规则。
- 内力：核心属性层统一管理，基础 100，每级上限 +25；卡牌加成进入同一层。
- 奇物：单件携带、固定五级；材料和来源待设计，当前页面免费强化。
- 锻造：淬火油提高下一锤成功/大成功权重各 1.5 倍，不叠加。撤销恢复未碎装备上一锤快照，不退材料；使用其他道具后旧撤销记录失效。

## 存档

user:// 下使用 level_state.cfg、progress.cfg、forge.cfg、curio.cfg、audio.cfg。先写临时文件再替换；跨文件奖励使用 reward_pending.cfg 快照日志恢复，不应手动删除未完成日志。读档/结构校验异常时保留原文件并禁止覆盖；尚无自动修复和备份恢复界面。

## 验证

```powershell
./tools/run_audits.ps1
./tools/run_playthrough.ps1
./tools/run_playthrough.ps1 -StartLevel 5 -EndLevel 5
# 独立后期关卡构筑可能较慢，可延长测试观察时间（默认420秒）
./tools/run_playthrough.ps1 -StartLevel 6 -EndLevel 6 -TimeoutSeconds 600
# 指定奇物及等级（仅影响隔离测试进程）
./tools/run_playthrough.ps1 -StartLevel 6 -EndLevel 6 -TimeoutSeconds 600 -Curio tongjing -CurioLevel 5
```

测试入口使用隔离项目及存档。集中用例结果在 .shots/audit_results。不要并发运行会重配同一 .shots/audit_project 的测试入口。专项关卡测试不等同于正常从第一关成长过去。断言通过不等于日志无警告或所有体验已验收。

## 维护与剩余事项

shared/ 为数据、状态、属性与保存；menu/ 为局外页面；kushou/battle_ui.gd 为战斗界面与构筑流程；kushou/kushou_battle.gd 为战斗核心。

[审查记录](docs/当前版本_审查进度.md) 保存修复和证据，按时间先后理解追加记录。

[旧 README](docs/README_旧版说明_2026-11-16.md) 保留历史维护与备份资料，未重新核验，不能作为当前功能清单。

正常窗口关闭与实战工具退出已接入音频清理；最近一次隔离存档十关回归全部通关，退出日志无 ERROR/WARNING（具体修改覆盖范围见审查记录）。46 项专项断言通过，部分直接退出的专项仍有资源诊断，不能据此宣称所有退出路径均已解决。

仍需处理：绕过清理的退出路径、尚未逐项核对的技能/奇物效果、完整手动教学交互、长期运行与移动端性能。桌面短时压力结果不代表移动端或长期稳定性。
