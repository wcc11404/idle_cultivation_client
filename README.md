# 修仙挂机游戏 (Cultivation Idle Game)

一款基于 Godot 4 开发的修仙题材挂机游戏。

## 游戏简介

在这个游戏中，你将扮演一名修仙者，通过修炼、历练、炼丹等方式提升修为，突破境界，最终飞升成仙。

### 核心玩法

- **修炼系统**: 自动修炼积累灵气，提升修为
- **境界突破**: 从练气期到大乘期，共9大境界
- **术法系统**: 装备吐纳心法、主动术法、被动术法增强实力
- **历练系统**: 挑战各种妖兽获取资源，采用ATB战斗机制
- **炼丹系统**: 炼制丹药辅助修炼
- **储纳系统**: 管理背包物品
- **账号系统**: 支持多用户存档
- **离线收益**: 离线时自动积累修炼收益

## 程序入口

- **主脚本**: `scripts/autoload/GameManager.gd`
- **项目文件**: `project.godot`

## 文档结构

```
docs/
├── Architecture.md          # 系统架构文档
├── DevelopmentGuide.md     # 开发指南
├── question_solve_plan/     # 问题解决方案
│   ├── GodotHeadlessFix.md
│   └── InventoryFixReport.md
└── sub_system/              # 子系统文档
    ├── AlchemySystem.md     # 炼丹系统
    ├── AttributeSystem.md   # 属性系统
    ├── CultivationSystem.md # 修炼系统
    ├── InventorySystem.md   # 储纳系统
    ├── LianliSystem.md      # 历练系统
    ├── LogSystem.md         # 日志系统
    └── SpellSystem.md       # 术法系统
```

## 项目结构

```
scripts/
├── autoload/           # 自动加载脚本
│   └── GameManager.gd  # 游戏管理器
├── core/               # 核心系统
│   ├── PlayerData.gd   # 玩家数据
│   ├── AccountSystem.gd # 账号系统
│   ├── SaveManager.gd  # 存档管理
│   ├── OfflineReward.gd # 离线收益
│   ├── realm/          # 境界相关系统
│   │   ├── RealmSystem.gd     # 境界系统
│   │   └── CultivationSystem.gd # 修炼系统
│   ├── inventory/      # 背包相关系统
│   │   ├── Inventory.gd       # 储纳系统
│   │   └── ItemData.gd        # 物品数据
│   ├── lianli/         # 历练相关系统
│   │   ├── LianliSystem.gd    # 历练系统
│   │   ├── LianliAreaData.gd  # 历练区域数据
│   │   ├── EnemyData.gd       # 敌人数据
│   │   └── EndlessTowerData.gd # 无尽塔数据
│   ├── spell/          # 术法相关系统
│   │   ├── SpellSystem.gd     # 术法系统
│   │   └── SpellData.gd       # 术法数据
│   └── alchemy/        # 炼丹相关系统
│       ├── AlchemySystem.gd   # 炼丹系统
│       └── AlchemyRecipeData.gd # 丹方数据
├── ui/                 # UI 相关
│   ├── GameUI.gd       # 主UI
│   ├── LogManager.gd   # 日志管理器
│   └── modules/        # UI模块
│       ├── SpellModule.gd      # 术法模块
│       ├── SpellDetailPopup.gd # 术法弹窗
│       ├── ChunaModule.gd      # 储纳模块
│       ├── LianliModule.gd     # 历练模块
│       └── ...
└── utils/              # 工具类
    └── ui_utils.gd

assets/                 # 游戏资源
scenes/                 # 场景文件
└── tests/              # 测试场景

tests/                  # 测试代码
├── test_helper.gd      # 测试辅助基类
├── run_all_tests.gd    # 统一测试运行器
├── TestRunner.tscn     # 测试运行场景
├── unit/               # 单元测试
└── integration/        # 集成测试
```

## 如何运行

1. 安装 [Godot 4.x](https://godotengine.org/)
2. 打开项目：`project.godot`
3. 点击运行按钮或按 F5

## 测试

在 Godot 编辑器中运行测试场景 `tests/TestRunner.tscn`。

## 技术栈

- **引擎**: Godot 4.x
- **语言**: GDScript
- **平台**: PC / macOS / Linux / Android / iOS

## 开发状态

当前版本已实现：
- ✅ 修炼系统（自动修炼、境界突破）
- ✅ 术法系统（装备、升级、使用）
- ✅ 历练系统（战斗、掉落、无尽塔）
- ✅ 储纳系统（背包管理）
- ✅ 炼丹系统（配方、炼制）
- ✅ 存档系统（保存/读取）
- ✅ 账号系统（多用户支持）
- ✅ 离线收益系统

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License
