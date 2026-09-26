# 江湖游历

Godot 4.7.2 竖屏放置武侠游戏。主场景 `menu_sketch.tscn`。

## 目录结构

| 目录 | 内容 |
|---|---|
| `menu/` | 主界面、爬塔战斗、各功能面板 |
| `journey/` | 游历玩法（走路 / 节点 / 遭遇 / 结算 / 战斗演出 / 火柴人动画） |
| `shared/` | 数据表与全局状态（卡表 / 词缀 / 状态 / 天赋 / 存档） |
| `kushou/` | 「困兽」独立模式（开发中） |
| `docs/` | 设计文档 |
| `tools/` | 构建与自动化脚本 |

## 版本控制与备份

由 Windows 计划任务 **`wuxia-autocommit`** 每 30 分钟自动执行一次
（脚本 `tools/autocommit.ps1`，任务定义 `tools/autocommit-task.xml`，
日志 `.git/autocommit.log`）：**有改动才提交，没改动不产生空提交**，
然后把提交推送到全部远端。

| 远端 | 位置 | 作用 |
|---|---|---|
| `origin` | Gitee 私有仓库 | 异地备份 |
| `backup` | `E:\wuxia-backup.git` | 本机第二副本（裸仓库） |

手动存档一次：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\1\wuxia-demo\tools\autocommit.ps1
```
