extends GutTest

var alchemy_system: AlchemySystem = null

func before_all():
	await get_tree().process_frame

func before_each():
	alchemy_system = AlchemySystem.new()
	add_child(alchemy_system)
	await get_tree().process_frame

func after_each():
	if alchemy_system:
		alchemy_system.queue_free()

#region 丹炉配置测试

func test_furnace_configs_exist():
	assert_true(alchemy_system.FURNACE_CONFIGS.has("alchemy_furnace"), "应有初级丹炉配置")

func test_furnace_config_values():
	var config = alchemy_system.FURNACE_CONFIGS["alchemy_furnace"]
	assert_eq(config.name, "初级丹炉", "丹炉名称应正确")
	assert_eq(config.success_bonus, 10, "成功值加成应为10")
	assert_eq(config.speed_rate, 0.1, "速度加成应为0.1")

#endregion

#region 丹炉装备测试

func test_has_furnace_false_initially():
	assert_false(alchemy_system.has_furnace(), "初始不应有丹炉")

func test_equip_furnace_success():
	var result = alchemy_system.equip_furnace("alchemy_furnace")
	assert_true(result, "装备丹炉应成功")
	assert_true(alchemy_system.has_furnace(), "装备后应有丹炉")

func test_equip_furnace_invalid():
	var result = alchemy_system.equip_furnace("invalid_furnace")
	assert_false(result, "装备无效丹炉应失败")
	assert_false(alchemy_system.has_furnace(), "装备失败后不应有丹炉")

func test_get_equipped_furnace_id():
	assert_eq(alchemy_system.get_equipped_furnace_id(), "", "初始丹炉ID应为空")
	
	alchemy_system.equip_furnace("alchemy_furnace")
	assert_eq(alchemy_system.get_equipped_furnace_id(), "alchemy_furnace", "装备后丹炉ID应正确")

#endregion

#region 丹炉加成测试

func test_get_furnace_bonus_no_furnace():
	var bonus = alchemy_system.get_furnace_bonus()
	assert_false(bonus.has_furnace, "无丹炉时has_furnace应为false")
	assert_eq(bonus.success_bonus, 0, "无丹炉时成功率加成应为0")
	assert_eq(bonus.speed_rate, 0.0, "无丹炉时速度加成应为0")

func test_get_furnace_bonus_with_furnace():
	alchemy_system.equip_furnace("alchemy_furnace")
	var bonus = alchemy_system.get_furnace_bonus()
	assert_true(bonus.has_furnace, "有丹炉时has_furnace应为true")
	assert_eq(bonus.success_bonus, 10, "丹炉应增加10成功值")
	assert_almost_eq(bonus.speed_rate, 0.1, 0.001, "丹炉应增加10%速度")
	assert_eq(bonus.furnace_name, "初级丹炉", "丹炉名称应正确")

#endregion

#region 丹方学习测试

func test_learned_recipes_empty_initially():
	assert_eq(alchemy_system.learned_recipes.size(), 0, "初始已学丹方应为空")

func test_learned_recipes_after_learn():
	alchemy_system.learned_recipes.append("qi_pill")
	assert_eq(alchemy_system.learned_recipes.size(), 1, "学习后应有1个丹方")
	assert_true("qi_pill" in alchemy_system.learned_recipes, "应包含聚气丹")

#endregion

#region 存档数据测试

func test_get_save_data():
	alchemy_system.equip_furnace("alchemy_furnace")
	alchemy_system.learned_recipes.append("qi_pill")
	var data = alchemy_system.get_save_data()
	assert_eq(data.equipped_furnace_id, "alchemy_furnace", "存档应包含丹炉ID")
	assert_eq(data.learned_recipes.size(), 1, "存档应包含已学丹方")

func test_get_save_data_empty():
	var data = alchemy_system.get_save_data()
	assert_eq(data.equipped_furnace_id, "", "无丹炉时存档ID应为空")
	assert_eq(data.learned_recipes.size(), 0, "无丹方时存档应为空数组")

func test_apply_save_data():
	var save_data = {
		"equipped_furnace_id": "alchemy_furnace",
		"learned_recipes": ["qi_pill", "healing_pill"]
	}
	alchemy_system.apply_save_data(save_data)
	assert_true(alchemy_system.has_furnace(), "加载存档后应有丹炉")
	assert_eq(alchemy_system.learned_recipes.size(), 2, "加载存档后应有2个丹方")

func test_apply_save_data_empty():
	alchemy_system.equip_furnace("alchemy_furnace")
	alchemy_system.learned_recipes.append("qi_pill")
	alchemy_system.apply_save_data({"equipped_furnace_id": "", "learned_recipes": []})
	assert_false(alchemy_system.has_furnace(), "加载空存档后不应有丹炉")
	assert_eq(alchemy_system.learned_recipes.size(), 0, "加载空存档后不应有丹方")

#endregion
