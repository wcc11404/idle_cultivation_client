# 储纳系统文档 (InventorySystem)

## 1. 系统概述

储纳系统是游戏中的核心物品管理系统，负责管理玩家的背包、物品存储、物品使用等功能。采用格子式背包设计，支持物品堆叠、背包扩容、物品分类展示等功能。

### 1.1 核心设计理念
- **格子式背包**：采用固定格子的背包设计，直观展示物品存放位置
- **物品堆叠**：支持同类物品堆叠，节省背包空间
- **动态扩容**：背包容量可动态扩展，满足不同阶段需求
- **品质系统**：物品分品质等级，用不同颜色标识
- **类型系统**：按物品类型决定功能按钮（打开/使用/无）
- **重要物品保护**：传说品质或功能解锁类物品丢弃需二次确认

### 1.2 物品类型（ItemType 枚举）

```gdscript
enum ItemType {
    CURRENCY = 0,      # 货币类（灵石）
    MATERIAL = 1,      # 材料类（灵草、矿石）
    CONSUMABLE = 2,    # 消耗品类（丹药）
    GIFT = 3,          # 礼包类
    UNLOCK = 4         # 功能解锁类（术法、丹方）
}
```

| 类型 | type值 | 必需字段 | 功能按钮 | 使用后 | 示例 |
|------|--------|---------|---------|--------|------|
| **货币类** | 0 | 无 | 仅丢弃 | - | 灵石 |
| **材料类** | 1 | 无 | 仅丢弃 | - | 破境草、玄铁 |
| **消耗品类** | 2 | `effect` | 使用+丢弃 | 消失 | 补血丹、补气丹、突破丹 |
| **礼包类** | 3 | `content` | 打开+丢弃 | 消失 | 新手礼包、测试礼包 |
| **功能解锁类** | 4 | `effect` | 使用+丢弃 | 消失 | 基础拳法秘籍、丹方、初级丹炉 |

### 1.3 重要物品判定

**重要物品**（丢弃需要二次确认）：
- 传说品质（quality >= 4）
- 功能解锁类（type == UNLOCK）

---

## 2. 系统架构

### 2.1 文件结构
```
scripts/core/inventory/
├── Inventory.gd          # 储纳系统核心逻辑
├── ItemData.gd           # 物品数据配置
└── items.json           # 物品配置数据

scripts/ui/modules/
└── ChunaModule.gd    # 储纳UI模块
```

### 2.2 核心常量定义

```gdscript
# Inventory.gd
const DEFAULT_SIZE = 50     # 默认背包容量
const MAX_SIZE = 200        # 最大背包容量
const EXPAND_STEP = 10      # 每次扩展的格子数

# ChunaModule.gd
const GRID_COLS = 5         # 每行格子数
const MAX_SLOTS = 200       # 最大格子数
```

### 2.3 主要数据结构

#### 2.3.1 背包格子数据 (slots)
```gdscript
var slots: Array = []  # 背包格子数组

# 单个格子数据结构
{
    "empty": bool,    # 是否为空
    "id": String,     # 物品ID
    "count": int      # 物品数量
}
```

#### 2.3.2 物品基础数据 (ItemData.item_data)
```gdscript
{
    "item_id": {
        "id": "item_id",           # 物品唯一标识
        "name": "物品名称",         # 显示名称
        "type": 0,                  # 物品类型（0-4）
        "quality": 0,               # 品质等级（0-4）
        "max_stack": 99,            # 最大堆叠数量
        "description": "描述",      # 物品描述
        "icon": "res://...",        # 图标路径
        "effect": {...},            # 使用效果（可选）
        "content": {...}            # 包含物品（礼包类，可选）
    }
}
```

