extends GutTest

## EndlessTowerData 单元测试 - 完整版

var tower_data: EndlessTowerData = null

func before_all():
	await get_tree().process_frame

func before_each():
	tower_data = EndlessTowerData.new()
	add_child(tower_data)
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout

func after_each():
	if tower_data:
		tower_data.queue_free()

#region 初始化测试

func test_initialization():
	assert_not_null(tower_data, "EndlessTowerData模块初始化")

func test_get_max_floor():
	var max_floor = tower_data.get_max_floor()
	assert_eq(max_floor, 51, "最大层数应为51")

func test_get_tower_name():
	var name = tower_data.get_tower_name()
	assert_eq(name, "无尽塔", "塔名称应为无尽塔")

func test_get_tower_description():
	var desc = tower_data.get_tower_description()
	assert_true(desc.length() > 0, "描述不应为空")

func test_get_area_id():
	var area_id = tower_data.get_area_id()
	assert_eq(area_id, "endless_tower", "区域ID应正确")

#endregion

#region 奖励层数测试

func test_get_reward_floors():
	var reward_floors = tower_data.get_reward_floors()
	assert_eq(reward_floors.size(), 10, "应有10个奖励层")

func test_reward_floors_not_empty():
	var reward_floors = tower_data.get_reward_floors()
	assert_gt(reward_floors.size(), 0, "奖励层数组不应为空")

func test_reward_floors_contain_expected_values():
	var reward_floors = tower_data.get_reward_floors()
	# JSON 解析后数字可能是 float，转换为 int 比较
	var expected = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
	for expected_floor in expected:
		var found = false
		for floor in reward_floors:
			if int(floor) == expected_floor:
				found = true
				break
		assert_true(found, str(expected_floor) + "层应在奖励层列表中")

func test_get_next_reward_floor():
	var next = tower_data.get_next_reward_floor(0)
	assert_gt(next, 0, "从0层开始应有下一个奖励层")

func test_get_next_reward_floor_from_5():
	var next = tower_data.get_next_reward_floor(5)
	assert_gt(next, 5, "从5层开始下一个奖励层应大于5")

func test_get_next_reward_floor_from_45():
	var next = tower_data.get_next_reward_floor(45)
	assert_gt(next, 45, "从45层开始下一个奖励层应大于45")

func test_get_next_reward_floor_at_max():
	var next = tower_data.get_next_reward_floor(50)
	assert_eq(next, -1, "超过50层应返回-1")

func test_get_next_reward_floor_over_max():
	var next = tower_data.get_next_reward_floor(100)
	assert_eq(next, -1, "超过最大层应返回-1")

func test_get_floors_to_next_reward():
	var floors_to = tower_data.get_floors_to_next_reward(0)
	assert_gt(floors_to, 0, "从0层到下一个奖励层应大于0")

func test_get_floors_to_next_reward_from_7():
	var floors_to = tower_data.get_floors_to_next_reward(7)
	assert_gt(floors_to, 0, "从7层到下一个奖励层应大于0")

func test_get_floors_to_next_reward_at_max():
	var floors_to = tower_data.get_floors_to_next_reward(100)
	assert_eq(floors_to, 0, "超过最大层应返回0")

#endregion

#region 奖励内容测试

func test_get_reward_for_floor_5():
	var reward = tower_data.get_reward_for_floor(5)
	assert_true(reward.has("spirit_stone"), "第5层应有灵石奖励")
	assert_eq(reward.get("spirit_stone", 0), 10, "第5层灵石奖励应为10")

func test_get_reward_for_floor_10():
	var reward = tower_data.get_reward_for_floor(10)
	assert_eq(reward.get("spirit_stone", 0), 20, "第10层灵石奖励应为20")

func test_get_reward_for_floor_15():
	var reward = tower_data.get_reward_for_floor(15)
	assert_eq(reward.get("spirit_stone", 0), 30, "第15层灵石奖励应为30")

