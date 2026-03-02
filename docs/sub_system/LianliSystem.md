# 历练系统文档 (LianliSystem)

## 1. 系统概述

历练系统是游戏中的核心战斗系统，采用**ATB（Active Time Battle，主动时间战斗）**机制，实现了回合制与实时制相结合的战斗体验。

**概念定义**：
- **历练 (Lianli)**：玩家进入历练区域进行的一系列战斗，直到主动退出或战败
- **战斗 (Battle)**：单次与敌人的对决，直到一方死亡
- 一次历练可以包含**多次战斗**

### 1.1 核心设计理念
- **ATB机制**：角色通过积累行动条（ATB）来触发行动，速度属性决定ATB积累速度
- **实时与回合结合**：战斗以固定频率（10次/秒）进行tick处理，模拟实时战斗
- **术法驱动**：战斗中的技能释放完全由装备的术法决定，包括主动攻击、被动buff等
- **气血系统**：采用"气血"作为生命值概念，区分当前气血和气血上限
- **连续战斗**：支持连续历练模式，战斗间隔3-5秒自动开始下一场

### 1.2 历练类型

| 类型 | 说明 | 特点 |
|------|------|------|
| **普通区域历练** | 炼气期/筑基期的外围/内围区域 | 可连续战斗，掉落灵石和术法 |
| **特殊区域历练** | 破境草洞穴等BOSS区域 | 单BOSS，通关后结束，特殊掉落，每日次数限制 |
| **无尽塔** | 挑战无尽层数 | 51层上限，每5层奖励，无掉落 |

---

## 2. 系统架构

### 2.1 文件位置

```
/scripts/core/lianli/
├── LianliSystem.gd        # 核心历练系统
├── LianliAreaData.gd      # 历练区域数据
├── EnemyData.gd           # 敌人数据
├── EndlessTowerData.gd    # 无尽塔数据
├── areas.json             # 区域配置
├── enemies.json           # 敌人配置
└── tower.json             # 无尽塔配置

/scripts/ui/modules/LianliModule.gd    # 历练UI模块
/scripts/ui/GameUI.gd                  # UI交互（历练相关部分）
```

### 2.2 核心常量定义

```gdscript
const ATB_MAX: float = 100.0              # ATB条最大值（满值100）
const TICK_INTERVAL: float = 0.1          # 每个tick的间隔时间（秒）
const DEFAULT_ENEMY_ATTACK: float = 50.0  # 默认敌人攻击
const PERCENTAGE_BASE: float = 100.0      # 百分比基数
```

> **数值规范**：历练系统所有数值计算使用 `float` 类型，UI显示时调用 `AttributeCalculator` 格式化函数。详见 [属性数值系统规范](../ATTRIBUTE_SYSTEM.md)。

### 2.3 主要数据结构

#### 2.3.1 历练状态
```gdscript
var is_in_lianli: bool = false           # 是否处于历练中（战斗中或等待中）
var is_in_battle: bool = false           # 是否处于战斗中
var is_waiting: bool = false             # 是否处于连续历练的等待间隔
var lianli_speed: float = 1.0            # 历练倍速（1.0-2.0）

# 无尽塔状态
var is_in_tower: bool = false            # 是否处于无尽塔中
var current_tower_floor: int = 0         # 当前无尽塔层数

# 连续历练设置
var continuous_lianli: bool = false      # 连续历练模式

# 区域默认连续战斗状态
var area_continuous_default: Dictionary = {
    "qi_refining_outer": true,
    "qi_refining_inner": true,
    "foundation_outer": true,
    "foundation_inner": true,
    "foundation_herb_cave": false,
    "endless_tower": false,
}
```

#### 2.3.2 ATB战斗数据
```gdscript
var player_atb: float = 0.0              # 玩家ATB值（0-100）
var enemy_atb: float = 0.0               # 敌人ATB值（0-100）
var tick_accumulator: float = 0.0        # 时间累积器
```

#### 2.3.3 战斗中的临时buff系统

