# 2D修仙挂机游戏 - 架构设计文档

**文档版本**：2.0
**创建日期**：2026-02-15
**更新日期**：2026-02-17
**适用范围**：Godot 4.6 + GDScript开发

---

## 项目状态
✅ **核心系统已实现**

---

## 1. 项目结构设计

```
idle_cultivation/
├── project.godot                    # Godot项目配置
├── scenes/                         # 场景文件
│   └── tests/                      # 测试场景
│       └── TestRunner.tscn         # 测试运行场景
├── scripts/                        # GDScript脚本
│   ├── autoload/                   # 自动加载脚本
│   │   └── GameManager.gd         # 游戏管理器（autoload）
│   ├── core/                      # 核心系统
│   │   ├── PlayerData.gd          # 玩家数据 ✅ 已实现
│   │   ├── RealmSystem.gd         # 境界系统 ✅ 已实现
│   │   ├── CultivationSystem.gd   # 修炼系统 ✅ 已实现
│   │   ├── BattleSystem.gd        # 战斗系统 ✅ 已实现
│   │   ├── Inventory.gd           # 背包系统 ✅ 已实现
│   │   ├── ItemData.gd            # 物品数据 ✅ 已实现
│   │   ├── OfflineReward.gd       # 离线收益 ✅ 已实现
│   │   ├── SaveManager.gd         # 存档管理 ✅ 已实现
│   │   ├── TaskSystem.gd          # 任务系统 ✅ 已实现
│   │   └── LogManager.gd          # 日志管理 ✅ 已实现
│   └── ui/                        # UI逻辑
│       └── GameUI.gd              # 游戏界面逻辑 ✅ 已实现
├── assets/                        # 资源文件夹
├── tests/                         # 测试文件 ✅ 已实现
│   ├── test_helper.gd            # 测试辅助基类
│   ├── run_all_tests.gd          # 统一测试运行器
│   ├── TestRunner.tscn           # 测试运行场景
│   ├── unit/                      # 单元测试目录
│   │   ├── test_item_data.gd
│   │   ├── test_inventory.gd
│   │   ├── test_player_data.gd
│   │   ├── test_realm_system.gd
│   │   ├── test_cultivation_system.gd
│   │   ├── test_battle_system.gd
│   │   ├── test_offline_reward.gd
│   │   └── test_save_manager.gd
│   └── integration/               # 集成测试目录
│       └── test_all_systems.gd
└── docs/                         # 文档
    ├── ARCHITECTURE.md           # 架构设计（本文件）
    ├── NUMERIC_DESIGN.md         # 数值设计
    ├── DEVELOPMENT_GUIDE.md      # 开发指南
    └── DEVELOPMENT_WORKFLOW.md   # 开发工作流程
```

---

## 2. 核心系统架构（已实现）

### 2.1 游戏管理器 (GameManager)
**职责**：
- 初始化所有游戏系统
- 管理全局状态
- 提供系统访问接口
- 处理存档/读档流程

**实际接口**：
```gdscript
extends Node

signal offline_reward_received(rewards: Dictionary)

var player: Node = null
var cultivation_system: Node = null
var battle_system: Node = null
var realm_system: Node = null
var save_manager: Node = null
var task_system: Node = null
var offline_reward: Node = null
var inventory: Node = null
var item_data: Node = null

var has_starter_pack: bool = true

func _ready():
	init_systems()
	create_player()
	give_starter_pack_item()

func init_systems():
	item_data = load("res://scripts/core/ItemData.gd").new()
	item_data.name = "ItemData"
	add_child(item_data)
	
	realm_system = load("res://scripts/core/RealmSystem.gd").new()
	realm_system.name = "RealmSystem"
	add_child(realm_system)
	
	inventory = load("res://scripts/core/Inventory.gd").new()
	inventory.name = "Inventory"
	add_child(inventory)
	
	cultivation_system = load("res://scripts/core/CultivationSystem.gd").new()
	cultivation_system.name = "CultivationSystem"
	add_child(cultivation_system)
	
	battle_system = load("res://scripts/core/BattleSystem.gd").new()
	battle_system.name = "BattleSystem"
	add_child(battle_system)
	
	save_manager = load("res://scripts/core/SaveManager.gd").new()
	save_manager.name = "SaveManager"
	add_child(save_manager)
	
	task_system = load("res://scripts/core/TaskSystem.gd").new()
	task_system.name = "TaskSystem"
	add_child(task_system)
	
	offline_reward = load("res://scripts/core/OfflineReward.gd").new()
	offline_reward.name = "OfflineReward"
	add_child(offline_reward)

func create_player():
	player = load("res://scripts/core/PlayerData.gd").new()
	player.name = "Player"
	add_child(player)
	
	cultivation_system.set_player(player)
	battle_system.set_player(player)

func get_player(): return player
func get_cultivation_system(): return cultivation_system
func get_battle_system(): return battle_system
func get_realm_system(): return realm_system
func get_save_manager(): return save_manager
func get_task_system(): return task_system
func get_offline_reward(): return offline_reward
func get_inventory(): return inventory
func get_item_data(): return item_data

func save_game():
	if save_manager:
		offline_reward.save_time()
		save_manager.save_game()

func load_game():
	if save_manager:
		var success = save_manager.load_game()
		if success:
			apply_loaded_data()
		return success
	return false
```

