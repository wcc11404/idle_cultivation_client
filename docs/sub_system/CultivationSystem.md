# 修炼系统文档 (CultivationSystem)

## 1. 系统概述

修炼系统是游戏的核心挂机玩法系统，负责管理玩家的修炼过程、境界突破和离线收益。玩家通过修炼积累灵气，突破境界提升属性，离线时也能获得收益。

### 1.1 核心设计理念
- **挂机修炼**：自动积累灵气，无需手动操作
- **境界晋升**：多境界多层次的成长体系
- **离线收益**：离线期间也能获得资源和灵气
- **属性成长**：每次突破都会提升基础属性

### 1.2 系统组成

| 子系统 | 说明 | 核心文件 |
|--------|------|----------|
| 修炼系统 | 灵气积累和气血恢复 | scripts/core/realm/CultivationSystem.gd |
| 境界系统 | 境界配置和突破逻辑 | scripts/core/realm/RealmSystem.gd |
| 离线收益 | 离线奖励计算 | scripts/core/OfflineReward.gd |
| 内视UI | 修炼界面展示 | scripts/ui/modules/NeishiModule.gd |

---

## 2. 系统架构

### 2.1 文件结构
```
scripts/core/
├── OfflineReward.gd        # 离线收益计算
├── realm/
│   ├── CultivationSystem.gd    # 修炼系统核心逻辑
│   ├── RealmSystem.gd          # 境界系统配置
│   └── realms.json             # 境界配置文件
└── ui/modules/
    └── NeishiModule.gd     # 内视UI模块
```

### 2.2 核心常量定义

```gdscript
# CultivationSystem.gd
const BASE_HEAL_PER_SECOND: float = 1.0  # 基础气血恢复（每秒，float类型）
const cultivation_interval: float = 1.0  # 修炼间隔（秒）
```

> **数值规范**：修炼系统所有数值计算使用 `float` 类型，UI显示时调用 `AttributeCalculator` 格式化函数。详见 [属性数值系统规范](./AttributeSystem.md)。

### 2.3 主要数据结构

#### 2.3.1 境界配置 (REALMS)
```gdscript
{
    "炼气期": {
        "max_level": 10,                    # 最大层数
        "level_names": {1: "一层", ...},    # 层数名称
        "levels": {
            1: {
                "health": 50,               # 气血值
                "attack": 5,                # 攻击力
                "defense": 2,               # 防御力
                "spirit_stone_cost": 4,     # 突破所需灵石
                "spirit_energy_cost": 5,    # 突破所需灵气
                "max_spirit_energy": 5      # 最大灵气值
            },
            # ... 其他层数
        },
        "next_realm": "筑基期",             # 下一境界
        "description": "引气入体，修炼入门", # 境界描述
        "spirit_gain_speed": 1              # 灵气获取速度倍率
    }
    # ... 其他境界
}
```

#### 2.3.2 突破材料配置
```gdscript
# 大境界突破材料
"realm_breakthrough": {
    "炼气期": {"foundation_pill": 1},      # 炼气→筑基需要1个筑基丹
    "筑基期": {"golden_core_pill": 1},     # 筑基→金丹需要1个金丹
    # ...
}

# 小境界突破材料（特定层数）
"level_breakthrough": {
    "筑基期": {
        "3": {"foundation_pill": 1},       # 3层→4层需要1个筑基丹
        "6": {"foundation_pill": 1},       # 6层→7层需要1个筑基丹
        "9": {"foundation_pill": 2}        # 9层→10层需要2个筑基丹
    }
    # ...
}
```

---

## 3. 命名规范

### 3.1 境界命名规范

| 命名 | 说明 | 示例 |
|------|------|------|
| `realm_name` | 境界名称 | "炼气期", "筑基期" |
| `level` | 层数（1-10） | 1, 2, 3...10 |
| `level_name` | 层数显示名称 | "一层", "二层", "大圆满" |

### 3.2 突破材料命名

