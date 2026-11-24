---
name: jianghu-ui
description: 《江湖游历》的 UI 实现规范（从现行代码提炼）：720×1280 版式分区、水墨纸面配色、panel/button 构件、按压与入场动效时长、字体与音效挂点、以及“必须复用 ui_kit”的硬规则。当用户要在这个工程里改界面、加页面、调按钮动效、统一风格时使用。
whenToUse: 改动 menu/ 下任何页面、kushou 战斗 HUD、或新增弹窗/按钮/列表之前；接手 UI 换皮也先读它，别翻归档的旧换皮文档（那些引用的是已删除的 menu_theme.gd）。
---

# 江湖 UI 规范（现行版）

来源：`shared/ui_kit.gd`(17.6 KB)、`shared/ui_pal.gd`、`shared/ui_motion.gd`。
旧文档 `docs/_archive/UI换皮_设计规范_v200.md` 描述的是已删除的 `menu/menu_theme.gd`，**只作历史参考**。

## 1. 画布与分区（硬约束）

| 量 | 值 | 说明 |
|---|---|---|
| 画布 | **720 × 1280** | 竖屏；ui_kit 里 `W / H` |
| 顶栏 | y 0 – 90 | `TOP_H`，头像/名号/设置 |
| 页头 | 高 62 | `HEAD_H`，标题行 |
| 内容区 | y 152 – 1176 | 主内容 |
| 底栏 | y 1176 – 1280 | `DOCK_Y / DOCK_H=104`，导航三钮 |

新页面按这套分区摆，不要自定安全区。

## 2. 配色（shared/ui_pal.gd）

| 常量 | 值 | 用途 |
|---|---|---|
| `PAPER` | (0.949,0.929,0.886) ≈ #F2EDE2 | 纸面底 |
| `PAPER_HI` | (0.980,0.969,0.937) | 高亮纸面 |
| `INK` | (0.133,0.129,0.149) ≈ #222126 | 主文字 |
| `DIM` | (0.459,0.412,0.361) | 次要文字 |
| `GOLD` | (0.780,0.580,0.220) ≈ #C79438 | 金线/强调 |
| `GOLD_HI` | (0.886,0.718,0.412) | 高亮金（标题字） |
| `SEAL` | (0.549,0.200,0.122) | 朱砂（印章/危险） |
| `DARK` / `DARK2` | (0.086,0.075,0.067) / (0.180,0.157,0.129) | 墨底 |
| `LINE` | (0.839,0.784,0.690) | 分隔线 |
| `RED` / `GREEN` | (0.784,0.231,0.169) / (0.235,0.478,0.290) | 增减数值 |
| `P.quality(i)` | 5 档品质色 | 装备/卡牌品质描边 |

一律 `P.xxx` 引用，不要写死 `Color(0.78,0.58,0.22)` 之类。

## 3. 构件（必须复用）

```gdscript
UiKit.panel(root, rect, bg_col, radius := 8, border := transparent, bw := 0)
UiKit.button(root, text, rect, font_size, bg_col, fg_col, callable, border, bw, radius := 8)
UiKit.label(root, text, pos, size, font_size, color, align)
```

- `button()` 内部已处理：normal / hover（提亮 7%）/ pressed（压暗 6%）、`focus_mode = NONE`、自动挂 `Motion.bind_button()` 按压反馈
- **不要**再手写 StyleBoxFlat、不要另起按钮工厂；缺的形态加点参数或加新 static 函数，别复制一份
- 文字一律用 `Label`（`ui_kit.label`），不要用 RichTextLabel 画普通文本
- 弹窗/面板用 `panel()` 的圆角 8 + 描边，需要金线时 `border = P.GOLD, bw = 1`

## 4. 动效（shared/ui_motion.gd）

| 场景 | 参数 |
|---|---|
| 按钮按压 | scale → 0.965，**0.065 s**，TRANS_QUAD / EASE_OUT |
| 松手回弹 | scale → 1.0，**0.18 s**，TRANS_BACK / EASE_OUT |
| 卡片入场 | position 0.31 s CUBIC OUT；rotation → 0 0.30 s；scale 1.055→0.99→1.0（0.18 / 0.085 / 0.095 s） |
| 常驻呼吸 | scale 1.007 ↔ 1.0，各 1.2 s，SINE IN_OUT |
| 点击音 | `Audio.sfx("ui_click", -13.0)` |

规则：只缩放**绘制**，不缩点击区域（`RenderingServer.canvas_item_set_transform`）；动效不阻塞业务回调。

## 5. 字体

`fonts/ink.ttf`（毛笔），`P.FONT`；ui_kit 主题默认字号 **20**，标题 24–26，按钮 16–20。
长文案溢出优先缩字号或加滚动，不要改版式。

## 6. 改 UI 的检查清单

1. 是否复用了 `ui_kit` 的 panel/button/label？有没有新造 StyleBox？
2. 颜色是否全部来自 `P`？
3. 位置是否落在 0–90 / 152–1176 / 1176–1280 分区内？
4. 按钮是否有按压反馈与点击音（`button()` 自带）？
5. 720×1280 下字号够不够？中文 16 号是下限。
6. 跑一次 `--check-only` 编译 + 冒烟（见 jianghu 技能的 verify）。
