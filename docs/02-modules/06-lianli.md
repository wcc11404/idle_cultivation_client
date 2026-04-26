# 历练

## 职责与边界

- 管理历练区域进入、战斗时间轴播放、结算上报、继续连战和退出。
- 战斗逻辑由服务端模拟，客户端只做播放与状态机控制。

## 关键状态

- 本地运行态写入 `lianli_system`：
  - `is_in_lianli`
  - `is_in_battle`
  - `is_waiting`
  - `current_area_id`
- 回放状态：
  - `_battle_timeline`、`_timeline_cursor`、`_timeline_elapsed`
  - `_is_timeline_running`、`_finish_in_flight`
- 展示状态：
  - `_simulated_player_health_after`
  - `_simulated_player_max_health`

## API 交互

- `GET /game/lianli/speed_options`
- `POST /game/lianli/simulate`
- `POST /game/lianli/finish`
- `GET /game/dungeon/foundation_herb_cave`
- `GET /game/tower/highest_floor`

## 区域 ID 约定（当前硬编码）

- 普通区：`area_1`、`area_2`、`area_3`、`area_4`
- 每日区：`foundation_herb_cave`
- 无尽塔：`sourth_endless_tower`

## 功能触发流转

### 1) 进入历练页

1. 展示历练主面板。
2. 用当前会话内记录的倍速先更新按钮文案，默认是 `1x`。
3. 异步拉取 `speed_options`，根据服务端返回的可用倍速集合修正当前选择。
2. 拉取副本次数与塔层信息，更新按钮文案。
3. 根据本地运行态判断：
   - 若已在历练中，直接回到战斗面板。
   - 否则显示区域选择面板。

### 1.5) 点击历练倍速按钮

1. 客户端先请求 `GET /game/lianli/speed_options`，确认当前账号可用的倍速集合。
2. 若只有 `1.0`：
   - 不切换
   - 输出提示：`达到金丹境界以后可以开启1.5倍速，开通VIP可以开启2倍速`
3. 若可用集合是 `[1.0, 1.5]`：
   - 在 `1.0 <-> 1.5` 间循环
4. 若可用集合是 `[1.0, 1.5, 2.0]`：
   - 按 `1.0 -> 1.5 -> 2.0 -> 1.0` 循环
5. 当前选中的倍速只在本次登录会话内保留；重新进入游戏默认回到 `1x`

### 2) 点击某历练区域

1. 先做本地拦截（例如气血不足）。
2. 再做模式互斥检查（修炼中/炼丹中不可进）。
3. 调 `lianli/simulate(area_id)`。
4. 成功：写入本地历练态，切到战斗面板，启动时间轴播放。
5. 失败：按 reason_code 输出阻断文案。

### 3) 时间轴播放（战斗中）

1. `_process` 按速度倍率推进 elapsed。
2. 到达事件时间点时应用事件：
   - 更新敌我血条
   - 更新术法相关展示
   - 输出战斗日志
3. 时间轴结束后进入结算流程（finish）。

### 4) 结算（finish）

1. 调 `lianli/finish(speed, index?)`，`index` 语义如下：
   - `null`：完整结算（请求体省略 index）。
   - `-1`：首个战斗事件前主动退出，仅退出不结算。
   - `>=0`：按已播放事件做部分结算。
2. `speed` 由客户端当前选中的倍速传入，服务端会再次校验是否合法。
2. 成功：
   - 根据返回判断是否已完整结算。
   - 进入等待下一场或允许继续/退出。
3. 失败：
   - 输出归一化提示。
   - 强制收敛退出战斗态，回到可恢复页面。

### 5) 连战与退出

1. 连战开启时，等待计时后自动请求下一次 `simulate`。
2. 点击退出时中断时间轴并清理本地历练态。
3. 若在首个事件前退出，模块会上传 `index=-1`，避免被服务端误判为“过早完整结算”。

## reason_code 文案策略

- `LIANLI_SIMULATE_*`：入场阻断与次数限制提示。
- `LIANLI_SPEED_OPTIONS_SUCCEEDED`：仅用于初始化可用倍速集合，通常不直接提示。
- `LIANLI_FINISH_*`：结算状态与同步异常提示。
- 不依赖服务端 message 文本。

## 失败处理与回退

- finish 失败必须收敛，避免卡在“战斗中”状态。
- 返回历练页时优先依据本地历练态恢复正确子页面。

## 数值显示约定（当前实现）

- 战斗页敌我 `气血 / 最大气血`：走整数口径。
- 战斗伤害数字：走普通数值口径（两位小数 / 紧凑单位）。
- 区域剩余次数：走整数口径。
- 掉落区间、掉落数量当前沿用普通数值口径；时间、层数、速度倍率属于特例，不套统一压缩规则。

## 测试覆盖点

- 切页返回后定位正确。
- finish 失败收敛。
- 本地气血拦截 + 服务端阻断提示。

## 典型触发链路（函数级）

以“进入某区域历练并完成一场结算”为例：

1. `LianliModule.on_lianli_area_pressed(area_id)` 做本地血量与模式互斥检查。
2. 调 `api.lianli_simulate` 成功后写入 `lianli_system.is_in_lianli/current_area_id/is_in_battle`。
3. `LianliModule._start_timeline_playback` 启动时间轴，`_process` 按帧推进事件并更新血条/日志。
4. 时间轴结束后触发 `api.lianli_finish`。
5. finish 成功则更新结算态并决定“继续连战/退出”；失败则强制收敛并回区域选择页。
6. 切到其他 tab 再返回时，`on_tab_open` 依据 `lianli_system` 直接定位战斗页或选择页。