| 材料ID | 用途 | 对应境界 |
|--------|------|----------|
| `foundation_pill` | 筑基丹 | 炼气期→筑基期 |
| `golden_core_pill` | 金丹 | 筑基期→金丹期 |
| `nascent_soul_pill` | 元婴丹 | 金丹期→元婴期 |
| `spirit_separation_pill` | 化神丹 | 元婴期→化神期 |
| `void_refining_pill` | 炼虚丹 | 化神期→炼虚期 |
| `body_integration_pill` | 合体丹 | 炼虚期→合体期 |
| `mahayana_pill` | 大乘丹 | 合体期→大乘期 |
| `tribulation_pill` | 渡劫丹 | 大乘期→渡劫期 |

### 3.3 属性字段命名

| 字段名 | 含义 | 类型 | 说明 |
|--------|------|------|------|
| `health` | 气血值 | float | 当前气血，上限为 `final_max_health` |
| `spirit_energy` | 灵气值 | float | 当前灵气，上限为 `final_max_spirit` |
| `base_max_health` | 基础气血上限 | float | 随境界变化的基础值 |
| `base_max_spirit` | 基础灵气上限 | float | 随境界变化的基础值 |
| `base_attack` | 基础攻击 | float | 随境界变化的基础值 |
| `base_defense` | 基础防御 | float | 随境界变化的基础值 |
| `base_speed` | 基础速度 | float | 随境界变化的基础值 |
| `base_spirit_gain` | 基础灵气获取 | float | 随境界变化的基础值 |
| `spirit_stone_cost` | 突破所需灵石 | int | 突破消耗 |
| `spirit_energy_cost` | 突破所需灵气 | int | 突破消耗 |

> **注意**：所有基础属性都是 `float` 类型，最终属性通过 `AttributeCalculator` 计算获得。详见 [属性数值系统规范](./AttributeSystem.md) 第1.1节。

---

## 4. 主体逻辑

### 4.1 修炼流程

```
开始修炼 (start_cultivation)
    ↓
每1秒执行一次 (do_cultivate)
    ↓
恢复气血
    ├── 基础恢复：1点/秒
    └── 吐纳术法加成：max_health * heal_percent
    ↓
增加灵气
    ├── 基础速度：1点/秒
    └── 境界倍率：spirit_gain_speed
    ↓
检查灵气是否已满
    ├── 已满 → 发送 cultivation_complete 信号
    └── 未满 → 继续修炼
```

### 4.2 突破流程

```
尝试突破 (attempt_breakthrough)
    ↓
检查突破条件 (can_breakthrough)
    ├── 检查是否最高境界
    ├── 检查灵气是否足够
    ├── 检查灵石是否足够
    └── 检查材料是否足够
    ↓
条件满足？
    ├── 否 → 返回失败原因
    └── 是 → 扣除资源
        ↓
        执行突破
        ├── 小境界突破：层数 + 1
        └── 大境界突破：切换到下一境界，层数 = 1
        ↓
        更新玩家属性
        ↓
        发送 breakthrough_success 信号
```

### 4.3 离线收益计算流程

```
计算离线时间
    ↓
限制离线时间范围
    ├── 最小：1分钟（不足则无收益）
    └── 最大：4小时（超出按4小时算）
    ↓
计算收益
    ├── 灵气 = spirit_per_second * offline_seconds
    └── 灵石 = stone_per_minute * offline_minutes
    ↓
应用上限
    ├── 灵气上限：max_spirit_energy * 60
    └── 灵石：向下取整
    ↓
返回收益数据
    ↓
应用收益 (apply_offline_reward)
    ├── 增加灵气
    └── 添加灵石到背包
```

---

## 5. 核心功能详解

### 5.1 修炼系统

#### 5.1.1 气血恢复机制

**数据来源**：使用**静态最终属性**计算，详见 [属性数值系统规范](./AttributeSystem.md) 第1.2节。

