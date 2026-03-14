extends GutTest

## LianliSystem 单元测试

var lianli_system: LianliSystem = null

func before_all():
	await get_tree().process_frame

func before_each():
	lianli_system = LianliSystem.new()
	add_child(lianli_system)
	await get_tree().process_frame

func after_each():
	if lianli_system:
		lianli_system.queue_free()

#region 初始化状态测试

func test_initial_state():
	assert_false(lianli_system.is_in_lianli, "初始不应在历练中")
	assert_false(lianli_system.is_in_battle, "初始不应在战斗中")
	assert_false(lianli_system.is_waiting, "初始不应在等待中")
	assert_eq(lianli_system.current_area_id, "", "初始区域ID应为空")
	assert_true(lianli_system.current_enemy.is_empty(), "初始敌人数据应为空")

func test_initial_speed():
	assert_eq(lianli_system.lianli_speed, 1.0, "初始历练速度应为1.0")

func test_initial_continuous():
	assert_false(lianli_system.continuous_lianli, "初始连续历练应为false")

func test_initial_atb():
	assert_eq(lianli_system.player_atb, 0.0, "初始玩家ATB应为0")
	assert_eq(lianli_system.enemy_atb, 0.0, "初始敌人ATB应为0")

func test_initial_combat_buffs():
	assert_eq(lianli_system.combat_buffs.attack_percent, 0.0, "初始攻击加成应为0")
	assert_eq(lianli_system.combat_buffs.defense_percent, 0.0, "初始防御加成应为0")
	assert_eq(lianli_system.combat_buffs.speed_bonus, 0.0, "初始速度加成应为0")
	assert_eq(lianli_system.combat_buffs.health_bonus, 0.0, "初始气血加成应为0")

#endregion

#region 设置测试

func test_set_continuous_lianli():
	lianli_system.set_continuous_lianli(true)
	assert_true(lianli_system.continuous_lianli, "连续历练应为true")
	
	lianli_system.set_continuous_lianli(false)
	assert_false(lianli_system.continuous_lianli, "连续历练应为false")

func test_set_lianli_speed():
	lianli_system.set_lianli_speed(1.5)
	assert_eq(lianli_system.lianli_speed, 1.5, "历练速度应正确设置")

func test_set_lianli_speed_clamped_max():
	lianli_system.set_lianli_speed(3.0)
	assert_eq(lianli_system.lianli_speed, 2.0, "历练速度应被限制在最大值")

func test_set_lianli_speed_clamped_min():
	lianli_system.set_lianli_speed(0.5)
	assert_eq(lianli_system.lianli_speed, 1.0, "历练速度应被限制在最小值")

func test_set_current_area():
	lianli_system.set_current_area("test_area")
	assert_eq(lianli_system.current_area_id, "test_area", "区域ID应正确设置")

#endregion

#region ATB常量测试

func test_atb_max_value():
	assert_eq(lianli_system.ATB_MAX, 100.0, "ATB最大值应为100")

#endregion

#region 战斗Buff测试

func test_combat_buffs_structure():
	assert_true(lianli_system.combat_buffs.has("attack_percent"), "应有攻击百分比")
	assert_true(lianli_system.combat_buffs.has("defense_percent"), "应有防御百分比")
	assert_true(lianli_system.combat_buffs.has("speed_bonus"), "应有速度加成")
	assert_true(lianli_system.combat_buffs.has("health_bonus"), "应有气血加成")

#endregion

#region 开始历练测试 - 无依赖

func test_start_lianli_in_area_no_area_data():
	var result = lianli_system.start_lianli_in_area("test_area")
	assert_false(result, "无区域数据时应失败")

func test_start_lianli_in_area_zero_health_no_player():
	var result = lianli_system.start_lianli_in_area("test_area")
	assert_false(result, "无区域数据时应失败")

#endregion

#region 结束历练测试

func test_end_lianli_not_in_lianli():
	lianli_system.end_lianli()
	assert_false(lianli_system.is_in_lianli, "不在历练时结束应无效果")

#endregion

#region 无尽塔测试

func test_is_in_tower_initial():
	assert_false(lianli_system.is_in_tower, "初始不应在无尽塔中")

func test_current_tower_floor_initial():
	assert_eq(lianli_system.current_tower_floor, 0, "初始无尽塔层数应为0")

func test_start_endless_tower_no_data():
	var result = lianli_system.start_endless_tower()
	assert_false(result, "无无尽塔数据时应失败")

#endregion

#region 等待测试

func test_is_waiting_initial():
	assert_false(lianli_system.is_waiting, "初始不应在等待中")

func test_wait_timer_initial():
	assert_eq(lianli_system.wait_timer, 0.0, "初始等待计时器应为0")

#endregion

#region 信号测试

func test_signals_exist():
	assert_true(lianli_system.has_signal("lianli_started"), "应有lianli_started信号")
	assert_true(lianli_system.has_signal("lianli_ended"), "应有lianli_ended信号")
	assert_true(lianli_system.has_signal("battle_started"), "应有battle_started信号")
	assert_true(lianli_system.has_signal("battle_ended"), "应有battle_ended信号")
	assert_true(lianli_system.has_signal("battle_updated"), "应有battle_updated信号")
	assert_true(lianli_system.has_signal("lianli_reward"), "应有lianli_reward信号")
	assert_true(lianli_system.has_signal("log_message"), "应有log_message信号")

#endregion
