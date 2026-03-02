extends Node

var helper: Node = null
var test_realm_system: Node = null

func _ready():
	helper = load("res://tests/test_helper.gd").new()
	add_child(helper)

func run_tests():
	print("\n=== RealmSystem 单元测试 ===")
	helper.reset_stats()
	
	test_realm_system = load("res://scripts/core/realm/RealmSystem.gd").new()
	add_child(test_realm_system)
	
	test_initialization()
	test_realm_info()
	test_level_name()
	test_breakthrough()
	test_display_name()
	
	return helper.failed_count == 0

func test_initialization():
	helper.assert_true(test_realm_system != null, "RealmSystem", "模块初始化")

func test_realm_info():
	var realm_info = test_realm_system.get_realm_info("炼气期")
	helper.assert_true(!realm_info.is_empty(), "RealmSystem", "获取境界信息")
	
	var level_info = test_realm_system.get_level_info("炼气期", 1)
	helper.assert_true(!level_info.is_empty(), "RealmSystem", "获取炼气期1段信息")
	
	var health = level_info.get("health", 0)
	helper.assert_eq(health, 50, "RealmSystem", "炼气期1段生命值")
	
	var invalid_info = test_realm_system.get_level_info("不存在的境界", 1)
	helper.assert_true(invalid_info.is_empty(), "RealmSystem", "无效境界返回空字典")

func test_level_name():
	var level_name = test_realm_system.get_level_name("炼气期", 1)
	helper.assert_eq(level_name, "一层", "RealmSystem", "境界名称-一层")
	
	level_name = test_realm_system.get_level_name("炼气期", 10)
	helper.assert_eq(level_name, "大圆满", "RealmSystem", "境界名称-大圆满")

func test_breakthrough():
	var result = test_realm_system.can_breakthrough("炼气期", 1, 100, 100, {})
	helper.assert_true(result.get("can") == true, "RealmSystem", "突破条件-资源足够")
	
	result = test_realm_system.can_breakthrough("炼气期", 1, 100, 0, {})
	helper.assert_true(result.get("can") == false, "RealmSystem", "突破条件-灵气不足")
	
	result = test_realm_system.can_breakthrough("炼气期", 10, 1000000, 1000000, {"foundation_pill": 1})
	helper.assert_eq(result.get("type"), "realm", "RealmSystem", "突破到下一境界")

func test_display_name():
	var display_name = test_realm_system.get_realm_display_name("炼气期", 5)
	helper.assert_eq(display_name, "炼气期 五层", "RealmSystem", "境界显示名称")