**数据来源**：战斗Buff作用于**动态最终属性**计算，详见 [属性数值系统规范](../ATTRIBUTE_SYSTEM.md) 第1.3节。

```gdscript
var combat_buffs: Dictionary = {
    "attack_percent": 0.0,   # 攻击加成百分比（小数，如0.25 = 25%）
    "defense_percent": 0.0,  # 防御加成百分比（小数）
    "speed_bonus": 0.0,      # 速度加成固定值（float）
    "health_bonus": 0.0      # 气血加成固定值（float）
}
```

---

## 3. 状态机模型

### 3.1 状态定义

| 状态 | is_in_lianli | is_in_battle | is_waiting | 说明 |
|------|-------------|-------------|-----------|------|
| IDLE | false | false | false | 未历练/历练结束 |
| BATTLE | true | true | false | 战斗中 |
| WAITING | true | false | true | 等待下一场 |

### 3.2 状态判断规则

```gdscript
# 判断是否显示战斗场景
if is_in_lianli == true:
    显示战斗场景
else:
    显示区域选择页面
```

**关键点**：
- `is_in_lianli` 只在 `BATTLE` 或 `WAITING` 状态时为 `true`
- 战斗胜利（非连续模式）后，`is_in_lianli = false`，但不发 `lianli_ended` 信号
- 战斗失败后，`is_in_lianli = false`，并发 `lianli_ended` 信号
- 用户点击"继续战斗"时，检查条件后设置 `is_in_lianli = true`

### 3.3 普通区域状态流转

```
点击区域 → 检查气血>0 → is_in_lianli=true → BATTLE
                                        ↓
                                    战斗结束
                                   ↙        ↘
                            玩家胜利          玩家失败
                               ↓                ↓
                           发放奖励         is_in_lianli=false
                               ↓                ↓
                         连续战斗?          lianli_ended.emit()
                        ↙       ↘              
                      是         否           
                       ↓          ↓           
                   WAITING   is_in_lianli=false
                       ↓          ↓
                   计时结束    点击继续&气血>0
                       ↓          ↓
                   BATTLE     is_in_lianli=true → WAITING → BATTLE
```

### 3.4 特殊区域状态流转

```
点击区域 → 检查气血>0 & 次数>0 → is_in_lianli=true → BATTLE
                                                    ↓
                                                战斗结束
                                               ↙        ↘
                                        玩家胜利          玩家失败
                                           ↓                ↓
                                       发放奖励         is_in_lianli=false
                                           ↓                ↓
                                     次数-1            lianli_ended.emit()
                                           ↓
                                     连续战斗?
                                    ↙       ↘              
                                  是         否           
                                   ↓          ↓           
                               WAITING   is_in_lianli=false
                                   ↓          ↓
                               检查次数>0  点击继续&气血>0&次数>0
                                   ↓          ↓
                               BATTLE     is_in_lianli=true → WAITING → BATTLE
```

### 3.5 无尽塔状态流转

```
点击无尽塔 → 检查气血>0 → is_in_lianli=true, is_in_tower=true → BATTLE
                                                              ↓
                                                          战斗结束
                                                         ↙        ↘
                                                    玩家胜利          玩家失败
                                                       ↓                ↓
                                                   层数+1          is_in_lianli=false
                                                       ↓                ↓
                                                   判断奖励层数?   lianli_ended.emit()
                                                       ↓
                                                   发放奖励
                                                       ↓
                                                   连续战斗?
                                                  ↙       ↘              
                                                是         否           
                                                 ↓          ↓           
                                             WAITING   is_in_lianli=false
                                                 ↓          ↓
                                             检查层数≤最大  点击继续&气血>0
                                                 ↓          ↓
                                             BATTLE     is_in_lianli=true → WAITING → BATTLE
```

---

## 4. 历练区域配置

### 4.1 普通区域