#### 2.3.3 品质颜色配置
```gdscript
const QUALITY_COLORS: Array = [
    Color("#D3D3D3"),     # 0 - 普通（浅灰色）
    Color.GREEN,          # 1 - 优秀（绿色）
    Color("#00BFFF"),     # 2 - 精良（亮蓝色 DeepSkyBlue）
    Color("#EE82EE"),     # 3 - 史诗（亮紫色 Violet）
    Color.ORANGE          # 4 - 传说（橙色）
]
```

---

## 3. 命名规范

### 3.1 物品ID命名规范

| 前缀 | 含义 | 示例 |
|------|------|------|
| `spirit_stone` | 灵石（货币） | spirit_stone |
| `mat_` | 材料 | mat_iron, mat_herb |
| `recipe_` | 丹方 | recipe_health_pill, recipe_foundation_pill |
| `spell_` | 术法解锁道具 | spell_basic_breathing |
| `health_pill` | 回血丹药 | health_pill |
| `spirit_pill` | 回灵丹药 | spirit_pill |
| `foundation_pill` | 突破丹药 | foundation_pill |
| `_pill` | 丹药后缀 | health_pill, bug_pill |
| `alchemy_furnace` | 炼丹工具 | alchemy_furnace |

### 3.2 物品效果类型命名

| 效果类型 | 说明 | 参数 |
|----------|------|------|
| `add_health` | 恢复气血 | `amount`: 恢复量 |
| `add_spirit_energy` | 增加灵气（受上限限制） | `amount`: 增加量 |
| `add_spirit_energy_unlimited` | 增加灵气（不受上限限制） | `amount`: 增加量 |
| `add_spirit_and_health` | 同时增加灵气和气血 | `spirit_amount`, `health_amount` |
| `unlock_spell` | 解锁术法 | `spell_id`: 术法ID |
| `learn_recipe` | 学会丹方 | `recipe_id`: 丹方ID |
| `unlock_feature` | 解锁功能 | `feature_id`: 功能ID |

---

## 4. 主体逻辑

### 4.1 物品添加流程

```
调用 add_item(item_id, count)
    ↓
检查物品是否存在（ItemData）
    ↓
获取物品堆叠信息（max_stack, can_stack）
    ↓
优先堆叠到已有格子
    ├── 遍历已有格子
    ├── 找到相同物品ID的格子
    └── 补充到最大堆叠数
    ↓
剩余数量放入空格子
    ├── 遍历空格子
    └── 创建新堆叠
    ↓
发送 item_added 信号
    ↓
返回添加结果（是否成功）
```

### 4.2 物品使用流程

```
玩家点击使用/打开按钮
    ↓
根据物品类型执行不同逻辑
    ├── 礼包类（GIFT）
    │   ├── 检查背包空间
    │   ├── 发放content中的物品
    │   └── 消耗礼包
    ├── 消耗品类（CONSUMABLE）
    │   ├── 执行effect效果
    │   └── 消耗物品
    └── 功能解锁类（UNLOCK）
        ├── 检查是否已解锁
        │   ├── 已解锁 → 提示，不消耗
        │   └── 未解锁 → 执行解锁
        └── 解锁成功 → 消耗物品
    ↓
发送使用日志
    ↓
更新UI显示
```

### 4.3 物品丢弃流程

```
点击丢弃按钮
    ↓
检查是否为重要物品
    ├── 是 → 显示确认对话框
    │   ├── 确定 → 执行丢弃
    │   └── 取消 → 返回
    └── 否 → 直接丢弃
    ↓
从背包移除物品
    ↓
发送丢弃日志
    ↓
更新UI显示
```

### 4.4 背包扩容流程

```
点击扩容按钮
    ↓
检查是否已达最大容量（MAX_SIZE）
    ↓
增加容量（capacity += EXPAND_STEP）
    ↓
发送 capacity_changed 信号
    ↓
UI层添加新格子
    ↓
更新容量显示
```

---

## 5. 核心功能详解

### 5.1 物品堆叠机制

