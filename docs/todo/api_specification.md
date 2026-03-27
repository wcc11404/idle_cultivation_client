# 修仙挂机游戏 - 服务端接口规范文档

**文档版本**: v1.0  
**创建日期**: 2026-03-25  
**适用范围**: 关键操作验证功能优化

---

## 1. 通用规范

### 1.1 请求头规范

所有需要认证的接口必须在请求头中包含：

```
Authorization: Bearer {jwt_token}
Content-Type: application/json
```

### 1.2 请求参数通用字段

所有操作请求必须包含以下字段：

```json
{
  "operation_id": "uuid-v4-string",  // 客户端生成的唯一操作 ID，用于防重
  "timestamp": 1234567890            // 客户端操作触发时间戳（秒）
}
```

### 1.3 响应格式规范

#### 成功响应（HTTP 200）
```json
{
  "success": true,
  "data": { ... },
  "message": "操作成功"
}
```

#### 失败响应（HTTP 400/401/500）
```json
{
  "success": false,
  "error_code": "INVALID_TOKEN",
  "message": "错误描述信息"
}
```

### 1.4 错误码定义

| 错误码 | HTTP 状态码 | 说明 |
|--------|-----------|------|
| SUCCESS | 200 | 成功 |
| INVALID_TOKEN | 401 | Token 无效或过期 |
| DUPLICATE_OPERATION | 400 | 重复操作（operation_id 已存在） |
| INSUFFICIENT_RESOURCES | 400 | 资源不足 |
| INVALID_OPERATION | 400 | 操作不合法 |
| DATA_VALIDATION_FAILED | 400 | 数据校验失败 |
| NETWORK_ERROR | 0 | 客户端网络错误（非服务端返回） |

### 1.5 日志格式规范

所有接口必须记录单行日志：

**入日志**:
```
[IN] POST /api/game/cultivation/validate - account_id: xxx - operation_id: yyy - data: {请求参数}
```

**出日志**:
```
[OUT] POST /api/game/cultivation/validate - account_id: xxx - operation_id: yyy - data: {返回参数} - 耗时：0.123s
```

---

## 2. 认证接口（已有，保持不变）

### 2.1 注册账号
- **接口**: `POST /api/auth/register`
- **描述**: 注册新账号

**请求参数**:
```json
{
  "username": "string (必填，20 字符以内)",
  "password": "string (必填)"
}
```

**响应**:
```json
{
  "success": true,
  "account_id": "uuid",
  "message": "注册成功"
}
```

### 2.2 登录账号
- **接口**: `POST /api/auth/login`
- **描述**: 登录并获取 JWT Token

**请求参数**:
```json
{
  "username": "string",
  "password": "string"
}
```

**响应**:
```json
{
  "success": true,
  "token": "jwt_token",
  "expires_in": 604800,
  "account_info": {
    "id": "uuid",
    "username": "testuser",
    "server_id": "default"
  },
  "data": {
    "account_info": { ... },
    "player": { ... },
    "inventory": { ... },
    "spell_system": { ... },
    "alchemy_system": { ... },
    "lianli_system": { ... }
  }
}
```

### 2.3 Token 续期
- **接口**: `POST /api/auth/refresh`
- **描述**: 刷新 JWT Token

**请求头**: `Authorization: Bearer {token}`

**响应**:
```json
{
  "success": true,
  "token": "new_jwt_token",
  "expires_in": 604800
}
```

### 2.4 登出
- **接口**: `POST /api/auth/logout`
- **描述**: 登出账号

**请求头**: `Authorization: Bearer {token}`

**响应**:
```json
{
  "success": true,
  "message": "登出成功"
}
```

---

## 3. 游戏数据接口（已有，优化）

