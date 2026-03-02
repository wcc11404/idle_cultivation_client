extends Node

var helper: Node = null
var test_offline_reward: Node = null
var test_player: Node = null

func _ready():
	helper = load("res://tests/test_helper.gd").new()
	add_child(helper)

func run_tests():
	print("\n=== OfflineReward 单元测试 ===")
	helper.reset_stats()
	
	test_player = load("res://scripts/core/PlayerData.gd").new()
	add_child(test_player)
	
	test_offline_reward = load("res://scripts/core/OfflineReward.gd").new()
	add_child(test_offline_reward)
	
	test_initialization()
	test_calculate_reward()
	test_min_offline_time()
	test_max_offline_time()
	
	return helper.failed_count == 0

func test_initialization():
	helper.assert_true(test_offline_reward != null, "OfflineReward", "模块初始化")

func test_calculate_reward():
	test_player.spirit_energy = 0.0
	test_player.base_max_spirit = 100.0
	
	var last_save_time = Time.get_unix_time_from_system() - 7200
	var rewards = test_offline_reward.calculate_offline_reward(test_player, last_save_time)
	
	helper.assert_true(rewards.get("offline_hours", 0) >= 1.0, "OfflineReward", "离线时长至少1小时")
	helper.assert_eq(rewards.get("efficiency", 0), 1.0, "OfflineReward", "效率固定为1.0")
	helper.assert_true(rewards.get("spirit_energy", 0) >= 0, "OfflineReward", "离线灵气>=0")
	helper.assert_true(rewards.get("spirit_stone", 0) >= 0, "OfflineReward", "离线灵石>=0")

func test_min_offline_time():
	# 测试小于1分钟的离线时间应该返回0奖励
	var last_save_time = Time.get_unix_time_from_system() - 30  # 30秒
	var rewards = test_offline_reward.calculate_offline_reward(test_player, last_save_time)
	
	helper.assert_eq(rewards.get("spirit_energy", -1), 0, "OfflineReward", "小于1分钟离线无灵气奖励")
	helper.assert_eq(rewards.get("spirit_stone", -1), 0, "OfflineReward", "小于1分钟离线无灵石奖励")

func test_max_offline_time():
	# 测试超过4小时的离线时间应该被限制
	var last_save_time = Time.get_unix_time_from_system() - 18000  # 5小时
	var rewards = test_offline_reward.calculate_offline_reward(test_player, last_save_time)
	
	helper.assert_true(rewards.get("offline_hours", 0) <= 4.0, "OfflineReward", "离线时长不超过4小时")