#### 5.1.1 堆叠规则
```gdscript
func add_item(item_id: String, count: int = 1) -> bool:
    var max_stack = item_data.get_max_stack(item_id)  # 获取最大堆叠数
    var can_stack = item_data.can_stack(item_id)      # 是否可堆叠
    
    if can_stack:
        # 优先堆叠到已有格子
        for i in range(capacity):
            if slots[i]["id"] == item_id and slots[i]["count"] < max_stack:
                var can_add = min(remaining, max_stack - slots[i]["count"])
                slots[i]["count"] += can_add
                remaining -= can_add
```

#### 5.1.2 不可堆叠物品
- `max_stack = 1` 的物品不可堆叠
- 每个不可堆叠物品占据独立格子

### 5.2 物品使用效果系统

#### 5.2.1 效果配置示例
```gdscript
# 补血丹
"health_pill": {
    "effect": {
        "type": "add_health",
        "amount": 100
    }
}

# 术法解锁道具
"spell_basic_breathing": {
    "effect": {
        "type": "unlock_spell",
        "spell_id": "basic_breathing"
    }
}

# 功能解锁道具
"alchemy_furnace": {
    "effect": {
        "type": "unlock_feature",
        "feature_id": "alchemy"
    }
}

# 新手礼包
"starter_pack": {
    "content": {
        "spirit_stone": 25,
        "health_pill": 5,
        "spell_basic_boxing_techniques": 1
    }
}
```

#### 5.2.2 效果执行流程
```gdscript
# ChunaModule._on_use_button_pressed()
match effect_type:
    "add_health":
        player.health = min(player.health + effect_amount, max_health)
    "add_spirit_energy":
        player.add_spirit_energy(effect_amount)
    "unlock_spell":
        spell_system.obtain_spell(spell_id)
    "unlock_feature":
        unlock_feature(feature_id)
    # ...
```

### 5.3 背包整理功能

```gdscript
func sort_by_id():
    # 收集所有非空物品
    var items = []
    for i in range(capacity):
        if not slots[i]["empty"]:
            items.append({"id": slots[i]["id"], "count": slots[i]["count"]})
    
    # 按ID排序
    items.sort_custom(func(a, b): return a["id"] < b["id"])
    
    # 重新放入格子
    for i in range(capacity):
        if i < items.size():
            slots[i] = {"empty": false, "id": items[i]["id"], "count": items[i]["count"]}
        else:
            slots[i] = {"empty": true, "id": "", "count": 0}
```

---

## 6. 与其他系统的联动

### 6.1 与术法系统的联动

#### 6.1.1 术法解锁
```gdscript
# 使用术法书时
"effect": {
    "type": "unlock_spell",
    "spell_id": "basic_breathing"
}

# 执行逻辑
spell_system.obtain_spell(spell_id)
```

#### 6.1.2 术法书物品列表
| 物品ID | 解锁术法 | 品质 | 类型 |
|--------|----------|------|------|
| spell_basic_breathing | 基础吐纳 | 0 | UNLOCK |
| spell_basic_boxing_techniques | 基础拳法 | 0 | UNLOCK |
| spell_thunder_strike | 雷击术 | 1 | UNLOCK |
| spell_basic_defense | 基础防御 | 0 | UNLOCK |
| spell_basic_steps | 基础步法 | 0 | UNLOCK |
| spell_basic_health | 基础气血 | 0 | UNLOCK |

### 6.2 与修炼系统的联动

#### 6.2.1 气血恢复
```gdscript
# 使用回血丹药
player.health = min(player.health + effect_amount, player.get_final_max_health())
```

#### 6.2.2 灵气补充
```gdscript
# 使用补气丹药
player.add_spirit_energy(amount)  # 受上限限制
player.add_spirit_energy_unlimited(amount)  # 不受上限限制
```

### 6.3 与历练系统的联动

#### 6.3.1 战斗奖励接收
```gdscript
# GameUI 接收历练奖励信号
func _on_lianli_reward(item_id: String, amount: int, source: String):
    inventory.add_item(item_id, amount)
    add_log("获得 " + item_data.get_item_name(item_id) + " x" + str(amount))
```