```gdscript
func do_cultivate():
    # 使用AttributeCalculator获取最终最大气血值（float）
    var final_max_health = AttributeCalculator.calculate_final_max_health(player)
    
    # 基础恢复 + 吐纳术法加成（全程float计算）
    var total_heal = BASE_HEAL_PER_SECOND
    var breathing_effect = spell_system.get_equipped_breathing_heal_effect()
    if breathing_effect.heal_amount > 0:
        # heal_amount 是百分比（如0.002 = 0.2%），直接相乘
        total_heal += final_max_health * breathing_effect.heal_amount
    
    # 应用气血恢复（float计算，不截断）
    if player.health < final_max_health:
        player.health = min(final_max_health, player.health + total_heal)
```

**显示规则**：
- 气血值显示：`AttributeCalculator.format_integer()`（保留整数）
- 气血上限显示：`AttributeCalculator.format_integer()`（保留整数）

#### 5.1.2 灵气获取机制
```gdscript
# 从RealmSystem获取灵气获取速度
var spirit_gain = realm_system.get_spirit_gain_speed(player.realm)
player.add_spirit_energy(spirit_gain)
```

### 5.2 境界系统

#### 5.2.1 境界列表

| 境界 | 最大层数 | 灵气倍率 | 描述 |
|------|----------|----------|------|
| 炼气期 | 10 | 1.0 | 引气入体，修炼入门 |
| 筑基期 | 10 | 1.2 | 凝聚道基，初步成仙 |
| 金丹期 | 10 | 1.5 | 凝结金丹，蜕凡成仙 |
| 元婴期 | 10 | 2.0 | 元婴出窍，神通广大 |
| 化神期 | 10 | 3.0 | 返璞归真，化神为虚 |
| 炼虚期 | 10 | 5.0 | 虚实合一，神通无量 |
| 合体期 | 10 | 9.0 | 天地合一，接近仙人 |
| 大乘期 | 10 | 18.0 | 功德圆满，渡劫飞升 |
| 渡劫期 | 10 | 40.0 | 历尽天劫，羽化登仙 |

#### 5.2.2 突破材料配置

**大境界突破材料**：
| 当前境界 | 目标境界 | 所需材料 | 数量 |
|----------|----------|----------|------|
| 炼气期 | 筑基期 | 筑基丹 | 1 |
| 筑基期 | 金丹期 | 金丹 | 1 |
| 金丹期 | 元婴期 | 元婴丹 | 1 |
| 元婴期 | 化神期 | 化神丹 | 1 |
| 化神期 | 炼虚期 | 炼虚丹 | 1 |
| 炼虚期 | 合体期 | 合体丹 | 1 |
| 合体期 | 大乘期 | 大乘丹 | 1 |
| 大乘期 | 渡劫期 | 渡劫丹 | 1 |

**小境界突破材料**（特定层数）：
| 境界 | 层数 | 所需材料 | 数量 |
|------|------|----------|------|
| 筑基期 | 3→4, 6→7 | 筑基丹 | 1 |
| 筑基期 | 9→10 | 筑基丹 | 2 |
| 金丹期 | 3→4, 6→7 | 金丹 | 1 |
| 金丹期 | 9→10 | 金丹 | 2 |
| ... | ... | ... | ... |

### 5.3 离线收益系统

#### 5.3.1 收益计算规则
```gdscript
# 灵气收益
spirit_per_second = player.get_spirit_gain_speed()  # 每秒灵气获取速度
total_spirit = spirit_per_second * offline_seconds * efficiency
max_spirit = player.max_spirit_energy * 60  # 上限
total_spirit = min(total_spirit, max_spirit)

# 灵石收益
stone_per_minute = 1.0  # 每分钟1个灵石
total_stone = int(stone_per_minute * total_minutes)
```

#### 5.3.2 时间限制
- **最小离线时间**：1分钟（不足则无收益）
- **最大离线时间**：4小时（超出部分无收益）
- **效率**：固定1.0（无衰减）