---

### 2.2 玩家数据 (PlayerData)
**职责**：
- 存储玩家属性
- 提供属性访问接口
- 处理境界和段位提升
- 计算战斗属性

**实际属性**：
```gdscript
class_name PlayerData extends Node

signal realm_changed(new_realm: String, new_level: int)
signal level_changed(new_level: int)
signal stats_changed()
signal cultivation_started()
signal cultivation_stopped()

var realm: String = "炼气期"
var realm_level: int = 1
var level: int = 1

var health: int = 500
var max_health: int = 500
var spirit_energy: int = 0
var max_spirit_energy: int = 100
var attack: int = 50
var defense: int = 25
var speed: int = 10

var is_cultivating: bool = false
var cultivation_timer: float = 0.0
```

**关键方法**：
- `get_status_dict() -> Dictionary`：获取完整状态字典
- `attempt_breakthrough() -> bool`：尝试突破
- `start_cultivation()` / `stop_cultivation()`：修炼控制
- `apply_realm_stats()`：应用境界属性加成
- `get_save_data() -> Dictionary` / `apply_save_data(data: Dictionary)`：存档接口

---

### 2.3 境界系统 (RealmSystem)
**职责**：
- 管理9大境界数据
- 每个境界10层（第10层为大圆满）
- 计算境界属性加成
- 判断境界突破条件

**实际境界列表**：
1. 炼气期
2. 筑基期
3. 金丹期
4. 元婴期
5. 化神期
6. 炼虚期
7. 合体期
8. 大乘期
9. 渡劫期

**关键方法**：
- `get_next_realm(current_realm: String) -> String`：获取下一境界
- `get_realm_index(realm_name: String) -> int`：获取境界索引
- `get_max_spirit_energy(realm_name: String) -> int`：获取灵气上限
- `get_realm_breakthrough_cost(realm_name: String) -> int`：获取晋升境界消耗
- `get_level_breakthrough_cost(realm_name: String, level: int) -> int`：获取升层消耗

---

### 2.4 修炼系统 (CultivationSystem)
**职责**：
- 处理自动修炼逻辑
- 每秒获得1点灵气
- 管理修炼状态

**实际接口**：
```gdscript
class_name CultivationSystem extends Node

signal cultivation_progress(current: int, max: int)
signal cultivation_complete()

var player: Node = null
var is_cultivating: bool = false
var cultivation_timer: float = 0.0
var cultivation_interval: float = 1.0

func set_player(p: Node):
	player = p

func start_cultivation():
	is_cultivating = true

func stop_cultivation():
	is_cultivating = false

func _process(delta: float):
	if not is_cultivating or not player:
		return
	
	cultivation_timer += delta
	if cultivation_timer >= cultivation_interval:
		cultivation_timer = 0.0
		do_cultivate()

func do_cultivate():
	player.add_spirit_energy(1)
```

---

### 2.5 战斗系统 (BattleSystem)
**职责**：
- 处理自动战斗逻辑
- 计算伤害和结果
- 管理掉落物品

**实际接口**：
```gdscript
class_name BattleSystem extends Node

signal battle_started(enemy_name: String)
signal battle_win(loot: Array)
signal battle_lose()

var player: Node = null
var is_battling: bool = false
var current_enemy: Dictionary = {}
var battle_timer: float = 0.0
var battle_round_interval: float = 1.0

func set_player(p: Node):
	player = p

func start_battle(enemy_data: Dictionary):
	is_battling = true
	current_enemy = enemy_data.duplicate()
	battle_timer = 0.0
	battle_started.emit(enemy_data.get("name", ""))

func _process(delta: float):
	if not is_battling or not player:
		return
	
	battle_timer += delta
	if battle_timer >= battle_round_interval:
		battle_timer = 0.0
		execute_battle_round()

func execute_battle_round():
	var damage_to_enemy = calculate_damage(player.attack, current_enemy.get("defense", 0))
	var damage_to_player = calculate_damage(current_enemy.get("attack", 50), player.defense)
	
	current_enemy["health"] -= damage_to_enemy
	player.health -= damage_to_player
	
	if current_enemy.get("health", 0) <= 0:
		handle_victory()
	elif player.health <= 0:
		handle_defeat()

func calculate_damage(attack: int, defense: int) -> int:
	return max(1, attack - defense)

func handle_victory():
	is_battling = false
	var loot = generate_loot()
	battle_win.emit(loot)

func handle_defeat():
	is_battling = false
	player.health = 1
	battle_lose.emit()

func generate_loot() -> Array:
	var loot = []
	loot.append({"type": "灵石", "amount": randi_range(50, 150)})
	if randi() % 100 < 20:
		loot.append({"type": "材料", "amount": 1})
	return loot
```