| 区域ID | 名称 | 境界要求 | 敌人种类 | 默认连续 |
|--------|------|----------|----------|----------|
| `qi_refining_outer` | 炼气期外围森林 | 炼气期 | 野狼、毒蛇、野猪 | ✅ true |
| `qi_refining_inner` | 炼气期内围山谷 | 炼气期 | 野狼、毒蛇、野猪、铁背狼王 | ✅ true |
| `foundation_outer` | 筑基期外围荒原 | 筑基期 | 野狼、毒蛇、野猪 | ✅ true |
| `foundation_inner` | 筑基期内围沼泽 | 筑基期 | 野狼、毒蛇、野猪、铁背狼王 | ✅ true |

### 4.2 特殊区域（BOSS）

| 区域ID | 名称 | 特点 | 通关奖励 | 默认连续 |
|--------|------|------|----------|----------|
| `foundation_herb_cave` | 破境草洞穴 | 单BOSS（破境草看守者），每日次数限制 | 破境草x10，灵石x20 | ❌ false |

### 4.3 无尽塔

- **层数上限**：51层
- **奖励层**：5, 10, 15, 20, 25, 30, 35, 40, 45, 50层
- **奖励内容**：灵石（10-1060，随层数递增）
- **敌人**：随机模板（狼、蛇、野猪），等级=层数
- **默认连续**：❌ false

---

## 5. 连续战斗机制

### 5.1 默认连续状态

```gdscript
var area_continuous_default: Dictionary = {
    "qi_refining_outer": true,       # 普通区域默认连续
    "qi_refining_inner": true,
    "foundation_outer": true,
    "foundation_inner": true,
    "foundation_herb_cave": false,   # 特殊区域默认不连续
    "endless_tower": false,          # 无尽塔默认不连续
}
```

### 5.2 连续状态设置流程

```
进入历练区域
    ↓
start_lianli_in_area(area_id) / start_endless_tower()
    ↓
从 area_continuous_default 读取默认值
    ↓
设置 continuous_lianli = 默认值
    ↓
UI复选框同步显示
    ↓
用户可手动切换复选框
    ↓
on_continuous_toggled(enabled) → set_continuous_lianli(enabled)
```

### 5.3 战斗结束时的判断

```gdscript
# 在 _handle_battle_victory() 中
if continuous_lianli and is_in_lianli:
    # 进入等待状态，准备下一场战斗
    is_waiting = true
    wait_timer = 0.0
    current_wait_interval = get_wait_interval()
else:
    # 非连续战斗模式，结束历练（不发 lianli_ended）
    is_in_lianli = false
```

### 5.4 手动继续战斗

```gdscript
func start_wait_for_next_battle() -> bool:
    # 检查当前状态
    if is_in_battle or is_waiting:
        return false
    
    # 检查气血
    if player and player.health <= 0:
        log_message.emit("气血不足，无法开始战斗，请恢复气血")
        return false
    
    # 特殊区域检查次数
    if lianli_area_data and lianli_area_data.is_special_area(current_area_id):
        if player.get_daily_dungeon_count(current_area_id) <= 0:
            log_message.emit("今日次数已用完")
            return false
    
    # 无尽塔检查层数
    if is_in_tower:
        var max_floor = endless_tower_data.get_max_floor()
        if current_tower_floor + 1 > max_floor:
            return false
    
    # 设置状态
    is_in_lianli = true
    is_waiting = true
    wait_timer = 0.0
    current_wait_interval = get_wait_interval()
    return true
```

---

## 6. ATB机制详解

### 6.1 ATB增长公式
```gdscript
# 每0.1秒执行一次tick计算（双方都要受倍速影响）
player_atb += player_speed * lianli_speed
enemy_atb += enemy_speed * lianli_speed
```

**说明**：
- **玩家ATB**：增长速度 = 玩家速度 × 历练倍速
- **敌人ATB**：增长速度 = 敌人速度 × 历练倍速
- **倍速效果**：2倍速时，双方ATB增长速度都翻倍，战斗节奏加快

### 6.2 ATB满值判定
```gdscript
# ATB满值为100
if player_atb >= ATB_MAX:
    _execute_player_action()
    player_atb -= ATB_MAX  # 归零并保留溢出
```

**溢出保留机制**：
- 行动后ATB减去100，保留超出部分
- 例如：ATB=110时行动，行动后ATB=10
- 确保速度优势能延续到下一回合