---

## 6. 与其他系统的联动

### 6.1 与术法系统的联动

#### 6.1.1 吐纳心法效果
```gdscript
# 修炼时自动触发吐纳心法
var breathing_effect = spell_system.get_equipped_breathing_heal_effect()
if breathing_effect.heal_amount > 0:
    total_heal += int(final_max_health * breathing_effect.heal_amount)
    spell_system.add_spell_use_count(breathing_spell_id)  # 增加使用次数
```

### 6.2 与储纳系统的联动

#### 6.2.1 突破材料检查
```gdscript
# 检查背包中是否有足够材料
var inventory_items = inventory.get_all_items()
var can_break = realm_system.can_breakthrough(
    realm, level, spirit_stone, spirit_energy, inventory_items
)
```

#### 6.2.2 离线收益发放
```gdscript
# 离线灵石发放到背包
if rewards.spirit_stone > 0:
    inventory.add_item("spirit_stone", rewards.spirit_stone)
```

### 6.3 与UI系统的联动

#### 6.3.1 信号定义
```gdscript
# CultivationSystem 信号
signal cultivation_progress(current: int, max: int)  # 修炼进度
signal cultivation_complete()                         # 灵气已满

# RealmSystem 信号
signal breakthrough_success(new_realm: String, new_level: int)  # 突破成功
signal breakthrough_failed(reason: String)                      # 突破失败

# OfflineReward 信号
signal offline_reward_calculated(rewards: Dictionary)  # 离线收益计算完成

# NeishiModule 信号
signal cultivation_started      # 开始修炼
signal breakthrough_requested   # 请求突破
```

---

## 7. 境界属性表

### 7.1 炼气期

| 层数 | 气血 | 攻击 | 防御 | 突破灵石 | 突破灵气 | 最大灵气 |
|------|------|------|------|----------|----------|----------|
| 1 | 50 | 5 | 2 | 4 | 5 | 5 |
| 5 | 76 | 9 | 4 | 12 | 20 | 20 |
| 10 | 150 | 20 | 9 | 24 | 80 | 80 |

### 7.2 筑基期

| 层数 | 气血 | 攻击 | 防御 | 突破灵石 | 突破灵气 | 最大灵气 |
|------|------|------|------|----------|----------|----------|
| 1 | 250 | 30 | 13 | 50 | 100 | 100 |
| 5 | 366 | 43 | 19 | 73 | 146 | 146 |
| 10 | 589 | 70 | 30 | 117 | 236 | 236 |

### 7.3 金丹期

| 层数 | 气血 | 攻击 | 防御 | 突破灵石 | 突破灵气 | 最大灵气 |
|------|------|------|------|----------|----------|----------|
| 1 | 1250 | 105 | 45 | 250 | 500 | 500 |
| 5 | 1830 | 153 | 65 | 366 | 732 | 732 |
| 10 | 2947 | 247 | 106 | 589 | 1178 | 1178 |

**注**：完整属性表见 RealmSystem.gd 中的 REALMS 常量

---

## 8. 关键函数索引

### 8.1 CultivationSystem 公共接口

| 函数名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `start_cultivation` | 无 | void | 开始修炼 |
| `stop_cultivation` | 无 | void | 停止修炼 |
| `do_cultivate` | 无 | void | 执行一次修炼（每秒调用） |
| `set_player` | `player_node: Node` | void | 设置玩家对象 |

### 8.2 RealmSystem 公共接口

