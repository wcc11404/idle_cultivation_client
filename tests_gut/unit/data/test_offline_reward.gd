extends GutTest

## OfflineReward 单元测试

var offline_reward: OfflineReward = null
var player: PlayerData = null

func before_all():
	await get_tree().process_frame

func before_each():
	offline_reward = OfflineReward.new()
	player = PlayerData.new()
	add_child(player)
	await get_tree().process_frame
	
	add_child(offline_reward)
	await get_tree().process_frame

func after_each():
	if offline_reward:
		offline_reward.queue_free()
	if player:
		player.queue_free()

#region 初始化测试

func test_initialization():
	assert_not_null(offline_reward, "OfflineReward模块初始化")

func test_max_offline_hours():
	assert_eq(offline_reward.MAX_OFFLINE_HOURS, 4.0, "最大离线时间应为4小时")

func test_min_offline_minutes():
	assert_eq(offline_reward.MIN_OFFLINE_MINUTES, 1.0, "最小离线时间应为1分钟")

func test_signals_exist():
	assert_true(offline_reward.has_signal("offline_reward_calculated"), "应有offline_reward_calculated信号")

#endregion

#region 离线奖励计算测试

func test_calculate_offline_reward_zero_time():
	var reward = offline_reward.calculate_offline_reward(player, 0)
	assert_eq(reward.spirit_energy, 0, "零时间戳应无灵气奖励")
	assert_eq(reward.spirit_stone, 0, "零时间戳应无灵石奖励")

func test_calculate_offline_reward_short_time():
	var now = Time.get_unix_time_from_system()
	var before = now - 30
	var reward = offline_reward.calculate_offline_reward(player, before)
	assert_eq(reward.spirit_energy, 0, "小于1分钟应无灵气奖励")
	assert_eq(reward.spirit_stone, 0, "小于1分钟应无灵石奖励")

func test_calculate_offline_reward_one_minute():
	var now = Time.get_unix_time_from_system()
	var before = now - 60
	var reward = offline_reward.calculate_offline_reward(player, before)
	assert_gt(reward.spirit_energy, 0, "1分钟应有灵气奖励")
	assert_gte(reward.spirit_stone, 1, "1分钟应有灵石奖励")

func test_calculate_offline_reward_one_hour():
	var now = Time.get_unix_time_from_system()
	var before = now - 3600
	var reward = offline_reward.calculate_offline_reward(player, before)
	assert_gt(reward.spirit_energy, 0, "1小时应有灵气奖励")
	assert_gt(reward.spirit_stone, 0, "1小时应有灵石奖励")
	assert_gte(reward.offline_hours, 1.0, "离线时长至少1小时")
	assert_eq(reward.efficiency, 1.0, "效率固定为1.0")

func test_calculate_offline_reward_max_cap():
	var now = Time.get_unix_time_from_system()
	var before = now - 3600 * 24
	var reward = offline_reward.calculate_offline_reward(player, before)
	assert_lte(reward.offline_hours, 4.0, "应限制在最大离线时间")

func test_calculate_offline_reward_future_time():
	var now = Time.get_unix_time_from_system()
	var future = now + 3600
	var reward = offline_reward.calculate_offline_reward(player, future)
	assert_eq(reward.spirit_energy, 0, "未来时间应无奖励")
	assert_eq(reward.spirit_stone, 0, "未来时间应无灵石奖励")

#endregion

#region 奖励领取测试

func test_apply_offline_reward_spirit_energy():
	var reward = {
		"spirit_energy": 100.0,
		"spirit_stone": 0
	}
	
	var initial_spirit = player.spirit_energy
	offline_reward.apply_offline_reward(player, reward)
	
	assert_gt(player.spirit_energy, initial_spirit, "灵气应增加")

func test_apply_offline_reward_empty():
	var reward = {
		"spirit_energy": 0,
		"spirit_stone": 0
	}
	
	offline_reward.apply_offline_reward(player, reward)
	assert_true(true, "空奖励应不报错")

#endregion
