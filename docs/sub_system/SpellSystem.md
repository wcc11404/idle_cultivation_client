# 术法系统文档 (SpellSystem)

## 1. 系统概述

术法系统是游戏中的核心技能系统，负责管理玩家拥有的所有术法，包括术法的获取、装备、升级、使用等全生命周期管理。

### 1.1 核心设计理念
- **分类管理**：术法分为四大类型（吐纳心法、主动术法、被动术法、杂学术法），各有不同的使用场景和装备规则
- **装备限制**：主动术法和被动术法有装备数量上限（各2个），增加策略性
- **概率触发**：主动攻击术法采用概率触发机制，多个技能按概率分配
- **成长系统**：术法可通过使用次数升级，升级后效果增强
- **数据驱动**：术法配置集中管理，便于扩展和平衡调整

---

## 2. 系统架构

### 2.1 文件结构
```
/Users/hsams/Documents/trae_projects/idle_cultivation/scripts/core/
├── SpellSystem.gd    # 术法系统核心逻辑
├── SpellData.gd      # 术法数据配置
└── ItemData.gd       # 物品数据（包含术法解锁道具）
```

### 2.2 术法类型枚举
```gdscript
# SpellData.gd
enum SpellType {
    BREATHING,   # 吐纳心法 - 修炼时持续生效（只能装备1个）
    ACTIVE,      # 主动术法 - 战斗中概率触发攻击（最多2个）
    PASSIVE,     # 被动术法 - 战斗开始时自动触发（最多2个）
    MISC         # 杂学术法 - 非战斗技能（如采集，无限制）
}
```

### 2.3 装备槽位限制
```gdscript
# SpellData.gd
const MAX_ACTIVE_SPELLS = 2    # 主动术法最大装备数
const MAX_PASSIVE_SPELLS = 2   # 被动术法最大装备数
# 吐纳心法：1个，杂学术法：无限制
```

---

## 3. 命名规范

### 3.1 数值命名规范

| 后缀 | 含义 | 存储格式 | 显示格式 | 示例 |
|------|------|----------|----------|------|
| `_chance` | 触发概率 | 小数 (0.25) | `int(value*100)%` | 25% |
| `_percent` | 百分比加成/倍率 | 小数 (0.15 或 1.10) | `int(value*100)%` | 15% 或 110% |
| `_value` | 固定数值（整数或小数） | 整数/小数 | 原样显示（去除末尾0） | 5 或 1.5 |
| `_amount` | 数量 | 整数 | 原样显示 | 10 |
| `_cost` | 消耗 | 整数 | 原样显示 | 100 |
| `_required` | 需求值 | 整数 | 原样显示 | 100 |
| `_bonus` | 加成值 | 整数/小数 | 原样显示 | 0.05 |

### 3.2 配置字段命名规范

```gdscript
# 术法等级数据结构
{
    "spirit_cost": 100,           # 灵气消耗（整数）
    "use_count_required": 100,    # 需要的使用次数（整数）
    "attribute_bonus": {          # 属性加成
        "attack": 1.02,           # 攻击加成（乘法，小数）
        "defense": 1.02,          # 防御加成（乘法，小数）
        "health": 1.02,           # 气血加成（乘法，小数）
        "spirit_gain": 1.02,      # 灵气获取加成（乘法，小数）
        "speed": 0.05             # 速度加成（加法，小数）
    },
    "effect": {                   # 战斗效果
        "type": "active_damage",  # 效果类型
        "damage_percent": 1.10,   # 伤害倍率（110%）
        "trigger_chance": 0.30,   # 触发概率（30%）
        "buff_type": "defense",   # buff类型
        "buff_percent": 0.15,     # buff百分比（15%）
        "buff_value": 1.0,        # buff固定值
        "heal_percent": 0.002     # 恢复百分比（0.2%）
    }
}
```

### 3.3 描述占位符规范

```gdscript
# 描述中使用占位符，UI层根据命名规范自动格式化
"description": "战斗中{trigger_chance}概率释放，造成{damage_percent}攻击力的伤害"
"description": "战斗开始时，防御提升{buff_percent}"
"description": "战斗开始时，速度+{buff_value}"
"description": "修炼时每秒恢复{heal_percent}最大气血"
```

**格式化规则**：
- `{xxx_chance}` → `AttributeCalculator.format_percent()` → "30%"
- `{xxx_percent}` → `AttributeCalculator.format_percent()` → "15%" 或 "110%"
- `{xxx_value}` → `AttributeCalculator.format_default()` → "1" 或 "1.5"

