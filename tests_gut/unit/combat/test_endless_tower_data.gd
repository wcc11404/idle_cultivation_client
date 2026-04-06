## LianliAreaData 无尽塔功能单元测试
extends GutTest

var area_data: LianliAreaData = null

func before_each():
	area_data = LianliAreaData.new()
	add_child(area_data)

func after_each():
	if area_data:
		area_data.queue_free()

func test_tower_config_loaded():
	assert_not_null(area_data, "LianliAreaData模块初始化")

func test_get_tower_max_floor():
	var max_floor = area_data.get_tower_max_floor()
	assert_eq(max_floor, 51, "最高层应为51")

func test_get_tower_id():
	var tower_id = area_data.get_tower_id()
	assert_eq(tower_id, "endless_tower", "塔ID应为endless_tower")

func test_is_tower_area():
	assert_true(area_data.is_tower_area("endless_tower"), "应识别无尽塔区域")
	assert_false(area_data.is_tower_area("qi_refining_outer"), "普通区域不应是塔区域")

func test_get_tower_name():
	var tower_name = area_data.get_tower_name()
	assert_eq(tower_name, "无尽塔", "塔名称应正确")

func test_get_tower_reward_floors():
	var reward_floors = area_data.get_tower_reward_floors()
	assert_eq(reward_floors.size(), 10, "应有10个奖励层")
	assert_has(reward_floors, 5, "第5层应为奖励层")
	assert_has(reward_floors, 50, "第50层应为奖励层")

func test_is_tower_reward_floor():
	assert_true(area_data.is_tower_reward_floor(5), "第5层应为奖励层")
	assert_true(area_data.is_tower_reward_floor(50), "第50层应为奖励层")
	assert_false(area_data.is_tower_reward_floor(3), "第3层不应为奖励层")

func test_get_tower_reward_for_floor():
	var reward_5 = area_data.get_tower_reward_for_floor(5)
	assert_has(reward_5, "spirit_stone", "第5层应有灵石奖励")
	assert_has(reward_5, "health_pill", "第5层应有补血丹奖励")

func test_get_tower_random_template():
	var template = area_data.get_tower_random_template()
	assert_true(template in ["wolf", "snake", "boar"], "模板应为有效敌人")

func test_get_tower_next_reward_floor():
	var next_reward = area_data.get_tower_next_reward_floor(1)
	assert_eq(next_reward, 5, "从第1层下一个奖励层应为5")
	
	next_reward = area_data.get_tower_next_reward_floor(5)
	assert_eq(next_reward, 10, "从第5层下一个奖励层应为10")

func test_get_tower_floors_to_next_reward():
	var floors = area_data.get_tower_floors_to_next_reward(1)
	assert_eq(floors, 4, "从第1层到下一个奖励层需4层")
	
	floors = area_data.get_tower_floors_to_next_reward(50)
	assert_eq(floors, 0, "第50层后无奖励层")
