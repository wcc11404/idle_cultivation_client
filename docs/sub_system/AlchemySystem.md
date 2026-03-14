# 炼丹系统设计文档

## 一、背景与需求

### 1.1 背景
修仙模拟器游戏需要增加炼丹玩法，作为洞府功能的核心系统之一。玩家可以通过炼丹系统炼制各种丹药，用于恢复气血、补充灵气、突破境界等。

### 1.2 需求
- 提供丹方学习、炼丹操作、丹药产出的完整流程
- 与现有系统（术法系统、储纳系统、物品系统）深度集成
- 支持批量炼制，提供炼丹日志
- UI简洁直观，操作便捷

## 二、系统设计

### 2.1 系统组成

#### 2.1.1 架构概览

炼丹系统采用 **逻辑层与UI层分离** 的架构：

```
┌─────────────────────────────────────────────────────────┐
│                      GameUI                             │
│  ┌─────────────────┐    ┌─────────────────────────┐    │
│  │  AlchemyModule  │◄───│     AlchemySystem       │    │
│  │    (UI层)       │    │      (逻辑层)            │    │
│  │                 │    │                         │    │
│  │ - 显示丹方列表   │    │ - 炼丹状态管理           │    │
│  │ - 显示材料信息   │    │ - _process(delta)循环   │    │
│  │ - 进度条更新     │    │ - 成功/失败判定          │    │
│  │ - 用户交互处理   │    │ - 材料消耗/产出          │    │
│  └─────────────────┘    └─────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

**关键设计决策**：
- 使用 `_process(delta)` 替代递归定时器，避免孤儿定时器和状态同步问题
- AlchemySystem 发出信号，AlchemyModule 监听并更新UI
- 所有炼丹逻辑集中在 AlchemySystem，AlchemyModule 是纯UI层

#### 2.1.2 丹方系统
- **获取方式**: 使用丹方道具解锁
- **解锁后**: 永久学会，可以无限次炼制
- **丹方列表**:

| 丹方ID | 名称 | 材料需求 | 成品 | 基础成功值 | 基础耗时 |
|--------|------|---------|------|-----------|---------|
| `health_pill` | 补血丹 | 灵草×2 | 补血丹×1 | 20 | 5秒 |
| `spirit_pill` | 补气丹 | 灵草×5 | 补气丹×1 | 20 | 5秒 |
| `foundation_pill` | 筑基丹 | 破境草×3 + 灵草×10 | 筑基丹×1 | 30 | 10秒 |
| `golden_core_pill` | 金丹丹 | 破境草×3 + 筑基丹×3 + 灵草×10 | 金丹丹×1 | 40 | 15秒 |

#### 2.1.3 炼丹术法（杂学术法）
- **术法ID**: `alchemy`
- **类型**: 杂学术法（MISC）
- **等级**: 1-3级

| 等级 | 成功值加成 | 速度加成 | 升级灵气消耗 | 使用次数需求 |
|------|-----------|---------|-------------|-------------|
| 1级 | +10 | +0.1 | 100 | 10 |
| 2级 | +20 | +0.2 | 300 | 30 |
| 3级 | +30 | +0.3 | 600 | 60 |

#### 2.1.4 丹炉道具
- **道具ID**: `alchemy_furnace`
- **名称**: 初级丹炉
- **属性**:
  - 成功值: +10
  - 速度加成: +0.1
- **说明**: 没有丹炉时也可以炼丹，只是没有丹炉加成

### 2.2 炼丹机制

#### 2.2.1 成功率计算
```
最终成功值 = 丹方基础成功值 + 炼丹术成功值加成 + 丹炉成功值加成
成功率 = clamp(最终成功值, 1, 100)%
```

**示例**:
- 筑基丹基础成功值: 30
- 炼丹术2级加成: +20
- 初级丹炉加成: +10
- 最终成功值: 30 + 20 + 10 = 60
- 成功率: 60%

#### 2.2.2 炼制耗时计算
```
最终速度 = 1 + 炼丹术速度加成 + 丹炉速度加成
实际耗时 = 丹方基础耗时 / 最终速度
```

**示例**:
- 筑基丹基础耗时: 10秒
- 炼丹术2级速度加成: 0.2
- 丹炉速度加成: 0.1
- 最终速度: 1 + 0.2 + 0.1 = 1.3
- 实际耗时: 10 / 1.3 = 7.69秒

#### 2.2.3 材料消耗
- **炼制成功**: 消耗全部材料
- **炼制失败**: 消耗一半材料（向上取整），返还另一半材料（向下取整）
  - 例如：消耗3颗灵草，失败时返还1颗，实际消耗2颗
- **材料不足**: 无法开始炼制
- **消耗时机**: 开始炼制时检测总数是否足够，然后消耗第一颗材料；每颗完成后消耗下一颗材料

#### 2.2.4 灵气消耗
- 每种丹方可能有灵气消耗需求
- 灵气不足时无法开始炼制
- 每颗炼制开始时单独消耗灵气

### 2.3 道具配置

#### 2.3.1 丹方道具（ItemData.gd）
```gdscript
"recipe_health_pill": {
    "id": "recipe_health_pill",
    "name": "补血丹丹方",
    "type": 3,  // 消耗品
    "quality": 1,
    "description": "记载补血丹炼制方法的丹方，使用后学会炼制补血丹",
    "effect": {
        "type": "learn_recipe",
        "recipe_id": "health_pill"
    }
},
"recipe_spirit_pill": {
    "id": "recipe_spirit_pill",
    "name": "补气丹丹方",
    "type": 3,
    "quality": 1,
    "description": "记载补气丹炼制方法的丹方，使用后学会炼制补气丹",
    "effect": {
        "type": "learn_recipe",
        "recipe_id": "spirit_pill"
    }
},
"recipe_foundation_pill": {
    "id": "recipe_foundation_pill",
    "name": "筑基丹丹方",
    "type": 3,
    "quality": 2,
    "description": "记载筑基丹炼制方法的珍贵丹方，使用后学会炼制筑基丹",
    "effect": {
        "type": "learn_recipe",
        "recipe_id": "foundation_pill"
    }
},
"recipe_golden_core_pill": {
    "id": "recipe_golden_core_pill",
    "name": "金丹丹丹方",
    "type": 3,
    "quality": 3,
    "description": "记载金丹丹炼制方法的稀有丹方，使用后学会炼制金丹丹",
    "effect": {
        "type": "learn_recipe",
        "recipe_id": "golden_core_pill"
    }
}
```

#### 2.3.2 丹炉道具（ItemData.gd）
```gdscript
"alchemy_furnace": {
    "id": "alchemy_furnace",
    "name": "初级丹炉",
    "type": 1,  // 材料/道具
    "quality": 2,
    "max_stack": 1,
    "description": "炼丹的基础工具，可提升炼丹成功率和速度",
    "icon": "res://assets/items/alchemy_furnace.png"
}
```

#### 2.3.3 炼丹术法（SpellData.gd）
```gdscript
"alchemy": {
    "id": "alchemy",
    "name": "炼丹术",
    "type": 3,  // MISC 杂学术法
    "quality": 2,
    "description": "提升炼丹成功率和速度的杂学术法，通过炼制丹药提升熟练度",
    "max_level": 3,
    "levels": {
        "1": {
            "spirit_cost": 100,
            "use_count_required": 10,
            "attribute_bonus": {},
            "effect": {
                "success_bonus": 10,
                "speed_bonus": 0.1
            }
        },
        "2": {
            "spirit_cost": 300,
            "use_count_required": 30,
            "attribute_bonus": {},
            "effect": {
                "success_bonus": 20,
                "speed_bonus": 0.2
            }
        },
        "3": {
            "spirit_cost": 600,
            "use_count_required": 60,
            "attribute_bonus": {},
            "effect": {
                "success_bonus": 30,
                "speed_bonus": 0.3
            }
        }
    }
}
```

### 2.4 丹方配置（AlchemyRecipeData.gd）

```gdscript
extends Node

