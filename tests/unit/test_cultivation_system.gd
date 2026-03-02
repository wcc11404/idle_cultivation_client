extends Node

var helper: Node = null
var test_cultivation: Node = null
var test_player: Node = null

func _ready():
	helper = load("res://tests/test_helper.gd").new()
	add_child(helper)

func run_tests():
	print("\n=== CultivationSystem 单元测试 ===")
	helper.reset_stats()
	
	test_player = load("res://scripts/core/PlayerData.gd").new()
	add_child(test_player)
	
	test_cultivation = load("res://scripts/core/realm/CultivationSystem.gd").new()
	test_cultivation.set_player(test_player)
	add_child(test_cultivation)
	
	test_initialization()
	test_start_stop()
	test_do_cultivation()
	
	return helper.failed_count == 0

func test_initialization():
	helper.assert_true(test_cultivation != null, "CultivationSystem", "模块初始化")
	helper.assert_true(test_cultivation.player == test_player, "CultivationSystem", "玩家正确设置")

func test_start_stop():
	test_cultivation.start_cultivation()
	helper.assert_true(test_cultivation.is_cultivating, "CultivationSystem", "修炼启动")
	helper.assert_true(test_player.get_is_cultivating(), "CultivationSystem", "玩家修炼状态开启")
	
	test_cultivation.stop_cultivation()
	helper.assert_true(not test_cultivation.is_cultivating, "CultivationSystem", "修炼停止")
	helper.assert_true(not test_player.get_is_cultivating(), "CultivationSystem", "玩家修炼状态关闭")

func test_do_cultivation():
	test_player.spirit_energy = 0
	test_cultivation.start_cultivation()
	
	test_cultivation.do_cultivate()
	helper.assert_eq(test_player.spirit_energy, 1, "CultivationSystem", "修炼获得灵气")