### 6.3 ATB同时满值行动优先级

当玩家和敌人在同一tick达到满值时，按以下优先级判定行动顺序：

```gdscript
if player_ready and enemy_ready:
    # 同时达到满值
    if player_speed > enemy_speed:
        # 玩家速度快，玩家先行动
        _execute_player_action()
        if 敌人仍然存活:
            _execute_enemy_action()
    elif enemy_speed > player_speed:
        # 敌人速度快，敌人先行动
        _execute_enemy_action()
        if 玩家仍然存活:
            _execute_player_action()
    else:
        # 速度相同，玩家优先
        _execute_player_action()
        if 敌人仍然存活:
            _execute_enemy_action()
```

**优先级规则**：
1. **速度快者优先**：速度高的角色先行动
2. **速度相同，玩家优先**：平局时玩家获得先手优势
3. **连续行动检查**：一方行动后，检查对方是否仍然存活才执行对方行动

---

## 7. 伤害机制

### 7.1 基础伤害计算

**数据来源**：使用**动态最终属性**计算，详见 [属性数值系统规范](../ATTRIBUTE_SYSTEM.md) 第1.4节。

```gdscript
func calculate_damage(attack: float, defense: float) -> float
```
**公式**：
```
damage = max(1.0, attack - defense)
```
**说明**：
- 伤害至少为1.0（保底伤害机制）
- 纯减法公式，防御直接抵消攻击
- 返回 `float` 类型，UI显示时使用 `format_damage()` 格式化

**显示规则**：
- 伤害值 ≤ 1000：`format_one_decimal()`（保留一位小数）
- 伤害值 > 1000：`format_integer()`（保留整数）

### 7.2 术法伤害计算
```gdscript
# 触发了攻击术法
var damage_percent = effect.get("damage_percent", 1.0)  # 如1.30表示130%
var attack_buff_percent = combat_buffs.get("attack_percent", 0.0)

# 最终攻击力 = 基础攻击 × (1+攻击buff) × 术法伤害百分比
var final_attack = player_attack * (1.0 + attack_buff_percent) * damage_percent
var damage_to_enemy = calculate_damage(final_attack, enemy_defense)
```

---

## 8. 战斗Buff系统

### 8.1 Buff类型
```gdscript
var combat_buffs: Dictionary = {
    "attack_percent": 0.0,   # 攻击加成百分比（小数，如0.25 = 25%）
    "defense_percent": 0.0,  # 防御加成百分比（小数）
    "speed_bonus": 0.0,      # 速度加成固定值（float）
    "health_bonus": 0.0      # 气血加成固定值（float）
}
```

### 8.2 Buff生效机制

**开局触发**：
- 被动术法（PASSIVE类型）在战斗开始时自动触发
- 通过 `_trigger_start_spells()` 函数执行

**Buff应用**（全程float计算）：
```gdscript
# 攻击buff（百分比乘法）
combat_attack = final_attack * (1.0 + combat_buffs.attack_percent)

# 防御buff（百分比乘法）
combat_defense = final_defense * (1.0 + combat_buffs.defense_percent)

# 速度buff（固定值加法）
combat_speed = final_speed + combat_buffs.speed_bonus

# 气血buff（固定值加法）
combat_max_health = final_max_health + combat_buffs.health_bonus
```

### 8.3 气血Buff特殊机制

#### 8.3.1 战斗开始时应用
```gdscript
# 基础气血术法效果
var health_percent = effect_data.get("buff_percent", 0.0)
var bonus_health = int(player.max_health * health_percent)

# 同时增加气血上限和当前气血
combat_buffs.health_bonus += bonus_health
player.max_health += bonus_health
player.health += bonus_health
```

#### 8.3.2 战斗结束后恢复
```gdscript
func _restore_health_after_combat():
    if player and combat_buffs.get("health_bonus", 0.0) > 0:
        var health_bonus = int(combat_buffs.health_bonus)
        
        # 减少气血上限
        player.max_health -= health_bonus
        
        # 当前气血调整
        if player.health >= player.max_health:
            player.health = player.max_health
        # 否则保持当前值不变（保留战斗中恢复的气血）
```