var recipes: Dictionary = {
    "health_pill": {
        "id": "health_pill",
        "name": "补血丹",
        "success_value": 20,
        "base_time": 5.0,
        "materials": {
            "mat_herb": 2
        },
        "product": "health_pill",
        "product_count": 1
    },
    "spirit_pill": {
        "id": "spirit_pill",
        "name": "补气丹",
        "success_value": 20,
        "base_time": 5.0,
        "materials": {
            "mat_herb": 5
        },
        "product": "spirit_pill",
        "product_count": 1
    },
    "foundation_pill": {
        "id": "foundation_pill",
        "name": "筑基丹",
        "success_value": 30,
        "base_time": 10.0,
        "materials": {
            "foundation_herb": 3,
            "mat_herb": 10
        },
        "product": "foundation_pill",
        "product_count": 1
    },
    "golden_core_pill": {
        "id": "golden_core_pill",
        "name": "金丹丹",
        "success_value": 40,
        "base_time": 15.0,
        "materials": {
            "foundation_herb": 3,
            "foundation_pill": 3,
            "mat_herb": 10
        },
        "product": "golden_core_pill",
        "product_count": 1
    }
}

func get_recipe_data(recipe_id: String) -> Dictionary:
    return recipes.get(recipe_id, {})

func get_all_recipe_ids() -> Array:
    return recipes.keys()
