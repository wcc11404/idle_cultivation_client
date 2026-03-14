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
scripts/core/spell/
├── SpellSystem.gd    # 术法系统核心逻辑
├── SpellData.gd      # 术法数据管理（从JSON加载）
└── spells.json       # 术法配置数据
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
var MAX_BREATHING_SPELLS = 1   # 吐纳心法最大装备数
var MAX_ACTIVE_SPELLS = 2      # 主动术法最大装备数
var MAX_PASSIVE_SPELLS = 2     # 被动术法最大装备数
# 杂学术法：无限制（-1）
```

---

## 3. 数据结构

### 3.1 术法配置数据 (spells.json)

**重要说明**：`levels` 中的 key 表示**当前等级**，value 表示**从当前等级升级到下一级的条件**。

```json
{
    "equipment_limits": {
        "MAX_BREATHING_SPELLS": 1,
        "MAX_ACTIVE_SPELLS": 2,
        "MAX_PASSIVE_SPELLS": 2
    },
    "spells": {
        "basic_boxing_techniques": {
            "id": "basic_boxing_techniques",
            "name": "基础拳法",
            "type": 1,
            "description": "战斗中{trigger_chance}概率释放，造成{damage_percent}攻击力的伤害",
            "max_level": 3,
            "levels": {
                "1": {
                    "spirit_cost": 50,
                    "use_count_required": 50,
                    "attribute_bonus": {"attack": 1.02},
                    "effect": {
                        "type": "active_damage",
                        "damage_percent": 1.10,
                        "trigger_chance": 0.30
                    }
                },
                "2": {
                    "spirit_cost": 200,
                    "use_count_required": 200,
                    "attribute_bonus": {"attack": 1.04},
                    "effect": {
                        "type": "active_damage",
                        "damage_percent": 1.15,
                        "trigger_chance": 0.30
                    }
                },
                "3": {
                    "spirit_cost": 500,
                    "use_count_required": 500,
                    "attribute_bonus": {"attack": 1.06},
                    "effect": {
                        "type": "active_damage",
                        "damage_percent": 1.20,
                        "trigger_chance": 0.30
                    }
                }
            }
        }
    }
}
```

### 3.2 升级条件查询规则

| 当前等级 | 查询的 key | 获取的内容 |
|---------|-----------|-----------|
| 1级 | "1" | 1级→2级的升级条件 |
| 2级 | "2" | 2级→3级的升级条件 |
| 3级（满级） | - | 无需查询，已满级 |

**代码示例**：
```gdscript
# 获取当前等级的升级条件
var level_data = spell_data.get_spell_level_data(spell_id, current_level)
var spirit_cost = level_data.get("spirit_cost", 0)
var use_count_required = level_data.get("use_count_required", 0)
```

### 3.3 玩家术法数据 (player_spells)
```gdscript
# SpellSystem.gd
var player_spells: Dictionary = {}  # 键: spell_id, 值: 玩家术法数据

# 单条玩家术法数据结构
{
    "obtained": false,          # 是否已获得
    "level": 0,                 # 当前等级（0=未获得）
    "use_count": 0,             # 当前等级使用次数
    "charged_spirit": 0         # 已充灵气（用于升级）
}
```

### 3.4 装备槽位数据 (equipped_spells)
```gdscript
var equipped_spells: Dictionary = {
    SpellType.BREATHING: [],     # 已装备吐纳心法列表（最多1个）
    SpellType.ACTIVE: [],        # 已装备主动术法列表（最多2个）
    SpellType.PASSIVE: [],       # 已装备被动术法列表（最多2个）
    SpellType.MISC: []           # 已装备杂学术法列表（无限制）
}
```

---

## 4. 命名规范

### 4.1 数值命名规范

| 后缀 | 含义 | 存储格式 | 显示格式 | 示例 |
|------|------|----------|----------|------|
| `_chance` | 触发概率 | 小数 (0.25) | `int(value*100)%` | 25% |
| `_percent` | 百分比加成/倍率 | 小数 (0.15 或 1.10) | `int(value*100)%` | 15% 或 110% |
| `_value` | 固定数值（整数或小数） | 整数/小数 | 原样显示（去除末尾0） | 5 或 1.5 |
| `_amount` | 数量 | 整数 | 原样显示 | 10 |
| `_cost` | 消耗 | 整数 | 原样显示 | 100 |
| `_required` | 需求值 | 整数 | 原样显示 | 100 |
| `_bonus` | 加成值 | 整数/小数 | 原样显示 | 0.05 |

### 4.2 描述占位符规范

```gdscript
# 描述中使用占位符，UI层根据命名规范自动格式化
"description": "战斗中{trigger_chance}概率释放，造成{damage_percent}攻击力的伤害"
"description": "战斗开始时，防御提升{buff_percent}"
"description": "战斗开始时，速度+{buff_value}"
"description": "修炼时每秒恢复{heal_percent}最大气血"
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
发送 spell_equipped 信号
```

### 5.3 术法升级流程
```
使用术法 → add_spell_use_count(spell_id)
    ↓
使用次数 + 1（如果未达到上限）
    ↓
玩家充灵气 → charge_spell_spirit(spell_id, amount)
    ↓