---

## 9. 战斗结束处理

### 9.1 战斗胜利 (_handle_battle_victory)

#### 9.1.1 胜利条件
- 敌人气血降至0或以下
- 在 `_process_atb_tick()` 中检查

#### 9.1.2 胜利处理流程

```
战斗胜利
    ↓
is_in_battle = false
    ↓
恢复气血buff
    ↓
生成战利品
    ↓
发送 battle_ended 信号
    ↓
判断历练类型
    ├── 无尽塔 → _handle_tower_victory()
    │              ├── 更新最高层数
    │              ├── 发放奖励层奖励
    │              ├── 达到51层？ → is_in_lianli = false
    │              └── continuous_lianli？ → WAITING / is_in_lianli = false
    │
    ├── 特殊区域 → 消耗每日次数
    │              ├── continuous_lianli + 剩余次数 > 0？ → WAITING
    │              └── 否则 → is_in_lianli = false
    │
    └── 普通区域 → continuous_lianli？
                   ├── 是 → WAITING
                   └── 否 → is_in_lianli = false
```

**注意**：战斗胜利（非连续模式）不发 `lianli_ended` 信号，用户可以手动继续。

### 9.2 战斗失败 (_handle_battle_defeat)

#### 9.2.1 失败条件
- 玩家气血降至0或以下
- 在 `_process_atb_tick()` 中检查

#### 9.2.2 失败处理流程
```gdscript
func _handle_battle_defeat():
    # 恢复气血buff
    _restore_health_after_combat()
    
    # 根据历练类型输出不同日志
    if is_in_tower:
        log_message.emit("无尽塔挑战结束，最高到达第" + str(current_tower_floor) + "层")
    else:
        log_message.emit("气血不足，历练结束")
    
    # 发送战斗结束信号
    battle_ended.emit(false, [], current_enemy.get("name", ""))
    
    # 统一调用 end_lianli() 清理状态
    end_lianli()
```

**注意**：战斗失败会发 `lianli_ended` 信号。

### 9.3 状态清理 (end_lianli)

**统一清理函数**，在以下场景调用：
- 战斗失败
- 用户主动退出历练
- 通关无尽塔最高层

```gdscript
func end_lianli():
    is_in_lianli = false
    is_in_battle = false
    is_waiting = false
    is_in_tower = false
    current_tower_floor = 0
    current_enemy = {}
    tick_accumulator = 0.0
    _restore_health_after_combat()
    _reset_combat_buffs()
    _cached_spell_system = null
    lianli_ended.emit(false)
```

---

## 10. 与其他系统的联动

### 10.1 信号定义

```gdscript
# 历练相关信号
signal lianli_started(area_id: String)                                    # 历练开始（进入区域）
signal lianli_ended(victory: bool)                                        # 历练结束（失败或主动退出）
signal lianli_waiting(time_remaining: float)                              # 连续历练等待

# 战斗相关信号
signal battle_started(enemy_name: String, is_elite: bool, enemy_max_health: float, enemy_level: int, player_max_health: float)
signal battle_action_executed(is_player: bool, damage: float, is_spell: bool, spell_name: String)
signal battle_updated(player_atb: float, enemy_atb: float, player_health: float, enemy_health: float, player_max_health: float, enemy_max_health: float)
signal battle_ended(victory: bool, loot: Array, enemy_name: String)

# 其他信号
signal lianli_reward(item_id: String, amount: int, source: String)
signal log_message(message: String)
```

### 10.2 信号触发时机

| 信号 | 触发时机 | 说明 |
|------|----------|------|
| `lianli_started` | 进入历练区域时 | 开始历练 |
| `battle_started` | 单场战斗开始时 | 开始战斗 |
| `battle_action_executed` | 每次行动后 | 玩家或敌人行动 |
| `battle_updated` | 每次行动后 | UI刷新 |
| `battle_ended` | 单场战斗结束时 | 胜利或失败 |
| `lianli_ended` | 历练完全结束时 | 失败或主动退出 |
| `lianli_waiting` | 连续历练等待期间 | 每帧更新 |
| `lianli_reward` | 获得奖励时 | 物品掉落 |

