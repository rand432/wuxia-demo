# 江湖 · UI 换皮总览（v220–v254）

![UI 换皮总览](../.shots/UI换皮总览_v248.png)

> 新游历专题验收：`docs/游历2_UI验收.md`（12 图，v242–v253）。

> 这份是**总览/交接索引**，施工细节看各版本 `docs/交接_UI换皮_vXXX.md`。
> 最后更新：v254（2026-10-20，战报/后记滚动）。

---

## 一、现在这套皮是什么

一句话：**水墨纸面 / 墨底金线 / 近方角 / 毛笔标题 / 朱砂点睛**。

| 层 | 做法 | 入口 |
|---|---|---|
| 调色/字体/缓动 | `Ui`（`SKIN=1`）：`INK/GOLD/SEAL/PAPER`、`brush_font()`、`spring/ease` | `menu/menu_theme.gd` |
| 纸面弹窗 | 近方角 4px + 金线 0.55 + 纸底；全工程 32 处共用 | `UiKit.paper_box / make_paper_panel` |
| 墨金按钮 | 墨底 + 金线 + 米白/金字；禁用态墨牌暗金 | `UiKit.style_button / make_button` |
| 战斗 HUD | 顶部/底部墨底金线带、毛笔胜负框、浅色字压深底 | `battle_lite / duel_battle` |
| 探索 HUD | 顶部信息条 + 底部卷轴操作带 | `journey/explore/explore_map.gd` |
| 地图/图鉴 | 江湖图 ink 字体、雾区金环「未探索」；图鉴分段金线 | `region_select / boss_codex` |

---

## 二、版本索引

| 版本 | 做了什么 | 关键文件 | 截图 |
|---|---|---|---|
| v220–v230 | 主界面墨金化、困兽斗场壳/经验条/弹窗、玄铁匣等 | `menu_sketch / kushou_v2` | `v230_*` |
| v231–v235 | 雾/金尘/季节/夏雨、环境音、全量冒烟 | `menu_mist / audio` | `v233/v235_*` |
| v236 | 困兽页内按钮墨金 | `kushou_v2` | `v236_*` |
| v237 | 一次性按钮（藏宝图/山洞）挪进画里、用完消失 | `menu_sketch` | `v237_*` |
| v238 | `battle_lite` HUD 墨金（四钮/撤退/战报条） | `battle_lite` | `v238_battle_*` |
| v239 | 战斗胜负结算：墨金框 + 毛笔「胜/败」 | `battle_lite` | `v239_battle_win` |
| v240 | 挂机/建设横梁搬到左上头像下 | `menu_sketch` | `v240_beam_under_avatar` |
| v241 | 游历决斗 HUD 墨金 + 深底浅字 | `duel_battle` | `v241_duel_*` |
| v242 | 全局纸面近方角金框；开局行装毛笔标题/金卡 | `ui_kit / journey_stage` | `v242_journey_80` |
| v243 | 新游历 explore_map 顶部信息条 + 底部操作带 | `explore_map` | `v243_explore_a` |
| v244 | 江湖关系标题左对齐，避让右上三钮 | `relationship_panel` | `v244_relation` |
| v245 | 江湖图 ink 字体/雾区金环；舆图禁用墨牌 | `region_select / world_map_panel` | `v245_region / v245_worldmap` |
| v246 | 全局禁用按钮：半透明灰 → 墨底暗金 | `ui_kit` | `v246_merchant / sect / jail` |
| v247 | 宗门事务恢复金框、面板 700；战线页 720 | `sect_affairs / war_table` | `v247_affairs / war_table` |
| v248 | 凶物图鉴六段加 1px 暗金分隔线；后记抽查 | `boss_codex` | `v248_boss_codex / epilogue` |
| v249 | 游历「地图」面板：金框纸面/毛笔字/24×30 暗格/返回·世界 | `explore_map` | `v249_map_panel / world_from_map / world_back` |
| v250 | 地图面板补图例（地标/宝箱/敌人/你） | `explore_map` | `v250_map_panel` |
| v251 | 地图开着时返回键先关地图，不再直接回村 | `explore_map` | `v251_esc_close` |
| v252 | 地图图例右侧加 − / + 触屏缩放钮 | `explore_map` | `v252_map_zoom` |
| v253 | 地图纸面斑点 + 未探索格轻明暗差 | `explore_map` | `v253_map_texture` |
| v254 | 战报/后记超长文案滚动 + 细金滚动条 | `ui_kit / war_report / epilogue` | `v254_war_scroll / epilogue_scroll` |

---

## 三、验收方式（可复跑）

1. 单文件编译：
   ```powershell
   $godot = 'C:\Users\zq300\Desktop\Godot_v4.7.2-stable_win64.exe'
   & $godot --headless --path D:\1\wuxia-demo --check-only --script res://menu/menu_sketch.gd 2>&1
   ```
2. 主界面/战斗/游历探针：SubViewport 720×1280，实例化场景，帧驱动截图；跑前备份 `%APPDATA%\Godot\app_userdata\江湖游历\save.cfg`，跑完还原。
3. 新游历单场景：直接加载 `res://journey/explore/explore_map.tscn`；面板可单独实例化并 `open()`。
4. 探针截图统一放 `.shots/`，文档只引用最终图，不引中间废片。

---

## 四、已知边界（下一轮可做）

| 项 | 说明 |
|---|---|
| 战报长列表 | 12 条短战报能装下；若以后战报变长/换行，再加 ScrollContainer 或行距压缩 |
| 游历行囊/角色钮 | 右上 8 格纸面、主界面角色/卡组钮还是各自 StyleBox，未统一 |
| 新面板长文 | 后记/图鉴是固定字号，极长文案可能溢出；可加滚动或缩字号 |
| 宗门事务列表 | 藏经阁两行 16 号字，条目多了会挤；可分行/加行距 |
| 战斗结算 | 只演画面；真实奖励结算仍在原流程 |

---

## 五、关键截图

| 画面 | 图 |
|---|---|
| 主界面 | `v240_beam_under_avatar.png` |
| 新游历 HUD | `v243_explore_a.png` |
| 游历开局 | `v242_journey_80.png` |
| 决斗 HUD | `v241_duel_a.png` |
| 战斗结算 | `v239_battle_win.png` |
| 江湖图 | `v245_region.png` |
| 舆图 | `v245_worldmap.png` |
| 游历地图面板 | `v249_map_panel.png` |
| 货郎/宗门/图鉴/后记 | `v246_merchant / v247_affairs / v248_boss_codex / v248_epilogue` |

---

## 六、一句话交接

皮已经铺到 `menu / kushou / battle_lite / duel_battle / journey_stage / explore`；
公共底在 `menu_theme.gd + ui_kit.gd`，以后新页面优先走 `paper_box / make_button / brush_font`，
不要在面板里再自己造一套覆盖金框的 StyleBox。
