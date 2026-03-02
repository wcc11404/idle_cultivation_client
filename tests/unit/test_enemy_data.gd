extends Node

var helper: Node = null
var enemy_data: Node = null

func _ready():
	helper = load("res://tests/test_helper.gd").new()
	add_child(helper)
	
	enemy_data = load("res://scripts/core/lianli/EnemyData.gd").new()
	add_child(enemy_data)

func run_tests():
	print("\n=== EnemyData 单元测试 ===")
	helper.reset_stats()
	
	test_initialization()
	test_generate_enemy()
	test_get_template_name()
	test_is_elite_template()
	test_get_all_template_ids()
	
	return helper.failed_count == 0

func test_initialization():
	helper.assert_true(enemy_data != null, "EnemyData", "模块初始化")

func test_generate_enemy():
	var enemy = enemy_data.generate_enemy("wolf", 5)
	helper.assert_true(not enemy.is_empty(), "EnemyData", "生成野狼数据")
	
	var name = enemy.get("name", "")
	helper.assert_true(not name.is_empty(), "EnemyData", "敌人名称不为空")
	
	var stats = enemy.get("stats", {})
	helper.assert_true(not stats.is_empty(), "EnemyData", "敌人属性不为空")
	
	var health = stats.get("health", 0)
	helper.assert_true(health > 0, "EnemyData", "生命值大于0")
	
	var level = enemy.get("level", 0)
	helper.assert_eq(level, 5, "EnemyData", "等级正确")

func test_get_template_name():
	var name = enemy_data.get_template_name("wolf")
	helper.assert_eq(name, "野狼", "EnemyData", "获取野狼模板名称")
	
	name = enemy_data.get_template_name("iron_back_wolf")
	helper.assert_eq(name, "铁背狼王", "EnemyData", "获取狼王模板名称")

func test_is_elite_template():
	var is_elite = enemy_data.is_elite_template("wolf")
	helper.assert_true(not is_elite, "EnemyData", "野狼不是精英")
	
	is_elite = enemy_data.is_elite_template("iron_back_wolf")
	helper.assert_true(is_elite, "EnemyData", "狼王是精英")
	
	is_elite = enemy_data.is_elite_template("herb_guardian")
	helper.assert_true(is_elite, "EnemyData", "看守者是精英")

func test_get_all_template_ids():
	var ids = enemy_data.get_all_template_ids()
	helper.assert_true(ids.size() >= 5, "EnemyData", "至少有5个模板")
