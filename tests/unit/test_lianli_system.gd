extends Node

var helper: Node = null
var test_lianli: Node = null
var test_player: Node = null

func _ready():
	helper = load("res://tests/test_helper.gd").new()
	add_child(helper)

func run_tests():
	print("\n=== LianliSystem 单元测试 ===")
	helper.reset_stats()
	
	test_player = load("res://scripts/core/PlayerData.gd").new()
	add_child(test_player)
	
	test_lianli = load("res://scripts/core/LianliSystem.gd").new()
	test_lianli.set_player(test_player)
	add_child(test_lianli)
	
	test_initialization()
	test_start_lianli()
	test_lianli_round()
	
	return helper.failed_count == 0

func test_initialization():
	helper.assert_true(test_lianli != null, "LianliSystem", "模块初始化")
	helper.assert_true(test_lianli.player == test_player, "LianliSystem", "玩家正确设置")

func test_start_lianli():
	var enemy_data = {
		"name": "测试怪物",
		"health": 100,
		"attack": 10,
		"defense": 0,
		"level": 1
	}
	
	test_lianli.start_battle(enemy_data)
	helper.assert_true(test_lianli.is_in_battle, "LianliSystem", "战斗启动")

func test_lianli_round():
	var enemy_data = {
		"name": "测试怪物",
		"health": 100,
		"attack": 10,
		"defense": 0,
		"speed": 5,
		"level": 1
	}
	
	test_player.base_attack = 20.0
	test_player.base_defense = 5.0
	test_player.base_speed = 10.0
	test_player.health = 100.0
	
	test_lianli.start_battle(enemy_data)
	
	test_lianli._process(1.0)
	
	var enemy_health = test_lianli.current_enemy.get("current_health", 100)
	helper.assert_true(enemy_health < 100, "LianliSystem", "敌人受到伤害")