> **注意**：术法系统的数值显示统一使用 `AttributeCalculator` 的格式化函数。详见 [属性数值系统规范](../ATTRIBUTE_SYSTEM.md) 第2.4节。

---

## 4. 数据结构

### 4.1 术法基础数据 (SpellData.SPELLS)
```gdscript
const SPELLS = {
    "basic_boxing_techniques": {
        "id": "basic_boxing_techniques",
        "name": "基础拳法",
        "type": SpellType.ACTIVE,
        "description": "战斗中{trigger_chance}概率释放，造成{damage_percent}攻击力的伤害",
        "max_level": 3,
        "levels": {
            1: {
                "spirit_cost": 150,           # 升级所需灵气
                "use_count_required": 100,    # 升级所需使用次数
                "attribute_bonus": {"attack": 1.02},  # 属性加成（乘法）
                "effect": {
                    "type": "active_damage",
                    "damage_percent": 1.10,   # 110%伤害倍率
                    "trigger_chance": 0.30    # 30%触发概率
                }
            }
            # ... 其他等级
        }
    }
}
```

### 4.2 玩家术法数据 (player_spells)
```gdscript
# SpellSystem.gd
var player_spells: Dictionary = {}  # 键: spell_id, 值: 玩家术法数据

# 单条玩家术法数据结构
{
    "obtained": false,          # 是否已获得
    "level": 0,                 # 当前等级（0=未获得）
    "use_count": 0,             # 当前等级使用次数
    "equipped": false,          # 是否已装备
    "charged_spirit": 0         # 已充灵气（用于升级）
}
```

### 4.3 装备槽位数据 (equipped_spells)
```gdscript
var equipped_spells: Dictionary = {
    SpellType.BREATHING: [],     # 已装备吐纳心法列表（最多1个）
    SpellType.ACTIVE: [],        # 已装备主动术法列表（最多2个）
    SpellType.PASSIVE: [],       # 已装备被动术法列表（最多2个）
    SpellType.MISC: []           # 已装备杂学术法列表（无限制）
}
```

---

## 5. 主体逻辑

### 5.1 术法获取流程
```
获得术法解锁道具
    ↓
使用道具 → obtain_spell(spell_id)
    ↓
在player_spells中标记obtained=true，level=1
    ↓
发送 spell_obtained 信号
    ↓
UI更新显示
```

### 5.2 术法装备流程
```
玩家点击装备
    ↓
equip_spell(spell_id)
    ↓
检查是否已解锁（obtained=true）
    ↓
检查是否已装备
    ↓
检查类型装备上限（get_equipment_limit）
    ├── 超限 → 返回错误提示
    └── 未超限 → 继续
    ↓
添加到装备槽位
    ↓
更新 equipped 标记
    ↓
发送 spell_equipped 信号
```

### 5.3 术法升级流程
```
使用术法 → add_spell_use_count(spell_id)
    ↓
使用次数 + 1（如果未达到上限）
    ↓
检查是否达到升级条件：
    - use_count >= use_count_required
    - charged_spirit >= spirit_cost
    - level < max_level
    ↓
满足条件 → upgrade_spell(spell_id)
    ↓
扣除灵气，等级 + 1，使用次数清零
    ↓
发送 spell_upgraded 信号
```

---

## 6. 核心功能详解

### 6.1 术法装备管理

#### 6.1.1 装备术法 (equip_spell)
```gdscript
func equip_spell(spell_id: String) -> Dictionary
```
**返回值**：
```gdscript
{
    "success": bool,           # 是否成功
    "reason": String           # 失败原因（如果失败）
}
```

**装备限制检查**：
```gdscript
var spell_type = spell_data.get_spell_type(spell_id)
var limit = spell_data.get_equipment_limit(spell_type)  # -1表示无限制

if limit >= 0 and equipped_spells[spell_type].size() >= limit:
    return {"success": false, "reason": "装备数量达到上限"}
```

#### 6.1.2 卸下术法 (unequip_spell)
```gdscript
func unequip_spell(spell_id: String) -> bool
```

### 6.2 攻击术法触发机制

#### 6.2.1 触发逻辑 (trigger_attack_spell)
```gdscript
func trigger_attack_spell() -> Dictionary
```

