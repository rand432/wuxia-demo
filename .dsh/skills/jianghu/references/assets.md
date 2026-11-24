# 素材与命名

## 目录

| 目录 | 放什么 |
|---|---|
| `assets/char/` | 角色立绘与切片（`chen_shi.png` / `_face` / `_full` / `_q`），`art_manifest.json` 是索引 |
| `assets/gen/char/` | AI 生成的角色原图（`_vidin_*` 是图生视频输入帧） |
| `assets/gen/cards/` | 卡面（`card_sword.png`、`card_wind.png`…） |
| `assets/items/`、`assets/items2/` | 道具/宝物图标（`chest_*`、`art_*`、`mat_*`、`fate_*`、`loot_*`） |
| `assets/ui/` | UI 九宫格、底纹、按钮件（`shop_pill.png` 等） |
| `assets/audio/` | BGM 与音效（`bgm_battle.ogg`、`menu_hejian.ogg`…） |
| `assets/voice/` | 配音（`boss_01.mp3`…） |
| `assets/video/` | 开场片 `opening.ogv`、`scroll_transition.ogv`（Godot 只认 Ogg Theora） |
| `assets/clips/` | 交付用 `<id>_clip.ogv` 演出片 |
| `assets/scenes/` | 场景/背景 |
| `assets/art/` | 手工整理的成品（bg / cards / cg / fx / skills / ui） |
| `assets/gen/` | **AI 生成物**：aivideo / audio / icons / keyframes / enemies / motion / qingshen / sketches |

## 命名约定

- 角色：`<英文名>.png`，变体加后缀 `_face` / `_full` / `_q` / `_cut`（`_cut` = 去背）
- 图标：语义前缀 + 用途，如 `chest_gold.png`、`art_spring.png`、`mat_bone.png`、`fate_greed.png`、`loot_silver.png`
- 音频：`bgm_<场景>.ogg`、`menu_<动效名>.ogg`、`boss_xx.mp3`
- 演出片：`<角色id>_clip.ogv`

## 规则

- 生成物进 `assets/gen/`，整理后成品进 `assets/art/`；不要混放。
- 每个资源都有 `.import` 与 `.uid` 伴生文件，**必须一起提交**。
- 引用用 `res://` 绝对路径；改路径要全库搜（`grep -r "旧路径"`）。
- 大文件：视频源片放 `assets/gen/aivideo/`（多数已 gitignore），交付只留 `assets/clips/` 与 `assets/video/` 的 ogv。
- 未被引用的素材不要直接删——先确认没有运行时拼接路径（本工程目前基本是字面量 res:// 引用）。
