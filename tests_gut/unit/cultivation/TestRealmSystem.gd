extends GutTest

## RealmSystem 单元测试

var realm_system: RealmSystem = null

func before_all():
	await get_tree().process_frame

func before_each():
	realm_system = RealmSystem.new()
	
	add_child(realm_system)
	await get_tree().process_frame
	
	# 在 _ready 之后设置 mock 数据
	_setup_mock_data()

func after_each():
	if realm_system:
		realm_system.free()
		realm_system = null
	await get_tree().process_frame

func _setup_mock_data():
	realm_system.REALM_ORDER = ["炼气期", "筑基期", "金丹期", "元婴期"]
	realm_system.REALMS = {
		"炼气期": {
			"max_level": 10,
			"next_realm": "筑基期",
			"spirit_gain_speed": 1.0,
			"level_names": {"1": "一段", "2": "二段", "3": "三段"},
			"levels": {
				"1": {"health": 500, "attack": 50, "defense": 25, "max_spirit_energy": 10, "spirit_stone_cost": 100, "spirit_energy_cost": 10},
				"2": {"health": 550, "attack": 55, "defense": 28, "max_spirit_energy": 15, "spirit_stone_cost": 200, "spirit_energy_cost": 20},
				"10": {"health": 1000, "attack": 100, "defense": 50, "max_spirit_energy": 50, "spirit_stone_cost": 1000, "spirit_energy_cost": 100}
			}
		},
		"筑基期": {
			"max_level": 10,
			"next_realm": "金丹期",
			"spirit_gain_speed": 1.5,
			"level_names": {"1": "初期", "2": "中期"},
			"levels": {
				"1": {"health": 2000, "attack": 200, "defense": 100, "max_spirit_energy": 100, "spirit_stone_cost": 5000, "spirit_energy_cost": 200}
			}
		},
		"金丹期": {
			"max_level": 10,
			"next_realm": "元婴期",
			"spirit_gain_speed": 2.0,
			"levels": {}
		},
		"元婴期": {
			"max_level": 10,
			"next_realm": "",
			"spirit_gain_speed": 3.0,
			"levels": {}
		}
	}
	realm_system.BREAKTHROUGH_MATERIALS = {
		"炼气期": {"5": {"herb": 5}, "10": {"foundation_pill": 1}}
	}

#region 初始化测试

func test_initial_realm_order():
	assert_eq(realm_system.REALM_ORDER.size(), 4, "应有4个境界")

func test_signals_exist():
	assert_true(realm_system.has_signal("breakthrough_success"), "应有breakthrough_success信号")
	assert_true(realm_system.has_signal("breakthrough_failed"), "应有breakthrough_failed信号")

#endregion

#region 境界信息测试

func test_get_realm_info():
	var info = realm_system.get_realm_info("炼气期")
	assert_eq(info.get("max_level", 0), 10, "炼气期最大等级应为10")

func test_get_realm_info_invalid():
	var info = realm_system.get_realm_info("无效境界")
	assert_eq(info, {}, "无效境界应返回空字典")

func test_get_all_realms():
	var realms = realm_system.get_all_realms()
	assert_eq(realms.size(), 4, "应有4个境界")

func test_get_realm_display_name():
	var name = realm_system.get_realm_display_name("炼气期", 1)
	assert_eq(name, "炼气期 一段", "境界显示名称应正确")

func test_get_realm_display_name_unknown_level():
	var name = realm_system.get_realm_display_name("炼气期", 5)
	assert_eq(name, "炼气期 5段", "未知等级应显示数字")

#endregion

#region 等级信息测试

func test_get_level_info():
	var info = realm_system.get_level_info("炼气期", 1)
	assert_eq(info.get("health", 0), 500, "炼气期1级气血应为500")

func test_get_level_info_invalid_level():
	var info = realm_system.get_level_info("炼气期", 999)
	assert_eq(info, {}, "无效等级应返回空字典")

func test_get_level_name():
	var name = realm_system.get_level_name("炼气期", 1)
	assert_eq(name, "一段", "等级名称应正确")

func test_get_level_name_unknown():
	var name = realm_system.get_level_name("炼气期", 999)
	assert_eq(name, "999段", "未知等级应显示数字")

func test_get_max_spirit_energy():
	var energy = realm_system.get_max_spirit_energy("炼气期", 1)
	assert_eq(energy, 10, "炼气期1级最大灵气应为10")

func test_get_spirit_stone_cost():
	var cost = realm_system.get_spirit_stone_cost("炼气期", 1)
	assert_eq(cost, 100, "炼气期1级灵石消耗应为100")

func test_get_spirit_energy_cost():
	var cost = realm_system.get_spirit_energy_cost("炼气期", 1)
	assert_eq(cost, 10, "炼气期1级灵气消耗应为10")