**触发流程**：
```
获取所有已装备的主动术法
    ↓
计算总触发概率（所有trigger_chance之和）
    ↓
生成随机数 roll = randf() (0.0 - 1.0)
    ↓
判定是否触发术法：
    - 普攻概率 = max(0, 1 - total_chance)
    - 如果 roll < 普攻概率 → 返回普攻
    ↓
按比例选择具体术法：
    - 归一化概率 = chance / total_chance
    - 按累积概率选择
    ↓
增加使用次数
    ↓
返回触发结果
```

**返回值结构**：
```gdscript
{
    "triggered": true,              # 是否触发术法
    "spell_id": "thunder_strike",   # 触发的术法ID
    "spell_name": "雷击术",         # 术法名称
    "effect": {...},                # 完整效果数据
    "is_normal_attack": false       # 是否为普通攻击
}
```

### 6.3 被动术法效果获取

#### 6.3.1 获取装备效果 (get_equipped_spell_effects_by_type)
```gdscript
func get_equipped_spell_effects_by_type(spell_type: int) -> Array
```

**返回值示例**（被动术法）：
```gdscript
[
    {
        "type": "start_buff",
        "buff_type": "defense",
        "buff_percent": 0.15,         # 15%防御加成
        "trigger_chance": 1.0,        # 100%触发
        "spell_id": "basic_defense",
        "spell_name": "基础防御"
    }
]
```

### 6.4 术法升级系统

#### 6.4.1 升级条件检查
```gdscript
# 1. 检查等级上限
if spell_info.level >= max_level:
    return {"success": false, "reason": "已达到最高等级"}

# 2. 检查使用次数
if spell_info.use_count < use_count_required:
    return {"success": false, "reason": "使用次数不足"}

# 3. 检查已充灵气
if spell_info.charged_spirit < spirit_cost:
    return {"success": false, "reason": "术法灵气不足"}
```

#### 6.4.2 属性加成计算

术法属性加成作用于**静态最终属性**计算，详见 [属性数值系统规范](../ATTRIBUTE_SYSTEM.md) 第1.2节。

**加成类型**：
- **攻击/防御/气血/灵气获取**：乘法加成（如 1.02 表示 +2%）
- **速度**：加法加成（如 0.1 表示 +0.1）

```gdscript
# 获取所有已获取术法的属性加成
func get_attribute_bonuses() -> Dictionary:
    var bonuses = {
        "attack": 1.0,      # 乘法
        "defense": 1.0,     # 乘法
        "health": 1.0,      # 乘法
        "spirit_gain": 1.0, # 乘法
        "speed": 0.0        # 加法
    }
    
    # 遍历所有已获取术法，累加属性加成
    for spell_id in player_spells.keys():
        if spell_info.obtained and spell_info.level > 0:
            var attribute_bonus = level_data.get("attribute_bonus", {})
            for attr in attribute_bonus.keys():
                if attr == "speed":
                    bonuses.speed += attribute_bonus[attr]  # 加法
                else:
                    bonuses[attr] *= attribute_bonus[attr]  # 乘法
    
    return bonuses
```

**静态最终属性计算**（AttributeCalculator）：
```gdscript
# 示例：最终攻击 = 基础攻击 × 术法攻击加成
static func calculate_final_attack(player: Node) -> float:
    var base_attack = player.base_attack
    var spell_bonuses = _get_spell_bonuses(player)
    return base_attack * spell_bonuses.get("attack", 1.0)
```

---

## 7. 与其他系统的联动

### 7.1 与历练系统的联动

#### 7.1.1 战斗开始时触发被动
```gdscript
# LianliSystem.gd
func _trigger_start_spells():
    var passive_effects = spell_system.get_equipped_spell_effects_by_type(SpellType.PASSIVE)
    for effect_data in passive_effects:
        var buff_type = effect_data.get("buff_type", "")
        match buff_type:
            "defense":
                var buff_percent = effect_data.get("buff_percent", 0.0)
                combat_buffs.defense_percent += buff_percent
            "speed":
                var buff_value = effect_data.get("buff_value", 0.0)
                combat_buffs.speed_bonus += buff_value
            "health":
                var health_percent = effect_data.get("buff_percent", 0.0)
                # 计算气血加成...
```

#### 7.1.2 玩家攻击时触发主动术法
```gdscript
# LianliSystem.gd
func _execute_player_action():
    var attack_result = GameManager.spell_system.trigger_attack_spell()
    if attack_result.triggered:
        # 使用术法伤害
        var damage_percent = attack_result.effect.get("damage_percent", 1.0)
        damage = calculate_damage(player_attack * damage_percent, enemy_defense)
    else:
        # 普通攻击
        damage = calculate_damage(player_attack, enemy_defense)
```