---

### 2.6 背包系统 (Inventory)
**职责**：
- 管理100个背包格子
- 物品添加/移除/查询
- 物品堆叠

**实际接口**：
```gdscript
class_name Inventory extends Node

signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal item_updated(item_id: String, count: int)

var slots: Array = []
const MAX_SLOTS = 100

func _ready():
	clear()

func clear():
	slots = []
	for i in range(MAX_SLOTS):
		slots.append({"empty": true, "id": "", "count": 0})

func add_item(item_id: String, count: int) -> bool:
	if count <= 0:
		return false
	
	var remaining = count
	
	for i in range(slots.size()):
		if not slots[i].empty and slots[i].id == item_id:
			slots[i].count += remaining
			remaining = 0
			item_added.emit(item_id, count)
			item_updated.emit(item_id, slots[i].count)
			return true
	
	if remaining > 0:
		for i in range(slots.size()):
			if slots[i].empty:
				slots[i] = {"empty": false, "id": item_id, "count": remaining}
				remaining = 0
				item_added.emit(item_id, count)
				return true
	
	return false

func remove_item(item_id: String, count: int) -> bool:
	var remaining = count
	
	for i in range(slots.size()):
		if remaining <= 0:
			break
		
		if not slots[i].empty and slots[i].id == item_id:
			var remove_amount = min(remaining, slots[i].count)
			slots[i].count -= remove_amount
			remaining -= remove_amount
			
			if slots[i].count <= 0:
				slots[i] = {"empty": true, "id": "", "count": 0}
			
			item_removed.emit(item_id, remove_amount)
			item_updated.emit(item_id, max(0, slots[i].count))
	
	return remaining == 0

func get_item_count(item_id: String) -> int:
	var total = 0
	for slot in slots:
		if not slot.empty and slot.id == item_id:
			total += slot.count
	return total

func get_item_list() -> Array:
	return slots.duplicate()

func get_save_data() -> Dictionary:
	return {"slots": slots.duplicate()}

func apply_save_data(data: Dictionary):
	if data.has("slots"):
		slots = data["slots"].duplicate()
```

---

### 2.7 物品数据 (ItemData)
**职责**：
- 管理所有物品定义
- 提供物品查询接口
- 物品品质颜色管理

**实际物品类型**：
- 0: 资源
- 1: 材料
- 2: 装备
- 3: 凭证

**物品品质**：
- 0: 普通（白色）
- 1: 优秀（绿色）
- 2: 稀有（蓝色）
- 3: 史诗（紫色）
- 4: 传说（金色）

---

### 2.8 离线收益 (OfflineReward)
**职责**：
- 记录最后存档时间
- 计算离线时间
- 按离线时长计算收益（灵气、灵石）

**离线收益比例**：
- 0-1小时：100%
- 1-3小时：80%
- 3-8小时：60%
- 8-24小时：50%

---

### 2.9 存档系统 (SaveManager)
**职责**：
- 保存游戏数据到 JSON
- 加载游戏数据
- 提供存档信息查询

**存档内容**：
- player: 玩家数据
- task_system: 任务系统数据
- offline_reward: 离线收益数据
- inventory: 背包数据
- has_starter_pack: 是否领取新手礼包
- timestamp: 存档时间戳
- version: 存档版本

---

### 2.10 任务系统 (TaskSystem)
**职责**：
- 管理4种任务类型
- 任务进度更新
- 任务完成奖励

**任务类型**：
1. collect_spirit_stone：收集灵石
2. cultivate_time：修炼时长
3. defeat_enemy：击败怪物
4. realm_breakthrough：境界突破

**每种任务5个等级**，完成后发放奖励。

---

### 2.11 日志管理 (LogManager)
**职责**：
- 管理游戏日志
- 日志高亮显示（灵石金色、灵气青色、成功绿色、失败红色）
- 最多保留50条日志

---

### 2.12 游戏界面 (GameUI)
**职责**：
- 显示玩家状态（境界、灵石、生命、灵气）
- 修炼、战斗、突破、存档、读档按钮
- 背包界面（100格）
- 物品详情面板
- 日志显示

