# 修炼与突破

## 职责与边界

- 负责修炼开始/停止、每秒乐观增长、定期上报、突破触发。
- 体验上允许先本地更新，最终状态以服务端返回与全量刷新为准。

## 关键状态

- 计时与上报：`_pending_elapsed_seconds`（上报累计秒）、`_optimistic_tick_accumulator`（乐观整秒累计）、`_flush_in_flight`、`_last_optimistic_update_at`
- 乐观回血累积：`_optimistic_health_regen_accumulator`
- 乐观术法次数累积：`_optimistic_spell_use_accumulator`
- 下次自动上报窗口：`_next_auto_flush_at`
- 玩家状态：`player.is_cultivating`

## API 交互

- `POST /game/player/cultivation/start`
- `POST /game/player/cultivation/report`
- `POST /game/player/cultivation/stop`
- `POST /game/player/breakthrough`

## 功能触发流转

### 1) 点击开始修炼

1. UI 按钮触发 `cultivation/start`。
2. 服务端成功后，玩家进入修炼态，按钮与状态文案更新。
3. 之后 `process` 按真实经过时间持续推进乐观结算。

### 2) 修炼中乐观 tick（按整秒结算）

1. 基于“当前时间 - 上次乐观更新时间”得到本次 `elapsed_seconds`。
2. `_pending_elapsed_seconds += elapsed_seconds`（上报累计）。
3. `_optimistic_tick_accumulator += elapsed_seconds`。
4. 当 `_optimistic_tick_accumulator >= 1.0` 时循环整秒结算（每次按 1 秒更新灵气/回血/术法次数），并扣减 1 秒。
5. 刷新 UI。
6. 达到 5 秒阈值后触发自动 flush（上报 report）。

### 3) flush 上报（`cultivation/report`）

1. 若存在 pending 且未在 flush 中，发起 report（请求字段为 `elapsed_seconds`）。
2. 只有“本地已发生过至少 1 次整秒乐观结算”才会上报；当 pending `< 1.0` 秒时不发请求，直接返回（保留累计到下一次）。
3. 成功：仅扣除已上报的 pending 秒数，并把下个自动上报窗口设为 5 秒后。
4. 失败：保留 pending 秒数，不做立即重试，等待下一次 5 秒窗口再合并上报。
5. `CULTIVATION_REPORT_TIME_INVALID` 按“每次非法上报返回一次提示”输出“修炼同步异常，请稍后重试”。
6. 不直接把技术细节透出给玩家。

### 4) 点击停止修炼

1. 先执行一次 flush，尽量把乐观增量上报完。
2. 调用 `cultivation/stop`。
3. 成功后退出修炼态。
4. 按需触发全量刷新，确保最终状态对齐服务端。

### 5) 点击突破

1. 先执行 flush，避免“未上报增量影响突破判断”。
2. flush 前会先即时结算一次“从上次乐观更新到当前点击时刻”的本地增量。
3. 执行本地前置检查（资源/条件）。
4. 调用 `player/breakthrough`。
5. 成功：读取 `reason_data.consumed_resources` 组装“突破成功，消耗了…”。
6. 失败：读取 `missing_resources`（或本地预检）组装“突破失败，缺少…”。
7. 最后走全量刷新，保证境界/层数与属性显示一致。

## reason_code 文案策略

- 开始、停止、互斥阻断、重复操作等固定映射。
- 突破成功/失败文案都用结构化资源数据拼接。
- 不依赖服务端 message 文本。

## 失败处理与回退

- report 失败不清 pending，防止增量丢失。
- report 失败后不立即重试，按固定 5 秒窗口继续合并上报。
- stop/breakthrough 前尽量 flush，降低状态回滚感知。
- 失败反馈优先给出玩家可操作的信息（缺什么、为何阻断）。
- 当全量刷新结果为“未在修炼”时，会主动清空本地修炼运行态累计（防止登出重登后残留乐观更新）。

## 测试覆盖点

- 开始/停止主链。
- pending flush 再突破。
- 成功/失败资源文案。
- 与炼丹/历练互斥提示。

## 内视 UI 结构（当前实现）

- 内视子 Tab（修炼/术法）使用统一 `TabBarStyleTemplate`，当前为下边线选中样式。
- 修炼页状态区分为两块展示面板：
  - 属性面板：标题、左侧强调线、右侧分割线，内容左侧对齐标题首字基线。
  - 突破面板：标题、突破材料（横向最多 3 项，`x / y` 结构）、修炼/突破按钮。
- 展示面板标题样式统一走 `DisplayPanelTemplate`（标题行 + 对齐规则 + 固定留白）。
- 对齐约束：
  - 面板内部内容左侧必须与标题首字左侧对齐。
  - 标题与下方内容留白固定为同一节奏，避免不同面板视觉漂移。
- 交互细节：
  - 突破按钮不展示悬停 tooltip，突破条件信息仅通过面板与日志提示。
- 布局调优记录：
  - 属性面板已上移，突破面板与中间修炼形象按“上下间距趋于对称”做过位置微调。
  - 字号对齐：属性区 `气血/灵气/攻击/防御/速度` 统一字号。

## 数值显示约定（当前实现）

- 属性面板：
  - `气血 / 灵气` 使用整数口径（`format_display_number_integer`），大数仍转 `K / M / B`
  - `攻击 / 防御 / 速度 / 灵气获取速度` 使用非整数口径（`format_display_number`）
- 突破详情中的 `灵气 / 灵石 / 材料需求` 当前统一使用非整数口径，保持与顶部资源和其余资源文案一致。

## 典型触发链路（函数级）

以“修炼中点击突破”为例：

1. `CultivationModule.on_breakthrough_button_pressed` 先调用 `flush_pending_and_then(...)`。
2. `flush_pending_and_then` 会先做 `_settle_pending_optimistic_progress_now` 再进入 flush。
3. flush 内部调用 `api.cultivation_report(elapsed_seconds)`，仅当累计达到 `>=1.0` 秒才会上报；成功仅扣减上报累计，不清乐观整秒余量。
4. flush 收敛后执行 `api.breakthrough`。
5. 按 `reason_code + reason_data` 组装“消耗了/缺少了”文案并写日志。
6. 触发 `game_ui.refresh_all_player_data` 拉全量状态，覆盖最终境界/层数/属性显示。
7. 全流程不移除乐观更新机制，仅在关键动作前后做状态收敛。