```

## 三、UI设计

### 3.1 洞府页面
```
┌─────────────────────────────────────────┐
│              洞府                        │
├─────────────────────────────────────────┤
│                                         │
│         [ 炼丹房 ]                      │
│                                         │
│         [ 其他功能 ]                    │
│                                         │
└─────────────────────────────────────────┘
```

### 3.2 炼丹房页面（初始状态）
```
┌─────────────────────────────────────────┐
│              炼丹房                      │
├─────────────────────────────────────────┤
│                                         │
│         暂无学会的丹方                  │
│                                         │
│    使用丹方道具后可在此炼制丹药         │
│                                         │
└─────────────────────────────────────────┘
```

### 3.3 炼丹房页面（学会丹方后）
```
┌─────────────────────────────────────────┐
│              炼丹房                      │
├──────────────────┬──────────────────────┤
│    丹方列表       │     炼丹操作区        │
│  (可滚动)         │                      │
│                  │  丹方名称: 筑基丹      │
│ ┌─────────────┐  │  成功率: 60%          │
│ │ 补血丹丹方   │  │  耗时: 7.7秒/颗       │
│ ├─────────────┤  │                      │
│ │ 补气丹丹方   │  │  材料需求:            │
│ ├─────────────┤  │  破境草: 5/3          │
│ │ 筑基丹丹方   │  │  灵草: 15/10          │
│ ├─────────────┤  │                      │
│ │ 金丹丹丹方   │  │  数量: [1] [10] [100] [Max] │
│ └─────────────┘  │                      │
│                  │  [开始炼制]           │
│                  │                      │
├──────────────────┴──────────────────────┤
│  炼丹术: LV.2 (+20成功值, +0.2速度)      │
│  丹炉: 初级丹炉 (+10成功值, +0.1速度)     │
├─────────────────────────────────────────┤
│  炼丹日志:                               │
│  [10:23:15] 开始炼制 筑基丹 ×10          │
│  [10:23:30] 炼制成功！获得 筑基丹 ×6     │
│  [10:23:30] 炼制失败 4次                 │
└─────────────────────────────────────────┘
```

## 四、与其他系统联动

### 4.1 与术法系统联动
- 炼丹术作为杂学术法，使用现有术法系统的升级机制
- 每次炼制丹药增加炼丹术使用次数
- 炼丹术等级影响成功率和速度

### 4.2 与储纳系统联动
- 炼制时从储纳中扣除材料
- 炼制成功将成品存入储纳
- 实时显示材料拥有数量

### 4.3 与物品系统联动
- 丹方道具使用后可学会对应丹方
- 丹炉道具存放在储纳中，拥有即可生效
- 支持消耗其他丹药作为材料（如金丹丹需要筑基丹）

### 4.4 与玩家数据联动
- 已学会丹方列表存储在玩家数据中
- 是否拥有丹炉标记存储在玩家数据中
- 支持存档/读档

## 五、核心接口

### 5.1 AlchemySystem.gd（逻辑层）

#### 信号
```gdscript
signal recipe_learned(recipe_id: String)                    # 学习丹方
signal crafting_started(recipe_id: String, count: int)      # 开始炼制
signal crafting_progress(current: int, total: int, progress: float)  # 炼制进度
signal single_craft_completed(success: bool, recipe_name: String)    # 单颗完成
signal crafting_finished(recipe_id: String, success_count: int, fail_count: int)  # 全部完成
signal crafting_stopped(completed_count: int, remaining_count: int)  # 停止炼制
signal log_message(message: String)                         # 日志消息
```

#### 状态变量
```gdscript
var is_crafting: bool = false           # 是否正在炼制
var current_craft_recipe: String = ""   # 当前丹方ID
var current_craft_count: int = 0        # 目标炼制数量
var current_craft_index: int = 0        # 当前炼制索引
var craft_timer: float = 0.0            # 当前计时器
var craft_success_count: int = 0        # 成功数量
var craft_fail_count: int = 0           # 失败数量
var craft_time_per_pill: float = 0.0    # 每颗耗时
```

#### 核心方法
```gdscript
# 学习丹方（使用丹方道具时调用）
func learn_recipe(recipe_id: String) -> bool

# 检查是否学会丹方
func has_learned_recipe(recipe_id: String) -> bool

# 获取已学会的丹方列表
func get_learned_recipes() -> Array

# 计算成功率（百分比）
func calculate_success_rate(recipe_id: String) -> int