### 3.1 加载游戏数据
- **接口**: `POST /api/game/data` 
- **描述**: 加载玩家游戏数据

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
}
```

**成功响应**:
```json
{
  "success": true,
  "data": {
    "account_info": { ... },
    "player": { ... },
    "inventory": { ... },
    "spell_system": { ... },
    "alchemy_system": { ... },
  }
}
```

只应该有认证失败一种情况，对应401状态码

### 3.2 保存游戏数据
- **接口**: `POST /api/game/save`
- **描述**: 保存游戏数据（字段级别更新）

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "data": {
    "account_info": { ... },  // 可选
    "player": { ... },        // 可选
    "inventory": { ... },     // 可选
    "spell_system": { ... },  // 可选
    "alchemy_system": { ... },// 可选
  }
}
```

**成功响应**:
```json
{
  "success": true,
}
```
只应该有认证失败一种情况，对应401状态码

---

## 4. 离线收益接口（优化）

### 4.1 领取离线收益
- **接口**: `POST /api/game/offline_reward`
- **描述**: 领取离线收益（服务端自动计算离线时间）

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890
}
```

**成功响应且有奖励**:
```json
{
  "success": true,
  "data": {
    "offline_reward": {
      "spirit_energy": 47.0,  // 灵气奖励（浮点数，保留 2 位小数）
      "spirit_stones": 1      // 灵石奖励（整数）
    },
    "offline_seconds": 474,   // 离线时长（秒）
    "player": {               // 更新后的玩家数据
      "realm": "筑基期",
      "realm_level": 5,
      "spirit_energy": 1047.0,
      "max_spirit_energy": 1000
    },
    "inventory": {            // 更新后的全量背包数据
      "slots": {
          ...
          "1": {
              "count": 101,
              "id": "spirit_stones"
          },
          ...
      }
    }
  },
}
```

**成功但无奖励**：(状态码是200)
```json
{
  "success": false,
  "offline_reward": null,
  "offline_seconds": 30,
}
```

---

## 5. 修炼接口（新增）

### 5.1 修炼校验
- **接口**: `POST /api/cultivation/validate`
- **描述**: 校验修炼效果并更新数据

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "spirit_energy_delta": 5.0,        // 灵气增量（浮点数）
  "breathing_mastery_delta": 10,     // 吐纳术法熟练度增量（整数）
  "health_delta": 50.0,              // 气血增量（浮点数）
  "duration_seconds": 5,             // 修炼时长（秒）
}
```

**服务端校验逻辑**:
1. idle_cultivation_client/scripts/core/AttributeCalculator.gd参考实现服务器端版本，计算实际灵气获取速度，气血恢复速度
2. 计算预估灵气增量 = 实际灵气获取速度 × 修炼时长
3. 校验实际增量 <= 1.1 × 预估增量
4. 计算预估气血增量 = 实际气血恢复速度 × 修炼时长
5. 校验实际增量 <= 1.1 × 预估增量
6. 更新玩家数据：灵气、熟练度、气血

**响应**:
```json
{
  "success": true,
  "data": {
    "is_valid": true,              // 校验是否通过
  },
}
```

**错误响应**:(状态码是400)
```json
{
  "success": false,
  "error_code": "DATA_VALIDATION_FAILED",
}
```

---

### 5.2 突破境界
- **接口**: `POST /api/cultivation/breakthrough`
- **描述**: 突破境界校验并更新数据

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
}
```

**服务端校验逻辑**:
1. 检查灵石是否足够
2. 检查材料是否足够（大境界突破需要材料）
3. 检查灵气是否足够
4. 扣除消耗品
5. 更新境界和属性

**成功响应**:
```json
{
  "success": true,
  "data": {
    "player": { ... },
    "inventory": { ... },
  },
}
```

**失败响应**:(状态码是400)
```json
{
  "success": false,
  "error_code": "INSUFFICIENT_RESOURCES",
  "data": {
    "missing": {
      "spirit_stone": 10,  // 缺少 10 个灵石
      "spirit_energy": 30  // 缺少 30 点灵气
    }
  },
  "message": "资源不足，无法突破"
}
```

---

## 7. 储纳接口（新增）

### 7.1 使用物品
- **接口**: `POST /api/game/inventory/use_item`
- **描述**: 使用物品并计算效果

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "item_id": "health_pill",
  "count": 1,
  "current_inventory": {
    "spirit_stone": 100,
    "health_pill": 5
  }
}
```

