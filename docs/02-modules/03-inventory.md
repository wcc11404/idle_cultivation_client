# 储纳（背包）

## 职责与边界

- 负责背包格子展示、物品详情、使用/丢弃/扩容/整理交互。
- 将服务端语义码转为玩家文案并输出到日志框。

## 关键状态

- 当前选中物品：`current_selected_item_id`、`current_selected_index`
- 背包容量与格子内容：来自 `inventory` 节点
- 模块依赖：`item_data`、`spell_data`、`recipe_data`（用于中文名和解锁文案）
- 容量规则：初始40格，最大40格（当前版本不再提供可增长容量）

## API 交互

- `GET /game/inventory/list`
- `POST /game/inventory/use`
- `POST /game/inventory/discard`
- `POST /game/inventory/expand`
- `POST /game/inventory/organize`

## 功能触发流转

### 1) 打开储纳页

1. 显示背包面板并清空详情区选中态。
2. 用当前 `inventory` 数据重建格子 UI。
3. 若允许后台刷新，延迟触发 `refresh_all_player_data` 做全量对齐。

### 2) 点击物品格子

1. 记录选中物品 ID 与槽位索引。
2. 刷新右侧详情（名称、数量、描述、可用动作按钮）。
3. 发出 `item_selected` 信号供外层监听。

### 3) 点击使用

1. 校验当前有选中物品。
2. 调 `inventory/use`。
3. 成功：
   - 按 `reason_code + reason_data.effect` 组装文案。
   - 立即刷新本地背包显示。
   - 对礼包类读取 `reason_data.contents` 展示奖励明细。
4. 失败：
   - 统一按 reason_code 映射失败文案（数量不足/不可使用/已使用过/等级条件不足等）。

### 4) 点击丢弃

1. 调 `inventory/discard`（当前实现为固定数量策略）。
2. 成功后刷新格子与容量显示。
3. 失败按 reason_code 输出“数量不足/物品不存在”等提示。

### 5) 点击扩容

1. 调 `inventory/expand`。
2. 成功：读取 `new_capacity`，更新容量文案。
3. 失败：按 reason_code 输出“已达上限”等提示。

### 6) 点击整理

1. 调 `inventory/organize`。
2. 成功后重建格子顺序并刷新显示。
3. 失败输出归一化错误文案。

### 7) 背包同步（列表接口）

1. 调 `inventory/list` 拉取服务端背包结构。
2. 成功：`inventory.apply_save_data` 后重建 UI。
3. 失败：仅输出“背包同步失败”类提示，不破坏当前可见状态。

## reason_code 文案策略

- 使用成功按 effect 类型区分：
  - 消耗品：展示实际恢复/获得值
  - 礼包：展示开包奖励汇总
  - 解锁类：展示术法/丹方/丹炉中文名
- 重复使用统一文案：`xx已经使用过了，无法重复使用`。
- 礼包等级门槛：`INVENTORY_USE_REQUIREMENT_NOT_MET` 时，按 `reason_data.requirement.realm_min` 输出“需达到炼气X层后才能打开”。

## 储纳 UI 结构（当前实现）

- 顶部栏：
  - 容量文本：`容量：已用/总容量`。
  - `+` 扩容按钮：金色主按钮风格，尺寸放大版本，便于触屏点击。
  - `整理` 按钮：次级浅棕按钮风格。
- 背包格子：
  - 统一为 5 列自适应网格，格子高度固定。
  - 三态视觉：
    - 空槽：浅棕底色 + 默认边框
    - 有物品：更亮一档底色 + 默认边框
    - 选中槽：亮底色 + 亮金边框（加粗）
  - 文本布局维持原约定：名称居中、数量右下角。
- 物品名颜色：
  - 继续按 `quality` 做稀有度配色。
  - `quality=0` 的默认灰色已改为深色（黑色基调），保证在浅底色下可读性。
  - 绿色稀有度改为更深绿色，避免偏亮发灰。
- 详情卡：
  - 背景色：`#f2e5cc`
  - 边框：暖棕色描边
  - 文本层级：名称与数量更强调，类型与描述弱化，减少信息噪声。
  - 丢弃按钮使用红色主按钮风格（与全局危险操作一致）。

## 数值显示约定（当前实现）

- 容量 `已用 / 总容量`：走整数口径。
- 格子右下角叠加数量：走整数口径。
- 扩容成功提示中的容量值：走整数口径。
- 右侧详情卡中的“数量”当前仍沿用普通数值口径，用于和其他资源型展示保持一致。

## 失败处理与回退

- 不直接透传服务端业务 message。
- API 失败时保留当前选中态，避免 UI 突兀跳变。

## 测试覆盖点

- 使用成功/失败、礼包奖励、重复使用。
- 扩容/整理/丢弃提示与刷新行为。

## 典型触发链路（函数级）

以“使用道具”为例：

1. `ChunaModule._on_use_button_pressed` 校验选中项并调 `api.inventory_use`。
2. 服务端返回后，`_build_use_result_message` 根据 `reason_code + reason_data.effect/contents` 生成中文文案。
3. 成功时执行本地 `inventory.apply_save_data` 或刷新流程，同步数量与详情面板状态。
4. 解锁类道具通过 `effect.type + id` 映射术法/丹方/丹炉中文名。
5. 失败时只输出语义码映射文案，不透传底层错误详情。
