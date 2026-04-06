extends GutTest

## 特殊副本系统单元测试
## 包含破境草洞穴等特殊区域的测试

var lianli_area_data: LianliAreaData = null
var enemy_data: EnemyData = null

func before_all():
	await get_tree().process_frame

func before_each():
	lianli_area_data = LianliAreaData.new()
	enemy_data = EnemyData.new()
	
	add_child(lianli_area_data)
	add_child(enemy_data)
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout

func after_each():
	if lianli_area_data:
		lianli_area_data.queue_free()
	if enemy_data:
		enemy_data.queue_free()

#region 破境草洞穴基础测试

func test_foundation_herb_cave_exists():
	var data = lianli_area_data.get_area_data("foundation_herb_cave")
	assert_false(data.is_empty(), "破境草洞穴应存在")

func test_foundation_herb_cave_name():
	var data = lianli_area_data.get_area_data("foundation_herb_cave")
	assert_eq(data.get("name", ""), "破境草洞穴", "名称应正确")

func test_foundation_herb_cave_description():
	var data = lianli_area_data.get_area_data("foundation_herb_cave")
	assert_eq(data.get("description", ""), "神秘的洞穴，由强大的看守者守护", "描述应正确")

func test_foundation_herb_cave_is_special():
	assert_true(lianli_area_data.is_special_area("foundation_herb_cave"), "应为特殊区域")
	assert_false(lianli_area_data.is_normal_area("foundation_herb_cave"), "不应为普通区域")

func test_foundation_herb_cave_is_single_boss():
	assert_true(lianli_area_data.is_single_boss_area("foundation_herb_cave"), "应为Boss区域")

func test_foundation_herb_cave_not_continuous():
	var continuous = lianli_area_data.get_default_continuous("foundation_herb_cave")
	assert_false(continuous, "不应默认连续")

#endregion

#region 破境草洞穴敌人测试

func test_foundation_herb_cave_enemy_count():
	var enemies_template = lianli_area_data.get_enemies_list("foundation_herb_cave")
	assert_eq(enemies_template.size(), 1, "应有1组敌人配置")

func test_foundation_herb_cave_enemy_template():
	var enemies_template = lianli_area_data.get_enemies_list("foundation_herb_cave")
	var enemies_list = enemies_template[0].get("enemies", [])
	assert_eq(enemies_list[0].get("template", ""), "herb_guardian", "敌人应为灵草看守者")

func test_foundation_herb_cave_enemy_level():
	var enemies_template = lianli_area_data.get_enemies_list("foundation_herb_cave")
	var enemies_list = enemies_template[0].get("enemies", [])
	assert_eq(enemies_list[0].get("min_level", 0), 10, "最小等级应为10")
	assert_eq(enemies_list[0].get("max_level", 0), 10, "最大等级应为10")

func test_herb_guardian_enemy_generation():
	var enemy = enemy_data.generate_enemy("herb_guardian", 10)
	assert_false(enemy.is_empty(), "应能生成灵草看守者")
	assert_eq(enemy.level, 10, "等级应为10")
	assert_true(enemy.is_elite, "应为精英敌人")

#endregion

#region 破境草洞穴掉落测试

func test_foundation_herb_cave_special_drops():
	var drops = lianli_area_data.get_special_drops("foundation_herb_cave")
	assert_true(drops.has("foundation_herb"), "应有破境草掉落")
	assert_eq(drops.get("foundation_herb", 0), 10, "破境草数量应为10")

func test_foundation_herb_cave_spirit_stone_drop():
	var drops = lianli_area_data.get_special_drops("foundation_herb_cave")
	assert_true(drops.has("spirit_stone"), "应有灵石掉落")
	assert_eq(drops.get("spirit_stone", 0), 20, "灵石数量应为20")

func test_foundation_herb_cave_guaranteed_drops():
	var drops = lianli_area_data.get_special_drops("foundation_herb_cave")
	assert_gt(drops.size(), 0, "Boss区域应有保底掉落")

#endregion

#region 其他特殊区域测试

func test_all_special_areas_are_special():
	var daily_ids = lianli_area_data.get_daily_area_ids()
	for area_id in daily_ids:
		assert_true(lianli_area_data.is_special_area(area_id), area_id + "应为每日区域")