**服务端校验逻辑**:
1. 检查物品数量是否足够
2. 检查物品是否有 effect 字段（可使用）
3. 计算物品效果
4. 更新玩家数据（气血、灵气等）
5. 扣除物品

**响应**:
```json
{
  "success": true,
  "data": {
    "effect": {
      "type": "add_health",
      "amount": 50
    },
    "updated_player": {
      "health": 150,
      "max_health": 100
    },
    "updated_inventory": {
      "health_pill": 4
    }
  },
  "message": "物品使用成功"
}
```

### 7.2 打开物品
- **接口**: `POST /api/game/inventory/open_item`
- **描述**: 打开可开启的物品（如礼包）

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "item_id": "starter_pack",
  "count": 1,
  "current_inventory": {
    "starter_pack": 1
  }
}
```

**服务端校验逻辑**:
1. 检查物品数量是否足够
2. 检查物品是否有 content 字段（可打开）
3. 发放内容物
4. 扣除物品

**响应**:
```json
{
  "success": true,
  "data": {
    "contents": {
      "spirit_stone": 100,
      "health_pill": 5
    },
    "updated_inventory": {
      "starter_pack": 0,
      "spirit_stone": 200,
      "health_pill": 5
    }
  },
  "message": "打开成功"
}
```

### 7.3 丢弃物品
- **接口**: `POST /api/game/inventory/drop_item`
- **描述**: 丢弃物品

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "item_id": "mat_iron",
  "count": 10,
  "current_inventory": {
    "mat_iron": 50
  }
}
```

**服务端校验逻辑**:
1. 检查物品数量是否足够
2. 扣除物品

**响应**:
```json
{
  "success": true,
  "data": {
    "updated_inventory": {
      "mat_iron": 40
    }
  },
  "message": "丢弃成功"
}
```

### 7.4 整理背包
- **接口**: `POST /api/game/inventory/sort`
- **描述**: 整理背包（按物品 ID 排序）

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "current_inventory": {
    "slots": [
      {"id": "health_pill", "count": 5},
      {"id": "spirit_stone", "count": 100},
      {"empty": true},
      {"id": "health_pill", "count": 3}
    ]
  }
}
```

**服务端校验逻辑**:
1. 合并相同物品的堆叠
2. 按物品 ID 排序
3. 移除空格子

**响应**:
```json
{
  "success": true,
  "data": {
    "sorted_inventory": {
      "slots": [
        {"empty": true},
        {"id": "health_pill", "count": 8},
        {"id": "spirit_stone", "count": 100}
      ]
    }
  },
  "message": "整理成功"
}
```

### 7.5 背包扩容
- **接口**: `POST /api/game/inventory/expand`
- **描述**: 扩展背包容量上限

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "current_max_slots": 100
}
```

**服务端校验逻辑**:
1. 检查当前容量是否小于最大值（200）
2. 增加容量（每次 +10 格）
3. 更新配置

**响应**:
```json
{
  "success": true,
  "data": {
    "new_max_slots": 110,
    "updated_inventory": {
      "max_slots": 110,
      "slots": [ ... ]
    }
  },
  "message": "扩容成功"
}
```

---

## 8. 历练接口（新增）