# 计算炼制耗时（秒/颗）
func calculate_craft_time(recipe_id: String) -> float

# 检查材料是否足够
func check_materials(recipe_id: String, count: int) -> Dictionary

# 检查灵气是否足够
func check_spirit_energy(recipe_id: String, count: int) -> Dictionary

# 开始批量炼制
func start_crafting_batch(recipe_id: String, count: int) -> Dictionary

# 停止炼制
func stop_crafting() -> Dictionary

# 获取炼制预览信息
func get_craft_preview(recipe_id: String, count: int) -> Dictionary

# 获取当前炼制状态
func get_crafting_state() -> Dictionary

# 获取炼丹术加成
func get_alchemy_bonus() -> Dictionary

# 获取丹炉加成
func get_furnace_bonus() -> Dictionary
```

#### 炼丹循环（_process）
```gdscript
func _process(delta):
    if not is_crafting:
        return
    
    craft_timer += delta
    
    # 发送进度信号
    var progress = (craft_timer / craft_time_per_pill) * 100.0
    crafting_progress.emit(current_craft_index + 1, current_craft_count, min(progress, 100.0))
    
    # 完成单颗炼制
    if craft_timer >= craft_time_per_pill:
        craft_timer = 0.0
        _complete_single_pill()
```

### 5.2 AlchemyModule.gd（UI层）

#### 信号
```gdscript
signal recipe_selected(recipe_id: String)    # 选择丹方
signal log_message(message: String)          # 日志消息
signal back_to_dongfu_requested              # 返回洞府
```

#### 核心方法
```gdscript
# 初始化
func initialize(ui: Node, player_node: Node, alchemy_sys: Node, recipe_data_node: Node, item_data_node: Node)

# 显示/隐藏
func show_alchemy_room()
func hide_alchemy_room()

# 刷新UI
func refresh_ui()

# 设置炼制数量
func set_craft_count(count: int)

# 获取最大可炼制数量
func get_max_craft_count() -> int

# 检查是否正在炼制
func is_crafting_active() -> bool
```

#### 信号连接（监听 AlchemySystem）
```gdscript
func _connect_alchemy_signals():
    alchemy_system.crafting_started.connect(_on_alchemy_crafting_started)
    alchemy_system.crafting_progress.connect(_on_alchemy_crafting_progress)
    alchemy_system.single_craft_completed.connect(_on_alchemy_single_craft_completed)
    alchemy_system.crafting_finished.connect(_on_alchemy_crafting_finished)
    alchemy_system.crafting_stopped.connect(_on_alchemy_crafting_stopped)
    alchemy_system.log_message.connect(_on_alchemy_log_message)
```

### 5.3 玩家数据扩展（PlayerData.gd）
```gdscript
# 已学会的丹方ID列表
var learned_recipes: Array = []
```

### 5.4 丹炉配置（AlchemySystem.gd）
```gdscript
# 丹炉配置（硬编码，支持多丹炉扩展）
const FURNACE_CONFIGS = {
    "alchemy_furnace": {
        "name": "初级丹炉",
        "success_bonus": 10,
        "speed_rate": 0.1
    }
}

# 装备的丹炉ID（空字符串表示无丹炉）
var equipped_furnace_id: String = ""
```

### 5.5 存档数据格式
```json
{
    "player": {
        "realm": "炼气期",
        "realm_level": 1,
        "learned_recipes": ["health_pill"]
    },
    "inventory": {
        "capacity": 50,
        "slots": {
            "0": {"id": "spirit_stone", "count": 100},
            "5": {"id": "herb", "count": 50}
        }
    },
    "alchemy_system": {
        "equipped_furnace_id": "alchemy_furnace"
    }
}
```

## 六、炼丹流程详解

### 6.1 炼丹状态机

```
┌─────────────┐     start_crafting_batch()     ┌─────────────┐
│   空闲      │ ─────────────────────────────► │   炼制中    │
│is_crafting  │                                │is_crafting  │
│   = false   │     stop_crafting()            │   = true    │
└─────────────┘ ◄───────────────────────────── └─────────────┘
                      或 crafting_finished