| 函数名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `get_realm_info` | `realm_name: String` | Dictionary | 获取境界信息 |
| `get_level_info` | `realm_name, level` | Dictionary | 获取层数信息 |
| `get_max_spirit_energy` | `realm_name, level` | int | 获取最大灵气值 |
| `get_spirit_stone_cost` | `realm_name, level` | int | 获取突破所需灵石 |
| `get_spirit_energy_cost` | `realm_name, level` | int | 获取突破所需灵气 |
| `get_spirit_gain_speed` | `realm_name` | float | 获取灵气获取速度倍率 |
| `get_breakthrough_materials` | `realm, level, is_realm` | Dictionary | 获取突破材料 |
| `can_breakthrough` | `realm, level, stone, energy, items` | Dictionary | 检查是否可以突破 |
| `get_initial_stats` | 无 | Dictionary | 获取初始属性（炼气期1层） |
| `get_realm_display_name` | `realm, level` | String | 获取境界显示名称 |

### 8.3 OfflineReward 公共接口

| 函数名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `calculate_offline_reward` | `player, last_save_time` | Dictionary | 计算离线收益 |
| `apply_offline_reward` | `player, rewards` | void | 应用离线收益 |

### 8.4 NeishiModule 公共接口

| 函数名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `initialize` | `ui, player, cult_sys, spell_sys` | void | 初始化模块 |
| `show_tab` | 无 | void | 显示内视标签页 |
| `hide_tab` | 无 | void | 隐藏内视标签页 |
| `update_cultivation_ui` | 无 | void | 更新修炼UI |
| `update_breakthrough_ui` | 无 | void | 更新突破UI |
| `start_cultivation` | 无 | void | 开始修炼 |
| `stop_cultivation` | 无 | void | 停止修炼 |
| `attempt_breakthrough` | 无 | void | 尝试突破 |

---

## 9. 扩展指南

### 9.1 添加新境界

1. **在 RealmSystem.gd 的 REALMS 中添加配置**：
```gdscript
"新境界": {
    "max_level": 10,
    "level_names": {1: "一层", ...},
    "levels": {
        1: {
            "health": 100000,
            "attack": 1000,
            "defense": 500,
            "spirit_stone_cost": 10000,
            "spirit_energy_cost": 20000,
            "max_spirit_energy": 20000
        },
        # ... 其他层数
    },
    "next_realm": "",  # 最高境界为空
    "description": "境界描述",
    "spirit_gain_speed": 50.0
}
```

2. **添加上一境界的 next_realm 指向新境界**

3. **添加突破材料配置**：
```gdscript
"realm_breakthrough": {
    "上一境界": {"new_pill": 1}
}
```

### 9.2 修改离线收益规则

编辑 OfflineReward.gd 中的常量：
```gdscript
const MAX_OFFLINE_HOURS = 8.0      # 修改最大离线时间
const MIN_OFFLINE_MINUTES = 5.0    # 修改最小离线时间

# 修改收益计算
var stone_per_minute = 2.0         # 修改灵石获取速度
var efficiency = 0.8               # 修改效率（添加衰减）
```

### 9.3 添加新的突破材料

1. **在 ItemData.gd 中添加材料物品**
2. **在 RealmSystem.gd 的 BREAKTHROUGH_MATERIALS 中配置使用**

---

## 10. 注意事项

1. **修炼状态**：修炼时会自动恢复气血和增加灵气，停止修炼则暂停
2. **灵气上限**：灵气达到上限时会发送 cultivation_complete 信号，但不会自动停止修炼
3. **突破检查**：突破前必须检查所有条件（灵气、灵石、材料），缺一不可
4. **属性继承**：突破后玩家属性会根据新境界配置更新，旧属性不保留
5. **离线时间**：离线时间从上次存档时间计算，首次游戏无离线收益
6. **收益上限**：离线灵气收益有上限（max_spirit_energy * 60），防止过度积累
7. **存档要求**：OfflineReward 需要配合存档系统使用，记录 last_save_time
8. **境界显示**：使用 get_realm_display_name() 获取完整的境界显示名称
9. **材料名称**：突破材料的中文名称通过 ItemData 获取，确保物品已配置
10. **数值平衡**：境界属性呈指数增长，注意后期数值溢出问题

---

## 11. 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 1.0 | 2026-02-24 | 初始文档 |
| 1.1 | 2026-03-14 | 更新文件路径和目录结构 |