### 8.1 普通历练胜利
- **接口**: `POST /api/game/lianli/victory`
- **描述**: 普通区域历练胜利结算

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "area_id": "qi_refining_outer",
  "enemy_id": "wolf_lv5",
  "enemy_level": 5,
  "is_elite": false,
  "duration_seconds": 30,
  "speed_multiplier": 1.0,
  "health_delta": -100.0,        // 气血变化（负数表示受伤）
  "mastery_deltas": {            // 熟练度变化
    "basic_breathing": 5,
    "basic_boxing": 10
  },
  "current_health": 400.0,       // 当前气血（校验用）
  "current_mastery": {           // 当前熟练度（校验用）
    "basic_breathing": 100,
    "basic_boxing": 50
  }
}
```

**服务端校验逻辑**:
1. 校验气血变化合理性
2. 校验熟练度增长合理性
3. 计算掉落奖励（随机数）
4. 更新玩家数据
5. 发放掉落物品

**响应**:
```json
{
  "success": true,
  "data": {
    "loot": [
      {"item_id": "spirit_stone", "amount": 20},
      {"item_id": "mat_herb", "amount": 2}
    ],
    "updated_player": {
      "health": 400.0,
      "max_health": 500
    },
    "updated_spells": {
      "basic_breathing": {
        "mastery": 105,
        "level": 2
      },
      "basic_boxing": {
        "mastery": 60,
        "level": 1
      }
    },
    "updated_inventory": {
      "spirit_stone": 120,
      "mat_herb": 5
    }
  },
  "message": "战斗胜利"
}
```

### 8.2 无尽塔胜利
- **接口**: `POST /api/game/tower/victory`
- **描述**: 无尽塔挑战胜利结算

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "tower_floor": 10,
  "duration_seconds": 60,
  "speed_multiplier": 1.0,
  "health_delta": -200.0,
  "mastery_deltas": {
    "basic_breathing": 10
  },
  "current_health": 300.0,
  "current_mastery": {
    "basic_breathing": 100
  },
  "is_new_highest": true
}
```

**服务端校验逻辑**:
1. 校验楼层合法性
2. 校验气血和熟练度变化
3. 判断是否发放楼层奖励
4. 更新最高层记录
5. 更新玩家数据

**响应**:
```json
{
  "success": true,
  "data": {
    "new_highest_floor": 10,
    "floor_reward": {
      "spirit_stone": 50,
      "mat_iron": 5
    },
    "updated_player": {
      "health": 300.0
    },
    "updated_spells": {
      "basic_breathing": {
        "mastery": 110,
        "level": 2
      }
    },
    "updated_inventory": {
      "spirit_stone": 150,
      "mat_iron": 10
    }
  },
  "message": "塔层挑战成功"
}
```

### 8.3 每日副本通关
- **接口**: `POST /api/game/dungeon/complete`
- **描述**: 每日副本通关结算（替代原有的 finish 接口）

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "dungeon_id": "foundation_herb_cave",
  "duration_seconds": 120,
  "speed_multiplier": 1.0,
  "health_delta": -150.0,
  "mastery_deltas": {
    "basic_breathing": 15
  },
  "current_health": 350.0,
  "current_mastery": {
    "basic_breathing": 100
  }
}
```

**服务端校验逻辑**:
1. 检查副本次数是否足够
2. 校验气血和熟练度变化
3. 扣减副本次数
4. 发放副本奖励
5. 更新玩家数据

**响应**:
```json
{
  "success": true,
  "data": {
    "remaining_count": 2,
    "dungeon_reward": {
      "foundation_herb": 3,
      "spirit_stone": 30
    },
    "updated_player": {
      "health": 350.0
    },
    "updated_spells": {
      "basic_breathing": {
        "mastery": 115,
        "level": 2
      }
    },
    "updated_inventory": {
      "foundation_herb": 3,
      "spirit_stone": 130
    }
  },
  "message": "副本通关成功"
}
```

### 8.4 历练失败
- **接口**: `POST /api/game/lianli/defeat`
- **描述**: 历练战斗失败结算

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "area_id": "qi_refining_outer",
  "enemy_id": "wolf_lv5",
  "duration_seconds": 20,
  "speed_multiplier": 1.0,
  "health_delta": -500.0,        // 气血归零
  "mastery_deltas": {
    "basic_breathing": 2
  },
  "final_health": 0
}
```

**服务端校验逻辑**:
1. 校验气血变化合理性
2. 更新熟练度（失败也有少量熟练度）
3. 更新玩家气血（至少保留 1 点）

**响应**:
```json
{
  "success": true,
  "data": {
    "updated_player": {
      "health": 1.0,
      "max_health": 500
    },
    "updated_spells": {
      "basic_breathing": {
        "mastery": 102,
        "level": 2
      }
    }
  },
  "message": "战斗失败，已退出历练"
}
```

---

## 9. 术法接口（新增）

