# 数据入口详解

## 1. 组合卡 · kushou/card_data.gd

结构：**10 系 × 4 阶**，每阶 2–6 张不同卡，第一张是该阶入口卡。

- 系（`SELFS[].key`）：atk 攻击 / def 防御 / hp 气血 / gold 金币 / mp 内力 / crystal 灵晶 / swarm 群 / peril 险 / bounty 财 / exp 经验
- 阶（tier 0–3）对应品质：初=良 中=玄 高=地 特=天（`QUALITY_OF_TIER`）
- 每系字段：`names`（各阶名字数组）、`own`（本卡自身数值）、`own_suffix`（%、空）、`set`（四阶同名组）、`trigger`、`combo` + `combo_key` + `combo_val`（集齐三张的组合效果）、`arts`（图标资源路径）
- 特殊系有额外矩阵：`bounty` 用 `own_matrix / own_val_matrix / own_text_matrix`；`swarm`、`peril` 用 `own_keys / own_texts` 与 `combo_extra_*`
- 卡 id 规则：`"%s_%d_%d" % [key, tier, idx]`
- 新卡组：`new_group()` 目前返回空，L10 首通后由 `GameState.new_cards_unlocked` 打开；把数据填进它的 `cards / entries` 即可，**不要改抽卡主流程**

改卡后要跑卡池/抽卡相关 audit（见 verify.md）。

## 2. 十关 · shared/level_state.gd

- `LEVELS`：10 关，每关 `waves` 波数 + `show`（各按钮显隐）
- `FEATURE_LEVEL`：功能解锁表，**唯一事实来源**
  - L1 强化/进阶/玉壶；L2 抽卡/成长/灵晶；L3 宝物/经济；L4 奇遇/挑战/危途；
  - L5 请神/家传/伙伴；L6 黑市/高级卡；L7 特级；L8 装备/锻造；L9 角色进阶；L10 新奇物/新卡组
- `has_feature(kind, level=-1)`：**任何系统判断功能开关都走它**，禁止散写 `current_level >= N`
- `LINE_GROWTH / LINE_ECON / LINE_DANGER`：10 系分线
- `FIRST_REWARDS`：首通掉落（7–10 关留了字段）
- `GOD_ORDER`：六位请神顺序（L5 开 2，之后每关 +1，L9 满 6）
- 存档：`user://level_state.cfg`，`SAVE_VERSION = 2`

## 3. 祖宗家传 · kushou/ancestor_data.gd

每位祖宗 **6 档 × 每档 3 张 = 18 张**；同档集齐三张 → 组合生效 → 清空 → 下一档入口进池；卡组 10 格，最多同开 3 档；抽到该祖宗家传卡时 4% 掷炫卡。
`effects` 键的组合加成落地在 `battle_ui._cast_skill`。

## 4. 奇物 · shared/curio_data.gd

15 件。字段：`name` 名称 / `glyph` 字形占位 / `type` 主动|被动 / `trig` 触发条件 / `cd` 冷却秒（0=被动）/ `lv` 五级效果文案 / `fb` 触发反馈。
单件携带、固定五级；材料和来源待设计，当前页面免费强化。

## 5. 装备与锻造 · shared/forge_data.gd

- 品质（`QUALITY_NAME`）：凡品/良品/玄品/地品/天品 —— 决定强化上限、每级增幅、边框色
- 品阶：每 20 级 +1，纯外观
- 特性：锻造时给特殊加成
- 淬火油：下一锤成功/大成功权重各 ×1.5，不叠加；撤销恢复上一锤快照，不退材料

## 6. 属性换算 · shared/equipment_stats.gd

`DEF_TO_RED = 0.03`（每点防御 3% 非真实固定减免）；`SPEED_TO_AMP = 0.01`（每点披风速度 1% 攻速）。
每局建场应用一次，局内成长继续走原属性层；最终减免上限沿用核心规则。

## 7. 其它

| 文件 | 职责 |
|---|---|
| `shared/game_state.gd` | 货币（wen/silver/yuanbao）、名号、首通掉落占位 |
| `shared/combat_rules.gd` | 战斗核心常量（减免上限等） |
| `shared/save_file.gd` | 原子写 + `user://reward_pending.cfg` 跨文件奖励日志 |
| `shared/audio.gd` | BGM 交叉淡入 + 音效一发；离树释放播放流 |
| `kushou/black_market.gd` | 六格随机货、折扣、Lv1-5 黑市经验、不暂停战斗 |
