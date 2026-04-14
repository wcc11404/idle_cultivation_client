# 修炼与突破

## 职责与边界

- 负责修炼开始/停止、每秒乐观增长、定期上报、突破触发。
- 体验上允许先本地更新，最终状态以服务端返回与全量刷新为准。

## 关键状态

- 计时与上报：`_accumulated_seconds`、`_pending_count`、`_flush_in_flight`
- 乐观回血累积：`_optimistic_health_regen_accumulator`
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
3. 之后 `process` 每秒触发一次乐观 tick。

### 2) 修炼中每秒 tick（乐观更新）

1. 计算并本地增加灵气（按当前属性/加成）。
2. 计算并本地恢复气血（带累积器，避免小数损失）。
3. 呼吸类术法次数进行乐观累计。
4. `_pending_count += 1`，并刷新 UI。
5. 达到阈值后触发自动 flush（上报 report）。

### 3) flush 上报（`cultivation/report`）

1. 若存在 pending 且未在 flush 中，发起 report。
2. 成功：扣除 pending，并把下个自动上报窗口设为 5 秒后。
3. 失败：保留 pending，不做立即重试，等待下一次 5 秒窗口再合并上报。
4. `CULTIVATION_REPORT_TIME_INVALID` 按“每次非法上报返回一次提示”输出“修炼同步异常，请稍后重试”。
5. 不直接把技术细节透出给玩家。

### 4) 点击停止修炼

1. 先执行一次 flush，尽量把乐观增量上报完。
2. 调用 `cultivation/stop`。
3. 成功后退出修炼态。
4. 按需触发全量刷新，确保最终状态对齐服务端。

### 5) 点击突破

1. 先执行 flush，避免“未上报增量影响突破判断”。
2. 执行本地前置检查（资源/条件）。
3. 调用 `player/breakthrough`。
4. 成功：读取 `reason_data.consumed_resources` 组装“突破成功，消耗了…”。
5. 失败：读取 `missing_resources`（或本地预检）组装“突破失败，缺少…”。
6. 最后走全量刷新，保证境界/层数与属性显示一致。

## reason_code 文案策略

- 开始、停止、互斥阻断、重复操作等固定映射。
- 突破成功/失败文案都用结构化资源数据拼接。
- 不依赖服务端 message 文本。

## 失败处理与回退

- report 失败不清 pending，防止增量丢失。
- report 失败后不立即重试，按固定 5 秒窗口继续合并上报。
- stop/breakthrough 前尽量 flush，降低状态回滚感知。
- 失败反馈优先给出玩家可操作的信息（缺什么、为何阻断）。

## 测试覆盖点

- 开始/停止主链。
- pending flush 再突破。
- 成功/失败资源文案。
- 与炼丹/历练互斥提示。

## 典型触发链路（函数级）

以“修炼中点击突破”为例：

1. `CultivationModule.on_breakthrough_button_pressed` 先调用 `_flush_pending_report_if_needed`。
2. flush 内部调用 `api.cultivation_report(count)`，成功则扣减 pending，失败则保留并计入重试。
3. flush 收敛后执行 `api.breakthrough`。
4. 按 `reason_code + reason_data` 组装“消耗了/缺少了”文案并写日志。
5. 触发 `game_ui.refresh_all_player_data` 拉全量状态，覆盖最终境界/层数/属性显示。
6. 全流程不移除乐观更新机制，仅在关键动作前后做状态收敛。
