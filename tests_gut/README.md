# GUT 测试框架使用指南

## 安装完成

GUT (Godot Unit Test) 已安装到 `addons/gut` 目录。

## 运行测试

### 方式1：命令行运行
```bash
# 运行所有 GUT 测试
godot --headless --script res://addons/gut/gut_cmdln.gd -gdir=res://tests_gut -ginclude_subdirs -gexit

# 或使用脚本
./tests_gut/run_gut_tests.sh
```

### 方式2：在 Godot 编辑器中运行
1. 打开项目
2. 菜单：Project → Project Settings → Plugins
3. 确保 GUT 插件已启用
4. 菜单：GUT → Run All Tests

## 测试文件结构

```
tests_gut/
├── gut_config.gd          # GUT 配置
├── GutTestRunner.tscn     # 测试运行场景
├── run_gut_tests.sh       # 命令行运行脚本
├── test_lianli_flow.gd    # 历练系统测试
└── test_ui_automation.gd  # UI 自动化测试
```

## GUT 常用断言

```gdscript
# 基本断言
assert_true(condition, "描述")
assert_false(condition, "描述")
assert_eq(actual, expected, "描述")
assert_ne(actual, expected, "描述")
assert_gt(value, compare, "描述")
assert_lt(value, compare, "描述")
assert_near(actual, expected, tolerance, "描述")

# 空值断言
assert_null(value, "描述")
assert_not_null(value, "描述")

# 类型断言
assert_is(value, type, "描述")

# 字符串断言
assert_string_contains(string, substring, "描述")
assert_string_starts_with(string, prefix, "描述")

# 待定测试
pending("待实现的功能")
```

## 生命周期方法

```gdscript
func before_all():
    # 所有测试前执行一次
    pass

func after_all():
    # 所有测试后执行一次
    pass

func before_each():
    # 每个测试前执行
    pass

func after_each():
    # 每个测试后执行
    pass
```

## 参数化测试

```gdscript
func test_player_damage(params = use_parameters([
    [100, 90],   # damage, expected_health
    [50, 50],
    [200, 0]
])):
    var damage = params[0]
    var expected = params[1]
    player.take_damage(damage)
    assert_eq(player.health, expected)
```

## 模拟对象 (Mock)

```gdscript
func test_with_mock():
    var mock_player = double(Player).new()
    stub(mock_player, 'take_damage').to_return(10)
    
    mock_player.take_damage(100)
    
    assert_called(mock_player, 'take_damage', [100])
```

## 参考资料

- [GUT 官方文档](https://github.com/bitwes/Gut/wiki)
- [GUT 断言参考](https://github.com/bitwes/Gut/wiki/Assertions)
- [GUT 命令行参数](https://github.com/bitwes/Gut/wiki/Command-Line)