### 9.1 装备术法
- **接口**: `POST /api/game/spell/equip`
- **描述**: 装备术法

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "spell_id": "basic_breathing",
  "spell_count": 1,
  "slot_type": "breathing",      // 槽位类型：breathing/active/passive
  "slot_index": 0,               // 槽位索引：0-2
  "current_spells": {
    "player_spells": {
      "basic_breathing": 1
    },
    "equipped_spells": {
      "breathing": [],
      "active": [],
      "passive": []
    }
  },
  "is_in_battle": false          // 是否在战斗中
}
```

**服务端校验逻辑**:
1. 检查是否拥有该术法
2. 检查槽位类型是否匹配
3. 检查槽位数量限制（每个槽位最多 3 个）
4. 检查是否在战斗中（战斗中不能装备）
5. 更新装备状态

**响应**:
```json
{
  "success": true,
  "data": {
    "updated_spell_system": {
      "player_spells": {
        "basic_breathing": 1
      },
      "equipped_spells": {
        "breathing": ["basic_breathing"],
        "active": [],
        "passive": []
      }
    },
    "attribute_bonuses": {
      "attack": 1.0,
      "defense": 1.0,
      "health": 1.0,
      "spirit_gain": 1.1,
      "speed": 0.0
    }
  },
  "message": "装备成功"
}
```

### 9.2 卸下术法
- **接口**: `POST /api/game/spell/unequip`
- **描述**: 卸下术法

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "spell_id": "basic_breathing",
  "slot_type": "breathing",
  "slot_index": 0,
  "current_spells": {
    "player_spells": {
      "basic_breathing": 1
    },
    "equipped_spells": {
      "breathing": ["basic_breathing"],
      "active": [],
      "passive": []
    }
  },
  "is_in_battle": false
}
```

**服务端校验逻辑**:
1. 检查术法是否已装备
2. 检查是否在战斗中（战斗中不能卸下）
3. 更新装备状态

**响应**:
```json
{
  "success": true,
  "data": {
    "updated_spell_system": {
      "player_spells": {
        "basic_breathing": 1
      },
      "equipped_spells": {
        "breathing": [],
        "active": [],
        "passive": []
      }
    },
    "attribute_bonuses": {
      "attack": 1.0,
      "defense": 1.0,
      "health": 1.0,
      "spirit_gain": 1.0,
      "speed": 0.0
    }
  },
  "message": "卸下成功"
}
```

### 9.3 术法充能
- **接口**: `POST /api/game/spell/recharge`
- **描述**: 为术法充能

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "spell_id": "fire_ball",
  "recharge_count": 1,
  "current_inventory": {
    "spirit_stone": 100
  },
  "current_spells": {
    "player_spells": {
      "fire_ball": 1
    },
    "spell_energy": {
      "fire_ball": 0
    }
  }
}
```

**服务端校验逻辑**:
1. 检查是否拥有该术法
2. 检查灵石是否足够（每次充能消耗灵石）
3. 增加术法能量
4. 扣除灵石

**响应**:
```json
{
  "success": true,
  "data": {
    "updated_spell_energy": {
      "fire_ball": 1
    },
    "updated_inventory": {
      "spirit_stone": 90
    },
    "cost": {
      "spirit_stone": 10
    }
  },
  "message": "充能成功"
}
```

### 9.4 术法升级
- **接口**: `POST /api/game/spell/upgrade`
- **描述**: 升级术法

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "spell_id": "basic_breathing",
  "current_mastery": 100,
  "required_mastery": 100,
  "current_inventory": {
    "spirit_stone": 100
  },
  "current_spells": {
    "player_spells": {
      "basic_breathing": 1
    },
    "spell_levels": {
      "basic_breathing": 1
    }
  },
  "is_in_battle": false
}
```

**服务端校验逻辑**:
1. 检查是否拥有该术法
2. 检查熟练度是否足够
3. 检查灵石是否足够
4. 检查是否在战斗中（战斗中不能升级）
5. 升级术法
6. 扣除消耗品