### 6.4 与UI系统的联动

#### 6.4.1 信号定义
```gdscript
# Inventory 信号
signal item_added(item_id: String, count: int)      # 物品添加
signal item_removed(item_id: String, count: int)    # 物品移除
signal inventory_full()                              # 背包已满
signal capacity_changed(new_capacity: int)          # 容量变化

# ChunaModule 信号
signal item_selected(item_id: String, index: int)   # 物品选中
signal item_used(item_id: String)                   # 物品使用
signal item_discarded(item_id: String, count: int)  # 物品丢弃
signal inventory_updated                            # 储纳更新
```

#### 6.4.2 UI层职责
**ChunaModule 负责**：
- 显示背包格子网格
- 显示物品详情面板
- 处理物品选择、使用、丢弃操作
- 显示容量信息
- 处理背包扩容和整理

---

## 7. 当前物品列表

### 7.1 货币类 (Type 0)

| 物品ID | 名称 | 堆叠上限 | 说明 |
|--------|------|----------|------|
| spirit_stone | 灵石 | 9,999,999 | 修仙界的通用货币 |

### 7.2 材料类 (Type 1)

| 物品ID | 名称 | 品质 | 说明 |
|--------|------|------|------|
| mat_iron | 玄铁 | 0 | 用于装备强化的基础材料 |
| mat_herb | 灵草 | 0 | 用于炼丹的基础草药，具有广泛药用用途 |
| mat_crystal | 灵石髓 | 2 | 用于装备精炼的稀有矿物 |
| mat_jade | 翡翠 | 3 | 用于装备进阶的珍稀玉石 |
| mat_dragon | 龙晶 | 4 | 用于装备觉醒的神级材料 |

### 7.3 消耗品类 (Type 2)

| 物品ID | 名称 | 品质 | 效果类型 | 说明 |
|--------|------|------|----------|------|
| bug_pill | bug丹 | 4 | add_spirit_and_health | 补充1亿灵气和10000气血 |
| health_pill | 补血丹 | 1 | add_health | 回复100点气血 |
| spirit_pill | 补气丹 | 1 | add_spirit_energy | 补充50点灵气 |
| foundation_pill | 筑基丹 | 1 | 突破丹 | 炼气期突破到筑基期 |
| golden_core_pill | 金丹丹 | 2 | 突破丹 | 筑基期突破到金丹期 |
| nascent_soul_pill | 元婴丹 | 2 | 突破丹 | 金丹期突破到元婴期 |
| spirit_separation_pill | 化神丹 | 3 | 突破丹 | 元婴期突破到化神期 |
| void_refining_pill | 炼虚丹 | 3 | 突破丹 | 化神期突破到炼虚期 |
| body_integration_pill | 合体丹 | 4 | 突破丹 | 炼虚期突破到合体期 |
| mahayana_pill | 大乘丹 | 4 | 突破丹 | 合体期突破到大乘期 |
| tribulation_pill | 渡劫丹 | 4 | 突破丹 | 大乘期突破到渡劫期 |

### 7.4 礼包类 (Type 3)

| 物品ID | 名称 | 品质 | 说明 |
|--------|------|------|------|
| starter_pack | 新手礼包 | 1 | 包含25灵石、5补血丹、基础拳法 |
| test_pack | 测试礼包 | 4 | 包含大量资源和道具 |

### 7.5 功能解锁类 (Type 4)