---

## 11. 关键函数索引

### 11.1 公共接口

| 函数名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `start_lianli_in_area` | `area_id: String` | `bool` | 开始历练（进入区域）|
| `start_next_battle` | 无 | `bool` | 开始下一场战斗 |
| `start_battle` | `enemy_data_dict: Dictionary` | `bool` | 开始一场战斗 |
| `start_endless_tower` | 无 | `bool` | 开始无尽塔挑战 |
| `end_lianli` | 无 | `void` | 结束历练（完全退出）|
| `set_lianli_speed` | `speed: float` | `void` | 设置历练倍速（1.0-2.0）|
| `set_continuous_lianli` | `enabled: bool` | `void` | 设置连续历练模式 |
| `get_current_tower_floor` | 无 | `int` | 获取当前无尽塔层数 |
| `is_in_endless_tower` | 无 | `bool` | 检查是否在无尽塔中 |
| `get_current_enemy_drops` | 无 | `Dictionary` | 获取当前敌人掉落配置 |
| `start_wait_for_next_battle` | 无 | `bool` | 开始等待下一场战斗 |
| `exit_tower` | 无 | `void` | 退出无尽塔 |

### 11.2 内部函数

| 函数名 | 说明 |
|--------|------|
| `_process_atb_tick` | 处理单次ATB tick，增长ATB并判定行动 |
| `_execute_player_action` | 执行玩家行动（普通攻击或术法）|
| `_execute_enemy_action` | 执行敌人行动（普通攻击）|
| `_trigger_start_spells` | 触发开局被动术法 |
| `_handle_battle_victory` | 处理战斗胜利及奖励发放 |
| `_handle_battle_defeat` | 处理战斗失败 |
| `_handle_tower_victory` | 处理无尽塔战斗胜利 |
| `_restore_health_after_combat` | 战斗后恢复气血buff |
| `_start_tower_battle` | 开始无尽塔的一场战斗 |
| `_reset_combat_buffs` | 重置战斗buff |

---

## 12. 注意事项

1. **状态判断**：使用 `is_in_lianli` 判断是否显示战斗场景，而非 `is_in_battle || is_waiting`
2. **信号区分**：`battle_ended` 表示单场战斗结束，`lianli_ended` 表示整个历练结束
3. **胜利后状态**：战斗胜利（非连续）后 `is_in_lianli = false`，但不发 `lianli_ended`
4. **失败后状态**：战斗失败后 `is_in_lianli = false`，并发 `lianli_ended`
5. **手动继续**：点击"继续战斗"时检查气血/次数，然后设置 `is_in_lianli = true`
6. **ATB溢出处理**：行动后ATB减去ATB_MAX（100），保留溢出部分
7. **保底伤害**：所有伤害计算最终都经过 `max(1, ...)` 处理
8. **气血buff同步**：气血加成同时影响当前气血和气血上限
9. **倍速影响**：历练倍速影响双方ATB增长速度
10. **无尽塔上限**：无尽塔最高51层，达到后自动结束挑战
11. **特殊区域**：破境草洞穴有每日次数限制，通关后消耗次数
12. **JSON数值类型**：JSON解析后所有数字为 `float`，显示时需转换为 `int`

---

## 13. 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 1.0 | 2026-02-21 | 初始文档 |
| 1.1 | 2026-02-21 | 区分历练与战斗概念、更新命名规范、ATB机制优化 |
| 1.2 | 2026-02-23 | 重构连续战斗机制、添加无尽塔系统、添加特殊区域说明 |
| 1.3 | 2026-03-01 | 重构状态管理：统一 `end_lianli()` 清理逻辑 |
| 2.0 | 2026-03-03 | **重大重构**：状态机模型重构、文件结构重组、JSON配置分离、区域默认连续状态、信号逻辑优化 |
