# Godot 4.6 开发流程指南

本文档记录项目开发的核心流程、规范和测试方法，确保开发过程标准化、可验证。

---

## 一、开发流程

### 1.1 设计阶段

#### 概念设计
- 确定核心玩法（修仙挂机）
- 定义世界观（境界划分、升级规则）
- 明确目标用户（挂机游戏爱好者）

#### 需求文档
- 功能列表：玩家属性、境界系统、修炼系统、战斗系统
- 数据结构：玩家数据格式、境界数据格式
- 验收标准：功能完成度、BUG修复率

#### 原型设计
- 纸面原型：UI布局、界面跳转流程
- 玩法原型：Godot快速实现核心玩法demo

### 1.2 开发阶段

#### 架构设计
- 模块划分：PlayerData、RealmSystem、CultivationSystem
- 接口设计：模块间交互协议
- 数据结构：玩家数据、境界数据、战斗数据

#### 代码开发
- 核心系统实现：PlayerData.gd、RealmSystem.gd、CultivationSystem.gd
- UI实现：MainUI.gd、BagUI.gd、SkillUI.gd
- 资源整合：临时占位符资源

#### 测试迭代
- 单元测试：单个函数/类测试
- 集成测试：模块间交互测试
- 用户测试：内部玩家试玩反馈

---

## 二、代码规范

### 2.1 继承选择
- 需要2D渲染 → `extends Node2D`
- 需要3D渲染 → `extends Node3D`
- 仅逻辑处理 → `extends Node`（推荐）

### 2.2 数组操作
- 头部删除 → `array.remove_at(0)`
- 尾部删除 → `array.pop_back()`
- 头部添加 → `array.push_front(value)`
- 尾部添加 → `array.push_back(value)`

### 2.3 类定义
- 不要对autoload使用`class_name`
- 如需跨脚本访问，使用autoload或`load()`

### 2.4 Node属性访问
```gdscript
# 正确方式（直接访问）
var attack = player.attack
player.health = 100

# 错误方式（对Node使用get）
var attack = player.get("attack", 100)  # 这是Dictionary的方法！
```

### 2.5 存档系统规范
所有需要持久化数据的系统必须实现以下两个方法：

```gdscript
# 获取存档数据
func get_save_data() -> Dictionary:
	return {
		"key1": value1,
		"key2": value2
	}

# 应用存档数据
func apply_save_data(data: Dictionary):
	if data.has("key1"):
		key1 = data["key1"]
	if data.has("key2"):
		key2 = data["key2"]
```

需要存档的系统包括：
- PlayerData
- OfflineReward
- Inventory

### 2.6 信号命名规范
使用过去式动词短语命名信号：
- 完成事件：xxx_completed（save_completed, load_completed）
- 更新事件：xxx_updated（task_updated, item_updated）
- 状态变化：xxx_changed（realm_changed, level_changed）
- 开始/停止：xxx_started, xxx_stopped（cultivation_started）

### 2.7 系统初始化规范
在 GameManager 中初始化系统的标准模式：

```gdscript
func init_systems():
	system_name = load("res://scripts/core/SystemName.gd").new()
	system_name.name = "SystemName"
	add_child(system_name)
```

为所有系统提供统一的访问器方法：
```gdscript
func get_system_name():
	return system_name
```

---

## 三、测试规范

### 3.1 测试框架

项目使用 **GUT (Godot Unit Testing)** 框架进行测试，这是Godot官方推荐的测试框架。

### 3.2 测试目录结构
```
tests/
├── gut.config.json              # GUT配置文件
├── test_helper.gd              # 测试辅助基类
├── unit/                        # 单元测试目录
│   ├── test_item_data.gd       # ItemData 模块测试
│   ├── test_inventory.gd       # Inventory 模块测试
│   ├── test_player_data.gd     # PlayerData 模块测试
│   ├── test_realm_system.gd    # RealmSystem 模块测试
│   ├── test_cultivation_system.gd  # CultivationSystem 模块测试
│   ├── test_offline_reward.gd  # OfflineReward 模块测试
│   └── test_save_manager.gd    # SaveManager 模块测试
└── integration/                 # 集成测试目录
    └── test_all_systems.gd     # GameManager 集成环境下的全系统测试
```

### 3.3 测试框架使用原则

#### 原则1：按系统组织测试
- 每个核心系统有独立的测试文件
- 单元测试和集成测试明确分离
- 避免重复测试用例

#### 原则2：使用GUT框架
- 所有测试继承自 `GutTest`
- 使用GUT提供的断言方法
- 遵循GUT的测试命名规范

#### 原则3：测试方法命名规范
- 测试函数以 `test_` 开头
- 清晰描述测试场景
- 避免与变量名冲突

### 3.4 测试阶段要求

#### 新功能开发流程
1. **功能实现**：完成新功能的代码编写
2. **测试用例编写**：
   - 在 `tests/unit/` 下创建对应系统的测试文件
   - 如需要集成测试，在 `tests/integration/` 下添加
3. **测试执行**：使用GUT运行测试验证功能正确性
4. **动静态检查**：执行静态检查和动态检查
5. **测试完善**：修复测试中发现的问题，确保测试覆盖所有场景

### 3.5 测试执行流程

#### 3.5.1 使用GUT运行测试

**通过Godot编辑器运行**：
1. 安装GUT插件（通过AssetLib）
2. 打开GUT面板（Project > Tools > GUT）
3. 选择测试目录和配置
4. 点击"Run Tests"按钮

