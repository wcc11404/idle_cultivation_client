extends Node

var helper: Node = null
var lianli_area_data: Node = null

func _ready():
	helper = load("res://tests/test_helper.gd").new()
	add_child(helper)
	
	lianli_area_data = load("res://scripts/core/LianliAreaData.gd").new()
	add_child(lianli_area_data)

func run_tests():
	print("\n=== LianliAreaData 单元测试 ===")
	helper.reset_stats()
	
	test_initialization()
	test_get_area_data()
	test_get_area_name()
	test_get_random_enemy_config()
	test_get_enemies_list()
	test_is_single_boss_area()
	test_get_special_drops()
	
	return helper.failed_count == 0

func test_initialization():
	helper.assert_true(lianli_area_data != null, "LianliAreaData", "模块初始化")

func test_get_area_data():
	var data = lianli_area_data.get_area_data("qi_refining_outer")
	helper.assert_true(not data.is_empty(), "LianliAreaData", "获取炼气期外围森林数据")
	
	var name = data.get("name", "")
	helper.assert_eq(name, "炼气期外围森林", "LianliAreaData", "区域名称")

func test_get_area_name():
	var name = lianli_area_data.get_area_name("qi_refining_outer")
	helper.assert_eq(name, "炼气期外围森林", "LianliAreaData", "获取区域名称")
	
	name = lianli_area_data.get_area_name("qi_refining_inner")
	helper.assert_eq(name, "炼气期内围山谷", "LianliAreaData", "获取区域名称2")

func test_get_random_enemy_config():
	var enemy = lianli_area_data.get_random_enemy_config("qi_refining_outer")
	helper.assert_true(not enemy.is_empty(), "LianliAreaData", "随机获取敌人配置")
	
	var template = enemy.get("template", "")
	helper.assert_true(not template.is_empty(), "LianliAreaData", "敌人模板不为空")

func test_get_enemies_list():
	var enemies = lianli_area_data.get_enemies_list("qi_refining_outer")
	helper.assert_eq(enemies.size(), 3, "LianliAreaData", "炼气期外围有3种敌人")
	
	var has_elite = false
	for enemy in enemies:
		var template = enemy.get("template", "")
		if template == "iron_back_wolf" or template == "herb_guardian":
			has_elite = true
			break
	helper.assert_true(not has_elite, "LianliAreaData", "外围区域没有精英")
	
	# 检查内围区域有精英
	enemies = lianli_area_data.get_enemies_list("qi_refining_inner")
	has_elite = false
	for enemy in enemies:
		var template = enemy.get("template", "")
		if template == "iron_back_wolf":
			has_elite = true
			break
	helper.assert_true(has_elite, "LianliAreaData", "内围区域包含精英")

func test_is_single_boss_area():
	var is_boss = lianli_area_data.is_single_boss_area("foundation_herb_cave")
	helper.assert_true(is_boss, "LianliAreaData", "破境草洞穴是BOSS区域")
	
	is_boss = lianli_area_data.is_single_boss_area("qi_refining_outer")
	helper.assert_true(not is_boss, "LianliAreaData", "外围森林不是BOSS区域")

func test_get_special_drops():
	var drops = lianli_area_data.get_special_drops("foundation_herb_cave")
	helper.assert_true(not drops.is_empty(), "LianliAreaData", "破境草洞穴有特殊掉落")
	
	var has_foundation_herb = drops.has("foundation_herb")
	helper.assert_true(has_foundation_herb, "LianliAreaData", "包含破境草")
