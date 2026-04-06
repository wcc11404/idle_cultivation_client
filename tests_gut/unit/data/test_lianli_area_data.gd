extends GutTest

## LianliAreaData 单元测试 - 使用真实配置数据

var lianli_area_data: LianliAreaData = null

func before_all():
	await get_tree().process_frame

func before_each():
	lianli_area_data = LianliAreaData.new()
	add_child(lianli_area_data)
	await get_tree().process_frame

func after_each():
	if lianli_area_data:
		lianli_area_data.queue_free()

#region 初始化测试

func test_initialization():
	assert_not_null(lianli_area_data, "LianliAreaData模块初始化")

func test_normal_areas_loaded():
	var areas = lianli_area_data.get_normal_areas()
	assert_gt(areas.size(), 0, "应加载普通区域")

func test_special_areas_loaded():
	var areas = lianli_area_data.get_daily_areas()
	assert_gt(areas.size(), 0, "应加载每日区域")

#endregion

#region 普通区域测试

func test_get_qi_refining_outer():
	var data = lianli_area_data.get_area_data("qi_refining_outer")
	assert_eq(data.get("name", ""), "炼气期外围森林", "炼气期外围名称应正确")
	assert_true(data.get("default_continuous", false), "外围区域应默认连续")

func test_get_qi_refining_inner():
	var data = lianli_area_data.get_area_data("qi_refining_inner")
	assert_eq(data.get("name", ""), "炼气期内围山谷", "炼气期内围名称应正确")

func test_get_foundation_outer():
	var data = lianli_area_data.get_area_data("foundation_outer")
	assert_eq(data.get("name", ""), "筑基期外围荒原", "筑基期外围名称应正确")

func test_get_foundation_inner():
	var data = lianli_area_data.get_area_data("foundation_inner")
	assert_eq(data.get("name", ""), "筑基期内围沼泽", "筑基期内围名称应正确")

func test_get_area_name():
	var name = lianli_area_data.get_area_name("qi_refining_outer")
	assert_eq(name, "炼气期外围森林", "区域名称应正确")

func test_get_area_name_invalid():
	var name = lianli_area_data.get_area_name("invalid_area")
	assert_eq(name, "未知区域", "无效区域应返回未知区域")

func test_get_area_description():
	var desc = lianli_area_data.get_area_description("qi_refining_outer")
	assert_true(desc.length() > 0, "区域描述不应为空")

#endregion

#region 特殊区域测试 - 破境草洞穴

func test_get_foundation_herb_cave():
	var data = lianli_area_data.get_area_data("foundation_herb_cave")
	assert_eq(data.get("name", ""), "破境草洞穴", "破境草洞穴名称应正确")
	assert_eq(data.get("description", ""), "神秘的洞穴，由强大的看守者守护", "描述应正确")

func test_foundation_herb_cave_is_special():
	assert_true(lianli_area_data.is_special_area("foundation_herb_cave"), "破境草洞穴应为每日区域")
	assert_false(lianli_area_data.is_normal_area("foundation_herb_cave"), "破境草洞穴不应为普通区域")

func test_foundation_herb_cave_is_single_boss():
	assert_true(lianli_area_data.is_single_boss_area("foundation_herb_cave"), "破境草洞穴应为Boss区域")

func test_foundation_herb_cave_special_drops():
	var drops = lianli_area_data.get_special_drops("foundation_herb_cave")
	assert_true(drops.has("foundation_herb"), "应有破境草掉落")
	assert_eq(drops.get("foundation_herb", 0), 10, "破境草数量应为10")
	assert_true(drops.has("spirit_stone"), "应有灵石掉落")
	assert_eq(drops.get("spirit_stone", 0), 20, "灵石数量应为20")

func test_foundation_herb_cave_enemies():
	var enemies_template = lianli_area_data.get_enemies_list("foundation_herb_cave")
	assert_eq(enemies_template.size(), 1, "应有1组敌人配置")
	var enemies_list = enemies_template[0].get("enemies", [])
	assert_eq(enemies_list.size(), 1, "应有1种敌人")
	assert_eq(enemies_list[0].get("template", ""), "herb_guardian", "敌人应为灵草看守者")
	assert_eq(enemies_list[0].get("min_level", 0), 10, "最小等级应为10")
	assert_eq(enemies_list[0].get("max_level", 0), 10, "最大等级应为10")

func test_foundation_herb_cave_not_continuous():
	var continuous = lianli_area_data.get_default_continuous("foundation_herb_cave")
	assert_false(continuous, "破境草洞穴不应默认连续")

#endregion

#region 敌人配置测试

func test_get_random_enemy_config_outer():
	var config = lianli_area_data.get_random_enemy_config("qi_refining_outer")
	assert_false(config.is_empty(), "应返回敌人配置")
	assert_true(config.has("template"), "应有模板字段")

func test_get_enemies_list_outer():
	var enemies_template = lianli_area_data.get_enemies_list("qi_refining_outer")
	assert_eq(enemies_template.size(), 3, "炼气期外围应有3组敌人配置")

func test_get_enemies_list_inner():
	var enemies_template = lianli_area_data.get_enemies_list("qi_refining_inner")
	assert_eq(enemies_template.size(), 4, "炼气期内围应有4组敌人配置")

func test_inner_has_elite():
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

#endregion

#region 区域类型判断测试

func test_is_normal_area():
	assert_true(lianli_area_data.is_normal_area("qi_refining_outer"), "外围森林应为普通区域")
	assert_false(lianli_area_data.is_normal_area("foundation_herb_cave"), "破境草洞穴不应为普通区域")

func test_is_special_area():
	assert_true(lianli_area_data.is_special_area("foundation_herb_cave"), "破境草洞穴应为特殊区域")
	assert_false(lianli_area_data.is_special_area("qi_refining_outer"), "外围森林不应为特殊区域")

func test_is_single_boss_area():
	assert_true(lianli_area_data.is_single_boss_area("foundation_herb_cave"), "破境草洞穴应为Boss区域")
	assert_false(lianli_area_data.is_single_boss_area("qi_refining_outer"), "外围森林不应为Boss区域")

#endregion

#region 获取所有区域测试

func test_get_all_areas():
	var all_areas = lianli_area_data.get_all_areas()
	assert_gt(all_areas.size(), 4, "应有多个区域")

func test_get_normal_area_ids():
	var ids = lianli_area_data.get_normal_area_ids()
	assert_gt(ids.size(), 0, "应有普通区域ID")

func test_get_special_area_ids():
	var ids = lianli_area_data.get_daily_area_ids()
	assert_gt(ids.size(), 0, "应有每日区域ID")

func test_get_all_area_ids():
	var ids = lianli_area_data.get_all_area_ids()
	assert_gt(ids.size(), 4, "应有多个区域ID")

#endregion