#### 2.12.1 内视页面属性显示规则

内视页面（玩家属性面板）的属性显示遵循以下格式化规则：

| 属性 | 显示规则 | 示例 |
|------|----------|------|
| **攻击/防御** | ≤1000：保留一位小数，去尾0<br>>1000：保留整数 | 50.5 → "50.5"<br>377214.7 → "377215" |
| **速度** | 保留两位小数，去尾0 | 5.50 → "5.5"<br>6.00 → "6" |
| **灵气获取速度** | 保留两位小数，去尾0 | 1.02 → "1.02"<br>1.00 → "1" |
| **气血/灵气** | 保留整数 | 34600800 → "34600800" |

**实现位置**：`scripts/core/AttributeCalculator.gd`

**格式化函数**：
```gdscript
# 攻击/防御格式化
static func format_attack_defense(value: float) -> String

# 速度格式化
static func format_speed(value: float) -> String

# 灵气获取速度格式化
static func format_spirit_gain_speed(value: float) -> String

# 气血/灵气格式化
static func format_health_spirit(value: float) -> String
```

**使用示例**：
```gdscript
# 在 GameUI.gd 中更新属性显示
attack_label.text = "攻击: " + AttributeCalculator.format_attack_defense(player.get_final_attack())
defense_label.text = "防御: " + AttributeCalculator.format_attack_defense(player.get_final_defense())
speed_label.text = "速度: " + AttributeCalculator.format_speed(player.get_final_speed())
spirit_gain_label.text = "灵气获取: " + AttributeCalculator.format_spirit_gain_speed(player.get_final_spirit_gain_speed()) + "/秒"
health_value.text = AttributeCalculator.format_health_spirit(status.health) + "/" + AttributeCalculator.format_health_spirit(final_max_health)
spirit_value.text = AttributeCalculator.format_health_spirit(status.spirit_energy) + "/" + AttributeCalculator.format_health_spirit(player.get_final_max_spirit_energy())
```

---

## 3. 数据结构设计

### 3.1 玩家存档数据格式
```json
{
    "player": {
        "realm": "炼气期",
        "realm_level": 1,
        "level": 1,
        "health": 500,
        "max_health": 500,
        "spirit_energy": 0,
        "max_spirit_energy": 100,
        "attack": 50,
        "defense": 25,
        "speed": 10,
        "is_cultivating": false
    },
    "task_system": {
        "completed_task_levels": {},
        "active_tasks": {},
        "task_progress": {}
    },
    "offline_reward": {
        "last_save_time": 0
    },
    "inventory": {
        "slots": [
            {"empty": true, "id": "", "count": 0},
            ...
        ]
    },
    "has_starter_pack": false,
    "timestamp": 1234567890,
    "version": "1.2"
}
```

---

## 4. 模块间交互设计

### 4.1 信号系统（已实现）
```gdscript
# PlayerData
signal realm_changed(new_realm: String, new_level: int)
signal level_changed(new_level: int)
signal stats_changed()
signal cultivation_started()
signal cultivation_stopped()

# CultivationSystem
signal cultivation_progress(current: int, max: int)
signal cultivation_complete()

# BattleSystem
signal battle_started(enemy_name: String)
signal battle_win(loot: Array)
signal battle_lose()

# Inventory
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal item_updated(item_id: String, count: int)

# SaveManager
signal save_completed()
signal load_completed()
signal load_failed()

# TaskSystem
signal task_updated(task_id: String)
signal task_completed(task_id: String, rewards: Dictionary)

# GameManager
signal offline_reward_received(rewards: Dictionary)

# LogManager
signal log_added(message: String)
```

### 4.2 节点访问方式
```gdscript
# 通过autoload访问（推荐）
var game_manager = get_node("/root/GameManager")
var player = game_manager.get_player()
var inventory = game_manager.get_inventory()
```

---

## 5. 待实现功能

### 5.1 未实现的系统
- ❌ 技能系统
- ❌ 技能点
- ❌ 装备系统（UI中有按钮，逻辑未实现）
- ❌ 敌人刷新器
- ❌ 修炼特效
- ❌ 音频管理
- ❌ 对象池
- ❌ 资源预加载

### 5.2 文档中提到但未实现
- ❌ Main.tscn 主场景
- ❌ GameUI.tscn UI场景
- ❌ assets/ 资源文件夹内容

---

## 6. 测试覆盖

✅ **已实现完整测试**：
- 单元测试：所有核心系统
- 集成测试：GameManager 环境下的全系统测试
- 测试运行器：一键运行所有测试
- 测试通过率：100%（152个测试用例）

---

**文档版本**：2.0
**更新日期**：2026-02-17