func test_all_special_areas_have_enemies():
	var daily_ids = lianli_area_data.get_daily_area_ids()
	for area_id in daily_ids:
		var enemies_template = lianli_area_data.get_enemies_list(area_id)
		assert_gt(enemies_template.size(), 0, area_id + "应有敌人")

func test_all_special_areas_have_drops():
	var daily_ids = lianli_area_data.get_daily_area_ids()
	for area_id in daily_ids:
		var drops = lianli_area_data.get_special_drops(area_id)
		assert_gt(drops.size(), 0, area_id + "应有特殊掉落")

#endregion

#region 特殊区域与普通区域对比测试

func test_special_vs_normal_areas():
	var normal_ids = lianli_area_data.get_normal_area_ids()
	var daily_ids = lianli_area_data.get_daily_area_ids()
	
	for normal_id in normal_ids:
		assert_false(lianli_area_data.is_special_area(normal_id), normal_id + "不应为每日区域")
	
	for daily_id in daily_ids:
		assert_false(lianli_area_data.is_normal_area(daily_id), daily_id + "不应为普通区域")

func test_special_areas_have_boss():
	var daily_ids = lianli_area_data.get_daily_area_ids()
	for area_id in daily_ids:
		assert_true(lianli_area_data.is_single_boss_area(area_id), area_id + "应为Boss区域")

func test_normal_areas_not_boss():
	var normal_ids = lianli_area_data.get_normal_area_ids()
	for area_id in normal_ids:
		assert_false(lianli_area_data.is_single_boss_area(area_id), area_id + "不应为Boss区域")

#endregion

#region 区域解锁条件测试

func test_qi_refining_areas():
	var outer = lianli_area_data.get_area_data("qi_refining_outer")
	var inner = lianli_area_data.get_area_data("qi_refining_inner")
	
	assert_false(outer.is_empty(), "炼气期外围应存在")
	assert_false(inner.is_empty(), "炼气期内围应存在")

func test_foundation_areas():
	var outer = lianli_area_data.get_area_data("foundation_outer")
	var inner = lianli_area_data.get_area_data("foundation_inner")
	
	assert_false(outer.is_empty(), "筑基期外围应存在")
	assert_false(inner.is_empty(), "筑基期内围应存在")

func test_area_progression():
	var areas = [
		"qi_refining_outer",
		"qi_refining_inner",
		"foundation_outer",
		"foundation_inner"
	]
	
	for area_id in areas:
		var data = lianli_area_data.get_area_data(area_id)
		assert_false(data.is_empty(), area_id + "应存在")

#endregion

#region 普通区域敌人配置测试

func test_qi_refining_outer_enemies():
	var enemies_template = lianli_area_data.get_enemies_list("qi_refining_outer")
	assert_eq(enemies_template.size(), 3, "炼气期外围应有3组敌人配置")

func test_qi_refining_inner_enemies():
	var enemies_template = lianli_area_data.get_enemies_list("qi_refining_inner")
	assert_eq(enemies_template.size(), 4, "炼气期内围应有4组敌人配置")

func test_qi_refining_inner_has_elite():
	var enemies_template = lianli_area_data.get_enemies_list("qi_refining_inner")
	var has_elite = false
	for enemy_group in enemies_template:
		var enemies_list = enemy_group.get("enemies", [])
		for enemy in enemies_list:
			if enemy.get("template", "") == "iron_back_wolf":
				has_elite = true
				break
		if has_elite:
			break
	assert_true(has_elite, "炼气期内围应有铁背狼王")

func test_foundation_outer_enemies():
	var enemies_template = lianli_area_data.get_enemies_list("foundation_outer")
	assert_eq(enemies_template.size(), 3, "筑基期外围应有3组敌人配置")

func test_foundation_inner_enemies():
	var enemies_template = lianli_area_data.get_enemies_list("foundation_inner")
	assert_eq(enemies_template.size(), 4, "筑基期内围应有4组敌人配置")

#endregion

#region 区域默认连续测试

func test_normal_areas_default_continuous():
	var normal_ids = lianli_area_data.get_normal_area_ids()
	for area_id in normal_ids:
		var continuous = lianli_area_data.get_default_continuous(area_id)
		assert_true(continuous, area_id + "应默认连续")

func test_special_areas_not_continuous():
	var daily_ids = lianli_area_data.get_daily_area_ids()
	for area_id in daily_ids:
		var continuous = lianli_area_data.get_default_continuous(area_id)
		assert_false(continuous, area_id + "不应默认连续")

#endregion