| 物品ID | 名称 | 品质 | 效果类型 | 说明 |
|--------|------|------|----------|------|
| spell_basic_breathing | 基础吐纳 | 0 | unlock_spell | 解锁基础吐纳术法 |
| spell_basic_boxing_techniques | 基础拳法 | 0 | unlock_spell | 解锁基础拳法术法 |
| spell_thunder_strike | 雷击术 | 1 | unlock_spell | 解锁雷击术 |
| spell_basic_defense | 基础防御 | 0 | unlock_spell | 解锁基础防御术法 |
| spell_basic_steps | 基础步法 | 0 | unlock_spell | 解锁基础步法术法 |
| spell_basic_health | 基础气血 | 0 | unlock_spell | 解锁基础气血术法 |
| recipe_health_pill | 补血丹丹方 | 1 | learn_recipe | 学会炼制补血丹 |
| recipe_spirit_pill | 补气丹丹方 | 1 | learn_recipe | 学会炼制补气丹 |
| recipe_foundation_pill | 筑基丹丹方 | 1 | learn_recipe | 学会炼制筑基丹 |
| recipe_golden_core_pill | 金丹丹丹方 | 2 | learn_recipe | 学会炼制金丹丹 |
| alchemy_furnace | 初级丹炉 | 1 | unlock_feature | 解锁炼丹功能 |

---

## 8. ItemData 辅助函数

### 8.1 类型判断函数

```gdscript
# 获取物品类型
get_item_type(item_id: String) -> int

# 类型判断
is_gift(item_id: String) -> bool           # 是否为礼包类
is_consumable(item_id: String) -> bool     # 是否为消耗品类
is_unlock(item_id: String) -> bool         # 是否为功能解锁类
is_currency(item_id: String) -> bool       # 是否为货币类
is_material(item_id: String) -> bool       # 是否为材料类

# 功能判断
has_function(item_id: String) -> bool                    # 是否有使用/打开功能
get_function_button_text(item_id: String) -> String      # 获取功能按钮文本

# 重要物品判断
is_important(item_id: String) -> bool      # 是否为重要物品（需二次确认）
```

### 8.2 基础信息函数

```gdscript
get_item_data(item_id: String) -> Dictionary
get_item_name(item_id: String) -> String
get_item_quality_color(quality: int) -> Color
can_stack(item_id: String) -> bool
get_max_stack(item_id: String) -> int
```

---

## 9. 关键函数索引

### 9.1 Inventory 公共接口

| 函数名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `add_item` | `item_id: String, count: int` | `bool` | 添加物品到背包 |
| `remove_item` | `item_id: String, count: int` | `bool` | 从背包移除物品 |
| `has_item` | `item_id: String, count: int` | `bool` | 检查是否拥有指定数量物品 |
| `get_item_count` | `item_id: String` | `int` | 获取物品总数量 |
| `get_item_list` | 无 | `Array` | 获取背包物品列表 |
| `expand_capacity` | 无 | `bool` | 扩展背包容量 |
| `can_expand` | 无 | `bool` | 检查是否可以扩展 |
| `sort_by_id` | 无 | `void` | 按ID整理背包 |
| `get_used_slots` | 无 | `int` | 获取已使用格子数 |
| `get_capacity` | 无 | `int` | 获取当前容量 |
| `use_starter_pack` | 无 | `bool` | 使用新手礼包 |
| `get_save_data` | 无 | `Dictionary` | 获取存档数据 |
| `apply_save_data` | `data: Dictionary` | `void` | 加载存档数据 |

### 9.2 ChunaModule 公共接口

| 函数名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `initialize` | `ui, player, inv, item_data, spell_sys, spell_dt` | `void` | 初始化模块 |
| `show_tab` | 无 | `void` | 显示储纳标签页 |
| `hide_tab` | 无 | `void` | 隐藏储纳标签页 |
| `update_inventory_ui` | 无 | `void` | 更新储纳UI显示 |
| `setup_inventory_grid` | 无 | `void` | 设置背包格子 |
| `get_selected_item_id` | 无 | `String` | 获取当前选中物品ID |
| `get_selected_index` | 无 | `int` | 获取当前选中格子索引 |
| `clear_selection` | 无 | `void` | 清空当前选择 |
| `cleanup` | 无 | `void` | 清理资源 |

