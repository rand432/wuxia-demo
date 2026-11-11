# 炫卡视频（shiny）

12 段炫卡出场视频，由外部 AI 生成，已转成 Godot 唯一支持的 **Theora (.ogv)**。

## 规格

| 项 | 值 |
|---|---|
| 分辨率 | 720×1280（竖屏，与游戏一致） |
| 帧率 | 24 fps |
| 时长 | 5.06 秒 |
| 编码 | Theora (libtheora, q5) |
| 音频 | **已去除**（游戏自己播 sfx/bgm） |
| 总体积 | 16.8 MB |

## 文件 ↔ 卡牌

| 文件 | 卡牌 | 代码 id | 背景 | 备注 |
|---|---|---|---|---|
| shiny_zl.ogv | 噬雷 | `shiny_zl` | 宣纸 | 金色闪电 |
| shiny_cuisanniang.ogv | 吞海 | `shiny_cuisanniang` | 宣纸 | |
| shiny_jicanghai.ogv | 焚天 | `shiny_jicanghai` | 宣纸 | |
| shiny_backwash.ogv | 回潮 | `shiny_backwash` | 宣纸 | |
| shiny_zhujue.ogv | 剑魄 | `shiny_zhujue` | 宣纸 | |
| shiny_gundilong.ogv | 滚山 | `shiny_gundilong` | 偏暗 | 泥流碎石 |
| shiny_zhiyuan.ogv | 千纸 | `shiny_zhiyuan` | 宣纸 | |
| shiny_qingluan.ogv | 万刃 | `shiny_qingluan` | 宣纸 | |
| shiny_liuqingqing2.ogv | 百草 | `shiny_liuqingqing2` | 宣纸 | |
| shiny_mingzhu.ogv | 不灭之灯 | `shiny_mingzhu` | 宣纸 | |
| shiny_chenshi2.ogv | 石殒 | `shiny_chenshi2` | 宣纸 | |
| shiny_zhongli.ogv | 重利 | `shiny_zhongli` | **暗底** | 紫色墨云 |

## 处理说明

- **宣纸底那 10 段**用 `colorlevels=rimax=0.886:gimax=0.869:bimax=0.895` 提亮了约 13%，
  把原片背景 (210,200,185) 对齐到游戏背景 (237,230,209)。
- 按用户提供的**生成顺序**映射：无编号=第1张(噬雷) … (11)=第12张(重利)。
- **重利 / 滚山** 背景偏暗、**没提亮** —— 播放时用**正常混合**，当暗色过场看。
  （试过加色混合：在纸色背景上会被冲成一片白，已放弃。）

## 在 Godot 里怎么用

```gdscript
var p := VideoStreamPlayer.new()
p.stream = load("res://assets/video/shiny/shiny_zl.ogv")
p.expand = true              # 铺满
p.position = Vector2.ZERO
p.size = Vector2(720, 1280)
add_child(p)
p.play()
// 播完自动 free，或到 5 秒收掉
```

> ⚠ Godot 4.7 官方构建**只支持 Theora**（`VideoStreamTheora`），
> `VideoStreamWebM` 这个类是**不存在**的 —— 别拿 webm 试。

## 已接入游戏

`battle_ui.gd` 的 `_play_shiny_video(kind)`：拿到炫卡时

**起手（0 ~ 0.12 秒，战斗仍在跑）**：
- `_core.Shake_add(13)` 震屏
- `_core._hitstop = 0.10` 顿帧
- 白闪（0.04s 起 / 0.20s 落）
- `drum` 音效

**正文（0.12 秒起）**：
1. 冻结战斗（`_core.running = false`）
2. 播放视频：淡入 0.15s → 保持 2.55s → 淡出 0.5s（**约 3.2 秒**）
3. 结束自动 `queue_free` 并恢复 `running`

> 冻结点必须在 0.12 秒之后 —— 否则震屏/白闪会一起冻住，看不到那一下"起手"。

`_shiny_present(kind)` 里：**有视频就播视频**（音效/音乐照旧），没有才退回程序化动画。