### 7.2 与修炼系统的联动

#### 7.2.1 吐纳心法效果
```gdscript
# 获取装备的吐纳术法效果
func get_equipped_breathing_heal_effect() -> Dictionary:
    var breathing_spells = equipped_spells.get(SpellType.BREATHING, [])
    if breathing_spells.is_empty():
        return {"heal_amount": 0}
    
    var spell_id = breathing_spells[0]
    var level_data = spell_data.get_spell_level_data(spell_id, player_spells[spell_id].level)
    var effect = level_data.get("effect", {})
    
    return {
        "heal_amount": effect.get("heal_percent", 0.0),  # 每秒恢复百分比
        "spell_name": spell_data.get_spell_name(spell_id)
    }
```

---

## 8. 当前术法列表

### 8.1 吐纳心法 (BREATHING) - 1个

| 术法ID | 名称 | 效果 | 等级1 | 等级2 | 等级3 |
|--------|------|------|-------|-------|-------|
| basic_breathing | 基础吐纳 | 每秒恢复{heal_percent}气血 | 0.2% | 0.4% | 0.6% |

### 8.2 主动术法 (ACTIVE) - 2个

| 术法ID | 名称 | 触发概率 | 伤害倍率 | 等级1 | 等级2 | 等级3 |
|--------|------|----------|----------|-------|-------|-------|
| basic_boxing_techniques | 基础拳法 | 30% | 110%/115%/120% | 110% | 115% | 120% |
| thunder_strike | 雷击术 | 25% | 130%/135%/140% | 130% | 135% | 140% |

### 8.3 被动术法 (PASSIVE) - 3个

| 术法ID | 名称 | Buff类型 | 等级1 | 等级2 | 等级3 |
|--------|------|----------|-------|-------|-------|
| basic_defense | 基础防御 | defense | +15% | +16% | +17% |
| basic_steps | 基础步法 | speed | +0.5 | +0.6 | +0.7 |
| basic_health | 基础气血 | health | +0.5% | +1.0% | +1.5% |

**注意**：基础气血和基础步法的效果已调整为更合理的数值
- 基础气血：从15%/16%/17%调整为0.5%/1.0%/1.5%
- 基础步法：从+1.0/+1.1/+1.2调整为+0.5/+0.6/+0.7

### 8.4 杂学术法 (MISC) - 1个

| 术法ID | 名称 | 效果类型 | 等级1 | 等级2 | 等级3 |
|--------|------|----------|-------|-------|-------|
| herb_gathering | 灵草采集 | gathering | 效率1.1x,稀有5% | 效率1.2x,稀有8% | 效率1.3x,稀有12% |

---

## 9. 关键函数索引

### 9.1 公共接口

| 函数名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `obtain_spell` | `spell_id: String` | `bool` | 获取术法 |
| `equip_spell` | `spell_id: String` | `Dictionary` | 装备术法 |
| `unequip_spell` | `spell_id: String` | `bool` | 卸下术法 |
| `upgrade_spell` | `spell_id: String` | `Dictionary` | 升级术法 |
| `charge_spell_spirit` | `spell_id, amount` | `Dictionary` | 给术法充灵气 |
| `add_spell_use_count` | `spell_id: String` | `void` | 增加使用次数 |
| `trigger_attack_spell` | 无 | `Dictionary` | 触发攻击术法判定 |
| `get_equipped_spell_effects_by_type` | `spell_type: int` | `Array` | 获取指定类型装备效果 |
| `get_equipped_breathing_heal_effect` | 无 | `Dictionary` | 获取吐纳恢复效果 |
| `get_attribute_bonuses` | 无 | `Dictionary` | 获取所有属性加成 |
| `get_spell_info` | `spell_id: String` | `Dictionary` | 获取术法完整信息 |
| `get_all_spells_by_type` | 无 | `Dictionary` | 获取所有术法（按类型分类） |

### 9.2 UI相关函数

| 函数名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `can_upgrade_spell` | `spell_id: String` | `Dictionary` | 检查术法是否可以升级（用于UI提示）|
| `get_spell_config_info` | `spell_id: String` | `Dictionary` | 获取术法配置信息（未获得也可查看）|

**can_upgrade_spell 返回值**：
```gdscript
{
    "can_upgrade": bool,      # 是否可以升级
    "reason": String,         # 不能升级的原因（如果不能）
    "next_level": int         # 下一等级（如果可以升级）
}
```