func test_get_spirit_gain_speed():
	var speed = realm_system.get_spirit_gain_speed("炼气期")
	assert_eq(speed, 1.0, "炼气期灵气获取速度应为1.0")

func test_get_spirit_gain_speed_higher_realm():
	var speed = realm_system.get_spirit_gain_speed("筑基期")
	assert_eq(speed, 1.5, "筑基期灵气获取速度应为1.5")

#endregion

#region 总等级计算测试

func test_get_total_realm_level():
	var total = realm_system.get_total_realm_level("炼气期", 5)
	assert_eq(total, 5, "炼气期5级总等级应为5")

func test_get_total_realm_level_second_realm():
	var total = realm_system.get_total_realm_level("筑基期", 3)
	assert_eq(total, 13, "筑基期3级总等级应为13")

func test_get_total_realm_level_invalid_realm():
	var total = realm_system.get_total_realm_level("无效境界", 1)
	assert_eq(total, 0, "无效境界总等级应为0")

#endregion

#region 境界需求检查测试

func test_check_realm_requirement_empty():
	var result = realm_system.check_realm_requirement("炼气期", 1, {})
	assert_true(result, "空需求应返回true")

func test_check_realm_requirement_met():
	var result = realm_system.check_realm_requirement("筑基期", 5, {"realm_min": 13})
	assert_true(result, "满足需求应返回true")

func test_check_realm_requirement_not_met():
	var result = realm_system.check_realm_requirement("炼气期", 5, {"realm_min": 20})
	assert_false(result, "不满足需求应返回false")

#endregion

#region 突破材料测试

func test_get_breakthrough_materials_level():
	var materials = realm_system.get_breakthrough_materials("炼气期", 5, false)
	assert_true(materials.has("herb"), "应有灵草材料")
	assert_eq(materials.get("herb", 0), 5, "需要5个灵草")

func test_get_breakthrough_materials_realm():
	var materials = realm_system.get_breakthrough_materials("炼气期", 10, true)
	assert_true(materials.has("foundation_pill"), "应有筑基丹")
	assert_eq(materials.get("foundation_pill", 0), 1, "需要1个筑基丹")

func test_get_breakthrough_materials_empty():
	var materials = realm_system.get_breakthrough_materials("炼气期", 3, false)
	assert_eq(materials, {}, "无材料需求应返回空字典")

#endregion

#region 突破判定测试

func test_can_breakthrough_level():
	var result = realm_system.can_breakthrough("炼气期", 1, 200, 20, {})
	assert_true(result.get("can", false), "应能突破")
	assert_eq(result.get("type", ""), "level", "应为等级突破")

func test_can_breakthrough_realm():
	var result = realm_system.can_breakthrough("炼气期", 10, 2000, 200, {"foundation_pill": 1})
	assert_true(result.get("can", false), "应能突破境界")
	assert_eq(result.get("type", ""), "realm", "应为境界突破")
	assert_eq(result.get("next_realm", ""), "筑基期", "下一境界应为筑基期")

func test_can_breakthrough_insufficient_spirit_stone():
	var result = realm_system.can_breakthrough("炼气期", 1, 50, 20, {})
	assert_false(result.get("can", false), "灵石不足应不能突破")
	assert_eq(result.get("reason", ""), "灵石不足", "原因应为灵石不足")

func test_can_breakthrough_insufficient_spirit_energy():
	var result = realm_system.can_breakthrough("炼气期", 1, 200, 5, {})
	assert_false(result.get("can", false), "灵气不足应不能突破")
	assert_eq(result.get("reason", ""), "灵气不足", "原因应为灵气不足")

func test_can_breakthrough_insufficient_materials():
	var result = realm_system.can_breakthrough("炼气期", 5, 500, 50, {})
	assert_false(result.get("can", false), "材料不足应不能突破")
	assert_true(result.get("reason", "").contains("不足"), "原因应包含不足")

func test_can_breakthrough_max_realm():
	var result = realm_system.can_breakthrough("元婴期", 10, 10000, 1000, {})
	assert_false(result.get("can", false), "最高境界应不能突破")
	assert_eq(result.get("reason", ""), "已达到最高境界", "原因应为最高境界")

func test_can_breakthrough_invalid_realm():
	var result = realm_system.can_breakthrough("无效境界", 1, 1000, 100, {})
	assert_false(result.get("can", false), "无效境界应不能突破")
	assert_eq(result.get("reason", ""), "未知境界", "原因应为未知境界")

#endregion

#region 初始属性测试

func test_get_initial_stats():
	var stats = realm_system.get_initial_stats()
	assert_eq(stats.get("health", 0), 500, "初始气血应为500")
	assert_eq(stats.get("attack", 0), 50, "初始攻击应为50")

#endregion
