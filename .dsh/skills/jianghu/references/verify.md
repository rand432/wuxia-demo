# 验证与回归

## 冒烟

```powershell
$godot = 'C:\Users\zq300\Desktop\Godot_v4.7.2-stable_win64.exe'
& $godot --headless --path D:\1\wuxia-demo --quit-after 240
```

## 单文件编译检查

```powershell
& $godot --headless --path D:\1\wuxia-demo --check-only --script res://menu/main_home.gd
```

## 全量审计

```powershell
./tools/run_audits.ps1
./tools/run_audits.ps1 -Godot 'C:/Users/zq300/Desktop/Godot_v4.7.2-stable_win64.exe'   # 换引擎路径
```

- 入口先 `run_playthrough.ps1 -PrepareOnly` 生成隔离项目 `.shots/audit_project`
- 每个用例：`--headless --script res://tools/audit_<name>.gd`
- 结果：`.shots/audit_results`

## 十关通关

```powershell
./tools/run_playthrough.ps1 -StartLevel 1 -EndLevel 10
./tools/run_playthrough.ps1 -StartLevel 5 -EndLevel 5
./tools/run_playthrough.ps1 -StartLevel 6 -EndLevel 6 -TimeoutSeconds 600 -Curio tongjing -CurioLevel 5
```

## 规矩

1. **不要并发**跑会重配 `.shots/audit_project` 的入口。
2. 跑探针前备份 `%APPDATA%\Godot\app_userdata\江湖游历\save.cfg`，跑完还原。
3. 断言通过 ≠ 日志无 ERROR/WARNING；看退出日志。
4. 专项测试 ≠ 从第一关正常成长；抽查要手动跑一遍。
5. 关窗口/退出的音频清理有专项（`audit_audio_shutdown`、`audit_audio_window_close`）。
