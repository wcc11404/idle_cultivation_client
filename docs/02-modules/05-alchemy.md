# 炼丹

## 职责与边界

- 管理丹方列表、炼制数量选择、进度条推进、每轮上报与停火汇总。
- 保留“每轮预扣 + 每轮结算”的体验逻辑。

## 关键状态

- 是否在炼丹：`_is_alchemizing`
- 当前批次上下文：`_runtime_recipe_id`、`_runtime_total_count`、`_runtime_index`
- 批次统计：`_runtime_success_count`、`_runtime_fail_count`
- 当前轮预扣：`_runtime_pending_cost`
- 异步任务收敛：`_pending_async_task_count`

## API 交互

- `GET /game/alchemy/recipes`
- `POST /game/alchemy/start`
- `POST /game/alchemy/report`
- `POST /game/alchemy/stop`

## 功能触发流转

### 1) 打开炼丹房

1. 拉取丹方配置 `alchemy/recipes`。
2. 刷新丹方卡片与当前选中丹方详情。
3. 根据当前库存/灵气实时更新材料文本（不足标红）。

### 2) 切换炼制数量（1/10/100/Max）

1. 更新 `selected_count`。
2. 重新计算该批次总材料需求并更新材料区域。
3. 若有缺料，材料条目直接显示红色文本。

### 3) 点击开炉（开始炼丹）

1. 先做本地可开炉校验（材料与灵气是否足够）。
2. 调 `alchemy/start`。
3. 成功后进入 `_is_alchemizing = true`，初始化批次运行态。
4. 对第一轮执行本地预扣并开始进度条计时。

### 4) 进度推进与单轮 report

1. `_process` 按丹方时间推进进度条。
2. 到达单轮时间后调用 `alchemy/report(recipe_id, 1)`。
3. 网络技术错误时，接口层会在 1 秒后自动重试 1 次。
3. 成功：
   - 根据返回 `success_count/fail_count/products/returned_materials` 更新统计与背包。
   - 成功轮仅输出“获得物品：xxx”。
   - 失败轮仅输出“返还材料：xxx”。
4. 重试后仍失败：
   - 回滚当前轮预扣（灵气与材料）。
   - 输出“炼丹同步异常，请稍后再重试”，并收口停火汇总。
5. 若尚有剩余轮次：
   - 继续下一轮预扣并进入下一段进度。

### 5) 中途停火（点击停止）

1. 调 `alchemy/stop`。
2. 停止后统一输出汇总：`收丹停火：成丹x枚，废丹x枚`。
3. 未开始预扣的后续轮次不做返还文案（因为未扣）。

### 6) 批次自然完成

1. 最后一轮 report 完成后自动走 stop 收口。
2. 统一输出同一条“收丹停火”汇总文案。

## reason_code 文案策略

- 开炉成功：`开炉炼丹`
- report 成功：模块内部按 products/returned_materials 组装文案
- stop 成功：不额外输出业务文案，只输出统一汇总
- 失败码映射“材料不足/灵气不足/同步异常/互斥阻断”等

## 失败处理与回退

- report 失败：立即恢复当前轮预扣成本并停火收口。
- report 的网络技术错误会先执行“1 秒后单次重试”，仅重试失败后才回滚并停火。
- 材料不足：启动前拦截 + 红字提示，不进入运行态。
- 所有失败都保证模式锁与按钮状态最终可恢复。

## 测试覆盖点

- 材料不足红字拦截。
- 单轮成功/失败文案是否唯一且符合规则。
- 停火汇总文案格式与计数一致。

## 典型触发链路（函数级）

以“炼制 10 枚并中途停火”为例：

1. `AlchemyModule.on_craft_pressed` 先做材料/灵气本地校验，不足直接红字阻断。
2. 成功开炉后写入运行态（`_runtime_total_count=10` 等）并对当前轮执行预扣。
3. `_process` 推进进度，单轮到点后调 `api.alchemy_report(recipe_id, 1)`。
4. report 成功：
   - 成丹轮只输出“获得物品：xxx”。
   - 废丹轮只输出“返还材料：xxx”。
5. 用户点击停止时 `on_stop_pressed -> api.alchemy_stop` 收口。
6. 最终统一输出“收丹停火：成丹x枚，废丹x枚”；未预扣轮次不做返还提示。