**通过命令行运行**：
```bash
# 运行所有测试
../../Godot_v4.6-stable_linux.x86_64 --headless --path . --script addons/gut/gut_cmdln.gd -gdir=res://tests_gut -gexit

# 运行特定目录的测试
../../Godot_v4.6-stable_linux.x86_64 --headless --path . --script addons/gut/gut_cmdln.gd -gdir=res://tests_gut/integration -gexit

# 运行单个测试文件
../../Godot_v4.6-stable_linux.x86_64 --headless --path . --script addons/gut/gut_cmdln.gd -gtest=res://tests_gut/integration/test_cultivation_integration.gd -gexit
```

#### 3.5.2 编写新测试用例

**单元测试模板**（`tests/unit/test_yourmodule.gd`）：

```gdscript
# 新系统测试文件示例
extends GutTest

var your_module: Node = null

func before_all():
	# 初始化测试对象
	your_module = load("res://scripts/core/YourModule.gd").new()

func test_initialization():
	a.assert_not_null(your_module, "模块初始化")

func test_functionality():
	# 测试核心功能
	var result = your_module.some_function()
	a.assert_eq(result, expected_value, "功能测试")

func test_edge_cases():
	# 测试边界情况
	a.assert_eq(your_module.handle_edge_case(), expected_result, "边界情况测试")

func test_error_handling():
	# 测试错误处理
	a.assert_eq(your_module.handle_error(), expected_error_result, "错误处理测试")
```

### 3.6 测试覆盖率要求

**单元测试覆盖率**：
- 核心功能：100%
- 边界情况：至少80%
- 错误处理：至少90%

**集成测试覆盖率**：
- 系统间交互：至少90%
- 完整游戏流程：100%

### 3.7 测试结果分析

**测试通过标准**：
- 所有测试用例通过
- 无语法错误
- 无运行时错误
- 功能符合预期

**测试失败处理**：
1. 分析失败原因
2. 修复代码或测试用例
3. 重新运行测试
4. 记录修复过程

**测试报告**：
- GUT会自动生成测试报告
- 查看控制台输出的测试结果
- 确保所有测试通过
- 检查测试覆盖率
- 记录测试结果

---

## 四、常用命令

### 4.1 测试命令

#### 4.1.1 自动化测试命令

使用项目根目录下的 `run_test.sh` 脚本可以一键执行所有测试：

```bash
# 执行完整测试流程（推荐）
bash run_test.sh
```

#### 4.1.2 手动测试命令

**静态检查**：
```bash
# 使用Godot静态检查
"/Applications/Godot.app/Contents/MacOS/godot" --check-only --path . --quit-after 100
```

**动态检查**：
```bash
# 使用Godot headless模式测试
"/Applications/Godot.app/Contents/MacOS/godot" --headless --path . --quit-after 100
```

**运行所有测试**：
```bash
# 运行完整测试套件
"/Applications/Godot.app/Contents/MacOS/godot" --headless --path . --scene res://tests/TestRunner.tscn --quit-after 100
```

**运行指定场景**：
```bash
# 运行主场景
"/Applications/Godot.app/Contents/MacOS/godot" --path . --scene res://scenes/main/Main.tscn --quit-after 100

# 运行测试场景
"/Applications/Godot.app/Contents/MacOS/godot" --path . --scene res://tests/TestRunner.tscn --quit-after 100
```

#### 4.1.3 开发辅助命令

**打开Godot编辑器**：
```bash
# 打开Godot编辑器
open -a Godot

# 打开指定项目
open -a Godot --args --path "/Users/hsams/Documents/trae_projects/idle_cultivation"
```

**查看Godot版本**：
```bash
"/Applications/Godot.app/Contents/MacOS/godot" --version
```

**查看命令行帮助**：
```bash
"/Applications/Godot.app/Contents/MacOS/godot" --help
```

### 4.2 调试技巧
- 在代码中添加 `print("debug: ", variable)`
- 使用 Godot 的Debugger面板查看变量值
- 使用断点调试功能

---

## 五、文档记录

### 5.1 架构文档
- 记录模块划分和接口设计
- 描述数据结构和交互协议

### 5.2 开发指南
- 记录开发流程和规范
- 描述测试方法和验收标准

### 5.3 数值设计
- 记录境界数据和升级规则
- 描述战斗数值和平衡调整

---

## 六、核心系统说明

### 6.1 核心系统列表
- **PlayerData**: 玩家数据管理
- **AccountSystem**: 账号系统
- **RealmSystem**: 境界系统
- **CultivationSystem**: 修炼系统
- **LianliSystem**: 历练系统（包含战斗功能）
- **Inventory**: 储纳系统
- **ItemData**: 物品数据
- **SpellSystem**: 术法系统
- **SpellData**: 术法数据
- **AlchemySystem**: 炼丹系统
- **AlchemyRecipeData**: 丹方数据
- **LianliAreaData**: 历练区域数据
- **EnemyData**: 敌人数据
- **EndlessTowerData**: 无尽塔数据
- **OfflineReward**: 离线收益
- **SaveManager**: 存档管理
- **GameManager**: 游戏管理器（autoload）
- **LogManager**: 日志管理

---

**文档版本**：3.0
**创建日期**：2026-02-16
**更新日期**：2026-03-14
**适用范围**：Godot 4.6 + GDScript开发