**get_spell_config_info 返回值**：
```gdscript
{
    "id": "basic_boxing_techniques",
    "name": "基础拳法",
    "type": 1,                    # SpellType.ACTIVE
    "type_name": "主动术法",
    "description": "战斗中{trigger_chance}概率释放...",
    "max_level": 3,
    "levels": {
        1: {
            "spirit_cost": 150,
            "use_count_required": 100,
            "attribute_bonus": {"attack": 1.02},
            "effect": {"type": "active_damage", "damage_percent": 1.10, "trigger_chance": 0.30}
        },
        2: {...},
        3: {...}
    }
}
```

### 9.3 UI提示逻辑

#### 9.3.1 术法升级提示

**使用场景**：在术法详情界面显示升级按钮状态

```gdscript
# 检查是否可以升级
var upgrade_check = spell_system.can_upgrade_spell(spell_id)

if upgrade_check.can_upgrade:
    # 显示"可升级"提示（如绿色按钮、闪烁效果等）
    show_upgrade_button(true, "可升级至等级 " + str(upgrade_check.next_level))
else:
    # 显示不能升级的原因
    show_upgrade_button(false, upgrade_check.reason)
    # 常见原因：
    # - "已达到最高等级"
    # - "使用次数不足（50/100）"
    # - "术法灵气不足（80/150）"
```

#### 9.3.2 未获得术法查看

**使用场景**：在术法图鉴或商店预览中查看未获得的术法

```gdscript
# 获取术法配置信息（不需要拥有该术法）
var config_info = spell_system.get_spell_config_info(spell_id)

# 显示术法信息
show_spell_name(config_info.name)
show_spell_description(config_info.description)
show_spell_type(config_info.type_name)

# 显示各等级属性
for level in config_info.levels.keys():
    var level_data = config_info.levels[level]
    show_level_info(level, level_data.attribute_bonus, level_data.effect)
```

**UI显示建议**：
- 未获得的术法使用灰色图标或半透明效果
- 显示"未获得"标签
- 可以查看所有等级的属性，但不能装备/升级
- 显示获取途径（如"通过新手礼包获得"）

### 9.4 存档相关

| 函数名 | 说明 |
|--------|------|
| `get_save_data` | 获取存档数据（只存储已获得的术法）|
| `apply_save_data` | 加载存档数据 |
| `_convert_old_id` | 转换旧存档ID到新ID |

**存档数据格式**：
```gdscript
{
    "player_spells": {
        "basic_boxing_techniques": {
            "obtained": true,
            "level": 2,
            "use_count": 50,
            "charged_spirit": 80
        }
        # 只存储已获得的术法，未获得的不存储
    },
    "equipped_spells": {
        0: ["basic_breathing"],           # BREATHING
        1: ["basic_boxing_techniques"],   # ACTIVE
        2: ["basic_defense"],             # PASSIVE
        3: []                              # MISC
    }
}
```

---

## 10. 扩展指南

### 10.1 添加新术法

1. **在 SpellData.gd 中添加配置**：
```gdscript
"new_spell": {
    "id": "new_spell",
    "name": "新术法",
    "type": SpellType.ACTIVE,
    "description": "战斗中{trigger_chance}概率释放，造成{damage_percent}攻击力的伤害",
    "max_level": 3,
    "levels": {
        1: {
            "spirit_cost": 150,
            "use_count_required": 100,
            "attribute_bonus": {"attack": 1.02},
            "effect": {
                "type": "active_damage",
                "damage_percent": 1.10,
                "trigger_chance": 0.30
            }
        }
    }
}
```

2. **遵循命名规范**：
   - 概率/百分比用 `_chance` 或 `_percent` 后缀
   - 固定数值用 `_value` 后缀
   - 描述中使用占位符 `{xxx_chance}` 或 `{xxx_percent}`

---

## 11. 注意事项

1. **数值存储格式**：所有百分比、概率值都用小数存储（0.25表示25%），显示时再转换
2. **属性加成类型**：
   - 攻击/防御/气血/灵气获取：乘法（1.02表示+2%）
   - 速度：加法（0.05表示+0.05）
3. **装备上限提示**：当装备达到上限时，提示用户先卸下已有术法
4. **杂学术法特殊性**：杂学术法无装备限制，不参与战斗触发
5. **存档兼容**：使用ID映射表处理旧存档数据迁移

---

## 12. 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 1.0 | 2026-02-21 | 初始文档 |
| 1.1 | 2026-02-21 | 添加命名规范、更新术法数据结构 |
| 1.2 | 2026-02-24 | 更新术法数值（基础气血、基础步法数值调整）|