**响应**:
```json
{
  "success": true,
  "data": {
    "new_level": 2,
    "updated_spells": {
      "basic_breathing": {
        "level": 2,
        "mastery": 0,
        "next_upgrade_mastery": 200
      }
    },
    "updated_inventory": {
      "spirit_stone": 50
    },
    "cost": {
      "spirit_stone": 50
    },
    "attribute_bonuses": {
      "attack": 1.0,
      "defense": 1.0,
      "health": 1.0,
      "spirit_gain": 1.2,  // 升级后加成提升
      "speed": 0.0
    }
  },
  "message": "升级成功"
}
```

---

## 10. 炼丹接口（新增）

### 10.1 炼丹校验
- **接口**: `POST /api/game/alchemy/craft`
- **描述**: 炼丹并校验结果

**请求头**: `Authorization: Bearer {token}`

**请求参数**:
```json
{
  "operation_id": "uuid",
  "timestamp": 1234567890,
  "recipe_id": "health_pill_recipe",
  "craft_count": 1,
  "duration_seconds": 10,
  "current_inventory": {
    "mat_herb": 10,
    "spirit_stone": 100
  },
  "current_alchemy_system": {
    "known_recipes": ["health_pill_recipe"],
    "mastery": {
      "health_pill_recipe": 50
    }
  }
}
```

**服务端校验逻辑**:
1. 检查是否知晓丹方
2. 检查材料是否足够
3. 检查耗时是否在合理区间（配置表获取）
4. 计算成功率（基于熟练度）
5. 随机判断是否成功
6. 扣除材料
7. 增加产物和熟练度

**响应**:
```json
{
  "success": true,
  "data": {
    "is_success": true,
    "product": {
      "health_pill": 1
    },
    "consumed": {
      "mat_herb": 5,
      "spirit_stone": 10
    },
    "mastery_gain": 5,
    "updated_inventory": {
      "mat_herb": 5,
      "spirit_stone": 90,
      "health_pill": 6
    },
    "updated_alchemy": {
      "mastery": {
        "health_pill_recipe": 55
      }
    }
  },
  "message": "炼丹成功"
}
```

**失败情况**:
```json
{
  "success": true,
  "data": {
    "is_success": false,
    "consumed": {
      "mat_herb": 5,
      "spirit_stone": 10
    },
    "mastery_gain": 2,
    "updated_inventory": {
      "mat_herb": 5,
      "spirit_stone": 90
    },
    "updated_alchemy": {
      "mastery": {
        "health_pill_recipe": 52
      }
    }
  },
  "message": "炼丹失败，材料已消耗"
}
```

---

## 11. 排行榜接口（已有，保持不变）

### 11.1 获取排行榜
- **接口**: `GET /api/game/rank`
- **描述**: 获取服务器排行榜

**请求参数**:
```
server_id=default
```

**响应**:
```json
{
  "success": true,
  "data": {
    "ranks": [
      {
        "nickname": "修仙者 123456",
        "realm": "筑基期",
        "level": 5,
        "spirit_energy": 1000.5,
        "title_id": "top_1",
        "rank": 1
      }
    ]
  }
}
```

---

## 12. 副本接口（已有，优化）

### 12.1 获取副本信息
- **接口**: `GET /api/game/dungeon/info`
- **描述**: 获取玩家副本信息

**请求头**: `Authorization: Bearer {token}`

**响应**:
```json
{
  "success": true,
  "data": {
    "dungeon_data": {
      "foundation_herb_cave": {
        "max_count": 3,
        "remaining_count": 3
      }
    }
  }
}
```

---

## 13. 数据格式说明

### 13.1 player 数据结构
```json
{
  "realm": "筑基期",
  "realm_level": 5,
  "health": 350.0,
  "max_health": 500,
  "spirit_energy": 800.0,
  "max_spirit_energy": 1000,
  "base_max_health": 500,
  "base_max_spirit": 1000,
  "base_attack": 30,
  "base_defense": 13,
  "base_speed": 5.0,
  "base_spirit_gain": 1.0
}
```

### 13.2 inventory 数据结构
```json
{
  "slots": {
    "spirit_stone": 100,
    "health_pill": 5,
    "mat_herb": 10
  },
  "max_slots": 100
}
```