```

### 6.2 开始炼制流程

```
┌──────────────────────────────────────────────────────────────┐
│                start_crafting_batch(recipe_id, count)        │
├──────────────────────────────────────────────────────────────┤
│  1. 检查是否学会丹方                                          │
│  2. 检查是否正在炼制                                          │
│  3. 检查材料总数是否足够（count颗）                            │
│  4. 检查灵气总数是否足够（count颗）                            │
│  5. 初始化炼制状态                                            │
│     - is_crafting = true                                     │
│     - current_craft_recipe = recipe_id                       │
│     - current_craft_count = count                            │
│     - current_craft_index = 0                                │
│     - current_material_consumed = false                      │
│  6. 检查第一颗材料是否足够                                     │
│  7. 消耗第一颗材料                                            │
│  8. current_material_consumed = true                         │
│  9. 发送 crafting_started 信号                               │
└──────────────────────────────────────────────────────────────┘
```

### 6.3 单颗炼制流程

```
┌──────────────────────────────────────────────────────────────┐
│                    _complete_single_pill()                   │
├──────────────────────────────────────────────────────────────┤
│  1. current_craft_index += 1                                 │
│  2. current_material_consumed = false                        │
│  3. 计算成功率，随机判定成功/失败                             │
│  4. 增加炼丹术使用次数                                        │
│  5. 成功: 产出丹药 → craft_success_count += 1                │
│     失败: 返还一半材料（向下取整）→ craft_fail_count += 1    │
│     （注：材料已在炼制开始时消耗，失败时返还一半）            │
│  6. 发送 single_craft_completed 信号                         │
│  7. 检查是否完成全部:                                         │
│     - 是: _finish_crafting()                                 │
│     - 否: 检查材料 → 消耗下一颗材料 → current_material_consumed = true │
└──────────────────────────────────────────────────────────────┘
```

### 6.4 停止炼制流程

```
┌──────────────────────────────────────────────────────────────┐
│                     stop_crafting()                          │
├──────────────────────────────────────────────────────────────┤
│  1. 如果当前正在炼制的丹药已消耗材料（current_material_consumed = true）│
│     - 返还这一颗丹药的全部材料                                │
│     - 返还这一颗丹药的灵气                                    │
│  2. 发送日志消息                                              │
│  3. _reset_crafting_state()                                  │
│  4. 发送 crafting_stopped 信号                               │
└──────────────────────────────────────────────────────────────┘
```

## 七、实施步骤

### 阶段1: 数据配置
1. ItemData.gd - 添加4个丹方道具 + 丹炉道具
2. SpellData.gd - 添加炼丹术法
3. 新建 AlchemyRecipeData.gd - 丹方配置

### 阶段2: 核心系统
1. 新建 AlchemySystem.gd - 炼丹逻辑
2. PlayerData.gd - 添加炼丹相关数据
3. Inventory.gd - 添加丹方使用效果处理

### 阶段3: UI界面
1. Main.tscn - 炼丹房按钮和炼丹页面
2. GameUI.gd - 添加炼丹相关函数

### 阶段4: 集成测试
1. 测试丹方学习
2. 测试炼丹流程
3. 测试材料消耗和产出

## 八、存档数据结构

```gdscript
# PlayerData 存档扩展
{
    "learned_recipes": ["health_pill", "spirit_pill"],
    "has_alchemy_furnace": true
}
```

## 九、注意事项

1. **丹方命名规范**: 解锁类道具以系统名开头，如 `recipe_health_pill`
2. **材料消耗**: 失败时返还一半材料（向下取整），实际消耗一半材料（向上取整）
3. **成功率限制**: 最低1%，最高100%
4. **速度计算**: 基础速度1 + 炼丹术加成 + 丹炉加成
5. **批量炼制**: 每颗丹药独立计算成功/失败
6. **日志显示**: 使用富文本框显示炼丹日志
7. **架构原则**: 逻辑在 AlchemySystem，UI 在 AlchemyModule，通过信号通信
8. **定时器选择**: 使用 `_process(delta)` 而非递归定时器，避免状态同步问题
9. **初始化顺序**: `AlchemyModule` 初始化时 `alchemy_system` 可能为 null，需要在 `set_alchemy_system()` 后重新调用 `_connect_alchemy_signals()` 连接信号
10. **材料消耗时机**: 开始炼制时检测总数是否足够，然后消耗第一颗材料；每颗完成后消耗下一颗材料
11. **停止返还**: 停止炼制时，如果当前正在炼制的丹药已消耗材料，则返还这一颗丹药的全部材料
12. **UI刷新**: 每次进入炼丹房时，调用 `_update_craft_panel()` 刷新成功率、耗时等信息

## 十、文件结构

```
scripts/core/alchemy/
├── AlchemySystem.gd          # 炼丹系统核心逻辑
├── AlchemyRecipeData.gd      # 丹方数据配置
└── recipes.json             # 丹方配置文件

scripts/ui/modules/
└── AlchemyModule.gd        # 炼丹UI模块
```

---

**文档版本**: 2.3  
**创建日期**: 2026-02-23  
**最后更新**: 2026-03-14  
**更新内容**: 更新文件路径和目录结构