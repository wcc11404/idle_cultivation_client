extends GutTest

## CultivationSystem 单元测试

var cultivation_system: CultivationSystem = null
var player: PlayerData = null

func before_all():
	await get_tree().process_frame

func before_each():
	cultivation_system = CultivationSystem.new()
	player = PlayerData.new()
	add_child(player)
	await get_tree().process_frame
	
	cultivation_system.set_player(player)
	add_child(cultivation_system)
	await get_tree().process_frame

func after_each():
	if cultivation_system:
		cultivation_system.queue_free()
	if player:
		player.queue_free()

#region 初始化测试

func test_initialization():
	assert_not_null(cultivation_system, "CultivationSystem模块初始化")
	assert_eq(cultivation_system.player, player, "玩家正确设置")

func test_initial_state():
	assert_false(cultivation_system.is_cultivating, "初始不应在修炼中")
	assert_eq(cultivation_system.cultivation_timer, 0.0, "初始计时器应为0")
	assert_eq(cultivation_system.cultivation_interval, 1.0, "默认间隔应为1秒")

func test_base_heal_per_second():
	assert_eq(cultivation_system.BASE_HEAL_PER_SECOND, 1.0, "基础治疗量应为1.0")

#endregion

#region 开始/停止修炼测试

func test_start_cultivation():
	cultivation_system.start_cultivation()
	assert_true(cultivation_system.is_cultivating, "应在修炼中")
	assert_true(player.get_is_cultivating(), "玩家修炼状态应为true")

func test_start_cultivation_no_player():
	cultivation_system.player = null
	cultivation_system.start_cultivation()
	assert_false(cultivation_system.is_cultivating, "无玩家时不应开始修炼")

func test_stop_cultivation():
	cultivation_system.start_cultivation()
	cultivation_system.stop_cultivation()
	assert_false(cultivation_system.is_cultivating, "应停止修炼")
	assert_false(player.get_is_cultivating(), "玩家修炼状态应为false")

func test_stop_cultivation_when_not_cultivating():
	cultivation_system.stop_cultivation()
	assert_false(cultivation_system.is_cultivating, "不在修炼时停止应无效果")

#endregion

#region 修炼效果测试

func test_do_cultivate_increases_spirit_energy():
	player.spirit_energy = 0.0
	cultivation_system.do_cultivate()
	assert_gt(player.spirit_energy, 0, "修炼应增加灵气")

func test_do_cultivate_heals_player():
	player.health = player.get_final_max_health() * 0.5
	var health_before = player.health
	cultivation_system.do_cultivate()
	assert_gt(player.health, health_before, "修炼应恢复气血")

func test_do_cultivate_not_heal_full_health():
	player.health = player.get_final_max_health()
	var health_before = player.health
	cultivation_system.do_cultivate()
	assert_eq(player.health, health_before, "满血时不应治疗")

func test_do_cultivate_not_exceed_max_spirit():
	player.spirit_energy = player.get_final_max_spirit_energy() - 0.5
	cultivation_system.do_cultivate()
	assert_lte(player.spirit_energy, player.get_final_max_spirit_energy(), "灵气不应超过上限")

func test_do_cultivate_no_player():
	cultivation_system.player = null
	cultivation_system.do_cultivate()
	assert_true(true, "无玩家时应不报错")

func test_cultivation_gains_spirit_energy():
	player.spirit_energy = 0.0
	cultivation_system.start_cultivation()
	cultivation_system.do_cultivate()
	assert_eq(player.spirit_energy, 1.0, "修炼获得灵气")

#endregion

#region 信号测试

func test_signals_exist():
	assert_true(cultivation_system.has_signal("cultivation_progress"), "应有cultivation_progress信号")
	assert_true(cultivation_system.has_signal("cultivation_complete"), "应有cultivation_complete信号")
	assert_true(cultivation_system.has_signal("log_message"), "应有log_message信号")

func test_cultivation_complete_signal():
	watch_signals(cultivation_system)
	player.spirit_energy = player.get_final_max_spirit_energy()
	cultivation_system.do_cultivate()
	await wait_for_signal(cultivation_system.cultivation_complete, 1.0)
	assert_signal_emitted(cultivation_system.cultivation_complete, "灵气满时应发出完成信号")

#endregion