---

## 10. 扩展指南

### 10.1 添加新物品

1. **在 ItemData.gd 中添加配置**：
```gdscript
"new_item": {
    "id": "new_item",
    "name": "新物品",
    "type": 2,                    # 消耗品类
    "quality": 1,                 # 优秀品质
    "max_stack": 99,              # 最大堆叠99
    "description": "物品描述",
    "icon": "res://assets/items/new_item.png",
    "effect": {
        "type": "add_health",     # 效果类型
        "amount": 100             # 效果数值
    }
}
```

2. **可选：添加content（礼包类）**：
```gdscript
"gift_pack": {
    "content": {
        "spirit_stone": 100,
        "health_pill": 5
    }
}
```

### 10.2 添加新的物品效果类型

1. **在 ItemData.gd 中定义新效果**：
```gdscript
"item_with_new_effect": {
    "effect": {
        "type": "new_effect_type",
        "param1": value1,
        "param2": value2
    }
}
```

2. **在 ChunaModule.gd 中处理新效果**：
```gdscript
# _on_use_button_pressed() 中添加
match effect_type:
    "new_effect_type":
        # 执行新效果逻辑
        execute_new_effect(params)
```

### 10.3 修改背包容量

编辑 Inventory.gd 中的常量：
```gdscript
const DEFAULT_SIZE = 50     # 修改默认容量
const MAX_SIZE = 200        # 修改最大容量
const EXPAND_STEP = 10      # 修改每次扩展数量
```

---

## 11. 注意事项

1. **堆叠限制**：每个物品的最大堆叠数由 `max_stack` 字段决定，灵石等特殊物品可设置很大值（9,999,999）
2. **品质颜色**：品质颜色会自动调整亮度，确保在深色背景上可见
3. **物品使用**：使用物品时会自动检查玩家是否初始化，避免空指针
4. **背包扩容**：扩容时会自动添加新格子，不会重置已有物品
5. **存档数据**：采用稀疏存储格式，只保存有物品的格子，物品配置从 ItemData 读取
6. **格子大小**：格子大小会根据容器宽度自动计算，保持每行5个格子
7. **物品选中**：选中物品后显示详情面板，按钮根据物品类型动态显示/隐藏
8. **新手礼包**：使用 `use_starter_pack()` 方法批量添加新手物品
9. **术法解锁**：解锁术法后会自动刷新术法UI，确保显示最新状态
10. **日志输出**：物品获取日志由 ChunaModule 统一处理，其他系统只需调用 `inventory.add_item()`
11. **重要物品**：传说品质或功能解锁类物品丢弃时会显示确认对话框
12. **物品类型**：修改物品类型(type)后，需要同步修改对应字段（content/effect）

---

## 12. 存档格式

### 12.1 稀疏存储格式（当前版本）

```json
{
    "capacity": 50,
    "slots": {
        "0": {"id": "spirit_stone", "count": 100},
        "5": {"id": "herb", "count": 50},
        "12": {"id": "health_pill", "count": 3}
    }
}
```

**优点**：
- 存档文件更小，只保存有物品的格子
- 读取更快，无需遍历空格子

### 12.2 兼容旧版本格式

系统同时支持旧版密集数组格式，自动转换：

```json
{
    "capacity": 50,
    "slots": [
        {"empty": false, "id": "spirit_stone", "count": 100},
        {"empty": true, "id": "", "count": 0},
        {"empty": true, "id": "", "count": 0},
        ...
    ]
}
```

---

## 13. 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 1.0 | 2026-02-24 | 初始文档 |
| 2.0 | 2026-02-25 | 重构物品类型系统，新增功能解锁类，优化品质颜色，添加重要物品保护机制 |
| 2.1 | 2026-03-04 | 存档格式改为稀疏存储，兼容旧版本格式 |
| 2.2 | 2026-03-14 | 更新文件路径和目录结构 |