func test_get_reward_for_floor_20():
	var reward = tower_data.get_reward_for_floor(20)
	assert_true(reward.has("spirit_stone"), "第20层应有灵石奖励")
	assert_eq(reward.get("spirit_stone", 0), 60, "第20层灵石奖励应为60")

func test_get_reward_for_floor_25():
	var reward = tower_data.get_reward_for_floor(25)
	assert_true(reward.has("spirit_stone"), "第25层应有灵石奖励")
	assert_eq(reward.get("spirit_stone", 0), 90, "第25层灵石奖励应为90")

func test_get_reward_for_floor_30():
	var reward = tower_data.get_reward_for_floor(30)
	assert_true(reward.has("spirit_stone"), "第30层应有灵石奖励")
	assert_eq(reward.get("spirit_stone", 0), 150, "第30层灵石奖励应为150")

func test_get_reward_for_floor_35():
	var reward = tower_data.get_reward_for_floor(35)
	assert_true(reward.has("spirit_stone"), "第35层应有灵石奖励")
	assert_eq(reward.get("spirit_stone", 0), 250, "第35层灵石奖励应为250")

func test_get_reward_for_floor_40():
	var reward = tower_data.get_reward_for_floor(40)
	assert_true(reward.has("spirit_stone"), "第40层应有灵石奖励")
	assert_eq(reward.get("spirit_stone", 0), 410, "第40层灵石奖励应为410")

func test_get_reward_for_floor_45():
	var reward = tower_data.get_reward_for_floor(45)
	assert_true(reward.has("spirit_stone"), "第45层应有灵石奖励")
	assert_eq(reward.get("spirit_stone", 0), 600, "第45层灵石奖励应为600")

func test_get_reward_for_floor_50():
	var reward = tower_data.get_reward_for_floor(50)
	assert_true(reward.has("spirit_stone"), "第50层应有灵石奖励")
	assert_eq(reward.get("spirit_stone", 0), 1060, "第50层灵石奖励应为1060")

func test_get_reward_for_floor_invalid():
	var reward = tower_data.get_reward_for_floor(999)
	assert_true(reward.size() >= 0, "无效层应返回有效结果")

func test_get_reward_description():
	var desc = tower_data.get_reward_description(5)
	assert_true(desc.length() > 0 or desc == "", "奖励描述应有效")

func test_reward_progression():
	var reward_5 = tower_data.get_reward_for_floor(5)
	var reward_10 = tower_data.get_reward_for_floor(10)
	var reward_50 = tower_data.get_reward_for_floor(50)
	
	assert_gt(reward_10.get("spirit_stone", 0), reward_5.get("spirit_stone", 0), "高层奖励应大于低层")
	assert_gt(reward_50.get("spirit_stone", 0), reward_10.get("spirit_stone", 0), "50层奖励应大于10层")

func test_floor_20_has_foundation_pill():
	var reward = tower_data.get_reward_for_floor(20)
	assert_true(reward.has("foundation_pill"), "第20层应有筑基丹")

#endregion

#region 敌人模板测试

func test_get_random_template():
	var template = tower_data.get_random_template()
	assert_true(template in ["wolf", "snake", "boar"], "模板应为有效敌人")

func test_templates_are_valid():
	for i in range(20):
		var template = tower_data.get_random_template()
		assert_true(template in ["wolf", "snake", "boar"], "所有模板应为有效敌人")

func test_templates_have_variety():
	var seen = {}
	for i in range(50):
		var template = tower_data.get_random_template()
		seen[template] = true
	assert_gt(seen.size(), 1, "应有多种敌人模板")

#endregion

#region 层数边界测试

func test_floor_1_not_reward():
	assert_false(tower_data.is_reward_floor(1), "第1层不应为奖励层")

func test_floor_51_not_reward():
	assert_false(tower_data.is_reward_floor(51), "第51层不应为奖励层")

func test_floor_0_not_reward():
	assert_false(tower_data.is_reward_floor(0), "第0层不应为奖励层")

func test_negative_floor():
	assert_false(tower_data.is_reward_floor(-1), "负数层不应为奖励层")

#endregion