检查是否达到升级条件：
    - use_count >= use_count_required（查询当前等级配置）
    - charged_spirit >= spirit_cost（查询当前等级配置）
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

### 6.1 升级条件查询

**关键点**：查询**当前等级**的配置数据，获取升级到下一级的条件。

```gdscript
# SpellSystem.gd - upgrade_spell()
var level_data = spell_data.get_spell_level_data(spell_id, spell_info.level)
var spirit_cost = level_data.get("spirit_cost", 0)
var use_count_required = level_data.get("use_count_required", 0)

# 检查使用次数
if spell_info.use_count < use_count_required:
    return {"success": false, "reason": "使用次数不足"}

# 检查已充灵气
if spell_info.charged_spirit < spirit_cost:
    return {"success": false, "reason": "术法灵气不足"}
```

### 6.2 充灵气逻辑

```gdscript
# SpellSystem.gd - charge_spell_spirit()
var level_data = spell_data.get_spell_level_data(spell_id, spell_info.level)
var spirit_cost = level_data.get("spirit_cost", 0)

var current_charged = spell_info.charged_spirit
var need = spirit_cost - current_charged

if need <= 0:
    return {"success": false, "reason": "灵气已充足"}
```

### 6.3 使用次数上限

```gdscript
# SpellSystem.gd - add_spell_use_count()
var level_data = spell_data.get_spell_level_data(spell_id, spell_info.level)
var use_count_required = level_data.get("use_count_required", 0)

# 如果已达到当前等级需求的使用次数，不再增加
if spell_info.use_count >= use_count_required:
    return
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
# 获取装备的吐纳术法效果（支持多个吐纳术法效果叠加）
func get_equipped_breathing_heal_effect() -> Dictionary:
    var breathing_spells = equipped_spells.get(SpellType.BREATHING, [])
    if breathing_spells.is_empty():
        return {"heal_amount": 0.0, "spell_ids": []}
    
    var total_heal_percent = 0.0
    var valid_spell_ids = []
    
    for spell_id in breathing_spells:
        var level_data = spell_data.get_spell_level_data(spell_id, player_spells[spell_id].level)
        var effect = level_data.get("effect", {})
        
        if effect.get("type") == "passive_heal":
            total_heal_percent += effect.get("heal_percent", 0.0)
            valid_spell_ids.append(spell_id)
    
    return {
        "heal_amount": total_heal_percent,
        "spell_ids": valid_spell_ids
    }
```

---

## 8. 当前术法列表

### 8.1 吐纳心法 (BREATHING)

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
| basic_steps | 基础步法 | speed | +0.1 | +0.2 | +0.3 |
| basic_health | 基础气血 | health | +0.5% | +1.0% | +1.5% |

### 8.4 杂学术法 (MISC) - 2个

| 术法ID | 名称 | 效果类型 | 等级1 | 等级2 | 等级3 |
|--------|------|----------|-------|-------|-------|
| herb_gathering | 灵草采集 | gathering | 效率1.1x,稀有5% | 效率1.2x,稀有8% | 效率1.3x,稀有12% |
| alchemy | 炼丹术 | alchemy | 成功值+10,速度+10% | 成功值+20,速度+20% | 成功值+30,速度+30% |

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

### 9.2 SpellData 接口

| 函数名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `get_spell_data` | `spell_id: String` | `Dictionary` | 获取术法基础数据 |
| `get_spell_name` | `spell_id: String` | `String` | 获取术法名称 |
| `get_spell_type` | `spell_id: String` | `int` | 获取术法类型 |
| `get_spell_type_name` | `spell_type: int` | `String` | 获取术法类型名称 |
| `get_spell_level_data` | `spell_id, level` | `Dictionary` | 获取指定等级数据 |
| `get_all_spell_ids` | 无 | `Array` | 获取所有术法ID |
| `get_spell_ids_by_type` | `spell_type: int` | `Array` | 按类型获取术法ID |
| `get_equipment_limit` | `spell_type: int` | `int` | 获取装备槽位上限 |

---

## 10. 注意事项

1. **升级条件查询**：使用**当前等级**查询升级条件，不是下一等级
2. **数值存储格式**：所有百分比、概率值都用小数存储（0.25表示25%），显示时再转换
3. **JSON数字类型**：Godot的JSON解析会将所有数字转为浮点数，SpellData在加载时会自动转换整数字段
4. **属性加成类型**：
   - 攻击/防御/气血/灵气获取：乘法（1.02表示+2%）
   - 速度：加法（0.05表示+0.05）
5. **装备上限提示**：当装备达到上限时，提示用户先卸下已有术法
6. **杂学术法特殊性**：杂学术法无装备限制，不参与战斗触发

---

## 11. 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 1.0 | 2026-02-21 | 初始文档 |
| 1.1 | 2026-02-21 | 添加命名规范、更新术法数据结构 |
| 1.2 | 2026-02-24 | 更新术法数值（基础气血、基础步法数值调整）|
| 2.0 | 2026-03-03 | 重构：数据移至JSON配置、更新文件结构、明确升级条件查询规则 |
| 2.1 | 2026-03-03 | 新增吐纳心法装备上限配置（MAX_BREATHING_SPELLS），支持多吐纳术法效果叠加 |
| 2.2 | 2026-03-14 | 更新文件路径和目录结构 |