### 13.3 spell_system 数据结构
```json
{
  "player_spells": {
    "basic_breathing": 1,
    "fire_ball": 1
  },
  "equipped_spells": {
    "breathing": ["basic_breathing"],
    "active": ["fire_ball"],
    "passive": []
  },
  "spell_energy": {
    "fire_ball": 3
  },
  "spell_levels": {
    "basic_breathing": 2,
    "fire_ball": 1
  },
  "spell_mastery": {
    "basic_breathing": 150,
    "fire_ball": 80
  }
}
```

### 13.4 alchemy_system 数据结构
```json
{
  "known_recipes": ["health_pill_recipe", "spirit_pill_recipe"],
  "mastery": {
    "health_pill_recipe": 50,
    "spirit_pill_recipe": 30
  }
}
```

### 13.5 lianli_system 数据结构
```json
{
  "tower_highest_floor": 10,
  "daily_dungeon_data": {
    "foundation_herb_cave": {
      "max_count": 3,
      "remaining_count": 2
    }
  }
}
```

---

## 14. 配置文件说明

### 14.1 需要软链接到服务端的配置文件

以下配置文件需要从客户端软链接到服务端：

```
idle_cultivation_server/config/ -> ../idle_cultivation_client/scripts/core/
├── items.json          # 物品配置
├── realms.json         # 境界配置
├── spells.json         # 术法配置
├── recipes.json        # 丹方配置
├── areas.json          # 历练区域配置
├── enemies.json        # 敌人配置
└── tower.json          # 无尽塔配置
```

### 14.2 服务端新增配置项

在配置文件中新增以下配置项：

**items.json** - 物品配置新增字段：
```json
{
  "health_pill": {
    "effect": {
      "type": "add_health",
      "amount": 50
    }
  },
  "starter_pack": {
    "content": {
      "spirit_stone": 100,
      "health_pill": 5
    }
  }
}
```

**spells.json** - 术法配置新增字段：
```json
{
  "basic_breathing": {
    "type": "breathing",
    "max_level": 10,
    "mastery_per_level": 100,
    "upgrade_cost": {
      "spirit_stone": 50
    },
    "recharge_cost": {
      "spirit_stone": 10
    },
    "attribute_bonus": {
      "spirit_gain": 0.1
    }
  }
}
```

**recipes.json** - 丹方配置新增字段：
```json
{
  "health_pill_recipe": {
    "product": "health_pill",
    "product_count": 1,
    "materials": {
      "mat_herb": 5,
      "spirit_stone": 10
    },
    "base_duration": 10,
    "base_success_rate": 0.8,
    "mastery_per_craft": 5
  }
}
```

---

## 15. 实现建议

### 15.1 服务端文件拆分建议

将 `game.py` 按功能拆分为以下文件：

```
app/api/
├── game.py              # 保留 load_game 和 save_game
├── cultivation.py       # 修炼相关（validate）
├── breakthrough.py      # 突破相关
├── inventory.py         # 储纳相关（use/open/drop/sort/expand）
├── lianli.py           # 历练相关（victory/defeat）
├── tower.py            # 无尽塔相关（victory）
├── dungeon.py          # 每日副本相关（complete）
├── spell.py            # 术法相关（equip/unequip/recharge/upgrade）
└── alchemy.py          # 炼丹相关（craft）
```

### 15.2 防重复操作实现

使用 Redis 或内存缓存存储 operation_id：

```python
# 伪代码
async def check_duplicate_operation(account_id: str, operation_id: str):
    key = f"operation:{account_id}:{operation_id}"
    if await redis.exists(key):
        raise HTTPException(status_code=400, detail="DUPLICATE_OPERATION")
    await redis.setex(key, 60, "1")  # 60 秒过期
```

### 15.3 数据校验原则

1. **客户端预校验**: 客户端先进行基础校验（资源是否足够）
2. **服务端最终校验**: 服务端进行最终校验，不信任客户端数据
3. **增量更新**: 服务端接收增量值，计算最终值并存储
4. **回滚机制**: 校验失败时返回错误，客户端回滚本地更改

---

**文档版本**: v1.0  
**最后更新**: 2026-03-25
